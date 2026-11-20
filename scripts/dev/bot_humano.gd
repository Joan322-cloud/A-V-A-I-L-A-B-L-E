## Sin class_name: lo carga stress_bot.gd con `--humano` (solo herramienta).
extends Node
## v0.3.1 Q1 (F23): el «bot humano». Juega como una persona en su primera partida, para medir los minutos reales
## del turno y encontrar lo que el bot instantáneo no ve (B3/B7/F17/F20 se escaparon por eso):
## - reacciona tarde: 3-8 s a un llamado, a un contacto que suena, a un DM, al recordatorio de Vitzo; 1,5-4 s al Ack;
## - lee: 6-10 s por nodo del árbol del cliente, 2-4 s por clic en un caso de BO, 8-14 s mirando un KYC;
## - CAMINA con el controlador real (Input + move_and_slide) por la rejilla de rutas del piso (Pursuit.grid_for),
##   abre puertas, toma el ascensor andando hasta la cabina y salta al azar mientras camina (prueba el salto);
##   si una ruta no llega (atasco), lo anota y recién ahí se teletransporta (cuenta como incidente del bot);
## - se equivoca: 1 marca de QA cada 5 contactos (como mucho max−1 por turno: Haime nunca llega a la fatal);
## - se distrae: pasa por la expendedora en un break, va al baño una vez por turno y a veces se queda leyendo un DM.
## El stress_bot le pide los tiempos (react/read/click) y los traslados (go_sit, go_marker, ride).
## Estadísticas: metros, viajes en ascensor, saltos, atascos, teletransportes de respaldo y la línea de tiempo.

var bot: Node = null
var rng := RandomNumberGenerator.new()
var meters: float = 0.0
var rides: int = 0
var stuck: int = 0
var fallback_tp: int = 0
var doors: int = 0
var timeline: Array[String] = []
var _driving: bool = false
var _target: Vector3 = Vector3.ZERO
var _left: float = 0.0
var _reached: bool = false
var _last_pos: Vector3 = Vector3.INF
var jump_chance: float = 0.006  # por cuadro de física mientras camina
## Cada traslado nuevo que reemplaza a otro (un personaje te llama a mitad del break) sube la época: el traslado viejo
## se corta en su próximo paso y no vuelve a mover al jugador (antes dos corrutinas caminaban a la vez).
var epoch: int = 0


func cancel() -> void:
	epoch += 1
	_driving = false


func setup(p_bot: Node, seed_v: int) -> void:
	bot = p_bot
	rng.seed = seed_v


func reset_stats() -> void:
	_phys_t = 0.0
	_proc_t = 0.0
	meters = 0.0
	rides = 0
	stuck = 0
	fallback_tp = 0
	doors = 0
	timeline.clear()


func log_t(s: String) -> void:
	var rt := float(bot.get("_run_time")) if bot != null else 0.0
	var line := "%s · %5.1f min · %s" % [GameState.clock_text(), rt / 60.0, s]
	timeline.append(line)
	if OS.get_cmdline_user_args().has("--bot-escala"):
		line += " · cuadro %d" % Engine.get_frames_drawn()  # v0.3.2: para las hojas de cuadros de las grabaciones
	print("[humano] " + line)


# --- tiempos ---------------------------------------------------------------------------------------

func t_react() -> float:
	return rng.randf_range(3.0, 8.0)


func t_ack() -> float:
	return rng.randf_range(1.5, 4.0)


func t_read() -> float:
	return rng.randf_range(6.0, 10.0)


func t_click() -> float:
	return rng.randf_range(2.0, 4.0)


func t_kyc() -> float:
	return rng.randf_range(8.0, 14.0)


func chance(p: float) -> bool:
	return rng.randf() < p


## Espera `s` segundos reales del juego (escalados; se detiene con la pausa).
func wait(s: float) -> void:
	await get_tree().create_timer(maxf(s, 0.01), false).timeout


# --- caminar ---------------------------------------------------------------------------------------

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


var _phys_t: float = 0.0
var _proc_t: float = 0.0


func _process(delta: float) -> void:
	_proc_t += delta


## Física / proceso: < 0,97 = la máquina no da abasto y la física se atrasa (los minutos medidos salen inflados).
func physics_ratio() -> float:
	return _phys_t / maxf(_proc_t, 0.001)


func _physics_process(delta: float) -> void:
	_phys_t += delta
	var p := _player()
	if p == null:
		_driving = false
		return
	if _last_pos != Vector3.INF and p.global_position.distance_to(_last_pos) < 3.0:
		meters += Vector2(p.global_position.x - _last_pos.x, p.global_position.z - _last_pos.z).length()
	_last_pos = p.global_position
	if not _driving:
		return
	var to := _target - p.global_position
	to.y = 0.0
	if to.length() < 0.35:
		_reached = true
		_driving = false
		return
	_left -= delta
	if _left <= 0.0 or p.seated or p.input_locked:
		_driving = false
		return
	p.rotation.y = atan2(-to.x, -to.z)
	if rng.randf() < jump_chance:
		p.request_jump()


func _drive_to(target: Vector3, max_s: float) -> bool:
	_target = target
	_left = max_s
	_reached = false
	_driving = true
	Input.action_press("move_forward")
	while _driving:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return _reached


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _nearest_door(r: float) -> WorldObjects.Door:
	var b := _building()
	var p := _player()
	if b == null or p == null:
		return null
	var best: WorldObjects.Door = null
	var bd := r
	for n in b.floor_node.find_children("*", "", true, false):
		if n is WorldObjects.Door:
			(n as WorldObjects.Door).hint_text()  # las puertas con regla (calibración, azotea…) recalculan su llave aquí
			if not (n as WorldObjects.Door).open and not (n as WorldObjects.Door).locked:
				var d := _flat((n as Node3D).global_position, p.global_position)
				if d < bd:
					bd = d
					best = n
	return best


## Una ruta por la rejilla (como walk_test._rw_route): si se traba abre la puerta más cercana; si no, un paso atrás
## por la normal del choque y otra ruta desde donde quedó (hasta 3 veces).
func _route(g: Variant, target: Vector3, replans: int = 3) -> bool:
	var e := epoch
	var pts: PackedVector3Array = PackedVector3Array([target]) if g == null else g.find_path(_player().global_position, target)
	for pt in pts:
		if e != epoch or _player() == null:
			return false
		var ok := await _drive_to(pt, 9.0) or _flat(pt, _player().global_position) < 0.8
		if e != epoch:
			return false
		if not ok:
			var d := _nearest_door(2.4)
			if d != null:
				d.interact(_player())
				doors += 1
				await get_tree().create_timer(0.9, false).timeout
				ok = await _drive_to(pt, 9.0) or _flat(pt, _player().global_position) < 0.8
		if not ok:
			if replans <= 0:
				return false
			var away := _player().global_transform.basis.z
			var col := _player().get_last_slide_collision()
			if col != null:
				away = col.get_normal()
			away.y = 0.0
			if away.length() > 0.01:
				await _drive_to(_player().global_position + away.normalized() * 0.7 + away.cross(Vector3.UP).normalized() * rng.randf_range(-0.4, 0.4), 1.2)
			return await _route(g, target, replans - 1)
	return true


## Camina hasta `target` en el piso actual por la rejilla de rutas. Si no llega, lo anota y se teletransporta.
## `near` = a cuántos metros ya vale (el centro del evento de Rasec está entre las sillas: basta con su radio).
func walk_to(target: Vector3, why: String = "", near: float = 1.2) -> bool:
	var p := _player()
	var b := _building()
	if p == null or b == null:
		return false
	if p.seated:
		p.stand_up()
		await get_tree().physics_frame
	if not is_instance_valid(b) or not is_instance_valid(p):
		return false  # v0.3.2: el mundo se rearmó (turno nuevo, menú) mientras esperaba
	var g: Variant = Pursuit.grid_for(b.floor_node)
	var e := epoch
	var ok := await _route(g, target)
	if e != epoch:
		return false  # otro traslado lo reemplazó: no se teletransporta a un destino viejo
	if not ok and _player() != null and _flat(target, _player().global_position) > near:
		stuck += 1
		fallback_tp += 1
		log_t("ATASCO yendo a %s (%.1f, %.1f) desde (%.1f, %.1f): teletransporte de respaldo" % [why, target.x, target.z, _player().global_position.x, _player().global_position.z])
		_player().teleport(target + Vector3(0, 0.05, 0), _player().rotation_degrees.y)
		await get_tree().physics_frame
	return ok


func _node(n: String) -> Node3D:
	var b := _building()
	return b.floor_node.find_child(n, true, false) as Node3D if b != null and b.floor_node != null else null


## Viaje en ascensor andando hasta la cabina. Desde la escalera o sin cabina: respaldo con go_to_floor.
func ride(target: int) -> void:
	var ep := epoch
	var b := _building()
	if b == null or b.current_floor == target:
		return
	var elev: Node3D = null
	for e in get_tree().get_nodes_in_group("elevator"):
		if b.floor_node != null and b.floor_node.is_ancestor_of(e):
			elev = e as Node3D
	if elev == null:
		fallback_tp += 1
		b.go_to_floor(target, "ascensor")
		await wait(0.5)
		return
	var front := elev.global_position + elev.global_transform.basis.z * 2.0
	await walk_to(front, "ascensor")
	await wait(rng.randf_range(1.0, 3.0))  # espera el ascensor
	if ep != epoch:
		return
	b = _building()
	if b == null or b.current_floor == target or not is_instance_valid(elev):
		return  # mientras esperaba cambió de piso (respaldo o muerte): la cabina de ese piso ya no existe
	rides += 1
	log_t("ascensor %d → %d" % [b.current_floor, target])
	elev.call("_travel", target)
	var w := 0.0
	while (b.current_floor != target or _player().input_locked) and w < 60.0:
		await get_tree().process_frame
		w += get_process_delta_time()
		b = _building()
		if b == null:
			return
	await wait(1.5)  # las puertas terminan de abrirse (0,5 s + 1,1 s de animación)
	# sale de la cabina
	var b2 := _building()
	var e2: Node3D = null
	for e in get_tree().get_nodes_in_group("elevator"):
		if b2 != null and b2.floor_node != null and b2.floor_node.is_ancestor_of(e):
			e2 = e as Node3D
	if e2 != null:
		await walk_to(e2.global_position + e2.global_transform.basis.z * 1.8, "salir del ascensor")


func go_floor(n: int) -> void:
	var b := _building()
	if b != null and b.current_floor != n:
		await ride(n)


## Va a un asiento (por id: C-14, calibracion, training_sala2_3…) del piso `floor_n` y se sienta.
func go_sit(floor_n: int, seat_id: String) -> bool:
	var e := epoch
	await go_floor(floor_n)
	if e != epoch:
		return false
	var b := _building()
	if b == null:
		return false
	var fl := b.floor_node as FloorBase
	var seat: Node3D = fl.seat_by_id(seat_id) if fl != null else null
	if seat == null:
		seat = _node("Seat_" + seat_id)
	if seat == null:
		log_t("no hay silla %s" % seat_id)
		return false
	var front := seat.global_position + seat.global_transform.basis.z * 0.9
	front.y = (seat.get_parent() as Node3D).global_position.y if seat.get_parent() is Node3D else 0.0
	await walk_to(front, seat_id)
	await wait(rng.randf_range(0.4, 1.2))
	if e != epoch:
		return false
	var p := _player()
	if p == null:
		return false
	if p.seated:
		p.stand_up()
	p.sit_at(seat, seat_id)
	return true


## Va a un marcador o nodo del piso `floor_n` (con un desplazamiento opcional).
func go_marker(floor_n: int, marker: String, offset: Vector3 = Vector3.ZERO, near: float = 1.2) -> bool:
	var e := epoch
	await go_floor(floor_n)
	if e != epoch:
		return false
	var m := _node(marker)
	if m == null:
		log_t("no hay marcador %s en el piso %d" % [marker, floor_n])
		return false
	var ok := await walk_to(m.global_position + offset, marker, near)
	if e != epoch:
		return false
	log_t("en %s (piso %d)%s" % [marker, floor_n, "" if ok else " (con respaldo)"])
	return true


## Interactúa con un objeto del piso (casillero, refri, microondas, expendedora) tras caminar hasta él.
func use_object(floor_n: int, node_name: String) -> bool:
	var e := epoch
	await go_floor(floor_n)
	if e != epoch:
		return false
	var o := _node(node_name)
	if o == null:
		return false
	var p := _player()
	var to := o.global_position - p.global_position
	to.y = 0.0
	var stand := o.global_position - to.normalized() * 1.1 if to.length() > 0.01 else o.global_position + Vector3(0, 0, 1.1)
	stand.y = p.global_position.y
	await walk_to(stand, node_name)
	await wait(rng.randf_range(0.6, 1.5))
	if e != epoch or not is_instance_valid(o):
		return false
	if o is Interactable:
		(o as Interactable).interact(_player())
		var shop := get_tree().get_first_node_in_group("shop_menu")
		if shop != null and bool(shop.get("_open")):
			await wait(rng.randf_range(2.0, 4.0))
			if not bool(shop.call("buy_index", 0)):
				shop.call("close")
			log_t("compra en %s · saldo %s" % [node_name, Economy.soles(Economy.saldo)])
	return true


func summary() -> String:
	return "física/proceso %.3f · %.0f m caminados · %d viajes en ascensor · %d puertas · %d saltos · %d atascos (%d teletransportes de respaldo) · %d salidas de muebles" % [physics_ratio(), meters, rides, doors, _player().jumps if _player() != null else -1, stuck, fallback_tp, _player().unstuck_count if _player() != null else -1]

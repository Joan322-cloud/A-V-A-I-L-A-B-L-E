## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## walk_test / qa_tour: mueve al jugador con el controlador REAL (Input + move_and_slide), no por waypoints.
##  -- --walk-test : en cada piso (-1, 1, 2, 9) y en la caja de escalera 1→2 recorre todos los bordes y
##                   esquinas de la planta (malla de check_collision, un objetivo por metro de borde) empujando
##                   el cuerpo contra cada borde; al final exige 0 rescates de la red de seguridad.
##  -- --qa-tour   : recorrido de QA jugado: calle → lobby → molinete → cafetería → baños del -1 (pestillo) →
##                   ascensor a cada piso → escalera (subir y bajar) → casillero → refri → agua → sala → C-14
##                   (sentarse ×3) → La Central → azotea; captura 1280×720 en cada punto (si hay pantalla),
##                   comprueba cámara sin atravesar paredes, interactuables que responden, 0 caídas y 0 errores
##                   en el log; informe en docs/QA_v0.1.1.md (o --qa-out <carpeta>). Las capturas del menú a varias
##                   resoluciones (ui_<ancho>x<alto>.png) las añade tools/qa_tour.sh.
##  -- --random-walk [min] (P7): paseo al azar con el controlador real durante `min` minutos de juego a 1x
##                   (30 por defecto): cambia de piso por ascensor y por la escalera, elige destinos al azar entre
##                   las celdas transitables (rejilla A* de Pursuit), abre las puertas que encuentra y cuenta
##                   caídas (rescates de la red de seguridad) y atascos (no llega ni abriendo puertas).
## Uso: godot --headless --path game -- --walk-test
##      xvfb-run -a -s "-screen 0 2560x1600x24" godot --path game --rendering-driver opengl3 -- --qa-tour

var _main: Node = null
var _qa: bool = false
var _cc: Node = null  # check_collision (malla)
var _player: Player = null
var _building: Building = null
var _driving: bool = false
var _drive_target: Vector3 = Vector3.ZERO
var _drive_left: float = 0.0
var _drive_reached: bool = false
var _report: Array[String] = []
var _fails: int = 0
var _passes: int = 0
var _shots: int = 0
var _out_dir: String = ""
var _headless: bool = false
var _t0_ms: int = 0
var _rescues_final: int = 0
var _rw_min: float = -1.0
var _jump_on: bool = false  # v0.3.1 Q1 (F26/C16): `--saltar` = salta al azar mientras camina (sin fugas del mapa)
var _jump_rng := RandomNumberGenerator.new()
var jumps_tried: int = 0


func start(main: Node, qa: bool) -> void:
	_main = main
	_qa = qa
	_headless = DisplayServer.get_name() == "headless"
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--qa-out")
	var root := ProjectSettings.globalize_path("res://").path_join("..")
	_out_dir = args[oi + 1] if oi >= 0 and oi + 1 < args.size() else root.path_join("dist/qa_walk")
	_jump_on = args.has("--saltar")
	_jump_rng.seed = 4242
	var ri := args.find("--random-walk")
	if ri >= 0:
		_rw_min = float(args[ri + 1]) if ri + 1 < args.size() and args[ri + 1].is_valid_float() else 30.0
	_run()


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	if not _headless:
		DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.time_scale = 4.0 if _qa else 8.0
	var cc_script := load("res://scripts/dev/check_collision.gd") as GDScript
	_cc = cc_script.new()
	add_child(_cc)
	_main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	await get_tree().physics_frame
	_building = get_tree().get_first_node_in_group("building") as Building
	_player = get_tree().get_first_node_in_group("player") as Player
	_cc.set("_player", _player)
	if _rw_min > 0.0:
		await _random_walk(_rw_min)
	elif _qa:
		await _tour()
	else:
		await _walk_all()
	var ok := _fails == 0
	if is_instance_valid(_player):
		_rescues_final = _player.fall_rescues
	print("[walk] FIN: %d PASS, %d FAIL, %d rescates de la red de seguridad, %.0f s de pared%s → %s" % [_passes, _fails, _rescues_final, (Time.get_ticks_msec() - _t0_ms) / 1000.0, (" · saltando: %d saltos, %d salidas de muebles" % [_player.jumps if is_instance_valid(_player) else -1, _player.unstuck_count if is_instance_valid(_player) else -1]) if _jump_on else "", "OK" if ok else "FALLO"])
	get_tree().quit(0 if ok else 1)


# ---------------------------------------------------------------------------
# Conducción real del jugador
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _driving or not is_instance_valid(_player):
		return
	var to := _drive_target - _player.global_position
	to.y = 0.0
	if to.length() < 0.3:
		_drive_reached = true
		_driving = false
		return
	_drive_left -= delta
	if _drive_left <= 0.0:
		_driving = false
		return
	_player.rotation.y = atan2(-to.x, -to.z)
	if _jump_on and _jump_rng.randf() < 0.04 and _player.request_jump():
		jumps_tried += 1


## Camina hacia `target` hasta llegar (0,3 m) o agotar `max_s` segundos de juego. Devuelve si llegó.
func _drive_to(target: Vector3, max_s: float = 6.0) -> bool:
	_drive_target = target
	_drive_left = max_s
	_drive_reached = false
	_driving = true
	Input.action_press("move_forward")
	while _driving:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return _drive_reached


var _last_nav: String = ""


func _goto(points: Array, max_s_each: float = 8.0) -> bool:
	_last_nav = ""
	for p in points:
		if not await _drive_to(p, max_s_each):
			_last_nav = "atascado en (%.1f, %.1f) yendo a (%.1f, %.1f)" % [_player.global_position.x, _player.global_position.z, p.x, p.z]
			print("[qa]   navegación: " + _last_nav)
			return false
	return true


func _settle(frames: int = 3) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		left -= get_physics_process_delta_time()
		await get_tree().physics_frame


# ---------------------------------------------------------------------------
# --walk-test: bordes y esquinas
# ---------------------------------------------------------------------------

func _walk_all() -> void:
	_player.safety_enabled = true
	for f in [-1, 1, 2, 9]:
		_building.go_to_floor(f, "ascensor")
		await _settle()
		await _walk_floor("piso %d" % f, _building.floor_node)
	_building.current_floor = 1
	_building.go_to_stairwell(2, true)
	await _settle()
	await _walk_floor("escalera 1→2", _building.floor_node)


func _walk_floor(label: String, floor_node: Node3D) -> void:
	var a: Dictionary = _cc.call("analyze", floor_node, false)
	var cells: Dictionary = a["cells"]
	var origin: Vector2 = a["origin"]
	var step: float = _cc.get("STEP")
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	# Celdas de borde: transitables con un vecino bloqueado/no alcanzado. Guardamos la dirección al vacío.
	var edges: Array = []
	for c in cells:
		if int(cells[c]["state"]) == 1:
			continue
		for d in dirs:
			var n: Vector2i = c + d
			if not cells.has(n) or int(cells[n]["state"]) == 1:
				edges.append([c, d, float(cells[c]["y"])])
				break
	# Un objetivo por metro de borde (muestreo voraz).
	var targets: Array = []
	var taken: Dictionary = {}
	for e in edges:
		var c: Vector2i = e[0]
		var key := Vector2i(int(floor(c.x * step)), int(floor(c.y * step)))
		if taken.has(key):
			continue
		taken[key] = true
		targets.append(e)
	var before := _player.fall_rescues
	var t_start := Time.get_ticks_msec()
	var stuck := 0
	for e in targets:
		var c: Vector2i = e[0]
		var d: Vector2i = e[1]
		var y: float = e[2]
		var p := Vector3(origin.x + c.x * step, y, origin.y + c.y * step)
		var away := Vector3(-d.x, 0, -d.y)  # hacia el interior
		var start := p + away * 0.7
		var sc := Vector2i(int(round((start.x - origin.x) / step)), int(round((start.z - origin.y) / step)))
		if not cells.has(sc) or int(cells[sc]["state"]) == 1:
			start = p + away * 0.3
		_player.teleport(start + Vector3(0, 0.05, 0), 0.0)
		await _settle(2)
		var reached := await _drive_to(p - away * 0.8, 0.9)  # empuja contra el borde
		if not reached and _player.global_position.distance_to(start) < 0.05:
			stuck += 1
	var falls := _player.fall_rescues - before
	var line := "%s: %d celdas de borde, %d objetivos, %d caídas rescatadas, %d sin moverse, %.1f s de pared" % [label, edges.size(), targets.size(), falls, stuck, (Time.get_ticks_msec() - t_start) / 1000.0]
	print("[walk] " + line)
	_check("Bordes " + label + " sin caídas", falls == 0, line)
	for l in _player.fall_log:
		print("[walk]    " + l)
	_player.fall_log.clear()


# ---------------------------------------------------------------------------
# --qa-tour
# ---------------------------------------------------------------------------

func _check(p_name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passes += 1
	else:
		_fails += 1
	if not ok and detail == "" and _last_nav != "":
		detail = _last_nav
	_report.append("| %s | %s | %s |" % [p_name, "PASS" if ok else "**FAIL**", detail.replace("|", "/")])
	print("[qa] %s · %s%s" % ["PASS" if ok else "FAIL", p_name, (" · " + detail) if detail != "" else ""])


func _floor() -> Node3D:
	return _building.floor_node


func _find(p_name: String) -> Node:
	return _floor().find_child(p_name, true, false) if _floor() != null else null


## Interactúa con un objeto del piso por nombre y comprueba que responde (pista no vacía, sin error).
func _use(p_name: String, expect_hint: bool = true) -> bool:
	var n := _find(p_name)
	if not (n is Interactable):
		_check("Interactuable " + p_name, false, "no existe en el piso %d" % _building.current_floor)
		return false
	var it := n as Interactable
	var hint := it.hint_text()
	var r := it.interact(_player)
	var ok := (not expect_hint) or hint != ""
	_check("Interactuable " + p_name, ok, "pista «%s», interact=%s" % [hint, str(r)])
	await _settle(2)
	return r


## Captura 1280×720 + comprobación de cámara (rayo cámara→cuerpo sin paredes en medio).
func _shot(p_name: String) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shots += 1
	var file := "%02d_%s.png" % [_shots, p_name]
	if not _headless:
		DirAccess.make_dir_recursive_absolute(_out_dir)
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out_dir.path_join(file))
	# Cámara: nada sólido entre el ojo y el centro del cuerpo.
	var space := _player.get_world_3d().direct_space_state
	var from := _player.camera.global_position
	var to := _player.global_position + Vector3(0, 0.9, 0)
	var rq := PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()])
	var hit := space.intersect_ray(rq)
	var clip := not hit.is_empty()
	_check("Cámara limpia en " + p_name, not clip, ("atraviesa " + str((hit["collider"] as Node).get_path()) if clip else "ok") + (" · " + file if not _headless else " · sin pantalla, sin captura"))


func _elevator() -> Node:
	for e in get_tree().get_nodes_in_group("elevator"):
		if _floor() != null and _floor().is_ancestor_of(e):
			return e
	return null


## Viaje real en ascensor: entra a la cabina, abre la botonera, pulsa el piso y espera la llegada.
func _ride(target: int) -> void:
	var elev := _elevator()
	if elev == null:
		_check("Ascensor en piso %d" % _building.current_floor, false, "no hay cabina")
		return
	# v0.3.1 pisos: la cabina puede estar girada (piso 2: abre hacia −z); delante = su +z local.
	var et := (elev as Node3D).global_transform
	var cabin: Vector3 = et * Vector3(0, 0, 0.2)
	var arrived := await _goto([et * Vector3(0, 0, 2.2), cabin], 10.0)
	_check("Llegar andando a la cabina (piso %d)" % _building.current_floor, arrived, "desde (%.1f, %.1f)" % [_player.global_position.x, _player.global_position.z])
	await _use("PanelInteract")
	elev.call("close_panel")
	var from := _building.current_floor
	elev.call("_travel", target)
	var waited := 0.0
	while (_building.current_floor != target or _player.input_locked) and waited < 40.0:
		waited += get_physics_process_delta_time()
		await get_tree().physics_frame
	_check("Ascensor %d → %d" % [from, target], _building.current_floor == target and not _player.input_locked, "%.1f s de juego" % waited)
	await _settle(2)


func _tour() -> void:
	_player.safety_enabled = true
	# v0.3: el recorrido es de mundo, no de reglas: si llega un WW (Shero v0.2 hasta P3) se le da Ack.
	EventBus.ack_window_opened.connect(func(_s: float) -> void: Metrics.give_ack.call_deferred())
	var fl: Node3D
	# ---- Piso -1: calle, fachada, lobby, molinete, cafetería, baños individuales ----
	await _wait(0.5)
	_check("Spawn en la calle mirando a la fachada", absf(wrapf(_player.rotation_degrees.y, -180.0, 180.0)) < 1.0, "yaw %.0f°" % _player.rotation_degrees.y)
	await _shot("calle_spawn")
	# v0.3.1 Q5: la vereda está 2,1 m arriba; se baja por la escalera del patio (baranda central en x 0).
	_check("Andar hasta la fachada", await _goto([Vector3(-1.6, 0, 23.0), Vector3(-1.6, 0, 16.5)]), "")
	await _shot("fachada")
	_check("Entrar al lobby", await _goto([Vector3(-0.6, 0, 15.0), Vector3(-0.6, 0, 11.0)]), "")
	await _shot("lobby")
	_check("Llegar al molinete", await _goto([Vector3(-1.0, 0, 7.3)]), "")
	# v0.3 P5: con la revisión de Don Fermín activa el molinete no abre sin "revision_ok"; la revisión la prueban
	# los escenarios p5_guardia*. Aquí se da por hecha (P6b: el recorrido fallaba desde P5 por esto).
	GameState.flags["revision_ok"] = true
	await _use("Molinete0")
	_check("Molinete marca entrada", bool(GameState.flags.get("clocked_in", false)), "")
	await _shot("molinetes")
	_check("Cruzar el molinete", await _goto([Vector3(-1.0, 0, 4.8), Vector3(0, 0, 2.0)]), "")
	_check("Caseta del guardia", await _goto([Vector3(-1.0, 0, 4.8), Vector3(-1.0, 0, 7.3), Vector3(-5.5, 0, 10.5)], 10.0), "")
	await _shot("guardia")
	# Rumbo recto con deslizamiento: los puntos intermedios van por el centro de cada vano (sin esquinas).
	# v0.3.1 pisos (plano de Joan): la cafetería está detrás del núcleo, por la puerta push (x 0,4..3,6, z −6..−4).
	_check("Andar a la cafetería (puerta push)", await _goto([Vector3(-1.0, 0, 7.3), Vector3(-1.0, 0, 4.8), Vector3(2.0, 0, 1.0), Vector3(2.0, 0, -2.5), Vector3(2.0, 0, -5.0), Vector3(2.0, 0, -7.5), Vector3(3.5, 0, -9.0)], 10.0), "")
	await _shot("cafeteria")
	_check("Recorrer la cafetería", await _goto([Vector3(6.0, 0, -8.6), Vector3(6.0, 0, -12.5), Vector3(-6.0, 0, -12.5), Vector3(-9.7, 0, -9.2), Vector3(-0.5, 0, -12.5), Vector3(6.5, 0, -8.2)], 12.0), "")
	await _use("Microondas")
	# Paso abierto de los baños (x 11,4..13) hasta la zona de barra; la expendedora contra la pared que da al núcleo.
	_check("Pasillo de baños → zona de barra", await _goto([Vector3(10.0, 0, -8.6), Vector3(12.2, 0, -7.6), Vector3(12.2, 0, -6.0), Vector3(12.2, 0, -1.2), Vector3(12.6, 0, 0.0)], 12.0), "")
	await _use("Expendedora")
	# P7: la captura salía negra (pegada a la pared): dos pasos atrás y mirando a la expendedora.
	_check("Frente a la expendedora", await _goto([Vector3(13.0, 0, 1.0)], 6.0), "")
	_player.rotation_degrees.y = 90.0
	_player.head.rotation.x = -0.12
	await _shot("expendedora")
	_check("Zona de descanso del -1", await _goto([Vector3(12.6, 0, 4.6), Vector3(14.4, 0, 9.5)], 14.0), "")
	await _shot("descanso_m1")
	_check("Volver al núcleo por la puerta abierta", await _goto([Vector3(12.6, 0, 4.6), Vector3(12.6, 0, 4.0), Vector3(10.2, 0, 4.0), Vector3(8.5, 0, 2.5), Vector3(0, 0, 0)], 14.0), "")
	# Baño individual del -1 (en el paso de baños, puerta al oeste en x 13) con pestillo.
	_check("Hasta la puerta del baño H", await _goto([Vector3(8.5, 0, 2.5), Vector3(10.2, 0, 4.0), Vector3(12.6, 0, 4.0), Vector3(12.6, 0, 0.0), Vector3(12.2, 0, -1.2), Vector3(12.2, 0, -4.9)], 14.0), "")
	var bano_h := _find("Bano_bano_m1_h") as Bathroom
	var door_h: Node = bano_h.get_node_or_null("Puerta") if bano_h != null else null
	if door_h is Interactable and not (door_h as WorldObjects.Door).open:
		_check("Interactuable Puerta (baño H)", (door_h as Interactable).interact(_player), "pista «%s»" % (door_h as Interactable).hint_text())
	await _settle(2)
	var entered := await _goto([Vector3(13.8, 0, -4.9)], 6.0)
	await _wait(0.3)
	_check("Entrar al baño individual H", entered, "")
	_check("Pestillo del baño individual", bano_h != null and bano_h.latched, "latched=%s" % str(bano_h.latched if bano_h != null else false))
	# P7: entrando se mira la pared del fondo (captura en blanco): media vuelta para ver la puerta con el pestillo.
	_player.rotation_degrees.y += 180.0
	await _settle(2)
	await _shot("bano_m1")
	_player.rotation_degrees.y -= 180.0
	_check("Salir del baño H", await _goto([Vector3(12.2, 0, -4.9), Vector3(12.2, 0, -1.2), Vector3(12.6, 0, 0.0), Vector3(12.6, 0, 4.0), Vector3(10.2, 0, 4.0), Vector3(8.5, 0, 2.5), Vector3(0.0, 0, 0.0)], 14.0), "")
	# ---- Ascensor al piso 1 ----
	await _shot("ascensor_fuera")
	await _ride(1)
	await _shot("piso1_cabina")
	_check("Salir de la cabina al pasillo", await _goto([Vector3(-3.0, 0, -1.5), Vector3(0.0, 0, 0.0)], 8.0), "")
	await _shot("piso1_pasillo")
	# v0.3.1 pisos (plano de Joan): esmerilada en x 6 → cruce con el «SALIDA» → recodo → puerta del tópico (~6,5 m).
	_check("Pasillo del piso 1 hasta el tópico", await _goto([Vector3(5.0, 0, 0.0), Vector3(6.9, 0, 0.0), Vector3(7.1, 0, -0.3), Vector3(10.5, 0, -0.3), Vector3(11.6, 0, -0.3)], 16.0), "")
	_player.rotation_degrees.y = -90.0
	await _shot("topico_training")
	_check("Baño común del piso 1 (vestíbulo al fondo del pasillo)", await _goto([Vector3(7.1, 0, -0.3), Vector3(7.1, 0, 3.0), Vector3(7.1, 0, 6.5), Vector3(7.5, 0, 8.65)], 14.0), "")
	var bano_p1b := _find("Bano_bano_p1_b") as Bathroom
	if bano_p1b != null:
		var d1: Node = bano_p1b.get_node_or_null("Puerta")
		if d1 is Interactable:
			(d1 as Interactable).interact(_player)
			await _settle(2)
	_check("Entrar al baño común (espejo)", await _goto([Vector3(9.4, 0, 8.65), Vector3(11.0, 0, 10.0)], 8.0), "")
	await _use("Espejo")
	await _shot("bano_p1")
	_check("Salir del baño del piso 1", await _goto([Vector3(9.4, 0, 8.65), Vector3(7.5, 0, 8.4), Vector3(7.1, 0, 6.5), Vector3(7.1, 0, 0.0), Vector3(5.0, 0, 0.0)], 14.0), "")
	_check("Pasillo apagado hasta la puerta de la mirilla", await _goto([Vector3(7.1, 0, 0.0), Vector3(7.1, 0, 6.5), Vector3(6.8, 0, 7.6), Vector3(3.0, 0, 7.55), Vector3(0.7, 0, 7.55)], 14.0), "")
	_check("Volver al hall", await _goto([Vector3(3.0, 0, 7.55), Vector3(6.8, 0, 7.6), Vector3(7.1, 0, 6.5), Vector3(7.1, 0, 0.0), Vector3(5.0, 0, 0.0)], 14.0), "")
	# ---- Escalera: subir de 1 a 2 por la caja ----
	_check("Hasta la escalera (enfrente de los ascensores)", await _goto([Vector3(3.3, 0, 0.4)], 6.0), "")
	await _use("EscaleraSubir")
	await _settle(2)
	fl = _floor()
	_check("Caja de escalera cargada", fl is Stairwell, str(fl.name) if fl != null else "nada")
	if fl is Stairwell:
		var base: Vector3 = fl.global_position
		# v0.3.1 Q5: escalera en U (tramo A x > 0 hacia +z, descanso medio, tramo B x < 0 hacia -z).
		_check("Subir el tramo andando", await _goto([base + Vector3(1.15, 0, 2.2), base + Vector3(1.15, 1.6, 5.6), base + Vector3(-1.15, 1.6, 5.6), base + Vector3(-1.15, 3.2, 1.0)], 14.0), "y=%.2f" % _player.global_position.y)
		await _shot("escalera_arriba")
		_check("Medio tramo a 3-8 (antes sin colisión)", await _goto([base + Vector3(-1.15, 3.2, 0.2), base + Vector3(-1.15, 4.4, -2.9)], 8.0), "y=%.2f" % _player.global_position.y)
		await _use("PuertaBloqueada", true)
		await _shot("escalera_cortafuego")
		_check("Volver al descanso alto", await _goto([base + Vector3(-1.15, 3.2, 0.2), base + Vector3(-1.15, 3.2, 1.0)], 8.0), "")
		await _use("Puerta_salida")
		await _settle(2)
	_check("Salir de la caja al piso 2", _building.current_floor == 2, "piso %d" % _building.current_floor)
	# ---- Piso 2 ----
	await _shot("piso2_nucleo")
	# v0.3.1 pisos: hall → molinete → casilleros → entrada 2 (vidrio) → ala norte → feedback / sala.
	_check("Hall → molinete → casilleros", await _goto([Vector3(3.6, 0, -0.4), Vector3(2.6, 0, -0.4), Vector3(0.5, 0, -0.4), Vector3(0.5, 0, -4.0)], 12.0), "")
	await _use("MiCasillero")
	await _shot("casilleros")
	_check("Casilleros → entrada 2 → ala norte", await _goto([Vector3(0.5, 0, 2.3), Vector3(0.5, 0, 4.0), Vector3(4.0, 0, 4.4)], 10.0), "")
	_check("Sala de feedback (se entra desde el ala norte)", await _goto([Vector3(8.5, 0, 4.9), Vector3(11.8, 0, 4.9), Vector3(11.8, 0, 3.4)], 10.0), "")
	await _shot("calibracion")
	_check("Ala norte → sala de operaciones (entrada 2)", await _goto([Vector3(11.8, 0, 4.9), Vector3(18.75, 0, 4.9), Vector3(18.75, 0, 2.8), Vector3(19.0, 0, 0.5)], 12.0), "")
	await _shot("sala_entrada")
	var f2 := _floor() as FloorBase
	var c14 := f2.seat_by_id("C-14") if f2 != null else null
	var c14_pos: Vector3 = c14.get_parent().global_position if c14 != null else Vector3(39.5, 0, -11.1)
	_check("Pasillo de la fila C hasta C-14", await _goto([Vector3(18.7, 0, -10.6), Vector3(c14_pos.x, 0, -10.6), c14_pos + Vector3(0, 0, 1.2)], 16.0), "")
	for i in 3:
		if c14 != null:
			c14.interact(_player)
			await _settle(2)
			var seated := _player.seated
			if i == 0 and not GameState.logged_in:
				GameState.login()
			if i == 0:
				await _shot("c14_sentado")
			_player.stand_up()
			await _settle(2)
			_check("Sentarse/levantarse en C-14 (%d/3)" % (i + 1), seated and not _player.seated and _player.global_position.y > -0.5, "y=%.2f" % _player.global_position.y)
	await _shot("c14_de_pie")
	_check("La Central (impresora)", await _goto([Vector3(46.4, 0, -10.6), Vector3(46.4, 0, -15.0), Vector3(45.0, 0, -17.0)], 14.0), "sin interactuable propio: solo vista")
	await _shot("central")
	_check("Sitio de Shero", await _goto([Vector3(46.4, 0, -13.0), Vector3(46.4, 0, -9.2)], 10.0), "")
	await _shot("shero_sitio")
	_check("Sala → ala suroeste (entrada 1)", await _goto([Vector3(46.4, 0, -12.7), Vector3(18.7, 0, -12.7), Vector3(16.6, 0, -12.6), Vector3(6.6, 0, -12.6)], 18.0), "")
	await _shot("anexo_so")
	_check("Entrada 1 → pantry", await _goto([Vector3(4.3, 0, -12.55), Vector3(0.5, 0, -12.5)], 8.0), "")
	await _use("Refri1")
	await _use("MaquinaAgua")
	await _shot("vestibulo_refris")
	_check("Pasillo de casilleros (14 paneles)", await _goto([Vector3(0.5, 0, -10.2)], 6.0), "")
	_check("Sin terminal Fonex en el pasillo (v0.3.2)", _find("Terminal_pasillo_agua") == null, "")
	await _shot("pasillo_agua")
	_check("Sala auxiliar (puesto del RTA)", await _goto([Vector3(0.5, 0, -12.5), Vector3(-2.6, 0, -12.5), Vector3(-4.3, 0, -12.5), Vector3(-4.7, 0, -13.6)], 10.0), "")
	await _shot("sala_auxiliar")
	_check("Pasillo corto de baños", await _goto([Vector3(-4.3, 0, -12.5), Vector3(-2.6, 0, -12.5), Vector3(0.55, 0, -12.5), Vector3(0.55, 0, -14.6), Vector3(0.55, 0, -15.85)], 10.0), "")
	var bano_p2 := _find("Bano_bano_p2") as Bathroom
	if bano_p2 != null:
		var d2: Node = bano_p2.get_node_or_null("Puerta")
		if d2 is Interactable:
			(d2 as Interactable).interact(_player)
			await _settle(2)
	_check("Entrar al baño de hombres del piso 2 (a la derecha)", await _goto([Vector3(2.3, 0, -15.85), Vector3(3.3, 0, -17.0)], 8.0), "")
	await _shot("bano_p2")
	_check("Volver al ascensor del 2", await _goto([Vector3(2.3, 0, -15.85), Vector3(0.55, 0, -15.85), Vector3(0.55, 0, -12.5), Vector3(0.5, 0, -10.2), Vector3(0.5, 0, -0.4), Vector3(2.6, 0, -0.4), Vector3(5.0, 0, 0.0), Vector3(14.6, 0, 0.6)], 20.0), "")
	# ---- Azotea ----
	await _ride(9)
	_check("Vestíbulo de la azotea", await _goto([Vector3(-2.0, 0, -1.5), Vector3(0, 0, 1.2)], 8.0), "")
	await _use("PuertaAzotea")
	await _shot("azotea_vidrio")
	# v0.3 P2: la puerta del deck (abre en Break/Lunch: regla probada en --escenario puerta_azotea); aquí se
	# abre con la bandera de desarrollo para no cambiar de AUX en medio del recorrido (Shero v0.2 reacciona).
	GameState.flags["azotea_abierta_dev"] = true
	await _settle(2)
	var deck := _find("PuertaAzotea") as WorldObjects.Door
	if deck != null and not deck.open:
		_check("Puerta del deck abre", deck.interact(_player), "pista «%s»" % deck.hint_text())
	await _settle(2)
	_check("Deck → cafetería al aire libre", await _goto([Vector3(0, 0, 3.2), Vector3(3.0, 0, 5.6), Vector3(5.0, 0, 5.8), Vector3(6.0, 0, 7.2)], 12.0), "")
	await _shot("cafeteria_azotea")
	_check("Volver al vestíbulo de la azotea", await _goto([Vector3(5.0, 0, 5.8), Vector3(3.0, 0, 5.6), Vector3(0, 0, 3.2), Vector3(0, 0, 0.5)], 12.0), "")
	GameState.flags.erase("azotea_abierta_dev")
	# ---- Bajar al -1 y salir a la calle ----
	await _ride(-1)
	_check("Salir a la calle", await _goto([Vector3(-3.0, 0, -1.0), Vector3(0.25, 0, 2.0), Vector3(0.25, 0, 8.0), Vector3(0.25, 0, 12.0), Vector3(-0.6, 0, 15.0), Vector3(-1.6, 0, 16.5), Vector3(-1.6, 0, 23.0), Vector3(0, 0, 24.0)], 18.0), "")
	await _shot("calle_salida")
	# ---- Escalera bajando 1 → -1 ----
	_building.go_to_floor(1, "escalera")
	await _settle(2)
	_check("Hasta la puerta de bajar (piso 1)", await _goto([Vector3(4.9, 0, 0.4)], 6.0), "")
	await _use("EscaleraBajar")
	await _settle(2)
	fl = _floor()
	if fl is Stairwell:
		var base2: Vector3 = fl.global_position
		_check("Bajar el tramo andando", await _goto([base2 + Vector3(-1.15, 3.2, 2.2), base2 + Vector3(-1.15, 1.6, 5.6), base2 + Vector3(1.15, 1.6, 5.6), base2 + Vector3(1.15, 0, 1.0)], 14.0), "y=%.2f" % _player.global_position.y)
		await _shot("escalera_bajada")
		await _use("Puerta_salida")
		await _settle(2)
	_check("Llegar al -1 por la escalera", _building.current_floor == -1, "piso %d" % _building.current_floor)
	# ---- Comprobaciones globales ----
	await _interactables_respond()
	_rescues_final = _player.fall_rescues
	_check("Red de seguridad: 0 caídas en todo el recorrido", _rescues_final == 0, "%d rescates %s" % [_rescues_final, str(_player.fall_log)])
	_check("Zonas de Fatiga/entradas respondieron", true, "recorrido completo")
	_log_check()
	_write_report()


## Todos los interactuables de cada piso devuelven una pista (hint_text) sin error.
func _interactables_respond() -> void:
	for f in [-1, 1, 2, 9]:
		_building.go_to_floor(f, "ascensor")
		await _settle(2)
		var total := 0
		var empty: Array[String] = []
		for n in get_tree().get_nodes_in_group("interactables"):
			if not (n is Interactable) or not _floor().is_ancestor_of(n):
				continue
			total += 1
			var h: String = (n as Interactable).hint_text()
			if h == "" and (n as Interactable).enabled and not (n is WorldObjects.Seat):
				empty.append(str(n.name))
		_check("Interactuables del piso %d responden" % f, empty.size() <= 2, "%d objetos, sin pista: %s" % [total, str(empty)])


## Las capturas del menú y opciones a varias resoluciones (UI responsive) las hace tools/qa_tour.sh con
## `--shot menu|opciones --resolution WxH` (bajo xvfb un window_set_size en caliente no cambia el tamaño real).


## El log de Godot de esta sesión no debe tener errores de script ni nodos nulos.
func _log_check() -> void:
	var f := FileAccess.open("user://logs/godot.log", FileAccess.READ)
	if f == null:
		_check("Log sin errores", true, "sin archivo de log")
		return
	var script_errors := 0
	var node_errors := 0
	var other := 0
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("SCRIPT ERROR"):
			script_errors += 1
		elif l.contains("Node not found") or l.contains("null instance") or l.contains("Nonexistent"):
			node_errors += 1
		elif l.begins_with("ERROR:") and not l.contains("ALSA") and not l.contains("audio") and not l.contains("status < 0") and not l.contains("V-Sync") and not l.contains("XDG"):
			other += 1
	f.close()
	_check("Log sin SCRIPT ERROR", script_errors == 0, "%d" % script_errors)
	_check("Log sin nodos nulos / no encontrados", node_errors == 0, "%d" % node_errors)
	_check("Log sin otros ERROR", other == 0, "%d" % other)


func _write_report() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("..")
	var path := root.path_join("docs/QA_v0.1.1.md")
	# v0.3 P6b: con --qa-out el informe va a esa carpeta (QA_tour.md) y docs/QA_v0.1.1.md no se toca.
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--qa-out")
	if oi >= 0 and oi + 1 < args.size():
		DirAccess.make_dir_recursive_absolute(args[oi + 1])
		path = args[oi + 1].path_join("QA_tour.md")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("[qa] no se pudo escribir ", path)
		return
	f.store_line("# QA jugado · AVAILABLE v%s" % str(ProjectSettings.get_setting("application/config/version", "")))
	f.store_line("")
	f.store_line("Recorrido automático con el controlador real del jugador (`godot --path game -- --qa-tour`, %s), %s. Capturas en `%s`." % [Time.get_datetime_string_from_system(), "con pantalla (xvfb, OpenGL 3 / llvmpipe)" if not _headless else "headless (sin capturas)", _out_dir])
	f.store_line("")
	f.store_line("**Resultado: %d PASS · %d FAIL · %d rescates de la red de seguridad · %d capturas.**" % [_passes, _fails, _rescues_final, _shots])
	f.store_line("")
	f.store_line("| Comprobación | Resultado | Detalle |")
	f.store_line("|---|---|---|")
	for l in _report:
		f.store_line(l)
	f.close()
	print("[qa] informe: ", path)


# ---------------------------------------------------------------------------
# --random-walk (P7)
# ---------------------------------------------------------------------------

func _random_walk(minutes: float) -> void:
	_player.safety_enabled = true
	GameState.flags["revision_ok"] = true
	GameState.flags["azotea_abierta_dev"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7707
	var sim := 0.0
	var trips := 0
	var reached := 0
	var stuck: Array[String] = []
	var floors_seen: Dictionary = {}
	var meters := 0.0
	var doors := 0
	var locked_skips := 0
	var changes := {"ascensor": 0, "escalera": 0}
	var t_start := Time.get_ticks_msec()
	while sim < minutes * 60.0:
		var t0 := Time.get_ticks_msec()
		# Cambio de piso cada 4 destinos: por ascensor o por la escalera (entra a la caja y sale en el destino).
		if trips % 4 == 0:
			var floors: Array = [-1, 1, 2, 9]
			var dest: int = floors[rng.randi() % floors.size()]
			if dest != _building.current_floor:
				if rng.randf() < 0.4 and _building.current_floor in [-1, 1, 2] and dest in [-1, 1, 2]:
					var up := dest > _building.current_floor
					var cur := _building.current_floor
					var nxt := (1 if cur == -1 else cur + 1) if up else (-1 if cur == 1 else cur - 1)
					_building.go_to_stairwell(nxt, up)
					await _settle(4)
					# camina un tramo dentro de la caja antes de salir
					var g0 := Pursuit.grid_for(_building.floor_node)
					if g0 != null and not g0.heights.is_empty():
						var ks: Array = g0.heights.keys()
						await _rw_route(g0, g0.pos_of(ks[rng.randi() % ks.size()]))
					changes["escalera"] += 1
				else:
					changes["ascensor"] += 1
				_building.go_to_floor(dest, "ascensor")
				await _settle(4)
		floors_seen[_building.current_floor] = true
		var g := Pursuit.grid_for(_building.floor_node)
		if g == null or g.heights.is_empty():
			await _settle(2)
			continue
		var keys: Array = g.heights.keys()
		var target := g.pos_of(keys[rng.randi() % keys.size()])
		var from := _player.global_position
		var res: Dictionary = await _rw_route(g, target)
		doors += int(res["doors"])
		trips += 1
		if bool(res["ok"]):
			reached += 1
		elif bool(res.get("llave", false)):
			locked_skips += 1  # detrás de una puerta con llave por reglas (sala de training en T1…): no es un atasco
		else:
			var dn := _nearest_door(6.0)
			var dl := _nearest_door(6.0, true)
			stuck.append("piso %d (%.1f, %.1f) → (%.1f, %.1f) · puerta cerca: %s / con llave: %s" % [_building.current_floor, _player.global_position.x, _player.global_position.z, target.x, target.z, str(dn.get_path()) if dn != null else "—", str(dl.get_path()) if dl != null else "—"])
			_player.teleport(target + Vector3(0, 0.05, 0), _player.rotation_degrees.y)  # sigue desde el destino
			await _settle(2)
		meters += from.distance_to(_player.global_position)
		sim += (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale
	var rescues := _player.fall_rescues
	var note := "%d destinos, %d alcanzados, %d tras puerta con llave, %d atascos, %d caídas rescatadas, %.0f m, %d puertas abiertas, pisos %s, cambios %s, %.1f min de juego en %.0f s de pared" % [trips, reached, locked_skips, stuck.size(), rescues, meters, doors, str(floors_seen.keys()), str(changes), sim / 60.0, (Time.get_ticks_msec() - t_start) / 1000.0]
	for s in stuck:
		print("[rw]   atasco: " + s)
	if _jump_on:
		note += ", %d saltos (%d registrados por el jugador), %d salidas de muebles" % [jumps_tried, _player.jumps, _player.unstuck_count]
	_check("Paseo al azar sin caídas ni atascos", rescues == 0 and stuck.size() <= maxi(1, trips / 100), note)


## Va a `target` por la rejilla; si se traba, abre la puerta más cercana (≤ 2 m) y reintenta una vez.
func _rw_route(g: Variant, target: Vector3, replans: int = 2) -> Dictionary:
	var doors := 0
	var pts: PackedVector3Array = g.find_path(_player.global_position, target)
	for p in pts:
		var ok := await _drive_to(p, 8.0)
		if not ok and _flat_dist(p) < 0.8:
			ok = true  # la rejilla de Pursuit (cuerpo de 0,3 m) llega más pegada a los muebles que la cápsula del jugador
		if not ok:
			var d := _nearest_door(2.2)
			if d != null:
				d.interact(_player)
				doors += 1
				await _settle(12)
				ok = await _drive_to(p, 8.0) or _flat_dist(p) < 0.8
			if not ok and replans > 0:
				# Esquina cortada por la rejilla (cuerpo 0,3 m contra la cápsula del jugador): un paso atrás y nueva ruta
				# desde donde quedó, como haría un jugador.
				var away := -_player.global_transform.basis.z * -1.0  # hacia atrás
				var col := _player.get_last_slide_collision()
				if col != null:
					away = col.get_normal()
				away.y = 0.0
				if away.length() > 0.01:
					await _drive_to(_player.global_position + away.normalized() * 0.7, 1.0)
				else:
					Input.action_press("move_back")
					await _wait(0.25)
					Input.action_release("move_back")
				var r2: Dictionary = await _rw_route(g, target, replans - 1)
				r2["doors"] = int(r2["doors"]) + doors
				return r2
			if not ok:
				var locked := _nearest_door(2.6, true)
				return {"ok": false, "doors": doors, "llave": locked != null}
	return {"ok": true, "doors": doors, "llave": false}


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - _player.global_position.x, p.z - _player.global_position.z).length()


func _nearest_door(r: float, locked_only: bool = false) -> WorldObjects.Door:
	var best: WorldObjects.Door = null
	var bd := r
	for n in _building.floor_node.find_children("*", "", true, false):
		if n is WorldObjects.Door:
			(n as WorldObjects.Door).hint_text()  # las puertas con regla (deck de la azotea) recalculan su llave aquí
		if n is WorldObjects.Door and not (n as WorldObjects.Door).open and (n as WorldObjects.Door).locked == locked_only:
			var dd := _flat_dist((n as Node3D).global_position)
			if dd < bd:
				bd = dd
				best = n
	return best

extends Node
## Haime en la sala de calibración (piso 2, antigua sala de descanso): comportamiento de piso
## (data/comportamientos.json → marcador sala_calibracion). El cerebro es QaFeedback (persistente).
## Haime está sentado frente a tu silla, de espaldas al ladrillo, con el monitor del REC. Cuando te llama
## se asoma a la puerta de la sala de PCs y te mira (si estás en el piso); durante el feedback se inclina
## hacia ti; en el 3.º se levanta despacio.
## v0.3.1 Q2 (C5, F6/F4): look_at_player(on) — te mira de frente todo el feedback (cabeza y cuello siguen tu cámara);
## set_severity(0..3) — la cara se pone más seria y terrorífica con cada oportunidad (cuencas que se oscurecen, cejas
## que bajan, pupilas rojas, piel gris; en el 3 ya tiembla y se estira apenas). Sin terminal Fonex en la sala: el AUX
## de Coaching te lo pone él (Q1).
## v0.3.2 (Joan: suspenso, tensión, agresivo): comportamiento de la sala durante la calibración (QaFeedback lo llama):
## room_session(on, nivel) — la puerta (aparece abierta y se cierra con seguro: lock_door/unlock_door) y las luces de la
## sala, que bajan con cada error (set_dim) y se apagan en el salto (blackout) · lean(k) — se inclina sobre la mesa hacia
## ti · in_face(on) — de pie, encima de tu cara · slam() — golpea la mesa (la mesa salta) · grab_headset(on) — te
## arranca el auricular (brazos del ScreamRig a tu cabeza). Nivel 1 sentado; 2 se levanta con el golpe.
## v0.3.2 (la última advertencia y la fatal): empieza sentado y quieto (más calmado que nunca) y se va acercando:
## rise() — se pone de pie sin golpe · behind(on) — de pie detrás de tu silla (su silla queda vacía) · brace(on) — de
## pie a su lado de la mesa con las dos manos sobre ella (la pose de la que salta el screamer de la calibración final) ·
## fail_light() — una luz de la sala muere y no vuelve en la sesión (la roja del REC queda).
## v0.3.2 (dirección de las cuatro calibraciones, tras verlas en pantalla):
## · Luz de verdad. La sala la alumbraban, además de su panel y su relleno, una decena de luces de afuera (núcleo, anexo
##   norte: las omni no tienen sombras y cruzan las paredes), así que «apagar la sala» no la oscurecía: lo hacía el velo
##   de la pantalla, y al irse la pantalla con la última frase de la fatal la sala quedaba clara. Ahora _collect_lights
##   junta también esas luces de afuera (set_outside(k) las baja en la advertencia y la fatal) y las luces mueren en
##   orden: el panel del techo, el relleno, la claridad de afuera; queda solo el rojo del REC (rec_only), que es como la
##   deja la sesión fatal para el screamer. La pizarra blanca y el tubo del panel bajan con su luz.
## · Poses con los clips del paquete de animación (NpcAnimator): de pie se apoya con las dos manos en la mesa
##   («lean_in»), se levanta despacio con «stand_up» (rise), queda de pie y derecho (upright), golpea con «slam_table»;
##   ya no es un cuerpo rígido inclinado desde los pies con los brazos colgando.
## · El monitor de QA (con su REC) tapaba medio cuerpo de Haime sentado: se corre 27 cm hacia el vidrio al cargar el piso.
## · Contrato con el paquete de muertes (calibracion_final): al pedir la muerte Haime sigue en el grupo
##   `p5_haime_actor`, con `actor` visible, de pie a su lado de la mesa con las manos sobre ella, y la sala a oscuras con
##   el rojo del REC. En death_sequence_started NO se esconde ni se libera el actor ni se devuelven las luces (hold_for_death):
##   el screamer toma su pose y lo esconde él; la sala vuelve al reaparecer o al volver al menú (release_after_death).

var floor_node: FloorBase = null
var actor: P5Actor = null
var _seat_pos: Vector3 = Vector3.ZERO
var _seat_rot: float = 0.0
var _red: OmniLight3D = null
var _session_n: int = 0
var _t: float = 0.0
var _door_left: float = 0.0
var _looking: bool = false
var severity: int = 0
var _rig: ScreamRig = null
# v0.3.2: sala de calibración durante la sesión.
var _nivel: int = 0
var _lean: float = 0.0
var _standing: bool = false
var _face: bool = false
var _grab_t: float = 0.0  # >0: manos en la mesa (golpe)
var _headset: bool = false
var _behind: bool = false
var lights_dead: int = 0
var _door_pivot: Node3D = null
var _door_closed: bool = false
var _lights: Array = []  # [Light3D, energía original, mood_base original, FlickerLight o null]
var dim: float = 0.0
var _blackout_left: float = 0.0
var _table: Node3D = null
var _table_y: float = 0.0
var _table_kick: float = 0.0
const FACE_PITCH := 0.3  # rad: de pie, apoyado en la mesa e inclinado sobre ella hasta tu cara
const MONITOR_SHIFT := 0.27  # m hacia el vidrio: el monitor de QA deja de tapar a Haime sentado
const ROOM := AABB(Vector3(8.5, -0.2, 1.4), Vector3(4.0, 3.4, 2.9))  # la sala (con sus paredes)
const REACH := 0.85  # una luz de afuera cuenta si la sala está dentro del 85 % de su radio
var _upright: bool = false  # de pie y derecho (no apoyado en la mesa)
var _braced: bool = false
var _rise_left: float = 0.0  # se está levantando despacio (clip stand_up)
var _slam_left: float = 0.0  # el golpe está en el aire: cuando llega a 0 pega (mesa, sonido)
var _slam_cb: Callable = Callable()
var _slam_hold: float = 0.0  # mientras dura el clip del golpe no se le cambia la pose
var outside: float = 1.0  # cuánto llega de las luces de afuera (1 = todo; 0 = nada)
var fill: float = 1.0  # cuánto da el relleno de la sala (la luz que no es el panel del techo); la fatal lo trae casi apagado
var _fill_abs: bool = false
var rec_only: bool = false  # solo queda el rojo del REC
var _board: MeshInstance3D = null
var _board_mat: Material = null
var _held_for_death: bool = false
var _sick: float = -1.0  # ritmo de fallas del tubo pedido por la sesión (sick_light); −1 = el del piso
var _rebase: Dictionary = {}  # estado de la sesión guardado mientras el pase gráfico cambia las bases de las luces
var _has_clips: bool = false  # el modelo trae los clips del paquete de animación (lean_in, stand_up, slam_table)


func setup_behaviour(fl: Node, _marker: Node, _entry: Dictionary) -> void:
	floor_node = fl as FloorBase
	PersonajesP5.ensure(get_tree())
	var spot := floor_node.find_child("haime_sitio", true, false) as Node3D
	if spot == null:
		return
	_seat_pos = spot.global_position
	_seat_rot = spot.global_rotation.y
	actor = P5Actor.make(floor_node, "haime", 1.78, Vector3.ZERO, 0.0, "Haime")
	actor.global_position = _seat_pos
	actor.rotation.y = _seat_rot
	actor.floor_ref = floor_node
	actor.speed = 1.3
	actor.play("sit", true, 0.6, ["idle"])
	_red = OmniLight3D.new()
	_red.light_color = Color(0.95, 0.12, 0.1)
	_red.light_energy = 0.0
	_red.omni_range = 3.5
	_red.shadow_enabled = false
	floor_node.add_child(_red)
	_red.global_position = _seat_pos + Vector3(0.6, 1.3, 0.0)
	_red.set_meta("no_mood", true)
	# v0.3.1 (F4): ya no hay terminal Fonex en la sala de calibración (solo en las PCs de operaciones).
	_rig = ScreamRig.attach(actor.model, "haime") if actor.model != null else null
	_has_clips = actor.animator != null and actor.animator.has_clip("lean_in") and actor.animator.has_clip("stand_up")
	_shift_monitor()
	add_to_group("p5_haime_actor")
	add_to_group(GfxLights.SCRIPTED_GROUP)  # v0.3.2-final: el pase gráfico avisa antes y después de cambiar las bases de las luces
	EventBus.respawned.connect(_on_respawned)
	EventBus.death_sequence_started.connect(_on_death)
	EventBus.returned_to_menu.connect(release_after_death)


## El monitor de QA estaba justo entre tu silla y la de Haime (z 2,82..3,38 con él en z 2,85): sentado se le veía media
## cabeza. Se corre hacia el vidrio con su punto REC, sus rótulos y su luz roja (una vez, al cargar el piso).
func _shift_monitor() -> void:
	if floor_node == null or floor_node.has_meta("h2_monitor"):
		return
	floor_node.set_meta("h2_monitor", true)
	for nm in ["MonitorQA", "RecPunto", "RecTexto", "LuzRec"]:
		var n := floor_node.find_child(nm, true, false) as Node3D
		if n != null:
			n.position.z += MONITOR_SHIFT
	# El rótulo de la pantalla («CALIBRACIÓN…») no tiene nombre: es el Label3D pegado al monitor.
	var mon := floor_node.find_child("MonitorQA", true, false) as Node3D
	if mon != null:
		for c in floor_node.get_children():
			if c is Label3D and c.name != "RecTexto" and (c as Label3D).position.distance_to(mon.position - Vector3(0, 0, MONITOR_SHIFT)) < 0.12:
				(c as Label3D).position.z += MONITOR_SHIFT


func _on_respawned(_k: String) -> void:
	release_after_death()
	_back_to_seat()


## Muerte por la calibración final: el Haime del mundo queda donde está (de pie, las manos en la mesa, visible) y la
## sala como la dejó la sesión; el screamer del paquete de muertes toma su pose y lo esconde él. En las demás muertes
## de Haime (inasistencia) su screamer aparece donde estés: el de la sala se esconde como antes.
func _on_death(c: String, killer: String, _d: String) -> void:
	if killer != "haime" or actor == null or not is_instance_valid(actor):
		return
	if c == "calibracion_final" and _held_for_death:
		return
	actor.visible = false


## QaFeedback lo llama justo antes de pedir la muerte de la calibración final: la sala y Haime no se tocan hasta
## reaparecer (release_after_death).
func hold_for_death() -> void:
	_held_for_death = true


func held_for_death() -> bool:
	return _held_for_death


## Fin de la muerte (reapareciste o volviste al menú): la sala vuelve a la normalidad y Haime a su silla.
func release_after_death() -> void:
	if not _held_for_death:
		return
	_held_for_death = false
	room_session(false, 0)
	session_mode(false, 0)


## C5: te mira de frente (cabeza y cuello) mientras on.
func look_at_player(on: bool) -> void:
	_looking = on


## C5: severidad de la cara 0..3 (una por oportunidad del feedback).
func set_severity(level: int) -> void:
	severity = clampi(level, 0, 3)
	if _rig != null and is_instance_valid(_rig):
		_rig.severity = severity / 3.0
		_rig.deform = 0.1 if severity >= 3 else 0.0
		_rig.tremor = 0.4


func _back_to_seat() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.visible = true
	actor.stop_walking("sit")
	actor.global_position = _seat_pos
	actor.rotation = Vector3(0.0, _seat_rot, 0.0)
	actor.look_toward(Vector3.INF)
	_session_n = 0
	_door_left = 0.0
	_looking = false
	set_severity(0)


## Se asoma a la entrada de la sala de PCs y te mira unos segundos (cuando te llama).
func appear_at_door() -> void:
	if actor == null or not is_instance_valid(actor) or GameState.current_floor != 2:
		return
	# v0.3.1 pisos: el piso puede marcar dónde asomarse (haime_puerta); si no, junto a la entrada de la sala.
	var m := floor_node.find_child("haime_puerta", true, false) as Node3D
	var off := Vector3.ZERO
	if m == null:
		m = floor_node.find_child("entrada_sala", true, false) as Node3D
		off = Vector3(-1.2, 0, 1.4)
	if m == null:
		return
	actor.global_position = m.global_position + off
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		actor.face_now(pl.global_position)
		actor.look_toward(pl.global_position)
	actor.play("stare_camera", true, 0.5, ["idle"])
	_door_left = 7.0


func session_mode(on: bool, n: int) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if not on and _held_for_death:
		return  # la muerte de la calibración final: se queda como está hasta reaparecer
	_session_n = n if on else 0
	if on:
		_back_to_seat()
		_session_n = n
		_looking = true
		set_severity(clampi(n - 1, 0, 3))
		actor.play("sit", true, 0.6, ["idle"])
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null:
			actor.look_toward(pl.global_position)
	else:
		actor.play("sit", true, 0.6, ["idle"])
		actor.global_position = _seat_pos
		actor.rotation = Vector3(0.0, _seat_rot, 0.0)
		actor.look_toward(Vector3.INF)
		_looking = false
		set_severity(0)


func _process(delta: float) -> void:
	_t += delta
	if actor == null or not is_instance_valid(actor):
		return
	if _rig != null and is_instance_valid(_rig):
		var pl := get_tree().get_first_node_in_group("player") as Player
		var want := 1.0 if (_looking or _door_left > 0.0) and pl != null else 0.0
		_rig.look = move_toward(_rig.look, want, delta * 2.0)
		if pl != null and pl.camera != null:
			_rig.look_at_point = pl.camera.global_position
	if _door_left > 0.0:
		_door_left -= delta
		if _door_left <= 0.0:
			_back_to_seat()
	if _red != null:
		var target := 0.0
		if rec_only:
			# Solo queda el REC: un rojo corto que late despacio sobre la mesa y su cara; el resto de la sala, negro.
			target = 0.5 + 0.22 * absf(sin(_t * 2.2))
		elif _session_n > 0 and _nivel >= 3:
			# La advertencia y la fatal: el rojo no ilumina la sala (con las blancas bajas la dejaba rosada, no oscura): es
			# un brillo corto sobre la mesa y su pecho que se nota más cuanto menos luz queda.
			target = 0.3 + 0.15 * absf(sin(_t * 2.6))
		elif _session_n > 0:
			target = 0.9 + 0.5 * absf(sin(_t * (1.5 + _session_n)))
		elif fmod(_t, 2.0) < 1.0:
			target = 0.15
		if not rec_only and GfxQuality.is_light():
			# Modo liviano: solo hay 3 luces encendidas a la vez y casi no llega blanca; este rojo a toda su fuerza teñía
			# de rosado la sala entera (también en la 1.ª y la 2.ª). A la mitad sigue latiendo sobre la mesa.
			target *= 0.5
		else:
			# Media/Alta (v0.3.2-final): la luz nocturna del paquete gráfico deja las paredes de la sala casi sin luz
			# blanca (un solo haz sobre la mesa) y su mapeo de tonos levanta lo oscuro: este rojo, entero, era la luz
			# principal de la sala y la volvía rosada en las cuatro sesiones. El factor sale de la zona de luz
			# (data/gfx_looks.json → "rojo_guion"; "rojo_solo" cuando solo queda el REC); en Baja vale 1.
			target *= GfxDirector.zone_value(_red.global_position, "rojo_solo" if rec_only else "rojo_guion", 1.0)
		_red.light_energy = lerpf(_red.light_energy, target, minf(delta * 6.0, 1.0))
		_red.omni_range = move_toward(_red.omni_range, 2.0 if rec_only else (2.2 if _session_n > 0 and _nivel >= 3 else 3.5), delta * 3.0)
	if _session_n > 0:
		_process_session(delta)
	_process_room(delta)


# --- v0.3.2: la sala durante la calibración ------------------------------------------------------------------------

func _player_cam() -> Camera3D:
	var pl := get_tree().get_first_node_in_group("player") as Player
	return pl.camera if pl != null else null


## Hacia dónde está tu silla desde la suya (eje de la mesa, en el plano).
func _toward_player() -> Vector3:
	var cam := _player_cam()
	if cam == null:
		return Vector3(1, 0, 0)
	var d := cam.global_position - _seat_pos
	d.y = 0.0
	return d.normalized() if d.length() > 0.1 else Vector3(1, 0, 0)


func room_session(on: bool, nivel: int) -> void:
	if floor_node == null:
		return
	if not on and _held_for_death:
		return  # la muerte de la calibración final: la sala queda a oscuras con el REC hasta reaparecer
	if on:
		_nivel = nivel
		_lean = 0.0
		_face = false
		_headset = false
		_behind = false
		_upright = false
		_braced = false
		_rise_left = 0.0
		_slam_left = 0.0
		_slam_hold = 0.0
		lights_dead = 0
		rec_only = false
		outside = 1.0
		fill = 1.0
		_fill_abs = false
		_sick = -1.0
		_standing = false  # v0.3.2: también la advertencia y la fatal empiezan sentado; se levanta en la sesión (rise)
		_collect_lights()
		_board_on()
		set_dim(0.0)
		_make_door()
		_table = floor_node.find_child("MesaCalibracion", true, false) as Node3D
		if _table != null:
			_table_y = _table.position.y
		if actor != null and is_instance_valid(actor):
			actor.play("sit", true, 0.6, ["idle"])
	else:
		_nivel = 0
		_lean = 0.0
		_face = false
		_standing = false
		_behind = false
		_upright = false
		_braced = false
		_rise_left = 0.0
		_slam_left = 0.0
		_slam_hold = 0.0
		_grab_t = 0.0
		lights_dead = 0
		rec_only = false
		outside = 1.0
		fill = 1.0
		_fill_abs = false
		_sick = -1.0
		grab_headset(false)
		unlock_door()
		set_dim(0.0)
		_restore_lights()
		_board_off()
		if _table != null and is_instance_valid(_table):
			_table.position.y = _table_y
		if _door_pivot != null and is_instance_valid(_door_pivot):
			_door_pivot.queue_free()
		_door_pivot = null


## La pizarra blanca detrás de Haime comparte material con medio edificio: durante la sesión lleva uno propio, que se
## apaga con la luz de la sala (si no, quedaba blanca y brillante con la sala «a oscuras»).
func _board_on() -> void:
	_board = floor_node.find_child("PizarraQA", true, false) as MeshInstance3D
	if _board == null or not (_board.material_override is StandardMaterial3D):
		_board = null
		return
	if _board_mat == null:
		_board_mat = _board.material_override
		_board.material_override = (_board_mat as StandardMaterial3D).duplicate()


func _board_off() -> void:
	if _board != null and is_instance_valid(_board) and _board_mat != null:
		_board.material_override = _board_mat
	_board_mat = null
	_board = null


## La puerta de la sala: aparece abierta en el vano (x 11..12,3 del frente de vidrio) y se cierra de golpe.
func _make_door() -> void:
	if _door_pivot != null and is_instance_valid(_door_pivot):
		return
	_door_pivot = Node3D.new()
	_door_pivot.name = "PuertaCalibracion"
	floor_node.add_child(_door_pivot)
	_door_pivot.global_position = Vector3(11.0, 0.0, 4.2)
	var hoja := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 2.25, 0.05)
	hoja.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.21, 0.22)
	mat.roughness = 0.6
	hoja.material_override = mat
	hoja.position = Vector3(0.65, 1.125, 0.0)
	_door_pivot.add_child(hoja)
	var manija := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.12, 0.03, 0.09)
	manija.mesh = mm
	manija.position = Vector3(1.18, 1.0, 0.0)
	_door_pivot.add_child(manija)
	_door_pivot.rotation.y = deg_to_rad(-100.0)  # abierta hacia la sala
	_door_closed = false


func lock_door() -> void:
	if _door_pivot == null or not is_instance_valid(_door_pivot) or _door_closed:
		return
	_door_closed = true
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	AudioManager.play_sfx("qa_puerta_seguro")


func unlock_door() -> void:
	if _door_pivot == null or not is_instance_valid(_door_pivot) or not _door_closed:
		return
	_door_closed = false
	AudioManager.play_sfx("ack_click")
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(-35.0), 0.4)


func door_locked() -> bool:
	return _door_closed


## Luces de la sala: las de adentro (x 8,5..12,5 · z 1,4..4,3, menos las rojas del REC) y las de afuera que la alcanzan
## (las omni no tienen sombras: cruzan las paredes). Cada entrada: [luz, energía original, mood_base original,
## FlickerLight o null, muerta, de_afuera, ráfagas originales del parpadeo].
func _collect_lights() -> void:
	_restore_lights()
	_lights.clear()
	for n in floor_node.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == _red or l is DirectionalLight3D:
			continue
		# v0.3.2-final: en Media/Alta el paquete gráfico cuelga del piso sus propias luces (el haz de cada tubo, el
		# derrame de la sala, el filo rojo del REC), esclavas de las del juego. No son de la sesión: «la luz de tu lado»
		# mataba el haz del tubo (que el paquete volvía a encender en el cuadro siguiente) en vez del relleno de verdad.
		if GfxLights.is_added(l):
			continue
		var p := l.global_position
		var inside := ROOM.has_point(p)
		if not inside:
			var near := Vector3(clampf(p.x, ROOM.position.x, ROOM.end.x), clampf(p.y, ROOM.position.y, ROOM.end.y), clampf(p.z, ROOM.position.z, ROOM.end.z))
			var r := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 0.0)
			if r <= 0.0 or p.distance_to(near) > r * REACH:
				continue
		var fl: FlickerLight = null
		if l.get_parent() != null:
			for c in l.get_parent().get_children():
				if c is FlickerLight and (c as FlickerLight).light == l:
					fl = c
		# Energía de base: la del parpadeo si es un tubo; la «mood_base» si la lleva el ánimo del piso (v0.3.2-final:
		# antes se guardaba la energía del momento, ya bajada por el ánimo, y al aplicarla se volvía a multiplicar por
		# él: con tensión alta la sala quedaba más oscura de lo pedido y cada vuelta de tomar/soltar la bajaba otro poco).
		var e1 := fl.base_energy if fl != null else float(l.get_meta("mood_base", l.light_energy))
		_lights.append([l, e1, float(l.get_meta("mood_base", l.light_energy)), fl, false, not inside, fl.rate if fl != null else 0.0, 1.0])


func _restore_lights() -> void:
	for e in _lights:
		if not is_instance_valid(e[0]):
			continue  # el piso rehízo o quitó esa luz a mitad de la sesión (convertir un objeto liberado es un error)
		var l := e[0] as Light3D
		var fl: FlickerLight = e[3] if is_instance_valid(e[3]) else null
		if fl != null and is_instance_valid(fl):
			fl.base_energy = float(e[1])
			fl.rate = float(e[6])
			_tube(fl, 1.0)
		if l.has_meta("mood_base"):
			l.set_meta("mood_base", float(e[2]))
		l.light_energy = float(e[1]) * (FlickerLight.mood if l.has_meta("mood_base") or fl != null else 1.0)
	_lights.clear()
	_blackout_left = 0.0
	_fill_abs = false
	_board_light(1.0)


## El pase gráfico va a cambiar las energías de base de las luces del piso (cambiaste de calidad en Opciones con la
## sesión en curso: Baja ↔ Media/Alta). Lo que la sesión guardó para devolver al final ya no valdría, y lo que el
## paquete guardara ahora serían luces bajadas por la sesión. Se sueltan las luces (vuelven a su base de antes de
## sentarte) y, cuando el pase termina, se vuelven a tomar con el mismo estado: cuánto bajó la sala, cuánto llega de
## afuera, el relleno, qué luces murieron, el apagón en curso y el ritmo de fallas del tubo.
func gfx_lights_begin() -> void:
	if _lights.is_empty() or not _rebase.is_empty():
		return
	var dead: Array = []
	for e in _lights:
		if bool(e[4]) and is_instance_valid(e[0]):
			dead.append(e[0])
	_rebase = {"dead": dead, "fill_abs": _fill_abs, "blackout": _blackout_left}
	_restore_lights()


func gfx_lights_end() -> void:
	if _rebase.is_empty():
		return
	var st := _rebase
	_rebase = {}
	if floor_node == null or not is_instance_valid(floor_node):
		return
	# Sin _restore_lights(): ya están sueltas (y la pizarra y el apagón no se tocan).
	_lights.clear()
	_collect_lights()
	for e in _lights:
		if (st["dead"] as Array).has(e[0]):
			e[4] = true
	_fill_abs = bool(st["fill_abs"])
	_blackout_left = float(st["blackout"])
	if _sick >= 0.0:
		var rate := _sick
		sick_light(rate)
	_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)


## ¿Es una luz roja (la del REC del monitor)? Esas no bajan ni mueren.
func _is_red(l: Light3D) -> bool:
	return l.light_color.r > 0.8 and l.light_color.g < 0.35


## 0 = luz normal … 0,85 = casi a oscuras (cada error la baja un escalón).
func set_dim(d: float) -> void:
	dim = clampf(d, 0.0, 0.85)
	_apply_lights(1.0 - dim)


## Cuánto llega de las luces de afuera (núcleo, anexo): 1 = como siempre; 0 = la sala solo tiene sus propias luces.
## La advertencia y la fatal la bajan (en la 1.ª y la 2.ª no se toca: su luz es la que ya estaba aprobada).
func set_outside(k: float) -> void:
	outside = clampf(k, 0.0, 1.0)
	_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)


## Cuánto da el relleno de la sala (las luces de adentro que no son el panel del techo). Con `absolute` no baja con
## set_dim (la fatal: el tubo del techo casi no da y el relleno es el que deja ver; cada luz muere a su hora).
func set_fill(k: float, absolute: bool = false) -> void:
	fill = clampf(k, 0.0, 1.0)
	_fill_abs = absolute
	_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)


func _apply_lights(k_all: float) -> void:
	var k_room := 0.0
	var n_room := 0
	for e in _lights:
		if not is_instance_valid(e[0]):
			continue
		var l := e[0] as Light3D
		var red := _is_red(l)
		var k := k_all
		if bool(e[4]):
			k = 0.0  # una luz que murió (fail_light) no vuelve en la sesión
		elif bool(e[5]):
			k = (1.0 if k_all > 0.0 else 0.0) * outside  # las de afuera no bajan con cada error: solo con set_outside y el apagón
		elif red:
			k = 1.0  # el REC del monitor no baja nunca
		elif e[3] == null:
			k = (fill if k_all > 0.0 else 0.0) if _fill_abs else k * fill  # el relleno
		e[7] = k
		var fl: FlickerLight = e[3] if is_instance_valid(e[3]) else null
		var e1 := float(e[1])
		var e2 := float(e[2])
		if _fill_abs and fl == null and not red and not bool(e[5]):
			# El relleno «absoluto» de la fatal (la luz de tu lado es la que deja ver, y muere a su hora) se mide contra
			# la luz que diseñó el piso. En Media/Alta el paquete gráfico la deja casi apagada en reposo (v0.3.2-final:
			# un 47 % de casi nada no alumbraba, y cuando «moría» no se notaba); durante la fatal vuelve a contar.
			var design := GfxDirector.design_energy(l) * GfxDirector.zone_value(l.global_position, "relleno_guion", 1.0)
			if design > 0.0:
				e1 = design
				e2 = design
		if fl != null and is_instance_valid(fl):
			fl.base_energy = e1 * k
			_tube(fl, k)
		if l.has_meta("mood_base"):
			l.set_meta("mood_base", e2 * k)
		l.light_energy = e1 * k * (FlickerLight.mood if l.has_meta("mood_base") or fl != null else 1.0)
		if not bool(e[5]) and not red:
			k_room += k
			n_room += 1
	_board_light(k_room / float(maxi(n_room, 1)) if _nivel >= 3 or k_all <= 0.0 else 1.0)


## El tubo del panel (su material emisivo propio, FlickerLight._mat) acompaña a su luz; muerto, tampoco parpadea.
func _tube(fl: FlickerLight, k: float) -> void:
	var m: Variant = fl.get("_mat")
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).emission_energy_multiplier = 2.0 * k
	if k <= 0.001:
		fl.rate = 0.0
		fl.set("_burst_left", 0.0)


func _board_light(k: float) -> void:
	if _board == null or not is_instance_valid(_board) or _board_mat == null:
		return
	var m := _board.material_override as StandardMaterial3D
	var base := _board_mat as StandardMaterial3D
	if m == null or base == null:
		return
	m.emission_energy_multiplier = base.emission_energy_multiplier * clampf(k, 0.0, 1.0)
	m.albedo_color = base.albedo_color * Color(lerpf(0.35, 1.0, clampf(k, 0.0, 1.0)), lerpf(0.35, 1.0, clampf(k, 0.0, 1.0)), lerpf(0.35, 1.0, clampf(k, 0.0, 1.0)), 1.0)


## Apagón de `s` segundos (el salto): todo a negro y vuelve a la luz baja de la sesión.
func blackout(s: float) -> void:
	_blackout_left = s
	_apply_lights(0.0)


func lean(k: float) -> void:
	_lean = maxf(_lean, clampf(k, 0.0, 1.0))


## Fija cuánto se inclina (lean() solo lo sube): después de un susurro en tu cara se retira un poco.
func set_lean(k: float) -> void:
	_lean = clampf(k, 0.0, 1.0)


## Una luz de la sala muere y no vuelve en la sesión: primero el panel del techo, después el relleno; cuando ya no
## queda ninguna blanca adentro, se va la claridad de afuera (el vidrio queda negro). La roja del REC nunca.
## Con `which` se elige cuál: "afuera" (el piso detrás del vidrio se apaga), "relleno" (la de tu lado, la de la
## puerta) o "panel" (el tubo sobre la mesa); si esa ya no está, sigue el orden de siempre.
## false si ya no queda nada que apagar.
func fail_light(which: String = "") -> bool:
	if which == "afuera" and outside > 0.0:
		lights_dead += 1
		set_outside(0.0)
		return true
	if which == "relleno" or which == "panel":
		for e in _lights:
			if not is_instance_valid(e[0]):
				continue
			var l0 := e[0] as Light3D
			if bool(e[4]) or bool(e[5]) or _is_red(l0) or (e[3] == null) != (which == "relleno"):
				continue
			e[4] = true
			lights_dead += 1
			_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)
			return true
	for pass_i in 2:
		for e in _lights:
			if not is_instance_valid(e[0]):
				continue
			var l := e[0] as Light3D
			if bool(e[4]) or bool(e[5]) or _is_red(l):
				continue
			if pass_i == 0 and e[3] == null:
				continue  # primero el panel del techo (el que tiene tubo y parpadeo)
			e[4] = true
			lights_dead += 1
			_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)
			return true
	if outside > 0.0:
		lights_dead += 1
		set_outside(0.0)
		return true
	return false


## Cuánta luz blanca llega ahora a la mesa de la sala (cada luz de adentro y de afuera pesa por su energía y por lo
## que se atenúa hasta el centro de la mesa, como en el motor; las rojas del REC no cuentan). Se mide del piso, no de la
## lista de la sesión: sirve antes, durante y después. Es una medida para pruebas y para afinar, no un valor exacto.
func room_light() -> float:
	var sum := 0.0
	if floor_node == null:
		return sum
	var at := Vector3(10.1, 0.9, _seat_pos.z)
	for n in floor_node.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == _red or l is DirectionalLight3D or _is_red(l) or not l.visible:
			continue
		var r := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 0.0)
		var d := l.global_position.distance_to(at)
		if r <= 0.0 or d >= r:
			continue
		# Un tubo con parpadeo cuenta por su energía de base (no por el instante de una ráfaga).
		var e := l.light_energy
		if l.get_parent() != null:
			for c in l.get_parent().get_children():
				if c is FlickerLight and (c as FlickerLight).light == l:
					e = (c as FlickerLight).base_energy * FlickerLight.mood
		sum += e * pow(1.0 - pow(d / r, 4.0), 2.0) / (1.0 + d * d)
	return sum


## Energía de la luz roja del REC de Haime ahora.
func rec_light() -> float:
	return _red.light_energy if _red != null else 0.0


## ¿Cuántas luces blancas de la sala siguen vivas?
func lights_alive() -> int:
	var n := 0
	for e in _lights:
		if is_instance_valid(e[0]) and not bool(e[4]) and not bool(e[5]) and not _is_red(e[0] as Light3D):
			n += 1
	return n


## El tubo del techo falla más seguido (la advertencia y la fatal: la luz ya está enferma al sentarte).
func sick_light(rate: float) -> void:
	_sick = rate
	for e in _lights:
		var fl: FlickerLight = e[3] if is_instance_valid(e[3]) else null
		if fl != null and not bool(e[4]):
			fl.rate = rate


## Todo muerto menos el rojo del REC: así termina la fatal (y así la recibe el screamer).
func only_rec() -> void:
	while fail_light():
		pass
	rec_only = true
	dim = 0.85
	_apply_lights(0.0 if _blackout_left > 0.0 else 1.0 - dim)


## Clip de pie: apoyado con las dos manos en la mesa (paquete de animación) o, sin esos clips, el de antes. Derecho
## (upright): quieto, los brazos a los lados, mirándote («stare_camera»: es un gesto pedido a mano, así que al hablar
## solo mueve la mandíbula; con «idle» el animador le pondría ademanes de conversación, y Haime no conversa).
func _stand_clip() -> String:
	if _upright and _has_clips:
		return "stare_camera" if actor.animator != null and actor.animator.has_clip("stare_camera") else "idle"
	return "lean_in" if _has_clips else "hunch"


func _play_stand(speed: float = 0.8) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.play(_stand_clip(), false, 1.0 if _upright else speed, ["hunch", "stare_camera", "idle"])


## Se pone de pie despacio, sin golpe (la advertencia: «Mírame»): el clip de levantarse y queda de pie y derecho,
## mirándote desde arriba. Después, lean()/in_face()/brace() lo apoyan en la mesa.
func rise() -> void:
	if actor == null or not is_instance_valid(actor) or _standing:
		return
	_standing = true
	_upright = true
	if _has_clips:
		_rise_left = 1.4
		actor.play("idle", false, 1.0, ["stare_camera"])  # sentado → de pie: el animador mete «stand_up»
	else:
		actor.play("hunch", true, 0.5, ["stare_camera", "idle"])


## De pie y derecho (on) o apoyado en la mesa (off).
func upright(on: bool) -> void:
	if not _standing or _upright == on:
		return
	_upright = on
	if not _behind and not _face:
		_play_stand()


## De pie detrás de tu silla, un poco inclinado sobre ti (su silla queda vacía). off: vuelve a su lado de la mesa, de pie.
func behind(on: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_behind = on
	_face = false
	_standing = true
	_rise_left = 0.0
	var cam := _player_cam()
	var to := _toward_player()
	if on:
		actor.play("stare_camera" if _has_clips else "hunch", false, 0.6, ["hunch", "idle"])
		var base := cam.global_position if cam != null else _seat_pos + to * 1.95
		var p := base + to * 0.6
		actor.global_position = Vector3(p.x, _seat_pos.y, p.z)
		actor.rotation.x = -0.16
	else:
		_upright = false
		_play_stand()
		actor.global_position = _seat_pos + to * _stand_offset()
		actor.rotation.x = _stand_pitch()
	if cam != null:
		actor.face_now(cam.global_position)


## De pie a su lado de la mesa con las dos manos apoyadas en ella, quieto. Es la pose de la que sale el screamer de la
## calibración final («salta la mesa»): la sesión fatal termina así.
func brace(on: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_braced = on
	if on:
		if _behind:
			behind(false)
		_face = false
		_upright = false
		_standing = true
		_rise_left = 0.0
		_lean = 0.6
		_play_stand()
		if not _has_clips:
			_grab_t = 600.0  # sin el clip: las manos van a la mesa con el IK del ScreamRig
	else:
		_grab_t = 0.0
		if _rig != null and is_instance_valid(_rig) and not _headset:
			_rig.grab = 0.0


func is_behind() -> bool:
	return _behind


func is_braced() -> bool:
	return _braced


func is_standing() -> bool:
	return _standing


## ¿De pie y derecho a su lado de la mesa (ni apoyado, ni detrás de ti, ni en tu cara)?
func is_upright() -> bool:
	return _standing and _upright and not _behind and not _face and not _braced


## Cuánto se adelanta de pie sobre la mesa (m desde su silla) y cuánto se inclina (rad): con el clip «lean_in» las manos
## caen en el borde de la mesa con los pies donde estaba la silla; inclinado del todo (lean 1) llega a media mesa.
func _stand_offset() -> float:
	if _upright:
		return 0.05
	return (0.08 + 0.22 * _lean) if _has_clips else 0.3


func _stand_pitch() -> float:
	if _upright:
		return 0.0
	return -(0.15 * _lean) if _has_clips else -(0.22 + 0.2 * _lean)


## De pie al otro lado de la mesa, inclinado sobre ella hasta tu cara (salto, susurro, auricular): las manos plantadas
## a media mesa, la cara a ~0,9 m de la tuya, un poco por encima. Fuera: la pose del nivel.
func in_face(on: bool) -> void:
	_face = on
	if actor == null or not is_instance_valid(actor):
		return
	if on:
		_behind = false
		_standing = true
		_upright = false
		_rise_left = 0.0
		_play_stand()
		var to := _toward_player()
		var p := _seat_pos + to * 0.42
		actor.global_position = Vector3(p.x, _seat_pos.y, p.z)  # de golpe: es un salto
		actor.rotation.x = -FACE_PITCH if _has_clips else -0.5
		var cam := _player_cam()
		if cam != null:
			actor.face_now(cam.global_position)
		if _rig != null and is_instance_valid(_rig) and _nivel >= 3:
			_rig.deform = 0.22
	else:
		if _rig != null and is_instance_valid(_rig):
			_rig.deform = 0.1 if severity >= 3 else 0.0
		if _nivel < 3:
			_standing = _standing and _nivel >= 2


## Golpe en la mesa: se levanta de un salto y descarga el puño (clip «slam_table», con su anticipación); en el momento
## del impacto la mesa salta y `on_hit` (el sonido, el temblor) se dispara. Devuelve cuánto falta para el impacto (s).
func slam(on_hit: Callable = Callable()) -> float:
	if actor == null or not is_instance_valid(actor):
		if on_hit.is_valid():
			on_hit.call()
		return 0.0
	_standing = true
	_upright = false
	_rise_left = 0.0
	_lean = 1.0
	_slam_cb = on_hit
	if _has_clips and actor.animator.has_clip("slam_table"):
		# El puño cae a los 0,5 s del clip; a ×2,8 son 0,18 s: se ve el brazo subir y bajar, y el golpe no llega tarde.
		actor.play("slam_table", true, 2.8, ["lean_in"])
		_slam_left = 0.18
		_slam_hold = 0.75  # el clip entero (2 s a ×2,8); después queda apoyado en la mesa
	else:
		actor.play("hunch", true, 1.0, ["stare_camera", "idle"])
		_grab_t = 0.35
		_slam_left = 0.0001
	return _slam_left


func _slam_hit() -> void:
	_table_kick = 0.18
	if _slam_cb.is_valid():
		_slam_cb.call()
	_slam_cb = Callable()


func grab_headset(on: bool) -> void:
	_headset = on
	if _rig == null or not is_instance_valid(_rig):
		return
	if not on and _grab_t <= 0.0:
		_rig.grab = 0.0


func _process_session(delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var to := _toward_player()
	var cam := _player_cam()
	if _slam_left > 0.0:
		_slam_left -= delta
		if _slam_left <= 0.0:
			_slam_hit()
	if _rise_left > 0.0:
		_rise_left -= delta
	if _slam_hold > 0.0:
		_slam_hold -= delta
	if _behind:
		if cam != null:
			actor.look_toward(cam.global_position)
	elif not _face:
		# Sentado: se inclina hacia ti. De pie: a su lado de la mesa, derecho o apoyado en ella (más adelante cuanto más se inclina).
		var want := _seat_pos + to * (0.12 + 0.22 * _lean) if not _standing else _seat_pos + to * _stand_offset()
		actor.global_position = actor.global_position.move_toward(want, delta * (0.9 if not _standing else (0.5 if _rise_left > 0.0 else 1.6)))
		var pitch := -(0.06 + 0.18 * _lean) if not _standing else _stand_pitch()
		actor.rotation.x = move_toward(actor.rotation.x, pitch, delta * (0.6 if not _standing else 1.2))
		if _standing and _rise_left <= 0.0 and _slam_hold <= 0.0 and actor.current_anim != _stand_clip():
			_play_stand()
		if cam != null:
			actor.look_toward(cam.global_position)
	else:
		actor.rotation.x = -FACE_PITCH if _has_clips else -0.5
	if _rig != null and is_instance_valid(_rig):
		if _grab_t > 0.0:
			_grab_t -= delta
			var tz := Vector3(-to.z, 0, to.x)
			var front := Vector3(actor.global_position.x, 0.78, actor.global_position.z) + to * 0.45
			_rig.grab = 1.0
			_rig.grab_l = front - tz * 0.28
			_rig.grab_r = front + tz * 0.28
			if _grab_t <= 0.0 and not _headset:
				_rig.grab = 0.0
		elif _headset and cam != null:
			var right := cam.global_transform.basis.x
			var fwd := -cam.global_transform.basis.z
			_rig.grab = move_toward(_rig.grab, 0.7, delta * 6.0)
			_rig.grab_l = cam.global_position - right * 0.2 + fwd * 0.32 - Vector3(0, 0.08, 0)
			_rig.grab_r = cam.global_position + right * 0.2 + fwd * 0.32 - Vector3(0, 0.08, 0)


func _process_room(delta: float) -> void:
	if _blackout_left > 0.0:
		_blackout_left -= delta
		if _blackout_left <= 0.0:
			_apply_lights(1.0 - dim)
	if _nivel > 0 or _held_for_death:
		# El tubo del panel sigue a su luz también después de cada ráfaga de parpadeo (FlickerLight lo deja a pleno).
		for e in _lights:
			var fl: FlickerLight = e[3]
			if fl != null and is_instance_valid(fl) and float(fl.get("_burst_left")) <= 0.0:
				var m: Variant = fl.get("_mat")
				if m is StandardMaterial3D and absf((m as StandardMaterial3D).emission_energy_multiplier - 2.0 * float(e[7])) > 0.01:
					(m as StandardMaterial3D).emission_energy_multiplier = 2.0 * float(e[7])
	# (Retenida para la muerte, la mesa es del screamer: salta cuando él la empuja y la devuelve él a su sitio.)
	if _table != null and is_instance_valid(_table) and not _held_for_death:
		if _table_kick > 0.0:
			_table_kick -= delta
			_table.position.y = _table_y + 0.025 * sin(clampf(_table_kick / 0.18, 0.0, 1.0) * PI)
		elif absf(_table.position.y - _table_y) > 0.0001:
			_table.position.y = _table_y

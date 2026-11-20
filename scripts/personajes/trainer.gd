class_name Trainer
extends CharacterBody3D
## Trainer (v0.2, piso 1, T2+): da clase a siluetas en una sala de training con frente de vidrio.
## FSM: DICTAR → MIRAR_PASILLO (cada 14-26 s mira al pasillo 5 s) → si te quedas mirándolo > 4 s,
## ASOMARSE (sale por la puerta) → INTERCEPTAR (viene por el pasillo) → CHARLA de inducción (te bloquea
## 9 s reales y el reloj avanza 10 min de juego) → VOLVER → DICTAR. Desde T3 grita "GAAAA" (screamer no letal)
## antes de la charla: el grito es exclusivo del Trainer (decisión de Joan). Líneas: data/lineas_trainer.json [PROPUESTA].
## Modelo assets/models/trainer.glb + trainer_ropa/trainer_piel; voz: voces/trainer/trainer_gaaaa_01..04.
## v0.3 (P5): el AUX Training lo maneja TrainingControl (personajes/training_control.gd). Mientras te convoca,
## da la sesión o te persigue (P5Pursuit), este Trainer no sale a interceptarte: set_session(true) lo deja
## dictando frente a la pizarra, mirando a la sala; en la persecución se oculta (el cazador es otro actor).

enum State { DICTAR, MIRAR_PASILLO, ASOMARSE, INTERCEPTAR, SCREAMER, CHARLA, VOLVER }

var state: int = State.DICTAR
var board_pos: Vector3 = Vector3.ZERO  # donde dicta (frente a la pizarra, mirando a las siluetas)
var door_in: Vector3 = Vector3.ZERO  # dentro de la sala, junto a la puerta
var door_out: Vector3 = Vector3.ZERO  # en el pasillo, frente a la puerta
var corridor_z: Vector2 = Vector2(-3.2, 3.2)
var corridor_x: Vector2 = Vector2(-5.0, 25.0)
## v0.3.1 pisos: el ala real es una L (hall, pasillo de training y recodo). Si `regions` no está vacío, la intercepción
## recorta tu posición a la región más cercana de la lista (Rect2 en x/z del piso) en vez de al rectángulo de arriba,
## y si estás en otra región que la suya pasa primero por `hub` (el cruce), así no atraviesa paredes (no tiene colisión).
var regions: Array[Rect2] = []
var hub: Vector3 = Vector3.INF
var front_z: float = -4.0
var speed: float = 2.6

var _player: Player = null
var _floor: FloorBase = null
var _door: WorldObjects.Door = null
var _rig: CharacterRig = null
var _path: Array[Vector3] = []
var _timer: float = 0.0
var _look_timer: float = 0.0
var _stare_s: float = 0.0
var _cooldown: float = 0.0
var _talk_left: float = 0.0
var _talk_total: float = 0.0
var _talk_lines: Array = []
var _talk_i: int = 0
var _dictar_timer: float = 8.0
var _label: Label3D = null
var _session: bool = false


func _ready() -> void:
	add_to_group("trainer")
	collision_layer = 4
	collision_mask = 0  # se mueve por rutas fijas (sala → puerta → pasillo): no choca con el greybox
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.85
	shape.shape = cap
	shape.position = Vector3(0, 0.925, 0)
	add_child(shape)
	speed = float(DataLoader.bal("trainer/velocidad_ms", 2.6))
	_rig = CharacterRig.attach(self, "trainer", 1.88)
	if _rig == null:
		# Sin modelo: silueta de cajas con camisa clara (nunca se queda el hueco vacío).
		Greybox.box(self, "Cuerpo", Vector3(0, 0.95, 0), Vector3(0.5, 1.7, 0.32), Color(0.75, 0.72, 0.6), false)
		Greybox.box(self, "Cabeza", Vector3(0, 1.95, 0), Vector3(0.24, 0.26, 0.24), Color(0.62, 0.5, 0.42), false)
	else:
		_rig.play("idle")
		terror_face(GameState.turno >= 1)  # en los turnos, siempre la cara real
	if OS.get_cmdline_user_args().has("--debug-labels"):
		_label = Label3D.new()
		_label.position = Vector3(0, 2.15, 0)
		_label.pixel_size = 0.006
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_label)
	_reset_look_timer()
	EventBus.respawned.connect(func(_k: String) -> void: _abort())
	EventBus.player_floor_changed.connect(func(_f: int) -> void: if _f != 1: _abort())


## p_front_z = z del frente de vidrio de la sala (antes fijo en −4); depth = de la pizarra al vidrio.
func setup(floor_node: FloorBase, player: Player, room_x: float, door: WorldObjects.Door, p_front_z: float = -4.0, depth: float = 3.2) -> void:
	_floor = floor_node
	_player = player
	_door = door
	front_z = p_front_z
	board_pos = Vector3(room_x, 0, p_front_z - depth)
	door_in = Vector3(room_x, 0, p_front_z - 1.0)
	door_out = Vector3(room_x, 0, p_front_z + 1.0)
	global_position = floor_node.global_position + board_pos
	_face_dir(Vector3(0, 0, 1))  # mira a las siluetas (y al vidrio)
	_set_state(State.DICTAR)


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	EventBus.trainer_state_changed.emit(s)
	if _label != null:
		_label.text = ["Dictar", "Mirar", "Asomarse", "Interceptar", "Screamer", "Charla", "Volver"][s]
	if _rig == null:
		return
	match s:
		State.DICTAR:
			_rig.play("idle")
		State.MIRAR_PASILLO:
			_rig.play("stare_camera", true, 1.0, ["idle"])
		State.ASOMARSE:
			_rig.play("peek_door", true, 1.0, ["walk"])
		State.INTERCEPTAR, State.VOLVER:
			_rig.play("walk")
		State.SCREAMER:
			_rig.play("jumpscare_main", false, 1.0, ["jumpscare_alt"])
		State.CHARLA:
			_rig.play("idle")


func _physics_process(delta: float) -> void:
	if _player == null or not GameState.running or GameState.shift_over or get_tree().paused:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
	if _session or _training_busy():
		_session_tick(delta)
		return
	match state:
		State.DICTAR:
			_dictar(delta)
			_look_timer -= delta
			if _look_timer <= 0.0:
				_timer = float(DataLoader.bal("trainer/mirar_pasillo_s", 5.0))
				_set_state(State.MIRAR_PASILLO)
			_watch_stare(delta)
		State.MIRAR_PASILLO:
			_face_target(_player.global_position if _player_on_floor() else global_position + Vector3(0, 0, 1))
			_timer -= delta
			if _timer <= 0.0:
				_reset_look_timer()
				_face_dir(Vector3(0, 0, 1))
				_set_state(State.DICTAR)
			_watch_stare(delta)
		State.ASOMARSE:
			if _follow(delta):
				if _door != null:
					_door.set_open(true)
					AudioManager.play_sfx("puerta_vidrio")
				_set_state(State.INTERCEPTAR)
		State.INTERCEPTAR:
			if not _player_on_floor():
				_go_back()
				return
			var target := _intercept_target()
			var d := target - global_position
			d.y = 0.0
			if d.length() <= 1.3:
				if GameState.turno >= int(DataLoader.bal("trainer/turno_grito", 3)):
					_screamer()
				else:
					_start_talk()
				return
			velocity = d.normalized() * speed * 1.25
			_face_target(target)
			move_and_slide()
		State.SCREAMER:
			_timer -= delta
			if _timer <= 0.0:
				_start_talk()
		State.CHARLA:
			_face_target(_player.global_position)
			_talk_left -= delta
			# La charla cuesta tiempo de turno: el reloj avanza charla_s_juego repartidos en la charla.
			GameState.clock_seconds += delta * float(DataLoader.bal("trainer/charla_s_juego", 600.0)) / maxf(_talk_total, 0.1)
			var step := _talk_total / maxf(_talk_lines.size(), 1)
			var idx := int((_talk_total - _talk_left) / step)
			if idx > _talk_i and idx < _talk_lines.size():
				_talk_i = idx
				_say(_talk_lines[idx])
			if _talk_left <= 0.0:
				_end_talk()
		State.VOLVER:
			if _follow(delta):
				if _door != null:
					_door.set_open(false)
				_face_dir(Vector3(0, 0, 1))
				_reset_look_timer()
				_set_state(State.DICTAR)


## v0.3 (P5): sesión de training en curso (TrainingControl): dicta a la sala sin salir a interceptar.
func set_session(on: bool) -> void:
	_session = on
	if on:
		_abort()
		_face_dir(Vector3(0, 0, 1))
		if _rig != null:
			_rig.play("point", true, 0.8, ["idle"])
	elif _rig != null:
		_rig.play("idle")
	terror_face(true)


## v0.3.2 · «Actualización de campaña»: en los turnos el Trainer tiene su cara real (la textura de grito, la cara
## seria del ScreamRig y una deformación leve), el contraste con el Trainer amable del Training (trainer_amable.gd).
## Las reglas que matan (quiz reprobado, inasistencia) no cambian.
const TERROR_DEFORM := 0.5


func terror_face(on: bool) -> void:
	if _rig == null:
		return
	_rig.set_scream_face(on)
	_rig.set_severity(3 if on else 0)
	_rig.set_deform(TERROR_DEFORM if on else 0.0)
	# Luz fría de frente, baja: la cara real se lee aunque tenga el haz del proyector detrás.
	var l := get_node_or_null("LuzCaraFria") as OmniLight3D
	if l == null and on:
		l = OmniLight3D.new()
		l.name = "LuzCaraFria"
		l.light_color = Color(0.62, 0.78, 0.9)
		l.light_energy = 0.9
		l.omni_range = 2.4
		l.shadow_enabled = false
		l.position = Vector3(0, 1.45, 0.75)
		add_child(l)
	if l != null:
		l.visible = on


func is_terror_face() -> bool:
	return _rig != null and _rig.get_deform() > 0.01


func _training_busy() -> bool:
	var hub := PersonajesP5.get_hub(get_tree())
	return hub != null and hub.training != null and hub.training.state in [TrainingControl.State.LLAMADO, TrainingControl.State.SESION, TrainingControl.State.QUIZ, TrainingControl.State.PERSIGUE]


func _session_tick(delta: float) -> void:
	if state != State.DICTAR:
		_abort()
	_dictar_timer -= delta
	if _session and _player_on_floor() and _player != null:
		# Te mira a ti, no a las siluetas: eres el único que escucha.
		_face_target(_player.global_position)


## Frases de la clase, en voz baja, solo si estás cerca del vidrio.
func _dictar(delta: float) -> void:
	_dictar_timer -= delta
	if _dictar_timer > 0.0:
		return
	_dictar_timer = randf_range(16.0, 28.0)
	if _player_on_floor() and _player.global_position.distance_to(global_position) < 9.0:
		var lines: Array = DataLoader.dict("lineas_trainer").get("dictar", {}).get("lineas", [])
		if not lines.is_empty():
			EventBus.subtitle.emit("trainer", "[Trainer] " + Loc.pick(lines[randi() % lines.size()]), 3.5)


## Si te quedas mirándolo > mirada_s (a < distancia_mirada_m), sale a interceptarte.
func _watch_stare(delta: float) -> void:
	if not _player_on_floor() or _cooldown > 0.0 or GameState.in_calm:
		_stare_s = 0.0
		return
	var to_me := global_position - _player.global_position
	to_me.y = 0.0
	var dist := to_me.length()
	var fwd := -_player.head.global_transform.basis.z if _player.head != null else -_player.global_transform.basis.z
	fwd.y = 0.0
	var looking := dist < float(DataLoader.bal("trainer/distancia_mirada_m", 11.0)) and fwd.normalized().dot(to_me.normalized()) > 0.9 and _player.global_position.z - (_floor.global_position.z if _floor != null else 0.0) > front_z + 0.4
	if looking:
		_stare_s += delta
		if _stare_s >= float(DataLoader.bal("trainer/mirada_s", 4.0)):
			_stare_s = 0.0
			force_intercept()
	else:
		_stare_s = maxf(_stare_s - delta * 2.0, 0.0)


## Sale de la sala a por ti (también lo usan las capturas).
func force_intercept() -> void:
	if state in [State.ASOMARSE, State.INTERCEPTAR, State.SCREAMER, State.CHARLA]:
		return
	_path = [door_in, door_out]
	_set_state(State.ASOMARSE)
	var lines: Array = DataLoader.dict("lineas_trainer").get("asomarse", {}).get("lineas", [])
	if not lines.is_empty():
		EventBus.subtitle.emit("trainer", "[Trainer] " + Loc.pick(lines[randi() % lines.size()]), 3.0)


func _screamer() -> void:
	_set_state(State.SCREAMER)
	_timer = 1.3
	# Cara a medio metro de la cámara, grito GAAAA (clip RENOMBRAR-safe: solo el grito) y sting.
	var cam_pos := _player.global_position + Vector3(0, 0, 0)
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	global_position = cam_pos + fwd.normalized() * 0.7
	_face_target(_player.global_position)
	var lines: Array = DataLoader.dict("lineas_trainer").get("grito", {}).get("lineas", [])
	var txt := Loc.pick(lines[randi() % lines.size()]) if not lines.is_empty() else "¡GAAAA!"
	AudioManager.play_voice("trainer", "trainer_gaaaa_%02d" % (randi() % 4 + 1), txt, "Sala")
	AudioManager.play_sting()
	Fatigue.add(float(DataLoader.bal("trainer/grito_fatiga", 10.0)))
	EventBus.distortion_triggered.emit("trainer_grito")
	_player.input_locked = true


func _start_talk() -> void:
	_set_state(State.CHARLA)
	_talk_total = float(DataLoader.bal("trainer/charla_real_s", 9.0))
	_talk_left = _talk_total
	_talk_lines = DataLoader.dict("lineas_trainer").get("charla", {}).get("lineas", [])
	_talk_i = -1
	_player.input_locked = true
	_player.velocity = Vector3.ZERO
	EventBus.trainer_talk.emit(_talk_total)
	EventBus.show_message.emit(Loc.fmt(tr("MSG_TRAINER_CHARLA"), {"min": int(float(DataLoader.bal("trainer/charla_s_juego", 600.0)) / 60.0)}), 4.0)
	if not _talk_lines.is_empty():
		_talk_i = 0
		_say(_talk_lines[0])


func _say(line: Variant) -> void:
	EventBus.subtitle.emit("trainer", "[Trainer] " + Loc.pick(line), 3.0)


func _end_talk() -> void:
	Fatigue.add(float(DataLoader.bal("trainer/charla_fatiga", 6.0)))
	if _player != null and not Checkpoints.dying:
		_player.input_locked = false
	_cooldown = float(DataLoader.bal("trainer/cooldown_intercepcion_s", 60.0))
	_go_back()


func _go_back() -> void:
	_path = [door_out, door_in, board_pos]
	_set_state(State.VOLVER)


## Corta lo que esté haciendo (muerte, cambio de piso) y vuelve a la pizarra.
func _abort() -> void:
	if state == State.CHARLA or state == State.SCREAMER:
		if _player != null and not Checkpoints.dying:
			_player.input_locked = false
	if _door != null:
		_door.set_open(false)
	if _floor != null:
		global_position = _floor.global_position + board_pos
	_path.clear()
	_stare_s = 0.0
	_cooldown = maxf(_cooldown, 20.0)
	_face_dir(Vector3(0, 0, 1))
	_set_state(State.DICTAR)


func _follow(delta: float) -> bool:
	if _path.is_empty():
		return true
	var target: Vector3 = (_floor.global_position if _floor != null else Vector3.ZERO) + _path[0]
	target.y = global_position.y
	var d := target - global_position
	if d.length() < maxf(0.35, speed * delta * 1.1):
		_path.remove_at(0)
		return _path.is_empty()
	velocity = d.normalized() * speed
	_face_target(target)
	move_and_slide()
	return false


## Punto al que va en la intercepción: tu posición recortada al pasillo (o a la L de regiones, pasando por el cruce).
func _intercept_target() -> Vector3:
	var origin := _floor.global_position if _floor != null else Vector3.ZERO
	var target := _player.global_position
	if regions.is_empty():
		target.x = clampf(target.x, corridor_x.x, corridor_x.y)
		target.z = clampf(target.z, corridor_z.x, corridor_z.y)
		return target
	var p := Vector2(target.x - origin.x, target.z - origin.z)
	var me := Vector2(global_position.x - origin.x, global_position.z - origin.z)
	var best := Vector2.ZERO
	var best_d := INF
	var best_i := -1
	var my_i := -1
	for i in regions.size():
		var r := regions[i]
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if q.distance_to(p) < best_d:
			best_d = q.distance_to(p)
			best = q
			best_i = i
		if r.grow(0.05).has_point(me):
			my_i = i
	if hub != Vector3.INF and my_i != best_i and Vector2(hub.x, hub.z).distance_to(me) > 0.4:
		var in_hub := false
		for r in regions:
			if r.grow(0.05).has_point(Vector2(hub.x, hub.z)) and r.grow(0.05).has_point(me) and r.grow(0.05).has_point(best):
				in_hub = true
		if not in_hub:
			return origin + Vector3(hub.x, target.y - origin.y, hub.z)
	return origin + Vector3(best.x, target.y - origin.y, best.y)


func _player_on_floor() -> bool:
	return GameState.current_floor == 1 and _player != null and is_instance_valid(_player)


func _face_target(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.z)


func _face_dir(dir: Vector3) -> void:
	rotation.y = atan2(-dir.x, -dir.z)


func _reset_look_timer() -> void:
	_look_timer = randf_range(float(DataLoader.bal("trainer/mirar_cada_s_min", 14.0)), float(DataLoader.bal("trainer/mirar_cada_s_max", 26.0)))

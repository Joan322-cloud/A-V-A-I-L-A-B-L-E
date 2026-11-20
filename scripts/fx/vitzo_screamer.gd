class_name VitzoScreamer
extends Node3D
## Muerte de Vitzo (v0.3.1 Q2, F11): su modelo 3D SALE ARRASTRÁNDOSE del monitor (la pantalla se rompe, cabeza y
## brazos primero, el cuerpo de robot tendido, la pantalla-cara glitcheando) hacia ti.
##   · Si sigues sentado cuando termina de salir: te agarra la cabeza y grita «¡ENVÍENME CORREOOO!» (screamer de la
##     causa: intro "monitor", sigue desde donde quedó este modelo).
##   · Si te paras antes: termina de salir, cae al suelo y te PERSIGUE corriendo (Pursuit.start("vitzo", …, extra
##     {exclusiva, entra_banos}): 5,2 m/s, en cualquier piso, entra a los baños) hasta alcanzarte y saltarte encima
##     (screamer con intro "salto").
## Es muerte segura y en exclusiva (C7): Discipline.freeze(true, "vitzo"), Pursuit.stop de los demás cazadores y
## PersonajesP5.busy = "vitzo" hasta reaparecer. Ningún otro enemigo interviene.
## API: VitzoScreamer.attack(causa) (lo llama Vitzo.email_detected / el recordatorio). VitzoScreamer.play(parent)
## queda como antes (efecto corto sin muerte) para las capturas viejas.

const CRAWL_S := 2.3
const DROP_S := 0.6
const CHASE_SPEED := 5.2
const HUMAN_H := 1.8  # v0.3.2: altura (m, desde 1 m) al salir del monitor; la persecución usa 1,8 m (Pursuit.RIG_OF)
const GROUP := "vitzo_attack"

var cause: String = ""
var phase: String = ""  # arrastre | cayendo | persecucion | agarre
var stood_up: bool = false
var _player: Player = null
var _model: Node3D = null
var _rig: CharacterRig = null
var _start: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD
var _t: float = 0.0
var _monitor: MonitorScreen = null
static var log: Array[String] = []


## Ataque completo (fase 1 en el mundo, fase 2 si te paras). Devuelve el nodo del ataque.
static func attack(p_cause: String) -> VitzoScreamer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(GROUP):
		return n as VitzoScreamer  # ya viene
	var player := tree.get_first_node_in_group("player") as Player
	var b := tree.get_first_node_in_group("building") as Building
	var tut_blocked := GameState.is_tutorial() and not bool(GameState.flags.get("tutorial_permite_muerte", false))
	if player == null or b == null or b.floor_node == null or not Checkpoints.can_die() or tut_blocked:
		Checkpoints.request_death(p_cause, "", "vitzo")
		return null
	_exclusive(true)
	# v0.3.2c: el techo de Master del screamer (pico verdadero ≤ -1 dBTP) rige desde que Vitzo SALE del monitor (vidrios,
	# glitches y el golpe del salto sonaban antes de que empezara el screamer). Si al final no hay muerte, vuelve solo.
	KillGore.master_guard(true)
	KillGore.master_guard(false, 25.0)
	var fx := VitzoScreamer.new()
	fx.name = "VitzoScreamer"
	fx.cause = p_cause
	fx.add_to_group(GROUP)
	b.floor_node.add_child(fx)
	fx._begin(player)
	return fx


## Exclusiva (C7): nadie más interviene mientras Vitzo viene.
static func _exclusive(on: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Discipline.freeze(on, "vitzo")
	var hub := PersonajesP5.get_hub(tree) if tree != null else null
	if hub != null:
		if on:
			hub.busy = "vitzo"
		elif hub.busy == "vitzo":
			hub.busy = ""
	if on:
		for k in ["shero", "trainer", "rta"]:
			if Pursuit.is_hunting(k):
				Pursuit.stop(k, "exclusiva_vitzo")


static func _log(msg: String) -> void:
	log.append(msg)
	if log.size() > 40:
		log.pop_front()
	if OS.get_cmdline_user_args().has("--escenario") or OS.get_cmdline_user_args().has("--shot"):
		print("[vitzo] ", msg)


func _ready() -> void:
	EventBus.respawned.connect(func(_k: String) -> void: _finish())
	EventBus.returned_to_menu.connect(_finish)
	EventBus.shift_started.connect(_finish)


func _finish() -> void:
	_exclusive(false)
	if Pursuit.is_hunting("vitzo"):
		Pursuit.stop("vitzo", "reinicio")
	queue_free()


func _begin(player: Player) -> void:
	_player = player
	_monitor = _pick_monitor()
	var cam := player.camera
	if _monitor != null:
		_start = _monitor.global_position
		_monitor.show_reflection(Faces.texture_at("res://assets/ui/vitzo_cara.png"), CRAWL_S + 0.4)
		_dir = (cam.global_position - _start)
		_dir.y = 0.0
		_dir = _dir.normalized() if _dir.length() > 0.01 else -_monitor.global_transform.basis.z
	else:
		var f := -cam.global_transform.basis.z
		f.y = 0.0
		f = f.normalized()
		_start = player.global_position + f * 7.0 + Vector3(0, 0.9, 0)
		_dir = -f
	_rig = CharacterRig.attach(self, "vitzo", 1.0)
	_model = _rig
	global_position = _start
	if _rig != null:
		_rig.play("walk", true, 1.6, ["run", "idle"])
		var sr := _rig.scream_rig()
		if sr != null:
			sr.look = 1.0
		VitzoGlitch.ramp(self, 0.5, 1.0, CRAWL_S)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.5)
	glow.light_energy = 1.6
	glow.omni_range = 2.6
	glow.shadow_enabled = false
	glow.position = Vector3(0, 0.6, 0)
	add_child(glow)
	_snd("sfx/monitor_rompe", 2.0)
	_snd("sfx/vitzo_arrastre_loop", -2.0)
	_snd("voces/vitzo/vitzo_screamer_capa", -8.0)
	phase = "arrastre"
	stood_up = not player.seated
	_log("sale del monitor (%s) · jugador %s" % ["silla " + GameState.seated_at if _monitor != null else "sin monitor", "sentado" if player.seated else "de pie"])
	EventBus.distortion_triggered.emit("vitzo_sale")


## El monitor derecho de tu silla; si no estás sentado, el monitor más cercano que tengas delante (o ninguno).
func _pick_monitor() -> MonitorScreen:
	var best: MonitorScreen = null
	var best_d := INF
	var p := _player.global_position
	for s in get_tree().get_nodes_in_group("monitor_screens"):
		var ms := s as MonitorScreen
		if ms == null or not ms.is_inside_tree():
			continue
		if _player.seated and ms.seat_id == GameState.seated_at:
			if ms.side == "right" or best == null:
				best = ms
				best_d = 0.0
			continue
		var d := ms.global_position.distance_to(p)
		if best_d > 0.0 and d < best_d and d > 2.5 and d < 14.0:
			best = ms
			best_d = d
	return best


func head_position() -> Vector3:
	return _rig.head_position() if _rig != null else global_position


## Pose de arrastre del modelo de Vitzo: el cuerpo tendido hacia adelante (w = 1) con la cabeza levantada mirándote.
static func crawl_pose(m: Node3D, w: float) -> void:
	if m == null:
		return
	var scene: Node3D = m.get_meta("scene") if m.has_meta("scene") else null
	if scene == null:
		for c in m.get_children():
			if c is Node3D and c.find_children("*", "Skeleton3D", true, false).size() > 0:
				scene = c
				break
	if scene == null:
		return
	# El GLB viene girado 180° (mira a -Z del nodo, hacia ti): +X local tumba la cabeza hacia ti, boca abajo. La
	# cabeza queda en el origen del nodo y el cuerpo detrás (dentro del monitor) para que salga cabeza primero.
	var k := clampf(w, 0.0, 1.0)
	var length := float(CharacterRig.HEIGHTS_V2.get("vitzo", 1.0)) * 0.86  # de los pies a la cabeza, tumbado
	scene.rotation.x = deg_to_rad(72.0) * k
	scene.position = Vector3(0.0, 0.18 * k, length * k)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or Checkpoints.dying:
		return
	_t += delta
	if not _player.seated:
		stood_up = true
	var cam := _player.camera
	match phase:
		"arrastre":
			var u := clampf(_t / CRAWL_S, 0.0, 1.0)
			# Del plano de la pantalla hacia ti: sale la cabeza, los brazos, el cuerpo; baja al escritorio.
			var reach := 0.55 if not stood_up else 1.0
			# Tumbado, la cabeza queda ~0,45 m sobre el origen: sale del centro de la pantalla y baja al escritorio.
			var pos := _start + _dir * (u * reach) + Vector3(0, -0.42 - 0.2 * u, 0)
			global_position = pos
			_face(cam.global_position)
			crawl_pose(_rig, 1.0)
			_look_cam(cam)
			if _monitor != null and int(_t * 12.0) % 4 == 0:
				_monitor.show_reflection(Faces.texture_at("res://assets/ui/vitzo_cara.png"), 0.2)
			if u >= 1.0:
				if stood_up:
					phase = "cayendo"
					_t = 0.0
					_log("te paraste: termina de salir y te persigue")
				else:
					phase = "agarre"
					_log("sigues sentado: te agarra")
					Checkpoints.request_death(cause, "", "vitzo")
					if not Checkpoints.dying:
						_finish()
		"cayendo":
			var u2 := clampf(_t / DROP_S, 0.0, 1.0)
			var floor_y := _player.global_position.y
			global_position = global_position.lerp(Vector3(global_position.x, floor_y, global_position.z) + _dir * delta * 1.2, minf(delta * 8.0, 1.0))
			crawl_pose(_rig, 1.0 - u2)
			# v0.3.2: al salir de la pantalla crece al tamaño de una persona (1 m → 1,8 m).
			scale = Vector3.ONE * lerpf(1.0, HUMAN_H, u2)
			_face(cam.global_position)
			if u2 >= 1.0:
				phase = "persecucion"
				_start_chase()


func _start_chase() -> void:
	var b := get_tree().get_first_node_in_group("building") as Building
	var floor_n := b.current_floor if b != null else 2
	var from := Vector3(global_position.x, _player.global_position.y, global_position.z)
	visible = false
	set_process(false)
	var ok := Pursuit.start("vitzo", cause, CHASE_SPEED, null, "", floor_n, from, Callable(),
		{"asesino": "vitzo", "exclusiva": true, "entra_banos": true, "intenso": true, "sin_aviso": true})
	_log("persecución %s desde (%.1f, %.1f)" % ["empieza" if ok else "NO empezó", from.x, from.z])
	if not ok:
		Checkpoints.request_death(cause, "", "vitzo")
		if not Checkpoints.dying:
			_finish()


func _face(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)


func _look_cam(cam: Camera3D) -> void:
	if _rig == null:
		return
	var sr := _rig.scream_rig()
	if sr != null:
		sr.look = 1.0
		sr.look_at_point = cam.global_position


func _snd(slot: String, db: float) -> void:
	var path := AudioManager.voice_path(slot) if slot.begins_with("voces/") else AudioManager.resolve(slot)
	if path == "":
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(path) as AudioStream
	s.bus = "Sala"
	s.unit_size = 6.0
	s.volume_db = db
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Efecto corto de la v0.3 (sin muerte): Vitzo crece desde la pantalla derecha. Lo usan capturas viejas.
static func play(parent: Node) -> void:
	var player := parent.get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var fx := VitzoScreamer.new()
	fx.name = "VitzoScreamer"
	parent.add_child(fx)
	fx._legacy(player)


func _legacy(player: Player) -> void:
	var cam := player.camera
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var start := eye + fwd * 0.9 - Vector3(0, 0.6, 0)
	var end := eye + fwd * 0.5 - Vector3(0, 0.78, 0)
	global_position = start
	look_at(eye, Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0
	var rig := CharacterRig.attach(self, "vitzo", 1.0)
	if rig != null:
		rig.play("jumpscare_main", false, 1.4, ["jumpscare_alt", "idle"])
	scale = Vector3.ONE * 0.15
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", end, 1.0)
	tw.tween_property(self, "scale", Vector3.ONE * 0.95, 1.0)
	await get_tree().create_timer(1.3).timeout
	queue_free()

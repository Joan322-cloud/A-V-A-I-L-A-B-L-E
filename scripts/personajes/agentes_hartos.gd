class_name AgentesHartos
extends Node
## v0.3.1 Q4 (F22): los demás agentes están HARTOS de las «integraciones» de Rasec. Durante el evento:
## - los compañeros que Rasec saca al centro (rigs cerca del marcador evento_rasec) cabecean, bostezan (la mandíbula
##   se abre despacio), miran el reloj de pulsera y sonríen a la fuerza (TiredPose sobre su esqueleto);
## - dos más se suman por su cuenta: uno sentado en el suelo contra la columna, dormido («zzz»), y otro de pie con
##   los brazos caídos mirando la hora;
## - susurros con subtítulo («otra vez no…», «son las cinco de la mañana») y reacción a lo que le respondes a Rasec;
## - DMs de compañeros quejándose, y al final según el ánimo del grupo (te agradecen o te tratan de traidor).
## Datos: lineas_agentes.json/evento_rasec. Lo crea y lo maneja RasecControl.

var ctl: Node = null
var mood: int = 0  # ánimo del grupo: + te agradecen, − te miran feo
var said: Array[String] = []  # susurros y reacciones dichas (pruebas)
var dms_sent: int = 0
var _poses: Array = []  # TiredPose agregados
var _extras: Array[Node3D] = []
var _t: float = 0.0
var _next_whisper: float = 4.0
var _whisper_i: int = 0
var _active: bool = false
var _dm_i: int = 0
var _zzz: Label3D = null


func _data() -> Dictionary:
	return DataLoader.dict("lineas_agentes").get("evento_rasec", {})


func start() -> void:
	stop()
	_active = true
	mood = 0
	said.clear()
	dms_sent = 0
	_t = 0.0
	_next_whisper = 3.5
	_whisper_i = int(GameState.turno) % 3
	_dm_i = GameState.turno
	_tire_rigs()
	_spawn_extras()
	_dm("durante")


func stop() -> void:
	_active = false
	for p in _poses:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_poses.clear()
	for e in _extras:
		if is_instance_valid(e):
			e.queue_free()
	_extras.clear()
	_zzz = null


func finish() -> void:
	if _active:
		_dm("bien" if mood >= 2 else ("mal" if mood <= -2 else "durante"))
	stop()


func _floor() -> FloorBase:
	return get_tree().get_first_node_in_group("floor") as FloorBase


func _center() -> Vector3:
	var fl := _floor()
	if fl == null:
		return Vector3.ZERO
	var m := fl.find_child("evento_rasec", true, false) as Node3D
	return m.global_position if m != null else fl.global_position


## Los rigs de agentes que ya están en el centro (los trae rasec.gd) se cansan.
func _tire_rigs() -> void:
	var fl := _floor()
	if fl == null:
		return
	var c := _center()
	var k := 0
	for r in fl.find_children("*", "CharacterRig", true, false):
		var rig := r as CharacterRig
		if rig == null or not is_instance_valid(rig):
			continue
		if rig.global_position.distance_to(c) > 4.0 or not _is_agent(rig):
			continue
		_add_pose(rig, k)
		k += 1


## Agentes de la fila C que rasec.gd trae al centro: sus rigs siguen colgados de su cubículo (Cub_C-xx).
func _is_agent(rig: Node) -> bool:
	return rig.get_parent() != null and str(rig.get_parent().name).begins_with("Cub_")


func _add_pose(rig: Node, k: int) -> void:
	var sks := rig.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var tp := TiredPose.new()
	tp.name = "TiredPose"
	tp.style = ["cabecea", "bosteza", "reloj", "sonrisa"][k % 4]
	tp.phase = float(k) * 1.7
	(sks[0] as Skeleton3D).add_child(tp)
	_poses.append(tp)


func _spawn_extras() -> void:
	var fl := _floor()
	if fl == null:
		return
	var c := _center()
	var others: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			others.append(a.to_lower())
	# 1) dormido sentado en el suelo, contra la columna del huddle
	var sleeper := NpcFigure.make(fl, "agente_" + others[(GameState.turno + 1) % others.size()], Vector3.ZERO, 0.0, 1.7, Color.WHITE, "AgenteDormido")
	var sp := _free_spot(fl, c, Vector3(3.0, 0, 0.4), [])  # al borde de la alfombra del huddle, a un lado
	sleeper.global_position = sp + Vector3(0, -0.42, 0)
	sleeper.rotation.y = atan2(c.x - sp.x, c.z - sp.z)  # mirando al huddle, sin verlo
	sleeper.idle_anim = "sit"
	sleeper.anim_speed = 0.0
	_extras.append(sleeper)
	_zzz = Label3D.new()
	_zzz.text = "z z z"
	_zzz.font_size = 40
	_zzz.pixel_size = 0.004
	_zzz.modulate = Color(0.8, 0.85, 0.95, 0.7)
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sleeper.add_child(_zzz)
	_zzz.position = Vector3(0, 1.55, 0)
	_add_pose_later(sleeper, "dormido")
	# 2) de pie, brazos caídos, mirando la hora
	var watcher := NpcFigure.make(fl, "agente_" + others[(GameState.turno + 2) % others.size()], Vector3.ZERO, 0.0, 1.7, Color.WHITE, "AgenteReloj")
	var wp := _free_spot(fl, c, Vector3(-3.0, 0, -0.6), [sp])
	watcher.global_position = wp
	watcher.rotation.y = atan2(c.x - wp.x, c.z - wp.z)
	watcher.idle_anim = "hunch"
	watcher.anim_speed = 0.4
	_extras.append(watcher)
	_add_pose_later(watcher, "reloj")


## Un sitio libre en el suelo alrededor del huddle (sin tabiques, escritorios ni gente), empezando por `prefer`.
func _free_spot(fl: Node3D, c: Vector3, prefer: Vector3, taken: Array) -> Vector3:
	var space := fl.get_world_3d().direct_space_state if fl.is_inside_tree() else null
	if space == null:
		return c + prefer
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.5
	q.shape = sh
	var base := atan2(prefer.x, prefer.z)
	for r in [prefer.length(), 3.4, 2.6, 4.2, 5.0]:
		for k in 12:
			var a := base + float(int((k + 1) * 0.5)) * (PI / 6.0) * (-1.0 if k % 2 == 1 else 1.0)
			var p := c + Vector3(sin(a), 0, cos(a)) * float(r)
			var near := false
			for t in taken:
				if (t as Vector3).distance_to(p) < 1.4:
					near = true
			if near:
				continue
			q.transform = Transform3D(Basis(), p + Vector3(0, 0.75, 0))
			if not space.intersect_shape(q, 1).is_empty():
				continue
			# que se vea desde el huddle: nada entre el sitio y el centro a la altura del pecho
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.9, 0), c + Vector3(0, 0.9, 0))
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or (hit.get("position", c) as Vector3).distance_to(c) < 1.2:
				return p
	return c + prefer


func _add_pose_later(n: NpcFigure, style: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(n) or not _active:
		return
	var sks := n.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var tp := TiredPose.new()
	tp.style = style
	(sks[0] as Skeleton3D).add_child(tp)
	_poses.append(tp)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _zzz != null and is_instance_valid(_zzz):
		_zzz.position.y = 1.55 + 0.08 * sin(_t * 1.3)
		_zzz.modulate.a = 0.4 + 0.3 * absf(sin(_t * 0.9))
	if _t >= _next_whisper:
		_next_whisper = _t + randf_range(7.0, 11.0)
		whisper()


## Un susurro de un compañero (subtítulo con su nombre, voz en susurro).
func whisper() -> void:
	var pool: Array = _data().get("susurros", [])
	if pool.is_empty():
		return
	var l: Dictionary = pool[_whisper_i % pool.size()]
	_whisper_i += 1
	_say(l)


func react(tipo: String, grupo: int) -> void:
	mood += grupo
	var pool: Array = (_data().get("reacciones", {}) as Dictionary).get(tipo, [])
	if pool.is_empty():
		return
	_say(pool[(_whisper_i + said.size()) % pool.size()] as Dictionary)
	for p in _poses:
		if is_instance_valid(p):
			(p as TiredPose).react(tipo)


func _say(l: Dictionary) -> void:
	var voz := str(l.get("voz", ""))
	var who := _name_for(str(l.get("quien", "comp")))
	said.append(voz)
	# v0.3.2-core: los susurros son relleno (must: false): los corta cualquier línea de Rasec y vencen en cola en vez
	# de retrasar sus preguntas; con voz van por play_voice, sin voz como texto de ambiente.
	var txt := "[%s] %s" % [Loc.fmt(tr("Q4_WHISPER_WHO"), {"agente": who}), Loc.pick(l)]
	if voz.contains("/"):
		AudioManager.play_voice(voz.get_slice("/", 0), voz.get_slice("/", 1), "", "Sala", -1, {"must": false})
		EventBus.subtitle.emit("comp", txt, 3.0)
	else:
		VoiceDirector.text("comp", txt, 3.0, {"must": false})


func _name_for(voice: String) -> String:
	var others: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent and a != "Juan":
			others.append(a)
	var i := {"comp": 0, "comp2": 1, "comp3": 2}.get(voice, 0) as int
	return others[i % others.size()] if not others.is_empty() else "C-15"


func _dm(kind: String) -> void:
	var pool: Array = (_data().get("dms", {}) as Dictionary).get(kind, [])
	if pool.is_empty():
		return
	var line: Dictionary = pool[_dm_i % pool.size()]
	_dm_i += 1
	var who := _name_for(["comp", "comp2", "comp3"][_dm_i % 3]).to_lower()
	dms_sent += 1
	EventBus.ezlak_post.emit("dm:" + who, who, Loc.pick(line), {"tipo": "agente_harto", "typing_s": 2.5})


## Pose de cansancio sobre el esqueleto (después de la animación): cabeza que cae, bostezo (mandíbula), mirar la
## muñeca, sonrisa forzada (la cabeza tiesa, temblando), dormido (cabeza al pecho).
class TiredPose extends SkeletonModifier3D:
	var style: String = "cabecea"
	var phase: float = 0.0
	var _t: float = 0.0
	var _kick: float = 0.0
	var _kick_kind: String = ""

	func react(tipo: String) -> void:
		_kick = 1.2
		_kick_kind = tipo

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		_t += get_process_delta_time() if is_inside_tree() else 0.016
		_kick = maxf(_kick - get_process_delta_time(), 0.0)
		var head := sk.find_bone("head")
		var neck := sk.find_bone("neck_01")
		var jaw := sk.find_bone("jaw")
		var spine := sk.find_bone("spine_03")
		var tt := _t + phase
		var pitch := 0.0
		var yaw := 0.0
		var roll := 0.0
		var jaw_open := 0.0
		var slouch := 0.15
		match style:
			"cabecea":
				var nod := fmod(tt, 6.0)
				pitch = 0.55 * smoothstep(1.0, 3.5, nod) * (1.0 - smoothstep(3.6, 3.8, nod))  # se le cae y se despierta
			"bosteza":
				var y := fmod(tt, 7.0)
				jaw_open = 0.45 * smoothstep(0.5, 1.5, y) * (1.0 - smoothstep(2.6, 3.2, y))
				pitch = -0.25 * jaw_open * 2.0
			"reloj":
				var w := fmod(tt, 5.0)
				pitch = 0.6 * smoothstep(0.0, 0.5, w) * (1.0 - smoothstep(2.0, 2.5, w))
				yaw = 0.5 * pitch
				slouch = 0.25
			"sonrisa":
				roll = 0.03 * sin(tt * 23.0)  # tiesa, temblando
				pitch = -0.05
			"dormido":
				pitch = 0.75
				roll = 0.25
				slouch = 0.35
				jaw_open = 0.12
		if _kick > 0.0:
			match _kick_kind:
				"burla": yaw += 0.35 * sin(_kick * 8.0)  # se giran a mirarte, aguantando la risa
				"seguir": pitch -= 0.25 * _kick  # te miran feo
				_: pitch += 0.15 * _kick
		if spine >= 0:
			sk.set_bone_pose_rotation(spine, sk.get_bone_pose_rotation(spine) * Quaternion(Vector3.RIGHT, slouch))
		if neck >= 0:
			sk.set_bone_pose_rotation(neck, sk.get_bone_pose_rotation(neck) * Quaternion(Vector3.RIGHT, pitch * 0.4))
		if head >= 0:
			sk.set_bone_pose_rotation(head, sk.get_bone_pose_rotation(head) * Quaternion.from_euler(Vector3(pitch * 0.6, yaw, roll)))
		if jaw >= 0 and jaw_open > 0.0:
			sk.set_bone_pose_rotation(jaw, sk.get_bone_pose_rotation(jaw) * Quaternion(Vector3.RIGHT, jaw_open))

class_name SleepSpot
extends Interactable
## Lugar para dormir (v0.3 P2, PLAN §2 #30 y §8.2): sofás de la cafetería del -1 y puffs de la zona de
## descanso. [E] te acuestas: la vista baja casi al suelo, los ojos se cierran (Overlays), el reloj corre
## a 30x ("dormido") y la Fatiga baja despacio. [E] o moverte te despierta. SIN reglas: la regla del lunch
## (dormido = WW en vez de muerte, 1 vez por turno) es de Discipline (P3), que escucha:
##   SleepSpot.slept(spot_id) / EventBus.player_slept(spot_id)  y  SleepSpot.woke / EventBus.player_woke().
## Consultas: SleepSpot.sleeping_spot() → id del lugar donde duerme el jugador ("" si está despierto).

signal slept(spot_id: String)
signal woke()

const FATIGUE_PER_GAME_MIN := -0.4

@export var spot_id: String = ""
## Altura del ojo acostado (puff ~0,45 m, sofá ~0,7 m) y hacia dónde queda la cabeza (yaw en grados).
@export var eye_height: float = 0.55
@export var yaw_deg: float = 0.0

static var _current: SleepSpot = null
var _player: Player = null
var _last_clock: float = 0.0


static func sleeping_spot() -> String:
	return _current.spot_id if is_instance_valid(_current) else ""


static func is_player_sleeping() -> bool:
	return is_instance_valid(_current)


func _ready() -> void:
	super._ready()
	add_to_group("sleep_spots")
	EventBus.death_sequence_started.connect(_on_death_seq)
	EventBus.returned_to_menu.connect(_silent_wake)
	EventBus.respawned.connect(_on_respawned)


func _on_death_seq(_c: String, _k: String, _d: String) -> void:
	_silent_wake()


func _on_respawned(_k: String) -> void:
	_silent_wake()


func _silent_wake() -> void:
	wake_up(false)


func hint_text() -> String:
	return tr("HUD_WAKE") if _current == self else tr("HUD_SLEEP")


func interact(player: Node) -> bool:
	if not enabled or not (player is Player):
		return false
	if _current == self:
		wake_up()
		return true
	if is_instance_valid(_current):
		return false
	_player = player as Player
	if _player.seated:
		_player.stand_up()
	_current = self
	_player.lie_down(self)
	_last_clock = GameState.clock_seconds
	if Metrics.aux == Metrics.Aux.LUNCH:
		GameState.set_clock_override("dormido")
	AudioManager.play_sfx("respiracion")
	set_process(true)
	slept.emit(spot_id)
	EventBus.player_slept.emit(spot_id)
	interacted.emit(player)
	return true


func _process(_delta: float) -> void:
	if _current != self:
		set_process(false)
		return
	var dt := GameState.clock_seconds - _last_clock
	if dt >= 60.0:
		_last_clock = GameState.clock_seconds
		Fatigue.add(FATIGUE_PER_GAME_MIN * floorf(dt / 60.0))
	if _player != null and is_instance_valid(_player) and _player.wants_to_wake():
		wake_up()


## Despierta (moverse, [E], muerte, menú o respawn). emit=false: limpieza silenciosa.
func wake_up(emit: bool = true) -> void:
	if _current != self:
		return
	_current = null
	set_process(false)
	GameState.clear_clock_override("dormido")
	if _player != null and is_instance_valid(_player):
		_player.get_up()
		place_out(_player)
	if emit:
		woke.emit()
		EventBus.player_woke.emit()


func _exit_tree() -> void:
	if _current == self:
		_current = null
		GameState.clear_clock_override("dormido")


## v0.3.1 Q5 (bug de Joan 11:19Z: al despertar del sofá quedabas atrapado dentro): al levantarte vas al ancla de
## salida «Salida» (Marker3D hijo, sobre piso libre, mirando hacia afuera). Si el ancla está ocupada (alguien dejó
## algo, un NPC) se busca el primer punto libre alrededor del mueble. Libre = hay suelo a la altura del piso del mueble
## y una cápsula del jugador cabe sin tocar nada.
func exit_marker() -> Marker3D:
	return get_node_or_null("Salida") as Marker3D


func exit_candidates() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var floor_y := (get_parent() as Node3D).global_position.y if get_parent() is Node3D else global_position.y - 0.5
	var m := exit_marker()
	if m != null:
		out.append(Vector3(m.global_position.x, floor_y, m.global_position.z))
	var half := maxf(size.x, size.z) * 0.5
	for r in [0.75, 1.05, 1.4, 1.9]:
		for k in 12:
			var a := TAU * k / 12.0
			out.append(Vector3(global_position.x + cos(a) * (half + r - 0.3), floor_y, global_position.z + sin(a) * (half + r - 0.3)))
	return out


## ¿Cabe el jugador parado en p (p.y = piso)? Devuelve la altura del suelo encontrado o NAN.
func free_spot(p: Vector3, exclude: Array[RID] = []) -> float:
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, -0.6, 0), 1, exclude)
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return NAN
	var fy := float((hit["position"] as Vector3).y)
	if absf(fy - p.y) > 0.35:
		return NAN
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	q.exclude = exclude
	q.transform = Transform3D(Basis(), Vector3(p.x, fy + 0.95, p.z))
	return fy if space.intersect_shape(q, 1).is_empty() else NAN


func place_out(player: Player) -> void:
	var ex: Array[RID] = [player.get_rid()]
	for c in exit_candidates():
		var fy := free_spot(c, ex)
		if is_nan(fy):
			continue
		var away := Vector3(c.x - global_position.x, 0, c.z - global_position.z)
		var m := exit_marker()
		var yaw := atan2(away.x, away.z) + PI if away.length() > 0.01 else player.rotation.y
		if m != null and c.distance_to(Vector3(m.global_position.x, c.y, m.global_position.z)) < 0.01:
			yaw = m.global_rotation.y
		player.global_position = Vector3(c.x, fy + 0.05, c.z)
		player.rotation.y = yaw
		player.velocity = Vector3.ZERO
		return
	push_warning("SleepSpot %s: sin punto libre para levantarse" % spot_id)


## Fábrica: un SleepSpot del tamaño del mueble (el mueble lo dibuja el piso). exit_pos (coordenadas del padre) es
## el ancla donde te levantas, mirando hacia exit_yaw (grados; por defecto, de espaldas al mueble).
static func make(parent: Node, id: String, pos: Vector3, size_v: Vector3, eye_h: float, yaw: float, exit_pos: Vector3 = Vector3.INF, exit_yaw: float = NAN) -> SleepSpot:
	var s := SleepSpot.new()
	s.name = "Dormir_" + id
	s.spot_id = id
	s.hint_key = "HUD_SLEEP"
	s.size = size_v + Vector3(0.3, 0.4, 0.3)
	s.position = pos
	s.eye_height = eye_h
	s.yaw_deg = yaw
	parent.add_child(s)
	if exit_pos != Vector3.INF:
		var m := Marker3D.new()
		m.name = "Salida"
		m.position = exit_pos - pos
		m.position.y = -pos.y
		var away := Vector3(exit_pos.x - pos.x, 0, exit_pos.z - pos.z)
		m.rotation.y = deg_to_rad(exit_yaw) if not is_nan(exit_yaw) else atan2(away.x, away.z) + PI
		s.add_child(m)
	return s

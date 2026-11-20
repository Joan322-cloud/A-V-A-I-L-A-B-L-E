class_name PerritoRTA
extends CharacterBody3D
## Perrito RTA (cuerpo del piso 2): no ve personas, lee estados (GDD 4.1, 6.2). Patrulla los pasillos de la
## sala en serpentina. v0.3 (P5): las reglas viven en RtaControl (personajes/rta_control.gd, persistente:
## órdenes en #allocations, strikes, caza en TODO el edificio con P5Pursuit, cupo de Baño). Este cuerpo solo
## patrulla; cuando te taguea camina hasta tu sitio y se queda olfateándote; durante la caza se oculta (el
## cazador es otro actor que te sigue de piso en piso). Ya no mata por break excedido (es de Shero).
## PerritoRTA.dictate(aux) sigue siendo la API para dictar el AUX esperado (P4: ContactManager, Mentor).
## v0.3.1 Q2 (F19): trabaja SENTADO en su escritorio del RTA (3 monitores de gráficos de adherencia, NpcDesks),
## sobre la silla, mirando las pantallas. Patrulla en su horario (DESK_S en el escritorio, PATROL_S de ronda) y
## vuelve; si te taguea se baja de la silla y va hasta ti.

var patrol_speed: float = 1.5
var _floor: FloorBase = null
var _player: Player = null
var _patrol: PackedVector3Array = PackedVector3Array()
var _patrol_i: int = 0
var _pause: float = 0.0
var _label: Label3D = null
var _rig: CharacterRig = null
var _stare: bool = false
var _stare_path: PackedVector3Array = PackedVector3Array()
var _stare_i: int = 0
var _visitor: bool = false  # instancia que mueve Pursuit (P3) durante la caza: no patrulla
const DESK_S := 70.0
const PATROL_S := 55.0
const CHAIR_Y := 0.5
var at_desk: bool = false
var _desk: Transform3D = Transform3D()
var _has_desk: bool = false
var _sched_t: float = 0.0
var _going_desk: bool = false
var _route: PackedVector3Array = PackedVector3Array()  # v0.3.1 pisos: ruta al escritorio / de vuelta a la sala
var _route_i: int = 0


func _ready() -> void:
	add_to_group("rta")
	collision_layer = 4
	collision_mask = 1
	_label = get_node_or_null("Estado") as Label3D
	if _label != null:
		_label.visible = OS.get_cmdline_user_args().has("--debug-labels")  # etiqueta de estado solo para depurar
	_rig = CharacterRig.attach(self, "perrito_rta", 0.72)
	if _rig != null:
		for c in get_children():
			if c is MeshInstance3D:
				c.visible = false
		_rig.play("walk")
	_dress()
	EventBus.respawned.connect(_on_respawned)
	PersonajesP5.ensure(get_tree())


func setup(floor_node: FloorBase, player: Player) -> void:
	_floor = floor_node
	_player = player
	_patrol.clear()
	# Ruta en serpentina por los pasillos de la sala (el piso la define); si no, los waypoints.
	if floor_node.has_method("patrol_route"):
		_patrol = floor_node.call("patrol_route")
	else:
		for wp in floor_node.waypoints:
			if wp.x > 18.0 and wp.z < 2.0:
				_patrol.append(wp)
	if _patrol.is_empty():
		_patrol.append(floor_node.global_position)
	global_position = _patrol[0]
	NpcDesks.ensure(floor_node)
	_has_desk = NpcDesks.has_seat(floor_node, "rta")
	if _has_desk:
		_desk = NpcDesks.seat(floor_node, "rta")
		_sit_desk()
	var hub := PersonajesP5.get_hub(get_tree())
	if hub != null and hub.rta != null and hub.rta.hunting:
		visible = false


## Pursuit (P3) instancia esta escena como cazador "rta" en el piso donde estés: la mueve él (rutas A*), así que
## este cuerpo no patrulla ni cuenta como el RTA del piso (sale del grupo "rta").
func setup_visitor(floor_node: Node, player: Player) -> void:
	_visitor = true
	_floor = floor_node as FloorBase
	_player = player
	if is_in_group("rta"):
		remove_from_group("rta")
	collision_layer = 0
	if _rig != null:
		_rig.play("run", true, 1.0, ["walk"])


func on_pursuit_move(moving: bool, _speed: float) -> void:
	if _rig != null:
		var clip := "run" if moving else "idle"
		if _rig.current != clip:
			_rig.play(clip, true, 1.0, ["walk"] if moving else ["stare_camera", "walk"])


func _physics_process(delta: float) -> void:
	if _visitor:
		return
	if _player == null or not GameState.running or GameState.shift_over or not GameState.logged_in or not visible:
		return
	if _stare:
		if at_desk:
			_leave_desk()
		_do_stare(delta)
		return
	if _has_desk:
		_sched_t += delta
		if at_desk:
			_face(global_position - _desk.basis.z)  # mira sus pantallas
			if _rig != null:
				_rig.play("idle", true, 0.6, ["sniff"])
			if _sched_t >= DESK_S:
				_sched_t = 0.0
				_leave_desk()
			return
		if _going_desk:
			_walk_to_desk(delta)
			return
		if _sched_t >= PATROL_S:
			_sched_t = 0.0
			_going_desk = true
			_route = _route_to(_desk.origin + _desk.basis.z * 0.7)
			_route_i = 0
			return
	if _route_i < _route.size():
		_follow_route(delta)  # vuelve a la sala por los pasillos (su escritorio está en la sala auxiliar)
		return
	_do_patrol(delta)


## Sentado (de pie sobre la silla) en su escritorio, mirando las pantallas.
func _sit_desk() -> void:
	at_desk = true
	_going_desk = false
	global_position = _desk.origin + Vector3(0, CHAIR_Y, 0)
	rotation.y = _desk.basis.get_euler().y
	velocity = Vector3.ZERO
	if _rig != null:
		_rig.play("idle", true, 0.6, ["sniff"])


## Se baja de la silla de un salto para su ronda.
func _leave_desk() -> void:
	at_desk = false
	var tw := create_tween()
	var down := global_position + Vector3(0, -CHAIR_Y, 0) + _desk.basis.z * 0.7
	tw.tween_property(self, "global_position", down, 0.3)
	_patrol_i = _nearest_patrol_to(down)
	_route = _route_to(_patrol[_patrol_i], down) if not _patrol.is_empty() else PackedVector3Array()
	_route_i = 0
	AudioManager.play_sfx("lanyard_tintineo")


func _nearest_patrol() -> int:
	return _nearest_patrol_to(global_position)


func _nearest_patrol_to(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in _patrol.size():
		var d := _patrol[i].distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## v0.3.1 pisos: ruta por la rejilla del piso (como Shero) o, si no hay, por los waypoints. Vacía si el destino está a
## la vista (menos de 3 m): entonces camina directo.
func _route_to(target: Vector3, from: Vector3 = Vector3.INF) -> PackedVector3Array:
	if from == Vector3.INF:
		from = global_position
	if _floor == null or from.distance_to(target) < 3.0:
		return PackedVector3Array()
	var g := Pursuit.grid_for(_floor)
	if g != null and g.cells > 0:
		return g.find_path(from, target)
	return _floor.path(from, target)


## Sigue _route; true al terminarla.
func _follow_route(delta: float) -> bool:
	if _route_i >= _route.size():
		return true
	var target := _route[_route_i]
	target.y = global_position.y
	var d := target - global_position
	if d.length() < maxf(0.3, patrol_speed * delta * 1.1):
		_route_i += 1
		return _route_i >= _route.size()
	velocity = d.normalized() * patrol_speed
	_face(target)
	if _rig != null:
		_rig.play("walk", true, 1.05)
	move_and_slide()
	global_position.y = 0.0
	global_position.y = 0.0
	return false


func _walk_to_desk(delta: float) -> void:
	if _route_i < _route.size():
		_follow_route(delta)
		return
	var target := _desk.origin + _desk.basis.z * 0.7
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.35:
		_sit_desk()
		return
	velocity = d.normalized() * patrol_speed
	_face(target)
	if _rig != null:
		_rig.play("walk", true, 1.05)
	move_and_slide()
	global_position.y = 0.0
	global_position.y = 0.0


## Lanyard que tintinea, fotocheck y auricular (GDD 6.2): geometría simple colgada del cuello.
func _dress() -> void:
	var lan := MeshInstance3D.new()
	lan.name = "Lanyard"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.085
	tor.outer_radius = 0.1
	tor.rings = 24
	tor.ring_segments = 8
	lan.mesh = tor
	lan.material_override = Greybox.material(Greybox.CIAN, 0.0, 0.8)
	lan.position = Vector3(0, 0.43, -0.12)
	lan.rotation_degrees.x = 62.0
	add_child(lan)
	var badge := Greybox.box(self, "Fotocheck", Vector3(0, 0.31, -0.24), Vector3(0.055, 0.08, 0.006), Greybox.BLANCO, false)
	badge.rotation_degrees.x = 18.0
	Greybox.box(badge, "Foto", Vector3(0, 0.012, -0.004), Vector3(0.035, 0.03, 0.002), Color(0.85, 0.85, 0.85), false)
	Greybox.box(badge, "Franja", Vector3(0, -0.028, -0.004), Vector3(0.045, 0.01, 0.002), Greybox.CIAN, false)
	Greybox.label(badge, "RTA", Vector3(0, -0.012, -0.004), 0.025, Greybox.GRIS_OSCURO, PI)
	Greybox.box(self, "Auricular", Vector3(0.1, 0.56, -0.2), Vector3(0.03, 0.05, 0.04), Greybox.NEGRO, false)
	Greybox.box(self, "AuricularBrazo", Vector3(0.08, 0.52, -0.27), Vector3(0.008, 0.008, 0.12), Greybox.NEGRO, false)
	Greybox.box(self, "Camisa", Vector3(0, 0.42, 0.02), Vector3(0.26, 0.14, 0.34), Color(0.85, 0.88, 0.92), false)


func _do_patrol(delta: float) -> void:
	if _patrol.is_empty():
		return
	if _pause > 0.0:
		_pause -= delta
		if _rig != null:
			_rig.play("sniff", true, 1.0, ["idle"])
		return
	var target := _patrol[_patrol_i]
	target.y = global_position.y
	var d := target - global_position
	if d.length() < maxf(0.3, patrol_speed * delta * 1.1):
		_patrol_i = (_patrol_i + 1) % _patrol.size()
		_pause = float(DataLoader.bal("rta/pausa_silla_vacia_s", 3.0)) * 0.3
		return
	velocity = d.normalized() * patrol_speed
	_face(target)
	if _rig != null:
		_rig.play("walk", true, 1.05)
	move_and_slide()
	global_position.y = 0.0


## Tras un tag: va hasta ti por los pasillos y se queda olfateando a tus pies (solo presión, no mata).
func stare_at_player(on: bool) -> void:
	_stare = on and GameState.current_floor == 2 and _floor != null and _player != null
	_route = PackedVector3Array()
	_route_i = 0
	_going_desk = false
	if _stare:
		_stare_path = _route_to(_player.global_position)
		if _stare_path.is_empty():
			_stare_path = PackedVector3Array([_player.global_position])
		_stare_i = 0
		_set_label("RTA !")
		AudioManager.play_sfx("lanyard_tintineo")
	else:
		_set_label("RTA")


func _do_stare(delta: float) -> void:
	var near := _player.global_position - global_position
	near.y = 0.0
	if near.length() < 1.6 or _stare_i >= _stare_path.size():
		velocity = Vector3.ZERO
		_face(_player.global_position)
		if _rig != null:
			_rig.play("sniff", true, 1.0, ["stare_camera", "idle"])
		return
	var target := _stare_path[_stare_i]
	target.y = global_position.y
	var d := target - global_position
	if d.length() < 0.4:
		_stare_i += 1
		return
	velocity = d.normalized() * patrol_speed * 1.8
	_face(target)
	if _rig != null:
		_rig.play("run", true, 1.2, ["walk"])
	move_and_slide()
	global_position.y = 0.0


func _face(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.z)


## Para la presión del ambiente (fx/dread.gd): ¿hay una caza de P5 en curso (RTA, Trainer o Shero)?
func is_hunting() -> bool:
	return P5Pursuit.is_hunting()


func _on_respawned(_kind: String) -> void:
	_stare = false
	_route = PackedVector3Array()
	_route_i = 0
	visible = true
	_set_label("RTA")
	if _has_desk:
		_sched_t = 0.0
		_sit_desk()
	elif not _patrol.is_empty():
		global_position = _patrol[0]


func _set_label(t: String) -> void:
	if _label != null:
		_label.text = t


## Dicta el AUX esperado y publica la orden en #allocations ("@{agente} pasa a BO", Lunch, Training).
## "Available" se lee como el AUX de la allocation del Mentor (T3+) o como la orden pendiente del turno
## (lunch a su hora, training convocado: RtaControl.pending_order()).
static func dictate(expected: int) -> void:
	if expected == Metrics.Aux.AVAILABLE and Metrics.allocation_aux >= 0:
		expected = Metrics.allocation_aux
	if expected == Metrics.Aux.AVAILABLE:
		expected = RtaControl.pending_order()
	if Metrics.expected_aux == expected:
		return
	var previous := Metrics.expected_aux
	Metrics.expected_aux = expected
	EventBus.expected_aux_changed.emit(expected)
	RtaControl.announce(expected, previous)

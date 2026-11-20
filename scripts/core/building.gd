class_name Building
extends Node3D
## Konzentramance (el edificio/BPO): carga un piso a la vez (streaming por ascensor/escalera) y coloca al jugador.

const FLOOR_SCENES: Dictionary = {
	-1: "res://scenes/niveles/Floor_M1.tscn",
	1: "res://scenes/niveles/Floor_01.tscn",
	2: "res://scenes/niveles/Floor_02.tscn",
	9: "res://scenes/niveles/Floor_09.tscn",
}
const BLOCKED_FLOORS: Array[int] = [3, 4, 5, 6, 7, 8]

signal floor_loaded(floor_number: int, floor_node: Node3D)

var current_floor: int = -1
var floor_node: Node3D = null
var player: Player = null
var _transitioning: bool = false


func setup(p_player: Player) -> void:
	player = p_player


## Cambia de piso y coloca al jugador en el spawn indicado ("ascensor", "escalera", "casillero", "calle"...).
func go_to_floor(number: int, spawn: String = "ascensor") -> void:
	if _transitioning:
		return
	if BLOCKED_FLOORS.has(number) or not FLOOR_SCENES.has(number):
		EventBus.show_message.emit(tr("ELEVATOR_DENIED"), 2.0)
		AudioManager.play_sfx("ascensor_boton_muerto", "UI")
		return
	_transitioning = true
	if floor_node != null:
		floor_node.queue_free()
		floor_node = null
	var packed: PackedScene = load(FLOOR_SCENES[number])
	if packed == null:
		push_error("Building: no se pudo cargar el piso %d" % number)
		_transitioning = false
		return
	floor_node = packed.instantiate() as Node3D
	add_child(floor_node)
	current_floor = number
	if player != null:
		var m: Node = floor_node.find_child(spawn, true, false)
		if m == null:
			m = floor_node.find_child("ascensor", true, false)
		if m is Node3D:
			player.teleport((m as Node3D).global_position, (m as Node3D).rotation_degrees.y)
	EventBus.player_floor_changed.emit(number)
	floor_loaded.emit(number, floor_node)
	_transitioning = false
	if spawn == "ascensor_dentro":
		var elev := floor_node.find_child("Elevator", true, false)
		if elev == null:
			for e in get_tree().get_nodes_in_group("elevator"):
				if floor_node.is_ancestor_of(e):
					elev = e
		if elev != null and elev.has_method("arrive"):
			elev.call("arrive")
		elif player != null:
			player.input_locked = false


## Caja de escalera entre el piso actual y `target` (espacio liminal; ver Stairwell).
func go_to_stairwell(target: int, going_up: bool) -> void:
	if _transitioning or BLOCKED_FLOORS.has(target):
		return
	_transitioning = true
	var from := current_floor
	if floor_node != null:
		floor_node.queue_free()
		floor_node = null
	var sw := Stairwell.new()
	sw.name = "Stairwell"
	sw.from_floor = from
	sw.to_floor = target
	sw.going_up = going_up
	floor_node = sw
	add_child(sw)
	if player != null:
		var m: Node = sw.find_child("escalera", true, false)
		if m is Node3D:
			player.teleport((m as Node3D).global_position, (m as Node3D).rotation_degrees.y)
	floor_loaded.emit(from, sw)
	_transitioning = false


func is_blocked(number: int) -> bool:
	return BLOCKED_FLOORS.has(number)

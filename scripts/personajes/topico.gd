extends Node
## Tópico del piso 1: comportamiento de piso (data/comportamientos.json → marcador topico). El cerebro es
## TopicoControl (persistente). Aquí está el enfermero: modelo v2 "enfermero" (P6: uniforme de enfermero) en lugar de
## la figura de P2, de pie junto al biombo; cuando atiende se acerca a la camilla, ladea la cabeza y no te
## quita los ojos de encima. En T1 el tópico está cerrado (solo la silueta de P2 tras el vidrio).

var floor_node: FloorBase = null
var actor: P5Actor = null
var _home: Vector3 = Vector3.ZERO
var _home_rot: float = 0.0
var _attending: bool = false
var _t: float = 0.0


func setup_behaviour(fl: Node, marker: Node, _entry: Dictionary) -> void:
	floor_node = fl as FloorBase
	PersonajesP5.ensure(get_tree())
	if not TopicoControl.is_open():
		return
	add_to_group("p5_enfermero")
	var old := floor_node.find_child("Enfermera", true, false) as Node3D
	_home = old.global_position if old != null else (marker as Node3D).global_position + Vector3(1.2, 0, -1.0)
	_home_rot = old.global_rotation.y if old != null else deg_to_rad(90.0)
	var slug := "enfermero" if P5Actor.model_path("enfermero") != "" else "enfermera"  # P6: modelo propio
	if P5Actor.model_path(slug) != "" and old != null:
		old.visible = false  # el modelo v2 reemplaza al rig reteñido de P2
	elif old != null:
		return  # sin modelo v2: se queda la figura de P2
	actor = P5Actor.make(floor_node, slug, 1.74, Vector3.ZERO, 0.0, "Enfermero")
	actor.global_position = _home
	actor.rotation.y = _home_rot
	actor.floor_ref = floor_node
	actor.speed = 0.9
	actor.play("idle", true, 0.6)


func attend(on: bool) -> void:
	_attending = on
	if actor == null or not is_instance_valid(actor):
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if on and pl != null:
		var d := pl.global_position - _home
		d.y = 0.0
		actor.global_position = _home + d.normalized() * minf(d.length() * 0.5, 1.0)
		actor.face_now(pl.global_position)
		actor.look_toward(pl.global_position)
		actor.play("stare_camera", true, 0.45, ["idle"])
	else:
		actor.global_position = _home
		actor.rotation.y = _home_rot
		actor.look_toward(Vector3.INF)
		actor.play("idle", true, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if actor == null or not is_instance_valid(actor) or _attending:
		return
	# Te sigue con la cabeza (todo el cuerpo, despacio) cuando estás cerca del vidrio.
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null and pl.global_position.distance_to(_home) < 6.0:
		actor.look_toward(pl.global_position)
	else:
		actor.look_toward(Vector3.INF)
		actor.rotation.y = lerp_angle(actor.rotation.y, _home_rot, minf(delta * 1.5, 1.0))

class_name Zone
extends Area3D
## Zona del mapa (pasillo, baño, fila C...). Emite player_entered_zone / player_exited_zone.

@export var zone_id: String = ""
@export var size: Vector3 = Vector3(4, 3, 4)

var player_inside: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 16  # 16 = jugador sentado/acostado (Player._set_ghost)
	monitoring = true
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("zones")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		EventBus.player_entered_zone.emit(zone_id)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		EventBus.player_exited_zone.emit(zone_id)


static func make(parent: Node, id: String, pos: Vector3, p_size: Vector3) -> Zone:
	var z := Zone.new()
	z.name = "Zone_" + id
	z.zone_id = id
	z.size = p_size
	z.position = pos
	parent.add_child(z)
	return z


## v0.3.2: rectángulo XZ global que cubre la zona (las zonas giran solo de a 90°: el rectángulo es exacto).
func rect_xz() -> Rect2:
	var xf := global_transform if is_inside_tree() else transform
	var h := size * 0.5
	var r := Rect2()
	var first := true
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := xf * Vector3(h.x * sx, 0.0, h.z * sz)
			var q := Vector2(p.x, p.z)
			if first:
				r = Rect2(q, Vector2.ZERO)
				first = false
			else:
				r = r.expand(q)
	return r


## ¿El punto (en planta) está dentro de la zona, a `margin` m o más de su borde?
func contains_xz(p: Vector3, margin: float = 0.0) -> bool:
	return rect_xz().grow(-margin).has_point(Vector2(p.x, p.z))


## La zona `id` del piso cargado (null si no hay).
static func find(tree: SceneTree, id: String) -> Zone:
	if tree == null:
		return null
	for z in tree.get_nodes_in_group("zones"):
		if z is Zone and (z as Zone).zone_id == id and (z as Zone).is_inside_tree() and not (z as Zone).is_queued_for_deletion():
			return z as Zone
	return null

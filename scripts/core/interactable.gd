class_name Interactable
extends Area3D
## Objeto con el que el jugador interactúa con E. Subclases sobreescriben interact() y hint_text().

signal interacted(player: Node)

@export var hint_key: String = "HUD_INTERACT"
@export var enabled: bool = true
@export var size: Vector3 = Vector3(1, 1, 1)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	if get_child_count() == 0 or not (get_child(0) is CollisionShape3D):
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		add_child(shape)
	add_to_group("interactables")


## Texto que muestra el HUD al apuntar.
func hint_text() -> String:
	return tr(hint_key)


## Acción al pulsar E. Devuelve true si consumió la acción.
func interact(player: Node) -> bool:
	if not enabled:
		return false
	interacted.emit(player)
	return true

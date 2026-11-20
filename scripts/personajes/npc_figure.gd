class_name NpcFigure
extends Node3D
## Figura neutral con rig (Don Fermín, perro del paradero, compañeros): clip en bucle, tinte opcional
## de la ropa/pelaje y giro lento hacia el jugador cuando se acerca (mirar, no seguir).

var rig: CharacterRig = null
var look_radius: float = 0.0  # 0 = no gira
var look_max_deg: float = 45.0
var idle_anim: String = "idle"
var near_anim: String = ""  # clip alternativo con el jugador cerca (p. ej. sniff)
var anim_speed: float = 1.0
var _base_yaw: float = 0.0
var _player: Node3D = null

## v0.3 (P6): las figuras de P2 que usaban un rig de agente reteñido pasan a su modelo v2 propio (sin tinte):
## nombre del nodo → GLB. Don Fermín v2 ya trae gorra: se ocultan las cajas GorraFermin/ViseraFermin del piso.
const MODEL_BY_NAME: Dictionary = {"Enfermera": "enfermera", "MentorFigura": "mentor", "Fermin": "guardia_fermin", "Marleny": "marleny"}
const HIDE_WITH_V2: Dictionary = {"Fermin": ["GorraFermin", "ViseraFermin"]}


static func make(parent: Node, model: String, pos: Vector3, yaw_deg: float, height: float, tint: Color = Color.WHITE, p_name: String = "") -> NpcFigure:
	var n := NpcFigure.new()
	n.name = p_name if p_name != "" else "Npc_" + model
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	n._base_yaw = n.rotation.y
	var own := str(MODEL_BY_NAME.get(n.name, ""))
	if own != "" and ResourceLoader.exists(CharacterRig.MODELS_DIR + own + ".glb"):
		model = own
	n.rig = CharacterRig.attach(n, model, height)
	if n.rig != null and n.rig.is_v2 and HIDE_WITH_V2.has(n.name):
		n.set_meta("hide_siblings", HIDE_WITH_V2[n.name])
	if n.rig == null:
		# Sin modelo: silueta de cajas para no dejar el hueco vacío.
		Greybox.box(n, "Cuerpo", Vector3(0, height * 0.5, 0), Vector3(0.45, height * 0.92, 0.3), tint if tint != Color.WHITE else Color(0.25, 0.3, 0.45), false)
		Greybox.box(n, "Cabeza", Vector3(0, height * 0.92 + 0.1, 0), Vector3(0.22, 0.24, 0.22), Color(0.6, 0.5, 0.42), false)
	elif tint != Color.WHITE:
		n.rig.tint_outfit(tint)
	return n


func _ready() -> void:
	add_to_group("npcs")
	call_deferred("_start")


func _start() -> void:
	if rig != null:
		rig.play(idle_anim, true, anim_speed, ["sit", "walk"])
	if has_meta("hide_siblings") and get_parent() != null:
		for nm in get_meta("hide_siblings"):
			var c := get_parent().find_child(str(nm), false, false) as Node3D
			if c != null:
				c.visible = false


func _process(delta: float) -> void:
	if look_radius <= 0.0 or rig == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var d := _player.global_position - global_position
	d.y = 0.0
	var target_yaw := _base_yaw
	var near := d.length() <= look_radius
	if near and d.length() > 0.05:
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - _base_yaw, -PI, PI)
		target_yaw = _base_yaw + clampf(diff, -deg_to_rad(look_max_deg), deg_to_rad(look_max_deg))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 2.5, 1.0))
	if near_anim != "":
		rig.play(near_anim if near else idle_anim, true, anim_speed, ["idle"])

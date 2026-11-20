class_name MonitorScreen
extends Interactable
## Pantalla "viva" de un monitor de la PC (GDD 8.1/8.3): un quad con la textura del SubViewport
## que dibuja la Workstation (izquierdo = Kardex/Identa, derecho = Fonex + Ezlaki).
## Estados: encendido (viewport), apagado (vidrio oscuro, puede mostrar un reflejo 1-2 s).
## Sentado y apuntando: [E] acerca la vista (overlay 2D); [F] apaga/enciende los monitores.

const SCREEN_SIZE := Vector2(0.52, 0.32)

var side: String = "left"  # "left" | "right"
var seat_id: String = ""
var powered: bool = true
var _quad: MeshInstance3D = null
var _on_mat: StandardMaterial3D = null
var _off_mat: StandardMaterial3D = null
var _glow: OmniLight3D = null
var _reflection_left: float = 0.0
var _bound: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("monitor_screens")
	hint_key = "HUD_MONITOR_ZOOM"
	var mesh := QuadMesh.new()
	mesh.size = SCREEN_SIZE
	_quad = MeshInstance3D.new()
	_quad.name = "Pantalla"
	_quad.mesh = mesh
	_quad.position = Vector3(0, 0, 0.017)
	add_child(_quad)
	_on_mat = StandardMaterial3D.new()
	_on_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_on_mat.albedo_color = Color(1, 1, 1)  # la textura del viewport tal cual
	_off_mat = StandardMaterial3D.new()
	# Apagado: también sin sombreado (control exacto del píxel); el reflejo va como albedo.
	_off_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_off_mat.albedo_color = Color(0.012, 0.013, 0.017)
	_quad.material_override = _on_mat
	# Luz azul de monitor sobre la cara (GDD 8.2).
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 0, 0.25)
	_glow.light_color = Color(0.45, 0.6, 0.95)
	_glow.light_energy = 0.35
	_glow.omni_range = 1.6
	add_child(_glow)


func _process(delta: float) -> void:
	if not _bound:
		_bind()
	if _reflection_left > 0.0:
		_reflection_left -= delta
		if _reflection_left <= 0.0:
			_off_mat.albedo_texture = null
			_off_mat.albedo_color = Color(0.012, 0.013, 0.017)
			if powered:
				set_powered(true)


## Engancha la textura del viewport de la Workstation (puede no existir aún al construir el piso).
func _bind() -> void:
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws == null or not ws.has_method("screen_texture"):
		return
	var tex: Texture2D = ws.call("screen_texture", side)
	if tex == null:
		return
	_on_mat.albedo_texture = tex
	_bound = true


func hint_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not bool(player.get("seated")):
		return ""
	return tr("HUD_MONITOR_ZOOM") if powered else tr("HUD_MONITOR_OFF")


func interact(player: Node) -> bool:
	if not enabled or player == null or not bool(player.get("seated")):
		return false
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws != null and powered:
		ws.call("toggle_zoom")
	interacted.emit(player)
	return true


func set_powered(on: bool) -> void:
	powered = on
	_quad.material_override = _on_mat if on else _off_mat
	_glow.visible = on
	AudioManager.play_sfx("monitor_encender" if on else "monitor_apagar", "Sala")
	ObjectAnim.monitor(self, _quad, _glow, on)  # v0.3.2-anim: parpadeo de la retroiluminación al encender


## Muestra un reflejo (silueta/cara) en la pantalla apagada durante `seconds`; luego vuelve al estado previo.
func show_reflection(tex: Texture2D, seconds: float = 1.5) -> void:
	_off_mat.albedo_texture = tex
	_off_mat.albedo_color = Color(0.75, 0.85, 1.0)
	_quad.material_override = _off_mat
	_glow.visible = false
	_reflection_left = seconds


## Crea las dos pantallas sobre los Monitor0/Monitor1 de un cubículo.
static func attach(cubicle: Node3D, p_seat_id: String) -> Array[MonitorScreen]:
	var out: Array[MonitorScreen] = []
	var sides := ["left", "right"]
	for i in 2:
		var mon := cubicle.get_node_or_null("Monitor%d" % i) as MeshInstance3D
		if mon == null:
			continue
		var s := MonitorScreen.new()
		s.name = "Pantalla_%s" % sides[i]
		s.side = sides[i]
		s.seat_id = p_seat_id
		s.size = Vector3(0.56, 0.36, 0.12)
		s.position = mon.position
		cubicle.add_child(s)
		out.append(s)
	return out

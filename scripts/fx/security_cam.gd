class_name SecurityCamView
extends Node
## Distorsión 5, "El espejo" (GDD 4.7): al mirarte en el espejo del baño con Fatiga alta, el reflejo es
## la cámara de seguridad de la Fila C: tú, sentado en tu PC, de espaldas. Durante UN fotograma Shero
## está de pie detrás de tu silla. Dura hasta que parpadeas (R) o 20 s.
## Se arma un "set" escondido muy por debajo del piso (3 cubículos + doble del jugador) y una
## cámara de techo lo filma a un SubViewport que se proyecta a pantalla completa con ruido y REC.

const STAGE_Y := -60.0
const MAX_SECONDS := 20.0

var _stage: Node3D = null
var _viewport: SubViewport = null
var _layer: CanvasLayer = null
var _shero: Node3D = null
var _rect: TextureRect = null
var _label: Label = null
var _t: float = 0.0
var _flash_at: float = 2.2
var _flashed: bool = false
var _active: bool = false


static func show_view(parent: Node) -> SecurityCamView:
	var v := SecurityCamView.new()
	v.name = "SecurityCamView"
	parent.add_child(v)
	v._start()
	return v


func _start() -> void:
	_active = true
	_flash_at = randf_range(1.6, 3.4)
	var world := get_tree().get_first_node_in_group("building")
	if world == null:
		world = get_tree().current_scene
	# --- Set oculto ---
	_stage = Node3D.new()
	_stage.name = "SetCamara"
	_stage.position = Vector3(0, STAGE_Y, 0)
	world.add_child(_stage)
	Greybox.floor_slab(_stage, "Alfombra", Vector2(0, 0.5), Vector2(8, 6), Greybox.ALFOMBRA)
	Greybox.ceiling(_stage, "Techo", Vector2(0, 0.5), Vector2(8, 6), 3.4)
	Greybox.box(_stage, "Fondo", Vector3(0, 1.7, -2.5), Vector3(8, 3.4, 0.2), Greybox.BEIGE, false)
	for i in 3:
		var id: String = ["C-13", "C-14", "C-15"][i]
		var cub := Greybox.cubicle(_stage, id, Vector3((i - 1) * 1.65, 0, 0), 0.0, 2 if id == "C-14" else 1)
		if id == "C-13":
			Greybox.box(cub, "Taza", Vector3(0.3, 0.78, -0.3), Vector3(0.1, 0.1, 0.1), Greybox.BLANCO, false)
		elif id == "C-15":
			var r := CharacterRig.attach(cub, "agente_juan", 1.7, 180.0, Vector3(0, 0, 0.45))
			if r != null:
				r.play("type", true, 0.9, ["sit", "idle"])
	# Doble del jugador sentado en C-14 (el agente elegido, de espaldas a la cámara).
	var c14 := _stage.get_node("Cub_C-14") as Node3D
	var me := CharacterRig.attach(c14, CharacterRig.agent_model(GameState.agent), 1.72, 180.0, Vector3(0, 0, 0.45))
	if me == null:
		Greybox.box(c14, "Doble", Vector3(0, 1.0, 0.4), Vector3(0.45, 0.7, 0.3), Color(0.2, 0.25, 0.35), false)
	else:
		me.play("sit", true, 0.5, ["type", "idle"])
	for k in 2:
		var mon := c14.get_node_or_null("Monitor%d" % k) as MeshInstance3D
		if mon != null:
			mon.material_override = Greybox.material(Color(0.25, 0.4, 0.7), 1.5)
	Greybox.light(_stage, Vector3(0, 1.2, -0.2), Color(0.45, 0.6, 0.95), 0.9, 3.0)
	Greybox.light(_stage, Vector3(1.5, 2.6, 2.0), Color(0.7, 0.85, 0.85), 0.8, 7.0)
	Greybox.light_panel(_stage, "Luz", Vector3(0, 3.3, 1.0), false, true)
	# Shero de pie detrás de la silla, invisible salvo un fotograma.
	_shero = Node3D.new()
	_shero.name = "SheroDoble"
	_shero.position = Vector3(0.25, 0, 1.45)
	_stage.add_child(_shero)
	var sr := CharacterRig.attach(_shero, "shero", 2.2)
	if sr == null:
		Greybox.box(_shero, "Cuerpo", Vector3(0, 0.95, 0), Vector3(0.5, 1.9, 0.35), Color(0.45, 0.6, 0.75), false)
	else:
		sr.play("idle")
	_shero.visible = false
	# --- Cámara de techo → SubViewport ---
	_viewport = SubViewport.new()
	_viewport.name = "CamVP"
	_viewport.size = Vector2i(640, 360)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1
	_viewport.add_child(cam)
	cam.global_position = _stage.global_position + Vector3(2.6, 3.1, 2.9)
	cam.look_at(_stage.global_position + Vector3(0, 0.9, 0.2), Vector3.UP)
	cam.current = true
	# --- Pantalla completa con ruido ---
	_layer = CanvasLayer.new()
	_layer.name = "CamOverlay"
	_layer.layer = 12
	add_child(_layer)
	_rect = TextureRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.texture = _viewport.get_texture()
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.material = _make_shader()
	_layer.add_child(_rect)
	_label = UITheme.label("", 22, Color(0.85, 0.9, 0.85))
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.position = Vector2(60, 40)
	_layer.add_child(_label)
	var rec := UITheme.label("● REC", 22, UITheme.RED)  # el punto REC es uno de los pocos rojos permitidos
	rec.autowrap_mode = TextServer.AUTOWRAP_OFF
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rec.offset_right = -60
	rec.offset_left = -220
	rec.offset_top = 40
	rec.offset_bottom = 70
	_layer.add_child(rec)
	AudioManager.play_sting()


func _make_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float t = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	uv.x += (hash(vec2(floor(uv.y * 180.0), floor(t * 24.0))) - 0.5) * 0.004;
	vec4 c = texture(TEXTURE, uv);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float n = hash(uv * vec2(640.0, 360.0) + vec2(t * 61.0, t * 17.0)) * 0.18;
	float scan = 0.88 + 0.12 * sin(uv.y * 360.0 * 3.1416 + t * 6.0);
	float vig = 1.0 - 0.45 * length(uv - 0.5);
	vec3 col = vec3(g * 0.85, g * 1.0, g * 0.9) * scan * vig + n;
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _rect != null and _rect.material is ShaderMaterial:
		(_rect.material as ShaderMaterial).set_shader_parameter("t", _t)
	if _label != null:
		_label.text = "CAM 02 · FILA C · %s" % GameState.clock_text()
	# Shero detrás de la silla: visible exactamente un fotograma.
	if _shero != null:
		if not _flashed and _t >= _flash_at:
			_flashed = true
			_shero.visible = true
		elif _shero.visible:
			_shero.visible = false
	if _t >= MAX_SECONDS:
		finish()


func finish() -> void:
	if not _active:
		return
	_active = false
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	queue_free()

class_name GfxFps
extends CanvasLayer
## v0.3.2 gfx · Contador de FPS visible (Opciones → Gráficos avanzados → «Mostrar contador de FPS»).
## Arriba a la derecha, chico y sin fondo; muestra los fps y el tiempo de cuadro promediados cada medio segundo.
## Solo existe mientras la opción está activa.

static var inst: GfxFps = null

var _label: Label = null
var _t: float = 0.0
var _frames: int = 0
var _t0: int = 0


## Crea o quita el contador según la opción.
static func sync(tree: SceneTree) -> void:
	var want := bool(GfxSettings.global("gfx_fps")) and not GfxSettings.headless()
	if want and not is_instance_valid(inst):
		inst = GfxFps.new()
		tree.root.add_child.call_deferred(inst)
	elif not want and is_instance_valid(inst):
		inst.queue_free()
		inst = null


func _init() -> void:
	name = "GfxFps"
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	GfxBoot.strings()
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -10
	_label.offset_top = 6
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)
	_t0 = Time.get_ticks_usec()


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _process(_delta: float) -> void:
	_frames += 1
	var now := Time.get_ticks_usec()
	var el := float(now - _t0) / 1000000.0
	if el >= 0.5:
		var fps := float(_frames) / el
		_label.text = tr("GFX_FPS_FMT") % [int(round(fps)), 1000.0 / maxf(fps, 0.01)]
		_frames = 0
		_t0 = now
	if not visible:
		visible = true  # la pausa oculta las capas ajenas: el contador se queda

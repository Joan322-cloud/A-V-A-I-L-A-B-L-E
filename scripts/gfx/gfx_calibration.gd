class_name GfxCalibration
extends Control
## v0.3.2 gfx · Pantalla «Brillo»: «mueve la barra hasta que el símbolo de la izquierda apenas se vea».
## Sale sola la primera vez que se abre el juego en escritorio (settings «gfx_calibrado») y se puede volver a
## abrir desde Opciones → Gráficos avanzados → «Calibrar brillo…». El valor (settings «gfx_brillo», 0,6..1,6;
## 1,0 = sin cambio) aclara u oscurece las sombras de la imagen 3D: en Media/Alta como gamma del pase de lente; en
## Baja y Modo liviano como exposición. La interfaz no cambia.
##
## Los dos símbolos se pintan con el mismo cálculo que usa el juego para una sombra de ese valor, así que lo que
## se ve aquí es lo que se verá en los rincones oscuros de la oficina.

signal closed()

const DARK := 0.032     # valor (sRGB) del símbolo que debe quedar «apenas visible»
const CLEAR := 0.13     # valor del símbolo que debe verse bien

static var _layer: CanvasLayer = null

var first_time: bool = false
var _value: float = 1.0
var _slider: HSlider = null
var _sample: Control = null
var _num: Label = null


## Primera vez (escritorio, con pantalla): la muestra sobre el menú principal.
static func first_run(tree: SceneTree) -> void:
	if OS.has_feature("web") or bool(GfxSettings.global("gfx_calibrado")) or is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "GfxBrillo"
	_layer.layer = 105
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var c := GfxCalibration.new()
	c.first_time = true
	_layer.add_child(c)
	c.closed.connect(func() -> void:
		if is_instance_valid(_layer):
			_layer.queue_free()
		_layer = null)
	tree.root.add_child.call_deferred(_layer)


## Desde las opciones: se cuelga del control que la abre (queda dentro de su capa, también con la pausa abierta).
static func open_in(host: Control) -> GfxCalibration:
	var c := GfxCalibration.new()
	host.add_child(c)
	c.closed.connect(c.queue_free)
	return c


## Cómo se ve en pantalla un tono `v` (sRGB 0..1) de la imagen 3D con el brillo `b`.
static func shown(v: float, b: float) -> float:
	if GfxSettings.enhanced():
		return pow(v, 1.0 / b)                              # gamma del pase de lente
	return pow(pow(v, 2.2) * GfxAtmosphere.brightness_to_exposure(b), 1.0 / 2.2)   # exposición


func _ready() -> void:
	GfxBoot.strings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_value = GfxSettings.brillo()
	_build()


## Al cambiar de idioma con la pantalla abierta, los textos se vuelven a armar (sin reiniciar).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build.call_deferred()   # el aviso llega mientras el árbol se recorre: no se pueden colgar hijos ahí mismo


## Arma (o vuelve a armar) toda la pantalla con los textos del idioma actual; conserva el valor de la barra.
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	add_child(bg)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	UITheme.center_fit(box)
	var title := UITheme.label(tr("GFX_CAL_TITLE"), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_sample = Control.new()
	_sample.name = "Muestra"
	_sample.custom_minimum_size = Vector2(760, 250)
	_sample.draw.connect(_draw_sample.bind(_sample))
	box.add_child(_sample)
	var caps := HBoxContainer.new()
	for key in ["GFX_CAL_LEFT", "GFX_CAL_RIGHT"]:
		var l := UITheme.label(tr(key), 13, UITheme.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caps.add_child(l)
	box.add_child(caps)
	var text := UITheme.label(tr("GFX_CAL_TEXT"), 15)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(760, 0)
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_slider = HSlider.new()
	_slider.name = "Barra"
	_slider.min_value = GfxSettings.BRILLO_MIN
	_slider.max_value = GfxSettings.BRILLO_MAX
	_slider.step = 0.02
	_slider.value = _value
	_slider.custom_minimum_size = Vector2(420, 24)
	_slider.value_changed.connect(_on_value)
	row.add_child(_slider)
	_num = UITheme.label("", 14, UITheme.DIM)
	_num.custom_minimum_size = Vector2(60, 0)
	_num.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_num)
	box.add_child(row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	var def := UITheme.button(tr("GFX_CAL_DEFAULT"), func() -> void: _slider.value = 1.0)
	def.custom_minimum_size = Vector2(160, 34)
	btns.add_child(def)
	var ok := UITheme.button(tr("GFX_CAL_OK"), accept)
	ok.name = "Aceptar"
	ok.custom_minimum_size = Vector2(200, 34)
	btns.add_child(ok)
	box.add_child(btns)
	_on_value(_value)
	_slider.grab_focus.call_deferred()


func _on_value(v: float) -> void:
	_value = clampf(v, GfxSettings.BRILLO_MIN, GfxSettings.BRILLO_MAX)
	GfxSettings.brillo_preview = _value   # el pase de lente lo toma en vivo (si hay un piso detrás, se ve)
	if _num != null:
		_num.text = "%d%%" % int(round(_value * 100.0))
	if _sample != null:
		_sample.queue_redraw()


func accept() -> void:
	GfxSettings.brillo_preview = -1.0
	GfxSettings.set_global("gfx_brillo", snappedf(_value, 0.01))
	GfxSettings.set_global("gfx_calibrado", true)
	GfxDirector.request(get_tree())   # en Baja crea el director solo si el brillo no es 1,0
	EventBus.settings_changed.emit("gfx_brillo")
	closed.emit()


func _exit_tree() -> void:
	GfxSettings.brillo_preview = -1.0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		accept()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if first_time:
			accept()
		else:
			GfxSettings.brillo_preview = -1.0
			closed.emit()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Mientras está abierta, el teclado y el mando son suyos (el menú de detrás no los ve).
		if event.is_action_pressed("ui_left"):
			_slider.value -= 0.04
		elif event.is_action_pressed("ui_right"):
			_slider.value += 0.04
		get_viewport().set_input_as_handled()


## Dos recuadros negros con el símbolo (un auricular de operador) en el tono oscuro y en el claro.
func _draw_sample(s: Control) -> void:
	var w := s.size.x
	var h := s.size.y
	for i in 2:
		var cx := w * (0.27 + 0.46 * i)
		var cy := h * 0.5
		var v := shown(DARK if i == 0 else CLEAR, _value)
		var col := Color(v, v, v, 1.0)
		s.draw_rect(Rect2(cx - 150, cy - 115, 300, 230), Color(0, 0, 0, 1))
		s.draw_rect(Rect2(cx - 150, cy - 115, 300, 230), Color(0.09, 0.1, 0.11, 1), false, 1.0)
		s.draw_arc(Vector2(cx, cy + 6), 62.0, PI, TAU, 40, col, 12.0, true)             # diadema
		s.draw_rect(Rect2(cx - 82, cy - 2, 30, 64), col)                               # copas
		s.draw_rect(Rect2(cx + 52, cy - 2, 30, 64), col)
		s.draw_arc(Vector2(cx - 24, cy + 54), 44.0, PI * 0.5, PI, 20, col, 6.0, true)  # brazo del micrófono
		s.draw_circle(Vector2(cx - 22, cy + 98), 10.0, col)

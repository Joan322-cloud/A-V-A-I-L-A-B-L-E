class_name UITheme
extends RefCounted
## Estilo "software corporativo viejo": tema azul-gris, bordes, monoespaciada. Un solo rojo.

const BG := Color(0.11, 0.13, 0.16)
const PANEL := Color(0.16, 0.19, 0.23)
const BORDER := Color(0.35, 0.42, 0.5)
const TEXT := Color(0.82, 0.86, 0.88)
const DIM := Color(0.55, 0.6, 0.65)
const GREEN := Color(0.18, 0.75, 0.44)
const YELLOW := Color(0.9, 0.75, 0.25)
const RED := Color(0.85, 0.08, 0.08)
const EZLAK := Color(0.3, 0.55, 0.9)


static func panel(title_text: String = "", min_size: Vector2 = Vector2(400, 200)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	var vb := VBoxContainer.new()
	vb.name = "VB"
	p.add_child(vb)
	if title_text != "":
		var t := Label.new()
		t.name = "Title"
		t.text = title_text
		t.add_theme_color_override("font_color", DIM)
		t.add_theme_font_size_override("font_size", 14)
		vb.add_child(t)
		vb.add_child(HSeparator.new())
	return p


static var _mono: Font = null


## Monoespaciada de sistema (logo y pantalla de login, GDD 8.3): DejaVu Sans Mono empaquetada.
static func mono() -> Font:
	if _mono == null:
		var path := "res://assets/fonts/DejaVuSansMono.ttf"
		if ResourceLoader.exists(path):
			_mono = load(path) as Font
		if _mono == null:
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Liberation Mono", "Courier New", "monospace"])
			_mono = sf
	return _mono


static func label(text: String, size: int = 16, color: Color = TEXT, use_mono: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if use_mono:
		l.add_theme_font_override("font", mono())
	return l


## Ventana de software viejo: barra de título con botones de ventana, borde y cuerpo.
static func window(title_text: String, min_size: Vector2 = Vector2(600, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	p.add_child(outer)
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.2, 0.27, 0.36)
	bsb.set_content_margin_all(6)
	bar.add_theme_stylebox_override("panel", bsb)
	var hb := HBoxContainer.new()
	bar.add_child(hb)
	var t := label(title_text, 13, TEXT, true)
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(t)
	var wb := label("_  □  ×", 13, DIM, true)
	wb.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(wb)
	outer.add_child(bar)
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 12)
	body.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(body)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	body.add_child(vb)
	return p


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


static func color_for(metric_color: String) -> Color:
	match metric_color:
		"verde": return GREEN
		"amarillo": return YELLOW
		"rojo": return RED
	return TEXT


## Centra un control en su padre (o en el viewport) y, si no cabe, lo escala hacia abajo para que quepa
## entero (UI responsive: el diseño es 1920×1080 pero la ventana puede ser estrecha o vertical).
## vertical=false lo deja a `top` px del borde superior y solo centra en horizontal.
static func center_fit(c: Control, fit: bool = true, vertical: bool = true, top: float = 0.0, margin: float = 24.0) -> void:
	var relayout := func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var area := c.get_parent_area_size()
		# Un Control suelto no encoge solo cuando baja su mínimo (las etiquetas con autowrap lo inflan
		# antes de conocer su ancho): se vuelve a su tamaño mínimo real en cada relayout.
		var mn := c.get_combined_minimum_size()
		if (c.size - mn).length() > 0.5:
			c.set_deferred("size", mn)
		var sz := Vector2(maxf(mn.x, 1.0), maxf(mn.y, 1.0))
		var s := 1.0
		if fit:
			s = minf(1.0, minf((area.x - margin) / sz.x, (area.y - margin) / sz.y))
		c.scale = Vector2(s, s)
		var x := (area.x - sz.x * s) * 0.5
		var y := (area.y - sz.y * s) * 0.5 if vertical else minf(top * s, maxf(0.0, area.y - sz.y * s))
		c.position = Vector2(x, y)
	c.resized.connect(relayout)
	c.visibility_changed.connect(relayout)
	# Las etiquetas con autowrap inflan el mínimo hasta que el contenedor les da ancho: cuando el mínimo
	# baja hay que volver a encoger y recentrar (ver arriba).
	c.minimum_size_changed.connect(relayout.call_deferred)
	# v0.3.2-core: la conexión al viewport se suelta cuando el control sale del árbol. Antes se quedaba para siempre:
	# cada panel cerrado (opciones, pausa, muerte, fin de turno…) dejaba una función colgada del viewport y, al cambiar
	# el tamaño de la ventana o pasar a pantalla completa, el motor escribía un «Lambda capture … was freed» por cada una.
	var hook := func() -> void:
		var vp := c.get_viewport()
		if vp != null and not vp.size_changed.is_connected(relayout):  # reparent = otro tree_entered
			vp.size_changed.connect(relayout)
		relayout.call_deferred()
	var unhook := func() -> void:
		var vp := c.get_viewport()
		if vp != null and vp.size_changed.is_connected(relayout):
			vp.size_changed.disconnect(relayout)
	c.tree_entered.connect(hook)
	c.tree_exiting.connect(unhook)
	if c.is_inside_tree():
		hook.call()


static func vb_of(p: PanelContainer) -> VBoxContainer:
	var direct := p.get_node_or_null("VB")
	if direct != null:
		return direct as VBoxContainer
	return p.find_child("VB", true, false) as VBoxContainer

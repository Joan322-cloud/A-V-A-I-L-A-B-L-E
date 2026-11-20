class_name GfxOptions
extends Control
## v0.3.2 gfx · Panel «Gráficos avanzados» (Opciones → Gráficos → «Gráficos avanzados…»).
##
## Cada mejora de Media/Alta se puede cambiar suelta (GfxSettings.set_value → settings.json «gfx»); elegir otra
## calidad en Opciones vuelve al ajuste de esa calidad. En Baja y Modo liviano las mejoras están apagadas y sus
## controles quedan deshabilitados (se explica arriba); las opciones de pantalla —brillo, contador de FPS, V-Sync,
## renderizador, fondo de subtítulos— valen siempre.
## Un solo gancho en ui/options_menu.gd: GfxOptions.add_row(columna, menú).

signal closed()

const LEFT: Array[String] = ["luz_terror", "sombras", "niebla", "ssao", "ssil", "reflejos", "glow", "adaptacion"]
const SURF: Array[String] = ["materiales", "detalle", "personajes", "escala_3d"]
const LENS: Array[String] = ["lente", "aberracion", "grano", "vineta", "parpadeo"]
const RENDERERS: Array = [["auto", "GFX_R_AUTO"], ["forward_plus", "GFX_R_FORWARD"], ["gl_compatibility", "GFX_R_COMPAT"]]

var _panel: PanelContainer = null
var _bench_label: Label = null


## Fila del menú de opciones: el botón que abre este panel encima del menú.
static func add_row(parent: Node, host: Control) -> void:
	if GfxSettings.web():
		return  # el HTML no lleva el paquete: el menú de opciones queda como en la beta
	GfxBoot.strings()
	var b := UITheme.button(host.tr("GFX_OPEN"), func() -> void:
		if host.get_node_or_null("GfxOpciones") != null:
			return
		var p := GfxOptions.new()
		p.name = "GfxOpciones"
		host.add_child(p)
		p.closed.connect(p.queue_free))
	b.name = "BotonGraficosAvanzados"
	parent.add_child(b)
	# La ayuda de la fila de calidad describe las calidades de antes: se cambia por la de ahora (sin tocar su CSV).
	var old_hint := host.tr("OPT_QUALITY_HINT_Q5")
	for c in parent.get_children():
		if c is Label and (c as Label).text == old_hint:
			(c as Label).text = host.tr("GFX_QUALITY_HINT")


func _ready() -> void:
	GfxBoot.strings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	add_child(bg)
	_build()


## Al cambiar de idioma con el panel abierto, se vuelve a armar con los textos nuevos (sin reiniciar).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build.call_deferred()   # el aviso llega mientras el árbol se recorre: no se pueden colgar hijos ahí mismo


## Arma (o vuelve a armar) el panel: todos los textos salen de tr() aquí.
func _build() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = UITheme.panel(tr("GFX_TITLE"), Vector2(1120, 0))
	add_child(_panel)
	UITheme.center_fit(_panel)
	var vb := UITheme.vb_of(_panel)
	var enhanced := GfxSettings.enhanced()
	var state := UITheme.label(tr("GFX_STATE") % [tr(GfxQuality.label_key(GfxQuality.level())), tr("GFX_R_FORWARD" if GfxSettings.forward() else "GFX_R_COMPAT")], 13, UITheme.DIM)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(state)
	if not enhanced:
		var note := UITheme.label(tr("GFX_LOW_NOTE"), 13, UITheme.YELLOW)
		note.custom_minimum_size = Vector2(1080, 0)
		vb.add_child(note)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(530, 0)
	left.add_theme_constant_override("separation", 5)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(530, 0)
	right.add_theme_constant_override("separation", 5)
	cols.add_child(right)
	left.add_child(UITheme.label(tr("GFX_G_LIGHT"), 13, UITheme.EZLAK))
	for k in LEFT:
		_option(left, k, enhanced)
	left.add_child(UITheme.label(tr("GFX_G_SURF"), 13, UITheme.EZLAK))
	for k in SURF:
		_option(left, k, enhanced)
	right.add_child(UITheme.label(tr("GFX_G_LENS"), 13, UITheme.EZLAK))
	for k in LENS:
		_option(right, k, enhanced)
	var fn := UITheme.label(tr("GFX_FLICKER_NOTE"), 11, UITheme.DIM)
	fn.custom_minimum_size = Vector2(520, 0)
	right.add_child(fn)
	right.add_child(UITheme.label(tr("GFX_G_SYSTEM"), 13, UITheme.EZLAK))
	_brightness_row(right)
	_global_check(right, "gfx_fps", "GFX_FPS")
	_fps_cap_row(right)
	_global_check(right, "gfx_vsync", "GFX_VSYNC")
	_global_check(right, "gfx_sub_fondo", "GFX_SUB_PLATE")
	_renderer_row(right)
	_bench_row(right)
	vb.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	var reset := UITheme.button(tr("GFX_RESET"), func() -> void:
		GfxSettings.reset_overrides()
		EventBus.settings_changed.emit("gfx")
		_build())
	reset.name = "Restablecer"
	reset.disabled = not enhanced or not GfxSettings.any_override()
	foot.add_child(reset)
	var back := UITheme.button(tr("OPT_BACK"), func() -> void: closed.emit())
	back.name = "Volver"
	foot.add_child(back)
	vb.add_child(foot)


func _row(parent: Node, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(text, 14)
	l.custom_minimum_size = Vector2(250, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	parent.add_child(row)
	return row


func _changed(key: String, v: Variant) -> void:
	GfxSettings.set_value(key, v)
	EventBus.settings_changed.emit("gfx")
	var r := _panel.find_child("Restablecer", true, false) as Button
	if r != null:
		r.disabled = not GfxSettings.any_override()


## Una opción del catálogo: casilla, botón que rota o barra, según su tipo.
func _option(parent: Node, key: String, enhanced: bool) -> void:
	var text := tr("GFX_O_" + key.to_upper())
	var usable := enhanced and GfxSettings.available(key)
	if GfxSettings.TOGGLES.has(key):
		var cb := CheckBox.new()
		cb.name = "Op_" + key
		cb.text = text + ("  " + tr("GFX_ONLY_FORWARD") if (GfxSettings.FORWARD_ONLY.has(key) and not GfxSettings.forward()) else "")
		cb.add_theme_font_size_override("font_size", 14)
		cb.button_pressed = GfxSettings.on(key) and usable
		cb.disabled = not usable
		cb.toggled.connect(func(v: bool) -> void: _changed(key, v))
		parent.add_child(cb)
	elif GfxSettings.CHOICES.has(key):
		var row := _row(parent, text)
		var choices: Array = GfxSettings.CHOICES[key]
		var b := Button.new()
		b.name = "Op_" + key
		b.custom_minimum_size = Vector2(200, 0)
		b.disabled = not enhanced
		b.text = _choice_text(key, choices, GfxSettings.level(key))
		b.pressed.connect(func() -> void:
			var cur := GfxSettings.level(key)
			var idx := 0
			for i in choices.size():
				if int(choices[i][0]) == cur:
					idx = i
			var nxt: int = int(choices[(idx + 1) % choices.size()][0])
			_changed(key, nxt)
			b.text = _choice_text(key, choices, nxt))
		row.add_child(b)
	elif GfxSettings.SLIDERS.has(key):
		var row2 := _row(parent, text)
		var cfg: Array = GfxSettings.SLIDERS[key]
		var s := HSlider.new()
		s.name = "Op_" + key
		s.min_value = float(cfg[0])
		s.max_value = float(cfg[1])
		s.step = float(cfg[2])
		s.value = GfxSettings.amount(key)
		s.editable = enhanced
		s.custom_minimum_size = Vector2(200, 0)
		row2.add_child(s)
		var v := UITheme.label("%d%%" % int(round(s.value * 100.0)), 13, UITheme.DIM)
		v.custom_minimum_size = Vector2(54, 0)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		row2.add_child(v)
		s.value_changed.connect(func(val: float) -> void:
			v.text = "%d%%" % int(round(val * 100.0)))
		# El pase gráfico se rehace al soltar la barra, no en cada paso.
		s.drag_ended.connect(func(_c: bool) -> void: _changed(key, s.value))
		s.focus_exited.connect(func() -> void:
			if not is_equal_approx(s.value, GfxSettings.amount(key)):
				_changed(key, s.value))


## Texto del valor; si con Compatibilidad ese valor usa el sustituto, lo dice.
func _choice_text(key: String, choices: Array, value: int) -> String:
	var t := ""
	for c in choices:
		if int(c[0]) == value:
			t = tr(str(c[1]))
	if not GfxSettings.forward() and GfxSettings.FORWARD_FROM.has(key) and value >= int(GfxSettings.FORWARD_FROM[key]):
		var below := ""
		for c in choices:
			if int(c[0]) == int(GfxSettings.FORWARD_FROM[key]) - 1:
				below = tr(str(c[1]))
		t += "  " + tr("GFX_FALLBACK") % below
	return t


func _global_check(parent: Node, key: String, text_key: String) -> void:
	var cb := CheckBox.new()
	cb.name = "Op_" + key
	cb.text = tr(text_key)
	cb.add_theme_font_size_override("font_size", 14)
	cb.button_pressed = bool(GfxSettings.global(key))
	cb.toggled.connect(func(v: bool) -> void:
		GfxSettings.set_global(key, v)
		EventBus.settings_changed.emit(key))
	parent.add_child(cb)


func _brightness_row(parent: Node) -> void:
	var row := _row(parent, tr("GFX_BRILLO"))
	var v := UITheme.label("%d%%" % int(round(GfxSettings.brillo() * 100.0)), 13, UITheme.DIM)
	v.name = "BrilloValor"
	v.custom_minimum_size = Vector2(54, 0)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	var b := UITheme.button(tr("GFX_CALIBRAR"), func() -> void:
		var c := GfxCalibration.open_in(self)
		c.closed.connect(_refresh_brillo))
	b.name = "Calibrar"
	b.custom_minimum_size = Vector2(200, 0)
	row.add_child(b)
	row.add_child(v)


## El valor junto a «Calibrar brillo…» se busca al cerrar la pantalla (el panel pudo rearmarse mientras tanto).
func _refresh_brillo() -> void:
	var v := find_child("BrilloValor", true, false) as Label
	if v != null:
		v.text = "%d%%" % int(round(GfxSettings.brillo() * 100.0))


func _renderer_row(parent: Node) -> void:
	var row := _row(parent, tr("GFX_RENDERER"))
	var b := Button.new()
	b.name = "Op_gfx_renderer"
	b.custom_minimum_size = Vector2(240, 0)
	var text_of := func(val: String) -> String:
		for r in RENDERERS:
			if str(r[0]) == val:
				return tr(str(r[1]))
		return tr("GFX_R_AUTO")
	b.text = text_of.call(str(GfxSettings.global("gfx_renderer")))
	b.pressed.connect(func() -> void:
		var cur := str(GfxSettings.global("gfx_renderer"))
		var idx := 0
		for i in RENDERERS.size():
			if str(RENDERERS[i][0]) == cur:
				idx = i
		var nxt := str(RENDERERS[(idx + 1) % RENDERERS.size()][0])
		GfxBoot.set_renderer(nxt)
		b.text = text_of.call(nxt))
	row.add_child(b)
	var note := UITheme.label(tr("GFX_RENDERER_NOTE") + " " + tr("GFX_RENDERER_AUTO_NOTE"), 11, UITheme.DIM)
	note.custom_minimum_size = Vector2(520, 0)
	parent.add_child(note)


func _bench_row(parent: Node) -> void:
	var b := UITheme.button(tr("GFX_BENCH"), func() -> void: _run_bench())
	b.name = "Medir"
	parent.add_child(b)
	_bench_label = UITheme.label("", 12, UITheme.DIM)
	_bench_label.name = "MedirTexto"
	_bench_label.custom_minimum_size = Vector2(520, 0)
	parent.add_child(_bench_label)


func _run_bench() -> void:
	var bench := GfxBench.manual(get_tree())
	if bench == null:
		_bench_label.text = tr("GFX_BENCH_NEED_FLOOR")
		return
	_bench_label.text = tr("GFX_BENCH_RUNNING") % ""
	bench.finished.connect(func(report: Dictionary) -> void:
		var parts: Array[String] = []
		for lv in ["alta", "media", "baja"]:
			if (report.get("fps", {}) as Dictionary).has(lv):
				parts.append("%s %d fps" % [tr(GfxQuality.label_key(lv)), int(round(float(report["fps"][lv])))])
		var txt := tr("GFX_BENCH_RESULT") % [" · ".join(parts), tr(GfxQuality.label_key(str(report.get("elegida", "media"))))]
		if is_instance_valid(self):
			_build()
			_bench_label.text = txt)


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and get_node_or_null("GfxCalibration") == null:
		for c in get_children():
			if c is GfxCalibration:
				return
		get_viewport().set_input_as_handled()
		closed.emit()


func _fps_cap_row(parent: Node) -> void:
	var row := _row(parent, tr("GFX_MAX_FPS"))
	var opts := [[60, "60 FPS (Frío / Rec.)"], [90, "90 FPS"], [120, "120 FPS"], [30, "30 FPS (Ahorro)"], [0, tr("GFX_V_UNLIMITED")]]
	var b := Button.new()
	b.name = "Op_gfx_max_fps"
	b.custom_minimum_size = Vector2(200, 0)
	var cur := GfxSettings.max_fps()
	var label_for := func(val: int) -> String:
		for o in opts:
			if int(o[0]) == val:
				return str(o[1])
		return "%d FPS" % val if val > 0 else tr("GFX_V_UNLIMITED")
	b.text = label_for.call(cur)
	b.pressed.connect(func() -> void:
		var c := GfxSettings.max_fps()
		var idx := 0
		for i in opts.size():
			if int(opts[i][0]) == c:
				idx = i
		var nxt: int = int(opts[(idx + 1) % opts.size()][0])
		GfxSettings.set_global("gfx_max_fps", nxt)
		EventBus.settings_changed.emit("gfx_max_fps")
		b.text = label_for.call(nxt))
	row.add_child(b)

class_name ContractUI
extends CanvasLayer
## v0.3.2 · La firma del contrato (final del Training, docs/AVAILABLE_trama_semana_v3 §1.4 y §2.3): el contrato EN PAPEL
## (Joan) sobre la mesa del aula, «Contrato de trabajo a plazo indefinido · Incorporación a la campaña KipuPay»
## (data/contrato.json, cláusulas capciosas), que se puede leer pasando las hojas con la rueda, y una línea de firma
## donde el jugador firma con el lapicero (el ratón). Al soltar «Firmar», la pantalla FALLA UN FOTOGRAMA:
## la sala a oscuras, luz fría y la cara real del Trainer encima (assets/screamers/trainer_grito.png); al fotograma
## siguiente todo vuelve. Emite `signed(read_all)` (read_all = bajó hasta la letra chica).
## Bot/pruebas: sign_for_bot(read) dibuja un trazo y firma; `glitch_frames` = fotogramas que duró la falla.

signal signed(read_all: bool)

const DATA := "contrato"
const GLITCH_TEX := "res://assets/screamers/trainer_grito.png"

var agent: String = "Jiroshi"
var date_text: String = ""
var read_all: bool = false
var is_signed: bool = false
var glitch_frames: int = 0
var strokes: Array = []  # Array[PackedVector2Array] en coordenadas del pad
var _scroll: ScrollContainer = null
var _pad: _Pad = null
var _sign_btn: Button = null
var _glitch: Control = null
var _glitch_left: int = -1
var _root: Control = null
var _sub: Label = null  # el subtítulo del HUD queda debajo del papel: lo que se diga mientras lees sale aquí arriba
var _sub_left: float = 0.0
var _lang: String = ""  # idioma con el que se escribió el papel (si cambia en Opciones, se reescribe)


func _ready() -> void:
	name = "ContractUI"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lang = Loc.language
	_build()
	_sub = UITheme.label("", 25, UITheme.TEXT)
	_sub.name = "Subtitulo"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub.offset_left = -900.0
	_sub.offset_right = 900.0
	_sub.offset_top = 10.0
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_sub.add_theme_constant_override("outline_size", 9)
	_root.add_child(_sub)
	var vd := get_node_or_null("/root/VoiceDirector")
	if vd != null:
		vd.connect("subtitle_shown", _on_subtitle)
		var cur: Object = vd.get("current")  # la línea que ya estaba sonando cuando el papel llegó a la mesa
		if cur != null and str(cur.get("text")) != "":
			var left := maxf(float(cur.get("read_left")), (int(cur.get("wall_end_ms")) - int(vd.call("now_ms"))) / 1000.0)
			_on_subtitle(str(cur.get("speaker")), str(cur.get("text")), maxf(left, 1.5))


func _on_subtitle(_speaker: String, text: String, seconds: float) -> void:
	if not bool(Loc.get_setting("subtitles", true)) or _sub == null:
		return
	_sub.text = text
	_sub_left = seconds


static func data() -> Dictionary:
	return DataLoader.dict(DATA)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.3, 0.2, 0.12, 0.88)  # la mesa del aula (madera)
	_root.add_child(dim)
	var tablet := PanelContainer.new()
	tablet.name = "Papel"
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.965, 0.945, 0.885)
	tsb.border_color = Color(0.78, 0.74, 0.64)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(2)
	tsb.set_content_margin_all(46)
	tsb.shadow_color = Color(0, 0, 0, 0.45)
	tsb.shadow_size = 22
	tsb.shadow_offset = Vector2(10, 14)
	tablet.add_theme_stylebox_override("panel", tsb)
	tablet.custom_minimum_size = Vector2(1000, 920)
	_root.add_child(tablet)
	UITheme.center_fit(tablet)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	tablet.add_child(vb)
	var d := data()
	var ink := Color(0.12, 0.12, 0.14)
	var title := UITheme.label(Loc.pick(d.get("titulo", {})), 26, ink)
	title.name = "Titulo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var num := UITheme.label("N.º KP-%05d · %s" % [abs(agent.hash()) % 100000, TranslationServer.translate("CONTRACT_INDEFINITE")], 12, Color(0.45, 0.42, 0.36), true)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(num)
	var parts := UITheme.label(Loc.fmt(Loc.pick(d.get("partes", {})), {"agente": agent.to_upper(), "fecha": date_text}), 15, Color(0.3, 0.3, 0.33))
	parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(parts)
	_scroll = ScrollContainer.new()
	_scroll.name = "Clausulas"
	_scroll.custom_minimum_size = Vector2(980, 430)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	vb.add_child(_scroll)
	var cl := VBoxContainer.new()
	cl.add_theme_constant_override("separation", 12)
	cl.custom_minimum_size = Vector2(950, 0)
	_scroll.add_child(cl)
	for c in d.get("clausulas", []):
		var small := bool((c as Dictionary).get("chica", false))
		var txt := "%s %d. %s" % [TranslationServer.translate("CONTRACT_CLAUSE"), int(c.get("n", 0)), Loc.pick(c)]
		var l := UITheme.label(txt, 12 if small else 17, Color(0.42, 0.42, 0.44) if small else ink)
		l.name = "Clausula%d" % int(c.get("n", 0))
		l.custom_minimum_size = Vector2(940, 0)
		if small:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 220)
			cl.add_child(gap)
		cl.add_child(l)
	vb.add_child(HSeparator.new())
	var hint := UITheme.label(Loc.pick(d.get("pista", {})), 13, Color(0.38, 0.38, 0.4))
	vb.add_child(hint)
	_pad = _Pad.new()
	_pad.name = "Firma"
	_pad.custom_minimum_size = Vector2(980, 170)
	_pad.ui = self
	vb.add_child(_pad)
	var cap := UITheme.label(Loc.pick(d.get("firma", {})) + " · " + agent.to_upper(), 13, Color(0.3, 0.3, 0.33))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	var clear := UITheme.button(TranslationServer.translate("CONTRACT_CLEAR"), clear_signature)
	clear.name = "Borrar"
	row.add_child(clear)
	_sign_btn = UITheme.button(TranslationServer.translate("CONTRACT_SIGN"), do_sign)
	_sign_btn.name = "FirmarBtn"
	_sign_btn.disabled = true
	_sign_btn.custom_minimum_size = Vector2(260, 52)
	row.add_child(_sign_btn)
	_glitch = _make_glitch()
	add_child(_glitch)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_scrolled(v: float) -> void:
	var sb := _scroll.get_v_scroll_bar()
	if v >= sb.max_value - sb.page - 4.0:
		read_all = true


## Largo total del trazo (para habilitar «Firmar»: una firma no es un punto).
func ink_length() -> float:
	var total := 0.0
	for s in strokes:
		var pts: PackedVector2Array = s
		for i in range(1, pts.size()):
			total += pts[i].distance_to(pts[i - 1])
	return total


func _changed() -> void:
	if _sign_btn != null:
		_sign_btn.disabled = is_signed or ink_length() < 80.0
	if _pad != null:
		_pad.queue_redraw()


func clear_signature() -> void:
	if is_signed:
		return
	strokes.clear()
	_changed()


func do_sign() -> void:
	if is_signed or ink_length() < 80.0:
		return
	is_signed = true
	_sign_btn.disabled = true
	AudioManager.play_sfx("firma_glitch", "UI")
	_glitch.visible = true
	_glitch_left = 1  # un solo fotograma (se cuenta en _process)
	glitch_frames = 0


## El idioma cambió con el contrato sobre la mesa (Opciones desde la pausa): el papel se reescribe en el idioma nuevo
## y conserva lo que ya hiciste (los trazos de la firma, hasta dónde leíste y si ya llegaste a la letra chica).
func relang() -> void:
	_lang = Loc.language
	if is_signed or _root == null or not is_instance_valid(_root):
		return
	var at := _scroll.scroll_vertical if _scroll != null else 0
	var read := read_all
	if _sub != null and _sub.get_parent() != null:
		_sub.get_parent().remove_child(_sub)
	_root.free()
	_glitch.free()
	_build()
	if _sub != null:
		_root.add_child(_sub)
	_changed()
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at
	read_all = read


func _process(delta: float) -> void:
	if _lang != Loc.language:
		relang()
	if _sub_left > 0.0:
		_sub_left -= delta / maxf(Engine.time_scale, 0.001)
		if _sub_left <= 0.0 and _sub != null:
			_sub.text = ""
	if _glitch_left < 0:
		return
	if _glitch.visible:
		glitch_frames += 1
		_glitch_left -= 1
		if _glitch_left <= 0:
			_glitch.visible = false
			_glitch_left = -1
			signed.emit(read_all)


## Firma de prueba (bot): un garabato de ~4 trazos; `read` = baja hasta la letra chica antes.
func sign_for_bot(read: bool = true, animate: bool = false) -> void:
	if animate:
		await _animate_for_video(read)
		return
	if read:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
		read_all = true
	strokes.clear()
	var pts := PackedVector2Array()
	for i in 40:
		var x := 120.0 + i * 14.0
		pts.append(Vector2(x, 90.0 + sin(i * 0.7) * 32.0))
	strokes.append(pts)
	_changed()
	do_sign()


## Para los videos: baja leyendo hasta la letra chica, vuelve a la firma y firma con un trazo que se dibuja.
func _animate_for_video(read: bool) -> void:
	var sb := _scroll.get_v_scroll_bar()
	if read:
		var t := 0.0
		while t < 3.0:
			t += get_process_delta_time()
			_scroll.scroll_vertical = int(sb.max_value * clampf(t / 3.0, 0.0, 1.0))
			await get_tree().process_frame
		read_all = true
		await get_tree().create_timer(1.2).timeout
	strokes.clear()
	strokes.append(PackedVector2Array())
	AudioManager.play_sfx("lapicero_firma", "UI")
	for i in 60:
		var x := 140.0 + i * 11.0
		var pts: PackedVector2Array = strokes[-1]
		pts.append(Vector2(x, 92.0 + sin(i * 0.55) * 30.0 * (1.0 - i / 90.0) + cos(i * 1.7) * 8.0))
		strokes[-1] = pts
		_changed()
		await get_tree().process_frame
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	do_sign()


func _make_glitch() -> Control:
	var g := Control.new()
	g.name = "Falla"
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.visible = false
	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.02, 0.05, 0.07)
	g.add_child(dark)
	var face := TextureRect.new()
	face.name = "CaraReal"
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.modulate = Color(0.7, 0.85, 0.95)
	if ResourceLoader.exists(GLITCH_TEX):
		face.texture = load(GLITCH_TEX) as Texture2D
	g.add_child(face)
	for i in 7:
		var band := ColorRect.new()
		band.color = Color(0.6, 0.9, 1.0, 0.18) if i % 2 == 0 else Color(0, 0, 0, 0.5)
		band.anchor_right = 1.0
		band.offset_top = 90.0 + i * 140.0
		band.offset_bottom = band.offset_top + 10.0 + (i % 3) * 8.0
		band.offset_left = -40.0 * (i % 2)
		g.add_child(band)
	return g


class _Pad extends Control:
	var ui: ContractUI = null
	var _drawing: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_CROSS

	func _gui_input(event: InputEvent) -> void:
		if ui == null or ui.is_signed:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_drawing = (event as InputEventMouseButton).pressed
			if _drawing:
				ui.strokes.append(PackedVector2Array([(event as InputEventMouseButton).position]))
				AudioManager.play_sfx("lapicero_firma", "UI")
			accept_event()
		elif event is InputEventMouseMotion and _drawing and not ui.strokes.is_empty():
			var pts: PackedVector2Array = ui.strokes[-1]
			pts.append((event as InputEventMouseMotion).position)
			ui.strokes[-1] = pts
			ui.call("_changed")
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.0))
		draw_line(Vector2(60, size.y - 36), Vector2(size.x - 60, size.y - 36), Color(0.25, 0.24, 0.22), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(36, size.y - 42), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 0.24, 0.22))
		if ui == null:
			return
		for s in ui.strokes:
			var pts: PackedVector2Array = s
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.05, 0.12, 0.45), 2.6, true)  # tinta azul del lapicero

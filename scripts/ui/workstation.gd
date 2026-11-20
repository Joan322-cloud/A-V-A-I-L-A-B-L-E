extends Control
## Estación de trabajo (v0.3, PLAN §2 #50, §6.5): los dos monitores de la PC dibujados en SubViewports que
## los monitores 3D de C-14 muestran como textura viva:
##   izquierdo = escritorio (PcDesktop: Kardex · Correo · Identa · Portal Vitzo · Campus + "Siguiente paso"),
##   derecho   = Ezlaki (canales y DMs) + Fonex (AUX, contacto, KPI).
## Sentado, [E] sobre un monitor "acerca la vista": overlay 2D con las dos pantallas y el RATÓN funciona
## (los clics se reenvían al SubViewport con push_input). [Tab] cambia entre las dos pantallas / solo la
## izquierda / solo la derecha (más grande). Atajos: Espacio = Ack > aceptar contacto > login; 1-4 opciones
## del árbol; H hold; Enter = reaccionar al recordatorio de Vitzo / unirse a Rooms; F1-F5 apps; Retroceso =
## deshacer el último campo del correo; Q = menú AUX (teclas 1-7). Terminal de pared = la pantalla derecha
## sola (Fonex + Ezlaki): AUX con clic o 1-7, reacción con clic o Enter, Q/E para cerrar.
## Arreglos de §6.5: el menú AUX ya no se traga el Espacio ni cierra el terminal al reaccionar; nada exige
## "enfocar" Ezlaki con Tab; el correo tiene campos separados y deshacer; acciones aux_1..aux_7 remapeables;
## el ratón funciona en la vista acercada.
## v0.3.1 Q1: reset() (B3: volver al menú nunca deja la PC abierta para el turno siguiente); las sillas sin
## monitores (calibración, training) no muestran la PC (F4); encuadre nuevo de la vista acercada (F10): las
## pantallas ocupan ≥ 90 % del ancho y ≥ 70 % del alto en 16:9, 16:10 y 21:9 (la pantalla «crece» en alto mientras
## está acercada: el SubViewport pasa de 800×492 a 800×(hasta 900) y el escritorio se reacomoda), con marco de
## monitor, y la sala se ve alrededor tras un fondo del 35 % con viñeta.

const SCREEN_W := PcStyle.W
const SCREEN_H := PcStyle.H
const LAYOUTS: Array[String] = ["ambas", "izquierda", "derecha"]
## F10: fracción de la vista que pueden ocupar las pantallas acercadas y alto máximo del SubViewport acercado.
## v0.3.1 Q1 (F10, revisión de Joan): las pantallas ocupan la mayor parte de la vista pero queda la sala alrededor
## (cubículo, escritorio, bordes de los monitores) y una franja arriba para los avisos de primera vez (AgentTips).
const ZOOM_W_FRAC := 0.88
const ZOOM_H_FRAC := 0.76
const ZOOM_TOP_FRAC := 0.12  # franja libre arriba (avisos de primera vez; el HUD va a la derecha)
const ZOOM_VP_MAX_H := 900
const BEZEL := 7.0
const ZOOM_GAP := 14.0

var _left_vp: SubViewport = null
var _right_vp: SubViewport = null
var _zoom_left: TextureRect = null
var _zoom_right: TextureRect = null
var _zoom_box: HBoxContainer = null
var _frame_left: PanelContainer = null
var _frame_right: PanelContainer = null
var _right_box: VBoxContainer = null
var _right_bg: ColorRect = null
var _screen_h: int = SCREEN_H  # alto actual de los SubViewports (F10: crece mientras la vista está acercada)
var _backdrop: ColorRect = null
var layout_area_override: Vector2 = Vector2.ZERO  # pruebas (q1_f10_encuadre): vista lógica a simular
## v0.3.2 (feedback de Joan sobre la beta: «los pasos del Training tapan la interfaz de la PC y de Ezlaki»): franja de
## arriba, en px lógicos, que la vista acercada deja libre para la guía del Training (TrainingCoach). Las pantallas se
## acomodan DEBAJO de ella con la misma escala (solo pierden alto: el escritorio se reacomoda, como en F10). 0 = nada
## reservado (el encuadre de siempre).
var reserve_top: float = 0.0:
	set(v):
		if not is_equal_approx(reserve_top, v):
			reserve_top = v
			_layout_zoom.call_deferred()
var _aux_menu: PanelContainer = null
var _ww: PanelContainer = null
var _ww_lbl: Label = null
var _ww_timer: Label = null
var _help: Label = null
var _help_box: PanelContainer = null
var _wallpaper: TextureRect = null
var _wallpaper_l: TextureRect = null
var _glitch_l: Control = null
var _glitch_r: Control = null
var _glitch_wait: float = 8.0
var _glitch_left: float = 0.0
var _terminal_mode: bool = false
var _layout: int = 0
var zoomed: bool = false
var hub: EzlakHub = null
var desktop: PcDesktop = null
var ezlak: PcEzlak = null
var fonex: PcFonex = null
var contacts: ContactManager = null:
	set = _set_contacts


func _ready() -> void:
	add_to_group("workstation")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	hub = EzlakHub.new()
	hub.name = "EzlakHub"
	add_child(hub)
	_build()
	EventBus.player_seated.connect(_on_seated)
	EventBus.player_stood_up.connect(_on_stood_up)
	EventBus.written_warning_issued.connect(_on_ww)
	EventBus.ack_given.connect(func() -> void: _ww.visible = false)
	EventBus.ack_expired.connect(func() -> void: _ww.visible = false)
	EventBus.respawned.connect(func(_k: String) -> void: _reset_popups())
	Loc.language_changed.connect(_on_language_changed)
	EventBus.shift_started.connect(func() -> void: _reset_popups(); desktop.open_app("kardex"); ezlak.open_channel("#team-familia"))


func _set_contacts(c: ContactManager) -> void:
	contacts = c
	if desktop != null:
		desktop.bind(c)
	if fonex != null:
		fonex.cm = c


func _make_screen(p_name: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = p_name
	vp.size = Vector2i(SCREEN_W, SCREEN_H)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.gui_disable_input = false
	vp.gui_embed_subwindows = true  # los desplegables (OptionButton) se dibujan dentro de la pantalla
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(vp)
	return vp


func _make_zoom(vp: SubViewport) -> TextureRect:
	# F10: cada pantalla con su marco de monitor (bisel oscuro) dentro de la caja acercada.
	var frame := PanelContainer.new()
	frame.name = "Moldura_" + vp.name
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.047, 0.05)
	sb.border_color = Color(0.13, 0.135, 0.14)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(BEZEL)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	var t := TextureRect.new()
	t.texture = vp.get_texture()
	t.custom_minimum_size = Vector2(SCREEN_W, SCREEN_H)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.visible = false
	t.gui_input.connect(func(ev: InputEvent) -> void: _forward(vp, t, ev))
	frame.add_child(t)
	_zoom_box.add_child(frame)
	return t


func _build() -> void:
	_left_vp = _make_screen("PantallaIzq")
	_right_vp = _make_screen("PantallaDer")
	desktop = PcDesktop.new()
	desktop.name = "Escritorio"
	_left_vp.add_child(desktop)
	var right := VBoxContainer.new()
	right.name = "EzlakFonex"
	right.add_theme_constant_override("separation", 4)
	right.size = Vector2(SCREEN_W, SCREEN_H)
	_right_box = right
	var bg := ColorRect.new()
	bg.color = PcStyle.BG
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_bg = bg
	_right_vp.add_child(bg)
	_right_vp.add_child(right)
	ezlak = PcEzlak.new()
	ezlak.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ezlak)
	ezlak.bind(hub)
	fonex = PcFonex.new()
	right.add_child(fonex)
	# Fondo de Vitzo (tras su screamer): su cara "quemada" encima de ambas pantallas, translúcida.
	var vtex := Faces.texture_at("res://assets/ui/vitzo_cara.png")
	_wallpaper = _wall(vtex, 0.22)
	_right_vp.add_child(_wallpaper)
	_wallpaper_l = _wall(vtex, 0.16)
	_left_vp.add_child(_wallpaper_l)
	_glitch_l = _glitch_layer()
	_left_vp.add_child(_glitch_l)
	_glitch_r = _glitch_layer()
	_right_vp.add_child(_glitch_r)
	# Vista acercada (F10): la sala se ve alrededor tras un fondo del 35 % con viñeta (antes negro al 82 %) y las
	# dos pantallas, con su marco, ocupan casi toda la vista.
	_backdrop = ColorRect.new()
	_backdrop.name = "FondoZoom"
	_backdrop.color = Color(0.0, 0.0, 0.01, 0.35)
	_backdrop.material = _backdrop_material()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	add_child(_backdrop)
	_zoom_box = HBoxContainer.new()
	_zoom_box.name = "CajaZoom"
	_zoom_box.add_theme_constant_override("separation", int(ZOOM_GAP))
	_zoom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zoom_box)
	_zoom_left = _make_zoom(_left_vp)
	_zoom_right = _make_zoom(_right_vp)
	_frame_left = _zoom_left.get_parent() as PanelContainer
	_frame_right = _zoom_right.get_parent() as PanelContainer
	get_viewport().size_changed.connect(_layout_zoom)
	_zoom_box.minimum_size_changed.connect(_layout_zoom.call_deferred)
	# v0.3.2-core: la línea de atajos a 13 px en gris sobre el escritorio no se leía en la ventana de 1280×720.
	# Va sobre una pastilla oscura del ancho del texto: encima del escritorio claro, ni con borde se leía bien.
	_help_box = PanelContainer.new()
	_help_box.name = "Atajos"
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.02, 0.03, 0.04, 0.78)
	hsb.set_corner_radius_all(3)
	hsb.content_margin_left = 12
	hsb.content_margin_right = 12
	hsb.content_margin_top = 2
	hsb.content_margin_bottom = 3
	_help_box.add_theme_stylebox_override("panel", hsb)
	_help_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_help_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help_box.offset_top = -5
	_help_box.offset_bottom = -5
	_help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_box.visible = false
	add_child(_help_box)
	_help = UITheme.label("", 15, Color(0.8, 0.84, 0.88))
	_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_box.add_child(_help)
	# Menú AUX (Q) y WW: modales del overlay.
	_aux_menu = UITheme.panel(tr("FONEX_TERMINAL_TITLE"), Vector2(360, 0))
	UITheme.center_fit(_aux_menu)
	var vb := UITheme.vb_of(_aux_menu)
	for i in Metrics.AUX_KEYS.size():
		var idx := i
		var b := UITheme.button("%d · %s" % [i + 1, tr(Metrics.AUX_KEYS[i])], func() -> void: _pick_aux(idx))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("guia", "aux_menu:%d" % i)  # la guía del Training señala el botón exacto (TrainingTargets)
		vb.add_child(b)
	vb.add_child(UITheme.label(Controls.hint("[Q] ") + tr("OPT_BACK"), 13, UITheme.DIM))
	_aux_menu.visible = false
	add_child(_aux_menu)
	_ww = UITheme.panel(tr("EZLAK_WW_TITLE"), Vector2(620, 0))
	(_ww.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UITheme.RED
	(_ww.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
	UITheme.center_fit(_ww)
	_ww_lbl = UITheme.label("", 18)
	UITheme.vb_of(_ww).add_child(_ww_lbl)
	UITheme.vb_of(_ww).add_child(UITheme.label(tr("EZLAK_WW_CC"), 13, UITheme.DIM))
	_ww_timer = UITheme.label("", 18, UITheme.RED)
	UITheme.vb_of(_ww).add_child(_ww_timer)
	var ack := UITheme.button(tr("EZLAK_ACK"), func() -> void: _give_ack())
	ack.focus_mode = Control.FOCUS_NONE
	ack.set_meta("guia", "ww:ack")
	UITheme.vb_of(_ww).add_child(ack)
	_ww.visible = false
	add_child(_ww)


func _wall(tex: Texture2D, alpha: float) -> TextureRect:
	var w := TextureRect.new()
	w.name = "Fondo_Vitzo"
	w.size = Vector2(SCREEN_W, SCREEN_H)
	w.texture = tex
	w.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w.modulate = Color(1, 1, 1, alpha)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.visible = false
	return w


func _glitch_layer() -> Control:
	var g := Control.new()
	g.name = "Glitch"
	g.size = Vector2(SCREEN_W, SCREEN_H)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.visible = false
	for i in 5:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(r)
	return g


## Reenvía el ratón de la vista acercada al SubViewport (coordenadas de la pantalla).
func _forward(vp: SubViewport, t: TextureRect, ev: InputEvent) -> void:
	if not (ev is InputEventMouse):
		return
	var e := ev.duplicate() as InputEventMouse
	var k := Vector2(vp.size) / t.size
	e.position = (ev as InputEventMouse).position * k
	e.global_position = e.position
	if e is InputEventMouseMotion:
		(e as InputEventMouseMotion).relative *= k
	vp.push_input(e, true)
	if ev is InputEventMouseButton:
		accept_event()


## Clic simulado en una pantalla ("left" | "right") en coordenadas de la pantalla (pruebas ui_pc y bot).
func click_screen(side: String, pos: Vector2) -> void:
	var vp := _left_vp if side == "left" else _right_vp
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		vp.push_input(e, true)


## Centro (en coordenadas de la pantalla) de un control dibujado en una de las pantallas.
func screen_pos_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## F10: encuadre de la vista acercada. Con las dos pantallas lado a lado, dos 800×492 dan 3,25:1 y en 16:9 dejan
## media pantalla en negro; aquí el SubViewport acercado crece en alto hasta la proporción que llena el hueco
## (≥ 90 % del ancho y ≥ 70 % del alto en 16:9, 16:10 y 21:9) y el contenido de la PC se reacomoda (apps con scroll).
func _layout_zoom() -> void:
	if _zoom_box == null or not is_inside_tree():
		return
	var area := get_viewport_rect().size if layout_area_override == Vector2.ZERO else layout_area_override
	var n := 1 if (_terminal_mode or LAYOUTS[_layout] != "ambas") else 2
	# Franja útil: de `top` (12 % de la vista, o lo que reserva la guía del Training) a `bottom` (88 % − 30 px). Sin
	# reserva es exactamente el encuadre de F10.
	var bottom := area.y * (ZOOM_TOP_FRAC + ZOOM_H_FRAC) - 30.0
	var top := minf(maxf(area.y * ZOOM_TOP_FRAC, reserve_top), bottom - 120.0)
	var avail := Vector2(area.x * ZOOM_W_FRAC, bottom - top)
	var each := Vector2((avail.x - ZOOM_GAP * (n - 1)) / n - BEZEL * 2.0, avail.y - BEZEL * 2.0)
	var want_h := SCREEN_H
	if zoomed and each.x > 1.0:
		want_h = clampi(int(round(SCREEN_W * each.y / each.x)), SCREEN_H, ZOOM_VP_MAX_H)
	_set_screen_height(want_h)
	var mn := _zoom_box.get_combined_minimum_size()
	_zoom_box.size = mn
	var s := minf(avail.x / maxf(mn.x, 1.0), avail.y / maxf(mn.y, 1.0))
	s = clampf(s, 0.2, 3.0)
	_zoom_box.scale = Vector2(s, s)
	_zoom_box.position = Vector2((area.x - mn.x * s) * 0.5, top + maxf(0.0, (avail.y - mn.y * s) * 0.5))


## Alto de las dos pantallas (SubViewports y todo lo que va dentro). 492 = el de los monitores 3D.
func _set_screen_height(h: int) -> void:
	if h == _screen_h:
		return
	_screen_h = h
	var sz := Vector2(SCREEN_W, h)
	for vp in [_left_vp, _right_vp]:
		(vp as SubViewport).size = Vector2i(sz)
	for t in [_zoom_left, _zoom_right]:
		(t as TextureRect).custom_minimum_size = sz
	if desktop != null:
		desktop.resize_to(sz)
	if _right_box != null:
		_right_box.size = sz
		_right_bg.size = sz
	for c in [_wallpaper, _wallpaper_l, _glitch_l, _glitch_r]:
		if c != null:
			(c as Control).size = sz


## Rect de las pantallas acercadas en la vista (pruebas F10): unión de los marcos visibles.
func zoom_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for f in [_frame_left, _frame_right]:
		if f != null and (f as Control).visible:
			var g := (f as Control).get_global_rect()
			r = g if first else r.merge(g)
			first = false
	return r


func screen_height() -> int:
	return _screen_h


## v0.3.2 · guía del Training: la pantalla ("left" | "right") y su textura acercada, para llevar el rect de un control
## dibujado en la pantalla a la vista (TrainingTargets). `zoom_shown(side)` = esa pantalla está acercada y a la vista.
func screen_viewport(side: String) -> SubViewport:
	return _left_vp if side == "left" else _right_vp


func zoom_shown(side: String) -> bool:
	var t := _zoom_left if side == "left" else _zoom_right
	return visible and zoomed and t != null and t.is_visible_in_tree()


## Rect en la vista (coordenadas del canvas) de un rect en coordenadas de la pantalla, con la vista acercada.
func screen_rect_in_view(side: String, r: Rect2) -> Rect2:
	var t := _zoom_left if side == "left" else _zoom_right
	var vp := screen_viewport(side)
	if t == null or vp == null or t.size.x < 1.0 or t.size.y < 1.0:
		return Rect2()
	var k := t.size / Vector2(vp.size)
	return t.get_global_transform() * Rect2(r.position * k, r.size * k)


## Menús del overlay que la guía no debe tapar (menú AUX, aviso del WW): los visibles, como rects de la vista.
func overlay_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p: Control in [_aux_menu, _ww]:
		if p != null and p.is_visible_in_tree():
			out.append(p.get_global_transform() * Rect2(Vector2.ZERO, p.size))
	return out


static func _backdrop_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.0, 0.8)) * 1.4;
	COLOR = vec4(0.0, 0.0, 0.01, mix(0.1, 0.42, smoothstep(0.5, 1.05, d)));  // v0.3.1: la sala se sigue viendo
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Textura viva de una pantalla ("left" | "right") para los monitores 3D.
func screen_texture(side: String) -> Texture2D:
	return (_left_vp if side == "left" else _right_vp).get_texture()


func _reset_popups() -> void:
	_ww.visible = false
	_aux_menu.visible = false
	GameState.flags["aux_menu_open"] = false
	GameState.flags["pc_text_focus"] = false


## ¿La silla `seat` tiene monitores (la PC de un puesto) o es una silla sin pantallas (calibración, training)?
## API pública (P5 la usa al volver a mostrar la PC tras el feedback o la clase).
func seat_has_screens(seat: String) -> bool:
	return _seat_has_screens(seat)


func _seat_has_screens(seat: String) -> bool:
	for s in get_tree().get_nodes_in_group("monitor_screens"):
		if s is MonitorScreen and (s as MonitorScreen).seat_id == seat:
			return true
	return false


func _on_seated(seat: String) -> void:
	_terminal_mode = false
	if not _seat_has_screens(seat):
		# F4: la calibración y el training no tienen PC: ni AUX ni Ezlaki ahí (Haime/el Trainer te ponen el AUX).
		visible = false
		set_zoom(false)
		return
	visible = true
	set_zoom(false)


## B3: deja la estación como al arrancar (volver al menú, turno nuevo): oculta, sin acercar, sin menú AUX,
## sin modo terminal, sin popups ni foco de texto.
func reset() -> void:
	_terminal_mode = false
	_layout = 0
	reserve_top = 0.0
	_reset_popups()
	set_zoom(false)
	visible = false
	GameState.flags["pc_zoom"] = false
	GameState.flags["terminal_open"] = false


## v0.3.2-core: las apps de la PC solo se redibujan cuando cambia su «firma» (fase, caso, mensajes…). Al cambiar de
## idioma la firma es la misma y el Kardex seguía diciendo «Sin caso abierto» en el turno en inglés: se les borra la
## caché para que se dibujen de nuevo en el siguiente cuadro.
func _on_language_changed(_code: String) -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		for p: String in ["_sig", "_pres_sig", "_node_sig", "_topic_text"]:
			if p in n and n.get(p) is String:
				n.set(p, "")
		for p: String in ["_dirty", "_dirty_side"]:
			if p in n and n.get(p) is bool:
				n.set(p, true)


func _on_stood_up() -> void:
	visible = false
	set_zoom(false)
	_aux_menu.visible = false
	GameState.flags["aux_menu_open"] = false


func set_zoom(on: bool) -> void:
	zoomed = on
	var mode := "derecha" if _terminal_mode else LAYOUTS[_layout]
	_zoom_left.visible = on and mode != "derecha"
	_zoom_right.visible = on and mode != "izquierda"
	_frame_left.visible = _zoom_left.visible
	_frame_right.visible = _zoom_right.visible
	_help_box.visible = on
	_backdrop.visible = on
	_help.text = tr("P4_HELP_TERMINAL") if _terminal_mode else tr("P4_HELP_PC")
	_layout_zoom.call_deferred()
	GameState.flags["pc_zoom"] = on
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif player != null and GameState.running and not get_tree().paused and not Checkpoints.death_visible:
		player.call("capture_mouse", true)
	if not on:
		GameState.flags["pc_text_focus"] = false
		for vp in [_left_vp, _right_vp]:
			var f := (vp as SubViewport).gui_get_focus_owner()
			if f != null:
				f.release_focus()


func toggle_zoom() -> void:
	set_zoom(not zoomed)


func cycle_layout() -> void:
	_layout = (_layout + 1) % LAYOUTS.size()
	set_zoom(true)


func _toggle_power() -> void:
	var any_on := false
	var screens: Array[MonitorScreen] = []
	for s in get_tree().get_nodes_in_group("monitor_screens"):
		if s is MonitorScreen and (s as MonitorScreen).seat_id == GameState.seated_at:
			screens.append(s)
			any_on = any_on or (s as MonitorScreen).powered
	if screens.is_empty():
		return
	for s in screens:
		s.set_powered(not any_on)
	GameState.flags["monitors_off"] = any_on
	if any_on:
		set_zoom(false)


## Terminal Fonex de pared: la pantalla derecha (Fonex + Ezlaki) con ratón; AUX con clic o 1-7.
func open_terminal(_id: String) -> void:
	# v0.3.2 (Joan): ya no hay terminales Fonex de pared: el AUX solo en las PCs de la sala (o con el comodín).
	push_warning("open_terminal(%s): no hay terminales desde la v0.3.2" % _id)


func _close_terminal() -> void:
	_terminal_mode = false
	visible = GameState.seated_at != ""  # el terminal se usa de pie; si sigues sentado, la PC sigue ahí
	set_zoom(false)
	_aux_menu.visible = false
	GameState.flags["aux_menu_open"] = false


## Teclado → campo de texto de una pantalla (buscador de Kardex / Portal) mientras tenga el foco.
func _input(event: InputEvent) -> void:
	if not visible or not zoomed or not (event is InputEventKey):
		return
	for vp in [_left_vp, _right_vp]:
		var f := (vp as SubViewport).gui_get_focus_owner()
		if f is LineEdit:
			var k := event as InputEventKey
			if k.alt_pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
				return  # v0.3.2-core: Alt+Intro es la pantalla completa (Loc), no un Intro para el campo de texto
			if k.keycode >= KEY_F1 and k.keycode <= KEY_F5 and not _terminal_mode:
				# v0.3.2: F1-F5 no son texto: cambian de app aunque estés escribiendo en un buscador o en el chat
				# (antes, tras escribir el KP en Kardex o en el Portal, las teclas de las apps quedaban muertas).
				f.release_focus()
				return
			if k.pressed and k.keycode == KEY_ESCAPE:
				f.release_focus()
			else:
				(vp as SubViewport).push_input(event, true)
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("aux_wheel"):
		if _terminal_mode and not _aux_menu.visible:
			_close_terminal()
		else:
			_toggle_aux_menu(not _aux_menu.visible)
		get_viewport().set_input_as_handled()
		return
	if _aux_menu.visible or _terminal_mode:
		for i in Controls.AUX_ACTIONS.size():
			if event.is_action_pressed(Controls.AUX_ACTIONS[i]):
				_pick_aux(i)
				get_viewport().set_input_as_handled()
				return
	if _terminal_mode and event.is_action_pressed("interact"):
		_close_terminal()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).keycode
		if zoomed and ezlak.key_action(key):  # v0.3.2 IA: selector de reacciones ([Enter], ← →, [Enter])
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			if ezlak.enter_action():
				get_viewport().set_input_as_handled()
				return
		if key >= KEY_F1 and key <= KEY_F5 and not _terminal_mode:
			desktop.open_app(PcDesktop.APPS[key - KEY_F1])
			if not zoomed:
				set_zoom(true)
			get_viewport().set_input_as_handled()
			return
		if key == KEY_BACKSPACE and desktop.active_app == "correo":
			desktop.correo.undo_last()
			get_viewport().set_input_as_handled()
			return
	if not _terminal_mode:
		if event.is_action_pressed("interact") and zoomed:
			set_zoom(false)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("aux_menu"):
			if zoomed:
				cycle_layout()
			else:
				set_zoom(true)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("monitor_toggle"):
			_toggle_power()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("accept"):
		if press_accept():
			get_viewport().set_input_as_handled()


## Espacio / botón Aceptar: Ack (prioridad) > aceptar el contacto > iniciar sesión. true si hizo algo.
func press_accept() -> bool:
	if Metrics.ack_pending:
		_give_ack()
		return true
	if contacts != null and contacts.phase == ContactManager.Phase.OFFERING and contacts.player_ready():
		contacts.accept()
		return true
	if GameState.seated_at != "" and not GameState.logged_in and not _terminal_mode:
		GameState.login()
		AudioManager.play_sfx("fonex_cambio_aux", "UI")
		EventBus.ezlak_post.emit("#team-familia", "sistema", tr("P4_EZLAK_INDUCTION"), {"tipo": "induccion", "silent": true})
		EventBus.ezlak_post.emit("#site-updates", "sistema", tr("EZLAK_PINNED_FLOOR5"), {"tipo": "fijado", "silent": true})
		Checkpoints.save_checkpoint("login")
		return true
	return false


func _give_ack() -> void:
	if Metrics.give_ack():
		EventBus.ezlak_post.emit("dm:shero", "yo", tr("EZLAK_PLAYER_ACK"), {"tipo": "ack", "silent": true})


func _toggle_aux_menu(on: bool) -> void:
	_aux_menu.visible = on
	GameState.flags["aux_menu_open"] = on


func _pick_aux(i: int) -> void:
	if not GameState.logged_in:
		return
	GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()  # v0.3.2: lo cambió el jugador (ACD)
	Metrics.set_aux(i)
	_toggle_aux_menu(false)
	Checkpoints.on_aux_picked(i)  # checkpoint «aux» / «break» (v0.3.2-core3: la regla vive en Checkpoints)
	if _terminal_mode:
		_close_terminal()


## v0.2 (bot y pruebas viejas): responder la excusa del correo de más de 10 min.
func _answer_excuse(i: int) -> void:
	hub.quick_reply("dm:shero", "excusa_%d" % (i + 1))


func _process(delta: float) -> void:
	if Metrics.ack_pending:
		_ww.visible = true
		_ww_timer.text = "%s  %.1f s" % [tr("EZLAK_ACK"), Metrics.ack_left]
	var looking := zoomed and visible
	if zoomed and visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Las pantallas viven en los monitores 3D: se refrescan aunque el overlay no esté abierto.
	if GameState.running or visible:
		desktop.refresh(delta)
		ezlak.refresh(delta, looking)
		fonex.refresh(delta)
	_wallpaper.visible = bool(GameState.flags.get("vitzo_wallpaper", false)) and _wallpaper.texture != null
	_wallpaper_l.visible = _wallpaper.visible
	_tick_glitch(delta)


## Fatiga ≥ 60: fotogramas de "falla" en las pantallas (bandas desplazadas); con "reducir destellos", solo
## bandas oscuras. Nunca tapan más de 0,12 s.
func _tick_glitch(delta: float) -> void:
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_glitch_l.visible = false
			_glitch_r.visible = false
		return
	if Fatigue.value < 60.0 or not GameState.running:
		return
	_glitch_wait -= delta
	if _glitch_wait > 0.0:
		return
	_glitch_wait = randf_range(5.0, 14.0) * (1.5 if Fatigue.value < 75.0 else 1.0)
	_glitch_left = randf_range(0.06, 0.12)
	var soft := bool(Loc.get_setting("flash_reduction", false))
	for g in [_glitch_l, _glitch_r]:
		(g as Control).visible = randf() < 0.7
		for r in (g as Control).get_children():
			var cr := r as ColorRect
			var h := randf_range(4.0, 26.0)
			cr.position = Vector2(randf_range(-40.0, 40.0), randf_range(0.0, SCREEN_H - h))
			cr.size = Vector2(SCREEN_W + 80.0, h)
			cr.color = Color(0, 0, 0, 0.6) if soft or randf() < 0.5 else Color(0.5, 0.02, 0.02, 0.35)


func _on_ww(number: int, reason: String) -> void:
	_ww.visible = true
	_ww_lbl.text = "#%d · %s" % [number, Checkpoints.cause_text(reason)]
	# v0.3.2 (Joan): el WW ya no abre el DM de Shero: el aviso del WW con el Ack ([Espacio]) está encima de la PC y
	# el DM queda resaltado con su insignia.


## Fondo de PC de Vitzo (tras el screamer): textura opcional de assets/ui.
func set_wallpaper(tex: Texture2D) -> void:
	_wallpaper.texture = tex
	_wallpaper_l.texture = tex

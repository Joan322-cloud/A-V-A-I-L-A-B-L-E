class_name TrainingCoach
extends Control
## v0.3.2 (feedback de Joan sobre la beta) · LA GUÍA DEL TRAINING: el panel de los pasos y lo que señala.
##   1. «Los pasos escritos deberían resaltar más, me tomó un rato verlos» → letra grande (24 px de diseño; antes 19 y
##      16 con la PC acercada), fondo opaco, borde y barra cian, pastilla «TRAINING», barra de avance del tema y un
##      AVISO cada vez que cambia el paso: destello del panel, un anillo que se cierra sobre él y un sonido corto
##      (sfx/tut_paso, por el bus UI: no ocupa el canal de las voces ni toca los subtítulos).
##   2. «Los pasos, sobre todo las preguntas, a veces exceden lo visible y no se ve «Continuar»» → el panel mide lo
##      que mide su texto (se calcula con la fuente, no con el alto mínimo de un Label con autowrap, que tarda un
##      cuadro y antes dejaba cajones altos o el panel trepando), nunca sale de la vista y, si el texto no cabe, es
##      el TEXTO el que tiene scroll: los botones («Continuar», «Sí», «No», «Saltar módulo») van en un pie fijo.
##   3. «Los pasos se sobreponen y tapan la interfaz de Ezlaki y de la PC» → con la PC acercada la guía es una franja
##      ARRIBA y la PC se acomoda debajo (Workstation.reserve_top): no se tocan nunca. De pie o sentado sin acercar
##      va arriba a la izquierda y, si lo que hay que usar cae ahí, pasa a la derecha (debajo del reloj). Además
##      SEÑALA el control exacto del paso: contorno que late + flecha (botón de Fonex, canal de Ezlaki, campo del
##      correo, botón del menú AUX, el Ack del WW, el piso del ascensor…; sin acercar, sobre el monitor 3D; en el
##      mundo, sobre la luz guía o en el borde de la vista hacia donde hay que girar). Ver TrainingTargets.
## Tampoco tapa: los subtítulos (franja de abajo), la columna del HUD (reloj, AUX, métricas), los menús abiertos
## (menú AUX, WW, ascensor, comodín, pantalla de muerte) ni el aviso de texto del HUD, que mientras dura el Training
## sale DENTRO de la guía (grupo «hud_notice_host»).
## Tutorial solo escribe los textos (title, body, hint, target_lbl, keys) y enseña u oculta los botones; el resto
## (medir, acomodar, señalar) lo hace este nodo en cada cuadro. Todo en px lógicos de la vista (1920×1080 de diseño;
## más chica en ventanas pequeñas y en el navegador: los anchos salen de la vista, nunca de constantes).

const MARGIN := 20.0  # borde de la vista
const GAP := 12.0  # aire mínimo con lo que no se tapa
const TOP_PC := 12.0  # la franja de arriba con la PC acercada
const SUB_ZONE := 280.0  # franja de abajo que es de los subtítulos y de los avisos del HUD
const H_MIN := 150.0  # menos que esto no es un panel: cabecera, una línea y el pie
const ACCENT := Color(0.25, 0.92, 0.98)
const GOLD := Color(0.99, 0.82, 0.22)
const BG := Color(0.02, 0.05, 0.07, 0.97)
const CUE_S := 0.9
const OPT_PX := 20  # letra de las opciones del mini-check
const OPT_PAD := Vector2(12.0, 7.0)  # aire del texto dentro del botón de cada opción
const TITLE_PX := 16
const KEYS_PX := 15
const RESULT_PX := 20
const TARGET_PX := 16
const KEYS_MIN_W := 240.0  # con menos sitio que esto al lado de los botones, las teclas van en su propio renglón
const PC_MIN_H := 120.0  # alto mínimo que Workstation deja a las pantallas acercadas (la franja nunca pasa de ahí)

var tut: Node = null  # Tutorial (para el objetivo del mundo)
var panel: PanelContainer = null
var title: Label = null
var body: Label = null
var opts_box: BoxContainer = null
var hint: Label = null
var target_lbl: Label = null
var keys: Label = null
var btn_next: Button = null
var btn_yes: Button = null
var btn_no: Button = null
var btn_skip: Button = null
var btn_ans: Array[Button] = []  # [1] [2] [3] en el pie fijo: el mini-check se contesta aunque sus opciones necesiten scroll
var scroll: ScrollContainer = null
var target_ids: Array = []  # ids de TrainingTargets del paso (lo primero que se pueda señalar)
var result: Label = null  # mini-check: «✓ ¡Correcto!» / «✗ La respuesta era…» + la explicación, debajo de las opciones
var result_reserve: String = ""  # el resultado más largo que puede salir: su sitio se guarda desde antes (el panel no salta al contestar)
var progress: float = 0.0  # avance del tema (0-1)
var waiting: bool = false  # el paso espera que el jugador haga algo: la barra late
var idle: bool = false  # entre dos pasos: panel apagado

var target: Dictionary = {}  # lo que se está señalando ahora (TrainingTargets.resolve)
var side: String = "izq"  # izq | der | pc
var _content: VBoxContainer = null
var _chip: PanelContainer = null
var _bar: ProgressBar = null
var _note: Label = null
var _foot: HBoxContainer = null
var _vb: VBoxContainer = null
var _foot_gap: Control = null  # con las teclas en su propio renglón: empuja «Saltar módulo» a la derecha
var _stacked: bool = false  # las teclas van en un renglón aparte, encima del pie (panel angosto)
var _ruler: Label = null
var _pointer: Pointer = null
var _sb: StyleBoxFlat = null
var _sig: String = ""
var _rect: Rect2 = Rect2()
var _cue_t: float = 0.0
var _t: float = 0.0
var _bad_t: float = 0.0
var _note_left: float = 0.0
var _body_px: int = 24
var _hint_px: int = 19
var _exact: Dictionary = {}  # alto de verdad de un texto ya puesto (clave px|mono|ancho|texto): manda sobre la regla
var _used: Dictionary = {}  # lo que se le dio a cada etiqueta en el último acomodo: Label → {clave, ancho, alto}
var _csig: String = ""  # firma del contenido: mientras no cambie, las medidas por ancho se reutilizan (no se mide en cada cuadro)
var _m_cache: Dictionary = {}
var sound: bool = true
var _opt_cb: Callable = Callable()
var _answered: bool = false
var min_h: float = H_MIN  # alto mínimo del panel con el texto de ahora (pruebas)
var true_ups: int = 0  # veces que una etiqueta corrigió a la regla (pruebas: debería ser raro)


## Los nodos se arman al crear la guía (Tutorial los usa enseguida, antes de que su capa entre al árbol).
func _init() -> void:
	name = "Guia"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer = Pointer.new()
	_pointer.name = "Senal"
	_pointer.coach = self
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pointer)
	_build_panel()
	_ruler = Label.new()
	_ruler.name = "Regla"
	_ruler.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ruler.visible = false
	_ruler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ruler)


func _ready() -> void:
	add_to_group("hud_notice_host")
	if not VoiceDirector.notice_shown.is_connected(_on_notice_shown):
		VoiceDirector.notice_shown.connect(_on_notice_shown)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "PanelTraining"
	_sb = StyleBoxFlat.new()
	_sb.bg_color = BG
	_sb.border_color = ACCENT
	_sb.set_border_width_all(3)
	_sb.border_width_left = 10
	_sb.set_corner_radius_all(6)
	_sb.content_margin_left = 16
	_sb.content_margin_right = 14
	_sb.content_margin_top = 10
	_sb.content_margin_bottom = 10
	_sb.shadow_color = Color(0, 0, 0, 0.55)
	_sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", _sb)
	panel.visible = false  # hasta el primer paso con texto (la tarjeta del recuerdo va sin panel)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.name = "VB"
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	_vb = vb
	var head := HBoxContainer.new()
	head.name = "Cabecera"
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	_chip = PanelContainer.new()
	_chip.name = "Pastilla"
	var csb := StyleBoxFlat.new()
	csb.bg_color = ACCENT
	csb.set_corner_radius_all(3)
	csb.content_margin_left = 8
	csb.content_margin_right = 8
	csb.content_margin_top = 1
	csb.content_margin_bottom = 2
	_chip.add_theme_stylebox_override("panel", csb)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_chip)
	var cl := UITheme.label("TRAINING", 15, Color(0.02, 0.06, 0.08), true)
	cl.name = "Texto"
	cl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chip.add_child(cl)
	# Las etiquetas con corte de línea van con clip_text: su alto mínimo es 1 y el alto lo pone la guía (_apply). Sin
	# eso, un Label con autowrap pide el alto que tendría con el ancho del cuadro ANTERIOR (al nacer, casi cero: decenas
	# de líneas) y el PanelContainer no puede medir menos que eso: el panel salía altísimo en el primer paso.
	title = UITheme.label("", TITLE_PX, ACCENT, true)
	title.name = "Titulo"
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_bar = ProgressBar.new()
	_bar.name = "Avance"
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, 4)
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0.1, 0.16, 0.19)
	var bfg := StyleBoxFlat.new()
	bfg.bg_color = ACCENT
	_bar.add_theme_stylebox_override("background", bbg)
	_bar.add_theme_stylebox_override("fill", bfg)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_bar)
	scroll = ScrollContainer.new()
	scroll.name = "Cuerpo"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	vb.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Contenido"
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(_content)
	body = UITheme.label("", _body_px, Color(0.96, 0.98, 0.99))
	body.name = "Texto"
	body.clip_text = true
	_content.add_child(body)
	opts_box = BoxContainer.new()
	opts_box.name = "MiniCheck"
	opts_box.vertical = true
	opts_box.add_theme_constant_override("separation", 6)
	opts_box.visible = false
	_content.add_child(opts_box)
	result = UITheme.label("", RESULT_PX, Color(0.8, 0.95, 0.85))
	result.name = "Resultado"
	result.clip_text = true
	result.visible = false
	_content.add_child(result)
	hint = UITheme.label("", 19, GOLD)
	hint.name = "Pista"
	hint.clip_text = true
	hint.visible = false
	_content.add_child(hint)
	target_lbl = UITheme.label("", TARGET_PX, ACCENT, true)
	target_lbl.name = "Objetivo"
	target_lbl.clip_text = true
	target_lbl.visible = false
	_content.add_child(target_lbl)
	_note = UITheme.label("", 16, UITheme.TEXT)
	_note.name = "Aviso"
	_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.visible = false
	vb.add_child(_note)
	_foot = HBoxContainer.new()
	_foot.name = "Pie"
	_foot.add_theme_constant_override("separation", 8)
	vb.add_child(_foot)
	for i in 3:
		var a := _main_button("R%d" % (i + 1))
		a.text = "[%d]" % (i + 1)
		a.add_theme_font_size_override("font_size", 17)
		for k: String in ["normal", "hover", "pressed"]:  # cortos: tres caben junto a «Saltar módulo» en el panel más angosto
			var asb := a.get_theme_stylebox(k).duplicate() as StyleBoxFlat
			asb.content_margin_left = 9
			asb.content_margin_right = 9
			a.add_theme_stylebox_override(k, asb)
		a.visible = false
		a.pressed.connect(_on_answer.bind(i))
		_foot.add_child(a)
		btn_ans.append(a)
	btn_next = _main_button("Continuar")
	_foot.add_child(btn_next)
	btn_yes = _main_button("Si")
	_foot.add_child(btn_yes)
	btn_no = _main_button("No")
	_foot.add_child(btn_no)
	keys = UITheme.label("", KEYS_PX, UITheme.DIM, true)
	keys.name = "Teclas"
	keys.clip_text = true
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot.add_child(keys)
	_foot_gap = Control.new()
	_foot_gap.name = "Aire"
	_foot_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_gap.visible = false
	_foot.add_child(_foot_gap)
	btn_skip = Button.new()
	btn_skip.name = "Saltar"
	btn_skip.focus_mode = Control.FOCUS_NONE
	btn_skip.add_theme_font_size_override("font_size", 15)
	btn_skip.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.07, 0.1, 0.12)
	ssb.border_color = Color(0.3, 0.38, 0.44)
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(3)
	ssb.set_content_margin_all(6)
	btn_skip.add_theme_stylebox_override("normal", ssb)
	var ssh := ssb.duplicate() as StyleBoxFlat
	ssh.bg_color = Color(0.12, 0.17, 0.2)
	btn_skip.add_theme_stylebox_override("hover", ssh)
	btn_skip.add_theme_stylebox_override("pressed", ssh)
	btn_skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot.add_child(btn_skip)


## Botón principal del pie («Continuar [T]», «Sí [T]», «No [N]»): grande y del color de la guía.
func _main_button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.36, 0.42)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.08, 0.5, 0.58)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


# --- contenido -----------------------------------------------------------------------------------------

## Las opciones del mini-check; `cb` recibe el índice. Cada opción es un botón grande dentro del área con scroll y,
## además, en el pie fijo hay un botón corto por opción ([1] [2] [3]): siempre a la vista, quepa o no el texto.
func set_options(texts: Array, cb: Callable) -> void:
	_opt_cb = cb
	_answered = false
	for c in opts_box.get_children():
		opts_box.remove_child(c)
		c.queue_free()
	# Cada opción es un botón SIN texto con una etiqueta dentro («Texto»): el alto lo pone la guía con la medida del
	# texto (un Button con autowrap tiene el mismo vicio del alto mínimo que un Label).
	for i in texts.size():
		var b := Button.new()
		b.name = "Opcion%d" % (i + 1)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_contents = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.14, 0.18)
		sb.border_color = Color(0.36, 0.55, 0.64)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(0)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("disabled", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.13, 0.22, 0.28)
		sh.border_color = ACCENT
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(cb.bind(i))
		var l := UITheme.label("[%d]  %s" % [i + 1, str(texts[i])], OPT_PX, Color(0.95, 0.97, 0.98))
		l.name = "Texto"
		l.clip_text = true
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = OPT_PAD.x
		l.offset_right = -OPT_PAD.x
		l.offset_top = OPT_PAD.y
		l.offset_bottom = -OPT_PAD.y
		b.add_child(l)
		opts_box.add_child(b)
	opts_box.visible = not texts.is_empty()
	_sig = ""


func option_button(i: int) -> Button:
	return opts_box.get_child(i) as Button if i >= 0 and i < opts_box.get_child_count() else null


func _option_label(i: int) -> Label:
	var b := option_button(i)
	return b.get_node_or_null("Texto") as Label if b != null else null


## Texto de la opción `i` tal como se ve («[2]  …»).
func option_text(i: int) -> String:
	var l := _option_label(i)
	return l.text if l != null else ""


## Cambia el texto de una opción ya puesta (cambio de idioma con el mini-check abierto).
func set_option_text(i: int, text: String) -> void:
	var l := _option_label(i)
	if l != null:
		l.text = "[%d]  %s" % [i + 1, text]


func _on_answer(i: int) -> void:
	if _opt_cb.is_valid() and not _answered and opts_box.visible:
		_opt_cb.call(i)


## Tras contestar: la correcta en verde, la elegida (si falló) en rojo; ya no se pueden pulsar.
func mark_options(correct: int, chosen: int) -> void:
	_answered = true
	for i in opts_box.get_child_count():
		var b := opts_box.get_child(i) as Button
		b.disabled = true
		if i == correct:
			b.modulate = Color(0.6, 1.0, 0.65)
		elif i == chosen:
			b.modulate = Color(1.0, 0.6, 0.55)


## Aviso de paso nuevo: destello + anillo + sonido corto. No toca las voces ni los subtítulos.
func cue() -> void:
	_cue_t = CUE_S
	if sound:
		AudioManager.play_sfx("tut_paso", "UI")


## Entre dos pasos (el Trainer habla, algo pasa en el aula): el texto del paso ya hecho se apaga; el siguiente
## vuelve a encenderse con su aviso.
func set_idle(on: bool) -> void:
	idle = on
	if panel != null:
		panel.modulate = Color(1, 1, 1, 0.55) if on else Color(1, 1, 1, 1)


# --- el aviso de texto del HUD, dentro de la guía ---------------------------------------------------------

## HUD._on_notice pregunta aquí: con el panel a la vista, el aviso lo muestra la guía (su franja es la del aviso).
func host_notice(_speaker: String, _text: String, _seconds: float, _must: bool) -> bool:
	return panel != null and panel.is_visible_in_tree()


func _on_notice_shown(speaker: String, text: String, seconds: float, must: bool) -> void:
	if _note == null:
		return
	if text == "" or (not must and not bool(Loc.get_setting("subtitles", true))):
		_note.text = ""
		_note_left = 0.0
		return
	_note.text = "» " + text.replace("\n", "  ")
	_note.tooltip_text = text
	_note.add_theme_color_override("font_color", UITheme.EZLAK.lightened(0.35) if speaker == "ezlak" else (GOLD if must else Color(0.8, 0.84, 0.88)))
	_note_left = seconds + 0.6


func notice_text() -> String:
	return _note.text if _note != null else ""


# --- medir y acomodar ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if panel == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_t += real
	if _note_left > 0.0:
		_note_left -= real
		if _note_left <= 0.0:
			_note.text = ""
	if _cue_t > 0.0:
		_cue_t = maxf(_cue_t - real, 0.0)
	layout(real)
	_pointer.queue_redraw()


func _ws() -> Control:
	return get_tree().get_first_node_in_group("workstation") as Control


func zoomed() -> bool:
	var ws := _ws()
	return ws != null and ws.visible and bool(ws.get("zoomed")) and bool(GameState.flags.get("pc_zoom", false))


## Alto de `text` en un Label de `px` puntos con `width` de ancho (la misma regla de corte que el Label de verdad).
func _text_h(text: String, px: int, width: float, mono: bool = false) -> float:
	if text == "":
		return 0.0
	_ruler.add_theme_font_size_override("font_size", px)
	if mono:
		_ruler.add_theme_font_override("font", UITheme.mono())
	else:
		_ruler.remove_theme_font_override("font")
	_ruler.text = text
	_ruler.size = Vector2(maxf(width, 40.0), 1.0)
	return _ruler.get_minimum_size().y


## Columna del HUD de arriba a la derecha (reloj, AUX, métricas, disciplina, hold): lo que ocupa de verdad.
func hud_column() -> Rect2:
	var main := get_tree().root.get_node_or_null("Main")
	var hud: Node = main.get("hud") if main != null else null
	var out := Rect2()
	if hud == null:
		return out
	var any := false
	for k: String in ["_clock", "_aux", "_metrics", "_disc", "_hold"]:
		var l := hud.get(k) as Label
		if l == null or not l.is_visible_in_tree() or l.text == "":
			continue
		var g := l.get_global_transform() * Rect2(Vector2.ZERO, l.size)
		var w := minf(l.get_minimum_size().x, g.size.x)
		var r := Rect2(g.end.x - w, g.position.y, w, g.size.y)
		out = out.merge(r) if any else r
		any = true
	return out


## Lo que la guía no puede tapar ahora: lo que señala el paso y los menús abiertos.
func avoid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not target.is_empty() and bool(target.get("dentro", false)) and str(target.get("zona", "")) != "pc":
		out.append(target["rect"] as Rect2)  # lo de la PC acercada queda siempre debajo de la franja: no cuenta
	out.append_array(TrainingTargets.obstacles(get_tree()))
	return out


func _sizes(v: Vector2, pc: bool) -> void:
	var small := v.x < 1400.0
	var px := (20 if small else 22) if pc else (22 if small else 24)
	if px != _body_px:
		_body_px = px
		body.add_theme_font_size_override("font_size", px)
	_hint_px = 17 if small else 19
	hint.add_theme_font_size_override("font_size", _hint_px)


## Alto que pide el contenido con `w` px de panel (medidas de cada pieza). Se guarda por ancho mientras el
## contenido no cambie.
func _measure(w: float, pc: bool) -> Dictionary:
	var key := "%d|%d|%d" % [int(round(w)), int(pc), _body_px]
	if _m_cache.has(key):
		return (_m_cache[key] as Dictionary).duplicate()
	var m := _measure_now(w, pc)
	_m_cache[key] = m
	return m.duplicate()


func _hkey(text: String, px: int, width: float, mono: bool) -> String:
	return "%d|%d|%d|%s" % [px, int(mono), int(round(width)), text]


## Alto (entero) de `text`: el que dijo la etiqueta de verdad si ya se puso con ese ancho (_true_up); si no, la regla.
func _h(text: String, px: int, width: float, mono: bool = false) -> float:
	if text == "":
		return 0.0
	var key := _hkey(text, px, width, mono)
	if _exact.has(key):
		return float(_exact[key])
	return ceilf(_text_h(text, px, width, mono))


func _measure_now(w: float, pc: bool) -> Dictionary:
	var inner := w - _sb.content_margin_left - _sb.content_margin_right
	var cw := inner - 14.0  # sitio fijo para la barra de scroll: el ancho del texto no cambia si aparece
	var n_opts := opts_box.get_child_count() if opts_box.visible else 0
	var row := pc and cw >= 900.0 and n_opts == 3  # opciones en fila: la franja queda baja
	var chip := _chip.get_combined_minimum_size()
	var title_w := maxf(inner - chip.x - 10.0, 40.0)
	var title_own := _h(title.text, TITLE_PX, title_w, true)
	var title_h := maxf(title_own, ceilf(chip.y))
	var body_h := _h(body.text, _body_px, cw)
	var parts: Array[float] = []
	if body.text != "":
		parts.append(body_h)
	var opt_w := 0.0
	var opt_own: Array[float] = []
	var opt_hs: Array[float] = []
	if n_opts > 0:
		opt_w = floorf((cw - 6.0 * (n_opts - 1)) / n_opts) if row else cw
		var tallest := 0.0
		var total := 0.0
		for i in n_opts:
			var own := _h(option_text(i), OPT_PX, opt_w - 2.0 * OPT_PAD.x)
			var h := own + 2.0 * OPT_PAD.y
			opt_own.append(own)
			opt_hs.append(h)
			tallest = maxf(tallest, h)
			total += h
		if row:
			for i in n_opts:
				opt_hs[i] = tallest
		parts.append(tallest if row else total + 6.0 * (n_opts - 1))
	var result_own := _h(result.text, RESULT_PX, cw)
	var result_h := maxf(result_own, _h(result_reserve, RESULT_PX, cw))
	if result_h > 0.0:
		parts.append(result_h)
	var hint_h := _h(hint.text, _hint_px, cw)
	if hint.text != "":
		parts.append(hint_h)
	var target_h := _h(target_lbl.text, TARGET_PX, cw, true)
	if target_lbl.text != "":
		parts.append(target_h)
	var content := 0.0
	for p in parts:
		content += p
	content += 8.0 * maxf(parts.size() - 1, 0)
	var rest := inner  # lo que les queda a las teclas en el pie, al lado de los botones
	var foot_h := 0.0
	for b: Button in _foot_buttons():
		if b.visible:
			var bm := b.get_combined_minimum_size()
			rest -= ceilf(bm.x) + 8.0
			foot_h = maxf(foot_h, ceilf(bm.y))
	# Panel angosto (ventana chica, columna del HUD ancha): las teclas no caben al lado de los botones y van en su
	# propio renglón, encima del pie.
	var stack := keys.text != "" and rest < KEYS_MIN_W
	var keys_w := inner if stack else maxf(rest, 40.0)
	var keys_own := _h(keys.text, KEYS_PX, keys_w, true)
	if not stack:
		foot_h = maxf(foot_h, keys_own)
	var note_h := (ceilf(_text_h("Ay", 16, 400.0)) + 6.0) if _note.text != "" else 0.0
	var chrome := _sb.content_margin_top + _sb.content_margin_bottom + title_h + 6.0 + 4.0 + 6.0 + note_h + ((keys_own + 6.0) if stack else 0.0) + 6.0 + foot_h
	return {"cw": cw, "row": row, "title_w": title_w, "title_own": title_own, "title_h": title_h, "body_h": body_h,
		"opt_w": opt_w, "opt_own": opt_own, "opt_hs": opt_hs, "result_own": result_own, "result_h": result_h,
		"hint_h": hint_h, "target_h": target_h, "keys_w": keys_w, "keys_own": keys_own, "stack": stack,
		"content": content, "chrome": chrome, "total": chrome + content}


func _content_signature() -> String:
	var o := ""
	for i in opts_box.get_child_count():
		o += option_text(i) + "|"
	var f := ""
	for b in _foot_buttons():
		f += (b.text if b.visible else "") + "|"
	return "%s·%s·%s·%s·%s·%s·%s·%s·%d·%s" % [title.text, body.text, result.text + "¦" + result_reserve, hint.text, target_lbl.text, keys.text, o, _note.text, int(opts_box.visible), f]


## Acomoda el panel (cada cuadro; solo toca algo si cambió). `real` = segundos reales desde el cuadro anterior.
func layout(real: float = 0.0) -> void:
	var ws := _ws()
	if not panel.visible:
		if ws != null and float(ws.get("reserve_top")) != 0.0:
			ws.set("reserve_top", 0.0)
		target = {}
		return
	var v := get_viewport_rect().size
	var pc := zoomed()
	hint.visible = hint.text != ""
	target_lbl.visible = target_lbl.text != ""
	_note.visible = _note.text != ""
	_bar.value = clampf(progress, 0.0, 1.0)
	var n_ans := opts_box.get_child_count() if opts_box.visible and not _answered else 0
	for i in btn_ans.size():
		btn_ans[i].visible = i < n_ans
	_sizes(v, pc)
	var csig := _content_signature()
	if csig != _csig:
		_csig = csig
		_m_cache.clear()
		if _exact.size() > 300:
			_exact.clear()
	target = TrainingTargets.resolve(get_tree(), target_ids, tut) if not target_ids.is_empty() else {}
	var hud := hud_column()
	var avoid := avoid_rects()
	var want := _place(v, pc, hud, avoid, real)
	var r: Rect2 = want["rect"]
	var m: Dictionary = want["medidas"]
	var sig := "%s·%s·%s·%d·%s·%s" % [csig, str(v), str(pc), _body_px, str(r), str(want["lado"])]
	if sig != _sig:
		_sig = sig
		side = str(want["lado"])
		_apply(r, m)
	elif _true_up():
		# Una etiqueta de verdad cortó las líneas distinto que la regla: su alto queda anotado y el cuadro siguiente
		# se acomoda con él (como mucho una vez por texto y ancho).
		true_ups += 1
		_m_cache.clear()
		_sig = ""
	if ws != null:
		var res := (panel.position.y + panel.size.y + GAP) if pc else 0.0
		if not is_equal_approx(float(ws.get("reserve_top")), res):
			ws.set("reserve_top", res)
	_pulse()


## Pone el panel en `r` con las medidas `m`: cada etiqueta recibe SU alto (ninguna lo decide sola).
func _apply(r: Rect2, m: Dictionary) -> void:
	var cw := float(m["cw"])
	_used.clear()
	_content.custom_minimum_size = Vector2(cw, 0)
	opts_box.vertical = not bool(m["row"])
	var hs: Array = m["opt_hs"]
	var owns: Array = m["opt_own"]
	var lw := float(m["opt_w"]) - 2.0 * OPT_PAD.x
	for i in opts_box.get_child_count():
		var b := opts_box.get_child(i) as Button
		b.custom_minimum_size = Vector2(0, float(hs[i]) if i < hs.size() else 0.0)
		var l := _option_label(i)
		if l != null and i < owns.size() and l.text != "":
			_used[l] = {"clave": _hkey(l.text, OPT_PX, lw, false), "ancho": lw, "alto": float(owns[i])}
	body.visible = body.text != ""
	_give(body, _body_px, cw, false, float(m["body_h"]), float(m["body_h"]))
	result.visible = float(m["result_h"]) > 0.0
	_give(result, RESULT_PX, cw, false, float(m["result_own"]), float(m["result_h"]))
	_give(hint, _hint_px, cw, false, float(m["hint_h"]), float(m["hint_h"]))
	_give(target_lbl, TARGET_PX, cw, true, float(m["target_h"]), float(m["target_h"]))
	_give(title, TITLE_PX, float(m["title_w"]), true, float(m["title_own"]), float(m["title_h"]))
	min_h = float(m.get("min_h", H_MIN))
	_stack_keys(bool(m["stack"]))
	_give(keys, KEYS_PX, float(m["keys_w"]), true, float(m["keys_own"]), float(m["keys_own"]))
	panel.position = r.position
	panel.size = r.size
	_rect = r


## Las teclas, en el pie (entre los botones y «Saltar módulo») o en su propio renglón encima del pie.
func _stack_keys(on: bool) -> void:
	if on == _stacked:
		return
	_stacked = on
	keys.get_parent().remove_child(keys)
	if on:
		_vb.add_child(keys)
		_vb.move_child(keys, _foot.get_index())
		keys.size_flags_vertical = Control.SIZE_FILL
	else:
		_foot.add_child(keys)
		_foot.move_child(keys, _foot_gap.get_index())
		keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot_gap.visible = on


## `own` = alto de su texto con `width`; `h` = el alto que se le da (puede ser más: sitio guardado, fila de la pastilla).
func _give(l: Label, px: int, width: float, mono: bool, own: float, h: float) -> void:
	l.custom_minimum_size = Vector2(0, h)
	if l.text != "":
		_used[l] = {"clave": _hkey(l.text, px, width, mono), "ancho": width, "alto": own}


## Comprueba, ya con las etiquetas en su ancho, que cada una tiene el alto de sus líneas. Devuelve true si alguna
## difería (queda anotado en _exact y hay que volver a acomodar).
func _true_up() -> bool:
	var changed := false
	for k in _used.keys():
		var l := k as Label
		if l == null or not is_instance_valid(l) or not l.is_visible_in_tree() or l.text == "":
			continue
		var u: Dictionary = _used[k]
		if absf(l.size.x - float(u["ancho"])) > 1.5:
			continue  # todavía no tiene el ancho con el que se midió (o el pie no cupo): no hay con qué comparar
		var n := l.get_line_count()
		var need := 0.0
		for i in n:
			need += l.get_line_height(i)
		need = ceilf(need + maxf(n - 1, 0) * l.get_theme_constant("line_spacing"))
		if absf(need - float(u["alto"])) > 0.5:
			_exact[str(u["clave"])] = need
			changed = true
	return changed


## Dónde va el panel: {rect, lado, medidas}.
func _place(v: Vector2, pc: bool, hud: Rect2, avoid: Array[Rect2], real: float) -> Dictionary:
	var bottom_max := v.y - SUB_ZONE
	if pc:
		var x0 := MARGIN
		var y0 := TOP_PC
		var x1 := (hud.position.x - GAP) if hud.size.x > 0.0 else v.x - MARGIN
		if x1 - x0 < 620.0:  # ventana estrecha: debajo de la columna del HUD, a todo el ancho
			x1 = v.x - MARGIN
			y0 = ceilf(hud.end.y + 6.0) if hud.size.x > 0.0 else TOP_PC
		var w := floorf(x1 - x0)
		var m := _measure(w, true)
		var band_min := float(m["chrome"]) + 2.0 * (_text_h("Ay", _body_px, 400.0) + 2.0)  # siempre sitio para dos líneas: la franja no baila
		# Tope: lo que deja a las dos pantallas su escala entera (solo pierden alto). Un mini-check puede pasar de ahí
		# (no hay nada que usar en la PC mientras contestas), hasta el 46 % de la vista.
		var zb := v.y * 0.88 - 30.0
		var s_w := (v.x * 0.88) / 1642.0
		var cap := zb - 506.0 * s_w - GAP - y0
		if opts_box.visible:
			cap = maxf(cap, v.y * 0.46)
		cap = maxf(cap, band_min)
		# Vista muy chica (el navegador en una ventana mínima): la franja nunca llega a las pantallas ni a los subtítulos;
		# lo que no quepa va con scroll (y el mini-check se contesta con los botones fijos del pie).
		var min_h := _min_height(m)
		cap = minf(cap, maxf(minf(zb - PC_MIN_H - GAP, bottom_max) - y0, min_h))
		for a in avoid:  # un menú abierto (AUX, WW) debajo de la franja: la franja termina antes
			if a.end.y > y0 and a.end.x > x0 and a.position.x < x1:
				cap = minf(cap, a.position.y - GAP - y0)
		cap = maxf(cap, min_h)  # nunca menos que la cabecera, un renglón y el pie (solo pasa en vistas mínimas)
		var h := floorf(clampf(maxf(float(m["total"]), band_min), min_h, cap))
		m["tope"] = cap
		m["min_h"] = min_h
		_bad_t = 0.0
		return {"rect": Rect2(x0, y0, w, h), "lado": "pc", "medidas": m}
	# De pie o sentado sin acercar: arriba a la izquierda; si ahí está lo que hay que usar, arriba a la derecha (debajo
	# de la columna del HUD). En vistas estrechas la columna del HUD llega hasta la mitad: el panel se angosta o baja.
	var w0 := floorf(minf(clampf(v.x * 0.40, 560.0, 780.0), v.x - 2.0 * MARGIN))
	var y_h := ceilf(hud.end.y + GAP) if hud.size.x > 0.0 else MARGIN
	var cands: Array[Dictionary] = []
	var lw := w0
	var ly := MARGIN
	if hud.size.x > 0.0 and MARGIN + w0 + GAP > hud.position.x:
		if hud.position.x - GAP - MARGIN >= 460.0:
			lw = floorf(hud.position.x - GAP - MARGIN)
		else:
			ly = y_h
	cands.append({"lado": "izq", "p": Vector2(MARGIN, ly), "w": lw})
	cands.append({"lado": "der", "p": Vector2(v.x - MARGIN - w0, y_h), "w": w0})
	if side == "der":
		cands.reverse()
	var best := {}
	var best_free := -1.0
	var current := {}
	for c in cands:
		var p: Vector2 = c["p"]
		var w: float = c["w"]
		var m := _measure(w, false)
		var min_h := _min_height(m)
		var cap2 := maxf(minf(bottom_max - p.y, v.y * 0.62), min_h)
		var free := cap2  # alto libre debajo de p sin tocar nada de lo que no se tapa
		for a in avoid:
			var g := a.grow(GAP)
			if g.end.x > p.x and g.position.x < p.x + w and g.end.y > p.y:
				free = minf(free, g.position.y - p.y)
		var need := floorf(minf(float(m["total"]), cap2))
		m["tope"] = cap2
		m["min_h"] = min_h
		var full := {"rect": Rect2(p, Vector2(w, need)), "lado": str(c["lado"]), "medidas": m}
		if str(c["lado"]) == side:
			current = full
		if free >= need:
			best = full
			best_free = INF
			break
		if free > best_free:
			best_free = free
			# Sin sitio para todo el texto: el alto que haya, con scroll (nunca menos que un panel mínimo).
			var mm := m.duplicate()
			var hh := floorf(maxf(free, min_h))
			mm["tope"] = hh
			best = {"rect": Rect2(p, Vector2(w, hh)), "lado": str(c["lado"]), "medidas": mm}
	# Histéresis: cambiar de lado solo si el actual lleva un rato sin servir (la cámara gira y el objetivo pasa por debajo).
	if str(best["lado"]) != side and not current.is_empty() and _sig != "":
		_bad_t += real
		if _bad_t < 0.25:
			return current
	_bad_t = 0.0
	return best


## Lo menos que puede medir el panel con estas medidas: cabecera, pie y un renglón de texto a la vista (o todo, si
## es más corto que eso).
func _min_height(m: Dictionary) -> float:
	return floorf(minf(float(m["total"]), maxf(H_MIN, float(m["chrome"]) + 34.0)))


func _pulse() -> void:
	var f := _cue_t / CUE_S
	var beat := 0.5 + 0.5 * sin(_t * 4.2) if waiting else 0.0
	var col := ACCENT.lerp(GOLD, 0.55 * beat).lerp(Color(1, 1, 1), f)
	if not _sb.border_color.is_equal_approx(col):
		_sb.border_color = col
	_sb.bg_color = BG.lerp(Color(0.1, 0.3, 0.34, 0.97), f * 0.8)


func panel_rect() -> Rect2:
	return panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size) if panel != null else Rect2()


## Botones y controles del panel que el jugador puede necesitar ahora (pruebas: todos dentro de la vista y del panel).
func live_buttons() -> Array[Control]:
	var out: Array[Control] = []
	for b in _foot_buttons():
		if b.is_visible_in_tree():
			out.append(b)
	return out


func _foot_buttons() -> Array[Button]:
	var out: Array[Button] = []
	out.append_array(btn_ans)
	out.append_array([btn_next, btn_yes, btn_no, btn_skip])
	return out


## Etiquetas del panel a las que les falta alto para sus líneas (pruebas: ninguna; el texto que no cabe va con scroll,
## nunca cortado).
func clipped_labels() -> Array[String]:
	var out: Array[String] = []
	var ls: Array[Label] = [title, body, result, hint, target_lbl, keys]
	for i in opts_box.get_child_count():
		var l := _option_label(i)
		if l != null:
			ls.append(l)
	for l in ls:
		if l.is_visible_in_tree() and l.text != "" and l.get_visible_line_count() < l.get_line_count():
			out.append("%s (%d de %d líneas)" % [l.name if l.get_parent() == null or not (l.get_parent() is Button) else str(l.get_parent().name), l.get_visible_line_count(), l.get_line_count()])
	return out


## Opciones del mini-check que no se ven enteras sin mover el scroll (para eso están los botones del pie).
func hidden_options() -> int:
	var n := 0
	if not opts_box.is_visible_in_tree():
		return 0
	var sc := scroll.get_global_transform() * Rect2(Vector2.ZERO, scroll.size)
	for i in opts_box.get_child_count():
		var b := option_button(i)
		if not sc.grow(0.5).encloses(b.get_global_transform() * Rect2(Vector2.ZERO, b.size)):
			n += 1
	return n


## ¿El texto necesita scroll? (pruebas: a 1920×1080 ningún paso debería)
func scrolls() -> bool:
	return scroll != null and _content.size.y > scroll.size.y + 1.0


# --- lo que señala -----------------------------------------------------------------------------------------

class Pointer extends Control:
	var coach: TrainingCoach = null

	func _draw() -> void:
		if coach == null or coach.panel == null or not coach.panel.visible:
			return
		var t := coach._t
		var f := coach._cue_t / TrainingCoach.CUE_S
		if f > 0.0:
			# Anillo que se cierra sobre el panel: la vista va sola hacia el paso nuevo.
			var pr := coach.panel_rect().grow(6.0 + 70.0 * f * f)
			draw_rect(pr, Color(TrainingCoach.ACCENT, 0.85 * (1.0 - f) + 0.15), false, 3.0 + 5.0 * f)
		var tg := coach.target
		if tg.is_empty():
			return
		var beat := 0.5 + 0.5 * sin(t * 5.0)
		var col := TrainingCoach.GOLD.lerp(Color(1, 1, 1), 0.35 * beat)
		var dark := Color(0, 0, 0, 0.7)
		var r: Rect2 = tg["rect"]
		var poly: PackedVector2Array = tg.get("poly", PackedVector2Array())
		var zona := str(tg.get("zona", ""))
		if zona == "mundo":
			_world_arrow(tg, col, dark, beat)
			return
		if not bool(tg.get("dentro", false)):
			return
		if poly.size() == 4:
			var loop := PackedVector2Array(poly)
			loop.append(poly[0])
			draw_polyline(loop, dark, 7.0, true)
			draw_polyline(loop, col, 3.0, true)
		else:
			var g := r.grow(5.0 + 3.0 * beat)
			draw_rect(g, dark, false, 7.0)
			draw_rect(g, col, false, 3.0)
		_arrow_to(r, col, dark, beat)

	## Flecha que rebota junto al rect: desde arriba si hay sitio y no cae sobre el panel; si no, desde un lado o abajo.
	func _arrow_to(r: Rect2, col: Color, dark: Color, beat: float) -> void:
		var v := get_viewport_rect().size
		var pr := coach.panel_rect().grow(4.0)
		var d := 16.0 + 12.0 * beat
		var size := 30.0
		var opts := [
			[Vector2(r.get_center().x, r.position.y - d), Vector2(0, 1)],
			[Vector2(r.position.x - d, r.get_center().y), Vector2(1, 0)],
			[Vector2(r.end.x + d, r.get_center().y), Vector2(-1, 0)],
			[Vector2(r.get_center().x, r.end.y + d), Vector2(0, -1)],
		]
		for o: Array in opts:
			var tip: Vector2 = o[0]
			var dir: Vector2 = o[1]
			var base := tip - dir * (size + 26.0)
			var box := Rect2(tip, Vector2.ZERO).expand(base).grow(size * 0.6)
			if box.position.x < 0.0 or box.position.y < 0.0 or box.end.x > v.x or box.end.y > v.y or box.intersects(pr):
				continue
			_arrow(tip, dir, size, col, dark)
			return

	func _arrow(tip: Vector2, dir: Vector2, size: float, col: Color, dark: Color) -> void:
		var n := Vector2(-dir.y, dir.x)
		var back := tip - dir * size
		var tri := PackedVector2Array([tip, back + n * size * 0.62, back - n * size * 0.62])
		var stem0 := back + n * size * 0.24
		var stem1 := back - n * size * 0.24
		var tail := back - dir * 26.0
		var stem := PackedVector2Array([stem0, stem1, tail - n * size * 0.24, tail + n * size * 0.24])
		var outline := PackedVector2Array([tip, back + n * size * 0.62, stem0, tail + n * size * 0.24, tail - n * size * 0.24, stem1, back - n * size * 0.62, tip])
		draw_colored_polygon(stem, col)
		draw_colored_polygon(tri, col)
		draw_polyline(outline, dark, 3.0, true)

	## Objetivo del mundo: flecha sobre la luz guía; si queda fuera de la vista, en el borde hacia donde hay que girar.
	func _world_arrow(tg: Dictionary, col: Color, dark: Color, beat: float) -> void:
		var v := get_viewport_rect().size
		var p: Vector2 = tg["punto"]
		var r: Rect2 = tg["rect"]
		var inside := bool(tg.get("dentro", false)) and not bool(tg.get("detras", false))
		var pr := coach.panel_rect().grow(8.0)
		if inside:
			var tip := Vector2(p.x, maxf(r.position.y - 10.0 - 12.0 * beat, 70.0))
			if not pr.has_point(tip) and not pr.has_point(tip - Vector2(0, 56)):
				_arrow(tip, Vector2(0, 1), 30.0, col, dark)
			return
		var c := v * 0.5
		var dir := (p - c).normalized() if p.distance_to(c) > 1.0 else Vector2(1, 0)
		if bool(tg.get("detras", false)):
			dir = Vector2(-1, 0) if p.x < c.x else Vector2(1, 0)
		var m := 70.0
		var k := minf((c.x - m) / maxf(absf(dir.x), 0.001), (c.y - m) / maxf(absf(dir.y), 0.001))
		var tip2 := c + dir * (k + 10.0 * beat)
		if pr.has_point(tip2) or pr.has_point(tip2 - dir * 56.0):
			tip2 = Vector2(clampf(tip2.x, m, v.x - m), maxf(tip2.y, pr.end.y + 70.0))
		_arrow(tip2, dir, 30.0, col, dark)

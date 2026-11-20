class_name EventoUI
extends CanvasLayer
## Mini evento de Rasec (PLAN §2 #78): cartel "¡FELIZ {TEMA}!", la letra del karaoke, la mímica de las
## charadas y las sillas con nombre. Dos interacciones (corrutinas, las usa RasecControl):
##   press(texto, segundos) -> bool       — pulsar [E]/Espacio/clic a tiempo (cantar)
##   choose(opciones, segundos, correcta) -> int  — elegir con clic o 1-5 (-1 si se acaba el tiempo)
##   decide(pregunta, opciones, segundos, correcta) -> int — v0.3.1 Q4 (F22): una decisión de diálogo con Rasec
##     (seguirle el juego / excusa / burla), opciones en columna con 1-3 o clic; -1 si te quedas callado.
## `forced` ("ok" / "fail") responde solo (pruebas y bot). Todo con callables de método (nada de lambdas
## que sobrevivan al nodo). `set_notes(n)` muestra «Rasec anotó: n».

signal _done(v: Variant)

var forced: String = ""
var kind: String = ""
var answers: Array = []  # lo que se respondió (pruebas)
var _root: Control = null
var _stage: Control = null
const BANNER_Y := 60.0
var _banner: Label = null
var _text: Label = null
var _prompt: Label = null
var _sung: Label = null  # v0.3.2: lo ya cantado del verso, en color, encima de la letra (karaoke)
var _lyric_marks: Array = []  # [[inicio_s, fin_s, letras_cantadas], …] (KaraokeVoz)
var _lyric_line: Object = null  # la línea del VoiceDirector que canta el verso (su reloj pinta la letra)
var _buttons: HBoxContainer = null
var _column: VBoxContainer = null
var _notes: Label = null
var _question: Label = null
var _ticket: int = 0
var _mode: String = ""
var _correct: int = 0
var _t: float = 0.0
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 0  # v0.3.1 Q1 (F6): debajo de la UI principal (capa 1): la pausa y la muerte siempre encima
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.35, 0.05, 0.25, 0.13)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.name = "Tinte"
	_root.add_child(tint)
	# v0.3.2-core: todo lo demás va en un «escenario» de 1920 de ancho centrado en la pantalla. Estaba colocado en
	# coordenadas fijas desde la izquierda: en una pantalla más ancha que 16:9 (ultrapanorámica) el cartel, la letra y
	# los botones quedaban corridos a la izquierda.
	_stage = Control.new()
	_stage.name = "Escenario"
	_stage.anchor_left = 0.5
	_stage.anchor_right = 0.5
	_stage.anchor_top = 0.0
	_stage.anchor_bottom = 1.0
	_stage.offset_left = -960.0
	_stage.offset_right = 960.0
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	_banner = UITheme.label("", 40, Color(1.0, 0.75, 0.3), true)
	_banner.position = Vector2(0, 60)
	_banner.size = Vector2(1920, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v0.3.2-core: contorno oscuro (sobre un fluorescente de la sala el amarillo no se leía)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_stage.add_child(_banner)
	_text = UITheme.label("", 34, Color(1, 0.96, 0.92))
	_text.position = Vector2(160, 640)
	_text.size = Vector2(1600, 120)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_text)
	# v0.3.2 (karaoke cantado): la misma letra, encima, en amarillo; se va destapando sílaba a sílaba con la voz. Mismo
	# texto, mismo sitio y los glifos ya colocados (VC_CHARS_AFTER_SHAPING): las letras pintadas caen justo encima.
	_sung = UITheme.label("", 34, Color(1.0, 0.8, 0.22))
	_sung.name = "LetraCantada"
	_sung.position = _text.position
	_sung.size = _text.size
	_sung.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sung.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_sung.visible_characters = 0
	_stage.add_child(_sung)
	_prompt = UITheme.label("", 26, Color(0.95, 0.85, 0.4), true)
	_prompt.position = Vector2(160, 780)
	_prompt.size = Vector2(1600, 50)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_prompt)
	_buttons = HBoxContainer.new()
	_buttons.position = Vector2(260, 850)
	_buttons.size = Vector2(1400, 70)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 18)
	_stage.add_child(_buttons)
	# v0.3.1 Q4 (F22): decisiones de diálogo en columna y el contador de anotaciones de Rasec.
	_question = UITheme.label("", 28, Color(1.0, 0.86, 0.6))
	_question.position = Vector2(260, 560)
	_question.size = Vector2(1400, 90)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_question)
	_column = VBoxContainer.new()
	_column.position = Vector2(460, 680)
	_column.size = Vector2(1000, 260)
	_column.add_theme_constant_override("separation", 10)
	_stage.add_child(_column)
	_notes = UITheme.label("", 20, Color(0.95, 0.55, 0.5), true)
	_notes.position = Vector2(1460, 140)
	_notes.size = Vector2(420, 40)
	_notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_notes)
	EventBus.death_sequence_started.connect(_on_death)


## v0.3.2-core: el cartel sin el artículo del tema y en plural cuando toca. Los temas se escriben para ir dentro de una
## frase («Hoy celebramos el aniversario de la campaña KipuPay»); en el cartel salía «¡FELIZ EL ANIVERSARIO DE LA…!»,
## «¡FELIZ EL DÍA DE LA MADRE!», «¡FELIZ FIESTAS PATRIAS!» y, en inglés, «HAPPY THE KIPUPAY CAMPAIGN ANNIVERSARY!».
static func banner_text(theme_name: String, lang: String, pattern: String) -> String:
	var t := theme_name.strip_edges()
	for art: String in ["el ", "la ", "los ", "las ", "the "]:
		if t.to_lower().begins_with(art):
			t = t.substr(art.length())
			break
	var first := t.get_slice(" ", 0).to_lower()
	if lang == "es" and first.length() > 3 and first.ends_with("s"):
		return "¡FELICES %s!" % t.to_upper()
	return pattern.replace("{tema}", t.to_upper())


func _on_death(_c: String, _k: String, _d: String) -> void:
	_root.visible = false
	_mode = ""  # la corrutina de RasecControl queda suspendida y se descarta (su token ya cambió)


func open(p_kind: String, theme_name: String) -> void:
	kind = p_kind
	_banner.text = banner_text(theme_name, Loc.language, tr("P5_EVENT_BANNER"))
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_text(t: String) -> void:
	_text.text = t
	_sung.text = ""
	_lyric_marks = []
	_lyric_line = null


## v0.3.2: un verso del karaoke. La letra entera en claro y, encima, lo ya cantado en color: `marks` son las marcas
## de tiempo de cada sílaba de la voz (KaraokeVoz.verse(i).marcas). Hasta sing() no se pinta nada.
func show_lyric(t: String, marks: Array) -> void:
	_text.text = t
	_sung.text = t
	_sung.visible_characters = 0
	_lyric_marks = marks
	_lyric_line = null


## La voz del verso (VoiceDirector.Line): desde que arranca, su reloj pinta la letra.
func sing(line: Object) -> void:
	_lyric_line = line


## Texto que se ve (pruebas).
func shown_text() -> String:
	return _text.text


## Letras del verso ya pintadas (pruebas).
func sung_chars() -> int:
	if _sung.text == "":
		return 0
	return _sung.text.length() if _sung.visible_characters < 0 else _sung.visible_characters


func _paint_lyric() -> void:
	if _lyric_line == null or _lyric_marks.is_empty() or _sung.text == "":
		return
	var st := int(_lyric_line.get("started_ms"))
	if st < 0:
		return
	if bool(_lyric_line.get("done")):
		if str(_lyric_line.get("result")) == "dicha":
			_sung.visible_characters = -1  # el verso entero (también el «♪» del final)
		_lyric_line = null
		return
	var vd := get_node_or_null("/root/VoiceDirector")
	if vd != null:
		_sung.visible_characters = KaraokeVoz.chars_at(_lyric_marks, float(int(vd.call("now_ms")) - st) / 1000.0)


## Pulsar a tiempo (cantar el verso). true si llegaste.
func press(prompt: String, seconds: float) -> bool:
	_clear_buttons()
	_mode = "press"
	_ticket += 1
	_prompt.text = prompt
	get_tree().create_timer(seconds).timeout.connect(_on_timeout.bind(_ticket, false))
	if forced != "":
		get_tree().create_timer(0.35).timeout.connect(_on_forced.bind(_ticket))
	var v: Variant = await _done
	answers.append(v)
	_prompt.text = ""
	return bool(v)


## Elegir una opción (charadas, sillas). Devuelve el índice o -1 si se acabó el tiempo.
func choose(options: Array, seconds: float, correct: int) -> int:
	_clear_buttons()
	_mode = "choose"
	_correct = correct
	_ticket += 1
	_prompt.text = tr("P5_EVENT_CHOOSE")
	for i in options.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, str(options[i])]
		b.custom_minimum_size = Vector2(230, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_button.bind(i))
		_buttons.add_child(b)
	get_tree().create_timer(seconds).timeout.connect(_on_timeout.bind(_ticket, -1))
	if forced != "":
		get_tree().create_timer(0.5).timeout.connect(_on_forced.bind(_ticket))
	var v: Variant = await _done
	answers.append(v)
	_clear_buttons()
	_prompt.text = ""
	return int(v)


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	if _column != null:
		for c in _column.get_children():
			c.queue_free()


func set_notes(n: int) -> void:
	_notes.text = Loc.fmt(tr("Q4_EVENT_NOTES"), {"n": n}) if n > 0 else ""


## Decisión de diálogo con Rasec. Devuelve el índice elegido o -1 si se acabó el tiempo (silencio).
func decide(question: String, options: Array, seconds: float, correct: int) -> int:
	_clear_buttons()
	_mode = "choose"
	_correct = correct
	_ticket += 1
	_prompt.text = ""
	show_text("")  # (también quita la letra pintada del verso anterior)
	_question.text = question
	for i in options.size():
		var b := Button.new()
		b.name = "Decision%d" % (i + 1)
		b.text = "%d. %s" % [i + 1, str(options[i])]
		b.custom_minimum_size = Vector2(1000, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_button.bind(i))
		_column.add_child(b)
	get_tree().create_timer(seconds).timeout.connect(_on_timeout.bind(_ticket, -1))
	if forced != "":
		get_tree().create_timer(0.5).timeout.connect(_on_forced.bind(_ticket))
	var v: Variant = await _done
	answers.append(v)
	_clear_buttons()
	_question.text = ""
	return int(v)


func _on_button(i: int) -> void:
	if _mode == "choose":
		_resolve(i)


func _on_timeout(ticket: int, value: Variant) -> void:
	if ticket == _ticket:
		_resolve(value)


func _on_forced(ticket: int) -> void:
	if ticket != _ticket:
		return
	if _mode == "press":
		_resolve(forced != "fail")
	elif _mode == "choose":
		var n := maxi(_buttons.get_child_count() + _column.get_child_count(), 1)
		if forced in ["excusa", "burla"] and _column.get_child_count() > 0:
			_resolve(1 if forced == "excusa" else n - 1)  # pruebas de ramas de las decisiones (F22)
		elif forced in ["excusa", "burla"]:
			_resolve(_correct)  # en el juego (cantar, sillas) responden bien
		else:
			_resolve(_correct if forced == "ok" else (_correct + 1) % n)


func _resolve(v: Variant) -> void:
	if _mode == "":
		return
	_mode = ""
	_ticket += 1
	_done.emit(v)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "":
		return
	if _mode == "press" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_resolve(true)
		get_viewport().set_input_as_handled()
	elif _mode == "choose" and event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9 and int(k - KEY_1) < _buttons.get_child_count() + _column.get_child_count():
			_resolve(int(k - KEY_1))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_paint_lyric()
	# Alegría forzada: el cartel late un poco demasiado rápido.
	_banner.modulate = Color(1, 1, 1, 0.75 + 0.25 * absf(sin(_t * 5.3)))
	# v0.3.2-core: el cartel baja si el aviso de texto del HUD (hasta 3 renglones, arriba al centro) le caería encima.
	var top := BANNER_Y
	if _root.visible:
		for bx in get_tree().get_nodes_in_group("hud_top_box"):
			var c := bx as Control
			if c != null and c.is_visible_in_tree():
				top = maxf(top, c.get_global_rect().end.y + 6.0)
	if not is_equal_approx(_banner.position.y, top):
		_banner.position.y = top
	if _mode == "press":
		_prompt.modulate.a = 0.5 + 0.5 * absf(sin(_t * 9.0))


func _exit_tree() -> void:
	Input.mouse_mode = _prev_mouse

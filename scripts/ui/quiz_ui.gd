class_name QuizUI
extends CanvasLayer
## Quiz del Trainer (PLAN §2 #37 y #82, DIALOGOS §5.1): 5 preguntas en la pizarra de la sala 2, 3
## opciones cada una (clic o teclas 1-3). El reloj del juego está PAUSADO mientras respondes (lo pausa
## TrainingControl con el override "quiz"). Fácil muestra una pista. Cada respuesta emite
## EventBus.quiz_answered(i, correcta) y `answered`; al final, `finished(puntaje, total, aprobado)`.
## API para pruebas y bot: answer(opción) · forced (respuestas automáticas: -1 correcta, -2 incorrecta).

signal answered(i: int, correct: bool)
signal finished(score: int, total: int, passed: bool)

var questions: Array = []
var need: int = 3
var hint: bool = false
var index: int = 0
var score: int = 0
var results: Array[bool] = []
var closed: bool = false
var _forced: Array = []
var _busy: bool = false
var _root: Control = null
var _board: PanelContainer = null
var _title: Label = null
var _count: Label = null
var _q: Label = null
var _hint: Label = null
var _buttons: Array[Button] = []
var _status: Label = null
var _paused: Label = null
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _t: float = 0.0


func _ready() -> void:
	layer = 0  # v0.3.1 Q1 (F6): debajo de la UI principal (capa 1): la pausa y la muerte siempre encima
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_board = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.92, 0.9)
	sb.border_color = Color(0.55, 0.57, 0.58)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(26)
	_board.add_theme_stylebox_override("panel", sb)
	_board.custom_minimum_size = Vector2(1080, 600)
	_board.position = Vector2(420, 200)
	_root.add_child(_board)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_board.add_child(vb)
	var ink := Color(0.12, 0.16, 0.42)
	_title = UITheme.label(tr("P5_QUIZ_TITLE"), 30, ink, true)
	vb.add_child(_title)
	_count = UITheme.label("", 20, Color(0.3, 0.32, 0.4), true)
	vb.add_child(_count)
	_q = UITheme.label("", 28, Color(0.08, 0.08, 0.1))
	_q.custom_minimum_size = Vector2(1020, 90)
	vb.add_child(_q)
	_hint = UITheme.label("", 19, Color(0.1, 0.45, 0.2))
	vb.add_child(_hint)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(1020, 58)
		b.add_theme_font_size_override("font_size", 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.97, 0.97, 0.95)
		bs.border_color = Color(0.3, 0.35, 0.55)
		bs.set_border_width_all(2)
		bs.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", bs)
		var bh := bs.duplicate() as StyleBoxFlat
		bh.bg_color = Color(0.85, 0.88, 0.98)
		b.add_theme_stylebox_override("hover", bh)
		b.add_theme_stylebox_override("pressed", bh)
		b.add_theme_stylebox_override("focus", bh)
		b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
		b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.1))
		b.pressed.connect(answer.bind(i))
		vb.add_child(b)
		_buttons.append(b)
	_status = UITheme.label("", 20, Color(0.3, 0.32, 0.4), true)
	vb.add_child(_status)
	_paused = UITheme.label(tr("P5_QUIZ_PAUSED"), 18, Color(0.85, 0.85, 0.8), true)
	_paused.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_paused.position = Vector2(40, 30)
	_paused.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_paused)
	EventBus.death_sequence_started.connect(_on_death)


func _on_death(_c: String, _k: String, _d: String) -> void:
	_root.visible = false
	closed = true


## P7: mientras el quiz está en pantalla los avisos de primera vez esperan (su esquina es la del «reloj parado»).
func blocks_tips() -> bool:
	return _root != null and _root.visible and not closed


func open(qs: Array, p_need: int, p_hint: bool, forced: Array = [], title: String = "") -> void:
	add_to_group("tip_blocker")
	if title != "" and _title != null:
		_title.text = title  # v0.3.2: cada «Actualización de campaña» tiene su tema (training.json/dias)
	questions = qs
	need = p_need
	hint = p_hint
	_forced = forced.duplicate()
	index = 0
	score = 0
	results.clear()
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show()


func _show() -> void:
	if index >= questions.size():
		return
	var q: Dictionary = questions[index]
	_count.text = "%s %d / %d" % [tr("P5_QUIZ_QUESTION"), index + 1, questions.size()]
	_q.text = Loc.pick(q)
	_hint.text = ("%s %s" % [tr("P5_QUIZ_HINT"), Loc.pick(q.get("pista", {}))]) if hint else ""
	var opts: Array = q.get("opciones", [])
	for i in _buttons.size():
		var b := _buttons[i]
		b.visible = i < opts.size()
		if i < opts.size():
			b.text = "%d.  %s" % [i + 1, Loc.pick(opts[i])]
		b.disabled = false
		b.modulate = Color.WHITE
	_status.text = Loc.fmt(tr("FBUI_QUIZ_STATUS"), {"n": score, "min": need, "total": questions.size()})  # v0.3.2: «mínimo N de 5» siempre a la vista
	if not _forced.is_empty() and index < _forced.size():
		get_tree().create_timer(0.35).timeout.connect(_auto_answer.bind(index, int(_forced[index])))


func _auto_answer(at: int, pick: int) -> void:
	if is_inside_tree() and not closed and at == index:
		answer(_forced_choice(pick))


func _forced_choice(pick: int) -> int:
	var q: Dictionary = questions[index]
	var corr := int(q.get("correcta", 0))
	if pick == -1:
		return corr
	if pick == -2:
		return (corr + 1) % maxi((q.get("opciones", []) as Array).size(), 1)
	return pick


## Responde la pregunta actual con la opción i (clic, tecla, bot o prueba).
func answer(i: int) -> void:
	if closed or _busy or index >= questions.size():
		return
	var q: Dictionary = questions[index]
	var ok := i == int(q.get("correcta", -1))
	_busy = true
	results.append(ok)
	if ok:
		score += 1
	for k in _buttons.size():
		_buttons[k].disabled = true
		if k == int(q.get("correcta", -1)) and hint:
			_buttons[k].modulate = Color(0.75, 1.0, 0.75)
	_buttons[clampi(i, 0, _buttons.size() - 1)].modulate = Color(0.7, 1.0, 0.7) if ok else Color(1.0, 0.55, 0.55)
	if not ok:
		_q.text = "GAAAA" if randf() < 0.5 else _q.text
	EventBus.quiz_answered.emit(index, ok)
	answered.emit(index, ok)
	await PersonajesP5.wait(self, 0.9)
	if not is_inside_tree():
		return
	_busy = false
	index += 1
	if index >= questions.size():
		closed = true
		_status.text = Loc.fmt(tr("FBUI_QUIZ_RESULT"), {"n": score, "min": need, "total": questions.size()})
		finished.emit(score, questions.size(), score >= need)
		return
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if closed or not (event is InputEventKey) or not event.pressed:
		return
	var k := (event as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_3:
		answer(int(k - KEY_1))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_paused.modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.0))
	_paused.text = "%s  ·  %s" % [tr("P5_QUIZ_PAUSED"), GameState.clock_text()]


func _exit_tree() -> void:
	Input.mouse_mode = _prev_mouse

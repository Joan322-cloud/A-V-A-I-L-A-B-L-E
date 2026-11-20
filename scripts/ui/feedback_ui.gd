class_name FeedbackUI
extends CanvasLayer
## Pantalla del feedback de Haime (sala de calibración): el monitor de calibración con tu contacto transcrito, tus
## errores marcados en rojo uno por uno (la pluma raya la fila), el puntaje que baja, el REC que late con tu pulso, la
## línea que dice Haime (= su voz, palabra por palabra) y las preguntas rápidas (teclas 1-4, 3-5 s).
## v0.3.2 (Joan: suspenso y tensión): el velo se oscurece con cada error, la pantalla salta con el golpe en la mesa,
## apagón en el salto, «AURICULAR DESCONECTADO» cuando te lo quita. En la advertencia y la fatal tu voz va al revés.
## API (QaFeedback): open · door_locked · show_line · mark_error · replay/replay_end · ask/answer/asking + señal
## resolved · anger · silence · jump · slam · headset_off · final_score · set_score · final_rec · pulse_rate ·
## history · prewritten · dark · note · lie_called.
## v0.3.2 (dirección de la advertencia y la fatal): en esos dos niveles la oscuridad es la de la sala (las luces de
## verdad): el velo de la pantalla casi no interviene, y al irse la pantalla con la última frase de la fatal quedan solo
## su frase y el REC. Mientras el auricular reproduce tu contacto o tu voz, una forma de onda sigue al audio.

signal resolved(result: int)  # opción elegida 0..3 · -1 tarde · -2 te cortó

var _root: Control = null
var _panel: PanelContainer = null
var _title: Label = null
var _transcript: VBoxContainer = null
var _ops: VBoxContainer = null
var _score: Label = null
var _score_cap: Label = null
var _line: Label = null
var _rec: Label = null
var _veil: ColorRect = null
var _black: ColorRect = null
var _flash: Label = null
var _qbox: PanelContainer = null
var _qopts: Array[Label] = []
var _qbar: ColorRect = null
var _qtime: Label = null
var _rows: Array[Label] = []
var _me_rows: Array[int] = []  # filas con TU voz (si la marca no tiene fila propia, la pluma raya la siguiente tuya)
var _strokes: Array[ColorRect] = []
var _n: int = 1
var _nivel: int = 1
var _dark: bool = false  # v0.3.1: la advertencia y la fatal (antes: n >= 3)
var _t: float = 0.0
var _shake_left: float = 0.0
var _score_shown: float = 100.0
var _veil_a: float = 0.22
var _q_left: float = -1.0
var _q_total: float = 1.0
var _q_cut: float = -1.0
var _q_correct: int = 0
var _q_open: bool = false
var _flash_left: float = 0.0
var pulse_rate: float = 1.0  # latidos del REC por segundo (lo sube la tensión)
var opportunities: Array[String] = []  # lo que se mostró (pruebas)
var marked_rows: Array[int] = []  # filas marcadas en rojo (pruebas)
var last_options: Array = []  # opciones de la última pregunta (pruebas)
var _hist: VBoxContainer = null  # v0.3.2: «TUS CALIBRACIONES» (lo que Haime recuerda de la partida)
var _hist_box: PanelContainer = null
var history_rows: Array = []  # lo que se mostró (pruebas)
var history_focus: int = -1  # la fila resaltada (pruebas)
var prewritten_shown: bool = false
var _veil_base: float = 0.22
var _wave: Control = null
var wave_on: bool = false  # la forma de onda del auricular está en pantalla (pruebas)
var _wave_amps: PackedFloat32Array = PackedFloat32Array()
var _wave_color: Color = Color(0.95, 0.25, 0.2)
var _wave_acc: float = 0.0
var _wave_bus: int = -2
var _quote: Label = null
var _quote_left: float = 0.0
var lie_quote: String = ""  # tu frase de Ezlaki que mostró (pruebas)
var _final: bool = false
const WAVE_BARS := 56


func _ready() -> void:
	layer = 0  # v0.3.1 Q1 (F6): debajo de la UI principal (capa 1): la pausa y la muerte siempre encima
	add_to_group("subtitle_owner")  # P7: con la pantalla abierta, el HUD no repite la línea de Haime abajo
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.1, 0.0, 0.0, 0.22)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	_panel = UITheme.panel("", Vector2(540, 470))
	_panel.position = Vector2(36, 64)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.05, 0.9)
	sb.border_color = Color(0.55, 0.08, 0.08)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var vb := _panel.get_node("VB") as VBoxContainer
	vb.add_theme_constant_override("separation", 6)
	_title = UITheme.label("", 16, Color(0.8, 0.84, 0.86), true)
	vb.add_child(_title)
	vb.add_child(HSeparator.new())
	_transcript = VBoxContainer.new()
	_transcript.add_theme_constant_override("separation", 3)
	vb.add_child(_transcript)
	vb.add_child(HSeparator.new())
	var oph := UITheme.label(tr("P5_FB_OPPORTUNITIES"), 15, Color(0.85, 0.3, 0.28), true)
	vb.add_child(oph)
	_ops = VBoxContainer.new()
	_ops.add_theme_constant_override("separation", 4)
	vb.add_child(_ops)
	_score = UITheme.label("100", 64, Color(0.9, 0.86, 0.8), true)
	_score.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score.offset_left = -300
	_score.offset_top = 170
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_score)
	_score_cap = UITheme.label("/ 100  QA", 18, Color(0.7, 0.72, 0.72), true)
	_score_cap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score_cap.offset_left = -300
	_score_cap.offset_top = 246
	_score_cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_score_cap)
	_rec = UITheme.label("● REC", 34, Color(0.92, 0.1, 0.08), true)
	_rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rec.offset_left = -300
	_rec.offset_top = 120  # bajo la hora y el AUX del HUD
	_rec.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_rec)
	_hist_box = PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.04, 0.03, 0.03, 0.82)
	hsb.border_color = Color(0.55, 0.08, 0.08)
	hsb.set_border_width_all(1)
	hsb.set_content_margin_all(10)
	_hist_box.add_theme_stylebox_override("panel", hsb)
	_hist_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hist_box.offset_left = -430
	_hist_box.offset_right = -24
	_hist_box.offset_top = 282
	_hist_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hist_box.visible = false
	_root.add_child(_hist_box)
	_hist = VBoxContainer.new()
	_hist.add_theme_constant_override("separation", 4)
	_hist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hist_box.add_child(_hist)
	_qbox = PanelContainer.new()
	var qsb := StyleBoxFlat.new()
	qsb.bg_color = Color(0.05, 0.02, 0.02, 0.92)
	qsb.border_color = Color(0.8, 0.12, 0.1)
	qsb.set_border_width_all(2)
	qsb.set_content_margin_all(12)
	_qbox.add_theme_stylebox_override("panel", qsb)
	_qbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_qbox.offset_left = -390
	_qbox.offset_right = 390
	_qbox.offset_top = -420
	_qbox.offset_bottom = -232
	_qbox.visible = false
	_root.add_child(_qbox)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 5)
	_qbox.add_child(qv)
	_qtime = UITheme.label("", 15, Color(0.95, 0.45, 0.4), true)
	qv.add_child(_qtime)
	for i in 4:
		var o := UITheme.label("", 17, Color(0.93, 0.9, 0.86))
		o.custom_minimum_size = Vector2(740, 0)
		qv.add_child(o)
		_qopts.append(o)
	_qbar = ColorRect.new()
	_qbar.color = Color(0.85, 0.12, 0.1)
	_qbar.custom_minimum_size = Vector2(740, 6)
	qv.add_child(_qbar)
	_line = UITheme.label("", 24, Color(0.95, 0.93, 0.9))
	_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_line.offset_top = -214
	_line.offset_bottom = -140
	_line.offset_left = 120
	_line.offset_right = -120
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_line)
	_flash = UITheme.label("", 22, Color(1.0, 0.2, 0.15), true)
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_left = -300
	_flash.offset_right = 300
	_flash.offset_top = 60
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_flash)
	# La forma de onda del auricular (bajo el aviso «REPRODUCIENDO…» / «TU VOZ»).
	_wave_amps.resize(WAVE_BARS)
	_wave = Control.new()
	_wave.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave.offset_left = -190
	_wave.offset_right = 190
	_wave.offset_top = 94
	_wave.offset_bottom = 134
	_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.visible = false
	_wave.draw.connect(_draw_wave)
	_root.add_child(_wave)
	_quote = UITheme.label("", 18, Color(0.96, 0.93, 0.9))
	_quote.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_quote.offset_left = -330
	_quote.offset_right = 330
	_quote.offset_top = 92
	_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.visible = false
	_root.add_child(_quote)
	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)
	EventBus.death_sequence_started.connect(_on_death)


func _on_death(_c: String, _k: String, _d: String) -> void:
	_root.visible = false


## `dark`: 1 = la sesión de advertencia o la fatal (voz al revés, temblor); 0 = no; -1 = como antes (n >= 3).
func open(n: int, contact: Dictionary, score: int, dark: int = -1, nivel: int = 0) -> void:
	_n = n
	_nivel = nivel if nivel > 0 else clampi(n, 1, 4)
	_dark = n >= 3 if dark < 0 else dark == 1
	# La advertencia y la fatal: la oscuridad es la de la sala; el velo, apenas un tinte.
	_veil_base = 0.1 if _nivel >= 3 else 0.22
	_veil_a = _veil_base
	_veil.color.a = _veil_base
	_title.text = "%s · %s %s · %s" % [tr("P5_FB_TITLE"), tr("P5_FB_CONTACT"), str(contact.get("id", "")), str(contact.get("hora", ""))]
	for c in _transcript.get_children():
		c.queue_free()
	_rows.clear()
	_strokes.clear()
	_me_rows.clear()
	var tr_lines: Array = contact.get("transcripcion", [])
	var shown := 0
	for e in tr_lines:
		if shown >= 7:
			break
		var d := e as Dictionary
		var me := str(d.get("quien", "")) == "yo"
		var who := GameState.agent if me else tr("P5_FB_CUSTOMER")
		var txt := str(d.get("texto", "")).replace("\n", " ")
		if _dark and me:
			txt = _reverse(txt)  # tu voz, al revés
		if me:
			_me_rows.append(_rows.size())
		_add_row("%s: %s" % [who, txt], Color(0.75, 0.8, 0.85) if me else Color(0.6, 0.64, 0.66))
		shown += 1
	if _rows.is_empty():
		_add_row(tr("P5_FB_NO_TRANSCRIPT"), Color(0.6, 0.64, 0.66))
	set_score(score)


func _add_row(text: String, col: Color) -> void:
	var l := UITheme.label(text, 14, col, true)
	l.custom_minimum_size = Vector2(510, 0)
	_transcript.add_child(l)
	# La raya de la pluma: hija de la fila, a media altura de la primera línea.
	var st := ColorRect.new()
	st.color = Color(0.95, 0.1, 0.08, 0.9)
	st.size = Vector2(0, 2)
	st.position = Vector2(0, 9)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(st)
	_rows.append(l)
	_strokes.append(st)


func set_score(score: int) -> void:
	_score.visible = true
	_score_shown = float(score)
	_paint_score(score)


func _paint_score(v: int) -> void:
	_score.text = str(v)
	_score.add_theme_color_override("font_color", Color(0.95, 0.2, 0.15) if v < 50 else Color(0.9, 0.86, 0.8))


## El puntaje baja contando (como un taxímetro al revés).
func _tick_to(score: int) -> void:
	var tw := create_tween()
	tw.tween_method(_set_shown, _score_shown, float(score), 0.55)


func _set_shown(v: float) -> void:
	_score_shown = v
	_paint_score(int(round(v)))


func door_locked() -> void:
	_flash_text(Loc.pick({"es": "PUERTA CERRADA", "en": "DOOR LOCKED"}), 1.6)


## La segunda vuelta de llave (la advertencia y la fatal).
func door_locked_twice() -> void:
	_flash_text(Loc.pick({"es": "PUERTA CERRADA · DOS VUELTAS", "en": "DOOR LOCKED · TWICE"}), 2.2)


## La fatal: tu puntaje ya está escrito antes de sentarte.
func prewritten() -> void:
	prewritten_shown = true
	_score_cap.text = Loc.pick({"es": "/ 100  QA · YA ESCRITO", "en": "/ 100  QA · ALREADY WRITTEN"})
	_score_cap.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))


## Lo que Haime recuerda de tus calibraciones anteriores en esta partida: una lista bajo el puntaje. `focus` = la fila de
## la que está hablando (resaltada; la de tu frase de Ezlaki o tus tardanzas puede ocupar dos renglones).
func history(rows: Array, focus: int = -1) -> void:
	history_rows = rows.duplicate()
	history_focus = focus
	for c in _hist.get_children():
		c.queue_free()
	var head := UITheme.label(Loc.pick({"es": "TUS CALIBRACIONES", "en": "YOUR CALIBRATIONS"}), 15, Color(0.92, 0.32, 0.28), true)
	_hist.add_child(head)
	var delay := 0.0
	for i in rows.size():
		var on := i == focus
		var l := UITheme.label(("▸ " if on else "  ") + str(rows[i]), 15 if on else 14, Color(1.0, 0.86, 0.8) if on else Color(0.86, 0.56, 0.52), true)
		l.custom_minimum_size = Vector2(384, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if on else TextServer.AUTOWRAP_OFF
		if not on:
			l.clip_text = true
		l.modulate.a = 0.0
		_hist.add_child(l)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		delay += 0.22
	_hist_box.visible = true
	_shake_left = 0.15


## Apagón corto de la pantalla (él se movió en la oscuridad).
func dark(secs: float) -> void:
	_black.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(maxf(secs - 0.1, 0.02))
	tw.tween_property(_black, "color:a", 0.0, 0.1)


## La pluma dejó de sonar / una luz murió: la pantalla lo acusa.
func note(text_es: String, text_en: String, secs: float = 1.8) -> void:
	_flash_text(Loc.pick({"es": text_es, "en": text_en}), secs)


func show_line(text: String) -> void:
	_line.text = text if bool(Loc.get_setting("subtitles", true)) else ""


## Un error tuyo: la fila (si la hay) se pone roja y la pluma la raya en golpecitos; la oportunidad entra en la lista;
## el puntaje baja; el velo se oscurece con la luz de la sala.
func mark_error(row: int, om: int, text: String, quote: String, score: int, dim: float) -> void:
	var item := quote if quote != "" else text
	opportunities.append(text)
	var col := Color(0.95, 0.32, 0.28)
	if (row < 0 or marked_rows.has(row)) and text != "":
		for r in _me_rows:
			if not marked_rows.has(r):
				row = r
				break
	if row >= 0 and row < _rows.size() and not marked_rows.has(row):
		marked_rows.append(row)
		_rows[row].add_theme_color_override("font_color", col)
		var st := _strokes[row]
		var w := minf(_rows[row].size.x, 500.0)
		var tw := create_tween()
		for k in 3:
			tw.tween_property(st, "size:x", w * float(k + 1) / 3.0, 0.08)
			tw.tween_interval(0.05)
	var l := UITheme.label("%s %d — %s" % [tr("P5_FB_OPPORTUNITY"), om, ("«%s»" % item) if quote != "" else item], 14, Color(0.98, 0.55, 0.5))
	l.custom_minimum_size = Vector2(510, 0)
	l.modulate = Color(2.0, 0.6, 0.6)
	_ops.add_child(l)
	var tw2 := create_tween()
	tw2.tween_property(l, "modulate", Color(1, 1, 1), 0.5)
	_tick_to(score)
	_veil_a = clampf(_veil_base + dim * 0.55, _veil_base, 0.7)


## Compatibilidad (v0.3.1): una oportunidad sin fila.
func add_opportunity(i: int, text: String) -> void:
	mark_error(-1, i, text, "", int(_score_shown), 0.0)


## Replay: la transcripción se ilumina línea por línea mientras el auricular suena.
func replay() -> void:
	var delay := 0.0
	for i in _rows.size():
		var r := _rows[i]
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(r, "modulate", Color(1.7, 1.3, 1.3), 0.15)
		tw.tween_property(r, "modulate", Color(1, 1, 1), 0.35)
		delay += 0.32
	_flash_text(Loc.pick({"es": "REPRODUCIENDO TU CONTACTO", "en": "PLAYING YOUR CONTACT"}), 3.2)
	_wave_show(Color(0.95, 0.25, 0.2))


func _wave_show(col: Color) -> void:
	_quote.visible = false
	_quote_left = 0.0
	_wave_color = col
	for i in _wave_amps.size():
		_wave_amps[i] = 0.0
	_wave.visible = true
	wave_on = true


## Tu propia voz en el auricular: la onda va en blanco sucio (no es el cliente: eres tú).
func replay_own() -> void:
	_wave_show(Color(0.95, 0.9, 0.86))


## Haime cortó la grabación: la onda se va.
func replay_end() -> void:
	wave_on = false
	_wave.visible = false


## Nivel del auricular ahora (0..1): el pico del bus «HaimeReplay»; sin dispositivo de audio, sílabas simuladas.
func _wave_level() -> float:
	if _wave_bus == -2:
		_wave_bus = AudioServer.get_bus_index("HaimeReplay")
	if _wave_bus >= 0:
		var db := maxf(AudioServer.get_bus_peak_volume_left_db(_wave_bus, 0), AudioServer.get_bus_peak_volume_right_db(_wave_bus, 0))
		if db > -80.0:
			return clampf(remap(db, -46.0, -8.0, 0.06, 1.0), 0.06, 1.0)
	var syl := 0.5 + 0.5 * sin(_t * 23.0)
	syl *= 0.45 + 0.55 * absf(sin(_t * 5.3 + 1.1))
	return clampf(0.1 + 0.85 * syl, 0.06, 1.0)


func _draw_wave() -> void:
	var w := _wave.size.x / float(WAVE_BARS)
	var mid := _wave.size.y * 0.5
	for i in WAVE_BARS:
		var h := maxf(_wave_amps[i] * _wave.size.y * 0.5, 1.0)
		_wave.draw_rect(Rect2(i * w + 1.0, mid - h, maxf(w - 2.0, 1.0), h * 2.0), Color(_wave_color.r, _wave_color.g, _wave_color.b, 0.35 + 0.65 * float(i) / float(WAVE_BARS)))


## Pregunta: 4 opciones (teclas 1-4) y la barra del tiempo. `cut` > 0: a los `cut` s sin respuesta Haime te corta (-2).
func ask(options: Array, correct: int, secs: float, cut: float = -1.0) -> void:
	last_options = options.duplicate()
	_q_correct = correct
	_q_total = maxf(secs, 0.5)
	_q_left = _q_total
	_q_cut = cut
	_q_open = true
	for i in 4:
		var o := _qopts[i]
		o.visible = i < options.size()
		if i < options.size():
			o.text = "%d   %s" % [i + 1, str(options[i])]
			o.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	_qbox.visible = true
	_qbar.scale.x = 1.0


func asking() -> bool:
	return _q_open


func answer(option: int) -> void:
	if not _q_open:
		return
	_q_open = false
	var ok := option == _q_correct
	if option >= 0 and option < _qopts.size():
		_qopts[option].add_theme_color_override("font_color", Color(0.5, 0.95, 0.55) if ok else Color(1.0, 0.25, 0.2))
	_close_question(0.35)
	resolved.emit(option)


func _expire(code: int) -> void:
	if not _q_open:
		return
	_q_open = false
	_qtime.text = Loc.pick({"es": "TARDE", "en": "TOO LATE"}) if code == -1 else Loc.pick({"es": "TE CORTÓ", "en": "CUT OFF"})
	_close_question(0.3)
	resolved.emit(code)


func _close_question(after: float) -> void:
	var tw := create_tween()
	tw.tween_interval(after)
	tw.tween_callback(_hide_question)


func _hide_question() -> void:
	if not _q_open:
		_qbox.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _q_open or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_4:
		answer(int(k - KEY_1))
		get_viewport().set_input_as_handled()
	elif k >= KEY_KP_1 and k <= KEY_KP_4:
		answer(int(k - KEY_KP_1))
		get_viewport().set_input_as_handled()


## Más enojo: el puntaje baja un poco más y la pantalla tiembla.
func anger(level: int, score: int) -> void:
	_tick_to(score)
	_shake_left = 0.25 + 0.05 * level
	_veil_a = clampf(_veil_a + (0.05 if _nivel < 3 else 0.02), _veil_base, 0.75)


func silence(on: bool) -> void:
	_line.text = "" if on else _line.text
	_panel.modulate.a = 0.55 if on else 1.0


## El salto: apagón de un instante y la pantalla salta.
func jump() -> void:
	_black.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(_black, "color:a", 0.0, 0.18)
	_shake_left = 0.4


func slam() -> void:
	_shake_left = 0.32
	_veil.color = Color(0.35, 0.0, 0.0, _veil.color.a + 0.15)


## Gancho IA: le mentiste a Haime en Ezlaki. `quote` = tu frase tal como la escribiste («hora · «frase»»): la pantalla
## te la pone delante mientras él te lo dice.
func lie_called(quote: String = "") -> void:
	_flash_text(Loc.pick({"es": "MENTISTE EN EZLAKI", "en": "YOU LIED ON EZLAKI"}), 4.2 if quote != "" else 2.4)
	_shake_left = 0.35
	lie_quote = quote
	if quote != "":
		replay_end()
		_quote.text = "EZLAKI · " + quote
		_quote.visible = true
		_quote_left = 4.2


func headset_off() -> void:
	_flash_text(Loc.pick({"es": "AURICULAR DESCONECTADO", "en": "HEADSET DISCONNECTED"}), 2.6)
	_shake_left = 0.45


func final_score(score: int) -> void:
	_tick_to(score)
	var tw := create_tween()
	tw.tween_property(_score, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(_score, "scale", Vector2(1, 1), 0.25)


func _flash_text(text: String, secs: float) -> void:
	_flash.text = text
	_flash_left = secs


## El velo se va (la fatal, en el apagón de la certeza): lo que se ve después es la luz de la sala, sin filtro; así la
## última frase y la muerte salen con la misma imagen.
func veil_off() -> void:
	_veil_base = 0.0
	_veil_a = 0.0
	_veil.color.a = 0.0


## Antes del screamer de la calibración final. v0.3.1 (F3/F6): la pantalla se va del todo (antes el velo rojo al
## 85 % era la «pantalla roja» que vio Joan): el REC queda solo en el monitor 3D y el screamer se ve entero.
## v0.3.2: se va todo MENOS su frase (el subtítulo de su última línea no puede desaparecer a media frase) y el REC.
func final_rec() -> void:
	if _final:
		return
	_final = true
	_veil_a = 0.0
	replay_end()
	for c in _root.get_children():
		if c == _line or c == _rec or c == _black or not (c is CanvasItem):
			continue
		var tw := create_tween()
		tw.tween_property(c, "modulate:a", 0.0, 0.45)


func _process(delta: float) -> void:
	_t += delta
	# El REC late con tu pulso (lo sube la tensión).
	var ph := fmod(_t * pulse_rate, 1.0)
	_rec.modulate.a = 1.0 if ph < 0.18 else lerpf(0.75, 0.15, clampf((ph - 0.18) / 0.6, 0.0, 1.0))
	var target_a := _veil_a + (0.06 * sin(_t * 7.0) if _dark and not _final and _nivel < 3 else 0.0)
	_veil.color.a = move_toward(_veil.color.a, clampf(target_a, 0.0, 0.85), delta * 1.5)
	_veil.color.r = move_toward(_veil.color.r, 0.1, delta * 0.8)
	var jitter := 1.5 if _dark else 0.0
	if _shake_left > 0.0:
		_shake_left -= delta
		jitter = 9.0 * _shake_left / 0.4
	_panel.position = Vector2(36, 64) + (Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter)) if jitter > 0.0 else Vector2.ZERO)
	if _flash_left > 0.0:
		_flash_left -= delta
		if not _final:
			_flash.modulate.a = 1.0 if fmod(_t, 0.5) < 0.35 else 0.4
		if _flash_left <= 0.0:
			_flash.text = ""
	if _quote_left > 0.0:
		_quote_left -= delta
		if _quote_left <= 0.0:
			_quote.visible = false
	if wave_on:
		_wave_acc += delta
		while _wave_acc >= 0.035:
			_wave_acc -= 0.035
			for i in WAVE_BARS - 1:
				_wave_amps[i] = _wave_amps[i + 1]
			_wave_amps[WAVE_BARS - 1] = _wave_level()
		_wave.queue_redraw()
	if _q_open:
		_q_left -= delta
		_qbar.scale.x = clampf(_q_left / _q_total, 0.0, 1.0)
		_qtime.text = "%s  %.1f s" % [Loc.pick({"es": "RESPONDE (1-4)", "en": "ANSWER (1-4)"}), maxf(_q_left, 0.0)]
		if _q_cut > 0.0 and _q_total - _q_left >= _q_cut:
			_expire(-2)
		elif _q_left <= 0.0:
			_expire(-1)


static func _reverse(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s[i]
	return out


## P7: el HUD consulta esto para no duplicar el subtítulo (la pantalla ya muestra la línea en grande).
func owns_subtitles() -> bool:
	return _root != null and _root.visible

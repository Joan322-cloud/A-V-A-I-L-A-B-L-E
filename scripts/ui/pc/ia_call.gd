class_name PcIACall
extends VBoxContainer
## v0.3.2 IA · Panel de la llamada en Kardex: micrófono (pulsar para hablar con [T] o manteniendo el botón,
## medidor de nivel, «Escuchando…», lo que dijiste en vivo) y una caja para decirle algo escrito al cliente.
## Lo reconocido va a ContactManager.say(texto, "voz"). Si el reconocimiento falla o no hay micrófono: aviso claro
## y, en Fácil/Normal, las respuestas rápidas de ese turno (en Difícil, a escribir).

signal fallback_changed(on: bool)

var cm: ContactManager = null
var fallback: bool = false  # en este turno se muestran las respuestas rápidas aunque estés en modo micrófono
var input: LineEdit = null
var _mic_row: HBoxContainer = null
var _btn: Button = null
var _meter: ProgressBar = null
var _state: Label = null
var _said: Label = null
var _lang_note: Label = null  # «Voz: solo español» con el juego en inglés
var _node_sig: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 3)
	_mic_row = HBoxContainer.new()
	_mic_row.add_theme_constant_override("separation", 8)
	add_child(_mic_row)
	# El icono del micrófono es el dibujo propio (la fuente del juego no trae emojis: el botón salía vacío).
	_btn = PcStyle.button("", func() -> void: pass, PcStyle.F_SMALL, Color(0.3, 0.12, 0.14))
	_btn.custom_minimum_size = Vector2(44, 30)
	var mic_tex := Emoji.texture("🎙")
	if mic_tex != null:
		_btn.icon = mic_tex
		_btn.expand_icon = true
		_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_btn.add_theme_constant_override("icon_max_width", 22)
	else:
		_btn.text = "MIC"
	_btn.tooltip_text = tr("IA_OPT_CALLS_MIC")
	_btn.button_down.connect(func() -> void: IASpeech.ptt_down())
	_btn.button_up.connect(func() -> void: IASpeech.ptt_up())
	_mic_row.add_child(_btn)
	_meter = ProgressBar.new()
	_meter.name = "NivelMic"
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(110, 12)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter.add_theme_stylebox_override("background", PcStyle.box(Color(0.05, 0.06, 0.07), PcStyle.BORDER, 0.0, 3))
	_meter.add_theme_stylebox_override("fill", PcStyle.box(PcStyle.GREEN, Color(0, 0, 0, 0), 0.0, 3))
	_mic_row.add_child(_meter)
	_state = PcStyle.label("", PcStyle.F_TINY, PcStyle.DIM, false)
	_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mic_row.add_child(_state)
	_lang_note = PcStyle.label("", PcStyle.F_TINY, PcStyle.YELLOW)
	_lang_note.name = "AvisoVozSoloEspanol"
	_lang_note.visible = false
	add_child(_lang_note)
	_said = PcStyle.label("", PcStyle.F_SMALL, Color(0.75, 0.9, 1.0))
	add_child(_said)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	input = LineEdit.new()
	input.name = "DecirCliente"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 220
	input.placeholder_text = tr("IA_CALL_SAY")
	input.add_theme_font_size_override("font_size", PcStyle.F_TINY)
	input.add_theme_stylebox_override("normal", PcStyle.box(Color(0.05, 0.055, 0.07), PcStyle.BORDER, 4, 8))
	input.add_theme_stylebox_override("focus", PcStyle.box(Color(0.06, 0.07, 0.09), PcStyle.ACCENT, 4, 8))
	input.text_submitted.connect(func(_t: String) -> void: submit())
	input.focus_entered.connect(func() -> void: GameState.flags["pc_text_focus"] = true)
	input.focus_exited.connect(func() -> void: GameState.flags["pc_text_focus"] = false)
	row.add_child(input)
	row.add_child(PcStyle.button(tr("IA_CHAT_SEND"), func() -> void: submit(), PcStyle.F_TINY, Color(0.16, 0.36, 0.3)))
	IASpeech.partial.connect(func(t: String) -> void: _said.text = Loc.fmt(tr("IA_MIC_YOU_SAID"), {"texto": t}))
	IASpeech.level.connect(func(v: float) -> void: _meter.value = v)
	IASpeech.result.connect(_on_result)


func submit() -> Dictionary:
	if cm == null:
		return {}
	var t := input.text.strip_edges()
	input.text = ""
	input.release_focus()
	GameState.flags["pc_text_focus"] = false
	if t == "":
		return {}
	_set_fallback(false)
	return cm.say(t, "voz_escrita")


func _on_result(text: String, ok: bool) -> void:
	if not is_visible_in_tree() or cm == null or cm.tree == null:
		return
	if not ok:
		_said.text = tr("IA_MIC_FAIL")
		_set_fallback(true)
		return
	_said.text = Loc.fmt(tr("IA_MIC_YOU_SAID"), {"texto": text})
	var r := cm.say(text, "voz")
	_set_fallback(false)
	if bool(r.get("ok", false)) and not bool(r.get("matched", false)):
		_said.text += "  ·  " + tr("IA_MIC_NO_MATCH")


func _set_fallback(on: bool) -> void:
	if fallback == on:
		return
	fallback = on
	fallback_changed.emit(on)


func refresh(_delta: float) -> void:
	var mic := IASpeech.mic_mode()
	GameState.flags["ia_llamada_activa"] = mic and cm != null and cm.tree != null
	_mic_row.visible = mic
	if cm != null and cm.tree != null:
		var sig := "%s|%s" % [str(cm.current.get("id", "")), cm.tree.node_id]
		if sig != _node_sig:
			_node_sig = sig
			if fallback and not IASpeech.state in ["unavailable", "error"]:
				_set_fallback(false)  # el fallback vale para un turno
	# v0.3.2-core: juego en inglés + voz solo en español → se avisa y las respuestas rápidas quedan a mano en cada
	# turno (en Difícil no hay rápidas: se escribe, y lo escrito en inglés se entiende).
	var es_only := mic and IASpeech.language_mismatch()
	_lang_note.visible = es_only
	if es_only:
		_lang_note.text = tr("IA_MIC_ES_ONLY_SHORT")
		if not fallback:
			_set_fallback(true)
	if not mic:
		return
	if IASpeech.state == "off":
		IASpeech.refresh()
	var key := "IA_MIC_STATE_OK"
	var col := PcStyle.DIM
	match IASpeech.state:
		"listening":
			_state.text = tr("IA_MIC_LISTENING")
			col = PcStyle.RED
		"thinking":
			_state.text = tr("IA_MIC_THINKING")
			col = PcStyle.YELLOW
		"ready":
			_state.text = Loc.fmt(tr("IA_MIC_HOLD"), {"tecla": _key_name()})
		"loading":
			_state.text = tr("IA_MIC_STATE_LOADING")
		_:
			key = {"no_consent": "IA_MIC_STATE_NOCONSENT", "no_engine": "IA_MIC_STATE_NOENGINE", "no_model": "IA_MIC_STATE_NOENGINE"}.get(IASpeech.reason, "IA_MIC_STATE_ERROR")
			_state.text = Loc.fmt(tr("IA_MIC_UNAVAILABLE"), {"motivo": tr(key)})
			col = PcStyle.YELLOW
			if not fallback:
				_set_fallback(true)
	_state.add_theme_color_override("font_color", col)
	_btn.disabled = not IASpeech.state in ["ready", "listening"]
	if IASpeech.state != "listening":
		_meter.value = maxf(0.0, _meter.value - 0.05)


func _key_name() -> String:
	if not InputMap.has_action(IASpeech.PTT_ACTION):
		return "T"
	for e in InputMap.action_get_events(IASpeech.PTT_ACTION):
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	return "T"

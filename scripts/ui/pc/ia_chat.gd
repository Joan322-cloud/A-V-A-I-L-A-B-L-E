class_name PcIAChat
extends VBoxContainer
## v0.3.2 IA · Vista de chat con el cliente (dentro de Kardex, en los contactos de canal «chat»): burbujas con hora,
## el cliente «escribiendo…», doble check «Leído», caja para escribir (Enter envía) y la fila de respuestas rápidas
## con las opciones del árbol (solo en Fácil/Normal; en Difícil y Turno real solo se escribe). Lo escrito pasa por
## ContactManager.say() → IACustomer: si se parece a una opción, el árbol avanza; si no, el cliente contesta en
## personaje. El dato del caso y el ánimo siguen arriba, en la cabecera de Kardex.
## Las mismas piezas (burbujas + caja) sirven en llamadas para «decirle» algo escrito al cliente (modo llamada).

var cm: ContactManager = null
var call_mode: bool = false
var input: LineEdit = null
var _head: HBoxContainer = null
var _who: Label = null
var _status: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _quick: HFlowContainer = null
var _quick_title: Label = null
var _note: Label = null
var _shown: int = 0  # entradas del historial ya dibujadas
var _cid: String = ""
var _reveal_left: float = 0.0  # el cliente «escribe» antes de que aparezca su burbuja
var _times: Dictionary = {}  # índice del historial -> hora
var _force_quick: bool = false  # el micrófono falló: respuestas rápidas en este turno
var _typing_bubble: Control = null
var _typing_label: Label = null
var _dots_t: float = 0.0


func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 8)
	add_child(_head)
	var av := PanelContainer.new()
	var sb := PcStyle.box(Color(0.22, 0.32, 0.45), Color(0, 0, 0, 0), 2.0, 14)
	av.add_theme_stylebox_override("panel", sb)
	av.custom_minimum_size = Vector2(24, 22)
	var ini := PcStyle.label("C", PcStyle.F_SMALL, PcStyle.TEXT, false)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(ini)
	_head.add_child(av)
	var hv := HBoxContainer.new()  # nombre y «en línea» en una sola fila: la altura es para las burbujas
	hv.add_theme_constant_override("separation", 10)
	_who = PcStyle.label("", PcStyle.F_SMALL, PcStyle.TEXT, false)
	_status = PcStyle.label("", PcStyle.F_TINY, PcStyle.GREEN, false)
	hv.add_child(_who)
	hv.add_child(_status)
	_head.add_child(hv)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_theme_stylebox_override("panel", PcStyle.box(Color(0.045, 0.055, 0.07), PcStyle.BORDER, 6.0, 4))
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	_quick_title = PcStyle.label(tr("IA_CHAT_QUICK"), PcStyle.F_TINY, PcStyle.DIM, false)
	add_child(_quick_title)
	_quick = HFlowContainer.new()
	_quick.add_theme_constant_override("h_separation", 4)
	_quick.add_theme_constant_override("v_separation", 4)
	add_child(_quick)
	_note = PcStyle.label("", PcStyle.F_TINY, PcStyle.YELLOW)
	_note.visible = false
	add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	input = LineEdit.new()
	input.name = "EscribirCliente"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 220
	input.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	input.add_theme_stylebox_override("normal", PcStyle.box(Color(0.05, 0.055, 0.07), PcStyle.BORDER, 5, 12))
	input.add_theme_stylebox_override("focus", PcStyle.box(Color(0.06, 0.07, 0.09), PcStyle.ACCENT, 5, 12))
	input.text_submitted.connect(func(_t: String) -> void: submit())
	input.focus_entered.connect(func() -> void: GameState.flags["pc_text_focus"] = true)
	input.focus_exited.connect(func() -> void: GameState.flags["pc_text_focus"] = false)
	row.add_child(input)
	row.add_child(PcStyle.button(tr("IA_CHAT_SEND"), func() -> void: submit(), PcStyle.F_SMALL, Color(0.16, 0.36, 0.3)))


## Envía lo escrito (Enter o el botón). Devuelve el resultado de ContactManager.say().
func submit() -> Dictionary:
	if cm == null or input == null:
		return {}
	var t := input.text.strip_edges()
	input.text = ""
	input.release_focus()
	GameState.flags["pc_text_focus"] = false
	if t == "":
		return {}
	_force_quick = false
	return cm.say(t, "voz_escrita" if call_mode else "chat")


## El micrófono no entendió: en este turno salen las respuestas rápidas (si la dificultad las permite).
func show_fallback(msg: String) -> void:
	_force_quick = true
	_note.text = msg
	_note.visible = msg != ""
	_rebuild_quick()


func reset_view() -> void:
	PcStyle.clear(_list)
	_shown = 0
	_times.clear()
	_reveal_left = 0.0
	_typing_bubble = null
	_force_quick = false
	_note.visible = false


var _tree_ref: DialogTree = null  # el último árbol: su final se sigue viendo un momento


func refresh(delta: float) -> void:
	if cm == null:
		return
	# estás escribiendo tu respuesta al chat: el cliente espera (ContactManager.composing)
	GameState.flags["ia_chat_escribiendo"] = not call_mode and input != null and input.has_focus() and input.text.strip_edges() != "" and cm.tree != null
	var fresh := cm.tree != null and cm.tree != _tree_ref  # contacto nuevo (aunque sea el mismo árbol otra vez)
	if cm.tree != null:
		_tree_ref = cm.tree
	if _tree_ref == null:
		return
	if fresh:
		_cid = ""
	var cid := str(cm.current.get("id", "")) if cm.tree != null else _cid
	if cid != _cid:
		_cid = cid
		reset_view()
		var arq := str(cm.current.get("arquetipo", "")).replace("_", " ").capitalize()
		_who.text = "%s · %s" % [tr("IA_CHAT_CUSTOMER"), arq]
		input.placeholder_text = tr("IA_CALL_SAY") if call_mode else tr("IA_CHAT_PLACEHOLDER")
	var hist: Array = _tree_ref.history
	if _reveal_left > 0.0:
		_reveal_left -= delta
		_dots_t += delta
		if _typing_label != null and is_instance_valid(_typing_label):
			_typing_label.text = ["●", "● ●", "● ● ●"][int(_dots_t * 3.0) % 3]
		_status.text = Loc.fmt(tr("IA_CHAT_TYPING"), {"nombre": tr("IA_CHAT_CUSTOMER")})
		_status.add_theme_color_override("font_color", PcStyle.YELLOW)
		if _reveal_left > 0.0:
			return
		if _typing_bubble != null:
			_typing_bubble.queue_free()
			_typing_bubble = null
	_status.text = "en línea" if Loc.language != "en" else "online"
	_status.add_theme_color_override("font_color", PcStyle.GREEN)
	var changed := false
	while _shown < hist.size():
		var h: Dictionary = hist[_shown]
		var mine := str(h.get("quien", "")) == "yo"
		if not mine and _shown > 0 and not call_mode and not _times.has(_shown):
			# el cliente escribe un rato antes de que salga su mensaje
			_times[_shown] = GameState.clock_text()
			var txt := Loc.pick(h.get("texto", {}))
			_reveal_left = clampf(0.7 + float(txt.length()) * 0.025, 0.8, 3.2)
			_dots_t = 0.0
			_typing_bubble = _typing_row()
			_list.add_child(_typing_bubble)
			_scroll_down()
			return
		if not _times.has(_shown):
			_times[_shown] = GameState.clock_text()
		_list.add_child(_bubble(PcStyle.clean(Loc.pick(h.get("texto", {}))), mine, str(_times[_shown]), h))
		_shown += 1
		changed = true
	if changed:
		_mark_read()
		_rebuild_quick()
		_scroll_down()


func _scroll_down() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _mark_read() -> void:
	for b in _list.get_children():
		if b.has_meta("tick"):
			(b.get_meta("tick") as Label).text = "✓✓ " + tr("IA_CHAT_READ")
			(b.get_meta("tick") as Label).add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))


func _bubble(text: String, mine: bool, hora: String, h: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var p := PanelContainer.new()
	var col := Color(0.13, 0.33, 0.27) if mine else Color(0.16, 0.19, 0.25)
	var sb := PcStyle.box(col, Color(0, 0, 0, 0), 7.0, 10)
	if mine:
		sb.corner_radius_bottom_right = 2
	else:
		sb.corner_radius_bottom_left = 2
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var l := PcStyle.label(text, PcStyle.F_SMALL, PcStyle.TEXT)
	l.custom_minimum_size = Vector2(minf(360.0, 40.0 + 8.5 * float(text.length())), 0)
	v.add_child(l)
	var meta := HBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_END
	meta.add_theme_constant_override("separation", 6)
	if bool(h.get("fuera", false)) == false and h.has("opcion") and Difficulty.flag("pistas_trampas"):
		meta.add_child(PcStyle.label("≈ " + PcStyle.clean(Loc.pick(h["opcion"])).left(40), PcStyle.F_TINY, PcStyle.DIM, false))
	if str(h.get("fuente", "")) == "voz":
		meta.add_child(PcStyle.label("🎙", PcStyle.F_TINY, PcStyle.DIM, false))
	meta.add_child(PcStyle.label(hora, PcStyle.F_TINY, PcStyle.DIM, false))
	if mine:
		var tick := PcStyle.label("✓ " + tr("IA_CHAT_SENT"), PcStyle.F_TINY, PcStyle.DIM, false)
		meta.add_child(tick)
		row.set_meta("tick", tick)
	v.add_child(meta)
	row.add_child(p)
	return row


func _typing_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", PcStyle.box(Color(0.16, 0.19, 0.25), Color(0, 0, 0, 0), 7.0, 10))
	_typing_label = PcStyle.label("●", PcStyle.F_SMALL, PcStyle.DIM, false)
	_typing_label.custom_minimum_size = Vector2(46, 0)
	p.add_child(_typing_label)
	row.add_child(p)
	return row


func quick_visible() -> bool:
	return _quick.visible and _quick.get_child_count() > 0


func _rebuild_quick() -> void:
	PcStyle.clear(_quick)
	var allowed := ContactManager.presets_allowed()
	var mic := call_mode and IASpeech.mic_mode() and not _force_quick
	_quick_title.visible = false  # la fila de botones se explica sola; el alto va a la conversación
	_quick.visible = allowed and not mic
	if not allowed:
		_note.text = tr("IA_CHAT_NO_PRESETS")
		_note.visible = true
	if cm == null or cm.tree == null or cm.tree.ended() or cm.tree.waiting_action() or not _quick.visible:
		return
	var opts := cm.tree.options()
	for i in opts.size():
		var idx := i
		var o: Dictionary = opts[i]
		var txt := "%d · %s" % [i + 1, PcStyle.clean(Loc.pick(o))]
		if Difficulty.flag("pistas_trampas") and (o.has("qa") or str(o.get("accion", "")).begins_with("correo")):
			txt += "   " + tr("P4_HINT_SURE")
		var b := PcStyle.button(txt, func() -> void:
			_force_quick = false
			cm.choose(idx), PcStyle.F_TINY, Color(0.12, 0.2, 0.27))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(240, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_quick.add_child(b)

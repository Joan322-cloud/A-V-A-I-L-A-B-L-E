class_name PcKardex
extends VBoxContainer
## App Kardex: (a) en una llamada/chat muestra la conversación del árbol — línea del cliente, opciones
## numeradas (1-4 o clic), ánimo cualitativo (tranquilo / tenso / a punto de colgar), tiempo y la operación
## con su nota interna; (b) en un caso de BO es el buscador de transacciones (clic en el KP del caso o
## escribir el número) con partner pagador, monto, fecha, estado y notas internas.
## v0.3.1 Q4 (F16): en un caso de correo, el número, el monto y la fecha son enlaces: un clic los copia en el campo
## activo del Correo (ContactManager.copy_to_active_field). Debajo salen las operaciones parecidas del mismo
## cliente (las mismas que confunden en las listas del correo): hay que copiar las de la operación correcta.

var cm: ContactManager = null
var _head: Label = null
var _meta: RichTextLabel = null
var _conv: RichTextLabel = null
var _opts: VBoxContainer = null
var _search_row: HBoxContainer = null
var _search: LineEdit = null
var _result: RichTextLabel = null
var _footer: Label = null
var _sig: String = ""
var _last_lookup: String = ""
## v0.3.2 IA: chat con burbujas (contactos de chat) y panel de micrófono/texto (llamadas)
var chat: PcIAChat = null
var call_panel: PcIACall = null
var _chat_hold: float = 0.0  # tras el final de un chat, la conversación se sigue viendo un momento


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_head = PcStyle.label("", PcStyle.F_BODY, PcStyle.TEXT, false)
	add_child(_head)
	_meta = _rich(PcStyle.F_SMALL)
	_meta.fit_content = true
	add_child(_meta)
	add_child(PcStyle.hsep())
	_conv = _rich(PcStyle.F_BODY)
	_conv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_conv.scroll_following = true
	_conv.meta_clicked.connect(_on_conv_meta)
	add_child(_conv)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 3)
	_opts.set_meta("guia", "kardex:opciones")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	add_child(_opts)
	chat = PcIAChat.new()
	chat.name = "ChatCliente"
	chat.visible = false
	add_child(chat)
	call_panel = PcIACall.new()
	call_panel.name = "LlamadaIA"
	call_panel.visible = false
	call_panel.fallback_changed.connect(func(_on: bool) -> void: _sig = "")
	add_child(call_panel)
	_search_row = HBoxContainer.new()
	_search_row.set_meta("guia", "kardex:buscar")
	add_child(_search_row)
	_search_row.add_child(PcStyle.label(tr("P4_KARDEX_SEARCH"), PcStyle.F_SMALL, PcStyle.DIM, false))
	_search = LineEdit.new()
	_search.placeholder_text = "KP-0000-0000"
	_search.custom_minimum_size = Vector2(190, 0)
	_search.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	# v0.3.2: al buscar con [Intro] el campo suelta el foco: si se lo queda, F1-F5, [Espacio] (aceptar / Ack) y
	# [Retroceso] siguen escribiendo en el buscador en vez de hacer lo suyo.
	_search.text_submitted.connect(func(t: String) -> void:
		_lookup(t)
		_search.release_focus())
	_search.focus_entered.connect(func() -> void: GameState.flags["pc_text_focus"] = true)
	_search.focus_exited.connect(func() -> void: GameState.flags["pc_text_focus"] = false)
	_search_row.add_child(_search)
	_search_row.add_child(PcStyle.button(tr("P4_SEARCH"), func() -> void: _lookup(_search.text)))
	_result = _rich(PcStyle.F_SMALL)
	_result.fit_content = true
	_result.meta_clicked.connect(_on_result_meta)
	_result.set_meta("guia", "kardex:resultado")
	add_child(_result)
	_footer = PcStyle.label("", PcStyle.F_TINY, PcStyle.DIM)
	add_child(_footer)


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.meta_underlined = true
	return r


func _lookup(id: String) -> void:
	_last_lookup = id.strip_edges().to_upper()
	_search.text = _last_lookup
	if cm != null:
		cm.kardex_lookup(_last_lookup)
	_sig = ""  # fuerza redibujar


func refresh(_delta: float) -> void:
	if cm == null:
		return
	_ia_refresh(_delta)
	var sig := _signature()
	if sig == _sig:
		_update_live()
		return
	_sig = sig
	PcStyle.clear(_opts)
	_conv.clear()
	_result.clear()
	_meta.clear()
	var c := cm.current
	if cm.phase != ContactManager.Phase.ACTIVE:
		_copied = ""
		_head.text = tr("KARDEX_TITLE")
		_conv.append_text("[color=#5a6670]%s[/color]\n\n" % tr("KARDEX_NO_CASE"))
		_conv.append_text(tr("P4_KARDEX_IDLE"))
		_search_row.visible = true
		_show_lookup(_last_lookup)
		_update_live()
		return
	var canal := str(c.get("canal", ""))
	_head.text = "%s %s · %s" % [tr("KARDEX_CASE"), str(c.get("id", "")), _canal_name(canal)]
	var caso := PcStyle.clean(Loc.pick(c.get("caso", c.get("asunto", {}))))
	_meta.append_text("[color=#9fb0bb]%s[/color]" % caso)
	var cadena: Dictionary = c.get("cadena", {})
	if not cadena.is_empty():
		_meta.append_text("\n[color=#edc245]%s[/color]" % Loc.fmt(tr("KARDEX_CHAIN"), {"n": int(cadena.get("paso", 1)), "total": int(cadena.get("total", 3))}))
	if cm.tree != null:
		_search_row.visible = c.has("portal")
		_draw_tree()
		if c.has("portal"):
			_show_lookup(_last_lookup if _last_lookup != "" else "")
	else:
		_search_row.visible = true
		_conv.append_text(tr("P4_KARDEX_CASE_HINT") + "\n")
		var tx := str(c.get("tx", ""))
		if tx != "":
			_conv.append_text("%s: [url=%s][b]%s[/b][/url]\n" % [tr("P4_KARDEX_TX"), tx, tx])
		_show_lookup(tx if cm.case != null and cm.case.kardex_done else _last_lookup)
	_update_live()


## v0.3.2 IA: qué vista de conversación toca (chat con burbujas / llamada con micrófono y texto).
func _ia_refresh(delta: float) -> void:
	if chat.cm == null:
		chat.cm = cm
		call_panel.cm = cm
	var active := cm.phase == ContactManager.Phase.ACTIVE and cm.tree != null
	var canal := str(cm.current.get("canal", "")) if active else ""
	if active and canal == "chat":
		_chat_hold = 3.5
	elif cm.phase == ContactManager.Phase.ACTIVE:
		# v0.3.2 (bot de correos por la interfaz, T3): otro contacto (llamada o caso de BO) ya no deja a la vista el chat
		# que terminó. La cuenta solo baja mientras Kardex es la app abierta: si cambiabas de app al colgar el chat, al
		# volver a Kardex con un correo el chat viejo tapaba el caso (y su KP) hasta 3,5 s.
		_chat_hold = 0.0
	elif _chat_hold > 0.0:
		_chat_hold -= delta
	var show_chat := (active and canal == "chat") or (not active and _chat_hold > 0.0 and chat.visible)
	chat.visible = show_chat
	_head.visible = not show_chat  # en el chat el título va en la cabecera de la conversación (más alto para las burbujas)
	_conv.visible = not show_chat
	_opts.visible = not show_chat
	call_panel.visible = active and canal == "llamada"
	if show_chat:
		chat.refresh(delta)
	if call_panel.visible:
		call_panel.refresh(delta)
	else:
		GameState.flags["ia_llamada_activa"] = false


## ¿Se ven las respuestas predefinidas de la llamada? (Difícil: nunca; micrófono: solo si falló en este turno)
func _call_presets_visible() -> bool:
	if not ContactManager.presets_allowed():
		return false
	if IASpeech.mic_mode() and not call_panel.fallback:
		return false
	return true


func _on_conv_meta(m: Variant) -> void:
	_lookup(str(m))


## Enlaces del resultado: "copiar:<campo>:<valor>" copia el valor a SU campo del correo; lo demás es otra búsqueda.
func _on_result_meta(m: Variant) -> void:
	var s := str(m)
	if s.begins_with("copiar:"):
		var rest := s.trim_prefix("copiar:")
		var f := rest.get_slice(":", 0)
		if f in CasoBO.FIELDS:
			copy_value(rest.substr(f.length() + 1), f)
		else:
			copy_value(rest)
	else:
		_lookup(s)


var _copied: String = ""


## Copia un valor de Kardex a su campo del correo (pruebas y bot humano lo llaman igual que el clic). `field` = la
## columna de la que sale; "" = se deduce del valor (ContactManager.field_of_value).
func copy_value(v: String, field: String = "") -> bool:
	if cm == null:
		return false
	var ok := cm.copy_to_field(field, v)
	if ok:
		_copied = Loc.fmt(tr("Q4_KARDEX_COPIED"), {"valor": v, "campo": tr("P4_FIELD_" + cm.last_copied_field.to_upper())})
	return ok


func _copy_link(v: String, field: String = "") -> String:
	if cm == null or cm.case == null or cm.case.is_kyc() or not cm.case.kardex_done:
		return "[b]%s[/b]" % v
	return "[url=copiar:%s:%s][b]%s[/b][/url]" % [field, v, v]


## Operaciones parecidas del mismo cliente (los distractores de opciones_campos, en filas).
func _related_rows(tx: String) -> Array:
	var opts: Dictionary = cm.current.get("opciones_campos", {}) if cm != null else {}
	if opts.is_empty():
		return []
	var info: Dictionary = (DataLoader.dict("casos_bo").get("transacciones", {}) as Dictionary).get(tx, {})
	var ids: Array = (opts.get("id", []) as Array).filter(func(v: Variant) -> bool: return str(v) != tx)
	var montos: Array = (opts.get("monto", []) as Array).filter(func(v: Variant) -> bool: return str(v) != str(info.get("monto", "")))
	var fechas: Array = (opts.get("fecha", []) as Array).filter(func(v: Variant) -> bool: return str(v) != str(info.get("fecha", "")))
	var rows: Array = []
	for i in ids.size():
		rows.append({"id": str(ids[i]), "monto": str(montos[i % maxi(montos.size(), 1)]) if not montos.is_empty() else "", "fecha": str(fechas[(i + 1) % maxi(fechas.size(), 1)]) if not fechas.is_empty() else ""})
	return rows


func _canal_name(canal: String) -> String:
	match canal:
		"llamada": return tr("P4_CANAL_LLAMADA")
		"chat": return tr("P4_CANAL_CHAT")
		"correo": return tr("P4_CANAL_CORREO")
		"kyc": return "KYC"
	return canal


func _signature() -> String:
	var s := "%d|%s" % [cm.phase, str(cm.current.get("id", ""))]
	if cm.tree != null:
		s += "|%s|%s|%d|%s|%d" % [cm.tree.node_id, cm.tree.final_id, cm.tree.history.size(), cm.tree.pending_action(), int(cm.on_hold)]
		s += "|f%d" % int(Fatigue.value / 10.0)
	if cm.case != null:
		s += "|%s|%s" % [str(cm.case.kardex_done), cm.mail_active_field]
	s += "|" + _last_lookup + "|" + str(cm.composer.is_empty())
	s += "|ia%d%d" % [int(call_panel.fallback), int(IASpeech.mic_mode())]
	return s


func _draw_tree() -> void:
	var t := cm.tree
	var seed := hash(str(cm.current.get("id", "")))
	var hist := t.history
	var start := maxi(0, hist.size() - 7)
	for i in range(start, hist.size()):
		var h: Dictionary = hist[i]
		var txt := PcStyle.clean(Loc.pick(h.get("texto", {}))).replace("\n", "\n   ")
		if str(h.get("quien", "")) == "cliente":
			var line := PcStyle.haunt(txt, seed + i) if i == hist.size() - 1 else txt
			var col := "#e8e0d0" if Fatigue.value < 70.0 else "#c9a8a0"
			_conv.append_text("[color=#8fa8c8]%s:[/color] [color=%s]%s[/color]\n" % [tr("KARDEX_CLIENT"), col, line])
		else:
			_conv.append_text("[color=#6f8090]%s: %s[/color]\n" % [GameState.agent, txt])
	if t.waiting_action():
		var a := t.pending_action()
		var key := "P4_WAIT_PORTAL" if a.begins_with("portal") else "P4_WAIT_CORREO"
		_conv.append_text("\n[color=#edc245]» %s[/color]\n" % tr(key))
		return
	if not _call_presets_visible():
		var why := tr("IA_CHAT_NO_PRESETS") if not ContactManager.presets_allowed() else Loc.fmt(tr("IA_MIC_HOLD"), {"tecla": call_panel._key_name()})
		_conv.append_text("\n[color=#6f8090][i]%s[/i][/color]\n" % why)
		return
	var opts := t.options()
	var hints := Difficulty.flag("pistas_trampas")
	for i in opts.size():
		var o: Dictionary = opts[i]
		var idx := i
		var txt := "%d · %s" % [i + 1, PcStyle.clean(Loc.pick(o))]
		if hints and (o.has("qa") or str(o.get("accion", "")).begins_with("correo")):
			txt += "   " + tr("P4_HINT_SURE")
		var b := PcStyle.button(txt, func() -> void: cm.choose(idx), PcStyle.F_BODY)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 30)
		_opts.add_child(b)


func _show_lookup(tx: String) -> void:
	if tx == "":
		return
	var info: Dictionary = (DataLoader.dict("casos_bo").get("transacciones", {}) as Dictionary).get(tx, {})
	if info.is_empty():
		_result.append_text("[color=#e5241f]%s[/color]" % Loc.fmt(tr("P4_KARDEX_NOT_FOUND"), {"tx": tx}))
		return
	_result.append_text("%s  ·  %s: [b]%s[/b]  ·  %s: %s  ·  %s: %s\n" % [_copy_link(tx, "id"), tr("P4_KARDEX_PARTNER"), str(info.get("partner", "")), tr("P4_KARDEX_AMOUNT"), _copy_link(str(info.get("monto", "")), "monto"), tr("P4_KARDEX_DATE"), _copy_link(str(info.get("fecha", "")), "fecha")])
	_result.append_text("%s: %s  ·  %s: %s\n" % [tr("P4_KARDEX_STATE"), Loc.pick(info.get("estado", {})), tr("P4_KARDEX_BENEF"), str(info.get("beneficiario", ""))])
	if info.has("nota"):
		_result.append_text("[color=#c9b27a][i]%s[/i][/color]\n" % PcStyle.clean(Loc.pick(info.get("nota", {}))))
	if cm != null and cm.case != null and not cm.case.is_kyc() and cm.case.kardex_done and tx == cm.case.tx():
		var rows := _related_rows(tx)
		if not rows.is_empty():
			_result.append_text("[color=#6f8090]%s[/color]\n" % tr("Q4_KARDEX_RELATED"))
			for r in rows:
				_result.append_text("[color=#8a96a0]%s  ·  %s  ·  %s[/color]\n" % [_copy_link(str(r["id"]), "id"), _copy_link(str(r["monto"]), "monto"), _copy_link(str(r["fecha"]), "fecha")])


func _update_live() -> void:
	if cm.phase == ContactManager.Phase.ACTIVE and cm.tree != null:
		var mood := cm.tree.mood()
		var mcol := {"tranquilo": "#3fc77a", "tenso": "#edc245", "a_punto": "#e5241f"}.get(mood, "#cccccc") as String
		var el := cm.elapsed()
		var tcol := "#e5241f" if el > 540.0 else ("#edc245" if el > 360.0 else "#9fb0bb")
		var chat := ""
		if str(cm.current.get("canal", "")) == "chat" and cm.current.has("timeout"):
			chat = "  ·  %s %ds" % [tr("P4_CHAT_TIMER"), int(maxf(cm.chat_left, 0.0))]
			if cm.composing():  # v0.3.2 IA: mientras escribes, el cliente espera
				chat = "  ·  %s" % tr("IA_CHAT_COMPOSING")
		_footer.text = ""
		_meta.clear()
		_meta.append_text("[color=#9fb0bb]%s[/color]\n" % PcStyle.clean(Loc.pick(cm.current.get("caso", {}))))
		_meta.append_text("%s: [color=%s][b]%s[/b][/color]  ·  [color=%s]%s %s[/color]%s%s" % [tr("P4_MOOD"), mcol, tr("P4_MOOD_" + mood.to_upper()), tcol, tr("KARDEX_AHT"), Loc.mmss(el), chat, ("  ·  [color=#edc245]" + tr("FONEX_ON_HOLD") + "[/color]") if cm.on_hold else ""])
	elif cm.phase == ContactManager.Phase.ACTIVE and cm.case != null:
		_footer.text = "%s %s%s" % [tr("KARDEX_EMAIL_TIMER"), Loc.mmss(maxf(cm.email_elapsed, 0.0)), ("   ·   " + _copied) if _copied != "" else ""]
		_footer.add_theme_color_override("font_color", PcFonex._timer_color(cm.case_timer_color()))
	else:
		_footer.text = ""

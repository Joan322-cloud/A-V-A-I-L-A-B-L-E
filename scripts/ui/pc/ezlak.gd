class_name PcEzlak
extends PanelContainer
## App Ezlaki (pantalla derecha y terminales): barra lateral con #allocations, #site-updates, #team-familia,
## DM de Shero, los 2-3 DMs del agente y los DMs que aparecen al primer mensaje (Trainer, Haime, Rasec, tópico),
## con insignias de no leídos y menciones; mensajes con avatar, "(editado)", "Este mensaje fue eliminado.",
## "escribiendo…", reacciones (clic o [Enter]), respuestas rápidas y la invitación a Ezlaki Rooms.
## v0.3.1 Q3 (B6): las respuestas rápidas se ven enteras (botones que bajan de línea, sin cortar) con vista previa al
## pasar el ratón; campo «Escribir…» para responder con tus palabras (EzlakHub.typed_reply); capturas de la vista de
## adherencia en #allocations (clic = verla grande) y reacciones de los compañeros con las caras del site.
## Datos: EzlakHub. Clic en un canal = abrirlo (marca leído).
## v0.3.2 (Joan: «que los chats no se abran solos cuando llegan mensajes… yo los abro manualmente»): NINGÚN chat se
## abre ni cambia solo (ni DM ni canal, ni el WW de Shero ni [Enter]). Lo nuevo se marca en la barra lateral: fila en
## negrita y resaltada con la insignia de no leídos (roja en DMs y menciones), un aviso breve arriba («Nuevo DM de
## Shero · 2») y el sonido de siempre. Solo el jugador abre un chat (clic): eso pone el contador en 0.

## v0.3.2 IA: estado de presencia de cada DM (punto de color + texto: activo, en llamada, en lunch, pausó sus
## notificaciones, ausente; IABrain.presence), pared de reacciones del aviso de coaching (contador, «SOLO FALTAS TÚ»,
## cuenta atrás, «ver quién reaccionó») y selector de emojis con clic o [Enter] ← → [Enter].

var hub: EzlakHub = null
var current: String = "#team-familia"
var _side: VBoxContainer = null
var _title: Label = null
var _topic: Label = null
var _log: RichTextLabel = null
var _typing: Label = null
var _replies: HFlowContainer = null
var _preview: Label = null
var input: LineEdit = null
var _send: Button = null
var _zoom: PanelContainer = null
var _zoom_tex: TextureRect = null
var shot_zoomed: int = -1  # pruebas: id del mensaje cuya captura está ampliada
var _side_buttons: Dictionary = {}
var _dirty: bool = true
var _dirty_side: bool = true
var _typing_t: float = 0.0
var auto_follow: bool = false  # v0.3.2: ya no se usa (nada abre un chat solo); queda por compatibilidad
var _toast_lbl: Label = null
var _topic_text: String = ""
var toast_left: float = 0.0
var toast_text: String = ""
var _bold: FontVariation = null
var _react_banner: Button = null
var _pin_box: PanelContainer = null
var _pin: RichTextLabel = null
var _pin_id: int = -1  # aviso fijado arriba (el que espera tu reacción; se queda unos segundos después de reaccionar)
var _pin_hold: float = 0.0
var _pres_sig: String = ""
var _pres_t: float = 0.0
var _last_other_id: int = -1  # último mensaje de otro en el chat abierto (lleva el «+ reaccionar»)
var wall_open: int = -1  # id del aviso con la lista «quién reaccionó» desplegada
static var _dots: Dictionary = {}


func _init() -> void:
	add_theme_stylebox_override("panel", PcStyle.box(Color(0.075, 0.08, 0.1), PcStyle.BORDER, 0.0))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	add_child(hb)
	var side_panel := PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", PcStyle.box(Color(0.1, 0.07, 0.12), Color(0, 0, 0, 0), 4.0, 0))
	side_panel.custom_minimum_size = Vector2(208, 0)
	hb.add_child(side_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 1)
	side_panel.add_child(sv)
	var brand := PcStyle.label("Ezlaki · Konzentramance", PcStyle.F_TINY, PcStyle.DIM, false)
	sv.add_child(brand)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 1)
	_side.set_meta("guia", "ezlak:lista")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	sv.add_child(_side)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 2)
	var mm := MarginContainer.new()
	mm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mm.add_theme_constant_override(k, 6)
	mm.add_child(main)
	hb.add_child(mm)
	var head := HBoxContainer.new()
	main.add_child(head)
	_title = PcStyle.label("", PcStyle.F_BODY, PcStyle.TEXT, false)
	head.add_child(_title)
	_topic = PcStyle.label("", PcStyle.F_TINY, PcStyle.DIM, false)
	_topic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topic.clip_text = true
	_topic.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_topic)
	main.add_child(PcStyle.hsep())
	# v0.3.2 IA: el aviso que espera tu reacción queda FIJADO arriba del chat (los mensajes nuevos no se lo llevan):
	# emojis con contador, «Reaccionaron 9 de 12 · SOLO FALTAS TÚ · 0:12», el selector y la lista de quién reaccionó.
	_pin_box = PanelContainer.new()
	_pin_box.name = "AvisoFijado"
	_pin_box.set_meta("guia", "ezlak:fijado")
	_pin_box.visible = false
	_pin_box.add_theme_stylebox_override("panel", PcStyle.box(Color(0.13, 0.11, 0.05), PcStyle.YELLOW.darkened(0.25), 5.0, 3))
	main.add_child(_pin_box)
	_pin = RichTextLabel.new()
	_pin.bbcode_enabled = true
	_pin.fit_content = true
	_pin.scroll_active = false
	_pin.add_theme_font_size_override("normal_font_size", PcStyle.F_SMALL)
	_pin.add_theme_font_size_override("bold_font_size", PcStyle.F_SMALL)
	_pin.add_theme_font_size_override("italics_font_size", PcStyle.F_SMALL)
	_pin.meta_clicked.connect(_on_meta)
	_pin.meta_underlined = true
	_pin_box.add_child(_pin)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", PcStyle.F_SMALL)
	_log.add_theme_font_size_override("bold_font_size", PcStyle.F_SMALL)
	_log.add_theme_font_size_override("italics_font_size", PcStyle.F_SMALL)
	_log.meta_clicked.connect(_on_meta)
	_log.meta_underlined = true
	main.add_child(_log)
	# v0.3.2 IA: aviso fijo mientras Shero espera tu reacción (se ve en cualquier chat; clic = abrir el selector)
	_react_banner = PcStyle.button("", func() -> void: open_picker(), PcStyle.F_SMALL, Color(0.36, 0.26, 0.05))
	_react_banner.name = "AvisoReaccion"
	_react_banner.set_meta("guia", "ezlak:reaccion")
	_react_banner.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_react_banner.clip_text = true
	_react_banner.visible = false
	main.add_child(_react_banner)
	_typing = PcStyle.label("", PcStyle.F_TINY, PcStyle.DIM, false)
	main.add_child(_typing)
	_preview = PcStyle.label("", PcStyle.F_TINY, PcStyle.YELLOW, true)
	_preview.visible = false
	main.add_child(_preview)
	_replies = HFlowContainer.new()
	_replies.add_theme_constant_override("h_separation", 4)
	_replies.add_theme_constant_override("v_separation", 3)
	_replies.set_meta("guia", "ezlak:respuestas")
	main.add_child(_replies)
	var ib := HBoxContainer.new()
	ib.add_theme_constant_override("separation", 4)
	main.add_child(ib)
	input = LineEdit.new()
	input.name = "Escribir"
	input.set_meta("guia", "ezlak:escribir")
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = 160
	input.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	input.add_theme_stylebox_override("normal", PcStyle.box(Color(0.05, 0.055, 0.07), PcStyle.BORDER, 4, 3))
	input.add_theme_stylebox_override("focus", PcStyle.box(Color(0.06, 0.07, 0.09), PcStyle.ACCENT, 4, 3))
	input.text_submitted.connect(func(_t: String) -> void: submit_typed())
	input.focus_entered.connect(func() -> void: GameState.flags["pc_text_focus"] = true)
	input.focus_exited.connect(func() -> void: GameState.flags["pc_text_focus"] = false)
	ib.add_child(input)
	_send = PcStyle.button(tr("EZLAKI_SEND"), submit_typed, PcStyle.F_SMALL, PcStyle.PANEL_HI)
	ib.add_child(_send)
	# captura ampliada (encima de todo el panel)
	_zoom = PanelContainer.new()
	_zoom.name = "CapturaAmpliada"
	_zoom.visible = false
	_zoom.add_theme_stylebox_override("panel", PcStyle.box(Color(0, 0, 0, 0.88), Color(0, 0, 0, 0), 10, 0))
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom.mouse_filter = Control.MOUSE_FILTER_STOP
	var zv := VBoxContainer.new()
	_zoom.add_child(zv)
	_zoom_tex = TextureRect.new()
	_zoom_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zoom_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zoom_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zoom_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zv.add_child(_zoom_tex)
	var zl := PcStyle.label(tr("EZLAKI_SHOT_CLOSE"), PcStyle.F_TINY, PcStyle.DIM, false)
	zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zl)
	_zoom.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_shot())
	add_child(_zoom)
	# v0.3.2: el aviso breve de mensaje nuevo va en la cabecera, en el lugar del tema del canal (no tapa mensajes).
	_toast_lbl = _topic


func bind(h: EzlakHub) -> void:
	hub = h
	if hub.captura != null:
		hub.captura.ready_shot.connect(func(_id: int) -> void: _dirty = true)
	hub.updated.connect(func(ch: String) -> void:
		if ch == "" or ch == current:
			_dirty = true
		_dirty_side = true)
	hub.posted.connect(_on_posted)
	hub.typing_changed.connect(func(_c: String, _a: String, _on: bool) -> void: _dirty_side = true)
	hub.reaction_alone.connect(func(m: Dictionary) -> void:
		if str(m.get("canal", "")) != current:
			show_toast(Loc.fmt(tr("IA_REACT_ALONE_TOAST"), {"canal": hub.channel_title(str(m.get("canal", "")))}), 5.0))
	_dirty = true


func _on_posted(ch: String, m: Dictionary) -> void:
	# v0.3.2: nunca se cambia de chat. Lo que llega a otro chat se avisa (fila resaltada + insignia + aviso breve).
	_dirty_side = true
	if ch == current:
		_dirty = true
		return
	if str(m.get("autor", "")) == "yo" or hub == null:
		return
	var meta: Dictionary = m.get("meta", {})
	if bool(meta.get("silent", false)):
		return
	var unread := int((hub.channels.get(ch, {}) as Dictionary).get("unread", 0))
	var who := str(hub.author_info(str(m.get("autor", ""))).get("nombre", m.get("autor", "")))
	if ch.begins_with("dm:"):
		show_toast(Loc.fmt(tr("B2_EZLAKI_TOAST_DM"), {"quien": who, "n": unread}))
	elif bool(m.get("mention", false)) or str(m.get("reaccion", "")) != "":
		show_toast(Loc.fmt(tr("B2_EZLAKI_TOAST_MENTION"), {"canal": hub.channel_title(ch), "quien": who, "n": unread}))


## Aviso breve arriba a la derecha del panel (3,5 s). No toca el chat abierto ni el foco.
func show_toast(text: String, seconds: float = 3.5) -> void:
	toast_text = text
	toast_left = seconds
	if _toast_lbl != null:
		_toast_lbl.text = "● " + text
		_toast_lbl.add_theme_color_override("font_color", PcStyle.RED.lightened(0.35))


## Insignias de no leídos por fila (pruebas y capturas): {id: n}.
func unread_badges() -> Dictionary:
	var out := {}
	for id in _side_buttons.keys():
		out[id] = int((_side_buttons[id] as Control).get_meta("unread", 0))
	return out


func open_channel(id: String) -> void:
	if id != current and input != null:
		input.text = ""
		close_shot()
	current = id
	_dirty = true
	_dirty_side = true
	_pres_t = 0.0
	if toast_left > 0.0:  # abriste un chat: el aviso breve ya cumplió y la cabecera vuelve a decir de quién es (y su estado)
		toast_left = 0.0
		_topic.add_theme_color_override("font_color", PcStyle.DIM)
	_pres_sig = ""
	if hub != null and looking:
		hub.mark_read(id)


var looking: bool = false  # el jugador está mirando la pantalla (vista acercada o terminal)


func refresh(delta: float, p_looking: bool = false) -> void:
	if hub == null:
		return
	looking = p_looking
	_typing_t += delta
	if toast_left > 0.0:
		toast_left -= delta
		if toast_left <= 0.0 and _topic != null:
			_topic.add_theme_color_override("font_color", PcStyle.DIM)
			_refresh_topic()
	if looking and int((hub.channels.get(current, {}) as Dictionary).get("unread", 0)) > 0:
		hub.mark_read(current)
	_pres_t -= delta
	if _pres_t <= 0.0:  # los estados salen del juego (no hay señal): se miran dos veces por segundo
		_pres_t = 0.5
		var sig := presence_signature()
		if sig != _pres_sig:
			_pres_sig = sig
			_dirty_side = true
			_refresh_topic()
	_refresh_banner()
	if not hub.reaction_pending.is_empty():
		if _pin_id != int(hub.reaction_pending.get("id", -1)):
			_pin_id = int(hub.reaction_pending.get("id", -1))
			_dirty = true
		_pin_hold = 8.0
	elif _pin_hold > 0.0:
		_pin_hold -= delta
		if _pin_hold <= 0.0:
			_dirty = true
	if _dirty_side:
		_dirty_side = false
		_rebuild_side()
	if _dirty:
		_dirty = false
		_rebuild_log()
	var who := str(hub.typing_now.get(current, ""))
	if who != "":
		var dots := ".".repeat(1 + int(_typing_t * 3.0) % 3)
		_typing.text = Loc.fmt(tr("P4_EZLAK_TYPING"), {"quien": str(hub.author_info(who).get("nombre", who))}) + dots
		_typing.add_theme_color_override("font_color", PcStyle.YELLOW if who == "shero" else PcStyle.DIM)
	else:
		_typing.text = ""
	if hub.rooms_pending and current == "dm:" + hub.rooms_from:
		_typing.text = "%s  %s" % [tr("EZLAK_ROOMS_TITLE"), Loc.mmss(hub.rooms_left)]
		_typing.add_theme_color_override("font_color", PcStyle.RED)


func _rebuild_side() -> void:
	PcStyle.clear(_side)
	_side_buttons.clear()
	var groups := [["#allocations", "#site-updates", "#team-familia"], []]
	for id in hub.order:
		if str(id).begins_with("dm:"):
			groups[1].append(id)
	for gi in groups.size():
		_side.add_child(PcStyle.label(tr("P4_EZLAK_CHANNELS") if gi == 0 else tr("P4_EZLAK_DMS"), PcStyle.F_TINY, PcStyle.DIM, false))
		for id in groups[gi]:
			var ch: Dictionary = hub.channels.get(id, {})
			var unread := int(ch.get("unread", 0))
			var mention := bool(ch.get("mention", false))
			var name := hub.channel_title(str(id))
			if hub.typing_now.has(id):
				name += " …"
			var hot := mention or str(id).begins_with("dm:")
			var col := PcStyle.PANEL_HI if str(id) == current else Color(0.1, 0.07, 0.12)
			if unread > 0 and str(id) != current:
				col = Color(0.3, 0.09, 0.11) if hot else Color(0.2, 0.15, 0.27)  # fila resaltada
			var b := PcStyle.button(name, func() -> void: open_channel(str(id)), PcStyle.F_SMALL, col)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.set_meta("unread", unread)
			b.set_meta("guia", "ezlak:canal:" + str(id))
			if str(id).begins_with("dm:"):  # v0.3.2 IA: estado de presencia (punto de color + texto corto)
				var pres: Dictionary = IABrain.presence(str(id).substr(3))
				b.icon = dot(str(pres["estado"]))
				b.add_theme_constant_override("icon_max_width", 12)
				b.set_meta("estado", str(pres["estado"]))
				b.tooltip_text = "%s · %s" % [name, str(pres["texto"])]
				if unread <= 0:
					var sl := PcStyle.label(str(pres["corto"]), PcStyle.F_TINY - 1, Color(str(pres["color"])).lerp(PcStyle.DIM, 0.35), false)
					sl.name = "Estado"
					sl.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
					sl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
					sl.grow_vertical = Control.GROW_DIRECTION_BOTH
					sl.offset_right = -5
					b.add_child(sl)
			b.add_theme_color_override("font_color", Color(1, 1, 1) if unread > 0 else (PcStyle.TEXT if str(id) == current else PcStyle.DIM))
			if unread > 0:
				b.add_theme_font_override("font", _bold_font(b))
				b.add_theme_constant_override("outline_size", 0)
				var badge := PanelContainer.new()
				badge.name = "Insignia"
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge.add_theme_stylebox_override("panel", PcStyle.box(PcStyle.RED if hot else PcStyle.ACCENT.darkened(0.15), Color(0, 0, 0, 0), 2, 8))
				var bl := PcStyle.label(str(unread) if unread < 100 else "99+", PcStyle.F_TINY, Color(1, 1, 1), false)
				bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bl.custom_minimum_size = Vector2(18, 0)
				badge.add_child(bl)
				badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
				badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				badge.grow_vertical = Control.GROW_DIRECTION_BOTH
				badge.offset_right = -5
				b.add_child(badge)
				b.add_theme_constant_override("h_separation", 4)
				var pad := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
				if pad != null:
					pad.content_margin_right = 32  # el nombre no pasa por debajo de la insignia
					b.add_theme_stylebox_override("normal", pad)
			_side.add_child(b)
			_side_buttons[id] = b


## Fuente en negrita (la del tema con embolden) para las filas con no leídos.
func _bold_font(c: Control) -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = c.get_theme_font("font")
		_bold.variation_embolden = 0.85
	return _bold


func _rebuild_log() -> void:
	_log.clear()
	_title.text = hub.channel_title(current)
	var tema := ""
	for c in DataLoader.dict("ezlak_canales").get("canales", []):
		if str(c.get("id", "")) == current:
			tema = Loc.pick(c.get("tema", {}))
	_topic_text = tema
	_refresh_topic()
	if input != null:
		input.placeholder_text = Loc.fmt(tr("EZLAKI_WRITE"), {"canal": hub.channel_title(current)})
	var msgs := hub.messages(current)
	if msgs.is_empty():
		_log.append_text("[color=#5a6670]%s[/color]" % tr("P4_EZLAK_EMPTY"))
	var start := maxi(0, msgs.size() - 40)
	var pinned := _rebuild_pin()
	_last_other_id = -1
	for i in range(msgs.size() - 1, -1, -1):
		if not (str(msgs[i].get("autor", "")) in ["yo", "sistema"]):
			_last_other_id = int(msgs[i].get("id", -1))
			break
	for i in range(start, msgs.size()):
		var m: Dictionary = msgs[i]
		var author := str(m.get("autor", ""))
		var info := hub.author_info(author)
		var av := EzlakHub.avatar(str(info.get("avatar", "")))
		if av != null:
			_log.add_image(av, 22, 22)
			_log.append_text(" ")
		_log.append_text("[b][color=%s]%s[/color][/b] [color=#5a6670]%s[/color]\n" % [str(info.get("color", "#cccccc")), str(info.get("nombre", author)), str(m.get("hora", ""))])
		var body := PcStyle.rich(str(m.get("texto", "")))  # v0.3.2-core: los emojis del mensaje salen como dibujo
		if bool(m.get("borrado", false)):
			body = "[i][color=#5a6670]%s[/color][/i]" % tr("P4_EZLAK_DELETED")
		else:
			body = body.replace("@" + GameState.agent, "[bgcolor=#5a2a10][b]@%s[/b][/bgcolor]" % GameState.agent).replace("@here", "[bgcolor=#5a2a10][b]@here[/b][/bgcolor]")
			if bool(m.get("editado", false)):
				body += " [color=#5a6670](%s)[/color]" % tr("P4_EZLAK_EDITED")
		var tipo := str(m.get("tipo", ""))
		if tipo in ["ww", "verbal", "llamado", "amonestacion"]:
			body = "[color=#ff6a5a]%s[/color]" % body
		_log.append_text(body + "\n")
		if int(m.get("id", -1)) == pinned:
			_log.append_text("[color=#8a7a3a][i]%s[/i][/color]\n" % tr("IA_PIN_ABOVE"))
		else:
			_emoji_row(m, _log)  # v0.3.2 IA: reacciones con emoji (avisos que piden reacción)
		if m.has("visto_por"):  # v0.3.2 IA: te dejaron en visto
			_log.append_text("[color=#5a6670][i]%s[/i][/color]\n" % Loc.fmt(tr("IA_SEEN"), {"hora": str(m.get("visto_hora", ""))}))
		if m.get("captura", null) is Dictionary and not bool(m.get("borrado", false)):
			var tex := hub.captura.texture_for(int(m.get("id", 0)), m["captura"])
			_log.append_text("[color=#5a6670]%s[/color]\n" % tr("EZLAKI_SHOT_FILE"))
			_log.push_meta("shot:%d" % int(m.get("id", 0)))
			_log.add_image(tex, 300)
			_log.pop()
			_log.append_text("\n")
		var reacts: Array = m.get("reacciones", [])
		if not reacts.is_empty():
			for r in reacts:
				var ra := EzlakHub.avatar(str(r[0]))
				_log.append_text("[bgcolor=#1d2630] ")
				if ra != null:
					_log.add_image(ra, 16, 16)
				_log.append_text(" [color=#9fb4c8]%d[/color] [/bgcolor] " % int(r[1]))
			_log.append_text("\n")
		var e := str(m.get("reaccion", ""))
		if e != "" and not bool(m.get("borrado", false)):
			if bool(m.get("reaccionado", false)):
				_log.append_text("[color=#3fc77a]%s %s · %s[/color]\n" % [PcStyle.emoji_label(e), "1", tr("P4_EZLAK_REACTED")])
			elif bool(m.get("reaccion_viva", false)):
				_log.append_text("[url=react:%d][bgcolor=#1f4a2a][color=#9effb8] %s %s [/color][/bgcolor][/url]  [color=#edc245]%s[/color]\n" % [int(m.get("id", 0)), PcStyle.emoji_label(e), tr("P4_EZLAK_REACT"), tr("P4_EZLAK_REACT_HINT")])
		_log.append_text("\n")
	_rebuild_replies()


func _rebuild_replies() -> void:
	PcStyle.clear(_replies)
	var msgs := hub.messages(current)
	var target: Dictionary = {}
	for i in range(msgs.size() - 1, -1, -1):
		var m: Dictionary = msgs[i]
		if str(m.get("autor", "")) == "yo":
			break
		if not (m.get("quick_replies", []) as Array).is_empty() and not bool(m.get("respondido", false)) and not bool(m.get("borrado", false)):
			target = m
			break
	var ids: Array = target.get("quick_replies", []) if not target.is_empty() else []
	if ids.is_empty() and current.begins_with("dm:"):
		ids = hub.quick_replies_for(current)
	var textos: Dictionary = DataLoader.dict("ezlak_canales").get("textos_respuesta", {})
	for id in ids:
		var rid := str(id)
		if rid == "en_un_caso":
			var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
			if cm == null or cm.case == null:
				continue
		if rid == "ack" and not Metrics.ack_pending:
			continue
		var label := _sin_tecla(tr("EZLAK_ROOMS_JOIN")) if rid == "join_rooms" else Loc.pick(textos.get(rid, {"es": rid, "en": rid}))
		var col := Color(0.12, 0.3, 0.2) if rid in ["ack", "join_rooms", "voy"] else PcStyle.PANEL_HI
		var b := PcStyle.button(label, func() -> void: hub.quick_reply(current, rid, target), PcStyle.F_SMALL, col)
		b.clip_text = false  # v0.3.1 Q3 (B6): se ve entera
		b.tooltip_text = label
		if label.length() > 30:  # las excusas largas bajan a 2 líneas en vez de cortarse
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(250, 0)
		b.set_meta("respuesta", rid)
		b.set_meta("guia", "ezlak:respuesta:" + rid)
		b.mouse_entered.connect(func() -> void: show_preview(label))
		b.mouse_exited.connect(func() -> void: show_preview(""))
		_replies.add_child(b)


## Burbuja de vista previa de una respuesta rápida («Vas a responder: …»).
func show_preview(text: String) -> void:
	if _preview == null:
		return
	_preview.visible = text != ""
	_preview.text = Loc.fmt(tr("EZLAKI_PREVIEW"), {"texto": text}) if text != "" else ""


## Envía lo escrito en el campo (Enter o el botón Enviar). Suelta el foco para que las teclas vuelvan al juego.
func submit_typed() -> String:
	if hub == null or input == null:
		return ""
	var txt := input.text.strip_edges()
	input.text = ""
	input.release_focus()
	GameState.flags["pc_text_focus"] = false
	if txt == "":
		return ""
	var intent := hub.typed_reply(current, txt)
	_dirty = true
	return intent


func open_shot(id: int) -> void:
	for m in hub.messages(current):
		if int(m.get("id", -1)) == id and m.get("captura", null) is Dictionary:
			_zoom_tex.texture = hub.captura.texture_for(id, m["captura"])
			_zoom.visible = true
			shot_zoomed = id
			return


func close_shot() -> void:
	if _zoom == null:
		return
	_zoom.visible = false
	shot_zoomed = -1


## v0.3.2 IA: fila de emojis del mensaje (con contador; el tuyo resaltado), la pared del aviso que pide reacción
## («Reaccionaron 9 de 12 · SOLO FALTAS TÚ · 0:31», «ver quién reaccionó») y el selector «+ reaccionar».
var picker_id: int = -1
var picker_sel: int = 1  # emoji elegido con ← → (empieza en ✅)


func _emoji_row(m: Dictionary, out: RichTextLabel) -> void:
	if str(m.get("autor", "")) in ["yo", "sistema"] or bool(m.get("borrado", false)):
		return
	var row := emoji_row_bb(m)
	if row != "":
		out.append_text(row + "\n")
	if m.has("pared"):
		_wall(m, out)
	var pk := picker_bb(m)
	if pk != "":
		out.append_text(pk)


## BBCode de la fila de reacciones de un mensaje: cada emoji (su dibujo) con su contador y «+ reaccionar».
func emoji_row_bb(m: Dictionary) -> String:
	var id := int(m.get("id", 0))
	var row := ""
	for e in m.get("emojis", []):
		var mine := bool(e[2])
		var names: Array = ((e[3] as Array).duplicate() if (e as Array).size() > 3 else [])
		if mine:
			names.append(tr("IA_WALL_YOU"))
		var chip := "[bgcolor=%s] %s %d [/bgcolor]" % ["#2a4a6a" if mine else "#1d2630", PcStyle.emoji_label(str(e[0]), 18, names.is_empty()), int(e[1])]
		row += ("[hint=%s]%s[/hint] " % [", ".join(PackedStringArray(names)), chip]) if not names.is_empty() else chip + " "
	var pending := bool(m.get("pide_reaccion", false)) and str(m.get("mi_emoji", "")) == "" and int(hub.reaction_pending.get("id", -1)) == id
	if str(m.get("mi_emoji", "")) == "" and (pending or id == _last_other_id or picker_id == id):  # solo en el aviso y en el último mensaje
		row += "[url=pick:%d][color=%s]%s[/color][/url]" % [id, "#edc245" if pending else "#5a6670", tr("IA_REACT_ADD")]
	return row


## BBCode del selector de emojis del mensaje (vacío si no está abierto): los dibujos, el elegido resaltado.
func picker_bb(m: Dictionary) -> String:
	var id := int(m.get("id", 0))
	if picker_id != id:
		return ""
	var ch := EzlakHub.reaction_choices()
	var opts := ""
	for i in ch.size():
		opts += "[url=emo:%d:%d][bgcolor=%s] %s [/bgcolor][/url] " % [id, i, "#3a7a4a" if i == picker_sel else "#1f3a2a", PcStyle.emoji_label(ch[i], 24)]
	return opts + "\n[color=#edc245]%s[/color]\n" % tr("IA_REACT_HINT")


## La pared del aviso: cuántos reaccionaron, si solo faltas tú, cuánto te queda y (desplegable) quién puso qué.
func _wall(m: Dictionary, out: RichTextLabel) -> void:
	var id := int(m.get("id", 0))
	var ws := hub.wall_status(m)
	var line := "[color=#9fb4c8]%s[/color]" % Loc.fmt(tr("IA_WALL_COUNT"), {"n": int(ws["hechos"]), "total": int(ws["total"])})
	if bool(ws["pendiente"]):
		if bool(ws["solo_tu"]):
			line += "  [bgcolor=#8a1a14][color=#ffffff][b] %s [/b][/color][/bgcolor]" % tr("IA_WALL_ONLY_YOU")
		else:
			line += "  [color=#edc245]%s[/color]" % Loc.fmt(tr("IA_WALL_MISSING"), {"n": (ws["faltan"] as Array).size()})
		line += "  [color=#edc245]%s[/color]" % Loc.mmss(ceil(float(ws["quedan"])))
	elif bool(ws["yo"]):
		line += "  [color=#3fc77a]%s[/color]" % tr("IA_WALL_YOU_DONE")
	else:
		line += "  [color=#ff6a5a]%s[/color]" % tr("IA_WALL_YOU_MISSED")
	line += "   [url=who:%d][color=#7f93a6]%s[/color][/url]" % [id, tr("IA_WALL_HIDE") if wall_open == id else tr("IA_WALL_SHOW")]
	out.append_text(line + "\n")
	if wall_open != id:
		return
	var slug_of := {}
	for p in (m["pared"] as Dictionary).get("equipo", []):
		if bool(p["agente"]):
			slug_of[str(p["nombre"])] = str(p["slug"])
	for e in m.get("emojis", []):
		var parts: Array[String] = []
		for n in (e[3] if (e as Array).size() > 3 else []):
			var txt := str(n)
			if slug_of.has(txt):  # un agente: su estado de ahora, si no está activo
				var pres: Dictionary = IABrain.presence(str(slug_of[txt]))
				if str(pres["estado"]) != "activo":
					txt += " [color=%s](%s)[/color]" % [str(pres["color"]), str(pres["texto"])]
			parts.append(txt)
		if bool(e[2]):
			parts.append("[b]%s[/b]" % tr("IA_WALL_YOU"))
		out.append_text("    [color=#9fb4c8]%s[/color]  %s\n" % [PcStyle.emoji_label(str(e[0])), ", ".join(PackedStringArray(parts))])
	var missing: Array[String] = []
	if not bool(ws["yo"]):
		missing.append("[b]%s[/b]" % tr("IA_WALL_YOU"))
	for n in ws["faltan"]:
		missing.append(str(n))
	if not missing.is_empty():
		out.append_text("    [color=#edc245]%s[/color]\n" % Loc.fmt(tr("IA_WALL_MISSING_LIST"), {"quienes": ", ".join(PackedStringArray(missing))}))
	if not (ws["fuera"] as Array).is_empty():
		var off: Array[String] = []
		for f in ws["fuera"]:
			off.append("%s (%s)" % [str(f[0]), str(f[1])])
		out.append_text("    [color=#6a7682]%s[/color]\n" % Loc.fmt(tr("IA_WALL_OFF_LIST"), {"quienes": ", ".join(PackedStringArray(off))}))


## El aviso fijado arriba del chat abierto. Devuelve su id (-1 si no hay): ese mensaje no repite sus emojis en el log.
func _rebuild_pin() -> int:
	var m: Dictionary = hub.message_by_id(_pin_id) if _pin_id >= 0 else {}
	var pending := not m.is_empty() and int(hub.reaction_pending.get("id", -1)) == _pin_id
	var show := not m.is_empty() and str(m.get("canal", "")) == current and (pending or _pin_hold > 0.0 or wall_open == _pin_id or picker_id == _pin_id)
	_pin_box.visible = show
	if not show:
		return -1
	_pin.clear()
	var info := hub.author_info(str(m.get("autor", "")))
	var one := str(m.get("texto", "")).replace("\n", "  ·  ")
	if one.length() > 200:
		one = one.left(197) + "…"
	one = PcStyle.rich(one)  # después de recortar: el BBCode de un emoji no se parte
	_pin.append_text("[color=#edc245]%s[/color]  [b][color=%s]%s[/color][/b] [color=#5a6670]%s[/color]\n%s\n" % [tr("IA_PIN_TITLE"), str(info.get("color", "#cccccc")), str(info.get("nombre", "")), str(m.get("hora", "")), one])
	_emoji_row(m, _pin)
	return _pin_id


## Texto visible del chat (aviso fijado + mensajes), para pruebas.
func visible_text() -> String:
	return (_pin.get_parsed_text() if _pin_box.visible else "") + "\n" + _log.get_parsed_text()


## Aviso fijo sobre el campo de escribir mientras hay una reacción pendiente (en cualquier chat).
func _refresh_banner() -> void:
	if _react_banner == null:
		return
	var on := not hub.reaction_pending.is_empty()
	_react_banner.visible = on
	if not on:
		return
	var m := hub.message_by_id(int(hub.reaction_pending.get("id", -1)))
	var alone := not m.is_empty() and bool(hub.wall_status(m)["solo_tu"])
	_react_banner.text = Loc.fmt(tr("IA_REACT_BANNER_ALONE") if alone else tr("IA_REACT_BANNER"),
		{"canal": hub.channel_title(str(hub.reaction_pending.get("canal", ""))), "t": Loc.mmss(ceil(hub.reaction_left()))})
	var col := Color(0.52, 0.1, 0.08) if alone else Color(0.36, 0.26, 0.05)
	if _react_banner.get_meta("col", Color()) != col:
		_react_banner.set_meta("col", col)
		_react_banner.add_theme_stylebox_override("normal", PcStyle.box(col, PcStyle.YELLOW if not alone else PcStyle.RED.lightened(0.3), 5.0))
		_react_banner.add_theme_stylebox_override("hover", PcStyle.box(col.lightened(0.12), PcStyle.YELLOW, 5.0))


## Estados de los DMs de la barra lateral, en una cadena (para saber cuándo redibujar).
func presence_signature() -> String:
	var out := ""
	for id in hub.order:
		if str(id).begins_with("dm:"):
			out += "%s=%s;" % [id, IABrain.presence_state(str(id).substr(3))]
	return out


## Estado (id) que muestra cada DM de la barra lateral (pruebas y capturas): {dm:quien: "llamada"}.
func presence_shown() -> Dictionary:
	var out := {}
	for id in _side_buttons.keys():
		if (_side_buttons[id] as Control).has_meta("estado"):
			out[id] = str((_side_buttons[id] as Control).get_meta("estado"))
	return out


## Cabecera: tema del canal, o en un DM «rol · estado» con el color del estado (el aviso breve manda mientras dura).
func _refresh_topic() -> void:
	if _topic == null or hub == null or toast_left > 0.0:
		return
	if current.begins_with("dm:"):
		var who := current.substr(3)
		var pres: Dictionary = IABrain.presence(who)
		_topic_text = "%s  ·  %s" % [Loc.pick(hub.author_info(who).get("rol", {})), str(pres["texto"])]
		_topic.add_theme_color_override("font_color", Color(str(pres["color"])))
	else:
		_topic.add_theme_color_override("font_color", PcStyle.DIM)
	_topic.text = _topic_text


## Punto de estado de 14 px (verde activo · rojo en llamada · ámbar lunch · violeta con barra «pausó» · aro gris ausente).
static func dot(estado: String) -> Texture2D:
	if _dots.has(estado):
		return _dots[estado]
	var col := Color(str(IABrain.PRESENCE_COLOR.get(estado, "#6a7682")))
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			var d := Vector2(x - 6.5, y - 6.5).length()
			var a := clampf(6.2 - d, 0.0, 1.0)
			if estado == "ausente":
				a *= clampf(d - 3.2, 0.0, 1.0)  # aro
			var c := col
			if estado == "pausa" and absf(y - 6.5) < 1.6 and absf(x - 6.5) < 4.0:
				c = Color(0.08, 0.07, 0.12)  # barra de «no molestar»
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	var tex := ImageTexture.create_from_image(img)
	_dots[estado] = tex
	return tex


## Teclas con Ezlaki a la vista (las reenvía la Workstation: la app vive en un SubViewport y no recibe el teclado).
## [Enter] abre el selector en el aviso pendiente; con el selector abierto ← → eligen, [Enter] reacciona y
## [Retroceso] lo cierra. true si la tecla hizo algo.
func key_action(k: int) -> bool:
	if hub == null or not looking or bool(GameState.flags.get("pc_text_focus", false)):
		return false
	if picker_id >= 0:
		if k in [KEY_LEFT, KEY_RIGHT]:
			var n := EzlakHub.reaction_choices().size()
			picker_sel = (picker_sel + (1 if k == KEY_RIGHT else -1) + n) % n
			_dirty = true
			return true
		if k in [KEY_ENTER, KEY_KP_ENTER]:
			react_with(EzlakHub.reaction_choices()[picker_sel])
			return true
		if k == KEY_BACKSPACE:
			picker_id = -1
			_dirty = true
			return true
		return false
	if k in [KEY_ENTER, KEY_KP_ENTER] and not hub.reaction_pending.is_empty():
		return open_picker() >= 0
	return false


func open_picker() -> int:
	var target := -1
	if not hub.reaction_pending.is_empty():
		target = int(hub.reaction_pending.get("id", -1))
		var ch := str(hub.reaction_pending.get("canal", ""))
		if ch != current:
			open_channel(ch)
	else:
		var ms := hub.messages(current)
		for i in range(ms.size() - 1, -1, -1):
			if str(ms[i].get("autor", "")) != "yo":
				target = int(ms[i].get("id", -1))
				break
	picker_id = target
	_dirty = true
	return target


func react_with(e: String) -> String:
	var m := hub.message_by_id(picker_id)
	picker_id = -1
	_dirty = true
	return hub.player_react(m, e)


func _on_meta(meta: Variant) -> void:
	var s := str(meta)
	if s.begins_with("pick:"):
		picker_id = int(s.substr(5)) if picker_id != int(s.substr(5)) else -1
		_dirty = true
		return
	if s.begins_with("who:"):
		wall_open = int(s.substr(4)) if wall_open != int(s.substr(4)) else -1
		_dirty = true
		return
	if s.begins_with("emo:"):
		var parts := s.split(":")
		picker_id = int(parts[1])
		react_with(EzlakHub.reaction_choices()[int(parts[2])])
		return
	if s.begins_with("shot:"):
		open_shot(int(s.substr(5)))
		return
	if s.begins_with("react:"):
		var id := int(s.substr(6))
		for m in hub.messages(current):
			if int(m.get("id", -1)) == id:
				hub.react(m)


## [Enter] en la PC/terminal: reacciona al recordatorio pendiente o se une a Rooms. true si hizo algo.
func enter_action() -> bool:
	if hub == null:
		return false
	if hub.rooms_pending:
		hub.join_rooms()
		return true
	var m := hub.pending_actionable()
	if not m.is_empty():
		return hub.react(m)  # v0.3.2: reacciona sin cambiar de chat
	return false


## «[Espacio] Unirse a la sala» sin la pista de la tecla (sea cual sea la tecla asignada): para el botón de la PC.
func _sin_tecla(t: String) -> String:
	if t.begins_with("[") and t.find("] ") > 0:
		return t.substr(t.find("] ") + 2)
	return t

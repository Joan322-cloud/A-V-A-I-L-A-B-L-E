class_name PcCampus
extends HBoxContainer
## App Campus: minitrainings del Mentor (00:20 · 03:30 · 06:15; se completan respondiendo su pregunta; v0.3.2: los
## tres de HOY, distintos cada turno: Mentor.day_minitrainings()), una franja con la «Actualización de campaña» del
## día y la nota mínima de su quiz (TrainingControl.day_info / pass_mark) y las
## guías de la campaña (Vitzo solo portal, reglas KYC por región, Available %). Responder mal no castiga:
## vuelve a la lectura (la presión la pone la lista del Mentor y Shero a las 08:00).
## v0.3 P6b: guías «Manual del agente» (glosario) y «Reglas del turno» (data/manual_agente.json, como en la pausa).

var cm: ContactManager = null
var _list: VBoxContainer = null
var _body: VBoxContainer = null
var _scroll: ScrollContainer = null
var _selected: String = ""
var _sig: String = ""
var _feedback: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var lp := PcStyle.panel(PcStyle.PANEL, 6.0)
	lp.custom_minimum_size = Vector2(250, 0)
	add_child(lp)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	lp.add_child(_list)
	var rp := PcStyle.panel(PcStyle.PANEL, 8.0)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rp)
	# v0.3.2: el cuerpo va dentro de un scroll. Un texto más largo de lo que cabe (la guía de KYC con sus cuatro
	# regiones, un minitraining en inglés) ya no estira la app ni empuja la barra F1-F5 fuera de la pantalla.
	_scroll = ScrollContainer.new()
	_scroll.name = "CuerpoScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rp.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)


func _mentor() -> Mentor:
	return get_tree().get_first_node_in_group("mentor") as Mentor


func refresh(_delta: float) -> void:
	var m := _mentor()
	var has_update := GameState.training_clock() >= 0.0  # hoy hay «Actualización de campaña» (martes y miércoles)
	var update_done := has_update and str(PersonajesP5.counter("p5_training", "")) == "hecho"
	var sig := "%s|%s|%s|%s|%d|%s|%d%d|%s" % [str(m.minitrainings_open) if m != null else "", str(m.minitrainings_done) if m != null else "", _selected, _feedback, GameState.turno, Loc.language, int(has_update), int(update_done), str(TrainingControl.pass_mark()) if has_update else ""]
	if sig == _sig:
		return
	_sig = sig
	PcStyle.clear(_list)
	PcStyle.clear(_body)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	var mts: Array = Mentor.day_minitrainings()
	var n_done := 0
	for mt in mts:
		if m != null and m.minitrainings_done.has(str(mt.get("id", ""))):
			n_done += 1
	var head := PcStyle.label(Loc.fmt(tr("FBUI_CAMPUS_MT_HOY"), {"hechos": n_done, "total": mts.size()}), PcStyle.F_SMALL, PcStyle.DIM)
	head.name = "MinitrainingsHoy"
	_list.add_child(head)
	for mt in mts:
		var id := str(mt.get("id", ""))
		var open := m != null and m.minitrainings_open.has(id)
		var done := m != null and m.minitrainings_done.has(id)
		var state := tr("P4_CAMPUS_DONE") if done else (tr("P4_CAMPUS_PENDING") if open else tr("P4_CAMPUS_LOCKED") + " " + str(mt.get("hora", "")))
		var b := PcStyle.button("%s\n%s" % [Loc.pick(mt.get("titulo", {})), state], func() -> void: _selected = id; _feedback = "", PcStyle.F_SMALL, PcStyle.PANEL_HI if id == _selected else PcStyle.PANEL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not open
		b.add_theme_color_override("font_color", PcStyle.GREEN if done else (PcStyle.YELLOW if open else PcStyle.DIM))
		_list.add_child(b)
	_list.add_child(PcStyle.hsep())
	_list.add_child(PcStyle.label(tr("P4_CAMPUS_GUIDES"), PcStyle.F_SMALL, PcStyle.DIM))
	for g in ["manual", "reglas", "vitzo", "kyc", "available"]:
		var gid: String = "guia_" + str(g)
		_list.add_child(PcStyle.button(tr("P4_CAMPUS_G_" + g.to_upper()), func() -> void: _selected = gid; _feedback = "", PcStyle.F_SMALL, PcStyle.PANEL_HI if gid == _selected else PcStyle.PANEL))
	# v0.3.2 (Joan: «que se vea la nota»): los días con «Actualización de campaña», una franja arriba con su hora, su
	# tema y la nota mínima de su quiz. Va en el cuerpo y no en la lista (la lista ya ocupa todo el alto de la pantalla),
	# en la bienvenida y en las guías cortas; no encima de un minitraining (su texto y sus opciones ocupan el alto).
	if has_update and (_selected == "" or _selected in ["guia_vitzo", "guia_kyc", "guia_available"]):
		var day := TrainingControl.day_info()
		var upd := PcStyle.label(Loc.fmt(tr("FBUI_CAMPUS_UPD"), {"hora": GameState.clock_text_at(GameState.training_clock()), "tema": Loc.pick(day.get("tema", {})), "min": TrainingControl.pass_mark(), "total": 5,
			"estado": tr("FBUI_CAMPUS_UPD_DONE") if update_done else tr("FBUI_CAMPUS_UPD_PENDING")}), PcStyle.F_TINY, PcStyle.GREEN if update_done else PcStyle.YELLOW)
		upd.name = "ActualizacionHoy"
		_body.add_child(upd)
		_body.add_child(PcStyle.hsep())
	if _selected == "":
		_body.add_child(PcStyle.label(tr("P4_CAMPUS_WELCOME"), PcStyle.F_BODY, PcStyle.DIM))
		return
	if _selected in ["guia_manual", "guia_reglas"]:
		GameState.flags["manual_abierto"] = true
		_body.add_child(PcStyle.label(tr("P4_CAMPUS_G_" + _selected.substr(5).to_upper()), PcStyle.F_BIG, PcStyle.TEXT))
		var sc := ScrollContainer.new()
		sc.name = "ManualScroll"
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size = Vector2(0, 330)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_body.add_child(sc)
		var rt := RichTextLabel.new()
		rt.name = "ManualTexto"
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_size_override("normal_font_size", PcStyle.F_TINY)
		rt.add_theme_font_size_override("bold_font_size", PcStyle.F_TINY)
		var parts: Array[String] = []
		if _selected == "guia_manual":
			for t in AgentManual.terms():
				parts.append("[b]%s[/b] — %s" % [Loc.pick(t.get("termino", {})), Loc.pick(t.get("def", {}))])
		else:
			for r in AgentManual.data().get("reglas", []):
				parts.append("[b]%s[/b]\n%s" % [Loc.pick(r.get("titulo", {})), Loc.pick_hint(r.get("texto", {}))])
		rt.text = "\n".join(PackedStringArray(parts))
		sc.add_child(rt)
		return
	if _selected.begins_with("guia_"):
		var key := "P4_CAMPUS_TXT_" + _selected.substr(5).to_upper()
		_body.add_child(PcStyle.label(tr("P4_CAMPUS_G_" + _selected.substr(5).to_upper()), PcStyle.F_BIG, PcStyle.TEXT))
		_body.add_child(PcStyle.label(tr(key), PcStyle.F_BODY, PcStyle.TEXT))
		if _selected == "guia_kyc":
			for r in (DataLoader.dict("casos_bo").get("reglas", {}).get("kyc_regiones", {}) as Dictionary).keys():
				_body.add_child(PcStyle.label("%s: %s" % [r, Loc.pick(DataLoader.dict("casos_bo").get("reglas", {}).get("kyc_regiones", {}).get(r, {}))], PcStyle.F_SMALL, PcStyle.TEXT))
		return
	for mt in mts:
		if str(mt.get("id", "")) != _selected:
			continue
		_body.add_child(PcStyle.label(Loc.pick(mt.get("titulo", {})), PcStyle.F_BIG, PcStyle.TEXT))
		_body.add_child(PcStyle.label(Loc.pick(mt.get("texto", {})), PcStyle.F_BODY, PcStyle.TEXT))
		_body.add_child(PcStyle.hsep())
		_body.add_child(PcStyle.label(Loc.pick(mt.get("pregunta", {})), PcStyle.F_BODY, PcStyle.YELLOW))
		var opts: Array = mt.get("opciones", [])
		for i in opts.size():
			var idx := i
			var id := _selected
			var correct := int(mt.get("correcta", 0))
			var b := PcStyle.button("%d · %s" % [i + 1, Loc.pick(opts[i])], func() -> void: answer(id, idx == correct), PcStyle.F_SMALL)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = m != null and m.minitrainings_done.has(id)
			_body.add_child(b)
		if _feedback != "":
			_body.add_child(PcStyle.label(_feedback, PcStyle.F_SMALL, PcStyle.GREEN if _feedback == tr("P4_CAMPUS_OK") else PcStyle.RED))


func answer(id: String, correct: bool) -> void:
	var m := _mentor()
	if correct and m != null:
		m.complete_minitraining(id)
		_feedback = tr("P4_CAMPUS_OK")
	else:
		_feedback = tr("P4_CAMPUS_WRONG")
	_sig = ""

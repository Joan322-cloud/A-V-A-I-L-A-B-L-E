class_name TurnSelect
extends Control
## "Elegir turno" (v0.3 P6b, PLAN §2 #80): lista los turnos que el agente ALCANZÓ en su partida principal (una
## instantánea por turno en SaveSlots) con la fecha en que llegó, el saldo con el que empezó y el resultado si
## ya lo cerró. Rejugar un turno pasado es una RAMA: la partida principal no cambia salvo que al terminar el
## turno elijas "Seguir desde aquí" (ShiftEnd). El turno actual (la frontera) es lo mismo que Continuar. Si hay
## una rama guardada a medias se puede continuar o descartar. Modo y dificultad: los elegidos en el menú.

signal turn_chosen(turno: int)  # turno anterior a la frontera → rama
signal continue_chosen()  # el turno actual = Continuar
signal branch_resume()
signal branch_discard()
signal closed()

var agent: String = "Jiroshi"
var mode: int = 0
var level: int = 1
var _confirm_discard: bool = false
var _panel: PanelContainer = null


func _ready() -> void:
	name = "TurnSelect"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	add_child(bg)
	build()


func build() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = UITheme.panel(Loc.fmt(tr("TS_TITLE"), {"agente": agent}), Vector2(980, 0))
	_panel.name = "Panel"
	add_child(_panel)
	UITheme.center_fit(_panel)
	var vb := UITheme.vb_of(_panel)
	vb.add_theme_constant_override("separation", 8)
	var intro := UITheme.label(tr("TS_INTRO"), 14, UITheme.TEXT)
	intro.custom_minimum_size = Vector2(950, 0)
	vb.add_child(intro)
	var mode_txt := tr("MENU_MODE_REAL") if mode == GameState.Mode.REAL else tr("MENU_MODE_NORMAL")
	var dif := Difficulty.display_name(Difficulty.Level.DIFICIL if mode == GameState.Mode.REAL else level)
	vb.add_child(UITheme.label(Loc.fmt(tr("TS_PLAYED_AS"), {"modo": mode_txt, "dif": dif}), 13, UITheme.DIM, true))
	# Rama guardada a medias.
	var pend := SaveSlots.pending_branch(agent)
	if not pend.is_empty():
		var pb := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.09)
		sb.border_color = UITheme.YELLOW.darkened(0.3)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(8)
		pb.add_theme_stylebox_override("panel", sb)
		vb.add_child(pb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pb.add_child(row)
		var pl := UITheme.label(Loc.fmt(tr("TS_PENDING"), {"n": int(pend.get("turno", 1)), "dia": Days.full(int(pend.get("turno", 1))), "fecha": fmt_date(str(pend.get("iniciada", "")))}), 14, UITheme.YELLOW, true)
		pl.custom_minimum_size = Vector2(520, 0)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pl)
		var rb := UITheme.button(tr("TS_RESUME"), func() -> void: branch_resume.emit())
		rb.name = "ResumeBranch"
		row.add_child(rb)
		var db := UITheme.button(tr("TS_DISCARD_CONFIRM") if _confirm_discard else tr("TS_DISCARD"), _on_discard)
		db.name = "DiscardBranch"
		if _confirm_discard:
			db.add_theme_color_override("font_color", UITheme.YELLOW)
		row.add_child(db)
	vb.add_child(HSeparator.new())
	var turns := SaveSlots.choosable_turns(agent)
	if turns.is_empty():
		vb.add_child(UITheme.label(tr("TS_EMPTY"), 15, UITheme.DIM))
	var first_btn: Button = null
	for e in turns:
		var n := int(e.get("turno", 1))
		var row := HBoxContainer.new()
		row.name = "Turno%d" % n
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(720, 0)
		row.add_child(col)
		var head := UITheme.label(Loc.fmt(tr("TS_ROW_HEAD"), {"n": n, "dia": Days.full(n), "fecha": fmt_date(str(e.get("alcanzado", "")))}) + ("   ·   " + tr("TS_CURRENT") if bool(e.get("actual", false)) else ""), 17, UITheme.TEXT, true)
		head.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(head)
		var info := UITheme.label(row_summary(e), 13, UITheme.EZLAK if e.has("resultado") else UITheme.DIM, true)
		info.name = "Resumen"
		col.add_child(info)
		var btn := UITheme.button(tr("TS_CONTINUE") if bool(e.get("actual", false)) else tr("TS_REPLAY"), _on_pick.bind(n, bool(e.get("actual", false))))
		btn.name = "Jugar"
		btn.custom_minimum_size = Vector2(190, 0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		if first_btn == null:
			first_btn = btn
	vb.add_child(HSeparator.new())
	var note := UITheme.label(tr("TS_NOTE"), 12, UITheme.DIM)
	note.custom_minimum_size = Vector2(950, 0)
	vb.add_child(note)
	var back := UITheme.button(tr("OPT_BACK"), func() -> void: closed.emit())
	back.name = "Volver"
	vb.add_child(back)
	if first_btn != null:
		first_btn.grab_focus.call_deferred()


## "Saldo inicial S/ 54,50 · Fatiga 25 · WW acumulados 1 — Cerrado: Available 89 % · WW 0 · 13 contactos · CSAT 4,2"
func row_summary(e: Dictionary) -> String:
	var parts: Array[String] = []
	var saldo := float(e.get("saldo", -1.0))
	parts.append(Loc.fmt(tr("TS_START_SALDO"), {"saldo": Economy.soles(saldo) if saldo >= 0.0 else Economy.soles(float(DataLoader.bal("economia/saldo_inicial_soles", 12.0)))}))
	parts.append(Loc.fmt(tr("TS_START_FATIGA"), {"f": int(float(e.get("fatiga_base", 20.0)))}))
	parts.append(Loc.fmt(tr("TS_START_WW"), {"n": int(e.get("ww_total", 0))}))
	var txt := "  ·  ".join(PackedStringArray(parts))
	if e.has("resultado"):
		var r: Dictionary = e.get("resultado", {})
		if bool(r.get("migrado", false)):
			txt += "\n" + tr("TS_RESULT_MIGRATED")
		else:
			var res := Loc.fmt(tr("TS_RESULT"), {"av": int(round(float(r.get("available", 0.0)))), "ww": int(r.get("ww", 0)), "c": int(r.get("contactos", 0)), "inc": int(r.get("incidencias", 0))})
			if float(r.get("csat", -1.0)) >= 0.0:
				res += "  ·  CSAT %.1f" % float(r.get("csat", 0.0))
			if bool(r.get("despedido", false)):
				res += "  ·  " + tr("TS_FIRED")
			txt += "\n" + res
	elif bool(e.get("actual", false)):
		txt += "\n" + tr("TS_NOT_CLOSED")
	if bool(e.get("migrado", false)):
		txt += "  " + tr("TS_MIGRATED_MARK")
	return txt


## "2026-11-09T14:32:10" → "09/11/2026 14:32"
static func fmt_date(iso: String) -> String:
	if iso.length() < 16:
		return "—"
	return "%s/%s/%s %s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(0, 4), iso.substr(11, 5)]


func _on_pick(n: int, current: bool) -> void:
	if current:
		continue_chosen.emit()
	else:
		turn_chosen.emit(n)


func _on_discard() -> void:
	if not _confirm_discard:
		_confirm_discard = true
		build()
		return
	_confirm_discard = false
	branch_discard.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

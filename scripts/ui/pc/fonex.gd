class_name PcFonex
extends PanelContainer
## Fonex (softphone) en la pantalla derecha y en los terminales de pared: sesión, AUX con botones (o teclas
## 1-7 en el menú [Q]), contacto entrante con [Aceptar] (Espacio) y [Hold] (H), y la fila de KPI que te
## avergüenza en tiempo real (Available bajo el target en rojo, llamadas perdidas, AHT, WW, breaks).

var cm: ContactManager = null
var _status: Label = null
var _incoming: Label = null
var _accept: Button = null
var _hold: Button = null
var _kpi: RichTextLabel = null
var _aux_buttons: Array[Button] = []
var _blink: float = 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", PcStyle.box(PcStyle.PANEL, PcStyle.BORDER, 8.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var title := PcStyle.label(tr("FONEX_TITLE"), PcStyle.F_TINY, PcStyle.DIM, false)
	top.add_child(title)
	_status = PcStyle.label("", PcStyle.F_SMALL, PcStyle.TEXT, false)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.clip_text = true  # v0.3.2: un estado largo no ensancha Fonex (la frase de «Reconectando» sacaba la PC de la pantalla)
	top.add_child(_status)
	var aux_row := HBoxContainer.new()
	aux_row.add_theme_constant_override("separation", 3)
	aux_row.set_meta("guia", "fonex:aux")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	vb.add_child(aux_row)
	for i in Metrics.AUX_KEYS.size():
		var idx := i
		var b := PcStyle.button("%d %s" % [i + 1, tr(Metrics.AUX_KEYS[i]).replace("BO · Back office", "BO")], func() -> void: _pick_aux(idx), PcStyle.F_TINY)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.set_meta("guia", "fonex:aux:%d" % i)
		aux_row.add_child(b)
		_aux_buttons.append(b)
	var call_row := HBoxContainer.new()
	call_row.add_theme_constant_override("separation", 6)
	vb.add_child(call_row)
	_incoming = PcStyle.label("", PcStyle.F_BODY, PcStyle.TEXT, false)
	_incoming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_incoming.clip_text = true
	_incoming.set_meta("guia", "fonex:estado")
	call_row.add_child(_incoming)
	_accept = PcStyle.button(tr("P4_FONEX_ACCEPT"), _on_accept, PcStyle.F_SMALL, Color(0.1, 0.32, 0.18))
	_accept.set_meta("guia", "fonex:aceptar")
	call_row.add_child(_accept)
	_hold = PcStyle.button(tr("P4_FONEX_HOLD"), func() -> void: if cm != null: cm.toggle_hold(), PcStyle.F_SMALL)
	_hold.set_meta("guia", "fonex:hold")
	call_row.add_child(_hold)
	_kpi = RichTextLabel.new()
	_kpi.bbcode_enabled = true
	_kpi.fit_content = true
	_kpi.scroll_active = false
	_kpi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kpi.add_theme_font_size_override("normal_font_size", PcStyle.F_SMALL)
	_kpi.add_theme_font_size_override("bold_font_size", PcStyle.F_SMALL)
	_kpi.set_meta("guia", "fonex:kpi")
	vb.add_child(_kpi)


func _pick_aux(i: int) -> void:
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("_pick_aux", i)


func _on_accept() -> void:
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("press_accept")


func refresh(delta: float = 0.0) -> void:
	_blink += delta
	var aux_t := Loc.mmss(Metrics.seconds_in_current_aux())
	if not GameState.logged_in:
		_status.text = "%s  ·  %s" % [GameState.clock_text(), tr("FONEX_LOGGED_OUT")]
	else:
		_status.text = "%s  ·  %s  ·  AUX %s %s%s" % [GameState.clock_text(), GameState.agent, Metrics.aux_name(), aux_t, Discipline.aux_margin_text()]
		if Metrics.reconnecting:
			_status.text = "%s  ·  %s  ·  %s… %d s" % [GameState.clock_text(), GameState.agent, tr("B2_AUX_RECONNECTING"), int(ceil(maxf(Reconexion.left, 0.0)))]
		# v0.3.2: la cola de KipuPay (ACD) y la espera del más antiguo.
		if cm != null and cm.acd != null:
			_status.text += "  ·  " + Loc.fmt(tr("B2_FONEX_QUEUE"), {"n": cm.acd.size(), "t": Loc.mmss(cm.acd.oldest_wait())})
	for i in _aux_buttons.size():
		var on := GameState.logged_in and Metrics.aux == i and not Metrics.reconnecting
		var expected := Metrics.expected_aux == i and Metrics.expected_aux != Metrics.aux
		var col := PcStyle.ACCENT.darkened(0.35) if on else (PcStyle.RED.darkened(0.45) if expected and fmod(_blink, 1.0) < 0.5 else PcStyle.PANEL_HI)
		_aux_buttons[i].add_theme_stylebox_override("normal", PcStyle.box(col, PcStyle.BORDER, 5.0))
		_aux_buttons[i].disabled = not GameState.logged_in
	var inc := ""
	var inc_col := PcStyle.TEXT
	# v0.3.2 (correos jugados con el ratón): los botones se apagaban y se volvían a encender en CADA cuadro, y apagar
	# un botón que se está apretando cancela el clic: «Aceptar» y «Hold» solo respondían a un clic de un solo cuadro
	# (nadie hace clic tan rápido; quedaba la tecla). Ahora se calcula el estado y se asigna una vez.
	var accept_off := true
	var hold_off := true
	if not GameState.logged_in:
		inc = tr("P4_FONEX_LOGIN_HINT")
		accept_off = GameState.seated_at == ""
	elif Metrics.reconnecting:
		# v0.3.2: la cuenta de «Reconectando» y qué hacer, en la línea grande del softphone (no «Esperando contacto»).
		inc = Reconexion.hud_text()
		inc_col = PcStyle.YELLOW
	elif cm != null:
		match cm.phase:
			ContactManager.Phase.OFFERING:
				var canal := str(cm.current.get("canal", ""))
				var key := "FONEX_INCOMING_CALL"
				match canal:
					"chat": key = "FONEX_INCOMING_CHAT"
					"correo": key = "FONEX_INCOMING_EMAIL"
					"kyc": key = "FONEX_INCOMING_KYC"
				inc = tr(key)
				if not ContactManager.is_bo(cm.current):
					inc += "   %ds" % int(ceil(maxf(cm.ring_left, 0.0)))
					inc_col = PcStyle.RED if cm.ring_left < 6.0 and fmod(_blink, 0.5) < 0.25 else PcStyle.YELLOW
				accept_off = not cm.player_ready()
			ContactManager.Phase.ACTIVE:
				if cm.tree != null:
					inc = "%s  %s" % [tr("FONEX_ON_HOLD") if cm.on_hold else tr("FONEX_ON_CALL"), Loc.mmss(cm.elapsed())]
					hold_off = false
					inc_col = PcStyle.YELLOW if cm.on_hold else PcStyle.GREEN
				else:
					inc = "%s  %s" % [tr("P4_FONEX_CASE"), Loc.mmss(maxf(cm.email_elapsed, 0.0))]
					inc_col = _timer_color(cm.case_timer_color())
			_:
				inc = tr("P4_FONEX_WAITING") if Metrics.is_productive(Metrics.aux) else tr("P4_FONEX_NOT_PRODUCTIVE")
				inc_col = PcStyle.DIM
	if _accept.disabled != accept_off:
		_accept.disabled = accept_off
	if _hold.disabled != hold_off:
		_hold.disabled = hold_off
	_incoming.text = inc
	_incoming.add_theme_color_override("font_color", inc_col)
	_kpi.text = kpi_bbcode()


static func _timer_color(c: String) -> Color:
	match c:
		"amarillo": return PcStyle.YELLOW
		"rojo", "pasado": return PcStyle.RED
	return PcStyle.GREEN


## KPI que avergüenzan (Available bajo el target, llamadas perdidas, AHT, WW, breaks, CSAT).
static func kpi_bbcode() -> String:
	var parts: Array[String] = []
	var pct := Metrics.available_pct()
	var col := "#3fc77a"
	var note := ""
	if Metrics.available_evaluable():
		if pct < 70.0:
			col = "#e5241f"
			note = " " + Loc.tr("P4_KPI_BELOW")
		elif pct < 80.0:
			col = "#edc245"
	parts.append("[color=%s]Available %d %%%s[/color]" % [col, int(pct), note])
	var aht := Metrics.aht_seconds()
	parts.append("[color=%s]AHT %s[/color]" % ["#e5241f" if aht > 540.0 else ("#edc245" if aht > 360.0 else "#9fb0bb"), Loc.mmss(aht)])
	var st := Engine.get_main_loop() as SceneTree
	var cm: ContactManager = st.get_first_node_in_group("contact_manager") as ContactManager if st != null else null
	var missed := cm.missed_count if cm != null else 0
	if missed > 0:
		parts.append("[color=#e5241f]%s %d/4[/color]" % [Loc.tr("P4_KPI_MISSED"), missed])
	parts.append("[color=%s]WW %d/3[/color]" % ["#e5241f" if Metrics.written_warnings > 0 else "#9fb0bb", Metrics.written_warnings])
	parts.append("[color=#9fb0bb]Breaks %d/%d[/color]" % [Metrics.breaks_used, Metrics.breaks_allowed()])
	# v0.3 P6b (PLAN §2 #33): "Feedback QA n/3" (Haime; el 3.º del turno es el último).
	if bool(GameState.turno_cfg("haime", true)) and GameState.turno > 0:
		var fq := int(PersonajesP5.counter("p5_qa_feedbacks", 0))
		var fmax := QaFeedback.max_for_shift()  # v0.3.1 (D2): 4 en Fácil/Normal, 3 en Difícil/Turno real
		parts.append("[color=%s]%s %d/%d[/color]" % ["#e5241f" if fq >= fmax - 2 else ("#edc245" if fq >= 1 else "#9fb0bb"), Loc.tr("P6B_KPI_QA"), fq, fmax])
	if Metrics.csat_avg() > 0.0:
		parts.append("[color=%s]CSAT %.1f[/color]" % ["#e5241f" if Metrics.csat_avg() < 3.0 else "#9fb0bb", Metrics.csat_avg()])
	if Economy.active():
		parts.append("[color=#9fb0bb]%s[/color]" % Economy.soles(Economy.saldo))
	return "  ·  ".join(PackedStringArray(parts))

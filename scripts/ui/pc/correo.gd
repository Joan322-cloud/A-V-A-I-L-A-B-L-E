class_name PcCorreo
extends VBoxContainer
## App Correo (PLAN §6.1). v0.3.1 Q4 (F16, decidido con Joan): arriba, la BARRA DE PASOS del caso con el paso actual
## resaltado y un check en los hechos, y al lado el reloj de 10 min del caso. Debajo: a la izquierda el correo
## entrante y lo enviado; a la derecha el redactor — destinatario, plantilla, los 3 campos (ID, monto, fecha),
## adjuntar el POD descargado del Portal Vitzo, [Enviar], tipificación y [Cerrar caso].
## v0.3.2 (Joan: «en el correo de pedir POD al partner, ¿por qué los pasos me piden adjuntar?»): la barra ya no es
## fija. Sale de CasoBO.steps(): con un partner normal son los siete pasos del Training (Kardex → Destinatario →
## Plantilla → Campos → Enviar → Tipificar → Cerrar), sin «Adjunto» y sin la casilla de adjuntar; si Kardex dice que
## el partner es Vitzo entra «Portal» y el resto es lo que el caso pide (responder o no; «Adjunto» solo si pidieron
## un POD). Lo hecho lleva check aunque se haga en otro orden.
## - Hasta buscar la operación en Kardex el redactor está bloqueado y dice una sola línea: «Busca la operación en
##   Kardex» (Joan 11:06Z: solo eso, sin más pistas).
## - Clic en un valor de Kardex: se copia a SU campo (ContactManager.copy_to_field). El jugador igual tiene que
##   encontrar la operación correcta: Kardex muestra también las parecidas del mismo cliente. También se puede
##   elegir de la lista. El campo marcado (>) es solo el siguiente vacío.
## - Al enviar NO se marca nada en rojo (Joan lo rechazó): los errores se descubren por las consecuencias (Haime,
##   QA, el caso que vuelve). El proceso no se acorta: mismos pasos, mismo reloj.
## - Guía una sola vez, en el primer correo de la partida: una nota bajo la barra que acompaña cada paso
##   (SaveSlots.mark_tooltip("q4_guia_correo"), una vez por partida); se cierra con [Entendido] o sola al cerrar el caso.
## Todo se puede cambiar antes de enviar (ratón o Retroceso = borrar el último campo). Un árbol (WMM) que abre un
## correo muestra aquí el redactor ya dirigido a Vitzo: Enviar / Cancelar.

## Todos los pasos que la barra puede mostrar (el caso dice cuáles y en qué orden: CasoBO.steps()).
const ALL_STEPS: Array[String] = ["kardex", "portal", "destinatario", "plantilla", "campos", "adjunto", "enviar", "tipificar", "cerrar"]
## Los siete de un correo normal (compatibilidad: pruebas y capturas viejas).
const STEPS: Array[String] = ["kardex", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"]
const GUIDE_FLAG := "q4_guia_correo"

var cm: ContactManager = null
var _bar: HBoxContainer = null
var _chips: Dictionary = {}  # paso -> {panel, label, check}
var _shown_steps: Array[String] = []  # los pasos que la barra tiene dibujados
var _timer: Label = null
var _guide: PanelContainer = null
var _guide_lbl: Label = null
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _sig: String = ""
var _guide_case: String = ""  # id del caso con la guía abierta
var _guide_off: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 5)
	var top := HBoxContainer.new()
	top.name = "PasosCorreo"
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	_bar = HBoxContainer.new()
	_bar.name = "BarraPasos"
	_bar.add_theme_constant_override("separation", 3)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_bar)
	_build_steps(STEPS)
	_timer = PcStyle.label("", PcStyle.F_SMALL, PcStyle.GREEN, false)
	_timer.name = "RelojCaso"
	_timer.custom_minimum_size = Vector2(112, 0)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_timer)
	_guide = PanelContainer.new()
	_guide.name = "GuiaCorreo"
	_guide.add_theme_stylebox_override("panel", PcStyle.box(Color(0.1, 0.13, 0.2), PcStyle.ACCENT, 5.0))
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 8)
	_guide.add_child(gh)
	_guide_lbl = PcStyle.label("", PcStyle.F_TINY, PcStyle.TEXT)
	_guide_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(_guide_lbl)
	var ok := PcStyle.button(tr("Q4_GUIDE_OK"), _dismiss_guide, PcStyle.F_TINY)
	ok.name = "GuiaOk"
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(ok)
	_guide.visible = false
	add_child(_guide)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var lp := PcStyle.panel(PcStyle.PANEL, 6.0)
	lp.custom_minimum_size = Vector2(280, 0)
	body.add_child(lp)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 3)
	lp.add_child(_left)
	var rp := PcStyle.panel(PcStyle.PANEL, 6.0)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rp)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 3)
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rp.add_child(_right)


## Dibuja la barra con estos pasos (numerados 1..n). Se rehace solo cuando la lista cambia (al buscar en Kardex se
## sabe quién es el partner).
func _build_steps(steps: Array) -> void:
	PcStyle.clear(_bar)
	_chips.clear()
	_shown_steps.clear()
	var small := steps.size() > 8  # nueve pasos (Vitzo con POD): una letra más chica para que quepan sin recortar
	_bar_font = 12 if not small else 11
	for i in steps.size():
		var k: String = steps[i]
		_shown_steps.append(k)
		var p := PanelContainer.new()
		p.name = "Paso_" + k
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 2)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(hb)
		var chk := _Check.new()
		chk.custom_minimum_size = Vector2(11, 11) if not small else Vector2(9, 9)
		chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(chk)
		var l := PcStyle.label("%d %s" % [i + 1, tr("Q4_STEP_" + k.to_upper())], _bar_font, PcStyle.DIM, false)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(l)
		_bar.add_child(p)
		# Cada paso se lleva el ancho que su etiqueta necesita («Destinatario» más que «Cerrar»): medido, no a ojo.
		p.size_flags_stretch_ratio = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _bar_font).x + 22.0
		_chips[k] = {"panel": p, "label": l, "check": chk}


## Si alguna etiqueta de la barra no cabe entera (ocho o nueve pasos, o un idioma de palabras más largas), la letra de
## toda la barra baja un punto por cuadro hasta que quepan (mínimo 9): nunca se ve un paso recortado con «…».
var _bar_font := 12


func _fit_steps() -> void:
	if _bar_font <= 9 or _chips.is_empty():
		return
	for k in _shown_steps:
		var l := _chips[k]["label"] as Label
		if l.size.x <= 1.0:
			return  # todavía sin maquetar
		if l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _bar_font).x > l.size.x + 0.5:
			_bar_font -= 1
			for kk in _shown_steps:
				(_chips[kk]["label"] as Label).add_theme_font_size_override("font_size", _bar_font)
			return


## Pasos del caso abierto (los siete del correo normal si no hay caso).
func steps() -> Array[String]:
	if cm == null or cm.case == null or cm.case.is_kyc():
		return STEPS.duplicate()
	return cm.case.steps()


func refresh(_delta: float) -> void:
	if cm == null:
		return
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		_rebuild()
	var has_case := cm.case != null and not cm.case.is_kyc()
	_bar.get_parent().visible = has_case and cm.composer.is_empty()
	if has_case:
		_timer.text = "%s %s / 10:00" % [tr("Q4_CASE_TIMER"), Loc.mmss(maxf(cm.email_elapsed, 0.0))]
		_timer.add_theme_color_override("font_color", PcFonex._timer_color(cm.case_timer_color()))
		_paint_steps()
	else:
		_timer.text = ""
	_update_guide()


## Paso actual del caso (el primero sin hacer de CasoBO.steps()); los hechos llevan check.
func current_step() -> String:
	if cm == null or cm.case == null:
		return ""
	return cm.case.current_step()


func step_done(step: String) -> bool:
	if cm == null or cm.case == null:
		return false
	return cm.case.step_done(step)


func _paint_steps() -> void:
	var want := steps()
	if want != _shown_steps:
		_build_steps(want)
	var cur := current_step()
	var reached := true
	for k in _shown_steps:
		var c: Dictionary = _chips[k]
		var done := step_done(k)
		var is_cur := k == cur
		var bg := PcStyle.PANEL
		var border := Color(0, 0, 0, 0)
		var col := PcStyle.DIM.darkened(0.25)
		if is_cur:
			bg = PcStyle.ACCENT.darkened(0.45)
			border = PcStyle.ACCENT
			col = PcStyle.TEXT
			reached = false
		elif done:
			bg = Color(0.08, 0.17, 0.12)
			col = PcStyle.GREEN
		elif reached:
			col = PcStyle.DIM  # saltado
		(c["panel"] as PanelContainer).add_theme_stylebox_override("panel", PcStyle.box(bg, border, 3.0))
		(c["label"] as Label).add_theme_color_override("font_color", col)
		var chk := c["check"] as _Check
		chk.on = done
		chk.queue_redraw()
	_fit_steps()


func _signature() -> String:
	var s := "%d|%s|%s|%s" % [cm.phase, str(cm.current.get("id", "")), str(cm.composer), cm.mail_active_field]
	if cm.case != null:
		var c := cm.case
		s += "|%s|%s|%s|%s|%s|%d|%s|%s" % [str(c.kardex_done), c.recipient, c.template, str(c.fields), str(c.attach_pod), c.sent.size(), c.typification, str(c.portal_done)]
	return s


func _rebuild() -> void:
	PcStyle.clear(_left)
	PcStyle.clear(_right)
	if not cm.composer.is_empty():
		_draw_tree_composer()
		return
	if cm.case == null or cm.case.is_kyc():
		_left.add_child(PcStyle.label(tr("P4_MAIL_INBOX"), PcStyle.F_SMALL, PcStyle.DIM))
		_left.add_child(PcStyle.label(tr("P4_MAIL_EMPTY"), PcStyle.F_SMALL, PcStyle.DIM))
		_right.add_child(PcStyle.label(tr("P4_MAIL_HOWTO"), PcStyle.F_SMALL, PcStyle.DIM))
		return
	var c := cm.current
	var k := cm.case
	_left.add_child(PcStyle.label("%s: %s" % [tr("P4_MAIL_FROM"), str(c.get("de", ""))], PcStyle.F_TINY, PcStyle.DIM))
	_left.add_child(PcStyle.label(PcStyle.clean(Loc.pick(c.get("asunto", {}))), PcStyle.F_BODY, PcStyle.TEXT))
	var body := PcStyle.label(PcStyle.clean(Loc.pick(c.get("cuerpo", {}))), PcStyle.F_SMALL, Color(0.8, 0.78, 0.72))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(body)
	var ver := PcStyle.button("%s %s" % [tr("P4_MAIL_OPEN_KARDEX"), k.tx()], func() -> void: _open("kardex", k.tx()))
	ver.set_meta("guia", "correo:kardex")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	_left.add_child(ver)
	if not k.sent.is_empty():
		_left.add_child(PcStyle.hsep())
		_left.add_child(PcStyle.label(tr("P4_MAIL_SENT"), PcStyle.F_TINY, PcStyle.DIM))
		for m in k.sent:
			var to := str(m.get("to", ""))
			_left.add_child(PcStyle.label("→ %s · %s%s" % [to, str(m.get("tpl", "")), " · POD" if bool(m.get("pod", false)) else ""], PcStyle.F_TINY, PcStyle.DIM))
	var locked := not k.kardex_done
	if locked:
		var ll := PcStyle.label(tr("Q4_MAIL_LOCKED"), PcStyle.F_SMALL, PcStyle.YELLOW)
		ll.name = "LineaBloqueo"
		_right.add_child(ll)
	# Redactor
	var dests: Array = []
	for d in DataLoader.dict("casos_bo").get("destinatarios", []):
		dests.append(str(d.get("id", "")))
	var row1 := HBoxContainer.new()
	row1.add_child(_cap(tr("KARDEX_EMAIL_TO")))
	var od := PcStyle.option(dests, k.recipient, func(v: String) -> void: cm.set_recipient(v))
	od.name = "OptDestinatario"
	od.set_meta("guia", "correo:destinatario")
	od.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	od.disabled = locked
	row1.add_child(od)
	_right.add_child(row1)
	if k.recipient != "":
		var addr := ""
		for d in DataLoader.dict("casos_bo").get("destinatarios", []):
			if str(d.get("id", "")) == k.recipient:
				addr = str(d.get("correo", ""))
		var warn := k.recipient == "Vitzo" and Difficulty.flag("pistas_trampas")
		_right.add_child(PcStyle.label("<%s>%s" % [addr, ("   " + tr("P4_HINT_SURE")) if warn else ""], PcStyle.F_TINY, PcStyle.RED if warn else PcStyle.DIM))
	var row2 := HBoxContainer.new()
	row2.add_child(_cap(tr("KARDEX_EMAIL_TEMPLATE")))
	var ot := PcStyle.option(DataLoader.dict("casos_bo").get("plantillas", []), k.template, func(v: String) -> void: cm.set_template(v))
	ot.name = "OptPlantilla"
	ot.set_meta("guia", "correo:plantilla")
	ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ot.disabled = locked
	row2.add_child(ot)
	_right.add_child(row2)
	var opts: Dictionary = c.get("opciones_campos", {})
	var fg := GridContainer.new()
	fg.columns = 3
	fg.add_theme_constant_override("h_separation", 4)
	fg.add_theme_constant_override("v_separation", 2)
	for key in CasoBO.FIELDS:
		var fk: String = key
		var active := cm.mail_active_field == fk and not locked
		var pick := PcStyle.button(">" if active else "-", func() -> void: cm.set_active_field(fk), PcStyle.F_TINY, PcStyle.ACCENT.darkened(0.3) if active else PcStyle.PANEL_HI)
		pick.name = "Activo_" + fk
		pick.custom_minimum_size = Vector2(24, 0)
		pick.tooltip_text = tr("Q4_FIELD_ACTIVE_TIP")
		pick.disabled = locked
		fg.add_child(pick)
		var cap := _cap(tr("P4_FIELD_" + key.to_upper()))
		if active:
			cap.add_theme_color_override("font_color", PcStyle.ACCENT.lightened(0.3))
		fg.add_child(cap)
		var items: Array = (opts.get(key, []) as Array).duplicate()
		var cur := str(k.fields.get(key, ""))
		if cur != "" and not items.has(cur):
			items.append(cur)  # valor copiado desde Kardex que no estaba en la lista
		var of := PcStyle.option(items, cur, func(v: String) -> void:
			cm.set_active_field(fk)
			cm.set_field(fk, v))
		of.name = "Campo_" + fk
		of.disabled = locked
		of.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if active:
			of.add_theme_stylebox_override("normal", PcStyle.box(PcStyle.PANEL_HI, PcStyle.ACCENT, 4.0))
		fg.add_child(of)
	fg.set_meta("guia", "correo:campos")
	_right.add_child(fg)
	var att := CheckBox.new()
	att.name = "Adjunto"
	att.set_meta("guia", "correo:adjunto")
	att.text = tr("P4_MAIL_ATTACH_POD")
	att.focus_mode = Control.FOCUS_NONE
	att.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	att.button_pressed = k.attach_pod
	att.disabled = locked or not k.portal_done.has("pod")
	# v0.3.2: adjuntar es solo de los casos de Vitzo (el POD sale de su portal). Con un partner normal no hay nada
	# que adjuntar: el POD se le PIDE; la casilla ni aparece.
	att.visible = k.portal_done.has("pod") or (k.kardex_done and k.partner() == "Vitzo")
	att.toggled.connect(func(on: bool) -> void: cm.set_attach(on))
	_right.add_child(att)
	var send := PcStyle.button(tr("P4_MAIL_SEND"), func() -> void: cm.send_email(), PcStyle.F_BODY, Color(0.12, 0.26, 0.42))
	send.name = "Enviar"
	send.set_meta("guia", "correo:enviar")
	send.disabled = locked or not k.can_send()
	_right.add_child(send)
	_right.add_child(PcStyle.hsep())
	var tips: Array = []
	var tip_ids: Array = []
	for t in DataLoader.dict("casos_bo").get("tipificaciones", []):
		tips.append(Loc.pick(t))
		tip_ids.append(str(t.get("id", "")))
	var cur_tip := ""
	if k.typification != "" and tip_ids.has(k.typification):
		cur_tip = str(tips[tip_ids.find(k.typification)])
	var row3 := HBoxContainer.new()
	row3.add_child(_cap(tr("P4_MAIL_TYPIFY")))
	var otp := PcStyle.option(tips, cur_tip, func(v: String) -> void: cm.set_typification("" if v == "" else str(tip_ids[tips.find(v)])))
	otp.name = "OptTipificacion"
	otp.set_meta("guia", "correo:tipificar")
	otp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(otp)
	_right.add_child(row3)
	var close := PcStyle.button(tr("P4_MAIL_CLOSE"), func() -> void: cm.close_case(), PcStyle.F_BODY, Color(0.12, 0.3, 0.2))
	close.name = "Cerrar"
	close.set_meta("guia", "correo:cerrar")
	close.disabled = k.typification == ""
	_right.add_child(close)


func _cap(t: String) -> Label:
	var l := PcStyle.label(t, PcStyle.F_SMALL, PcStyle.DIM, false)
	l.custom_minimum_size = Vector2(92, 0)
	return l


func _open(app: String, tx: String) -> void:
	var d := get_tree().get_first_node_in_group("pc_desktop")
	if d != null:
		d.call("open_app", app)
		if app == "kardex" and tx != "":
			var kd := d.get("kardex") as PcKardex
			if kd != null:
				kd.call("_lookup", tx)


func _draw_tree_composer() -> void:
	var comp := cm.composer
	_left.add_child(PcStyle.label(tr("P4_MAIL_NEW"), PcStyle.F_BODY, PcStyle.TEXT))
	_left.add_child(PcStyle.label(tr("P4_MAIL_FROM_CALL"), PcStyle.F_SMALL, PcStyle.DIM))
	if bool(comp.get("aviso", false)):
		_left.add_child(PcStyle.label(tr("P4_MAIL_FROM_BANNER"), PcStyle.F_SMALL, PcStyle.YELLOW))
	_right.add_child(PcStyle.label("%s: Vitzo <%s>" % [tr("KARDEX_EMAIL_TO"), str(DataLoader.dict("casos_bo").get("reglas", {}).get("vitzo_correo", "ops@vitzo.kp"))], PcStyle.F_BODY, PcStyle.RED if Difficulty.flag("pistas_trampas") else PcStyle.TEXT))
	_right.add_child(PcStyle.label("%s: %s" % [tr("KARDEX_EMAIL_TEMPLATE"), str(comp.get("tpl", ""))], PcStyle.F_SMALL, PcStyle.TEXT))
	var body := Loc.fmt(tr("P4_MAIL_TREE_BODY"), {"tx": str(comp.get("tx", "")), "tpl": str(comp.get("tpl", ""))})
	var b := PcStyle.label(body, PcStyle.F_SMALL, Color(0.8, 0.78, 0.72))
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(PcStyle.button(tr("P4_MAIL_SEND"), func() -> void: cm.composer_send(), PcStyle.F_BODY, Color(0.12, 0.26, 0.42)))
	row.add_child(PcStyle.button(tr("P4_MAIL_CANCEL"), func() -> void: cm.composer_cancel(), PcStyle.F_BODY))
	_right.add_child(row)


## Retroceso: deshace el último campo elegido (fecha → monto → id → plantilla → destinatario).
func undo_last() -> void:
	if cm == null or cm.case == null:
		return
	var k := cm.case
	for key in ["fecha", "monto", "id"]:
		if str(k.fields.get(key, "")) != "":
			cm.set_field(key, "")
			cm.set_active_field(key)
			return
	if k.template != "":
		cm.set_template("")
	elif k.recipient != "":
		cm.set_recipient("")


# --- guía del primer correo ------------------------------------------------------------------------

func guide_pending() -> bool:
	return not SaveSlots.tooltip_seen(GUIDE_FLAG) and not _guide_off


func _update_guide() -> void:
	var show := cm != null and cm.case != null and not cm.case.is_kyc() and cm.composer.is_empty() and guide_pending()
	if show and _guide_case == "":
		_guide_case = str(cm.current.get("id", ""))
	if not show and _guide_case != "" and (cm == null or cm.case == null):
		_finish_guide()  # se cerró el primer caso: la guía no vuelve
	_guide.visible = show
	if show:
		var step := current_step()
		var all := steps()
		_guide_lbl.text = "%s  %s" % [Loc.fmt(tr("Q4_GUIDE_HEAD"), {"n": all.find(step) + 1, "total": all.size()}), tr(guide_key(step))]


## Clave del texto de la guía para un paso del caso abierto: el Portal dice qué falta ahí (buscar / descargar el POD
## / registrar el reversal) y, con Vitzo de partner, el destinatario recuerda que a Vitzo no se le escribe.
func guide_key(step: String) -> String:
	var k := cm.case if cm != null else null
	if k != null and step == "portal":
		var pend := k.portal_pending()
		return "Q4_GUIDE_PORTAL_" + (pend if pend != "" else "buscar").to_upper()
	if k != null and step == "destinatario" and k.kardex_done and k.partner() == "Vitzo":
		return "Q4_GUIDE_DESTINATARIO_VZ"
	return "Q4_GUIDE_" + step.to_upper()


func _dismiss_guide() -> void:
	_finish_guide()
	_guide.visible = false


func _finish_guide() -> void:
	_guide_off = true
	_guide_case = ""
	SaveSlots.mark_tooltip(GUIDE_FLAG)


## Check dibujado (la fuente de la PC no tiene ✓).
class _Check extends Control:
	var on: bool = false

	func _draw() -> void:
		var s := size
		if not on:
			draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color(0.4, 0.45, 0.5, 0.6), false, 1.0)
			return
		draw_polyline(PackedVector2Array([Vector2(1, s.y * 0.55), Vector2(s.x * 0.4, s.y - 1), Vector2(s.x - 1, 1)]), PcStyle.GREEN, 2.0, true)

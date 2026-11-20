## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P4 · casos de BO (PLAN §6.1-6.3): correo con trabajo real, reloj del caso (10x, 10 min =
## 60 s reales) y sus eventos, KYC por caso, casos de correo de Vitzo (trampa = muerte, portal = correcto),
## un caso BO nunca se pierde, llamadas perdidas (respaldo de P4 mientras P3 no implemente la pista).


func escenarios() -> Array[String]:
	return ["correo_trabajo", "correo_timer", "kyc:", "kyc_todos", "vitzo_correo", "bo_no_expira", "llamadas_perdidas_p4"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"correo_trabajo": await _correo(t)
		"correo_timer": await _timer(t)
		"kyc": await _kyc(t, arg)
		"kyc_todos":
			for c in all_cases():
				if str(c.get("canal", "")) == "kyc":
					await _kyc(t, str(c.get("id", "")))
		"vitzo_correo": await _vitzo(t)
		"bo_no_expira": await _no_expira(t)
		"llamadas_perdidas_p4": await _perdidas(t)


static func all_cases() -> Array:
	var out: Array = []
	var bo := DataLoader.dict("casos_bo")
	for tn in ["1", "2", "3"]:
		for c in (bo.get("turnos", {}) as Dictionary).get(tn, []):
			var d: Dictionary = (c as Dictionary).duplicate(true)
			d["_turno"] = int(tn)
			out.append(d)
	for c in bo.get("relleno_kyc", []):
		var d: Dictionary = (c as Dictionary).duplicate(true)
		d["_turno"] = 3
		out.append(d)
	return out


static func case_by_id(cid: String) -> Dictionary:
	for c in all_cases():
		if str(c.get("id", "")) == cid:
			return c
	return {}


func _cm(t: Node) -> ContactManager:
	return t.main.get("contacts") as ContactManager


func _open(t: Node, c: Dictionary) -> ContactManager:
	await t.start_shift("Jiroshi", int(c.get("_turno", 1)))
	await t.login_at_seat()
	var cm := _cm(t)
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c.duplicate(true))
	cm.accept()
	await t.frames(1)
	return cm


## Hace el caso como un agente que sabe (mismos pasos que el bot listo).
static func solve(cm: ContactManager, c: Dictionary) -> void:
	var corr: Dictionary = c.get("correcto", {})
	cm.kardex_lookup(str(c.get("tx", "")))
	for p in corr.get("portal", []):
		match str(p):
			"buscar": cm.portal_search(str(c.get("tx", "")))
			"pod": cm.portal_download_pod()
			"reversal": cm.portal_reversal()
			"contacto": cm.portal_contact()
	if str(corr.get("destinatario", "")) != "":
		cm.set_recipient(str(corr.get("destinatario", "")))
		cm.set_template(str(corr.get("plantilla", "")))
		for f in CasoBO.FIELDS:
			cm.set_field(f, str((corr.get("campos", {}) as Dictionary).get(f, "")))
		if bool(corr.get("adjunto_pod", false)):
			cm.portal_attach_pod()
		cm.send_email()
	cm.set_typification(str(corr.get("tipificacion", "")))


func _correo(t: Node) -> void:
	var c := case_by_id("t1_correo_pod")
	var cm: ContactManager = await _open(t, c)
	var outcomes: Array = t.spy("contact_outcome")
	var sent: Array = t.spy("email_sent")
	t.check(cm.case != null and not cm.case.is_kyc(), "el correo entra como caso en Available (sin cambiar de AUX)")
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE, "AUX sigue en Available")
	t.check(is_equal_approx(GameState.clock_speed(), float(DataLoader.bal("reloj/caso_bo", 10.0))), "reloj del caso BO %.0fx" % GameState.clock_speed())
	cm.set_field("id", "KP-2211-3312")
	t.check(str(cm.case.fields.get("id", "")) == "", "los campos están bloqueados hasta buscar en Kardex")
	t.check(not cm.kardex_lookup("KP-2211-3321"), "un KP equivocado no se encuentra")
	solve(cm, c)
	t.check(sent.size() == 1 and str(sent[0][0]) == "Banco Andino", "envía a Banco Andino")
	var el := cm.email_elapsed
	cm.close_case()
	t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "bo_ok", "bien resuelto → bo_ok (%s)" % str(outcomes))
	t.check(el < 8.0 * 60.0, "el agente competente cierra en < 8 min de juego (%.0f s de juego, incluida la latencia)" % el)
	# Monto del cliente (typo) en vez del de Kardex → miss.
	cm = await _open(t, c)
	outcomes.clear()
	var alerts0 := Metrics.alerts
	solve(cm, c)
	cm.case.sent.clear()
	cm.set_field("monto", "1.205,00 KP")
	cm.send_email()
	cm.close_case()
	t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "bo_miss", "monto del correo del cliente (no el de Kardex) → bo_miss")
	t.check(Metrics.alerts > alerts0 or Metrics.written_warnings > 0, "el miss pasa por el procedimiento de misses (alerta/WW)")
	t.check((outcomes[0][0].get("_qa", []) as Array).has("correo_campo_monto"), "marca de QA del campo que falló (v0.3.1 Q4: correo_campo_monto, antes correo_incorrecto)")
	# Deshacer: cambiar el destinatario y la plantilla antes de enviar (bug v0.2).
	cm = await _open(t, c)
	cm.set_recipient("Caja Mirador")
	cm.set_template("Reversal")
	cm.set_recipient("Banco Andino")
	cm.set_template("POD")
	t.check(cm.case.recipient == "Banco Andino" and cm.case.template == "POD", "destinatario y plantilla se pueden cambiar antes de enviar")
	var ws: Node = t.main.get_node("UI/Workstation")
	var desk: PcDesktop = ws.get("desktop") as PcDesktop
	desk.open_app("correo")
	desk.correo.undo_last()
	t.check(cm.case.template == "", "Retroceso deshace la plantilla")
	desk.correo.undo_last()
	t.check(cm.case.recipient == "", "Retroceso deshace el destinatario")


func _timer(t: Node) -> void:
	var c := case_by_id("t1_correo_pod")
	var cm: ContactManager = await _open(t, c)
	GameState.running = false
	var ticks: Array = t.spy("email_timer_tick")
	var over: Array = t.spy("email_over_time")
	t.check(cm.case_timer_color() == "verde", "reloj del caso en verde al abrir")
	await t.advance_clock(7.5 * 60.0)
	t.check(cm.case_timer_color() == "amarillo", "a los 7 min se pone amarillo")
	await t.advance_clock(1.8 * 60.0)
	t.check(cm.case_timer_color() == "rojo", "a los 9 min rojo")
	t.check(over.is_empty(), "antes de los 10 min no hay email_over_time")
	await t.advance_clock(1.0 * 60.0)
	t.check(over.size() == 1 and str(over[0][0]) == "t1_correo_pod", "a los 10 min: email_over_time una vez (para la escalera de Shero, P3)")
	await t.advance_clock(3.0 * 60.0)
	t.check(over.size() == 1, "email_over_time no se repite")
	t.check(ticks.size() >= 10 and float(ticks[ticks.size() - 1][0]) < 0.0, "email_timer_tick con los segundos restantes (negativo pasado el límite)")
	t.check(cm.case_timer_color() == "pasado" and cm.email_seconds_left() < 0.0, "pasado de 10 min")
	# Real: 10 min de juego = 60 s reales a 10x.
	var speed := float(DataLoader.bal("reloj/caso_bo", 10.0))
	t.check(absf(600.0 / speed - 60.0) < 0.1, "10 min de caso = %.0f s reales" % (600.0 / speed))
	# La latencia de los sistemas hace posible pasarse: Kardex + portal + POD + envío.
	var lat: Dictionary = DataLoader.dict("casos_bo").get("reglas", {}).get("latencia_s_juego", {})
	t.check(float(lat.get("kardex", 0)) + float(lat.get("portal", 0)) + float(lat.get("pod", 0)) + float(lat.get("enviar", 0)) >= 60.0, "los sistemas consumen al menos 1 min de juego por caso Vitzo")


func _kyc(t: Node, cid: String) -> void:
	var c := case_by_id(cid)
	if not t.check(not c.is_empty() and str(c.get("canal", "")) == "kyc", "existe el KYC %s" % cid):
		return
	for action in PcIdenta.ACTIONS:
		var cm: ContactManager = await _open(t, c)
		var outcomes: Array = t.spy("contact_outcome")
		var misses0 := Metrics.alerts + Metrics.written_warnings
		cm.kyc_decide(action)
		var want_ok := action == str(c.get("correcto", ""))
		t.check(outcomes.size() == 1 and str(outcomes[0][1]) == ("bo_ok" if want_ok else "bo_miss"), "%s · %s → %s" % [cid, action, "bo_ok" if want_ok else "bo_miss"])
		if not want_ok:
			t.check(Metrics.alerts + Metrics.written_warnings > misses0, "%s · %s: miss reportado (QA)" % [cid, action])
		outcomes.clear()


func _vitzo(t: Node) -> void:
	for cid in ["vz_status", "vz_pod", "vz_reversal"]:
		var c := case_by_id(cid)
		# Camino correcto.
		var cm: ContactManager = await _open(t, c)
		var outcomes: Array = t.spy("contact_outcome")
		var deaths: Array = t.spy("death_requested")
		var actions: Array = t.spy("vitzo_portal_action")
		solve(cm, c)
		cm.close_case()
		t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "bo_ok" and deaths.is_empty(), "%s: portal → bo_ok sin muerte (%s)" % [cid, str(outcomes)])
		t.check(actions.size() >= 1 and str(actions[0][1]) == "buscar", "%s: vitzo_portal_action emitido" % cid)
		# Cerrar sin pasar por el portal = miss.
		cm = await _open(t, c)
		outcomes.clear()
		cm.kardex_lookup(str(c.get("tx", "")))
		cm.set_typification(str((c.get("correcto", {}) as Dictionary).get("tipificacion", "")))
		cm.close_case()
		t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "bo_miss", "%s: cerrar sin el portal → bo_miss" % cid)
		# Trampa: correo a Vitzo (cualquier plantilla).
		cm = await _open(t, c)
		deaths.clear()
		cm.kardex_lookup(str(c.get("tx", "")))
		cm.set_recipient("Vitzo")
		cm.set_template("POD request" if cid == "vz_pod" else "Status")
		var opts: Dictionary = c.get("opciones_campos", {})
		for f in CasoBO.FIELDS:
			cm.set_field(f, str((opts.get(f, [""]) as Array)[0]))
		cm.send_email()
		await t.frames(2)
		await t.until(func() -> bool: return not deaths.is_empty(), 5.0)  # v0.3.1 Q2: Vitzo sale del monitor antes de matarte
		t.check(deaths.size() >= 1 and str(deaths[0][0]) == "correo_vitzo", "%s: correo a Vitzo → muerte correo_vitzo (%s)" % [cid, str(deaths)])
		await t.wait_death_shown(8.0)
		await t.reconnect()
	# T3: el aviso del portal pone a Vitzo de destinatario (trampa).
	var cr := case_by_id("vz_reversal")
	var cm2: ContactManager = await _open(t, cr)
	cm2.portal_search("KP-2404-5562")
	t.check(bool(cm2.portal_view.get("banner", false)), "vz_reversal: el portal muestra el aviso 'escríbanos a ops@vitzo.kp'")
	cm2.open_mailto_vitzo()
	t.check(cm2.case.recipient == "Vitzo", "el enlace del aviso pone a Vitzo como destinatario")


func _no_expira(t: Node) -> void:
	var c := case_by_id("t1_correo_pod")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var cm := _cm(t)
	var outcomes: Array = t.spy("contact_outcome")
	cm._offer(c.duplicate(true))
	t.player().stand_up()
	await t.seconds(float(DataLoader.dict("casos_bo").get("reglas", {}).get("timbre_s_real", 14.0)) * 1.5)
	t.check(cm.phase == ContactManager.Phase.OFFERING and outcomes.is_empty() and cm.missed_count == 0, "un caso BO ofrecido no se pierde aunque estés de pie")
	await t.login_at_seat()
	cm.accept()
	t.player().stand_up()
	await t.seconds(3.0)
	t.check(cm.is_active() and cm.case != null and outcomes.is_empty(), "un caso BO abierto sigue abierto aunque te pares")


func _perdidas(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var cm := _cm(t)
	var outcomes: Array = t.spy("contact_outcome")
	var posts: Array = t.spy("ezlak_post")
	var deaths: Array = t.spy("death_requested")
	var call: Dictionary = (DataLoader.dict("contactos_t1").get("contactos", [])[0] as Dictionary).duplicate(true)
	t.player().stand_up()
	await t.frames(2)
	var ring := float(DataLoader.dict("casos_bo").get("reglas", {}).get("timbre_s_real", 14.0)) * Difficulty.scale("plazos")
	var owned := ContactManager.discipline_owns("llamadas_perdidas")
	var ww0 := Metrics.written_warnings
	for n in 4:
		cm.phase = ContactManager.Phase.IDLE
		var cc := call.duplicate(true)
		cc["id"] = "perdida_%d" % n
		cm._offer(cc)
		# P7: el WW de la 3.ª perdida abre el Ack; sin darlo, "WW sin Ack" lanza a Shero y con la máquina cargada
		# llegaba a alcanzarte antes de la 4.ª (muerte ww_sin_ack en vez de llamadas_perdidas). Se da el Ack en cuanto
		# aparece, como haría un jugador, para que la prueba mida solo la pista de llamadas perdidas.
		await t.until(func() -> bool:
			if Metrics.ack_pending:
				Metrics.give_ack()
			return cm.phase != ContactManager.Phase.OFFERING, ring + 4.0)
		await t.frames(2)
		t.check(cm.missed_count == n + 1, "llamada %d sin contestar → perdida (missed_count %d)" % [n + 1, cm.missed_count])
		if n == 0 and not owned:
			var shero_dm := false
			for p in posts:
				if str(p[0]) == "dm:shero" and str(p[3].get("pista", "")) == "llamadas_perdidas":
					shero_dm = true
			t.check(shero_dm, "1.ª perdida: llamado de Shero por DM")
		if n == 2 and not owned:
			t.check(Metrics.written_warnings >= ww0 + 1, "3.ª perdida: written warning (WW %d → %d, missed %d)" % [ww0, Metrics.written_warnings, cm.missed_count])
			if Metrics.ack_pending:
				Metrics.give_ack()
	var perdidos := 0
	for o in outcomes:
		if str(o[1]) == "perdido":
			perdidos += 1
	t.check(perdidos == 4, "4 contact_outcome 'perdido' (para la pista de P3)")
	if owned:
		t.note("Discipline.owns_track('llamadas_perdidas') = true: la escalera la ejecuta P3")
	else:
		t.check(deaths.size() >= 1 and str(deaths[0][0]) == "llamadas_perdidas", "4.ª perdida → muerte llamadas_perdidas (%s)" % str(deaths))
		await t.wait_death_shown(8.0)
		await t.reconnect()

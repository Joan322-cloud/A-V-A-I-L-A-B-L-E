## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P5 · personajes con reglas (PLAN §10 P5): Haime (feedback, 3.º = calibracion_final,
## inasistencia), Trainer (training, quiz con el reloj pausado, reprobado, inasistencia, escapa, dificultad),
## Rasec (música, evento con BO, advertencias y muerte, actor de sus muertes por coaching), tópico (permiso,
## 2.º pedido = work_avoiding, sin permiso), Perrito RTA (órdenes, strikes y caza en el 2 y en el -1,
## corregir cancela, sin break_excedido, cupo de baño, tags a compañeros) y Don Fermín (revisión).
## Cada muerte comprueba causa, asesino y que el screamer termina antes de la pantalla.
## Para aislar cada regla: ContactManager y Shero (v0.2, hasta que P3 lo reemplace) quedan apagados, los
## WW se confirman solos y el recordatorio de Vitzo se reacciona solo.

var _conns: Array = []


func escenarios() -> Array[String]:
	return [
		"p5_feedback_qa", "p5_feedback_qa_3", "p5_qa_noshow", "p5_qa_llega_a_tiempo", "p5_feedback_congela", "p5_qa_rec", "p5_feedback_tras_muerte",
		"p5_training", "p5_training_quiz", "p5_training_reprobado", "p5_training_dificultad", "p5_training_falta", "p5_training_escapa",
		"p5_rasec_musica", "p5_rasec_evento", "p5_rasec_evento_rta", "p5_rasec_rechazo", "p5_rasec_sin_bo", "p5_rasec_tarde", "p5_rasec_sillas_fallo", "p5_rasec_coaching",
		"p5_topico", "p5_topico_dos", "p5_topico_sin_permiso", "p5_topico_cerrado_t1",
		"p5_rta_strikes", "p5_rta_strikes_m1", "p5_rta_corrige", "p5_rta_sin_break", "p5_rta_ordenes", "p5_rta_continuo",
		"p5_guardia", "p5_guardia_t3", "p5_hub_persistente",
	]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p5_feedback_qa": await _feedback(t)
		"p5_feedback_qa_3": await _feedback_3(t)
		"p5_qa_noshow": await _qa_noshow(t)
		"p5_qa_llega_a_tiempo": await _qa_a_tiempo(t)
		"p5_feedback_congela": await _feedback_congela(t)
		"p5_qa_rec": await _qa_rec(t)
		"p5_feedback_tras_muerte": await _feedback_tras_muerte(t)
		"p5_training": await _training(t, false)
		"p5_training_quiz": await _training(t, true)
		"p5_training_reprobado": await _training_reprobado(t)
		"p5_training_dificultad": await _training_dificultad(t)
		"p5_training_falta": await _training_falta(t)
		"p5_training_escapa": await _training_escapa(t)
		"p5_rasec_musica": await _rasec_musica(t)
		"p5_rasec_evento": await _rasec_evento(t)
		"p5_rasec_evento_rta": await _rasec_evento_rta(t)
		"p5_rasec_rechazo": await _rasec_rechazo(t)
		"p5_rasec_sin_bo": await _rasec_sin_bo(t)
		"p5_rasec_tarde": await _rasec_tarde(t)
		"p5_rasec_sillas_fallo": await _rasec_sillas_fallo(t)
		"p5_rasec_coaching": await _rasec_coaching(t)
		"p5_topico": await _topico(t)
		"p5_topico_dos": await _topico_dos(t)
		"p5_topico_sin_permiso": await _topico_sin_permiso(t)
		"p5_topico_cerrado_t1": await _topico_t1(t)
		"p5_rta_strikes": await _rta_strikes(t, 2)
		"p5_rta_strikes_m1": await _rta_strikes(t, -1)
		"p5_rta_corrige": await _rta_corrige(t)
		"p5_rta_sin_break": await _rta_sin_break(t)
		"p5_rta_ordenes": await _rta_ordenes(t)
		"p5_rta_continuo": await _rta_continuo(t)
		"p5_guardia": await _guardia(t, 1)
		"p5_guardia_t3": await _guardia(t, 3)
		"p5_hub_persistente": await _hub_persistente(t)
	for c in _conns:
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	_conns.clear()


# --- ayudas ---------------------------------------------------------------------------------------

func _on_ack(_s: float) -> void:
	Metrics.give_ack()


func _on_vitzo(_e: String, _s: float) -> void:
	EventBus.vitzo_reacted.emit()


## Turno T sentado en C-14 (o en la calle) con el resto del mundo neutralizado.
func _prep(t: Node, turno: int, seat: bool = true, dif: int = 1) -> PersonajesP5:
	await t.start_shift("Jiroshi", turno, 0, dif)
	if not EventBus.ack_window_opened.is_connected(_on_ack):
		EventBus.ack_window_opened.connect(_on_ack)
		_conns.append(["ack_window_opened", _on_ack])
	if not EventBus.vitzo_reminder.is_connected(_on_vitzo):
		EventBus.vitzo_reminder.connect(_on_vitzo)
		_conns.append(["vitzo_reminder", _on_vitzo])
	var cm := t.main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	if seat:
		await t.login_at_seat()
		_quiet(t)
	GameState.stop_calm()
	return PersonajesP5.get_hub(t.get_tree())


## Shero v0.2 (hasta P3) apagado en el piso cargado.
func _quiet(t: Node) -> void:
	for s in t.get_tree().get_nodes_in_group("shero"):
		(s as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _floor(t: Node, n: int, spawn: String = "ascensor") -> void:
	t.building().go_to_floor(n, spawn)
	await t.frames(3)
	_quiet(t)


func _sit(t: Node, seat_id: String) -> bool:
	var fl := t.building().floor_node as FloorBase
	var s := fl.find_child("Seat_" + seat_id, true, false) as Node3D if fl != null else null
	if s == null:
		return false
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	p.sit_at(s, seat_id)
	await t.frames(2)
	return true


func _to_marker(t: Node, m: String, off: Vector3 = Vector3.ZERO) -> void:
	var n := (t.building().floor_node as Node).find_child(m, true, false) as Node3D
	if n != null:
		t.player().teleport(n.global_position + off, 0.0)
	await t.frames(2)


## Último mensaje de un canal de Ezlaki (espera el "escribiendo…").
func _last_msg(t: Node, ch: String) -> Dictionary:
	var hubz := EzlakHub.get_hub(t.get_tree())
	await t.until(func() -> bool: return not hubz.messages(ch).is_empty(), 5.0)
	var ms := hubz.messages(ch)
	return ms[ms.size() - 1] if not ms.is_empty() else {}


func _bad_contact(marks: Array, outcome: String = "neutral") -> void:
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t1c1":
			c = (x as Dictionary).duplicate(true)
	c["_qa"] = marks
	c["_choices"] = ["inicio.c", "repite_fuerte.a"]
	EventBus.contact_outcome.emit(c, outcome, 1)


## Comprueba la secuencia de muerte: causa, asesino, screamer antes de la pantalla.
func _check_death(t: Node, seq: Array, scr: Array, cause: String, killer: String, timeout_s: float = 10.0) -> void:
	var ok: bool = await t.until(func() -> bool: return not seq.is_empty(), timeout_s)
	t.check(ok, "muerte '%s' pedida" % cause)
	if not ok:
		return
	var last: Array = seq[seq.size() - 1]
	t.check(str(last[0]) == cause and str(last[1]) == killer, "%s con asesino %s (hay %s / %s)" % [cause, killer, str(last[0]), str(last[1])])
	var shown: bool = await t.wait_death_shown(8.0)
	t.check(shown and scr.has([cause]), "screamer de %s y luego 'Usuario desconectado'" % killer)


func _call_haime(t: Node, hub: PersonajesP5, marks: Array = ["prometer_sin_verificar", "respuesta_vaga"]) -> void:
	_bad_contact(marks)
	await t.frames(1)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE, "contacto malo → Haime programa la llamada")
	var dt := hub.qa.call_at - GameState.clock_seconds
	t.check(dt >= 5.0 * 60.0 - 1.0 and dt <= 15.0 * 60.0 + 1.0, "llama 5-15 min de juego después (en %.1f min)" % (dt / 60.0))
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 3.0)


func _go_calibration(t: Node) -> void:
	Metrics.set_aux(Metrics.Aux.COACHING)
	if t.building().current_floor != 2:
		await _floor(t, 2)
	await _sit(t, "calibracion")


# --- Haime ----------------------------------------------------------------------------------------

func _feedback(t: Node) -> void:
	var hub := await _prep(t, 1)
	var called: Array = t.spy("qa_feedback_called")
	var started: Array = t.spy("qa_feedback_started")
	var ended: Array = t.spy("qa_feedback_ended")
	var seq: Array = t.spy("death_sequence_started")
	await _call_haime(t, hub)
	t.check(called.size() == 1 and int(called[0][0]) == 1, "qa_feedback_called(1)")
	var dm: Dictionary = await _last_msg(t, "dm:haime")
	t.check(str(dm.get("tipo", "")) == "qa_llamado" and (dm.get("quick_replies", []) as Array).has("voy"), "DM de Haime en dm:haime con 'Voy'")
	t.check(Metrics.is_aux_authorized(Metrics.Aux.COACHING) and Metrics.is_authorized("sala_calibracion"), "autoriza Coaching y la sala de calibración")
	await t.frames(2)
	t.check(hub.qa.rec._root.visible, "el punto REC te sigue mientras no llegas")
	# v0.3.1 (F4): sentarse sin Coaching ya no te levanta: la silla no tiene PC y Haime te pone en Coaching él.
	await _floor(t, 2)
	hub.qa.test_opts = {"apertura": "intro"}  # v0.3.2: la apertura es al azar; aquí se comprueba la intro del tipo
	await _sit(t, "calibracion")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "sentado sin Coaching: Haime te pone en Coaching y empieza la sesión")
	t.check(Metrics.aux == Metrics.Aux.COACHING, "AUX Coaching")
	t.check(started.size() == 1 and Discipline.is_frozen() and GameState.clock_override == "feedback" and hub.busy == "feedback", "sesión: Discipline congelada, reloj 'feedback', nadie más interviene")
	t.check(t.player().input_locked, "en la sesión no te puedes ir")
	t.check(await t.until(func() -> bool: return not ended.is_empty(), 120.0), "la sesión termina (~50 s reales)")
	t.check(seq.is_empty(), "el 1.er feedback no mata")
	t.check(hub.qa.feedbacks_done() == 1 and not Discipline.is_frozen() and GameState.clock_override == "" and hub.busy == "", "1 feedback contado; todo descongelado")
	# v0.3.1 (F4): la silla de calibración no tiene PC: queda un permiso corto para volver a tu puesto en Coaching;
	# vence solo o al poner otro AUX (después, quedarse en Coaching vuelve a ser la pista de Rasec, P3).
	var back := Metrics.authorization_of("qa")
	t.check(not back.is_empty() and float(back.get("until", INF)) <= GameState.clock_seconds + float(DataLoader.dict("qa_haime").get("regreso_min", 6.0)) * 60.0 + 1.0, "al terminar queda solo el permiso de vuelta (%s)" % str(back))
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(not Metrics.is_aux_authorized(Metrics.Aux.COACHING) and Metrics.authorization_of("qa").is_empty(), "al poner otro AUX se revoca la autorización")
	var said := hub.qa.session_log
	# v0.3.1 Q4: el guion es personalizado (HaimeGuion): intro por tipo de caso, repaso del caso, una línea por marca real.
	# v0.3.2: estructura al azar (HaimeGuion.build_session); el cierre de la 1.ª sale de cierre_1 o fb1_cierre.
	var has_pre := func(pre: String) -> bool: return said.any(func(k: Variant) -> bool: return str(k).begins_with(pre))
	t.check(has_pre.call("q4_in_llamada_1_") and has_pre.call("q4_caso_") and (said.has("fb1_cierre") or has_pre.call("h2_c1_")) and (has_pre.call("q4_om_prometer_sin_verificar") or has_pre.call("q4_om_respuesta_vaga")), "guion fb1 (%s)" % str(said))
	hub.qa.test_opts = {}
	var ops: Dictionary = DataLoader.dict("qa_haime").get("oportunidades", {})
	t.check(Loc.pick(ops.get("prometer_sin_verificar", {})) != "", "las marcas de QA tienen su 'oportunidad de mejora'")
	t.check(not t.player().input_locked, "al terminar recuperas el control")


func _feedback_3(t: Node) -> void:
	var hub := await _prep(t, 2)
	var maxn: int = hub.qa.max_per_shift()  # v0.3.1 (D2): 4 en Normal (la fatal), 3 en Difícil
	PersonajesP5.set_counter("p5_qa_feedbacks", maxn - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _call_haime(t, hub, ["dato_personal"])
	t.check(hub.qa.n_call == maxn, "última llamada del turno (n=%d de %d)" % [hub.qa.n_call, maxn])
	await _go_calibration(t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "3.er feedback empieza")
	await t.until(func() -> bool: return not seq.is_empty(), 120.0)
	t.check(hub.qa.session_log.has("fb3_cierre") and hub.qa.session_log.any(func(k: Variant) -> bool: return str(k).begins_with("q4_caso_")), "guion fb3 completo antes de matar (%s)" % str(hub.qa.session_log))
	await _check_death(t, seq, scr, "calibracion_final", "haime")
	t.check(Screamers.row_for("haime", "calibracion_final").get("variante", "") == "rec", "screamer REC de Haime")
	await t.reconnect()
	t.check(not Discipline.is_frozen() and hub.busy == "" and not t.player().input_locked, "tras reconectar no queda nada congelado")


## Una muerte en plena sesión deja la corrutina vieja dormida en la pausa de su línea; al reconectar y volver
## a la sala, la sesión nueva no debe romperse cuando esa corrutina despierta.
func _feedback_tras_muerte(t: Node) -> void:
	var hub := await _prep(t, 1)
	var started: Array = t.spy("qa_feedback_started")
	var ended: Array = t.spy("qa_feedback_ended")
	await _call_haime(t, hub)
	await _go_calibration(t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "1.ª sesión")
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 2, 20.0)  # llegaste + intro (guion de HaimeGuion)
	Checkpoints.request_death("colapso", "", "")
	await t.wait_death_shown(10.0)
	t.check(hub.qa.state == QaFeedback.State.LIBRE and hub.qa.ui == null and not Discipline.is_frozen(), "la muerte corta la sesión y limpia")
	await t.reconnect()
	_quiet(t)
	GameState.stop_calm()
	await t.frames(2)
	hub.qa.call_now()
	await _go_calibration(t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION and started.size() == 2, 3.0), "sesión nueva tras reconectar")
	var ui_new := hub.qa.ui
	await t.seconds(8.0)  # la corrutina vieja despierta en este rato
	t.check(hub.qa.state == QaFeedback.State.SESION and hub.qa.ui == ui_new and is_instance_valid(ui_new), "la corrutina vieja no toca la sesión nueva")
	t.check(await t.until(func() -> bool: return not ended.is_empty(), 120.0), "la sesión nueva termina normal")
	t.check(not Discipline.is_frozen() and hub.busy == "" and not t.player().input_locked, "todo descongelado")


func _qa_noshow(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _call_haime(t, hub)
	GameState.set_clock_override("quiz")  # reloj quieto: solo avanza con set_clock (determinista)
	var t0 := hub.qa.called_at
	# v0.3.2-core4: el plazo de Haime pasa de 5 / 8 min a 2 / 4 (qa_haime.json: aviso_noshow_min, margen_llegada_min).
	await t.set_clock(t0 + 1.9 * 60.0)
	await t.frames(2)
	t.check(not hub.qa.noshow_warned and seq.is_empty(), "a los 1:54 todavía nada")
	await t.set_clock(t0 + 2.0 * 60.0 + 1.0)
	await t.frames(2)
	var dm: Dictionary = await _last_msg(t, "dm:haime")
	t.check(hub.qa.noshow_warned and str(dm.get("tipo", "")) == "qa_noshow", "2:00 DM 'Te estoy esperando… la grabación también te espera'")
	await t.set_clock(t0 + 3.9 * 60.0)
	await t.frames(2)
	t.check(seq.is_empty(), "a los 3:54 sigue vivo")
	await t.set_clock(t0 + 4.0 * 60.0 + 1.0)
	await _check_death(t, seq, scr, "qa_inasistencia", "haime")
	t.check(hub.qa.feedbacks_done() == 0, "la inasistencia no cuenta como uno de sus 3 feedbacks")


func _qa_a_tiempo(t: Node) -> void:
	var hub := await _prep(t, 1, true, 2)  # Difícil: el margen es 4 × 0,75 = 3 min (v0.3.2-core4; antes 8 × 0,75 = 6)
	var seq: Array = t.spy("death_sequence_started")
	await _call_haime(t, hub)
	t.check(absf(hub.qa.seconds_left() - 3.0 * 60.0) < 5.0, "Difícil: 3 min para llegar (hay %.1f)" % (hub.qa.seconds_left() / 60.0))
	await t.set_clock(hub.qa.called_at + 2.0 * 60.0)
	await _go_calibration(t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "llegar a los 2 min → sesión normal")
	await t.set_clock(hub.qa.called_at + 30.0 * 60.0)
	await t.frames(3)
	t.check(seq.is_empty(), "una vez en la sesión el plazo ya no corre")


func _feedback_congela(t: Node) -> void:
	var hub := await _prep(t, 3)
	var freezes: Array = t.spy("freeze_discipline")
	await _call_haime(t, hub)
	await _go_calibration(t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)
	t.check(freezes.has([true, "feedback"]), "freeze_discipline(true, 'feedback')")
	t.check(not hub.can_interrupt(), "con el feedback en curso nadie de P5 interrumpe")
	# El RTA no taguea durante la sesión aunque el AUX esperado sea otro.
	Metrics.expected_aux = Metrics.Aux.BO
	t.check(hub.rta.wrong_reason() == "", "el RTA no mira durante el feedback")
	# El evento de Rasec no se convoca durante la sesión.
	hub.rasec.state = RasecControl.State.LIBRE
	await t.set_clock(maxf(GameState.clock_seconds, hub.rasec.event_clock()))
	await t.frames(3)
	t.check(hub.rasec.state == RasecControl.State.LIBRE, "Rasec espera a que termine el feedback")
	Metrics.expected_aux = Metrics.Aux.AVAILABLE
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 120.0)
	t.check(freezes.has([false, "feedback"]) and not Discipline.is_frozen(), "al terminar se descongela")


func _qa_rec(t: Node) -> void:
	var hub := await _prep(t, 1)
	t.check(QaFeedback.bad_marks({"_qa": []}, "satisfecho").is_empty(), "contacto bueno: sin marcas")
	t.check(QaFeedback.bad_marks({"_qa": []}, "molesto") == ["molesto"], "molesto = malo")
	t.check(QaFeedback.bad_marks({"_qa": []}, "bo_miss") == ["bo_miss"], "caso BO mal resuelto = malo")
	t.check(QaFeedback.bad_marks({"_qa": ["calmese"]}, "satisfecho") == ["calmese"], "satisfecho con marca de QA = malo")
	t.check(QaFeedback.bad_marks({"_qa": []}, "perdido").is_empty(), "llamada perdida no es de QA (es de Shero)")
	hub.qa.contacts_seen = 0
	EventBus.contact_accepted.emit({"id": "x"})
	t.check(hub.qa.monitored, "el 1.er contacto lleva REC (1 de cada 3)")
	EventBus.contact_ended.emit({"id": "x"}, true, false)
	EventBus.contact_accepted.emit({"id": "y"})
	t.check(not hub.qa.monitored, "el 2.º no")
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t1c1":
			c = x
	c = c.duplicate(true)
	c["_choices"] = ["inicio.c"]
	var tr := QaFeedback.transcript(c)
	t.check(tr.size() == 2 and str(tr[1].get("qa", "")) == "respuesta_sin_revisar", "transcripción con la opción marcada (%d líneas)" % tr.size())


# --- Trainer --------------------------------------------------------------------------------------

func _training_call(t: Node, hub: PersonajesP5) -> void:
	var called: Array = t.spy("training_called")
	await t.set_clock(GameState.training_clock() + 2.0)
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.LLAMADO, 3.0), "a la hora del training (%s) el Trainer convoca" % GameState.clock_text_at(GameState.training_clock()))
	t.check(called.size() == 1, "training_called")
	t.check(Metrics.is_aux_authorized(Metrics.Aux.TRAINING) and Metrics.is_authorized("piso_1"), "autoriza Training y el piso 1")
	t.check(Metrics.expected_aux == Metrics.Aux.TRAINING, "el RTA dicta Training")
	var dm: Dictionary = await _last_msg(t, "dm:trainer")
	t.check(str(dm.get("tipo", "")) == "training_llamado", "DM del Trainer")


func _training_arrive(t: Node, hub: PersonajesP5) -> void:
	Metrics.set_aux(Metrics.Aux.TRAINING)
	await _floor(t, 1)
	await _sit(t, "training_sala2_3")
	await t.until(func() -> bool: return hub.training.state == TrainingControl.State.SESION, 3.0)


func _training(t: Node, quiz_focus: bool) -> void:
	var hub := await _prep(t, 2)
	var started: Array = t.spy("training_started")
	var ended: Array = t.spy("training_ended")
	var answered: Array = t.spy("quiz_answered")
	var seq: Array = t.spy("death_sequence_started")
	await _training_call(t, hub)
	await t.set_clock(GameState.clock_seconds + 3.0 * 60.0)
	await _training_arrive(t, hub)
	t.check(started.size() == 1 and hub.training.state == TrainingControl.State.SESION, "llega en < 8 min y se sienta en la sala 2 → sesión")
	t.check(Discipline.is_frozen() and is_equal_approx(GameState.clock_speed(), 24.0), "sesión: Discipline congelada y reloj 24x (v0.3.1; hay %.1f)" % GameState.clock_speed())
	hub.training.forced_answers = [-1, -1, -1, -2, -2]  # 3/5 en Normal: aprueba
	hub.training.session_at -= 21.9 * 60.0
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0), "a los 22 min de sesión, el quiz")
	t.check(hub.training.said.has("clase_2") and hub.training.said.has("clase_4"), "dio la clase antes del quiz (%s)" % str(hub.training.said))
	var c0 := GameState.clock_seconds
	t.check(is_equal_approx(GameState.clock_speed(), 0.0), "el quiz PAUSA el reloj (velocidad %.1f)" % GameState.clock_speed())
	t.check(t.player().input_locked and hub.training.quiz != null and hub.training.quiz.questions.size() == 5, "quiz de 5 preguntas, control bloqueado")
	if quiz_focus:
		var cats: Dictionary = {}
		for q in hub.training.quiz.questions:
			cats[str(q.get("cat", ""))] = true
		t.check(cats.has("kyc") and cats.has("vitzo") and cats.has("aux") and cats.has("proceso"), "mezcla KYC, Vitzo, AUX y proceso (%s)" % str(cats.keys()))
	t.check(await t.until(func() -> bool: return answered.size() == 5, 20.0), "5 respuestas")
	t.check(absf(GameState.clock_seconds - c0) < 0.01, "el reloj no avanzó entre la primera y la última respuesta (%.2f s de juego)" % (GameState.clock_seconds - c0))
	await t.until(func() -> bool: return hub.training.last_score >= 0, 5.0)
	t.check(hub.training.last_score == 3, "3/5 (hay %d)" % hub.training.last_score)
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.SESION and hub.training.quiz == null, 6.0), "aprobado: vuelve la clase")
	t.check(is_equal_approx(GameState.clock_speed(), 24.0), "tras el quiz el reloj sigue a 24x (v0.3.1)")
	hub.training.session_at -= 10.0 * 60.0
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.HECHO, 6.0), "a los 30 min te suelta")
	t.check(ended.size() == 1 and bool(ended[0][0]), "training_ended(true) al soltarte (la vuelta tardía es de P3)")
	t.check(not Discipline.is_frozen() and not Metrics.is_aux_authorized(Metrics.Aux.TRAINING) and GameState.clock_override == "", "descongela, revoca Training, reloj normal")
	t.check(hub.training.done() and seq.is_empty(), "training hecho, 0 muertes")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(Metrics.expected_aux == Metrics.Aux.AVAILABLE, "al salir de Training el RTA vuelve a esperar Available")


func _training_reprobado(t: Node) -> void:
	var hub := await _prep(t, 3)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _training_call(t, hub)
	await _training_arrive(t, hub)
	hub.training.forced_answers = [-1, -1, -2, -2, -2]
	hub.training.session_at -= 21.9 * 60.0
	await t.until(func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0)
	await _check_death(t, seq, scr, "training_reprobado", "trainer", 30.0)
	t.check(not seq.is_empty() and str(seq[seq.size() - 1][2]) == "2/5", "detalle '2/5' (hay %s)" % (str(seq[seq.size() - 1][2]) if not seq.is_empty() else ""))
	t.check(hub.training.said.has("reprobado"), "'El mínimo era 3. Tú sacaste 2.'")
	await t.reconnect()
	t.check(not Discipline.is_frozen() and GameState.clock_override == "" and not hub.training.done(), "tras reconectar: nada congelado; el training queda por hacer")


func _training_dificultad(t: Node) -> void:
	for pair in [[0, [-1, -1, -2, -2, -2], true], [2, [-1, -1, -1, -2, -2], false]]:
		var hub := await _prep(t, 2, true, int(pair[0]))
		var seq: Array = t.spy("death_sequence_started")
		await _training_call(t, hub)
		await _training_arrive(t, hub)
		hub.training.forced_answers = pair[1]
		hub.training.session_at -= 21.9 * 60.0
		await t.until(func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0)
		if int(pair[0]) == 0:
			t.check(hub.training.quiz.hint and hub.training.quiz.need == 2, "Fácil: aprobar con 2/5 y con pista")
		else:
			t.check(not hub.training.quiz.hint and hub.training.quiz.need == 4, "Difícil: 4/5 sin pista")
		var passed: bool = pair[2]
		if passed:
			t.check(await t.until(func() -> bool: return hub.training.quiz == null and hub.training.state == TrainingControl.State.SESION, 20.0) and seq.is_empty(), "Fácil 2/5 aprueba")
		else:
			t.check(await t.until(func() -> bool: return not seq.is_empty(), 25.0) and str(seq[0][0]) == "training_reprobado", "Difícil 3/5 reprueba")
		await t.back_to_menu()


func _training_falta(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var hunts: Array = t.spy("pursuit_started")
	var entered: Array = t.spy("hunter_entered_floor")
	await _training_call(t, hub)
	var t0 := hub.training.called_at
	# v0.3.2-core4: el Trainer avisa a los 3 min y sale a los 5 (training.json: espera_min, persecucion_min; antes 8 y 12).
	await t.set_clock(t0 + 2.9 * 60.0)
	await t.frames(2)
	t.check(not hub.training.espera_warned and hunts.is_empty(), "a los 2:54 todavía nada")
	await t.set_clock(t0 + 3.0 * 60.0 + 1.0)
	await t.frames(2)
	t.check(hub.training.espera_warned and hunts.is_empty(), "3 min: 'Te estoy esperando'")
	await t.set_clock(t0 + 5.0 * 60.0 + 1.0)
	await t.frames(2)
	t.check(hunts.size() == 1 and str(hunts[0][0]) == "trainer" and str(hunts[0][1]) == "training_inasistencia", "5 min: el Trainer te persigue")
	t.player().stand_up()
	t.check(await t.until(func() -> bool: return not entered.is_empty(), 40.0), "llega al piso 2 (ascensor: 20 s + 6 s por piso)")
	t.check(not entered.is_empty() and int(entered[0][1]) == 2, "hunter_entered_floor(trainer, 2)")
	await _check_death(t, seq, scr, "training_inasistencia", "trainer", 90.0)


func _training_escapa(t: Node) -> void:
	var hub := await _prep(t, 3)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _training_call(t, hub)
	await _training_arrive(t, hub)
	t.player().stand_up()
	await _to_marker(t, "training_sala2", Vector3(-6.0, 0, 2.5))
	await t.frames(3)
	t.check(hub.training.escape_at >= 0.0 and hub.training.said.has("escapa"), "te paras y te vas: '¿A dónde vas?'")
	t.check(GameState.clock_override == "", "fuera de la sala el reloj vuelve al de pie (1 min de gracia = 15 s reales)")
	await t.set_clock(hub.training.escape_at + 61.0)
	await t.frames(2)
	t.check(hub.training.state == TrainingControl.State.PERSIGUE, "1 min fuera → persecución")
	await _check_death(t, seq, scr, "training_inasistencia", "trainer", 90.0)


# --- Rasec ----------------------------------------------------------------------------------------

func _rasec_actor(t: Node) -> P5Actor:
	var n := t.get_tree().get_first_node_in_group("p5_rasec_actor")
	return n.get("actor") as P5Actor if n != null else null


func _rasec_musica(t: Node) -> void:
	var hub := await _prep(t, 2)
	var a := _rasec_actor(t)
	t.check(a != null and not a.has_hair(), "Rasec en la sala, calvo")
	var horas: Array = (DataLoader.dict("rasec_eventos").get("musica", {}) as Dictionary).get("horas", {}).get("2", [])
	await t.set_clock(GameState.hhmm_to_seconds(str(horas[0])) + 1.0)
	t.check(await t.until(func() -> bool: return hub.rasec.music_on, 3.0), "a las %s pone música" % str(horas[0]))
	t.check(a.has_hair(), "con música: pelo (nodo Pelo visible)")
	await t.set_clock(hub.rasec.music_until + 1.0)
	t.check(await t.until(func() -> bool: return not hub.rasec.music_on, 3.0), "se corta a los 6-9 min")
	t.check(not a.has_hair(), "sin música: calvo")


func _rasec_call(t: Node, hub: PersonajesP5) -> void:
	# v0.3.2-core2: a la hora del evento la clase del Trainer (T2/T3) ya pasó hace horas. Sin esto el salto de reloj
	# la convocaba en el mismo cuadro y, desde «de a uno» (v0.3.2-core), Rasec espera a que no haya otro llamado
	# pendiente: en la prueba el evento no llegaba a convocarse (jugando no pasa: la clase se da a su hora).
	if hub.training != null and hub.training.state == TrainingControl.State.LIBRE:
		hub.training.state = TrainingControl.State.HECHO
	# Solo el evento de Rasec. Desde la v0.3.2 te convocan de a uno (hub.summon_pending): al saltar el reloj hasta el
	# evento, el llamado de Haime de las 5:14 (o el del Trainer) cae antes y el evento lo espera, que es lo correcto
	# en el juego (lo prueba core_convocan_de_a_uno) pero no es lo que miden estas pruebas.
	for other in [hub.qa, hub.training]:
		if other != null:
			(other as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await t.set_clock(hub.rasec.event_clock() + 1.0)
	t.check(await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.CONVOCADO, 3.0), "a las %s Rasec convoca su evento" % GameState.clock_text_at(hub.rasec.event_clock()))
	t.check(Metrics.authorization_of("tm").get("aux", -1) == Metrics.Aux.BO, "autoriza BO (fuente tm)")


func _rasec_evento(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var site: Array = t.spy("ezlak_post")
	GameState.flags["p5_tema"] = "halloween"
	# Algo de Available antes para ver que el BO del evento lo baja.
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.advance_clock(40.0 * 60.0)
	await _rasec_call(t, hub)
	var announced := false
	for p in site:
		if str(p[0]) == "#site-updates" and str(p[1]) == "rasec" and str(p[2]).contains("Halloween"):
			announced = true
	t.check(announced, "anuncio en #site-updates con el tema (Halloween)")
	var dm: Dictionary = await _last_msg(t, "dm:rasec")
	t.check((dm.get("quick_replies", []) as Array).has("no_gracias"), "DM de Rasec: 'pasa a BO y ven al centro' con Voy / No, gracias")
	var avl0 := Metrics.available_pct()
	hub.rasec.forced_play = "ok"
	Metrics.set_aux(Metrics.Aux.BO)
	t.player().stand_up()
	await _to_marker(t, "evento_rasec")
	t.check(await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.EVENTO, 3.0), "BO + centro de la sala → empieza el karaoke")
	t.check(hub.rasec.kind == "karaoke" and hub.busy == "evento", "T1 = karaoke")
	var a := _rasec_actor(t)
	t.check(a != null and a.has_hair(), "en el evento Rasec lleva pelo")
	t.check(await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.HECHO, 90.0), "el evento termina (4-5 min de juego)")
	t.check(hub.rasec.warnings() == 0 and seq.is_empty(), "participar = 0 advertencias, 0 muertes")
	t.check(Metrics.available_pct() < avl0 - 0.5, "el BO del evento bajó el Available (%.1f → %.1f)" % [avl0, Metrics.available_pct()])
	t.check(Metrics.authorization_of("tm").is_empty() and hub.busy == "", "al terminar se revoca la autorización")
	t.check((hub.rasec.ui == null) and (hub.rasec.said.has("fin_evento")), "fin del evento")


func _rasec_evento_rta(t: Node) -> void:
	var hub := await _prep(t, 2)
	await _rasec_call(t, hub)
	Metrics.set_aux(Metrics.Aux.BO)
	Metrics.expected_aux = Metrics.Aux.AVAILABLE
	t.check(hub.rta.wrong_reason() == "", "en el BO del evento (tm) el RTA no taguea")
	Metrics.revoke("tm")
	t.check(hub.rta.wrong_reason() == "aux", "sin la autorización del evento, BO sin allocation sí es AUX incorrecto")


func _rasec_rechazo(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var warns: Array = []
	hub.rasec_warning.connect(func(n: int, r: String) -> void: warns.append([n, r]))
	await _rasec_call(t, hub)
	EzlakHub.get_hub(t.get_tree()).quick_reply("dm:rasec", "no_gracias")
	await t.frames(2)
	t.check(warns.size() == 1 and str(warns[0][1]) == "rechazo" and seq.is_empty(), "'No, gracias' = primera advertencia")
	t.check(hub.rasec.state == RasecControl.State.CONVOCADO, "te sigue esperando")
	EzlakHub.get_hub(t.get_tree()).quick_reply("dm:rasec", "no_gracias")
	await _check_death(t, seq, scr, "rasec_evento", "rasec")


func _rasec_sin_bo(t: Node) -> void:
	var hub := await _prep(t, 3)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _rasec_call(t, hub)
	t.player().stand_up()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _to_marker(t, "evento_rasec")
	await t.frames(2)
	t.check(hub.rasec.hinted_bo and hub.rasec.state == RasecControl.State.CONVOCADO, "llegas sin BO: 'Pasa a BO, como te dije'")
	await t.set_clock(hub.rasec.window_at + 2.0 * 60.0 + 1.0)
	await t.frames(2)
	t.check(hub.rasec.warnings() == 1 and hub.rasec.last_result == "advertencia_sin_bo", "2 min sin BO = advertencia")
	await t.set_clock(hub.rasec.window_at + 2.0 * 60.0 + 1.0)
	await _check_death(t, seq, scr, "rasec_evento", "rasec")


func _rasec_tarde(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	await _rasec_call(t, hub)
	if t.player().seated:
		t.player().stand_up()  # v0.3.1 F20 (3): la ventana cuenta de pie (sentado, la mitad: q4_rasec_ventana)
	await t.frames(1)
	await t.set_clock(hub.rasec.window_at + 1.0 * 60.0 + 1.0)
	await t.frames(2)
	t.check(hub.rasec.reminded and seq.is_empty(), "al minuto: 'te estamos esperando… nadie parpadea'")
	await t.set_clock(hub.rasec.window_at + 2.0 * 60.0 + 1.0)
	await t.frames(2)
	t.check(hub.rasec.warnings() == 1 and hub.rasec.last_result == "advertencia_tarde", "no llegar en 2 min = advertencia")
	await t.set_clock(hub.rasec.window_at + 2.0 * 60.0 + 1.0)
	await _check_death(t, seq, scr, "rasec_evento", "rasec")


func _rasec_sillas_fallo(t: Node) -> void:
	var hub := await _prep(t, 3)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	PersonajesP5.set_counter("p5_rasec_adv", 1)  # ya tenía una advertencia en el turno
	await _rasec_call(t, hub)
	hub.rasec.forced_play = "fail"
	Metrics.set_aux(Metrics.Aux.BO)
	t.player().stand_up()
	await _to_marker(t, "evento_rasec")
	t.check(await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.EVENTO and hub.rasec.kind == "sillas", 3.0), "T3: juego de la silla")
	var chairs := t.get_tree().root.find_child("Sillas", true, false)
	await t.until(func() -> bool: return chairs != null and chairs.get_child_count() > 0, 15.0)
	var mine := false
	if chairs != null:
		for c in chairs.get_children():
			for l in c.find_children("*", "Label3D", true, false):
				if (l as Label3D).text == GameState.agent:
					mine = true
	t.check(mine, "una silla tiene tu nombre")
	await _check_death(t, seq, scr, "rasec_evento", "rasec", 30.0)
	t.check(not seq.is_empty() and str(seq[seq.size() - 1][2]) == "fallo", "quedarte de pie = 2.ª advertencia del turno → muerte")


func _rasec_coaching(t: Node) -> void:
	var hub := await _prep(t, 2)
	var a := _rasec_actor(t)
	var before := a.global_position
	EventBus.discipline_step.emit("coaching", 2, {"ejecutor": "rasec"})
	await t.seconds(4.5)
	t.check(a.global_position.distance_to(before) > 1.0, "escalón verbal de coaching: Rasec viene en persona")
	var seq: Array = t.spy("death_sequence_started")
	await t.die("coaching_sin_permiso", "", "rasec")
	t.check(not seq.is_empty() and str(seq[0][1]) == "rasec", "muerte con asesino rasec (la pide P3)")
	t.check(not a.visible, "su actor se esconde: el screamer lo trae a tu cámara")
	await t.wait_death_shown(8.0)
	await t.reconnect()
	await t.frames(3)
	a = _rasec_actor(t)
	t.check(a != null and a.visible and not a.has_hair(), "al reconectar vuelve a su sitio, calvo")
	t.check(hub.rasec.state != RasecControl.State.EVENTO, "sin evento colgado")


# --- tópico ---------------------------------------------------------------------------------------

func _ask_topico(t: Node) -> void:
	EzlakHub.get_hub(t.get_tree()).quick_reply("dm:shero", "me_siento_mal")
	await t.frames(2)


func _topico(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	Fatigue.set_value(60.0)
	await _ask_topico(t)
	t.check(hub.topico.state == TopicoControl.State.PERMISO and hub.topico.requests() == 1, "1.er 'Me siento mal' → permiso")
	t.check(not Metrics.authorization_of("topico").is_empty() and Metrics.is_authorized("topico"), "autorización del tópico (15 min)")
	Metrics.set_aux(Metrics.Aux.BANO)
	await _floor(t, 1)
	await _to_marker(t, "topico", Vector3(0, 0, -0.6))
	t.check(await t.until(func() -> bool: return hub.topico.state == TopicoControl.State.ATENCION, 3.0), "el enfermero te atiende")
	t.check(await t.until(func() -> bool: return hub.topico.state == TopicoControl.State.ALTA, 40.0), "alta")
	t.check(Fatigue.value <= 60.0 - 15.0 * Difficulty.fatigue_rate("recuperacion") + 0.5, "Fatiga −15 × recuperación de la dificultad (v0.3.2) (hay %.1f)" % Fatigue.value)
	t.check(hub.topico.said.has("recepcion") and hub.topico.said.has("alta"), "líneas del enfermero (%s)" % str(hub.topico.said))
	t.check(seq.is_empty() and not t.player().input_locked, "una vez por turno está bien: 0 muertes")
	t.check(hub.rta.wrong_reason() == "", "en Baño con el permiso del tópico el RTA no taguea")


func _topico_dos(t: Node) -> void:
	var hub := await _prep(t, 3)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var hunts: Array = t.spy("pursuit_started")
	await _ask_topico(t)
	await _ask_topico(t)
	t.check(hub.topico.state == TopicoControl.State.PERSIGUE and hub.topico.requests() == 2, "2.º pedido del turno: 'Work avoiding. Ya bajo.'")
	t.check(hunts.size() == 1 and str(hunts[0][0]) == "shero" and str(hunts[0][1]) == "work_avoiding", "Shero baja a buscarte")
	t.player().stand_up()
	await _check_death(t, seq, scr, "work_avoiding", "shero", 90.0)


func _topico_sin_permiso(t: Node) -> void:
	var hub := await _prep(t, 2)
	var msgs: Array = t.spy("shero_message")
	await _floor(t, 1)
	await _to_marker(t, "topico", Vector3(0, 0, -0.6))
	await t.frames(4)
	t.check(hub.topico.said.has("sin_permiso"), "sin permiso: 'Sin permiso de su supervisor no lo puedo atender'")
	var m := t.building().floor_node.find_child("topico", true, false) as Node3D
	t.check(t.player().global_position.distance_to(m.global_position) > 2.4, "te devuelve al pasillo")
	t.check(msgs.has(["topico_anotado", "dm"]), "Shero lo anota (llamado)")


func _topico_t1(t: Node) -> void:
	var hub := await _prep(t, 1)
	var denied: Array = []
	hub.topico_denied.connect(func(r: String) -> void: denied.append(r))
	await _ask_topico(t)
	t.check(denied == ["cerrado"] and hub.topico.requests() == 0, "T1: el tópico está cerrado (no cuenta como pedido)")


# --- Perrito RTA ----------------------------------------------------------------------------------

func _force_wrong(hub: PersonajesP5) -> void:
	var tol := float(GameState.turno_cfg("rta_tolerancia_s", 90.0)) * Difficulty.scale("tolerancia_rta")
	hub.rta.wrong_elapsed = maxf(hub.rta.wrong_elapsed, tol - 0.5)


func _rta_strikes(t: Node, floor_n: int) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var hunts: Array = t.spy("pursuit_started")
	var entered: Array = t.spy("hunter_entered_floor")
	if floor_n != 2:
		await _floor(t, floor_n, "cafeteria" if floor_n == -1 else "ascensor")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await t.frames(2)
	var alloc := EzlakHub.get_hub(t.get_tree()).messages("#allocations")
	t.check(not alloc.is_empty() and str(alloc[alloc.size() - 1].get("tipo", "")) == "orden_aux", "orden en #allocations: '@Jiroshi pasa a BO'")
	# 1.ª orden ignorada.
	await t.until(func() -> bool: return hub.rta.wrong_elapsed >= 0.0, 2.0)
	_force_wrong(hub)
	await t.until(func() -> bool: return hub.rta.strikes() == 1, 3.0)
	t.check(hub.rta.posts.has("tag_1"), "1.ª orden ignorada: tag")
	Metrics.set_aux(Metrics.Aux.BO)
	await t.frames(2)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.until(func() -> bool: return hub.rta.wrong_elapsed >= 0.0, 2.0)
	_force_wrong(hub)
	await t.until(func() -> bool: return hub.rta.strikes() == 2, 3.0)
	t.check(hub.rta.posts.has("tag_2") and hub.rta.since_tag2 >= 0.0, "2.ª: 'Al tercero no aviso'")
	t.check(hunts.is_empty(), "todavía no caza")
	hub.rta.since_tag2 = 59.5
	t.check(await t.until(func() -> bool: return not hunts.is_empty(), 4.0), "60 s tras el 2.º tag sin corregir → caza")
	t.check(str(hunts[0][0]) == "rta" and hub.rta.posts.has("caza"), "'@Jiroshi adherencia cero. Voy.'")
	if floor_n != 2:
		t.check(await t.until(func() -> bool: return not entered.is_empty(), 40.0), "el RTA llega por la escalera al piso %d" % floor_n)
	await _check_death(t, seq, scr, "aux_incorrecto", "rta", 90.0)
	t.check(Screamers.row_for("rta", "aux_incorrecto").get("variante", "") == "suelo", "screamer del perro desde el suelo")


func _rta_corrige(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var ended: Array = t.spy("pursuit_ended")
	await _floor(t, 1)
	PersonajesP5.set_counter("p5_rta_strikes", 2)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await t.until(func() -> bool: return hub.rta.wrong_elapsed >= 0.0, 2.0)
	_force_wrong(hub)
	t.check(await t.until(func() -> bool: return hub.rta.hunting, 3.0), "3.ª orden ignorada → caza directa (sin aviso)")
	Metrics.set_aux(Metrics.Aux.BO)  # corregir en un terminal Fonex
	await t.frames(3)
	t.check(not hub.rta.hunting and not P5Pursuit.is_hunting("rta"), "corregir el AUX cancela la caza")
	t.check(ended.has(["rta", "corregido"]) and hub.rta.posts.has("perdida_caza"), "'AUX correcto. Reporte cerrado. Por ahora.'")
	await t.seconds(30.0)
	t.check(seq.is_empty(), "0 muertes")


## Ignorar en continuo (sin corregir nunca) también escala: cada tolerancia entera es un strike nuevo.
func _rta_continuo(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var hunts: Array = t.spy("pursuit_started")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await t.until(func() -> bool: return hub.rta.wrong_elapsed >= 0.0, 2.0)
	_force_wrong(hub)
	t.check(await t.until(func() -> bool: return hub.rta.strikes() == 1, 3.0), "1.ª tolerancia: tag 1")
	t.check(hub.rta.wrong_elapsed < 5.0 and not hub.rta.counted, "el episodio vuelve a contar desde 0 sin corregir (%.1f s)" % hub.rta.wrong_elapsed)
	_force_wrong(hub)
	t.check(await t.until(func() -> bool: return hub.rta.strikes() == 2, 3.0), "otra tolerancia sin corregir: tag 2")
	t.check(hub.rta.posts.has("tag_1") and hub.rta.posts.has("tag_2") and hunts.is_empty(), "dos tags, todavía sin caza")
	_force_wrong(hub)
	t.check(await t.until(func() -> bool: return not hunts.is_empty(), 3.0), "3.ª tolerancia sin corregir: caza")
	await _check_death(t, seq, scr, "aux_incorrecto", "rta", 90.0)


func _rta_sin_break(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	Metrics.set_aux(Metrics.Aux.BREAK)
	t.player().stand_up()
	await t.advance_clock(25.0 * 60.0)
	hub.rta.wrong_elapsed = 999.0
	await t.frames(3)
	t.check(hub.rta.wrong_reason() == "" and hub.rta.strikes() == 0 and not hub.rta.hunting, "break de 25 min: el RTA no hace nada (es de Shero)")
	# v0.3.1: la persecución de Shero por el break (16 min) puede alcanzarte en estos 3 cuadros con la máquina cargada;
	# lo que se prueba es que el RTA no mata.
	t.check(seq.filter(func(e: Array) -> bool: return str(e[1]) == "rta").is_empty(), "el RTA ya no mata por break_excedido (%s)" % str(seq))
	var src := FileAccess.get_file_as_string("res://scripts/personajes/perrito_rta.gd") + FileAccess.get_file_as_string("res://scripts/personajes/rta_control.gd")
	t.check(not src.contains("\"break_excedido\""), "ni una referencia a break_excedido en el RTA")
	Metrics.set_aux(Metrics.Aux.BANO)
	await t.advance_clock(11.0 * 60.0)
	t.check(hub.rta.wrong_reason() == "cupo", "baño acumulado > 10 min: cupo excedido (regla del RTA)")


func _rta_ordenes(t: Node) -> void:
	var hub := await _prep(t, 1)
	var hubz := EzlakHub.get_hub(t.get_tree())
	await t.set_clock(GameState.lunch_clock() + 5.0)
	await t.frames(3)
	t.check(Metrics.expected_aux == Metrics.Aux.LUNCH, "a la hora del lunch el RTA dicta Lunch")
	var last := hubz.messages("#allocations")
	var lunch_order := false
	for m in last:
		if str(m.get("texto", "")).contains("Lunch"):
			lunch_order = true
	t.check(lunch_order, "'@Jiroshi pasa a Lunch. Horario …' en #allocations")
	PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	t.check(Metrics.expected_aux == Metrics.Aux.LUNCH, "un contacto que termina no borra la orden de Lunch")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(RtaControl.lunch_taken(), "lunch a su hora: anotado")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(Metrics.expected_aux == Metrics.Aux.AVAILABLE, "al volver del lunch espera Available")
	var npc := false
	for m in hubz.messages("#allocations"):
		if str(m.get("tipo", "")) == "tag_npc":
			npc = true
	t.check(npc, "taguea a compañeros en #allocations")


# --- Don Fermín -----------------------------------------------------------------------------------

func _guardia(t: Node, turno: int) -> void:
	await _prep(t, turno, false)
	var steps: Array = t.spy("guard_check")
	var g := t.get_tree().get_first_node_in_group("p5_guardia")
	t.check(g != null and bool(GameState.flags.get("guardia_revision_activa", false)), "Don Fermín activa la revisión al llegar")
	var turn := t.building().floor_node.find_child("Molinete0", true, false) as Interactable
	t.check(turn != null and not turn.interact(t.player()), "el molinete no abre sin revisión")
	await t.frames(2)
	t.check(steps.has(["molinete_bloqueado"]), "guard_check('molinete_bloqueado')")
	g.call("start_check")
	t.check(t.player().input_locked, "la revisión te detiene")
	t.check(await t.until(func() -> bool: return bool(GameState.flags.get("revision_ok", false)), 40.0), "revisión completa")
	for st in ["fotocheck", "mochila", "detector", "celular", "ok"]:
		t.check(steps.has([st]), "paso %s" % st)
	t.check(not t.player().input_locked, "luego te deja pasar")
	t.check(turn.interact(t.player()), "con revisión el molinete abre")
	if turno >= 3:
		var lines: Dictionary = DataLoader.dict("lineas_neutrales").get("fermin", {})
		t.check(str(g.call("_variant", "fotocheck")) == "fotocheck_t3" and lines.has("pase_t3"), "T3: algo raro en sus líneas (fotocheck_t3, pase_t3)")
	else:
		t.check(str(g.call("_variant", "fotocheck")) == "fotocheck", "T1: revisión normal")


func _hub_persistente(t: Node) -> void:
	var hub := await _prep(t, 2)
	t.check(hub != null and hub.qa != null and hub.training != null and hub.rasec != null and hub.topico != null and hub.rta != null, "PersonajesP5 con sus 5 cerebros")
	for f in [-1, 1, 9, 2]:
		await _floor(t, f)
		t.check(PersonajesP5.get_hub(t.get_tree()) == hub, "sobrevive al cambio al piso %d" % f)
	var b := t.building().floor_node as FloorBase
	t.check(b.behaviours().has("haime") and b.behaviours().has("rasec"), "piso 2: haime y rasec")
	await t.back_to_menu()
	await t.frames(2)
	t.check(PersonajesP5.get_hub(t.get_tree()) == null, "al volver al menú se libera")

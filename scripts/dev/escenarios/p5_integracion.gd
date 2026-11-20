## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios del merge de P5 en v0.3 (P3 + P5 juntos, sin dobles): una sola persecución (P5Pursuit → Pursuit con
## todos los argumentos: el RTA y el Trainer salen de donde están si estás en su piso, si no llegan por la
## escalera / el ascensor), el tópico de P5 (owns_track("topico") = false), los motivos de congelamiento
## "feedback"/"training" de los dos lados, training_released → una sola vuelta tardía (regreso_tardio), el feedback
## de Haime como coaching autorizado para "coaching excedido" (Rasec) y el coaching de Rasec por Rooms (fuente
## "tm") sin pisar su evento (ni al revés). Usa las ayudas de p5_personajes.gd (_prep, _training_call…).

const P5 := "res://scripts/dev/escenarios/p5_personajes.gd"

var _p5: Object = null


func escenarios() -> Array[String]:
	return [
		"p5m_rta_desde_su_sitio", "p5m_rta_otro_piso", "p5m_trainer_desde_su_sitio", "p5m_trainer_otro_piso",
		"p5m_una_persecucion", "p5m_topico_de_p5", "p5m_congelar_motivos", "p5m_training_regreso_una_vez",
		"p5m_haime_coaching_excedido", "p5m_rasec_coaching_y_evento", "p5m_rasec_evento_y_coaching",
	]


func run(id: String, _arg: String, t: Node) -> void:
	_p5 = (load(P5) as GDScript).new()
	match id:
		"p5m_rta_desde_su_sitio": await _rta_here(t)
		"p5m_rta_otro_piso": await _rta_other(t)
		"p5m_trainer_desde_su_sitio": await _trainer_here(t)
		"p5m_trainer_otro_piso": await _trainer_other(t)
		"p5m_una_persecucion": await _one_system(t)
		"p5m_topico_de_p5": await _topico(t)
		"p5m_congelar_motivos": await _freeze(t)
		"p5m_training_regreso_una_vez": await _training_once(t)
		"p5m_haime_coaching_excedido": await _haime_exceso(t)
		"p5m_rasec_coaching_y_evento": await _rasec_coaching_first(t)
		"p5m_rasec_evento_y_coaching": await _rasec_event_first(t)
	for c in (_p5.get("_conns") as Array):
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	(_p5.get("_conns") as Array).clear()
	_p5 = null


# --- ayudas ---------------------------------------------------------------------------------------

func _prep(t: Node, turno: int, seat: bool = true) -> PersonajesP5:
	return await _p5.call("_prep", t, turno, seat)


func _steps(t: Node) -> Array:
	var log_arr: Array = t.spy("discipline_step")
	return log_arr


func _count(log_arr: Array, track: String, step: int = -1) -> int:
	var n := 0
	for e in log_arr:
		if str(e[0]) == track and (step < 0 or int(e[1]) == step):
			n += 1
	return n


func _marker_pos(t: Node, m: String) -> Vector3:
	var n := (t.building().floor_node as Node).find_child(m, true, false) as Node3D
	return n.global_position if n != null else Vector3.INF


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Avanza el reloj de juego de 10 s en 10 s (las pistas de Discipline avanzan con clock_tick).
func _adv(t: Node, seconds: float) -> void:
	var left := seconds
	var n := 0
	while left > 0.0:
		var s := minf(10.0, left)
		GameState.clock_seconds += s
		EventBus.clock_tick.emit(GameState.clock_seconds)
		left -= s
		n += 1
		if n % 12 == 0:
			await t.frames(1)
	await t.frames(1)


## El cazador (nodo que mueve Pursuit) ya está en tu piso: visitante de P3, no el cuerpo de P5.
func _check_spawn_here(t: Node, hunter: String, at: Vector3, floor_n: int, entered: Array) -> void:
	var inf := Pursuit.info(hunter)
	var n := Pursuit.node_of(hunter)
	t.check(P5Pursuit.is_hunting(hunter) and Pursuit.is_hunting(hunter), "%s: P5Pursuit delega en Pursuit (una sola persecución)" % hunter)
	t.check(str(inf.get("state", "")) == "cazando" and n != null, "%s: aparece al instante (estado %s), sin ascensor ni escalera" % [hunter, str(inf.get("state", ""))])
	t.check(n != null and _hdist(n.global_position, at) < 0.6, "%s: sale de donde estaba en el piso %d (%s → %s)" % [hunter, floor_n, str(at), str(n.global_position) if n != null else "nada"])
	t.check(not entered.is_empty() and str(entered[0][0]) == hunter and int(entered[0][1]) == floor_n, "hunter_entered_floor(%s, %d)" % [hunter, floor_n])


## Llega al piso del jugador por su entrada (marcador) tras la demora de Pursuit.
func _check_arrival(t: Node, hunter: String, expect_s: float, kind: String, floor_n: int, entered: Array) -> void:
	var inf := Pursuit.info(hunter)
	t.check(str(inf.get("state", "")) == "llegando" and Pursuit.node_of(hunter) == null, "%s: viene en camino (%s)" % [hunter, str(inf.get("state", ""))])
	t.check(absf(float(inf.get("arrive_left", 0.0)) - expect_s) < 0.6, "%s: llega en %.0f s (%s; hay %.1f)" % [hunter, expect_s, kind, float(inf.get("arrive_left", 0.0))])
	# P7: la posición se toma en el mismo instante en que entra (con la máquina cargada, al volver de `until` el
	# cazador ya había corrido unos metros y la prueba fallaba a veces).
	var at_entry: Array = []
	var grab := func(h: String, _f: int) -> void:
		var nn := Pursuit.node_of(h)
		if h == hunter and nn != null and at_entry.is_empty():
			at_entry.append(nn.global_position)
	EventBus.hunter_entered_floor.connect(grab)
	t.check(await t.until(func() -> bool: return not entered.is_empty(), expect_s + 15.0), "%s entra al piso %d" % [hunter, floor_n])
	await t.frames(1)
	EventBus.hunter_entered_floor.disconnect(grab)
	var n := Pursuit.node_of(hunter)
	var m := _marker_pos(t, kind)
	var pos: Vector3 = at_entry[0] if not at_entry.is_empty() else (n.global_position if n != null else Vector3.INF)
	t.check(not entered.is_empty() and int(entered[0][1]) == floor_n, "hunter_entered_floor(%s, %d)" % [hunter, floor_n])
	# v0.3.1: con la máquina cargada el cazador puede alcanzarte en el cuadro siguiente (el nodo ya no está): vale la
	# posición tomada al entrar.
	t.check((n != null or not at_entry.is_empty()) and m != Vector3.INF and _hdist(pos, m) < 4.0, "%s sale del marcador '%s' del piso %d (a %.1f m)" % [hunter, kind, floor_n, _hdist(pos, m) if pos != Vector3.INF else -1.0])


# --- persecución: una sola, con todos los argumentos ---------------------------------------------------

func _rta_here(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var entered: Array = t.spy("hunter_entered_floor")
	var ended: Array = t.spy("pursuit_ended")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await t.frames(2)
	var body := t.get_tree().get_first_node_in_group("rta") as Node3D
	t.check(body != null, "el RTA patrulla el piso 2")
	if body == null:
		return
	var at := body.global_position
	hub.rta.call("_hunt")  # mismo frame: el cuerpo no se movió
	_check_spawn_here(t, "rta", at, 2, entered)
	var n := Pursuit.node_of("rta")
	t.check(n != body and not body.visible, "persigue un visitante; el cuerpo que patrulla se oculta")
	t.check(n != null and not n.is_in_group("rta") and bool(n.get("_visitor")), "el visitante (PerritoRTA) no patrulla ni cuenta como el RTA del piso")
	t.player().stand_up()
	await _p5.call("_check_death", t, seq, scr, "aux_incorrecto", "rta", 60.0)
	t.check(ended.has(["rta", "alcanzado"]) and hub.rta.posts.has("reporte"), "pursuit_ended(rta, alcanzado) y el RTA publica su reporte")
	await t.reconnect()
	await t.frames(3)
	var b2 := t.get_tree().get_first_node_in_group("rta") as Node3D
	t.check(b2 != null and b2.visible and not Pursuit.is_hunting(), "tras reconectar el RTA vuelve a patrullar")


func _rta_other(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var entered: Array = t.spy("hunter_entered_floor")
	await _p5.call("_floor", t, -1, "cafeteria")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await t.frames(2)
	hub.rta.call("_hunt")
	await _check_arrival(t, "rta", 12.0 + 4.0 * 2.0, "escalera", -1, entered)
	await _p5.call("_check_death", t, seq, scr, "aux_incorrecto", "rta", 60.0)


func _trainer_here(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var entered: Array = t.spy("hunter_entered_floor")
	await _p5.call("_training_call", t, hub)
	t.player().stand_up()
	await _p5.call("_floor", t, 1)
	await _p5.call("_to_marker", t, "training_sala2", Vector3(-6.0, 0, 2.5))
	var tn := t.get_tree().get_first_node_in_group("trainer") as Node3D
	t.check(tn != null, "el Trainer está en el piso 1")
	if tn == null:
		return
	var at := tn.global_position
	hub.training.call("_hunt")
	_check_spawn_here(t, "trainer", at, 1, entered)
	var n := Pursuit.node_of("trainer")
	t.check(n != null and n.has_meta("rig") and not tn.visible, "visitante con su modelo de models_v2; el Trainer de la sala se oculta")
	await _p5.call("_check_death", t, seq, scr, "training_inasistencia", "trainer", 60.0)


func _trainer_other(t: Node) -> void:
	var hub := await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var entered: Array = t.spy("hunter_entered_floor")
	await _p5.call("_training_call", t, hub)
	t.player().stand_up()
	hub.training.call("_hunt")
	await _check_arrival(t, "trainer", 20.0 + 6.0, "ascensor", 2, entered)
	await _p5.call("_check_death", t, seq, scr, "training_inasistencia", "trainer", 60.0)


## Persecuciones de P5 y de P3 son la misma: una por cazador, stop con motivo, y una muerte por otra causa corta
## la caza del Trainer/RTA (como antes del merge).
func _one_system(t: Node) -> void:
	var hub := await _prep(t, 2)
	var started: Array = t.spy("pursuit_started")
	var ended: Array = t.spy("pursuit_ended")
	PerritoRTA.dictate(Metrics.Aux.BO)
	await _p5.call("_floor", t, -1, "cafeteria")
	t.check(P5Pursuit.start("rta", "aux_incorrecto", 7.0, null, "Available 1:00", 2, Vector3.INF), "P5Pursuit.start arranca")
	t.check(not P5Pursuit.start("rta", "aux_incorrecto", 7.0), "una persecución por cazador")
	t.check(Pursuit.is_hunting("rta") and started.size() == 1, "la ve Pursuit (P3): una sola pursuit_started")
	P5Pursuit.stop("rta", "corregido")
	t.check(not Pursuit.is_hunting("rta") and ended.has(["rta", "corregido"]), "stop(cazador, motivo) pasa el motivo")
	P5Pursuit.start("trainer", "training_inasistencia", 4.4, null, "", 1, Vector3.INF)
	var seq: Array = t.spy("death_sequence_started")
	Checkpoints.request_death("colapso", "", "")
	await t.frames(2)
	t.check(not seq.is_empty() and not Pursuit.is_hunting("trainer") and ended.has(["trainer", "muerte"]), "otra muerte corta la caza del Trainer")
	await t.wait_death_shown(10.0)
	await t.reconnect()
	t.check(not Pursuit.is_hunting() and hub.busy == "", "tras reconectar no queda ninguna persecución")


# --- Discipline ↔ P5 ------------------------------------------------------------------------------

func _topico(t: Node) -> void:
	var hub := await _prep(t, 3)
	var hunts: Array = t.spy("pursuit_started")
	var log_arr := _steps(t)
	t.check(not Discipline.owns_track("topico") and Discipline.owns_track("topico_excedido"), "con TopicoControl el tópico es de P5; topico_excedido sigue en P3")
	t.check(not hub.topico.p3_owns(), "TopicoControl.p3_owns() = false")
	var auth0 := Metrics.authorizations.size()
	await _p5.call("_ask_topico", t)
	t.check(Metrics.authorizations.size() == auth0 + 1 and not Metrics.authorization_of("topico").is_empty(), "1.er pedido: un solo permiso (el de P5)")
	t.check(int(Discipline.counters.get("topico", 0)) == 0 and _count(log_arr, "topico") == 0, "Discipline no cuenta ni escala el tópico")
	await _p5.call("_ask_topico", t)
	t.check(hunts.size() == 1 and str(hunts[0][0]) == "shero" and str(hunts[0][1]) == "work_avoiding", "2.º pedido: UNA persecución de Shero (work_avoiding)")
	var rows: Array = Pursuit.stats.filter(func(r: Dictionary) -> bool: return str(r.get("cazador", "")) == "shero" and str(r.get("causa", "")) == "work_avoiding")
	t.check(Pursuit.is_hunting("shero") or not rows.is_empty(), "la lleva Pursuit (Shero sale de su sitio, junto a C-14)")


func _freeze(t: Node) -> void:
	var hub := await _prep(t, 2)
	await _p5.call("_call_haime", t, hub)
	await _p5.call("_go_calibration", t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "feedback de Haime")
	t.check(Discipline.freeze_reasons() == ["feedback"], "un solo motivo 'feedback' (Haime + qa_feedback_started): %s" % str(Discipline.freeze_reasons()))
	await t.until(func() -> bool: return hub.qa.state != QaFeedback.State.SESION, 120.0)
	t.check(Discipline.freeze_reasons().is_empty(), "al terminar no queda nada congelado (%s)" % str(Discipline.freeze_reasons()))
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _p5.call("_training_call", t, hub)
	await _p5.call("_training_arrive", t, hub)
	t.check(hub.training.state == TrainingControl.State.SESION and Discipline.freeze_reasons() == ["training"], "training: un solo motivo 'training' (%s)" % str(Discipline.freeze_reasons()))
	hub.training.forced_answers = [-1, -1, -1, -1, -1]
	hub.training.session_at -= 40.0 * 60.0
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.HECHO, 30.0), "el training termina")
	t.check(Discipline.freeze_reasons().is_empty(), "al soltarte no queda nada congelado (%s)" % str(Discipline.freeze_reasons()))


func _training_once(t: Node) -> void:
	var hub := await _prep(t, 2)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	var ended: Array = t.spy("training_ended")
	var released := [0]
	hub.training_released.connect(func() -> void: released[0] += 1)
	await t.frames(40)  # Discipline engancha training_released del cerebro (mira cada 30 frames)
	await _p5.call("_training_call", t, hub)
	await _p5.call("_training_arrive", t, hub)
	hub.training.forced_answers = [-1, -1, -1, -1, -1]
	hub.training.session_at -= 40.0 * 60.0
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.HECHO, 30.0), "el Trainer te suelta")
	t.check(released[0] == 1 and ended.size() == 1 and bool(ended[0][0]), "training_released y training_ended(true), una vez cada una")
	t.check(not Discipline.debug_run().get("training_regreso", {}).is_empty(), "arranca la vuelta tardía (P3)")
	t.player().stand_up()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	var t0 := GameState.clock_seconds
	# v0.3.2-core4: el regreso del training pasa de 8 / 11 / 14 min a 3 / 4 / 5 (balance.json/escalera).
	await _adv(t, 3.0 * 60.0 + 20.0)
	t.check(_count(log_arr, "training_regreso", 1) == 1, "3 min: UN llamado de training_regreso (hay %d)" % _count(log_arr, "training_regreso", 1))
	await _adv(t, 60.0)
	t.check(_count(log_arr, "training_regreso", 2) == 1, "4 min: un verbal")
	Metrics.give_ack()
	await _adv(t, 60.0)
	t.check(_count(log_arr, "training_regreso", 4) == 1, "5 min: persecución (una sola escalera)")
	await t.until(func() -> bool: return not seq.is_empty(), 90.0)
	t.check(not seq.is_empty() and str(seq[0][0]) == "regreso_tardio" and str(seq[0][1]) == "shero", "muerte regreso_tardio (Shero) a los %.1f min" % ((GameState.clock_seconds - t0) / 60.0))
	t.check(seq.size() == 1, "una sola muerte")


func _haime_exceso(t: Node) -> void:
	var hub := await _prep(t, 1)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	await _p5.call("_call_haime", t, hub)
	await _p5.call("_go_calibration", t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "feedback de Haime con AUX Coaching")
	t.check(_count(log_arr, "coaching") == 0 and Discipline.debug_run().get("coaching", {}).is_empty(), "Coaching autorizado por Haime: no es 'coaching sin permiso'")
	await t.until(func() -> bool: return hub.qa.state != QaFeedback.State.SESION, 120.0)
	# v0.3.1 (F4): la silla de calibración no tiene PC: el Coaching sigue autorizado el rato de volver a tu puesto
	# (qa_haime.json/regreso_min); vencido ese permiso, quedarse en Coaching es la pista de Rasec, como antes.
	t.check(Metrics.aux == Metrics.Aux.COACHING and not Metrics.authorization_of("qa").is_empty(), "termina el feedback: permiso corto para volver en Coaching")
	t.check(Discipline.debug_run().get("coaching_exceso", {}).is_empty(), "con el permiso de vuelta no corre 'coaching excedido'")
	await _adv(t, float(DataLoader.dict("qa_haime").get("regreso_min", 6.0)) * 60.0 + 10.0)
	t.check(Metrics.aux == Metrics.Aux.COACHING and not Metrics.is_aux_authorized(Metrics.Aux.COACHING), "vencido el permiso sigues en Coaching (sin autorización)")
	t.check(await t.until(func() -> bool: return not Discipline.debug_run().get("coaching_exceso", {}).is_empty(), 3.0), "corre 'coaching excedido' (el feedback cuenta como coaching autorizado)")
	t.check(Discipline.executor("coaching_exceso") == "rasec", "ejecutor Rasec")
	await _adv(t, 2.0 * 60.0 + 20.0)
	t.check(_count(log_arr, "coaching_exceso", 1) == 1, "2 min: llamado de Rasec")
	t.check(_count(log_arr, "coaching") == 0, "nunca 'coaching sin permiso'")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(Discipline.debug_run().get("coaching_exceso", {}).is_empty() and seq.is_empty(), "volver a Available lo corta, 0 muertes")


## Coaching de Rasec por Rooms (fuente "tm") en curso a la hora de su evento: el evento espera a que termine la
## sesión y luego convoca con su propia autorización "tm" (BO), que la sesión ya no revoca.
func _rasec_coaching_first(t: Node) -> void:
	var hub := await _prep(t, 1)
	var seq: Array = t.spy("death_sequence_started")
	var called: Array = []
	hub.rasec_event_called.connect(func(k: String) -> void: called.append(k))
	Discipline.request_coaching("rasec")
	await t.frames(3)
	EzlakHub.get_hub(t.get_tree()).join_rooms()
	await t.frames(3)
	var a := Metrics.authorization_of("tm")
	t.check(Discipline.session_active() and int(a.get("aux", -1)) == Metrics.Aux.COACHING, "sesión de Rasec: Coaching autorizado con 'tm'")
	t.check(not hub.can_interrupt(), "con la sesión en curso nadie de P5 interrumpe")
	var at := hub.rasec.event_clock()
	t.check(at >= 0.0, "T1 tiene evento de Rasec (%s)" % GameState.clock_text_at(at))
	GameState.clock_seconds = at + 1.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await t.frames(5)
	t.check(called.is_empty() and hub.rasec.state == RasecControl.State.LIBRE, "a la hora del evento la sesión sigue: Rasec no lo convoca todavía")
	t.check(int(Metrics.authorization_of("tm").get("aux", -1)) == Metrics.Aux.COACHING, "la autorización de la sesión no se pisa")
	t.check(await t.until(func() -> bool: return not Discipline.session_active(), 80.0), "la sesión termina")
	t.check(await t.until(func() -> bool: return not called.is_empty(), 5.0), "después convoca su evento")
	var b := Metrics.authorization_of("tm")
	t.check(int(b.get("aux", -1)) == Metrics.Aux.BO and str(b.get("zone", "")) == "evento_rasec", "el evento tiene su BO 'tm' (hay %s)" % str(b))
	await t.frames(5)
	t.check(not Metrics.authorization_of("tm").is_empty() and seq.is_empty(), "la sesión que terminó no le revoca el BO; 0 muertes")


## Al revés: el evento de Rasec convocado (BO "tm") y Rasec te llama a coaching: la sesión espera al evento.
func _rasec_event_first(t: Node) -> void:
	var hub := await _prep(t, 1)
	hub.rasec.call_event("karaoke")
	await t.frames(2)
	t.check(int(Metrics.authorization_of("tm").get("aux", -1)) == Metrics.Aux.BO, "evento convocado: BO 'tm'")
	Discipline.request_coaching("rasec")
	await t.frames(3)
	EzlakHub.get_hub(t.get_tree()).join_rooms()
	await t.frames(5)
	t.check(not Discipline.session_active(), "unirte a Rooms con el evento en curso: la sesión de Rasec espera")
	t.check(int(Metrics.authorization_of("tm").get("aux", -1)) == Metrics.Aux.BO, "el BO del evento sigue intacto")
	Metrics.revoke("tm")  # el evento termina (o se cancela)
	t.check(await t.until(func() -> bool: return Discipline.session_active(), 3.0), "al terminar el evento empieza la sesión de coaching")
	t.check(int(Metrics.authorization_of("tm").get("aux", -1)) == Metrics.Aux.COACHING, "Coaching 'tm' de la sesión")

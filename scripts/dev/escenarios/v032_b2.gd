extends RefCounted
## v0.3.2 · arreglos de Joan tras la beta y la final de la v0.3.1 (rama v0.3.2-bugs). Cada uno empezó como repro
## (falla en la v0.3.1) y queda como prueba de regresión. `--escenario v032_b2`.
##   b2_microondas          los 6 del -1 y el de la azotea: ningún «ding» en bucle (el taper eterno de C-13 sonaba
##                          cada segundo de juego), como mucho uno por microondas; tu taper vuelve tras recargar el piso
##   b2_ezlaki_no_abre      ráfaga de DMs, menciones, posts de canal, WW, Rooms y Vitzo con otro chat y otra app abiertos:
##                          la vista activa NUNCA cambia; filas en negrita con insignia, aviso breve; abrir = leído;
##                          Ack, Rooms y Vitzo se resuelven sin abrir el chat ([Espacio] / [Enter])
##   b2_lunch_inmune        en el lunch nadie convoca (Haime, Rasec, Trainer, Mentor, Vitzo, Rooms, lista de Shero) ni
##                          avanza la escalera; tras la gracia sale lo aplazado, escalonado (Haime primero)
##   b2_lunch_excepciones   una persecución de antes del lunch sigue; pasado el cupo (45 min) corre la escalera del lunch
##   b2_mesas               cada mesa de las cafeterías del -1 y del 9 se apunta con el rayo (de pie a su lado), te sienta,
##                          animación de comer y Fatiga; las mesas siguen tras cambiar de piso
##   b2_espejo              tu reflejo (cámara reflejada, doble con cabeza) ≤ 2 s y vuelve el control; con Fatiga ≥ 50
##                          alguien detrás de ti que no queda al terminar; sin la cámara de seguridad de 20 s
##   b2_parpadeo            párpados con curva suave (sin saltos) y más rápido: 0,5 s (antes 1 s de negro de golpe)
##   b2_fatiga_dificultad   ganancia y recuperación por dificultad (Fácil, Normal, Difícil, Turno real)
##   b2_correo_evento       (bot humano) el evento de Rasec no se come el reloj del caso de BO abierto
##   b2_sin_terminales      no queda ningún terminal Fonex de pared en -1, 1, 2 ni 9
##   b2_aux_solo_pc         de pie el AUX no cambia; sentado en tu PC sí; en otra isla también, con la regla «otra isla»
##   b2_comodin             llamas a un compañero: te marca el AUX (Available al volver del lunch), HUD 1/1, DM de Shero;
##                          la 2.ª vez en el turno no se puede
##   b2_comodin_reintento   uno no contesta → otro con el mismo comodín en 30 s; si nadie contesta se pierde
##   b2_acd_bo_timbre       pasar a BO con un contacto sonando = 1 perdida y después 0 (Joan)
##   b2_acd_evento_rasec    el evento de Rasec en BO no genera perdidas
##   b2_acd_rona            tras una perdida el mismo contacto no vuelve a sonar enseguida (el bucle de 4 perdidas)
##   b2_acd_cola_drena      en tu lunch los compañeros Available vacían la cola
##   b2_acd_back_to_back    todos en lunch, la cola crece; al volver a Available te entran seguidos (con tope)
##   b2_acd_perdidas_available  la muerte por 4 perdidas solo cuenta timbres en Available
##   b2_topico_training     (Joan) de pie en la sala de training (T2) no te echa el enfermero del tópico; dentro del tópico
##                          sin permiso, sí
##   b2_respawn_trainer     (Joan) te mata el Trainer en el piso 1 → reapareces SENTADO en C-14, con la PC abierta y en
##                          «Reconectando» (ni Available ni fuera de la sala)
##   b2_reconectando_timeout  sin elegir AUX, a los 5 s pasa solo a Available; nada suena ni se pierde mientras; elegir
##                          Available enseguida no da una perdida al instante; 60 s quieto después no te mata
##   b2_respawn_contacto    morir en pleno contacto: 0 perdidas, el contacto vuelve a la cola, el AHT no cambia
##   b2_respawn_lunch       morir en el lunch: «Te quedaban X min», elegir Lunch retoma el cupo (no lo reinicia)
##   b2_voces_sin_solape    (Joan: «cruzas todos los diálogos») evento de Rasec + DM de Shero + llamada de cliente +
##                          murmullo + Haime a la vez: una voz y un subtítulo a la vez, prioridades, cola que vence
##   b2_zonas_sin_solape    en cada piso ninguna zona exclusiva (tópico, training, baños, feedback, limpieza, casilleros,
##                          cafeterías, evento de Rasec, sala, otra isla, azotea…) pisa a otra (margen 5 cm)


func escenarios() -> Array[String]:
	return ["b2_microondas", "b2_ezlaki_no_abre", "b2_lunch_inmune", "b2_lunch_excepciones", "b2_mesas", "b2_espejo", "b2_parpadeo", "b2_fatiga_dificultad", "b2_correo_evento", "b2_sin_terminales", "b2_aux_solo_pc", "b2_comodin", "b2_comodin_reintento", "b2_acd_bo_timbre", "b2_acd_evento_rasec", "b2_acd_rona", "b2_acd_cola_drena", "b2_acd_back_to_back", "b2_acd_perdidas_available", "b2_topico_training", "b2_zonas_sin_solape", "b2_respawn_trainer", "b2_reconectando_timeout", "b2_respawn_contacto", "b2_respawn_lunch", "b2_voces_sin_solape"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"b2_microondas": await _microondas(t)
		"b2_ezlaki_no_abre": await _ezlaki(t)
		"b2_lunch_inmune": await _lunch(t)
		"b2_lunch_excepciones": await _lunch_exc(t)
		"b2_mesas": await _mesas(t)
		"b2_espejo": await _espejo(t)
		"b2_parpadeo": await _parpadeo(t)
		"b2_fatiga_dificultad": await _fatiga(t)
		"b2_correo_evento": await _correo_evento(t)
		"b2_sin_terminales": await _sin_terminales(t)
		"b2_aux_solo_pc": await _aux_solo_pc(t)
		"b2_comodin": await _comodin(t)
		"b2_comodin_reintento": await _comodin_reintento(t)
		"b2_acd_bo_timbre": await _acd_bo_timbre(t)
		"b2_acd_evento_rasec": await _acd_evento_rasec(t)
		"b2_acd_rona": await _acd_rona(t)
		"b2_acd_cola_drena": await _acd_cola_drena(t)
		"b2_acd_back_to_back": await _acd_b2b(t)
		"b2_acd_perdidas_available": await _acd_perdidas(t)
		"b2_topico_training": await _topico_training(t)
		"b2_zonas_sin_solape": await _zonas(t)
		"b2_respawn_trainer": await _respawn_trainer(t)
		"b2_reconectando_timeout": await _recon_timeout(t)
		"b2_respawn_contacto": await _respawn_contacto(t)
		"b2_respawn_lunch": await _respawn_lunch(t)
		"b2_voces_sin_solape": await _voces(t)


# --- 1. Microondas --------------------------------------------------------------------------------

func _mws(t: Node, fl: Node) -> Array:
	var out: Array = []
	for n in t.get_tree().get_nodes_in_group("microondas"):
		if n is WorldObjects.Microwave and WorldObjects.TaperFlow.floor_of(n as Node) == fl:
			out.append(n)
	out.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	return out


## Cuenta los «microondas_fin» pedidos al AudioManager mientras el reloj corre `game_s` segundos de juego, de a `step`.
func _count_dings(t: Node, game_s: float, step: float) -> int:
	var n := 0
	var last_t := -1
	var left := game_s
	while left > 0.0:
		GameState.clock_seconds += step
		left -= step
		await t.frames(1)
		var ls: Dictionary = AudioManager.last_sfx
		if str(ls.get("slot", "")) == "sfx/microondas_fin" and int(ls.get("t", -1)) != last_t:
			last_t = int(ls.get("t", -1))
			n += 1
	return n


func _microondas(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	Engine.time_scale = 1.0
	var b: Building = t.building()
	t.player().stand_up()
	b.go_to_floor(-1, "cafeteria")
	await t.frames(3)
	var mws := _mws(t, b.floor_node)
	t.check(mws.size() == 6, "6 microondas en el -1 (%d)" % mws.size())
	if mws.size() < 6:
		return
	Metrics.set_aux(Metrics.Aux.LUNCH)
	(mws[0] as WorldObjects.Microwave).hint_text()  # reparte: fuera, ocupados (uno con el taper eterno de C-13), libres
	var states := {}
	for m in mws:
		states[str(m.state)] = int(states.get(str(m.state), 0)) + 1
	t.note("estados %s" % str(states))
	# 12 min de juego a 2 s por cuadro (≈ el lunch a 9x con 60 fps reales: 0,15 s por cuadro; aquí más grueso).
	var dings := await _count_dings(t, 12.0 * 60.0, 2.0)
	var busy := int(states.get("ocupado", 0))
	t.check(dings <= busy, "en 12 min de juego suenan %d «ding» (≤ %d, uno por microondas ocupado; antes el de C-13 sonaba cada segundo de juego)" % [dings, busy])
	var eternal := 0
	for m in mws:
		if (m as WorldObjects.Microwave).eternal:
			eternal += 1
			t.check((m as WorldObjects.Microwave).state == "ocupado", "%s: el taper de C-13 sigue «ocupado» (nunca termina)" % m.name)
	t.check(eternal >= 1, "%d microondas con el taper eterno de C-13, en silencio" % eternal)
	# Más tiempo: ningún ding más (ya terminaron los ajenos).
	var more := await _count_dings(t, 10.0 * 60.0, 1.0)
	t.check(more == 0, "10 min más de juego: %d «ding» (0)" % more)
	# Tu taper: se calienta, se recarga el piso a mitad y sigue en el mismo microondas.
	WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.MANO)
	var free: WorldObjects.Microwave = null
	for m in mws:
		if (m as WorldObjects.Microwave).state == "libre":
			free = m
			break
	t.check(free != null, "hay un microondas libre")
	if free == null:
		return
	free.interact(t.player())
	var mine := str(free.name)
	t.check(WorldObjects.TaperFlow.state() == "calentando", "tu taper se calienta en %s" % mine)
	b.go_to_floor(2, "ascensor")
	await t.frames(3)
	b.go_to_floor(-1, "cafeteria")
	await t.frames(3)
	var mws2 := _mws(t, b.floor_node)
	(mws2[0] as WorldObjects.Microwave).hint_text()
	var again: WorldObjects.Microwave = null
	for m in mws2:
		if str(m.name) == mine:
			again = m
	t.check(again != null and again.state == "mio_calentando", "tras recargar el -1 tu taper sigue en %s (%s)" % [mine, again.state if again != null else "?"])
	var my_dings := await _count_dings(t, 90.0, 1.0)
	t.check(again != null and again.state == "mio_listo" and WorldObjects.TaperFlow.state() == "listo" and again.dings == 1, "listo con un solo «ding» de tu microondas (%d; %d en total con los ajenos)" % [again.dings if again != null else -1, my_dings])
	# Azotea: un microondas, uno libre, un solo ding con tu taper.
	b.go_to_floor(9, "ascensor")
	await t.frames(3)
	var az := _mws(t, b.floor_node)
	t.check(az.size() == 1, "un microondas en la azotea (%d)" % az.size())
	if az.size() == 1:
		WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.MANO)
		GameState.flags.erase("taper_mw")
		WorldObjects.TaperFlow.current_microwave = null
		var mw := az[0] as WorldObjects.Microwave
		mw.hint_text()
		mw.interact(t.player())
		var d9 := await _count_dings(t, 5.0 * 60.0, 1.0)
		t.check(mw.state == "mio_listo" and d9 == 1, "azotea: tu taper listo con un «ding» (%d)" % d9)
	Engine.time_scale = 8.0
	await t.back_to_menu()


# --- 2. Ezlaki: nada se abre solo ------------------------------------------------------------------

func _ezlaki(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var ez: PcEzlak = ws.get("ezlak")
	var desk: PcDesktop = ws.get("desktop")
	var hub: EzlakHub = ws.get("hub")
	desk.open_app("correo")
	ez.open_channel("#site-updates")
	ez.input.text = "estoy escribiendo"
	await t.frames(3)
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED  # sin contactos que cambien de app por su cuenta
	var views: Array = []
	var watch := func() -> void: views.append("%s|%s" % [ez.current, desk.active_app])
	# Ráfaga: DMs de 5 personas, menciones, posts en los 3 canales, WW (Ack), Rooms, recordatorio de Vitzo.
	var toasts: Array = []
	for who in ["shero", "trainer", "haime", "rasec", "mentor"]:
		EventBus.ezlak_post.emit("dm:" + who, who, "Hola @%s, ¿tienes un minuto?" % GameState.agent, {"mention": true})
		await t.frames(1)
		watch.call()
		if ez.toast_left > 0.0:
			toasts.append((ez.get("_topic") as Label).text)
	for i in 3:
		EventBus.ezlak_post.emit("#team-familia", "companero", "Mensaje %d al equipo" % i, {})
		EventBus.ezlak_post.emit("#allocations", "rta", "@%s revisa tu AUX" % GameState.agent, {"mention": true})
		EventBus.ezlak_post.emit("#site-updates", "om", "Aviso %d del site" % i, {})
		await t.frames(1)
		watch.call()
	Metrics.issue_written_warning("prueba_b2")
	await t.frames(2)
	watch.call()
	t.check(Metrics.ack_pending, "el WW abrió el Ack (%.1f s)" % Metrics.ack_left)
	t.note("plazo del Ack en la PC: %.1f s (turnos.json/ack_s × dificultad)" % Metrics.ack_left)
	EventBus.coaching_requested.emit(60.0)
	await t.frames(2)
	watch.call()
	var vz := t.get_tree().get_first_node_in_group("vitzo")
	if vz != null:
		vz.call("post_reminder")
	await t.seconds(2.0)
	watch.call()
	var bad := 0
	for v in views:
		if str(v) != "#site-updates|correo":
			bad += 1
	t.check(bad == 0 and ez.current == "#site-updates" and desk.active_app == "correo", "con %d mensajes la vista no cambió nunca (%s · %s; %d cambios)" % [hub.unread_total(), ez.current, desk.active_app, bad])
	t.check(ez.input.text == "estoy escribiendo", "lo que estabas escribiendo sigue ahí («%s»)" % ez.input.text)
	await t.frames(3)
	var badges := ez.unread_badges()
	t.check(int(badges.get("dm:shero", 0)) >= 3 and int(badges.get("dm:trainer", 0)) >= 1 and int(badges.get("#team-familia", 0)) >= 3 and int(badges.get("#allocations", 0)) >= 3, "filas con insignia de no leídos %s" % str(badges))
	var row := ez._side_buttons.get("dm:trainer") as Button
	t.check(row != null and row.get_node_or_null("Insignia") != null and row.get_theme_font("font") is FontVariation, "la fila del DM va en negrita y con su insignia")
	t.check(int(badges.get("#site-updates", -1)) == 0, "el chat abierto no acumula (lo estás mirando)")
	t.check(toasts.size() >= 1 and str(toasts[0]).contains("DM"), "aviso breve de mensaje nuevo en la cabecera de Ezlaki («%s»)" % (str(toasts[0]) if not toasts.is_empty() else ""))
	# Ack con [Espacio] sin abrir el DM; Rooms con [Enter]; Vitzo con [Enter]: el chat abierto no cambia.
	t.check(bool(ws.call("press_accept")) and not Metrics.ack_pending, "Ack con [Espacio] desde cualquier chat")
	t.check(hub.rooms_pending and hub.rooms_left >= 30.0, "Rooms pendiente con %.0f s para unirte" % hub.rooms_left)
	ez.enter_action()
	await t.frames(2)
	t.check(not hub.rooms_pending, "[Enter] se une a Rooms sin abrir el DM")
	if vz != null and bool(vz.call("is_reminder_pending")):
		ez.enter_action()
		await t.frames(2)
		t.check(not bool(vz.call("is_reminder_pending")), "[Enter] reacciona al recordatorio de Vitzo")
	t.check(ez.current == "#site-updates" and desk.active_app == "correo", "después de Ack, Rooms y Vitzo la vista sigue igual (%s · %s)" % [ez.current, desk.active_app])
	# Abrir a mano = leído.
	ez.open_channel("dm:trainer")
	ez.refresh(0.016, true)
	await t.frames(2)
	t.check(int((hub.channels.get("dm:trainer", {}) as Dictionary).get("unread", -1)) == 0, "abrir el DM del Trainer lo marca leído")
	ez.open_channel("#allocations")
	ez.refresh(0.016, true)
	await t.frames(2)
	t.check(int((hub.channels.get("#allocations", {}) as Dictionary).get("unread", -1)) == 0, "abrir #allocations lo marca leído")
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_INHERIT
	ws.call("set_zoom", false)
	await t.back_to_menu()


# --- 3. Lunch inmune --------------------------------------------------------------------------------

func _p5(t: Node) -> PersonajesP5:
	return PersonajesP5.get_hub(t.get_tree())


static func _hhmm(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


func _lunch(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as Node
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var hub := _p5(t)
	t.check(hub != null, "personajes de P5 en el turno")
	if hub == null:
		return
	# Llegar a la hora del lunch sin que nada salga con el salto del reloj (todo «hecho»); después se fuerza a mano.
	PersonajesP5.set_counter("p5_rasec_evento", "hecho")
	PersonajesP5.set_counter("p5_training", "hecho")
	var vz0 := t.get_tree().get_first_node_in_group("vitzo")
	var mentor0 := t.get_tree().get_first_node_in_group("mentor")
	if vz0 != null:
		(vz0.get("_hours_done") as Array).append_array([3, 6])
	if mentor0 != null:
		mentor0.set("_alloc_next", 99)
		mentor0.set("_list_next", 99)
	await t.set_clock(GameState.lunch_clock())
	await t.frames(2)
	if vz0 != null and bool(vz0.call("is_reminder_pending")):
		EventBus.vitzo_reacted.emit()
	if mentor0 != null and bool(mentor0.get("active")):
		mentor0.call("_end_allocation")
	PersonajesP5.set_counter("p5_rasec_evento", "")
	PersonajesP5.set_counter("p5_training", "")
	PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(Discipline.is_lunch_immune(), "AUX Lunch dentro del cupo: inmune")
	var fired: Dictionary = {}
	var t0: Array = [t.game_s()]  # las lambdas capturan por valor: un Array para poder moverlo
	var mark := func(k: String) -> void:
		if not fired.has(k):
			fired[k] = t.game_s() - float(t0[0])
	var qa_spy: Array = t.spy("qa_feedback_called")
	var tr_spy: Array = t.spy("training_called")
	var al_spy: Array = t.spy("allocation_posted")
	var vz_spy: Array = t.spy("vitzo_reminder")
	var steps: Array = t.spy("discipline_step")
	hub.rasec_event_called.connect(func(_k: String) -> void: mark.call("rasec"))
	# Todo vence ahora mismo: Haime (contacto malo), Rasec (su evento), Trainer (su clase), Mentor (allocation), Vitzo
	# (hora del recordatorio), una invitación a Rooms y la lista del Mentor bajo el target.
	var now := GameState.clock_seconds
	hub.qa.state = QaFeedback.State.PENDIENTE
	hub.qa.call_at = now
	var rcfg: Dictionary = (DataLoader.dict("rasec_eventos").get("turnos", {}) as Dictionary).get("2", {})
	var rasec_h := str(rcfg.get("hora", "05:15"))
	rcfg["hora"] = _hhmm(now + 60.0)
	hub.rasec.state = RasecControl.State.LIBRE
	hub.rasec.waited_since = -1.0
	var tr_entry: Dictionary = GameState.turno_data(2)
	var tr_h: Variant = tr_entry.get("training", null)
	if not tr_entry.is_empty():
		tr_entry["training"] = _hhmm(now + 90.0)
	hub.training.state = TrainingControl.State.LIBRE
	var mentor := mentor0
	if mentor != null:
		var at: Array[float] = [now + 30.0]
		mentor.set("_alloc_times", at)
		mentor.set("_alloc_next", 0)
		mentor.set("active", false)
	var vz := vz0
	if vz != null:
		(vz.get("_hours_done") as Array).erase(6)
		EventBus.hour_changed.emit(6)
	EventBus.coaching_requested.emit(60.0)
	var ez := EzlakHub.get_hub(t.get_tree())
	var lb0 := int(Discipline.counters.get("listas_bajo", 0))
	EventBus.ezlak_post.emit("#team-familia", "mentor", "Lista", {"tipo": "allocations", "evaluable": true, "bajo_target": true, "jugador_pct": 50.0})
	# 30 min de juego de lunch, cuadro a cuadro (los cerebros miran el reloj en _process).
	for i in 60:
		await t.advance_clock(30.0)
	await t.seconds(4.0)
	t.check(qa_spy.is_empty() and hub.qa.state == QaFeedback.State.PENDIENTE, "en el lunch Haime no llama a calibración (lo de Joan)")
	t.check(not fired.has("rasec") and hub.rasec.state == RasecControl.State.LIBRE, "en el lunch Rasec no convoca a su evento")
	t.check(tr_spy.is_empty(), "en el lunch el Trainer no convoca al training")
	t.check(al_spy.is_empty(), "en el lunch el Mentor no te pone en allocation")
	t.check(vz_spy.is_empty(), "en el lunch Vitzo no publica su recordatorio")
	t.check(ez != null and ez.rooms_pending and ez.rooms_left >= 59.0, "la invitación a Rooms espera (%.0f s)" % (ez.rooms_left if ez != null else -1.0))
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == lb0, "Shero no lee la lista del Mentor en tu lunch")
	var other := 0
	for s in steps:
		if str(s[0]) != "lunch":
			other += 1
	t.check(other == 0, "ningún escalón de Shero en el lunch (%d)" % other)
	var hud: Node = t.main.find_child("HUD", true, false)
	var disc: Variant = hud.get("_disc") if hud != null else null
	t.check(disc is Label and str((disc as Label).text).contains("Lunch"), "el HUD avisa «Lunch · nadie te convoca» («%s»)" % (str((disc as Label).text) if disc is Label else "?"))
	# Vuelve del lunch (a los 35 min, dentro del cupo): gracia y luego lo aplazado, escalonado.
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	t.player().stand_up()
	await t.frames(2)
	t.check(Discipline.lunch_grace_left() > 80.0, "gracia al volver: %.0f s reales" % Discipline.lunch_grace_left())
	var grace := float(DataLoader.bal("lunch_inmune/gracia_s_real", 90.0))
	var stag := float(DataLoader.bal("lunch_inmune/escalonado_s", 40.0))
	t0[0] = t.game_s()
	var waited := 0.0
	while waited < grace + stag * 6.0 + 10.0:
		await t.seconds(0.5)
		waited += 0.5
		if not qa_spy.is_empty():
			mark.call("haime")
			if hub.qa.state == QaFeedback.State.LLAMADO:
				hub.qa.state = QaFeedback.State.LIBRE  # la prueba no va a la calibración: solo mide cuándo llamó
				hub.qa.call_at = INF
				Discipline.hold_slow_clock("haime", false)
		if waited > grace + 2.0 and ez != null and ez.rooms_pending and not fired.has("rooms"):
			fired["rooms"] = ez.rooms_left  # la invitación de Rooms vuelve a correr al terminar la gracia
		if fired.has("rooms") and ez != null and ez.rooms_pending and ez.rooms_left < float(fired["rooms"]) - 1.0:
			ez.rooms_pending = false  # corre de nuevo: la prueba la descarta (si no, coaching_noshow)
			Discipline.set("_rooms_left", -1.0)
			fired.erase("rooms")
			fired["_rooms_corre"] = true
		if fired.has("rasec") and hub.rasec.state == RasecControl.State.CONVOCADO:
			hub.rasec.state = RasecControl.State.HECHO
			Discipline.hold_slow_clock("rasec", false)
		if not tr_spy.is_empty() and not fired.has("trainer"):
			mark.call("trainer")
			hub.training.state = TrainingControl.State.HECHO
			PersonajesP5.set_counter("p5_training", "hecho")
			Discipline.hold_slow_clock("trainer", false)
			PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
		if not al_spy.is_empty() and not fired.has("mentor"):
			mark.call("mentor")
			Metrics.set_aux(Metrics.Aux.BO)  # cumple la allocation (si no, el RTA te caza: no es de esta prueba)
		if not vz_spy.is_empty():
			mark.call("vitzo")
			EventBus.vitzo_reacted.emit()
		if int(Discipline.counters.get("listas_bajo", 0)) > lb0:
			mark.call("shero_lista")
		if Checkpoints.dying:
			break
	var rooms_ran := fired.has("_rooms_corre")
	fired.erase("_rooms_corre")
	fired.erase("rooms")
	t.check(rooms_ran, "la invitación de Rooms vuelve a correr después de la gracia")
	t.note("tras soltar el lunch (s reales): %s" % str(fired))
	t.check(not Checkpoints.dying, "nadie te mató al volver del lunch")
	t.check(fired.has("haime") and float(fired["haime"]) >= grace - 1.0, "Haime llama recién tras la gracia (%.0f s ≥ %.0f)" % [float(fired.get("haime", -1.0)), grace])
	var order: Array = fired.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return float(fired[a]) < float(fired[b]))
	var ok_gap := true
	for i in range(1, order.size()):
		if float(fired[order[i]]) - float(fired[order[i - 1]]) < stag * 0.6:
			ok_gap = false
	t.check(fired.size() >= 5 and ok_gap, "lo aplazado sale de a uno, separado ≥ %.0f s: %s" % [stag * 0.6, str(order)])
	rcfg["hora"] = rasec_h
	if not tr_entry.is_empty():
		tr_entry["training"] = tr_h
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	await t.back_to_menu()


func _lunch_exc(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as Node
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	# (0) Un lunch fuera de hora (01:00) no es inmune (siguen las reglas del lunch y del RTA) y no gasta el de verdad.
	await t.set_clock(GameState.hhmm_to_seconds("01:00"))
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(not Discipline.is_lunch_immune(), "un lunch fuera de hora no es inmune")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	await t.set_clock(GameState.lunch_clock())
	# (a) Una persecución que ya venía de antes del lunch sigue.
	# El lunch no la cancela: o sigue corriendo o llegó hasta ti (on_catch). Antes se miraba is_hunting a los 3,0 s y
	# ella te alcanza a los ~4 s: con la máquina cargada un cuadro largo se comía ese margen (fallo falso).
	var got := {"catch": false}
	var on_catch := func(_i: Dictionary) -> bool:
		got["catch"] = true
		return true
	Pursuit.start("shero", "ww_sin_ack", 3.0, null, "", -99, Vector3.INF, on_catch, {"pista": "ww_ack"})
	await t.frames(2)
	t.check(Pursuit.is_hunting("shero"), "Shero ya te perseguía")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(3)
	t.check((Pursuit.is_hunting("shero") or bool(got["catch"])) and Discipline.is_lunch_immune(), "poner Lunch no corta la persecución que ya venía")
	await t.seconds(3.0)
	t.check((Pursuit.is_hunting("shero") or bool(got["catch"])) and Discipline.is_lunch_immune(), "la persecución de antes del lunch sigue aunque pongas Lunch")
	Pursuit.stop("shero", "prueba")
	await t.frames(2)
	# (b) Pasado el cupo (45 min) la escalera del lunch corre igual y la inmunidad se acaba.
	var steps: Array = t.spy("discipline_step")
	for i in 47:
		await t.advance_clock(60.0)
	await t.frames(3)
	var lunch_steps := 0
	for s in steps:
		if str(s[0]) == "lunch":
			lunch_steps += 1
	t.check(not Discipline.is_lunch_immune(), "a los 47 min de lunch ya no hay inmunidad")
	t.check(lunch_steps >= 1, "la escalera del lunch excedido corre (%d escalones)" % lunch_steps)
	# (c) Un 2.º lunch en el turno no es inmune.
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(not Discipline.is_lunch_immune(), "un 2.º lunch no es inmune")
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	await t.back_to_menu()


# --- 4. Mesas de las cafeterías ----------------------------------------------------------------------

## Pone al jugador de pie a `dist` m del centro de la mesa (por su lado largo), mirándola, y devuelve lo que apunta el rayo.
func _aim_at(t: Node, tb: Node3D, side: int, dist: float) -> Object:
	var p: Player = t.player()
	var dirs := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	var d: Vector3 = tb.global_transform.basis * (dirs[side] as Vector3)
	d.y = 0.0
	d = d.normalized()
	var c := tb.global_position
	var pos := Vector3(c.x, 0.0, c.z) + d * dist
	pos.y = TaperFlowHelper.floor_y(tb)
	var yaw := rad_to_deg(atan2(d.x, d.z))  # −Z del jugador hacia la mesa
	p.teleport(pos, yaw)
	await t.frames(2)
	p.head.rotation.x = -atan2(p.camera.global_position.y - c.y, dist)
	for i in 4:
		await t.get_tree().physics_frame
	await t.frames(1)
	p.ray.force_raycast_update()
	return p.ray.get_collider() if p.ray.is_colliding() else null


class TaperFlowHelper:
	static func floor_y(n: Node3D) -> float:
		var fl := WorldObjects.TaperFlow.floor_of(n)
		return fl.global_position.y if fl != null else 0.0


func _mesas(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	var b: Building = t.building()
	for fn in [-1, 9]:
		b.go_to_floor(fn, "ascensor")
		await t.frames(4)
		var fl := b.floor_node
		var tables := WorldObjects.TaperFlow.cafe_tables(fl)
		var spots := fl.find_children("Comer_*", "", false, false)
		t.check(tables.size() >= (8 if fn == -1 else 6), "piso %d: %d mesas de cafetería" % [fn, tables.size()])
		t.check(spots.size() == tables.size(), "piso %d: un sitio para comer por mesa (%d/%d), sin calentar nada antes" % [fn, spots.size(), tables.size()])
		WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.CALIENTE)
		var aimed := 0
		var missing: Array[String] = []
		for tb in tables:
			var ok := false
			for side in 4:
				var hit: Object = await _aim_at(t, tb, side, 0.75 if side < 2 else 1.0)
				if hit is WorldObjects.EatSpot and (hit as WorldObjects.EatSpot).table == tb:
					ok = true
					break
			if ok:
				aimed += 1
			else:
				missing.append(str(tb.name))
		t.check(aimed == tables.size(), "piso %d: de pie junto a cada mesa el rayo la encuentra (%d/%d; faltan %s)" % [fn, aimed, tables.size(), str(missing)])
		# Comer de verdad: [E] con el rayo sobre la mesa → te sientas, animación, Fatiga.
		var tb0: Node3D = tables[0]
		var hit0: Object = await _aim_at(t, tb0, 0, 0.75)
		Metrics.set_aux(Metrics.Aux.LUNCH)
		Fatigue.set_value(60.0)
		var p: Player = t.player()
		p.call("_update_hint")
		p.call("_try_interact")
		await t.frames(3)
		var manos := p.camera.get_node_or_null("ManosFx") as ManosFx
		t.check(hit0 is WorldObjects.EatSpot and p.seated and GameState.seated_at.begins_with("mesa_comer"), "piso %d: [E] en la mesa te sienta (%s)" % [fn, GameState.seated_at])
		t.check(manos != null and manos.busy, "piso %d: animación de comer" % fn)
		var expect := 20.0 * Difficulty.fatigue_rate("recuperacion")
		t.check(WorldObjects.TaperFlow.state() == "comido" and absf((60.0 - Fatigue.value) - expect) < 0.01, "piso %d: Fatiga −%.0f (60 → %.0f)" % [fn, expect, Fatigue.value])
		var ws := t.get_tree().get_first_node_in_group("workstation") as Control
		t.check(ws == null or not ws.visible, "sentado a la mesa no aparece la PC")
		p.stand_up()
		await t.frames(2)
		t.check(not p.seated and GameState.seated_at == "", "te levantas de la mesa")
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		GameState.flags.erase("lunch_eaten")
	await t.back_to_menu()


# --- 5. Espejo ------------------------------------------------------------------------------------

func _find_mirror(t: Node) -> WorldObjects.Mirror:
	for fn in [2, 1, -1]:
		t.building().go_to_floor(fn, "ascensor")
		await t.frames(3)
		for n in t.building().floor_node.find_children("Espejo", "", true, false):
			if n is WorldObjects.Mirror:
				return n
	return null


func _face_mirror(t: Node, m: Node3D) -> void:
	var axis := m.global_transform.basis.x.normalized()
	var bath := m.get_parent() as Node3D
	if bath != null and axis.dot(bath.global_position - m.global_position) < 0.0:
		axis = -axis
	axis.y = 0.0
	axis = axis.normalized()
	var pos := m.global_position + axis * 0.85
	pos.y = TaperFlowHelper.floor_y(m)
	t.player().teleport(pos, rad_to_deg(atan2(axis.x, axis.z)))
	await t.frames(3)


func _espejo(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	Engine.time_scale = 1.0
	var m := await _find_mirror(t)
	t.check(m != null, "hay un espejo de baño")
	if m == null:
		Engine.time_scale = 8.0
		return
	await _face_mirror(t, m)
	Fatigue.set_value(20.0)
	GameState.flags["espejo_susto_visto"] = true  # sin el susto al azar en esta vuelta
	var p: Player = t.player()
	var t0 := Time.get_ticks_msec()
	m.interact(p)
	var t_open := Time.get_ticks_msec()
	var game := 0.0  # tiempo de juego con el reflejo abierto (suma de deltas)
	for i in 2:
		await t.get_tree().process_frame
		game += t.get_process_delta_time()
	var v := MirrorView.current
	t.check(v != null and MirrorView.is_open(), "mirarse abre tu reflejo")
	if v == null:
		Engine.time_scale = 8.0
		return
	var cam := v.get("_cam") as Camera3D
	var dc: Vector3 = cam.global_position - m.global_position
	var de: Vector3 = p.camera.global_position - m.global_position
	t.check(absf(dc.dot(v.normal) + de.dot(v.normal)) < 0.05 and cam.near > 0.2, "la cámara está en el punto reflejado de tus ojos (%.2f / %.2f m), con el plano cercano en el espejo" % [dc.dot(v.normal), de.dot(v.normal)])
	var dbl := v.get("_double") as Node3D
	t.check(dbl != null and is_instance_valid(dbl) and dbl.global_position.distance_to(p.global_position) < 0.05, "tu doble (con cabeza) está donde estás")
	# v0.3.2-core: de cara al espejo (antes daba la espalda: el reflejo era tu nuca) y con luz (antes, silueta negra).
	t.check((-dbl.global_transform.basis.z).dot(-v.normal) > 0.7, "tu doble está de CARA al espejo (%.2f)" % (-dbl.global_transform.basis.z).dot(-v.normal))
	var lamp := v.get("lamp") as OmniLight3D
	t.check(lamp != null and is_instance_valid(lamp) and lamp.light_energy >= 1.0 and not lamp.shadow_enabled and (lamp.global_position - m.global_position).dot(v.normal) > 0.1 and lamp.global_position.distance_to(p.camera.global_position) < lamp.omni_range, "una luz de tocador, del lado del espejo, te ilumina la cara mientras te miras")
	t.check(p.input_locked, "mientras te miras no te mueves")
	t.check(t.get_tree().root.find_child("SetCamara", true, false) == null and t.get_tree().root.find_child("SecurityCamView", true, false) == null, "ya no sale la cámara de seguridad de la Fila C")
	while MirrorView.is_open() and game < 3.0:
		await t.get_tree().process_frame
		game += t.get_process_delta_time()
	var dur := (Time.get_ticks_msec() - t0) / 1000.0
	# La duración se mide en tiempo de juego. Antes era el reloj de pared (≤ 2,3 s): con la máquina cargada el motor
	# recorta el paso de cada cuadro (máx. 8 pasos de física) y el juego va más lento que la pared: 2,55-3,15 s de
	# pared con el reflejo durando sus 1,8 s (fallo falso). La pared queda anotada.
	t.note("espejo: armar el reflejo %.2f s · abierto %.2f s de juego · %.2f s de pared" % [(t_open - t0) / 1000.0, game, dur])
	t.check(not MirrorView.is_open() and game <= MirrorView.MAX_SECONDS + 0.1, "el reflejo dura %.2f s de juego (≤ 2 s)" % game)
	await t.frames(2)
	t.check(not p.input_locked, "vuelve el control")
	t.check(t.get_tree().root.find_child("ReflejoSet", true, false) == null and t.get_tree().root.find_child("LuzTocador", true, false) == null, "el doble y la luz de tocador se fueron")
	# Con Fatiga ≥ 50 (distorsión 5): alguien detrás de ti en el reflejo, que no está al terminar.
	GameState.flags.erase("espejo_susto_visto")
	Fatigue.set_value(60.0)
	var dist: Node = t.main.get("distortions")
	if dist != null:
		(dist.get("_seen") as Dictionary).erase("el_espejo")
	var ok_haunt := false
	for attempt in 5:  # la distorsión tiene probabilidad 0,9
		m.interact(p)
		await t.frames(2)
		var v2 := MirrorView.current
		if v2 != null and v2.haunted:
			await t.seconds(MirrorView.HAUNT_AT + 0.1)
			var fig := v2.get("_figure") as Node3D
			t.check(fig != null and fig.visible and fig.global_position.distance_to(p.global_position) > 1.0, "en el reflejo alguien está de pie detrás de ti")
			# v0.3.2-core: `normal` va del espejo al baño; detrás de ti = más lejos del espejo. Antes se comprobaba al
			# revés (back < −0,5) y la figura quedaba DENTRO de la pared, delante del plano cercano: nunca se veía.
			var back: float = (fig.global_position - p.global_position).normalized().dot(v2.normal)
			t.check(back > 0.5, "detrás de ti: más lejos del espejo que tú (%.2f)" % back)
			var cam2 := v2.get("_cam") as Camera3D
			var depth: float = (fig.global_position - cam2.global_position).dot(v2.normal)
			t.check(depth > cam2.near + 0.3 and depth < cam2.far, "y dentro de lo que ve la cámara del reflejo (a %.2f m; el espejo está a %.2f)" % [depth, cam2.near])
			t.check((-fig.global_transform.basis.z).dot(-v2.normal) > 0.7, "te mira a ti (de cara al espejo)")
			ok_haunt = true
			await t.until(func() -> bool: return not MirrorView.is_open(), 3.0)
			break
		await t.until(func() -> bool: return not MirrorView.is_open(), 3.0)
		await t.frames(2)
		if dist != null:
			(dist.get("_seen") as Dictionary).erase("el_espejo")
			(dist.get("_last_real") as Dictionary).erase("el_espejo")
	t.check(ok_haunt, "con Fatiga ≥ 50 aparece la figura en el reflejo")
	await t.frames(2)
	t.check(t.get_tree().root.find_child("AlguienDetras", true, false) == null and not p.input_locked, "al darte vuelta no hay nadie y tienes el control")
	Engine.time_scale = 8.0
	await t.back_to_menu()


# --- 6. Parpadeo y Fatiga ----------------------------------------------------------------------------

func _parpadeo(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	Engine.time_scale = 1.0
	var ov: Node = t.main.get("overlays")
	t.check(ov != null and ov.has_method("blink"), "overlay con párpados")
	if ov == null:
		Engine.time_scale = 8.0
		return
	Fatigue.rub_eyes()
	var t0 := Time.get_ticks_msec()
	await t.until(func() -> bool: return float(ov.get("lid")) > 0.0, 1.0)
	await t.until(func() -> bool: return float(ov.get("lid")) <= 0.0, 2.0)
	var real: float = (Time.get_ticks_msec() - t0) / 1000.0
	var total := float(ov.call("blink_total"))
	t.check(total <= 0.55 and total >= 0.35, "frotarse los ojos: %.2f s (antes 1 s de negro)" % total)
	t.note("parpadeo medido: %.2f s reales" % real)
	# Curva: sube y baja sin saltos (a 60 fps ningún paso > 0,2) y con extremos suaves.
	var c := float(DataLoader.bal("jugador/parpadeo_cerrar_s", 0.13))
	var h := float(DataLoader.bal("jugador/parpadeo_cerrado_s", 0.09))
	var o := float(DataLoader.bal("jugador/parpadeo_abrir_s", 0.28))
	var prev := 0.0
	var max_step := 0.0
	var peak := 0.0
	var tt := 0.0
	while tt <= c + h + o + 0.02:
		var l := float(ov.call("lid_curve", tt, c, h, o))
		max_step = maxf(max_step, absf(l - prev))
		peak = maxf(peak, l)
		prev = l
		tt += 1.0 / 60.0
	t.check(peak >= 0.999 and max_step < 0.2, "curva suave: cierra del todo y el paso máximo a 60 fps es %.3f" % max_step)
	var first := float(ov.call("lid_curve", 1.0 / 60.0, c, h, o))
	var last := float(ov.call("lid_curve", c + h + o - 1.0 / 60.0, c, h, o))
	t.check(first < 0.15 and last < 0.05, "arranca y termina suave (%.3f / %.3f)" % [first, last])
	var samples: Array = ov.get("lid_samples")
	t.check(samples.size() >= 2, "%d cuadros con párpado (no un solo cuadro negro; con la máquina cargada bajan los fps)" % samples.size())
	Engine.time_scale = 8.0
	await t.back_to_menu()


func _fatiga(t: Node) -> void:
	var exp := {"facil": [0.75, 1.2], "normal": [1.0, 0.75], "dificil": [1.25, 0.6], "real": [1.4, 0.5]}
	var rep: Array[String] = []
	for k in ["facil", "normal", "dificil", "real"]:
		var real: bool = k == "real"
		var lvl := {"facil": 0, "normal": 1, "dificil": 2, "real": 2}[k] as int
		await t.start_shift("Marko", 1, GameState.Mode.REAL if real else GameState.Mode.NORMAL, lvl)
		await t.login_at_seat()
		GameState.stop_calm()
		t.check(GameState.is_real_mode() == real, "%s: modo correcto" % k)
		Fatigue.set_value(50.0)
		Fatigue.add(float(DataLoader.bal("fatiga/por_hora", 4.0)))
		var gain := Fatigue.value - 50.0
		Fatigue.set_value(50.0)
		Fatigue.add(float(WorldObjects.TaperFlow.cfg().get("fatiga", -20.0)))
		var taper := 50.0 - Fatigue.value
		Fatigue.set_value(50.0)
		Fatigue.add(float(DataLoader.bal("fatiga/cafe", -15.0)))
		var cafe := 50.0 - Fatigue.value
		var e: Array = exp[k]
		t.check(absf(gain - 4.0 * float(e[0])) < 0.01, "%s: cada hora +%.2f (×%.2f)" % [k, gain, float(e[0])])
		t.check(absf(taper - 20.0 * float(e[1])) < 0.01 and absf(cafe - 15.0 * float(e[1])) < 0.01, "%s: taper −%.1f, café −%.2f (×%.2f)" % [k, taper, cafe, float(e[1])])
		rep.append("%s +%.2f/h taper −%.1f café −%.2f" % [k, gain, taper, cafe])
		await t.back_to_menu()
	t.note(" · ".join(rep))
	t.check(true, "tabla de fatiga por dificultad")


# --- Encontrado jugando (bot humano) ---------------------------------------------------------------

func _correo_evento(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.frames(40)  # Discipline engancha el cerebro de P5
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var hub := _p5(t)
	var steps: Array = t.spy("discipline_step")
	cm.current = {"id": "b2_caso", "canal": "correo", "limite_s_juego": 600.0}
	var correo := func() -> int:
		var n := 0
		for s in steps:
			if str(s[0]) == "correo":
				n += 1
		return n
	# 20 min de caso con el evento de Rasec en curso: no cuentan.
	hub.busy = "evento"
	var raw := 0.0
	while raw <= 1200.0:
		EventBus.email_timer_tick.emit(600.0 - raw)
		raw += 30.0
		await t.frames(1)
	t.check(int(correo.call()) == 0, "durante el evento de Rasec el caso abierto no escala (%d escalones)" % int(correo.call()))
	hub.busy = ""
	while raw <= 1200.0 + 9.0 * 60.0:
		EventBus.email_timer_tick.emit(600.0 - raw)
		raw += 30.0
		await t.frames(1)
	t.check(int(correo.call()) == 0, "al volver quedan los 10 min del caso: a los 9 min todavía nada")
	while raw <= 1200.0 + 13.0 * 60.0:
		EventBus.email_timer_tick.emit(600.0 - raw)
		raw += 30.0
		await t.frames(1)
	t.check(int(correo.call()) >= 1, "pasados los 10 min de trabajo sí escala (%d)" % int(correo.call()))
	cm.current = {}
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	await t.back_to_menu()


# --- Sin terminales y comodín ------------------------------------------------------------------------

func _sin_terminales(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	var b: Building = t.building()
	for fn in [-1, 1, 2, 9]:
		b.go_to_floor(fn, "ascensor")
		await t.frames(6)
		var n := 0
		for c in b.floor_node.find_children("*", "", true, false):
			if c is WorldObjects.WallTerminal or str(c.name).begins_with("Terminal_"):
				n += 1
		t.check(n == 0, "piso %d: %d terminales Fonex de pared (0)" % [fn, n])
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("open_terminal", "T1")
	await t.frames(1)
	t.check(not bool(ws.get("_terminal_mode")), "open_terminal ya no abre nada")
	await t.back_to_menu()


func _press_aux(t: Node, i: int) -> void:
	var ev := InputEventAction.new()
	ev.action = Controls.AUX_ACTIONS[i]
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.frames(2)
	var up := InputEventAction.new()
	up.action = Controls.AUX_ACTIONS[i]
	up.pressed = false
	Input.parse_input_event(up)
	await t.frames(1)


func _aux_solo_pc(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var ws := t.get_tree().get_first_node_in_group("workstation")
	var p: Player = t.player()
	p.stand_up()
	await t.frames(2)
	await _press_aux(t, Metrics.Aux.BO)
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE, "de pie las teclas de AUX no cambian nada (%s)" % Metrics.aux_name())
	var fl := t.building().floor_node as FloorBase
	p.sit_at(fl.seat_by_id("C-14"), "C-14")
	await t.frames(3)
	ws.call("_pick_aux", Metrics.Aux.BO)
	t.check(Metrics.aux == Metrics.Aux.BO, "en tu PC (C-14) sí")
	ws.call("_pick_aux", Metrics.Aux.AVAILABLE)
	p.stand_up()
	await t.frames(2)
	var other := fl.seat_by_id("E-07")
	t.check(other != null, "hay un puesto en otra isla (E-07)")
	if other != null:
		p.sit_at(other, "E-07")
		await t.frames(3)
		t.check((ws as Control).visible, "en una PC de otra isla aparece la PC")
		ws.call("_pick_aux", Metrics.Aux.BO)
		t.check(Metrics.aux == Metrics.Aux.BO, "y se puede cambiar el AUX")
		await t.advance_clock(30.0)
		t.check(Discipline.active_tracks().has("otra_isla"), "con la regla «otra isla» corriendo (%s)" % str(Discipline.active_tracks().keys()))
	await t.back_to_menu()


func _comodin(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.set_clock(GameState.lunch_clock())
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("_pick_aux", Metrics.Aux.LUNCH)
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	t.check(not Comodin.used and Comodin.open(), "lejos de tu PC el comodín se abre (mantener C)")
	Comodin.answer_override = func(_n: String) -> bool: return true
	var shero: Array = t.spy("ezlak_post")
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	Comodin.choose_coworker(0)
	t.check(Comodin.used and Comodin.phase == "ringing", "suena el teléfono de %s (el comodín ya se gastó)" % Comodin.calling)
	var t0 := GameState.clock_seconds
	await t.until(func() -> bool: return Comodin.phase == "", 30.0)
	var waited := GameState.clock_seconds - t0
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE, "%s te marcó Available en tu PC (fin de lunch) a los %.0f s de juego" % [Comodin.coworkers()[0], waited])
	t.check(waited >= 9.0 and waited <= 40.0, "contesta en 10-20 s de juego (%.0f)" % waited)
	var from_shero := 0
	for e in shero:
		if str(e[0]) == "dm:shero" and str((e[3] as Dictionary).get("tipo", "")) == "comodin":
			from_shero += 1
	t.check(from_shero == 1, "Shero lo nota: DM sarcástico (%d)" % from_shero)
	var hud: Node = t.main.find_child("HUD", true, false)
	await t.frames(3)
	t.check(hud != null and str((hud.get("_disc") as Label).text).contains(TranslationServer.translate("B2_COMODIN_HUD_USED")), "HUD: «Comodín usado (1/1)»")
	t.check(not Comodin.open(), "la 2.ª vez en el turno no se puede")
	Comodin.answer_override = Callable()
	await t.back_to_menu()


func _comodin_reintento(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	var first := Comodin.coworkers()[0]
	Comodin.answer_override = func(n: String) -> bool: return n != first
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.BO)
	Comodin.choose_coworker(0)
	await t.until(func() -> bool: return Comodin.phase == "retry", 30.0)
	t.check(Comodin.phase == "retry" and Comodin.retry_left > 20.0, "%s no contesta: tienes %.0f s para llamar a otro" % [first, Comodin.retry_left])
	Comodin.choose_coworker(1)
	await t.until(func() -> bool: return Comodin.phase == "", 30.0)
	t.check(Metrics.aux == Metrics.Aux.BO, "el 2.º (%s) contesta con el mismo comodín y marca BO" % Comodin.coworkers()[1])
	await t.back_to_menu()
	# Nadie contesta: se pierde al vencer el reintento.
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	await t.frames(2)
	Comodin.answer_override = func(_n: String) -> bool: return false
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.BREAK)
	Comodin.choose_coworker(2)
	await t.until(func() -> bool: return Comodin.phase == "retry", 30.0)
	await t.until(func() -> bool: return Comodin.phase == "", 40.0)
	t.check(Comodin.used and Metrics.aux == Metrics.Aux.AVAILABLE, "nadie contestó en 30 s: el comodín se perdió y el AUX no cambió")
	t.check(not Comodin.open(), "y ya no se puede usar en el turno")
	Comodin.answer_override = Callable()
	await t.back_to_menu()


# --- Cola ACD ----------------------------------------------------------------------------------------

func _cm(t: Node) -> ContactManager:
	return t.get_tree().get_first_node_in_group("contact_manager") as ContactManager


func _misses(arr: Array) -> int:
	var n := 0
	for o in arr:
		if str(o[1]) == "perdido":
			n += 1
	return n


func _ring_first(t: Node) -> ContactManager:
	var cm := _cm(t)
	var first: Dictionary = cm.next_scripted()
	await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0)
	await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 6.0)
	return cm


func _acd_bo_timbre(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var out: Array = t.spy("contact_outcome")
	var cm := await _ring_first(t)
	t.check(cm.phase == ContactManager.Phase.OFFERING, "suena un contacto")
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("_pick_aux", Metrics.Aux.BO)
	await t.frames(2)
	t.check(_misses(out) == 1, "pasar a BO con el contacto sonando = 1 perdida (%d)" % _misses(out))
	t.player().stand_up()
	for i in 40:
		await t.advance_clock(30.0)
		await t.frames(3)
	t.check(_misses(out) == 1 and int(Discipline.counters.get("perdidas", 0)) == 1, "20 min de juego en BO: ninguna perdida más (%d)" % _misses(out))
	await t.back_to_menu()


func _acd_evento_rasec(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var out: Array = t.spy("contact_outcome")
	var hub := _p5(t)
	var ws := t.get_tree().get_first_node_in_group("workstation")
	await t.set_clock(GameState.hhmm_to_seconds("05:25"))
	hub.rasec.call_event()
	ws.call("_pick_aux", Metrics.Aux.BO)
	var m := hub.marker("evento_rasec")
	t.player().stand_up()
	if m != null:
		t.player().teleport(m.global_position, 0.0)
	await t.until(func() -> bool: return hub.busy == "evento", 10.0)
	t.check(hub.busy == "evento", "evento de Rasec en curso con AUX BO")
	await t.set_clock(GameState.hhmm_to_seconds("05:30"))
	for i in 20:
		await t.advance_clock(20.0)
		await t.frames(3)
	t.check(_misses(out) == 0, "durante el evento (en BO) ninguna perdida (%d) aunque llegó el guion de las 05:15" % _misses(out))
	await t.back_to_menu()


func _acd_rona(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var out: Array = t.spy("contact_outcome")
	var cm := _cm(t)
	var first: Dictionary = cm.next_scripted()
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("_pick_aux", Metrics.Aux.BO)
	t.player().stand_up()
	await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 120.0)
	await t.seconds(2.0)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)  # de pie en Available (el caso de Joan al volver del evento)
	await t.seconds(60.0)
	var n := _misses(out)
	t.check(n <= 2, "60 s reales de pie en Available: %d perdidas (antes el mismo contacto sonaba cada 18 s: 3-4 y muerte)" % n)
	t.check(not Checkpoints.dying, "sin muerte por llamadas perdidas")
	await t.back_to_menu()


func _acd_cola_drena(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	await t.set_clock(GameState.lunch_clock())
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("_pick_aux", Metrics.Aux.LUNCH)
	for i in 6:
		cm.acd.ambient.append(GameState.clock_seconds)
	var states := {}
	var on_floor := 0
	for n in cm.acd.coworkers():
		states[n] = cm.acd.npc_state(n)
		if states[n] in ["disponible", "contacto"]:
			on_floor += 1
	t.note("compañeros en tu lunch: %s" % str(states))
	t.check(on_floor >= 1, "hay compañeros atendiendo (Available o en contacto) en tu lunch")
	var n0 := cm.acd.size()
	for i in 30:
		await t.advance_clock(30.0)
		await t.frames(2)
	t.check(cm.acd.size() < n0 and cm.acd.npc_handled >= 3, "la cola baja mientras comes (%d → %d; %d atendidos por compañeros)" % [n0, cm.acd.size(), cm.acd.npc_handled])
	t.check(cm.phase == ContactManager.Phase.IDLE, "a ti no te entra nada en lunch")
	await t.back_to_menu()


func _acd_b2b(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	await t.set_clock(GameState.hhmm_to_seconds("01:00"))
	var ws := t.get_tree().get_first_node_in_group("workstation")
	ws.call("_pick_aux", Metrics.Aux.BREAK)
	# Todos los compañeros en lunch a la vez: nadie atiende y la cola crece.
	var now := GameState.clock_seconds
	for n in cm.acd.coworkers():
		(cm.acd.get("_sched") as Dictionary)[n] = [[now - 60.0, now + 3600.0, "lunch"]]
	for i in 6:
		cm.acd.ambient.append(now)
	await t.advance_clock(60.0)
	t.check(cm.acd.available_npcs().is_empty() and cm.acd.size() >= 6, "todos en lunch: cola %d" % cm.acd.size())
	var offers: Array = t.spy("contact_offered")
	ws.call("_pick_aux", Metrics.Aux.AVAILABLE)
	var times: Array[float] = []
	var t0: float = t.game_s()
	while t.game_s() - t0 < 60.0 and times.size() < 6:
		await t.frames(1)
		if cm.phase == ContactManager.Phase.OFFERING:
			times.append(t.game_s() - t0)
			cm.accept()
			await t.frames(1)
			var c := cm.current
			cm.call("_finish", c, true, false, "satisfecho", 5)
	t.note("contactos al volver a Available (s reales): %s" % str(times))
	var cap := int((DataLoader.bal("cola_acd/back_to_back_max", [2, 3, 4]) as Array)[1])
	var run := 0
	var best := 0
	for i in range(1, times.size()):
		run = run + 1 if times[i] - times[i - 1] < 3.6 else 0
		best = maxi(best, run)
	t.check(times.size() >= 2 and best >= 1, "back-to-back: entran seguidos (%d seguidos)" % (best + 1))
	t.check(best + 1 <= cap, "con tope en Normal (%d ≤ %d seguidos; luego una pausa normal)" % [best + 1, cap])
	await t.back_to_menu()


func _acd_perdidas(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var deaths: Array = t.spy("death_sequence_started")
	var steps: Array = t.spy("discipline_step")
	var cm := _cm(t)
	# Sentado en Available sin contestar: cada timbre que vence es una perdida; a la 4.ª, la escalera llega al final.
	var waited := 0.0
	# El WW de la 3.ª se firma (Ack) para que la muerte venga de la 4.ª perdida y no del Ack vencido.
	var pursuit: Array = t.spy("pursuit_started")
	var t0 := GameState.clock_seconds
	while waited < 400.0 and int(Discipline.counters.get("perdidas", 0)) < 4 and not Checkpoints.dying:
		await t.seconds(1.0)
		waited += 1.0
		await t.advance_clock(20.0)
		if Metrics.ack_pending:
			Metrics.give_ack()
	t.note("reloj de juego: %.0f min · persecuciones: %s" % [(GameState.clock_seconds - t0) / 60.0, str(pursuit)])
	var n := int(Discipline.counters.get("perdidas", 0))
	t.check(n >= 4, "4 timbres sin contestar en Available = 4 perdidas (%d, en %.0f s reales)" % [n, waited])
	var last := 0
	for s0 in steps:
		if str(s0[0]) == "llamadas_perdidas":
			last = maxi(last, int(s0[1]))
	t.check(last >= Discipline.Step.WW, "la escalera de llamadas perdidas avanza (escalón %d)" % last)
	t.check(cm.missed_count == n, "ContactManager y Discipline cuentan lo mismo (%d / %d)" % [cm.missed_count, n])
	t.note("muertes: %s" % str(deaths))
	var hunt := false
	for d in deaths:
		hunt = hunt or str(d[0]) == "llamadas_perdidas"
	t.check(hunt or Discipline.active_tracks().has("llamadas_perdidas") or not pursuit.is_empty(), "la 4.ª perdida en Available lleva a la persecución de llamadas perdidas")
	await t.back_to_menu()


func _topico_training(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var hub := _p5(t)
	var b: Building = t.building()
	b.go_to_floor(1, "ascensor")
	await t.until(func() -> bool: return b.current_floor == 1 and Zone.find(t.get_tree(), "topico") != null, 8.0)
	await t.frames(3)
	var nurse: Array = t.spy("shero_message")
	var p: Player = t.player()
	var topico: Zone = Zone.find(t.get_tree(), "topico")
	var sala: Zone = Zone.find(t.get_tree(), "training_sala2")
	t.check(topico != null and sala != null, "piso 1 con zona del tópico (T2) y de la sala de training")
	if topico == null or sala == null:
		await t.back_to_menu()
		return
	t.note("tópico %s · training %s" % [str(topico.rect_xz()), str(sala.rect_xz())])
	# El caso de Joan: de pie en la sala de training, en la esquina más cercana al tópico y junto a la silla libre.
	var spots := [Vector3(13.2, 0, -1.6), Vector3(12.6, 0, -2.2), Vector3(12.3, 0, -2.6), Vector3(11.6, 0, -1.8)]
	var kicked := 0
	for sp in spots:
		p.teleport(sp, 0.0)
		await t.frames(6)
		if p.global_position.distance_to(sp) > 0.5 or not nurse.is_empty():
			kicked += 1
	t.check(kicked == 0 and hub.topico.state == TopicoControl.State.LIBRE, "de pie en la sala de training nadie te echa (%d de %d puntos; antes el radio de 2,4 m del tópico llegaba ahí)" % [kicked, spots.size()])
	# El recodo frente a la puerta del tópico tampoco es el tópico.
	p.teleport(Vector3(11.4, 0, -0.3), 90.0)
	await t.frames(6)
	t.check(nurse.is_empty(), "en el recodo, frente a la puerta, tampoco")
	# Dentro del cuarto sin permiso: el enfermero te devuelve al recodo y Shero lo anota.
	var m: Node3D = hub.marker("topico")
	p.teleport(m.global_position, -90.0)
	await t.until(func() -> bool: return not nurse.is_empty(), 4.0)
	t.check(not nurse.is_empty() and not topico.contains_xz(p.global_position), "dentro del tópico sin permiso sí te echa (%s)" % str(p.global_position))
	await t.back_to_menu()


## Zonas que no deben pisarse (lo que una regla o un personaje usa para saber «dónde estás»).
const EXCLUSIVE_PREFIX := ["topico", "training", "bano", "baño", "banos", "feedback", "sala", "limpieza", "casilleros", "cafeteria", "descanso", "azotea", "guardia", "lobby", "calibracion"]
## Zonas de superficie, sonido o paso (sí se solapan con las salas, a propósito).
const SURFACE_PREFIX := ["vinilico", "ventilacion", "pasillo", "calle", "exterior", "escalera", "fila_c"]


func _exclusive(id: String) -> bool:
	for pre in SURFACE_PREFIX:
		if id.begins_with(pre):
			return false
	return true


## Anidadas a propósito: el mostrador de Fermín dentro del lobby, el huddle de Rasec y los puestos de otras islas
## dentro de la sala de operaciones.
func _nested_ok(a: String, b: String) -> bool:
	for pair in [["guardia", "lobby"], ["sala", "evento_rasec(radio)"], ["sala", "otra_isla:"]]:
		if (a.begins_with(pair[0]) and b.begins_with(pair[1])) or (b.begins_with(pair[0]) and a.begins_with(pair[1])):
			return true
	return false


func _zonas(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var b: Building = t.building()
	var margin := 0.05  # separadas al menos 5 cm (una pared de 0,2 m entre dos zonas de interior deja ~0,2 m)
	var bad: Array[String] = []
	var total := 0
	for fl in [-1, 1, 2, 9]:
		if b.current_floor != fl:
			b.go_to_floor(fl, "ascensor")
			await t.until(func() -> bool: return b.current_floor == fl and b.floor_node != null, 8.0)
			await t.frames(3)
		var rects: Array = []  # [id, Rect2]
		for z in t.get_tree().get_nodes_in_group("zones"):
			var zn := z as Zone
			if zn == null or zn.is_queued_for_deletion() or not b.floor_node.is_ancestor_of(zn) or not _exclusive(zn.zone_id):
				continue
			rects.append([zn.zone_id, zn.rect_xz()])
		# Las áreas por radio alrededor de un marcador cuentan como zona (evento de Rasec, 3,2 m): [id, centro, radio].
		var circles: Array = []
		if fl == 2:
			var m := _p5(t).marker("evento_rasec")
			if m != null:
				circles.append(["evento_rasec(radio)", Vector2(m.global_position.x, m.global_position.z), float(DataLoader.dict("rasec_eventos").get("radio_m", 3.2))])
		# Puestos de otra isla: un cuadro de 1 m alrededor de cada silla libre.
		if fl == 2:
			for id in ["E-07", "E-08", "A-03", "F-12"]:
				var s0 := (b.floor_node as FloorBase).seat_by_id(id)
				if s0 != null:
					rects.append(["otra_isla:" + id, Rect2(s0.global_position.x - 0.5, s0.global_position.z - 0.5, 1.0, 1.0)])
		var ids: Array[String] = []
		for r in rects + circles:
			ids.append(str(r[0]))
		t.note("piso %d: %s" % [fl, ", ".join(ids)])
		total += rects.size() + circles.size()
		for i in rects.size():
			var ia := str(rects[i][0])
			var a: Rect2 = rects[i][1]
			for j in range(i + 1, rects.size()):
				var ic := str(rects[j][0])
				var c: Rect2 = rects[j][1]
				if ia == ic or _nested_ok(ia, ic):
					continue
				if a.grow(margin).intersects(c):
					var inter := a.grow(margin).intersection(c)
					bad.append("piso %d: %s × %s (%.2f × %.2f m)" % [fl, ia, ic, inter.size.x, inter.size.y])
			for ci in circles:
				if _nested_ok(ia, str(ci[0])):
					continue
				var ctr: Vector2 = ci[1]
				var closest := Vector2(clampf(ctr.x, a.position.x, a.end.x), clampf(ctr.y, a.position.y, a.end.y))
				var gap := closest.distance_to(ctr) - float(ci[2])
				if gap < margin:
					bad.append("piso %d: %s × %s (a %.2f m del radio)" % [fl, ia, str(ci[0]), gap])
	for x in bad:
		t.note("solape: " + x)
	t.check(total >= 10, "zonas exclusivas revisadas: %d" % total)
	t.check(bad.is_empty(), "ninguna zona exclusiva pisa a otra (margen %.2f m): %d solapes" % [margin, bad.size()])
	await t.back_to_menu()


func _die_and_reconnect(t: Node, cause: String, killer: String) -> bool:
	await t.die(cause, "", killer)
	var shown: bool = await t.wait_death_shown(12.0)
	t.check(shown, "pantalla de muerte (%s)" % cause)
	await t.reconnect()
	await t.frames(4)
	return shown


func _check_seated_reconnecting(t: Node, what: String) -> void:
	var p: Player = t.player()
	var ws := t.get_tree().get_first_node_in_group("workstation") as Control
	t.check(t.building().current_floor == 2 and p.seated and p.seat_id == "C-14", "%s: reapareces sentado en C-14 (piso %d, silla «%s»)" % [what, t.building().current_floor, p.seat_id])
	t.check(ws != null and ws.visible and bool(ws.get("zoomed")), "%s: con la PC abierta (vista de la PC)" % what)
	t.check(Metrics.reconnecting and Reconexion.active and Metrics.aux_name() == tr("B2_AUX_RECONNECTING"), "%s: AUX «%s» (no Available)" % [what, Metrics.aux_name()])


func _respawn_trainer(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	# Como Joan: provocas al Trainer en el piso 1 (de pie, fuera de la sala de operaciones) y te mata.
	t.player().stand_up()
	var b: Building = t.building()
	b.go_to_floor(1, "ascensor")
	await t.until(func() -> bool: return b.current_floor == 1, 6.0)
	await t.frames(3)
	await _die_and_reconnect(t, "training_inasistencia", "trainer")
	_check_seated_reconnecting(t, "muerte del Trainer")
	t.note("HUD: %s" % Reconexion.hud_text())
	await t.back_to_menu()


func _recon_timeout(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	var out: Array = t.spy("contact_outcome")
	var offers: Array = t.spy("contact_offered")
	# Que haya cola y un guion esperando: lo peor para el primer timbre.
	var first: Dictionary = cm.next_scripted()
	await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 30.0)
	Checkpoints.save_checkpoint("contacto")
	await _die_and_reconnect(t, "aux_incorrecto", "shero")
	_check_seated_reconnecting(t, "tras morir")
	var left0 := Reconexion.left
	var t0: float = t.game_s()
	await t.until(func() -> bool: return not Metrics.reconnecting, 12.0)
	var took: float = t.game_s() - t0
	t.check(not Metrics.reconnecting and Metrics.aux == Metrics.Aux.AVAILABLE, "a los %.1f s pasa solo a Available (%s)" % [took, Metrics.aux_name()])
	t.check(is_equal_approx(Reconexion.duration(), 5.0) and absf(took - left0) < 1.5, "dura %.0f s reales (quedaban %.1f, tardó %.1f)" % [Reconexion.duration(), left0, took])
	t.check(offers.is_empty() and _misses(out) == 0, "mientras reconectaba no sonó nada (%d ofertas, %d perdidas)" % [offers.size(), _misses(out)])
	# Elegir Available al instante no da una perdida al instante: el primer timbre espera y suena entero.
	var t1: float = t.game_s()
	await t.until(func() -> bool: return not offers.is_empty(), 20.0)
	var first_ring: float = t.game_s() - t1
	t.check(not offers.is_empty() and first_ring >= 3.0, "el primer timbre llega %.1f s después de Available (≥ 3 s)" % first_ring)
	t.check(_misses(out) == 0, "y no es una perdida al instante")
	# Loop: 60 s reales quieto en tu PC después de reaparecer no te mata otra vez.
	var deaths: Array = t.spy("death_sequence_started")
	await t.seconds(60.0)
	t.check(deaths.is_empty() and not Checkpoints.dying, "60 s quieto tras reaparecer: ninguna muerte (%s)" % str(deaths))
	t.note("perdidas en esos 60 s: %d (RONA %.0f s)" % [_misses(out), float(DataLoader.bal("cola_acd/rona_s_real", 25.0))])
	await t.back_to_menu()


func _respawn_contacto(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var out: Array = t.spy("contact_outcome")
	var disc: Array = t.spy("contact_disconnected")
	var cm := await _ring_first(t)
	t.check(cm.phase == ContactManager.Phase.OFFERING, "suena el primer contacto")
	var id := str(cm.current.get("id", ""))
	cm.accept()
	await t.seconds(3.0)
	t.check(cm.phase == ContactManager.Phase.ACTIVE, "lo atiendes")
	var aht0 := Metrics.contact_durations.size()
	var missed0 := cm.missed_count
	await _die_and_reconnect(t, "aux_incorrecto", "shero")
	_check_seated_reconnecting(t, "muerte en contacto")
	t.check(disc.size() == 1 and str((disc[0][0] as Dictionary).get("id", "")) == id, "el contacto se cerró como «desconectado» (%d)" % disc.size())
	t.check(_misses(out) == 0 and cm.missed_count == missed0 and int(Discipline.counters.get("perdidas", 0)) == 0, "0 perdidas (%d / %d)" % [_misses(out), cm.missed_count])
	t.check(Metrics.contact_durations.size() == aht0, "no cuenta para el AHT (%d → %d)" % [aht0, Metrics.contact_durations.size()])
	t.check(not (cm.get("_served") as Array).has(id), "vuelve a la cola: %s te vuelve a sonar" % id)
	await t.back_to_menu()


func _respawn_lunch(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var ws := t.get_tree().get_first_node_in_group("workstation")
	await t.set_clock(GameState.lunch_clock())
	ws.call("_pick_aux", Metrics.Aux.LUNCH)
	await t.advance_clock(12.0 * 60.0)
	Checkpoints.save_checkpoint("lunch")  # checkpoint a mitad del lunch (12 min usados)
	var left_cp := Metrics.quota_left(Metrics.Aux.LUNCH)
	t.note("checkpoint %s · modo %s · lunch usado %.0f s · cupo %.0f s" % [str(Checkpoints.last_checkpoint.get("kind", "")), Checkpoints.checkpoint_mode(), float(Metrics.time_in_aux[Metrics.Aux.LUNCH]), left_cp])
	await t.advance_clock(8.0 * 60.0)
	await _die_and_reconnect(t, "aux_incorrecto", "shero")
	_check_seated_reconnecting(t, "muerte en el lunch")
	t.check(Reconexion.resume_aux == Metrics.Aux.LUNCH and absf(Reconexion.resume_left_s - left_cp) < 60.0, "«Te quedaban %d min de lunch» (%s)" % [int(Reconexion.resume_left_s / 60.0), Reconexion.hud_text()])
	t.check(Reconexion.hud_text().contains(str(int(ceil(left_cp / 60.0)))), "el HUD lo dice: %s" % Reconexion.hud_text())
	var b0 := Metrics.breaks_used
	await t.seconds(1.0)
	ws.call("_pick_aux", Metrics.Aux.LUNCH)
	await t.frames(2)
	var q := Metrics.quota_left(Metrics.Aux.LUNCH)
	t.check(not Metrics.reconnecting and Metrics.aux == Metrics.Aux.LUNCH, "elegir Lunch termina «Reconectando» y sigues en Lunch")
	t.check(absf(q - left_cp) < 60.0 and q < GameState.lunch_minutes() * 60.0 - 60.0, "retoma el cupo que quedaba (%s de %s; no lo reinicia)" % [Loc.mmss(q), Loc.mmss(GameState.lunch_minutes() * 60.0)])
	t.check(Metrics.breaks_used == b0 and Discipline.is_lunch_immune(), "sigue inmune y sin gastar nada más")
	await t.back_to_menu()


func _voces(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var vd := t.get_tree().root.get_node("VoiceDirector")
	vd.call("reset_audit")
	var subs: Array = []
	var starts: Array = []
	var on_sub := func(sp: String, tx: String, _s: float) -> void: subs.append([Time.get_ticks_msec(), sp, tx])
	var on_start := func(id: String, sp: String, pr: int) -> void: starts.append([Time.get_ticks_msec(), id, sp, pr])
	vd.connect("subtitle_shown", on_sub)
	vd.connect("line_started", on_start)
	var hub := _p5(t)
	var ws := t.get_tree().get_first_node_in_group("workstation")
	await t.set_clock(GameState.hhmm_to_seconds("05:25"))
	# Todo a la vez, en el mismo cuadro: evento de Rasec (PA + su voz), DM de Shero, un compañero, un murmullo, Haime.
	hub.rasec.call_event()
	EventBus.ezlak_post.emit("dm:shero", "shero", "@%s ¿estás?" % GameState.agent, {"mention": true})
	AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala")
	PersonajesP5.say("Haime", "haime", "pone_coaching", "Te espero en la sala de calibración.")
	vd.call("say", "voces/agentes/murmullo_prueba", VoiceDirector.P.BARK, "agentes", Callable(), {"text": "(murmullo)", "max_wait": 0.0})  # como los murmullos de AudioDirector
	t.check(int(vd.get("overlaps")) == 0, "al pedirlas todas juntas suena una sola")
	var cur: Object = vd.get("current")
	# v0.3.2-core: una línea importante que ya suena no se corta (termina su frase); la de mayor prioridad es la que
	# suena o la primera de la cola.
	var q0: Object = (vd.get("queue") as Array)[0] if not (vd.get("queue") as Array).is_empty() else null
	t.check(cur != null and bool(cur.get("must")) and (int(cur.get("priority")) == VoiceDirector.P.DIRECTO or (q0 != null and int(q0.get("priority")) == VoiceDirector.P.DIRECTO)),
		"suena una importante y la de mayor prioridad (directa) va primera (%s · cola: %s)" % [str(cur.get("id")) if cur != null else "—", str(q0.get("id")) if q0 != null else "—"])
	var dropped0 := int(vd.get("lines_dropped"))
	t.check(dropped0 >= 1, "el murmullo no espera: se pierde (%d descartadas)" % dropped0)
	# Una llamada de cliente pasa delante de las directas que esperan, y su subtítulo va pegado a su voz.
	var first: Dictionary = _cm(t).next_scripted()
	await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0)
	var cm := _cm(t)
	await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 6.0)
	cm.accept()
	await t.frames(3)
	# La voz del cliente («clientes») y su subtítulo («cliente») van juntos: una línea, no voz y después el texto.
	var queued_sub := false
	var cli: Object = null
	for q in ([vd.get("current")] if vd.get("current") != null else []) + (vd.get("queue") as Array):
		queued_sub = queued_sub or str((q as Object).get("id")) == "sub:cliente"
		if str((q as Object).get("id")).begins_with("voces/clientes"):
			cli = q
	if cli != null:
		t.check(str(cli.get("text")) != "" and not queued_sub, "la voz del cliente trae su subtítulo pegado (%s)" % str(cli.get("text")).left(40))
	else:
		t.check(not queued_sub, "el subtítulo del cliente no espera en cola detrás de su voz")
	var before: Object = vd.get("current")
	vd.call("say", "sub:cliente", VoiceDirector.P.CLIENTE, "cliente", Callable(), {"text": "Hola, ¿me escuchas? Me cobraron dos veces.", "seconds": 3.0})
	cur = vd.get("current")
	q0 = (vd.get("queue") as Array)[0] if not (vd.get("queue") as Array).is_empty() else null
	var cli_first := (cur != null and int(cur.get("priority")) == VoiceDirector.P.CLIENTE) or (q0 != null and int(q0.get("priority")) == VoiceDirector.P.CLIENTE)
	t.check(cli_first, "el cliente de la llamada va primero: suena ya o es el siguiente (%s · cola %s)" % [str(cur.get("speaker")) if cur != null else "—", str(q0.get("speaker")) if q0 != null else "—"])
	var got_cli: bool = await t.until(func() -> bool: return vd.get("current") != null and int((vd.get("current") as Object).get("priority")) == VoiceDirector.P.CLIENTE, 160.0)
	t.check(got_cli and (before == null or int(before.get("priority")) == VoiceDirector.P.CLIENTE or str(before.get("result")) == "dicha"), "la línea que sonaba terminó su frase (no se cortó a la mitad: %s) y después habló el cliente" % (str(before.get("result")) if before != null else "—"))
	# Muchas más mientras tanto: ninguna se apila.
	var duck_seen := false
	for i in 6:
		EventBus.subtitle.emit("ezlak", "Aviso %d de Ezlaki" % i, 3.0)
		AudioManager.play_voice("comp", "comp_viene_shero", tr("COMP_VIENE_SHERO"), "Sala")
		await t.seconds(1.0)
		var c2: Object = vd.get("current")
		duck_seen = duck_seen or (c2 != null and bool(c2.get("has_audio")) and bool(vd.call("ducked")))
	await t.until(func() -> bool: return vd.get("current") == null and (vd.get("queue") as Array).is_empty(), 60.0)
	# Durante la muerte solo pasa el screamer, y su subtítulo (la frase gritada) sí se ve.
	vd.set("_hold_low", true)
	vd.set("death_killer", "shero")
	vd.call("stop_all", "prueba")
	var n_subs := subs.size()
	AudioManager.play_voice("comp", "comp_viene_shero", tr("COMP_VIENE_SHERO"), "Sala")
	EventBus.subtitle.emit("ezlak", "Aviso de Ezlaki", 3.0)
	t.check(vd.get("current") == null and subs.size() == n_subs, "muriendo, un compañero o Ezlaki no hablan")
	EventBus.subtitle.emit("shero", "¡A TRABAJAR!", 2.0)
	EventBus.subtitle.emit("shero", "¡AHORA!", 2.0)
	t.check(subs.size() == n_subs + 2 and str(subs[-1][2]) == "¡AHORA!", "muriendo, los subtítulos del screamer se ven (el más nuevo encima)")
	vd.set("_hold_low", false)
	vd.call("stop_all", "prueba")
	vd.disconnect("subtitle_shown", on_sub)
	vd.disconnect("line_started", on_start)
	# Línea de tiempo: ningún tramo empieza antes de que termine el anterior (+ el fundido de 80 ms).
	var tl: Array = vd.get("timeline")
	var bad := 0
	for i in range(1, tl.size()):
		var prev_end := int(tl[i - 1][1])
		if prev_end < 0 or int(tl[i][0]) + 1 < prev_end - 100:
			bad += 1
	t.note("líneas: %d dichas, %d descartadas/vencidas · %d subtítulos · línea de tiempo %d tramos" % [int(vd.get("lines_said")), int(vd.get("lines_dropped")), subs.size(), tl.size()])
	t.check(int(vd.get("overlaps")) == 0 and bad == 0, "0 solapes de voz (%d) y la línea de tiempo no se pisa (%d)" % [int(vd.get("overlaps")), bad])
	t.check(subs.size() == starts.size() or subs.size() <= starts.size(), "un subtítulo por línea, nunca dos a la vez (%d subtítulos, %d líneas)" % [subs.size(), starts.size()])
	# v0.3.2-core: la misma línea pedida 6 veces no se apila (repetidas), los avisos de Ezlaki van por su fila (no ocupan
	# el canal de las voces) y ninguna línea importante se perdió.
	t.check(int(vd.get("lines_merged")) >= 3, "la misma línea pedida muchas veces no se apila (%d repetidas)" % int(vd.get("lines_merged")))
	var ez_notes := 0
	for n in vd.get("notice_log") as Array:
		if str(n[1]) == "ezlak":
			ez_notes += 1
	t.check(ez_notes >= 2, "los avisos de Ezlaki salen por la fila de avisos (%d), no por el canal de las voces" % ez_notes)
	t.check((vd.get("lost_important") as Array).is_empty(), "ninguna línea importante se perdió %s" % str(vd.get("lost_important")))
	t.check(duck_seen, "con una voz sonando la música y el ambiente bajan (duck)")
	await t.back_to_menu()

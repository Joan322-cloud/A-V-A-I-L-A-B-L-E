## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P4 · Ezlaki y Mentor (PLAN §6.4, §2 #40-45): cada mensaje cae en su canal, insignias, DMs por
## agente, DM de Shero con respuestas rápidas, API ezlak_post para P3/P5 (typing, editar, borrar, DMs nuevos),
## recordatorio de Vitzo (reacción en la PC y en el terminal), lista de allocations y minitrainings.


func escenarios() -> Array[String]:
	return ["ezlak_canales", "ezlak_dm_agentes", "ezlak_dm_shero", "ezlak_api", "vitzo_recordatorio", "mentor_lista", "minitraining"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"ezlak_canales": await _canales(t)
		"ezlak_dm_agentes": await _dm_agentes(t)
		"ezlak_dm_shero": await _dm_shero(t)
		"ezlak_api": await _api(t)
		"vitzo_recordatorio": await _vitzo(t)
		"mentor_lista": await _lista(t)
		"minitraining": await _minitraining(t)


func _hub(t: Node) -> EzlakHub:
	return EzlakHub.get_hub(t.get_tree())


func _authors(hub: EzlakHub, ch: String) -> Array:
	var out: Array = []
	for m in hub.messages(ch):
		out.append(str(m.get("autor", "")))
	return out


func _canales(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.running = false
	var hub := _hub(t)
	t.check(hub.order.slice(0, 4) == ["#allocations", "#site-updates", "#team-familia", "dm:shero"], "canales fijos + DM Shero (%s)" % str(hub.order))
	await t.set_clock(8.0 * 3600.0)
	await t.seconds(11.0)  # mensajes con "escribiendo…", ediciones (7 s) y borrados (9 s)
	var prog: Array = DataLoader.dict("ezlak_canales").get("programados", [])
	for p in prog:
		if not (p.get("turnos", []) as Array).has(2.0) and not (p.get("turnos", []) as Array).has(2):
			continue
		var ch := str(p.get("canal", ""))
		var who := str(p.get("autor", ""))
		var authors := _authors(hub, ch)
		t.check(authors.has(who) or who == "companero", "%s %s → %s (%s)" % [str(p.get("hora", "")), who, ch, str(authors)])
	t.check(_authors(hub, "#allocations").has("rta") and _authors(hub, "#allocations").has("shero"), "#allocations: RTA (órdenes y tags) y Shero (excesos, 'no hay breaks')")
	t.check(_authors(hub, "#site-updates").has("om") and _authors(hub, "#site-updates").has("haime") and _authors(hub, "#site-updates").has("rasec"), "#site-updates: OM, QA (Haime) y TM (Rasec)")
	t.check(_authors(hub, "#team-familia").has("shero") and _authors(hub, "#team-familia").has("mentor"), "#team-familia: Shero y Mentor")
	t.check(int(hub.channels["#site-updates"]["unread"]) > 0 and hub.unread_total() > 5, "insignias de no leídos (total %d)" % hub.unread_total())
	# Edición y borrado (T2: Shero 'Buen trabajo… Casi todos.', OM borra el bono).
	var edited := false
	for m in hub.messages("#team-familia"):
		if bool(m.get("editado", false)):
			edited = true
	t.check(edited, "un mensaje de Shero aparece editado")
	var deleted := false
	for m in hub.messages("#site-updates"):
		if bool(m.get("borrado", false)):
			deleted = true
	t.check(deleted, "un mensaje del OM se borra ('Este mensaje fue eliminado.')")
	# Adaptadores v0.2.
	EventBus.rta_tag.emit("@%s AUX incorrecto" % GameState.agent)
	EventBus.shero_message.emit("Hola team", "canal")
	EventBus.shero_message.emit("Tú", "dm")
	await t.frames(2)
	var last_alloc: Dictionary = hub.messages("#allocations").back()
	t.check(str(last_alloc.get("autor", "")) == "rta" and bool(last_alloc.get("mention", false)), "rta_tag → #allocations con mención")
	t.check(str((hub.messages("#team-familia").back() as Dictionary).get("texto", "")) == "Hola team", "shero_message canal → #team-familia")
	t.check(str((hub.messages("dm:shero").back() as Dictionary).get("texto", "")) == "Tú", "shero_message dm → DM Shero")
	hub.mark_read("#allocations")
	t.check(int(hub.channels["#allocations"]["unread"]) == 0, "abrir el canal lo marca leído")


func _dm_agentes(t: Node) -> void:
	var table: Dictionary = DataLoader.dict("ezlak_canales").get("dms_por_agente", {})
	for agent in GameState.AGENTS:
		await t.start_shift(agent, 1)
		await t.login_at_seat()
		GameState.running = false
		var hub := _hub(t)
		var dms: Array = []
		for ch in hub.order:
			if str(ch).begins_with("dm:") and str(ch) != "dm:shero":
				dms.append(str(ch).substr(3))
		var want: Array = table.get(agent, [])
		t.check(dms == want and want.size() >= 2 and want.size() <= 3, "%s: DMs exactamente con %s (hay %s)" % [agent, str(want), str(dms)])
		await t.set_clock(8.75 * 3600.0 - 60.0)
		await t.seconds(4.0)
		for w in want:
			t.check(hub.messages("dm:" + str(w)).size() >= 2, "%s: %s le escribe (%d mensajes)" % [agent, w, hub.messages("dm:" + str(w)).size()])
		var replies := hub.quick_replies_for("dm:" + str(want[0]))
		t.check(replies.has("jaja") and replies.has("gracias"), "%s: respuestas rápidas en el DM del compañero" % agent)


func _dm_shero(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var topico: Array = t.spy("topico_requested")
	var replies: Array = t.spy("ezlak_quick_reply")
	t.check(hub.quick_replies_for("dm:shero") == ["ack", "ok", "me_siento_mal", "en_un_caso"], "DM Shero: Ack · Ok · Me siento mal · Estoy en un caso")
	hub.quick_reply("dm:shero", "me_siento_mal")
	t.check(topico.size() == 1, "'Me siento mal' emite topico_requested (P5)")
	t.check(replies.size() == 1 and str(replies[0][1]) == "me_siento_mal", "ezlak_quick_reply(canal, id) para P3/P5")
	Metrics.issue_written_warning("aht_bo")
	await t.frames(1)
	var ww: Dictionary = hub.messages("dm:shero").back()
	t.check(str(ww.get("tipo", "")) == "ww" and (ww.get("quick_replies", []) as Array).has("ack"), "el WW llega al DM de Shero con botón Ack")
	hub.quick_reply("dm:shero", "ack", ww)
	t.check(not Metrics.ack_pending, "Ack desde el DM")
	var n0 := hub.messages("dm:shero").size()
	hub.quick_reply("dm:shero", "en_un_caso")
	await t.seconds(2.5)
	t.check(hub.messages("dm:shero").size() >= n0 + 2, "'Estoy en un caso' → Shero responde")
	# Rooms (coaching) desde el DM.
	var joined: Array = t.spy("coaching_joined")
	EventBus.coaching_requested.emit(60.0)
	await t.frames(1)
	t.check(hub.rooms_pending, "invitación a Ezlaki Rooms en el DM de Shero")
	hub.quick_reply("dm:shero", "join_rooms")
	t.check(joined.size() == 1 and not hub.rooms_pending, "unirse a Rooms desde Ezlaki")


func _api(t: Node) -> void:
	await t.start_shift("Llauri", 2)
	await t.login_at_seat()
	var hub := _hub(t)
	EventBus.ezlak_post.emit("dm:haime", "haime", "Pasa a Coaching. Sala de calibración.", {"tipo": "qa_llamado", "mention": true, "quick_replies": ["voy", "ok"]})
	await t.frames(1)
	t.check(hub.order.has("dm:haime") and hub.messages("dm:haime").size() == 1, "un DM nuevo (Haime) aparece al primer mensaje")
	t.check(int(hub.channels["dm:haime"]["unread"]) == 1 and bool(hub.channels["dm:haime"]["mention"]), "con insignia y mención")
	EventBus.ezlak_post.emit("dm:trainer", "trainer", "Te espero en la sala 2.", {"typing_s": 1.0})
	await t.frames(2)
	t.check(str(hub.typing_now.get("dm:trainer", "")) == "trainer" and hub.messages("dm:trainer").is_empty(), "typing_s: primero 'escribiendo…'")
	await t.seconds(1.5)
	t.check(hub.messages("dm:trainer").size() == 1 and not hub.typing_now.has("dm:trainer"), "luego el mensaje")
	EventBus.ezlak_post.emit("#team-familia", "shero", "Buen trabajo.", {"edita": "Buen trabajo. Casi.", "edita_s": 0.5, "borra_s": 1.2})
	await t.seconds(0.9)
	# v0.3.1: con la máquina cargada otro mensaje del canal (p. ej. el Mentor respondiendo a Shero) puede quedar
	# último: se busca el de Shero.
	var m: Dictionary = hub.messages("#team-familia").back()
	for mm in hub.messages("#team-familia"):  # v0.3.1: hay más publicaciones programadas; se busca el mensaje
		if str(mm.get("texto", "")).begins_with("Buen trabajo.") and (mm.get("meta", {}) as Dictionary).has("edita_s") and float(mm["meta"]["edita_s"]) == 0.5:
			m = mm
	t.check(bool(m.get("editado", false)) and str(m.get("texto", "")) == "Buen trabajo. Casi.", "meta.edita → editado")
	await t.seconds(0.8)
	t.check(bool(m.get("borrado", false)), "meta.borra_s → eliminado")
	EventBus.ezlak_post.emit("allocations", "rasec", "Evento en 2 min. Pasen a BO.", {"tipo": "rasec_evento"})
	await t.frames(1)
	t.check(str((hub.messages("#allocations").back() as Dictionary).get("autor", "")) == "rasec", "canal sin '#' se normaliza")
	var r: Array = t.spy("ezlak_quick_reply")
	hub.quick_reply("dm:haime", "voy", hub.messages("dm:haime")[0])
	t.check(r.size() == 1 and str(r[0][0]) == "dm:haime" and str(r[0][1]) == "voy", "respuesta rápida en un DM de P5 → ezlak_quick_reply")


func _vitzo(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var v := t.get_tree().get_first_node_in_group("vitzo")
	var ws: Node = t.main.get_node("UI/Workstation")
	var deaths: Array = t.spy("death_requested")
	# 1) PC: [Enter] reacciona (sin enfocar nada con Tab).
	ws.call("set_zoom", true)
	v.call("post_reminder")
	await t.frames(1)
	var msg: Dictionary = hub.messages("#site-updates").back()
	t.check(str(msg.get("reaccion", "")) != "" and bool(v.call("is_reminder_pending")), "recordatorio en #site-updates con reacción pendiente")
	await _key(t, KEY_ENTER)
	t.check(not bool(v.call("is_reminder_pending")) and bool(msg.get("reaccionado", false)), "PC: [Enter] reacciona al recordatorio")
	# 2) v0.3.2: ya no hay terminales de pared: open_terminal no abre nada ni deja cambiar el AUX.
	ws.call("set_zoom", false)
	ws.call("open_terminal", "T1")
	await t.frames(1)
	t.check(not bool(ws.get("_terminal_mode")), "v0.3.2: sin terminal de pared (open_terminal no abre nada)")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.login_at_seat()
	# 3) Clic en la reacción (hub.react) y no reaccionar = muerte.
	v.call("post_reminder")
	await t.frames(1)
	t.check(hub.react(hub.pending_actionable()), "clic en la reacción")
	v.call("post_reminder")
	await t.until(func() -> bool: return not deaths.is_empty(), 60.0)
	t.check(not deaths.is_empty() and str(deaths[0][0]) == "vitzo_reminder", "sin reacción → muerte vitzo_reminder")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _key(t: Node, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.frames(2)
	var up: InputEventKey = ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await t.frames(2)


func _lista(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	var posts: Array = t.spy("ezlak_post")
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(mentor != null, "el Mentor existe en T2 (v0.2 solo en T3)")
	GameState.running = false
	Metrics.reset_shift()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.advance_clock(30.0 * 60.0)
	Metrics.set_aux(Metrics.Aux.BO)
	await t.advance_clock(20.0 * 60.0)
	await t.set_clock(GameState.hhmm_to_seconds("01:30") + 1.0)
	await t.frames(2)
	var lista: Dictionary = {}
	for p in posts:
		if str((p[3] as Dictionary).get("tipo", "")) == "allocations":
			lista = p[3]
			t.check(str(p[0]) == "#team-familia" and str(p[1]) == "mentor", "la lista la publica el Mentor en #team-familia")
	t.check(not lista.is_empty(), "lista de allocations a las 01:30")
	t.check((lista.get("lista", {}) as Dictionary).size() == 5 and (lista.get("lista", {}) as Dictionary).has("Marko"), "la lista trae los 5 agentes, incluido el jugador")
	t.check(bool(lista.get("evaluable", false)) and bool(lista.get("bajo_target", false)) and float(lista.get("jugador_pct", 100)) < 70.0, "con 30 min Available + 20 BO (60 %%) → bajo_target (meta para P3)")
	var horas: Array = DataLoader.dict("lineas_mentor").get("lista_horas", [])
	t.check(horas == ["01:30", "03:00", "04:30", "06:00", "07:30"], "cada 90 min")
	# Allocations a BO del turno (turnos.json/allocations_bo).
	t.check(mentor._alloc_times.size() == int(GameState.turno_cfg("allocations_bo", 0)), "T2: %d allocations a BO" % mentor._alloc_times.size())
	var orders: Array = t.spy("allocation_posted")
	mentor.post_allocation_now()
	t.check(orders.size() == 1 and int(orders[0][0]) == Metrics.Aux.BO and Metrics.allocation_aux == Metrics.Aux.BO, "allocation a BO (20 min)")
	t.check(absf(float(orders[0][2]) - GameState.clock_seconds - 20.0 * 60.0) < 1.0, "dura 20 min de juego")


func _minitraining(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.running = false
	var posts: Array = t.spy("ezlak_post")
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	await t.set_clock(GameState.hhmm_to_seconds("00:21"))
	t.check(mentor.minitrainings_open == ["mt_empatia"], "00:20: minitraining abierto en Campus")
	var ws: Node = t.main.get_node("UI/Workstation")
	var desk: PcDesktop = ws.get("desktop") as PcDesktop
	desk.open_app("campus")
	desk.campus.answer("mt_empatia", false)
	t.check(mentor.minitrainings_done.is_empty(), "respuesta incorrecta: no se completa")
	desk.campus.answer("mt_empatia", true)
	t.check(mentor.minitrainings_done == ["mt_empatia"], "respuesta correcta en Campus: completado")
	await t.set_clock(GameState.hhmm_to_seconds("06:20"))
	t.check(mentor.minitrainings_pending() == 2, "a las 06:20 quedan 2 pendientes")
	posts.clear()
	await t.set_clock(GameState.hhmm_to_seconds("08:01"))
	await t.seconds(2.5)
	var shero := false
	for p in posts:
		if str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("tipo", "")) == "minitraining_pendiente":
			shero = true
	t.check(shero, "08:00 con minitrainings pendientes: llamado de Shero (meta.tipo minitraining_pendiente)")

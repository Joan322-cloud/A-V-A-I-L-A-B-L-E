## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P5 (personajes): revisión de Don Fermín, punto REC, feedback de Haime, quiz del training, evento
## de Rasec (karaoke / charadas / sillas), tópico con el enfermero y tags del RTA en #allocations.
## `-- --shot p5` las captura todas (mejor con `--turno 2`: training y tópico abiertos).
## `-- --shot p5_video:<feedback|evento|rta|guardia>` para grabar con --write-movie: marca en el log
## "[video] inicio N" y "[video] fin N" (fotogramas dibujados), como p2_mundo.gd.


func shots() -> Array[String]:
	# p5_guardia primero: la revisión solo existe antes del login.
	return ["p5_guardia", "p5_rec", "p5_feedback", "p5_feedback_3", "p5_quiz", "p5_evento", "p5_evento_charadas", "p5_evento_sillas", "p5_topico", "p5_rta_allocations", "p5_rta_caza", "p5_video:"]


func _hub(s: Node) -> PersonajesP5:
	return PersonajesP5.get_hub(s.get_tree())


## Sin contactos ni Shero v0.2 que interrumpan la vista.
func _quiet(s: Node) -> void:
	var cm := s._main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()


func _set_clock(t: float) -> void:
	GameState.clock_seconds = t
	EventBus.clock_tick.emit(t)


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


func _until(s: Node, cond: Callable, timeout_s: float) -> bool:
	var t := 0.0
	while t < timeout_s:
		if cond.call():
			return true
		await s.get_tree().create_timer(0.1).timeout
		t += 0.1
	return bool(cond.call())


func _floor(s: Node, n: int, spawn: String = "ascensor") -> void:
	var b: Building = s._building()
	if b.current_floor != n:
		b.go_to_floor(n, spawn)
		await _wait(s, 0.3)
	_quiet(s)


func _sit(s: Node, seat_id: String) -> void:
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_" + seat_id, true, false) as Node3D if fl != null else null
	var p: Player = s._player()
	if seat == null:
		printerr("[shot] sin asiento ", seat_id)
		return
	if p.seated:
		p.stand_up()
	p.sit_at(seat, seat_id)
	await _wait(s, 0.2)


## Mira a un punto (gira el cuerpo y la cabeza del jugador).
func _look_at(s: Node, target: Vector3, pitch_bias: float = 0.0) -> void:
	var p: Player = s._player()
	var d := target - p.head.global_position
	var yaw := atan2(-d.x, -d.z)
	p.rotation.y = yaw
	var flat := Vector2(d.x, d.z).length()
	p.head.rotation.x = clampf(atan2(d.y, flat) + pitch_bias, -1.2, 1.2)


func _bad_contact() -> void:
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t1c1":
			c = (x as Dictionary).duplicate(true)
	c["_qa"] = ["prometer_sin_verificar", "respuesta_vaga", "dato_personal"]
	c["_choices"] = ["inicio.c", "repite_fuerte.a"]
	EventBus.contact_outcome.emit(c, "molesto", 1)


func _haime_session(s: Node, n: int) -> void:
	var hub := _hub(s)
	await s._sit_c14()
	_quiet(s)
	PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	_bad_contact()
	await _wait(s, 0.1)
	hub.qa.call_now()
	await _wait(s, 0.5)
	Metrics.set_aux(Metrics.Aux.COACHING)
	await _sit(s, "calibracion")
	await _until(s, func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)


func _event(s: Node, kind: String) -> void:
	var hub := _hub(s)
	await s._sit_c14()
	_quiet(s)
	GameState.flags["p5_tema"] = "halloween"
	hub.rasec.call_event(kind)
	await _wait(s, 0.6)
	Metrics.set_aux(Metrics.Aux.BO)
	s._player().stand_up()
	var m := s._building().floor_node.find_child("evento_rasec", true, false) as Node3D
	if m != null:
		s._player().teleport(m.global_position + Vector3(0, 0, 2.2), 0.0)
	await _until(s, func() -> bool: return hub.rasec.state == RasecControl.State.EVENTO, 4.0)


func _face_rasec(s: Node) -> void:
	var r := s.get_tree().get_first_node_in_group("p5_rasec_actor")
	var a := r.get("actor") as Node3D if r != null else null
	if a != null:
		_look_at(s, a.global_position + Vector3(0, 1.3, 0), -0.05)


func _force_strike(hub: PersonajesP5) -> void:
	var tol := float(GameState.turno_cfg("rta_tolerancia_s", 90.0)) * Difficulty.scale("tolerancia_rta")
	hub.rta.wrong_elapsed = maxf(hub.rta.wrong_elapsed, tol - 0.3)


func _rta_two_tags(s: Node) -> void:
	var hub := _hub(s)
	await s._sit_c14()
	_quiet(s)
	_set_clock(3.0 * 3600.0 + 5.0 * 60.0)  # después de los tags de Ttoom (02:15-03:02) en #allocations
	await _wait(s, 0.3)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	PerritoRTA.dictate(Metrics.Aux.BO)
	await _until(s, func() -> bool: return hub.rta.wrong_elapsed >= 0.0, 2.0)
	_force_strike(hub)
	await _until(s, func() -> bool: return hub.rta.strikes() >= 1, 3.0)
	_force_strike(hub)
	await _until(s, func() -> bool: return hub.rta.strikes() >= 2, 3.0)


func shoot(name: String, arg: String, s: Node) -> void:
	var hub := _hub(s)
	if hub == null:
		printerr("[shot] sin PersonajesP5")
		return
	match name:
		"p5_guardia":
			await _floor(s, -1, "calle")
			var g := s.get_tree().get_first_node_in_group("p5_guardia")
			if g == null or GameState.logged_in:
				printerr("[shot] la revisión solo existe antes del login (corre p5_guardia primero)")
				return
			var actor := g.get("actor") as Node3D
			var turn := s._building().floor_node.find_child("Molinete0", true, false) as Node3D
			if turn != null:
				s._player().teleport(turn.global_position + Vector3(0, 0, 1.6), 0.0)
			g.call("start_check")
			await _wait(s, 3.4 * 1.6)  # en el paso de la mochila
			if actor != null:
				_look_at(s, actor.global_position + Vector3(0, 1.45, 0))
		"p5_rec":
			await s._sit_c14()
			_quiet(s)
			_bad_contact()
			await _wait(s, 0.1)
			hub.qa.call_now()
			await _wait(s, 3.0)  # el DM de Haime (escribiendo…) y el punto REC con la cuenta atrás
			s._player().head.rotation.x = -0.12
		"p5_feedback":
			await _haime_session(s, 1)
			await _until(s, func() -> bool: return hub.qa.heard_opportunities >= mini(2, hub.qa.session_opportunities), 40.0)
			await _wait(s, 1.5)
		"p5_feedback_3":
			await _haime_session(s, 3)
			await _until(s, func() -> bool: return hub.qa.session_log.any(func(k: Variant) -> bool: return str(k).begins_with("q4_caso")), 40.0)
			await _wait(s, 2.5)
		"p5_quiz":
			await s._sit_c14()
			_quiet(s)
			if not hub.training.enabled():
				printerr("[shot] el training no está en este turno (usa --turno 2)")
			hub.training.call_now()
			await _wait(s, 0.5)
			Metrics.set_aux(Metrics.Aux.TRAINING)
			await _floor(s, 1)
			await _sit(s, "training_sala2_3")
			await _until(s, func() -> bool: return hub.training.state == TrainingControl.State.SESION, 3.0)
			hub.training.session_at -= 21.9 * 60.0
			await _until(s, func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0)
			await _wait(s, 1.2)
			if hub.training.quiz != null:
				hub.training.quiz.answer(0)  # una respondida (verde/rojo) y la siguiente en pantalla
			await _wait(s, 1.6)
		"p5_evento", "p5_evento_charadas", "p5_evento_sillas":
			var kind: String = {"p5_evento": "karaoke", "p5_evento_charadas": "charadas", "p5_evento_sillas": "sillas"}[name]
			await _event(s, kind)
			await _face_rasec(s)
			await _wait(s, 7.0 if kind != "sillas" else 9.0)
			await _face_rasec(s)
		"p5_topico":
			await s._sit_c14()
			_quiet(s)
			Fatigue.set_value(62.0)
			EzlakHub.get_hub(s.get_tree()).quick_reply("dm:shero", "me_siento_mal")
			await _wait(s, 0.4)
			Metrics.set_aux(Metrics.Aux.BANO)
			await _floor(s, 1)
			var m := s._building().floor_node.find_child("topico", true, false) as Node3D
			if m != null:
				s._player().teleport(m.global_position + Vector3(0, 0, -0.6), 180.0)
			await _until(s, func() -> bool: return hub.topico.state == TopicoControl.State.ATENCION, 3.0)
			await _wait(s, 3.0)
			var e := s.get_tree().get_first_node_in_group("p5_enfermero")
			var ea := e.get("actor") as Node3D if e != null else null
			if ea != null:
				_look_at(s, ea.global_position + Vector3(0, 1.5, 0))
		"p5_rta_allocations":
			await _rta_two_tags(s)
			var ws := s.get_tree().get_first_node_in_group("workstation")
			ws.call("set_zoom", true)
			var ez: PcEzlak = ws.get("ezlak")
			var desk: PcDesktop = ws.get("desktop")
			if desk != null:
				desk.open_app("ezlak")
			ez.open_channel("#allocations")
			await _wait(s, 3.5)  # "escribiendo…"
		"p5_rta_caza":
			await _rta_two_tags(s)
			hub.rta.since_tag2 = 59.8
			await _until(s, func() -> bool: return P5Pursuit.is_hunting("rta"), 4.0)
			s._player().stand_up()
			s._player().teleport(Vector3(20.5, 0, 0.8), -55.0)
			# Hasta que el perro corre hacia ti, antes de que te alcance.
			for _i in 200:
				await _wait(s, 0.05)
				var rta := _hunter_actor(s)
				if rta != null:
					_look_at(s, rta.global_position + Vector3(0, 0.4, 0))
					if rta.global_position.distance_to(s._player().global_position) < 10.0:
						break  # screenshot.gd espera 0,8 s antes de capturar: llega a ~4 m
		"p5_video":
			await _video(s, arg if arg != "" else "feedback")


func _hunter_actor(s: Node) -> Node3D:
	for k in P5Pursuit.HUNTERS.keys():
		var a := P5Pursuit.node_of(str(k))
		if a != null:
			return a
	return null


## Videos para --write-movie: inicio/fin en fotogramas dibujados.
func _video(s: Node, which: String) -> void:
	var hub := _hub(s)
	match which:
		"guardia":
			await _floor(s, -1, "calle")
			var g := s.get_tree().get_first_node_in_group("p5_guardia")
			if g == null:
				return
			var turn := s._building().floor_node.find_child("Molinete0", true, false) as Node3D
			if turn != null:
				s._player().teleport(turn.global_position + Vector3(0, 0, 1.6), 0.0)
			var actor := g.get("actor") as Node3D
			if actor != null:
				_look_at(s, actor.global_position + Vector3(0, 1.45, 0))
			await _wait(s, 0.8)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			g.call("start_check")
			await _until(s, func() -> bool: return bool(GameState.flags.get("revision_ok", false)), 30.0)
			await _wait(s, 1.5)
			print("[video] fin %d" % Engine.get_frames_drawn())
		"feedback":
			# 3.er feedback del turno: llamada → sala de calibración → guion → REC (calibracion_final).
			await s._sit_c14()
			_quiet(s)
			PersonajesP5.set_counter("p5_qa_feedbacks", 2)
			PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
			_bad_contact()
			await _wait(s, 0.5)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			hub.qa.call_now()
			await _wait(s, 3.0)
			Metrics.set_aux(Metrics.Aux.COACHING)
			await _sit(s, "calibracion")
			await _until(s, func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)
			Engine.time_scale = 1.6  # el guion entero en ~40 s de video
			await _until(s, func() -> bool: return Checkpoints.dying, 90.0)
			Engine.time_scale = 1.0
			await _until(s, func() -> bool: return Checkpoints.death_visible, 12.0)
			await _wait(s, 1.0)
			print("[video] fin %d" % Engine.get_frames_drawn())
		"evento":
			# Juego de la silla de Rasec (T3), jugado bien: música, para, te sientas en la silla con tu nombre.
			await s._sit_c14()
			_quiet(s)
			GameState.flags["p5_tema"] = "halloween"
			hub.rasec.forced_play = "ok"
			await _wait(s, 0.5)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			hub.rasec.call_event("sillas")
			await _wait(s, 2.5)
			Metrics.set_aux(Metrics.Aux.BO)
			s._player().stand_up()
			var m := s._building().floor_node.find_child("evento_rasec", true, false) as Node3D
			if m != null:
				s._player().teleport(m.global_position + Vector3(0.6, 0, 2.9), 0.0)  # dentro del radio (3,2 m)
			await _until(s, func() -> bool: return hub.rasec.state == RasecControl.State.EVENTO, 4.0)
			var r := s.get_tree().get_first_node_in_group("p5_rasec_actor")
			for _i in 900:
				await _wait(s, 0.1)
				# Entre el círculo de sillas y la cara de Rasec.
				var ra := r.get("actor") as Node3D if r != null else null
				if m != null and ra != null:
					_look_at(s, (m.global_position + Vector3(0, 0.5, 0)).lerp(ra.global_position + Vector3(0, 1.5, 0), 0.45))
				if hub.rasec.state != RasecControl.State.EVENTO:
					break
			await _wait(s, 1.5)
			print("[video] fin %d" % Engine.get_frames_drawn())
		"rta":
			# Dos tags en #allocations, caza por la sala y el screamer del perro (aux_incorrecto).
			await _rta_two_tags(s)
			var ws := s.get_tree().get_first_node_in_group("workstation")
			ws.call("set_zoom", true)
			var desk: PcDesktop = ws.get("desktop")
			if desk != null:
				desk.open_app("ezlak")
			(ws.get("ezlak") as PcEzlak).open_channel("#allocations")
			await _wait(s, 3.0)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			await _wait(s, 2.5)
			hub.rta.since_tag2 = 59.8
			await _until(s, func() -> bool: return P5Pursuit.is_hunting("rta"), 4.0)
			await _wait(s, 2.0)
			ws.call("set_zoom", false)
			s._player().stand_up()
			s._player().teleport(Vector3(20.5, 0, 0.8), -55.0)
			for _i in 300:
				await _wait(s, 0.1)
				var a := _hunter_actor(s)
				if a != null:
					_look_at(s, a.global_position + Vector3(0, 0.5, 0))
				if Checkpoints.dying:
					break
			await _until(s, func() -> bool: return Checkpoints.death_visible, 12.0)
			await _wait(s, 1.0)
			print("[video] fin %d" % Engine.get_frames_drawn())


func after(name: String, s: Node) -> void:
	Engine.time_scale = 1.0
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("set_zoom", false)
	# Nada pendiente para la vista siguiente (Haime no vuelve a llamar, sin strikes ni advertencias).
	for k in ["p5_qa_pend", "p5_qa_feedbacks", "p5_rta_strikes", "p5_rasec_adv", "p5_topico_pedidos"]:
		PersonajesP5.set_counter(k, [] if k == "p5_qa_pend" else 0)
	var hub := _hub(s)
	if hub != null:
		hub.rasec.forced_play = ""
		hub.training.forced_answers = []
	if Checkpoints.dying:
		await _until(s, func() -> bool: return Checkpoints.death_visible, 12.0)
		Checkpoints.respawn()
	else:
		EventBus.respawned.emit("shot")  # los cerebros de P5 vuelven a LIBRE (UI fuera, reloj normal)
	var pu := P5Pursuit.get_node_in(s.get_tree())
	if pu != null:
		pu.stop_all("shot")
	GameState.set_clock_override("")
	var p: Player = s._player()
	if p != null:
		p.input_locked = false
	GameState.stop_calm()
	if name == "p5_guardia":
		GameState.flags["revision_ok"] = true

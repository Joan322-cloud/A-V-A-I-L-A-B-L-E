## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas del paquete Q1 de la v0.3.1: encuadre de la PC acercada (F10; correr con --resolution 1280x720,
## 1920x1080 y 2560x1440), la barra F1-F5 en Identa/Campus (B5), el desenfoque por Fatiga con su aviso (B7) y el
## flujo de la calibración (F4/F6/F9): llamado, sentado (sin PC), sesión, advertencia, pausa encima y de pie.
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" godot --path game --rendering-driver opengl3 --resolution 1920x1080 \
##        -- --shot q1_pc_zoom+q1_pc_zoom_tab+q1_identa+q1_campus+q1_blur+q1_calib_llamado+q1_calib_sesion+…


func shots() -> Array[String]:
	return ["q1_pc_zoom", "q1_pc_zoom_tab", "q1_identa", "q1_campus", "q1_blur", "q1_calib_llamado", "q1_calib_sentado",
		"q1_calib_sesion", "q1_calib_advertencia", "q1_calib_pausa", "q1_calib_de_pie", "q1_salto",
		"q1_video_zoom", "q1_video_tercer_break"]


func _ws(s: Node) -> Node:
	return s.get_tree().get_first_node_in_group("workstation")


func _hub(s: Node) -> PersonajesP5:
	return PersonajesP5.get_hub(s.get_tree())


func _wait(s: Node, sec: float) -> void:
	await s.get_tree().create_timer(sec).timeout


func _bad_contact(canal: String) -> void:
	PersonajesP5.set_counter("p5_qa_pend", [])  # las vistas corren en el mismo proceso: sin el contacto de la anterior
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t1c1":
			c = (x as Dictionary).duplicate(true)
	c["_qa"] = ["prometer_sin_verificar", "respuesta_vaga"]
	c["_choices"] = ["inicio.c", "repite_fuerte.a"]
	if canal != "":
		# Un caso real de ese canal (correo/KYC), como el de Joan: Haime habla del caso, no de una llamada.
		for x in (load("res://scripts/dev/escenarios/p4_casos.gd") as GDScript).call("all_cases"):
			if str((x as Dictionary).get("canal", "")) == canal:
				c = (x as Dictionary).duplicate(true)
				c["_qa"] = ["sin_enviar"] if canal == "correo" else ["kyc_aprobado_mal"]
				EventBus.contact_outcome.emit(c, "bo_miss", 1)
				return
	EventBus.contact_outcome.emit(c, "neutral", 1)


func _session(s: Node, n_before: int, canal: String = "") -> void:
	await s._sit_c14()
	GameState.stop_calm()
	var hub := _hub(s)
	PersonajesP5.set_counter("p5_qa_feedbacks", n_before)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	_bad_contact(canal)
	hub.qa.call_now()
	await _wait(s, 0.3)
	Metrics.set_aux(Metrics.Aux.COACHING)
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	p.sit_at(seat, "calibracion")
	p.head.rotation.x = -0.05


func shoot(name: String, _arg: String, s: Node) -> void:
	var ws := _ws(s)
	match name:
		"q1_pc_zoom", "q1_pc_zoom_tab":
			await s._sit_c14()
			ws.set("_layout", 1 if name == "q1_pc_zoom_tab" else 0)
			ws.call("set_zoom", true)
			(ws.get("desktop") as PcDesktop).open_app("kardex")
			await _wait(s, 0.5)
		"q1_identa", "q1_campus":
			await s._sit_c14()
			ws.set("_layout", 0)
			ws.call("set_zoom", true)
			(ws.get("desktop") as PcDesktop).open_app("identa" if name == "q1_identa" else "campus")
			await _wait(s, 0.5)
		"q1_blur":
			await s._sit_c14()
			GameState.stop_calm()
			Fatigue.set_value(48.0)
			Fatigue.set("_blink_timer", 60.0)
			Fatigue.blur_hint_text = Loc.fmt(TranslationServer.translate("Q1_HINT_RUB_EYES"), {"tecla": "R"})
			Fatigue.blur_hint_left = 7.0
			await _wait(s, 0.4)
		"q1_calib_llamado":
			await s._sit_c14()
			GameState.stop_calm()
			_bad_contact("")
			_hub(s).qa.call_now()
			ws.call("set_zoom", true)
			(ws.get("ezlak") as PcEzlak).open_channel("dm:haime")
			await _wait(s, 3.0)
		"q1_calib_sentado":
			await _session(s, 0)
			await _wait(s, 0.1)
		"q1_calib_sesion":
			await _session(s, 0, "correo")
			await _wait(s, 14.0)
		"q1_calib_advertencia":
			await _session(s, 2)
			await s.get_tree().process_frame
			var hub := _hub(s)
			var w := 0.0
			while not hub.qa.session_log.has("advertencia") and w < 40.0:
				await s.get_tree().process_frame
				w += s.get_tree().root.get_process_delta_time()
			await _wait(s, 1.0)
		"q1_calib_pausa":
			await _session(s, 0)
			await _wait(s, 8.0)
			s._main.get("pause_menu").call("toggle")
			await _wait(s, 0.3)
		"q1_calib_de_pie":
			await _session(s, 0)
			await _wait(s, 9.0)
			s._player().stand_up()
			await _wait(s, 0.6)
		"q1_video_zoom":
			# La PC acercada en uso (F10): sentarse, acercar, Kardex → Correo → Identa → Campus, Tab (una pantalla), salir.
			await s._sit_c14()
			GameState.stop_calm()
			ws.call("set_zoom", false)
			await _wait(s, 1.0)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			await _wait(s, 1.0)
			ws.call("set_zoom", true)
			var desk: PcDesktop = ws.get("desktop")
			for app in ["kardex", "correo", "identa", "campus", "portal"]:
				desk.open_app(app)
				await _wait(s, 1.6)
			ws.call("cycle_layout")
			await _wait(s, 1.8)
			ws.call("cycle_layout")
			await _wait(s, 1.8)
			ws.call("cycle_layout")
			await _wait(s, 1.0)
			ws.call("set_zoom", false)
			await _wait(s, 1.2)
			print("[video] fin %d" % Engine.get_frames_drawn())
		"q1_video_tercer_break":
			# 3.er break (F5): Shero sale corriendo desde su sitio y te alcanza (la presentación entre pisos es de Q2).
			await s._sit_c14()
			GameState.stop_calm()
			Metrics.breaks_used = 2
			var sh := s.get_tree().get_first_node_in_group("shero") as Node3D
			var p: Player = s._player()
			if sh != null:
				p.rotation.y = atan2(-(sh.global_position.x - p.global_position.x), -(sh.global_position.z - p.global_position.z))
			p.head.rotation.x = -0.05
			await _wait(s, 1.0)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			await _wait(s, 0.8)
			Metrics.set_aux(Metrics.Aux.BREAK)
			var w := 0.0
			while not Checkpoints.death_visible and w < 40.0:
				await s.get_tree().process_frame
				w += s.get_tree().root.get_process_delta_time()
				var n := Pursuit.node_of("shero")
				if n != null and not p.cinematic:
					var to := n.global_position - p.global_position
					p.rotation.y = lerp_angle(p.rotation.y, atan2(-to.x, -to.z), 0.08)
			await _wait(s, 1.5)
			print("[video] fin %d" % Engine.get_frames_drawn())
		"q1_salto":
			await s._place(2, Vector3(19.0, 0.05, 2.5), 180.0, 0.0)
			GameState.stop_calm()
			s._player().request_jump()
			await _wait(s, 0.28)


func after(name: String, s: Node) -> void:
	var ws := _ws(s)
	if name.begins_with("q1_pc") or name in ["q1_identa", "q1_campus", "q1_calib_llamado"]:
		ws.set("_layout", 0)
		ws.call("set_zoom", false)
	if name == "q1_calib_pausa":
		s._main.get("pause_menu").call("toggle")
	if name.begins_with("q1_calib"):
		var hub := _hub(s)
		if hub != null and hub.qa.state == QaFeedback.State.SESION:
			hub.qa.call("_cleanup", false, true)
		if hub != null:
			hub.qa.state = QaFeedback.State.LIBRE
			Discipline.hold_slow_clock("haime", false)
		if s._player() != null and s._player().seated:
			s._player().stand_up()
	if name == "q1_blur":
		Fatigue.rub_eyes()
	if name == "q1_video_tercer_break" and Checkpoints.dying:
		Checkpoints.respawn()

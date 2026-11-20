## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.2 · Haime: capturas y videos de las calibraciones.
##   h2_video:<n>   graba la calibración n del turno (1, 2, 3 = la advertencia; 4 = la fatal) desde que te sientas hasta
##                  que termina (marcas [video] inicio/fin para tools/…/movie.sh). Responde algunas preguntas como un
##                  jugador (bien, tarde, mal) para que se vean las reacciones.
##   h2_foto:<n>:<beat>  una captura de la sesión n cuando empieza el beat (marca, pregunta, silencio, auricular…).
##   h2_tira:<n>[:paso[:giro]]  la sesión n entera en una sola corrida: un JPG a media resolución cada `paso` s (0,5) en
##                  user://shots/tira/ con el segundo de la sesión y el beat en el nombre (para armar la hoja de cuadros y
##                  dirigir la escena sin grabar video), siguiendo hasta el final de la muerte si mata. `giro` (grados):
##                  el jugador gira la cabeza ese ángulo en los beats «detras» y «auricular» (¿se ve algo raro?).


func shots() -> Array[String]:
	return ["h2_video:", "h2_foto:", "h2_tira:", "h2_pose:", "h2_luzlab:"]


func _hub(s: Node) -> PersonajesP5:
	return PersonajesP5.get_hub(s.get_tree())


func _wait(s: Node, sec: float) -> void:
	await s.get_tree().create_timer(sec).timeout


## Memoria de la partida para las tomas de la advertencia y la fatal: dos calibraciones anteriores (una con respuestas
## tarde, otra de la que te fuiste a mitad) con el mismo error de hoy, y una mentira por Ezlaki. Sin esto la toma no
## tendría nada que recordar (cada toma empieza con la carpeta de datos vacía).
func _seed_memory(n: int, lie: bool = true) -> void:
	var h: Array = [
		{"n": 1, "hora": "00:47", "tipo": "llamada", "marcas": ["prometer_sin_verificar", "respuesta_vaga"], "puntaje": 66, "mal": 1, "bien": 1, "fin": "dada"},
		{"n": 2, "hora": "02:15", "tipo": "chat", "marcas": ["respuesta_plantilla", "info_incorrecta"], "puntaje": 51, "mal": 2, "bien": 0, "fin": "a_mitad"},
	]
	if n >= 4:
		h.append({"n": 3, "hora": "03:58", "tipo": "llamada", "marcas": ["dato_personal"], "puntaje": 36, "mal": 1, "bien": 0, "fin": "dada"})
	var mem := {"lineas": [], "firmas": [], "sesiones": h.size(), "historial": h, "muertes": 0, "mentiras": 1 if lie else 0}
	var p := SaveSlots.dir_of(GameState.agent) + "haime_memoria.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(mem))


func _sit_session(s: Node, n: int, marks: Array, memory: bool = true, wait_call: bool = true) -> PersonajesP5:
	await s._sit_c14()
	GameState.stop_calm()
	# El eco de la polaroid (lo que tu agente piensa la primera vez que se sienta en C-14) ya pasó hace horas en una
	# partida de verdad: en la toma (partida nueva) quedaba en cola detrás de los parlantes y salía al sentarte con Haime.
	RecuerdosSemana.mark("eco_foto")
	for q in [VoiceDirector.current] + VoiceDirector.queue.duplicate():
		if q != null and str(q.speaker) == "piensa":
			VoiceDirector.cancel(q, "toma")
	VoiceDirector.subtitle_shown.emit("", "", 0.0)
	if memory and n >= 3:
		_seed_memory(n)
	var hub := _hub(s)
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	for sh in s.get_tree().get_nodes_in_group("shero"):
		(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
	PersonajesP5.set_counter("p5_qa_pend", [])
	PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t1c1":
			c = (x as Dictionary).duplicate(true)
	c["_qa"] = marks
	c["_choices"] = ["inicio.c", "repite_fuerte.a"]
	EventBus.contact_outcome.emit(c, "neutral", 1)
	hub.qa.call_now()
	# Como en el juego: entre el llamado y sentarte pasa el rato de caminar hasta la sala (el aviso de Ezlaki y la
	# pista de primera vez ya no están en pantalla; Haime ya volvió de asomarse a la puerta).
	await _wait(s, 8.5 if wait_call else 0.3)
	Metrics.set_aux(Metrics.Aux.COACHING)
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	await _wait(s, 0.2)
	p.sit_at(seat, "calibracion")
	p.head.rotation.x = -0.06
	var w := 0.0
	while hub.qa.state != QaFeedback.State.SESION and w < 5.0:
		await s.get_tree().process_frame
		w += s.get_tree().root.get_process_delta_time()
	return hub


## Laboratorio de poses: Haime con cada clip / distancia / inclinación, visto desde tu silla y de costado (JPG en
## user://shots/pose/). `h2_pose:` corre la lista POSES; `h2_pose:<clip>:<avance>:<inclinación>` una sola.
const POSES: Array = [
	["sit", "sit", 0.12, -0.06], ["pen_tap", "pen_tap", 0.12, -0.06], ["haime_lean", "haime_lean", 0.12, 0.0], ["haime_lean_34", "haime_lean", 0.34, -0.1],
	["sit_talk", "sit_talk", 0.12, -0.06], ["hunch_30", "hunch", 0.3, -0.22], ["hunch_30_lean", "hunch", 0.3, -0.42], ["hunch_face", "hunch", 0.42, -0.5],
	["lean_in_05", "lean_in", 0.05, 0.0], ["lean_in_20", "lean_in", 0.2, 0.0], ["lean_in_30_p15", "lean_in", 0.3, -0.15], ["lean_in_42_p30", "lean_in", 0.42, -0.3],
	["idle_05", "idle", 0.05, 0.0], ["idle_arms_05", "idle_arms", 0.05, 0.0], ["talk_05", "talk", 0.05, 0.0], ["stare_05", "stare_camera", 0.05, 0.0],
	["slam_045", "slam_table", 0.05, 0.0, 0.45], ["slam_15", "slam_table", 0.05, 0.0, 1.5],
]


func _pose_lab(s: Node, only: Array) -> void:
	await s._sit_c14()
	GameState.stop_calm()
	var hub := _hub(s)
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	hub.qa.process_mode = Node.PROCESS_MODE_DISABLED
	for sh in s.get_tree().get_nodes_in_group("shero"):
		(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	await _wait(s, 0.2)
	p.sit_at(seat, "calibracion")
	p.head.rotation.x = -0.06
	var hud := s.get_tree().root.find_child("HUD", true, false) as CanvasItem
	var node := s.get_tree().get_first_node_in_group("p5_haime_actor")
	var actor: P5Actor = node.get("actor")
	var seat_pos: Vector3 = node.get("_seat_pos")
	var cam := p.camera
	var to := cam.global_position - seat_pos
	to.y = 0.0
	to = to.normalized()
	print("[pose] silla de Haime %s · tu cámara %s · clips: %s" % [str(seat_pos), str(cam.global_position), str(actor.animator.get("_lib").get_animation_list()) if actor.animator != null else "sin animador"])
	# Qué luces alcanzan la sala (x 8,6..12,4 · z 1,5..4,2): las de adentro y las de afuera cuyo radio llega.
	var box := AABB(Vector3(8.6, 0.0, 1.5), Vector3(3.8, 2.8, 2.7))
	for n in fl.get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		var lp := l.global_position
		var near := Vector3(clampf(lp.x, box.position.x, box.end.x), clampf(lp.y, box.position.y, box.end.y), clampf(lp.z, box.position.z, box.end.z))
		var d := lp.distance_to(near)
		var r := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 9999.0)
		if d < r:
			print("[luz] %s/%s %s pos %s energía %.2f radio %.1f dist %.2f color %s visible %s sombras %s" % [l.get_parent().name, l.name, l.get_class(), str(lp), l.light_energy, r, d, str(l.light_color), str(l.is_visible_in_tree()), str(l.shadow_enabled)])
	var we := fl.get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if not we.is_empty():
		var e := (we[0] as WorldEnvironment).environment
		print("[luz] ambiente %s × %.2f · fondo %s · ajuste %s brillo %.2f" % [str(e.ambient_light_color), e.ambient_light_energy, str(e.background_color), str(e.adjustment_enabled), e.adjustment_brightness])
	var side := Camera3D.new()
	side.fov = 60.0
	fl.add_child(side)
	side.global_position = seat_pos + to * 0.9 + Vector3(0, 1.25, -1.25)
	side.look_at(seat_pos + to * 0.55 + Vector3(0, 1.0, 0), Vector3.UP)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/pose"))
	node.call("look_at_player", true)
	var list: Array = POSES if only.is_empty() else [only]
	var i := 0
	for cfg in list:
		var label := str(cfg[0])
		actor.global_position = seat_pos + to * float(cfg[2])
		actor.rotation = Vector3(float(cfg[3]), float(node.get("_seat_rot")), 0.0)
		actor.face_now(cam.global_position)
		actor.rotation.x = float(cfg[3])
		actor.play(str(cfg[1]), true, 1.0, ["idle"])
		await _wait(s, float(cfg[4]) if cfg.size() > 4 else 1.6)
		for view in ["yo", "lado"]:
			if view == "lado":
				side.make_current()
			else:
				cam.make_current()
			if hud != null:
				hud.visible = view == "yo"
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = s.get_viewport().get_texture().get_image()
			img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
			img.save_jpg("user://shots/pose/%02d_%s_%s.jpg" % [i, label, view], 0.85)
		cam.make_current()
		print("[pose] %s: anim %s (estado %s/%s) pos %s" % [label, actor.current_anim, str(actor.animator.state) if actor.animator != null else "", str(actor.animator.sub) if actor.animator != null else "", str(actor.global_position)])
		i += 1
	side.queue_free()


## Laboratorio de luz: la sala en cada estado de luz de las cuatro calibraciones (sin sesión: se llaman las mismas
## funciones del actor), con la pantalla de la calibración y sin ella. JPG en user://shots/luz/.
##   [etiqueta, nivel, dim, afuera, luces muertas, solo_rec, pose]   pose: sit | over | brace | up
const LUCES: Array = [
	["n1_inicio", 1, 0.0, 1.0, 0, false, "sit", 1.0], ["n2_dos_errores", 2, 0.34, 1.0, 0, false, "over", 1.0],
	["n3_inicio", 3, 0.6, 0.15, 0, false, "sit", 1.0], ["n3_tres_errores", 3, 0.78, 0.02, 0, false, "over", 1.0],
	["n3_sin_tubo", 3, 0.78, 0.02, 1, false, "over", 1.0],
	["n4_inicio", 4, 0.84, 0.26, [], false, "sit", 0.47], ["n4_luz1", 4, 0.84, 0.26, ["afuera"], false, "sit", 0.47], ["n4_luz2", 4, 0.84, 0.26, ["afuera", "relleno"], false, "up", 0.47],
	["n4_solo_rec", 4, 0.85, 0.0, 9, true, "brace", 0.47],
	# La fatal en Modo liviano (`h2_luzlab:liviano`): la escalera la lleva el tubo (0,66 → 0,75 → 0,84).
	["n4L_inicio", 4, 0.66, 0.26, [], false, "sit", 0.47], ["n4L_luz1", 4, 0.75, 0.26, ["afuera"], false, "sit", 0.47], ["n4L_luz2", 4, 0.84, 0.26, ["afuera", "relleno"], false, "up", 0.47],
]


func _light_lab(s: Node, mode: String = "") -> void:
	await s._sit_c14()
	GameState.stop_calm()
	if mode == "liviano":
		# Modo liviano: 3 luces a la vez y el ambiente ×1,7 (GfxQuality.LightBudget). ¿Sigue leyéndose la escalera de luz?
		GfxQuality.apply(s.get_tree(), "liviano")
		await _wait(s, 1.0)
	var hub := _hub(s)
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	hub.qa.process_mode = Node.PROCESS_MODE_DISABLED
	for sh in s.get_tree().get_nodes_in_group("shero"):
		(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	await _wait(s, 0.2)
	p.sit_at(seat, "calibracion")
	p.head.rotation.x = -0.06
	var hud := s.get_tree().root.find_child("HUD", true, false) as CanvasItem
	var node := s.get_tree().get_first_node_in_group("p5_haime_actor")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/luz"))
	var i := 0
	for cfg in LUCES:
		var nivel := int(cfg[1])
		node.call("session_mode", true, nivel)
		node.call("room_session", true, nivel)
		node.call("lock_door")
		node.call("look_at_player", true)
		node.call("set_severity", [0, 1, 2, 2, 3][nivel] if not bool(cfg[5]) else 3)
		node.call("set_dim", float(cfg[2]))
		node.call("set_outside", float(cfg[3]))
		node.call("set_fill", float(cfg[7]), nivel == 4)
		if bool(cfg[5]):
			node.call("only_rec")
		elif cfg[4] is Array:
			for w in cfg[4]:
				node.call("fail_light", str(w))
		else:
			for k in int(cfg[4]):
				node.call("fail_light")
		match str(cfg[6]):
			"over":
				node.call("slam") if nivel == 2 else node.call("rise")
				node.call("upright", false)
				node.call("lean", 0.7)
			"up":
				node.call("rise")
			"brace":
				node.call("brace", true)
		await _wait(s, 2.6)
		for with_ui in [false, true]:
			var ui: FeedbackUI = null
			if with_ui:
				ui = FeedbackUI.new()
				s.add_child(ui)
				ui.open(nivel, {"id": "t1c1", "hora": "02:41", "transcripcion": [{"quien": "cliente", "texto": "Aló. Quiero saber el estado de mi envío.", "qa": ""}, {"quien": "yo", "texto": "Sí, ya está aprobado, no se preocupe.", "qa": "prometer_sin_verificar"}]}, 100, 1 if nivel >= 3 else 0, nivel)
				ui.mark_error(1, 1, "Lo prometiste sin mirar la pantalla.", "", 66 if nivel < 4 else 0, float(cfg[2]) if nivel < 3 else float(cfg[2]) * 0.2)
				ui.show_line("Mírame. Esta es tu última calibración con número.")
				if nivel == 4:
					ui.prewritten()
				await _wait(s, 0.9)
			if hud != null:
				hud.visible = with_ui
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = s.get_viewport().get_texture().get_image()
			img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
			img.save_jpg("user://shots/luz/%02d_%s_%s.jpg" % [i, str(cfg[0]), "ui" if with_ui else "3d"], 0.85)
			if ui != null:
				ui.queue_free()
		print("[luz] %s: luz blanca %.2f · REC %.2f · muertas %d" % [str(cfg[0]), float(node.call("room_light")), float(node.call("rec_light")), int(node.get("lights_dead"))])
		node.call("room_session", false, 0)
		node.call("session_mode", false, 0)
		await _wait(s, 0.3)
		i += 1
	if hud != null:
		hud.visible = true


func shoot(name: String, arg: String, s: Node) -> void:
	var parts := arg.split(":")
	if name == "h2_luzlab":
		await _light_lab(s, arg)
		return
	if name == "h2_pose":
		var only: Array = []
		if parts.size() >= 3 and parts[0] != "":
			only = [parts[0], parts[0], float(parts[1]), float(parts[2])]
		await _pose_lab(s, only)
		return
	var n := clampi(int(parts[0]) if parts.size() > 0 and parts[0].is_valid_int() else 1, 1, 4)
	match name:
		"h2_video":
			var marks: Array = [["prometer_sin_verificar", "respuesta_vaga"], ["dato_personal", "culpar_cliente", "molesto"], ["prometer_reembolso", "calmese", "respuesta_vaga"], ["dato_personal"]][n - 1]
			var answers: Array = [["ok", "tarde", "ok"], ["tarde", "mal", "ok"], ["mal", "tarde", "mal"], ["ok", "tarde"]][n - 1]
			print("[video] inicio %d" % Engine.get_frames_drawn())
			var hub := await _sit_session(s, n, marks)
			hub.qa.test_answers = answers.duplicate()
			var w := 0.0
			while (hub.qa.state != QaFeedback.State.LIBRE or w < 2.0) and not Checkpoints.dying and w < 150.0:
				await s.get_tree().process_frame
				w += s.get_tree().root.get_process_delta_time()
			await _wait(s, 1.6 if not Checkpoints.dying else 9.5)  # la fatal: hasta la pantalla de «Usuario desconectado»
			var pc: Dictionary = hub.qa.pacing()
			print("[h2] sesión %d: %s · %.1f s (guion %.1f-%.1f) · silencio %d %% · hueco máx %.2f s · línea más larga %.1f s · solapes de voz %d · respuestas %s" % [n, str(hub.qa.session.get("firma", "")), hub.qa.clock, float(hub.qa.session.get("min_s", 0.0)), float(hub.qa.session.get("max_s", 0.0)), int(float(pc["silencio_pct"])), float(pc["hueco"]), float(pc["linea_max"]), VoiceDirector.overlaps, str(hub.qa.answers)])
			print("[video] fin %d" % Engine.get_frames_drawn())
		"h2_foto":
			var beat := parts[1] if parts.size() > 1 else "marca"
			var hub := await _sit_session(s, n, ["prometer_sin_verificar", "respuesta_vaga"])
			hub.qa.test_answers = ["tarde", "tarde", "tarde"]
			var w := 0.0
			while hub.qa.beat_now != beat and hub.qa.state == QaFeedback.State.SESION and w < 120.0:
				await s.get_tree().process_frame
				w += s.get_tree().root.get_process_delta_time()
			await _wait(s, float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 0.9)
		"h2_tira":
			var step := float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else 0.5
			var turn := float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 0.0
			var marks: Array = [["prometer_sin_verificar", "respuesta_vaga"], ["dato_personal", "culpar_cliente", "molesto"], ["prometer_sin_verificar", "calmese", "respuesta_vaga"], ["prometer_sin_verificar", "dato_personal"]][n - 1]
			var answers: Array = [["ok", "tarde", "ok"], ["tarde", "mal", "ok"], ["mal", "tarde", "mal"], ["ok", "tarde"]][n - 1]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/tira"))
			var hub := await _sit_session(s, n, marks)
			hub.qa.test_answers = answers.duplicate()
			var p: Player = s._player()
			var yaw0 := p.head.rotation.y
			var next := 0.0
			var i := 0
			var after := 0.0
			var t_death := -1.0
			var wall := 0.0
			while wall < 200.0:
				await RenderingServer.frame_post_draw
				var dt: float = s.get_tree().root.get_process_delta_time()
				wall += dt
				var in_session: bool = hub.qa.state == QaFeedback.State.SESION
				var tsec: float = hub.qa.clock if in_session else hub.qa.clock + after
				if not in_session:
					after += dt
					if Checkpoints.dying and t_death < 0.0:
						t_death = after
					if after > (9.0 if Checkpoints.dying or t_death >= 0.0 else 2.5):
						break
				if turn != 0.0:
					var want := deg_to_rad(turn) if hub.qa.beat_now in ["detras", "auricular"] else 0.0
					p.head.rotation.y = move_toward(p.head.rotation.y, yaw0 + want, dt * 3.0)
				# Durante la muerte, más seguido: es lo que hay que juzgar cuadro por cuadro.
				var st := step if in_session else minf(step, 0.2)
				if tsec >= next:
					next = tsec + st
					var img: Image = s.get_viewport().get_texture().get_image()
					img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
					var beat: String = hub.qa.beat_now if in_session else ("muerte" if Checkpoints.dying else "fin")
					img.save_jpg("user://shots/tira/%03d_%05.1f_%s.jpg" % [i, tsec, beat if beat != "" else "-"], 0.82)
					i += 1
			var pc: Dictionary = hub.qa.pacing()
			print("[h2] tira %d: %s · %.1f s (guion %.1f-%.1f) · silencio %d %% · hueco máx %.2f s (a los %.1f s) · solapes %d · saltados %s · perdidas %s · respuestas %s · log %s" % [n, str(hub.qa.session.get("firma", "")), hub.qa.clock, float(hub.qa.session.get("min_s", 0.0)), float(hub.qa.session.get("max_s", 0.0)), int(float(pc["silencio_pct"])), float(pc["hueco"]), float(pc["hueco_en"]), VoiceDirector.overlaps, str(hub.qa.skipped), str(hub.qa.lost), str(hub.qa.answers), str(hub.qa.session_log)])
			for e in hub.qa.timeline:
				print("[h2-tl] %.2f %.2f %s %s" % [float(e[0]), float(e[1]), str(e[2]), str(e[3])])

## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P6b: menú con Continuar / Elegir turno, la pantalla de turnos, el cierre de una rama (Seguir desde
## aquí y su confirmación), la selección de módulos de la Inducción, un momento de cada módulo (con el panel y la
## luz guía), el Manual del agente (glosario, reglas y Campus), un tooltip de primera vez, la zona de descanso del
## -1 (brillo), los carteles vistos de los dos lados, una vista cenital del piso 2 (evento de Rasec y su sitio) y
## el sitio C-17. `-- --shot p6b` las captura todas; `--resolution 1280x720` para revisar la UI chica.

const BOT := "res://scripts/dev/bot_tutorial.gd"

## modulo/paso donde se para el bot y si la PC va acercada.
const TUT_VIEWS: Dictionary = {
	"aux": ["aux/sentarse", false], "aux_menu": ["aux/poner_bo", false], "contactos": ["contactos/conversar", true],
	"correo": ["correo/campos", true], "bo_kyc": ["bo_kyc/decidir", true], "vitzo": ["vitzo/portal", true],
	"ezlak": ["ezlak/reaccionar", true], "salir": ["salir/salir", false], "jefes": ["jefes/ack", false],
	"fatiga": ["fatiga/dormir", false], "fatiga_reconectar": ["fatiga/reconectar", false], "partidas": ["partidas/manual", false],
}


func shots() -> Array[String]:
	var out: Array[String] = ["p6b_menu_elegir", "p6b_turnos", "p6b_rama_fin", "p6b_rama_confirmar", "p6b_tut_menu"]
	for k in TUT_VIEWS.keys():
		out.append("p6b_tut_" + k)
	out += ["p6b_tut_fin", "p6b_manual", "p6b_manual_reglas", "p6b_campus_manual", "p6b_tooltip", "p6b_pausa",
		"p6b_lounge_m1", "p6b_lounge_m1_puffs", "p6b_cafeteria_m1", "p6b_lobby_m1", "p6b_planta2", "p6b_rasec_evento",
		"p6b_rasec_sitio", "p6b_c17", "p6b_c17_cerca", "p6b_fonex_qa", "p6b_cartel:"]
	return out


func _seed_saves() -> void:
	# Marko con T1 y T2 cerrados (T3 actual) para el menú y la pantalla de turnos.
	SaveSlots.use_main()
	SaveSlots.select("Marko")
	var p := SaveSlots.progress("Marko")
	p["turno_desbloqueado"] = 3
	p["turnos_cerrados"] = [1, 2]
	p["saldo"] = 54.5
	var turns := {}
	for n in [1, 2, 3]:
		var snap := SaveSlots.make_snapshot("Marko", n)
		snap["turno_desbloqueado"] = n
		snap["saldo"] = -1.0 if n == 1 else (31.0 if n == 2 else 54.5)
		snap["alcanzado"] = "2026-11-0%dT0%d:1%d:00" % [6 + n, n + 2, n]
		if n < 3:
			snap["resultado"] = {"available": 96.0 - n * 5, "ww": n - 1, "contactos": 12 + n, "incidencias": n - 1, "csat": 4.4 - n * 0.3, "despedido": false, "cerrado": "2026-11-0%dT09:0%d:00" % [6 + n, n]}
		turns[str(n)] = snap
	p["turnos"] = turns
	SaveSlots.save("Marko")


func _menu(s: Node, agent: String) -> Control:
	s._main.call("_back_to_menu")
	await s.get_tree().create_timer(0.2).timeout
	var menu: Control = s._main.get("main_menu")
	menu.set("agent_index", GameState.AGENTS.find(agent))
	SaveSlots.select(agent)
	menu.call("_build")
	await s.get_tree().create_timer(0.2).timeout
	return menu


func _tut(s: Node, mod: String, stop: String, zoom: bool) -> void:
	s._main.call("_back_to_menu")
	await s.get_tree().create_timer(0.2).timeout
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotShot"
	bot.set("stop_at", stop)
	bot.set("log_steps", false)
	s.add_child(bot)
	bot.call("start", s._main, [mod], [])
	var w := 0.0
	while not bool(bot.get("stopped")) and w < 40.0:
		await s.get_tree().create_timer(0.1).timeout
		w += 0.1
	bot.set_process(false)
	await s.get_tree().create_timer(1.2).timeout
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null and GameState.seated_at != "":
		ws.call("set_zoom", zoom)
	_face_target(s)
	bot.queue_free()


## Gira al jugador hacia la luz guía (si la hay y está de pie).
func _face_target(s: Node) -> void:
	var p: Player = s._player()
	var beacon := s.get_tree().root.find_child("LuzGuia", true, false) as Node3D
	if p == null or beacon == null or p.seated or p.lying:
		return
	var d := beacon.global_position - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = -0.12


func shoot(name: String, arg: String, s: Node) -> void:
	if name.begins_with("p6b_tut_") and TUT_VIEWS.has(name.substr(8)):
		var v: Array = TUT_VIEWS[name.substr(8)]
		await _tut(s, str(v[0]).get_slice("/", 0), str(v[0]), bool(v[1]))
		if name == "p6b_tut_partidas":
			s._main.get("pause_menu").call("toggle")
			await s.get_tree().create_timer(0.2).timeout
			s._main.get("pause_menu").call("open_manual")
		return
	match name:
		"p6b_menu_elegir":
			_seed_saves()
			await _menu(s, "Marko")
		"p6b_turnos":
			_seed_saves()
			var menu := await _menu(s, "Marko")
			menu.call("_open_turns")
		"p6b_rama_fin", "p6b_rama_confirmar":
			_seed_saves()
			await _menu(s, "Marko")
			s._main.call("_start_branch", 1, 0)
			await s.get_tree().create_timer(0.5).timeout
			GameState.login()
			GameState.shift_over = true
			GameState.running = false
			EventBus.shift_ended.emit()
			await s.get_tree().create_timer(0.3).timeout
			if name == "p6b_rama_confirmar":
				s._main.get("shift_end").call("keep_branch")
		"p6b_tut_menu":
			Tutorial.save_progress({"aux": "hecho", "contactos": "hecho", "correo": "saltado"})
			var menu2 := await _menu(s, "Jiroshi")
			menu2.call("_open_tutorial_menu")
		"p6b_tut_fin":
			s._main.call("_back_to_menu")
			await s.get_tree().create_timer(0.2).timeout
			var tut: Node = s._main.call("_start_tutorial", ["partidas"])
			await s.get_tree().create_timer(0.5).timeout
			tut.call("skip_module")
			await s.get_tree().create_timer(1.0).timeout
		"p6b_manual", "p6b_manual_reglas", "p6b_pausa":
			await s._sit_c14()
			s._main.get("pause_menu").call("toggle")
			await s.get_tree().create_timer(0.2).timeout
			if name != "p6b_pausa":
				s._main.get("pause_menu").call("open_manual")
				await s.get_tree().create_timer(0.2).timeout
				if name == "p6b_manual_reglas":
					var man: Node = s._main.get("pause_menu").find_child("AgentManual", true, false)
					(man.find_child("Tab_reglas", true, false) as Button).emit_signal("pressed")
		"p6b_campus_manual":
			await s._sit_c14()
			var ws := s.get_tree().get_first_node_in_group("workstation")
			ws.call("set_zoom", true)
			var desk: Node = ws.get("desktop")
			desk.call("open_app", "campus")
			desk.get("campus").set("_selected", "guia_manual")
			desk.get("campus").set("_sig", "")
		"p6b_tooltip":
			await s._sit_c14()
			SaveSlots.progress()["tooltips_vistos"] = []
			EventBus.break_started.emit(1)
		"p6b_fonex_qa":
			await s._sit_c14()
			PersonajesP5.set_counter("p5_qa_feedbacks", 1)
			s.get_tree().get_first_node_in_group("workstation").call("set_zoom", true)
		"p6b_lounge_m1":
			await s._place(-1, Vector3(28.0, 0, 8.6), -75.0, -0.12)
		"p6b_lounge_m1_puffs":
			await s._place(-1, Vector3(34.0, 0, 10.2), 40.0, -0.2)
		"p6b_cafeteria_m1":
			await s._place(-1, Vector3(13.8, 0, 7.5), -70.0)
		"p6b_lobby_m1":
			await s._place(-1, Vector3(0, 0, 12.5), 0.0)
		"p6b_planta2":
			# La sala desde la esquina noroeste, alto: la zona de huddle en el centro y Rasec bajo el reloj al fondo.
			await s._place(2, Vector3(19.3, 0, 1.2), 0.0)
			var fl2: Node3D = s._building().floor_node
			var cam: Camera3D = s._player().camera
			cam.global_position = fl2.global_position + Vector3(19.4, 3.15, 1.3)
			cam.look_at(fl2.global_position + Vector3(32.4, 0.0, -9.5), Vector3.UP)
			cam.fov = 85.0
		"p6b_rasec_evento":
			# El evento de Rasec en la zona de huddle (centro de la sala): nada encima de las sillas.
			var hub := PersonajesP5.get_hub(s.get_tree())
			await s._sit_c14()
			if hub != null and hub.rasec != null:
				GameState.flags["p5_tema"] = "halloween"
				hub.rasec.call_event("karaoke")
			await s.get_tree().create_timer(0.6).timeout
			Metrics.set_aux(Metrics.Aux.BO)
			var m := s._building().floor_node.find_child("evento_rasec", true, false) as Node3D
			if m != null:
				await s._place(2, m.global_position + Vector3(0.0, 0, 1.8), 0.0, -0.12)
			for _i in 40:
				await s.get_tree().create_timer(0.1).timeout
				if hub == null or hub.rasec.state == RasecControl.State.EVENTO:
					break
			await s.get_tree().create_timer(1.0).timeout
		"p6b_rasec_sitio":
			# Rasec en su sitio (bajo el reloj, pasillo sur) visto de pie junto a C-14.
			await s._sit_c14()
			var p: Player = s._player()
			p.stand_up()
			await s.get_tree().create_timer(0.2).timeout
			var r := s.get_tree().get_first_node_in_group("p5_rasec_actor")
			var a: Node3D = r.get("actor") as Node3D if r != null else null
			if a != null:
				var d := a.global_position - p.global_position
				p.rotation.y = atan2(-d.x, -d.z)
				p.head.rotation.x = -0.02
		"p6b_c17", "p6b_c17_cerca":
			Metrics.breaks_used = 1
			if name == "p6b_c17":
				await s._place(2, Vector3(33.6, 0, 0.2), 108.0, -0.1)
			else:
				await s._place(2, Vector3(30.2, 0, -0.3), 180.0, -0.16)
			var fl: Node = s._building().floor_node
			if fl.has_method("debug_show_c17"):
				fl.call("debug_show_c17", name == "p6b_c17_cerca")
		"p6b_cartel":
			await _cartel(s, arg)


## Carteles vistos de frente y por detrás: `p6b_cartel:<id>_<frente|detras>` con id banos (piso 2), banos_m1,
## lockers, isla (fila C), descanso (-1), huddle (piso 2). Busca el Label3D por su texto y se para a 3 m.
const CARTELES := {"banos": [2, "SIGN_BATHROOM"], "banos_m1": [-1, "SIGN_BATHROOM"], "lockers": [2, "SIGN_LOCKER"],
	"isla": [2, "SIGN_ISLAND"], "descanso": [-1, "SIGN_REST"], "huddle": [2, "P6B_HUDDLE"]}


func _cartel(s: Node, which: String) -> void:
	var side := which.get_slice("_", which.get_slice_count("_") - 1)
	var id := which.trim_suffix("_" + side)
	var info: Array = CARTELES.get(id, [2, "SIGN_LOCKER"])
	await s._place(int(info[0]), Vector3(0, 0, 0.5), 0.0)
	var fl: Node3D = s._building().floor_node
	var want := s.tr(str(info[1]))
	var lbl: Label3D = null
	for n in fl.find_children("*", "Label3D", true, false):
		if (n as Label3D).text == want and not n.has_meta("reverso"):
			lbl = n
			break
	if lbl == null:
		printerr("[shot] cartel no encontrado: ", which)
		return
	var dir := lbl.global_transform.basis.z.normalized() * (1.0 if side != "detras" else -1.0)
	dir.y = 0.0
	# A 2,4 m si hay piso; si no (pasillo corto), más cerca.
	var at := lbl.global_position
	var space := fl.get_world_3d().direct_space_state
	for dist in [2.4, 1.8, 1.3, 0.9]:
		at = lbl.global_position + dir.normalized() * float(dist)
		at.y = fl.global_position.y
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.2, 0), at - Vector3(0, 0.3, 0))
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf((hit["position"] as Vector3).y - at.y) < 0.2:
			break
	var d := lbl.global_position - at
	var pitch := atan2(d.y - 1.6, Vector2(d.x, d.z).length())
	await s._place(int(info[0]), at, rad_to_deg(atan2(-d.x, -d.z)), pitch)


## Deja la escena limpia para la vista siguiente: fuera pausa / Manual / zoom / menús; las vistas de menú, rama o
## Inducción vuelven a un turno normal de Jiroshi (como al empezar `--shot`).
func after(name: String, s: Node) -> void:
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("set_zoom", false)
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	var lugar := name.begins_with("p6b_lounge") or name.begins_with("p6b_cafeteria") or name.begins_with("p6b_lobby") \
		or name.begins_with("p6b_c17") or name.begins_with("p6b_cartel")
	if lugar:
		return
	s._main.call("_back_to_menu")
	await s.get_tree().create_timer(0.2).timeout
	SaveSlots.use_main()
	SaveSlots.select("Jiroshi")
	s._main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	await s.get_tree().create_timer(0.6).timeout

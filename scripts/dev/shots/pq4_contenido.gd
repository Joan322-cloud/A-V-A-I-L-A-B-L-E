## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de Q4 (v0.3.1): intro de arranque, menú principal, selección de agente, correo por pasos (barra, guía,
## bloqueo), Kardex con copiar, evento de Rasec con decisión, agentes hartos, casillero, refri, microondas y una
## toma de cada cinemática.
##   `-- --shot pq4`                         todas
##   `-- --shot menu_q4_intro:<s>`           un fotograma de la intro de arranque (segundo s)
##   `-- --shot pq4_cine:<id>,<s>`           un fotograma de una cinemática (intro_t1, t2_capacitacion, …)
##   `-- --shot pq4_video:<menu|correo|rasec|comida|cine>`  recorrido para grabar con --write-movie

const P5 := "res://scripts/dev/shots/p5_personajes.gd"
const P6B := "res://scripts/dev/shots/p6b_tutorial.gd"


func shots() -> Array[String]:
	return ["menu_q4_principal", "menu_q4_agentes", "menu_q4_intro_a", "menu_q4_intro_b", "menu_q4_intro_c",
		"menu_q4_intro:", "pq4_correo_bloqueo", "pq4_correo_pasos", "pq4_kardex", "pq4_rasec_decision",
		"pq4_hartos", "pq4_casillero", "pq4_refri", "pq4_microondas", "pq4_comer", "pq4_cine_t1", "pq4_cine_t2",
		"pq4_cine_t3", "pq4_cine:", "pq4_video:"]


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


func _menu(s: Node) -> Control:
	s._main.call("_back_to_menu")
	await _wait(s, 0.3)
	return s._main.get("main_menu") as Control


func _quiet(s: Node) -> void:
	var cm := s._main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()


func _look(s: Node, target: Vector3, pitch_bias: float = 0.0) -> void:
	var p: Player = s._player()
	var d := target - p.head.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()) + pitch_bias, -1.2, 1.2)


## De pie a `dist` m del objeto (por el lado `side`), mirándolo.
func _face(s: Node, floor_n: int, node_name: String, side: Vector3, dist: float, pitch_bias: float = 0.0) -> Node3D:
	var b: Building = s._building()
	if b.current_floor != floor_n:
		b.go_to_floor(floor_n, "ascensor")
		await _wait(s, 0.4)
	var n := b.floor_node.find_child(node_name, true, false) as Node3D
	if n == null:
		printerr("[shot] no hay ", node_name)
		return null
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	var pos := n.global_position + side.normalized() * dist
	pos.y = b.floor_node.global_position.y
	p.teleport(pos, 0.0)
	await _wait(s, 0.1)
	_look(s, n.global_position, pitch_bias)
	return n


func _cin(s: Node) -> Cinematicas:
	return s._main.get_node_or_null("UI/Cinematicas") as Cinematicas


func _open_mail(s: Node, kardex_done: bool) -> Node:
	await s._sit_c14()
	_quiet(s)
	(SaveSlots.progress().get("tooltips_vistos", []) as Array).erase(PcCorreo.GUIDE_FLAG)
	var cm := s._main.get("contacts") as ContactManager
	var c := {}
	for x in (DataLoader.dict("casos_bo").get("turnos", {}) as Dictionary).get("1", []):
		if str((x as Dictionary).get("id", "")) == "t1_correo_pod":
			c = (x as Dictionary).duplicate(true)
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c)
	cm.accept()
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(s, 0.2)
	var desk := s.get_tree().get_first_node_in_group("pc_desktop")
	if kardex_done:
		desk.call("open_app", "kardex")
		await _wait(s, 0.2)
		cm.kardex_lookup("KP-2211-3312")
		cm.set_recipient("Banco Andino")
		cm.set_template("POD")
	desk.call("open_app", "correo")
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	await _wait(s, 0.5)
	return desk


func shoot(name: String, arg: String, s: Node) -> void:
	match name:
		"menu_q4_principal":
			var m := await _menu(s)
			m.call("go_home")
			await _wait(s, 0.6)
		"menu_q4_agentes":
			var p6b: Object = (load(P6B) as GDScript).new()
			p6b.call("_seed_saves")
			var m2 := await _menu(s)
			m2.set("agent_index", GameState.AGENTS.find("Marko"))
			m2.call("_build")
			m2.call("go_agents")
			await _wait(s, 0.6)
		"menu_q4_intro_a", "menu_q4_intro_b", "menu_q4_intro_c", "menu_q4_intro":
			var at := {"menu_q4_intro_a": 2.2, "menu_q4_intro_b": 5.6, "menu_q4_intro_c": 8.6}.get(name, float(arg) if arg != "" else 4.0) as float
			var m3 := await _menu(s)
			var intro := m3.call("play_intro", true) as IntroArranque
			await _wait(s, 0.2)
			intro.seek(at, true)
			await _wait(s, 0.3)
		"pq4_correo_bloqueo":
			await _open_mail(s, false)
		"pq4_correo_pasos":
			var desk := await _open_mail(s, true)
			var cm := s._main.get("contacts") as ContactManager
			cm.set_active_field("id")
			var corr := desk.get("correo") as PcCorreo
			corr.refresh(0.1)
			await _wait(s, 0.3)
		"pq4_kardex":
			var desk2 := await _open_mail(s, true)
			desk2.call("open_app", "kardex")
			await _wait(s, 0.4)
		"pq4_rasec_decision", "pq4_hartos":
			var p5: Object = (load(P5) as GDScript).new()
			await p5.call("_event", s, "karaoke")
			var hub := PersonajesP5.get_hub(s.get_tree())
			var ui := hub.rasec.get("ui") as Node if hub != null else null
			var w := 0.0
			while w < 30.0 and (ui == null or ui.find_child("Decision1", true, false) == null):
				await _wait(s, 0.2)
				w += 0.2
				ui = hub.rasec.get("ui") as Node
			if name == "pq4_rasec_decision":
				await p5.call("_face_rasec", s)
			else:
				var sl := s._building().floor_node.find_child("AgenteDormido", true, false) as Node3D
				if sl != null:
					_look(s, sl.global_position + Vector3(0, 0.6, 0), -0.05)
			await _wait(s, 0.6)
		"pq4_casillero":
			GameState.flags.erase("locker_done")
			var lk := await _face(s, 2, "MiCasillero", Vector3(1, 0, 0), 1.25, -0.1)
			if lk != null:
				(lk as Interactable).interact(s._player())
				await _wait(s, 0.9)
		"pq4_refri":
			GameState.flags["locker_done"] = true
			WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.MOCHILA)
			var fr := await _face(s, 2, "Refri1", Vector3(0.5, 0, -1), 2.0, -0.12)
			if fr != null:
				(fr as Interactable).interact(s._player())
				await _wait(s, 1.0)
		"pq4_microondas", "pq4_comer":
			GameState.flags["locker_done"] = true
			WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.MANO)
			Metrics.set_aux(Metrics.Aux.LUNCH)
			var mw := await _face(s, -1, "Microondas", Vector3(0, 0, 1), 1.5, -0.25)
			if mw != null:
				(mw as Interactable).hint_text()
				if (mw as WorldObjects.Microwave).state != "libre":
					(mw as WorldObjects.Microwave).set_state("libre")
				(mw as Interactable).interact(s._player())
				await _wait(s, 1.2)
				if name == "pq4_comer":
					GameState.clock_seconds += 70.0
					await _wait(s, 0.4)
					(mw as Interactable).interact(s._player())
					await _wait(s, 0.4)
					var spots: Array = s._building().floor_node.find_children("Comer_*", "", true, false)
					if not spots.is_empty():
						var sp := spots[0] as Node3D
						(sp as Interactable).interact(s._player())
						await _wait(s, 1.0)
		"pq4_cine_t1", "pq4_cine_t2", "pq4_cine_t3", "pq4_cine":
			var id_t := {"pq4_cine_t1": ["intro_t1", 12.0], "pq4_cine_t2": ["t2_capacitacion", 6.0], "pq4_cine_t3": ["t3_allocations", 6.5]}.get(name, [arg.get_slice(",", 0), float(arg.get_slice(",", 1)) if arg.contains(",") else 2.0]) as Array
			var cin := _cin(s)
			if cin == null:
				printerr("[shot] sin Cinematicas")
				return
			_quiet(s)
			cin.play(str(id_t[0]), true)
			await _wait(s, 0.3)
			cin.t = float(id_t[1])
			await _wait(s, 0.5)
		"pq4_video":
			await _video(arg, s)


func after(name: String, s: Node) -> void:
	var cin := _cin(s)
	if cin != null and cin.playing != "":
		cin.stop(true)
	if name.begins_with("pq4_correo") or name == "pq4_kardex":
		var ws := s.get_tree().get_first_node_in_group("workstation")
		if ws != null:
			ws.call("set_zoom", false)
	if name.begins_with("menu_q4_intro"):
		var m: Node = s._main.get("main_menu")
		var intro := m.get("intro") as IntroArranque
		if intro != null and is_instance_valid(intro):
			intro.finish()
	if name.begins_with("pq4_rasec") or name == "pq4_hartos":
		s._main.call("_back_to_menu")
		await _wait(s, 0.2)
		s._main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
		await _wait(s, 0.6)


## Recorridos para grabar (--write-movie). Marcan inicio/fin en el log.
func _video(kind: String, s: Node) -> void:
	print("[video] inicio ", kind, " frame ", Engine.get_frames_drawn())
	match kind:
		"menu":
			Loc.set_setting("intro_vista", false)
			var m := await _menu(s)
			var intro := m.call("play_intro", true) as IntroArranque
			await intro.finished
			await _wait(s, 2.0)
			m.call("go_agents")
			await _wait(s, 1.5)
			for a in ["Marko", "Jiroshi"]:
				m.call("_select_agent", GameState.AGENTS.find(a))
				await _wait(s, 1.6)
			await _wait(s, 1.0)
		"correo":
			var desk := await _open_mail(s, false)
			var cm := s._main.get("contacts") as ContactManager
			await _wait(s, 3.5)
			var corr := desk.get("correo") as PcCorreo
			var g := corr.find_child("GuiaOk", true, false) as Button
			desk.call("open_app", "kardex")
			await _wait(s, 1.0)
			cm.kardex_lookup("KP-2211-3312")
			await _wait(s, 2.0)
			desk.call("open_app", "correo")
			await _wait(s, 1.2)
			cm.set_recipient("Banco Andino")
			corr.refresh(0.1)
			await _wait(s, 1.4)
			cm.set_template("POD")
			corr.refresh(0.1)
			await _wait(s, 1.4)
			var kd := desk.get("kardex") as PcKardex
			for f in ["id", "monto", "fecha"]:
				cm.set_active_field(f)
				desk.call("open_app", "kardex")
				await _wait(s, 1.0)
				var v := str((cm.case.correct().get("campos", {}) as Dictionary).get(f, "")) if cm.case != null else ""
				if kd != null and v != "":
					kd.copy_value(v)
				elif v != "":
					cm.copy_to_active_field(v)
				await _wait(s, 0.6)
				desk.call("open_app", "correo")
				await _wait(s, 1.0)
			# v0.3.2: el partner de este correo no es Vitzo: no hay nada que adjuntar (antes el recorrido adjuntaba un POD).
			corr.refresh(0.1)
			await _wait(s, 1.5)
			if g != null and is_instance_valid(g) and g.visible:
				g.pressed.emit()
			await _wait(s, 1.5)
		"rasec":
			var p5: Object = (load(P5) as GDScript).new()
			await p5.call("_event", s, "karaoke")
			await p5.call("_face_rasec", s)
			var hub := PersonajesP5.get_hub(s.get_tree())
			var t := 0.0
			var turned := false
			while t < 55.0 and hub.rasec.state == RasecControl.State.EVENTO:
				await _wait(s, 0.25)
				t += 0.25
				if not turned and t > 18.0:
					turned = true
					var sl := s._building().floor_node.find_child("AgenteDormido", true, false) as Node3D
					if sl != null:
						_look(s, sl.global_position + Vector3(0, 0.6, 0), -0.05)
						await _wait(s, 3.5)
						await p5.call("_face_rasec", s)
		"comida":
			GameState.flags.erase("locker_done")
			GameState.flags.erase("taper")
			var lk := await _face(s, 2, "MiCasillero", Vector3(1, 0, 0), 1.25, -0.1)
			await _wait(s, 0.8)
			(lk as Interactable).interact(s._player())
			await _wait(s, 3.2)
			var fr := await _face(s, 2, "Refri1", Vector3(0.5, 0, -1), 2.0, -0.12)
			await _wait(s, 0.8)
			(fr as Interactable).interact(s._player())
			await _wait(s, 3.0)
			Metrics.set_aux(Metrics.Aux.LUNCH)
			(fr as Interactable).interact(s._player())
			await _wait(s, 2.5)
			var mw := await _face(s, -1, "Microondas", Vector3(0, 0, 1), 1.5, -0.25)
			(mw as Interactable).hint_text()
			if (mw as WorldObjects.Microwave).state != "libre":
				(mw as WorldObjects.Microwave).set_state("libre")
			await _wait(s, 0.8)
			(mw as Interactable).interact(s._player())
			GameState.set_clock_override("training")
			await _wait(s, 7.0)
			GameState.clear_clock_override("training")
			if (mw as WorldObjects.Microwave).state != "mio_listo":
				GameState.clock_seconds += 60.0
				await _wait(s, 1.2)
			(mw as Interactable).interact(s._player())
			await _wait(s, 2.0)
			var spots: Array = s._building().floor_node.find_children("Comer_*", "", true, false)
			if not spots.is_empty():
				var sp := spots[0] as Node3D
				var p: Player = s._player()
				p.teleport(sp.global_position + Vector3(0, -sp.global_position.y + s._building().floor_node.global_position.y, 1.2), 0.0)
				await _wait(s, 0.1)
				_look(s, sp.global_position, -0.2)
				await _wait(s, 0.8)
				(sp as Interactable).interact(s._player())
				await _wait(s, 4.0)
		"cine":
			var cin := _cin(s)
			_quiet(s)
			cin.play("intro_t1", true)
			await cin.finished
			await _wait(s, 0.5)
	print("[video] fin ", kind, " frame ", Engine.get_frames_drawn())
	await _wait(s, 0.5)

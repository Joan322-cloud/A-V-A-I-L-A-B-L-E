extends RefCounted
## Capturas de P3 (escalera de Shero y persecución). `-- --shot p3` las saca todas; `-- --shot p3_video:<id>`
## es para grabar con --write-movie (ezlak · parlantes · persecucion): marca inicio/fin en el log.

func shots() -> Array[String]:
	return ["p3_ezlak_dm", "p3_ezlak_allocations", "p3_ezlak_team", "p3_parlantes", "p3_detras_silla", "p3_hud",
		"p3_persecucion_m1", "p3_persecucion_escalera", "p3_persecucion_azotea", "p3_bano_espera", "p3_aparicion",
		"p3_video:"]


func shoot(name: String, arg: String, s: Node) -> void:
	GameState.stop_calm()
	Metrics.breaks_used = 0  # cada vista arranca sin breaks usados (si no, el 3.er break del HUD mata)
	match name:
		"p3_ezlak_dm":
			await _ezlak(s, "dm:shero")
		"p3_ezlak_allocations":
			await _ezlak(s, "#allocations")
		"p3_ezlak_team":
			await _ezlak(s, "#team-familia")
		"p3_parlantes":
			await s._place(-1, Vector3(-1.0, 0, 3.0), 90.0)
			Dread.forced = 0.6
			Discipline.debug_start("sala", 0.0)
			Discipline.debug_fire("sala", 2)
			await s.get_tree().create_timer(1.2).timeout
		"p3_detras_silla":
			await s._sit_c14()
			var sh := s.get_tree().get_first_node_in_group("shero") as Shero
			if sh != null:
				sh.walk_behind_player("detras", 30.0)
				for _i in 80:
					await s.get_tree().create_timer(0.1).timeout
					if sh.state == Shero.State.COACHING:
						break
			var p: Player = s._player()
			p.rotation.y += PI * 0.75
			p.head.rotation.x = 0.05
		"p3_hud":
			await s._place(2, Vector3(10.0, 0, 20.0), 90.0)
			Metrics.set_aux(Metrics.Aux.BREAK)
			Discipline.debug_start("break", 12.5 * 60.0)
			await s.get_tree().create_timer(0.3).timeout
			Metrics.issue_written_warning("break_excedido")
		"p3_persecucion_m1":
			await s._place(-1, Vector3(9.0, 0, 3.0), -90.0, 0.02)
			Metrics.set_aux(Metrics.Aux.BREAK)
			Pursuit.start("shero", "break_excedido")
			await _arrive_now(s)
			await _wait_close(s, 6.0, 4.0)
		"p3_persecucion_escalera":
			var b: Building = s._building()
			if b.current_floor != 2:
				b.go_to_floor(2, "ascensor")
				await s.get_tree().create_timer(0.3).timeout
			Metrics.set_aux(Metrics.Aux.BREAK)
			Pursuit.start("shero", "abandono")
			b.current_floor = 2
			b.go_to_stairwell(1, false)
			await s.get_tree().create_timer(0.3).timeout
			s._player().teleport(b.floor_node.global_position + Vector3(0, 0.05, 1.2), 0.0)
			await _arrive_now(s)
			await s.get_tree().create_timer(0.5).timeout
			_look_at_hunter(s)
		"p3_persecucion_azotea":
			await s._place(9, Vector3(6.0, 0, 9.5), 180.0)
			Metrics.set_aux(Metrics.Aux.BREAK)
			Pursuit.start("shero", "abandono")
			await _arrive_now(s)
			await _wait_close(s, 3.0, 8.0)
			Pursuit.instance().process_mode = Node.PROCESS_MODE_DISABLED  # congelada para la captura
		"p3_bano_espera":
			await s._place(2, Vector3(-10.0, 0, -1.5), 0.0)
			Metrics.set_aux(Metrics.Aux.BANO)
			Pursuit.start("shero", "abandono")
			await s.get_tree().create_timer(0.3).timeout
			var bath: Node3D = null
			for bn in s.get_tree().get_nodes_in_group("bathrooms"):
				if bn is Bathroom and (bn as Bathroom).player_inside:
					bath = bn as Node3D
			# Sale de su sitio (a ~57 m): espera a que llegue a la puerta del baño.
			for _i in 300:
				await s.get_tree().create_timer(0.1).timeout
				var hn := Pursuit.node_of("shero")
				var pu: Node3D = bath.get_node_or_null("Puerta") as Node3D if bath != null else null
				if hn == null or pu == null or hn.global_position.distance_to(pu.global_position) < 2.4:
					break
			await s.get_tree().create_timer(1.0).timeout
			# Desde adentro, con la puerta abierta: Shero espera en el marco.
			if bath != null:
				for d in s.get_tree().get_nodes_in_group("interactables"):
					if d is WorldObjects.Door and bath.is_ancestor_of(d):
						(d as WorldObjects.Door).set_open(true)
				var door := bath.get_node_or_null("Puerta") as Node3D
				if door != null:
					var inside := bath.global_position.lerp(door.global_position, 0.35)
					inside.y = bath.global_position.y
					s._player().teleport(inside, 0.0)
			await s.get_tree().create_timer(0.2).timeout
			_look_at_hunter(s)
		"p3_aparicion":
			await s._place(1, Vector3(-2.0, 0, 0.0), -90.0)
			Discipline.debug_start("sala", 0.0)
			Discipline.debug_fire("sala", 2)
			await s.get_tree().create_timer(0.4).timeout
			Discipline.presence.call("spawn_apparition")
			await s.get_tree().create_timer(0.3).timeout
		"p3_video":
			await _video(s, arg if arg != "" else "persecucion")


func after(name: String, s: Node) -> void:
	Dread.forced = -1.0
	Engine.time_scale = 1.0
	if Pursuit.instance() != null:
		Pursuit.instance().process_mode = Node.PROCESS_MODE_INHERIT
		Pursuit.instance().stop_all("reinicio")
	if Metrics.ack_pending:
		Metrics.give_ack()
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null and name.begins_with("p3_ezlak"):
		ws.call("set_zoom", false)
	if Checkpoints.dying:
		for _i in 80:
			await s.get_tree().create_timer(0.1).timeout
			if Checkpoints.death_visible:
				break
		Checkpoints.respawn()
		GameState.stop_calm()
		await s.get_tree().create_timer(1.0).timeout
	Discipline.from_save_dict(Discipline.to_save_dict())


func _ezlak(s: Node, channel: String) -> void:
	await s._sit_c14()
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var ez: Object = ws.get("ezlak")
	ez.call("open_channel", channel)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await s.get_tree().create_timer(0.2).timeout
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await s.get_tree().create_timer(0.3).timeout
	Metrics.set_aux(Metrics.Aux.BREAK)
	await s.get_tree().create_timer(0.2).timeout
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	Discipline.debug_start("break", 0.0)
	Discipline.debug_fire("break", 1)
	Discipline.debug_start("sala", 0.0)
	Discipline.debug_fire("sala", 1)
	Discipline.debug_fire("correo", 1)
	await s.get_tree().create_timer(4.5).timeout
	Discipline.debug_fire("sala", 3)
	await s.get_tree().create_timer(2.6).timeout
	ez.call("open_channel", channel)
	var hub := EzlakHub.get_hub(s.get_tree())
	hub.typing(channel, "shero", 6.0)
	await s.get_tree().create_timer(0.4).timeout


## Espera (con la cámara siguiéndola) a que Shero esté a menos de `dist` m, como mucho `max_s` s.
func _wait_close(s: Node, dist: float, max_s: float) -> void:
	var p: Player = s._player()
	var t := 0.0
	while t < max_s:
		_look_at_hunter(s)
		await s.get_tree().process_frame
		t += s.get_process_delta_time()
		var n := Pursuit.node_of("shero")
		if n == null or Checkpoints.dying or n.global_position.distance_to(p.global_position) < dist:
			break
	_look_at_hunter(s)


## La llegada de Shero sin esperar los 20-32 s (para las capturas).
func _arrive_now(s: Node) -> void:
	var pi: Pursuit = Pursuit.instance()
	if pi == null:
		return
	var h: Dictionary = pi._hunts.get("shero", {})
	if not h.is_empty():
		h["arrive_left"] = 0.05
	for _i in 30:
		await s.get_tree().process_frame
		if str(Pursuit.info("shero").get("space", "")) != "":
			break


func _look_at_hunter(s: Node) -> void:
	var n := Pursuit.node_of("shero")
	var p: Player = s._player()
	if n == null or p == null:
		return
	var d := n.global_position - p.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = clampf(atan2(d.y + 0.3, Vector2(d.x, d.z).length()), -0.5, 0.5)


## Videos (--write-movie): ezlak (escalera en Ezlaki con "escribiendo…", ediciones y el WW con Ack),
## parlantes (Shero por los parlantes del -1, la luz que baja, su respiración y la aparición al final del
## pasillo) y persecucion (de su sitio a tu piso, por el ascensor al -1, sale del ascensor, te alcanza: screamer
## de Shero calvo).
func _video(s: Node, which: String) -> void:
	var tree: SceneTree = s.get_tree()
	match which:
		"ezlak":
			await s._sit_c14()
			var ws := tree.get_first_node_in_group("workstation")
			ws.call("set_zoom", true)
			var ez: Object = ws.get("ezlak")
			ez.call("open_channel", "dm:shero")
			await tree.create_timer(0.8).timeout
			print("[video] inicio %d" % Engine.get_frames_drawn())
			Metrics.set_aux(Metrics.Aux.BREAK)  # 1.er break: "Break. Ok." → (editado) "…No hay breaks, pero ok."
			await tree.create_timer(7.5).timeout
			Metrics.set_aux(Metrics.Aux.AVAILABLE)
			Discipline.debug_start("sala", 0.0)
			Discipline.debug_fire("sala", 1)
			await tree.create_timer(3.6).timeout
			Discipline.debug_fire("sala", 2)
			await tree.create_timer(2.6).timeout
			Discipline.debug_fire("sala", 3)
			await tree.create_timer(2.2).timeout
			ws.call("_give_ack")
			await tree.create_timer(2.2).timeout
			ez.call("open_channel", "#team-familia")
			await tree.create_timer(2.5).timeout
			print("[video] fin %d" % Engine.get_frames_drawn())
		"parlantes":
			# Desde el extremo oeste del lobby mirando al este (lobby → cafetería): ahí aparece al final.
			await s._place(-1, Vector3(-10.0, 0, 5.0), -90.0)
			await tree.create_timer(0.8).timeout
			print("[video] inicio %d" % Engine.get_frames_drawn())
			Discipline.debug_start("sala", 0.0)
			Discipline.debug_fire("sala", 1)
			await tree.create_timer(2.0).timeout
			Dread.forced = 0.45
			Discipline.debug_fire("sala", 2)
			await tree.create_timer(4.5).timeout
			Dread.forced = 0.7
			print("[video] aparición: ", Discipline.presence.call("spawn_apparition"))
			await tree.create_timer(2.6).timeout
			var p: Player = s._player()
			for _i in 20:
				p.rotate_y(-0.12)
				await tree.process_frame
			await tree.create_timer(0.8).timeout
			for _i in 20:
				p.rotate_y(0.12)
				await tree.process_frame
			await tree.create_timer(2.0).timeout
			print("[video] fin %d" % Engine.get_frames_drawn())
		_:
			var b: Building = s._building()
			await s._place(2, Vector3(22.0, 0, -2.5), -90.0)
			if not GameState.logged_in:
				GameState.login()  # sin sesión el reloj no corre y la pista no llega a la persecución
			await tree.create_timer(0.5).timeout
			print("[video] inicio %d" % Engine.get_frames_drawn())
			# Break ya en 15:57 (llamado, verbal y WW de golpe); a los 16 min sale con la amonestación.
			Discipline.debug_start("break", 15.95 * 60.0)
			Metrics.set_aux(Metrics.Aux.BREAK)
			var p2: Player = s._player()
			for _i in 150:
				_look_at_hunter(s)
				await tree.process_frame
				var hn := Pursuit.node_of("shero")
				if hn != null and hn.global_position.distance_to(p2.global_position) < 9.0:
					break
			# Al ascensor: baja al -1.
			b.go_to_floor(-1, "ascensor_dentro")
			await tree.create_timer(1.6).timeout
			p2.teleport(b.floor_node.global_position + Vector3(9.0, 0, 3.0), 0.0)
			var e := b.floor_node.find_child("ascensor", true, false) as Node3D
			if e != null:
				var dd := e.global_position - p2.global_position
				p2.rotation.y = atan2(-dd.x, -dd.z)
			var pi: Pursuit = Pursuit.instance()
			var h: Dictionary = pi._hunts.get("shero", {}) if pi != null else {}
			if not h.is_empty():
				h["arrive_left"] = minf(float(h["arrive_left"]), 2.5)
			for _i in 400:
				_look_at_hunter(s)
				await tree.process_frame
				if Checkpoints.dying:
					break
			for _i in 60:
				await tree.create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
			await tree.create_timer(1.2).timeout
			print("[video] fin %d" % Engine.get_frames_drawn())

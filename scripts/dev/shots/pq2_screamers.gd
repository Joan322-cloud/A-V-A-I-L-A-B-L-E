## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de Q2 (v0.3.1): caras deformadas, screamers y persecuciones.
##   q2_cara:<slug>:<deform>[:grab]   modelo frente a la cámara con ScreamRig (deform 0..1)
##   q2_screamer:<causa>              pico del screamer nuevo (cámara lenta)
##   q2_video:<causa>                 para --write-movie: 1 s antes, screamer y pantalla de muerte (marca inicio/fin)
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 -- --shot q2_cara:shero:1


func shots() -> Array[String]:
	return ["q2_cara:", "q2_screamer:", "q2_video:", "q2_escritorios", "q2_escritorios:", "q2_haime_sev:", "q2_perf:", "q2_persecucion_video:"]


func shoot(name: String, arg: String, s: Node) -> void:
	Dread.forced = -1.0
	match name:
		"q2_cara":
			var parts := arg.split(":")
			var slug := parts[0] if parts.size() > 0 and parts[0] != "" else "shero"
			var k := float(parts[1]) if parts.size() > 1 else 1.0
			var g := parts.size() > 2 and parts[2] == "grab"
			await s._place(2, Vector3(20.5, 0, 0.8), -55.0, 0.0)
			var p: Player = s._player()
			var cam := p.camera
			var holder := Node3D.new()
			holder.name = "LabCara"
			p.get_parent().add_child(holder)
			var rig := CharacterRig.attach(holder, slug, float(Screamers.HEIGHTS.get(slug, 1.8)))
			rig.set_look("calvo" if slug == "shero" else "")
			rig.play("idle")
			var f := -cam.global_transform.basis.z
			f.y = 0
			f = f.normalized()
			var dist := 0.75 if slug != "perrito_rta" else 0.6
			holder.global_position = Vector3(cam.global_position.x, p.global_position.y, cam.global_position.z) + f * dist
			holder.look_at(Vector3(cam.global_position.x, holder.global_position.y, cam.global_position.z), Vector3.UP)
			var l := OmniLight3D.new()
			l.light_energy = 2.0
			l.omni_range = 3.0
			holder.add_child(l)
			l.position = Vector3(0, 1.2, -0.6)
			await s.get_tree().process_frame
			var sr := rig.scream_rig()
			sr.deform = k
			if g:
				sr.grab = 1.0
				var right := cam.global_transform.basis.x
				sr.grab_l = cam.global_position + right * 0.22 + f * 0.12 - Vector3(0, 0.05, 0)
				sr.grab_r = cam.global_position - right * 0.22 + f * 0.12 - Vector3(0, 0.05, 0)
			sr.look = 1.0
			sr.look_at_point = cam.global_position
			await s.get_tree().create_timer(0.4).timeout
			# Mira a la cara.
			var hp := rig.head_position()
			var to := hp - cam.global_position
			p.rotation.y = atan2(-to.x, -to.z)
			p.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.2)
			await s.get_tree().create_timer(0.2).timeout


		"q2_escritorios":
			# arg opcional "x,z,yaw" (otro encuadre)
			var v := arg.split(",")
			if v.size() == 3:
				await s._place(2, Vector3(float(v[0]), 0, float(v[1])), float(v[2]), -0.05)
			else:
				await s._place(2, Vector3(40.5, 0, -12.0), -70.0, -0.05)
			await s.get_tree().create_timer(1.2).timeout
		"q2_haime_sev":
			await s._place(2, Vector3(-5.9, 0, 20.0), 90.0, -0.05)
			for a in s.get_tree().get_nodes_in_group("p5_haime_actor"):
				a.call("set_severity", int(arg) if arg.is_valid_int() else 3)
				a.call("look_at_player", true)
			await s.get_tree().create_timer(1.5).timeout
		"q2_persecucion_video":
			await chase_video(int(arg) if arg.is_valid_int() else 2, s)
		"q2_perf":
			await perf(arg if arg != "" else "break_excedido", s)
		"q2_screamer", "q2_video":
			var cause := arg if arg != "" else "break_excedido"
			var killer := ""
			if cause in ["lunch_dormido", "colapso", "colapso_pie"] or cause.ends_with("#pie"):
				killer = "shero" if cause == "lunch_dormido" else ("vitzo" if cause.ends_with("#pie") else "-")
			if cause.contains("@"):
				killer = cause.get_slice("@", 1)
				cause = cause.get_slice("@", 0)
			if killer == "":
				killer = Checkpoints.killer_of(cause)
			elif killer == "-":
				killer = ""
			await setup_for(cause, s)
			GameState.stop_calm()
			if name == "q2_video":
				await s.get_tree().create_timer(0.6).timeout
				print("[video] inicio %d" % Engine.get_frames_drawn())
				await s.get_tree().create_timer(1.0).timeout
				var f0 := Engine.get_frames_drawn()
				await start_death(cause, killer, s)
				for _i in 900:
					await s.get_tree().create_timer(0.05).timeout
					if Checkpoints.death_visible:
						break
				var fs := Engine.get_frames_drawn()
				print("[video] pantalla %d (%.2f s hasta la pantalla de muerte, a 30 fps)" % [fs, (fs - f0) / 30.0])
				await s.get_tree().create_timer(3.6).timeout
				print("[video] fin %d" % Engine.get_frames_drawn())
			else:
				var dur := Screamers.duration(killer, cause)
				var at := float(OS.get_environment("Q2_AT")) if OS.get_environment("Q2_AT") != "" else 0.7
				Engine.time_scale = 0.25
				Checkpoints.request_death(cause, detail_for(cause), killer)
				await s.get_tree().create_timer(maxf(dur * at - 0.8 * 0.25, 0.05)).timeout


## Persecución para --write-movie: piso 2 = Shero se levanta de su escritorio y corre por la sala hasta ti;
## otro piso = lo esperas mirando la entrada (escalera/ascensor) y sale corriendo. El tránsito se acorta a 10 s
## (en el juego: 20 s + 6 por parada) para que el video no dure un minuto.
static func chase_video(floor_n: int, s: Node) -> void:
	GameState.login()
	var b: Building = s._building()
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	if b.current_floor != floor_n:
		b.go_to_floor(floor_n, "ascensor")
		await s.get_tree().create_timer(0.4).timeout
	var fl := b.floor_node
	var grid := Pursuit.grid_for(fl)
	var look_at := Vector3.ZERO
	var stand := Vector3.ZERO
	if floor_n == 2:
		var desk := fl.find_child("escritorio_shero", true, false) as Node3D
		look_at = desk.global_position + Vector3(0, 1.2, 0)
		stand = desk.global_position + Vector3(-17.0, 0, -6.0)
	else:
		var m := fl.find_child("escalera", true, false) as Node3D
		look_at = m.global_position + Vector3(0, 1.4, 0)
		stand = m.global_position + m.global_transform.basis.z * -11.0
	if grid != null:
		var c := grid.nearest(stand, 25)
		if c.x > -99999:
			stand = grid.pos_of(c)
	var to := look_at - (stand + Vector3(0, 1.6, 0))
	p.teleport(stand, rad_to_deg(atan2(-to.x, -to.z)))
	p.head.rotation.x = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6)
	GameState.stop_calm()
	await s.get_tree().create_timer(0.8).timeout
	print("[video] inicio %d" % Engine.get_frames_drawn())
	await s.get_tree().create_timer(0.6).timeout
	Pursuit.start("shero", "abandono", -1.0, null, "", -99, Vector3.INF, Callable(), {"asesino": "shero"})
	if floor_n != 2:
		var inst := Pursuit.instance()
		var h: Dictionary = (inst.get("_hunts") as Dictionary).get("shero", {})
		if not h.is_empty():
			h["arrive_kind"] = "escalera"
			h["arrive_left"] = 10.0
			h["transit_total"] = 10.0
	# La cámara del jugador sigue mirando hacia él (como haría alguien que lo ve venir).
	for _i in 900:
		await s.get_tree().process_frame
		var n := Pursuit.node_of("shero")
		if n != null and not Checkpoints.dying:
			var d := n.global_position + Vector3(0, 1.5, 0) - p.camera.global_position
			p.rotation.y = lerp_angle(p.rotation.y, atan2(-d.x, -d.z), 0.08)
			p.head.rotation.x = lerpf(p.head.rotation.x, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.6), 0.08)
		if Checkpoints.death_visible:
			break
	await s.get_tree().create_timer(3.0).timeout
	print("[video] fin %d" % Engine.get_frames_drawn())


## Rendimiento en Calidad Baja: tiempo de cada fotograma 1,5 s antes y durante el screamer (sin --write-movie).
static func perf(cause: String, s: Node) -> void:
	GfxQuality.apply(s.get_tree(), "baja")
	await setup_for(cause, s)
	GameState.stop_calm()
	var before: Array[float] = []
	var during: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < 1500000:
		await s.get_tree().process_frame
		var now := Time.get_ticks_usec()
		before.append((now - last) / 1000.0)
		last = now
	Checkpoints.request_death(cause, detail_for(cause), Checkpoints.killer_of(cause))
	last = Time.get_ticks_usec()
	while not Checkpoints.death_visible and Time.get_ticks_usec() - last < 15000000:
		await s.get_tree().process_frame
		var now2 := Time.get_ticks_usec()
		during.append((now2 - last) / 1000.0)
		last = now2
	before.sort()
	var dmax := 0.0
	var spikes := 0
	var med := before[before.size() / 2] if not before.is_empty() else 0.0
	for d in during:
		dmax = maxf(dmax, d)
		if d - med > 100.0:
			spikes += 1
	print("[perf] %s · calidad baja · mediana antes %.1f ms · máx durante %.1f ms · tirones > mediana+100 ms: %d · fotogramas %d" % [cause, med, dmax, spikes, during.size()])


## Arranca la muerte como en el juego: Vitzo sale del monitor (VitzoScreamer.attack; «#pie» = te paras y te
## persigue), la 2.ª siesta (lunch_dormido) te despierta en el sofá, la Fatiga te desploma (colapso / colapso_pie);
## el resto pide la muerte directo (el screamer de la causa).
static func start_death(cause: String, killer: String, s: Node) -> void:
	var ag := OS.get_environment("K2_AGENTE")  # v0.3.2: la fusión de Vitzo con otro agente (videos)
	if ag != "":
		GameState.agent = ag
	var base := cause.trim_suffix("#pie")
	if killer == "vitzo":
		VitzoScreamer.attack(base)
		if cause.ends_with("#pie"):
			await s.get_tree().create_timer(0.7).timeout
			var p: Player = s._player()
			if p.seated:
				p.stand_up()
			await s.get_tree().create_timer(0.5).timeout
			# Retrocede mirando a Vitzo (como alguien que huye de espaldas a la pared).
			for _i in 600:
				await s.get_tree().process_frame
				if Checkpoints.dying:
					break
				var n := Pursuit.node_of("vitzo")
				var fx := s.get_tree().get_first_node_in_group(VitzoScreamer.GROUP) as Node3D
				var src := n if n != null and n.visible else fx
				if src != null:
					var d := src.global_position + Vector3(0, 0.8, 0) - p.camera.global_position
					p.rotation.y = lerp_angle(p.rotation.y, atan2(-d.x, -d.z), 0.1)
					p.head.rotation.x = lerpf(p.head.rotation.x, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.4), 0.1)
					var back := -Vector3(d.x, 0, d.z).normalized()
					p.velocity = back * 2.2
					p.move_and_slide()
		return
	if cause == "colapso" or cause == "colapso_pie":
		Fatigue.set_value(99.0)
		Fatigue.add(10.0)
		return
	if cause == "lunch_dormido":
		Checkpoints.request_death("lunch_excedido", detail_for("lunch_excedido"), "shero")
		return
	Checkpoints.request_death(cause, detail_for(cause), killer)


## Dónde está el jugador para cada causa (como en el juego): sentado en C-14 por defecto.
static func setup_for(cause: String, s: Node) -> void:
	match cause:
		"aux_incorrecto", "abandono", "work_avoiding", "otra_isla", "regreso_tardio":
			await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
		"training_inasistencia":
			await s._place(1, Vector3(18.0, 0, -2.0), 180.0)
		"rasec_evento":
			await s._place(2, Vector3(28.0, 0, -6.0), 160.0)
		"calibracion_final":
			await _sit(s, 2, "calibracion")
			for a in s.get_tree().get_nodes_in_group("p5_haime_actor"):
				a.call("session_mode", true, 4)
		"training_reprobado":
			await _sit(s, 1, "training_sala2_1")
		"lunch_excedido":
			await s._place(-1, Vector3(8.0, 0, 6.0), 0.0)
		"lunch_dormido":
			var b: Building = s._building()
			b.go_to_floor(-1, "ascensor")
			await s.get_tree().create_timer(0.4).timeout
			if not GameState.logged_in:
				GameState.login()
			var p: Player = s._player()
			if p.seated:
				p.stand_up()
			for sp in s.get_tree().get_nodes_in_group("sleep_spots"):
				(sp as SleepSpot).interact(p)
				break
			await s.get_tree().create_timer(1.5).timeout
		"colapso_pie":
			await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			if not GameState.logged_in:
				GameState.login()
		_:
			await s._sit_c14()


static func _sit(s: Node, floor_n: int, seat_id: String) -> void:
	var b: Building = s._building()
	if b.current_floor != floor_n:
		b.go_to_floor(floor_n, "ascensor")
		await s.get_tree().create_timer(0.4).timeout
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id(seat_id)
	var p: Player = s._player()
	if seat != null and not p.seated:
		p.sit_at(seat, seat_id)
	if not GameState.logged_in:
		GameState.login()


static func detail_for(cause: String) -> String:
	match cause:
		"available_bajo":
			return "61"
		"break_excedido":
			return "16:00"
		"lunch_excedido":
			return "52:00"
		"coaching_exceso":
			return "11:00"
		"training_reprobado":
			return "2/5"
		"aux_incorrecto":
			return "Baño 02:31"
	return ""


func after(name: String, s: Node) -> void:
	Engine.time_scale = 1.0
	if name in ["q2_screamer", "q2_video"]:
		for _i in 80:
			await s.get_tree().create_timer(0.1).timeout
			if Checkpoints.death_visible:
				break
		Checkpoints.respawn()
		await s.get_tree().create_timer(1.5).timeout
	if name == "q2_cara":
		var n: Node = s._player().get_parent().get_node_or_null("LabCara")
		if n != null:
			n.queue_free()

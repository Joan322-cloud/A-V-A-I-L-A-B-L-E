## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P2 (PLAN §10 P2): zonas nuevas, exterior con lluvia y bus, utilería de terror, colapso y un
## screamer por causa ("screamer:<causa>", capturado cerca del clímax).
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 -- --shot p2   (o una vista)


func shots() -> Array[String]:
	return ["pingpong_m1", "descanso_puffs", "dormido_puff", "dispensador_sala", "calibracion", "guardia_puesto", "training_sala2", "fachada", "bus_llegada", "bus_salida", "lluvia_calle", "azotea_skyline", "cafeteria_azotea", "sala_ventanas", "kpi_tablero", "c17", "notas_escritorio", "presion_sala", "colapso_sentado", "colapso_de_pie", "perf_lluvia", "screamer:", "video:"]


func shoot(name: String, arg: String, s: Node) -> void:
	Dread.forced = -1.0
	match name:
		"pingpong_m1":
			await s._place(-1, Vector3(27.4, 0, 10.8), -40.0, -0.2)
		"descanso_puffs":
			await s._place(-1, Vector3(33.9, 0, 8.6), 25.0, -0.3)
		"dormido_puff":
			GameState.login()
			await s._place(-1, Vector3(31.0, 0, 8.5), 0.0)
			var puff: SleepSpot = s._building().floor_node.find_child("Dormir_puff_3", true, false) as SleepSpot
			if puff != null:
				puff.interact(s._player())
			await s.get_tree().create_timer(1.4).timeout
		"dispensador_sala":
			await s._place(2, Vector3(24.2, 0, -1.6), 145.0, -0.2)
		"calibracion":
			await s._place(2, Vector3(-2.6, 0, 18.2), 75.0, -0.12)
		"guardia_puesto":
			await s._place(-1, Vector3(-5.4, 0, 13.6), 55.0, -0.05)
		"training_sala2":
			await s._place(1, Vector3(18.0, 0, -4.4), 0.0, -0.1)
		"fachada":
			await s._place(-1, Vector3(0.0, 0, 30.5), 0.0, 0.22)
		"bus_llegada":
			s._main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
			await s.get_tree().create_timer(0.3).timeout
			s._player().teleport(Vector3(-2.0, 0, 21.5), -105.0)
			s._player().head.rotation.x = 0.02
		"bus_salida":
			GameState.shift_over = true
			s._building().go_to_floor(1, "ascensor")
			await s.get_tree().create_timer(0.2).timeout
			s._building().go_to_floor(-1, "calle")
			await s.get_tree().create_timer(6.5).timeout
			s._player().teleport(Vector3(-1.5, 0, 22.5), -100.0)
			s._player().head.rotation.x = 0.02
		"lluvia_calle":
			await s._place(-1, Vector3(-6.0, 0, 18.0), 160.0, 0.0)
			var l: Node = s._building().floor_node.find_child("Relampago", true, false)
			if l != null:
				l.call("strike_now")
			await s.get_tree().create_timer(0.03).timeout
		"azotea_skyline":
			GameState.flags["azotea_abierta_dev"] = true
			await s._place(9, Vector3(-3.0, 0, 18.6), 0.0, 0.06)
			s._player().rotation_degrees.y = 180.0
		"cafeteria_azotea":
			await s._place(9, Vector3(1.5, 0, 10.0), -50.0, -0.1)
		"sala_ventanas":
			await s._place(2, Vector3(40.0, 0, -9.5), -90.0, 0.05)
		"kpi_tablero":
			await s._place(2, Vector3(25.8, 0, -16.6), 0.0, 0.18)
		"c17":
			await s._place(2, Vector3(27.2, 0, -1.0), -126.0, -0.18)
			var g: Node = s._building().floor_node.find_child("Fantasma", true, false)
			if g != null:
				g.call("show_now")
		"notas_escritorio":
			await s._place(2, Vector3(39.3, 0, -10.2), 0.0, -0.45)
		"presion_sala":
			Dread.forced = 0.85
			Fatigue.set_value(85.0)
			await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			await s.get_tree().create_timer(1.0).timeout
		"colapso_sentado":
			await s._sit_c14()
			Engine.time_scale = 0.25
			Fatigue.set_value(95.0)
			Fatigue.add(10.0)
			await s.get_tree().create_timer(0.9).timeout  # + 0,8 s de screenshot.gd = ~1,7 s de 3,8
		"colapso_de_pie":
			await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			Engine.time_scale = 0.25
			Fatigue.set_value(95.0)
			Fatigue.add(10.0)
			await s.get_tree().create_timer(0.9).timeout
		"perf_lluvia":
			# Costo relativo de la lluvia (calidad Baja, Compatibility): fps con y sin las gotas.
			GfxQuality.apply(s.get_tree(), "baja")
			await s._place(-1, Vector3(0.0, 0, 26.0), 0.0, 0.05)
			var fl: Node = s._building().floor_node
			var rain: Node3D = fl.find_child("Lluvia", true, false) as Node3D
			var with_rain := await _fps(s, 4.0)
			if rain != null:
				rain.visible = false
			var without := await _fps(s, 4.0)
			if rain != null:
				rain.visible = true
			print("[perf] calle, calidad baja: %.1f fps con lluvia (%d gotas) · %.1f fps sin lluvia" % [with_rain, Weather.drop_count(), without])
		"video":
			# Para grabar con --write-movie (sin cámara lenta): marca el fotograma de inicio y de fin en el log.
			var vc := arg if arg != "" else "break_excedido"
			var vk := ""
			if vc == "coaching_rasec":
				vc = "coaching"
				vk = "rasec"
			var standing := vc in ["aux_incorrecto", "abandono", "training_inasistencia", "work_avoiding", "otra_isla", "colapso_de_pie"]
			if standing:
				await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			else:
				await s._sit_c14()
			GameState.stop_calm()
			await s.get_tree().create_timer(1.0).timeout
			print("[video] inicio %d" % Engine.get_frames_drawn())
			if vc.begins_with("colapso"):
				Fatigue.set_value(95.0)
				Fatigue.add(10.0)
			else:
				Checkpoints.request_death(vc, "61" if vc == "available_bajo" else "", vk)
			for _i in 120:
				await s.get_tree().create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
			await s.get_tree().create_timer(1.0).timeout
			print("[video] fin %d" % Engine.get_frames_drawn())
		"screamer":
			var cause := arg if arg != "" else "break_excedido"
			var killer := Checkpoints.killer_of(cause)
			if cause == "coaching_rasec":
				cause = "coaching"
				killer = "rasec"
			if cause in ["aux_incorrecto", "abandono", "training_inasistencia", "work_avoiding", "otra_isla"]:
				await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			else:
				await s._sit_c14()
			var dur := Screamers.duration(killer, cause)
			Engine.time_scale = 0.2
			Checkpoints.request_death(cause, "61" if cause == "available_bajo" else "", killer)
			var at := dur - Screamers.CUT - 0.1 - 0.8  # screenshot.gd espera 0,8 s (de juego) antes de capturar
			await s.get_tree().create_timer(maxf(at, 0.05)).timeout


func after(name: String, s: Node) -> void:
	Engine.time_scale = 1.0
	Dread.forced = -1.0
	if name == "dormido_puff":
		var spot: SleepSpot = s._building().floor_node.find_child("Dormir_puff_3", true, false) as SleepSpot
		if spot != null:
			spot.wake_up()
	if name == "bus_salida":
		GameState.shift_over = false
	if name.begins_with("screamer") or name.begins_with("colapso") or name.begins_with("video"):
		for _i in 80:
			await s.get_tree().create_timer(0.1).timeout
			if Checkpoints.death_visible:
				break
		Checkpoints.respawn()
		GameState.stop_calm()
		await s.get_tree().create_timer(2.2).timeout


func _fps(s: Node, seconds: float) -> float:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(seconds * 1000000.0):
		await s.get_tree().process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - t0) / 1000000.0)

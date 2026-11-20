## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de las muertes propias (v0.3.1, fx/kill_moves.gd):
##   k_tira:<causa>[,<causa>…]   tira de cuadros de la muerte (cada 0,16 s del reloj del screamer) en user://shots/tira/
##                    (<causa>_NN.png), para revisar la coreografía sin grabar video. Mismas causas que q2_video
##                    (correo_vitzo#pie, lunch_dormido, coaching@rasec, colapso).
##                    calibracion_final#sesion: la muerte llega sola al final de la sesión FATAL de Haime (v0.3.2d, la toma
##                    de relevo: el screamer sale de la pose y el sitio del Haime del mundo); la sesión corre rápido
##                    (K_FAST, 6) hasta el segundo K_SLOW_AT (44) y después a K_SCALE; K_PRE guarda los cuadros previos.
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 640x360 -- --shot k_tira:break_excedido
## El video sigue siendo q2_video:<causa> (pq2_screamers.gd): 1 s antes, la muerte y la pantalla de muerte.

const Q2 := preload("res://scripts/dev/shots/pq2_screamers.gd")


func shots() -> Array[String]:
	return ["k_tira:"]


func shoot(name: String, arg: String, s: Node) -> void:
	Dread.forced = -1.0
	if name != "k_tira":
		return
	# v0.3.2e: varias causas separadas con «,» en una sola corrida (muere, reaparece, la siguiente): una tira por causa.
	var list := (arg if arg != "" else "break_excedido").split(",", false)
	for i in list.size():
		await _one(str(list[i]), s)
		if i < list.size() - 1:
			Engine.time_scale = 1.0
			for _j in 80:
				await s.get_tree().create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
			Checkpoints.respawn()
			await s.get_tree().create_timer(1.2).timeout


func _one(arg: String, s: Node) -> void:
	var cause := arg if arg != "" else "break_excedido"
	var killer := ""
	if cause in ["lunch_dormido"]:
		killer = "shero"
	elif cause.ends_with("#pie"):
		killer = "vitzo"
	if cause.contains("@"):
		killer = cause.get_slice("@", 1)
		cause = cause.get_slice("@", 0)
	var sesion := cause.ends_with("#sesion")
	var hub: PersonajesP5 = null
	if sesion:
		cause = cause.trim_suffix("#sesion")
		killer = "haime"
		var h2: RefCounted = load("res://scripts/dev/shots/ph2_haime.gd").new()
		hub = await h2.call("_sit_session", s, 4, ["prometer_sin_verificar", "dato_personal"], true, false)
		hub.qa.test_answers = ["ok", "tarde"]
	else:
		if killer == "":
			killer = Checkpoints.killer_of(cause)
		await Q2.setup_for(cause, s)
		GameState.stop_calm()
		await s.get_tree().create_timer(0.5).timeout
	var dir := "user://shots/tira"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var tag := arg.replace("#", "_").replace("@", "_")
	var step := float(OS.get_environment("K_STEP")) if OS.get_environment("K_STEP") != "" else 0.16
	# v0.3.2d: K_SCALE (escala de tiempo, 0,35), K_FROM / K_TO (ventana del reloj del screamer, s), K_PRE (s antes de la
	# muerte que también se fotografían, con sufijo _pNN: la salida del monitor de Vitzo, el final de una persecución).
	var envf := func(k: String, dflt: float) -> float: return float(OS.get_environment(k)) if OS.get_environment(k) != "" else dflt
	var t_from: float = envf.call("K_FROM", 0.0)
	var t_to: float = envf.call("K_TO", 999.0)
	var pre: float = envf.call("K_PRE", 0.0)
	var k_scale: float = envf.call("K_SCALE", 0.35)
	var k_fast: float = envf.call("K_FAST", 6.0)
	var slow_at: float = envf.call("K_SLOW_AT", 44.0)
	# Varias muertes en una corrida: después de reaparecer hay unos segundos de gracia en los que no se puede morir.
	for _w in 150:
		if Checkpoints.can_die():
			break
		await s.get_tree().create_timer(0.2).timeout
	Engine.time_scale = k_scale if not sesion else k_fast
	if not sesion:
		Q2.start_death(cause, killer, s)  # sin esperar: la fase previa (Vitzo saliendo, la persecución) también se ve
	var next := t_from
	var n := 0
	var pn := 0
	var pre_buf: Array = []  # [segundos de juego, imagen] de los últimos K_PRE s antes de morir
	var gt := 0.0
	var pnext := 0.0
	for _i in 40000:
		await s.get_tree().process_frame
		gt += s.get_process_delta_time()
		var fx := s.get_tree().get_first_node_in_group(Screamers.GROUP) as Screamers
		if sesion and hub != null and fx == null and not Checkpoints.dying:
			Engine.time_scale = k_fast if hub.qa.clock < slow_at else k_scale
			if hub.qa.state != QaFeedback.State.SESION and gt > 30.0:
				print("[tira] la sesión terminó sin muerte")
				break
		elif sesion:
			Engine.time_scale = k_scale
		if fx == null:
			if n > 0 or Checkpoints.death_visible:
				break
			if not sesion and gt > 30.0 and not Checkpoints.dying:
				print("[tira] %s: la muerte no empezó" % tag)
				break
			if pre > 0.0 and gt >= pnext:
				pnext = gt + step
				var pl: Player = s._player()
				if pl != null and Engine.get_process_frames() % 5 == 0:
					print("[tira-previo] fov %.1f · cabeza %s giro %.3f/%.3f · cám %s rot %s" % [pl.camera.fov, str(pl.head.position.snapped(Vector3.ONE * 0.001)), pl.rotation.y, pl.head.rotation.x, str(pl.camera.position.snapped(Vector3.ONE * 0.001)), str(pl.camera.rotation.snapped(Vector3.ONE * 0.001))])
				pre_buf.append([gt, s.get_viewport().get_texture().get_image()])
				while pre_buf.size() > int(ceil(pre / step)) + 1:
					pre_buf.pop_front()
			continue
		if not pre_buf.is_empty():
			for pb in pre_buf:
				var pp := "%s/%s_p%02d.png" % [dir, tag, pn]
				(pb[1] as Image).save_png(pp)
				print("[tira] %s previo %.2f s -> %s" % [tag, float(pb[0]) - gt, ProjectSettings.globalize_path(pp)])
				pn += 1
			pre_buf.clear()
		if fx._clock > t_to:
			continue
		if fx._clock >= next:
			var img := s.get_viewport().get_texture().get_image()
			var p := "%s/%s_%02d.png" % [dir, tag, n]
			img.save_png(p)
			print("[tira] %s %.2f s -> %s" % [tag, fx._clock, ProjectSettings.globalize_path(p)])
			n += 1
			next += step
	Engine.time_scale = 1.0


func after(_name: String, s: Node) -> void:
	Engine.time_scale = 1.0
	for _i in 60:
		await s.get_tree().create_timer(0.1).timeout
		if Checkpoints.death_visible:
			break
	Checkpoints.respawn()
	await s.get_tree().create_timer(0.5).timeout

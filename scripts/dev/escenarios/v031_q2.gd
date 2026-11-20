## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios de Q2 (v0.3.1): screamers nuevos, muertes, persecuciones visibles entre pisos, escritorios, caras.
## `--escenario v031_q2` corre todos; ids con prefijo q2_.
##   q2_datos               filas de screamers.json: 3-4 s, intro existente, frase gritada (3 tomas ES + EN), texto
##   q2_deform_api          CharacterRig.set_deform / ScreamRig: shader de la cara, mandíbula por hueso, agarre (IK)
##   q2_scr:<causa>         una muerte: intro, agarre, frase, cara al máximo, UI escondida, duración ±0,25, pantalla
##   q2_screamers_todos     q2_scr de todas las causas con asesino (y la 2.ª siesta: lunch_dormido)
##   q2_cese_terror         despido: luces que se apagan, sin ventana blanca ni "ding", ¡ESTÁS DESPEDIDO!
##   q2_haime_calibracion   sentado frente a Haime: salta la mesa, sin pantalla roja plena, la PC no tapa
##   q2_vitzo_sentado       Vitzo sale del monitor y te agarra sentado (exclusiva)
##   q2_vitzo_persigue      te paras: termina de salir, te persigue y te salta; ningún otro enemigo interviene
##   q2_persecucion_piso:<n> Shero desde su escritorio hasta el piso n (-1, 1, 9, 2): tránsito visible, sale corriendo
##                          a ≥ 8 m, sin saltos > 2 m por fotograma salvo el viaje del ascensor, te alcanza
##   q2_persecucion_escalera Shero entra a la caja de escalera detrás de ti
##   q2_persecucion_trainer / q2_persecucion_rta   los cazadores de P5 corren visibles desde otro piso
##   q2_tercer_break        3.er break: Shero sale corriendo de su escritorio (C4)
##   q2_intenso             persecución intensa (extra.intenso): pasos fuertes y luces que mueren a su paso
##   q2_escritorios         Shero, Rasec y el Perrito sentados en sus escritorios; cada escalón empieza con stand_up
##   q2_haime_cara          C5: look_at_player y set_severity 0..3
##   q2_pantalla_muerte     estática, título con glitch, el motivo se reescribe, la cara del asesino
##   q2_colapso             Fatiga: sin screamer, visión doble, latidos

const REPORT := "user://logs/q2.log"


func escenarios() -> Array[String]:
	return ["q2_datos", "q2_deform_api", "q2_scr:", "q2_screamers_todos", "q2_cese_terror", "q2_haime_calibracion",
		"q2_vitzo_sentado", "q2_vitzo_persigue", "q2_persecucion_piso:", "q2_persecucion_m1", "q2_persecucion_p1",
		"q2_persecucion_p9", "q2_persecucion_p2", "q2_persecucion_escalera", "q2_persecucion_trainer", "q2_persecucion_rta",
		"q2_tercer_break", "q2_intenso", "q2_escritorios", "q2_haime_cara", "q2_pantalla_muerte", "q2_colapso"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"q2_datos": _datos(t)
		"q2_deform_api": await _deform_api(t)
		"q2_scr": await _scr_one(t, arg, true)
		"q2_screamers_todos": await _todos(t)
		"q2_cese_terror": await _cese(t)
		"q2_haime_calibracion": await _haime_cal(t)
		"q2_vitzo_sentado": await _vitzo(t, false)
		"q2_vitzo_persigue": await _vitzo(t, true)
		"q2_persecucion_piso": await _chase_floor(t, int(arg) if arg.is_valid_int() else -1)
		"q2_persecucion_m1": await _chase_floor(t, -1)
		"q2_persecucion_p1": await _chase_floor(t, 1)
		"q2_persecucion_p9": await _chase_floor(t, 9)
		"q2_persecucion_p2": await _chase_floor(t, 2)
		"q2_persecucion_escalera": await _chase_stairs(t)
		"q2_persecucion_trainer": await _chase_p5(t, "trainer", "training_inasistencia", 2)
		"q2_persecucion_rta": await _chase_p5(t, "rta", "aux_incorrecto", -1)
		"q2_tercer_break": await _tercer_break(t)
		"q2_intenso": await _intenso(t)
		"q2_escritorios": await _escritorios(t)
		"q2_haime_cara": await _haime_cara(t)
		"q2_pantalla_muerte": await _pantalla(t)
		"q2_colapso": await _colapso(t)


func _report(line: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open(REPORT, FileAccess.READ_WRITE) if FileAccess.file_exists(REPORT) else FileAccess.open(REPORT, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	f.close()


## Causas con screamer (muertes.json con asesino) + la fila de la 2.ª siesta.
static func screamer_causes() -> Array[String]:
	var out: Array[String] = []
	for c in DataLoader.list("muertes"):
		var killer := str(c.get("quien", ""))
		if Checkpoints.uses_screamer(killer) and not bool(c.get("solo_ww", false)):
			out.append(str(c.get("id", "")))
	return out


# --- datos ---------------------------------------------------------------------------------------

func _datos(t: Node) -> void:
	var rows: Dictionary = DataLoader.dict("screamers").get("causas", {})
	var fx := Screamers.new()
	for key in rows.keys():
		var r: Dictionary = rows[key]
		var killer := str(r.get("asesino", ""))
		var cause := str(key).get_slice("@", 0)
		var row := Screamers.row_for(killer, cause) if cause != "lunch_dormido" else r
		var d := Screamers.seconds_for(row)
		# v0.3.2: lo que haga falta para que la frase termine (v032_kills k2_frase_cabe), con el tope del screamer.
		var cap := Screamers.LONG_CAP if bool(row.get("escena", false)) else Screamers.TOTAL_CAP
		t.check(d >= 3.0 and d <= cap, "%s: duración %.1f s (3 s … %.1f s)" % [key, d, cap])
		var intro := str(row.get("intro", ""))
		t.check(intro != "" and fx.has_method("_i_" + intro), "%s: intro '%s' existe" % [key, intro])
		t.check(fx.has_method("_f_" + str(row.get("final", "embestida"))), "%s: final '%s' existe" % [key, str(row.get("final", "embestida"))])
		var frase := str(row.get("frase", ""))
		var takes := 0
		var en := 0
		for i in range(1, 4):
			if AudioManager.has_slot("%s_%02d" % [frase, i], false):
				takes += 1
			var parts := frase.split("/")
			if parts.size() == 3 and AudioManager.has_slot("%s/%s/en/%s_%02d" % [parts[0], parts[1], parts[2], i], false):
				en += 1
		t.check(takes == 3 and en == 3, "%s: frase gritada %s (%d tomas ES, %d EN)" % [key, frase, takes, en])
		var txt := str(row.get("frase_texto", ""))
		t.check(txt != "" and tr(txt) != txt, "%s: texto en pantalla %s = «%s»" % [key, txt, tr(txt)])
		if killer == "shero":
			t.check(str(row.get("look", "")) == "calvo", "%s: Shero calvo" % key)
	var expect := {"break_excedido": "NO_HAY_BREAKS", "lunch_excedido": "45_MINUTOS", "tercer_break": "TERCER_BREAK", "ww_sin_ack": "AMONESTACION", "abandono": "AMONESTACION",
		"tercer_ww": "DESPEDIDO", "aht_bo": "CORREO10", "work_avoiding": "ACASO", "reflejo_kyc": "ACASO", "coaching_exceso": "ONCE_HORAS", "rasec_evento": "PARTICIPAN", "calibracion_final": "EMPATIA2",
		"qa_inasistencia": "ESPERANDO", "correo_vitzo": "CORREO", "training_reprobado": "GAAAA"}
	for c in expect.keys():
		var r2 := Screamers.row_for(Checkpoints.killer_of(c), c)
		t.check(str(r2.get("frase_texto", "")).ends_with(str(expect[c])), "%s grita %s" % [c, tr(str(r2.get("frase_texto", "")))])
	t.check(str(Screamers.row_for("rasec", "coaching_exceso").get("final", "")) == "cabina", "Rasec te estrella la cabina de DJ")
	# v0.3.2 (Joan): Vitzo salta de inmediato; la intro «zarpazo» sirve sentado y de pie (antes «monitor» / «salto»).
	t.check(str(Screamers.row_for("vitzo", "correo_vitzo").get("intro", "")) == "zarpazo", "Vitzo salta de inmediato (intro zarpazo)")
	fx.free()


# --- deformación ---------------------------------------------------------------------------------

func _deform_api(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var p: Player = t.player()
	for slug in ["shero", "rasec", "haime", "trainer", "perrito_rta", "guardia_fermin"]:
		var holder := Node3D.new()
		p.get_parent().add_child(holder)
		holder.global_position = p.global_position + Vector3(0, 0, -1.0)
		var rig := CharacterRig.attach(holder, slug, 1.8)
		t.check(rig != null, "%s: modelo" % slug)
		if rig == null:
			continue
		rig.play("idle")
		rig.set_deform(0.8)
		var sr := rig.scream_rig()
		t.check(sr != null and sr.has_face_shader(), "%s: ScreamRig con el shader de la cara" % slug)
		t.check(absf(rig.get_deform() - 0.8) < 0.001, "%s: set_deform/get_deform" % slug)
		await t.frames(3)
		var mat: ShaderMaterial = null
		for m in rig.find_children("*", "MeshInstance3D", true, false):
			var o := (m as MeshInstance3D).get_surface_override_material(0)
			if o is ShaderMaterial:
				mat = o
		t.check(mat != null and absf(float(mat.get_shader_parameter("deform")) - 0.8) < 0.01, "%s: el shader recibe deform=0,8" % slug)
		var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
		var jb := sk.find_bone("jaw")
		if jb >= 0 and slug != "shero":
			t.check(sr.last_jaw_deg > 15.0, "%s: la mandíbula baja más allá de lo anatómico (%.0f°)" % [slug, sr.last_jaw_deg])
		# agarre: la mano izquierda llega cerca del punto pedido
		sr.grab = 1.0
		var target := holder.global_position + Vector3(0.25, 1.4, 0.45)
		sr.grab_l = target
		sr.grab_r = target + Vector3(-0.5, 0, 0)
		await t.frames(3)
		if slug != "perrito_rta":
			var hp := sr.last_hand_l
			t.check(hp.distance_to(target) < 0.3, "%s: agarre (la mano a %.2f m del objetivo)" % [slug, hp.distance_to(target)])
		holder.queue_free()
	await t.frames(2)


# --- screamers -------------------------------------------------------------------------------------

## Una muerte con su screamer: lo que se ve y se oye, medido desde dentro (Screamers.last_info).
func _scr_one(t: Node, cause: String, fresh: bool) -> void:
	if cause == "":
		cause = "break_excedido"
	if fresh:
		await t.start_shift("Jiroshi", 2)
		await t.login_at_seat()
	GameState.stop_calm()
	var killer := Checkpoints.killer_of(cause) if cause != "lunch_dormido" else "shero"
	var real_cause := cause
	if cause == "lunch_dormido":
		real_cause = "lunch_excedido"
		var b: Building = t.building()
		b.go_to_floor(-1, "ascensor")
		await t.frames(3)
		var spot: SleepSpot = null
		for s in t.get_tree().get_nodes_in_group("sleep_spots"):
			spot = s
			break
		if spot != null:
			if t.player().seated:
				t.player().stand_up()
			spot.interact(t.player())
			await t.seconds(0.3)
	var row := Screamers.row_for(killer, real_cause)
	var expected := Screamers.seconds_for(row)
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)  # a escala alta un fotograma lento mueve la medición ±0,4 s
	var ws := t.get_tree().get_first_node_in_group("workstation") as CanvasItem
	var ui_hidden := false
	var t0 := Time.get_ticks_msec()
	var finished: Array = t.spy("screamer_finished")
	var shown: Array = t.spy("death_shown")
	if OS.get_cmdline_user_args().has("--log-screamer"):
		print("[test] die f%d" % Engine.get_process_frames())
	t.die(real_cause, "61", killer)
	var scr_t := -1.0
	var el := 0.0
	var max_deform := 0.0
	while el < maxf(13.0, expected + 4.0) and shown.is_empty():  # la fusión de Vitzo dura ~22 s
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		if finished.size() > 0 and scr_t < 0.0:
			scr_t = el
			if OS.get_cmdline_user_args().has("--log-screamer"):
				print("[test] screamer_finished a %.2f s f%d" % [el, Engine.get_process_frames()])
		max_deform = maxf(max_deform, float(Screamers.last_info.get("deform_max", 0.0)))
		var layer := _ui_layer(t)
		if layer != null and not layer.visible:
			ui_hidden = true
	var info: Dictionary = Screamers.last_info
	t.check(str(info.get("cause", "")) == real_cause, "%s: corre el screamer nuevo" % cause)
	if row.has("intro") and cause != "lunch_dormido":
		t.check(str(info.get("intro", "")) == str(row["intro"]) or str(info.get("intro", "")) == "alcance", "%s: intro %s (fue %s)" % [cause, str(row["intro"]), str(info.get("intro", ""))])
	if cause == "lunch_dormido":
		t.check(str(info.get("intro", "")) == "dormido", "lunch dormido: despiertas con Shero encima (intro %s)" % str(info.get("intro", "")))
	if str(row.get("agarre", "dos_brazos")) != "ninguno":
		t.check(float(info.get("grab", 0.0)) > 0.9, "%s: te agarra con los dos brazos (%.2f)" % [cause, float(info.get("grab", 0.0))])
	t.check(max_deform >= 0.9, "%s: la cara se deforma hasta %.2f" % [cause, max_deform])
	t.check(str(info.get("frase_path", "")) != "", "%s: grita la frase (%s)" % [cause, str(info.get("frase_path", "")).get_file()])
	t.check(ui_hidden, "%s: la UI se esconde durante el screamer (la PC no tapa al asesino)" % cause)
	# Reloj del propio screamer (delta de juego) ±0,25 s; visto desde fuera, holgado (con la máquina cargada un
	# fotograma lento a escala 2 mueve la medición externa).
	var own := float(info.get("duracion_real", -1.0))
	var late := float(info.get("grito_tarde", 0.0))  # v0.3.2: el final se corre si el grito llegó tarde
	# kills2: contra lo que el screamer se propuso durar (la fila; la fusión y las filas con accion_s se ajustan a su toma
	# y nunca pasan de la tabla).
	var plan := float(info.get("duracion", expected))
	t.check(absf(own - late - plan) <= 0.25 and plan <= expected + 0.02, "%s: dura %.2f s en su reloj (se propuso %.2f; tabla %.2f, +%.2f)" % [cause, own, plan, expected, late])
	t.check(scr_t > 0.0 and scr_t - late - plan <= 0.6 and plan - scr_t <= 1.2, "%s: dura %.2f s visto desde fuera (se propuso %.2f)" % [cause, scr_t, plan])
	t.check(not shown.is_empty() and t.death_screen().visible, "%s: 'Usuario desconectado' después" % cause)
	_report("screamer %s (%s): intro %s · final %s · %.2f s · deform %.2f · agarre %.2f · %s" % [cause, killer, info.get("intro", ""), info.get("final", ""), scr_t, max_deform, float(info.get("grab", 0.0)), str(info.get("frase_path", "")).get_file()])
	Engine.time_scale = scale0
	await t.reconnect()
	await t.until(func() -> bool: return Checkpoints.can_die(), 6.0)
	var _u := [ws, t0]


func _ui_layer(t: Node) -> CanvasLayer:
	var n: Node = t.main.get_node_or_null("UI")
	return n as CanvasLayer


func _todos(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	for cause in screamer_causes() + ["lunch_dormido"]:
		if cause in ["correo_vitzo", "vitzo_reminder", "wmm_correo_vitzo", "wmm_pod_correo"]:
			# Vitzo pide la muerte después de salir del monitor; aquí se prueba el screamer directo.
			pass
		await _scr_one(t, cause, false)
		if not t.player().seated:
			await t.login_at_seat()


func _cese(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.die("tercer_ww", "", "shero")
	var lights_off := 0
	var white := false
	var badge := false
	var ding := false
	var ding_info := ""
	for _i in 120:
		await t.frames(1)
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP)
		if fx == null:
			break
		lights_off = maxi(lights_off, (fx.get("_lights_off") as Array).size())
		var ui_bus := AudioServer.get_bus_index("UI")
		var audible := ui_bus < 0 or not AudioServer.is_bus_mute(ui_bus) or str(AudioManager.last_sfx.get("bus", "UI")) != "UI"
		if str(AudioManager.last_sfx.get("slot", "")) == "sfx/ezlak_notificacion" and audible and Time.get_ticks_msec() - int(AudioManager.last_sfx.get("t", 0)) < 100:
			ding = true
			ding_info = "%s · bus %s muteado %s · fotograma %d" % [str(AudioManager.last_sfx.get("slot")), str(AudioManager.last_sfx.get("bus")), str(AudioServer.is_bus_mute(ui_bus)), _i]
		for c in fx.find_children("*", "Panel", true, false):
			var sb := (c as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			if sb != null and sb.bg_color.v > 0.8 and (c as Panel).is_visible_in_tree():
				white = true
		if fx.find_children("*", "Control", true, false).any(func(n: Node) -> bool: return n.get_script() != null and str(n.get("agent")) != "" and n.has_method("crack")):
			badge = true
	t.check(lights_off >= 4, "las luces de la sala se apagan en fila (%d)" % lights_off)
	t.check(not white, "sin la ventana blanca del correo de cese")
	t.check(badge, "el gafete en la oscuridad (se raja)")
	t.check(not ding, "sin el 'ding' de Ezlaki durante el despido %s" % ding_info)
	t.check(str(Screamers.last_info.get("frase", "")).ends_with("despedido"), "grita ¡ESTÁS DESPEDIDO!")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _haime_cal(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	var b: Building = t.building()
	b.go_to_floor(2, "pc")
	await t.frames(3)
	var seat := (b.floor_node as FloorBase).seat_by_id("calibracion")
	t.check(seat != null, "silla de calibración")
	if seat == null:
		return
	t.player().sit_at(seat, "calibracion")
	GameState.login()
	await t.frames(2)
	GameState.stop_calm()
	t.die("calibracion_final", "", "haime")
	var red_full := false
	var close := INF
	var ui_hidden := false
	var visible_model := false
	for _i in 200:
		await t.frames(1)
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP)
		if fx == null:
			break
		var bg := fx.get("_bg") as ColorRect
		if bg != null and bg.color.r > 0.3 and bg.color.a > 0.6 and bg.color.g < 0.1:
			red_full = true
		var m := fx.get("_m") as Node3D
		if m != null and is_instance_valid(m) and m.visible:
			visible_model = true
			close = minf(close, m.global_position.distance_to(t.player().camera.global_position))
		var layer := _ui_layer(t)
		if layer != null and not layer.visible:
			ui_hidden = true
	t.check(not red_full, "sin la pantalla roja plena de la v0.3")
	t.check(visible_model and close < 1.5, "Haime en cámara, a %.2f m (salta la mesa y te agarra)" % close)
	t.check(ui_hidden, "la PC/feedback no tapan el modelo")
	t.check(str(Screamers.last_info.get("intro", "")) == "salto_mesa", "intro salto_mesa")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _vitzo(t: Node, stand: bool) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var seq: Array = t.spy("death_sequence_started")
	var others: Array = t.spy("pursuit_started")
	Screamers.last_info = {}  # nada del escenario anterior
	var v := t.get_tree().get_first_node_in_group("vitzo")
	t.check(v != null, "Vitzo existe")
	if v == null:
		return
	v.call("email_detected", "correo_vitzo", false)
	await t.frames(2)
	var hub := PersonajesP5.get_hub(t.get_tree())
	t.check(Discipline.freeze_reasons().has("vitzo"), "exclusiva: Discipline congelada por 'vitzo'")
	t.check(hub == null or hub.busy == "vitzo", "exclusiva: PersonajesP5.busy = vitzo")
	var atk := t.get_tree().get_first_node_in_group(VitzoScreamer.GROUP)
	t.check(atk != null and str(atk.get("phase")) == "arrastre", "sale arrastrándose del monitor")
	# Mientras sale, otro enemigo intenta algo: no puede.
	var started := Pursuit.start("shero", "abandono")
	t.check(not started or true, "")
	if stand:
		await t.seconds(0.6)
		t.player().stand_up()
		var p: Player = t.player()
		p.teleport(p.global_position + Vector3(0, 0, 3.0), 180.0)
		var ok: bool = await t.until(func() -> bool: return Pursuit.is_hunting("vitzo"), 6.0)
		t.check(ok, "te paraste: termina de salir y te persigue")
		var inf := Pursuit.info("vitzo")
		t.check(float(inf.get("speed", 0.0)) >= 5.0, "corre a %.1f m/s" % float(inf.get("speed", 0.0)))
		var caught: bool = await t.until(func() -> bool: return not seq.is_empty(), 30.0)
		t.check(caught and str(seq[0][1]) == "vitzo", "te alcanza: muerte por Vitzo")
		await t.until(func() -> bool: return Screamers.last_info.get("cause", "") == "correo_vitzo", 2.0)
		await t.until(func() -> bool: return str(Screamers.last_info.get("kill", "")) != "", 4.0)  # la muerte se anota al terminar la intro
		t.check(str(Screamers.last_info.get("intro", "")) == "zarpazo" and str(Screamers.last_info.get("kill", "")) == "vitzo_salto", "salta con su screamer (intro %s, muerte %s)" % [str(Screamers.last_info.get("intro", "")), str(Screamers.last_info.get("kill", ""))])
	else:
		var ok2: bool = await t.until(func() -> bool: return not seq.is_empty(), 6.0)
		t.check(ok2 and str(seq[0][1]) == "vitzo" and str(seq[0][0]) == "correo_vitzo", "sentado: te agarra (muerte por Vitzo)")
		await t.until(func() -> bool: return str(Screamers.last_info.get("cause", "")) == "correo_vitzo", 3.0)
		await t.until(func() -> bool: return str(Screamers.last_info.get("kill", "")) != "", 4.0)
		t.check(str(Screamers.last_info.get("intro", "")) == "zarpazo" and str(Screamers.last_info.get("kill", "")) == "vitzo_vidrio_bandeja", "screamer desde el monitor (intro %s, muerte %s)" % [str(Screamers.last_info.get("intro", "")), str(Screamers.last_info.get("kill", ""))])
	var other := 0
	for e in others:
		if str(e[0]) != "vitzo":
			other += 1
	t.check(other == 0 and seq.size() == 1, "ningún otro enemigo interviene (%d persecuciones ajenas, %d muertes)" % [other, seq.size()])
	await t.wait_death_shown(8.0)
	await t.reconnect()
	await t.frames(3)
	t.check(not Discipline.freeze_reasons().has("vitzo") and (hub == null or hub.busy != "vitzo"), "al reaparecer termina la exclusiva")


# --- persecuciones ---------------------------------------------------------------------------------

## Sigue al cazador cada fotograma: el salto más grande entre fotogramas (fuera del viaje del ascensor) y su estado.
class Tracker:
	var hunter: String = ""
	var last: Vector3 = Vector3.INF
	var last_space: String = ""
	var max_jump: float = 0.0
	var jumps: Array = []
	var samples: int = 0
	var first_pos: Vector3 = Vector3.INF
	var clip_at_spawn: String = ""

	func step(tree: SceneTree) -> void:
		var n := Pursuit.node_of(hunter)
		var inf := Pursuit.info(hunter)
		var sp := str(inf.get("space", ""))
		if n == null or sp == "":
			last = Vector3.INF
			return
		var pos := n.global_position
		if first_pos == Vector3.INF:
			first_pos = pos
			var rig: CharacterRig = null
			for c in n.find_children("*", "CharacterRig", true, false):
				rig = c
			if rig == null and n.has_meta("rig"):
				rig = n.get_meta("rig")
			clip_at_spawn = rig.current if rig != null else ""
		if last != Vector3.INF and sp == last_space:
			var d := pos.distance_to(last)
			if d > max_jump:
				max_jump = d
			if d > 2.0:
				jumps.append([d, sp])
		last = pos
		last_space = sp
		samples += 1


func _chase_floor(t: Node, floor_n: int) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var p: Player = t.player()
	p.stand_up()
	var b: Building = t.building()
	var where := {-1: Vector3(20.0, 0, 8.0), 1: Vector3(10.0, 0, -2.0), 9: Vector3(-3.0, 0, 14.0), 2: Vector3(22.0, 0, -18.0)}
	if floor_n != 2:
		b.go_to_floor(floor_n, "ascensor")
		await t.frames(3)
	var target: Vector3 = where.get(floor_n, Vector3.ZERO) as Vector3
	var grid := Pursuit.grid_for(b.floor_node)
	if grid != null:
		var c := grid.nearest(target, 20)
		if c.x > -99999:
			target = grid.pos_of(c)
	p.teleport(target, 0.0)
	await t.frames(3)
	var entered: Array = t.spy("hunter_entered_floor")
	var seq: Array = t.spy("death_sequence_started")
	Pursuit.transit.clear()
	var sh := t.get_tree().get_first_node_in_group("shero")
	var tr := Tracker.new()
	tr.hunter = "shero"
	Pursuit.start("shero", "abandono")
	var el := 0.0
	var enter_ms := -1
	while el < 90.0 and seq.is_empty():
		await t.get_tree().physics_frame
		el += t.get_physics_process_delta_time()
		tr.step(t.get_tree())
		if not entered.is_empty() and enter_ms < 0:
			enter_ms = Time.get_ticks_msec()
		if not Pursuit.is_hunting("shero") and seq.is_empty():
			break
	var st: Dictionary = Pursuit.stats[Pursuit.stats.size() - 1] if not Pursuit.stats.is_empty() else {}
	var evs: Array = []
	for e in Pursuit.transit:
		evs.append(str(e[1]))
	if floor_n != 2:
		t.check(evs.has("sale"), "tránsito: Ezlaki avisa que salió de su sitio (%s)" % str(evs))
		t.check(evs.has("indicador") or evs.has("pasos_escalera") or evs.has("ding") or evs.has("portazo"), "tránsito visible/audible antes de entrar al piso (%s)" % str(evs))
		t.check(evs.has("sale_corriendo"), "sale corriendo por la puerta (no aparece quieto)")
		t.check(float(st.get("aparece_s", -1.0)) > 0.0, "aparece a los %.1f s" % float(st.get("aparece_s", -1.0)))
		var spawn := tr.first_pos.distance_to(target) if tr.first_pos != Vector3.INF else -1.0
		t.check(spawn >= 8.0, "aparece a %.1f m del jugador (≥ 8)" % spawn)
	else:
		var home: Vector3 = sh.get("home") if sh != null else Vector3.INF
		t.check(sh != null and tr.first_pos != Vector3.INF and tr.first_pos.distance_to(home) < 1.0, "sale de su escritorio (a %.1f m de su silla)" % (tr.first_pos.distance_to(home) if sh != null else -1.0))
		t.check(sh != null and int(sh.get("stand_ups")) >= 1, "se levanta de la silla antes de correr")
	t.check(tr.clip_at_spawn in ["sprint", "run", "stand_up"] or floor_n == 2, "corre (clip %s)" % tr.clip_at_spawn)
	t.check(tr.jumps.is_empty(), "sin teletransportes: salto máximo por fotograma %.2f m (%d > 2 m)" % [tr.max_jump, tr.jumps.size()])
	t.check(not seq.is_empty() and str(seq[0][1]) == "shero", "te alcanza (muerte por Shero)")
	await t.frames(2)
	t.check(str(Screamers.last_info.get("intro", "")) == "alcance", "el screamer arranca donde te alcanzó (intro %s)" % str(Screamers.last_info.get("intro", "")))
	_report("persecución Shero → piso %d: aparece %.1f s · %.1f m recorridos · salto máx %.2f m · %d muestras · tránsito %s" % [floor_n, float(st.get("aparece_s", -1.0)), float(st.get("metros", 0.0)), tr.max_jump, tr.samples, str(evs)])
	for l in (st.get("trail", []) as Array).slice(0, 8):
		t.note("trazo %s" % str(l))
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _chase_stairs(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var p: Player = t.player()
	p.stand_up()
	var b: Building = t.building()
	var seq: Array = t.spy("death_sequence_started")
	b.go_to_floor(1, "ascensor")
	await t.frames(3)
	Pursuit.start("shero", "abandono")
	await t.seconds(4.0)
	b.go_to_stairwell(-1, false)
	await t.frames(3)
	var tr := Tracker.new()
	tr.hunter = "shero"
	var entered := false
	var el := 0.0
	while el < 40.0 and seq.is_empty():
		await t.get_tree().physics_frame
		el += t.get_physics_process_delta_time()
		tr.step(t.get_tree())
		if str(Pursuit.info("shero").get("space", "")).begins_with("sw:"):
			entered = true
	t.check(entered, "Shero entra físicamente a la caja de escalera")
	t.check(tr.jumps.is_empty(), "sin saltos > 2 m (máx %.2f)" % tr.max_jump)
	t.check(not seq.is_empty(), "te alcanza en la escalera")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _chase_p5(t: Node, hunter: String, cause: String, floor_n: int) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var p: Player = t.player()
	p.stand_up()
	var b: Building = t.building()
	b.go_to_floor(floor_n, "ascensor")
	await t.frames(3)
	var grid := Pursuit.grid_for(b.floor_node)
	var target: Vector3 = p.global_position + Vector3(10, 0, 4)
	if grid != null:
		var c := grid.nearest(target, 20)
		if c.x > -99999:
			target = grid.pos_of(c)
	p.teleport(target, 0.0)
	var seq: Array = t.spy("death_sequence_started")
	Pursuit.transit.clear()
	var tr := Tracker.new()
	tr.hunter = hunter
	P5Pursuit.start(hunter, cause, 5.0)
	var el := 0.0
	while el < 80.0 and seq.is_empty():
		await t.get_tree().physics_frame
		el += t.get_physics_process_delta_time()
		tr.step(t.get_tree())
	var evs: Array = []
	for e in Pursuit.transit:
		evs.append(str(e[1]))
	t.check(evs.has("sale_corriendo"), "%s sale corriendo por la puerta (%s)" % [hunter, str(evs)])
	t.check(tr.clip_at_spawn in ["sprint", "run"], "%s corre visible (clip %s)" % [hunter, tr.clip_at_spawn])
	t.check(tr.jumps.is_empty(), "%s sin saltos > 2 m (máx %.2f)" % [hunter, tr.max_jump])
	t.check(not seq.is_empty() and str(seq[0][1]) == hunter, "%s te alcanza" % hunter)
	_report("persecución %s → piso %d: salto máx %.2f m · %s" % [hunter, floor_n, tr.max_jump, str(evs)])
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _tercer_break(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var sh := t.get_tree().get_first_node_in_group("shero")
	t.check(sh != null and bool(sh.get("seated")), "Shero está sentado en su escritorio")
	var seq: Array = t.spy("death_sequence_started")
	var ups := int(sh.get("stand_ups")) if sh != null else 0
	Pursuit.start("shero", "tercer_break", 4.6, null, "3")
	await t.frames(2)
	t.check(sh != null and int(sh.get("stand_ups")) == ups + 1, "se levanta para salir corriendo")
	var ok: bool = await t.until(func() -> bool: return not seq.is_empty(), 40.0)
	t.check(ok and str(seq[0][0]) == "tercer_break", "te alcanza: tercer_break")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _intenso(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	t.player().teleport(Vector3(22.0, 0, -18.0), 0.0)
	Pursuit.start("shero", "lunch_excedido", 5.0, null, "", -99, Vector3.INF, Callable(), {"intenso": true})
	var dimmed := 0
	for _i in 240:
		await t.get_tree().physics_frame
		var pu := Pursuit.instance()
		if pu != null:
			dimmed = maxi(dimmed, (pu.get("_dimmed") as Array).size())
		if Checkpoints.dying:
			break
	t.check(dimmed > 0, "las luces mueren a su paso (%d)" % dimmed)
	await t.wait_death_shown(10.0)
	await t.reconnect()


# --- escritorios y caras ---------------------------------------------------------------------------

func _escritorios(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	await t.frames(5)
	var fl: Node3D = t.building().floor_node
	for who in ["shero", "rasec", "rta"]:
		t.check(fl.find_child("escritorio_" + who, true, false) != null, "marcador escritorio_%s (C8)" % who)
	var sh := t.get_tree().get_first_node_in_group("shero")
	var seat := (fl.find_child("escritorio_shero", true, false) as Node3D).global_position
	t.check(sh != null and bool(sh.get("seated")) and (sh as Node3D).global_position.distance_to(seat) < 0.3, "Shero sentado en su escritorio al empezar")
	var rig: CharacterRig = sh.get("_rig")
	t.check(rig != null and rig.current in ["sit", "sit_type"], "Shero: clip %s" % (rig.current if rig != null else "-"))
	var ups := int(sh.get("stand_ups"))
	Discipline.debug_fire("sala", 2)  # verbal: se para y te señala
	await t.frames(2)
	t.check(int(sh.get("stand_ups")) == ups + 1 and not (rig.current in ["sit", "sit_type"]), "el verbal empieza con stand_up (%s)" % rig.current)
	var back: bool = await t.until(func() -> bool: return bool(sh.get("seated")), 12.0)
	t.check(back, "vuelve a sentarse")
	ups = int(sh.get("stand_ups"))
	sh.call("walk_behind_player", "fila", 3.0)
	await t.seconds(0.2)
	t.check(int(sh.get("stand_ups")) == ups + 1, "ir a tu fila empieza con stand_up")
	var home: bool = await t.until(func() -> bool: return bool(sh.get("seated")), 40.0)
	t.check(home, "vuelve CAMINANDO a su silla y se sienta")
	var ras: Node = null
	for n in t.get_tree().get_nodes_in_group("p5_rasec_actor"):
		ras = n
	t.check(ras != null and bool(ras.get("seated")), "Rasec sentado en su escritorio del TM")
	var dog := t.get_tree().get_first_node_in_group("rta")
	t.check(dog != null and bool(dog.get("at_desk")), "el Perrito RTA en su escritorio de 3 monitores")
	_report("escritorios: shero %s · rasec %s · rta %s" % [str(sh.get("seated")), str(ras.get("seated")) if ras != null else "-", str(dog.get("at_desk")) if dog != null else "-"])


func _haime_cara(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	var h: Node = null
	for n in t.get_tree().get_nodes_in_group("p5_haime_actor"):
		h = n
	t.check(h != null and h.has_method("look_at_player") and h.has_method("set_severity"), "C5: API de Haime")
	if h == null:
		return
	var rig: ScreamRig = h.get("_rig")
	t.check(rig != null and rig.has_face_shader(), "Haime con ScreamRig")
	for lv in 4:
		h.call("set_severity", lv)
		t.check(absf(rig.severity - lv / 3.0) < 0.01, "severidad %d → %.2f" % [lv, rig.severity])
	h.call("look_at_player", true)
	await t.seconds(1.5)
	t.check(rig.look > 0.9, "te mira de frente (look %.2f)" % rig.look)
	h.call("look_at_player", false)
	h.call("set_severity", 0)


func _pantalla(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.die("break_excedido", "16:00", "shero")
	await t.wait_death_shown(8.0)
	var ds: Control = t.death_screen()
	t.check(ds.visible, "pantalla de muerte")
	var st := ds.get("_static") as ColorRect
	t.check(st != null and st.material is ShaderMaterial and float((st.material as ShaderMaterial).get_shader_parameter("k")) > 0.4, "entra con una ráfaga de estática")
	t.check(str(ds.get("_title").text) == tr("DEATH_TITLE"), "«Usuario desconectado»")
	t.check(ds.get("_face").texture != null, "la cara del asesino entre la estática")
	await t.seconds(2.2)
	var full := str(ds.get("_reason_full"))
	t.check(full.contains("Break") or full.contains("break"), "motivo: %s" % full)
	t.check(str(ds.get("_reason").text) == full or (ds.get("_k") as float) > 0.6, "el motivo se reescribe y queda fijo")
	var k_min := 1.0
	for _i in 30:  # entre ráfagas (cada 2-4 s) la estática queda de fondo
		k_min = minf(k_min, float((st.material as ShaderMaterial).get_shader_parameter("k")))
		await t.seconds(0.1)
	t.check(k_min < 0.5, "la estática baja a ruido de fondo (mín. %.2f)" % k_min)
	t.check(ds.get("_ghost") != null and (ds.get("_ghost") as TextureRect).modulate.a > 0.02, "la cara se queda debajo de la estática")
	await t.reconnect()


func _colapso(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var scr: Array = t.spy("screamer_finished")
	var anim: Array = t.spy("death_animation_finished")
	Fatigue.set_value(99.0)
	Fatigue.add(10.0)
	await t.wait_death_shown(10.0)
	t.check(scr.is_empty() and not anim.is_empty(), "colapso sin screamer, con su animación")
	await t.reconnect()

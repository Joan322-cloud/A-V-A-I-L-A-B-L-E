## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P2 · mundo y presentación (PLAN §8, §10 P2): screamers por causa (duración de la tabla,
## screamer antes de la pantalla, Shero calvo, Rasec), colapso sin screamer, marcadores para P3/P5,
## dormir (SleepSpot), dispensador de la sala, puerta del deck, comportamientos por piso, la sesión en
## otra fila sin castigo de isla, Konzentramance, lluvia barata y bus.


func escenarios() -> Array[String]:
	return ["screamers", "screamer_shero_calvo", "screamer_rasec", "colapso_animacion", "marcadores_p2", "dormir_sleepspot", "dispensador_sala", "puerta_azotea", "comportamientos", "sesion_otra_fila", "konzentramance", "lluvia_barata", "bus"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"screamers": await _screamers(t)
		"screamer_shero_calvo": await _shero_calvo(t)
		"screamer_rasec": await _rasec(t)
		"colapso_animacion": await _colapso(t)
		"marcadores_p2": await _marcadores(t)
		"dormir_sleepspot": await _dormir(t)
		"dispensador_sala": await _dispensador(t)
		"puerta_azotea": await _azotea(t)
		"comportamientos": await _comportamientos(t)
		"sesion_otra_fila": await _sesion_otra_fila(t)
		"konzentramance": await _konzentramance(t)
		"lluvia_barata": await _lluvia(t)
		"bus": await _bus(t)


## Mide (en tiempo de juego escalado) de death_sequence_started a screamer_finished.
func _timed_death(t: Node, cause: String, killer: String = "") -> Dictionary:
	var out := {"screamer": -1.0, "anim": -1.0, "shown_after": false, "killer": ""}
	var state := {"t": 0.0, "scr": false, "anim": false, "shown": false, "scr_at": -1.0, "anim_at": -1.0, "shown_at": -1.0}
	var f_scr := func(_c: String) -> void:
		state["scr"] = true
		state["scr_at"] = state["t"]
	var f_anim := func(_c: String) -> void:
		state["anim"] = true
		state["anim_at"] = state["t"]
	var f_shown := func(_c: String) -> void:
		state["shown"] = true
		state["shown_at"] = state["t"]
	var f_seq := func(_c: String, k: String, _d: String) -> void:
		out["killer"] = k
	EventBus.screamer_finished.connect(f_scr)
	EventBus.death_animation_finished.connect(f_anim)
	EventBus.death_shown.connect(f_shown)
	EventBus.death_sequence_started.connect(f_seq)
	t.die(cause, "61", killer)
	# La espera sigue a la tabla: la fusión de Vitzo dura 22,9 s (v0.3.2) y con 12 s fijos la prueba la cortaba a la mitad.
	var cap := 12.0
	if Screamers.has_row(cause):
		cap = maxf(cap, Screamers.duration(killer if killer != "" else Checkpoints.killer_of(cause), cause) + 6.0)
	var waited := 0.0
	while not bool(state["shown"]) and waited < cap:
		await t.get_tree().process_frame
		var dt: float = t.get_process_delta_time()
		state["t"] = float(state["t"]) + dt
		waited += dt
	EventBus.screamer_finished.disconnect(f_scr)
	EventBus.death_animation_finished.disconnect(f_anim)
	EventBus.death_shown.disconnect(f_shown)
	EventBus.death_sequence_started.disconnect(f_seq)
	out["screamer"] = float(state["scr_at"]) if bool(state["scr"]) else -1.0
	out["anim"] = float(state["anim_at"]) if bool(state["anim"]) else -1.0
	out["shown"] = bool(state["shown"])
	var before: float = float(state["scr_at"]) if bool(state["scr"]) else float(state["anim_at"])
	out["shown_after"] = bool(state["shown"]) and before >= 0.0 and float(state["shown_at"]) >= before
	return out


## Todas las causas con asesino: fila en screamers.json, screamer → pantalla, duración ±0,2 s.
func _screamers(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var n := 0
	for c in DataLoader.list("muertes"):
		var cause := str(c.get("id", ""))
		var killer := str(c.get("quien", ""))
		if not Checkpoints.uses_screamer(killer):
			continue
		n += 1
		t.check(Screamers.has_row(cause), "screamers.json tiene fila para '%s'" % cause)
		var expected := Screamers.duration(killer, cause)
		GameState.stop_calm()  # tras cada muerte hay calma (las causas que la respetan no matan)
		var r: Dictionary = await _timed_death(t, cause)
		t.check(float(r["screamer"]) > 0.0 and float(r["anim"]) < 0.0, "%s: screamer (no animación de colapso)" % cause)
		t.check(bool(r["shown_after"]), "%s: 'Usuario desconectado' después de screamer_finished" % cause)
		var late := float(Screamers.last_info.get("grito_tarde", 0.0))  # v0.3.2: la frase no se corta (el final se corre)
		# kills2: se mide con el reloj del propio screamer (delta sumado: no depende de los fps ni de la carga; con el
		# editor sin tope de fps el cronómetro de pared dio 22,62 s contra 22,90) y contra lo que el screamer se propuso
		# durar: la fila, salvo las que se ajustan a su toma (la fusión: el grito y el reminder de cada agente; las filas
		# con accion_s: el Trainer y el Perrito), que nunca pasan de la tabla. Holgura: +0,25 s (cubre un cuadro largo a
		# 30 fps con el reloj a 2x) y -0,05 s.
		var plan := float(Screamers.last_info.get("duracion", expected))
		var own := float(Screamers.last_info.get("duracion_real", float(r["screamer"])))
		t.check(own - late - plan <= 0.25 and own - late - plan >= -0.05, "%s: duración %.2f s por su reloj (se propuso %.2f; tabla %.2f; cronómetro %.2f)" % [cause, own, plan, expected, float(r["screamer"])])
		t.check(plan <= expected + 0.02, "%s: no pasa de la tabla (%.2f ≤ %.2f)" % [cause, plan, expected])
		await t.reconnect()
		await t.until(func() -> bool: return Checkpoints.can_die(), 6.0)
		if not t.player().seated:
			await t.login_at_seat()
	t.note("%d causas con screamer" % n)
	Engine.time_scale = 8.0


## En TODO screamer de Shero el modelo sale calvo (nodo Afro oculto) y la cara es la calva.
func _shero_calvo(t: Node) -> void:
	Engine.time_scale = 1.0
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	var shero_causes: Array[String] = []
	for c in DataLoader.list("muertes"):
		if str(c.get("quien", "")) == "shero":
			shero_causes.append(str(c.get("id", "")))
	for cause in shero_causes:
		var row := Screamers.row_for("shero", cause)
		t.check(str(row.get("look", "")) == "calvo" or str(row.get("variante", "")) == "cese", "%s: look calvo en screamers.json" % cause)
		t.check(str(row.get("cara", "")).begins_with("shero_calvo"), "%s: cara calva (%s)" % [cause, str(row.get("cara", ""))])
	# Uno en vivo: el modelo instanciado no muestra el afro.
	t.die("break_excedido", "16:00")
	var seen := false
	var afro_hidden := false
	for _i in 40:
		await t.frames(1)
		var m := t.get_tree().root.find_child("Asesino_shero", true, false)
		if m != null:
			seen = true
			var afro := m.find_child("Afro", true, false) as Node3D
			afro_hidden = afro == null or not afro.is_visible_in_tree()
			if afro != null:
				break
	t.check(seen, "el screamer de break_excedido instancia a Shero frente a la cámara")
	t.check(afro_hidden, "Shero sale calvo (nodo Afro oculto)")
	await t.wait_death_shown(6.0)
	await t.reconnect()
	Engine.time_scale = 8.0


## Rasec: coaching_sin_permiso/coaching_exceso/rasec_evento; 'coaching' convocado por Rasec usa su fila.
func _rasec(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	for cause in ["coaching_sin_permiso", "coaching_exceso", "rasec_evento"]:
		t.check(Checkpoints.killer_of(cause) == "rasec", "%s: asesino rasec en muertes.json" % cause)
		t.check(str(Screamers.row_for("rasec", cause).get("asesino", "")) == "rasec", "%s: fila de Rasec en screamers.json" % cause)
	var row := Screamers.row_for("rasec", "coaching")
	t.check(str(row.get("asesino", "")) == "rasec" and str(row.get("cara", "")) == "rasec", "coaching convocado por Rasec → screamer de Rasec (coaching@rasec)")
	t.check(str(Screamers.row_for("shero", "coaching").get("asesino", "")) == "shero", "coaching de Shero → screamer de Shero")
	GameState.stop_calm()
	var r: Dictionary = await _timed_death(t, "coaching", "rasec")
	t.check(str(r["killer"]) == "rasec" and float(r["screamer"]) > 0.0, "muerte 'coaching' con asesino rasec pasa por su screamer")
	await t.reconnect()


## Colapso: animación sin screamer (3-4,5 s), sentado y de pie; la cámara cae.
func _colapso(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	var r: Dictionary = await _timed_death(t, "colapso")
	# v0.3.2e (kills, pedido de Joan): el colapso es en tercera persona desde el primer cuadro y dura 5,4 s (actuado de
	# cuerpo entero + cierre lento); tu cámara ya no cae sobre el teclado: se ve a tu agente desplomarse.
	t.check(float(r["anim"]) >= 3.0 and float(r["anim"]) <= 5.9 and float(r["screamer"]) < 0.0, "colapso sentado: animación %.2f s sin screamer" % float(r["anim"]))
	t.check(bool(r["shown_after"]), "pantalla después de death_animation_finished")
	t.check(bool(DeathAnimations.last_info.get("tercera_persona", false)) and bool(DeathAnimations.last_info.get("sentado", false)),
		"sentado: tercera persona, tu agente se desploma sobre el escritorio (clip %s)" % str(DeathAnimations.last_info.get("anim", "")))
	await t.reconnect()
	await t.frames(3)
	t.check(t.player().head.position.y > 1.0 and absf(t.player().camera.rotation.z) < 0.01, "al reconectar la cámara vuelve a su sitio")
	t.player().stand_up()
	await t.until(func() -> bool: return Checkpoints.can_die(), 6.0)
	r = await _timed_death(t, "colapso")
	t.check(float(r["anim"]) >= 3.0 and float(r["screamer"]) < 0.0, "colapso de pie: animación sin screamer")
	t.check(bool(DeathAnimations.last_info.get("tercera_persona", false)) and not bool(DeathAnimations.last_info.get("sentado", true)),
		"de pie: tercera persona, tu agente cae al suelo (clip %s)" % str(DeathAnimations.last_info.get("anim", "")))
	await t.reconnect()
	Engine.time_scale = 8.0


## Marcadores para P3 (Pursuit) y P5 en cada piso.
func _marcadores(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var want := {-1: ["ascensor", "escalera", "calle", "descanso_m1", "fermin_puesto", "revision_jugador", "cafeteria"], 1: ["ascensor", "escalera", "training_sala2", "topico"], 2: ["ascensor", "escalera", "sala_calibracion", "haime_sitio", "evento_rasec", "dispensador_sala", "pc", "shero_sitio"], 9: ["ascensor", "escalera", "cafeteria_azotea"]}
	for f in want.keys():
		t.building().go_to_floor(int(f), "ascensor")
		await t.frames(3)
		var fl: Node3D = t.building().floor_node
		for m in want[f]:
			t.check(fl.find_child(str(m), true, false) is Marker3D, "piso %d: marcador '%s'" % [int(f), str(m)])
	t.building().go_to_floor(1, "ascensor")
	await t.frames(3)
	var seats := 0
	for n in t.building().floor_node.find_children("Seat_training_sala2_*", "", true, false):
		if n is WorldObjects.TrainingSeat:
			seats += 1
	t.check(seats == 4, "sala 2 de training con 4 asientos (%d)" % seats)


## Dormir: puff del -1 → slept + reloj 30x + Fatiga baja; [E] despierta → woke.
func _dormir(t: Node) -> void:
	var slept: Array = t.spy("player_slept")
	var woke: Array = t.spy("player_woke")
	await t.start_shift("Jiroshi", 1)
	GameState.login()
	t.building().go_to_floor(-1, "descanso_m1")
	await t.frames(3)
	var spots := t.get_tree().get_nodes_in_group("sleep_spots")
	t.check(spots.size() >= 6, "sofás + puffs para dormir en el -1 (%d)" % spots.size())
	var puff: SleepSpot = null
	for s in spots:
		if (s as SleepSpot).spot_id == "puff_0":
			puff = s
	if puff == null:
		t.fail("no hay puff_0")
		return
	Fatigue.set_value(70.0)
	var local := {"n": 0}
	puff.slept.connect(func(_id: String) -> void: local["n"] = int(local["n"]) + 1)
	puff.interact(t.player())
	await t.seconds(1.2)
	t.check(slept.size() == 1 and str(slept[0][0]) == "puff_0" and int(local["n"]) == 1, "SleepSpot.slept y EventBus.player_slept('puff_0')")
	t.check(GameState.clock_override == "dormido" and SleepSpot.sleeping_spot() == "puff_0", "reloj 'dormido' (30x) mientras duermes")
	t.check(t.player().lying and t.player().head.position.y < 1.0, "vista acostada")
	var c0 := GameState.clock_seconds
	await t.seconds(4.0)
	t.check(GameState.clock_seconds - c0 > 100.0, "el reloj corre rápido dormido (+%.0f s de juego)" % (GameState.clock_seconds - c0))
	t.check(Fatigue.value < 70.0, "la Fatiga baja durmiendo (%.1f)" % Fatigue.value)
	puff.interact(t.player())
	await t.frames(3)
	t.check(woke.size() == 1 and not t.player().lying and GameState.clock_override == "", "[E] despierta: player_woke, de pie, reloj normal")
	t.check(t.player().global_position.y > -0.5, "de pie sobre el piso")


## Dispensador dentro de la sala: Fatiga −2, no saca al jugador de la sala, ningún paso de disciplina.
func _dispensador(t: Node) -> void:
	var steps: Array = t.spy("discipline_step")
	var exited: Array = t.spy("room_exited")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	await t.frames(4)
	t.check(GameState.in_room, "sentado en C-14 sigues dentro de la sala (in_room)")
	var fl: Node3D = t.building().floor_node
	var disp := fl.find_child("DispensadorSala", true, false) as WorldObjects.WaterCooler
	t.check(disp != null, "existe DispensadorSala en el piso 2")
	if disp == null:
		return
	t.player().stand_up()
	t.player().teleport(fl.global_position + Vector3(22.0, 0, 0.4), 0.0)
	await t.frames(6)
	t.check(GameState.in_room, "junto al dispensador sigues dentro de la sala")
	Fatigue.set_value(50.0)
	disp.interact(t.player())
	await t.frames(2)
	t.check(is_equal_approx(Fatigue.value, 50.0 - 2.0 * Difficulty.fatigue_rate("recuperacion")), "Fatiga −2 × recuperación de la dificultad (v0.3.2) (%.1f)" % Fatigue.value)
	t.check(steps.is_empty() and exited.is_empty(), "no dispara nada (pasos %d, salidas %d)" % [steps.size(), exited.size()])


## Puerta del deck: v0.3.1 Q5 (B10) la azotea está abierta 24/7: abre también en Available; desde el deck siempre abre.
func _azotea(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	t.player().stand_up()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	t.building().go_to_floor(9, "ascensor")
	await t.frames(3)
	var door := t.building().floor_node.find_child("PuertaAzotea", true, false) as WorldObjects.Door
	t.player().teleport(t.building().floor_node.global_position + Vector3(0, 0, 0.8), 180.0)
	await t.frames(2)
	t.check(door != null and door.interact(t.player()) and door.open, "en Available la puerta del deck abre (azotea 24/7)")
	door.set_open(false)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "en Break abre")
	await t.frames(3)
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 1.0, 0.6)
	q.shape = bs
	q.transform = Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, -0.2, 0))
	q.collision_mask = 1
	q.exclude = [t.player().get_rid()]
	var hits: Array = t.player().get_world_3d().direct_space_state.intersect_shape(q, 8)
	var names: Array[String] = []
	for h in hits:
		names.append(str((h["collider"] as Node).get_path()))
	t.check(hits.is_empty(), "por la puerta abierta se pasa (choca con %s)" % str(names))
	for z in [2.6, 3.0, 3.4, 4.0]:
		q.transform = Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, -0.4, z - 2.0))
		var hz: Array = t.player().get_world_3d().direct_space_state.intersect_shape(q, 8)
		var nz: Array[String] = []
		for h in hz:
			nz.append(str((h["collider"] as Node).get_path()))
		t.check(hz.is_empty(), "deck libre en z=%.1f (choca con %s)" % [z, str(nz)])
	door.set_open(false)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "en Lunch abre")
	door.set_open(false)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	t.player().teleport(t.building().floor_node.global_position + Vector3(0, 0, 3.2), 0.0)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "desde el deck siempre se puede volver a entrar")
	var fl: Node3D = t.building().floor_node
	t.check(fl.find_child("MicroondasAzotea", true, false) is WorldObjects.Microwave, "cafetería al aire libre con microondas")
	# v0.3.1 Q4 (F15): el taper se calienta (60 s de juego), se saca y se come.
	GameState.flags["lunch_in_hand"] = true
	var mw := fl.find_child("MicroondasAzotea", true, false) as WorldObjects.Microwave
	mw.interact(t.player())
	await t.advance_clock(70.0)
	await t.frames(3)
	WorldObjects.TaperFlow.bot_step(t.player())
	WorldObjects.TaperFlow.bot_step(t.player())
	t.check(bool(GameState.flags.get("lunch_eaten", false)), "comer en la azotea cuenta como lunch completo")


## Gancho de comportamientos: con el script presente se instancia y recibe setup_behaviour; sin él, nada.
func _comportamientos(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var real: Dictionary = DataLoader.dict("comportamientos")
	t.check((real.get("pisos", {}) as Dictionary).has("-1"), "comportamientos.json con pisos")
	t.building().go_to_floor(-1, "ascensor")
	await t.frames(3)
	var fl := t.building().floor_node as FloorBase
	var expected_real := 1 if ResourceLoader.exists("res://scripts/personajes/guardia.gd") else 0
	t.check(fl.behaviours().size() == expected_real, "sin guardia.gd (P5) no se instancia nada (%s)" % str(fl.behaviours()))
	DataLoader._cache["comportamientos"] = {"pisos": {"-1": [{"id": "prueba", "script": "res://scripts/dev/fixtures/comportamiento_prueba.gd", "marcador": "fermin_puesto"}, {"id": "falta", "script": "res://scripts/personajes/no_existe.gd"}]}}
	t.building().go_to_floor(-1, "ascensor")
	await t.frames(3)
	fl = t.building().floor_node as FloorBase
	var node := fl.get_node_or_null("Comportamiento_prueba")
	t.check(node != null and fl.behaviours() == ["prueba"], "se instancia el comportamiento presente y se ignora el que falta (%s)" % str(fl.behaviours()))
	t.check(node != null and node.get("marker_name") == "fermin_puesto" and node.get("floor_number") == -1, "setup_behaviour(piso, marcador, entrada)")
	DataLoader._cache.erase("comportamientos")


## Distorsión 4 (sesión en otra fila): al sentarte vuelves a C-14 con tu sesión; sin WW de "isla".
func _sesion_otra_fila(t: Node) -> void:
	var ww: Array = t.spy("written_warning_issued")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var fl := t.building().floor_node as FloorBase
	fl.apply_distortion("sesion_otra_fila", {"cliente_en_espera": "0:42"})
	await t.frames(2)
	var e07 := fl.seat_by_id("E-07")
	var c14 := fl.seat_by_id("C-14")
	t.check(e07.has_session and not c14.has_session, "la sesión aparece en E-07")
	t.player().stand_up()
	await t.frames(2)
	t.player().sit_at(e07, "E-07")
	await t.seconds(4.0)
	t.check(c14.has_session and not e07.has_session, "la sesión vuelve a C-14")
	t.check(t.player().seated and t.player().seat_id == "C-14" and GameState.seated_at == "C-14", "y tú estás sentado en C-14 (%s)" % t.player().seat_id)
	await t.advance_clock(20.0 * 60.0)
	await t.frames(3)
	var isla := 0
	for w in ww:
		if str(w[1]) == "isla":
			isla += 1
	t.check(isla == 0, "sin WW de isla por la distorsión (%d)" % isla)


## Konzentramance en la fachada; ni el nombre viejo de la torre ni nombres reales en archivos de P2.
func _konzentramance(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	t.building().go_to_floor(-1, "calle")
	await t.frames(3)
	var fl: Node3D = t.building().floor_node
	var word := ""
	for i in 14:
		var l := fl.find_child("Letra%d" % i, true, false) as Label3D
		if l != null:
			word += l.text
	# v0.3.1 Q5: decisión de Joan, solo la grafía nueva.
	t.check(word == "KONZENTRAMANCE", "letras de la fachada: %s" % word)
	# Las palabras van partidas para que este archivo (y el .pck) no contenga los nombres que la prueba prohíbe.
	var bad := ["te" + "laris", "web" + "help", "1013", "che" + "ro", "hiro" + "shi", "bit" + "so", "en" + "zo", "yau" + "ri"]
	var files := ["res://scripts/niveles/floor_m1.gd", "res://scripts/niveles/floor_02.gd", "res://scripts/niveles/floor_01.gd", "res://scripts/niveles/floor_09.gd", "res://scripts/fx/screamers.gd", "res://scripts/fx/weather.gd", "res://scripts/mundo/bus.gd", "res://scripts/mundo/horror_props.gd", "res://data/screamers.json", "res://localization/strings_p2.csv"]
	for f in files:
		var txt := FileAccess.get_file_as_string(f).to_lower()
		for b in bad:
			var hit := false
			var idx := txt.find(b)
			while idx >= 0:
				# Solo palabra aislada (un nombre dentro de otra palabra, como en «comienzo», no cuenta).
				var before := txt.substr(idx - 1, 1) if idx > 0 else " "
				var after := txt.substr(idx + b.length(), 1)
				if not (before.is_valid_identifier() or before.is_valid_int()) and not (after.is_valid_identifier() or after.is_valid_int()):
					hit = true
					break
				idx = txt.find(b, idx + 1)
			t.check(not hit, "%s sin '%s'" % [f.get_file(), b])


## Lluvia: MultiMesh con shader (sin GPUParticles) y menos gotas en calidad Baja.
func _lluvia(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	t.building().go_to_floor(-1, "calle")
	await t.frames(3)
	var fl: Node3D = t.building().floor_node
	t.check(fl.find_children("*", "GPUParticles3D", true, false).is_empty() and fl.find_children("*", "CPUParticles3D", true, false).is_empty(), "sin sistemas de partículas")
	var rain := fl.find_child("Lluvia", true, false) as Weather
	t.check(rain != null, "hay lluvia en la calle")
	var prev := GfxQuality.level()
	GfxQuality.current = "baja"
	t.check(Weather.drop_count() <= 500, "calidad Baja: %d gotas" % Weather.drop_count())
	GfxQuality.current = "alta"
	t.check(Weather.drop_count() <= 2000, "calidad Alta: %d gotas" % Weather.drop_count())
	GfxQuality.current = prev
	var mmi := rain.find_child("Gotas", true, false) as MultiMeshInstance3D if rain != null else null
	t.check(mmi != null and mmi.multimesh.instance_count == rain.drops, "una sola MultiMesh de gotas")
	# El tope de 4 es del juego base (calidad Baja y Modo liviano: sus propias luces). En Media y Alta el paquete
	# gráfico reparte las sombras entre sus haces con un cupo propio (GfxLights.SHADOW_BUDGET) y eso se mide aparte.
	var q0 := GfxQuality.level()
	var per_level := {}
	for lv in ["baja", q0]:
		GfxQuality.apply(t.get_tree(), lv)
		await t.frames(8)
		await t.seconds(1.2)  # las sombras de los haces entran con fundido
		fl = t.building().floor_node
		var lights := 0
		var added := 0
		for l in fl.find_children("*", "Light3D", true, false):
			if (l as Light3D).shadow_enabled:
				lights += 1
				if GfxLights.is_added(l as Light3D):
					added += 1
		per_level[lv] = [lights, added]
		if lv == "baja":
			t.check(lights <= 4 and added == 0, "luces con sombra en el -1 con el juego base (Baja): %d (del paquete gráfico: %d)" % [lights, added])
		elif lv in ["media", "alta"]:
			var s := clampi(GfxSettings.level("sombras"), 0, 3)
			var budget := int((GfxLights.SHADOW_BUDGET[s] as Array)[1 if GfxSettings.forward() else 0])
			var base_lights: int = int((per_level["baja"] as Array)[0])
			t.check(added <= budget and lights - added <= base_lights, "calidad %s: %d haces con sombra (cupo %d) y %d luces del juego con sombra (en Baja %d)" % [lv, added, budget, lights - added, base_lights])
	GfxQuality.apply(t.get_tree(), q0)
	await t.frames(4)
	t.note("luces con sombra en el -1 [total, del paquete gráfico]: %s" % str(per_level))


## Bus: te deja al llegar y se va; al terminar el turno hay otro esperando.
func _bus(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.frames(3)
	var bus := t.get_tree().get_first_node_in_group("bus") as Bus
	t.check(bus != null and bus.mode == Bus.Mode.LLEGADA, "al empezar el turno el bus de llegada está en el paradero")
	t.check(await t.until(func() -> bool: return t.get_tree().get_first_node_in_group("bus") == null, 20.0), "el bus se va")
	GameState.shift_over = true
	t.building().go_to_floor(-1, "calle")
	await t.frames(3)
	bus = t.get_tree().get_first_node_in_group("bus") as Bus
	t.check(bus != null and bus.mode == Bus.Mode.SALIDA, "a las 08:45 un bus te espera")
	GameState.shift_over = false

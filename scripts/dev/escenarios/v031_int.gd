## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios de la integración v0.3.1 (Q1 × Q2 × Q3 × Q4 × Q5). `--escenario v031_int` corre todos; prefijo int_.
##   int_escalera_otra_puerta  quieto en la puerta por la que entraste a la caja de escalera, Shero entra por la otra
##                             (antes aparecía en tu misma puerta a 0 m)
##   int_persecucion_audio     durante una persecución suenan el latido y el zumbido grabados de Q3
##   int_taper_mesas           los 6 microondas de Q5 reparten estados de Q4 y se come en las mesas de la cafetería
##   int_bolsa_clientes        la bolsa de árboles por turno y dificultad (15-20, solo_dificil fuera de Fácil/Normal)
##   int_musica_espera         la música de espera (en bucle desde Q3) se corta al sacar del hold, al terminar el
##                             contacto y al volver al menú (antes seguía sonando y tapaba la cama de tensión)
##   int_haime_sin_bucle:<dif> la calibración final mata, reapareces en la advertencia, 90 min / bloque siguiente sin
##                             llamadas, una 2.ª muerte solo con una calibración nueva y después solo advertencias
##                             (dif: normal | dificil; sin argumento, normal)
##   int_sustos_sonoros        audio_horror_v2: callados en el T1; en T2/T3 cada susto suena desde donde no miras, con
##                             su tope por turno; nada durante un contacto
##   int_rta_caza_cerca        la caza del Perrito empieza a tu lado: te mira y ladra ~3 s antes de correr (antes
##                             te alcanzaba en el acto, auditoría #20)


func escenarios() -> Array[String]:
	return ["int_escalera_otra_puerta", "int_persecucion_audio", "int_taper_mesas", "int_bolsa_clientes", "int_rta_caza_cerca", "int_musica_espera", "int_haime_sin_bucle", "int_haime_sin_bucle:", "int_sustos_sonoros", "int_haime_trainer"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"int_escalera_otra_puerta": await _stairs_other_door(t)
		"int_persecucion_audio": await _chase_audio(t)
		"int_taper_mesas": await _taper_tables(t)
		"int_bolsa_clientes": await _pool(t)
		"int_rta_caza_cerca": await _rta_close(t)
		"int_musica_espera": await _hold_music(t)
		"int_haime_sin_bucle": await _haime_loop(t, _arg)
		"int_sustos_sonoros": await _scares(t)
		"int_haime_trainer": await _haime_trainer(t)


func _stairs_other_door(t: Node) -> void:
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
	await t.seconds(2.0)
	b.go_to_stairwell(-1, false)
	await t.frames(3)
	var sw := b.floor_node as Stairwell
	t.check(sw != null, "en la caja de escalera")
	if sw == null:
		return
	var mine := (sw.find_child("escalera", true, false) as Node3D).global_position
	var other_m := sw.find_child("escalera_otra", true, false) as Node3D
	t.check(other_m != null, "la caja tiene el marcador de la otra puerta")
	var spawn := Vector3.INF
	var spawn_d := -1.0
	var el := 0.0
	while el < 40.0 and seq.is_empty():
		await t.get_tree().physics_frame
		el += t.get_physics_process_delta_time()
		var inf := Pursuit.info("shero")
		if spawn == Vector3.INF and str(inf.get("space", "")).begins_with("sw:") and inf.has("pos"):
			spawn = inf["pos"]
			spawn_d = float(inf.get("dist", -1.0))
			break
	t.check(spawn != Vector3.INF, "Shero entra a la caja de escalera")
	if spawn != Vector3.INF:
		t.note("jugador en %s · tu puerta %s · Shero aparece en %s a %.1f m" % [str(p.global_position), str(mine), str(spawn), spawn_d])
		t.check(spawn.distance_to(mine) > 2.0, "no aparece en tu misma puerta (a %.1f m de ella)" % spawn.distance_to(mine))
		t.check(other_m != null and spawn.distance_to(other_m.global_position) < 1.5, "entra por la otra puerta de la caja")
		t.check(spawn_d >= 3.0, "aparece a %.1f m de ti (no a 0 m)" % spawn_d)
	await t.until(func() -> bool: return not seq.is_empty(), 40.0)
	t.check(not seq.is_empty(), "igual te alcanza en la escalera")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _chase_audio(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(3)
	var seq: Array = t.spy("death_sequence_started")
	t.check(AudioManager.has_slot("sfx/persecucion_latido_loop", false) and AudioManager.has_slot("sfx/persecucion_drone_loop", false), "existen el latido y el zumbido de Q3")
	Pursuit.start("shero", "abandono")
	var heart: AudioStreamPlayer = Pursuit._inst._heart
	var drone: AudioStreamPlayer = Pursuit._inst._drone
	var ok: bool = await t.until(func() -> bool: return heart != null and heart.playing and drone != null and drone.playing, 20.0)
	t.check(ok, "durante la persecución suenan el latido y el zumbido")
	if ok:
		t.check(heart.stream != null and drone.stream != null, "con el stream grabado (no un tono sintético)")
	await t.until(func() -> bool: return not seq.is_empty(), 90.0)
	await t.wait_death_shown(8.0)
	t.check(not heart.playing and not drone.playing, "al morir se cortan")
	await t.reconnect()


func _taper_tables(t: Node) -> void:
	await t.start_shift("Marko", 1)
	var b: Building = t.building()
	b.go_to_floor(-1, "cafeteria")
	await t.frames(3)
	var fl := b.floor_node
	var mws: Array = []
	for n in t.get_tree().get_nodes_in_group("microondas"):
		if WorldObjects.TaperFlow.floor_of(n as Node) == fl:
			mws.append(n)
	t.check(mws.size() == 6, "6 microondas de Q5 en el -1 (%d)" % mws.size())
	var fridges := 0
	for n in fl.find_children("*", "", true, false):
		if n is WorldObjects.Fridge:
			fridges += 1
	t.check(fridges == 2, "2 refris en el -1, sin duplicado de Q4 (%d)" % fridges)
	if mws.is_empty():
		return
	(mws[0] as WorldObjects.Microwave).hint_text()
	var states := {}
	for m in mws:
		states[str(m.state)] = int(states.get(str(m.state), 0)) + 1
	t.check(int(states.get("fuera", 0)) == 1 and int(states.get("ocupado", 0)) >= 2 and int(states.get("libre", 0)) >= 1, "estados de Q4 en los microondas de Q5 %s" % str(states))
	WorldObjects.TaperFlow.spawn_eat_spots(mws[0])
	var spots: Array = []
	for c in fl.get_children():
		if c is WorldObjects.EatSpot:
			spots.append(c)
	var at_table := 0
	var tables := WorldObjects.TaperFlow.cafe_tables(fl)  # v0.3.2: Mesa<n> y las mesas bajas de los sillones
	for s in spots:
		for c in tables:
			if (c as Node3D).global_position.distance_to((s as Node3D).global_position) < 0.5:
				at_table += 1
				break
	t.check(spots.size() >= 4 and at_table == spots.size(), "%d sitios para comer, %d en mesas de la cafetería" % [spots.size(), at_table])
	await t.back_to_menu()


func _pool(t: Node) -> void:
	var want := {1: [15, 16], 2: [16, 17], 3: [18, 20]}
	for tn in [1, 2, 3]:
		for lvl in [Difficulty.Level.NORMAL, Difficulty.Level.DIFICIL]:
			await t.start_shift("Llauri", tn, 0, lvl)
			var cm := t.main.get("contacts") as ContactManager
			var d := DataLoader.dict("contactos_t%d" % tn)
			var n := 0
			for c in d.get("contactos", []) + d.get("relleno", []):
				if (c as Dictionary).has("nodos") and ContactManager.eligible(c):
					n += 1
			var expected: int = (want[tn] as Array)[0 if lvl == Difficulty.Level.NORMAL else 1]
			t.check(n == expected, "T%d %s: bolsa de %d árboles distintos (esperado %d)" % [tn, Difficulty.id(lvl), n, expected])
			var leak := false
			for id in cm._planned_scripted:
				for c in d.get("contactos", []):
					if str((c as Dictionary).get("id", "")) == str(id) and not ContactManager.eligible(c):
						leak = true
			t.check(not leak, "T%d %s: el sorteo no saca árboles fuera de su dificultad" % [tn, Difficulty.id(lvl)])
	await t.back_to_menu()


func _rta_close(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var p: Player = t.player()
	p.stand_up()
	await t.frames(3)
	var rta: Node3D = null
	for n in t.get_tree().get_nodes_in_group("rta"):
		if n is Node3D and t.building().floor_node.is_ancestor_of(n):
			rta = n
	t.check(rta != null, "el Perrito está en el piso 2")
	if rta == null:
		return
	var grid := Pursuit.grid_for(t.building().floor_node)
	var spot := p.global_position + p.global_transform.basis.x * 2.0
	if grid != null:
		var c := grid.nearest(spot, 10)
		if c.x > -99999:
			spot = grid.pos_of(c)
	rta.global_position = spot
	await t.frames(2)
	var seq: Array = t.spy("death_sequence_started")
	Pursuit.transit.clear()
	P5Pursuit.start("rta", "aux_incorrecto", 7.0)
	await t.frames(2)
	var d0 := float(Pursuit.info("rta").get("dist", -1.0))
	t.note("el Perrito empieza a %.1f m" % d0)
	var evs: Array = []
	for e in Pursuit.transit:
		evs.append(str(e[1]))
	t.check(evs.has("aviso_cerca"), "a menos de 8 m avisa antes de correr (%s)" % str(evs))
	await t.seconds(2.5)
	t.check(seq.is_empty(), "no te alcanza en los primeros 2,5 s (te da tiempo de huir)")
	t.check(float(Pursuit.info("rta").get("dist", 0.0)) > 1.0, "sigue sin tocarte mientras te mira")
	await t.until(func() -> bool: return not seq.is_empty(), 40.0)
	t.check(not seq.is_empty() and str(seq[0][1]) == "rta", "después sí corre y te alcanza (quieto)")
	await t.wait_death_shown(8.0)
	await t.reconnect()


func _hold_music(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var cm := t.main.get("contacts") as ContactManager
	cm.call("_set_hold", true)
	await t.frames(2)
	t.check(AudioManager.music_playing() == "musica/hold_kipupay", "en hold suena la música de espera (%s)" % AudioManager.music_playing())
	cm.call("_set_hold", false)
	await t.frames(2)
	t.check(AudioManager.music_playing() == "", "al sacar del hold se corta (%s)" % AudioManager.music_playing())
	cm.call("_set_hold", true)
	cm.call("_clear_hold")
	await t.frames(2)
	t.check(AudioManager.music_playing() == "" and not cm.on_hold, "al terminar el contacto en hold también se corta")
	AudioManager.play_music("hold_kipupay_parlantes", false)
	await t.frames(2)
	t.check(AudioManager.music_playing() == "musica/hold_kipupay_parlantes", "la distorsión de los parlantes suena")
	await t.back_to_menu()
	await t.frames(2)
	t.check(AudioManager.music_playing() == "", "al volver al menú no queda música del turno (%s)" % AudioManager.music_playing())


var _p5i: Object = null


func _p5() -> Object:
	if _p5i == null:
		_p5i = (load("res://scripts/dev/escenarios/p5_personajes.gd") as GDScript).new()
	return _p5i


func _haime_loop(t: Node, arg: String) -> void:
	var dif := Difficulty.Level.DIFICIL if arg == "dificil" else Difficulty.Level.NORMAL
	var hub: PersonajesP5 = await _p5().call("_prep", t, 3, true, dif)
	var seq: Array = t.spy("death_sequence_started")
	var maxn: int = hub.qa.max_per_shift()
	PersonajesP5.set_counter("p5_qa_feedbacks", maxn - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var death_clocks: Array[float] = []
	for round_i in 3:
		# Los saltos de reloj pasan por la hora del training y del evento de Rasec: no son parte de esta prueba.
		hub.training.process_mode = Node.PROCESS_MODE_DISABLED
		hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
		var block_until := float(PersonajesP5.counter("p5_qa_bloqueo_hasta", -INF))
		_p5().call("_bad_contact", ["dato_personal"])
		await t.frames(1)
		t.check(hub.qa.state == QaFeedback.State.PENDIENTE, "ronda %d: contacto malo → Haime programa la llamada" % (round_i + 1))
		if round_i > 0:
			t.check(hub.qa.call_at >= block_until - 1.0, "ronda %d: no llama antes del margen (%s ≥ %s)" % [round_i + 1, GameState.clock_text_at(hub.qa.call_at), GameState.clock_text_at(block_until)])
		await t.set_clock(hub.qa.call_at + 1.0)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
		var fatal: bool = hub.qa.is_fatal(hub.qa.n_call)
		t.check(fatal == (round_i < 2), "ronda %d: n=%d %s (muertes %d)" % [round_i + 1, hub.qa.n_call, "calibración final" if fatal else "advertencia", hub.qa.kills()])
		await _p5().call("_go_calibration", t)
		t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0), "ronda %d: la sesión empieza" % (round_i + 1))
		if round_i == 1 and Checkpoints.last_checkpoint.has("game_state"):
			# Como en el bot humano: el checkpoint es de 1 h antes y el respawn rebobina el reloj hasta ahí.
			var gs: Dictionary = Checkpoints.last_checkpoint["game_state"]
			gs["clock_seconds"] = GameState.clock_seconds - 3600.0
		if round_i < 2:
			t.check(await t.until(func() -> bool: return not seq.is_empty(), 160.0), "ronda %d: la calibración final mata" % (round_i + 1))
			if seq.is_empty():
				return
			t.check(str(seq[seq.size() - 1][0]) == "calibracion_final", "ronda %d: causa calibracion_final" % (round_i + 1))
			death_clocks.append(GameState.clock_seconds)
			await t.wait_death_shown(15.0)
			seq.clear()
			await t.reconnect()
			await t.frames(3)
			_p5().call("_quiet", t)
			var now := maxf(GameState.clock_seconds, death_clocks[death_clocks.size() - 1])  # desde la hora de la muerte
			var bl := float(PersonajesP5.counter("p5_qa_bloqueo_hasta", -INF))
			var next_block := (floorf(now / float(GameState.BLOCK_SECONDS)) + 1.0) * float(GameState.BLOCK_SECONDS)
			t.check(hub.qa.feedbacks_done() == maxn - 1, "tras reaparecer, el turno queda en la advertencia (%d de %d)" % [hub.qa.feedbacks_done(), maxn])
			t.check(hub.qa.pending().is_empty() and hub.qa.state == QaFeedback.State.LIBRE, "el checkpoint no trae la convocatoria ni contactos pendientes")
			t.check(Metrics.authorization_of("qa").is_empty() and not Discipline.get("_slow_holds").has("haime"), "sin permiso de Coaching ni reloj lento de Haime")
			t.check(bl >= now + 90.0 * 60.0 - 1.0 and bl >= next_block - 1.0, "margen: hasta %s (≥ 90 min desde la muerte de las %s y ≥ bloque siguiente %s; reloj tras reaparecer %s)" % [GameState.clock_text_at(bl), GameState.clock_text_at(now), GameState.clock_text_at(next_block), GameState.clock_text()])
			# Reaparecer y quedarse: 60 s reales sin otra muerte.
			await t.seconds(60.0)
			t.check(seq.is_empty(), "ronda %d: 60 s quieto tras reaparecer sin otra muerte" % (round_i + 1))
		else:
			t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 160.0), "3.ª ronda: la sesión termina")
			t.check(seq.is_empty() and hub.qa.last_session_end == "dada", "tras 2 muertes en el turno Haime solo advierte (%s; muertes %s; %s)" % [hub.qa.last_session_end, str(seq), GameState.clock_text()])
			t.check(hub.qa.feedbacks_done() == maxn - 1, "y el turno sigue en la advertencia")
			t.player().stand_up()
	t.check(hub.qa.kills() == 2, "2 muertes de Haime en el turno, ni una más (%d)" % hub.qa.kills())
	if death_clocks.size() == 2:
		t.check(death_clocks[1] - death_clocks[0] >= 3600.0, "entre las 2 calibraciones finales hay ≥ 60 min de juego (%s → %s)" % [GameState.clock_text_at(death_clocks[0]), GameState.clock_text_at(death_clocks[1])])
	await t.back_to_menu()


func _scares(t: Node) -> void:
	var ha: HorrorAmbience = AudioManager.director.get("horror")
	t.check(ha != null, "el AudioDirector cuelga HorrorAmbience")
	if ha == null:
		return
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.seconds(1.5)
	t.check(ha.quiet_reason() == "turno", "en el T1 no hay sustos sonoros (%s)" % ha.quiet_reason())
	await t.start_shift("Jiroshi", 3)
	await t.login_at_seat()
	GameState.stop_calm()
	Fatigue.set_value(85.0)
	# La gracia de llegada también los calla; mientras pasa, el reloj de juego quieto (si no, a 240x llega el training).
	GameState.set_clock_override("quiz")
	await t.seconds(61.0)
	GameState.set_clock_override("")
	await t.frames(2)
	t.check(ha.quiet_reason() == "", "en T3, sentado y tranquilo, puede sonar (%s)" % ha.quiet_reason())
	# En los 61 s de espera el temporizador propio pudo soltar alguno (queda en enfriamiento): se prueba desde cero.
	ha.process_mode = Node.PROCESS_MODE_DISABLED
	ha.call("_reset")
	var ok := 0
	var missing: Array[String] = []
	var silent: Array[String] = []
	for e in HorrorAmbience.EVENTS:
		if not AudioManager.has_slot(str(e["slot"])):
			missing.append(str(e["slot"]))
			continue
		if ha.can_fire(e):
			var before: int = t.building().floor_node.find_children("SustoSonoro*", "AudioStreamPlayer3D", true, false).size()
			AudioManager.sfx_history.clear()  # guarda los últimos 24: en la corrida completa ya está lleno y no crece
			ha.fire(e)
			await t.frames(2)
			var after: int = t.building().floor_node.find_children("SustoSonoro*", "AudioStreamPlayer3D", true, false).size()
			if after > before or not AudioManager.sfx_history.is_empty() or str(e.get("donde", "")) in ["parlantes", "auricular"]:
				ok += 1
			else:
				silent.append(str(e["id"]))
			t.check(not ha.can_fire(e) or int(e.get("max", 1)) > 1, "%s: respeta su tope/enfriamiento" % e["id"])
	t.check(missing.is_empty(), "todos los archivos de audio_horror_v2 están (%s)" % str(missing))
	t.check(ok >= HorrorAmbience.EVENTS.size() - 1, "%d de %d sustos suenan (mudos: %s)" % [ok, HorrorAmbience.EVENTS.size(), str(silent)])
	ha.process_mode = Node.PROCESS_MODE_PAUSABLE
	var pl: Vector3 = t.player().global_position
	var cam_fwd: Vector3 = -(t.player() as Node3D).global_transform.basis.z
	var front := 0
	for n in t.building().floor_node.find_children("SustoSonoro*", "AudioStreamPlayer3D", true, false):
		if str(n.name).contains("impresora"):
			continue  # la impresora suena donde está
		var d: Vector3 = (n as Node3D).global_position - pl
		d.y = 0.0
		if d.length() > 0.5 and d.normalized().dot(cam_fwd) > 0.7:
			front += 1
	t.check(front == 0, "ninguno sale de delante de ti (%d)" % front)
	await t.back_to_menu()


## rc1 (auditoría de bucles, tercer_break → qa_inasistencia): tras reaparecer, Haime y el Trainer convocaban en el mismo
## minuto; ibas al training y el plazo de Haime corría a 24x en la clase (8 min de juego = 20 s): muerte en el piso 1.
## Ahora con el Trainer ocupándote Haime no llama, y si ya llamó su plazo queda en pausa.
func _haime_trainer(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2, true, Difficulty.Level.NORMAL)
	var seq: Array = t.spy("death_sequence_started")
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	# 1) Pendiente y el Trainer convocando: Haime espera.
	hub.training.state = TrainingControl.State.LLAMADO
	_p5().call("_bad_contact", ["dato_personal"])
	await t.frames(1)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE, "contacto malo → Haime programa la llamada")
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.seconds(1.0)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE and hub.qa.trainer_busy(), "con el Trainer convocándote Haime no llama")
	hub.training.state = TrainingControl.State.LIBRE
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0), "libre del Trainer, Haime llama")
	# 2) Ya llamó y empieza el training (24x): su plazo no corre.
	var left0: float = hub.qa.seconds_left()
	hub.training.state = TrainingControl.State.SESION
	await t.frames(2)
	await t.set_clock(GameState.clock_seconds + 30.0 * 60.0)  # la clase entera
	await t.seconds(1.0)
	var left1: float = hub.qa.seconds_left()
	t.check(hub.qa.state == QaFeedback.State.LLAMADO and seq.is_empty(), "30 min de training con Haime esperando: sin qa_inasistencia")
	t.check(absf(left1 - left0) < 60.0, "su plazo quedó en pausa (%.1f → %.1f min)" % [left0 / 60.0, left1 / 60.0])
	hub.training.state = TrainingControl.State.HECHO
	await t.frames(2)
	await t.set_clock(GameState.clock_seconds + left1 + 30.0)
	await t.seconds(1.0)
	t.check(seq.size() == 1 and str(seq[0][0]) == "qa_inasistencia", "tras el training el plazo sigue y vence como siempre (%s)" % str(seq))
	await t.back_to_menu()

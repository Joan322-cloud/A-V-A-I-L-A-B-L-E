extends RefCounted
## Escenarios de P3 (Pursuit): la "amonestación asesina" te alcanza en TODOS los pisos (-1, 1, 2, 9), en la
## caja de escalera y si tomas el ascensor; espera en la puerta de los baños; no se detiene si vuelves a tu
## sitio; rutas sin atascos (rejilla A* de cada piso, ruta registrada y tiempo hasta alcanzarte por piso).
## Informe: user://logs/p3_persecucion.txt (piso, s hasta aparecer, s hasta alcanzar, metros, desatascos).

const REPORT := "user://logs/p3_persecucion.txt"


func escenarios() -> Array[String]:
	return [
		"persecucion_otro_piso:", "persecucion_piso_m1", "persecucion_piso_1", "persecucion_piso_2", "persecucion_piso_9",
		"persecucion_escalera", "persecucion_ascensor", "persecucion_cambia_piso", "bano_espera", "bano_espera_m1",
		"persecucion_no_se_detiene", "persecucion_rutas", "persecucion_rta_api", "persecucion_congelada",
		"persecucion_calma", "persecucion_puerta_azotea", "persecucion_api_p5", "persecucion_desde_p5",
	]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"persecucion_otro_piso": await _otro_piso(t, int(arg) if arg.is_valid_int() else -1, "")
		"persecucion_piso_m1": await _otro_piso(t, -1, "descanso_m1")
		"persecucion_piso_1": await _otro_piso(t, 1, "training_sala2")
		"persecucion_piso_2": await _otro_piso(t, 2, "sala_calibracion")
		"persecucion_piso_9": await _otro_piso(t, 9, "cafeteria_azotea")
		"persecucion_escalera": await _escalera(t)
		"persecucion_ascensor": await _ascensor(t)
		"persecucion_cambia_piso": await _cambia_piso(t)
		"bano_espera": await _bano(t, 2, "bano_p2")
		"bano_espera_m1": await _bano(t, -1, "bano_m1_h")
		"persecucion_no_se_detiene": await _no_se_detiene(t)
		"persecucion_rutas": await _rutas(t)
		"persecucion_rta_api": await _rta(t)
		"persecucion_congelada": await _congelada(t)
		"persecucion_calma": await _calma(t)
		"persecucion_puerta_azotea": await _puerta_azotea(t)
		"persecucion_api_p5": await _api_p5(t)
		"persecucion_desde_p5": await _desde_p5(t)


func _prep(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	GameState.clock_seconds = 2.0 * 3600.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.BREAK)  # autorizado a estar en cualquier piso: solo cuenta la persecución
	await t.frames(2)


func _go(t: Node, floor_n: int, marker: String) -> Vector3:
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	t.building().go_to_floor(floor_n, "ascensor")
	await t.frames(4)
	var m := t.building().floor_node.find_child(marker, true, false) as Node3D if marker != "" else null
	if m != null:
		p.teleport(m.global_position, m.rotation_degrees.y)
		await t.frames(3)
	return p.global_position


func _report(line: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open(REPORT, FileAccess.READ_WRITE) if FileAccess.file_exists(REPORT) else FileAccess.open(REPORT, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	f.close()


func _last_stat() -> Dictionary:
	return Pursuit.stats[Pursuit.stats.size() - 1] if not Pursuit.stats.is_empty() else {}


func _expect_caught(t: Node, seq: Array, cause: String, killer: String, timeout: float) -> bool:
	var ok: bool = await t.until(func() -> bool: return not seq.is_empty(), timeout)
	t.check(ok, "%s te alcanza (%s)" % [killer, cause])
	if not ok:
		var inf := Pursuit.info(killer)
		t.note("estado: %s" % str(inf))
		for l in inf.get("log", []):
			t.note(str(l))
		return false
	t.check(str(seq[0][0]) == cause and str(seq[0][1]) == killer, "muerte %s por %s (fue %s / %s)" % [cause, killer, str(seq[0][0]), str(seq[0][1])])
	await t.wait_death_shown(10.0)
	return true


func _otro_piso(t: Node, floor_n: int, marker: String) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var entered: Array = t.spy("hunter_entered_floor")
	var pos := await _go(t, floor_n, marker)
	t.note("jugador en el piso %d (%.1f, %.1f)" % [floor_n, pos.x, pos.z])
	Pursuit.start("shero", "abandono")
	var ok: bool = await t.until(func() -> bool: return not entered.is_empty(), 40.0)
	var inf := Pursuit.info("shero")
	t.check(ok and int(entered[0][1]) == floor_n, "Shero entra a tu piso (%d)" % floor_n)
	var caught: bool = await _expect_caught(t, seq, "abandono", "shero", 60.0)
	var st := _last_stat()
	var appear := float(st.get("aparece_s", -1.0))
	t.check(appear >= 0.0 and appear <= 32.5, "aparece en ≤ 32 s reales (%.1f s)" % appear)
	t.check(int(st.get("desatascos", 0)) == 0, "sin atascos (%d desatascos)" % int(st.get("desatascos", 0)))
	var line := "persecución piso %d (%s): aparece %.1f s · alcanza %.1f s después · %.1f m · %d desatascos · %s" % [floor_n, marker, appear, float(st.get("alcanza_s", -1.0)), float(st.get("metros", 0.0)), int(st.get("desatascos", 0)), "OK" if caught else "NO ALCANZÓ"]
	t.note(line)
	_report(line)
	if inf.is_empty():
		pass


func _escalera(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var entered: Array = t.spy("hunter_entered_floor")
	await _go(t, 2, "entrada_sala")
	Pursuit.start("shero", "abandono")
	await t.frames(3)
	t.check(Pursuit.info("shero").get("space", "") == "2", "Shero sale de su sitio en el piso 2")
	t.building().current_floor = 2
	t.building().go_to_stairwell(1, false)
	await t.frames(4)
	t.check(t.building().floor_node is Stairwell, "el jugador entra a la caja de escalera")
	# Baja el tramo hasta el descanso de abajo (Shero entra por la cortafuego de arriba, detrás de ti).
	t.player().teleport(t.building().floor_node.global_position + Vector3(0, 0.05, 1.4), 180.0)
	var ok: bool = await t.until(func() -> bool: return str(Pursuit.info("shero").get("space", "")).begins_with("sw:"), 12.0)
	t.check(ok, "Shero entra a la caja de escalera detrás de ti (5 s)")
	var n := Pursuit.node_of("shero")
	t.check(n != null and n.global_position.y > 2.5, "entra por la cortafuego de arriba (y = %.1f) y baja el tramo" % (n.global_position.y if n != null else -1.0))
	var caught: bool = await _expect_caught(t, seq, "abandono", "shero", 30.0)
	var st := _last_stat()
	var line := "persecución escalera 2→1: Shero entra a la caja tras %.1f s · alcanza %.1f s después · pisos %s · %d desatascos" % [float(st.get("aparece_s", -1.0)), float(st.get("alcanza_s", -1.0)), str(st.get("pisos", [])), int(st.get("desatascos", 0))]
	t.note(line)
	_report(line)
	t.check(caught and int(st.get("desatascos", 0)) == 0 and float(st.get("alcanza_s", 0.0)) > 0.5, "baja la escalera y te alcanza abajo, sin atascos")
	if entered.is_empty():
		pass


func _ascensor(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	await _go(t, 2, "casillero")
	Pursuit.start("shero", "abandono")
	await t.seconds(1.5)
	var t0_ms := Time.get_ticks_msec()
	t.building().go_to_floor(9, "ascensor_dentro")
	await t.frames(4)
	var inf := Pursuit.info("shero")
	# Con la máquina cargada 4 cuadros a time_scale 8 pueden ser >2 s de juego: se descuenta lo transcurrido.
	var gastado := (Time.get_ticks_msec() - t0_ms) / 1000.0 * Engine.time_scale
	t.check(str(inf.get("space", "x")) == "" and float(inf.get("arrive_left", 0.0)) + gastado >= 17.0, "tomas el ascensor: te sigue en el siguiente (12 s + 6 por parada = %.1f s)" % float(inf.get("arrive_left", 0.0)))
	var p: Player = t.player()
	p.teleport(t.building().floor_node.global_position + Vector3(0, 0, -1.0), 0.0)
	var caught: bool = await _expect_caught(t, seq, "abandono", "shero", 50.0)
	var st := _last_stat()
	var line := "persecución por ascensor 2→9: pisos %s · alcanza %.1f s después de llegar · %d desatascos" % [str(st.get("pisos", [])), float(st.get("alcanza_s", -1.0)), int(st.get("desatascos", 0))]
	t.note(line)
	_report(line)
	t.check(caught and (st.get("pisos", []) as Array).has("9"), "Shero llega al 9 y te alcanza")


func _cambia_piso(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var entered: Array = t.spy("hunter_entered_floor")
	await _go(t, -1, "cafeteria")
	Pursuit.start("shero", "abandono")
	await t.until(func() -> bool: return not entered.is_empty(), 40.0)
	await t.seconds(1.0)
	await _go(t, 1, "topico")
	await t.until(func() -> bool: return entered.size() >= 2, 40.0)
	await t.seconds(0.5)
	await _go(t, 9, "cafeteria_azotea")
	var caught: bool = await _expect_caught(t, seq, "abandono", "shero", 70.0)
	var floors: Array = []
	for e in entered:
		floors.append(int(e[1]))
	t.check(floors.has(-1) and floors.has(1) and floors.has(9), "te sigue piso por piso: %s" % str(floors))
	var st := _last_stat()
	var line := "persecución -1 → 1 → 9: entra a %s · total %.1f s · %.1f m · %d desatascos" % [str(floors), float(st.get("total_s", -1.0)), float(st.get("metros", 0.0)), int(st.get("desatascos", 0))]
	t.note(line)
	_report(line)
	t.check(caught, "y te alcanza en el 9")


func _bano(t: Node, floor_n: int, zone: String) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var subs: Array = t.spy("subtitle")
	await _go(t, floor_n, "ascensor")
	var bath: Bathroom = null
	for b in t.get_tree().get_nodes_in_group("bathrooms"):
		if b is Bathroom and (b as Bathroom).zone_id == zone:
			bath = b
	t.check(bath != null, "baño %s" % zone)
	if bath == null:
		return
	var p: Player = t.player()
	p.teleport(bath.global_position + Vector3(0, 0.05, 0), 0.0)
	await t.until(func() -> bool: return bath.player_inside, 3.0)
	t.check(bath.player_inside, "dentro del baño")
	Pursuit.start("shero", "abandono")
	var ok: bool = await t.until(func() -> bool: return str(Pursuit.info("shero").get("state", "")) == "bano", 45.0)
	t.check(ok, "Shero llega a la puerta del baño y espera")
	var r0 := Time.get_ticks_msec()
	await t.seconds(95.0)
	var waited := (Time.get_ticks_msec() - r0) / 1000.0 * Engine.time_scale
	t.check(seq.is_empty() and Pursuit.is_hunting("shero"), "espera ≥ 90 s afuera sin entrar (%.0f s, sin muerte)" % waited)
	var n := Pursuit.node_of("shero")
	t.check(n != null and n.global_position.distance_to(bath.global_position) < 4.5, "está en la puerta (%.1f m del centro del baño)" % (n.global_position.distance_to(bath.global_position) if n != null else -1.0))
	var said := false
	for s in subs:
		if str(s[1]).contains("Yo no entro") or str(s[1]).contains("I don't go in"):
			said = true
	t.check(said, "'Yo no entro. Yo espero. Tengo todo el turno.'")
	var line := "baño %s (piso %d): espera %.0f s en la puerta, a %.1f m" % [zone, floor_n, waited, n.global_position.distance_to(bath.global_position) if n != null else -1.0]
	t.note(line)
	_report(line)
	var door := bath.get_node_or_null("Puerta") as Node3D
	var out := (door.global_position - bath.global_position) if door != null else Vector3(0, 0, 2)
	out.y = 0.0
	p.teleport(bath.global_position + out.normalized() * (out.length() + 1.6), 0.0)
	await _expect_caught(t, seq, "abandono", "shero", 20.0)


func _no_se_detiene(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _go(t, 2, "pasillo_agua" if t.building().floor_node.find_child("pasillo_agua", true, false) != null else "casillero")
	Pursuit.start("shero", "abandono")
	await t.seconds(1.0)
	var fl := t.building().floor_node as FloorBase
	t.player().sit_at(fl.seat_by_id("C-14"), "C-14")
	await t.frames(3)
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE and t.player().seated, "de vuelta en tu sitio en Available")
	await _expect_caught(t, seq, "abandono", "shero", 40.0)


## Rutas: en cada piso y en las cajas de escalera, desde el ascensor hasta 30 celdas repartidas por toda la
## planta: la ruta existe, termina cerca del objetivo y cada tramo tiene línea de vista sobre la rejilla. Luego
## persecuciones reales a 4 puntos por piso: Shero alcanza sin atascos.
func _rutas(t: Node) -> void:
	await _prep(t)
	var targets_by_floor := {-1: ["cafeteria", "descanso_m1", "molinetes", "fermin_puesto"], 1: ["topico", "training_sala2"], 2: ["casillero", "sala_calibracion", "pc", "dispensador_sala", "evento_rasec"], 9: ["cafeteria_azotea"]}
	for f in [-1, 1, 2, 9]:
		await _go(t, f, "ascensor")
		var fl: Node3D = t.building().floor_node
		var g := Pursuit.grid_for(fl)
		t.check(g != null and g.cells > 200, "piso %d: rejilla de rutas (%d celdas, %d ms)" % [f, g.cells if g != null else 0, g.build_ms if g != null else 0])
		if g == null:
			continue
		var start := (fl.find_child("ascensor", true, false) as Node3D).global_position
		var keys := g.heights.keys()
		keys.sort()
		var bad := 0
		var n := 0
		var step := maxi(1, keys.size() / 30)
		for i in range(0, keys.size(), step):
			var c: Vector2i = keys[i]
			var to := g.pos_of(c)
			var path := g.find_path(start, to)
			n += 1
			if path.is_empty() or path[path.size() - 1].distance_to(to) > 0.8:
				bad += 1
				continue
			var prev := g.cell_of(start)
			for pt in path:
				if not g._los(prev, g.cell_of(pt)):
					bad += 1
					break
				prev = g.cell_of(pt)
		t.check(bad == 0, "piso %d: %d rutas desde el ascensor, %d malas" % [f, n, bad])
		_report("rutas piso %d: %d celdas, %d ms, %d rutas, %d malas" % [f, g.cells, g.build_ms, n, bad])
		for m in targets_by_floor[f]:
			var mk := fl.find_child(m, true, false) as Node3D
			if mk == null:
				continue
			var seq: Array = t.spy("death_sequence_started")
			Checkpoints.reset_runtime()
			GameState.running = true
			GameState.stop_calm()
			t.player().teleport(mk.global_position, 0.0)
			t.player().input_locked = false
			await t.frames(3)
			Pursuit.start("shero", "abandono")
			# Shero ya está en este piso: aparece en el ascensor (como si te hubiera seguido).
			var ok: bool = await t.until(func() -> bool: return not seq.is_empty(), 60.0)
			var st := _last_stat()
			t.check(ok and int(st.get("desatascos", 0)) == 0, "piso %d → %s: alcanza en %.1f s, %.1f m, %d desatascos" % [f, m, float(st.get("alcanza_s", -1.0)), float(st.get("metros", 0.0)), int(st.get("desatascos", 0))])
			_report("ruta piso %d → %s: aparece %.1f s, alcanza %.1f s después, %.1f m, %d desatascos, trazo %d puntos" % [f, m, float(st.get("aparece_s", -1.0)), float(st.get("alcanza_s", -1.0)), float(st.get("metros", 0.0)), int(st.get("desatascos", 0)), (st.get("trail", []) as Array).size()])
			await t.wait_death_shown(10.0)
			Checkpoints.reset_runtime()
			t.main.call("_reset_modals")
			GameState.running = true
			await t.frames(3)
	# Cajas de escalera.
	for cfg in [[-1, 1, true], [2, 1, false]]:
		t.building().current_floor = cfg[0]
		t.building().go_to_stairwell(cfg[1], cfg[2])
		await t.frames(4)
		var sw: Node3D = t.building().floor_node
		var g2 := Pursuit.grid_for(sw)
		var ys: Array[float] = []
		for v in g2.heights.values():
			ys.append(float(v))
		ys.sort()
		var span := ys[ys.size() - 1] - ys[0] if not ys.is_empty() else 0.0
		t.check(g2 != null and g2.cells > 40 and span > 3.0, "escalera %d→%d: rejilla con el tramo completo (%d celdas, desnivel %.1f m)" % [cfg[0], cfg[1], g2.cells, span])
		_report("rutas escalera %d→%d: %d celdas, desnivel %.1f m" % [cfg[0], cfg[1], g2.cells, span])


func _rta(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	await _go(t, -1, "cafeteria")
	Pursuit.start("rta", "aux_incorrecto", 8.0)
	var inf := Pursuit.info("rta")
	t.check(absf(float(inf.get("arrive_left", 0.0)) - 20.0) < 0.6, "API para P5: el RTA llega por la escalera (12 s + 4 por parada = 20 s; %.1f)" % float(inf.get("arrive_left", 0.0)))
	var caught: bool = await _expect_caught(t, seq, "aux_incorrecto", "rta", 50.0)
	t.check(caught, "el RTA te caza en el -1 con rutas")


## La forma en que P5Pursuit delega (script.call con 4 argumentos y escena null) y stop/is_hunting.
func _api_p5(t: Node) -> void:
	await _prep(t)
	await _go(t, -1, "descanso_m1")
	var scr := load("res://scripts/core/pursuit.gd") as Script
	var started: Array = t.spy("pursuit_started")
	var ends: Array = t.spy("pursuit_ended")
	var r: Variant = scr.call("start", "rta", "aux_incorrecto", 7.0, null)
	t.check(r == true and bool(scr.call("is_hunting", "rta")), "P5Pursuit → Pursuit.start(cazador, causa, velocidad, null) arranca")
	t.check(started.size() == 1 and str(started[0][0]) == "rta" and str(started[0][1]) == "aux_incorrecto", "pursuit_started(rta, aux_incorrecto)")
	t.check(scr.call("start", "rta", "aux_incorrecto", 7.0, null) == false, "una persecución por cazador (el 2.º start devuelve false)")
	scr.call("stop", "rta")
	t.check(not bool(scr.call("is_hunting", "rta")) and ends.size() == 1, "stop(cazador) la termina (pursuit_ended)")
	var ok := Pursuit.start("shero", "work_avoiding", 4.6, null, "", 2, Vector3.INF, Callable(), {"asesino": "shero"})
	t.check(ok and Pursuit.is_hunting("shero"), "firma completa de P5 (detalle, piso de origen, desde) + al_alcanzar/extra")
	Pursuit.stop("shero")


## P5 pasa de dónde sale (piso y posición): el Trainer aparece ahí mismo (modelo con CharacterRig, sin escena)
## y te caza con su asesino.
func _desde_p5(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var entered: Array = t.spy("hunter_entered_floor")
	var pp := await _go(t, 1, "training_sala2")
	var from := t.building().floor_node.find_child("ascensor", true, false) as Node3D
	var at := from.global_position if from != null else pp + Vector3(6, 0, 0)
	t.check(Pursuit.start("trainer", "training_inasistencia", 4.4, null, "", 1, at), "Trainer desde el piso 1")
	var n := Pursuit.node_of("trainer")
	t.check(n != null and n.global_position.distance_to(at) < 0.6, "aparece al instante donde P5 dijo (%s)" % (str(n.global_position) if n != null else "nada"))
	t.check(n != null and n.has_meta("rig"), "sin escena: su modelo de models_v2 (CharacterRig)")
	t.check(not entered.is_empty() and int(entered[0][1]) == 1, "hunter_entered_floor(trainer, 1)")
	var caught: bool = await _expect_caught(t, seq, "training_inasistencia", "trainer", 40.0)
	t.check(caught, "el Trainer te caza en el piso 1 (asesino trainer)")


func _congelada(t: Node) -> void:
	await _prep(t)
	await _go(t, 2, "casillero")
	Pursuit.start("shero", "abandono")
	await t.seconds(0.5)
	Discipline.freeze(true, "feedback")
	var n := Pursuit.node_of("shero")
	var p0 := n.global_position if n != null else Vector3.ZERO
	await t.seconds(4.0)
	t.check(n != null and n.global_position.distance_to(p0) < 0.05, "congelado (feedback de QA): Shero no se mueve")
	Discipline.freeze(false, "feedback")
	await t.seconds(1.0)
	t.check(n != null and n.global_position.distance_to(p0) > 0.5, "al terminar sigue")


func _calma(t: Node) -> void:
	await _prep(t)
	var ends: Array = t.spy("pursuit_ended")
	Pursuit.start("shero", "abandono")
	GameState.start_calm(3.0)
	await t.frames(2)
	t.check(not Pursuit.is_hunting() and not ends.is_empty() and str(ends[0][1]) == "calma", "la calma ('Shero en reunión') corta la persecución")
	GameState.stop_calm()


func _puerta_azotea(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	await _go(t, 9, "cafeteria_azotea")
	var door: Node = t.building().floor_node.find_child("PuertaAzotea", true, false)
	if door is WorldObjects.Door:
		(door as WorldObjects.Door).set_open(false)
	Pursuit.start("shero", "abandono")
	var caught: bool = await _expect_caught(t, seq, "abandono", "shero", 60.0)
	t.check(caught, "cruza la puerta del deck (la abre) y te alcanza en la cafetería de la azotea")
	var opened := false
	for l in _last_stat().get("trail", []):
		if l is Array and float(l[2]) > 3.0:
			opened = true
	t.check(opened, "su trazo pasa al deck (z > 3)")

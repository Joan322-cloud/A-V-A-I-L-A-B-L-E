extends RefCounted
## v0.3.2-core4 · regresiones de la prueba beta de Joan en Normal (`--escenario v032_core4`).
##   c4_break_dormido        (punto 5: «me fui a dormir a los pufs, el tiempo corría más rápido, pero Shero no dio avisos y
##                           nunca vino a matarme») recién reaparecido (la calma), dormido en un puff en Break: el aviso sale
##                           a los 10 min, se oye, te despierta, y verbal, WW, persecución y muerte llegan a su minuto;
##                           si te vuelves a dormir, también; en todos los pufs y sofás; en el lunch la escalera tampoco
##                           espera a la calma y vale el perdón por dormir; en el baño y con el juego a otra velocidad.
##   c4_comodin_tercer_break (punto 6) el comodín cubre el tercer break 10 minutos: Shero amaga la persecución, lo dice
##                           (voz + DM), vuelve a su sitio con su cara normal y sin banderas colgadas, el HUD enseña lo
##                           que queda; pasado el cupo, la escalera del break excedido y muerte break_excedido («NO HAY
##                           BREAKS»); desde otro piso; volver a tiempo; un cuarto break sin comodín mata como siempre
##                           y «Reiniciar contacto» no vale con alguien persiguiéndote; Fácil; un break legal con comodín.
##   c4_escalera_datos       los plazos por dificultad de balance.json/escalera son los de la tabla que vio Joan (Fácil,
##                           Normal, Difícil, Turno real), los límites 10/45/10 no se mueven, el piso de 30 s reales,
##                           Haime, el Trainer y el Ack lejos de la PC.
##   c4_marcas               «no hay repeticiones gratis»: cada exceso deja una marca (por tipo de falta) que Shero dice
##                           y el HUD enseña; con una marca no hay llamado (verbal al llegar al límite), con dos el WW
##                           es inmediato y la persecución respeta el piso; las marcas viajan con el checkpoint.
##   c4_camino_medido        la medida del piso: caminando a 5 m/s desde el sitio de descanso más lejano hasta C-14.
##   c4_calibracion_retoma   (punto 9) pararte y volver a sentarte en una calibración no la reinicia ni la acorta: sigue
##                           en el MISMO beat, con el mismo guion, enojo, puntaje y oportunidades, y volver no le quita
##                           tiempo; Haime echa el seguro otra vez y te lo dice; irte dos veces tampoco; pararte solo
##                           «da» la sesión cuando ya no queda más que el cierre; en pausa no avanza; en la fatal no te
##                           puedes levantar ni «Reiniciar contacto», y termina en la muerte, nunca al entrar.
##   c4_pausa_en_muerte      pausar 60 s en plena muerte (una con screamer, un colapso, la de Haime) no corta la
##                           animación: Checkpoints procesa también en pausa y su tope de espera seguía contando; al
##                           volver, la animación termina como siempre y recién entonces sale «Usuario desconectado».
##                           Tampoco corren en pausa «Reconectando», la gracia tras reaparecer ni la calma.

func escenarios() -> Array[String]:
	return ["c4_break_dormido", "c4_comodin_tercer_break", "c4_escalera_datos", "c4_marcas", "c4_camino_medido", "c4_pausa_en_muerte", "c4_calibracion_retoma"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"c4_break_dormido": await _break_dormido(t)
		"c4_comodin_tercer_break": await _comodin_tercer_break(t)
		"c4_escalera_datos": await _escalera_datos(t)
		"c4_marcas": await _marcas(t)
		"c4_camino_medido": await _camino(t)
		"c4_pausa_en_muerte": await _pausa_en_muerte(t)
		"c4_calibracion_retoma": await _calibracion_retoma(t)


func _cm(t: Node) -> ContactManager:
	return t.get_tree().get_first_node_in_group("contact_manager") as ContactManager


func _spot(t: Node, id: String) -> SleepSpot:
	for s in t.get_tree().get_nodes_in_group("sleep_spots"):
		if s is SleepSpot and (s as SleepSpot).spot_id == id:
			return s as SleepSpot
	return null












## Medición: cuánto se tarda CAMINANDO (5 m/s, sin correr) desde cada sitio legítimo de descanso hasta sentarte en C-14.
## Largo de la ruta por la rejilla del piso (la misma de Pursuit) hasta el ascensor + viaje + ascensor del piso 2 → C-14.
func _largo(grid: Variant, a: Vector3, b: Vector3) -> float:
	var path: PackedVector3Array = grid.find_path(a, b)
	if path.is_empty():
		return -1.0
	var d := 0.0
	var prev := a
	for q in path:
		d += Vector2(prev.x, prev.z).distance_to(Vector2(q.x, q.z))
		prev = q
	return d + Vector2(prev.x, prev.z).distance_to(Vector2(b.x, b.z))


func _camino(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	var v: float = t.player().speed
	var fl2 := t.building().floor_node as FloorBase
	var g2: Variant = Pursuit.grid_for(fl2)
	var seat := fl2.seat_by_id("C-14") as Node3D
	var asc2 := fl2.find_child("ascensor", true, false) as Node3D
	var esc2 := fl2.find_child("escalera", true, false) as Node3D
	var d_asc: float = _largo(g2, asc2.global_position, seat.global_position)
	var d_esc: float = _largo(g2, esc2.global_position, seat.global_position) if esc2 != null else -1.0
	t.note("piso 2: ascensor → C-14 %.1f m = %.1f s · escalera → C-14 %.1f m = %.1f s (a %.1f m/s)" % [d_asc, d_asc / v, d_esc, d_esc / v, v])
	var peor := 0.0
	var peor_que := ""
	for b in t.get_tree().get_nodes_in_group("bathrooms"):
		if fl2.is_ancestor_of(b):
			var d: float = _largo(g2, (b as Node3D).global_position, seat.global_position)
			t.note("piso 2: baño %s → C-14 %.1f m = %.1f s" % [str(b.get("zone_id")), d, d / v])
	for z in fl2.find_children("Zone_*", "", true, false):
		if z is Node3D:
			var d2: float = _largo(g2, (z as Node3D).global_position, seat.global_position)
			if d2 > 45.0:
				t.note("piso 2: %s → C-14 %.1f m = %.1f s" % [z.name, d2, d2 / v])
	for piso in [-1, 1, 9]:
		t.player().stand_up()
		t.building().go_to_floor(piso, "ascensor")
		await t.frames(6)
		var fl := t.building().floor_node as Node3D
		var g: Variant = Pursuit.grid_for(fl)
		var asc := fl.find_child("ascensor", true, false) as Node3D
		var rows: Array = []
		for n in fl.find_children("*", "", true, false):
			if not (n is Node3D):
				continue
			var nm := str(n.name)
			if n is SleepSpot or n is Bathroom or nm.begins_with("Zone_") or nm.begins_with("training_sala") or nm.contains("topico") or nm.contains("calibracion") or nm.contains("microondas") or nm.contains("Expendedora") or nm.contains("mesa_comedor"):
				var d3: float = _largo(g, (n as Node3D).global_position, asc.global_position)
				if d3 > 0.0:
					rows.append([d3, nm])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		for i in mini(rows.size(), 8):
			var viaje := 1.3 + 0.75 * float(absi(2 - piso) - (1 if piso < 0 else 0)) + 0.35  # cierra puertas + 0,75 s por piso + llegada (elevator.gd)
			var total: float = float(rows[i][0]) / v + viaje + d_asc / v
			if total > peor:
				peor = total
				peor_que = "piso %d, %s" % [piso, str(rows[i][1])]
			if i < 3:
				t.note("piso %d: %s → ascensor %.1f m = %.1f s · + viaje %.1f s + piso 2 %.1f s = %.1f s caminando hasta C-14" % [piso, str(rows[i][1]), float(rows[i][0]), float(rows[i][0]) / v, viaje, d_asc / v, total])
	# El piso de la escalera: 2 min de juego a 4x = 30 s reales entre el primer aviso y la persecución. La ruta más larga
	# caminando (sin correr) tiene que caber con margen para puertas, panel del ascensor, sentarse y marcar el AUX.
	t.check(peor > 15.0 and peor <= 25.0, "el sitio legítimo más lejano (%s) queda a %.1f s caminando de sentarte en C-14: cabe en el piso de 30 s" % [peor_que, peor])
	t.check(is_equal_approx(Discipline.marks_floor_min() * 60.0 / GameState.base_clock("de_pie_aux", 4.0), 30.0), "piso en Normal: %.0f min de juego a %.0fx = 30 s reales" % [Discipline.marks_floor_min(), GameState.base_clock("de_pie_aux", 4.0)])
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# Utilidades de las pruebas de la escalera (puntos 5, 6 y «la ventana es muy amplia»).

const TOL := 12.0  # s de juego: el reloj se adelanta de 5 en 5 s


## Turno con login en C-14 sin calma, a las 00:30, con las métricas a cero. dif: 0 fácil · 1 normal · 2 difícil.
func _prep(t: Node, turno: int = 2, dif: int = 1, agent: String = "Marko") -> void:
	await t.start_shift(agent, turno, 0, dif)
	await t.login_at_seat()
	GameState.stop_calm()
	GameState.clock_seconds = 0.5 * 3600.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.reset_shift()
	Fatigue.set_value(30.0)
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	await t.frames(2)


## Registra cada discipline_step con la hora de juego: [[pista, escalón, reloj, info], …].
func _pasos(t: Node) -> Array:
	var log_arr: Array = []
	var cb := func(track: String, step: int, info: Dictionary) -> void: log_arr.append([track, step, GameState.clock_seconds, info])
	EventBus.discipline_step.connect(cb)
	t.set_meta("c4_cb", cb)
	return log_arr


func _suelta(t: Node) -> void:
	if t.has_meta("c4_cb"):
		var cb: Callable = t.get_meta("c4_cb")
		if EventBus.discipline_step.is_connected(cb):
			EventBus.discipline_step.disconnect(cb)
		t.remove_meta("c4_cb")


## Adelanta el reloj de juego `seconds` en pasos de 5 s (las pistas avanzan con clock_tick). Va contra una hora
## objetivo: lo que el reloj corre solo en los cuadros de por medio (con la máquina cargada, bastante) se descuenta,
## así al volver el reloj está donde la prueba cree que está.
func _adv(t: Node, seconds: float, step: float = 5.0) -> void:
	var target := GameState.clock_seconds + seconds
	var n := 0
	while GameState.clock_seconds < target - 0.01 and not Checkpoints.dying:
		var s := minf(step, target - GameState.clock_seconds)
		GameState.clock_seconds += s
		EventBus.clock_tick.emit(GameState.clock_seconds)
		n += 1
		if n % 24 == 0:
			await t.frames(1)
	await t.frames(1)


func _en(log_arr: Array, track: String, step: int, desde: float = -1.0) -> float:
	for e in log_arr:
		if str(e[0]) == track and int(e[1]) == step and float(e[2]) >= desde:
			return float(e[2])
	return -1.0


func _cuenta(log_arr: Array, track: String, step: int = -1) -> int:
	var n := 0
	for e in log_arr:
		if str(e[0]) == track and (step < 0 or int(e[1]) == step):
			n += 1
	return n


## Cada escalón llegó en su minuto (desde t0) ± TOL. mins: {escalón: minuto}.
func _a_tiempo(t: Node, log_arr: Array, track: String, t0: float, mins: Dictionary, que: String = "") -> void:
	for st in mins.keys():
		var at := _en(log_arr, track, int(st), t0 - 1.0)
		var want := t0 + float(mins[st]) * 60.0
		t.check(at >= 0.0 and absf(at - want) <= TOL, "%s%s: escalón %d a los %.2f min (llegó a los %.2f)" % [que, track, int(st), float(mins[st]), (at - t0) / 60.0 if at >= 0.0 else -1.0])


func _post_de(posts: Array, canal: String, autor: String, pista: String, escalon: String = "") -> bool:
	for p in posts:
		var m: Dictionary = p[3]
		if str(p[0]) == canal and str(p[1]) == autor and str(m.get("pista", "")) == pista and (escalon == "" or str(m.get("escalon", "")) == escalon):
			return true
	return false


func _sub_con(subs: Array, trozo: String) -> bool:
	for s in subs:
		if str(s[1]).contains(trozo):
			return true
	return false


func _va(t: Node, piso: int, spawn: String = "ascensor") -> void:
	if t.player().seated:
		t.player().stand_up()
	t.building().go_to_floor(piso, spawn)
	await t.frames(5)


func _vuelve(t: Node) -> void:
	if SleepSpot.is_player_sleeping():
		Discipline.call("_wake_player")
	if t.building().current_floor != 2:
		t.building().go_to_floor(2, "pc")
		await t.frames(4)
	var fl := t.building().floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	if not t.player().seated and seat != null:
		t.player().sit_at(seat, "C-14")
	await t.until(func() -> bool: return GameState.in_room, 40.0)  # la zona de la sala tarda unos cuadros de física
	await t.frames(2)


func _fuera_de_sala(t: Node) -> void:
	if t.player().seated:
		t.player().stand_up()
	var fl: Node3D = t.building().floor_node
	t.player().teleport(fl.global_position + Vector3(10.0, 0, 20.0), 90.0)
	await t.until(func() -> bool: return not GameState.in_room, 40.0)
	await t.frames(2)


## Se acuesta en el sitio `id`. Sin esperar cuadros después: dormido el reloj va a 30x y, a escala 8 con la máquina
## cargada, un solo cuadro largo son un par de minutos de juego (el llamado llegaría antes de que la prueba mire).
func _duerme(t: Node, id: String) -> bool:
	var s := _spot(t, id)
	if s == null:
		return false
	t.player().teleport(s.global_position + Vector3(0, 0, -1.2), 0.0)
	await t.frames(3)
	return s.interact(t.player()) and SleepSpot.is_player_sleeping()


func _ack() -> void:
	if Metrics.ack_pending:
		Metrics.give_ack()


func _shero(t: Node) -> Node:
	for n in t.get_tree().get_nodes_in_group("shero"):
		if t.building().floor_node != null and t.building().floor_node.is_ancestor_of(n) and not bool(n.get("visitor")):
			return n
	return null


# ----------------------------------------------------------------------------------------------------------------
# Punto 5 de Joan: dormir en los pufs no esconde la escalera del break ni a Shero.

func _break_dormido(t: Node) -> void:
	# (a) Recién reaparecido (la calma de 120 s reales): el caso de Joan. Antes la calma congelaba la pista del break y,
	# con el reloj a 30x, pasaba una hora de juego de break sin un solo aviso.
	await t.start_shift("Marko", 2, 0, 1)
	await t.login_at_seat()
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.until(func() -> bool: return not Metrics.reconnecting, 12.0)
	t.check(GameState.in_calm, "(a) recién reaparecido: hay calma (Shero en reunión)")
	var log_arr := _pasos(t)
	var subs: Array = t.spy("subtitle")
	var posts: Array = t.spy("ezlak_post")
	var seq: Array = t.spy("death_sequence_started")
	GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
	Metrics.set_aux(Metrics.Aux.BREAK)
	Checkpoints.on_aux_picked(Metrics.Aux.BREAK)
	var t0 := GameState.clock_seconds
	await _va(t, -1, "ascensor")
	t.check(await _duerme(t, "puff_0"), "(a) acostado en el puff del -1 en Break")
	t.check(is_equal_approx(GameState.clock_speed(), 30.0), "(a) dormido el reloj corre a 30x (%.0fx)" % GameState.clock_speed())
	var r0: float = t.game_s()
	var ok: bool = await t.until(func() -> bool: return _en(log_arr, "break", 1) >= 0.0, 40.0)
	t.check(ok and GameState.in_calm, "(a) con la calma puesta el break excedido da su primer aviso (a los %.1f min de break, %.0f s reales dormido)" % [(_en(log_arr, "break", 1) - t0) / 60.0, t.game_s() - r0])
	var tarde := _en(log_arr, "break", 1) - t0 - 600.0
	t.check(tarde >= -1.0 and tarde <= 150.0, "(a) el aviso sale al llegar a los 10 min, no antes ni mucho después (%.0f s de juego después: a 30x y escala 8 un cuadro son muchos segundos de juego)" % tarde)
	await t.frames(3)
	t.check(not SleepSpot.is_player_sleeping(), "(a) el aviso por los parlantes te despierta")
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "(a) despierto y pasado el cupo el reloj va a 4x (%.0fx): el margen dura lo mismo que para cualquiera" % GameState.clock_speed())
	await t.seconds(1.5)
	t.check(_sub_con(subs, "10 minutos en break"), "(a) el primer aviso se OYE lejos de la PC (voz por los parlantes con subtítulo)")
	t.check(_post_de(posts, "dm:shero", "shero", "break", "llamado"), "(a) y queda escrito en el DM de Shero")
	# Se queda donde está: verbal, WW y persecución a su minuto, con el reloj normal.
	var tl := _en(log_arr, "break", 1)
	ok = await t.until(func() -> bool: return _en(log_arr, "break", 4) >= 0.0 or Checkpoints.dying, 70.0)
	_ack()
	_a_tiempo(t, log_arr, "break", tl, {2: 1.0, 3: 2.0, 4: 3.0}, "(a) Normal, desde el llamado · ")
	t.check(ok and Pursuit.is_hunting("shero") or Checkpoints.dying, "(a) Shero sale a buscarte aunque estés en la calma")
	ok = await t.until(func() -> bool: return not seq.is_empty(), 70.0)
	t.check(ok and str(seq[0][0]) == "break_excedido" and str(seq[0][1]) == "shero", "(a) y te mata: break_excedido / shero (%s)" % str(seq))
	await t.wait_death_shown(20.0)
	_suelta(t)
	await t.back_to_menu()

	# (b) Te despierta y te vuelves a dormir: a 30x el resto del margen son segundos, y dormido también te alcanza.
	await _prep(t)
	log_arr = _pasos(t)
	seq = t.spy("death_sequence_started")
	Metrics.set_aux(Metrics.Aux.BREAK)
	t0 = GameState.clock_seconds
	await _va(t, -1, "ascensor")
	await _adv(t, 9.0 * 60.0)
	t.check(await _duerme(t, "puff_1"), "(b) dormido a los 9 min de break")
	ok = await t.until(func() -> bool: return _en(log_arr, "break", 1) >= 0.0, 20.0)
	await t.frames(3)
	t.check(ok and not SleepSpot.is_player_sleeping(), "(b) el llamado te despierta")
	t.check(await _duerme(t, "puff_1"), "(b) te vuelves a acostar")
	ok = await t.until(func() -> bool: return Pursuit.is_hunting("shero") or Checkpoints.dying, 30.0)
	t.check(ok and SleepSpot.is_player_sleeping() or Checkpoints.dying, "(b) dormido otra vez la escalera sigue (verbal, WW y persecución en segundos reales: %s)" % str(log_arr.map(func(e: Array) -> String: return "%s:%d" % [str(e[0]), int(e[1])])))
	ok = await t.until(func() -> bool: return not seq.is_empty(), 80.0)
	t.check(ok and str(seq[0][0]) == "break_excedido", "(b) Shero baja y te mata dormido: en el break no hay perdón por dormir (%s)" % str(seq))
	await t.wait_death_shown(20.0)
	_suelta(t)
	await t.back_to_menu()

	# (c) Todos los sitios de descanso: el aviso sale igual en cada puff y cada sofá.
	for id in ["puff_0", "puff_1", "puff_2", "puff_3", "sofa_gris", "sofa_rojo"]:
		await _prep(t)
		log_arr = _pasos(t)
		Metrics.set_aux(Metrics.Aux.BREAK)
		t0 = GameState.clock_seconds
		await _va(t, -1, "ascensor")
		if _spot(t, id) == null:
			t.note("(c) no hay %s en el -1" % id)
			_suelta(t)
			await t.back_to_menu()
			continue
		await _adv(t, t0 + 9.5 * 60.0 - GameState.clock_seconds)
		t.check(await _duerme(t, id), "(c) %s: acostado" % id)
		var c0 := GameState.clock_seconds
		t.check(c0 < t0 + 600.0 and _cuenta(log_arr, "break") == 0, "(c) %s: dormido antes del límite, sin avisos todavía (%.1f min)" % [id, (c0 - t0) / 60.0])
		await _adv(t, t0 + 600.0 + 10.0 - GameState.clock_seconds)
		var at_l := _en(log_arr, "break", 1)
		t.check(at_l >= t0 + 600.0 - 1.0 and at_l <= maxf(c0, t0 + 600.0) + 90.0 and not SleepSpot.is_player_sleeping(), "(c) %s: llamado al pasar los 10:00 (a los %.2f min) y te despierta" % [id, (at_l - t0) / 60.0])
		_suelta(t)
		await t.back_to_menu()

	# (d) Lunch dormido recién reaparecido: la escalera del lunch tampoco espera a la calma, NO te despierta y vale la
	# regla de Joan: Shero te encuentra dormido y te perdona una vez (WW en vez de muerte).
	await t.start_shift("Marko", 2, 0, 1)
	await t.login_at_seat()
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()
	await t.set_clock(GameState.lunch_clock() - 120.0)
	Checkpoints.save_checkpoint("login")
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.until(func() -> bool: return not Metrics.reconnecting, 12.0)
	await t.set_clock(GameState.lunch_clock() + 10.0)
	t.check(GameState.in_calm, "(d) recién reaparecido a la hora del lunch: hay calma")
	log_arr = _pasos(t)
	seq = t.spy("death_sequence_started")
	var ends: Array = t.spy("pursuit_ended")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	Checkpoints.on_aux_picked(Metrics.Aux.LUNCH)
	t0 = GameState.clock_seconds
	await _va(t, -1, "ascensor")
	t.check(await _duerme(t, "sofa_gris"), "(d) dormido en el sofá del -1 en Lunch")
	var ww0 := Metrics.written_warnings
	ok = await t.until(func() -> bool: return Pursuit.is_hunting("shero") or not ends.is_empty(), 150.0)
	t.check(ok, "(d) el lunch excedido llega a la persecución aunque la calma siga puesta: %s" % str(log_arr.map(func(e: Array) -> String: return "%s:%d@%.1f" % [str(e[0]), int(e[1]), (float(e[2]) - t0) / 60.0])))
	var tarde_l := _en(log_arr, "lunch", 1) - t0 - 45.0 * 60.0
	t.check(tarde_l >= -1.0 and tarde_l <= 150.0, "(d) llamado al llegar a los 45 min (%.0f s de juego después)" % tarde_l)
	t.check(SleepSpot.is_player_sleeping() or not ends.is_empty(), "(d) en el lunch los parlantes NO te despiertan")
	ok = await t.until(func() -> bool: return not ends.is_empty() or not seq.is_empty(), 80.0)
	t.check(ok and seq.is_empty() and not ends.is_empty() and str(ends[0][1]) == "perdonado", "(d) Shero baja, te encuentra dormido y te perdona (una vez): %s · muertes %s" % [str(ends), str(seq)])
	t.check(Metrics.written_warnings >= ww0 + 1, "(d) a cambio de un WW (%d → %d)" % [ww0, Metrics.written_warnings])
	_suelta(t)
	await t.back_to_menu()

	# (e) Otros estados que podían tapar el reloj del break: en el baño (Shero espera en la puerta, pero los avisos
	# salen), sentado en la cafetería, con el juego a otra velocidad y tras «Reconectando».
	await _prep(t)
	log_arr = _pasos(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	t0 = GameState.clock_seconds
	await _va(t, -1, "ascensor")
	var bath: Node3D = null
	for b in t.get_tree().get_nodes_in_group("bathrooms"):
		if t.building().floor_node.is_ancestor_of(b):
			bath = b
			break
	if bath != null:
		t.player().teleport(bath.global_position, 0.0)
		await t.until(func() -> bool: return bool(bath.get("player_inside")), 3.0)
	var antes := Engine.time_scale
	Engine.time_scale = 3.0
	await _adv(t, 12.2 * 60.0)
	Engine.time_scale = antes
	_ack()
	_a_tiempo(t, log_arr, "break", t0, {1: 10.0, 2: 11.0, 3: 12.0}, "(e) en el baño del -1 y con el juego a otra velocidad · ")
	await _adv(t, 60.0)
	t.check(Pursuit.is_hunting("shero"), "(e) a los 13:00 Shero sale igual (en el baño espera en la puerta: regla de siempre)")
	_suelta(t)
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# Punto 6 de Joan: el tercer break con el comodín.

## Dos breaks legales ya usados y el jugador de pie donde diga `donde` ("sala" = pasillo del agua del piso 2, "-1").
func _dos_breaks_y_comodin(t: Node, donde: String) -> bool:
	var brk := Metrics.Aux.BREAK
	for i in 2:
		Metrics.set_aux(brk)
		await _adv(t, 180.0)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await _adv(t, 600.0)
	t.player().stand_up()
	await t.frames(2)
	if donde == "-1":
		await _va(t, -1, "ascensor")
	else:
		var z := t.building().floor_node.find_child("Zone_pasillo_agua", true, false) as Node3D
		if z != null:
			t.player().teleport(z.global_position, 0.0)
		await t.frames(6)
	Comodin.answer_override = func(_n: String) -> bool: return true
	if not Comodin.open():
		return false
	Comodin.choose_aux(brk)
	Comodin.choose_coworker(0)
	return await t.until(func() -> bool: return Metrics.aux == brk, 40.0)


func _comodin_tercer_break(t: Node) -> void:
	# (a) En tu piso: Shero salta, corre hacia ti, se detiene, lo dice y vuelve a su sitio con su cara normal.
	await _prep(t)
	var log_arr := _pasos(t)
	var subs: Array = t.spy("subtitle")
	var posts: Array = t.spy("ezlak_post")
	var seq: Array = t.spy("death_sequence_started")
	var starts: Array = t.spy("pursuit_started")
	var ends: Array = t.spy("pursuit_ended")
	t.check(await _dos_breaks_y_comodin(t, "sala"), "(a) el compañero te marca el tercer Break (Breaks %d/%d)" % [Metrics.breaks_used, Metrics.breaks_allowed()])
	var t0 := Metrics.aux_since
	t.check(Discipline.comodin_break_covered(), "(a) ese Break lo cubre el comodín")
	t.check(not starts.is_empty() and str(starts[0][1]) == "tercer_break" and Discipline.shero_bald(), "(a) Shero salta igual: «¿TERCER BREAK?!», calvo y hacia ti (%s)" % str(starts))
	t.check(_sub_con(subs, "TERCER BREAK") or _sub_con(subs, "Tercer break"), "(a) lo grita")
	var ok: bool = await t.until(func() -> bool: return not ends.is_empty() or not seq.is_empty(), 12.0)
	t.check(ok and seq.is_empty() and str(ends[0][1]) in ["comodin", "perdonado"], "(a) el amago termina sin muerte en pocos segundos (%s)" % str(ends))
	var sh := _shero(t)
	t.check(sh != null and not bool(sh.get("pursuit_driven")) and int(sh.get("state")) != Shero.State.PERSEGUIR, "(a) Shero ya no persigue (estado %s)" % (str(sh.get("state")) if sh != null else "-"))
	t.check(not Pursuit.is_hunting() and not (Discipline.counters["por_pista"] as Dictionary).has("tercer_break"), "(a) sin banderas de persecución colgadas (%s)" % str(Discipline.counters["por_pista"]))
	await t.seconds(4.0)
	t.check(_sub_con(subs, "Que no se repita"), "(a) dice por qué con su voz: «Ok. Que no se repita. Lo dejo como alerta.»")
	t.check(_post_de(posts, "dm:shero", "shero", "comodin_break", "perdon"), "(a) y por Ezlaki: «Tu PC se marcó sola en Break… lo dejo pasar 10 minutos…»")
	var dm_generico := false
	for p in posts:
		dm_generico = dm_generico or (str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("tipo", "")) == "comodin")
	t.check(not dm_generico, "(a) sin el DM genérico del comodín encima (no se repite)")
	ok = await t.until(func() -> bool: return sh != null and bool(sh.get("seated")) and str(sh.get("look")) == "afro", 40.0)
	t.check(ok and not Discipline.shero_bald(), "(a) vuelve caminando a su sitio, se sienta y recupera su cara normal (sentado %s, look %s)" % [str(sh.get("seated")) if sh != null else "-", str(sh.get("look")) if sh != null else "-"])
	var memo := sh.get_node_or_null("Amonestacion") as Node3D if sh != null else null
	t.check(memo == null or not memo.visible, "(a) sin la amonestación en la mano")
	var txt := Discipline.aux_margin_text()
	t.check(txt.contains("10:00") and (txt.contains("comodín") or txt.contains("lifeline")), "(a) al lado del contador del Break se ve lo que le queda al comodín («%s%s»)" % [Loc.mmss(Metrics.seconds_in_current_aux()), txt])
	t.check(GameState.break_in_quota() and GameState.clock_mode == GameState.ClockMode.BREAK, "(a) y corre el reloj de un break normal (%.0fx)" % GameState.clock_speed())
	t.check(_cuenta(log_arr, "break") == 0 and Metrics.written_warnings == 0, "(a) dentro de sus 10 minutos no hay ni llamado ni WW")
	# Pasados los 10 minutos: la escalera del break excedido de siempre y la muerte de «NO HAY BREAKS».
	await _adv(t, t0 + 9.0 * 60.0 - GameState.clock_seconds)
	t.check(_cuenta(log_arr, "break") == 0 and not Pursuit.is_hunting(), "(a) a los 9:00 sigue perdonado")
	await _adv(t, 3.0 * 60.0 + 10.0)
	_ack()
	txt = Discipline.aux_margin_text()
	t.check(txt.contains("vencido") or txt.contains("expired"), "(a) pasado el cupo el HUD dice que el comodín venció («%s»)" % txt)
	await _adv(t, 60.0)
	_a_tiempo(t, log_arr, "break", t0, {1: 10.0, 2: 11.0, 3: 12.0, 4: 13.0}, "(a) Normal · ")
	t.check(Pursuit.is_hunting("shero") and str(Pursuit.info("shero").get("cause", "")) == "break_excedido", "(a) a los 13:00 Shero sale a matar por break excedido")
	ok = await t.until(func() -> bool: return not seq.is_empty(), 60.0)
	t.check(ok and str(seq[0][0]) == "break_excedido" and str(seq[0][1]) == "shero", "(a) muerte break_excedido / shero: la del grito «NO HAY BREAKS» (%s)" % str(seq))
	t.check(str((DataLoader.dict("screamers").get("causas", {}) as Dictionary).get("break_excedido", {}).get("frase", "")).contains("no_hay_breaks"), "(a) y ese grito es el de break_excedido en screamers.json")
	await t.wait_death_shown(20.0)
	Comodin.answer_override = Callable()
	_suelta(t)
	await t.back_to_menu()

	# (b) En otro piso: Shero no llega a aparecer; lo dice por los parlantes y se queda en su sitio.
	await _prep(t, 2, 1, "Juan")
	subs = t.spy("subtitle")
	seq = t.spy("death_sequence_started")
	ends = t.spy("pursuit_ended")
	t.check(await _dos_breaks_y_comodin(t, "-1"), "(b) tercer Break con el comodín desde el -1")
	ok = await t.until(func() -> bool: return not ends.is_empty() or not seq.is_empty(), 12.0)
	t.check(ok and seq.is_empty() and str(ends[0][1]) == "comodin", "(b) el amago se corta antes de que llegue a tu piso (%s)" % str(ends))
	await t.seconds(3.0)
	t.check(_sub_con(subs, "Que no se repita"), "(b) y lo oyes por los parlantes")
	t.check(Discipline.comodin_break_covered() and not Pursuit.is_hunting() and not Discipline.shero_bald(), "(b) cubierto, sin persecución, Shero normal")
	# Volver a tiempo: sin llamado, sin marca.
	await _adv(t, 8.0 * 60.0)
	await _vuelve(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 5.0 * 60.0)
	t.check(Discipline.marks_of("break") == 0 and Metrics.written_warnings == 0 and not Pursuit.is_hunting(), "(b) vuelves a los 8 min: ni marca ni WW ni persecución")
	# Un cuarto break (ya sin comodín) sí es el tercer break de siempre.
	var starts2: Array = t.spy("pursuit_started")
	t.check(Checkpoints.can_restart_contact(), "(b) sin nadie persiguiéndote «Reiniciar contacto» está disponible")
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(2)
	t.check(not Discipline.comodin_break_covered() and Pursuit.is_hunting("shero") and not starts2.is_empty() and str(starts2[0][1]) == "tercer_break", "(b) otro break después, sin comodín: persecución del tercer break, sin perdón")
	t.check(not Checkpoints.can_restart_contact(), "(b) y con Shero persiguiéndote no vale «Reiniciar contacto» (antes cortaba la persecución)")
	ok = await t.until(func() -> bool: return not seq.is_empty(), 60.0)
	t.check(ok and str(seq[0][0]) == "tercer_break", "(b) te alcanza: tercer_break (%s)" % str(seq))
	await t.wait_death_shown(20.0)
	Comodin.answer_override = Callable()
	await t.back_to_menu()

	# (c) Fácil: con el comodín no hay «confirma el tercer break» y tampoco muerte.
	await _prep(t, 2, 0, "Llauri")
	seq = t.spy("death_sequence_started")
	ends = t.spy("pursuit_ended")
	t.check(await _dos_breaks_y_comodin(t, "sala"), "(c) Fácil: tercer Break con el comodín sin pedir confirmación")
	ok = await t.until(func() -> bool: return not ends.is_empty() or not seq.is_empty(), 12.0)
	t.check(ok and seq.is_empty() and Discipline.comodin_break_covered(), "(c) cubierto y sin muerte")
	Comodin.answer_override = Callable()
	await t.back_to_menu()

	# (d) El comodín en un break legal (el primero) no cambia nada: sin amago y con su checkpoint.
	await _prep(t, 2, 1, "Ttoom")
	starts = t.spy("pursuit_started")
	var cps: Array = t.spy("checkpoint_saved")
	t.player().stand_up()
	var z2 := t.building().floor_node.find_child("Zone_pasillo_agua", true, false) as Node3D
	if z2 != null:
		t.player().teleport(z2.global_position, 0.0)
	await t.frames(6)
	Comodin.answer_override = func(_n: String) -> bool: return true
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.BREAK)
	Comodin.choose_coworker(0)
	ok = await t.until(func() -> bool: return Metrics.aux == Metrics.Aux.BREAK, 40.0)
	await t.seconds(2.0)
	t.check(ok and starts.is_empty() and not Discipline.comodin_break_covered() and Metrics.breaks_used == 1, "(d) primer break con el comodín: un break normal, sin amago")
	t.check(not cps.is_empty(), "(d) con su checkpoint, como al elegirlo en la PC (%s)" % str(cps))
	Comodin.answer_override = Callable()
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# «La ventana es muy amplia»: plazos por dificultad (balance.json/escalera) y marcas.

## La tabla que se le enseñó a Joan, en minutos de juego desde el límite (o desde que empieza la falta), por dificultad
## [Fácil, Normal, Difícil, Turno real]. Si alguien retoca balance.json, esta prueba dice qué cambió.
const TABLA := {
	"break": {1: [0, 0, 0, 0], 2: [1.5, 1, 0.75, 0.75], 3: [3, 2, 1.5, 1.5], 4: [4.5, 3, 2.25, 2.25]},
	"lunch": {1: [0, 0, 0, 0], 2: [1.5, 1, 0.75, 0.75], 3: [3, 2, 1.5, 1.5], 4: [4.5, 3, 2.25, 2.25]},
	"correo": {1: [0, 0, 0, 0], 2: [3, 2, 1.5, 1.5], 3: [6, 4, 3, 3], 4: [9, 6, 4.5, 4.5]},
	"sala": {1: [0.75, 0.5, 0.4, 0.4], 2: [2.25, 1.5, 1.15, 1.15], 3: [3.75, 2.5, 1.9, 1.9], 4: [5.25, 3.5, 2.65, 2.65]},
	"otra_isla": {1: [3, 2, 1.5, 1.5], 2: [4.5, 3, 2.25, 2.25], 3: [6, 4, 3, 3], 4: [7.5, 5, 3.75, 3.75]},
	"coaching": {1: [0, 0, 0, 0], 2: [1.5, 1, 0.75, 0.75], 3: [3, 2, 1.5, 1.5], 4: [4.5, 3, 2.25, 2.25]},
	"coaching_exceso": {1: [1.5, 1, 0.5, 0.5], 2: [3, 2, 1.25, 1.25], 4: [4.5, 3, 2.5, 2.5]},
	"coaching_noshow": {2: [0, 0, 0, 0], 3: [1.5, 1, 1, 1], 4: [3, 2, 2, 2]},
	"coaching_noshow_rasec": {2: [0, 0, 0, 0], 3: [1.5, 1, 1, 1], 4: [3, 2, 2, 2]},
	"training_regreso": {1: [4.5, 3, 2.25, 2.25], 2: [6, 4, 3, 3], 4: [7.5, 5, 4.25, 4.25]},
	"topico_excedido": {2: [0, 0, 0, 0], 4: [3, 2, 2, 2]},
}
const LIMITE := {"break": 10.0, "lunch": 45.0, "correo": 10.0}


func _escalera_datos(t: Node) -> void:
	var keys := ["", "llamado_min", "verbal_min", "ww_min", "persecucion_min"]
	for col in 4:
		await t.start_shift("Marko", 2, GameState.Mode.REAL if col == 3 else 0, mini(col, 2))
		await t.frames(2)
		t.check(Discipline.difficulty_column() == col, "columna %d de la tabla (dificultad %s%s)" % [col, Difficulty.id(), " · turno real" if GameState.is_real_mode() else ""])
		var mal: Array[String] = []
		var piso_ok := true
		for track in TABLA.keys():
			var th: Dictionary = Discipline.thresholds(track)
			var row: Dictionary = TABLA[track]
			var base := float(LIMITE.get(track, 0.0))
			for st in [1, 2, 3, 4]:
				var has := th.has(keys[st])
				if row.has(st) != has or (has and not is_equal_approx(float(th[keys[st]]), base + float(row[st][col]))):
					mal.append("%s/%s = %s (esperado %s)" % [track, keys[st], str(th.get(keys[st], "—")), str(base + float(row[st][col])) if row.has(st) else "—"])
			# Piso: del primer aviso a la persecución, al menos 2 min de juego (30 s reales a 4x); el correo, a 10x, 3 min.
			var firsts: Array = row.keys()
			firsts.sort()
			var gap := float(row[4][col]) - float(row[firsts[0]][col])
			if gap < 2.0 - 0.001:
				piso_ok = false
				mal.append("%s: solo %.2f min del primer aviso a la persecución" % [track, gap])
		t.check(mal.is_empty(), "dificultad %d: los plazos de la escalera son los de la tabla (%s)" % [col, "todos" if mal.is_empty() else "; ".join(PackedStringArray(mal))])
		t.check(piso_ok and Discipline.marks_floor_min() >= 2.0, "dificultad %d: de un aviso a la persecución nunca menos de 2 min de juego = 30 s reales (piso con marcas %.1f)" % [col, Discipline.marks_floor_min()])
		# Los límites de regla no se mueven (los gritan los screamers).
		t.check(is_equal_approx(float(Discipline.thresholds("break")["llamado_min"]), 10.0) and is_equal_approx(float(Discipline.thresholds("lunch")["llamado_min"]), 45.0) and is_equal_approx(float(Discipline.thresholds("correo")["llamado_min"]), 10.0), "dificultad %d: break 10, lunch 45 y correo 10 no cambian" % col)
		# Haime y el Trainer (sus plazos van × dificultad): aviso y muerte / persecución.
		var k := Difficulty.scale("plazos")
		var qa: Dictionary = DataLoader.dict("qa_haime")
		var tr_cfg: Dictionary = DataLoader.dict("training")
		t.check(is_equal_approx(float(qa.get("aviso_noshow_min", -1)), 2.0) and is_equal_approx(float(qa.get("margen_llegada_min", -1)), 4.0) and PersonajesP5.plazo(4.0) >= 180.0 - 0.01, "dificultad %d: Haime avisa a los %.2f min y mata a los %.2f (≥ 45 s reales)" % [col, 2.0 * k, 4.0 * k])
		t.check(is_equal_approx(float(tr_cfg.get("espera_min", -1)), 3.0) and is_equal_approx(float(tr_cfg.get("persecucion_min", -1)), 5.0), "dificultad %d: el Trainer avisa a los %.2f min y sale a los %.2f" % [col, 3.0 * k, 5.0 * k])
		var p: Dictionary = (DataLoader.dict("escalada").get("pistas", {}) as Dictionary).get("ww_ack", {})
		t.check(int(p.get("ack_s_lejos", 0)) == 40 and int(p.get("ack_s_lejos_otro_piso", 0)) == 60, "dificultad %d: Ack lejos de la PC 40 s en el piso 2 y 60 s desde otro piso (× dificultad)" % col)
		await t.back_to_menu()
	# Fácil ≥ Normal ≥ Difícil = Turno real en todos los plazos.
	var orden_ok := true
	for track in TABLA.keys():
		for st in (TABLA[track] as Dictionary).keys():
			var r: Array = TABLA[track][st]
			orden_ok = orden_ok and float(r[0]) >= float(r[1]) and float(r[1]) >= float(r[2]) and is_equal_approx(float(r[2]), float(r[3]))
	t.check(orden_ok, "Fácil es el que más perdona, Difícil el que menos y el Turno real va como Difícil")


## Un exceso de break corregido a tiempo: sale de la sala en Break, pasa `min_total` minutos y vuelve a Available.
func _exceso_break(t: Node, min_total: float) -> float:
	Metrics.set_aux(Metrics.Aux.BREAK)
	var t0 := Metrics.aux_since
	await _fuera_de_sala(t)
	await _adv(t, min_total * 60.0)
	_ack()
	await _vuelve(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 120.0)
	return t0


func _marcas(t: Node) -> void:
	await _prep(t)
	var log_arr := _pasos(t)
	var posts: Array = t.spy("ezlak_post")
	var seq: Array = t.spy("death_sequence_started")
	t.check(Discipline.marks_of("break") == 0 and Discipline.marks_of("lunch") == 0, "turno limpio: sin marcas")
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(2)
	var txt := Discipline.aux_margin_text()
	t.check(txt.contains("10:00") and txt.contains("3:00") and not (txt.contains("marca") or txt.contains("mark")), "sin marcas, al lado del contador del Break: límite 10:00 y margen 3:00 («%s»)" % txt)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	Metrics.breaks_used = 0
	await t.frames(2)
	# 1.er exceso: 10:30 de break. Llamado, marca y nada más.
	var t0: float = await _exceso_break(t, 10.5)
	await t.seconds(5.0)
	t.check(_cuenta(log_arr, "break", 1) == 1 and _cuenta(log_arr, "break", 2) == 0, "1.er exceso (10:30): solo el llamado")
	t.check(Discipline.marks_of("break") == 1 and Discipline.marks_of("lunch") == 1 and Discipline.marks_of("sala") == 0, "queda una marca de «descanso»: vale para el break y para el lunch, no para otras faltas")
	t.check(_post_de(posts, "dm:shero", "shero", "break", "marca"), "Shero lo dice por DM: «Anotado… primera marca…»")
	# El checkpoint se la lleva: morir y reaparecer no la borra ni la duplica.
	Checkpoints.save_checkpoint("login")
	# 2.º break, 2.º exceso: ya no hay llamado; verbal al llegar a los 10, WW a los 11.
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(2)
	txt = Discipline.aux_margin_text()
	t.check(txt.contains("2:00") and (txt.contains("1 marca") or txt.contains("1 mark")), "con una marca el HUD enseña el margen reducido: 2:00 y «1 marca» («%s»)" % txt)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	Metrics.breaks_used = 1
	await t.frames(2)
	var n1 := log_arr.size()
	t0 = await _exceso_break(t, 11.2)
	await t.seconds(5.0)
	var seg: Array = log_arr.slice(n1)
	t.check(_cuenta(seg, "break", 1) == 0, "2.º exceso: sin llamado")
	_a_tiempo(t, seg, "break", t0, {2: 10.0, 3: 11.0}, "2.º exceso · ")
	t.check(Metrics.written_warnings == 1, "pasarse 1 min con una marca ya cuesta un WW (%d)" % Metrics.written_warnings)
	t.check(Discipline.marks_of("break") == 2, "y deja la segunda marca")
	var mas := false
	for p in posts:
		mas = mas or (str((p[3] as Dictionary).get("escalon", "")) == "marca" and str(p[2]).contains("2"))
	t.check(mas, "Shero: «Van 2 marcas…»")
	# Reaparecer devuelve las marcas del checkpoint (1), no las de después (2): morir no suma ni resta marcas.
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.until(func() -> bool: return not Metrics.reconnecting, 12.0)
	GameState.stop_calm()
	t.check(Discipline.marks_of("break") == 1, "tras reaparecer: las marcas del checkpoint (%d), ni más ni menos" % Discipline.marks_of("break"))
	# Con dos marcas el lunch: WW al llegar a los 45 y la persecución nunca antes de 2 min de juego (30 s reales).
	(Discipline.counters["veces"] as Dictionary)["break"] = 2
	await t.set_clock(GameState.lunch_clock() + 5.0)
	var n2 := log_arr.size()
	Metrics.set_aux(Metrics.Aux.LUNCH)
	var tl := Metrics.aux_since
	await _va(t, -1, "ascensor")
	txt = Discipline.aux_margin_text()
	t.check(txt.contains("45:00") and txt.contains("2:00") and (txt.contains("2 marcas") or txt.contains("2 marks")), "lunch con dos marcas: límite 45:00, margen 2:00, «2 marcas» («%s»)" % txt)
	await _adv(t, 45.5 * 60.0, 10.0)
	_ack()
	seg = log_arr.slice(n2)
	t.check(_cuenta(seg, "lunch", 1) == 0 and _cuenta(seg, "lunch", 2) == 0, "lunch con dos marcas: ni llamado ni verbal")
	_a_tiempo(t, seg, "lunch", tl, {3: 45.0}, "lunch con dos marcas · ")
	txt = Discipline.aux_margin_text()
	t.check(txt.contains("47:00"), "pasado el límite el HUD dice cuándo sale Shero: a los 47:00 («%s»)" % txt)
	await _adv(t, tl + 47.0 * 60.0 + 15.0 - GameState.clock_seconds)
	seg = log_arr.slice(n2)
	_a_tiempo(t, seg, "lunch", tl, {4: 47.0}, "lunch con dos marcas · ")
	t.check(_en(seg, "lunch", 4) - _en(seg, "lunch", 3) >= 120.0 - TOL, "la persecución respeta el piso: 2 min de juego tras el WW, no 1 (%.0f s)" % (_en(seg, "lunch", 4) - _en(seg, "lunch", 3)))
	t.check(Pursuit.is_hunting("shero") or Checkpoints.dying, "a los 47:00 sale")
	var ok: bool = await t.until(func() -> bool: return not seq.is_empty() and str(seq[seq.size() - 1][0]) == "lunch_excedido", 80.0)
	t.check(ok, "y mata por lunch_excedido (%s)" % str(seq))
	await t.wait_death_shown(20.0)
	_suelta(t)
	await t.back_to_menu()

	# Otras faltas, sus marcas por separado: salir de la sala sin AUX (grupo «sitio»).
	await _prep(t)
	log_arr = _pasos(t)
	var s0 := GameState.clock_seconds
	await _fuera_de_sala(t)
	s0 = GameState.clock_seconds
	await _adv(t, 60.0)
	await _vuelve(t)
	await _adv(t, 120.0)
	_a_tiempo(t, log_arr, "sala", s0, {1: 0.5}, "1.ª salida · ")
	t.check(Discipline.marks_of("sala") == 1 and Discipline.marks_of("otra_isla") == 1 and Discipline.marks_of("break") == 0, "salir de la sala deja marca de «sitio» (no de descanso)")
	var n3 := log_arr.size()
	await _fuera_de_sala(t)
	s0 = GameState.clock_seconds
	await _adv(t, 100.0)
	_ack()
	seg = log_arr.slice(n3)
	t.check(_cuenta(seg, "sala", 1) == 0, "2.ª salida: sin llamado")
	_a_tiempo(t, seg, "sala", s0, {2: 0.5, 3: 1.5}, "2.ª salida · ")
	await _adv(t, 60.0)
	seg = log_arr.slice(n3)
	_a_tiempo(t, seg, "sala", s0, {4: 2.5}, "2.ª salida · ")
	_suelta(t)
	await t.back_to_menu()

	# Difícil: el primer exceso de break sale a los 10 / 10:45 / 11:30 / 12:15; con una marca, la persecución respeta
	# el piso (verbal 10:00, WW 10:45, persecución 12:00 y no 11:30).
	await _prep(t, 2, 2)
	log_arr = _pasos(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	t0 = Metrics.aux_since
	await _va(t, 9, "ascensor")
	await _adv(t, 12.5 * 60.0)
	_ack()
	_a_tiempo(t, log_arr, "break", t0, {1: 10.0, 2: 10.75, 3: 11.5, 4: 12.25}, "Difícil · ")
	_suelta(t)
	await t.back_to_menu()
	await _prep(t, 2, 2)
	(Discipline.counters["veces"] as Dictionary)["lunch"] = 1
	log_arr = _pasos(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	t0 = Metrics.aux_since
	await _va(t, 9, "ascensor")
	await _adv(t, 12.3 * 60.0)
	_ack()
	t.check(_cuenta(log_arr, "break", 1) == 0, "Difícil con una marca (del lunch): sin llamado")
	_a_tiempo(t, log_arr, "break", t0, {2: 10.0, 3: 10.75, 4: 12.0}, "Difícil con una marca · ")
	_suelta(t)
	await t.back_to_menu()

# ----------------------------------------------------------------------------------------------------------------
# Pausa en plena muerte (lo encontró el paquete de muertes; Checkpoints es de core).

## Pide la muerte y devuelve cuántos segundos de juego SIN PAUSA pasaron hasta «Usuario desconectado», pausando
## `pausa_s` segundos al segundo de empezar (0 = sin pausa). out: {fin: terminó la animación antes de la pantalla,
## en_pausa: la pantalla salió durante la pausa, tope: el tope de espera de esa muerte}.
func _muere_con_pausa(t: Node, cause: String, killer: String, pausa_s: float, out: Dictionary) -> float:
	var fin_scr: Array = t.spy("screamer_finished")
	var fin_anim: Array = t.spy("death_animation_finished")
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	GameState.stop_calm()
	if cause == "colapso":
		Fatigue.set_value(99.0)
		Fatigue.add(5.0, true)
	else:
		Checkpoints.request_death(cause, "", killer)
	await t.frames(1)
	if not Checkpoints.dying:
		return -1.0
	var t0: float = t.game_s()
	var corrido := 0.0
	out["en_pausa"] = false
	if pausa_s > 0.0:
		await t.seconds(1.0)
		corrido = t.game_s() - t0
		t.get_tree().paused = true
		await t.seconds(pausa_s)
		out["en_pausa"] = Checkpoints.death_visible or t.death_screen().visible
		out["fin_en_pausa"] = fin_scr.size() + fin_anim.size()
		t.get_tree().paused = false
		t0 = t.game_s()
	var shown: bool = await t.wait_death_shown(30.0)
	out["fin"] = shown and fin_scr.size() + fin_anim.size() >= 1
	return corrido + (t.game_s() - t0) if shown else -1.0


func _pausa_en_muerte(t: Node) -> void:
	for caso in [["abandono", "shero", "screamer de Shero"], ["colapso", "", "colapso por Fatiga"], ["calibracion_final", "haime", "screamer de Haime"]]:
		var cause := str(caso[0])
		var nombre := str(caso[2])
		await t.start_shift("Marko", 2)
		await t.login_at_seat()
		_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
		# sin pausa: lo que dura esa muerte
		var a := {}
		var base: float = await _muere_con_pausa(t, cause, str(caso[1]), 0.0, a)
		t.check(base > 0.5 and bool(a.get("fin", false)), "%s sin pausa: la animación termina y sale la pantalla (%.1f s)" % [nombre, base])
		await t.reconnect()
		await t.frames(3)
		# con 60 s de pausa en medio
		var b := {}
		var con: float = await _muere_con_pausa(t, cause, str(caso[1]), 60.0, b)
		t.check(not bool(b.get("en_pausa", true)) and int(b.get("fin_en_pausa", 1)) == 0, "%s: en 60 s de pausa no sale «Usuario desconectado» ni se da por terminada la animación" % nombre)
		t.check(con > 0.0 and bool(b.get("fin", false)), "%s: al volver de la pausa la animación termina sola (no la corta el tope) y sale la pantalla" % nombre)
		await t.reconnect()
		await t.frames(3)
		# otra vez sin pausa: la misma muerte repetida puede durar distinto (el aviso previo solo sale la primera vez),
		# así que la que tuvo pausa se compara con las dos
		var c := {}
		var base2: float = await _muere_con_pausa(t, cause, str(caso[1]), 0.0, c)
		t.note("%s: sin pausa %.1f s · con 60 s de pausa %.1f s (sin contar la pausa) · sin pausa otra vez %.1f s" % [nombre, base, con, base2])
		t.check(con > 0.0 and base2 > 0.0 and con >= minf(base, base2) - 1.5 and con <= maxf(base, base2) + 1.5, "%s: dura lo mismo que sin pausa (%.1f s sin contar la pausa; sin pausa %.1f s antes y %.1f s después)" % [nombre, con, base, base2])
		await t.reconnect()
		await t.frames(3)
		if cause == "abandono":
			# «Reconectando», la gracia tras reaparecer y la calma tampoco corren en pausa
			var rec0 := Reconexion.left
			var gracia0 := Checkpoints.respawn_grace_left()
			var calma0 := float(GameState.get("_calm_left"))
			t.get_tree().paused = true
			await t.seconds(60.0)
			t.check(Metrics.reconnecting and absf(Reconexion.left - rec0) < 0.05, "en pausa «Reconectando» no corre (%.1f s → %.1f s)" % [rec0, Reconexion.left])
			t.check(absf(Checkpoints.respawn_grace_left() - gracia0) < 0.05 and gracia0 > 50.0, "ni la gracia tras reaparecer (%.1f s → %.1f s)" % [gracia0, Checkpoints.respawn_grace_left()])
			t.check(GameState.in_calm and absf(float(GameState.get("_calm_left")) - calma0) < 0.05 and calma0 > 10.0, "ni la calma (%.1f s → %.1f s)" % [calma0, float(GameState.get("_calm_left"))])
			t.get_tree().paused = false
		await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# Punto 9 (Joan, beta en Normal): «en la calibración de la muerte me paré y me volví a sentar y la calibración empezó
# de nuevo desde el principio. Eso puede explotarse; debe continuar donde se quedó».

func _beats_esperados(qa: QaFeedback) -> int:
	var n := 0
	for b in qa.session.get("beats", []):
		if str((b as Dictionary).get("k", "")) != "fin":
			n += 1
	return n - qa.skipped.size()


func _calibracion_retoma(t: Node) -> void:
	var ph2: RefCounted = load("res://scripts/dev/escenarios/ph2_haime.gd").new()
	var p5: RefCounted = load("res://scripts/dev/escenarios/p5_personajes.gd").new()
	for caso in ["segunda", "advertencia"]:
		var hub: PersonajesP5 = await p5.call("_prep", t, 1, true, Difficulty.Level.NORMAL)
		ph2.call("_quiet_p5", hub)
		var qa := hub.qa
		PersonajesP5.set_counter("p5_qa_feedbacks", (qa.max_per_shift() - 2) if caso == "advertencia" else 1)
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		qa.test_answers = ["mal", "tarde", "ok", "ok", "ok"]
		await ph2.call("_fatal_session_n", t, hub)
		var n := qa.n_call
		t.check(qa.state == QaFeedback.State.SESION and (qa.is_warning(n) if caso == "advertencia" else n == 2) and qa.resumed_from == -1, "%s: empieza la calibración %d (de cero)" % [caso, n])
		var guion: Dictionary = qa.session
		var firma := str(guion.get("firma", ""))
		t.check(not Checkpoints.can_restart_contact(), "%s: durante la calibración no hay «Reiniciar contacto»" % caso)
		# Hasta la mitad: al menos un error ya marcado y un beat en curso, con el control devuelto.
		var mitad: bool = await t.until(func() -> bool: return int(qa.get("_beat_i")) >= 3 and qa.heard_opportunities >= 1 and qa.beat_now != "" and not t.player().input_locked, 150.0)
		var i0 := int(qa.get("_beat_i"))
		var k0 := qa.beat_now
		var anger0 := qa.anger
		var score0 := qa.score_now
		var heard0 := qa.heard_opportunities
		var clock0 := qa.clock
		var hechos0 := qa.beats_done.size() - 1  # el que está en curso no cuenta
		t.check(mitad, "%s: a mitad de la sesión (beat %d «%s» de %d · enojo %d · puntaje %d · oportunidades %d · %.1f s)" % [caso, i0, k0, (guion.get("beats", []) as Array).size(), anger0, score0, heard0, clock0])
		# En pausa nada avanza.
		t.get_tree().paused = true
		await t.seconds(20.0)
		t.check(int(qa.get("_beat_i")) == i0 and absf(qa.clock - clock0) < 0.3, "%s: 20 s de pausa: sigue en el mismo beat y el reloj de la sesión no corre (%.1f s → %.1f s)" % [caso, clock0, qa.clock])
		t.get_tree().paused = false
		clock0 = qa.clock
		# Te paras: te fuiste a mitad.
		t.player().stand_up()
		await t.frames(4)
		t.check(not t.player().seated and qa.state == QaFeedback.State.LLAMADO and qa.last_session_end == "a_mitad" and qa.walkouts == 1, "%s: te paras a mitad: Haime te vuelve a llamar (%s)" % [caso, qa.last_session_end])
		t.check(int(PersonajesP5.counter("p5_qa_feedbacks", -1)) == n - 1, "%s: la calibración no cuenta como dada (feedbacks %d)" % [caso, int(PersonajesP5.counter("p5_qa_feedbacks", -1))])
		# Vuelves a sentarte: sigue donde iba.
		await p5.call("_go_calibration", t)
		var otra: bool = await t.until(func() -> bool: return qa.state == QaFeedback.State.SESION, 8.0)
		t.check(otra and qa.resumed_from == i0 and qa.session == guion and str(qa.session.get("firma", "")) == firma, "%s: al volver NO empieza de nuevo: mismo guion, retomado en el beat %d (retoma %d)" % [caso, i0, qa.resumed_from])
		t.check(qa.anger == anger0 and qa.score_now == score0 and qa.heard_opportunities == heard0 and qa.beats_done.size() == hechos0, "%s: mismo enojo (%d), puntaje (%d), oportunidades (%d) y beats hechos (%d)" % [caso, qa.anger, qa.score_now, qa.heard_opportunities, qa.beats_done.size()])
		t.check(t.player().input_locked, "%s: mientras Haime te recibe no te puedes volver a parar" % caso)
		var actor := t.get_tree().get_first_node_in_group("p5_haime_actor")
		t.check(actor != null and bool(actor.call("door_locked")), "%s: echa el seguro otra vez" % caso)
		var dijo: bool = await t.until(func() -> bool: return qa.session_log.has("llegaste"), 20.0)
		t.check(dijo, "%s: y te lo dice («%s»)" % [caso, HaimeVoz.spoken("llegaste", "")])
		var mismo: bool = await t.until(func() -> bool: return int(qa.get("_beat_i")) == i0 and qa.beat_now == k0, 30.0)
		t.check(mismo and qa.clock <= clock0 + 3.0 and qa.clock >= clock0 - 0.5, "%s: sigue en el MISMO beat («%s») y volver no le quitó tiempo a la sesión (reloj %.1f s; al irte %.1f s)" % [caso, qa.beat_now, qa.clock, clock0])
		# Otra vez (cuando devuelva el control): tampoco reinicia.
		var libre: bool = await t.until(func() -> bool: return not t.player().input_locked and qa.state == QaFeedback.State.SESION and qa.beat_now != "", 60.0)
		var i1 := int(qa.get("_beat_i"))
		var anger1 := qa.anger
		if libre and not qa.call("_only_closing_left"):
			t.player().stand_up()
			await t.frames(4)
			await p5.call("_go_calibration", t)
			await t.until(func() -> bool: return qa.state == QaFeedback.State.SESION, 8.0)
			t.check(qa.resumed_from == i1 and qa.anger == anger1 and qa.walkouts == 2 and qa.session == guion, "%s: irte por segunda vez tampoco la reinicia (beat %d, enojo %d)" % [caso, qa.resumed_from, qa.anger])
		# Hasta el final: se da entera.
		var fin: bool = await t.until(func() -> bool: return qa.state == QaFeedback.State.LIBRE, 300.0)
		t.check(fin and qa.last_session_end == "dada" and int(PersonajesP5.counter("p5_qa_feedbacks", -1)) == n, "%s: termina y cuenta como dada (%s, feedbacks %d)" % [caso, qa.last_session_end, int(PersonajesP5.counter("p5_qa_feedbacks", -1))])
		t.check(qa.beats_done.size() == _beats_esperados(qa), "%s: no se saltó ni repitió ningún beat del guion (%d de %d; extras fuera de tiempo %s)" % [caso, qa.beats_done.size(), _beats_esperados(qa), str(qa.skipped)])
		await ph2.call("_back_to_desk", t)
		await t.back_to_menu()
	# Pararte cuando ya solo queda el cierre «da» la sesión (y antes, con todas las oportunidades oídas, ya no).
	var hub2: PersonajesP5 = await p5.call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	ph2.call("_quiet_p5", hub2)
	var qa2 := hub2.qa
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	qa2.test_answers = ["ok", "ok", "ok", "ok"]
	await ph2.call("_fatal_session_n", t, hub2)
	var oidas: bool = await t.until(func() -> bool: return qa2.heard_opportunities >= maxi(qa2.session_opportunities, 1) and qa2.beat_now != "" and not t.player().input_locked, 200.0)
	if oidas and not qa2.call("_only_closing_left"):
		var ib := int(qa2.get("_beat_i"))
		t.player().stand_up()
		await t.frames(4)
		t.check(qa2.last_session_end == "a_mitad" and qa2.state == QaFeedback.State.LLAMADO, "con las oportunidades oídas pero con guion por delante («%s»), pararte es irte a mitad (antes se daba por terminada y se saltaba el resto)" % str((qa2.session.get("beats", []) as Array)[ib].get("k", "")))
		await p5.call("_go_calibration", t)
		await t.until(func() -> bool: return qa2.state == QaFeedback.State.SESION, 8.0)
	var cierre: bool = await t.until(func() -> bool: return qa2.state == QaFeedback.State.SESION and bool(qa2.call("_only_closing_left")) and qa2.beat_now != "" and not t.player().input_locked, 240.0)
	t.check(cierre, "llega al cierre (beat «%s»)" % qa2.beat_now)
	if cierre:
		t.player().stand_up()
		await t.frames(4)
		var dada: bool = await t.until(func() -> bool: return qa2.state == QaFeedback.State.LIBRE, 30.0)
		t.check(dada and qa2.last_session_end == "dada", "pararte en el cierre sí la da por terminada (%s)" % qa2.last_session_end)
	await ph2.call("_back_to_desk", t)
	await t.back_to_menu()
	# La fatal: ni pararte ni «Reiniciar contacto»; no empieza de nuevo y termina en la muerte (nunca al entrar).
	var hub3: PersonajesP5 = await p5.call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	ph2.call("_quiet_p5", hub3)
	var qa3 := hub3.qa
	var seq: Array = t.spy("death_sequence_started")
	qa3.test_answers = ["ok", "ok"]
	await ph2.call("_fatal_session", t, hub3)
	t.check(qa3.state == QaFeedback.State.SESION and qa3.is_fatal(qa3.n_call) and seq.is_empty() and not Checkpoints.dying, "la fatal empieza como sesión: no mata al entrar")
	var guion3: Dictionary = qa3.session
	await t.until(func() -> bool: return qa3.session_log.size() >= 2 and not t.player().input_locked, 60.0)
	var max_i := int(qa3.get("_beat_i"))
	var retro := false
	for k in 3:
		t.player().stand_up()
		await t.frames(3)
		retro = retro or int(qa3.get("_beat_i")) < max_i or qa3.session != guion3 or qa3.state != QaFeedback.State.SESION
		max_i = maxi(max_i, int(qa3.get("_beat_i")))
		t.check(not Checkpoints.can_restart_contact(), "fatal: «Reiniciar contacto» no está disponible (intento %d)" % (k + 1))
		await t.seconds(2.0)
	t.check(not retro and t.player().seated and qa3.stand_attempts == 3 and qa3.resumed_from == -1, "fatal: tres intentos de pararte: sigues sentado, mismo guion, sin volver atrás (intentos %d)" % qa3.stand_attempts)
	var murio: bool = await t.until(func() -> bool: return not seq.is_empty(), 240.0)
	t.check(murio and str(seq[0][0]) == "calibracion_final" and str(seq[0][1]) == "haime" and qa3.beats_done.has("fatal"), "fatal: se da entera y termina en la muerte de Haime (%s; beats %d)" % [str(seq), qa3.beats_done.size()])
	await t.wait_death_shown(25.0)
	await t.back_to_menu()

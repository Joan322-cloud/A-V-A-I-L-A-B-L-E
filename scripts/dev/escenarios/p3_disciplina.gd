extends RefCounted
## Escenarios de P3 (Discipline): cada pista y cada escalón de SHERO_ESCALADA §2.2 con sus tiempos, cada causa
## de muerte con su asesino y su screamer, las salvaciones (lunch dormido, Fácil sentado), la reincidencia,
## dos verbales = un WW, tres WW = despido, congelamientos, dificultad y el reloj a 4x fuera de la sala.
## Tiempos de juego medidos con relojes adelantados de 10 s en 10 s (tolerancia ±15 s de juego).
## v0.3.2-core4: los minutos de cada escalón son los de balance.json/escalera (la tabla que aprobó Joan: en Normal
## break 10/11/12/13, lunch 45/46/47/48, correo 10/12/14/16, sala 0:30/1:30/2:30/3:30, otra isla 2/3/4/5, coaching
## 0/1/2/3, coaching excedido 1/2/3, no-show 0/1/2, regreso del training 3/4/5) y la reincidencia son las «marcas».

const TOL := 15.0


func escenarios() -> Array[String]:
	return [
		"dos_breaks", "tercer_break", "tercer_break_facil", "break_excedido", "break_corregido", "break_libre",
		"break_reincidencia", "dificil_plazos", "lunch_en_hora", "lunch_excedido:", "lunch_excedido_m1", "lunch_excedido_9",
		"lunch_dormido", "lunch_dormido_2", "lunch_avisos", "correo_10", "correo_excusa", "salir_sala", "salir_sala_vuelve",
		"agua_en_sala", "llamadas_perdidas", "otra_isla", "otra_isla_no_cuentan", "coaching_sin_permiso",
		"coaching_exceso", "coaching_autorizado", "coaching_noshow", "coaching_noshow_tarde", "coaching_noshow_rasec",
		"available_bajo", "available_ok", "shero_look", "ww_sin_ack_persecucion", "ack_lejos", "dos_verbales",
		"tercer_ww", "reincidencia_sala", "training_regreso", "feedback_congela", "topico", "topico_excedido",
		"tres_molestos", "reflejo_kyc", "reloj_4x", "owns_tracks", "facil_sentado", "presencia", "hud_p3",
		"no_hay_breaks_npc", "checkpoint_disciplina", "login_salto_reloj", "training_released_p5", "coaching_rasec_tm",
		"feedback_motivo_p5", "topico_p5",
	]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"dos_breaks": await _dos_breaks(t)
		"tercer_break": await _tercer_break(t, false)
		"tercer_break_facil": await _tercer_break(t, true)
		"break_excedido": await _break_excedido(t)
		"break_corregido": await _break_corregido(t)
		"break_libre": await _break_libre(t)
		"break_reincidencia": await _break_reincidencia(t)
		"dificil_plazos": await _dificil(t)
		"lunch_en_hora": await _lunch_en_hora(t)
		"lunch_excedido": await _lunch_excedido(t, int(arg) if arg.is_valid_int() else -1)
		"lunch_excedido_m1": await _lunch_excedido(t, -1)
		"lunch_excedido_9": await _lunch_excedido(t, 9)
		"lunch_dormido": await _lunch_dormido(t, false)
		"lunch_dormido_2": await _lunch_dormido(t, true)
		"lunch_avisos": await _lunch_avisos(t)
		"correo_10": await _correo_10(t)
		"correo_excusa": await _correo_excusa(t)
		"salir_sala": await _salir_sala(t)
		"salir_sala_vuelve": await _salir_sala_vuelve(t)
		"agua_en_sala": await _agua_en_sala(t)
		"llamadas_perdidas": await _perdidas(t)
		"otra_isla": await _otra_isla(t)
		"otra_isla_no_cuentan": await _otra_isla_no_cuentan(t)
		"coaching_sin_permiso": await _coaching_sin_permiso(t)
		"coaching_exceso": await _coaching_exceso(t)
		"coaching_autorizado": await _coaching_autorizado(t)
		"coaching_noshow": await _coaching_noshow(t, false)
		"coaching_noshow_tarde": await _coaching_noshow(t, true)
		"coaching_noshow_rasec": await _coaching_noshow_rasec(t)
		"available_bajo": await _available_bajo(t)
		"available_ok": await _available_ok(t)
		"shero_look": await _shero_look(t)
		"ww_sin_ack_persecucion": await _ww_sin_ack(t)
		"ack_lejos": await _ack_lejos(t)
		"dos_verbales": await _dos_verbales(t)
		"tercer_ww": await _tercer_ww(t)
		"reincidencia_sala": await _reincidencia_sala(t)
		"training_regreso": await _training_regreso(t)
		"feedback_congela": await _feedback_congela(t)
		"topico": await _topico(t)
		"topico_excedido": await _topico_excedido(t)
		"tres_molestos": await _tres_molestos(t)
		"reflejo_kyc": await _reflejo_kyc(t)
		"reloj_4x": await _reloj_4x(t)
		"owns_tracks": await _owns(t)
		"facil_sentado": await _facil_sentado(t)
		"presencia": await _presencia(t)
		"hud_p3": await _hud(t)
		"no_hay_breaks_npc": await _npc_breaks(t)
		"checkpoint_disciplina": await _checkpoint(t)
		"login_salto_reloj": await _login_salto(t)
		"training_released_p5": await _training_released_p5(t)
		"coaching_rasec_tm": await _coaching_rasec_tm(t)
		"feedback_motivo_p5": await _feedback_motivo_p5(t)
		"topico_p5": await _topico_p5(t)


# --- Utilidades ----------------------------------------------------------------------------------

## Turno con login en C-14, sin calma; dificultad 0 fácil · 1 normal · 2 difícil.
func _prep(t: Node, turno: int = 1, dif: int = 1, agent: String = "Jiroshi") -> void:
	await t.start_shift(agent, turno, 0, dif)
	await t.login_at_seat()
	GameState.stop_calm()
	GameState.clock_seconds = 0.5 * 3600.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.reset_shift()
	Fatigue.set_value(30.0)
	await t.frames(2)


## Registra cada discipline_step con la hora de juego: [[pista, escalón, reloj, info], …].
func _steps(t: Node) -> Array:
	var log_arr: Array = []
	var cb := func(track: String, step: int, info: Dictionary) -> void: log_arr.append([track, step, GameState.clock_seconds, info])
	EventBus.discipline_step.connect(cb)
	t.set_meta("p3_cb", cb)
	return log_arr


func _unspy(t: Node) -> void:
	if t.has_meta("p3_cb"):
		var cb: Callable = t.get_meta("p3_cb")
		if EventBus.discipline_step.is_connected(cb):
			EventBus.discipline_step.disconnect(cb)
		t.remove_meta("p3_cb")


## Adelanta el reloj de juego en pasos de 10 s (las pistas avanzan con clock_tick).
## v0.3.2-core4: va contra una hora objetivo: lo que el reloj corre solo en los cuadros de por medio se descuenta (con
## la máquina cargada era bastante y los escalones, ahora a un minuto uno de otro, caían donde la prueba no esperaba).
func _adv(t: Node, seconds: float, step: float = 10.0) -> void:
	var target := GameState.clock_seconds + seconds
	var n := 0
	while GameState.clock_seconds < target - 0.01:
		var s := minf(step, target - GameState.clock_seconds)
		GameState.clock_seconds += s
		EventBus.clock_tick.emit(GameState.clock_seconds)
		n += 1
		if n % 12 == 0:
			await t.frames(1)
	await t.frames(1)


## Hora de juego (s) a la que la pista llegó al escalón (o -1).
func _at(log_arr: Array, track: String, step: int) -> float:
	for e in log_arr:
		if str(e[0]) == track and int(e[1]) == step:
			return float(e[2])
	return -1.0


func _count(log_arr: Array, track: String, step: int = -1) -> int:
	var n := 0
	for e in log_arr:
		if str(e[0]) == track and (step < 0 or int(e[1]) == step):
			n += 1
	return n


## Comprueba que cada escalón llegó en su minuto (desde t0) ±TOL.
func _check_times(t: Node, log_arr: Array, track: String, t0: float, mins: Dictionary) -> void:
	for st in mins.keys():
		var at := _at(log_arr, track, int(st))
		var want := t0 + float(mins[st]) * 60.0
		t.check(at >= 0.0 and absf(at - want) <= TOL, "%s: escalón %d a los %.2f min (llegó a los %.2f)" % [track, int(st), float(mins[st]), (at - t0) / 60.0 if at >= 0.0 else -1.0])


func _posts(t: Node) -> Array:
	return t.spy("ezlak_post")


func _has_post(posts: Array, channel: String, author: String, pista: String = "") -> bool:
	for p in posts:
		if str(p[0]) == channel and str(p[1]) == author and (pista == "" or str((p[3] as Dictionary).get("pista", "")) == pista):
			return true
	return false


func _go(t: Node, floor_n: int, spawn: String = "ascensor") -> void:
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	t.building().go_to_floor(floor_n, spawn)
	await t.frames(4)


func _stand_in_room(t: Node) -> void:
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	await t.frames(3)


## Sale de la sala (de pie en el pasillo del agua del piso 2).
func _leave_room(t: Node) -> void:
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	var fl: Node3D = t.building().floor_node
	p.teleport(fl.global_position + Vector3(10.0, 0, 20.0), 90.0)
	await t.until(func() -> bool: return not GameState.in_room, 40.0)
	await t.frames(2)


func _back_in_room(t: Node) -> void:
	var p: Player = t.player()
	if t.building().current_floor != 2:
		t.building().go_to_floor(2, "pc")
		await t.frames(4)
	var fl := t.building().floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	if not p.seated and seat != null:
		p.sit_at(seat, "C-14")
	await t.until(func() -> bool: return GameState.in_room, 40.0)
	await t.frames(2)


## Espera la muerte y comprueba causa, asesino y screamer (o animación).
func _expect_death(t: Node, seq: Array, cause: String, killer: String, timeout: float = 90.0) -> void:
	var ok: bool = await t.until(func() -> bool: return Checkpoints.dying or not seq.is_empty(), timeout)
	t.check(ok and not seq.is_empty(), "muere (esperado %s)" % cause)
	if seq.is_empty():
		return
	var last: Array = seq[seq.size() - 1]
	if not t.check(str(last[0]) == cause, "causa %s (fue %s)" % [cause, str(last[0])]):
		t.note("historial: %s · WW %d (%s)" % [str(Discipline.counters.get("historial", [])), Metrics.written_warnings, Metrics.ack_reason])
	t.check(str(last[1]) == killer, "asesino %s (fue %s)" % [killer, str(last[1])])
	t.check(Screamers.has_row(cause), "%s tiene su fila de screamer" % cause)
	var shown: bool = await t.wait_death_shown(12.0)
	t.check(shown, "pantalla 'Usuario desconectado' tras el screamer de %s" % cause)


func _ack_now() -> void:
	if Metrics.ack_pending:
		Metrics.give_ack()


# --- Breaks --------------------------------------------------------------------------------------

func _dos_breaks(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var deaths: Array = t.spy("death_requested")
	var ww0 := Metrics.written_warnings
	for i in 2:
		Metrics.set_aux(Metrics.Aux.BREAK)
		await _leave_room(t)
		await _adv(t, 5.0 * 60.0)
		await _back_in_room(t)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await _adv(t, 60.0)
	await t.seconds(6.0)
	t.check(_has_post(posts, "dm:shero", "shero", "break_1"), "1.er break: DM de Shero ('No hay breaks, pero ok')")
	var edit_ok := false
	for p in posts:
		if str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("pista", "")) == "break_1" and (p[3] as Dictionary).has("edita"):
			edit_ok = true
	t.check(edit_ok, "el DM del 1.er break se edita después (Ezlaki 'editado')")
	t.check(_has_post(posts, "#team-familia", "shero", "break_2"), "2.º break: mensaje público en #team-familia")
	var lemas := 0
	for p in posts:
		if str(p[0]) == "#allocations" and str(p[1]) == "shero":
			lemas += 1
	t.check(lemas >= 2, "'No hay breaks.' en #allocations en cada break (%d)" % lemas)
	t.check(_count(log_arr, "break_2", 1) == 1 and int(Discipline.counters["llamados"]) == 1, "el 2.º break cuenta como llamado (llamados %d, %s)" % [int(Discipline.counters["llamados"]), str(Discipline.counters["historial"])])
	t.check(_count(log_arr, "break") == 0, "breaks de 5 min: la pista de break no avanza")
	t.check(Metrics.written_warnings == ww0 and deaths.is_empty(), "0 WW y 0 muertes (WW %d, muertes %d)" % [Metrics.written_warnings - ww0, deaths.size()])
	t.check(Metrics.breaks_used == 2, "Breaks 2/2")
	_unspy(t)


func _tercer_break(t: Node, facil: bool) -> void:
	await _prep(t, 1, 0 if facil else 1)
	var seq: Array = t.spy("death_sequence_started")
	for i in 2:
		Metrics.set_aux(Metrics.Aux.BREAK)
		await _adv(t, 60.0)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await _adv(t, 60.0)
	var t0 := Time.get_ticks_msec()
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(3)
	if facil:
		t.check(seq.is_empty() and Metrics.aux != Metrics.Aux.BREAK and Metrics.breaks_used == 2, "Fácil: el 3.er break pide confirmación (sin muerte, vuelve a Available)")
		Metrics.set_aux(Metrics.Aux.BREAK)
		await t.frames(3)
	# v0.3.1 (F5): ya no es muerte en el acto: Shero sale corriendo desde donde está, en el acto, y te alcanza.
	# «En el acto» se mide en cuadros: con la máquina cargada el reloj de pared × escala no dice nada.
	var nf := 0
	while nf < 10 and seq.is_empty() and not Pursuit.is_hunting("shero"):
		await t.frames(1)
		nf += 1
	var ok: bool = not seq.is_empty() or Pursuit.is_hunting("shero")
	var real := (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale
	t.check(ok, "Shero sale con la persecución en el acto (%d cuadros tras el break; %.2f s de juego con la máquina cargada)" % [nf, real])
	await _expect_death(t, seq, "tercer_break", "shero")


func _break_excedido(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	Metrics.set_aux(Metrics.Aux.BREAK)
	var t0 := GameState.clock_seconds
	await _go(t, 9, "ascensor")  # en la azotea: cualquier piso
	await _adv(t, t0 + 12.5 * 60.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, 50.0)
	_ack_now()
	_check_times(t, log_arr, "break", t0, {1: 10.0, 2: 11.0, 3: 12.0, 4: 13.0})
	t.check(_has_post(posts, "dm:shero", "shero", "break") and _has_post(posts, "#allocations", "shero", "break"), "llamado por DM y mención en #allocations")
	t.check(Pursuit.is_hunting("shero"), "a los 13:00 Shero sale con la amonestación (persecución)")
	await _expect_death(t, seq, "break_excedido", "shero", 60.0)
	_unspy(t)


func _break_corregido(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var deaths: Array = t.spy("death_requested")
	Metrics.set_aux(Metrics.Aux.BREAK)
	await _leave_room(t)
	await _adv(t, 11.5 * 60.0)
	await _back_in_room(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 10.0 * 60.0)
	t.check(_count(log_arr, "break", 2) == 1 and _count(log_arr, "break", 3) == 0, "volver a los 11:30: se detiene en el Verbal (sin WW)")
	t.check(deaths.is_empty() and not Pursuit.is_hunting(), "sin persecución ni muerte")
	t.check(Discipline.step_of("break") == 0, "la pista queda cerrada (escalón activo 0)")
	t.check(_count(log_arr, "sala") == 0, "fuera de la sala en Break no corre 'fuera de la sala'")
	_unspy(t)


func _break_libre(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await _go(t, 9, "ascensor")
	await _adv(t, 8.0 * 60.0)
	await _go(t, -1, "ascensor")
	await _adv(t, 1.0 * 60.0)
	t.check(log_arr.is_empty() or (_count(log_arr, "sala") == 0 and _count(log_arr, "break") == 0), "8 min de break en la azotea y el -1: 0 llamados (pasos %s)" % str(log_arr))
	_unspy(t)


func _break_reincidencia(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await _leave_room(t)
	await _adv(t, 10.5 * 60.0)
	await _back_in_room(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 60.0)
	t.check(Discipline.marks_of("break") == 1, "el primer exceso deja una marca")
	Metrics.set_aux(Metrics.Aux.BREAK)
	var t0 := GameState.clock_seconds
	await _leave_room(t)
	await _adv(t, t0 + 10.0 * 60.0 + 20.0 - GameState.clock_seconds)
	t.check(_count(log_arr, "break", 1) == 1, "la 2.ª vez no hay llamado")
	_check_times(t, log_arr, "break", t0, {2: 10.0})
	await _adv(t, 60.0)
	_check_times(t, log_arr, "break", t0, {3: 11.0})
	_ack_now()
	await _back_in_room(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 30.0)
	_unspy(t)


func _dificil(t: Node) -> void:
	await _prep(t, 1, 2)
	var log_arr := _steps(t)
	# P7: el límite de la regla (10 min de break, 45 de lunch, 10 de correo) no se acorta; se acorta lo que viene después.
	var th := Discipline.thresholds("break")
	t.check(is_equal_approx(float(th.get("llamado_min", 0.0)), 10.0) and is_equal_approx(float(th.get("verbal_min", 0.0)), 10.75) and is_equal_approx(float(th.get("persecucion_min", 0.0)), 12.25), "Difícil: el break sigue durando 10 min y la escalera después va ×0,75 (10 · 10:45 · 11:30 · 12:15: %s)" % str(th))
	t.check(is_equal_approx(float(Discipline.thresholds("lunch").get("llamado_min", 0.0)), 45.0) and is_equal_approx(float(Discipline.thresholds("lunch").get("persecucion_min", 0.0)), 47.25), "Difícil: lunch 45 min y persecución a los 47:15")
	t.check(is_equal_approx(float(Discipline.thresholds("sala").get("persecucion_min", 0.0)), 2.65), "Difícil: sin límite de regla (sala) la persecución sale a los 2:39 (Normal 3:30)")
	Metrics.set_aux(Metrics.Aux.BREAK)
	var t0 := GameState.clock_seconds
	await _leave_room(t)
	await _adv(t, t0 + 11.0 * 60.0 - GameState.clock_seconds)
	_check_times(t, log_arr, "break", t0, {1: 10.0, 2: 10.75})
	_unspy(t)
	await t.back_to_menu()
	await _prep(t, 1, 0)
	t.check(is_equal_approx(float(Discipline.thresholds("sala").get("persecucion_min", 0.0)), 5.25), "Fácil: plazos ×1,5 (sala 3:30 → 5:15)")


# --- Lunch ----------------------------------------------------------------------------------------

func _lunch_en_hora(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	GameState.clock_seconds = GameState.lunch_clock() - 60.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await _adv(t, 60.0)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await _go(t, -1, "cafeteria")
	await _adv(t, 40.0 * 60.0, 20.0)
	await _back_in_room(t)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 60.0)
	var esc := 0
	for e in log_arr:
		if int(e[1]) > 0:
			esc += 1
	t.check(esc == 0, "lunch a su hora de 40 min: 0 escalones (%s)" % str(log_arr))
	_unspy(t)


func _lunch_excedido(t: Node, floor_n: int) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	var t0 := GameState.clock_seconds
	await _go(t, floor_n, "cafeteria" if floor_n == -1 else ("cafeteria_azotea" if floor_n == 9 else "ascensor"))
	await _adv(t, t0 + 47.5 * 60.0 - GameState.clock_seconds)  # pasos de 10 s (< TOL): con 20 s el escalón podía caer hasta 20 s tarde según la fase
	_ack_now()
	await _adv(t, 50.0)
	_ack_now()
	_check_times(t, log_arr, "lunch", t0, {1: 45.0, 2: 46.0, 3: 47.0, 4: 48.0})
	t.check(Pursuit.is_hunting("shero"), "persecución a los 48:00 en el piso %d" % floor_n)
	await _expect_death(t, seq, "lunch_excedido", "shero", 80.0)
	_unspy(t)


func _lunch_dormido(t: Node, second: bool) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var ends: Array = t.spy("pursuit_ended")
	if second:
		Discipline.counters["perdon_dormido"] = true
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await _go(t, -1, "descanso_m1")
	await _adv(t, 51.5 * 60.0, 20.0)
	_ack_now()
	var puff := t.building().floor_node.find_child("Dormir_puff_1", true, false) as SleepSpot
	t.check(puff != null, "hay un puff para dormir en el -1")
	if puff == null:
		return
	puff.interact(t.player())
	await t.frames(3)
	t.check(SleepSpot.is_player_sleeping(), "dormido en el puff")
	var ww0 := Metrics.written_warnings
	await _adv(t, 2.5 * 60.0 + 20.0)
	t.check(Pursuit.is_hunting("shero"), "persecución del lunch con el jugador dormido")
	if not second:
		var ok: bool = await t.until(func() -> bool: return not ends.is_empty(), 70.0)
		t.check(ok and str(ends[0][1]) == "perdonado", "Shero lo encuentra dormido y lo perdona (%s)" % str(ends))
		t.check(seq.is_empty(), "0 muertes")
		t.check(Metrics.written_warnings == ww0 + 1, "a cambio, un WW ('dormir en horario laboral') (%d → %d)" % [ww0, Metrics.written_warnings])
		t.check(bool(Discipline.counters.get("perdon_dormido", false)), "el perdón queda usado en el turno")
		t.check(not SleepSpot.is_player_sleeping() and Metrics.aux == Metrics.Aux.AVAILABLE, "lo despierta y lo pone en Available ('Sube.')")
		_ack_now()
	else:
		await _expect_death(t, seq, "lunch_excedido", "shero", 80.0)


func _lunch_avisos(t: Node) -> void:
	await _prep(t)
	var posts := _posts(t)
	GameState.clock_seconds = GameState.lunch_clock() - 6.0 * 60.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await _adv(t, 2.0 * 60.0)
	await t.seconds(4.0)
	var hora := false
	for p in posts:
		if str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("escalon", "")) == "hora":
			hora = true
	t.check(hora, "5 min antes de la hora del lunch: DM 'Tu lunch es a las…'")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await _adv(t, 20.0)
	await t.seconds(4.0)
	var ini := false
	for p in posts:
		if str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("escalon", "")) == "inicio":
			ini = true
	t.check(ini, "al poner Lunch: 'Cuarenta y cinco minutos. Te los estoy contando.'")


# --- Correo -----------------------------------------------------------------------------------------

## Abre un caso de BO (correo) y lo deja sin trabajar.
func _open_case(t: Node) -> ContactManager:
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	var cases: Array = (DataLoader.dict("casos_bo").get("turnos", {}) as Dictionary).get("1", [])
	var c: Dictionary = {}
	for x in cases:
		if str(x.get("canal", "")) != "kyc":
			c = (x as Dictionary).duplicate(true)
			break
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c)
	await t.frames(2)
	cm.accept()
	await t.frames(2)
	return cm


func _correo_10(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	var cm := await _open_case(t)
	t.check(cm.case != null, "caso de BO abierto (correo)")
	var t0 := GameState.clock_seconds
	await _adv(t, 12.0 * 60.0 + 10.0)
	var sh := t.get_tree().get_first_node_in_group("shero") as Shero
	await t.until(func() -> bool: return sh != null and sh.state == Shero.State.COACHING, 20.0)
	var dd := sh.global_position.distance_to(t.player().global_position) if sh != null else -1.0
	t.check(sh != null and dd < 3.0, "12:00: Shero está detrás de tu silla (%.1f m, se ve en el reflejo)" % dd)
	await _adv(t, t0 + 14.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, t0 + 16.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	_check_times(t, log_arr, "correo", t0, {1: 10.0, 2: 12.0, 3: 14.0, 4: 16.0})
	var excusa := false
	for p in posts:
		if str(p[0]) == "dm:shero" and str((p[3] as Dictionary).get("pista", "")) == "correo" and ((p[3] as Dictionary).get("quick_replies", []) as Array).has("excusa_2"):
			excusa = true
	t.check(excusa, "10:00: DM '¿Qué tomó tanto?' con las 3 excusas")
	t.check(_has_post(posts, "#allocations", "shero", "correo"), "14:00: 'casos de más de 10 min' en #allocations")
	await _expect_death(t, seq, "aht_bo", "shero", 40.0)
	_unspy(t)


func _correo_excusa(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var cm := await _open_case(t)
	var hub := EzlakHub.get_hub(t.get_tree())
	var t0 := GameState.clock_seconds
	await _adv(t, 10.0 * 60.0 + 10.0)
	hub.quick_reply("dm:shero", "excusa_1")
	await t.frames(2)
	t.check(_at(log_arr, "correo", 2) >= 0.0 and _at(log_arr, "correo", 2) - t0 < 11.0 * 60.0, "excusa equivocada: salta directo al Verbal")
	cm.close_case()
	await t.frames(2)
	t.check(Discipline.step_of("correo") == 0, "cerrar el caso corta la escalera")
	_unspy(t)
	await t.back_to_menu()
	await _prep(t)
	log_arr = _steps(t)
	cm = await _open_case(t)
	hub = EzlakHub.get_hub(t.get_tree())
	await _adv(t, 10.0 * 60.0 + 10.0)
	hub.quick_reply("dm:shero", "excusa_2")
	await _adv(t, 1.5 * 60.0)
	t.check(_count(log_arr, "correo", 2) == 0, "excusa correcta: queda en llamado (alerta) hasta las 12:00")
	_unspy(t)


# --- Sala ----------------------------------------------------------------------------------------------

func _salir_sala(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	await _leave_room(t)
	t.check(not GameState.in_room, "fuera de la sala")
	t.check(GameState.clock_speed() <= 4.01, "de pie fuera de la sala: reloj a 4x (%.1fx)" % GameState.clock_speed())
	var t0 := GameState.clock_seconds
	await _adv(t, t0 + 3.0 * 60.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, 45.0)
	_check_times(t, log_arr, "sala", t0, {1: 0.5, 2: 1.5, 3: 2.5, 4: 3.5})
	t.check(_has_post(posts, "dm:shero", "shero", "sala"), "0:30: '¿A dónde vas? No tienes AUX.'")
	await _expect_death(t, seq, "abandono", "shero", 40.0)
	_unspy(t)


func _salir_sala_vuelve(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	await _leave_room(t)
	await _adv(t, 60.0)
	await _back_in_room(t)
	await _adv(t, 8.0 * 60.0)
	t.check(_count(log_arr, "sala", 1) == 1 and _count(log_arr, "sala", 2) == 0, "volver al minuto: solo el llamado")
	t.check(not Pursuit.is_hunting(), "sin persecución")
	_unspy(t)


## Llegar a las 23:48 y loguearse de pie fuera de la sala: el reloj salta a 00:00 y esos 12 min no son de la pista.
func _login_salto(t: Node) -> void:
	await t.start_shift("Jiroshi", 1, 0, 1)
	GameState.stop_calm()
	await _go(t, 2)
	await _leave_room(t)
	var log_arr := _steps(t)
	GameState.clock_seconds = -12.0 * 60.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	GameState.login()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await t.frames(2)
	t.check(GameState.logged_in and GameState.clock_seconds >= 0.0, "logueado a las 00:00")
	t.check(log_arr.is_empty() and not Pursuit.is_hunting(), "el salto 23:48 → 00:00 no da escalones (%d)" % log_arr.size())
	var r: Dictionary = Discipline.debug_run().get("sala", {})
	# v0.3.1: < 30 s y no < 1: con la máquina cargada 2 cuadros a 4x ya son unos segundos; lo que importa es que no se
	# lleve los 12 min del salto 23:48 → 00:00.
	t.check(not r.is_empty() and float(r["t"]) < 30.0, "la pista 'sala' arranca en 0 (%.0f s)" % float(r.get("t", -1.0)))
	await _adv(t, 70.0)
	t.check(_count(log_arr, "sala", 1) == 1 and _count(log_arr, "sala", 2) == 0, "y el llamado llega al minuto, no antes")
	_unspy(t)


## P5: el Trainer te suelta con PersonajesP5.training_released (sin EventBus.training_ended): corre la vuelta.
func _training_released_p5(t: Node) -> void:
	await _prep(t, 2)
	var log_arr := _steps(t)
	var hub := Node.new()
	hub.name = "PersonajesP5Falso"
	hub.add_user_signal("training_released")
	hub.add_to_group("p5_personajes")
	t.get_tree().root.add_child(hub)
	await t.frames(40)  # Discipline lo engancha (mira cada 30 frames)
	await _go(t, 1, "ascensor")
	Discipline.freeze(true, "training")
	t.check(Discipline.is_frozen() and Discipline.freeze_reasons().has("training"), "freeze(true, 'training') de P5: congelado")
	Discipline.freeze(false, "training")
	hub.emit_signal("training_released")
	EventBus.training_ended.emit(true)  # P5 emite las dos: la pista arranca una vez
	await t.frames(2)
	t.check(not Discipline.debug_run().get("training_regreso", {}).is_empty(), "training_released: arranca la vuelta tardía")
	var t0 := GameState.clock_seconds
	await _adv(t, t0 + 3.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_check_times(t, log_arr, "training_regreso", t0, {1: 3.0})
	t.check(_count(log_arr, "training_regreso", 1) == 1, "una sola escalera aunque lleguen las dos señales")
	await _back_in_room(t)
	await t.frames(2)
	t.check(Discipline.debug_run().get("training_regreso", {}).is_empty(), "volver a la sala la corta")
	hub.queue_free()
	_unspy(t)


## Rasec convoca un coaching (Rooms): la sesión se autoriza con la fuente "tm"; al terminar, si sigues en
## Coaching corre "coaching excedido" (Rasec). Unirse no deja escalones de "coaching sin permiso".
func _coaching_rasec_tm(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	var subs: Array = t.spy("subtitle")
	Discipline.request_coaching("rasec")
	await t.frames(3)
	var hub := EzlakHub.get_hub(t.get_tree())
	t.check(hub.rooms_pending and hub.rooms_from == "rasec", "invitación de Rasec a Rooms")
	hub.join_rooms()
	await t.frames(3)
	var a := Metrics.authorization_of("tm")
	t.check(Discipline.session_active() and not a.is_empty() and int(a.get("aux", -1)) == Metrics.Aux.COACHING, "sesión de Rasec: Coaching autorizado con la fuente 'tm'")
	t.check(Metrics.aux == Metrics.Aux.COACHING and Discipline.is_frozen(), "AUX Coaching y todo congelado")
	var ok: bool = await t.until(func() -> bool: return not Discipline.session_active(), 80.0)
	t.check(ok and Metrics.authorization_of("tm").is_empty(), "al terminar se revoca 'tm'")
	var rasec_spoke := false
	for e in subs:
		if str(e[0]) == "rasec":
			rasec_spoke = true
	t.check(rasec_spoke, "habla Rasec (Rooms)")
	t.check(_at(log_arr, "coaching", 1) < 0.0 and _at(log_arr, "coaching_noshow_rasec", 2) < 0.0, "ni 'sin permiso' ni no-show")
	var t0 := GameState.clock_seconds
	await _adv(t, 1.0 * 60.0 + 20.0)
	_check_times(t, log_arr, "coaching_exceso", t0, {1: 1.0})
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(seq.is_empty() and Discipline.debug_run().get("coaching_exceso", {}).is_empty(), "volver a Available corta el exceso")
	_unspy(t)


## Haime (P5) congela con freeze(true, "feedback") y además emite qa_feedback_started: un solo motivo.
func _feedback_motivo_p5(t: Node) -> void:
	await _prep(t)
	EventBus.qa_feedback_started.emit(1)
	Discipline.freeze(true, "feedback")
	t.check(Discipline.freeze_reasons() == ["feedback"], "un motivo ('feedback'): %s" % str(Discipline.freeze_reasons()))
	Discipline.freeze(false, "feedback")
	t.check(not Discipline.is_frozen(), "freeze(false, 'feedback') de P5 descongela aunque no llegue qa_feedback_ended")
	EventBus.qa_feedback_ended.emit(1)
	t.check(not Discipline.is_frozen(), "y qa_feedback_ended después no rompe nada")


## Contrato del tópico con P5: si TopicoControl existe, P3 no da permiso ni persigue (lo hace P5 y su
## persecución delega en Pursuit); "topico_excedido" sigue siendo de P3.
func _topico_p5(t: Node) -> void:
	await _prep(t)
	t.check(Discipline.owns_track("topico_excedido"), "topico_excedido es de P3")
	var p5 := false
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "TopicoControl":
			p5 = true
	t.check(Discipline.owns_track("topico") == not p5, "owns_track('topico') = %s (TopicoControl %s)" % [str(not p5), "presente" if p5 else "ausente"])
	if p5:
		var auth0 := Metrics.authorizations.size()
		EventBus.topico_requested.emit()
		await t.frames(2)
		t.check(Metrics.authorizations.size() <= auth0 + 1, "P3 no duplica el permiso de P5")


func _agua_en_sala(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.set_process(false)  # sin contactos ofrecidos
	await _stand_in_room(t)
	var fl: Node3D = t.building().floor_node
	t.player().teleport(fl.global_position + Vector3(22.0, 0, 0.4), 0.0)
	await t.frames(4)
	var disp := fl.find_child("DispensadorSala", true, false) as Interactable
	if disp != null:
		disp.interact(t.player())
	await _adv(t, 5.0 * 60.0)
	t.check(GameState.in_room and log_arr.is_empty(), "5 min de pie en la sala (dispensador) sin contactos: 0 escalones (%s)" % str(log_arr))
	cm.set_process(true)
	_unspy(t)


# --- Llamadas perdidas ---------------------------------------------------------------------------------

func _perdidas(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	await _stand_in_room(t)
	var call: Dictionary = (DataLoader.dict("contactos_t1").get("contactos", [])[0] as Dictionary).duplicate(true)
	var ring := float(DataLoader.dict("casos_bo").get("reglas", {}).get("timbre_s_real", 14.0)) * Difficulty.scale("plazos")
	for n in 4:
		cm.phase = ContactManager.Phase.IDLE
		var cc := call.duplicate(true)
		cc["id"] = "p3_perdida_%d" % n
		cm._offer(cc)
		await t.until(func() -> bool: return cm.phase != ContactManager.Phase.OFFERING, ring + 4.0)
		await t.frames(3)
		_ack_now()
	t.check(_count(log_arr, "llamadas_perdidas", 1) == 1 and _count(log_arr, "llamadas_perdidas", 2) == 1 and _count(log_arr, "llamadas_perdidas", 3) == 1 and _count(log_arr, "llamadas_perdidas", 4) == 1, "1.ª llamado · 2.ª verbal · 3.ª WW · 4.ª persecución")
	t.check(_has_post(posts, "#allocations", "shero", "llamadas_perdidas"), "'¡Contesten esas llamadas!' en #allocations")
	t.check(ContactManager.discipline_owns("llamadas_perdidas"), "P4 deja la pista a P3 (owns_track)")
	await _expect_death(t, seq, "llamadas_perdidas", "shero", 40.0)
	_unspy(t)


# --- Otra isla -------------------------------------------------------------------------------------

func _otra_isla(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.set_process(false)
	t.player().stand_up()
	var seat := (t.building().floor_node as FloorBase).seat_by_id("E-07")
	t.player().sit_at(seat, "E-07")
	await t.frames(3)
	GameState.queue_size = 0
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE and GameState.seated_at == "E-07", "sentado en E-07, Available, sin cola")
	t.check(is_equal_approx(GameState.clock_speed(), float(DataLoader.bal("reloj/de_pie_aux", 4.0))), "otra isla: el reloj corre a 4x, nunca a 45x (%.1fx)" % GameState.clock_speed())
	# Reloj real: el llamado llega a los 2 min de juego medidos a 4x (30 s reales).
	var t0 := GameState.clock_seconds
	var r0 := Time.get_ticks_msec()
	var ok: bool = await t.until(func() -> bool: return _at(log_arr, "otra_isla", 1) >= 0.0, 200.0)
	var real := (Time.get_ticks_msec() - r0) / 1000.0 * Engine.time_scale
	t.check(ok, "llamado de la pista otra_isla")
	t.check(absf((_at(log_arr, "otra_isla", 1) - t0) / 60.0 - 2.0) < 0.3, "llamado a los 2 min de juego (%.2f)" % ((_at(log_arr, "otra_isla", 1) - t0) / 60.0))
	t.check(real > 22.0 and real < 50.0, "≈ 30 s reales (%.0f s): medido a 4x" % real)
	t.check(_has_post(posts, "#team-familia", "shero", "otra_isla"), "2:00: 'Las únicas personas en la isla son…' en #team-familia")
	var texto_ok := false
	for p in posts:
		if str(p[0]) == "#team-familia" and str((p[3] as Dictionary).get("pista", "")) == "otra_isla":
			texto_ok = str(p[2]).contains("3 min")
	t.check(texto_ok, "y el mensaje dice los minutos que quedan de verdad (3)")
	await _adv(t, t0 + 4.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, t0 + 5.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	_check_times(t, log_arr, "otra_isla", t0, {2: 3.0, 3: 4.0, 4: 5.0})
	await _expect_death(t, seq, "otra_isla", "shero", 40.0)
	cm.set_process(true)
	_unspy(t)


func _otra_isla_no_cuentan(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	await t.frames(2)
	t.check(not Discipline._other_island("C-10") and not Discipline._other_island("training_sala2_3") and not Discipline._other_island("calibracion"), "C-xx, training y calibración no son 'otra isla'")
	t.check(Discipline._other_island("E-07") and Discipline._other_island("A-03") and Discipline._other_island("F-12"), "E-07, A-03 y F-12 sí")
	await _go(t, 1, "ascensor")
	var ts := t.building().floor_node.find_child("Seat_training_sala2_3", true, false) as Node3D
	if ts != null:
		Metrics.authorize(Metrics.Aux.TRAINING, "trainer", "piso_1", 30.0)
		t.player().sit_at(ts, "training_sala2_3")
		await _adv(t, 12.0 * 60.0)
		t.check(_count(log_arr, "otra_isla") == 0, "sentado en la sala 2 de training (con permiso): no corre otra isla")
	else:
		t.check(true, "(sin asiento de training en este build)")
	_unspy(t)


# --- Coaching ----------------------------------------------------------------------------------------

func _coaching_sin_permiso(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	var t0 := GameState.clock_seconds
	Metrics.set_aux(Metrics.Aux.COACHING)
	await t.frames(2)
	await _adv(t, t0 + 2.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, 50.0)
	_check_times(t, log_arr, "coaching", t0, {1: 0.0, 2: 1.0, 3: 2.0, 4: 3.0})
	var exe_ok := true
	for e in log_arr:
		if str(e[0]) == "coaching" and str((e[3] as Dictionary).get("ejecutor", "")) != "rasec":
			exe_ok = false
	t.check(exe_ok, "todos los escalones los ejecuta Rasec")
	t.check(_has_post(posts, "dm:rasec", "rasec", "coaching"), "DM de Rasec: '¿Coaching? ¿Con quién?'")
	t.check(not Pursuit.is_hunting("shero"), "Shero no persigue (es de Rasec)")
	await _expect_death(t, seq, "coaching_sin_permiso", "rasec", 20.0)
	_unspy(t)


func _session(t: Node) -> void:
	Discipline.request_coaching("shero")
	await t.frames(3)
	var hub := EzlakHub.get_hub(t.get_tree())
	t.check(hub.rooms_pending, "invitación a Ezlaki Rooms")
	hub.join_rooms()
	await t.frames(3)


func _coaching_autorizado(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var avl0 := Metrics.available_pct()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 30.0 * 60.0)
	var c0 := GameState.clock_seconds
	await _session(t)
	t.check(Discipline.session_active() and Metrics.aux == Metrics.Aux.COACHING and Metrics.is_aux_authorized(Metrics.Aux.COACHING), "sesión de Shero: AUX Coaching autorizado")
	t.check(Discipline.is_frozen() and GameState.clock_override == "coaching_sesion", "durante la sesión todo se congela (reloj coaching_sesion)")
	var tia := float(Metrics.time_in_aux[Metrics.Aux.AVAILABLE]) + float(Metrics.time_in_aux[Metrics.Aux.BO])
	var ok: bool = await t.until(func() -> bool: return not Discipline.session_active(), 80.0)
	t.check(ok, "la sesión termina (~60 s reales)")
	var mins := (GameState.clock_seconds - c0) / 60.0
	t.check(mins > 4.0 and mins < 6.5, "dura ~5 min de juego (%.1f)" % mins)
	t.check(is_equal_approx(float(Metrics.time_in_aux[Metrics.Aux.AVAILABLE]) + float(Metrics.time_in_aux[Metrics.Aux.BO]), tia), "Available congelado durante la sesión")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 5.0 * 60.0)
	var esc := 0
	for e in log_arr:
		# v0.3.1: con la máquina cargada una llamada que suena en estos 5 min (nadie la contesta en la prueba) puede
		# perderse por tiempo real: no es de la sesión de coaching, que es lo que se prueba.
		if int(e[1]) > 0 and str(e[0]) != "llamadas_perdidas":
			esc += 1
	t.check(esc == 0 and not Discipline.is_frozen(), "0 escalones (%s)" % str(log_arr))
	if avl0 < 0.0:
		pass
	_unspy(t)


func _coaching_exceso(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	await _session(t)
	await t.until(func() -> bool: return not Discipline.session_active(), 80.0)
	var t0 := GameState.clock_seconds
	t.check(Metrics.aux == Metrics.Aux.COACHING and _at(log_arr, "coaching", 1) < 0.0, "sigue en Coaching al terminar: NO es 'sin permiso'")
	await _adv(t, 3.0 * 60.0 + 20.0)
	_check_times(t, log_arr, "coaching_exceso", t0, {1: 1.0, 2: 2.0, 4: 3.0})
	await _expect_death(t, seq, "coaching_exceso", "rasec", 20.0)
	_unspy(t)


func _coaching_noshow(t: Node, late: bool) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	var deaths: Array = t.spy("death_requested")
	Discipline.request_coaching("shero", 4.0)
	var ok: bool = await t.until(func() -> bool: return _at(log_arr, "coaching_noshow", 2) >= 0.0, 12.0)
	t.check(ok, "al vencer Rooms (60 s reales; aquí 4): Verbal")
	t.check(deaths.is_empty(), "vencer Rooms ya no mata al instante")
	var t0 := GameState.clock_seconds
	if late:
		EzlakHub.get_hub(t.get_tree()).join_rooms()
		await t.frames(3)
		await _adv(t, 5.0 * 60.0)
		t.check(_count(log_arr, "coaching_noshow", 3) == 0 and not Pursuit.is_hunting(), "unirse tarde corta la escalera")
		t.check(Discipline.session_active(), "y empieza la sesión")
		_unspy(t)
		return
	await _adv(t, t0 + 1.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_ack_now()
	await _adv(t, 50.0)
	_check_times(t, log_arr, "coaching_noshow", t0, {3: 1.0, 4: 2.0})
	await _expect_death(t, seq, "coaching", "shero", 40.0)
	_unspy(t)


func _coaching_noshow_rasec(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	Discipline.request_coaching("rasec", 4.0)
	await t.until(func() -> bool: return _at(log_arr, "coaching_noshow_rasec", 2) >= 0.0, 12.0)
	await _adv(t, 2.0 * 60.0 + 10.0)
	_ack_now()
	await _adv(t, 2.0 * 60.0 + 10.0)
	t.check(_count(log_arr, "coaching_noshow_rasec", 4) == 1, "coaching de Rasec no atendido: verbal, WW y muerte a los +4")
	await _expect_death(t, seq, "coaching", "rasec", 20.0)
	_unspy(t)


# --- Available (lista del Mentor) -----------------------------------------------------------------------

func _available_bajo(t: Node) -> void:
	await _prep(t, 2)
	GameState.clock_seconds = 1.6 * 3600.0  # después de la lista de las 01:30 (las listas se publican a mano)
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.reset_shift()
	await t.frames(2)
	var log_arr := _steps(t)
	var posts := _posts(t)
	var seq: Array = t.spy("death_sequence_started")
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(mentor != null, "el Mentor existe")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 30.0 * 60.0)
	Metrics.set_aux(Metrics.Aux.BO)
	await _adv(t, 30.0 * 60.0)
	t.check(log_arr.is_empty(), "entre listas, 0 escalones aunque el %% baje (%d %%)" % int(Metrics.available_pct()))
	mentor.post_list_now()
	await t.frames(2)
	t.check(_count(log_arr, "available", 2) == 1, "1.ª lista bajo 70 %%: verbal")
	await t.seconds(4.0)
	t.check(_has_post(posts, "dm:shero", "shero", "available"), "y DM personal")
	mentor.post_list_now()
	await t.frames(2)
	t.check(_count(log_arr, "available", 3) == 1, "2.ª lista bajo 70 %%: WW")
	_ack_now()
	var hunts: Array = t.spy("pursuit_started")
	mentor.post_list_now()
	await t.frames(2)
	# v0.3.1: con la máquina cargada Shero (a 4,9 m de C-14) puede alcanzarte antes de estos 2 cuadros: vale que la
	# persecución haya empezado.
	var shero_hunt := Pursuit.is_hunting("shero") or hunts.any(func(h: Array) -> bool: return str(h[0]) == "shero")
	t.check(_count(log_arr, "available", 4) == 1 and shero_hunt, "3.ª lista: amonestación (persecución)")
	await _expect_death(t, seq, "available_bajo", "shero", 40.0)
	t.check(str(seq[seq.size() - 1][2]).is_valid_int() if not seq.is_empty() else false, "el motivo lleva el %% (%s)" % (str(seq[seq.size() - 1][2]) if not seq.is_empty() else "?"))
	_unspy(t)


func _available_ok(t: Node) -> void:
	await _prep(t, 2)
	var log_arr := _steps(t)
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _adv(t, 40.0 * 60.0)
	mentor.post_list_now()
	await _adv(t, 60.0)
	t.check(_count(log_arr, "available") == 0, "lista con Available ≥ 70 %%: nada (%d %%)" % int(Metrics.available_pct()))
	_unspy(t)


# --- Look, Ack, WW ---------------------------------------------------------------------------------

func _shero_look(t: Node) -> void:
	await _prep(t)
	var sh := t.get_tree().get_first_node_in_group("shero") as Shero
	t.check(sh != null, "Shero en el piso 2")
	await t.seconds(0.6)
	t.check(sh.look == "afro" and not sh.bald, "normal: afro")
	Discipline.debug_start("sala", 0.0)
	Discipline.debug_fire("sala", 2)
	await t.seconds(0.6)
	t.check(sh.look == "afro", "verbal: todavía afro")
	Discipline.debug_fire("sala", 3)
	await t.seconds(0.6)
	t.check(sh.look == "calvo" and sh.bald, "desde el WW: calvo (bandera Shero.bald para P6)")
	_ack_now()
	GameState.start_calm(5.0)
	await t.seconds(0.6)
	t.check(sh.look == "afro", "con la calma vuelve el afro")
	GameState.stop_calm()
	var row := Screamers.row_for("shero", "break_excedido")
	t.check(str(row.get("look", "")) == "calvo", "screamers de Shero: look calvo")


func _ww_sin_ack(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	var deaths: Array = t.spy("death_requested")
	var starts: Array = t.spy("pursuit_started")
	Metrics.issue_written_warning("abandono")
	var w := Metrics.ack_left
	t.check(w > 7.0 and w < 9.0, "en tu PC: Ack de 8 s (%.1f)" % w)
	await t.until(func() -> bool: return not Metrics.ack_pending, 12.0)
	await t.frames(2)
	t.check(deaths.is_empty() or str(deaths[0][0]) != "ww_sin_ack" or not starts.is_empty(), "vencer el Ack ya no mata al instante")
	t.check(not starts.is_empty() and str(starts[0][1]) == "ww_sin_ack", "inicia la persecución ww_sin_ack")
	await _expect_death(t, seq, "ww_sin_ack", "shero", 40.0)


func _ack_lejos(t: Node) -> void:
	await _prep(t)
	await _go(t, 9, "ascensor")
	Metrics.issue_written_warning("abandono")
	t.check(Metrics.ack_left > 50.0, "lejos de tu PC: 60-90 s para llegar a una PC (%.1f)" % Metrics.ack_left)
	await t.frames(3)
	var hud: Node = t.main.get_node("UI/HUD")
	var lbl := ""
	for c in hud.get_children():
		if c is Label and str((c as Label).text).contains("Ack") and str((c as Label).text).contains("PC"):
			lbl = (c as Label).text
	t.check(lbl != "", "el HUD avisa: 'Ack desde tu PC o cualquier PC de la sala' (v0.3.2: sin terminales) (%s)" % lbl)
	_ack_now()
	t.check(not Metrics.ack_pending, "Ack dado")


func _dos_verbales(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var ww0 := Metrics.written_warnings
	await _leave_room(t)
	await _adv(t, 1.5 * 60.0 + 20.0)
	await _back_in_room(t)
	await _adv(t, 60.0)
	t.check(_count(log_arr, "sala", 2) == 1 and Metrics.written_warnings == ww0, "1.er verbal: sin WW")
	Metrics.set_aux(Metrics.Aux.BREAK)
	var tb := GameState.clock_seconds
	await _leave_room(t)
	await _adv(t, tb + 11.0 * 60.0 + 20.0 - GameState.clock_seconds)
	t.check(_count(log_arr, "dos_verbales", 3) == 1 and Metrics.written_warnings == ww0 + 1, "2.º verbal (de otra pista): WW automático ('dos verbales hacen un escrito')")
	_ack_now()
	_unspy(t)


func _tercer_ww(t: Node) -> void:
	await _prep(t)
	var seq: Array = t.spy("death_sequence_started")
	Metrics.issue_written_warning("abandono")
	_ack_now()
	Metrics.issue_written_warning("aht_bo")
	_ack_now()
	Discipline.debug_start("sala", 0.0)
	Discipline.debug_fire("sala", 3)
	await _expect_death(t, seq, "tercer_ww", "shero", 10.0)


func _reincidencia_sala(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	for i in 2:
		await _leave_room(t)
		await _adv(t, 60.0)
		await _back_in_room(t)
		await _adv(t, 60.0)
	t.check(_count(log_arr, "sala", 1) == 1 and _count(log_arr, "sala", 2) == 1 and _count(log_arr, "sala", 3) == 0, "1.ª vez llamado; 2.ª vez (una marca) empieza en verbal, a 0:30")
	t.check(Discipline.marks_of("sala") == 2, "dos marcas de «sitio»")
	await _leave_room(t)
	var t0 := GameState.clock_seconds
	await _adv(t, 50.0)
	t.check(_at(log_arr, "sala", 3) >= 0.0 and absf(_at(log_arr, "sala", 3) - t0 - 30.0) <= TOL + 10.0 and _count(log_arr, "sala", 4) == 0, "3.ª vez (dos marcas): WW directo a 0:30, todavía sin persecución")
	_ack_now()
	await _adv(t, t0 + 2.5 * 60.0 + 15.0 - GameState.clock_seconds)
	t.check(_at(log_arr, "sala", 4) >= 0.0 and absf(_at(log_arr, "sala", 4) - t0 - 150.0) <= TOL + 10.0, "y la persecución a los 2:30: nunca antes de 2 min de juego tras el aviso (%.2f min)" % ((_at(log_arr, "sala", 4) - t0) / 60.0))
	_unspy(t)


# --- Training, freeze, tópico ------------------------------------------------------------------------

func _training_regreso(t: Node) -> void:
	await _prep(t, 2)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	await _go(t, 1, "ascensor")
	EventBus.training_started.emit()
	t.check(Discipline.is_frozen(), "training: todo congelado")
	EventBus.training_ended.emit(true)
	await t.frames(2)
	t.check(not Discipline.is_frozen(), "fin del training: se descongela")
	var t0 := GameState.clock_seconds
	await _adv(t, t0 + 5.0 * 60.0 + 20.0 - GameState.clock_seconds)
	_check_times(t, log_arr, "training_regreso", t0, {1: 3.0, 2: 4.0, 4: 5.0})
	t.check(_count(log_arr, "sala") == 0, "mientras corre el regreso, 'fuera de la sala' no se suma")
	await _expect_death(t, seq, "regreso_tardio", "shero", 60.0)
	_unspy(t)


func _feedback_congela(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await _leave_room(t)
	await _adv(t, 10.5 * 60.0)
	t.check(_count(log_arr, "break", 1) == 1 and _count(log_arr, "break", 2) == 0, "break vencido (llamado)")
	EventBus.qa_feedback_started.emit(1)
	await _adv(t, 10.0 * 60.0)
	t.check(_count(log_arr, "break", 2) == 0, "durante el feedback de QA el break no avanza (congelado)")
	EventBus.qa_feedback_ended.emit(1)
	await _adv(t, 60.0)
	t.check(_count(log_arr, "break", 2) == 1 and _count(log_arr, "break", 3) == 0, "al terminar el feedback sigue donde iba (verbal a los 11)")
	_unspy(t)


func _topico(t: Node) -> void:
	await _prep(t)
	if not Discipline.owns_track("topico"):
		t.note("TopicoControl (P5) está en el proyecto: el tópico lo lleva P5 (ver topico_p5)")
		t.check(true, "tópico de P5")
		return
	var seq: Array = t.spy("death_sequence_started")
	var posts := _posts(t)
	EventBus.topico_requested.emit()
	await t.frames(2)
	t.check(Discipline.topico_permitted(), "1.er 'Me siento mal': permiso de tópico (15 min)")
	await t.seconds(4.0)
	t.check(_has_post(posts, "dm:shero", "shero", "topico"), "DM 'Ok. Tópico, piso 1. Quince minutos.'")
	await _go(t, 1, "ascensor")
	await _adv(t, 5.0 * 60.0)
	t.check(Discipline.step_of("sala") == 0, "con permiso de tópico, fuera de la sala no corre")
	EventBus.topico_requested.emit()
	await t.frames(2)
	t.check(Pursuit.is_hunting("shero"), "2.º pedido: 'Work avoiding.' y persecución inmediata")
	await _expect_death(t, seq, "work_avoiding", "shero", 60.0)


func _topico_excedido(t: Node) -> void:
	await _prep(t)
	var log_arr := _steps(t)
	var seq: Array = t.spy("death_sequence_started")
	EventBus.topico_requested.emit()
	await t.frames(2)
	if Metrics.authorization_of("topico").is_empty():
		Metrics.authorize(Metrics.Aux.BANO, "topico", "topico", 15.0)  # como TopicoControl (P5)
	await _go(t, 1, "ascensor")
	await _adv(t, 15.0 * 60.0 + 10.0)
	var t0 := _at(log_arr, "topico_excedido", 2)
	t.check(t0 >= 0.0, "pasados los 15 min fuera de la sala: verbal ('Quince minutos eran quince')")
	await _adv(t, 2.0 * 60.0 + 10.0)
	t.check(_count(log_arr, "topico_excedido", 4) == 1, "+2:00: persecución")
	await _expect_death(t, seq, "abandono", "shero", 60.0)
	_unspy(t)


func _tres_molestos(t: Node) -> void:
	await _prep(t, 1)
	var log_arr := _steps(t)
	var ww0 := Metrics.written_warnings
	EventBus.angry_streak.emit(3)
	await t.frames(2)
	t.check(_count(log_arr, "tres_molestos", 3) == 1 and Metrics.written_warnings == ww0 + 1, "T1: 3 molestos = WW")
	_ack_now()
	_unspy(t)
	await t.back_to_menu()
	await _prep(t, 2)
	var seq: Array = t.spy("death_sequence_started")
	EventBus.angry_streak.emit(3)
	await _expect_death(t, seq, "tres_molestos", "shero", 10.0)


func _reflejo_kyc(t: Node) -> void:
	await _prep(t)
	var wws: Array = t.spy("written_warning_issued")
	var sh := t.get_tree().get_first_node_in_group("shero") as Shero
	EventBus.scripted_event.emit("shero_en_el_reflejo")
	await t.until(func() -> bool: return sh.state == Shero.State.COACHING, 20.0)
	t.check(sh.global_position.distance_to(t.player().global_position) < 3.2, "Shero va detrás de tu silla (reflejo)")
	await t.seconds(3.0)
	EventBus.contact_ended.emit({"id": "kyc_x"}, true, false)
	await t.frames(3)
	t.check(sh.state == Shero.State.OBSERVAR, "al cerrar el caso vuelve a su sitio")
	t.check(wws.is_empty(), "el jugador obediente NO recibe el WW 'reflejo_kyc' (v0.2 lo daba)")


func _reloj_4x(t: Node) -> void:
	await _prep(t)
	await t.frames(2)
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.set_process(false)
	t.check(is_equal_approx(GameState.clock_speed(), float(DataLoader.bal("reloj/sin_cola", 45.0))), "sentado en C-14 sin cola: 45x")
	await _leave_room(t)
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "fuera de la sala: 4x")
	await _back_in_room(t)
	Metrics.set_aux(Metrics.Aux.COACHING)
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "coaching sin permiso: 4x")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), 45.0), "de vuelta: 45x")
	cm.set_process(true)


func _owns(t: Node) -> void:
	for k in ["llamadas_perdidas", "correo", "coaching_noshow"]:
		t.check(Discipline.owns_track(k) and ContactManager.discipline_owns(k), "Discipline.owns_track('%s')" % k)
	t.check(Discipline.has_method("ack_window_seconds") and Discipline.has_method("allows_fast_clock"), "API de P3 para Metrics / GameState")
	await t.frames(1)


func _facil_sentado(t: Node) -> void:
	await _prep(t, 1, 0)
	var seq: Array = t.spy("death_sequence_started")
	var ends: Array = t.spy("pursuit_ended")
	var ww0 := Metrics.written_warnings
	Discipline.debug_start("sala", 0.0)
	Discipline.debug_fire("sala", 4)
	t.check(Pursuit.is_hunting("shero"), "persecución")
	var ok: bool = await t.until(func() -> bool: return not ends.is_empty(), 40.0)
	t.check(ok and str(ends[0][1]) == "perdonado" and seq.is_empty(), "Fácil: te alcanza sentado en C-14 en Available → sin muerte")
	t.check(Metrics.written_warnings == ww0 + 1, "le deja la amonestación: +1 WW")
	_ack_now()


func _presencia(t: Node) -> void:
	await _prep(t)
	var subs: Array = t.spy("subtitle")
	await _go(t, -1, "ascensor")
	Discipline.debug_start("sala", 0.0)
	Discipline.debug_fire("sala", 2)
	await t.frames(3)
	var pa_ok := false
	for s in subs:
		if str(s[1]).contains(Loc.fmt(tr("P3_SPK_PA"), {"quien": "Shero"})):
			pa_ok = true
	t.check(pa_ok, "verbal lejos de Shero: por los parlantes del piso (-1) con subtítulo")
	var pr: Node = Discipline.presence
	var p: Player = t.player()
	# v0.3.1 Q5: (0, 0, 18) es ahora el pie de la escalera del patio hundido (la vereda queda 2,1 m arriba); el
	# pasillo largo a nivel es el lobby hacia el núcleo, por el carril del molinete (x -1).
	p.teleport(t.building().floor_node.global_position + Vector3(-1.0, 0, 13.0), 0.0)
	p.head.rotation.x = 0.0
	await t.frames(3)
	var ok: bool = pr.call("spawn_apparition")
	t.check(ok and pr.call("ghost") != null, "aparición de Shero al final del pasillo")
	var g: Node3D = pr.call("ghost")
	if g != null:
		var d := g.global_position.distance_to(p.global_position)
		t.check(d >= 11.0 and d <= 25.0, "a 12-24 m (%.1f)" % d)
	await t.seconds(0.8)
	p.rotate_y(PI)
	await t.seconds(0.5)
	t.check(pr.call("ghost") == null, "al apartar la vista y volver a mirar, ya no está")
	_ack_now()


func _hud(t: Node) -> void:
	await _prep(t)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(3)
	var hud: Node = t.main.get_node("UI/HUD")
	var txt := ""
	for c in hud.get_children():
		if c is Label and str((c as Label).text).contains("Breaks"):
			txt = (c as Label).text
	t.check(txt.contains("1/2"), "HUD: Breaks 1/2 (%s)" % txt)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _leave_room(t)
	await _adv(t, 1.5 * 60.0 + 20.0)
	await t.frames(3)
	for c in hud.get_children():
		if c is Label and str((c as Label).text).contains("Breaks"):
			txt = (c as Label).text
	t.check(txt.contains("Shero") and txt.contains(tr("P3_STEP_2")), "HUD: 'Shero · fuera de la sala · verbal' (%s)" % txt)


func _npc_breaks(t: Node) -> void:
	await _prep(t)
	var posts := _posts(t)
	EventBus.ezlak_post.emit("#allocations", "rta", "@Ttoom AUX incorrecto: Break hace 12:10.", {"tipo": "prueba"})
	await t.seconds(4.0)
	var ok := false
	for p in posts:
		if str(p[0]) == "#allocations" and str(p[1]) == "shero":
			ok = true
	t.check(ok, "un compañero en Break en #allocations → Shero: 'No hay breaks.'")


func _checkpoint(t: Node) -> void:
	await _prep(t)
	await _leave_room(t)
	await _adv(t, 4.0 * 60.0 + 10.0)
	var d := Discipline.to_save_dict()
	t.check(int((d.get("counters", {}) as Dictionary).get("verbales", 0)) == 1, "los contadores van en el checkpoint")
	t.check(((d.get("counters", {}) as Dictionary).get("por_pista", {}) as Dictionary).is_empty(), "las escaleras en curso no (al reaparecer se reinician)")
	Discipline.from_save_dict(d)
	t.check(int(Discipline.counters["verbales"]) == 1 and Discipline.step_of("sala") == 0, "restaurar: verbales 1, sala reiniciada")
	await _back_in_room(t)

## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P1 · reglas del núcleo: AUX nuevos y Available % (§3.3), autorizaciones, dificultad (§3.6),
## reloj 00:00-08:45 y horario del turno (§3.1-3.2), economía en 8 pagos.


func escenarios() -> Array[String]:
	return ["available_formula", "aux_v03", "autorizaciones", "dificultad", "reloj_turno", "horario_turno", "economia_turno"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"available_formula": await _available(t)
		"aux_v03": await _aux(t)
		"autorizaciones": await _auth(t)
		"dificultad": await _dificultad(t)
		"reloj_turno": await _reloj(t)
		"horario_turno": await _horario(t)
		"economia_turno": await _economia(t)


## 30 min Available + 10 min BO → 75 %; +10 min de Break → 75 % (PLAN §2 #15).
func _available(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.running = false  # el reloj solo avanza con advance_clock (determinista)
	Metrics.reset_shift()
	t.check(is_equal_approx(Metrics.available_pct(), 100.0), "arranca en 100 %")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.advance_clock(30 * 60.0)
	t.check(Metrics.available_evaluable(), "con 30 min productivos ya se evalúa")
	Metrics.set_aux(Metrics.Aux.BO)
	await t.advance_clock(10 * 60.0)
	t.check(absf(Metrics.available_pct() - 75.0) < 0.5, "30 Available + 10 BO = 75 %% (hay %.1f)" % Metrics.available_pct())
	for a in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH, Metrics.Aux.BANO, Metrics.Aux.COACHING, Metrics.Aux.TRAINING]:
		Metrics.set_aux(a)
		await t.advance_clock(10 * 60.0)
		t.check(absf(Metrics.available_pct() - 75.0) < 0.5, "%s congela el Available (hay %.1f)" % [Metrics.aux_name(a), Metrics.available_pct()])
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.advance_clock(20 * 60.0)
	t.check(absf(Metrics.available_pct() - 83.3) < 0.5, "solo sube en Available: 50/60 = 83,3 %% (hay %.1f)" % Metrics.available_pct())
	Metrics.reset_shift()
	Metrics.set_aux(Metrics.Aux.BO)
	await t.advance_clock(10 * 60.0)
	t.check(not Metrics.available_evaluable() and Metrics.color_of("available") == "verde", "antes de 30 min productivos no se pinta de rojo")


func _aux(t: Node) -> void:
	t.check(Metrics.AUX_KEYS.size() == 7, "7 AUX")
	var names: Array[String] = []
	for i in Metrics.AUX_KEYS.size():
		names.append(Metrics.aux_name(i))
	t.check(names[0] == "Available" and names[1].begins_with("BO") and names[2] == "Break" and names[3] == "Lunch" and names[6] == "Training", "orden Available, BO, Break, Lunch, Baño, Coaching, Training (%s)" % ", ".join(names))
	for n in names:
		t.check(not n.contains("KYC") and n != "Correo" and n != "Email", "ningún AUX se llama KYC ni Correo (%s)" % n)
	t.check(Metrics.is_productive(Metrics.Aux.AVAILABLE) and Metrics.is_productive(Metrics.Aux.BO) and not Metrics.is_productive(Metrics.Aux.TRAINING), "productivos: Available y BO")
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	var csv := f.get_as_text()
	t.check(not csv.contains("AUX_KYC") and not csv.contains("AUX_CORREO") and not csv.contains("pasa a KYC") and not csv.contains("pasa a Correo"), "strings.csv sin 'AUX KYC' ni 'pasa a Correo'")
	t.check(Loc.tr("RTA_GO_BO").contains("BO"), "el RTA dice 'pasa a BO'")
	for a in Controls.AUX_ACTIONS:
		t.check(InputMap.has_action(a), "acción remapeable %s" % a)
	# Breaks del turno y sesión de AUX.
	var started: Array = t.spy("break_started")
	var ended: Array = t.spy("break_ended")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.running = false
	t.check(Metrics.breaks_allowed() == 2, "2 breaks por turno")
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.advance_clock(4 * 60.0)
	t.check(absf(Metrics.aux_session_seconds() - 240.0) < 1.0, "segundos de la sesión de AUX (%.0f)" % Metrics.aux_session_seconds())
	t.check(absf(Metrics.quota_left(Metrics.Aux.BREAK) - 360.0) < 1.0, "el break se mide por break: quedan 6 min")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	Metrics.set_aux(Metrics.Aux.BREAK)
	t.check(absf(Metrics.quota_left(Metrics.Aux.BREAK) - 600.0) < 1.0, "el 2.º break empieza con sus 10 min")
	t.check(Metrics.breaks_used == 2 and started.size() == 2 and ended.size() == 1, "contador de breaks (usados %d, started %d, ended %d)" % [Metrics.breaks_used, started.size(), ended.size()])
	# Guardar y restaurar conserva los breaks.
	var d := Metrics.to_save_dict()
	Metrics.reset_shift()
	Metrics.from_save_dict(d)
	t.check(Metrics.breaks_used == 2 and Metrics.aux == Metrics.Aux.BREAK, "breaks y AUX en el checkpoint")


## Break/Lunch/Baño autorizan todo el edificio; Coaching/Training solo si alguien los pide (PLAN §3.3/3.4).
func _auth(t: Node) -> void:
	var granted: Array = t.spy("authorization_granted")
	var ended: Array = t.spy("authorization_ended")
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.running = false
	t.check(Metrics.is_authorized("sala"), "estar en la sala siempre está permitido")
	t.check(not Metrics.is_authorized("piso_1"), "en Available no se puede salir de la sala")
	Metrics.set_aux(Metrics.Aux.BREAK)
	t.check(Metrics.is_authorized("piso_1") and Metrics.is_authorized("azotea"), "Break autoriza todo el edificio")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	t.check(Metrics.is_authorized("cafeteria") and Metrics.authorization_of("break").is_empty(), "Lunch reemplaza a Break")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	t.check(not Metrics.is_authorized("piso_1"), "volver a Available retira la autorización")
	Metrics.set_aux(Metrics.Aux.COACHING)
	t.check(not Metrics.is_aux_authorized(), "Coaching sin permiso no está autorizado")
	Metrics.authorize(Metrics.Aux.COACHING, "qa", "sala_calibracion", 5.0)
	t.check(Metrics.is_aux_authorized() and Metrics.is_authorized("sala_calibracion") and not Metrics.is_authorized("piso_1"), "QA autoriza Coaching y solo la sala de calibración")
	await t.advance_clock(6 * 60.0)
	t.check(not Metrics.is_aux_authorized(), "la autorización vence a los 5 min")
	t.check(not Metrics.is_aux_authorized(Metrics.Aux.TRAINING), "Training sin Trainer no está autorizado")
	Metrics.authorize(Metrics.Aux.TRAINING, "trainer", "piso_1", 30.0)
	t.check(Metrics.is_aux_authorized(Metrics.Aux.TRAINING) and Metrics.is_authorized("piso_1"), "el Trainer autoriza Training y el piso 1")
	Metrics.revoke("trainer")
	t.check(not Metrics.is_authorized("piso_1"), "revoke(fuente) la retira")
	var srcs: Array[String] = []
	for e in ended:
		srcs.append(str(e[0]))
	t.check(srcs.has("break") and srcs.has("lunch") and srcs.has("qa") and srcs.has("trainer"), "authorization_ended por fuente (%s)" % ", ".join(srcs))
	t.check(granted.size() >= 4, "authorization_granted emitida (%d)" % granted.size())


## Fácil ×1,5 / Normal ×1 / Difícil ×0,75; Turno real = Difícil (PLAN §3.6).
func _dificultad(t: Node) -> void:
	var expected := {Difficulty.Level.FACIL: 1.5, Difficulty.Level.NORMAL: 1.0, Difficulty.Level.DIFICIL: 0.75}
	var cp_modes := {Difficulty.Level.FACIL: "contacto", Difficulty.Level.NORMAL: "dos_contactos", Difficulty.Level.DIFICIL: "login_break_lunch"}
	for lvl in expected.keys():
		await t.start_shift("Llauri", 2, GameState.Mode.NORMAL, lvl)
		var k: float = expected[lvl]
		t.check(is_equal_approx(Difficulty.scale("plazos"), k) and is_equal_approx(GameState.tolerance_scale(), k), "%s: plazos x%.2f" % [Difficulty.id(), k])
		t.check(Checkpoints.checkpoint_mode() == str(cp_modes[lvl]), "%s: checkpoints '%s' (hay '%s')" % [Difficulty.id(), cp_modes[lvl], Checkpoints.checkpoint_mode()])
		await t.login_at_seat()
		Metrics.issue_written_warning("prueba")
		var ack := 8.0 * k
		t.check(absf(Metrics.ack_left - ack) < 0.05, "%s: Ack %.1f s (hay %.2f)" % [Difficulty.id(), ack, Metrics.ack_left])
		Metrics.give_ack()
		t.check(int(Difficulty.value("quiz_aprobar", 0)) == [2, 3, 4][lvl], "%s: quiz %d/5" % [Difficulty.id(), [2, 3, 4][lvl]])
		t.check(Difficulty.flag("salvarse_sentado") == (lvl == Difficulty.Level.FACIL), "%s: salvarse sentado solo en Fácil" % Difficulty.id())
		GameState.start_calm(100.0)
		var calm_k: float = [1.5, 1.0, 0.5][lvl]
		t.check(absf(float(GameState.get("_calm_left")) - 100.0 * calm_k) < 0.5, "%s: calma x%.1f" % [Difficulty.id(), calm_k])
		await t.back_to_menu()
	await t.start_shift("Llauri", 2, GameState.Mode.REAL, Difficulty.Level.FACIL)
	t.check(Difficulty.effective() == Difficulty.Level.DIFICIL and is_equal_approx(Difficulty.scale("ack"), 0.75), "Turno real: Difícil aunque se eligió Fácil")
	t.check(Checkpoints.checkpoint_mode() == "ninguno" and Difficulty.restarts_full_shift(), "Turno real: sin checkpoints y reinicio completo")
	# Fatiga por hora × dificultad.
	await t.back_to_menu()
	await t.start_shift("Llauri", 1, GameState.Mode.NORMAL, Difficulty.Level.DIFICIL)
	await t.login_at_seat()
	Fatigue.set_value(30.0)
	Fatigue.call("_on_hour_changed", 5)
	t.check(is_equal_approx(Fatigue.value, 35.0), "Difícil: Fatiga +4 × 1,25 = +5 por hora (hay %.1f)" % Fatigue.value)


## Turno 00:00 → 08:45, bloques de 3 h y velocidades del reloj (PLAN §3.1).
func _reloj(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	t.check(is_equal_approx(GameState.shift_end_seconds(), 31500.0), "el turno termina a las 08:45 (31500 s)")
	t.check(is_equal_approx(GameState.clock_speed(), 3.0), "llegada 3x")
	await t.login_at_seat()
	var speeds := {"sin_cola": 45.0, "de_pie_aux": 4.0, "lunch": 9.0, "contacto": 6.0, "contacto_guion": 12.0, "caso_bo": 10.0, "training": 24.0, "dormido": 30.0}  # v0.3.1: training 12→24 (F21)
	for k in speeds.keys():
		t.check(is_equal_approx(float(DataLoader.bal("reloj/" + str(k), 0.0)), float(speeds[k])), "balance reloj/%s = %.0fx" % [k, speeds[k]])
	t.check(is_equal_approx(GameState.clock_speed(), 45.0), "sentado en Available sin caso: 45x (hay %.1f)" % GameState.clock_speed())
	Metrics.set_aux(Metrics.Aux.LUNCH)
	t.check(is_equal_approx(GameState.clock_speed(), 9.0), "lunch 9x")
	Metrics.set_aux(Metrics.Aux.BREAK)
	t.player().stand_up()
	await t.frames(1)
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "de pie / break 4x")
	GameState.set_clock_override("dormido")
	t.check(is_equal_approx(GameState.clock_speed(), 30.0), "dormido 30x (reloj especial)")
	GameState.clear_clock_override("dormido")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	GameState.call("_on_player_seated", "C-14")
	for pair in [[{"canal": "correo_bo"}, 10.0, "caso BO (correo)"], [{"canal": "kyc"}, 10.0, "caso BO (KYC)"], [{"canal": "llamada"}, 12.0, "llamada v0.2 con guion"], [{"canal": "chat", "nodos": {}}, 6.0, "chat con árbol (P4)"]]:
		GameState.call("_on_contact_accepted", pair[0])
		t.check(is_equal_approx(GameState.clock_speed(), float(pair[1])), "%s: %.0fx (hay %.1f)" % [pair[2], pair[1], GameState.clock_speed()])
		GameState.call("_on_contact_ended", pair[0], true, false)
	t.check(is_equal_approx(GameState.clock_speed(), 45.0), "sin caso vuelve a 45x")
	for pair in [[0.0, 1], [3 * 3600.0 - 1.0, 1], [3 * 3600.0, 2], [6 * 3600.0 - 1.0, 2], [6 * 3600.0, 3], [31499.0, 3]]:
		GameState.clock_seconds = pair[0]
		t.check(GameState.current_block() == pair[1], "bloque a las %s = %d" % [GameState.clock_text(), pair[1]])
	var ended: Array = t.spy("shift_ended")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.set_clock(31500.0 - 30.0)
	t.check(await t.until(func() -> bool: return not ended.is_empty(), 10.0), "el turno se cierra a las 08:45")
	t.check(GameState.shift_over and GameState.clock_text() == "8:45 AM", "reloj final %s" % GameState.clock_text())


## Horario por turno: lunch T1 04:00 · T2 03:45 · T3 04:20 (45 min), training T2 02:20 · T3 01:40, Vitzo 03:00/06:00.
func _horario(t: Node) -> void:
	var lunch := {1: "4:00 AM", 2: "3:45 AM", 3: "4:20 AM"}
	var training := {1: "", 2: "2:20 AM", 3: "1:40 AM"}
	for n in [1, 2, 3]:
		await t.start_shift("Jiroshi", n)
		t.check(GameState.clock_text_at(GameState.lunch_clock()) == lunch[n] and is_equal_approx(GameState.lunch_minutes(), 45.0), "T%d: lunch %s de 45 min" % [n, lunch[n]])
		var tc := GameState.training_clock()
		t.check((tc < 0.0 and training[n] == "") or GameState.clock_text_at(tc) == training[n], "T%d: training %s" % [n, training[n] if training[n] != "" else "—"])
		t.check(int(GameState.turno_cfg("breaks", 0)) == 2, "T%d: 2 breaks" % n)
		await t.back_to_menu()
	var vh: Array = DataLoader.bal("vitzo/horas_recordatorio", [])
	t.check(vh.size() == 2 and int(vh[0]) == 3 and int(vh[1]) == 6, "Vitzo a las 03:00 y 06:00 (%s)" % str(vh))
	# Ventana del lunch: abre a la hora −5 y cierra a la hora +15.
	var win: Array = t.spy("lunch_window")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	# v0.3.1: sin cuadros de espera antes de mirar: con la máquina cargada 2 cuadros a 45x pasaban el minuto que falta.
	await t.set_clock(GameState.lunch_clock() - 6 * 60.0)
	t.check(not GameState.lunch_window_open(), "04:54 → 03:54: ventana cerrada")
	await t.set_clock(GameState.lunch_clock() - 4 * 60.0)
	await t.frames(2)
	t.check(GameState.lunch_window_open() and not win.is_empty() and bool(win[-1][0]), "03:56: lunch_window(true)")
	await t.set_clock(GameState.lunch_clock() + 16 * 60.0)
	await t.frames(2)
	t.check(not GameState.lunch_window_open() and not bool(win[-1][0]), "04:16: lunch_window(false)")


## Sueldo: 8 pagos (1:00 … 8:00) + el cierre de los 45 min = sueldo completo.
func _economia(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	var sueldo := float(DataLoader.bal("economia/sueldo_turno_soles", 58.0))
	for h in range(0, 10):
		EventBus.hour_changed.emit(h)
	var pagado := Economy.ganado_turno
	t.check(absf(pagado - sueldo * 8.0 / 8.75) < 0.01, "8 pagos por hora (%.2f)" % pagado)
	Economy.call("_on_shift_ended")
	t.check(absf(Economy.ganado_turno - sueldo) < 0.01, "con el cierre suma el sueldo completo (%.2f de %.2f)" % [Economy.ganado_turno, sueldo])

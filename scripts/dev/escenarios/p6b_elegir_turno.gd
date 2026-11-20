## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P6b · Elegir turno (PLAN §2 #80): instantáneas al inicio de cada turno alcanzado, rejugar un
## turno pasado como rama que NO toca la partida principal, "Seguir desde aquí" (con confirmación) que la
## reemplaza, finales para siempre, todas las dificultades y Turno real, rama guardada a medias, migración de
## partidas sin instantáneas, y el menú (Continuar / Elegir turno / pantalla de turnos).


func escenarios() -> Array[String]:
	return ["p6_elegir_turno", "p6_elegir_turno_seguir", "p6_elegir_turno_finales", "p6_elegir_turno_real",
		"p6_elegir_turno_dificultad", "p6_elegir_turno_migracion", "p6_elegir_turno_rama_guardada",
		"p6_elegir_turno_menu", "p6_elegir_turno_frontera"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p6_elegir_turno": await _basico(t)
		"p6_elegir_turno_seguir": await _seguir(t)
		"p6_elegir_turno_finales": await _finales(t)
		"p6_elegir_turno_real": await _real(t)
		"p6_elegir_turno_dificultad": await _dificultad(t)
		"p6_elegir_turno_migracion": await _migracion(t)
		"p6_elegir_turno_rama_guardada": await _rama_guardada(t)
		"p6_elegir_turno_menu": await _menu(t)
		"p6_elegir_turno_frontera": await _frontera(t)


# --- ayudas ----------------------------------------------------------------------------------------

func _shift_end(t: Node) -> Control:
	return t.main.get("shift_end") as Control


## Cierra el turno en curso como el reloj a las 08:45 (Economy paga, ShiftEnd cierra y guarda). Si era una rama,
## deja la pantalla abierta (el escenario elige); si no, "Marcar salida" → menú.
func _close_turn(t: Node, ww: int = 0) -> void:
	await t.login_at_seat()
	Metrics.written_warnings = ww
	await t.advance_clock(1800.0)
	GameState.shift_over = true
	GameState.running = false
	EventBus.shift_ended.emit()
	await t.frames(3)
	var se := _shift_end(t)
	if int(se.get("branch_turn")) == 0:
		se.call("_close")
		await t.frames(3)


## Juega la partida principal de `agent` hasta tener `n` turnos cerrados (T1..Tn) y la frontera en n+1.
func _progress_to(t: Node, agent: String, n: int) -> void:
	for k in range(1, n + 1):
		await t.start_shift(agent, k)
		await _close_turn(t)


## Elige el agente como en el menú (el menú reconstruido vuelve a seleccionar SU agente al volver).
func _sel(t: Node, agent: String) -> void:
	t.main.get("main_menu").set("agent_index", GameState.AGENTS.find(agent))
	SaveSlots.select(agent)


func _main_text(agent: String) -> String:
	var p := SaveSlots.main_progress_path(agent)
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _strip_times(json: String) -> Dictionary:
	var d: Variant = JSON.parse_string(json)
	if not (d is Dictionary):
		return {}
	(d as Dictionary).erase("actualizada")
	return d


# --- escenarios -------------------------------------------------------------------------------------

## Instantáneas, rama que no toca la principal y "Volver sin cambiar mi partida".
func _basico(t: Node) -> void:
	await _progress_to(t, "Marko", 2)
	var snaps := SaveSlots.snapshots("Marko")
	t.check(snaps.size() == 3, "hay una instantánea por turno alcanzado (T1, T2, T3): %d" % snaps.size())
	var s1 := SaveSlots.snapshot(1, "Marko")
	var s2 := SaveSlots.snapshot(2, "Marko")
	var s3 := SaveSlots.snapshot(3, "Marko")
	t.check(s1.has("resultado") and s2.has("resultado") and not s3.has("resultado"), "T1 y T2 con resultado, T3 (actual) sin cerrar")
	t.check(float(s1.get("saldo", 0.0)) < 0.0 and float(s2.get("saldo", -1.0)) > 0.0, "T1 empieza sin saldo (inicial), T2 con el saldo ganado en T1 (%s)" % str(s2.get("saldo")))
	t.check((s3.get("turnos_cerrados", []) as Array).size() == 2 and int(s3.get("turno_desbloqueado", 0)) == 3, "la instantánea de T3 tiene T1-T2 cerrados")
	t.check(is_equal_approx(float(s2.get("fatiga_base", 0.0)), SaveSlots.fatigue_base_of(2)), "con la Fatiga base del turno")
	t.check(s1.has("ww_total") and s1.has("contadores") and s1.has("memos") and str(s1.get("alcanzado", "")).length() >= 16, "y WW acumulados, contadores, memos y fecha")
	var r1: Dictionary = s1.get("resultado", {})
	t.check(r1.has("available") and r1.has("ww") and r1.has("contactos") and str(r1.get("cerrado", "")) != "", "el resultado guarda Available, WW, contactos y fecha de cierre")
	var ch := SaveSlots.choosable_turns("Marko")
	t.check(ch.size() == 3 and bool(ch[2].get("actual", false)) and bool(ch[0].get("rama", false)), "Elegir turno lista T1-T3 y marca T3 como actual")
	var before := _main_text("Marko")
	var saldo_before := float(SaveSlots.main_progress("Marko").get("saldo", 0.0))
	_sel(t, "Marko")
	t.check(bool(t.main.call("_start_branch", 1, 0)), "rejugar T1 arranca una rama")
	await t.frames(3)
	t.check(GameState.turno == 1 and SaveSlots.in_branch() and GameState.running, "se juega T1 en rama")
	t.check(int(GameState.progress.get("turno_desbloqueado", 0)) == 1 and (GameState.progress.get("turnos_cerrados", []) as Array).is_empty(), "la rama empieza desde la instantánea de T1 (nada cerrado)")
	t.check(Economy.saldo > 0.0 and absf(Economy.saldo - saldo_before) > 0.01, "con el saldo de entonces (S/ %.2f, la principal tiene %.2f)" % [Economy.saldo, saldo_before])
	t.check(is_equal_approx(Fatigue.value, float(s1.get("fatiga_base", 0.0))), "y la Fatiga base de T1")
	t.check(_main_text("Marko") == before, "la partida principal no cambió al empezar la rama")
	await t.login_at_seat()
	t.check(FileAccess.file_exists(SaveSlots.checkpoint_path("Marko")) and SaveSlots.checkpoint_path("Marko").contains("/rama/"), "los checkpoints de la rama van a su carpeta")
	t.check(not FileAccess.file_exists(SaveSlots.main_checkpoint_path("Marko")) or str(SaveSlots.read_checkpoint("Marko").get("turno", 0)) == "1", "sin pisar el de la partida principal")
	await _close_turn(t)
	var se := _shift_end(t)
	t.check(int(se.get("branch_turn")) == 1 and (se.find_child("SeguirDesdeAqui", true, false) as Control).is_visible_in_tree(), "al cerrar la rama la pantalla ofrece «Seguir desde aquí»")
	t.check(_main_text("Marko") == before, "cerrar el turno de la rama no tocó la principal")
	se.call("drop_branch")
	await t.frames(4)
	t.check(not SaveSlots.in_branch() and SaveSlots.pending_branch("Marko").is_empty(), "«Volver sin cambiar mi partida» descarta la rama")
	t.check(_strip_times(_main_text("Marko")) == _strip_times(before), "y la partida principal quedó igual")
	t.check(SaveSlots.frontier("Marko") == 3, "Continuar sigue siendo el T3")


## "Seguir desde aquí": confirmación y reemplazo del progreso posterior.
func _seguir(t: Node) -> void:
	await _progress_to(t, "Llauri", 2)
	await t.start_shift("Llauri", 3)
	await t.login_at_seat()
	await t.advance_clock(1200.0)
	Checkpoints.save_checkpoint("login")
	await t.back_to_menu()
	t.check(SaveSlots.has_main_checkpoint("Llauri"), "la principal tiene el T3 a medias")
	_sel(t, "Llauri")
	t.main.call("_start_branch", 1, 0)
	await t.frames(3)
	await _close_turn(t, 1)
	var se := _shift_end(t)
	se.call("keep_branch")
	await t.frames(2)
	t.check(se.visible and bool(se.get("_confirm_keep")), "la primera pulsación pide confirmar")
	t.check(SaveSlots.in_branch(), "todavía no reemplaza nada")
	se.call("drop_branch")
	await t.frames(2)
	t.check(se.visible and not bool(se.get("_confirm_keep")), "[Espacio] con la confirmación abierta solo la cancela")
	se.call("keep_branch")
	se.call("keep_branch")
	await t.frames(4)
	var p := SaveSlots.main_progress("Llauri")
	t.check(not SaveSlots.in_branch() and SaveSlots.pending_branch("Llauri").is_empty(), "confirmado: la rama pasa a ser la partida")
	t.check((p.get("turnos_cerrados", []) as Array) == [1] and int(p.get("turno_desbloqueado", 0)) == 2, "la partida queda con T1 cerrado y T2 desbloqueado (cerrados %s)" % str(p.get("turnos_cerrados")))
	t.check(not (p.get("turnos", {}) as Dictionary).has("3"), "se reemplazó el progreso posterior (sin instantánea de T3)")
	t.check((p.get("turnos", {}) as Dictionary).has("2") and int(p.get("ww_total", 0)) == 1, "T2 nace de la rama (WW acumulados 1)")
	t.check(not SaveSlots.has_main_checkpoint("Llauri"), "y el T3 a medias se borró")
	t.check(SaveSlots.frontier("Llauri") == 2 and str((p.get("seguido_desde", {}) as Dictionary).get("turno", 0)) == "1", "Continuar ahora es el T2 (seguido desde T1)")


## Finales y epílogos quedan para siempre, también vistos en una rama descartada.
func _finales(t: Node) -> void:
	await _progress_to(t, "Ttoom", 2)
	_sel(t, "Ttoom")
	SaveSlots.unlock_ending("renunciar")
	t.main.call("_start_branch", 1, 0)
	await t.frames(3)
	SaveSlots.unlock_ending("despedido")
	SaveSlots.unlock_epilogue("epilogo_ttoom_1")
	SaveSlots.unlock_memo("memo_14")
	t.check((SaveSlots.main_progress("Ttoom").get("finales", []) as Array).has("despedido"), "un final visto en la rama se escribe en la principal al instante")
	await _close_turn(t)
	_shift_end(t).call("drop_branch")
	await t.frames(3)
	var p := SaveSlots.main_progress("Ttoom")
	t.check((p.get("finales", []) as Array).has("renunciar") and (p.get("finales", []) as Array).has("despedido"), "tras descartar la rama la principal conserva los dos finales")
	t.check((p.get("epilogos", []) as Array).has("epilogo_ttoom_1") and (p.get("memos", []) as Array).has("memo_14"), "y el epílogo y el memo")
	t.note("frontera %d · instantáneas %s · rama pendiente %s · contexto '%s'" % [SaveSlots.frontier("Ttoom"), str(SaveSlots.main_progress("Ttoom").get("turnos", {}).keys()), str(SaveSlots.pending_branch("Ttoom")), SaveSlots.context])
	_sel(t, "Ttoom")
	t.check(bool(t.main.call("_start_branch", 2, 0)), "se puede abrir otra rama (T2)")
	await t.frames(3)
	t.check((GameState.progress.get("finales", []) as Array).has("despedido"), "una rama nueva ya trae los finales vistos")
	await _close_turn(t)
	_shift_end(t).call("keep_branch")
	_shift_end(t).call("keep_branch")
	await t.frames(3)
	t.check((SaveSlots.main_progress("Ttoom").get("finales", []) as Array).size() == 2, "y «Seguir desde aquí» no los pierde")
	t.check(not (SaveSlots.main_progress("Juan").get("finales", []) as Array).has("despedido"), "los finales son por agente (Juan no los tiene)")


## Turno real en una rama: Difícil, morir reinicia el turno de la rama (la principal intacta).
func _real(t: Node) -> void:
	await _progress_to(t, "Juan", 2)
	var before := _main_text("Juan")
	_sel(t, "Juan")
	t.main.call("_start_branch", 2, GameState.Mode.REAL)
	await t.frames(3)
	t.check(GameState.is_real_mode() and Difficulty.effective() == Difficulty.Level.DIFICIL and SaveSlots.in_branch(), "la rama de T2 en Turno real (Difícil)")
	await t.login_at_seat()
	await t.advance_clock(900.0)
	GameState.stop_calm()
	await t.die("abandono", "", "shero")
	t.check(await t.wait_death_shown(), "muere en la rama")
	await t.reconnect()
	await t.frames(3)
	t.check(GameState.turno == 2 and SaveSlots.in_branch() and not GameState.logged_in and GameState.clock_seconds < 0.0, "Turno real: el turno de la rama vuelve a empezar desde la calle")
	t.check(_main_text("Juan") == before, "la partida principal no cambió")
	await _close_turn(t)
	t.check(int(_shift_end(t).get("branch_turn")) == 2, "al cerrar sigue siendo la rama de T2")
	_shift_end(t).call("drop_branch")
	await t.frames(3)
	t.check(_strip_times(_main_text("Juan")) == _strip_times(before), "descartada: la principal igual")


## Cada dificultad: la rama la usa y la partida principal conserva la suya.
func _dificultad(t: Node) -> void:
	await _progress_to(t, "Jiroshi", 1)
	for lvl in [Difficulty.Level.FACIL, Difficulty.Level.NORMAL, Difficulty.Level.DIFICIL]:
		SaveSlots.select("Jiroshi")
		SaveSlots.set_difficulty(Difficulty.Level.NORMAL)
		Difficulty.set_level(lvl)
		t.main.call("_start_branch", 1, 0)
		await t.frames(3)
		t.check(Difficulty.level == lvl and str(GameState.progress.get("dificultad", "")) == Difficulty.IDS[lvl], "rama de T1 en %s" % Difficulty.IDS[lvl])
		t.check(str(SaveSlots.main_progress("Jiroshi").get("dificultad", "")) == "normal", "la principal sigue en Normal")
		await t.back_to_menu()
		SaveSlots.end_branch(false)
	_sel(t, "Jiroshi")
	t.check(Difficulty.level == Difficulty.Level.NORMAL, "al volver al menú, la dificultad de la partida (Normal)")


## Partidas de antes de P6b (sin instantáneas) y la v0.2.
func _migracion(t: Node) -> void:
	var dir := SaveSlots.dir_of("Marko")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir + "progreso.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "agente": "Marko", "turno_desbloqueado": 3, "turnos_cerrados": [1, 2], "saldo": 54.5, "mode": 0, "dificultad": "dificil", "finales": [], "creada": "2026-11-01T02:00:00", "actualizada": "2026-11-02T03:00:00"}))
	f.close()
	SaveSlots.use_sandbox(SaveSlots.root.get_base_dir().get_base_dir())  # vacía la caché: se lee del disco
	var snaps := SaveSlots.snapshots("Marko")
	t.check(snaps.size() == 3, "la partida v3 recibe una instantánea por turno alcanzado (%d)" % snaps.size())
	t.check(bool(snaps[1].get("migrado", false)) and is_equal_approx(float(snaps[1].get("saldo", 0.0)), 54.5) and float(snaps[0].get("saldo", 0.0)) < 0.0, "marcadas como migradas (T1 con el saldo inicial, el resto con el actual)")
	t.check((snaps[0] as Dictionary).has("resultado") and not (snaps[2] as Dictionary).has("resultado"), "T1 y T2 cerrados, T3 actual")
	var disk: Variant = JSON.parse_string(_main_text("Marko"))
	t.check(disk is Dictionary and int((disk as Dictionary).get("version", 0)) == SaveSlots.VERSION and ((disk as Dictionary).get("turnos", {}) as Dictionary).size() == 3, "la migración quedó escrita en el disco (versión %d)" % SaveSlots.VERSION)
	_sel(t, "Marko")
	t.check(bool(t.main.call("_start_branch", 2, 0)) and GameState.turno == 2, "y se puede rejugar el T2 migrado")
	t.check(is_equal_approx(Economy.saldo, 54.5), "con su saldo")
	await t.back_to_menu()
	SaveSlots.end_branch(false)
	# v0.2 → v0.3 → instantáneas.
	var legacy := SaveSlots.legacy_dir
	var g := FileAccess.open(legacy + "progreso.json", FileAccess.WRITE)
	g.store_string(JSON.stringify({"turno_desbloqueado": 2, "agent": "Llauri", "mode": 0, "saldo": 30.0, "turnos_cerrados": [1]}))
	g.close()
	SaveSlots.migrate_v02()
	t.check(SaveSlots.snapshots("Llauri").size() == 2 and SaveSlots.frontier("Llauri") == 2, "la partida de la v0.2 también: T1 (cerrado) y T2")


## Rama guardada a medias: Continuar sigue la principal; la rama se retoma o se descarta desde Elegir turno.
func _rama_guardada(t: Node) -> void:
	await _progress_to(t, "Marko", 2)
	await t.start_shift("Marko", 3)
	await t.login_at_seat()
	await t.advance_clock(600.0)
	Checkpoints.save_checkpoint("login")
	var main_clock := GameState.clock_seconds
	await t.back_to_menu()
	_sel(t, "Marko")
	t.main.call("_start_branch", 1, 0)
	await t.frames(3)
	await t.login_at_seat()
	await t.advance_clock(3600.0)
	Checkpoints.save_checkpoint("login")
	var branch_clock := GameState.clock_seconds
	await t.back_to_menu()
	t.check(not SaveSlots.in_branch() and SaveSlots.pending_branch("Marko").get("turno", 0) == 1, "al volver al menú la rama de T1 queda guardada")
	_sel(t, "Marko")
	t.main.call("_continue_shift")
	await t.frames(5)
	# v0.3.2-core3: tolerancia 90 → 300 s de juego. Sentado y libre el reloj corre a 120-400x: con la máquina cargada un
	# solo cuadro largo son más de 90 s de juego; lo que esta prueba distingue son horas (otra partida), no minutos.
	t.check(GameState.turno == 3 and not SaveSlots.in_branch() and absf(GameState.clock_seconds - main_clock) < 300.0, "Continuar sigue la partida principal (T3 a medias) · turno %d, rama %s, reloj %+.0f s" % [GameState.turno, str(SaveSlots.in_branch()), GameState.clock_seconds - main_clock])
	await t.back_to_menu()
	_sel(t, "Marko")
	t.check(bool(t.main.call("_continue_branch")), "Continuar la rama")
	await t.frames(5)
	t.check(GameState.turno == 1 and SaveSlots.in_branch() and absf(GameState.clock_seconds - branch_clock) < 300.0, "retoma la rama de T1 en su checkpoint · turno %d, rama %s, reloj %+.0f s" % [GameState.turno, str(SaveSlots.in_branch()), GameState.clock_seconds - branch_clock])
	await t.back_to_menu()
	var menu: Control = t.main.get("main_menu")
	_sel(t, "Marko")
	menu.call("_build")
	await t.frames(2)
	var pick := menu.find_child("PickTurnBtn", true, false) as Button
	t.check(pick != null and pick.text == Loc.tr("MENU_PICK_TURN_BRANCH"), "el menú avisa la rama guardada")
	menu.call("_open_turns")
	await t.frames(3)
	var ts := menu.find_child("TurnSelect", true, false)
	t.check(ts != null and ts.find_child("ResumeBranch", true, false) != null, "Elegir turno muestra la rama con Continuar / Descartar")
	ts.emit_signal("branch_discard")
	await t.frames(3)
	t.check(SaveSlots.pending_branch("Marko").is_empty() and SaveSlots.has_main_checkpoint("Marko"), "descartada; el T3 a medias de la principal sigue ahí")


## El menú: sin partida "Iniciar turno"; con partida "Continuar" + "Elegir turno"; la pantalla de turnos.
func _menu(t: Node) -> void:
	var menu: Control = t.main.get("main_menu")
	_sel(t, "Juan")
	menu.set("agent_index", GameState.AGENTS.find("Juan"))
	menu.call("_build")
	await t.frames(2)
	t.check(menu.find_child("StartBtn", true, false) != null and (menu.find_child("PickTurnBtn", true, false) as Button).disabled, "sin partida: Iniciar turno y Elegir turno apagado")
	await _progress_to(t, "Juan", 1)
	_sel(t, "Juan")
	menu.set("agent_index", GameState.AGENTS.find("Juan"))
	menu.call("_build")
	await t.frames(2)
	var cont := menu.find_child("ContinueBtn", true, false) as Button
	var pick := menu.find_child("PickTurnBtn", true, false) as Button
	t.check(cont != null and cont.text.contains(Days.day_name(2)) and pick != null and not pick.disabled, "con partida: «Continuar · Martes» y «Elegir día»")
	pick.emit_signal("pressed")
	await t.frames(3)
	var ts := menu.find_child("TurnSelect", true, false)
	t.check(ts != null and ts.find_child("Turno1", true, false) != null and ts.find_child("Turno2", true, false) != null, "la pantalla lista T1 y T2")
	var r1 := ts.find_child("Turno1", true, false)
	var info := r1.find_child("Resumen", true, false) as Label
	t.check(info != null and info.text.contains("Available"), "con el resumen del turno cerrado (%s)" % (info.text.replace("\n", " / ") if info != null else ""))
	(r1.find_child("Jugar", true, false) as Button).emit_signal("pressed")
	await t.frames(5)
	t.check(GameState.running and GameState.turno == 1 and SaveSlots.in_branch(), "«Rejugar» arranca la rama de T1 desde el menú")
	await t.back_to_menu()
	SaveSlots.end_branch(false)
	menu.call("_build")
	await t.frames(2)
	(menu.find_child("PickTurnBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(3)
	ts = menu.find_child("TurnSelect", true, false)
	(ts.find_child("Turno2", true, false).find_child("Jugar", true, false) as Button).emit_signal("pressed")
	await t.frames(5)
	t.check(GameState.running and GameState.turno == 2 and not SaveSlots.in_branch(), "el turno actual en la pantalla = Continuar (partida principal)")
	await t.back_to_menu()


## La frontera no se rejuega en rama (es Continuar) y un turno no alcanzado no se puede elegir.
func _frontera(t: Node) -> void:
	await _progress_to(t, "Llauri", 1)
	_sel(t, "Llauri")
	t.check(not SaveSlots.start_branch(2), "T2 (actual) no abre rama")
	t.check(not SaveSlots.start_branch(3), "T3 (no alcanzado) tampoco")
	t.check(not SaveSlots.in_branch(), "y el contexto sigue en la partida principal")
	t.check(SaveSlots.start_branch(1) and SaveSlots.in_branch(), "T1 sí")
	SaveSlots.end_branch(false)
	t.check(not SaveSlots.in_branch() and SaveSlots.pending_branch("Llauri").is_empty(), "y se descarta limpio")

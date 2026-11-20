## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P1 · partidas por agente (PLAN §3.7) y migración del guardado único de la v0.2.


func escenarios() -> Array[String]:
	return ["slots", "migrar_guardado_v02", "continuar_por_agente"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"slots": await _slots(t)
		"migrar_guardado_v02": await _migrar(t)
		"continuar_por_agente": await _continuar(t)


## Progresar con Marko no cambia la partida de Jiroshi.
func _slots(t: Node) -> void:
	var changed: Array = t.spy("slot_changed")
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var jir_before: Dictionary = SaveSlots.progress("Jiroshi").duplicate(true)
	await t.back_to_menu()
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	t.check(SaveSlots.current == "Marko", "la partida activa es la de Marko")
	t.check(changed.size() >= 1, "slot_changed se emite al cambiar de agente")
	var unlocked := GameState.close_turno(false)
	t.check(unlocked == 2, "cerrar T1 con Marko desbloquea T2 (devolvió %d)" % unlocked)
	t.check(int(SaveSlots.load("Marko").get("turno_desbloqueado", 0)) == 2, "Marko: turno 2 desbloqueado en disco")
	t.check(int(SaveSlots.load("Jiroshi").get("turno_desbloqueado", 0)) == int(jir_before.get("turno_desbloqueado", 1)), "Jiroshi no cambia")
	t.check(FileAccess.file_exists(SaveSlots.checkpoint_path("Marko")) and FileAccess.file_exists(SaveSlots.checkpoint_path("Jiroshi")), "cada agente tiene su checkpoint en su carpeta")
	t.check(str(SaveSlots.read_checkpoint("Marko").get("agente", "")) == "Marko", "el checkpoint de Marko dice Marko")
	t.check(SaveSlots.summary_text("Marko").contains("2"), "el menú muestra el turno de Marko: %s" % SaveSlots.summary_text("Marko"))
	t.check(not SaveSlots.exists("Ttoom"), "Ttoom no tiene partida")
	t.check(SaveSlots.summary_text("Ttoom") == Loc.fmt(Loc.tr("SLOT_EMPTY"), {"agente": "Ttoom"}), "Ttoom: 'Sin partida'")
	# Dificultad por partida.
	SaveSlots.set_difficulty(Difficulty.Level.DIFICIL)
	await t.back_to_menu()
	SaveSlots.select("Jiroshi")
	t.check(Difficulty.level == Difficulty.Level.NORMAL, "Jiroshi conserva su dificultad (Normal)")
	SaveSlots.select("Marko")
	t.check(Difficulty.level == Difficulty.Level.DIFICIL, "Marko recupera su dificultad (Difícil)")
	# Nueva partida (el menú pide confirmación; aquí se llama directo).
	SaveSlots.new("Marko")
	t.check(not SaveSlots.exists("Marko") and int(SaveSlots.progress("Marko").get("turno_desbloqueado", 0)) == 1, "Nueva partida borra la historia de Marko")
	t.check(SaveSlots.exists("Jiroshi"), "y no la de Jiroshi")
	# El menú muestra el estado del agente elegido.
	var menu: Control = t.main.get("main_menu")
	SaveSlots.select("Jiroshi")
	menu.set("agent_index", GameState.AGENTS.find("Jiroshi"))
	menu.call("_build")
	await t.frames(2)
	var lbl := menu.find_child("SlotLbl", true, false) as Label
	t.check(lbl != null and lbl.text.begins_with("Jiroshi"), "el menú muestra la partida de Jiroshi (%s)" % (lbl.text if lbl != null else "sin etiqueta"))


## La partida única de la v0.2 (progreso.json + save_slot_1.json) pasa a la carpeta de su agente.
func _migrar(t: Node) -> void:
	var legacy := SaveSlots.legacy_dir
	var prog := {"turno_desbloqueado": 3, "agent": "Llauri", "mode": 0, "saldo": 54.5, "turnos_cerrados": [1, 2]}
	var cp := {
		"kind": "contacto",
		"game_state": {"mode": 0, "agent": "Llauri", "turno": 2, "clock_seconds": 5400.0, "logged_in": true, "seated_at": "C-14", "current_floor": 2, "distortions_seen": [], "flags": {}},
		"metrics": {"aux": 2, "time_in_aux": {"0": 600.0, "1": 120.0, "2": 300.0, "3": 60.0}, "shift_seconds": 1080.0, "contacts_handled": 3, "angry_total": 0, "written_warnings": 1, "incidents": 0, "alerts": 1, "contact_durations": [60.0, 80.0, 70.0]},
		"fatigue": 33.0, "extra": {}, "saved_at": "2026-11-01T03:00:00",
	}
	_write(legacy + "progreso.json", prog)
	_write(legacy + "save_slot_1.json", cp)
	var done: Array = SaveSlots.migrate_v02()
	t.check(done.size() == 2, "migra progreso y checkpoint (%s)" % str(done))
	var p := SaveSlots.load("Llauri")
	t.check(int(p.get("turno_desbloqueado", 0)) == 3 and is_equal_approx(float(p.get("saldo", 0.0)), 54.5), "progreso de Llauri: T3 y S/ 54.50")
	var mig := SaveSlots.read_checkpoint("Llauri")
	var m: Dictionary = mig.get("metrics", {})
	t.check(int(m.get("aux", -1)) == Metrics.Aux.BO, "AUX KYC de la v0.2 → BO (quedó %s)" % str(m.get("aux")))
	var tia: Dictionary = m.get("time_in_aux", {})
	t.check(is_equal_approx(float(tia.get("0", 0.0)), 720.0), "tiempo en Correo pasa a Available (600 + 120)")
	t.check(is_equal_approx(float(tia.get("1", 0.0)), 300.0), "tiempo en KYC pasa a BO")
	t.check(is_equal_approx(float(tia.get("2", 0.0)), 60.0), "el resto corre una posición (Break 3 → 2)")
	t.check(str(mig.get("agente", "")) == "Llauri" and int(mig.get("version", 0)) == SaveSlots.VERSION, "checkpoint marcado con agente y versión")
	t.check(not FileAccess.file_exists(legacy + "progreso.json") and FileAccess.file_exists(legacy + "progreso.json.v02.bak"), "el archivo viejo queda como .v02.bak")
	t.check(SaveSlots.migrate_v02().is_empty(), "migrar otra vez no hace nada")
	t.check(not SaveSlots.exists("Jiroshi"), "no crea partidas de otros agentes")
	# Continuar la partida migrada.
	SaveSlots.select("Llauri")
	t.main.call("_continue_shift")
	await t.frames(5)
	t.check(GameState.agent == "Llauri" and GameState.turno == 2 and GameState.running, "Continuar sigue la partida migrada de Llauri en T2")
	t.check(Metrics.aux == Metrics.Aux.BO and Metrics.written_warnings == 1, "con su AUX (BO) y sus WW")
	t.check(is_equal_approx(Fatigue.value, 33.0), "y su Fatiga")


## Continuar usa solo el checkpoint del agente elegido.
func _continuar(t: Node) -> void:
	await t.start_shift("Juan", 2)
	await t.login_at_seat()
	await t.advance_clock(1800.0)
	Checkpoints.save_checkpoint("login")
	var juan_clock := GameState.clock_seconds
	await t.back_to_menu()
	SaveSlots.select("Ttoom")
	t.main.call("_continue_shift")  # Ttoom no tiene checkpoint ni turnos: no arranca nada
	await t.frames(3)
	t.check(not GameState.running, "Continuar con Ttoom (sin partida) no toma la de Juan")
	SaveSlots.select("Juan")
	t.main.call("_continue_shift")
	# P7: el reloj se lee en el primer fotograma: sentado sin cola corre a 45x y, con la máquina cargada, 5
	# fotogramas largos ya sumaban más de un minuto de juego (la prueba fallaba a veces en `all`).
	await t.frames(1)
	var clock_now := GameState.clock_seconds
	await t.frames(4)
	t.check(GameState.agent == "Juan" and GameState.turno == 2, "Continuar con Juan sigue su T2")
	t.check(absf(clock_now - juan_clock) < 60.0, "en la hora de su checkpoint (%.0f vs %.0f)" % [clock_now, juan_clock])
	t.check(str(Checkpoints.last_checkpoint.get("agente", "")) == "Juan", "y ese es su checkpoint vivo")


func _write(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))

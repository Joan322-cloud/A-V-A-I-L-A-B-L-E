## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## Runner de escenarios (v0.3, PLAN §10 P1): pruebas deterministas de reglas, una por id.
## Uso:  godot --headless --path game -- --escenario <id>      (un escenario; "arbol:t2c9" = id con argumento)
##       godot --headless --path game -- --escenario p1        (todos los de un paquete; v0.3.1: q1 = v031_q1.gd)
##       godot --headless --path game -- --escenario all       (todos)
##       godot --headless --path game -- --escenario lista     (lista los ids)
##       godot --headless --path game -- --repro-colapso       (= --escenario repro_colapso)
## Opcional: --escala N (Engine.time_scale, por defecto 8), --turno, --dificultad, --slot.
## Sale con código 0 si todo pasó y 1 si algo falló. Las partidas van a user://escenarios_tmp/ (nunca toca
## las del jugador).
##
## Cómo añadir escenarios (P2-P6): un archivo scripts/dev/escenarios/pN_<tema>.gd que extiende RefCounted con
##   func escenarios() -> Array[String]: return ["break_15min", "lunch_overrun", "kyc:"]  # "x:" acepta argumento
##   func run(id: String, arg: String, t: Node) -> void: ...  # corrutina; usa la API de `t` (este runner)
## API de `t`: main, check(cond, msg), fail(msg), note(msg), frames(n), seconds(s), until(cond, timeout_s),
##   start_shift(agente, turno, modo, dificultad), login_at_seat(), advance_clock(segundos_de_juego),
##   set_clock(segundos_de_juego), spy(señal_de_EventBus) -> Array, die(causa, detalle, asesino),
##   wait_death_shown(timeout_s), reconnect(), back_to_menu(), player(), building(), death_screen().

const DIR := "res://scripts/dev/escenarios/"
const SANDBOX := "user://escenarios_tmp"

var main: Node = null
var _registry: Dictionary = {}  # id (o prefijo "x:") -> ruta del script
var _checks: int = 0
var _fails: Array[String] = []
var _spies: Array = []  # [señal, callable]
var _last_agent: String = ""
var _game_s: float = 0.0


func start(p_main: Node, which: String) -> void:
	main = p_main
	var args := OS.get_cmdline_user_args()
	var ei := args.find("--escala")
	Engine.time_scale = float(args[ei + 1]) if ei >= 0 and ei + 1 < args.size() and args[ei + 1].is_valid_float() else 8.0
	_last_agent = str(Loc.get_setting("last_agent", "Jiroshi"))
	_discover()
	get_tree().process_frame.connect(func() -> void: _game_s += get_process_delta_time())
	await get_tree().process_frame
	if which == "lista":
		for id in _sorted_ids():
			print(id, "   (", _registry[id].get_file(), ")")
		_quit(0)
		return
	var ids := _resolve(which)
	if ids.is_empty():
		printerr("[escenario] no existe: ", which, " · usa --escenario lista")
		_quit(2)
		return
	var failed: Array[String] = []
	for full in ids:
		var ok: bool = await _run_one(full)
		if not ok:
			failed.append(full)
	print("[escenario] RESUMEN: %d/%d OK%s" % [ids.size() - failed.size(), ids.size(), ("  · fallaron: " + ", ".join(failed)) if not failed.is_empty() else ""])
	_quit(0 if failed.is_empty() else 1)


func _quit(code: int) -> void:
	GameState.dev_preset_override = "-"
	Loc.set_setting("last_agent", _last_agent)
	Engine.time_scale = 1.0
	get_tree().paused = true
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for p in get_tree().root.find_children("*", type, true, false):
			p.call("stop")
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(code)


## Nombre del guion tal como se carga con load(): `x.gd` en el editor; en un exportado, `x.gdc` o `x.gd.remap`.
static func script_name(f: String) -> String:
	f = f.trim_suffix(".remap")
	if f.ends_with(".gdc"):
		f = f.trim_suffix(".gdc") + ".gd"
	return f


func _discover() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	var seen := {}
	for f0 in d.get_files():
		# v0.3.2-core: en un exportado los guiones van compilados (`x.gdc` + `x.gd.remap`): sin esto el exportado no
		# tenía ningún escenario y no se podía probar nada bajo Wine / en la PC de Joan.
		var f := script_name(f0)
		if seen.has(f):
			continue
		seen[f] = true
		if not ((f.begins_with("p") or f.begins_with("v031_") or f.begins_with("v032_")) and f.ends_with(".gd") and f.contains("_")):  # v0.3.1: v031_q<N>.gd (C11); v0.3.2: v032_*.gd
			continue
		var path := DIR + f
		var scr := load(path) as GDScript
		if scr == null:
			printerr("[escenario] no carga: ", path)
			continue
		var inst: Object = scr.new()
		if inst.has_method("escenarios"):
			for id in inst.call("escenarios"):
				_registry[str(id)] = path


func _sorted_ids() -> Array:
	var ids := _registry.keys()
	ids.sort()
	return ids


## "colapso_reconectar" · "p1" (prefijo de archivo) · "all" · "arbol:t2c9" (id con argumento).
func _resolve(which: String) -> Array[String]:
	var out: Array[String] = []
	if which == "all":
		for id in _sorted_ids():
			if not str(id).ends_with(":"):
				out.append(str(id))
		return out
	if _registry.has(which):
		out.append(which)
		return out
	if which.contains(","):  # v0.3.2: varios ids o grupos separados por comas
		for part in which.split(",", false):
			for id in _resolve(part):
				if not out.has(id):
					out.append(id)
		return out
	if which.begins_with(">"):  # v0.3.2: «>id» = todos los de después de id (retomar una corrida de «all»)
		var from := which.substr(1)
		for id in _sorted_ids():
			if str(id) > from and not str(id).ends_with(":"):
				out.append(str(id))
		return out
	if which.contains(":") and _registry.has(which.get_slice(":", 0) + ":"):
		out.append(which)
		return out
	# v0.3.1 (C11): «q3» o «v031_q3» = las de v031_q3.gd; «v031_q3_media»/«v031_int» = las de ese archivo. Las de Q4 van en
	# pq4_contenido.gd y entran por el prefijo «pq4» de abajo.
	if which.begins_with("v031_") or which.begins_with("v032_") or (which.begins_with("q") and which.length() <= 3):
		var base := which if which.begins_with("v031_") or which.begins_with("v032_") else "v031_" + which
		for id in _sorted_ids():
			if str(_registry[id]).get_file() == base + ".gd" and not str(id).ends_with(":"):
				out.append(str(id))
		return out
	if which.length() <= 3 and which.begins_with("p"):
		for id in _sorted_ids():
			var fn := str(_registry[id]).get_file()
			if (fn.begins_with(which + "_") or fn == which + ".gd") and not str(id).ends_with(":"):
				out.append(str(id))
	return out


func _run_one(full: String) -> bool:
	var id := full
	var arg := ""
	var key := full
	if full.contains(":"):
		id = full.get_slice(":", 0)
		arg = full.substr(id.length() + 1)
		key = id + ":"
	var path := str(_registry.get(key, ""))
	var scr := load(path) as GDScript
	var inst: Object = scr.new()
	_checks = 0
	_fails.clear()
	_clear_sandbox()
	await _reset_world()
	# v0.3.1: las pruebas de la v0.3 (p*_) se escribieron con los relojes de la rc1 (sin cola 45x): las corren con
	# ellos; las de la v0.3.1 (v031_*) con el preset por defecto de la partida (Normal) o el que elijan.
	GameState.dev_preset_override = "-" if path.get_file().begins_with("v031_") or path.get_file().begins_with("v032_") else ""
	print("[escenario] ▶ ", full)
	var t0 := Time.get_ticks_msec()
	await inst.call("run", id, arg, self)
	_clear_spies()
	await _reset_world()
	var ok := _fails.is_empty() and _checks > 0
	if _checks == 0:
		_fails.append("el escenario no comprobó nada")
	print("[escenario] %s %s · %d comprobaciones, %d fallos · %.1f s" % ["OK   " if ok else "FALLO", full, _checks, _fails.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for f in _fails:
		print("      ✗ ", f)
	return ok


func _clear_sandbox() -> void:
	SaveSlots.use_sandbox(SANDBOX)
	_rm_tree(ProjectSettings.globalize_path(SANDBOX))
	SaveSlots.use_sandbox(SANDBOX)


func _rm_tree(abs_path: String) -> void:
	var d := DirAccess.open(abs_path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(abs_path.path_join(f))
	for sub in d.get_directories():
		_rm_tree(abs_path.path_join(sub))
		DirAccess.remove_absolute(abs_path.path_join(sub))


func _reset_world() -> void:
	if main != null and main.has_method("_back_to_menu"):
		main.call("_back_to_menu")
	Difficulty.set_level(Difficulty.Level.NORMAL)
	await frames(3)


# --- API para los escenarios ---------------------------------------------------------------------

func check(cond: bool, msg: String) -> bool:
	_checks += 1
	if not cond:
		_fails.append(msg)
	return cond


func fail(msg: String) -> void:
	_checks += 1
	_fails.append(msg)


func note(msg: String) -> void:
	print("      · ", msg)


func frames(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame


## Espera `s` segundos de juego-real (escalados por Engine.time_scale).
func seconds(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


## Segundos de juego-real desde que arrancó el runner (suma de deltas, o sea escalados por Engine.time_scale). Para
## medir plazos «reales» del juego úsalo en vez de Time.get_ticks_msec() * time_scale: con la máquina cargada el motor
## recorta el paso de cada cuadro (máx. 8 pasos de física) y el juego va más lento que el reloj de pared, así que las
## pruebas con reloj de pared fallaban sin que el juego estuviera mal (v0.3.2: b2_espejo, b2_reconectando_timeout).
func game_s() -> float:
	return _game_s


## Espera hasta que cond() sea true o pasen timeout_s (escalados). Devuelve si se cumplió.
func until(cond: Callable, timeout_s: float = 10.0) -> bool:
	var waited := 0.0
	while not bool(cond.call()):
		if waited >= timeout_s:
			return false
		await get_tree().process_frame
		waited += get_process_delta_time()
	return true


func start_shift(agent: String = "Jiroshi", turno: int = 1, mode: int = 0, dificultad: int = 1) -> void:
	SaveSlots.select(agent)
	SaveSlots.set_difficulty(dificultad)  # la dificultad vive en la partida (como al pulsar Iniciar en el menú)
	main.call("_start_shift", agent, mode, turno)
	await frames(3)


## Sienta al jugador en C-14 (piso 2) y hace login con su checkpoint, como el bot.
func login_at_seat() -> void:
	var b := building()
	if b.current_floor != 2:
		b.go_to_floor(2, "pc")
		await frames(2)
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id("C-14") if fl != null else null
	if seat != null and not player().seated:
		player().sit_at(seat, "C-14")
	if not GameState.logged_in:
		GameState.login()
		Checkpoints.save_checkpoint("login")
	await frames(2)


## Adelanta el reloj de juego `s` segundos de golpe (en pasos de 60 s para que Metrics los reparta).
func advance_clock(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(60.0, left)
		GameState.clock_seconds += step
		EventBus.clock_tick.emit(GameState.clock_seconds)
		left -= step
	await frames(1)


func set_clock(s: float) -> void:
	GameState.clock_seconds = s
	EventBus.clock_tick.emit(s)
	await frames(1)


## Registra cada emisión de una señal de EventBus; devuelve el Array (cada elemento = Array de args).
func spy(sig: String) -> Array:
	var log_arr: Array = []
	var argc := 0
	for info in EventBus.get_signal_list():
		if str(info.get("name", "")) == sig:
			argc = (info.get("args", []) as Array).size()
	var cb: Callable
	match argc:
		0: cb = func() -> void: log_arr.append([])
		1: cb = func(a: Variant) -> void: log_arr.append([a])
		2: cb = func(a: Variant, b: Variant) -> void: log_arr.append([a, b])
		3: cb = func(a: Variant, b: Variant, c: Variant) -> void: log_arr.append([a, b, c])
		_: cb = func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: log_arr.append([a, b, c, d])
	EventBus.connect(sig, cb)
	_spies.append([sig, cb])
	return log_arr


func _clear_spies() -> void:
	for s in _spies:
		if EventBus.is_connected(s[0], s[1]):
			EventBus.disconnect(s[0], s[1])
	_spies.clear()


func die(cause: String, detail: String = "", killer: String = "") -> void:
	Checkpoints.request_death(cause, detail, killer)
	await frames(1)


func wait_death_shown(timeout_s: float = 8.0) -> bool:
	return await until(func() -> bool: return Checkpoints.death_visible and death_screen().visible, timeout_s)


## Lo que hace [Espacio] en la pantalla de muerte.
func reconnect() -> void:
	death_screen().call("_reconnect")
	await frames(2)


func back_to_menu() -> void:
	main.call("_back_to_menu")
	await frames(2)


func player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func death_screen() -> Control:
	return main.get_node("UI/DeathScreen") as Control

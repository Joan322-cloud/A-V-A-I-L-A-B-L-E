## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## web_qa (P7): recorrido corto y medible para los builds exportados (HTML de un archivo, Linux, Windows) que no se
## pueden manejar con el ratón (sin pointer lock en headless). Imprime marcas `[webqa] <paso>` para que el que
## mira (Playwright, un log) sepa qué hay en pantalla en cada momento, y mide los fps de cada vista:
##   calle (llegada) → vestíbulo de los refris del piso 2 (brillo en Compatibility, tope de 16 luces) → C-14
##   sentado y login → PC acercada → una llamada aceptada y respondida → fps en la sala en Calidad Baja y Media
##   → momento pesado (calle con lluvia + persecución de Shero + luces que parpadean con Dread al máximo) →
##   screamer de break_excedido → "Usuario desconectado" → reconectar → fin.
## Uso: <exe> -- --web-qa [--webqa-espera 4]   (HTML de un archivo con `--dev-hash`: abrir con #--%20--web-qa)

var _main: Node = null
var _wait: float = 4.0


func start(main: Node) -> void:
	_main = main
	var args := OS.get_cmdline_user_args()
	var wi := args.find("--webqa-espera")
	if wi >= 0 and wi + 1 < args.size() and args[wi + 1].is_valid_float():
		_wait = float(args[wi + 1])
	_run()


func _mark(step: String, extra: String = "") -> void:
	var hi := OS.get_cmdline_user_args().find("--webqa-hasta")
	if hi >= 0 and hi + 1 < OS.get_cmdline_user_args().size() and OS.get_cmdline_user_args()[hi + 1] == step:
		print("[webqa] corte en ", step)
		_main.call("_back_to_menu")
		AudioManager.quit_game(0)
		await get_tree().create_timer(10.0).timeout
	print("[webqa] %s%s · %.1f fps · calidad %s · %s · objetos %d · huérfanos %d" % [step, (" · " + extra) if extra != "" else "", Engine.get_frames_per_second(), GfxQuality.level(), RenderingServer.get_current_rendering_method(), int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


func _sleep(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## rc1: espera a que pase el tirón de una vez del cambio de calidad (fundir la geometría del piso): hasta 3 cuadros
## seguidos de menos de 600 ms, o 45 s. Devuelve los segundos que tardó (se informan aparte de los fps).
func _settle() -> float:
	var t0 := Time.get_ticks_usec()
	var last := t0
	var good := 0
	while good < 3 and Time.get_ticks_usec() - t0 < 45000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		good = good + 1 if now - last < 600000 else 0
		last = now
	return float(Time.get_ticks_usec() - t0) / 1000000.0


## Reloj de pared (Time), no el delta del motor: el delta se recorta a 8 pasos de física (~133-150 ms) y con
## cuadros lentos (render por software) los fps salían inflados.
func _fps(seconds: float) -> Dictionary:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var worst := 0
	while Time.get_ticks_usec() - t0 < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
	var t := float(Time.get_ticks_usec() - t0) / 1000000.0
	return {"fps": float(frames) / maxf(t, 0.001), "peor_ms": float(worst) / 1000.0}


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func _place(floor_n: int, pos: Vector3, yaw: float, pitch: float = 0.0) -> void:
	var b := _building()
	if b.current_floor != floor_n:
		b.go_to_floor(floor_n, "ascensor")
		await _sleep(0.6)
	var p := _player()
	if p.seated:
		p.stand_up()
	p.teleport(pos, yaw)
	p.head.rotation.x = pitch


func _run() -> void:
	await _sleep(1.0)
	_main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	GameState.flags["revision_ok"] = true
	await _sleep(_wait)
	_mark("calle", "llegada mirando la fachada")
	await _sleep(_wait)
	# Vestíbulo de los refris (piso 2): en Compatibility salía negro con el tope de 8 luces por malla.
	await _place(2, Vector3(3.9, 0, -13.4), 105.0, -0.08)  # rc1: pantry de los pisos v3 (el vestíbulo de antes ya no existe)
	await _sleep(_wait)
	_mark("refris", "vestíbulo de los refris del piso 2")
	await _sleep(_wait)
	# C-14, login, PC acercada.
	var b := _building()
	b.go_to_floor(2, "pc")
	await _sleep(0.6)
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	_player().sit_at(seat, "C-14")
	await _sleep(0.5)
	GameState.login()
	await _sleep(1.0)
	_mark("sentado", "C-14 con sesión en Fonex")
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("set_zoom", true)
	await _sleep(_wait)
	_mark("pc", "PC acercada (escritorio + Ezlaki/Fonex)")
	# Una llamada: se ofrece, se acepta y se responde con el mejor camino.
	var cm := _main.get("contacts") as ContactManager
	var calls: Array = DataLoader.dict("contactos_t1").get("contactos", [])
	var call: Dictionary = {}
	for c in calls:
		if str((c as Dictionary).get("canal", "")) == "llamada":
			call = (c as Dictionary).duplicate(true)
			break
	if cm != null and not call.is_empty():
		cm.offer_now(call)
		await _sleep(1.0)
		_mark("llamada_entra", str(call.get("id", "")))
		cm.accept()
		await _sleep(_wait)
		_mark("llamada", "contacto aceptado: " + str(call.get("id", "")))
		var path := DialogTree.best_path(cm.current)
		for st in path:
			if not cm.is_active():
				break
			cm.choose(int(st["i"]))
			await _sleep(1.2)
		await _sleep(1.0)
		_mark("llamada_fin", "árbol recorrido (%d pasos)" % path.size())
	else:
		_mark("llamada_no", "no se pudo ofrecer la llamada")
	if ws != null:
		ws.call("set_zoom", false)
	# FPS en la sala de pie (la vista más cargada de geometría) en Liviano (v0.3.1 Q5), Baja y Media.
	await _place(2, Vector3(30.0, 0, -6.0), 90.0, -0.05)
	for lv in ["liviano", "baja", "media"]:
		GfxQuality.apply(get_tree(), lv)
		var st := await _settle()  # rc1: el cambio de calidad funde la geometría (un tirón de una vez): aparte
		await _sleep(1.0)
		var r := await _fps(6.0)
		_mark("fps_sala_" + lv, "%.1f fps medios · peor cuadro %.0f ms · cambio de calidad %.1f s" % [r["fps"], r["peor_ms"], st])
	# Momento pesado: calle con lluvia + persecución + parpadeo con Dread al máximo (Calidad Baja).
	GfxQuality.apply(get_tree(), "baja")
	await _place(-1, Vector3(-1.6, 0, 17.5), 0.0, 0.0)  # v0.3.1 Q5: patio hundido bajo la lluvia, mirando la fachada
	await _sleep(1.0)
	Dread.forced = 1.0
	# Shero sale del lobby y camina despacio (0,6 m/s) para que la medición no termine en el screamer.
	Pursuit.start("shero", "break_excedido", 0.6, null, "", -1, Vector3(0, 0, 9.0), func(_i: Dictionary) -> bool: return true)
	await _sleep(0.8)
	for lv in ["liviano", "baja", "media"]:
		GfxQuality.apply(get_tree(), lv)
		var st := await _settle()
		await _sleep(1.0)
		var r := await _fps(5.0)
		_mark("fps_pesado_" + lv, "lluvia (%d gotas) + persecución + Dread 1 · %.1f fps · peor %.0f ms · cambio de calidad %.1f s" % [Weather.drop_count(), r["fps"], r["peor_ms"], st])
	Pursuit.stop("shero", "stop")
	Dread.forced = -1.0
	GfxQuality.apply(get_tree(), "baja")
	# Screamer (como si el break se hubiera pasado) y la pantalla de muerte.
	await _place(2, Vector3(30.0, 0, -6.0), 90.0, 0.0)
	await _sleep(0.5)
	_mark("screamer", "break_excedido")
	Checkpoints.request_death("break_excedido", "16:00")
	var t := 0.0
	while not Checkpoints.death_visible and t < 12.0:
		await _sleep(0.1)
		t += 0.1
	_mark("muerte", "pantalla Usuario desconectado" if Checkpoints.death_visible else "SIN pantalla de muerte")
	await _sleep(_wait)
	Checkpoints.respawn()
	await _sleep(2.0)
	_mark("reconecta", "turno corriendo" if GameState.running and not Checkpoints.dying else "NO reconectó")
	_mark("fin")
	if OS.get_cmdline_user_args().has("--webqa-salir"):
		_main.call("_back_to_menu")  # salir desde el menú, como el jugador (sin turno vivo al cerrar)
		await _sleep(0.5)
		_mark("menu", "de vuelta en el menú")
		AudioManager.quit_game(0)

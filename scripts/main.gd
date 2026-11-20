extends Node
## Main: boot → MainMenu → turno. Crea el edificio, el jugador, Shero, el RTA, Vitzo, el
## director, las distorsiones y la cola de contactos. Conecta muerte y fin de turno.

const PLAYER_SCENE := "res://scenes/jugador/Player.tscn"
const SHERO_SCENE := "res://scenes/personajes/Shero.tscn"
const RTA_SCENE := "res://scenes/personajes/PerritoRTA.tscn"

@onready var world: Node3D = $World
@onready var ui: CanvasLayer = $UI
@onready var main_menu: Control = $UI/MainMenu
@onready var hud: Control = $UI/HUD
@onready var workstation: Control = $UI/Workstation
@onready var death_screen: Control = $UI/DeathScreen
@onready var shift_end: Control = $UI/ShiftEnd
@onready var pause_menu: Control = $UI/PauseMenu
@onready var overlays: Control = $UI/Overlays

var building: Building = null
var player: Player = null
var shero: Shero = null
var rta: PerritoRTA = null
var vitzo: Vitzo = null
var director: Director = null
var distortions: DistortionController = null
var contacts: ContactManager = null
var headless_bot: bool = false
var dev_turno: int = 0  # `-- --turno N`: turno con el que arrancan los bots, las capturas y "Iniciar turno"
var mentor: Mentor = null
var _env: WorldEnvironment = null
var _training_mode: int = 0  # v0.3.2: modo elegido para la partida nueva mientras se hace el Training obligatorio
## v0.3.1 Q1 (F6, Joan 11:14Z): la pausa va en su propia capa, encima de TODO (FeedbackUI, REC, quiz, evento,
## inducción, ascensor, screamers…); mientras está abierta, las demás capas se ocultan y la UI principal queda
## atenuada por el fondo de la pausa. Una muerte o un screamer no se pueden pausar (Escape no abre la pausa sin
## GameState.running), así que nada de eso compite con ella.
const PAUSE_LAYER := 120
var pause_layer: CanvasLayer = null
var _hidden_by_pause: Array[CanvasLayer] = []

# UI responsive: el diseño es 1920×1080 con estirado canvas_items/expand. En ventanas pequeñas o
# verticales (p. ej. el navegador a 660×840) el factor bajaba a 0,34 y todo salía diminuto: aquí el
# factor nunca baja de 2/3 (lo que se ve a 1280×720); por debajo, el viewport lógico se encoge y los
# paneles se centran/ajustan con UITheme.center_fit.
const UI_DESIGN := Vector2(1920, 1080)
const UI_MIN_SCALE := 2.0 / 3.0


func _ready() -> void:
	Controls.setup()
	if bool(Loc.get_setting("fullscreen", false)) and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not OS.has_feature("web"):
		DisplayServer.window_set_min_size(OptionsMenu.min_window_size())  # v0.3.2-core: en escritorio la ventana no baja de 1280×720 (o de lo que quepa en una pantalla más chica)
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = PAUSE_LAYER
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu.reparent(pause_layer, false)
	pause_menu.visibility_changed.connect(_on_pause_visibility)
	main_menu.start_requested.connect(_start_shift)
	main_menu.continue_requested.connect(_continue_shift)
	if main_menu.has_signal("tutorial_requested"):
		main_menu.connect("tutorial_requested", _start_tutorial)
	if main_menu.has_signal("first_training_requested"):
		main_menu.connect("first_training_requested", _start_first_training)
	if main_menu.has_signal("branch_requested"):
		main_menu.connect("branch_requested", _start_branch)
	if main_menu.has_signal("branch_resume_requested"):
		main_menu.connect("branch_resume_requested", _continue_branch)
	shift_end.finished.connect(_back_to_menu)
	pause_menu.quit_to_menu.connect(_back_to_menu)
	death_screen.menu_requested.connect(_back_to_menu)
	EventBus.respawned.connect(_on_respawned)
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	GfxQuality.apply(get_tree())
	EventBus.settings_changed.connect(func(key: String) -> void:
		if key == "quality":
			GfxQuality.apply(get_tree(), str(Loc.get_setting("quality", GfxQuality.default_level()))))
	var tips := AgentTips.new()  # v0.3 P6b: tooltips de primera vez (una vez por partida)
	ui.add_child(tips)
	ui.move_child(tips, overlays.get_index() + 1)
	_show_menu(true)
	_handle_cmdline()


## Con la pausa abierta, toda otra CanvasLayer visible (salvo la UI principal, que la pausa atenúa) se oculta;
## al cerrarla vuelven exactamente las que se ocultaron.
func _on_pause_visibility() -> void:
	if pause_menu.visible:
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			if cl == pause_layer or cl == ui or not cl.visible:
				continue
			cl.visible = false
			_hidden_by_pause.append(cl)
	else:
		for cl in _hidden_by_pause:
			if is_instance_valid(cl):
				cl.visible = true
		_hidden_by_pause.clear()


func _apply_ui_scale() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0:
		return
	var s := minf(win.x / UI_DESIGN.x, win.y / UI_DESIGN.y)
	var root := get_tree().root
	var target := Vector2i(UI_DESIGN) if s >= UI_MIN_SCALE else Vector2i((win / UI_MIN_SCALE).ceil())
	if root.content_scale_size != target:
		root.content_scale_size = target


## Modos de herramienta: `-- --check-all` revisa todos los .gd/.tscn; `-- --bot N [--torpe]` juega N turnos;
## `-- --check-collision` audita huecos de colisión por piso; `-- --walk-test` recorre bordes y esquinas
## con el controlador real; `-- --qa-tour` recorrido de QA con capturas (necesita pantalla) e informe;
## `-- --shot [nombre|all]` guarda capturas en user://shots/ (necesita pantalla: xvfb-run + --rendering-driver opengl3).
## v0.3: `-- --escenario <id|pN|all>` corre pruebas deterministas (scripts/dev/escenarios/p*_*.gd);
## `-- --repro-colapso` es la regresión del bug de colapso de la v0.2 (PLAN §1).
## Los scripts viven en scripts/dev/ y se cargan con load(): el juego exportado nunca depende de ellos.
func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var ti := args.find("--turno")
	if ti >= 0 and ti + 1 < args.size() and args[ti + 1].is_valid_int():
		dev_turno = clampi(int(args[ti + 1]), 1, 10)
	var ei := args.find("--escenario")
	if ei >= 0 or args.has("--repro-colapso"):
		var runner_script := _dev_script("escenarios/runner")
		if runner_script == null:
			get_tree().quit(2)
			return
		headless_bot = true
		var runner: Node = runner_script.new()
		runner.name = "Escenarios"
		add_child(runner)
		var which := "repro_colapso" if ei < 0 else (args[ei + 1] if ei + 1 < args.size() else "all")
		runner.call("start", self, which)
		return
	if args.has("--check-all"):
		var checker_script := _dev_script("check_all")
		if checker_script == null:
			get_tree().quit(2)
			return
		var checker: RefCounted = checker_script.new()
		var n: int = checker.call("run")
		get_tree().quit(1 if n > 0 else 0)
		return
	if args.has("--web-qa"):
		var wq_script := _dev_script("web_qa")
		if wq_script == null:
			get_tree().quit(2)
			return
		var wq: Node = wq_script.new()
		wq.name = "WebQA"
		add_child(wq)
		wq.call("start", self)
		return
	if args.has("--check-collision"):
		var cc_script := _dev_script("check_collision")
		if cc_script == null:
			get_tree().quit(2)
			return
		var cc: Node = cc_script.new()
		cc.name = "CheckCollision"
		add_child(cc)
		cc.call("start", self)
		return
	if args.has("--walk-test") or args.has("--qa-tour") or args.has("--random-walk"):
		var wt_script := _dev_script("walk_test")
		if wt_script == null:
			get_tree().quit(2)
			return
		headless_bot = true
		var wt: Node = wt_script.new()
		wt.name = "WalkTest"
		add_child(wt)
		wt.call("start", self, args.has("--qa-tour"))
		return
	var si := args.find("--shot")
	if si >= 0:
		var shot_script := _dev_script("screenshot")
		if shot_script == null:
			get_tree().quit(2)
			return
		var shooter: Node = shot_script.new()
		shooter.name = "Screenshot"
		add_child(shooter)
		shooter.call("start", self, args[si + 1] if si + 1 < args.size() and not args[si + 1].begins_with("--") else "all")
		return
	if args.has("--bot-tutorial"):
		var bt_script := _dev_script("bot_tutorial")
		if bt_script == null:
			get_tree().quit(2)
			return
		headless_bot = true
		var bt: Node = bt_script.new()
		bt.name = "BotTutorial"
		add_child(bt)
		var sk := args.find("--saltar")
		var skip_ids: Array = Array(args[sk + 1].split(",")) if sk >= 0 and sk + 1 < args.size() else []
		var ei2 := args.find("--escala")
		Engine.time_scale = float(args[ei2 + 1]) if ei2 >= 0 and ei2 + 1 < args.size() else 4.0
		bt.connect("done", func(r: Dictionary) -> void:
			print("[bot-tut] FIN · módulos %s · pasos %d · muertes evitadas %d · errores %s · %.1f s reales (×%.0f)" % [str(r.get("modulos")), int(r.get("pasos", 0)), int(r.get("muertes_evitadas", 0)), str(r.get("errores")), float(r.get("tiempo_real_s", 0.0)), Engine.time_scale])
			Engine.time_scale = 1.0
			get_tree().quit(0 if (r.get("errores", []) as Array).is_empty() else 1))
		bt.call("start", self, [], skip_ids)
		return
	var i := args.find("--bot")
	if i >= 0:
		var bot_script := _dev_script("stress_bot")
		if bot_script == null:
			get_tree().quit(2)
			return
		headless_bot = true
		var runs := 1
		if i + 1 < args.size() and args[i + 1].is_valid_int():
			runs = int(args[i + 1])
		var bot: Node = bot_script.new()
		bot.name = "StressBot"
		add_child(bot)
		bot.call("start", self, runs, args.has("--torpe"))


func _dev_script(p_name: String) -> GDScript:
	var path := "res://scripts/dev/%s.gd" % p_name
	if not ResourceLoader.exists(path):
		printerr("Herramienta no disponible en este build: ", path)
		return null
	return load(path) as GDScript


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GfxQuality.apply_fps_cap()


func _show_menu(on: bool) -> void:
	main_menu.visible = on
	if on:
		Engine.max_fps = mini(GfxQuality.desired_max_fps(), 60)
	else:
		GfxQuality.apply_fps_cap()
	hud.visible = not on
	overlays.visible = not on
	var tips := ui.get_node_or_null("AgentTips") as Control
	if tips != null:
		tips.visible = not on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## `keep_context`: la rama (Elegir turno) y la inducción ya fijaron su contexto de guardado en SaveSlots;
## cualquier otro inicio juega la partida principal del agente.
func _start_shift(agent: String, mode: int, turno: int = 0, keep_context: bool = false) -> void:
	_teardown()
	_reset_modals()
	# v0.3.2-final: un turno que arranca sin pasar por el menú (el Lunes al firmar el Training, los bots que encadenan
	# rondas) no hereda la cola de voces ni los avisos del mundo que se acaba de borrar: un «Agente, al centro de la
	# sala» del turno anterior salía a las 11:49 PM del siguiente. Viniendo del menú ya está todo vacío.
	VoiceDirector.stop_all("menu")
	VoiceDirector.subtitle_shown.emit("", "", 0.0)
	if not keep_context:
		SaveSlots.use_main()
	Checkpoints.reset_runtime()  # sin muerte en curso ni checkpoint de otro turno/agente
	var t := turno if turno > 0 else (dev_turno if dev_turno > 0 else 1)
	if SaveSlots.in_tutorial():
		t = 0  # Inducción = Turno 0 (turnos.json)
	GameState.start_new_shift(t, agent, mode)
	_build_world()
	if t == 7:
		var sun := SundayRestRoom.new()
		sun.name = "SundayRestRoom"
		world.add_child(sun)
		sun.setup(player)
	else:
		building.go_to_floor(-1, "calle")
	_show_menu(false)


## "Continuar" de la partida del agente activo (SaveSlots.current): su checkpoint si hay uno a medias;
## si no, el siguiente turno desbloqueado de esa partida (GDD 4.10). Nunca toma el checkpoint de otro agente.
func _continue_shift() -> void:
	SaveSlots.use_main()
	var agent := SaveSlots.current
	var cp := Checkpoints.read_save(agent)
	var gs: Dictionary = cp.get("game_state", {})
	if cp.is_empty() or str(cp.get("agente", gs.get("agent", agent))) != agent:
		var nxt := GameState.next_turno()
		if nxt > 1 or GameState.max_unlocked_turno() > 1 or SaveSlots.exists(agent):
			_start_shift(agent, int(GameState.progress.get("mode", 0)), nxt)
		return
	_resume_from(agent, cp)


## Elegir turno (PLAN §2 #80): rejugar el turno n (anterior a la frontera) como RAMA desde su instantánea.
## La partida principal no cambia salvo "Seguir desde aquí" al terminar (ShiftEnd). Modo y dificultad: los del
## menú. Devuelve false si el turno no se puede elegir.
func _start_branch(turno: int, mode: int = -1) -> bool:
	var agent := SaveSlots.current
	var m := mode if mode >= 0 else int(SaveSlots.main_progress(agent).get("mode", GameState.Mode.NORMAL))
	var lvl := Difficulty.Level.DIFICIL if m == GameState.Mode.REAL else Difficulty.level
	if not SaveSlots.start_branch(turno, lvl, m, agent):
		return false
	_start_shift(agent, m, turno, true)
	return true


## Retoma la rama guardada del agente activo (su checkpoint; si no tiene, el turno de la rama desde el inicio).
func _continue_branch() -> bool:
	var agent := SaveSlots.current
	var meta := SaveSlots.pending_branch(agent)
	if meta.is_empty() or not SaveSlots.resume_branch():
		return false
	var cp := Checkpoints.read_save(agent)
	var gs: Dictionary = cp.get("game_state", {})
	if cp.is_empty() or str(cp.get("agente", gs.get("agent", agent))) != agent:
		_start_shift(agent, int(GameState.progress.get("mode", 0)), int(meta.get("turno", 1)), true)
		return true
	_resume_from(agent, cp)
	return true


func _resume_from(agent: String, cp: Dictionary) -> void:
	var gs: Dictionary = cp.get("game_state", {})
	_teardown()
	_reset_modals()
	Checkpoints.reset_runtime()
	GameState.start_new_shift(int(gs.get("turno", 1)), agent, int(gs.get("mode", 0)))
	Checkpoints.continue_from(cp)  # restaura estado, métricas, disciplina y Fatiga; vuelve a ser el checkpoint vivo
	_build_world()
	if str(cp.get("kind", "")) == "inicio":
		building.go_to_floor(-1, "calle")
	else:
		building.go_to_floor(GameState.current_floor if GameState.current_floor != 0 else 2, "pc" if GameState.seated_at != "" else "ascensor")
	_show_menu(false)


## Training (antes «Inducción», P6b: scripts/core/tutorial.gd, Turno 0). `modules` = ids de los módulos a hacer en
## orden (vacío = todos los pendientes desde el primero). Usa su propio guardado (SaveSlots "induccion"): nunca
## toca la partida del agente. Devuelve el nodo del tutorial (o null si no existe en este build).
func _start_tutorial(modules: Array = []) -> Node:
	var path := "res://scripts/core/tutorial.gd"
	if not ResourceLoader.exists(path):
		return null
	var tut_script := load(path) as GDScript
	if tut_script == null:
		return null
	SaveSlots.begin_tutorial()
	_start_shift(SaveSlots.current, GameState.Mode.NORMAL, 0, true)
	var tut: Node = tut_script.new()
	tut.name = "Tutorial"
	world.add_child(tut)
	tut.call("begin", self, modules)
	return tut


## v0.3.2 · Partida nueva: el Training (el recuerdo) es obligatorio antes del Lunes. Lo hace entero (los 11 temas,
## se pueden saltar con F8 salvo la firma) y al firmar, _after_training() abre el Lunes de la partida principal.
func _start_first_training(agent: String, mode: int) -> Node:
	SaveSlots.select(agent)
	_training_mode = mode
	var tut := _start_tutorial(Tutorial.first_pending(agent))  # si lo dejó a medias, sigue donde quedó (por agente)
	if tut != null:
		tut.set("first_time", true)
		tut.call("resume_first")
	return tut


## Tras la firma del Training obligatorio: la partida principal queda creada con el contrato firmado y empieza el Lunes.
func _after_training(agent: String, read_contract: bool, memory: Dictionary = {}) -> void:
	SaveSlots.use_main()
	SaveSlots.sign_contract(agent, read_contract, _training_mode)
	SaveSlots.progress(agent)["contrato_leido"] = read_contract
	if not memory.is_empty():  # lo que elegiste en el recuerdo (la foto): los ecos de la semana lo leen (RecuerdosSemana)
		SaveSlots.progress(agent)["recuerdo"] = memory
		SaveSlots.save(agent)
	_start_shift(agent, _training_mode, 1)


func _build_world() -> void:
	building = Building.new()
	building.name = "Building"
	building.add_to_group("building")
	world.add_child(building)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	building.setup(player)
	building.floor_loaded.connect(_on_floor_loaded)
	contacts = ContactManager.new()
	contacts.name = "ContactManager"
	world.add_child(contacts)
	var ecos := RecuerdosSemana.new()  # v0.3.2: la polaroid de tu promoción en C-14 y el primer café (ecos del Training)
	ecos.name = "RecuerdosSemana"
	world.add_child(ecos)
	ecos.setup(building)
	workstation.set("contacts", contacts)
	vitzo = Vitzo.new()
	vitzo.name = "Vitzo"
	world.add_child(vitzo)
	mentor = null
	if GameState.enemy_enabled("mentor"):
		mentor = Mentor.new()
		mentor.name = "Mentor"
		mentor.add_to_group("mentor")
		world.add_child(mentor)
	director = Director.new()
	director.name = "Director"
	director.add_to_group("director")
	world.add_child(director)
	distortions = DistortionController.new()
	distortions.name = "Distortions"
	distortions.add_to_group("distortions")
	world.add_child(distortions)
	# Entorno mínimo: oscuridad, niebla leve, sin sol.
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.01, 0.015)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.3, 0.32)
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	e.fog_light_color = Color(0.02, 0.03, 0.03)
	e.fog_density = 0.01
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# v0.3.2 gfx: punto blanco 2,2 (antes 1,0: todo lo que pasaba de 1 se recortaba a blanco puro y los pasillos claros
	# se veían quemados) con la exposición compensada (×1,3) para que sombras y medios tonos queden donde estaban.
	e.tonemap_white = 2.2
	e.tonemap_exposure = 1.3
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.85  # paleta nocturna desaturada (GDD 8.2); baja con los turnos
	_env.environment = e
	world.add_child(_env)


## Shero y el RTA viven en el piso 2; se crean al cargarlo y se destruyen con él.
func _on_floor_loaded(number: int, floor_node: Node3D) -> void:
	shero = null
	rta = null
	GfxQuality.apply(get_tree())  # sombras de las luces del piso nuevo según la calidad
	if _env != null and floor_node is FloorBase:
		var cfg: Dictionary = (floor_node as FloorBase).env_settings()
		var e := _env.environment
		e.ambient_light_color = cfg.get("ambient", e.ambient_light_color)
		e.ambient_light_energy = float(cfg.get("ambient_energy", e.ambient_light_energy))
		e.fog_light_color = cfg.get("fog", e.fog_light_color)
		e.fog_density = float(cfg.get("fog_density", e.fog_density))
		e.background_color = cfg.get("bg", e.background_color)
		_apply_sky(e, cfg.get("sky", {}))
	if number == 2 and floor_node is FloorBase:
		shero = (load(SHERO_SCENE) as PackedScene).instantiate() as Shero
		floor_node.add_child(shero)
		shero.setup(floor_node as FloorBase, player)
		rta = (load(RTA_SCENE) as PackedScene).instantiate() as PerritoRTA
		floor_node.add_child(rta)
		rta.setup(floor_node as FloorBase, player)
	if GameState.flags.get("locker_done", false) == false and number == 2:
		pass


## Cielo degradado (azotea) o color plano (interiores).
func _apply_sky(e: Environment, sky_cfg: Dictionary) -> void:
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # el cielo no se refleja en techos rugosos
	if sky_cfg.is_empty():
		e.background_mode = Environment.BG_COLOR
		e.sky = null
		return
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = sky_cfg.get("top", Color(0.01, 0.01, 0.03))
	mat.sky_horizon_color = sky_cfg.get("horizon", Color(0.25, 0.12, 0.05))
	mat.sky_curve = 0.12
	mat.ground_bottom_color = sky_cfg.get("ground", Color(0.02, 0.02, 0.025))
	mat.ground_horizon_color = sky_cfg.get("horizon", Color(0.25, 0.12, 0.05))
	mat.sun_angle_max = 0.0
	mat.use_debanding = true
	var sky := Sky.new()
	sky.sky_material = mat
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	e.background_energy_multiplier = 0.6


func _on_respawned(kind: String) -> void:
	# v0.3.2 (Joan: «me mató el Trainer y reaparecí en Available pero fuera de la sala de operaciones»): después de
	# cualquier muerte reapareces SENTADO en tu PC (C-14), con la PC abierta y en «Reconectando» (autoload Reconexion).
	# Quedan igual: el checkpoint de inicio (en la calle, antes del login) y el turno completo de nuevo (Turno real o
	# sin checkpoint: casillero). La Inducción lleva su propio respawn (tutorial.gd).
	if building == null:
		return
	if kind == "inicio":
		building.go_to_floor(-1, "calle")  # checkpoint de inicio de turno (23:48, en la calle)
		return
	if kind == "casillero" or not GameState.logged_in or GameState.is_tutorial():
		var target_floor := 2 if kind == "casillero" else (GameState.current_floor if GameState.current_floor != 0 else 2)
		if building.current_floor != target_floor or kind == "casillero":
			building.go_to_floor(target_floor, "casillero" if kind == "casillero" else "ascensor")
		else:
			var m: Node = building.floor_node.find_child("ascensor", true, false)
			if m is Node3D:
				player.teleport((m as Node3D).global_position, (m as Node3D).rotation_degrees.y)
		return
	seat_at_own_pc(true)


## Sienta al jugador en su puesto (C-14, piso 2) y, si `zoom`, abre la vista de la PC.
func seat_at_own_pc(zoom: bool) -> void:
	if building == null or player == null:
		return
	if player.seated and building.current_floor == 2 and player.seat_id == "C-14":
		if zoom and workstation != null and workstation.visible:
			workstation.call("set_zoom", true)
		return
	if player.seated:
		player.stand_up()
	if building.current_floor != 2 or building.floor_node == null or building.floor_node is Stairwell:
		building.go_to_floor(2, "pc")
	var floor_node := building.floor_node as FloorBase
	var seat := floor_node.seat_by_id("C-14") if floor_node != null else null
	if seat == null:
		return
	player.sit_at(seat, "C-14")
	if zoom and workstation != null and workstation.visible:
		workstation.call("set_zoom", true)


func _teardown() -> void:
	for c in world.get_children():
		c.queue_free()
	building = null
	player = null
	shero = null
	rta = null
	mentor = null


## Volver al menú (Marcar salida, fin de turno, [Esc] en la pantalla de muerte): borra el mundo y deja
## TODO el estado de los autoloads y de las pantallas modales como al arrancar (PLAN §1).
func _back_to_menu() -> void:
	_teardown()
	_reset_modals()
	Checkpoints.reset_runtime()
	GameState.reset_runtime()
	SaveSlots.use_main()  # la rama queda guardada (se retoma desde Elegir turno); la inducción termina
	AudioManager.stop_ambient()
	EventBus.returned_to_menu.emit()
	_show_menu(true)
	main_menu.call("_build")


## Oculta y desactiva pantalla de muerte, resumen, pausa, la PC (Workstation) y overlays; despausa el árbol.
func _reset_modals() -> void:
	get_tree().paused = false
	for n in find_children("*", "", true, false):
		if n is OptionsMenu:
			(n as Control).visible = false  # P7: unas Opciones abiertas no quedan encima del menú o del turno nuevo
	for m in [death_screen, shift_end, pause_menu, workstation]:
		if m != null and m.has_method("reset"):
			m.call("reset")  # v0.3.1 Q1 (B3): la Workstation también (antes el turno nuevo arrancaba dentro de la PC)
	if main_menu != null and main_menu.has_method("close_subpanels"):
		main_menu.call("close_subpanels")
	Screamers.stop_all()
	DeathAnimations.stop_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

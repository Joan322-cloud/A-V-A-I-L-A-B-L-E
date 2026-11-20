## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## stress_bot: juega un turno en headless N veces y reporta muertes/errores.
## Uso: godot --headless --path game -- --bot 3 [--torpe] [--turno N] [--slot <agente>] [--dificultad facil|normal|dificil] [--real]
##      v0.3.1: [--humano] [--duracion corta|normal|larga] [--quieto-respawn S]  ·  v0.3.2: [--bot-escala N] (humano)
## (v0.2: T2/T3; el bot cumple allocations y compra en la expendedora/Marleny)
## Bot "listo": llega, casillero, espera la hora como un agente de verdad, se sienta en C-14, login, acepta
## contactos, elige empatía/proceso/cierre, cambia AUX a tiempo, da Ack, reacciona a Vitzo, se une al coaching.
## v0.3: turno 00:00-08:45, AUX nuevos (BO), 2 breaks de 8 min (02:00 y 06:30) y el lunch a la hora del
## turno (turnos.json/lunch) durante 40 min. Debe terminar con 0 muertes.
## Bot "torpe": ignora todo; debe morir con un motivo de muertes.json.
## v0.3 P3: `--torpe <variante>` = bot listo con UNA falta, para probar cada pista de Discipline; debe morir
## con la causa de la variante (TORPE_CAUSAS) y da Ack a los WW (salvo la variante "ack"):
##   break (no vuelve del 1.er break) · lunch (no vuelve del lunch) · sala (sale de la sala sin AUX) ·
##   correo (abre un caso de BO y no lo trabaja) · isla (se sienta en E-07) · coaching (AUX Coaching sin permiso,
##   lo mata Rasec) · exceso (se queda en Coaching tras la sesión de Shero, Rasec) · noshow (no va al coaching
##   de Shero) · tercer_break · available (todo el turno en BO: lista del Mentor) · perdidas (de pie en la sala,
##   no contesta) · ack (no da Ack a un WW).
## P7 (faltas de P4): vitzo (no reacciona al recordatorio de Vitzo) · correo_vitzo (en un caso de Vitzo le escribe
##   un correo en vez de usar el portal) · wmm (en la llamada/chat WMM envía el correo a Vitzo: T2/T3) · molestos
##   (elige siempre las peores respuestas: 3 molestos seguidos; en T1 los WW llevan al despido).
## v0.3 (P5): `--torpe <variante>` (qa, qa3, training, quiz, rasec, topico, rta) juega como el listo salvo en
## su falta y debe morir con esa causa (bot_p5.gd). El listo pasa la revisión de Don Fermín, atiende a Haime,
## al Trainer y el evento de Rasec, y pide el tópico una vez.
## Las dos familias de variantes comparten `--torpe <variante>`: las de P3 (TORPE_CAUSAS, `_variant`) y las de P5
## (bot_p5.FAULTS, `fault`); con una variante de P3 el gancho de P5 sigue jugando como el listo con sus personajes.
## v0.3.1 Q1 (F23): `--humano` = el bot humano (bot_humano.gd): mismos aciertos que el listo pero con tiempos de una
## persona (reacciona en 3-8 s, lee 6-10 s por nodo, camina por el edificio y toma el ascensor, salta al azar, se
## equivoca 1 de cada 5 contactos, va a la expendedora y al baño). Con N > 1 juega T1 → T2 → T3… seguidos con el mismo
## agente (Continuar). Imprime los minutos reales de cada turno y el reloj por estado (Metrics.clock_meas).
## `--quieto-respawn S` (F17/F20): tras reconectar se queda S segundos reales quieto (sin atender a nadie) y anota si
## vuelve a morir: la auditoría de bucles de muerte.

var runs_total: int = 1
var runs_done: int = 0
var clumsy: bool = false
var deaths: Array[String] = []
var killers: Array[String] = []  # asesino de cada muerte (las variantes torpes lo comparan con muertes.json)
var errors: int = 0
var _main: Node = null
var _t: float = 0.0
var _state: String = "boot"
var _run_time: float = 0.0  # segundos "reales" del turno (delta ya escalado por time_scale = reloj de pared a 1x)
var _wall_start_ms: int = 0
var _max_run_s: float = 3000.0  # tope en segundos escalados por turno (time_scale abajo)
var _breaks_done: int = 0
var _lunch_done: bool = false
var _agent: String = "Jiroshi"
const BREAK_AT_H: Array[float] = [2.0, 6.5]  # horas de juego de los 2 breaks del turno
const BREAK_MIN := 8.0
const LUNCH_MIN := 40.0
const LOGIN_AT_S := -60.0  # 23:59: el bot listo hace la llegada a 3x como un jugador
var _pause_until_clock: float = 0.0
var _fillers: int = 0
var _path_for: String = ""
var _path: Array = []
var _path_i: int = 0
var _variant: String = ""  # --torpe <variante> (v0.3 P3)
var _difficulty: int = -1  # --dificultad (−1 = la de la partida)
## v0.3.2-core: `--bot-fotos S` = partida entera «en fotos». Con ventana (no headless), el 3D no se dibuja salvo un
## cuadro cada S segundos de turno (a 1x) y en los momentos clave (muerte, reaparecer, convocatorias, fin de turno):
## la partida corre casi tan rápido como en headless y deja una tira de capturas en user://fotos/ para mirarla entera.
## (Grabar el turno con --write-movie a 1280×720 por software tardaba ~2 h por turno.)
var _foto_cada: float = 0.0
var _foto_next: float = 0.0
var _foto_n: int = 0
var _foto_busy: bool = false
var _seq: Array[String] = []  # P7: secuencia de la última muerte (screamer / animación) para comprobarla
var _post_ok: bool = true
## v0.3.2 (feedback de Joan sobre los correos): `--correo-ui` = el bot obediente hace los casos de BO (correos, correos de
## Vitzo y KYC) por la interfaz REAL, con dev/manos_pc.gd: clics de ratón sobre los controles de la PC y teclas por la
## ventana, por el camino del manual. Mientras dura el caso el reloj va a 1,5x (los clics son cuadros reales).
var _ui_cases: bool = false
var _ui_busy: bool = false
var _ui_tries: Dictionary = {}  # id del caso → intentos por la interfaz
var ui_outcomes: Array[String] = []  # «id=resultado» de cada caso de BO cerrado
var ui_fallbacks: int = 0  # casos que hubo que terminar sin la interfaz (debe quedar en 0)
var ui_done: int = 0
var _real: bool = false  # --real (P7): Turno real (Difícil, sin checkpoints, al morir reinicia el turno completo)
var _variant_done: bool = false
const TORPE_CAUSAS: Dictionary = {"break": ["break_excedido"], "lunch": ["lunch_excedido"], "sala": ["abandono"], "correo": ["aht_bo"], "isla": ["otra_isla"], "coaching": ["coaching_sin_permiso"], "exceso": ["coaching_exceso"], "noshow": ["coaching"], "tercer_break": ["tercer_break"], "dormido": ["break_excedido"], "comodin_break": ["break_excedido"], "available": ["available_bajo"], "perdidas": ["llamadas_perdidas"], "ack": ["ww_sin_ack"],
	# P7 (P4): Vitzo y clientes
	"vitzo": ["vitzo_reminder"], "correo_vitzo": ["correo_vitzo"], "wmm": ["wmm_correo_vitzo", "wmm_pod_correo"], "molestos": ["tres_molestos", "tercer_ww", "calibracion_final"]}
var _p5: Node = null  # bot_p5.gd: personajes de P5
var fault: String = ""  # variante torpe de P5 ("" = ninguna)
var _pd_variant: String = ""  # variante/falta guardadas mientras corre la verificación tras la muerte
var _pd_fault: String = ""
var _human: Node = null  # bot_humano.gd (--humano)
var _h_need: float = 1.5  # segundos hasta el próximo paso (árbol / caso) del bot humano
var _h_hold_until: float = 0.0  # se quedó leyendo un DM
var _h_contacts: int = 0
var _h_bano_done: bool = false
var _h_doing: String = ""  # qué está haciendo el humano en el estado "h" (break, lunch, bano, volver, llegar)
var _quiet_s: float = 0.0  # --quieto-respawn
var results: Array[String] = []  # una línea por turno (humano)
var _train_first: bool = false  # --tras-training (v0.3.2): partida nueva: primero el Training obligatorio, después el Lunes
## v0.3.2-core2: `--muere HH:MM,HH:MM` = el bot muere a esas horas de juego (una vez cada una) y sigue jugando: para
## mirar cómo se repite un tramo. Esas muertes no cuentan como fallo. Y mide la cola: cuánto llegó a estar libre en
## Available con gente esperando (lo que no puede pasar: «Cola 21» y no entra nada).
var _kill_at: Array[float] = []
var _kill_cause: Array[String] = []  # v0.3.2-core3: `--muere 07:10,07:55=colapso` (sin causa: abandono, la de siempre)
var _forced: int = 0
## v0.3.2-core3: tras reaparecer el bot retoma como una persona: el Break o el Lunch que el checkpoint tenía a medias
## (el HUD lo dice: «Te quedaban 31 min de Lunch»), el tópico si vuelve a estar disponible y el café de cortesía.
var _resume_aux: int = -1
var _resume_left: float = 0.0
## Bucle = muertes seguidas desde el mismo checkpoint: 3 con la misma causa, o 4 de cualquiera. Siempre es un error.
## `--audita-bucle`: las demás muertes no cuentan como fallo (auditoría: «colapso tras reaparecer», «dos muertes del
## mismo checkpoint»); lo que se juzga es que no haya bucle y que el turno termine.
var _audit_loop: bool = false
## v0.3.2-core4: `--pasa-break M` = el bot (el listo, sin --humano) se pasa M minutos de juego en CADA break y vuelve
## a su sitio. Con la escalera nueva y las marcas eso tiene que costar un WW o la vida dentro del turno («no hay
## repeticiones gratis»): veredicto OK solo si hubo al menos un WW o una muerte por break (y nada más raro).
var _over_break: float = 0.0
var _ww_seen: int = 0
var _streak: Array[String] = []
var _streak_max: int = 0
var _loops: int = 0
var _starve_real: float = 0.0
var _starve_from: float = -1.0
var _starve_max_real: float = 0.0
var _starve_max_game: float = 0.0


func start(main: Node, runs: int, p_clumsy: bool) -> void:
	_main = main
	runs_total = runs
	clumsy = p_clumsy
	var args := OS.get_cmdline_user_args()
	var si := args.find("--slot")
	if si >= 0 and si + 1 < args.size() and SaveSlots.agent_from(args[si + 1]) != "":
		_agent = SaveSlots.agent_from(args[si + 1])
	_real = args.has("--real")
	_ui_cases = args.has("--correo-ui")
	if _ui_cases:
		print("[bot] casos de BO por la interfaz real (dev/manos_pc.gd): clics y teclas, no llamadas a ContactManager")
		EventBus.contact_outcome.connect(func(c: Dictionary, o: String, _csat: int) -> void:
			if ContactManager.is_bo(c):
				ui_outcomes.append("%s=%s%s" % [str(c.get("id", "")), o, (" " + str(c.get("_qa", []))) if o == "bo_miss" else ""]))
	_train_first = args.has("--tras-training")
	var mi := args.find("--muere")
	if mi >= 0 and mi + 1 < args.size():
		var plan: Array = []
		for h in args[mi + 1].split(",", false):
			var parts := h.split("=")
			plan.append([GameState.hhmm_to_seconds(parts[0]), parts[1] if parts.size() > 1 else ""])
		plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for e in plan:
			_kill_at.append(float(e[0]))
			_kill_cause.append(str(e[1]))
		print("[bot] morirá a propósito a las %s (para repetir el tramo)" % args[mi + 1])
	_audit_loop = args.has("--audita-bucle")
	var obi := args.find("--pasa-break")
	if obi >= 0 and obi + 1 < args.size() and str(args[obi + 1]).is_valid_float():
		_over_break = maxf(float(args[obi + 1]), 0.0)
		print("[bot] se pasa %.1f min en cada break (--pasa-break): debe costarle un WW o la vida" % _over_break)
	EventBus.written_warning_issued.connect(func(n: int, r: String) -> void:
		_ww_seen = maxi(_ww_seen, n)
		print("[bot] %s WW %d (%s) · marcas de descanso %d" % [GameState.clock_text(), n, r, Discipline.marks_of("break")]))
	var qi := args.find("--quieto-respawn")
	if qi >= 0 and qi + 1 < args.size() and args[qi + 1].is_valid_float():
		_quiet_s = float(args[qi + 1])
	var di := args.find("--duracion")  # v0.3.1: preset del reloj de la partida del bot (corta | normal | larga)
	if di >= 0 and di + 1 < args.size():
		SaveSlots.set_shift_length(args[di + 1].to_lower(), _agent)
	# v0.3.2-core: la dificultad vive en la partida (SaveSlots la vuelve a aplicar al empezar el turno). `--dificultad`
	# solo movía Difficulty al arrancar y la partida nueva del bot la devolvía a Normal: el bot «Difícil» jugaba en Normal.
	var fi := args.find("--bot-fotos")
	if fi >= 0 and fi + 1 < args.size() and args[fi + 1].is_valid_float() and DisplayServer.get_name() != "headless":
		_foto_cada = maxf(float(args[fi + 1]), 2.0)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://fotos"))
		get_tree().root.disable_3d = true  # solo el 3D: la interfaz y las pantallas de la PC siguen dibujándose
		EventBus.respawned.connect(func(_k: String) -> void: _foto_luego(1.2, "reaparece"))
		EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void:
			_foto_luego(0.8, "muerte")
			_foto_luego(7.0, "pantalla"))
		EventBus.qa_feedback_called.connect(func(_n: int) -> void: _foto_luego(1.5, "haime"))
		EventBus.shift_ended.connect(func() -> void: _foto_luego(1.5, "fin"))
	var dfi := args.find("--dificultad")
	if dfi >= 0 and dfi + 1 < args.size():
		_difficulty = Difficulty.level_from_id(args[dfi + 1])
	if _train_first:
		await _do_training()  # antes de enganchar al bot del turno: en el Training manda bot_tutorial
	if args.has("--humano"):
		var hs := load("res://scripts/dev/bot_humano.gd") as GDScript
		if hs != null:
			_human = hs.new()
			_human.name = "BotHumano"
			add_child(_human)
			_human.call("setup", self, 7331 + _agent.hash())
			print("[bot] modo HUMANO (F23) · Duración del turno %s" % SaveSlots.shift_length(_agent))
	var ti := args.find("--torpe")
	var p5_script := load("res://scripts/dev/bot_p5.gd") as GDScript
	if ti >= 0 and ti + 1 < args.size() and not args[ti + 1].begins_with("--") and TORPE_CAUSAS.has(args[ti + 1]):
		_variant = args[ti + 1]
		clumsy = false  # bot listo con una sola falta
		print("[bot] variante torpe: %s (debe morir por %s)" % [_variant, str(TORPE_CAUSAS[_variant])])
	elif ti >= 0 and ti + 1 < args.size() and p5_script != null and str(args[ti + 1]) in p5_script.get_script_constant_map().get("FAULTS", {}):
		fault = str(args[ti + 1])
		clumsy = false  # juega como el listo salvo en su falta
		print("[bot] variante torpe (P5): %s" % fault)
	if p5_script != null:
		_p5 = p5_script.new()
		_p5.name = "BotP5"
		add_child(_p5)
		_p5.call("setup", self, fault)
	EventBus.authorization_ended.connect(_on_auth_ended)
	EventBus.discipline_step.connect(func(tr_id: String, st: int, inf: Dictionary) -> void:
		print("[bot] %s Shero/disciplina: %s escalón %d %s" % [GameState.clock_text(), tr_id, st, str(inf.get("ejecutor", ""))]))
	EventBus.pursuit_started.connect(func(h: String, c: String) -> void: print("[bot] %s persecución: %s (%s) · jugador en el piso %d" % [GameState.clock_text(), h, c, GameState.current_floor]))
	Engine.time_scale = 16.0  # acelera el reloj real; el de juego escala igual
	if _human != null:
		# Camina de verdad: a 8x con 180 pasos de física por segundo cada paso es de 4 cm (como a 1x con 22 ms).
		Engine.time_scale = 8.0
		# v0.3.2: `--bot-escala N` (grabaciones con --write-movie: a 4x cada cuadro de 30 fps son 0,13 s de juego).
		var bi := args.find("--bot-escala")
		if bi >= 0 and bi + 1 < args.size() and args[bi + 1].is_valid_float():
			Engine.time_scale = clampf(float(args[bi + 1]), 1.0, 8.0)
		Engine.physics_ticks_per_second = 180
		Engine.max_physics_steps_per_frame = 64
		_max_run_s = 4200.0
	EventBus.death_shown.connect(_on_death)
	EventBus.rta_hunt_started.connect(func() -> void: print("[bot] %s caza del RTA · %s" % [GameState.clock_text(), _aux_state()]))
	EventBus.death_sequence_started.connect(func(c: String, k: String, _d: String) -> void: _seq = ["inicio:%s@%s" % [c, k]])
	EventBus.screamer_finished.connect(func(c: String) -> void: _seq.append("screamer:" + c))
	EventBus.death_animation_finished.connect(func(c: String) -> void: _seq.append("colapso:" + c))
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.contact_offered.connect(_on_offered)
	EventBus.contact_accepted.connect(_on_accepted)
	EventBus.written_warning_issued.connect(_on_ww)
	EventBus.vitzo_reminder.connect(_on_vitzo)
	EventBus.coaching_requested.connect(_on_coaching)
	EventBus.email_over_time.connect(_on_email_over)
	EventBus.allocation_posted.connect(_on_allocation)
	EventBus.ezlak_post.connect(_on_ezlak_post)
	EventBus.contact_outcome.connect(func(c: Dictionary, o: String, csat: int) -> void:
		if o in ["perdido", "bo_miss"]:
			print("[bot] %s %s: %s (QA %s)" % [GameState.clock_text(), o, str(c.get("id", "")), str(c.get("_qa", []))])
		elif o in ["satisfecho", "neutral", "molesto"]:
			print("[bot] %s árbol %s → %s CSAT %d %s" % [GameState.clock_text(), str(c.get("id", "")), o, csat, str(c.get("_choices", []))]))
	EventBus.allocation_ended.connect(func() -> void:
		if not clumsy:
			await get_tree().create_timer(1.0).timeout
			var cm := _contacts()
			if cm != null and not cm.is_active() and _state == "work":
				Metrics.set_aux(Metrics.Aux.AVAILABLE))
	EventBus.trainer_talk.connect(func(s: float) -> void: print("[bot] %s charla del Trainer (%d s)" % [GameState.clock_text(), int(s)]))
	EventBus.contact_offered.connect(func(c: Dictionary) -> void:
		var cmo := _contacts()
		var kind := "sustituto" if bool(c.get("sustituto", false)) else ("desborde" if bool(c.get("desborde", false)) else ("relleno" if bool(c.get("relleno", false)) else "guion"))
		print("[bot] %s entra %s (%s%s%s) · cola %d · huecos %d" % [GameState.clock_text(), str(c.get("id", "")), kind, ", prestado" if bool(c.get("prestado", false)) else "", ", repetido" if c.has("repetido") else "", GameState.queue_size, cmo.slots_pending() if cmo != null else -1]))
	EventBus.contact_ended.connect(func(c: Dictionary, r: bool, a: bool) -> void:
		if bool(c.get("relleno", false)):
			_fillers += 1
		print("[bot] %s contacto %s resuelto=%s molesto=%s AUX=%s AVL=%d%% · t_real %ds" % [GameState.clock_text(), str(c.get("id", "")), str(r), str(a), Metrics.aux_name(), int(Metrics.available_pct()), int(_run_time)])
		# int (Llauri) + pisos (QA): si la allocation del Mentor terminó con un caso abierto, allocation_ended no lo
		# devolvía a Available y el bot obediente se quedaba en BO hasta el lunch. Una sola vía: _back_from_bo.
		if not clumsy and (ContactManager.is_bo(c) or Metrics.aux == Metrics.Aux.BO):
			_back_from_bo.call_deferred())
	EventBus.hour_changed.connect(func(h: int) -> void:
		var cmh := _contacts()
		print("[bot] hora %d · Fatiga %d · Shero %d · estado %s · AUX %s · cola %s %s" % [h, int(Fatigue.value), _shero_state(), _state, Metrics.aux_name(), str(cmh.phase) if cmh != null else "-", str(cmh.current.get("id", "")) if cmh != null else ""]))
	_begin_run()


func _shero_state() -> int:
	var sh := get_tree().get_first_node_in_group("shero") as Shero
	return sh.state if sh != null else -1


func _begin_run() -> void:
	_state = "boot"
	_run_time = 0.0
	_wall_start_ms = Time.get_ticks_msec()
	_breaks_done = 0
	_lunch_done = false
	_variant_done = false
	_fillers = 0
	_t = 0.0
	if _p5 != null:
		_p5.call("reset_run")
	_h_contacts = 0
	_h_bano_done = false
	_h_hold_until = 0.0
	if _human != null:
		_human.call("reset_stats")
	# _start_shift ya llama Checkpoints.reset_runtime(): el torpe termina la ronda sin reaparecer y la
	# siguiente muerte vuelve a contar.
	if _train_first and runs_done == 0:
		pass  # el Lunes ya lo abrió Main._after_training al firmar (ver _do_training)
	elif _human != null and runs_done > 0:
		_main.call("_continue_shift")  # el humano sigue con el turno siguiente de su partida (T1 → T2 → T3)
	else:
		if _difficulty >= 0:
			SaveSlots.select(_agent)
			SaveSlots.set_difficulty(_difficulty)
		_main.call("_start_shift", _agent, GameState.Mode.REAL if _real else GameState.Mode.NORMAL)
	print("[bot] %s · dificultad %s" % ["Turno real" if GameState.is_real_mode() else "Turno normal", Difficulty.id()])
	print("[bot] turno %d/%d (%s) · %s · Turno %d · %s · Fatiga %d · saldo %s · lunch %s" % [runs_done + 1, runs_total, ("torpe " + fault) if fault != "" else ("torpe " + _variant) if _variant != "" else ("torpe" if clumsy else "listo"), _agent, GameState.turno, Difficulty.id(), int(Fatigue.value), Economy.soles(Economy.saldo), GameState.clock_text_at(GameState.lunch_clock())])


## v0.3.2 · `--tras-training`: el paso de mando del Training al primer turno. Empieza como el botón «Empezar · Training»
## de una partida nueva (Main._start_first_training), el bot del Training hace los 14 módulos y firma, y cuando
## Main._after_training abre el Lunes este bot lo juega como siempre (casillero, login, la cola ACD…).
func _do_training() -> void:
	_state = "training"
	var scale := Engine.time_scale
	Engine.time_scale = 8.0
	var t0 := Time.get_ticks_msec()
	var tut: Node = _main.call("_start_first_training", _agent, GameState.Mode.REAL if _real else GameState.Mode.NORMAL)
	var bt: Node = (load("res://scripts/dev/bot_tutorial.gd") as GDScript).new()
	bt.name = "BotTraining"
	bt.set("log_steps", false)
	bt.set("timeout_s", 3000.0)
	add_child(bt)
	var rep: Array = []
	bt.connect("done", func(r: Dictionary) -> void: rep.append(r))
	bt.call("attach", _main, tut, [])
	print("[bot] partida nueva de %s: Training obligatorio (%d módulos)" % [_agent, (tut.get("queue") as Array).size() if tut != null else 0])
	while is_inside_tree() and not (GameState.turno == 1 and GameState.running and not GameState.is_tutorial()):
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 1500000:
			break
	var t1 := Time.get_ticks_msec()
	while is_inside_tree() and rep.is_empty() and Time.get_ticks_msec() - t1 < 4000:
		await get_tree().process_frame  # el informe del bot del Training llega medio segundo después de la firma
	var r: Dictionary = rep[0] if not rep.is_empty() else {}
	var ok := not rep.is_empty() and GameState.turno == 1 and GameState.running and not GameState.is_tutorial() and (r.get("errores", []) as Array).is_empty()
	var c := SaveSlots.contract(_agent)
	print("[bot] Training %s: módulos %s · errores %s · %.0f s reales · contrato firmado=%s leído=%s · recuerdo %s → %s, turno %d, contexto %s" % ["HECHO" if ok else "FALLÓ", str((r.get("modulos", {}) as Dictionary).size()), str(r.get("errores", [])), (Time.get_ticks_msec() - t0) / 1000.0, str(c.get("firmado", false)), str(c.get("leido", false)), str(SaveSlots.progress(_agent).get("recuerdo", {})), Days.day_name(GameState.turno) if ok else "?", GameState.turno, "principal" if not SaveSlots.in_tutorial() else "training"])
	if not ok:
		errors += 1
	bt.queue_free()
	Engine.time_scale = scale


func _process(delta: float) -> void:
	if _state == "training":
		return  # el bot del Training tiene el control hasta que empieza el Lunes
	_run_time += delta
	_t += delta
	if _foto_cada > 0.0 and _run_time >= _foto_next:
		_foto_next = _run_time + _foto_cada
		_foto("t")
	if _run_time > _max_run_s:
		printerr("[bot] tope de tiempo alcanzado en estado %s, reloj %s, contactos %d" % [_state, GameState.clock_text(), Metrics.contacts_handled])
		errors += 1
		_finish_run()
		return
	var building := get_tree().get_first_node_in_group("building") as Building
	var player := get_tree().get_first_node_in_group("player") as Player
	if building == null or player == null:
		return
	_queue_watch(delta)
	if not _kill_at.is_empty() and GameState.logged_in and GameState.clock_seconds >= _kill_at[0] and Checkpoints.can_die() and not Checkpoints.in_respawn_grace() and not Metrics.reconnecting:
		_kill_at.pop_front()
		var why: String = _kill_cause.pop_front() if not _kill_cause.is_empty() else ""
		_forced += 1
		print("[bot] %s muerte A PROPÓSITO (--muere%s) · Fatiga %d · checkpoint %s" % [GameState.clock_text(), (" " + why) if why != "" else "", int(Fatigue.value), _cp_text()])
		if why == "colapso":
			Fatigue.set_value(99.0)
			Fatigue.add(5.0, true)  # el colapso de verdad: cruza 100 con add
		elif why != "":
			Checkpoints.request_death(why)
		else:
			Checkpoints.request_death("abandono", "", "shero")
		return
	if _p5 != null and (_state == "p5" or bool(_p5.call("busy"))):
		return  # P5 tiene el control (Haime, Trainer, Rasec, tópico, Don Fermín)
	if _human != null and _state in ["h", "boot", "seat", "break", "lunch"]:
		_human_tick()
		return
	match _state:
		"boot":
			if _p5 != null and not clumsy and bool(_p5.call("handle_boot")):
				return
			if _t > 1.0:
				building.go_to_floor(2, "casillero")
				_state = "locker"
				_t = 0.0
		"locker":
			if _t > 0.5:
				var locker := building.floor_node.find_child("MiCasillero", true, false)
				if locker is Interactable:
					(locker as Interactable).interact(player)
				var fridge := building.floor_node.find_child("Refri1", true, false)
				if fridge is Interactable:
					(fridge as Interactable).interact(player)  # taper a la refri
				_state = "seat"
				_t = 0.0
		"seat":
			if not GameState.logged_in and not clumsy and GameState.clock_seconds < LOGIN_AT_S:
				return  # llegada a 3x hasta las 23:59 (el torpe se loguea enseguida)
			if building.current_floor != 2:
				building.go_to_floor(2, "entrada_sala")  # p. ej. reapareció en el -1 (checkpoint del lunch)
				return
			var seat := _session_seat(building)
			if seat != null:
				player.sit_at(seat, seat.seat_id)
				if not GameState.logged_in:
					GameState.login()
					Checkpoints.save_checkpoint("login")
				elif not clumsy and _variant == "" and fault == "" and Metrics.aux != Metrics.expected_aux and _resume_aux < 0:
					# v0.3.1: al reconectar, el AUX del checkpoint puede no ser el que dicta el RTA (lo repite en #allocations),
					# p. ej. Lunch de un checkpoint del lunch: el listo ya lo dio por hecho (_lunch_done) y vuelve a trabajar.
					Metrics.set_aux(Metrics.expected_aux if Metrics.is_productive(Metrics.expected_aux) else Metrics.Aux.AVAILABLE)
					print("[bot] %s reconectado en su sitio: AUX %s" % [GameState.clock_text(), Metrics.aux_name()])
				_state = "work"
				_t = 0.0
		"work":
			if clumsy:
				_clumsy_tick()
			else:
				if _variant != "" and _variant_tick(building, player):
					return
				_smart_tick()
		"torpe":
			# la variante ya cometió su falta: espera a que Shero (o Rasec) la cobre
			if _variant == "dormido" and not _asleep_done and building.current_floor == -1 and building.floor_node != null:
				_asleep_done = _sleep_on_puff(player)
		"break":
			# De pie en el pasillo del agua hasta la hora; luego vuelve a C-14 y a Available.
			if _variant in ["break"] or (_variant == "tercer_break" and _breaks_done >= 2):
				return
			if GameState.clock_seconds >= _pause_until_clock:
				_return_to_seat(building, player)
				_breaks_done += 1
		"lunch":
			if _variant == "lunch":
				return
			WorldObjects.TaperFlow.bot_step(player)  # v0.3.1 Q4 (F15): saca el taper del microondas y lo come
			if GameState.clock_seconds >= _pause_until_clock:
				if building.current_floor != 2:
					building.go_to_floor(2, "entrada_sala")
					return
				_return_to_seat(building, player)
				_lunch_done = true
		"done":
			pass


## Silla con tu sesión (normalmente C-14; tras la distorsión 4 puede ser otra).
func _session_seat(building: Building) -> WorldObjects.Seat:
	var fl := building.floor_node as FloorBase
	if fl == null:
		return null
	var c14 := fl.seat_by_id("C-14")
	if c14 != null and c14.has_session:
		return c14
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is WorldObjects.Seat and (n as WorldObjects.Seat).has_session:
			return n as WorldObjects.Seat
	return c14


func _return_to_seat(building: Building, player: Player) -> void:
	var seat := _session_seat(building)
	if seat == null:
		return
	player.sit_at(seat, seat.seat_id)
	# Vuelve al AUX que dicta el RTA (BO si hay una allocation del Mentor en curso; si no, Available).
	Metrics.set_aux(Metrics.expected_aux if Metrics.is_productive(Metrics.expected_aux) else Metrics.Aux.AVAILABLE)
	_state = "work"
	_t = 0.0
	print("[bot] %s de vuelta en %s" % [GameState.clock_text(), seat.seat_id])


## Breaks (02:00 y 06:30, 8 min de juego en el pasillo del agua) y Lunch (a la hora de turnos.json,
## 40 min: refri → cafetería del -1).
func _maybe_pause(building: Building, player: Player) -> bool:
	var cm := _contacts()
	if cm == null or cm.phase != ContactManager.Phase.IDLE:
		return false
	var now := GameState.clock_seconds
	if _variant == "available":
		return false  # todo el turno en BO, sin pausas
	# v0.3.2-core3: el checkpoint estaba en pleno Break o Lunch y el HUD dice «Te quedaban X min: [n] para seguir». El
	# bot lo retoma dentro de «Reconectando», como quien pulsa la tecla (fuera de «Reconectando» sería otro break).
	var resume := _resume_aux >= 0 and Metrics.reconnecting and Reconexion.resume_aux == _resume_aux and _pd_variant == "" and _pd_fault == "" and _variant == "" and fault == ""
	if _resume_aux >= 0 and not Metrics.reconnecting:
		_resume_aux = -1  # se le pasó la cuenta: ya está en Available
		_lunch_done = RtaControl.lunch_taken()
		_breaks_done = Metrics.breaks_used
	if (Metrics.reconnecting and not resume) or _pd_variant != "" or _pd_fault != "":
		# v0.3.2-core: mientras se verifica el respawn el bot no sale de break. Antes, si la muerte lo devolvía a una
		# hora con el break ya vencido (variante available en el T3), se levantaba en el primer cuadro y la
		# comprobación «reaparece sentado en C-14 en Reconectando» fallaba por culpa del bot, no del juego.
		return false
	if resume and Reconexion.left > Reconexion.duration() - 1.5:
		return false  # un segundo y medio para leer el aviso
	var res_b := resume and _resume_aux == Metrics.Aux.BREAK
	var res_l := resume and _resume_aux == Metrics.Aux.LUNCH
	if _variant == "comodin_break" and now >= 0.4 * 3600.0 and _breaks_done >= 2:
		# v0.3.2-core4 (punto 6): el tercer break lo pone un compañero con el comodín; el bot se queda en el pasillo del
		# agua y se pasa de los 10 minutos que el comodín cubre: lo tiene que matar la escalera del break, sin bucle.
		if _breaks_done >= 3:
			return false
		player.stand_up()
		var zc := building.floor_node.find_child("Zone_pasillo_agua", true, false)
		if zc is Node3D:
			player.teleport((zc as Node3D).global_position, 0.0)
		Comodin.answer_override = func(_n: String) -> bool: return true
		if Comodin.open():
			Comodin.choose_aux(Metrics.Aux.BREAK)
			Comodin.choose_coworker(0)
		_breaks_done = 3
		_state = "torpe"
		print("[bot] %s tercer break con el comodín (variante comodin_break)" % GameState.clock_text())
		return true
	if _variant in ["tercer_break", "comodin_break"] and now >= 0.4 * 3600.0 and _breaks_done < 3:
		Metrics.set_aux(Metrics.Aux.BREAK)
		_pause_until_clock = GameState.clock_seconds + 3.0 * 60.0
		_state = "break"
		print("[bot] %s break %d (variante %s)" % [GameState.clock_text(), Metrics.breaks_used, _variant])
		return true
	if resume:
		# La tecla se pulsa YA, dentro de «Reconectando» (elegir Break un segundo después de que venza sería otro break:
		# el bot esperaba su tiempo de reacción antes de elegir y así se ganó un tercer break, y otro, y otro).
		_pick_aux(_resume_aux)
		if Metrics.aux != _resume_aux or Metrics.reconnecting:
			_resume_aux = -1
			return false
	var may_break := _breaks_done < BREAK_AT_H.size() and _breaks_done < Metrics.breaks_allowed() and Metrics.breaks_used < Metrics.breaks_allowed() and now >= BREAK_AT_H[mini(_breaks_done, BREAK_AT_H.size() - 1)] * 3600.0 and not (now >= GameState.lunch_clock() - 600.0 and not _lunch_done)
	if _human != null and _variant == "" and fault == "":
		if res_b or (not resume and may_break):
			_pause_until_clock = now + _pause_len("break")
			_human_pause("break", res_b)
			return true
		if not resume and not _lunch_done and now >= GameState.lunch_clock() + float(DataLoader.bal("lunch/ventana_despues_min", 15.0)) * 60.0:
			_lunch_done = true  # se le pasó la ventana (p. ej. el training la tapó): un agente ya no sale a almorzar
			_human.log_t("se le pasó la hora del lunch: no sale")
		if res_l or (not resume and not _lunch_done and now >= GameState.lunch_clock()):
			_pause_until_clock = now + _pause_len("lunch")
			_human_pause("lunch", res_l)
			return true
		if not resume and not _h_bano_done and now >= 3.2 * 3600.0 and now < 5.5 * 3600.0 and Metrics.aux == Metrics.Aux.AVAILABLE:
			_human_bano()
			return true
		return false
	if res_b or (not resume and may_break):
		var b_len := _pause_len("break")
		if _over_break > 0.0:
			b_len = (float(DataLoader.bal("cupos_aux_min/break", 10.0)) + _over_break) * 60.0
		Metrics.set_aux(Metrics.Aux.BREAK)
		player.stand_up()
		var z := building.floor_node.find_child("Zone_pasillo_agua", true, false)
		if z is Node3D:
			player.teleport((z as Node3D).global_position, 0.0)
		_pause_until_clock = GameState.clock_seconds + b_len
		_state = "break"
		print("[bot] %s break %d/%d" % [GameState.clock_text(), Metrics.breaks_used, Metrics.breaks_allowed()])
		return true
	if res_l or (not resume and not _lunch_done and now >= GameState.lunch_clock()):
		var l_len := _pause_len("lunch")
		Metrics.set_aux(Metrics.Aux.LUNCH)
		player.stand_up()
		var fridge := building.floor_node.find_child("Refri1", true, false)
		if fridge is Interactable:
			(fridge as Interactable).interact(player)  # saca el taper
		building.go_to_floor(-1, "cafeteria")
		for n in ["Microondas", "Expendedora", "MostradorMarleny"]:
			var o := building.floor_node.find_child(n, true, false)
			if o is Interactable:
				(o as Interactable).interact(player)
				# v0.2: la expendedora y el mostrador abren un menú; el bot compra lo primero (si le alcanza) o cierra.
				var shop := get_tree().get_first_node_in_group("shop_menu")
				if shop != null and bool(shop.get("_open")):
					if not bool(shop.call("buy_index", 0)):
						shop.call("close")
					print("[bot] %s compra en %s · saldo %s · Fatiga %d" % [GameState.clock_text(), n, Economy.soles(Economy.saldo), int(Fatigue.value)])
		_pause_until_clock = GameState.clock_seconds + l_len
		_state = "lunch"
		print("[bot] %s lunch en la cafetería" % GameState.clock_text())
		return true
	return false


func _contacts() -> ContactManager:
	var c: Variant = _main.get("contacts")
	return c as ContactManager if is_instance_valid(c) else null


## Bot listo: resuelve cada contacto con la frase adecuada y respeta las reglas.
func _smart_tick() -> void:
	var building := get_tree().get_first_node_in_group("building") as Building
	var player := get_tree().get_first_node_in_group("player") as Player
	var cm := _contacts()
	if cm == null or building == null or player == null:
		return
	if not cm.is_active():
		# Si la sesión ya no está en esta silla (distorsión 4), cámbiate de sitio.
		var seat := _session_seat(building)
		if player.seated and seat != null and seat.seat_id != player.seat_id:
			player.stand_up()
			_state = "seat"
			return
		# Un caso BO que se ofreció mientras no estaba listo (p. ej. volvía del feedback) espera: ábrelo ahora.
		if cm.phase == ContactManager.Phase.OFFERING and cm.is_bo(cm.current) and cm.player_ready() and _t >= 1.5:
			_t = 0.0
			cm.accept()
			return
		_maybe_pause(building, player)
		return
	if _t < (_h_need if _human != null else 1.5):
		return
	if _human != null and _run_time < _h_hold_until:
		return  # se quedó leyendo un DM
	_t = 0.0
	if _human != null:
		_h_need = float(_human.call("t_read")) if cm.tree != null else (float(_human.call("t_kyc")) if cm.case != null and cm.case.is_kyc() else float(_human.call("t_click")))
	if cm.tree != null:
		_tree_step(cm)
	elif cm.case != null:
		_case_step(cm)


## v0.3 (P4): árbol de diálogo — sigue el mejor camino (DialogTree.best_path) y hace las acciones en el
## Portal Vitzo como un jugador (buscar la operación, Contacto partner). Nunca envía un correo a Vitzo.
func _tree_step(cm: ContactManager) -> void:
	var id := str(cm.current.get("id", ""))
	if _path_for != id:
		_path_for = id
		_path = _p5.call("path_for", cm.current) if _p5 != null else []
		if _variant == "molestos":
			_path = DialogTree.best_path(cm.current, "peor")
		elif _variant == "wmm" and _wmm_path(cm.current).size() > 0:
			_path = _wmm_path(cm.current)
		if _path.is_empty():
			_path = DialogTree.best_path(cm.current)
		_path_i = 0
	if not cm.composer.is_empty():
		if _variant == "wmm":
			print("[bot] %s envía el correo a Vitzo desde el árbol %s (variante wmm)" % [GameState.clock_text(), id])
			cm.composer_send()
			return
		cm.composer_cancel()
		return
	if cm.tree.waiting_action():
		var a := cm.tree.pending_action()
		var tx := str((cm.current.get("portal", {}) as Dictionary).get("tx", ""))
		if a == "portal_pod":
			cm.portal_search(tx)
		elif a == "portal_contacto":
			if cm.portal_view.is_empty():
				cm.portal_search(tx)
			cm.portal_contact()
		return
	if _path_i < _path.size():
		cm.choose(int(_path[_path_i]["i"]))
		_path_i += 1
	else:
		cm.choose(0)


## Variante wmm: un camino del árbol que abre el correo a Vitzo (el que el listo cancela).
func _wmm_path(c: Dictionary) -> Array:
	# El correo tiene que ser la primera acción: si antes hay una del portal, su resultado real (POD sí/no) puede
	# no ser el del camino simulado y el bot terminaría en otra rama (t2c9).
	var fallback: Array = []
	for p in DialogTree.enumerate_paths(c, 5000):
		var sim := DialogTree.simulate(c, p)
		if bool(sim.get("correo", false)):
			var acc: Array = sim.get("acciones", [])
			if not acc.is_empty() and str(acc[0]).begins_with("correo"):
				return p
			if fallback.is_empty():
				fallback = p
	return fallback


## v0.3 (P4): caso de BO, un paso por tick (como un agente que hace clic): Kardex → portal → campos →
## enviar → tipificar → cerrar; KYC: mira 10 s de juego y decide lo correcto.
func _case_step(cm: ContactManager) -> void:
	var k := cm.case
	var c := cm.current
	if _ui_cases and _variant == "" and fault == "" and not clumsy and int(_ui_tries.get(str(c.get("id", "")), 0)) < 2:
		if not _ui_busy:
			_ui_case(cm)
		return
	if k.is_kyc():
		if _human == null and GameState.clock_seconds - cm._start_clock < 10.0 * GameState.clock_speed():
			return
		cm.kyc_decide(str(c.get("correcto", "rechazar")))
		return
	var corr: Dictionary = c.get("correcto", {})
	if not k.kardex_done:
		cm.kardex_lookup(k.tx())
		return
	if _variant == "correo_vitzo" and not (corr.get("portal", []) as Array).is_empty():
		# Caso de Vitzo: en vez del portal, le escribe un correo (lo que el recordatorio prohíbe).
		if k.recipient != "Vitzo":
			cm.open_mailto_vitzo()
			return
		if k.template == "":
			cm.set_template("Status")
			return
		for f in CasoBO.FIELDS:
			if str(k.fields.get(f, "")) == "":
				cm.set_field(f, str((corr.get("campos", {}) as Dictionary).get(f, "x")) if (corr.get("campos", {}) as Dictionary).has(f) else "x")
				return
		print("[bot] %s envía un correo a Vitzo en el caso %s (variante correo_vitzo)" % [GameState.clock_text(), str(c.get("id", ""))])
		cm.send_email()
		return
	for pa in corr.get("portal", []):
		var step := str(pa)
		if k.portal_done.has(step):
			continue
		match step:
			"buscar": cm.portal_search(k.tx())
			"pod": cm.portal_download_pod()
			"reversal": cm.portal_reversal()
			"contacto": cm.portal_contact()
		return
	var dest := str(corr.get("destinatario", ""))
	if dest != "" and k.sent.is_empty():
		if k.recipient != dest:
			cm.set_recipient(dest)
			return
		if k.template != str(corr.get("plantilla", "")):
			cm.set_template(str(corr.get("plantilla", "")))
			return
		for f in CasoBO.FIELDS:
			var want := str((corr.get("campos", {}) as Dictionary).get(f, ""))
			if str(k.fields.get(f, "")) != want:
				cm.set_field(f, want)
				return
		if bool(corr.get("adjunto_pod", false)) and not k.attach_pod:
			cm.portal_attach_pod()
			return
		cm.send_email()
		return
	if k.typification != str(corr.get("tipificacion", "")):
		cm.set_typification(str(corr.get("tipificacion", "")))
		return
	print("[bot] %s caso %s cerrado en %s de juego" % [GameState.clock_text(), str(c.get("id", "")), Loc.mmss(cm.email_elapsed)])
	cm.close_case()


## `--correo-ui`: el caso entero por la interfaz real (corrutina; el bot sigue dando Ack y reaccionando mientras tanto).
func _ui_case(cm: ContactManager) -> void:
	_ui_busy = true
	var c := cm.current
	var cid := str(c.get("id", ""))
	_ui_tries[cid] = int(_ui_tries.get(cid, 0)) + 1
	var manos_script := load("res://scripts/dev/manos_pc.gd") as GDScript
	var m: Object = manos_script.new()
	var ok := false
	var scale := Engine.time_scale
	if bool(m.call("setup", _main)):
		Engine.time_scale = minf(scale, 1.5)
		ok = await m.call("play", manos_script.call("manual_steps", c), cid)
		Engine.time_scale = scale
	if ok:
		ui_done += 1
		print("[bot] %s caso %s hecho por la interfaz (%d clics)" % [GameState.clock_text(), cid, int(m.get("clicks"))])
	else:
		print("[bot] %s caso %s: la interfaz no pudo (intento %d): %s" % [GameState.clock_text(), cid, int(_ui_tries[cid]), " / ".join(PackedStringArray(m.get("fails")))])
		if int(_ui_tries[cid]) >= 2 and cm.phase == ContactManager.Phase.ACTIVE and str(cm.current.get("id", "")) == cid:
			ui_fallbacks += 1  # se termina por la vía vieja (y la pasada lo cuenta como fallo)
	_ui_busy = false


## Bot torpe: se levanta en Live y no hace nada más.
func _clumsy_tick() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if _t > 3.0 and player != null and player.seated:
		player.stand_up()


func _on_offered(_c: Dictionary) -> void:
	if clumsy or _state in ["torpe", "humano_quieto"]:
		return
	await get_tree().create_timer(float(_human.call("t_react")) if _human != null else 0.5).timeout
	if _human != null:
		_h_contacts += 1
		_h_need = float(_human.call("t_read"))
		_t = 0.0
	var cm := _contacts()
	if cm != null:
		cm.accept()


func _on_accepted(_c: Dictionary) -> void:
	pass


func _on_ww(_n: int, _reason: String) -> void:
	print("[bot] %s WW #%d (%s)" % [GameState.clock_text(), _n, _reason])
	if not clumsy and _variant != "ack":
		await get_tree().create_timer(float(_human.call("t_ack")) if _human != null else 0.3).timeout
		Metrics.give_ack()


func _on_vitzo(_t: String, _s: float) -> void:
	print("[bot] %s recordatorio de Vitzo (%d s)" % [GameState.clock_text(), int(_s)])
	if _variant == "vitzo":
		print("[bot] %s no reacciona al recordatorio (variante vitzo)" % GameState.clock_text())
		return
	if not clumsy:
		await get_tree().create_timer(float(_human.call("t_react")) if _human != null else 0.5).timeout
		# Como un jugador: clic en la reacción del mensaje de Vitzo en #site-updates (Ezlaki).
		var hub := EzlakHub.get_hub(get_tree())
		if hub == null or not hub.react(hub.pending_actionable()):
			EventBus.vitzo_reacted.emit()


## Allocation del Mentor (T3+): el bot listo cambia el AUX en seguida.
func _on_allocation(aux: int, comply_s: float, until_clock: float) -> void:
	print("[bot] %s allocation del Mentor: %s hasta %s (%d s)" % [GameState.clock_text(), Metrics.aux_name(aux), GameState.clock_text_at(until_clock), int(comply_s)])
	if not clumsy:
		await get_tree().create_timer(float(_human.call("t_react")) if _human != null else 1.0).timeout
		if _state == "work":
			Metrics.set_aux(aux)


## v0.3.2 IA: como un jugador atento, reacciona con ✅ al aviso de coaching de Shero en cuanto lo lee.
func _react_to_notice() -> void:
	var hub := EzlakHub.get_hub(get_tree())
	if hub == null:
		return
	for i in 80:  # el aviso sale tras su «escribiendo…»
		if not hub.reaction_pending.is_empty():
			break
		await get_tree().create_timer(0.25).timeout
	if hub.reaction_pending.is_empty():
		return
	await get_tree().create_timer(float(_human.call("t_read")) if _human != null else 1.0).timeout
	if hub.reaction_pending.is_empty():
		return
	var res := hub.player_react(hub.message_by_id(int(hub.reaction_pending.get("id", -1))), "✅")
	print("[bot] %s reacciona al aviso de Shero (%s)" % [GameState.clock_text(), res])


## Minitraining del Mentor: el bot lo completa en Campus a los 2 s (respuesta correcta).
func _on_ezlak_post(_ch: String, _author: String, _text: String, meta: Dictionary) -> void:
	if _human != null and not clumsy and _ch.begins_with("dm:") and bool(meta.get("mention", false)) and _human.call("chance", 0.25):
		_h_hold_until = _run_time + float(_human.call("t_read"))  # se queda leyendo el DM
	if not clumsy and _author == "rta" and str(meta.get("tipo", "")) in ["tag", "caza"] and bool(meta.get("mention", false)):
		_on_rta_tag(str(meta.get("tipo", "")))
	if not clumsy and bool(meta.get("pide_reaccion", false)):
		_react_to_notice()  # v0.3.2 IA: el aviso de Shero que pide reacción (emoji = «estoy al tanto»)
	if clumsy or str(meta.get("tipo", "")) != "minitraining":
		return
	await get_tree().create_timer(2.0 if _human == null else float(_human.call("t_read")) * 2.0).timeout
	var m := get_tree().get_first_node_in_group("mentor") as Mentor
	if m != null:
		m.complete_minitraining(str(meta.get("id", "")))


## v0.3.1: el RTA te taguea en #allocations: el listo lee el mensaje y corrige el AUX (como en el Fonex).
func _on_rta_tag(tipo: String) -> void:
	print("[bot] %s el RTA taguea (%s) · %s" % [GameState.clock_text(), tipo, _aux_state()])
	await get_tree().create_timer(float(_human.call("t_react")) if _human != null else 1.0).timeout
	if _state != "work" or _variant != "" or fault != "":
		return
	var cm := _contacts()
	if cm != null and cm.is_active():
		return
	var want := Metrics.expected_aux if Metrics.is_productive(Metrics.expected_aux) else RtaControl.pending_order()
	if Metrics.aux != want:
		Metrics.set_aux(want)
		print("[bot] %s corrige el AUX a %s" % [GameState.clock_text(), Metrics.aux_name()])


## v0.3.1 (integración): si la allocation del Mentor terminó mientras trabajaba un caso de BO (allocation_ended
## no lo saca de BO con un caso abierto), al cerrar el caso vuelve a Available. Antes se quedaba en BO hasta el
## lunch y el Available % bajaba al 52 % (WW available_bajo y caza de Shero en T3, Llauri).
func _back_from_bo() -> void:
	await get_tree().create_timer(1.0).timeout
	var cm := _contacts()
	if clumsy or _variant != "" or cm == null or cm.is_active() or _state != "work":
		return
	if Metrics.aux == Metrics.Aux.BO and Metrics.allocation_aux < 0 and Metrics.expected_aux != Metrics.Aux.BO and Metrics.authorization_of("tm").is_empty():
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		print("[bot] %s caso de BO cerrado sin allocation: vuelve a Available" % GameState.clock_text())


func _on_coaching(_s: float) -> void:
	if not clumsy and _variant != "noshow":
		await get_tree().create_timer(float(_human.call("t_react")) if _human != null else 1.0).timeout
		# Lo mismo que unirse desde Ezlaki Rooms en la PC: la sala deja de contar y Shero lo sabe.
		var hub := EzlakHub.get_hub(get_tree())
		if hub != null and hub.rooms_pending:
			hub.join_rooms()
		else:
			EventBus.coaching_joined.emit()


## v0.3 P3: al terminar la sesión de coaching de Shero el bot listo vuelve a Available (si no, Rasec: exceso).
func _on_auth_ended(source: String) -> void:
	if clumsy or _variant == "exceso" or source != "shero":
		return
	await get_tree().create_timer(float(_human.call("t_ack")) if _human != null else 0.8).timeout
	if Metrics.aux == Metrics.Aux.COACHING:
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		print("[bot] %s fin del coaching de Shero: vuelve a Available" % GameState.clock_text())


## v0.3 P3: la falta de cada variante de --torpe. Devuelve true si este tick ya lo usó la variante.
func _variant_tick(building: Building, player: Player) -> bool:
	var now := GameState.clock_seconds
	var cm := _contacts()
	if _variant_done or cm == null or cm.phase != ContactManager.Phase.IDLE or now < 0.5 * 3600.0:
		if _variant == "correo" and cm != null and cm.case != null:
			return true  # abre el caso y no lo trabaja
		return false
	match _variant:
		"sala":
			_variant_done = true
			player.stand_up()
			var z := building.floor_node.find_child("Zone_pasillo_agua", true, false)
			if z is Node3D:
				player.teleport((z as Node3D).global_position, 0.0)
			_state = "torpe"
			print("[bot] %s sale de la sala sin AUX (Available)" % GameState.clock_text())
			return true
		"isla":
			_variant_done = true
			player.stand_up()
			var seat := (building.floor_node as FloorBase).seat_by_id("E-07")
			if seat != null:
				player.sit_at(seat, "E-07")
			# P7: en BO (los casos de BO no se pierden) para que solo corra la pista "otra isla": en Available, en T2/T3
			# las llamadas que suenan en C-14 se perdían y la escalera de llamadas perdidas llegaba antes (tercer_ww).
			Metrics.set_aux(Metrics.Aux.BO)
			_state = "torpe"
			print("[bot] %s se sienta en E-07 (otra isla)" % GameState.clock_text())
			return true
		"coaching":
			_variant_done = true
			Metrics.set_aux(Metrics.Aux.COACHING)
			_state = "torpe"
			print("[bot] %s AUX Coaching sin permiso" % GameState.clock_text())
			return true
		"exceso", "noshow":
			_variant_done = true
			Discipline.request_coaching("shero")
			if _variant == "exceso":
				_state = "torpe"
			print("[bot] %s Shero lo convoca a coaching (%s)" % [GameState.clock_text(), _variant])
			return _variant == "exceso"
		"available":
			if Metrics.aux != Metrics.Aux.BO:
				Metrics.set_aux(Metrics.Aux.BO)
				print("[bot] %s se queda en BO todo el turno" % GameState.clock_text())
			return false
		"dormido":
			# v0.3.2-core4 (punto 5): Break de verdad (con su checkpoint, como en el menú de la PC) y a dormir a los pufs
			# del -1: el reloj corre a 30x y la escalera del break y Shero tienen que llegar igual.
			_variant_done = true
			_pick_aux(Metrics.Aux.BREAK)
			player.stand_up()
			building.go_to_floor(-1, "ascensor")
			_asleep_done = false
			_state = "torpe"
			print("[bot] %s Break y baja a dormir a los pufs (variante dormido)" % GameState.clock_text())
			return true
		"perdidas":
			_variant_done = true
			player.stand_up()
			player.teleport(player.global_position + Vector3(0, 0, 1.5), 0.0)
			_state = "torpe"
			print("[bot] %s de pie en la sala sin contestar" % GameState.clock_text())
			return true
		"ack":
			_variant_done = true
			Discipline.debug_fire("sala", 3)  # un WW (como si hubiera salido) que el bot no confirma
			print("[bot] %s WW sin Ack (variante ack)" % GameState.clock_text())
			return false
	return false


var _asleep_done: bool = false


## Variante dormido: se echa en el primer puf libre del piso (false si todavía no hay ninguno cargado).
func _sleep_on_puff(player: Player) -> bool:
	for s in get_tree().get_nodes_in_group("sleep_spots"):
		if s is SleepSpot and (s as SleepSpot).is_inside_tree():
			player.teleport((s as SleepSpot).global_position + Vector3(0, 0, -1.2), 0.0)
			if (s as SleepSpot).interact(player) and SleepSpot.is_player_sleeping():
				print("[bot] %s dormido en %s (reloj x%.0f)" % [GameState.clock_text(), (s as SleepSpot).spot_id, GameState.clock_multiplier() if GameState.has_method("clock_multiplier") else 0.0])
				return true
	return false


func _on_email_over(_id: String, _s: float) -> void:
	if not clumsy:
		var ws := get_tree().get_first_node_in_group("workstation")
		if ws != null:
			ws.call("_answer_excuse", int(DataLoader.bal("correo_bo/excusa_correcta", 2)) - 1)


## Libre en Available, sentado en tu puesto, con gente esperando en la cola: cuánto dura (segundos reales y de juego).
func _queue_watch(delta: float) -> void:
	var cm := _contacts()
	var idle := cm != null and cm.phase == ContactManager.Phase.IDLE and Metrics.aux == Metrics.Aux.AVAILABLE and cm.player_ready() and not Metrics.reconnecting and not Checkpoints.dying and GameState.queue_size > 0
	if not idle:
		_starve_real = 0.0
		_starve_from = -1.0
		return
	if _starve_from < 0.0:
		_starve_from = GameState.clock_seconds
	_starve_real += delta
	_starve_max_real = maxf(_starve_max_real, _starve_real)
	_starve_max_game = maxf(_starve_max_game, GameState.clock_seconds - _starve_from)


func _on_death(cause: String) -> void:
	deaths.append(cause)
	killers.append(Checkpoints.death_killer)
	print("[bot] %s muerte: %s (%s) · asesino %s · piso %d · cuadro %d" % [GameState.clock_text(), cause, Checkpoints.cause_text(cause), Checkpoints.death_killer, GameState.current_floor, Engine.get_frames_drawn()])
	if _variant != "" or fault != "":
		await _post_death(cause)
		_finish_run()
	elif clumsy:
		_finish_run()
	else:
		if _p5 != null:
			_p5.call("on_death")
		await get_tree().create_timer(2.0 if _human == null else 3.0 + float(_human.call("t_react"))).timeout
		Checkpoints.respawn()
		print("[bot] %s reconecta (%s) · %s" % [GameState.clock_text(), cause, _aux_state()])
		_state = "seat"
		_after_respawn(cause)
		if _state == "done":
			return  # bucle: el turno se cortó
		if _quiet_s > 0.0:
			await _quiet_after_respawn(cause)


func _cp_text() -> String:
	var cp := Checkpoints.last_checkpoint
	if cp.is_empty():
		return "-"
	return "%s de las %s (Fatiga %d)" % [str(cp.get("kind", "-")), GameState.clock_text_at(float((cp.get("game_state", {}) as Dictionary).get("clock_seconds", 0.0))), int(float(cp.get("fatigue", 0.0)))]


## v0.3.2-core3 — Recién reaparecido (el listo y el humano). Comprueba las reglas del respawn (nunca más Fatiga que la
## del checkpoint; tras un colapso o dos muertes seguidas desde el mismo checkpoint, como mucho el tope de la
## dificultad; el saldo, el del checkpoint), detecta el bucle y deja al bot como lo dejaría una persona: con los
## breaks y el lunch que el checkpoint dice, y listo para retomar el Break/Lunch que estaba a medias.
func _after_respawn(cause: String) -> void:
	var cp := Checkpoints.last_checkpoint
	var real := GameState.is_real_mode() or not Checkpoints.matches_current(cp)
	var n := Checkpoints.deaths_from_checkpoint()
	if not real:
		var cp_f := float(cp.get("fatigue", 0.0))
		var cap := Checkpoints.fatigue_cap()
		var capped := cause == "colapso" or n >= 2
		var ok_f := Fatigue.value <= cp_f + 0.5 and (not capped or Fatigue.value <= cap + 0.5)
		var eco: Dictionary = cp.get("economy", {})
		var ok_s := not eco.has("saldo") or absf(float(eco.get("saldo", 0.0)) - Economy.saldo) < 0.005
		var hubt := PersonajesP5.get_hub(get_tree())
		print("[bot] reaparece: Fatiga %d (checkpoint %s%s) · muertes seguidas desde ahí %d · tópico pedido %d · breaks %d · lunch %s · saldo %s%s · aviso «%s»" % [int(Fatigue.value), _cp_text(), (", tope %d" % int(cap)) if capped else "", n, hubt.topico.requests() if hubt != null and hubt.topico != null else -1, Metrics.breaks_used, "hecho" if RtaControl.lunch_taken() else "pendiente", Economy.soles(Economy.saldo), " (café de cortesía)" if Economy.courtesy_coffee() else "", Reconexion.pending_notice()])
		if not ok_f:
			errors += 1
			print("[bot] ERROR: reaparece con Fatiga %.1f: el checkpoint tenía %.1f%s" % [Fatigue.value, cp_f, (" y el tope es %.0f" % cap) if capped else ""])
		if not ok_s:
			errors += 1
			print("[bot] ERROR: reaparece con saldo %s y el checkpoint tenía %s" % [Economy.soles(Economy.saldo), Economy.soles(float(eco.get("saldo", 0.0)))])
		if n <= 1:
			_streak.clear()
		_streak.append(cause)
		_streak_max = maxi(_streak_max, _streak.size())
		var s := _streak.size()
		if s >= 4 or (s >= 3 and _streak[s - 1] == _streak[s - 2] and _streak[s - 2] == _streak[s - 3]):
			_loops += 1
			errors += 1
			print("[bot] BUCLE: %d muertes seguidas desde el checkpoint %s: %s" % [s, _cp_text(), str(_streak)])
			_finish_run()
			return
	# Lo que el checkpoint dice que ya hiciste (antes solo tras una muerte de --muere; si no, el bot daba por hecho el
	# lunch en el que murió y no volvía a pedir el tópico aunque el checkpoint fuera anterior).
	_lunch_done = RtaControl.lunch_taken()
	_breaks_done = Metrics.breaks_used
	_resume_aux = -1
	_resume_left = 0.0
	if _p5 != null:
		_p5.call("after_respawn")
	if not real and Reconexion.active and Reconexion.resume_aux in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH]:
		_resume_aux = Reconexion.resume_aux
		_resume_left = Reconexion.resume_left_s
		if _resume_aux == Metrics.Aux.LUNCH:
			_lunch_done = false
		else:
			_breaks_done = maxi(Metrics.breaks_used - 1, 0)


## Cuánto dura la pausa que empieza: la del bot (8 min de break, 40 de lunch) o, si retoma la del checkpoint, lo que
## le quedaba de cupo menos 3 min para volver.
func _pause_len(kind: String) -> float:
	var full := (LUNCH_MIN if kind == "lunch" else BREAK_MIN) * 60.0
	if _human != null:
		# v0.3.2-core4: como una persona que mira el contador del AUX: sale de vuelta con margen para llegar caminando
		# antes del límite (unos 34 s reales desde el -1; dentro del cupo el reloj del break/lunch corre a 5-20x, así
		# que ese paseo son varios minutos de juego). Antes volvía a los 40 fijos y llegaba al filo de los 45: con la
		# escalera nueva eso es un llamado y una marca cada vez.
		var limite := float(DataLoader.bal("cupos_aux_min/" + kind, 45.0 if kind == "lunch" else 10.0))
		var vuelta_min := 34.0 * GameState.reloj(kind, 4.0) / 60.0 + 1.0
		full = minf(full, maxf(limite - vuelta_min, 3.0) * 60.0)
	if _resume_aux < 0:
		return full
	var left := _resume_left
	_resume_aux = -1
	_resume_left = 0.0
	print("[bot] %s retoma el %s del checkpoint (le quedaban %d min)" % [GameState.clock_text(), kind, int(left / 60.0)])
	return clampf(left - 180.0, 60.0, full)


## Elige un AUX como quien juega, en el menú de la PC (Workstation._pick_aux): con el checkpoint que eso guarda.
func _pick_aux(aux: int) -> void:
	GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
	Metrics.set_aux(aux)
	Checkpoints.on_aux_picked(aux)


## Estado de AUX para el registro (diagnóstico de cazas del RTA y de reconexiones).
func _aux_state() -> String:
	var hub := PersonajesP5.get_hub(get_tree())
	var auths: Array[String] = []
	for a in Metrics.authorizations:
		auths.append("%s:%s" % [str(a.get("source", "")), Metrics.aux_name(int(a.get("aux", -1)))])
	return "AUX %s, esperado %s, allocation %s, strikes RTA %d, autorizaciones %s, estado %s" % [Metrics.aux_name(), Metrics.aux_name(Metrics.expected_aux), Metrics.aux_name(Metrics.allocation_aux) if Metrics.allocation_aux >= 0 else "-", hub.rta.strikes() if hub != null else -1, str(auths), _state]


## P7: tras la muerte de una variante torpe comprueba lo que Joan vio roto en la v0.2: la secuencia (screamer si hay
## asesino, animación de colapso si es Fatiga), el texto de «Usuario desconectado» sin puntuación suelta, que
## [Espacio] reconecta y se puede seguir jugando sin volver a morir (sin bucle), que el Turno real reinicia el turno
## desde el casillero, que se vuelve al menú y que otro agente puede empezar su turno.
func _post_death(cause: String) -> void:
	var killer := Checkpoints.death_killer
	var want_scr := Checkpoints.uses_screamer(killer)
	var seq_ok := _seq.size() >= 2 and _seq[1] == ("screamer:" if want_scr else "colapso:") + cause
	_post("secuencia %s → %s" % [str(_seq), "screamer" if want_scr else "colapso"], seq_ok)
	if want_scr:
		# v0.3.1 (muertes propias): corrió la animación de esa muerte y de ese asesino, con todos sus tiempos.
		var info: Dictionary = Screamers.last_info
		var k := str(info.get("kill", ""))
		var spec: Dictionary = KillMoves.SPEC.get(k, {})
		var kb: Array = info.get("beats", [])
		print("[bot] animación de muerte: %s · %s · tiempos %s" % [k, str(info.get("intro", "")), str(kb)])
		_post("animación «%s» de %s para %s (tiempos %d/%d)" % [k, str(spec.get("asesino", "?")), cause, kb.size(), (spec.get("beats", []) as Array).size()],
			str(info.get("cause", "")) == cause and str(spec.get("asesino", "")) == killer and kb == spec.get("beats", []))
	var ds: Control = _main.get("death_screen")
	var motivo := Checkpoints.cause_text(cause, Checkpoints.death_detail)
	var txt := ""
	# v0.3.1 Q2: el motivo entra corrupto entre la estática y se fija letra por letra (~1,7 s): se lee ya fijo.
	for _i in 40:
		txt = ""
		for n in ds.find_children("*", "Label", true, false):
			txt += (n as Label).text + "\n"
		if txt.contains(motivo):
			break
		await get_tree().create_timer(0.1).timeout
	var bad := RegEx.create_from_string("(:\\s*$|:\\s*\\.|\\(\\s*\\)|\\s[.,:])").search(motivo)
	_post("pantalla «%s»" % txt.strip_edges().replace("\n", " | "), ds.visible and bad == null and txt.contains(motivo))
	# Reconectar ([Espacio]) y seguir jugando como el listo
	var v := _variant
	var f := fault
	_variant = ""
	fault = ""
	_pd_variant = v  # si el turno cierra durante la verificación, el veredicto es el de la variante
	_pd_fault = f
	var hub5: PersonajesP5 = _p5.get("_hub") if _p5 != null else null
	if _p5 != null:
		_p5.set("fault", "")
	if hub5 != null and hub5.training != null:
		hub5.training.forced_answers = [-1, -1, -1, -1, -1]  # tras reaparecer juega como el listo (también el quiz)
	var deaths_before := deaths.size()
	ds.call("_reconnect")
	await get_tree().create_timer(1.0).timeout
	var real := GameState.is_real_mode()
	_post("reconecta (pantalla oculta, turno corriendo)", not ds.visible and GameState.running and not Checkpoints.dying)
	if not real and GameState.logged_in and not GameState.is_tutorial():
		# v0.3.2 (Joan): reapareces sentado en tu PC (C-14), con la PC abierta, en «Reconectando».
		_post("reaparece sentado en %s (piso %d) en «%s»" % [GameState.seated_at, GameState.current_floor, Metrics.aux_name()],
			GameState.seated_at == "C-14" and GameState.current_floor == 2 and Metrics.reconnecting)
	if _quiet_s > 0.0:
		# v0.3.2-core2: «quieto» desde ya, no después de los 5 s de abajo. Al repetir un tramo ahora suena un sustituto
		# a los ~9 s de reconectar; el bot lo contestaba (todavía «listo») y un instante después se quedaba quieto con
		# el cliente en línea: cliente molesto, +8 de Fatiga y, con la Fatiga alta de la variante `molestos`, un colapso
		# dos horas de juego más tarde que la auditoría contaba como bucle. Quien se queda quieto no contesta.
		_state = "humano_quieto"
		if _p5 != null:
			_p5.process_mode = Node.PROCESS_MODE_DISABLED
	if _quiet_s > 0.0 and not real and GameState.logged_in:
		# v0.3.2: elegir Available enseguida no da una perdida al instante (y después sigue quieto S s).
		var p0 := int(Discipline.counters.get("perdidas", 0))
		GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		var tw := _run_time
		while _run_time < tw + 5.0 and not Checkpoints.dying and not GameState.shift_over:
			await get_tree().process_frame
		var p1 := int(Discipline.counters.get("perdidas", 0))
		print("[bot] AVAILABLE al reaparecer: %d perdidas en 5 s (AUX %s)" % [p1 - p0, Metrics.aux_name()])
		_post("Available al instante tras reaparecer: sin perdida inmediata (%d)" % (p1 - p0), p1 == p0)
	if _quiet_s > 0.0:
		# v0.3.1 (F17/F20): auditoría de bucles. Quieto S s reales sin atender a nadie: ¿vuelve a morir?
		_state = "humano_quieto"
		if _p5 != null:
			_p5.process_mode = Node.PROCESS_MODE_DISABLED
		var tq := _run_time
		while _run_time < tq + _quiet_s and deaths.size() == deaths_before and not GameState.shift_over:
			await get_tree().process_frame
		var again := deaths.size() > deaths_before
		var cut := " (el turno terminó a los %.0f s)" % (_run_time - tq) if GameState.shift_over and not again else ""
		print("[bot] QUIETO %.0f s tras reconectar de %s (%s, sentado=%s, AUX %s): %s%s" % [_quiet_s, cause, GameState.clock_text(), str(GameState.seated_at), Metrics.aux_name(), ("MUERE de nuevo a los %.1f s: %s" % [_run_time - tq, str(deaths.slice(deaths_before))]) if again else "sin muerte", cut])
		_post("quieto %.0f s tras reconectar sin volver a morir (bucle)" % _quiet_s, not again)
		if _p5 != null:
			_p5.process_mode = Node.PROCESS_MODE_INHERIT
		if again:
			# vuelve a reconectar para poder seguir con el resto de la verificación
			await get_tree().create_timer(6.0).timeout
			ds.call("_reconnect")
			await get_tree().create_timer(1.0).timeout
			deaths_before = deaths.size()
	if real:
		_post("Turno real: reinicia el turno completo desde el casillero (%s, piso %d)" % [GameState.clock_text(), GameState.current_floor], GameState.clock_seconds < 0.0 and GameState.current_floor == 2)
	_state = "boot" if real else "seat"
	# El listo retoma según el estado restaurado (la variante pudo marcar el lunch como hecho para saltárselo).
	_lunch_done = RtaControl.lunch_taken()
	if not real and GameState.logged_in:
		Metrics.set_aux(Metrics.expected_aux if Metrics.is_productive(Metrics.expected_aux) else Metrics.Aux.AVAILABLE)
	var t_end := _run_time + 90.0
	while _run_time < t_end and deaths.size() == deaths_before:
		await get_tree().process_frame
	_post("90 s de juego (real a 1x) después sin volver a morir (muertes nuevas: %s)" % str(deaths.slice(deaths_before)), deaths.size() == deaths_before)
	while deaths.size() > deaths_before:
		deaths.pop_back()
		killers.pop_back()
	# Volver al menú y empezar con otro agente
	_main.call("_back_to_menu")
	await get_tree().create_timer(0.5).timeout
	var other := "Llauri" if _agent != "Llauri" else "Ttoom"
	_main.call("_start_shift", other, GameState.Mode.NORMAL)
	await get_tree().create_timer(3.0).timeout
	_post("menú → turno nuevo con %s (corre, sin pantalla de muerte)" % other, GameState.running and GameState.agent == other and not ds.visible and not Checkpoints.dying)
	_variant = v
	fault = f
	_pd_variant = ""
	_pd_fault = ""
	if _p5 != null:
		_p5.set("fault", f)
	if hub5 != null and hub5.training != null and f == "quiz":
		hub5.training.forced_answers = [-2, -2, -2, -2, -2]


func _post(what: String, ok: bool) -> void:
	print("[bot] tras la muerte: %s → %s" % [what, "OK" if ok else "FALLO"])
	if not ok:
		_post_ok = false
		errors += 1


func _on_shift_ended() -> void:
	var wall := (Time.get_ticks_msec() - _wall_start_ms) / 1000.0
	var cmx := _contacts()
	var line := "T%d %s · %s · %.1f min reales · %d contactos · muertes %d · WW %d · Available %d%%" % [GameState.turno, GameState.clock_preset, _agent, _run_time / 60.0, Metrics.contacts_handled, deaths.size(), Metrics.written_warnings, int(Metrics.available_pct())]
	line += " · " + VoiceDirector.audit_line()  # v0.3.2: una voz a la vez (objetivo: 0 solapes)
	# v0.3.2 fb-ui (puntos 16 y 17): minitrainings del día hechos y nota del quiz del Trainer contra la mínima del día.
	var mtr := get_tree().get_first_node_in_group("mentor") as Mentor
	if mtr != null:
		line += " · minitrainings %d/%d %s" % [mtr.minitrainings_done.size(), mtr.minitrainings_open.size(), str(mtr.minitrainings_done)]
	var hub_q: PersonajesP5 = _p5.get("_hub") if _p5 != null else null
	if hub_q != null and hub_q.training != null and hub_q.training.enabled():
		line += " · quiz %d/5 (mínimo %d)" % [hub_q.training.last_score, TrainingControl.pass_mark()]
	results.append(line)
	print("[reloj] %s · %s" % [line, Metrics.clock_meas_text()])
	if _human != null:
		print("[humano] turno cerrado: %s · %s" % [line, str(_human.call("summary"))])
	print("[bot] turno cerrado: Available %d%%, contactos %d (relleno %d), incidencias %d, WW %d, perdidas %d, resultados %s, CSAT %.1f" % [int(Metrics.available_pct()), Metrics.contacts_handled, _fillers, Metrics.incidents, Metrics.written_warnings, cmx.missed_count if cmx != null else -1, str(Metrics.outcomes), Metrics.csat_avg()])
	print("[bot] cola: sustitutos %d · desborde %d · bolsa %d árboles · relleno pedido %d · huecos sin servir %d · libre con cola como mucho %.1f s reales (%d min de juego) · muertes a propósito %d" % [cmx.sub_count if cmx != null else -1, cmx.overflow_count if cmx != null else -1, cmx.pool_size() if cmx != null else -1, cmx.filler_served.size() if cmx != null else -1, cmx.slots_pending() if cmx != null else -1, _starve_max_real, int(_starve_max_game / 60.0), _forced])
	print("[bot] tiempo: %.1f min reales a 1x (estimado) · %.1f s de pared a %.0fx" % [_run_time / 60.0, wall, Engine.time_scale])
	_finish_run()


## Una captura dentro de `real_s` segundos reales (para que se vea lo que pasó: la pantalla de muerte, la PC al reaparecer).
func _foto_luego(real_s: float, tag: String) -> void:
	if _foto_cada <= 0.0:
		return
	await get_tree().create_timer(real_s, true, false, true).timeout
	var tries := 0
	while _foto_busy and tries < 120:  # hay una captura periódica a medias: esta no se pierde, espera
		await get_tree().process_frame
		tries += 1
	_foto(tag)


## Dibuja un cuadro de verdad, lo guarda (640×360, JPG) y vuelve a apagar el dibujado.
func _foto(tag: String) -> void:
	if _foto_busy or _foto_cada <= 0.0 or not is_inside_tree():
		return
	_foto_busy = true
	get_tree().root.disable_3d = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img != null and not img.is_empty():
		var full := tag != "t"
		if not full:
			img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		img.save_jpg("user://fotos/%04d_%s_%s.jpg" % [_foto_n, tag, GameState.clock_text().replace(":", "").replace(" ", "")], 0.88)
		_foto_n += 1
	get_tree().root.disable_3d = true
	_foto_busy = false


func _finish_run() -> void:
	if _state == "done":
		return
	runs_done += 1
	if runs_done >= runs_total:
		_state = "done"
		if _variant == "" and fault == "" and (_pd_variant != "" or _pd_fault != ""):
			_variant = _pd_variant  # el turno cerró durante la verificación tras la muerte
			fault = _pd_fault
			if _p5 != null:
				_p5.set("fault", fault)  # v0.3.2-core2: si no, «esperaba [nada]» y la variante salía FALLO sin fallos
		var ok := ((deaths.size() <= _forced or _audit_loop) and errors == 0) if not clumsy else (not deaths.is_empty())
		if _variant == "" and fault == "" and not clumsy and not deaths.is_empty():
			print("[bot] bucles: %d · como mucho %d muertes seguidas desde un mismo checkpoint%s" % [_loops, _streak_max, " · auditoría de bucles: las muertes sin bucle no cuentan" if _audit_loop else ""])
		if _variant != "":
			ok = not deaths.is_empty() and errors == 0
			for d in deaths:
				if not (TORPE_CAUSAS[_variant] as Array).has(d):
					ok = false
		if _over_break > 0.0:
			var raras: Array[String] = []
			for d in deaths:
				if not d in ["break_excedido", "tercer_ww", "ww_sin_ack"]:
					raras.append(d)
			ok = errors == 0 and raras.is_empty() and (_ww_seen >= 1 or deaths.has("break_excedido"))
			print("[bot] pasa-break %.1f min: WW %d · marcas de descanso %d · muertes %s → %s" % [_over_break, _ww_seen, Discipline.marks_of("break"), str(deaths), "le costó" if ok else "le salió gratis (o pasó algo raro)"])
		if fault != "":
			var want := str(_p5.call("expected_cause"))
			ok = deaths == [want] and errors == 0
			print("[bot] variante torpe %s: esperaba %s, murió de %s" % [fault, want, str(deaths)])
		if _variant != "" or fault != "":
			# Cada muerte de una variante, con el asesino de muertes.json (Rasec en las de coaching, Haime, el Trainer…).
			for i in deaths.size():
				var want_k := Checkpoints.killer_of(deaths[i])
				if killers[i] != want_k:
					ok = false
				print("[bot] variante %s: %s · asesino %s (muertes.json: %s)" % [_variant if _variant != "" else fault, deaths[i], killers[i], want_k])
		var tally: Dictionary = {}
		for d in deaths:
			tally[d] = int(tally.get(d, 0)) + 1
		for r in results:
			print("[bot] turno: " + r)
		if _ui_cases:
			var misses := 0
			for o in ui_outcomes:
				if str(o).contains("=bo_miss"):
					misses += 1
			print("[bot] casos de BO por la interfaz: %d hechos · %d sin interfaz · %d mal resueltos · %s" % [ui_done, ui_fallbacks, misses, str(ui_outcomes)])
			ok = ok and ui_fallbacks == 0 and misses == 0 and ui_done > 0
		print("[bot] FIN: Turno %d, %d rondas, %d muertes %s, %d errores → %s" % [GameState.turno, runs_total, deaths.size(), str(tally), errors, "OK" if ok else "FALLO"])
		await _silence()
		get_tree().quit(0 if ok else 1)
	else:
		_begin_run()


## Pausa el árbol, para todo el audio y espera 100 ms reales antes de salir. Si al cerrar quedan
## streams sonando (tras una muerte: sting, Ezlaki, voz), el AudioServer no llega a soltar sus
## playbacks antes del chequeo de ObjectDB y Godot avisa "N ObjectDB instances were leaked at exit".
## Dos pasadas: otros handlers de la misma señal (death_shown) suenan justo después de la primera.
func _silence() -> void:
	get_tree().paused = true
	for _i in 2:
		for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
			for p in get_tree().root.find_children("*", type, true, false):
				p.call("stop")
		await get_tree().create_timer(0.1, true, false, true).timeout



# --- v0.3.1 Q1 (F23): el bot humano ---------------------------------------------------------------

## Estados que el humano hace andando (llegada, volver al sitio, breaks, lunch): una corrutina a la vez.
func _human_tick() -> void:
	if _state == "h":
		return
	match _state:
		"boot":
			_state = "h"
			_human_arrival()
		"seat":
			_state = "h"
			_human_back_to_seat(true)
		"break", "lunch":
			pass


func _human_arrival() -> void:
	var h := _human
	await h.wait(2.0)
	var b := get_tree().get_first_node_in_group("building") as Building
	if b == null:
		return
	if b.current_floor == -1:
		h.log_t("llega en el bus: calle → lobby")
		var g := get_tree().get_first_node_in_group("p5_guardia")
		if g != null and bool(g.call("needs_check")):
			await h.go_marker(-1, "revision_jugador")
			g.call("start_check")  # Don Fermín (también la dispara la zona al pasar)
			var w := 0.0
			while not bool(GameState.flags.get("revision_ok", false)) and w < 60.0:
				await get_tree().process_frame
				w += get_process_delta_time()
			h.log_t("revisión de Don Fermín ok")
		var tn := b.floor_node.find_child("Molinete0", true, false) as Node3D
		if tn != null:
			await h.walk_to(tn.global_position + Vector3(1.0, -0.5, 1.4), "molinete")
			(tn as Interactable).interact(_player_node())
			await h.walk_to(tn.global_position + Vector3(1.0, -0.5, -1.6), "pasar el molinete")
		await h.ride(2)
	if b.current_floor == 2 and not GameState.logged_in:
		await h.use_object(2, "MiCasillero")
		await h.use_object(2, "Refri1")
		h.log_t("casillero y refri")
	await _human_back_to_seat(false)


func _player_node() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Camina hasta su puesto (C-14 o el que tenga la sesión), se sienta, se loguea (si hace falta) y vuelve al AUX.
func _human_back_to_seat(set_aux: bool) -> void:
	var h := _human
	var e := int(h.epoch)
	var b := get_tree().get_first_node_in_group("building") as Building
	if b == null:
		return
	if b.current_floor != 2:
		await h.ride(2)
		if e != int(h.epoch):
			return  # lo llamó un personaje a mitad de camino
		b = get_tree().get_first_node_in_group("building") as Building
	var seat := _session_seat(b)
	if seat == null:
		_state = "seat"
		return
	await h.go_sit(2, seat.seat_id)
	if e != int(h.epoch):
		return
	if not GameState.logged_in:
		while GameState.clock_seconds < LOGIN_AT_S and GameState.running:
			await get_tree().process_frame  # espera la hora sentado, como un agente
		await h.wait(h.t_ack())
		GameState.login()
		Checkpoints.save_checkpoint("login")
		h.log_t("login en %s" % seat.seat_id)
	elif set_aux and _resume_aux < 0:  # (si va a retomar el Break/Lunch del checkpoint, no pasa antes por Available)
		await h.wait(h.t_ack())
		Metrics.set_aux(Metrics.expected_aux if Metrics.is_productive(Metrics.expected_aux) else Metrics.Aux.AVAILABLE)
	_state = "work"
	_h_doing = ""
	_t = 0.0


## v0.3.2: el lunch del bot humano como el de Joan: un microondas LIBRE del -1 (antes iba siempre a «Microondas», que
## suele estar ocupado, y nunca calentaba), espera el «ding», lo saca y se sienta a comer en una mesa de la cafetería.
func _human_eat_taper(h: Node) -> void:
	await h.go_floor(-1)
	var b := get_tree().get_first_node_in_group("building") as Building
	if b == null or b.floor_node == null:
		return
	var free := ""
	for n in get_tree().get_nodes_in_group("microondas"):
		if n is WorldObjects.Microwave and b.floor_node.is_ancestor_of(n):
			(n as WorldObjects.Microwave).hint_text()
			if (n as WorldObjects.Microwave).state in ["libre", "mio_calentando", "mio_listo"] and free == "":
				free = str(n.name)
	if free == "" or WorldObjects.TaperFlow.state() not in [WorldObjects.TaperFlow.MANO, WorldObjects.TaperFlow.CALENTANDO, WorldObjects.TaperFlow.LISTO]:
		return
	if WorldObjects.TaperFlow.state() == WorldObjects.TaperFlow.MANO:
		await h.use_object(-1, free)
	var t0 := GameState.clock_seconds
	while WorldObjects.TaperFlow.state() == WorldObjects.TaperFlow.CALENTANDO and GameState.clock_seconds - t0 < 180.0 and _state == "h" and not Checkpoints.dying:
		await get_tree().process_frame
	if WorldObjects.TaperFlow.state() == WorldObjects.TaperFlow.LISTO:
		await h.use_object(-1, free)
	if WorldObjects.TaperFlow.state() != WorldObjects.TaperFlow.CALIENTE or _state != "h":
		return
	await h.use_object(-1, "Comer_%d" % h.rng.randi_range(0, 3))
	h.log_t("come el taper en la mesa (%s, Fatiga %.0f)" % [GameState.seated_at, Fatigue.value])
	await h.wait(h.rng.randf_range(4.0, 7.0))
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.seated and GameState.seated_at.begins_with("mesa_comer"):
		p.stand_up()


## Break n (1: expendedora del -1; 2: el agua del piso 2) o lunch (refri → microondas → mesa), caminando.
## `resumed`: retoma el Break/Lunch del checkpoint; el AUX ya se eligió dentro de «Reconectando» (_maybe_pause).
func _human_pause(kind: String, resumed: bool = false) -> void:
	var h := _human
	_state = "h"
	_h_doing = kind
	var until := _pause_until_clock
	await h.wait(h.t_ack())
	var cm := _contacts()
	if not resumed and cm != null and cm.phase != ContactManager.Phase.IDLE:
		# Justo sonó un contacto mientras se paraba: lo contesta y sale después (antes se iba y era una llamada perdida).
		h.log_t("iba al %s pero suena un contacto: lo contesta" % kind)
		_state = "work"
		_h_doing = ""
		return
	if kind == "break":
		if not resumed:
			_pick_aux(Metrics.Aux.BREAK)
		h.log_t("break %d" % Metrics.breaks_used)
		if _breaks_done == 0 or Economy.courtesy_coffee():
			await h.use_object(-1, "Expendedora")  # v0.3.2-core3: también si la máquina le debe un café
		else:
			await h.go_marker(2, "dispensador_sala", Vector3(0, 0, 1.0))
	else:
		if not resumed:
			_pick_aux(Metrics.Aux.LUNCH)
		h.log_t("lunch")
		var eaten := WorldObjects.TaperFlow.state() == WorldObjects.TaperFlow.COMIDO
		if not eaten:
			await h.use_object(2, "Refri1")
			if _state != "h" or _h_doing != kind:
				return  # lo interrumpió un personaje (Haime, el Trainer, Rasec)
			await _human_eat_taper(h)
			if _state != "h" or _h_doing != kind:
				return
		if Economy.courtesy_coffee():
			await h.use_object(-1, "Expendedora")  # el café de cortesía, en el rato del lunch
			if _state != "h" or _h_doing != kind:
				return
		await h.go_marker(-1, "cafeteria")
	while GameState.clock_seconds < until and GameState.running and not Checkpoints.dying and _state == "h":
		await get_tree().process_frame
	if Checkpoints.dying or not GameState.running or _state != "h":
		return  # murió o lo interrumpió un personaje (Haime, el Trainer, Rasec): eso lo devuelve a su sitio
	if kind == "break":
		_breaks_done += 1
	else:
		_lunch_done = true
	await _human_back_to_seat(true)
	h.log_t("de vuelta del %s" % kind)


## Una vez por turno, en un hueco sin contacto: AUX Baño, va al baño del piso 2 y vuelve (3 min de juego).
func _human_bano() -> void:
	var h := _human
	_state = "h"
	_h_doing = "bano"
	await h.wait(h.t_ack())
	var cm := _contacts()
	if cm != null and cm.phase != ContactManager.Phase.IDLE:
		h.log_t("iba al baño pero suena un contacto: lo contesta")
		_state = "work"
		_h_doing = ""
		return
	_h_bano_done = true
	_pick_aux(Metrics.Aux.BANO)
	h.log_t("al baño")
	var b := get_tree().get_first_node_in_group("building") as Building
	var z := b.floor_node.find_child("Zone_bano_p2", true, false) as Node3D if b != null else null
	if z != null:
		await h.walk_to(z.global_position * Vector3(1, 0, 1), "baño")
	else:
		await h.walk_to(Vector3(-10, 0, -1.5), "baño")
	var until := GameState.clock_seconds + 3.0 * 60.0
	while GameState.clock_seconds < until and GameState.running and not Checkpoints.dying and _state == "h":
		await get_tree().process_frame
	if Checkpoints.dying or not GameState.running or _state != "h":
		return
	await _human_back_to_seat(true)


## --quieto-respawn: tras reconectar no atiende a nadie durante S segundos reales; si vuelve a morir, es un bucle.
func _quiet_after_respawn(cause: String) -> void:
	var before := deaths.size()
	_state = "humano_quieto"
	if _p5 != null:
		_p5.process_mode = Node.PROCESS_MODE_DISABLED
	var t0 := _run_time
	while _run_time < t0 + _quiet_s and deaths.size() == before:
		await get_tree().process_frame
	var again := deaths.size() > before
	print("[bot] QUIETO %.0f s tras reconectar de %s (%s, sentado=%s, AUX %s): %s" % [_quiet_s, cause, GameState.clock_text(), str(GameState.seated_at), Metrics.aux_name(), ("MUERE de nuevo a los %.1f s: %s" % [_run_time - t0, str(deaths.slice(before))]) if again else "sin muerte"])
	if _p5 != null:
		_p5.process_mode = Node.PROCESS_MODE_INHERIT
	if again:
		errors += 1
		_post("bucle: re-muerte en la ventana de %.0f s" % _quiet_s, false)
	_state = "seat"

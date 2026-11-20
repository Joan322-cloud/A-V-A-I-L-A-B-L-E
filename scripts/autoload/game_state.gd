extends Node
## GameState: turno actual, agente, modo y reloj del turno con velocidades por estado (GDD 3.1, PLAN §3.1).
## El reloj se mide en segundos de juego desde las 00:00. La llegada empieza en 11:48 PM (-720 s).
## v0.3: turno 00:00 → 08:45 (525 min de juego) con la misma duración real que el de 6 h de la v0.2:
## los relojes de los casos no cambian y las horas extra se absorben en la espera sin cola, el lunch y
## los AUX de pie. Bloques 00:00-03:00 / 03:00-06:00 / 06:00-08:45.

enum Mode { NORMAL, REAL }
enum ClockMode { CONTACTO, SIN_COLA, DE_PIE, LUNCH, LLEGADA, PAUSADO, CASO_BO, ESPECIAL, BREAK, TIMBRE }
## v0.3.1 Q1 (D3/F21): relojes libres que salen del preset «Duración del turno» (balance.json/reloj_presets).
const FREE_CLOCKS: Array[String] = ["sin_cola", "llegada_salida", "break", "lunch"]

const AGENTS: Array[String] = ["Jiroshi", "Marko", "Llauri", "Ttoom", "Juan"]
const PLAYABLE_AGENTS: Array[String] = ["Jiroshi"]
const DEV_TOOLS_ENABLED: bool = true  # Cambiar a false antes de publicar en Steam

static func is_playable(p_agent: String) -> bool:
	return PLAYABLE_AGENTS.has(p_agent)
const SHIFT_END_SECONDS := 8 * 3600 + 45 * 60  # 08:45 (balance.json/turno/fin)
const BLOCK_SECONDS := 3 * 3600  # bloques de 3 h
const ARRIVAL_SECONDS := -12.0 * 60.0  # 11:48 PM
## Canales de contacto que son "caso BO" (reloj de caso 12x: 10 min de correo = 50 s reales).
const BO_CHANNELS: Array[String] = ["correo_bo", "kyc", "correo", "caso_bo", "vitzo_caso"]

var mode: int = Mode.NORMAL
var agent: String = "Jiroshi"
var turno: int = 1
var clock_seconds: float = ARRIVAL_SECONDS
var clock_shift: float = 0.0  # v0.3.2 · desplazamiento del TEXTO del reloj (Flashback.CLOCK_SHIFT durante el recuerdo)
var clock_mode: int = ClockMode.LLEGADA
var running: bool = false
var shift_over: bool = false
var in_calm: bool = false
var in_contact: bool = false
var queue_size: int = 0
var current_floor: int = -1
var seated_at: String = ""  # "C-14", "E-07", "" si de pie
var logged_in: bool = false
var in_room: bool = false  # dentro de la zona "sala" (sala de PCs del piso 2)
var distortions_seen: Array[String] = []
var flags: Dictionary = {}  # banderas sueltas del turno (coffee_used, lunch_taken, ...)

## Reloj especial (P2/P3/P5): "training" 24x (v0.3.1), "dormido" 30x, "feedback", "coaching_sesion" (balance.json/reloj).
var clock_override: String = ""
## v0.3.1 Q1 (D3): preset del reloj del turno ("corta" | "normal" | "larga"; "" = relojes base de la rc1, la
## Inducción). Se fija al empezar el turno con el de la partida del agente (SaveSlots.shift_length).
var clock_preset: String = "normal"
## Herramientas: fija el preset de todos los turnos ("-" = no fijar; "" = relojes base de la rc1). El runner de
## escenarios lo pone en "" para las pruebas de la v0.3 (p*_), escritas con los tiempos de la rc1.
var dev_preset_override: String = "-"

var _contact_bo: bool = false
## v0.3.1 Q1 (F23): suena un contacto que se puede perder (no BO): el reloj no es el «sin cola».
var _ringing: bool = false
var _contact_tree: bool = false
var _last_hour: int = -1
var _last_block: int = 0
var _calm_left: float = 0.0
var _lunch_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.aux_changed.connect(_on_aux_changed)
	EventBus.player_seated.connect(_on_player_seated)
	EventBus.player_stood_up.connect(_on_player_stood_up)
	EventBus.contact_offered.connect(_on_contact_offered)
	EventBus.contact_outcome.connect(func(_c: Dictionary, o: String, _csat: int) -> void:
		if o in ["perdido", "bo_miss"]:
			_ringing = false
			_refresh_clock_mode())
	EventBus.contact_accepted.connect(_on_contact_accepted)
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.player_floor_changed.connect(_on_floor_changed)
	EventBus.player_entered_zone.connect(_on_zone_entered)
	EventBus.player_exited_zone.connect(_on_zone_exited)


func _on_player_seated(seat: String) -> void:
	seated_at = seat
	_refresh_clock_mode()


func _on_player_stood_up() -> void:
	seated_at = ""
	_refresh_clock_mode()


## v0.3.1 Q1 (F23, lo encontró el bot humano): mientras suena un contacto el reloj iba al «sin cola» (240x en
## Normal, 400x en Corta): un «ignorar_s_juego» de 55-90 s de juego (T2/T3) se perdía en 0,2-0,4 s reales, antes de
## poder contestar (en la rc1, a 45x, eran 1,2-2 s: tampoco daba para un humano). Ahora suena al reloj del contacto
## (6x: 55 s de juego = 9 s reales, en línea con los 14 s reales del timbre). Los casos BO no se pierden: sin cambio.
func _on_contact_offered(c: Dictionary) -> void:
	_ringing = not BO_CHANNELS.has(str(c.get("canal", "")))
	_refresh_clock_mode()


func ringing() -> bool:
	return _ringing and queue_size > 0 and not in_contact


func _on_contact_accepted(c: Dictionary) -> void:
	in_contact = true
	_ringing = false
	_contact_bo = BO_CHANNELS.has(str(c.get("canal", "")))
	_contact_tree = c.has("nodos")
	_refresh_clock_mode()


func _on_contact_ended(_c: Dictionary, _resolved: bool, _angry: bool) -> void:
	in_contact = false
	_contact_bo = false
	_ringing = false
	_contact_tree = false
	_refresh_clock_mode()


func _on_floor_changed(f: int) -> void:
	current_floor = f
	if f != 2:
		_set_in_room(false)  # el piso se descarga entero: no siempre llega el body_exited de la zona


func _on_zone_entered(zone: String) -> void:
	if zone == "sala":
		_set_in_room(true)


func _on_zone_exited(zone: String) -> void:
	if zone == "sala":
		_set_in_room(false)


func _set_in_room(on: bool) -> void:
	if in_room == on:
		return
	in_room = on
	if on:
		EventBus.room_entered.emit()
	else:
		EventBus.room_exited.emit()


func _process(delta: float) -> void:
	if _calm_left > 0.0 and not get_tree().paused:  # v0.3.2-core4: la calma (Shero en reunión) no se gasta en pausa
		_calm_left -= delta
		if _calm_left <= 0.0:
			in_calm = false
			EventBus.calm_ended.emit()
	if not running or shift_over or get_tree().paused:
		return
	var prev_sec := clock_seconds
	clock_seconds += delta * clock_speed()
	if turno == 6 and logged_in and not bool(flags.get("sat_0559_broken", false)):
		if int(flags.get("carta_fragmentos", 0)) >= 3:
			flags["sat_0559_broken"] = true
		elif prev_sec < 21599.0 and clock_seconds >= 21599.0:
			clock_seconds = 21540.0
			flags["sat_0559_loops"] = int(flags.get("sat_0559_loops", 0)) + 1
			EventBus.show_message.emit("05:59 AM · El reloj no avanza. Busca los 3 fragmentos de tu carta de renuncia (Piso 2, Piso 1, Sótano -1)." if Loc.lang != "en" else "05:59 AM · The clock is frozen. Find the 3 resignation letter fragments (Floor 2, Floor 1, Basement -1).", 5.0)
			if int(flags["sat_0559_loops"]) >= 3:
				flags["sat_0559_broken"] = true
	EventBus.clock_tick.emit(clock_seconds)
	var h := current_hour()
	if h != _last_hour:
		_last_hour = h
		EventBus.hour_changed.emit(h)
	var b := current_block()
	if b != _last_block:
		_last_block = b
		EventBus.block_changed.emit(b)
	_update_lunch_window()
	if clock_seconds >= shift_end_seconds() and logged_in:
		shift_over = true
		running = false
		EventBus.shift_ended.emit()


## Fin del turno en segundos de juego (balance.json/turno/fin, "08:45").
func shift_end_seconds() -> float:
	var s := str(DataLoader.bal("turno/fin", "08:45"))
	var v := hhmm_to_seconds(s)
	return v if v > 0.0 else float(SHIFT_END_SECONDS)


## Velocidad actual del reloj según estado (balance.json/reloj; calibración dinámica v0.4.1).
func clock_speed() -> float:
	if clock_mode == ClockMode.ESPECIAL:
		if clock_override == "quiz":
			return 0.0
		if clock_override == "dormido":
			if Metrics.aux == Metrics.Aux.LUNCH and lunch_in_quota():
				return base_clock("dormido", 45.0)
			return reloj("de_pie_aux", 8.5)
		return base_clock(clock_override, 12.0)
	if not logged_in or clock_mode == ClockMode.LLEGADA:
		return reloj("llegada_salida", 6.5)
	if Discipline.summons_pending():
		return reloj("urgente_convocatoria", 5.5)
	match clock_mode:
		ClockMode.SIN_COLA:
			return reloj("sin_cola", 165.0)
		ClockMode.TIMBRE:
			return reloj("timbre", 12.0)
		ClockMode.CONTACTO:
			return reloj("contacto_guion" if _contact_tree else "contacto", 18.0)
		ClockMode.CASO_BO:
			return reloj("caso_bo", 10.0)
		ClockMode.BREAK:
			return reloj("break", 10.0) if break_in_quota() else 6.0
		ClockMode.LUNCH:
			return reloj("lunch", 16.0) if lunch_in_quota() else 6.0
		ClockMode.DE_PIE:
			return reloj("de_pie_aux", 8.5)
	return reloj("de_pie_aux", 8.5)


## Velocidad efectiva de un reloj según el preset activo (corta / normal / larga).
func reloj(key: String, default: float = 10.0) -> float:
	if clock_preset != "":
		var p: Variant = (DataLoader.dict("balance").get("reloj_presets", {}) as Dictionary).get(clock_preset, {})
		if p is Dictionary:
			var pt: Variant = (p as Dictionary).get("t%d" % turno, {})
			if pt is Dictionary and (pt as Dictionary).has(key):
				return float((pt as Dictionary)[key])
			if (p as Dictionary).has(key):
				return float((p as Dictionary)[key])
	return base_clock(key, default)


## Reloj base (balance.json/reloj), sin preset.
static func base_clock(key: String, default: float = 4.0) -> float:
	return float(DataLoader.bal("reloj/" + key, default))


## ¿El lunch en curso sigue dentro de su cupo (45 min de juego acumulados)?
func lunch_in_quota() -> bool:
	return float(Metrics.time_in_aux.get(Metrics.Aux.LUNCH, 0.0)) < lunch_minutes() * 60.0


## ¿El break en curso sigue dentro de su cupo (10 min de juego por break) y es uno de los permitidos?
func break_in_quota() -> bool:
	# v0.3.2-core4: el break de más que cubre el comodín también corre con el reloj del break mientras dure su cupo.
	return Metrics.quota_left(Metrics.Aux.BREAK) > 0.0 and (Metrics.breaks_used <= Metrics.breaks_allowed() or Discipline.comodin_break_covered())


## Preset del turno que empieza: el del agente; la Inducción usa los relojes base.
func _pick_preset() -> String:
	if dev_preset_override != "-":
		return dev_preset_override
	if SaveSlots.in_tutorial():
		return ""
	return SaveSlots.shift_length(agent)


## Reloj especial mientras dura algo guionizado (training 12x, dormido 30x, feedback, coaching_sesion).
func set_clock_override(key: String) -> void:
	clock_override = key
	_refresh_clock_mode()


## Quita el reloj especial (si key no es "" solo lo quita si es ese).
func clear_clock_override(key: String = "") -> void:
	if key != "" and clock_override != key:
		return
	clock_override = ""
	_refresh_clock_mode()


## Suma tiempo de juego de golpe (lo que dura un intercambio del árbol de diálogo, P4: opción.t_juego).
func add_game_time(seconds: float) -> void:
	if seconds <= 0.0 or not running or shift_over:
		return
	clock_seconds += minf(seconds, 12.0)
	EventBus.clock_tick.emit(clock_seconds)


func _refresh_clock_mode() -> void:
	if not logged_in:
		clock_mode = ClockMode.LLEGADA
		return
	if clock_override != "":
		clock_mode = ClockMode.ESPECIAL
		return
	var aux: int = Metrics.aux
	if aux == Metrics.Aux.LUNCH:
		clock_mode = ClockMode.LUNCH
	elif aux == Metrics.Aux.BREAK:
		clock_mode = ClockMode.BREAK  # v0.3.1: reloj propio del break (preset dentro del cupo; 4x fuera)
	elif seated_at == "":
		clock_mode = ClockMode.DE_PIE
	elif in_contact:
		clock_mode = ClockMode.CASO_BO if _contact_bo else ClockMode.CONTACTO
	elif ringing():
		clock_mode = ClockMode.TIMBRE
	elif Metrics.is_productive(aux):
		# v0.3 P3 (PLAN #83): fuera de la sala, sentado en otra isla o con una escalera de Shero de las que se
		# miden de pie abierta, el reloj no corre a 45x sino a de_pie_aux (4x).
		clock_mode = ClockMode.SIN_COLA if Discipline.allows_fast_clock() else ClockMode.DE_PIE
	else:
		clock_mode = ClockMode.DE_PIE
	# v0.3.1 Q1 (F20, salvaguarda 2, C3): con una convocatoria abierta ningún reloj libre corre: 4x aunque estés
	# sentado, en el break o en el lunch (Rasec en 2 min de juego = 30 s reales, no 0,5 s).
	if clock_mode in [ClockMode.SIN_COLA, ClockMode.LUNCH, ClockMode.BREAK] and Discipline.summons_pending():
		clock_mode = ClockMode.DE_PIE


func _on_aux_changed(_new_aux: int, _old_aux: int) -> void:
	_refresh_clock_mode()


## Hora del reloj del juego (0-23). Antes de medianoche devuelve 23.
func current_hour() -> int:
	var s := clock_seconds
	if s < 0.0:
		s += 24.0 * 3600.0
	return int(s / 3600.0) % 24


func current_minute() -> int:
	var s := clock_seconds
	if s < 0.0:
		s += 24.0 * 3600.0
	return int(s / 60.0) % 60


## Bloque del turno: 0 llegada, 1 (00:00-03:00), 2 (03:00-06:00), 3 (06:00-08:45).
func current_block() -> int:
	if clock_seconds < 0.0:
		return 0
	return clampi(int(clock_seconds / BLOCK_SECONDS) + 1, 1, 3)


## "3:47 AM" (formato 12 h como las capturas). v0.3.2: `clock_shift` desplaza SOLO el texto (el recuerdo del Training
## es de mañana: la PC, Fonex y Ezlak marcan la misma hora que el HUD); el reloj de juego no cambia.
func clock_text() -> String:
	return clock_text_at(clock_seconds + clock_shift)


func clock_text_at(seconds: float) -> String:
	var s := seconds
	if s < 0.0:
		s += 24.0 * 3600.0
	var h := int(s / 3600.0) % 24
	var m := int(s / 60.0) % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## "04:20" → 15600.0 (segundos desde las 00:00). -1 si no se entiende.
static func hhmm_to_seconds(hhmm: String) -> float:
	var parts := hhmm.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1.0
	return float(int(parts[0]) * 3600 + int(parts[1]) * 60)


func start_new_shift(p_turno: int, p_agent: String, p_mode: int) -> void:
	var _args := OS.get_cmdline_user_args()
	if not PLAYABLE_AGENTS.has(p_agent) and not _args.has("--escenario") and not _args.has("--bot"):
		p_agent = PLAYABLE_AGENTS[0]
	turno = p_turno
	agent = p_agent
	mode = p_mode
	SaveSlots.select(p_agent)
	clock_preset = _pick_preset()
	SaveSlots.record_turn_start(p_turno)  # v0.3 P6b: instantánea del inicio del turno (Elegir turno; no en la inducción)
	Checkpoints.clear_memory()  # nunca se arrastra el checkpoint de otro turno u otro agente (PLAN §1)
	reset_runtime()
	clock_seconds = ARRIVAL_SECONDS
	running = true
	EventBus.shift_started.emit()
	Checkpoints.save_checkpoint("inicio")


## Limpia el estado del turno (al iniciar uno nuevo y al volver al menú). No toca el progreso guardado.
func reset_runtime() -> void:
	clock_seconds = ARRIVAL_SECONDS
	clock_mode = ClockMode.LLEGADA
	clock_override = ""
	running = false
	shift_over = false
	logged_in = false
	in_contact = false
	_contact_bo = false
	_ringing = false
	_contact_tree = false
	in_calm = false
	_calm_left = 0.0
	seated_at = ""
	in_room = false
	queue_size = 0
	distortions_seen.clear()
	flags.clear()
	_last_hour = -1
	_last_block = 0
	_lunch_open = false


func login() -> void:
	logged_in = true
	if clock_seconds < 0.0:
		clock_seconds = 0.0  # el turno arranca a las 00:00 al loguearse
	_refresh_clock_mode()


func logout() -> void:
	logged_in = false
	clock_mode = ClockMode.LLEGADA


## Calma garantizada tras susto o muerte (GDD 3.2): Shero "está en reunión". × Difficulty "calma".
func start_calm(seconds: float) -> void:
	var s := seconds * Difficulty.scale("calma")
	if s <= 0.0:
		return
	in_calm = true
	_calm_left = s
	EventBus.calm_started.emit(s)


## Termina la calma ya (escenarios de prueba; P3 si una regla lo necesita).
func stop_calm() -> void:
	if in_calm:
		in_calm = false
		_calm_left = 0.0
		EventBus.calm_ended.emit()


func is_real_mode() -> bool:
	return mode == Mode.REAL


## v0.3 P6b: ¿estamos en la Inducción (tutorial, Turno 0)? Ahí no hay muertes reales salvo las de práctica.
func is_tutorial() -> bool:
	return SaveSlots.in_tutorial()


# --- Horario del turno (turnos.json, PLAN §3.2) ------------------------------------------------

## Hora programada del lunch del turno en segundos de juego (T1 04:00, T2 03:45, T3 04:20).
func lunch_clock() -> float:
	return base_lunch_clock() + float(flags.get("lunch_retraso_s", 0.0))  # v0.3.2: corrido si la muerte lo pisó


## Hora del lunch de turnos.json (sin el corrimiento tras reaparecer).
func base_lunch_clock() -> float:
	var v := hhmm_to_seconds(str(turno_cfg("lunch", "04:00")))
	return v if v >= 0.0 else 4.0 * 3600.0


## Duración del lunch en minutos de juego (45).
func lunch_minutes() -> float:
	return float(turno_cfg("lunch_min", DataLoader.bal("cupos_aux_min/lunch", 45)))


## Hora del training (AUX Training) del turno en segundos de juego; -1 si el turno no tiene.
func training_clock() -> float:
	var t: Variant = turno_cfg("training", null)
	return hhmm_to_seconds(str(t)) if t != null else -1.0


## ¿Estamos dentro de la ventana para empezar el lunch a su hora? (hora −5 min … hora +15 min)
func lunch_window_open() -> bool:
	var l := lunch_clock()
	var before := float(DataLoader.bal("lunch/ventana_antes_min", 5.0)) * 60.0
	var after := float(DataLoader.bal("lunch/ventana_despues_min", 15.0)) * 60.0
	return logged_in and clock_seconds >= l - before and clock_seconds < l + after


func _update_lunch_window() -> void:
	var open := lunch_window_open()
	if open != _lunch_open:
		_lunch_open = open
		EventBus.lunch_window.emit(open)


# --- Turnos (turnos.json) y progreso entre turnos (partida del agente, SaveSlots) -------------

## Progreso persistente de la partida activa (SaveSlots.current): turno máximo desbloqueado,
## turnos cerrados, saldo, modo, dificultad, finales. Se modifica en sitio y se guarda con save_progress().
var progress: Dictionary:
	get:
		return SaveSlots.progress()


## Entrada de turnos.json del turno dado (o del actual). {} si no existe.
func turno_data(p_turno: int = turno) -> Dictionary:
	for t in DataLoader.list("turnos"):
		if int(t.get("turno", 0)) == p_turno:
			return t
	return {}


## Parámetro del turno actual con valor por defecto: turno_cfg("rta_tolerancia_s", 90.0).
func turno_cfg(key: String, default: Variant) -> Variant:
	var d := turno_data()
	return d.get(key, default) if d.has(key) else default


## ¿Este antagonista entra en el turno actual? (lista 'enemigos' de turnos.json)
func enemy_enabled(id: String) -> bool:
	var list: Array = turno_cfg("enemigos", [])
	return list.has(id)


## ¿El turno está habilitado en esta versión? (turnos.json/habilitado)
func turno_available(p_turno: int) -> bool:
	return bool(turno_data(p_turno).get("habilitado", false))


## Compatibilidad v0.2: el progreso vive ahora en la partida del agente (se carga sola).
func load_progress() -> void:
	SaveSlots.progress()


func save_progress() -> void:
	SaveSlots.save()


## Turno más alto que el jugador puede iniciar (desbloqueado y habilitado en esta versión).
func max_unlocked_turno() -> int:
	var n := int(progress.get("turno_desbloqueado", 1))
	while n > 1 and not turno_available(n):
		n -= 1
	return maxi(n, 1)


## Siguiente turno que el jugador aún no ha cerrado (para "Continuar turno" sin partida a medias).
func next_turno() -> int:
	var closed: Array = progress.get("turnos_cerrados", [])
	var n := 1
	while closed.has(n) and n < 10:
		n += 1
	return mini(n, max_unlocked_turno())


## Al cerrar un turno sin despido: desbloquea el siguiente (si existe en turnos.json). Devuelve el turno desbloqueado o 0.
func close_turno(fired: bool) -> int:
	var p := progress
	var closed: Array = p.get("turnos_cerrados", [])
	if not closed.has(turno):
		closed.append(turno)
	p["turnos_cerrados"] = closed
	p["agent"] = agent
	p["mode"] = mode
	p["dificultad"] = Difficulty.IDS[Difficulty.level]
	p["ww_total"] = int(p.get("ww_total", 0)) + Metrics.written_warnings
	var unlocked := 0
	if not fired and turno_data(turno + 1).size() > 0 and int(p.get("turno_desbloqueado", 1)) < turno + 1:
		p["turno_desbloqueado"] = turno + 1
		unlocked = turno + 1
	save_progress()
	# v0.3 P6b (Elegir turno): resultado del turno en su instantánea y la instantánea del turno que se abre.
	SaveSlots.record_turn_result(turno, {
		"available": snappedf(Metrics.available_pct(), 0.1), "ww": Metrics.written_warnings, "incidencias": Metrics.incidents,
		"contactos": Metrics.contacts_handled, "csat": snappedf(Metrics.csat_avg(), 0.1) if not Metrics.csat_values.is_empty() else -1.0,
		"despedido": fired, "dificultad": Difficulty.IDS[Difficulty.level], "mode": mode, "saldo": float(p.get("saldo", -1.0)),
	})
	if not fired and turno_data(turno + 1).size() > 0:
		SaveSlots.record_turn_start(turno + 1, unlocked > 0)
	if unlocked > 0:
		EventBus.turno_unlocked.emit(unlocked)
	return unlocked


## Escala de tolerancias/plazos por dificultad (Fácil ×1,5 · Normal ×1 · Difícil y Turno real ×0,75).
func tolerance_scale() -> float:
	return Difficulty.scale("plazos")


func mark_distortion(id: String) -> void:
	if not distortions_seen.has(id):
		distortions_seen.append(id)


func to_save_dict() -> Dictionary:
	return {
		"mode": mode, "agent": agent, "turno": turno, "clock_seconds": clock_seconds,
		"logged_in": logged_in, "seated_at": seated_at, "current_floor": current_floor,
		# v0.3.2: copias; antes el checkpoint en memoria compartía las vivas (las banderas no volvían atrás al reaparecer y
		# from_save_dict vaciaba distortions_seen antes de leerla).
		"distortions_seen": distortions_seen.duplicate(), "flags": flags.duplicate(true),
	}


## Restaura el estado del turno desde un checkpoint. No toca `running`: lo decide quien restaura
## (Checkpoints.respawn lo pone al final de la transacción).
func from_save_dict(d: Dictionary) -> void:
	mode = int(d.get("mode", Mode.NORMAL))
	agent = str(d.get("agent", "Jiroshi"))
	turno = int(d.get("turno", 1))
	clock_seconds = float(d.get("clock_seconds", 0.0))
	logged_in = bool(d.get("logged_in", false))
	seated_at = str(d.get("seated_at", ""))
	current_floor = int(d.get("current_floor", 2))
	distortions_seen.clear()
	for s in d.get("distortions_seen", []):
		distortions_seen.append(str(s))
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	in_contact = false
	_contact_bo = false
	_ringing = false
	_contact_tree = false
	clock_override = ""
	shift_over = false
	_last_hour = current_hour()
	_last_block = current_block()
	_refresh_clock_mode()

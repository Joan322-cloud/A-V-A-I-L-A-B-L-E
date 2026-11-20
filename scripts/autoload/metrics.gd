extends Node
## Metrics: estados AUX, Available %, AHT, adherencia, written warnings + Ack (GDD 4.1, 4.3, 4.5).
## v0.3 (PLAN §3.3): AUX = Available, BO, Break, Lunch, Baño, Coaching, Training (Correo ya no es AUX:
## es un caso que entra en Available; KYC pasa a llamarse BO). Available % = Available / (Available + BO);
## los demás AUX lo congelan. Contador de breaks del turno, segundos de la sesión de AUX actual y registro
## de autorizaciones {aux, fuente, zona, vence} que consultan Discipline (P3) y el RTA (P5).

enum Aux { AVAILABLE, BO, BREAK, LUNCH, BANO, COACHING, TRAINING }

const AUX_KEYS: Array[String] = ["AUX_AVAILABLE", "AUX_BO", "AUX_BREAK", "AUX_LUNCH", "AUX_BANO", "AUX_COACHING", "AUX_TRAINING"]
const PRODUCTIVE: Array[int] = [Aux.AVAILABLE, Aux.BO]
## AUX que autorizan salir de la sala de PCs a todo el edificio por sí solos (PLAN §3.4).
const SELF_AUTHORIZED: Dictionary = {Aux.BREAK: "break", Aux.LUNCH: "lunch", Aux.BANO: "bano"}
## AUX que necesitan que alguien los autorice (Shero/TM/QA → Coaching; Trainer → Training).
const NEEDS_AUTH: Array[int] = [Aux.COACHING, Aux.TRAINING]
## Zonas de autorización: "edificio" (todo), "sala" (sala de PCs), "piso_1", "sala_calibracion", "topico", "training_sala2".
const ZONE_ALL := "edificio"
const SAVE_VERSION := 3
## v0.2 → v0.3: Available 0, Correo 1, KYC 2, Break 3, Lunch 4, Baño 5, Coaching 6 → Correo pasa a Available y KYC a BO.
const V02_AUX_MAP: Array[int] = [Aux.AVAILABLE, Aux.AVAILABLE, Aux.BO, Aux.BREAK, Aux.LUNCH, Aux.BANO, Aux.COACHING]

var aux: int = Aux.AVAILABLE
var aux_since: float = 0.0  # reloj de juego al entrar al AUX actual
## v0.3.2: «Reconectando» tras reaparecer (autoload Reconexion): se muestra como AUX, no cuenta para ningún AUX.
var reconnecting: bool = false
var time_in_aux: Dictionary = {}  # Aux -> segundos de juego acumulados
var shift_seconds: float = 0.0  # segundos de juego logueado
var contact_durations: Array[float] = []
var contacts_handled: int = 0
var angry_total: int = 0
var angry_streak: Array[float] = []  # horas de juego de los últimos molestos seguidos
var written_warnings: int = 0
var ack_pending: bool = false
var ack_left: float = 0.0
var ack_reason: String = ""
var incidents: int = 0
var expected_aux: int = Aux.AVAILABLE  # lo que dicta el Perrito RTA
var alerts: int = 0  # procedimiento de misses: 1ª vez alerta, luego WW
var allocation_aux: int = -1  # v0.2 (T3+): AUX que fija la allocation del Mentor mientras dura; -1 = ninguna
var breaks_used: int = 0  # breaks puestos en el turno (máximo turnos.json/breaks, 2)
var authorizations: Array = []  # [{aux, source, zone, until}] (until = reloj de juego; INF = mientras dure el AUX)
var outcomes: Dictionary = {"satisfecho": 0, "neutral": 0, "molesto": 0}
var csat_values: Array[int] = []

var _last_clock: float = 0.0
var _colors: Dictionary = {}
## v0.3.1 Q1 (F21/F23, `--medir-reloj`): segundos reales (delta escalado = reloj de pared a 1x) y minutos de juego
## por estado del reloj en el turno en curso: {estado: [real_s, juego_s]}. Lo imprime el bot al cerrar el turno.
var clock_meas: Dictionary = {}
var _meas_last_game: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in Aux.values():
		time_in_aux[a] = 0.0
	EventBus.clock_tick.connect(_on_clock_tick)
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.shift_started.connect(reset_shift)
	EventBus.returned_to_menu.connect(reset_shift)


func _process(delta: float) -> void:
	_measure_clock(delta)
	if ack_pending and not get_tree().paused and GameState.running:
		ack_left -= delta
		if ack_left <= 0.0:
			ack_pending = false
			EventBus.ack_expired.emit()
			# v0.3 P3: sin Ack ya no es muerte instantánea; Discipline inicia la persecución (ww_sin_ack).
			if not Discipline.owns_track("ww_ack"):
				EventBus.death_requested.emit("ww_sin_ack", "")


## Estado del reloj para la medición: llegada, contacto, caso_bo, sin_cola, de_pie, break, lunch o el reloj especial.
static func clock_state_name() -> String:
	if GameState.clock_mode == GameState.ClockMode.ESPECIAL:
		return GameState.clock_override
	return str(GameState.ClockMode.keys()[GameState.clock_mode]).to_lower()


func _measure_clock(delta: float) -> void:
	if not GameState.running or get_tree().paused:
		_meas_last_game = GameState.clock_seconds
		return
	var k := clock_state_name()
	var e: Array = clock_meas.get(k, [0.0, 0.0])
	e[0] = float(e[0]) + delta
	var dg := GameState.clock_seconds - _meas_last_game
	if dg > 0.0 and dg < 1800.0:
		e[1] = float(e[1]) + dg
	clock_meas[k] = e
	_meas_last_game = GameState.clock_seconds


## Tabla de la medición: "estado: real min / juego min" ordenada por tiempo real.
func clock_meas_text() -> String:
	var keys := clock_meas.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(clock_meas[a][0]) > float(clock_meas[b][0]))
	var parts: Array[String] = []
	var tr_s := 0.0
	for k in keys:
		tr_s += float(clock_meas[k][0])
		parts.append("%s %.2f/%.1f" % [k, float(clock_meas[k][0]) / 60.0, float(clock_meas[k][1]) / 60.0])
	return "total %.2f min reales · %s" % [tr_s / 60.0, " · ".join(parts)]


func reset_shift() -> void:
	clock_meas.clear()
	_meas_last_game = GameState.clock_seconds
	aux = Aux.AVAILABLE
	aux_since = 0.0
	reconnecting = false
	for a in Aux.values():
		time_in_aux[a] = 0.0
	shift_seconds = 0.0
	contact_durations.clear()
	contacts_handled = 0
	angry_total = 0
	angry_streak.clear()
	written_warnings = 0
	ack_pending = false
	ack_left = 0.0
	incidents = 0
	alerts = 0
	expected_aux = Aux.AVAILABLE
	allocation_aux = -1
	breaks_used = 0
	authorizations.clear()
	outcomes = {"satisfecho": 0, "neutral": 0, "molesto": 0}
	csat_values.clear()
	_last_clock = GameState.clock_seconds
	_colors.clear()


func _on_clock_tick(game_seconds: float) -> void:
	if not GameState.logged_in or game_seconds < 0.0:
		_last_clock = game_seconds
		return
	var dt := game_seconds - _last_clock
	_last_clock = game_seconds
	if dt <= 0.0:
		return
	shift_seconds += dt
	if not reconnecting:  # v0.3.2: Reconectando es neutro para el Available % y los cupos
		time_in_aux[aux] = float(time_in_aux[aux]) + dt
	_expire_authorizations(game_seconds)
	_check_colors()


func set_aux(new_aux: int) -> void:
	if reconnecting and new_aux >= 0 and new_aux < AUX_KEYS.size():
		var rc := get_node_or_null("/root/Reconexion")
		if rc != null:
			rc.call("finish", new_aux, true)  # elegir un AUX termina «Reconectando» (el mismo Break/Lunch lo retoma)
			return
		reconnecting = false
	if new_aux == aux or new_aux < 0 or new_aux >= AUX_KEYS.size():
		return
	var old := aux
	aux = new_aux
	aux_since = GameState.clock_seconds
	# Autorizaciones propias de Break/Lunch/Baño: todo el edificio mientras dure ese AUX.
	if SELF_AUTHORIZED.has(old):
		revoke(str(SELF_AUTHORIZED[old]))
	if SELF_AUTHORIZED.has(new_aux):
		authorize(new_aux, str(SELF_AUTHORIZED[new_aux]), ZONE_ALL, -1.0)
	if old == Aux.BREAK:
		EventBus.break_ended.emit(breaks_used)
	if new_aux == Aux.BREAK:
		breaks_used += 1
		EventBus.break_started.emit(breaks_used)
	EventBus.aux_changed.emit(new_aux, old)
	AudioManager.play_sfx("fonex_cambio_aux")


func is_productive(a: int) -> bool:
	return PRODUCTIVE.has(a)


func aux_name(a: int = -1) -> String:
	if a == -1:
		if reconnecting:
			return tr("B2_AUX_RECONNECTING")  # v0.3.2: el AUX que se ve (HUD, Fonex) al reaparecer
		a = aux
	if a < 0 or a >= AUX_KEYS.size():
		return "?"
	return tr(AUX_KEYS[a])


## Segundos de juego en el AUX actual (desde que se puso: una sesión, no el acumulado).
func seconds_in_current_aux() -> float:
	return maxf(GameState.clock_seconds - aux_since, 0.0)


## Alias del contrato v0.3 (PLAN §11).
func aux_session_seconds() -> float:
	return seconds_in_current_aux()


## Breaks permitidos por turno (turnos.json/breaks; 2).
func breaks_allowed() -> int:
	return int(GameState.turno_cfg("breaks", DataLoader.bal("breaks/por_turno", 2)))


## Available % = t(Available) / (t(Available) + t(BO)). Break, Lunch, Baño, Coaching y Training no
## cuentan (congelado). Arranca en 100 %.
func available_pct() -> float:
	var av := float(time_in_aux[Aux.AVAILABLE])
	var denom := av + float(time_in_aux[Aux.BO])
	if denom <= 1.0:
		return 100.0
	return clampf(av / denom * 100.0, 0.0, 100.0)


## El Available % vuelve a contarse desde cero (Checkpoints, al reaparecer de una muerte por Available bajo).
func restart_available() -> void:
	time_in_aux[Aux.AVAILABLE] = 0.0
	time_in_aux[Aux.BO] = 0.0


## Segundos productivos (Available + BO) del turno.
func productive_seconds() -> float:
	return float(time_in_aux[Aux.AVAILABLE]) + float(time_in_aux[Aux.BO])


## ¿Ya se evalúa el Available? (no antes de balance.json/available/evaluar_desde_min productivos; 30).
func available_evaluable() -> bool:
	return productive_seconds() >= float(DataLoader.bal("available/evaluar_desde_min", 30.0)) * 60.0


func aht_seconds() -> float:
	if contact_durations.is_empty():
		return 0.0
	var total := 0.0
	for d in contact_durations:
		total += d
	return total / contact_durations.size()


## Cupo restante de un AUX (segundos de juego) según balance.json/cupos_aux_min.
## v0.3: el Break se mide por break (cada uno dura 10 min); Lunch y Baño siguen acumulados en el turno.
func quota_left(a: int) -> float:
	var key := ""
	match a:
		Aux.BREAK: key = "break"
		Aux.LUNCH: key = "lunch"
		Aux.BANO: key = "bano"
		_: return INF
	var quota := float(DataLoader.bal("cupos_aux_min/" + key, 10.0)) * 60.0
	if a == Aux.BREAK:
		return quota - (seconds_in_current_aux() if aux == Aux.BREAK else 0.0)
	return quota - float(time_in_aux[a])


# --- Autorizaciones (PLAN §3.3/§3.4) ----------------------------------------------------------

## Autoriza un AUX y una zona. source: shero|tm|qa|trainer|lunch|break|bano|topico. minutes < 0 = sin
## vencimiento (hasta revoke). Una fuente tiene una sola autorización viva (la nueva reemplaza a la vieja).
func authorize(p_aux: int, source: String, zone: String, minutes: float) -> void:
	revoke(source, false)
	var until := INF if minutes < 0.0 else GameState.clock_seconds + minutes * 60.0
	authorizations.append({"aux": p_aux, "source": source, "zone": zone, "until": until})
	EventBus.authorization_granted.emit(p_aux, source, zone, until)


## Retira la autorización de una fuente (emite authorization_ended si existía).
func revoke(source: String, emit: bool = true) -> void:
	var kept: Array = []
	var found := false
	for a in authorizations:
		if str(a.get("source", "")) == source:
			found = true
		else:
			kept.append(a)
	authorizations = kept
	if found and emit:
		EventBus.authorization_ended.emit(source)


## ¿Alguna autorización viva cubre esta zona? ("edificio" cubre todas; "sala" siempre está permitida).
func is_authorized(zone: String) -> bool:
	if zone == "sala":
		return true
	for a in authorizations:
		var z := str(a.get("zone", ""))
		if (z == ZONE_ALL or z == zone) and float(a.get("until", 0.0)) > GameState.clock_seconds:
			return true
	return false


## ¿El AUX actual (o el dado) está autorizado? Available/BO/Break/Lunch/Baño siempre; Coaching/Training
## solo si Shero, un TM, QA o el Trainer lo pidieron (authorize con ese aux).
func is_aux_authorized(a: int = -1) -> bool:
	var x := aux if a < 0 else a
	if not NEEDS_AUTH.has(x):
		return true
	for au in authorizations:
		if int(au.get("aux", -1)) == x and float(au.get("until", 0.0)) > GameState.clock_seconds:
			return true
	return false


## Autorización viva de una fuente ({} si no hay).
func authorization_of(source: String) -> Dictionary:
	for a in authorizations:
		if str(a.get("source", "")) == source:
			return a
	return {}


func _expire_authorizations(now: float) -> void:
	for a in authorizations.duplicate():
		if float(a.get("until", INF)) <= now:
			revoke(str(a.get("source", "")))


# --- Contactos --------------------------------------------------------------------------------

func _on_contact_ended(contact: Dictionary, resolved: bool, angry: bool) -> void:
	contacts_handled += 1
	contact_durations.append(float(contact.get("_duration", 0.0)))
	if angry:
		angry_total += 1
		# v0.3.2-core3: un contacto «de más» al repetir un tramo (uno que la primera vez no existía) no cansa: el
		# tramo repetido no puede costar más Fatiga que la primera vez (ContactManager marca `de_mas`).
		if not bool(contact.get("de_mas", false)):
			Fatigue.add(float(DataLoader.bal("fatiga/por_molesto", 8.0)))
		var now := GameState.clock_seconds
		var window := float(DataLoader.bal("molestos/ventana_min", 20.0)) * 60.0
		var kept: Array[float] = []
		for t in angry_streak:
			if now - t < window:
				kept.append(t)
		angry_streak = kept
		angry_streak.append(now)
		EventBus.angry_streak.emit(angry_streak.size())
	elif resolved and not bool(contact.get("_neutral", false)):
		angry_streak.clear()  # un final neutral (árboles v0.3) no rompe ni suma a la racha
	_check_colors()


## Resultado de un contacto con árbol (P4): satisfecho | neutral | molesto y su CSAT (1-5).
func register_outcome(outcome: String, csat: int) -> void:
	outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
	if csat > 0:
		csat_values.append(clampi(csat, 1, 5))


## v0.3.2-core2: lo que ya atendiste no se des-atiende al reaparecer. El checkpoint devuelve las métricas a como
## estaban cuando se guardó, pero los contactos que terminaste después siguen atendidos (no se repiten: en su lugar
## entra otro cliente), así que su cuenta, su AHT, su resultado y su CSAT se conservan. ContactManager guarda esta
## foto en el checkpoint vivo cada vez que cierras un contacto y la repone al rebobinar (reaparecer, «Reiniciar
## contacto» o «Continuar»). Nada se cuenta dos veces: un contacto a medias nunca llegó a contarse.
func contacts_snapshot() -> Dictionary:
	return {
		"contacts_handled": contacts_handled, "angry_total": angry_total,
		"contact_durations": contact_durations.duplicate(), "outcomes": outcomes.duplicate(true),
		"csat_values": csat_values.duplicate(),
	}


## Repone la foto de contacts_snapshot() si trae más contactos atendidos que ahora. Devuelve si cambió algo.
func keep_contacts(s: Dictionary) -> bool:
	if int(s.get("contacts_handled", 0)) <= contacts_handled:
		return false
	contacts_handled = int(s.get("contacts_handled", 0))
	angry_total = maxi(angry_total, int(s.get("angry_total", 0)))
	contact_durations.clear()
	for v in s.get("contact_durations", []):
		contact_durations.append(float(v))
	var o: Dictionary = s.get("outcomes", {})
	for k in o.keys():
		outcomes[str(k)] = int(o[k])
	csat_values.clear()
	for v in s.get("csat_values", []):
		csat_values.append(int(v))
	_check_colors()
	return true


func csat_avg() -> float:
	if csat_values.is_empty():
		return 0.0
	var t := 0
	for v in csat_values:
		t += v
	return float(t) / csat_values.size()


func _color_for(metric: String) -> String:
	match metric:
		"available":
			if not available_evaluable():
				return "verde"
			var p := available_pct()
			if p >= float(DataLoader.bal("available/verde", 80.0)):
				return "verde"
			if p >= float(DataLoader.bal("available/rojo", 70.0)):
				return "amarillo"
			return "rojo"
		"aht":
			var a := aht_seconds() / 60.0
			if a < float(DataLoader.bal("aht/verde_min", 6.0)):
				return "verde"
			if a <= float(DataLoader.bal("aht/rojo_min", 9.0)):
				return "amarillo"
			return "rojo"
		"ww":
			if written_warnings == 0:
				return "verde"
			return "amarillo" if written_warnings < 2 else "rojo"
	return "verde"


func _check_colors() -> void:
	for m in ["available", "aht", "ww"]:
		var c := _color_for(m)
		if _colors.get(m, "") != c:
			_colors[m] = c
			EventBus.metric_color_changed.emit(m, c)


func color_of(metric: String) -> String:
	return _colors.get(metric, "verde")


## Procedimiento de misses (GDD 4.2): 1ª vez alerta, siguientes WW.
func report_miss(reason: String) -> void:
	if alerts == 0:
		alerts += 1
		EventBus.shero_message.emit("alerta", "dm")
		return
	issue_written_warning(reason)


## Emite un WW y abre la ventana de Ack (8 s reales × dificultad; +50 % accesibilidad).
func issue_written_warning(reason: String) -> void:
	written_warnings += 1
	ack_reason = reason
	EventBus.written_warning_issued.emit(written_warnings, reason)
	# v0.3.1 (audio_horror_v2): el 2.º WW del turno (el que avisa del despido) suena corrupto en T3.
	AudioManager.play_sfx("ww_popup_corrupto" if GameState.turno >= 3 and written_warnings >= 2 and AudioManager.has_slot("sfx/ww_popup_corrupto") else "ww_popup")
	if written_warnings >= int(DataLoader.bal("ww/despido", 3)):
		EventBus.death_requested.emit("tercer_ww", "")
		return
	# Plazo de Ack del turno (turnos.json/ack_s; T1 = 8 s como balance.json) × Difficulty "ack".
	var secs := float(GameState.turno_cfg("ack_s", DataLoader.bal("ww/ack_segundos", 8.0))) * Difficulty.scale("ack")
	if bool(Loc.get_setting("ack_extra", false)):
		secs *= 1.5
	secs = Discipline.ack_window_seconds(secs)  # v0.3 P3: lejos de tu PC/terminal, 60 s para llegar a uno
	ack_pending = true
	ack_left = secs
	EventBus.ack_window_opened.emit(secs)


func give_ack() -> bool:
	if not ack_pending:
		return false
	ack_pending = false
	AudioManager.play_sfx("ack_click")
	EventBus.ack_given.emit()
	return true


func register_incident() -> void:
	incidents += 1


func to_save_dict() -> Dictionary:
	var auths: Array = []
	for a in authorizations:
		var c: Dictionary = (a as Dictionary).duplicate()
		if is_inf(float(c.get("until", 0.0))):
			c["until"] = -1.0  # JSON no guarda INF
		auths.append(c)
	return {
		"version": SAVE_VERSION,
		# v0.3.2: copias (antes eran las mismas Dictionary/Array vivas: el checkpoint en memoria cambiaba con el juego y
		# from_save_dict las vaciaba antes de leerlas → tras reaparecer el cupo del lunch, el Available % y el AHT
		# volvían a cero).
		"aux": aux, "aux_since": aux_since, "time_in_aux": time_in_aux.duplicate(true), "shift_seconds": shift_seconds,
		"contacts_handled": contacts_handled, "angry_total": angry_total,
		"written_warnings": written_warnings, "incidents": incidents, "alerts": alerts,
		"contact_durations": contact_durations.duplicate(), "breaks_used": breaks_used, "authorizations": auths,
		"outcomes": outcomes.duplicate(true), "csat_values": csat_values.duplicate(),
		# v0.3.1 Q1 (F23): las órdenes de AUX vigentes en el checkpoint. Antes quedaban las del momento de la muerte:
		# una allocation del Mentor posterior al checkpoint seguía pidiendo BO 2 h de juego (Available 0 % → Shero).
		"expected_aux": expected_aux, "allocation_aux": allocation_aux,
	}


func from_save_dict(raw: Dictionary) -> void:
	var d := migrate_save_dict(raw)
	aux = clampi(int(d.get("aux", Aux.AVAILABLE)), 0, AUX_KEYS.size() - 1)
	aux_since = float(d.get("aux_since", GameState.clock_seconds))
	for a in Aux.values():
		time_in_aux[a] = 0.0
	var t: Dictionary = d.get("time_in_aux", {})
	for k in t.keys():
		var i := int(k)
		if i >= 0 and i < AUX_KEYS.size():
			time_in_aux[i] = float(time_in_aux[i]) + float(t[k])
	shift_seconds = float(d.get("shift_seconds", 0.0))
	contacts_handled = int(d.get("contacts_handled", 0))
	angry_total = int(d.get("angry_total", 0))
	written_warnings = int(d.get("written_warnings", 0))
	incidents = int(d.get("incidents", 0))
	alerts = int(d.get("alerts", 0))
	breaks_used = int(d.get("breaks_used", 0))
	contact_durations.clear()
	for v in d.get("contact_durations", []):
		contact_durations.append(float(v))
	authorizations.clear()
	for a in d.get("authorizations", []):
		var c: Dictionary = (a as Dictionary).duplicate()
		if float(c.get("until", 0.0)) < 0.0:
			c["until"] = INF
		authorizations.append(c)
	expected_aux = clampi(int(d.get("expected_aux", Aux.AVAILABLE)), 0, AUX_KEYS.size() - 1)
	allocation_aux = int(d.get("allocation_aux", -1))
	outcomes = (d.get("outcomes", {"satisfecho": 0, "neutral": 0, "molesto": 0}) as Dictionary).duplicate(true)
	csat_values.clear()
	for v in d.get("csat_values", []):
		csat_values.append(int(v))
	ack_pending = false
	ack_left = 0.0
	angry_streak.clear()
	_last_clock = GameState.clock_seconds
	_colors.clear()


## Migra un dict de métricas de la v0.2 (sin "version") al enum de AUX de la v0.3.
static func migrate_save_dict(d: Dictionary) -> Dictionary:
	if int(d.get("version", 2)) >= SAVE_VERSION:
		return d
	var out := d.duplicate(true)
	var old_aux := int(d.get("aux", 0))
	out["aux"] = V02_AUX_MAP[old_aux] if old_aux >= 0 and old_aux < V02_AUX_MAP.size() else Aux.AVAILABLE
	var t: Dictionary = d.get("time_in_aux", {})
	var nt: Dictionary = {}
	for k in t.keys():
		var i := int(k)
		var ni := V02_AUX_MAP[i] if i >= 0 and i < V02_AUX_MAP.size() else Aux.AVAILABLE
		nt[str(ni)] = float(nt.get(str(ni), 0.0)) + float(t[k])
	out["time_in_aux"] = nt
	out["version"] = SAVE_VERSION
	return out

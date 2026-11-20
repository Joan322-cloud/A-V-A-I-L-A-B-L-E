extends Node
## Discipline (v0.3 P3, PLAN §4, SHERO_ESCALADA §2): la escalera de Shero para TODO. Una máquina de estados
## por pista con los umbrales de data/escalada.json × Difficulty.scale("plazos"):
##   1 llamado (Ezlaki: DM, #team-familia, #allocations) → 2 verbal (la voz del ejecutor: en persona si está en
##   tu piso, si no por los parlantes del piso donde estés) → 3 written warning (Ack: 8 s en tu PC o un terminal,
##   60 s si estás lejos; sin Ack = persecución) → 4 persecución "amonestación asesina" (Pursuit: te busca en
##   cualquier piso, escaleras y ascensor; en los baños espera en la puerta; volver a tu sitio no la detiene)
##   → 5 muerte (screamer de la causa). Dos verbales = un WW; tres WW = despido (tercer_ww, lo pide Metrics).
## Pistas por minutos: break · lunch · correo · sala · otra_isla · coaching (sin permiso, ejecuta Rasec) ·
## coaching_exceso (Rasec) · coaching_noshow (Shero) / coaching_noshow_rasec · training_regreso ·
## topico_excedido. Por evento: break_1/break_2/tercer_break · available (lista del Mentor) ·
## llamadas_perdidas · topico (2.º pedido) · ww_ack · tres_molestos.
## Reincidencia: la 2.ª/3.ª vez que una pista se rompe en el turno, la escalera EMPIEZA en el escalón de
## escalada.json/reincidencia y los siguientes usan los plazos siguientes.
## Congelamiento (freeze): feedback de QA, training autorizado y coaching autorizado — nada avanza (ni las
## persecuciones); al terminar, Vitzo publica lo aplazado. Calma tras morir: tampoco avanza nada.
## Reloj (PLAN #83): fuera de la sala, sentado en otra isla o con una pista de minutos abierta, el reloj no
## corre a 45x (allows_fast_clock → GameState._refresh_clock_mode usa de_pie_aux, 4x).
##
## Contrato (P1 lo dejó fijo; P3 lo rellena — ver PLAN §11.4):
##   señales (EventBus): discipline_step(track, step, info) · freeze_discipline(on, reason) ·
##     pursuit_started / pursuit_ended / hunter_entered_floor (Pursuit)
##   Discipline.freeze(on, reason) / is_frozen()
##   Discipline.counters  — {llamados, verbales, ww, por_pista: {track: escalón activo}, veces: {track: n}, …}
##   Discipline.step_of(track) -> int (0 nada, 1 llamado … 4 persecución) · thresholds(track) · active_tracks()
##   Discipline.owns_track(track) -> bool  (P4 deja de hacer su respaldo: llamadas_perdidas, correo, coaching_noshow)
##   Discipline.ack_window_seconds(base) · allows_fast_clock() · anger() · max_step() · shero_bald()
##   Discipline.topico_permitted() · request_coaching(by, seconds) · to/from_save_dict() · reset()
##   v0.3.2: Discipline.is_lunch_immune(quien = "") — el lunch es inmune (Joan): lo consultan TODOS los que convocan
##     o persiguen (PersonajesP5.can_interrupt: Haime/Rasec/Trainer; Mentor, Vitzo, Rooms, la escalera de Shero).
## Escalones: 1 llamado · 2 verbal · 3 written warning · 4 persecución · 5 muerte.
##
## v0.3.2-core4 (prueba beta de Joan en Normal):
## - Plazos: los minutos de cada escalón salen de balance.json/escalera (una columna por dificultad; en las pistas con
##   límite de regla —break 10, lunch 45, correo 10— son minutos DESPUÉS del límite, que no se toca). Si una pista no
##   está ahí, valen los de escalada.json × Difficulty.scale("plazos") como antes.
## - Marcas («no hay repeticiones gratis»): cada exceso (primer escalón dado) deja una marca para el resto del turno
##   (counters.veces, viaja con el checkpoint), compartida por tipo de falta (escalera/marcas/grupos: descanso = break +
##   lunch; sitio = sala, otra isla, regreso del training, tópico excedido; coaching; inasistencia; correo). Con marcas
##   la escalera empieza un escalón más arriba (1 marca: verbal; 2 o más: WW) y la persecución nunca sale antes de
##   escalera/marcas/piso_min minutos de juego tras el primer aviso (30 s reales a 4x: lo que se tarda caminando desde
##   el sitio legítimo más lejano hasta sentarse en C-14). marks_of(track) · aux_margin() (HUD, Fonex).
## - La calma tras reaparecer («Shero en reunión») ya no congela las pistas del break y del lunch: son TUS relojes.
##   Antes, recién reaparecido, dormir en un puff (reloj 30x) era una hora de juego de break sin un solo aviso.
## - En el break, el primer aviso por los parlantes despierta al que duerme (a 30x los minutos de margen eran segundos);
##   en el lunch no: ahí sigue la regla de Joan (dormido en el -1: perdón una vez con WW; la 2.ª siesta, caza directa).
## - Comodín y tercer break: comodin_marks_break(quien) · comodin_break_covered() · comodin_break_left(). El comodín
##   cubre un break de más solo durante su cupo (10 min); Shero amaga la persecución, lo dice y vuelve a su sitio con su
##   cara normal; pasado el cupo corre la escalera del break excedido y la muerte es break_excedido («NO HAY BREAKS»).

enum Step { NADA, LLAMADO, VERBAL, WW, PERSECUCION, MUERTE }

const TRACKS: Array[String] = ["break", "lunch", "correo", "sala", "coaching", "coaching_noshow", "coaching_noshow_rasec", "coaching_exceso", "available", "topico", "topico_excedido", "training_regreso", "ww_ack", "llamadas_perdidas", "otra_isla", "tres_molestos", "tercer_break", "break_1", "break_2"]
## Pistas que P3 ejecuta y que otros paquetes dejan de hacer por su cuenta (P4: ContactManager / EzlakHub).
const OWNED: Array[String] = ["llamadas_perdidas", "correo", "coaching_noshow", "coaching_noshow_rasec", "coaching", "coaching_exceso", "ww_ack", "available", "sala", "otra_isla", "break", "lunch", "training_regreso", "topico", "topico_excedido", "tres_molestos", "tercer_break"]
## Pistas que corren por minutos de juego (las demás avanzan por evento).
const MINUTE_TRACKS: Array[String] = ["break", "lunch", "correo", "sala", "otra_isla", "coaching", "coaching_exceso", "coaching_noshow", "coaching_noshow_rasec", "training_regreso", "topico_excedido"]
## Con una de estas pistas abierta el reloj no corre a 45x (se mide de pie: 4x).
const SLOW_CLOCK_TRACKS: Array[String] = ["sala", "otra_isla", "coaching", "coaching_exceso", "coaching_noshow", "coaching_noshow_rasec", "training_regreso", "topico_excedido"]
const STEP_KEYS: Array[String] = ["", "llamado", "verbal", "ww", "persecucion", "muerte"]
const TH_KEYS: Array[String] = ["llamado_min", "verbal_min", "ww_min", "persecucion_min"]

var counters: Dictionary = {}
var _freeze_reasons: Array[String] = []
var _run: Dictionary = {}  # pista → {t, steps, times, i, info}
var _last_clock: float = 0.0
var _rooms_left: float = -1.0
var _rooms_from: String = "shero"
var _session_token: int = 0
var _say_serial: int = 0  # mensajes con retraso (P7): se descartan si cambió (muerte, reinicio, menú)
var _session_active: bool = false
var _coach_auth_seen: bool = false
var _excuse_open: bool = false
var _third_confirm_until_ms: int = -1
var _bald_until_clock: float = -INF
var _rng := RandomNumberGenerator.new()
var _pursuit_node: Node = null
var _p5_hub: Node = null  # PersonajesP5 (P5), si existe: training_released
var _p5_topico: int = -1  # -1 sin mirar · 0 no · 1 sí: existe TopicoControl (P5 lleva el tópico)
var presence: Node = null
## v0.3.1 Q1 (C3): claves que retienen el reloj lento (convocatorias abiertas). Con alguna, allows_fast_clock() = false.
var _slow_holds: Dictionary = {}
## v0.3.1 Q1 (F23): tiempo del caso BO abierto que pasó con Discipline congelada (training, feedback, sesiones). No
## cuenta para la escalera del correo: antes, al volver del training con un caso abierto, los 4 escalones (llamado,
## verbal, WW, persecución) salían en el mismo minuto y Shero te mataba en el acto.
var _correo_case: String = ""
var _correo_last: float = 0.0
var _correo_paused: float = 0.0
## v0.3.2 (Joan: «durante lunch eres inmune»): gracia real tras soltar el lunch y lo que se aplazó en él (en orden),
## que sale escalonado (uno cada lunch_inmune/escalonado_s) para que no te convoquen todos a la vez al volver.
var _lunch_grace_left: float = 0.0
var _lunch_deferred: Array[String] = []
var _lunch_since_release: float = -1.0
var _lunch_list_meta: Dictionary = {}  # lista del Mentor bajo el target publicada durante el lunch (Shero la lee después)
## v0.3.2-core4: pistas que la calma tras reaparecer NO congela (los relojes de tu break y de tu lunch).
const CALM_PROOF_TRACKS: Array[String] = ["break", "lunch"]
var _comodin_marker: String = ""  # Comodin lo pone justo antes de marcar Break; _on_break_started lo consume
var _comodin_feint_t: float = -1.0  # segundos reales del amago de Shero ante un tercer break del comodín (-1 = no hay)
var _comodin_bald_before: float = -INF
var _comodin_who: String = ""  # quién te marcó el break que el comodín cubre (para la línea de Shero)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.shift_started.connect(reset)
	EventBus.returned_to_menu.connect(reset)
	EventBus.freeze_discipline.connect(_on_freeze)
	EventBus.clock_tick.connect(_on_clock)
	EventBus.aux_changed.connect(func(_n: int, _o: int) -> void: _on_state_changed())
	EventBus.aux_changed.connect(_on_aux_lunch)
	EventBus.respawned.connect(func(_k: String) -> void: _lunch_reset_runtime())
	EventBus.room_entered.connect(_on_state_changed)
	EventBus.room_exited.connect(_on_state_changed)
	EventBus.player_seated.connect(func(_s: String) -> void: _on_state_changed())
	EventBus.player_stood_up.connect(_on_state_changed)
	EventBus.player_floor_changed.connect(func(_f: int) -> void: _on_state_changed())
	EventBus.authorization_granted.connect(func(_a: int, _s: String, _z: String, _u: float) -> void: _on_state_changed())
	EventBus.authorization_ended.connect(_on_authorization_ended)
	EventBus.break_started.connect(_on_break_started)
	EventBus.email_timer_tick.connect(_on_email_tick)
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.contact_outcome.connect(_on_contact_outcome)
	EventBus.ezlak_post.connect(_on_ezlak_post)
	EventBus.ezlak_quick_reply.connect(_on_quick_reply)
	EventBus.coaching_requested.connect(_on_coaching_requested)
	EventBus.coaching_joined.connect(_on_coaching_joined)
	EventBus.topico_requested.connect(_on_topico_requested)
	EventBus.training_ended.connect(_on_training_ended)
	EventBus.training_started.connect(func() -> void: freeze(true, "training"))
	EventBus.qa_feedback_started.connect(func(_n: int) -> void: freeze(true, "feedback"))  # mismo motivo que Haime (P5)
	EventBus.qa_feedback_ended.connect(func(_n: int) -> void: freeze(false, "feedback"))
	EventBus.ack_expired.connect(_on_ack_expired)
	EventBus.ack_given.connect(_on_ack_given)
	EventBus.angry_streak.connect(_on_angry_streak)
	EventBus.pursuit_ended.connect(_on_pursuit_ended)
	EventBus.calm_started.connect(func(_s: float) -> void: _stop_pursuits("calma"))
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: _session_token += 1; _session_active = false; _say_serial += 1)
	EventBus.written_warning_issued.connect(func(_n: int, _r: String) -> void: _bald_until_clock = GameState.clock_seconds + float(_cfg("presencia").get("calvo_min_juego_tras_ww", 30)) * 60.0)
	var pscr := load("res://scripts/core/pursuit.gd") as GDScript
	if pscr != null:
		_pursuit_node = pscr.new()
		_pursuit_node.name = "Pursuit"
		add_child(_pursuit_node)
	var prs := load("res://scripts/core/shero_presence.gd") as GDScript
	if prs != null:
		presence = prs.new()
		presence.name = "SheroPresence"
		add_child(presence)
	reset()


func reset() -> void:
	counters = {"llamados": 0, "verbales": 0, "ww": 0, "por_pista": {}, "veces": {}, "perdidas": 0, "listas_bajo": 0, "topico": 0, "perdon_dormido": false, "historial": [], "lunch_avisos": []}
	_freeze_reasons.clear()
	_clear_runtime()
	_rng.seed = 901 + GameState.turno * 17


func _clear_runtime() -> void:
	_say_serial += 1
	_lunch_reset_runtime()
	_run.clear()
	_slow_holds.clear()
	_rooms_left = -1.0
	_session_token += 1
	_session_active = false
	_coach_auth_seen = false
	_excuse_open = false
	_third_confirm_until_ms = -1
	_bald_until_clock = -INF
	_comodin_marker = ""
	_comodin_feint_t = -1.0
	_last_clock = GameState.clock_seconds
	if GameState.clock_override == "coaching_sesion":
		GameState.clear_clock_override("coaching_sesion")
	_stop_pursuits("reinicio")


func _stop_pursuits(reason: String) -> void:
	if _pursuit_node != null and _pursuit_node.has_method("stop_all"):
		_pursuit_node.call("stop_all", reason)


# --- Contrato ------------------------------------------------------------------------------------

## ¿P3 ejecuta esta pista? (P4 deja de hacer su escalera mínima de respaldo). El tópico (1.er pedido = permiso,
## 2.º = work avoiding) lo lleva P5 cuando su TopicoControl está en el proyecto; "topico_excedido" es siempre de P3.
func owns_track(track: String) -> bool:
	if track == "topico" and _p5_owns_topico():
		return false
	return OWNED.has(track)


func _p5_owns_topico() -> bool:
	if _p5_topico < 0:
		_p5_topico = 0
		for c in ProjectSettings.get_global_class_list():
			if str(c.get("class", "")) == "TopicoControl":
				_p5_topico = 1
	return _p5_topico == 1


## Congela (on) o descongela todas las pistas por un motivo ("feedback" de Haime, "training", "coaching_autorizado"…;
## cualquier texto vale: queda congelado mientras quede algún motivo).
func freeze(on: bool, reason: String) -> void:
	EventBus.freeze_discipline.emit(on, reason)


func _on_freeze(on: bool, reason: String) -> void:
	if on and not _freeze_reasons.has(reason):
		_freeze_reasons.append(reason)
	elif not on:
		_freeze_reasons.erase(reason)
	_last_clock = GameState.clock_seconds  # el tiempo congelado no cuenta


func is_frozen() -> bool:
	return not _freeze_reasons.is_empty()


func freeze_reasons() -> Array[String]:
	return _freeze_reasons.duplicate()


## Escalón ACTIVO de una pista (0 nada, 1 llamado … 4 persecución). Al corregir vuelve a 0 (las veces quedan).
func step_of(track: String) -> int:
	return int((counters.get("por_pista", {}) as Dictionary).get(track, Step.NADA))


## Escalón más alto entre las pistas activas (para Dread, el HUD, el look de Shero y la presencia).
func max_step() -> int:
	var m := 0
	for v in (counters.get("por_pista", {}) as Dictionary).values():
		m = maxi(m, int(v))
	return m


## Enojo 0..1 (llamado 0,2 · verbal 0,4 · WW 0,65 · persecución 1).
func anger() -> float:
	return [0.0, 0.2, 0.4, 0.65, 1.0, 1.0][clampi(max_step(), 0, 5)]


## Shero calvo (S 13:28): desde el WW, en la persecución y un rato después de un WW; afro con la calma.
func shero_bald() -> bool:
	if Pursuit.is_hunting("shero"):
		return true  # v0.3.2-core4: también en la calma (el break/lunch excedido ya no espera a que termine)
	if GameState.in_calm:
		return false
	if max_step() >= Step.WW:
		return true
	return GameState.clock_seconds < _bald_until_clock


## Pistas abiertas ahora: {pista: {min, escalon, siguiente_min}}.
func active_tracks() -> Dictionary:
	var out: Dictionary = {}
	for k in _run.keys():
		var r: Dictionary = _run[k]
		var nxt := -1.0
		if int(r["i"]) < (r["times"] as Array).size():
			nxt = float(r["times"][int(r["i"])]) / 60.0
		out[k] = {"min": float(r["t"]) / 60.0, "escalon": step_of(k), "siguiente_min": nxt}
	return out


## Umbrales de una pista (escalada.json) en minutos de juego ya escalados por dificultad.
func thresholds(track: String) -> Dictionary:
	var t: Dictionary = _pista(track)
	var out: Dictionary = {}
	# v0.3.2-core4: plazos por dificultad en balance.json/escalera (minutos de juego tras el límite de regla, o desde
	# que empieza la falta si la pista no tiene límite). null o ausente = la pista no tiene ese escalón.
	var row := ladder_row(track)
	if not row.is_empty():
		var base := float(t.get("limite_regla_min", 0.0)) if t.get("limite_regla_min") != null else 0.0
		var col := difficulty_column()
		for i in TH_KEYS.size():
			var arr: Variant = row.get(STEP_KEYS[i + 1], null)
			if arr is Array and not (arr as Array).is_empty():
				var v: Variant = (arr as Array)[mini(col, (arr as Array).size() - 1)]
				if v != null:
					out[TH_KEYS[i]] = base + float(v)
		return out
	var k := Difficulty.scale("plazos")
	# P7: en las pistas con un límite de regla (break 10, lunch 45, correo 10) la dificultad escala lo que pasa
	# DESPUÉS del límite, no el límite: en Difícil/Turno real un break de 8 min sigue siendo legal (antes el
	# llamado llegaba a los 7,5 min y el lunch de 40 min daba un WW al jugador que cumplía la regla).
	var lim := float(t.get("limite_regla_min", -1.0)) if t.get("limite_regla_min") != null else -1.0
	for key in TH_KEYS:
		if t.has(key) and t[key] != null:
			var v := float(t[key])
			out[key] = (lim + (v - lim) * k) if lim >= 0.0 and v >= lim else v * k
	return out


func executor(track: String) -> String:
	return str(_pista(track).get("ejecutor", "shero"))


# --- v0.3.2-core4: plazos por dificultad y marcas ---------------------------------------------------

## Columna de dificultad de las tablas de balance.json (0 Fácil · 1 Normal · 2 Difícil · 3 Turno real).
func difficulty_column() -> int:
	return 3 if GameState.is_real_mode() else clampi(Difficulty.level, 0, 2)


## Fila de la pista en balance.json/escalera ({} si no tiene: valen los plazos de escalada.json).
func ladder_row(track: String) -> Dictionary:
	var v: Variant = (DataLoader.dict("balance").get("escalera", {}) as Dictionary).get(track, null)
	return v if v is Dictionary else {}


func _marks_cfg() -> Dictionary:
	var v: Variant = (DataLoader.dict("balance").get("escalera", {}) as Dictionary).get("marcas", null)
	return v if v is Dictionary else {}


## Tipo de falta de la pista para las marcas ("" = la pista no deja marcas).
func marks_group(track: String) -> String:
	var groups: Variant = _marks_cfg().get("grupos", {})
	if groups is Dictionary:
		for g in (groups as Dictionary).keys():
			var lst: Variant = (groups as Dictionary)[g]
			if lst is Array and (lst as Array).has(track):
				return str(g)
	return ""


## Marcas del turno del tipo de falta de esta pista (los excesos anteriores de su grupo). Viajan con el checkpoint.
func marks_of(track: String) -> int:
	var g := marks_group(track)
	if g == "":
		return 0
	var veces: Dictionary = counters.get("veces", {})
	var n := 0
	for t in (_marks_cfg().get("grupos", {}) as Dictionary)[g]:
		n += int(veces.get(str(t), 0))
	return n


## Minutos de juego que, como mínimo, pasan entre el primer aviso de un episodio y la persecución.
func marks_floor_min() -> float:
	var arr: Variant = _marks_cfg().get("piso_min", [3.0, 2.0, 2.0, 2.0])
	if arr is Array and not (arr as Array).is_empty():
		return float((arr as Array)[mini(difficulty_column(), (arr as Array).size() - 1)])
	return 2.0


## Aplica las marcas a una escalera (escalones y sus segundos): con marcas empieza un escalón más arriba —nunca en la
## persecución: como mucho en el último aviso que la pista tenga—, los escalones que quedan usan los primeros plazos
## y la persecución respeta el piso tras el primer aviso. Devuelve {steps, times, marcas}.
func _apply_marks(track: String, steps_all: Array[int], times_all: Array[float]) -> Dictionary:
	var marks := marks_of(track)
	var start_step := steps_all[0]
	if not ladder_row(track).is_empty():
		if marks >= 1:
			var sube: Array = _marks_cfg().get("sube", ["verbal", "ww"])
			var want := STEP_KEYS.find(str(sube[mini(marks - 1, sube.size() - 1)])) if not sube.is_empty() else Step.VERBAL
			var chosen := -1
			var last_warn := -1
			for st in steps_all:
				if st < Step.PERSECUCION:
					last_warn = st
					if chosen < 0 and st >= want:
						chosen = st
			if chosen < 0:
				chosen = last_warn
			if chosen > 0:
				start_step = maxi(start_step, chosen)
	else:
		# Pistas sin fila nueva: la reincidencia de escalada.json, como antes.
		var veces := int((counters.get("veces", {}) as Dictionary).get(track, 0))
		var rein: Variant = _pista(track).get("reincidencia", null)
		if veces >= 1 and rein is Array and (rein as Array).size() >= 1:
			start_step = maxi(start_step, STEP_KEYS.find(str((rein as Array)[mini(veces - 1, (rein as Array).size() - 1)])))
	var steps: Array[int] = []
	for st in steps_all:
		if st >= start_step:
			steps.append(st)
	var times: Array[float] = []
	for i in steps.size():
		times.append(times_all[i])
	if not ladder_row(track).is_empty() and steps.size() >= 2 and steps[steps.size() - 1] == Step.PERSECUCION:
		times[times.size() - 1] = maxf(times[times.size() - 1], times[0] + marks_floor_min() * 60.0)
	return {"steps": steps, "times": times, "marcas": marks}


## Para el HUD y Fonex: el margen del Break o del Lunch en curso. {} si no aplica (otro AUX, un tercer break sin
## comodín). {pista, limite_s, sale_s (segundo de AUX en que sale la persecución), primero (escalón del primer aviso),
## marcas, comodin_s (lo que le queda al comodín; -1 si este break no es suyo)}.
func aux_margin() -> Dictionary:
	var track := ""
	if Metrics.aux == Metrics.Aux.BREAK:
		track = "break"
	elif Metrics.aux == Metrics.Aux.LUNCH:
		track = "lunch"
	if track == "" or not GameState.logged_in:
		return {}
	var covered := comodin_break_covered()
	if track == "break" and Metrics.breaks_used > Metrics.breaks_allowed() and not covered:
		return {}
	var steps: Array = []
	var times: Array = []
	var marks := marks_of(track)
	if _run.has(track):
		steps = (_run[track] as Dictionary)["steps"]
		times = (_run[track] as Dictionary)["times"]
		marks = int(((_run[track] as Dictionary).get("info", {}) as Dictionary).get("marcas", marks))
	else:
		var th := thresholds(track)
		var steps_all: Array[int] = []
		var times_all: Array[float] = []
		for i in TH_KEYS.size():
			if th.has(TH_KEYS[i]):
				steps_all.append(i + 1)
				times_all.append(float(th[TH_KEYS[i]]) * 60.0)
		if steps_all.is_empty():
			return {}
		var plan := _apply_marks(track, steps_all, times_all)
		steps = plan["steps"]
		times = plan["times"]
	if steps.is_empty():
		return {}
	var lim := float(_pista(track).get("limite_regla_min", 0.0)) * 60.0
	var sale := -1.0
	for i in steps.size():
		if int(steps[i]) == Step.PERSECUCION:
			sale = float(times[i])
	return {"pista": track, "limite_s": lim, "sale_s": sale, "primero": int(steps[0]), "marcas": marks, "comodin_s": comodin_break_left() if covered else -1.0}


## Ventana de Ack de un WW (Metrics la pide): 8 s × dificultad sentado en una PC de la sala; si estás lejos,
## ww_ack/ack_s_lejos (60 s) × dificultad para llegar a una PC en el piso 2, y ack_s_lejos_otro_piso (90 s) desde otro
## piso o la escalera (v0.3.2: ya no hay terminales Fonex de pared).
func ack_window_seconds(base: float) -> float:
	if _at_terminal():
		return base
	var p := _pista("ww_ack")
	var far := float(p.get("ack_s_lejos", 60.0))
	if GameState.current_floor != 2 or _in_stairwell():
		far = float(p.get("ack_s_lejos_otro_piso", 90.0))
	far *= Difficulty.scale("ack")
	if bool(Loc.get_setting("ack_extra", false)):
		far *= 1.5
	return maxf(base, far)


func _in_stairwell() -> bool:
	var b := get_tree().get_first_node_in_group("building") as Building if is_inside_tree() else null
	return b != null and b.floor_node is Stairwell


## ¿Estás en un sitio donde dar Ack ya? Sentado en una PC de la sala (con pantallas) o con la PC acercada.
## (El nombre viene de cuando había terminales de pared; el flag terminal_open ya no se pone.)
func _at_terminal() -> bool:
	if GameState.seated_at != "" and GameState.current_floor == 2:
		var cm := _cm()
		if cm != null and cm.player_ready():
			return true
		var ws := get_tree().get_first_node_in_group("workstation") as Control if is_inside_tree() else null
		if ws != null and ws.visible:
			return true
	return bool(GameState.flags.get("pc_zoom", false))


## v0.3.2: ¿Hay una PC de la sala delante (sentado en un puesto con pantallas)? Para Vitzo y el comodín.
func at_pc() -> bool:
	return _at_terminal()


## ¿Puede el reloj correr a 45x (sin cola)? No fuera de la sala, sentado en otra isla ni con una pista
## de minutos de las que se miden de pie abierta (PLAN #83: "nunca a 45x"). v0.3.1 (F20, C3): tampoco con una
## convocatoria abierta (summons_pending).
func allows_fast_clock() -> bool:
	if not GameState.logged_in:
		return true
	if not _in_room():
		return false
	if _other_island(GameState.seated_at):
		return false
	for k in SLOW_CLOCK_TRACKS:
		if _run.has(k):
			return false
	if summons_pending():
		return false
	return true


## v0.3.1 Q1 (C3): una convocatoria (Haime, Rasec, el Trainer, un coaching…) retiene el reloj a 4x mientras esté
## abierta: `hold_slow_clock("rasec", true)` al convocar y `false` al llegar o al cerrarse. Las claves se borran
## solas al reaparecer, al empezar turno y al volver al menú.
func hold_slow_clock(key: String, on: bool) -> void:
	if on:
		_slow_holds[key] = true
	else:
		_slow_holds.erase(key)
	GameState.call("_refresh_clock_mode")


func slow_holds() -> Array:
	return _slow_holds.keys()


## ¿Hay alguna convocatoria abierta? (claves de hold_slow_clock, Haime/Trainer llamando, el evento de Rasec
## convocado o un link de Rooms pendiente). Con una, ningún reloj libre corre: 4x (salvaguarda 2, PLAN §2.4).
func summons_pending() -> bool:
	if not GameState.logged_in:
		return false
	if not _slow_holds.is_empty():
		return true
	# v0.3.1 (F23, bot humano en Corta): una orden de AUX del RTA sin cumplir (Lunch a su hora, BO de una allocation,
	# Training) también es una convocatoria: sentado en Available el reloj iba a 400x y la ventana del lunch (15 min de
	# juego) se cerraba en 2 s reales: «lunch fuera de su hora» antes de poder cambiar el AUX.
	if Metrics.expected_aux in [Metrics.Aux.LUNCH, Metrics.Aux.BO, Metrics.Aux.TRAINING] and Metrics.aux != Metrics.expected_aux and not GameState.in_contact:
		return true
	if _rooms_left > 0.0:
		return true
	var hz := _hub()
	if hz != null and hz.rooms_pending:
		return true
	if not is_instance_valid(_p5_hub):
		_hook_p5()  # el hub de P5 se rehace con cada turno: no esperar al sondeo de cada 30 cuadros
	var h := _p5_hub as PersonajesP5 if is_instance_valid(_p5_hub) else null
	if h != null:
		if h.qa != null and h.qa.state == QaFeedback.State.LLAMADO:
			return true
		if h.training != null and h.training.state == TrainingControl.State.LLAMADO:
			return true
		if h.rasec != null and h.rasec.state == RasecControl.State.CONVOCADO:
			return true
		# v0.3.1 (F23, bot humano): el permiso del tópico (15 min de juego) corría a 240x mientras terminabas el
		# contacto: se vencía en 4 s reales y Shero cobraba «tópico excedido». Mientras no llegas, es una convocatoria.
		if h.topico != null and h.topico.state == TopicoControl.State.PERMISO and GameState.clock_seconds <= h.topico.permit_until:
			return true
	return false


func topico_permitted() -> bool:
	var a := Metrics.authorization_of("topico")
	return not a.is_empty() and float(a.get("until", 0.0)) > GameState.clock_seconds


## Shero (o Rasec) te convoca a coaching por Ezlaki Rooms (= lo que hacía v0.2 con coaching_requested).
func request_coaching(by: String = "shero", seconds: float = -1.0) -> void:
	var s := seconds if seconds > 0.0 else float(_pista("coaching_noshow").get("rooms_s_real", DataLoader.bal("coaching/unirse_s", 60.0)))
	EventBus.coaching_requested.emit(s)
	var hub := _hub()
	if hub != null:
		hub.rooms_from = by
	_rooms_from = by


func to_save_dict() -> Dictionary:
	var c := counters.duplicate(true)
	c["por_pista"] = {}  # las escaleras en curso no se guardan: al reaparecer se reinician
	return {"version": 3, "counters": c}


func from_save_dict(d: Dictionary) -> void:
	var c: Variant = d.get("counters", null)
	for r in _freeze_reasons.duplicate():
		EventBus.freeze_discipline.emit(false, r)  # el respawn corta cualquier sesión (Vitzo publica lo aplazado)
	reset()
	if c is Dictionary:
		for k in (c as Dictionary).keys():
			counters[k] = (c as Dictionary)[k]
		counters["por_pista"] = {}
	_last_clock = GameState.clock_seconds


# --- Datos ---------------------------------------------------------------------------------------

func _cfg(key: String) -> Dictionary:
	var v: Variant = DataLoader.dict("escalada").get(key, {})
	return v if v is Dictionary else {}


func _pista(track: String) -> Dictionary:
	var v: Variant = (DataLoader.dict("escalada").get("pistas", {}) as Dictionary).get(track, {})
	return v if v is Dictionary else {}


func _lines(track: String, key: String) -> Array:
	var esc: Dictionary = DataLoader.dict("lineas_shero").get("escalera", {})
	var t: Variant = esc.get(track, {})
	if t is Dictionary:
		var l: Variant = (t as Dictionary).get(key, [])
		if l is Array:
			return l
	return []


func cause_of(track: String) -> String:
	return str(_pista(track).get("muerte", track))


func _cm() -> ContactManager:
	return get_tree().get_first_node_in_group("contact_manager") as ContactManager if is_inside_tree() else null


func _hub() -> EzlakHub:
	return EzlakHub.get_hub(get_tree()) if is_inside_tree() else null


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


## El margen del Break / Lunch para poner al lado del contador del AUX (HUD y Fonex): « / 10:00 · margen 3:00», con
## marcas «· 1 marca», con el comodín «· comodín 06:40» y, pasado el límite, «· Shero sale a los 13:00». "" si no aplica.
func aux_margin_text() -> String:
	var m := aux_margin()
	if m.is_empty():
		return ""
	var t := Metrics.seconds_in_current_aux()
	var lim := float(m.get("limite_s", 0.0))
	var sale := float(m.get("sale_s", -1.0))
	var parts: Array[String] = []
	if float(m.get("comodin_s", -1.0)) >= 0.0:
		var left := float(m["comodin_s"])
		parts.append(Loc.fmt(tr("C4_HUD_COMODIN"), {"t": Loc.mmss(left)}) if left > 0.0 else tr("C4_HUD_COMODIN_FIN"))
	if sale >= 0.0:
		if t < lim:
			parts.append(Loc.fmt(tr("C4_HUD_MARGEN"), {"t": Loc.mmss(sale - lim)}))
		else:
			parts.append(Loc.fmt(tr("C4_HUD_SALE"), {"t": Loc.mmss(sale)}))
	var n := int(m.get("marcas", 0))
	if n > 0:
		parts.append(tr("C4_HUD_MARCA_1") if n == 1 else Loc.fmt(tr("C4_HUD_MARCAS"), {"n": n}))
	var out := " / %s" % Loc.mmss(lim)
	for part in parts:
		out += "  ·  " + part
	return out


# --- Bucle ---------------------------------------------------------------------------------------

## ¿Pueden avanzar las pistas ahora?
func _can_advance() -> bool:
	return _can_advance_rest() and not GameState.in_calm


## v0.3.2-core4: lo mismo sin mirar la calma: es lo que necesitan las pistas del break y del lunch (CALM_PROOF_TRACKS).
func _can_advance_rest() -> bool:
	return GameState.running and GameState.logged_in and not GameState.shift_over and not Checkpoints.dying and not is_frozen() and not Metrics.reconnecting


func _on_clock(now: float) -> void:
	var dt := now - _last_clock
	_last_clock = now
	if dt <= 0.0 or dt > 1800.0:
		return
	_lunch_reminder(now)
	if not _can_advance_rest():
		return
	var calm := GameState.in_calm
	var had: Array = _run.keys()
	if calm:
		_update_rest_tracks()  # en la calma solo corren los relojes de tu break y de tu lunch
	else:
		_update_tracks()
	for k in _run.keys().duplicate():
		if not _run.has(k) or not had.has(k):
			continue  # una pista que arranca en este tick no se lleva el salto (p. ej. 23:48 → 00:00 al loguearse)
		if calm and not CALM_PROOF_TRACKS.has(k):
			continue
		var r: Dictionary = _run[k]
		if k == "correo":
			continue  # la pista del correo lee el reloj del caso (email_timer_tick)
		if k != "lunch" and is_lunch_immune():
			continue  # v0.3.2: en el lunch la escalera de Shero espera (salvo la del propio lunch: >45 min)
		r["t"] = float(r["t"]) + dt
		_check(k)


var _idle_bo_game_s: float = 0.0

func _process(delta: float) -> void:
	if not GameState.running or get_tree().paused:
		return
	if GameState.logged_in and not GameState.shift_over and not is_frozen() and not GameState.in_calm:
		if Metrics.aux == Metrics.Aux.BO and Metrics.allocation_aux != Metrics.Aux.BO:
			var cm := _cm()
			var has_bo_case := cm != null and cm.case != null
			if not has_bo_case:
				_idle_bo_game_s += delta * GameState.clock_speed()
				if _idle_bo_game_s >= 120.0:
					_idle_bo_game_s = 0.0
					EventBus.rta_tag.emit("@%s estás en BO sin caso activo. Vuelve a Available." % GameState.agent)
					Pursuit.start("rta", "aux_incorrecto", 7.0, null, "BO sin caso", 2)
			else:
				_idle_bo_game_s = 0.0
		else:
			_idle_bo_game_s = 0.0
	if Engine.get_process_frames() % 30 == 0:
		_hook_p5()
	if GameState.logged_in:
		GameState.call("_refresh_clock_mode")  # v0.3.1: las convocatorias de P5 cambian sin señal (summons_pending)
	_tick_lunch_immunity(delta)
	_tick_comodin_feint(delta)
	if _rooms_left > 0.0 and not is_frozen() and not Checkpoints.dying and not is_lunch_immune():
		_rooms_left -= delta
		if _rooms_left <= 0.0:
			_rooms_left = -1.0
			_rooms_expired()


## Arranca/termina pistas según el estado (AUX, sala, asiento, autorizaciones).
func _on_state_changed() -> void:
	if not is_inside_tree():
		return
	GameState.call("_refresh_clock_mode")
	if _can_advance():
		_update_tracks()
	elif _can_advance_rest():
		_update_rest_tracks()


## Break y lunch: corren con el AUX; si ya se rompieron, hasta volver a la sala con otro AUX. Un break de más solo
## tiene pista si lo cubre el comodín (v0.3.2-core4); si no, lo suyo es la persecución del tercer break.
func _update_rest_tracks() -> void:
	if Checkpoints.dying:
		return
	var aux := Metrics.aux
	for pair in [["break", Metrics.Aux.BREAK], ["lunch", Metrics.Aux.LUNCH]]:
		var tr_id: String = pair[0]
		var a: int = pair[1]
		if aux == a:
			if not _run.has(tr_id) and not (tr_id == "break" and Metrics.breaks_used > Metrics.breaks_allowed() and not comodin_break_covered()):
				_start(tr_id, Metrics.seconds_in_current_aux())
		elif _run.has(tr_id):
			if _in_room() or int((_run[tr_id] as Dictionary)["i"]) == 0:
				_end(tr_id)


func _update_tracks() -> void:
	if Checkpoints.dying:
		return
	var aux := Metrics.aux
	_update_rest_tracks()
	# Coaching: sin permiso (Rasec) / excedido tras una sesión autorizada (Rasec).
	if aux == Metrics.Aux.COACHING:
		if Metrics.is_aux_authorized(Metrics.Aux.COACHING):
			_coach_auth_seen = true
			_end("coaching")
			_end("coaching_exceso")
		elif _coach_auth_seen:
			_end("coaching")
			if not _run.has("coaching_exceso"):
				_start("coaching_exceso", 0.0)
		elif not _run.has("coaching"):
			_start("coaching", 0.0)
	else:
		_coach_auth_seen = _session_active
		_end("coaching")
		_end("coaching_exceso")
	# Otra isla: sentado en una isla que no es la de Shero.
	if _other_island(GameState.seated_at):
		if not _run.has("otra_isla"):
			_start("otra_isla", 0.0)
	else:
		_end("otra_isla")
	# Regreso del training / tópico excedido: hasta volver a la sala.
	if _in_room():
		_end("training_regreso")
		_end("topico_excedido")
	# Fuera de la sala sin AUX autorizado.
	if _sala_breaking():
		if not _run.has("sala"):
			_start("sala", 0.0)
	else:
		_end("sala")


func _sala_breaking() -> bool:
	if _in_room() or not GameState.logged_in:
		return false
	for k in ["break", "lunch", "training_regreso", "topico_excedido"]:
		if _run.has(k):
			return false
	if Pursuit.is_hunting("shero"):
		return false
	return not _outside_authorized()


## Dentro de la sala de PCs: la zona "sala" o sentado en un sitio de las filas A-F del piso 2 (la zona tarda
## unos fotogramas en registrar al jugador que se sienta desde fuera).
func _in_room() -> bool:
	if GameState.in_room:
		return true
	var s := GameState.seated_at
	return GameState.current_floor == 2 and s.length() == 4 and s[1] == "-" and "ABCDEF".contains(s[0])


## ¿Está autorizado estar fuera de la sala donde estás? Break/Lunch/Baño = todo el edificio; las
## autorizaciones con zona cubren los pisos de escalada.json/zonas_pisos (la caja de escalera es camino).
func _outside_authorized() -> bool:
	if Metrics.aux in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH, Metrics.Aux.BANO]:
		return true
	var zp := _cfg("zonas_pisos")
	var b := get_tree().get_first_node_in_group("building") as Building
	var in_stairs := b != null and b.floor_node is Stairwell
	for a in Metrics.authorizations:
		if float(a.get("until", 0.0)) <= GameState.clock_seconds:
			continue
		var z := str(a.get("zone", ""))
		if z == Metrics.ZONE_ALL or in_stairs:
			return true
		var floors: Variant = zp.get(z, [-1, 1, 2, 9])
		if floors is Array and ((floors as Array).has(GameState.current_floor) or (floors as Array).has(float(GameState.current_floor))):
			return true
	return false


## Asientos de otra isla: A-F (no C); los de training y calibración no cuentan.
func _other_island(seat: String) -> bool:
	if seat == "" or seat.begins_with("C-"):
		return false
	for pre in _pista("otra_isla").get("no_cuentan", ["training_sala2", "calibracion"]):
		if seat.begins_with(str(pre)):
			return false
	return seat.length() == 4 and seat[1] == "-" and "ABDEF".contains(seat[0])


# --- Escalera ------------------------------------------------------------------------------------

## Abre una pista con su secuencia de escalones (reincidencia) y plazos. t0 = segundos ya transcurridos.
func _start(track: String, t0: float, info: Dictionary = {}) -> void:
	if _run.has(track) or step_of(track) >= Step.PERSECUCION:
		return  # ya salió con la amonestación: la persecución sigue aunque corrijas
	var th := thresholds(track)
	var steps_all: Array[int] = []
	var times_all: Array[float] = []
	for i in TH_KEYS.size():
		if th.has(TH_KEYS[i]):
			steps_all.append(i + 1)
			times_all.append(float(th[TH_KEYS[i]]) * 60.0)
	if steps_all.is_empty():
		return
	var plan := _apply_marks(track, steps_all, times_all)
	var inf := info.duplicate()
	inf["marcas"] = int(plan["marcas"])
	_run[track] = {"t": t0, "steps": plan["steps"], "times": plan["times"], "i": 0, "info": inf}
	GameState.call("_refresh_clock_mode")
	_check(track)


## Cierra una pista (corregida). Los escalones dados quedan en el historial; el escalón activo vuelve a 0.
func _end(track: String) -> void:
	if not _run.has(track):
		return
	_run.erase(track)
	if step_of(track) < Step.PERSECUCION:
		(counters["por_pista"] as Dictionary).erase(track)
	GameState.call("_refresh_clock_mode")


func _check(track: String) -> void:
	while _run.has(track):
		var r: Dictionary = _run[track]
		var i := int(r["i"])
		if i >= (r["steps"] as Array).size() or float(r["t"]) < float(r["times"][i]):
			return
		if track == "lunch" and second_nap():
			_second_nap_hunt()
			return
		r["i"] = i + 1
		_fire(track, int(r["steps"][i]))


## v0.3.1 Q1 (F14): ¿2.ª siesta del lunch en el turno? (ya te perdonó una vez y vuelves a estar dormido en el -1).
func second_nap() -> bool:
	return bool(counters.get("perdon_dormido", false)) and SleepSpot.is_player_sleeping() and GameState.current_floor == -1


## F14: la 2.ª vez dormido no hay escalera (llamado → verbal → WW): apenas vence el lunch, Shero viene directo a
## matarte, con la persecución intensa (C4: extra.intenso → pasos fuertes, luces que mueren, screamer lunch_dormido).
func _second_nap_hunt() -> void:
	_run.erase("lunch")
	(counters["por_pista"] as Dictionary)["lunch"] = Step.PERSECUCION
	var veces: Dictionary = counters["veces"]
	veces["lunch"] = int(veces.get("lunch", 0)) + 1
	(counters["historial"] as Array).append({"t": GameState.clock_seconds, "pista": "lunch", "escalon": Step.PERSECUCION, "segunda_siesta": true})
	_say("lunch", "persecucion", _vars("lunch", {}))
	EventBus.discipline_step.emit("lunch", Step.PERSECUCION, {"ejecutor": "shero", "causa": "lunch_excedido", "segunda_siesta": true, "intenso": true})
	if Pursuit.is_hunting("shero"):
		return
	var p := _cfg("persecucion")
	var ok := Pursuit.start("shero", "lunch_excedido", float(p.get("velocidad_shero_ms", 4.6)), null, Loc.mmss(GameState.lunch_minutes() * 60.0), -99, Vector3.INF, _on_catch, {"pista": "lunch", "intenso": true, "segunda_siesta": true})
	if not ok:
		Checkpoints.request_death("lunch_excedido", "", "shero")
	_bald_until_clock = GameState.clock_seconds + 3600.0
	GameState.call("_refresh_clock_mode")


## Ejecuta un escalón de una pista.
func _fire(track: String, step: int, extra: Dictionary = {}) -> void:
	if Checkpoints.dying:
		return
	var exe := executor(track)
	var detail := _detail(track, extra)
	var veces: Dictionary = counters["veces"]
	var first := step_of(track) == Step.NADA
	(counters["por_pista"] as Dictionary)[track] = step
	if first and track in MINUTE_TRACKS:
		veces[track] = int(veces.get(track, 0)) + 1
	var vars := _vars(track, extra)
	var info := {"ejecutor": exe, "causa": cause_of(track), "min": float((_run.get(track, {}) as Dictionary).get("t", 0.0)) / 60.0, "n": int(extra.get("n", 0))}
	info.merge(extra, false)
	(counters["historial"] as Array).append({"t": GameState.clock_seconds, "pista": track, "escalon": step})
	match step:
		Step.LLAMADO:
			counters["llamados"] = int(counters["llamados"]) + 1
			_say(track, "llamado", vars)
		Step.VERBAL:
			counters["verbales"] = int(counters["verbales"]) + 1
			_say(track, "verbal", vars)
		Step.WW:
			_issue_ww(cause_of(track) if track != "coaching_noshow_rasec" else "coaching")
			vars["n"] = Metrics.written_warnings
			_say(track, "ww", vars)
		Step.PERSECUCION:
			_run.erase(track)
			_say(track, "persecucion", vars)
			_hunt(track, exe, cause_of(track), detail)
	if first and track in MINUTE_TRACKS and step < Step.PERSECUCION and not ladder_row(track).is_empty():
		info["marcas"] = marks_of(track)
		_say_mark(track, exe)
	if first and track == "break" and SleepSpot.is_player_sleeping():
		# v0.3.2-core4: dormido el reloj va a 30x y los minutos de margen serían segundos: el primer aviso del break
		# te despierta (y el reloj vuelve a 4x). En el lunch no: ahí vale la regla del dormido (perdón una vez).
		_wake_player()
		EventBus.show_message.emit(tr("C4_DESPIERTA_PARLANTES"), 4.0)
	EventBus.discipline_step.emit(track, step, info)
	if step == Step.VERBAL and int(counters["verbales"]) % 2 == 0 and not Checkpoints.dying:
		_two_verbals(track)
	GameState.call("_refresh_clock_mode")


## "Dos verbales hacen un escrito".
func _two_verbals(track: String) -> void:
	_say("dos_verbales", "ww", _vars("dos_verbales", {}))
	_issue_ww(cause_of(track) if track != "coaching_noshow_rasec" else "coaching")
	EventBus.discipline_step.emit("dos_verbales", Step.WW, {"ejecutor": "shero", "verbales": counters["verbales"], "pista": track})


func _issue_ww(reason: String) -> void:
	counters["ww"] = int(counters["ww"]) + 1
	_bald_until_clock = GameState.clock_seconds + float(_cfg("presencia").get("calvo_min_juego_tras_ww", 30)) * 60.0
	Metrics.issue_written_warning(reason)
	if Metrics.written_warnings == 2 and not Checkpoints.dying:
		_say("ww_conteo", "segundo", {})  # "Segundo WW enviado, con copia a los tres OM…" (clip cosechado, P7)


func _detail(track: String, extra: Dictionary) -> String:
	match track:
		"break", "lunch", "correo", "coaching_exceso":
			var r: Dictionary = _run.get(track, {})
			var th := thresholds(track)
			var s := float(r.get("t", float(th.get("persecucion_min", 0.0)) * 60.0))
			if track == "correo" and extra.has("t"):
				s = float(extra["t"])
			return Loc.mmss(s)
		"available":
			return str(int(round(float(extra.get("pct", Metrics.available_pct())))))
		"llamadas_perdidas":
			return str(int(extra.get("n", counters.get("perdidas", 0))))
	return ""


func _vars(track: String, extra: Dictionary) -> Dictionary:
	var v := {"agente": GameState.agent, "n": Metrics.written_warnings, "pct": int(round(float(extra.get("pct", Metrics.available_pct())))), "hora": GameState.clock_text_at(GameState.lunch_clock()) if track == "lunch" else GameState.clock_text_at(GameState.clock_seconds - 70.0 * 60.0)}
	var r: Dictionary = _run.get(track, {})
	v["min"] = int(float(r.get("t", 0.0)) / 60.0)
	# v0.3.2-core4: minutos de juego que faltan para que salga la persecución (los textos ya no llevan números fijos).
	v["quedan"] = 0
	if not r.is_empty() and not (r["times"] as Array).is_empty() and int((r["steps"] as Array)[(r["steps"] as Array).size() - 1]) == Step.PERSECUCION:
		v["quedan"] = maxi(int(ceil((float((r["times"] as Array)[(r["times"] as Array).size() - 1]) - float(r.get("t", 0.0))) / 60.0)), 1)
	v["marcas"] = marks_of(track)
	if track == "otra_isla":
		var names: Array[String] = []
		for a in GameState.AGENTS:
			if a != GameState.agent:
				names.append("@" + a)
		v["lista"] = " ".join(PackedStringArray(names.slice(0, 3)))
	return v


## Publica/dice los mensajes de un escalón (lineas_shero.json/escalera/<pista>/<clave>).
func _say(track: String, key: String, vars: Dictionary) -> void:
	for msg in _lines(track, key):
		if msg is Dictionary:
			var delay := float((msg as Dictionary).get("retraso", 0.0))
			if delay > 0.0:
				_say_later(track, key, msg as Dictionary, vars, delay)
			else:
				_emit_msg(track, key, msg as Dictionary, vars)


## Mensaje con "retraso" (segundos reales): sale después de la voz del escalón para no cortarla (P7). Se descarta si
## en el medio empezó una muerte, se volvió al menú o terminó el turno.
func _say_later(track: String, key: String, msg: Dictionary, vars: Dictionary, delay: float) -> void:
	var shift := _say_serial
	await get_tree().create_timer(delay, false).timeout
	if shift != _say_serial or Checkpoints.dying or not GameState.running or GameState.shift_over:
		return
	_emit_msg(track, key, msg, vars)


func _emit_msg(track: String, key: String, msg: Dictionary, vars: Dictionary) -> void:
	var autor := str(msg.get("autor", "shero"))
	var text := Loc.fmt(Loc.pick(msg), vars)
	var canal := str(msg.get("canal", "dm"))
	var voz := str(msg.get("voz", ""))
	match canal:
		"voz", "pa", "rooms":
			if presence != null:
				presence.call("speak", autor, text, voz, canal)
		_:
			var ch := ("dm:" + autor) if canal == "dm" else canal
			var meta := {"tipo": "disciplina", "pista": track, "escalon": key, "mention": bool(msg.get("mention", ch.begins_with("dm:")))}
			if msg.has("typing_s"):
				meta["typing_s"] = float(msg["typing_s"])
			if msg.has("edita"):
				meta["edita"] = Loc.fmt(Loc.pick(msg["edita"]), vars)
				meta["edita_s"] = float(msg.get("edita_s", 5.0))
			if msg.has("quick_replies"):
				meta["quick_replies"] = msg["quick_replies"]
			EventBus.ezlak_post.emit(ch, autor, text, meta)


## v0.3.2-core4: el exceso queda anotado y el jugador lo sabe. DM de quien ejecuta la pista (Shero o Rasec) después del
## aviso del escalón: «primera marca por…» / «van N marcas por…» (lineas_shero.json/escalera/marca).
func _say_mark(track: String, exe: String) -> void:
	var n := marks_of(track)
	if n <= 0:
		return
	var data: Dictionary = DataLoader.dict("lineas_shero").get("escalera", {})
	var tipos: Dictionary = (data.get("marca", {}) as Dictionary).get("tipos", {})
	var vars := _vars(track, {})
	vars["n"] = n
	vars["tipo"] = Loc.pick(tipos.get(marks_group(track), {"es": "eso", "en": "that"}))
	for msg in _lines("marca", "primera" if n == 1 else "mas"):
		if msg is Dictionary:
			var m := (msg as Dictionary).duplicate()
			m["autor"] = exe
			_say_later(track, "marca", m, vars, float(m.get("retraso", 3.0)))


# --- v0.3.2-core4: el comodín y el tercer break ------------------------------------------------------

## Comodin avisa justo antes de marcarte Break en tu PC (y lo retira justo después): si ese Break es uno de más,
## _on_break_started lo trata como cubierto por el comodín en vez de salir a matarte.
func comodin_marks_break(quien: String) -> void:
	_comodin_marker = quien


## ¿El Break en curso es uno de más (el tercero) cubierto por el comodín? Vive en counters (viaja con el checkpoint).
func comodin_break_covered() -> bool:
	return Metrics.aux == Metrics.Aux.BREAK and Metrics.breaks_used > Metrics.breaks_allowed() and int(counters.get("comodin_break", 0)) == Metrics.breaks_used


## Segundos de juego que le quedan al comodín en este Break (su cupo: 10 min). 0 si ya venció o no es suyo.
func comodin_break_left() -> float:
	return maxf(Metrics.quota_left(Metrics.Aux.BREAK), 0.0) if comodin_break_covered() else 0.0


## Tercer break marcado por un compañero: Shero salta igual («¿TERCER BREAK?!») y sale hacia ti, pero ve que tu PC se
## marcó sola y lo deja pasar: se detiene, lo dice (voz + DM) y vuelve a su sitio con su cara normal. Pasado el cupo
## corre la pista «break» de siempre (con las marcas que tengas) y la muerte es break_excedido.
func _comodin_break(n: int, quien: String) -> void:
	counters["comodin_break"] = n
	_comodin_who = quien
	(counters["historial"] as Array).append({"t": GameState.clock_seconds, "pista": "tercer_break", "escalon": Step.NADA, "comodin": quien})
	_say("tercer_break", "persecucion", _vars("break", {}))
	EventBus.discipline_step.emit("tercer_break", Step.NADA, {"ejecutor": "shero", "causa": "tercer_break", "n": n, "comodin": quien, "cubierto": true})
	var started := false
	if not Pursuit.is_hunting("shero") and not Checkpoints.dying:
		var p := _cfg("persecucion")
		_comodin_bald_before = _bald_until_clock
		started = Pursuit.start("shero", "tercer_break", float(p.get("velocidad_shero_ms", 4.6)), null, str(n), -99, Vector3.INF, _on_comodin_catch, {"pista": "tercer_break", "comodin": true, "amago": true})
	if started:
		(counters["por_pista"] as Dictionary)["tercer_break"] = Step.PERSECUCION
		_comodin_feint_t = 0.0
	else:
		_comodin_spare_lines(quien)  # ya venía por otra cosa (esa caza sigue) o no puede salir: solo lo dice
	_on_state_changed()


## El amago: corre hacia ti unos segundos (o unos metros, o hasta tenerte cerca) y se detiene.
func _tick_comodin_feint(delta: float) -> void:
	if _comodin_feint_t < 0.0:
		return
	if not Pursuit.is_hunting("shero") or Checkpoints.dying or str(Pursuit.info("shero").get("cause", "")) != "tercer_break":
		_comodin_feint_t = -1.0
		return
	if is_frozen():
		return
	_comodin_feint_t += delta
	var c: Dictionary = DataLoader.dict("balance").get("comodin", {})
	var inf := Pursuit.info("shero")
	var near := inf.has("dist") and float(inf["dist"]) <= float(c.get("amago_cerca_m", 6.0)) and str(inf.get("state", "")) != "llegando"
	if near or float(inf.get("meters", 0.0)) >= float(c.get("amago_m", 9.0)) or _comodin_feint_t >= float(c.get("amago_s_real", 5.0)):
		_comodin_spare()
		Pursuit.stop("shero", "comodin")


## Si en el amago llega a alcanzarte, tampoco te mata: te lo dice a la cara y se va.
func _on_comodin_catch(_info: Dictionary) -> bool:
	_comodin_spare()
	return true


func _comodin_spare() -> void:
	_comodin_feint_t = -1.0
	_bald_until_clock = _comodin_bald_before  # el enojo del amago no deja a Shero calvo una hora
	(counters["por_pista"] as Dictionary).erase("tercer_break")
	_comodin_spare_lines(_comodin_who)
	EventBus.discipline_step.emit("tercer_break", Step.NADA, {"ejecutor": "shero", "causa": "tercer_break", "comodin_perdon": true})


func _comodin_spare_lines(quien: String) -> void:
	var vars := _vars("break", {})
	vars["quien"] = quien
	vars["cupo"] = int(DataLoader.bal("cupos_aux_min/break", 10.0))
	_say("comodin_break", "perdon", vars)


## Escalón 4: Shero sale con la amonestación (Pursuit). Rasec no persigue: su muerte sale por la pantalla
## (contrato con P5: Checkpoints.request_death(causa, detalle, "rasec"); P5 lo hace aparecer).
func _hunt(track: String, exe: String, cause: String, detail: String) -> void:
	if exe == "rasec":
		Checkpoints.request_death(cause, detail, "rasec")
		return
	if Pursuit.is_hunting("shero"):
		return  # una sola persecución: la que ya viene te alcanza igual
	var p := _cfg("persecucion")
	_say("amonestacion", "canal", _vars(track, {}))
	Pursuit.start("shero", cause, float(p.get("velocidad_shero_ms", 4.6)), null, detail, -99, Vector3.INF, _on_catch, {"pista": track, "ww_reason": Metrics.ack_reason})
	_bald_until_clock = GameState.clock_seconds + 3600.0


## Shero te alcanzó: ¿perdona? Lunch dormido en un sofá/puff del -1 (1 vez por turno) o Fácil sentado en tu
## PC en Available. Devuelve true si NO hay muerte.
func _on_catch(info: Dictionary) -> bool:
	var cause := str(info.get("cause", ""))
	var lunchish := cause == "lunch_excedido" or (cause == "ww_sin_ack" and str((info.get("extra", {}) as Dictionary).get("ww_reason", "")) == "lunch_excedido")
	if lunchish and SleepSpot.is_player_sleeping() and GameState.current_floor == -1:
		if not bool(counters.get("perdon_dormido", false)):
			counters["perdon_dormido"] = true
			_say("lunch", "perdon", _vars("lunch", {}))
			_wake_player()
			if Metrics.aux == Metrics.Aux.LUNCH:
				Metrics.set_aux(Metrics.Aux.AVAILABLE)  # "Sube." — te pone en Available: ahora corre la sala
			_end("lunch")
			(counters["por_pista"] as Dictionary).erase("lunch")
			(counters["por_pista"] as Dictionary).erase("ww_ack")
			_issue_ww("lunch_excedido")
			EventBus.discipline_step.emit("lunch", Step.WW, {"ejecutor": "shero", "perdon": true, "causa": "lunch_excedido"})
			return true
		_say("lunch", "perdon_2", _vars("lunch", {}))
		return false
	var p := _player()
	if Difficulty.flag("salvarse_sentado") and p != null and p.seated and GameState.seated_at.begins_with("C-") and Metrics.aux == Metrics.Aux.AVAILABLE:
		for k in (counters["por_pista"] as Dictionary).keys().duplicate():
			if step_of(k) >= Step.PERSECUCION:
				(counters["por_pista"] as Dictionary).erase(k)
		_issue_ww(cause)
		EventBus.discipline_step.emit(str((info.get("extra", {}) as Dictionary).get("pista", cause)), Step.WW, {"ejecutor": "shero", "facil_sentado": true, "causa": cause})
		return true
	return false


## v0.3.1 Q1 (F5): el 3.er break ya no mata en el acto: Shero sale corriendo desde donde está (su escritorio en el
## piso 2; desde otro piso, el tránsito visible es de Q2, C4) y te alcanza. No hay perdón: ni Fácil sentado en tu
## PC ni el lunch dormido (on_catch siempre devuelve false). Si ya te persigue, esa persecución te alcanza igual.
func _third_break_hunt(n: int) -> void:
	if Pursuit.is_hunting("shero"):
		return
	var p := _cfg("persecucion")
	var ok := Pursuit.start("shero", "tercer_break", float(p.get("velocidad_shero_ms", 4.6)), null, str(n), -99, Vector3.INF, func(_i: Dictionary) -> bool: return false, {"pista": "tercer_break", "sin_perdon": true})
	if not ok:
		Checkpoints.request_death("tercer_break", str(n), "shero")
		return
	_bald_until_clock = GameState.clock_seconds + 3600.0


## v0.3.1 Q1 (F7): correr en la sala por 3.ª vez en 5 min → Shero viene en persona: un verbal (cuenta para
## «dos verbales hacen un escrito»). Lo llama el jugador (player.gd); los mensajes de Ezlaki los limita él.
func running_verbal() -> void:
	if not _can_advance() or Checkpoints.dying:
		return
	counters["verbales"] = int(counters["verbales"]) + 1
	(counters["historial"] as Array).append({"t": GameState.clock_seconds, "pista": "correr", "escalon": Step.VERBAL})
	var data: Dictionary = DataLoader.dict("lineas_shero").get("de_pie_en_live", {})
	var arr: Array = data.get("lineas", [])
	if presence != null and not arr.is_empty():
		presence.call("speak", "shero", Loc.pick(arr[_rng.randi_range(0, arr.size() - 1)]), str(data.get("voz", "shero_por_que_aux")), "voz")
	EventBus.discipline_step.emit("correr", Step.VERBAL, {"ejecutor": "shero", "causa": "correr"})
	if int(counters["verbales"]) % 2 == 0:
		_two_verbals("sala")


## v0.3.2: el comodín usado otra vez en la partida (Shero vio tu PC cambiar sola): un verbal (cuenta para «dos verbales
## hacen un escrito»).
func comodin_verbal() -> void:
	if not _can_advance() or Checkpoints.dying:
		return
	counters["verbales"] = int(counters["verbales"]) + 1
	(counters["historial"] as Array).append({"t": GameState.clock_seconds, "pista": "comodin", "escalon": Step.VERBAL})
	EventBus.discipline_step.emit("comodin", Step.VERBAL, {"ejecutor": "shero", "causa": "comodin"})
	if int(counters["verbales"]) % 2 == 0:
		_two_verbals("sala")


func _wake_player() -> void:
	var id := SleepSpot.sleeping_spot()
	for s in get_tree().get_nodes_in_group("sleep_spots"):
		if s is SleepSpot and (s as SleepSpot).spot_id == id:
			(s as SleepSpot).wake_up()
			return


func _on_pursuit_ended(hunter: String, reason: String) -> void:
	if hunter != "shero" or reason == "alcanzado":
		return  # alcanzado: la muerte ya está en curso (al reaparecer todo se reinicia)
	for k in (counters["por_pista"] as Dictionary).keys().duplicate():
		if step_of(k) >= Step.PERSECUCION:
			(counters["por_pista"] as Dictionary).erase(k)
	_on_state_changed()


# --- Disparadores por evento -----------------------------------------------------------------------

## v0.3.2-core3: ¿Fácil acaba de devolverte un tercer break para que lo confirmes? (ese Break no llegó a empezar)
func third_break_confirming() -> bool:
	return _third_confirm_until_ms >= 0 and Time.get_ticks_msec() <= _third_confirm_until_ms


func _on_break_started(n: int) -> void:
	if not GameState.logged_in:
		return
	var allowed := Metrics.breaks_allowed()
	var marker := _comodin_marker
	_comodin_marker = ""
	if n > allowed and marker != "":
		_comodin_break(n, marker)  # v0.3.2-core4: te lo marcó un compañero: cubierto durante su cupo
		return
	if n > allowed:
		if Difficulty.flag("confirmar_tercer_break") and Time.get_ticks_msec() > _third_confirm_until_ms:
			# Fácil: confirmación previa. Vuelve al AUX anterior; elegir Break otra vez en 6 s lo confirma.
			_third_confirm_until_ms = Time.get_ticks_msec() + 6000
			Metrics.breaks_used -= 1
			Metrics.set_aux.call_deferred(Metrics.Aux.AVAILABLE)
			EventBus.show_message.emit(tr("P3_CONFIRM_THIRD_BREAK"), 6.0)
			return
		(counters["por_pista"] as Dictionary)["tercer_break"] = Step.PERSECUCION
		_say("tercer_break", "persecucion", _vars("break", {}))
		EventBus.discipline_step.emit("tercer_break", Step.PERSECUCION, {"ejecutor": "shero", "causa": "tercer_break", "n": n})
		_third_break_hunt(n)
		return
	if n == 1:
		_say("break_1", "molestia", _vars("break", {}))
		EventBus.discipline_step.emit("break_1", Step.NADA, {"ejecutor": "shero", "n": 1, "molestia": true})
	elif n == 2:
		counters["llamados"] = int(counters["llamados"]) + 1  # el 2.º break sí cuenta como llamado
		_say("break_2", "llamado", _vars("break", {}))
		EventBus.discipline_step.emit("break_2", Step.LLAMADO, {"ejecutor": "shero", "n": 2})
	_on_state_changed()


## Correo/caso de BO abierto: la pista lee el reloj del caso (P4: email_timer_tick = límite − transcurrido).
func _on_email_tick(seconds_left: float) -> void:
	var cm := _cm()
	if cm == null or cm.current.is_empty():
		return
	var limit := float(cm.current.get("limite_s_juego", (DataLoader.dict("casos_bo").get("reglas", {}) as Dictionary).get("limite_s_juego", 600.0)))
	var raw := limit - seconds_left
	var cid := str(cm.current.get("id", ""))
	if cid != _correo_case or raw < _correo_last:
		_correo_case = cid
		_correo_last = raw
		_correo_paused = 0.0
	# v0.3.2 (lo encontró el bot humano): el evento de Rasec te saca del puesto con el caso abierto y su reloj seguía:
	# volvías con el correo ya vencido y Shero te cazaba por AHT BO. Ese rato no cuenta (como el training o el feedback).
	var rasec_event := is_instance_valid(_p5_hub) and str(_p5_hub.get("busy")) == "evento"
	if not _can_advance() or rasec_event:
		_correo_paused += maxf(raw - _correo_last, 0.0)
	_correo_last = raw
	var elapsed := raw - _correo_paused
	if rasec_event:
		return
	if not _run.has("correo"):
		if elapsed < limit or not _can_advance() or step_of("correo") >= Step.PERSECUCION:
			return
		var th := thresholds("correo")
		var k0 := float(th.get("llamado_min", 10.0))
		_start_correo(limit, k0)
	if not _can_advance():
		return
	var r: Dictionary = _run["correo"]
	r["t"] = elapsed
	_check("correo")


func _start_correo(limit: float, k0: float) -> void:
	var th := thresholds("correo")
	var steps_all: Array[int] = []
	var times_all: Array[float] = []
	for i in TH_KEYS.size():
		if th.has(TH_KEYS[i]):
			steps_all.append(i + 1)
			times_all.append(limit + (float(th[TH_KEYS[i]]) - k0) * 60.0)
	var plan := _apply_marks("correo", steps_all, times_all)
	var steps: Array = plan["steps"]
	_run["correo"] = {"t": limit, "steps": steps, "times": plan["times"], "i": 0, "info": {"marcas": int(plan["marcas"])}}
	_excuse_open = int(steps[0]) == Step.LLAMADO


func _on_contact_ended(_c: Dictionary, _resolved: bool, _angry: bool) -> void:
	_excuse_open = false
	_end("correo")


func _on_contact_outcome(_c: Dictionary, outcome: String, _csat: int) -> void:
	if outcome != "perdido" or not GameState.logged_in or Checkpoints.dying:
		return
	var n := int(counters.get("perdidas", 0)) + 1
	counters["perdidas"] = n
	var p := _pista("llamadas_perdidas")
	var step := Step.NADA
	if n >= int(p.get("persecucion_n", 4)):
		step = Step.PERSECUCION
	elif n >= int(p.get("ww_n", 3)):
		step = Step.WW
	elif n >= int(p.get("verbal_n", 2)):
		step = Step.VERBAL
	elif n >= int(p.get("llamado_n", 1)):
		step = Step.LLAMADO
	if step == Step.NADA or step_of("llamadas_perdidas") >= Step.PERSECUCION:
		return
	_fire("llamadas_perdidas", step, {"n": n})


func _on_ezlak_post(channel: String, author: String, text: String, meta: Dictionary) -> void:
	if not GameState.logged_in:
		return
	# Lista de allocations del Mentor (P4): Shero se entera del Available SOLO aquí (Joan, J #40).
	if str(meta.get("tipo", "")) == "allocations" and author == "mentor":
		if not bool(meta.get("evaluable", false)) or not bool(meta.get("bajo_target", false)) or Checkpoints.dying:
			return
		if is_lunch_immune("shero_lista"):
			_lunch_list_meta = meta.duplicate()  # v0.3.2: Shero la lee al volver del lunch (escalonado)
			return
		# v0.3.2-core: en «Reconectando», en la gracia del respawn y en la calma nadie convoca (Reconexion, regla 2):
		# Shero tampoco lee la lista. Antes una lista que salía justo al reaparecer subía un escalón y, con dos listas
		# malas a cuestas, te mandaba la persecución con el AUX todavía en «Reconectando».
		if Metrics.reconnecting or Checkpoints.in_respawn_grace() or GameState.in_calm:
			return
		var n := int(counters.get("listas_bajo", 0)) + 1
		counters["listas_bajo"] = n
		var p := _pista("available")
		var step := Step.NADA
		if n >= int(p.get("persecucion_n", 3)):
			step = Step.PERSECUCION
		elif n >= int(p.get("ww_n", 2)):
			step = Step.WW
		elif n >= int(p.get("verbal_n", 1)):
			step = Step.VERBAL
		if step != Step.NADA and step_of("available") < Step.PERSECUCION:
			_fire("available", step, {"n": n, "pct": float(meta.get("jugador_pct", Metrics.available_pct()))})
		return
	# "No hay breaks." cada vez que alguien (un compañero) aparece en Break en #allocations.
	if EzlakHub.normalize(channel) == "#allocations" and author == "rta" and text.containsn("break"):
		await get_tree().create_timer(2.5).timeout
		if GameState.running and GameState.logged_in:
			_say("lema", "allocations", {})


func _on_quick_reply(channel: String, reply_id: String) -> void:
	if not reply_id.begins_with("excusa_") or not _excuse_open or not _run.has("correo"):
		return
	_excuse_open = false
	var correct := int(DataLoader.bal("correo_bo/excusa_correcta", 2))
	if int(reply_id.substr(7)) == correct:
		_say("correo", "excusa_ok", {})
		return
	_say("correo", "excusa_mal", {})
	# La excusa equivocada salta directo al Verbal (escalada.json/correo/excusa_equivocada).
	var r: Dictionary = _run["correo"]
	var i := int(r["i"])
	if i < (r["steps"] as Array).size() and int(r["steps"][i]) == Step.VERBAL:
		r["i"] = i + 1
		_fire("correo", Step.VERBAL)
	if channel == "":
		pass


func _on_coaching_requested(seconds: float) -> void:
	_rooms_left = seconds
	_rooms_from = "shero"
	await get_tree().process_frame
	var hub := _hub()
	if hub != null:
		_rooms_from = hub.rooms_from


func _rooms_expired() -> void:
	if _rooms_from == "haime" or not GameState.logged_in:
		return  # el feedback de Haime que no atiendes lo castiga Haime (P5, qa_inasistencia)
	var track := "coaching_noshow_rasec" if _rooms_from == "rasec" else "coaching_noshow"
	# El link sigue abierto: unirte tarde corta la escalera.
	var hub := _hub()
	if hub != null:
		hub.rooms_pending = true
		hub.rooms_left = 1.0e9
		hub.rooms_from = _rooms_from
	_start(track, 0.0, {"de": _rooms_from})


func _on_coaching_joined() -> void:
	_rooms_left = -1.0
	_end("coaching_noshow")
	_end("coaching_noshow_rasec")
	(counters["por_pista"] as Dictionary).erase("coaching_noshow")
	var hub := _hub()
	if hub != null:
		hub.rooms_left = 0.0
	if _rooms_from in ["shero", "rasec"] and not _session_active:
		_coaching_session(_rooms_from)


## Sesión de coaching autorizada (~60 s reales = 5 min de juego, reloj coaching_sesion): de Shero (fuente
## "shero") o de Rasec (fuente "tm", la del Team Manager; líneas coaching_sesion_rasec). Congela todas las
## pistas; al terminar, si sigues en Coaching corre "coaching excedido" (Rasec). La fuente "tm" es también la del
## evento de Rasec (P5): si hay una autorización "tm" en curso, la sesión espera a que termine (no la pisa).
func _coaching_session(by: String = "shero") -> void:
	_session_token += 1
	var token := _session_token
	var track := "coaching_sesion_rasec" if by == "rasec" else "coaching_sesion"
	var source := "tm" if by == "rasec" else "shero"
	if GameState.in_contact:
		_say(track, "espera_llamada", {})
		await EventBus.contact_ended
		if token != _session_token:
			return
	while source == "tm" and not Metrics.authorization_of("tm").is_empty():
		await EventBus.authorization_ended
		if token != _session_token:
			return
	_session_active = true
	_coach_auth_seen = true
	Metrics.authorize(Metrics.Aux.COACHING, source, "sala", -1.0)
	if Metrics.aux != Metrics.Aux.COACHING:
		Metrics.set_aux(Metrics.Aux.COACHING)
	freeze(true, "coaching_autorizado")
	GameState.set_clock_override("coaching_sesion")
	EventBus.discipline_step.emit("coaching_sesion", Step.NADA, {"ejecutor": by, "de": by, "sesion": "inicio"})
	var lines := _lines(track, "lineas")
	var each := (18.0 if GameState.is_tutorial() else 60.0) / maxf(1.0, float(lines.size()))  # P6b: Inducción, sesión corta
	var vars := _vars(track, {})
	for msg in lines:
		if token != _session_token or not is_inside_tree():
			return
		_emit_msg(track, "lineas", msg, vars)
		await get_tree().create_timer(each).timeout
	if token != _session_token:
		return
	_say(track, "fin", vars)
	GameState.clear_clock_override("coaching_sesion")
	freeze(false, "coaching_autorizado")
	_session_active = false
	Metrics.revoke(source)
	EventBus.discipline_step.emit("coaching_sesion", Step.NADA, {"ejecutor": by, "de": by, "sesion": "fin"})
	_on_state_changed()


func session_active() -> bool:
	return _session_active


func _on_authorization_ended(source: String) -> void:
	if source == "topico" and not GameState.in_room and GameState.logged_in and not Checkpoints.dying:
		_start("topico_excedido", 0.0)
	_on_state_changed()


func _on_topico_requested() -> void:
	if not GameState.logged_in or Checkpoints.dying or not owns_track("topico"):
		return
	var n := int(counters.get("topico", 0)) + 1
	counters["topico"] = n
	if n == 1:
		_say("topico", "permiso", {})
		Metrics.authorize(-1, "topico", "topico", float(_pista("topico").get("permiso_min", 15)) * Difficulty.scale("plazos"))
		EventBus.discipline_step.emit("topico", Step.NADA, {"ejecutor": "shero", "permiso": true, "n": 1})
		return
	_fire("topico", Step.PERSECUCION, {"n": n})


func _on_training_ended(passed: bool) -> void:
	freeze(false, "training")
	if passed:
		_training_released()


## El Trainer te suelta (P5: PersonajesP5.training_released, o EventBus.training_ended(true)): desde ahí corre la
## vuelta tardía a la sala (8/11/14). Las dos señales llegan juntas: la pista arranca una sola vez.
func _training_released() -> void:
	if GameState.logged_in and not _in_room() and not Checkpoints.dying:
		_start("training_regreso", 0.0)


## Engancha training_released del cerebro de P5 cuando aparece (vive bajo World; se crea con cada turno).
func _hook_p5() -> void:
	if is_instance_valid(_p5_hub) or not is_inside_tree():
		return
	var hub := get_tree().get_first_node_in_group("p5_personajes")
	if hub == null:
		return
	_p5_hub = hub
	if hub.has_signal("training_released") and not hub.is_connected("training_released", _training_released):
		hub.connect("training_released", _training_released)


func _on_ack_given() -> void:
	(counters["por_pista"] as Dictionary).erase("ww_ack")
	if presence != null and not Pursuit.is_hunting("shero"):
		presence.call("ack_ok")


## WW sin Ack → persecución (ya no muerte instantánea). Si el WW era del lunch y estás dormido en el -1, la
## persecución es la del lunch (Shero te encuentra dormido y te perdona, una vez por turno).
func _on_ack_expired() -> void:
	if not GameState.logged_in or Checkpoints.dying or GameState.is_tutorial():
		return  # P6b: en la Inducción el Ack vencido se explica y se repite (Tutorial), nadie persigue
	(counters["por_pista"] as Dictionary)["ww_ack"] = Step.PERSECUCION
	_say("ww_ack", "persecucion", {})
	EventBus.discipline_step.emit("ww_ack", Step.PERSECUCION, {"ejecutor": "shero", "causa": "ww_sin_ack", "motivo": Metrics.ack_reason})
	_hunt("ww_ack", "shero", "ww_sin_ack", "")


## Tres molestos seguidos en 20 min: T1 WW; desde T2, muerte directa.
func _on_angry_streak(count: int) -> void:
	if count < int(DataLoader.bal("molestos/seguidos", 3)) or not GameState.logged_in or Checkpoints.dying:
		return
	Metrics.angry_streak.clear()
	if GameState.turno >= 2:
		EventBus.discipline_step.emit("tres_molestos", Step.PERSECUCION, {"ejecutor": "shero", "causa": "tres_molestos"})
		Checkpoints.request_death("tres_molestos", "", "shero")
		return
	_say("tres_molestos", "ww", {})
	_issue_ww("tres_molestos")
	EventBus.discipline_step.emit("tres_molestos", Step.WW, {"ejecutor": "shero", "causa": "tres_molestos"})


## Avisos del lunch: 5 min antes de la hora; al ponerlo (a tiempo o fuera de hora).
func _lunch_reminder(now: float) -> void:
	if not GameState.logged_in or Checkpoints.dying:
		return
	var avisos: Array = counters.get("lunch_avisos", [])
	var l := GameState.lunch_clock()
	if not avisos.has("hora") and now >= l - 5.0 * 60.0 and now < l and Metrics.aux != Metrics.Aux.LUNCH:
		avisos.append("hora")
		_say("lunch", "hora", _vars("lunch", {}))
	if Metrics.aux == Metrics.Aux.LUNCH and not avisos.has("inicio"):
		avisos.append("inicio")
		_say("lunch", "fuera_hora" if now < l - 5.0 * 60.0 else "inicio", _vars("lunch", {}))
	counters["lunch_avisos"] = avisos


# --- v0.3.2: lunch inmune -------------------------------------------------------------------------

## ¿El jugador está en su lunch (AUX Lunch, el primero del turno y dentro de su cupo de 45 min de juego) o en la gracia
## de después? Mientras tanto nadie lo convoca (calibración, coaching/Rooms, evento de Rasec, training, allocation del
## Mentor, recordatorio de Vitzo, escalera de Shero) ni sale una persecución nueva. Lo que se aplazó sale después de la
## gracia y escalonado. Excepciones: una persecución o convocatoria que ya venía de antes sigue (no se toca), y la
## escalera del propio lunch (>45 min) corre igual: pasado el cupo la inmunidad se acaba.
## `quien` (opcional) = el que pregunta: queda en la fila de aplazados y se suelta en su turno. Sin `quien`, solo dice
## si hay inmunidad ahora (el primero en salir tras la gracia, p. ej. Haime vía PersonajesP5.can_interrupt()).
func is_lunch_immune(quien: String = "") -> bool:
	if not GameState.running or not GameState.logged_in or GameState.shift_over or GameState.is_tutorial():
		return false
	if _lunch_active() or _lunch_grace_left > 0.0:
		if quien != "" and not _lunch_deferred.has(quien):
			_lunch_deferred.append(quien)
		return true
	if quien != "" and _lunch_since_release >= 0.0:
		var i := _lunch_deferred.find(quien)
		if i >= 0 and _lunch_since_release < float(i + 1) * float(DataLoader.bal("lunch_inmune/escalonado_s", 40.0)):
			return true
	return false


## Lunch en curso, a su hora (la ventana del lunch o la orden del RTA) y dentro del cupo; el primero del turno: un
## 2.º lunch o uno fuera de hora no son inmunes (ahí siguen las reglas del lunch y del RTA).
func _lunch_active() -> bool:
	if Metrics.aux != Metrics.Aux.LUNCH or bool(counters.get("lunch_inmune_usado", false)):
		return false
	if _lunch_started_at < 0.0:
		_lunch_started_at = Metrics.aux_since  # tras reaparecer en el lunch
		_lunch_legit = bool(GameState.flags.get("p5_lunch_hecho", false)) or _lunch_on_time(Metrics.aux_since)
	if not _lunch_legit:
		return false
	return GameState.clock_seconds - _lunch_started_at < GameState.lunch_minutes() * 60.0


func lunch_grace_left() -> float:
	return _lunch_grace_left


func _on_aux_lunch(new_aux: int, old_aux: int) -> void:
	if new_aux == Metrics.Aux.LUNCH:
		_lunch_started_at = GameState.clock_seconds
		_lunch_legit = _lunch_on_time(GameState.clock_seconds) or Metrics.expected_aux == Metrics.Aux.LUNCH
		return
	if old_aux != Metrics.Aux.LUNCH or bool(counters.get("lunch_inmune_usado", false)) or not _lunch_legit:
		_lunch_started_at = -1.0
		return
	var within := _lunch_started_at >= 0.0 and _lunch_legit and GameState.clock_seconds - _lunch_started_at < GameState.lunch_minutes() * 60.0
	counters["lunch_inmune_usado"] = true
	_lunch_started_at = -1.0
	if within and GameState.logged_in:
		_lunch_grace_left = float(DataLoader.bal("lunch_inmune/gracia_s_real", 90.0))
	_lunch_since_release = -1.0 if within else 0.0


var _lunch_started_at: float = -1.0
var _lunch_legit: bool = false


## ¿Empieza a su hora? (la misma ventana que usa el RTA: hora del lunch −5 … +15 min de juego).
func _lunch_on_time(at: float) -> bool:
	var l := GameState.lunch_clock()
	return at >= l - float(DataLoader.bal("lunch/ventana_antes_min", 5.0)) * 60.0 and at < l + float(DataLoader.bal("lunch/ventana_despues_min", 15.0)) * 60.0


func _tick_lunch_immunity(delta: float) -> void:
	if _lunch_grace_left > 0.0:
		_lunch_grace_left -= delta
		if _lunch_grace_left <= 0.0:
			_lunch_grace_left = 0.0
			_lunch_since_release = 0.0
	elif _lunch_since_release >= 0.0:
		_lunch_since_release += delta
		if not _lunch_list_meta.is_empty() and not is_lunch_immune("shero_lista") and GameState.logged_in and not Checkpoints.dying:
			var m := _lunch_list_meta
			_lunch_list_meta = {}
			_on_ezlak_post("#team-familia", "mentor", "", m)
		if _lunch_since_release > float(_lunch_deferred.size() + 1) * float(DataLoader.bal("lunch_inmune/escalonado_s", 40.0)) and _lunch_list_meta.is_empty():
			_lunch_since_release = -1.0
			_lunch_deferred.clear()
	elif Metrics.aux == Metrics.Aux.LUNCH and not _lunch_active() and not _lunch_deferred.is_empty():
		_lunch_since_release = 0.0  # se pasó del cupo sin soltar el lunch: lo aplazado sale ya, escalonado


func _lunch_reset_runtime() -> void:
	_lunch_grace_left = 0.0
	_lunch_deferred.clear()
	_lunch_since_release = -1.0
	_lunch_list_meta = {}
	_lunch_started_at = -1.0


# --- Pruebas -------------------------------------------------------------------------------------

## Abre una pista a mano con t0 segundos ya transcurridos (escenarios).
func debug_start(track: String, t0: float = 0.0) -> void:
	if track == "correo":
		return
	_start(track, t0)


## Fuerza un escalón (escenarios y capturas).
func debug_fire(track: String, step: int, extra: Dictionary = {}) -> void:
	_fire(track, step, extra)


func debug_run() -> Dictionary:
	return _run.duplicate(true)

class_name ContactManager
extends Node
## Cola de contactos del turno (v0.3, PLAN §2 #3/#21-24, §5, §6): llamadas y chats como árboles de diálogo
## (data/contactos_tN.json, motor DialogTree) y casos de BO (data/casos_bo.json: correos con trabajo real,
## casos de correo de Vitzo y KYC). Cada contacto entra a su `hora_juego`:
##   · llamada / chat / correo → se ofrecen en AUX Available; KYC → solo en AUX BO.
##   · Una llamada o chat que suena y no contestas (de pie, en otra silla, mirando a otro lado) se PIERDE a los
##     reglas/timbre_s_real segundos: contact_outcome(c, "perdido", 0) y missed_count + 1 (pista
##     "llamadas_perdidas" de P3; si Discipline aún no la implementa, la escalera mínima de abajo).
##   · Un caso de BO nunca se pierde: se ofrece solo sentado en tu sesión y queda abierto hasta que lo cierres.
## El relleno (relleno[] del JSON) entra entre guiones, espaciado por el Director. v0.3.1 Q4 (F13): cada turno trae
## 6 árboles de relleno propios (con "nodos"); se barajan con la semilla de la partida y no se repiten dentro del
## turno. v0.3.2-core2: si se agotan sigue el relleno de los turnos anteriores y, después, otra vuelta con el cliente
## de otro humor (_build_pool, _filler); al repetir un tramo (reaparecer, «Reiniciar contacto», «Continuar») cada
## contacto que ya atendiste deja un hueco a su hora y entra un sustituto (ver «Repetir un tramo», más abajo).
## El formato viejo {id, ref} (reusar un guion) sigue valiendo.
##
## API para la PC (apps) y las pruebas: accept(), choose(i), toggle_hold(); portal_search(tx) /
## portal_download_pod() / portal_attach_pod() / portal_reversal() / portal_contact() / open_mailto_vitzo();
## kardex_lookup(tx); set_recipient / set_template / set_field / set_attach / send_email(); composer_send() /
## composer_cancel() (correo que abre un árbol); set_typification(); close_case(); kyc_decide(accion).
## Señales (EventBus): contact_offered · contact_accepted · dialog_node(id, nodo) · contact_ended ·
## contact_outcome(c, "satisfecho|neutral|molesto|perdido|bo_ok|bo_miss", csat) · email_timer_tick ·
## email_over_time · email_sent · vitzo_portal_action(case_id, accion) · hold_changed · scripted_event.

signal changed()  # algo del contacto actual cambió (la PC se redibuja)
signal app_requested(app: String)  # el contacto pide abrir una app ("kardex" | "correo" | "identa" | "portal")

enum Phase { IDLE, OFFERING, ACTIVE }

const TRACK_MISSED := "llamadas_perdidas"
## Causas que pide el respaldo de llamadas perdidas (PLAN §2 #24; P2 las añade a muertes.json).
var missed_death_cause: String = "llamadas_perdidas"

var phase: int = Phase.IDLE
var current: Dictionary = {}
var tree: DialogTree = null
var case: CasoBO = null
var composer: Dictionary = {}  # correo abierto por un árbol: {to, tpl, muerte, cuerpo}
var on_hold: bool = false
var missed_count: int = 0
var ring_left: float = 0.0
var chat_left: float = 0.0  # segundos de juego que le quedan al nodo de chat
var email_elapsed: float = 0.0
var email_over_reported: bool = false
var filler_count: int = 0
var portal_view: Dictionary = {}  # última búsqueda en el Portal Vitzo {tx, ...datos}
var _schedule: Array = []  # contactos guionizados del turno (árboles + casos BO) ordenados por hora
var _served: Array[String] = []
var _start_clock: float = 0.0
var _offer_clock: float = 0.0
var _offer_wait: float = 0.0
var _min_gap: float = 0.0
var _filler_per_block: Dictionary = {}
var _last_clock: float = 0.0
var _filler_rng := RandomNumberGenerator.new()
var _data_name: String = "contactos_t1"
var _bo_filler_used: bool = false
var _sol_n: int = 5500
var _suspend_chat: bool = false
var _filler_order: Array[int] = []  # baraja del relleno del turno (índices de relleno[])
var _filler_next: int = 0
var filler_served: Array[String] = []  # ids de relleno servidos en el turno (pruebas: sin repetir)
## v0.3.1 Q4 (F13, Joan 11:43Z): cada turno tiene una BOLSA de 15-20 árboles (guionizados + relleno). Cuántos
## contactos con árbol te tocan sale de contactos_por_turno[dificultad] (rango) del JSON del turno: los "fijos"
## (historia: cadenas, Vitzo, los que vuelven) siempre; el resto se sortea sin repetir entre los guionizados
## opcionales (a su hora) y el relleno (cuando la cola está libre). Semilla: agente + turno + dificultad + partida.
var planned_total: int = 0  # contactos con árbol que el turno quiere servir (pruebas e informe)
var filler_quota: int = -1  # relleno que falta servir en el turno (-1 = reglas viejas de balance.json)
var _planned_scripted: Array[String] = []
## v0.3.1 Q4 (F16): campo activo del correo (id | monto | fecha); un clic en un valor de Kardex lo copia aquí.
var mail_active_field: String = "id"
## v0.3.2 (Joan, «como un call center real»): cola de KipuPay con los 4 compañeros como agentes (ColaACD).
var acd: ColaACD = null
var _b2b_next: bool = false  # el próximo contacto entra en racha (pausa corta)
## v0.3.2-core2: repetir un tramo (ver «Repetir un tramo» más abajo).
var _life: Array = []  # contactos aceptados desde el último checkpoint: {id, t, relleno, slot, fuera, kyc, desborde, fin}
var _slots: Array = []  # huecos de sustituto: {uid, t (reloj de juego en que te entra), hecho, de}
var _slot_uid: int = 0
var _attended: Dictionary = {}  # guiones que TÚ atendiste hasta el final (id → true): no vuelven a llamar
var _last_base: String = ""  # último árbol de relleno que salió (nunca el mismo dos veces seguidas)
var _pool: Array = []  # bolsa de relleno ampliada: [{c: árbol, arq: su arquetipo, propio: bool}]
var _starve_s: float = 0.0  # segundos reales libre en Available con gente esperando en la cola
var sub_count: int = 0  # sustitutos que entraron (pruebas e informe)
## v0.3.2-core3: hasta dónde llegaste en el turno (reloj de juego) y hasta dónde llega el tramo que estás repitiendo.
## Mientras el reloj va por detrás de `_repeat_until` repites algo ya jugado: lo que entra ahí y no es ni un guion ni
## un sustituto es un contacto «de más» (repeating(), extra_count).
var _seen_clock: float = NO_CLOCK
var _repeat_until: float = NO_CLOCK
var extra_count: int = 0  # contactos «de más» que entraron al repetir un tramo (pruebas e informe)
const NO_CLOCK := -1.0e9
var overflow_count: int = 0  # contactos que entraron por «la cola no se queda parada» (pruebas e informe)


func _data() -> Dictionary:
	return DataLoader.dict(_data_name)


## v0.3.1 (integración): árboles con `solo_dificil` solo entran en Difícil y Turno real (la bolsa crece con la
## dificultad: Fácil/Normal T1 15 · T2 16 · T3 18; Difícil/Turno real T1 16 · T2 17 · T3 20).
static func eligible(c: Dictionary) -> bool:
	if not bool(c.get("solo_dificil", false)):
		return true
	return GameState.is_real_mode() or Difficulty.level >= Difficulty.Level.DIFICIL


## Relleno del turno que entra en el sorteo con la dificultad actual.
func _fillers() -> Array:
	return (_data().get("relleno", []) as Array).filter(func(c: Variant) -> bool: return eligible(c as Dictionary))


func _rules() -> Dictionary:
	return DataLoader.dict("casos_bo").get("reglas", {})


func _ready() -> void:
	add_to_group("contact_manager")
	acd = ColaACD.new()
	acd.name = "ColaACD"
	acd.cm = self
	add_child(acd)
	EventBus.aux_changed.connect(_on_aux_changed)
	_filler_rng.seed = 14
	EventBus.clock_tick.connect(_on_clock_tick)
	EventBus.player_stood_up.connect(_on_player_stood_up)
	EventBus.respawned.connect(_on_respawned)
	EventBus.checkpoint_saved.connect(_on_checkpoint_saved)
	EventBus.shift_started.connect(_reset)
	EventBus.allocation_posted.connect(func(_a: int, _c: float, _u: float) -> void: _bo_filler_used = false)
	_reset()
	_rewind(true)  # «Continuar»: el mundo se arma después de restaurar el checkpoint
	_ensure_services.call_deferred()


## El Mentor publica la lista de allocations en todos los turnos (PLAN §2 #40): si Main no lo creó (v0.2 solo
## lo creaba en T3), lo crea aquí.
func _ensure_services() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	if get_tree().get_first_node_in_group("mentor") == null:
		var m := Mentor.new()
		m.name = "Mentor"
		m.add_to_group("mentor")
		get_parent().add_child(m)


func _reset() -> void:
	_data_name = str(GameState.turno_cfg("contactos", "contactos_t1"))
	if not FileAccess.file_exists(DataLoader.DATA_DIR + _data_name + ".json"):
		_data_name = "contactos_t1"
	_schedule.clear()
	_plan_shift()
	for c in _data().get("contactos", []):
		if _planned_scripted.is_empty() or _planned_scripted.has(str(c.get("id", ""))):
			_schedule.append(c)
	var bo: Dictionary = DataLoader.dict("casos_bo").get("turnos", {})
	for c in bo.get(str(GameState.turno), []):
		_schedule.append(c)
	_schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return clock_of(str(a.get("hora_juego", "00:00"))) < clock_of(str(b.get("hora_juego", "00:00"))))
	_served.clear()
	phase = Phase.IDLE
	current = {}
	tree = null
	case = null
	composer = {}
	portal_view = {}
	_clear_hold()
	missed_count = 0
	filler_count = 0
	_bo_filler_used = false
	_filler_per_block.clear()
	_life.clear()
	_slots.clear()
	_slot_uid = 0
	_attended.clear()
	_last_base = ""
	_starve_s = 0.0
	sub_count = 0
	overflow_count = 0
	extra_count = 0
	_seen_clock = NO_CLOCK
	_repeat_until = NO_CLOCK
	_min_gap = 3.0
	_offer_wait = _filler_interval()
	GameState.queue_size = 0
	if acd != null:
		acd.reset()


static func clock_of(hhmm: String) -> float:
	var parts := hhmm.split(":")
	if parts.size() != 2:
		return 0.0
	return float(int(parts[0]) * 3600 + int(parts[1]) * 60)


static func is_tree(c: Dictionary) -> bool:
	return c.has("nodos")


static func is_bo(c: Dictionary) -> bool:
	return str(c.get("canal", "")) in ["correo", "kyc"]


## Próximo guion pendiente (cualquiera) — para el Director y el relleno.
func next_scripted() -> Dictionary:
	for c in _schedule:
		if not _served.has(str(c.get("id", ""))):
			return c
	return {}


## Guion pendiente cuya hora llegó y que puede entrar con el AUX actual.
func _due_for(aux: int) -> Dictionary:
	for c in _schedule:
		var id := str(c.get("id", ""))
		if _served.has(id) or GameState.clock_seconds < clock_of(str(c.get("hora_juego", "00:00"))):
			continue
		var kyc := str(c.get("canal", "")) == "kyc"
		if (kyc and aux == Metrics.Aux.BO) or (not kyc and aux == Metrics.Aux.AVAILABLE):
			return c
	return {}


## Un contacto que entra sin pausa corta (no en racha) empieza la cuenta de nuevo.
func _b2b_mark() -> void:
	if acd != null and not _b2b_next:
		acd.b2b_streak = 0
	_b2b_next = false


func _filler_interval() -> float:
	var level := 0
	var director := get_tree().get_first_node_in_group("director") as Director if is_inside_tree() else null
	if director != null:
		level = director.level()
	var table: Dictionary = DataLoader.bal("cola/relleno_espera_real_s", {})
	var rng: Array = table.get(str(level), [45.0, 75.0])
	return randf_range(float(rng[0]), float(rng[1]))


func _filler_allowed() -> bool:
	var block := GameState.current_block()
	if filler_quota >= 0:
		# v0.3.1 Q4: el cupo del sorteo manda; se reparte por bloques (un bloque puede adelantar uno del siguiente).
		if filler_quota == 0:
			return false
		var served_total := 0
		for b in _filler_per_block.values():
			served_total += int(b)
		var per := ceili(float(served_total + filler_quota) / 3.0)
		if int(_filler_per_block.get(block, 0)) >= per + 1:
			return false
		var nxt0 := next_scripted()
		if not nxt0.is_empty():
			var margin0 := float(DataLoader.bal("cola/relleno_margen_guion_s_juego", 480.0)) * 0.6
			if clock_of(str(nxt0.get("hora_juego", "00:00"))) - GameState.clock_seconds < margin0:
				return false
		return true
	var max_per: Dictionary = DataLoader.bal("cola/relleno_max_por_bloque", {})
	if int(_filler_per_block.get(block, 0)) >= int(max_per.get(str(block), 2)):
		return false
	var nxt := next_scripted()
	if not nxt.is_empty():
		var margin := float(DataLoader.bal("cola/relleno_margen_guion_s_juego", 480.0))
		if clock_of(str(nxt.get("hora_juego", "00:00"))) - GameState.clock_seconds < margin:
			return false
	if block >= 3:
		var director := get_tree().get_first_node_in_group("director") as Director
		if director != null and director.level() < int(DataLoader.bal("cola/relleno_bloque3_nivel_min", 2)):
			return false
	return true


## Sentado en la silla de tu sesión (la que tiene tu login).
func player_ready() -> bool:
	if not GameState.logged_in or GameState.seated_at == "":
		return false
	var floor_node := get_tree().get_first_node_in_group("floor") as FloorBase
	if floor_node == null:
		return false
	var seat := floor_node.seat_by_id(GameState.seated_at)
	return seat != null and seat.has_session


func _process(delta: float) -> void:
	if not GameState.running or GameState.shift_over or get_tree().paused:
		return
	match phase:
		Phase.IDLE:
			_tick_idle(delta)
		Phase.OFFERING:
			_tick_offer(delta)
		Phase.ACTIVE:
			_tick_active(delta)


func _tick_idle(delta: float) -> void:
	if not GameState.logged_in or Checkpoints.dying:
		return
	if Metrics.reconnecting:
		return  # v0.3.2: «Reconectando» tras reaparecer: no te ofrecen nada (ni cuenta como perdido)
	var aux := Metrics.aux
	var ready := player_ready()
	var due := _due_for(aux)
	_min_gap -= delta
	if aux != Metrics.Aux.AVAILABLE and acd != null:
		acd.b2b_streak = 0
		_b2b_next = false
	if _min_gap > 0.0:
		return
	if aux == Metrics.Aux.AVAILABLE:
		if not due.is_empty():
			# Los casos BO solo se ofrecen sentado; las llamadas y chats suenan igual (y se pierden).
			if is_bo(due) and not ready:
				return
			_b2b_mark()
			_offer(due.duplicate(true))
			return
		if not ready:
			return  # el relleno solo entra con el jugador sentado (no fabrica llamadas perdidas)
		# v0.3.2-core2: un hueco del tramo que repites: entra el sustituto de un contacto que ya atendiste.
		var si := _slot_due()
		if si >= 0:
			var sub := _filler()
			var slot: Dictionary = _slots[si]
			slot["hecho"] = true  # sin relleno en este turno no hay con qué sustituir: el hueco no se queda en la cola
			if not sub.is_empty():
				sub["sustituto"] = true
				sub["_slot"] = int(slot.get("uid", -1))
				sub_count += 1
				_b2b_mark()
				_offer(sub)
				return
		_offer_wait -= delta
		# v0.3.2: con la cola cargada al volver a Available los contactos llegan seguidos (back-to-back, con tope).
		var b2b := acd != null and filler_quota != 0 and (_b2b_next or (acd.b2b_streak == 0 and acd.back_to_back()))
		if (_offer_wait <= 0.0 and _filler_allowed()) or b2b:
			var f := _filler()
			if f.is_empty():
				_offer_wait = _filler_interval()
				return
			if acd != null:
				acd.took_from_queue()
				if b2b:
					f["back_to_back"] = true
			_mark_extra(f)
			_b2b_mark()
			var block := GameState.current_block()
			_filler_per_block[block] = int(_filler_per_block.get(block, 0)) + 1
			filler_count += 1
			if filler_quota > 0:
				filler_quota -= 1
			_offer(f)
		elif _starving(delta):
			# v0.3.2-core2: gente esperando, tú libre: te entra uno aunque el cupo del turno ya se haya servido.
			var extra_f := _filler()
			if extra_f.is_empty():
				return
			acd.took_from_queue()
			extra_f["desborde"] = true
			overflow_count += 1
			_mark_extra(extra_f)
			_b2b_mark()
			_offer(extra_f)
	elif aux == Metrics.Aux.BO and ready:
		if not due.is_empty():
			_offer(due.duplicate(true))
		elif Metrics.allocation_aux == Metrics.Aux.BO and not _bo_filler_used and not _kyc_soon(25.0 * 60.0):
			var pool: Array = DataLoader.dict("casos_bo").get("relleno_kyc", [])
			if not pool.is_empty():
				_bo_filler_used = true
				var k: Dictionary = (pool[(filler_count + GameState.turno) % pool.size()] as Dictionary).duplicate(true)
				k["id"] = str(k.get("id", "kyc")) + "_%d" % (filler_count + 1)
				k["relleno"] = true
				filler_count += 1
				_offer(k)


## ¿Hay un KYC guionizado pendiente que entra dentro de `within` segundos de juego? (el relleno no lo pisa)
func _kyc_soon(within: float) -> bool:
	for c in _schedule:
		if str(c.get("canal", "")) == "kyc" and not _served.has(str(c.get("id", ""))):
			if clock_of(str(c.get("hora_juego", "00:00"))) - GameState.clock_seconds <= within:
				return true
	return false


func _tick_offer(delta: float) -> void:
	if is_bo(current):
		return  # un caso BO espera a que lo abras (no se pierde)
	ring_left -= delta
	var ignore_s := float(current.get("ignorar_s_juego", 0.0))
	if ring_left <= 0.0 or (ignore_s > 0.0 and GameState.clock_seconds - _offer_clock >= ignore_s):
		_miss()


func _on_clock_tick(game_seconds: float) -> void:
	if not Checkpoints.dying:
		_seen_clock = maxf(_seen_clock, game_seconds)
	var dt := game_seconds - _last_clock
	_last_clock = game_seconds
	if phase != Phase.ACTIVE or dt <= 0.0 or dt > 3600.0:
		return
	if case != null:
		email_elapsed += dt
		var limit := float(current.get("limite_s_juego", _rules().get("limite_s_juego", 600.0)))
		EventBus.email_timer_tick.emit(limit - email_elapsed)
		if email_elapsed > limit and not email_over_reported:
			email_over_reported = true
			EventBus.email_over_time.emit(str(current.get("id", "")), email_elapsed)
	elif tree != null and str(current.get("canal", "")) == "chat" and not on_hold and not tree.waiting_action() and not _suspend_chat and not composing():
		chat_left -= dt
		if chat_left <= 0.0 and current.has("timeout"):
			tree.force_final(str((current.get("timeout", {}) as Dictionary).get("fin", "")))
			_after_tree_step()


func _offer(c: Dictionary) -> void:
	current = c
	phase = Phase.OFFERING
	_starve_s = 0.0
	_offer_clock = GameState.clock_seconds
	ring_left = float(_rules().get("timbre_s_real", 14.0)) * Difficulty.scale("plazos")
	GameState.queue_size = 1
	var required := Metrics.Aux.BO if str(c.get("canal", "")) == "kyc" else Metrics.Aux.AVAILABLE
	PerritoRTA.dictate(required)
	AudioManager.play_sfx("auricular_pitido", "Auricular")
	EventBus.contact_offered.emit(c)
	changed.emit()


## v0.3 P6b (Inducción): ofrece YA un contacto armado por fuera del guion del turno (árbol o caso BO). Solo
## con la cola libre; true si lo ofreció. El contacto no entra en la lista de guiones servidos del turno.
func offer_now(c: Dictionary) -> bool:
	if phase != Phase.IDLE or c.is_empty() or not GameState.logged_in:
		return false
	var d := c.duplicate(true)
	d["relleno"] = true  # no cuenta como guion servido (no se repite ni se guarda en el checkpoint)
	d["_fuera"] = true  # ni deja hueco al repetir un tramo: lo ofrece quien lo armó (Inducción, prácticas)
	_offer(d)
	return true


## Sorteo del turno: rango por dificultad → total; fijos + opcionales a su hora + cupo de relleno.
func _plan_shift() -> void:
	_planned_scripted.clear()
	filler_quota = -1
	planned_total = 0
	_shuffle_fillers()
	var ranges: Dictionary = _data().get("contactos_por_turno", {})
	if ranges.is_empty():
		return
	var key := "real" if GameState.is_real_mode() else Difficulty.id()
	var rg: Array = ranges.get(key, ranges.get("normal", [10, 12]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%s|%s" % [GameState.agent, GameState.turno, key, str(SaveSlots.progress().get("creada", ""))])
	planned_total = rng.randi_range(int(rg[0]), int(rg[1]))
	var fijos: Array = _data().get("fijos", [])
	var optional: Array[String] = []
	for c in _data().get("contactos", []):
		var id := str(c.get("id", ""))
		if fijos.has(id):
			_planned_scripted.append(id)
		elif eligible(c):
			optional.append(id)
	var fillers: Array = _fillers()
	# Candidatos: opcionales (o:<id>) y relleno (f), barajados; se toman los que faltan para el total.
	var cands: Array[String] = []
	for id in optional:
		cands.append("o:" + id)
	for i in fillers.size():
		cands.append("f")
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var need := maxi(planned_total - _planned_scripted.size(), 0)
	filler_quota = 0
	for k in mini(need, cands.size()):
		if cands[k] == "f":
			filler_quota += 1
		else:
			_planned_scripted.append(cands[k].trim_prefix("o:"))


## Baraja del relleno del turno: semilla = agente + turno (la misma partida da el mismo orden; otra, otro).
func _shuffle_fillers() -> void:
	_filler_order.clear()
	_filler_next = 0
	filler_served.clear()
	var n := _fillers().size()
	for i in n:
		_filler_order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%s" % [GameState.agent, GameState.turno, _data_name])
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := _filler_order[i]
		_filler_order[i] = _filler_order[j]
		_filler_order[j] = tmp
	_build_pool(rng)


## v0.3.2-core2: la bolsa de relleno no se acaba. Primero el relleno del turno (barajado, como siempre); cuando se
## agota, el de los turnos anteriores (otros clientes, con su voz, su caso y sus números: el martes pueden volver a
## llamar los del lunes; el miércoles, los del martes y los del lunes), también barajado; y solo si todo eso se
## agota empieza otra vuelta, con el cliente de otro humor (_filler). El lunes no toma prestado de turnos
## posteriores (su relleno es de otro tono).
func _build_pool(rng: RandomNumberGenerator) -> void:
	_pool.clear()
	var own: Array = _fillers()
	var arqs: Dictionary = _data().get("arquetipos", {})
	for i in _filler_order:
		var f: Dictionary = own[i]
		_pool.append({"c": f, "arq": arqs.get(str(f.get("arquetipo", "")), {}), "propio": true})
	if own.is_empty() or GameState.is_tutorial():
		return
	for t in range(GameState.turno - 1, 0, -1):
		var file := "contactos_t%d" % t
		if file == _data_name or not FileAccess.file_exists(DataLoader.DATA_DIR + file + ".json"):
			continue
		var d: Dictionary = DataLoader.dict(file)
		var far: Dictionary = d.get("arquetipos", {})
		var borrowed: Array = []
		for c in d.get("relleno", []):
			if (c as Dictionary).has("nodos") and eligible(c):
				borrowed.append({"c": c, "arq": far.get(str((c as Dictionary).get("arquetipo", "")), {}), "propio": false})
		for i in range(borrowed.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Dictionary = borrowed[i]
			borrowed[i] = borrowed[j]
			borrowed[j] = tmp
		_pool.append_array(borrowed)


## Cuántos árboles distintos hay en la bolsa ampliada (pruebas e informe).
func pool_size() -> int:
	if _pool.is_empty() and not _fillers().is_empty():
		_shuffle_fillers()
	return _pool.size()


func _filler() -> Dictionary:
	var fillers: Array = _fillers()
	if fillers.is_empty():
		return {}
	if _filler_order.size() != fillers.size() or _pool.is_empty():
		_shuffle_fillers()
	var n := _pool.size()
	var d: Dictionary = {}
	var base := ""
	var lap := 0
	for _i in n + 1:
		lap = int(float(_filler_next) / float(n))
		var e: Dictionary = _pool[_filler_next % n]
		_filler_next += 1
		var f: Dictionary = e["c"]
		base = str(f.get("id", ""))
		if n > 1 and base == _last_base:
			continue  # nunca el mismo cliente dos veces seguidas (al dar la vuelta a la bolsa)
		if f.has("nodos"):
			d = f.duplicate(true)  # árbol propio de relleno (v0.3.1)
			d["_arq_cfg"] = (e.get("arq", {}) as Dictionary).duplicate()
		else:
			for c in _data().get("contactos", []):
				if str(c.get("id", "")) == str(f.get("ref", "")):
					d = (c as Dictionary).duplicate(true)
					break
		if d.is_empty():
			continue
		if not bool(e.get("propio", true)):
			d["prestado"] = true
		break
	if d.is_empty():
		return {}
	d["ref_id"] = str(d.get("id", base))
	d["id"] = base if lap == 0 else base + "_%d" % (lap + 1)
	d["relleno"] = true
	for k in ["hora_juego", "cadena", "ignorar_s_juego"]:
		d.erase(k)
	for nd in (d.get("nodos", {}) as Dictionary).values():
		(nd as Dictionary).erase("evento")  # el relleno no repite los eventos guionizados
	if lap > 0:
		# Otra vuelta a la bolsa: el mismo caso, pero el cliente llega de otro humor (y, al llevar otro id, lo que
		# contesta fuera de guion —IACustomer— tampoco es lo mismo). Nunca tan bajo que cuelgue de entrada.
		var vr := RandomNumberGenerator.new()
		vr.seed = hash("%s|%d|%s" % [base, lap, GameState.agent])
		var moods := [-18.0, -10.0, 8.0, 14.0]
		var mood := float(d.get("animo_inicial", 0.0))
		d["animo_inicial"] = clampf(mood + float(moods[vr.randi_range(0, moods.size() - 1)]), minf(mood, -30.0), 60.0)
		d["repetido"] = lap
	_last_base = base
	filler_served.append(base)
	return d


func accept() -> void:
	if phase != Phase.OFFERING or not player_ready():
		return
	phase = Phase.ACTIVE
	var id := str(current.get("id", ""))
	if not bool(current.get("relleno", false)) and not _served.has(id):
		_served.append(id)
	_clear_hold()
	composer = {}
	portal_view = {}
	email_elapsed = 0.0
	email_over_reported = false
	mail_active_field = "id"
	_start_clock = GameState.clock_seconds
	_last_clock = GameState.clock_seconds  # un salto de reloj previo (login) no cuenta como tiempo del caso
	tree = null
	case = null
	if not GameState.is_tutorial():
		_life.append({
			"id": id, "t": _offer_clock, "relleno": bool(current.get("relleno", false)), "slot": int(current.get("_slot", -1)),
			"fuera": bool(current.get("_fuera", false)), "kyc": str(current.get("canal", "")) == "kyc",
			"desborde": bool(current.get("desborde", false)), "de_mas": bool(current.get("de_mas", false)), "fin": false,
		})
	Checkpoints.save_checkpoint("contacto", _cp_extra())
	if Metrics.contacts_handled > 0 and Metrics.contacts_handled % 2 == 0:
		Checkpoints.save_checkpoint("contacto_par", _cp_extra())
	if is_tree(current):
		tree = DialogTree.new()
		tree.start(current)
		free_turns = 0
		if not current.has("_arq_cfg"):  # el relleno prestado de otro turno trae el suyo
			current["_arq_cfg"] = (_data().get("arquetipos", {}) as Dictionary).get(str(current.get("arquetipo", "")), {})
		_reset_chat_timer()
	else:
		case = CasoBO.new(current)
	EventBus.contact_accepted.emit(current)
	if tree != null:
		app_requested.emit("kardex")
		_on_node_entered()
	elif case.is_kyc():
		app_requested.emit("identa")
		if str(current.get("evento", "")) == "shero_en_el_reflejo":
			await get_tree().create_timer(1.5).timeout
			if phase == Phase.ACTIVE and case != null:
				EventBus.scripted_event.emit("shero_en_el_reflejo")
	else:
		app_requested.emit("correo")
	changed.emit()


## Lo que la cola guarda en un checkpoint (v0.3.2-core2: en todos, ver Checkpoints.save_checkpoint): qué guiones ya
## salieron, las perdidas, los huecos de sustituto pendientes, el ACD y lo «vivo» (_live_extra).
func _cp_extra() -> Dictionary:
	var d := {
		"cm_served": _served.duplicate(), "cm_missed": missed_count, "cm_slots": _slots_open(), "cm_uid": _slot_uid,
		"cm_acd": acd.to_save() if acd != null else {},
	}
	d.merge(_live_extra(_life_open()))
	return d


## Lo que Checkpoints añade a los checkpoints que no son de contacto. La Inducción queda como estaba (sus
## checkpoints de AUX y login nunca guardaron la cola).
func checkpoint_extra() -> Dictionary:
	return {} if GameState.is_tutorial() else _cp_extra()


func _reset_chat_timer() -> void:
	chat_left = float((current.get("timeout", {}) as Dictionary).get("s_juego", 40.0))
	compose_left = float(IACustomer.data().get("escribir_max_s_real", 25.0))


## v0.3.2 IA: mientras escribes tu respuesta (el campo del chat con foco y texto) el cliente ve «escribiendo…» y no
## se impacienta: el plazo del chat no corre. Tope: clientes.json/escribir_max_s_real segundos reales por turno
## (dejar una letra en el campo no congela el chat para siempre).
var compose_left: float = 25.0


func composing() -> bool:
	return bool(GameState.flags.get("ia_chat_escribiendo", false)) and compose_left > 0.0


func _tick_active(_delta: float) -> void:
	if bool(GameState.flags.get("ia_chat_escribiendo", false)):
		compose_left = maxf(compose_left - _delta, 0.0)
	if tree == null or GameState.flags.get("aux_menu_open", false) or GameState.flags.get("pc_text_focus", false):
		return
	for i in 4:
		if presets_allowed() and Input.is_action_just_pressed("phrase_%d" % (i + 1)):
			choose(i)
			return
	if Input.is_action_just_pressed("hold"):
		toggle_hold()


# --- v0.3.2 IA: texto libre y voz -------------------------------------------------------------------

## ¿Hay respuestas predefinidas? Fácil/Normal sí; Difícil y Turno real no (solo escribir o hablar).
static func presets_allowed() -> bool:
	if GameState.is_real_mode():
		return false
	return Difficulty.flag("respuestas_predefinidas") if (DataLoader.dict("dificultad").get("banderas", {}) as Dictionary).has("respuestas_predefinidas") else true


var free_turns: int = 0  # turnos fuera de guion en el contacto actual
var _say_override: Dictionary = {}  # tus palabras para la entrada «yo» que añade choose()
var last_say: Dictionary = {}  # pruebas: resultado del último say()


## El jugador escribió (chat) o dijo (llamada, por micrófono) `text`. Si se parece a una opción del nodo, cuenta como
## esa opción (con tus palabras en la conversación); si no, el cliente contesta en personaje (IACustomer).
## Devuelve {ok, matched, i, score, clave, respuesta}.
func say(text: String, source: String = "texto") -> Dictionary:
	var res := {"ok": false, "matched": false, "i": -1, "score": 0.0, "fuente": source}
	if phase != Phase.ACTIVE or tree == null or tree.ended() or tree.waiting_action() or bool(composer.get("arbol", false)):
		return res
	var clean := text.strip_edges().left(220)
	if clean == "":
		return res
	IACustomer.prepare(current)
	var nlu := IANlu.analyze(clean, {"dominio": "cs"})
	var m := IACustomer.match_option(tree, clean, nlu)
	res["ok"] = true
	res["score"] = m.get("score", 0.0)
	res["ranking"] = m.get("ranking", [])
	res["intent"] = nlu.get("intent", "otro")
	if not current.has("_dicho"):
		current["_dicho"] = []
	(current["_dicho"] as Array).append(clean)
	var said := {"es": clean, "en": clean}
	if int(m.get("i", -1)) >= 0:
		var i := int(m["i"])
		var o: Dictionary = tree.options()[i]
		res["matched"] = true
		res["i"] = i
		res["opcion"] = Loc.pick(o)
		_say_override = {"texto": said, "opcion": {"es": str(o.get("es", "")), "en": str(o.get("en", ""))}, "fuente": source}
		last_say = res
		choose(i)
		_say_override = {}
		return res
	# fuera de guion
	var off := IACustomer.offscript(current, tree, nlu, free_turns)
	if str(current.get("canal", "")) == "llamada" and str(off.get("audio", "")) == "" and str(tree.node().get("audio", "")) != "":
		# en una llamada solo se dice lo que tiene voz: el cliente te repite su línea del nodo (ya grabada)
		off["audio"] = str(tree.node().get("audio", "")).get_file().get_basename()
		off["texto"] = tree.client_line()
	free_turns += 1
	tree.history.append({"quien": "yo", "texto": said, "fuente": source, "fuera": true})
	tree.history.append({"quien": "cliente", "texto": off["texto"], "fuera": true})
	tree.animo = clampf(tree.animo + float(off.get("animo", 0.0)), -100.0, 100.0)
	res["clave"] = off.get("clave", "")
	res["respuesta"] = off["texto"]
	res["animo"] = tree.animo
	_suspend_chat = true
	GameState.add_game_time(float(IACustomer.data().get("t_juego_fuera", 15.0)))
	_suspend_chat = false
	_reset_chat_timer()
	var audio := str(off.get("audio", ""))
	_client_says(audio if str(current.get("canal", "")) == "llamada" else "", Loc.pick(off["texto"]))
	if tree.animo < DialogTree.HANGUP:
		tree.hung_up = true
		tree.force_final(tree.first_final("molesto"))
		res["colgo"] = true
		last_say = res
		_end_tree()
		return res
	last_say = res
	changed.emit()
	return res


# --- Árbol --------------------------------------------------------------------------------------

func choose(i: int) -> void:
	if phase != Phase.ACTIVE or tree == null or tree.ended() or tree.waiting_action() or bool(composer.get("arbol", false)):
		return
	if on_hold:
		_set_hold(false)  # volver a hablar saca del hold
	var h0 := tree.history.size()
	var res := tree.choose(i)
	if not bool(res.get("ok", false)):
		return
	if not _say_override.is_empty() and h0 < tree.history.size():
		var h: Dictionary = tree.history[h0]  # v0.3.2 IA: lo que dijiste, no el texto del guion
		h["texto"] = _say_override["texto"]
		h["opcion"] = _say_override["opcion"]
		h["fuente"] = _say_override["fuente"]
	# Lo que dura el intercambio corre en el reloj, pero no consume el temporizador del chat (es tu respuesta).
	_suspend_chat = true
	GameState.add_game_time(float(res.get("t_juego", 0.0)))
	_suspend_chat = false
	if str(res.get("evento", "")) != "":
		EventBus.scripted_event.emit(str(res.get("evento", "")))
	var accion := str(res.get("accion", ""))
	match accion:
		"hold":
			_set_hold(true)
		"portal_pod", "portal_contacto":
			app_requested.emit("portal")
		"":
			pass
		_:
			if accion.begins_with("correo"):
				var tpl := "POD request" if accion == "correo_vitzo_pod" else "Status"
				composer = {"to": "Vitzo", "tpl": tpl, "muerte": str(res.get("muerte", "wmm_correo_vitzo")), "tx": str((current.get("portal", {}) as Dictionary).get("tx", "")), "arbol": true}
				app_requested.emit("correo")
	_after_tree_step()


func _after_tree_step() -> void:
	if tree == null:
		return
	if tree.ended():
		_end_tree()
		return
	_on_node_entered()
	changed.emit()


## La línea del cliente por el VoiceDirector (v0.3.2-core). Con voz (llamada): prioridad CLIENTE, importante, y su
## texto ya está en Kardex (`elsewhere`: si no llega a sonar, no hace falta aviso). Las líneas de un mismo contacto
## van en un grupo: si contestas antes de que el cliente termine de hablar, su línea siguiente corta a la anterior
## (la voz va con lo que ves en pantalla) en vez de esperar detrás y vencerse. Sin voz (chat): un texto de ambiente
## que no retrasa a nadie (la burbuja ya está en el chat).
func _client_says(audio: String, line: String) -> void:
	var group := "contacto:" + str(current.get("id", ""))
	var is_rage := line.contains("!!") or line.contains("¡¡") or (tree != null and tree.animo <= -20.0)
	if is_rage:
		GfxLens.kick(0.42, 0.55)
		AudioManager.play_sfx("fluorescente_estallido", "Auricular")
	if audio != "":
		AudioManager.play_voice("clientes", audio, "", "Auricular", 3.5 if is_rage else -1.0, {"group": group, "elsewhere": true})
		EventBus.subtitle.emit("cliente", line, 4.2 if is_rage else 3.5)
	elif line != "":
		VoiceDirector.text("cliente", line, 4.2 if is_rage else 3.5, {"must": false, "group": group})


var _last_node: String = ""


func _on_node_entered() -> void:
	if tree == null or tree.node_id == _last_node and tree.history.size() > 1:
		return
	_last_node = tree.node_id
	_reset_chat_timer()
	EventBus.dialog_node.emit(str(current.get("id", "")), tree.node_id)
	var line := Loc.pick(tree.client_line())
	var audio := str(tree.node().get("audio", "")).get_file().get_basename()
	_client_says(audio, line.replace("\n", " · "))
	match str(tree.node().get("evento", "")):
		"coaching_durante_llamada":
			_coaching_event()
		"respiracion_detras":
			EventBus.scripted_event.emit("respiracion_detras")


func _coaching_event() -> void:
	await get_tree().create_timer(4.0).timeout
	if phase == Phase.ACTIVE and tree != null:
		EventBus.shero_message.emit("convocar_coaching_evento", "dm")
		EventBus.coaching_requested.emit(float(DataLoader.bal("coaching/unirse_s", 60.0)))


func toggle_hold() -> void:
	if phase != Phase.ACTIVE or tree == null:
		return
	_set_hold(not on_hold)


## v0.3.1: fin del contacto/turno sin pasar por _set_hold: corta también la música de espera (va en bucle).
func _clear_hold() -> void:
	on_hold = false
	if AudioManager.music_playing() in ["musica/hold_kipupay", "musica/hold_kipupay_corrupta_loop"]:
		AudioManager.stop_music()


func _set_hold(on: bool) -> void:
	if on_hold == on:
		return
	on_hold = on
	EventBus.hold_changed.emit(on_hold)
	if on_hold:
		# v0.3.1 (audio_horror_v2): en T2/T3 con Fatiga alta, a veces la música de espera sale «corrupta».
		var corrupt := GameState.turno >= 2 and Fatigue.value >= 50.0 and not GameState.is_tutorial() and randf() < 0.25 and AudioManager.has_slot("musica/hold_kipupay_corrupta_loop")
		AudioManager.play_music("hold_kipupay_corrupta_loop" if corrupt else "hold_kipupay")
	elif AudioManager.music_playing() in ["musica/hold_kipupay", "musica/hold_kipupay_corrupta_loop"]:
		AudioManager.stop_music()  # v0.3.1: la música de espera va en bucle (Q3): se corta al sacar del hold
	changed.emit()


## Correo abierto por un árbol (WMM): Enviar = muerte de Vitzo; Cancelar = −10 de ánimo y vuelve.
func composer_send() -> void:
	if composer.is_empty():
		return
	var cause := str(composer.get("muerte", "wmm_correo_vitzo"))
	var tpl := str(composer.get("tpl", ""))
	composer = {}
	EventBus.email_sent.emit("Vitzo", tpl)
	_vitzo_detected(cause, true)
	changed.emit()


func composer_cancel() -> void:
	if composer.is_empty():
		return
	var from_tree := bool(composer.get("arbol", false))
	composer = {}
	if from_tree and tree != null and tree.waiting_action():
		tree.action_cancel()
		_after_tree_step()
	changed.emit()


func _end_tree() -> void:
	var c := current
	# v0.3.2 IA: si hubo conversación fuera de guion, el ánimo del cliente pesa en el resultado
	if free_turns > 0 and not tree.hung_up:
		if tree.outcome() == "satisfecho" and tree.animo < -20.0 and tree.first_final("neutral") != "":
			tree.final_id = tree.first_final("neutral")
		elif tree.outcome() == "neutral" and tree.animo < -45.0 and tree.first_final("molesto") != "":
			tree.final_id = tree.first_final("molesto")
	c["_libre"] = free_turns
	var outcome := tree.outcome()
	var csat := tree.csat()
	c["_duration"] = GameState.clock_seconds - _start_clock
	c["_outcome"] = outcome
	c["_final"] = tree.final_id
	c["_qa"] = tree.qa_marks.duplicate()
	c["_choices"] = tree.choices.duplicate()
	c["_neutral"] = outcome == "neutral"
	var line := Loc.pick(tree.final().get("cliente", {}))
	var audio := str(tree.final().get("audio", "")).get_file().get_basename()
	_client_says(audio, line.replace("\n", " · "))
	var angry := outcome == "molesto"
	_finish(c, not angry, angry, outcome, csat)


func _finish(c: Dictionary, resolved: bool, angry: bool, outcome: String, csat: int) -> void:
	phase = Phase.IDLE
	_last_node = ""
	_life_done(c)
	var was_hold := on_hold
	_clear_hold()
	composer = {}
	var gap: Array = DataLoader.bal("cola/pausa_tras_contacto_s_real", [4.0, 8.0])
	_min_gap = randf_range(float(gap[0]), float(gap[1]))
	if acd != null and acd.back_to_back():
		_min_gap = acd.b2b_gap()  # v0.3.2: back-to-back (como mucho back_to_back_max seguidos)
		acd.b2b_streak += 1
		_b2b_next = true
	_offer_wait = _filler_interval()
	if was_hold:
		EventBus.hold_changed.emit(false)
	var msg := "KARDEX_RESOLVED"
	match outcome:
		"molesto": msg = "KARDEX_CLIENT_ANGRY"
		"neutral": msg = "P4_OUTCOME_NEUTRAL"
		"satisfecho": msg = "P4_OUTCOME_OK"
		"bo_miss": msg = "P4_CASE_MISS"
	EventBus.show_message.emit(tr(msg), 2.0)
	if outcome in ["satisfecho", "neutral", "molesto"]:
		Metrics.register_outcome(outcome, csat)
	current = {}
	tree = null
	case = null
	HaimeGuion.remember(c)  # v0.3.1 Q4: Haime nombra el caso real (tipo, tu frase, el valor que elegiste)
	EventBus.contact_ended.emit(c, resolved, angry)
	EventBus.contact_outcome.emit(c, outcome, csat)
	PerritoRTA.dictate(Metrics.allocation_aux if Metrics.allocation_aux >= 0 else Metrics.Aux.AVAILABLE)
	_persist()  # al final: Metrics ya contó este contacto
	changed.emit()


# --- Llamadas perdidas ----------------------------------------------------------------------------

func _miss() -> void:
	var c := current
	c["_missed"] = true
	c["_duration"] = 0.0
	phase = Phase.IDLE
	current = {}
	missed_count += 1
	# v0.3.2: tras una perdida (RONA) no te vuelve a sonar enseguida: el contacto vuelve a la cola (si es opcional lo
	# puede tomar un compañero) y no te ofrecen nada en cola/rona_s_real. Antes volvía a sonar a los 4 s: caminando a tu
	# sitio en Available el MISMO guion se perdía 3-4 veces seguidas y Shero te mataba (el bug del evento de Rasec).
	_min_gap = float(DataLoader.bal("cola_acd/rona_s_real", 25.0))
	_offer_wait = _filler_interval()
	EventBus.show_message.emit(Loc.fmt(tr("P4_MISSED"), {"n": missed_count}), 3.0)
	AudioManager.play_sfx("ezlak_mencion", "UI")
	EventBus.contact_outcome.emit(c, "perdido", 0)
	_missed_fallback()
	changed.emit()


## ¿Discipline (P3) ya ejecuta esta pista? P3 define Discipline.owns_track(track) -> bool; mientras no exista,
## P4 hace la escalera mínima de llamadas perdidas (1.ª llamado · 2.ª verbal · 3.ª WW · 4.ª muerte).
static func discipline_owns(track: String) -> bool:
	return Discipline.has_method("owns_track") and bool(Discipline.call("owns_track", track))


func _missed_fallback() -> void:
	if discipline_owns(TRACK_MISSED):
		return
	var lines: Dictionary = DataLoader.dict("lineas_canales").get("llamadas_perdidas", {})
	match missed_count:
		1:
			EventBus.ezlak_post.emit("dm:shero", "shero", Loc.pick(lines.get("llamado", {})), {"tipo": "llamado", "pista": TRACK_MISSED, "typing_s": 1.5})
		2:
			EventBus.ezlak_post.emit("#team-familia", "shero", Loc.fmt(Loc.pick(lines.get("verbal", {})), {"agente": GameState.agent}), {"tipo": "verbal", "pista": TRACK_MISSED, "mention": true})
		3:
			Metrics.issue_written_warning(TRACK_MISSED)
		_:
			if missed_count >= 4:
				Checkpoints.request_death(missed_death_cause, str(missed_count), "shero")


# --- Casos de BO (correo, Vitzo, KYC) ------------------------------------------------------------

func kardex_lookup(tx_id: String) -> bool:
	if case == null:
		return false
	var was := case.kardex_done
	var ok := case.lookup_kardex(tx_id)
	if ok and not was:
		GameState.add_game_time(_sys_s("kardex"))  # el sistema tarda (latencia de Kardex)
	changed.emit()
	return ok


## Busca en el Portal Vitzo. Devuelve los datos del portal ({} si no existe). Si un árbol espera
## `portal_pod`, el resultado (POD disponible o no) decide el nodo siguiente.
func portal_search(tx_id: String) -> Dictionary:
	var key := tx_id.strip_edges().to_upper()
	var db: Dictionary = DataLoader.dict("casos_bo").get("portal", {})
	var info: Dictionary = {}
	if tree != null and str((current.get("portal", {}) as Dictionary).get("tx", "")) == key:
		info = (db.get(key, {}) as Dictionary).duplicate()
		var p: Dictionary = current.get("portal", {})
		info["pod"] = bool(p.get("pod", info.get("pod", false)))
		info["pod_texto"] = str(p.get("pod_texto", info.get("pod_texto", "")))
	elif db.has(key):
		info = (db[key] as Dictionary).duplicate()
	if info.is_empty():
		portal_view = {"tx": key, "no_existe": true}
		changed.emit()
		return {}
	info["tx"] = key
	if not info.has("monto"):
		info["monto"] = str((DataLoader.dict("casos_bo").get("transacciones", {}).get(key, {}) as Dictionary).get("monto", ""))
	portal_view = info
	GameState.add_game_time(_sys_s("portal"))
	_portal_action("buscar")
	if case != null and key == case.tx():
		case.portal_mark("buscar")
	if tree != null and tree.pending_action() == "portal_pod":
		tree.action_done("pod_ok" if bool(info.get("pod", false)) else "pod_no")
		_after_tree_step()
	changed.emit()
	return info


func portal_download_pod() -> bool:
	if portal_view.is_empty() or not bool(portal_view.get("pod", false)):
		return false
	_portal_action("pod")
	GameState.add_game_time(_sys_s("pod"))
	if case != null and str(portal_view.get("tx", "")) == case.tx():
		case.portal_mark("pod")
	changed.emit()
	return true


## Segundos de juego que tarda cada sistema (casos_bo.json/reglas/latencia_s_juego): el correo tiene trabajo
## real y pasarse de los 10 min es posible (poco probable si lo haces con cuidado y sin dudar).
func _sys_s(key: String) -> float:
	return float((_rules().get("latencia_s_juego", {}) as Dictionary).get(key, 0.0))


func portal_attach_pod() -> bool:
	if case == null or not case.portal_done.has("pod"):
		return false
	case.attach_pod = true
	_portal_action("adjuntar")
	changed.emit()
	return true


func portal_reversal() -> bool:
	if portal_view.is_empty() or portal_view.has("no_existe"):
		return false
	_portal_action("reversal")
	if case != null and str(portal_view.get("tx", "")) == case.tx():
		case.portal_mark("reversal")
	changed.emit()
	return true


func portal_contact() -> String:
	if portal_view.is_empty() or portal_view.has("no_existe"):
		return ""
	_sol_n += 1
	_portal_action("contacto")
	if case != null:
		case.portal_mark("contacto")
	if tree != null and tree.pending_action() == "portal_contacto":
		tree.action_done("ok")
		_after_tree_step()
	changed.emit()
	return "SOL-%d" % _sol_n


## El aviso del portal (T3) "si es urgente escríbanos a ops@vitzo.kp" abre el redactor hacia Vitzo (trampa).
func open_mailto_vitzo() -> void:
	if tree != null:
		composer = {"to": "Vitzo", "tpl": "Status", "muerte": "wmm_correo_vitzo", "tx": str(portal_view.get("tx", "")), "aviso": true}
	elif case != null:
		case.recipient = "Vitzo"
	else:
		composer = {"to": "Vitzo", "tpl": "Status", "muerte": "correo_vitzo", "tx": str(portal_view.get("tx", ""))}
	app_requested.emit("correo")
	changed.emit()


func _portal_action(action: String) -> void:
	EventBus.vitzo_portal_action.emit(str(current.get("id", "")), action)


func set_recipient(r: String) -> void:
	if case != null:
		case.recipient = r
		changed.emit()


func set_template(t: String) -> void:
	if case != null:
		case.template = t
		changed.emit()


func set_field(key: String, value: String) -> void:
	if case != null and case.kardex_done:
		case.set_field(key, value)
		if value != "" and key == mail_active_field:
			_advance_active_field()
		changed.emit()


## v0.3.1 Q4 (F16): el campo del correo que recibe el próximo valor copiado desde Kardex.
func set_active_field(key: String) -> void:
	if key in CasoBO.FIELDS and mail_active_field != key:
		mail_active_field = key
		changed.emit()


## Clic en un valor de Kardex: lo copia en SU campo del correo (el n.º en «N.º operación», el monto en «Monto», la
## fecha en «Fecha»), se pulse en el orden que se pulse y esté marcado el campo que esté. v0.3.2 (Joan: «correos que
## hago bien salen como mal resueltos»): antes el valor caía en el «campo activo», que se movía solo; copiar el monto
## antes que el número, un doble clic en un enlace o elegir primero un campo de la lista dejaban los tres campos
## cruzados sin ningún aviso, y el caso se cerraba con errores. Elegir la OPERACIÓN correcta (debajo salen las
## parecidas del mismo cliente) sigue siendo trabajo del jugador.
## `field` = columna de Kardex de la que sale el valor; "" = se deduce del valor (pruebas y bots viejos) y, si no se
## reconoce, va al campo activo como antes.
## Devuelve false sin caso de correo o sin haber buscado la operación en Kardex.
func copy_to_field(field: String, value: String) -> bool:
	if case == null or case.is_kyc() or not case.kardex_done or value == "":
		return false
	var f := field if field in CasoBO.FIELDS else field_of_value(value)
	if f == "":
		f = mail_active_field
	mail_active_field = f  # lo que set_field usa para saltar al siguiente campo vacío
	set_field(f, value)
	last_copied_field = f
	AudioManager.play_sfx("ack_click", "UI")
	return true


## Campo del último valor copiado desde Kardex (para el aviso «Copiado … en …»).
var last_copied_field: String = ""


## ¿De qué columna es este valor? Mira la operación del caso y las parecidas (opciones_campos). "" si no se sabe.
func field_of_value(value: String) -> String:
	if case == null:
		return ""
	var info := case.tx_info()
	if value == case.tx():
		return "id"
	if value == str(info.get("monto", "")):
		return "monto"
	if value == str(info.get("fecha", "")):
		return "fecha"
	var opts: Dictionary = current.get("opciones_campos", {})
	for f in CasoBO.FIELDS:
		if (opts.get(f, []) as Array).has(value):
			return f
	return ""


## Compatibilidad (v0.3.1): copiar «al campo activo». Ahora va al campo que le corresponde al valor.
func copy_to_active_field(value: String) -> bool:
	return copy_to_field("", value)


func _advance_active_field() -> void:
	var i := CasoBO.FIELDS.find(mail_active_field)
	for k in CasoBO.FIELDS.size():
		var f: String = CasoBO.FIELDS[(i + 1 + k) % CasoBO.FIELDS.size()]
		if str(case.fields.get(f, "")) == "":
			mail_active_field = f
			return


func set_attach(on: bool) -> void:
	if case != null:
		case.attach_pod = on and case.portal_done.has("pod")
		changed.emit()


func set_typification(t: String) -> void:
	if case != null:
		case.typification = t
		changed.emit()


## Envía el borrador del caso. A Vitzo = muerte `correo_vitzo` (aunque la plantilla sea "correcta").
func send_email() -> bool:
	if case == null or not case.can_send():
		return false
	var m := case.send()
	GameState.add_game_time(_sys_s("enviar"))
	EventBus.email_sent.emit(str(m.get("to", "")), str(m.get("tpl", "")))
	AudioManager.play_sfx("ezlak_notificacion", "UI")
	if str(m.get("to", "")) == "Vitzo":
		_vitzo_detected("correo_vitzo", false)
	changed.emit()
	return true


func _vitzo_detected(cause: String, wmm: bool) -> void:
	var v := get_tree().get_first_node_in_group("vitzo")
	if v != null and v.has_method("email_detected"):
		v.call("email_detected", cause, wmm)
	else:
		Checkpoints.request_death(cause, "", "vitzo")


## Cierra el caso de correo/Vitzo. Bien resuelto = sin consecuencia; mal = miss (QA) y marca para Haime.
func close_case() -> void:
	if case == null or phase != Phase.ACTIVE or case.is_kyc():
		return
	var ev := case.evaluate()
	var c := current
	c["_duration"] = GameState.clock_seconds - _start_clock
	c["_qa"] = _detailed_marks(ev.get("motivos", []))
	c["_correo_detalle"] = _mail_detail()
	c["_case_steps"] = case.notes.duplicate()
	c["_bo_elapsed"] = email_elapsed
	if not bool(ev.get("ok", false)):
		Metrics.report_miss("correo")
	_finish(c, bool(ev.get("ok", false)), false, "bo_ok" if bool(ev.get("ok", false)) else "bo_miss", 0)


## v0.3.1 Q4 (Haime personalizado): «correo_incorrecto» se separa en lo que de verdad falló (campo, plantilla,
## destinatario, adjunto) comparando el correo de referencia (CasoBO.reference_mail: el último que le mandaste a quien
## había que escribirle) con el correcto; un caso mal resuelto que además pasó los 10 min suma «correo_tiempo». Las
## marcas solo existen si el caso ya estaba mal (no hay oportunidades falsas).
## v0.3.2: la plantilla se compara con CasoBO.valid_templates() y «sin_pod» solo sale si el caso pedía el POD y no
## le llegó a quien lo pidió.
func _detailed_marks(motivos: Array) -> Array:
	var out: Array = []
	var want: Dictionary = case.correct()
	var dest := str(want.get("destinatario", ""))
	var last: Dictionary = case.reference_mail()
	for r in motivos:
		var k := str(r)
		if k == "correo_incorrecto" and not last.is_empty():
			var parts: Array = []
			if str(last.get("to", "")) != dest:
				parts.append("destinatario_equivocado")
			if not case.valid_templates().has(str(last.get("tpl", ""))):
				parts.append("correo_plantilla")
			var campos: Dictionary = want.get("campos", {})
			for f in CasoBO.FIELDS:
				if campos.has(f) and str((last.get("fields", {}) as Dictionary).get(f, "")) != str(campos[f]):
					parts.append("correo_campo_" + f)
			if case.needs_pod() and not bool(last.get("pod", false)) and not case._pod_reached(dest):
				parts.append("sin_pod")
			if parts.is_empty():
				parts.append(k)
			for p in parts:
				if not out.has(p):
					out.append(p)
		elif not out.has(k):
			out.append(k)
	if not out.is_empty() and email_elapsed > float(_rules().get("limite_s_juego", 600.0)):
		out.append("correo_tiempo")
	return out


func _mail_detail() -> Dictionary:
	var last: Dictionary = case.reference_mail()
	# «a quién le escribiste»: si además del correo bueno salió otro a quien no era, Haime cita a ese.
	var to := str(last.get("to", ""))
	var dest := str(case.correct().get("destinatario", ""))
	for m in case._work_mails():
		if str((m as Dictionary).get("to", "")) != dest:
			to = str((m as Dictionary).get("to", ""))
	return {"to": to, "tpl": str(last.get("tpl", "")), "campos": (last.get("fields", {}) as Dictionary).duplicate(), "pod": bool(last.get("pod", false)), "tip": case.typification, "enviados": case.sent.size()}


## Identa: aprobar | rechazar | solicitar_id | solicitar_comprobante | escalar | resolver_recheck.
func kyc_decide(action: String) -> void:
	if case == null or not case.is_kyc() or phase != Phase.ACTIVE:
		return
	case.kyc_action = action
	var ev := case.evaluate()
	var ok := bool(ev.get("ok", false))
	var c := current
	c["_duration"] = GameState.clock_seconds - _start_clock
	c["_qa"] = ev.get("motivos", [])
	c["_kyc_action"] = action
	if ok:
		EventBus.show_message.emit(tr("IDENTA_OK"), 2.0)
	else:
		EventBus.show_message.emit(tr("IDENTA_WRONG"), 3.0)
		Metrics.report_miss("kyc")
	_finish(c, ok, false, "bo_ok" if ok else "bo_miss", 0)


# --- Levantarse, morir ----------------------------------------------------------------------------

## v0.3.2: solo se reciben contactos en Available. Si dejas Available con uno sonando, esa es UNA perdida (si lo
## cambiaste tú); si te cambió el sistema (Trainer, Haime, coaching de Shero), el contacto vuelve a la cola sin perdida.
func _on_aux_changed(new_aux: int, _old_aux: int) -> void:
	if phase != Phase.OFFERING or new_aux == Metrics.Aux.AVAILABLE or is_bo(current):
		return
	if int(GameState.flags.get("aux_por_jugador_frame", -1)) == Engine.get_process_frames():
		_miss()
	else:
		_slot_rearm(int(current.get("_slot", -1)))
		phase = Phase.IDLE
		current = {}
		_min_gap = 3.0
		changed.emit()


func _on_player_stood_up() -> void:
	if Checkpoints.dying:
		return  # v0.3.2: el respawn te vuelve a sentar en tu PC; el contacto en curso se cierra como «desconectado»
	if phase == Phase.ACTIVE and tree != null and not on_hold:
		EventBus.show_message.emit(tr("MSG_NEED_HOLD"), 3.0)
		tree.force_final(tree.first_final("molesto"))
		_end_tree()


# --- v0.3.2-core2: repetir un tramo ------------------------------------------------------------------------------
## Al reaparecer (o «Reiniciar contacto», o salir y «Continuar») el reloj vuelve al checkpoint y repites ese tramo.
## Antes ese tramo se quedaba casi vacío: lo que ya habías atendido no volvía, el relleno del turno ya estaba
## gastado, y en Difícil (checkpoint solo en login/break/lunch) eran horas de juego sin un contacto. Reglas:
##   · Lo que atendiste hasta el final sigue atendido: un guion resuelto no vuelve a llamar (no repites la misma
##     conversación) y su cuenta, AHT, resultado y CSAT se conservan (Metrics.keep_contacts). Nada se cuenta dos
##     veces: el contacto que tenías a medias nunca llegó a contarse, y ese sí vuelve a su hora.
##   · La carga del tramo es la de la primera vez: cada contacto que atendiste después del checkpoint deja un HUECO
##     a la hora de juego en que te había entrado, y en ese hueco entra un SUSTITUTO: otro cliente de la bolsa de
##     relleno (_filler). Los huecos esperan en la cola como un guion (el HUD los cuenta: lo que dice «Cola» es lo
##     que te puede entrar) y solo entran contigo sentado en tu puesto, en Available. Un KYC no deja hueco: en BO
##     ya entra uno de relleno por allocation.
##   · Vale igual en todas las dificultades y para «Continuar»: lo vivo se apunta en el checkpoint al cerrar cada
##     contacto (_persist) y el tramo se arma al rebobinar (_rewind).

func _life_open() -> Array:
	var out: Array = []
	for e in _life:
		if not bool((e as Dictionary).get("fin", false)):
			out.append((e as Dictionary).duplicate())
	return out


## Huecos que siguen valiendo: los pendientes y el del sustituto que tienes entre manos.
func _slots_open() -> Array:
	var cur := int(current.get("_slot", -1)) if phase != Phase.IDLE else -1
	var out: Array = []
	for sl in _slots:
		if not bool((sl as Dictionary).get("hecho", false)) or int((sl as Dictionary).get("uid", -2)) == cur:
			out.append((sl as Dictionary).duplicate())
	return out


## Lo que cambia entre checkpoints y hay que poder reponer: qué atendiste (y con qué resultado) y por dónde va el relleno.
func _live_extra(life: Array) -> Dictionary:
	var per_block := {}
	for k in _filler_per_block.keys():
		per_block[str(k)] = int(_filler_per_block[k])
	return {
		"cm_vida": life, "cm_atendidos": _attended.keys(), "cm_metricas": Metrics.contacts_snapshot(),
		"cm_fq": filler_quota, "cm_fpb": per_block, "cm_fc": filler_count, "cm_fnext": _filler_next,
		"cm_fserved": filler_served.duplicate(), "cm_last": _last_base, "cm_subs": sub_count, "cm_desb": overflow_count,
		"cm_visto": maxf(_seen_clock, GameState.clock_seconds), "cm_hasta": _repeat_until, "cm_demas": extra_count,
	}


## Un checkpoint nuevo: lo que terminó antes ya no se repite (se olvida). Queda lo que está en curso.
func _on_checkpoint_saved(_kind: String) -> void:
	_life = _life_open()
	_slots = _slots_open()


## Apunta lo vivo en el checkpoint (memoria y disco) al cerrar un contacto. Solo si el checkpoint es de los que
## guardan la cola (el de «inicio» no: el turno real y la Inducción empiezan de cero).
func _persist() -> void:
	if GameState.is_tutorial() or not Checkpoints.matches_current(Checkpoints.last_checkpoint):
		return
	if not (Checkpoints.last_checkpoint.get("extra", {}) as Dictionary).has("cm_served"):
		return
	var life: Array = []
	for e in _life:
		life.append((e as Dictionary).duplicate())
	Checkpoints.patch_checkpoint_extra(_live_extra(life))


func _life_done(c: Dictionary) -> void:
	var id := str(c.get("id", ""))
	for i in range(_life.size() - 1, -1, -1):
		var e: Dictionary = _life[i]
		if str(e.get("id", "")) == id and not bool(e.get("fin", false)):
			e["fin"] = true
			if not bool(e.get("relleno", false)):
				_attended[id] = true
			return


## v0.3.2-core3 — ¿Repites un tramo ya jugado? (el reloj va por detrás de donde llegaste antes de reaparecer)
func repeating() -> bool:
	return GameState.clock_seconds < _repeat_until - 1.0


## Un contacto de relleno que entra a su ritmo (o por desborde) MIENTRAS repites un tramo es un contacto «de más»: la
## primera vez no existía (los que sí existían son los huecos, y en ellos entran los sustitutos). Para que repetir no
## cueste más que la primera vez: si sale molesto no suma Fatiga (Metrics._on_contact_ended) y, si vuelves a morir,
## no deja hueco (el tramo no engorda con cada intento).
func _mark_extra(c: Dictionary) -> void:
	if repeating() and not GameState.is_tutorial():
		c["de_mas"] = true
		extra_count += 1


func _add_slot(t: float, from: String) -> void:
	_slot_uid += 1
	_slots.append({"uid": _slot_uid, "t": t, "hecho": false, "de": from})


func _slot_rearm(uid: int) -> void:
	for sl in _slots:
		if int((sl as Dictionary).get("uid", -2)) == uid:
			(sl as Dictionary)["hecho"] = false


## Índice del hueco pendiente más antiguo cuya hora ya llegó (-1 si no hay).
func _slot_due() -> int:
	var best := -1
	for i in _slots.size():
		var sl: Dictionary = _slots[i]
		if bool(sl.get("hecho", false)) or float(sl.get("t", 0.0)) > GameState.clock_seconds:
			continue
		if best < 0 or float(sl.get("t", 0.0)) < float((_slots[best] as Dictionary).get("t", 0.0)):
			best = i
	return best


## Sustitutos que ya te esperan en la cola (el HUD y Fonex los cuentan).
func slots_waiting() -> int:
	var n := 0
	for sl in _slots:
		if not bool((sl as Dictionary).get("hecho", false)) and float((sl as Dictionary).get("t", 0.0)) <= GameState.clock_seconds:
			n += 1
	return n


## Hora de juego del sustituto que más lleva esperando (INF si ninguno).
func slots_oldest() -> float:
	var i := _slot_due()
	return float((_slots[i] as Dictionary).get("t", 0.0)) if i >= 0 else INF


## Huecos del tramo todavía sin servir, hayan llegado o no (pruebas e informe).
func slots_pending() -> int:
	var n := 0
	for sl in _slots:
		if not bool((sl as Dictionary).get("hecho", false)):
			n += 1
	return n


## Si faltas mucho rato los sustitutos no se amontonan sin fin: con más de `keep` esperando, un compañero libre
## toma el más antiguo (como hace con un guion opcional). Lo llama ColaACD. Devuelve si tomó uno.
func npc_take_slot(waited_s: float, keep: int = 3) -> bool:
	if slots_waiting() <= keep:
		return false
	var i := _slot_due()
	if i < 0 or GameState.clock_seconds - float((_slots[i] as Dictionary).get("t", 0.0)) < waited_s:
		return false
	(_slots[i] as Dictionary)["hecho"] = true
	return true


## «Cola 5» en el HUD, tú en Available, sentado y libre, y no entra nada: no puede pasar. Si el contacto de ambiente
## más antiguo lleva esperando más de cola_acd/espera_max_min_juego[dificultad] (nadie lo atiende: con un compañero
## libre el ambiente no espera) y llevas cola_acd/espera_max_pausa_s_real segundos reales libre, te entra a ti,
## aunque el cupo de relleno del turno ya esté servido. No pisa un guion ni un sustituto que estén al caer.
func _starving(delta: float) -> bool:
	if acd == null or acd.ambient.is_empty() or GameState.is_tutorial() or _fillers().is_empty():
		_starve_s = 0.0
		return false
	var waits: Array = DataLoader.bal("cola_acd/espera_max_min_juego", [40.0, 30.0, 20.0])
	var max_wait := float(waits[clampi(Difficulty.effective(), 0, waits.size() - 1)]) * 60.0
	if acd.ambient_wait() < max_wait:
		_starve_s = 0.0
		return false
	_starve_s += delta
	if _starve_s < float(DataLoader.bal("cola_acd/espera_max_pausa_s_real", 6.0)):
		return false
	var margin := float(DataLoader.bal("cola/relleno_margen_guion_s_juego", 480.0)) * 0.6
	var nxt := next_scripted()
	if not nxt.is_empty() and not is_bo(nxt) and clock_of(str(nxt.get("hora_juego", "00:00"))) - GameState.clock_seconds < margin:
		return false
	for sl in _slots:
		if not bool((sl as Dictionary).get("hecho", false)) and float((sl as Dictionary).get("t", 0.0)) - GameState.clock_seconds < margin:
			return false
	return true


## Rebobina la cola al checkpoint vivo (si es de este agente y turno). `fresh`: el mundo se acaba de armar
## («Continuar» desde el menú) y todo sale del checkpoint; si no (reaparecer, «Reiniciar contacto»), lo vivo es lo
## que este ContactManager tiene en memoria. v0.3.2-core: antes de leer cm_served al «Continuar», los clientes que
## ya habías atendido volvían a llamar desde el primero.
func _rewind(fresh: bool) -> void:
	if not Checkpoints.matches_current(Checkpoints.last_checkpoint):
		_life.clear()
		return
	var extra: Dictionary = Checkpoints.last_checkpoint.get("extra", {})
	var now := GameState.clock_seconds
	if extra.has("cm_served"):
		_served.clear()
		for sv in extra.get("cm_served", []):
			_served.append(str(sv))
		missed_count = int(extra.get("cm_missed", missed_count))
	elif fresh:
		# «Continuar» con un checkpoint de una versión anterior que no guardaba la cola (los de login/break/lunch):
		# los guiones cuya hora ya pasó se dan por atendidos. Antes volvían a sonar todos, uno detrás de otro.
		for c in _schedule:
			var cid := str(c.get("id", ""))
			if clock_of(str(c.get("hora_juego", "00:00"))) < now - 60.0 and not _served.has(cid):
				_served.append(cid)
	if GameState.is_tutorial():
		_life.clear()
		return
	if fresh:
		_load_extra(extra)
	if acd != null and (not fresh or extra.has("cm_acd")):
		acd.rewind(extra.get("cm_acd", {}))
	# Lo que atendiste hasta el final no vuelve, lo diga o no la lista del checkpoint.
	for id in _attended.keys():
		if not _served.has(str(id)):
			_served.append(str(id))
	# Cada contacto atendido después del checkpoint deja un hueco a su hora; el que estaba a medias vuelve.
	for e in _life:
		var id := str((e as Dictionary).get("id", ""))
		var t := maxf(float((e as Dictionary).get("t", now)), now)
		var kyc := bool((e as Dictionary).get("kyc", false))
		if not bool((e as Dictionary).get("relleno", false)):
			if bool((e as Dictionary).get("fin", false)):
				_attended[id] = true
				if not _served.has(id):
					_served.append(id)
				if not kyc:
					_add_slot(t, id)
			else:
				_served.erase(id)
				_attended.erase(id)
		elif int((e as Dictionary).get("slot", -1)) < 0 and not kyc and not bool((e as Dictionary).get("fuera", false)) and not bool((e as Dictionary).get("desborde", false)) and not bool((e as Dictionary).get("de_mas", false)):
			_add_slot(t, id)
	_life.clear()
	# v0.3.2-core3: desde aquí hasta donde habías llegado, repites (repeating()).
	_repeat_until = maxf(_repeat_until, _seen_clock)
	for sl in _slots:
		(sl as Dictionary)["hecho"] = false
		(sl as Dictionary)["t"] = maxf(float((sl as Dictionary).get("t", now)), now)
	Metrics.keep_contacts(extra.get("cm_metricas", {}))
	# El checkpoint vivo queda como el tramo que vas a repetir: otra muerte desde él, o «Continuar», dan lo mismo.
	if extra.has("cm_served"):
		var patch := {"cm_served": _served.duplicate(), "cm_slots": _slots_open(), "cm_uid": _slot_uid}
		patch.merge(_live_extra([]))
		Checkpoints.patch_checkpoint_extra(patch)
	elif fresh and GameState.logged_in:
		Checkpoints.patch_checkpoint_extra(_cp_extra())  # el checkpoint viejo pasa a guardar la cola


## «Continuar»: lo vivo sale del checkpoint (este ContactManager acaba de nacer).
func _load_extra(extra: Dictionary) -> void:
	_attended.clear()
	for id in extra.get("cm_atendidos", []):
		_attended[str(id)] = true
	_slots.clear()
	for sl in extra.get("cm_slots", []):
		var d: Dictionary = sl
		_slots.append({"uid": int(d.get("uid", 0)), "t": float(d.get("t", 0.0)), "hecho": bool(d.get("hecho", false)), "de": str(d.get("de", ""))})
	_slot_uid = int(extra.get("cm_uid", 0))
	_life.clear()
	for e in extra.get("cm_vida", []):
		_life.append((e as Dictionary).duplicate())
	if not extra.has("cm_fq"):
		return
	filler_quota = int(extra.get("cm_fq", filler_quota))
	_filler_per_block.clear()
	var per_block: Dictionary = extra.get("cm_fpb", {})
	for k in per_block.keys():
		_filler_per_block[int(str(k))] = int(per_block[k])
	filler_count = int(extra.get("cm_fc", 0))
	_filler_next = int(extra.get("cm_fnext", 0))
	filler_served.clear()
	for b in extra.get("cm_fserved", []):
		filler_served.append(str(b))
	_last_base = str(extra.get("cm_last", ""))
	sub_count = int(extra.get("cm_subs", 0))
	overflow_count = int(extra.get("cm_desb", 0))
	extra_count = int(extra.get("cm_demas", 0))
	_seen_clock = float(extra.get("cm_visto", NO_CLOCK))
	_repeat_until = float(extra.get("cm_hasta", NO_CLOCK))


func _on_respawned(_kind: String) -> void:
	# v0.3.2: el contacto que sonaba o atendías al morir se cierra como «desconectado»: ni perdido ni AHT. El guion
	# vuelve a su hora (nunca se pierde un guion); el relleno deja un hueco (v0.3.2-core2: antes volvía al ambiente
	# de la cola y se perdía).
	if phase != Phase.IDLE:
		var loose := bool(current.get("relleno", false)) and not current.has("_slot") and not bool(current.get("_fuera", false)) and not bool(current.get("desborde", false)) and not bool(current.get("de_mas", false)) and str(current.get("canal", "")) != "kyc"
		if phase == Phase.OFFERING and loose and not GameState.is_tutorial():
			_life.append({"id": str(current.get("id", "")), "t": _offer_clock, "relleno": true, "slot": -1, "fuera": false, "kyc": false, "desborde": false, "fin": false})
		EventBus.contact_disconnected.emit(current.duplicate())
		EventBus.show_message.emit(tr("B2_RECON_DESCONECTADO"), 4.0)
	phase = Phase.IDLE
	current = {}
	tree = null
	case = null
	composer = {}
	_rewind(false)
	_clear_hold()
	_last_node = ""
	_min_gap = 5.0
	_offer_wait = _filler_interval()
	_starve_s = 0.0
	EventBus.hold_changed.emit(false)
	changed.emit()


## v0.3.2: al terminar «Reconectando» (elegiste AUX o pasó solo a Available), unos segundos antes del primer timbre.
func after_reconnect() -> void:
	_min_gap = maxf(_min_gap, float(DataLoader.bal("reconexion/primer_timbre_s_real", 4.0)))


func is_active() -> bool:
	return phase == Phase.ACTIVE


## Segundos de juego que le quedan al caso BO abierto antes de los 10 min (negativo = pasado).
func email_seconds_left() -> float:
	if phase != Phase.ACTIVE or case == null:
		return 0.0
	return float(current.get("limite_s_juego", _rules().get("limite_s_juego", 600.0))) - email_elapsed


## Color del reloj del caso: "verde" | "amarillo" (7 min) | "rojo" (9 min) | "pasado".
func case_timer_color() -> String:
	var r := _rules()
	if email_elapsed >= float(r.get("limite_s_juego", 600.0)):
		return "pasado"
	if email_elapsed >= float(r.get("aviso_rojo_s_juego", 540.0)):
		return "rojo"
	if email_elapsed >= float(r.get("aviso_amarillo_s_juego", 420.0)):
		return "amarillo"
	return "verde"


## Tiempo de juego que lleva el contacto actual.
func elapsed() -> float:
	return GameState.clock_seconds - _start_clock if phase == Phase.ACTIVE else 0.0

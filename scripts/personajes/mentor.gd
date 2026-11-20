class_name Mentor
extends Node
## Mentor (v0.3, PLAN §2 #40/#43, DIALOGOS §8), en todos los turnos:
## - Lista de allocations cada 90 min (lineas_mentor.json/lista_horas) en #team-familia con el Available de cada
##   agente, incluido el tuyo. Es la ÚNICA forma en que Shero se entera de tu Available (P3 escucha
##   EventBus.ezlak_post con meta.tipo = "allocations": {lista, jugador, jugador_pct, evaluable, target,
##   bajo_target, n}).
## - Allocations a BO de 20 min (turnos.json/allocations_bo y allocation_bo_min) a la hora de los KYC del turno
##   (casos_bo.json) y, si faltan, a allocation_horas_extra. El RTA da la orden en #allocations.
## - 3 minitrainings (00:20 · 03:30 · 06:15) que se hacen en la app Campus; a las 08:00, si falta alguno,
##   aviso del Mentor + llamado de Shero (meta.tipo = "minitraining_pendiente").
##   v0.3.2 (feedback de Joan: «tres minitrainings distintos por turno en vez de los mismos tres»): cada día tiene
##   los suyos (lineas_mentor.json/minitrainings_por_dia → day_minitrainings()); ningún tema se repite en la semana.
## - Lamebotas: responde a lo que Shero publica en #team-familia.

const TARGET := 70.0
## v0.3.2-core: cuántas listas programadas ya salieron y cuántas listas van (GameState.flags viaja con el checkpoint).
## Antes el índice se recalculaba solo con la hora y un margen de 60 s: un checkpoint guardado en el minuto siguiente
## a una lista (en el T3 el KYC de las 03:00 abre justo con la lista de las 03:00) la volvía a publicar al reaparecer
## o al Continuar, Shero la contaba dos veces y te perseguía en pleno «Reconectando».
const FLAG_LISTS := "mentor_listas_idx"
const FLAG_LISTS_N := "mentor_listas_n"
## Los minitrainings hechos, igual: antes vivían solo en este nodo y «Continuar» los olvidaba (a las 08:00 el Mentor
## decía que te faltaban los tres y Shero te escribía).
const FLAG_MT_DONE := "mentor_mt_hechos"
const FLAG_MT_IDX := "mentor_mt_idx"  # minitrainings ya anunciados
const FLAG_MT_WARNED := "mentor_mt_aviso"  # el aviso de las 08:00 ya salió
## La allocation a BO en curso (hasta qué hora y cuántas van): «Continuar» con un checkpoint guardado en plena
## allocation dejaba al RTA pidiendo BO sin nadie que la cerrara (el Mentor nuevo no sabía que había una).
const FLAG_ALLOC_UNTIL := "mentor_alloc_hasta"
const FLAG_ALLOC_IDX := "mentor_alloc_idx"

var active: bool = false
var alloc_aux: int = -1
var until_clock: float = 0.0
var minitrainings_done: Array[String] = []
var minitrainings_open: Array[String] = []
var lists_posted: int = 0
var _alloc_times: Array[float] = []
var _alloc_next: int = 0
var _list_next: int = 0
var _mt_next: int = 0
var _pending_warned: bool = false
var _comply_left: float = 0.0
var _comply_pending: bool = false
var _rng := RandomNumberGenerator.new()
var _drift: Dictionary = {}


func _ready() -> void:
	EventBus.clock_tick.connect(_on_clock)
	EventBus.ezlak_post.connect(_on_post)
	EventBus.respawned.connect(_on_respawned)
	EventBus.shift_started.connect(_reset)
	var cp_alloc := Metrics.allocation_aux  # «Continuar»: lo que traía el checkpoint (_reset lo limpia)
	_reset()
	_adopt_allocation(cp_alloc)


## «Continuar» (el Mentor nace con el checkpoint ya restaurado): si el checkpoint se guardó en plena allocation y
## todavía no terminó, sigue en curso hasta su hora; si ya terminó, el RTA vuelve a pedir Available.
func _adopt_allocation(cp_alloc: int) -> void:
	if cp_alloc < 0 or not GameState.logged_in:
		return
	var until := float(GameState.flags.get(FLAG_ALLOC_UNTIL, -1.0))
	if until > GameState.clock_seconds + 1.0:
		active = true
		alloc_aux = cp_alloc
		until_clock = until
		Metrics.allocation_aux = cp_alloc
	elif Metrics.expected_aux == cp_alloc and not GameState.in_contact:
		PerritoRTA.dictate(Metrics.Aux.AVAILABLE)


func _data() -> Dictionary:
	return DataLoader.dict("lineas_mentor")


## Los minitrainings del turno (por defecto, el actual), en orden y con su hora: [{id, n, hora, anuncio, titulo,
## texto, pregunta, opciones, correcta}]. Salen de lineas_mentor.json: `minitrainings_por_dia` (turno → ids),
## `minitraining_horas` (la hora de cada puesto) y `minitrainings` (el banco). Un turno sin lista propia rota entre
## las que hay; sin `minitrainings_por_dia` vale el banco entero con la hora de cada entrada (formato de la v0.3).
static func day_minitrainings(turno: int = -1) -> Array:
	var d: Dictionary = DataLoader.dict("lineas_mentor")
	var t := GameState.turno if turno < 0 else turno
	var bank: Array = d.get("minitrainings", [])
	var per: Dictionary = d.get("minitrainings_por_dia", {})
	var days: Array = []
	for k in per.keys():
		if not str(k).begins_with("_"):
			days.append(str(k))
	if days.is_empty():
		return bank.duplicate(true)
	days.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	var ids: Array = per.get(str(t), [])
	if ids.is_empty():
		ids = per.get(days[posmod(t - 1, days.size())], [])
	var by_id: Dictionary = {}
	for mt in bank:
		by_id[str((mt as Dictionary).get("id", ""))] = mt
	var hours: Array = d.get("minitraining_horas", [])
	var out: Array = []
	for i in ids.size():
		if not by_id.has(str(ids[i])):
			continue
		var mt: Dictionary = (by_id[str(ids[i])] as Dictionary).duplicate(true)
		mt["hora"] = str(hours[i]) if i < hours.size() else str(mt.get("hora", "00:00"))
		mt["n"] = out.size() + 1
		out.append(mt)
	return out


func _reset() -> void:
	_rng.seed = 311 + GameState.turno * 7
	active = false
	alloc_aux = -1
	_comply_pending = false
	Metrics.allocation_aux = -1
	minitrainings_done.clear()
	minitrainings_open.clear()
	lists_posted = 0
	_pending_warned = false
	_drift.clear()
	_alloc_times = _allocation_times()
	_resync()


## v0.3.1 Q1 (F23, hook mínimo): al reaparecer, una allocation que empezó DESPUÉS del checkpoint no sigue (antes
## quedaba activa hasta su hora de fin, 2 h de juego más tarde, y el RTA pedía BO todo ese rato mientras Shero
## castigaba el Available). Metrics ya restauró allocation_aux del checkpoint; se vuelve a publicar a su hora.
## v0.3.2-core: manda lo que dice el checkpoint (allocation_aux de Metrics + hasta qué hora, en GameState.flags), no lo
## que este nodo recordaba al morir. Antes, si la allocation del checkpoint TERMINABA entre el checkpoint y la muerte
## (o mientras duraba la secuencia de muerte, con el reloj corriendo), al reaparecer —con el reloj otra vez dentro de
## su horario— se daba por terminada y el RTA dejaba de pedir BO a mitad de la orden.
func _on_respawned(_k: String) -> void:
	_comply_pending = false
	var cp_alloc := Metrics.allocation_aux
	var until := float(GameState.flags.get(FLAG_ALLOC_UNTIL, -1.0))
	if cp_alloc >= 0 and until > GameState.clock_seconds + 1.0:
		active = true
		alloc_aux = cp_alloc
		until_clock = until
	else:
		active = false
		alloc_aux = -1
		Metrics.allocation_aux = -1
	if Metrics.allocation_aux < 0 and Metrics.expected_aux == Metrics.Aux.BO and not GameState.in_contact:
		PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	_resync()


## Tras un respawn (el reloj vuelve atrás) los índices se recalculan con la hora actual.
func _resync() -> void:
	var now := GameState.clock_seconds
	_alloc_next = 0
	if GameState.flags.has(FLAG_ALLOC_IDX):
		_alloc_next = clampi(int(GameState.flags[FLAG_ALLOC_IDX]), 0, _alloc_times.size())
	else:
		while _alloc_next < _alloc_times.size() and _alloc_times[_alloc_next] + 60.0 < now:
			_alloc_next += 1
	_list_next = 0
	var lh: Array = _data().get("lista_horas", [])
	if GameState.flags.has(FLAG_LISTS):
		# Lo que decía el checkpoint: las listas que ya salieron no se repiten y las que faltaban salen a su hora.
		_list_next = clampi(int(GameState.flags[FLAG_LISTS]), 0, lh.size())
		lists_posted = int(GameState.flags.get(FLAG_LISTS_N, _list_next))
	else:
		while _list_next < lh.size() and GameState.hhmm_to_seconds(str(lh[_list_next])) + 60.0 < now:
			_list_next += 1
	minitrainings_done.clear()
	for id in GameState.flags.get(FLAG_MT_DONE, []):
		minitrainings_done.append(str(id))
	_pending_warned = bool(GameState.flags.get(FLAG_MT_WARNED, false))
	_mt_next = 0
	var mts: Array = day_minitrainings()
	var known := GameState.flags.has(FLAG_MT_IDX)
	var upto := clampi(int(GameState.flags.get(FLAG_MT_IDX, 0)), 0, mts.size())
	while _mt_next < mts.size() and (_mt_next < upto if known else GameState.hhmm_to_seconds(str((mts[_mt_next] as Dictionary).get("hora", "00:00"))) + 60.0 < now):
		var id := str((mts[_mt_next] as Dictionary).get("id", ""))
		if not minitrainings_open.has(id):
			minitrainings_open.append(id)
		_mt_next += 1


## Horas de inicio de las allocations a BO del turno: 3 min antes de cada KYC y, si faltan, las extra.
func _allocation_times() -> Array[float]:
	var out: Array[float] = []
	var n := int(GameState.turno_cfg("allocations_bo", 1))
	for c in (DataLoader.dict("casos_bo").get("turnos", {}) as Dictionary).get(str(GameState.turno), []):
		if str(c.get("canal", "")) == "kyc" and out.size() < n:
			out.append(GameState.hhmm_to_seconds(str(c.get("hora_juego", "00:00"))) - 180.0)
	for h in _data().get("allocation_horas_extra", []):
		if out.size() >= n:
			break
		var s := GameState.hhmm_to_seconds(str(h))
		var clash := false
		for o in out:
			if absf(o - s) < 45.0 * 60.0:
				clash = true
		if not clash and not _in_blocked_window(s):
			out.append(s)
	out.sort()
	return out


func _in_blocked_window(s: float) -> bool:
	var lunch := GameState.lunch_clock()
	if s > lunch - 30.0 * 60.0 and s < lunch + float(GameState.lunch_minutes()) * 60.0:
		return true
	var tr_clock := GameState.training_clock()
	return tr_clock >= 0.0 and s > tr_clock - 30.0 * 60.0 and s < tr_clock + 40.0 * 60.0


func _process(delta: float) -> void:
	if not _comply_pending or get_tree().paused:
		return
	_comply_left -= delta
	if _comply_left <= 0.0:
		_comply_pending = false
		if Metrics.aux != alloc_aux and GameState.logged_in:
			EventBus.rta_tag.emit(Loc.fmt(tr("RTA_ALLOCATION_MISS"), {"jugador": GameState.agent, "aux": Metrics.aux_name(alloc_aux)}))
			AudioManager.play_sfx("ezlak_mencion", "UI")


func _on_clock(game_seconds: float) -> void:
	if not GameState.logged_in or GameState.shift_over or Flashback.active:
		return  # v0.3.2 · en el recuerdo del Training no hay Mentor de hoy: ni listas, ni allocations, ni minitrainings
	if active and game_seconds >= until_clock:
		_end_allocation()
	elif not active and _alloc_next < _alloc_times.size() and game_seconds >= _alloc_times[_alloc_next] and not GameState.in_calm and not Discipline.is_lunch_immune("mentor") and not Metrics.reconnecting:
		_alloc_next += 1
		GameState.flags[FLAG_ALLOC_IDX] = _alloc_next
		post_allocation_now()
	var lh: Array = _data().get("lista_horas", [])
	if _list_next < lh.size() and game_seconds >= GameState.hhmm_to_seconds(str(lh[_list_next])):
		while _list_next < lh.size() and game_seconds >= GameState.hhmm_to_seconds(str(lh[_list_next])):
			_list_next += 1  # si el reloj saltó (dormido, pruebas) solo se publica la última lista
		GameState.flags[FLAG_LISTS] = _list_next
		post_list_now()
	var mts: Array = day_minitrainings()
	while _mt_next < mts.size() and game_seconds >= GameState.hhmm_to_seconds(str((mts[_mt_next] as Dictionary).get("hora", "00:00"))):
		var mt: Dictionary = mts[_mt_next]
		_mt_next += 1
		GameState.flags[FLAG_MT_IDX] = _mt_next
		if not minitrainings_open.has(str(mt.get("id", ""))):
			minitrainings_open.append(str(mt.get("id", "")))
		EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.pick(mt.get("anuncio", {})), {"tipo": "minitraining", "id": str(mt.get("id", "")), "mention": true})
	if not _pending_warned and game_seconds >= GameState.hhmm_to_seconds("08:00"):
		_pending_warned = true
		GameState.flags[FLAG_MT_WARNED] = true
		var n := minitrainings_pending()
		if n > 0:
			EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.fmt(Loc.pick(_data().get("minitraining_pendiente", {})), {"n": n}), {"tipo": "minitraining_pendiente", "n": n})
			EventBus.ezlak_post.emit("dm:shero", "shero", Loc.pick(_data().get("shero_minitraining", {})), {"tipo": "minitraining_pendiente", "pista": "minitraining", "n": n, "typing_s": 2.0})


func minitrainings_pending() -> int:
	return minitrainings_open.size() - minitrainings_done.size()


## Campus: el jugador completó un minitraining (respondió bien su pregunta).
func complete_minitraining(id: String) -> void:
	if minitrainings_done.has(id):
		return
	minitrainings_done.append(id)
	GameState.flags[FLAG_MT_DONE] = minitrainings_done.duplicate()
	EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.pick(_data().get("minitraining_hecho", {})), {"tipo": "minitraining_hecho", "id": id})


## Lista de allocations ahora (también lo usan las pruebas y las capturas).
func post_list_now() -> Dictionary:
	lists_posted += 1
	GameState.flags[FLAG_LISTS_N] = lists_posted
	var base: Dictionary = (_data().get("lista_base", {}) as Dictionary).get(str(GameState.turno), {})
	var lista: Dictionary = {}
	var parts: Array[String] = []
	for a in GameState.AGENTS:
		if a == GameState.agent:
			continue
		var b := float(base.get(a, 80.0))
		var d := float(_drift.get(a, 0.0)) + _rng.randf_range(-3.0, 2.0)
		_drift[a] = clampf(d, -8.0, 6.0)
		var pct := clampf(b + float(_drift[a]), 55.0, 99.0)
		lista[a] = int(round(pct))
		parts.append("%s AVL %d %%" % [a, int(round(pct))])
	var mine := Metrics.available_pct()
	var evaluable := Metrics.available_evaluable()
	lista[GameState.agent] = int(round(mine))
	parts.append("%s AVL %d %%" % [GameState.agent, int(round(mine))])
	var hora := GameState.clock_text()
	var txt := Loc.fmt(Loc.pick(_data().get("lista", {})), {"hora": hora, "lista": " · ".join(PackedStringArray(parts))})
	var below := evaluable and mine < TARGET
	if below:
		txt += " " + Loc.fmt(Loc.pick(_data().get("lista_bajo", {})), {"agente": GameState.agent})
	var meta := {"tipo": "allocations", "lista": lista, "jugador": GameState.agent, "jugador_pct": mine, "evaluable": evaluable, "target": TARGET, "bajo_target": below, "n": lists_posted, "mention": below}
	EventBus.ezlak_post.emit("#team-familia", "mentor", txt, meta)
	return meta


## Allocation a BO ahora (también lo usan las pruebas y las capturas).
func post_allocation_now() -> void:
	var allocs: Array = _data().get("allocations", [])
	if allocs.is_empty():
		return
	alloc_aux = Metrics.Aux.BO
	var dur := float(GameState.turno_cfg("allocation_bo_min", DataLoader.bal("mentor/duracion_min_juego", 20.0))) * 60.0
	var start := GameState.clock_seconds
	until_clock = start + dur
	active = true
	Metrics.allocation_aux = alloc_aux
	GameState.flags[FLAG_ALLOC_UNTIL] = until_clock
	var a: Dictionary = allocs[_rng.randi_range(0, allocs.size() - 1)]
	var vars := {"desde": _hhmm(start), "hasta": _hhmm(until_clock), "aux": Metrics.aux_name(alloc_aux), "agente": GameState.agent}
	EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.fmt(Loc.pick(a), vars), {"tipo": "allocation_bo", "desde": start, "hasta": until_clock})
	EventBus.ezlak_post.emit("#allocations", "rta", Loc.fmt(Loc.pick(_data().get("rta_orden", {})), vars), {"tipo": "orden_aux", "aux": alloc_aux, "mention": true})
	PerritoRTA.dictate(alloc_aux)
	var comply := float(DataLoader.bal("mentor/cumplir_s", 60.0)) * Difficulty.scale("mentor_cumplir")
	_comply_left = comply
	_comply_pending = Metrics.aux != alloc_aux
	EventBus.allocation_posted.emit(alloc_aux, comply, until_clock)


func _end_allocation() -> void:
	active = false
	_comply_pending = false
	Metrics.allocation_aux = -1
	alloc_aux = -1
	var lines: Array = _data().get("fin_allocation", {}).get("lineas", [])
	if not lines.is_empty():
		EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.pick(lines[_rng.randi_range(0, lines.size() - 1)]), {"tipo": "fin_allocation"})
	if Metrics.expected_aux != Metrics.Aux.AVAILABLE and not GameState.in_contact:
		PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	EventBus.allocation_ended.emit()


## Lamebotas: responde a lo que Shero publica en #team-familia (no a DMs ni a sí mismo).
func _on_post(channel: String, author: String, _text: String, meta: Dictionary) -> void:
	if channel != "#team-familia" or author != "shero" or not GameState.logged_in or bool(meta.get("_lamebotas", false)):
		return
	if _rng.randf() > float(DataLoader.bal("mentor/prob_lamebotas", 0.6)):
		return
	var lines: Array = _data().get("lamebotas", {}).get("lineas", [])
	if lines.is_empty():
		return
	var line: Dictionary = lines[_rng.randi_range(0, lines.size() - 1)]
	await get_tree().create_timer(_rng.randf_range(2.0, 4.5)).timeout
	if is_inside_tree() and GameState.running:
		EventBus.ezlak_post.emit("#team-familia", "mentor", Loc.pick(line), {"tipo": "lamebotas"})


func _hhmm(seconds: float) -> String:
	var s := seconds
	if s < 0.0:
		s += 24.0 * 3600.0
	return "%02d:%02d" % [int(s / 3600.0) % 24, int(s / 60.0) % 60]

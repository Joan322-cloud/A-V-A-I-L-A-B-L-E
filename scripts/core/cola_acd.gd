class_name ColaACD
extends Node
## v0.3.2 (Joan: «las llamadas, chats o correos solo se pueden recibir en Available… tus compañeros también pueden tomar
## llamadas, son agentes como tú… como un call center real»). La cola de KipuPay (ACD) del turno, hija de ContactManager:
##   - Los 4 compañeros (GameState.AGENTS menos el tuyo) son agentes con su propio horario de AUX del turno: Available,
##     en un contacto, BO, break, lunch, coaching, training y (T2/T3) uno que se queda dormido un rato. npc_state(nombre).
##   - Entran contactos de ambiente (los clientes de todos) a cola/llegadas_por_hora (reloj de juego, así los presets de
##     «Duración del turno» también la mueven). Un compañero Available toma el más antiguo y queda «en contacto» su
##     AHT (cola/aht_npc_min_juego). Si nadie está Available la cola crece.
##   - Los contactos del guion del turno que llegan a su hora mientras no estás en Available esperan en la cola; los
##     opcionales (no «fijos», sin cadena, que no son casos de BO) los puede tomar un compañero tras
##     cola/npc_toma_guion_tras_min; los de la historia te esperan a ti.
##   - Al volver a Available con la cola cargada, los contactos te llegan seguidos (back-to-back): pausa mínima de
##     cola/back_to_back_pausa_s_real entre uno y otro, como mucho cola/back_to_back_max[dificultad] seguidos.
## La cola visible (Fonex, HUD) = ambiente + tus guiones esperando. Shero presiona en #team-familia con la cola alta.

const NPC_SEED := 7717

var cm: ContactManager = null
## Contactos de ambiente esperando: reloj de juego de llegada de cada uno.
var ambient: Array[float] = []
## Compañero → reloj de juego en que termina el contacto que está atendiendo.
var npc_busy_until: Dictionary = {}
## Contactos del guion tomados por un compañero (ids) y por quién.
var taken_by_npc: Dictionary = {}
var npc_handled: int = 0
var ambient_arrived: int = 0
var _sched: Dictionary = {}  # compañero → [[desde, hasta, estado], …] (reloj de juego)
var _last_clock: float = -INF
var _arrive_acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _shero_warned_at: float = -INF
var b2b_streak: int = 0  # pausas cortas seguidas de la racha (contactos seguidos = b2b_streak + 1)


func _cfg() -> Dictionary:
	return DataLoader.dict("balance").get("cola_acd", {})


func coworkers() -> Array[String]:
	var out: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			out.append(a)
	return out


## Horario de AUX de los compañeros del turno (determinista por agente y turno).
func reset() -> void:
	ambient.clear()
	npc_busy_until.clear()
	taken_by_npc.clear()
	npc_handled = 0
	ambient_arrived = 0
	_arrive_acc = 0.0
	_last_clock = -INF
	_shero_warned_at = -INF
	b2b_streak = 0
	_rng.seed = hash("%s|%d" % [GameState.agent, GameState.turno]) + NPC_SEED
	_sched.clear()
	var names := coworkers()
	var l := GameState.lunch_clock()
	var lunch_off := [-60.0, 0.0, -15.0, 45.0]  # uno sale contigo; los demás escalonados
	var tr_clock := GameState.training_clock()
	for i in names.size():
		var n := names[i]
		var blocks: Array = []
		for bh in [2.0 + 0.2 * i, 6.3 + 0.15 * i]:
			var b0: float = float(bh) * 3600.0 + _rng.randf_range(-6.0, 6.0) * 60.0
			blocks.append([b0, b0 + 10.0 * 60.0, "break"])
		var l0 := l + float(lunch_off[i % lunch_off.size()]) * 60.0
		blocks.append([l0, l0 + GameState.lunch_minutes() * 60.0, "lunch"])
		if tr_clock >= 0.0 and i % 2 == 0:
			blocks.append([tr_clock, tr_clock + 30.0 * 60.0, "training"])
		var c0 := _rng.randf_range(1.0, 7.5) * 3600.0
		blocks.append([c0, c0 + 10.0 * 60.0, "coaching"])
		var bo0 := _rng.randf_range(0.5, 7.5) * 3600.0
		blocks.append([bo0, bo0 + 20.0 * 60.0, "bo"])
		if GameState.turno >= 2 and i == (GameState.turno + 1) % names.size():
			var s0 := _rng.randf_range(4.5, 6.3) * 3600.0
			blocks.append([s0, s0 + _rng.randf_range(20.0, 40.0) * 60.0, "dormido"])
		_sched[n] = blocks


## Estado del compañero ahora: disponible · contacto · bo · break · lunch · coaching · training · dormido · fuera.
func npc_state(n: String, at: float = INF) -> String:
	var now := GameState.clock_seconds if at == INF else at
	if now < 0.0:
		return "fuera"  # antes de las 00:00 todavía no se loguearon
	var prio := ["dormido", "training", "lunch", "break", "coaching", "bo"]
	var best := ""
	for b in _sched.get(n, []):
		if now >= float(b[0]) and now < float(b[1]):
			if best == "" or prio.find(str(b[2])) < prio.find(best):
				best = str(b[2])
	if best != "":
		return best
	if float(npc_busy_until.get(n, -INF)) > now:
		return "contacto"
	return "disponible"


func available_npcs() -> Array[String]:
	var out: Array[String] = []
	for n in coworkers():
		if npc_state(n) == "disponible":
			out.append(n)
	return out


## Cola visible: ambiente + tus contactos del guion que ya llegaron y esperan (+ v0.3.2-core2: los sustitutos que
## te esperan al repetir un tramo).
func size() -> int:
	return ambient.size() + waiting_scripted().size() + (cm.slots_waiting() if cm != null else 0)


func oldest_wait() -> float:
	var oldest := INF
	for a in ambient:
		oldest = minf(oldest, a)
	for c in waiting_scripted():
		oldest = minf(oldest, ContactManager.clock_of(str(c.get("hora_juego", "00:00"))))
	if cm != null:
		oldest = minf(oldest, cm.slots_oldest())
	return maxf(GameState.clock_seconds - oldest, 0.0) if oldest != INF else 0.0


## Lo que lleva esperando el contacto de AMBIENTE más antiguo (segundos de juego; 0 sin ambiente). Con un compañero
## libre el ambiente no espera: si esto crece es que nadie lo está atendiendo.
func ambient_wait() -> float:
	var oldest := INF
	for a in ambient:
		oldest = minf(oldest, a)
	return maxf(GameState.clock_seconds - oldest, 0.0) if oldest != INF else 0.0


# --- v0.3.2-core2: la cola también rebobina -------------------------------------------------------------------
## Al reaparecer el reloj vuelve al checkpoint, pero la cola se quedaba con lo de la vida anterior: los compañeros
## seguían «en un contacto» hasta la hora en que moriste (horas de juego sin que nadie atendiera: «Cola 21» en el
## HUD), los contactos de ambiente tenían hora de llegada futura y los guiones que un compañero tomó después del
## checkpoint no volvían. Ahora el checkpoint guarda la cola (to_save) y al rebobinar se repone (rewind).

func to_save() -> Dictionary:
	return {
		"ambiente": ambient.duplicate(), "ocupado": npc_busy_until.duplicate(), "tomados": taken_by_npc.duplicate(),
		"acc": _arrive_acc, "atendidos": npc_handled, "llegados": ambient_arrived,
		"shero": _shero_warned_at if _shero_warned_at != -INF else -1.0,
	}


## Repone la cola del checkpoint. Sin datos (checkpoint de una versión anterior): quita lo que «viene del futuro».
func rewind(saved: Dictionary) -> void:
	var now := GameState.clock_seconds
	if saved.has("ambiente"):
		ambient.clear()
		for a in saved.get("ambiente", []):
			ambient.append(minf(float(a), now))
		npc_busy_until.clear()
		var busy: Dictionary = saved.get("ocupado", {})
		for n in busy.keys():
			npc_busy_until[str(n)] = float(busy[n])
		taken_by_npc.clear()
		var taken: Dictionary = saved.get("tomados", {})
		for id in taken.keys():
			taken_by_npc[str(id)] = str(taken[id])
		_arrive_acc = float(saved.get("acc", 0.0))
		npc_handled = int(saved.get("atendidos", npc_handled))
		ambient_arrived = int(saved.get("llegados", ambient_arrived))
		var sh := float(saved.get("shero", -1.0))
		_shero_warned_at = sh if sh >= 0.0 else -INF
	else:
		var kept: Array[float] = []
		for a in ambient:
			if a <= now:
				kept.append(a)
		ambient = kept
		if _shero_warned_at > now:
			_shero_warned_at = -INF
	# Nadie queda «en un contacto» más allá de lo que dura un contacto desde ahora.
	var aht: Array = _cfg().get("aht_npc_min_juego", [4.0, 8.0])
	for n in npc_busy_until.keys():
		if float(npc_busy_until[n]) > now + float(aht[1]) * 60.0:
			npc_busy_until[n] = now + _rng.randf_range(float(aht[0]), float(aht[1])) * 60.0
	_last_clock = now
	b2b_streak = 0


## Guiones (no BO) que ya llegaron y nadie atendió.
func waiting_scripted() -> Array:
	var out: Array = []
	if cm == null:
		return out
	for c in cm.get("_schedule"):
		var id := str(c.get("id", ""))
		if ContactManager.is_bo(c) or (cm.get("_served") as Array).has(id) or taken_by_npc.has(id):
			continue
		if GameState.clock_seconds >= ContactManager.clock_of(str(c.get("hora_juego", "00:00"))):
			if cm.phase != ContactManager.Phase.IDLE and str(cm.current.get("id", "")) == id:
				continue
			out.append(c)
	return out


## ¿Lo puede tomar un compañero? (no de la historia: ni «fijos» ni cadena ni casos de BO).
func npc_can_take(c: Dictionary) -> bool:
	if ContactManager.is_bo(c) or c.has("cadena") or bool(c.get("clave", false)):
		return false
	return not (cm._data().get("fijos", []) as Array).has(str(c.get("id", "")))


func _process(_delta: float) -> void:
	if cm == null or not GameState.running or GameState.shift_over or not GameState.logged_in or get_tree().paused:
		_last_clock = GameState.clock_seconds
		return
	var now := GameState.clock_seconds
	if _last_clock == -INF:
		_last_clock = now
	var dt := clampf(now - _last_clock, 0.0, 600.0)
	_last_clock = now
	if dt <= 0.0:
		return
	# Llegadas de ambiente (por hora de juego, según el bloque del turno).
	var per_h: Array = _cfg().get("llegadas_por_hora", [8.0, 10.0, 7.0])
	var rate := float(per_h[clampi(GameState.current_block() - 1, 0, per_h.size() - 1)]) / 3600.0
	_arrive_acc += dt * rate
	while _arrive_acc >= 1.0:
		_arrive_acc -= 1.0
		ambient.append(now)
		ambient_arrived += 1
	# Los compañeros Available atienden lo más antiguo: primero el ambiente, luego guiones opcionales que esperan.
	var aht: Array = _cfg().get("aht_npc_min_juego", [4.0, 8.0])
	var take_after := float(_cfg().get("npc_toma_guion_tras_min", 8.0)) * 60.0
	for n in available_npcs():
		if not ambient.is_empty():
			ambient.pop_front()
		else:
			var took := false
			for c in waiting_scripted():
				if npc_can_take(c) and now - ContactManager.clock_of(str(c.get("hora_juego", "00:00"))) >= take_after:
					taken_by_npc[str(c.get("id", ""))] = n
					(cm.get("_served") as Array).append(str(c.get("id", "")))  # no te vuelve a sonar
					took = true
					break
			if not took and not cm.npc_take_slot(take_after):  # v0.3.2-core2: sustitutos amontonados
				continue
		npc_handled += 1
		npc_busy_until[n] = now + _rng.randf_range(float(aht[0]), float(aht[1])) * 60.0
	GameState.queue_size = size() + (1 if cm.phase == ContactManager.Phase.OFFERING else 0)
	GameState.flags["cola_espera_s"] = oldest_wait()
	_shero_pressure(now)


## «Hay 9 en cola, ¿dónde están?»: Shero al canal del equipo con la cola alta (sin castigo; como mucho cada 40 min).
func _shero_pressure(now: float) -> void:
	var n := size()
	if n < int(_cfg().get("shero_aviso_cola", 6)) or now - _shero_warned_at < float(_cfg().get("shero_aviso_cada_min", 40.0)) * 60.0:
		return
	if Discipline.is_lunch_immune() or Checkpoints.dying or GameState.is_tutorial():
		return
	_shero_warned_at = now
	var txt := Loc.fmt(TranslationServer.translate("B2_COLA_SHERO"), {"n": n, "espera": Loc.mmss(oldest_wait())})
	EventBus.ezlak_post.emit("#team-familia", "shero", txt, {"tipo": "cola", "n": n, "mention": Metrics.aux != Metrics.Aux.AVAILABLE})


## Te entra uno del ambiente (relleno): sale de la cola.
func took_from_queue() -> void:
	if not ambient.is_empty():
		ambient.pop_front()


## ¿Va en racha? Cola cargada al volver a Available: pausa mínima entre contactos, con tope por dificultad.
func back_to_back() -> bool:
	var maxes: Array = _cfg().get("back_to_back_max", [2, 3, 4])
	var cap := int(maxes[clampi(Difficulty.effective(), 0, maxes.size() - 1)])
	return size() >= int(_cfg().get("back_to_back_desde", 3)) and b2b_streak < cap - 1


func b2b_gap() -> float:
	return float(_cfg().get("back_to_back_pausa_s_real", 2.5))

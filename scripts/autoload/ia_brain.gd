extends Node
## v0.3.2 IA · Cerebro de conversación (autoload IABrain), compartido por los DMs de Ezlaki, el chat con clientes
## y las llamadas por micrófono. Sin red ni modelos: entiende con IANlu y contesta recombinando las líneas
## escritas de data/ia/personas.json (Joan las edita) con su estado:
##   · ánimo (esta noche) y afecto (la semana) por personaje; reacciones por intención, sentimiento y cortesía;
##   · memoria: lo que le contaste (familia, cómo estás, tu examen…), lo que le dijiste (insultos, halagos) y los
##     favores; lo retoma después («oye y tu mamá? ya está mejor?»), también en otro turno (se guarda con la partida);
##   · estilo: escribiendo…, tiempo de reacción, varios mensajes, minúsculas, faltas (Ttoom), se duerme a mitad
##     de frase (Juan), emojis (Rasec), visto sin respuesta (Shero, el OM);
##   · consecuencias con los sistemas que ya existen: faltarle el respeto a Shero = alerta → WW → persecución
##     (muerte «tercer_ww» si te alcanza); halagar a Rasec = te invita a su evento; mentirle a Haime = penalización
##     de calibración; delatar = Obediencia (y el delatado deja de cubrirte); pedir ayuda a un compañero = pista;
##     insultar a un compañero = deja de cubrirte (comodín) y deja de avisarte.
##   · contadores ocultos de la biblia (Obediencia, Rebeldía, Desgaste) por lo que escribes, con su tope por turno.
##
## API:
##   IABrain.reply(quien, canal, texto, ctx = {}) -> {intent, coarse, nlu, mensajes: [{texto, espera}], visto, efectos}
##     (no publica nada: EzlakHub publica los mensajes y aplica la espera). ctx: nlu (análisis ya hecho) · expect ·
##     afirmar_es · sin_efectos (pruebas).
##   IABrain.can_coworker_answer(nombre) -> bool  · IABrain.coworker_comodin(nombre) -> {answers, line, dm, reason}
##     (contrato con el comodín del paquete de bugs: no toca su UI).
##   IABrain.state(quien) -> Dictionary  · IABrain.meters() -> {obe, reb, des}  · IABrain.meter_add(m, v, motivo)
##   IABrain.haime_calibration_penalty() -> int (mentiras a Haime en el turno; Haime/calibración lo puede leer)
##   IABrain.hint() -> String (consejo según lo que pasa ahora)
##   IABrain.remember_fact(quien, hecho) · IABrain.forget_all() (pruebas) · IABrain.save_now()
##   IABrain.presence(quien) -> {estado, texto, corto, color, contesta} · IABrain.presence_state(quien) -> String
##     Estado de Ezlaki de cada personaje, sacado del juego (data/ia/personas.json/presencia): activo · llamada ·
##     lunch · pausa («pausó sus notificaciones») · ausente. Solo un compañero «activo» contesta el comodín.

signal replied(who: String, channel: String, result: Dictionary)
signal consequence(kind: String, info: Dictionary)

const COWORKERS: Array[String] = ["jiroshi", "marko", "llauri", "ttoom", "juan"]
const MAX_FACTS := 24
const MAX_EVENTS := 30
const METER_CAP := 6

var mem: Dictionary = {}  # quien -> estado persistente
var meters_total: Dictionary = {"obe": 0, "reb": 0, "des": 0}
var shift: Dictionary = {}  # contadores del turno
var last: Dictionary = {}  # último resultado (pruebas)
var recent_contacts: Array = []  # [{id, qa, caso, frase}] para saber si le mientes a Haime
var _rng := RandomNumberGenerator.new()
var _cfg_cache: Dictionary = {}
var _loaded_for: String = ""
var _dirty: bool = false
var _save_left: float = 0.0
var _msg_n: int = 0
## Pruebas y videos: quien (minúsculas) -> estado forzado de Ezlaki.
var presence_override: Dictionary = {}
var _shero_state: int = 0
var _epoch: int = 0  # cambia con cada turno / vuelta al menú: lo programado con _later no cruza de partida


func _ready() -> void:
	_rng.randomize()
	_reset_shift()
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.shift_ended.connect(save_now)
	EventBus.returned_to_menu.connect(save_now)
	EventBus.slot_changed.connect(func(_a: String) -> void: _ensure_loaded(true))
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.shero_state_changed.connect(func(st: int) -> void: _shero_state = st)
	EventBus.returned_to_menu.connect(func() -> void:
		presence_override.clear()
		_epoch += 1)


func cfg() -> Dictionary:
	if _cfg_cache.is_empty():
		_cfg_cache = IANlu.load_json("res://data/ia/personas.json")
	return _cfg_cache


func reload() -> void:
	_cfg_cache = {}
	IANlu.reload()


func _process(delta: float) -> void:
	if _dirty:
		_save_left -= delta
		if _save_left <= 0.0:
			save_now()


# --- estado y memoria ---------------------------------------------------------------------------------------

func _reset_shift() -> void:
	shift = {"shero_pts": 0.0, "shero_faltas": 0, "rasec_invitado": false, "gain": {"obe": 0, "reb": 0, "des": 0}, "ok_obe": 0,
		"apoyo_reb": false, "calibracion": 0, "persecucion": false, "delatados": [], "turno": GameState.turno}


func _on_shift_started() -> void:
	_epoch += 1
	_ensure_loaded(false)
	_reset_shift()
	_rng.seed = hash(GameState.agent) + GameState.turno * 7919 + Time.get_ticks_msec()
	for who in mem.keys():
		var st: Dictionary = mem[who]
		var p := persona(str(who))
		var base := float(p.get("animo_base", 0.0)) + 0.3 * float(st.get("afecto", 0.0))
		st["animo"] = lerpf(float(st.get("animo", base)), base, 0.7)


func _path() -> String:
	return SaveSlots.dir_of(GameState.agent) + "ia_memoria.json"


func _ensure_loaded(force: bool) -> void:
	if _loaded_for == GameState.agent and not force:
		return
	if _loaded_for != "" and _dirty:
		save_now()  # la memoria del agente anterior se guarda antes de cambiar
	_loaded_for = GameState.agent
	mem = {}
	meters_total = {"obe": 0, "reb": 0, "des": 0}
	var p := _path()
	if FileAccess.file_exists(p):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if v is Dictionary:
			mem = (v as Dictionary).get("personajes", {})
			meters_total = (v as Dictionary).get("contadores", meters_total)


func save_now() -> void:
	_dirty = false
	if _loaded_for == "":
		return
	var p := SaveSlots.dir_of(_loaded_for) + "ia_memoria.json"
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "agente": _loaded_for, "personajes": mem, "contadores": meters_total}))


func _touch() -> void:
	_dirty = true
	_save_left = 4.0


## Borra toda la memoria (pruebas y «nueva partida» del agente).
func forget_all() -> void:
	mem = {}
	meters_total = {"obe": 0, "reb": 0, "des": 0}
	recent_contacts.clear()
	presence_override.clear()
	_reset_shift()
	_loaded_for = GameState.agent
	_touch()


## Configuración del personaje con la herencia de 'base' (compañeros → «companero»).
func persona(who: String) -> Dictionary:
	var all: Dictionary = cfg().get("personajes", {})
	var key := who
	if not all.has(key):
		key = "companero" if COWORKERS.has(who) else "companero"
	var p: Dictionary = (all.get(key, {}) as Dictionary).duplicate(true)
	var base := str(p.get("base", ""))
	if base != "" and all.has(base):
		var b: Dictionary = (all[base] as Dictionary).duplicate(true)
		for k in ["estilo", "reacciones"]:
			var merged: Dictionary = (b.get(k, {}) as Dictionary).duplicate(true)
			merged.merge(p.get(k, {}), true)
			p[k] = merged
		for k in b.keys():
			if not p.has(k):
				p[k] = b[k]
		p["_base_lineas"] = b.get("lineas", {})
	p["_slug"] = key
	return p


func state(who: String) -> Dictionary:
	_ensure_loaded(false)
	if not mem.has(who):
		var p := persona(who)
		var af := float(p.get("afecto_inicial", 0.0))
		var rel := ""
		var r: Dictionary = (cfg().get("relaciones", {}) as Dictionary).get(who, {})
		if r.has(GameState.agent):
			af = float(r[GameState.agent][0])
			rel = str(r[GameState.agent][1])
		mem[who] = {"animo": float(p.get("animo_base", 0.0)) + 0.3 * af, "afecto": af, "relacion": rel, "insultos": 0, "halagos": 0,
			"mentiras": 0, "debe": 0, "le_debes": 0, "cubre": true, "hechos": [], "eventos": [], "usados": {}, "mensajes": 0, "ultimo_turno": GameState.turno}
	return mem[who]


func band(who: String) -> String:
	var st := state(who)
	var b: Dictionary = cfg().get("bandas", {})
	var m := float(st.get("animo", 0.0)) * 0.7 + float(st.get("afecto", 0.0)) * 0.3
	if m <= float(b.get("hostil", -35)):
		return "hostil"
	if m <= float(b.get("frio", -8)):
		return "frio"
	if m >= float(b.get("calido", 28)):
		return "calido"
	return "neutral"


func remember_fact(who: String, fact: Dictionary) -> void:
	var st := state(who)
	var hs: Array = st["hechos"]
	for h in hs:
		if str(h.get("tipo", "")) == str(fact.get("tipo", "")) and str(h.get("valor", "")) == str(fact.get("valor", "")):
			h["frase"] = fact.get("frase", h.get("frase", ""))
			h["turno"] = GameState.turno
			h["n"] = int(st.get("mensajes", 0))
			return
	var f := fact.duplicate()
	f["turno"] = GameState.turno
	f["hora"] = GameState.clock_text()
	f["ref"] = 0
	f["n"] = int(st.get("mensajes", 0))
	hs.append(f)
	while hs.size() > MAX_FACTS:
		hs.pop_front()
	_touch()


func _event(who: String, kind: String, frase: String) -> void:
	var st := state(who)
	var ev: Array = st["eventos"]
	ev.append({"tipo": kind, "valor": frase.left(60), "turno": GameState.turno, "hora": GameState.clock_text(), "ref": 0, "n": int(st.get("mensajes", 0))})
	while ev.size() > MAX_EVENTS:
		ev.pop_front()


# --- contadores ocultos (biblia §1.2) ----------------------------------------------------------------------

func meters() -> Dictionary:
	_ensure_loaded(false)
	return meters_total.duplicate()


func meter_add(m: String, v: int, motivo: String) -> int:
	_ensure_loaded(false)
	var gain: Dictionary = shift.get("gain", {})
	var g := int(gain.get(m, 0))
	if v > 0:
		v = clampi(v, 0, maxi(0, METER_CAP - g))
	if v == 0:
		return 0
	gain[m] = g + v
	meters_total[m] = int(meters_total.get(m, 0)) + v
	# si el paquete de Narrativa ya tiene sus contadores, también se los pasamos
	for n in ["Narrativa", "Campana", "Contadores", "Medidores"]:
		var node := get_node_or_null("/root/" + n)
		if node != null and node.has_method("add_meter"):
			node.call("add_meter", m, v, "ia:" + motivo)
			break
	consequence.emit("contador", {"contador": m, "valor": v, "motivo": motivo})
	_touch()
	return v


func haime_calibration_penalty() -> int:
	return int(shift.get("calibracion", 0))


func _on_contact_ended(c: Dictionary, _resolved: bool, _angry: bool) -> void:
	var qa: Array = c.get("_qa", [])
	recent_contacts.append({"id": str(c.get("id", "")), "qa": qa.duplicate(), "caso": PcStyle.clean(Loc.pick(c.get("caso", c.get("asunto", {})))).left(50) if c.has("caso") or c.has("asunto") else str(c.get("id", "")),
		"frase": _qa_phrase(c)})
	while recent_contacts.size() > 6:
		recent_contacts.pop_front()


## La frase tuya que dejó la marca de QA (para que Haime te la cite).
func _qa_phrase(c: Dictionary) -> String:
	var ch: Array = c.get("_choices", [])
	var nodes: Dictionary = c.get("nodos", {})
	for k in ch:
		var parts := str(k).split(".")
		if parts.size() < 2 or not nodes.has(parts[0]):
			continue
		for o in (nodes[parts[0]] as Dictionary).get("opciones", []):
			if str(o.get("id", "")) == parts[1] and o.has("qa"):
				return Loc.pick(o).left(70)
	var said: Array = c.get("_dicho", [])
	return str(said.back()).left(70) if not said.is_empty() else ""


# --- respuesta --------------------------------------------------------------------------------------------

func reply(who: String, channel: String, text: String, ctx: Dictionary = {}) -> Dictionary:
	var a: Dictionary = ctx.get("nlu", {})
	if a.is_empty():
		a = IANlu.analyze(text, ctx)
	var intent := str(a.get("intent", "otro"))
	var p := persona(who)
	var st := state(who)
	st["mensajes"] = int(st.get("mensajes", 0)) + 1
	st["ultimo_turno"] = GameState.turno
	_msg_n += 1
	var res := {"intent": intent, "coarse": str(a.get("coarse", "otro")), "nlu": a, "mensajes": [], "visto": false, "efectos": [], "quien": who}
	if intent == "vacio":
		return res
	var before := band(who)
	# 1) memoria de lo que contaste
	for h in a.get("hechos", []):
		remember_fact(who, h)
	# 2) ánimo y afecto
	var reac: Dictionary = p.get("reacciones", {})
	var d := float(reac.get(intent, 0.0))
	d += 8.0 * float(a.get("sentiment", 0.0)) + 5.0 * float(a.get("politeness", 0.0))
	if float(a.get("intensity", 0.0)) > 0.4 and d < 0.0:
		d *= 1.3
	if intent == "insulto":
		d *= [0.5, 0.7, 1.0, 1.6][clampi(int(a.get("severity", 1)), 0, 3)]
	st["animo"] = clampf(float(st.get("animo", 0.0)) + d, -100.0, 100.0)
	st["afecto"] = clampf(float(st.get("afecto", 0.0)) + d * 0.35, -100.0, 100.0)
	if intent in ["insulto", "amenaza"]:
		st["insultos"] = int(st.get("insultos", 0)) + 1
		_event(who, "insulto", text)
	elif intent == "halago":
		st["halagos"] = int(st.get("halagos", 0)) + 1
		_event(who, "halago", text)
	elif intent == "apoyo":
		_event(who, "apoyo", text)
	# 3) consecuencias
	var fx := _consequences(who, channel, intent, a, st, text, ctx)
	res["efectos"] = fx
	# 4) ¿contesta?
	var now_band := band(who)
	var est: Dictionary = p.get("estilo", {})
	var ign: Dictionary = est.get("ignora", {})
	var p_ign := float(ign.get(intent, 0.0)) + float(ign.get(now_band, 0.0))
	if text.contains("?") or bool(ctx.get("nunca_ignora", false)) or fx.has("pista") or intent in ["insulto", "amenaza", "ack", "voy", "ayuda_salud", "delatar", "defensa"]:
		p_ign = 0.0
	if p_ign > 0.0 and _rng.randf() < p_ign:
		res["visto"] = true
		last = res
		replied.emit(who, channel, res)
		_touch()
		return res
	# 5) componer
	var lines: Array[String] = []
	var main := _pick_line(who, p, intent, now_band, a, ctx)
	var kp := str((a.get("slots", {}) as Dictionary).get("kp", ""))
	if who == "vitzo" and kp != "" and intent != "insulto":
		var tx: Dictionary = (DataLoader.dict("casos_bo").get("transacciones", {}) as Dictionary).get(kp, {})
		if tx.is_empty():
			main = Loc.fmt(Loc.pick({"es": "🤖 Vitzo: No encuentro la operación {kp}. Revisa el número en Kardex. 😊", "en": "🤖 Vitzo: I can't find transaction {kp}. Check the number in Kardex. 😊"}), {"kp": kp})
		else:
			main = Loc.fmt(Loc.pick({"es": "🤖 Vitzo: {kp} · {estado} · partner {partner} · {monto}. ¿Te ayudo con algo más? 😊", "en": "🤖 Vitzo: {kp} · {estado} · partner {partner} · {monto}. Anything else? 😊"}),
				{"kp": kp, "estado": Loc.pick(tx.get("estado", {})), "partner": str(tx.get("partner", "")), "monto": str(tx.get("monto", ""))})
	if main != "":
		lines.append(main)
	var rec := _recall(who, p, st, intent, a)
	if rec != "":
		if intent in ["pregunta_personal", "otro", "charla"] and _rng.randf() < 0.5:
			lines.insert(0, rec)
		else:
			lines.append(rec)
	res["mensajes"] = _style(p, lines, a)
	res["banda"] = now_band
	res["banda_antes"] = before
	last = res
	replied.emit(who, channel, res)
	_touch()
	return res


func _lines_for(p: Dictionary, key: String) -> Array:
	var l: Dictionary = p.get("lineas", {})
	if l.has(key):
		return l[key]
	var bl: Dictionary = p.get("_base_lineas", {})
	if bl.has(key):
		return bl[key]
	return []


func _pick_line(who: String, p: Dictionary, intent: String, b: String, a: Dictionary, ctx: Dictionary) -> String:
	var keys: Array[String] = []
	if ctx.has("variante"):
		keys.append("%s.%s" % [intent, str(ctx["variante"])])
	keys.append("%s.%s" % [intent, b])
	keys.append(intent)
	var coarse := str(a.get("coarse", "otro"))
	var pool: Array = []
	var used_key := ""
	for k in keys:
		pool = _lines_for(p, k)
		if not pool.is_empty():
			used_key = k
			break
	if pool.is_empty():
		# las respuestas de la v0.3.1 (Q3) siguen valiendo como respaldo
		var q3r: Dictionary = DataLoader.dict("ezlaki_q3").get("respuestas", {})
		var role := who if q3r.has(who) else ("companero" if COWORKERS.has(who) else "")
		if role != "" and (q3r[role] as Dictionary).has(coarse) and coarse != "otro":
			pool = q3r[role][coarse]
			used_key = "q3:" + coarse
	if pool.is_empty():
		pool = _lines_for(p, "otro")
		used_key = "otro"
	if pool.is_empty():
		return ""
	var st := state(who)
	var usados: Dictionary = st.get("usados", {})
	var u: Array = usados.get(used_key, [])
	var free: Array = []
	for i in pool.size():
		if not u.has(i):
			free.append(i)
	if free.is_empty():
		u.clear()
		free = range(pool.size())
	var idx := int(free[_rng.randi_range(0, free.size() - 1)])
	u.append(idx)
	usados[used_key] = u
	st["usados"] = usados
	return _fill(Loc.pick(pool[idx]), who, a, ctx)


func _fill(t: String, who: String, a: Dictionary, ctx: Dictionary) -> String:
	var dicho := str(a.get("texto", "")).strip_edges()
	if dicho.length() > 48:
		dicho = dicho.left(45) + "…"
	var vars := {"agente": GameState.agent, "hora": GameState.clock_text(), "dicho": dicho, "companero": _other_coworker(who),
		"turno": GameState.turno, "aux": Metrics.aux_name(), "pct": int(Metrics.available_pct()), "n": int(Metrics.available_pct()), "t_aux": Loc.mmss(Metrics.seconds_in_current_aux()),
		"relacion": str(state(who).get("relacion", ""))}
	if t.contains("{pista}"):
		vars["pista"] = hint(str(a.get("norm", "")))
	var slots: Dictionary = a.get("slots", {})
	vars["persona"] = str((slots.get("personas", [""]) as Array)[0]).capitalize() if slots.has("personas") else ""
	vars["lugar"] = str((slots.get("lugares", [""]) as Array)[0]) if slots.has("lugares") else ""
	for k in ctx.get("vars", {}).keys():
		vars[k] = ctx["vars"][k]
	return Loc.fmt(t, vars)


func _other_coworker(who: String) -> String:
	for c in COWORKERS:
		if c != who and c != GameState.agent.to_lower():
			return c.capitalize()
	return "Juan"


func _when(turno: int, n: int, now_n: int) -> String:
	var es := Loc.language != "en"
	if turno < GameState.turno - 1:
		return "el otro turno" if es else "the other shift"
	if turno < GameState.turno:
		return "anoche" if es else "last night"
	if now_n - n <= 3:
		return "recién" if es else "just now"
	return "hace rato" if es else "a while ago"


## Retoma algo que le contaste (o algo que le hiciste). "" si no toca.
func _recall(who: String, p: Dictionary, st: Dictionary, intent: String, a: Dictionary) -> String:
	if intent in ["insulto", "amenaza", "ack", "voy", "ayuda_salud"]:
		return ""
	var rec_lines: Dictionary = (p.get("lineas", {}) as Dictionary).get("recuerdo", {})
	var base_rec: Dictionary = (p.get("_base_lineas", {}) as Dictionary).get("recuerdo", {})
	var now_n := int(st.get("mensajes", 0))
	var cand: Dictionary = {}
	# primero lo que le hiciste: un insulto pesa cuando ahora le pides algo o le agradeces
	if intent in ["gracias", "halago", "favor", "pedir_ayuda", "carino", "disculpa", "saludo"]:
		for e in st.get("eventos", []):
			if str(e.get("tipo", "")) == "insulto" and int(e.get("ref", 0)) == 0 and now_n - int(e.get("n", 0)) >= 1:
				cand = e
	if cand.is_empty() and intent == "favor" and int(st.get("debe", 0)) > 0:
		cand = {"tipo": "favor", "valor": "", "turno": GameState.turno, "n": 0, "ref": 0}
	if cand.is_empty():
		var chance := float(p.get("memoria", 0.5))
		var eager := intent in ["saludo", "pregunta_personal", "charla", "otro", "broma", "contar", "queja"]
		for h in st.get("hechos", []):
			if int(h.get("ref", 0)) == 0 and (now_n - int(h.get("n", 0)) >= 2 or int(h.get("turno", 0)) < GameState.turno):
				cand = h
				break
		if not cand.is_empty() and not eager and _rng.randf() > chance * 0.5:
			cand = {}
	if cand.is_empty():
		return ""
	var tipo := str(cand.get("tipo", ""))
	var pool: Array = rec_lines.get(tipo, base_rec.get(tipo, []))
	if pool.is_empty():
		return ""
	cand["ref"] = int(cand.get("ref", 0)) + 1
	if tipo == "favor":
		st["debe"] = maxi(0, int(st.get("debe", 0)))
	var t := Loc.pick(pool[_rng.randi_range(0, pool.size() - 1)])
	var valor := str(cand.get("valor", ""))
	if tipo in ["insulto", "halago", "apoyo"]:
		valor = valor.strip_edges().left(40)
	return Loc.fmt(_fill(t, who, a, {}), {"valor": valor, "cuando": _when(int(cand.get("turno", GameState.turno)), int(cand.get("n", 0)), now_n)})


## Estilo del personaje → mensajes con su espera (escribiendo…).
func _style(p: Dictionary, lines: Array[String], a: Dictionary) -> Array:
	var est: Dictionary = p.get("estilo", {})
	var out: Array = []
	var parts: Array[String] = []
	for li in lines.size():
		var l := lines[li]
		if l == "":
			continue
		# solo la línea principal se parte en varios mensajes (máx. 3); el recuerdo va entero
		if li == 0 and float(est.get("partir", 0.0)) > 0.0 and _rng.randf() < float(est.get("partir", 0.0)):
			var ss := _sentences(l)
			for k in mini(ss.size(), 3):
				parts.append(ss[k] if k < 2 or ss.size() == 3 else " ".join(ss.slice(2)))
		else:
			parts.append(l)
	var r: Array = est.get("reaccion_s", [1.5, 3.5])
	var ms := float(est.get("ms_por_letra", 35.0))
	for i in parts.size():
		var t := parts[i]
		if _rng.randf() < float(est.get("minusculas", 0.0)):
			t = t.to_lower()
		if float(est.get("faltas", 0.0)) > 0.0 and i < parts.size() - (1 if lines.size() > 1 else 0):
			t = _typos(t, float(est.get("faltas", 0.0)))  # el recuerdo (lo que le contaste) va sin faltas
		if i == parts.size() - 1:
			# primero el signo y después el emoji («…a la hora que sea! 💪», no «…sea. 💪!»); no se exclama tras un emoji
			var last := t.unicode_at(t.length() - 1) if t.length() > 0 else 0
			if _rng.randf() < float(est.get("exclamar", 0.0)) and not t.ends_with("!") and not t.ends_with("?") and last < 0x2000:
				t = t.trim_suffix(".") + "!"
			var emo: Array = est.get("emojis", [])
			if not emo.is_empty() and _rng.randf() < float(est.get("emoji_p", 0.0)) and not t.contains(str(emo[0])):
				t += " " + str(emo[_rng.randi_range(0, emo.size() - 1)])
			if _rng.randf() < float(est.get("perdon", 0.0)) and not t.to_lower().contains("perd") and not t.to_lower().contains("sorry"):
				t += " perdón" if Loc.language != "en" else " sorry"
		var wait := (_rng.randf_range(float(r[0]), float(r[1])) if i == 0 else _rng.randf_range(0.5, 1.2)) + minf(2.0, float(t.length()) * ms / 1000.0)
		wait = minf(wait, 5.0)
		out.append({"texto": t, "espera": wait})
	# Juan se duerme a mitad de frase
	if float(est.get("duerme", 0.0)) > 0.0 and not out.is_empty() and _rng.randf() < float(est.get("duerme", 0.0)):
		var t0 := str(out[0]["texto"])
		if t0.length() > 12:
			out[0]["texto"] = t0.left(int(t0.length() * 0.55)).strip_edges() + "…"
			out.insert(1, {"texto": "perdón. me dormí" if Loc.language != "en" else "sorry. fell asleep", "espera": 4.0})
	return out


func _sentences(t: String) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for i in t.length():
		cur += t[i]
		if t[i] in [".", "?", "!"] and i + 1 < t.length() and t[i + 1] == " " and cur.strip_edges().length() > 6:
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


func _typos(t: String, p: float) -> String:
	var ws := t.split(" ")
	var done := 0
	for i in ws.size():
		var w := ws[i]
		if w.length() >= 5 and done < 2 and _rng.randf() < p * 2.0 and w.is_valid_identifier():
			var k := _rng.randi_range(1, w.length() - 3)
			ws[i] = w.left(k) + w[k + 1] + w[k] + w.substr(k + 2)
			done += 1
	return " ".join(ws)


# --- consecuencias ----------------------------------------------------------------------------------------

func _consequences(who: String, channel: String, intent: String, a: Dictionary, st: Dictionary, text: String, ctx: Dictionary) -> Array:
	var fx: Array = []
	var live := GameState.running and not bool(ctx.get("sin_efectos", false)) and not GameState.is_tutorial()
	match who:
		"shero":
			if intent in ["ack", "ok", "voy"] and int(shift.get("ok_obe", 0)) < 2:
				shift["ok_obe"] = int(shift.get("ok_obe", 0)) + 1
				if meter_add("obe", 1, "shero_" + intent) > 0:
					fx.append("obe")
			elif intent in ["pregunta", "pregunta_caso", "pregunta_personal", "excusa", "defensa", "grasa"]:
				if meter_add("reb", 1, "shero_" + intent) > 0:
					fx.append("reb")
			if intent in ["insulto", "amenaza"]:
				meter_add("reb", 4, "shero_insulto")
				fx.append_array(_shero_disrespect(a, live))
		"rasec":
			if intent == "halago" and not bool(shift.get("rasec_invitado", false)):
				var rc := _rasec()
				if rc != null and live and rc.state == RasecControl.State.LIBRE and not rc.event_done():
					shift["rasec_invitado"] = true
					fx.append("rasec_evento")
					_later(4.0, func() -> void:
						if rc != null and is_instance_valid(rc) and rc.state == RasecControl.State.LIBRE:
							rc.call_event())
				elif rc == null or not live:
					fx.append("rasec_evento_simulado")
		"haime":
			if intent == "defensa":
				var lie := {}
				for c in recent_contacts:
					if not (c.get("qa", []) as Array).is_empty():
						lie = c
				if not lie.is_empty():
					st["mentiras"] = int(st.get("mentiras", 0)) + 1
					shift["calibracion"] = int(shift.get("calibracion", 0)) + 1
					ctx["variante"] = "mentira"
					ctx["vars"] = {"caso": str(lie.get("caso", "")), "frase_qa": str(lie.get("frase", ""))}
					fx.append("calibracion")
					var qa := _qa_node()
					if qa != null and qa.has_method("add_calibration_penalty"):
						qa.call("add_calibration_penalty", 1, "mentira_ezlaki")
					consequence.emit("calibracion", {"caso": lie.get("id", ""), "total": shift["calibracion"]})
				else:
					ctx["variante"] = "verdad"
	# delatar a un compañero (a quien sea que no sea el delatado)
	if intent == "delatar":
		var targets: Array = []
		for n in (a.get("slots", {}) as Dictionary).get("personas", []):
			if COWORKERS.has(str(n)) and str(n) != who and str(n) != GameState.agent.to_lower():
				targets.append(str(n))
		if not targets.is_empty():
			if who in ["shero", "mentor", "om", "rta", "haime"]:
				meter_add("obe", 2, "delatar")
				fx.append("obe")
			for tname in targets:
				var ts := state(tname)
				ts["afecto"] = clampf(float(ts.get("afecto", 0.0)) - 40.0, -100.0, 100.0)
				ts["animo"] = clampf(float(ts.get("animo", 0.0)) - 30.0, -100.0, 100.0)
				ts["cubre"] = float(ts["afecto"]) > _comodin_cfg_f("umbral_afecto", -25.0)
				_event(tname, "insulto", text)
				(shift["delatados"] as Array).append(tname)
				fx.append("delatado:" + tname)
				if live and who in ["shero", "mentor", "om", "rta", "haime"]:
					_later(_rng.randf_range(18.0, 30.0), func() -> void:
						var msg := "oye. le contaste a %s lo mío? ok. ya sé con quién hablo" % who.capitalize() if Loc.language != "en" else "hey. did you tell %s about me? ok. now i know who i'm talking to" % who.capitalize()
						EventBus.ezlak_post.emit("dm:" + tname, tname, msg, {"tipo": "ia_delatado", "typing_s": 2.5}))
	# compañeros
	if COWORKERS.has(who):
		if intent in ["insulto", "amenaza"]:
			st["cubre"] = float(st.get("afecto", 0.0)) > _comodin_cfg_f("umbral_afecto", -25.0)
			if not bool(st["cubre"]):
				fx.append("no_cubre")
		elif intent in ["disculpa", "apoyo", "carino", "gracias"] and float(st.get("afecto", 0.0)) > _comodin_cfg_f("umbral_afecto", -25.0):
			st["cubre"] = true
		if intent == "apoyo" and not bool(shift.get("apoyo_reb", false)):
			shift["apoyo_reb"] = true
			if meter_add("reb", 2, "ayudar_companero") > 0:
				fx.append("reb")
		if intent in ["pedir_ayuda", "pregunta_caso", "pregunta"] and band(who) != "hostil":
			fx.append("pista")
		if intent == "favor":
			st["debe"] = int(st.get("debe", 0))
	if intent == "ayuda_salud" and who != "shero":
		fx.append("sugiere_topico")
	for e in fx:
		consequence.emit(str(e), {"quien": who, "canal": channel, "intent": intent})
	return fx


## Faltarle el respeto a Shero: escalera propia (sobre la de Metrics): 1.ª falta alerta/verbal, después WW
## (con su Ack), y si sigues o lo amenazas, sale a buscarte (Pursuit; si te alcanza, «tercer_ww»).
func _shero_disrespect(a: Dictionary, live: bool) -> Array:
	var fx: Array = []
	var sev := clampi(int(a.get("severity", 1)), 1, 3)
	var pts: float = [0.0, 1.0, 2.0, 4.0][sev]
	if str(a.get("intent", "")) == "amenaza":
		pts = 6.0
	var k := 1.5 if Difficulty.effective() == Difficulty.Level.FACIL else (0.8 if Difficulty.effective() == Difficulty.Level.DIFICIL else 1.0)
	shift["shero_pts"] = float(shift.get("shero_pts", 0.0)) + pts
	shift["shero_faltas"] = int(shift.get("shero_faltas", 0)) + 1
	var total := float(shift["shero_pts"])
	var st := state("shero")
	if total >= 6.0 * k and not bool(shift.get("persecucion", false)):
		shift["persecucion"] = true
		fx.append("persecucion")
		if live:
			_later(2.5, func() -> void: _shero_chase())
	elif total >= 3.0 * k or int(shift["shero_faltas"]) >= 2:
		fx.append("ww")
		if live and not Checkpoints.dying:
			Metrics.issue_written_warning("insulto")
	else:
		fx.append("verbal")
		if live and not Checkpoints.dying:
			Metrics.report_miss("insulto")  # 1.ª vez alerta (verbal); si ya hubo alerta, WW
	st["animo"] = minf(float(st.get("animo", 0.0)), -40.0)
	return fx


## Reaccionar con un emoji burlón (😂 🤡 💀 🙄) a un aviso: cuenta como falta de respeto (leve) a su autor.
func react_disrespect(who: String, channel: String, emoji: String) -> Dictionary:
	var a := {"texto": emoji, "intent": "insulto", "coarse": "insulto", "severity": 1, "sentiment": -0.4, "politeness": -0.6, "intensity": 0.0, "slots": {}, "hechos": [], "scores": {"insulto": 1.5}}
	return reply(who, channel, emoji, {"nlu": a, "vars": {"emoji": emoji}, "variante": "emoji"})


func _shero_chase() -> void:
	if not GameState.running or Checkpoints.dying or Pursuit.is_hunting("shero"):
		return
	var speed := float(DataLoader.dict("escalada").get("persecucion", {}).get("velocidad_shero_ms", 4.6)) if DataLoader.dict("escalada").has("persecucion") else 4.6
	var detail := "Falta de respeto al supervisor (Ezlaki)" if Loc.language != "en" else "Disrespecting the supervisor (Ezlaki)"
	EventBus.ezlak_post.emit("#team-familia", "shero", Loc.pick({"es": "@%s. Quédate donde estás." % GameState.agent, "en": "@%s. Stay where you are." % GameState.agent}), {"tipo": "ia_persecucion", "mention": true})
	Pursuit.start("shero", "tercer_ww", speed, null, detail)
	consequence.emit("persecucion", {"quien": "shero"})


func _rasec() -> RasecControl:
	var h := PersonajesP5.get_hub(get_tree())
	return h.rasec if h != null else null


func _qa_node() -> Node:
	var h := PersonajesP5.get_hub(get_tree())
	return h.qa if h != null else null


## Algo para dentro de `s` segundos… si sigues en el mismo turno (lo pendiente no salta a otra partida ni al menú).
func _later(s: float, f: Callable) -> void:
	var epoch := _epoch
	await get_tree().create_timer(s).timeout
	if epoch == _epoch and GameState.running:
		f.call()


# --- presencia: el estado de Ezlaki de cada personaje ---------------------------------------------------------
## Una pista legible: el estado sale de lo que el personaje está haciendo de verdad.
##   compañeros → su AUX en la cola (ColaACD.npc_state): Available/BO = activo · en un contacto o en coaching (Rooms) =
##     en llamada · lunch = en lunch · break, training o dormido = ausente. Solo «activo» contesta el comodín.
##   Shero → activo = está leyendo el canal o dando vueltas; en llamada = en reunión (la calma) o en un coaching
##     por Rooms (el tuyo o el de un compañero): ahí no lee los canales (sí su DM).
##   Haime → en llamada durante un feedback · Tópico → en llamada con un paciente · Rasec → ausente en su evento ·
##   OM → solo de día (horario) · el Trainer → SIEMPRE «pausó sus notificaciones»… y contesta al instante.
const PRESENCE: Array[String] = ["activo", "llamada", "lunch", "pausa", "ausente"]
const PRESENCE_COLOR := {"activo": "#3fc77a", "llamada": "#e8503f", "lunch": "#edb845", "pausa": "#a48fe0", "ausente": "#6a7682"}


func _acd() -> ColaACD:
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	return cm.acd if cm != null else null


## El compañero que el miércoles (turno 3) ya no está en la sala desde cierta hora ("" si no aplica ahora).
func off_floor_t3(ignore_clock: bool = false) -> String:
	var f: Dictionary = (cfg().get("presencia", {}) as Dictionary).get("fuera_t3", {})
	if f.is_empty() or GameState.turno != int(f.get("turno", 3)):
		return ""
	if not ignore_clock and GameState.clock_seconds < GameState.hhmm_to_seconds(str(f.get("desde", "06:45"))):
		return ""
	var q: Dictionary = f.get("quien", {})
	return str(q.get(GameState.agent, q.get("default", "")))


func presence_state(who: String) -> String:
	var w := who.to_lower()
	if presence_override.has(w):
		return str(presence_override[w])
	var pc: Dictionary = cfg().get("presencia", {})
	var fijo: Dictionary = pc.get("fijo", {})
	if fijo.has(w):
		return str(fijo[w])
	if COWORKERS.has(w):
		if w == GameState.agent.to_lower():
			return "activo"
		if off_floor_t3() == w:
			return "ausente"
		var acd := _acd()
		if acd == null:
			return "activo"
		var name := w.capitalize()
		for a in GameState.AGENTS:
			if a.to_lower() == w:
				name = a
		return str((pc.get("acd", {}) as Dictionary).get(acd.npc_state(name), "activo"))
	var h := PersonajesP5.get_hub(get_tree())
	match w:
		"shero":
			if GameState.in_calm or GameState.clock_override == "coaching_sesion" or _shero_state == Shero.State.COACHING:
				return "llamada"
			var acd2 := _acd()
			if acd2 != null:
				for n in acd2.coworkers():
					if acd2.npc_state(n) == "coaching":
						return "llamada"
			return "activo"
		"haime":
			return "llamada" if h != null and h.qa != null and h.qa.state == QaFeedback.State.SESION else "activo"
		"rasec":
			return "ausente" if h != null and h.rasec != null and h.rasec.state == RasecControl.State.EVENTO else "activo"
		"enfermera":
			return "llamada" if h != null and h.topico != null and h.topico.state == TopicoControl.State.ATENCION else "activo"
	var hor: Dictionary = pc.get("horario", {})
	if hor.has(w):
		for win in hor[w]:
			if GameState.clock_seconds >= GameState.hhmm_to_seconds(str(win[0])) and GameState.clock_seconds < GameState.hhmm_to_seconds(str(win[1])):
				return "activo"
		return "ausente"
	return "activo"


## {estado, texto («pausó sus notificaciones»), corto (para la barra lateral), color, contesta (el comodín)}.
func presence(who: String) -> Dictionary:
	var st := presence_state(who)
	var key := "IA_PRES_" + st.to_upper()
	var short := tr(key + "_CORTO")
	return {"estado": st, "texto": tr(key), "corto": short if short != key + "_CORTO" else tr(key),
		"color": str(PRESENCE_COLOR.get(st, "#6a7682")), "contesta": st == "activo"}


# --- pistas y comodín --------------------------------------------------------------------------------------

func hint(topic_text: String = "") -> String:
	var ps: Dictionary = cfg().get("pistas", {})
	# si preguntas por un tema concreto, la pista es de ese tema
	if topic_text != "":
		var pt: Dictionary = cfg().get("pistas_tema", {})
		for k in pt.keys():
			if k != "_comentario" and topic_text.contains(" " + str(k)):
				return Loc.pick(pt[k])
	var hub := EzlakHub.get_hub(get_tree())
	if Metrics.ack_pending:
		return Loc.pick(ps.get("ack", {}))
	if hub != null and hub.rooms_pending:
		return Loc.pick(ps.get("rooms", {}))
	var rc := _rasec()
	if rc != null and rc.state == RasecControl.State.CONVOCADO:
		return Loc.pick(ps.get("rasec", {}))
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	if cm != null and cm.phase == ContactManager.Phase.ACTIVE:
		if cm.tree != null:
			var trap := false
			for o in cm.tree.options():
				if str(o.get("tipo", "")) in ["trampa", "fuera"]:
					trap = true
			var arq: Dictionary = (cm._data().get("arquetipos", {}) as Dictionary).get(str(cm.current.get("arquetipo", "")), {})
			var calma: Array = arq.get("calma", [])
			if trap and _rng.randf() < 0.4:
				return Loc.pick(ps.get("contacto_trampa", {}))
			return Loc.pick(ps.get("contacto_empatia" if calma.has("empatia") and not calma.has("proceso") else "contacto_proceso", {}))
		return Loc.pick(ps.get("correo", {}))
	var gen: Array = ps.get("general", [])
	return Loc.pick(gen[_rng.randi_range(0, gen.size() - 1)]) if not gen.is_empty() else ""


func _comodin_cfg_f(k: String, d: float) -> float:
	return float((cfg().get("comodin", {}) as Dictionary).get(k, d))


## Contrato con el comodín (paquete de bugs): ¿te contesta este compañero si lo llamas para que te marque el AUX?
func can_coworker_answer(name: String) -> bool:
	return bool(coworker_comodin(name, false).get("answers", false))


## Decide y (si commit) registra el favor y programa el DM de después. {answers, line, dm, reason}
## `asumir_activo` (v0.3.2-core): cuando lo llamaste su estado decía «activo» (así lo viste en el panel del comodín):
## contesta aunque en los segundos del timbre le haya entrado un contacto.
func coworker_comodin(name: String, commit: bool = true, asumir_activo: bool = false) -> Dictionary:
	var who := name.to_lower()
	var cc: Dictionary = cfg().get("comodin", {})
	var st := state(who)
	var res := {"answers": true, "line": "", "dm": "", "reason": "ok", "quien": who}
	var af := float(st.get("afecto", 0.0))
	var an := float(st.get("animo", 0.0))
	var pres := "activo" if asumir_activo else presence_state(who)
	res["estado"] = pres
	if pres != "activo":  # en llamada, en lunch, ausente: no ve el teléfono (lo dice su estado de Ezlaki)
		res["answers"] = false
		res["reason"] = "presencia"
	elif not bool(st.get("cubre", true)) or af <= float(cc.get("umbral_afecto", -25.0)):
		res["answers"] = false
		res["reason"] = "rencor"
	elif an <= float(cc.get("umbral_animo", -40.0)):
		res["answers"] = false
		res["reason"] = "molesto"
	elif (shift.get("delatados", []) as Array).has(who):
		res["answers"] = false
		res["reason"] = "delatado"
	var r := RandomNumberGenerator.new()
	r.seed = hash(who) + GameState.turno * 31 + int(st.get("mensajes", 0))
	if bool(res["answers"]):
		var c: Array = cc.get("contesta", [])
		var d: Array = cc.get("dm_despues", [])
		res["line"] = Loc.pick(c[r.randi_range(0, c.size() - 1)]) if not c.is_empty() else ""
		res["dm"] = Loc.pick(d[r.randi_range(0, d.size() - 1)]) if not d.is_empty() else ""
	else:
		var key := "rechaza" if not (str(res["reason"]) in ["molesto", "presencia"]) else "no_contesta"
		var c2: Array = cc.get(key, [])
		var d2: Array = cc.get("dm_rechazo", [])
		if str(res["reason"]) == "presencia":  # no te odia: después ve la llamada perdida y te escribe
			d2 = cc.get("dm_ocupado", []) if bool(st.get("cubre", true)) and af > float(cc.get("umbral_afecto", -25.0)) else []
		res["line"] = Loc.pick(c2[r.randi_range(0, c2.size() - 1)]) if not c2.is_empty() else ""
		res["dm"] = Loc.fmt(Loc.pick(d2[r.randi_range(0, d2.size() - 1)]), {"estado": str(presence(who)["texto"])}) if not d2.is_empty() else ""
	if commit:
		if bool(res["answers"]):
			st["debe"] = int(st.get("debe", 0)) + 1  # ahora le debes un favor
			_event(who, "favor", "comodín")
		if str(res["dm"]) != "":
			var hub := EzlakHub.get_hub(get_tree())
			if hub != null:
				hub.call("_ensure", "dm:" + who)
			var dm_text := str(res["dm"])
			if str(res["reason"]) == "presencia":  # la llamada perdida la ve cuando se desocupa
				_later(_rng.randf_range(20.0, 35.0), func() -> void: EventBus.ezlak_post.emit("dm:" + who, who, dm_text, {"tipo": "ia_comodin", "typing_s": 3.0}))
			else:
				EventBus.ezlak_post.emit("dm:" + who, who, dm_text, {"tipo": "ia_comodin", "typing_s": 3.0})
		consequence.emit("comodin", res)
		_touch()
	return res

class_name IACustomer
extends RefCounted
## v0.3.2 IA · Cerebro del cliente (chat y llamadas). Lo que escribes o dices se compara con las opciones del nodo
## actual del árbol: parecido de palabras (con las faltas ya corregidas, pesando más las que distinguen a una opción
## de las otras) + parecido de intención (IANlu analiza también el texto de cada opción). Si la mejor pasa el
## umbral, cuenta como esa opción (el árbol, el final, la nota de QA y el AHT son los de siempre). Si no, el
## cliente contesta en personaje (data/ia/clientes.json, por arquetipo) y su ánimo cambia según cómo le hablaste.
##
## API: IACustomer.prepare(contacto) · IACustomer.match_option(arbol, texto, nlu) -> {i, score, ranking, umbral}
##      IACustomer.offscript(contacto, arbol, nlu, n_fuera) -> {texto: {es,en}, audio, animo, clave}

const W_LEX := 0.48
const W_INT := 0.52

static var _prepared: Dictionary = {}
static var _opt_cache: Dictionary = {}  # texto de opción -> {stems, scores}


static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if not _cache.has("c"):
		_cache["c"] = IANlu.load_json("res://data/ia/clientes.json")
	return _cache["c"]


## Enseña al corrector las palabras del árbol (para que «nmero de operasion» se entienda).
static func prepare(c: Dictionary) -> void:
	var id := str(c.get("id", ""))
	if _prepared.has(id):
		return
	_prepared[id] = true
	var words: Array = []
	for n in (c.get("nodos", {}) as Dictionary).values():
		for o in (n as Dictionary).get("opciones", []):
			for lang in ["es", "en"]:
				for w in IANlu._basic_tokens(IANlu._apply_phrases(IANlu._clean(str(o.get(lang, ""))))):
					if w.length() >= 4:
						words.append(w)
	IANlu.learn_words(words)


static func _opt_info(o: Dictionary) -> Dictionary:
	var key := str(o.get("es", "")) + "|" + str(o.get("en", ""))
	if _opt_cache.has(key):
		return _opt_cache[key]
	var es := IANlu.stems(str(o.get("es", "")))
	var en := IANlu.stems(str(o.get("en", "")))
	var en_raw := IANlu.stems(str(o.get("en", "")), true)  # v0.3.2-core: el inglés palabra por palabra (sin el léxico)
	var a := IANlu.analyze(str(o.get("es", "")), {"dominio": "cs"})
	var info := {"es": es, "en": en, "en_raw": en_raw, "scores": a.get("scores", {}), "intent": a.get("intent", "otro")}
	_opt_cache[key] = info
	return info


static func threshold() -> float:
	var d := data()
	if GameState.is_real_mode() or Difficulty.effective() == Difficulty.Level.DIFICIL:
		return float(d.get("umbral_dificil", 0.26))
	return float(d.get("umbral", 0.3))


static func match_option(t: DialogTree, text: String, nlu: Dictionary = {}) -> Dictionary:
	if nlu.is_empty():
		nlu = IANlu.analyze(text, {"dominio": "cs"})
	var opts := t.options()
	var res := {"i": -1, "score": 0.0, "ranking": [], "umbral": threshold()}
	if opts.is_empty():
		return res
	var said := IANlu.stems(text)
	if said.is_empty():
		return res
	var said_raw := IANlu.stems(text, true)
	var infos: Array = []
	var df := {}
	var df_raw := {}
	for o in opts:
		var inf := _opt_info(o)
		infos.append(inf)
		var seen := {}
		for s in (inf["es"] as PackedStringArray) + (inf["en"] as PackedStringArray):
			if not seen.has(s):
				seen[s] = true
				df[s] = int(df.get(s, 0)) + 1
		var seen_raw := {}
		for s in (inf["en_raw"] as PackedStringArray):
			if not seen_raw.has(s):
				seen_raw[s] = true
				df_raw[s] = int(df_raw.get(s, 0)) + 1
	var pscores: Dictionary = nlu.get("scores", {})
	var tipo_map: Dictionary = data().get("tipo_por_intencion", {})
	var best := -1
	var best_s := 0.0
	var second := 0.0
	var ranking: Array = []
	for i in opts.size():
		var inf: Dictionary = infos[i]
		var lex := maxf(_lex(said, inf["es"], df, opts.size()), _lex(said, inf["en"], df, opts.size()))
		lex = maxf(lex, _lex(said_raw, inf["en_raw"], df_raw, opts.size()))
		var it := _cos(pscores, inf["scores"])
		# respaldo por tipo de opción (empatía / proceso / cierre / trampa / fuera)
		var tipo := str((opts[i] as Dictionary).get("tipo", ""))
		var tp := 0.0
		for k in pscores.keys():
			if str(tipo_map.get(k, "")) == tipo:
				tp = maxf(tp, clampf(float(pscores[k]) / 3.0, 0.0, 1.0))
		if str((opts[i] as Dictionary).get("accion", "")) == "hold" and pscores.has("cs_hold"):
			tp = maxf(tp, clampf(float(pscores["cs_hold"]) / 2.5, 0.0, 1.0))
		var s := W_LEX * lex + W_INT * maxf(it, tp * 0.85)
		ranking.append([i, snappedf(s, 0.001), snappedf(lex, 0.001), snappedf(it, 0.001), snappedf(tp, 0.001)])
		var fine_intent := str(nlu.get("intent", "otro"))
		if fine_intent in ["cs_empatia", "disculpa", "apoyo"] and tipo == "empatia":
			s += 0.24
		elif fine_intent in ["cs_proceso", "pregunta_caso", "cs_escalar"] and tipo == "proceso":
			s += 0.24
		elif fine_intent in ["cs_info", "cs_cierre", "cs_reembolso", "ok"] and tipo == "cierre":
			s += 0.24
		elif fine_intent in ["cs_calmese", "cs_procedimiento", "insulto", "amenaza"] and tipo in ["trampa", "fuera"]:
			s += 0.26
		var slots: Dictionary = nlu.get("slots", {})
		if not slots.is_empty() and tipo in ["proceso", "cierre"]:
			s += 0.14
		if s > best_s:
			second = best_s
			best_s = s
			best = i
		elif s > second:
			second = s
	res["ranking"] = ranking
	res["score"] = best_s
	var fine := str(nlu.get("intent", "otro"))
	if best >= 0 and best_s < float(res["umbral"]) and fine in ["cs_empatia", "disculpa", "cs_proceso", "pregunta_caso", "cs_info", "cs_cierre", "cs_reembolso", "cs_escalar"]:
		for idx in opts.size():
			var tp_opt := str((opts[idx] as Dictionary).get("tipo", ""))
			if tp_opt in ["empatia", "proceso", "cierre"]:
				best = idx
				best_s = maxf(best_s, float(res["umbral"]) + 0.02)
				break
	if best >= 0 and best_s >= float(res["umbral"]):
		res["i"] = best
	return res


static func _lex(said: PackedStringArray, opt: PackedStringArray, df: Dictionary, n_opts: int) -> float:
	if opt.is_empty():
		return 0.0
	var w := func(s: String) -> float:
		var base := 1.0 if s.length() >= 4 else 0.55
		var d := int(df.get(s, 0))
		return base * (1.0 if d <= 1 else (0.55 if d < n_opts else 0.3))
	var so := {}
	for s in opt:
		so[s] = true
	var ss := {}
	for s in said:
		ss[s] = true
	var inter := 0.0
	var a := 0.0
	var b := 0.0
	for s in ss.keys():
		var v: float = w.call(s)
		a += v
		if so.has(s):
			inter += v
	for s in so.keys():
		b += w.call(s)
	if a <= 0.0 or b <= 0.0:
		return 0.0
	return inter / sqrt(a * b)


static func _cos(a: Dictionary, b: Dictionary) -> float:
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for k in a.keys():
		var x := maxf(0.0, float(a[k]))
		na += x * x
		if b.has(k):
			dot += x * maxf(0.0, float(b[k]))
	for k in b.keys():
		var y := maxf(0.0, float(b[k]))
		nb += y * y
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	return dot / sqrt(na * nb)


## Respuesta del cliente a algo que no encaja con ninguna opción.
static func offscript(c: Dictionary, t: DialogTree, nlu: Dictionary, n_fuera: int) -> Dictionary:
	var d := data()
	var intent := str(nlu.get("intent", "otro"))
	var key := "no_entiende"
	match intent:
		"insulto", "amenaza": key = "insulto"
		"saludo", "cs_saludo": key = "saludo"
		"cs_empatia", "disculpa", "apoyo", "gracias": key = "empatia"
		"cs_proceso", "pregunta_caso": key = "dato"
		"cs_hold": key = "espera"
		"charla", "broma", "carino", "renuncia", "grasa", "azotea": key = "charla"
		"pregunta_personal": key = "pregunta_personal"
		"ok", "ack", "voy", "cs_cierre", "cs_info": key = "ok"
		"no_se": key = "no_se"
		"cs_calmese": key = "calmese"
		"cs_procedimiento", "negar": key = "procedimiento"
	if n_fuera >= 1 and key in ["no_entiende", "ok", "charla", "empatia"] and n_fuera % 2 == 1:
		key = "repite"
	var arq: Dictionary = (d.get("arquetipos", {}) as Dictionary).get(str(c.get("arquetipo", "")), {})
	var pool: Array = (arq.get("lineas", {}) as Dictionary).get(key, [])
	# en una llamada solo vale lo que tiene voz grabada: las reacciones genéricas con clip
	if str(c.get("canal", "")) == "llamada":
		var gp: Array = ((d.get("generico", {}) as Dictionary).get(key, []) as Array).filter(func(x: Dictionary) -> bool: return x.has("clip"))
		if not gp.is_empty():
			pool = gp
	var generic := pool.is_empty() or (pool[0] as Dictionary).has("clip")
	if pool.is_empty():
		pool = (d.get("generico", {}) as Dictionary).get(key, [])
	if pool.is_empty():
		pool = (d.get("generico", {}) as Dictionary).get("no_entiende", [])
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(c.get("id", ""))) + n_fuera * 131 + t.history.size()
	var line: Dictionary = (pool[r.randi_range(0, pool.size() - 1)] as Dictionary).duplicate()
	var need := Loc.pick(t.client_line()) if not t.ended() else ""
	var first := need.split(". ")[0] if need != "" else ""
	var tx := str((c.get("portal", {}) as Dictionary).get("tx", ""))
	if tx == "":
		var re := RegEx.new()
		re.compile("KP-\\d{4}-\\d{4}")
		var m := re.search(Loc.pick(c.get("caso", {})))
		tx = m.get_string() if m != null else "KP-…"
	for lang in ["es", "en"]:
		line[lang] = Loc.fmt(str(line.get(lang, "")), {"necesidad": first, "tx": tx})
	var an: Dictionary = d.get("animo", {})
	var delta := float(an.get(intent, an.get("otro", -5.0)))
	delta += 5.0 * float(nlu.get("sentiment", 0.0)) + 4.0 * float(nlu.get("politeness", 0.0))
	if float(nlu.get("intensity", 0.0)) > 0.4 and delta < 0.0:
		delta *= 1.3
	var paciencia := float(((c.get("_arq_cfg", {}) as Dictionary)).get("paciencia", 60.0))
	if delta < 0.0:
		delta *= clampf(80.0 / maxf(paciencia, 20.0), 0.6, 1.8)
	# clip ya grabado: las reacciones genéricas existen en la voz de cada arquetipo (clientes.json/voces)
	var clip := str(line.get("clip", ""))
	if clip != "" and generic:
		clip += "_" + str(((d.get("voces", {}) as Dictionary).get("por_arquetipo", {}) as Dictionary).get(str(c.get("arquetipo", "")), "amable"))
	return {"texto": {"es": str(line.get("es", "")), "en": str(line.get("en", ""))}, "audio": clip, "animo": delta, "clave": key}

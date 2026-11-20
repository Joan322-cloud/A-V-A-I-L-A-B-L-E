class_name IANlu
extends RefCounted
## v0.3.2 IA · Comprensión del texto libre (Ezlaki, chat con clientes y lo que dijiste por micrófono). Sin red y
## sin modelos: normaliza (tildes, mayúsculas, letras repetidas, jerga peruana y abreviaturas de data/ia/nlu.json),
## corrige faltas (una palabra desconocida se cambia por la conocida más parecida a 1-2 letras), recorta sufijos
## (plural, género, infinitivo) y suma los patrones de cada intención (frases en orden, con relleno perdonado).
## Devuelve también sentimiento, cortesía, intensidad (MAYÚSCULAS, «!!!»), datos (KP, números, hora, personas,
## lugares) y «hechos» que el jugador cuenta de sí mismo («mi mamá…», «estoy cansado», «tengo examen») para la
## memoria de los personajes.
##
## API: IANlu.analyze(texto, ctx = {}) -> {texto, norm, tokens, intent, coarse, score, top, sentiment, politeness,
##        intensity, severity, slots, hechos}
##      ctx: expect (Array de intenciones que el personaje espera: +0.6) · dominio ("cs" = hablas con un cliente:
##        las intenciones de atención al cliente pesan ×1.2; fuera de una llamada/chat ×0.85) · afirmar_es (una intención: «sí/ok/dale»
##        cuenta como esa, p. ej. "voy" en una invitación a Rooms o "ack" con un WW pendiente).
##      IANlu.classify(texto) -> intención fina · IANlu.coarse_of(fina, texto) -> intención v0.3.1 (Q3).
##      IANlu.stems(texto) -> palabras útiles recortadas (para comparar con las opciones de un árbol).

const MIN_SCORE := 0.6
const NEGATABLE: Array[String] = ["insulto", "halago", "queja", "ayuda_salud", "ok", "voy", "ack", "gracias", "carino"]

static var _d: Dictionary = {}
static var _index: Dictionary = {}  # primer stem -> [[intent, stems:PackedStringArray, peso]]
static var _vocab: Dictionary = {}  # palabra canónica -> true
static var _by_len: Dictionary = {}  # largo -> [palabras]
static var _fix_cache: Dictionary = {}
static var _stop: Dictionary = {}
static var _base: Dictionary = {}  # frases/jerga/stop de nlu.json sin el léxico inglés (ver _merge_en)
static var _filler: Dictionary = {}
static var _sent: Dictionary = {}
static var _leves: Array = []
static var _graves: Array = []


static func data() -> Dictionary:
	if _d.is_empty():
		_compile()
	return _d


static func reload() -> void:
	_d = {}
	_index = {}
	_vocab = {}
	_by_len = {}
	_fix_cache = {}


## JSON sin pasar por DataLoader (así IANlu sirve también en herramientas sin autoloads).
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


static func _compile() -> void:
	_d = load_json("res://data/ia/nlu.json")
	_merge_en()
	_index = {}
	_vocab = {}
	_by_len = {}
	_fix_cache = {}
	_stop = {}
	_filler = {}
	_sent = {}
	for w in _d.get("stop", []):
		_stop[str(w)] = true
	for w in _d.get("relleno", []):
		_filler[stem(str(w))] = true
	var jerga: Dictionary = _d.get("jerga", {})
	for k in jerga.keys():
		for w in str(jerga[k]).split(" ", false):
			_add_vocab(w)
	var ints: Dictionary = _d.get("intenciones", {})
	for intent in ints.keys():
		for p in (ints[intent] as Dictionary).get("p", []):
			var s := str(p)
			var w := 1.0
			var bar := s.rfind("|")
			if bar > 0:
				w = float(s.substr(bar + 1))
				s = s.left(bar)
			var raw := _basic_tokens(_apply_phrases(_clean(s)), false)
			for t in raw:
				_add_vocab(t)
			var st := PackedStringArray()
			for t in raw:
				st.append(stem(t))
			if st.is_empty():
				continue
			if not _index.has(st[0]):
				_index[st[0]] = []
			(_index[st[0]] as Array).append([str(intent), st, w])
	for grp in ["pos", "neg"]:
		var lex: Dictionary = (_d.get("sentimiento", {}) as Dictionary).get(grp, {})
		for k in lex.keys():
			_sent[stem(str(k))] = float(lex[k])
			_add_vocab(str(k))
	var ent: Dictionary = _d.get("entidades", {})
	for grp in ["personas", "lugares"]:
		for k in (ent.get(grp, {}) as Dictionary).keys():
			for alias in (ent[grp][k] as Array):
				for w in str(alias).split(" ", false):
					_add_vocab(w)
	for grp in ["familia", "estados"]:
		for w in ent.get(grp, []):
			_add_vocab(str(w))
	for w in _d.get("vocabulario_extra", []):
		_add_vocab(str(w))
	_leves = (_d.get("insultos_leves", []) as Array).map(func(x: Variant) -> String: return " " + str(x) + " ")
	_graves = (_d.get("insultos_graves", []) as Array).map(func(x: Variant) -> String: return " " + str(x) + " ")


## v0.3.2-core · Inglés: data/ia/nlu_en.json cambia frases y palabras inglesas por la frase española que el motor ya
## entiende (el motor de intenciones es español). Se mezcla aquí con nlu.json: las frases inglesas van primero (de la
## más larga a la más corta) y lo que ya estaba en nlu.json manda. Así lo que el jugador ESCRIBE en inglés al cliente
## o en Ezlaki se clasifica igual que en español. La voz sigue siendo solo en español (Vosk).
static func _merge_en() -> void:
	# Lo de nlu.json tal cual, para comparar un texto inglés «en crudo» (stems(texto, true)): al reescribir a mano la
	# frase inglesa de una opción (palabras de menos, una falta) las frases del léxico dejan de encajar, y comparar
	# palabra por palabra en inglés acierta más. IACustomer usa las dos comparaciones y se queda con la mejor.
	_base = {"frases": (_d.get("frases", {}) as Dictionary).duplicate(), "jerga": (_d.get("jerga", {}) as Dictionary).duplicate(), "stop": {}}
	for w in _d.get("stop", []):
		(_base["stop"] as Dictionary)[str(w)] = true
	var en := load_json("res://data/ia/nlu_en.json")
	if en.is_empty():
		return
	var base_fr: Dictionary = _d.get("frases", {})
	var fr := {}
	for k in (en.get("frases", {}) as Dictionary).keys():
		if not base_fr.has(k):
			fr[k] = en["frases"][k]
	for k in base_fr.keys():
		fr[k] = base_fr[k]
	_d["frases"] = fr
	var jerga: Dictionary = _d.get("jerga", {})
	for k in (en.get("jerga", {}) as Dictionary).keys():
		if not jerga.has(k):
			jerga[k] = en["jerga"][k]
	_d["jerga"] = jerga
	var stop: Array = _d.get("stop", [])
	for w in en.get("stop", []):
		if not stop.has(w):
			stop.append(w)
	_d["stop"] = stop


static func _add_vocab(w: String) -> void:
	if w == "" or w == "?" or _vocab.has(w):
		return
	_vocab[w] = true
	var l := w.length()
	if not _by_len.has(l):
		_by_len[l] = []
	(_by_len[l] as Array).append(w)


## Añade palabras al corrector (p. ej. las de las opciones de un árbol de cliente).
static func learn_words(words: Array) -> void:
	data()
	for w in words:
		_add_vocab(str(w))


# --- normalización ---------------------------------------------------------------------------------------------

static func _clean(text: String) -> String:
	var t := " " + text.to_lower() + " "
	for emo in [[":)", " jaja "], [":-)", " jaja "], [":d", " jaja "], ["xd", " jaja "], [":p", " jaja "], [";)", " jaja "], [":(", " triste "], [":'(", " triste "], ["😂", " jaja "], ["🤣", " jaja "], ["😡", " odio "], ["🙏", " gracias "], ["❤", " te quiero "], ["👍", " ok "]]:
		t = t.replace(emo[0], emo[1])
	var rep := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n", "à": "a", "è": "e", "ì": "i", "ò": "o", "ù": "u", "¿": " ", "¡": " ", "'": "", "’": "", "´": ""}
	for k in rep.keys():
		t = t.replace(k, rep[k])
	var out := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			out += ch
		elif ch == "?":
			out += " ? "
		else:
			out += " "
	while out.contains("  "):
		out = out.replace("  ", " ")
	return " " + out.strip_edges() + " "


static func _apply_phrases(t: String, raw: bool = false) -> String:
	var fr: Dictionary = _base.get("frases", {}) if raw else _d.get("frases", {})
	for k in fr.keys():
		var key := " " + str(k) + " "
		if t.contains(key):
			t = t.replace(key, " " + str(fr[k]) + " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t


## «holaaaa» → «hola», «jajajaja/jsjs/xd» → «jaja», «siii» → «si».
static func _squeeze(w: String) -> String:
	if w.length() >= 3:
		var only_j := true
		for ch in w:
			if not ch in ["j", "a", "e", "i", "s", "h"]:
				only_j = false
				break
		if only_j and (w.begins_with("ja") or w.begins_with("je") or w.begins_with("ji") or w.begins_with("js") or w.begins_with("ha") or w.begins_with("aj")) and w.count("j") + w.count("h") >= 2:
			return "jaja"
	var out := ""
	var run := 0
	for i in w.length():
		if i > 0 and w[i] == w[i - 1]:
			run += 1
			if run >= 2 or (run >= 1 and not w[i] in ["l", "r", "c", "e", "o"]):
				continue
		else:
			run = 0
		out += w[i]
	return out


static func _basic_tokens(t: String, map_slang: bool = true, base_only: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	var jerga: Dictionary = _base.get("jerga", {}) if base_only else _d.get("jerga", {})
	for raw in t.split(" ", false):
		var w := raw if (raw == "?" or jerga.has(raw)) else _squeeze(raw)
		if map_slang and jerga.has(w):
			for x in str(jerga[w]).split(" ", false):
				out.append(x)
		else:
			out.append(w)
	return out


## Recorte suave de sufijos (plural, género, infinitivo, -mente).
static func stem(w: String) -> String:
	if w.length() <= 3 or w == "?" or w.is_valid_int():
		return w
	for sup in ["isimos", "isimas", "isimo", "isima"]:
		if w.length() > sup.length() + 2 and w.ends_with(sup):
			return w.left(w.length() - sup.length())
	if w.length() > 7 and w.ends_with("mente"):
		w = w.left(w.length() - 5)
	if w.length() > 5 and (w.ends_with("ar") or w.ends_with("er") or w.ends_with("ir")):
		return w.left(w.length() - 2)
	if w.length() > 4 and w.ends_with("s"):
		w = w.left(w.length() - 1)
	if w.length() > 4 and (w.ends_with("a") or w.ends_with("o") or w.ends_with("e")):
		w = w.left(w.length() - 1)
	return w


## Corrige una palabra desconocida con la conocida más parecida (Damerau-Levenshtein ≤ 1, o ≤ 2 si es larga).
static func fix_word(w: String) -> String:
	if w.length() < 4 or _vocab.has(w) or w.is_valid_int() or _stop.has(w):
		return w
	if _fix_cache.has(w):
		return str(_fix_cache[w])
	var maxd := 1 if w.length() < 7 else 2
	var best := w
	var bestd := maxd + 1
	for l in range(w.length() - maxd, w.length() + maxd + 1):
		for cand in _by_len.get(l, []):
			var c := str(cand)
			if absi(c.length() - w.length()) >= bestd:
				continue
			# las faltas casi nunca tocan la primera letra: se exige igual salvo con distancia 1 en palabras largas
			if c[0] != w[0] and (maxd < 2):
				continue
			var d := _dist(w, c, bestd - 1)
			if d < bestd:
				bestd = d
				best = c
				if d == 1 and c[0] == w[0]:
					break
	_fix_cache[w] = best
	return best


static func _dist(a: String, b: String, limit: int) -> int:
	var n := a.length()
	var m := b.length()
	if absi(n - m) > limit:
		return limit + 1
	var prev2 := PackedInt32Array()
	var prev := PackedInt32Array()
	var cur := PackedInt32Array()
	prev.resize(m + 1)
	cur.resize(m + 1)
	prev2.resize(m + 1)
	for j in m + 1:
		prev[j] = j
	for i in range(1, n + 1):
		cur[0] = i
		var row_min := cur[0]
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			var v := mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				v = mini(v, prev2[j - 2] + 1)
			cur[j] = v
			row_min = mini(row_min, v)
		if row_min > limit:
			return limit + 1
		var tmp := prev2
		prev2 = prev
		prev = cur
		cur = tmp
	return prev[m]


## Texto → palabras canónicas (jerga, faltas corregidas), sin recortar. raw = sin el léxico inglés (ver _merge_en).
static func words(text: String, raw: bool = false) -> PackedStringArray:
	data()
	var t := _apply_phrases(_clean(text), raw)
	var out := PackedStringArray()
	for w in _basic_tokens(t, true, raw):
		var f := fix_word(w)
		var jerga: Dictionary = _base.get("jerga", {}) if raw else _d.get("jerga", {})
		if f != w and jerga.has(f):
			for x in str(jerga[f]).split(" ", false):
				out.append(x)
		else:
			out.append(f)
	return out


## Palabras útiles recortadas (sin las vacías): para comparar textos entre sí.
static func stems(text: String, raw: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	var stop: Dictionary = _base.get("stop", {}) if raw else _stop
	for w in words(text, raw):
		if w == "?" or stop.has(w):
			continue
		out.append(stem(w))
	return out


# --- análisis --------------------------------------------------------------------------------------------------

static func classify(text: String, ctx: Dictionary = {}) -> String:
	return str(analyze(text, ctx).get("intent", "otro"))


static func analyze(text: String, ctx: Dictionary = {}) -> Dictionary:
	data()
	var res := {"texto": text, "intent": "vacio", "coarse": "vacio", "score": 0.0, "top": [], "sentiment": 0.0, "politeness": 0.0,
		"intensity": 0.0, "severity": 0, "slots": {}, "hechos": [], "tokens": PackedStringArray(), "norm": ""}
	if text.strip_edges() == "":
		return res
	var w := words(text)
	if w.is_empty():
		return res
	var norm := " " + " ".join(w) + " "
	res["norm"] = norm
	var st := PackedStringArray()
	for x in w:
		st.append(stem(x))
	res["tokens"] = st
	# patrones: todos los encajes; los más largos primero se quedan con sus palabras
	var matches: Array = []
	for i in st.size():
		for pat in _index.get(st[i], []):
			var e := _match_at(st, i, pat[1])
			if e >= 0:
				matches.append([i, e, str(pat[0]), float(pat[2]), (pat[1] as PackedStringArray).size()])
	matches.sort_custom(func(a: Array, b: Array) -> bool: return a[4] > b[4] if a[4] != b[4] else a[3] > b[3])
	var used := {}  # posición -> "inicio:fin" del encaje que se la quedó (el mismo tramo lo comparten varias intenciones)
	var scores := {}
	var cs_k := 1.2 if str(ctx.get("dominio", "")) == "cs" else 0.85
	for m in matches:
		var span := "%d:%d" % [int(m[0]), int(m[1])]
		var free := true
		for k in range(int(m[0]), int(m[1]) + 1):
			if used.has(k) and str(used[k]) != span:
				free = false
				break
		if not free:
			continue
		for k in range(int(m[0]), int(m[1]) + 1):
			used[k] = span
		var wgt := float(m[3]) * (1.0 + 0.15 * (int(m[4]) - 1))
		var intent := str(m[2])
		if int(m[0]) > 0 and st[int(m[0]) - 1] == "no" and intent in NEGATABLE:
			wgt *= -0.6
		if intent.begins_with("cs_"):
			wgt *= cs_k
		scores[intent] = float(scores.get(intent, 0.0)) + wgt
	for e in ctx.get("expect", []):
		if float(scores.get(str(e), 0.0)) > 0.0:
			scores[str(e)] = float(scores[str(e)]) + 0.6
	var ranked: Array = scores.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return float(scores[a]) > float(scores[b]))
	var best := "otro"
	var best_s := 0.0
	if not ranked.is_empty() and float(scores[ranked[0]]) >= MIN_SCORE:
		best = str(ranked[0])
		best_s = float(scores[best])
	# «sí / ok / dale» cuenta como lo que se espera (ir al Rooms, dar Ack…)
	var af := str(ctx.get("afirmar_es", ""))
	if af != "" and best in ["ok", "otro"] and (best == "ok" or _is_affirm(st)):
		best = af
		best_s = maxf(best_s, 1.0)
	res["intent"] = best
	res["score"] = best_s
	var top: Array = []
	for k in ranked.slice(0, 3):
		top.append([str(k), snappedf(float(scores[k]), 0.01)])
	res["top"] = top
	res["scores"] = scores
	res["coarse"] = coarse_of(best, text)
	res["sentiment"] = _sentiment(st)
	res["politeness"] = _politeness(norm, scores)
	res["intensity"] = _intensity(text)
	res["severity"] = _severity(norm, scores)
	res["slots"] = _slots(text, norm)
	res["hechos"] = _facts(text, w)
	return res


static func _is_affirm(st: PackedStringArray) -> bool:
	for t in st:
		if t in ["si", "ok", "dale", "listo", "claro", "vale", "va", "ya", "bueno", "seguro"]:
			return true
	return false


## Encaje del patrón `pat` desde la posición i; perdona hasta 2 palabras de relleno entre medio. -1 = no encaja.
static func _match_at(st: PackedStringArray, i: int, pat: PackedStringArray) -> int:
	var j := i + 1
	var skipped := 0
	for k in range(1, pat.size()):
		while j < st.size() and st[j] != pat[k] and _filler.has(st[j]) and skipped < 2:
			j += 1
			skipped += 1
		if j >= st.size() or st[j] != pat[k]:
			return -1
		j += 1
	return j - 1


static func coarse_of(fine: String, text: String = "") -> String:
	var m: Dictionary = data().get("coarse", {})
	var c := str(m.get(fine, "otro"))
	if c in ["otro", "saludo"] and text.contains("?"):
		return "pregunta"
	return c


static func _sentiment(st: PackedStringArray) -> float:
	var s := 0.0
	var ints: Array = _d.get("intensificadores", [])
	for i in st.size():
		if _sent.has(st[i]):
			var v := float(_sent[st[i]])
			if i > 0 and st[i - 1] in ints:
				v *= 1.5
			if i > 0 and st[i - 1] == "no" and v > 0.0:
				v = -v * 0.6
			s += v
	return clampf(tanh(s / 1.5), -1.0, 1.0)


static func _politeness(norm: String, scores: Dictionary) -> float:
	var p := 0.0
	var c: Dictionary = _d.get("cortesia", {})
	for k in c.keys():
		if norm.contains(" " + str(k) + " "):
			p += float(c[k])
	if float(scores.get("insulto", 0.0)) > 0.0 or float(scores.get("amenaza", 0.0)) > 0.0:
		p -= 1.2
	return clampf(p, -1.0, 1.0)


static func _intensity(text: String) -> float:
	var letters := 0
	var caps := 0
	for ch in text:
		var u := ch.unicode_at(0)
		if (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
			letters += 1
			if u <= 90:
				caps += 1
	var v := 0.0
	if letters >= 6 and float(caps) / float(letters) > 0.6:
		v += 0.6
	v += minf(0.4, 0.1 * float(text.count("!")))
	return clampf(v, 0.0, 1.0)


## 0 nada · 1 leve («calvo», «pesado») · 2 insulto · 3 grave (groserías fuertes o amenaza).
static func _severity(norm: String, scores: Dictionary) -> int:
	if float(scores.get("amenaza", 0.0)) >= 1.5:
		return 3
	for g in _graves:
		if norm.contains(str(g)):
			return 3
	var ins := float(scores.get("insulto", 0.0))
	if ins <= 0.0:
		return 0
	var leve_only := true
	var hits := 0
	for l in _leves:
		if norm.contains(str(l)):
			hits += 1
	if ins > 2.6 or hits == 0:
		leve_only = false
	if ins >= 4.0:
		return 3
	return 1 if leve_only else 2


static func _slots(text: String, norm: String) -> Dictionary:
	var s := {}
	var re := RegEx.new()
	re.compile("(?i)KP[- ]?(\\d{4})[- ]?(\\d{4})")
	var m := re.search(text)
	if m != null:
		s["kp"] = "KP-%s-%s" % [m.get_string(1), m.get_string(2)]
	re.compile("\\d+")
	var nums: Array = []
	for r in re.search_all(text):
		nums.append(r.get_string())
	if not nums.is_empty():
		s["numeros"] = nums
	re.compile("(\\d{1,2})[:h](\\d{2})")
	m = re.search(text)
	if m != null:
		s["hora"] = "%02d:%s" % [int(m.get_string(1)), m.get_string(2)]
	var ent: Dictionary = _d.get("entidades", {})
	for grp in ["personas", "lugares"]:
		var found: Array = []
		var g: Dictionary = ent.get(grp, {})
		for k in g.keys():
			for alias in g[k]:
				if norm.contains(" " + str(alias) + " "):
					if not found.has(str(k)):
						found.append(str(k))
					break
		if not found.is_empty():
			s[grp] = found
	return s


## Lo que el jugador cuenta de sí mismo (para que los personajes lo recuerden después).
static func _facts(text: String, w: PackedStringArray) -> Array:
	var out: Array = []
	var ent: Dictionary = _d.get("entidades", {})
	var fam: Array = ent.get("familia", [])
	var est: Array = ent.get("estados", [])
	var frase := text.strip_edges().left(70)
	for i in w.size():
		var a := w[i]
		var b := w[i + 1] if i + 1 < w.size() else ""
		var c := w[i + 2] if i + 2 < w.size() else ""
		if (a == "mi" or a == "mis") and b in fam:
			var rest := " ".join(w.slice(i + 2, mini(i + 6, w.size())))
			out.append({"tipo": "familia", "valor": b, "detalle": rest, "frase": frase})
		elif (a == "estoy" or (a == "me" and b == "siento")) and ((b if a == "estoy" else c) in est or (b == "muy" and c in est)):
			var v := b if a == "estoy" and b != "muy" else c
			out.append({"tipo": "estado", "valor": v, "frase": frase})
		elif a == "tengo" and (b in ["examen", "clase", "cita", "deuda", "hambre", "sueno", "miedo", "fiebre", "hijo", "hija", "novia", "novio", "perro", "gato"] or (b in ["un", "una"] and c in ["examen", "clase", "cita", "deuda", "hijo", "hija", "novia", "novio", "perro", "gato"])):
			out.append({"tipo": "tengo", "valor": b if not b in ["un", "una"] else c, "frase": frase})
		elif a == "me" and b == "gusta" and c != "":
			out.append({"tipo": "gusto", "valor": " ".join(w.slice(i + 2, mini(i + 5, w.size()))), "frase": frase})
		elif a == "vivo" and b == "en" and c != "":
			out.append({"tipo": "vive", "valor": " ".join(w.slice(i + 2, mini(i + 4, w.size()))), "frase": frase})
		elif a == "cumpleanos" and (i > 0 and w[i - 1] == "mi"):
			out.append({"tipo": "cumple", "valor": "hoy", "frase": frase})
	return out

class_name HaimeGuion
extends RefCounted
## v0.3.1 Q4 (Joan 2026-11-10 11:14Z): guion PERSONALIZADO de cada feedback de Haime (data/haime_guiones.json).
## Antes la sesión era fija (fb1_om1..3 hablaban de saludo, empatía y respiración aunque el caso fuera un correo).
## Ahora cada línea sale del caso real:
##   · tipo del caso: llamada · chat · correo · vitzo (correo con portal) · kyc. Una línea solo sale en su tipo.
##   · una oportunidad de mejora por cada marca REAL de QA del contacto (1..4; sin marcas propias, una genérica
##     del mismo tipo). Las marcas de correo dicen qué falló: campo (id/monto/fecha), plantilla, destinatario,
##     adjunto, tipificación, tiempo, portal (ContactManager.close_case las detalla).
##   · el caso concreto: cliente o remitente y su problema (casos.<id>); tu frase real o el valor que elegiste se
##     muestra como cita antes de la línea (la pantalla la «reproduce»; Haime no la lee en voz alta).
##   · nunca repite una línea en el turno (GameState.flags.q4_haime_usadas, va en el checkpoint).
## Escalada: intro de nivel 1 (primer feedback), 2 (los siguientes) y 3 (el de la muerte). El cierre con el
## puntaje («83 sobre cien. No es malo. Es un número.») sigue siendo el de lineas_haime.json.
## Voz: voces/haime/<id> (ES y EN), sintetizada con el casting de Haime.

const DATA := "haime_guiones"
const MAX_OM := 4
const DETAIL_KEY := "q4_haime_det"  # Discipline.counters (va en el checkpoint)
const USED_KEY := "q4_haime_usadas"


static func _d() -> Dictionary:
	return DataLoader.dict(DATA)


## ContactManager lo llama al terminar cada contacto (antes de contact_outcome): guarda tipo, citas y valores
## elegidos para que la sesión pueda nombrarlos aunque Haime llame 15 min de juego después.
static func remember(c: Dictionary) -> void:
	var det: Dictionary = (PersonajesP5.counter(DETAIL_KEY, {}) as Dictionary).duplicate(true)
	var id := str(c.get("id", ""))
	if id == "":
		return
	det[id] = {"tipo": case_type(c), "base": base_id(c), "correo": c.get("_correo_detalle", {}), "kyc": str(c.get("_kyc_action", ""))}
	if det.size() > 16:
		det.erase(det.keys()[0])
	PersonajesP5.set_counter(DETAIL_KEY, det)


## Id del contenido (sin el sufijo del relleno: kyc_relleno_ok_3 → kyc_relleno_ok, t1r4_2 → t1r4).
static func base_id(c: Dictionary) -> String:
	var id := str(c.get("ref_id", c.get("id", "")))
	var casos: Dictionary = _d().get("casos", {})
	if casos.has(id):
		return id
	var cut := id
	while cut.contains("_"):
		cut = cut.substr(0, cut.rfind("_"))
		if casos.has(cut):
			return cut
	return id


## llamada | chat | correo | vitzo | kyc
static func case_type(c: Dictionary) -> String:
	var canal := str(c.get("canal", ""))
	if canal == "kyc":
		return "kyc"
	if canal == "correo":
		if str(c.get("vitzo", "")) != "":
			return "vitzo"
		var base := base_id(c)
		for list in (DataLoader.dict("casos_bo").get("turnos", {}) as Dictionary).values():
			for k in list:
				if str((k as Dictionary).get("id", "")) == base and str((k as Dictionary).get("vitzo", "")) != "":
					return "vitzo"
		return "correo"
	return "chat" if canal == "chat" else "llamada"


## Marcas normalizadas y sin repetir (falta_portal_pod → falta_portal; correo_incorrecto sin detalle → bo_miss).
static func marks_of(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for m in entry.get("marcas", []):
		var k := str(m)
		if k.begins_with("falta_portal"):
			k = "falta_portal"
		elif k == "correo_incorrecto":
			k = "bo_miss"
		elif k.begins_with("kyc_") and not (_d().get("marcas", {}) as Dictionary).has(k):
			k = "kyc_sin_decision"
		if not out.has(k):
			out.append(k)
	return out


## Cuántas oportunidades tiene la sesión de este contacto: una por marca real (1..4).
static func opportunities(entry: Dictionary) -> int:
	return clampi(marks_of(entry).size(), 1, MAX_OM)


static func _used() -> Array:
	return GameState.flags.get(USED_KEY, []) as Array


static func _mark_used(id: String) -> void:
	var u := _used().duplicate()
	if not u.has(id):
		u.append(id)
	GameState.flags[USED_KEY] = u


## Primera línea no usada en el turno (orden estable por semilla); si todas se usaron, la menos reciente.
static func _pick(lines: Array, seed_v: int) -> Dictionary:
	if lines.is_empty():
		return {}
	var used := _used()
	var start := absi(seed_v) % lines.size()
	for i in lines.size():
		var l: Dictionary = lines[(start + i) % lines.size()]
		if not used.has(str(l.get("id", ""))):
			return l
	return {}


static func _pick_any(lines: Array, seed_v: int) -> Dictionary:
	var l := _pick(lines, seed_v)
	if l.is_empty() and not lines.is_empty():
		l = lines[absi(seed_v) % lines.size()]
	return l


static func _say(l: Dictionary) -> String:
	return Loc.pick(l)


## Cita de la marca: tu frase del árbol que dejó esa marca, o el valor que elegiste en el correo/KYC.
static func quote_for(entry: Dictionary, mark: String) -> String:
	for t in entry.get("transcripcion", []):
		var td := t as Dictionary
		if str(td.get("quien", "")) == "yo" and str(td.get("qa", "")) == mark:
			return str(td.get("texto", ""))
	var det: Dictionary = (PersonajesP5.counter(DETAIL_KEY, {}) as Dictionary).get(str(entry.get("id", "")), {})
	var mail: Dictionary = det.get("correo", {})
	match mark:
		"correo_plantilla":
			return str(mail.get("tpl", ""))
		"destinatario_equivocado":
			return str(mail.get("to", ""))
		"correo_campo_id", "correo_campo_monto", "correo_campo_fecha":
			return str((mail.get("campos", {}) as Dictionary).get(mark.trim_prefix("correo_campo_"), ""))
		"tipificacion":
			var tip := str(mail.get("tip", ""))
			for t in DataLoader.dict("casos_bo").get("tipificaciones", []):
				if str((t as Dictionary).get("id", "")) == tip:
					return Loc.pick(t)
			return tip
	if mark.begins_with("kyc_") and str(det.get("kyc", "")) != "":
		return tr_key("P4_KYC_" + str(det.get("kyc", "")).to_upper(), str(det.get("kyc", "")))
	return ""


static func tr_key(key: String, fallback: String) -> String:
	var t := TranslationServer.translate(key)
	return fallback if t == key else t


static func entry_type(entry: Dictionary) -> String:
	var det: Dictionary = (PersonajesP5.counter(DETAIL_KEY, {}) as Dictionary).get(str(entry.get("id", "")), {})
	if det.has("tipo"):
		return str(det["tipo"])
	return case_type({"id": str(entry.get("id", "")), "canal": str(entry.get("canal", ""))})


## Línea de una oportunidad para la marca en ese tipo de caso (o genérica del tipo).
static func opportunity_line(entry: Dictionary, mark: String, tipo: String, seed_v: int) -> Dictionary:
	var cands: Array = []
	for l in (_d().get("marcas", {}) as Dictionary).get(mark, []):
		if (l as Dictionary).get("tipos", []).has(tipo):
			cands.append(l)
	var l := _pick(cands, seed_v)
	if l.is_empty():
		l = _pick_any((_d().get("genericas", {}) as Dictionary).get(tipo, []), seed_v)
	if l.is_empty():
		return {}
	var text := _say(l)
	var q := quote_for(entry, mark)
	if q != "":
		text = "«%s» %s" % [q.replace("\n", " "), text]
	return {"id": str(l.get("id", "")), "text": text}


## Secuencia de la sesión n para QaFeedback._start_session: [{key, text?, replay?, om?, cierre?}].
## Los ítems sin "text" usan lineas_haime.json (cierre con puntaje, las del feedback fatal y la advertencia).
## `cierre_key` = clave de cierre que decide QaFeedback; `after_intro` = claves extra tras la intro ("advertencia").
static func sequence(entry: Dictionary, n: int, fatal: bool, cierre_key: String = "", after_intro: Array = []) -> Array:
	var tipo := entry_type(entry)
	var nivel := "3" if fatal else ("1" if n <= 1 else "2")
	var seed_v := hash(str(entry.get("id", ""))) + n * 7919
	var seq: Array = []
	var intro := _pick_any((((_d().get("intro", {}) as Dictionary).get(tipo, {}) as Dictionary).get(nivel, []) as Array), seed_v)
	seq.append({"key": str(intro.get("id", "fb1_intro")), "text": _say(intro)})
	for k in after_intro:
		seq.append({"key": str(k)})
	var det: Dictionary = (PersonajesP5.counter(DETAIL_KEY, {}) as Dictionary).get(str(entry.get("id", "")), {})
	var base := str(det.get("base", base_id({"id": str(entry.get("id", ""))})))
	var caso: Dictionary = (_d().get("casos", {}) as Dictionary).get(base, (_d().get("caso_tipo", {}) as Dictionary).get(tipo, {}))
	seq.append({"key": str(caso.get("id", "fb1_replay")), "text": _say(caso), "replay": true})
	var marks := marks_of(entry)
	if marks.is_empty():
		marks.append("generica")
	var count := clampi(marks.size(), 1, MAX_OM)
	if fatal:
		# El de la muerte: la primera es tu marca real; después, las de lineas_haime (fb3_om2/om3).
		var l := opportunity_line(entry, marks[0], tipo, seed_v)
		seq.append({"key": str(l.get("id", "fb3_om1")), "text": str(l.get("text", "")), "om": 1})
		seq.append({"key": "fb3_om2", "om": 2})
		seq.append({"key": "fb3_om3", "om": 3})
	else:
		for k in count:
			var l2 := opportunity_line(entry, marks[k], tipo, seed_v + k * 31)
			if l2.is_empty():
				continue
			_mark_used(str(l2.get("id", "")))  # evita la misma línea dos veces en la misma sesión
			seq.append({"key": str(l2["id"]), "text": str(l2["text"]), "om": seq.filter(func(it: Dictionary) -> bool: return it.has("om")).size() + 1})
	for it in seq:
		if (it as Dictionary).has("text"):
			_mark_used(str((it as Dictionary)["key"]))
	var nk := clampi(n, 1, 3)
	seq.append({"key": cierre_key if cierre_key != "" else ("fb3_cierre" if fatal else "fb%d_cierre" % mini(nk, 2)), "cierre": true})
	return seq


## Todas las líneas con voz (pruebas de audio y síntesis).
static func all_voice_ids() -> Array[String]:
	var out: Array[String] = []
	var d := _d()
	for lv in (d.get("intro", {}) as Dictionary).values():
		for lines in (lv as Dictionary).values():
			for l in lines:
				out.append(str(l.get("id", "")))
	for group in ["marcas", "genericas"]:
		for lines in (d.get(group, {}) as Dictionary).values():
			for l in lines:
				out.append(str(l.get("id", "")))
	for group in ["casos", "caso_tipo"]:
		for l in (d.get(group, {}) as Dictionary).values():
			out.append(str((l as Dictionary).get("id", "")))
	# v0.3.2: los grupos del constructor de sesiones.
	for lines in ((d.get(V32, {}) as Dictionary).get("lineas", {}) as Dictionary).values():
		for l in lines:
			out.append(str((l as Dictionary).get("id", "")))
	return out


# --- v0.3.2: sesiones con suspenso ---------------------------------------------------------------------------------
## Joan (v0.3.2): «que causen suspenso, tensión y miedo… aún más agresivos, no repetitivos cada vez y no tan lentos».
## build_session() arma la calibración como una lista de BEATS (QaFeedback los ejecuta):
##   puerta (el seguro de la puerta) · linea · marca (tu error en rojo, la pluma, el puntaje baja, la luz baja) ·
##   replay (el auricular reproduce tu contacto distorsionado) · pregunta (3-5 s, teclas 1-4; tarde o mal = más enojo;
##   «repite» = te corta y te hace repetir el guion) · silencio (demasiado largo… y el salto) · golpe (la mesa) ·
##   amenaza (susurro) · auricular (te lo arranca) · cierre · fatal.
## Escalera por calibración del turno (nivel): 1 fría y pasivo-agresiva · 2 golpea la mesa, te corta y te hace repetir el
## guion · 3 la última advertencia (más calmado que nunca: recuerda, se para detrás de ti, te quita el auricular) · 4 la
## fatal (una calibración completa, la más terrorífica; al final pide la muerte). 3 y 4 se arman en _build_peak (guion
## por fases). La ESTRUCTURA es al azar (con qué error abre, dónde van el repaso, las
## preguntas, el silencio) y las líneas se eligen entre las menos usadas en la partida (memoria por partida: mem).
## Toda línea va con su id de voz: el texto es el del índice de voz (HaimeVoz.spoken), nunca con marcadores.

const V32 := "v032"
const MEM_LINES := 260  # ids recordados por partida
const MEM_SIGS := 16  # estructuras recordadas por partida

# --- ritmo (Joan: «no tan lentas») ---
## Una calibración 1.ª-3.ª dura 40-55 s reales y la fatal ≤ 40 s. El constructor conoce la duración exacta de cada
## beat (cada línea dura hasta que Haime termina de HABLAR, HaimeVoz.talk: la cola de silencio de la toma no se
## espera) y calcula dos totales: `min_s` (respondes bien y rápido) y `max_s` (todo tarde o mal, y te corta). Arma el
## núcleo del nivel y le suma extras al azar mientras max_s ≤ S_MAX, hasta que min_s ≥ F_MIN. QaFeedback usa estas
## mismas constantes al ejecutar los beats: lo estimado es lo que dura.
const F_MIN := 40.8
const S_MAX := 53.8
## La última advertencia (3) puede llegar a 60 s y la fatal (4) dura 45-70 s: son los picos (Joan: «que la última sea aún
## más»; «que su calibración sea muy terrorífica y te da la idea que morirás y justo te mata ahí»), con cada segundo ocupado.
const LIMITS := {1: [40.8, 53.8], 2: [40.8, 53.8], 3: [46.0, 59.4], 4: [47.0, 68.5]}
const GAP: Array[float] = [0.12, 0.16, 0.1, 0.3, 0.22]  # respiro tras cada línea, por nivel (3 y 4: habla más despacio)
const VOICE_PITCH: Array[float] = [1.0, 1.0, 1.0, 0.96, 0.93]  # velocidad/tono de su voz por nivel (voice_pitch)
const T_PUERTA := 0.35  # el seguro → su primera palabra
const T_MIRA := 0.7  # entrada sin frase: solo te mira
const T_MARCA := 0.15  # la pluma marca tu error → lo dice
const T_GOLPE := 0.3  # la mesa → el grito
const T_ENOJO := 0.25
const T_AURICULAR := 0.5
const T_MENTIRA := 0.3
const T_SALTO := 0.3
const T_FATAL := 0.0  # la muerte se pide en el cuadro en que termina su última palabra
const T_LLAVE := 0.7  # la segunda vuelta de llave
const T_RECUERDO := 0.3
const T_PLUMA_CALLA := 1.1  # la pluma deja de sonar → habla
const T_DETRAS_IN := 0.35  # apagón → su silla vacía
const T_DETRAS := 1.0  # la respiración en tu nuca → el susurro
const T_LUZ := 0.5
const T_CERTEZA := 1.6  # apagón, solo queda el REC, el latido
const T_TU_VOZ := 2.8  # lo que deja sonar tu propio saludo antes de cortarlo
const CORTE_ADV := 0.55  # la advertencia: te corta la respuesta al 55 % del tiempo (sin segunda oportunidad)
const CORTE_FATAL := 0.4  # la fatal: al 40 %; da igual lo que contestes
const T_REPLAY: Array[float] = [2.4, 2.6, 2.4, 2.0, 2.2]  # lo que deja sonar tu contacto antes de cortarlo él, por nivel
const T_RESPUESTA := 0.8  # una respuesta rápida (la de las pruebas)
const CORTE := 0.55  # «repite el guion»: si no contestaste al 55 % del tiempo, te corta
const FIRST_MARK_MAX := 15.0  # el primer error en rojo llega antes de esto (s), por el camino más largo
const FULL_MARKS: Array[int] = [2, 2, 2, 1, 1]  # errores que explica por nivel; los demás van en ráfaga («Otra.» y la pluma)


static func _v32() -> Dictionary:
	return _d().get(V32, {}) as Dictionary


static func group(g: String) -> Array:
	return ((_v32().get("lineas", {}) as Dictionary).get(g, []) as Array)


## Nivel de la sesión: 1, 2, 3 (la última advertencia) o 4 (la fatal).
static func level_of(n: int, fatal: bool, warning: bool) -> int:
	if fatal:
		return 4
	if warning:
		return 3
	return clampi(n, 1, 2)


## ¿Está el número en la lista? (los JSON traen 1.0, no 1)
static func _has_n(arr: Array, n: int) -> bool:
	for x in arr:
		if int(x) == n:
			return true
	return false


static func _fits(l: Dictionary, nivel: int, tipo: String) -> bool:
	if l.has("nivel") and not _has_n(l["nivel"] as Array, nivel):
		return false
	if l.has("tipos") and tipo != "" and not (l["tipos"] as Array).has(tipo):
		return false
	return true


## Elige una línea de `lines` que quepa en nivel/tipo: entre las que no se usaron en la partida (ni en esta sesión), al azar;
## si todas se usaron, la que se usó hace más tiempo. Anota el id en `used` (esta sesión).
static func pick_fresh(lines: Array, nivel: int, tipo: String, rng: RandomNumberGenerator, mem: Dictionary, used: Array) -> Dictionary:
	var cands: Array = []
	for l in lines:
		if _fits(l as Dictionary, nivel, tipo) and not used.has(str((l as Dictionary).get("id", ""))):
			cands.append(l)
	if cands.is_empty():
		for l in lines:
			if _fits(l as Dictionary, nivel, tipo):
				cands.append(l)
	if cands.is_empty():
		return {}
	var recent: Array = mem.get("lineas", [])
	var fresh: Array = cands.filter(func(l: Dictionary) -> bool: return not recent.has(str(l.get("id", ""))))
	var l: Dictionary
	if not fresh.is_empty():
		l = fresh[rng.randi() % fresh.size()]
	else:
		var best := INF
		for c in cands:
			var i := recent.find(str((c as Dictionary).get("id", "")))
			if i < best:
				best = i
				l = c
	used.append(str(l.get("id", "")))
	return l


static func _line(l: Dictionary) -> Dictionary:
	if l.is_empty():
		return {}
	var id := str(l.get("id", ""))
	return {"key": id, "text": HaimeVoz.spoken(id, Loc.pick(l))}


static func _lh(key: String) -> Dictionary:
	return {"key": key, "text": HaimeVoz.spoken(key, Loc.pick(DataLoader.dict("lineas_haime").get(key, {})))}


static func _g(g: String, nivel: int, tipo: String, rng: RandomNumberGenerator, mem: Dictionary, used: Array) -> Dictionary:
	return _line(pick_fresh(group(g), nivel, tipo, rng, mem, used))


## Opciones de una pregunta (texto en pantalla, en el idioma actual): [opciones(4), índice correcto].
static func question_options(q: String, entry: Dictionary, n: int, max_n: int, rng: RandomNumberGenerator) -> Array:
	var ops: Dictionary = _v32().get("opciones", {})
	var correct := ""
	var wrong: Array[String] = []
	match q:
		"p_hora":
			var base := float(entry.get("reloj", -1.0))
			correct = str(entry.get("hora", ""))
			if base < 0.0:
				base = GameState.clock_seconds - 900.0
				correct = GameState.clock_text_at(base) if correct == "" else correct
			for off in [-47.0, 23.0, 71.0, -96.0, 38.0]:
				var t := GameState.clock_text_at(base + off * 60.0)
				if t != correct and not wrong.has(t):
					wrong.append(t)
		"p_canal":
			var lab: Dictionary = ops.get("canal", {})
			var tipo := entry_type(entry)
			correct = Loc.pick(lab.get(tipo, {}))
			for k in lab.keys():
				if str(k) != tipo:
					wrong.append(Loc.pick(lab[k]))
		"p_marcas":
			var c := clampi(marks_of(entry).size(), 1, MAX_OM)
			correct = str(c)
			for i in range(1, 6):
				if i != c:
					wrong.append(str(i))
		"p_quedan":
			var left := clampi(max_n - n, 0, 4)
			correct = str(left)
			for i in range(0, 5):
				if i != left:
					wrong.append(str(i))
		"p_nombre":
			correct = GameState.agent
			for a in GameState.AGENTS:
				if a != correct:
					wrong.append(a)
		_:
			var o: Dictionary = ops.get(q, {})
			correct = Loc.fmt(Loc.pick(o.get("correcta", {})), {"agente": GameState.agent})
			for f in o.get("falsas", []):
				wrong.append(Loc.fmt(Loc.pick(f), {"agente": GameState.agent}))
	# 3 falsas al azar + la correcta en un lugar al azar.
	var pool := wrong.duplicate()
	var picked: Array[String] = []
	while picked.size() < 3 and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi() % pool.size()))
	var at := rng.randi() % (picked.size() + 1)
	picked.insert(at, correct)
	return [picked, at]


## Transcripción: índice de la fila con la marca (para pintarla en rojo); -1 si no hay.
static func row_of(entry: Dictionary, mark: String) -> int:
	var tr_lines: Array = entry.get("transcripcion", [])
	for i in mini(tr_lines.size(), 7):
		if str((tr_lines[i] as Dictionary).get("qa", "")) == mark:
			return i
	return -1


static func _question(q: String, nivel: int, tipo: String, entry: Dictionary, n: int, max_n: int, rng: RandomNumberGenerator, mem: Dictionary, used: Array) -> Dictionary:
	var l := _g(q, nivel, tipo, rng, mem, used)
	if l.is_empty():
		return {}
	var qo := question_options(q, entry, n, max_n, rng)
	var cfg: Dictionary = (_v32().get("preguntas", {}) as Dictionary).get(q, {})
	var tarea := bool(cfg.get("tarea", false))
	var secs := float((_v32().get("tiempo_respuesta_s", {}) as Dictionary).get(str(nivel), 4.0)) + (0.6 if tarea else 0.0)  # las tareas se leen
	var b := {"k": "pregunta", "q": q, "key": l["key"], "text": l["text"], "opciones": qo[0], "correcta": qo[1], "tiempo": secs,
		"tarea": tarea, "repite": bool(cfg.get("repite", false)) and nivel >= 2}
	# Lo que contesta él (bien / mal / tarde / te corta) se elige al armar: así la sesión sabe cuánto dura por cada camino.
	for r in ["bien", "mal", "tarde"]:
		b["r_" + r] = _g(r, nivel, tipo, rng, mem, used)
	if bool(b["repite"]):
		b["r_corta"] = _g("corta", nivel, tipo, rng, mem, used)
	return b


static func _questions_for(nivel: int) -> Array[String]:
	var out: Array[String] = []
	for q in (_v32().get("preguntas", {}) as Dictionary).keys():
		if _has_n((_v32()["preguntas"][q] as Dictionary).get("niveles", []) as Array, nivel):
			out.append(str(q))
	return out


static func _wpick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return str(k)
	return str(weights.keys()[0])


## La voz de Haime en ese nivel: en la advertencia y la fatal suena más grave y más lenta (la misma toma, reproducida
## un poco más despacio): normal en la 1.ª y la 2.ª, fría en la advertencia, más fría en la fatal (y los susurros).
static func voice_pitch(nivel: int) -> float:
	return VOICE_PITCH[clampi(nivel, 0, 4)]


## Lo que tarda una línea en ese nivel (s): hasta que termina de hablar + el respiro. 0 si no hay línea.
static func line_s(l: Variant, nivel: int) -> float:
	if not (l is Dictionary) or str((l as Dictionary).get("key", "")) == "":
		return 0.0
	var d := l as Dictionary
	return HaimeVoz.talk(str(d["key"]), str(d.get("text", ""))) / voice_pitch(nivel) + GAP[clampi(nivel, 0, 4)]


## Segundos (por el camino más largo) hasta que marca tu primer error en rojo.
static func first_mark_s(beats: Array, nivel: int) -> float:
	var s := 0.0
	for b in beats:
		if str((b as Dictionary).get("k", "")) == "marca":
			return s
		s += beat_range(b as Dictionary, nivel).y
	return s


## Límites de duración [mínima, máxima] de la sesión de ese nivel.
static func limits(nivel: int) -> Array:
	return LIMITS.get(clampi(nivel, 1, 4), LIMITS[1]) as Array


## Tiempo de la segunda oportunidad cuando te cortó.
static func second_time(secs: float) -> float:
	return maxf(secs * 0.8, 2.4)


## Duración de un beat (s reales): x = el camino más corto (respondes bien y rápido), y = el más largo (tarde o mal).
static func beat_range(b: Dictionary, nivel: int) -> Vector2:
	var own := line_s(b, nivel)
	var f := own
	var s := own
	match str(b.get("k", "")):
		"puerta":
			f = T_PUERTA + (T_LLAVE if bool(b.get("doble", false)) else 0.0) + (own if own > 0.0 else T_MIRA)
			s = f
		"marca":
			f = T_MARCA + own
			s = f
		"replay":
			f = line_s(b.get("pre"), nivel) + (T_TU_VOZ if bool(b.get("tu_voz", false)) else T_REPLAY[clampi(nivel, 0, 4)]) + line_s(b.get("caso"), nivel) + line_s(b.get("post"), nivel)
			s = f
		"pregunta":
			var t := float(b.get("tiempo", 4.0))
			var enojo := T_ENOJO if nivel >= 2 else 0.0
			var bad_min := minf(line_s(b.get("r_mal"), nivel), line_s(b.get("r_tarde"), nivel)) + enojo
			var bad_max := maxf(line_s(b.get("r_mal"), nivel), line_s(b.get("r_tarde"), nivel)) + enojo
			f = own + T_RESPUESTA + minf(line_s(b.get("r_bien"), nivel), bad_min)
			if b.has("corte"):
				# Te corta la respuesta (sin segunda oportunidad). En la fatal da igual lo que contestes (r_igual).
				var cut := t * float(b["corte"])
				var said := line_s(b.get("r_igual"), nivel) if bool(b.get("da_igual", false)) else minf(line_s(b.get("r_bien"), nivel), line_s(b.get("r_mal"), nivel))
				var said_max := line_s(b.get("r_igual"), nivel) if bool(b.get("da_igual", false)) else maxf(line_s(b.get("r_bien"), nivel), line_s(b.get("r_mal"), nivel))
				f = own + minf(T_RESPUESTA + said, cut + line_s(b.get("r_corta"), nivel))
				s = own + maxf(cut + line_s(b.get("r_corta"), nivel), cut + said_max)
			elif bool(b.get("repite", false)):
				s = own + t * CORTE + T_GOLPE + line_s(b.get("r_corta"), nivel) + second_time(t) + bad_max
			else:
				s = own + t + bad_max
		"silencio":
			f = float(b.get("s", 3.0)) + (0.0 if bool(b.get("sin_salto", false)) else T_SALTO) + own
			s = f
		"golpe":
			f = T_GOLPE + own
			s = f
		"auricular":
			f = T_AURICULAR + own
			s = f
		"mentira":
			f = T_MENTIRA + own
			s = f
		"fatal":
			f = own - GAP[clampi(nivel, 0, 4)] + T_FATAL  # sin respiro: la muerte entra con su última palabra
			s = f
		"recuerdo":
			f = T_RECUERDO + own
			s = f
		"pluma":
			f = float(b.get("s", 1.8)) + T_PLUMA_CALLA + own
			s = f
		"detras":
			f = T_DETRAS_IN + T_DETRAS + own
			s = f
		"luz":
			f = T_LUZ + own
			s = f
		"certeza":
			f = T_CERTEZA + own
			s = f
	return Vector2(f, s)


## Duración de la sesión (o de lo que queda desde el beat `from`): x = mínima, y = máxima.
static func range_of(beats: Array, nivel: int, from: int = 0) -> Vector2:
	var r := Vector2.ZERO
	for i in range(from, beats.size()):
		r += beat_range(beats[i] as Dictionary, nivel)
	return r


## Firma de la estructura (qué beats y en qué orden; las preguntas con su tipo).
static func signature(beats: Array) -> String:
	var parts: PackedStringArray = []
	for b in beats:
		var d := b as Dictionary
		var k := str(d.get("k", ""))
		if k == "pregunta":
			k += ":" + str(d.get("q", ""))
		elif k == "marca" and bool(d.get("rapida", false)):
			k = "rafaga"
		elif k == "replay" and bool(d.get("tu_voz", false)):
			k = "tu_voz"
		elif k == "linea":
			k = str(d.get("g", "linea"))
		parts.append(k)
	return "-".join(parts)


## Sesión completa: {beats, nivel, firma, lineas (ids), min_s, max_s, segundos}. Prueba hasta 28 estructuras y se
## queda con una que no esté en la memoria de la partida (mem.firmas) y dure lo que debe (F_MIN ≤ min_s, max_s ≤ S_MAX;
## la advertencia y la fatal, LIMITS).
## `opts`: {"apertura": "intro" | "directo" | "replay" | "silencio" | "golpe"} fija la apertura (pruebas);
## {"entrada": clave de lineas_haime} = lo que dice al cerrar la puerta («Te pongo en Coaching yo»);
## {"mentira": n} = le mentiste en Ezlaki (gancho de IA): beat «mentira» tras el primer error;
## {"recuerdos": [claves]} = lo que recuerda de tus calibraciones anteriores (QaFeedback._memory_facts): la advertencia
## y la fatal lo dicen (grupo «recuerdo», cada línea con su «si»).
static func build_session(entry: Dictionary, n: int, fatal: bool, warning: bool, rng: RandomNumberGenerator, mem: Dictionary = {}, max_n: int = 4, opts: Dictionary = {}) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := INF
	var sigs: Array = mem.get("firmas", [])
	for attempt in 28:
		var s := _build_once(entry, n, fatal, warning, rng, mem, max_n, opts)
		var cost := 0.0
		var lim := limits(int(s["nivel"]))
		cost += maxf(float(lim[0]) - float(s["min_s"]), 0.0) * 4.0 + maxf(float(s["max_s"]) - float(lim[1]), 0.0) * 4.0
		cost += maxf(first_mark_s(s["beats"] as Array, int(s["nivel"])) - (FIRST_MARK_MAX if int(s["nivel"]) < 3 else FIRST_MARK_MAX + 5.0), 0.0) * 2.0
		var seen := sigs.find(str(s["firma"]))
		if seen >= 0:
			cost += 3.0 + 0.1 * float(seen)  # repetida: cuanto más reciente, peor (pero antes repetida que fuera de tiempo)
		if cost < best_cost:
			best_cost = cost
			best = s
		if cost <= 0.0:
			break
	return best


static func remember_session(mem: Dictionary, s: Dictionary) -> void:
	var lines: Array = mem.get("lineas", [])
	for id in s.get("lineas", []):
		lines.erase(id)
		lines.append(id)
	while lines.size() > MEM_LINES:
		lines.pop_front()
	mem["lineas"] = lines
	var sigs: Array = mem.get("firmas", [])
	sigs.erase(s.get("firma", ""))
	sigs.append(s.get("firma", ""))
	while sigs.size() > MEM_SIGS:
		sigs.pop_front()
	mem["firmas"] = sigs
	mem["sesiones"] = int(mem.get("sesiones", 0)) + 1


static func _build_once(entry: Dictionary, n: int, fatal: bool, warning: bool, rng: RandomNumberGenerator, mem: Dictionary, max_n: int, opts: Dictionary = {}) -> Dictionary:
	var nivel := level_of(n, fatal, warning)
	var tipo := entry_type(entry)
	var used: Array = []
	# Las marcas reales (1..4), en orden al azar: con cuál abre cambia cada vez.
	var marks := marks_of(entry)
	if marks.is_empty():
		marks.append("generica")
	if marks.size() > MAX_OM:
		marks.resize(MAX_OM)
	var shuffled: Array[String] = []
	var mpool := marks.duplicate()
	while not mpool.is_empty():
		shuffled.append(mpool.pop_at(rng.randi() % mpool.size()))
	var seed_v := rng.randi()
	var mark_beats: Array = []
	for i in shuffled.size():
		var ol := opportunity_line_v32(entry, shuffled[i], tipo, nivel, rng, mem, used, seed_v + i * 31)
		if ol.is_empty():
			continue
		var mb := {"k": "marca", "mark": shuffled[i], "key": ol["key"], "text": ol["text"], "quote": ol.get("quote", ""), "row": row_of(entry, shuffled[i])}
		# Ritmo: explica los primeros; los demás van en ráfaga (la pluma, el rojo en la pantalla con el texto, y «Otra.»).
		if nivel < 4 and mark_beats.size() >= FULL_MARKS[nivel]:
			var c := _g("rafaga", nivel, tipo, rng, mem, used)
			if c.is_empty():
				c = _g("conector", nivel, tipo, rng, mem, used)
			if not c.is_empty():
				mb["ui_text"] = mb["text"]
				mb["key"] = c["key"]
				mb["text"] = c["text"]
				mb["rapida"] = true
		mark_beats.append(mb)
	# Repaso del caso: el auricular reproduce tu contacto distorsionado y Haime lo corta con el caso concreto (q4_caso_*).
	var det: Dictionary = (PersonajesP5.counter(DETAIL_KEY, {}) as Dictionary).get(str(entry.get("id", "")), {})
	var base := str(det.get("base", base_id({"id": str(entry.get("id", ""))})))
	var caso: Dictionary = (_d().get("casos", {}) as Dictionary).get(base, (_d().get("caso_tipo", {}) as Dictionary).get(tipo, {}))
	var replay := {"k": "replay", "caso": _line(caso)}
	# Entrada: el seguro de la puerta siempre; lo que dice (o si solo te mira) es un extra.
	var door := {"k": "puerta"}
	if str(opts.get("entrada", "")) != "":
		door.merge(_lh(str(opts["entrada"])))
	var intro_l := {}
	if nivel == 3:
		intro_l = _g("adv_intro", nivel, tipo, rng, mem, used)
	else:
		var lv := "3" if nivel == 4 else str(nivel)
		intro_l = _line(pick_fresh((((_d().get("intro", {}) as Dictionary).get(tipo, {}) as Dictionary).get(lv, []) as Array), nivel, "", rng, mem, used))
	var intro := {"k": "linea", "g": "intro"}
	intro.merge(intro_l)
	if nivel >= 3:
		return _build_peak(entry, n, nivel, tipo, rng, mem, max_n, opts, used, mark_beats, door, replay, intro)
	var qs := _questions_for(nivel)
	var preguntas := qs.filter(func(q: String) -> bool: return q.begins_with("p_"))
	var tareas := qs.filter(func(q: String) -> bool: return q.begins_with("t_"))
	# --- apertura ---
	var opening := str(opts["apertura"]) if opts.has("apertura") else _wpick(rng, {"intro": 4, "directo": 2, "replay": 2, "silencio": 2} if nivel == 1 else {"intro": 2, "directo": 3, "replay": 1, "silencio": 1, "golpe": 2})
	var head: Array = []
	var replay_placed := false
	var slammed := false
	match opening:
		"directo":
			var dl := {"k": "linea", "g": "directo"}
			dl.merge(_g("directo", nivel, tipo, rng, mem, used))
			head.append(dl)
			if not mark_beats.is_empty():
				head.append(mark_beats.pop_front())
		"replay":
			head.append(replay)  # abre con tu contacto en el auricular: el caso hace de intro
			replay_placed = true
		"silencio":
			head.append({"k": "silencio", "s": snappedf(rng.randf_range(2.0, 2.8), 0.1), "sin_salto": true})
			head.append(intro)
		"golpe":
			var g0 := {"k": "golpe"}
			g0.merge(_g("golpe", nivel, tipo, rng, mem, used))
			head.append(g0)
			slammed = true
			head.append(intro)
		_:
			head.append(intro)
	# --- núcleo del nivel (la escalera) y extras posibles ---
	var core: Array = []  # beats obligatorios que se reparten por el cuerpo
	var pool: Array = []  # extras: {"t": "beat"|"puerta"|"pre"|"post"|"con", "b"/"l": …}
	var make_q := func(q: String) -> Dictionary: return _question(q, nivel, tipo, entry, n, max_n, rng, mem, used)
	var pick_q := func(from: Array) -> Dictionary:
		if from.is_empty():
			return {}
		return make_q.call(from.pop_at(rng.randi() % from.size()))
	var silence := {"k": "silencio", "s": snappedf(rng.randf_range(2.4, 3.4), 0.1)}
	silence.merge(_g("silencio", nivel, tipo, rng, mem, used))
	var slam := func() -> Dictionary:
		var gb := {"k": "golpe"}
		gb.merge(_g("golpe", nivel, tipo, rng, mem, used))
		return gb
	match nivel:
		1:
			# 1.ª, fría: el repaso con tu contacto y una pregunta o tarea.
			if not replay_placed:
				core.append(replay)
				replay_placed = true
			var first_task := rng.randf() < 0.4 and not tareas.is_empty()
			var q1: Dictionary = pick_q.call(tareas if first_task else preguntas)
			if not q1.is_empty():
				core.append(q1)
			var q2: Dictionary = pick_q.call(preguntas if first_task else tareas)
			if not q2.is_empty():
				pool.append({"t": "beat", "b": q2})
			pool.append({"t": "beat", "b": silence})
		2:
			# 2.ª: golpea la mesa, te hace repetir el guion y te corta.
			var tb: Dictionary = make_q.call("t_saludo") if tareas.has("t_saludo") else pick_q.call(tareas)
			if not tb.is_empty():
				core.append(tb)
			if not slammed:
				core.append(slam.call())
			else:
				pool.append({"t": "beat", "b": slam.call()})
			var q3: Dictionary = pick_q.call(preguntas)
			if not q3.is_empty():
				pool.append({"t": "beat", "b": q3})
			pool.append({"t": "beat", "b": silence})
			pool.append({"t": "beat", "b": slam.call()})
	if not replay_placed:
		pool.append({"t": "beat", "b": replay})
	if not door.has("key"):
		var dl2 := _g("puerta", nivel, tipo, rng, mem, used) if rng.randf() < 0.5 else (_g("llegaste", nivel, tipo, rng, mem, used) if rng.randf() < 0.8 else _lh("llegaste"))
		pool.append({"t": "puerta", "l": dl2})
	pool.append({"t": "pre", "l": _g("replay_pre", nivel, tipo, rng, mem, used)})
	pool.append({"t": "post", "l": _g("replay_post", nivel, tipo, rng, mem, used)})
	for i in 2:
		pool.append({"t": "con", "l": _g("conector", nivel, tipo, rng, mem, used)})
	# Cierre (el puntaje lo muestra la pantalla; la voz no dice el número).
	var cierre := {"k": "cierre"}
	if nivel == 2:
		cierre.merge(_g("cierre_2", nivel, tipo, rng, mem, used) if rng.randf() < 0.75 else _lh("fb2b_cierre"))
	else:
		cierre.merge(_g("cierre_1", nivel, tipo, rng, mem, used) if rng.randf() < 0.75 else _lh("fb1_cierre"))
	var fin := {"k": "fin"}
	fin.merge(_g("fin", nivel, tipo, rng, mem, used) if rng.randf() < 0.7 else _lh("fin_vuelve"))
	var lie := {}
	if int(opts.get("mentira", 0)) > 0:
		lie = {"k": "mentira", "castigo": int(opts["mentira"])}
		lie.merge(_g("mentira", nivel, tipo, rng, mem, used))
	# --- presupuesto: el núcleo y extras al azar mientras quepan ---
	var fixed: Array = [door] + head + mark_beats + core + [cierre, fin]
	if not lie.is_empty():
		fixed.append(lie)
	var tot := range_of(fixed, nivel)
	var want := F_MIN + rng.randf_range(0.3, 5.0)
	var extras: Array = []
	var cons: Array = []
	var order: Array = []
	while not pool.is_empty():
		order.append(pool.pop_at(rng.randi() % pool.size()))
	for it in order:
		if tot.x >= want:
			break
		var item := it as Dictionary
		var kind := str(item["t"])
		var d := Vector2.ZERO
		if kind == "beat":
			d = beat_range(item["b"] as Dictionary, nivel)
		else:
			if (item["l"] as Dictionary).is_empty():
				continue
			if (kind == "pre" or kind == "post") and not replay_placed:
				continue
			if kind == "con" and cons.size() >= mark_beats.filter(func(m: Dictionary) -> bool: return not bool(m.get("rapida", false))).size():
				continue
			d = Vector2.ONE * line_s(item["l"], nivel)
			if kind == "puerta":
				d -= Vector2.ONE * T_MIRA
		if tot.y + d.y > S_MAX:
			continue
		tot += d
		match kind:
			"beat":
				var nb := item["b"] as Dictionary
				nb["opc"] = true
				extras.append(nb)
				if str(nb.get("k", "")) == "replay":
					replay_placed = true
			"puerta":
				door.merge(item["l"] as Dictionary)
			"pre", "post":
				replay[kind] = item["l"]
			"con":
				cons.append(item["l"])
	# --- cuerpo: los errores en su orden, con lo demás repartido al azar entre ellos ---
	var body: Array = mark_beats.duplicate()
	for x in core + extras:
		body.insert(rng.randi_range(0, body.size()), x)
	# El primer error en rojo llega pronto: como mucho un beat corto del cuerpo antes de él.
	if not head.any(func(h: Dictionary) -> bool: return str(h.get("k", "")) == "marca"):
		for i in body.size():
			if str((body[i] as Dictionary).get("k", "")) == "marca":
				var at0 := 1 if i >= 1 and beat_range(body[0] as Dictionary, nivel).y <= 5.0 else 0
				if i > at0:
					var first: Dictionary = body.pop_at(i)
					body.insert(at0, first)
				break
	if not lie.is_empty():
		# La mentira, justo después del primer error (el de la apertura directa o el primero del cuerpo).
		var at := 0
		if not head.any(func(h: Dictionary) -> bool: return str(h.get("k", "")) == "marca"):
			for i in body.size():
				if str((body[i] as Dictionary).get("k", "")) == "marca":
					at = i + 1
					break
		body.insert(at, lie)
	# Nada de dos golpes seguidos (el segundo se va detrás del beat siguiente).
	for i in range(1, body.size()):
		if str((body[i] as Dictionary).get("k", "")) == "golpe" and str((body[i - 1] as Dictionary).get("k", "")) == "golpe" and i + 1 < body.size():
			var moved: Dictionary = body.pop_at(i)
			body.insert(i + 1, moved)
	# Conectores («Mírala bien.») delante de errores explicados.
	var out_body: Array = []
	for b in body:
		var bd := b as Dictionary
		if str(bd.get("k", "")) == "marca" and not bool(bd.get("rapida", false)) and not cons.is_empty():
			var cl := {"k": "linea", "g": "conector", "opc": true}
			cl.merge(cons.pop_front() as Dictionary)
			out_body.append(cl)
		out_body.append(bd)
	var beats: Array = [door] + head + out_body + [cierre, fin]
	return _pack(beats, nivel)


## Lo que recuerda (grupo «recuerdo»): una línea cuyo «si» esté entre los hechos; las concretas antes que la de siempre.
static func _memory_line(facts: Array, nivel: int, tipo: String, rng: RandomNumberGenerator, mem: Dictionary, used: Array) -> Dictionary:
	if facts.is_empty():
		return {}
	var concrete: Array = []
	var general: Array = []
	for l in group("recuerdo"):
		var si := str((l as Dictionary).get("si", ""))
		if not facts.has(si):
			continue
		if si == "siempre":
			general.append(l)
		else:
			concrete.append(l)
	var from := concrete if not concrete.is_empty() and (general.is_empty() or rng.randf() < 0.8) else general
	var picked := pick_fresh(from, nivel, tipo, rng, mem, used)
	var out := _line(picked)
	if not out.is_empty():
		out["si"] = str(picked.get("si", ""))  # la pantalla resalta en la lista aquello de lo que habla
	return out


## Extras que caben: de `seq` (en orden) se quedan todos los obligatorios y, al azar, los opcionales («opc») mientras la
## sesión no pase del máximo, hasta llegar al largo buscado.
static func _fit(seq: Array, nivel: int, rng: RandomNumberGenerator) -> Array:
	var lim := limits(nivel)
	var tot := Vector2.ZERO
	var opt: Array = []
	for i in seq.size():
		if bool((seq[i] as Dictionary).get("opc", false)):
			opt.append(i)
		else:
			tot += beat_range(seq[i] as Dictionary, nivel)
	var want := float(lim[0]) + rng.randf_range(1.5, (float(lim[1]) - float(lim[0])) * 0.6)
	var chosen: Dictionary = {}
	while not opt.is_empty():
		var i: int = opt.pop_at(rng.randi() % opt.size())
		if tot.x >= want:
			break
		var d := beat_range(seq[i] as Dictionary, nivel)
		if tot.y + d.y > float(lim[1]):
			continue
		tot += d
		chosen[i] = true
	var out: Array = []
	var carry := false  # el beat en que dejaba la silla era un extra que no entró: la deja en el siguiente
	for i in seq.size():
		var d := seq[i] as Dictionary
		if not bool(d.get("opc", false)) or chosen.has(i):
			if carry:
				d["de_pie"] = true
				carry = false
			out.append(d)
		elif bool(d.get("de_pie", false)):
			d.erase("de_pie")
			carry = true
	return out


## La última advertencia (nivel 3) y la fatal (nivel 4): guion por fases (el orden importa), con extras según quepan.
##   3 · Más calmado y frío que nunca: dos vueltas de llave, empieza sentado, se levanta al «Mírame», tu error, lo que
##       recuerda de tus veces anteriores, una pregunta que te corta, tu propia voz en el auricular, deja de anotar, se
##       para detrás de ti y te quita el auricular, y termina diciéndote sin gritar que no va a haber otra.
##   4 · Empieza casi normal (tu puntaje ya está escrito), calibra de verdad (tu contacto, tu error, lo que recuerda,
##       preguntas que ya no importan y que corta), las luces fallan una por una, ya no se sienta, deja de anotar, se para
##       detrás, te quita el auricular… y cuando ya sabes que no sales: «Cero sobre cien. Te voy a calibrar.» y la muerte.
static func _build_peak(entry: Dictionary, n: int, nivel: int, tipo: String, rng: RandomNumberGenerator, mem: Dictionary, max_n: int, opts: Dictionary, used: Array, mark_beats: Array, door: Dictionary, replay: Dictionary, intro: Dictionary) -> Dictionary:
	var fatal := nivel == 4
	var opc := func(b: Dictionary) -> Dictionary:
		b["opc"] = true
		return b
	var ln := func(g: String, kind: String) -> Dictionary:
		var b := {"k": kind, "g": g}
		b.merge(_g(g, nivel, tipo, rng, mem, used))
		return b
	# Entrada: dos vueltas de llave y una frase tranquila.
	door["doble"] = true
	if not door.has("key"):
		door.merge(_g("fatal_in" if fatal else "adv_puerta", nivel, tipo, rng, mem, used))
	# Preguntas: te corta la respuesta; en la fatal, además, da igual lo que contestes.
	var qs := _questions_for(nivel)
	var make_q := func() -> Dictionary:
		if qs.is_empty():
			return {}
		var q: String = qs.pop_at(rng.randi() % qs.size())
		var b := _question(q, nivel, tipo, entry, n, max_n, rng, mem, used)
		if b.is_empty():
			return {}
		b["corte"] = CORTE_FATAL if fatal else CORTE_ADV
		b["repite"] = false
		b["r_corta"] = _g("adv_corta", nivel, tipo, rng, mem, used)
		if fatal:
			b["da_igual"] = true
			b["r_igual"] = _g("da_igual", nivel, tipo, rng, mem, used)
		return b
	var memory := {"k": "recuerdo"}
	memory.merge(_memory_line(opts.get("recuerdos", []) as Array, nivel, tipo, rng, mem, used))
	var voice := {"k": "replay", "tu_voz": true, "post": _g("tu_voz", nivel, tipo, rng, mem, used)}
	var pen := {"k": "pluma", "s": snappedf(rng.randf_range(1.6, 2.2), 0.1)}
	pen.merge(_g("adv_pluma", nivel, tipo, rng, mem, used))
	var back := {"k": "detras"}
	back.merge(_g("detras", nivel, tipo, rng, mem, used))
	var headset := {"k": "auricular", "desde_atras": true}
	headset.merge(_g("auricular", nivel, tipo, rng, mem, used))
	var lie := {}
	if int(opts.get("mentira", 0)) > 0:
		lie = {"k": "mentira", "castigo": int(opts["mentira"])}
		lie.merge(_g("mentira", nivel, tipo, rng, mem, used))
	var first: Dictionary = mark_beats[0] if not mark_beats.is_empty() else {}
	var rest: Array = mark_beats.slice(1)
	for m in rest:
		# Los demás errores, en ráfaga (también en la fatal: no es otra clase, es la cuenta).
		if not bool((m as Dictionary).get("rapida", false)):
			var c := _g("rafaga", nivel, tipo, rng, mem, used)
			if not c.is_empty():
				m["ui_text"] = m["text"]
				m["key"] = c["key"]
				m["text"] = c["text"]
				m["rapida"] = true
	var seq: Array = [door]
	var mid: Array = []  # el cuerpo: bloques que se barajan (cada bloque es una lista de beats)
	if not fatal:
		# --- 3: la última advertencia ---
		if str(opts.get("apertura", "")) == "intro" or rng.randf() < 0.7:
			seq.append(intro)
		seq.append({"k": "linea", "g": "advertencia", "key": "advertencia", "text": _lh("advertencia")["text"]})
		if not first.is_empty():
			seq.append(first)
		if not lie.is_empty():
			seq.append(lie)
		if memory.has("key"):
			mid.append([memory])
		var q3: Dictionary = make_q.call()
		if not q3.is_empty():
			mid.append([q3])
		mid.append([voice])
		if not rest.is_empty():
			mid.append(rest)
		mid.append([opc.call(pen)])
		mid.append([opc.call(replay)])
		var am: Dictionary = ln.call("amenaza", "amenaza")
		mid.append([opc.call(am)])
		var q3b: Dictionary = make_q.call()
		if not q3b.is_empty():
			mid.append([opc.call(q3b)])
	else:
		# --- 4: la fatal ---
		var b1: Array = [replay, first] if rng.randf() < 0.5 else [first, replay]
		for b in b1:
			if not (b as Dictionary).is_empty():
				seq.append(b)
		seq.append({"k": "luz"})
		var l1: Dictionary = ln.call("fatal_luz", "linea")
		seq.append(opc.call(l1))
		if not lie.is_empty():
			seq.append(lie)
		if memory.has("key"):
			mid.append([memory])
		else:
			mid.append([opc.call(intro)])
		var q4: Dictionary = make_q.call()
		if not q4.is_empty():
			mid.append([q4])
		mid.append([voice])
		if not rest.is_empty():
			mid.append(rest)
		else:
			mid.append([opc.call({"k": "marca", "mark": "", "key": "fb3_om2", "text": _lh("fb3_om2")["text"], "row": -1, "quote": ""})])
		var q4b: Dictionary = make_q.call()
		if not q4b.is_empty():
			mid.append([opc.call(q4b)])
	# El cuerpo, barajado por bloques. Deja la silla al empezar el primer bloque (la advertencia) o el segundo (la fatal:
	# el primero todavía lo dice sentado, «casi normal») y ya no vuelve a sentarse.
	var blocks: Array = []
	while not mid.is_empty():
		blocks.append(mid.pop_at(rng.randi() % mid.size()))
	var stand_at := mini(1 if fatal else 0, blocks.size() - 1)
	for i in blocks.size():
		var block: Array = blocks[i]
		if i == stand_at and not block.is_empty():
			(block[0] as Dictionary)["de_pie"] = true
		seq.append_array(block)
	if fatal:
		seq.append({"k": "luz"})
		var ns: Dictionary = ln.call("no_sales", "amenaza")
		seq.append(opc.call(ns))
		# La pluma deja de sonar: en la fatal va siempre (es una de las señales de que ya lo sabes), un poco más corta.
		pen["s"] = snappedf(rng.randf_range(1.2, 1.6), 0.1)
		seq.append(pen)
	seq.append(back)
	seq.append(headset)
	if fatal:
		# El último «error»: ya no es del contacto (grupo fatal_om; sin él, la línea de siempre).
		var last_om := _g("fatal_om", nivel, tipo, rng, mem, used)
		if last_om.is_empty():
			last_om = _lh("fb3_om3")
		seq.append({"k": "marca", "mark": "", "key": last_om["key"], "text": last_om["text"], "row": -1, "quote": ""})
		var sure := {"k": "certeza"}
		var sure_l := pick_fresh(group("fatal_pre"), nivel, tipo, rng, mem, used)
		sure.merge(_line(sure_l))
		if bool(sure_l.get("antes", false)):
			sure["antes"] = true  # la línea habla de apagar la luz: primero la dice, después se apaga
		seq.append(sure)
		var fb3 := {"k": "fatal"}
		fb3.merge(_lh("fb3_cierre"))
		seq.append(fb3)
	else:
		var cierre := {"k": "cierre"}
		cierre.merge(_lh("advertencia_cierre"))
		seq.append(cierre)
		var fin := {"k": "fin"}
		fin.merge(_g("adv_fin", nivel, tipo, rng, mem, used))
		seq.append(fin)
	return _pack(_fit(seq, nivel, rng), nivel)


static func _pack(beats: Array, nivel: int) -> Dictionary:
	var ids: Array = []
	var om := 0
	for b in beats:
		var d := b as Dictionary
		if str(d.get("k", "")) == "marca":
			om += 1
			d["om"] = om
		for key in ["pre", "caso", "post"]:
			if d.has(key) and str((d[key] as Dictionary).get("key", "")) != "":
				ids.append(str(d[key]["key"]))
		if str(d.get("key", "")) != "":
			ids.append(str(d["key"]))
	var r := range_of(beats, nivel)
	return {"beats": beats, "nivel": nivel, "firma": signature(beats), "lineas": ids, "min_s": r.x, "max_s": r.y, "segundos": (r.x + r.y) * 0.5}


## Línea de una oportunidad (marca real en ese tipo de caso, o genérica del tipo), elegida entre las menos usadas en la
## partida. La cita (tu frase, el valor que elegiste) va aparte: la muestra la pantalla, Haime no la dice (antes iba
## pegada al subtítulo: «tu frase» + la línea, y la voz no la decía).
static func opportunity_line_v32(entry: Dictionary, mark: String, tipo: String, nivel: int, rng: RandomNumberGenerator, mem: Dictionary, used: Array, _seed_v: int) -> Dictionary:
	var cands: Array = []
	for l in (_d().get("marcas", {}) as Dictionary).get(mark, []):
		if ((l as Dictionary).get("tipos", []) as Array).has(tipo):
			cands.append(l)
	var l := pick_fresh(cands, nivel, "", rng, mem, used)
	if l.is_empty():
		l = pick_fresh((_d().get("genericas", {}) as Dictionary).get(tipo, []), nivel, "", rng, mem, used)
	if l.is_empty():
		return {}
	var out := _line(l)
	out["quote"] = quote_for(entry, mark).replace("\n", " ")
	return out

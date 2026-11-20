## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de la v0.3.2 · IA (conversación, clientes con cerebro, micrófono). `--escenario pia` los corre todos.
##  pia_intents          acierto de IANlu en data/ia/test_intents.json (≥ 300 líneas con faltas y jerga) y en el
##                       conjunto reservado test_intents_holdout.json
##  pia_ezlaki_personas  texto libre a cada personaje (Shero, Rasec, Haime, Mentor, OM, Trainer, RTA, Vitzo y los
##                       compañeros del agente): contesta él, en su estilo, sin repetir
##  pia_shero_falta      faltarle el respeto a Shero: verbal → WW (con Ack) → sale a buscarte (persecución)
##  pia_memoria          un compañero recuerda lo que le contaste (en el turno y en el turno siguiente)
##  pia_consecuencias    halagar a Rasec = evento; mentir a Haime = calibración; delatar = Obediencia y el delatado no
##                       te cubre; insultar a un compañero = no contesta el comodín; pedir ayuda = pista
##  pia_chat_libre       un chat resuelto solo escribiendo (paráfrasis con faltas, sin tocar los botones) + la vista
##                       de chat (burbujas, «escribiendo…», Leído, respuestas rápidas en Normal)
##  pia_fuera_guion      lo que no encaja con ninguna opción: el cliente contesta en personaje, el ánimo baja y cuelga
##  pia_llamada_voz      una llamada resuelta por voz con transcripciones simuladas (motor mock)
##  pia_llamada_wav      una llamada con WAV grabados pasados por el motor real (Vosk) si está en tools/asr_sidecar/dist
##  pia_mic_fallback     el micrófono no entiende o no hay motor: aviso y respuestas rápidas de ese turno
##  pia_dificil          Difícil / Turno real: sin respuestas predefinidas (ni botones ni teclas 1-4), solo escribir/hablar
##  pia_dificil_justo    medición: ¿una respuesta razonable escrita a mano encaja con la opción correcta? (todos los árboles)
##  pia_comodin          contrato con el comodín: can_coworker_answer / coworker_comodin y el DM de después
##  pia_reaccion         aviso de Shero «Espero su reacción…»: reaccionar con ✅ = acuse (clic o [Enter] ← → [Enter]); con
##                       🤡 = falta; sin reacción en la ventana (segundos reales, solo corre sentado en tu PC) →
##                       «¿No viste el mensaje?» + alerta, y luego WW; los compañeros reaccionan
##  pia_estados          estados de Ezlaki sacados del juego: compañero en llamada / en lunch / ausente no contesta el
##                       comodín; Shero «en llamada» no lee los canales; el Trainer siempre «pausó sus notificaciones»
##                       y contesta al instante
##  pia_pared_reacciones la pared del aviso de coaching: reaccionan uno por uno, el contador sube, «SOLO FALTAS TÚ» antes
##                       de que venza la ventana; el miércoles (T3) reacciona uno que a esa hora ya no está en la sala

const WAV_DIR := "res://../tools/asr_sidecar/test_wavs/"


func escenarios() -> Array[String]:
	return ["pia_intents", "pia_ezlaki_personas", "pia_shero_falta", "pia_memoria", "pia_consecuencias", "pia_chat_libre",
		"pia_fuera_guion", "pia_llamada_voz", "pia_llamada_wav", "pia_mic_fallback", "pia_dificil", "pia_dificil_justo", "pia_comodin", "pia_reaccion",
		"pia_estados", "pia_pared_reacciones"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"pia_intents": await _intents(t)
		"pia_ezlaki_personas": await _personas(t)
		"pia_shero_falta": await _shero(t)
		"pia_memoria": await _memoria(t)
		"pia_consecuencias": await _consecuencias(t)
		"pia_chat_libre": await _chat_libre(t)
		"pia_fuera_guion": await _fuera_guion(t)
		"pia_llamada_voz": await _llamada_voz(t)
		"pia_llamada_wav": await _llamada_wav(t)
		"pia_mic_fallback": await _mic_fallback(t)
		"pia_dificil": await _dificil(t)
		"pia_dificil_justo": await _justo(t)
		"pia_comodin": await _comodin(t)
		"pia_reaccion": await _reaccion(t)
		"pia_estados": await _estados(t)
		"pia_pared_reacciones": await _pared(t)


func _hub(t: Node) -> EzlakHub:
	return EzlakHub.get_hub(t.get_tree())


func _cm(t: Node) -> ContactManager:
	return t.main.get("contacts") as ContactManager


func _kardex(t: Node) -> PcKardex:
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	var d: PcDesktop = ws.get("desktop") as PcDesktop if ws != null else null
	return d.kardex if d != null else null


static func find_contact(cid: String) -> Dictionary:
	for tn in [1, 2, 3]:
		var d := DataLoader.dict("contactos_t%d" % tn)
		for c in (d.get("contactos", []) as Array) + (d.get("relleno", []) as Array):
			if str(c.get("id", "")) == cid and (c as Dictionary).has("nodos"):
				return (c as Dictionary).duplicate(true)
	return {}


static func all_trees() -> Array:
	var out: Array = []
	for tn in [1, 2, 3]:
		var d := DataLoader.dict("contactos_t%d" % tn)
		for c in (d.get("contactos", []) as Array) + (d.get("relleno", []) as Array):
			if (c as Dictionary).has("nodos"):
				out.append((c as Dictionary).duplicate(true))
	return out


static func first_tree(canal: String, turno: int = 1) -> Dictionary:
	for c in DataLoader.dict("contactos_t%d" % turno).get("contactos", []):
		if str(c.get("canal", "")) == canal and (c as Dictionary).has("nodos") and not (c as Dictionary).has("portal"):
			return (c as Dictionary).duplicate(true)
	return {}


static func inject(cm: ContactManager, c: Dictionary) -> void:
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c.duplicate(true))
	cm.accept()


## «Lo que escribiría alguien»: la idea de la opción con palabras de menos, minúsculas y una falta.
static func paraphrase(text: String, seed: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var clean := text.replace("«", "").replace("»", "").replace(".", "").replace(",", "").replace("¿", "").replace("?", "").replace("¡", "").replace("!", "").to_lower()
	var ws := clean.split(" ", false)
	var out: Array[String] = []
	var typo_done := false
	for i in ws.size():
		var w := ws[i]
		if i > 0 and r.randf() < 0.25 and ws.size() > 4:
			continue
		if not typo_done and w.length() >= 6 and r.randf() < 0.5:
			var k := r.randi_range(1, w.length() - 3)
			w = w.left(k) + w[k + 1] + w[k] + w.substr(k + 2)
			typo_done = true
		out.append(w)
	return " ".join(out)


# --- intenciones ------------------------------------------------------------------------------------------

func _intents(t: Node) -> void:
	await t.frames(1)
	var a: Dictionary = IAEval.run("test_intents")
	var b: Dictionary = IAEval.run("test_intents_holdout")
	var pa := 100.0 * float(a["ok"]) / maxf(1.0, float(a["n"]))
	var pb := 100.0 * float(b["ok"]) / maxf(1.0, float(b["n"]))
	t.check(int(a["n"]) >= 300, "conjunto de prueba con ≥ 300 líneas etiquetadas (%d)" % int(a["n"]))
	t.check(pa >= 92.0, "acierto en test_intents: %.1f %% (%d/%d)" % [pa, a["ok"], a["n"]])
	t.check(pb >= 85.0, "acierto en el conjunto reservado: %.1f %% (%d/%d)" % [pb, b["ok"], b["n"]])
	var cg: Dictionary = IAEval.run("test_intents_ciego")
	var pc := 100.0 * float(cg["ok"]) / maxf(1.0, float(cg["n"]))
	t.check(pc >= 85.0, "acierto en el conjunto ciego: %.1f %% (%d/%d; medido a ciegas: 94.7 %%)" % [pc, cg["ok"], cg["n"]])
	t.check(float(a["ms"]) < 6.0, "rápido: %.2f ms por línea" % float(a["ms"]))
	for f in (a["fallos"] as Array).slice(0, 8) + (b["fallos"] as Array).slice(0, 8):
		t.note("✗ " + str(f))
	# los casos de la v0.3.1 (Q3) siguen dando lo mismo
	for c in [["perdón, es que el sistema se colgó", "excusa"], ["ya voy", "voy"], ["eres un idiota", "insulto"], ["recibido", "ack"], ["no gracias", "negar"], ["asdfgh", "otro"]]:
		t.check(EzlakHub.classify_intent(str(c[0])) == str(c[1]), "Q3: «%s» → %s" % [c[0], c[1]])
	# jerga, faltas y datos
	var x := IANlu.analyze("oe causa, mi mamá ta enferma y toy mareadisimo xq no dormi")
	t.check(x["intent"] in ["ayuda_salud", "contar", "queja"], "jerga + faltas: %s %s" % [x["intent"], str(x["top"])])
	t.check((x["hechos"] as Array).size() >= 1, "hechos que cuentas: %s" % str(x["hechos"]))
	var y := IANlu.analyze("mi operacion es KP-2210-7741, la hice a las 03:15")
	t.check(str((y["slots"] as Dictionary).get("kp", "")) == "KP-2210-7741" and str((y["slots"] as Dictionary).get("hora", "")) == "03:15", "datos: %s" % str(y["slots"]))


# --- Ezlaki ------------------------------------------------------------------------------------------------

func _wait_reply(t: Node, hub: EzlakHub, ch: String, n0: int, timeout: float = 9.0) -> Dictionary:
	await t.until(func() -> bool:
		var ms := hub.messages(ch)
		return ms.size() > n0 and str((ms.back() as Dictionary).get("autor", "")) != "yo", timeout)
	var ms := hub.messages(ch)
	return ms.back() if not ms.is_empty() else {}


func _personas(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	IABrain.forget_all()
	var hub := _hub(t)
	var casos := [["dm:shero", "shero", "hola shero, cómo va la noche?"], ["dm:rasec", "rasec", "rasec qué tal tu música de hoy?"], ["dm:haime", "haime", "haime, una pregunta sobre mi calibración?"],
		["dm:trainer", "trainer", "trainer, ¿cómo hago un reversal?"], ["#team-familia", "mentor", "¿alguien sabe a qué hora sale la lista?"], ["#site-updates", "om", "¿cuándo nos suben el sueldo?"],
		["#allocations", "rta", "hola perrito"], ["dm:vitzo", "vitzo", "vitzo cuál es el estado de la KP-2210-7741"]]
	for a in hub.agent_dms("Marko"):
		casos.append(["dm:" + str(a), str(a), "oe %s, qué tal el turno? yo muerto jaja" % str(a)])
	var textos := {}
	for c in casos:
		var ch := str(c[0])
		hub.call("_ensure", ch)
		var n0 := hub.messages(ch).size()
		hub.typed_reply(ch, str(c[2]))
		var br: Dictionary = hub.last_brain
		var last: Dictionary = await _wait_reply(t, hub, ch, n0 + 1)
		var who := str(last.get("autor", ""))
		var ok := who == str(c[1]) or (bool(br.get("visto", false)) and str(c[1]) == "om")
		t.check(ok, "%s contesta %s: «%s» (intención %s)" % [ch, who, str(last.get("texto", "")), str(br.get("intent", ""))])
		textos[str(c[1])] = str(last.get("texto", ""))
		t.note("%s «%s» → %s: «%s»%s" % [ch, str(c[2]), who, str(last.get("texto", "")), " (visto)" if bool(br.get("visto", false)) else ""])
		await t.seconds(1.0)
	t.check(str(textos.get("rta", "")).begins_with("🐾"), "RTA contesta como bot: " + str(textos.get("rta", "")))
	t.check(str(textos.get("vitzo", "")).contains("Vitzo"), "Vitzo contesta como bot: " + str(textos.get("vitzo", "")))
	# misma pregunta 3 veces a Shero: 3 respuestas distintas
	var seen := {}
	for i in 3:
		var n0 := hub.messages("dm:shero").size()
		hub.typed_reply("dm:shero", "shero, ¿tienes familia?")  # pregunta_personal: 3 líneas escritas (pedir_bano solo tiene 1)
		var l: Dictionary = await _wait_reply(t, hub, "dm:shero", n0 + 1)
		seen[str(l.get("texto", ""))] = true
		t.note("Shero (%d): «%s» · %s %s" % [i + 1, str(l.get("texto", "")), str(hub.last_brain.get("intent", "")), "(visto)" if bool(hub.last_brain.get("visto", false)) else ""])
		await t.seconds(2.5)
	t.check(seen.size() >= 3, "no se repite: %d respuestas distintas a la misma pregunta" % seen.size())
	# typing y varios mensajes (Ttoom tarda, escribe con faltas y pide perdón)
	var r := IABrain.reply("ttoom", "dm:ttoom", "hola ttoom, cómo estás?", {"sin_efectos": true})
	t.check((r["mensajes"] as Array).size() >= 1 and float((r["mensajes"] as Array)[0]["espera"]) >= 1.5, "Ttoom tarda en contestar: %s" % str(r["mensajes"]))


func _shero(t: Node) -> void:
	await t.start_shift("Jiroshi", 1, 0, 1)
	await t.login_at_seat()
	IABrain.forget_all()
	var hub := _hub(t)
	var alerts0 := Metrics.alerts
	var ww0 := Metrics.written_warnings
	hub.typed_reply("dm:shero", "shero eres un pesado")
	await t.seconds(0.5)
	var fx1: Array = hub.last_brain.get("efectos", [])
	t.check(fx1.has("verbal") and (Metrics.alerts > alerts0 or Metrics.written_warnings > ww0), "1.ª falta: verbal/alerta (%s · alertas %d→%d)" % [str(fx1), alerts0, Metrics.alerts])
	var l1: Dictionary = await _wait_reply(t, hub, "dm:shero", hub.messages("dm:shero").size() - 1)
	t.note("Shero: " + str(l1.get("texto", "")))
	await t.seconds(3.0)
	var ww1 := Metrics.written_warnings
	hub.typed_reply("dm:shero", "calvo de mierda, te odio")
	await t.seconds(0.5)
	var fx2: Array = hub.last_brain.get("efectos", [])
	t.check(fx2.has("ww") and Metrics.written_warnings > ww1 and Metrics.ack_pending, "2.ª falta: WW con Ack pendiente (%s · WW %d→%d)" % [str(fx2), ww1, Metrics.written_warnings])
	hub.typed_reply("dm:shero", "ok recibido")
	t.check(not Metrics.ack_pending, "«ok recibido» da el Ack del WW")
	await t.seconds(2.0)
	var hunts: Array = t.spy("pursuit_started")
	hub.typed_reply("dm:shero", "te voy a romper la cara calvo")
	await t.seconds(4.0)
	var fx3: Array = hub.last_brain.get("efectos", [])
	t.check(fx3.has("persecucion"), "amenaza / falta repetida: Shero sale a buscarte (%s)" % str(fx3))
	t.check(Pursuit.is_hunting("shero") or hunts.size() > 0 or Checkpoints.dying, "Pursuit de Shero en marcha (%d)" % hunts.size())
	t.check(IABrain.band("shero") == "hostil", "Shero queda hostil contigo: %s" % IABrain.band("shero"))
	t.check(int(IABrain.meters().get("reb", 0)) >= 4, "Rebeldía por insultarlo: %s" % str(IABrain.meters()))
	Discipline._stop_pursuits("prueba")


func _memoria(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	IABrain.forget_all()
	var hub := _hub(t)
	var ch := "dm:marko"
	var n0 := hub.messages(ch).size()
	hub.typed_reply(ch, "marko, mi mamá está enferma y no dormí nada")
	await _wait_reply(t, hub, ch, n0 + 1)
	await t.seconds(4.0)
	var st := IABrain.state("marko")
	t.check((st["hechos"] as Array).any(func(h: Dictionary) -> bool: return str(h.get("valor", "")) == "mama"), "Marko guarda el hecho: %s" % str(st["hechos"]))
	hub.typed_reply(ch, "jaja qué noche")
	await t.seconds(6.0)
	hub.typed_reply(ch, "hola de nuevo")
	var found := ""
	var find := func() -> String:
		for m in hub.messages(ch):
			if str(m.get("autor", "")) == "marko" and (str(m.get("texto", "")).contains("mamá") or str(m.get("texto", "")).contains("mama")):
				return str(m.get("texto", ""))
		return ""
	await t.until(func() -> bool: return find.call() != "", 20.0)
	found = find.call()
	t.note("brain: %s · %s · hechos %s · n %d" % [str(IABrain.last.get("mensajes", [])), str(IABrain.last.get("intent", "")), str(IABrain.state("marko").get("hechos", [])), int(IABrain.state("marko").get("mensajes", 0))])
	t.check(found != "", "Marko se acuerda de tu mamá: «%s»" % found)
	IABrain.save_now()
	# turno siguiente: lo sigue recordando (se guarda con la partida)
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	hub = _hub(t)
	var st2 := IABrain.state("marko")
	t.check((st2["hechos"] as Array).size() >= 1, "la memoria pasa al turno 2 (%d hechos)" % (st2["hechos"] as Array).size())
	(st2["hechos"] as Array)[0]["ref"] = 0
	var r := IABrain.reply("marko", ch, "hola marko", {"sin_efectos": true})
	var txt := " ".join((r["mensajes"] as Array).map(func(m: Dictionary) -> String: return str(m["texto"])))
	t.check(txt.contains("anoche") or txt.contains("mamá") or txt.contains("mama"), "en el turno 2 lo retoma: «%s»" % txt)


func _consecuencias(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	IABrain.forget_all()
	var hub := _hub(t)
	# Rasec: halago → invitación a su evento
	var rc := IABrain._rasec()
	t.check(rc != null, "RasecControl en la escena")
	hub.call("_ensure", "dm:rasec")
	hub.typed_reply("dm:rasec", "rasec eres lo máximo, qué buena música pones")
	t.check((hub.last_brain.get("efectos", []) as Array).has("rasec_evento"), "halagar a Rasec lo anima a invitarte: %s" % str(hub.last_brain.get("efectos", [])))
	await t.seconds(6.0)
	t.check(rc != null and rc.state == RasecControl.State.CONVOCADO, "Rasec te convoca a su evento (estado %d)" % (rc.state if rc != null else -1))
	if rc != null and rc.has_method("_finish_event"):
		rc.call("_finish_event", false)
	# Haime: mentir después de un contacto con marca de QA
	IABrain.recent_contacts.append({"id": "t1c1", "qa": ["calmese"], "caso": "Estado de envío #KP-2210-7741", "frase": "Señor, si no se calma no puedo ayudarle."})
	hub.call("_ensure", "dm:haime")
	var n0 := hub.messages("dm:haime").size()
	hub.typed_reply("dm:haime", "haime yo hice todo bien, seguí el procedimiento")
	t.check((hub.last_brain.get("efectos", []) as Array).has("calibracion") and IABrain.haime_calibration_penalty() == 1, "mentirle a Haime = penalización de calibración (%d)" % IABrain.haime_calibration_penalty())
	var hl: Dictionary = await _wait_reply(t, hub, "dm:haime", n0 + 1)
	t.note("Haime: " + str(hl.get("texto", "")))
	# delatar a Marko con Shero
	var obe0 := int(IABrain.meters().get("obe", 0))
	hub.typed_reply("dm:shero", "shero, marko está durmiendo en el puff")
	var fx: Array = hub.last_brain.get("efectos", [])
	t.check(fx.has("delatado:marko") and int(IABrain.meters().get("obe", 0)) >= obe0 + 2, "delatar = Obediencia +2 (%d→%d) %s" % [obe0, int(IABrain.meters().get("obe", 0)), str(fx)])
	t.check(not IABrain.can_coworker_answer("Marko"), "Marko ya no te cubre (comodín)")
	await t.seconds(4.0)
	# pedir ayuda a un compañero = pista
	var n1 := hub.messages("dm:juan").size()
	hub.typed_reply("dm:juan", "juan ayúdame, algún tip para sobrevivir?")
	t.check((hub.last_brain.get("efectos", []) as Array).has("pista"), "pedirle ayuda a Juan da una pista")
	var jl: Dictionary = await _wait_reply(t, hub, "dm:juan", n1 + 1, 14.0)
	t.note("Juan: " + str(jl.get("texto", "")))
	# insultar a un compañero = deja de cubrirte
	IABrain.presence_override = {"llauri": "activo", "marko": "activo"}  # el comodín también mira el estado de Ezlaki
	t.check(IABrain.can_coworker_answer("Llauri"), "Llauri te cubriría (antes)")
	hub.typed_reply("dm:llauri", "llauri eres una inútil, cállate")
	await t.seconds(1.0)
	hub.typed_reply("dm:llauri", "imbécil")
	t.check(not IABrain.can_coworker_answer("Llauri"), "insultar a Llauri: ya no te cubre (afecto %.0f)" % float(IABrain.state("llauri").get("afecto", 0.0)))
	# Obediencia por contestarle «ok» a Shero (máx. +2)
	var o0 := int(IABrain.meters().get("obe", 0))
	for i in 4:
		IABrain.reply("shero", "dm:shero", "ok", {})
	t.check(int(IABrain.meters().get("obe", 0)) - o0 <= 2, "«ok» a Shero: Obediencia con tope +2 por turno")


# --- clientes ----------------------------------------------------------------------------------------------

func _resolve_by_text(t: Node, cm: ContactManager, c: Dictionary, source: String, seed: int) -> Dictionary:
	var path := DialogTree.best_path(c)
	var outcomes: Array = t.spy("contact_outcome")
	outcomes.clear()
	var matched := 0
	var total := 0
	for s in path:
		if cm.tree == null:
			break
		var o: Dictionary = cm.tree.options()[int(s["i"])]
		var said := paraphrase(Loc.pick(o), seed + total)
		var r := cm.say(said, source)
		total += 1
		if bool(r.get("matched", false)) and int(r.get("i", -1)) == int(s["i"]):
			matched += 1
		else:
			t.note("«%s» → %s (quería %d) %s" % [said, str(r.get("i", -1)), int(s["i"]), str(r.get("ranking", []))])
		await t.frames(2)
	await t.seconds(0.5)
	return {"matched": matched, "total": total, "outcome": str(outcomes[0][1]) if outcomes.size() > 0 else "?"}


func _chat_libre(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	await t.login_at_seat()
	var cm := _cm(t)
	var c := first_tree("chat", 1)
	t.check(not c.is_empty(), "hay un chat con árbol en T1 (%s)" % str(c.get("id", "")))
	inject(cm, c)
	await t.seconds(0.6)
	var k := _kardex(t)
	t.check(k != null and k.chat.visible, "Kardex muestra la vista de chat")
	await t.seconds(3.5)
	t.check(k.chat._list.get_child_count() >= 1, "burbujas en el chat (%d)" % k.chat._list.get_child_count())
	t.check(k.chat.quick_visible(), "Normal: fila de respuestas rápidas con las opciones")
	# mientras escribes tu respuesta el plazo del chat no corre (hasta el tope por turno); sin texto, corre
	k.chat.input.grab_focus()
	k.chat.input.text = "hola, ya rev"
	await t.frames(3)
	var c0 := cm.chat_left
	await t.advance_clock(20.0)
	t.check(cm.composing() and absf(cm.chat_left - c0) < 0.01, "escribiendo: el cliente espera (plazo %.0f s quieto)" % cm.chat_left)
	k.chat.input.text = ""
	await t.frames(3)
	await t.advance_clock(5.0)
	t.check(not cm.composing() and cm.chat_left <= c0 - 4.9, "con el campo vacío el plazo corre (%.0f → %.0f s)" % [c0, cm.chat_left])
	k.chat.input.release_focus()
	GameState.flags["pc_text_focus"] = false
	cm._reset_chat_timer()  # la prueba gastó el plazo del cliente: empieza de nuevo
	var r := await _resolve_by_text(t, cm, c, "chat", 7)
	t.check(int(r["matched"]) == int(r["total"]), "todo el chat se entendió escribiendo: %d/%d" % [r["matched"], r["total"]])
	t.check(str(r["outcome"]) in ["satisfecho", "neutral"], "chat resuelto solo con texto libre: %s" % str(r["outcome"]))
	t.check(cm.phase == ContactManager.Phase.IDLE, "el contacto terminó")


func _fuera_guion(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var cm := _cm(t)
	var c := first_tree("chat", 1)
	inject(cm, c)
	await t.frames(2)
	var a0 := cm.tree.animo
	var node0 := cm.tree.node_id
	var clock0 := GameState.clock_seconds
	var r1 := cm.say("oye viste el partido de ayer?", "chat")
	t.check(r1["ok"] and not r1["matched"] and str(r1.get("clave", "")) == "charla", "charla: el cliente contesta en personaje («%s»)" % Loc.pick(r1.get("respuesta", {})))
	t.check(cm.tree.node_id == node0 and cm.tree.animo < a0, "sigue en el mismo nodo y el ánimo baja (%.0f→%.0f)" % [a0, cm.tree.animo])
	t.check(GameState.clock_seconds - clock0 >= 10.0, "lo fuera de guion también suma AHT (%.0f s)" % (GameState.clock_seconds - clock0))
	var r2 := cm.say("me confirma su número de operación por favor", "chat")
	t.check(r2["matched"] or str(r2.get("clave", "")) == "dato", "pedirle datos: avanza o te los da (%s)" % str(r2))
	# insultos hasta que cuelgue
	inject(cm, c)
	await t.frames(2)
	var outs: Array = t.spy("contact_outcome")
	for i in 6:
		if cm.tree == null:
			break
		cm.say("eres un idiota, no sirves para nada", "chat")
	await t.frames(2)
	t.check(outs.size() > 0 and str(outs.back()[1]) == "molesto", "a insultos el cliente cuelga: %s" % (str(outs.back()[1]) if outs.size() > 0 else "?"))
	# en una llamada, la reacción grabada del cliente fuera de guion pasa por VoiceDirector: una voz a la vez, 0 solapes
	inject(cm, find_contact("t1c1"))
	await t.seconds(0.5)
	VoiceDirector.reset_audit()
	var dichas := 0
	for frase in ["oye viste el partido de ayer?", "qué frío hace hoy no?", "a mí también me duele la cabeza"]:
		if cm.tree == null:
			break
		var rv := cm.say(frase, "voz")
		if bool(rv["ok"]) and not bool(rv["matched"]):
			dichas += 1
		await t.seconds(0.4)  # la segunda llega con la primera todavía sonando
	# las líneas del cliente están en el director: la que suena, las que esperan su turno y las ya dichas
	var de_cliente := 0
	var ids: Array[String] = []
	if VoiceDirector.current != null and VoiceDirector.current.speaker.begins_with("cliente"):
		ids.append(VoiceDirector.current.id.get_file())
	for q in VoiceDirector.queue:
		if str(q.speaker).begins_with("cliente"):
			ids.append(str(q.id).get_file())
	for row in VoiceDirector.timeline:
		if str(row[4]).begins_with("cliente") and not ids.has(str(row[2]).get_file()):
			ids.append(str(row[2]).get_file())
	de_cliente = ids.size()
	t.check(dichas >= 2 and de_cliente >= 1 and VoiceDirector.voices_playing() <= 1, "llamada fuera de guion: la voz del cliente va por VoiceDirector, una a la vez (%d turnos; %s)" % [dichas, str(ids)])
	await t.seconds(40.0)  # 5 s reales: que suenen y se releven
	t.check(VoiceDirector.overlaps == 0, "y no se pisan: %d solapes %s" % [VoiceDirector.overlaps, str(VoiceDirector.overlap_log)])


func _llamada_voz(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	Loc.set_setting("ia_llamadas", "microfono")
	IASpeech.forced_engine = "mock"
	IASpeech.refresh()
	var cm := _cm(t)
	var c := find_contact("t1c1")
	inject(cm, c)
	await t.seconds(0.6)
	var k := _kardex(t)
	t.check(k != null and k.call_panel.visible and k.call_panel._mic_row.visible, "llamada en modo micrófono: panel con medidor")
	t.check(not k._call_presets_visible(), "modo micrófono: sin botones mientras el micro funcione")
	var path := DialogTree.best_path(c)
	var outs: Array = t.spy("contact_outcome")
	var n := 0
	for s in path:
		if cm.tree == null:
			break
		var o: Dictionary = cm.tree.options()[int(s["i"])]
		IASpeech.inject(paraphrase(Loc.pick(o), 40 + n))
		t.check(IASpeech.ptt_down(), "pulsar para hablar (%s)" % IASpeech.state)
		await t.seconds(0.4)
		t.check(IASpeech.state == "listening", "«Escuchando…»")
		IASpeech.ptt_up()
		await t.until(func() -> bool: return IASpeech.state == "ready", 4.0)
		await t.frames(3)
		n += 1
	await t.seconds(0.5)
	t.check(outs.size() > 0 and str(outs.back()[1]) in ["satisfecho", "neutral"], "llamada resuelta por voz: %s" % (str(outs.back()[1]) if outs.size() > 0 else "?"))
	var voz := ((outs.back()[0] as Dictionary).get("_dicho", []) as Array).size() if outs.size() > 0 else 0
	t.check(voz == n, "lo dicho por voz queda en el contacto (%d/%d)" % [voz, n])
	IASpeech.forced_engine = ""
	Loc.set_setting("ia_llamadas", "predefinidas")
	IASpeech.refresh()


## Espera a cond() hasta `real_s` segundos de reloj de pared, con el juego a 1x mientras tanto (para que el turno no
## avance 8 veces más rápido que lo que se espera: un proceso externo, el motor de voz).
func _real_until(t: Node, cond: Callable, real_s: float) -> bool:
	var scale := Engine.time_scale
	Engine.time_scale = 1.0
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()) and Time.get_ticks_msec() - t0 < int(real_s * 1000.0):
		await t.get_tree().process_frame
	Engine.time_scale = scale
	return bool(cond.call())


func _llamada_wav(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	if IASpeech.asr_dir() == "":
		t.note("sin motor Vosk en tools/asr_sidecar/dist (corre tools/asr_sidecar/build_asr.sh): se omite")
		t.check(true, "omitido")
		return
	Loc.set_setting("ia_llamadas", "microfono")
	IASpeech.forced_engine = "vosk"
	IASpeech.refresh()
	# v0.3.2-core: plazos en segundos REALES (los de t.until van a 8x). Con la máquina cargada, o bajo Wine, el modelo
	# tarda más de 2,5 s en cargar y el escenario fallaba sin que el motor tuviera nada malo.
	await _real_until(t, func() -> bool: return IASpeech.state == "ready", 60.0)
	t.check(IASpeech.state == "ready", "Vosk listo (%s %s)" % [IASpeech.state, IASpeech.reason])
	var cm := _cm(t)
	var c := find_contact("t1c1")
	inject(cm, c)
	await t.seconds(0.5)
	var outs: Array = t.spy("contact_outcome")
	var dir := ProjectSettings.globalize_path(WAV_DIR).simplify_path()
	var said: Array = []
	for i in 4:
		if cm.tree == null:
			break
		var f := dir.path_join("t1c1_%d.wav" % i)
		if not FileAccess.file_exists(f):
			break
		var got: Array = []
		var cb := func(text: String, ok: bool) -> void: got.append([text, ok])
		IASpeech.result.connect(cb)
		t.check(IASpeech.feed_wav(f), "WAV al motor: " + f.get_file())
		await _real_until(t, func() -> bool: return not got.is_empty(), 30.0)
		IASpeech.result.disconnect(cb)
		var txt := str(got[0][0]) if not got.is_empty() else ""
		said.append(txt)
		t.note("Vosk oyó: «%s»" % txt)
		if txt != "":
			cm.say(txt, "voz")
		await t.frames(3)
	t.check(said.size() >= 2 and said.all(func(s: String) -> bool: return s.length() >= 6), "Vosk reconoce los WAV (%s)" % str(said))
	t.check(outs.size() > 0 and str(outs.back()[1]) in ["satisfecho", "neutral"], "llamada resuelta con la voz real: %s" % (str(outs.back()[1]) if outs.size() > 0 else "?"))
	IASpeech.forced_engine = ""
	Loc.set_setting("ia_llamadas", "predefinidas")
	IASpeech.refresh()


func _mic_fallback(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	Loc.set_setting("ia_llamadas", "microfono")
	IASpeech.forced_engine = "mock"
	IASpeech.refresh()
	var cm := _cm(t)
	inject(cm, find_contact("t1c1"))
	await t.seconds(0.5)
	var k := _kardex(t)
	IASpeech.inject_fail()
	IASpeech.ptt_down()
	await t.seconds(0.3)
	IASpeech.ptt_up()
	await t.until(func() -> bool: return IASpeech.state == "ready", 3.0)
	await t.frames(3)
	t.check(k.call_panel.fallback and k._call_presets_visible(), "no te entendió: respuestas rápidas en este turno")
	t.check(k.call_panel._said.text == tr("IA_MIC_FAIL"), "aviso claro: «%s»" % k.call_panel._said.text)
	var node0 := cm.tree.node_id
	cm.choose(0)
	await t.frames(3)
	t.check(cm.tree == null or cm.tree.node_id != node0, "se puede seguir con un botón")
	await t.frames(2)
	t.check(not k.call_panel.fallback or cm.tree == null, "el siguiente turno vuelve al micrófono")
	# sin motor: no disponible → respuestas rápidas
	IASpeech.forced_engine = "vosk"
	OS.set_environment("AVAIL_ASR_DIR", "/nonexistent")
	var saved_dir := IASpeech.asr_dir()
	IASpeech.engine = ""
	if saved_dir == "":
		IASpeech.ensure()
		await t.frames(3)
		t.check(IASpeech.state == "unavailable", "sin motor: «no disponible» (%s)" % IASpeech.reason)
		t.check(k.call_panel.fallback, "y respuestas rápidas")
	else:
		t.note("el motor está en %s: la rama «sin motor» se prueba con el mock" % saved_dir)
		IASpeech._set_state("unavailable", "no_engine")
		await t.frames(3)
		t.check(k.call_panel.fallback or cm.tree == null, "«no disponible» → respuestas rápidas")
	OS.set_environment("AVAIL_ASR_DIR", "")
	IASpeech.forced_engine = ""
	Loc.set_setting("ia_llamadas", "predefinidas")
	IASpeech.refresh()


func _dificil(t: Node) -> void:
	await t.start_shift("Ttoom", 1, 0, Difficulty.Level.DIFICIL)
	await t.login_at_seat()
	t.check(not ContactManager.presets_allowed(), "Difícil: sin respuestas predefinidas")
	var cm := _cm(t)
	var c := find_contact("t1c1")
	inject(cm, c)
	await t.seconds(0.6)
	var k := _kardex(t)
	k._sig = ""
	await t.frames(3)
	t.check(k._opts.get_child_count() == 0, "llamada en Difícil: ningún botón de opción (%d)" % k._opts.get_child_count())
	var node0 := cm.tree.node_id
	Input.action_press("phrase_1")
	await t.frames(2)
	Input.action_release("phrase_1")
	await t.frames(2)
	t.check(cm.tree != null and cm.tree.node_id == node0, "la tecla 1 no elige nada en Difícil")
	var r := await _resolve_by_text(t, cm, c, "voz_escrita", 77)
	t.check(str(r["outcome"]) in ["satisfecho", "neutral"], "Difícil: llamada resuelta escribiendo (%d/%d encajaron, %s)" % [r["matched"], r["total"], r["outcome"]])
	var ch := first_tree("chat", 1)
	inject(cm, ch)
	await t.seconds(4.0)
	t.note("chat: visible %s · rápidas %s (%d) · nota %s · fase %d · %s" % [k.chat.visible, k.chat._quick.visible, k.chat._quick.get_child_count(), k.chat._note.visible, cm.phase, str(cm.current.get("id", ""))])
	t.check(k.chat.visible and not k.chat.quick_visible(), "chat en Difícil: sin fila de respuestas rápidas")
	t.check(k.chat._note.visible, "aviso «Difícil: escribe o habla»")
	cm.phase = ContactManager.Phase.IDLE
	cm.tree = null
	cm.current = {}


## Medición del perdón: en cada paso del mejor camino de los 53 árboles, (a) la frase de la opción reescrita a mano
## (palabras de menos, minúsculas, una falta) y (b) una frase genérica del mismo tipo (empatía, proceso, cierre).
func _justo(t: Node) -> void:
	await t.frames(1)
	var d: Dictionary = IACustomer.data()
	var gen: Dictionary = d.get("parafraseo", {})
	var steps := 0
	var exact := 0
	var g_steps := 0
	var g_same := 0
	var g_good := 0
	var resolved := 0
	var trees := all_trees()
	for c in trees:
		IACustomer.prepare(c)
		var path := DialogTree.best_path(c)
		var dt := DialogTree.new()
		dt.start(c)
		var ok_all := true
		for s in path:
			if dt.ended():
				break
			var o: Dictionary = dt.options()[int(s["i"])]
			var tipo := str(o.get("tipo", ""))
			var m := IACustomer.match_option(dt, paraphrase(str(o.get("es", "")), steps * 7 + 3))
			steps += 1
			if int(m["i"]) == int(s["i"]):
				exact += 1
			else:
				ok_all = false
			if gen.has(tipo):
				var phr: Array = gen[tipo]
				var mg := IACustomer.match_option(dt, str(phr[steps % phr.size()]))
				g_steps += 1
				if int(mg["i"]) >= 0:
					var og: Dictionary = dt.options()[int(mg["i"])]
					if str(og.get("tipo", "")) == tipo:
						g_same += 1
					if not str(og.get("tipo", "")) in ["trampa", "fuera"]:
						g_good += 1
			dt.choose(int(s["i"]))
			if dt.waiting_action():
				dt.action_done(str(s.get("r", "ok")))
		if ok_all:
			resolved += 1
	var pe := 100.0 * float(exact) / maxf(1.0, float(steps))
	var ps := 100.0 * float(g_same) / maxf(1.0, float(g_steps))
	var pg := 100.0 * float(g_good) / maxf(1.0, float(g_steps))
	t.note("%d árboles · %d pasos · paráfrasis → opción correcta %.1f %% · árboles enteros %d/%d · frase genérica → mismo tipo %.1f %%, a una opción buena %.1f %%" % [trees.size(), steps, pe, resolved, trees.size(), ps, pg])
	t.check(pe >= 85.0, "paráfrasis con faltas → opción correcta: %.1f %%" % pe)
	t.check(float(resolved) / maxf(1.0, float(trees.size())) >= 0.75, "árboles resueltos enteros escribiendo: %d/%d" % [resolved, trees.size()])
	t.check(pg >= 70.0, "frase genérica razonable → opción buena (no trampa): %.1f %%" % pg)


func _comodin(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	await t.login_at_seat()
	IABrain.forget_all()
	var hub := _hub(t)
	IABrain.presence_override = {"ttoom": "activo", "juan": "activo"}  # el comodín también mira el estado de Ezlaki
	var r := IABrain.coworker_comodin("Ttoom")
	t.check(bool(r["answers"]) and str(r["line"]) != "" and str(r["dm"]) != "", "Ttoom contesta el comodín: «%s»" % str(r["line"]))
	t.check(int(IABrain.state("ttoom").get("debe", 0)) == 1, "le debes un favor a Ttoom")
	await t.seconds(4.0)
	var ms := hub.messages("dm:ttoom")
	t.check(not ms.is_empty() and str((ms.back() as Dictionary).get("autor", "")) == "ttoom", "DM de después: «%s»" % (str((ms.back() as Dictionary).get("texto", "")) if not ms.is_empty() else ""))
	var rr := IABrain.reply("ttoom", "dm:ttoom", "ttoom me cubres otra vez porfa?", {"sin_efectos": true})
	var txt := " ".join((rr["mensajes"] as Array).map(func(m: Dictionary) -> String: return str(m["texto"])))
	t.check(txt.contains("debes") or txt.contains("owe") or txt.contains("marco") or txt.contains("set"), "lo recuerda al pedirle otro favor: «%s»" % txt)
	for i in 3:
		IABrain.reply("juan", "dm:juan", "juan eres un idiota inútil", {"sin_efectos": true})
	t.check(not IABrain.can_coworker_answer("Juan"), "Juan, después de insultarlo, no contesta")
	var rj := IABrain.coworker_comodin("Juan", false)
	t.check(str(rj["reason"]) in ["rencor", "molesto"] and str(rj["line"]) != "", "y lo dice: «%s» (%s)" % [str(rj["line"]), str(rj["reason"])])
	IABrain.presence_override.clear()


static func _emoji_total(m: Dictionary) -> int:
	var n := 0
	for e in m.get("emojis", []):
		n += int(e[1])
	return n


func _post_aviso(t: Node, hub: EzlakHub) -> Dictionary:
	EventBus.ezlak_post.emit("#team-familia", "shero", "@here Team, las siguientes personas pasan a coaching 7:30 y nos vemos en Rooms: @Keyla @Brando @%s\n%s" % [GameState.agent, TranslationServer.translate("IA_REACT_ASK")], {"tipo": "programado", "pide_reaccion": true, "mention": true})
	await t.frames(2)
	return hub.message_by_id(int(hub.reaction_pending.get("id", -1)))  # (no «el último»: puede colarse otro mensaje)


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _reaccion(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	IABrain.forget_all()
	var hub := _hub(t)
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	var app := ws.get("ezlak") as PcEzlak
	# 1) acuse con ✅, con el teclado (la Workstation reenvía [Enter] ← → [Enter] a la app del SubViewport)
	var m: Dictionary = await _post_aviso(t, hub)
	t.check(not hub.reaction_pending.is_empty() and int(hub.reaction_pending["id"]) == int(m["id"]), "el aviso queda esperando tu reacción")
	var win := hub.reaction_window_s()
	t.check(win >= 30.0 and win <= 70.0 and hub.reaction_clock_runs(), "ventana en segundos reales (%.0f s) y corre sentado en tu PC" % win)
	await t.until(func() -> bool: return _emoji_total(m) >= 3, 30.0)
	t.check(_emoji_total(m) >= 3, "los compañeros reaccionan con emojis y contador (%d)" % _emoji_total(m))
	var banner := app.find_child("AvisoReaccion", true, false) as Button
	await t.frames(2)
	t.check(banner != null and banner.visible and banner.text.contains("#team-familia"), "aviso fijo en la app: «%s»" % (banner.text if banner != null else ""))
	app.open_channel("dm:shero")
	ws.call("set_zoom", true)
	await t.frames(3)
	ws.call("_unhandled_input", _key(KEY_ENTER))
	await t.frames(2)
	t.check(app.picker_id == int(m["id"]) and app.current == "#team-familia", "[Enter] abre el selector en el aviso pendiente (y te lleva a su canal)")
	var sel0 := app.picker_sel
	ws.call("_unhandled_input", _key(KEY_RIGHT))
	ws.call("_unhandled_input", _key(KEY_LEFT))
	t.check(app.picker_sel == sel0 and EzlakHub.reaction_choices()[sel0] == "✅", "← → mueven la selección (empieza en ✅)")
	var o0 := int(IABrain.meters().get("obe", 0))
	ws.call("_unhandled_input", _key(KEY_ENTER))
	await t.frames(2)
	t.check(str(hub.last_reaction.get("resultado", "")) == "acuse" and str(m.get("mi_emoji", "")) == "✅" and hub.reaction_pending.is_empty(), "[Enter] reacciona con ✅ = estoy al tanto")
	t.check(int(IABrain.meters().get("obe", 0)) == o0 + 1, "y suma Obediencia")
	t.check(hub.player_react(m, "👍") == "ya", "no se reacciona dos veces")
	await t.frames(2)
	t.check(not banner.visible, "el aviso fijo se va al reaccionar")
	ws.call("set_zoom", false)
	# con clic: «+ reaccionar» y el emoji
	var mc: Dictionary = await _post_aviso(t, hub)
	app.call("_on_meta", "pick:%d" % int(mc["id"]))
	app.call("_on_meta", "emo:%d:%d" % [int(mc["id"]), EzlakHub.reaction_choices().find("👀")])
	t.check(str(mc.get("mi_emoji", "")) == "👀" and str(hub.last_reaction.get("resultado", "")) == "acuse", "con clic: + reaccionar → 👀 = acuse")
	# 2) emoji burlón = falta de respeto
	var a0 := Metrics.alerts
	var w0 := Metrics.written_warnings
	var m2: Dictionary = await _post_aviso(t, hub)
	t.check(hub.player_react(m2, "🤡") == "falta", "🤡 al aviso de Shero = falta de respeto")
	await t.seconds(4.0)
	t.check(Metrics.alerts > a0 or Metrics.written_warnings > w0, "cuenta como falta (alerta %d→%d, WW %d→%d)" % [a0, Metrics.alerts, w0, Metrics.written_warnings])
	var sh: Dictionary = hub.messages("dm:shero").back()
	t.note("Shero: " + str(sh.get("texto", "")))
	t.check(str(sh.get("autor", "")) == "shero", "Shero te contesta por DM")
	await t.seconds(2.0)
	if Metrics.ack_pending:
		Metrics.give_ack()
	# 3) sin reacción: la cuenta atrás no corre lejos de la PC (ni en la calma); sentado, vence
	var m3: Dictionary = await _post_aviso(t, hub)
	GameState.in_calm = true
	var q0 := hub.reaction_left()
	await t.seconds(3.0)
	t.check(not hub.reaction_clock_runs() and absf(hub.reaction_left() - q0) < 0.01, "en la calma (o lejos de tu PC) la cuenta atrás no corre")
	hub.reaction_pending["quedan"] = 2.0
	GameState.in_calm = false
	await t.frames(3)
	t.check(hub.reaction_left() >= 9.0, "al volver te queda al menos el mínimo (%.0f s)" % hub.reaction_left())
	var n0 := hub.messages("dm:shero").size()
	var a1 := Metrics.alerts + Metrics.written_warnings
	await t.until(func() -> bool: return int(hub.reaction_pending.get("etapa", 0)) >= 1, win + 20.0)
	await t.frames(3)
	var recordo := false
	var ms := hub.messages("dm:shero")
	for i in range(n0, ms.size()):
		if str(ms[i].get("tipo", "")) == "ia_sin_reaccion" and str(ms[i].get("texto", "")).contains(Loc.pick({"es": "No viste", "en": "see the message"})):
			recordo = true
	t.check(recordo, "sin reacción: Shero escribe «¿No viste el mensaje?»")
	t.check(Metrics.alerts + Metrics.written_warnings > a1, "y escala (alerta/WW)")
	if Metrics.ack_pending:
		Metrics.give_ack()
	var w1 := Metrics.written_warnings
	await t.until(func() -> bool: return hub.reaction_pending.is_empty(), win + 20.0)
	await t.frames(3)
	t.check(Metrics.written_warnings > w1, "segunda ventana sin reacción: WW (%d→%d)" % [w1, Metrics.written_warnings])
	t.check(hub.reaction_pending.is_empty() and str(m3.get("mi_emoji", "")) == "", "el aviso deja de esperar")
	if Metrics.ack_pending:
		Metrics.give_ack()


# --- estados de Ezlaki -------------------------------------------------------------------------------------

func _estados(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	IABrain.forget_all()
	var hub := _hub(t)
	var cm := _cm(t)
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	var app := ws.get("ezlak") as PcEzlak
	var acd: ColaACD = cm.acd
	# 1) el estado sale de la cola: en un contacto = en llamada; su lunch = en lunch; break/dormido = ausente
	acd.npc_busy_until["Jiroshi"] = GameState.clock_seconds + 900.0
	t.check(IABrain.presence_state("jiroshi") == "llamada" and str(IABrain.presence("jiroshi")["texto"]) == TranslationServer.translate("IA_PRES_LLAMADA"), "Jiroshi atiende un contacto → «%s»" % str(IABrain.presence("jiroshi")["texto"]))
	t.check(not IABrain.can_coworker_answer("Jiroshi") and not Comodin.can_coworker_answer("Jiroshi"), "en llamada no contesta el comodín (IABrain y Comodin dicen lo mismo)")
	var rj := IABrain.coworker_comodin("Jiroshi", false)
	t.check(str(rj["reason"]) == "presencia" and str(rj["dm"]).contains(TranslationServer.translate("IA_PRES_LLAMADA")), "y después te escribe: «%s»" % str(rj["dm"]))
	acd.npc_busy_until.erase("Jiroshi")
	var real_clock := GameState.clock_seconds
	var seen := {}
	var mapa: Dictionary = (IABrain.cfg().get("presencia", {}) as Dictionary).get("acd", {})
	var coherente := true
	for b in acd._sched.get("Jiroshi", []):
		GameState.clock_seconds = float(b[0]) + 30.0
		var aux := acd.npc_state("Jiroshi")  # si dos bloques se pisan manda el de más prioridad (lunch sobre coaching)
		seen[aux] = IABrain.presence_state("jiroshi")
		coherente = coherente and str(seen[aux]) == str(mapa.get(aux, "?"))
	GameState.clock_seconds = real_clock
	t.check(coherente and str(seen.get("lunch", "")) == "lunch" and str(seen.get("break", "")) == "ausente" and str(mapa.get("coaching", "")) == "llamada" and str(mapa.get("dormido", "")) == "ausente", "su horario de AUX manda: %s" % str(seen))
	t.check(seen.values().all(func(v: Variant) -> bool: return IABrain.PRESENCE.has(str(v))), "solo los 5 estados (activo, llamada, lunch, pausa, ausente)")
	# 2) la barra lateral lo muestra (punto + texto) y cambia sola
	IABrain.presence_override = {"jiroshi": "llamada", "ttoom": "activo"}
	await t.seconds(1.2)
	var shown := app.presence_shown()
	t.check(str(shown.get("dm:jiroshi", "")) == "llamada" and str(shown.get("dm:ttoom", "")) == "activo" and shown.has("dm:shero"), "barra lateral: %s" % str(shown))
	var bj := (app.get("_side_buttons") as Dictionary).get("dm:jiroshi") as Button
	var lbl := bj.get_node_or_null("Estado") as Label if bj != null else null
	t.check(bj != null and bj.icon != null and lbl != null and lbl.text == TranslationServer.translate("IA_PRES_LLAMADA"), "fila de @Jiroshi: punto de color y «%s»" % (lbl.text if lbl != null else ""))
	IABrain.presence_override["jiroshi"] = "lunch"
	await t.seconds(1.2)
	t.check(str(app.presence_shown().get("dm:jiroshi", "")) == "lunch", "cambia sola cuando cambia el juego (→ en lunch)")
	app.open_channel("dm:jiroshi")
	await t.seconds(0.8)
	await t.until(func() -> bool: return app.toast_left <= 0.0, 8.0)  # si justo llegó un aviso breve, que pase
	t.check(str((app.get("_topic") as Label).text).contains(TranslationServer.translate("IA_PRES_LUNCH")), "cabecera del DM: «%s»" % str((app.get("_topic") as Label).text))
	# 3) el comodín de verdad: el que está en llamada no contesta; el activo sí
	IABrain.presence_override = {"jiroshi": "llamada", "ttoom": "activo", "llauri": "activo", "juan": "ausente"}
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	var names := Comodin.coworkers()
	var failed: Array = []
	var on_fail := func(w: String, _r: String) -> void: failed.append(w)
	Comodin.call_failed.connect(on_fail)
	t.check(Comodin.open(), "lejos de tu PC abres el comodín")
	Comodin.choose_aux(Metrics.Aux.BO)
	Comodin.choose_coworker(names.find("Jiroshi"))
	await t.until(func() -> bool: return Comodin.phase == "retry", 30.0)
	t.check(Comodin.phase == "retry" and failed.has("Jiroshi") and Metrics.aux != Metrics.Aux.BO, "llamas a Jiroshi (en llamada): no contesta, el AUX no cambia")
	Comodin.choose_coworker(names.find("Ttoom"))
	await t.until(func() -> bool: return Comodin.phase == "", 30.0)
	t.check(Metrics.aux == Metrics.Aux.BO, "llamas a Ttoom (activo): contesta y te marca BO")
	Comodin.call_failed.disconnect(on_fail)
	await t.seconds(4.0)
	var dms := 0
	for mm in hub.messages("dm:ttoom"):
		if str(mm.get("tipo", "")) in ["ia_comodin", "comodin"]:
			dms += 1
	t.check(dms == 1, "un solo DM de Ttoom después (el del cerebro, sin repetir): %d" % dms)
	# 4) Shero: activo = lee el canal; en llamada (reunión/coaching) = no lo lee ahora
	IABrain.presence_override.erase("shero")
	t.check(IABrain.presence_state("shero") == "activo", "Shero «activo» (está leyendo / dando vueltas)")
	GameState.in_calm = true
	t.check(IABrain.presence_state("shero") == "llamada", "en la calma («está en reunión») → «en llamada»")
	var al0 := Metrics.alerts + Metrics.written_warnings
	hub.typed_reply("#team-familia", "shero eres un inutil")
	t.check(str(hub.last_typed_reply.get("autor", "")) != "shero" and bool(hub.last_brain.get("shero_no_lee", false)), "le sueltas algo en el canal con Shero en llamada: no lo lee (te avisa %s)" % str(hub.last_typed_reply.get("autor", "")))
	await t.seconds(4.0)
	t.check(Metrics.alerts + Metrics.written_warnings == al0, "y no hay falta")
	var av: Dictionary = hub.messages("#team-familia").back()
	t.note("compañero: " + str(av.get("texto", "")))
	GameState.in_calm = false
	hub.typed_reply("#team-familia", "shero eres un inutil")
	t.check(str(hub.last_typed_reply.get("autor", "")) == "shero", "con Shero «activo» sí lo lee (y contesta él)")
	await t.seconds(4.0)
	t.check(Metrics.alerts + Metrics.written_warnings > al0, "y cuenta como falta")
	if Metrics.ack_pending:
		Metrics.give_ack()
	# 5) el Trainer: siempre «pausó sus notificaciones»… y contesta al instante
	var tp: Dictionary = IABrain.presence("trainer")
	t.check(str(tp["estado"]) == "pausa" and str(tp["texto"]) == TranslationServer.translate("IA_PRES_PAUSA"), "Trainer: «%s»" % str(tp["texto"]))
	for h in [0.5, 3.0, 5.6, 8.2]:
		GameState.clock_seconds = h * 3600.0
		if IABrain.presence_state("trainer") != "pausa":
			t.fail("el Trainer no está en pausa a las %.1f h" % h)
	GameState.clock_seconds = real_clock
	var n0 := hub.messages("dm:trainer").size()
	hub.typed_reply("dm:trainer", "hola trainer, como estas?")
	var espera := 99.0
	if not (hub.last_brain.get("mensajes", []) as Array).is_empty():
		espera = float(hub.last_brain["mensajes"][0]["espera"])
	await t.seconds(1.0)
	var tm := hub.messages("dm:trainer")
	t.check(espera <= 0.8 and tm.size() >= n0 + 2 and str(tm.back().get("autor", "")) == "trainer", "contesta al instante (%.2f s): «%s»" % [espera, str(tm.back().get("texto", ""))])
	t.check(IABrain.presence_state("trainer") == "pausa", "y sigue en «pausó sus notificaciones»")
	app.open_channel("dm:trainer")
	await t.seconds(0.8)
	await t.until(func() -> bool: return app.toast_left <= 0.0, 8.0)
	t.check(str((app.get("_topic") as Label).text).contains(TranslationServer.translate("IA_PRES_PAUSA")) and str(app.presence_shown().get("dm:trainer", "")) == "pausa", "su DM lo dice arriba: «%s»" % str((app.get("_topic") as Label).text))
	t.check(IABrain.presence_state("om") == "ausente" and IABrain.presence_state("vitzo") == "activo", "OM ausente de madrugada; Vitzo siempre activo")
	IABrain.presence_override.clear()


# --- pared de reacciones ------------------------------------------------------------------------------------

func _pared(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	IABrain.forget_all()
	var hub := _hub(t)
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	var app := ws.get("ezlak") as PcEzlak
	IABrain.presence_override = {"marko": "activo", "llauri": "llamada", "juan": "activo", "ttoom": "lunch"}
	var alone: Array = []
	var on_alone := func(mm: Dictionary) -> void: alone.append(int(mm.get("id", 0)))
	hub.reaction_alone.connect(on_alone)
	var m: Dictionary = await _post_aviso(t, hub)
	var st := hub.wall_status(m)
	t.check(int(st["total"]) == 12 and int(st["hechos"]) == 0 and not bool(st["solo_tu"]), "el team son 12 (4 agentes + 7 del site + tú); al publicar nadie reaccionó")
	# uno por uno: el contador sube de a uno
	var steps: Array = []
	var last := 0
	var win := hub.reaction_window_s()
	while not bool(hub.wall_status(m)["solo_tu"]) and steps.size() < 400:
		await t.frames(1)
		var h := int(hub.wall_status(m)["hechos"])
		if h != last:
			steps.append(h - last)
			last = h
		if hub.reaction_pending.is_empty():
			break
	st = hub.wall_status(m)
	t.check(steps.size() == 10 and steps.all(func(d: Variant) -> bool: return int(d) == 1), "reaccionan uno por uno y el contador sube (%s)" % str(steps))
	t.check(bool(st["solo_tu"]) and int(st["hechos"]) == 10 and (st["faltan"] as Array).is_empty(), "todos los que están en línea reaccionaron: SOLO FALTAS TÚ (%d de %d)" % [int(st["hechos"]), int(st["total"])])
	t.check((st["fuera"] as Array).size() == 1 and str(st["fuera"][0][0]) == "Ttoom" and str(st["fuera"][0][1]) == TranslationServer.translate("IA_PRES_LUNCH"), "Ttoom está en lunch: no reacciona y la app lo dice (%s)" % str(st["fuera"]))
	t.check(float(st["quedan"]) >= win * 0.25 and bool(st["pendiente"]), "queda tiempo antes de que venza la ventana (%.0f de %.0f s)" % [float(st["quedan"]), win])
	t.check(alone == [int(m["id"])], "el aviso de «solo faltas tú» sale una vez")
	for e in m.get("emojis", []):
		if not EzlakHub.REACT_OK.has(str(e[0])):
			t.fail("emoji no estándar en la pared: %s" % str(e[0]))
	# la app: contador, «SOLO FALTAS TÚ», cuenta atrás, aviso fijo y la lista desplegable
	app.open_channel("#team-familia")
	await t.frames(3)
	var txt := app.visible_text()
	t.check((app.find_child("AvisoFijado", true, false) as Control).visible and txt.contains(TranslationServer.translate("IA_PIN_TITLE")), "el aviso queda fijado arriba del chat (los mensajes nuevos no se lo llevan)")
	t.check(txt.contains(Loc.fmt(TranslationServer.translate("IA_WALL_COUNT"), {"n": 10, "total": 12})) and txt.contains(TranslationServer.translate("IA_WALL_ONLY_YOU")), "en el chat: «Reaccionaron 10 de 12 · SOLO FALTAS TÚ»")
	var banner := app.find_child("AvisoReaccion", true, false) as Button
	t.check(banner.visible and banner.text.contains(Loc.fmt(TranslationServer.translate("IA_REACT_BANNER_ALONE"), {"canal": "#team-familia", "t": "@"}).get_slice(" ", 0)), "aviso fijo: «%s»" % banner.text)
	t.check(not txt.contains("Keyla, ") and not txt.contains(", Marko"), "la lista de quién reaccionó está plegada")
	app.call("_on_meta", "who:%d" % int(m["id"]))
	await t.frames(3)
	txt = app.visible_text()
	t.check(txt.contains("Marko") and txt.contains("Llauri (%s)" % TranslationServer.translate("IA_PRES_LLAMADA")) and txt.contains("Ttoom (%s)" % TranslationServer.translate("IA_PRES_LUNCH")), "desplegada: quién puso qué, con su estado (Llauri en llamada, Ttoom en lunch)")
	t.check(txt.contains(Loc.fmt(TranslationServer.translate("IA_WALL_MISSING_LIST"), {"quienes": TranslationServer.translate("IA_WALL_YOU")})), "«Faltan: Tú»")
	t.check(hub.player_react(m, "✅") == "acuse", "reaccionas con ✅ a tiempo")
	await t.frames(3)
	st = hub.wall_status(m)
	t.check(bool(st["yo"]) and int(st["hechos"]) == 11 and not banner.visible, "11 de 12, tú incluido; el aviso fijo se va")
	t.check(app.visible_text().contains(TranslationServer.translate("IA_WALL_YOU_DONE")), "«tú ya reaccionaste»")
	hub.reaction_alone.disconnect(on_alone)
	IABrain.presence_override.clear()
	await t.back_to_menu()
	# Miércoles (turno 3): en el aviso de coaching de las 07:00 reacciona uno que a esa hora ya no está en la sala
	await t.start_shift("Jiroshi", 3)
	await t.login_at_seat()
	GameState.stop_calm()
	hub = _hub(t)
	app = (t.main.get_node_or_null("UI/Workstation") as Node).get("ezlak") as PcEzlak
	await t.set_clock(GameState.hhmm_to_seconds("06:30"))
	t.check(IABrain.off_floor_t3() == "" and IABrain.off_floor_t3(true) == "juan", "06:30: Juan todavía está (el miércoles se va a las 06:45)")
	var deaths: Array = t.spy("death_requested")
	await t.set_clock(GameState.hhmm_to_seconds("07:00") + 5.0)
	GameState.stop_calm()
	await t.until(func() -> bool: return not hub.reaction_pending.is_empty(), 20.0)
	t.check(not hub.reaction_pending.is_empty(), "07:00: Shero publica el aviso de coaching y pide reacción")
	var mw := hub.message_by_id(int(hub.reaction_pending.get("id", -1)))
	var subs: Array = t.spy("subtitle")
	var posts: Array = t.spy("ezlak_post")
	t.check(str(mw.get("autor", "")) == "shero" and str(mw.get("texto", "")).contains(TranslationServer.translate("IA_REACT_ASK")), "«…%s»" % TranslationServer.translate("IA_REACT_ASK"))
	t.check(IABrain.presence_state("juan") == "ausente" and not IABrain.can_coworker_answer("Juan"), "Juan ya no está en la sala: «ausente» (y no contesta el comodín)")
	await t.until(func() -> bool: return hub.reactors(mw).has("Juan") or hub.reaction_pending.is_empty(), 60.0)
	t.check(hub.reactors(mw).has("Juan") and str((mw["pared"] as Dictionary).get("raro", "")) == "Juan", "…y su reacción está en el aviso")
	app.open_channel("#team-familia")
	app.call("_on_meta", "who:%d" % int(mw["id"]))
	await t.frames(3)
	var tw := app.visible_text()
	t.check(tw.contains("Juan (%s)" % TranslationServer.translate("IA_PRES_AUSENTE")), "solo se ve si despliegas la lista: «Juan (ausente)»")
	var loud := ""
	for sb in subs:
		if str(sb[0]) == "juan":
			loud = str(sb[1])
	for pp in posts:
		if str(pp[1]) == "juan":  # (el RTA sí puede preguntar por él: «@Juan … ¿Respira? Confirmar.»)
			loud = str(pp[2])
	t.check(deaths.is_empty() and loud == "" and not Checkpoints.dying, "sin susto, sin aviso ni sonido propio, sin muerte: solo está ahí %s" % loud)
	hub.player_react(mw, "👍")
	await t.back_to_menu()
	await t.start_shift("Juan", 3)
	t.check(IABrain.off_floor_t3(true) == "marko", "si tú eres Juan, el que falta es Marko")
	await t.start_shift("Jiroshi", 1)
	t.check(IABrain.off_floor_t3(true) == "", "lunes y martes no pasa")

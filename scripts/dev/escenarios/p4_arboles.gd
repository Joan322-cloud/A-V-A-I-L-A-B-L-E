## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P4 · árboles de diálogo (PLAN §5): cada camino de cada árbol llega a su final y emite el
## resultado correcto (contact_outcome + Metrics.register_outcome), reloj 6x durante el árbol, t_juego sumado;
## WMM (t2c9 llamada, t3c9 chat): las trampas de correo matan con su causa y los caminos por el portal resuelven.


func escenarios() -> Array[String]:
	return ["arbol:", "arboles_todos", "arbol_reglas", "wmm"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"arbol": await _arbol(t, arg, 600)
		"arboles_todos":
			for tn in [1, 2, 3]:
				for c in DataLoader.dict("contactos_t%d" % tn).get("contactos", []):
					await _arbol(t, str(c.get("id", "")), 600)
		"arbol_reglas": await _reglas(t)
		"wmm": await _wmm(t)


static func find_contact(cid: String) -> Dictionary:
	for tn in [1, 2, 3]:
		for c in DataLoader.dict("contactos_t%d" % tn).get("contactos", []):
			if str(c.get("id", "")) == cid:
				return (c as Dictionary).duplicate(true)
	return {}


static func turno_of(cid: String) -> int:
	return clampi(int(cid.substr(1, 1)), 1, 3) if cid.begins_with("t") else 1


func _cm(t: Node) -> ContactManager:
	return t.main.get("contacts") as ContactManager


## Pone el contacto en la PC y lo acepta (como si sonara y el jugador pulsara Espacio).
static func inject(cm: ContactManager, c: Dictionary) -> void:
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c.duplicate(true))
	cm.accept()


func _arbol(t: Node, cid: String, max_paths: int) -> void:
	var c := find_contact(cid)
	if not t.check(not c.is_empty(), "existe el árbol %s" % cid):
		return
	await t.start_shift("Jiroshi", turno_of(cid))
	await t.login_at_seat()
	var cm := _cm(t)
	var outcomes: Array = t.spy("contact_outcome")
	var nodes_seen: Array = t.spy("dialog_node")
	var pod := bool((c.get("portal", {}) as Dictionary).get("pod", true))
	var paths := DialogTree.enumerate_paths(c, max_paths)
	t.check(paths.size() > 0, "%s: hay caminos (%d)" % [cid, paths.size()])
	var finals_hit: Dictionary = {}
	var n := 0
	for p in paths:
		var real_ok := true
		for s in p:
			if str(s.get("r", "")) == ("pod_no" if pod else "pod_ok"):
				real_ok = false
		if not real_ok:
			continue
		var sim := DialogTree.simulate(c, p)
		Metrics.reset_shift()
		outcomes.clear()
		inject(cm, c)
		var clock0 := GameState.clock_seconds
		var tj := 0.0
		for s in p:
			if cm.tree == null:
				break
			var o: Dictionary = cm.tree.options()[int(s["i"])]
			tj += float(o.get("t_juego", 0.0))
			cm.choose(int(s["i"]))
			if cm.tree != null and cm.tree.waiting_action():
				var r := str(s.get("r", "ok"))
				var tx := str((c.get("portal", {}) as Dictionary).get("tx", ""))
				if r == "cancel":
					cm.composer_cancel()
				elif cm.tree.pending_action() == "portal_pod":
					cm.portal_search(tx)
				elif cm.tree.pending_action() == "portal_contacto":
					cm.portal_search(tx)
					if cm.tree != null and cm.tree.pending_action() == "portal_contacto":
						cm.portal_contact()
		n += 1
		var want := str(sim.get("resultado", ""))
		var got: String = str(outcomes[0][1]) if outcomes.size() == 1 else "?"
		t.check(cm.phase == ContactManager.Phase.IDLE and outcomes.size() == 1, "%s %s: termina con un solo contact_outcome (hay %d)" % [cid, _p(p), outcomes.size()])
		t.check(got == want, "%s %s: resultado %s (esperado %s)" % [cid, _p(p), got, want])
		t.check(int(Metrics.outcomes.get(want, 0)) == 1, "%s %s: Metrics.register_outcome(%s)" % [cid, _p(p), want])
		t.check(GameState.clock_seconds - clock0 >= tj - 0.5, "%s %s: el t_juego de las opciones se suma al reloj (%.0f ≥ %.0f)" % [cid, _p(p), GameState.clock_seconds - clock0, tj])
		finals_hit[str(sim.get("final", ""))] = true
	for f in (c.get("finales", {}) as Dictionary).keys():
		if str(f) == str((c.get("timeout", {}) as Dictionary).get("fin", "")):
			continue
		t.check(finals_hit.has(f), "%s: algún camino llega a %s" % [cid, f])
	t.check(nodes_seen.size() >= n, "%s: dialog_node emitido (%d)" % [cid, nodes_seen.size()])
	t.note("%s: %d caminos recorridos, finales %s" % [cid, n, str(finals_hit.keys())])


func _p(p: Array) -> String:
	var s: Array[String] = []
	for x in p:
		s.append("%d%s" % [int(x["i"]) + 1, "" if str(x.get("r", "ok")) == "ok" else ":" + str(x["r"])])
	return "[" + ",".join(PackedStringArray(s)) + "]"


## Reglas del motor: reloj 6x, cuelga bajo −50, levantarse sin hold = molesto, timeout del chat, neutral no
## rompe la racha, marcas de QA en el contacto.
func _reglas(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var cm := _cm(t)
	var c := find_contact("t1c1")
	inject(cm, c)
	t.check(is_equal_approx(GameState.clock_speed(), 6.0), "llamada con árbol: reloj 6x (hay %.1f)" % GameState.clock_speed())
	# Colgar por ánimo: animo_inicial −60 → la primera opción negativa cuelga.
	var c2 := c.duplicate(true)
	c2["animo_inicial"] = -45
	var tr2 := DialogTree.new()
	tr2.start(c2)
	var worst := 0
	for i in tr2.options().size():
		if float(tr2.options()[i].get("animo", 0)) < float(tr2.options()[worst].get("animo", 0)):
			worst = i
	tr2.choose(worst)
	t.check(tr2.ended() and tr2.outcome() == "molesto" and tr2.hung_up, "ánimo < −50 → el cliente cuelga (final molesto)")
	# Levantarse sin hold = molesto.
	var outcomes: Array = t.spy("contact_outcome")
	t.player().stand_up()
	await t.frames(2)
	t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "molesto", "pararse sin hold → final molesto")
	await t.login_at_seat()
	# Chat: timeout del nodo.
	var chat := find_contact("t1c3")
	outcomes.clear()
	inject(cm, chat)
	await t.advance_clock(float((chat.get("timeout", {}) as Dictionary).get("s_juego", 40.0)) + 5.0)
	t.check(outcomes.size() == 1 and str(outcomes[0][0].get("_final", "")) == str((chat.get("timeout", {}) as Dictionary).get("fin", "")), "chat sin responder → %s" % str((chat.get("timeout", {}) as Dictionary).get("fin", "")))
	# Hold: con hold puedes pararte sin perder el contacto.
	outcomes.clear()
	inject(cm, c)
	cm.toggle_hold()
	t.player().stand_up()
	await t.frames(2)
	t.check(outcomes.is_empty() and cm.is_active(), "con hold te puedes parar (el contacto sigue)")
	await t.login_at_seat()
	cm.choose(0)
	t.check(not cm.on_hold, "volver a hablar saca del hold")
	# Neutral no rompe la racha; marca de QA en el contacto.
	Metrics.reset_shift()
	Metrics.angry_streak.append(GameState.clock_seconds)
	var ended: Array = t.spy("contact_ended")
	cm.phase = ContactManager.Phase.IDLE
	var p := _path_to(c, "neutral")
	inject(cm, c)
	for s in p:
		cm.choose(int(s["i"]))
	t.check(ended.size() >= 1 and bool((ended[ended.size() - 1][0] as Dictionary).get("_neutral", false)), "final neutral marcado _neutral")
	t.check(Metrics.angry_streak.size() == 1, "un final neutral no rompe la racha de molestos")
	var qa_path := _path_with_qa(c)
	if not qa_path.is_empty():
		cm.phase = ContactManager.Phase.IDLE
		inject(cm, c)
		for s in qa_path:
			if cm.tree != null:
				cm.choose(int(s["i"]))
		t.check(not (ended[ended.size() - 1][0].get("_qa", []) as Array).is_empty(), "la opción con 'qa' deja su marca en el contacto (_qa)")


func _path_to(c: Dictionary, result: String) -> Array:
	for p in DialogTree.enumerate_paths(c):
		var sim := DialogTree.simulate(c, p)
		if str(sim.get("resultado", "")) == result and not bool(sim.get("correo", false)):
			var simple := true
			for s in p:
				if str(s.get("r", "ok")) != "ok":
					simple = false
			if simple:
				return p
	return []


func _path_with_qa(c: Dictionary) -> Array:
	for p in DialogTree.enumerate_paths(c):
		var sim := DialogTree.simulate(c, p)
		if not (sim.get("qa", []) as Array).is_empty() and not bool(sim.get("correo", false)):
			return p
	return []


## WMM: cada trampa de correo mata con su causa; el portal resuelve (POD ok en t2c9, Contacto partner en t3c9);
## el aviso del portal (T3) también es una trampa.
func _wmm(t: Node) -> void:
	for cid in ["t2c9", "t3c9"]:
		var c := find_contact(cid)
		await t.start_shift("Jiroshi", turno_of(cid))
		await t.login_at_seat()
		GameState.running = false
		var cm := _cm(t)
		var tx := str((c.get("portal", {}) as Dictionary).get("tx", ""))
		# Camino correcto: el del bot listo.
		var best := DialogTree.best_path(c)
		var outcomes: Array = t.spy("contact_outcome")
		var deaths: Array = t.spy("death_requested")
		inject(cm, c)
		for s in best:
			if cm.tree == null:
				break
			cm.choose(int(s["i"]))
			if cm.tree != null and cm.tree.waiting_action():
				cm.portal_search(tx)
				if cm.tree != null and cm.tree.pending_action() == "portal_contacto":
					cm.portal_contact()
		t.check(outcomes.size() == 1 and str(outcomes[0][1]) == "satisfecho" and deaths.is_empty(), "%s: por el portal → satisfecho sin muerte (%s)" % [cid, str(outcomes)])
		# Trampas: cada opción con muerte_al_enviar, enviada.
		for nid in (c.get("nodos", {}) as Dictionary).keys():
			var opts: Array = (c["nodos"][nid] as Dictionary).get("opciones", [])
			for i in opts.size():
				var cause := str((opts[i] as Dictionary).get("muerte_al_enviar", ""))
				if cause == "":
					continue
				var route := _route_to(c, str(nid))
				if route.is_empty() and str(nid) != "inicio":
					t.note("%s: el nodo %s no es alcanzable con el portal de este contacto (se omite su trampa)" % [cid, nid])
					continue
				await t.start_shift("Jiroshi", turno_of(cid))
				await t.login_at_seat()
				cm = _cm(t)
				deaths.clear()
				inject(cm, c)
				for s in route:
					cm.choose(int(s["i"]))
					if cm.tree != null and cm.tree.waiting_action():
						cm.portal_search(tx)
				cm.choose(i)
				t.check(not cm.composer.is_empty() and str(cm.composer.get("to", "")) == "Vitzo", "%s.%s.%s: se abre el redactor dirigido a Vitzo" % [cid, nid, opts[i].get("id", "")])
				cm.composer_send()
				await t.frames(2)
				await t.until(func() -> bool: return not deaths.is_empty(), 5.0)  # v0.3.1 Q2: Vitzo sale del monitor antes de matarte
				t.check(deaths.size() >= 1 and str(deaths[0][0]) == cause, "%s.%s.%s: enviar → muerte %s (hay %s)" % [cid, nid, opts[i].get("id", ""), cause, str(deaths)])
				t.check(Checkpoints.killer_of(cause) == "vitzo" or Checkpoints.death_killer == "vitzo", "%s: el asesino es Vitzo" % cause)
				await t.wait_death_shown(8.0)
				await t.reconnect()
		# Aviso del portal (T3): el enlace ops@vitzo.kp abre el redactor y enviarlo mata.
		if cid == "t3c9":
			await t.start_shift("Jiroshi", 3)
			await t.login_at_seat()
			cm = _cm(t)
			deaths.clear()
			inject(cm, c)
			var route := _route_to(c, "num")
			for s in route:
				cm.choose(int(s["i"]))
			cm.choose(0)  # accion portal_pod
			cm.portal_search(tx)
			t.check(bool(cm.portal_view.get("banner", false)), "t3c9: el portal muestra el aviso de mantenimiento")
			cm.open_mailto_vitzo()
			t.check(str(cm.composer.get("to", "")) == "Vitzo", "t3c9: el aviso abre un correo a Vitzo")
			cm.composer_cancel()
			t.check(cm.composer.is_empty() and cm.is_active(), "t3c9: cancelar el correo del aviso no rompe la llamada")
			cm.open_mailto_vitzo()
			cm.composer_send()
			await t.frames(2)
			await t.until(func() -> bool: return not deaths.is_empty(), 5.0)  # v0.3.1 Q2: Vitzo sale del monitor antes de matarte
			t.check(deaths.size() >= 1 and str(deaths[0][0]) == "wmm_correo_vitzo", "t3c9: enviar el correo del aviso → muerte wmm_correo_vitzo")
			await t.wait_death_shown(8.0)
			await t.reconnect()


## Camino (lista de elecciones) desde el inicio hasta el nodo `target`, sin trampas de correo.
func _route_to(c: Dictionary, target: String) -> Array:
	if target == str(c.get("inicio", "inicio")):
		return []
	var pod := bool((c.get("portal", {}) as Dictionary).get("pod", true))
	for p in DialogTree.enumerate_paths(c):
		var tr_ := DialogTree.new()
		tr_.start(c)
		var prefix: Array = []
		for s in p:
			tr_.choose(int(s["i"]))
			prefix.append(s)
			if tr_.waiting_action():
				if str(s.get("r", "")) == "cancel":
					break
				tr_.action_done("pod_ok" if pod else "pod_no")
			if tr_.node_id == target and not tr_.ended():
				return prefix
	return []

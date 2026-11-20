## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de Q4 (v0.3.1): contenido. `--escenario pq4` los corre todos.
##   q4_arboles        45 árboles (15 por turno), todos los finales alcanzables por algún camino, satisfecho/neutral/molesto
##   q4_sorteo         contactos por turno × dificultad dentro del rango, fijos siempre, sin repetir
##   q4_sin_repetir    el relleno no se repite en el turno
##   q4_correo_pasos   barra de pasos, bloqueo «Busca la operación en Kardex», copiar desde Kardex, guía del 1.er correo
##   q4_correo_marcas  el correo mal hecho deja marcas por campo (para Haime); sin marcas rojas al enviar
##   q4_haime_tipos    cada tipo de caso solo da líneas de su tipo; correo sin «cliente/llamada»; 1 oportunidad por marca
##   q4_haime_voces    todas las líneas de Haime tienen voz ES y EN
##   q4_menu_flujo     intro → menú sin selección de agente → Jugar → agentes → Continuar; la intro se salta la 2.ª vez
##   q4_cinematicas    intro T1 (mundo), T2, T3 y salida: corren, el reloj espera, se saltan con Espacio mantenido
##   q4_taper          casillero → refri → lunch → microondas (60 s) → mesa: Fatiga −20 y energía; 6 microondas; se malogra
##   q4_rasec_decisiones  karaoke/charadas/sillas: 3-4 decisiones, cada rama (seguir/excusa/burla) llega a un fin
##   q4_rasec_ventana  la ventana de llegada de Rasec cuenta de pie (sentado, la mitad)

const PREFIX := "q4_"


func escenarios() -> Array[String]:
	return ["q4_arboles", "q4_sorteo", "q4_sin_repetir", "q4_correo_pasos", "q4_correo_marcas", "q4_haime_tipos", "q4_haime_voces", "q4_menu_flujo", "q4_cinematicas", "q4_taper", "q4_rasec_decisiones", "q4_rasec_ventana"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"q4_arboles": await _arboles(t)
		"q4_sorteo": await _sorteo(t)
		"q4_sin_repetir": await _sin_repetir(t)
		"q4_correo_pasos": await _correo_pasos(t)
		"q4_correo_marcas": await _correo_marcas(t)
		"q4_haime_tipos": await _haime_tipos(t)
		"q4_haime_voces": await _haime_voces(t)
		"q4_menu_flujo": await _menu(t)
		"q4_cinematicas": await _cinematicas(t)
		"q4_taper": await _taper(t)
		"q4_rasec_decisiones": await _rasec(t)
		"q4_rasec_ventana": await _ventana(t)


static func pool(turno: int) -> Array:
	var d := DataLoader.dict("contactos_t%d" % turno)
	var out: Array = []
	for c in d.get("contactos", []) + d.get("relleno", []):
		if (c as Dictionary).has("nodos"):
			out.append(c)
	return out


# --- F13 ---------------------------------------------------------------------------------------

func _arboles(t: Node) -> void:
	var total := 0
	var bad: Array[String] = []
	for tn in [1, 2, 3]:
		var p := pool(tn)
		total += p.size()
		t.check(p.size() >= 15 and p.size() <= 20, "T%d: %d árboles distintos (15-20)" % [tn, p.size()])
		for c in p:
			var cd := c as Dictionary
			var finals: Dictionary = cd.get("finales", {})
			var reached := {}
			var results := {}
			for path in DialogTree.enumerate_paths(cd, 3000):
				var sim := DialogTree.simulate(cd, path)
				reached[str(sim.get("final", ""))] = true
				results[str(sim.get("resultado", ""))] = true
			if cd.has("timeout"):
				reached[str((cd["timeout"] as Dictionary).get("fin", ""))] = true
			for f in finals.keys():
				if not reached.has(str(f)) and not str(f).begins_with("fin_timeout"):
					bad.append("%s: final %s sin camino" % [cd.get("id"), f])
			for r in ["satisfecho", "neutral", "molesto"]:
				if not results.has(r):
					bad.append("%s: ningún camino termina %s" % [cd.get("id"), r])
			for n in (cd.get("nodos", {}) as Dictionary).values():
				if str((n as Dictionary).get("cliente", {}).get("es", "")) == "" or str((n as Dictionary).get("cliente", {}).get("en", "")) == "":
					bad.append("%s: texto vacío" % cd.get("id"))
	for b in bad:
		t.fail(b)
	t.check(total >= 45, "%d árboles en T1-T3 (≥ 45)" % total)
	t.check(bad.is_empty(), "todos los caminos de los %d árboles llegan a sus finales (satisfecho, neutral y molesto)" % total)


func _sorteo(t: Node) -> void:
	for tn in [1, 2, 3]:
		for lvl in [Difficulty.Level.FACIL, Difficulty.Level.NORMAL, Difficulty.Level.DIFICIL]:
			await t.start_shift("Marko", tn, 0, lvl)
			var cm := t.main.get("contacts") as ContactManager
			var d := DataLoader.dict("contactos_t%d" % tn)
			var rg: Array = (d.get("contactos_por_turno", {}) as Dictionary).get(Difficulty.id(lvl), [0, 99])
			var planned := cm._planned_scripted.size() + cm.filler_quota
			t.check(cm.planned_total >= int(rg[0]) and cm.planned_total <= int(rg[1]), "T%d %s: %d contactos (rango %s)" % [tn, Difficulty.id(lvl), cm.planned_total, str(rg)])
			t.check(planned == cm.planned_total, "T%d %s: guionizados %d + relleno %d = %d" % [tn, Difficulty.id(lvl), cm._planned_scripted.size(), cm.filler_quota, cm.planned_total])
			var fijos_ok := true
			for f in d.get("fijos", []):
				fijos_ok = fijos_ok and cm._planned_scripted.has(str(f))
			t.check(fijos_ok, "T%d: los fijos (historia) siempre salen" % tn)
			var uniq := {}
			for s in cm._planned_scripted:
				uniq[s] = true
			t.check(uniq.size() == cm._planned_scripted.size(), "T%d: sin guionizados repetidos" % tn)
			# v0.3.1 (integración): la bolsa crece con la dificultad; los «solo_dificil» no salen en Fácil/Normal.
			var bolsa := 0
			var solo := 0
			for c in d.get("contactos", []) + d.get("relleno", []):
				if (c as Dictionary).has("nodos") and ContactManager.eligible(c):
					bolsa += 1
					solo += 1 if bool((c as Dictionary).get("solo_dificil", false)) else 0
			var leak := false
			for f in cm._fillers():
				leak = leak or (bool((f as Dictionary).get("solo_dificil", false)) and lvl < Difficulty.Level.DIFICIL)
			t.check(not leak and (solo == 0) == (lvl < Difficulty.Level.DIFICIL), "T%d %s: bolsa de %d árboles distintos (%d solo Difícil/Turno real)" % [tn, Difficulty.id(lvl), bolsa, solo])
			t.check(bolsa >= 15 and bolsa <= 20, "T%d %s: bolsa entre 15 y 20 (%d)" % [tn, Difficulty.id(lvl), bolsa])
	await t.back_to_menu()


func _sin_repetir(t: Node) -> void:
	for tn in [1, 2, 3]:
		await t.start_shift("Ttoom", tn)
		var cm := t.main.get("contacts") as ContactManager
		var ids := {}
		var n := cm._fillers().size()  # v0.3.1: el relleno que entra con la dificultad (sin los solo_dificil en Normal)
		for i in n:
			var f := cm._filler()
			ids[str(f.get("ref_id", f.get("id", "")))] = true
		t.check(ids.size() == n, "T%d: %d rellenos seguidos, %d distintos" % [tn, n, ids.size()])
	await t.back_to_menu()


# --- F16 ---------------------------------------------------------------------------------------

func _desk(t: Node) -> Node:
	return t.get_tree().get_first_node_in_group("pc_desktop")


func _open_case(t: Node, cid: String, turno: int = 1) -> ContactManager:
	await t.start_shift("Jiroshi", turno)
	await t.login_at_seat()
	var cm := t.main.get("contacts") as ContactManager
	var c := {}
	for x in (DataLoader.dict("casos_bo").get("turnos", {}) as Dictionary).get(str(turno), []):
		if str((x as Dictionary).get("id", "")) == cid:
			c = (x as Dictionary).duplicate(true)
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c)
	cm.accept()
	await t.frames(3)
	return cm


func _correo_pasos(t: Node) -> void:
	(SaveSlots.progress().get("tooltips_vistos", []) as Array).erase(PcCorreo.GUIDE_FLAG)  # partida «nueva» para la guía
	var cm := await _open_case(t, "t1_correo_pod")
	var desk := _desk(t)
	t.check(desk != null, "PC")
	if desk == null:
		return
	desk.call("open_app", "correo")
	var correo := desk.get("correo") as PcCorreo
	correo._guide_off = false
	correo._guide_case = ""
	correo.refresh(0.1)
	await t.frames(2)
	t.check(correo.current_step() == "kardex", "paso actual: Kardex")
	var lock := correo.find_child("LineaBloqueo", true, false) as Label
	t.check(lock != null and lock.text == Loc.tr("Q4_MAIL_LOCKED") and Loc.tr("Q4_MAIL_LOCKED") in ["Busca la operación en Kardex", "Look up the transaction in Kardex"], "bloqueado con una sola línea: «%s»" % (lock.text if lock != null else "—"))
	t.check((correo.find_child("OptDestinatario", true, false) as OptionButton).disabled and (correo.find_child("Enviar", true, false) as Button).disabled, "destinatario y enviar bloqueados")
	# v0.3.2 (Joan): con un partner normal la barra son los 7 pasos del Training; «Adjunto» es solo de los casos de Vitzo.
	t.check(correo.find_child("BarraPasos", true, false).get_child_count() == 7 and correo.find_child("Paso_adjunto", true, false) == null, "barra de 7 pasos, sin «Adjunto»")
	t.check((correo.find_child("RelojCaso", true, false) as Label).text.contains("10:00"), "reloj de 10 min junto a la barra")
	var guia := correo.find_child("GuiaCorreo", true, false) as Control
	t.check(guia != null and guia.visible, "primer correo: guía visible")
	# Kardex
	cm.kardex_lookup("KP-2211-3312")
	correo.refresh(0.1)
	await t.frames(1)
	t.check(correo.step_done("kardex") and correo.current_step() == "destinatario", "Kardex hecho (check) → Destinatario")
	t.check(correo.find_child("LineaBloqueo", true, false) == null, "desbloqueado")
	cm.set_recipient("Banco Andino")
	cm.set_template("POD")
	correo.refresh(0.1)
	t.check(correo.current_step() == "campos", "→ Campos")
	# copiar desde Kardex al campo activo
	var kd := desk.get("kardex") as PcKardex
	t.check(cm.mail_active_field == "id", "campo activo: ID")
	t.check(kd.copy_value("KP-2211-3312") and str(cm.case.fields.get("id")) == "KP-2211-3312", "clic en el KP de Kardex lo copia al ID")
	t.check(cm.mail_active_field == "monto", "el activo pasa al siguiente vacío (monto)")
	cm.set_active_field("fecha")
	kd.copy_value("08/11")
	cm.set_active_field("monto")
	kd.copy_value("1.250,00 KP")
	correo.refresh(0.1)
	t.check(cm.case.fields_complete() and correo.current_step() == "enviar", "campos completos → Enviar (v0.3.2: el partner no es Vitzo, no hay nada que adjuntar; antes pedía «Adjunto»)")
	var chk_att := correo.find_child("Adjunto", true, false) as CheckBox
	t.check(chk_att == null or not chk_att.visible, "sin casilla de adjuntar en un caso que no es de Vitzo")
	var sent: Array = t.spy("email_sent")
	cm.send_email()
	correo.refresh(0.1)
	await t.frames(1)
	t.check(sent.size() == 1 and correo.current_step() == "tipificar", "enviar → Tipificar")
	var reds := 0
	for l in correo.find_children("*", "Label", true, false):
		var lb := l as Label
		if lb.visible and lb.get_theme_color("font_color") == PcStyle.RED:
			reds += 1
	t.check(reds == 0, "al enviar no se marca nada en rojo (Joan)")
	cm.set_typification("pod_solicitado")
	correo.refresh(0.1)
	t.check(correo.current_step() == "cerrar", "→ Cerrar")
	var out: Array = t.spy("contact_outcome")
	cm.close_case()
	correo.refresh(0.1)
	await t.frames(1)
	t.check(out.size() == 1 and str(out[0][1]) == "bo_ok", "caso bien cerrado")
	t.check(SaveSlots.tooltip_seen("q4_guia_correo"), "la guía no vuelve (queda en la partida)")
	await t.back_to_menu()


func _correo_marcas(t: Node) -> void:
	var cm := await _open_case(t, "t1_correo_pod")
	cm.kardex_lookup("KP-2211-3312")
	cm.set_recipient("Banco Andino")
	cm.set_template("Status")
	cm.set_field("id", "KP-2211-3312")
	cm.set_field("monto", "1.205,00 KP")
	cm.set_field("fecha", "08/11")
	cm.send_email()
	cm.set_typification("status_partner")
	var out: Array = t.spy("contact_outcome")
	cm.close_case()
	await t.frames(1)
	var qa: Array = (out[0][0] as Dictionary).get("_qa", []) if not out.is_empty() else []
	t.check(qa.has("correo_plantilla") and qa.has("correo_campo_monto") and qa.has("tipificacion") and not qa.has("correo_incorrecto"), "marcas por lo que falló: %s" % str(qa))
	t.check(not qa.has("correo_campo_id") and not qa.has("correo_campo_fecha"), "los campos bien no se marcan")
	await t.back_to_menu()


# --- Haime personalizado -----------------------------------------------------------------------

static func _entry(c: Dictionary, marks: Array, choices: Array = []) -> Dictionary:
	var cc := c.duplicate(true)
	cc["_choices"] = choices
	return {"id": str(c.get("id", "")), "hora": "01:00", "marcas": marks, "resultado": "molesto", "canal": str(c.get("canal", "")), "transcripcion": QaFeedback.transcript(cc)}


func _ids_of(tipo: String) -> Dictionary:
	var d := DataLoader.dict("haime_guiones")
	var ok := {}
	for lv in ((d.get("intro", {}) as Dictionary).get(tipo, {}) as Dictionary).values():
		for l in lv:
			ok[str(l.get("id"))] = true
	for lines in (d.get("marcas", {}) as Dictionary).values():
		for l in lines:
			if (l.get("tipos", []) as Array).has(tipo):
				ok[str(l.get("id"))] = true
	for l in (d.get("genericas", {}) as Dictionary).get(tipo, []):
		ok[str(l.get("id"))] = true
	for l in (d.get("casos", {}) as Dictionary).values():
		ok[str(l.get("id"))] = true
	for l in (d.get("caso_tipo", {}) as Dictionary).values():
		ok[str(l.get("id"))] = true
	return ok


func _haime_tipos(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	var bo := DataLoader.dict("casos_bo")
	var c1 := {}
	for c in DataLoader.dict("contactos_t1").get("contactos", []):
		if str(c.get("id")) == "t1c1":
			c1 = c
	var chat := {}
	for c in DataLoader.dict("contactos_t1").get("contactos", []):
		if str(c.get("id")) == "t1c8":
			chat = c
	var casos := {}
	for tn in ["1", "2", "3"]:
		for c in (bo.get("turnos", {}) as Dictionary).get(tn, []):
			casos[str(c.get("id"))] = c
	var tests := [
		["llamada", _entry(c1, ["respuesta_sin_revisar", "molesto"], ["inicio.c", "repite_fuerte.b"])],
		["chat", _entry(chat, ["culpar_cliente"], ["inicio.c", "enojo.b"])],
		["correo", _entry(casos["t1_correo_pod"], ["correo_plantilla", "correo_campo_monto", "tipificacion"])],
		["vitzo", _entry(casos["vz_pod"], ["falta_portal_pod", "sin_pod"])],
		["kyc", _entry(casos["t1_kyc_norvalia"], ["kyc_aprobar"])],
	]
	var all_lines := {}
	var forbidden := RegEx.create_from_string("(?i)\\b(cliente|clienta|llamada|colg|customer|call|hung up)")
	for tc in tests:
		var tipo := str(tc[0])
		var e := tc[1] as Dictionary
		GameState.flags.erase(HaimeGuion.USED_KEY)
		t.check(HaimeGuion.entry_type(e) == tipo, "%s: tipo detectado %s" % [e.get("id"), HaimeGuion.entry_type(e)])
		var ok := _ids_of(tipo)
		for n in [1, 2, 3]:
			var seq := HaimeGuion.sequence(e, n, n == 3)
			var oms := 0
			for it in seq:
				var d := it as Dictionary
				if d.has("om"):
					oms += 1
				if not d.has("text"):
					continue
				var key := str(d["key"])
				t.check(ok.has(key), "%s n=%d: «%s» es de tipo %s" % [e.get("id"), n, key, tipo])
				if tipo in ["correo", "vitzo", "kyc"]:
					var body := str(d["text"])
					if body.begins_with("«"):
						body = body.substr(body.find("»") + 1)
					var from_customer := tipo == "correo" and str((casos.get(str(e.get("id")), {}) as Dictionary).get("de", "")).ends_with("@correo.kp")
					t.check(from_customer or forbidden.search(body) == null, "%s n=%d: sin «cliente/llamada» en «%s»" % [e.get("id"), n, body.left(60)])
				all_lines[key] = int(all_lines.get(key, 0)) + 1
			if n < 3:
				t.check(oms == HaimeGuion.opportunities(e), "%s n=%d: %d oportunidades = %d marcas reales" % [e.get("id"), n, oms, HaimeGuion.opportunities(e)])
	# Joan 11:14Z: el correo de t1_correo_pod ya no habla de empatía ni de respirar.
	var seq2 := HaimeGuion.sequence(tests[2][1], 1, false)
	var txt := ""
	for it in seq2:
		txt += str((it as Dictionary).get("text", "")) + " "
	t.check(not txt.contains("respiraste") and not txt.contains("Sonó aprendida"), "el correo no recibe líneas de llamada (respirar, empatía hablada)")
	t.check(txt.contains("plantilla") and txt.contains("monto") and (txt.contains("ipific") or txt.contains("código")), "habla de plantilla, monto y tipificación: %s" % txt)
	# Sin repetir en el turno: 3 sesiones del mismo tipo con la misma marca no repiten líneas de oportunidad.
	GameState.flags.erase(HaimeGuion.USED_KEY)
	var seen := {}
	var rep := 0
	for n in [1, 2]:
		for it in HaimeGuion.sequence(tests[0][1], n, false):
			var d2 := it as Dictionary
			if d2.has("om"):
				if seen.has(d2["key"]):
					rep += 1
				seen[d2["key"]] = true
	t.check(rep == 0, "dos sesiones del mismo caso: 0 oportunidades repetidas")
	await t.back_to_menu()


func _haime_voces(t: Node) -> void:
	var missing: Array[String] = []
	for id in HaimeGuion.all_voice_ids():
		var s := "voces/haime/" + id
		if not AudioManager.has_slot(s, false) or not AudioManager.has_slot("voces/haime/en/" + id, false):
			missing.append(id)
	t.check(missing.is_empty(), "%d líneas de Haime con voz ES/EN (faltan %d: %s)" % [HaimeGuion.all_voice_ids().size(), missing.size(), ", ".join(missing.slice(0, 8))])
	await t.frames(1)


# --- F24 ---------------------------------------------------------------------------------------

func _menu(t: Node) -> void:
	await t.back_to_menu()
	var menu: Control = t.main.get("main_menu")
	Loc.set_setting("intro_vista", false)
	var intro := menu.call("play_intro", true) as IntroArranque
	await t.frames(2)
	t.check(intro != null and not intro.skippable, "1.ª vez: la intro no se salta")
	var k := InputEventKey.new()
	k.pressed = true
	k.keycode = KEY_A
	intro._try_skip(k)
	t.check(menu.get("intro") != null, "una tecla no la salta la primera vez")
	intro.seek(IntroArranque.DURATION - 0.01, false)
	await t.until(func() -> bool: return menu.get("intro") == null, 3.0)
	t.check(menu.get("intro") == null and bool(Loc.get_setting("intro_vista", false)), "termina y queda vista")
	var home := menu.find_child("MenuPrincipal", true, false) as Control
	var agents := menu.find_child("SeleccionAgente", true, false) as Control
	t.check(home != null and home.visible and agents != null and not agents.visible, "después: menú principal, sin selección de agente")
	for b in ["PlayBtn", "TutorialBtn", "OptionsBtn", "ManualBtn", "CreditsBtn", "QuitBtn"]:
		t.check(home.find_child(b, true, false) is Button, "menú principal: " + b)
	var intro2 := menu.call("play_intro") as IntroArranque
	await t.frames(2)
	t.check(intro2.skippable, "2.ª vez: se puede saltar")
	intro2._try_skip(k)
	await t.frames(2)
	t.check(menu.get("intro") == null, "una tecla la salta")
	(home.find_child("PlayBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(2)
	agents = menu.find_child("SeleccionAgente", true, false) as Control
	t.check(agents.visible and not home.visible, "Jugar → selección de agente")
	var cards := agents.find_child("Agentes", true, false)
	t.check(cards != null and cards.get_child_count() == 5, "los 5 agentes")
	for a in GameState.AGENTS:
		var card := agents.find_child("Agente_" + a, true, false)
		var sum: Label = null
		if card != null:
			for l in card.find_children("SlotLbl*", "Label", true, false):
				sum = l
		t.check(sum != null and sum.text.begins_with(a), "tarjeta de %s con su resumen («%s»)" % [a, sum.text if sum != null else "—"])
	# Continuar con una partida
	SaveSlots.select("Marko")
	SaveSlots.save("Marko")
	menu.set("agent_index", GameState.AGENTS.find("Marko"))
	menu.call("_build")
	menu.call("go_agents")
	await t.frames(2)
	var got: Array = []
	var cb := func() -> void: got.append(true)
	menu.connect("continue_requested", cb)
	var cont := menu.find_child("ContinueBtn", true, false) as Button
	t.check(cont != null and cont.is_visible_in_tree(), "Marko con partida: Continuar visible en su tarjeta")
	if cont != null:
		cont.emit_signal("pressed")
	await t.frames(3)
	t.check(got.size() == 1, "Continuar emite continue_requested")
	menu.disconnect("continue_requested", cb)
	await t.back_to_menu()
	menu.call("go_agents")
	(menu.find_child("BackBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(1)
	t.check((menu.find_child("MenuPrincipal", true, false) as Control).visible, "Atrás vuelve al menú principal")


# --- B11 ---------------------------------------------------------------------------------------

func _cine() -> Cinematicas:
	return null


func _cinematicas(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.frames(5)
	var cin := t.main.get_node_or_null("UI/Cinematicas") as Cinematicas
	t.check(cin != null, "Cinematicas vive junto a la UI (sin tocar main.gd)")
	if cin == null:
		return
	t.check(cin.playing == "", "con --escenario no sale sola")
	t.check(cin.play("intro_t1", true), "intro T1")
	await t.frames(3)
	t.check(GameState.clock_override == "quiz", "el reloj espera (override quiz)")
	var c0 := GameState.clock_seconds
	await t.seconds(2.0)
	t.check(absf(GameState.clock_seconds - c0) < 0.5, "el reloj no avanza durante la cinemática (%.1f s)" % (GameState.clock_seconds - c0))
	t.check(t.player().cinematic, "el jugador no se mueve")
	var cam := t.get_tree().root.get_viewport().get_camera_3d()
	t.check(cam != null and cam.name == "CamaraCinematica", "cámara propia")
	cin.t = 12.0  # toma de la ventana del piso 2 (10.5–15.5 s)
	await t.frames(3)
	t.check(t.building().floor_node.find_child("VentanaShero", true, false) != null, "silueta de Shero en la ventana del piso 2")
	cin._hold = Cinematicas.HOLD_SKIP_S + 1.0
	await t.frames(2)
	t.check(cin.playing == "" and cin.skipped, "mantener Espacio la salta")
	t.check(GameState.clock_override == "" and not t.player().cinematic, "el reloj y el jugador vuelven")
	t.check(t.get_tree().root.get_viewport().get_camera_3d() == t.player().camera, "la cámara vuelve al jugador")
	for id in ["t2_capacitacion", "t3_allocations", "salida"]:
		var done: Array = []
		var cb := func(i: String, s: bool) -> void: done.append([i, s])
		cin.finished.connect(cb)
		t.check(cin.play(id, true), id + " empieza")
		await t.frames(4)
		t.check(cin._stage_rect.visible, id + ": decorado propio")
		cin.t = cin._total - 0.05
		await t.until(func() -> bool: return not done.is_empty(), 3.0)
		t.check(done.size() == 1 and not bool(done[0][1]), id + " termina sola")
		cin.finished.disconnect(cb)
	await t.back_to_menu()


# --- F15 ---------------------------------------------------------------------------------------

func _taper(t: Node) -> void:
	await t.start_shift("Marko", 1)
	var b: Building = t.building()
	b.go_to_floor(2, "casillero")
	await t.frames(3)
	var locker := b.floor_node.find_child("MiCasillero", true, false) as Interactable
	t.check(locker.interact(t.player()) and bool(GameState.flags.get("locker_done", false)), "casillero: mochila guardada")
	await t.frames(2)
	var manos := t.player().camera.get_node_or_null("ManosFx") as ManosFx
	t.check(manos != null and manos.busy and manos.visible, "manos en cámara (animación del casillero)")
	t.check(locker.get_node_or_null("PuertaPivote") != null, "la puerta del casillero se abre")
	var fridge := b.floor_node.find_child("Refri1", true, false) as Interactable
	fridge.interact(t.player())
	t.check(WorldObjects.TaperFlow.state() == "refri" and bool(GameState.flags.get("lunch_stored", false)), "taper en la refri (con tu nombre)")
	fridge.interact(t.player())
	t.check(WorldObjects.TaperFlow.state() == "refri", "fuera del lunch no lo sacas")
	Metrics.set_aux(Metrics.Aux.LUNCH)
	fridge.interact(t.player())
	t.check(WorldObjects.TaperFlow.state() == "mano", "en el lunch lo sacas")
	b.go_to_floor(-1, "cafeteria")
	await t.frames(3)
	var fl: Node = b.floor_node
	var mws: Array = []
	for n in t.get_tree().get_nodes_in_group("microondas"):
		if WorldObjects.TaperFlow.floor_of(n as Node) == fl:  # v0.3.1: los de Q5 cuelgan de EstacionMicroondas
			mws.append(n)
	t.check(mws.size() == 6, "%d microondas en la cafetería del -1 (Q5: 2 filas de 3)" % mws.size())
	if mws.size() < 6:
		# Con el -1 de Q5 hay 6 (2 filas de 3); aquí se arma la fila para probar el reparto.
		var holder := Node3D.new()
		holder.name = "FilaPrueba"
		fl.add_child(holder)
		for i in 6:
			WorldObjects.simple(holder, WorldObjects.Microwave, "Microondas_%d" % i, "HUD_MICROWAVE", Vector3(28 + i * 0.7, 1.1, 2), Vector3(0.6, 0.4, 0.5), Greybox.GRIS_OSCURO)
		await t.frames(1)
		mws.clear()
		for c in holder.get_children():
			mws.append(c)
	(mws[0] as WorldObjects.Microwave).hint_text()  # asigna los estados
	var states := {}
	for m in mws:
		var st := str((m as WorldObjects.Microwave).state)
		states[st] = int(states.get(st, 0)) + 1
	t.check(int(states.get("fuera", 0)) == 1 and int(states.get("ocupado", 0)) >= 2 and int(states.get("libre", 0)) >= 1, "6 microondas: uno fuera de servicio, ocupados y libres %s" % str(states))
	var free: WorldObjects.Microwave = null
	for m in mws:
		if (m as WorldObjects.Microwave).state == "libre":
			free = m
	var busy: WorldObjects.Microwave = null
	for m in mws:
		if (m as WorldObjects.Microwave).state == "ocupado":
			busy = m
	t.check(busy != null and free != null and not busy.interact(t.player()), "uno ocupado no se puede usar")
	if busy == null or free == null:
		return
	free.interact(t.player())
	t.check(free.state == "mio_calentando" and WorldObjects.TaperFlow.state() == "calentando", "tu taper se calienta (1 min de juego)")
	await t.advance_clock(30.0)
	await t.frames(2)
	t.check(free.state == "mio_calentando", "a los 30 s todavía no")
	await t.advance_clock(35.0)
	await t.frames(3)
	t.check(free.state == "mio_listo" and WorldObjects.TaperFlow.state() == "listo", "¡ding! listo")
	free.interact(t.player())
	t.check(WorldObjects.TaperFlow.state() == "caliente", "lo sacas caliente")
	var spots: Array = fl.find_children("Comer_*", "", true, false)
	t.check(spots.size() >= 4, "%d sitios para comer en las mesas de la cafetería (Mesa<n> de Q5, no junto al microondas)" % spots.size())
	Fatigue.set_value(60.0)
	var f0 := Fatigue.value
	(spots[0] as Interactable).interact(t.player())
	t.check(absf(Fatigue.value - (f0 - 20.0 * Difficulty.fatigue_rate("recuperacion"))) < 0.01, "comer: Fatiga −20 × recuperación de la dificultad (v0.3.2) (%.0f → %.0f)" % [f0, Fatigue.value])
	t.check(Fatigue.blur_suppressed(), "energía: sin desenfoque")
	t.check(Fatigue.microsleep_suppressed(), "energía: sin microsueños (Fatigue.suppress_microsleep)")
	t.check(t.player().breath > 6.5, "energía: aliento ×1,5 (%.1f)" % t.player().breath)
	t.check(bool(GameState.flags.get("lunch_eaten", false)) and WorldObjects.TaperFlow.state() == "comido", "cuenta como lunch completo")
	# Se echa a perder si nunca fue a la refri.
	GameState.flags["taper"] = "mochila"
	GameState.clock_seconds = GameState.ARRIVAL_SECONDS + 4.1 * 3600.0
	WorldObjects.TaperFlow.check_spoiled()
	t.check(WorldObjects.TaperFlow.state() == "malogrado", "a las 4 h en la mochila se echa a perder")
	await t.back_to_menu()


# --- F22 ---------------------------------------------------------------------------------------

func _rasec_event(t: Node, turno: int, forced: String) -> RasecControl:
	await t.start_shift("Jiroshi", turno)
	var cm := t.main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.login_at_seat()
	for s in t.get_tree().get_nodes_in_group("shero"):
		(s as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var hub := PersonajesP5.get_hub(t.get_tree())
	# v0.3.2-core2: a la hora del evento la clase del Trainer (T2/T3) ya pasó hace horas. Sin esto el salto de reloj
	# la convocaba en el mismo cuadro y, desde «de a uno» (v0.3.2-core), Rasec espera a que no haya otro llamado
	# pendiente: el evento no llegaba a empezar en la prueba (fallaba desde af49f11; jugando no pasa).
	if hub.training != null:
		hub.training.state = TrainingControl.State.HECHO
	# Solo el evento de Rasec. Desde la v0.3.2 te convocan de a uno (hub.summon_pending): al saltar el reloj hasta el
	# evento, en T2 y T3 el llamado de Haime (o el del Trainer) cae antes y el evento lo espera, que es lo correcto en
	# el juego (core_convocan_de_a_uno lo prueba) pero no es lo que mide esta prueba.
	for other in [hub.qa, hub.training]:
		if other != null:
			(other as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await t.set_clock(hub.rasec.event_clock() + 1.0)
	await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.CONVOCADO, 3.0)
	hub.rasec.forced_play = forced
	Metrics.set_aux(Metrics.Aux.BO)
	t.player().stand_up()
	var m := (t.building().floor_node as Node).find_child("evento_rasec", true, false) as Node3D
	t.player().teleport(m.global_position, 0.0)
	await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.EVENTO, 4.0)
	return hub.rasec


func _rasec(t: Node) -> void:
	for tc in [[1, "karaoke", "ok"], [2, "charadas", "excusa"], [3, "sillas", "burla"], [1, "karaoke", "burla"]]:
		var r := await _rasec_event(t, int(tc[0]), str(tc[2]))
		t.check(r.state == RasecControl.State.EVENTO and r.kind == str(tc[1]), "T%d: %s" % [tc[0], tc[1]])
		await t.until(func() -> bool: return r.hartos != null and r.hartos.get("_extras").size() > 0, 3.0)
		var extras: Array = r.hartos.get("_extras")
		t.check(extras.size() >= 2 and t.building().floor_node.find_child("AgenteDormido", true, false) != null, "compañeros hartos: uno dormido en el suelo, otro mirando la hora")
		await t.until(func() -> bool: return r.state != RasecControl.State.EVENTO, 120.0)
		var n := r.decisions_log.size()
		t.check(n >= 3 and n <= 4, "%s/%s: %d decisiones" % [tc[1], tc[2], n])
		var tipos := {}
		for d in r.decisions_log:
			tipos[str((d as Dictionary).get("tipo"))] = true
		var want := {"ok": "seguir"}.get(str(tc[2]), str(tc[2])) as String
		t.check(tipos.size() == 1 and tipos.has(want), "%s: todas las respuestas fueron «%s» %s" % [tc[1], want, str(tipos)])
		t.check(r.hartos.said.size() >= n, "los compañeros reaccionan y susurran (%d)" % r.hartos.said.size())
		match str(tc[2]):
			"ok":
				t.check(r.state == RasecControl.State.HECHO and r.warnings() == 0 and r.notes == 0, "seguirle el juego: 0 anotaciones, 0 advertencias, termina")
			"excusa":
				t.check(r.state == RasecControl.State.HECHO and r.notes <= 1 and r.warnings() == 0, "excusas: %d anotación(es), termina" % r.notes)
			"burla":
				t.check(r.notes >= 2 and r.warnings() == 1 and r.state == RasecControl.State.HECHO, "burlarte: %d anotaciones → 1 advertencia, el evento termina igual" % r.notes)
	await t.back_to_menu()


func _ventana(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var cm := t.main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.login_at_seat()
	var hub := PersonajesP5.get_hub(t.get_tree())
	await t.set_clock(hub.rasec.event_clock() + 1.0)
	await t.until(func() -> bool: return hub.rasec.state == RasecControl.State.CONVOCADO, 3.0)
	var w0 := hub.rasec.window_at
	await t.set_clock(w0 + 2.0 * 60.0 + 5.0)
	await t.frames(2)
	t.check(hub.rasec.warnings() == 0, "sentado leyendo el DM 2 min: todavía sin advertencia")
	t.player().stand_up()
	await t.frames(1)
	await t.set_clock(GameState.clock_seconds + 61.0)
	await t.frames(2)
	t.check(hub.rasec.warnings() == 1 and hub.rasec.last_result == "advertencia_tarde", "+1 min de pie: advertencia (la ventana se cumple de pie)")
	await t.back_to_menu()

## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P6b · Training (antes «Training», PLAN §2 #84; v0.3.2: el recuerdo, la PC T-01 del piso 1 y la firma
## del contrato) y Manual del agente: el bot hace los 14 módulos completos, cada
## módulo solo (su preparación funciona desde cero), cada módulo se puede saltar (y el siguiente sigue bien),
## no hay muertes reales salvo el colapso de práctica, el guardado de la Training no toca la partida del agente,
## el menú de módulos, el Manual (términos ES/EN, pausa y Campus), los tooltips de primera vez por dificultad y
## la pista extra de Fácil en «Siguiente paso».

const BOT := "res://scripts/dev/bot_tutorial.gd"


func escenarios() -> Array[String]:
	return ["p6b_training_completo", "p6b_training_modulos", "p6b_training_modulo:", "p6b_training_saltar",
		"p6b_training_saltar_cada", "p6b_training_sin_muertes", "p6b_training_guardado", "p6b_training_menu",
		"p6b_manual", "p6b_tooltips", "p6b_pistas_dificultad"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"p6b_training_completo": await _completo(t)
		"p6b_training_modulos": await _modulos(t)
		"p6b_training_modulo": await _uno(t, arg, true)
		"p6b_training_saltar": await _saltar(t)
		"p6b_training_saltar_cada": await _saltar_cada(t)
		"p6b_training_sin_muertes": await _sin_muertes(t)
		"p6b_training_guardado": await _guardado(t)
		"p6b_training_menu": await _menu(t)
		"p6b_manual": await _manual(t)
		"p6b_tooltips": await _tooltips(t)
		"p6b_pistas_dificultad": await _pistas(t)


## Corre el bot de la Training con esos módulos (vacío = pendientes) y devuelve su informe.
func _bot(t: Node, mods: Array, skip: Array = [], timeout_s: float = 400.0) -> Dictionary:
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotTutorialEsc"
	bot.set("log_steps", false)
	bot.set("timeout_s", timeout_s)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("start", t.main, mods, skip)
	await t.until(func() -> bool: return not out.is_empty(), timeout_s + 5.0)
	bot.queue_free()
	await t.frames(3)
	return out[0] if not out.is_empty() else {"errores": ["el bot no terminó"], "modulos": {}}


func _completo(t: Node) -> void:
	var shown: Array = t.spy("death_shown")
	var blocked := [0]
	var cb := func(txt: String, _s: float) -> void:
		if txt.begins_with(Loc.tr("TUT_DEATH_BLOCKED").get_slice("«", 0).strip_edges()):
			blocked[0] += 1
	EventBus.show_message.connect(cb)
	SaveSlots.select("Llauri")
	var r := await _bot(t, [])
	EventBus.show_message.disconnect(cb)
	var mods: Dictionary = r.get("modulos", {})
	t.check((r.get("errores", []) as Array).is_empty(), "el bot terminó sin errores %s" % str(r.get("errores")))
	t.check(mods.size() == Tutorial.module_ids().size() and mods.size() == 14, "hizo los 14 módulos (%d)" % mods.size())
	for id in Tutorial.module_ids():
		t.check(str(mods.get(id, "")) == "hecho", "módulo %s completo" % id)
	t.check(shown.size() == 1 and str(shown[0][0]) == "colapso", "una sola pantalla de muerte: el colapso de práctica (%s)" % str(shown))
	t.check(blocked[0] == 0, "ninguna muerte evitada (el bot lo hizo todo bien): %d" % blocked[0])
	t.check(not GameState.running and t.main.get("main_menu").visible, "al terminar vuelve al menú")
	t.check(not SaveSlots.in_tutorial() and not SaveSlots.exists("Llauri"), "y la partida de Llauri no existe (la Training tiene su guardado)")
	var prog := Tutorial.load_progress()
	t.check(prog.size() == 14, "el progreso del Training quedó guardado (%d)" % prog.size())
	t.note("pasos %d · %.1f s reales a ×%.0f" % [int(r.get("pasos", 0)), float(r.get("tiempo_real_s", 0.0)), Engine.time_scale])


## Cada módulo solo (como desde la selección de módulos): su preparación lo deja listo y se completa.
func _modulos(t: Node) -> void:
	for id in Tutorial.module_ids():
		await _uno(t, id, false)


func _uno(t: Node, id: String, alone: bool) -> void:
	if Tutorial.module_by_id(id).is_empty():
		t.fail("no existe el módulo %s" % id)
		return
	var r := await _bot(t, [id], [], 200.0)
	t.check(str((r.get("modulos", {}) as Dictionary).get(id, "")) == "hecho" and (r.get("errores", []) as Array).is_empty(), "módulo %s solo: completo %s" % [id, str(r.get("errores"))])
	t.check(not GameState.running, "%s: vuelve al menú" % id)
	if alone:
		t.check(Tutorial.load_progress().get(id, "") == "hecho", "y queda marcado como hecho")


## Saltar todo: cada módulo queda «saltado» y se vuelve al menú.
func _saltar(t: Node) -> void:
	var ids := Tutorial.module_ids()
	var skip := ids.duplicate()
	skip.erase(Tutorial.CONTRACT_MODULE)
	var r := await _bot(t, ids, skip, 160.0)
	var mods: Dictionary = r.get("modulos", {})
	for id in skip:
		t.check(str(mods.get(id, "")) == "saltado", "%s se puede saltar" % id)
	t.check(str(mods.get(Tutorial.CONTRACT_MODULE, "")) == "hecho", "la firma del contrato no se salta: se firma")
	t.check(Tutorial.load_progress().size() == 14, "el progreso guarda los saltados")
	t.check(Tutorial.pending_modules().size() == 13, "y «Hacer el Training» ofrece otra vez los 13 saltados (saltado no es hecho)")


## Saltar cada módulo a mitad de camino deja todo limpio para el siguiente (que se completa).
func _saltar_cada(t: Node) -> void:
	var ids := Tutorial.module_ids()
	for i in ids.size():
		var a: String = ids[i]
		var b: String = ids[(i + 1) % ids.size()]
		if a == Tutorial.CONTRACT_MODULE:
			continue  # la firma no se puede saltar
		var r := await _bot(t, [a, b], [a], 220.0)
		var mods: Dictionary = r.get("modulos", {})
		t.check(str(mods.get(a, "")) == "saltado" and str(mods.get(b, "")) == "hecho", "saltar %s y hacer %s (%s)" % [a, b, str(mods)])
		t.check(not Checkpoints.dying and not get_tree_paused(t), "sin muerte ni pausa colgadas tras %s" % a)


func get_tree_paused(t: Node) -> bool:
	return t.get_tree().paused


## En la Training ninguna muerte es real: se avisa y sigue (salvo el colapso de práctica del módulo 9).
func _sin_muertes(t: Node) -> void:
	SaveSlots.select("Marko")
	var tut: Node = t.main.call("_start_tutorial", ["contactos"])
	await t.frames(5)
	t.check(tut != null and GameState.turno == 0 and GameState.is_tutorial() and Difficulty.level == Difficulty.Level.FACIL, "la Training es el Turno 0, en Fácil")
	t.check(Discipline.is_frozen() and Discipline.freeze_reasons().has("tutorial"), "con la disciplina congelada")
	var shown: Array = t.spy("death_shown")
	var seq: Array = t.spy("death_sequence_started")
	await t.login_at_seat()
	for c in ["break_excedido", "abandono", "aux_incorrecto", "correo_vitzo", "calibracion_final", "tercer_ww", "colapso"]:
		GameState.stop_calm()
		await t.die(c, "", "")
		await t.seconds(0.3)
	t.check(shown.is_empty() and seq.is_empty() and not Checkpoints.dying, "7 muertes pedidas, 0 secuencias de muerte")
	t.check(str(GameState.flags.get("tutorial_muerte_evitada", "")) == "colapso", "cada una se avisa («aquí habrías muerto»)")
	Metrics.issue_written_warning("induccion")
	Metrics.ack_left = 0.01
	await t.seconds(0.5)
	t.check(not Pursuit.is_hunting("shero") and not Checkpoints.dying, "un Ack vencido no persigue a nadie")
	var v := t.get_tree().get_first_node_in_group("vitzo")
	v.call("post_reminder")
	v.set("_reminder_left", 0.01)
	await t.seconds(0.5)
	t.check(t.get_tree().root.find_child("VitzoScreamer", true, false) == null and not Checkpoints.dying, "el recordatorio de Vitzo vencido no grita")
	await t.back_to_menu()
	t.check(not GameState.is_tutorial() and not Discipline.is_frozen(), "al salir, el juego normal vuelve a matar")


## El guardado de la Training no toca la partida del agente (ni su checkpoint).
func _guardado(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	await t.advance_clock(1200.0)
	Checkpoints.save_checkpoint("login")
	await t.back_to_menu()
	var prog_before := FileAccess.get_file_as_string(SaveSlots.main_progress_path("Juan"))
	var cp_before := FileAccess.get_file_as_string(SaveSlots.main_checkpoint_path("Juan"))
	SaveSlots.select("Juan")
	var r := await _bot(t, ["aux", "salir"])
	t.check(str((r.get("modulos", {}) as Dictionary).get("salir", "")) == "hecho", "la Training con Juan se hizo")
	t.check(FileAccess.get_file_as_string(SaveSlots.main_progress_path("Juan")) == prog_before, "el progreso de Juan no cambió")
	t.check(FileAccess.get_file_as_string(SaveSlots.main_checkpoint_path("Juan")) == cp_before, "ni su checkpoint a medias")
	t.check(FileAccess.file_exists(SaveSlots.root + SaveSlots.TUTORIAL_DIR + "checkpoint.json"), "los checkpoints de la Training van a su carpeta")
	t.check(Difficulty.level == Difficulty.Level.NORMAL, "al volver, Juan tiene su dificultad (Normal)")
	SaveSlots.select("Juan")
	t.main.call("_continue_shift")
	await t.frames(5)
	t.check(GameState.agent == "Juan" and GameState.turno == 1 and GameState.logged_in, "Continuar con Juan sigue su turno a medias")


## Botón Training del menú → selección de módulos con su estado → «Hacer este».
func _menu(t: Node) -> void:
	Tutorial.save_progress({"aux": "hecho", "contactos": "saltado"})
	var menu: Control = t.main.get("main_menu")
	menu.call("_build")
	await t.frames(2)
	var b := menu.find_child("TutorialBtn", true, false) as Button
	t.check(b != null and not b.disabled and b.text == Loc.tr("MENU_TUTORIAL") and b.text.begins_with("Training"), "el botón «Training» está activo (%s)" % (b.text if b != null else ""))
	b.emit_signal("pressed")
	await t.frames(3)
	var tm := menu.find_child("TutorialMenu", true, false)
	t.check(tm != null, "abre la selección de módulos")
	var st1 := tm.find_child("Mod_aux", true, false).find_child("Estado", true, false) as Label
	var st2 := tm.find_child("Mod_contactos", true, false).find_child("Estado", true, false) as Label
	var st3 := tm.find_child("Mod_correo", true, false).find_child("Estado", true, false) as Label
	t.check(st1.text == Loc.tr("TUTM_DONE") and st2.text == Loc.tr("TUTM_SKIPPED") and st3.text == Loc.tr("TUTM_PENDING"), "con el estado de cada módulo (%s / %s / %s)" % [st1.text, st2.text, st3.text])
	var pend := Tutorial.pending_modules()
	t.check(pend[0] == "llegada" and pend.has("contactos") and not pend.has("aux"), "los pendientes: los no hechos en orden, con el saltado y sin el hecho (%s)" % str(pend.slice(0, 3)))
	(tm.find_child("Mod_correo", true, false).find_child("Hacer", true, false) as Button).emit_signal("pressed")
	await t.frames(5)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	t.check(tut != null and GameState.is_tutorial() and (tut.get("queue") as Array).size() == 1 and str(tut.get("queue")[0]) == "correo", "«Hacer este» arranca solo ese módulo")
	await t.until(func() -> bool: return str(tut.call("module_id")) == "correo", 5.0)
	var panel := t.get_tree().root.find_child("PanelTraining", true, false) as Control
	await t.until(func() -> bool: return panel != null and panel.is_visible_in_tree(), 10.0)  # sale con el primer paso con texto
	t.check(panel != null and panel.is_visible_in_tree(), "el panel de la Training está en pantalla")
	tut.call("skip_module")
	await t.until(func() -> bool: return bool(tut.get("finished")), 10.0)
	tut.call("press_continue")
	await t.frames(5)
	t.check(not GameState.running and menu.visible, "saltar y [T] → menú")


## Manual del agente: términos del plan con definición ES/EN, desde la pausa (sin bloquear) y en Campus.
func _manual(t: Node) -> void:
	var need := ["aux", "aht", "csat", "bo", "kyc", "pod", "wmm", "reversal", "ww", "ack", "allocation", "isla", "tm", "qa", "om", "rta", "available_pct", "hold", "tipificacion", "partner"]
	var by_id := {}
	for term in AgentManual.terms():
		by_id[str(term.get("id", ""))] = term
	for id in need:
		var term: Dictionary = by_id.get(id, {})
		var d: Dictionary = term.get("def", {})
		t.check(not term.is_empty() and str(d.get("es", "")).length() > 20 and str(d.get("en", "")).length() > 20, "término %s con definición ES/EN" % id)
	t.check(AgentManual.terms().size() >= 40 and (AgentManual.data().get("reglas", []) as Array).size() >= 8, "glosario completo (%d términos) y resumen de reglas" % AgentManual.terms().size())
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	var pm: Control = t.main.get("pause_menu")
	pm.call("toggle")
	await t.frames(2)
	pm.call("open_manual")
	await t.frames(3)
	var man := pm.find_child("AgentManual", true, false)
	t.check(man != null and (man as Control).is_visible_in_tree() and t.get_tree().paused, "la pausa abre el Manual (con el juego en pausa)")
	t.check(bool(GameState.flags.get("manual_abierto", false)), "y avisa que se abrió (la Training lo espera)")
	var lista := man.find_child("Lista", true, false)
	var n_all := lista.get_child_count()
	(man.find_child("Buscar", true, false) as LineEdit).text = "Vitzo"
	(man.find_child("Buscar", true, false) as LineEdit).text_changed.emit("Vitzo")
	await t.frames(3)
	t.check(lista.get_child_count() < n_all and lista.get_child_count() > 0, "el buscador filtra (%d → %d)" % [n_all, lista.get_child_count()])
	(man.find_child("Tab_reglas", true, false) as Button).emit_signal("pressed")
	await t.frames(3)
	t.check(lista.get_child_count() >= 16, "la pestaña Reglas muestra las secciones")
	man.emit_signal("closed")
	await t.frames(2)
	t.check(pm.find_child("AgentManual", true, false) == null and pm.visible, "cerrar vuelve a la pausa")
	pm.call("toggle")
	await t.frames(2)
	var ws := t.get_tree().get_first_node_in_group("workstation")
	var campus: Node = ws.get("desktop").get("campus")
	ws.get("desktop").call("open_app", "campus")
	campus.set("_selected", "guia_manual")
	campus.set("_sig", "")
	campus.call("refresh", 0.1)
	await t.frames(2)
	var rt := campus.find_child("ManualTexto", true, false) as RichTextLabel
	t.check(rt != null and rt.text.contains("WMM") and rt.text.contains("POD"), "Campus → Manual del agente muestra el glosario en la PC")
	Loc.set_language("en")
	campus.set("_sig", "")
	campus.call("refresh", 0.1)
	await t.frames(2)
	rt = campus.find_child("ManualTexto", true, false) as RichTextLabel
	t.check(rt != null and rt.text.contains("Where's My Money"), "y en inglés")
	Loc.set_language("es")


## Tooltips de primera vez: una vez por partida, Fácil y Normal sí, Difícil y Turno real no, nunca en la Training.
func _tooltips(t: Node) -> void:
	await t.start_shift("Ttoom", 1, 0, Difficulty.Level.NORMAL)
	await t.login_at_seat()
	var tips: Node = t.main.find_child("AgentTips", true, false)
	t.check(tips != null, "los tooltips viven en la UI")
	EventBus.break_started.emit(1)
	await t.frames(3)
	t.check((tips.get("shown") as Array).has("break") and SaveSlots.tooltip_seen("break"), "primer break → tooltip")
	(tips.get("shown") as Array).clear()
	EventBus.break_started.emit(2)
	await t.frames(3)
	t.check(not (tips.get("shown") as Array).has("break"), "el segundo, no")
	await t.back_to_menu()
	SaveSlots.use_sandbox(SaveSlots.root.get_base_dir().get_base_dir())  # relee del disco
	SaveSlots.select("Ttoom")
	t.check(SaveSlots.tooltip_seen("break"), "visto queda guardado en la partida")
	await t.start_shift("Marko", 1, 0, Difficulty.Level.DIFICIL)
	await t.login_at_seat()
	tips = t.main.find_child("AgentTips", true, false)
	EventBus.break_started.emit(1)
	EventBus.written_warning_issued.emit(1, "x")
	await t.frames(3)
	t.check((tips.get("shown") as Array).is_empty() and not SaveSlots.tooltip_seen("break"), "en Difícil no hay tooltips")
	await t.back_to_menu()
	await t.start_shift("Juan", 1, GameState.Mode.REAL, Difficulty.Level.NORMAL)
	await t.login_at_seat()
	EventBus.break_started.emit(1)
	await t.frames(3)
	t.check((t.main.find_child("AgentTips", true, false).get("shown") as Array).is_empty(), "ni en Turno real")
	await t.back_to_menu()
	await t.start_shift("Llauri", 1, 0, Difficulty.Level.FACIL)
	await t.login_at_seat()
	EventBus.pursuit_started.emit("shero", "abandono")
	await t.frames(3)
	var sh: Array = t.main.find_child("AgentTips", true, false).get("shown")
	t.check(sh.has("persecucion"), "en Fácil la persecución avisa…")
	await t.seconds(10.0)
	t.check(sh.has("persecucion_facil"), "…y da la pista extra (sentarte en C-14 te salva)")


## «Siguiente paso»: Fácil añade una pista; Normal y Difícil no (el panel queda siempre).
func _pistas(t: Node) -> void:
	for lvl in [Difficulty.Level.FACIL, Difficulty.Level.NORMAL, Difficulty.Level.DIFICIL]:
		await t.start_shift("Jiroshi", 1, 0, lvl)
		await t.login_at_seat()
		var cm: ContactManager = t.main.get("contacts")
		var c := Tutorial.case_by_id("tut_correo")
		cm.offer_now(c)
		await t.frames(2)
		cm.accept()
		await t.frames(2)
		var desk: Node = t.get_tree().get_first_node_in_group("workstation").get("desktop")
		desk.call("refresh", 0.1)
		var txt := str(desk.get("_next").get("text"))
		var hint := AgentTips.next_step_hint(cm)
		if lvl == Difficulty.Level.FACIL:
			t.check(hint != "" and txt.contains(hint), "Fácil: «Siguiente paso» con pista (%s)" % hint)
		else:
			t.check(hint == "" and txt != "" and not txt.contains(Loc.tr("TUT_HINT_PREFIX")), "%s: «Siguiente paso» sin pista extra" % Difficulty.IDS[lvl])
		await t.back_to_menu()

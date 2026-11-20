## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 · Training (el recuerdo) y la semana (docs/AVAILABLE_trama_semana):
##   training_contrato          partida nueva desde el menú → Training obligatorio (recuerdo con su fecha, PC T-01 del
##                              piso 1, Trainer amable sin cara de terror, torre limpia) → firma con el fotograma que
##                              falla → corte al presente («N después») → Lunes de la partida principal con el contrato.
##   training_partidas_viejas   las partidas de la v0.3/v0.3.1 no repiten el Training; el T1 de antes es el Lunes.
##   training_etiquetas         días de la semana (ES/EN) en HUD, menú, partidas, Elegir día y cinemáticas; datos de los
##                              7 días + el recuerdo; los turnos de jueves a domingo aún no se juegan (v0.4).
##   training_actualizacion     en los turnos, el Trainer da «Actualización de campaña» con la cara de terror.
##   training_replay            el Training se puede rejugar desde el menú sin tocar la partida.
##   training_voces             el guion habla UNA línea a la vez: con varias líneas seguidas y una llamada de práctica,
##                              ninguna voz se pisa con otra (línea de tiempo de TrainingVoice) y los mini-checks puntúan.
##   training_director          la bienvenida a tiempo real: cada línea del guion sale por el VoiceDirector con su voz
##                              y su subtítulo, el registro de solapes del director queda en 0 y [T] corta una línea.
##   training_comodin           el comodín DE VERDAD en el recuerdo (autoload Comodin): de pie en el pasillo, con el break
##                              vencido, llamas a alguien de tu promoción y te marca Available en la T-01; Shero no se
##                              entera y no cuenta para la partida. Fuera del Training vuelve a llamar a los agentes.
##   training_ecos              el recuerdo vuelve en la semana: la polaroid de tu promoción en C-14 y el primer café.
##   training_aula              el aula viva: la promoción de civil con nombre, de pie en el café y sentada en la
##                              herradura; ríe, aplaude, saluda y SIGUE SENTADA después; tu nombre en tu mesa; el brindis;
##                              nada del presente en el recuerdo (parlantes, susurros, el cartel del tópico).
##   training_reanudar          el Training obligatorio se puede dejar a medias: al volver sigue en el módulo siguiente
##                              (por agente), con lo que ya elegiste; saltando todo lo demás con [F8] igual se firma y
##                              empieza el Lunes.
##   training_largo:<agente>    (no corre con «all») el Training ENTERO a tiempo real, con el bot escuchando cada línea
##                              hasta el final: escribe la línea de tiempo de las voces en $T2_TIMELINE (o
##                              user://training_timeline.txt), mide la duración total y comprueba cero cruces.
##   training_media:<qué>       videos y capturas para Joan (no corren con «all»: el id lleva «:»). Con pantalla y
##                              Movie Maker, a tiempo real:
##     xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##         --write-movie out.avi --fixed-fps 30 -- --escenario training_media:recuerdo --escala 1
##     recuerdo        partida nueva → el Training (recuerdo) → la firma con el fotograma que falla → el corte al presente
##     actualizacion   10 s: la «Actualización de campaña» del martes con la cara real del Trainer
##     fotos           capturas PNG de cada momento en $T2_SHOTS (o user://shots_v032/)
##     modulo_<id>     un solo módulo del Training (con el bot escuchando al Trainer) y se cierra: los clips de avance
##                     para Joan (media_t2/avance_<n>_<id>.mp4)

const BOT := "res://scripts/dev/bot_tutorial.gd"


func escenarios() -> Array[String]:
	return ["training_contrato", "training_partidas_viejas", "training_etiquetas", "training_actualizacion", "training_replay", "training_voces", "training_director", "training_comodin", "training_ecos", "training_aula", "training_reanudar", "training_largo:", "training_media:"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"training_contrato": await _contrato(t)
		"training_partidas_viejas": await _viejas(t)
		"training_etiquetas": await _etiquetas(t)
		"training_actualizacion": await _actualizacion(t)
		"training_replay": await _replay(t)
		"training_voces": await _voces(t)
		"training_director": await _director(t)
		"training_comodin": await _comodin(t)
		"training_ecos": await _ecos(t)
		"training_aula": await _aula(t)
		"training_reanudar": await _reanudar(t)
		"training_largo": await _largo(t, _arg)
		"training_media": await _media(t, _arg)


func _menu_agent(t: Node, agent: String) -> Control:
	var menu: Control = t.main.get("main_menu")
	SaveSlots.select(agent)
	menu.set("agent_index", GameState.AGENTS.find(agent))
	menu.call("_build")
	await t.frames(2)
	return menu


func _contrato(t: Node) -> void:
	var agent := "Jiroshi"
	t.check(SaveSlots.needs_training(agent), "sin partida, Jiroshi necesita el Training")
	var menu := await _menu_agent(t, agent)
	var start := menu.find_child("StartBtn", true, false) as Button
	t.check(start != null and start.text == Loc.tr("Q4_AGENT_START"), "la tarjeta dice «%s»" % (start.text if start != null else "?"))
	start.emit_signal("pressed")
	await t.frames(6)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	t.check(tut != null and bool(tut.get("first_time")) and GameState.turno == 0 and GameState.is_tutorial(), "«Empezar» abre el Training obligatorio (Turno 0)")
	t.check((tut.get("queue") as Array).size() == 14 and str((tut.get("queue") as Array)[0]) == "llegada" and str((tut.get("queue") as Array)[-1]) == Tutorial.CONTRACT_MODULE, "los 14 temas: empieza en la bienvenida y el último es la firma")
	t.check(Flashback.active and t.get_tree().root.find_child("FlashbackLayer", true, false) != null, "con el tratamiento de recuerdo (tonos cálidos, viñeta, grano)")
	var card_seen := [false, ""]
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotTraining"
	bot.set("log_steps", false)
	bot.set("timeout_s", 400.0)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("attach", t.main, tut, [])
	# Lo que se ve en el aula (cuando el bot ya está sentado en T-01).
	await t.until(func() -> bool:
		var c := t.get_tree().root.find_child("TarjetaRecuerdo", true, false)
		if c != null and not card_seen[0]:
			card_seen[0] = true
			var f := c.find_child("Fecha", true, false) as Label
			card_seen[1] = f.text if f != null else ""
		return GameState.seated_at == TrainingRoom.SEAT, 60.0)
	t.check(card_seen[0] and str(card_seen[1]) == "Viernes 25 de agosto de 2023", "tarjeta «Recuerdo» con la fecha de la biblia (%s)" % str(card_seen[1]))
	var fl: Node3D = t.building().floor_node
	t.check(t.building().current_floor == 1 and fl.find_child("Cub_T-01", true, false) != null, "la sesión vive en la PC de training T-01 del piso 1")
	var ws: Node = t.get_tree().get_first_node_in_group("workstation")
	t.check(ws != null and bool(ws.call("seat_has_screens", TrainingRoom.SEAT)), "con las dos pantallas vivas (Fonex, Kardex)")
	var ta := fl.find_child("TrainerAmable", true, false) as TrainerAmable
	t.check(ta != null and ta.rig != null and ta.rig.get_deform() < 0.01, "el Trainer amable: mismo modelo, cara normal (sin deformar)")
	t.check(fl.find_child("Trainer", false, false) == null, "y no está el Trainer de terror")
	var horror := 0
	for n in fl.find_children("*", "", true, false):
		if (String(n.name).begins_with("TuboTartamudo") or String(n.name).begins_with("MonitorDesconectado") or String(n.name).begins_with("BaldosaColgando")) and n is Node3D and (n as Node3D).visible:
			horror += 1
	t.check(horror == 0, "la torre del recuerdo está limpia: sin horror de oficina visible (%d)" % horror)
	t.check(t.main.get("hud") != null and str((t.main.get("hud") as Node).call("_clock_label")).begins_with("RECUERDO"), "el HUD dice RECUERDO (%s)" % str((t.main.get("hud") as Node).call("_clock_label")))
	# La firma y el corte al presente.
	var glitch := [-1]
	var cut_text := [""]
	await t.until(func() -> bool:
		var c := t.get_tree().root.get_node_or_null("ContractUI")
		if c != null:
			glitch[0] = int(c.get("glitch_frames"))
		var cut := t.get_tree().root.get_node_or_null("CortePresente")
		if cut != null and cut_text[0] == "":
			var d := cut.find_child("Despues", true, false) as Label
			var p := cut.find_child("Presente", true, false) as Label
			cut_text[0] = (p.text if p != null else "") + " " + (d.text if d != null else "")
		return not out.is_empty() or GameState.turno == 1, 400.0)
	await t.until(func() -> bool: return GameState.turno == 1 and GameState.running, 20.0)
	await t.until(func() -> bool: return not out.is_empty(), 5.0)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("errores", []) as Array).is_empty(), "el bot hizo el Training sin errores %s" % str(r.get("errores", [])))
	t.check(str((r.get("modulos", {}) as Dictionary).get(Tutorial.CONTRACT_MODULE, "")) == "hecho", "firmó el contrato")
	t.check(glitch[0] == 1, "al firmar, la pantalla falla exactamente un fotograma (%d)" % glitch[0])
	t.check(str(cut_text[0]) == "Lunes 26 de octubre de 2026 — 3 años y 2 meses después", "corte al presente: «%s»" % str(cut_text[0]))
	t.check(GameState.turno == 1 and not GameState.is_tutorial() and not SaveSlots.in_tutorial() and GameState.agent == agent, "y empieza el Lunes de Jiroshi")
	t.check(not Flashback.active and t.get_tree().root.find_child("FlashbackLayer", true, false) == null, "ya sin el tratamiento de recuerdo")
	var c := SaveSlots.contract(agent)
	t.check(bool(c.get("firmado", false)) and bool(c.get("leido", false)), "la partida principal guarda el contrato firmado y leído %s" % str(c))
	t.check(not SaveSlots.needs_training(agent) and SaveSlots.exists(agent), "la partida existe: no se pide otro Training")
	t.check(Difficulty.level == Difficulty.Level.NORMAL, "con la dificultad elegida en el menú (Normal), no la Fácil del Training")
	await t.back_to_menu()
	menu = await _menu_agent(t, agent)
	t.check(menu.find_child("StartBtn", true, false) == null and menu.find_child("ContinueBtn", true, false) != null, "en el menú ya sale «Continuar»")
	bot.queue_free()


## Partidas de antes (v0.3 / v0.3.1, sin contrato): no repiten el Training y su T1/T2/T3 es Lunes/Martes/Miércoles.
func _viejas(t: Node) -> void:
	var dir := SaveSlots.dir_of("Marko")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir + "progreso.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "agente": "Marko", "turno_desbloqueado": 3, "turnos_cerrados": [1, 2], "saldo": 54.5, "mode": 0, "dificultad": "normal", "finales": [], "turnos": {}, "creada": "2026-11-05T02:00:00", "actualizada": "2026-11-06T03:00:00"}))
	f.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveSlots.dir_of("Juan")))
	var g := FileAccess.open(SaveSlots.dir_of("Juan") + "progreso.json", FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify({"version": 3, "agente": "Juan", "turno_desbloqueado": 1, "turnos_cerrados": [], "saldo": -1.0, "mode": 0, "dificultad": "facil", "finales": []}))
		g.close()
	SaveSlots.use_sandbox(SaveSlots.root.get_base_dir().get_base_dir())  # vacía la caché: se lee del disco
	t.check(not SaveSlots.needs_training("Marko") and not SaveSlots.needs_training("Juan"), "las partidas viejas no piden el Training")
	t.check(SaveSlots.contract("Marko").is_empty(), "(y no inventan un contrato)")
	t.check(SaveSlots.frontier("Marko") == 3 and SaveSlots.snapshots("Marko").size() == 3, "la partida v4 sigue en su T3 con sus instantáneas")
	t.check(SaveSlots.summary_text("Marko").contains("Miércoles 28 de octubre"), "el resumen dice el día: %s" % SaveSlots.summary_text("Marko"))
	t.check(SaveSlots.summary_text("Juan").contains("Lunes 26 de octubre"), "el T1 de antes es el Lunes: %s" % SaveSlots.summary_text("Juan"))
	var menu := await _menu_agent(t, "Marko")
	var cont := menu.find_child("ContinueBtn", true, false) as Button
	t.check(cont != null and cont.text == "Continuar · Miércoles", "el botón dice «%s»" % (cont.text if cont != null else "?"))
	cont.emit_signal("pressed")
	await t.frames(6)
	t.check(GameState.turno == 3 and GameState.agent == "Marko" and not GameState.is_tutorial() and t.main.find_child("Tutorial", true, false) == null, "Continuar abre el Miércoles directo, sin Training")
	await t.back_to_menu()
	menu = await _menu_agent(t, "Juan")
	var c2 := menu.find_child("ContinueBtn", true, false) as Button
	t.check(c2 != null and c2.text == "Continuar · Lunes", "Juan: «%s»" % (c2.text if c2 != null else "?"))
	c2.emit_signal("pressed")
	await t.frames(6)
	t.check(GameState.turno == 1 and not GameState.is_tutorial(), "y su T1 de la v0.3 es el Lunes")
	await t.back_to_menu()


func _etiquetas(t: Node) -> void:
	var week := Days.week()
	t.check(week.size() == 8, "datos de la semana: el recuerdo + 6 noches + el domingo (%d)" % week.size())
	var names := []
	for d in week:
		names.append(str(d["nombre"]))
	t.check(names == ["Training", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"], "nombres %s" % str(names))
	t.check(Days.full(1) == "Lunes 26 de octubre" and Days.full(6) == "Sábado 31 de octubre" and Days.full(7) == "Domingo 1 de noviembre" and Days.short(3) == "MIÉ 28 OCT", "fechas: %s · %s · %s" % [Days.full(1), Days.full(6), Days.short(3)])
	t.check(GameState.turno_available(1) and GameState.turno_available(3) and not GameState.turno_available(4) and not GameState.turno_available(7), "lunes a miércoles se juegan; jueves a domingo esperan a la v0.4")
	t.check(bool(GameState.turno_data(7).get("descanso", false)) and str(GameState.turno_data(6).get("congela_contadores", "")) == "05:59", "el domingo es descanso y el sábado congela los contadores a las 05:59")
	for a in GameState.AGENTS:
		t.check(Flashback.date_text(a) != "" and Flashback.later_text(a).ends_with("después") and Flashback.inner_lines(a).size() >= 2, "%s: recuerdo %s · %s" % [a, Flashback.date_text(a), Flashback.later_text(a)])
	var cin: Dictionary = DataLoader.dict("cinematicas").get("cinematicas", {})
	t.check(Loc.pick((cin.get("intro_t1", {}) as Dictionary).get("titulo", {})).begins_with("Lunes 26 de octubre"), "la cinemática del T1 dice «Lunes 26 de octubre»")
	t.check(Loc.pick((cin.get("t2_capacitacion", {}) as Dictionary).get("titulo", {})).contains("Actualización de campaña"), "la del T2: «Actualización de campaña»")
	await t.start_shift("Llauri", 2)
	await t.frames(3)
	var hud: Node = t.main.get("hud")
	t.check(str(hud.call("_clock_label")).begins_with("MAR 27 OCT · "), "HUD: %s" % str(hud.call("_clock_label")))
	Loc.set_language("en")
	await t.frames(2)
	t.check(str(hud.call("_clock_label")).begins_with("TUE OCT 27 · ") and Days.full(2) == "Tuesday, October 27", "en inglés: %s · %s" % [str(hud.call("_clock_label")), Days.full(2)])
	t.check(Loc.tr("MENU_TUTORIAL").begins_with("Training") and Loc.tr("MENU_PICK_TURN") == "Choose day", "menú EN: %s · %s" % [Loc.tr("MENU_TUTORIAL"), Loc.tr("MENU_PICK_TURN")])
	Loc.set_language("es")
	t.check(Loc.tr("MENU_TUTORIAL").begins_with("Training") and Loc.tr("MENU_PICK_TURN") == "Elegir día" and not Loc.tr("TUTM_TITLE").contains("nducci"), "menú ES: %s · %s" % [Loc.tr("MENU_TUTORIAL"), Loc.tr("MENU_PICK_TURN")])
	# Cambiar de idioma con el contrato sobre la mesa: el papel se reescribe y conserva la firma a medio hacer.
	var cui := ContractUI.new()
	cui.agent = "Jiroshi"
	cui.date_text = Flashback.date_text("Jiroshi")
	t.get_tree().root.add_child(cui)
	await t.frames(3)
	cui.strokes.append(PackedVector2Array([Vector2(80, 60), Vector2(200, 90), Vector2(320, 50)]))
	var title_es := (cui.find_child("Titulo", true, false) as Label).text
	Loc.set_language("en")
	await t.frames(4)
	var tl := cui.find_child("Titulo", true, false) as Label
	var c1 := cui.find_child("Clausula1", true, false) as Label
	t.check(tl != null and tl.text == str((ContractUI.data().get("titulo", {}) as Dictionary).get("en", "")) and tl.text != title_es and c1 != null and c1.text.begins_with("Clause 1."), "con el contrato abierto, cambiar a inglés lo reescribe (%s)" % (tl.text if tl != null else "?"))
	t.check(cui.strokes.size() == 1 and not (cui.find_child("FirmarBtn", true, false) as Button).disabled, "y conserva la firma a medio hacer (%d trazo, «Firmar» habilitado)" % cui.strokes.size())
	Loc.set_language("es")
	await t.frames(4)
	t.check((cui.find_child("Titulo", true, false) as Label).text == title_es, "y de vuelta al español")
	cui.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await t.back_to_menu()


## En los turnos: el anuncio es «Actualización de campaña» y el Trainer del piso 1 tiene la cara real.
func _actualizacion(t: Node) -> void:
	var posts: Array = t.spy("ezlak_post")
	await t.start_shift("Ttoom", 2)
	await t.login_at_seat()
	await t.advance_clock(20.0 * 60.0)
	var anuncio := ""
	for p in posts:
		if str(p[1]) == "trainer" and str(p[0]) == "#site-updates":
			anuncio = str(p[2])
	t.check(anuncio.begins_with("Actualización de campaña"), "anuncio: «%s»" % anuncio)
	t.building().go_to_floor(1, "ascensor")
	await t.frames(4)
	var tr_: Node = t.building().floor_node.find_child("Trainer", true, false)
	t.check(tr_ != null and bool(tr_.call("is_terror_face")), "en los turnos el Trainer tiene su cara de terror")
	t.check(t.building().floor_node.find_child("TrainerAmable", true, false) == null and t.building().floor_node.find_child("Cub_T-01", true, false) == null, "ni el Trainer amable ni la PC de training (eso es del recuerdo)")
	t.check(not Flashback.active, "sin tratamiento de recuerdo")
	await t.back_to_menu()


## Rejugar el Training desde el menú (un tema suelto y la firma): no toca la partida y vuelve al menú.
func _replay(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	await t.back_to_menu()
	var before := FileAccess.get_file_as_string(SaveSlots.main_progress_path("Llauri"))
	SaveSlots.select("Llauri")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", OS.get_environment("T2_LOG_STEPS") != "")
	bot.set("read_contract", false)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("start", t.main, ["ezlak", Tutorial.CONTRACT_MODULE], [])
	await t.until(func() -> bool: return not out.is_empty(), 200.0)
	await t.frames(5)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("modulos", {}) as Dictionary).get(Tutorial.CONTRACT_MODULE, "") == "hecho" and (r.get("errores", []) as Array).is_empty(), "Ezlaki y la firma rejugados %s" % str(r))
	t.check(not GameState.running and t.main.get("main_menu").visible, "vuelve al menú (no abre el Lunes)")
	t.check(FileAccess.get_file_as_string(SaveSlots.main_progress_path("Llauri")) == before, "la partida de Llauri no cambió")
	bot.queue_free()



# --- media para Joan ---------------------------------------------------------------------------------

func _shot(t: Node, name: String) -> void:
	var dir := OS.get_environment("T2_SHOTS")
	if dir == "":
		dir = ProjectSettings.globalize_path("user://shots_v032")
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var img := t.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(dir.path_join(name + ".png"))
		t.note("captura %s" % name)


## Una línea a la vez: el guion de la bienvenida (Trainer, compañeros, monólogo) y la llamada perdida de práctica.
func _voces(t: Node) -> void:
	SaveSlots.select("Marko")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("timeout_s", 300.0)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	var started: Array = []
	bot.call("start", t.main, ["llegada", "metricas", "contrato"], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var tv: TrainingVoice = tut.get("voice") if tut != null else null
	t.check(tv != null, "el Training habla por TrainingVoice")
	if tv == null:
		return
	tv.line_started.connect(func(id: String, _x: String) -> void: started.append([id, tv.speaking]))
	var dup := [0]
	var spy := func(_sp: String, _tx: String, _s: float) -> void:
		if VoiceDirector.voices_playing() > 1:
			dup[0] += 1
	VoiceDirector.subtitle_shown.connect(spy)
	await t.until(func() -> bool: return not out.is_empty(), 300.0)
	VoiceDirector.subtitle_shown.disconnect(spy)
	t.check(tv.director_overlaps == 0, "el VoiceDirector no registró solapes durante el Training (%d)" % tv.director_overlaps)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("errores", []) as Array).is_empty(), "el bot hizo bienvenida, métricas y firma sin errores %s" % str(r.get("errores", [])))
	t.check(tv.spoken.has("t_hola") and tv.spoken.has("t_nombre") and tv.spoken.has("promo:hola_nayra") and tv.spoken.has("piensa:0"), "hablan el Trainer, la promoción y el monólogo (%d líneas)" % tv.spoken.size())
	t.check(tv.spoken.has("t_perdido_ok") and not tv.spoken.has("t_perdido_contestaste"), "la llamada de práctica se dejó sonar: el Trainer explica el contacto perdido")
	t.check(tv.overlaps().is_empty(), "ninguna línea se pisa con otra (%d cruces)" % tv.overlaps().size())
	t.check(dup[0] == 0, "nunca hay dos voces sonando cuando sale un subtítulo (%d)" % dup[0])
	var q: Dictionary = tut.get("quiz") if is_instance_valid(tut) else {}
	t.check(bool(q.get("llegada", false)) and bool(q.get("metricas", false)), "los mini-checks puntúan %s" % str(q))
	t.check(bool(tut.get("photo_taken")) if is_instance_valid(tut) else false, "la foto de promoción se tomó")
	bot.queue_free()


## El comodín en el Training: el sistema real (Comodin), con tu promoción al teléfono.
func _comodin(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.back_to_menu()
	var usos_antes := int(SaveSlots.main_progress("Marko").get("comodin_usos", 0))
	SaveSlots.select("Marko")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("timeout_s", 300.0)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	var answered: Array = []
	var state: Array = []  # [de pie, fuera del aula, AUX antes] cuando contestan
	var shero_dm := [0]
	var on_post := func(ch: String, _a: String, _tx: String, meta: Dictionary) -> void:
		if str(meta.get("tipo", "")) == "comodin":
			shero_dm[0] += 1
			t.note("post de comodín en %s" % ch)
	EventBus.ezlak_post.connect(on_post)
	var on_call := func(who: String) -> void: state.append([GameState.seated_at == "", Metrics.aux, Discipline.at_pc()])
	var on_ans := func(who: String, aux: int) -> void: answered.append([who, aux])
	Comodin.call_started.connect(on_call)
	Comodin.call_answered.connect(on_ans)
	bot.call("start", t.main, ["salir"], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var tv: TrainingVoice = tut.get("voice") if tut != null else null
	t.check(Comodin.practice_names == (Flashback.classmates() as Array) and Comodin.coworkers().has("Nayra") and not Comodin.coworkers().has("Jiroshi"), "en el recuerdo el comodín llama a tu promoción %s" % str(Comodin.coworkers()))
	await t.until(func() -> bool: return not out.is_empty(), 300.0)
	EventBus.ezlak_post.disconnect(on_post)
	Comodin.call_started.disconnect(on_call)
	Comodin.call_answered.disconnect(on_ans)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("errores", []) as Array).is_empty() and str((r.get("modulos", {}) as Dictionary).get("salir", "")) == "hecho", "el módulo de breaks se completa %s" % str(r.get("errores", [])))
	t.check(answered.size() == 1 and str(answered[0][0]) == "Nayra" and int(answered[0][1]) == Metrics.Aux.AVAILABLE, "llamaste a Nayra y te marcó Available %s" % str(answered))
	t.check(state.size() == 1 and bool(state[0][0]) and int(state[0][1]) == Metrics.Aux.BREAK and not bool(state[0][2]), "de pie, lejos de la PC y con el Break puesto: ahí el AUX solo cambia con el comodín %s" % str(state))
	t.check(tv != null and tv.spoken.has("t_comodin_1") and tv.spoken.has("t_comodin_2"), "el Trainer lo presenta y lo cierra («para eso están los amigos»)")
	t.check(tv != null and tv.spoken.has("comodin:Nayra"), "y Nayra te contesta con su voz, por el teléfono %s" % (str(tv.spoken) if tv != null else ""))
	t.check(shero_dm[0] == 0, "Shero no se entera y nadie manda DM (%d)" % shero_dm[0])
	await t.frames(5)
	t.check(int(SaveSlots.main_progress("Marko").get("comodin_usos", 0)) == usos_antes, "no cuenta para la partida (comodin_usos %d)" % int(SaveSlots.main_progress("Marko").get("comodin_usos", 0)))
	if is_instance_valid(tut) and not bool(tut.get("finished")):
		await t.until(func() -> bool: return not is_instance_valid(tut) or bool(tut.get("finished")), 20.0)
	if is_instance_valid(tut):
		tut.call("press_continue")
	await t.until(func() -> bool: return not GameState.running, 10.0)
	bot.queue_free()
	await t.start_shift("Marko", 1)
	t.check(Comodin.practice_names.is_empty() and not Comodin.answer_override.is_valid() and Comodin.coworkers().has("Jiroshi") and not Comodin.used, "en el Lunes el comodín vuelve a ser el de verdad: llama a los agentes y está disponible")


## Ecos del recuerdo en la semana: la polaroid en C-14 y el primer café de la expendedora.
func _ecos(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.frames(3)
	t.building().go_to_floor(2, "ascensor")
	await t.frames(6)
	var fl: Node3D = t.building().floor_node
	var cub := fl.find_child("Cub_C-14", true, false)
	var pol := fl.find_child("PolaroidPromocion", true, false) as Node3D
	t.check(pol != null and cub != null and cub.is_ancestor_of(pol), "la polaroid de tu promoción está en tu mesa, en C-14")
	var said: Array = []
	var on_line := func(lid: String, sp: String, _pr: int) -> void:
		if sp == "piensa":
			said.append(lid)
	var subs: Array = []
	var on_sub := func(sp: String, tx: String, _s: float) -> void:
		if sp == "piensa":
			subs.append(tx)
	VoiceDirector.line_started.connect(on_line)
	VoiceDirector.subtitle_shown.connect(on_sub)
	var seat := (fl as FloorBase).seat_by_id("C-14")
	t.player().sit_at(seat, "C-14")
	await t.until(func() -> bool: return said.has("voces/agentes/jiroshi_eco_foto"), 30.0)
	t.check(said.has("voces/agentes/jiroshi_eco_foto"), "al sentarte, tu agente piensa en la foto, con su voz %s" % str(said))
	t.check(not subs.is_empty() and str(subs[0]).contains("25 de agosto de 2023") and str(subs[0]).contains("Éramos cinco") and not str(subs[0]).contains("Nayra"), "corto, para que quepa antes de la primera llamada: «%s»" % (str(subs[0]) if not subs.is_empty() else ""))
	var longest := 0.0
	for ag in GameState.AGENTS:
		for pre in ["voces/agentes/", "voces/agentes/en/"]:
			var vp := AudioManager.resolve(pre + str(ag).to_lower() + "_eco_foto")
			var st := load(vp) as AudioStream if vp != "" else null
			longest = maxf(longest, st.get_length() if st != null else 99.0)
	t.check(longest <= 5.5, "ese pensamiento dura como mucho 5,5 s con cualquier agente, en ES y EN (el más largo: %.1f s)" % longest)
	# Un eco cuenta como dicho solo si sonó al menos la mitad (si no, lo vuelve a intentar).
	var fake := _FakeLine.new()
	fake.result = "interrumpida"
	fake.started_ms = VoiceDirector.now_ms() - 600
	fake.wall_end_ms = VoiceDirector.now_ms() + 3400
	var cut_early := RecuerdosSemana._heard(fake)
	fake.started_ms = VoiceDirector.now_ms() - 3000
	fake.wall_end_ms = VoiceDirector.now_ms() + 1000
	var cut_late := RecuerdosSemana._heard(fake)
	fake.result = "vencida"
	var expired := RecuerdosSemana._heard(fake)
	fake.result = "dicha"
	t.check(not cut_early and cut_late and not expired and RecuerdosSemana._heard(fake) and not RecuerdosSemana._heard(null), "cortado a las dos palabras no cuenta; cortado después de la mitad, sí; vencido, no (%s %s %s)" % [str(cut_early), str(cut_late), str(expired)])
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_foto", false)), 240.0)  # la voz dura ~10 s reales
	t.check(bool(RecuerdosSemana.record().get("eco_foto", false)), "queda anotado en la partida: suena una vez")
	said.clear()
	t.player().stand_up()
	await t.frames(3)
	t.player().sit_at(seat, "C-14")
	await t.seconds(4.0)
	t.check(said.is_empty(), "al volver a sentarte no lo repite %s" % str(said))
	var area := pol.find_child("PolaroidArea", true, false) as Interactable if pol != null else null
	t.player().stand_up()
	await t.frames(2)
	if area != null:
		area.interact(t.player())
	await t.frames(3)
	t.check(t.get_tree().root.get_node_or_null("EcoFoto") != null, "[E] sobre la polaroid la muestra de cerca")
	await t.until(func() -> bool: return said.has("voces/agentes/jiroshi_eco_foto_cerca"), 20.0)
	t.check(said.has("voces/agentes/jiroshi_eco_foto_cerca") and not subs.is_empty() and str(subs[-1]).contains("Nayra duró tres meses"), "y mirándola piensa en lo que fue de cada uno: «%s»" % (str(subs[-1]) if not subs.is_empty() else ""))
	await t.until(func() -> bool: return not VoiceDirector.busy(1), 240.0)
	said.clear()
	EventBus.shop_bought.emit("expendedora", "energetica", 4.5)
	await t.seconds(1.0)
	t.check(said.is_empty(), "una energética no dice nada")
	EventBus.shop_bought.emit("expendedora", "cafe", 2.5)
	await t.until(func() -> bool: return said.has("voces/agentes/jiroshi_eco_cafe"), 20.0)
	t.check(said.has("voces/agentes/jiroshi_eco_cafe"), "el primer café que pagas: «Cortesía de la empresa», decía el Trainer")
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_cafe", false)), 240.0)
	said.clear()
	EventBus.shop_bought.emit("expendedora", "cafe", 2.5)
	await t.seconds(2.0)
	t.check(said.is_empty(), "el segundo café ya no")
	# El comodín de hoy: la primera vez, te acuerdas de a quién llamabas.
	await t.until(func() -> bool: return not VoiceDirector.busy(1), 240.0)
	said.clear()
	Comodin.call_started.emit("Marko")
	await t.until(func() -> bool: return said.has("voces/agentes/jiroshi_eco_comodin"), 20.0)
	t.check(said.has("voces/agentes/jiroshi_eco_comodin"), "el primer comodín de la partida: «Antes llamaba a Nayra»")
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_comodin", false)), 240.0)
	# El Trainer de hoy te suelta de la Actualización con la frase del recuerdo.
	var trainer_said: Array = []
	var on_tr := func(lid: String, sp: String, _pr: int) -> void:
		if sp == "trainer":
			trainer_said.append(lid)
	VoiceDirector.line_started.connect(on_tr)
	EventBus.training_ended.emit(true)
	await t.until(func() -> bool: return trainer_said.has("voces/trainer/eco_vuelve"), 30.0)
	t.check(trainer_said.has("voces/trainer/eco_vuelve"), "al soltarte de la Actualización, el Trainer de hoy: «Aquí siempre se vuelve. Siempre.» %s" % str(trainer_said))
	t.check(AudioManager.resolve("voces/trainer/eco_vuelve") != "" and AudioManager.resolve("voces/trainer/en/eco_vuelve") != "", "con su voz en ES y EN")
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_trainer", false)), 240.0)
	VoiceDirector.line_started.disconnect(on_tr)
	VoiceDirector.line_started.disconnect(on_line)
	VoiceDirector.subtitle_shown.disconnect(on_sub)
	t.check(VoiceDirector.overlaps == 0, "sin solapes de voces (%d)" % VoiceDirector.overlaps)
	# La foto cambia con los días (si existen las copias que se sacaron el día de la foto).
	var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
	for k in [1, 2, 3]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RecuerdosSemana.photo_path("Jiroshi", k).get_base_dir()))
		img.save_jpg(RecuerdosSemana.photo_path("Jiroshi", k))
	t.check(RecuerdosSemana.photo_variant("Jiroshi") == 1, "lunes: la foto entera (%d)" % RecuerdosSemana.photo_variant("Jiroshi"))
	# La letra chica: la desconexión cita la cláusula del contrato (aquí, firmado SIN leer).
	SaveSlots.sign_contract("Jiroshi", false)
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(20.0)
	await t.frames(3)
	var cl := t.death_screen().get_node_or_null("ClausulaContrato") as Label
	t.check(cl != null and cl.text.contains(RecuerdosSemana.contract_number("Jiroshi")) and cl.text.contains("4") and cl.text.contains(Loc.tr("ECO_CLAUSULA_SIN_LEER").get_slice(". ", 1).left(12)), "la desconexión cita la cláusula 4 del contrato que firmaste sin leer: «%s»" % (cl.text if cl != null else ""))
	t.check(RecuerdosSemana.clause_for("tercer_ww") == 11 and RecuerdosSemana.clause_for("colapso") == 3 and RecuerdosSemana.clause_for("no_existe") == 15 and RecuerdosSemana.clause_text(11).contains("3"), "cada muerte tiene su cláusula (las demás, la 15: se renueva cada domingo)")
	var known := true
	for m in DataLoader.list("muertes"):
		if RecuerdosSemana.clause_text(RecuerdosSemana.clause_for(str((m as Dictionary).get("id", "")))) == "":
			known = false
	t.check(known, "todas las causas de muertes.json citan una cláusula que existe en contrato.json")
	await t.reconnect()
	await t.frames(3)
	t.check(t.death_screen().get_node_or_null("ClausulaContrato") == null, "al reconectar el rótulo se va con la pantalla")
	# El martes: el contrato clavado en el aula, con tu firma, y la foto ya sin Zuly. (Leído: la cláusula entera.)
	await t.back_to_menu()
	SaveSlots.sign_contract("Jiroshi", true)
	SaveSlots.use_main()
	var p := SaveSlots.progress("Jiroshi")
	var rec: Dictionary = p.get("recuerdo", {}) if p.get("recuerdo", {}) is Dictionary else {}
	rec["firma"] = [[0.0, 0.2, 0.3, 0.0, 0.6, 0.25, 1.0, 0.1]]
	p["recuerdo"] = rec
	SaveSlots.save("Jiroshi")
	await t.start_shift("Jiroshi", 2)
	await t.frames(3)
	t.check(RecuerdosSemana.photo_variant("Jiroshi") == 2, "martes: la copia en la que ya no sale Zuly (%d)" % RecuerdosSemana.photo_variant("Jiroshi"))
	t.check(RecuerdosSemana.clause_line("Jiroshi", "abandono").contains(RecuerdosSemana.clause_text(4)), "con el contrato leído, la desconexión cita la cláusula entera")
	t.building().go_to_floor(1, "ascensor")
	await t.frames(6)
	var f1: Node3D = t.building().floor_node
	var paper := f1.find_child("ContratoFirmado", true, false) as Node3D
	t.check(paper != null and paper.find_child("Firma", true, false) != null, "desde el martes tu contrato está clavado junto a la puerta del aula de training, con tu firma")
	t.check(RecuerdosSemana.signature_points(rec["firma"], Rect2(0, 0, 100, 40)).size() == 1 and (RecuerdosSemana.signature_points([], Rect2(0, 0, 100, 40))[0] as PackedVector2Array).size() > 10, "la firma se dibuja con tus trazos (o un garabato en las partidas de antes)")
	var said2: Array = []
	var on_line2 := func(lid: String, sp: String, _pr: int) -> void:
		if sp == "piensa":
			said2.append(lid)
	VoiceDirector.line_started.connect(on_line2)
	var ca := paper.find_child("ContratoArea", true, false) as Interactable if paper != null else null
	if ca != null:
		ca.interact(t.player())
	await t.frames(3)
	t.check(t.get_tree().root.get_node_or_null("EcoContrato") != null, "[E] sobre el contrato lo muestra de cerca (con la letra chica)")
	await t.until(func() -> bool: return said2.has("voces/agentes/jiroshi_eco_firma"), 20.0)
	t.check(said2.has("voces/agentes/jiroshi_eco_firma"), "«Mi firma. La hice sonriendo.» %s" % str(said2))
	await t.until(func() -> bool: return not VoiceDirector.busy(1), 240.0)
	# El mural de promociones («una copia va al mural del piso uno»): casi todas borradas; la tuya, con la copia de hoy.
	var mural := f1.find_child("MuralPromociones", true, false) as Node3D
	var slots := mural.find_children("Promo*", "Node3D", true, false) if mural != null else []
	var mine := (slots[RecuerdosSemana.MURAL_MINE] as Node3D).find_child("Foto", true, false) as MeshInstance3D if slots.size() == 24 else null
	t.check(mural != null and slots.size() == 24 and mine != null and (mine.material_override as StandardMaterial3D).albedo_texture != null, "en el aula de hoy está el mural de promociones: 24 fotos, casi todas borradas, y la tuya (%d)" % slots.size())
	said2.clear()
	var ma := mural.find_child("MuralArea", true, false) as Interactable if mural != null else null
	if ma != null:
		ma.interact(t.player())
	await t.frames(3)
	t.check(t.get_tree().root.get_node_or_null("EcoFoto") != null, "[E] sobre el mural muestra tu foto de cerca")
	await t.until(func() -> bool: return said2.has("voces/agentes/jiroshi_eco_foto_2"), 20.0)
	t.check(said2.has("voces/agentes/jiroshi_eco_foto_2"), "y tu agente nota quién falta, igual que en su mesa %s" % str(said2))
	await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("EcoFoto") == null and not VoiceDirector.busy(1), 240.0)
	# y la polaroid del martes, de cerca: nota quién falta
	t.building().go_to_floor(2, "ascensor")
	await t.frames(6)
	said2.clear()
	var pol2 := t.building().floor_node.find_child("PolaroidArea", true, false) as Interactable
	if pol2 != null:
		pol2.interact(t.player())
	await t.until(func() -> bool: return said2.has("voces/agentes/jiroshi_eco_foto_2"), 20.0)
	t.check(said2.has("voces/agentes/jiroshi_eco_foto_2"), "martes, mirando la foto: «Zuly salía aquí, a la izquierda. Lo sé. ¿Lo sé?» %s" % str(said2))
	VoiceDirector.line_started.disconnect(on_line2)


## El aula viva: escenas, reacciones, tu nombre, el brindis, y nada del presente.
func _aula(t: Node) -> void:
	SaveSlots.select("Llauri")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("stop_at", "llegada/cafe")
	bot.set("timeout_s", 300.0)
	t.add_child(bot)
	bot.call("start", t.main, ["llegada"], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var first: Dictionary = {}  # cómo está el aula en el primer paso (antes de que nadie hable)
	tut.connect("step_started", func(_m: String, _s: String) -> void:
		var sg: TrainingStage = tut.get("stage")
		if not first.is_empty() or sg == null or not sg.ready_on_floor():
			return
		first["escena"] = sg.scene
		first["trainer"] = sg.trainer.mode()
		first["de_pie"] = 0
		for i in sg.promo.size():
			if not sg.promo[i].seated and sg.promo[i].position.distance_to(TrainingRoom.CLASS[i]["cafe"]) < 0.3:
				first["de_pie"] = int(first["de_pie"]) + 1)
	await t.until(func() -> bool: return bool(bot.get("stopped")), 60.0)
	await t.frames(4)
	var st: TrainingStage = tut.get("stage")
	var tr_: TrainerAmable = tut.get("trainer")
	var fl: Node3D = t.building().floor_node
	t.check(st != null and st.ready_on_floor() and st.promo.size() == 4, "la promoción son cuatro, con el Trainer, en el piso 1")
	if st == null or st.promo.size() != 4:
		return
	var names: Array = []
	var civil := 0
	var gestures := 0
	for a in st.promo:
		names.append(a.who)
		if ResourceLoader.exists("res://assets/textures/promo_%s.jpg" % a.who.to_lower()):
			civil += 1
		if a.has_gesture("laugh_sit") and a.has_gesture("hand_up") and a.has_gesture("clap_sit") and a.has_gesture("cup") and a.has_gesture("pose_a"):
			gestures += 1
	t.check(names == ["Nayra", "Yimi", "Zuly", "Kenyi"] and names == (Flashback.classmates() as Array), "con nombre: %s" % str(names))
	t.check(civil == 4, "cada uno con su ropa de civil (assets/textures/promo_<nombre>.jpg: %d de 4)" % civil)
	t.check(gestures == 4 and tr_.has_gesture("welcome") and tr_.has_gesture("handshake") and tr_.has_gesture("camera"), "con los gestos del Training (reír, aplaudir, levantar la mano, la taza, posar: %d de 4; el Trainer da la bienvenida, la mano y pone la cámara)" % gestures)
	# Llegas y el aula está de pie, alrededor del café; el Trainer te recibe en la puerta.
	t.check(str(first.get("escena", "")) == "cafe" and int(first.get("de_pie", 0)) == 4 and str(first.get("trainer", "")) == "puerta", "al llegar: la promoción de pie en el café (%d de 4) y el Trainer en la puerta (%s)" % [int(first.get("de_pie", 0)), str(first.get("trainer", "?"))])
	t.check(st.cue_log.has("va:cafe") and tr_.mode() == "cafe", "te invita al café («ahí, con tus compañeros») y va él también (%s)" % tr_.mode())
	var card := fl.find_child(TrainingRoom.NAME_CARD, true, false) as Node3D
	t.check(card != null and not card.visible, "tu mesa todavía no tiene cartel: el Trainer no sabe cómo te llamas")
	# Nada del presente.
	var amb := fl.find_child("Inquietud", true, false)
	var mood := fl.find_child("Animo", true, false)
	t.check(amb != null and not amb.is_processing() and mood != null and not mood.is_processing(), "el ambiente de hoy (parlantes, susurros, apagones) está apagado en el recuerdo")
	var mentor_posts: Array = []
	var on_post := func(_ch: String, author: String, _tx: String, meta: Dictionary) -> void:
		if author == "mentor" and str(meta.get("tipo", "")) != "induccion":
			mentor_posts.append(str(meta.get("tipo", "?")))
	EventBus.ezlak_post.connect(on_post)
	var was_logged := GameState.logged_in
	GameState.logged_in = true
	var mentor_node := t.get_tree().root.find_child("Mentor", true, false)
	if mentor_node != null:
		mentor_node.call("_on_clock", GameState.hhmm_to_seconds("07:30"))  # pasan las horas de las listas y los minitrainings de hoy
	GameState.logged_in = was_logged
	EventBus.ezlak_post.disconnect(on_post)
	t.check(mentor_node != null and mentor_posts.is_empty(), "el Mentor de hoy no publica nada en el recuerdo (ni minitrainings ni listas) %s" % str(mentor_posts))
	var topico := fl.find_child("Topico", true, false) as Interactable
	t.check(topico == null or not topico.enabled, "la puerta del tópico no ofrece nada (su cartel de hoy no existe en el recuerdo)")
	var banner := fl.find_child("CartelBienvenida", true, false)
	var bl := banner.find_children("*", "Label3D", true, false) if banner != null else []
	t.check(not bl.is_empty() and (bl[0] as Label3D).alpha_cut == Label3D.ALPHA_CUT_OPAQUE_PREPASS, "los rótulos del aula escriben profundidad (nunca se dibujan sobre una cabeza)")
	# La clase sentada en la herradura.
	st.set_scene("clase", true)
	await t.seconds(0.6)
	var seated := 0
	for i in st.promo.size():
		var a3 := st.promo[i]
		if a3.seated and a3.position.distance_to(TrainingRoom.CLASS[i]["silla"]) < 0.05 and a3.rig.animator.current_state() == "seated":
			seated += 1
	t.check(seated == 4, "en clase: cada uno sentado en su silla de la herradura (%d de 4)" % seated)
	# Ríen… y siguen sentados (los gestos son clips de otra biblioteca: al terminar no quedan de pie).
	st.cue("risa")
	await t.seconds(0.6)
	var laughing := 0
	for a4 in st.promo:
		if a4.busy_gesture == "laugh_sit":
			laughing += 1
	t.check(laughing == 4, "«risa»: los cuatro se ríen (%d)" % laughing)
	await t.until(func() -> bool:
		for a5 in st.promo:
			if a5.busy_gesture != "":
				return false
		return true, 12.0)
	await t.seconds(0.8)
	seated = 0
	for a6 in st.promo:
		if a6.seated and a6.rig.animator.current_state() == "seated":
			seated += 1
	t.check(seated == 4, "después de reírse siguen sentados (%d de 4 en el estado «seated» del animador)" % seated)
	st.cue("mano:Nayra")
	st.cue("aplauso")
	await t.seconds(0.6)
	t.check(st.actor("Nayra").busy_gesture in ["hand_up", "clap_sit"] and st.actor("Yimi").busy_gesture == "clap_sit", "levantan la mano y aplauden (%s · %s)" % [st.actor("Nayra").busy_gesture, st.actor("Yimi").busy_gesture])
	# Tu nombre.
	st.cue("nombre")
	await t.frames(2)
	var lbl := card.find_children("*", "Label3D", true, false) if card != null else []
	t.check(card != null and card.visible and lbl.size() == 2 and (lbl[0] as Label3D).text == "LLAURI", "le dices tu nombre y queda en un cartelito sobre tu mesa, de los dos lados (%s)" % ((lbl[0] as Label3D).text if not lbl.is_empty() else "?"))
	# El brindis del coffee break.
	st.step_start({"id": "brindis", "tipo": "esperar", "cond": "cafe"}, "cafe")
	var table := fl.find_child("MesaCafe", true, false) as Interactable
	t.check(table != null and bool(table.get("toast")) and table.hint_text() == Loc.tr("HUD_TRAINING_BRINDIS"), "en el brindis la mesa del café dice «%s»" % (table.hint_text() if table != null else "?"))
	st.step_start({"id": "cafe", "tipo": "esperar", "cond": "cafe"}, "cafe")
	t.check(table != null and not bool(table.get("toast")), "y en los demás pasos, servirte café")
	# El Trainer va a cada sitio sin atravesar la herradura (llega y te mira).
	tr_.place("puerta")
	tr_.go("cafe")
	await t.until(func() -> bool: return not tr_.is_walking(), 40.0)
	t.check(tr_.mode() == "cafe" and tr_.position.distance_to(TrainingRoom.SPOTS["cafe"]) < 0.1, "de la puerta a la isla del café, por el pasillo del fondo (%.1f, %.1f)" % [tr_.position.x, tr_.position.z])
	# Cambiar de idioma con el Training abierto reescribe el panel sin reiniciar el paso (y vuelve).
	var body_lbl := tut.get("_body") as Label
	var title_lbl := tut.get("_title") as Label
	var body_es := body_lbl.text
	var title_es := title_lbl.text
	Loc.set_language("en")
	await t.frames(3)
	var step_en := Loc.pick((tut.call("step") as Dictionary).get("texto", {}))
	t.check(body_lbl.text != body_es and body_lbl.text.left(24) == step_en.left(24) and title_lbl.text != title_es and title_lbl.text.contains("Welcome to the family"), "en inglés a mitad del paso: «%s» · «%s»" % [title_lbl.text, body_lbl.text.left(40)])
	Loc.set_language("es")
	await t.frames(3)
	t.check(body_lbl.text == body_es and title_lbl.text == title_es, "y de vuelta al español queda como estaba")
	# El reloj del recuerdo: de mañana, el mismo en el HUD y en la PC; cada módulo a su hora y nunca hacia atrás.
	var hud := t.main.get("hud") as Node
	var h0 := GameState.clock_text()
	t.check(h0.ends_with("AM") and (h0.begins_with("8:") or h0.begins_with("9:")) and str(hud.call("_clock_label")).ends_with(h0), "en la bienvenida son las %s en el HUD y en la PC (%s)" % [h0, str(hud.call("_clock_label"))])
	tut.call("_memory_hour", "17:00")
	var h1 := GameState.clock_text()
	t.check(h1.begins_with("5:0") and h1.ends_with("PM"), "la firma es a las 17:00 (%s)" % h1)
	var shown := GameState.clock_seconds + GameState.clock_shift
	tut.call("_set_clock", GameState.clock_seconds - 900.0)
	tut.call("_memory_hour", "09:15")
	t.check(is_equal_approx(GameState.clock_seconds + GameState.clock_shift, shown), "el reloj que se ve no retrocede aunque el de juego se reajuste (%s)" % GameState.clock_text())
	# Un gesto en cola no revienta si su actor ya no existe (bajaste al -1 y el piso se recargó).
	var ghost := st.promo[3]
	st.call("_later", 0.05, Callable(st, "_gest").bind(ghost, "laugh_sit", "laugh"))
	# Fuera del aula tampoco hay nada de hoy: en el lobby del -1, ni el Halloween olvidado ni los cartones.
	t.building().go_to_floor(-1, "ascensor")
	await t.frames(8)
	var fm: Node3D = t.building().floor_node
	var seen: Array = []
	var total := 0
	for nd in fm.find_children("*", "Node3D", true, false):
		var nm := String(nd.name)
		for pre in ["Murcielago", "Bruja", "Carton", "Huella"]:
			if nm.begins_with(pre):
				total += 1
				if (nd as Node3D).is_visible_in_tree():
					seen.append(nm)
	t.check(total > 0 and seen.is_empty(), "en el -1 del recuerdo no cuelga el Halloween olvidado ni hay cartones en el piso (%d escondidos; a la vista: %s)" % [total, str(seen)])
	t.check(not Flashback.active or GameState.clock_shift > 0.0, "y sigue siendo de día")
	bot.queue_free()


## El Training obligatorio se deja a medias y se retoma; saltando todo lo que queda con [F8] igual se firma.
func _reanudar(t: Node) -> void:
	var agent := "Ttoom"
	t.check(SaveSlots.needs_training(agent) and Tutorial.first_state(agent).is_empty(), "Ttoom no tiene partida ni Training empezado")
	var menu := await _menu_agent(t, agent)
	(menu.find_child("StartBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(6)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("stop_at", "metricas/kpi")
	bot.set("timeout_s", 300.0)
	t.add_child(bot)
	bot.call("attach", t.main, tut, ["aux"])  # hace la bienvenida, salta el AUX con [F8] y se queda al empezar el tercero
	await t.until(func() -> bool: return bool(bot.get("stopped")), 120.0)
	t.check(bool(bot.get("stopped")) and str(tut.call("module_id")) == "metricas", "hizo la bienvenida, saltó «AUX» y va por el tercer módulo")
	var st1 := Tutorial.first_state(agent)
	t.check(str((st1.get("modulos", {}) as Dictionary).get("llegada", "")) == "hecho" and str((st1.get("modulos", {}) as Dictionary).get("aux", "")) == "saltado", "queda anotado por agente %s" % str(st1.get("modulos", {})))
	bot.queue_free()
	await t.back_to_menu()  # sale a mitad del Training
	t.check(SaveSlots.needs_training(agent) and not SaveSlots.exists(agent), "salir a medias no crea la partida: sigue pidiendo el Training")
	t.check(Tutorial.first_pending(agent).size() == 12 and str(Tutorial.first_pending(agent)[0]) == "metricas" and str(Tutorial.first_pending(agent)[-1]) == Tutorial.CONTRACT_MODULE, "le faltan 12, desde «métricas» hasta la firma")
	t.check(Tutorial.first_pending("Juan").size() == 14, "otro agente empieza el suyo desde el principio (14)")
	menu = await _menu_agent(t, agent)
	var start := menu.find_child("StartBtn", true, false) as Button
	t.check(start != null and start.text == Loc.fmt(Loc.tr("TS_TRAINING_RESUME"), {"n": 3, "total": 14}), "el menú dice «%s»" % (start.text if start != null else "?"))
	start.emit_signal("pressed")
	await t.frames(6)
	tut = t.main.find_child("Tutorial", true, false)
	var q: Array = tut.get("queue")
	t.check(tut != null and bool(tut.get("first_time")) and q.size() == 12 and str(q[0]) == "metricas", "al volver sigue donde quedó (%d módulos, empieza por %s)" % [q.size(), str(q[0]) if not q.is_empty() else "?"])
	t.check(bool((tut.get("quiz") as Dictionary).get("llegada", false)), "y el mini-check que ya contestó sigue contando %s" % str(tut.get("quiz")))
	await t.until(func() -> bool: return GameState.seated_at == TrainingRoom.SEAT, 30.0)
	var fl: Node3D = t.building().floor_node
	var card := fl.find_child(TrainingRoom.NAME_CARD, true, false) as Node3D
	t.check(card != null and card.visible, "el cartelito con su nombre ya está en su mesa (el Trainer ya lo conoce)")
	# Lo que queda, saltado entero con [F8]: igual llega a la firma, firma y empieza el Lunes.
	var bot2: Node = (load(BOT) as GDScript).new()
	bot2.set("log_steps", false)
	bot2.set("timeout_s", 300.0)
	t.add_child(bot2)
	var out: Array = []
	bot2.connect("done", func(r: Dictionary) -> void: out.append(r))
	var skip: Array = Tutorial.module_ids()
	skip.erase(Tutorial.CONTRACT_MODULE)
	bot2.call("attach", t.main, tut, skip)
	await t.until(func() -> bool: return not out.is_empty() or GameState.turno == 1, 300.0)
	await t.until(func() -> bool: return GameState.turno == 1 and GameState.running, 30.0)
	await t.until(func() -> bool: return not out.is_empty(), 5.0)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	var mods: Dictionary = r.get("modulos", {})
	var skipped := 0
	for id in mods.keys():
		if str(mods[id]) == "saltado":
			skipped += 1
	t.check((r.get("errores", []) as Array).is_empty() and skipped == 11 and str(mods.get(Tutorial.CONTRACT_MODULE, "")) == "hecho", "saltó los 11 que quedaban con [F8] y firmó el contrato %s %s" % [str(r.get("errores", [])), str(mods)])
	t.check(GameState.turno == 1 and not GameState.is_tutorial() and GameState.agent == agent and bool(SaveSlots.contract(agent).get("firmado", false)), "y empieza el Lunes de Ttoom con el contrato firmado")
	t.check(Tutorial.first_state(agent).is_empty() and not SaveSlots.needs_training(agent), "ya no hay Training a medias que retomar")
	bot2.queue_free()
	await t.back_to_menu()


## El guion por el VoiceDirector, de verdad (a tiempo real, con las voces): la bienvenida de Llauri. Cada línea entra al
## director con prioridad DIRECTO, con su archivo de voz y su subtítulo; nunca hay dos voces a la vez (ni en la línea
## de tiempo del guion ni en el registro del director) y [T] corta la línea en curso sin pisar la siguiente.
func _director(t: Node) -> void:
	var prev_scale := Engine.time_scale
	Engine.time_scale = 1.0
	SaveSlots.select("Llauri")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("fast_speech", false)
	bot.set("read_delay", 0.3)
	bot.set("timeout_s", 300.0)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("start", t.main, ["llegada"], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var tv: TrainingVoice = tut.get("voice") if tut != null else null
	t.check(tv != null and not tv.fast, "el Training habla por TrainingVoice, a tiempo real")
	if tv == null:
		return
	var via: Array = []  # [id de la línea en el director, prioridad, hablante]
	var subs: Array = []
	var playing_max := [0]
	var on_line := func(lid: String, sp: String, pr: int) -> void: via.append([lid, pr, sp])
	var on_sub := func(_sp: String, tx: String, _s: float) -> void:
		subs.append(tx)
		playing_max[0] = maxi(playing_max[0], VoiceDirector.voices_playing())
	VoiceDirector.line_started.connect(on_line)
	VoiceDirector.subtitle_shown.connect(on_sub)
	var cut := [false, ""]
	tv.line_started.connect(func(id: String, _x: String) -> void:
		if id == "t_que_es" and not cut[0]:
			cut[0] = true
			cut[1] = id
			await t.seconds(1.0)
			if is_instance_valid(tut):
				tut.call("press_continue"))  # [T] mientras habla: corta ESA línea
	await t.until(func() -> bool: return not out.is_empty(), 300.0)
	VoiceDirector.line_started.disconnect(on_line)
	VoiceDirector.subtitle_shown.disconnect(on_sub)
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("errores", []) as Array).is_empty(), "la bienvenida completa sin errores %s" % str(r.get("errores", [])))
	var script_lines := 0
	var with_voice := 0
	for v in via:
		var lid := str(v[0])
		if int(v[1]) == TrainingVoice.PRIORITY and (lid.begins_with("voces/trainer_amable/") or lid.begins_with("voces/promocion/") or lid.begins_with("voces/agentes/") or lid.begins_with("training/")):
			script_lines += 1
			if lid.begins_with("voces/"):
				with_voice += 1
	t.check(script_lines == tv.spoken.size() and script_lines >= 12, "cada línea del guion salió por el VoiceDirector (%d de %d)" % [script_lines, tv.spoken.size()])
	t.check(with_voice == script_lines, "todas con su archivo de voz (%d de %d)" % [with_voice, script_lines])
	var shown := 0
	for tx in subs:
		if str(tx).begins_with("[Trainer]") or str(tx).begins_with("[Nayra]") or str(tx).begins_with("[Yimi]") or str(tx).begins_with("(Llauri)"):
			shown += 1
	t.check(shown >= script_lines, "el subtítulo de cada línea lo muestra el director (%d de %d)" % [shown, script_lines])
	t.check(tv.spoken.has("t_nombre") and via.any(func(v: Array) -> bool: return str(v[0]) == "voces/trainer_amable/t_nombre_llauri"), "el Trainer dice tu nombre con su voz (t_nombre_llauri)")
	t.check(tv.overlaps().is_empty(), "línea de tiempo del guion: cero cruces (%d)" % tv.overlaps().size())
	t.check(tv.director_overlaps == 0 and VoiceDirector.overlaps == 0 and playing_max[0] <= 1, "registro del VoiceDirector: cero solapes (%d · máx. %d voces a la vez)" % [VoiceDirector.overlaps, playing_max[0]])
	var cut_rec: Dictionary = {}
	var after: Dictionary = {}
	var tl := tv.timeline()
	for i in tl.size():
		if str(tl[i]["id"]) == str(cut[1]):
			cut_rec = tl[i]
			after = tl[i + 1] if i + 1 < tl.size() else {}
	t.check(bool(cut_rec.get("saltada", false)) and float(cut_rec.get("dur", 99.0)) < 3.0, "[T] corta la línea en curso (%s duró %.1f s)" % [str(cut[1]), float(cut_rec.get("dur", -1.0))])
	t.check(not after.is_empty() and float(after.get("ini", 0.0)) >= float(cut_rec.get("fin", 0.0)), "y la siguiente empieza después, nunca encima")
	bot.queue_free()
	Engine.time_scale = prev_scale


## El Training entero, a tiempo real, como un jugador que escucha todo: duración total y línea de tiempo sin cruces.
func _largo(t: Node, agent: String) -> void:
	agent = agent if agent != "" else "Jiroshi"
	Engine.time_scale = 1.0
	SaveSlots.select(agent)
	var path := OS.get_environment("T2_TIMELINE")
	if path == "":
		path = ProjectSettings.globalize_path("user://training_timeline.txt")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", true)
	bot.set("fast_speech", false)
	bot.set("read_delay", 1.2)
	bot.set("sign_delay", 2.0)
	bot.set("skip_cut", false)
	bot.set("timeout_s", 2400.0)
	bot.set("quiz_wrong", ["metricas"])  # una mal, para oír el ánimo del Trainer
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	var t0 := Time.get_ticks_msec()
	var vd0 := VoiceDirector.now_ms() / 1000.0
	bot.call("start", t.main, [], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	tut.set("timeline_path", path)
	var tv: TrainingVoice = tut.get("voice")
	var ov: Array = []
	var n_lines := [0]
	var mods: Dictionary = {}
	var clk := {}  # fin de cada módulo en el reloj del juego sin escalar (el del audio): lo que dura para el jugador
	tut.connect("module_finished", func(id: String, _s: String) -> void:
		mods[id] = (Time.get_ticks_msec() - t0) / 1000.0
		clk[id] = snappedf(tv._now(), 0.1))
	await t.until(func() -> bool:
		if is_instance_valid(tv):
			n_lines[0] = tv.timeline().size()
			ov = tv.overlaps()
		return not out.is_empty(), 2500.0)
	var total := (Time.get_ticks_msec() - t0) / 1000.0
	var total_clk := VoiceDirector.now_ms() / 1000.0 - vd0
	var r: Dictionary = out[0] if not out.is_empty() else {}
	t.check((r.get("errores", []) as Array).is_empty(), "Training entero sin errores %s" % str(r.get("errores", [])))
	t.check(ov.is_empty(), "cero cruces de voces en todo el Training (%d)" % ov.size())
	var vd_ov := tv.director_overlaps if is_instance_valid(tv) else -1
	t.check(vd_ov == 0, "cero solapes en el registro del VoiceDirector (%d)" % vd_ov)
	t.check(FileAccess.file_exists(path), "línea de tiempo escrita en %s" % path)
	t.note("duración total %s (%.0f s de juego; %.0f s de pared con la máquina cargada) · %d líneas habladas · fin de cada módulo %s" % [Loc.mmss(total_clk), total_clk, total, n_lines[0], JSON.stringify(clk)])
	t.check(total_clk >= 12.0 * 60.0 and total_clk <= 16.5 * 60.0, "dura entre 12 y 16 minutos (%s)" % Loc.mmss(total_clk))
	print("[t2largo] total_juego_s=%.1f total_pared_s=%.1f lineas=%d cruces=%d solapes_vd=%d fin_modulos_juego=%s fin_modulos_pared=%s" % [total_clk, total, n_lines[0], ov.size(), vd_ov, JSON.stringify(clk), JSON.stringify(mods)])
	bot.queue_free()


func _media(t: Node, what: String) -> void:
	if OS.get_environment("T2_CALIDAD") != "":  # liviano | baja | media | alta: el aspecto del recuerdo en cada calidad
		GfxQuality.apply(t.get_tree(), OS.get_environment("T2_CALIDAD"))
	if OS.get_environment("T2_ESCALA3D") != "":  # grabar más rápido por software: el 3D a menor resolución, la UI y los subtítulos nítidos
		t.get_viewport().scaling_3d_scale = clampf(float(OS.get_environment("T2_ESCALA3D")), 0.4, 1.0)
	if what.begins_with("modulo_"):
		await _media_modulo(t, what.substr(7))
		return
	if what.begins_with("story_"):
		await _media_story(t, what.substr(6))
		return
	match what:
		"recuerdo", "fotos":
			await _media_recuerdo(t, what == "fotos")
		"actualizacion":
			await _media_actualizacion(t, false)
		"actualizacion_foto":
			await _media_actualizacion(t, true)
		"ecos":
			await _media_ecos(t)
		"look":
			await _media_look(t)
		"firma_lunes":
			await _media_firma_lunes(t)
		"c14":
			await _media_c14(t)
	t.check(true, "media %s" % what)


func _media_recuerdo(t: Node, photos: bool) -> void:
	var agent := "Jiroshi"
	var menu := await _menu_agent(t, agent)
	print("[t2media] inicio frame %d" % Engine.get_frames_drawn())
	(menu.find_child("StartBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(6)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("read_delay", 3.0)
	bot.set("sign_delay", 2.0)
	bot.set("skip_cut", false)
	t.add_child(bot)
	var skip: Array = Tutorial.module_ids()
	skip.erase("aux")
	skip.erase("contactos")  # el role play: el Trainer hace de cliente molesto
	skip.erase(Tutorial.CONTRACT_MODULE)
	bot.call("attach", t.main, tut, skip)
	if photos:
		await t.seconds(1.5)
		await _shot(t, "01_tarjeta_recuerdo")
		await t.until(func() -> bool: return GameState.seated_at == TrainingRoom.SEAT, 60.0)
		await t.seconds(1.0)
		await _shot(t, "02_aula_sentado")
		var pl: Player = t.player()
		pl.stand_up()
		pl.teleport(t.building().floor_node.global_position + Vector3(10.2, 0, -2.2), 15.0)
		await t.seconds(1.0)
		await _shot(t, "03_trainer_amable")
		await t.until(func() -> bool: return GameState.seated_at == TrainingRoom.SEAT, 30.0)
	await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("ContractUI") != null, 200.0)
	if photos:
		await t.seconds(1.0)
		await _shot(t, "04_contrato")
		await t.until(func() -> bool:
			var c := t.get_tree().root.get_node_or_null("ContractUI")
			return c == null or bool(c.get("is_signed")), 40.0)
		await _shot(t, "05_falla")
	await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("CortePresente") != null, 60.0)
	if photos:
		await t.seconds(1.2)
		await _shot(t, "06_corte_presente")
		await t.seconds(3.6)
		await _shot(t, "07_contraste")
	await t.until(func() -> bool: return GameState.turno == 1 and GameState.running, 40.0)
	await t.seconds(6.0)
	if photos:
		await _shot(t, "08_lunes")
	print("[t2media] fin frame %d" % Engine.get_frames_drawn())
	bot.queue_free()


## Capturas del aula del recuerdo para revisar el encuadre y la luz (sin voces): la puerta, la isla del café, tu
## sitio con el Trainer en cada uno de sus lugares, los monitores, la planta de la sala, la fila de la foto.
## T2_SHOTS=<carpeta> xvfb-run … --escenario training_media:look --escala 1   (T2_AGENTE = agente; T2_LOOK = solo esas)
func _media_look(t: Node) -> void:
	SaveSlots.select(OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi")
	var only := OS.get_environment("T2_LOOK")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", false)
	bot.set("stop_at", "llegada/cafe")
	bot.set("timeout_s", 600.0)
	t.add_child(bot)
	bot.call("start", t.main, ["llegada"], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	await t.until(func() -> bool: return bool(bot.get("stopped")), 60.0)
	await t.seconds(1.0)
	var st: TrainingStage = tut.get("stage")
	var tr_: TrainerAmable = tut.get("trainer")
	var pl: Player = t.player()
	var fl: Node3D = t.building().floor_node
	var want := func(n: String) -> bool: return only == "" or only.contains(n)
	if want.call("puerta"):
		st.set_scene("cafe", true)
		tr_.place("puerta")
		var mk := fl.find_child(TrainingRoom.DOOR_MARK, true, false) as Node3D
		if mk != null:
			pl.teleport(mk.global_position, mk.rotation_degrees.y)
		await t.seconds(0.8)
		tr_.gesture("welcome")
		tr_.speak_line(3.0, true)
		await t.seconds(1.3)
		await _shot(t, "look_01_puerta")
		tr_.hush()
		await t.seconds(2.0)
	if want.call("cafe"):
		pl.teleport(fl.to_global(TrainingRoom.COFFEE_STAND), 0.0)
		await t.seconds(0.8)
		await _shot(t, "look_02_cafe")
		(pl.get("head") as Node3D).rotation.x = -0.35
		await t.seconds(0.3)
		await _shot(t, "look_02b_cafe_mesa")
	st.set_scene("clase", true)
	await tut.call("ensure_seated", false)
	await t.seconds(1.2)
	for spot in ["centro", "cerca", "mesa", "pizarra"]:
		if not want.call(spot):
			continue
		tr_.place(spot)
		await t.seconds(0.9)
		tr_.speak_line(3.0)
		await t.seconds(1.0)
		await _shot(t, "look_03_sentado_%s" % spot)
		tr_.hush()
	if want.call("lados"):
		tr_.place("centro")
		pl.rotation.y += deg_to_rad(38.0)
		await t.seconds(0.6)
		await _shot(t, "look_04_izquierda")
		pl.rotation.y -= deg_to_rad(76.0)
		await t.seconds(0.6)
		await _shot(t, "look_05_derecha")
		pl.rotation.y += deg_to_rad(38.0)
	if want.call("monitores"):
		(pl.get("head") as Node3D).rotation.x = -0.32
		await t.seconds(0.5)
		await _shot(t, "look_06_monitores")
		(pl.get("head") as Node3D).rotation.x = 0.0
	if want.call("reaccion"):
		st.cue("risa")
		await t.seconds(1.1)
		await _shot(t, "look_07_risa")
		await t.seconds(2.5)
		st.cue("mano:Nayra")
		st.cue("aplauso")
		await t.seconds(1.3)
		await _shot(t, "look_08_mano_aplauso")
		await t.seconds(2.5)
	if want.call("planta"):
		var ceil := fl.find_child("TrainingTecho1", false, false) as Node3D
		if ceil != null:
			ceil.visible = false
		var cam := Camera3D.new()
		fl.add_child(cam)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 8.6
		cam.position = Vector3(9.75, 9.0, -4.9)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.current = true
		await t.seconds(0.5)
		await _shot(t, "look_09_planta")
		st.set_scene("cafe", true)
		await t.seconds(0.6)
		await _shot(t, "look_10_planta_cafe")
		st.set_scene("foto", true)
		await t.seconds(0.6)
		await _shot(t, "look_11_planta_foto")
		cam.queue_free()
		if ceil != null:
			ceil.visible = true
		pl.get_viewport().get_camera_3d()
		(pl.get("camera") as Camera3D).current = true
	if want.call("foto"):
		st.set_scene("foto", true)
		tr_.place("foto")
		st._hold(tr_, "pose_a")
		var cam2 := Camera3D.new()
		fl.add_child(cam2)
		cam2.fov = TrainingRoom.PHOTO_FOV
		cam2.position = TrainingRoom.PHOTO_CAM
		cam2.look_at(fl.to_global(TrainingRoom.PHOTO_LOOK), Vector3.UP)
		cam2.current = true
		await t.seconds(1.2)
		await _shot(t, "look_12_foto")
		cam2.queue_free()
		(pl.get("camera") as Camera3D).current = true
	t.check(true, "capturas del aula")
	bot.queue_free()


## Storyboard de un módulo (rápido, sin voces): una captura por paso, 2 s después de empezarlo. Para revisar el encuadre
## antes de grabar (xvfb, sin --write-movie): T2_SHOTS=<carpeta> … --escenario training_media:story_<módulo> --escala 1
func _media_story(t: Node, id: String) -> void:
	SaveSlots.select(OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", true)
	bot.set("fast_speech", true)
	bot.set("video", true)
	bot.set("read_delay", 3.2)
	bot.set("sign_delay", 4.0)
	bot.set("skip_cut", false)
	bot.set("timeout_s", 600.0)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("start", t.main, [id], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	(tut.get("voice") as TrainingVoice).fast = false  # con subtítulos, pero el bot no espera las líneas
	var n := [0]
	tut.connect("step_started", func(m: String, s: String) -> void:
		n[0] += 1
		var k: int = n[0]
		await t.seconds(2.4)
		if is_instance_valid(tut):
			await _shot(t, "st_%s_%02d_%s" % [m, k, s]))
	await t.until(func() -> bool: return not out.is_empty() or (id == Tutorial.CONTRACT_MODULE and GameState.turno == 1), 600.0)
	await t.seconds(3.0)
	await _shot(t, "st_%s_fin" % id)
	t.check(true, "storyboard %s (%d pasos)" % [id, n[0]])
	bot.queue_free()


## Clip de avance: un módulo, con el bot escuchando cada línea (la grabación termina cuando el módulo termina).
func _media_modulo(t: Node, id: String) -> void:
	SaveSlots.select(OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", true)
	bot.set("fast_speech", false)
	bot.set("video", true)
	bot.set("read_delay", 1.4)
	bot.set("sign_delay", 2.5)
	bot.set("skip_cut", false)
	bot.set("timeout_s", 900.0)
	t.add_child(bot)
	var fin := [false]
	print("[t2media] inicio frame %d" % Engine.get_frames_drawn())
	bot.call("start", t.main, [id], [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var tv: TrainingVoice = tut.get("voice")
	tut.connect("module_finished", func(m: String, _s: String) -> void:
		if m == id:
			fin[0] = true
			var p := OS.get_environment("T2_TIMELINE")
			if p != "" and is_instance_valid(tv):
				tv.write_log(p, {"modulo": id})
			print("[t2media] %s: %d líneas, %d cruces, %d solapes VoiceDirector, %.1f s" % [id, tv.timeline().size(), tv.overlaps().size(), tv.director_overlaps, tv._now()]))
	var hasta := float(OS.get_environment("T2_HASTA")) if OS.get_environment("T2_HASTA") != "" else 0.0  # cortar a los N s (clips parciales)
	await t.until(func() -> bool: return fin[0] or (hasta > 0.0 and is_instance_valid(tv) and tv._now() >= hasta) or (id == Tutorial.CONTRACT_MODULE and t.get_tree().root.get_node_or_null("CortePresente") != null and GameState.turno == 1), 900.0)
	await t.seconds(1.5)
	print("[t2media] fin frame %d" % Engine.get_frames_drawn())
	t.check(fin[0] or hasta > 0.0, "módulo %s grabado" % id)
	bot.queue_free()


## Clip «la firma → la falla → el corte → el Lunes → la polaroid en C-14», en una sola toma y a tiempo real: partida
## nueva con el Training a medias (todo hecho menos la firma, como si lo hubieras dejado ahí), el bot escucha cada
## línea y firma; al empezar el Lunes sube a su isla, se sienta en C-14, piensa en la foto y la mira de cerca.
func _media_firma_lunes(t: Node) -> void:
	var agent := OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi"
	Engine.time_scale = 1.0
	SaveSlots.select(agent)
	var done: Dictionary = {}
	for id in Tutorial.module_ids():
		if id != Tutorial.CONTRACT_MODULE:
			done[id] = "hecho"
	var fp := Tutorial.first_path(agent)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fp.get_base_dir()))
	var f := FileAccess.open(fp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "agente": agent, "modulos": done, "choices": {"conto": true, "pregunto": true, "ayudo": true}, "quiz": {}}))
	f.close()
	var menu := await _menu_agent(t, agent)
	print("[t2media] inicio frame %d" % Engine.get_frames_drawn())
	(menu.find_child("StartBtn", true, false) as Button).emit_signal("pressed")
	await t.frames(6)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	var bot: Node = (load(BOT) as GDScript).new()
	bot.set("log_steps", true)
	bot.set("fast_speech", false)
	bot.set("video", true)
	bot.set("read_delay", 1.4)
	bot.set("sign_delay", 2.5)
	bot.set("skip_cut", false)
	bot.set("timeout_s", 900.0)
	t.add_child(bot)
	bot.call("attach", t.main, tut, [])
	var tv: TrainingVoice = tut.get("voice")
	tut.connect("module_finished", func(m: String, _s: String) -> void:
		var p := OS.get_environment("T2_TIMELINE")
		if p != "" and is_instance_valid(tv):
			tv.write_log(p, {"modulo": m})
		print("[t2media] %s: %d líneas, %d cruces, %d solapes VoiceDirector, %.1f s · frame %d" % [m, tv.timeline().size(), tv.overlaps().size(), tv.director_overlaps, tv._now(), Engine.get_frames_drawn()]))
	await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("CortePresente") != null, 600.0)
	print("[t2media] corte frame %d" % Engine.get_frames_drawn())
	await t.until(func() -> bool: return GameState.turno == 1 and GameState.running, 120.0)
	print("[t2media] lunes frame %d" % Engine.get_frames_drawn())
	bot.queue_free()
	await t.seconds(5.0)
	var pl: Player = t.player()
	if t.building().current_floor != 2:
		t.building().go_to_floor(2, "ascensor")
		await t.seconds(1.5)
	var fl := t.building().floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	if pl.seated:
		pl.stand_up()
		await t.seconds(0.4)
	# de pie junto a la mesa, mirando la polaroid
	pl.teleport(seat.global_position + seat.global_transform.basis.z * 1.0 + seat.global_transform.basis.x * -0.35, seat.global_rotation_degrees.y)
	(pl.get("head") as Node3D).rotation.x = -0.42
	print("[t2media] c14 frame %d" % Engine.get_frames_drawn())
	await t.seconds(3.0)
	(pl.get("head") as Node3D).rotation.x = 0.0
	pl.sit_at(seat, "C-14")
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_foto", false)), 40.0)
	await t.seconds(1.0)
	pl.stand_up()
	await t.seconds(0.6)
	var pol := fl.find_child("PolaroidArea", true, false) as Interactable
	if pol != null:
		pol.interact(pl)
	await t.seconds(6.5)
	print("[t2media] fin frame %d · solapes VoiceDirector %d" % [Engine.get_frames_drawn(), VoiceDirector.overlaps])
	t.check(VoiceDirector.overlaps == 0, "sin solapes (%d)" % VoiceDirector.overlaps)


## Deja la partida de `agent` como después del Training: contrato firmado (si no lo estaba, uno leído con una firma
## cualquiera) y, con T2_FOTOS, las tres copias de la foto de promoción de una grabación anterior.
func _seed_memory(agent: String) -> void:
	if not bool(SaveSlots.contract(agent).get("firmado", false)):  # sin la partida de una grabación: un contrato leído y una firma cualquiera
		SaveSlots.select(agent)
		SaveSlots.sign_contract(agent, true)
		SaveSlots.use_main()
		var p0 := SaveSlots.progress(agent)
		var rec0: Dictionary = p0.get("recuerdo", {}) if p0.get("recuerdo", {}) is Dictionary else {}
		rec0["firma"] = [[0.0, 0.25, 0.12, 0.02, 0.2, 0.3, 0.3, 0.05, 0.42, 0.28], [0.45, 0.15, 0.7, 0.12, 1.0, 0.2]]
		p0["recuerdo"] = rec0
		SaveSlots.save(agent)
	var from := OS.get_environment("T2_FOTOS")  # carpeta con foto_promocion*.jpg de una grabación (el runner empieza con las partidas vacías)
	if from != "":
		for k in [1, 2, 3]:
			var src := from.path_join(str(RecuerdosSemana.PHOTO_FILES[k - 1]))
			if FileAccess.file_exists(src):
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RecuerdosSemana.photo_path(agent, k).get_base_dir()))
				DirAccess.copy_absolute(src, ProjectSettings.globalize_path(RecuerdosSemana.photo_path(agent, k)))


## Clip corto del presente (para empalmar al de la firma): el Lunes, de pie junto a C-14 mirando la polaroid, te
## sientas, tu agente piensa en la foto (corto), y con [E] la mira de cerca y termina la idea.
func _media_c14(t: Node) -> void:
	var agent := OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi"
	Engine.time_scale = 1.0
	_seed_memory(agent)
	await t.start_shift(agent, 1)
	await t.frames(3)
	t.building().go_to_floor(2, "ascensor")
	await t.seconds(1.5)
	var pl: Player = t.player()
	var fl := t.building().floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	if pl.seated:
		pl.stand_up()
		await t.seconds(0.4)
	pl.teleport(seat.global_position + seat.global_transform.basis.z * 1.0 + seat.global_transform.basis.x * -0.35, seat.global_rotation_degrees.y)
	(pl.get("head") as Node3D).rotation.x = -0.42
	print("[t2media] c14 frame %d" % Engine.get_frames_drawn())
	await t.seconds(3.0)
	(pl.get("head") as Node3D).rotation.x = 0.0
	pl.sit_at(seat, "C-14")
	await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_foto", false)), 40.0)
	await t.seconds(1.0)
	pl.stand_up()
	await t.seconds(0.6)
	var pol := fl.find_child("PolaroidArea", true, false) as Interactable
	if pol != null:
		pol.interact(pl)
	await t.seconds(6.5)
	print("[t2media] fin frame %d · solapes VoiceDirector %d" % [Engine.get_frames_drawn(), VoiceDirector.overlaps])
	t.check(VoiceDirector.overlaps == 0, "sin solapes (%d)" % VoiceDirector.overlaps)


## Capturas del presente con la partida que haya en user:// (qa: se copia la de la grabación «firma_lunes», con su foto
## y su firma de verdad): la polaroid en C-14 el lunes, el martes y el miércoles; la cláusula al pie de la desconexión;
## y el contrato clavado junto al aula de training.
func _media_ecos(t: Node) -> void:
	var agent := OS.get_environment("T2_AGENTE") if OS.get_environment("T2_AGENTE") != "" else "Jiroshi"
	_seed_memory(agent)
	for day in [1, 2, 3]:
		await t.start_shift(agent, day)
		await t.frames(3)
		t.building().go_to_floor(2, "ascensor")
		await t.frames(6)
		var fl := t.building().floor_node as FloorBase
		var seat := fl.seat_by_id("C-14")
		var pl: Player = t.player()
		if day == 1:
			pl.sit_at(seat, "C-14")
			await t.seconds(1.5)
			await _shot(t, "10_c14_sentado")
			pl.stand_up()
			await t.seconds(0.4)
		pl.teleport(seat.global_position + seat.global_transform.basis.z * 1.0 + seat.global_transform.basis.x * -0.35, seat.global_rotation_degrees.y)
		(pl.get("head") as Node3D).rotation.x = -0.42
		await t.seconds(0.8)
		await _shot(t, "11_polaroid_mesa_dia%d" % day)
		var area := fl.find_child("PolaroidArea", true, false) as Interactable
		if area != null:
			area.interact(pl)
		await t.seconds(2.0)
		await _shot(t, "12_polaroid_cerca_dia%d" % day)
		await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("EcoFoto") == null and not VoiceDirector.busy(1), 30.0)
		if day == 1:
			await t.die("abandono", "", "shero")
			await t.wait_death_shown(20.0)
			await t.seconds(4.0)
			await _shot(t, "13_desconexion_clausula")
			await t.reconnect()
			await t.seconds(1.0)
		if day == 2:
			t.building().go_to_floor(1, "ascensor")
			await t.frames(8)
			var paper := t.building().floor_node.find_child("ContratoFirmado", true, false) as Node3D
			if paper != null:
				(pl.get("head") as Node3D).rotation.x = 0.0
				pl.teleport(paper.global_position + Vector3(-0.9, -1.5, -2.6), 160.0)
				await t.seconds(0.8)
				await _shot(t, "14_contrato_lejos")
				pl.teleport(paper.global_position + Vector3(0.0, -1.5, -0.75), 180.0)
				await t.seconds(0.8)
				await _shot(t, "15_contrato_pared")
				var ca := paper.find_child("ContratoArea", true, false) as Interactable
				if ca != null:
					ca.interact(pl)
				await t.seconds(2.0)
				await _shot(t, "16_contrato_cerca")
				await t.until(func() -> bool: return t.get_tree().root.get_node_or_null("EcoContrato") == null and not VoiceDirector.busy(1), 30.0)
				var mural := t.building().floor_node.find_child("MuralPromociones", true, false) as Node3D
				if mural != null:
					pl.teleport(mural.global_position + Vector3(0.0, -1.52, -2.3), 180.0)
					await t.seconds(0.8)
					await _shot(t, "17_mural")
					pl.teleport(mural.global_position + Vector3(0.35, -1.52, -0.95), 180.0)
					await t.seconds(0.8)
					await _shot(t, "18_mural_cerca")
			else:
				t.check(false, "no está el contrato clavado en el piso 1")
		await t.back_to_menu()
		SaveSlots.use_main()


func _media_actualizacion(t: Node, photo: bool) -> void:
	await t.start_shift("Ttoom", 2)
	await t.frames(5)
	t.building().go_to_floor(1, "ascensor")
	await t.frames(5)
	var fl: Node3D = t.building().floor_node
	var tr_: Node3D = fl.find_child("Trainer", true, false) as Node3D
	if tr_ != null and tr_.has_method("set_session"):
		tr_.call("set_session", true)
	var pl: Player = t.player()
	pl.teleport(fl.global_position + Vector3(7.5, 0, -6.3), 0.0)
	await t.seconds(0.6)
	print("[t2media] inicio frame %d" % Engine.get_frames_drawn())
	PersonajesP5.say("Trainer", "trainer", "bienvenida", PersonajesP5.line("lineas_trainer", "bienvenida"))
	if photo:
		await t.seconds(2.0)
		await _shot(t, "09_actualizacion_terror")
	else:
		await t.seconds(4.5)
		PersonajesP5.say("Trainer", "trainer", "quiz_intro", PersonajesP5.line("lineas_trainer", "quiz_intro"))
		await t.seconds(5.0)
	print("[t2media] fin frame %d" % Engine.get_frames_drawn())


## Una línea del VoiceDirector de mentira (para probar RecuerdosSemana._heard sin esperar a que suene nada).
class _FakeLine extends RefCounted:
	var result: String = ""
	var started_ms: int = -1
	var wall_end_ms: int = 0

## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2-beta · integración: las costuras entre paquetes (bugs/VoiceDirector × animación × muertes × IA).
##   `--escenario v032_int`
##   i32_npc_habla          (animación × VoiceDirector) el animador de los NPC escucha al VoiceDirector, no a
##                          EventBus.subtitle: Shero habla → su animador habla; un compañero habla → el agente más
##                          cercano gesticula / mueve la mandíbula; al terminar la línea, se calla.
##   i32_muerte_en_llamada  (muertes × VoiceDirector × cola ACD) morir con una llamada en curso corta al cliente y a
##                          todo lo demás; durante la muerte solo pasan los subtítulos del asesino; al reaparecer no
##                          queda ninguna voz, ningún reproductor del screamer ni subtítulo, y el contacto se cerró.

func escenarios() -> Array[String]:
	return ["i32_npc_habla", "i32_muerte_en_llamada"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"i32_npc_habla": await _npc_habla(t)
		"i32_muerte_en_llamada": await _muerte_en_llamada(t)


func _cm(t: Node) -> ContactManager:
	return t.get_tree().get_first_node_in_group("contact_manager") as ContactManager


func _animator(slug: String) -> NpcAnimator:
	for a in NpcAnimator._all:
		if is_instance_valid(a) and (a as NpcAnimator).slug == slug:
			return a as NpcAnimator
	return null


func _npc_habla(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.frames(4)
	var vd := t.get_tree().root.get_node("VoiceDirector")
	# v0.3.2-core: la primera vez que te sientas en C-14 tu agente piensa en la foto (2,5 s de juego después de
	# sentarte, ~10 s de voz). Se espera a que la pida y se corta junto con lo demás: si no, según la velocidad de la
	# máquina quedaba detrás de la línea de Shero y el susurro del compañero de más abajo no llegaba a sonar a tiempo.
	await t.seconds(3.5)
	vd.call("stop_all", "prueba")
	var hub: Node = NpcAnimator._hub
	t.check(hub != null and is_instance_valid(hub) and hub.is_inside_tree(), "hay un NpcSpeechHub en la raíz")
	if hub == null or not is_instance_valid(hub):
		await t.back_to_menu()
		return
	var on_sub := Callable(hub, "_on_sub")
	t.check(vd.is_connected("subtitle_shown", on_sub) and not EventBus.subtitle.is_connected(on_sub), "el hub escucha al VoiceDirector (y no a EventBus.subtitle: no gesticula con lo que no llegó a sonar)")
	t.check(vd.is_connected("line_started", Callable(hub, "_on_line")) and vd.is_connected("finished", Callable(hub, "_on_done")), "y conoce el principio y el fin exactos de cada línea")
	t.note("animadores vivos: %d" % NpcAnimator._all.size())
	# 1) Un personaje con nombre: Shero. Lo que no suena (queda en cola o se descarta) no mueve a nadie.
	var shero := _animator("shero")
	var l: Object = vd.call("say", "voces/shero/coach_1", VoiceDirector.P.DIRECTO, "shero", Callable(), {"text": "¡Los quiero a todos en Available!", "seconds": 3.0})
	await t.frames(3)
	t.check(vd.get("current") == l, "la línea de Shero suena por el VoiceDirector")
	t.check(int((hub.get("until_ms") as Dictionary).get("shero", 0)) > NpcAnimator.SpeechHub.now(), "el hub sabe que habla Shero")
	if shero != null:
		t.check(shero._speaking(), "el animador de Shero está hablando")
		var talked: bool = await t.until(func() -> bool: return shero._talking and shero._talk_mode != "", 4.0)
		t.check(talked, "y gesticula o mueve la mandíbula (modo «%s», estado %s/%s)" % [shero._talk_mode, shero.state, shero.sub])
	else:
		t.note("Shero no está en el piso ahora mismo: se revisa solo el hub")
	vd.call("cancel", l, "prueba")
	await t.frames(2)
	var quiet: bool = await t.until(func() -> bool: return int((hub.get("until_ms") as Dictionary).get("shero", 0)) <= NpcAnimator.SpeechHub.now() + 160, 2.0)
	t.check(quiet, "al cortar la línea, Shero deja de hablar (≤ 0,15 s)")
	if shero != null:
		var stopped: bool = await t.until(func() -> bool: return not shero._talking, 3.0)
		t.check(stopped, "y su animador vuelve a lo que hacía")
	# 2) «Un compañero»: habla el agente más cercano a la cámara. Quién habla se decide UNA vez, cuando la línea empieza a
	# sonar, y queda anotado en el hub (`picked`): la prueba lee esa anotación en vez de mirar ventanas de tiempo un par
	# de fotogramas después (con la máquina cargada la ventana estimada por el texto ya había vencido: «nadie»).
	var cam: Camera3D = t.get_viewport().get_camera_3d()
	var expected: NpcAnimator = null
	var best := 9.0
	var near: Array = []
	for a in NpcAnimator._all:
		var an := a as NpcAnimator
		if not is_instance_valid(an) or an.body == null or cam == null or not an.body.is_inside_tree():
			continue
		var dd: float = an.body.global_position.distance_to(cam.global_position)
		near.append("%s %.1f m" % [an.slug, dd])
		if an.slug.begins_with("agente_") and an.body.is_visible_in_tree() and dd > 0.5 and dd < best:
			best = dd
			expected = an
	t.note("cámara %s · animadores: %s" % [str(cam), str(near)])
	var who: NpcAnimator = null
	for round in 3:
		# El turno está vivo (stop_calm: entran llamadas): si en ese momento suena un cliente (prioridad mayor), la línea
		# del compañero espera en la cola hasta 5 s o vence, y nadie gesticula porque nada sonó. Eso NO es un fallo del
		# animador: por eso la prueba primero deja libre al director y pide la línea en el mismo fotograma, con prioridad
		# de cliente (ningún otro la corta ni la deja en cola). Así empieza a sonar dentro de play_voice y el hub anota a
		# quién le tocó EN ESA MISMA LLAMADA: se lee enseguida, sin esperar fotogramas (con carga 20+ fallaba 1 de 2).
		vd.call("stop_all", "prueba")
		(hub.get("picked") as Dictionary).clear()
		AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala", VoiceDirector.P.CLIENTE)
		var pk: Variant = null
		var noted := false
		for k in (hub.get("picked") as Dictionary):
			if str(k).contains("comp_no_te_pares"):
				pk = (hub.get("picked") as Dictionary)[k]
				noted = true
		who = pk as NpcAnimator if pk is NpcAnimator else null
		var c1: Object = vd.get("current")
		if round == 0:
			t.note("suena %s (%s) · elegido %s" % [str(c1.get("id")) if c1 != null else "—", str(c1.get("speaker")) if c1 != null else "", who.slug if who != null else str(pk)])
			t.check(c1 != null and str(c1.get("id")).contains("comp_no_te_pares"), "la línea del compañero empieza a sonar en la misma llamada (director libre)")
			t.check(noted and who != null, "la línea de un compañero la dice el agente de al lado (%s)" % (who.slug if who != null else "nadie"))
			t.check(who == expected, "y es exactamente el agente más cercano a la cámara (%s a %.1f m)" % [expected.slug if expected != null else "—", best])
			if who != null:
				t.check(who._speak_until_ms > NpcAnimator.SpeechHub.now(), "su ventana de habla está abierta mientras suena la línea")
				var moved: bool = await t.until(func() -> bool: return who._talking, 4.0)
				t.check(moved, "y habla (modo «%s»)" % who._talk_mode)
				if not GfxQuality.is_light():
					var jaw: bool = await t.until(func() -> bool: return who._jaw < 0 or who._jaw_open > 0.2, 4.0)
					t.check(jaw, "mueve la mandíbula (%.1f°)" % who._jaw_open)
		else:
			t.check(noted and who == expected, "repetida (%d): la dice el MISMO agente (elección determinista: %s)" % [round + 1, who.slug if who != null else str(pk)])
		if round < 2:
			vd.call("stop_all", "prueba")
			if who != null:
				var cut: bool = await t.until(func() -> bool: return not who._talking, 3.0)
				t.check(cut, "cortada la línea, el compañero calla")
	await t.until(func() -> bool: return vd.get("current") == null and (vd.get("queue") as Array).is_empty(), 30.0)
	if who != null:
		var shut: bool = await t.until(func() -> bool: return not who._talking and who._jaw_open < 0.2, 4.0)
		t.check(shut, "al terminar la voz, se calla y cierra la boca")
	t.check(int(vd.get("overlaps")) == 0, "sin solapes (%d)" % int(vd.get("overlaps")))
	await t.back_to_menu()


func _muerte_en_llamada(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var vd := t.get_tree().root.get_node("VoiceDirector")
	vd.call("reset_audit")
	var cm := _cm(t)
	var first: Dictionary = cm.next_scripted()
	await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0)
	var offered: bool = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 8.0)
	t.check(offered, "entra el primer contacto del turno")
	cm.accept()
	await t.frames(4)
	t.check(cm.phase == ContactManager.Phase.ACTIVE, "contacto en curso (%s)" % str(cm.current.get("id", "")))
	# Más voces pedidas a la vez: un compañero y un aviso de Ezlaki quedan en cola detrás del cliente.
	AudioManager.play_voice("comp", "comp_viene_shero", tr("COMP_VIENE_SHERO"), "Sala")
	EventBus.subtitle.emit("ezlak", "Aviso de Ezlaki", 3.0)
	await t.frames(2)
	var before: Object = vd.get("current")
	t.note("antes de morir suena: %s · en cola %d" % [str(before.get("id")) if before != null else "—", (vd.get("queue") as Array).size()])
	var subs: Array = []
	var on_sub := func(sp: String, tx: String, _s: float) -> void: subs.append([sp, tx])
	vd.connect("subtitle_shown", on_sub)
	var shown: Array = t.spy("death_shown")
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)
	t.die("break_excedido", "prueba", "shero")
	await t.frames(3)
	var cur: Object = vd.get("current")
	t.check(cur == null or int(cur.get("priority")) == VoiceDirector.P.SCREAMER, "al empezar la muerte se corta el cliente y todo lo demás (suena: %s)" % (str(cur.get("id")) if cur != null else "nada"))
	t.check((vd.get("queue") as Array).is_empty(), "y la cola de voces queda vacía (%d)" % (vd.get("queue") as Array).size())
	# Mientras te matan, piden hablar otros: no pasan.
	AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala")
	EventBus.subtitle.emit("ezlak", "Otro aviso de Ezlaki", 3.0)
	EventBus.subtitle.emit("cliente", "¿Aló? ¿Sigue ahí?", 3.0)
	var el := 0.0
	var max_voices := 0
	while el < 20.0 and shown.is_empty():
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		max_voices = maxi(max_voices, int(vd.call("voices_playing")))
	Engine.time_scale = scale0
	t.check(not shown.is_empty(), "el screamer termina y sale la pantalla de muerte (%.1f s, %s)" % [el, str(Screamers.last_info.get("kill", ""))])
	var others: Array = []
	var killer_subs := 0
	for s in subs:
		var sp := str(s[0]).to_lower()
		if sp == "shero":
			killer_subs += 1
		elif str(s[1]) != "":
			others.append("%s: %s" % [sp, str(s[1]).left(30)])
	t.check(others.is_empty(), "durante la muerte solo se ven subtítulos del asesino (otros: %s)" % str(others))
	t.check(killer_subs >= 1, "la frase gritada de Shero sale como subtítulo (%d)" % killer_subs)
	t.check(max_voices <= 1, "ninguna voz del juego suena debajo del screamer (máx. %d por el VoiceDirector/AudioManager)" % max_voices)
	await t.wait_death_shown(8.0)
	await t.reconnect()
	await t.frames(6)
	# Al reaparecer: nada queda sonando ni escrito.
	var lingering: Array = []
	for type in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for p in t.get_tree().root.find_children("*", type, true, false):
			var bus := str(p.get("bus"))
			if bool(p.get("playing")) and (bus.begins_with("Screamer") or bus == "HaimeReplay"):
				lingering.append("%s (%s)" % [p.name, bus])
	t.check(lingering.is_empty(), "ningún reproductor del screamer sigue sonando al reaparecer (%s)" % str(lingering))
	t.check(t.get_tree().get_nodes_in_group(Screamers.GROUP).is_empty(), "el nodo del screamer se fue")
	t.check(vd.get("current") == null and (vd.get("queue") as Array).is_empty() and int(vd.call("voices_playing")) == 0, "el VoiceDirector está en silencio (suena %d, cola %d)" % [int(vd.call("voices_playing")), (vd.get("queue") as Array).size()])
	t.check(not subs.is_empty() and str(subs[-1][1]) == "", "el último subtítulo es el borrado (no queda la frase del asesino en pantalla)")
	t.check(not bool(vd.get("_hold_low")), "el VoiceDirector vuelve a dejar hablar a todos")
	t.check(cm.phase == ContactManager.Phase.IDLE, "el contacto en curso se cerró (fase %d)" % cm.phase)
	# Y después se puede volver a hablar normalmente.
	await t.seconds(6.5)
	AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala")
	await t.frames(3)
	var after: Object = vd.get("current")
	t.check(after != null and str(after.get("id")).contains("comp_no_te_pares"), "después de reconectar las voces vuelven a sonar")
	vd.disconnect("subtitle_shown", on_sub)
	vd.call("stop_all", "prueba")
	t.check(int(vd.get("overlaps")) == 0, "0 solapes registrados (%d)" % int(vd.get("overlaps")))
	await t.back_to_menu()

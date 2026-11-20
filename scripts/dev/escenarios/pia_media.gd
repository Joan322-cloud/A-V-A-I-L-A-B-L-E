## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Videos de la v0.3.2 · IA para Joan (no corren con `--escenario all`: el id lleva «:»). Con pantalla y Movie Maker:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##       --write-movie out.avi --fixed-fps 30 -- --escenario ia_media:shero --escala 1
##   ia_media:shero     Ezlaki: le faltas el respeto a Shero → verbal → WW (Ack escrito) → amenaza → sale a buscarte
##   ia_media:memoria   un compañero recuerda lo que le contaste
##   ia_media:chat      el chat nuevo (burbujas, escribiendo…, Leído) resuelto escribiendo, sin botones
##   ia_media:llamada   llamada en modo Micrófono con WAV grabados pasados por Vosk (medidor, «Escuchando…», transcripción)
##   ia_media:reaccion  aviso de coaching de Shero → la pared de reacciones → «SOLO FALTAS TÚ» → selector → ✅; y la
##                      variante ignorada: «¿No viste el mensaje?» + alerta, y a la segunda, WW
##   ia_media:estados   estados de Ezlaki: en llamada / en lunch / activo; el comodín solo lo contesta el «activo»; Shero
##                      en llamada no lee el canal; el Trainer «pausó sus notificaciones» y contesta al instante

var _cap: Label = null


func escenarios() -> Array[String]:
	return ["ia_media:"]


func run(_id: String, arg: String, t: Node) -> void:
	match arg:
		"shero": await _shero(t)
		"memoria": await _memoria(t)
		"chat": await _chat(t)
		"llamada": await _llamada(t)
		"reaccion": await _reaccion(t)
		"estados": await _estados(t)
		_: t.fail("ia_media: shero | memoria | chat | llamada | reaccion | estados")
	await t.seconds(2.5)  # el último plano se queda un momento
	print("[iamedia] FIN frame %d" % Engine.get_frames_drawn())  # media.sh corta aquí (después viene el menú)
	t.check(true, "ia_media:" + arg)


func _caption(t: Node, text: String) -> void:
	if _cap == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		t.add_child(layer)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", PcStyle.box(Color(0, 0, 0, 0.66), Color(0, 0, 0, 0), 10, 6))
		pc.position = Vector2(24, 1012)  # abajo, sobre el escritorio (la base es 1920×1080): no tapa la PC
		layer.add_child(pc)
		_cap = Label.new()
		_cap.add_theme_font_size_override("font_size", 31)
		_cap.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
		pc.add_child(_cap)
	_cap.text = text
	print("[iamedia] frame %d · %s" % [Engine.get_frames_drawn(), text.replace("\n", " · ")])


func _quiet(t: Node) -> void:
	Discipline.freeze(true, "iamedia")
	Metrics.set_aux(Metrics.Aux.BO)


func _type(t: Node, le: LineEdit, text: String) -> void:
	le.grab_focus()
	le.text = ""
	for ch in text:
		le.text += ch
		le.caret_column = le.text.length()
		if randf() < 0.25:
			AudioManager.play_sfx("ezlak_escribiendo", "UI")
		await t.seconds(0.055)
	await t.seconds(0.35)


func _ws(t: Node) -> Node:
	return t.main.get_node_or_null("UI/Workstation")


## Con la PC ampliada el mundo 3D queda detrás, oscurecido: se renderiza a media resolución para que la grabación
## (llvmpipe, sin GPU) no tarde el triple. `full` = 1.0 para las tomas en que se ve la sala.
func _fast3d(t: Node, on: bool) -> void:
	t.get_tree().root.scaling_3d_scale = 0.5 if on else 1.0


func _ezlaki_view(t: Node, agent: String) -> PcEzlak:
	await t.start_shift(agent, 1)
	await t.login_at_seat()
	_quiet(t)
	IABrain.forget_all()
	var ws := _ws(t)
	var app := ws.get("ezlak") as PcEzlak
	app.auto_follow = false
	ws.set("_layout", 2)
	ws.call("set_zoom", true)
	_fast3d(t, true)
	await t.seconds(0.8)
	return app


func _say(t: Node, app: PcEzlak, text: String, wait: float) -> void:
	await _type(t, app.input, text)
	app.submit_typed()
	await t.seconds(wait)


func _shero(t: Node) -> void:
	var app: PcEzlak = await _ezlaki_view(t, "Jiroshi")
	app.open_channel("dm:shero")
	_caption(t, "Ezlaki · DM con Shero: le escribes con tus palabras")
	await t.seconds(1.5)
	await _say(t, app, "shero, ¿por qué siempre me escribes a mí?", 5.0)
	_caption(t, "Le faltas el respeto → 1.ª falta: verbal (alerta)")
	await _say(t, app, "eres un calvo pesado", 5.5)
	_caption(t, "2.ª falta → written warning (con Ack)")
	await _say(t, app, "calvo de mierda, te odio", 4.5)
	_caption(t, "Escribir «ok recibido» da el Ack")
	await _say(t, app, "ok recibido", 3.5)
	_caption(t, "Amenazarlo → sale de su escritorio a buscarte")
	await _say(t, app, "te voy a romper la cara calvo", 5.0)
	app.open_channel("#team-familia")
	await t.seconds(3.0)


func _memoria(t: Node) -> void:
	var app: PcEzlak = await _ezlaki_view(t, "Jiroshi")
	app.open_channel("dm:marko")
	_caption(t, "DM con Marko: le cuentas algo tuyo")
	await t.seconds(1.0)
	await _say(t, app, "marko, mi mamá está enferma y no dormí nada", 7.0)
	_caption(t, "La conversación sigue…")
	await _say(t, app, "jaja qué noche, ya no siento las piernas", 7.0)
	_caption(t, "…y más tarde Marko se acuerda")
	await _say(t, app, "hola de nuevo causa", 9.0)
	await t.seconds(2.0)


func _chat(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	await t.login_at_seat()
	Discipline.freeze(true, "iamedia")
	var ws := _ws(t)
	ws.set("_layout", 1)
	ws.call("set_zoom", true)
	_fast3d(t, true)
	var cm := t.main.get("contacts") as ContactManager
	var c := _first_chat()
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c)
	cm.accept()
	await t.seconds(0.5)
	var k := (ws.get("desktop") as PcDesktop).kardex
	_caption(t, "Chat con el cliente: burbujas, «escribiendo…», Leído y respuestas rápidas")
	await t.seconds(2.8)
	_caption(t, "Le escribes con tus palabras (con faltas): el cliente entiende. Mientras escribes, espera")
	var path := DialogTree.best_path(c)
	var i := 0
	for s in path:
		if cm.tree == null:
			break
		var o: Dictionary = cm.tree.options()[int(s["i"])]
		if i == 1:  # una con respuesta rápida (clic en el botón)
			_caption(t, "…o eliges una respuesta rápida (Fácil y Normal)")
			await t.seconds(2.5)
			cm.choose(int(s["i"]))
		else:
			if i == 2:
				_caption(t, "Y sigues escribiendo: texto libre y respuestas rápidas conviven")
			var said := _human(Loc.pick(o), i)
			await _type(t, k.chat.input, said)
			k.chat.submit()
		i += 1
		await t.seconds(3.6)
	_caption(t, "Chat resuelto: texto libre + respuestas rápidas")
	await t.seconds(1.0)


func _llamada(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	Discipline.freeze(true, "iamedia")
	Loc.set_setting("ia_llamadas", "microfono")
	IASpeech.forced_engine = "vosk"
	IASpeech.refresh()
	await t.until(func() -> bool: return IASpeech.state == "ready", 25.0)
	var ws := _ws(t)
	ws.set("_layout", 1)
	ws.call("set_zoom", true)
	_fast3d(t, true)
	var cm := t.main.get("contacts") as ContactManager
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t1").get("contactos", []):
		if str(x.get("id", "")) == "t1c1":
			c = (x as Dictionary).duplicate(true)
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c)
	cm.accept()
	_caption(t, "Opciones › Responder llamadas: Micrófono · mantén [T] y habla")
	await t.seconds(5.0)
	var dir := ProjectSettings.globalize_path("res://../tools/asr_sidecar/test_wavs/").simplify_path()
	for n in 3:
		if cm.tree == null:
			break
		_caption(t, "Escuchando… (WAV grabado como micrófono · Vosk sin conexión)")
		var player := AudioStreamPlayer.new()
		var f := dir.path_join("t1c1_%d.wav" % n)
		player.stream = AudioStreamWAV.load_from_file(f)
		player.bus = "UI"
		t.add_child(player)
		player.play()
		IASpeech.feed_wav(f)
		await t.until(func() -> bool: return IASpeech.state == "ready", 20.0)
		player.queue_free()
		_caption(t, "Reconocido → el cliente te contesta según lo que dijiste")
		await t.seconds(5.5)
	await t.seconds(3.0)
	IASpeech.forced_engine = ""
	Loc.set_setting("ia_llamadas", "predefinidas")


func _first_chat() -> Dictionary:
	for c in DataLoader.dict("contactos_t1").get("contactos", []):
		if str(c.get("canal", "")) == "chat" and (c as Dictionary).has("nodos") and not (c as Dictionary).has("portal"):
			return (c as Dictionary).duplicate(true)
	return {}


func _human(text: String, seed: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = seed + 11
	var w := text.replace("«", "").replace("»", "").to_lower().split(" ", false)
	var out: Array[String] = []
	for i in w.size():
		if i > 1 and r.randf() < 0.2:
			continue
		out.append(w[i])
	return " ".join(out).replace(".", "").replace("¿", "")


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _aviso(t: Node, hub: EzlakHub) -> Dictionary:
	hub.typing("#team-familia", "shero", 2.0)
	await t.seconds(2.0)
	var body := "%s %s\n%s" % [TranslationServer.translate("EZLAKI_SHERO_COACHING_LISTA"), hub.coaching_tags(), TranslationServer.translate("IA_REACT_ASK")]
	EventBus.ezlak_post.emit("#team-familia", "shero", body, {"tipo": "programado", "pide_reaccion": true, "mention": true})
	await t.frames(3)
	return hub.message_by_id(int(hub.reaction_pending.get("id", -1)))


func _reaccion(t: Node) -> void:
	var app: PcEzlak = await _ezlaki_view(t, "Jiroshi")
	GameState.stop_calm()
	var hub := EzlakHub.get_hub(t.get_tree())
	var ws := _ws(t)
	IABrain.presence_override = {"marko": "activo", "llauri": "llamada", "juan": "activo", "ttoom": "lunch"}
	app.open_channel("#team-familia")
	# En el juego la ventana es de 45 s reales (Normal); para el video, 24 s (y 8 s en la variante ignorada).
	(IABrain.cfg()["reaccion_aviso"] as Dictionary)["ventana_s_real"] = 24.0
	_caption(t, "Aviso de coaching de Shero (en el juego, 07:00): pide reacción. Ventana acortada para el video")
	var m: Dictionary = await _aviso(t, hub)
	await t.seconds(3.5)
	_caption(t, "El team reacciona uno por uno: el contador sube y la cuenta atrás corre")
	await t.until(func() -> bool: return bool(hub.wall_status(m)["solo_tu"]), 40.0)
	_caption(t, "Reaccionaron todos los que están en línea: SOLO FALTAS TÚ")
	await t.seconds(3.0)
	_caption(t, "[Enter] abre el selector · ← → eligen · [Enter] reacciona (o clic)")
	ws.call("_unhandled_input", _key(KEY_ENTER))
	await t.seconds(1.8)
	ws.call("_unhandled_input", _key(KEY_RIGHT))
	await t.seconds(0.7)
	ws.call("_unhandled_input", _key(KEY_LEFT))
	await t.seconds(1.0)
	ws.call("_unhandled_input", _key(KEY_ENTER))
	_caption(t, "[OK] = «estoy al tanto» (acuse). Un emoji burlón contaría como falta de respeto")
	await t.seconds(3.0)
	app.call("_on_meta", "who:%d" % int(m["id"]))
	_caption(t, "«ver quién reaccionó»: Llauri reaccionó en llamada; Ttoom, en lunch, no")
	await t.seconds(5.0)
	app.call("_on_meta", "who:%d" % int(m["id"]))
	# variante: lo ignoras
	(IABrain.cfg()["reaccion_aviso"] as Dictionary)["ventana_s_real"] = 8.0
	(IABrain.cfg()["reaccion_aviso"] as Dictionary)["minimo_al_volver_s"] = 0.0
	_caption(t, "Otra noche: lo ignoras…")
	await _aviso(t, hub)
	await t.until(func() -> bool: return int(hub.reaction_pending.get("etapa", 0)) >= 1, 30.0)
	_caption(t, "Venció: DM de Shero (negrita + insignia + aviso arriba; el chat no se abre solo)")
	await t.seconds(3.5)
	app.open_channel("dm:shero")
	_caption(t, "«¿No viste el mensaje?» + alerta. Si sigues sin reaccionar…")
	await t.until(func() -> bool: return hub.reaction_pending.is_empty(), 30.0)
	_caption(t, "…written warning: «No reaccionó al aviso del supervisor»")
	await t.seconds(5.0)
	IABrain.presence_override.clear()
	IABrain.reload()


func _estados(t: Node) -> void:
	var app: PcEzlak = await _ezlaki_view(t, "Marko")
	GameState.stop_calm()
	var hub := EzlakHub.get_hub(t.get_tree())
	var ws := _ws(t)
	var cm := t.main.get("contacts") as ContactManager
	IABrain.presence_override = {"shero": "activo", "ttoom": "activo"}
	cm.acd.npc_busy_until["Jiroshi"] = GameState.clock_seconds + 3600.0  # Jiroshi atiende un contacto de verdad
	app.open_channel("#team-familia")
	_caption(t, "Ezlaki: cada chat muestra el estado real de la persona (punto de color + texto)")
	await t.seconds(4.0)
	app.open_channel("dm:jiroshi")
	_caption(t, "Jiroshi atiende un contacto → «en llamada». Ttoom está «activo»")
	await t.seconds(3.5)
	# el comodín: llamas al que está en llamada y no contesta; el activo sí
	_caption(t, "Sirve de pista: lejos de tu PC, el comodín solo lo contesta quien está «activo»")
	ws.call("set_zoom", false)
	_fast3d(t, false)
	t.player().stand_up()
	await t.seconds(1.5)
	var names := Comodin.coworkers()
	Comodin.open()
	await t.seconds(1.5)
	Comodin.choose_aux(Metrics.Aux.BREAK)
	await t.seconds(1.5)
	_caption(t, "Llamas a Jiroshi (en llamada)…")
	Comodin.choose_coworker(names.find("Jiroshi"))
	await t.until(func() -> bool: return Comodin.phase == "retry", 40.0)
	_caption(t, "…no contesta. Llamas a Ttoom (activo) con el mismo comodín")
	await t.seconds(3.0)
	Comodin.choose_coworker(names.find("Ttoom"))
	await t.until(func() -> bool: return Comodin.phase == "", 40.0)
	_caption(t, "Ttoom contesta y te marca el AUX en tu PC")
	await t.seconds(3.5)
	await t.login_at_seat()
	Metrics.set_aux(Metrics.Aux.BO)
	ws.set("_layout", 2)
	ws.call("set_zoom", true)
	_fast3d(t, true)
	# Shero en llamada no lee el canal
	IABrain.presence_override["shero"] = "llamada"
	app.open_channel("dm:shero")
	_caption(t, "Shero «en llamada» (coaching por Rooms): ahora no está leyendo los canales")
	await t.seconds(3.0)
	app.open_channel("#team-familia")
	await _say(t, app, "shero ya deja de escribir tanto, pesado", 4.5)
	_caption(t, "No lo lee: un compañero te avisa. Con Shero «activo» sería una falta")
	await t.seconds(3.5)
	# el Trainer
	EventBus.ezlak_post.emit("dm:trainer", "trainer", Loc.fmt(Loc.pick(DataLoader.dict("lineas_trainer").get("anuncio", {})), {"hora": "02:20"}), {"tipo": "training"})
	_caption(t, "El Trainer: su estado SIEMPRE dice «pausó sus notificaciones»…")
	await t.seconds(3.0)
	app.open_channel("dm:trainer")
	await t.seconds(2.0)
	await _say(t, app, "hola trainer, como estas?", 2.5)
	_caption(t, "…y contesta al instante")
	await t.seconds(2.0)
	await _say(t, app, "gracias por la clase", 3.5)
	IABrain.presence_override.clear()

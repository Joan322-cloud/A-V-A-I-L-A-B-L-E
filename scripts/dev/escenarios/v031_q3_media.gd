## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Videos y capturas de audio de la v0.3.1 · Q3 para Joan (no corren con `--escenario all`: el id lleva «:»).
## Con pantalla y Movie Maker, a tiempo real (--escala 1):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##       --write-movie out.avi --fixed-fps 30 -- --escenario q3_media:tour --escala 1
##   q3_media:tour     pisos -1 (calle y lobby), 2 (sala y capas de música), 1 (training), escalera y azotea: pasos por
##                     superficie, carrera, salto y aterrizaje, lluvia por contexto, las 4 capas y el silencio de la azotea
##   q3_media:ezlaki   respuestas rápidas enteras con vista previa, respuesta escrita, capturas de adherencia en
##                     #allocations (ampliada) y reacciones
##   q3_media:lluvia   10 minutos de lluvia sola en la calle del -1 (prueba de que no hay repetición audible)
## Marca en el log «[q3media] inicio frame <n>» y «[q3media] fin frame <n>» (fotogramas dibujados, para recortar).

var _cap: Label = null
var _t0: float = 0.0


func escenarios() -> Array[String]:
	return ["q3_media:"]


func run(_id: String, arg: String, t: Node) -> void:
	match arg:
		"tour": await _tour(t)
		"ezlaki": await _ezlaki(t)
		"lluvia": await _lluvia(t)
		_: t.fail("q3_media: tour | ezlaki | lluvia")
	t.check(true, "q3_media:" + arg)


func _caption(t: Node, text: String) -> void:
	if _cap == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		t.add_child(layer)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", PcStyle.box(Color(0, 0, 0, 0.62), Color(0, 0, 0, 0), 10, 6))
		pc.position = Vector2(24, 24)
		layer.add_child(pc)
		_cap = Label.new()
		_cap.add_theme_font_size_override("font_size", 30)
		_cap.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
		pc.add_child(_cap)
	_cap.text = text
	var pl: Player = t.player()
	print("[q3media] frame %d · %s · pos %s · piso %d" % [Engine.get_frames_drawn(), text.replace("\n", " · "), str(pl.global_position.snapped(Vector3(0.1, 0.1, 0.1))) if pl else "-", GameState.current_floor])


func _zone_pos(t: Node, id: String) -> Vector3:
	for z in t.get_tree().get_nodes_in_group("zones"):
		if z is Zone and (z as Zone).zone_id == id and (z as Node3D).is_inside_tree():
			return (z as Node3D).global_position
	return Vector3.INF


func _quiet(t: Node) -> void:
	var cm := t.get_tree().get_first_node_in_group("contact_manager")
	if cm != null:
		cm.set("queue", [])
	Discipline.freeze(true, "q3media")


## Camina (o corre) de la posición actual hacia `to` por la rejilla de rutas del piso, a `speed` m/s, `secs` segundos.
func _walk(t: Node, to: Vector3, speed: float, secs: float) -> void:
	var p: Player = t.player()
	var fl := FloorBase.active
	var pts := PackedVector3Array()
	if fl != null and to != Vector3.INF:
		var g := Pursuit.grid_for(fl)
		if g != null:
			pts = g.find_path(p.global_position, to)  # la rejilla de rutas de la persecución (todos los pisos)
		if pts.size() <= 1:
			pts = fl.path(p.global_position, to)
	print("[q3media]   camino %s → %s: %d puntos" % [str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(to.snapped(Vector3(0.1, 0.1, 0.1))) if to != Vector3.INF else "INF", pts.size()])
	if pts.is_empty():
		pts.append(to if to != Vector3.INF else p.global_position + Vector3(0, 0, -20))
	var i := 0
	var el := 0.0
	while el < secs:
		await t.get_tree().physics_frame
		var dt := t.get_physics_process_delta_time()
		el += dt
		if i >= pts.size():
			break
		var tgt := pts[i]
		var cur := p.global_position
		var d := Vector2(tgt.x - cur.x, tgt.z - cur.z)
		if d.length() < 0.25:
			i += 1
			continue
		var step := d.normalized() * speed * dt
		p.global_position = Vector3(cur.x + step.x, cur.y, cur.z + step.y)
		var yaw := atan2(-d.x, -d.y)
		p.rotation.y = lerp_angle(p.rotation.y, yaw, clampf(dt * 6.0, 0.0, 1.0))
		p.head.rotation.x = lerpf(p.head.rotation.x, -0.05, dt * 3.0)


## Un salto de ~0,45 m: el cuerpo sube y la gravedad del jugador lo baja (el AudioDirector suena el aterrizaje).
func _jump(t: Node) -> void:
	var p: Player = t.player()
	var dir: Node = AudioManager.director
	dir.call("jumped")
	for k in 8:
		p.global_position.y += 0.45 / 8.0
		p.velocity.y = 0.0
		await t.get_tree().physics_frame
	await t.seconds(0.9)


func _tour(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	_quiet(t)
	var b: Building = t.building()
	var dir: Node = AudioManager.director
	var md: MusicDirector = dir.get("music")
	md.forced = [0.6, 0.0, 0.0, 0.0]
	b.go_to_floor(-1, "calle")
	await t.seconds(1.0)
	print("[q3media] inicio frame %d" % Engine.get_frames_drawn())
	_caption(t, "Piso -1 · calle: pasos en exterior mojado (charcos)\nLluvia a la intemperie: 2 camas largas + gotas, ráfagas, canaletas")
	var lobby := _zone_pos(t, "lobby")
	EventBus.player_entered_zone.emit("calle")
	await _walk(t, lobby, 3.0, 3.0)
	_caption(t, "Salto (Espacio): aterrizaje sobre la vereda mojada")
	AudioManager.play_sfx("trueno_cercano")
	await _jump(t)
	await _jump(t)
	await _walk(t, lobby, 3.0, 4.0)
	EventBus.player_exited_zone.emit("calle")
	_caption(t, "Lobby: porcelanato negro con eco de hall\nLa lluvia queda tras el vidrio (filtrada)")
	await _walk(t, lobby + Vector3(-8, 0, -3), 3.6, 5.0)
	_caption(t, "Corriendo: set de carrera propio, más pesado\n+ respiración que sube con el aliento")
	t.player().breath_left = t.player().breath * 0.25
	await _walk(t, lobby + Vector3(8, 0, -2), 6.8, 4.5)
	await _jump(t)
	# piso 2: sala de PCs y las capas
	b.go_to_floor(2, "ascensor")
	await t.seconds(1.0)
	_quiet(t)
	var sala := _zone_pos(t, "sala")
	md.forced = [1.0, 0.0, 0.0, 0.0]
	_caption(t, "Piso 2 · sala de PCs: alfombra\nMúsica capa 1 · calma con pavor (cuerdas graves, piano preparado)")
	await _walk(t, sala, 3.2, 3.0)
	EventBus.player_entered_zone.emit("sala")
	await _walk(t, sala + Vector3(-6, 0, 0), 3.2, 5.0)
	md.forced = [1.0, 1.0, 0.0, 0.0]
	_caption(t, "Presión media (Dread ↑): entra la capa 2 · tensión (ostinato de chelos)")
	await _walk(t, sala + Vector3(-6, 0, 4), 3.2, 8.0)
	md.forced = [1.0, 1.0, 1.0, 0.0]
	_caption(t, "Presión alta: capa 3 · trémolo en cluster, reloj, «braams»")
	await _walk(t, sala + Vector3(2, 0, 4), 3.2, 8.0)
	md.forced = [0.55, 1.0, 1.0, 1.0]
	_caption(t, "Persecución: capa 4 · taikos y chelos frenéticos")
	AudioManager.play_sfx("shero_pasos_intensos")
	await _walk(t, sala + Vector3(8, 0, 0), 6.6, 8.0)
	md.forced = [1.0, 0.0, 0.0, 0.0]
	_caption(t, "Vuelve la calma (las capas salen de a poco)")
	await _walk(t, sala, 3.2, 5.0)
	# piso 1: training (vinílico)
	b.go_to_floor(1, "ascensor")
	await t.seconds(1.0)
	_quiet(t)
	var tr := _zone_pos(t, "training_sala2")
	_caption(t, "Piso 1 · pasillo y training: vinílico tipo madera\nLluvia lejana")
	await _walk(t, tr, 3.4, 5.0)
	EventBus.player_entered_zone.emit("training_sala2")
	await _walk(t, tr + Vector3(1.0, 0, 1.0), 2.4, 2.5)
	await _jump(t)
	EventBus.player_exited_zone.emit("training_sala2")
	# escalera
	b.go_to_stairwell(2, true)
	await t.seconds(1.0)
	_caption(t, "Escalera: concreto con eco de la caja")
	await _walk(t, t.player().global_position + Vector3(0, 0, 2.5), 2.6, 4.0)
	await _walk(t, t.player().global_position + Vector3(0, 0, -2.5), 2.6, 3.0)
	# azotea
	b.go_to_floor(9, "ascensor")
	await t.seconds(1.0)
	_quiet(t)
	md.forced = []
	var caf := _zone_pos(t, "cafeteria_azotea")
	_caption(t, "Azotea: deck mojado · la música calla a propósito\nSolo lluvia y viento")
	await _walk(t, caf, 3.4, 7.0)
	AudioManager.play_sfx("trueno_lejano")
	await _jump(t)
	await _walk(t, caf + Vector3(5, 0, 3), 3.4, 4.0)
	print("[q3media] fin frame %d" % Engine.get_frames_drawn())
	Discipline.freeze(false, "q3media")


func _type(t: Node, le: LineEdit, text: String) -> void:
	le.grab_focus()
	le.text = ""
	for ch in text:
		le.text += ch
		le.caret_column = le.text.length()
		if randf() < 0.25:
			AudioManager.play_sfx("ezlak_escribiendo", "UI")
		await t.seconds(0.06)
	await t.seconds(0.4)


func _ezlaki(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	_quiet(t)
	var hub := EzlakHub.get_hub(t.get_tree())
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	var app := ws.get("ezlak") as PcEzlak
	AudioManager.director.get("music").set("forced", [0.7, 0.0, 0.0, 0.0])
	app.auto_follow = false  # la cámara la manejamos nosotros (las menciones no arrastran de canal)
	Metrics.set_aux(Metrics.Aux.BO)  # sin llamadas entrantes mientras se graba
	ws.set("_layout", 2)  # «derecha»: Ezlaki + Fonex en grande (como con Tab)
	ws.call("set_zoom", true)
	await t.seconds(0.8)
	print("[q3media] inicio frame %d" % Engine.get_frames_drawn())
	# 1) respuestas rápidas enteras + vista previa
	hub.excuse_pending = true
	EventBus.ezlak_post.emit("dm:shero", "shero", Loc.pick(DataLoader.dict("lineas_canales").get("excusa", {}).get("pregunta", {})), {"tipo": "excusa", "quick_replies": ["excusa_1", "excusa_2", "excusa_3"], "mention": true, "typing_s": 1.0})
	app.open_channel("dm:shero")
	_caption(t, "Ezlaki · las respuestas rápidas se ven enteras (bajan de línea, sin cortar)")
	await t.seconds(3.0)
	_caption(t, "Al pasar el ratón: vista previa de lo que vas a responder")
	app.show_preview(Loc.pick(DataLoader.dict("ezlak_canales").get("textos_respuesta", {}).get("excusa_2", {})))
	await t.seconds(3.0)
	app.show_preview("")
	# 2) respuesta escrita: excusa → Shero contesta mal
	_caption(t, "Campo «Escribir…»: respondes con tus palabras\nA Shero le caen mal las excusas")
	await _type(t, app.input, "perdón, es que el sistema se colgó")
	app.submit_typed()
	await t.seconds(4.5)
	_caption(t, "Escribir «recibido» da el Ack del written warning")
	Metrics.issue_written_warning("aht_bo")
	await t.seconds(1.5)
	await _type(t, app.input, "recibido, doy ack")
	app.submit_typed()
	await t.seconds(3.5)
	# 3) DM de compañero
	var buddy := "dm:" + str(hub.agent_dms("Jiroshi")[0])
	app.open_channel(buddy)
	_caption(t, "DM de un compañero: entiende la intención y contesta en personaje")
	await t.seconds(1.0)
	await _type(t, app.input, "jaja qué turno, ya no siento las piernas")
	app.submit_typed()
	await t.seconds(5.0)
	# 4) #allocations con capturas
	app.open_channel("#allocations")
	_caption(t, "#allocations: Shero y el Perrito RTA tagean con la captura\nde la vista de adherencia (identidades del juego)")
	EventBus.ezlak_post.emit("#allocations", "rta", "@here de momento no hay cola, pasamos a BO. Guau.", {"tipo": "programado", "captura": {"tipo": "lista", "estado": "bo", "n": 8, "tema": "oscuro"}})
	await t.seconds(3.0)
	EventBus.ezlak_post.emit("#allocations", "shero", "@Jiroshi break excedido.", {"tipo": "disciplina", "pista": "break", "escalon": "llamado", "mention": true})
	await t.seconds(2.5)
	EventBus.ezlak_post.emit("#allocations", "rta", "@Marko perdiste un contacto. Missed. Guau.", {"tipo": "programado", "captura": {"tipo": "uno", "estado": "perdido", "quien": "marko", "tema": "claro"}})
	await t.seconds(3.0)
	EventBus.ezlak_post.emit("#allocations", "rta", "Team, recuerden que el ACW es de máx 2 min, ojo con sus tiempos. Guau.", {"tipo": "programado", "captura": {"tipo": "lista", "estado": "acw", "n": 4, "tema": "claro"}})
	await t.seconds(4.0)
	_caption(t, "Clic en la imagen: se ve grande")
	var last: Dictionary = hub.messages("#allocations")[hub.messages("#allocations").size() - 4]
	app.open_shot(int(last.get("id", 0)))
	await t.seconds(4.0)
	app.close_shot()
	_caption(t, "Los compañeros reaccionan con las caras del site")
	await t.seconds(3.0)
	# 5) los @here de Shero en #team-familia (caso diario con planilla borrosa, llamado a coaching)
	app.open_channel("#team-familia")
	_caption(t, "#team-familia: los @here de Shero (caso diario con la planilla,\nllamado a coaching de las 7:30)")
	EventBus.ezlak_post.emit("#team-familia", "shero", tr("EZLAKI_SHERO_CASO_DIARIO"), {"tipo": "programado", "captura": {"tipo": "hoja", "n": 13, "tema": "claro"}, "reacciones": true})
	await t.seconds(3.5)
	EventBus.ezlak_post.emit("#team-familia", "shero", tr("EZLAKI_SHERO_COACHING_LISTA") + " " + hub.coaching_tags(), {"tipo": "programado", "reacciones": true})
	await t.seconds(4.5)
	# 6) canal: pregunta → el Mentor
	_caption(t, "#team-familia: una pregunta la contesta el Mentor")
	await _type(t, app.input, "¿alguien sabe dónde está el tópico?")
	app.submit_typed()
	await t.seconds(4.5)
	print("[q3media] fin frame %d" % Engine.get_frames_drawn())


func _lluvia(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	_quiet(t)
	var b: Building = t.building()
	b.go_to_floor(-1, "calle")
	await t.seconds(1.0)
	EventBus.player_entered_zone.emit("calle")
	var dir: Node = AudioManager.director
	dir.get("music").set("forced", [0.0, 0.0, 0.0, 0.0])
	await t.seconds(2.0)
	# solo la lluvia: se apagan los demás bucles (calle, bus) y voces
	AudioManager.stop_ambient()
	var keep: Array = [dir.get("rain")]
	for p in t.get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		if not (p as Node).get_parent() in keep:
			(p as AudioStreamPlayer).volume_db = -80.0
	for p in t.get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		if not (p as Node).get_parent() in keep:
			(p as AudioStreamPlayer3D).volume_db = -80.0
	print("[q3media] inicio frame %d" % Engine.get_frames_drawn())
	await t.seconds(605.0)
	print("[q3media] fin frame %d · eventos %s" % [Engine.get_frames_drawn(), str(dir.get("rain").get("events_played"))])

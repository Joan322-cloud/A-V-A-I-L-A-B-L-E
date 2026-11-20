extends RefCounted
## v0.3.2-core · capturas para revisar a ojo lo del paquete core (`--shot core_emoji`, `--shot core_comodin`, …;
## varias: `--shot core_emoji+core_comodin+core_aviso`). Cada vista guarda además capturas intermedias con
## `_snap(s, "nombre")` en user://shots/. `--shot core_en:<vista>` saca la misma vista en inglés.
##   core_emoji     Ezlaki: mensaje con emojis, aviso de coaching con su pared, selector abierto
##   core_comodin   el panel del comodín con el estado de cada compañero (y «nadie está activo»)
##   core_aviso     el aviso de texto de arriba (Ezlaki, importante) con un subtítulo de voz abajo
##   core_opciones  el menú de opciones (la casilla «Emojis como texto», la fila del micrófono)
##   core_llamada   Kardex en una llamada con el panel del micrófono
##   core_espejo    te miras en el espejo del baño: tu agente, iluminado; y con Fatiga alta, alguien detrás
##   core_pistas    con «interactuar» en G y «aceptar» en V: la PC en una llamada entrante y la pista de levantarse
##   core_idioma    abres en español, pasas a English en el menú y empiezas el turno: la PC entera en inglés
##   core_video:<tema>  clips con --write-movie (marcas [video] inicio/fin) de lo que faltaba por MIRAR de la lista de
##                  bugs: fatiga (la misma hora y el mismo taper en Fácil, Normal y Difícil) · terminales (vuelta
##                  completa en cada piso: no queda ninguna terminal de pared; el AUX está en tu PC) · perdidas (en BO
##                  no suena nada más; en el evento de Rasec no se pierde nada)

func shots() -> Array[String]:
	return ["core_emoji", "core_comodin", "core_aviso", "core_opciones", "core_llamada", "core_idioma", "core_espejo", "core_pistas", "core_en:", "core_video:"]


func shoot(name: String, arg: String, s: Node) -> void:
	GameState.stop_calm()
	if name == "core_en":
		Loc.set_language("en")
		await _t(s, 0.3)
		await shoot(arg, "", s)
		return
	match name:
		"core_emoji": await _emoji(s)
		"core_comodin": await _comodin(s)
		"core_aviso": await _aviso(s)
		"core_opciones": await _opciones(s)
		"core_llamada": await _llamada(s)
		"core_idioma": await _idioma(s)
		"core_espejo": await _espejo(s)
		"core_pistas": await _pistas(s)
		"core_video":
			match arg:
				"fatiga": await _v_fatiga(s)
				"terminales": await _v_terminales(s)
				"perdidas": await _v_perdidas(s)


func after(_name: String, _s: Node) -> void:
	Loc.set_language("es")
	Controls.reset_all()
	Loc.set_setting("help_hud", false)
	IABrain.presence_override = {}
	Comodin.cancel()


func _t(s: Node, sec: float) -> void:
	await s.get_tree().create_timer(sec, true, false, true).timeout


func _snap(s: Node, name: String) -> void:
	await _t(s, 0.5)
	await RenderingServer.frame_post_draw
	var img: Image = s.get_viewport().get_texture().get_image()
	var path := "user://shots/%s%s.png" % [name, "_en" if Loc.language == "en" else ""]
	img.save_png(path)
	print("[shot] ", name, " -> ", ProjectSettings.globalize_path(path))


func _no_contacts(s: Node) -> void:
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED


func _emoji(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var app: PcEzlak = ws.get("ezlak")
	var hub: EzlakHub = ws.get("hub")
	app.open_channel("#team-familia")
	EventBus.ezlak_post.emit("#team-familia", "rasec", "¡Vamos team! 💪🔥 Hoy la rompemos 🎉 Los quiero ver con actitud 😎🚀", {})
	EventBus.ezlak_post.emit("#team-familia", "companero", "jajaja 😂 ya pues 🙏 gracias Rasec ❤️ 💯", {})
	EventBus.ezlak_post.emit("#team-familia", "mentor", "Totalmente de acuerdo 👏🙌 Gran liderazgo 😊 ⭐📈", {})
	await _t(s, 0.6)
	await _snap(s, "core_emoji_mensajes")
	EventBus.ezlak_post.emit("#team-familia", "shero", "@here Team, coaching a las 7:30. Espero su reacción para saber que están al tanto.", {"pide_reaccion": true, "mention": true})
	await _t(s, 14.0)
	app.refresh(0.016, true)
	await _snap(s, "core_emoji_pared")
	app.open_picker()
	await _t(s, 0.4)
	await _snap(s, "core_emoji_selector")
	var m := hub.message_by_id(app.picker_id)
	if not m.is_empty():
		app.wall_open = int(m.get("id", -1))
		hub.player_react(m, "🫡")
	app.refresh(0.016, true)
	await _t(s, 0.5)


func _comodin(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	await _t(s, 0.6)
	# De pie ANTES de cambiar de piso (cambiar de piso sentado deja la PC abierta en pantalla: el comodín no abre).
	var p: Node = s.get_tree().get_first_node_in_group("player")
	if p != null and bool(p.get("seated")):
		p.call("stand_up")
	await _t(s, 0.3)
	await s._place(-1, Vector3(13.8, 0, 7.5), -70.0)
	await _t(s, 0.6)
	IABrain.presence_override = {"jiroshi": "llamada", "llauri": "lunch", "ttoom": "activo", "juan": "ausente", "marko": "activo"}
	Comodin.open()
	await _snap(s, "core_comodin_aux")
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await _t(s, 0.3)
	await _snap(s, "core_comodin_quien")
	for k in IABrain.presence_override.keys():
		if str(IABrain.presence_override[k]) == "activo":
			IABrain.presence_override[k] = "llamada"
	await _t(s, 0.8)
	await _snap(s, "core_comodin_nadie")
	IABrain.presence_override["ttoom"] = "activo"
	IABrain.presence_override["marko"] = "activo"
	var names := Comodin.coworkers()
	Comodin.choose_coworker(names.find("Jiroshi") if names.has("Jiroshi") else 0)
	await _t(s, 0.4)
	await _snap(s, "core_comodin_llamando")
	var w := 0.0
	while Comodin.phase == "ringing" and w < 30.0:
		await _t(s, 0.2)
		w += 0.2
	await _t(s, 0.3)


func _aviso(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", false)
	await _t(s, 0.5)
	VoiceDirector.stop_all("captura")
	VoiceDirector.clear_notices()
	EventBus.subtitle.emit("ezlak", "@Shero · Shero: ¿Dónde estás? Tu AUX dice Available y tu silla está vacía.", 5.0)
	VoiceDirector.say("voces/comp/comp_viene_shero", VoiceDirector.P.AMBIENTE, "comp", Callable(), {"text": TranslationServer.translate("COMP_VIENE_SHERO")})
	await _snap(s, "core_aviso_ezlaki")
	VoiceDirector.clear_notices()
	VoiceDirector.notice("parlantes", "Parlantes: %s, a la sala de calibración. Ahora." % GameState.agent, 5.0, true)
	await _t(s, 0.3)
	ws.call("set_zoom", true)


func _opciones(s: Node) -> void:
	var main: Node = s._main
	main.call("_back_to_menu")
	await _t(s, 0.6)
	var menu: Node = main.get("main_menu")
	if menu != null and menu.has_method("_open_options"):
		menu.call("_open_options")
	else:
		var opt := OptionsMenu.new()
		opt.name = "OpcionesCaptura"
		(main.get_node("UI") as Node).add_child(opt)
	await _t(s, 0.5)


func _llamada(s: Node) -> void:
	await s._sit_c14()
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	Loc.set_setting("ia_llamadas", "microfono")
	EventBus.settings_changed.emit("ia_llamadas")
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.process_mode = Node.PROCESS_MODE_INHERIT  # una vista anterior pudo dejarlo parado (_no_contacts)
	var first: Dictionary = cm.next_scripted()
	GameState.clock_seconds = ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0
	var w := 0.0
	while cm.phase != ContactManager.Phase.OFFERING and w < 12.0:
		await _t(s, 0.2)
		w += 0.2
	cm.accept()
	await _t(s, 1.5)
	(ws.get("desktop") as PcDesktop).open_app("kardex")
	await _t(s, 1.0)
	await _snap(s, "core_llamada_mic")
	Loc.set_setting("ia_llamadas", "predefinidas")
	EventBus.settings_changed.emit("ia_llamadas")
	await _t(s, 0.6)


## Como un jugador nuevo en inglés: el juego abre en español, cambia a English en el menú y empieza el turno.
func _idioma(s: Node) -> void:
	var main: Node = s._main
	Loc.set_language("es")
	main.call("_back_to_menu")
	await _t(s, 0.6)
	Loc.toggle_language()
	var menu: Node = main.get("main_menu")
	if menu != null and menu.has_method("_build"):
		menu.call("_build")
	await _t(s, 0.4)
	await _snap(s, "core_idioma_menu")
	main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	await _t(s, 0.8)
	GameState.stop_calm()
	await s._sit_c14()
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	await _t(s, 0.8)
	await _snap(s, "core_idioma_pc")
	var desk := ws.get("desktop") as PcDesktop
	for app: String in ["correo", "identa", "portal", "campus"]:
		desk.open_app(app)
		await _t(s, 0.5)
		await _snap(s, "core_idioma_" + app)
	desk.open_app("kardex")
	await _t(s, 0.3)


## Frente al espejo del baño del piso 2: el reflejo sin susto (Fatiga baja), de lado, y con alguien detrás (Fatiga 60).
func _espejo(s: Node) -> void:
	var b: Building = s._building()
	if b.current_floor != 2:
		b.go_to_floor(2, "ascensor")
		await _t(s, 0.3)
	var p: Node = s.get_tree().get_first_node_in_group("player")
	if p != null and bool(p.get("seated")):
		p.call("stand_up")
	var m: Node3D = null
	for n in b.floor_node.find_children("Espejo", "", true, false):
		m = n
		break
	if m == null:
		return
	var axis := m.global_transform.basis.x.normalized()
	var bath := m.get_parent() as Node3D
	if axis.dot(bath.global_position - m.global_position) < 0.0:
		axis = -axis
	axis.y = 0.0
	axis = axis.normalized()
	var pos := m.global_position + axis * 0.85
	pos.y = 0.0
	var yaw := rad_to_deg(atan2(axis.x, axis.z))
	GameState.flags["espejo_susto_visto"] = true  # sin el susto raro en las dos primeras
	Fatigue.set_value(10.0)
	for caso: Array in [["core_espejo_frente", 0.0, 10.0], ["core_espejo_lado", 28.0, 10.0], ["core_espejo_alguien", 0.0, 60.0]]:
		await s._place(2, pos, yaw + float(caso[1]), -0.05)
		Fatigue.set_value(float(caso[2]))
		if float(caso[2]) >= 50.0:
			GameState.flags["espejo_susto_visto"] = false
		await _t(s, 0.8)
		m.call("interact", s._player())
		if float(caso[2]) >= 50.0 and MirrorView.current != null:
			MirrorView.current.haunt()
		await _t(s, 0.55)
		await _snap(s, str(caso[0]))
		await _t(s, 1.6)


## Las pistas de teclas con dos acciones remapeadas (interactuar → G, aceptar → V), como las vería el jugador.
func _pistas(s: Node) -> void:
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	Controls.rebind("interact", g)
	var v := InputEventKey.new()
	v.physical_keycode = KEY_V
	Controls.rebind("accept", v)
	await s._sit_c14()
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	var first: Dictionary = cm.next_scripted()
	GameState.clock_seconds = ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0
	var w := 0.0
	while cm.phase != ContactManager.Phase.OFFERING and w < 12.0:
		await _t(s, 0.2)
		w += 0.2
	await _t(s, 0.6)
	await _snap(s, "core_pistas_sentado")
	ws.call("set_zoom", true)
	await _t(s, 0.8)
	await _snap(s, "core_pistas_pc")
	ws.call("set_zoom", false)
	Controls.reset_all()
	await _t(s, 0.3)


# --- clips (--write-movie) ---------------------------------------------------------------------------

func _mark(what: String) -> void:
	print("[video] %s %d" % [what, Engine.get_frames_drawn()])


## Espera contada por cuadros (con --write-movie un cuadro tarda ~1 s de pared; los plazos de reloj real no sirven).
func _until(s: Node, cond: Callable, max_s: float) -> bool:
	var w := 0.0
	while not bool(cond.call()):
		if w >= max_s:
			return false
		await s.get_tree().process_frame
		w += s.get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	return true


func _adv(s: Node, game_s: float) -> void:
	GameState.clock_seconds += game_s
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await _t(s, 0.25)


## Fatiga por dificultad: dos horas de turno (el camino real: Fatigue._on_hour_changed) y un taper caliente, en
## Fácil, Normal y Difícil. La barra de ayuda del HUD enseña la Fatiga; el mensaje dice los números.
func _v_fatiga(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	Loc.set_setting("help_hud", true)
	var old := Difficulty.level
	await _t(s, 1.0)
	_mark("inicio")
	var hour := 1
	for lvl: int in [0, 1, 2]:
		Difficulty.set_level(lvl)
		Fatigue.set_value(50.0)
		await _t(s, 1.0)
		for i in 2:
			Fatigue.call("_on_hour_changed", hour)
			hour += 1
		var up := Fatigue.value
		EventBus.show_message.emit("%s · dos horas de turno: Fatiga 50 → %.1f" % [Difficulty.display_name(lvl), up], 2.6)
		await _t(s, 2.8)
		Fatigue.set_value(50.0)
		Fatigue.add(float(WorldObjects.TaperFlow.cfg().get("fatiga", -20.0)))
		var down := Fatigue.value
		EventBus.show_message.emit("%s · taper caliente: Fatiga 50 → %.1f" % [Difficulty.display_name(lvl), down], 2.6)
		await _t(s, 2.8)
		print("[video] fatiga: %s · 2 h 50 → %.2f · taper 50 → %.2f" % [Difficulty.id(lvl), up, down])
	Difficulty.set_level(old)
	Fatigue.set_value(20.0)
	_mark("fin")


## Sin terminales Fonex de pared: una vuelta completa en la llegada de cada piso y, al final, el AUX en tu PC.
func _v_terminales(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	var b: Building = s._building()
	s._player().stand_up()
	await _t(s, 0.5)
	_mark("inicio")
	for fn: int in [2, 1, -1, 9]:
		b.go_to_floor(fn, "ascensor")
		await _t(s, 0.6)
		var n := 0
		for c in b.floor_node.find_children("*", "", true, false):
			if c is WorldObjects.WallTerminal or str(c.name).begins_with("Terminal_"):
				n += 1
		print("[video] terminales: piso %d · %d terminales de pared" % [fn, n])
		var p: Player = s._player()
		var at := p.global_position
		for k in 6:
			p.teleport(at, 60.0 * k)
			p.head.rotation.x = -0.03
			await _t(s, 1.0)
	await s._sit_c14()
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	await _t(s, 1.5)
	ws.call("_pick_aux", Metrics.Aux.BREAK)
	await _t(s, 2.0)
	ws.call("_pick_aux", Metrics.Aux.AVAILABLE)
	await _t(s, 1.5)
	print("[video] terminales: AUX desde la PC = %s" % Metrics.aux_name())
	_mark("fin")


## Llamadas perdidas: (1) suena un contacto, pasas a BO: una perdida y 20 min de juego en BO sin que suene nada más;
## (2) el evento de Rasec en BO: 10 min de juego y ninguna perdida.
func _v_perdidas(s: Node) -> void:
	await s._sit_c14()
	var ws: Node = s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	var first: Dictionary = cm.next_scripted()
	GameState.clock_seconds = ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await _t(s, 0.5)
	_mark("inicio")
	var rang := await _until(s, func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 12.0)
	await _t(s, 1.5)
	ws.call("_pick_aux", Metrics.Aux.BO)
	await _t(s, 1.5)
	print("[video] perdidas: sonó=%s · a BO con el timbre: perdidas %d" % [str(rang), cm.missed_count])
	for i in 40:
		await _adv(s, 30.0)
	print("[video] perdidas: 20 min de juego en BO: perdidas %d · fase %d" % [cm.missed_count, cm.phase])
	var n_bo := cm.missed_count
	# (2) evento de Rasec
	var hub := PersonajesP5.get_hub(s.get_tree())
	GameState.clock_seconds = GameState.hhmm_to_seconds("05:25")
	EventBus.clock_tick.emit(GameState.clock_seconds)
	hub.rasec.call_event()
	await _t(s, 2.0)
	var m: Node3D = hub.marker("evento_rasec")
	s._player().stand_up()
	if m != null:
		s._player().teleport(m.global_position, 0.0)
	var on := await _until(s, func() -> bool: return hub.busy == "evento", 12.0)
	for i in 20:
		await _adv(s, 30.0)
	print("[video] perdidas: evento de Rasec en curso=%s · 10 min de juego: perdidas %d (antes %d)" % [str(on), cm.missed_count, n_bo])
	_mark("fin")


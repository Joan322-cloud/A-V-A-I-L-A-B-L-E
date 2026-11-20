extends RefCounted
## v0.3.2 · clips de antes/después de los arreglos de Joan (`--shot b2_video:<tema>` con --write-movie; marcas
## [video] inicio/fin para recortar). Solo usa la API que ya existía en la v0.3.1, así el mismo archivo graba el «antes»
## en una copia de la v0.3.1. Temas: ezlaki · espejo · mesa · parpadeo · microondas · lunch. Avances para Joan (solo
## v0.3.2): cola · comodin · reconectando · voces · topico (este con `--turno 2`).

func shots() -> Array[String]:
	return ["b2_video:"]


func shoot(_name: String, arg: String, s: Node) -> void:
	GameState.stop_calm()
	var vz_cb := func(_e: String, _sec: float) -> void: EventBus.vitzo_reacted.emit.call_deferred()
	EventBus.vitzo_reminder.connect(vz_cb)
	match arg:
		"ezlaki": await _ezlaki(s)
		"espejo": await _espejo(s)
		"mesa": await _mesa(s)
		"parpadeo": await _parpadeo(s)
		"microondas": await _microondas(s)
		"lunch": await _lunch(s)
		"cola": await _cola(s)
		"comodin": await _comodin(s)
		"reconectando": await _reconectando(s)
		"voces": await _voces(s)
		"topico": await _topico(s)
	EventBus.vitzo_reminder.disconnect(vz_cb)


func _t(s: Node, sec: float) -> void:
	await s.get_tree().create_timer(sec).timeout


func _mark(what: String) -> void:
	print("[video] %s %d" % [what, Engine.get_frames_drawn()])


func _no_contacts(s: Node) -> void:
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED


func _ezlaki(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var ez: Node = ws.get("ezlak")
	var desk: Node = ws.get("desktop")
	desk.call("open_app", "correo")
	ez.call("open_channel", "#site-updates")
	await _t(s, 1.2)
	_mark("inicio")
	await _t(s, 1.0)
	for who in ["shero", "trainer", "haime"]:
		EventBus.ezlak_post.emit("dm:" + who, who, "@%s ¿tienes un minuto?" % GameState.agent, {"mention": true})
		await _t(s, 1.1)
	EventBus.ezlak_post.emit("#allocations", "rta", "@%s revisa tu AUX" % GameState.agent, {"mention": true})
	EventBus.ezlak_post.emit("#team-familia", "companero", "¿Alguien sabe si hay pizza hoy?", {})
	await _t(s, 1.2)
	Metrics.issue_written_warning("prueba")
	await _t(s, 2.0)
	ws.call("press_accept")
	await _t(s, 1.5)
	ez.call("open_channel", "dm:trainer")
	await _t(s, 2.0)
	_mark("fin")


func _espejo(s: Node) -> void:
	var b: Building = s._building()
	b.go_to_floor(2, "ascensor")
	await _t(s, 0.3)
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
	await s._place(2, pos, rad_to_deg(atan2(axis.x, axis.z)), -0.05)
	Fatigue.set_value(60.0)
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 1.0)
	m.call("interact", s._player())
	await _t(s, 2.6)
	s._player().rotation_degrees.y += 180.0  # te das vuelta
	await _t(s, 1.8)
	s._player().rotation_degrees.y -= 180.0
	await _t(s, 2.0)
	_mark("fin")


func _mesa(s: Node) -> void:
	var b: Building = s._building()
	b.go_to_floor(-1, "cafeteria")
	await _t(s, 0.3)
	var fl := b.floor_node
	var tb := fl.find_child("Mesa1", true, false) as Node3D
	WorldObjects.TaperFlow.set_state(WorldObjects.TaperFlow.CALIENTE)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	var mw := fl.find_child("Microondas", true, false) as Node3D
	if fl.find_child("Comer_0", false, false) == null and mw != null:
		WorldObjects.TaperFlow.spawn_eat_spots(mw)
	Fatigue.set_value(65.0)
	var pos := tb.global_position + Vector3(0, 0, 0.75)
	pos.y = 0.0
	await s._place(-1, pos, 0.0, -0.75)
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 1.8)
	s._player().call("_try_interact")
	await _t(s, 4.2)
	if s._player().seated:
		s._player().stand_up()
	await _t(s, 1.5)
	_mark("fin")


func _parpadeo(s: Node) -> void:
	await s._place(2, Vector3(-2.0, 0, 2.0), 180.0, -0.05)
	Fatigue.set_value(45.0)
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 1.0)
	for i in 3:
		Fatigue.rub_eyes()
		await _t(s, 1.6)
	EventBus.microsleep.emit()
	await _t(s, 2.0)
	_mark("fin")


func _microondas(s: Node) -> void:
	var b: Building = s._building()
	b.go_to_floor(-1, "cafeteria")
	await _t(s, 0.3)
	await s._place(-1, Vector3(6.5, 0, -7.9), 180.0, -0.15)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	var mw := b.floor_node.find_child("Microondas", true, false)
	if mw != null:
		mw.call("hint_text")
	await _t(s, 0.8)
	_mark("inicio")
	# El reloj del lunch, acelerado (1 s de juego por cuadro): en 8 s pasan ~4 min de juego.
	var tt := 0.0
	while tt < 9.0:
		GameState.clock_seconds += 1.0
		await s.get_tree().process_frame
		tt += s.get_process_delta_time()
	_mark("fin")


func _lunch(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await _t(s, 0.2)
	await s._place(-1, Vector3(4.5, 0, -12.0), 180.0, -0.1)
	var hub := PersonajesP5.get_hub(s.get_tree())
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 1.0)
	if hub != null:
		hub.qa.state = QaFeedback.State.PENDIENTE
		hub.qa.call_at = GameState.clock_seconds
	await _t(s, 6.0)
	_mark("fin")


# --- Avances v0.3.2 (API nueva) --------------------------------------------------------------------

func _cm(s: Node) -> ContactManager:
	return s.get_tree().get_first_node_in_group("contact_manager") as ContactManager


## Espera a que cond() se cumpla o pasen `max_s` segundos de juego-real, contados por cuadros. Con --write-movie un
## cuadro tarda ~1 s de pared: los plazos con Time.get_ticks_msec() vencían a los 7 cuadros y el clip salía sin el
## contacto aceptado (v0.3.2: por eso los primeros avances no servían).
func _until(s: Node, cond: Callable, max_s: float) -> bool:
	var w := 0.0
	while not bool(cond.call()):
		if w >= max_s:
			return false
		await s.get_tree().process_frame
		w += s.get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	return true


## Compañeros en lunch (nadie drena la cola) y `n` contactos de ambiente esperando.
func _load_queue(cm: ContactManager, n: int) -> void:
	for c in cm.acd.coworkers():
		(cm.acd.get("_sched") as Dictionary)[c] = [[GameState.clock_seconds - 60.0, GameState.clock_seconds + 7200.0, "lunch"]]
	for i in n:
		cm.acd.ambient.append(GameState.clock_seconds - 60.0 * (i + 1))


## La cola de KipuPay: estás en BO con «Cola: 7 (…)» en Fonex y no te suena nada (solo entran contactos en
## Available); pasas a Available con la cola cargada y entran 3 seguidos (tope de Normal, pausa de 2,5 s); después
## vuelve la pausa normal aunque la cola siga cargada.
func _cola(s: Node) -> void:
	await s._sit_c14()
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var cm := _cm(s)
	GameState.clock_seconds = GameState.hhmm_to_seconds("01:00")
	EventBus.clock_tick.emit(GameState.clock_seconds)
	ws.call("_pick_aux", Metrics.Aux.BO)
	_load_queue(cm, 7)
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 5.0)  # en BO la cola crece y a ti no te suena nada
	print("[video] cola: en BO fase %d · perdidas %d · cola %d" % [cm.phase, cm.missed_count, cm.acd.size()])
	ws.call("_pick_aux", Metrics.Aux.AVAILABLE)  # vuelves con la cola cargada: back-to-back
	for i in 3:
		var ok := await _until(s, func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 10.0)
		print("[video] cola: contacto %d ofrecido=%s seguido=%s cola %d" % [i + 1, str(ok), str(cm.current.get("back_to_back", false)), cm.acd.size()])
		await _t(s, 1.0)
		cm.accept()
		await _t(s, 0.5)
		await _until(s, func() -> bool: return VoiceDirector.current == null, 6.0)  # el cliente termina su línea
		await _t(s, 0.3)
		if cm.phase == ContactManager.Phase.ACTIVE:
			cm.call("_finish", cm.current, true, false, "satisfecho", 5)
	await _t(s, 5.0)  # tope de seguidos: ahora la pausa normal, con la cola todavía cargada
	print("[video] cola: fin fase %d · atendidos %d · perdidas %d · racha %d · solapes %d" % [cm.phase, Metrics.contacts_handled, cm.missed_count, cm.acd.b2b_streak, VoiceDirector.overlaps])
	_mark("fin")


## Comodín: estás en el lunch en la cafetería (piso -1), te quedan 4 min y no llegas: mantienes C, eliges que te marquen
## Available y a quién llamas; el 1.º no contesta, llamas a otro con el mismo comodín, contesta y te lo marca en tu PC;
## al volver a intentarlo: «ya usaste tu comodín este turno».
func _comodin(s: Node) -> void:
	await s._sit_c14()
	_no_contacts(s)
	await _t(s, 0.6)  # el salto de reloj del login no cuenta como minutos fuera de la sala
	var ws := s.get_tree().get_first_node_in_group("workstation")
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await _t(s, 0.3)
	ws.call("_pick_aux", Metrics.Aux.LUNCH)
	await _t(s, 0.3)
	await s._place(-1, Vector3(4.5, 0, -12.0), 180.0, -0.1)
	for i in 41:  # 41 min de lunch ya gastados (de a un minuto, como el reloj)
		GameState.clock_seconds += 60.0
		EventBus.clock_tick.emit(GameState.clock_seconds)
		await s.get_tree().process_frame
	var names := Comodin.coworkers()
	# v0.3.2-core: el clip sigue la regla del panel (solo contesta quien está «activo»). El 1.º está en una llamada: lo
	# dice el panel, lo llamas igual y el aviso dice por qué no contesta; el 2.º está activo y contesta. (Antes un
	# gancho de prueba hacía que no contestara uno que el panel daba por activo y sí uno que estaba en lunch.)
	IABrain.forget_all()
	IABrain.presence_override = {names[0].to_lower(): "llamada", names[1].to_lower(): "activo", names[2].to_lower(): "lunch", names[3].to_lower(): "activo"}
	await _t(s, 1.0)
	_mark("inicio")
	print("[video] comodin: %s %s · inmune=%s · persecución=%s · WW=%d" % [Metrics.aux_name(), Loc.mmss(Metrics.seconds_in_current_aux()), str(Discipline.is_lunch_immune()), str(Pursuit.is_hunting("shero")), Metrics.written_warnings])
	await _t(s, 2.5)
	Comodin.open()
	await _t(s, 2.5)
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await _t(s, 2.5)
	Comodin.choose_coworker(0)  # no contesta
	await _until(s, func() -> bool: return Comodin.phase != "ringing", 12.0)
	await _t(s, 3.0)
	Comodin.choose_coworker(1)  # reintento con el mismo comodín: contesta
	await _until(s, func() -> bool: return Comodin.phase == "", 12.0)
	await _t(s, 4.5)
	print("[video] comodin: usado=%s aux=%s fase='%s' · persecución=%s · WW=%d" % [str(Comodin.used), Metrics.aux_name(), Comodin.phase, str(Pursuit.is_hunting("shero")), Metrics.written_warnings])
	Comodin.open()  # ya gastado
	await _t(s, 3.0)
	IABrain.presence_override = {}
	_mark("fin")
	Comodin.answer_override = Callable()


## Reaparecer: te mata el Trainer en el piso 1 → reapareces SENTADO en C-14, PC abierta, «Reconectando 5…1» → Available.
func _reconectando(s: Node) -> void:
	await s._sit_c14()
	Checkpoints.save_checkpoint("login")
	_no_contacts(s)
	await _t(s, 0.6)  # el salto de reloj del login no cuenta como minutos fuera de la sala
	await s._place(1, Vector3(0.0, 0, 0.0), 90.0, -0.05)
	await _t(s, 1.0)
	_mark("inicio")
	print("[video] reconectando: antes de morir · persecución=%s · WW=%d" % [str(Pursuit.is_hunting("shero")), Metrics.written_warnings])
	await _t(s, 1.5)
	Checkpoints.request_death("training_inasistencia", "", "trainer")
	var ds: Control = s.get_tree().root.find_child("DeathScreen", true, false) as Control
	var seen := await _until(s, func() -> bool: return Checkpoints.death_visible, 25.0)
	await _t(s, 2.5)
	print("[video] reconectando: pantalla de muerte=%s" % str(seen))
	if ds != null:
		ds.call("_reconnect")
	await _until(s, func() -> bool: return Metrics.reconnecting, 6.0)
	var p: Player = s._player()
	print("[video] reconectando: sentado=%s en '%s' piso %d · %s" % [str(p.seated), GameState.seated_at, s._building().current_floor, Reconexion.hud_text()])
	await _until(s, func() -> bool: return not Metrics.reconnecting, 10.0)
	await _t(s, 3.0)
	print("[video] reconectando: AUX %s · sentado en '%s'" % [Metrics.aux_name(), GameState.seated_at])
	_mark("fin")


## Voces: contestas la llamada de un cliente y en el mismo instante caen el evento de Rasec (parlantes), un DM de
## Shero, un compañero, Haime y un murmullo: se oye y se lee UNA línea a la vez (el cliente primero; los que te
## convocan esperan su turno; el compañero y el murmullo vencen en vez de encimarse).
func _voces(s: Node) -> void:
	await s._sit_c14()
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var hub := PersonajesP5.get_hub(s.get_tree())
	var cm := _cm(s)
	_load_queue(cm, 3)
	await _t(s, 1.0)
	_mark("inicio")
	await _until(s, func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 12.0)
	await _t(s, 1.2)
	cm.accept()
	await _t(s, 0.3)
	print("[video] voces: contacto fase %d · voz actual %s" % [cm.phase, VoiceDirector.current.id if VoiceDirector.current != null else "-"])
	if hub != null:
		hub.rasec.call_event()
	EventBus.ezlak_post.emit("dm:shero", "shero", "@%s ¿estás?" % GameState.agent, {"mention": true})
	AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala")
	PersonajesP5.say("Haime", "haime", "pone_coaching", "Te espero en la sala de calibración.")
	VoiceDirector.say("voces/agentes/murmullo", VoiceDirector.P.BARK, "agentes", Callable(), {"text": "(murmullo)", "max_wait": 0.0})
	var said: Array = []
	var cb := func(id: String, spk: String, _p: int) -> void: said.append("%s(%s)" % [spk, id.get_file()])
	VoiceDirector.line_started.connect(cb)
	await _t(s, 17.0)
	VoiceDirector.line_started.disconnect(cb)
	print("[video] voces: %d dichas · %d descartadas · %d solapes · orden %s" % [VoiceDirector.lines_said, VoiceDirector.lines_dropped, VoiceDirector.overlaps, str(said)])
	_mark("fin")


## Tópico (T2): de pie en la esquina de la sala de training que da al tópico, nadie te echa; dentro del tópico sin
## permiso, el enfermero te devuelve al recodo.
func _topico(s: Node) -> void:
	if GameState.turno < 2:
		s.get("_main").call("_start_shift", "Jiroshi", GameState.Mode.NORMAL, 2)  # el tópico abre desde el T2
		await _t(s, 0.6)
	await s._sit_c14()
	await s._place(1, Vector3(12.9, 0, -1.8), 120.0, -0.05)
	await _t(s, 1.0)
	_mark("inicio")
	await _t(s, 5.0)  # antes: a los pocos cuadros te botaba con el mensaje del tópico
	var hub := PersonajesP5.get_hub(s.get_tree())
	var m: Node3D = hub.marker("topico") if hub != null else null
	if m != null:
		s._player().teleport(m.global_position, -90.0)
	await _t(s, 5.0)
	_mark("fin")

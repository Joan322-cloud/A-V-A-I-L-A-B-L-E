class_name RasecControl
extends Node
## Rasec (TM de otro equipo), PLAN §2 #75-78 (cerebro persistente; el actor de la sala es rasec.gd).
## Calvo; con pelo (nodo "Pelo" del modelo v2) solo mientras suena su música o en su evento.
## - Música de madrugada (bloque 03:00-06:00, 1-2 veces por turno, 6-9 min de juego) por los parlantes;
##   se va arrastrando (más lenta) mientras suena.
## - Un mini evento por turno (karaoke, charadas, juego de la silla) con el tema de la fecha real si cae en
##   una (Halloween, Navidad, Día de la Madre…) o el del turno. Para participar: AUX BO, como él lo indica
##   (Metrics.authorize(BO, "tm", "evento_rasec")) e ir al centro de la sala en 2 min de juego. El evento
##   dura 4-5 min de juego y es jugable (cantar a tiempo / adivinar / sentarse en la silla con tu nombre).
##   Rechazarlo ("No, gracias"), no poner BO, no llegar o quedarte de pie en las sillas = advertencia; la
##   2.ª advertencia del turno = muerte `rasec_evento`. El BO del evento baja tu Available (a propósito).
## - Coaching sin permiso / excedido: la pista la lleva P3 (Discipline, ejecutor rasec) y P3 pide la muerte;
##   aquí Rasec aparece en persona en el escalón verbal y se esconde cuando su screamer lo trae a tu cámara.
## Estado con checkpoint: Discipline.counters p5_rasec_adv (advertencias), p5_rasec_evento ("" | "hecho").
## v0.3.1 Q4 (F22): cada evento tiene 3-4 DECISIONES con consecuencia (rasec_eventos.json/decisiones): seguirle el
##   juego, poner una excusa o burlarte. Rasec contesta a cada una y «lo anota» en voz alta; 2 anotaciones en un
##   evento = una advertencia (la 2.ª del turno mata). El ánimo del grupo sube si te burlas y baja si le sigues el
##   juego: los compañeros (AgentesHartos) bostezan, cabecean, uno se duerme, susurran y te escriben.
## v0.3.1 Q4 (F20, C3/C12): convocado, el reloj va a 4x aunque estés sentado (Discipline.hold_slow_clock("rasec"));
##   la ventana de llegada cuenta de pie (sentado cuenta la mitad); tras reaparecer espera ≥ 15 min de juego y nunca
##   convoca dentro de la gracia de 60 s reales (Checkpoints.in_respawn_grace, si existe).

enum State { LIBRE, CONVOCADO, EVENTO, HECHO }

var hub: PersonajesP5 = null
var state: int = State.LIBRE
var kind: String = ""
var window_at: float = 0.0
var waited_since: float = -1.0
var music_on: bool = false
var music_until: float = 0.0
var reminded: bool = false
var hinted_bo: bool = false
var ui: EventoUI = null
var said: Array[String] = []
var last_result: String = ""
## Pruebas/bot: "ok" responde bien, "fail" responde mal, "" = el jugador.
var forced_play: String = ""
var _music_done: Array[String] = []
var _player: AudioStreamPlayer = null
var _token: int = 0
var _rng := RandomNumberGenerator.new()
var hartos: AgentesHartos = null
var notes: int = 0  # anotaciones de Rasec en el evento en curso (F22)
var decisions_log: Array = []  # [{pregunta, tipo}] del evento (pruebas)
var _warned_notes: bool = false
var _did_comun: bool = false
var window_stood: float = 0.0  # segundos de juego de ventana cumplidos (de pie = 1, sentado = 0,5)
var _window_last: float = 0.0
var _respawn_block_until: float = -INF


func _cfg() -> Dictionary:
	return DataLoader.dict("rasec_eventos")


func _ready() -> void:
	_rng.seed = 909 + GameState.turno * 13
	_player = AudioStreamPlayer.new()
	_player.name = "MusicaRasec"
	_player.bus = "Musica"  # v0.3.2: es música (baja bajo las voces con el VoiceDirector)
	_player.volume_db = -14.0
	add_child(_player)
	EventBus.ezlak_quick_reply.connect(_on_quick_reply)
	EventBus.discipline_step.connect(_on_discipline_step)
	EventBus.death_sequence_started.connect(_on_death)
	EventBus.respawned.connect(_on_respawned)
	EventBus.shift_ended.connect(stop_music)
	hartos = AgentesHartos.new()
	hartos.name = "AgentesHartos"
	hartos.ctl = self
	add_child(hartos)


func warnings() -> int:
	return int(PersonajesP5.counter("p5_rasec_adv", 0))


func event_done() -> bool:
	return str(PersonajesP5.counter("p5_rasec_evento", "")) == "hecho"


func event_cfg() -> Dictionary:
	return ((_cfg().get("turnos", {}) as Dictionary).get(str(GameState.turno), {}) as Dictionary)


func event_clock() -> float:
	var h := str(event_cfg().get("hora", ""))
	return GameState.hhmm_to_seconds(h) if h != "" else -1.0


## Tema del evento: la fecha real si cae en uno de los temas; si no, el del turno.
func theme() -> Dictionary:
	var temas: Array = _cfg().get("temas", [])
	var forced := str(GameState.flags.get("p5_tema", ""))
	var by_id: Dictionary = {}
	for t in temas:
		by_id[str((t as Dictionary).get("id", ""))] = t
	if forced != "" and by_id.has(forced):
		return by_id[forced]
	var d := Time.get_date_dict_from_system()
	var md := "%02d-%02d" % [int(d.get("month", 1)), int(d.get("day", 1))]
	for t in temas:
		var td := t as Dictionary
		var a := str(td.get("desde", ""))
		var b := str(td.get("hasta", ""))
		if a != "" and b != "" and md >= a and md <= b:
			return td
	return by_id.get(str((_cfg().get("tema_por_turno", {}) as Dictionary).get(str(GameState.turno), "aniversario")), {})


func theme_name() -> String:
	return Loc.pick(theme().get("nombre", {"es": "la campaña", "en": "the campaign"}))


func _process(_delta: float) -> void:
	if not GameState.logged_in or Checkpoints.dying or not GameState.running:
		return
	var now := GameState.clock_seconds
	_tick_music(now)
	match state:
		State.LIBRE:
			var at := event_clock()
			if at < 0.0 or event_done() or now < at:
				return
			if now < _respawn_block_until or _in_grace():
				return  # F20/C12: tras reaparecer no te convoca enseguida
			if hub.can_interrupt(false, "rasec"):
				call_event()
			elif Discipline.is_lunch_immune("rasec"):
				waited_since = -1.0  # v0.3.2: el lunch no cuenta como «no hubo hueco»: el evento te espera
			else:
				if waited_since < 0.0:
					waited_since = now
				if now - waited_since >= float(_cfg().get("retraso_max_min", 30.0)) * 60.0:
					state = State.HECHO  # no hubo hueco: el evento se hizo sin ti (sin advertencia)
		State.CONVOCADO:
			_tick_called(now)


# --- música ---------------------------------------------------------------------------------------

func _tick_music(now: float) -> void:
	var m: Dictionary = _cfg().get("musica", {})
	if music_on:
		_player.pitch_scale = maxf(_player.pitch_scale - 0.00006, 0.78)  # se arrastra
		if now >= music_until:
			stop_music()
		return
	if hub.busy != "":
		return
	for h in (m.get("horas", {}) as Dictionary).get(str(GameState.turno), []):
		var hs := str(h)
		if _music_done.has(hs):
			continue
		var t := GameState.hhmm_to_seconds(hs)
		if now >= t:
			_music_done.append(hs)
			var dur: Array = m.get("duracion_min", [6.0, 9.0])
			if now < t + float(dur[1]) * 60.0:
				start_music(_rng.randf_range(float(dur[0]), float(dur[1])))
			return


## Rasec pone música en los parlantes `minutes` minutos de juego (también pruebas y capturas).
func start_music(minutes: float) -> void:
	music_on = true
	music_until = GameState.clock_seconds + minutes * 60.0
	var m: Dictionary = _cfg().get("musica", {})
	var path := AudioManager.resolve(str(m.get("slot", "musica/rasec_madrugada")))
	if path == "":
		path = AudioManager.resolve(str(m.get("slot_respaldo", "musica/hold_kipupay_parlantes")))
	if path != "":
		var st := load(path) as AudioStream
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		_player.stream = st
		_player.pitch_scale = 0.96
		_player.play()
	PersonajesP5.say("Rasec", "rasec", "musica_on", PersonajesP5.line("lineas_rasec", "musica_on"))
	EventBus.subtitle.emit("parlantes", PersonajesP5.line("lineas_rasec", "musica_pa"), 4.0)
	hub.rasec_music.emit(true)


func stop_music() -> void:
	if not music_on:
		return
	music_on = false
	_player.stop()
	if GameState.running and not Checkpoints.dying:
		PersonajesP5.say("Rasec", "rasec", "musica_off", PersonajesP5.line("lineas_rasec", "musica_off"))
	hub.rasec_music.emit(false)


# --- evento ---------------------------------------------------------------------------------------

func _activity_name(k: String) -> String:
	return PersonajesP5.line("lineas_rasec", "actividad_" + k)


## Rasec convoca su mini evento ahora (también pruebas y capturas).
func call_event(p_kind: String = "") -> void:
	kind = p_kind if p_kind != "" else str(event_cfg().get("tipo", "karaoke"))
	state = State.CONVOCADO
	window_at = GameState.clock_seconds
	window_stood = 0.0
	_window_last = GameState.clock_seconds
	reminded = false
	hinted_bo = false
	_hold_clock(true)
	var mins := float(_cfg().get("ventana_min", 2.0)) * 2.0 + float(_cfg().get("duracion_min", 4.5)) + 3.0
	Metrics.authorize(Metrics.Aux.BO, "tm", "evento_rasec", mins)
	var vars := {"agente": GameState.agent, "tema": theme_name(), "actividad": _activity_name(kind)}
	PersonajesP5.post("#site-updates", "rasec", PersonajesP5.line("lineas_rasec", "evento_anuncio", vars), {"tipo": "rasec_evento", "evento": kind})
	PersonajesP5.post("dm:rasec", "rasec", PersonajesP5.line("lineas_rasec", "evento_dm", vars), {"tipo": "rasec_evento", "mention": true, "typing_s": 1.2, "quick_replies": ["voy", "no_gracias"]})
	PersonajesP5.pa(PersonajesP5.line("lineas_rasec", "evento_pa", vars), "rasec", "evento_pa")
	hub.rasec_event_called.emit(kind)


func arrived() -> bool:
	return hub.dist_to_marker("evento_rasec", 2) <= float(_cfg().get("radio_m", 3.2))


func _tick_called(now: float) -> void:
	var here := arrived()
	if here and Metrics.aux == Metrics.Aux.BO:
		_start_event()
		return
	if here and not hinted_bo:
		hinted_bo = true
		_say("evento_sin_bo")
	var win := PersonajesP5.plazo(float(_cfg().get("ventana_min", 2.0)))
	# F20 (3): la ventana cuenta de pie; sentado (leyendo el DM) cuenta la mitad.
	var dt := clampf(now - _window_last, 0.0, 600.0)
	_window_last = now
	window_stood += dt * (0.5 if GameState.seated_at != "" else 1.0)
	if not reminded and window_stood >= win * 0.5:
		reminded = true
		PersonajesP5.pa(PersonajesP5.line("lineas_rasec", "evento_recordatorio", {"agente": GameState.agent}), "rasec", "evento_recordatorio")
	if window_stood >= win:
		warn("sin_bo" if here else "tarde")


## Advertencia de Rasec (rechazo, tarde, sin_bo, fallo). La 2.ª del turno mata (rasec_evento).
func warn(reason: String) -> void:
	var n := warnings() + 1
	PersonajesP5.set_counter("p5_rasec_adv", n)
	last_result = "advertencia_" + reason
	hub.rasec_warning.emit(n, reason)
	if n >= 2:
		_say("advertencia_final")
		PersonajesP5.post("dm:rasec", "rasec", PersonajesP5.line("lineas_rasec", "advertencia_final"), {"tipo": "rasec_advertencia", "n": n, "mention": true})
		_token += 1
		_end_event_ui()
		_hold_clock(false)
		Checkpoints.request_death("rasec_evento", reason, "rasec")
		return
	var key := "advertencia_" + reason
	var text := PersonajesP5.line("lineas_rasec", key, {"agente": GameState.agent})
	_say(key)
	PersonajesP5.post("dm:rasec", "rasec", text, {"tipo": "rasec_advertencia", "n": n, "motivo": reason, "mention": true})
	if state == State.CONVOCADO:
		window_at = GameState.clock_seconds  # otra ventana: te sigue esperando
		window_stood = 0.0
		_window_last = GameState.clock_seconds
		reminded = false


func _on_quick_reply(ch: String, id: String) -> void:
	if ch != "dm:rasec":
		return
	if state != State.CONVOCADO:
		return
	if id == "no_gracias":
		warn("rechazo")
	elif id == "voy":
		PersonajesP5.post("dm:rasec", "rasec", PersonajesP5.line("lineas_rasec", "evento_voy"), {"tipo": "respuesta_npc", "typing_s": 1.0})


func _start_event() -> void:
	state = State.EVENTO
	_hold_clock(false)
	_token += 1
	var tok := _token
	notes = 0
	_warned_notes = false
	_did_comun = false
	decisions_log.clear()
	hub.busy = "evento"
	said.clear()
	var pl := hub.player()
	if pl != null:
		pl.input_locked = true
	hub.rasec_event_started.emit(kind)
	ui = EventoUI.new()
	ui.name = "EventoUI"
	ui.forced = forced_play
	add_child(ui)
	ui.open(kind, theme_name())
	_event_music(true)
	var t0 := GameState.clock_seconds
	var vars := {"tema": theme_name(), "agente": GameState.agent}
	_say("inicio_" + kind, vars)
	if hartos != null:
		hartos.start()
	await PersonajesP5.wait(self, 3.0)
	if not await _decisions_at(tok, "inicio"):
		return
	var ok := true
	match kind:
		"karaoke":
			ok = await _karaoke(tok)
		"charadas":
			ok = await _charadas(tok)
		"sillas":
			ok = await _sillas(tok)
	if tok != _token or Checkpoints.dying:
		return
	if not ok:
		return  # _sillas ya advirtió (y quizá mató); el evento sigue convocado o terminó
	if not await _decisions_at(tok, "final"):
		return
	# Completa los 4-5 min de juego del evento (de pie en BO: el Available baja, a propósito).
	# Mientras tanto, la fiesta sigue sola: frases de Rasec y acotaciones cada ~6 s (lineas_rasec relleno_N).
	var dur := float(_cfg().get("duracion_min", 4.5)) * 60.0
	var waited := 0.0
	var next_fill := 2.0
	var fill := 1
	while GameState.clock_seconds - t0 < dur and tok == _token and not Checkpoints.dying:
		await PersonajesP5.wait(self, 0.25)
		waited += 0.25
		if waited >= next_fill and tok == _token:
			next_fill = waited + 6.0
			if not _did_comun:
				_did_comun = true
				if not await _decisions_at(tok, "relleno"):
					return
				if GameState.agent != "Ttoom":
					_say("q4_dormido")
				continue
			_filler(fill)
			fill = fill % 6 + 1
	if tok != _token or Checkpoints.dying:
		return
	_finish_event(true)


## Relleno del evento: las acotaciones ("[…]") van en la pantalla del evento; lo demás lo dice Rasec.
func _filler(n: int) -> void:
	var key := "relleno_%d" % n
	var text := PersonajesP5.line("lineas_rasec", key, {"agente": GameState.agent})
	if text == "":
		return
	if text.begins_with("["):
		said.append(key)
		if ui != null and is_instance_valid(ui):
			ui.show_text(text)
	else:
		if ui != null and is_instance_valid(ui):
			ui.show_text("")
		_say(key)
	var actor := get_tree().get_first_node_in_group("p5_rasec_actor")
	if actor != null and actor.has_method("mime"):
		actor.call("mime")


func _finish_event(took_part: bool) -> void:
	_token += 1
	if notes == 1:
		_say("q4_anotado_1", {"agente": GameState.agent})
	if hartos != null:
		if hartos.mood >= 2:
			_say("q4_grupo_bien")
		elif hartos.mood <= -2:
			_say("q4_grupo_mal")
	if _did_comun and GameState.agent != "Juan":
		_say("q4_juan_anotado")
	if hartos != null:
		hartos.finish()
	_say("fin_evento")
	_end_event_ui()
	Metrics.revoke("tm")
	PersonajesP5.set_counter("p5_rasec_evento", "hecho")
	state = State.HECHO
	last_result = "participo" if took_part else last_result
	hub.rasec_event_finished.emit(kind, took_part)


## Música del evento (o la de madrugada de respaldo) mientras dura.
func _event_music(on: bool) -> void:
	if not on:
		if not music_on:
			_player.stop()
		_player.stream_paused = false
		return
	var cfg: Dictionary = _cfg().get(kind, {})
	var path := AudioManager.resolve(str(cfg.get("slot", "")))
	if path == "":
		path = AudioManager.resolve(str((_cfg().get("musica", {}) as Dictionary).get("slot_respaldo", "musica/hold_kipupay_parlantes")))
	if path != "":
		var st := load(path) as AudioStream
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		_player.stream = st
		_player.pitch_scale = 1.0
		_player.volume_db = -8.0
		_player.play()


func _end_event_ui() -> void:
	_event_music(false)
	if hartos != null and state != State.EVENTO:
		hartos.stop()
	_player.volume_db = -14.0
	if hub != null and hub.busy == "evento":
		hub.busy = ""
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	ui = null
	var pl := hub.player() if hub != null else null
	if pl != null and not Checkpoints.dying:
		pl.input_locked = false


func _karaoke(tok: int) -> bool:
	var cfg: Dictionary = _cfg().get("karaoke", {})
	var verses: Array = cfg.get("versos", [])
	sung.clear()
	for i in verses.size():
		if tok != _token:
			return false
		var slow := i == verses.size() - 1
		if slow:
			_player.pitch_scale = KaraokeVoz.SLOW
			EventBus.subtitle.emit("rasec", PersonajesP5.line("lineas_rasec", "karaoke_lento"), 2.4)
		# v0.3.2 (Joan: «lo que se canta debe corresponder a los subtítulos»): el verso se CANTA. La letra que se ve es
		# la de la voz, entra en un compás de la pista y se va pintando a medida que suena.
		var sung_s: float = await _sing_verse(tok, i, Loc.pick(verses[i]))
		if tok != _token:
			return false
		var window := float(cfg.get("ventana_s", 2.2)) * (1.6 if slow else 1.0)
		if sung_s > 0.0 and _real_time():
			window = maxf(window, sung_s + 0.3)  # se canta CON el verso: la ventana dura lo que dura el verso
		var sang: bool = await ui.press(tr("P5_EVENT_SING"), window)
		if tok != _token:
			return false
		if sung_s > 0.0:
			# Cantar a tiempo cierra la ventana a mitad del verso: Rasec comenta cuando el verso TERMINA (si no, a los
			# 1,6 s de su «¡Eso!» ya salía la letra del verso siguiente con este todavía sonando).
			await _quiet(tok, sung_s + 1.0)
			if tok != _token:
				return false
		_say("karaoke_bien" if sang else "karaoke_mal")
		await PersonajesP5.wait(self, 1.6)
		if i == int(verses.size() / 2.0) and not await _decisions_at(tok, "mitad"):
			return false
	return true


## ¿El juego corre a velocidad real? (el audio siempre: con el reloj acelerado no se puede esperar a una voz)
func _real_time() -> bool:
	return Engine.time_scale <= 1.5


## v0.3.2: versos cantados en este evento (pruebas): [n.º de verso, slot de la voz, letra en pantalla, línea del
## VoiceDirector, posición de la pista (s) al arrancar la voz].
var sung: Array = []


## Canta el verso `i`: pone la letra en pantalla con sus marcas de tiempo, espera a que nadie esté hablando (el
## comentario de Rasec del verso anterior) y al próximo compás de la pista, y arranca la voz por el VoiceDirector (una
## voz a la vez, la música baja debajo como con cualquier voz). Devuelve los segundos de canto (0 = no hay voz para
## ese verso o no coincide con la letra: queda solo el texto, como antes de la v0.3.2).
## Con el juego acelerado (bots y pruebas a ×8: Engine.time_scale > 1,5) no se espera ni al silencio ni al compás: el
## audio va en tiempo real y el evento no; la voz se pide igual (mismo grupo: el verso nuevo releva al anterior, así
## lo que suena es siempre el verso que se lee).
func _sing_verse(tok: int, i: int, text: String) -> float:
	var info := KaraokeVoz.verse(i)
	var vd := get_node_or_null("/root/VoiceDirector")
	if ui == null or not is_instance_valid(ui):
		return 0.0
	if vd == null or not KaraokeVoz.has_voice(i) or str(info.get("texto", "")) != text:
		ui.show_text(text)
		return 0.0
	ui.show_lyric(text, info.get("marcas", []))
	if _real_time():
		await _quiet(tok)  # que Rasec termine su comentario del verso anterior
		# …y cualquier otra línea importante que esté sonando (un relleno no: el verso lo corta)
		var left := 3.0
		while left > 0.0 and tok == _token and vd.get("current") != null and bool((vd.get("current") as Object).get("must")):
			await get_tree().process_frame
			left -= get_process_delta_time()
		if tok != _token or ui == null or not is_instance_valid(ui):
			return 0.0
		var st := _player.stream
		if _player.playing and st != null and st.get_length() > 0.0:
			var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix()
			var wait_s := KaraokeVoz.bar_wait(pos, st.get_length()) / maxf(_player.pitch_scale, 0.1)
			await get_tree().create_timer(wait_s * Engine.time_scale).timeout  # segundos reales: la pista no se escala
		if tok != _token or ui == null or not is_instance_valid(ui):
			return 0.0
	var line: Object = vd.call("say", KaraokeVoz.slot(i), VoiceDirector.P.DIRECTO, "rasec", Callable(), {"group": "karaoke", "dedupe": false})
	ui.sing(line)
	sung.append([i, KaraokeVoz.slot(i), ui.shown_text(), line, _player.get_playback_position() if _player.playing else -1.0])
	return float(info.get("canto", info.get("dur", 0.0)))


func _charadas(tok: int) -> bool:
	var cfg: Dictionary = _cfg().get("charadas", {})
	for r in cfg.get("rondas", []):
		if tok != _token:
			return false
		var rd := r as Dictionary
		ui.show_text(Loc.pick(rd.get("mimica", {})))
		var hub_rasec := get_tree().get_first_node_in_group("p5_rasec_actor")
		if hub_rasec != null and hub_rasec.has_method("mime"):
			hub_rasec.call("mime")
		var opts: Array = []
		for o in rd.get("opciones", []):
			opts.append(Loc.pick(o))
		var pick: int = await ui.choose(opts, 9.0, int(rd.get("correcta", 0)))
		if tok != _token:
			return false
		if pick == int(rd.get("correcta", 0)):
			var t := Loc.fmt(Loc.pick(rd.get("si_bien", {})), {"agente": GameState.agent})
			PersonajesP5.say("Rasec", "rasec", "charada_bien", t)
			ui.show_text(t)
		else:
			var t2 := Loc.pick(cfg.get("si_mal", {}))
			PersonajesP5.say("Rasec", "rasec", "charada_mal", t2)
			ui.show_text(t2)
		await PersonajesP5.wait(self, 2.4)
		if r == (cfg.get("rondas", []) as Array)[0] and not await _decisions_at(tok, "mitad"):
			return false
	return true


func _sillas(tok: int) -> bool:
	var cfg: Dictionary = _cfg().get("sillas", {})
	var n_chairs := int(cfg.get("sillas", 5))
	var rounds := int(cfg.get("rondas", 2))
	var names: Array = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			names.append(a)
	names.append("C-13")
	for r in rounds:
		if tok != _token:
			return false
		var chairs: Array = names.slice(0, maxi(n_chairs - 1 - r, 1))
		chairs.insert(_rng.randi_range(0, chairs.size()), GameState.agent)
		var mr: Array = cfg.get("musica_s", [4.0, 6.5])
		_player.pitch_scale = 1.0 - 0.18 * r
		if not _player.playing and _player.stream != null:
			_player.play()
		ui.show_text(tr("P5_EVENT_CHAIRS_MUSIC"))
		var actor := get_tree().get_first_node_in_group("p5_rasec_actor")
		if actor != null and actor.has_method("chairs_round"):
			actor.call("chairs_round", chairs)
		await PersonajesP5.wait(self, _rng.randf_range(float(mr[0]), float(mr[1])))
		if tok != _token:
			return false
		_player.stream_paused = true
		_say("sillas_para")
		var mine := chairs.find(GameState.agent)
		var pick: int = await ui.choose(chairs, float(cfg.get("sentarse_s", 4.0)), mine)
		_player.stream_paused = false
		if tok != _token:
			return false
		if pick != mine:
			_end_event_ui()
			state = State.CONVOCADO
			window_at = GameState.clock_seconds
			warn("fallo")
			if state == State.CONVOCADO and not Checkpoints.dying:
				# Primera advertencia: vuelve a convocarte (pon BO y vuelve al centro… ya estás ahí).
				await PersonajesP5.wait(self, 1.0)
			return false
		_say("sillas_bien")
		await PersonajesP5.wait(self, 1.8)
		if r == 0 and not await _decisions_at(tok, "mitad"):
			return false
	_say("sillas_ultima")
	await PersonajesP5.wait(self, 2.4)
	return true


func _say(key: String, vars: Dictionary = {}) -> void:
	said.append(key)
	var text := PersonajesP5.line("lineas_rasec", key, vars)
	if GameState.current_floor == 2:
		PersonajesP5.say("Rasec", "rasec", key, text)
	else:
		PersonajesP5.pa(text, "rasec", key)


# --- coaching (pistas de P3) y muerte -------------------------------------------------------------

func _on_discipline_step(track: String, step: int, info: Dictionary) -> void:
	var rasec := str(info.get("ejecutor", "")) == "rasec" or track in ["coaching", "coaching_exceso", "coaching_sin_permiso"]
	if not rasec or step < 2 or step > 3:
		return
	var key := "en_persona_exceso" if track == "coaching_exceso" else ("en_persona_ww" if step == 3 else "en_persona_coaching")
	var actor := get_tree().get_first_node_in_group("p5_rasec_actor")
	if GameState.current_floor == 2 and actor != null and actor.has_method("come_to_player"):
		actor.call("come_to_player", PersonajesP5.line("lineas_rasec", key), key)
	else:
		PersonajesP5.pa(PersonajesP5.line("lineas_rasec", key), "rasec", key)


func _on_death(_c: String, killer: String, _d: String) -> void:
	_token += 1
	_hold_clock(false)
	if state == State.EVENTO:
		state = State.CONVOCADO
	_end_event_ui()
	if killer == "rasec":
		_player.stop()  # su screamer trae su propia música, que se corta en seco
	if state == State.CONVOCADO:
		Metrics.revoke("tm")
	music_on = false
	_player.stop()


func _on_respawned(_k: String) -> void:
	_token += 1
	_hold_clock(false)
	if hartos != null:
		hartos.stop()
	# F20 (C12): después de reaparecer Rasec espera al menos 15 min de juego para convocarte.
	_respawn_block_until = GameState.clock_seconds + float(_cfg().get("espera_tras_reaparecer_min", 15.0)) * 60.0
	if ui != null and is_instance_valid(ui):
		_end_event_ui()
	state = State.HECHO if event_done() else State.LIBRE
	waited_since = -1.0
	music_on = false
	# Las músicas cuyo horario ya pasó no se repiten tras volver al checkpoint.
	var now := GameState.clock_seconds
	_music_done.clear()
	for h in ((_cfg().get("musica", {}) as Dictionary).get("horas", {}) as Dictionary).get(str(GameState.turno), []):
		if GameState.hhmm_to_seconds(str(h)) <= now:
			_music_done.append(str(h))
	hub.rasec_music.emit(false)


# --- v0.3.1 Q4 (F22): decisiones con consecuencia ----------------------------------------------------

## Las decisiones del evento en el momento `momento` (inicio | mitad | final | relleno). false = el evento se cortó.
func _decisions_at(tok: int, momento: String) -> bool:
	var all: Dictionary = _cfg().get("decisiones", {})
	var lst: Array = (all.get(kind, []) as Array) + (all.get("comun", []) as Array)
	for d in lst:
		var dd := d as Dictionary
		if str(dd.get("en", "")) != momento or str(dd.get("excluye", "")) == GameState.agent:
			continue
		if not await _decision(tok, dd):
			return false
	return tok == _token and not Checkpoints.dying


func _decision(tok: int, d: Dictionary) -> bool:
	if ui == null or not is_instance_valid(ui) or tok != _token:
		return false
	var vars := {"agente": GameState.agent, "tema": theme_name()}
	var qk := str(d.get("pregunta", ""))
	await _quiet(tok)  # v0.3.2-core: la pregunta suena cuando sale en pantalla (no en cola detrás de lo anterior)
	if ui == null or not is_instance_valid(ui) or tok != _token or Checkpoints.dying:
		return false
	_say(qk, vars)
	var opts: Array = d.get("opciones", [])
	var texts: Array = []
	var seguir := 0
	for i in opts.size():
		texts.append(Loc.pick((opts[i] as Dictionary).get("texto", {})))
		if str((opts[i] as Dictionary).get("tipo", "")) == "seguir":
			seguir = i
	var pick: int = await ui.decide(PersonajesP5.line("lineas_rasec", qk, vars), texts, float(_cfg().get("decision_s", 11.0)), seguir)
	if tok != _token or Checkpoints.dying:
		return false
	var tipo := "silencio"
	var anota := true
	var grupo := 0
	if pick >= 0 and pick < opts.size():
		var o: Dictionary = opts[pick]
		tipo = str(o.get("tipo", ""))
		anota = bool(o.get("anota", false))
		grupo = int(o.get("grupo", 0))
		_say(str(o.get("respuesta", "")), vars)
	else:
		_say("q4_timeout", vars)
	decisions_log.append({"pregunta": qk, "tipo": tipo, "anota": anota})
	if hartos != null:
		hartos.react(tipo if tipo != "silencio" else "excusa", grupo)
	var actor := get_tree().get_first_node_in_group("p5_rasec_actor")
	if actor != null and actor.has_method("mime"):
		actor.call("mime")
	if anota:
		notes += 1
		if ui != null and is_instance_valid(ui):
			ui.set_notes(notes)
	await PersonajesP5.wait(self, 3.2)
	await _quiet(tok)  # y su respuesta a lo que elegiste termina antes de seguir
	if tok != _token or Checkpoints.dying:
		return false
	if notes >= int(_cfg().get("anotaciones_advertencia", 2)) and not _warned_notes:
		_warned_notes = true
		_say("q4_anotado_2", vars)
		await PersonajesP5.wait(self, 2.6)
		if tok != _token:
			return false
		warn("anotado")
		if Checkpoints.dying or tok != _token:
			return false
	return true


## v0.3.2-core: a velocidad real, espera (como mucho `max_s`) a que Rasec termine lo que está diciendo y lo que tiene
## en cola. El guion del evento iba más rápido que su voz (pregunta + respuesta + «¡Eso! Más fuerte» cada 2-3 s contra
## líneas de 4-6 s): las líneas se apilaban en el VoiceDirector y sus preguntas vencían sin sonar. Acelerado (bots,
## pruebas) no espera: el evento dura lo mismo en tiempo de juego.
func _quiet(tok: int, max_s: float = 9.0) -> void:
	if Engine.time_scale > 1.5:
		return
	var left := max_s
	while left > 0.0 and tok == _token and is_inside_tree() and not Checkpoints.dying and (VoiceDirector.speaker_busy("rasec") or VoiceDirector.speaker_busy("parlantes")):
		await get_tree().process_frame
		left -= get_process_delta_time()


func _hold_clock(on: bool) -> void:
	if Discipline.has_method("hold_slow_clock"):
		Discipline.call("hold_slow_clock", "rasec", on)


func _in_grace() -> bool:
	return Checkpoints.has_method("in_respawn_grace") and bool(Checkpoints.call("in_respawn_grace"))

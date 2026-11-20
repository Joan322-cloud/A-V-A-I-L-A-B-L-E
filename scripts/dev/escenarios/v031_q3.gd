## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de la v0.3.1 · Q3 (audio y Ezlaki). `--escenario q3` (o v031_q3) los corre todos.
##  q3_p6_audio        todo audio que piden el código y los datos existe en ES y EN (el escáner de p6_audio) +
##                     los slots fijos de C2, las 5 voces re-sintetizadas y ningún generador sintético en el código
##  q3_silencio        un slot que falta suena en SILENCIO (sin pitido) y queda en MISSING.txt
##  q3_musica          capas de tensión por presión y persecución, en fase; silencio en la azotea; cama del feedback
##  q3_lluvia          camas largas (≥ 240 s, coprimas), Weather adoptado, perfiles por zona, eventos sueltos
##  q3_pasos           superficies (alfombra, porcelanato, vinílico, escalera, exterior, deck), caminar/correr ≥ 6
##                     clips, cadencia del head bob, pan izquierda/derecha, aterrizaje del salto
##  q3_rasec_degrada   la música de Rasec se desafina y se ensucia con el tiempo
##  q3_ezlaki_botones  respuestas rápidas enteras (sin cortar) y vista previa
##  q3_ezlaki_escribir texto libre → intención → respuesta del personaje; Ack/Rooms/tópico escritos; excusas e
##                     insultos a Shero; spam; canales de solo lectura; nunca rompe
##  q3_ezlaki_variedad un turno entero: el doble de publicaciones, 0 líneas de NPC repetidas por canal
##  q3_ezlaki_limitador 30 avisos seguidos de «de pie en Live» → 1 en la ventana de 20 s
##  q3_entorno_q5      rumor de la autopista del este colgado del «Trafico» de Q5 (más fuerte cerca de la fachada,
##                     camiones sueltos) y siseo de las zonas «ventilacion_*» del piso 2
##  q3_ezlaki_capturas tags de #allocations con la captura de la vista de adherencia (fila del infractor, identidades
##                     del juego, nada real), reacciones y ampliar con clic

const C2_SLOTS: Array[String] = [
	"sfx/shero_pasos_intensos", "sfx/persecucion_latido_loop", "sfx/persecucion_drone_loop", "musica/feedback_haime_loop",
	"musica/tension_capa_1", "musica/tension_capa_2", "musica/tension_capa_3", "musica/tension_capa_4",
	"sfx/rasec_cabina_golpe", "sfx/monitor_rompe", "sfx/vitzo_arrastre_loop", "sfx/estatica_desconexion",
	"ambiente/lluvia", "ambiente/lluvia_cama_b", "ambiente/lluvia_gota", "ambiente/lluvia_rafaga", "ambiente/lluvia_canaleta",
	"sfx/respiracion_carrera_loop", "musica/rasec_animo_forzado",
]
const VOCES_Q3: Array[String] = ["voces/shero/convocar", "voces/shero/shero_ezlak_profesional", "voces/shero/shero_unete_sala", "voces/sistema/tut_1", "voces/sistema/tut_3"]
const SURFACES: Array[String] = ["alfombra", "porcelanato", "vinilico", "escalera", "exterior", "deck"]


func escenarios() -> Array[String]:
	return ["q3_p6_audio", "q3_silencio", "q3_musica", "q3_lluvia", "q3_pasos", "q3_rasec_degrada", "q3_ezlaki_botones",
		"q3_ezlaki_escribir", "q3_ezlaki_variedad", "q3_ezlaki_limitador", "q3_ezlaki_capturas", "q3_entorno_q5"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"q3_p6_audio": await _p6_audio(t)
		"q3_silencio": await _silencio(t)
		"q3_musica": await _musica(t)
		"q3_lluvia": await _lluvia(t)
		"q3_pasos": await _pasos(t)
		"q3_rasec_degrada": await _rasec(t)
		"q3_ezlaki_botones": await _botones(t)
		"q3_ezlaki_escribir": await _escribir(t)
		"q3_ezlaki_variedad": await _variedad(t)
		"q3_ezlaki_limitador": await _limitador(t)
		"q3_ezlaki_capturas": await _capturas(t)
		"q3_entorno_q5": await _entorno_q5(t)


func _p6() -> GDScript:
	return load("res://scripts/dev/escenarios/p6_audio.gd") as GDScript


# --- auditoría ----------------------------------------------------------------------------------------------

func _p6_audio(t: Node) -> void:
	var p6 := _p6()
	var req: Dictionary = p6.call("requested_slots")
	var missing: Array[String] = []
	for slot in req.keys():
		if not bool(p6.call("slot_exists", str(slot))):
			missing.append(str(slot))
	t.check(missing.is_empty(), "todo audio pedido existe (%d pedidos, faltan %s)" % [req.size(), str(missing)])
	for s in C2_SLOTS:
		t.check(AudioManager.has_slot(s), "slot fijo C2: " + s)
	for v in VOCES_Q3:
		t.check(AudioManager.has_slot(v) and AudioManager.has_slot(str(p6.call("en_slot", v))), "voz re-sintetizada ES y EN: " + v)
	for v in VOCES_Q3:
		var txt: Dictionary = (DataLoader.dict("audio_index").get("textos", {}) as Dictionary).get(v, {})
		t.check(not str(txt).contains("Ezlak ") and not str(txt).contains("Ezlak.") and not str(txt).to_lower().contains("konzentrimance"), "texto nuevo de %s (Ezlaki / Konzentramance)" % v)
	# ningún generador de tonos sintéticos en el código de audio (B8): ni pitido de respaldo ni ding-dong de senos
	for path in ["res://scripts/autoload/audio_manager.gd", "res://scripts/core/shero_presence.gd", "res://scripts/autoload/audio_director.gd", "res://scripts/audio/music_director.gd", "res://scripts/audio/rain_engine.gd"]:
		var src := FileAccess.get_file_as_string(path)
		t.check(not src.contains("_synth_beep") and not src.contains("_make_chime") and not src.contains("sin(TAU"), "sin tonos sintéticos en " + path.get_file())
	# ningún .wav sintético referenciado: todo sfx es ogg
	var wavs: Array[String] = []
	for slot in req.keys():
		var path := AudioManager.resolve(str(slot), false)
		if path.ends_with(".wav"):
			wavs.append(path)
	t.check(wavs.is_empty(), "ningún .wav referenciado (%s)" % str(wavs))
	var d := DirAccess.open("res://assets/audio/sfx")
	var wav_files := 0
	for f in d.get_files():
		if f.ends_with(".wav"):
			wav_files += 1
	t.check(wav_files == 0, "sin .wav en sfx/ (%d)" % wav_files)


func _silencio(t: Node) -> void:
	var am := AudioManager
	var before := am.missing_requested().size()
	am.play_sfx("q3_slot_que_no_existe")
	var b := str(am.last_sfx.get("bus", "Sala"))
	var pool: Array = am.get("_sfx_pool")[b]
	var playing_wav := false
	for p in pool:
		if (p as AudioStreamPlayer).playing and (p as AudioStreamPlayer).stream is AudioStreamWAV:
			playing_wav = true
	t.check(not playing_wav, "un sfx que falta no suena (ni pitido)")
	am.play_voice("shero", "q3_voz_que_no_existe", "")
	var v := am.get_node("Voz_Sala") as AudioStreamPlayer
	t.check(not (v.playing and v.stream is AudioStreamWAV), "una voz que falta no suena")
	am.play_music("q3_musica_que_no_existe")
	t.check(am.music_playing() == "", "una música que falta no suena")
	am.play_loop("sfx/q3_bucle_que_no_existe", 55.0, -10.0)
	t.check(not am.has_ambient("q3_bucle_que_no_existe"), "un bucle que falta no suena (antes, zumbido sintético)")
	t.check(am.missing_requested().size() >= before + 3, "se anotan en MISSING.txt (%d)" % (am.missing_requested().size() - before))
	t.check(FileAccess.get_file_as_string("user://MISSING.txt").contains("q3_slot_que_no_existe"), "MISSING.txt los lista")


# --- música -------------------------------------------------------------------------------------------------

func _musica(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var dir: Node = AudioManager.director
	var md: MusicDirector = dir.get("music")
	if not t.check(md != null, "MusicDirector creado"):
		return
	var lens: Array[float] = []
	for s in MusicDirector.LAYERS:
		var st := AudioManager.stream_for(s, true)
		lens.append(st.get_length() if st != null else 0.0)
	t.check(lens.min() >= 120.0 and absf(lens.max() - lens.min()) < 0.2, "4 capas de ≥ 120 s y la misma duración (%s)" % str(lens))
	Dread.forced = 0.0
	await t.frames(3)
	var tg := md.compute_targets()
	t.check(tg[0] > 0.9 and tg[1] < 0.05 and tg[2] < 0.05 and tg[3] < 0.05, "calma: solo la capa 1 (%s · %s)" % [str(tg), md.reason])
	Dread.forced = 0.5
	tg = md.compute_targets()
	t.check(tg[1] > 0.9 and tg[2] < 0.2 and tg[3] < 0.05, "presión media: entra la tensión (%s)" % str(tg))
	Dread.forced = 0.85
	tg = md.compute_targets()
	t.check(tg[2] > 0.9 and tg[3] < 0.1, "presión alta: entra la alta tensión, todavía sin persecución (%s)" % str(tg))
	await t.seconds(2.0 * Engine.time_scale)  # los fundidos son en segundos reales
	var pos: Array[float] = []
	for p in md.players:
		pos.append(p.get_playback_position() if p.playing else -1.0)
	t.check(md.players[0].playing and pos.max() - pos.min() < 0.25, "las 4 capas suenan en fase (%s)" % str(pos))
	t.check(md.levels[2] > 0.1, "la capa 3 sube de a poco (%.2f)" % md.levels[2])
	Dread.forced = 0.2
	var fake := Node3D.new()
	fake.name = "Cazador_shero"
	t.building().floor_node.add_child(fake)
	var started := Pursuit.start("shero", "break_excedido", 0.1, null, "", GameState.current_floor, Vector3(0, -50, 0))
	await t.frames(2)
	if started or Pursuit.is_hunting():
		tg = md.compute_targets()
		t.check(tg[3] > 0.9, "persecución: capa 4 al máximo (%s · %s)" % [str(tg), md.reason])
		Pursuit.stop("shero", "q3")
	else:
		t.note("Pursuit.start no arrancó en el escenario: se prueba la regla con forced")
		md.forced = [0.55, 0.0, 0.0, 1.0]
		t.check(md.compute_targets()[3] > 0.9, "persecución (forzada): capa 4")
		md.forced = []
	fake.queue_free()
	# azotea: silencio a propósito
	Dread.forced = 0.6
	t.building().go_to_floor(9, "escalera")
	await t.frames(4)
	(dir.get("_zones") as Dictionary).erase("azotea_vestibulo")
	tg = md.compute_targets()
	t.check(tg.max() < 0.01, "azotea: silencio (%s · %s)" % [str(tg), md.reason])
	(dir.get("_zones") as Dictionary)["azotea_vestibulo"] = true
	tg = md.compute_targets()
	t.check(tg[0] > 0.5, "en el vestíbulo de la azotea vuelve la música (%s)" % str(tg))
	# cama del feedback de Haime (F6): las capas se apartan
	AudioManager.play_music("feedback_haime_loop")
	tg = md.compute_targets()
	t.check(AudioManager.music_playing() == "musica/feedback_haime_loop" and tg[0] < 0.2 and tg[1] < 0.2, "feedback de Haime: suena su cama y las capas bajan (%s)" % str(tg))
	AudioManager.stop_music()
	Dread.forced = -1.0
	EventBus.death_sequence_started.emit("q3", "shero", "")
	Checkpoints.dying = true
	t.check(md.compute_targets().max() < 0.01, "en una muerte la música se calla")
	Checkpoints.dying = false


# --- lluvia ---------------------------------------------------------------------------------------------------

func _lluvia(t: Node) -> void:
	var a := AudioManager.stream_for(RainEngine.BED_A, true)
	var b := AudioManager.stream_for(RainEngine.BED_B, true)
	t.check(a != null and a.get_length() >= 240.0, "cama A de lluvia ≥ 240 s (%.0f)" % (a.get_length() if a else 0.0))
	t.check(b != null and b.get_length() >= 240.0, "cama B de lluvia ≥ 240 s (%.0f)" % (b.get_length() if b else 0.0))
	if a != null and b != null:
		var la := int(round(a.get_length()))
		var lb := int(round(b.get_length()))
		var g := la
		var h := lb
		while h != 0:
			var r := g % h
			g = h
			h = r
		t.check(g <= 2, "duraciones coprimas (%d s y %d s, mcd %d): la mezcla se repite recién a las %.1f h" % [la, lb, g, la * lb / float(g) / 3600.0])
	for k in ["gota", "rafaga", "canaleta"]:
		var n := 0
		for i in range(1, 13):
			if AudioManager.has_slot("ambiente/lluvia_%s_%02d" % [k, i], false):
				n += 1
		t.check(n >= 4, "variantes de %s: %d" % [k, n])
	await t.start_shift("Jiroshi", 1)
	var dir: Node = AudioManager.director
	var rain: RainEngine = dir.get("rain")
	t.building().go_to_floor(-1, "calle")
	await t.frames(6)
	await t.seconds(0.5)
	t.check(rain.active and rain.bed_a.playing and rain.bed_b.playing, "en el -1 suenan las dos camas")
	var wsound: AudioStreamPlayer = null
	for n in t.building().floor_node.find_children("SonidoLluvia", "AudioStreamPlayer", true, false):
		wsound = n
	if wsound != null:
		t.check(not wsound.playing and wsound.stream == null, "el SonidoLluvia de Weather queda adoptado (sin su bucle)")
	EventBus.player_entered_zone.emit("calle")
	await t.frames(2)
	t.check(rain.current_profile() == "exterior", "en la calle: lluvia a la intemperie (%s)" % rain.current_profile())
	await t.seconds(3.0 * Engine.time_scale)
	t.check(rain.cutoff > 10000.0, "sin filtro a la intemperie (%.0f Hz)" % rain.cutoff)
	EventBus.player_exited_zone.emit("calle")
	# v0.3.1 (fusión con Q5): la calle real de Q5 también es zona «exterior» (pasos, C15): se entra al lobby de verdad.
	t.player().teleport(Vector3(0.0, 0.05, 9.0), 180.0)
	EventBus.player_exited_zone.emit("exterior")
	await t.seconds(3.0 * Engine.time_scale)  # la transición es en segundos reales
	t.check(rain.current_profile() == "ventana" and rain.cutoff < 4000.0, "adentro del lobby: tras el vidrio (%s, %.0f Hz)" % [rain.current_profile(), rain.cutoff])
	var p := rain.play_event("gota")
	t.check(p != null and p.playing, "una gota suelta suena en 3D alrededor del jugador")
	var pa := rain.bed_a.pitch_scale
	var va := rain.bed_a.volume_db
	await t.seconds(6.0)
	t.check(not is_equal_approx(pa, rain.bed_a.pitch_scale) or not is_equal_approx(va, rain.bed_a.volume_db), "las camas derivan (pitch %.4f→%.4f, vol %.1f→%.1f)" % [pa, rain.bed_a.pitch_scale, va, rain.bed_a.volume_db])
	t.building().go_to_floor(1, "escalera")
	await t.frames(6)
	t.check(rain.current_profile() == "lejano", "piso 1: lluvia lejana (%s)" % rain.current_profile())


# --- pasos ------------------------------------------------------------------------------------------------------

func _pasos(t: Node) -> void:
	for s in SURFACES:
		for kind in ["pasos", "correr", "aterrizaje"]:
			var n := 0
			for i in range(1, 13):
				if AudioManager.has_slot("sfx/pasos/%s_%s_%02d" % [kind, s, i], false):
					n += 1
			t.check(n >= (3 if kind == "aterrizaje" else 6), "%s_%s: %d clips" % [kind, s, n])
	await t.start_shift("Jiroshi", 1)
	var b: Building = t.building()
	b.go_to_floor(2, "pc")
	await t.frames(4)
	var dir: Node = AudioManager.director
	var z: Dictionary = dir.get("_zones")
	z.clear()
	z["sala"] = true
	t.check(dir.call("surface") == "alfombra", "sala de PCs: alfombra")
	z.clear()
	t.check(dir.call("surface") == "porcelanato", "hall: porcelanato negro")
	z["vinilico"] = true
	t.check(dir.call("surface") == "vinilico", "zona «vinilico» de Q5: vinílico")
	z.clear()
	z["training_sala2"] = true
	t.check(dir.call("surface") == "vinilico", "training: vinílico")
	z.clear()
	z["calle"] = true
	t.check(dir.call("surface") == "exterior", "calle: exterior mojado")
	z.clear()
	z["exterior"] = true
	t.check(dir.call("surface") == "exterior", "zona «exterior» de Q5: exterior mojado")
	z.clear()
	# caminar: la cadencia del head bob (2,55 pasos/s) y un pie y el otro
	var p: Player = t.player()
	z["sala"] = true
	var n0: int = dir.steps_played
	var start := p.global_position
	var phys := float(Engine.physics_ticks_per_second)
	var game_s := 0.0
	var ticks := 120
	for i in ticks:
		var dt := Engine.time_scale / phys
		game_s += dt
		p.global_position = start + Vector3(-4.6 * game_s * 0.25, 0, 0)  # 1,15 m/s escalado a la caminata
		await t.get_tree().physics_frame
	var steps := int(dir.steps_played) - n0
	t.note("%d pasos en %.1f s de juego (%.2f/s)" % [steps, game_s, steps / maxf(game_s, 0.01)])
	t.check(steps >= 2 and steps / game_s >= 1.0 and steps / game_s <= 3.2, "cadencia de caminata razonable (%.2f pasos/s)" % (steps / maxf(game_s, 0.01)))
	t.check(str(dir.last_surface) == "alfombra", "y suenan sobre la alfombra")
	var sp: Array = dir.get("_step_players")
	t.check(sp.size() == 2 and (sp[0] as AudioStreamPlayer).bus == "PasosL" and (sp[1] as AudioStreamPlayer).bus == "PasosR", "pie izquierdo y derecho (buses con pan ±0,15)")
	var pan := AudioManager.bus_effect("PasosL", 0) as AudioEffectPanner
	t.check(pan != null and pan.pan < 0.0, "PasosL panea a la izquierda")
	t.check(str(dir.last_step_slot) == "sfx/pasos/pasos_alfombra", "set de caminar: " + str(dir.last_step_slot))
	dir.call("_step", true)
	t.check(str(dir.last_step_slot) == "sfx/pasos/correr_alfombra", "set de carrera propio: " + str(dir.last_step_slot))
	# escalera: con la reverb de la caja
	dir.call("_apply_reverb", "escalera")
	var rv := AudioManager.bus_effect("PasosL", 1) as AudioEffectReverb
	t.check(rv != null and rv.wet > 0.25, "escalera: eco de la caja (wet %.2f)" % (rv.wet if rv else 0.0))
	dir.call("_apply_reverb", "alfombra")
	t.check(rv.wet < 0.06, "alfombra: casi seca")
	# aterrizaje del salto (C15)
	var l0: int = dir.landings
	dir.call("land", 0.45)
	t.check(int(dir.landings) == l0 + 1 and str(dir.last_landing) == "alfombra", "aterrizaje por superficie (%s)" % str(dir.last_landing))
	if EventBus.has_signal("player_landed"):
		EventBus.emit_signal("player_landed", 0.45)
		t.check(int(dir.landings) == l0 + 2, "EventBus.player_landed (Q1) suena el aterrizaje")
	else:
		t.note("EventBus.player_landed todavía no existe (Q1): el AudioDirector detecta la caída solo")
	dir.call("land", 0.05)
	t.check(int(dir.landings) >= l0 + 1 and int(dir.landings) <= l0 + 2, "un escalón (5 cm) no suena como salto")
	z.clear()


# --- Rasec ------------------------------------------------------------------------------------------------------

func _rasec(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var dir: Node = AudioManager.director
	AudioManager.play_music("rasec_animo_forzado")
	t.check(AudioManager.music_playing() == "musica/rasec_animo_forzado", "suena la música alegre de Rasec")
	t.check((AudioManager.get_node("Musica") as AudioStreamPlayer).bus == "RasecDegrada", "por el bus RasecDegrada")
	await t.seconds(1.0)
	var k0: float = dir.rasec_degrade
	dir.set("_rasec_t", 80.0)
	await t.seconds(1.0)
	var k1: float = dir.rasec_degrade
	var ps := AudioManager.bus_effect("RasecDegrada", 0) as AudioEffectPitchShift
	var lp := AudioManager.bus_effect("RasecDegrada", 2) as AudioEffectLowPassFilter
	t.check(k0 < 0.2 and k1 > 0.5, "se degrada con el tiempo (%.2f → %.2f)" % [k0, k1])
	t.check(ps != null and ps.pitch_scale < 0.97 and lp.cutoff_hz < 12000.0, "se desafina y se apaga (pitch %.3f, %.0f Hz)" % [ps.pitch_scale if ps else 1.0, lp.cutoff_hz if lp else 0.0])
	t.check(dir.get("music").compute_targets()[0] < 0.2, "las capas de tensión le dejan lugar")
	AudioManager.stop_music()
	await t.seconds(0.8)
	t.check(dir.rasec_degrade == 0.0 and ps.pitch_scale == 1.0, "al terminar vuelve a la normalidad")
	# un reproductor ajeno (rasec_control) con musica/rasec_* también se degrada
	var pl := AudioStreamPlayer.new()
	pl.bus = "Sala"
	t.building().add_child(pl)
	pl.stream = load(AudioManager.resolve("musica/rasec_karaoke"))
	pl.play()
	await t.seconds(1.2 * Engine.time_scale)
	t.check(pl.bus == "RasecDegrada", "el reproductor de Rasec pasa por RasecDegrada (%s)" % pl.bus)
	pl.stop()
	await t.seconds(1.2 * Engine.time_scale)
	t.check(pl.bus == "Sala", "y vuelve a su bus al terminar (%s)" % pl.bus)
	pl.queue_free()


# --- Ezlaki ------------------------------------------------------------------------------------------------------

func _hub(t: Node) -> EzlakHub:
	return EzlakHub.get_hub(t.get_tree())


func _app(t: Node) -> PcEzlak:
	var ws: Node = t.main.get_node_or_null("UI/Workstation")
	return ws.get("ezlak") as PcEzlak if ws != null else null


func _botones(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var app := _app(t)
	if not t.check(app != null, "app Ezlaki"):
		return
	hub.excuse_pending = true
	EventBus.ezlak_post.emit("dm:shero", "shero", "¿Por qué ese correo lleva más de 10 minutos?", {"tipo": "excusa", "quick_replies": ["excusa_1", "excusa_2", "excusa_3"], "mention": true})
	await t.frames(2)
	app.open_channel("dm:shero")
	app.refresh(0.1, true)
	await t.frames(2)
	var replies: HFlowContainer = app.get("_replies")
	var textos: Dictionary = DataLoader.dict("ezlak_canales").get("textos_respuesta", {})
	var n := 0
	for b in replies.get_children():
		if b is Button:
			n += 1
			var rid := str((b as Button).get_meta("respuesta", ""))
			var full := Loc.pick(textos.get(rid, {}))
			t.check(not (b as Button).clip_text and (b as Button).text == full, "botón «%s» entero (sin cortar)" % full)
			t.check((b as Button).tooltip_text == full, "con el texto completo al pasar el ratón")
	t.check(n >= 3, "las 3 excusas como botones (%d)" % n)
	var long_ok := true
	for b in replies.get_children():
		if b is Button and (b as Button).text.length() > 30:
			long_ok = long_ok and (b as Button).autowrap_mode != TextServer.AUTOWRAP_OFF
	t.check(long_ok, "las largas bajan a 2 líneas")
	app.show_preview("Revisé las notas dos veces para no duplicar el envío.")
	var pv: Label = app.get("_preview")
	t.check(pv.visible and pv.text.contains("Revisé las notas"), "vista previa: " + pv.text)
	app.show_preview("")
	t.check(not pv.visible, "la vista previa se va al salir")
	hub.excuse_pending = false


func _escribir(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var app := _app(t)
	var casos := [["perdón, es que el sistema se colgó", "excusa"], ["ya voy", "voy"], ["ok", "ok"], ["eres un idiota", "insulto"],
		["¿qué hago con el correo?", "pregunta"], ["me siento mal", "ayuda"], ["jajaja", "broma"], ["gracias!!", "gracias"],
		["no gracias", "negar"], ["recibido", "ack"], ["asdfgh", "otro"], ["I'm on my way", "voy"], ["sorry, the system crashed", "excusa"],
		["you are useless", "insulto"], ["what do I do?", "pregunta"], ["   ", "vacio"]]
	for c in casos:
		t.check(EzlakHub.classify_intent(str(c[0])) == str(c[1]), "«%s» → %s (%s)" % [c[0], c[1], EzlakHub.classify_intent(str(c[0]))])
	# 5 textos → 5 intenciones → respuesta del personaje del canal
	var five := [["dm:shero", "es que no vi el reloj", "excusa", "shero"], ["dm:jiroshi" if hub.agent_dms("Jiroshi").has("jiroshi") else "dm:marko", "jaja qué turno", "broma", ""],
		["#team-familia", "¿alguien sabe dónde está el tópico?", "pregunta", "mentor"], ["#site-updates", "hola?", "pregunta", "om"], ["#allocations", "listo", "ok", "rta"]]
	for f in five:
		var ch := str(f[0])
		var n0 := hub.messages(ch).size()
		var intent := hub.typed_reply(ch, str(f[1]))
		t.check(intent == str(f[2]), "%s: «%s» → %s" % [ch, f[1], intent])
		var mine: Dictionary = hub.messages(ch).back() if not hub.messages(ch).is_empty() else {}
		t.check(str(mine.get("autor", "")) == "yo" and str(mine.get("texto", "")) == str(f[1]), "lo escrito queda en el canal")
		await t.seconds(5.5)
		var last: Dictionary = hub.messages(ch).back()
		var want := str(f[3])
		t.check(hub.messages(ch).size() >= n0 + 2 and str(last.get("autor", "")) != "yo" and (want == "" or str(last.get("autor", "")) == want), "%s responde: %s · %s" % [ch, str(last.get("autor", "")), str(last.get("texto", ""))])
	# a Shero le caen mal las excusas
	# v0.3.2 IA: ahora contesta IABrain con data/ia/personas.json (shero/excusa); puede partirlo en 2 mensajes
	var exc: Array = (IABrain.persona("shero").get("lineas", {}).get("excusa", []) as Array).map(func(d: Dictionary) -> String: return Loc.fmt(Loc.pick(d), {"agente": GameState.agent}))
	var sh: Dictionary = hub.messages("dm:shero").back()
	var sh_ok := false
	for e in exc:
		if str(e).contains(str(sh.get("texto", "")).trim_suffix(".")) or str(sh.get("texto", "")).contains(str(e).left(12)):
			sh_ok = true
	t.check(sh_ok and str(sh.get("autor", "")) == "shero", "Shero contesta mal a la excusa: " + str(sh.get("texto", "")))
	# insultar a Shero = falta (alerta y luego WW)
	var a0 := Metrics.alerts
	var w0 := Metrics.written_warnings
	hub.typed_reply("dm:shero", "shero calvo tirano")
	await t.seconds(2.0)
	t.check(Metrics.alerts > a0 or Metrics.written_warnings > w0, "insultar a Shero cuenta como falta (alerta %d→%d, WW %d→%d)" % [a0, Metrics.alerts, w0, Metrics.written_warnings])
	# Ack escrito cierra el WW
	Metrics.issue_written_warning("aht_bo")
	await t.frames(1)
	t.check(Metrics.ack_pending, "WW con Ack pendiente")
	hub.typed_reply("dm:shero", "recibido, doy ack")
	t.check(not Metrics.ack_pending, "escribir «recibido» da el Ack")
	await t.seconds(2.0)
	# Rooms escrito
	var joined: Array = t.spy("coaching_joined")
	EventBus.coaching_requested.emit(60.0)
	await t.frames(1)
	hub.typed_reply("dm:shero", "ya voy")
	t.check(joined.size() == 1 and not hub.rooms_pending, "escribir «ya voy» en la invitación entra a Rooms")
	# «me siento mal» escrito → tópico
	var topico: Array = t.spy("topico_requested")
	hub.typed_reply("dm:shero", "me siento mal, estoy mareado")
	t.check(topico.size() == 1, "escribir «me siento mal» pide el tópico (como el botón)")
	# Rasec: «no gracias» escrito = el botón
	var qr: Array = t.spy("ezlak_quick_reply")
	EventBus.ezlak_post.emit("dm:rasec", "rasec", "¡Integración en 2 min!", {"tipo": "rasec_evento", "quick_replies": ["voy", "no_gracias"]})
	await t.frames(1)
	hub.typed_reply("dm:rasec", "no gracias, tengo cola")
	t.check(qr.size() >= 1 and str(qr.back()[1]) == "no_gracias", "«no gracias» en el DM de Rasec = respuesta rápida (P5)")
	# spam: nunca rompe y Shero avisa una vez
	for i in 6:
		hub.typed_reply("#team-familia", "hola %d" % i)
	await t.seconds(2.0)
	t.check(hub.messages("#team-familia").size() > 0, "6 mensajes seguidos no rompen nada")
	t.check(hub.typed_reply("#team-familia", "") == "vacio", "vacío: nada")
	# el campo de la app
	if app != null:
		app.open_channel("dm:shero")
		var le: LineEdit = app.input
		t.check(le != null and le.max_length == 160, "campo «Escribir…» en la app")
		le.text = "perdón, se me pasó"
		var it := app.submit_typed()
		t.check(it == "excusa" and le.text == "" and not bool(GameState.flags.get("pc_text_focus", false)), "Enter envía, limpia y suelta el foco (%s)" % it)


func _variedad(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	var hub := _hub(t)
	var prog: Array = DataLoader.dict("ezlak_canales").get("programados", [])
	var t2 := 0
	for p in prog:
		if (p.get("turnos", []) as Array).has(2.0) or (p.get("turnos", []) as Array).has(2):
			t2 += 1
	t.check(prog.size() >= 50, "publicaciones programadas: %d (v0.3.0: 27)" % prog.size())
	# variantes: cada línea de canal con ≥ 3 versiones en total
	var lc: Dictionary = DataLoader.dict("lineas_canales")
	var few: Array[String] = []
	for p in prog:
		var key := str(p.get("linea", ""))
		if p.has("edita") or p.has("borra"):
			continue
		if hub.line_pool("lineas_canales", key).size() < 3:
			few.append(key)
	t.check(few.size() <= 6, "líneas con < 3 variantes: %d %s" % [few.size(), str(few)])
	# un turno entero a saltos de 60 s: ninguna línea de NPC repetida en un canal
	var start := GameState.clock_seconds
	await t.advance_clock(GameState.hhmm_to_seconds("08:30") - start + (86400.0 if GameState.hhmm_to_seconds("08:30") < start else 0.0))
	await t.seconds(8.0)
	var total := 0
	var reps: Array[String] = []
	for ch in hub.order:
		var seen := {}
		for m in hub.messages(ch):
			var a := str(m.get("autor", ""))
			if a == "yo" or a == "sistema":
				continue
			var tx := str(m.get("texto", ""))
			total += 1
			if seen.has(tx) and str(m.get("tipo", "")) in ["programado", "dm_companero", "v02", "respuesta_npc"]:
				reps.append("%s: %s" % [ch, tx.left(40)])
			seen[tx] = true
	t.note("%d mensajes de NPC en el turno 2 (%d programados en T2)" % [total, t2])
	t.check(total >= 40, "turno con mucho movimiento: %d mensajes" % total)
	t.check(reps.is_empty(), "0 líneas repetidas por canal en el turno (%s)" % str(reps))
	var extra := 0
	for ch in hub.order:
		for m in hub.messages(ch):
			if str(m.get("tipo", "")) == "dm_companero":
				extra += 1
	t.check(extra >= 4, "charla de los compañeros por DM: %d" % extra)


func _limitador(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var n0 := hub.messages("dm:shero").size()
	for i in 30:
		EventBus.shero_message.emit("de_pie_en_live", "dm")
		await t.frames(1)
	await t.frames(2)
	var got := hub.messages("dm:shero").size() - n0
	t.check(got == 1, "30 avisos seguidos → 1 mensaje en la ventana de 20 s (%d)" % got)
	t.check(hub.limited_count >= 29, "el resto se retuvo o descartó (%d)" % hub.limited_count)
	await t.seconds(21.0)
	var got2 := hub.messages("dm:shero").size() - n0
	t.check(got2 <= 2, "pasada la ventana sale como mucho uno más (%d)" % got2)
	# lo importante no se limita
	var n1 := hub.messages("dm:shero").size()
	Metrics.issue_written_warning("aht_bo")
	EventBus.coaching_requested.emit(30.0)
	await t.frames(2)
	t.check(hub.messages("dm:shero").size() == n1 + 2, "WW y Rooms no se limitan")
	Metrics.give_ack()


func _capturas(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hub := _hub(t)
	var app := _app(t)
	# tag de disciplina (break excedido) en #allocations
	EventBus.ezlak_post.emit("#allocations", "shero", "@Jiroshi break excedido.", {"tipo": "disciplina", "pista": "break", "escalon": "llamado", "mention": true})
	await t.frames(2)
	var m: Dictionary = hub.messages("#allocations").back()
	var cap: Dictionary = m.get("captura", {})
	t.check(not cap.is_empty(), "el tag de Shero en #allocations trae la captura")
	var filas: Array = cap.get("filas", [])
	t.check(filas.size() == 1 and bool(filas[0].get("destacado", false)) and str(filas[0].get("slug", "")) == "jiroshi", "una fila: el infractor, resaltado")
	t.check(str(filas[0].get("estado", "")) == "break" and str(filas[0].get("cron", "")).length() == 8, "estado Break y cronómetro hh:mm:ss (%s %s)" % [filas[0].get("estado_txt", ""), filas[0].get("cron", "")])
	# tag del RTA a un NPC (programado con captura de lista)
	EventBus.ezlak_post.emit("#allocations", "rta", "@here de momento no hay cola, pasamos a BO. Guau.", {"tipo": "programado", "captura": {"tipo": "lista", "estado": "bo", "n": 8, "tema": "oscuro"}})
	EventBus.ezlak_post.emit("#allocations", "rta", "@Ttoom sigue en Break.", {"tipo": "programado", "captura": {"tipo": "uno", "estado": "break", "quien": "ttoom", "tema": "claro"}})
	await t.frames(2)
	var ms := hub.messages("#allocations")
	var lista: Dictionary = ms[ms.size() - 2].get("captura", {})
	var uno: Dictionary = ms[ms.size() - 1].get("captura", {})
	t.check((lista.get("filas", []) as Array).size() >= 6 and (lista.get("filas", []) as Array).size() <= 8, "lista @here: 6-8 filas (%d)" % (lista.get("filas", []) as Array).size())
	t.check(str(uno.get("tema", "")) == "claro" and bool((uno.get("filas", []) as Array)[0].get("destacado", false)) and str((uno.get("filas", []) as Array)[0].get("slug", "")) == "ttoom", "tag a Ttoom: su fila, tema claro")
	# identidades: solo las del juego, con el dominio de la campaña
	var roster: Dictionary = EzlakiCaptura.cfg().get("identidades", {})
	var dom := str(EzlakiCaptura.cfg().get("dominio", ""))
	var rx := RegEx.create_from_string("^[a-z\\-]+@kipupay\\.kp \\([^,()]+, [^,()]+\\)$")
	var bad: Array[String] = []
	for c in [cap, lista, uno]:
		for f in c.get("filas", []):
			var tx := str(f.get("texto", ""))
			if rx.search(tx) == null or not roster.has(str(f.get("slug", ""))) or tx.contains(".com") or not tx.contains("@" + dom):
				bad.append(tx)
	t.check(dom == "kipupay.kp" and bad.is_empty(), "identidades inventadas del juego (dominio %s; fuera de regla: %s)" % [dom, str(bad)])
	var all_txt := JSON.stringify(EzlakiCaptura.cfg())
	t.check(not all_txt.contains(".com") and all_txt.count("@") == 0, "los datos de las capturas no traen correos ni dominios reales")
	# control y textura
	var ctrl := EzlakiCaptura.build_control(lista)
	var labels := ctrl.find_children("Identidad", "Label", true, false)
	var crons := ctrl.find_children("Cronometro", "Label", true, false)
	t.check(labels.size() == (lista.get("filas", []) as Array).size() and crons.size() == labels.size(), "la tabla tiene una fila por identidad, con su cronómetro")
	ctrl.free()
	var tex := hub.captura.texture_for(int(ms[ms.size() - 2].get("id", 0)), lista)
	t.check(tex != null and tex.get_width() >= EzlakiCaptura.W, "imagen generada (%dx%d)" % [tex.get_width() if tex else 0, tex.get_height() if tex else 0])
	# reacciones de los compañeros
	await t.seconds(6.0)
	t.check(not (m.get("reacciones", []) as Array).is_empty(), "reacciones con caras del site: %s" % str(m.get("reacciones", [])))
	# clic → ampliar
	if app != null:
		app.open_channel("#allocations")
		app.refresh(0.1, true)
		app.call("_on_meta", "shot:%d" % int(m.get("id", 0)))
		t.check(app.shot_zoomed == int(m.get("id", 0)) and (app.get("_zoom") as Control).visible, "clic en la captura: se ve grande")
		app.close_shot()
		t.check(app.shot_zoomed == -1, "y se cierra")
	# caso diario (T2+, flavor): planilla borrosa sin texto legible
	var hoja := hub.captura.make({"tipo": "hoja", "n": 13, "tema": "claro"}, 999)
	var hc := EzlakiCaptura.build_control(hoja)
	t.check((hoja.get("celdas", []) as Array).size() == 13 and hc.find_children("*", "Label", true, false).is_empty(), "caso diario: planilla de 13 filas, borrosa (ningún texto)")
	hc.free()
	# llamado a coaching de las 7:30: compañeros inventados; el jugador solo si tiene un coaching pendiente
	hub.rooms_pending = false
	var tags := hub.coaching_tags()
	t.check(not tags.contains("@" + GameState.agent) and tags.count("@") >= 3, "lista de coaching sin el jugador si no tiene coaching pendiente: " + tags)
	hub.rooms_pending = true
	t.check(hub.coaching_tags().contains("@" + GameState.agent), "con coaching pendiente, el jugador está en la lista")
	hub.rooms_pending = false
	var prog: Array = DataLoader.dict("ezlak_canales").get("programados", [])
	var found := 0
	for p in prog:
		if str(p.get("linea", "")) in ["EZLAKI_SHERO_COACHING_LISTA", "EZLAKI_SHERO_CASO_DIARIO"] and tr(str(p["linea"])) != str(p["linea"]):
			found += 1
	t.check(found == 2, "los dos @here de Shero están programados con su texto ES/EN (%d)" % found)
	t.check(not tr("EZLAKI_SHERO_CASO_DIARIO").contains("RISE"), "herramienta inventada (KipuLog)")
	# mentor/RTA: orden de allocation (rta) con lista
	EventBus.rta_tag.emit("@%s AUX incorrecto." % GameState.agent)
	await t.frames(2)
	var tg: Dictionary = hub.messages("#allocations").back()
	t.check(not (tg.get("captura", {}) as Dictionary).is_empty(), "rta_tag también trae su captura")


# --- entorno de Q5 ---------------------------------------------------------------------------------------

## Q5 arma «EntornoEste/Trafico» en su rama; acá se imita la misma forma (nombres y campos _x, _y, _z0, _z1).
func _entorno_q5(t: Node) -> void:
	t.check(AudioManager.has_slot("ambiente/autopista_rumor_loop", false), "existe el rumor de la autopista")
	var rum := AudioManager.stream_for("ambiente/autopista_rumor_loop", true)
	t.check(rum != null and rum.get_length() >= 60.0, "rumor largo (%.0f s)" % (rum.get_length() if rum else 0.0))
	var nc := 0
	for i in range(1, 9):
		if AudioManager.has_slot("ambiente/autopista_camion_%02d" % i, false):
			nc += 1
	t.check(nc >= 3, "variantes de camión: %d" % nc)
	t.check(AudioManager.has_slot("ambiente/ventilacion_loop", false), "existe el siseo de ventilación")
	await t.start_shift("Jiroshi", 1)
	var dir: Node = AudioManager.director
	t.building().go_to_floor(2)
	await t.frames(6)
	var fl: Node3D = t.building().floor_node
	# v0.3.1 (fusión con Q5): el piso 2 ya trae su EntornoEste/Trafico; sin él (rama de Q3 sola) se imita.
	var root := fl.get_node_or_null("EntornoEste") as Node3D
	var traf: Node = root.get_node_or_null("Trafico") if root != null else null
	if root == null or traf == null:
		root = Node3D.new()
		root.name = "EntornoEste"
		fl.add_child(root)
		var gs := GDScript.new()
		gs.source_code = "extends Node3D\nvar _x: float = 60.0\nvar _y: float = 6.8\nvar _z0: float = -80.0\nvar _z1: float = 80.0\n"
		gs.reload()
		traf = Node3D.new()
		traf.set_script(gs)
		traf.name = "Trafico"
		root.add_child(traf)
	await t.frames(3)
	var tx := float(traf.get("_x"))
	var tz0 := float(traf.get("_z0"))
	var tz1 := float(traf.get("_z1"))
	var h: HighwayAudio = root.get_node_or_null("RumorAutopista") as HighwayAudio
	t.check(h != null, "el AudioDirector cuelga el rumor del EntornoEste")
	if h != null:
		await t.frames(2)
		t.check(absf(h.axis_x - tx) < 0.01 and absf(h.z1 - tz1) < 0.01, "lee el eje del Trafico (x %.0f, z %.0f..%.0f)" % [h.axis_x, h.z0, h.z1])
		t.check(h.rumble.playing and h.rumble.bus == "Lluvia", "el rumor suena por el bus Lluvia (vidrio adentro, entero afuera)")
		var cam := fl.get_viewport().get_camera_3d()
		if cam != null:
			var p := h.nearest_point()
			var cz := root.to_local(cam.global_position).z
			t.check(absf(p.z - clampf(cz, tz0, tz1)) < 0.5, "el emisor se pone en el punto del tablero más cercano a la cámara")
			var near := absf(cam.global_position.x - root.to_global(Vector3(tx, 0, 0)).x)
			t.check(near < h.rumble.max_distance, "se oye desde la fachada este (%.0f m del eje)" % near)
		var before := h.trucks
		h.pass_truck()
		t.check(h.trucks == before + 1 and h.truck.playing, "pasa un camión")
	EventBus.player_entered_zone.emit("ventilacion_casilleros")
	await t.frames(2)
	t.check(AudioManager.has_ambient("ventilacion_loop") and bool(dir.get("vent_on")), "en «ventilacion_*» sisea la rejilla")
	EventBus.player_entered_zone.emit("ventilacion_vestibulo")
	EventBus.player_exited_zone.emit("ventilacion_casilleros")
	await t.frames(2)
	t.check(AudioManager.has_ambient("ventilacion_loop"), "de una zona de ventilación a otra no se corta")
	EventBus.player_exited_zone.emit("ventilacion_vestibulo")
	await t.frames(2)
	t.check(not AudioManager.has_ambient("ventilacion_loop"), "fuera de las zonas (hall de ascensores) silencio")
	root.queue_free()

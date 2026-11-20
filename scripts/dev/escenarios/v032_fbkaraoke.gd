## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 · feedback de Joan: «las canciones del karaoke: lo que se canta debe corresponder a los subtítulos».
## Antes nadie cantaba la letra (pista instrumental + un tarareo sin palabras). Ahora cada verso tiene su voz cantada
## (tools/v032_karaoke_voz.py), con la letra de los datos letra por letra, y el evento la arranca en un compás.
##   fbk_indice     la letra de data/rasec_eventos.json = el texto del índice data/karaoke_voz.json = lo que se
##                  sintetizó; cada archivo existe en ES y EN con el md5 del índice; las marcas de las sílabas cubren
##                  la letra entera, en orden; duraciones razonables; el último verso, frenado.
##   fbk_letra_voz  el evento de verdad, a velocidad real, en ES y en EN, jugado con el teclado: por cada verso, la
##                  voz que arranca es la de ESE verso en ESE idioma, la letra en pantalla es su texto, entra en un
##                  compás de la pista, la letra se pinta mientras suena, Rasec comenta después (nunca encima) y hay
##                  0 solapes.
##   fbk_acelerado  con el juego a ×8 (bots): el evento termina, lo que suena es siempre el verso que se lee y hay
##                  0 solapes.


func escenarios() -> Array[String]:
	return ["fbk_indice", "fbk_letra_voz", "fbk_acelerado"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"fbk_indice": await _index(t)
		"fbk_letra_voz":
			for lang in ["es", "en"]:
				await _event(t, lang)
			Loc.set_language("es")
		"fbk_acelerado": await _fast(t)


func _plain(text: String) -> String:
	return text.replace("♪", "").strip_edges()


func _index(t: Node) -> void:
	var verses: Array = (DataLoader.dict("rasec_eventos").get("karaoke", {}) as Dictionary).get("versos", [])
	t.check(verses.size() == 5 and KaraokeVoz.count() == verses.size(), "5 versos en los datos y %d en el índice" % KaraokeVoz.count())
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		await t.frames(1)
		for i in verses.size():
			var tag := "verso %d [%s]" % [i + 1, lang]
			var want := str((verses[i] as Dictionary).get(lang, ""))
			var v := KaraokeVoz.verse(i, lang)
			t.check(not v.is_empty() and str(v.get("texto", "")) == want, "%s: lo que se canta = la letra de los datos («%s» / «%s»)" % [tag, str(v.get("texto", "")), want])
			var slot := KaraokeVoz.slot(i)
			var path := AudioManager.voice_path(slot)
			t.check(slot == "voces/rasec/karaoke_verso_%d" % (i + 1) and path != "" and path.contains("/en/") == (lang == "en"), "%s: archivo %s" % [tag, path])
			if path == "":
				continue
			t.check(FileAccess.get_md5(path) == str(v.get("md5", "")), "%s: el archivo instalado es el que se indexó (md5)" % tag)
			var st := load(path) as AudioStream
			t.check(st != null and absf(st.get_length() - float(v.get("dur", 0.0))) < 0.08, "%s: duración %.2f s (índice %.2f)" % [tag, st.get_length() if st != null else -1.0, float(v.get("dur", 0.0))])
			# marcas: una por sílaba, en orden, y la última llega al final de la letra (sin el «♪» de cierre)
			var marks: Array = v.get("marcas", [])
			var ok := not marks.is_empty()
			var prev_t := -1.0
			var prev_n := 0
			for m in marks:
				var a := m as Array
				ok = ok and a.size() == 3 and float(a[0]) > prev_t and float(a[1]) > float(a[0]) and int(a[2]) > prev_n
				prev_t = float(a[0])
				prev_n = int(a[2])
			var lyric_end := want.find(_plain(want)) + _plain(want).length()
			t.check(ok and prev_n == lyric_end, "%s: %d marcas en orden que cubren la letra (%d de %d letras)" % [tag, marks.size(), prev_n, lyric_end])
			t.check(float(v.get("canto", 0.0)) > 1.5 and float(v.get("canto", 0.0)) <= float(v.get("dur", 0.0)) + 0.01 and float(v.get("dur", 0.0)) < 9.0, "%s: canto %.2f s de %.2f s" % [tag, float(v.get("canto", 0.0)), float(v.get("dur", 0.0))])
			t.check(KaraokeVoz.chars_at(marks, -0.1) == 0 and KaraokeVoz.chars_at(marks, 99.0) == lyric_end, "%s: nada pintado antes de empezar y todo al final" % tag)
			t.check(absf(AudioManager.gain_db(slot)) < 0.01, "%s: sin corrección de sonoridad (ya viene a -16 LUFS como las demás voces)" % tag)
		# el último va frenado: su canto son N corcheas enteras a 108 divididas por 0,62 (ES 12 corcheas = 3,33 s → 5,38 s;
		# EN 11 → 4,93 s: la partitura de tools/v032_karaoke_voz.py). Sin frenar, canto × 0,62 no daría corcheas enteras.
		var last := KaraokeVoz.verse(verses.size() - 1, lang)
		var eighths := float(last.get("canto", 0.0)) * KaraokeVoz.SLOW / (60.0 / KaraokeVoz.BPM / 2.0)
		t.check(eighths >= 8.0 - 0.1 and eighths <= 16.1 and absf(eighths - roundf(eighths)) < 0.06, "[%s] el último verso viene frenado ×%.2f (canto %.2f s = %.2f corcheas a tempo)" % [lang, KaraokeVoz.SLOW, float(last.get("canto", 0.0)), eighths])
	Loc.set_language("es")
	# cuadrícula de compases
	t.check(absf(KaraokeVoz.bar_wait(0.5, 33.5556) - (KaraokeVoz.BAR_S - 0.5)) < 0.001, "bar_wait: al próximo compás")
	t.check(absf(KaraokeVoz.bar_wait(30.0, 33.5556) - 3.5556) < 0.001, "bar_wait: cerca del final espera a que la pista vuelva a empezar (no cruza la costura del bucle)")
	t.check(absf(KaraokeVoz.bar_wait(KaraokeVoz.BAR_S * 3.0 - 0.01, 33.5556) - (KaraokeVoz.BAR_S + 0.01)) < 0.001 or absf(KaraokeVoz.bar_wait(KaraokeVoz.BAR_S * 3.0 - 0.01, 33.5556) - 0.08) < 0.08, "bar_wait: demasiado pegado al compás → el siguiente o ya")
	var st2 := load(AudioManager.resolve("musica/rasec_karaoke")) as AudioStream
	t.check(st2 != null and absf(st2.get_length() - 33.5556) < 0.05, "la pista dura 33,56 s (15,1 compases a 108): %.3f" % (st2.get_length() if st2 != null else -1.0))


func _hub(t: Node) -> PersonajesP5:
	return PersonajesP5.get_hub(t.get_tree())


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _press_sing() -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = "interact"
		e.pressed = pressed
		_send(e)


func _press_key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		_send(e)


## El evento de karaoke, a velocidad real, jugado con el teclado (sin `forced_play`).
func _event(t: Node, lang: String) -> void:
	Loc.set_language(lang)
	await t.start_shift("Llauri", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := t.main.get("contacts") as ContactManager
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.frames(3)
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	VoiceDirector.reset_audit()
	var hub := _hub(t)
	var rasec: RasecControl = hub.rasec
	if not t.check(rasec != null, "[%s] hay Rasec en el turno" % lang):
		return
	var verses: Array = (DataLoader.dict("rasec_eventos").get("karaoke", {}) as Dictionary).get("versos", [])
	var starts: Array = []  # {id, ui, path, pos, pitch, ms}
	var order: Array = []  # ids de todo lo que suena, en orden
	var on_start := func(id2: String, _sp: String, _p: int) -> void:
		order.append(id2.get_file())
		if id2.contains("karaoke_verso_"):
			# la ruta que eligió el director para esta línea (el stream se carga sin resource_path: AudioManager._load_mode)
			var ln: Object = VoiceDirector.get("_starting")
			var mp: AudioStreamPlayer = rasec.get("_player")
			starts.append({"id": id2, "ui": rasec.ui.shown_text() if rasec.ui != null else "", "path": str(ln.get("path")) if ln != null else "",
				"pos": mp.get_playback_position() + AudioServer.get_time_since_last_mix(), "pitch": mp.pitch_scale, "ms": VoiceDirector.now_ms()})
	VoiceDirector.line_started.connect(on_start)
	var peak := [0]
	var watch := func() -> void: peak[0] = maxi(peak[0], VoiceDirector.voices_playing())
	t.get_tree().process_frame.connect(watch)
	var scale := Engine.time_scale
	Engine.time_scale = 1.0
	rasec.forced_play = ""
	Metrics.set_aux(Metrics.Aux.BO)
	rasec.call_event("karaoke")
	await t.frames(3)
	var pl: Player = t.player()
	pl.stand_up()
	await t.frames(2)
	var mk := hub.marker("evento_rasec")
	if mk != null:
		pl.teleport(mk.global_position, 0.0)
	var t0 := VoiceDirector.now_ms()
	var began := false
	while VoiceDirector.now_ms() - t0 < 25000 and not began:
		began = rasec.state == RasecControl.State.EVENTO
		await t.frames(1)
	t.check(began, "[%s] llegas en BO al centro de la sala: empieza el karaoke" % lang)
	# El jugador: canta a 1 s de que salga el verso y responde la primera opción a 1 s de cada pregunta.
	var mode_since := 0
	var last_mode := ""
	var painted_mid: Array = []  # letras pintadas a mitad de cada verso
	var painted_end: Array = []
	var seen_sung := 0
	t0 = VoiceDirector.now_ms()
	while VoiceDirector.now_ms() - t0 < 170000 and rasec.state == RasecControl.State.EVENTO:
		await t.frames(1)
		var ui := rasec.ui
		if ui == null or not is_instance_valid(ui):
			continue
		var mode := str(ui.get("_mode"))
		if mode != last_mode:
			last_mode = mode
			mode_since = VoiceDirector.now_ms()
		if mode == "press" and VoiceDirector.now_ms() - mode_since > 1000:
			_press_sing()
			mode_since = VoiceDirector.now_ms() + 100000
		elif mode == "choose" and VoiceDirector.now_ms() - mode_since > 1000:
			_press_key(KEY_1)
			mode_since = VoiceDirector.now_ms() + 100000
		# la letra se pinta con la voz
		if rasec.sung.size() > seen_sung:
			seen_sung = rasec.sung.size()
			painted_mid.append(-1)
			painted_end.append(-1)
		if seen_sung > 0:
			var line: Object = rasec.sung[seen_sung - 1][3]
			var info := KaraokeVoz.verse(seen_sung - 1)
			if int(line.get("started_ms")) >= 0 and not bool(line.get("done")):
				var el := float(VoiceDirector.now_ms() - int(line.get("started_ms"))) / 1000.0
				if el > float(info.get("canto", 9.0)) * 0.45 and painted_mid[seen_sung - 1] < 0:
					painted_mid[seen_sung - 1] = ui.sung_chars()
			elif bool(line.get("done")) and painted_end[seen_sung - 1] < 0 and ui.shown_text() == str(rasec.sung[seen_sung - 1][2]):
				await t.frames(1)
				painted_end[seen_sung - 1] = ui.sung_chars()
		if rasec.sung.size() >= verses.size() and bool((rasec.sung[verses.size() - 1][3] as Object).get("done")) and rasec.decisions_log.size() >= 2:
			break
	t.note("[%s] voces en orden: %s" % [lang, str(order)])
	t.note("[%s] %s" % [lang, VoiceDirector.audit_line()])
	t.check(starts.size() == verses.size(), "[%s] sonaron los %d versos cantados (%d)" % [lang, verses.size(), starts.size()])
	for i in mini(starts.size(), verses.size()):
		var s: Dictionary = starts[i]
		var tag := "[%s] verso %d" % [lang, i + 1]
		var want := str((verses[i] as Dictionary).get(lang, ""))
		t.check(str(s["id"]) == "voces/rasec/karaoke_verso_%d" % (i + 1), "%s: la voz que arranca es la de ese verso (%s)" % [tag, str(s["id"])])
		t.check(str(s["ui"]) == want and str(s["ui"]) == str(KaraokeVoz.verse(i, lang).get("texto", "")), "%s: la letra en pantalla es la que se canta («%s»)" % [tag, str(s["ui"])])
		t.check(str(s["path"]).ends_with(("/en/" if lang == "en" else "/rasec/") + "karaoke_verso_%d.ogg" % (i + 1)), "%s: suena el archivo de ese idioma (%s)" % [tag, str(s["path"]).get_file()])
		# en compás: la posición de la pista al arrancar la voz cae en un múltiplo del compás (± lo que tarda un cuadro)
		var off := fposmod(float(s["pos"]) + KaraokeVoz.BAR_S * 0.5, KaraokeVoz.BAR_S) - KaraokeVoz.BAR_S * 0.5
		t.check(absf(off) < 0.16 or float(s["pos"]) < 0.16, "%s: entra en un compás de la pista (a %.2f s de la pista, %.0f ms del compás)" % [tag, float(s["pos"]), off * 1000.0])
		t.check(is_equal_approx(float(s["pitch"]), KaraokeVoz.SLOW if i == verses.size() - 1 else 1.0), "%s: pista a ×%.2f" % [tag, float(s["pitch"])])
		if i < painted_mid.size():
			var total := want.length()
			t.check(painted_mid[i] > 2 and painted_mid[i] < total, "%s: a mitad del verso la letra va pintada a medias (%d de %d letras)" % [tag, painted_mid[i], total])
			t.check(painted_end[i] == total, "%s: al terminar la voz, la letra entera pintada (%d de %d)" % [tag, painted_end[i], total])
	# Rasec comenta DESPUÉS de cada verso: en la línea de tiempo ninguna voz empieza antes de que termine la anterior.
	var tl: Array = VoiceDirector.timeline
	var crossed := 0
	for i in range(1, tl.size()):
		if int(tl[i][0]) < int(tl[i - 1][1]) - 30:
			crossed += 1
	t.check(crossed == 0 and int(VoiceDirector.overlaps) == 0 and peak[0] <= 1, "[%s] una voz a la vez: 0 solapes (%d), máx. %d voces, %d cruces en la línea de tiempo" % [lang, int(VoiceDirector.overlaps), peak[0], crossed])
	t.check(VoiceDirector.lost_important.is_empty(), "[%s] ninguna línea importante perdida %s" % [lang, str(VoiceDirector.lost_important)])
	var sung_ok := 0
	for id2 in order:
		if str(id2).begins_with("karaoke_bien"):
			sung_ok += 1
	t.check(sung_ok >= 3, "[%s] cantaste con el teclado y Rasec lo dijo (%d «¡Eso!»)" % [lang, sung_ok])
	Engine.time_scale = scale
	VoiceDirector.line_started.disconnect(on_start)
	t.get_tree().process_frame.disconnect(watch)
	await t.back_to_menu()


## Acelerado (como los bots): termina, y lo que suena es el verso que se lee.
func _fast(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := t.main.get("contacts") as ContactManager
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.frames(3)
	VoiceDirector.stop_all("prueba")
	VoiceDirector.reset_audit()
	var hub := _hub(t)
	var rasec: RasecControl = hub.rasec
	var mism := [0]
	var n_verse := [0]
	var on_start := func(id2: String, _sp: String, _p: int) -> void:
		if id2.contains("karaoke_verso_"):
			n_verse[0] += 1
			var i := int(id2.get_file().trim_prefix("karaoke_verso_")) - 1
			if rasec.ui == null or rasec.ui.shown_text() != str(KaraokeVoz.verse(i).get("texto", "")):
				mism[0] += 1
	VoiceDirector.line_started.connect(on_start)
	rasec.forced_play = "ok"
	Metrics.set_aux(Metrics.Aux.BO)
	rasec.call_event("karaoke")
	await t.frames(3)
	t.player().stand_up()
	await t.frames(2)
	var mk := hub.marker("evento_rasec")
	if mk != null:
		t.player().teleport(mk.global_position, 0.0)
	t.check(await t.until(func() -> bool: return rasec.state == RasecControl.State.EVENTO, 20.0), "empieza el evento")
	t.check(await t.until(func() -> bool: return rasec.state == RasecControl.State.HECHO, 240.0), "a ×8 el evento termina")
	t.check(rasec.sung.size() == 5, "se pidieron los 5 versos cantados (%d)" % rasec.sung.size())
	t.check(mism[0] == 0, "lo que suena es siempre el verso que se lee (%d versos sonaron, %d distintos de la pantalla)" % [n_verse[0], mism[0]])
	t.check(int(VoiceDirector.overlaps) == 0, "0 solapes (%d)" % int(VoiceDirector.overlaps))
	rasec.forced_play = ""
	VoiceDirector.line_started.disconnect(on_start)
	await t.back_to_menu()

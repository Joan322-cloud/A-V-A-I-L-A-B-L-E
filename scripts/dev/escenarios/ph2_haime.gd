## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## v0.3.2 · Haime (calibraciones): `--escenario ph2` corre todos.
##   h2_subtitulos_voz  cada subtítulo posible de Haime (ES y EN) = el texto con el que se sintetizó su voz
##                      (data/haime_voz.json), el archivo es ese (md5) y suena ese (sin variante ni desfase); en
##                      sesiones reales, cada subtítulo emitido = el texto de la voz que sonó en ese fotograma
##   h2_duracion        largo real (s a 1x) de la 1.ª, 2.ª, 3.ª (advertencia) y 4.ª (fatal) del turno: 40-55 s y la
##                      fatal ≤ 40 s, dentro de lo que calculó el guion (min_s..max_s); silencio y hueco máximo
##   h2_ritmo           a 1x de verdad (la voz manda): las 4 del turno con el VoiceDirector: 0 solapes, 0 líneas de
##                      Haime vencidas, ningún hueco > 1,5 s sin voz ni nada pasando, ninguna línea > 5,5 s; 200
##                      guiones armados (ES/EN) caben en 40-55 s por el camino corto y por el largo
##   h2_variedad        20 sesiones simuladas (misma partida, niveles 1-3, 5 tipos de caso): estructuras y líneas
##   h2_escalera        1.ª fría · 2.ª golpe + te corta y repites el guion · 3.ª cara al máximo, susurros, auricular ·
##                      4.ª calibracion_final; la puerta con seguro y la luz que baja con cada error
##   h2_preguntas       respuestas: bien (sin enojo), mal y tarde (enojo, puntaje), «repite» te corta
##   h2_pausa           la pausa congela la pregunta (tiempo, teclas) y la sesión; al volver sigue igual
##   h2_lunch           en el lunch (Discipline.is_lunch_immune) Haime no llama, y si ya había llamado su plazo se
##                      detiene; al terminar el lunch y la gracia, llama / el plazo sigue
##   h2_ia_mentira      gancho de IA: con /root/IABrain y haime_calibration_penalty() > 0 Haime te echa en cara la
##                      mentira de Ezlaki (beat «mentira»: más enojo y puntaje); sin IABrain, nada
##   h2_gancho_muerte   contrato con el paquete de muertes: en el cuadro en que la fatal pide calibracion_final estás
##                      sentado en «calibracion», Haime sigue en el grupo p5_haime_actor con su `actor` visible, de pie a
##                      su lado de la mesa con las manos sobre ella, y la sala está a oscuras con el rojo del REC; durante
##                      la muerte ni el actor ni las luces se tocan; al reaparecer todo vuelve
##   h2_luz             la escalera de luz: 1.ª y 2.ª con la luz de siempre, la advertencia más oscura, la fatal más
##                      oscura que nunca; en la fatal las luces mueren una por una y termina solo con el REC
##   h2_fatal_sentado   en la fatal no te puedes levantar: te paras y vuelves a estar sentado; la sesión sigue y mata
##   h2_memoria         lo que Haime recuerda de la partida: tardanzas (llegar tras el «Te estoy esperando»), tu frase
##                      de Ezlaki cuando le mientes, calibraciones anteriores; sin memoria, la advertencia igual funciona
##   h2_advertencias    diez advertencias seguidas (tras 2 muertes todas lo son): ninguna estructura se repite seguida
##   h2_gancho_muerte:<v>  el mismo contrato en Difícil (mata la 3.ª: `dificil`), en Modo liviano (`liviano`) y en
##                      inglés (`en`: además cada subtítulo de la fatal = el texto de la voz que suena)
##   h2_en_llamada      con un contacto en curso Haime no llama; llama al terminar el contacto
##   h2_persecucion     mientras te persiguen Haime no llama, y si ya había llamado su plazo no corre; sentarte en la
##                      sala con un cazador encima congela la caza y la sesión se da entera
##   h2_menu_a_mitad    salir al menú en plena fatal: el aviso del HUD, el ambiente, el reloj y el congelado vuelven a
##                      su sitio; al continuar la partida, Haime vuelve a llamarte por ese contacto
##   h2_pausa_fatal     pausa en el último tramo de la fatal: nada corre; al volver, mata igual y con el mismo contrato
##   h2_llamado_en_cola su llamado por los parlantes quedó en cola detrás de la voz de un cliente y llegas antes de que
##                      suene: al sentarte se saca de la cola (no suena encima del principio de la sesión)
##   h2_de_a_uno        su llamado pasa por hub.can_interrupt: con otro ocupándote (hub.busy) espera aunque ya tocara, y
##                      el plazo de 8 min empieza cuando el llamado sale, no cuando tocaba
##   h2_voz_ajena       nadie más habla en una calibración: una voz en cola desde antes (lo que piensa tu agente) y otra
##                      que llega a mitad se cortan al empezar, su subtítulo no queda en el HUD y Haime no espera

const TEXT_ONLY: Array[String] = ["noshow", "noshow_canal", "llamado_1", "llamado_2", "llamado_3", "llamado_final", "llamado_1_correo",
	"llamado_2_correo", "llamado_3_correo", "llamado_1_kyc", "llamado_2_kyc", "llamado_3_kyc", "llamado_1_chat", "llamado_2_chat"]
const NO_VOICE: Array[String] = ["_comentario", "pasillo", "scr_haime", "scr_inasistencia"]
const TIPOS: Array[String] = ["llamada", "chat", "correo", "vitzo", "kyc"]

var last_voiced := 0.0
var last_pacing: Dictionary = {}
var first_mark := -1.0
var _sub_bad: Array[String] = []
var _sub_n: int = 0


func escenarios() -> Array[String]:
	return ["h2_subtitulos_voz", "h2_duracion", "h2_ritmo", "h2_variedad", "h2_escalera", "h2_preguntas", "h2_pausa", "h2_lunch", "h2_ia_mentira",
		"h2_gancho_muerte", "h2_gancho_muerte:", "h2_luz", "h2_fatal_sentado", "h2_memoria", "h2_advertencias", "h2_en_llamada", "h2_persecucion",
		"h2_menu_a_mitad", "h2_pausa_fatal", "h2_voz_ajena", "h2_llamado_en_cola", "h2_de_a_uno"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"h2_subtitulos_voz": await _subs(t)
		"h2_duracion": await _duration(t)
		"h2_ritmo": await _rhythm(t)
		"h2_variedad": await _variety(t)
		"h2_escalera": await _ladder(t)
		"h2_preguntas": await _questions(t)
		"h2_pausa": await _pause(t)
		"h2_lunch": await _lunch(t)
		"h2_ia_mentira": await _lie(t)
		"h2_gancho_muerte": await _death_hook(t, _arg)
		"h2_en_llamada": await _on_call(t)
		"h2_persecucion": await _chased(t)
		"h2_menu_a_mitad": await _menu_mid(t)
		"h2_pausa_fatal": await _pause_fatal(t)
		"h2_luz": await _light_ladder(t)
		"h2_fatal_sentado": await _fatal_seated(t)
		"h2_memoria": await _memory(t)
		"h2_advertencias": await _warnings(t)
		"h2_voz_ajena": await _foreign_voice(t)
		"h2_llamado_en_cola": await _queued_summons(t)
		"h2_de_a_uno": await _one_at_a_time(t)


func _p5() -> RefCounted:
	return load("res://scripts/dev/escenarios/p5_personajes.gd").new()


## Tono actual del reproductor de voces del VoiceDirector (1 = normal; -1 si no está).
func _voice_pitch() -> float:
	var pl := VoiceDirector.get("_player") as AudioStreamPlayer
	return pl.pitch_scale if pl != null else -1.0


func _quiet_p5(hub: PersonajesP5) -> void:
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	# Vitzo tampoco: su recordatorio (el de las 03:00 cae en el lunch de T2) no es de estas pruebas, y sin nadie que
	# reaccione mataba al jugador a los 45 s: en h2_lunch corría una carrera con la llamada de Haime (40 s tras la gracia).
	for v in hub.get_tree().get_nodes_in_group("vitzo"):
		(v as Node).process_mode = Node.PROCESS_MODE_DISABLED


# --- subtítulo = voz ------------------------------------------------------------------------------------------------

## Todas las líneas habladas de Haime en los datos: id → {es, en}.
func _spoken_lines() -> Dictionary:
	var out: Dictionary = {}
	var lh := DataLoader.dict("lineas_haime")
	for k in lh.keys():
		if TEXT_ONLY.has(str(k)) or NO_VOICE.has(str(k)):
			continue
		var v: Dictionary = lh[k]
		if str(k) == "pa_llamado":
			for a in GameState.AGENTS:
				out["pa_llamado_" + SaveSlots.slug(a)] = {"es": Loc.fmt(str(v["es"]), {"agente": a}), "en": Loc.fmt(str(v["en"]), {"agente": a})}
			continue
		out[str(k)] = v
	_walk(DataLoader.dict("haime_guiones"), out)
	return out


func _walk(o: Variant, out: Dictionary) -> void:
	if o is Dictionary:
		var d := o as Dictionary
		if d.has("id") and d.has("es") and d.has("en"):
			out[str(d["id"])] = d
			return
		for k in d.keys():
			if str(k) != "opciones" and str(k) != "_comentario":
				_walk(d[k], out)
	elif o is Array:
		for x in o:
			_walk(x, out)


func _subs(t: Node) -> void:
	var lines := _spoken_lines()
	var voces: Dictionary = DataLoader.dict("haime_voz").get("voces", {})
	t.check(voces.size() >= 400, "índice de voz de Haime: %d voces" % voces.size())
	var bad: Array[String] = []
	var files := 0
	var lang0 := Loc.language
	for id in lines.keys():
		for lang in ["es", "en"]:
			var sub := str((lines[id] as Dictionary).get(lang, ""))
			if sub.contains("{"):
				bad.append("%s/%s: marcador en una línea hablada «%s»" % [id, lang, sub])
				continue
			var said := HaimeVoz.text(id, lang)
			if said != sub:
				bad.append("%s/%s: subtítulo «%s» ≠ voz «%s»" % [id, lang, sub, said])
				continue
			var e: Dictionary = ((voces.get(id, {}) as Dictionary).get(lang, {}))
			var path := "res://assets/audio/voces/haime/%s%s.ogg" % ["en/" if lang == "en" else "", id]
			if not FileAccess.file_exists(path):
				bad.append("%s/%s: falta %s" % [id, lang, path])
				continue
			if FileAccess.get_md5(path) != str(e.get("md5", "")):
				bad.append("%s/%s: el archivo no es el que se sintetizó con ese texto (md5)" % [id, lang])
				continue
			# Suena ESE archivo: sin variante elegida por parecido ni desfase de índice.
			Loc.language = lang
			var played := AudioManager.voice_path(AudioManager.voice_slot("haime", str(id), ""))
			Loc.language = lang0
			if played != path:
				bad.append("%s/%s: suena %s" % [id, lang, played])
				continue
			files += 1
	Loc.language = lang0
	t.check(bad.is_empty(), "%d líneas habladas × ES/EN: subtítulo = texto de la voz, archivo y md5 (%d archivos; fallan %d: %s)" % [lines.size(), files, bad.size(), "; ".join(bad.slice(0, 6))])
	# Sesiones armadas (todos los niveles y tipos, ES y EN): cada línea que se dice tiene voz y su texto es el de la voz.
	var sbad: Array[String] = []
	var n_lines := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	await t.start_shift("Jiroshi", 1)
	for lang in ["es", "en"]:
		Loc.language = lang
		var mem: Dictionary = {}
		for i in 40:
			var tipo := TIPOS[i % TIPOS.size()]
			var e := _entry(tipo, i)
			var nivel := 1 + (i / 5) % 4
			var s := HaimeGuion.build_session(e, nivel, nivel == 4, nivel == 3, rng, mem, 4)
			HaimeGuion.remember_session(mem, s)
			for b in s["beats"]:
				for part in _parts(b as Dictionary):
					n_lines += 1
					var key := str((part as Dictionary).get("key", ""))
					var txt := str((part as Dictionary).get("text", ""))
					if not HaimeVoz.has(key) or HaimeVoz.text(key) != txt or txt.contains("{"):
						sbad.append("%s/%s «%s» (voz «%s»)" % [key, lang, txt, HaimeVoz.text(key)])
	Loc.language = lang0
	t.check(sbad.is_empty(), "80 sesiones armadas (ES/EN): %d líneas, todas con voz y texto = voz (fallan %d: %s)" % [n_lines, sbad.size(), "; ".join(sbad.slice(0, 5))])
	# Sesiones reales: lo que sale como subtítulo en el mismo fotograma en que suena la voz.
	for lang in ["es", "en"]:
		Loc.language = lang
		_sub_bad.clear()
		_sub_n = 0
		var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
		_quiet_p5(hub)
		VoiceDirector.subtitle_shown.connect(_on_sub)  # v0.3.2: los subtítulos los emite el VoiceDirector con cada voz
		for n in [1, 3]:
			PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
			PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
			hub.qa.test_answers = ["mal", "tarde", "ok", "tarde"]
			await _one_session(t, hub, ["prometer_sin_verificar", "respuesta_vaga"])
			await _back_to_desk(t)
		VoiceDirector.subtitle_shown.disconnect(_on_sub)
		t.check(_sub_n >= 12 and _sub_bad.is_empty(), "%s: %d subtítulos de Haime en 2 sesiones reales, cada uno = el texto de la voz que sonó (fallan %d: %s)" % [lang, _sub_n, _sub_bad.size(), "; ".join(_sub_bad.slice(0, 4))])
		await t.back_to_menu()
	Loc.language = lang0


func _on_sub(speaker: String, text: String, _secs: float) -> void:
	if speaker != "haime" or not text.begins_with("[Haime] "):
		return
	_sub_n += 1
	# La voz que el director está haciendo sonar en este mismo momento (no la última pedida): su archivo → su texto.
	var cur: Variant = VoiceDirector.current
	var path := str(cur.path) if cur != null else ""
	var id := path.get_file().get_basename()
	var said := HaimeVoz.text(id)
	if said == "" or said != text.trim_prefix("[Haime] ") or path != str(AudioManager.last_voice.get("path", "")):
		_sub_bad.append("«%s» con %s («%s»)" % [text, path, said])


func _parts(b: Dictionary) -> Array:
	var out: Array = []
	for k in ["pre", "caso", "post"]:
		if b.has(k) and str((b[k] as Dictionary).get("key", "")) != "":
			out.append(b[k])
	if str(b.get("key", "")) != "":
		out.append(b)
	return out


## Un contacto malo de cada tipo (con sus marcas reales) para el constructor.
func _entry(tipo: String, i: int) -> Dictionary:
	var marks: Dictionary = {
		"llamada": [["prometer_sin_verificar", "respuesta_vaga"], ["calmese"], ["dato_personal", "culpar_cliente", "molesto"]],
		"chat": [["respuesta_plantilla", "info_incorrecta"], ["desentenderse"], ["prometer_reembolso", "respuesta_sin_revisar"]],
		"correo": [["correo_plantilla", "destinatario_equivocado"], ["sin_enviar"], ["tipificacion", "correo_campo_monto", "correo_tiempo"]],
		"vitzo": [["falta_portal", "sin_pod"], ["falta_portal"], ["correo_innecesario", "falta_portal"]],
		"kyc": [["kyc_aprobar"], ["kyc_rechazar", "kyc_escalar"], ["kyc_sin_decision"]],
	}
	var canales := {"llamada": "llamada", "chat": "chat", "correo": "correo", "vitzo": "correo", "kyc": "kyc"}
	var id := "sim_%s_%d" % [tipo, i]
	var det: Dictionary = (PersonajesP5.counter(HaimeGuion.DETAIL_KEY, {}) as Dictionary).duplicate(true)
	var casos := (DataLoader.dict("haime_guiones").get("casos", {}) as Dictionary).keys()
	det[id] = {"tipo": tipo, "base": str(casos[i % casos.size()]) if i % 2 == 0 else "", "correo": {}, "kyc": ""}
	PersonajesP5.set_counter(HaimeGuion.DETAIL_KEY, det)
	var ms: Array = (marks[tipo] as Array)[i % 3]
	return {"id": id, "hora": GameState.clock_text_at(3600.0 + i * 600.0), "reloj": 3600.0 + i * 600.0, "marcas": ms, "canal": canales[tipo], "transcripcion": []}


# --- duración -------------------------------------------------------------------------------------------------------

## Contacto malo → llamada → a la sala; devuelve los segundos reales (a 1x) desde que te sientas hasta el final.
func _one_session(t: Node, hub: PersonajesP5, marks: Array) -> float:
	var p5 := _p5()
	p5.call("_bad_contact", marks)
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	var seq: Array = t.spy("death_sequence_started")
	await p5.call("_go_calibration", t)
	# Segundos de juego-real (delta ya escalado por time_scale = lo que dura a 1x, sin depender de la carga de la máquina).
	var real := 0.0
	while hub.qa.state != QaFeedback.State.SESION and real < 5.0:
		await t.frames(1)
		real += t.get_process_delta_time()
	first_mark = -1.0
	while (hub.qa.state == QaFeedback.State.SESION and seq.is_empty()) and real < 400.0:
		await t.frames(1)
		real += t.get_process_delta_time()
		if first_mark < 0.0 and hub.qa.beats_done.has("marca"):
			first_mark = hub.qa.clock
	last_pacing = hub.qa.pacing()
	# El reloj de la propia sesión (desde que te sientas hasta que termina o pide la muerte): el de esta prueba arranca
	# unos cuadros tarde (termina de «sentarse» con la sesión ya empezada).
	real = hub.qa.clock
	last_voiced = float(last_pacing["voz"]) / maxf(real, 0.001)
	return real


func _duration(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var seq: Array = t.spy("death_sequence_started")
	var out: Array[String] = []
	for round_i in 2:
		for n in range(1, 5):
			PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
			PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
			hub.qa.test_answers = ["tarde", "mal", "ok", "tarde"] if round_i == 0 else ["ok", "ok", "mal", "ok"]
			var s: float = await _one_session(t, hub, ["prometer_sin_verificar", "respuesta_vaga"] if round_i == 0 else ["dato_personal", "culpar_cliente", "molesto"])
			var lo := float(hub.qa.session.get("min_s", 0.0))
			var hi := float(hub.qa.session.get("max_s", 0.0))
			out.append("%d.ª %.1f s (silencio %d %%, hueco máx %.1f s, %d líneas, la más larga %.1f s, %d preguntas, 1.er error en rojo a los %.1f s)" % [n, s, int(float(last_pacing["silencio_pct"])), float(last_pacing["hueco"]), hub.qa.session_log.size(), float(last_pacing["linea_max"]), hub.qa.answers.size(), first_mark])
			t.note("calibración %d: %.1f s reales (guion %.1f-%.1f) · %s · fin %s" % [n, s, lo, hi, str(hub.qa.session.get("firma", "")), hub.qa.last_session_end])
			t.check(s >= lo - 0.4 and s <= hi + 1.2, "calibración %d: dura lo que calculó el guion (%.1f en %.1f-%.1f s)" % [n, s, lo, hi])
			t.check(float(last_pacing["hueco"]) <= 1.5, "calibración %d: ningún hueco de más de 1,5 s sin voz ni nada pasando (%.2f s a los %.1f s)" % [n, float(last_pacing["hueco"]), float(last_pacing["hueco_en"])])
			t.check(float(last_pacing["linea_max"]) <= 5.5, "calibración %d: ninguna línea de más de 5,5 s (%.1f s, %s)" % [n, float(last_pacing["linea_max"]), str(last_pacing["linea_max_id"])])
			t.check(first_mark > 0.0 and first_mark <= (16.5 if n < 3 else 21.5), "calibración %d: el primer error en rojo llega pronto (a los %.1f s)" % [n, first_mark])
			if n < 3:
				t.check(s >= 40.0 and s <= 55.0, "calibración %d entre 40 y 55 s reales (%.1f)" % [n, s])
				await _back_to_desk(t)
			elif n == 3:
				t.check(s >= 45.0 and s <= 60.0, "la advertencia entre 45 y 60 s reales (%.1f)" % s)
				await _back_to_desk(t)
			else:
				t.check(s >= 45.0 and s <= 70.0 and not seq.is_empty(), "la fatal es una calibración completa (45-70 s) y mata (%.1f s)" % s)
				await t.wait_death_shown(15.0)
				await t.reconnect()
				await t.frames(3)
				seq.clear()
				_p5().call("_quiet", t)
				_quiet_p5(hub)
				hub.qa.kills_shift = 0
				PersonajesP5.set_counter("p5_qa_muertes", 0)
				PersonajesP5.set_counter("p5_qa_bloqueo_hasta", -INF)
				GameState.stop_calm()
				await t.seconds(61.0)  # gracia tras reaparecer
				await _back_to_desk(t)
	t.note("DURACION " + " · ".join(out))
	await t.back_to_menu()


## A 1x de verdad: aquí manda la voz (el VoiceDirector marca cuándo termina cada línea). Las 4 calibraciones del turno.
func _rhythm(t: Node) -> void:
	# 1) Guiones armados: caben en 40-55 s por el camino corto y por el largo; ninguna línea pasa de 5,5 s (ES y EN).
	await t.start_shift("Jiroshi", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lang0 := Loc.language
	var bad: Array[String] = []
	var long_l: Array[String] = []
	var lo := 999.0
	var hi := 0.0
	var fat := 0.0
	var built := 0
	for lang in ["es", "en"]:
		Loc.language = lang
		var mem: Dictionary = {}
		for i in 100:
			var tipo := TIPOS[i % TIPOS.size()]
			var e := _entry(tipo, i)
			if i % 7 == 3:
				e["marcas"] = ["dato_personal", "culpar_cliente", "molesto", "respuesta_vaga"] if tipo == "llamada" else (e["marcas"] as Array)
			var nivel := 1 + (i / 5) % 4
			var opts := {"mentira": 2} if i % 9 == 4 else ({"entrada": "pone_coaching"} if i % 9 == 7 else {})
			var s := HaimeGuion.build_session(e, nivel, nivel == 4, nivel == 3, rng, mem, 4, opts)
			HaimeGuion.remember_session(mem, s)
			built += 1
			var a := float(s["min_s"])
			var b := float(s["max_s"])
			if nivel == 4:
				fat = maxf(fat, b)
				if a < 45.0 or b > 70.0:
					bad.append("fatal %s %.1f-%.1f s" % [lang, a, b])
			elif nivel == 3:
				if a < 45.0 or b > 60.0:
					bad.append("advertencia %s %s %.1f-%.1f s" % [tipo, lang, a, b])
			else:
				lo = minf(lo, a)
				hi = maxf(hi, b)
				if a < 40.3 or b > 54.5:
					bad.append("n%d %s %s %.1f-%.1f s (%s)" % [nivel, tipo, lang, a, b, str(s["firma"])])
			for b2 in s["beats"]:
				for part in _parts(b2 as Dictionary) + _reactions(b2 as Dictionary):
					var key := str((part as Dictionary).get("key", ""))
					if HaimeVoz.speech_end(key) > 5.5:
						long_l.append("%s/%s %.1f s" % [key, lang, HaimeVoz.speech_end(key)])
	Loc.language = lang0
	t.note("RITMO %d guiones armados: 1.ª-3.ª %.1f-%.1f s (corto-largo), fatal hasta %.1f s" % [built, lo, hi, fat])
	t.check(bad.is_empty(), "%d guiones (ES/EN, con y sin mentira/entrada): 1.ª-3.ª en 40-55 s por cualquier camino y fatal ≤ 40 s (fuera %d: %s)" % [built, bad.size(), "; ".join(bad.slice(0, 5))])
	t.check(long_l.is_empty(), "ninguna línea de una calibración dura más de 5,5 s (%d: %s)" % [long_l.size(), "; ".join(long_l.slice(0, 6))])
	await t.back_to_menu()
	# 2) Sesiones reales a 1x.
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var seq: Array = t.spy("death_sequence_started")
	var scale0 := Engine.time_scale
	var out: Array[String] = []
	for n in range(1, 5):
		PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		hub.qa.test_answers = [["ok", "tarde"], ["tarde", "mal", "ok"], ["mal", "ok"], []][n - 1]
		var p5 := _p5()
		p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga", "calmese"] if n == 2 else ["prometer_sin_verificar", "respuesta_vaga"])
		await t.frames(1)
		await t.set_clock(hub.qa.call_at + 1.0)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
		Engine.time_scale = 1.0  # desde antes de sentarte: la sesión empieza en cuanto te sientas (con el llamado de los parlantes aún sonando)
		VoiceDirector.reset_audit()
		_sub_bad.clear()
		_sub_n = 0
		VoiceDirector.subtitle_shown.connect(_on_sub)
		await p5.call("_go_calibration", t)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)
		var wall := 0.0
		var two := 0
		var pitch_n := 0  # cuadros con una línea suya sonando…
		var pitch_bad := 0  # …y de esos, cuántos fuera del tono del nivel
		var other_bad := 0  # cuadros en que otra cosa (la grabación de tu contacto) sonaba con el tono cambiado
		var vp := HaimeGuion.voice_pitch(int(hub.qa.session.get("nivel", 1)))
		while hub.qa.state == QaFeedback.State.SESION and seq.is_empty() and wall < 120.0:
			await t.frames(1)
			wall += t.get_process_delta_time()
			if VoiceDirector.voices_playing() > 1:
				two += 1
			var cur: Variant = VoiceDirector.current
			if cur != null and bool(cur.has_audio) and cur.external == null and hub.qa.state == QaFeedback.State.SESION and seq.is_empty():
				if str(cur.speaker) == "haime":
					pitch_n += 1
					if not is_equal_approx(_voice_pitch(), vp):
						pitch_bad += 1
				elif not is_equal_approx(_voice_pitch(), 1.0):
					other_bad += 1
		Engine.time_scale = scale0
		VoiceDirector.subtitle_shown.disconnect(_on_sub)
		var real: float = hub.qa.clock
		var pc: Dictionary = hub.qa.pacing()
		var a := float(hub.qa.session.get("min_s", 0.0))
		var b := float(hub.qa.session.get("max_s", 0.0))
		out.append("%d.ª %.1f s (guion %.1f-%.1f; silencio %d %%; hueco máx %.2f s; línea más larga %.1f s; %d voces, %d solapes)" % [n, real, a, b, int(float(pc["silencio_pct"])), float(pc["hueco"]), float(pc["linea_max"]), VoiceDirector.lines_said, VoiceDirector.overlaps])
		t.check(VoiceDirector.overlaps == 0 and two == 0, "%d.ª a 1x: 0 solapes de voz (%d; cuadros con 2 voces %d)" % [n, VoiceDirector.overlaps, two])
		t.check(pitch_n > 100 and pitch_bad == 0 and other_bad == 0 and ((n <= 2 and vp == 1.0) or (n >= 3 and vp < 1.0)), "%d.ª a 1x: su voz suena %s (×%.2f en %d cuadros; fuera de tono %d; otra voz con el tono cambiado %d)" % [n, "normal" if n <= 2 else "más grave y lenta", vp, pitch_n, pitch_bad, other_bad])
		t.check(_voice_pitch() == 1.0, "%d.ª a 1x: al terminar el reproductor de voces queda a su tono normal (×%.2f)" % [n, _voice_pitch()])
		t.check(hub.qa.lost.is_empty() and hub.qa.skipped.is_empty(), "%d.ª a 1x: ninguna línea de Haime vencida ni extra saltado (%s, %s)" % [n, str(hub.qa.lost), str(hub.qa.skipped)])
		t.check(_sub_n == hub.qa.session_log.size() and _sub_bad.is_empty(), "%d.ª a 1x: cada línea del guion sonó por el director con su subtítulo = el texto de esa voz (%d de %d; fallan %d: %s)" % [n, _sub_n, hub.qa.session_log.size(), _sub_bad.size(), "; ".join(_sub_bad.slice(0, 3))])
		t.check(float(pc["hueco"]) <= 1.5, "%d.ª a 1x: ningún hueco > 1,5 s (%.2f s a los %.1f s)" % [n, float(pc["hueco"]), float(pc["hueco_en"])])
		# Cada línea entra uno o dos cuadros después de la anterior: con la máquina cargada (pocos cuadros por segundo en
		# headless) eso suma; el margen crece con las líneas dichas.
		t.check(real >= a - 0.4 and real <= b + 1.5 + 0.05 * float(VoiceDirector.lines_said), "%d.ª a 1x: dura lo que calculó el guion (%.1f en %.1f-%.1f, %d líneas)" % [n, real, a, b, VoiceDirector.lines_said])
		if n < 3:
			t.check(real >= 40.0 and real <= 55.0, "%d.ª a 1x entre 40 y 55 s (%.1f)" % [n, real])
			await _back_to_desk(t)
		elif n == 3:
			t.check(real >= 45.0 and real <= 60.5, "la advertencia a 1x entre 45 y 60 s (%.1f)" % real)
			await _back_to_desk(t)
		else:
			t.check(real >= 45.0 and real <= 70.5 and not seq.is_empty(), "la fatal a 1x: 45-70 s y mata (%.1f)" % real)
	t.note("RITMO 1x " + " · ".join(out))
	await t.wait_death_shown(15.0)
	await t.back_to_menu()


func _reactions(b: Dictionary) -> Array:
	var out: Array = []
	for k in ["r_bien", "r_mal", "r_tarde", "r_corta"]:
		if b.has(k) and str((b[k] as Dictionary).get("key", "")) != "":
			out.append(b[k])
	return out


## De vuelta a C-14 en Available (como el bot: si no, Discipline te caza por estar fuera del puesto).
func _back_to_desk(t: Node) -> void:
	var p5 := _p5()
	t.player().stand_up()
	await t.frames(1)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await p5.call("_sit", t, "C-14")
	await t.frames(2)


# --- variedad -------------------------------------------------------------------------------------------------------

func _variety(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mem: Dictionary = {}
	var sigs: Dictionary = {}
	var openings: Dictionary = {}
	var first_marks: Dictionary = {}
	var sets: Array = []
	var all_ids: Dictionary = {}
	var per_level: Dictionary = {}
	var secs: Array[float] = []
	for i in 20:
		var nivel := 1 + i % 3
		var tipo := TIPOS[(i / 3) % TIPOS.size()]
		var e := _entry(tipo, i)
		var s := HaimeGuion.build_session(e, nivel, false, nivel == 3, rng, mem, 4)
		HaimeGuion.remember_session(mem, s)
		sigs[str(s["firma"])] = int(sigs.get(str(s["firma"]), 0)) + 1
		var beats: Array = s["beats"]
		openings[("frase-" if (beats[0] as Dictionary).has("key") else "mira-") + HaimeGuion.signature(beats.slice(1, 3))] = true  # cómo entra (dice algo al cerrar o solo te mira) y con qué sigue
		for b in beats:
			if str((b as Dictionary).get("k", "")) == "marca":
				first_marks["%s:%s" % [tipo, str((b as Dictionary).get("mark", ""))]] = true
				break
		var ids: Dictionary = {}
		for id in s["lineas"]:
			ids[id] = true
			all_ids[id] = int(all_ids.get(id, 0)) + 1
		sets.append(ids)
		var lvl: Array = per_level.get(nivel, [])
		lvl.append(ids)
		per_level[nivel] = lvl
		secs.append(float(s["segundos"]))
	var jac := 0.0
	var pairs := 0
	var jmax := 0.0
	for a in sets.size():
		for b in range(a + 1, sets.size()):
			var j := _jaccard(sets[a], sets[b])
			jac += j
			jmax = maxf(jmax, j)
			pairs += 1
	jac /= float(maxi(pairs, 1))
	var jl := 0.0
	var pl := 0
	for lv in per_level.keys():
		var arr: Array = per_level[lv]
		for a in arr.size():
			for b in range(a + 1, arr.size()):
				jl += _jaccard(arr[a], arr[b])
				pl += 1
	jl /= float(maxi(pl, 1))
	var repeated := 0
	var total := 0
	var rep_pool := 0
	var tot_pool := 0
	for id in all_ids.keys():
		total += int(all_ids[id])
		if int(all_ids[id]) > 1:
			repeated += int(all_ids[id]) - 1
		# Las fijas por regla (la advertencia) y la descripción del caso (cada caso tiene la suya) no cuentan como pool.
		if not (str(id) in ["advertencia", "advertencia_cierre"] or str(id).begins_with("q4_caso_")):
			tot_pool += int(all_ids[id])
			rep_pool += maxi(int(all_ids[id]) - 1, 0)
	var smin := 999.0
	var smax := 0.0
	for x in secs:
		smin = minf(smin, x)
		smax = maxf(smax, x)
	t.note("VARIEDAD 20 sesiones: %d estructuras distintas · %d aperturas · %d primeras marcas · %d líneas distintas de %d dichas (%.0f %% repetidas; de los grupos al azar %.0f %%) · Jaccard medio %.3f (mismo nivel %.3f, máx %.3f) · %.0f-%.0f s estimados" % [sigs.size(), openings.size(), first_marks.size(), all_ids.size(), total, 100.0 * repeated / float(maxi(total, 1)), 100.0 * rep_pool / float(maxi(tot_pool, 1)), jac, jl, jmax, smin, smax])
	t.check(sigs.size() >= 19, "20 sesiones: %d estructuras distintas (≥ 19)" % sigs.size())
	t.check(openings.size() >= 8, "aperturas distintas: %d (≥ 8)" % openings.size())
	t.check(jac <= 0.12 and jl <= 0.2, "líneas: Jaccard medio %.3f (≤ 0,12), mismo nivel %.3f (≤ 0,2)" % [jac, jl])
	t.check(float(rep_pool) / float(maxi(tot_pool, 1)) <= 0.25, "líneas de los grupos al azar: como mucho 25 %% repetidas en 20 sesiones (%d de %d)" % [rep_pool, tot_pool])
	await t.back_to_menu()


func _jaccard(a: Dictionary, b: Dictionary) -> float:
	var inter := 0
	for k in a.keys():
		if b.has(k):
			inter += 1
	var uni := a.size() + b.size() - inter
	return float(inter) / float(maxi(uni, 1))


# --- escalera, sala, preguntas --------------------------------------------------------------------------------------

func _ladder(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var seq: Array = t.spy("death_sequence_started")
	for n in range(1, 5):
		PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		hub.qa.test_answers = ["tarde", "tarde", "mal", "tarde"]
		var p5 := _p5()
		p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
		await t.frames(1)
		await t.set_clock(hub.qa.call_at + 1.0)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
		await p5.call("_go_calibration", t)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
		var actor := t.get_tree().get_first_node_in_group("p5_haime_actor")
		await t.until(func() -> bool: return hub.qa.beats_done.size() >= 2, 10.0)
		t.check(actor != null and bool(actor.call("door_locked")), "%d.ª: la puerta se cierra con seguro" % n)
		var hint := (t.main.find_child("HUD", true, false) as Node).get("_hint") as Label
		t.check(hint != null and hint.offset_top > hint.get_viewport_rect().size.y * 0.25, "%d.ª: el aviso «[E] Levantarse» baja al pie (no tapa la cara de Haime)" % n)
		var max_sev := 0
		var looked := true
		var dim_after_mark := -1.0
		var stood := false
		var faced := false
		var was_behind := false
		var lights_dead := 0
		var braced_at_death := false
		var asked_up := false  # te preguntó estando de pie
		var q_lean := false  # y mientras contestabas se apoyó en la mesa
		var prewritten: bool = hub.qa.ui != null and hub.qa.ui.prewritten_shown
		while hub.qa.state == QaFeedback.State.SESION and seq.is_empty():
			await t.frames(2)
			if actor != null:
				was_behind = was_behind or bool(actor.call("is_behind"))
				lights_dead = maxi(lights_dead, int(actor.get("lights_dead")))
				if seq.is_empty() and hub.qa.state == QaFeedback.State.SESION:
					braced_at_death = bool(actor.call("is_braced"))  # la última muestra antes de la muerte (la muerte limpia la sala)
				max_sev = maxi(max_sev, int(actor.get("severity")))
				looked = looked and (bool(actor.get("_looking")) or hub.qa.state != QaFeedback.State.SESION)
				stood = stood or bool(actor.get("_standing"))
				faced = faced or bool(actor.get("_face"))
				if hub.qa.beat_now == "pregunta" and bool(actor.get("_standing")) and hub.qa.ui != null and hub.qa.ui.asking():
					asked_up = true
					q_lean = q_lean or not bool(actor.call("is_upright"))
				if hub.qa.heard_opportunities >= 1 and dim_after_mark < 0.0:
					dim_after_mark = float(actor.get("dim"))
		var done: Array[String] = hub.qa.beats_done
		var log_s := str(hub.qa.session_log)
		t.note("%d.ª: %s · enojo %d · %s" % [n, str(hub.qa.session.get("firma", "")), hub.qa.anger, str(hub.qa.answers)])
		t.check(dim_after_mark > 0.0, "%d.ª: la luz baja con el primer error (dim %.2f)" % [n, dim_after_mark])
		t.check(looked, "%d.ª: te mira toda la sesión" % n)
		t.check(_voice_pitch() == 1.0, "%d.ª: al terminar (o al pedir la muerte) el reproductor de voces queda a su tono normal (×%.2f)" % [n, _voice_pitch()])
		if n >= 3:
			t.check(q_lean or not asked_up, "%d.ª: si te pregunta de pie, mientras contestas se apoya en la mesa (de pie %s, apoyado %s)" % [n, str(asked_up), str(q_lean)])
		match n:
			1:
				t.check(not done.has("golpe") and not done.has("amenaza") and not done.has("auricular") and not stood, "1.ª fría: sentado, sin golpes, sin susurros (%s)" % str(done))
			2:
				t.check(done.has("golpe") and stood, "2.ª: golpea la mesa y se levanta (%s)" % str(done))
				t.check(log_s.contains("h2_t_saludo_") and log_s.contains("h2_corta_"), "2.ª: te hace repetir el guion y te corta (%s)" % log_s)
			3:
				# v0.3.2 (Joan: «que la última sea aún más»): más frío que nunca, sin golpes; se acerca hasta ponerse detrás de ti.
				t.check(max_sev == 3 and stood and was_behind and done.has("detras") and done.has("auricular"), "3.ª: empieza sentado, se levanta, termina detrás de ti con la cara al máximo y te quita el auricular (sev %d, %s)" % [max_sev, str(done)])
				t.check(not done.has("golpe") and not done.has("silencio"), "3.ª: ni golpes ni gritos ni saltos: calma (%s)" % str(done))
				var voces: Dictionary = DataLoader.dict("haime_voz").get("voces", {})
				var whisper := hub.qa.session_log.filter(func(k: Variant) -> bool: return str(k).begins_with("h2_amz_") or str(k).begins_with("h2_det_"))
				var all_w := whisper.size() >= 1
				for k in whisper:
					all_w = all_w and str(((voces.get(str(k), {}) as Dictionary).get("es", {}) as Dictionary).get("estilo", "")) == "susurro"
				t.check(all_w, "3.ª: te habla al oído en susurros (%s)" % str(whisper))
				t.check(log_s.contains("h2_advp_") and (hub.qa.session.get("beats", [])[0] as Dictionary).get("doble", false), "3.ª: dos vueltas de llave (%s)" % log_s)
				t.check(done.has("recuerdo") and not hub.qa.ui_history.is_empty(), "3.ª: recuerda tus calibraciones anteriores de la partida (%s)" % str(hub.qa.ui_history))
				t.check(log_s.contains("h2_voz_") and log_s.contains("h2_advc_"), "3.ª: te pone tu propia voz y te corta la respuesta (%s)" % log_s)
				t.check(hub.qa.session_log.has("advertencia") and hub.qa.session_log.has("advertencia_cierre") and str(hub.qa.session_log[-1]).begins_with("h2_advf_"), "3.ª: la última advertencia, y al final te dice sin gritar que no habrá otra (%s)" % str(hub.qa.session_log[-1]))
			4:
				t.check(not seq.is_empty() and str(seq[0][0]) == "calibracion_final", "4.ª: calibracion_final (%s)" % str(seq))
				# v0.3.2 (Joan): la fatal es una calibración completa, la más terrorífica; te mata justo cuando ya lo sabes.
				t.check(prewritten, "4.ª: tu puntaje ya estaba escrito (0) al sentarte")
				t.check(lights_dead >= 2 and done.has("luz"), "4.ª: las luces de la sala mueren una por una (%d)" % lights_dead)
				t.check(done.has("pregunta") and (log_s.contains("h2_igual_") or log_s.contains("h2_advc_")), "4.ª: pregunta lo que ya no importa y corta la respuesta (%s)" % log_s)
				t.check(stood and done.has("pluma") and was_behind and done.has("auricular") and done.has("certeza"), "4.ª: ya no se sienta, deja de anotar, se para detrás, te quita el auricular (%s)" % str(done))
				t.check(braced_at_death and str(hub.qa.session_log[-1]) == "fb3_cierre", "4.ª: la muerte entra con su última frase, él de pie a su lado de la mesa con las manos sobre ella (%s)" % str(hub.qa.session_log[-1]))
				t.check(hub.qa.clock >= 45.0 and hub.qa.clock <= 70.0, "4.ª: dura 45-70 s antes de matarte (%.1f)" % hub.qa.clock)
		if n < 4:
			t.check(actor != null and not bool(actor.call("door_locked")), "%d.ª: al terminar se abre la puerta" % n)
			await t.frames(2)
			t.check(actor != null and float(actor.get("dim")) == 0.0, "%d.ª: la luz vuelve" % n)
			t.check(hint != null and is_equal_approx(hint.offset_top, 20.0) and is_equal_approx(hint.modulate.a, 1.0), "%d.ª: el aviso del HUD vuelve a su sitio" % n)
			await _back_to_desk(t)
	await t.wait_death_shown(15.0)
	await t.back_to_menu()


func _questions(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var cases := [["ok", "ok", "ok", "ok"], ["mal", "tarde", "mal", "tarde"]]
	for ci in cases.size():
		PersonajesP5.set_counter("p5_qa_feedbacks", 1)  # la 2.ª: hay «repite»
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		hub.qa.test_answers = (cases[ci] as Array).duplicate()
		await _one_session(t, hub, ["prometer_sin_verificar", "respuesta_vaga"])
		var res: Array = []
		for a in hub.qa.answers:
			res.append(str((a as Dictionary).get("resultado", "")))
		var log_s := str(hub.qa.session_log)
		if ci == 0:
			t.check(not res.is_empty() and not res.has("mal") and not res.has("tarde") and not res.has("cortado") and hub.qa.anger == 0 and log_s.contains("h2_bien_"), "todo bien: sin enojo (%s, enojo %d)" % [str(res), hub.qa.anger])
		else:
			t.check(hub.qa.anger >= 2 and (log_s.contains("h2_mal_") or log_s.contains("h2_tarde_")) and log_s.contains("h2_corta_"), "mal y tarde: enojo %d, te corta (%s · %s)" % [hub.qa.anger, str(res), log_s])
			t.check(hub.qa.score_now <= 94 and hub.qa.last_session_end == "dada", "el enojo baja el puntaje (%d) y la sesión igual cuenta (%s)" % [hub.qa.score_now, hub.qa.last_session_end])
		await _back_to_desk(t)
	await t.back_to_menu()


func _pause(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	await p5.call("_go_calibration", t)
	t.check(await t.until(func() -> bool: return hub.qa.ui != null and is_instance_valid(hub.qa.ui) and hub.qa.ui.asking(), 120.0), "llega una pregunta")
	if hub.qa.ui == null or not hub.qa.ui.asking():
		return
	var ui: FeedbackUI = hub.qa.ui
	await t.frames(3)
	var left0: float = ui.get("_q_left")
	var log0 := hub.qa.session_log.size()
	var pm: Control = t.main.get("pause_menu")
	pm.call("toggle")
	await t.frames(2)
	left0 = ui.get("_q_left")
	t.check(t.get_tree().paused and pm.visible, "pausa abierta en plena pregunta")
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.seconds(3.0)
	var ev2 := ev.duplicate() as InputEventKey
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await t.frames(2)
	t.check(ui.asking() and absf(float(ui.get("_q_left")) - left0) < 0.05, "en pausa el tiempo de la pregunta no corre y la tecla 1 no responde (%.2f → %.2f)" % [left0, float(ui.get("_q_left"))])
	t.check(hub.qa.session_log.size() == log0 and hub.qa.state == QaFeedback.State.SESION, "en pausa Haime no sigue hablando")
	var main_layer := int((t.main.get_node("UI") as CanvasLayer).layer)
	var pl: CanvasLayer = t.main.get("pause_layer")
	t.check(ui.layer < main_layer and pl != null and pl.layer > ui.layer, "la pausa queda encima de la pantalla del feedback")
	pm.call("toggle")
	await t.frames(3)
	t.check(not t.get_tree().paused, "pausa cerrada")
	t.check(await t.until(func() -> bool: return not ui.asking(), 8.0), "al volver la pregunta sigue y vence")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 150.0), "la sesión termina normal")
	await t.back_to_menu()


func _lunch(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	# A la hora del lunch, con un contacto malo pendiente de Haime.
	await t.set_clock(GameState.lunch_clock())
	await t.frames(2)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var called: Array = t.spy("qa_feedback_called")
	var seq: Array = t.spy("death_sequence_started")
	_p5().call("_bad_contact", ["dato_personal"])
	await t.frames(1)
	PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(Discipline.is_lunch_immune() and hub.qa.lunch_immune(), "AUX Lunch a su hora: inmune (%s)" % Discipline.is_lunch_immune())
	hub.qa.call_at = GameState.clock_seconds
	for i in 40:
		await t.advance_clock(30.0)  # 20 min de juego de lunch
	t.check(called.is_empty() and hub.qa.state == QaFeedback.State.PENDIENTE, "en el lunch Haime no llama (estado %d, llamadas %d)" % [hub.qa.state, called.size()])
	# Al volver del lunch, pasada la gracia y su turno escalonado, llama.
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	var ok: bool = await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 400.0)
	t.check(ok and called.size() == 1, "al terminar el lunch (y la gracia) Haime llama (estado %d)" % hub.qa.state)
	await t.back_to_menu()
	# Ya te había llamado y te vas al lunch a tu hora: el plazo se detiene; al volver, sigue.
	hub = await _p5().call("_prep", t, 2, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	await t.set_clock(GameState.lunch_clock())
	await t.frames(2)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	seq = t.spy("death_sequence_started")
	_p5().call("_bad_contact", ["dato_personal"])
	await t.frames(1)
	hub.qa.call_now()
	await t.frames(2)
	t.check(hub.qa.state == QaFeedback.State.LLAMADO, "Haime te llamó justo antes del lunch")
	await t.advance_clock(60.0)
	var left0: float = hub.qa.seconds_left()
	PerritoRTA.dictate(Metrics.Aux.AVAILABLE)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(hub.qa.lunch_immune(), "en el lunch, con Haime esperando: inmune")
	for i in 50:
		await t.advance_clock(30.0)  # 25 min de juego: más que todo su plazo (8 min)
	var left1: float = hub.qa.seconds_left()
	t.check(seq.is_empty() and hub.qa.state == QaFeedback.State.LLAMADO and absf(left1 - left0) < 45.0, "en el lunch el plazo de Haime no corre (%.0f s → %.0f s) y no mata por inasistencia" % [left0, left1])
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	var resumed: bool = await t.until(func() -> bool: return not hub.qa.lunch_immune(), 400.0)
	await t.advance_clock(60.0)
	t.check(resumed and hub.qa.seconds_left() < left1 - 30.0, "al volver del lunch el plazo sigue (%.0f s)" % hub.qa.seconds_left())
	await t.back_to_menu()


func _lie(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var had := t.get_tree().root.get_node_or_null("IABrain") != null
	t.check(had or hub.qa.lie_penalty() == 0, "sin IABrain no hay castigo")
	var fake: Node = null
	if not had:
		var scr := GDScript.new()
		scr.source_code = "extends Node\nfunc haime_calibration_penalty() -> int:\n\treturn 2\n"
		scr.reload()
		fake = Node.new()
		fake.set_script(scr)
		fake.name = "IABrain"
		t.get_tree().root.add_child(fake)
	# v0.3.2-beta (integración): con el IABrain de verdad cargado, el castigo sale de su contador del turno
	# (IABrain.shift.calibracion, que sube al mentirle a Haime por Ezlaki): se pone a mano y se devuelve al final.
	var brain := t.get_tree().root.get_node_or_null("IABrain")
	var shift0: Variant = null
	if had and brain != null and brain.get("shift") is Dictionary:
		shift0 = int((brain.get("shift") as Dictionary).get("calibracion", 0))
		(brain.get("shift") as Dictionary)["calibracion"] = 2
	t.check(hub.qa.lie_penalty() >= 1, "con IABrain: castigo %d" % hub.qa.lie_penalty())
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await _one_session(t, hub, ["prometer_sin_verificar", "respuesta_vaga"])
	var log_s := str(hub.qa.session_log)
	t.check(hub.qa.beats_done.has("mentira") and log_s.contains("h2_mentira_") and hub.qa.anger >= 2, "Haime te echa en cara la mentira (%s, enojo %d)" % [log_s, hub.qa.anger])
	t.check(hub.qa.last_session_end == "dada", "la sesión igual cuenta")
	if fake != null:
		fake.queue_free()
	if shift0 != null and brain != null and is_instance_valid(brain):
		(brain.get("shift") as Dictionary)["calibracion"] = int(shift0)
	await _back_to_desk(t)
	await t.back_to_menu()


# --- la muerte de la calibración final: contrato con el paquete de muertes ------------------------------------------

var _hook: Dictionary = {}


## Lo que hay en el cuadro del pedido de muerte, después de los oyentes de la sesión y antes del screamer: es lo que
## recibe el paquete de muertes (su intro toma la pose del actor del mundo y lo esconde él).
func _on_death_hook(cause: String, killer: String, _detail: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.get_first_node_in_group("p5_haime_actor")
	var actor: Variant = node.get("actor") if node != null else null
	var pl := tree.get_first_node_in_group("player") as Player
	var a := actor as P5Actor if actor is P5Actor and is_instance_valid(actor) else null
	var seat_pos: Vector3 = node.get("_seat_pos") if node != null else Vector3.ZERO
	var hubq := PersonajesP5.get_hub(tree)
	var ui: FeedbackUI = hubq.qa.ui if hubq != null and hubq.qa != null else null
	var veil: ColorRect = ui.get("_veil") as ColorRect if ui != null and is_instance_valid(ui) else null
	var hud := tree.root.find_child("HUD", true, false)
	var hint: Label = hud.get("_hint") as Label if hud != null else null
	_hook = {
		"veil": veil.color.a if veil != null else 0.0, "hint": hint.modulate.a if hint != null and hint.visible and hint.text != "" else 0.0,
		"cause": cause, "killer": killer, "dying": Checkpoints.dying,
		"seated": pl != null and pl.seated and pl.seat_id == "calibracion" and GameState.seated_at == "calibracion",
		"node": node != null, "actor": a != null, "visible": a != null and a.is_visible_in_tree(),
		"standing": node != null and bool(node.call("is_standing")), "braced": node != null and bool(node.call("is_braced")),
		"behind": node != null and bool(node.call("is_behind")),
		"dist": a.global_position.distance_to(seat_pos) if a != null else 99.0,
		"own_side": a != null and pl != null and a.global_position.distance_to(pl.global_position) > 1.2,
		"anim": a.current_anim if a != null else "",
		"light": float(node.call("room_light")) if node != null else -1.0, "rec": float(node.call("rec_light")) if node != null else -1.0,
		"rec_only": node != null and bool(node.get("rec_only")), "held": node != null and bool(node.call("held_for_death")),
		"door": node != null and bool(node.call("door_locked")),
	}


func _fatal_session(t: Node, hub: PersonajesP5, marks: Array = ["prometer_sin_verificar", "respuesta_vaga"]) -> void:
	PersonajesP5.set_counter("p5_qa_feedbacks", hub.qa.max_per_shift() - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var p5 := _p5()
	p5.call("_bad_contact", marks)
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	await p5.call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)


func _death_hook(t: Node, variant: String = "") -> void:
	var lang0 := Loc.language
	var q0 := GfxQuality.level()
	if variant == "en":
		Loc.language = "en"
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.DIFICIL if variant == "dificil" else Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	if variant == "liviano":
		GfxQuality.apply(t.get_tree(), "liviano")
		await t.frames(4)
		t.check(GfxQuality.is_light(), "Modo liviano puesto")
	if variant == "dificil":
		t.check(hub.qa.max_per_shift() == 3, "Difícil: mata la 3.ª (%d)" % hub.qa.max_per_shift())
	var node := t.get_tree().get_first_node_in_group("p5_haime_actor")
	t.check(node != null and node.get("actor") is P5Actor, "Haime del mundo: grupo p5_haime_actor con su propiedad `actor` (P5Actor)")
	if node == null:
		await t.back_to_menu()
		return
	var light0: float = node.call("room_light")
	var props0 := _room_props(t)
	var amb := AudioServer.get_bus_index("Ambiente")
	var amb0 := AudioServer.get_bus_volume_db(amb) if amb >= 0 else 0.0
	_hook = {}
	EventBus.death_sequence_started.connect(_on_death_hook)
	hub.qa.test_answers = ["ok", "tarde", "mal"]
	_sub_bad.clear()
	_sub_n = 0
	VoiceDirector.subtitle_shown.connect(_on_sub)
	await _fatal_session(t, hub)
	t.check(hub.qa.is_fatal(hub.qa.n_call), "es la fatal (n %d)" % hub.qa.n_call)
	await t.frames(2)
	# La luz del tubo al sentarte y con cada luz que muere (Modo liviano: la escalera la lleva el tubo).
	var dims: Array[float] = [float(node.get("dim"))]
	var died: bool = await t.until(func() -> bool:
		if int(node.get("lights_dead")) >= dims.size() and not bool(node.get("rec_only")):
			dims.append(float(node.get("dim")))  # (el estado va en la lista: una lambda no puede reasignar un local capturado)
		return not _hook.is_empty(), 200.0)
	if variant == "liviano":
		t.check(dims.size() == 3 and dims[0] <= 0.7 and dims[1] >= dims[0] + 0.05 and dims[2] >= dims[1] + 0.05, "Modo liviano: el tubo baja un escalón con cada luz que muere (%s)" % str(dims))
	else:
		t.check(dims.size() == 3 and is_equal_approx(dims[0], dims[2]), "con todas las luces, el tubo no baja: mueren la de afuera y la de tu lado (%s)" % str(dims))
	EventBus.death_sequence_started.disconnect(_on_death_hook)
	VoiceDirector.subtitle_shown.disconnect(_on_sub)
	t.check(_sub_n >= hub.qa.session_log.size() and _sub_bad.is_empty(), "%s: cada línea de la fatal salió con su subtítulo = el texto de su voz (%d de %d; fallan %d: %s)" % [Loc.language, _sub_n, hub.qa.session_log.size(), _sub_bad.size(), "; ".join(_sub_bad.slice(0, 3))])
	t.check(died and str(_hook.get("cause", "")) == "calibracion_final" and str(_hook.get("killer", "")) == "haime" and bool(_hook.get("dying", false)), "la fatal pide calibracion_final con asesino haime (%s)" % str(_hook))
	if not died:
		await t.back_to_menu()
		return
	t.note("en el cuadro del pedido: %s" % str(_hook))
	t.check(bool(_hook["seated"]), "estás sentado en la silla «calibracion»")
	t.check(bool(_hook["node"]) and bool(_hook["actor"]) and bool(_hook["visible"]), "Haime sigue en el grupo p5_haime_actor y su `actor` está visible (no se esconde ni se libera al empezar la muerte)")
	t.check(bool(_hook["standing"]) and bool(_hook["braced"]) and not bool(_hook["behind"]) and float(_hook["dist"]) <= 0.45 and bool(_hook["own_side"]), "está de pie a su lado de la mesa con las manos sobre ella (a %.2f m de su silla; clip %s)" % [float(_hook["dist"]), str(_hook["anim"])])
	t.check(float(_hook["light"]) <= 0.005 and float(_hook["rec"]) >= 0.3 and bool(_hook["rec_only"]), "la sala está a oscuras (luz blanca %.2f de %.2f al empezar) con el rojo del REC encendido (%.2f)" % [float(_hook["light"]), light0, float(_hook["rec"])])
	t.check(bool(_hook["held"]) and bool(_hook["door"]), "la sala queda como la dejó la sesión (retenida para la muerte, puerta con seguro)")
	t.check(float(_hook["veil"]) <= 0.01 and float(_hook["hint"]) <= 0.01, "la imagen es la de la sala: sin velo de pantalla (%.2f) ni «[E] Levantarse» (%.2f)" % [float(_hook["veil"]), float(_hook["hint"])])
	t.check(hub.qa.last_session_end == "fatal" and str(hub.qa.session_log[-1]) == "fb3_cierre", "la muerte entra con su última frase (%s, fin %s)" % [str(hub.qa.session_log[-1]), hub.qa.last_session_end])
	# Durante la muerte: ni el actor ni las luces se tocan (el screamer puede esconder al actor; liberarlo o prender la luz, no).
	var ok_during := true
	var freed := false
	for i in 12:
		await t.frames(1)
		var n2 := t.get_tree().get_first_node_in_group("p5_haime_actor")
		if n2 == null or not (n2.get("actor") is P5Actor) or not is_instance_valid(n2.get("actor")):
			freed = true
			break
		if float(n2.call("room_light")) > 0.005 or not bool(n2.call("held_for_death")):
			ok_during = false
	t.check(not freed and ok_during, "durante la muerte el actor sigue vivo en su grupo y las luces de la sala siguen apagadas")
	t.check(hub.qa.state == QaFeedback.State.LIBRE and t.get_tree().root.find_children("FeedbackUI", "", true, false).size() <= 1, "la sesión terminó (sin pantalla ni voz de Haime colgando)")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.frames(4)
	var n3 := t.get_tree().get_first_node_in_group("p5_haime_actor")
	var back := n3 != null and not bool(n3.call("held_for_death")) and float(n3.call("room_light")) >= light0 * 0.55 and not bool(n3.get("rec_only")) and not bool(n3.call("door_locked"))
	t.check(back, "al reaparecer la sala vuelve: luz %.2f (antes %.2f), sin seguro, sin «solo REC»" % [float(n3.call("room_light")) if n3 != null else -1.0, light0])
	var a3: Variant = n3.get("actor") if n3 != null else null
	t.check(a3 is P5Actor and (a3 as P5Actor).visible and not bool(n3.call("is_standing")), "y Haime vuelve a su silla, visible")
	var amb1 := AudioServer.get_bus_volume_db(amb) if amb >= 0 else 0.0
	t.check(absf(amb1 - amb0) < 0.5, "el ambiente del piso recupera su volumen (%.1f dB → %.1f dB)" % [amb0, amb1])
	# Lo que el screamer mueve (la mesa que salta, el monitor que se vuelca, tu silla que se va de espaldas) y lo que
	# mueve la sesión: al reaparecer, cada cosa exactamente donde estaba antes de sentarte.
	await t.frames(20)
	var props1 := _room_props(t)
	var moved: Array[String] = []
	for k in props0.keys():
		if not props1.has(k) or not (props1[k] as Transform3D).is_equal_approx(props0[k] as Transform3D):
			moved.append("%s %s → %s" % [k, str((props0[k] as Transform3D).origin), str((props1[k] as Transform3D).origin) if props1.has(k) else "?"])
	t.check(props0.size() >= 8 and moved.is_empty(), "la mesa, el monitor con su REC y las sillas quedan donde estaban antes de la sesión (%d cosas; movidas: %s)" % [props0.size(), "; ".join(moved)])
	var hint3 := (t.main.find_child("HUD", true, false) as Node).get("_hint") as Label
	t.check(hint3 != null and not hint3.has_meta("h2_top") and is_equal_approx(hint3.modulate.a, 1.0), "y el aviso del HUD vuelve a su sitio")
	if variant == "dificil":
		t.check(hub.qa.feedbacks_done() == 2 and hub.qa.kills() == 1, "Difícil: reapareces en la advertencia (hechos %d, muertes %d)" % [hub.qa.feedbacks_done(), hub.qa.kills()])
	if variant == "liviano":
		GfxQuality.apply(t.get_tree(), q0)
	Loc.language = lang0
	await t.back_to_menu()


## Dónde está cada cosa de la sala de calibración que alguien mueve (la sesión o el screamer): nombre → transform.
func _room_props(t: Node) -> Dictionary:
	var out: Dictionary = {}
	var fl := t.building().floor_node as Node
	if fl == null:
		return out
	for nm in ["MesaCalibracion", "MesaCalibracionPata", "MonitorQA", "RecPunto", "RecTexto", "LuzRec", "SillaAgente", "SillaAgenteResp", "SillaQA", "SillaQAResp", "Seat_calibracion"]:
		var n := fl.find_child(nm, true, false) as Node3D
		if n != null:
			out[nm] = n.transform
	var mon := fl.find_child("MonitorQA", true, false) as Node3D
	if mon != null:
		var i := 0
		for c in fl.get_children():
			if c is Label3D and c != mon and (c as Label3D).global_position.distance_to(mon.global_position) < 0.14 and not out.has(str(c.name)):
				out["rotulo%d" % i] = (c as Label3D).transform
				i += 1
	return out


# --- la escalera de luz ---------------------------------------------------------------------------------------------

func _light_ladder(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	# v0.3.2-final: esta escalera se mide con las luces del JUEGO (Baja): los umbrales de abajo salieron de ahí. Con
	# Media/Alta la mesa la alumbra el haz cerrado del paquete gráfico y «la luz de tu lado» se nota en tu lado de la
	# sala, no en la mesa: eso lo mide fin_haime_luces (grupo v032_fin) con sus propios criterios.
	var q0 := GfxQuality.level()
	GfxQuality.apply(t.get_tree(), "baja")
	await t.frames(4)
	var seq: Array = t.spy("death_sequence_started")
	var node := t.get_tree().get_first_node_in_group("p5_haime_actor")
	var base: float = node.call("room_light")
	var start: Array[float] = []
	var lowest: Array[float] = []
	var out: Array[String] = []
	for n in range(1, 5):
		PersonajesP5.set_counter("p5_qa_feedbacks", n - 1)
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		hub.qa.test_answers = ["ok", "ok", "ok", "ok"]
		var p5 := _p5()
		p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
		await t.frames(1)
		await t.set_clock(hub.qa.call_at + 1.0)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
		await p5.call("_go_calibration", t)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
		await t.frames(2)
		var l0: float = node.call("room_light")
		var low := l0
		var steps: Array[float] = [l0]
		var dead_seen := 0
		while hub.qa.state == QaFeedback.State.SESION and seq.is_empty():
			await t.frames(2)
			if hub.qa.state != QaFeedback.State.SESION or not seq.is_empty():
				break
			if float(node.get("_blackout_left")) > 0.0:
				continue  # los apagones de un parpadeo no cuentan como nivel de luz
			var l: float = node.call("room_light")
			low = minf(low, l)
			if int(node.get("lights_dead")) > dead_seen:
				dead_seen = int(node.get("lights_dead"))
				steps.append(l)
		start.append(l0)
		lowest.append(low)
		out.append("%d.ª: empieza %.2f, baja hasta %.2f, luces muertas %d %s" % [n, l0, low, dead_seen, str(steps) if n == 4 else ""])
		if n < 4:
			await t.frames(2)
			t.check(float(node.call("room_light")) >= base * 0.6, "%d.ª: al terminar la luz vuelve (%.2f de %.2f)" % [n, float(node.call("room_light")), base])
			await _back_to_desk(t)
		else:
			t.check(dead_seen >= 3 and steps.size() >= 4 and steps[1] <= steps[0] * 0.8 and steps[2] <= steps[1] * 0.8 and steps[3] <= 0.005, "4.ª: las luces mueren una por una y cada una se nota (afuera, la de tu lado y, al final, el tubo: %s)" % str(steps))
			t.check(_hook_light(node) <= 0.005 and bool(node.get("rec_only")), "4.ª: termina solo con el rojo del REC (luz blanca %.2f)" % _hook_light(node))
	t.note("LUZ (blanca que alumbra la sala; normal %.2f) · %s" % [base, " · ".join(out)])
	t.check(start[0] >= base * 0.75 and start[1] >= base * 0.75, "1.ª y 2.ª empiezan con la luz de siempre (%.2f y %.2f de %.2f)" % [start[0], start[1], base])
	t.check(start[2] <= start[1] * 0.7, "la advertencia empieza claramente más oscura que la 2.ª (%.2f frente a %.2f)" % [start[2], start[1]])
	t.check(start[3] <= start[2] * 0.85, "la fatal empieza más oscura que nunca (%.2f frente a %.2f de la advertencia)" % [start[3], start[2]])
	t.check(lowest[2] > 0.008, "la advertencia nunca llega a negro (%.3f): eso es de la fatal" % lowest[2])
	await t.wait_death_shown(20.0)
	GfxQuality.apply(t.get_tree(), q0)
	await t.back_to_menu()


func _hook_light(node: Node) -> float:
	return float(node.call("room_light")) if node != null and is_instance_valid(node) else -1.0


# --- la fatal: no te puedes levantar --------------------------------------------------------------------------------

func _fatal_seated(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var seq: Array = t.spy("death_sequence_started")
	var ended: Array = t.spy("qa_feedback_ended")
	hub.qa.test_answers = ["ok", "ok"]
	await _fatal_session(t, hub)
	t.check(await t.until(func() -> bool: return hub.qa.session_log.size() >= 2 and not t.player().input_locked, 40.0), "la fatal va por su 2.ª línea y tienes control")
	var log0 := hub.qa.session_log.size()
	var beats0 := hub.qa.beats_done.size()
	t.player().stand_up()
	await t.frames(3)
	t.check(t.player().seated and t.player().seat_id == "calibracion" and GameState.seated_at == "calibracion", "te paras… y vuelves a estar sentado en la silla de calibración")
	t.check(hub.qa.state == QaFeedback.State.SESION and hub.qa.stand_attempts == 1 and ended.is_empty() and hub.qa.last_session_end == "", "la sesión sigue (no es «te fuiste a mitad»; intentos %d)" % hub.qa.stand_attempts)
	t.check(Discipline.is_frozen() and GameState.clock_override == "feedback", "todo sigue congelado")
	var hint := (t.main.find_child("HUD", true, false) as Node).get("_hint") as Label
	t.check(hint != null and hint.modulate.a < 0.05, "el aviso «[E] Levantarse» ya no se muestra")
	t.check(await t.until(func() -> bool: return hub.qa.session_log.size() > log0 or hub.qa.beats_done.size() > beats0, 30.0), "Haime sigue con su guion")
	t.player().stand_up()
	await t.frames(3)
	t.check(t.player().seated and hub.qa.stand_attempts == 2 and hub.qa.state == QaFeedback.State.SESION, "otra vez: tampoco")
	var died: bool = await t.until(func() -> bool: return not seq.is_empty(), 200.0)
	t.check(died and str(seq[0][0]) == "calibracion_final" and t.player().seated, "y termina en calibracion_final, contigo sentado (%s)" % str(seq))
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.frames(3)
	t.check(hint != null and is_equal_approx(hint.modulate.a, 1.0), "al reaparecer el aviso del HUD vuelve")
	await t.back_to_menu()
	# En las demás (aquí la advertencia) pararse sigue siendo irse a mitad.
	hub = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_feedbacks", hub.qa.max_per_shift() - 2)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	await _fatal_session_n(t, hub)
	t.check(hub.qa.is_warning(hub.qa.n_call), "la advertencia (n %d)" % hub.qa.n_call)
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 2 and not t.player().input_locked, 40.0)
	t.player().stand_up()
	await t.frames(4)
	t.check(not t.player().seated and hub.qa.last_session_end == "a_mitad" and hub.qa.state == QaFeedback.State.LLAMADO, "en la advertencia te puedes ir a mitad (%s)" % hub.qa.last_session_end)
	var node := t.get_tree().get_first_node_in_group("p5_haime_actor")
	t.check(node != null and float(node.call("room_light")) > 0.25 and not bool(node.call("door_locked")), "y la sala vuelve a su luz, sin seguro (%.2f)" % float(node.call("room_light")))
	await t.back_to_menu()


## Como _fatal_session pero sin tocar el contador (la calibración que toque).
func _fatal_session_n(t: Node, hub: PersonajesP5) -> void:
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	await p5.call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)


# --- memoria de la partida ------------------------------------------------------------------------------------------

func _mem_file() -> Dictionary:
	var p := SaveSlots.dir_of(GameState.agent) + "haime_memoria.json"
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


func _memory(t: Node) -> void:
	# 1) Partida nueva en Difícil: la primera calibración de la partida es… la 1.ª; la 2.ª ya es la advertencia y solo
	#    tiene una calibración que recordar. Antes: sin memoria, la advertencia igual se arma (sin el beat «recuerdo»).
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.DIFICIL)
	_quiet_p5(hub)
	t.check(_mem_file().is_empty(), "partida nueva: sin memoria de Haime")
	PersonajesP5.set_counter("p5_qa_feedbacks", hub.qa.max_per_shift() - 2)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["tarde", "mal"]
	await _fatal_session_n(t, hub)
	t.check(hub.qa.is_warning(hub.qa.n_call) and not (hub.qa.session.get("firma", "") as String).contains("recuerdo"), "Difícil, primera vez que te sientas y ya es la advertencia: sin nada que recordar, no hay beat «recuerdo» (%s)" % str(hub.qa.session.get("firma", "")))
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0) and hub.qa.last_session_end == "dada", "y la sesión termina normal")
	var m := _mem_file()
	var h: Array = m.get("historial", [])
	t.check(h.size() == 1 and int((h[0] as Dictionary).get("mal", 0)) >= 1 and str((h[0] as Dictionary).get("fin", "")) == "dada" and not bool((h[0] as Dictionary).get("tarde", true)), "queda en la memoria: errores, respuestas malas, cómo terminó (%s)" % str(h))
	await _back_to_desk(t)
	await t.back_to_menu()
	# 2) Normal: llegas tarde (después del «Te estoy esperando»), le mientes por Ezlaki, te vas a mitad. La advertencia lo sabe.
	hub = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	await t.until(func() -> bool: return hub.qa.noshow_warned, 400.0)
	t.check(hub.qa.noshow_warned and hub.qa.state == QaFeedback.State.LLAMADO, "Haime ya avisó «Te estoy esperando» y todavía no llegas")
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await p5.call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0)
	m = _mem_file()
	t.check(int(m.get("tardanzas", 0)) == 1 and bool(((m.get("historial", []) as Array)[-1] as Dictionary).get("tarde", false)), "llegar tarde queda anotado (tardanzas %d)" % int(m.get("tardanzas", 0)))
	await _back_to_desk(t)
	# La mentira por Ezlaki: IABrain avisa (replied con el efecto «calibracion») y queda tu frase.
	var brain := t.get_tree().root.get_node_or_null("IABrain")
	t.check(brain != null and brain.has_signal("replied"), "hay IABrain con la señal replied")
	var lie_txt := "yo sí verifiqué todo antes de prometerle, no pasó nada"
	if brain != null:
		brain.emit_signal("replied", "haime", "dm:haime", {"efectos": ["calibracion"], "nlu": {"texto": lie_txt}, "quien": "haime"})
		brain.emit_signal("replied", "shero", "dm:shero", {"efectos": ["calibracion"], "nlu": {"texto": "esto no es para Haime"}, "quien": "shero"})
		brain.emit_signal("replied", "haime", "dm:haime", {"efectos": [], "nlu": {"texto": "voy para allá"}, "quien": "haime"})
	m = _mem_file()
	var lies: Array = m.get("mentiras_txt", [])
	t.check(lies.size() == 1 and str((lies[0] as Dictionary).get("t", "")) == lie_txt, "lo que le escribiste a Haime y no era cierto queda guardado tal cual (%s)" % str(lies))
	# 2.ª: te vas a mitad.
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	await _fatal_session_n(t, hub)
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 2 and not t.player().input_locked, 40.0)
	t.player().stand_up()
	await t.frames(4)
	t.check(hub.qa.last_session_end == "a_mitad", "2.ª: te vas a mitad")
	# Vuelves (cuenta como la 2.ª) y la terminas; la siguiente es la advertencia.
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await _p5().call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0)
	await _back_to_desk(t)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await _fatal_session_n(t, hub)
	t.check(hub.qa.is_warning(hub.qa.n_call), "la que sigue es la advertencia (n %d)" % hub.qa.n_call)
	var facts: Array = hub.qa.call("_memory_facts")
	t.check(facts.has("a_mitad") and facts.has("tarde_llegada") and facts.has("mentiste") and facts.has("repite_error") and facts.has("siempre"), "lo que recuerda: te fuiste a mitad, llegaste tarde, le mentiste, repites el error (%s)" % str(facts))
	t.check(await t.until(func() -> bool: return hub.qa.beats_done.has("recuerdo"), 120.0), "la advertencia tiene su beat «recuerdo»")
	await t.until(func() -> bool: return str(hub.qa.session_log).contains("h2_rec_"), 10.0)
	var said := ""
	for k in hub.qa.session_log:
		if str(k).begins_with("h2_rec_"):
			said = str(k)
	var si := ""
	for l in HaimeGuion.group("recuerdo"):
		if str((l as Dictionary).get("id", "")) == said:
			si = str((l as Dictionary).get("si", ""))
	t.check(said != "" and facts.has(si), "dice algo que de verdad pasó en esta partida (%s: «%s», %s)" % [said, HaimeVoz.text(said), si])
	var ui: FeedbackUI = hub.qa.ui
	t.check(ui != null and ui.history_rows.size() >= 3 and ui.history_rows == hub.qa.ui_history, "la pantalla muestra «TUS CALIBRACIONES» (%s)" % str(hub.qa.ui_history))
	var focus := ui.history_focus if ui != null else -2
	t.check(focus < ui.history_rows.size() and (focus >= 0 or si in ["siempre", "muchas", "baja"]), "y resalta la fila de la que habla (fila %d para «%s»)" % [focus, si])
	t.note("filas: %s · foco %d · hechos %s" % [str(hub.qa.ui_history), focus, str(facts)])
	# Las filas con el dato concreto: tu frase de Ezlaki y tus tardanzas.
	var rows_lie: Array = hub.qa.call("_history_rows", "mentiste")
	t.check(str(rows_lie[-1]).contains(lie_txt) and str(rows_lie[-1]).begins_with("EZLAKI"), "si habla de la mentira, la lista muestra tu frase (%s)" % str(rows_lie[-1]))
	var rows_late: Array = hub.qa.call("_history_rows", "tarde_llegada")
	t.check(str(rows_late[-1]).contains("1"), "si habla de tus tardanzas, cuántas fueron (%s)" % str(rows_late[-1]))
	t.check(str(hub.qa.ui_history).contains(Loc.pick({"es": "tarde", "en": "late"})) and str(hub.qa.ui_history).contains(Loc.pick({"es": "te fuiste", "en": "you walked out"})), "las filas dicen cuál llegaste tarde y de cuál te fuiste")
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0)
	await _back_to_desk(t)
	# 3) La mentira de ESTE turno (castigo de IABrain > 0): el beat «mentira» pone tu frase en pantalla.
	var shift0: Variant = null
	if brain != null and brain.get("shift") is Dictionary:
		shift0 = int((brain.get("shift") as Dictionary).get("calibracion", 0))
		(brain.get("shift") as Dictionary)["calibracion"] = 1
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await _fatal_session_n(t, hub)
	if await t.until(func() -> bool: return hub.qa.beats_done.has("mentira"), 120.0):
		await t.frames(2)
		t.check(hub.qa.ui != null and hub.qa.ui.lie_quote.contains(lie_txt), "«MENTISTE EN EZLAKI» con tu frase en pantalla (%s)" % (hub.qa.ui.lie_quote if hub.qa.ui != null else ""))
	else:
		t.fail("no hubo beat «mentira» con castigo de IABrain")
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0)
	if shift0 != null and brain != null and is_instance_valid(brain):
		(brain.get("shift") as Dictionary)["calibracion"] = int(shift0)
	await _back_to_desk(t)
	await t.back_to_menu()


# --- diez advertencias seguidas -------------------------------------------------------------------------------------

func _warnings(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lang0 := Loc.language
	for lang in ["es", "en"]:
		Loc.language = lang
		var mem: Dictionary = {"historial": [{"n": 1, "hora": "00:47", "tipo": "llamada", "marcas": ["respuesta_vaga"], "puntaje": 66, "mal": 1, "bien": 1, "fin": "dada"}], "sesiones": 1}
		var prev := ""
		var prev_ids: Dictionary = {}
		var same := 0
		var sigs: Dictionary = {}
		var jmax := 0.0
		var orders: Dictionary = {}
		for i in 10:
			var tipo := TIPOS[i % TIPOS.size()]
			var e := _entry(tipo, i)
			var s := HaimeGuion.build_session(e, 3, false, true, rng, mem, 4, {"recuerdos": ["siempre", "tardaste", "repite_error"]})
			HaimeGuion.remember_session(mem, s)
			var sig := str(s["firma"])
			if sig == prev:
				same += 1
			sigs[sig] = true
			var ids: Dictionary = {}
			for id in s["lineas"]:
				if not (str(id) in ["advertencia", "advertencia_cierre"] or str(id).begins_with("q4_")):
					ids[id] = true
			if not prev_ids.is_empty():
				jmax = maxf(jmax, _jaccard(ids, prev_ids))
			prev = sig
			prev_ids = ids
			# El orden del cuerpo (lo que va entre el primer error y «detrás de ti»).
			var parts := sig.split("-")
			orders["-".join(parts.slice(3, mini(parts.size(), 7)))] = true
			t.check(float(s["min_s"]) >= 45.0 and float(s["max_s"]) <= 60.0 and sig.contains("detras") and sig.contains("auricular") and sig.ends_with("cierre-fin"), "advertencia %d (%s): 45-60 s y termina detrás de ti, el auricular, tu número (%s, %.1f-%.1f s)" % [i + 1, lang, sig, float(s["min_s"]), float(s["max_s"])])
		t.note("ADVERTENCIAS %s: %d estructuras distintas de 10 · %d cuerpos distintos · Jaccard máx entre seguidas %.2f" % [lang, sigs.size(), orders.size(), jmax])
		t.check(same == 0 and sigs.size() >= 8, "%s: diez advertencias seguidas, ninguna estructura repetida dos veces seguidas (%d distintas)" % [lang, sigs.size()])
		t.check(jmax <= 0.5, "%s: entre dos advertencias seguidas, menos de la mitad de las líneas en común (%.2f)" % [lang, jmax])
	Loc.language = lang0
	await t.back_to_menu()


# --- en el juego: con un contacto en curso, perseguido, al salir al menú, en pausa ----------------------------------

func _on_call(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var cm := t.main.get("contacts") as ContactManager
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var called: Array = t.spy("qa_feedback_called")
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	# Te entra otra llamada antes de que Haime llame: mientras dure, espera.
	cm.current = {"id": "t1c2", "canal": "llamada"}
	cm.phase = ContactManager.Phase.ACTIVE
	t.check(hub.in_contact(), "hay un contacto en curso")
	await t.set_clock(hub.qa.call_at + 1.0)
	for i in 30:
		await t.advance_clock(20.0)
	t.check(called.is_empty() and hub.qa.state == QaFeedback.State.PENDIENTE, "con un contacto en curso Haime no llama (10 min de juego después: estado %d)" % hub.qa.state)
	cm.phase = ContactManager.Phase.IDLE
	cm.current = {}
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0) and called.size() == 1, "al terminar el contacto, llama")
	await t.back_to_menu()


func _chased(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var called: Array = t.spy("qa_feedback_called")
	var seq: Array = t.spy("death_sequence_started")
	_p5().call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	# Un cazador lento que viene de lejos (no alcanza a llegar en la prueba).
	var started := Pursuit.start("shero", "abandono", 0.05, null, "", 9, Vector3.INF, Callable(), {"asesino": "shero"})
	t.check(started and hub.qa.hunted(), "te persiguen")
	await t.set_clock(hub.qa.call_at + 1.0)
	for i in 20:
		await t.advance_clock(20.0)
	t.check(called.is_empty() and hub.qa.state == QaFeedback.State.PENDIENTE, "mientras te persiguen Haime no llama (estado %d)" % hub.qa.state)
	Pursuit.stop("shero", "prueba")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0) and called.size() == 1, "cuando la persecución termina, llama")
	# Ya llamado y te empiezan a perseguir: su plazo no corre (no mueres de inasistencia por estar corriendo).
	await t.advance_clock(60.0)
	var left0: float = hub.qa.seconds_left()
	Pursuit.start("shero", "abandono", 0.05, null, "", 9, Vector3.INF, Callable(), {"asesino": "shero"})
	for i in 40:
		await t.advance_clock(20.0)  # 13 min de juego: más que todo el plazo
	var left1: float = hub.qa.seconds_left()
	t.check(seq.is_empty() and hub.qa.state == QaFeedback.State.LLAMADO and absf(left1 - left0) < 45.0, "perseguido, el plazo de Haime no corre (%.0f s → %.0f s) y no hay inasistencia" % [left0, left1])
	# Llegas a la sala con el cazador todavía encima: la sesión congela la caza y se da entera.
	hub.qa.test_answers = ["ok", "ok", "ok"]
	await _p5().call("_go_calibration", t)
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0), "te sientas: empieza la sesión")
	t.check(Discipline.is_frozen() and Pursuit.is_hunting("shero"), "la caza queda congelada mientras dura")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 200.0) and hub.qa.last_session_end == "dada" and seq.is_empty(), "la sesión se da entera, sin muerte (%s, %s)" % [hub.qa.last_session_end, str(seq)])
	Pursuit.stop("shero", "prueba")
	await _back_to_desk(t)
	await t.back_to_menu()


func _menu_mid(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	var hint := (t.main.find_child("HUD", true, false) as Node).get("_hint") as Label
	var top0 := hint.offset_top
	var amb := AudioServer.get_bus_index("Ambiente")
	var amb0 := AudioServer.get_bus_volume_db(amb)
	PersonajesP5.set_counter("p5_qa_feedbacks", hub.qa.max_per_shift() - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	# Como en el juego: el contacto que termina deja checkpoint (con el contacto malo ya pendiente de Haime).
	Checkpoints.save_checkpoint("contacto")
	t.check(not (Checkpoints.last_checkpoint.get("discipline", {}) as Dictionary).is_empty() or not Checkpoints.last_checkpoint.is_empty(), "hay checkpoint tras el contacto malo")
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	await p5.call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	t.check(hub.qa.is_fatal(hub.qa.n_call), "estás en la fatal")
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 3, 60.0)
	await t.seconds(2.0)
	t.check(AudioServer.get_bus_volume_db(amb) < amb0 - 3.0 and hint.offset_top > top0 + 50.0 and Discipline.is_frozen(), "en plena fatal: ambiente bajo (%.1f dB), aviso del HUD al pie, todo congelado" % AudioServer.get_bus_volume_db(amb))
	await t.back_to_menu()
	await t.frames(3)
	t.check(is_equal_approx(hint.offset_top, top0) and is_equal_approx(hint.modulate.a, 1.0), "al salir al menú el aviso del HUD vuelve a su sitio (%.0f)" % hint.offset_top)
	t.check(absf(AudioServer.get_bus_volume_db(amb) - amb0) < 0.5, "el ambiente recupera su volumen (%.1f dB)" % AudioServer.get_bus_volume_db(amb))
	t.check(not Discipline.is_frozen() and GameState.clock_override == "", "nada queda congelado ni con el reloj de la sesión (%s, «%s»)" % [str(Discipline.freeze_reasons()), GameState.clock_override])
	t.check(t.get_tree().root.find_children("FeedbackUI", "", true, false).is_empty(), "sin pantalla de calibración colgando")
	var cur: Variant = VoiceDirector.current
	t.check(cur == null or str(cur.speaker) != "haime", "Haime no sigue hablando en el menú")
	# Continuar la partida: el contacto sigue pendiente y Haime vuelve a llamar por él (salir no te salva).
	t.main.call("_continue_shift")
	await t.frames(8)
	var hub2: PersonajesP5 = PersonajesP5.get_hub(t.get_tree())
	if hub2 == null:
		t.building().go_to_floor(2, "pc")
		await t.frames(6)
		hub2 = PersonajesP5.get_hub(t.get_tree())
	t.check(hub2 != null and hub2 != hub and hub2.qa.state == QaFeedback.State.PENDIENTE and hub2.qa.pending().size() == 1, "al continuar, el contacto malo sigue pendiente y la llamada está programada (estado %d, pendientes %d)" % [hub2.qa.state if hub2 != null else -1, hub2.qa.pending().size() if hub2 != null else -1])
	if hub2 != null:
		_quiet_p5(hub2)
		_p5().call("_quiet", t)
		var cm := t.main.get("contacts") as Node
		if cm != null:
			cm.process_mode = Node.PROCESS_MODE_DISABLED
		GameState.stop_calm()
		if not GameState.logged_in:
			await t.login_at_seat()
		await t.set_clock(maxf(hub2.qa.call_at, GameState.clock_seconds) + 1.0)
		# (La gracia tras reaparecer son 60 s reales y «Reconectando» 5 s más: con la máquina cargada 90 s quedaban justos.)
		var called2: bool = await t.until(func() -> bool: return hub2.qa.state == QaFeedback.State.LLAMADO, 240.0)
		t.check(called2 and hub2.qa.is_fatal(hub2.qa.n_call), "y cuando llama, es otra vez la fatal (n %d, estado %d; reloj %.0f, llama a %.0f; trainer %s, lunch %s, cazado %s, puede %s, gracia %s, reconectando %s, ocupado «%s», sentado «%s», login %s)" % [hub2.qa.n_call, hub2.qa.state, GameState.clock_seconds, hub2.qa.call_at, str(hub2.qa.trainer_busy()), str(hub2.qa.lunch_immune()), str(hub2.qa.hunted()), str(hub2.can_interrupt()), str(Checkpoints.in_respawn_grace()), str(Metrics.reconnecting), hub2.busy, GameState.seated_at, str(GameState.logged_in)])
	await t.back_to_menu()


## Nadie más habla durante una calibración. Caso visto en un video: lo que tu agente piensa al sentarse en C-14 (el eco
## de la polaroid, prioridad AMBIENTE, espera su turno hasta 8 s) quedó en cola detrás del llamado de los parlantes;
## al sentarte con Haime el llamado se corta, el eco empezaba, se cortaba… y su subtítulo se quedaba en el HUD debajo de
## las frases de Haime varios segundos.
func _foreign_voice(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	var sub := (t.main.find_child("HUD", true, false) as Node).get("_sub") as Label
	# En cola desde antes de sentarte (detrás del llamado de los parlantes, o sola si ya terminó).
	var queued: Variant = VoiceDirector.say("h2_prueba_cola", VoiceDirector.P.AMBIENTE, "piensa", Callable(), {"text": "(Jiroshi) prueba: esto lo pensaba antes de sentarme", "bus": "UI", "max_wait": 8.0})
	await p5.call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 1, 30.0)
	await t.frames(2)
	t.check(queued != null and bool(queued.done) and str(queued.result) != "dicha", "la voz que esperaba en cola no llega a decirse en la sesión (%s)" % (str(queued.result) if queued != null else "?"))
	t.check(sub != null and not sub.text.contains("prueba"), "y su subtítulo no queda en el HUD («%s»)" % (sub.text if sub != null else "?"))
	# Otra llega a mitad de la sesión, con la misma prioridad que Haime (espera su turno: entra en el primer silencio).
	var mid: Variant = VoiceDirector.say("h2_prueba_mitad", VoiceDirector.P.DIRECTO, "shero", Callable(), {"text": "[Shero] prueba: te hablo en plena calibración", "max_wait": 30.0})
	var n0: int = hub.qa.session_log.size()
	var shown := false
	var w := 0.0
	while hub.qa.state == QaFeedback.State.SESION and hub.qa.session_log.size() < n0 + 3 and w < 60.0:
		await t.frames(1)
		w += t.get_process_delta_time()
		shown = shown or (sub != null and sub.text.contains("prueba"))
	t.check(mid != null and bool(mid.done) and str(mid.result) != "dicha" and hub.qa.silenced.has("h2_prueba_mitad"), "la voz ajena que llega a mitad se corta al empezar (%s; cortadas %s)" % [str(mid.result) if mid != null else "?", str(hub.qa.silenced)])
	t.check(not shown, "su subtítulo no llega a verse en el HUD")
	await t.until(func() -> bool: return hub.qa.state != QaFeedback.State.SESION, 120.0)
	var pc: Dictionary = hub.qa.pacing()
	t.check(hub.qa.lost.is_empty() and hub.qa.last_session_end == "dada", "la sesión se da entera, sin líneas de Haime vencidas (%s, fin %s)" % [str(hub.qa.lost), hub.qa.last_session_end])
	t.check(float(pc["hueco"]) <= 1.6, "y Haime no esperó detrás de nadie: ningún hueco > 1,6 s (%.2f s a los %.1f s)" % [float(pc["hueco"]), float(pc["hueco_en"])])
	await t.back_to_menu()


## El llamado en cola (visto por el paquete del núcleo en h2_ritmo): Haime llama mientras suena otra voz importante (un
## cliente), su llamado por los parlantes espera en la cola del VoiceDirector, y el jugador llega y se sienta antes de
## que suene. Antes solo se cortaba si era la línea que sonaba: en cola, arrancaba después y tapaba 8-11 s de la sesión.
func _queued_summons(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	var p5 := _p5()
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	var scale0 := Engine.time_scale
	Engine.time_scale = 1.0  # a 1x de verdad: la voz manda
	VoiceDirector.reset_audit()
	# Un cliente habla (7,8 s) y en ese momento Haime llama.
	var cust: Variant = VoiceDirector.say("voces/clientes/t1c10_inicio", VoiceDirector.P.CLIENTE, "clientes", Callable(), {"text": "[Cliente] prueba: sigo hablando"})
	await t.frames(2)
	t.check(VoiceDirector.current == cust and bool(cust.has_audio), "suena la voz de un cliente")
	hub.qa.call_now()
	await t.frames(3)
	var pa: Variant = null
	for q in VoiceDirector.queue:
		if str(q.speaker) == "haime" and str(q.id).contains("pa_llamado"):
			pa = q
	t.check(hub.qa.state == QaFeedback.State.LLAMADO and pa != null and VoiceDirector.current == cust, "Haime llama y su llamado por los parlantes queda en cola detrás del cliente")
	# Llegas antes de que suene.
	await p5.call("_go_calibration", t)
	var started: bool = await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	await t.frames(2)
	var still := false
	for q in VoiceDirector.queue:
		still = still or (str(q.speaker) == "haime" and str(q.id).contains("pa_llamado"))
	t.check(started and pa != null and bool(pa.done) and int(pa.started_ms) < 0 and not still, "al sentarte el llamado sale de la cola sin haber sonado (resultado %s)" % (str(pa.result) if pa != null else "?"))
	# La sesión: el llamado no suena nunca, y la primera frase de Haime entra en cuanto el cliente termina.
	var pa_played := false
	var w := 0.0
	while hub.qa.state == QaFeedback.State.SESION and hub.qa.session_log.size() < 3 and w < 40.0:
		await t.frames(1)
		w += t.get_process_delta_time()
		var cur: Variant = VoiceDirector.current
		pa_played = pa_played or (cur != null and str(cur.id).contains("pa_llamado"))
	Engine.time_scale = scale0
	var first_at := -1.0
	for e in hub.qa.timeline:
		if str(e[2]) == "voz" and first_at < 0.0:
			first_at = float(e[0])
	t.check(not pa_played and hub.qa.session_log.size() >= 3, "el llamado no suena en la sesión (%d líneas de Haime dichas en %.1f s)" % [hub.qa.session_log.size(), w])
	t.check(first_at >= 0.0 and first_at <= 9.5 and hub.qa.lost.is_empty(), "su primera frase entra en cuanto el cliente termina (a los %.1f s de sentarte; vencidas %s)" % [first_at, str(hub.qa.lost)])
	t.check(VoiceDirector.overlaps == 0, "0 solapes de voz (%d)" % VoiceDirector.overlaps)
	await t.back_to_menu()


## De a uno (regla del núcleo: con un llamado pendiente o una sesión de otro, nadie más te convoca). Todo llamado de
## Haime pasa por hub.can_interrupt(): mientras otro te tiene ocupado espera, aunque su hora ya haya pasado, y el plazo
## para llegar (8 min de juego) cuenta desde que el llamado sale de verdad.
func _one_at_a_time(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	var called: Array = t.spy("qa_feedback_called")
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE, "contacto malo: la llamada queda programada")
	var due: float = hub.qa.call_at
	hub.busy = "prueba"  # otro personaje te tiene (una sesión, el evento): can_interrupt() dice que no
	await t.set_clock(due + 1.0)
	for i in 30:
		await t.advance_clock(20.0)  # 10 min de juego después de su hora
	t.check(not hub.can_interrupt(false, "haime") and called.is_empty() and hub.qa.state == QaFeedback.State.PENDIENTE, "con otro ocupándote Haime espera aunque su hora ya pasó (estado %d, %.0f min tarde)" % [hub.qa.state, (GameState.clock_seconds - due) / 60.0])
	var free_at := GameState.clock_seconds
	hub.busy = ""
	var ok: bool = await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	t.check(ok and called.size() == 1, "al quedar libre, llama")
	var full: float = PersonajesP5.plazo(float((DataLoader.dict("qa_haime") as Dictionary).get("margen_llegada_min", 8.0)))
	t.check(hub.qa.called_at >= free_at - 1.0 and hub.qa.seconds_left() >= full - 30.0, "y el plazo empieza cuando el llamado sale, no cuando tocaba (quedan %.0f s de %.0f; salió %.0f s después de su hora)" % [hub.qa.seconds_left(), full, hub.qa.called_at - due])
	await t.back_to_menu()


func _pause_fatal(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	_quiet_p5(hub)
	_hook = {}
	EventBus.death_sequence_started.connect(_on_death_hook)
	hub.qa.test_answers = ["ok", "ok"]
	await _fatal_session(t, hub)
	var node0 := t.get_tree().get_first_node_in_group("p5_haime_actor")
	# (Con «Apaga la luz. No. Yo la apago.» primero lo dice y después se apaga: se espera al apagón.)
	t.check(await t.until(func() -> bool: return hub.qa.beat_now == "certeza" and node0 != null and bool(node0.get("rec_only")) and float(node0.get("_blackout_left")) <= 0.0, 200.0), "llega el último tramo (solo queda el REC)")
	await t.frames(3)
	var pm: Control = t.main.get("pause_menu")
	pm.call("toggle")
	await t.frames(2)
	var clock0: float = hub.qa.clock
	var log0 := hub.qa.session_log.size()
	await t.seconds(4.0)
	t.check(t.get_tree().paused and _hook.is_empty() and absf(hub.qa.clock - clock0) < 0.05 and hub.qa.session_log.size() == log0, "en pausa la fatal no avanza ni mata (reloj %.2f → %.2f)" % [clock0, hub.qa.clock])
	var node := t.get_tree().get_first_node_in_group("p5_haime_actor")
	t.check(node != null and bool(node.get("rec_only")) and float(node.call("room_light")) <= 0.005, "y la sala sigue a oscuras con el REC")
	pm.call("toggle")
	await t.frames(2)
	var died: bool = await t.until(func() -> bool: return not _hook.is_empty(), 60.0)
	EventBus.death_sequence_started.disconnect(_on_death_hook)
	t.check(died and str(_hook.get("cause", "")) == "calibracion_final" and bool(_hook.get("seated", false)) and bool(_hook.get("braced", false)) and bool(_hook.get("visible", false)) and float(_hook.get("light", 1.0)) <= 0.005, "al volver de la pausa mata igual, con el mismo contrato (%s)" % str(_hook))
	await t.wait_death_shown(20.0)
	await t.back_to_menu()

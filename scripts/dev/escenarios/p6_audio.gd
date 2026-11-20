## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P6a · audio (PLAN §10 P6, #6/#51): el escáner `p6_audio` revisa que TODO audio que pida el
## código o los datos exista (y que cada línea de diálogo tenga ES y EN), con la misma regla que
## tools/p6_audio_scan.py. Excepciones EN explícitas en EXCEPCIONES_EN (gritos, risas y golpes sin palabras;
## el ronquido de Juan). Además: idioma ES/EN, variante que coincide con el subtítulo, variantes al azar,
## polifonía (el efecto no corta la voz), sin "[audio pendiente]", ganancias del índice, música de Rasec en
## bucle, pasos por superficie y bucle de carrera de Shero.

const EXCEPCIONES_EN: Array[String] = [
	"voces/trainer/trainer_gaaaa", "voces/trainer/trainer_gaaaa_01", "voces/trainer/trainer_gaaaa_02",
	"voces/trainer/trainer_gaaaa_03", "voces/trainer/trainer_gaaaa_04", "voces/trainer/trainer_risa",
	"voces/trainer/trainer_golpe", "voces/trainer/trainer_muerte_01", "voces/trainer/trainer_muerte_02",
	"voces/grasa/grasa_grito_corto",
]
const DATA_KEYS: Array[String] = ["voz", "voz_respaldo", "slot", "slot_respaldo", "musica", "audio"]
## _say(key) dinámicos de P5 → todas las claves de su archivo de líneas.
const DYN: Dictionary = {
	"scripts/personajes/training_control.gd": ["lineas_trainer", "", "trainer", ""],
	"scripts/personajes/rasec_control.gd": ["lineas_rasec", "", "rasec", ""],
	"scripts/personajes/rasec.gd": ["lineas_rasec", "", "rasec", ""],
	"scripts/personajes/qa_feedback.gd": ["lineas_haime", "", "haime", ""],
	"scripts/personajes/guardia.gd": ["lineas_neutrales", "fermin", "otros", "fermin_"],
	"scripts/personajes/topico_control.gd": ["lineas_neutrales", "enfermero", "otros", "enfermero_"],
}
## v0.3.1: las líneas nuevas de Haime (F4/F6/F9 y las variantes por caso _correo/_kyc/_chat), la del Trainer (F4) y
## la cama del feedback (F6) ya las entregó Q3: se comprueban como cualquier otro slot.
const VARIANTES_CASO: Array[String] = ["_correo", "_kyc", "_chat"]


## fb1_replay_correo → fb1_replay (la variante por caso se dice, o no, igual que su línea base).
static func _base_key(k: String) -> String:
	for v in VARIANTES_CASO:
		if k.ends_with(v):
			return k.trim_suffix(v)
	return k


## Claves de líneas que no se dicen en voz (canal de Ezlaki, pantalla o configuración).
const NO_VOZ: Dictionary = {
	"lineas_trainer": ["dictar", "asomarse", "charla", "grito", "anuncio", "llamado", "siluetas"],
	"lineas_rasec": ["musica_pa", "evento_anuncio", "evento_dm", "actividad_karaoke", "actividad_charadas", "actividad_sillas",
		"relleno_2", "relleno_4", "relleno_6"],  # relleno par = acotación «[…]» en la pantalla del evento
	"lineas_haime": ["noshow_canal", "fb1_replay", "fb2_replay", "fb3_replay", "rec_canal",
		"noshow", "llamado_1", "llamado_2", "llamado_3", "llamado_final", "llamado_1_correo", "llamado_2_correo", "llamado_3_correo", "llamado_1_kyc", "llamado_2_kyc", "llamado_3_kyc", "llamado_1_chat", "llamado_2_chat"],
}


func escenarios() -> Array[String]:
	return ["p6_audio", "p6_audio_idioma", "p6_audio_variante_texto", "p6_audio_variantes", "p6_audio_polifonia", "p6_audio_sin_pendiente", "p6_audio_sonoridad", "p6_audio_musica_rasec", "p6_audio_pasos", "p6_audio_carrera", "p6_audio_ui_colapso", "p6_audio_bucle_suelto", "p6_audio_cosechados"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p6_audio": await _scan(t)
		"p6_audio_idioma": await _idioma(t)
		"p6_audio_variante_texto": await _variante_texto(t)
		"p6_audio_variantes": await _variantes(t)
		"p6_audio_polifonia": await _polifonia(t)
		"p6_audio_sin_pendiente": await _sin_pendiente(t)
		"p6_audio_sonoridad": await _sonoridad(t)
		"p6_audio_musica_rasec": await _musica_rasec(t)
		"p6_audio_pasos": await _pasos(t)
		"p6_audio_carrera": await _carrera(t)
		"p6_audio_ui_colapso": await _ui_colapso(t)
		"p6_audio_bucle_suelto": await _bucle_suelto(t)
		"p6_audio_cosechados": await _cosechados(t)


# --- escáner ---------------------------------------------------------------------------------------

## {slot: [referencias]} de todo lo que piden el código y los datos.
static func requested_slots() -> Dictionary:
	var out := {}
	var rx := [
		[RegEx.create_from_string('play_sfx(?:\\.bind)?\\(\\s*"([^"]+)"'), "sfx/%s"],
		[RegEx.create_from_string('play_voice\\(\\s*"([^"]+)"\\s*,\\s*"([^"%]+)"'), "voces/%s/%s"],
		[RegEx.create_from_string('play_ambient\\(\\s*"([^"]+)"'), "ambiente/%s"],
		[RegEx.create_from_string('play_music\\(\\s*"([^"]+)"'), "musica/%s"],
		[RegEx.create_from_string('play_loop\\(\\s*"([^"]+)"'), "%s"],
		[RegEx.create_from_string('(?:resolve|has_slot|stream_for)\\(\\s*"((?:sfx|ambiente|musica|voces)/[^"%]+)"'), "%s"],
		[RegEx.create_from_string('\\b_sfx\\(\\s*"([^"]+)"'), "sfx/%s"],
		[RegEx.create_from_string('say\\(\\s*[^,\\n]+,\\s*"([a-z_]+)"\\s*,\\s*"([a-z0-9_]+)"'), "voces/%s/%s"],
		[RegEx.create_from_string('PersonajesP5\\.pa\\([^\\n]*?,\\s*"([a-z_]+)"\\s*,\\s*"([a-z0-9_]+)"\\)'), "voces/%s/%s"],
	]
	for path in _gd_files("res://scripts"):
		if path.begins_with("res://scripts/dev/"):
			continue
		var txt := FileAccess.get_file_as_string(path)
		var rel := path.trim_prefix("res://")
		for pair in rx:
			for m in (pair[0] as RegEx).search_all(txt):
				var slot := ""
				if m.get_group_count() >= 2 and m.get_string(2) != "":
					slot = str(pair[1]) % [m.get_string(1), m.get_string(2)]
				else:
					slot = str(pair[1]) % m.get_string(1)
				if slot.ends_with("_"):
					continue  # prefijo de un id dinámico ("fermin_" + clave): lo cubre DYN
				_add(out, slot.trim_suffix(".ogg"), rel)
		if txt.contains('"trainer_gaaaa_%02d"'):
			for i in range(1, 5):
				_add(out, "voces/trainer/trainer_gaaaa_%02d" % i, rel)
		if txt.contains("cliente_la_que_llora_0%d"):
			for i in range(1, 5):
				_add(out, "voces/clientes/cliente_la_que_llora_%02d" % i, rel)
		if txt.contains("cliente_estafado_0%d"):
			for i in range(1, 4):
				_add(out, "voces/clientes/cliente_estafado_%02d" % i, rel)
		if DYN.has(rel):
			var cfg: Array = DYN[rel]
			var d: Dictionary = DataLoader.dict(str(cfg[0]))
			if str(cfg[1]) != "":
				d = d.get(str(cfg[1]), {})
			var skip: Array = NO_VOZ.get(str(cfg[0]), [])
			for k in d.keys():
				var v: Variant = d[k]
				if str(k).begins_with("_") or skip.has(str(k)) or skip.has(_base_key(str(k))):
					continue
				if v is Array or (v is Dictionary and ((v as Dictionary).has("es") or (v as Dictionary).has("lineas"))):
					_add(out, "voces/%s/%s%s" % [cfg[2], cfg[3], k], rel + " (_say)")
	# datos
	var dd := DirAccess.open("res://data")
	for f in dd.get_files():
		if not f.ends_with(".json"):
			continue
		var base := f.get_basename()
		var d2: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + f))
		if d2 == null or base == "audio_index":
			continue
		var folder := base.trim_prefix("lineas_") if base.begins_with("lineas_") else ""
		_walk_data(d2, out, base, folder, base.begins_with("contactos_"), "data/" + f)
	return out


static func _walk_data(o: Variant, out: Dictionary, base: String, folder: String, contact: bool, ref: String) -> void:
	if o is Dictionary:
		# Mensajes de escalera (lineas_shero.json/escalera, P3): la voz es de su "autor" (voces/rasec/… para Rasec) y
		# solo suena en los canales hablados (voz, pa, rooms); un DM o un post de canal es texto (sin voz).
		var mfolder := folder
		var text_only := false
		if (o as Dictionary).has("canal") and (o as Dictionary).has("voz"):
			mfolder = str((o as Dictionary).get("autor", folder))
			text_only = not (str(o["canal"]) in ["voz", "pa", "rooms"])
		for k in (o as Dictionary).keys():
			var v: Variant = o[k]
			if text_only and str(k) in ["voz", "voz_respaldo"]:
				continue
			if v is String and DATA_KEYS.has(str(k)) and str(v) != "":
				var s := str(v).trim_suffix(".ogg").trim_suffix(".wav")
				if contact and str(k) == "audio" and not s.begins_with("voces/"):
					s = "voces/clientes/" + s
				elif not s.contains("/"):
					if mfolder != "" and str(k) in ["voz", "voz_respaldo"]:
						s = "voces/%s/%s" % [mfolder, s]
					elif str(k) in ["musica", "slot", "slot_respaldo"]:
						s = "musica/" + s
					else:
						continue
				elif not (s.get_slice("/", 0) in ["sfx", "ambiente", "musica", "voces"]):
					s = "voces/" + s
				_add(out, s, ref + ":" + str(k))
			else:
				_walk_data(v, out, base, folder, contact, ref)
	elif o is Array:
		for v in o:
			_walk_data(v, out, base, folder, contact, ref)


static func _add(out: Dictionary, slot: String, ref: String) -> void:
	if not out.has(slot):
		out[slot] = []
	if not (out[slot] as Array).has(ref):
		(out[slot] as Array).append(ref)


static func _gd_files(dir: String) -> Array[String]:
	var res: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return res
	for f in d.get_files():
		if f.ends_with(".gd"):
			res.append(dir.path_join(f))
	for sub in d.get_directories():
		res.append_array(_gd_files(dir.path_join(sub)))
	return res


static func en_slot(slot: String) -> String:
	var p := slot.split("/")
	return "%s/%s/en/%s" % [p[0], p[1], "/".join(p.slice(2))]


## Existe el slot (o sus variantes _01.. que el AudioManager elige solo). Con fallback sfx → ambiente.
static func slot_exists(slot: String) -> bool:
	if AudioManager.has_slot(slot):
		return true
	if slot.begins_with("sfx/") and AudioManager.has_slot("ambiente/" + slot.trim_prefix("sfx/")):
		return true
	return false


func _scan(t: Node) -> void:
	var req := requested_slots()
	var missing: Array[String] = []
	var missing_en: Array[String] = []
	var voices := 0
	for slot in req.keys():
		var s := str(slot)
		if not slot_exists(s):
			missing.append("%s  (%s)" % [s, ", ".join(req[slot]).left(120)])
			continue
		if s.begins_with("voces/"):
			voices += 1
			if EXCEPCIONES_EN.has(s):
				continue
			if not AudioManager.has_slot(en_slot(s)):
				missing_en.append("%s  (%s)" % [s, ", ".join(req[slot]).left(120)])
	t.note("%d slots pedidos (código + datos) · %d voces · %d excepciones EN: %s" % [req.size(), voices, EXCEPCIONES_EN.size(), ", ".join(EXCEPCIONES_EN)])
	t.check(req.size() > 250, "el escáner encontró pocos slots (%d): ¿cambió el código?" % req.size())
	for m in missing:
		t.fail("falta audio: " + m)
	for m in missing_en:
		t.fail("falta la EN: " + m)
	t.check(missing.is_empty() and missing_en.is_empty(), "%d sin archivo, %d sin EN" % [missing.size(), missing_en.size()])
	# Los árboles de clientes: cada nodo con texto del cliente tiene audio ES y EN.
	var nodes := 0
	for f in ["contactos_t1", "contactos_t2", "contactos_t3"]:
		for c in DataLoader.dict(f).get("contactos", []):
			for part in ["nodos", "finales"]:
				for nk in (c as Dictionary).get(part, {}).keys():
					var n: Dictionary = c[part][nk]
					if n.has("audio"):
						nodes += 1
	t.check(nodes >= 150, "nodos de árbol con audio: %d" % nodes)


# --- idioma y variantes ---------------------------------------------------------------------------

func _idioma(t: Node) -> void:
	var prev := Loc.language
	Loc.language = "es"
	AudioManager.play_voice("haime", "llegaste", "")
	t.check(str(AudioManager.last_voice.get("path", "")).ends_with("voces/haime/llegaste.ogg"), "ES: " + str(AudioManager.last_voice))
	Loc.language = "en"
	AudioManager.play_voice("haime", "llegaste", "")
	t.check(str(AudioManager.last_voice.get("path", "")).ends_with("voces/haime/en/llegaste.ogg"), "EN: " + str(AudioManager.last_voice))
	# Clip cosechado en ES con su EN sintética (no pisa el de Joan)
	AudioManager.play_voice("shero", "shero_no_hay_breaks", "")
	t.check(str(AudioManager.last_voice.get("path", "")).contains("/shero/en/"), "EN del cosechado: " + str(AudioManager.last_voice))
	Loc.language = "es"
	AudioManager.play_voice("shero", "shero_no_hay_breaks", "No hay breaks.")
	t.check(str(AudioManager.last_voice.get("path", "")).ends_with("voces/shero/shero_no_hay_breaks.ogg"), "ES cosechado (con su texto): " + str(AudioManager.last_voice))
	Loc.language = prev
	AudioManager.stop_ambient()


func _variante_texto(t: Node) -> void:
	var prev := Loc.language
	Loc.language = "es"
	var rondas: Array = (DataLoader.dict("rasec_eventos").get("charadas", {}) as Dictionary).get("rondas", [])
	for i in rondas.size():
		var txt := Loc.fmt(Loc.pick((rondas[i] as Dictionary).get("si_bien", {})), {"agente": "Jiroshi"})
		var slot := AudioManager.voice_slot("rasec", "charada_bien", txt)
		var want := "voces/rasec/charada_bien" if i == 0 else "voces/rasec/charada_bien__%d" % (i + 1)
		t.check(slot == want, "ronda %d: '%s' → %s (quería %s)" % [i + 1, txt.left(40), slot, want])
	# Como PersonajesP5.say: voz sin texto y el subtítulo en el mismo fotograma → cambia a la variante correcta
	var t3 := Loc.fmt(Loc.pick((rondas[2] as Dictionary).get("si_bien", {})), {"agente": "Jiroshi"})
	PersonajesP5.say("Rasec", "rasec", "charada_bien", t3)
	t.check(str(AudioManager.last_voice.get("slot", "")) == "voces/rasec/charada_bien__3", "say() + subtítulo → variante 3: " + str(AudioManager.last_voice.get("slot", "")))
	Loc.language = "en"
	var en_txt := Loc.fmt(Loc.pick((rondas[2] as Dictionary).get("si_bien", {})), {"agente": "Jiroshi"})
	var en_slot := AudioManager.voice_slot("rasec", "charada_bien", en_txt)
	t.check(en_slot == "voces/rasec/charada_bien__3", "EN ronda 3 → " + en_slot)
	t.check(AudioManager.voice_path(en_slot).contains("/rasec/en/"), "EN usa la carpeta en/: " + AudioManager.voice_path(en_slot))
	Loc.language = prev
	t.check(AudioManager.text_score("¡Mamá! Feliz día", "Mamá. Feliz día a todas") > 0.5, "parecido de textos")


func _variantes(t: Node) -> void:
	var seen := {}
	for i in 40:
		seen[AudioManager.resolve("sfx/rta_ladrido")] = true
	t.check(seen.size() >= 2, "rta_ladrido varía entre el cosechado y las variantes: %s" % str(seen.keys()))
	t.check(AudioManager.has_slot("voces/trainer/trainer_gaaaa"), "trainer_gaaaa (sin número) → una de sus 4 variantes")
	t.check(AudioManager.has_slot("voces/otros/marleny_saludo"), "marleny_saludo → _01/_02")
	t.check(AudioManager.stream_for("ambiente/trueno_lejano") != null, "trueno lejano al azar")


func _polifonia(t: Node) -> void:
	AudioManager.play_voice("haime", "llegaste", "", "Sala")
	AudioManager.play_sfx("telefono_timbre", "Sala")
	AudioManager.play_sting()
	await t.frames(2)
	var voz := VoiceDirector.get("_player") as AudioStreamPlayer  # v0.3.2: las voces suenan por el VoiceDirector
	t.check(voz.playing, "la voz sigue sonando después de dos efectos en el mismo bus")
	var playing := 0
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer and str(c.name).begins_with("Sfx_Sala") and (c as AudioStreamPlayer).playing:
			playing += 1
	t.check(playing >= 2, "efectos simultáneos en Sala: %d" % playing)
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()


func _sin_pendiente(t: Node) -> void:
	var subs: Array = t.spy("subtitle")
	for s in ["telefono_timbre", "rta_ladrido", "lanyard_tintineo", "detector", "trainer_golpe", "respiracion", "pa_chime", "screamer_rasec", "screamer_guardia"]:
		AudioManager.play_sfx(s)
	for pair in [["otros", "scr_fermin"], ["rasec", "scr_evento"], ["haime", "pasillo"], ["clientes", "t3c8_inicio"], ["trainer", "trainer_gaaaa"]]:
		AudioManager.play_voice(pair[0], pair[1], "")
	await t.frames(2)
	var pend := 0
	for s in subs:
		if str(s[1]).contains("[") and str(s[0]) == "sys":
			pend += 1
	t.check(pend == 0, "ningún subtítulo de audio pendiente (%d)" % pend)
	var miss: Array = []
	for m in AudioManager.missing_requested():
		if (str(m).begins_with("sfx/") or str(m).begins_with("voces/")):
			miss.append(m)
	t.check(miss.is_empty(), "faltantes pedidos en la sesión: %s" % str(miss))
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()


func _sonoridad(t: Node) -> void:
	var idx: Dictionary = DataLoader.dict("audio_index")
	var gains: Dictionary = idx.get("gain_db", {})
	t.check(not gains.is_empty(), "audio_index.json con ganancias")
	t.check((idx.get("textos", {}) as Dictionary).size() > 400, "audio_index.json con textos: %d" % (idx.get("textos", {}) as Dictionary).size())
	var harvested := 0
	for k in gains.keys():
		if str(k).begins_with("voces/agentes/") or str(k).begins_with("voces/grasa/"):
			harvested += 1
		t.check(absf(float(gains[k])) <= 12.0, "ganancia razonable %s %.1f dB" % [k, float(gains[k])])
	t.note("%d ganancias (%d de clips cosechados, sin tocar los archivos)" % [gains.size(), harvested])
	VoiceDirector.stop_all()
	AudioManager.play_voice("agentes", "marko_dormido", "")
	var v := VoiceDirector.get("_player") as AudioStreamPlayer  # v0.3.2: VoiceDirector
	t.check(is_equal_approx(v.volume_db, AudioManager.gain_db("voces/agentes/marko_dormido")), "la ganancia se aplica (%.1f dB)" % v.volume_db)
	v.stop()


func _musica_rasec(t: Node) -> void:
	for m in ["rasec_madrugada", "rasec_karaoke", "rasec_charadas", "rasec_sillas"]:
		var st := AudioManager.stream_for("musica/" + m, true)
		t.check(st != null and st.get_length() > 15.0, "musica/%s existe y dura %.1f s" % [m, st.get_length() if st != null else 0.0])
		if st is AudioStreamOggVorbis:
			t.check((st as AudioStreamOggVorbis).loop, "musica/%s en bucle" % m)
	var lluvia := load(AudioManager.resolve("ambiente/lluvia")) as AudioStreamOggVorbis
	t.check(lluvia != null and lluvia.loop, "ambiente/lluvia importada en bucle (Weather la carga directo)")


func _pasos(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var b: Building = t.building()
	b.go_to_floor(2, "pc")
	await t.frames(4)
	var p: Player = t.player()
	var dir: Node = AudioManager.director
	t.check(dir != null, "AudioDirector creado")
	if dir == null or p == null:
		return
	EventBus.player_entered_zone.emit("sala")
	t.note("piso %d · activo %s · en el suelo %s · sentado %s · cinemática %s" % [GameState.current_floor, str(FloorBase.active.name) if FloorBase.active != null else "—", str(p.is_on_floor()), str(p.seated), str(p.cinematic)])
	var n0: int = dir.steps_played
	var start := p.global_position
	var step := 1.4 * Engine.time_scale / float(Engine.physics_ticks_per_second)  # 1,4 m/s de juego
	# P7: hacia el interior de la sala (−x) y como mucho 12 m: hacia +x atravesaba la pared este (x 48) y el
	# jugador caía fuera del edificio (3 «caída en (5x, -3, -9.9)» por pasada de `all`).
	step = minf(step, 12.0 / 90.0)
	for i in 90:
		p.global_position = start + Vector3(-step * i, 0, 0)
		await t.get_tree().physics_frame
	t.check(int(dir.steps_played) > n0, "suenan pasos al caminar (%d)" % (int(dir.steps_played) - n0))
	t.check(str(dir.last_surface) == "alfombra", "en la sala la superficie es alfombra: " + str(dir.last_surface))
	(dir.get("_zones") as Dictionary).clear()
	t.check(dir.call("surface") == "porcelanato", "fuera de la sala: porcelanato")


func _carrera(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var fl := t.building().floor_node as Node3D
	var fake := Node3D.new()
	fake.name = "Cazador_shero"
	fl.add_child(fake)
	EventBus.pursuit_started.emit("shero", "prueba")
	await t.frames(4)
	var a := fake.find_child("CarreraAudio", true, false) as AudioStreamPlayer3D
	var direct := fl.find_child("CarreraAudio", true, false) as AudioStreamPlayer3D
	t.check(a != null or direct != null, "bucle 3D de carrera colgado del cazador")
	EventBus.pursuit_ended.emit("shero", "prueba")
	await t.frames(3)
	t.check(fake.find_child("CarreraAudio", true, false) == null, "se quita al terminar la persecución")
	fake.queue_free()


## Auricular/PC (conecta, cuelga molesto, correo recibido/enviado, clic) y sonidos del colapso.
func _ui_colapso(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var am := AudioManager
	var seen: Array[String] = []
	am.sfx_history.clear()
	var rec := func() -> void:  # v0.3.1: el historial (con más tráfico de Ezlaki, last_sfx puede ser otro efecto)
		for sl in am.sfx_history:
			if not seen.has(sl):
				seen.append(sl)
	var call := {"id": "prueba_llamada", "canal": "llamada"}
	var mail := {"id": "prueba_correo", "canal": "correo"}
	EventBus.contact_accepted.emit(call)
	rec.call()
	EventBus.contact_outcome.emit(call, "molesto", 1)
	rec.call()
	EventBus.contact_offered.emit(mail)
	rec.call()
	EventBus.email_sent.emit("Vitzo", "prueba")
	rec.call()
	var b := Button.new()
	t.add_child(b)
	await t.frames(1)
	b.pressed.emit()
	await t.frames(2)
	rec.call()
	b.queue_free()
	for want in ["sfx/auricular_conecta", "sfx/auricular_cliente_cuelga", "sfx/correo_recibido", "sfx/correo_enviado", "sfx/ui_click_v2"]:
		t.check(want in seen, "suena " + want)
	t.check(am.missing_requested().is_empty() or not str(am.missing_requested()).contains("sfx/"), "ningún sfx pedido falta")
	var dir: Node = am.get_node("AudioDirector") if am.has_node("AudioDirector") else null
	if not t.check(dir != null, "AudioDirector presente"):
		return
	# v0.3.2: el colapso lo suena DeathAnimations a nivel de sala (pk2 `k2_colapso*` lo mide). El director ya no lanza
	# por AudioManager las tres señales a nivel pleno de la versión en primera persona (latido, acúfeno, caída).
	t.player().seated = false
	var old_cues: Array = []
	for slot in ["sfx/latido_lento", "sfx/acufeno", "sfx/caida_cuerpo"]:
		var st: AudioStream = am.stream_for(slot, false)
		if st != null:
			old_cues.append(st)
	EventBus.death_sequence_started.emit("colapso", "fatiga", "")
	var full_level := 0
	var w := 0.0
	while w < 2.0:
		await t.get_tree().process_frame
		w += t.get_process_delta_time()
		for ch in am.get_children():
			var ap := ch as AudioStreamPlayer
			if ap != null and ap.playing and ap.stream != null and old_cues.has(ap.stream):
				full_level += 1
	t.check(old_cues.size() == 3 and full_level == 0 and not ("collapse_sounds" in dir), "colapso: el director ya no lanza latido, acúfeno ni caída a nivel pleno (%d cuadros sonando)" % full_level)


## Un archivo que es bucle de ambiente y también golpe suelto (fluorescente_parpadeo del baño): cada uso con su copia.
func _bucle_suelto(t: Node) -> void:
	var am := AudioManager
	am.stop_ambient("fluorescente_parpadeo")
	am.play_ambient("fluorescente_parpadeo", -30.0)
	var amb := am.get("_ambient_players").get("ambiente/fluorescente_parpadeo") as AudioStreamPlayer
	if not t.check(amb != null and amb.stream is AudioStreamOggVorbis, "ambiente fluorescente_parpadeo suena"):
		return
	am.play_sfx("fluorescente_parpadeo")
	var b: String = am.last_sfx.get("bus", "Sala")
	var pool: Array = am.get("_sfx_pool")[b]
	var i: int = (int(am.get("_sfx_next")[b]) - 1 + pool.size()) % pool.size()
	var one := (pool[i] as AudioStreamPlayer).stream
	t.check(one is AudioStreamOggVorbis and not (one as AudioStreamOggVorbis).loop, "como golpe suelto no se repite")
	t.check((amb.stream as AudioStreamOggVorbis).loop, "el bucle de ambiente sigue en bucle")
	t.check(am.stream_for("ambiente/fluorescente_parpadeo", true) != am.stream_for("ambiente/fluorescente_parpadeo", false), "stream_for da una copia por modo")
	am.stop_ambient("fluorescente_parpadeo")
	(pool[i] as AudioStreamPlayer).stop()


## Clips cosechados de ambiente: compañero hablando con su cliente (3D desde su cubículo), inodoro al salir del baño,
## y la capa de Vitzo en su screamer.
func _cosechados(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()  # piso 2, sala
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	var dir: Node = AudioManager.get_node("AudioDirector")
	var fl := t.building().floor_node as Node3D
	var rig: CharacterRig = null
	for r in fl.find_children("*", "Node3D", true, false):
		if r is CharacterRig and (r as CharacterRig).model_name in ["agente_juan", "agente_marko"]:
			rig = r
			break
	if not t.check(rig != null, "hay un Juan o un Marko sentado en la sala"):
		return
	p.teleport(rig.global_position + Vector3(3.0, 0, 0), 90.0)
	await t.frames(3)
	VoiceDirector.stop_all()  # v0.3.2: un murmullo solo sale si no hay otra voz
	await t.frames(2)
	var a: AudioStreamPlayer3D = dir.murmur()
	var who: Node = a.get_parent() if a != null else null
	t.check(a != null and a.stream != null and a.playing and who is CharacterRig and (who as CharacterRig).model_name in ["agente_juan", "agente_marko"] \
		and (who as Node3D).global_position.distance_to(p.global_position) <= 12.0, "un compañero habla con su cliente desde su sitio (%s)" % [(who as CharacterRig).model_name if who is CharacterRig else "-"])
	p.teleport(rig.global_position + Vector3(30.0, 0, 0), 90.0)
	await t.frames(3)
	t.check(dir.murmur() == null, "a 30 m de la fila no suena ninguno")
	EventBus.player_entered_zone.emit("bano_p2")
	dir.get("_zone_in")["bano_p2"] = Time.get_ticks_msec() - 20000
	EventBus.player_exited_zone.emit("bano_p2")
	t.check(str(AudioManager.last_sfx.get("slot", "")) == "sfx/inodoro", "inodoro al salir del baño")
	var row := Screamers.row_for("vitzo", "correo_vitzo")
	t.check(str(row.get("capa", "")) == "voces/vitzo/vitzo_screamer_capa" and AudioManager.has_slot(str(row.get("capa", ""))), "screamer de Vitzo con la capa cosechada")

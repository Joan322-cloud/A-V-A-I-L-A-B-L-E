extends Node
## AudioManager: reproduce audio por "slot" desde res://assets/audio/ (GDD 8.6).
## Convención de carpetas (la del paquete de assets, documentada en docs/AUDIO_SLOTS.md):
##   sfx/<slot>.ogg|wav · ambiente/<slot>.ogg · musica/<slot>.ogg · voces/<slug>/<slot>.ogg
##   (voz en inglés: voces/<slug>/en/<slot>.ogg; si falta, suena la ES con subtítulo EN).
## Si falta el archivo: SILENCIO (v0.3.1 Q3, B8/C2: nada de pitidos sintéticos) y se anota en user://MISSING.txt
## (el subtítulo "[audio pendiente]" solo en builds de depuración). Al arrancar se revisan todos los slots.
##
## v0.3.1 (Q3): buses propios creados en tiempo de ejecución (sin tocar default_bus_layout.tres): «Musica» (capas de
## tensión, va al bus Ambiente), «Lluvia» (camas largas con filtro por contexto), «PasosL»/«PasosR» (pan ±0,15 y
## reverb por superficie) y «RasecDegrada» (la música alegre de Rasec que se desafina y se ensucia).
##
## v0.3 (P6a):
##  · Polifonía: cada bus tiene UN canal de voz (una línea nueva corta la anterior del mismo bus) y un grupo de
##    canales de efectos (antes un efecto cortaba la voz y el golpe del screamer cortaba el stinger).
##  · Variantes: si falta <slot> pero hay <slot>_01.._NN (o hay <slot> y <slot>_02..), se elige una al azar
##    sin repetir la anterior (trainer_gaaaa, marleny_saludo, rta_ladrido, trueno_lejano…).
##  · Voces: con el subtítulo, se elige la variante cuyo texto coincide (<id>, <id>__2, <id>_02…; textos en
##    data/audio_index.json) para que lo que se oye sea lo que se lee, en ES y en EN.
##  · Sonoridad: ganancia por archivo de data/audio_index.json (voces −16 LUFS, screamers −12) sin tocar los
##    clips cosechados de los juegos anteriores de Joan.
##  · AudioDirector (hijo): pasos por superficie, carrera de Shero, ambiente por piso (oficina, fluorescentes,
##    lluvia tras el vidrio), bus y tono que se degrada con Dread.

const AUDIO_ROOT := "res://assets/audio/"
const MISSING_PATH := "user://MISSING.txt"
const EXTS: Array[String] = [".ogg", ".wav"]
const INDEX := "audio_index"
const SFX_VOICES := 8  # canales de efectos por bus

## Lista de slots revisados al arrancar (v0.1 + los nuevos de la v0.3 que pide el código). El escenario
## p6_audio revisa TODOS los que pide el código y los datos (también los dinámicos).
const SLOTS: Dictionary = {
	"voces/shero": ["shero_buenas_team", "shero_isla_10min", "shero_no_hay_breaks", "shero_correo_once_min", "shero_screamer", "shero_a_trabajar", "shero_contesten", "shero_persecucion", "shero_regresa_sitio", "shero_tres_breaks", "scr_llamadas", "scr_isla"],
	"voces/clientes": ["cliente_estafado_01", "cliente_estafado_02", "cliente_el_que_repite_01", "cliente_amable_01", "cliente_la_que_llora_01"],
	"voces/vitzo": ["vitzo_recordatorio", "vitzo_screamer", "scr_wmm"],
	"voces/comp": ["comp_no_te_pares", "comp_mira_el_reflejo", "comp_viene_shero"],
	"voces/otros": ["fermin_buenas_noches", "fermin_marca", "scr_fermin"],
	"voces/haime": ["scr_haime", "scr_inasistencia", "rec"],
	"voces/trainer": ["trainer_gaaaa_01", "trainer_muerte_01", "trainer_risa"],
	"voces/rasec": ["scr_coaching", "scr_exceso", "scr_evento", "musica_on"],
	"voces/rta": ["scr_rta", "rta_aviso"],
	"sfx": ["auricular_pitido", "auricular_desconexion", "fonex_cambio_aux", "ezlak_notificacion", "ezlak_mencion", "ezlak_escribiendo", "ww_popup", "ack_click", "molinete", "detector", "casillero_abrir", "casillero_cerrar", "refri", "microondas_fin", "expendedora", "maquina_agua", "lanyard_tintineo", "impresora", "ascensor_llegada", "ascensor_boton_muerto", "puerta_vidrio", "puerta_cortafuego", "respiracion", "parpadeo", "monitor_encender", "monitor_apagar", "tono_grave_sting", "telefono_timbre", "rta_ladrido", "trainer_golpe", "pa_chime", "ascensor_motor", "screamer_shero", "screamer_rasec", "screamer_vitzo", "screamer_rta", "screamer_trainer", "screamer_haime", "screamer_grasa", "screamer_guardia", "shero_corre_loop", "caida_cuerpo", "latido_lento",
		"shero_pasos_intensos", "persecucion_latido_loop", "persecucion_drone_loop", "rasec_cabina_golpe", "monitor_rompe", "vitzo_arrastre_loop", "estatica_desconexion", "respiracion_carrera_loop", "auricular_cliente_cuelga", "auricular_conecta", "ui_error", "acufeno"],
	"sfx/pasos": ["pasos_alfombra", "pasos_porcelanato", "pasos_vinilico", "pasos_escalera", "pasos_exterior", "pasos_deck", "correr_alfombra", "correr_porcelanato", "correr_vinilico", "correr_escalera", "correr_exterior", "correr_deck", "aterrizaje_alfombra", "aterrizaje_porcelanato", "aterrizaje_vinilico", "aterrizaje_escalera", "aterrizaje_exterior", "aterrizaje_deck"],
	"ambiente": ["fluorescente_zumbido", "fluorescente_parpadeo", "aire_acondicionado", "teclados_lejanos", "llamadas_ajenas", "calle_madrugada", "calle_6am", "azotea_viento", "tono_grave_tension", "lluvia", "lluvia_cama_b", "lluvia_gota", "lluvia_rafaga", "lluvia_canaleta", "oficina_lejana_loop", "fluorescente_sala_loop", "bus_ralenti_loop", "trueno_lejano_01", "autopista_rumor_loop", "autopista_camion", "ventilacion_loop"],
	"musica": ["hold_kipupay", "hold_kipupay_parlantes", "rasec_madrugada", "rasec_karaoke", "rasec_charadas", "rasec_sillas", "tension_capa_1", "tension_capa_2", "tension_capa_3", "tension_capa_4", "feedback_haime_loop", "rasec_animo_forzado"],
}

var _missing_logged: Dictionary = {}
var _stream_cache: Dictionary = {}
var _resolve_cache: Dictionary = {}
var _voice_players: Dictionary = {}  # bus -> AudioStreamPlayer (una línea a la vez por bus)
var _sfx_pool: Dictionary = {}  # bus -> Array[AudioStreamPlayer]
var _sfx_next: Dictionary = {}
var _last_pick: Dictionary = {}  # slot -> última variante elegida
var _ambient_players: Dictionary = {}  # slot -> AudioStreamPlayer (bucles)
var _music: AudioStreamPlayer = null
var _gain: Dictionary = {}
var _texts: Dictionary = {}  # "voces/<c>/<id>" -> {es, en}
var director: Node = null
## Última voz que sonó (pruebas: p6_audio comprueba idioma, variante y subtítulo).
var last_voice: Dictionary = {}
var last_sfx: Dictionary = {}
var sfx_history: Array[String] = []  # últimos 24 slots de efectos pedidos (pruebas: con mucho tráfico last_sfx no alcanza)
var music_slot: String = ""
## v0.3.2: con una voz sonando (VoiceDirector) los efectos nuevos bajan estos dB.
var sfx_duck_db: float = 0.0
var music_started_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Auricular", "Sala", "Ambiente", "UI", "Parlantes"]:  # Parlantes (P7): manda a Sala con el filtro de bocina
		var v := AudioStreamPlayer.new()
		v.bus = bus
		v.name = "Voz_" + bus
		add_child(v)
		_voice_players[bus] = v
		var pool: Array[AudioStreamPlayer] = []
		for i in SFX_VOICES:
			var p := AudioStreamPlayer.new()
			p.bus = bus
			p.name = "Sfx_%s_%d" % [bus, i]
			add_child(p)
			pool.append(p)
		_sfx_pool[bus] = pool
		_sfx_next[bus] = 0
	_ensure_buses()
	_music = AudioStreamPlayer.new()
	_music.bus = "Musica"
	_music.name = "Musica"
	add_child(_music)
	var idx: Dictionary = DataLoader.dict(INDEX)
	_gain = idx.get("gain_db", {})
	_texts = idx.get("textos", {})
	EventBus.player_floor_changed.connect(func(_f: int) -> void: stop_ambient())
	EventBus.subtitle.connect(_on_subtitle)
	_write_missing_report()
	apply_volumes()
	var dscript: Script = load("res://scripts/autoload/audio_director.gd")
	if dscript != null:
		director = dscript.new()
		director.name = "AudioDirector"
		add_child(director)


## Volúmenes de las opciones (settings.json: vol_master, vol_auricular, vol_sala, vol_ambiente, vol_ui).
## P7: para todo lo que suena antes de cerrar el juego. Godot avisa de «ObjectDB instances leaked at exit» por cada
## reproducción (AudioStreamPlayback) que sigue viva al salir: lluvia, ambiente, voces a medias.
func stop_everything() -> void:
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for p in get_tree().root.find_children("*", type, true, false):
			(p as Node).call("stop")


## Cerrar el juego limpio (menú «Marcar salida», herramientas de prueba): para el audio y sale al cuadro siguiente.
func quit_game(code: int = 0) -> void:
	get_tree().paused = true
	stop_everything()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_everything()  # cerrar la ventana (la X) también sale sin reproducciones vivas


func apply_volumes() -> void:
	for pair in [["vol_master", "Master"], ["vol_auricular", "Auricular"], ["vol_sala", "Sala"], ["vol_ambiente", "Ambiente"], ["vol_ui", "UI"]]:
		set_bus_volume(pair[1], float(Loc.get_setting(pair[0], 1.0)))


# --- API ----------------------------------------------------------------------

## Voz: voces/<carpeta>/<archivo> (EN en voces/<carpeta>/en/<archivo>; si falta la EN suena la ES). Con
## subtitle_text elige la variante cuyo texto coincide y emite el subtítulo.
## v0.3.2: suena por el VoiceDirector (una voz a la vez, con prioridad: `priority` < 0 = según la carpeta).
## v0.3.2-core: `opts` pasa al director (must: false = relleno · group · elsewhere · max_wait · dedupe).
func play_voice(folder: String, file: String, subtitle_text: String = "", bus: String = "Sala", priority: int = -1, opts: Dictionary = {}) -> void:
	var slot := voice_slot(folder, file, subtitle_text)
	var path := voice_path(slot)
	var vd := get_node_or_null("/root/VoiceDirector")
	if vd != null:
		var o := opts.duplicate()
		o["text"] = subtitle_text
		o["bus"] = bus
		o["seconds"] = 3.0
		vd.call("say", slot, priority, folder, Callable(), o)
		last_voice = {"slot": slot, "path": path, "bus": bus, "lang": Loc.language, "t": Time.get_ticks_msec(), "frame": Engine.get_process_frames()}
		if path == "":
			_log_missing(slot)
	else:
		_play_voice(slot, path, bus)
	last_voice["folder"] = folder
	last_voice["file"] = file
	last_voice["had_text"] = subtitle_text != ""
	if file.ends_with("screamer") or file.begins_with("scr_"):
		Controls.vibrate(1.0, 1.0, 0.8)  # vibración fuerte en el screamer (GDD 9.2)
	if subtitle_text != "":
		EventBus.subtitle.emit(folder, subtitle_text, 3.0)


## Slot ES de la voz que va a sonar ("voces/<carpeta>/<id>"): la variante que mejor coincide con el texto.
func voice_slot(folder: String, file: String, text: String = "") -> String:
	var base := "voces/%s/%s" % [folder, file]
	var cands: Array[String] = []
	if has_slot(base, false):
		cands.append(base)
	for v in _variants_of(base):
		cands.append(v)
	if cands.is_empty():
		return base
	if cands.size() == 1:
		return cands[0]
	if text == "":
		# sin texto: la línea base si existe (el subtítulo que llegue en este mismo fotograma puede cambiarla,
		# ver _on_subtitle); si no hay base, una variante al azar (trainer_gaaaa_01..04)
		return base if cands[0] == base else cands[randi() % cands.size()]
	var best := cands[0]
	var best_s := -1.0
	for c in cands:
		var s := text_score(text, _text_of(c))
		if s > best_s:
			best_s = s
			best = c
	return best


## Ruta del archivo de una voz en el idioma actual (EN si existe; si no, ES). "" si no hay ninguno.
func voice_path(slot: String) -> String:
	var path := ""
	if Loc.language != "es":
		var parts := slot.split("/")
		if parts.size() >= 3:
			path = resolve("%s/%s/%s/%s" % [parts[0], parts[1], Loc.language, "/".join(parts.slice(2))], false)
	if path == "":
		path = resolve(slot, false)
	return path


## Quien llama play_voice(carpeta, id, "") y emite el subtítulo justo después (PersonajesP5.say/pa, Shero de P3):
## si esa voz tiene variantes y el subtítulo coincide mejor con otra, se cambia en el mismo fotograma (inaudible).
func _on_subtitle(_speaker: String, text: String, _secs: float) -> void:
	if get_node_or_null("/root/VoiceDirector") != null:
		return  # v0.3.2: el VoiceDirector pega el subtítulo a su voz y elige la variante
	if last_voice.is_empty() or bool(last_voice.get("had_text", true)):
		return
	if Engine.get_process_frames() - int(last_voice.get("frame", -10)) > 1:
		return
	var folder := str(last_voice.get("folder", ""))
	var file := str(last_voice.get("file", ""))
	if folder == "" or _variants_of("voces/%s/%s" % [folder, file]).is_empty():
		return
	last_voice["had_text"] = true
	var best := voice_slot(folder, file, text)
	if best != str(last_voice.get("slot", "")):
		var bus := str(last_voice.get("bus", "Sala"))
		_play_voice(best, voice_path(best), bus)
		last_voice["had_text"] = true
		last_voice["folder"] = folder
		last_voice["file"] = file


func play_sfx(file: String, bus: String = "Sala", from_position: float = 0.0) -> void:
	if file == "auricular_pitido":
		Controls.vibrate(0.25, 0.0, 0.15)  # vibración leve con el pitido del auricular
	var slot := "sfx/" + file
	var path := resolve(slot)
	if path == "":
		var amb := resolve("ambiente/" + file)  # algunos efectos viven en ambiente/ (fluorescente_parpadeo)
		if amb != "":
			path = amb
			slot = "ambiente/" + file
	_play_sfx(slot, path, bus, 880.0, 0.06, from_position)


## Ambiente en bucle (varios a la vez: zumbido + teclados). Se cortan al cambiar de piso.
func play_ambient(file: String, volume_db: float = -6.0) -> void:
	var slot := "ambiente/" + file
	if _ambient_players.has(slot):
		return
	var path := resolve(slot)
	var stream: AudioStream = _load_mode(path, true) if path != "" else null
	if stream == null:
		_log_missing(slot)
		return  # sin bucle sintético: el silencio molesta menos que un tono eterno
	var p := AudioStreamPlayer.new()
	p.bus = "Ambiente"
	p.stream = stream
	p.volume_db = volume_db + float(_gain.get(slot, 0.0))
	p.name = "Amb_" + file
	add_child(p)
	p.play()
	_ambient_players[slot] = p


func has_ambient(file: String) -> bool:
	return _ambient_players.has("ambiente/" + file)


## Bucle de un slot cualquiera (motor del ascensor). Si el slot no existe: silencio (antes, un tono grave sintético;
## `_synth_hz` queda por compatibilidad). Se detiene con stop_ambient(nombre) o al cambiar de piso.
func play_loop(slot: String, _synth_hz: float = 55.0, volume_db: float = -10.0) -> void:
	var key := "ambiente/" + slot.get_file()
	if _ambient_players.has(key):
		return
	var path := resolve(slot)
	var stream: AudioStream = _load_mode(path, true) if path != "" else null
	if stream == null:
		_log_missing(slot)
		return  # v0.3.1: sin zumbido sintético; el silencio y MISSING.txt
	var p := AudioStreamPlayer.new()
	p.bus = "Sala"
	p.stream = stream
	p.volume_db = volume_db
	p.name = "Loop_" + slot.get_file()
	add_child(p)
	p.play()
	_ambient_players[key] = p


func stop_ambient(file: String = "") -> void:
	for slot in _ambient_players.keys():
		if file == "" or slot == "ambiente/" + file:
			(_ambient_players[slot] as AudioStreamPlayer).queue_free()
			_ambient_players.erase(slot)


## `loop` = false para una pasada (la distorsión de los parlantes); la música de espera y de los eventos va en bucle.
func play_music(file: String, loop: bool = true) -> void:
	var slot := "musica/" + file
	var path := resolve(slot)
	var stream: AudioStream = _load_mode(path, loop) if path != "" else null
	if stream == null:
		_log_missing(slot)
		_music.stop()
		return
	_music.stream = stream
	_music.volume_db = float(_gain.get(slot, 0.0))
	_music.bus = "RasecDegrada" if file.begins_with("rasec_") else "Musica"
	_music.play()
	music_slot = slot
	music_started_ms = Time.get_ticks_msec()


## Para la música de play_music (cama del feedback de Haime, evento). La cama de tensión es del MusicDirector.
func stop_music() -> void:
	_music.stop()
	music_slot = ""


func music_playing() -> String:
	return music_slot if _music != null and _music.playing else ""


## Cualquier slot (también una voz) como golpe suelto en los canales de efectos: capas que no deben cortar la voz
## del mismo bus (p. ej. voces/vitzo/vitzo_screamer_capa debajo del grito de Vitzo).
func play_slot(slot: String, bus: String = "Sala") -> void:
	_play_sfx(slot, resolve(slot), bus, 880.0, 0.06, 0.0)


## Golpe de tensión (reflejo de Shero, aviso de screamer): bombo de orquesta + cuerdas graves (sfx/tono_grave_sting).
func play_sting() -> void:
	var slot := "sfx/tono_grave_sting"
	_play_sfx(slot, resolve(slot), "Sala", 70.0, 1.2, 0.0)


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))


## Stream de un slot (con variantes al azar), cargado y sin bucle: para quien tiene su propio reproductor
## (truenos de Weather, bus, voz 3D de Shero). null si no hay archivo.
func stream_for(slot: String, loop: bool = false) -> AudioStream:
	var path := resolve(slot)
	return _load_mode(path, loop) if path != "" else null


## Ganancia de sonoridad (dB) del archivo de un slot (data/audio_index.json).
func gain_db(slot: String) -> float:
	return float(_gain.get(slot, 0.0))


# --- Resolución y carga ---------------------------------------------------------

## Ruta real de un slot ("sfx/ww_popup") probando .ogg/.wav, importado o no. Si `variants` y hay
## <slot>_01.._NN (o <slot>_02.. además de <slot>), una al azar. "" si no existe.
func resolve(slot: String, variants: bool = true) -> String:
	var base := _resolve_exact(slot)
	if not variants:
		return base
	var vs := _variants_of(slot)
	if vs.is_empty():
		return base
	var pool: Array[String] = []
	if base != "":
		pool.append(base)
	for v in vs:
		pool.append(_resolve_exact(v))
	# al azar, sin repetir la toma anterior del mismo slot (tres truenos seguidos iguales se notan)
	var prev := str(_last_pick.get(slot, ""))
	if pool.size() > 1 and prev != "":
		pool.erase(prev)
	var pick := pool[randi() % pool.size()]
	_last_pick[slot] = pick
	return pick


func _resolve_exact(slot: String) -> String:
	if _resolve_cache.has(slot):
		return _resolve_cache[slot]
	var out := ""
	for ext in EXTS:
		var path := AUDIO_ROOT + slot + ext
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			out = path
			break
	_resolve_cache[slot] = out
	return out


## Variantes numeradas o de texto de un slot: <slot>_01.._12 y <slot>__2.._6 que existan.
func _variants_of(slot: String) -> Array[String]:
	var key := "v:" + slot
	if _resolve_cache.has(key):
		return _resolve_cache[key]
	var out: Array[String] = []
	for i in range(1, 13):
		var s := "%s_%02d" % [slot, i]
		if _resolve_exact(s) != "":
			out.append(s)
	for i in range(2, 7):
		var s2 := "%s__%d" % [slot, i]
		if _resolve_exact(s2) != "":
			out.append(s2)
	_resolve_cache[key] = out
	return out


func has_slot(slot: String, variants: bool = true) -> bool:
	return resolve(slot, variants) != ""


## Texto (en el idioma actual, si no ES) de una voz del índice.
func _text_of(slot: String) -> String:
	var t: Dictionary = _texts.get(slot, {})
	return str(t.get(Loc.language, t.get("es", "")))


## Parecido de dos textos (0..1): Dice de palabras sin tildes ni signos; ignora el "[Hablante]" inicial.
static func text_score(a: String, b: String) -> float:
	var ta := _tokens(a)
	var tb := _tokens(b)
	if ta.is_empty() or tb.is_empty():
		return 0.0
	var common := 0
	for w in ta:
		if tb.has(w):
			common += 1
	return 2.0 * common / float(ta.size() + tb.size())


static func _tokens(s: String) -> Dictionary:
	var t := s.to_lower()
	if t.begins_with("["):
		var e := t.find("]")
		if e > 0 and e < 40:
			t = t.substr(e + 1)
	var rep := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
	for k in rep.keys():
		t = t.replace(k, rep[k])
	var out := {}
	var cur := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			cur += ch
		else:
			if cur.length() > 1:
				out[cur] = true
			cur = ""
	if cur.length() > 1:
		out[cur] = true
	return out


## Carga un stream importado (load) o directo del archivo (ogg/wav sin importar, p. ej. añadido a mano).
func _load(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		if path.ends_with(".ogg"):
			stream = AudioStreamOggVorbis.load_from_file(path)
		elif path.ends_with(".wav"):
			stream = AudioStreamWAV.load_from_file(path)
	if stream != null:
		_stream_cache[path] = stream
	return stream


## El mismo archivo puede sonar como bucle (ambiente) y como golpe suelto (play_sfx): cada modo usa su propia copia
## del recurso (comparten los datos) para que poner loop en uno no corte ni eternice el otro.
func _load_mode(path: String, loop: bool) -> AudioStream:
	var key := path + ("#bucle" if loop else "#una")
	if _stream_cache.has(key):
		return _stream_cache[key]
	var base := _load(path)
	if base == null:
		return null
	var s := base.duplicate() as AudioStream
	_set_loop(s, loop)
	_stream_cache[key] = s
	return s


func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = on
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED
		if on:
			(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / (2 if (stream as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if (stream as AudioStreamWAV).stereo else 1)


func _slot_of_path(path: String) -> String:
	var s := path.trim_prefix(AUDIO_ROOT)
	for ext in EXTS:
		s = s.trim_suffix(ext)
	return s


func _play_voice(slot: String, path: String, bus: String) -> void:
	var player: AudioStreamPlayer = _voice_players.get(bus, _voice_players["Sala"])
	var stream: AudioStream = _load_mode(path, false) if path != "" else null
	if stream == null:
		_log_missing(slot)
		_missing_subtitle(slot)
		last_voice = {"slot": slot, "path": "", "bus": bus, "lang": Loc.language, "t": Time.get_ticks_msec(), "frame": Engine.get_process_frames()}
		return  # silencio (C2)
	player.volume_db = gain_db(_slot_of_path(path))
	player.stream = stream
	player.play()
	last_voice = {"slot": slot, "path": path, "bus": bus, "lang": Loc.language, "t": Time.get_ticks_msec(), "frame": Engine.get_process_frames()}


func _play_sfx(slot: String, path: String, bus: String, _synth_hz: float, _synth_len: float, from_position: float) -> void:
	var pool: Array = _sfx_pool.get(bus, _sfx_pool["Sala"])
	var b := bus if _sfx_pool.has(bus) else "Sala"
	var i: int = _sfx_next[b]
	var player: AudioStreamPlayer = pool[i]
	_sfx_next[b] = (i + 1) % pool.size()
	var stream: AudioStream = _load_mode(path, false) if path != "" else null
	last_sfx = {"slot": slot, "path": path, "bus": bus, "t": Time.get_ticks_msec()}
	sfx_history.append(slot)
	if sfx_history.size() > 24:
		sfx_history.pop_front()
	if stream == null:
		_log_missing(slot)
		_missing_subtitle(slot)
		return  # silencio (C2): el slot sigue anotado en MISSING.txt
	player.volume_db = gain_db(_slot_of_path(path)) + sfx_duck_db
	player.stream = stream
	player.play(maxf(from_position, 0.0))


## "[audio pendiente: …]" solo en depuración (en un build exportado nunca se muestra).
func _missing_subtitle(slot: String) -> void:
	if OS.is_debug_build() and bool(Loc.get_setting("subtitles", true)):
		EventBus.subtitle.emit("sys", Loc.fmt(tr("SUB_MISSING_AUDIO"), {"file": slot}), 1.5)


# --- Buses propios (v0.3.1 Q3) ------------------------------------------------------------------

## Crea (una vez) los buses de Q3 al final del layout: no hace falta tocar default_bus_layout.tres.
func _ensure_buses() -> void:
	_bus("Musica", "Ambiente", [])
	# v0.3.2: «Duck» al final de Música y Ambiente (VoiceDirector los baja con una voz sonando).
	for b in ["Musica", "Ambiente"]:
		var bi := AudioServer.get_bus_index(b)
		if bi < 0:
			continue
		var has := false
		for e in AudioServer.get_bus_effect_count(bi):
			has = has or AudioServer.get_bus_effect(bi, e).resource_name == "Duck"
		if not has:
			var amp := AudioEffectAmplify.new()
			amp.resource_name = "Duck"
			amp.volume_db = 0.0
			AudioServer.add_bus_effect(bi, amp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	lp.resonance = 0.3
	_bus("Lluvia", "Ambiente", [lp])
	_bus("HaimeReplay", "Master", QaFeedback.replay_effects())  # v0.3.2 Haime: el bus del auricular de la sala, creado al arrancar (no en plena partida)
	for side in [["PasosL", -0.15], ["PasosR", 0.15]]:
		var pan := AudioEffectPanner.new()
		pan.pan = float(side[1])
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.4
		rv.damping = 0.6
		rv.wet = 0.0
		rv.dry = 1.0
		rv.predelay_msec = 12.0
		rv.spread = 0.6
		_bus(str(side[0]), "Sala", [pan, rv])
	var ps := AudioEffectPitchShift.new()
	ps.pitch_scale = 1.0
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.0
	dist.post_gain = 0.0
	var lp2 := AudioEffectLowPassFilter.new()
	lp2.cutoff_hz = 20000.0
	_bus("RasecDegrada", "Sala", [ps, dist, lp2])


func _bus(name: String, send: String, effects: Array) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, send if AudioServer.get_bus_index(send) >= 0 else "Master")
	for e in effects:
		AudioServer.add_bus_effect(idx, e)
	return idx


## Efecto `i` del bus `name` (null si no existe).
func bus_effect(name: String, i: int) -> AudioEffect:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0 or i >= AudioServer.get_bus_effect_count(idx):
		return null
	return AudioServer.get_bus_effect(idx, i)


# --- MISSING.txt ----------------------------------------------------------------

## Escribe la lista completa de slots que faltan (al arrancar) para que Joan grabe encima.
func _write_missing_report() -> void:
	var f := FileAccess.open(MISSING_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("# Audio que falta (ruta relativa a game/assets/audio/, sin extensión; vale .ogg o .wav).")
	f.store_line("# Convención: sfx/, ambiente/, musica/, voces/<slug>/ (EN en voces/<slug>/en/). Ver docs/AUDIO_SLOTS.md.")
	f.store_line("# Lista completa (código + datos, también los ids dinámicos): -- --escenario p6_audio.")
	var total := 0
	var missing := 0
	for folder in SLOTS.keys():
		for name in SLOTS[folder]:
			total += 1
			var slot := "%s/%s" % [folder, name]
			if not has_slot(slot):
				missing += 1
				_missing_logged[slot] = true
				f.store_line(slot)
	f.store_line("# %d de %d slots presentes." % [total - missing, total])


func _log_missing(slot: String) -> void:
	if _missing_logged.has(slot):
		return
	_missing_logged[slot] = true
	var f := FileAccess.open(MISSING_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MISSING_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(slot + "   # pedido por el juego fuera de la lista")


## Slots que el juego pidió y no existían en esta sesión (pruebas).
func missing_requested() -> Array:
	return _missing_logged.keys()

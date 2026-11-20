extends Node
## v0.3.2 IA · Voz → texto para las llamadas (autoload IASpeech). Opciones › «Responder llamadas: Respuestas
## predefinidas / Micrófono» (settings «ia_llamadas»: "predefinidas" | "microfono"; por defecto predefinidas).
## Motores:
##   · "vosk"  (Windows/Linux): sidecar sin red tools/asr_sidecar/avail_asr(.exe) + libvosk (Apache-2.0) + el modelo
##             vosk-model-small-es-0.3 (Apache-2.0, 53 MB), en <carpeta del juego>/asr/. El juego le pasa el audio del
##             micrófono (AudioServer input, 16 kHz mono) por una tubería y recibe parciales y el resultado final.
##             Si el sidecar falla o no está, el estado queda «no disponible» y la llamada sigue con respuestas rápidas.
##   · "web"   (HTML): Web Speech API del navegador vía JavaScriptBridge. Chrome manda el audio a Google: solo se usa
##             si el jugador lo aceptó en Opciones (settings «ia_voz_web_ok»).
##   · "mock"  (pruebas): inject(texto) / inject_fail().
## Pulsar para hablar: acción «ia_hablar» (T por defecto). Señales: state_changed(estado) · level(0..1) ·
## partial(texto) · result(texto, ok). Estados: off · loading · ready · listening · thinking · error · unavailable.
## feed_wav(ruta): manda un WAV grabado al motor como si fuera el micrófono (pruebas y capturas).

signal state_changed(s: String)
signal level(v: float)
signal partial(text: String)
signal result(text: String, ok: bool)

const RATE := 16000
const PTT_ACTION := "ia_hablar"
const FINAL_TIMEOUT_S := 6.0

var state: String = "off"
var reason: String = ""  # por qué no está disponible
var engine: String = ""
var forced_engine: String = ""  # pruebas: "mock" | "vosk" | "web"
var last_text: String = ""
var last_level: float = 0.0
var listening_s: float = 0.0
var _proc: Dictionary = {}
var _reader: Thread = null
var _lines: Array[String] = []
var _mutex := Mutex.new()
var _out: PackedByteArray = PackedByteArray()
var _resample_acc: float = 0.0
var _final_wait: float = -1.0
var _mock_queue: Array = []
var _web_finals: String = ""
var _web_ready: bool = false
var _wav_feed: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(PTT_ACTION):
		InputMap.add_action(PTT_ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_T
		InputMap.action_add_event(PTT_ACTION, ev)
	EventBus.settings_changed.connect(func(k: String) -> void:
		if k in ["ia_llamadas", "ia_voz_web_ok"]:
			refresh())


func mic_mode() -> bool:
	return str(Loc.get_setting("ia_llamadas", "predefinidas")) == "microfono"


func _set_state(s: String, why: String = "") -> void:
	if s == state and why == reason:
		return
	state = s
	reason = why
	state_changed.emit(s)


## Motor que toca en esta plataforma (o el forzado por las pruebas).
func pick_engine() -> String:
	if forced_engine != "":
		return forced_engine
	if OS.has_feature("web"):
		return "web"
	return "vosk"


## Arranca o apaga el motor según la opción. Se llama al entrar a una llamada y al cambiar la opción.
func refresh() -> void:
	if not mic_mode() and forced_engine == "":
		shutdown()
		_set_state("off")
		return
	ensure()


func ensure() -> void:
	var e := pick_engine()
	if engine == e and state in ["ready", "listening", "thinking", "loading"]:
		return
	engine = e
	match e:
		"mock":
			_set_state("ready")
		"web":
			_start_web()
		"vosk":
			_start_vosk()


func available() -> bool:
	return state in ["ready", "listening", "thinking"]


## v0.3.2-core: el motor sin conexión (Vosk) solo trae el modelo en español. Con el juego en inglés el micrófono
## sigue funcionando si hablas en español, pero hay que decirlo claro y dejar a mano las respuestas escritas y
## rápidas (que sí funcionan enteras en inglés). En el navegador la voz la hace el navegador en el idioma del juego.
func spanish_only() -> bool:
	return pick_engine() == "vosk"


## ¿Hay que avisar de que la voz no entiende el idioma del juego?
func language_mismatch() -> bool:
	return Loc.language == "en" and spanish_only()


# --- pulsar para hablar -------------------------------------------------------------------------------------

func ptt_down() -> bool:
	if state != "ready":
		return false
	listening_s = 0.0
	last_text = ""
	_set_state("listening")
	match engine:
		"vosk":
			_send(&"R", PackedByteArray())
			if AudioServer.set_input_device_active(true) != OK:
				_set_state("unavailable", "mic")
				return false
		"web":
			_web_finals = ""
			JavaScriptBridge.eval("window.__availSRq=[]; try{window.__availSR.start()}catch(e){window.__availSRq.push('ERR '+e)}", true)
	return true


func ptt_up() -> void:
	if state != "listening":
		return
	_set_state("thinking")
	_final_wait = FINAL_TIMEOUT_S
	match engine:
		"vosk":
			_pump_mic()
			AudioServer.set_input_device_active(false)
			_flush_out()
			_send(&"E", PackedByteArray())
		"web":
			JavaScriptBridge.eval("try{window.__availSR.stop()}catch(e){}", true)
		"mock":
			_final_wait = 0.4


## Pruebas: lo próximo que «oiga» el motor mock.
func inject(text: String) -> void:
	_mock_queue.append(text)


func inject_fail() -> void:
	_mock_queue.append(null)


## Manda un WAV (PCM 16 bits, cualquier frecuencia, mono o estéreo) como si sonara por el micrófono.
func feed_wav(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or engine != "vosk" or state != "ready":
		return false
	var bytes := f.get_buffer(f.get_length())
	var pcm := _wav_to_16k(bytes)
	if pcm.is_empty():
		return false
	_set_state("listening")
	_send(&"R", PackedByteArray())
	_wav_feed = pcm
	return true


func _finish(text: String, ok: bool) -> void:
	_final_wait = -1.0
	last_text = text
	if state in ["thinking", "listening"]:
		_set_state("ready")
	result.emit(text, ok)


func _process(delta: float) -> void:
	if engine == "vosk" and not _proc.is_empty():
		_read_lines()
		if state == "listening":
			listening_s += delta
			if _wav_feed.is_empty():
				_pump_mic()
			else:
				_pump_wav(delta)
			_flush_out()
	elif engine == "web" and _web_ready:
		_poll_web()
		if state == "listening":
			listening_s += delta
	elif engine == "mock" and state == "listening":
		listening_s += delta
		last_level = 0.35 + 0.3 * sin(listening_s * 18.0)
		level.emit(last_level)
	if _final_wait >= 0.0:
		_final_wait -= delta
		if engine == "mock" and _final_wait <= 0.0:
			var t: Variant = _mock_queue.pop_front() if not _mock_queue.is_empty() else null
			_finish(str(t) if t != null else "", t != null and str(t).strip_edges() != "")
		elif _final_wait <= 0.0:
			_finish(last_text, false)
	# pulsar para hablar con la tecla (no mientras escribes en un campo)
	if mic_mode() and InputMap.has_action(PTT_ACTION) and not bool(GameState.flags.get("pc_text_focus", false)) and bool(GameState.flags.get("ia_llamada_activa", false)):
		if Input.is_action_just_pressed(PTT_ACTION):
			ptt_down()
		elif Input.is_action_just_released(PTT_ACTION):
			ptt_up()


# --- Vosk (sidecar) -----------------------------------------------------------------------------------------

## Carpeta del motor: junto al ejecutable (builds) o tools/asr_sidecar/dist/<plataforma> (desarrollo).
func asr_dir() -> String:
	var cands: Array[String] = []
	if OS.get_environment("AVAIL_ASR_DIR") != "":
		cands.append(OS.get_environment("AVAIL_ASR_DIR"))
	cands.append(OS.get_executable_path().get_base_dir().path_join("asr"))
	var plat := "windows" if OS.has_feature("windows") else "linux"
	cands.append(ProjectSettings.globalize_path("res://").path_join("../tools/asr_sidecar/dist").path_join(plat).simplify_path())
	for c in cands:
		if FileAccess.file_exists(c.path_join(_exe_name())):
			return c
	return ""


func _exe_name() -> String:
	return "avail_asr.exe" if OS.has_feature("windows") else "avail_asr"


func _start_vosk() -> void:
	shutdown()
	var dir := asr_dir()
	if dir == "":
		_set_state("unavailable", "no_engine")
		return
	var model := dir.path_join("model-es")
	if not DirAccess.dir_exists_absolute(model):
		_set_state("unavailable", "no_model")
		return
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_set_state("unavailable", "mic")
		return
	_set_state("loading")
	_proc = OS.execute_with_pipe(dir.path_join(_exe_name()), [model, str(RATE)], true)
	if _proc.is_empty() or not _proc.has("stdio"):
		_proc = {}
		_set_state("unavailable", "no_engine")
		return
	_reader = Thread.new()
	_reader.start(_reader_loop.bind(_proc["stdio"]))


func _reader_loop(pipe: FileAccess) -> void:
	while true:
		var l := pipe.get_line()
		if l == "" and pipe.get_error() != OK:
			_mutex.lock()
			_lines.append("EOF")
			_mutex.unlock()
			return
		_mutex.lock()
		_lines.append(l)
		_mutex.unlock()


func _read_lines() -> void:
	_mutex.lock()
	var ls := _lines.duplicate()
	_lines.clear()
	_mutex.unlock()
	for l in ls:
		if l == "READY":
			_set_state("ready")
		elif l.begins_with("P "):
			var v: Variant = JSON.parse_string(l.substr(2))
			if v is Dictionary:
				var t := str((v as Dictionary).get("partial", ""))
				if t != "":
					last_text = t
					partial.emit(t)
		elif l.begins_with("F "):
			var v2: Variant = JSON.parse_string(l.substr(2))
			var t2 := str((v2 as Dictionary).get("text", "")) if v2 is Dictionary else ""
			if state in ["thinking", "listening"]:
				_finish(t2, t2.strip_edges() != "")
		elif l.begins_with("ERR") or l == "EOF":
			var was := state
			_proc = {}
			_set_state("error" if was != "loading" else "unavailable", l)
			if was in ["thinking", "listening"]:
				result.emit("", false)


func _send(op: StringName, data: PackedByteArray) -> void:
	if _proc.is_empty():
		return
	var hdr := PackedByteArray([str(op).unicode_at(0), 0, 0, 0, 0])
	hdr.encode_u32(1, data.size())
	var pipe: FileAccess = _proc["stdio"]
	pipe.store_buffer(hdr + data)


func _pump_mic() -> void:
	var n := AudioServer.get_input_frames_available()
	if n <= 0:
		return
	var frames := AudioServer.get_input_frames(n)
	var src_rate := AudioServer.get_input_mix_rate()
	var step := src_rate / float(RATE)
	var peak := 0.0
	var i := _resample_acc
	while i < frames.size():
		var s := frames[int(i)]
		var m := clampf((s.x + s.y) * 0.5, -1.0, 1.0)
		peak = maxf(peak, absf(m))
		var v := int(m * 32767.0)
		_out.append(v & 0xFF)
		_out.append((v >> 8) & 0xFF)
		i += step
	_resample_acc = i - frames.size()
	last_level = clampf(peak * 1.4, 0.0, 1.0)
	level.emit(last_level)


func _pump_wav(delta: float) -> void:
	var n := mini(_wav_feed.size(), int(RATE * maxf(delta, 1.0 / 60.0)))
	var peak := 0
	for k in n:
		var v := _wav_feed[k]
		peak = maxi(peak, absi(v))
		_out.append(v & 0xFF)
		_out.append((v >> 8) & 0xFF)
	_wav_feed = _wav_feed.slice(n)
	last_level = clampf(float(peak) / 32767.0 * 1.4, 0.0, 1.0)
	level.emit(last_level)
	if _wav_feed.is_empty():
		_flush_out()
		ptt_up()


func _flush_out() -> void:
	while _out.size() > 0:
		var n := mini(_out.size(), 3200)
		_send(&"A", _out.slice(0, n))
		_out = _out.slice(n)


static func _wav_to_16k(b: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return out
	var pos := 12
	var ch := 1
	var rate := 16000
	var bits := 16
	var data_off := -1
	var data_len := 0
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var ln := b.decode_u32(pos + 4)
		if id == "fmt ":
			ch = b.decode_u16(pos + 10)
			rate = b.decode_u32(pos + 12)
			bits = b.decode_u16(pos + 22)
		elif id == "data":
			data_off = pos + 8
			data_len = mini(ln, b.size() - data_off)
			break
		pos += 8 + ln + (ln & 1)
	if data_off < 0 or bits != 16:
		return out
	var frames := data_len / (2 * ch)
	var step := float(rate) / float(RATE)
	var t := 0.0
	while int(t) < frames:
		var k := data_off + int(t) * 2 * ch
		var v := b.decode_s16(k)
		if ch > 1:
			v = (v + b.decode_s16(k + 2)) / 2
		out.append(v)
		t += step
	return out


func shutdown() -> void:
	if not _proc.is_empty():
		_send(&"Q", PackedByteArray())
		var pid := int(_proc.get("pid", -1))
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
		_proc = {}
	if _reader != null:
		if _reader.is_started():
			_reader.wait_to_finish()
		_reader = null
	_lines.clear()
	if engine == "vosk":
		AudioServer.set_input_device_active(false)


func _exit_tree() -> void:
	shutdown()


# --- Web Speech (HTML) --------------------------------------------------------------------------------------

func _start_web() -> void:
	if not bool(Loc.get_setting("ia_voz_web_ok", false)):
		_set_state("unavailable", "no_consent")
		return
	var ok: Variant = JavaScriptBridge.eval("""(function(){var SR=window.SpeechRecognition||window.webkitSpeechRecognition;if(!SR)return false;
var r=new SR();r.lang=%s;r.interimResults=true;r.continuous=true;r.maxAlternatives=1;window.__availSRq=[];
r.onresult=function(e){for(var i=e.resultIndex;i<e.results.length;i++){window.__availSRq.push((e.results[i].isFinal?'F ':'P ')+e.results[i][0].transcript);}};
r.onerror=function(e){window.__availSRq.push('ERR '+e.error);};r.onend=function(){window.__availSRq.push('END');};
r.onsoundstart=function(){window.__availSRq.push('S');};window.__availSR=r;return true;})()""" % JSON.stringify("es-PE" if Loc.language != "en" else "en-US"), true)
	_web_ready = bool(ok)
	_set_state("ready" if _web_ready else "unavailable", "" if _web_ready else "no_engine")


func _poll_web() -> void:
	for _k in 8:
		var l := str(JavaScriptBridge.eval("(window.__availSRq&&window.__availSRq.length)?window.__availSRq.shift():''", true))
		if l == "" or l == "null":
			return
		if l == "S":
			last_level = 0.6
			level.emit(last_level)
		elif l.begins_with("P "):
			last_text = (_web_finals + " " + l.substr(2)).strip_edges()
			partial.emit(last_text)
			last_level = 0.5
			level.emit(last_level)
		elif l.begins_with("F "):
			_web_finals = (_web_finals + " " + l.substr(2)).strip_edges()
			last_text = _web_finals
			partial.emit(last_text)
		elif l == "END":
			if state in ["thinking", "listening"]:
				_finish(_web_finals, _web_finals.strip_edges() != "")
		elif l.begins_with("ERR"):
			if l.contains("not-allowed") or l.contains("service-not-allowed"):
				_set_state("unavailable", "mic")
			if state in ["thinking", "listening"] or state == "unavailable":
				result.emit("", false)

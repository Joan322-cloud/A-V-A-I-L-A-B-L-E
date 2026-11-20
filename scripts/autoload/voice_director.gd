extends Node
## VoiceDirector (autoload, v0.3.2; Joan: «estás cruzando todos los diálogos a la vez y no se entiende nada»).
## Toda línea hablada pasa por aquí: los personajes (PersonajesP5.say/pa → AudioManager.play_voice), Shero en persona
## (SheroPresence), el cliente de la llamada, los compañeros, el PA, los murmullos de ambiente y los subtítulos que
## se emiten sueltos (EventBus.subtitle). Reglas:
##   - Suena UNA línea a la vez (y se ve UN subtítulo a la vez: el HUD escucha subtitle_shown, no EventBus.subtitle).
##   - Prioridad (mayor primero): SCREAMER (muerte) > CLIENTE (llamada en curso) > DIRECTO (te convocan, Haime, el
##     Trainer, Shero, el PA) > AMBIENTE (compañeros) > BARK (murmullos, risas, gritos sueltos).
##   - Con una voz sonando, la música y el ambiente bajan (AudioEffectAmplify «Duck») y los efectos 4 dB.
##   - Durante la muerte (screamer/pantalla) solo pasa SCREAMER; lo demás se descarta hasta reaparecer. Los screamers
##     (fx/screamers.gd, kill_moves.gd) no necesitan llamarlo: death_sequence_started corta todo (stop_all) y sus
##     subtítulos pasan como SCREAMER. Quien quiera cortar a mano: VoiceDirector.stop_all("motivo") o
##     VoiceDirector.say(id, VoiceDirector.P.SCREAMER, …), que siempre entra.
##
## v0.3.2-core · LÍNEAS IMPORTANTES Y RELLENO (medido a velocidad real: en un turno se perdían 6 líneas que el jugador
## necesitaba — las preguntas del evento de Rasec, el «Pase, está limpio» de Don Fermín, el aviso del compañero):
##   - IMPORTANTE (`must`, lo normal): toda línea de AMBIENTE para arriba que no sea relleno. Nunca se pierde en
##     silencio: (1) mientras suena, solo la corta un SCREAMER, su propia línea siguiente (mismo `group`: el cliente
##     que pasa al nodo siguiente) o quien la cancela a mano; una de más prioridad ESPERA a que termine (segundos);
##     (2) en cola espera su turno hasta MUST_WAIT; si ni así pudo sonar, su texto sale como AVISO (notice_shown: el
##     HUD lo muestra arriba a la izquierda) en vez de desaparecer. Las que ya se leen en otra parte (`elsewhere`: la
##     línea del cliente está en Kardex) vencen sin aviso.
##   - RELLENO (`must: false`: murmullos, susurros de los compañeros hartos, comentarios sueltos de Shero, anuncios de
##     ambiente por los parlantes): lo corta cualquiera de más prioridad y vence en cola (BARK 1 s · AMBIENTE 5 s).
##     Un relleno de solo texto no retrasa a nadie: lo corta cualquier voz o línea importante.
##   - REPETIDAS: la misma línea pedida otra vez mientras suena o espera no se apila («¡Eso! Más fuerte» ×5).
##   - AVISOS (hablantes «ezlak» y «sys»: el resumen de un DM, «Llamando a Marko…»): no son habla y no ocupan el
##     canal de las voces; van a la fila de avisos (uno a la vez, los viejos de Ezlaki ceden: siguen en el chat).
##   - La cola del audio manda: una línea no termina mientras su reproductor siga sonando (hasta TAIL_MAX_MS) y al
##     arrancar la siguiente se corta cualquier resto: nunca dos voces a la vez aunque el hilo de audio vaya atrasado.
##
## API: say(line_id, priority, speaker, on_done, opts) -> Line  ·  `await line.finished`  ·  señal finished(line_id).
##   line_id = "voces/<carpeta>/<archivo>" (con voz) o un id libre con opts.text (solo subtítulo).
##   opts: text, seconds (lectura), bus, max_wait, player (un AudioStreamPlayer/3D propio: el director lo arranca cuando
##   le toca y lo corta si lo interrumpen), free_on_drop, must (bool), group (String), elsewhere (bool), dedupe (bool).
##   text(speaker, texto, segundos, opts) = una línea de solo texto · notice(speaker, texto, segundos) = un aviso.
## Auditoría: `timeline` ([inicio_ms, fin_ms, id, prioridad, hablante]), `overlaps` (veces que sonaron 2 voces a la vez,
## mirando también los reproductores de voz de AudioManager y los externos), `lines_noticed` (importantes que salieron
## como aviso), `lines_merged` (repetidas) y `lost_important` (importantes perdidas de verdad: debe quedar vacío).
## `--voz-log` imprime cada línea.

signal finished(line_id: String)
signal line_started(line_id: String, speaker: String, priority: int)
signal subtitle_shown(speaker: String, text: String, seconds: float)
## Aviso de texto (no es habla): el HUD lo muestra arriba a la izquierda. `must` = viene de una línea importante que
## no pudo sonar (se muestra aunque los subtítulos estén apagados). text == "" = quitar el aviso.
signal notice_shown(speaker: String, text: String, seconds: float, must: bool)

enum P { BARK, AMBIENTE, DIRECTO, CLIENTE, SCREAMER }

const FADE_S := 0.08
const TAIL_MAX_MS := 600  # cuánto se espera, como mucho, a que el reproductor termine de verdad después de su hora
const MAX_WAIT := {0: 1.0, 1: 5.0, 2: 15.0, 3: 8.0, 4: 0.0}
## Espera máxima en cola de una línea importante antes de salir como aviso de texto.
const MUST_WAIT := {0: 1.0, 1: 8.0, 2: 15.0, 3: 8.0, 4: 0.0}
const DUCK_DB := -7.0
const SFX_DUCK_DB := -4.0
const DIRECT_SPEAKERS := ["haime", "qa", "trainer", "rasec", "shero", "mentor", "rta", "vitzo", "parlantes", "enfermero", "fermin", "tm"]
## Hablantes cuyo texto suelto es un AVISO (no habla): no ocupan el canal de las voces.
const NOTICE_SPEAKERS := ["ezlak", "sys"]
## Hablantes que son relleno salvo que se diga otra cosa.
const FILLER_SPEAKERS := ["agentes", "llanto"]
const NOTICE_MAX := 4  # avisos en fila (sin contar el que se ve)
const NOTICE_MIN_S := 2.0  # con otros esperando, cada aviso se ve al menos esto
const NOTICE_CAP_S := 5.0


class Line extends RefCounted:
	signal finished
	var id: String = ""
	var priority: int = 1
	var speaker: String = ""
	var text: String = ""
	var seconds: float = 0.0
	var bus: String = "Sala"
	var slot: String = ""
	var path: String = ""
	var on_done: Callable = Callable()
	var external: Node = null
	var free_on_drop: bool = false
	var queued_ms: int = 0
	var max_wait: float = 5.0
	var waited: float = 0.0
	var started_ms: int = -1
	var wall_end_ms: int = 0
	var read_left: float = 0.0
	var has_audio: bool = false
	var done: bool = false
	var result: String = ""  # dicha · interrumpida · vencida · descartada · aviso · en_pantalla · repetida
	var frame: int = 0
	var must: bool = true  # importante: no se pierde en silencio
	var group: String = ""  # la línea nueva del mismo grupo reemplaza a la anterior (el cliente del mismo contacto)
	var elsewhere: bool = false  # su texto ya se lee en otra parte (Kardex, la sesión de Haime): vencida no hace falta aviso
	var dedupe: bool = true


var current: Line = null
var queue: Array = []
var timeline: Array = []
var overlaps: int = 0
var overlap_log: Array = []  # [ms, "id1 + id2"] de cada solape (auditoría de los bots)
var lines_said: int = 0
var lines_dropped: int = 0
var lines_noticed: int = 0  # importantes que no pudieron sonar a tiempo y salieron como aviso de texto
var lines_merged: int = 0  # repetidas que no se apilaron
var lines_elsewhere: int = 0  # vencidas cuyo texto ya estaba en pantalla (el cliente en Kardex)
var lost_important: Array = []  # [ms, id, motivo]: importantes perdidas de verdad (debe quedar vacío)
var notices: Array = []  # avisos esperando: {speaker, text, seconds, must}
var notice_current: Dictionary = {}
var notice_log: Array = []  # [ms, hablante, texto, must] (auditoría)
var _notice_left: float = 0.0
var _notice_shown_s: float = 0.0
var _player: AudioStreamPlayer = null
var _fading: Array = []  # [player, tween]
var _hold_low: bool = false  # muerte en curso: solo SCREAMER
var _ducked: bool = false
var _duck_tween: Tween = null
var _duck_db: float = 0.0
var _was_multi: bool = false
var _log: bool = false
var _aclock: float = 0.0
var death_killer: String = ""  # quien te está matando: sus subtítulos (la frase gritada) pasan como SCREAMER
var _dup_frame: int = -1  # cuadro en que se descartó una voz repetida: su subtítulo del mismo cuadro tampoco entra
var _dup_speaker: String = ""
var _dup_bus: String = ""
var _last_external: Node = null  # el reproductor externo de la línea anterior (por si su cola sigue sonando)
var _last_external_free: bool = false
var _starting: Line = null  # la línea cuyo line_started se está emitiendo (ver cancel(): veto al empezar)
var lines_vetoed: int = 0  # cortadas por otro en el instante de empezar (la calibración de Haime calla a los demás)
## v0.3.2 (integración): voces vetadas al empezar que todavía no traían texto: [cuadro, hablante, bus, id, ms]. Quien pide
## la voz y emite el subtítulo justo después (PersonajesP5.say/pa) no ha perdido nada: el subtítulo entra enseguida como
## línea suelta y, si también lo vetan, sale como aviso. Solo si pasa un cuadro sin que llegue queda como perdida.
var _veto_wait: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = OS.get_cmdline_user_args().has("--voz-log")
	_player = AudioStreamPlayer.new()
	_player.name = "VozDirector"
	add_child(_player)
	EventBus.subtitle.connect(_on_subtitle)
	EventBus.death_sequence_started.connect(func(_c: String, k: String, _d: String) -> void:
		_hold_low = true
		death_killer = k
		stop_all("muerte"))
	EventBus.respawned.connect(func(_k: String) -> void:
		_hold_low = false
		death_killer = ""
		stop_all("respawn")  # el grito del asesino no sigue sonando ni queda su subtítulo al reaparecer en tu PC
		subtitle_shown.emit("", "", 0.0))
	EventBus.returned_to_menu.connect(func() -> void:
		_hold_low = false
		stop_all("menu")
		subtitle_shown.emit("", "", 0.0))
	EventBus.shift_started.connect(func() -> void: reset_audit())


func reset_audit() -> void:
	timeline.clear()
	overlaps = 0
	overlap_log.clear()
	lines_said = 0
	lines_dropped = 0
	lines_noticed = 0
	lines_merged = 0
	lines_elsewhere = 0
	lines_vetoed = 0
	lost_important.clear()
	_veto_wait.clear()
	notice_log.clear()


## Prioridad por hablante / carpeta (para quien no la dice).
static func priority_for(speaker: String, file: String = "") -> int:
	if file.begins_with("scr_") or file.ends_with("screamer"):
		return P.SCREAMER
	var s := speaker.to_lower()
	if s == "cliente" or s == "clientes":
		return P.CLIENTE
	if s in DIRECT_SPEAKERS:
		return P.DIRECTO
	if s == "agentes" or file.begins_with("trainer_gaaaa") or file == "trainer_risa":
		return P.BARK
	return P.AMBIENTE


## ¿Importante por defecto? Todo lo que no es un murmullo (BARK) ni de un hablante de relleno.
## «piensa» (lo que piensa tu agente) depende de la prioridad con que se pide: el monólogo del Training va como DIRECTO
## y sigue siendo importante; los ecos de la semana (RecuerdosSemana: ~10 s de voz la primera vez que te sientas en
## C-14, como AMBIENTE) son relleno. Como importantes nadie podía cortarlos: durante esos 10 s el primer cliente del
## turno se quedaba sin voz (su línea vencía en la cola), la calibración de Haime arrancaba con un hueco de 11-15 s y
## los avisos esperaban. Ahora los corta quien tiene más prioridad (un jefe, Haime, el cliente).
static func must_for(priority: int, speaker: String) -> bool:
	if priority <= P.BARK:
		return false
	var s := speaker.to_lower()
	if s == "piensa":
		return priority >= P.DIRECTO
	return not (s in FILLER_SPEAKERS)


## Pide una línea. Devuelve el Line (await line.finished).
func say(line_id: String, priority: int = -1, speaker: String = "", on_done: Callable = Callable(), opts: Dictionary = {}) -> Line:
	var l := Line.new()
	l.id = line_id
	l.speaker = speaker
	l.text = str(opts.get("text", ""))
	l.seconds = float(opts.get("seconds", 0.0))
	l.bus = str(opts.get("bus", "Sala"))
	l.priority = priority if priority >= 0 else priority_for(speaker, line_id.get_file())
	l.on_done = on_done
	l.external = opts.get("player", null) as Node
	l.free_on_drop = bool(opts.get("free_on_drop", l.external != null))
	l.must = bool(opts.get("must", must_for(l.priority, speaker)))
	if opts.has("max_wait") and float(opts["max_wait"]) <= 0.0 and not opts.has("must"):
		l.must = false  # «si no puede sonar ya, que no suene» (los murmullos): relleno
	l.max_wait = float(opts.get("max_wait", (MUST_WAIT if l.must else MAX_WAIT).get(l.priority, 5.0)))
	l.group = str(opts.get("group", ""))
	l.elsewhere = bool(opts.get("elsewhere", false))
	l.dedupe = bool(opts.get("dedupe", true))
	l.queued_ms = now_ms()
	l.frame = Engine.get_process_frames()
	if line_id.begins_with("voces/") and l.external == null:
		l.slot = str(opts.get("slot", line_id))
		l.path = AudioManager.voice_path(l.slot)
	_submit(l)
	return l


## Línea que reproduce un reproductor propio (3D): murmullos, Shero en persona, el llanto del baño.
func say_external(player: Node, line_id: String, priority: int, speaker: String = "", opts: Dictionary = {}) -> Line:
	var o := opts.duplicate()
	o["player"] = player
	return say(line_id, priority, speaker, Callable(), o)


## Línea de solo texto (un personaje que habla sin voz grabada, o un texto de ambiente con `must: false`).
## opts: priority, must, group, elsewhere, max_wait.
func text(speaker: String, txt: String, seconds: float = 0.0, opts: Dictionary = {}) -> Line:
	if txt == "":
		return null
	var o := opts.duplicate()
	o["text"] = txt
	o["seconds"] = seconds
	return say("sub:" + speaker, int(opts.get("priority", -1)), speaker, Callable(), o)


## ¿Hay alguna voz sonando o esperando de prioridad >= p? (los murmullos opcionales ni lo intentan)
func busy(p: int = 0) -> bool:
	if current != null and current.priority >= p:
		return true
	for q in queue:
		if (q as Line).priority >= p:
			return true
	return false


## ¿Suena o espera alguna línea de este hablante (carpeta de voz o nombre)? Para las secuencias con guion que dicen
## una línea tras otra (la revisión de Don Fermín): la siguiente se pide cuando la anterior terminó.
func speaker_busy(speaker: String) -> bool:
	var s := _canon(speaker)
	if current != null and _canon(current.speaker) == s:
		return true
	for q in queue:
		if _canon((q as Line).speaker) == s:
			return true
	return false


## Línea de solo texto (sin voz ni reproductor).
static func _is_silent(l: Line) -> bool:
	return l.path == "" and l.external == null and not l.has_audio


## Relleno de solo texto (un anuncio de ambiente): no retrasa a nadie.
static func _is_soft_text(l: Line) -> bool:
	return _is_silent(l) and not l.must


func _submit(l: Line) -> void:
	if _hold_low and l.priority < P.SCREAMER:
		_drop(l, "descartada")
		return
	# La misma línea pedida otra vez mientras suena o espera: no se apila (Rasec: «¡Eso! Más fuerte» ×5).
	if l.dedupe and l.priority < P.SCREAMER and _is_duplicate(l):
		lines_merged += 1
		_dup_frame = l.frame
		_dup_speaker = _canon(l.speaker)
		_dup_bus = l.bus
		if _log:
			print("[voz] %s = %s (repetida)" % [Loc.mmss(now_ms() / 1000.0), l.id])
		if l.external != null and is_instance_valid(l.external) and l.free_on_drop:
			l.external.queue_free()
		_end(l, "repetida")
		return
	# La línea nueva de un grupo deja sin efecto a las que esperaban de ese grupo (el cliente ya pasó al nodo siguiente).
	if l.group != "":
		for q in queue.duplicate():
			if (q as Line).group == l.group:
				queue.erase(q)
				_end_quiet(q as Line, "interrumpida")
	if current == null:
		_start(l)
		return
	var c := current
	# Un subtítulo sin voz del mismo hablante reemplaza al suyo (el cliente pasa a la línea siguiente).
	var replace := l.speaker != "" and l.speaker == c.speaker and not l.has_audio and not c.has_audio and l.path == "" and l.external == null and c.path == "" and c.external == null
	# v0.3.2 (Training): la VOZ de un hablante reemplaza a SU subtítulo suelto en curso. Por los parlantes y en Rooms el
	# texto sale primero (con el ding-dong) y la voz 0,65 s después: sin esto la voz esperaba 5 s detrás de su propio
	# subtítulo y, con líneas seguidas (la sesión de coaching), se vencía sin sonar.
	var own_sub := _is_voiced(l) and _is_loose_sub(c) and _canon(c.speaker) == _canon(l.speaker)
	var same_group := l.group != "" and l.group == c.group
	# Una importante en curso no se corta (solo un screamer, su reemplazo o su grupo); un relleno sí, por prioridad;
	# un relleno de solo texto, por cualquier voz o línea importante.
	var cuts := false
	if l.priority == P.SCREAMER or replace or own_sub or same_group:  # el screamer más nuevo siempre entra
		cuts = true
	elif not c.must:
		cuts = l.priority > c.priority or (_is_soft_text(c) and (_is_voiced(l) or l.must))
	if cuts:
		if own_sub and l.text == "":
			l.text = c.text  # hereda el texto que ya se estaba viendo (la voz llegó después que su subtítulo)
			l.seconds = c.seconds
		_interrupt(c)
		_start(l)
		return
	if _is_soft_text(l):
		# Un texto de ambiente con el canal ocupado: sale como aviso (si hay sitio) y no espera a nadie.
		_soft_to_notice(l)
		return
	if l.max_wait <= 0.0 and not l.must:
		_drop(l, "vencida")
		return
	queue.append(l)
	queue.sort_custom(func(a: Line, b: Line) -> bool: return a.priority > b.priority if a.priority != b.priority else a.queued_ms < b.queued_ms)


## ¿La misma línea ya suena o espera? Mismo id y hablante; si las dos traen texto, el mismo texto.
func _is_duplicate(l: Line) -> bool:
	var cands: Array = ([current] if current != null else []) + queue
	for c in cands:
		var x := c as Line
		if x.id != l.id or _canon(x.speaker) != _canon(l.speaker):
			continue
		if _is_silent(l) and l.external == null and l.slot == "":
			if x.text == l.text:  # texto suelto: solo si dice lo mismo
				return true
			continue
		if l.text == "" or x.text == "" or x.text == l.text:
			return true
	return false


func _start(l: Line) -> void:
	current = l
	l.started_ms = now_ms()
	_silence_tails(l)
	var audio_len := 0.0
	if l.external != null:
		if is_instance_valid(l.external) and l.external.is_inside_tree():
			var st: Variant = l.external.get("stream")
			audio_len = (st as AudioStream).get_length() if st is AudioStream else 2.0
			l.external.call("play")
			l.has_audio = true
		else:
			l.external = null
	elif l.path != "":
		var stream: AudioStream = AudioManager.call("_load_mode", l.path, false)
		if stream != null:
			_player.stop()
			_player.bus = l.bus if AudioServer.get_bus_index(l.bus) >= 0 else "Sala"
			_player.volume_db = AudioManager.gain_db(l.slot)
			_player.stream = stream
			_player.play()
			audio_len = stream.get_length()
			l.has_audio = true
		else:
			AudioManager.call("_log_missing", l.slot)
	var read := 0.0
	if l.text != "":
		var want := l.seconds if l.seconds > 0.0 else clampf(2.0 + l.text.length() * 0.045, 2.5, 7.0)
		read = minf(want, clampf(1.2 + l.text.length() * 0.04, 1.5, 5.0)) if l.has_audio else want
		subtitle_shown.emit(l.speaker, l.text, maxf(want, audio_len))
	l.wall_end_ms = l.started_ms + int(audio_len * 1000.0) + (120 if l.has_audio else 0)
	l.read_left = read
	if l.has_audio:
		_duck(true)
	lines_said += 1
	timeline.append([l.started_ms, -1, l.id, l.priority, l.speaker])
	if timeline.size() > 4000:
		timeline.pop_front()
	if _log:
		print("[voz] %s ▶ %s (p%d%s, %s) %s" % [Loc.mmss(now_ms() / 1000.0), l.id, l.priority, "" if l.must else "·relleno", l.speaker, l.text.left(60)])
	_starting = l
	line_started.emit(l.id, l.speaker, l.priority)
	_starting = null


## Antes de arrancar una línea se corta cualquier resto de la anterior (su hora ya pasó): el reproductor propio si la
## nueva va por uno externo, y el externo de la línea anterior si todavía suena.
func _silence_tails(l: Line) -> void:
	if l.external != null and _player != null and _player.playing:
		_player.stop()
	if _last_external != null and is_instance_valid(_last_external) and _last_external != l.external:
		if bool(_last_external.call("is_playing")):
			_last_external.call("stop")
			if _last_external_free:
				_last_external.queue_free()
	_last_external = null


## Pega un subtítulo a la voz pedida en este mismo cuadro (PersonajesP5.say: voz sin texto + subtítulo enseguida).
func _attach_text(l: Line, p_text: String, seconds: float) -> void:
	l.text = p_text
	l.seconds = seconds
	if l.slot != "" and l == current and Engine.get_process_frames() - l.frame <= 1:
		var best := AudioManager.voice_slot(l.slot.get_slice("/", 1), l.slot.get_slice("/", 2), p_text)
		if best != l.slot:
			l.slot = best
			l.path = AudioManager.voice_path(best)
			AudioManager.last_voice["slot"] = best
			AudioManager.last_voice["path"] = l.path
			AudioManager.last_voice["had_text"] = true
			timeline.pop_back()
			lines_said -= 1
			_start(l)
			return
	if l == current:
		var want := seconds if seconds > 0.0 else 3.0
		l.read_left = maxf(l.read_left, minf(want, 3.0))
		subtitle_shown.emit(l.speaker, p_text, want)


func _on_subtitle(speaker: String, p_text: String, seconds: float) -> void:
	if p_text == "":
		return
	var fr := Engine.get_process_frames()
	# El texto de una voz que vetaron al empezar (pedida en este mismo cuadro sin texto): ya no cuenta como perdida.
	for i in range(_veto_wait.size() - 1, -1, -1):
		var vw: Array = _veto_wait[i]
		if fr - int(vw[0]) <= 1 and (str(vw[1]) == _canon(speaker) or (speaker == "parlantes" and str(vw[2]) == "Parlantes")):
			_veto_wait.remove_at(i)
	# Durante la muerte, los subtítulos de quien te mata (la frase gritada, «REC») son del screamer y pasan; los demás
	# (un compañero, Ezlaki) se descartan como sus voces.
	var scr := _hold_low and death_killer != "" and _canon(speaker) == _canon(death_killer)
	# Un aviso (Ezlaki, sistema): no es habla, no ocupa el canal de las voces ni se pega a la voz de otro.
	if not scr and speaker.to_lower() in NOTICE_SPEAKERS:
		notice(speaker, p_text, seconds)
		return
	# ¿Es el texto de una voz de este mismo cuadro sin subtítulo?
	var cands: Array = ([current] if current != null else []) + queue
	for c in cands:
		var l := c as Line
		# Mismo hablante («clientes»/«cliente», «agentes»/«comp»…) o la voz pedida en este mismo cuadro sin texto (no
		# un murmullo: los murmullos no llevan subtítulo y el de otro no es suyo).
		var same := l.speaker == speaker or _canon(l.speaker) == _canon(speaker) or (speaker == "parlantes" and l.bus == "Parlantes") or (fr == l.frame and l.priority > P.BARK)
		if same and l.text == "" and fr - l.frame <= 1 and (l.slot != "" or l.external != null):
			_attach_text(l, p_text, seconds)
			return
		if l.text == p_text and fr - l.frame <= 1:
			return  # play_voice ya trajo este texto
	# El subtítulo de una voz que no entró por repetida (pedida en este mismo cuadro): tampoco entra.
	if fr == _dup_frame and (_canon(speaker) == _dup_speaker or (speaker == "parlantes" and _dup_bus == "Parlantes")):
		_dup_frame = -1  # uno por repetida
		return
	say("sub:" + speaker, P.SCREAMER if scr else priority_for(speaker), speaker, Callable(), {"text": p_text, "seconds": seconds})


## Línea con sonido propio (un archivo de voz o un reproductor externo).
static func _is_voiced(l: Line) -> bool:
	return l.path != "" or l.external != null


## Subtítulo suelto (EventBus.subtitle sin voz): solo texto.
static func _is_loose_sub(l: Line) -> bool:
	return l.id.begins_with("sub:") and l.path == "" and l.external == null and not l.has_audio


func _voice_queued_for(speaker: String) -> bool:
	for q in queue:
		if _is_voiced(q as Line) and _canon((q as Line).speaker) == _canon(speaker):
			return true
	return false


static func _canon(s: String) -> String:
	var c := s.to_lower().trim_suffix("s")
	return "comp" if c in ["agente", "compañero", "companero"] else c


## Reloj del audio (ms): el tiempo sin escalar del juego. Va con el sonido en los tres casos: a 1x es el tiempo real,
## con Engine.time_scale (bots a 8x) el audio sigue a velocidad real, y con --write-movie (cuadros fijos) el audio se
## mezcla por cuadro. Con el reloj de pared, grabando a 1 cuadro/s la línea «terminaba» a los 2 cuadros y la siguiente
## la cortaba.
func now_ms() -> int:
	return int(_aclock * 1000.0)


func _process(delta_scaled: float) -> void:
	var delta := delta_scaled / maxf(Engine.time_scale, 0.001)
	_aclock += delta
	# Cola: las que esperan demasiado vencen (relleno) o salen como aviso de texto (importantes).
	for q in queue.duplicate():
		var l := q as Line
		l.waited += delta
		if l.waited > l.max_wait:
			_expire(l)
	if current != null:
		var c := current
		c.read_left -= delta
		var audio_done := now_ms() >= c.wall_end_ms
		if c.external != null:
			if not is_instance_valid(c.external) or not bool(c.external.call("is_playing")):
				audio_done = true
			elif audio_done and now_ms() < c.wall_end_ms + TAIL_MAX_MS:
				audio_done = false  # su reproductor externo sigue sonando: manda la cola del audio
		elif audio_done and c.has_audio and _player.playing and now_ms() < c.wall_end_ms + TAIL_MAX_MS:
			# v0.3.2-beta (integración): manda la cola del audio. Con el hilo de audio atrasado (máquina cargada) el
			# reproductor va detrás del reloj y la línea «terminaba» con 0,2-0,4 s todavía sonando: la siguiente, si
			# era de un reproductor externo (Shero en persona, 3D), se le montaba encima (solape en h2_lunch).
			audio_done = false
		if audio_done and c.read_left <= 0.0:
			_end(c, "dicha")
	while current == null and not queue.is_empty():
		var nxt := queue.pop_front() as Line
		if _is_loose_sub(nxt) and _voice_queued_for(nxt.speaker):
			_end_quiet(nxt, "descartada")  # su voz ya espera en la cola y trae el mismo texto: el subtítulo suelto sobra
			continue
		_start(nxt)
	if current == null and _ducked:
		_duck(false)
	if not _veto_wait.is_empty():
		var frn := Engine.get_process_frames()
		for i in range(_veto_wait.size() - 1, -1, -1):
			var vw: Array = _veto_wait[i]
			if frn - int(vw[0]) > 1:  # su subtítulo no llegó: importante y sin texto, perdida de verdad
				lost_important.append([int(vw[4]), str(vw[3]), "vetada al empezar, sin texto"])
				if lost_important.size() > 100:
					lost_important.pop_front()
				_veto_wait.remove_at(i)
	_tick_notices(delta)
	_audit()


## Una línea que esperó demasiado en la cola.
func _expire(l: Line) -> void:
	queue.erase(l)
	if not l.must:
		_drop(l, "vencida")
		return
	if l.elsewhere:
		lines_elsewhere += 1  # su texto ya está en pantalla (el cliente, en Kardex): no hace falta más
		if _log:
			print("[voz] %s ✓ %s (vencida; su texto ya está en pantalla)" % [Loc.mmss(now_ms() / 1000.0), l.id])
		_free_external(l)
		_end(l, "en_pantalla")
		return
	if l.text != "":
		lines_noticed += 1
		if _log:
			print("[voz] %s ✉ %s (no pudo sonar en %.0f s: sale como aviso)" % [Loc.mmss(now_ms() / 1000.0), l.id, l.max_wait])
		notice(l.speaker, l.text, clampf(2.0 + l.text.length() * 0.045, 3.0, NOTICE_CAP_S), true)
		_free_external(l)
		_end(l, "aviso")
		return
	# Importante y sin texto que mostrar: sigue esperando (hasta 3 veces su plazo); después se pierde y queda anotada.
	if l.waited <= l.max_wait * 3.0:
		queue.append(l)
		queue.sort_custom(func(a: Line, b: Line) -> bool: return a.priority > b.priority if a.priority != b.priority else a.queued_ms < b.queued_ms)
		return
	lost_important.append([now_ms(), l.id, "vencida sin texto"])
	if lost_important.size() > 100:
		lost_important.pop_front()
	_drop(l, "vencida")


func _free_external(l: Line) -> void:
	if l.external != null and is_instance_valid(l.external) and l.free_on_drop:
		l.external.queue_free()


func _end(l: Line, how: String) -> void:
	if l.done:
		return
	l.done = true
	l.result = how
	if current == l:
		current = null
	if how == "dicha" and l.external != null and is_instance_valid(l.external):
		_last_external = l.external  # si su cola sigue sonando cuando arranque la siguiente, se corta ahí
		_last_external_free = l.free_on_drop
	for i in range(timeline.size() - 1, -1, -1):
		if timeline[i][2] == l.id and int(timeline[i][1]) < 0 and int(timeline[i][0]) == l.started_ms:
			timeline[i][1] = now_ms()
			break
	if l.on_done.is_valid():
		l.on_done.call()
	l.finished.emit()
	finished.emit(l.id)


## Termina una línea de la cola sin contarla como descartada (la reemplazó la siguiente de su grupo, o sobraba).
func _end_quiet(l: Line, how: String) -> void:
	_free_external(l)
	if _log:
		print("[voz] %s ⤫ %s (%s: ya no hace falta)" % [Loc.mmss(now_ms() / 1000.0), l.id, how])
	_end(l, how)


func _interrupt(l: Line) -> void:
	if l.external != null and is_instance_valid(l.external):
		_fade_out(l.external, l.free_on_drop)  # los temporales (Shero en persona, murmullos) se liberan
	elif l.has_audio:
		_fade_out(_player, false)
	_end(l, "interrumpida")


func _drop(l: Line, how: String) -> void:
	lines_dropped += 1
	_free_external(l)
	if _log:
		print("[voz] %s ✗ %s (%s%s)" % [Loc.mmss(now_ms() / 1000.0), l.id, how, "" if l.must else " · relleno"])
	_end(l, how)


## Fundido de 80 ms y corte. El reproductor propio se reemplaza para que la línea nueva no espere al fundido.
## El fundido es del propio reproductor (p.create_tween()): si su nodo se libera antes (Shero en persona al terminar la
## persecución, el piso al volver al menú) el fundido muere con él. Antes era del director y su lambda capturaba al
## reproductor: «Lambda capture at index 0 was freed» en la consola (v0.3.2-beta1-fix2 lo arregló guardando el id del
## reproductor; aquí ni siquiera hay lambda: mismo efecto).
func _fade_out(p: Node, free_after: bool) -> void:
	if p == _player:
		var old := _player
		_player = AudioStreamPlayer.new()
		_player.name = "VozDirector"
		add_child(_player)
		old.name = "VozFundido"
		free_after = true
		p = old
	if not is_instance_valid(p) or not p.is_inside_tree():
		if is_instance_valid(p):
			p.call("stop")
			if free_after:
				p.queue_free()
		return
	var tw := p.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(p, "volume_db", -40.0, FADE_S)
	tw.tween_callback(Callable(p, "stop"))
	if free_after:
		tw.tween_callback(Callable(p, "queue_free"))


func stop_all(why: String = "") -> void:
	for q in queue.duplicate():
		_drop(q as Line, "descartada")
	queue.clear()
	if current != null:
		_interrupt(current)
	if why in ["muerte", "menu", "respawn"]:
		clear_notices()
	if why != "" and _log:
		print("[voz] corte: " + why)


## v0.3.2 (Haime): corta UNA línea, la que suena (fundido de 80 ms) o una que espera en la cola. Para quien lleva su
## propio ritmo: la calibración corta la cola de silencio de cada toma (la siguiente entra apenas termina de hablar),
## Haime corta la grabación de tu contacto con su frase y, con el tiempo acelerado (pruebas y bots), la sesión sigue
## su guion sin dejar líneas vencidas en la cola. No cuenta como descartada.
##
## v0.3.2-core · VETO AL EMPEZAR. Quien escucha `line_started` y cancela ahí mismo la línea que acaba de arrancar le
## quita la palabra a OTRO (la calibración de Haime: mientras dura, nadie más habla). Esa línea no llegó a oírse, así
## que, si era importante, no se pierde: su texto sale como aviso arriba (una convocatoria de Shero o de Rasec que cae
## en plena calibración se lee igual); si su texto ya está en otra parte (`elsewhere`) no hace falta; si no tiene
## texto queda anotada en `lost_important`. El relleno se calla sin más. Cancelar una línea propia a medias (los demás
## usos de cancel) no cambia.
func cancel(l: Line, why: String = "") -> void:
	if l == null or l.done:
		return
	if l == current:
		var vetoed := l == _starting
		_interrupt(l)
		if vetoed:
			_vetoed(l)
	else:
		queue.erase(l)
		if l.external != null and is_instance_valid(l.external) and l.free_on_drop:
			l.external.queue_free()
		_end(l, "interrumpida")
	if why != "" and _log:
		print("[voz] %s ✂ %s (%s)" % [Loc.mmss(now_ms() / 1000.0), l.id, why])


func _vetoed(l: Line) -> void:
	lines_vetoed += 1
	lines_said = maxi(lines_said - 1, 0)  # no llegó a decirse
	if l.text != "":
		subtitle_shown.emit("", "", 0.0)  # su subtítulo no se queda en pantalla sin voz
	if not l.must or l.elsewhere or _hold_low:
		return
	if l.text == "":
		_veto_wait.append([Engine.get_process_frames(), _canon(l.speaker), l.bus, l.id, now_ms()])
		return
	lines_noticed += 1
	l.result = "aviso"
	if _log:
		print("[voz] %s ✉ %s (le quitaron la palabra al empezar: sale como aviso)" % [Loc.mmss(now_ms() / 1000.0), l.id])
	notice(l.speaker, l.text, clampf(2.0 + l.text.length() * 0.045, 3.0, NOTICE_CAP_S), true)


# --- Avisos de texto (no son habla) -----------------------------------------------------------------------

## Un aviso: el resumen de un DM de Ezlaki, «Llamando a Marko…», o el texto de una línea importante que no pudo sonar
## a tiempo (`must`). Uno a la vez; los que esperan de más (Ezlaki) ceden: siguen en el chat.
func notice(speaker: String, p_text: String, seconds: float = 4.0, must: bool = false) -> void:
	if p_text == "" or _hold_low:  # muriendo no hay avisos
		return
	if str(notice_current.get("text", "")) == p_text:
		return
	for n in notices:
		if str((n as Dictionary).get("text", "")) == p_text:
			return
	notices.append({"speaker": speaker, "text": p_text, "seconds": clampf(seconds if seconds > 0.0 else 4.0, 1.5, NOTICE_CAP_S), "must": must})
	while notices.size() > NOTICE_MAX:
		var dropped := false
		for i in notices.size():
			if not bool((notices[i] as Dictionary).get("must", false)):
				notices.remove_at(i)  # el más viejo que no es importante
				dropped = true
				break
		if not dropped:
			break  # todos importantes: ninguno se tira
	if notice_current.is_empty():
		_next_notice()


func clear_notices() -> void:
	notices.clear()
	if not notice_current.is_empty():
		notice_current = {}
		_notice_left = 0.0
		notice_shown.emit("", "", 0.0, false)


func _next_notice() -> void:
	if notices.is_empty():
		if not notice_current.is_empty():
			notice_current = {}
			notice_shown.emit("", "", 0.0, false)
		return
	notice_current = notices.pop_front()
	_notice_left = float(notice_current["seconds"])
	_notice_shown_s = 0.0
	notice_log.append([now_ms(), str(notice_current["speaker"]), str(notice_current["text"]), bool(notice_current["must"])])
	if notice_log.size() > 400:
		notice_log.pop_front()
	if _log:
		print("[voz] %s ✉ aviso (%s%s) %s" % [Loc.mmss(now_ms() / 1000.0), str(notice_current["speaker"]), ", importante" if bool(notice_current["must"]) else "", str(notice_current["text"]).left(70)])
	notice_shown.emit(str(notice_current["speaker"]), str(notice_current["text"]), _notice_left, bool(notice_current["must"]))


func _tick_notices(delta: float) -> void:
	if notice_current.is_empty():
		if not notices.is_empty():
			_next_notice()
		return
	_notice_left -= delta
	_notice_shown_s += delta
	# con otros esperando, el que se ve cede en cuanto cumple su mínimo
	if _notice_left <= 0.0 or (not notices.is_empty() and _notice_shown_s >= NOTICE_MIN_S):
		_next_notice()


## Un texto de ambiente (relleno, sin voz) que llegó con el canal ocupado: aviso si hay sitio; si no, se pierde.
func _soft_to_notice(l: Line) -> void:
	if notices.size() < 2 and l.text != "":
		notice(l.speaker, l.text, minf(l.seconds if l.seconds > 0.0 else 4.0, 4.0))
		_end(l, "aviso")
	else:
		_drop(l, "vencida")


# --- Ducking ---------------------------------------------------------------------------------------

func _duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, DUCK_DB if on else 0.0, 0.12 if on else 0.4)
	AudioManager.set("sfx_duck_db", SFX_DUCK_DB if on else 0.0)


func _set_duck(db: float) -> void:
	_duck_db = db
	for bus in ["Musica", "Ambiente"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		for e in AudioServer.get_bus_effect_count(idx):
			var fx := AudioServer.get_bus_effect(idx, e)
			if fx is AudioEffectAmplify and fx.resource_name == "Duck":
				(fx as AudioEffectAmplify).volume_db = db


func ducked() -> bool:
	return _ducked


# --- Auditoría ----------------------------------------------------------------------------------------

## Resumen del turno para los bots: «voces N · solapes N · descartadas/vencidas N (relleno) · a texto N · repetidas N ·
## importantes perdidas N».
func audit_line() -> String:
	return "voces %d · solapes %d · descartadas/vencidas %d · a texto %d · repetidas %d · importantes perdidas %d" % [lines_said, overlaps, lines_dropped, lines_noticed, lines_merged, lost_important.size()]


## Voces sonando ahora mismo: el reproductor del director, los de AudioManager (no deberían sonar fuera de él) y el
## externo de la línea en curso. Más de una = solape.
func voices_playing() -> int:
	var n := 0
	if _player != null and _player.playing:
		n += 1
	for v in (AudioManager.get("_voice_players") as Dictionary).values():
		if (v as AudioStreamPlayer).playing:
			n += 1
	if current != null and current.external != null and is_instance_valid(current.external) and bool(current.external.call("is_playing")):
		n += 1
	return n


func _audit() -> void:
	var multi := voices_playing() > 1
	if multi and not _was_multi:
		overlaps += 1
		var what := "%s (p%d)" % [current.id, current.priority] if current != null else "?"
		overlap_log.append([now_ms(), "%d voces · actual %s · AudioManager %s" % [voices_playing(), what, str(AudioManager.get("last_voice").get("slot", ""))]])
		if overlap_log.size() > 50:
			overlap_log.pop_front()
		print("[voz] SOLAPE %s" % str(overlap_log[-1][1]))
	_was_multi = multi

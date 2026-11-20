class_name QaFeedback
extends Node
## Haime (QA), PLAN §2 #32-34 y #76 (cerebro persistente; el actor de la sala es haime.gd en el piso 2).
## - Escucha TODOS los contactos (contact_outcome). Uno es "malo" si termina molesto, si es un caso BO mal
##   resuelto (bo_miss) o si dejó marcas de QA (c._qa: opciones con "qa" de los árboles, motivos del caso).
## - Tras un contacto malo te llama en 5-15 min de juego (nunca a menos de 40 min del feedback anterior, ni
##   durante un contacto ni durante otra sesión): DM en dm:haime + parlantes; autoriza Coaching y la sala
##   de calibración (Metrics.authorize(COACHING, "qa", "sala_calibracion")). Hay que poner AUX Coaching e ir
##   a la sala de calibración (piso 2, antigua sala de descanso) y sentarse frente a él.
## - Si no llegas: 5:00 DM "Te estoy esperando" → 8:00 muerte `qa_inasistencia` (screamer de Haime donde
##   estés). No cuenta como uno de sus 3 feedbacks.
## - Sesión (45-75 s reales, reloj "feedback"): Discipline.freeze(true, "feedback") — nadie más interviene —, repite
##   tu contacto y te da sus "oportunidades de mejora" hechas con TUS marcas de QA (una por marca, 1..4).
## - v0.3.1 (D2/F9): en Fácil y Normal el 4.º feedback del turno termina en su screamer (`calibracion_final`) apenas
##   terminan las oportunidades; el 3.º es la última advertencia (cara al máximo, set_severity(3), y «La próxima es
##   la calibración de la muerte»). En Difícil y Turno real mata el 3.º (qa_haime.json/max_por_turno_dificil).
## - v0.3.1 (F4): al sentarte frente a él cuando te llamó, Haime te pone en Coaching («Te pongo en Coaching yo»):
##   cuenta como llegar a tiempo. La silla no tiene PC.
## - v0.3.1 (F6): desde la 2.ª línea puedes pararte ([E]); pararte cierra la sesión: si ya escuchaste las 3
##   oportunidades cuenta como dada; si no, «te fuiste a mitad»: vuelve a llamarte con el plazo ya en el aviso.
##   Cama musical propia (musica/feedback_haime_loop; si falta, silencio) y Haime te mira (C5).
## - v0.3.1 (F17, C12): tras morir por calibracion_final o qa_inasistencia se descarta el contacto que causó la
##   llamada (y los pendientes de antes), los feedbacks quedan en max−1 y hay 60 min de juego antes de la siguiente
##   llamada, que además exige un contacto malo NUEVO. Nunca llama dentro de la gracia tras reaparecer.
## - El punto REC (QaRec) aparece en 1 de cada 3 contactos con tu puntaje en vivo y, cuando te llamó, te
##   sigue por la pantalla con la cuenta regresiva.
## - v0.3.2 (Joan: «que causen suspenso, tensión y miedo… más agresivos, no repetitivos y no tan lentos»): la sesión
##   es una lista de beats armada por HaimeGuion.build_session (estructura al azar, memoria por partida, 48-70 s):
##   la puerta se cierra con seguro, tus errores se marcan en rojo uno por uno (pluma, el puntaje baja, la luz baja),
##   el auricular reproduce tu contacto distorsionado, preguntas de 3-5 s con teclas 1-4 (tarde o mal = más enojo),
##   silencios demasiado largos con salto, latido que crece, REC que late. 1.ª fría · 2.ª golpea la mesa, te corta y te
##   hace repetir el guion · 3.ª (advertencia) en tu cara, cara al máximo, susurros, te quita el auricular · 4.ª mata.
##   Subtítulo = voz: cada línea hablada usa el texto de su voz (HaimeVoz, data/haime_voz.json), sin marcadores.
##   No llama en el lunch (Discipline.is_lunch_immune) y su plazo se detiene mientras dura.
## - v0.3.2 (ritmo y voces): toda línea de la sesión va por el VoiceDirector (una voz a la vez, sin solapes) y la sesión
##   lleva su reloj (`clock`, s reales a 1x): cada línea dura hasta que Haime termina de HABLAR (HaimeVoz.talk; la cola de
##   silencio de la toma se corta y entra la siguiente), Haime corta la grabación de tu contacto con su frase, los errores
##   de más van en ráfaga y nada pasa de ~1,5 s sin que ocurra algo (pluma, luz, silla, golpe). `timeline` y `pacing()`
##   lo miden (h2_ritmo). 1.ª y 2.ª: 40-55 s (HaimeGuion.LIMITS).
## - v0.3.2 (Joan: «que la última calibración sea aún más antes de matarte»; «que su calibración sea muy terrorífica y te
##   da la idea que morirás y justo te mata ahí»): la última advertencia (46-60 s) y la fatal (47-69 s) son los picos.
##   Advertencia: más calmado y frío que nunca (sin golpes ni gritos), dos vueltas de llave, la sala más oscura, empieza
##   sentado y se va acercando (de pie, en tu cara, detrás de ti), recuerda tus calibraciones anteriores de la partida
##   (`historial` en haime_memoria.json: errores, respuestas, si te fuiste, si ya te mató, si le mentiste), te corta la
##   respuesta sin segunda oportunidad, te pone tu propia voz (tu saludo) en el auricular, deja de anotar, te quita el
##   auricular desde atrás y termina diciéndote sin gritar que no va a haber otra. Fatal: empieza casi normal (tu puntaje
##   ya está escrito), calibra de verdad con preguntas que ya no importan, las luces de la sala mueren una por una, y
##   termina de pie a su lado de la mesa, las manos sobre ella, solo con la luz roja del REC: en el cuadro en que termina
##   «Cero sobre cien. Te voy a calibrar.» pide la muerte (Checkpoints.request_death("calibracion_final", "", "haime")):
##   esa es la pose de la que salta el screamer («salto_mesa»).
## - v0.3.2 (dirección, tras verlas en pantalla y jugarlas): la oscuridad de la advertencia y la fatal es de la sala (las
##   luces de verdad, también las de afuera que la alcanzan; haime.gd), no del velo de la pantalla; en la fatal las luces
##   mueren una por una (la claridad de afuera, la luz de tu lado y, al final, el tubo del techo: lo apaga él) y con cada
##   una se apaga un poco más el ambiente del piso y el tubo zumba peor, hasta quedar solo el rojo del REC y el latido;
##   en ese apagón el velo de la pantalla se va (la última frase y la muerte tienen la misma imagen). Haime usa los clips
##   del paquete de animación (se levanta despacio, de pie se apoya en la mesa mientras contestas, golpea con el puño);
##   en la fatal la pluma siempre deja de sonar. Su voz se enfría: en la advertencia y la fatal cada línea suya suena
##   más grave y lenta (_apply_pitch: el reproductor del VoiceDirector a HaimeGuion.voice_pitch(nivel) solo mientras
##   habla él en la sesión). La memoria de la partida guarda también tus tardanzas
##   (llegar después del «Te estoy esperando») y tu frase cuando le mientes por Ezlaki (IABrain.replied): la pantalla te
##   la muestra. En la fatal no te puedes levantar (te paras y vuelves a estar sentado). Al pedir la muerte la sala y
##   Haime quedan como están (hold_for_death) hasta reaparecer: el screamer del paquete de muertes sale de esa pose.
## - v0.3.2-core4 (Joan: «me paré y me volví a sentar y la calibración empezó de nuevo desde el principio. Eso puede
##   explotarse; debe continuar donde se quedó»): irte a mitad ya no reinicia nada. La sesión queda guardada (`_paused`:
##   el guion, el beat en que ibas, el enojo, el puntaje, la luz, tus respuestas) y al volver a sentarte Haime echa el
##   seguro otra vez, te dice «Llegaste. Faltaban unos minutos. Los conté.» y sigue en el MISMO beat, con el mismo
##   enojo; volver no le quita tiempo a la sesión (su reloj sigue donde iba). Pararte solo «da» la sesión cuando ya no
##   queda más que el cierre (antes bastaba con haber oído las oportunidades: se saltaba lo que viniera después). En la
##   fatal no te puedes levantar (paquete de Haime) y «Reiniciar contacto» no vale durante una calibración.
## Estado con checkpoint: Discipline.counters p5_qa_feedbacks, p5_qa_ultimo, p5_qa_pend.

enum State { LIBRE, PENDIENTE, LLAMADO, SESION }
## Luz al sentarte, por nivel: cuánto baja la sala (set_dim) y cuánto llega de las luces de afuera (set_outside).
## La fatal: el tubo del techo casi no da (enfermo), y lo que deja ver es la claridad de afuera y la luz de tu lado
## (relleno, absoluto: no baja con el tubo). Mueren en ese orden, una por una; el tubo lo apaga él.
const LIGHT_START: Array[float] = [0.0, 0.0, 0.0, 0.6, 0.84]
const OUTSIDE_START: Array[float] = [1.0, 1.0, 1.0, 0.15, 0.26]
const FILL_START: Array[float] = [1.0, 1.0, 1.0, 1.0, 0.47]
const LIGHT_START_LIGHT := 0.66  # la fatal en Modo liviano: el tubo empieza aquí…
const LIGHT_STEP_LIGHT := 0.09  # …y baja esto con cada luz que muere (0,66 → 0,75 → 0,84 → apagado)

var hub: PersonajesP5 = null
var state: int = State.LIBRE
var call_at: float = INF  # reloj de juego en que llamará
var called_at: float = 0.0
var calling: Dictionary = {}  # el contacto malo por el que llamó
var n_call: int = 0
var noshow_warned: bool = false
var coaching_hint_given: bool = false
var monitored: bool = false
var contacts_seen: int = 0
var rec: QaRec = null
var ui: FeedbackUI = null
var session_log: Array[String] = []  # líneas dichas en la última sesión (pruebas)
var session_texts: Array[String] = []  # v0.3.1: su texto (el guion de HaimeGuion no está en lineas_haime)
var heard_opportunities: int = 0  # oportunidades dichas en la sesión en curso (F6)
var session_opportunities: int = 3  # oportunidades del guion de la sesión en curso (HaimeGuion, 1..4)
## v0.3.1 (F17/F20, bucle de la calibración final): Haime mata como mucho MAX_KILLS veces por turno; después solo
## advierte. kills_shift sobrevive al respawn (el checkpoint lo trae también en p5_qa_muertes).
const MAX_KILLS := 2
var kills_shift: int = 0
var last_session_end: String = ""  # "dada" | "a_mitad" | "muerte" | "fatal" (pruebas)
var _music: AudioStreamPlayer = null
var _death_cause: String = ""
var _last_tick: float = -1.0  # reloj del último tick en LLAMADO (pausa del plazo con el Trainer)
var _real_called_s: float = 0.0  # segundos reales libres para caminar hasta la sala de calibracion
var _death_clock: float = -INF  # reloj de juego al morir (el respawn lo rebobina al checkpoint)
var _token: int = 0
var _rng := RandomNumberGenerator.new()
# v0.3.2: estado de la sesión en curso (lo leen las pruebas, el bot y las capturas).
var session: Dictionary = {}  # HaimeGuion.build_session: {beats, nivel, firma, lineas, segundos}
var beat_now: String = ""  # beat en curso ("pregunta", "silencio"…)
var beats_done: Array[String] = []
var anger: int = 0  # respuestas tarde o mal en la sesión
var answers: Array = []  # [{q, resultado: ok|mal|tarde|cortado}]
var test_answers: Array = []  # pruebas: respuestas forzadas en orden ("ok" | "mal" | "tarde")
var test_opts: Dictionary = {}  # pruebas: opciones de HaimeGuion.build_session ({"apertura": "intro"})
var score_now: int = 100
var tension: float = 0.0  # 0..1: latido, luz, cara
var _score_step: float = 0.0
var _dim: float = 0.0
var _given: bool = false
var _used: Array = []
var _mem: Dictionary = {}
var _heart: AudioStreamPlayer = null
var _drone: AudioStreamPlayer = null
var _replay: AudioStreamPlayer = null
var _tube: AudioStreamPlayer = null
var _buzz: AudioStreamPlayer = null
var _buzz_left: float = 0.0
var _lights_out: int = 0  # luces que murieron solas en esta sesión (la fatal)
var _voice_pitch: float = 1.0  # velocidad/tono de su voz en esta sesión (HaimeGuion.voice_pitch; 1 fuera de sesión)
var _music_db: float = -13.0
var _duck: float = 0.0  # 1 = música muda (silencios)
# v0.3.2 (ritmo): reloj de la sesión y su línea de tiempo.
signal tick  # cada cuadro de la sesión (las esperas de la sesión cuelgan de él: se pausa con el juego y muere con el nodo)
var clock: float = 0.0  # s de sesión (delta escalado = s reales a 1x)
var timeline: Array = []  # [inicio, fin, "voz" | "audio" | "ev", id]: lo que suena y lo que pasa (pruebas: pacing())
var skipped: Array[String] = []  # extras que se saltó por ir pasada de tiempo (una voz ajena la hizo esperar)
var lost: Array[String] = []  # líneas del guion que el director no llegó a hacer sonar (vencidas o descartadas)
var silenced: Array[String] = []  # voces ajenas que quisieron sonar durante la sesión y se cortaron (pruebas)
var ui_history: Array = []  # la lista «TUS CALIBRACIONES» que mostró la última sesión (pruebas)
var _cur: float = 0.0  # cursor del guion: con el tiempo acelerado las esperas se encadenan sin arrastrar cuadros
var _line: RefCounted = null  # la línea de Haime que suena (VoiceDirector.Line)
var _sev: int = 0  # cara en la advertencia y la fatal (sube con cada paso)
var _amb_cut: float = 0.0  # 0..1: cuánto se apaga el ambiente del piso (el zumbido de la sala) en la fatal
var _amb_now: float = 0.0
var _amb_touched: bool = false
var _room_held: bool = false  # la muerte de la calibración final dejó la sala como estaba (se devuelve al reaparecer)
var stand_attempts: int = 0  # veces que quisiste pararte en la fatal (no se puede)
var _paused: Dictionary = {}  # v0.3.2-core4: la sesión que dejaste a medias (se retoma en el mismo beat)
var _beat_i: int = -1  # índice (en session.beats) del beat en curso o del último que corrió
var resumed_from: int = -1  # pruebas: beat desde el que se retomó la sesión en curso (-1 = empezó de cero)
var walkouts: int = 0  # pruebas: veces que te fuiste a mitad de la sesión en curso
var _late_arrival: bool = false  # llegaste a esta sesión después del «Te estoy esperando»
var _recalled: bool = false  # te fuiste a mitad y te volvió a llamar (volver de eso no es «llegar tarde»)


func _cfg() -> Dictionary:
	return DataLoader.dict("qa_haime")


func _ready() -> void:
	_rng.seed = 4151 + GameState.turno * 31
	rec = QaRec.new()
	rec.name = "QaRec"
	rec.qa = self
	add_child(rec)
	_music = AudioStreamPlayer.new()
	_music.name = "MusicaFeedback"
	_music.bus = "Sala"
	_music.volume_db = -13.0
	add_child(_music)
	_heart = AudioStreamPlayer.new()
	_heart.name = "LatidoFeedback"
	_heart.bus = "Sala"
	add_child(_heart)
	_drone = AudioStreamPlayer.new()
	_drone.name = "DronFeedback"
	_drone.bus = "Sala"
	add_child(_drone)
	_replay = AudioStreamPlayer.new()
	_replay.name = "ReplayAuricular"
	add_child(_replay)
	_tube = AudioStreamPlayer.new()  # el tubo enfermo del techo (la advertencia y la fatal): zumba hasta que muere
	_tube.name = "TuboSala"
	_tube.bus = "Sala"
	add_child(_tube)
	_buzz = AudioStreamPlayer.new()  # el chispazo corto de una luz que parpadea o muere
	_buzz.name = "ChispazoSala"
	_buzz.bus = "Sala"
	add_child(_buzz)
	EventBus.player_stood_up.connect(_on_stood_up)
	EventBus.aux_changed.connect(func(new_aux: int, _old: int) -> void:
		# El permiso de vuelta tras la sesión se acaba al poner otro AUX en tu PC.
		if state == State.LIBRE and new_aux != Metrics.Aux.COACHING and not Metrics.authorization_of("qa").is_empty():
			Metrics.revoke("qa"))
	EventBus.contact_outcome.connect(_on_outcome)
	EventBus.contact_accepted.connect(_on_accepted)
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.respawned.connect(_on_respawned)
	EventBus.death_sequence_started.connect(_on_death)
	EventBus.ezlak_quick_reply.connect(_on_quick_reply)
	EventBus.shift_started.connect(func() -> void:
		kills_shift = 0
		_paused = {}
		_release_room())
	EventBus.returned_to_menu.connect(func() -> void:
		kills_shift = 0
		_paused = {}
		_abort_session()
		_release_room())
	# Gancho de IA: lo que le escribes a Haime por Ezlaki. Si le mientes (efecto «calibracion»), guarda tu frase tal cual:
	# en la advertencia y la fatal la pantalla te la muestra.
	var brain := get_node_or_null("/root/IABrain")
	if brain != null and brain.has_signal("replied"):
		brain.connect("replied", _on_ia_replied)
	VoiceDirector.line_started.connect(_on_line_started)
	_resume_pending.call_deferred()


## Durante la calibración nadie más tiene la palabra: la sala está cerrada con seguro. Los parlantes de Shero, las voces
## del sistema, un compañero que murmura o un subtítulo de Ezlaki que aprovechan un silencio de Haime para empezar se
## cortan en el acto y sin fundido (antes una línea ajena se metía justo en los silencios largos —la respiración en tu
## nuca, la pluma que calla— y la frase siguiente de Haime esperaba detrás de ella hasta 3 s).
func _on_line_started(id: String, speaker: String, priority: int) -> void:
	_apply_pitch(state == State.SESION and speaker == "haime")
	if state != State.SESION or priority >= VoiceDirector.P.CLIENTE or speaker in ["haime", "haime_replay"]:
		return
	_silence_foreign(id)


## La voz fría de la advertencia y la fatal: sus líneas de la sesión suenan a HaimeGuion.voice_pitch(nivel) (más grave y
## más lenta). Se pone al empezar cada línea suya y se quita con cualquier otra (la grabación de tu contacto, un
## screamer, quien hable después): el reproductor del VoiceDirector nunca queda cambiado fuera de una línea de Haime.
func _apply_pitch(on: bool) -> void:
	var pl := VoiceDirector.get("_player") as AudioStreamPlayer
	if pl == null:
		return
	var want := _voice_pitch if on else 1.0
	if not is_equal_approx(pl.pitch_scale, want):
		pl.pitch_scale = want


func _silence_foreign(id: String = "") -> void:
	var l: Variant = VoiceDirector.current
	if l == null or (id != "" and str(l.id) != id) or str(l.speaker) in ["haime", "haime_replay"] or int(l.priority) >= VoiceDirector.P.CLIENTE:
		return
	var ext: Variant = l.external
	silenced.append(str(l.id))
	VoiceDirector.cancel(l, "calibración")
	if ext != null and is_instance_valid(ext) and (ext as Node).has_method("stop"):
		(ext as Node).call("stop")
	var old := VoiceDirector.get_node_or_null("VozFundido")
	if old != null and old.has_method("stop"):
		old.call("stop")
	VoiceDirector.subtitle_shown.emit("", "", 0.0)  # y su subtítulo no se queda en el HUD debajo de la frase de Haime


## Al continuar una partida guardada con un contacto malo que Haime todavía no calibró (saliste del juego antes de que
## te llamara, o en plena sesión): la llamada vuelve a programarse, como al reaparecer. Salir al menú no te salva.
func _resume_pending() -> void:
	if not is_inside_tree() or state != State.LIBRE or not enabled() or GameState.is_tutorial():
		return
	if not pending().is_empty() and feedbacks_done() < max_per_shift():
		_schedule()


## Saliste al menú en plena sesión: se cierra sin contar (lo que es global —el aviso del HUD, el ambiente, el reloj, el
## congelado— vuelve a su sitio; el mundo se libera en este mismo cuadro).
func _abort_session() -> void:
	if state != State.SESION:
		return
	_token += 1
	_room_held = false
	last_session_end = "menu"
	_cleanup(false)


func _exit_tree() -> void:
	# Red de seguridad: si el nodo se va con una sesión abierta, nada global queda tocado.
	if state == State.SESION:
		Discipline.freeze(false, "feedback")
		GameState.clear_clock_override("feedback")
		_cut_voice()
	if is_inside_tree():
		_hint_aside(false)
	_voice_pitch = 1.0
	_apply_pitch(false)
	_restore_ambient()


func _on_contact_ended(_c: Dictionary, _r: bool, _a: bool) -> void:
	monitored = false


func feedbacks_done() -> int:
	return int(PersonajesP5.counter("p5_qa_feedbacks", 0))


func pending() -> Array:
	return PersonajesP5.counter("p5_qa_pend", []) as Array


func enabled() -> bool:
	return bool(GameState.turno_cfg("haime", true))


## v0.3.1 (D2/F9): feedbacks del turno hasta la calibración final: 4 en Fácil/Normal, 3 en Difícil/Turno real.
func max_per_shift() -> int:
	return max_for_shift()


static func max_for_shift() -> int:
	var cfg := DataLoader.dict("qa_haime")
	if GameState.is_real_mode() or Difficulty.level >= Difficulty.Level.DIFICIL:
		return int(cfg.get("max_por_turno_dificil", 3))
	return int(cfg.get("max_por_turno", 4))


## Muertes por la calibración final en el turno (también las de antes del respawn).
func kills() -> int:
	return maxi(kills_shift, int(PersonajesP5.counter("p5_qa_muertes", 0)))


## ¿La calibración final todavía puede matar en este turno? (Como mucho MAX_KILLS veces; después, advertencias.)
func can_kill() -> bool:
	return kills() < MAX_KILLS


## ¿El feedback n es la última advertencia (el anterior al fatal)? Tras MAX_KILLS muertes, todos lo son.
func is_warning(n: int) -> bool:
	return n == max_per_shift() - 1 or (n >= max_per_shift() and not can_kill())


## ¿El feedback n mata (calibración final)?
func is_fatal(n: int) -> bool:
	return n >= max_per_shift() and can_kill()


## v0.3.1 (Joan 11:14Z): las líneas dependen del caso. Tipo del contacto malo: "correo" (casos de BO por correo),
## "kyc", "chat" o "" (llamada: las líneas base hablan de voz, silencios y respiración).
static func case_kind(canal: String) -> String:
	if canal in ["correo", "correo_bo", "caso_bo", "vitzo_caso"]:
		return "correo"
	if canal == "kyc":
		return "kyc"
	if canal == "chat":
		return "chat"
	return ""


## Clave de lineas_haime con la variante del caso si existe (fb1_replay → fb1_replay_correo).
func case_key(key: String) -> String:
	var k := case_kind(str(calling.get("canal", "")))
	if k != "" and DataLoader.dict("lineas_haime").has(key + "_" + k):
		return key + "_" + k
	return key


## Clave de líneas (fb1/fb2/fb3) del feedback n: el fatal usa fb3, la advertencia fb2 + la línea de advertencia.
func _line_set(n: int) -> int:
	if is_fatal(n):
		return 3
	return clampi(n, 1, 2)


# --- contactos ------------------------------------------------------------------------------------

func _on_accepted(_c: Dictionary) -> void:
	contacts_seen += 1
	var every := maxi(int(_cfg().get("rec_cada", 3)), 1)
	monitored = enabled() and (contacts_seen % every == 1 or every == 1 or state == State.LLAMADO)  # P6b: sin Haime (Inducción) no hay REC
	if monitored and contacts_seen == 1:
		PersonajesP5.say("REC", "haime", "rec", PersonajesP5.line("lineas_haime", "rec"), "Auricular")


## ¿Es un contacto malo para QA? Devuelve las marcas ([] si es bueno).
static func bad_marks(c: Dictionary, outcome: String) -> Array:
	var marks: Array = []
	for m in c.get("_qa", []):
		marks.append(str(m))
	if outcome == "molesto" and not marks.has("molesto"):
		marks.append("molesto")
	if outcome == "bo_miss" and marks.is_empty():
		marks.append("bo_miss")
	if outcome == "perdido":
		return []
	return marks


func _on_outcome(c: Dictionary, outcome: String, _csat: int) -> void:
	if not enabled() or outcome == "perdido":
		return
	var marks := bad_marks(c, outcome)
	if marks.is_empty():
		return
	if feedbacks_done() >= max_per_shift():
		return  # ya hubo calibración final en el turno
	var entry := {
		"id": str(c.get("id", "")), "hora": GameState.clock_text(), "reloj": GameState.clock_seconds, "marcas": marks, "resultado": outcome,
		"canal": str(c.get("canal", "")), "transcripcion": transcript(c),
	}
	var pend := pending().duplicate(true)
	pend.append(entry)
	PersonajesP5.set_counter("p5_qa_pend", pend)
	if state == State.LIBRE:
		_schedule()


func _schedule() -> void:
	var rng: Array = _cfg().get("llamada_tras_min", [5.0, 15.0])
	var t := GameState.clock_seconds + _rng.randf_range(float(rng[0]), float(rng[1])) * 60.0
	var last := float(PersonajesP5.counter("p5_qa_ultimo", -INF))
	t = maxf(t, last + float(_cfg().get("entre_llamadas_min", 40.0)) * 60.0)
	t = maxf(t, float(PersonajesP5.counter("p5_qa_bloqueo_hasta", -INF)))  # F17: margen tras la calibración final
	call_at = t
	state = State.PENDIENTE


## Transcripción del contacto (para la sesión): [{quien: cliente|yo, texto, qa}].
static func transcript(c: Dictionary) -> Array:
	var out: Array = []
	var nodes: Dictionary = c.get("nodos", {})
	for ch in c.get("_choices", []):
		var parts := str(ch).split(".")
		if parts.size() < 2 or not nodes.has(parts[0]):
			continue
		var node: Dictionary = nodes[parts[0]]
		out.append({"quien": "cliente", "texto": Loc.pick(node.get("cliente", {})), "qa": "", "audio": str(node.get("audio", "")).get_file().get_basename()})
		for o in node.get("opciones", []):
			if str((o as Dictionary).get("id", "")) == parts[1]:
				out.append({"quien": "yo", "texto": Loc.pick(o), "qa": str((o as Dictionary).get("qa", ""))})
	if out.is_empty():
		var caso: Variant = c.get("caso", c.get("asunto", {}))
		out.append({"quien": "cliente", "texto": Loc.pick(caso) if caso is Dictionary else str(caso), "qa": ""})
	return out


# --- llamada y llegada ----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not GameState.logged_in or Checkpoints.dying or not GameState.running:
		return
	_process_audio(_delta)
	if state == State.SESION:
		clock += _delta
		tick.emit()
	var now := GameState.clock_seconds
	# Haime espera (no llama, y si ya llamó su plazo no corre) mientras el Trainer te tiene ocupado, mientras dura tu
	# lunch y mientras alguien te persigue (Shero, el guardia, el RTA): no te mata por inasistencia por estar corriendo.
	var trainer := trainer_busy() or lunch_immune() or hunted()
	match state:
		State.PENDIENTE:
			# Todo llamado suyo pasa por hub.can_interrupt (de a uno: con otro llamado pendiente —el Trainer, el evento de
			# Rasec—, una sesión en curso, el lunch o la gracia tras reaparecer, espera). Su plazo empieza en call_now(),
			# cuando el llamado sale de verdad, no cuando tocaba.
			if now >= call_at and not trainer and hub.can_interrupt(false, "haime") and not Checkpoints.in_respawn_grace():
				call_now()
		State.LLAMADO:
			var busy_now := trainer or GameState.in_contact
			if busy_now and _last_tick >= 0.0:
				# Pausa el plazo de Haime mientras terminas tu llamada activa, el Trainer te ocupa, estas en lunch o te persiguen.
				called_at += maxf(now - _last_tick, 0.0)
			elif not busy_now:
				_real_called_s += _delta
			_last_tick = now
			_tick_called(now)
	if state != State.LLAMADO:
		_last_tick = -1.0


## v0.3.2: el lunch es inmune (Joan): Haime no llama y, si ya llamó, su plazo queda en pausa. La regla vive en
## Discipline.is_lunch_immune (paquete de bugs); sin ella (rama vieja) no hay inmunidad que respetar.
func lunch_immune() -> bool:
	return Discipline.has_method("is_lunch_immune") and bool(Discipline.call("is_lunch_immune", "haime"))


## ¿Alguien te está persiguiendo ahora mismo (cualquier cazador de Pursuit)?
func hunted() -> bool:
	return Pursuit.is_hunting()


## ¿El Trainer te tiene ocupado (convocado, en clase, en el quiz o persiguiéndote)? Haime no llama ni descuenta.
func trainer_busy() -> bool:
	var tr := hub.training if hub != null else null
	return tr != null and tr.state in [TrainingControl.State.LLAMADO, TrainingControl.State.SESION, TrainingControl.State.QUIZ, TrainingControl.State.PERSIGUE]


## Haime te llama ahora (lo usan también las pruebas y las capturas).
func call_now() -> void:
	var pend := pending()
	calling = (pend[0] as Dictionary).duplicate(true) if not pend.is_empty() else {"id": "", "hora": GameState.clock_text(), "marcas": ["generica"], "resultado": "", "transcripcion": []}
	n_call = feedbacks_done() + 1
	called_at = GameState.clock_seconds
	_real_called_s = 0.0
	noshow_warned = false
	coaching_hint_given = false
	_late_arrival = false
	_recalled = false
	state = State.LLAMADO
	Discipline.hold_slow_clock("haime", true)  # F20 (C3): convocado, el reloj va a 4x aunque sigas sentado
	Metrics.authorize(Metrics.Aux.COACHING, "qa", "sala_calibracion", -1.0)
	var vars := {"agente": GameState.agent, "hora": str(calling.get("hora", ""))}
	var key := case_key("llamado_final" if is_fatal(n_call) else ("llamado_3" if is_warning(n_call) else "llamado_%d" % clampi(n_call, 1, 2)))
	PersonajesP5.post("dm:haime", "haime", PersonajesP5.line("lineas_haime", key, vars), {"tipo": "qa_llamado", "n": n_call, "mention": true, "typing_s": 2.0, "quick_replies": ["voy", "ok"]})
	# v0.3.2: una toma de parlantes por agente (la voz dice tu nombre, como el subtítulo).
	var pa_id := "pa_llamado_" + SaveSlots.slug(GameState.agent)
	PersonajesP5.pa(HaimeVoz.spoken(pa_id, PersonajesP5.line("lineas_haime", "pa_llamado", vars)), "haime", pa_id if HaimeVoz.has(pa_id) else "pa_llamado")
	AudioManager.play_sfx("telefono_timbre")
	EventBus.qa_feedback_called.emit(n_call)
	hub.qa_called.emit(n_call)
	var actor := get_tree().get_first_node_in_group("p5_haime_actor")
	if actor != null and actor.has_method("appear_at_door"):
		actor.call("appear_at_door")


## Minutos de juego que quedan para llegar (con la dificultad). < 0 si no te llamó.
func seconds_left() -> float:
	if state != State.LLAMADO:
		return -1.0
	return PersonajesP5.plazo(float(_cfg().get("margen_llegada_min", 8.0))) - (GameState.clock_seconds - called_at)


func _tick_called(now: float) -> void:
	var elapsed := now - called_at
	if GameState.seated_at == "calibracion":
		var entrada := ""
		if Metrics.aux != Metrics.Aux.COACHING:
			# v0.3.1 (F4): la silla de calibración no tiene PC; Haime te pone en Coaching él mismo (llegaste a tiempo).
			# v0.3.2: lo dice al cerrar la puerta (es la entrada de la sesión: una voz a la vez).
			entrada = "pone_coaching"
			Metrics.set_aux(Metrics.Aux.COACHING)
		_start_session(entrada)
		return
	var min_real_warn := 28.0 * Difficulty.scale("plazos")
	if not noshow_warned and elapsed >= PersonajesP5.plazo(float(_cfg().get("aviso_noshow_min", 6.0))) and _real_called_s >= min_real_warn:
		noshow_warned = true
		PersonajesP5.post("dm:haime", "haime", PersonajesP5.line("lineas_haime", "noshow"), {"tipo": "qa_noshow", "mention": true})
		AudioManager.play_sfx("telefono_timbre")
	var min_real_death := clampf(55.0 * Difficulty.scale("plazos"), 45.0, 75.0)
	if elapsed >= PersonajesP5.plazo(float(_cfg().get("margen_llegada_min", 10.0))) and _real_called_s >= min_real_death:
		_noshow_death()


func _noshow_death() -> void:
	state = State.LIBRE
	Discipline.hold_slow_clock("haime", false)
	Metrics.revoke("qa")
	PersonajesP5.post("#site-updates", "haime", PersonajesP5.line("lineas_haime", "noshow_canal"), {"tipo": "qa_noshow_canal"})
	Checkpoints.request_death("qa_inasistencia", "", "haime")


func _on_quick_reply(ch: String, id: String) -> void:
	if ch != "dm:haime" or state != State.LLAMADO:
		return
	if id in ["voy", "ok"]:
		await PersonajesP5.wait(self, 1.6)
		if is_inside_tree() and state == State.LLAMADO:
			PersonajesP5.post("dm:haime", "haime", Loc.pick({"es": "Te espero. No traigas nada. Ya tengo todo.", "en": "I'll wait. Don't bring anything. I already have everything."}), {"tipo": "respuesta_npc"})


# --- sesión ---------------------------------------------------------------------------------------

func _start_session(entrada: String = "") -> void:
	state = State.SESION
	_token += 1
	var tok := _token
	var n := n_call
	var fatal := is_fatal(n)
	var warning := is_warning(n)
	# v0.3.2-core4: ¿vuelves a la sesión que dejaste a medias (misma llamada, mismo contacto)? Sigue donde iba.
	var saved: Dictionary = {}
	if not fatal and not _paused.is_empty() and int(_paused.get("n", -1)) == n and str(_paused.get("id", "")) == str(calling.get("id", "")):
		saved = _paused
	_paused = {}
	var resume := not saved.is_empty()
	resumed_from = int(saved.get("i", -1)) if resume else -1
	if not resume:
		walkouts = 0
	hub.busy = "feedback"
	session_log.clear()
	session_texts.clear()
	beats_done.clear()
	answers.clear()
	timeline.clear()
	skipped.clear()
	lost.clear()
	silenced.clear()
	ui_history = []
	# Lo que Haime venía diciendo (su llamado por los parlantes, «¿Te vas?») se corta: ya estás sentado frente a él. Y
	# cualquier otra voz que estuviera sonando (los parlantes) también: la puerta se cierra con seguro y la sala es suya.
	# Primero lo suyo que ESPERABA en cola (el llamado por los parlantes detrás de un cliente o de otro jefe): ya no
	# hace falta, y si no se saca arrancaba después y sonaba 8-11 s encima del principio de la sesión.
	for q in VoiceDirector.queue.duplicate():
		if q != null and str(q.speaker) == "haime":
			VoiceDirector.cancel(q, "llegaste")
	var prev: Variant = VoiceDirector.current
	if prev != null and str(prev.speaker) == "haime":
		VoiceDirector.cancel(prev, "llegaste")
		VoiceDirector.subtitle_shown.emit("", "", 0.0)  # y su subtítulo no se queda en pantalla sin voz
	elif prev != null:
		_silence_foreign()
		VoiceDirector.subtitle_shown.emit("", "", 0.0)
	_hint_aside(true)
	var hud0 := get_tree().root.find_child("HUD", true, false)
	if hud0 != null and hud0.has_method("_on_message"):
		hud0.call("_on_message", "", 0.0)  # el aviso del HUD que hubiera (su llamado por Ezlaki) no se queda sobre su primera frase
	_late_arrival = noshow_warned and not _recalled  # llegaste después de su «Te estoy esperando»: lo anota (y lo recuerda)
	stand_attempts = 0
	_amb_cut = 0.0
	clock = 0.0
	_cur = 0.0
	_line = null
	heard_opportunities = 0
	last_session_end = ""
	anger = 0
	tension = 0.0
	_dim = 0.0
	_duck = 0.0
	_given = false
	_used = []
	_beat_i = -1
	if resume:
		session_log.assign(saved.get("log", []))
		session_texts.assign(saved.get("texts", []))
		beats_done.assign(saved.get("beats_done", []))
		answers = (saved.get("answers", []) as Array).duplicate(true)
		anger = int(saved.get("anger", 0))
		tension = float(saved.get("tension", 0.0))
		heard_opportunities = int(saved.get("heard", 0))
		_used = (saved.get("used", []) as Array).duplicate()
		_late_arrival = bool(saved.get("late", false))
		skipped.assign(saved.get("skipped", []))
	Discipline.hold_slow_clock("haime", false)
	Discipline.freeze(true, "feedback")
	GameState.set_clock_override("feedback")
	hub.hide_pc("feedback", true)
	var pl := hub.player()
	if pl != null:
		pl.input_locked = true  # solo la 1.ª línea: desde la 2.ª te puedes parar (F6)
	EventBus.qa_feedback_started.emit(n)
	hub.haime_feedback_started.emit(n)
	_mem = _memory()
	_rng.randomize()
	var opts := test_opts.duplicate()
	if entrada != "":
		opts["entrada"] = entrada
	var lie := lie_penalty()
	if lie > 0:
		opts["mentira"] = lie
	var facts := _memory_facts()
	if not facts.is_empty():
		opts["recuerdos"] = facts
	if resume:
		session = saved.get("session", {})
	else:
		session = HaimeGuion.build_session(calling, n, fatal, warning, _rng, _mem, max_per_shift(), opts)
	var nivel := int(session.get("nivel", 1))
	if not resume:
		HaimeGuion.remember_session(_mem, session)
		_save_memory(_mem)  # al empezar: una sesión cortada por la muerte también cuenta como vista
	var actor := get_tree().get_first_node_in_group("p5_haime_actor")
	if actor != null and actor.has_method("session_mode"):
		actor.call("session_mode", true, n)
	_actor_call("room_session", [true, nivel])
	_actor_call("look_at_player", [true])  # C5 (Q2): te mira de frente
	_sev = _base_severity(nivel)
	_actor_call("set_severity", [_sev])
	_start_music(nivel)
	ui = FeedbackUI.new()
	ui.name = "FeedbackUI"
	add_child(ui)
	var marks: Array = calling.get("marcas", [])
	var target := _score(marks, n)
	session_opportunities = 0
	for b in session.get("beats", []):
		if str((b as Dictionary).get("k", "")) == "marca":
			session_opportunities += 1
	score_now = 100
	_score_step = float(100 - target) / float(maxi(session_opportunities, 1))
	ui.open(n, calling, 100, 1 if fatal or warning else 0, nivel)
	if nivel >= 3:
		# La advertencia y la fatal: la sala ya está más oscura que nunca al sentarte, y es oscuridad de verdad (las luces
		# de afuera que la alcanzan también bajan; el tubo del techo falla). El velo de la pantalla casi no interviene.
		_dim = LIGHT_START[nivel]
		if nivel == 4 and GfxQuality.is_light():
			# Modo liviano: solo hay 3 luces encendidas a la vez (las de afuera y el relleno no cuentan) y la sala cuelga
			# del tubo. Empieza menos bajo y baja un escalón con cada luz que «muere», para que se siga viendo la escalera.
			_dim = LIGHT_START_LIGHT
		_actor_call("set_dim", [_dim])
		_actor_call("set_outside", [OUTSIDE_START[nivel]])
		_actor_call("set_fill", [FILL_START[nivel], nivel == 4])
		_actor_call("sick_light", [0.2 if nivel == 3 else 0.45])
	_lights_out = 0
	_voice_pitch = HaimeGuion.voice_pitch(nivel)
	if nivel == 4:
		score_now = 0  # tu puntaje ya está escrito
		ui.set_score(0)
		ui.prewritten()
		_amb_cut = 0.35  # la sala suena mal desde que te sientas: el piso de afuera casi no se oye
	var beats: Array = session.get("beats", [])
	var first := 0
	if resume:
		# La sala y la pantalla vuelven a como las dejaste; echa el seguro otra vez y te lo dice. Después, lo que tocaba.
		first = clampi(int(saved.get("i", 0)), 0, beats.size())
		_restore_paused(saved, beats, first, nivel)
		_ev("retoma")
		await _w(tok, HaimeGuion.T_PUERTA)
		await _say_key(tok, "llegaste", nivel)
		if tok != _token:
			return
		clock = float(saved.get("clock", clock))  # el reloj de la sesión sigue donde iba: volver no le quita tiempo
		_cur = clock  # el beat se repite entero desde su principio: el cursor del guion arranca en el reloj
	for i in range(first, beats.size()):
		if tok != _token:
			return  # sesión vieja (muerte/respawn ya limpió; puede haber otra sesión en curso)
		if Checkpoints.dying:
			_cleanup(false)
			return
		_beat_i = i
		var beat := beats[i] as Dictionary
		if str(beat.get("k", "")) == "fin":
			continue  # lo dice _session_given si sigues sentado
		# Un extra no entra si la sesión ya va pasada de tiempo (una voz ajena la hizo esperar).
		if bool(beat.get("opc", false)) and _now() + HaimeGuion.range_of(beats, nivel, i).y > float(HaimeGuion.limits(nivel)[1]) + 0.6:
			skipped.append(str(beat.get("k", "")))
			continue
		if bool(beat.get("de_pie", false)):
			# Deja la silla (despacio, sin golpe) y ya no vuelve a sentarse: lo que sigue lo dice de pie.
			_actor_call("rise", [])
			_sev_up()
			_ev("de_pie")
		await _run_beat(tok, beat, nivel, n)
		if tok == _token and pl != null and is_instance_valid(pl) and pl.input_locked and not Checkpoints.dying and beat_now != "auricular" and session_log.size() >= 1:
			pl.input_locked = false
	if tok != _token:
		return
	if Checkpoints.dying:
		_cleanup(false)
		return
	_session_given(tok, n)


## v0.3.2-core4: lo que la sesión llevaba cuando te fuiste, puesto otra vez (puntaje, luz, cara, errores ya marcados en
## la pantalla, la lista de lo que recuerda, Haime de pie si ya se había levantado, el seguro).
func _restore_paused(saved: Dictionary, beats: Array, first: int, nivel: int) -> void:
	score_now = int(saved.get("score", score_now))
	_sev = int(saved.get("sev", _sev))
	_actor_call("set_severity", [_sev if nivel >= 3 else clampi(_base_severity(nivel) + anger + heard_opportunities, 0, 3)])
	if nivel < 4:
		_dim = float(saved.get("dim", _dim))
		_actor_call("set_dim", [_dim])
	var up := false
	for j in mini(first, beats.size()):
		var b := beats[j] as Dictionary
		up = up or bool(b.get("de_pie", false))
		if str(b.get("k", "")) == "marca" and _ui_ok():
			ui.mark_error(int(b.get("row", -1)), int(b.get("om", 1)), str(b.get("ui_text", b.get("text", ""))), str(b.get("quote", "")), score_now, _dim if nivel < 3 else _dim * 0.2)
	if up:
		_actor_call("rise", [])
	if nivel == 3 and heard_opportunities > 0:
		_actor_call("set_outside", [maxf(OUTSIDE_START[3] - 0.05 * heard_opportunities, 0.02)])
	ui_history = saved.get("ui_history", [])
	if _ui_ok():
		ui.set_score(score_now)
		if not ui_history.is_empty():
			ui.history(ui_history, int(saved.get("ui_focus", -1)))
		ui.door_locked()
	_actor_call("lock_door", [])
	_actor_call("lean", [0.6])


## ¿Ya no queda más que el cierre? (pararte ahí «da» la sesión; antes de eso es irte a mitad)
func _only_closing_left() -> bool:
	var beats: Array = session.get("beats", [])
	var from := _beat_i if beat_now != "" else _beat_i + 1
	for j in range(maxi(from, 0), beats.size()):
		if not str((beats[j] as Dictionary).get("k", "")) in ["cierre", "fin"]:
			return false
	return true


## v0.3.2 (gancho del paquete de IA, rama v0.3.2-ia): si existe el autoload IABrain y le mentiste a Haime en Ezlaki
## tras un contacto con marca de QA, haime_calibration_penalty() > 0: Haime te lo echa en cara (beat «mentira» después
## del primer error: más enojo, puntaje y luz; HaimeGuion lo mete en el guion y en su presupuesto). Sin IABrain, nada.
func lie_penalty() -> int:
	var brain := get_node_or_null("/root/IABrain")
	if brain == null or not brain.has_method("haime_calibration_penalty"):
		return 0
	return maxi(int(brain.call("haime_calibration_penalty")), 0)


# --- v0.3.2: reloj de la sesión, voz por el VoiceDirector y línea de tiempo -------------------------------------------

## ¿Tiempo acelerado? (pruebas y bots: Engine.time_scale 8). La voz no se acelera: la sesión sigue su guion y corta cada
## línea cuando «terminó» en tiempo de juego.
func _scaled() -> bool:
	return Engine.time_scale > 1.05


## Segundo de la sesión para la línea de tiempo (acelerado: el del guion, sin el arrastre de los cuadros).
func _now() -> float:
	return _cur if _scaled() else clock


## Espera `dt` s de sesión. A 1x, desde ahora; acelerado, desde donde iba el guion (los cuadros largos no se acumulan).
func _w(tok: int, dt: float) -> void:
	if not _scaled():
		_cur = clock
	_cur += maxf(dt, 0.0)
	while clock < _cur and tok == _token:
		await tick


## Algo pasa (pluma, luz, golpe…): va a la línea de tiempo.
func _ev(what: String) -> void:
	timeline.append([_now(), _now(), "ev", what])


## Pide la voz al VoiceDirector (prioridad DIRECTO, una voz a la vez) con su subtítulo, que es el texto de la toma.
func _voice(key: String, text: String) -> RefCounted:
	var slot := AudioManager.voice_slot("haime", key, "")
	if _scaled():
		# Acelerado (pruebas, bots) una voz ajena dura «8 veces más» que el guion: no se espera, se corta.
		var c: Variant = VoiceDirector.current
		if c != null and int(c.priority) <= VoiceDirector.P.DIRECTO:
			VoiceDirector.cancel(c, "acelerado")
	AudioManager.last_voice = {"slot": slot, "path": AudioManager.voice_path(slot), "bus": "Sala", "lang": Loc.language, "t": Time.get_ticks_msec(),
		"frame": Engine.get_process_frames(), "folder": "haime", "file": key, "had_text": true}
	var l: RefCounted = VoiceDirector.say(slot, VoiceDirector.P.DIRECTO, "haime", Callable(), {"text": "[Haime] " + text, "seconds": HaimeVoz.estimate(key, text), "bus": "Sala"})
	_line = l
	return l


## Espera a que la línea termine de hablarse (`habla` s) y corta su cola. A 1x, si otra voz directa (los parlantes,
## Shero) está sonando, primero espera su turno en el director: nunca se pisan.
func _line_wait(tok: int, l: Variant, habla: float, entry: Array = []) -> void:
	if l == null:
		await _w(tok, habla)
		return
	if not _scaled():
		while not l.done and int(l.started_ms) < 0 and tok == _token:
			await tick
		if tok != _token:
			return
		if not entry.is_empty():
			entry[0] = _now()  # empezó a sonar ahora (esperó su turno)
	if l.done and str(l.result) in ["vencida", "descartada"]:
		lost.append(str(l.id).get_file())
		return  # no llegó a sonar: no hay nada que esperar
	await _w(tok, habla)
	if not l.done:
		VoiceDirector.cancel(l, "cola")


## El aviso «[E] Levantarse» del HUD va en el centro de la pantalla: justo sobre la cara de Haime. Durante la sesión baja
## al pie (bajo la línea de Haime) y se atenúa; al terminar vuelve a su sitio.
func _hint_aside(on: bool, hide: bool = false) -> void:
	var hud := get_tree().root.find_child("HUD", true, false)
	var hint := hud.get("_hint") as Label if hud != null else null
	if hint == null:
		return
	if on:
		if not hint.has_meta("h2_top"):
			hint.set_meta("h2_top", hint.offset_top)
			hint.set_meta("h2_bottom", hint.offset_bottom)
		var h := float(hint.get_viewport_rect().size.y)
		hint.offset_top = h * 0.5 - 104.0
		hint.offset_bottom = h * 0.5 - 78.0
		hint.modulate.a = 0.0 if hide else 0.55  # la fatal, tras intentar pararte: ya no hay «Levantarse»
	elif hint.has_meta("h2_top"):
		hint.offset_top = float(hint.get_meta("h2_top"))
		hint.offset_bottom = float(hint.get_meta("h2_bottom"))
		hint.modulate.a = 1.0
		hint.remove_meta("h2_top")
		hint.remove_meta("h2_bottom")


func _cut_voice() -> void:
	if _line != null and not bool(_line.get("done")):
		VoiceDirector.cancel(_line, "sesión")
	_line = null


## Ritmo de la última sesión (pruebas, h2_ritmo): total, voz, silencio, el hueco más largo sin voz ni nada pasando, y la
## línea más larga.
func pacing() -> Dictionary:
	var total := maxf(_now(), 0.001)
	var step := 0.02
	var n := int(ceil(total / step)) + 1
	var busy := PackedByteArray()
	busy.resize(n)
	var voz := 0.0
	var lines := 0
	var longest := 0.0
	var longest_id := ""
	for e in timeline:
		var t0 := float(e[0])
		var t1 := float(e[1]) if float(e[1]) >= 0.0 else total
		if str(e[2]) == "voz":
			voz += t1 - t0
			lines += 1
			if t1 - t0 > longest:
				longest = t1 - t0
				longest_id = str(e[3])
		for i in range(clampi(int(t0 / step), 0, n - 1), clampi(int(t1 / step), 0, n - 1) + 1):
			busy[i] = 1
	var gap := 0.0
	var gap_at := 0.0
	var run := 0
	for i in n:
		if busy[i] == 0:
			run += 1
			if run * step > gap:
				gap = run * step
				gap_at = (i - run + 1) * step
		else:
			run = 0
	return {"total": total, "voz": voz, "silencio_pct": 100.0 * (1.0 - voz / total), "hueco": gap, "hueco_en": gap_at, "lineas": lines, "linea_max": longest, "linea_max_id": longest_id}


## Cara al empezar: la advertencia y la fatal empiezan tranquilas (y terminan al máximo: _sev_up).
func _base_severity(nivel: int) -> int:
	return [0, 0, 1, 1, 0][clampi(nivel, 0, 4)]


## La advertencia y la fatal: cada paso que se acerca, la cara empeora un grado (hasta 3).
func _sev_up(to_max: bool = false) -> void:
	_sev = 3 if to_max else mini(_sev + 1, 3)
	_actor_call("set_severity", [_sev])


func _ui_ok() -> bool:
	return ui != null and is_instance_valid(ui)


## Un beat de la sesión (ver HaimeGuion.build_session; los tiempos son las constantes T_* de HaimeGuion).
func _run_beat(tok: int, b: Dictionary, nivel: int, n: int) -> void:
	var k := str(b.get("k", ""))
	beat_now = k
	beats_done.append(k)
	match k:
		"puerta":
			_actor_call("lock_door", [])
			if _ui_ok():
				ui.door_locked()
			_ev("seguro")
			await _w(tok, HaimeGuion.T_PUERTA)
			if bool(b.get("doble", false)):
				# La segunda vuelta de llave.
				AudioManager.play_sfx("qa_puerta_seguro")
				if _ui_ok():
					ui.door_locked_twice()
				_ev("seguro2")
				await _w(tok, HaimeGuion.T_LLAVE)
			if b.has("key"):
				await _say(tok, b, nivel)
			else:
				_actor_call("lean", [0.5])  # solo te mira (y se inclina)
				_ev("mira")
				await _w(tok, HaimeGuion.T_MIRA)
		"linea":
			if str(b.get("g", "")) == "advertencia":
				_actor_call("lean", [0.8])  # «Mírame»: todavía sentado, se te viene encima despacio
				_sev_up()
				_ev("se_inclina")
			await _say(tok, b, nivel)
		"recuerdo":
			# Lo que recuerda de tus calibraciones anteriores: la lista aparece bajo el puntaje, con lo que está diciendo
			# resaltado (tu frase de Ezlaki, las veces que llegaste tarde, el error que repites).
			ui_history = _history_rows(str(b.get("si", "")))
			if _ui_ok():
				ui.history(ui_history, _history_focus(str(b.get("si", ""))))
			_pen_taps(2)
			_sev_up()
			_ev("historial")
			await _w(tok, HaimeGuion.T_RECUERDO)
			await _say(tok, b, nivel)
		"pluma":
			await _pen_stops(tok, b, nivel)
		"detras":
			await _behind(tok, b, nivel)
		"luz":
			_light_dies()
			await _w(tok, HaimeGuion.T_LUZ)
			await _say(tok, b, nivel)
		"certeza":
			await _certainty(tok, b, nivel)
		"marca":
			await _mark(tok, b, nivel, n)
		"replay":
			await _replay_beat(tok, b, nivel)
		"pregunta":
			await _ask(tok, b, nivel)
		"silencio":
			await _silence(tok, b, nivel)
		"golpe":
			_slam(nivel)
			await _w(tok, HaimeGuion.T_GOLPE)
			await _say(tok, b, nivel)
		"amenaza":
			_actor_call("in_face", [true])
			if nivel >= 3:
				_sev_up()
			_ev("cara")
			_duck = 0.7
			await _say(tok, b, nivel)
			_duck = 0.0
			if nivel >= 3 and tok == _token:
				_actor_call("in_face", [false])  # se retira a su lado de la mesa, apoyado en ella: la distancia cambia
				_actor_call("set_lean", [0.45])
		"auricular":
			await _headset(tok, b, nivel)
		"mentira":
			# Le mentiste en Ezlaki: cuenta como otro error (enojo × castigo) y te lo dice.
			for i in clampi(int(b.get("castigo", 1)), 1, 3):
				_anger_up(nivel)
			if nivel == 2:
				_slam(nivel)  # solo la 2.ª golpea: en la advertencia y la fatal ya no grita
			else:
				_pen_taps(4)
			if _ui_ok():
				ui.lie_called(_lie_quote())
			await _w(tok, HaimeGuion.T_MENTIRA)
			await _say(tok, b, nivel)
		"cierre":
			if nivel >= 3:
				_actor_call("upright", [true])  # la advertencia: se endereza y te dice tu número de pie, quieto, sin gritar
			if _ui_ok():
				ui.final_score(score_now if not is_fatal(n) else 0)
			_ev("puntaje")
			await _say(tok, b, nivel)
		"fatal":
			# Su última frase. La pantalla se va mientras la dice (quedan su frase y el REC); en el cuadro en que termina,
			# la muerte. La sala ya está a oscuras de verdad: al irse la pantalla no se aclara nada.
			if _ui_ok():
				ui.set_score(0)
				ui.final_rec()
			_duck = 1.0
			_ev("puntaje")
			await _say(tok, b, nivel, false)
	if tok == _token:
		beat_now = ""


## Deja de anotar: la pluma golpea parejo mientras te mira… y se calla. Un segundo de nada. Después habla.
func _pen_stops(tok: int, b: Dictionary, nivel: int) -> void:
	if _ui_ok():
		ui.show_line("")
	_duck = 0.6
	_actor_call("lean", [0.8])
	var s := float(b.get("s", 1.8))
	var taps := maxi(int(round(s / 0.4)), 2)
	for i in taps:
		AudioManager.play_sfx("qa_pluma")
		_ev("pluma")
		await _w(tok, s / float(taps))
		if tok != _token:
			return
	_duck = 1.0
	tension = minf(tension + 0.1, 1.0)
	if _ui_ok():
		ui.note("DEJÓ DE ANOTAR", "HE STOPPED WRITING")
	_ev("pluma_calla")
	await _w(tok, HaimeGuion.T_PLUMA_CALLA)
	_duck = 0.0
	await _say(tok, b, nivel)


## Un apagón, y cuando la luz vuelve su silla está vacía: está detrás de ti. Respira en tu nuca y te habla al oído.
func _behind(tok: int, b: Dictionary, nivel: int) -> void:
	if _ui_ok():
		ui.show_line("")
		ui.dark(HaimeGuion.T_DETRAS_IN)
	_spark(HaimeGuion.T_DETRAS_IN + 0.1)
	_actor_call("blackout", [HaimeGuion.T_DETRAS_IN])
	if nivel == 3:
		# La advertencia: el tubo del techo no vuelve del apagón. Cuando ves otra vez, hay menos luz y su silla está vacía.
		_actor_call("fail_light", [])
		_tube_off()
	_actor_call("behind", [true])
	_sev_up(true)
	_duck = 1.0
	_ev("apagon")
	await _w(tok, HaimeGuion.T_DETRAS_IN)
	if tok != _token:
		return
	if _ui_ok():
		ui.note("SU SILLA ESTÁ VACÍA", "HIS CHAIR IS EMPTY", 2.0)
	AudioManager.play_sfx("respiracion_nuca")
	_ev("silla_vacia")
	tension = minf(tension + 0.2, 1.0)
	await _w(tok, HaimeGuion.T_DETRAS * 0.5)
	if tok != _token:
		return
	_shake(0.03, 0.3)
	_ev("respira")
	await _w(tok, HaimeGuion.T_DETRAS * 0.5)
	_duck = 0.7
	await _say(tok, b, nivel)
	_duck = 0.0


## Una luz de la sala muere (la fatal: una por una; la roja del REC queda): chispazo, y el tubo que queda zumba peor.
## En la fatal las luces no bajan con tus errores (ya no cuentan): mueren solas, a su hora.
func _light_dies() -> void:
	# Primero se apaga el piso de afuera (el vidrio queda negro: allá no hay nadie); después la luz de tu lado, la de
	# la puerta. El tubo sobre la mesa queda para el final: lo apaga él (certeza). Con cada una, el tubo falla más
	# seguido y zumba más fuerte.
	_lights_out += 1
	_actor_call("fail_light", ["afuera" if _lights_out == 1 else "relleno"])
	if GfxQuality.is_light():
		_dim = minf(_dim + LIGHT_STEP_LIGHT, LIGHT_START[4])
		_actor_call("set_dim", [_dim])
	_actor_call("sick_light", [0.45 + 0.4 * _lights_out])
	_spark(0.45)
	if _tube != null and _tube.playing:
		_tube.volume_db = minf(_tube.volume_db + 2.5, -6.0)
	tension = minf(tension + 0.12, 1.0)
	_amb_cut = minf(_amb_cut + 0.3, 0.95)
	if _ui_ok():
		ui.dark(0.12)
	_sev_up()
	_ev("luz_muere")


## Chispazo de fluorescente de `secs` s (un trozo del parpadeo, cortado en seco).
func _spark(secs: float) -> void:
	var st := AudioManager.stream_for("ambiente/fluorescente_parpadeo", false)
	if st == null or _buzz == null:
		return
	_buzz.stream = st
	_buzz.volume_db = -3.0
	_buzz.play(_rng.randf_range(0.0, maxf(st.get_length() - secs - 0.2, 0.0)))
	_buzz_left = secs


## El zumbido del tubo enfermo (la advertencia y la fatal) mientras el panel del techo vive.
func _tube_on(nivel: int) -> void:
	var st := AudioManager.stream_for("ambiente/fluorescente_muriendo_loop", true)
	if st == null or _tube == null:
		return
	_tube.stream = st
	_tube.volume_db = -15.0 if nivel == 3 else -12.0
	_tube.play(_rng.randf_range(0.0, 8.0))


func _tube_off() -> void:
	if _tube != null and _tube.playing:
		_tube.stop()


## El momento en que ya lo sabes: apagón, muere lo que quedaba (también la claridad de afuera), y cuando ves otra vez él
## está de pie a su lado de la mesa, las dos manos sobre ella, quieto, solo con el rojo del REC. El latido. Y lo dice
## bajo. Con «antes» (la línea habla de apagar la luz) primero lo dice y después la apaga.
func _certainty(tok: int, b: Dictionary, nivel: int) -> void:
	if _ui_ok():
		ui.show_line("")
	_duck = 1.0
	_amb_cut = 1.0
	var first := bool(b.get("antes", false))
	if first:
		_actor_call("brace", [true])
		await _say(tok, b, nivel)
		if tok != _token:
			return
	if _ui_ok():
		ui.show_line("")
		ui.dark(0.4)
	AudioManager.play_sfx("fluorescente_estallido")
	_tube_off()
	_actor_call("blackout", [0.4])
	_actor_call("only_rec", [])
	if _ui_ok():
		ui.veil_off()  # desde aquí la oscuridad es solo la de la sala: la muerte sale de este mismo cuadro, sin velo
	_hint_aside(true, true)  # ni «[E] Levantarse»: ya no hay nada que tocar
	_dim = 0.85
	_actor_call("brace", [true])
	_sev_up(true)
	tension = 1.0
	_ev("apagon")
	await _w(tok, 0.4)
	if tok != _token:
		return
	_ev("solo_rec")
	await _w(tok, (HaimeGuion.T_CERTEZA - 0.4) * 0.5)
	if tok != _token:
		return
	AudioManager.play_sfx("latido_lento")
	_shake(0.02, 0.25)
	_ev("latido")
	await _w(tok, (HaimeGuion.T_CERTEZA - 0.4) * 0.5)
	if not first:
		await _say(tok, b, nivel)


## Dice una línea: subtítulo = texto de su voz, por el VoiceDirector; espera a que termine de hablar (no la cola de
## silencio de la toma) y un respiro corto (antes de la v0.3.2 cada línea ocupaba 5,5-7 s fijos).
func _say(tok: int, b: Dictionary, nivel: int = 1, breathe: bool = true) -> void:
	if tok != _token:
		return
	var key := str(b.get("key", ""))
	var text := HaimeVoz.spoken(key, str(b.get("text", "")))
	if key == "" or text == "":
		return
	session_log.append(key)
	session_texts.append(text)
	if _ui_ok():
		ui.show_line(text)
	var l := _voice(key, text)
	var entry := [_now(), -1.0, "voz", key]
	timeline.append(entry)
	await _line_wait(tok, l, HaimeVoz.talk(key, text) / _voice_pitch, entry)
	if tok != _token:
		return
	entry[1] = _now()
	if breathe:
		await _w(tok, HaimeGuion.GAP[clampi(nivel, 0, 4)])


func _say_key(tok: int, key: String, nivel: int) -> void:
	await _say(tok, {"key": key, "text": Loc.pick(DataLoader.dict("lineas_haime").get(key, {}))}, nivel)


## Tu error en rojo: la fila de la transcripción se marca, la pluma golpea, el puntaje baja, la luz baja, el latido sube.
## En ráfaga (`rapida`): lo mismo, pero solo dice «Otra.» y la pantalla muestra la oportunidad.
func _mark(tok: int, b: Dictionary, nivel: int, n: int) -> void:
	var om := int(b.get("om", 1))
	if is_fatal(n):
		score_now = 0  # ya estaba escrito
	else:
		var base := 100.0 - _score_step * om if om < session_opportunities else float(_score(calling.get("marcas", []), n))
		score_now = clampi(int(round(base)) - anger * 3, 18, 100)
	# La fatal: la luz ya no baja con tus errores (mueren solas). La advertencia: baja la sala y lo que llega de afuera.
	tension = minf(tension + 0.12 + 0.04 * nivel, 1.0)
	if nivel < 4:
		_dim = minf(_dim + [0.0, 0.14, 0.17, 0.06][clampi(nivel, 0, 3)], 0.82)
		_actor_call("set_dim", [_dim])
	if nivel == 3:
		_actor_call("set_outside", [maxf(OUTSIDE_START[3] - 0.05 * om, 0.02)])
	_actor_call("lean", [minf(0.35 + 0.2 * om, 1.0)])
	if nivel <= 2:
		_actor_call("set_severity", [clampi(_base_severity(nivel) + om - 1 + anger, 0, 3)])
	elif om == 1:
		_sev_up()
	if _ui_ok():
		ui.mark_error(int(b.get("row", -1)), om, str(b.get("ui_text", b.get("text", ""))), str(b.get("quote", "")), score_now, _dim if nivel < 3 else _dim * 0.2)
	_ev("marca")
	_pen_taps(2 + nivel)
	await _w(tok, HaimeGuion.T_MARCA)
	await _say(tok, b, nivel)
	if tok == _token:
		heard_opportunities = om


func _pen_taps(count: int) -> void:
	for i in count:
		get_tree().create_timer(0.11 * i, false).timeout.connect(_pen_tap)


func _pen_tap() -> void:
	if state == State.SESION:
		AudioManager.play_sfx("qa_pluma")
		_ev("pluma")


## El auricular reproduce TU contacto, distorsionado (voz del cliente lenta y saturada; en chat/correo/KYC, tus teclas).
## Va por el VoiceDirector como una voz más (nada le habla encima) y Haime no lo deja terminar: lo corta con su frase.
func _replay_beat(tok: int, b: Dictionary, nivel: int) -> void:
	if b.has("pre"):
		await _say(tok, b["pre"], nivel)
	if tok != _token:
		return
	if _ui_ok():
		ui.replay()
	_duck = 0.55
	AudioManager.play_sfx("estatica_rafaga")
	_ev("estatica")
	var own := bool(b.get("tu_voz", false))
	var st := _own_voice_stream() if own else _replay_stream()
	var l: Variant = null
	var entry := [_now(), -1.0, "audio", "tu_voz" if own else "replay"]
	timeline.append(entry)
	if own:
		# Tu propia voz: tu saludo del guion, lento y saturado. La pantalla lo cita; él no lo deja terminar.
		if _ui_ok():
			ui.show_line("[%s] «%s…»" % [GameState.agent, _own_voice_text()])
			ui.note("TU VOZ", "YOUR VOICE", 2.6)
			ui.replay_own()
		_ev("tu_voz")
	if st != null:
		_replay.bus = _replay_bus()
		_replay.stream = st
		_replay.volume_db = -2.0 if own else -4.0
		_replay.pitch_scale = 0.88 if own else (0.84 if nivel < 3 else 0.74)
		l = VoiceDirector.say_external(_replay, "haime/tu_voz" if own else "haime/replay", VoiceDirector.P.DIRECTO, "haime_replay", {"free_on_drop": false})
		_line = l
	await _w(tok, HaimeGuion.T_TU_VOZ if own else HaimeGuion.T_REPLAY[clampi(nivel, 0, 4)])
	if l != null and not l.done:
		VoiceDirector.cancel(l, "Haime corta la grabación")
	if _replay.playing:
		_replay.stop()
	if _ui_ok():
		ui.replay_end()
	_duck = 0.0
	if tok != _token:
		return
	entry[1] = _now()
	if b.has("caso"):
		await _say(tok, b["caso"], nivel)
	if b.has("post"):
		await _say(tok, b["post"], nivel)


## Tu propia voz grabada: el saludo del guion de tu agente (voces/agentes/<agente>_saludo; EN si existe).
func _own_voice_slot() -> String:
	return AudioManager.voice_slot("agentes", SaveSlots.slug(GameState.agent) + "_saludo", "")


func _own_voice_stream() -> AudioStream:
	var path := AudioManager.voice_path(_own_voice_slot())
	if path != "":
		var st := AudioManager.call("_load_mode", path, false) as AudioStream
		if st != null:
			return st
	return _replay_stream()


## Lo que alcanza a oírse antes de que lo corte: el saludo hasta la primera coma.
func _own_voice_text() -> String:
	var t: Dictionary = (DataLoader.dict("audio_index").get("textos", {}) as Dictionary).get(_own_voice_slot(), {})
	var full := Loc.pick(t) if not t.is_empty() else Loc.pick({"es": "Gracias por comunicarse con KipuPay", "en": "Thank you for calling KipuPay"})
	return full.get_slice(",", 0).strip_edges()


func _replay_stream() -> AudioStream:
	for row in calling.get("transcripcion", []):
		var audio := str((row as Dictionary).get("audio", ""))
		if audio == "":
			continue
		var path := AudioManager.voice_path(AudioManager.voice_slot("clientes", audio))
		if path != "":
			var st := AudioManager.call("_load_mode", path, false) as AudioStream
			if st != null:
				return st
	return AudioManager.stream_for("ambiente/teclado_fantasma_loop", false)


## Bus del auricular de la sala: tono más grave, saturado, banda de teléfono y eco corto. Lo crea AudioManager al
## arrancar (_ensure_buses): añadir un bus en plena partida corre contra el hilo de mezcla del motor.
static func replay_effects() -> Array:
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.62
	dist.post_gain = -6.0
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1300.0
	bp.resonance = 0.7
	var dl := AudioEffectDelay.new()
	dl.tap1_delay_ms = 140.0
	dl.tap1_level_db = -9.0
	dl.tap2_active = false
	dl.feedback_active = true
	dl.feedback_delay_ms = 230.0
	dl.feedback_level_db = -12.0
	return [dist, bp, dl]


static func _replay_bus() -> String:
	var bname := "HaimeReplay"
	if AudioServer.get_bus_index(bname) >= 0:
		return bname
	# Respaldo (no debería pasar: AudioManager ya lo creó): con el servidor de audio bloqueado.
	AudioServer.lock()
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bname)
	AudioServer.set_bus_send(idx, "Master")
	for fx in replay_effects():
		AudioServer.add_bus_effect(idx, fx)
	AudioServer.unlock()
	return bname


## Pregunta rápida o tarea (3-5 s, teclas 1-4). Tarde o mal = más enojo. En «repite» (2.ª+), si tardas o fallas te
## corta («Para. Muy lento.»), golpea y te la hace repetir con menos tiempo.
func _ask(tok: int, b: Dictionary, nivel: int) -> void:
	await _say(tok, b, nivel)
	if tok != _token or not _ui_ok():
		return
	var secs := float(b.get("tiempo", 4.0))
	var rep := bool(b.get("repite", false))
	if b.has("corte"):
		# La advertencia y la fatal: te corta la respuesta (sin segunda oportunidad). En la fatal da igual lo que contestes.
		# Si estaba de pie y derecho, mientras contestas se apoya en la mesa con las dos manos, encima de ti; dicha su
		# respuesta, se endereza otra vez.
		var node := get_tree().get_first_node_in_group("p5_haime_actor")
		var was_up := node != null and node.has_method("is_upright") and bool(node.call("is_upright"))
		if was_up:
			_actor_call("upright", [false])
			_actor_call("set_lean", [0.55])
		var r2 := await _answer(tok, b, secs, secs * float(b["corte"]))
		if tok != _token:
			return
		answers.append({"q": str(b.get("q", "")), "resultado": r2})
		if r2 != "ok":
			_anger_up(nivel)
		var kind := "corta" if r2 == "cortado" or r2 == "tarde" else ("igual" if bool(b.get("da_igual", false)) else ("bien" if r2 == "ok" else "mal"))
		await _say(tok, _reaction(b, kind, nivel), nivel)
		if was_up and tok == _token:
			_actor_call("upright", [true])
		return
	var res := await _answer(tok, b, secs, secs * HaimeGuion.CORTE if rep else -1.0)
	if tok != _token:
		return
	if rep and res != "ok":
		answers.append({"q": str(b.get("q", "")), "resultado": res})
		_anger_up(nivel)
		_slam(nivel)
		await _w(tok, HaimeGuion.T_GOLPE)
		await _say(tok, _reaction(b, "corta", nivel), nivel)
		if tok != _token or not _ui_ok():
			return
		res = await _answer(tok, b, HaimeGuion.second_time(secs), -1.0)
		if tok != _token:
			return
	answers.append({"q": str(b.get("q", "")), "resultado": res})
	if res == "ok":
		await _say(tok, _reaction(b, "bien", nivel), nivel)
		return
	_anger_up(nivel)
	if nivel >= 2 and anger >= 2:
		_slam(nivel)
		await _w(tok, HaimeGuion.T_ENOJO)
	await _say(tok, _reaction(b, "mal" if res == "mal" else "tarde", nivel), nivel)


## Lo que contesta él: lo eligió HaimeGuion al armar la pregunta (r_bien/r_mal/r_tarde/r_corta); queda en la memoria
## de la partida solo si lo dice.
func _reaction(b: Dictionary, kind: String, nivel: int) -> Dictionary:
	var r: Dictionary = b.get("r_" + kind, {})
	if r.is_empty():
		r = HaimeGuion._g(kind, nivel, "", _rng, _mem, _used)
	var lines: Array = _mem.get("lineas", [])
	lines.erase(str(r.get("key", "")))
	lines.append(str(r.get("key", "")))
	_mem["lineas"] = lines
	return r


## Espera la respuesta: "ok" | "mal" | "tarde" | "cortado". Mientras piensas, Haime se impacienta (la pluma, cada vez
## más seguido, y se inclina): nada de segundos muertos. Las pruebas fuerzan respuestas con test_answers.
func _answer(tok: int, b: Dictionary, secs: float, cut: float) -> String:
	if not _ui_ok():
		return "tarde"
	var correct := int(b.get("correcta", 0))
	var forced := -1
	if not test_answers.is_empty():
		var want := str(test_answers.pop_front())
		if want == "ok" or want == "mal":
			forced = correct if want == "ok" else (correct + 1) % 4
	var got: Array = [-99]
	ui.resolved.connect(func(r: int) -> void: got[0] = r, CONNECT_ONE_SHOT)
	ui.ask(b.get("opciones", []) as Array, correct, secs, cut)
	_ev("pregunta")
	if not _scaled():
		_cur = clock
	var t0 := _cur
	var t_ask := clock
	var next_tap := 1.0
	var every := 0.9
	while int(got[0]) == -99 and tok == _token and _ui_ok():
		await tick
		if tok != _token:
			return "tarde"
		var el := clock - t_ask
		if forced >= 0 and el >= HaimeGuion.T_RESPUESTA and _ui_ok() and ui.asking():
			ui.answer(forced)
		elif el >= next_tap and int(got[0]) == -99:
			AudioManager.play_sfx("qa_pluma")
			_actor_call("lean", [minf(0.5 + 0.15 * next_tap, 1.0)])
			timeline.append([t0 + next_tap, t0 + next_tap, "ev", "impaciencia"])
			every = maxf(every - 0.12, 0.55)
			next_tap += every
	if tok != _token:
		return "tarde"
	var r := int(got[0])
	# El guion sigue desde la respuesta (acelerado: desde cuando tocaba, sin el arrastre del cuadro).
	if _scaled():
		_cur = t0 + (HaimeGuion.T_RESPUESTA if forced >= 0 else (cut if r == -2 else secs))
	else:
		_cur = clock
	_ev("respuesta")
	match r:
		-1, -99:
			return "tarde"
		-2:
			return "cortado"
	return "ok" if r == correct else "mal"


## Bot y pruebas: responde la pregunta en pantalla (opción 0..3). false si no hay pregunta.
func answer(option: int) -> bool:
	if not _ui_ok() or not ui.asking():
		return false
	ui.answer(option)
	return true


func _anger_up(nivel: int) -> void:
	anger += 1
	tension = minf(tension + 0.18, 1.0)
	if nivel < 4:
		_dim = minf(_dim + (0.08 if nivel < 3 else 0.03), 0.85 if nivel < 3 else 0.82)
		_actor_call("set_dim", [_dim])
	_actor_call("set_severity", [clampi(_base_severity(nivel) + anger + heard_opportunities, 0, 3)])
	_actor_call("lean", [1.0])
	_ev("enojo")
	if _ui_ok():
		score_now = clampi(score_now - 3, 0 if is_fatal(n_call) else 18, 100)
		ui.anger(anger, score_now)


## Silencio demasiado largo: todo se calla menos el latido; te mira y se acerca. Mientras dura, cada ~1 s pasa algo (la
## luz parpadea y baja, la silla cruje, la pluma). Al final, el salto (apagón, golpe de luz, la cara encima) salvo en el
## silencio de entrada.
func _silence(tok: int, b: Dictionary, nivel: int) -> void:
	_duck = 1.0
	if _ui_ok():
		ui.show_line("")
		ui.silence(true)
	_actor_call("lean", [1.0])
	_ev("silencio")
	tension = minf(tension + 0.1, 1.0)
	var s := float(b.get("s", 3.0))
	var parts := maxi(int(ceil(s / 1.15)), 1)
	for i in parts:
		await _w(tok, s / float(parts))
		if tok != _token:
			return
		if i < parts - 1:
			_silence_step(i, nivel)
	if not bool(b.get("sin_salto", false)):
		AudioManager.play_sfx("fluorescente_estallido")
		AudioManager.play_sting()
		_actor_call("blackout", [0.22])
		_actor_call("in_face", [nivel >= 2])
		_actor_call("set_severity", [3])
		_shake(0.06 if nivel < 3 else 0.09, 0.35)
		if _ui_ok():
			ui.jump()
		_ev("salto")
		tension = minf(tension + 0.2, 1.0)
		await _w(tok, HaimeGuion.T_SALTO)
		if tok != _token:
			return
	_duck = 0.0
	if _ui_ok():
		ui.silence(false)
	if b.has("key"):
		await _say(tok, b, nivel)
	if nivel <= 2 and tok == _token:
		_actor_call("in_face", [false])
		_actor_call("set_severity", [clampi(_base_severity(nivel) + heard_opportunities - 1 + anger, 0, 3)])


## Algo pequeño en medio del silencio: la luz parpadea y baja un poco, o la silla cruje cuando se inclina, o la pluma.
func _silence_step(i: int, nivel: int) -> void:
	tension = minf(tension + 0.05, 1.0)
	match (i + nivel) % 3:
		0:
			_dim = minf(_dim + 0.05, 0.85)
			_actor_call("set_dim", [_dim])
			_actor_call("blackout", [0.07])
			AudioManager.play_sfx("fluorescente_parpadeo")
			_ev("luz")
		1:
			AudioManager.play_sfx("silla_crujido_largo")
			_actor_call("lean", [1.0])
			_ev("silla")
		2:
			AudioManager.play_sfx("qa_pluma")
			_ev("pluma")


## El golpe en la mesa: se levanta de un salto y descarga el puño; en el impacto (0,18 s después, lo marca el actor con
## su clip) la mesa salta, suena, la cámara tiembla y la pantalla también.
func _slam(nivel: int) -> void:
	var hit := func() -> void:
		AudioManager.play_sfx("qa_mesa_golpe")
		_shake(0.05 + 0.02 * nivel, 0.3)
		if _ui_ok():
			ui.slam()
		_ev("golpe")
	var actor := get_tree().get_first_node_in_group("p5_haime_actor")
	if actor != null and actor.has_method("slam"):
		actor.call("slam", hit)
	else:
		hit.call()
	tension = minf(tension + 0.12, 1.0)


## 3.ª: te arranca el auricular. Acople, la cámara tiembla y unos segundos no te puedes mover.
func _headset(tok: int, b: Dictionary, nivel: int) -> void:
	var pl := hub.player()
	if pl != null:
		pl.input_locked = true
	if not bool(b.get("desde_atras", false)):
		_actor_call("in_face", [true])
	_actor_call("grab_headset", [true])
	AudioManager.play_sfx("auricular_acople_chillido", "UI")
	AudioManager.play_sfx("auricular_desconexion")
	_shake(0.08, 0.45)
	if _ui_ok():
		ui.headset_off()
	_ev("auricular")
	await _w(tok, HaimeGuion.T_AURICULAR)
	await _say(tok, b, nivel)
	_actor_call("grab_headset", [false])
	if bool(b.get("desde_atras", false)) and tok == _token:
		# Vuelve a su lado de la mesa en un parpadeo de la luz: de pie, encima de ella.
		_actor_call("blackout", [0.12])
		_actor_call("behind", [false])
		if _ui_ok():
			ui.dark(0.12)
		_ev("vuelve")
	if tok == _token and pl != null and is_instance_valid(pl) and not Checkpoints.dying:
		pl.input_locked = false


## Temblor de cámara (h_offset/v_offset del Camera3D del jugador; vuelve a 0).
func _shake(amount: float, secs: float) -> void:
	var pl := hub.player() if hub != null else null
	if pl == null or pl.camera == null or bool(Loc.get_setting("flash_reduction", false)):
		return
	var cam := pl.camera
	var tw := create_tween()
	var steps := maxi(int(secs / 0.035), 2)
	for i in steps:
		var a := amount * (1.0 - float(i) / float(steps))
		tw.tween_property(cam, "h_offset", _rng.randf_range(-a, a), 0.035)
		tw.parallel().tween_property(cam, "v_offset", _rng.randf_range(-a, a), 0.035)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


func _reset_camera() -> void:
	var pl := hub.player() if hub != null else null
	if pl != null and pl.camera != null:
		pl.camera.h_offset = 0.0
		pl.camera.v_offset = 0.0


## Lo que pasó en esta calibración queda en la memoria de la partida (`historial`, las últimas 8): la advertencia y la
## fatal lo usan (_memory_facts) y lo muestran (_history_rows).
func _remember_outcome(fin: String) -> void:
	var bad := 0
	var good := 0
	for a in answers:
		if str((a as Dictionary).get("resultado", "")) == "ok":
			good += 1
		else:
			bad += 1
	var h: Array = _mem.get("historial", [])
	h.append({"n": n_call, "hora": str(calling.get("hora", "")), "tipo": HaimeGuion.entry_type(calling), "marcas": HaimeGuion.marks_of(calling),
		"puntaje": score_now, "mal": bad, "bien": good, "fin": fin, "tarde": _late_arrival})
	while h.size() > 8:
		h.pop_front()
	_mem["historial"] = h
	if _late_arrival:
		_mem["tardanzas"] = int(_mem.get("tardanzas", 0)) + 1  # llegaste después del «Te estoy esperando»
		_late_arrival = false
	if fin == "fatal":
		_mem["muertes"] = int(_mem.get("muertes", 0)) + 1
	if lie_penalty() > 0:
		_mem["mentiras"] = int(_mem.get("mentiras", 0)) + 1
	_save_memory(_mem)


## Qué recuerda Haime de tus calibraciones anteriores en esta partida (claves «si» del grupo de líneas «recuerdo»).
func _memory_facts() -> Array:
	var h: Array = _mem.get("historial", [])
	var out: Array = []
	if h.is_empty():
		return out
	out.append("siempre")
	var today := HaimeGuion.marks_of(calling)
	var last: Dictionary = h[-1]
	for e in h:
		var d := e as Dictionary
		for m in d.get("marcas", []):
			if today.has(str(m)) and not out.has("repite_error"):
				out.append("repite_error")
		if str(d.get("fin", "")) == "a_mitad" and not out.has("a_mitad"):
			out.append("a_mitad")
	if int(last.get("mal", 0)) >= 1:
		out.append("tardaste")
	elif int(last.get("bien", 0)) >= 1:
		out.append("todo_bien")
	if int(_mem.get("muertes", 0)) >= 1:
		out.append("ya_moriste")
	if (int(_mem.get("mentiras", 0)) >= 1 or not (_mem.get("mentiras_txt", []) as Array).is_empty()) and lie_penalty() <= 0:
		out.append("mentiste")  # (si la mentira es de este turno ya te la echa en cara el beat «mentira»)
	if int(_mem.get("tardanzas", 0)) >= 1:
		out.append("tarde_llegada")
	# Tus números bajan de una calibración a la otra.
	var scores: Array = []
	for e in h:
		if str((e as Dictionary).get("fin", "")) == "dada":
			scores.append(int((e as Dictionary).get("puntaje", 0)))
	if scores.size() >= 2 and int(scores[-1]) < int(scores[0]):
		out.append("baja")
	if int(_mem.get("sesiones", 0)) >= 4:
		out.append("muchas")
	return out


## Lo que le escribiste a Haime por Ezlaki y no era cierto (IABrain: efecto «calibracion»): queda tu frase, tal cual.
func _on_ia_replied(who: String, _channel: String, res: Dictionary) -> void:
	if who != "haime" or not (res.get("efectos", []) as Array).has("calibracion") or GameState.is_tutorial():
		return
	var txt := str((res.get("nlu", {}) as Dictionary).get("texto", "")).replace("\n", " ").strip_edges()
	if txt == "":
		return
	var m := _memory()
	var list: Array = m.get("mentiras_txt", [])
	list.append({"t": txt.left(90), "hora": GameState.clock_text()})
	while list.size() > 3:
		list.pop_front()
	m["mentiras_txt"] = list
	_save_memory(m)


## Tu última mentira por Ezlaki, para mostrarla: «hora · frase». "" si no hay ninguna guardada.
func _lie_quote() -> String:
	var list: Array = _mem.get("mentiras_txt", [])
	if list.is_empty():
		return ""
	var d := list[-1] as Dictionary
	return "%s · «%s»" % [str(d.get("hora", "")), str(d.get("t", ""))]


## La lista «TUS CALIBRACIONES» (las últimas 4): hora, tipo de caso, errores y puntaje (o cómo terminó). Según lo que
## Haime está recordando (`si`), una fila más con el dato: tu frase de Ezlaki, las veces que llegaste tarde, las veces
## que ya te calibró.
func _history_rows(si: String = "") -> Array:
	var rows: Array = []
	var h: Array = _mem.get("historial", [])
	var labels: Dictionary = (HaimeGuion._v32().get("opciones", {}) as Dictionary).get("canal", {})
	for e in h.slice(maxi(h.size() - 4, 0)):
		var d := e as Dictionary
		var tipo := Loc.pick(labels.get(str(d.get("tipo", "")), {}))
		var n_err := (d.get("marcas", []) as Array).size()
		var tail := str(int(d.get("puntaje", 0)))
		match str(d.get("fin", "")):
			"a_mitad":
				tail = Loc.pick({"es": "te fuiste", "en": "you walked out"})
			"fatal":
				tail = Loc.pick({"es": "calibrado", "en": "calibrated"})
		if bool(d.get("tarde", false)):
			tail += Loc.pick({"es": " · tarde", "en": " · late"})
		rows.append("%s · %s · %d %s · %s" % [str(d.get("hora", "")), tipo, n_err, Loc.pick({"es": "err.", "en": "err."}), tail])
	match si:
		"mentiste":
			var q := _lie_quote()
			rows.append("EZLAKI " + q if q != "" else Loc.pick({"es": "EZLAKI · lo que escribiste no era cierto", "en": "EZLAKI · what you wrote wasn't true"}))
		"tarde_llegada":
			var n_late := int(_mem.get("tardanzas", 0))
			rows.append(Loc.pick({"es": "LLEGASTE TARDE · %d %s", "en": "YOU CAME LATE · %d %s"}) % [n_late, Loc.pick({"es": "vez" if n_late == 1 else "veces", "en": "time" if n_late == 1 else "times"})])
		"ya_moriste":
			var n_dead := int(_mem.get("muertes", 0))
			rows.append(Loc.pick({"es": "CALIBRACIÓN FINAL · %d %s", "en": "FINAL CALIBRATION · %d %s"}) % [n_dead, Loc.pick({"es": "vez" if n_dead == 1 else "veces", "en": "time" if n_dead == 1 else "times"})])
	return rows


## Qué fila de la lista es de la que habla (se resalta): -1 = ninguna en particular.
func _history_focus(si: String) -> int:
	var h: Array = _mem.get("historial", [])
	var shown: Array = h.slice(maxi(h.size() - 4, 0))
	match si:
		"mentiste", "tarde_llegada", "ya_moriste":
			return shown.size()  # la fila extra
		"tardaste", "todo_bien":
			return shown.size() - 1
		"a_mitad":
			for i in range(shown.size() - 1, -1, -1):
				if str((shown[i] as Dictionary).get("fin", "")) == "a_mitad":
					return i
		"repite_error":
			var today := HaimeGuion.marks_of(calling)
			for i in range(shown.size() - 1, -1, -1):
				for m in (shown[i] as Dictionary).get("marcas", []):
					if today.has(str(m)):
						return i
	return -1


## Memoria por partida (líneas y estructuras ya vistas): user://partidas/<agente>/haime_memoria.json.
func _memory_path() -> String:
	return SaveSlots.dir_of(GameState.agent) + "haime_memoria.json"


func _memory() -> Dictionary:
	var p := _memory_path()
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _save_memory(m: Dictionary) -> void:
	if GameState.is_tutorial():
		return
	var p := _memory_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(m))


## La sesión cuenta como dada (escuchaste todas las oportunidades del guion): fatal = calibración final; si no, vuelves.
func _session_given(tok: int, n: int) -> void:
	_given = true
	_consume_pending()
	# Tras MAX_KILLS muertes el contador se queda en la advertencia: Haime sigue llamando, pero ya no mata.
	PersonajesP5.set_counter("p5_qa_feedbacks", n if can_kill() else mini(n, max_per_shift() - 1))
	PersonajesP5.set_counter("p5_qa_ultimo", GameState.clock_seconds)
	if is_fatal(n):
		last_session_end = "fatal"
		_remember_outcome("fatal")
		hub.haime_feedback_finished.emit(n, true)
		EventBus.qa_feedback_ended.emit(n)
		if _ui_ok():
			ui.final_rec()
		_ev("rec")
		# El gancho de la muerte: en este mismo cuadro (su última palabra acaba de terminar). Haime queda de pie a su lado
		# de la mesa con las manos sobre ella y solo el rojo del REC: de ahí salta el screamer («salto_mesa»). Contrato con
		# el paquete de muertes: tú sentado en «calibracion», Haime en el grupo p5_haime_actor con su `actor` visible, la
		# sala a oscuras con el REC; ni el actor ni las luces se tocan al empezar la muerte (vuelven al reaparecer).
		_room_held = true
		_actor_call("hold_for_death", [])
		_voice_pitch = 1.0
		_apply_pitch(false)  # el grito del screamer sale por el mismo reproductor: a su tono
		Checkpoints.request_death("calibracion_final", "", "haime")
		if not Checkpoints.dying and tok == _token:
			# La muerte no entró (inmortal de pruebas, Inducción): la sesión no puede quedarse abierta a oscuras.
			_release_room()
			_finish_released(n)
		return
	last_session_end = "dada"
	Fatigue.add(5.0)  # el feedback desgasta
	_remember_outcome("dada")  # guarda también lo que contestó a tus respuestas
	_actor_call("unlock_door", [])
	_ev("abre")
	_duck = 0.0
	tension = maxf(tension - 0.4, 0.0)
	if GameState.seated_at == "calibracion":
		var fin: Dictionary = {}
		for b in session.get("beats", []):
			if str((b as Dictionary).get("k", "")) == "fin":
				fin = b
		if fin.is_empty():
			fin = {"key": "fin_vuelve", "text": Loc.pick(DataLoader.dict("lineas_haime").get("fin_vuelve", {}))}
		await _say(tok, fin, 1)
		if tok != _token:
			return
	_finish_released(n)


func _finish_released(n: int) -> void:
	_cleanup(true)
	EventBus.qa_feedback_ended.emit(n)
	hub.haime_feedback_finished.emit(n, false)


## v0.3.1 (F6): te paraste durante la sesión. Con todas las oportunidades del guion escuchadas cuenta como dada; si no, te
## fuiste a mitad: Haime vuelve a llamarte con el plazo ya en el aviso («Te estoy esperando»).
func _on_stood_up() -> void:
	if state != State.SESION or Checkpoints.dying:
		return
	if is_fatal(n_call):
		# La fatal: no hay forma de irse. Te paras… y vuelves a estar sentado (al cuadro siguiente: los demás oyentes de
		# «se paró» ya terminaron). La sesión sigue donde iba.
		_pull_back.call_deferred()
		return
	_token += 1
	var tok := _token
	var n := n_call
	if _given:
		_finish_released(n)  # te paraste mientras decía la última línea: ya estaba dada
		return
	if heard_opportunities >= maxi(session_opportunities, 1) and _only_closing_left():
		_session_given(tok, n)
		return
	# v0.3.2-core4: te vas a mitad → la sesión queda guardada tal como iba; al volver sigue en este mismo beat.
	var done := beats_done.duplicate()
	if beat_now != "" and not done.is_empty():
		done.pop_back()  # el beat en curso no terminó: se repite entero al volver
	walkouts += 1
	_paused = {
		"n": n, "id": str(calling.get("id", "")), "session": session, "i": maxi(_beat_i if beat_now != "" else _beat_i + 1, 0),
		"anger": anger, "tension": tension, "score": score_now, "heard": heard_opportunities, "answers": answers.duplicate(true),
		"beats_done": done, "dim": _dim, "sev": _sev, "used": _used.duplicate(), "clock": clock, "cur": _cur,
		"log": session_log.duplicate(), "texts": session_texts.duplicate(), "ui_history": ui_history,
		"ui_focus": ui.history_focus if _ui_ok() else -1, "late": _late_arrival, "skipped": skipped.duplicate(),
	}
	last_session_end = "a_mitad"
	_remember_outcome("a_mitad")
	_cleanup(false, true)
	EventBus.qa_feedback_ended.emit(n)
	hub.haime_feedback_finished.emit(n, false)
	PersonajesP5.say("Haime", "haime", "a_mitad", HaimeVoz.spoken("a_mitad", PersonajesP5.line("lineas_haime", "a_mitad")))
	state = State.LLAMADO
	called_at = GameState.clock_seconds - PersonajesP5.plazo(float(_cfg().get("aviso_noshow_min", 5.0)))
	noshow_warned = true
	_recalled = true
	coaching_hint_given = false
	Discipline.hold_slow_clock("haime", true)
	Metrics.authorize(Metrics.Aux.COACHING, "qa", "sala_calibracion", -1.0)
	PersonajesP5.post("dm:haime", "haime", PersonajesP5.line("lineas_haime", "noshow"), {"tipo": "qa_noshow", "mention": true})


## La fatal: quisiste pararte. La silla (o él) te devuelve: apagón de un parpadeo, crujido, la cámara tiembla, y el
## aviso «[E] Levantarse» desaparece hasta el final.
func _pull_back() -> void:
	if state != State.SESION or Checkpoints.dying or hub == null:
		return
	var pl := hub.player()
	var seat := get_tree().root.find_child("Seat_calibracion", true, false) as Node3D
	if pl == null or seat == null:
		return
	stand_attempts += 1
	if not pl.seated:
		pl.sit_at(seat, "calibracion")
		pl.head.rotation.x = -0.06
	AudioManager.play_sfx("silla_crujido_largo")
	_shake(0.07, 0.35)
	tension = minf(tension + 0.15, 1.0)
	_actor_call("lean", [1.0])
	if _ui_ok():
		ui.dark(0.16)
		ui.note("NO TE PUEDES LEVANTAR", "YOU CAN'T GET UP", 2.2)
	_ev("no_te_levantas")
	_hint_aside(true, true)


## La sala que la muerte de la calibración final dejó a oscuras vuelve a la normalidad (al reaparecer, al volver al menú
## o al empezar otro turno), y el ambiente del piso recupera su volumen.
func _release_room() -> void:
	_restore_ambient()
	if not _room_held:
		return
	_room_held = false
	_hint_aside(false)
	_actor_call("release_after_death", [])


func _restore_ambient() -> void:
	_amb_cut = 0.0
	_amb_now = 0.0
	if _amb_touched:
		_amb_touched = false
		AudioManager.apply_volumes()


func _actor_call(method: String, args: Array) -> void:
	var actor := get_tree().get_first_node_in_group("p5_haime_actor")
	if actor != null and actor.has_method(method):
		actor.callv(method, args)


## Cama musical del feedback (Q3: musica/feedback_haime_loop) + el dron de audio_horror_v2 desde la 2.ª + el latido que
## crece con la tensión. Sin archivo: silencio (nunca un tono sintético).
func _start_music(nivel: int) -> void:
	var st := AudioManager.stream_for("musica/feedback_haime_loop", true)
	if st != null:
		_music.stream = st
		_music_db = -13.0 if nivel < 3 else -16.0
		_music.volume_db = _music_db
		_music.play()
	var hb := AudioManager.stream_for("sfx/latido_rapido_loop", true)
	if hb != null:
		_heart.stream = hb
		_heart.volume_db = -26.0
		_heart.pitch_scale = 0.62
		_heart.play()
	var dr := AudioManager.stream_for("sfx/persecucion_drone_loop", true) if nivel >= 2 else null
	if dr != null:
		_drone.stream = dr
		_drone.volume_db = -30.0
		_drone.play()
	if nivel >= 3:
		_tube_on(nivel)
	tension = [0.0, 0.05, 0.25, 0.5, 0.65][clampi(nivel, 0, 4)]


func _stop_music() -> void:
	for p in [_music, _heart, _drone, _replay, _tube, _buzz]:
		if p != null and (p as AudioStreamPlayer).playing:
			(p as AudioStreamPlayer).stop()
	_buzz_left = 0.0


## Latido, dron y música siguen a la tensión; los silencios bajan la música de golpe.
func _process_audio(delta: float) -> void:
	if state != State.SESION:
		return
	var t := tension
	if _heart.playing:
		_heart.volume_db = move_toward(_heart.volume_db, lerpf(-24.0, -6.0, t) + (4.0 if _duck >= 1.0 else 0.0), delta * 20.0)
		_heart.pitch_scale = move_toward(_heart.pitch_scale, lerpf(0.62, 1.22, t), delta * 0.5)
	if _drone.playing:
		_drone.volume_db = move_toward(_drone.volume_db, lerpf(-30.0, -12.0, t), delta * 12.0)
	if _music.playing:
		var want := _music_db - 34.0 * _duck
		_music.volume_db = want if _duck >= 1.0 else move_toward(_music.volume_db, want, delta * 30.0)
	if _ui_ok():
		ui.pulse_rate = lerpf(1.0, 2.6, t)
	if _buzz_left > 0.0:
		_buzz_left -= delta
		if _buzz_left <= 0.0 and _buzz.playing:
			_buzz.stop()
	# La fatal: el ambiente del piso (el zumbido, la oficina lejana) se va apagando con las luces; al final, nada.
	_amb_now = move_toward(_amb_now, _amb_cut, delta * 2.5)
	if _amb_now > 0.001 or _amb_touched:
		var idx := AudioServer.get_bus_index("Ambiente")
		if idx >= 0:
			_amb_touched = true
			AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(float(Loc.get_setting("vol_ambiente", 1.0)), 0.0001, 1.0)) + lerpf(0.0, -50.0, _amb_now))


func _score(marks: Array, n: int) -> int:
	if is_fatal(n):
		return 0
	var s := 100 - int(_cfg().get("puntaje_por_marca", 17)) * marks.size()
	if marks.has("molesto"):
		s -= int(_cfg().get("puntaje_molesto", 30)) - int(_cfg().get("puntaje_por_marca", 17))
	return clampi(s - (n - 1) * 15, 18, 88)


func _mark_text(mark: String) -> String:
	var ops: Dictionary = _cfg().get("oportunidades", {})
	var key := mark
	if mark.begins_with("kyc_"):
		key = "kyc"
	elif mark.begins_with("falta_portal"):
		key = "falta_portal"
	if not ops.has(key):
		key = "generica"
	return Loc.pick(ops.get(key, {}))


func _consume_pending() -> void:
	var pend := pending().duplicate(true)
	if not pend.is_empty():
		pend.pop_front()
	PersonajesP5.set_counter("p5_qa_pend", pend)


## Fin de la sesión (released = salió bien; false = se cortó por una muerte o un respawn). `walked_out` = el
## jugador se paró a mitad (F6): también le devuelve el control.
func _cleanup(released: bool, walked_out: bool = false) -> void:
	Discipline.freeze(false, "feedback")
	if hub != null:
		hub.hide_pc("feedback", false)
	GameState.clear_clock_override("feedback")
	if released and not Checkpoints.dying:
		# v0.3.1 (F4): la silla de calibración no tiene PC: el Coaching sigue autorizado el rato de volver a tu puesto
		# (si no, Rasec contaba «coaching excedido» y Shero «fuera de la sala» mientras caminabas). Al poner otro AUX
		# o al vencer, rigen las reglas de siempre.
		Metrics.authorize(Metrics.Aux.COACHING, "qa", "sala_calibracion", float(_cfg().get("regreso_min", 6.0)))
	else:
		Metrics.revoke("qa")
	_stop_music()
	_cut_voice()  # te fuiste (o moriste) a media frase: no sigue hablando solo
	_voice_pitch = 1.0
	_apply_pitch(false)
	if not _room_held:
		_hint_aside(false)  # (retenida para la muerte: el aviso no reaparece en el cuadro en que entra el screamer)
	_reset_camera()
	if not _room_held:
		# (La muerte de la calibración final deja la sala a oscuras y a Haime en su pose: el screamer sale de ahí.)
		_restore_ambient()
		_actor_call("room_session", [false, 0])
		_actor_call("look_at_player", [false])
	beat_now = ""
	_duck = 0.0
	if hub != null and hub.busy == "feedback":
		hub.busy = ""
	var pl := hub.player() if hub != null else null
	if pl != null and (released or walked_out) and not Checkpoints.dying:
		pl.input_locked = false
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	ui = null
	var actor := get_tree().get_first_node_in_group("p5_haime_actor")
	if actor != null and actor.has_method("session_mode") and not _room_held:
		actor.call("session_mode", false, 0)
	state = State.LIBRE
	if released and not pending().is_empty():
		_schedule()


func _on_death(c: String, _k: String, _d: String) -> void:
	_token += 1
	_paused = {}  # una muerte se lleva la sesión que estaba a medias
	_death_cause = c
	_death_clock = GameState.clock_seconds
	if state == State.SESION:
		if last_session_end != "fatal":
			last_session_end = "muerte"
			_room_held = false  # otra muerte en plena sesión: la sala vuelve ya
		_cleanup(false)
	elif state == State.LLAMADO:
		Metrics.revoke("qa")
	_stop_music()
	Discipline.hold_slow_clock("haime", false)
	state = State.LIBRE
	call_at = INF
	if c == "calibracion_final":
		kills_shift = kills() + 1


## Tras reaparecer, los contadores vuelven con el checkpoint; los contactos malos pendientes de ese
## momento vuelven a programar su llamada. v0.3.1 (F17): si la muerte fue de Haime (calibracion_final o
## qa_inasistencia) se purgan los pendientes (el que causó la llamada y los anteriores), los feedbacks quedan en
## max−1 como mucho y hay 60 min de juego de margen; la siguiente llamada exige un contacto malo nuevo. La
## purga también se escribe en el checkpoint vivo (otro respawn desde él no los trae de vuelta).
func _on_respawned(_k: String) -> void:
	_token += 1
	_paused = {}
	if state == State.SESION:
		_cleanup(false)
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	ui = null
	_stop_music()
	_release_room()
	state = State.LIBRE
	call_at = INF
	monitored = false
	var cause := Checkpoints.last_respawn_cause if Checkpoints.last_respawn_cause != "" else _death_cause
	_death_cause = ""
	# Ninguna convocatoria de Haime vuelve con el checkpoint (ni el reloj lento ni el permiso de Coaching).
	Discipline.hold_slow_clock("haime", false)
	if not Metrics.authorization_of("qa").is_empty():
		Metrics.revoke("qa")
	if cause in ["calibracion_final", "qa_inasistencia"]:
		# v0.3.1 (bucle de la calibración final): el turno vuelve a la advertencia (3.ª; 2.ª en Difícil/Turno real) y
		# no hay otra llamada antes de 90 min de juego ni antes del bloque de 3 h siguiente (lo que llegue después):
		# el reloj del respawn vuelve al checkpoint, y con 60 min la siguiente calibración caía en la misma hora.
		# El margen se cuenta desde la hora de la muerte (no desde la del checkpoint, que puede ser 1 h antes).
		var now := GameState.clock_seconds
		var base := maxf(now, _death_clock)
		var next_block := (floorf(base / float(GameState.BLOCK_SECONDS)) + 1.0) * float(GameState.BLOCK_SECONDS)
		# qa_inasistencia no es una calibración: ahí el contador no sube; la calibración final sí deja la advertencia
		# aunque el checkpoint sea de antes de la 3.ª (si no, se reaparecía con 2 y la «siguiente» no era la advertencia).
		var fb := max_per_shift() - 1 if cause == "calibracion_final" else mini(feedbacks_done(), max_per_shift() - 1)
		var patch := {
			"p5_qa_pend": [],
			"p5_qa_feedbacks": fb,
			"p5_qa_ultimo": now,
			"p5_qa_bloqueo_hasta": maxf(base + float(_cfg().get("margen_tras_muerte_min", 90.0)) * 60.0, next_block),
			"p5_qa_muertes": kills(),
		}
		for k in patch.keys():
			PersonajesP5.set_counter(k, patch[k])
		Checkpoints.patch_checkpoint_counters(patch)
		return
	if not pending().is_empty() and feedbacks_done() < max_per_shift():
		_schedule()

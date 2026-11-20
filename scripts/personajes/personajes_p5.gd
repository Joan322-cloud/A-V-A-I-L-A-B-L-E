class_name PersonajesP5
extends Node
## Personajes con reglas de la v0.3 (paquete P5, PLAN §7 y §10 P5). Nodo persistente del turno: vive bajo
## World (al lado del Building), así que sobrevive a los cambios de piso y muere con el mundo (menú, turno
## nuevo). Lo crean los comportamientos de cada piso (data/comportamientos.json → guardia.gd, topico.gd,
## training_session.gd, haime.gd, rasec.gd, personajes_piso.gd) con PersonajesP5.ensure(tree).
## Cerebros (uno por personaje, también persistentes):
##   qa       → QaFeedback (Haime: contactos malos, llamada, sala de calibración, 3.er feedback, inasistencia)
##   training → TrainingControl (Trainer: AUX Training, llegada, sesión, quiz con el reloj pausado, persecución)
##   rasec    → RasecControl (música de madrugada, mini evento con AUX BO, advertencias, actor de sus muertes)
##   topico   → TopicoControl ("Me siento mal" → permiso; el 2.º pedido del turno = work_avoiding)
##   rta      → RtaControl (órdenes de AUX en #allocations, strikes y caza en todo el edificio)
##   pursuit  → P5Pursuit (persecución en todo el edificio si P3 no la provee)
## Señales (contrato P5, PLAN §11.5): ver abajo. El estado que debe volver con el checkpoint vive en
## Discipline.counters (claves p5_*), así entra en los checkpoints sin tocar Checkpoints.

signal qa_called(n: int)
signal haime_feedback_started(n: int)
signal haime_feedback_finished(n: int, fatal: bool)
signal training_called()
signal training_started()
signal training_finished(passed: bool)
signal training_released()
signal rasec_music(on: bool)
signal rasec_event_called(kind: String)
signal rasec_event_started(kind: String)
signal rasec_event_finished(kind: String, took_part: bool)
signal rasec_warning(n: int, reason: String)
signal topico_granted()
signal topico_denied(reason: String)
signal guard_check_finished(turno: int)

const GROUP := "p5_personajes"

var qa: QaFeedback = null
var training: TrainingControl = null
var rasec: RasecControl = null
var topico: TopicoControl = null
var rta: RtaControl = null
var pursuit: P5Pursuit = null
var trainer_hold: TrainerHold = null


## Ver hold_trainer_patience(): corre después de Haime y antes del Trainer.
class TrainerHold extends Node:
	var hub: PersonajesP5 = null

	func _process(_delta: float) -> void:
		if hub != null:
			hub.hold_trainer_patience()
## Qué sesión guionizada está en curso ("" = ninguna): feedback, training, evento, topico. Mientras dura,
## los demás personajes de P5 no intervienen (PLAN §2 #34).
var busy: String = ""


static func get_hub(tree: SceneTree) -> PersonajesP5:
	return tree.get_first_node_in_group(GROUP) as PersonajesP5 if tree != null else null


## Crea el nodo persistente si no existe (bajo World). null si no hay mundo (menú).
static func ensure(tree: SceneTree) -> PersonajesP5:
	if tree == null:
		return null
	var h := get_hub(tree)
	if h != null:
		return h
	var b := tree.get_first_node_in_group("building") as Node
	if b == null or b.get_parent() == null:
		return null
	h = PersonajesP5.new()
	h.name = "PersonajesP5"
	b.get_parent().add_child(h)
	return h


func _ready() -> void:
	add_to_group(GROUP)
	pursuit = P5Pursuit.new()
	pursuit.name = "Persecucion"
	add_child(pursuit)
	qa = QaFeedback.new()
	qa.name = "Haime"
	qa.hub = self
	add_child(qa)
	trainer_hold = TrainerHold.new()
	trainer_hold.name = "FrenoTrainer"
	trainer_hold.hub = self
	add_child(trainer_hold)  # entre Haime y el Trainer: ver hold_trainer_patience()
	training = TrainingControl.new()
	training.name = "Training"
	training.hub = self
	add_child(training)
	rasec = RasecControl.new()
	rasec.name = "Rasec"
	rasec.hub = self
	add_child(rasec)
	topico = TopicoControl.new()
	topico.name = "Topico"
	topico.hub = self
	add_child(topico)
	rta = RtaControl.new()
	rta.name = "RTA"
	rta.hub = self
	add_child(rta)
	EventBus.respawned.connect(_on_respawned)


func _on_respawned(_k: String) -> void:
	busy = ""
	pc_hidden_by = ""


## v0.3.2-core (pasada 4 de partidas en fotos, bot torpe, T2): el Trainer tiene un camino forzado («no espera más»:
## tras 20 min de juego sin hueco te convoca igual) que no pasa por can_interrupt(). Caso visto: un contacto largo
## tenía esperando a Haime y al Trainer; al colgar, Haime (que corre antes) llamó, y en ESE MISMO cuadro al Trainer
## «se le acabó la paciencia»: los dos te convocaban a la vez a las 2:47. Mientras otro te tenga convocado, la
## tolerancia del Trainer no corre; en cuanto el otro termina, el Trainer llama por su camino normal.
## Lo llama `trainer_hold`, un nodo hijo puesto ENTRE Haime y el Trainer (el orden de los hijos es el orden de
## _process), para que la pregunta se haga justo antes de que decida el Trainer. Devuelve true si la frenó (pruebas).
func hold_trainer_patience() -> bool:
	if training == null or training.state != TrainingControl.State.LIBRE or training.waited_since < 0.0:
		return false
	if summon_pending("trainer") == "":
		return false
	training.waited_since = GameState.clock_seconds
	return true


## Durante el feedback, la clase y el quiz la PC se oculta: estás en una sala con alguien mirándote.
## `who` = quién lo oculta ("feedback", "training"); al soltar, vuelve como estaba si sigues sentado en un puesto
## CON monitores. v0.3.1 (F4/F6): las sillas sin monitores (calibración, training) nunca muestran la PC.
var pc_hidden_by: String = ""


func hide_pc(who: String, on: bool) -> void:
	var ws := get_tree().get_first_node_in_group("workstation") as Control
	if on:
		pc_hidden_by = who
		if ws != null:
			ws.call("set_zoom", false)
			ws.visible = false
	elif pc_hidden_by == who:
		pc_hidden_by = ""
		var pl := player()
		if ws != null and pl != null and pl.seated and bool(ws.call("seat_has_screens", pl.seat_id)):
			ws.visible = true
			ws.call("set_zoom", false)


# --- ayudas compartidas ---------------------------------------------------------------------------

func player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func floor_node() -> FloorBase:
	var b := building()
	return b.floor_node as FloorBase if b != null else null


func contacts() -> ContactManager:
	return get_tree().get_first_node_in_group("contact_manager") as ContactManager


func in_contact() -> bool:
	var cm := contacts()
	return cm != null and cm.phase != ContactManager.Phase.IDLE and not ContactManager.is_bo(cm.current)


## ¿Puede un personaje de P5 interrumpir ahora? (logueado, sin muerte, sin otra sesión, sin contacto, fuera del lunch).
## v0.3.2: `who` = quién convoca (rasec, trainer…): tras el lunch lo aplazado sale escalonado (Discipline.is_lunch_immune).
func can_interrupt(allow_contact: bool = false, who: String = "") -> bool:
	if not GameState.running or not GameState.logged_in or GameState.shift_over or Checkpoints.dying:
		return false
	if busy != "":
		return false
	if Discipline.session_active():
		return false  # sesión de coaching de Shero o de Rasec (P3, fuente shero / tm): nadie la pisa
	if Checkpoints.in_respawn_grace() or Metrics.reconnecting:
		return false  # v0.3.1 (C12): nadie convoca en los primeros 60 s reales tras reaparecer
	if Discipline.is_lunch_immune(who):
		return false  # v0.3.2 (Joan): en el lunch eres inmune (calibración, evento de Rasec, training…)
	if summon_pending(who) != "":
		return false  # v0.3.2-core: de a uno. Con un llamado pendiente nadie más te convoca (ver summon_pending)
	return allow_contact or not in_contact()


## ¿Quién te tiene convocado y todavía esperándote (el llamado salió, la sesión no empezó)? "" si nadie.
## `except` = quien pregunta (no se bloquea a sí mismo).
## v0.3.2-core (encontrado por el bot humano, T2): Haime llamaba a las 5:14 y el evento de Rasec caía a las 5:15.
## `busy` solo se marca cuando la sesión EMPIEZA, así que los dos llamados corrían a la vez: ibas al evento (4-6 min de
## juego) y el plazo de Haime (8 min) vencía; o ibas con Haime y te mataba Rasec. Una muerte sin salida. Ahora el
## segundo espera a que el primero termine (el evento aguanta 30 min de juego; Haime y el Trainer, lo que haga falta).
func summon_pending(except: String = "") -> String:
	if qa != null and except != "haime" and qa.state == QaFeedback.State.LLAMADO:
		return "haime"
	if training != null and except != "trainer" and training.state == TrainingControl.State.LLAMADO:
		return "trainer"
	if rasec != null and except != "rasec" and rasec.state == RasecControl.State.CONVOCADO:
		return "rasec"
	return ""


## Marcador del piso actual por nombre (o null).
func marker(p_name: String) -> Node3D:
	var fl := floor_node()
	return fl.find_child(p_name, true, false) as Node3D if fl != null else null


## Distancia horizontal del jugador a un marcador del piso `floor_n` (INF si estás en otro piso).
func dist_to_marker(p_name: String, floor_n: int) -> float:
	if GameState.current_floor != floor_n:
		return INF
	var m := marker(p_name)
	var p := player()
	if m == null or p == null:
		return INF
	var d := p.global_position - m.global_position
	d.y = 0.0
	return d.length()


## Contadores del turno que vuelven con el checkpoint (Discipline.counters).
static func counter(key: String, default: Variant = 0) -> Variant:
	return Discipline.counters.get(key, default)


static func set_counter(key: String, value: Variant) -> void:
	Discipline.counters[key] = value


## Línea {es,en} de un archivo de datos (data/<file>.json), con {variables}.
static func line(file: String, key: String, vars: Dictionary = {}) -> String:
	var d: Variant = DataLoader.dict(file).get(key, {})
	return Loc.fmt(Loc.pick(d), vars)


## Habla en persona: subtítulo con su nombre + voz voces/<folder>/<id> (si falta, el susurro de respaldo).
static func say(speaker: String, folder: String, id: String, text: String, bus: String = "Sala") -> void:
	if text == "":
		return
	AudioManager.play_voice(folder, id, "", bus)
	EventBus.subtitle.emit(folder, "[%s] %s" % [speaker, text], clampf(2.0 + text.length() * 0.045, 3.0, 7.0))


## Anuncio por los parlantes del piso donde estés.
static func pa(text: String, folder: String = "", id: String = "") -> void:
	AudioManager.play_sfx("pa_chime")
	if folder != "" and id != "":
		AudioManager.play_voice(folder, id, "", "Parlantes")  # P7: filtro de parlantes en tiempo real (bus)
	EventBus.subtitle.emit("parlantes", "%s: %s" % [TranslationServer.translate("SPEAKER_PA"), text], 5.0)


static func post(channel: String, author: String, text: String, meta: Dictionary = {}) -> void:
	EventBus.ezlak_post.emit(channel, author, text, meta)


## Espera `s` segundos con un Timer hijo de `node`: si el nodo se libera (menú, turno nuevo) la corrutina
## se descarta en silencio (un SceneTreeTimer la reanudaría sobre una instancia muerta). Se pausa con el juego.
static func wait(node: Node, s: float) -> Signal:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(s, 0.01)
	node.add_child(t)
	t.timeout.connect(t.queue_free)
	t.start()
	return t.timeout


## Escala de plazos por dificultad (Fácil ×1,5 · Normal ×1 · Difícil ×0,75).
static func plazo(minutes: float) -> float:
	return minutes * 60.0 * Difficulty.scale("plazos")

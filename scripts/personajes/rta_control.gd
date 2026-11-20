class_name RtaControl
extends Node
## Perrito RTA, reglas v0.3 (PLAN §2 #39 y #41, DIALOGOS §2; cerebro persistente: vigila en TODO el
## edificio; el cuerpo que patrulla la sala es perrito_rta.gd en el piso 2).
## - Órdenes de AUX en #allocations (PerritoRTA.dictate): BO (allocation del Mentor o caso KYC), Lunch a la
##   hora del turno, Training cuando el Trainer convoca, Available al volver. Menciona al que no cumple, y
##   también taguea a compañeros (que escalan… y desaparecen de la lista).
## - Strikes por turno: 1.ª y 2.ª orden ignorada (tolerancia del turno) = tag; la 3.ª, o 60 s de juego tras
##   el 2.º tag sin corregir = caza en todo el edificio (P5Pursuit, por la escalera) → `aux_incorrecto`
##   (screamer del perro desde el suelo). Corregir el AUX en cualquier Fonex cancela la caza.
## - Ya NO mata por break excedido (los breaks son de Shero, P3). Conserva el cupo de Baño (10 min
##   acumulados, PLAN §3.5) y la regla de lunch fuera de su hora.
## - No mira: Break, Coaching (Discipline/Rasec), Training autorizado o ya hecho (el regreso es de P3), el BO
##   del evento de Rasec (autorización "tm"), el Baño del permiso del tópico, durante un contacto y mientras
##   Discipline esté congelada (feedback, training, coaching autorizado) o haya otra sesión de P5.
## - Sus relojes corren a la velocidad del reloj del juego pero con tope de 4x (como las reglas de sitio,
##   PLAN #83): 90 s de tolerancia no pasan en dos segundos por estar sentado sin cola.
## Estado con checkpoint: Discipline.counters p5_rta_strikes; GameState.flags p5_lunch_hecho.

const CLOCK_CAP := 4.0

var hub: PersonajesP5 = null
var wrong_elapsed: float = -1.0  # segundos "de juego con tope" en el AUX incorrecto (-1 = correcto)
var counted: bool = false  # este episodio ya sumó su strike
var since_tag2: float = -1.0
var hunting: bool = false
var reason: String = ""
var posts: Array[String] = []  # tipos publicados (pruebas)
var _npc_next: int = 0
static var _order_frame: int = -1  # el Mentor publicó la orden en este fotograma (no duplicar)


func _ready() -> void:
	EventBus.aux_changed.connect(_on_aux_changed)
	EventBus.respawned.connect(_on_respawned)
	EventBus.pursuit_ended.connect(_on_pursuit_ended)
	EventBus.ezlak_post.connect(_on_post)
	_resync_npc()


func strikes() -> int:
	return int(PersonajesP5.counter("p5_rta_strikes", 0))


func _rta_cfg() -> Dictionary:
	return DataLoader.dict("lineas_rta")


static func lunch_taken() -> bool:
	return bool(GameState.flags.get("p5_lunch_hecho", false))


## Orden pendiente que reemplaza a "Available" (lunch a su hora, training convocado).
static func pending_order() -> int:
	if not GameState.logged_in:
		return Metrics.Aux.AVAILABLE
	var hub := PersonajesP5.get_hub(Engine.get_main_loop() as SceneTree)
	if hub != null and hub.training != null and hub.training.state == TrainingControl.State.LLAMADO:
		return Metrics.Aux.TRAINING
	var l := GameState.lunch_clock()
	var now := GameState.clock_seconds
	if not lunch_taken() and now >= l and now < l + GameState.lunch_minutes() * 60.0:
		return Metrics.Aux.LUNCH
	return Metrics.Aux.AVAILABLE


## Publica la orden de AUX en #allocations (la llama PerritoRTA.dictate).
static func announce(expected: int, previous: int) -> void:
	if Engine.get_process_frames() == _order_frame:
		return
	var vars := {"agente": GameState.agent, "hora": GameState.clock_text_at(GameState.lunch_clock())}
	var key := ""
	match expected:
		Metrics.Aux.BO:
			key = "orden_bo_caso"
		Metrics.Aux.LUNCH:
			key = "orden_lunch"
		Metrics.Aux.TRAINING:
			key = "orden_training"
		Metrics.Aux.AVAILABLE:
			if previous == Metrics.Aux.BO:
				key = "orden_available"
	if key == "" or not GameState.logged_in:
		return
	PersonajesP5.post("#allocations", "rta", PersonajesP5.line("lineas_rta", key, vars), {"tipo": "orden_aux", "aux": expected, "mention": true})


func _on_post(channel: String, author: String, _text: String, meta: Dictionary) -> void:
	if author == "rta" and str(meta.get("tipo", "")) == "orden_aux" and EzlakHub.normalize(channel) == "#allocations":
		_order_frame = Engine.get_process_frames()
		posts.append("orden")


## Motivo por el que el AUX actual está mal ("" = bien o no le toca vigilar).
func wrong_reason() -> String:
	if Discipline.is_frozen() or hub.busy != "" or hub.in_contact():
		return ""
	var aux := Metrics.aux
	var exp := Metrics.expected_aux
	match aux:
		Metrics.Aux.BREAK, Metrics.Aux.COACHING:
			return ""
		Metrics.Aux.TRAINING:
			if Metrics.is_aux_authorized(Metrics.Aux.TRAINING) or hub.training.done() or exp == Metrics.Aux.TRAINING:
				return ""
			return "aux"
		Metrics.Aux.LUNCH:
			return "" if lunch_taken() or exp == Metrics.Aux.LUNCH else "aux"
		Metrics.Aux.BANO:
			if not Metrics.authorization_of("topico").is_empty():
				return ""
			return "cupo" if Metrics.quota_left(Metrics.Aux.BANO) <= 0.0 else ""
	# Available / BO
	if aux == Metrics.Aux.BO and not Metrics.authorization_of("tm").is_empty():
		return ""  # evento de Rasec
	return "" if aux == exp else "aux"


func _process(delta: float) -> void:
	if not GameState.logged_in or not GameState.running or GameState.shift_over or Checkpoints.dying:
		return
	var now := GameState.clock_seconds
	_npc_tags(now)
	_lunch_orders(now)
	if GameState.in_calm or Checkpoints.in_respawn_grace():
		return  # P7: la calma tras reconectar también vale para el RTA; v0.3.1 (C12): y la gracia de 60 s reales
	if Discipline.is_lunch_immune():
		return  # v0.3.2: en el lunch y en la gracia de vuelta el RTA no cuenta strikes ni sale a cazar
	var r := wrong_reason()
	if r == "":
		if wrong_elapsed >= 0.0:
			_corrected()
		return
	reason = r
	var step := delta * minf(GameState.clock_speed(), CLOCK_CAP)
	if wrong_elapsed < 0.0:
		wrong_elapsed = 0.0
		counted = false
	wrong_elapsed += step
	if since_tag2 >= 0.0:
		since_tag2 += step
	var tol := float(GameState.turno_cfg("rta_tolerancia_s", DataLoader.bal("rta/tolerancia_s_juego", 90.0))) * Difficulty.scale("tolerancia_rta")
	if not counted and wrong_elapsed >= tol:
		counted = true
		var n := strikes() + 1
		PersonajesP5.set_counter("p5_rta_strikes", n)
		if n >= 3:
			_hunt()
		else:
			_tag(n)
			# Si sigue sin corregir, otra tolerancia entera cuenta un strike nuevo (ignorar en continuo escala).
			wrong_elapsed = 0.0
			counted = false
	elif since_tag2 >= 0.0 and not hunting and since_tag2 >= float(_rta_cfg().get("caza_tras_tag2_s", 60.0)):
		_hunt()


func _detail() -> String:
	return "%s %s" % [Metrics.aux_name(), Loc.mmss(Metrics.aux_session_seconds())]


func _tag(n: int) -> void:
	var key := "tag_cupo" if reason == "cupo" else ("tag_2" if n >= 2 else "tag_1")
	var vars := {"agente": GameState.agent, "aux": Metrics.aux_name(), "t": Loc.mmss(Metrics.aux_session_seconds())}
	posts.append(key)
	PersonajesP5.post("#allocations", "rta", PersonajesP5.line("lineas_rta", key, vars), {"tipo": "tag", "strike": n, "mention": true})
	AudioManager.play_sfx("rta_ladrido")
	if n >= 2:
		since_tag2 = 0.0
	var body := get_tree().get_first_node_in_group("rta")
	if body != null and body.has_method("stare_at_player"):
		body.call("stare_at_player", true)


func _hunt() -> void:
	if hunting:
		return
	hunting = true
	since_tag2 = -1.0
	posts.append("caza")
	PersonajesP5.post("#allocations", "rta", PersonajesP5.line("lineas_rta", "caza", {"agente": GameState.agent}), {"tipo": "caza", "mention": true})
	PersonajesP5.pa(PersonajesP5.line("lineas_rta", "caza_pa"), "rta", "caza")
	AudioManager.play_sfx("lanyard_tintineo")
	EventBus.rta_hunt_started.emit()
	var from := Vector3.INF
	var body := get_tree().get_first_node_in_group("rta") as Node3D
	if GameState.current_floor == 2 and body != null:
		from = body.global_position
		body.visible = false
	P5Pursuit.start("rta", "aux_incorrecto", float(_rta_cfg().get("velocidad_caza_ms", 7.0)), null, _detail(), 2, from)


func _corrected() -> void:
	wrong_elapsed = -1.0
	counted = false
	since_tag2 = -1.0
	var body := get_tree().get_first_node_in_group("rta")
	if body != null and body.has_method("stare_at_player"):
		body.call("stare_at_player", false)
	if hunting:
		hunting = false
		P5Pursuit.stop("rta", "corregido")
		posts.append("perdida_caza")
		PersonajesP5.post("#allocations", "rta", PersonajesP5.line("lineas_rta", "perdida_caza", {"agente": GameState.agent}), {"tipo": "perdida_caza", "mention": true})
		_show_body()


func _show_body() -> void:
	var body := get_tree().get_first_node_in_group("rta") as Node3D
	if body != null:
		body.visible = true


func _on_pursuit_ended(hunter: String, why: String) -> void:
	if hunter != "rta":
		return
	hunting = false
	_show_body()
	if why == "alcanzado":
		posts.append("reporte")
		PersonajesP5.post("#allocations", "rta", PersonajesP5.line("lineas_rta", "reporte", {"id": "%04d" % (randi() % 9000 + 1000)}), {"tipo": "reporte"})


## Lunch a su hora: orden del RTA; al terminar el lunch (o si nunca lo tomaste), vuelve a Available.
func _lunch_orders(now: float) -> void:
	var l := GameState.lunch_clock()
	var end := l + GameState.lunch_minutes() * 60.0
	if now >= l and now < end and not lunch_taken() and Metrics.aux != Metrics.Aux.LUNCH and Metrics.expected_aux != Metrics.Aux.LUNCH and not hub.in_contact():
		PerritoRTA.dictate(Metrics.Aux.AVAILABLE)  # se lee como Lunch (pending_order)
	elif now >= end and Metrics.expected_aux == Metrics.Aux.LUNCH and Metrics.aux != Metrics.Aux.LUNCH:
		Metrics.expected_aux = Metrics.Aux.AVAILABLE
		EventBus.expected_aux_changed.emit(Metrics.Aux.AVAILABLE)


func _on_aux_changed(new_aux: int, old_aux: int) -> void:
	if new_aux == Metrics.Aux.LUNCH:
		var l := GameState.lunch_clock()
		var now := GameState.clock_seconds
		if Metrics.expected_aux == Metrics.Aux.LUNCH or (now >= l - float(DataLoader.bal("lunch/ventana_antes_min", 5.0)) * 60.0 and now < l + float(DataLoader.bal("lunch/ventana_despues_min", 15.0)) * 60.0):
			GameState.flags["p5_lunch_hecho"] = true
	if old_aux in [Metrics.Aux.LUNCH, Metrics.Aux.TRAINING] and Metrics.expected_aux == old_aux:
		PerritoRTA.dictate(Metrics.Aux.AVAILABLE)


# --- compañeros ----------------------------------------------------------------------------------

func _npc_tags(now: float) -> void:
	var npc: Array = _rta_cfg().get("npc", [])
	while _npc_next < npc.size() and GameState.hhmm_to_seconds(str((npc[_npc_next] as Dictionary).get("hora", "99:00"))) <= now:
		var e: Dictionary = npc[_npc_next]
		_npc_next += 1
		if str(e.get("agente", "")).to_lower() == GameState.agent.to_lower():
			continue  # el que juegas no se taguea a sí mismo como NPC
		PersonajesP5.post("#allocations", "rta", Loc.pick(e), {"tipo": "tag_npc", "agente": str(e.get("agente", ""))})


func _resync_npc() -> void:
	_npc_next = 0
	var npc: Array = _rta_cfg().get("npc", [])
	while _npc_next < npc.size() and GameState.logged_in and GameState.hhmm_to_seconds(str((npc[_npc_next] as Dictionary).get("hora", "99:00"))) <= GameState.clock_seconds:
		_npc_next += 1


func _on_respawned(_k: String) -> void:
	wrong_elapsed = -1.0
	counted = false
	since_tag2 = -1.0
	hunting = false
	_show_body()
	_resync_npc()
	_reannounce.call_deferred()


## P7: el checkpoint puede devolverte en un AUX que ya no toca (p. ej. BO de un caso que cerraste justo antes de
## morir): el RTA repite la orden en #allocations con mención, para que se vea qué AUX corresponde al reconectar.
func _reannounce() -> void:
	if hub == null or not GameState.logged_in or not GameState.running or Checkpoints.dying:
		return
	if wrong_reason() == "aux":
		var exp := pending_order() if pending_order() != Metrics.Aux.AVAILABLE else Metrics.expected_aux
		announce(exp, Metrics.aux)
		posts.append("orden_reconecta")

## Sin class_name: lo carga stress_bot.gd (solo herramienta).
extends Node
## Parte P5 del bot (stress_bot.gd): el bot listo pasa la revisión de Don Fermín, atiende el feedback de
## Haime (Coaching + sala de calibración), va al training (AUX Training, sala 2, quiz bien respondido) y vuelve,
## participa en el evento de Rasec (AUX BO + centro de la sala), pide el tópico UNA vez (T2+) y vuelve a su
## sitio. Para que el feedback de Haime se ejercite, en un contacto por turno elige un camino con una marca
## de QA (sin correo a Vitzo y sin cliente molesto si se puede).
## v0.3.1 Q1 (F23): con el bot humano (stress_bot `--humano`) va andando a cada sitio (calibración, sala 2 del
## piso 1, centro de la sala, tópico) tras sus tiempos de reacción, y se equivoca 1 de cada 5 contactos.
## Variantes torpes de P5 (`-- --bot N --torpe <variante>`): juegan como el listo salvo en su falta y deben
## morir con su causa:
##   qa → no va al feedback (qa_inasistencia) · qa3 → marca de QA en cada contacto (calibracion_final al 4.º en
##   Normal desde la v0.3.1, D2)
##   training → no baja al training (training_inasistencia, T2/T3) · quiz → responde mal (training_reprobado)
##   rasec → rechaza el evento dos veces (rasec_evento) · topico → pide el tópico dos veces (work_avoiding)
##   rta → ignora las órdenes del RTA (aux_incorrecto)
## Con una variante de P3 (`stress_bot._variant`: break, sala, isla…) no comete el error honesto (Haime no llama)
## y, una vez cometida la falta (estado "torpe"), no atiende a Haime, al Trainer ni a Rasec: si no, el feedback lo
## devolvería a su sitio y la falta de P3 no llegaría a matarlo. En la variante "available" (todo el turno en BO,
## para la lista del Mentor) el RTA queda apagado: su caza por AUX incorrecto llegaría antes que la 3.ª lista.

const FAULTS: Dictionary = {
	"qa": "qa_inasistencia", "qa3": "calibracion_final", "training": "training_inasistencia",
	"quiz": "training_reprobado", "rasec": "rasec_evento", "topico": "work_avoiding", "rta": "aux_incorrecto",
}
const TOPICO_AT := "06:50"
const TOPICO_FATIGA := 88.0  # v0.3.2-core3: con esta Fatiga pide el tópico aunque no sea la hora

var bot: Node = null
var fault: String = ""
var task: String = ""  # "", "feedback", "training", "evento", "topico", "guardia"
var mistakes: int = 0
var log_lines: Array[String] = []
var _hub: PersonajesP5 = null
var _topico_asked: int = 0
var _t: float = 0.0
var _wait_return: bool = false
var _interrupted: String = ""
var _rta_ignored: bool = false
var _rta_log_t: float = 0.0


func setup(p_bot: Node, p_fault: String) -> void:
	bot = p_bot
	fault = p_fault


func expected_cause() -> String:
	return str(FAULTS.get(fault, ""))


func _log(s: String) -> void:
	log_lines.append(s)
	print("[bot·p5] %s %s" % [GameState.clock_text(), s])


func reset_run() -> void:
	task = ""
	mistakes = 0
	_topico_asked = 0
	_wait_return = false
	_hub = null
	_rta_ignored = false
	if fault == "rta":
		bot.set("_lunch_done", true)  # no toma el lunch: lo decide _tick_rta


## Conecta las señales del PersonajesP5 del turno (cambia con cada turno).
func _bind() -> void:
	var h := PersonajesP5.get_hub(get_tree())
	if h == null or h == _hub:
		return
	_hub = h
	# v0.3.2: al cambiar de turno el mismo PersonajesP5 puede volver a engancharse (antes: «already connected» × 8).
	for pair in [[h.qa_called, _on_qa_called], [h.haime_feedback_finished, _on_feedback_done], [h.training_called, _on_training_called], [h.training_released, _on_training_released], [h.rasec_event_called, _on_event_called], [h.rasec_event_finished, _on_event_done], [h.rasec_warning, _on_rasec_warning], [h.topico_granted, _on_topico_granted]]:
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])
	h.rasec.forced_play = "ok"
	if _p3_variant() in ["available", "isla"]:
		h.rta.process_mode = Node.PROCESS_MODE_DISABLED
		_log("(variante %s de P3) RTA apagado: la falta es otra, no el AUX (BO sin allocation)" % _p3_variant())
	if fault == "quiz":
		h.training.forced_answers = [-2, -2, -2, -2, -2]
	else:
		h.training.forced_answers = [-1, -1, -1, -1, -1]


## El bot humano del stress_bot (null si no hay).
func _h() -> Node:
	return bot.get("_human") if bot != null and "_human" in bot else null


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Variante torpe de P3 del stress_bot ("" = ninguna) y si ya cometió su falta (estado "torpe").
func _p3_variant() -> String:
	return str(bot.get("_variant")) if bot != null and "_variant" in bot else ""


func _p3_fault_on() -> bool:
	return _p3_variant() != "" and str(bot.get("_state")) == "torpe"


## ¿Toma el control el bot P5? (el stress_bot no toca nada mientras task != "").
func busy() -> bool:
	return task != ""


# --- arranque: la revisión de Don Fermín -------------------------------------------------------

## En "boot": si Don Fermín espera la revisión, la hace y pasa el molinete antes de subir. true = sigue.
func handle_boot() -> bool:
	var g := get_tree().get_first_node_in_group("p5_guardia")
	if g == null or bool(GameState.flags.get("revision_ok", false)) or not bool(GameState.flags.get("guardia_revision_activa", false)):
		return false
	if task == "":
		task = "guardia"
		_log("revisión de Don Fermín")
		g.call("start_check")
	return true


func _tick_guard() -> void:
	if not bool(GameState.flags.get("revision_ok", false)):
		return
	var b := _building()
	var turn := b.floor_node.find_child("Molinete0", true, false) as Interactable if b != null else null
	if turn != null:
		turn.interact(_player())
	task = ""
	_log("revisión ok, molinete")


# --- contactos: un error honesto por turno para que Haime llame -------------------------------

## Camino del árbol con una marca de QA, sin correo y, si se puede, sin cliente molesto. [] si no hay.
static func mistake_path(c: Dictionary) -> Array:
	var pod := bool((c.get("portal", {}) as Dictionary).get("pod", true))
	var best: Array = []
	var best_score := -INF
	for p in DialogTree.enumerate_paths(c):
		var ok := true
		for s in p:
			if str(s.get("r", "")) == ("pod_no" if pod else "pod_ok"):
				ok = false
		if not ok:
			continue
		var sim := DialogTree.simulate(c, p)
		if (sim.get("qa", []) as Array).is_empty() or bool(sim.get("correo", false)):
			continue
		var score := 0.0
		match str(sim.get("resultado", "")):
			"satisfecho": score = 50.0
			"neutral": score = 40.0
			"molesto": score = -50.0
		score -= p.size()
		if score > best_score:
			best_score = score
			best = p
	return best


## El stress_bot pregunta qué camino seguir en este contacto. [] = el mejor.
func path_for(c: Dictionary) -> Array:
	var want := false
	if _p3_variant() != "":
		return []  # variante de P3: sin error honesto (Haime no interviene en su falta)
	if fault == "qa3":
		want = true
	elif _h() != null and fault == "":
		# Bot humano: 1 marca de QA cada 5 contactos, como mucho max−1 en el turno (Haime nunca llega a la fatal).
		var n := int(bot.get("_h_contacts"))
		var cap := (_hub.qa.max_per_shift() - 1) if _hub != null else 2
		want = n > 0 and n % 5 == 0 and mistakes < cap and GameState.clock_seconds < 7.5 * 3600.0
	elif fault in ["", "qa", "training", "quiz", "rasec", "topico", "rta"] and mistakes == 0 and GameState.clock_seconds > 25.0 * 60.0 and GameState.clock_seconds < 6.0 * 3600.0:
		want = true
	if not want:
		return []
	var p := mistake_path(c)
	if not p.is_empty():
		mistakes += 1
		_log("error honesto en %s (marca de QA para Haime)" % str(c.get("id", "")))
	return p


# --- Haime ---------------------------------------------------------------------------------------

func _interrupt() -> void:
	var st := str(bot.get("_state"))
	if st == "h":
		st = str(bot.get("_h_doing"))  # el humano estaba caminando: break, lunch, baño o volviendo
	_interrupted = st
	if _h() != null:
		_h().cancel()  # corta el traslado en curso (break, lunch, baño, volver): ahora manda el personaje
	if st == "break":
		bot.set("_breaks_done", int(bot.get("_breaks_done")) + 1)
	elif st == "lunch":
		bot.set("_lunch_done", true)
	bot.set("_state", "p5")


func _on_qa_called(n: int) -> void:
	_log("Haime llama (feedback %d)" % n)
	if _p3_fault_on():
		_log("(variante %s de P3, en su falta) no atiende" % _p3_variant())
		return
	if fault == "qa":
		_log("(torpe) no va")
		return
	_interrupt()
	task = "feedback"
	if _h() != null:
		await _h().wait(_h().t_react())
		Metrics.set_aux(Metrics.Aux.COACHING)
		await _h().go_sit(2, "calibracion")
		return
	Metrics.set_aux(Metrics.Aux.COACHING)
	var p := _player()
	if p.seated:
		p.stand_up()
	var b := _building()
	if b.current_floor != 2:
		b.go_to_floor(2, "ascensor")
	await get_tree().create_timer(0.5).timeout
	if task != "feedback" or not is_inside_tree():
		return
	var fl := b.floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D if fl != null else null
	if seat != null:
		_player().sit_at(seat, "calibracion")


func _on_feedback_done(n: int, fatal: bool) -> void:
	_log("feedback %d terminado%s" % [n, " (fatal)" if fatal else ""])
	if not fatal:
		_back_to_seat()


# --- Trainer -------------------------------------------------------------------------------------

func _on_training_called() -> void:
	_log("el Trainer convoca")
	if _p3_fault_on():
		_log("(variante %s de P3, en su falta) no atiende" % _p3_variant())
		return
	if fault == "training":
		# v0.3.1: pone el AUX que dicta el RTA pero no baja. Con la convocatoria a 4x (C3) el plazo del Trainer dura
		# 3 min reales y la caza del RTA por no poner Training llegaba antes: la falta que se prueba es no bajar.
		Metrics.set_aux(Metrics.Aux.TRAINING)
		_log("(torpe) pone Training pero no baja")
		return
	_interrupt()
	task = "training"
	if _h() != null:
		await _h().wait(_h().t_react())
		Metrics.set_aux(Metrics.Aux.TRAINING)
		await _h().go_sit(1, "training_sala2_3")
		return
	Metrics.set_aux(Metrics.Aux.TRAINING)
	var p := _player()
	if p.seated:
		p.stand_up()
	_building().go_to_floor(1, "ascensor")
	await get_tree().create_timer(0.5).timeout
	if task != "training" or not is_inside_tree():
		return
	var fl := _building().floor_node as FloorBase
	var seat := fl.find_child("Seat_training_sala2_3", true, false) as Node3D if fl != null else null
	if seat != null:
		_player().sit_at(seat, "training_sala2_3")


func _on_training_released() -> void:
	_log("training aprobado (%d/5), vuelve a la sala" % (_hub.training.last_score if _hub != null else -1))
	_back_to_seat()


# --- Rasec ---------------------------------------------------------------------------------------

func _on_event_called(kind: String) -> void:
	_log("evento de Rasec: %s" % kind)
	if _p3_fault_on():
		_log("(variante %s de P3, en su falta) no atiende" % _p3_variant())
		return
	if fault == "rasec":
		_log("(torpe) 'No, gracias'")
		var hz := EzlakHub.get_hub(get_tree())
		hz.quick_reply("dm:rasec", "no_gracias")
		await get_tree().create_timer(1.0).timeout
		hz.quick_reply("dm:rasec", "no_gracias")
		return
	_interrupt()
	task = "evento"
	if _h() != null:
		await _h().wait(_h().t_react())
		EzlakHub.get_hub(get_tree()).quick_reply("dm:rasec", "voy")
		Metrics.set_aux(Metrics.Aux.BO)
		await _h().go_marker(2, "evento_rasec", Vector3.ZERO, 2.6)  # radio del evento: 3,2 m
		return
	EzlakHub.get_hub(get_tree()).quick_reply("dm:rasec", "voy")
	Metrics.set_aux(Metrics.Aux.BO)
	var p := _player()
	if p.seated:
		p.stand_up()
	var b := _building()
	if b.current_floor != 2:
		b.go_to_floor(2, "ascensor")
		await get_tree().create_timer(0.5).timeout
	var m := b.floor_node.find_child("evento_rasec", true, false) as Node3D
	if m != null:
		_player().teleport(m.global_position, 0.0)


func _on_rasec_warning(n: int, r: String) -> void:
	_log("advertencia de Rasec %d (%s)" % [n, r])


func _on_event_done(_kind: String, _took: bool) -> void:
	_log("evento terminado (Available %d %%)" % int(Metrics.available_pct()))
	_back_to_seat()


# --- tópico --------------------------------------------------------------------------------------

func _maybe_topico() -> void:
	if GameState.turno < 2 or _topico_asked >= (2 if fault == "topico" else 1) or task != "":
		return
	if str(bot.get("_state")) != "work" or _hub == null or not _hub.can_interrupt():
		return
	# v0.3.2-core3: a su hora de siempre o, como haría cualquiera, cuando ya no puede más (Fatiga alta).
	if GameState.clock_seconds < GameState.hhmm_to_seconds(TOPICO_AT) and not (fault == "" and Fatigue.value >= TOPICO_FATIGA and _topico_asked == 0):
		return
	_topico_asked += 1
	_log("'Me siento mal' (%d)" % _topico_asked)
	EzlakHub.get_hub(get_tree()).quick_reply("dm:shero", "me_siento_mal")
	if fault == "topico" and _topico_asked == 1:
		await get_tree().create_timer(2.0).timeout
		_topico_asked += 1
		_log("'Me siento mal' otra vez (torpe)")
		EzlakHub.get_hub(get_tree()).quick_reply("dm:shero", "me_siento_mal")


func _on_topico_granted() -> void:
	_interrupt()
	task = "topico"
	if _h() != null:
		await _h().wait(_h().t_ack())
		Metrics.set_aux(Metrics.Aux.BANO)
		var fl1 := _building().floor_node if _building().current_floor == 1 else null
		var mk := fl1.find_child("topico", true, false) as Node3D if fl1 != null else null
		# v0.3.1 pisos: hacia adentro del cuarto según la base del marcador (su +Z local mira a la puerta).
		var into := -mk.global_transform.basis.z * 0.6 if mk != null else Vector3(0.6, 0, 0)
		await _h().go_marker(1, "topico", into, 1.7)  # llegada al tópico: 2,4 m del marcador
		return
	Metrics.set_aux(Metrics.Aux.BANO)
	var p := _player()
	if p.seated:
		p.stand_up()
	_building().go_to_floor(1, "ascensor")
	await get_tree().create_timer(0.5).timeout
	if task != "topico" or not is_inside_tree():
		return
	var m := _building().floor_node.find_child("topico", true, false) as Node3D
	if m != null:
		_player().teleport(m.global_position - m.global_transform.basis.z * 0.6, m.global_rotation_degrees.y + 180.0)


func _tick_topico() -> void:
	if _hub != null and _hub.topico.state == TopicoControl.State.ALTA:
		_log("alta del tópico (Fatiga %d)" % int(Fatigue.value))
		_back_to_seat()


# --- RTA (torpe) ---------------------------------------------------------------------------------

## Variante rta: a la hora del lunch el RTA ordena Lunch en #allocations; el torpe lo ignora y se pone en BO.
func _tick_rta() -> void:
	if fault == "rta" and _rta_ignored and _hub != null and _t - _rta_log_t > 10.0:
		_rta_log_t = _t
		_log("RTA: AUX %s, esperado %s, motivo '%s', %.0f s incorrecto, strikes %d" % [Metrics.aux_name(), Metrics.aux_name(Metrics.expected_aux), _hub.rta.wrong_reason(), _hub.rta.wrong_elapsed, _hub.rta.strikes()])
		if P5Pursuit.is_hunting("rta"):
			var inf := Pursuit.info("rta")
			_log("  caza rta: estado %s, llega en %.1f, espacio %s, distancia %.1f, pos %s" % [str(inf.get("state", "")), float(inf.get("arrive_left", 0.0)), str(inf.get("space", "")), float(inf.get("dist", -1.0)), str(inf.get("pos", "-"))])
	if fault != "rta" or _rta_ignored or str(bot.get("_state")) != "work" or GameState.clock_seconds < GameState.lunch_clock():
		return
	_rta_ignored = true
	_log("(torpe) ignora la orden de Lunch del RTA y se queda en BO")
	Metrics.set_aux(Metrics.Aux.BO)


# --- vuelta al sitio -----------------------------------------------------------------------------

func _back_to_seat() -> void:
	task = "volver"
	var b := _building()
	if b == null:
		task = ""
		return
	if _h() != null:
		await _h().wait(_h().t_ack())
		if _building() == null:
			task = ""
			return
		await bot.call("_human_back_to_seat", true)
		if task == "volver":
			task = ""
		return
	if b.current_floor != 2:
		b.go_to_floor(2, "entrada_sala")
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	if task != "volver":
		return  # v0.3.2: otro te convocó mientras volvías (Rasec llama justo al alta del tópico): manda esa tarea
	var p := _player()
	if p == null or _building() == null:
		task = ""
		return  # volvió al menú mientras tanto (verificación tras la muerte)
	if p.seated:
		p.stand_up()
	bot.call("_return_to_seat", _building(), _player())
	task = ""


func _process(delta: float) -> void:
	_t += delta
	_bind()
	if Checkpoints.dying:
		return
	match task:
		"guardia":
			_tick_guard()
		"topico":
			_tick_topico()
		"":
			_maybe_topico()
			_tick_rta()


## Tras una muerte (listo): el bot reaparece en su sitio; lo que estaba haciendo P5 se cancela.
func on_death() -> void:
	task = ""


## v0.3.2-core3: ya reapareció. El tópico se pide según lo que dice el juego (el contador vuelve con el checkpoint, y la
## ayuda de la segunda muerte seguida lo pone a cero): si está disponible otra vez, el bot lo vuelve a pedir.
func after_respawn() -> void:
	_bind()
	if fault == "" and _hub != null and _hub.topico != null:
		_topico_asked = _hub.topico.requests()

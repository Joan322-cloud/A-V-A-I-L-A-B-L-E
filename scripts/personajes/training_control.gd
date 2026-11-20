class_name TrainingControl
extends Node
## Trainer · AUX Training (PLAN §2 #35-38 y #82; cerebro persistente; en el piso 1 actúan trainer.gd y
## training_session.gd). En el juego se llama solo "Trainer"; su grito es "GAAAA".
## 1. 00:10 anuncio en #site-updates. 2. A la hora del turno (T2 02:20, T3 01:40; si estás en un contacto,
##    espera a que termines): DM del Trainer + orden del RTA en #allocations + Metrics.authorize(TRAINING,
##    "trainer", "piso_1") → puedes salir de la sala y bajar al piso 1 (sala 2, la silla libre del extremo).
## 3. Hay que sentarse en la sala 2 (v0.3.1, F4: la silla no tiene PC; si no estás en Training, el Trainer te pone
##    él mismo; cuenta como llegar a tiempo). Mientras te espera el reloj va a 4x (C3). 8 min sin llegar → DM "Te estoy esperando"; 12 min → el Trainer
##    te persigue por todo el edificio (P5Pursuit) → `training_inasistencia`.
## 4. Sesión de 30 min de juego (reloj "training", 12x) con Discipline.freeze(true, "training"): clase y QUIZ.
##    El quiz PAUSA el reloj (override "quiz" = 0x, PLAN #82). Reprobar = `training_reprobado` (screamer del Trainer
##    en la pizarra).
##    v0.3.2 (feedback de Joan): cada día es distinto (training.json/dias → day_info(): tema, pizarra, clase, banco
##    de preguntas y mezcla; los bancos del martes y del miércoles no comparten preguntas) y la nota mínima sube en
##    los últimos turnos (turnos.json/quiz_aprobar → pass_mark(): martes Fácil 2 · Normal 3 · Difícil 4; miércoles
##    3 · 4 · 4, siempre de 5). La nota se ve en el anuncio, en el DM del llamado, en Campus, en la pizarra de la
##    sala y en el quiz; lo que DICE el Trainer al aprobar o reprobar no lleva números (voz = subtítulo).
## 5. Salir de la sala 2 durante la sesión: "¿A dónde vas?", 1 min de gracia y persecución.
## 6. Al terminar te suelta (training_released / EventBus.training_ended(true)): la vuelta tardía a la sala
##    es la pista "regreso tardío" de Shero (P3).
## Estado con checkpoint: Discipline.counters p5_training ("" | "hecho"), p5_training_intentos.

enum State { LIBRE, LLAMADO, SESION, QUIZ, PERSIGUE, HECHO }

var hub: PersonajesP5 = null
var state: int = State.LIBRE
var called_at: float = 0.0
var session_at: float = 0.0
var escape_at: float = -1.0
var announced: bool = false
var waited_since: float = -1.0
var espera_warned: bool = false
var hint_given: bool = false
var quiz: QuizUI = null
var last_score: int = -1
var said: Array[String] = []  # líneas de la sesión (pruebas)
var _class_i: int = 0
var _quiz_done: bool = false
var _passed: bool = false
var _token: int = 0
## Pruebas/bot: respuestas forzadas (índices de la opción elegida por pregunta; -1 = la correcta).
var forced_answers: Array = []


func _cfg() -> Dictionary:
	return DataLoader.dict("training")


## Lo propio del día (training.json/dias/<turno>): {tema, quiz_titulo, pizarra, clase, preguntas, mezcla, fija,
## quiz_en_min, duracion_min}. Un turno sin entrada hereda la del día anterior más cercano; si no hay ninguna, {}
## (vale lo general del archivo: clase, mezcla y el banco entero).
static func day_info(turno: int = -1) -> Dictionary:
	var t := GameState.turno if turno < 0 else turno
	var dias: Dictionary = DataLoader.dict("training").get("dias", {})
	var best := -1
	for k in dias.keys():
		if str(k).is_valid_int() and int(k) <= t and int(k) > best:
			best = int(k)
	return dias.get(str(best), {}) if best >= 0 else {}


## Nota mínima del quiz (de 5) en ese turno: turnos.json/quiz_aprobar [Fácil, Normal, Difícil] del turno o del día
## anterior más cercano que la traiga; si ninguno, dificultad.json/valores/quiz_aprobar.
static func pass_mark(turno: int = -1) -> int:
	var t := GameState.turno if turno < 0 else turno
	while t >= 1:
		var row: Variant = GameState.turno_data(t).get("quiz_aprobar", null)
		if row is Array and not (row as Array).is_empty():
			var arr := row as Array
			return int(arr[clampi(Difficulty.effective(), 0, arr.size() - 1)])
		t -= 1
	return int(Difficulty.value("quiz_aprobar", 3))


## Las líneas de la clase de hoy, en orden (la primera es la bienvenida).
func class_lines() -> Array:
	var c: Variant = day_info().get("clase", null)
	return c if c is Array and not (c as Array).is_empty() else _cfg().get("clase", [])


func _day_num(key: String, default: float) -> float:
	var day := day_info()
	return float(day.get(key, _cfg().get(key, default)))


func _ready() -> void:
	EventBus.respawned.connect(_on_respawned)
	EventBus.death_sequence_started.connect(_on_death)


func enabled() -> bool:
	return GameState.training_clock() >= 0.0


func done() -> bool:
	return str(PersonajesP5.counter("p5_training", "")) == "hecho"


func _seat_ok() -> bool:
	return GameState.seated_at.begins_with("training_sala2")


func _trainer_node() -> Node:
	return get_tree().get_first_node_in_group("trainer")


func _process(_delta: float) -> void:
	if not enabled() or not GameState.logged_in or Checkpoints.dying or not GameState.running:
		return
	var now := GameState.clock_seconds
	if not announced and now >= GameState.hhmm_to_seconds(str(_cfg().get("anuncio_hora", "00:10"))):
		announced = true
		if now < GameState.training_clock():
			PersonajesP5.post("#site-updates", "trainer", PersonajesP5.line("lineas_trainer", "anuncio", {"hora": GameState.clock_text_at(GameState.training_clock()), "tema": Loc.pick(day_info().get("tema", {})), "min": pass_mark()}), {"tipo": "training_anuncio"})
	match state:
		State.LIBRE:
			if done() or now < GameState.training_clock():
				return
			if hub.can_interrupt(false, "trainer"):
				call_now()
			else:
				if waited_since < 0.0:
					waited_since = now
				if now - waited_since >= float(_cfg().get("retraso_max_min", 20.0)) * 60.0 and hub.busy == "" and not Checkpoints.in_respawn_grace() and not Discipline.is_lunch_immune("trainer"):
					call_now()  # aunque sigas en un contacto: el Trainer no espera más
		State.LLAMADO:
			_tick_called(now)
		State.SESION:
			_tick_session(now)


## El Trainer te convoca (también lo usan las pruebas).
func call_now() -> void:
	state = State.LLAMADO
	called_at = GameState.clock_seconds
	espera_warned = false
	hint_given = false
	Discipline.hold_slow_clock("trainer", true)  # F20 (C3)
	Metrics.authorize(Metrics.Aux.TRAINING, "trainer", "piso_1", -1.0)
	PersonajesP5.post("dm:trainer", "trainer", PersonajesP5.line("lineas_trainer", "llamado", {"agente": GameState.agent, "min": pass_mark()}), {"tipo": "training_llamado", "mention": true, "typing_s": 1.5, "quick_replies": ["voy", "ok"]})
	PerritoRTA.dictate(Metrics.Aux.TRAINING)
	EventBus.training_called.emit()
	hub.training_called.emit()


func _tick_called(now: float) -> void:
	var elapsed := now - called_at
	if _seat_ok():
		if Metrics.aux != Metrics.Aux.TRAINING:
			# v0.3.1 (F4): «Te pongo en Training yo»; la silla no tiene PC (texto en strings_v031_q1: lineas_trainer es de Q3).
			said.append("pone_training")
			PersonajesP5.say("Trainer", "trainer", "pone_training", tr("Q1_TRAINER_PONE_TRAINING"))
			Metrics.set_aux(Metrics.Aux.TRAINING)
		_start_session()
		return
	if not espera_warned and elapsed >= PersonajesP5.plazo(float(_cfg().get("espera_min", 8.0))):
		espera_warned = true
		PersonajesP5.post("dm:trainer", "trainer", PersonajesP5.line("lineas_trainer", "espera"), {"tipo": "training_espera", "mention": true})
	if elapsed >= PersonajesP5.plazo(float(_cfg().get("persecucion_min", 12.0))):
		_hunt()


## Persecución en todo el edificio (no llegaste o te escapaste).
func _hunt() -> void:
	state = State.PERSIGUE
	_token += 1
	Discipline.hold_slow_clock("trainer", false)
	_end_freeze()
	var from := Vector3.INF
	var tn := _trainer_node() as Node3D
	if GameState.current_floor == 1 and tn != null:
		from = tn.global_position
		tn.visible = false
	PersonajesP5.pa(PersonajesP5.line("lineas_trainer", "persecucion"), "trainer", "persecucion")
	AudioManager.play_voice("trainer", "trainer_risa", "", "Sala")
	P5Pursuit.start("trainer", "training_inasistencia", float(_cfg().get("velocidad_caza_ms", 4.4)), null, "", 1, from)


func _start_session() -> void:
	state = State.SESION
	_token += 1
	Discipline.hold_slow_clock("trainer", false)
	session_at = GameState.clock_seconds
	escape_at = -1.0
	_class_i = 0
	_quiz_done = false
	_passed = false
	said.clear()
	hub.busy = "training"
	Discipline.freeze(true, "training")
	GameState.set_clock_override("training")
	hub.hide_pc("training", true)
	var tn := _trainer_node()
	if tn != null and tn.has_method("set_session"):
		tn.call("set_session", true)
	EventBus.training_started.emit()
	hub.training_started.emit()
	var clase := class_lines()
	_say(str(clase[0]) if not clase.is_empty() else "bienvenida")
	PersonajesP5.set_counter("p5_training_intentos", int(PersonajesP5.counter("p5_training_intentos", 0)) + 1)


func session_minutes() -> float:
	return (GameState.clock_seconds - session_at) / 60.0 if state in [State.SESION, State.QUIZ] else 0.0


func _tick_session(now: float) -> void:
	# ¿Se fue de la sala 2? 1 min de juego de gracia (al reloj de pie) y persecución.
	if not _seat_ok():
		if escape_at < 0.0:
			escape_at = now
			GameState.clear_clock_override("training")
			_say("escapa")
		elif now - escape_at >= PersonajesP5.plazo(float(_cfg().get("escapa_gracia_min", 1.0))):
			_hunt()
		return
	if escape_at >= 0.0:
		escape_at = -1.0
		GameState.set_clock_override("training")
	var m := (now - session_at) / 60.0
	var clase := class_lines()
	var quiz_at := _day_num("quiz_en_min", 22.0)
	if not _quiz_done:
		# La clase se reparte entre el minuto 0 y el del quiz.
		var step := quiz_at / maxf(clase.size(), 1.0)
		var want := int(m / step)
		while _class_i < clase.size() and _class_i <= want:
			if _class_i > 0:
				_say(str(clase[_class_i]))
			if _class_i == 2:
				_say("siluetas")
			_class_i += 1
		if m >= quiz_at:
			_open_quiz()
		return
	if m >= _day_num("duracion_min", 30.0):
		_release()


func _open_quiz() -> void:
	state = State.QUIZ
	_say("quiz_intro")
	GameState.set_clock_override("quiz")  # el reloj se detiene mientras respondes (PLAN #82)
	var pl := hub.player()
	if pl != null:
		pl.input_locked = true
	quiz = QuizUI.new()
	quiz.name = "QuizUI"
	add_child(quiz)
	var qs := pick_questions(int(PersonajesP5.counter("p5_training_intentos", 1)) * 97 + GameState.turno)
	var need := pass_mark()
	quiz.finished.connect(_on_quiz_finished)
	quiz.answered.connect(func(_i: int, ok: bool) -> void:
		_say("quiz_bien" if ok else "quiz_mal")
		if not ok:
			AudioManager.play_sfx("trainer_golpe"))
	quiz.open(qs, need, bool(Difficulty.value("quiz_pista", false)), forced_answers, Loc.pick(day_info().get("quiz_titulo", {})))


## 5 preguntas del banco de HOY (training.json/dias/<turno>/preguntas; sin él, el banco entero) con la mezcla de
## categorías del día, opciones barajadas. `fija` = {id, pos}: esa pregunta sale siempre, en ese puesto (el martes,
## la 4.ª es «¿Cuántos breaks hay por turno?»).
func pick_questions(seed_v: int, turno: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var day := day_info(turno)
	var allowed: Array = day.get("preguntas", [])
	var fixed: Dictionary = day.get("fija", {})
	var fixed_q: Dictionary = {}
	var by_cat: Dictionary = {}
	for q in _cfg().get("preguntas", []):
		var qd := q as Dictionary
		if not allowed.is_empty() and not allowed.has(str(qd.get("id", ""))):
			continue
		if not fixed.is_empty() and str(qd.get("id", "")) == str(fixed.get("id", "")):
			fixed_q = qd
			continue
		var c := str(qd.get("cat", "aux"))
		if not by_cat.has(c):
			by_cat[c] = []
		(by_cat[c] as Array).append(q)
	var out: Array = []
	var mix: Dictionary = (day.get("mezcla", _cfg().get("mezcla", {"kyc": 2, "vitzo": 1, "aux": 1, "proceso": 1})) as Dictionary).duplicate()
	if not fixed_q.is_empty():  # la fija ocupa uno de los puestos de su categoría
		var fc := str(fixed_q.get("cat", "aux"))
		mix[fc] = maxi(int(mix.get(fc, 0)) - 1, 0)
	for c in mix.keys():
		var pool: Array = (by_cat.get(c, []) as Array).duplicate()
		for k in int(mix[c]):
			if pool.is_empty():
				break
			out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	# Baraja el orden de las preguntas y de las opciones (la correcta cambia de lugar).
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	if not fixed_q.is_empty():
		out.insert(clampi(int(fixed.get("pos", 1)) - 1, 0, out.size()), fixed_q)
	var final: Array = []
	for q in out:
		var qd: Dictionary = (q as Dictionary).duplicate(true)
		var opts: Array = qd.get("opciones", [])
		var idx: Array = range(opts.size())
		for i in range(idx.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: Variant = idx[i]
			idx[i] = idx[j]
			idx[j] = t
		var new_opts: Array = []
		var corr := int(qd.get("correcta", 0))
		for k in idx.size():
			new_opts.append(opts[int(idx[k])])
			if int(idx[k]) == corr:
				qd["correcta"] = k
		qd["opciones"] = new_opts
		final.append(qd)
	return final


func _on_quiz_finished(score: int, total: int, passed: bool) -> void:
	last_score = score
	_quiz_done = true
	_passed = passed
	var tok := _token
	var pl := hub.player()
	hub.training_finished.emit(passed)
	if not passed:
		_say("reprobado")  # sin números: el mínimo y tu nota están en la pizarra del quiz (la voz dice lo mismo que el subtítulo)
		await PersonajesP5.wait(self, 2.2)
		if tok != _token:
			return
		if quiz != null and is_instance_valid(quiz):
			quiz.queue_free()
		quiz = null
		EventBus.training_ended.emit(false)
		Checkpoints.request_death("training_reprobado", "%d/%d" % [score, total], "trainer")
		return
	_say("aprobado")
	await PersonajesP5.wait(self, 1.6)
	if tok != _token:
		return
	if quiz != null and is_instance_valid(quiz):
		quiz.queue_free()
	quiz = null
	if pl != null:
		pl.input_locked = false
	state = State.SESION
	GameState.set_clock_override("training")
	_say("repaso")


func _release() -> void:
	state = State.HECHO
	_token += 1
	PersonajesP5.set_counter("p5_training", "hecho")
	_say("alta")
	_end_freeze()
	Metrics.revoke("trainer")
	EventBus.training_ended.emit(true)
	hub.training_released.emit()


func _end_freeze() -> void:
	Discipline.freeze(false, "training")
	if hub != null:
		hub.hide_pc("training", false)
	GameState.clear_clock_override("training")
	GameState.clear_clock_override("quiz")
	if hub != null and hub.busy == "training":
		hub.busy = ""
	var tn := _trainer_node()
	if tn != null and tn.has_method("set_session"):
		tn.call("set_session", false)
	var pl := hub.player() if hub != null else null
	if pl != null and not Checkpoints.dying and state != State.QUIZ:
		pl.input_locked = false
	if quiz != null and is_instance_valid(quiz):
		quiz.queue_free()
	quiz = null


func _say(key: String, vars: Dictionary = {}) -> void:
	said.append(key)
	var text := PersonajesP5.line("lineas_trainer", key, vars)
	if key == "siluetas":
		EventBus.subtitle.emit("trainer", text, 4.0)
		return
	PersonajesP5.say("Trainer", "trainer", key, spoken_text(key, text))


## Lo que se LEE cuando el Trainer habla (Joan: el subtítulo dice lo mismo que la voz, siempre). Es el texto de la
## línea mientras sea lo que dice su voz (data/audio_index.json/textos); si alguien cambió la línea sin volver a
## sintetizarla, manda lo que se oye. La batería v032_fbmt (fbmt_voz) falla si una línea hablada difiere de su voz.
static func spoken_text(key: String, text: String) -> String:
	var t: Dictionary = (DataLoader.dict("audio_index").get("textos", {}) as Dictionary).get("voces/trainer/" + key, {})
	var heard := str(t.get(Loc.language, ""))
	if heard == "" or _plain(heard) == _plain(text):
		return text
	return heard


static func _plain(s: String) -> String:
	var out := s.strip_edges()
	for pair: Array in [["«", "\""], ["»", "\""], ["“", "\""], ["”", "\""], ["’", "'"], ["  ", " "]]:
		out = out.replace(str(pair[0]), str(pair[1]))
	return out


func _on_death(_c: String, _k: String, _d: String) -> void:
	_token += 1
	Discipline.hold_slow_clock("trainer", false)
	if state in [State.SESION, State.QUIZ, State.LLAMADO, State.PERSIGUE]:
		_end_freeze()
		Metrics.revoke("trainer")
	var tn := _trainer_node() as Node3D
	if tn != null:
		tn.visible = true


## Tras reaparecer: si el training no quedó hecho en el checkpoint, el Trainer vuelve a convocarte.
func _on_respawned(_k: String) -> void:
	_token += 1
	if state in [State.SESION, State.QUIZ] or (quiz != null and is_instance_valid(quiz)):
		_end_freeze()  # normalmente ya lo hizo _on_death; por si el respawn llega sin muerte
	state = State.HECHO if done() else State.LIBRE
	waited_since = -1.0
	announced = GameState.clock_seconds >= GameState.hhmm_to_seconds(str(_cfg().get("anuncio_hora", "00:10")))
	var tn := _trainer_node() as Node3D
	if tn != null:
		tn.visible = true

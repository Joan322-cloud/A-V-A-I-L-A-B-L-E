extends Node
## Don Fermín, el guardia del lobby (piso -1), PLAN §2 #48 y DIALOGOS §7: comportamiento de piso
## (data/comportamientos.json → marcador fermin_puesto). Al llegar, el molinete de entrada no abre sin su
## revisión (GameState.flags guardia_revision_activa / revision_ok, bandera de P2 en WorldObjects.Turnstile).
## Revisión de 4 pasos (fotocheck, mochila, detector, celular; 3-4 s cada uno) con sus líneas: se activa al
## acercarte al mostrador (zona "guardia") o te llama él si intentas pasar el molinete. Cada paso emite
## EventBus.guard_check(paso). Desde el turno 2 hay algo raro en sus líneas (el fotocheck dice que ya
## entraste, un fotocheck de la C-13 en tu mochila, el detector que pita "por dentro"). Saluda al salir a las
## 08:45 y comenta si pasas corriendo durante una persecución. Modelo v2 "guardia_fermin" si está.

const STEPS: Array[String] = ["fotocheck", "mochila", "detector", "celular"]
const STEP_S := 3.4

var floor_node: FloorBase = null
var actor: P5Actor = null
var fig: Node3D = null
var checking: bool = false
var steps_done: Array[String] = []
var _called: bool = false
var _huye_cd: float = 0.0
var _token: int = 0


func setup_behaviour(fl: Node, _marker: Node, _entry: Dictionary) -> void:
	floor_node = fl as FloorBase
	add_to_group("p5_guardia")
	PersonajesP5.ensure(get_tree())
	if not GameState.shift_over and not GameState.logged_in and not bool(GameState.flags.get("revision_ok", false)) and not bool(GameState.flags.get("clocked_in", false)):
		GameState.flags["guardia_revision_activa"] = true
	GameState.flags["fermin_saludo"] = true  # su saludo lo da la revisión (no el de P2)
	GameState.flags["fermin_despedida"] = true  # y la despedida de las 08:45 también (línea "salida")
	fig = floor_node.find_child("Fermin", true, false) as Node3D
	if fig != null and P5Actor.model_path("guardia_fermin") != "":
		var pos := fig.global_position
		var rot := fig.global_rotation.y
		fig.visible = false
		for n in ["GorraFermin", "ViseraFermin"]:
			var c := floor_node.find_child(n, true, false) as Node3D
			if c != null:
				c.visible = false
		actor = P5Actor.make(floor_node, "guardia_fermin", 1.76, Vector3.ZERO, 0.0, "DonFermin")
		actor.global_position = pos
		actor.rotation.y = rot
		actor.floor_ref = floor_node
		actor.play("idle", true, 0.7)
	EventBus.player_entered_zone.connect(_on_zone)
	EventBus.guard_check.connect(_on_guard_signal)
	EventBus.death_sequence_started.connect(_on_death)


func _say(key: String) -> void:
	var text := Loc.pick((DataLoader.dict("lineas_neutrales").get("fermin", {}) as Dictionary).get(key, {}))
	PersonajesP5.say("Don Fermín", "otros", "fermin_" + key, text)


## Variante del paso según el turno (desde T2 algo no cuadra).
func _variant(step: String) -> String:
	var d: Dictionary = DataLoader.dict("lineas_neutrales").get("fermin", {})
	for t in [GameState.turno, 3, 2]:
		if int(t) <= GameState.turno and d.has("%s_t%d" % [step, int(t)]):
			return "%s_t%d" % [step, int(t)]
	return step


func needs_check() -> bool:
	return bool(GameState.flags.get("guardia_revision_activa", false)) and not bool(GameState.flags.get("revision_ok", false)) and not GameState.shift_over and not GameState.logged_in


func _on_zone(zone: String) -> void:
	if zone == "sin_revision_paso" and needs_check() and not checking:
		_start_fermin_pursuit()
	elif zone == "guardia" and needs_check() and not checking:
		start_check()
	elif zone == "lobby" and GameState.shift_over and not bool(GameState.flags.get("fermin_despedida_p5", false)):
		GameState.flags["fermin_despedida_p5"] = true
		_say("salida")


var _chasing: bool = false

func _on_guard_signal(step: String) -> void:
	if (step == "molinete_bloqueado" or step == "paso_sin_revision") and not checking and needs_check():
		if not _called and step == "molinete_bloqueado":
			_say("alto")
			_called = true
			if actor != null:
				actor.play("point", true, 1.0, ["idle"])
		else:
			_start_fermin_pursuit()

func _start_fermin_pursuit() -> void:
	if _chasing or not needs_check():
		return
	_chasing = true
	_say("sin_revision")
	var start_pos := actor.global_position if actor != null else Vector3(-8.0, 0.0, 12.1)
	Pursuit.start("fermin", "sin_revision", 5.5, null, "Sin revisión en lobby", -1, start_pos, Callable(), {"asesino": "fermin", "sin_aviso": true})


## La revisión de 4 pasos (también la usan las pruebas, el bot y las capturas).
func start_check() -> void:
	if checking or not needs_check():
		return
	checking = true
	_token += 1
	var tok := _token
	steps_done.clear()
	var pl := get_tree().get_first_node_in_group("player") as Player
	var spot := floor_node.find_child("revision_jugador", true, false) as Node3D
	if pl != null:
		pl.input_locked = true
		if spot != null:
			pl.teleport(spot.global_position, spot.global_rotation_degrees.y)
	if actor != null and pl != null:
		actor.look_toward(pl.global_position)
	EventBus.guard_check.emit("inicio")
	_say("tarde" if GameState.clock_seconds > -2.0 * 60.0 else "saludo")
	await _step_wait()
	for st in STEPS:
		if tok != _token:
			return
		_say(_variant(st))
		if actor != null:
			actor.play("point" if st == "fotocheck" else ("hunch" if st == "mochila" else "idle"), true, 0.8, ["idle"])
		if st == "detector":
			AudioManager.play_sfx("detector")
			if GameState.turno >= 3:
				get_tree().create_timer(0.6).timeout.connect(AudioManager.play_sfx.bind("detector"))
		steps_done.append(st)
		EventBus.guard_check.emit(st)
		await _step_wait()
	if tok != _token:
		return
	_say("pase_t%d" % GameState.turno if GameState.turno >= 2 else "pase_limpio")
	GameState.flags["revision_ok"] = true
	checking = false
	if pl != null and is_instance_valid(pl) and not Checkpoints.dying:
		pl.input_locked = false
	if actor != null:
		actor.play("idle", true, 0.7)
	EventBus.guard_check.emit("ok")
	var hub := PersonajesP5.get_hub(get_tree())
	if hub != null:
		hub.guard_check_finished.emit(GameState.turno)


## Pausa entre pasos: STEP_S y, a velocidad real, hasta que Don Fermín termine de decir su línea (duran 4-7 s y los
## pasos iban cada 3,4 s: se apilaban en el VoiceDirector y la última, «Pase, está limpio», vencía sin sonar).
## Acelerado (bots, pruebas) no espera a la voz: la revisión dura lo de siempre en tiempo de juego.
func _step_wait() -> void:
	await PersonajesP5.wait(self, STEP_S)
	if Engine.time_scale > 1.5:
		return
	var left := 9.0
	while left > 0.0 and is_inside_tree() and VoiceDirector.speaker_busy("otros"):
		await get_tree().process_frame
		left -= get_process_delta_time()


func _on_death(_c: String, _k: String, _d: String) -> void:
	_token += 1
	checking = false


func _process(delta: float) -> void:
	if _huye_cd > 0.0:
		_huye_cd -= delta
	if GameState.logged_in and bool(GameState.flags.get("guardia_revision_activa", false)):
		GameState.flags["guardia_revision_activa"] = false  # ya marcaste: el molinete vuelve a ser libre
	if actor == null or not is_instance_valid(actor):
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var near := pl.global_position.distance_to(actor.global_position) < 8.0
	# Te sigue con la mirada; desde T3 no deja de mirarte aunque ya hayas pasado.
	actor.look_toward(pl.global_position if near or GameState.turno >= 3 else Vector3.INF)
	if near and _huye_cd <= 0.0 and P5Pursuit.is_hunting() and Input.is_action_pressed("walk_fast"):
		_huye_cd = 30.0
		_say("huye")

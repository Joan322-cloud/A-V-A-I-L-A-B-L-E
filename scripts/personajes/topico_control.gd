class_name TopicoControl
extends Node
## Tópico (PLAN §2 #65, DIALOGOS §1.8 y §6): solo se entra pidiéndoselo a Shero por Ezlaki ("Me siento mal",
## respuesta rápida del DM de Shero → EventBus.topico_requested). Desde el turno 2 (antes está cerrado).
## - 1.er pedido del turno: permiso (Metrics.authorize(BANO, "topico", "topico", 15 min)); en el piso 1 te
##   atiende el enfermero (escena de ~20 s), Fatiga −15. Una vez por turno está bien.
## - 2.º pedido del turno ("dos veces seguidas"): "¿Otra vez? Work avoiding. Ya bajo." → Shero baja a
##   buscarte (persecución en todo el edificio) → muerte `work_avoiding` (screamer de Shero en el tópico).
##   Si P3 ya lleva la pista "topico" (Discipline.owns_track("topico")), aquí solo queda el permiso y el
##   enfermero y la escalera es de P3.
## - Entrar sin permiso: el enfermero te devuelve al pasillo y Shero lo anota (llamado).
## Estado con checkpoint: Discipline.counters p5_topico_pedidos.

enum State { LIBRE, PERMISO, ATENCION, ALTA, PERSIGUE }

var hub: PersonajesP5 = null
var state: int = State.LIBRE
var permit_until: float = 0.0
var said: Array[String] = []
var _rejected_cd: float = 0.0
var _token: int = 0


func _ready() -> void:
	EventBus.topico_requested.connect(_on_request)
	EventBus.respawned.connect(_on_respawned)
	EventBus.death_sequence_started.connect(_on_death)
	EventBus.room_entered.connect(_on_room_entered)


func requests() -> int:
	return int(PersonajesP5.counter("p5_topico_pedidos", 0))


static func is_open() -> bool:
	return GameState.turno >= int(DataLoader.bal("topico/turno_desde", 2))


static func p3_owns() -> bool:
	return Discipline.has_method("owns_track") and bool(Discipline.call("owns_track", "topico"))


func _shero_line(key: String) -> String:
	return Loc.pick((DataLoader.dict("lineas_neutrales").get("shero_topico", {}) as Dictionary).get(key, {}))


func _on_request() -> void:
	if not GameState.logged_in or Checkpoints.dying:
		return
	if not is_open():
		PersonajesP5.post("dm:shero", "shero", _shero_line("cerrado"), {"tipo": "topico_cerrado", "typing_s": 1.5})
		hub.topico_denied.emit("cerrado")
		return
	var n := requests() + 1
	PersonajesP5.set_counter("p5_topico_pedidos", n)
	if n == 1:
		state = State.PERMISO
		permit_until = GameState.clock_seconds + PersonajesP5.plazo(15.0)
		Metrics.authorize(Metrics.Aux.BANO, "topico", "topico", 15.0 * Difficulty.scale("plazos"))
		if not p3_owns():
			PersonajesP5.post("dm:shero", "shero", _shero_line("permiso"), {"tipo": "topico_permiso", "typing_s": 1.5, "mention": true})
		hub.topico_granted.emit()
		return
	# 2.º pedido del turno: work avoiding.
	state = State.PERSIGUE
	hub.topico_denied.emit("work_avoiding")
	if p3_owns():
		return
	PersonajesP5.post("dm:shero", "shero", _shero_line("work_avoiding"), {"tipo": "topico_work_avoiding", "typing_s": 1.0, "mention": true})
	P5Pursuit.start("shero", "work_avoiding", float(DataLoader.bal("shero/velocidad_perseguir_ms", 3.9)) + 0.7, null, "", 2)


## v0.3.2 (Joan: «me paré en la sala de training y me botó fuera con el mensaje del tópico»): antes era un radio de
## 2,4 m alrededor del marcador, que tras el rearmado de pisos (v0.3.1) cruzaba la pared y llegaba a la esquina NE de la
## sala de training (x 11,5..13,5, z −2,2..−1,3) y al recodo frente a la puerta. Ahora es el cuarto: la zona «topico»
## (interior de 2,6 × 2,6 m, solo existe desde el T2, cuando la puerta abre).
func _in_topico() -> bool:
	if GameState.current_floor != 1:
		return false
	var z := Zone.find(get_tree(), "topico")
	var p := hub.player()
	return z != null and p != null and z.contains_xz(p.global_position)


func _process(delta: float) -> void:
	if _rejected_cd > 0.0:
		_rejected_cd -= delta
	if not GameState.logged_in or Checkpoints.dying or not GameState.running:
		return
	if not _in_topico():
		return
	match state:
		State.PERMISO:
			if GameState.clock_seconds <= permit_until or permit_until <= 0.0:
				_treat()
			else:
				_reject()
		State.LIBRE, State.ALTA:
			_reject()
		State.PERSIGUE:
			if _rejected_cd <= 0.0:
				_rejected_cd = 20.0
				_nurse("work_avoiding")


## El enfermero atiende (con permiso): ~20 s reales, Fatiga −15.
func _treat() -> void:
	state = State.ATENCION
	_token += 1
	var tok := _token
	hub.busy = "topico"
	said.clear()
	var pl := hub.player()
	if pl != null:
		pl.input_locked = true
	var nurse := get_tree().get_first_node_in_group("p5_enfermero")
	if nurse != null and nurse.has_method("attend"):
		nurse.call("attend", true)
	for key in ["recepcion", "atiende_1", "atiende_2", "atiende_3", "atiende_4"]:
		if tok != _token:
			return
		_nurse(key)
		if key == "atiende_2":
			AudioManager.play_sfx("respiracion")
		await PersonajesP5.wait(self, 4.2)
	if tok != _token:
		return
	Fatigue.add(-15.0)
	var left := maxf(permit_until - GameState.clock_seconds, 0.0)
	_nurse("alta", {"min": int(ceil(left / 60.0))})
	if nurse != null and is_instance_valid(nurse) and nurse.has_method("attend"):
		nurse.call("attend", false)
	if pl != null and is_instance_valid(pl) and not Checkpoints.dying:
		pl.input_locked = false
	hub.busy = ""
	state = State.ALTA
	_rejected_cd = 30.0  # recién atendido: no te echa al instante si te quedas en la puerta


## Sin permiso: te devuelve al pasillo y avisa a Shero.
func _reject() -> void:
	if _rejected_cd > 0.0:
		return
	_rejected_cd = 12.0
	_nurse("sin_permiso")
	var pl := hub.player()
	var m := hub.marker("topico")
	if pl != null and m != null:
		# v0.3.1 pisos: el +Z local del marcador apunta a la puerta (al recodo); te deja ahí, de espaldas al cuarto.
		pl.teleport(m.global_position + m.global_transform.basis.z * 3.0, m.global_rotation_degrees.y + 180.0)
	EventBus.shero_message.emit("topico_anotado", "dm")


func _nurse(key: String, vars: Dictionary = {}) -> void:
	said.append(key)
	var text := Loc.fmt(Loc.pick((DataLoader.dict("lineas_neutrales").get("enfermero", {}) as Dictionary).get(key, {})), vars)
	PersonajesP5.say(tr("P5_NURSE"), "otros", "enfermero_" + key, text)


func _on_room_entered() -> void:
	# De vuelta en la sala: el permiso del tópico ya no hace falta.
	if state == State.ALTA:
		Metrics.revoke("topico")


func _on_death(_c: String, _k: String, _d: String) -> void:
	_token += 1
	if hub != null and hub.busy == "topico":
		hub.busy = ""


func _on_respawned(_k: String) -> void:
	_token += 1
	state = State.LIBRE if requests() == 0 else (State.ALTA if requests() == 1 else State.LIBRE)
	if requests() == 1 and Metrics.authorization_of("topico").size() > 0:
		state = State.PERMISO
		permit_until = float(Metrics.authorization_of("topico").get("until", GameState.clock_seconds))

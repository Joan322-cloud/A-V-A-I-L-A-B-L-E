extends Node
## Sala 2 de training (piso 1, T2+): comportamiento de piso (data/comportamientos.json → marcador
## training_sala2). El cerebro es TrainingControl (persistente). Aquí: la silla libre del extremo
## (Seat_training_sala2_3) siempre habilitada, las siluetas que giran la cabeza a la vez cuando te sientas,
## la pizarra que cambia durante el quiz y la luz del proyector que tiembla mientras respondes.

var floor_node: FloorBase = null
var _heads: Array[Node3D] = []
var _board: Label3D = null
var _board_text: String = ""
var _beam: Node3D = null
var _t: float = 0.0
var _turn_left: float = 0.0


func setup_behaviour(fl: Node, _marker: Node, _entry: Dictionary) -> void:
	floor_node = fl as FloorBase
	PersonajesP5.ensure(get_tree())
	var seat := floor_node.find_child("Seat_training_sala2_3", true, false) as WorldObjects.Seat
	if seat != null:
		seat.enabled = true
	for k in 3:
		var h := floor_node.find_child("AlumnoCabezaT%d" % k, true, false) as Node3D
		if h != null:
			_heads.append(h)
	for l in floor_node.find_children("*", "Label3D", true, false):
		var lb := l as Label3D
		if lb.has_meta("reverso"):
			continue  # P6b: el reverso del cartel copia la cara; se anima la cara
		# v0.3.2: la sala de la sesión es la principal (floor_01 conservó los ids «sala2», pero su pizarra está en x 8,2;
		# aquí se buscaba en x 18 y no se encontraba nunca: la pizarra no cambiaba ni durante el quiz).
		if lb.text == tr("SIGN_TRAINING_BOARD") and (seat == null or absf(lb.global_position.x - seat.global_position.x) < 7.0):
			_board = lb
			_board_text = lb.text
	# v0.3.2: la pizarra es la del DÍA (training.json/dias/<turno>/pizarra): el temario de esa actualización y la
	# nota mínima de su quiz ({min}). Sin entrada (el lunes) queda el cartel de siempre.
	var piz: Variant = TrainingControl.day_info().get("pizarra", null)
	if _board != null and piz is Dictionary:
		_board_text = Loc.fmt(Loc.pick(piz), {"min": TrainingControl.pass_mark()})
		_board.text = _board_text
	_beam = floor_node.find_child("ProyectorHaz1", true, false) as Node3D
	# v0.3.2: sin terminal Fonex de pared (ya no hay terminales): el AUX Training se pone en tu PC o con el comodín [C].
	EventBus.player_seated.connect(_on_seated)


func _on_seated(id: String) -> void:
	if id.begins_with("training_sala2"):
		_turn_left = 2.2
		AudioManager.play_sfx("respiracion")


func _process(delta: float) -> void:
	_t += delta
	var hub := PersonajesP5.get_hub(get_tree())
	var quiz_on := hub != null and hub.training != null and hub.training.state == TrainingControl.State.QUIZ
	if _turn_left > 0.0:
		_turn_left -= delta
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	for h in _heads:
		if not is_instance_valid(h):
			continue
		if (_turn_left > 0.0 or quiz_on) and pl != null:
			# Las siluetas giran la cabeza hacia ti, todas a la vez.
			var d := pl.global_position - h.global_position
			h.rotation.y = lerp_angle(h.rotation.y, atan2(d.x, d.z), minf(delta * 9.0, 1.0))
		else:
			h.rotation.y = lerp_angle(h.rotation.y, 0.0, minf(delta * 4.0, 1.0))
	if _board != null:
		_board.text = (tr("P5_TRAINING_BOARD_QUIZ") if fmod(_t, 1.4) < 1.0 else _board_text) if quiz_on else _board_text
	if _beam != null:
		_beam.visible = not quiz_on or fmod(_t, 0.23) > 0.05

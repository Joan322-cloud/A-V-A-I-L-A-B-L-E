class_name HorrorAmbience
extends Node
## v0.3.1 (integración, audio_horror_v2): sustos sonoros sueltos de call center en T2 y T3, sin mecánicas nuevas.
## Lo cuelga el AudioDirector. Cada 70-150 s reales (más seguido con Dread alta) puede sonar UNO de EVENTS si se
## cumplen sus condiciones (turno, piso 2, sentado, Fatiga); cada evento tiene su enfriamiento y un tope por turno,
## y nada suena en el T1, en la Inducción, con una muerte en curso, en un contacto, en un feedback ni en una caza.
## Los efectos 3D salen de un punto que no ves (detrás, al lado, lejos en la sala, en el techo) y nunca delante.
## Otros ganchos con los mismos archivos: la música de espera «corrupta» (ContactManager._set_hold), la respiración
## en la línea muerta al colgar (aquí, contact_ended), el ding lento del ascensor de un cazador (Pursuit).

const EVENTS: Array[Dictionary] = [
	{"id": "telefono_sin_fin", "slot": "sfx/telefono_sin_fin_loop", "turno": 2, "donde": "lejos", "loop_s": 11.0, "db": -6.0, "max": 2},
	{"id": "telefonos_se_suman", "slot": "ambiente/telefonos_se_suman", "turno": 3, "donde": "lejos", "db": -6.0, "max": 1},
	{"id": "teclado_fantasma", "slot": "ambiente/teclado_fantasma_loop", "turno": 2, "donde": "al_lado", "loop_s": 9.0, "db": -12.0, "sentado": true, "max": 2},
	{"id": "clics_fantasma", "slot": "sfx/clics_fantasma", "turno": 2, "donde": "al_lado", "db": -10.0, "sentado": true, "max": 2},
	{"id": "fluorescente_crece", "slot": "ambiente/fluorescente_crece", "turno": 2, "donde": "arriba", "db": -8.0, "max": 1},
	{"id": "fluorescente_estallido", "slot": "sfx/fluorescente_estallido", "turno": 3, "donde": "arriba", "db": -4.0, "fatiga": 55.0, "max": 1},
	{"id": "silla_crujido", "slot": "sfx/silla_crujido_largo", "turno": 2, "donde": "detras", "db": -6.0, "max": 2},
	{"id": "impresora_grito", "slot": "sfx/impresora_atasco_grito", "turno": 2, "donde": "impresora", "db": -4.0, "max": 1},
	{"id": "susurros", "slot": "ambiente/susurros_available_loop", "slot_en": "ambiente/susurros_available_en_loop", "turno": 2, "donde": "detras", "loop_s": 14.0, "db": -16.0, "fatiga": 70.0, "max": 1},
	{"id": "llanto", "slot": "ambiente/llanto_agente_lejano_loop", "turno": 3, "donde": "lejos", "loop_s": 16.0, "db": -12.0, "max": 1},
	{"id": "risa_pasillo", "slot": "sfx/risa_pasillo", "turno": 3, "donde": "lejos", "db": -8.0, "max": 1},
	{"id": "golpes_puerta", "slot": "sfx/golpes_puerta_lejanos", "turno": 3, "donde": "lejos", "db": -6.0, "max": 1},
	{"id": "respiracion_nuca", "slot": "sfx/respiracion_nuca", "turno": 3, "donde": "2d", "db": -8.0, "fatiga": 75.0, "max": 1},
	{"id": "pa_corrupto", "slot": "voces/sistema/pa_anuncio_corrupto", "turno": 3, "donde": "parlantes", "max": 1},
	{"id": "susurro_auricular", "slot": "voces/sistema/susurro_auricular", "turno": 3, "donde": "auricular", "sentado": true, "fatiga": 80.0, "max": 1},
]
const LINEA_MUERTA := "sfx/linea_muerta_respiracion"
const INTERVALO_S := [70.0, 150.0]
const ENFRIAMIENTO_S := 240.0  # el mismo evento no se repite antes

var fired: Array[String] = []  # ids del turno (pruebas y tope)
var _next: float = 90.0
var _last_real: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	EventBus.shift_started.connect(_reset)
	EventBus.returned_to_menu.connect(_reset)
	EventBus.contact_ended.connect(_on_contact_ended)


func _reset() -> void:
	fired.clear()
	_last_real.clear()
	_next = _rng.randf_range(float(INTERVALO_S[0]), float(INTERVALO_S[1]))


## ¿Se puede asustar ahora? (Nunca en T1, Inducción, muerte, contacto, feedback, caza ni con el reloj congelado.)
func quiet_reason() -> String:
	if not GameState.running or GameState.shift_over or GameState.turno < 2:
		return "turno"
	if GameState.is_tutorial() or Checkpoints.dying or Checkpoints.in_respawn_grace():
		return "estado"
	if Discipline.is_frozen() or Pursuit.is_hunting():
		return "congelado"
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	if cm != null and cm.is_active():
		return "contacto"
	return ""


func _process(delta: float) -> void:
	if quiet_reason() != "":
		return
	_next -= delta * (1.0 + Dread.level())  # con más presión, más seguido (hasta el doble)
	if _next > 0.0:
		return
	_next = _rng.randf_range(float(INTERVALO_S[0]), float(INTERVALO_S[1]))
	var cands: Array[Dictionary] = []
	for e in EVENTS:
		if can_fire(e):
			cands.append(e)
	if not cands.is_empty():
		fire(cands[_rng.randi() % cands.size()])


func can_fire(e: Dictionary) -> bool:
	if GameState.turno < int(e.get("turno", 2)) or GameState.current_floor != 2:
		return false
	if bool(e.get("sentado", false)) and GameState.seated_at == "":
		return false
	if Fatigue.value < float(e.get("fatiga", 0.0)):
		return false
	var id := str(e["id"])
	if fired.count(id) >= int(e.get("max", 1)):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _last_real.has(id) and now - float(_last_real[id]) < ENFRIAMIENTO_S:
		return false
	return AudioManager.has_slot(str(e["slot"]))


func fire(e: Dictionary) -> void:
	var id := str(e["id"])
	fired.append(id)
	_last_real[id] = Time.get_ticks_msec() / 1000.0
	var slot := str(e["slot"])
	if e.has("slot_en") and Loc.language == "en":
		slot = str(e["slot_en"])
	match str(e.get("donde", "")):
		"parlantes":
			AudioManager.play_sfx("pa_chime")
			# v0.3.2 (integración): un susto de ambiente es relleno para el director de voces (no una línea importante): si
			# alguien le quita la palabra (la calibración de Haime calla a todos) no hay nada que avisar ni que lamentar.
			AudioManager.play_voice("sistema", slot.get_file(), "", "Parlantes", -1, {"must": false})
		"auricular":
			AudioManager.play_voice("sistema", slot.get_file(), "", "Auricular", -1, {"must": false})
		"2d":
			AudioManager.play_slot(slot)
		_:
			var at := _spot(str(e.get("donde", "")))
			if at != Vector3.INF:
				_play_3d(slot, at, float(e.get("db", -8.0)), float(e.get("loop_s", 0.0)), id)
	EventBus.distortion_triggered.emit("audio_" + id)


## Un punto que no estás mirando: detrás, al lado (la silla vecina), en el techo o lejos en la sala.
func _spot(where: String) -> Vector3:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return Vector3.INF
	var back := pl.global_transform.basis.z.normalized()  # la cámara mira a -Z
	var side := pl.global_transform.basis.x.normalized()
	match where:
		"detras":
			return pl.global_position + back * 2.5 + Vector3(0, 1.0, 0)
		"al_lado":
			return pl.global_position + side * (1.1 if _rng.randf() < 0.5 else -1.1) + Vector3(0, 0.8, 0)
		"arriba":
			return pl.global_position + back * 1.5 + Vector3(0, 2.6, 0)
		"impresora":
			var fl := get_tree().get_first_node_in_group("floor") as Node3D
			if fl != null:
				for n in fl.find_children("Impresora*", "Node3D", true, false):
					return (n as Node3D).global_position
			return pl.global_position + back * 9.0 + Vector3(0, 1.0, 0)
	# lejos: 9-16 m a un costado o atrás
	var dir := (back * _rng.randf_range(0.4, 1.0) + side * _rng.randf_range(-1.0, 1.0)).normalized()
	return pl.global_position + dir * _rng.randf_range(9.0, 16.0) + Vector3(0, 1.2, 0)


func _play_3d(slot: String, at: Vector3, db: float, loop_s: float, id: String = "") -> void:
	var st := AudioManager.stream_for(slot, loop_s > 0.0)
	var fl := get_tree().get_first_node_in_group("floor") as Node3D
	if st == null or fl == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "SustoSonoro_" + id
	p.stream = st
	p.bus = "Sala"
	p.unit_size = 6.0
	p.max_distance = 30.0
	p.volume_db = db + AudioManager.gain_db(slot)
	fl.add_child(p)
	p.global_position = at
	p.play()
	if loop_s > 0.0:
		var tw := p.create_tween()
		tw.tween_interval(maxf(loop_s - 2.0, 0.5))
		tw.tween_property(p, "volume_db", -60.0, 2.0)
		tw.tween_callback(p.queue_free)
	else:
		p.finished.connect(p.queue_free)


## Al colgar una llamada en T3 con Fatiga alta, a veces la línea no se corta: alguien respira (una vez por turno).
func _on_contact_ended(c: Dictionary, _r: bool, _a: bool) -> void:
	if GameState.turno < 3 or str(c.get("canal", "")) != "llamada" or Fatigue.value < 60.0 or fired.has("linea_muerta"):
		return
	if Checkpoints.dying or GameState.is_tutorial() or _rng.randf() > 0.2:
		return
	fired.append("linea_muerta")
	await get_tree().create_timer(0.8).timeout
	if not Checkpoints.dying:
		AudioManager.play_slot(LINEA_MUERTA, "Auricular")
		EventBus.distortion_triggered.emit("audio_linea_muerta")

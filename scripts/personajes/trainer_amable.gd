class_name TrainerAmable
extends TrainingActor
## v0.3.2 · El Trainer AMABLE del Training (el recuerdo, docs/AVAILABLE_trama_semana §2.1): el mismo modelo que el de
## los turnos (assets/models/trainer.glb), con la cara normal (sin la textura de grito ni la deformación del ScreamRig),
## piel y ropa más cálidas, una luz cálida propia y la voz suave (voces/trainer_amable/*). No persigue ni mata.
## Da la clase en el claro de la herradura (TrainingRoom.SPOTS): «centro» cuando explica, «pizarra» cuando señala la
## diapositiva, «cerca» cuando te habla a ti, «mesa» cuando miras tu PC y él se asoma a tu pantalla, «cafe» en el
## break, «foto» en la foto, «puerta» cuando te recibe y «salida» (a un lado de la puerta) cuando te deja salir. Siempre gira hacia ti cuando te habla (el cuerpo; la cabeza la lleva NpcAnimator).
## Lo maneja Tutorial / TrainingStage: habla por TrainingVoice (una línea a la vez; talk() mueve manos y boca).
## Grieta (para quien vuelva a jugarlo): la firma muestra un fotograma su cara real (ContractUI).

const VOICE := "trainer_amable"
const LINES := "lineas_trainer_amable"

var board_pos: Vector3 = TrainingRoom.SPOTS["centro"]  # (compatibilidad: dónde da la clase)
var desk_pos: Vector3 = TrainingRoom.SPOTS["mesa"]
var said: Array[String] = []  # pruebas
var _floor: Node3D = null
var _light: OmniLight3D = null
var _mode: String = "centro"
var _eye: Vector3 = TrainingRoom.EYE


func setup(floor_node: Node3D) -> void:
	_floor = floor_node
	place_standing(TrainingRoom.SPOTS["centro"], _to_eye(TrainingRoom.SPOTS["centro"]))


func _ready() -> void:
	add_to_group("trainer_amable")
	speed = 1.45
	if build("trainer", 1.86):
		rig.set_scream_face(false)
		rig.set_deform(0.0)
		rig.play("idle")  # (la piel y la ropa cálidas ya las puso build → Flashback.apply_look)
	else:
		Greybox.box(self, "Cuerpo", Vector3(0, 0.95, 0), Vector3(0.5, 1.7, 0.32), Color(0.9, 0.86, 0.75), false)
	_light = OmniLight3D.new()
	_light.name = "LuzCalida"
	_light.light_color = Color(1.0, 0.86, 0.68)
	_light.light_energy = 0.35
	_light.omni_range = 2.6
	_light.position = Vector3(0, 2.0, -0.7)  # delante de él: le da en la cara
	_light.shadow_enabled = false
	_light.set_meta("recuerdo", true)
	add_child(_light)


func _to_eye(from: Vector3) -> Vector3:
	var d := _eye - from
	d.y = 0.0
	return d


## Habla (pruebas sueltas): subtítulo con su nombre + su voz amable. `id` = clave de data/lineas_trainer_amable.json.
func say(id: String, vars: Dictionary = {}) -> String:
	var txt := PersonajesP5.line(LINES, id, vars)
	if txt == "":
		return ""
	said.append(id)
	PersonajesP5.say("Trainer", VOICE, id, txt, "Sala")
	talk(clampf(1.0 + txt.length() * 0.06, 1.5, 9.0))
	return txt


## Empieza a hablar (lo llama TrainingVoice en cada línea suya): manos y boca hasta hush().
func speak_line(secs: float, hard: bool = false) -> void:
	if not is_walking() and _gesture_left <= 0.0:
		talk(secs, hard)
	elif rig != null and rig.animator != null:
		rig.animator.speak(secs, hard)  # caminando: solo la boca


## (compatibilidad) Señala al hablar.
func gesture_talk() -> void:
	speak_line(3.0)


## Va a uno de sus sitios (TrainingRoom.SPOTS) por dentro de la herradura y queda mirándote.
func go(spot: String, then: Callable = Callable()) -> void:
	if not TrainingRoom.SPOTS.has(spot):
		return
	if _mode == spot and not is_walking():
		if then.is_valid():
			then.call()
		return
	var from := _mode
	_mode = spot
	var to: Vector3 = TrainingRoom.SPOTS[spot]
	walk(_route(from, spot) + [to], _face_for(spot, to), then)


## Ya parado en uno de sus sitios, mirándote (sin caminar: al armar la escena).
func place(spot: String) -> void:
	if TrainingRoom.SPOTS.has(spot):
		var at: Vector3 = TrainingRoom.SPOTS[spot]
		place_standing(at, _face_for(spot, at))
		_mode = spot


## A un punto cualquiera del piso (por el claro de la herradura).
func to_spot(p: Vector3, face_dir: Vector3) -> void:
	_mode = "spot"
	walk([p], face_dir)


func to_board() -> void:
	go("centro")


func to_desk() -> void:
	go("mesa")


func applaud() -> void:
	if not gesture("clap"):
		if rig != null:
			rig.play("open_hands", true, 1.4, ["point", "idle"])
	AudioManager.play_sfx("aplausos", "Sala")


func mode() -> String:
	return _mode


## Dónde está tu cabeza (el jugador se paró, fue por café…): hacia ahí mira cuando llega a un sitio.
func set_eye(p: Vector3) -> void:
	_eye = p


func _face_for(spot: String, at: Vector3) -> Vector3:
	match spot:
		"mesa":
			return Vector3(TrainingRoom.SEAT_POS.x - at.x, 0, (TrainingRoom.SEAT_POS.z - 0.2) - at.z)  # mira tu pantalla y a ti
		"cafe":
			return Vector3(TrainingRoom.COFFEE_STAND.x - at.x, 0, TrainingRoom.COFFEE_STAND.z - at.z)
		"foto":
			return Vector3(TrainingRoom.PHOTO_CAM.x - at.x, 0, TrainingRoom.PHOTO_CAM.z - at.z)
		"puerta":
			return Vector3(0.3, 0, -1)
	return _to_eye(at)


## Puntos intermedios entre dos sitios: dentro de la herradura va por el eje; a la isla del café (queda DETRÁS de la
## mesa, entre la promoción) da la vuelta por el pasillo del fondo, delante de la pizarra; a tu mesa baja por el lado
## izquierdo del claro; a la puerta sale por el hueco suroeste.
func _route(from: String, to: String) -> Array:
	var ax := TrainingRoom.AXIS_X
	var north := [Vector3(8.9, 0, -7.6), Vector3(11.9, 0, -7.55)]  # pasillo del fondo, de oeste a este
	var door := [Vector3(7.4, 0, -3.2), Vector3(7.6, 0, -4.5), Vector3(ax, 0, -5.2)]  # de la puerta al claro
	var inner := ["pizarra", "centro", "cerca", "foto", "spot", "camara"]
	var out: Array = []
	if from == "salida":  # «salida» = junto a la puerta, a un lado (te deja el paso libre): mismas rutas que «puerta»
		from = "puerta"
	if to == "salida":
		to = "puerta"
	if from == to:
		return out
	if to == "cafe":
		if from == "mesa":
			out = [Vector3(7.95, 0, -5.0), Vector3(ax, 0, -6.2)]
		elif from == "puerta":
			out = door.duplicate()
		return out + north
	if from == "cafe":
		out = north.duplicate()
		out.reverse()
		if to == "mesa":
			out += [Vector3(ax, 0, -6.2), Vector3(7.95, 0, -5.0)]
		elif to == "puerta":
			var back := door.duplicate()
			back.reverse()
			out += back
		return out
	if to == "mesa":
		if from == "puerta":
			return [Vector3(7.4, 0, -3.2), Vector3(7.5, 0, -4.2)]
		return [Vector3(7.95, 0, -5.0)]
	if from == "mesa":
		if to == "puerta":
			return [Vector3(7.5, 0, -4.2), Vector3(7.4, 0, -3.2)]
		return [Vector3(7.95, 0, -5.0)]
	if to == "puerta":
		var back2 := door.duplicate()
		back2.reverse()
		return back2
	if from == "puerta":
		return door.duplicate()
	return out

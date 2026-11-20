class_name TrainingActor
extends Node3D
## v0.3.2 · Un personaje del Training (el recuerdo): el Trainer amable y los compañeros de promoción. Camina por
## puntos (sin navegación: el aula es chica y las rutas se escriben a mano), gira con el cuerpo hacia donde va o hacia
## quien le habla, se sienta y se para con sus clips, hace gestos de una vez (los del Training: assets/anim/
## <modelo>_t32.res, biblioteca «t32» sumada con NpcAnimator.add_library) y mueve la boca y las manos al hablar
## (NpcAnimator.speak). No toca npc_animator.gd: usa su API pública (play, add_library, speak, shut_up, look_enabled).

const T32 := "t32"
const T32_DIR := "res://assets/anim/"
const TURN_SPEED := 5.0  # rad/s al girar el cuerpo
const STAND_S := 1.25  # lo que tarda en pararse de la silla antes de caminar
const SIT_S := 1.4

var rig: CharacterRig = null
var model: String = ""
var height: float = 1.7
var speed: float = 1.35
var seated: bool = false
var base_clip: String = "idle"  # a lo que vuelve después de un gesto: idle de pie; sit / type sentado
var busy_gesture: String = ""  # gesto de una vez en curso (pruebas)
var _path: Array[Vector3] = []
var _face_dir: Vector3 = Vector3.INF
var _then: Callable = Callable()
var _track: Node3D = null
var _track_point: Vector3 = Vector3.INF
var _gesture_left: float = 0.0
var _delay: float = 0.0  # espera antes de empezar a caminar (se está parando)
var _want_yaw: float = INF
var _sit_after: bool = false
var _seat_pos: Vector3 = Vector3.ZERO
var _seat_dir: Vector3 = Vector3(0, 0, -1)
var _seat_clip: String = "sit"
var _hold_clip: String = ""  # gesto congelado a mitad (gesture_hold)
var _hold_at: float = -1.0
var _hold_t: float = 0.0


## Crea el cuerpo. `look` = "recuerdo" (piel y ropa con más color). Devuelve false si el modelo no existe.
func build(p_model: String, p_height: float, look: String = "recuerdo") -> bool:
	model = p_model
	height = p_height
	rig = CharacterRig.attach(self, model, height)
	if rig == null:
		return false
	if look != "":
		Flashback.apply_look(rig, look)
	if rig.animator != null:
		var p := T32_DIR + model + "_" + T32 + ".res"
		if ResourceLoader.exists(p):
			rig.animator.add_library(T32, load(p) as AnimationLibrary)
	rig.play("idle")
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rig != null and is_instance_valid(rig):
		Flashback.clear_look(rig)  # sus materiales propios se sueltan antes de que el cuerpo muera (ver clear_look)


func has_gesture(clip: String) -> bool:
	return rig != null and rig.has_anim(clip if clip.contains("/") else T32 + "/" + clip)


# --- moverse ------------------------------------------------------------------------------------------

## Camina por `points` (locales del piso). Al llegar mira hacia `face` (dirección) y llama `then`. Si estaba sentado,
## primero se para.
func walk(points: Array, face: Vector3 = Vector3.INF, then: Callable = Callable()) -> void:
	_path.clear()
	for p in points:
		_path.append(Vector3((p as Vector3).x, 0, (p as Vector3).z))
	_face_dir = face
	_then = then
	_sit_after = false
	_end_gesture()
	if seated:
		seated = false
		base_clip = "idle"
		_delay = STAND_S
		if rig != null:
			rig.play("idle")  # el animador pasa por stand_up
	elif rig != null:
		rig.play("walk")


## Camina hasta una silla y se sienta mirando hacia `dir`.
func walk_and_sit(points: Array, seat_pos: Vector3, dir: Vector3, clip: String = "sit") -> void:
	walk(points + [seat_pos], dir)
	_sit_after = true
	_seat_pos = seat_pos
	_seat_dir = dir
	_seat_clip = clip


func is_walking() -> bool:
	return not _path.is_empty() or _delay > 0.0


## Deja de caminar donde está (el recuerdo cambia de módulo o se salta).
func halt() -> void:
	_path.clear()
	_delay = 0.0
	_then = Callable()
	_sit_after = false
	if rig != null and not seated:
		rig.play("idle")


## Ya sentado en `pos` mirando a `dir` (sin caminar: al armar el aula o al saltar un módulo).
func place_seated(pos: Vector3, dir: Vector3, clip: String = "sit") -> void:
	halt()
	_end_gesture()
	position = Vector3(pos.x, 0, pos.z)
	rotation.y = TrainingRoom.yaw_to(dir)
	_want_yaw = INF
	seated = true
	base_clip = clip
	_rest()


## De pie en `pos` mirando a `dir` (sin caminar).
func place_standing(pos: Vector3, dir: Vector3) -> void:
	halt()
	_end_gesture()
	position = Vector3(pos.x, 0, pos.z)
	if dir.length() > 0.01:
		rotation.y = TrainingRoom.yaw_to(dir)
	_want_yaw = INF
	seated = false
	base_clip = "idle"
	_rest()


## Gira el cuerpo (suave) hacia un punto local del piso.
func turn_to(point: Vector3) -> void:
	var d := point - position
	d.y = 0.0
	if d.length() > 0.05 and not seated:
		_want_yaw = TrainingRoom.yaw_to(d)


## Sigue con el cuerpo a un nodo (el jugador) mientras está de pie y quieto. null = deja de seguir.
func track(node: Node3D) -> void:
	_track = node


## La cabeza busca la cámara (NpcAnimator) o sigue el clip.
func look_at_player(on: bool) -> void:
	if rig != null and rig.animator != null:
		rig.animator.look_enabled = on


# --- gestos y habla -----------------------------------------------------------------------------------

## Gesto de una vez: un clip del Training («risa_sentado», «mano», «aplauso»…) o uno del modelo («point», «yawn»).
## Vuelve solo a su clip de reposo. `secs` < 0 = lo que dura el clip. Devuelve false si no existe.
func gesture(clip: String, secs: float = -1.0, p_speed: float = 1.0) -> bool:
	if rig == null or is_walking():
		return false
	var full := T32 + "/" + clip
	var use := full if rig.has_anim(full) else (clip if rig.has_anim(clip) else "")
	if use == "":
		return false
	var dur := secs
	if dur < 0.0:
		dur = 2.0
		if rig.anim != null and rig.anim.has_animation(use):
			dur = rig.anim.get_animation(use).length / maxf(p_speed, 0.05)
	rig.play(use, false, p_speed)
	busy_gesture = clip
	_gesture_left = dur
	return true


## Empieza un gesto y lo deja CONGELADO a los `at` s (la mano tendida, esperándote) hasta resume_gesture() o hasta
## que pida otra cosa. Pausar = pedir el mismo clip con velocidad 0 (API pública de NpcAnimator.play).
func gesture_hold(clip: String, at: float) -> bool:
	if not gesture(clip, 600.0):
		return false
	_hold_clip = T32 + "/" + clip if rig.has_anim(T32 + "/" + clip) else clip
	_hold_at = at
	_hold_t = 0.0
	return true


## Suelta el gesto congelado: sigue hasta el final (el apretón) y vuelve a su reposo.
func resume_gesture() -> void:
	if _hold_clip == "" or rig == null:
		return
	var total := 2.0
	if rig.anim != null and rig.anim.has_animation(_hold_clip):
		total = rig.anim.get_animation(_hold_clip).length
	rig.play(_hold_clip, false, 1.0)
	_gesture_left = maxf(total - _hold_t, 0.3)
	_hold_clip = ""
	_hold_at = -1.0


func _end_gesture() -> void:
	_hold_clip = ""
	_hold_at = -1.0
	if _gesture_left > 0.0 or busy_gesture != "":
		_gesture_left = 0.0
		busy_gesture = ""
		_rest()


## Vuelve a su clip de reposo AL INSTANTE (sentado sigue sentado). Los gestos del Training son clips de otra
## biblioteca: NpcAnimator los reproduce con el árbol apagado y, al volver, el árbol arranca de pie; con
## auto_transitions = false entra directo al estado pedido (sin pasar por de pie ni por sit_down).
func _rest(clip: String = "") -> void:
	if rig == null:
		return
	var an: NpcAnimator = rig.animator
	var was := an.auto_transitions if an != null else true
	if an != null:
		an.auto_transitions = false
	rig.play(clip if clip != "" else base_clip, true, 0.9 if seated else 1.0, ["sit", "idle"])
	if an != null:
		an.auto_transitions = was


## Habla `secs` segundos: gestos de conversación y mandíbula (los corta hush()).
func talk(secs: float, hard: bool = false) -> void:
	if rig != null and rig.animator != null:
		rig.animator.speak(secs, hard)


func hush() -> void:
	if rig != null and rig.animator != null:
		rig.animator.shut_up()


# --- cada cuadro -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _hold_clip != "" and _hold_at >= 0.0 and _hold_t < _hold_at:
		_hold_t += delta
		if _hold_t >= _hold_at and rig != null:
			rig.play(_hold_clip, false, 0.0)  # queda con la mano tendida
	if _gesture_left > 0.0:
		_gesture_left -= delta
		if _gesture_left <= 0.0:
			_end_gesture()
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0 and rig != null and not _path.is_empty():
			rig.play("walk")
		return
	if _path.is_empty():
		if not seated:
			if _track != null and is_instance_valid(_track) and _gesture_left <= 0.0:
				var d := _track.global_position - global_position
				d.y = 0.0
				if d.length() > 0.3:
					_want_yaw = TrainingRoom.yaw_to(d)
			if _want_yaw != INF:
				var diff := wrapf(_want_yaw - rotation.y, -PI, PI)
				var stp := TURN_SPEED * delta
				if absf(diff) <= stp:
					rotation.y = _want_yaw
					if _track == null:
						_want_yaw = INF
				else:
					rotation.y += signf(diff) * stp
		return
	var to := _path[0] - position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		position = Vector3(_path[0].x, 0, _path[0].z)
		_path.remove_at(0)
		if _path.is_empty():
			_arrived()
		return
	position += to.normalized() * step
	var want := TrainingRoom.yaw_to(to)
	var diff2 := wrapf(want - rotation.y, -PI, PI)
	rotation.y += clampf(diff2, -TURN_SPEED * 1.6 * delta, TURN_SPEED * 1.6 * delta)


func _arrived() -> void:
	if _sit_after:
		_sit_after = false
		rotation.y = TrainingRoom.yaw_to(_seat_dir)
		_want_yaw = INF
		seated = true
		base_clip = _seat_clip
		if rig != null:
			rig.play(_seat_clip, true, 0.9, ["sit", "idle"])  # el animador pasa por sit_down
	else:
		if _face_dir != Vector3.INF and _face_dir.length() > 0.01:
			_want_yaw = TrainingRoom.yaw_to(_face_dir)
		if rig != null:
			rig.play("idle")
	var cb := _then
	_then = Callable()
	if cb.is_valid():
		cb.call()

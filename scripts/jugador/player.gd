class_name Player
extends CharacterBody3D
## Controlador en primera persona: WASD, mouse, E, Shift correr, Ctrl agacharse,
## R frotarse los ojos, sentarse/levantarse, raycast de interacción, head bob sutil.
## v0.3.1 Q1: correr ya no «parpadea» al agotar el aliento (B9/F7: hay que recuperar un 35 % antes de volver a
## correr, y el aviso de Shero sale una vez al agotarlo, con 25 s reales de enfriamiento, solo logueado, dentro de
## la sala y fuera de break/lunch; la 3.ª vez en 5 min viene en persona: un verbal). Salto con Espacio de pie
## (F26, ~0,45 m, sin doble salto, 0,4 s de enfriamiento, cuesta aliento; sentado, con un modal, un terminal o un
## Ack pendiente, Espacio sigue siendo «aceptar»). Señales player_jumped / player_landed (C15).

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var collider: CollisionShape3D = $CollisionShape3D

var mouse_sens: float = 0.0022
var speed: float = 5.0
var run_speed: float = 6.5
var breath: float = 6.0
var breath_left: float = 6.0
var fov_base: float = 75.0
var fov_run: float = 85.0
var seated: bool = false
var seat_node: Node3D = null
var seat_id: String = ""
var crouching: bool = false
var input_locked: bool = false  # UI modal abierta
var lying: bool = false  # acostado en un SleepSpot (v0.3 P2)
var lie_spot: Node3D = null
var cinematic: bool = false  # screamer / colapso: la cámara la mueve fx/screamers.gd o fx/collapse_fx.gd
var _wake_request: bool = false
var _bob_t: float = 0.0
var _yaw_base: float = 0.0
var _rubbing: float = 0.0
var _current_hint: Interactable = null
var _last_hint: String = ""
var _rig: CharacterRig = null  # cuerpo visible (manos, piernas) del agente elegido
var _sens_base: float = 0.0022
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
# v0.3.1 (B9/F7): aliento agotado → no se vuelve a correr hasta recuperar RUN_RECOVER del total.
const RUN_RECOVER := 0.35
const RUN_MSG_COOLDOWN_S := 25.0
const RUN_VERBAL_WINDOW_S := 300.0
var _exhausted: bool = false
var _clock_real: float = 0.0  # segundos reales del jugador (delta escalado; no corre en pausa)
var _run_msg_at: float = -INF
var _run_msgs: Array[float] = []
var run_messages: int = 0  # avisos de Shero por correr en este jugador (pruebas)
# v0.3.1 (F26): salto.
const JUMP_HEIGHT := 0.45
const JUMP_COOLDOWN_S := 0.4
const JUMP_BREATH_S := 0.8
var jump_enabled: bool = true
var _jump_request: bool = false
var _jump_cd: float = 0.0
var _airborne: bool = false
var _air_peak_y: float = 0.0
var _jumping: bool = false
var _jump_t: float = -1.0  # tiempo desde el despegue (≥ 0 = subida balística exacta, igual a 1x que a 16x)
var jumps: int = 0
# v0.3.1 (Joan 11:19Z: atrapado dentro del sofá al despertar): al pararte de un asiento, al despertar, al reaparecer
# y si quedas encerrado (2 s empujando sin moverte y bloqueado en las 8 direcciones), el cuerpo sale al hueco libre
# más cercano (o a la salida del mueble: hijo "Salida" o meta "salida" del asiento/SleepSpot, contrato con Q5).
const STUCK_S := 2.0
var unstuck_count: int = 0
var unstuck_log: Array[String] = []
var _stuck_t: float = 0.0
var _stuck_from: Vector3 = Vector3.ZERO
# Red de seguridad contra huecos de colisión: si el cuerpo cae KILL_BELOW m bajo la base del piso,
# vuelve a la última posición segura (grabada cada 0,5 s con los pies en el suelo, fuera del ascensor).
const KILL_BELOW := 3.0
const SAFE_EVERY := 0.5
var safety_enabled: bool = true
var fall_rescues: int = 0
var fall_log: Array[String] = []
var _safe_pos: Vector3 = Vector3.ZERO
var _safe_yaw: float = 0.0
var _safe_valid: bool = false
var _safe_t: float = 0.0


func _ready() -> void:
	add_to_group("player")
	EventBus.interact_hint.emit("")  # P6b: el HUD no hereda el "[E] Levantarse" del jugador del turno anterior
	collision_layer = 1
	collision_mask = 1
	speed = float(DataLoader.bal("jugador/velocidad_ms", 5.0))
	run_speed = float(DataLoader.bal("jugador/velocidad_correr_ms", 6.5))
	breath = float(DataLoader.bal("jugador/aliento_s", 6.0))
	breath_left = breath
	fov_base = float(Loc.get_setting("fov", DataLoader.bal("jugador/fov", 75.0)))
	fov_run = float(DataLoader.bal("jugador/fov_correr", 85.0))
	camera.fov = fov_base
	ray.target_position = Vector3(0, 0, -2.5)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	ray.collision_mask = 2
	mouse_sens = _sens_base * float(Loc.get_setting("sensitivity", 1.0))
	EventBus.settings_changed.connect(_on_setting)
	EventBus.respawned.connect(_on_respawned_cam)
	capture_mouse(true)
	# Cuerpo visible: el rig del agente con la cabeza en la cámara (la cabeza se descarta por backface).
	_rig = CharacterRig.attach(self, CharacterRig.agent_model(GameState.agent), 1.72, 180.0, Vector3(0, -0.04, 0.17))
	if _rig != null:
		_rig.play("idle")
		_rig.hide_head()
		for m in _rig.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_respawned_cam(_kind: String) -> void:
	reset_camera()
	if not seated:
		_unstick_later(Vector3.INF, "reaparecer")


func _on_setting(key: String) -> void:
	if key == "sensitivity":
		mouse_sens = _sens_base * float(Loc.get_setting("sensitivity", 1.0))
	elif key == "fov":
		fov_base = float(Loc.get_setting("fov", 75.0))


func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * mouse_sens)
		head.rotation.x = clampf(head.rotation.x - mm.relative.y * mouse_sens, -1.4, 1.4)
		if seated:
			# Giro limitado a 160° sentado (GDD 9.1): para ver atrás hay que levantarse o mirar el reflejo.
			var lim := deg_to_rad(float(DataLoader.bal("jugador/giro_sentado_grados", 160.0)) * 0.5)
			var d := wrapf(rotation.y - _yaw_base, -PI, PI)
			rotation.y = _yaw_base + clampf(d, -lim, lim)
	elif event.is_action_pressed("interact"):
		if lying:
			_wake_request = true
			return
		_try_interact()
	elif event.is_action_pressed("rub_eyes"):
		Fatigue.rub_eyes()
		_rubbing = float(DataLoader.bal("jugador/frotar_ojos_negro_s", 1.0))
	elif event.is_action_pressed("crouch") and not seated:
		crouching = true
	elif event.is_action_released("crouch"):
		crouching = false
	if event.is_action_pressed("jump") and can_jump():
		# Mando: A también es «interactuar»; con algo delante gana interactuar.
		if (event is InputEventJoypadButton) and _current_hint != null and _current_hint.enabled:
			return
		_jump_request = true


## v0.3.1 (F26): ¿Espacio puede ser «saltar» ahora? Solo de pie, en el suelo, sin modal, sin la PC/terminal
## abiertos, sin Ack pendiente (Espacio = aceptar tiene prioridad) y sin el enfriamiento.
func can_jump() -> bool:
	if not jump_enabled or seated or lying or input_locked or cinematic or crouching:
		return false
	if _jump_cd > 0.0 or _airborne or not is_on_floor():
		return false
	if Metrics.ack_pending or bool(GameState.flags.get("pc_zoom", false)) or bool(GameState.flags.get("terminal_open", false)):
		return false
	if get_tree().paused or Checkpoints.dying:
		return false
	return breath_left >= JUMP_BREATH_S * 0.5


## Por qué no se puede saltar ahora ("" = se puede). Para pruebas e informes.
func jump_block_reason() -> String:
	if not jump_enabled: return "desactivado"
	if seated: return "sentado"
	if lying: return "acostado"
	if input_locked: return "input_locked"
	if cinematic: return "cinematica"
	if crouching: return "agachado"
	if _jump_cd > 0.0: return "enfriamiento %.2f" % _jump_cd
	if _airborne: return "en el aire"
	if not is_on_floor(): return "sin suelo"
	if Metrics.ack_pending: return "ack"
	if bool(GameState.flags.get("pc_zoom", false)): return "pc_zoom"
	if bool(GameState.flags.get("terminal_open", false)): return "terminal"
	if get_tree().paused or Checkpoints.dying: return "pausa/muerte"
	if breath_left < JUMP_BREATH_S * 0.5: return "sin aliento %.1f" % breath_left
	return ""


## Salto pedido por código (bots / pruebas): el mismo camino que Espacio.
func request_jump() -> bool:
	if not can_jump():
		return false
	_jump_request = true
	return true


func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		_clock_real += delta
	if _jump_cd > 0.0:
		_jump_cd = 0.0 if _jump_cd - delta < 0.001 else _jump_cd - delta
	if _rubbing > 0.0:
		_rubbing -= delta
	if not input_locked:
		_gamepad_look(delta)
	if seated and _rig != null:
		_rig.play("type" if GameState.in_contact else "sit", true, 1.0, ["sit", "idle"])
	if lying:
		velocity = Vector3.ZERO
		if not input_locked and (absf(Input.get_axis("move_forward", "move_back")) > 0.5 or absf(Input.get_axis("move_left", "move_right")) > 0.5):
			_wake_request = true
		_update_hint()
		return
	if seated or input_locked:
		velocity = Vector3.ZERO
		_jump_request = false
		_airborne = false
		_jump_t = -1.0
		_update_hint()
		return
	var dir := Vector3.ZERO
	var f := Input.get_axis("move_forward", "move_back")
	var s := Input.get_axis("move_left", "move_right")
	dir = (transform.basis * Vector3(s, 0, f)).normalized()
	if _exhausted and breath_left >= breath * RUN_RECOVER:
		_exhausted = false
	var running := Input.is_action_pressed("walk_fast") and not _exhausted and breath_left > 0.0 and dir.length() > 0.1
	if running:
		breath_left -= delta
		if breath_left <= 0.0:
			breath_left = 0.0
			_exhausted = true  # B9: antes volvía a correr al cuadro siguiente y avisaba ~30 veces por segundo
			_on_breath_spent()
	else:
		breath_left = minf(breath_left + delta * 0.5, breath)
	var spd := run_speed if running else speed
	if crouching:
		spd *= 0.5
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_stuck_watchdog(delta, dir)
	var on_floor := is_on_floor()
	if _jump_request:
		_jump_request = false
		if on_floor and can_jump():
			_jump_t = 0.0
			on_floor = false
			breath_left = maxf(breath_left - JUMP_BREATH_S, 0.0)
			_jumping = true
			jumps += 1
			EventBus.player_jumped.emit()
	if _jump_t >= 0.0:
		# Parábola exacta: la velocidad de este paso es el desplazamiento de h(t) = v0·t − g·t²/2 entre t y t+dt
		# (con Engine.time_scale alto un Euler simple saltaba 0,7-0,8 m en vez de 0,45).
		var v0 := sqrt(2.0 * _gravity * JUMP_HEIGHT)
		var h0 := v0 * _jump_t - 0.5 * _gravity * _jump_t * _jump_t
		_jump_t += delta
		var h1 := v0 * _jump_t - 0.5 * _gravity * _jump_t * _jump_t
		velocity.y = (h1 - h0) / maxf(delta, 0.0001)
	elif not on_floor:
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if _jump_t >= 0.0 and (is_on_ceiling() or (is_on_floor() and _jump_t > 0.05)):
		_jump_t = -1.0  # techo: cae desde ahí; suelo: aterrizó
		velocity.y = minf(velocity.y, 0.0)
	_track_air()
	_safety_net(delta)
	# FOV al correr y head bob sutil (crece con la Fatiga).
	# v0.3 P2: con la presión (Fatiga alta, Shero enojado) el campo de visión se estrecha un poco (encierro).
	var fov_target := (fov_run if running else fov_base) - 7.0 * Dread.level()
	camera.fov = lerpf(camera.fov, fov_target, minf(delta * 4.0, 1.0))
	var moving := velocity.length() > 0.5 and is_on_floor()
	var bob_amt := float(Loc.get_setting("headbob", 1.0)) * (0.03 + 0.04 * Fatigue.headbob_factor())
	if moving:
		_bob_t += delta * (12.0 if running else 8.0)
	var target_y := (1.6 if not crouching else 0.9) + (sin(_bob_t) * bob_amt if moving else 0.0)
	head.position.y = lerpf(head.position.y, target_y, minf(delta * 10.0, 1.0))  # acotado: a time_scale alto divergía
	_update_hint()


## B9/F7: aliento agotado corriendo. Un aviso de Shero (DM) con 25 s reales de enfriamiento, solo con login, dentro
## de la sala, fuera de break/lunch y sin persecución ni calma; la 3.ª vez en 5 min Shero viene en persona (verbal).
func _on_breath_spent() -> void:
	if not GameState.logged_in or not GameState.in_room or GameState.in_calm or Checkpoints.dying:
		return
	if Metrics.aux in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH] or Pursuit.is_hunting():
		return
	if _clock_real - _run_msg_at < RUN_MSG_COOLDOWN_S:
		return
	_run_msg_at = _clock_real
	run_messages += 1
	_run_msgs.append(_clock_real)
	while not _run_msgs.is_empty() and _clock_real - _run_msgs[0] > RUN_VERBAL_WINDOW_S:
		_run_msgs.pop_front()
	if _run_msgs.size() >= 3:
		_run_msgs.clear()
		Discipline.running_verbal()
		return
	EventBus.shero_message.emit("de_pie_en_live", "dm")  # correr sin motivo pone a Shero en Escribir


## F26: despegue y aterrizaje (player_landed con la altura caída: Q3 pone el golpe por superficie).
func _track_air() -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		if not _airborne:
			_airborne = true
			_air_peak_y = global_position.y
		_air_peak_y = maxf(_air_peak_y, global_position.y)
		return
	if _airborne:
		_airborne = false
		var fall := maxf(_air_peak_y - global_position.y, 0.0)
		if _jumping or fall > 0.25:
			EventBus.player_landed.emit(fall)
		if _jumping:
			_jump_cd = JUMP_COOLDOWN_S
		_jumping = false


func is_airborne() -> bool:
	return _airborne


# --- v0.3.1: no quedar atrapado en los muebles ------------------------------------------------------

## Salida declarada de un asiento o SleepSpot (Q5): hijo Node3D "Salida" o meta "salida" (Vector3 global). INF si no.
static func exit_anchor_of(n: Node) -> Vector3:
	if n == null or not is_instance_valid(n):
		return Vector3.INF
	var a := n.get_node_or_null("Salida") as Node3D
	if a != null:
		return a.global_position
	if n.has_meta("salida"):
		var v: Variant = n.get_meta("salida")
		if v is Vector3:
			return v
	return Vector3.INF


## ¿La cápsula del cuerpo se mete en geometría (capa 1) en `pos` (pies)?
func overlaps_at(pos: Vector3) -> bool:
	if not is_inside_tree() or collider == null or collider.shape == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collider.shape
	var xf := collider.global_transform
	xf.origin = pos + (collider.global_position - global_position) + Vector3(0, 0.08, 0)  # apoyado en el piso no cuenta
	q.transform = xf
	q.collision_mask = 1
	q.margin = 0.0
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## ¿Se ve `to` desde `from` a la altura del pecho? (el hueco libre no puede quedar del otro lado de una pared)
func _clear_line(from: Vector3, to: Vector3) -> bool:
	if from == Vector3.INF:
		return true
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), to + Vector3(0, 1.0, 0), 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## ¿Hay suelo debajo de `pos` (≤ 1,2 m)? (para no «rescatar» al jugador sobre el vacío)
func _floor_below(pos: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.4, 0), pos + Vector3(0, -1.2, 0), 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _unstick_later(hint: Vector3, why: String) -> void:
	await get_tree().physics_frame  # el cambio de capa (fantasma ↔ sólido) ya aplicado
	if is_instance_valid(self) and not seated and not lying:
		unstick(hint, why)


## Si el cuerpo está metido en geometría, sale a `hint` (si está libre) o al hueco libre más cercano con suelo
## (anillos de 0,25 a 2,5 m, 16 direcciones). Devuelve true si movió al jugador.
func unstick(hint: Vector3 = Vector3.INF, why: String = "", force: bool = false) -> bool:
	if not force and not overlaps_at(global_position):
		return false
	var here := global_position
	var ref := _safe_pos if _safe_valid else Vector3.INF  # último sitio pisado: el hueco debe verse desde ahí
	var cands: Array[Vector3] = []
	if hint != Vector3.INF:
		cands.append(Vector3(hint.x, here.y, hint.z))
	for r in [0.25, 0.45, 0.7, 1.0, 1.4, 1.9, 2.5]:
		for i in 16:
			var a := TAU * float(i) / 16.0
			cands.append(here + Vector3(cos(a) * r, 0.0, sin(a) * r))
	for c in cands:
		var p := c + Vector3(0, 0.05, 0)
		if not overlaps_at(p) and _floor_below(p) and not (force and _boxed_at(p)) and (force or _clear_line(ref, p)):
			global_position = p
			velocity = Vector3.ZERO
			_safe_valid = false
			unstuck_count += 1
			var line := "%s · (%.2f, %.2f, %.2f) → (%.2f, %.2f, %.2f)" % [why, here.x, here.y, here.z, p.x, p.y, p.z]
			unstuck_log.append(line)
			push_warning("Player: atrapado, sale al hueco libre: " + line)
			return true
	return false


## Perro guardián: 2 s pidiendo moverte sin moverte y sin salida en ninguna de las 8 direcciones (encerrado, no
## contra una pared) → al hueco libre más cercano.
func _stuck_watchdog(delta: float, dir: Vector3) -> void:
	if dir.length() < 0.1 or not is_on_floor():
		_stuck_t = 0.0
		_stuck_from = global_position
		return
	var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	if moved > 0.15:
		_stuck_t = 0.0
		_stuck_from = global_position
		return
	_stuck_t += delta
	if _stuck_t < STUCK_S:
		return
	_stuck_t = 0.0
	_stuck_from = global_position
	if overlaps_at(global_position) or _boxed_in():
		unstick(Vector3.INF, "encerrado", true)


func _boxed_in() -> bool:
	return _boxed_at(global_position)


## ¿Encerrado en `pos`? (ninguna de las 8 direcciones deja avanzar 0,3 m; se prueba 6 cm sobre el suelo para que
## el roce con el piso no cuente)
func _boxed_at(pos: Vector3) -> bool:
	var xf := global_transform
	xf.origin = pos + Vector3(0, 0.06, 0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		if not test_move(xf, Vector3(cos(a), 0.0, sin(a)) * 0.3):
			return false
	return true


## Stick derecho: mirar (GDD 9.2). Misma limitación de giro sentado que el mouse.
func _gamepad_look(delta: float) -> void:
	var lx := Input.get_axis("look_left", "look_right") if InputMap.has_action("look_left") else 0.0
	var ly := Input.get_axis("look_up", "look_down") if InputMap.has_action("look_up") else 0.0
	if absf(lx) < 0.05 and absf(ly) < 0.05:
		return
	var spd := 2.6 * float(Loc.get_setting("sensitivity", 1.0)) * delta
	rotate_y(-lx * spd)
	head.rotation.x = clampf(head.rotation.x - ly * spd, -1.4, 1.4)
	if seated:
		var lim := deg_to_rad(float(DataLoader.bal("jugador/giro_sentado_grados", 160.0)) * 0.5)
		var d := wrapf(rotation.y - _yaw_base, -PI, PI)
		rotation.y = _yaw_base + clampf(d, -lim, lim)


func _update_hint() -> void:
	if lying:
		var wake_txt := tr("HUD_WAKE")
		if wake_txt != _last_hint:
			_last_hint = wake_txt
			EventBus.interact_hint.emit(wake_txt)
		return
	var hit: Object = ray.get_collider() if ray.is_colliding() else null
	var inter: Interactable = hit as Interactable if hit != null else null
	_current_hint = inter
	var txt := inter.hint_text() if inter != null and inter.enabled else ""
	if seated and txt == "" and not _seat_locked():
		txt = tr("HUD_STAND")
	if txt != _last_hint:
		_last_hint = txt
		EventBus.interact_hint.emit(txt)


## v0.3 P6b: sesiones en las que no te puedes levantar (feedback, training, quiz, evento de Rasec: input_locked)
## y la sesión de coaching por Rooms: ahí no se muestra "[E] Levantarse".
func _seat_locked() -> bool:
	return input_locked or cinematic or Discipline.session_active()


func _try_interact() -> void:
	if seated:
		# Sentado: [E] sobre un monitor acerca la vista; en cualquier otro sitio, levantarse.
		if _current_hint is MonitorScreen and _current_hint.enabled:
			_current_hint.interact(self)
		else:
			stand_up()
		return
	if _current_hint != null and _current_hint.enabled:
		_current_hint.interact(self)


## Sentarse en una silla (Seat). Bloquea el movimiento y limita el giro.
func sit_at(seat: Node3D, id: String) -> void:
	if seated:
		return
	seated = true
	seat_node = seat
	seat_id = id
	# El Seat (área) flota a 0,8 m: el cuerpo va al suelo del cubículo, con el ojo a ~1,3 m.
	var floor_y := (seat.get_parent() as Node3D).global_position.y if seat.get_parent() is Node3D else seat.global_position.y - 0.8
	global_position = Vector3(seat.global_position.x, floor_y + 0.05, seat.global_position.z)
	rotation.y = seat.global_rotation.y
	_yaw_base = rotation.y
	head.position.y = 1.25
	_set_ghost(true)  # v0.3 P2: sentado sigues "dentro" de las zonas (la sala) pero nadie choca contigo
	if _rig != null:
		_rig.position = Vector3(0, 0, 0.2)
		_rig.play("sit")
	_declutter(true)
	EventBus.player_seated.emit(id)


func stand_up() -> void:
	if not seated:
		return
	# Si hay llamada activa sin hold, el cliente cuelga molesto (lo resuelve ContactManager).
	seated = false
	_set_ghost(false)
	var up := seat_node.global_position + seat_node.global_transform.basis.z * 0.9
	global_position = Vector3(up.x, global_position.y + 0.05, up.z)
	head.position.y = 1.6
	var exit_hint := exit_anchor_of(seat_node)
	seat_node = null
	_unstick_later(exit_hint, "levantarse")
	seat_id = ""
	if _rig != null:
		_rig.position = Vector3(0, -0.04, 0.17)
		_rig.play("idle")
	_declutter(false)
	EventBus.player_stood_up.emit()


## Base del piso actual (todas las plantas se construyen con el suelo en y = 0; la caja de escalera
## tiene el descanso alto en 3,2 pero su base también es 0).
func _floor_base_y() -> float:
	var b := get_tree().get_first_node_in_group("building")
	if b != null:
		var fl: Node = b.get("floor_node")
		if fl is FloorBase:
			return (fl as FloorBase).base_y
	return 0.0


func _safety_net(delta: float) -> void:
	if not safety_enabled:
		return
	if is_on_floor():
		_safe_t += delta
		if _safe_t >= SAFE_EVERY or not _safe_valid:
			_safe_t = 0.0
			_safe_pos = global_position
			_safe_yaw = rotation_degrees.y
			_safe_valid = true
		return
	var base := _floor_base_y()
	if global_position.y < base - KILL_BELOW:
		_rescue(base)


func _rescue(base: float) -> void:
	fall_rescues += 1
	var b := get_tree().get_first_node_in_group("building")
	var fl: int = int(b.get("current_floor")) if b != null else 0
	var here := global_position
	var line := "%s piso %d caída en (%.2f, %.2f, %.2f) → vuelta a (%.2f, %.2f, %.2f)" % [Time.get_datetime_string_from_system(), fl, here.x, here.y, here.z, _safe_pos.x, _safe_pos.y, _safe_pos.z]
	if _safe_valid:
		teleport(_safe_pos, _safe_yaw)
	else:
		var m: Node = (b.get("floor_node") as Node).find_child("ascensor", true, false) if b != null and b.get("floor_node") != null else null
		if m is Node3D:
			teleport((m as Node3D).global_position, (m as Node3D).rotation_degrees.y)
		else:
			teleport(Vector3(here.x, base + 0.1, here.z), rotation_degrees.y)
	velocity = Vector3.ZERO
	fall_log.append(line)
	push_warning("Player: " + line)
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open("user://logs/caidas.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://logs/caidas.log", FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
	EventBus.player_rescued.emit(here, fl)


func teleport(pos: Vector3, yaw_deg: float = 0.0) -> void:
	_declutter(false)
	if lying:
		_end_lying()
	reset_camera()
	if seated:
		seated = false
		_set_ghost(false)
		seat_node = null
		seat_id = ""
		if _rig != null:
			_rig.position = Vector3(0, -0.04, 0.17)
			_rig.play("idle")
	global_position = pos
	rotation.y = deg_to_rad(yaw_deg)
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_airborne = false
	_jumping = false
	_jump_t = -1.0
	_jump_request = false
	_safe_valid = false  # la próxima posición con los pies en el suelo pasa a ser la segura


## Para el overlay de frotarse los ojos (1 s de negro).
func is_rubbing_eyes() -> bool:
	return _rubbing > 0.0


# --- v0.3 P2: dormir (SleepSpot) ---------------------------------------------------------------

## Acostarse en un SleepSpot: la cabeza baja a eye_height, mirando al techo de lado; sin moverse.
func lie_down(spot: Node3D) -> void:
	if lying:
		return
	lying = true
	lie_spot = spot
	_wake_request = false
	_set_ghost(true)
	var eye_h := float(spot.get("eye_height")) if spot.get("eye_height") != null else 0.55
	global_position = Vector3(spot.global_position.x, (spot.get_parent() as Node3D).global_position.y if spot.get_parent() is Node3D else 0.0, spot.global_position.z)
	rotation.y = deg_to_rad(float(spot.get("yaw_deg")) if spot.get("yaw_deg") != null else 0.0)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "position:y", eye_h, 0.8)
	tw.tween_property(head, "rotation:x", 1.05, 0.8)
	tw.tween_property(camera, "rotation:z", deg_to_rad(-18.0), 0.8)
	if _rig != null:
		_rig.visible = false


## Levantarse del SleepSpot (lo llama SleepSpot.wake_up).
func get_up() -> void:
	if not lying:
		return
	var spot := lie_spot
	_end_lying()
	if spot != null and is_instance_valid(spot):
		# v0.3.1 (Joan 11:19Z): el SleepSpot no está girado (su orientación es yaw_deg, la del cuerpo acostado):
		# con basis.z el jugador salía siempre hacia +z, y en los sofás del -1 (yaw 180) eso es DENTRO del respaldo y
		# la pared. Ahora sale hacia el lado abierto del mueble (basis.z girado por yaw_deg); unstick() hace el resto.
		var fwd := spot.global_transform.basis.z
		if spot.get("yaw_deg") != null:
			fwd = Basis(Vector3.UP, deg_to_rad(float(spot.get("yaw_deg")))) * Vector3(0, 0, 1)
		global_position = spot.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 0.9
		global_position.y = (spot.get_parent() as Node3D).global_position.y + 0.05 if spot.get_parent() is Node3D else 0.05
		_unstick_later(exit_anchor_of(spot), "despertar")


func _end_lying() -> void:
	lying = false
	lie_spot = null
	_wake_request = false
	_set_ghost(false)
	head.position.y = 1.6
	head.rotation.x = 0.0
	camera.rotation.z = 0.0
	if _rig != null:
		_rig.visible = true


## SleepSpot pregunta cada frame si el jugador quiere despertar ([E] o moverse).
func wants_to_wake() -> bool:
	var w := _wake_request
	_wake_request = false
	return w


# --- v0.3 P2: cámara cinemática (screamers y colapso) -------------------------------------------

## Bloquea el control y entrega la cámara a un efecto (fx/screamers.gd, fx/collapse_fx.gd).
func set_cinematic(on: bool) -> void:
	cinematic = on
	input_locked = on or input_locked
	if on:
		velocity = Vector3.ZERO


## Deja la cámara como estaba (al reaparecer, al teletransportarse o al volver al menú).
func reset_camera() -> void:
	cinematic = false
	if camera == null:
		return
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = fov_base
	if not lying:
		head.position = Vector3(0, 1.25 if seated else 1.6, 0)
		head.rotation.x = clampf(head.rotation.x, -0.5, 0.5)



## Sentado/acostado: el cuerpo deja de chocar (capa 16 "jugador quieto", máscara 0) pero las zonas
## (Zone: máscara 1|16) lo siguen viendo. Antes se desactivaba la colisión y al sentarte en C-14 la zona
## "sala" emitía body_exited → GameState.in_room = false (la regla "fuera de la sala" se habría disparado
## sentado en tu PC).
const LAYER_GHOST := 16


func _set_ghost(on: bool) -> void:
	collision_layer = LAYER_GHOST if on else 1
	collision_mask = 0 if on else 1



# --- v0.3 P2: sentado, los letreros flotantes no tapan las pantallas ------------------------------

var _decluttered: Array[Label3D] = []


## Sentado en un puesto: oculta los Label3D del mundo que quedan delante y cerca (placa del cubículo,
## "don Aurelio", el cartel de La Central…) para que no se superpongan a los monitores. Las notas
## adhesivas (Nota_*) se quedan. Al levantarte vuelven.
func _declutter(on: bool) -> void:
	if not on:
		for l in _decluttered:
			if is_instance_valid(l):
				l.visible = true
		_decluttered.clear()
		return
	var b := get_tree().get_first_node_in_group("building")
	var fl: Node = b.get("floor_node") if b != null else null
	if fl == null or camera == null:
		return
	var eye := global_position + Vector3(0, 1.25, 0)
	var fwd := -global_transform.basis.z
	for n in fl.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if not l.visible or l.get_parent().name.begins_with("Nota_"):
			continue
		var to := l.global_position - eye
		if to.length() > 7.0:
			continue
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < 0.05 or fwd.dot(flat.normalized()) < 0.55:
			continue
		l.visible = false
		_decluttered.append(l)

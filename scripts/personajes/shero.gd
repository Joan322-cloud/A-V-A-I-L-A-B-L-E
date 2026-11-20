class_name Shero
extends CharacterBody3D
## Shero (v0.3 P3): ya no decide solo. Discipline (autoload) lleva las escaleras y él EJECUTA los escalones
## que se ven en el mundo (PLAN §4):
##   - Verbal: en persona si estás en el piso 2 (gira hacia ti, señala; su voz sale de su cuerpo); en el correo
##     de más de 10 min camina hasta DETRÁS de tu silla (lo ves en el reflejo del monitor apagado).
##   - Written warning: se pone calvo (S 13:28: afro en Observar/Llamado/Verbal; calvo desde el WW, en la
##     persecución y en todos sus screamers; vuelve al afro con la calma) y, si estás en tu sitio, viene a tu fila
##     con la amonestación y espera el Ack ("Bien.").
##   - Persecución: lo mueve Pursuit (core/pursuit.gd) en cualquier piso; aquí solo la animación (sprint).
## Reglas que conserva: no entra a ningún baño (Pursuit), respeta el Ack, no te toca en una llamada activa, en
## calma "está en reunión". Se borró la regla v0.2 de "de pie en Live" (pararte dentro de la sala es libre) y
## el uso de los bloques para matar (los bloques quedan solo para su comportamiento ambiental).
## Look: `bald` + set_look("afro" | "calvo"); oculta el nodo "Afro" del modelo v2 (CharacterRig.set_look) y emite
## look_changed. Shero mide 2,2 m con el afro (CharacterRig.HEIGHTS_V2) en el mundo, la presencia y los screamers.
## Visitante (otro piso): Pursuit lo instancia con setup_visitor(); no tiene escritorio ni reglas.
## v0.3.1 Q2 (F19): trabaja SENTADO en su escritorio del TM (NpcDesks): tecleando o mirando la sala por encima de los
## monitores (la cabeza te sigue). Para todo lo que hace se levanta (clip stand_up, 0,9 s): señalarte en el verbal,
## ir a tu fila con el WW, ir detrás de tu silla, salir corriendo en la persecución (Pursuit espera pursuit_hold()).
## Al terminar vuelve CAMINANDO a su silla y se sienta (sit_down). En sus screamers la cara se deforma (ScreamRig).

signal look_changed(look: String)

enum State { OBSERVAR, ESCRIBIR, CAMINAR, COACHING, PERSEGUIR, SCREAMER }

var state: int = State.OBSERVAR
var home: Vector3 = Vector3(46.9, 0, -9)
var speed: float = 3.9
var bald: bool = false
var look: String = "afro"
var visitor: bool = false
var pursuit_driven: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _floor: FloorBase = null
var _player: Player = null
var _label: Label3D = null
var _reflection_shown: bool = false
var _rig: CharacterRig = null
var _writing_left: float = 0.0
var _wait_left: float = 0.0
var _walk_goal: String = ""  # "detras" (correo), "fila" (WW), "reflejo" (KYC guionizado), "casa"
var _look_t: float = 0.0
var _step_t: float = 0.0
var _steps: AudioStreamPlayer3D = null
var seated: bool = false  # sentado en su escritorio (F19)
var _stand_left: float = 0.0  # segundos que le faltan para terminar de pararse
var _sit_left: float = 0.0
var _returning: bool = false  # vuelve caminando a su silla
var stand_ups: int = 0  # veces que se levantó (pruebas)
var _giant_step_cd: float = 0.0
var _giant_growl_cd: float = 12.0


func _ready() -> void:
	add_to_group("shero")
	collision_layer = 4
	collision_mask = 1
	speed = float(DataLoader.bal("shero/velocidad_caminar_ms", 3.9))
	_label = get_node_or_null("Estado") as Label3D
	if _label != null:
		_label.visible = OS.get_cmdline_user_args().has("--debug-labels")
	_rig = CharacterRig.attach(self, "shero", 2.2)  # v2 con el afro (CharacterRig.HEIGHTS_V2)
	if _rig != null:
		for n in ["Cuerpo", "Clipboard"]:
			var ph := get_node_or_null(n)
			if ph != null:
				ph.visible = false
		_rig.ensure_desk_clips()
		_rig.play("idle")
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Pasos"
	_steps.bus = "Sala"
	_steps.unit_size = 5.0
	_steps.pitch_scale = 0.8
	add_child(_steps)
	EventBus.discipline_step.connect(_on_step)
	EventBus.ack_given.connect(_on_ack_given)
	EventBus.respawned.connect(_on_respawned)
	EventBus.calm_started.connect(func(_s: float) -> void: set_look("afro"))
	EventBus.ezlak_post.connect(_on_ezlak_post)
	EventBus.contact_ended.connect(_on_contact_ended)
	EventBus.scripted_event.connect(func(id: String) -> void: if id == "shero_en_el_reflejo": scripted_reflection())


func setup(floor_node: FloorBase, player: Player) -> void:
	_floor = floor_node
	_player = player
	NpcDesks.ensure(floor_node)
	var m := floor_node.find_child("escritorio_shero", true, false)
	if m == null:
		m = floor_node.find_child("shero_sitio", true, false)
	if m is Node3D:
		home = (m as Node3D).global_position
	global_position = home
	_sit_now()
	_set_state(State.OBSERVAR)


## Pursuit: Shero que llega a otro piso (o a la caja de escalera) persiguiéndote.
func set_visitor(on: bool) -> void:
	visitor = on


func setup_visitor(floor_node: Node3D, player: Player) -> void:
	visitor = true
	_floor = floor_node as FloorBase
	_player = player
	home = global_position
	set_look("calvo")
	_set_state(State.PERSEGUIR)


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	EventBus.shero_state_changed.emit(s)
	if _label != null:
		_label.text = ["Observar", "Escribir", "Caminar", "Coaching", "Perseguir", "Screamer"][s]
	if _rig != null and not (_stand_left > 0.0 and s in [State.CAMINAR, State.PERSEGUIR, State.COACHING]):
		match s:
			State.OBSERVAR:
				if seated:
					_rig.play("sit", true, 1.0, ["idle"])
				elif not _returning:
					_rig.play("idle")
			State.ESCRIBIR:
				_rig.play("sit_type" if seated else "type", true, 1.0, ["type", "idle"])
			State.CAMINAR:
				_rig.play("walk")
			State.COACHING:
				_rig.play("point", false, 1.0, ["idle"])
			State.PERSEGUIR:
				_rig.play("sprint", true, 1.0, ["run", "walk"])
			State.SCREAMER:
				_rig.play("jumpscare_main", false)


## Afro (normal) / calvo (enojado). Oculta el nodo "Afro" del modelo si lo tiene (v2); si no, solo la bandera.
func set_look(l: String) -> void:
	var b := l == "calvo"
	if look == l and bald == b:
		return
	look = l
	bald = b
	if _rig != null:
		_rig.set_look(l)  # P6: oculta el nodo Afro del modelo v2
	else:
		var afro := find_child("Afro", true, false) as Node3D
		if afro != null:
			afro.visible = not b
	look_changed.emit(l)


func _physics_process(delta: float) -> void:
	if GameState.turno == 5:
		_tick_giant_shero(delta)
	if _stand_left > 0.0:
		_stand_left -= delta
		if _stand_left <= 0.0:
			_on_stood()
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.25
		set_look("calvo" if (visitor or GameState.turno >= 5 or Discipline.shero_bald()) else "afro")
	if _player == null or pursuit_driven or not GameState.running or GameState.shift_over:
		return
	if visitor:
		return
	_check_reflection()
	if _sit_left > 0.0:
		_sit_left -= delta
		if _sit_left <= 0.0 and seated and _rig != null:
			_rig.play("sit_type" if state == State.ESCRIBIR else "sit", true, 1.0, ["sit", "idle"])
	if _stand_left > 0.0:
		return  # se está levantando
	match state:
		State.OBSERVAR:
			if _returning:
				if GameState.in_calm or _follow_path(delta):
					_returning = false
					global_position = home
					_sit_down()
			elif seated:
				_seat_look()
			else:
				_face(_player.global_position if _player_visible() else home + Vector3(-1, 0, 0))
		State.ESCRIBIR:
			_writing_left -= delta
			if _writing_left <= 0.0:
				_set_state(State.OBSERVAR)
		State.CAMINAR:
			if GameState.in_calm:
				go_home()
			elif _follow_path(delta):
				if _walk_goal == "casa":
					_set_state(State.OBSERVAR)
					global_position = home
				else:
					_set_state(State.COACHING)
					_face(_player.global_position)
		State.COACHING:
			# De pie detrás de tu silla / al final de tu fila, mirándote, hasta que corrijas o des Ack.
			_face(_player.global_position)
			_wait_left -= delta
			if _wait_left <= 0.0 or not _player_visible() or GameState.in_calm:
				go_home()


# --- Escalones que se ven -------------------------------------------------------------------------

func _on_step(track: String, step: int, info: Dictionary) -> void:
	if visitor or _floor == null or not is_inside_tree() or str(info.get("ejecutor", "shero")) != "shero":
		return
	if step == 2 and _player_visible():  # Discipline.Step.VERBAL
		if track == "correo" and GameState.seated_at != "":
			walk_behind_player("detras", 600.0)
		elif state == State.OBSERVAR or state == State.ESCRIBIR:
			_stand_up()
			_face(_player.global_position)
			if _rig != null:
				_point_after_stand()
	elif step == 3 and _player_visible() and GameState.seated_at != "" and state in [State.OBSERVAR, State.ESCRIBIR]:
		walk_behind_player("fila", 40.0)


## Camina hasta detrás de tu silla ("detras") o al final de tu fila ("fila") y espera `wait_s` reales.
func walk_behind_player(goal: String, wait_s: float) -> void:
	if _player == null or not _player_visible() or state in [State.PERSEGUIR, State.SCREAMER]:
		return
	_walk_goal = goal
	_wait_left = wait_s
	_stand_up()
	var behind := _player.global_position + _player.global_transform.basis.z * (1.3 if goal != "fila" else 2.4)
	_set_target(behind)
	_set_state(State.CAMINAR)


## Evento guionizado del KYC de T1 ("shero_en_el_reflejo"): Shero va detrás de tu silla y te MIRA trabajar
## (reflejo en el monitor apagado). v0.3: NO castiga (v0.2 te daba un WW "reflejo_kyc" aunque lo hicieras
## bien: injusto para el jugador obediente). Se va cuando cierras el caso.
func scripted_reflection() -> void:
	if visitor or state in [State.CAMINAR, State.COACHING, State.PERSEGUIR, State.SCREAMER] or not _player_visible():
		return
	_reflection_shown = false
	walk_behind_player("reflejo", 90.0)


## Al cerrar el caso (o colgar), se va de detrás de tu silla; en el KYC guionizado dice "Sigo mirando."
func _on_contact_ended(_c: Dictionary, _r: bool, _a: bool) -> void:
	if visitor or pursuit_driven or not is_inside_tree() or not (_walk_goal in ["reflejo", "detras"]) or not (state in [State.CAMINAR, State.COACHING]):
		return
	if _walk_goal == "reflejo":
		var l: Array = ((DataLoader.dict("lineas_shero").get("escalera", {}) as Dictionary).get("reflejo", {}) as Dictionary).get("voz", [])
		if not l.is_empty() and Discipline.presence != null:
			Discipline.presence.call("speak", "shero", Loc.pick(l[0]), str((l[0] as Dictionary).get("voz", "")), "voz")
	go_home()


## "Aparece en el reflejo de tu monitor antes de que lo oigas" (GDD 5.2): si está detrás de ti sentado y a
## < 3 m, el monitor derecho se apaga 1-2 s y muestra su silueta, con un golpe grave.
func _check_reflection() -> void:
	if state == State.OBSERVAR or state == State.ESCRIBIR or state == State.SCREAMER:
		_reflection_shown = false
		return
	if not _player.seated or GameState.seated_at == "":
		return
	var to_me := global_position - _player.global_position
	to_me.y = 0.0
	var dist := to_me.length()
	if dist > 4.0:
		_reflection_shown = false
		return
	if _reflection_shown or dist > 3.0:
		return
	var forward := -_player.global_transform.basis.z
	if to_me.normalized().dot(forward) > -0.2:
		return  # no está detrás
	_reflection_shown = true
	var target: MonitorScreen = null
	for s in get_tree().get_nodes_in_group("monitor_screens"):
		if s is MonitorScreen and (s as MonitorScreen).seat_id == GameState.seated_at:
			if target == null or not (s as MonitorScreen).powered or (s as MonitorScreen).side == "right":
				target = s
	if target != null:
		target.show_reflection(Faces.reflection_texture("shero"), 1.8)
	AudioManager.play_sting()
	EventBus.distortion_triggered.emit("shero_en_el_reflejo")


func _on_ack_given() -> void:
	# Regla 2: un Ack a tiempo siempre lo devuelve a su sitio ("Bien."), salvo en una persecución.
	if visitor or pursuit_driven:
		return
	if state in [State.CAMINAR, State.COACHING] and _walk_goal != "detras":
		go_home()


func _on_ezlak_post(_ch: String, author: String, _text: String, meta: Dictionary) -> void:
	# "Shero está escribiendo…": en su sitio teclea mientras dura el indicador de Ezlaki.
	if visitor or author != "shero" or float(meta.get("typing_s", 0.0)) <= 0.0:
		return
	if state == State.OBSERVAR:
		_writing_left = float(meta.get("typing_s", 0.0)) + 0.5
		_set_state(State.ESCRIBIR)


func _on_respawned(_kind: String) -> void:
	pursuit_driven = false
	_memo(false)
	set_look("afro")
	if visitor:
		return
	if _floor != null and is_inside_tree():
		go_home(true)


## Vuelve a su escritorio: caminando si lo puedes ver (nada de aparecer sentado de golpe), y se sienta.
func go_home(instant: bool = false) -> void:
	_walk_goal = "casa"
	_path = PackedVector3Array()
	var far := global_position.distance_to(home) > 0.6
	if far and not instant and _floor != null and is_inside_tree() and _player_visible() and not GameState.in_calm:
		_returning = true
		_set_target(home)
		_set_state(State.OBSERVAR)
		if _rig != null:
			_rig.play("walk")
		return
	_returning = false
	_set_state(State.OBSERVAR)
	global_position = home
	_sit_now()


## Se sienta en el acto (inicio, reaparecer).
func _sit_now() -> void:
	seated = true
	_stand_left = 0.0
	rotation.y = _home_yaw()
	if _rig != null:
		_rig.play("sit", true, 1.0, ["idle"])


func _home_yaw() -> float:
	var m := _floor.find_child("escritorio_shero", true, false) as Node3D if _floor != null else null
	if m == null:
		m = _floor.find_child("shero_sitio", true, false) as Node3D if _floor != null else null
	return m.global_rotation.y if m != null else deg_to_rad(90.0)


## Se sienta (clip sit_down) al llegar a su escritorio.
func _sit_down() -> void:
	rotation.y = _home_yaw()
	seated = true
	_sit_left = CharacterRig.STAND_S
	if _rig != null:
		_rig.play("sit_down", false, 1.0, ["sit", "idle"])


## Se levanta del escritorio (clip stand_up). Devuelve los segundos que tarda (0 si ya estaba de pie).
func _stand_up() -> float:
	if not seated:
		return 0.0
	seated = false
	_returning = false
	stand_ups += 1
	_stand_left = CharacterRig.STAND_S
	if _rig != null:
		_rig.play("stand_up", false, 1.0, ["idle"])
		var sr := _rig.scream_rig()
		if sr != null:
			sr.look = 0.0
	return CharacterRig.STAND_S


## Terminó de pararse: el clip del estado en que está.
func _on_stood() -> void:
	if _rig == null:
		return
	match state:
		State.CAMINAR:
			_rig.play("walk")
		State.PERSEGUIR:
			_rig.play("sprint", true, 1.0, ["run", "walk"])
		State.COACHING:
			_rig.play("point", false, 1.0, ["idle"])


func _point_after_stand() -> void:
	await get_tree().create_timer(maxf(_stand_left, 0.01)).timeout
	if _rig != null and is_inside_tree() and state in [State.OBSERVAR, State.ESCRIBIR] and not seated:
		_rig.play("point", false, 1.0, ["idle"])
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree() and state in [State.OBSERVAR, State.ESCRIBIR] and not seated and not _returning and not pursuit_driven:
		_sit_down()


## Sentado: la cabeza te sigue por encima de los monitores si estás en la sala.
func _seat_look() -> void:
	if _rig == null:
		return
	var sr := _rig.scream_rig()
	if sr == null:
		return
	var see := _player_visible() and _player.global_position.distance_to(global_position) < 30.0 and state == State.OBSERVAR and _sit_left <= 0.0
	sr.look = move_toward(sr.look, 0.75 if see else 0.0, get_physics_process_delta_time() * 1.5)
	if see:
		sr.look_at_point = _player.camera.global_position if _player.camera != null else _player.global_position + Vector3(0, 1.6, 0)


## Pursuit: tiempo que le falta para estar de pie (se levanta de su escritorio antes de correr).
func pursuit_hold() -> float:
	return _stand_left


# --- Pursuit ----------------------------------------------------------------------------------------

func on_pursuit_start(_cause: String) -> void:
	if not visitor:
		_stand_up()
	pursuit_driven = true
	set_look("calvo")
	_set_state(State.PERSEGUIR)
	_memo(true)


## La "amonestación asesina": el memo impreso con el sello rojo en la mano mientras te persigue.
func _memo(on: bool) -> void:
	var m := get_node_or_null("Amonestacion") as Node3D
	if m == null and on:
		m = Greybox.box(self, "Amonestacion", Vector3(0.34, 1.12, -0.32), Vector3(0.21, 0.29, 0.006), Color(0.93, 0.92, 0.88), false, 0.25)
		Greybox.box(m, "Sello", Vector3(0.04, -0.07, -0.004), Vector3(0.08, 0.06, 0.002), Greybox.ROJO, false, 1.2)
		Greybox.box(m, "Texto", Vector3(-0.01, 0.06, -0.004), Vector3(0.15, 0.08, 0.002), Color(0.25, 0.25, 0.27), false)
		m.rotation_degrees = Vector3(-20, 10, 0)
	if m != null:
		m.visible = on


func on_pursuit_move(moving: bool, spd: float) -> void:
	if _rig != null:
		if moving:
			_rig.play("sprint" if spd > 4.0 else "walk", true, clampf(spd / 4.6, 0.7, 1.4), ["run", "walk"])
		else:
			_rig.play("idle")
	if moving:
		_step_t -= get_physics_process_delta_time()
		if _step_t <= 0.0:
			_step_t = clampf(2.2 / maxf(spd, 0.5), 0.3, 0.7)
			var path := AudioManager.resolve("sfx/pasos_alfombra" if GameState.current_floor == 2 else "sfx/pasos_porcelanato")
			if path != "" and not _steps.playing:
				_steps.stream = load(path) as AudioStream
				_steps.play()


func on_pursuit_catch() -> void:
	_set_state(State.SCREAMER)


func on_pursuit_spare() -> void:
	pursuit_driven = false
	_memo(false)
	if not visitor:
		go_home()


func on_pursuit_end(_reason: String) -> void:
	pursuit_driven = false
	_memo(false)
	if not visitor and state == State.PERSEGUIR:
		go_home()


# --- Movimiento ---------------------------------------------------------------------------------------

func _player_visible() -> bool:
	return GameState.current_floor == 2 and _player != null and is_instance_valid(_player)


func _face(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.z)


## Ruta con la rejilla del piso (Pursuit.grid_for); si no hay, los waypoints del piso.
func _set_target(target: Vector3) -> void:
	if _floor == null:
		return
	var g := Pursuit.grid_for(_floor)
	if g != null and g.cells > 0:
		_path = g.find_path(global_position, target)
	else:
		_path = _floor.path(global_position, target)
	_path_i = 0


func _follow_path(delta: float, spd: float = speed) -> bool:
	if _path_i >= _path.size():
		return true
	var target := _path[_path_i]
	var d := target - global_position
	d.y = 0.0
	var step := spd * delta
	if d.length() <= maxf(step, 0.05):
		global_position = Vector3(target.x, target.y, target.z)
		_path_i += 1
		return _path_i >= _path.size()
	global_position += d.normalized() * step
	_face(target)
	return false


## v0.4 · Viernes (Turno 5, Penultimo): Shero Gigante colosal (2.35x -> 2.85x, ~5.2 a 6.3 metros), deformacion progresiva y pisadas sismicas.
func _tick_giant_shero(delta: float) -> void:
	var prog := clampf(GameState.clock_seconds / maxf(GameState.shift_end_seconds(), 1.0), 0.0, 1.0)
	var target_s := lerpf(2.35, 2.85, prog)
	scale = scale.lerp(Vector3(target_s, target_s, target_s), clampf(delta * 1.5, 0.0, 1.0))
	if _steps != null:
		_steps.pitch_scale = lerpf(0.62, 0.48, prog)
		_steps.volume_db = 4.0
	if _rig != null:
		var base_def := lerpf(0.28, 0.96, prog)
		var pulse := 0.06 * sin(Time.get_ticks_msec() * 0.007)
		_rig.set_deform(clampf(base_def + pulse, 0.0, 1.0))
		var sr := _rig.scream_rig()
		if sr != null:
			sr.severity = clampf(0.55 + prog * 0.45, 0.0, 1.0)
			sr.tremor = 1.4 + prog * 1.2
	if _player != null and is_instance_valid(_player) and GameState.running and not GameState.shift_over:
		var dist := global_position.distance_to(_player.global_position)
		_giant_step_cd -= delta
		if _giant_step_cd <= 0.0 and (state in [State.CAMINAR, State.PERSEGUIR] or dist < 14.0):
			_giant_step_cd = 0.62 if state == State.PERSEGUIR else 1.15
			var quake := clampf(1.0 - dist / 24.0, 0.08, 0.85)
			GfxLens.kick(quake * 0.55, 0.45)
			AudioManager.play_sfx("golpes_puerta_lejanos", "Sala")
		_giant_growl_cd -= delta
		if _giant_growl_cd <= 0.0 and dist < 18.0:
			_giant_growl_cd = randf_range(16.0, 26.0)
			GfxLens.kick(0.45, 0.7)
			AudioManager.play_sfx("silla_crujido_largo", "Sala")

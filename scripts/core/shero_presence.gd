extends Node
## SheroPresence (v0.3 P3, dirección de Joan: "más terror, que se sienta su presencia"): solo presentación,
## siempre legible y nunca injusta. Hijo del autoload Discipline.
## - speak(autor, texto, voz, canal): la voz del ejecutor de un escalón. canal "voz" = en persona si está en tu
##   piso (voz 3D desde su cuerpo, subtítulo "Shero"); si no, por los PARLANTES del piso donde estés (ding-dong,
##   la voz, subtítulo "Shero (parlantes)" y, si ya está enojado, su respiración por los parlantes). "pa" = siempre
##   parlantes; "rooms" = la sesión de Ezlaki Rooms (auricular).
## - Apariciones: desde el Verbal, en otro piso (no el 2), Shero de pie al final del pasillo, inmóvil; cuando
##   vuelves a mirar ya no está. Nunca durante una persecución ni a menos de 12 m.
## - Pasos detrás de ti desde el WW (sin nadie). "Shero está escribiendo…" en tu DM sin mensaje desde el llamado.
## - Persecución: "¡Te voy a traer de las orejas!" al verte, "Yo no entro. Yo espero." en la puerta del baño,
##   las luces del piso caen un instante cuando sale del ascensor.
## Las luces que bajan con el enojo y la viñeta las hace Dread (P2) leyendo Discipline.counters.
## - P7: los parlantes suenan por el bus "Parlantes" (banda de teléfono, saturación y eco de pasillo en tiempo real:
##   la misma voz limpia sirve en persona y por los parlantes) y Shero dice en su sitio los clips cosechados de
##   `lineas_shero.json/ambiente` a su hora (madrugada, cola alta, Ezlaki profesional…), con su post en Ezlaki.

var apparitions: int = 0  # contador (pruebas)
var pa_count: int = 0
var last_pa: String = ""
var _ghost: Node3D = null
var _ghost_seen_t: float = 0.0
var _ghost_age: float = 0.0
var _ghost_cd: float = 60.0
var _steps_cd: float = 40.0
var _typing_cd: float = 50.0
var _tick: float = 0.0
var _pa: AudioStreamPlayer = null
var _breath: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()
var ambient_done: Array = []  # índices de lineas_shero.json/ambiente ya dichos este turno (pruebas)
var ambient_said: Array = []  # [{voz, en_persona}] (pruebas)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1313
	_pa = AudioStreamPlayer.new()
	_pa.name = "Parlantes"
	_pa.bus = "Parlantes" if AudioServer.get_bus_index("Parlantes") >= 0 else "Sala"
	add_child(_pa)
	_breath = AudioStreamPlayer.new()
	_breath.name = "RespiracionParlantes"
	_breath.bus = "Parlantes" if AudioServer.get_bus_index("Parlantes") >= 0 else "Sala"
	_breath.pitch_scale = 0.82
	_breath.volume_db = -9.0
	add_child(_breath)
	EventBus.respawned.connect(func(_k: String) -> void: _vanish(false))
	EventBus.returned_to_menu.connect(func() -> void: _vanish(false))
	EventBus.pursuit_started.connect(func(_h: String, _c: String) -> void: _vanish(false))
	EventBus.shift_started.connect(func() -> void: ambient_done.clear(); ambient_said.clear())
	EventBus.clock_tick.connect(_on_clock_ambient)


## Clips cosechados de Shero en su sitio (lineas_shero.json/ambiente, P7). Una vez por turno cada uno; si el reloj
## ya pasó hace más de 20 min de juego (checkpoint, salto del reloj) se da por dicho sin sonar.
func _on_clock_ambient(now: float) -> void:
	if not GameState.running or GameState.shift_over or GameState.is_tutorial() or not GameState.logged_in:
		return
	if now < 0.0 or now > GameState.shift_end_seconds():  # llegada (23:48) y salida: fuera del turno
		return
	var amb: Dictionary = DataLoader.dict("lineas_shero").get("ambiente", {})
	var lines: Array = amb.get("lineas", [])
	for i in lines.size():
		if ambient_done.has(i) or not (lines[i] is Dictionary):
			continue
		var l: Dictionary = lines[i]
		var turnos: Array = []
		for x in (l.get("turnos", [1, 2, 3]) as Array):
			turnos.append(int(x))  # el JSON los devuelve como float
		if not turnos.has(GameState.turno):
			ambient_done.append(i)
			continue
		var t := GameState.hhmm_to_seconds(str(l.get("hora", "00:00")))
		if now < t:
			continue
		ambient_done.append(i)
		if now - t > 20.0 * 60.0 or Checkpoints.dying:
			continue
		var text := Loc.pick(l)
		if str(l.get("post", "")) != "":
			EventBus.ezlak_post.emit(str(l["post"]), "shero", text, {"tipo": "ambiente", "typing_s": 2.0})
		var n := _executor_node("shero")
		var p := _player()
		var calm := n != null and not ("pursuit_driven" in n and bool(n.get("pursuit_driven"))) and Discipline.max_step() < 3
		if calm and p != null and not Discipline.is_frozen() and n.global_position.distance_to(p.global_position) <= float(amb.get("radio", 34.0)):
			_voice_3d(n, "shero", str(l.get("voz", "")), VoiceDirector.P.AMBIENTE)  # comentario de ambiente
			EventBus.subtitle.emit("shero", "%s: %s" % [_name("shero"), text], 4.5)
			ambient_said.append({"voz": str(l.get("voz", "")), "en_persona": true})
		else:
			ambient_said.append({"voz": str(l.get("voz", "")), "en_persona": false})


func _cfg() -> Dictionary:
	var v: Variant = DataLoader.dict("escalada").get("presencia", {})
	return v if v is Dictionary else {}


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building if is_inside_tree() else null


## Nodo del ejecutor en el piso del jugador (Shero del piso 2 o el que persigue), visible.
func _executor_node(autor: String) -> Node3D:
	var b := _building()
	if b == null or b.floor_node == null:
		return null
	for n in get_tree().get_nodes_in_group(autor):
		if n is Node3D and (n as Node3D).visible and b.floor_node.is_ancestor_of(n):
			return n as Node3D
	return null


func _name(autor: String) -> String:
	return "Rasec" if autor == "rasec" else ("Shero" if autor == "shero" else autor.capitalize())


func speak(autor: String, text: String, voz: String, canal: String) -> void:
	var p := _player()
	if canal == "rooms":
		AudioManager.play_voice(autor, voz, "", "Auricular")
		EventBus.subtitle.emit(autor, "%s · Rooms: %s" % [_name(autor), text], 4.5)
		return
	var n := _executor_node(autor) if canal == "voz" else null
	if n != null and p != null and n.global_position.distance_to(p.global_position) <= 30.0:
		_voice_3d(n, autor, voz)
		EventBus.subtitle.emit(autor, "%s: %s" % [_name(autor), text], 4.5)
		return
	pa(autor, text, voz)


## Anuncio por los parlantes del piso donde estés (también en la escalera y el ascensor).
func pa(autor: String, text: String, voz: String) -> void:
	pa_count += 1
	last_pa = text
	# v0.3.1 Q3 (B8): el ding-dong es sfx/pa_chime.ogg (vibráfono por la bocina del techo, con eco), no dos senos.
	var chime := AudioManager.stream_for("sfx/pa_chime")
	if chime != null:
		_pa.stream = chime
		_pa.volume_db = -6.0 + AudioManager.gain_db("sfx/pa_chime")
		_pa.play()
	EventBus.subtitle.emit(autor, Loc.fmt(tr("P3_SPK_PA"), {"quien": _name(autor)}) + ": " + text, 5.0)
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return
	if voz != "":
		AudioManager.play_voice(autor, voz, "", "Parlantes")
		EventBus.subtitle.emit(autor, Loc.fmt(tr("P3_SPK_PA"), {"quien": _name(autor)}) + ": " + text, 5.0)
	if autor == "shero" and bool(_cfg().get("respiracion_pa", true)) and Discipline.max_step() >= 2:
		await get_tree().create_timer(2.4).timeout
		var path := AudioManager.resolve("sfx/respiracion")
		if path != "" and is_inside_tree():
			_breath.stream = load(path) as AudioStream
			_breath.play()


func _voice_3d(n: Node3D, autor: String, voz: String, prio: int = VoiceDirector.P.DIRECTO) -> void:
	var path := AudioManager.resolve("voces/%s/%s" % [autor, voz]) if voz != "" else ""
	if Loc.language != "es" and voz != "":
		var en := AudioManager.resolve("voces/%s/%s/%s" % [autor, Loc.language, voz])
		if en != "":
			path = en
	if path == "":
		AudioManager.play_voice(autor, voz, "", "Sala", prio)  # pitido + MISSING (P6 sintetiza la línea)
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(path) as AudioStream
	s.bus = "Sala"
	s.unit_size = 9.0
	s.max_db = 4.0
	n.add_child(s)
	s.position = Vector3(0, 1.7, 0)
	s.finished.connect(s.queue_free)
	VoiceDirector.say_external(s, "voces/%s/%s" % [autor, voz], prio, autor, {"free_on_drop": true})  # v0.3.2: una voz a la vez


func ack_ok() -> void:
	var n := _executor_node("shero")
	if n != null:
		var l: Array = ((DataLoader.dict("lineas_shero").get("escalera", {}) as Dictionary).get("ack_ok", {}) as Dictionary).get("voz", [])
		if not l.is_empty():
			speak("shero", Loc.pick(l[0]), str((l[0] as Dictionary).get("voz", "")), "voz")


func _line(group: String, key: String, i: int = -1) -> Dictionary:
	var l: Array = ((DataLoader.dict("lineas_shero").get("escalera", {}) as Dictionary).get(group, {}) as Dictionary).get(key, [])
	if l.is_empty():
		return {}
	return l[(i if i >= 0 else _rng.randi_range(0, l.size() - 1)) % l.size()]


func hunter_sees_you(n: Node3D) -> void:
	var m := _line("persecucion", "al_verte")
	if not m.is_empty() and n != null:
		_voice_3d(n, "shero", str(m.get("voz", "")))
		EventBus.subtitle.emit("shero", "Shero: " + Loc.pick(m), 3.5)


func bathroom_wait(n: Node3D) -> void:
	var m := _line("persecucion", "bano", 0)
	if not m.is_empty() and n != null:
		_voice_3d(n, "shero", str(m.get("voz", "")))
		EventBus.subtitle.emit("shero", "Shero: " + Loc.pick(m), 4.5)


## Shero sale del ascensor / de la cortafuego: las luces del piso caen un instante.
func hunter_arrived(_n: Node3D) -> void:
	var b := _building()
	if b == null or b.floor_node == null:
		return
	AudioManager.play_sting()
	var lights: Array[Light3D] = []
	for l in b.floor_node.find_children("*", "Light3D", true, false):
		if (l as Light3D).has_meta("mood_base"):
			lights.append(l as Light3D)
			(l as Light3D).light_energy = float(l.get_meta("mood_base")) * 0.12
	await get_tree().create_timer(0.35).timeout
	for l in lights:
		if is_instance_valid(l):
			l.light_energy = float(l.get_meta("mood_base")) * FlickerLight.mood


# --- Presencia ambiental ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _ghost != null:
		_tick_ghost(delta)
	if not GameState.running or not GameState.logged_in or GameState.in_calm or Checkpoints.dying or get_tree().paused:
		return
	var c := _cfg()
	var st := Discipline.max_step()
	var hunting := Pursuit.is_hunting()
	_ghost_cd -= delta
	_steps_cd -= delta
	_typing_cd -= delta
	if st >= int(c.get("escribiendo_desde_escalon", 1)) and _typing_cd <= 0.0:
		var r: Array = c.get("escribiendo_cada_s", [45, 90])
		_typing_cd = _rng.randf_range(float(r[0]), float(r[1]))
		var hub := EzlakHub.get_hub(get_tree())
		var tr_s: Array = c.get("escribiendo_s", [3, 7])
		if hub != null:
			hub.typing("dm:shero", "shero", _rng.randf_range(float(tr_s[0]), float(tr_s[1])))
	if hunting:
		return
	var b := _building()
	var p := _player()
	if b == null or p == null or b.floor_node == null:
		return
	var off_floor2 := b.current_floor != 2 or b.floor_node is Stairwell
	if st >= int(c.get("pasos_desde_escalon", 3)) and _steps_cd <= 0.0 and off_floor2:
		var r2: Array = c.get("pasos_cada_s", [35, 70])
		_steps_cd = _rng.randf_range(float(r2[0]), float(r2[1]))
		_footsteps_behind(p)
	if st >= int(c.get("aparicion_desde_escalon", 2)) and _ghost_cd <= 0.0 and _ghost == null and off_floor2 and not p.seated and not p.lying:
		var r3: Array = c.get("aparicion_cada_s", [70, 130])
		_ghost_cd = _rng.randf_range(float(r3[0]), float(r3[1]))
		spawn_apparition()


## Pasos de alguien grande a 4-6 m detrás de ti, sin nadie (3-4 pasos).
func _footsteps_behind(p: Player) -> void:
	var path := AudioManager.resolve("sfx/pasos_porcelanato")
	if path == "":
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(path) as AudioStream
	s.bus = "Sala"
	s.unit_size = 4.0
	s.pitch_scale = 0.78
	s.volume_db = -4.0
	var fl := _building().floor_node
	fl.add_child(s)
	s.global_position = p.global_position + p.global_transform.basis.z * 5.0 + Vector3(0, 0.3, 0)
	s.play()
	# v0.3.2-core: el corte es del propio reproductor (su tween muere con él). Antes era un temporizador del árbol con
	# una lambda que capturaba al reproductor: si el piso se descargaba antes (ascensor, escalera, persecución), el
	# motor escribía «Lambda capture at index 0 was freed» en la consola.
	var tw := s.create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(s.queue_free)


## Shero de pie al final del pasillo, frente a ti (12-24 m, con línea de vista). Devuelve true si apareció.
func spawn_apparition() -> bool:
	var b := _building()
	var p := _player()
	if b == null or p == null or b.floor_node == null or _ghost != null:
		return false
	var cam := p.camera
	var space := cam.get_world_3d().direct_space_state
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return false
	fwd = fwd.normalized()
	var c := _cfg()
	var dr: Array = c.get("aparicion_dist_m", [12, 24])
	var eye := cam.global_position
	for ang in [0.0, 8.0, -8.0, 16.0, -16.0]:
		var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * float(dr[1]), 1, [p.get_rid()]))
		var maxd := float(dr[1]) if hit.is_empty() else eye.distance_to(hit["position"]) - 0.8
		if maxd < float(dr[0]):
			continue
		var d := minf(maxd, float(dr[1]))
		var at := eye + dir * d
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1, [p.get_rid()]))
		if down.is_empty() or absf((down["position"] as Vector3).y - p.global_position.y) > 0.4:
			continue
		var ground := down["position"] as Vector3
		_ghost = Node3D.new()
		_ghost.name = "SheroAparicion"
		b.floor_node.add_child(_ghost)
		_ghost.add_to_group("shero_aparicion")
		_ghost.global_position = ground
		var rig := CharacterRig.attach(_ghost, "shero", 2.2)
		if rig != null:
			rig.play("idle")
		else:
			var mi := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.32
			cap.height = 1.85
			mi.mesh = cap
			mi.position = Vector3(0, 0.925, 0)
			_ghost.add_child(mi)
		# Un tubo frío encima, apenas: que se lea la silueta al final del pasillo y nada más.
		var lamp := OmniLight3D.new()
		lamp.name = "LuzAparicion"
		lamp.position = Vector3(0, 2.4, 0.4)
		lamp.light_color = Color(0.7, 0.82, 0.9)
		lamp.light_energy = float(c.get("aparicion_luz", 0.9))
		lamp.omni_range = 3.2
		lamp.omni_attenuation = 1.6
		_ghost.add_child(lamp)
		var to := p.global_position - ground
		_ghost.rotation.y = atan2(-to.x, -to.z)
		_ghost_seen_t = 0.0
		_ghost_age = 0.0
		apparitions += 1
		return true
	return false


func _tick_ghost(delta: float) -> void:
	var p := _player()
	if p == null or not is_instance_valid(_ghost) or not _ghost.is_inside_tree():
		_ghost = null
		return
	_ghost_age += delta
	var cam := p.camera
	var to := (_ghost.global_position + Vector3(0, 1.5, 0)) - cam.global_position
	var dist := to.length()
	var dot := (-cam.global_transform.basis.z).dot(to.normalized())
	if dot > 0.93:
		_ghost_seen_t += delta
	var c := _cfg()
	var max_age := float(c.get("aparicion_dura_max_s", 6.0))
	# "Cuando vuelves a mirar, ya no está": se va en cuanto apartas la vista después de haberlo visto.
	if (_ghost_seen_t > 0.35 and dot < 0.55) or (_ghost_age > max_age and dot < 0.8) or dist < 8.0 or Pursuit.is_hunting():
		_vanish(dist < 8.0)


func _vanish(with_sting: bool) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
		if with_sting:
			AudioManager.play_sting()
	_ghost = null


func ghost() -> Node3D:
	return _ghost if is_instance_valid(_ghost) else null

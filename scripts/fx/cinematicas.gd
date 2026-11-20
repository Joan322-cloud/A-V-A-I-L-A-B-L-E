class_name Cinematicas
extends CanvasLayer
## v0.3.1 Q4 (B11): cinemáticas de turno (data/cinematicas.json). Cámara propia, franjas negras, subtítulos y
## «Mantén [Espacio] para saltar» (0,8 s, también con clic). Se enganchan a EventBus.shift_started (intro del
## turno: T1 en el -1 real con la lluvia, el bus 47, la torre, Shero en la ventana del piso 2 y Don Fermín; T2 la
## clase del Trainer tras el vidrio y el «GAAAA»; T3 el Mentor publica la lista) y a shift_ended (08:45, el bus de
## vuelta), sin tocar main.gd. Se ven una vez por agente (SaveSlots.mark_tooltip("cine_<id>")) y se pueden
## repetir desde la selección de agente. Mientras dura, el reloj del turno espera (GameState.set_clock_override
## ("quiz"), 0x) y el jugador no se mueve (Player.set_cinematic). Con --bot/--escenario/--shot/headless no salen
## solas: las pruebas y capturas las piden con play(id, true).

signal started(id: String)
signal finished(id: String, skipped: bool)

const DATA := "cinematicas"
const HOLD_SKIP_S := 0.8
const LETTERBOX := 120.0

var playing: String = ""
var t: float = 0.0
var skipped: bool = false
var auto: bool = true  # false = no salen solas (pruebas)
var _shot: int = -1
var _shot_t: float = 0.0
var _shots: Array = []
var _cam: Camera3D = null
var _stage_vp: SubViewport = null
var _stage_rect: TextureRect = null
var _stage_root: Node3D = null
var _world_props: Array[Node] = []
var _top: ColorRect = null
var _bottom: ColorRect = null
var _sub: Label = null
var _title: Label = null
var _hint: Label = null
var _fade: ColorRect = null
var _flash: ColorRect = null
var _hold: float = 0.0
var _played: Dictionary = {}
var _rig_events: Dictionary = {}
var _total: float = 0.0
var _prev_override: String = ""
var _locked_player: bool = false
var _clock_at: float = 0.0  # el reloj espera aunque aún no hayas marcado (LLEGADA no mira el override)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_stage_rect = TextureRect.new()
	_stage_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_stage_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_rect.visible = false
	root.add_child(_stage_rect)
	_top = _bar(root, true)
	_bottom = _bar(root, false)
	_title = UITheme.label("", 30, Color(0.88, 0.9, 0.92), true)
	_title.position = Vector2(0, 40)
	_title.size = Vector2(1920, 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	_sub = UITheme.label("", 26, Color(0.92, 0.92, 0.9), false)
	_sub.position = Vector2(160, 1080 - LETTERBOX + 22)
	_sub.size = Vector2(1600, 80)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_sub.add_theme_constant_override("outline_size", 6)
	root.add_child(_sub)
	_hint = UITheme.label("", 14, Color(0.6, 0.62, 0.65), true)
	_hint.position = Vector2(1920 - 520, 1080 - 34)
	_hint.size = Vector2(500, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_hint)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.9, 0.95, 1.0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	visible = false
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.returned_to_menu.connect(func() -> void: stop(true))
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: stop(true))


func _bar(root: Control, top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0)
	r.position = Vector2(0, 0 if top else 1080 - LETTERBOX)
	r.size = Vector2(1920, LETTERBOX)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


static func data() -> Dictionary:
	return DataLoader.dict(DATA)


static func cfg(id: String) -> Dictionary:
	return (data().get("cinematicas", {}) as Dictionary).get(id, {})


static func auto_allowed() -> bool:
	return MainMenuLike.should_play()


func seen(id: String) -> bool:
	return SaveSlots.tooltip_seen("cine_" + id)


func _on_shift_started() -> void:
	if not auto or not auto_allowed() or SaveSlots.in_tutorial():
		return
	var id := str((data().get("turnos", {}) as Dictionary).get(str(GameState.turno), ""))
	if id == "" or seen(id):
		return
	# Espera a que el mundo exista (main crea el edificio después de shift_started) y que sea el inicio del turno.
	for i in 30:
		await get_tree().process_frame
		var b := get_tree().get_first_node_in_group("building") as Building
		if b != null and b.floor_node != null and get_tree().get_first_node_in_group("player") != null:
			break
	if GameState.logged_in or GameState.current_floor != -1:
		return  # continuar desde un checkpoint a mitad de turno: sin intro
	play(id)


func _on_shift_ended() -> void:
	if not auto or not auto_allowed() or SaveSlots.in_tutorial() or GameState.turno <= 0:
		return
	var id := str(data().get("salida", ""))
	if id == "" or seen(id + "_t%d" % GameState.turno):
		return
	SaveSlots.mark_tooltip("cine_%s_t%d" % [id, GameState.turno])
	play(id)


## Reproduce la cinemática `id`. `force` = aunque ya se haya visto (pruebas, capturas, repetir desde el menú).
func play(id: String, force: bool = false) -> bool:
	var c := cfg(id)
	if c.is_empty() or playing != "":
		return false
	if not force and seen(id):
		return false
	if not id.begins_with("salida"):
		SaveSlots.mark_tooltip("cine_" + id)
	playing = id
	skipped = false
	t = 0.0
	_hold = 0.0
	_shot = -1
	_played.clear()
	_rig_events.clear()
	_shots = c.get("tomas", [])
	_total = 0.0
	for s in _shots:
		_total += float((s as Dictionary).get("dur", 3.0))
	_title.text = Loc.pick(c.get("titulo", {}))
	_hint.text = tr("Q4_CINE_SKIP")
	visible = true
	_prev_override = GameState.clock_override
	if GameState.running and not GameState.shift_over:
		GameState.set_clock_override("quiz")
	var pl := _player()
	_locked_player = pl != null and GameState.running and not GameState.shift_over
	if _locked_player:
		pl.set_cinematic(true)
	_clock_at = GameState.clock_seconds
	_build_scene(str(c.get("escena", "")))
	started.emit(id)
	return true


## Termina la cinemática (skip = saltada por el jugador o cortada por menú/muerte).
func stop(skip: bool = false) -> void:
	if playing == "":
		return
	var id := playing
	playing = ""
	skipped = skip
	visible = false
	_stage_rect.visible = false
	if _stage_vp != null and is_instance_valid(_stage_vp):
		_stage_vp.queue_free()
	_stage_vp = null
	_stage_root = null
	for n in _world_props:
		if is_instance_valid(n):
			n.queue_free()
	_world_props.clear()
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if GameState.clock_override == "quiz" and _prev_override != "quiz":
		if _prev_override != "":
			GameState.set_clock_override(_prev_override)
		else:
			GameState.clear_clock_override("quiz")
	var pl := _player()
	if _locked_player and pl != null and is_instance_valid(pl):
		pl.reset_camera()
		pl.input_locked = false
		if pl.camera != null:
			pl.camera.make_current()
	_locked_player = false
	finished.emit(id, skip)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


func _process(delta: float) -> void:
	if playing == "":
		return
	if _locked_player and GameState.running and GameState.clock_seconds > _clock_at:
		GameState.clock_seconds = _clock_at
	t += delta
	var acc := 0.0
	var idx := -1
	for i in _shots.size():
		var d := float((_shots[i] as Dictionary).get("dur", 3.0))
		if t < acc + d:
			idx = i
			break
		acc += d
	if idx < 0:
		stop(false)
		return
	if idx != _shot:
		_shot = idx
		_enter_shot(_shots[idx] as Dictionary)
	_shot_t = t - acc
	var s: Dictionary = _shots[idx]
	var d2 := float(s.get("dur", 3.0))
	var k := clampf(_shot_t / d2, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	if _cam != null and s.has("desde"):
		var p := _v(s.get("desde")).lerp(_v(s.get("hasta", s.get("desde"))), e)
		var m := _v(s.get("mira_desde")).lerp(_v(s.get("mira_hasta", s.get("mira_desde"))), e)
		_place_cam(p, m)
	# fundidos entre tomas y título al principio
	var f := 0.0
	if _shot_t < 0.35:
		f = 1.0 - _shot_t / 0.35
	elif d2 - _shot_t < 0.3:
		f = (0.3 - (d2 - _shot_t)) / 0.3
	if idx == 0 and _shot_t < 0.35:
		f = 1.0 - _shot_t / 0.35
	_fade.color.a = clampf(f, 0.0, 1.0)
	_title.modulate.a = clampf(1.0 - absf(t - 1.8) / 1.8, 0.0, 1.0) if t < 3.6 else 0.0
	for snd in s.get("sonidos", []):
		_cue(idx, float(snd[0]), str(snd[1]))
	var vz: Array = s.get("voz", [])
	if vz.size() == 3 and _shot_t >= float(vz[0]) and not _played.has("%d_voz" % idx):
		_played["%d_voz" % idx] = true
		AudioManager.play_voice(str(vz[1]), str(vz[2]), "", "Sala")
	_stage_events(s, _shot_t)
	# saltar: mantener Espacio / clic
	var holding := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	_hold = _hold + delta if holding else maxf(_hold - delta * 2.0, 0.0)
	_hint.text = "%s %s" % [tr("Q4_CINE_SKIP"), "|".repeat(int(_hold / HOLD_SKIP_S * 6.0)) if _hold > 0.0 else ""]
	if _hold >= HOLD_SKIP_S:
		stop(true)


func _enter_shot(s: Dictionary) -> void:
	_sub.text = Loc.pick(s.get("texto", {}))
	if bool(s.get("jugador", false)):
		# Última toma: de vuelta a los ojos del jugador (la cámara del jugador, sin moverse).
		var pl := _player()
		if pl != null and pl.camera != null:
			pl.camera.make_current()
		if _cam != null:
			_cam.current = false
	elif _cam != null:
		_cam.make_current()
	if bool(s.get("silueta", false)) and _stage_root == null:
		_world_silhouette()


func _cue(idx: int, at: float, slot: String) -> void:
	var key := "%d_%s_%.2f" % [idx, slot, at]
	if _shot_t < at or _played.has(key):
		return
	_played[key] = true
	var st := AudioManager.stream_for(slot)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "Ambiente" if slot.begins_with("ambiente/") else "Sala"
	add_child(p)
	if slot.begins_with("voces/"):
		VoiceDirector.say_external(p, slot, VoiceDirector.P.DIRECTO, slot.get_slice("/", 1), {"free_on_drop": true})  # v0.3.2
	else:
		p.play()
	p.finished.connect(p.queue_free)
	# Tope de 6 s reales, del propio reproductor (v0.3.2-core: antes un temporizador del árbol con una lambda que lo
	# capturaba; casi siempre el sonido ya había terminado y liberado al reproductor → «Lambda capture… was freed»).
	var cap := p.create_tween()
	cap.set_ignore_time_scale(true)
	cap.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cap.tween_interval(6.0)
	cap.tween_callback(p.queue_free)


static func _v(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _place_cam(p: Vector3, look: Vector3) -> void:
	var parent := _cam.get_parent() as Node3D
	var base := parent.global_transform if parent != null else Transform3D.IDENTITY
	var gp := base * p
	var gl := base * look
	_cam.global_position = gp
	if gp.distance_to(gl) > 0.01:
		_cam.look_at(gl, Vector3.UP)


# --- escenas --------------------------------------------------------------------------------------

func _build_scene(escena: String) -> void:
	_stage_rect.visible = false
	match escena:
		"mundo_m1":
			var b := get_tree().get_first_node_in_group("building") as Building
			var parent: Node3D = b.floor_node if b != null and b.floor_node != null else get_tree().root.get_node_or_null("Main/World") as Node3D
			_cam = Camera3D.new()
			_cam.name = "CamaraCinematica"
			_cam.fov = 58.0
			_cam.far = 400.0
			if parent != null:
				parent.add_child(_cam)
				_cam.make_current()
		_:
			_build_stage(escena)


## Decorado propio en su mundo 3D (no toca el piso cargado).
func _build_stage(escena: String) -> void:
	_stage_vp = SubViewport.new()
	_stage_vp.size = Vector2i(1280, 720)
	_stage_vp.own_world_3d = true
	_stage_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_stage_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_stage_vp)
	_stage_root = Node3D.new()
	_stage_root.name = "Decorado"
	_stage_vp.add_child(_stage_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.012, 0.016)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.35, 0.38)
	e.ambient_light_energy = 0.25
	e.fog_enabled = true
	e.fog_light_color = Color(0.02, 0.025, 0.03)
	e.fog_density = 0.03
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_stage_root.add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_stage_root.add_child(_cam)
	_cam.current = true
	match escena:
		"set_training": _set_training()
		"set_mentor": _set_mentor()
		"set_salida": _set_salida(e)
	_stage_rect.texture = _stage_vp.get_texture()
	_stage_rect.visible = true


func _light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	_stage_root.add_child(l)
	return l


func _set_training() -> void:
	Greybox.floor_slab(_stage_root, "Piso", Vector2(0, 0), Vector2(10, 14), Greybox.ALFOMBRA)
	Greybox.box(_stage_root, "ParedFondo", Vector3(0, 1.5, -3.0), Vector3(10, 3, 0.2), Greybox.GRIS, false)
	var board := Greybox.box(_stage_root, "Pizarra", Vector3(0, 1.75, -2.85), Vector3(3.2, 1.3, 0.05), Greybox.BLANCO, false, 0.6)
	var q := Label3D.new()
	q.name = "Pregunta"
	q.text = tr("Q4_CINE_QUIZ")
	q.font_size = 40
	q.pixel_size = 0.004
	q.modulate = Color(0.1, 0.12, 0.2)
	q.position = Vector3(0, 1.8, -2.81)
	q.outline_size = 0
	_stage_root.add_child(q)
	_rig_events["pizarra"] = q
	board.name = "Pizarra"
	Greybox.box(_stage_root, "Vidrio", Vector3(0, 1.4, 2.2), Vector3(8, 2.8, 0.04), Greybox.VIDRIO, false)
	for i in 6:
		var x := -2.5 + float(i % 3) * 2.5
		var z := 0.2 + float(i / 3) * 1.3
		Greybox.box(_stage_root, "Mesa%d" % i, Vector3(x, 0.72, z - 0.45), Vector3(1.2, 0.05, 0.6), Greybox.GRIS_OSCURO, false)
		var holder := Node3D.new()
		holder.position = Vector3(x, 0, z)
		_stage_root.add_child(holder)
		var rig := CharacterRig.attach(holder, "agente_" + ["marko", "llauri", "ttoom", "juan", "jiroshi", "marko"][i], 1.7)
		if rig != null:
			rig.play("sit", true, 0.0)
	var th := Node3D.new()
	th.name = "Trainer"
	th.position = Vector3(-0.9, 0, -2.2)
	th.rotation_degrees.y = 160.0
	_stage_root.add_child(th)
	var trig := CharacterRig.attach(th, "trainer", 1.8)
	if trig != null:
		trig.play("point", true, 0.7, ["idle"])
	_rig_events["trainer"] = th
	_rig_events["trainer_rig"] = trig
	_light(Vector3(0, 2.7, -1.5), Color(0.85, 0.95, 0.9), 1.6, 7.0)
	_light(Vector3(0, 2.6, 4.5), Color(0.5, 0.6, 0.65), 0.4, 6.0)


func _set_mentor() -> void:
	Greybox.floor_slab(_stage_root, "Piso", Vector2(0, 0), Vector2(10, 10), Greybox.ALFOMBRA)
	Greybox.box(_stage_root, "ParedFondo", Vector3(0, 1.6, -3.0), Vector3(10, 3.2, 0.2), Greybox.GRIS_OSCURO, false)
	Greybox.box(_stage_root, "Escritorio", Vector3(0, 0.74, -0.4), Vector3(2.2, 0.05, 0.9), Greybox.GRIS_OSCURO, false)
	Greybox.box(_stage_root, "Monitor", Vector3(0, 1.05, -0.7), Vector3(0.6, 0.38, 0.04), Greybox.NEGRO, false, 0.9)
	var screen := Label3D.new()
	screen.name = "Lista"
	screen.font_size = 38
	screen.pixel_size = 0.0036
	screen.modulate = Color(0.85, 0.92, 0.9)
	screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	screen.position = Vector3(-0.85, 2.05, -2.88)
	screen.width = 600
	screen.text = _list_text(0)
	_stage_root.add_child(screen)
	_rig_events["lista"] = screen
	Greybox.box(_stage_root, "Pantalla", Vector3(0, 2.0, -2.9), Vector3(2.4, 1.3, 0.03), Color(0.05, 0.08, 0.09), false, 0.5)
	var mh := Node3D.new()
	mh.position = Vector3(0, 0, 0.35)
	mh.rotation_degrees.y = 180.0
	_stage_root.add_child(mh)
	var mrig := CharacterRig.attach(mh, "mentor", 1.72)
	if mrig != null:
		mrig.play("type", true, 1.3, ["sit", "idle"])
	var sh := Node3D.new()
	sh.name = "Shero"
	sh.position = Vector3(-1.4, 0, -1.9)
	sh.rotation_degrees.y = 30.0
	sh.visible = false
	_stage_root.add_child(sh)
	var srig := CharacterRig.attach(sh, "shero", 1.86)
	if srig != null:
		srig.play("idle", true, 0.5)
	_rig_events["shero"] = sh
	_rig_events["shero_rig"] = srig
	_light(Vector3(0, 1.4, 0.2), Color(0.5, 0.75, 0.8), 1.2, 4.0)
	_light(Vector3(0, 2.4, -2.2), Color(0.6, 0.8, 0.85), 0.8, 5.0)


func _list_text(stage: int) -> String:
	var others: Array = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			others.append(a)
	var lines := ["#team-familia · ALLOCATIONS 01:30", ""]
	var pct := [98, 95, 91, 88]
	for i in others.size():
		lines.append("%d. %s  %d %%" % [i + 1, others[i], pct[i % pct.size()]])
	var me := "%d. %s  71 %%  ◄" % [others.size() + 1, GameState.agent if GameState.agent != "" else "C-14"]
	if stage > 0:
		me = "[%s]" % me
	lines.append(me)
	return "\n".join(lines)


func _set_salida(e: Environment) -> void:
	e.background_color = Color(0.16, 0.16, 0.2)
	e.ambient_light_color = Color(0.55, 0.5, 0.55)
	e.ambient_light_energy = 0.5
	e.fog_light_color = Color(0.3, 0.3, 0.36)
	e.fog_density = 0.02
	Greybox.floor_slab(_stage_root, "Pista", Vector2(0, 6), Vector2(60, 10), Greybox.NEGRO)
	Greybox.floor_slab(_stage_root, "Vereda", Vector2(0, 0.5), Vector2(60, 3), Greybox.GRIS)
	Greybox.box(_stage_root, "Torre", Vector3(0, 18, -6), Vector3(16, 36, 4), Color(0.12, 0.13, 0.15), false)
	for r in 10:
		for c in 6:
			var lit := (r == 2 and c == 2)
			Greybox.box(_stage_root, "Ventana%d_%d" % [r, c], Vector3(-6.0 + c * 2.4, 3.5 + r * 3.2, -3.95), Vector3(1.4, 1.6, 0.04), Color(0.75, 0.85, 0.8) if lit else Color(0.08, 0.09, 0.1), false, 1.2 if lit else 0.0)
	var sil := Greybox.box(_stage_root, "Silueta", Vector3(-1.2, 9.6, -3.9), Vector3(0.45, 1.05, 0.02), Color(0.01, 0.01, 0.01), false)
	sil.name = "SiluetaShero"
	var bus := Bus.make(_stage_root, Bus.Mode.SALIDA)
	bus.position = Bus.STOP + Vector3(55, 0, 0)
	_light(Vector3(-4, 4, 6), Color(0.9, 0.75, 0.6), 0.6, 30.0)


## Silueta en una ventana encendida del piso 2 de la fachada real (intro T1).
func _world_silhouette() -> void:
	var b := get_tree().get_first_node_in_group("building") as Building
	if b == null or b.floor_node == null:
		return
	var z := 13.97
	var fach := b.floor_node.find_child("FachadaAlta", true, false) as Node3D
	if fach != null:
		z = fach.position.z + 0.17
	# v0.3.1 (fachada de Q5): franjas de vidrio delante del concreto y letras más altas (y 11,9): la ventana va
	# delante de la franja de vidrio y 2,4 m bajo las letras (en la fachada vieja: y 6,2 con letras a 8,5).
	var y := 6.2
	var franja := b.floor_node.find_child("FranjaVidrio0", true, false) as Node3D
	if franja != null:
		z = maxf(z, franja.position.z + 0.06)
	var letra := b.floor_node.find_child("Letra0", true, false) as Node3D
	if letra != null:
		y = letra.position.y - 2.4
	var holder := Node3D.new()
	holder.name = "VentanaShero"
	holder.position = Vector3(-3.5, y, z)  # debajo de las letras de la fachada
	b.floor_node.add_child(holder)
	_world_props.append(holder)
	Greybox.box(holder, "Luz", Vector3(0, 0, 0), Vector3(1.6, 1.3, 0.02), Color(0.62, 0.8, 0.76), false, 2.0)
	Greybox.box(holder, "Moldura", Vector3(0, -0.66, 0.015), Vector3(1.7, 0.06, 0.03), Color(0.05, 0.05, 0.06), false)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.012)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.3
	head.mesh = hm
	head.material_override = dark
	head.position = Vector3(0.08, 0.2, 0.03)
	head.scale = Vector3(1, 1, 0.15)
	holder.add_child(head)
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.27
	tm.height = 0.95
	torso.mesh = tm
	torso.material_override = dark
	torso.position = Vector3(0.08, -0.4, 0.03)
	torso.scale = Vector3(1, 1, 0.08)
	holder.add_child(torso)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0, 0.4)
	l.light_color = Color(0.6, 0.8, 0.75)
	l.light_energy = 0.8
	l.omni_range = 3.0
	holder.add_child(l)


func _stage_events(s: Dictionary, st: float) -> void:
	match str(s.get("evento", "")):
		"trainer_pizarra":
			var q := _rig_events.get("pizarra") as Label3D
			if q != null:
				q.text = tr("Q4_CINE_QUIZ") + ("\n" + tr("Q4_CINE_QUIZ_OPT") if st > 1.6 else "")
		"trainer_grito":
			var th := _rig_events.get("trainer") as Node3D
			var rig := _rig_events.get("trainer_rig") as CharacterRig
			if th != null and not _played.has("grito"):
				_played["grito"] = true
				th.position = Vector3(0.0, 0, -0.2)
				th.rotation_degrees.y = 0.0
				if rig != null:
					rig.play("scream", false, 1.0, ["jumpscare_main", "idle"])
				if not bool(Loc.get_setting("flash_reduction", false)):
					_flash.color.a = 0.7
		"lista":
			var l := _rig_events.get("lista") as Label3D
			if l != null:
				l.text = _list_text(1 if fmod(st, 0.8) < 0.4 else 0)
				l.modulate = Color(0.85, 0.92, 0.9)
		"shero_mira":
			var sh := _rig_events.get("shero") as Node3D
			if sh != null and not sh.visible:
				sh.visible = true
				var r := _rig_events.get("shero_rig") as CharacterRig
				if r != null:
					r.play("stare_camera", true, 0.6, ["idle"])
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(_flash.color.a - 0.04, 0.0)


## Condición común con el menú: no salen solas en herramientas ni headless.
class MainMenuLike:
	static func should_play() -> bool:
		if DisplayServer.get_name() == "headless":
			return false
		var args := OS.get_cmdline_user_args()
		for a in ["--bot", "--escenario", "--shot", "--check-all", "--check-collision", "--walk-test", "--qa-tour", "--random-walk", "--web-qa", "--bot-tutorial", "--repro-colapso", "--sin-cinematicas"]:
			if args.has(a):
				return false
		return true

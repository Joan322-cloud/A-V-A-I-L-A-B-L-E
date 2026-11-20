## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de v0.3.2-anim (animación de personajes con AnimationTree). Para --write-movie (marcas [video]):
##   pa_lado:<slug>[@antes]      antes/después: camina, corre, se sienta, teclea y se para (cámara que lo acompaña);
##                               "@antes" = clips de v0.3.1 (sin árbol). Se graban los dos a 640×720 y se pegan.
##   pa_video:todo               muestra: la sala con los compañeros (teclean, bostezan, atienden), Shero pasando
##                               enojado, el Trainer presentando y en postura de terror, Haime con el lapicero y
##                               encima de la mesa, Perrito RTA, Vitzo.
##   pa_video:<escena>           una sola: sala | shero | trainer | haime | guardia | perrito | vitzo
##   pa_rev:<slug>,<clip:seg~clip:seg…>[,<vista>][,<dist>]   revisión: un personaje en el estudio (con escritorio si el
##                               clip es de sentado) haciendo la lista de clips; vista = lado | frente | 34
##   pa_foto:<slug>,<clip>       una foto
##   pa_juego:<quien>            el personaje EN SU LUGAR del juego, visto desde donde lo ve el jugador:
##                               fermin (la revisión completa del lobby) | topico | marleny | mentor | rasec | compa

const STUDIO := Vector3(26.0, 0.0, 9.0)
const HEIGHTS: Dictionary = {"shero": 2.2, "grasa": 2.6, "perrito_rta": 0.6, "vitzo": 1.0, "papayala": 1.82, "trainer": 1.88, "haime": 1.78}
const SEATED: Array[String] = ["sit", "type", "phone", "read", "bored", "tired_nod", "rub_eyes", "yawn", "pen_tap", "haime_lean", "sit_talk",
	"sit_down", "stand_up", "sit_type"]

var _camera: Camera3D = null


func shots() -> Array[String]:
	return ["pa_video:", "pa_lado:", "pa_foto:", "pa_rev:", "pa_juego:", "pa_manos:"]


func _quiet(s: Node) -> void:
	var cm := s._main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
		(n as Node3D).visible = false
	GameState.stop_calm()
	var hud := s._main.get("hud") as Control
	if hud != null:
		hud.visible = false


func _studio(s: Node) -> Node3D:
	var fl: Node3D = s._building().floor_node
	var st := Node3D.new()
	st.name = "EstudioAnim"
	fl.add_child(st)
	st.global_position = STUDIO
	Greybox.box(st, "Fondo", Vector3(9.5, 2.0, 0), Vector3(0.1, 4.0, 60.0), Color(0.15, 0.16, 0.18), false)
	Greybox.box(st, "Piso", Vector3(4.5, -0.01, 0), Vector3(11.0, 0.02, 60.0), Color(0.24, 0.24, 0.26), false)
	# líneas en el piso cada metro: se ve si los pies patinan
	for i in range(-30, 31):
		Greybox.box(st, "Linea%d" % i, Vector3(4.5, 0.002, i), Vector3(11.0, 0.004, 0.02), Color(0.34, 0.34, 0.36), false)
	for z in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
		for p in [Vector3(1.0, 2.8, z), Vector3(6.0, 3.0, z + 2.0)]:
			var l := OmniLight3D.new()
			l.position = p
			l.light_energy = 2.4
			l.omni_range = 12.0
			st.add_child(l)
	return st


## Deja a la vista solo el estudio (on) o vuelve a mostrar el piso: las tomas de estudio no arrastran la sala entera
## (fondo limpio y se graba mucho más rápido).
func _isolate(s: Node, st: Node3D, on: bool) -> void:
	var fl: Node3D = s._building().floor_node
	for c in fl.get_children():
		if c == st or not (c is Node3D):
			continue
		if on and (c as Node3D).visible:
			c.set_meta("pa_oculto", true)
			(c as Node3D).visible = false
		elif not on and c.has_meta("pa_oculto"):
			c.remove_meta("pa_oculto")
			(c as Node3D).visible = true
	st.visible = on
	var p := s._player() as Node3D
	if p != null:
		p.visible = not on


## Cámara propia (no la del jugador): posición local al nodo `parent`, mirando a `look` (local).
func _cam_at(parent: Node3D, pos: Vector3, look: Vector3, fov: float = 46.0) -> Camera3D:
	if _camera == null or not is_instance_valid(_camera):
		_camera = Camera3D.new()
		_camera.name = "CamAnim"
		parent.get_tree().root.add_child(_camera)
	_camera.fov = fov
	_camera.global_position = parent.to_global(pos)
	_camera.look_at(parent.to_global(look), Vector3.UP)
	_camera.current = true
	return _camera


func _actor(st: Node3D, slug: String, pos: Vector3, yaw: float, before: bool, h: float = 0.0) -> CharacterRig:
	var holder := Node3D.new()
	holder.name = "A_" + slug + str(st.get_child_count())
	st.add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = yaw
	var r := CharacterRig.attach(holder, slug, h if h > 0.0 else float(HEIGHTS.get(slug, 1.7)))
	if r != null and before:
		r.use_tree(false)
		r.ensure_desk_clips()
	return r


## Puesto de trabajo real (Greybox.cubicle) con el personaje en su silla (misma colocación que floor_02._seat_agent).
func _desk_actor(st: Node3D, slug: String, pos: Vector3, yaw: float, before: bool, h: float = 1.7) -> CharacterRig:
	var cub := Greybox.cubicle(st, "R-%d" % st.get_child_count(), pos, yaw, 1)
	var r := CharacterRig.attach(cub, slug, h, 180.0, Vector3(0, 0, 0.45))
	if r != null and before:
		r.use_tree(false)
		r.ensure_desk_clips()
	return r


## Mueve `holder` en línea recta a `speed` m/s durante `secs`; si `cam` no es null lo acompaña.
func _walk(s: Node, holder: Node3D, dir: Vector3, speed: float, secs: float, cam: Camera3D = null) -> void:
	var t := 0.0
	while t < secs:
		var d := s.get_process_delta_time()
		var step: Vector3 = dir.normalized() * speed * d
		holder.global_position += step
		if cam != null:
			cam.global_position += step
		t += d
		await s.get_tree().process_frame


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


func _label(s: Node, text: String) -> void:
	var cl := s.get_tree().root.find_child("RotuloAnim", true, false) as Label
	if cl == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		s.get_tree().root.add_child(layer)
		cl = Label.new()
		cl.name = "RotuloAnim"
		cl.position = Vector2(28, 22)
		cl.add_theme_font_size_override("font_size", 40)
		cl.add_theme_color_override("font_color", Color(1, 1, 1))
		cl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cl.add_theme_constant_override("outline_size", 10)
		layer.add_child(cl)
	cl.text = text


func shoot(name: String, arg: String, s: Node) -> void:
	var before := arg.ends_with("@antes")
	var what := arg.get_slice("@", 0)
	if name == "pa_juego":
		await _juego(s, what)
		return
	if name == "pa_manos":
		await _manos(s, what)
		return
	await s._place(2, STUDIO, -90.0, 0.0)
	_quiet(s)
	var st := _studio(s)
	await _wait(s, 0.5)
	match name:
		"pa_lado":
			_isolate(s, st, true)
			await _lado(s, st, what if what != "" else "agente_marko", before)
		"pa_video":
			await _video(s, st, what)
		"pa_rev":
			_isolate(s, st, true)
			await _rev(s, st, what)
		"pa_foto":
			_isolate(s, st, true)
			_cam_at(st, Vector3(0.6, 1.3, 0), Vector3(4.0, 1.0, 0), 40.0)
			var r := _actor(st, what.get_slice(",", 0), Vector3(4.0, 0, 0), 90.0, before)
			if what.contains(","):
				r.play(what.get_slice(",", 1))
			await _wait(s, 1.5)


## Antes / después de un personaje: caminar 1,4 m/s, correr 3,6 m/s (cámara de costado que lo sigue: las líneas del
## piso pasan y se ve si los pies patinan) y el escritorio: se sienta, teclea, se para.
func _lado(s: Node, st: Node3D, slug: String, before: bool) -> void:
	var tag := "ANTES · v0.3.1" if before else "AHORA · v0.3.2"
	var h := float(HEIGHTS.get(slug, 1.7))
	var r := _actor(st, slug, Vector3(5.0, 0, -12.0), 180.0, before)  # mira a +Z
	var hd := r.get_parent() as Node3D
	var cam := _cam_at(st, Vector3(0.9, h * 0.62, -12.0), Vector3(5.0, h * 0.5, -12.0), 44.0)
	r.play("idle")
	await _wait(s, 0.4)
	print("[video] inicio %d" % Engine.get_frames_drawn())
	_label(s, tag + "\ncaminar")
	r.play("walk")
	await _walk(s, hd, Vector3(0, 0, 1), 1.4, 6.0, cam)
	_label(s, tag + "\ncorrer")
	r.play("run", true, 1.0, ["walk"])
	await _walk(s, hd, Vector3(0, 0, 1), 3.6, 3.2, cam)
	r.play("idle")
	await _wait(s, 0.8)
	hd.queue_free()
	# escritorio: de 3/4 por detrás del hombro (se ven las manos sobre la mesa)
	_label(s, tag + "\nsentarse · teclear · pararse")
	var d := _desk_actor(st, slug, Vector3(4.6, 0, 6.0), 90.0, before, h)  # el puesto mira a -X
	_cam_at(st, Vector3(3.5, 1.55, 3.2), Vector3(4.8, 1.02, 6.0), 50.0)
	d.play("idle")
	await _wait(s, 1.2)
	d.play("sit_down", false, 1.0, ["sit"])
	await _wait(s, 1.7)
	d.play("type", true, 1.0, ["sit"])
	await _wait(s, 7.0)
	d.play("stand_up", false, 1.0, ["idle"])
	await _wait(s, 1.6)
	d.play("idle")
	await _wait(s, 1.0)
	print("[video] fin %d" % Engine.get_frames_drawn())


## Revisión: "slug,clip:seg~clip:seg,vista,dist"
func _rev(s: Node, st: Node3D, what: String) -> void:
	var slug := what.get_slice(",", 0)
	var clips := what.get_slice(",", 1).split("~")
	var view := what.get_slice(",", 2) if what.get_slice_count(",") > 2 else "34"
	var dist := float(what.get_slice(",", 3)) if what.get_slice_count(",") > 3 else 3.2
	var h := float(HEIGHTS.get(slug, 1.7))
	var first := str(clips[0]).get_slice(":", 0)
	var seated := SEATED.has(first)
	var r: CharacterRig
	if seated:
		r = _desk_actor(st, slug, Vector3(4.6, 0, 0), 90.0, false, h)
	else:
		r = _actor(st, slug, Vector3(4.6, 0, 0), 90.0, false)
	var center := Vector3(4.6 if not seated else 4.75, h * (0.42 if seated else 0.55), 0)
	var dirs := {"lado": Vector3(0, 0, 1), "frente": Vector3(-1, 0, 0), "34": Vector3(-0.8, 0, 0.6), "34b": Vector3(-0.8, 0, -0.6), "atras": Vector3(0.75, 0, 0.66)}
	if seated:
		dirs["34"] = Vector3(-0.45, 0, 0.9)
		dirs["34b"] = Vector3(-0.45, 0, -0.9)
	# «vista!» o «vista!0.73» = primer plano de la cara (para ver la boca): centro a esa fracción de la altura, lente largo
	var face := view.contains("!")
	if face:
		var frac := float(view.get_slice("!", 1)) if view.get_slice("!", 1) != "" else (0.69 if seated else 0.905)
		view = view.get_slice("!", 0)
		center = Vector3(4.6 if not seated else 4.75, h * frac, 0)
	var dv: Vector3 = (dirs.get(view, dirs["34"]) as Vector3).normalized()
	_cam_at(st, center + dv * dist + Vector3(0, 0.03 if face else 0.25, 0), center, 26.0 if face else 40.0)
	r.play(first, true, 1.0, ["idle"])
	await _wait(s, 0.8)
	print("[video] inicio %d" % Engine.get_frames_drawn())
	for c in clips:
		var cn := str(c).get_slice(":", 0)
		var secs := float(str(c).get_slice(":", 1)) if str(c).contains(":") else 3.0
		_label(s, "%s · %s" % [slug, cn])
		if cn.begins_with("mover"):  # mover<vel>: camina/corre en línea recta con la cámara siguiéndolo
			var v := float(cn.trim_prefix("mover"))
			r.play("walk" if v < 3.0 else ("run" if v < 4.2 else "sprint"), true, 1.0, ["walk"])
			var hd := r.get_parent() as Node3D
			hd.rotation_degrees.y = 180.0
			await _walk(s, hd, Vector3(0, 0, 1), v, secs, _camera)
		elif cn.begins_with("dice"):  # dice / dicefuerte: una línea de subtítulo del personaje (reacción de hablar)
			var line := "[%s] ¡A TU SITIO, AHORA MISMO!" % slug if cn == "dicefuerte" else "[%s] Buenas noches, vamos a revisar la llamada de hoy con calma." % slug
			EventBus.subtitle.emit((NpcAnimator.SPEAKERS.get(slug, ["comp"]) as Array)[0], line, secs)
			await _wait(s, secs)
		else:
			if cn == "liviano" or cn == "media":  # cambia la calidad a mitad de la toma (en liviano no hay mandíbula por voz)
				GfxQuality.current = cn
				continue
			r.play(cn, not cn in ["slam_table", "sit_down", "stand_up", "tired_nod", "rub_eyes", "yawn"], 1.0, ["idle"])
			await _wait(s, secs)
	print("[video] fin %d" % Engine.get_frames_drawn())


# ------------------------------------------------------------------ muestra
func _seated_rigs(s: Node) -> Array:
	var out: Array = []
	for n in (s._building().floor_node as Node).find_children("*", "CharacterRig", true, false):
		var r := n as CharacterRig
		if r.animator != null and r.animator.state == "seated":
			out.append(r)
	return out


func _video(s: Node, st: Node3D, what: String) -> void:
	print("[video] inicio %d" % Engine.get_frames_drawn())
	var fl: Node3D = s._building().floor_node
	_isolate(s, st, false)
	if what in ["sala", "todo"]:
		# 1) la sala de verdad: una fila de compañeros; la cámara avanza despacio por el pasillo
		_label(s, "La sala · compañeros de madrugada")
		var rigs := _seated_rigs(s)
		var cam_from := Vector3(41.5, 1.45, -9.75)
		var cam_to := Vector3(36.0, 1.45, -9.75)
		rigs.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(cam_from + Vector3(-3, 0, 0)) < (b as Node3D).global_position.distance_to(cam_from + Vector3(-3, 0, 0)))
		var near: Array = rigs.slice(0, 8)
		var plan := ["type", "phone", "yawn", "type", "bored", "rub_eyes", "phone", "tired_nod"]
		for i in near.size():
			var a: NpcAnimator = (near[i] as CharacterRig).animator
			a._variant_t = 30.0
			a.set_meta("plan", plan[i % plan.size()])
		var cam := _cam_at(fl, cam_from, cam_from + Vector3(-4.0, -0.45, 0.9), 58.0)
		var t := 0.0
		while t < 9.6:
			var d := s.get_process_delta_time()
			t += d
			cam.global_position = fl.to_global(cam_from.lerp(cam_to, smoothstep(0.0, 9.6, t)))
			for i in near.size():
				var a: NpcAnimator = (near[i] as CharacterRig).animator
				if a.has_meta("plan") and t > 0.5 + i * 0.85:
					var c := str(a.get_meta("plan"))
					a.remove_meta("plan")
					if c != "type":
						a._set_switch("seated/sv", c)
						a._oneshot_left = a._lib.get_animation(c).length if c in NpcAnimator.TIRED else 9.0
						a._variant_t = 30.0
			await s.get_tree().process_frame
	if what in ["shero", "todo"]:
		# 2) Shero pasa enojado por el pasillo, se planta y señala
		_label(s, "Shero · camina enojado")
		var r := _actor(fl, "shero", Vector3(24.0, 0, -9.75), -90.0, false)  # mira a +X
		var hd := r.get_parent() as Node3D
		_cam_at(fl, Vector3(38.5, 1.5, -9.0), Vector3(30.0, 1.25, -9.75), 50.0)
		r.play("walk")
		await _walk(s, hd, Vector3(1, 0, 0), 3.9, 2.9)
		r.play("idle")
		await _wait(s, 0.9)
		EventBus.subtitle.emit("shero", "Shero: ¡A TU SITIO! ¡AHORA!", 2.4)
		await _wait(s, 2.6)
		r.play("idle")
		r.animator._pick_idle(true)
		await _wait(s, 1.3)
		hd.queue_free()
	_isolate(s, st, true)
	if what in ["trainer", "todo"]:
		# 3) el Trainer: presentador… y cuando deja de ser amable
		_label(s, "Trainer · presenta la clase")
		_cam_at(st, Vector3(1.2, 1.5, 0.5), Vector3(4.6, 1.15, 0), 42.0)
		var r := _actor(st, "trainer", Vector3(4.6, 0, 0), 90.0, false)
		r.play("idle")
		r.animator.tree.set("parameters/loco/bs/0/iv/transition_request", "present_a")
		r.animator._variant_t = 100.0
		await _wait(s, 3.4)
		r.animator.tree.set("parameters/loco/bs/0/iv/transition_request", "present_b")
		await _wait(s, 3.2)
		_label(s, "Trainer · cuando deja de ser amable")
		r.play("stare_camera", true, 1.0, ["idle"])
		await _wait(s, 2.6)
		(r.get_parent() as Node).queue_free()
	if what in ["haime", "todo"]:
		# 4) Haime: quieto y exacto (lapicero), y se te viene encima
		_label(s, "Haime · el lapicero")
		var d := _desk_actor(st, "haime", Vector3(4.6, 0, 6.0), 90.0, false, 1.78)
		# de 3/4 por el costado abierto del cubículo (de frente lo tapa la mampara)
		_cam_at(st, Vector3(4.75, 0.78, 6.0) + Vector3(-0.45, 0, 0.9).normalized() * 2.5 + Vector3(0, 0.3, 0), Vector3(4.75, 0.8, 6.0), 40.0)
		d.play("pen_tap")
		await _wait(s, 3.6)
		_label(s, "Haime · se inclina hacia ti")
		d.play("haime_lean")
		await _wait(s, 3.4)
		(d.get_parent() as Node).queue_free()
	if what in ["guardia", "todo"]:
		# 5) Don Fermín: de guardia, barre el lobby con la linterna, revisa la mochila
		_label(s, "Don Fermín · de guardia")
		_cam_at(st, Vector3(1.9, 1.4, -13.1), Vector3(4.6, 1.05, -14.0), 44.0)
		var g := _actor(st, "guardia_fermin", Vector3(4.6, 0, -14.0), 100.0, false, 1.76)
		g.play("idle")
		g.animator._variant_t = 100.0
		await _wait(s, 1.6)
		_label(s, "Don Fermín · barre con la linterna")
		g.animator.tree.set("parameters/loco/bs/0/iv/transition_request", "idle_look")
		await _wait(s, 5.6)
		_label(s, "Don Fermín · «la mochila»")
		g.play("hunch", true, 0.8, ["idle"])
		await _wait(s, 3.0)
		(g.get_parent() as Node).queue_free()
	if what in ["perrito", "todo"]:
		# 6) Perrito RTA: llega caminando, olfatea, gruñe
		_label(s, "Perrito RTA · olfatea")
		_cam_at(st, Vector3(2.2, 0.55, -5.2), Vector3(4.6, 0.3, -6.0), 40.0)
		var r := _actor(st, "perrito_rta", Vector3(4.6, 0, -9.2), 180.0, false)
		var hd := r.get_parent() as Node3D
		r.play("walk")
		await _walk(s, hd, Vector3(0, 0, 1), 1.2, 2.2)
		r.play("sniff", true, 1.0, ["idle"])
		await _wait(s, 3.2)
		_label(s, "Perrito RTA · gruñe")
		hd.rotation_degrees.y = 120.0
		r.play("growl", true, 1.0, ["idle"])
		await _wait(s, 2.6)
		hd.queue_free()
	if what in ["vitzo", "todo"]:
		# 7) Vitzo: glitch, camina, gatea hacia ti
		_label(s, "Vitzo")
		_cam_at(st, Vector3(2.5, 0.7, 12.55), Vector3(4.6, 0.5, 12.0), 42.0)
		var r := _actor(st, "vitzo", Vector3(6.4, 0, 11.6), 65.0, false)
		var hd := r.get_parent() as Node3D
		r.play("idle")
		await _wait(s, 2.0)
		hd.rotation_degrees.y = 90.0  # mira a -X (a la cámara)
		r.play("walk")
		await _walk(s, hd, Vector3(-1, 0, 0.1), 0.7, 2.0)
		_label(s, "Vitzo · gatea")
		r.play("crawl")
		await _walk(s, hd, Vector3(-1, 0, 0.1), 0.45, 3.2)
	print("[video] fin %d" % Engine.get_frames_drawn())


## Cámara a la altura de los ojos del jugador, mirando al pecho de `who`, a `dist` metros (o desde `from` si se da).
func _cam_npc(s: Node, who: Node3D, dist: float, fov: float = 44.0, from: Vector3 = Vector3.INF, h: float = 1.25) -> void:
	var fl: Node3D = s._building().floor_node
	var at := who.global_position + Vector3(0, h, 0)
	var pos := from
	if _cam_over != Vector3.INF:  # pa_juego:<quien>,dx,dy,dz → cámara en la posición del personaje + (dx, dy, dz) del mundo
		pos = who.global_position + _cam_over
	if pos == Vector3.INF:
		var fwd := who.global_transform.basis.z.normalized()  # los modelos miran a +Z local
		pos = who.global_position + fwd * dist + Vector3(0, 1.55, 0)
	_cam_at(fl, fl.to_local(pos), fl.to_local(at), fov)


## Espera `secs` mostrando en el rótulo qué clip tiene puesto el animador (para revisar las hojas de contactos).
func _watch(s: Node, an: NpcAnimator, secs: float, title: String) -> void:
	var t := 0.0
	while t < secs:
		t += s.get_process_delta_time()
		if an != null and is_instance_valid(an):
			_label(s, "%s   [%s · %s%s]" % [title, an.current, an.current_variant(), " · habla" if an._talking else ""])
		await s.get_tree().process_frame


## Los personajes secundarios donde el jugador los ve de verdad (revisión de animación en el juego).
var _cam_over: Vector3 = Vector3.INF
var _foto: bool = false


func _juego(s: Node, what: String) -> void:
	# pa_juego:<quien>[,dx,dy,dz][!]  → cámara propia relativa al personaje; «!» = solo una foto (sin la secuencia)
	_foto = what.ends_with("!")
	what = what.trim_suffix("!")
	_cam_over = Vector3.INF
	if what.count(",") == 3:
		_cam_over = Vector3(float(what.get_slice(",", 1)), float(what.get_slice(",", 2)), float(what.get_slice(",", 3)))
		what = what.get_slice(",", 0)
	var b: Building = s._building()
	var hud := s._main.get("hud") as Control
	if hud != null:
		hud.visible = false
	match what:
		"fermin":
			# la revisión de Don Fermín tal cual: saludo, fotocheck (señala), mochila (se inclina a alumbrar), detector, celular
			GameState.logged_in = false
			GameState.flags["revision_ok"] = false
			GameState.flags["clocked_in"] = false
			b.go_to_floor(2, "ascensor")
			await _wait(s, 0.4)
			b.go_to_floor(-1, "calle")
			await _wait(s, 1.0)
			var g := s.get_tree().get_first_node_in_group("p5_guardia")
			var actor := g.get("actor") as Node3D if g != null else null
			if actor == null:
				printerr("[pa_juego] no hay guardia")
				return
			var spot := (b.floor_node as Node).find_child("revision_jugador", true, false) as Node3D
			(s._player() as Player).teleport(spot.global_position, spot.global_rotation_degrees.y)
			_cam_npc(s, actor, 0.0, 64.0, spot.global_position + Vector3(0, 1.6, 0), 1.3)
			var an: NpcAnimator = (actor.get("animator") as NpcAnimator)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			if not bool(g.get("checking")):
				GameState.flags["guardia_revision_activa"] = true
				g.call("start_check")
			await _watch(s, an, 22.5, "Don Fermín · la revisión")
			await _watch(s, an, 24.0, "Don Fermín · de guardia")
			print("[video] fin %d" % Engine.get_frames_drawn())
		"topico":
			GameState.turno = maxi(GameState.turno, 2)  # el tópico atiende desde el turno 2
			b.go_to_floor(2, "ascensor")
			await _wait(s, 0.4)
			await s._place(1, Vector3(8.0, 0, -1.0), 0.0, 0.02)
			await _wait(s, 1.0)
			var n := s.get_tree().get_first_node_in_group("p5_enfermero")
			var actor := n.get("actor") as Node3D if n != null else null
			if actor == null:
				actor = (b.floor_node as Node).find_child("Enfermera", true, false) as Node3D
			if actor == null:
				printerr("[pa_juego] no hay nadie en el tópico")
				return
			_cam_npc(s, actor, 0.0, 46.0, actor.global_position + Vector3(-1.3, 1.5, 0.9), 1.2)  # dentro del tópico, del lado por el que mira al jugador
			if _foto:
				await _wait(s, 1.0)
				return
			print("[video] inicio %d" % Engine.get_frames_drawn())
			var an: NpcAnimator = actor.get("animator") as NpcAnimator
			await _watch(s, an, 7.0, "Tópico · espera")
			EventBus.subtitle.emit("enfermero", "Enfermero: Siéntese. Respire. ¿Desde cuándo no duerme?", 4.5)
			await _watch(s, an, 5.5, "Tópico · habla")
			if n != null and n.has_method("attend"):
				n.call("attend", true)
				await _watch(s, an, 3.5, "Tópico · te atiende")
				n.call("attend", false)
				await _watch(s, an, 1.5, "Tópico · espera")
			print("[video] fin %d" % Engine.get_frames_drawn())
		"marleny":
			GameState.turno = maxi(GameState.turno, 3)
			b.go_to_floor(2, "ascensor")
			await _wait(s, 0.4)
			await s._place(-1, Vector3(20.0, 0, 4.6), 0.0, 0.04)
			await _wait(s, 1.0)
			var m := (b.floor_node as Node).find_child("Marleny", true, false) as Node3D
			if m == null:
				printerr("[pa_juego] no hay Marleny")
				return
			_cam_npc(s, m, 0.0, 46.0, m.global_position + Vector3(-2.2, 1.5, -0.25), 1.2)  # delante del mostrador, donde compra el jugador
			if _foto:
				await _wait(s, 1.0)
				return
			print("[video] inicio %d" % Engine.get_frames_drawn())
			var an: NpcAnimator = (m as NpcFigure).rig.animator if m is NpcFigure and (m as NpcFigure).rig != null else null
			await _watch(s, an, 10.0, "Marleny · cafetería")
			EventBus.subtitle.emit("marleny", "Marleny: Ya, ya. ¿Qué va a llevar?", 4.5)
			await _watch(s, an, 6.0, "Marleny · habla")
			print("[video] fin %d" % Engine.get_frames_drawn())
		"mentor":
			GameState.turno = maxi(GameState.turno, 3)
			b.go_to_floor(-1, "ascensor")
			await _wait(s, 0.4)
			await s._place(2, Vector3(43.5, 0, -12.2), -90.0, 0.05)
			await _wait(s, 1.0)
			var m := (b.floor_node as Node).find_child("MentorFigura", true, false) as Node3D
			if m == null:
				printerr("[pa_juego] no hay Mentor")
				return
			_cam_npc(s, m, 0.0, 46.0, Vector3(43.9, 1.5, -11.6), 1.0)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			var an: NpcAnimator = (m as NpcFigure).rig.animator if m is NpcFigure and (m as NpcFigure).rig != null else null
			await _watch(s, an, 6.0, "Mentor · en su sitio")
			print("[video] fin %d" % Engine.get_frames_drawn())
		"rasec":
			await s._place(2, Vector3(30.0, 0, -9.75), 90.0, 0.0)
			_quiet(s)
			var fl: Node3D = b.floor_node
			var r := _actor(fl, "rasec", Vector3(22.0, 0, -9.75), -90.0, false, 1.84)
			var hd := r.get_parent() as Node3D
			_cam_at(fl, Vector3(33.5, 1.5, -9.0), Vector3(27.0, 1.2, -9.75), 46.0)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			_label(s, "Rasec · llega")
			r.play("walk")
			await _walk(s, hd, Vector3(1, 0, 0), 1.5, 4.2)
			r.play("idle")
			await _watch(s, r.animator, 6.0, "Rasec · de pie")
			EventBus.subtitle.emit("rasec", "Rasec: ¡Familia! ¿Quién se apunta al karaoke?", 4.0)
			await _watch(s, r.animator, 4.5, "Rasec · habla")
			print("[video] fin %d" % Engine.get_frames_drawn())
		"compa":
			# el compañero de C-15 deja de teclear para susurrarte: se queda sentado y habla
			await s._place(2, Vector3(30.0, 0, -9.75), 90.0, 0.0)
			var fl: FloorBase = b.floor_node as FloorBase
			var c := s.get_tree().get_first_node_in_group("companion")
			var seat := fl.seat_by_id("C-15") as Node3D if fl != null else null
			if seat == null:
				printerr("[pa_juego] no hay C-15")
				return
			var rig: CharacterRig = null
			for n in (fl as Node).find_children("*", "CharacterRig", true, false):
				var rr := n as CharacterRig
				if rig == null or rr.global_position.distance_to(seat.global_position) < rig.global_position.distance_to(seat.global_position):
					rig = rr
			_cam_npc(s, rig, 0.0, 46.0, rig.global_position + Vector3(1.9, 1.3, 1.5), 0.95)
			print("[video] inicio %d" % Engine.get_frames_drawn())
			await _watch(s, rig.animator, 3.0, "Compañero de C-15 · teclea")
			rig.play("idle", true, 0.6, ["sit"])
			AudioManager.play_voice("comp", "comp_no_te_pares", s.tr("COMP_NO_TE_PARES"), "Sala", VoiceDirector.P.CLIENTE)
			await _watch(s, rig.animator, 5.0, "Compañero de C-15 · te susurra")
			rig.play("type", true, 0.9, ["sit", "idle"])
			await _watch(s, rig.animator, 3.0, "Compañero de C-15 · sigue")
			print("[video] fin %d" % Engine.get_frames_drawn())
			if c != null:
				pass
		_:
			printerr("[pa_juego] no conozco: ", what)


# ------------------------------------------------------------------ manos en primera persona
## pa_manos:<acción>[,inclinación][,agente] — lo que ve el jugador: casillero (el de verdad, con su puerta y sus sonidos),
## refri_dejar, refri_sacar, microondas_meter, microondas_sacar (frente a los casilleros) y comer (sentado en C-14).
## «todas» las encadena. La inclinación de la cámara va en grados (por omisión la de referencia de cada gesto).
func _manos(s: Node, what: String) -> void:
	var k := what.get_slice(",", 0)
	var kinds: Array = ["casillero", "refri_dejar", "microondas_sacar", "comer"] if k == "todas" else [k]
	var b: Building = s._building()
	var p: Player = s._player()
	_quiet(s)
	print("[video] inicio %d" % Engine.get_frames_drawn())
	for kk in kinds:
		var pitch := float(what.get_slice(",", 1)) if what.get_slice_count(",") > 1 and what.get_slice(",", 1) != "" else (-25.0 if kk == "comer" else -12.0)
		if kk == "comer":
			if b.current_floor != 2:
				b.go_to_floor(2, "pc")
				await _wait(s, 0.5)
			var fl := b.floor_node as FloorBase
			if not p.seated:
				p.sit_at(fl.seat_by_id("C-14"), "C-14")
		else:
			await s._place(2, Vector3(0.7, 0, -4.5), 90.0, 0.0)
		p.head.rotation.x = deg_to_rad(pitch)
		_label(s, "Tus manos · %s" % str(kk).replace("_", " "))
		await _wait(s, 0.7)
		print("[video] corte %d" % Engine.get_frames_drawn())
		var d := 0.0
		var locker := b.floor_node.find_child("MiCasillero", true, false) as Interactable
		if kk == "casillero" and locker != null and not bool(locker.get("used")):
			locker.interact(p)
			d = float(ManosFx.DUR["casillero"])
		else:
			d = ManosFx.for_player(p).play(kk)
		var el := 0.0
		while el < d + 0.45:
			await s.get_tree().process_frame
			el += s.get_process_delta_time()
			p.head.rotation.x = deg_to_rad(pitch)
		print("[video] hasta %d" % Engine.get_frames_drawn())
	print("[video] fin %d" % Engine.get_frames_drawn())


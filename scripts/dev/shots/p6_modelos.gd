## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P6a (modelos v2 dentro del juego): `-- --shot p6` las captura todas.
##   p6_personaje:<slug>   cada modelo en un "estudio" dentro del piso 2 (frente, cuerpo entero, idle)
##   p6_fila:<clip>[@b]     los 19 modelos en fila con un clip congelado (idle, walk, run, sit, type, jumpscare_main):
##                          pies en el suelo, sin T-pose, texturas (la mitad "a" o "b" de la fila)
##   p6_cuerpo:<agente>     el cuerpo del jugador en 1.ª persona con el rig v2 del agente elegido
##   p6_screamer_guardia / p6_screamer_grasa   screamers por defecto (aún no matan en la v0.3), en el golpe
##   p6_screamer:<asesino|causa>@<s>  el screamer a los <s> segundos exactos (secuencia para revisar fotogramas)
##   p6_vitzo_glitch:<n>    dos instantes distintos de la pantalla de Vitzo (cambia entre fotogramas)
##   p6_video:<causa>       para --write-movie (como video: de P2, con el audio del screamer)

const MODELS: Array[String] = ["shero", "trainer", "haime", "rasec", "perrito_rta", "vitzo", "grasa", "guardia_fermin", "enfermero", "enfermera",
	"agente_jiroshi", "agente_marko", "agente_llauri", "agente_ttoom", "agente_juan", "mentor", "om", "marleny", "papayala"]
const HEIGHTS: Dictionary = {"shero": 2.2, "grasa": 2.6, "perrito_rta": 0.7, "vitzo": 1.0, "papayala": 1.82}
const STUDIO := Vector3(26.0, 0.0, 9.0)  # piso 2, pasillo de la sala (despejado y con luz del piso)


func shots() -> Array[String]:
	var out: Array[String] = []
	for m in MODELS:
		out.append("p6_personaje:" + m)
	for c in ["idle", "walk", "run", "sit", "type", "jumpscare_main"]:
		out.append("p6_fila:" + c)
		out.append("p6_fila:%s@b" % c)
	for a in ["Jiroshi", "Marko", "Llauri", "Ttoom", "Juan"]:
		out.append("p6_cuerpo:" + a)
	for k in ["guardia", "grasa"]:
		for t in ["0.3", "0.6", "0.8", "1.0", "1.2"]:
			out.append("p6_screamer:%s@%s" % [k, t])
	out += ["p6_screamer:", "p6_screamer_guardia", "p6_screamer_grasa", "p6_vitzo_glitch:1", "p6_vitzo_glitch:2", "p6_video:"]
	return out


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


func _quiet(s: Node) -> void:
	var cm := s._main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()


## Estudio: fondo neutro, luz de frente y de contra; el jugador mira a +X desde STUDIO.
func _studio(s: Node) -> Node3D:
	var fl: Node3D = s._building().floor_node
	var old := fl.find_child("EstudioP6", false, false)
	if old != null:
		old.free()
	var st := Node3D.new()
	st.name = "EstudioP6"
	fl.add_child(st)
	st.global_position = STUDIO
	Greybox.box(st, "Fondo", Vector3(9.0, 2.0, 0), Vector3(0.1, 4.0, 22.0), Color(0.16, 0.17, 0.19), false)
	Greybox.box(st, "Piso", Vector3(4.5, -0.01, 0), Vector3(9.5, 0.02, 22.0), Color(0.22, 0.22, 0.24), false)
	var key := OmniLight3D.new()
	key.position = Vector3(1.2, 2.6, 1.5)
	key.light_energy = 3.2
	key.omni_range = 14.0
	st.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 1.4, -3.0)
	fill.light_energy = 2.0
	fill.light_color = Color(0.8, 0.88, 1.0)
	fill.omni_range = 12.0
	st.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(7.5, 3.0, 0)
	rim.light_energy = 2.2
	rim.omni_range = 9.0
	st.add_child(rim)
	return st


func _rig(st: Node3D, slug: String, pos: Vector3, clip: String) -> CharacterRig:
	var holder := Node3D.new()
	holder.name = "M_" + slug
	st.add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = 90.0  # mira a -X (hacia la cámara)
	var r := CharacterRig.attach(holder, slug, float(HEIGHTS.get(slug, 1.75)))
	if r != null:
		r.play(clip, true, 1.0, ["idle"])
		if r.anim != null and r.anim.has_animation(clip):
			r.anim.seek(r.anim.get_animation(clip).length * 0.4, true)
			r.anim.pause()
		if slug == "rasec" and clip == "idle":
			r.set_look("")
	return r


func shoot(name: String, arg: String, s: Node) -> void:
	match name:
		"p6_personaje":
			await s._place(2, STUDIO, -90.0, 0.0)
			_quiet(s)
			var st := _studio(s)
			var h := float(HEIGHTS.get(arg, 1.75))
			var dist := 1.2 + h * 1.25
			_rig(st, arg, Vector3(dist, 0, 0), "idle")
			var p: Player = s._player()
			# encuadre de cuerpo entero: el centro del modelo al centro de la imagen, FOV cerrado
			p.head.rotation.x = atan2(h * 0.52 - (p.camera.global_position.y - STUDIO.y), dist)
			p.fov_base = 40.0  # el jugador interpola camera.fov hacia fov_base cada fotograma
			p.camera.fov = 40.0
		"p6_fila":
			var clip := arg.get_slice("@", 0)
			var half := arg.get_slice("@", 1) if arg.contains("@") else "a"
			await s._place(2, STUDIO, -90.0, 0.0)
			_quiet(s)
			var st := _studio(s)
			var list := MODELS.slice(0, 10) if half == "a" else MODELS.slice(10)
			for i in list.size():
				var z := (i - (list.size() - 1) * 0.5) * 1.05
				var r := _rig(st, list[i], Vector3(6.2, 0, z), clip)
				if r != null and clip in ["sit", "type"]:
					Greybox.box(st, "Silla_%d" % i, Vector3(6.35, 0.23, z), Vector3(0.45, 0.46, 0.45), Color(0.1, 0.1, 0.12), false)
			var p: Player = s._player()
			p.head.rotation.x = -0.08
			p.fov_base = 62.0
			p.camera.fov = 62.0
		"p6_cuerpo":
			s._main.call("_start_shift", arg, GameState.Mode.NORMAL)
			await _wait(s, 0.6)
			await s._place(2, STUDIO, -90.0, -1.05)
			_quiet(s)
			_studio(s)
		"p6_screamer_guardia", "p6_screamer_grasa":
			await s._place(2, STUDIO, -90.0, 0.0)
			_quiet(s)
			var killer := "guardia" if name == "p6_screamer_guardia" else "grasa"
			var dur := Screamers.duration(killer, "p6_demo")
			Screamers.play(killer, "p6_demo", "")
			# carrera: 0,25 s de giro + 42 % de la duración corriendo; el golpe llega justo después
			await s.get_tree().create_timer(0.25 + dur * 0.42 + 0.18).timeout
			await RenderingServer.frame_post_draw
			s.set_meta("p6_frame", s.get_viewport().get_texture().get_image())
		"p6_screamer":
			# La captura general espera 0,8 s de juego después de shoot(): aquí se toma el fotograma exacto a los
			# <s> segundos y after() lo escribe encima.
			await s._place(2, STUDIO, -90.0, 0.0)
			_quiet(s)
			var who := arg.get_slice("@", 0)
			if DataLoader.dict("screamers").get("causas", {}).has(who):  # una causa: la muerte completa (posición de P2)
				if who in ["aux_incorrecto", "abandono", "training_inasistencia", "work_avoiding", "otra_isla"]:
					await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
				else:
					await s._sit_c14()
				Checkpoints.request_death(who, "", "")
			else:
				Screamers.play(who, "p6_demo", "")
			await s.get_tree().create_timer(maxf(arg.get_slice("@", 1).to_float(), 0.02)).timeout
			await RenderingServer.frame_post_draw
			s.set_meta("p6_frame", s.get_viewport().get_texture().get_image())
		"p6_vitzo_glitch":
			await s._place(2, STUDIO, -90.0, 0.05)
			_quiet(s)
			var st := _studio(s)
			var r := _rig(st, "vitzo", Vector3(1.6, 0.35, 0), "idle")
			if r != null:
				VitzoGlitch.set_intensity(r.get_child(0), 1.0)
			await _wait(s, 0.37 * float(arg.to_int()))
		"p6_video":
			var vc := arg if arg != "" else "training_reprobado"
			var standing := vc in ["aux_incorrecto", "abandono", "training_inasistencia", "work_avoiding", "otra_isla", "guardia"]
			if standing:
				await s._place(2, Vector3(20.5, 0, 0.8), -55.0)
			else:
				await s._sit_c14()
			_quiet(s)
			await s.get_tree().create_timer(1.0).timeout
			print("[video] inicio %d" % Engine.get_frames_drawn())
			if vc == "guardia":
				await Screamers.play("guardia", "p6_demo", "")
			else:
				Checkpoints.request_death(vc, "", "")
				for _i in 120:
					await s.get_tree().create_timer(0.1).timeout
					if Checkpoints.death_visible:
						break
			await s.get_tree().create_timer(1.0).timeout
			print("[video] fin %d" % Engine.get_frames_drawn())


func after(name: String, s: Node) -> void:
	if s.has_meta("p6_frame"):
		(s.get_meta("p6_frame") as Image).save_png("user://shots/%s.png" % name)
		s.remove_meta("p6_frame")
	Engine.time_scale = 1.0
	var fl: Node = s._building().floor_node if s._building() != null else null
	if fl != null:
		var st := fl.find_child("EstudioP6", false, false)
		if st != null:
			st.queue_free()
	var p: Player = s._player()
	if p != null and p.camera != null:
		p.fov_base = float(Loc.get_setting("fov", DataLoader.bal("jugador/fov", 75.0)))
		p.camera.fov = p.fov_base
	if name.begins_with("p6_screamer") or name.begins_with("p6_video"):
		await s.get_tree().create_timer(1.2).timeout
		if Checkpoints.death_visible:
			Checkpoints.respawn()
		GameState.stop_calm()
		await s.get_tree().create_timer(1.5).timeout

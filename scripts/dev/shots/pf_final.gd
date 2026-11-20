## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.2-final · vistas para mirar las costuras entre paquetes (la calidad sale de settings.json «quality»).
##   fin_cal[:estados[:paso]]  la sala de calibración desde tu silla en cada estado de luz de las cuatro sesiones de
##                  Haime (los mismos que `h2_luzlab`, con las mismas llamadas al actor), más la sala en reposo antes
##                  («00_reposo») y después de soltarla («99_despues»). `estados` = etiquetas separadas por comas
##                  (vacío = todas las de Normal; «liviano» = las de la escalera del Modo liviano). `paso` = segundos de
##                  espera por estado (3,0). JPG en user://shots/fin_cal/ y una línea «[fin_cal]» por estado con la luz
##                  blanca, el REC, la exposición y las luces del paquete gráfico.
##   fin_colapso[:pie][:en]    el colapso por Fatiga (tercera persona de kills-rc2) con la calidad puesta, en plena
##                  llamada (sentado en C-14 con un contacto de verdad aceptado; «pie» = de pie junto a la isla, sin
##                  llamada), un cuadro cada 0,3 s: la luz suave de la toma contra las luces del paquete gráfico, la
##                  silla que sale rodando (animación de objetos) y el subtítulo del cliente. JPG en
##                  user://shots/fin_colapso/ y una línea «[fin_colapso]» por cuadro (cámara, luz, silla, subtítulo).
##   fin_recuerdo[:módulos]    el recuerdo del Training (aula del piso 1) en cuatro vistas fijas, sin HUD: la clase desde
##                  tu mesa, el Trainer y la pizarra, la ventana, el pasillo. JPG en user://shots/fin_recuerdo/.

const H2 := "res://scripts/dev/shots/ph2_haime.gd"


func shots() -> Array[String]:
	return ["fin_cal", "fin_cal:", "fin_recuerdo", "fin_recuerdo:", "fin_objetos", "fin_objetos:", "fin_leer", "fin_leer:", "fin_colapso", "fin_colapso:"]


func _wait(s: Node, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while frames < 10 or float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await s.get_tree().process_frame
		frames += 1


func _snap(s: Node, dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = s.get_viewport().get_texture().get_image()
	if img.get_width() > 960:
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("user://shots/%s/%s.jpg" % [dir, name], 0.9)


func _report(s: Node, node: Node, label: String) -> void:
	var d: GfxDirector = GfxDirector.inst if is_instance_valid(GfxDirector.inst) else null
	var extras := ""
	var spot := -1.0
	var zk := -1.0
	if d != null and d.lights.active:
		for ex in d.lights._extras:
			var l := ex[0] as Light3D
			extras += " %s=%.2f%s" % [l.name, l.light_energy, "" if l.visible else "(oculta)"]
		for fx in d.lights.fixtures:
			if is_instance_valid(fx.panel) and str(fx.panel.name) == "LuzCalibracion" and is_instance_valid(fx.spot):
				spot = fx.spot.light_energy if fx.spot.visible else 0.0
				zk = d.lights._zone_follow(fx.zone)
	print("[fin_cal] %s: calidad=%s blanca=%.3f rec=%.2f muertas=%d exposicion=%.2f luz_local=%.2f haz=%.2f zona_k=%.2f presencia=%.3f%s" % [label, GfxQuality.level(),
		float(node.call("room_light")), float(node.call("rec_light")), int(node.get("lights_dead")),
		d.atmosphere.exposure_now() if d != null else -1.0, d.lights.local_light if d != null else -1.0, spot, zk,
		d.lights.presence.light_energy if d != null and is_instance_valid(d.lights.presence) else -1.0, extras])


func _cal(s: Node, arg: String) -> void:
	var parts := arg.split(":")
	var want: Array = []
	var light := false
	if parts.size() > 0 and parts[0] != "":
		if parts[0] == "liviano":
			light = true
		else:
			want = Array(parts[0].split(","))
	var step := float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else 3.0
	var states: Array = (load(H2) as GDScript).get_script_constant_map().get("LUCES", [])
	await s._sit_c14()
	GameState.stop_calm()
	var hub := PersonajesP5.get_hub(s.get_tree())
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	hub.qa.process_mode = Node.PROCESS_MODE_DISABLED
	for sh in s.get_tree().get_nodes_in_group("shero"):
		(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
	for v in s.get_tree().get_nodes_in_group("vitzo"):
		(v as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var fl := s._building().floor_node as FloorBase
	var seat := fl.find_child("Seat_calibracion", true, false) as Node3D
	var p: Player = s._player()
	if p.seated:
		p.stand_up()
	await _wait(s, 0.3)
	p.sit_at(seat, "calibracion")
	p.head.rotation.x = -0.06
	var hud := s.get_tree().root.find_child("HUD", true, false) as CanvasItem
	var tips := s._main.get_node_or_null("UI/AgentTips") as CanvasItem
	if hud != null:
		hud.visible = false
	if tips != null:
		tips.visible = false
	var node := s.get_tree().get_first_node_in_group("p5_haime_actor")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/fin_cal"))
	await _wait(s, step + 1.5)
	if want.is_empty() or want.has("reposo"):
		await _snap(s, "fin_cal", "00_reposo")
		_report(s, node, "reposo")
	var i := 1
	for cfg in states:
		var label := str(cfg[0])
		var is_light_state := label.begins_with("n4L")
		if (want.is_empty() and is_light_state != light) or (not want.is_empty() and not want.has(label)):
			i += 1
			continue
		var nivel := int(cfg[1])
		node.call("session_mode", true, nivel)
		node.call("room_session", true, nivel)
		node.call("lock_door")
		node.call("look_at_player", true)
		node.call("set_severity", [0, 1, 2, 2, 3][nivel] if not bool(cfg[5]) else 3)
		node.call("set_dim", float(cfg[2]))
		node.call("set_outside", float(cfg[3]))
		node.call("set_fill", float(cfg[7]), nivel == 4)
		if bool(cfg[5]):
			node.call("only_rec")
		elif cfg[4] is Array:
			for w in cfg[4]:
				node.call("fail_light", str(w))
		else:
			for _k in int(cfg[4]):
				node.call("fail_light")
		match str(cfg[6]):
			"over":
				if nivel == 2:
					node.call("slam")
				else:
					node.call("rise")
				node.call("upright", false)
				node.call("lean", 0.7)
			"up":
				node.call("rise")
			"brace":
				node.call("brace", true)
		await _wait(s, step)
		await _snap(s, "fin_cal", "%02d_%s" % [i, label])
		_report(s, node, label)
		node.call("room_session", false, 0)
		node.call("session_mode", false, 0)
		await _wait(s, 0.4)
		i += 1
	if want.is_empty() or want.has("despues"):
		await _wait(s, step + 1.0)
		await _snap(s, "fin_cal", "99_despues")
		_report(s, node, "despues")
	if hud != null:
		hud.visible = true


## El aula del recuerdo: como la ve el jugador (con HUD, panel y subtítulos) y sin interfaz desde tu mesa (frente,
## izquierda, derecha) y desde tres puntos fijos (coordenadas del piso 1).
const RECUERDO_VIEWS: Array = [
	["aula", Vector3(11.2, 0.05, -8.05), 168.0, -0.12],     # la misma vista que gfx_recuerdo
	["ventana", Vector3(13.0, 0.05, -2.0), 80.0, 0.0],
	["pasillo", Vector3(7.1, 0.05, 6.0), 0.0, -0.03],
]


func _ui_layers(s: Node, on: bool) -> void:
	var hud := s.get_tree().root.find_child("HUD", true, false) as CanvasItem
	if hud != null:
		hud.visible = on
	for layer in s.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var nm := str(layer.name)
		if nm.begins_with("Tut") or nm == "TarjetaRecuerdo" or nm.begins_with("Training"):
			(layer as CanvasLayer).visible = on


func _recuerdo_line(s: Node, tag: String) -> void:
	var d: GfxDirector = GfxDirector.inst if is_instance_valid(GfxDirector.inst) else null
	var we := s.get_tree().root.find_children("*", "WorldEnvironment", true, false)
	var e: Environment = (we[-1] as WorldEnvironment).environment if not we.is_empty() else null
	print("[fin_recuerdo] %s: calidad=%s aspecto=%s luces_noche=%s exposicion=%.2f blanco=%.2f ambiente=%.2f fondo=%s" % [tag, GfxQuality.level(),
		d.atmosphere.look_id if d != null else "-", d.lights.active if d != null else false, e.tonemap_exposure if e != null else -1.0,
		e.tonemap_white if e != null else -1.0, e.ambient_light_energy if e != null else -1.0, str(e.background_color) if e != null else "-"])


func _recuerdo(s: Node, _arg: String) -> void:
	# Mismo camino que una partida nueva: Main._start_first_training (Tutorial + Flashback + aula).
	s._main.call("_back_to_menu")
	await _wait(s, 0.5)
	SaveSlots.select("Jiroshi")
	var tut: Node = s._main.call("_start_first_training", "Jiroshi", GameState.Mode.NORMAL)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/fin_recuerdo"))
	var b: Building = GfxQuality.live_building(s.get_tree())
	var waited := 0.0
	while (b == null or b.current_floor != 1) and waited < 40.0:
		await _wait(s, 0.5)
		waited += 0.5
		b = GfxQuality.live_building(s.get_tree())
	await _wait(s, 2.5)
	print("[fin_recuerdo] piso=%d recuerdo=%s tutorial=%s calidad=%s" % [b.current_floor if b != null else -99, Flashback.active, tut != null, GfxQuality.level()])
	await _snap(s, "fin_recuerdo", "0_tarjeta")
	# Tal como lo ve el jugador: sentado en T-01 con el panel del Training y el Trainer hablando (subtítulo).
	if tut != null and tut.has_method("ensure_seated"):
		await tut.call("ensure_seated", false)
	var w := 0.0
	while s.get_tree().root.find_child("TarjetaRecuerdo", true, false) != null and w < 25.0:
		await _wait(s, 0.5)
		w += 0.5
	var hud_sub: Label = null
	var hud := s.get_tree().root.find_child("HUD", true, false)
	if hud != null:
		hud_sub = hud.get("_sub") as Label
	w = 0.0
	while (hud_sub == null or hud_sub.text == "") and w < 20.0:
		await _wait(s, 0.3)
		w += 0.3
	await _wait(s, 0.6)
	await _snap(s, "fin_recuerdo", "1_jugador_hud")
	print("[fin_recuerdo] subtítulo a la vista: «%s»" % (hud_sub.text.left(90) if hud_sub != null else "?"))
	if tut != null:
		tut.process_mode = Node.PROCESS_MODE_DISABLED
	_ui_layers(s, false)
	var p: Player = s._player()
	await _wait(s, 1.0)
	await _snap(s, "fin_recuerdo", "2_mesa_frente")
	_recuerdo_line(s, "mesa")
	p.rotation.y += deg_to_rad(40.0)
	await _wait(s, 0.8)
	await _snap(s, "fin_recuerdo", "3_mesa_izquierda")
	p.rotation.y -= deg_to_rad(80.0)
	await _wait(s, 0.8)
	await _snap(s, "fin_recuerdo", "4_mesa_derecha")
	p.rotation.y += deg_to_rad(40.0)
	var fl := b.floor_node as Node3D
	var i := 5
	for v in RECUERDO_VIEWS:
		if p.seated:
			p.stand_up()
		p.teleport(fl.to_global(v[1]), float(v[2]))
		p.head.rotation.x = float(v[3])
		await _wait(s, 2.5)
		await _snap(s, "fin_recuerdo", "%d_%s" % [i, str(v[0])])
		_recuerdo_line(s, str(v[0]))
		i += 1
	# Lo que NO debe haber en el recuerdo: horario nocturno, utilería de hoy, luces del paquete.
	var d: GfxDirector = GfxDirector.inst if is_instance_valid(GfxDirector.inst) else null
	var night := 0
	if d != null:
		for fx in d.lights.fixtures:
			if not fx.lit:
				night += 1
	var present := 0
	if d != null and is_instance_valid(d.detail.root):
		for c in d.detail.root.get_children():
			if c is Node3D and str(c.name) in GfxDetail.PRESENT_DAY and (c as Node3D).visible:
				present += 1
	print("[fin_recuerdo] tubos apagados por horario nocturno=%d · utilería de hoy visible=%d · luces de práctica=%d · presencia=%s" % [night, present,
		d.lights.pool.size() if d != null else 0, str(d.lights.presence.light_energy) if d != null and is_instance_valid(d.lights.presence) else "-"])
	_ui_layers(s, true)


func shoot(name: String, arg: String, s: Node) -> void:
	match name:
		"fin_cal": await _cal(s, arg)
		"fin_recuerdo": await _recuerdo(s, arg)
		"fin_objetos": await _objetos(s, arg)
		"fin_leer": await _leer(s, arg)
		"fin_colapso": await _colapso(s, arg)


# --- animación × gráficos: las escenas de objetos del paquete de animación, con la calidad que esté puesta ------------
## `fin_objetos[:esc1+esc2…]` → user://shots/fin_objetos/<n>_<escena>_<k>.jpg (k = 0.. a lo largo de la escena).
## Reutiliza la preparación y el guion de cada escena de po_objetos.gd (puerta, silla, monitor, ascensor, microondas,
## expendedora, taza): lo que cambia es que aquí se mira con la capa de detalle y las luces del paquete gráfico.
const PO := "res://scripts/dev/shots/po_objetos.gd"


func _objetos(s: Node, arg: String) -> void:
	var po: RefCounted = (load(PO) as GDScript).new()
	var list: Array = Array(arg.split("+", false)) if arg != "" else ["puerta", "silla", "monitor", "ascensor", "microondas", "expendedora", "taza"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/fin_objetos"))
	await _wait(s, 0.5)
	po.call("_quiet", s)
	var i := 0
	for sc in list:
		await po.call("_prep_" + str(sc), s)
		var done := [false]
		var run := func() -> void:
			await po.call("_do_" + str(sc), s)
			done[0] = true
		run.call()
		var k := 0
		var t0 := Time.get_ticks_msec()
		while not done[0] and k < 6:
			await _snap(s, "fin_objetos", "%d_%s_%d" % [i, str(sc), k])
			k += 1
			await _wait(s, 0.55)
		while not done[0] and Time.get_ticks_msec() - t0 < 60000:
			await s.get_tree().process_frame
		var det := GfxDirector.inst.detail.stats if is_instance_valid(GfxDirector.inst) else {}
		print("[fin_objetos] %s: calidad=%s tomas=%d detalle=%s anim_objetos=%s" % [str(sc), GfxQuality.level(), k, str(det), str(ObjectAnim.on())])
		i += 1


# --- lo que el jugador lee o tiene cerca: una toma de frente a cada cosa, con la calidad que esté puesta -------------
## `fin_leer[:recuerdo]` → user://shots/fin_leer/<piso>_<nodo>.jpg. La cámara se pone sola: de frente a la cara ancha del
## objeto (o desde el lado más despejado, si es un bulto), a la distancia a la que el jugador lo leería.
const LEER: Array = [
	[2, ["Nota_NOTE_DESK*", "Nota_NOTE_CALIBRATION*", "Nota_NOTE_LOCKER*", "Nota_NOTE_WATER*", "Nota_NOTE_BATHROOM*", "Nota_NOTE_C*", "Nota_Q5_H_NOTA*", "Cub_C-13/Taza", "TazaMoho", "PizarraQA", "Cartel_POSTER_ROOM*", "Cartel_POSTER_LOCKERS*", "Casilleros*", "StickerEntrada*", "StickerCelular*", "Mural*", "MonitorQA", "Expendedora*", "Dispensador*", "Espejo", "EspejoChico", "Elevator/Panel", "Elevator/EspejoFondo", "PolaroidPromocion", "HojaColgando", "Papel"]],
	[1, ["Nota_NOTE_TRAINING*", "Nota_NOTE_TOPICO*", "Pizarra", "Corcho", "Cartel_SIGN_METRICS_WALL*", "Cartel_SIGN_AVAILABLE_ATTITUDE*", "Cartel_SIGN_BREAK_PRIVILEGE*", "FueraDeServicio*", "Contrato*", "Botiquin*"]],
	[-1, ["Nota_NOTE_PUFF*", "CartelRevision*", "Cartel_POSTER_REST*", "Microondas*", "Expendedora*", "Placa*", "Carta*", "Cuaderno*", "Llavero*", "Refri*", "Casillero*"]],
]
const LEER_RECUERDO: Array = ["Pizarra", "PizarraMarco", "Corcho", "Papel", "Cartel*", "ContratoMesa*", "Proyector*", "Guirnalda*", "Banderin*", "Nota_*", "MesaTraining"]


func _mesh_box(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var all: Array = [n] + n.find_children("*", "MeshInstance3D", true, false)
	for m in all:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	if first:
		out = AABB(n.global_position - Vector3(0.1, 0.1, 0.1), Vector3(0.2, 0.2, 0.2))
	return out


func c0(box: AABB) -> Vector3:
	return box.get_center()


func _free(s: Node, from: Vector3, dir: Vector3, far: float) -> float:
	var space: PhysicsDirectSpaceState3D = s.get_viewport().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * far)
	var hit := space.intersect_ray(q)
	return far if hit.is_empty() else from.distance_to(hit["position"])


func _front_cam(s: Node, n: Node3D) -> Dictionary:
	var box := _mesh_box(n)
	var c := box.get_center()
	var sz := box.size
	var big := maxf(sz.x, maxf(sz.y, sz.z))
	var dist := clampf(big * 1.5 + 0.28, 0.42, 2.6)
	var dirs: Array = []
	var flat := sz.y < 0.06 and sz.y <= minf(sz.x, sz.z)
	if not flat and minf(sz.x, sz.z) < 0.12 and minf(sz.x, sz.z) < maxf(sz.x, sz.z) * 0.5:
		# lámina vertical: por delante o por detrás de su cara ancha
		var nrm := Vector3.RIGHT if sz.x < sz.z else Vector3.BACK
		dirs = [nrm, -nrm]
	else:
		dirs = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	# Si lleva texto, el texto manda: la cámara va del lado hacia el que mira su Label3D (una nota pegada a una pared
	# tiene «libre» también del otro lado del tabique).
	var lab: Label3D = null
	for lc in n.find_children("*", "Label3D", true, false):
		lab = lc as Label3D
		break
	if lab == null and n.get_parent() != null:
		for lc in n.get_parent().get_children():
			if lc is Label3D and (lc as Label3D).global_position.distance_to(c0(box)) < maxf(big, 0.25):
				lab = lc as Label3D
				break
	if lab != null:
		var f := lab.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.3:
			dirs = [f.normalized()]
	var best := Vector3.ZERO
	var best_free := -1.0
	for d in dirs:
		var half: float = absf((d as Vector3).x) * sz.x * 0.5 + absf((d as Vector3).z) * sz.z * 0.5
		var f := _free(s, c + (d as Vector3) * (half + 0.03), d, 3.0)
		if f > best_free:
			best_free = f
			best = d
	var half_b: float = absf(best.x) * sz.x * 0.5 + absf(best.z) * sz.z * 0.5
	dist = minf(dist, half_b + best_free - 0.06)
	var up := 0.42 * dist if flat else 0.12 * dist
	var pos := c + best * maxf(dist, 0.2) + Vector3(0, up, 0)
	return {"pos": pos, "look": c, "libre": best_free, "tam": sz}


func _leer_floor(s: Node, fl: Node, pats: Array, tag: String, cam: Camera3D) -> void:
	for pat in pats:
		var n: Node3D = null
		if str(pat).contains("/"):
			var par := fl.find_child(str(pat).get_slice("/", 0), true, false)
			n = par.find_child(str(pat).get_slice("/", 1), true, false) as Node3D if par != null else null
		else:
			for c in fl.find_children(str(pat), "", true, false):
				if c is Node3D and (c as Node3D).is_visible_in_tree():
					n = c as Node3D
					break
		if n == null:
			print("[fin_leer] %s %s: no está" % [tag, str(pat)])
			continue
		var v: Dictionary = _front_cam(s, n)
		cam.global_position = v["pos"]
		cam.look_at(v["look"], Vector3.UP)
		cam.current = true
		for _i in 3:
			await s.get_tree().process_frame
		var relief := 0
		var total := 0
		for m in [n] + n.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
				total += 1
				if GfxMaterials.has_relief(m as MeshInstance3D):
					relief += 1
		print("[fin_leer] %s %s → %s: tamaño %s · mallas con relieve %d de %d" % [tag, str(pat), n.name, str((v["tam"] as Vector3).snapped(Vector3(0.01, 0.01, 0.01))), relief, total])
		await _snap(s, "fin_leer", "%s_%s" % [tag, str(n.name).validate_filename().replace(" ", "_")])


func _leer(s: Node, arg: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/fin_leer"))
	var cam := Camera3D.new()
	cam.name = "CamLeer"
	cam.fov = 48.0
	cam.near = 0.03
	s.get_tree().root.add_child(cam)
	if arg == "recuerdo":
		s._main.call("_back_to_menu")
		await _wait(s, 0.5)
		SaveSlots.select("Jiroshi")
		s._main.call("_start_first_training", "Jiroshi", GameState.Mode.NORMAL)
		var b0: Building = GfxQuality.live_building(s.get_tree())
		var w := 0.0
		while (b0 == null or b0.current_floor != 1) and w < 40.0:
			await _wait(s, 0.5)
			w += 0.5
			b0 = GfxQuality.live_building(s.get_tree())
		await _wait(s, 3.0)
		_ui_layers(s, false)
		# En el aula del recuerdo los nombres son otros: se toma todo lo que lleva texto (el soporte de cada Label3D),
		# una vez por nombre, más la lista fija.
		var pats: Array = LEER_RECUERDO.duplicate()
		var seen := {}
		for lb in b0.floor_node.find_children("*", "Label3D", true, false):
			var par := (lb as Node).get_parent()
			if not (par is Node3D) or par == b0.floor_node or not (lb as Label3D).is_visible_in_tree():
				continue
			var key := str(par.name).rstrip("0123456789_")
			if seen.has(key) or pats.size() >= 30:
				continue
			seen[key] = true
			pats.append(str(par.name))
		await _leer_floor(s, b0.floor_node, pats, "rec", cam)
	else:
		_ui_layers(s, false)
		var hud := s._main.get("hud") as Control
		if hud != null:
			hud.visible = false
		GameState.stop_calm()
		var cm := s._main.get("contacts") as Node
		if cm != null:
			cm.process_mode = Node.PROCESS_MODE_DISABLED
		for sh in s.get_tree().get_nodes_in_group("shero"):
			(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
		var b: Building = s._building()
		for e in LEER:
			if b.current_floor != int(e[0]) or b.floor_node == null:
				b.go_to_floor(int(e[0]), "ascensor")
				await _wait(s, 2.0)
			await _leer_floor(s, b.floor_node, e[1], "p%d" % int(e[0]) if int(e[0]) >= 0 else "s1", cam)
	cam.queue_free()



# --- muertes × gráficos × animación de objetos × voces: el colapso -------------------------------------------------------

func _colapso(s: Node, arg: String) -> void:
	var opts := Array(arg.split(":", false))
	var standing := "pie" in opts
	if "en" in opts and Loc.language != "en":
		Loc.set_language("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/fin_colapso"))
	await s._sit_c14()
	GameState.stop_calm()
	await _wait(s, 1.0)
	var p: Player = s._player()
	var cm := s.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	if standing:
		p.stand_up()
		p.teleport(Vector3(20.5, p.global_position.y, 0.8), -55.0)
		await _wait(s, 0.5)
	elif cm != null:
		var first: Dictionary = cm.next_scripted()
		GameState.clock_seconds = ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0
		EventBus.clock_tick.emit(GameState.clock_seconds)
		for _i in 600:
			await s.get_tree().process_frame
			if cm.phase == ContactManager.Phase.OFFERING:
				break
		if cm.phase == ContactManager.Phase.OFFERING:
			cm.accept()
		await _wait(s, 3.0)
	print("[fin_colapso] calidad=%s llamada=%s (%s) sentado=%s idioma=%s" % [GfxQuality.level(), str(cm != null and cm.is_active()), str(cm.current.get("canal", "")) if cm != null else "", str(p.seated), Loc.language])
	# la silla de trabajo bajo tu cuerpo (sus piezas de malla), para ver si alguien más la mueve
	var chair: Array = []
	if FloorBase.active != null:
		for n in FloorBase.active.find_children("Silla*", "MeshInstance3D", true, false):
			var d2 := (n as Node3D).global_position - p.global_position
			d2.y = 0.0
			if d2.length() < 0.6:
				chair.append(n)
	while not Checkpoints.can_die():
		await s.get_tree().process_frame
	Fatigue.set_value(99.0)
	Fatigue.add(10.0)
	# Por el reloj de la toma (no el de pared): con `--write-movie … --fixed-fps 30` cada cuadro es 1/30 s de juego.
	var k := 0
	var next_t := 0.0
	var frames := 0
	var tag := "pie" if standing else "sentado"
	while frames < 4000:
		await s.get_tree().process_frame
		frames += 1
		var fx: DeathAnimations = null
		for n in s.get_tree().get_nodes_in_group(DeathAnimations.GROUP):
			if not n.is_queued_for_deletion():
				fx = n as DeathAnimations
		if fx == null:
			if k > 0:
				break  # la toma terminó
			continue
		var el: float = fx._t3 if fx._third != null else float(frames) / 30.0
		if el + 0.001 < next_t:
			continue
		next_t = el + 0.3
		var cam := s.get_viewport().get_camera_3d()
		var key: Light3D = fx._third.find_child("LuzColapso", true, false) as Light3D if fx._third != null and is_instance_valid(fx._third) else null
		var sub: Label = fx.get_node_or_null("SubtituloToma") as Label
		var cpos := ""
		for c in chair:
			if is_instance_valid(c):
				cpos += " %s=(%.2f,%.2f)" % [str((c as Node).name), (c as Node3D).global_position.x, (c as Node3D).global_position.z]
		var gl := ""
		if is_instance_valid(GfxDirector.inst) and GfxDirector.inst.lights.active:
			gl = " luz_local=%.2f exposicion=%.2f" % [GfxDirector.inst.lights.local_light, GfxDirector.inst.atmosphere.exposure_now()]
		print("[fin_colapso] %02d t=%.2f cam=%s luz_toma=%s%s sub=«%s» voz=%s%s" % [k, el, str(cam.name) if cam != null else "-", "%.2f" % key.light_energy if key != null else "-", gl,
			sub.text if sub != null else "", VoiceDirector.current.id if VoiceDirector.current != null else "-", cpos])
		await _snap(s, "fin_colapso", "%s_%02d" % [tag, k])
		k += 1
	# «Usuario desconectado» y la reconexión: la silla en su sitio, las luces como estaban
	for _i in 60:
		await s.get_tree().process_frame
	await _snap(s, "fin_colapso", "%s_%02d_desconectado" % [tag, k])
	var cpos2 := ""
	for c in chair:
		if is_instance_valid(c):
			cpos2 += " %s=(%.2f,%.2f)" % [str((c as Node).name), (c as Node3D).global_position.x, (c as Node3D).global_position.z]
	print("[fin_colapso] fin: muerte_visible=%s%s" % [str(Checkpoints.death_visible), cpos2])

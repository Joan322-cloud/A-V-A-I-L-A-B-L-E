class_name NpcDesks
extends RefCounted
## Escritorios de los jefes en el piso 2 (v0.3.1 Q2, F19): el "TM" (Shero y Rasec lado a lado, al fondo este de la
## sala, mirando a la sala) y el "RTA" (el Perrito, con 3 monitores de gráficos). Cada uno con su silla, teclado y
## monitores encendidos (el brillo les ilumina la cara desde abajo); los monitores dan la espalda a la sala: desde
## tu fila ves sus cabezas asomando por encima de las pantallas.
## Marcadores (C8): escritorio_shero, escritorio_rasec, escritorio_rta = el punto de la silla, mirando a la sala. Si
## el piso ya los trae (Q5 los pone en el floor_02 nuevo), no se crea nada: solo se usan. Sin colisión (como el
## escritorio de Shero de siempre): nadie se traba al salir corriendo.
## API: NpcDesks.ensure(piso) · NpcDesks.seat(piso, quien) -> Transform3D (global; Transform3D() si no hay).

const DESKS: Array = [
	{"id": "shero", "pos": Vector3(46.9, 0, -9.0), "yaw": 90.0, "monitors": 2, "len": 2.4, "label": "TM"},
	{"id": "rasec", "pos": Vector3(46.9, 0, -5.8), "yaw": 90.0, "monitors": 2, "len": 1.8, "label": "TM"},
	{"id": "rta", "pos": Vector3(46.9, 0, -16.6), "yaw": 90.0, "monitors": 3, "len": 2.0, "label": "RTA"},
]
static var _tex_cache: Dictionary = {}


static func ensure(floor_node: Node3D) -> void:
	if floor_node == null or not floor_node.is_inside_tree():
		return
	# v0.3.1 (integración): la caja de escalera que sale del piso 2 también es «piso 2» para main.gd (trae a Shero);
	# ahí no hay escritorios (antes se armaban en el vacío, con marcadores inalcanzables para --check-collision).
	if floor_node is Stairwell:
		return
	if floor_node.get_node_or_null("EscritoriosNPC") != null:
		return
	var root := Node3D.new()
	root.name = "EscritoriosNPC"
	floor_node.add_child(root)
	for d in DESKS:
		var id := str(d["id"])
		var mk := floor_node.find_child("escritorio_" + id, true, false) as Node3D
		if mk == null:
			_desk(root, d)
		elif not _has_monitor_near(floor_node, mk.global_position, 1.6):
			# El piso trae el escritorio (Q5) pero sin pantallas para él (Shero): solo monitores, teclado y brillo.
			_desk(root, d, mk)


static func _has_monitor_near(floor_node: Node3D, p: Vector3, r: float) -> bool:
	for n in floor_node.find_children("Monitor*", "Node3D", true, false):
		if (n as Node3D).global_position.distance_to(p) < r:
			return true
	return false


static func seat(floor_node: Node3D, who: String) -> Transform3D:
	if floor_node == null:
		return Transform3D()
	var m := floor_node.find_child("escritorio_" + who, true, false) as Node3D
	return m.global_transform if m != null else Transform3D()


static func has_seat(floor_node: Node3D, who: String) -> bool:
	return floor_node != null and floor_node.find_child("escritorio_" + who, true, false) != null


static func _desk(root: Node3D, d: Dictionary, marker: Node3D = null) -> void:
	var id := str(d["id"])
	var seat_pos: Vector3 = d["pos"]
	var yaw := float(d["yaw"])
	var n := Node3D.new()
	n.name = "Escritorio_" + id
	root.add_child(n)
	if marker != null:
		n.global_transform = marker.global_transform  # sobre el escritorio que ya trae el piso
	else:
		n.position = seat_pos
		n.rotation_degrees.y = yaw
	# Local: el que se sienta mira a -Z; el escritorio queda delante (z negativo).
	var ln := float(d["len"])
	if id != "shero" and marker == null:  # el de Shero ya existe en el piso (EscritorioShero); se le agregan monitores y teclado
		Greybox.box(n, "Tapa", Vector3(0, 0.75, -0.9), Vector3(ln, 0.06, 1.0), Greybox.GRIS_OSCURO, false)
		Greybox.box(n, "Panel", Vector3(0, 0.38, -1.36), Vector3(ln, 0.7, 0.04), Greybox.NEGRO, false)
		Greybox.box(n, "Silla", Vector3(0, 0.5, 0), Vector3(0.6, 0.1, 0.6), Greybox.GRIS_OSCURO, false)
		Greybox.box(n, "Respaldo", Vector3(0, 0.85, 0.3), Vector3(0.56, 0.6, 0.06), Greybox.NEGRO, false)
	var count := int(d["monitors"])
	for i in count:
		var x := (float(i) - (count - 1) * 0.5) * 0.56
		var ang := -x * 0.35
		var mon := Node3D.new()
		mon.name = "Monitor%d" % i
		n.add_child(mon)
		mon.position = Vector3(x, 0.78, -1.08)
		mon.rotation.y = ang
		Greybox.box(mon, "Pie", Vector3(0, 0.08, 0.05), Vector3(0.18, 0.02, 0.14), Greybox.NEGRO, false)
		Greybox.box(mon, "Cuello", Vector3(0, 0.17, 0.06), Vector3(0.04, 0.18, 0.03), Greybox.NEGRO, false)
		Greybox.box(mon, "Moldura", Vector3(0, 0.42, 0.03), Vector3(0.54, 0.34, 0.03), Greybox.NEGRO, false)
		var q := MeshInstance3D.new()
		q.name = "Pantalla"
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.3)
		q.mesh = qm
		q.position = Vector3(0, 0.42, 0.048)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = _screen_tex(id, i)
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mon.add_child(q)
	Greybox.box(n, "Teclado", Vector3(0, 0.79, -0.62), Vector3(0.44, 0.02, 0.14), Color(0.08, 0.08, 0.09), false)
	# El brillo de las pantallas en la cara (de abajo, frío).
	var l := OmniLight3D.new()
	l.name = "BrilloPantallas"
	l.light_color = Color(0.55, 0.7, 1.0) if id != "rta" else Color(0.55, 1.0, 0.7)
	l.light_energy = 0.55
	l.omni_range = 1.7
	l.shadow_enabled = false
	l.position = Vector3(0, 1.0, -0.7)
	l.set_meta("no_mood", true)
	n.add_child(l)
	if marker != null:
		return  # el marcador y el letrero son del piso
	Greybox.label(n, str(d["label"]), Vector3(0, 0.62, -1.4), 0.07, Greybox.CIAN, PI)
	var m := Marker3D.new()
	m.name = "escritorio_" + id
	n.add_child(m)


## Pantalla procedural (una vez por tipo): Ezlaki con texto rojo para el TM, gráficos de adherencia para el RTA.
static func _screen_tex(id: String, i: int) -> Texture2D:
	var key := "%s_%d" % [id, i % 3]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var w := 128
	var h := 80
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	img.fill(Color(0.03, 0.05, 0.09))
	if id == "rta":
		# Barras y una línea roja que cae (adherencia).
		img.fill_rect(Rect2i(0, 0, w, 9), Color(0.1, 0.35, 0.3))
		var base := h - 8
		for b in 12:
			var bh := rng.randi_range(8, 52)
			var col := Color(0.2, 0.85, 0.5) if bh > 22 else Color(0.9, 0.2, 0.15)
			img.fill_rect(Rect2i(6 + b * 10, base - bh, 6, bh), col)
		var y := 20.0
		for x in range(4, w - 4):
			y = clampf(y + rng.randf_range(-1.2, 1.6), 12.0, float(h - 10))
			img.set_pixel(x, int(y), Color(1.0, 0.25, 0.2))
	else:
		img.fill_rect(Rect2i(0, 0, w, 9), Color(0.25, 0.1, 0.35))
		img.fill_rect(Rect2i(0, 9, 26, h - 9), Color(0.06, 0.07, 0.12))
		for r in 9:
			var yy := 14 + r * 7
			var ln := rng.randi_range(30, 90)
			var col := Color(0.75, 0.78, 0.82) if r % 3 != 1 else Color(0.95, 0.2, 0.18)
			img.fill_rect(Rect2i(32, yy, ln, 2), col)
			img.fill_rect(Rect2i(4, yy, 16, 2), Color(0.4, 0.45, 0.55))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t

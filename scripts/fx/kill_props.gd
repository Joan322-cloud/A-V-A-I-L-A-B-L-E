class_name KillProps
extends RefCounted
## Utilería de las muertes propias (v0.3.1, fx/kill_moves.gd): mallas genéricas hechas en código (sin assets nuevos,
## sin marcas reales): hojas impresas, lanyard y fotocheck, cable del headset, micrófono, gorro de fiesta, tickets,
## pizarra, mesa y táper, teclado, divisor del pod, vidrios, confeti. Todo cuelga del escenario del screamer
## (Screamers._stage) y se libera con él. En Modo liviano / Calidad Baja los restos (tickets, teclas, vidrios,
## confeti, arroz) son la mitad o menos.


## Texto traducido (strings_v031_q2.csv); si falta la clave, el texto de respaldo.
static func t(key: String, fallback: String) -> String:
	var v := str(TranslationServer.translate(key))
	return v if v != key else fallback


static func light_mode() -> bool:
	return GfxQuality.is_light() or GfxQuality.is_low()


## Cantidad de restos según la calidad (Modo liviano: un tercio; Baja: la mitad).
static func count(n: int) -> int:
	if GfxQuality.is_light():
		return maxi(3, n / 3)
	if GfxQuality.is_low():
		return maxi(4, n / 2)
	return n


static func mat(c: Color, emission: float = 0.0, transparent: bool = false, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent or c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emission
	return m


static func box(parent: Node3D, size: Vector3, c: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emission)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, px: float, c: Color, pos: Vector3, width_m: float = 0.0, size: int = 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.double_sided = true
	l.shaded = true
	l.position = pos
	if width_m > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width_m / px
	parent.add_child(l)
	return l


# --- seguidores ---------------------------------------------------------------------------------------------

## Nodo que sigue a la cámara del screamer: pos (espacio de la cámara: x derecha, y arriba, z = -adelante) y rot
## (grados). use_cam = false: sigue la vista sin el temblor. rate <= 0: sin suavizado. Las tweens animan pos/rot.
class Follow extends Node3D:
	var fx: Screamers = null
	var pos: Vector3 = Vector3(0, 0, -0.5)
	var rot: Vector3 = Vector3.ZERO
	var rate: float = 16.0
	var use_cam: bool = true
	var active: bool = true
	var _first: bool = true

	func _process(delta: float) -> void:
		if not active or fx == null or not is_instance_valid(fx) or fx._player == null or not is_instance_valid(fx._player):
			return
		var base: Transform3D = fx._cam().global_transform if use_cam else fx.view_xf()
		var want := base * Transform3D(Basis.from_euler(rot * (PI / 180.0)), pos)
		if _first or rate <= 0.0:
			global_transform = want
			_first = false
		else:
			global_transform = global_transform.interpolate_with(want, minf(delta * rate, 1.0))

	## Coloca ya (sin suavizar) en la posición pedida.
	func snap() -> void:
		_first = true
		_process(0.0)


## Llama a fn(delta) en cada cuadro mientras viva (se cuelga del escenario del screamer y muere con él): la vista
## colgada de la cabeza del agente en la tercera persona de la fusión, una mano que sigue a un hueso…
class Each extends Node:
	var fn: Callable = Callable()

	func _process(delta: float) -> void:
		if fn.is_valid():
			fn.call(delta)


static func follow(fx: Screamers, pos: Vector3, rot: Vector3 = Vector3.ZERO, use_cam: bool = true) -> Follow:
	var f := Follow.new()
	f.fx = fx
	f.pos = pos
	f.rot = rot
	f.use_cam = use_cam
	fx._stage.add_child(f)
	f.snap()
	return f


# --- cuerdas: lanyard, cable del headset, cable del micrófono -------------------------------------------------

## Cinta/cable entre puntos del mundo (pts_fn → PackedVector3Array), de cara a la cámara (ImmediateMesh).
class Rope extends MeshInstance3D:
	var pts_fn: Callable = Callable()
	var width: float = 0.012
	var cam: Camera3D = null
	var _im: ImmediateMesh = null

	func setup(c: Color, w: float, p_cam: Camera3D, emission: float = 0.0) -> void:
		_im = ImmediateMesh.new()
		mesh = _im
		width = w
		cam = p_cam
		top_level = true
		material_override = KillProps.mat(c, emission)
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(_d: float) -> void:
		if _im == null or not pts_fn.is_valid() or cam == null or not is_instance_valid(cam):
			return
		global_transform = Transform3D.IDENTITY
		_im.clear_surfaces()
		var pts: PackedVector3Array = pts_fn.call()
		var n := pts.size()
		if n < 2 or not visible:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var p := pts[i]
			var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
			if d.length() < 0.0001:
				d = Vector3.UP
			d = d.normalized()
			var to_c := (cam.global_position - p)
			to_c = to_c.normalized() if to_c.length() > 0.0001 else Vector3.BACK
			var side := d.cross(to_c)
			side = side.normalized() * width * 0.5 if side.length() > 0.0001 else Vector3.RIGHT * width * 0.5
			_im.surface_set_normal(to_c)
			_im.surface_add_vertex(p - side)
			_im.surface_set_normal(to_c)
			_im.surface_add_vertex(p + side)
		_im.surface_end()


static func rope(fx: Screamers, c: Color, w: float, pts_fn: Callable, emission: float = 0.0) -> Rope:
	var r := Rope.new()
	r.setup(c, w, fx._cam(), emission)
	r.pts_fn = pts_fn
	fx._stage.add_child(r)
	return r


## Curva colgante entre a y b (n puntos, cae `drop` m en el medio).
static func sag(a: Vector3, b: Vector3, n: int = 10, drop: float = 0.05) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var u := float(i) / float(n - 1)
		out.append(a.lerp(b, u) + Vector3.DOWN * drop * 4.0 * u * (1.0 - u))
	return out


# --- piezas ----------------------------------------------------------------------------------------------------

## Hoja impresa A4 (WW, lista del Mentor, hoja de calibración): de frente hacia +Z.
static func sheet(parent: Node3D, title: String, body: String, accent: Color, stamp: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "Hoja"
	parent.add_child(root)
	var w := 0.21
	var h := 0.297
	box(root, Vector3(w, h, 0.0016), Color(0.9, 0.9, 0.86))
	box(root, Vector3(w, 0.03, 0.0005), accent, Vector3(0, h * 0.5 - 0.022, 0.0011))
	label(root, title, 0.00042, Color(0.08, 0.08, 0.1), Vector3(0, h * 0.5 - 0.06, 0.0012), w * 0.86, 52)
	label(root, body, 0.00026, Color(0.12, 0.12, 0.14), Vector3(0, 0.035, 0.0012), w * 0.84, 44)
	for i in 6:
		box(root, Vector3(w * (0.7 - 0.06 * (i % 3)), 0.004, 0.0005), Color(0.55, 0.55, 0.56), Vector3(-0.01, -0.05 - i * 0.013, 0.0011))
	if stamp != "":
		var st := label(root, stamp, 0.00055, Color(0.8, 0.05, 0.04, 0.92), Vector3(0.025, -0.095, 0.0014), 0.0, 64)
		st.rotation.z = 0.32
		st.outline_size = 0
	return root


## Fotocheck en dos mitades (se parte en dos): izquierda y derecha, de frente hacia +Z. Devuelve [raíz, izq, der].
static func badge(parent: Node3D, agent: String) -> Array:
	var root := Node3D.new()
	root.name = "Fotocheck"
	parent.add_child(root)
	var halves: Array = []
	for side in [-1, 1]:
		var half := Node3D.new()
		half.name = "Mitad%d" % side
		half.position = Vector3(side * 0.0142, 0, 0)
		root.add_child(half)
		box(half, Vector3(0.0278, 0.086, 0.0012), Color(0.86, 0.87, 0.86))
		box(half, Vector3(0.0278, 0.016, 0.0004), Color(0.12, 0.13, 0.17), Vector3(0, 0.035, 0.0008))
		halves.append(half)
	box(halves[0], Vector3(0.022, 0.026, 0.0004), Color(0.3, 0.3, 0.33), Vector3(0.003, 0.008, 0.0008))
	label(halves[0], "KONZEN", 0.00012, Color(0.85, 0.85, 0.85), Vector3(0.004, 0.035, 0.0011), 0.0, 48)
	label(halves[1], "TRAMANCE", 0.00012, Color(0.85, 0.85, 0.85), Vector3(-0.002, 0.035, 0.0011), 0.0, 48)
	var name_l := agent.to_upper()
	var cut := int(ceil(name_l.length() / 2.0))
	label(halves[0], name_l.substr(0, cut), 0.00016, Color(0.1, 0.1, 0.1), Vector3(0.006, -0.022, 0.0011), 0.0, 48)
	label(halves[1], name_l.substr(cut), 0.00016, Color(0.1, 0.1, 0.1), Vector3(-0.004, -0.022, 0.0011), 0.0, 48)
	label(halves[0], "AGEN", 0.0001, Color(0.3, 0.3, 0.3), Vector3(0.006, -0.034, 0.0011), 0.0, 48)
	label(halves[1], "TE", 0.0001, Color(0.3, 0.3, 0.3), Vector3(-0.004, -0.034, 0.0011), 0.0, 48)
	return [root, halves[0], halves[1]]


## Micrófono de karaoke (mango negro, rejilla), apuntando a -Z (la rejilla adelante).
static func mic(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Microfono"
	parent.add_child(root)
	var h := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.017
	cm.bottom_radius = 0.012
	cm.height = 0.17
	h.mesh = cm
	h.material_override = mat(Color(0.05, 0.05, 0.06), 0.0, false, 0.4)
	h.rotation.x = PI * 0.5
	h.position = Vector3(0, 0, 0.085)
	root.add_child(h)
	var g := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	g.mesh = sm
	g.material_override = mat(Color(0.55, 0.56, 0.6), 0.0, false, 0.3)
	root.add_child(g)
	box(root, Vector3(0.008, 0.004, 0.01), Color(1.0, 0.15, 0.5), Vector3(0, 0.017, 0.06), 3.0)
	return root


## Gorro de fiesta: cono de rayas con pompón (la punta hacia +Y).
static func hat(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "GorroFiesta"
	parent.add_child(root)
	for i in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r0 := 0.085 * (1.0 - i / 3.0)
		var r1 := 0.085 * (1.0 - (i + 1) / 3.0)
		cm.bottom_radius = r0
		cm.top_radius = maxf(r1, 0.002)
		cm.height = 0.075
		mi.mesh = cm
		mi.material_override = mat([Color(0.95, 0.2, 0.55), Color(0.98, 0.85, 0.2), Color(0.2, 0.75, 0.95)][i], 0.25)
		mi.position = Vector3(0, 0.0375 + i * 0.075, 0)
		root.add_child(mi)
	var p := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	p.mesh = sm
	p.material_override = mat(Color(1, 1, 1), 0.3)
	p.position = Vector3(0, 0.23, 0)
	root.add_child(p)
	return root


## Pizarra blanca de la sala de training con lo que reprobaste escrito a plumón. De frente hacia +Z.
static func whiteboard(parent: Node3D, detail: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Pizarra"
	parent.add_child(root)
	box(root, Vector3(1.7, 1.05, 0.02), Color(0.93, 0.94, 0.94), Vector3.ZERO)
	for e in [[Vector3(0, 0.535, 0.005), Vector3(1.74, 0.03, 0.035)], [Vector3(0, -0.535, 0.005), Vector3(1.74, 0.03, 0.035)],
			[Vector3(-0.86, 0, 0.005), Vector3(0.03, 1.1, 0.035)], [Vector3(0.86, 0, 0.005), Vector3(0.03, 1.1, 0.035)]]:
		box(root, e[1], Color(0.55, 0.57, 0.6), e[0])
	box(root, Vector3(0.9, 0.025, 0.07), Color(0.55, 0.57, 0.6), Vector3(0, -0.55, 0.04))
	label(root, t("SCR_K_BOARD_TITLE", "QUIZ DE PRODUCTO"), 0.0016, Color(0.1, 0.2, 0.75), Vector3(-0.2, 0.36, 0.012), 0.0, 64)
	label(root, "AHT · FCR · NPS · KPI", 0.0011, Color(0.1, 0.2, 0.75), Vector3(-0.25, 0.2, 0.012), 0.0, 64)
	label(root, t("SCR_K_BOARD_FAIL", "{nota}  REPROBADO").replace("{nota}", detail if detail != "" else "2/5"), 0.0021, Color(0.82, 0.08, 0.06), Vector3(0.05, -0.05, 0.012), 0.0, 64)
	label(root, t("SCR_K_BOARD_NOTE", "NO SE REPITE"), 0.0012, Color(0.82, 0.08, 0.06), Vector3(0.1, -0.28, 0.012), 0.0, 64)
	var mk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.009
	cm.bottom_radius = 0.009
	cm.height = 0.12
	mk.mesh = cm
	mk.material_override = mat(Color(0.1, 0.25, 0.85))
	mk.rotation.z = PI * 0.5
	mk.position = Vector3(0.2, -0.53, 0.05)
	root.add_child(mk)
	return root


## Mesa del comedor con un táper (arroz y guiso). La tapa del táper hacia +Y.
static func table_taper(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "MesaTaper"
	parent.add_child(root)
	box(root, Vector3(1.3, 0.04, 0.8), Color(0.42, 0.33, 0.25), Vector3(0, -0.02, 0))
	var taper := Node3D.new()
	taper.name = "Taper"
	root.add_child(taper)
	box(taper, Vector3(0.2, 0.06, 0.14), Color(0.85, 0.88, 0.9, 0.55), Vector3(0, 0.03, 0))
	box(taper, Vector3(0.18, 0.045, 0.12), Color(0.93, 0.9, 0.8), Vector3(0.0, 0.026, 0))
	box(taper, Vector3(0.08, 0.02, 0.1), Color(0.55, 0.28, 0.12), Vector3(0.05, 0.05, 0))
	var lid := box(taper, Vector3(0.21, 0.012, 0.15), Color(0.25, 0.55, 0.85, 0.7), Vector3(-0.17, 0.006, 0.05))
	lid.rotation.y = 0.5
	var fork := box(root, Vector3(0.012, 0.004, 0.16), Color(0.75, 0.76, 0.78), Vector3(0.18, 0.003, 0.05))
	fork.rotation.y = -0.3
	return {"root": root, "taper": taper}


## Teclado genérico (cuerpo y placa de teclas). Las teclas que saltan son restos (debris).
static func keyboard(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Teclado"
	parent.add_child(root)
	box(root, Vector3(0.44, 0.022, 0.15), Color(0.06, 0.06, 0.07))
	for r in 4:
		box(root, Vector3(0.4, 0.008, 0.026), Color(0.16, 0.16, 0.18), Vector3(0, 0.014, -0.05 + r * 0.033))
	return root


## Divisor del pod (panel de tela con canto de aluminio) de frente hacia +Z.
static func divider(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "DivisorPod"
	parent.add_child(root)
	box(root, Vector3(1.8, 0.62, 0.05), Color(0.2, 0.24, 0.3), Vector3.ZERO)
	box(root, Vector3(1.82, 0.03, 0.06), Color(0.6, 0.62, 0.65), Vector3(0, 0.325, 0))
	return root


# --- restos -------------------------------------------------------------------------------------------------

## Restos que vuelan (tickets, teclas, vidrios, arroz, confeti): física simple (gravedad, giro, roce).
class Debris extends Node3D:
	var parts: Array = []  # [MeshInstance3D, vel, angvel]
	var gravity: float = 4.0
	var drag: float = 1.2
	var life: float = 3.0

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		for p in parts:
			var mi := p[0] as MeshInstance3D
			var v: Vector3 = p[1]
			v.y -= gravity * delta
			v *= maxf(0.0, 1.0 - drag * delta)
			p[1] = v
			mi.global_position += v * delta
			mi.rotate_object_local(Vector3(1, 0.3, 0.2).normalized(), float(p[2]) * delta)


## n piezas de `size` (color o colores) desde `origin`, velocidad vel_fn(i) → Vector3.
static func debris(fx: Screamers, n: int, size: Vector3, colors: Array, origin: Vector3, vel_fn: Callable, gravity: float = 4.0, prism: bool = false) -> Debris:
	var d := Debris.new()
	d.gravity = gravity
	fx._stage.add_child(d)
	d.global_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 31 + 7
	var mats: Array = []
	for c in colors:
		mats.append(mat(c, 0.15 if prism else 0.0, (c as Color).a < 0.99))
	var mesh: Mesh
	if prism:
		var pm := PrismMesh.new()
		pm.size = size
		mesh = pm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mesh = bm
	for i in count(n):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mats[i % mats.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.add_child(mi)
		mi.global_position = origin + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.04))
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		d.parts.append([mi, vel_fn.call(i), rng.randf_range(-12.0, 12.0)])
	return d

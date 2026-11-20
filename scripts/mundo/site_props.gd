class_name SiteProps
extends RefCounted
## v0.3.1 Q5: utilería del edificio reconstruida desde las fotos y videos del site (ref_site_v2/REFERENCIA_PISOS.md).
## Nada de logos, nombres, lemas, números reales ni personas: los carteles son genéricos y los posters, figuras sin
## rostro de la campaña ficticia de AVAILABLE. Todo es geometría barata (cajas, cilindros, Label3D) y, donde hay
## animación, un _process a pocos Hz.
##
## Anclas de interacción (para Q4, F15/D4/D5): cada refri, microondas, lavadero y casillero lleva un Marker3D hijo
## «Ancla» donde se para el jugador (mirando al objeto) y está en un grupo: "refris", "microondas", "lavaderos".
## Los microondas tienen meta "slot" (0..5), "fila" (0 abajo, 1 arriba) y dos nodos que Q4 puede manejar: «Reloj»
## (Label3D del display LED) e «Interior» (MeshInstance3D emisivo, apagado = girando no).

const ARROW_GREEN := Color(0.224, 0.827, 0.325)
const ARROW_RED := Color(0.9, 0.12, 0.08)


static func _anchor(parent: Node3D, local: Vector3, yaw_deg: float) -> Marker3D:
	var a := Marker3D.new()
	a.name = "Ancla"
	a.position = local
	a.rotation_degrees.y = yaw_deg
	parent.add_child(a)
	return a


## Molinete trípode de acero (gabinete + brazos sin colisión + flecha LED). El gabinete choca hasta 1,25 m (C16).
static func tripod_cabinet(parent: Node, p_name: String, pos: Vector3, arms_side: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	parent.add_child(root)
	var inox := Greybox.inox()
	var cab := Greybox.box(root, "Gabinete", Vector3(0, 0.5, 0), Vector3(0.24, 1.0, 1.1), Greybox.INOX)
	cab.material_override = inox
	Greybox.invisible_box(root, "Alto", Vector3(0, 1.12, 0), Vector3(0.24, 0.25, 1.1))
	Greybox.box(root, "Tapa", Vector3(0, 1.01, 0), Vector3(0.26, 0.02, 1.12), Greybox.NEGRO, false)
	var hub := Greybox.cylinder(root, "Eje", Vector3(arms_side * 0.16, 0.85, 0.0), 0.07, 0.1, Greybox.INOX, false, 0.32, 0.45)
	hub.rotation_degrees.z = 90.0
	for k in 3:
		var arm := Greybox.cylinder(root, "Brazo%d" % k, Vector3(arms_side * 0.42, 0.85, 0.0), 0.018, 0.5, Greybox.INOX, false, 0.32, 0.45)
		arm.rotation_degrees = Vector3(k * 120.0 + 30.0, 0, 90.0)
		arm.position = Vector3(arms_side * 0.42, 0.85 + 0.2 * sin(deg_to_rad(k * 120.0 + 30.0)), 0.2 * cos(deg_to_rad(k * 120.0 + 30.0)))
	for side in [-1.0, 1.0]:
		var led := Greybox.box(root, "Flecha%d" % int(side), Vector3(0, 0.98, side * 0.42), Vector3(0.12, 0.012, 0.12), ARROW_GREEN, false, 2.5)
		led.set_meta("flecha", true)
	return root


## Lector alto negro con display azul (el carril accesible del lobby).
static func tall_reader(parent: Node, p_name: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	parent.add_child(root)
	Greybox.box(root, "Poste", Vector3(0, 0.7, 0), Vector3(0.22, 1.4, 0.22), Color(0.04, 0.04, 0.045))
	Greybox.invisible_box(root, "Alto", Vector3(0, 1.3, 0), Vector3(0.22, 0.2, 0.22))
	var d := Greybox.box(root, "Display", Vector3(0, 1.22, 0.112), Vector3(0.14, 0.1, 0.005), Color(0.15, 0.45, 0.95), false, 2.0)
	d.name = "Display"
	var nm := Greybox.label(root, "", Vector3(0, 1.22, 0.118), 0.03, Color(0.8, 0.9, 1.0))
	nm.name = "Nombre"
	nm.outline_size = 0
	return root


## Flechas de los molinetes: verdes; con presión alta pasan a rojo en secuencia HACIA el jugador.
class ArrowWave extends Node:
	var arrows: Array[MeshInstance3D] = []
	var _t: float = 0.0
	var _phase: float = 0.0
	var _red: StandardMaterial3D = null
	var _green: StandardMaterial3D = null

	func _ready() -> void:
		_red = Greybox.material(ARROW_RED, 2.5)
		_green = Greybox.material(ARROW_GREEN, 2.5)

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.2
		var d := Dread.level()
		if d < 0.5 or arrows.is_empty():
			for a in arrows:
				if is_instance_valid(a):
					a.material_override = _green
			return
		_phase += 1.0
		var cam := get_viewport().get_camera_3d()
		var order := arrows.duplicate()
		if cam != null:
			order.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return a.global_position.distance_to(cam.global_position) > b.global_position.distance_to(cam.global_position))
		var lit := int(_phase) % (order.size() + 3)
		for i in order.size():
			(order[i] as MeshInstance3D).material_override = _red if i <= lit else _green


## Poster de la campaña ficticia: figura sin rostro, con la cara cada vez más raspada (turno a turno).
static func faceless_poster(parent: Node, p_name: String, pos: Vector3, rot_deg: float, slogan_key: String, hue: Color, scratch: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = rot_deg
	parent.add_child(root)
	Greybox.box(root, "Moldura", Vector3.ZERO, Vector3(0.84, 1.18, 0.03), Greybox.NEGRO, false)
	Greybox.box(root, "Fondo", Vector3(0, 0, 0.017), Vector3(0.78, 1.12, 0.005), hue.darkened(0.35), false, 0.15)
	Greybox.box(root, "Circulo", Vector3(0.12, 0.18, 0.021), Vector3(0.5, 0.5, 0.003), hue.lightened(0.2), false, 0.2)
	var skin := Color(0.62, 0.55, 0.5)
	Greybox.box(root, "Torso", Vector3(0.04, -0.2, 0.023), Vector3(0.36, 0.42, 0.003), Color(0.08, 0.09, 0.12), false)
	Greybox.cylinder(root, "Cabeza", Vector3(0.04, 0.17, 0.024), 0.11, 0.003, skin).rotation_degrees.x = 90.0
	# Sin rostro: óvalo liso; los raspones (más cada turno) dejan ver el fondo.
	for k in clampi(scratch, 0, 6):
		var s := Greybox.box(root, "Raspon%d" % k, Vector3(0.04 + (k - 2.5) * 0.025, 0.17 + (k % 3 - 1) * 0.03, 0.027), Vector3(0.012, 0.2, 0.002), Color(0.85, 0.85, 0.82), false)
		s.rotation_degrees.z = -25.0 + k * 9.0
	var l := Greybox.label(root, "", Vector3(0, -0.47, 0.024), 0.05, Color(0.95, 0.95, 0.92))
	l.text = root.tr(slogan_key) if root.is_inside_tree() else TranslationServer.translate(slogan_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 0.72 / l.pixel_size
	l.outline_size = 0
	return root


## Refrigeradora de acero inox de 2 puertas (congelador arriba), interactuable (WorldObjects.Fridge).
static func fridge(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Interactable:
	var f := WorldObjects.Fridge.new()
	f.name = p_name
	f.hint_key = "HUD_FRIDGE"
	f.size = Vector3(1.0, 2.2, 1.1)
	f.position = pos + Vector3(0, 0.9, 0)
	f.rotation_degrees.y = yaw_deg
	parent.add_child(f)
	f.add_to_group("refris")
	var inox := Greybox.inox()
	var body := Greybox.box(f, "Caja", Vector3(0, 0, 0), Vector3(0.7, 1.8, 0.7), Greybox.INOX)
	body.material_override = inox
	Greybox.box(f, "Junta", Vector3(0, 0.35, 0.352), Vector3(0.68, 0.012, 0.01), Greybox.NEGRO, false)
	for hy in [0.6, -0.05]:
		Greybox.box(f, "Jalador%d" % int(hy * 10 + 10), Vector3(0.28, hy, 0.37), Vector3(0.025, 0.3 if hy > 0.3 else 0.5, 0.03), Greybox.GRIS_OSCURO, false)
	Greybox.box(f, "Etiqueta", Vector3(-0.2, 0.15, 0.356), Vector3(0.12, 0.17, 0.003), Color(0.9, 0.9, 0.86), false)
	_anchor(f, Vector3(0, -0.9, 1.0), 180.0)
	return f


## Estación de microondas del -1 (D5): 6 microondas iguales en 2 filas de 3 (mesada a 0,95 m y repisa inox a 1,35 m).
## Devuelve los 6 interactuables (WorldObjects.Microwave). El primero se llama `first_name` (compatibilidad).
static func microwave_bank(parent: Node, origin: Vector3, yaw_deg: float, first_name: String = "Microondas") -> Array[Interactable]:
	var root := Node3D.new()
	root.name = "EstacionMicroondas"
	root.position = origin
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var inox := Greybox.inox()
	Greybox.box(root, "Mesada", Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.6), Color(0.91, 0.90, 0.88))
	Greybox.box(root, "MesadaTope", Vector3(0, 0.91, 0), Vector3(1.62, 0.03, 0.62), Color(0.88, 0.87, 0.84), false)
	var rack := Greybox.box(root, "Repisa", Vector3(0, 1.33, -0.05), Vector3(1.56, 0.025, 0.5), Greybox.INOX, false)
	rack.material_override = inox
	for px in [-0.78, 0.78]:
		Greybox.box(root, "Paral%d" % int(px * 10), Vector3(px, 1.45, -0.27), Vector3(0.03, 1.0, 0.03), Greybox.INOX, false).material_override = inox
	var out: Array[Interactable] = []
	var times := ["12:00", "--:--", "88:88", "03:47", "00:00", "11:59"]
	for row in 2:
		for col in 3:
			var i := row * 3 + col
			var mw := WorldObjects.Microwave.new()
			mw.name = first_name if i == 0 else "%s_%d" % [first_name, i + 1]
			mw.hint_key = "HUD_MICROWAVE"
			mw.size = Vector3(0.6, 0.45, 0.6)
			mw.position = Vector3(-0.5 + col * 0.5, 1.07 + row * 0.42, -0.05)
			mw.set_meta("slot", i)
			mw.set_meta("fila", row)
			root.add_child(mw)
			mw.add_to_group("microondas")
			var body := Greybox.box(mw, "Caja", Vector3.ZERO, Vector3(0.48, 0.28, 0.38), Greybox.NEGRO, false)
			body.material_override = Greybox.material(Color(0.07, 0.07, 0.075), 0.0, 0.35, 0.4)
			var glass := Greybox.box(mw, "Vidrio", Vector3(-0.06, 0, 0.192), Vector3(0.3, 0.2, 0.004), Color(0.05, 0.06, 0.06), false)
			glass.name = "Vidrio"
			var inner := Greybox.box(mw, "Interior", Vector3(-0.06, 0, 0.15), Vector3(0.28, 0.18, 0.05), Color(1.0, 0.78, 0.45), false, 0.0)
			inner.material_override = Greybox.material(Color(0.12, 0.1, 0.08))
			inner.name = "Interior"
			var clock := Greybox.label(mw, times[i], Vector3(0.16, 0.06, 0.195), 0.04, Greybox.VERDE_LED)
			clock.name = "Reloj"
			clock.outline_size = 0
			Greybox.box(mw, "Teclado", Vector3(0.16, -0.04, 0.193), Vector3(0.1, 0.12, 0.003), Color(0.15, 0.15, 0.16), false)
			_anchor(mw, Vector3(0, -1.07 - row * 0.42, 0.8), 180.0)
			out.append(mw)
	# Uno siempre muestra la hora equivocada que avanza sola; otro parpadea (relojes desincronizados).
	var desync := _ClockDesync.new()
	desync.name = "Desincronizados"
	for mw in out:
		desync.labels.append(mw.get_node("Reloj") as Label3D)
	root.add_child(desync)
	return out


class _ClockDesync extends Node:
	var labels: Array[Label3D] = []
	var _t: float = 0.0
	var _blink: bool = false

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or labels.size() < 6:
			return
		_t = 0.5
		_blink = not _blink
		if labels[1].get_meta("q4", false) == false:
			labels[1].visible = _blink
		if labels[3].get_meta("q4", false) == false:
			var s := int(GameState.clock_seconds) if GameState.running else 0
			labels[3].text = "%02d:%02d" % [int(s / 3600 + 3) % 24, int((s / 60 + 47) % 60)]


## Lavadero de acero inox con grifo de cuello alto, escurridor y una gota que cae (D5).
static func sink(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	root.add_to_group("lavaderos")
	var inox := Greybox.inox()
	Greybox.box(root, "Mueble", Vector3(0, 0.43, 0), Vector3(0.7, 0.86, 0.6), Color(0.85, 0.85, 0.83))
	var top := Greybox.box(root, "Poza", Vector3(0, 0.9, 0), Vector3(0.72, 0.06, 0.62), Greybox.INOX, false)
	top.material_override = inox
	Greybox.box(root, "Hueco", Vector3(-0.08, 0.92, 0.02), Vector3(0.4, 0.02, 0.4), Color(0.25, 0.26, 0.27), false)
	var cuello := Greybox.cylinder(root, "Cuello", Vector3(-0.08, 1.12, -0.24), 0.015, 0.4, Greybox.INOX, false, 0.32, 0.45)
	cuello.material_override = inox
	var pico := Greybox.box(root, "Pico", Vector3(-0.08, 1.31, -0.15), Vector3(0.025, 0.025, 0.2), Greybox.INOX, false)
	pico.material_override = inox
	Greybox.box(root, "Escurridor", Vector3(0.26, 0.97, 0.0), Vector3(0.18, 0.08, 0.5), Greybox.INOX, false).material_override = inox
	var drop := Greybox.box(root, "Gota", Vector3(-0.08, 1.25, -0.06), Vector3(0.012, 0.02, 0.012), Color(0.7, 0.8, 0.9), false, 0.6)
	var dd := _Drip.new()
	dd.name = "Goteo"
	dd.drop = drop
	root.add_child(dd)
	_anchor(root, Vector3(0, 0, 0.8), 180.0)
	return root


class _Drip extends Node:
	var drop: MeshInstance3D = null
	var _y: float = 0.0

	func _process(delta: float) -> void:
		if drop == null:
			return
		_y += delta * (0.9 + _y * 3.0)
		if _y > 0.32:
			_y = 0.0 if randf() < 0.5 else -randf_range(0.2, 1.5)  # pausa irregular
		drop.visible = _y >= 0.0
		drop.position.y = 1.25 - maxf(_y, 0.0)


## Carro bandejero de acero inox con ruedas (cafetería del -1).
static func tray_rack(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var inox := Greybox.inox()
	for sx in [-0.3, 0.3]:
		for sz in [-0.22, 0.22]:
			Greybox.box(root, "Poste%d%d" % [int(sx * 10), int(sz * 10)], Vector3(sx, 0.9, sz), Vector3(0.025, 1.7, 0.025), Greybox.INOX, false).material_override = inox
	for k in 10:
		Greybox.box(root, "Riel%d" % k, Vector3(0, 0.3 + k * 0.14, 0), Vector3(0.62, 0.01, 0.46), Greybox.INOX, false).material_override = inox
	Greybox.invisible_box(root, "Col", Vector3(0, 0.9, 0), Vector3(0.64, 1.8, 0.48))
	return root


## Banqueta baja de espera de madera clara (tópico del piso 1, D6).
static func waiting_bench(parent: Node, p_name: String, pos: Vector3, yaw_deg: float, length: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var seat := Greybox.box(root, "Asiento", Vector3(0, 0.43, 0), Vector3(length, 0.05, 0.4), Color(0.78, 0.66, 0.5))
	seat.material_override = Greybox.surf("roble")
	for sx in [-length * 0.5 + 0.06, length * 0.5 - 0.06]:
		Greybox.box(root, "Pata%d" % int(sx * 100), Vector3(sx, 0.2, 0), Vector3(0.05, 0.4, 0.36), Color(0.7, 0.58, 0.42), false).material_override = Greybox.surf("roble")
	return root


## Cartel amarillo de piso mojado (caballete).
static func wet_sign(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	for side in [-1.0, 1.0]:
		var p := Greybox.box(root, "Hoja%d" % int(side), Vector3(0, 0.32, side * 0.1), Vector3(0.3, 0.62, 0.012), Color(0.92, 0.75, 0.08), false)
		p.rotation_degrees.x = side * 14.0
		var l := Greybox.label(p, "", Vector3(0, 0.05, side * 0.008), 0.045, Color(0.08, 0.06, 0.02), 0.0 if side > 0 else PI)
		l.text = root.tr("Q5_PISO_MOJADO") if root.is_inside_tree() else TranslationServer.translate("Q5_PISO_MOJADO")
		l.outline_size = 0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 0.26 / l.pixel_size
	return root


## Cartón mojado tirado en el piso.
static func cardboard(parent: Node, p_name: String, pos: Vector3, yaw_deg: float, size: Vector2 = Vector2(0.9, 0.6)) -> MeshInstance3D:
	var c := Greybox.box(parent, p_name, pos + Vector3(0, 0.006, 0), Vector3(size.x, 0.008, size.y), Color(0.42, 0.33, 0.22), false)
	c.material_override = Greybox.material(Color(0.32, 0.25, 0.17), 0.0, 0.35, 0.0)
	c.rotation_degrees.y = yaw_deg
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return c


## Huellas de barro (pares) de `from` a `to`: siempre en ese sentido (en el ingreso, bajan y no suben).
static func footprints(parent: Node, p_name: String, from: Vector3, to: Vector3, step: float = 0.7, y_of: Callable = Callable()) -> void:
	var dir := to - from
	dir.y = 0.0
	var n := int(dir.length() / step)
	if n <= 0:
		return
	var yaw := atan2(dir.x, dir.z)
	var side := Vector3(dir.z, 0, -dir.x).normalized() * 0.11
	var mat := Greybox.material(Color(0.07, 0.055, 0.04, 0.75), 0.0, 0.5)
	for i in n:
		var p := from + dir.normalized() * (i * step) + (side if i % 2 == 0 else -side)
		if y_of.is_valid():
			p.y = float(y_of.call(p))
		var f := Greybox.box(parent, "%s%d" % [p_name, i], p + Vector3(0, 0.008, 0), Vector3(0.1, 0.004, 0.26), Color(0.07, 0.055, 0.04, 0.75), false)
		f.material_override = mat
		f.rotation.y = yaw
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Gabinete contra incendios (rojo apagado de seguridad, vidrio) con su placa.
static func fire_cabinet(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	Greybox.box(root, "Caja", Vector3.ZERO, Vector3(0.75, 0.9, 0.2), Greybox.ROJO_SEGURIDAD, false)
	Greybox.box(root, "Vidrio", Vector3(0, 0, 0.102), Vector3(0.6, 0.75, 0.004), Color(0.6, 0.7, 0.72, 0.35), false)
	Greybox.cylinder(root, "Manguera", Vector3(0, 0, 0.0), 0.25, 0.12, Color(0.55, 0.12, 0.1), false).rotation_degrees.x = 90.0
	return root


## Hojas A4 pegadas con cinta (texto ilegible), un poco torcidas.
static func a4_sheets(parent: Node, p_name: String, pos: Vector3, yaw_deg: float, count: int = 3, seed_v: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var p := Greybox.box(parent, "%s%d" % [p_name, i], pos + Vector3.ZERO, Vector3(0.21, 0.297, 0.002), Color(0.9, 0.9, 0.87), false)
		p.rotation_degrees = Vector3(0, yaw_deg, rng.randf_range(-6.0, 6.0))
		var off := Basis.from_euler(Vector3(0, deg_to_rad(yaw_deg), 0)) * Vector3(i * 0.32 + rng.randf_range(-0.05, 0.05), rng.randf_range(-0.12, 0.12), 0)
		p.position += off
		for k in 6:
			Greybox.box(p, "Linea%d" % k, Vector3(0, 0.1 - k * 0.035, 0.0015), Vector3(rng.randf_range(0.08, 0.17), 0.006, 0.001), Color(0.25, 0.25, 0.28), false)
		Greybox.box(p, "Cinta", Vector3(0, 0.145, 0.0016), Vector3(0.07, 0.025, 0.001), Color(0.85, 0.82, 0.6, 0.8), false)


## Decoración de Halloween olvidada: murciélagos de papel negro colgando (giran despacio).
static func bats(parent: Node, p_name: String, center: Vector3, spread: Vector2, count: int, ceiling_y: float, seed_v: int = 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var spin := _Spin.new()
	spin.name = p_name + "_Giro"
	parent.add_child(spin)
	for i in count:
		var hang := rng.randf_range(0.3, 0.9)
		var p := center + Vector3(rng.randf_range(-0.5, 0.5) * spread.x, 0, rng.randf_range(-0.5, 0.5) * spread.y)
		p.y = ceiling_y - hang
		var piv := Node3D.new()
		piv.name = "%s%d" % [p_name, i]
		piv.position = p
		parent.add_child(piv)
		Greybox.box(piv, "Hilo", Vector3(0, hang * 0.5, 0), Vector3(0.004, hang, 0.004), Color(0.6, 0.6, 0.6), false)
		var body := Greybox.box(piv, "Cuerpo", Vector3.ZERO, Vector3(0.06, 0.07, 0.01), Greybox.NEGRO, false)
		for s in [-1.0, 1.0]:
			var w := Greybox.box(body, "Ala%d" % int(s), Vector3(s * 0.11, 0.01, 0), Vector3(0.18, 0.06, 0.004), Greybox.NEGRO, false)
			w.rotation_degrees.z = s * 15.0
		spin.targets.append(piv)


## Figura colgante de bruja (silueta de papel oscuro con sombrero en punta).
static func witch(parent: Node, p_name: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	parent.add_child(root)
	Greybox.box(root, "Hilo", Vector3(0, 0.45, 0), Vector3(0.004, 0.9, 0.004), Color(0.6, 0.6, 0.6), false)
	Greybox.box(root, "Vestido", Vector3(0, -0.35, 0), Vector3(0.36, 0.6, 0.02), Color(0.1, 0.05, 0.12), false)
	Greybox.box(root, "Cara", Vector3(0, 0.04, 0), Vector3(0.14, 0.16, 0.02), Color(0.3, 0.42, 0.18), false)
	var hat := Greybox.cylinder(root, "Sombrero", Vector3(0, 0.25, 0), 0.12, 0.3, Greybox.NEGRO, false, 0.9, 0.0, 0.0)
	hat.scale = Vector3(1, 1, 0.15)
	Greybox.box(root, "Ala", Vector3(0, 0.11, 0), Vector3(0.36, 0.02, 0.05), Greybox.NEGRO, false)
	var spin := _Spin.new()
	spin.name = "Giro"
	spin.targets.append(root)
	spin.speed = 0.25
	root.add_child(spin)
	return root


class _Spin extends Node:
	var targets: Array[Node3D] = []
	var speed: float = 0.15
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta * speed * (1.0 + 2.0 * Dread.level())
		for i in targets.size():
			if is_instance_valid(targets[i]):
				targets[i].rotation.y = sin(_t + i * 1.7) * 1.2 + _t * 0.3


## Puerta de baño con pictograma de línea negra grande (círculo o triángulo) sobre la hoja (vista hacia +Z local).
static func pictogram(parent: Node, pos: Vector3, yaw_deg: float, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Pictograma_" + kind
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var ink := Color(0.05, 0.05, 0.05)
	if kind == "circulo":
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.15
		tm.outer_radius = 0.17
		tm.rings = 24
		tm.ring_segments = 6
		t.mesh = tm
		t.material_override = Greybox.material(ink)
		t.rotation_degrees.x = 90.0
		t.name = "Circulo"
		root.add_child(t)
	elif kind == "triangulo":
		for k in 3:
			var a := deg_to_rad(90.0 + k * 120.0)
			var b := deg_to_rad(90.0 + (k + 1) * 120.0)
			var pa := Vector3(cos(a), sin(a), 0) * 0.22
			var pb := Vector3(cos(b), sin(b), 0) * 0.22
			var seg := Greybox.box(root, "Lado%d" % k, (pa + pb) * 0.5, Vector3(pa.distance_to(pb), 0.02, 0.004), ink, false)
			seg.rotation.z = atan2(pb.y - pa.y, pb.x - pa.x)
	elif kind == "accesible":
		# v0.3.1 pisos: pictograma de línea genérico de accesibilidad (rueda, cabeza, torso y brazo).
		var w := MeshInstance3D.new()
		var wm := TorusMesh.new()
		wm.inner_radius = 0.1
		wm.outer_radius = 0.12
		wm.rings = 20
		wm.ring_segments = 6
		w.mesh = wm
		w.material_override = Greybox.material(ink)
		w.rotation_degrees.x = 90.0
		w.position = Vector3(-0.02, -0.08, 0)
		w.name = "Rueda"
		root.add_child(w)
		Greybox.cylinder(root, "Cabeza", Vector3(0.0, 0.2, 0), 0.035, 0.004, ink).rotation_degrees.x = 90.0
		Greybox.box(root, "Torso", Vector3(0.0, 0.07, 0), Vector3(0.02, 0.18, 0.004), ink, false)
		Greybox.box(root, "Brazo", Vector3(0.06, 0.06, 0), Vector3(0.12, 0.02, 0.004), ink, false)
		Greybox.box(root, "Pierna", Vector3(0.08, -0.03, 0), Vector3(0.14, 0.02, 0.004), ink, false)
	return root


## Árbol de hoja fina (tipa/jacarandá) en la vereda: tronco y copa de planos cruzados semitransparentes.
static func tree(parent: Node, p_name: String, pos: Vector3, h: float = 5.0) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	parent.add_child(root)
	Greybox.cylinder(root, "Tronco", Vector3(0, h * 0.35, 0), 0.12, h * 0.7, Color(0.18, 0.14, 0.1), true, 0.9, 0.0, 0.08)
	var leaf := Greybox.material(Color(0.12, 0.2, 0.1, 0.82), 0.0, 0.9)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 4:
		var c := Greybox.box(root, "Copa%d" % k, Vector3(0, h * 0.78 + (k % 2) * 0.3, 0), Vector3(3.6 - k * 0.4, 1.2, 0.02), Color(0.12, 0.2, 0.1, 0.82), false)
		c.material_override = leaf
		c.rotation_degrees.y = k * 45.0
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Jardinera de concreto con plantas (cordyline, hiedra).
static func planter(parent: Node, p_name: String, pos: Vector3, size: Vector3, collide: bool = true) -> MeshInstance3D:
	var p := Greybox.sbox(parent, p_name, pos, size, "concreto", collide)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_name)
	var n := maxi(2, int(size.x * size.z * 2.0))
	for i in mini(n, 8):
		var col := Color(0.15, 0.28, 0.12) if i % 3 != 0 else Color(0.55, 0.22, 0.12)
		var hh := rng.randf_range(0.3, 0.9)
		var leaf := Greybox.box(p, "Planta%d" % i, Vector3(rng.randf_range(-0.4, 0.4) * size.x, size.y * 0.5 + hh * 0.5, rng.randf_range(-0.4, 0.4) * size.z), Vector3(0.35, hh, 0.35), col, false)
		leaf.rotation_degrees.y = rng.randf_range(0.0, 90.0)
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Franja de vidrio esmerilado (film de 1,0 a 1,6 m) sobre un vidrio que mira a lo largo de X (o de Z si along_z).
static func frosted_band(parent: Node, p_name: String, center: Vector3, length: float, along_z: bool = false) -> MeshInstance3D:
	var size := Vector3(0.012, 0.6, length) if along_z else Vector3(length, 0.6, 0.012)
	var b := Greybox.box(parent, p_name, Vector3(center.x, 1.3, center.z), size, Color(0.86, 0.9, 0.9, 0.6), false)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return b


## Persiana enrollable blanca a una altura (0 = arriba del todo, 1 = abajo del todo) delante de una ventana.
static func blind(parent: Node, p_name: String, top: Vector3, width: float, drop: float, yaw_deg: float) -> MeshInstance3D:
	var h := clampf(drop, 0.05, 1.0) * 1.6
	var b := Greybox.box(parent, p_name, top + Vector3(0, -h * 0.5, 0), Vector3(width, h, 0.01), Color(0.9, 0.9, 0.88), false)
	b.material_override = Greybox.surf("persiana")
	b.rotation_degrees.y = yaw_deg
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(b, "Tubo", Vector3(0, h * 0.5 + 0.03, 0), Vector3(width + 0.04, 0.06, 0.06), Color(0.85, 0.85, 0.83), false)
	Greybox.box(b, "Barra", Vector3(0, -h * 0.5, 0.0), Vector3(width, 0.025, 0.02), Color(0.8, 0.8, 0.78), false)
	return b


## Bulto con headset que no se mueve, sentado en la banqueta de espera (T1); en T2+ la banqueta queda vacía.
static func waiting_figure(parent: Node, p_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var dark := Color(0.035, 0.035, 0.04)
	Greybox.box(root, "Torso", Vector3(0, 0.78, 0), Vector3(0.4, 0.62, 0.28), dark, false).rotation_degrees.x = 12.0
	Greybox.box(root, "Cabeza", Vector3(0, 1.18, 0.08), Vector3(0.2, 0.24, 0.22), dark, false).rotation_degrees.x = 35.0
	Greybox.box(root, "Diadema", Vector3(0, 1.3, 0.06), Vector3(0.24, 0.03, 0.04), Greybox.GRIS_OSCURO, false)
	Greybox.box(root, "Piernas", Vector3(0, 0.47, 0.2), Vector3(0.36, 0.14, 0.42), dark, false)
	return root


# --- Entorno este (v0.3.1 Q5, ref. del entorno real, genérico): autopista elevada que cruza la avenida,
# tráfico continuo, torres de iluminación altas, torres de alta tensión y cerros pelados al fondo. Sin textos,
# números ni marcas. Todo en 3 MultiMesh (estructura, puntos de luz y tráfico): cuesta 3 llamadas de dibujo.
## `x_axis`: x del eje de la autopista (corre a lo largo de z). `ground_y`: nivel de la calle bajo el piso actual.
## `cross_z`: z de la avenida que la autopista cruza por encima (el puente). `z0..z1`: tramo visible.
static func entorno_este(parent: Node, ground_y: float, x_axis: float, cross_z: float, z0: float, z1: float, hills_x: float = 520.0) -> Node3D:
	var root := Node3D.new()
	root.name = "EntornoEste"
	parent.add_child(root)
	var deck_y := ground_y + 6.8
	var half := 13.0
	var solid: Array = []  # [Transform3D, Color]
	var dots: Array = []
	var gris := Color(0.46, 0.46, 0.44)
	var oscuro := Color(0.12, 0.12, 0.13)
	var amarillo := Color(0.78, 0.66, 0.12)
	var z := z0
	while z < z1:
		var seg := minf(20.0, z1 - z)
		var zc := z + seg * 0.5
		solid.append([Transform3D(Basis.from_scale(Vector3(half * 2.0, 0.9, seg)), Vector3(x_axis, deck_y - 0.45, zc)), gris])
		for sx in [-1.0, 1.0]:
			solid.append([Transform3D(Basis.from_scale(Vector3(0.35, 0.8, seg)), Vector3(x_axis + sx * (half - 0.2), deck_y + 0.4, zc)), Color(0.5, 0.5, 0.48)])
			# Baranda peatonal amarilla de malla (solo cerca del puente sobre la avenida).
			if absf(zc - cross_z) < 45.0:
				dots.append([Transform3D(Basis.from_scale(Vector3(0.06, 1.1, seg)), Vector3(x_axis + sx * (half + 1.4), deck_y + 0.55, zc)), amarillo * 0.55])
				solid.append([Transform3D(Basis.from_scale(Vector3(2.8, 0.15, seg)), Vector3(x_axis + sx * (half + 0.9), deck_y - 0.1, zc)), gris])
		solid.append([Transform3D(Basis.from_scale(Vector3(0.5, 0.9, seg)), Vector3(x_axis, deck_y + 0.45, zc)), Color(0.45, 0.45, 0.43)])  # separador central
		# Ojos de gato y balizas del borde: la silueta del tablero se lee de noche.
		for sx in [-1.0, 1.0]:
			dots.append([Transform3D(Basis.from_scale(Vector3(0.12, 0.12, 0.12)), Vector3(x_axis + sx * (half - 0.05), deck_y + 0.6, zc)), Color(0.85, 0.78, 0.45)])
			dots.append([Transform3D(Basis.from_scale(Vector3(0.1, 0.04, seg)), Vector3(x_axis + sx * (half + 0.02), deck_y - 0.85, zc)), Color(0.16, 0.15, 0.13)])
		if absf(zc - cross_z) > 14.0:
			for px in [-7.0, 7.0]:
				solid.append([Transform3D(Basis.from_scale(Vector3(1.6, deck_y - ground_y - 0.9, 1.6)), Vector3(x_axis + px, (deck_y + ground_y - 0.9) * 0.5, z)), oscuro])
		z += seg
	# Escalera peatonal que baja del puente a la avenida.
	for k in 14:
		solid.append([Transform3D(Basis.from_scale(Vector3(1.6, 0.18, 0.4)), Vector3(x_axis - half - 2.4, ground_y + k * 0.48, cross_z + 18.0 + k * 0.4)), gris])
	# Torres de iluminación altas (~22 m) con corona de luminarias.
	for i in 4:
		var mz := cross_z - 60.0 + i * 45.0
		var mx := x_axis + (half + 6.0) * (1.0 if i % 2 == 0 else -1.0)
		solid.append([Transform3D(Basis.from_scale(Vector3(0.6, 22.0, 0.6)), Vector3(mx, ground_y + 11.0, mz)), oscuro])
		solid.append([Transform3D(Basis.from_scale(Vector3(3.2, 0.5, 3.2)), Vector3(mx, ground_y + 22.2, mz)), oscuro])
		for k in 4:
			var a := k * PI * 0.5
			dots.append([Transform3D(Basis.from_scale(Vector3(0.7, 0.25, 0.7)), Vector3(mx + cos(a) * 1.2, ground_y + 21.9, mz + sin(a) * 1.2)), Color(0.92, 0.95, 1.0)])
	# Postes de alumbrado de doble brazo sobre la autopista (sodio viejo y LED frío mezclados).
	var zz := z0 + 10.0
	var n := 0
	while zz < z1:
		solid.append([Transform3D(Basis.from_scale(Vector3(0.25, 9.0, 0.25)), Vector3(x_axis, deck_y + 4.5, zz)), oscuro])
		solid.append([Transform3D(Basis.from_scale(Vector3(7.0, 0.15, 0.2)), Vector3(x_axis, deck_y + 9.0, zz)), oscuro])
		for sx in [-3.4, 3.4]:
			dots.append([Transform3D(Basis.from_scale(Vector3(0.8, 0.15, 0.35)), Vector3(x_axis + sx, deck_y + 8.85, zz)), Color(1.0, 0.62, 0.3) if n % 3 == 0 else Color(0.85, 0.92, 1.0)])
		zz += 32.0
		n += 1
	# Torres de alta tensión de acero (celosía en silueta) con cables combados, del lado de afuera.
	var px := x_axis + half + 22.0
	var prev := Vector3.INF
	var tz := z0 + 5.0
	while tz < z1:
		var base := Vector3(px, ground_y, tz)
		for lx in [-1.6, 1.6]:
			for lz in [-1.6, 1.6]:
				var leg := Transform3D(Basis.from_euler(Vector3(lz * -0.05, 0, lx * 0.05)) * Basis.from_scale(Vector3(0.18, 30.0, 0.18)), base + Vector3(lx * 0.6, 15.0, lz * 0.6))
				solid.append([leg, oscuro])
		for k in 3:
			solid.append([Transform3D(Basis.from_scale(Vector3(9.0 - k * 2.0, 0.25, 0.25)), base + Vector3(0, 22.0 + k * 3.5, 0)), oscuro])
		dots.append([Transform3D(Basis.from_scale(Vector3(0.45, 0.45, 0.45)), base + Vector3(0, 32.0, 0)), Color(1.0, 0.12, 0.08)])
		if prev != Vector3.INF:
			for k in 3:
				for sx in [-1.0, 1.0]:
					var a := prev + Vector3(sx * (4.5 - k), 22.0 + k * 3.5, 0)
					var b := base + Vector3(sx * (4.5 - k), 22.0 + k * 3.5, 0)
					for s in 4:
						var t0 := s / 4.0
						var t1 := (s + 1) / 4.0
						var p0 := a.lerp(b, t0) + Vector3(0, -2.2 * 4.0 * t0 * (1.0 - t0), 0)
						var p1 := a.lerp(b, t1) + Vector3(0, -2.2 * 4.0 * t1 * (1.0 - t1), 0)
						var mid := (p0 + p1) * 0.5
						var dir := p1 - p0
						var bs := Basis.looking_at(dir.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.05, 0.05, dir.length()))
						solid.append([Transform3D(bs, mid), Color(0.05, 0.05, 0.05)])
		prev = base
		tz += 70.0
	# Cerros pelados al fondo (silueta marrón gris; con la garúa casi se pierden).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	for i in 9:
		var hz := lerpf(cross_z - 420.0, cross_z + 420.0, i / 8.0) + rng.randf_range(-40.0, 40.0)
		var hh := rng.randf_range(70.0, 160.0)
		var hw := rng.randf_range(160.0, 260.0)
		var b := Basis.from_euler(Vector3(0, rng.randf_range(-0.4, 0.4), deg_to_rad(rng.randf_range(38.0, 50.0)))) * Basis.from_scale(Vector3(hh, hh, hw))
		solid.append([Transform3D(b, Vector3(hills_x + rng.randf_range(0.0, 120.0), ground_y - 10.0, hz)), Color(0.16, 0.14, 0.13).lerp(Color(0.2, 0.2, 0.21), rng.randf())])
	root.add_child(_mm_node("Estructura", solid, false))
	# Bajo el puente, el sodio de la avenida lava el concreto (una sola luz; el presupuesto de liviano la apaga lejos).
	var sodio := Greybox.light(root, Vector3(x_axis, ground_y + 4.0, cross_z), Color(1.0, 0.6, 0.3), 1.4, 28.0)
	sodio.name = "SodioPuente"
	root.add_child(_mm_node("Luces", dots, true))
	var traf := _Traffic.new()
	traf.name = "Trafico"
	traf.setup(x_axis, deck_y, z0, z1)
	root.add_child(traf)
	return root


static func _mm_node(p_name: String, items: Array, unshaded: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = p_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 1.0
	mmi.material_override = m
	return mmi


## Ríos de faros: blancos hacia +z, rojos hacia -z; camiones (luces altas y más lentos) cada tanto. 15 Hz.
class _Traffic extends MultiMeshInstance3D:
	var _x: float = 0.0
	var _y: float = 0.0
	var _z0: float = 0.0
	var _z1: float = 0.0
	var _cars: Array = []  # [lane_x, z, speed, alto]
	var _t: float = 0.0

	func setup(x_axis: float, deck_y: float, z0: float, z1: float) -> void:
		_x = x_axis
		_y = deck_y
		_z0 = z0
		_z1 = z1
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 64:
			var dir := 1.0 if i % 2 == 0 else -1.0
			var lane := rng.randi_range(0, 4)
			var truck := rng.randf() < 0.18
			_cars.append([x_axis + dir * (2.0 + lane * 2.2), rng.randf_range(z0, z1), dir * (rng.randf_range(16.0, 26.0) if not truck else rng.randf_range(11.0, 15.0)), truck])
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = true
		m.mesh = BoxMesh.new()
		m.instance_count = _cars.size() * 2
		multimesh = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		material_override = mat
		_update()

	func _process(delta: float) -> void:
		_t += delta
		if _t < 1.0 / 15.0:
			return
		for c in _cars:
			c[1] = float(c[1]) + float(c[2]) * _t
			if c[1] > _z1:
				c[1] = _z0
			elif c[1] < _z0:
				c[1] = _z1
		_t = 0.0
		_update()

	func _update() -> void:
		for i in _cars.size():
			var c: Array = _cars[i]
			var up := 1.0 if float(c[2]) > 0.0 else -1.0
			var hy := _y + (1.6 if bool(c[3]) else 0.7)
			var col := Color(1.0, 0.95, 0.82) if up > 0.0 else Color(0.95, 0.08, 0.05)
			for k in 2:
				var off := -0.7 if k == 0 else 0.7
				multimesh.set_instance_transform(i * 2 + k, Transform3D(Basis.from_scale(Vector3(0.35, 0.2, 0.1)), Vector3(float(c[0]) + off, hy, float(c[1]))))
				multimesh.set_instance_color(i * 2 + k, col)

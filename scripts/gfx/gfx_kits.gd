class_name GfxKits
extends RefCounted
## v0.3.2 gfx · Piezas de la capa de detalle (GfxDetail) que se repiten: sillas de trabajo, teclado, lo que hay
## encima de cada escritorio y la silueta sentada. Todo son cajas y cilindros en un GfxMesh: sin colisión, sin
## texturas propias (los materiales son los de Greybox y llevan el relieve de GfxMaterials) y sin textos.
##
## Sillas: NO son piezas nuevas. Se cambia la MALLA de los nodos «Silla», «Respaldo» y «Estrella» que ya arma
## Greybox.cubicle (mismo nodo, mismo material, mismo sitio): así siguen a quien las mueve o las esconde (la silla
## girada del puesto abandonado, la que se oculta en una muerte) y no cuestan ni un dibujo más.

static var _seat: ArrayMesh = null
static var _back: ArrayMesh = null
static var _star: ArrayMesh = null
static var _mug: ArrayMesh = null


## Asiento (origen = centro de la caja original 0,48 × 0,06 × 0,46; el frente mira a −z): cojín con el canto
## delantero caído, mecanismo, palanca, apoyabrazos y la escuadra que sube al respaldo.
static func chair_seat() -> ArrayMesh:
	if _seat != null:
		return _seat
	var k := GfxMesh.new()
	k.cube(null, Vector3(0, 0.0, 0.012), Vector3(0.47, 0.054, 0.415))
	k.box(null, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16.0)), Vector3(0, -0.012, -0.207)), Vector3(0.45, 0.046, 0.066))
	k.cube(null, Vector3(0, 0.031, 0.022), Vector3(0.40, 0.012, 0.35))
	k.cube(null, Vector3(0, -0.05, 0.03), Vector3(0.2, 0.046, 0.24))
	k.cube(null, Vector3(0.17, -0.062, -0.04), Vector3(0.15, 0.012, 0.016))
	k.cube(null, Vector3(0, -0.04, 0.07), Vector3(0.56, 0.022, 0.06))
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.277
		k.cube(null, Vector3(x, 0.072, 0.07), Vector3(0.026, 0.245, 0.05))
		k.cube(null, Vector3(x, 0.203, 0.03), Vector3(0.064, 0.028, 0.25))
	k.cube(null, Vector3(0, -0.047, 0.2), Vector3(0.07, 0.03, 0.17))
	_seat = k.commit()
	return _seat


## Respaldo (origen = centro de la caja original 0,44 × 0,55 × 0,04): tres paños —el central y dos alas hacia
## delante—, remate, apoyo lumbar y la columna que baja hasta la escuadra del asiento.
static func chair_back() -> ArrayMesh:
	if _back != null:
		return _back
	var k := GfxMesh.new()
	k.cube(null, Vector3(0, 0, 0.004), Vector3(0.2, 0.53, 0.018))
	for sx in [-1.0, 1.0]:
		var s: float = sx
		k.box(null, Transform3D(Basis(Vector3.UP, s * 0.28), Vector3(s * 0.16, 0, -0.013)), Vector3(0.125, 0.53, 0.018))
	k.cube(null, Vector3(0, 0.272, 0.006), Vector3(0.3, 0.03, 0.03))
	k.cube(null, Vector3(0, -0.13, 0.022), Vector3(0.26, 0.09, 0.02))
	k.cube(null, Vector3(0, -0.24, 0.05), Vector3(0.06, 0.3, 0.022))
	_back = k.commit()
	return _back


## Taza (origen = centro de la caja original de 10 cm; la base de la caja es la mesa): loza blanca con asa y el café
## adentro. Es la taza de C-13, la que todavía humea: el vapor sigue colgando del mismo nodo.
static func mug() -> ArrayMesh:
	if _mug != null:
		return _mug
	var k := GfxMesh.new()
	var loza := Greybox.material(Color(0.9, 0.9, 0.87), 0.0, 0.3)   # lisa y brillante: el pase de materiales no la toca
	var cafe := Greybox.material(Color(0.09, 0.055, 0.035), 0.0, 0.35)
	k.cyl(loza, Transform3D(Basis.IDENTITY, Vector3(0, -0.004, 0)), 0.041, 0.092, 14)
	k.cyl(cafe, Transform3D(Basis.IDENTITY, Vector3(0, 0.0425, 0)), 0.035, 0.002, 14)
	# asa: tres tramos
	k.cube(loza, Vector3(0.052, 0.018, 0), Vector3(0.026, 0.011, 0.012))
	k.cube(loza, Vector3(0.052, -0.028, 0), Vector3(0.026, 0.011, 0.012))
	k.cube(loza, Vector3(0.063, -0.005, 0), Vector3(0.011, 0.057, 0.012))
	_mug = k.commit()
	return _mug


## Base (origen = centro del disco original, a 3 cm del suelo): cubo, funda del pistón, cinco brazos y sus ruedas.
static func chair_star() -> ArrayMesh:
	if _star != null:
		return _star
	var k := GfxMesh.new()
	k.cyl(null, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), 0.045, 0.06, 8)
	k.cyl(null, Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0)), 0.032, 0.16, 8)
	for i in 5:
		var b := Basis(Vector3.UP, TAU * float(i) / 5.0 + 0.31)
		k.box(null, Transform3D(b, b * Vector3(0.145, 0.022, 0)), Vector3(0.25, 0.022, 0.04))
		k.cyl(null, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), b * Vector3(0.265, -0.003, 0)), 0.027, 0.045, 6)
	_star = k.commit()
	return _star


## Teclado sobre el tablero (marco del cubículo). Alta: filas de teclas, bloque de flechas y teclado numérico.
static func keyboard(kit: GfxMesh, full: bool) -> void:
	var base := GfxDetail.m_black()
	var keys := GfxDetail.m_keys()
	kit.cube(base, Vector3(0, 0.757, -0.14), Vector3(0.45, 0.014, 0.152))
	if not full:
		kit.cube(keys, Vector3(0, 0.766, -0.142), Vector3(0.41, 0.004, 0.118))
		return
	for r in 6:
		var z := -0.197 + 0.0215 * r
		if r == 5:
			kit.cube(keys, Vector3(-0.165, 0.7665, z), Vector3(0.06, 0.005, 0.017))
			kit.cube(keys, Vector3(-0.055, 0.7665, z), Vector3(0.125, 0.005, 0.017))   # barra espaciadora
			kit.cube(keys, Vector3(0.048, 0.7665, z), Vector3(0.062, 0.005, 0.017))
		else:
			kit.cube(keys, Vector3(-0.058, 0.7665, z), Vector3(0.274, 0.005, 0.017 if r > 0 else 0.012))
	kit.cube(keys, Vector3(0.112, 0.7665, -0.165), Vector3(0.05, 0.005, 0.06))        # inicio / fin / suprimir
	kit.cube(keys, Vector3(0.112, 0.7665, -0.1), Vector3(0.05, 0.005, 0.036))         # flechas
	kit.cube(keys, Vector3(0.182, 0.7665, -0.14), Vector3(0.066, 0.005, 0.105))       # numérico


## Lo que hay encima del escritorio, en cuatro versiones (marco del cubículo; el tablero queda a y = 0,75).
static func clutter(v: int) -> GfxMesh:
	var k := GfxMesh.new()
	var dark := GfxDetail.m_keys()
	var black := GfxDetail.m_black()
	var paper := GfxDetail.m_paper()
	match v:
		0:  # bandeja de papeles y taza
			k.cube(dark, Vector3(-0.52, 0.76, -0.3), Vector3(0.25, 0.02, 0.33))
			for sx in [-1.0, 1.0]:
				k.cube(dark, Vector3(-0.52 + sx * 0.121, 0.782, -0.3), Vector3(0.008, 0.044, 0.33))
			k.cube(dark, Vector3(-0.52, 0.782, -0.461), Vector3(0.25, 0.044, 0.008))
			k.box(paper, Transform3D(Basis(Vector3.UP, 0.05), Vector3(-0.52, 0.776, -0.3)), Vector3(0.21, 0.012, 0.297))
			k.box(paper, Transform3D(Basis(Vector3.UP, -0.2), Vector3(-0.5, 0.784, -0.29)), Vector3(0.21, 0.002, 0.297))
			var mug := Greybox.material(Color(0.62, 0.16, 0.12), 0.0, 0.35)
			k.cyl(mug, Transform3D(Basis.IDENTITY, Vector3(0.6, 0.797, -0.3)), 0.04, 0.094, 10)
			k.cyl(black, Transform3D(Basis.IDENTITY, Vector3(0.6, 0.8425, -0.3)), 0.033, 0.004, 10)
			k.cube(mug, Vector3(0.652, 0.8, -0.3), Vector3(0.024, 0.05, 0.012))
		1:  # cuaderno, lapicero y notas adhesivas en el divisor
			var cover := Greybox.material(Color(0.1, 0.16, 0.26), 0.0, 0.6)
			var nb := Transform3D(Basis(Vector3.UP, 0.22), Vector3(-0.5, 0.758, -0.2))
			k.box(cover, nb, Vector3(0.16, 0.016, 0.22))
			k.box(paper, nb * Transform3D(Basis.IDENTITY, Vector3(0.003, 0.001, 0)), Vector3(0.158, 0.012, 0.214))
			k.box(GfxDetail.m_chrome(), nb * Transform3D(Basis.IDENTITY, Vector3(-0.078, 0.004, 0)), Vector3(0.01, 0.02, 0.2))
			k.box(Greybox.material(Color(0.1, 0.2, 0.55), 0.0, 0.4), nb * Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.02, 0.012, 0.01)), Vector3(0.009, 0.009, 0.14))
			k.cyl(black, Transform3D(Basis.IDENTITY, Vector3(-0.63, 0.8, -0.43)), 0.036, 0.1, 10)
			var pens: Array = [Color(0.1, 0.2, 0.55), Color(0.6, 0.1, 0.1), Color(0.05, 0.05, 0.05), Color(0.85, 0.75, 0.2)]
			for i in pens.size():
				var a := float(i) * 1.7
				k.box(Greybox.material(pens[i], 0.0, 0.4), Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.2), Vector3(-0.63 + 0.014 * cos(a * 2.0), 0.86, -0.43 + 0.014 * sin(a * 2.0))), Vector3(0.007, 0.14, 0.007))
			var notes: Array = [[Color(0.86, 0.78, 0.25), Vector3(-0.56, 0.97, -0.5698), 0.06], [Color(0.86, 0.42, 0.56), Vector3(-0.47, 0.955, -0.5698), -0.09],
				[Color(0.5, 0.8, 0.42), Vector3(0.55, 0.98, -0.5698), 0.04], [Color(0.86, 0.78, 0.25), Vector3(0.63, 0.94, -0.5698), -0.05]]
			for nt in notes:
				k.box(Greybox.material(nt[0], 0.0, 0.9), Transform3D(Basis(Vector3(0, 0, 1), float(nt[2])), nt[1]), Vector3(0.076, 0.076, 0.002))
		2:  # teléfono de mesa y pila de carpetas
			var ph := Transform3D(Basis(Vector3.UP, -0.25) * Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(-0.5, 0.775, -0.28))
			k.box(black, ph, Vector3(0.19, 0.04, 0.21))
			k.box(dark, ph * Transform3D(Basis.IDENTITY, Vector3(-0.062, 0.03, 0)), Vector3(0.05, 0.03, 0.2))
			k.box(dark, ph * Transform3D(Basis.IDENTITY, Vector3(0.035, 0.022, 0.035)), Vector3(0.09, 0.006, 0.1))
			k.box(Greybox.material(Color(0.1, 0.2, 0.16), 0.25, 0.4), ph * Transform3D(Basis.IDENTITY, Vector3(0.035, 0.022, -0.06)), Vector3(0.09, 0.006, 0.045))
			var folders: Array = [Color(0.66, 0.54, 0.33), Color(0.16, 0.26, 0.42), Color(0.5, 0.2, 0.16), Color(0.66, 0.54, 0.33)]
			for i in folders.size():
				k.box(Greybox.material(folders[i], 0.0, 0.8), Transform3D(Basis(Vector3.UP, 0.08 * float(i) - 0.1), Vector3(0.59, 0.757 + 0.014 * i, -0.27)), Vector3(0.24, 0.013, 0.32))
			k.box(paper, Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.59, 0.814, -0.27)), Vector3(0.21, 0.002, 0.297))
		_:  # botella, caja de pañuelos y una hoja con notas
			var water := Greybox.material(Color(0.5, 0.64, 0.7), 0.0, 0.2)
			k.cyl(water, Transform3D(Basis.IDENTITY, Vector3(0.62, 0.84, -0.36)), 0.034, 0.18, 10)
			k.cyl(water, Transform3D(Basis.IDENTITY, Vector3(0.62, 0.945, -0.36)), 0.034, 0.03, 10, 0.014)
			k.cyl(GfxDetail.m_white(), Transform3D(Basis.IDENTITY, Vector3(0.62, 0.97, -0.36)), 0.015, 0.022, 8)
			var tissue := Greybox.material(Color(0.2, 0.38, 0.42), 0.0, 0.8)
			k.box(tissue, Transform3D(Basis(Vector3.UP, 0.35), Vector3(-0.52, 0.79, -0.36)), Vector3(0.23, 0.08, 0.12))
			k.box(paper, Transform3D(Basis(Vector3.UP, 0.35) * Basis(Vector3(0, 0, 1), 0.3), Vector3(-0.52, 0.845, -0.36)), Vector3(0.07, 0.05, 0.02))
			k.box(paper, Transform3D(Basis(Vector3.UP, -0.14), Vector3(-0.48, 0.7515, -0.13)), Vector3(0.21, 0.002, 0.297))
			k.box(Greybox.material(Color(0.86, 0.78, 0.25), 0.0, 0.9), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.5, 0.7535, -0.1)), Vector3(0.076, 0.002, 0.076))
	return k


## Lo que queda sobre una mesa de comedor (marco local: centro del tablero, y = 0 en su cara de arriba). Tres versiones:
## servilletero y saleros · lo mismo más una bandeja olvidada con vaso y plato · un vaso de cartón y un diario doblado.
static func table_set(v: int) -> GfxMesh:
	var k := GfxMesh.new()
	var chrome := GfxDetail.m_chrome()
	var white := GfxDetail.m_white()
	var paper := GfxDetail.m_paper()
	if v != 2:
		k.cube(GfxDetail.m_black(), Vector3(0.0, 0.05, 0.0), Vector3(0.13, 0.1, 0.05))          # servilletero
		k.cube(paper, Vector3(0.0, 0.065, 0.0), Vector3(0.11, 0.1, 0.03))
		k.cyl(white, Transform3D(Basis.IDENTITY, Vector3(0.11, 0.035, 0.02)), 0.018, 0.07, 8)   # salero
		k.cyl(chrome, Transform3D(Basis.IDENTITY, Vector3(0.11, 0.074, 0.02)), 0.017, 0.008, 8)
		k.cyl(Greybox.material(Color(0.2, 0.14, 0.1), 0.0, 0.5), Transform3D(Basis.IDENTITY, Vector3(0.15, 0.035, -0.02)), 0.018, 0.07, 8)
		k.cyl(chrome, Transform3D(Basis.IDENTITY, Vector3(0.15, 0.074, -0.02)), 0.017, 0.008, 8)
	if v == 1:
		var tray := Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.2, 0.008, 0.16))
		k.box(Greybox.material(Color(0.5, 0.2, 0.14), 0.0, 0.5), tray, Vector3(0.36, 0.016, 0.26))
		k.cyl(white, tray * Transform3D(Basis.IDENTITY, Vector3(-0.06, 0.016, 0.0)), 0.085, 0.012, 14)   # plato
		k.cyl(Greybox.material(Color(0.62, 0.66, 0.7), 0.0, 0.15), tray * Transform3D(Basis.IDENTITY, Vector3(0.11, 0.06, -0.05)), 0.03, 0.1, 10)  # vaso
		k.box(chrome, tray * Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.05, 0.012, 0.07)), Vector3(0.015, 0.004, 0.16))   # cubierto
	if v == 2:
		k.cyl(Greybox.material(Color(0.78, 0.74, 0.66), 0.0, 0.8), Transform3D(Basis.IDENTITY, Vector3(0.1, 0.05, -0.08)), 0.036, 0.1, 10, 0.042)   # vaso de cartón
		k.cyl(GfxDetail.m_black(), Transform3D(Basis.IDENTITY, Vector3(0.1, 0.103, -0.08)), 0.043, 0.006, 10)
		var np := Transform3D(Basis(Vector3.UP, -0.35), Vector3(-0.12, 0.006, 0.08))
		k.box(paper, np, Vector3(0.3, 0.012, 0.21))
		k.box(Greybox.material(Color(0.3, 0.32, 0.36), 0.0, 0.9), np * Transform3D(Basis.IDENTITY, Vector3(0, 0.0065, -0.06)), Vector3(0.26, 0.001, 0.03))
		for r in 4:
			k.box(Greybox.material(Color(0.45, 0.47, 0.5), 0.0, 0.9), np * Transform3D(Basis.IDENTITY, Vector3(-0.07 + 0.14 * (r % 2), 0.0065, -0.01 + 0.035 * float(r / 2))), Vector3(0.11, 0.001, 0.02))
	return k


## Tablero de avisos de corcho (marco local: centro del tablero, espalda en z = 0, frente +z): marco de aluminio,
## corcho, hojas de colores con renglones (formas, sin texto) y chinches. Dos versiones.
static func board(v: int) -> GfxMesh:
	var k := GfxMesh.new()
	k.cube(GfxDetail.m_alu(), Vector3(0, 0, 0.008), Vector3(1.26, 0.96, 0.016))
	k.cube(Greybox.material(Color(0.5, 0.36, 0.23), 0.0, 1.0), Vector3(0, 0, 0.014), Vector3(1.2, 0.9, 0.012))
	var white := GfxDetail.m_paper()
	var cols: Array = [white, Greybox.material(Color(0.88, 0.84, 0.52), 0.0, 0.9), Greybox.material(Color(0.86, 0.6, 0.66), 0.0, 0.9),
		Greybox.material(Color(0.66, 0.78, 0.9), 0.0, 0.9), Greybox.material(Color(0.7, 0.84, 0.68), 0.0, 0.9)]
	var ink := Greybox.material(Color(0.3, 0.32, 0.36), 0.0, 0.9)
	var head: Array = [Greybox.material(Color(0.62, 0.16, 0.14), 0.0, 0.8), Greybox.material(Color(0.15, 0.3, 0.55), 0.0, 0.8)]
	var pin: Array = [Greybox.material(Color(0.75, 0.1, 0.1), 0.0, 0.4), Greybox.material(Color(0.1, 0.25, 0.7), 0.0, 0.4), Greybox.material(Color(0.85, 0.7, 0.1), 0.0, 0.4)]
	# [x, y, ancho, alto, giro, color]
	var sheets: Array = [
		[-0.42, 0.2, 0.21, 0.297, 0.05, 0], [-0.14, 0.22, 0.21, 0.297, -0.04, 1], [0.2, 0.2, 0.297, 0.21, 0.03, 0], [0.47, 0.24, 0.148, 0.21, -0.08, 2],
		[-0.38, -0.2, 0.297, 0.21, -0.03, 3], [-0.03, -0.2, 0.21, 0.297, 0.06, 0], [0.28, -0.19, 0.21, 0.297, -0.02, 4], [0.5, -0.27, 0.1, 0.1, 0.12, 1],
	] if v == 0 else [
		[-0.4, 0.21, 0.297, 0.21, -0.03, 0], [-0.08, 0.2, 0.21, 0.297, 0.04, 3], [0.2, 0.22, 0.21, 0.297, -0.05, 0], [0.46, 0.2, 0.148, 0.21, 0.07, 4],
		[-0.44, -0.2, 0.21, 0.297, 0.03, 2], [-0.16, -0.22, 0.21, 0.297, -0.06, 0], [0.16, -0.2, 0.297, 0.21, 0.02, 1], [0.48, -0.2, 0.148, 0.21, -0.04, 0],
	]
	for i in sheets.size():
		var sh: Array = sheets[i]
		var w := float(sh[2])
		var h := float(sh[3])
		var xf := Transform3D(Basis(Vector3(0, 0, 1), float(sh[4])), Vector3(float(sh[0]), float(sh[1]), 0.0212))
		k.box(cols[int(sh[5])], xf, Vector3(w, h, 0.002))
		k.box(pin[i % pin.size()], xf * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5 - 0.018, 0.005)), Vector3(0.012, 0.012, 0.008))
		if w < 0.12:
			continue
		k.box(head[i % head.size()], xf * Transform3D(Basis.IDENTITY, Vector3(-w * 0.1, h * 0.5 - 0.05, 0.0012)), Vector3(w * 0.6, 0.014, 0.0006))
		var rows := int(floor((h - 0.11) / 0.034))
		for r in mini(rows, 5):
			var lw := w * (0.72 - 0.11 * float((r * 3 + i) % 3))
			k.box(ink, xf * Transform3D(Basis.IDENTITY, Vector3(-(w * 0.78 - lw) * 0.5, h * 0.5 - 0.09 - 0.034 * r, 0.0012)), Vector3(lw, 0.007, 0.0006))
	return k


## Color de vértice (sRGB) para las piezas siguientes de un kit con shader propio; `flag` va en UV.x.
static func _tint(k: GfxMesh, c: Color, flag: float = 0.0) -> void:
	k.color = c
	k.uv = Vector2(flag, 0.0)


## Silueta sentada tecleando (marco local: centro del busto original, mirando a −z), en UNA superficie con el
## shader gfx_silueta: el color de cada pieza va en el vértice; la ropa (UV.x = 1) toma el color de la copia.
static func bust(mat: Material) -> GfxMesh:
	var k := GfxMesh.new()
	k.with_colors = true
	var skin := Color(0.42, 0.29, 0.22)
	var hair := Color(0.035, 0.03, 0.03)
	var pants := Color(0.07, 0.075, 0.1)
	var black := Color(0.04, 0.04, 0.045)
	# torso (cadera, pecho, hombros), algo inclinado hacia el teclado
	_tint(k, Color.WHITE, 1.0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-9.0))
	k.box(mat, Transform3D(tilt, Vector3(0, -0.3, 0.02)), Vector3(0.34, 0.3, 0.21))
	k.box(mat, Transform3D(tilt, Vector3(0, -0.02, -0.02)), Vector3(0.4, 0.3, 0.23))
	k.box(mat, Transform3D(tilt, Vector3(0, 0.13, -0.045)), Vector3(0.46, 0.09, 0.2))
	# cuello y cabeza
	_tint(k, skin)
	k.cyl(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.215, -0.06)), 0.05, 0.08, 8)
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, -0.075)), Vector3(0.155, 0.19, 0.18))
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.305, -0.075)), Vector3(0.175, 0.07, 0.11))   # pómulos / orejas
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.325, -0.172)), Vector3(0.03, 0.05, 0.02))     # nariz
	_tint(k, hair)
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.405, -0.06)), Vector3(0.17, 0.07, 0.2))      # pelo arriba
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0.012)), Vector3(0.165, 0.15, 0.04))     # nuca
	# auriculares: diadema y dos copas, brazo del micrófono
	_tint(k, black)
	k.box(mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.447, -0.07)), Vector3(0.2, 0.014, 0.03))
	for sx in [-1.0, 1.0]:
		var s: float = sx
		k.box(mat, Transform3D(Basis.IDENTITY, Vector3(s * 0.098, 0.4, -0.07)), Vector3(0.012, 0.1, 0.026))
		k.cyl(mat, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(s * 0.098, 0.33, -0.07)), 0.038, 0.028, 8)
	k.box(mat, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.085, 0.29, -0.16)), Vector3(0.008, 0.008, 0.12))
	for sx in [-1.0, 1.0]:
		var s2: float = sx
		# brazos y antebrazos hacia el teclado, manos
		_tint(k, Color.WHITE, 1.0)
		k.box(mat, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-28.0)), Vector3(s2 * 0.245, -0.03, -0.1)), Vector3(0.09, 0.27, 0.09))
		k.box(mat, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)) * Basis(Vector3.UP, s2 * 0.22), Vector3(s2 * 0.2, -0.19, -0.33)), Vector3(0.075, 0.075, 0.28))
		_tint(k, skin)
		k.box(mat, Transform3D(Basis.IDENTITY, Vector3(s2 * 0.15, -0.215, -0.5)), Vector3(0.075, 0.035, 0.1))
		# muslos sobre el asiento, piernas al suelo y zapatos
		_tint(k, pants)
		k.box(mat, Transform3D(Basis.IDENTITY, Vector3(s2 * 0.1, -0.44, -0.19)), Vector3(0.15, 0.12, 0.44))
		k.box(mat, Transform3D(Basis.IDENTITY, Vector3(s2 * 0.1, -0.73, -0.39)), Vector3(0.11, 0.46, 0.12))
		_tint(k, black)
		k.box(mat, Transform3D(Basis.IDENTITY, Vector3(s2 * 0.1, -0.965, -0.44)), Vector3(0.1, 0.07, 0.24))
	return k

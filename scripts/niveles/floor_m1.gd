extends FloorBase
## Piso -1: calle y escalera de ingreso, lobby con molinetes y guardia, cafetería (microondas,
## expendedora, terminal), núcleo de ascensores y escalera, dos baños individuales (GDD 7.2 rev 2).
## v0.3 P2: fachada (sin logos), torre que se pierde en la niebla, lluvia, charcos, faroles y silueta de ciudad, bus
## de llegada y de salida, puesto del guardia iluminado (marcador fermin_puesto, bandera del molinete para P5), zona
## de descanso con ping-pong y puffs para dormir pasando los sofás de la cafetería (x 27-35, z 2-12, marcador
## descanso_m1).
## v0.3.1 Q5 (fotos y videos del site, ref_site_v2/REFERENCIA_PISOS.md §1, §2, §7.1): el ingreso está HUNDIDO. La
## vereda y la pista quedan a STREET_Y (2,1 m) sobre el lobby y se BAJA al patio de ingreso por 12 peldaños con
## alfombras antideslizantes azules y baranda central inox; el patio (z 14-18) es un pozo donde se empoza la lluvia,
## con cartón mojado, el cartel de piso mojado y huellas de barro que bajan y no suben. Fachada de concreto claro con
## franjas de aluminio y vidrio, letrero «KONZENTRAMANCE» (decisión de Joan, D1). Lobby angosto y profundo (x -9,6..6,5)
## de porcelanato negro espejado con retícula negra open-cell en el techo, pared de 6 posters sin rostro a la
## izquierda, recepción con pared turquesa a la derecha, 3 molinetes trípode + lector alto (barrera de vidrio de
## 1,25 m: el salto no los cruza, C16). Cafetería con techo abierto gris, rociadores rojos, campanas negras, carros
## bandejeros, barra frente a la ventana alta del patio inglés, nichos con arco y la estación de 2 refris inox,
## 6 microondas (2 filas de 3) y lavadero (D4/D5). Zonas de superficie `exterior` y `vinilico` para los pasos (C15).

const STREET_Y := 2.1
const STEPS := 12
const STEP_RUN := 0.3
const PIT_Z0 := 14.0   # fachada
const STAIR_Z0 := 18.0  # pie de la escalera de ingreso (fondo del patio)
const STAIR_HW := 3.2   # media anchura de la escalera
const PIT_HW := 6.0     # media anchura del patio hundido
const LOBBY_X0 := -9.6
const LOBBY_X1 := 6.5

var _arrows: SiteProps.ArrowWave = null


func _stair_z1() -> float:
	return STAIR_Z0 + STEPS * STEP_RUN


func _build() -> void:
	floor_number = -1
	_street()
	_pit()
	_facade()
	_lobby()
	_turnstiles()
	_reception()
	_guard()
	_core()
	_bathrooms()
	_cafeteria()
	_rest_zone()
	_exterior()
	# Zonas
	Zone.make(self, "lobby", Vector3(-1.55, 1.5, 9.0), Vector3(16.1, 3, 10))
	Zone.make(self, "cafeteria", Vector3(0, 1.5, (CAFE_Z0 + CAFE_Z1) * 0.5), Vector3(CAFE_X1 - CAFE_X0, 3, CAFE_Z1 - CAFE_Z0))
	Zone.make(self, "calle", Vector3(0, 2.5, 22.5), Vector3(30, 5.0, 17))
	Zone.make(self, "exterior", Vector3(0, 2.5, 23.5), Vector3(40, 5.0, 19))  # C15: pasos de exterior mojado (patio + calle)
	# Rutas (Shero, Pursuit): lobby → núcleo → puerta push → cafetería; núcleo → conexión → barra → descanso / lounge;
	# cafetería → pasillo de baños → barra (el paso abierto de Joan).
	waypoints = [Vector3(0, 0, 8), Vector3(0, 0, 0), Vector3(-3, 0, 0), Vector3(-7, 0, 0.5), Vector3(4, 0, 0), Vector3(8.5, 0, 0.5),
		Vector3(2.0, 0, -2.5), Vector3(2.0, 0, -5.0), Vector3(2.0, 0, -7.5), Vector3(-3.5, 0, -9.0), Vector3(3.0, 0, -9.0),
		Vector3(-11.0, 0, -11.5), Vector3(-0.5, 0, -12.5), Vector3(6.0, 0, -12.5), Vector3(11.0, 0, -10.0), Vector3(-5.0, 0, -13.5),
		Vector3(10.2, 0, 4.0), Vector3(12.6, 0, 4.0), Vector3(12.4, 0, 6.0), Vector3(15.0, 0, 6.5), Vector3(14.4, 0, 9.5),
		Vector3(19.0, 0, 9.0), Vector3(12.6, 0, 0.0), Vector3(12.2, 0, -1.2), Vector3(12.2, 0, -6.0), Vector3(12.2, 0, -7.6),
		Vector3(16.3, 0, -0.2), Vector3(17.0, 0, -3.6)]


# --- Calle (a STREET_Y) ------------------------------------------------------------------------------

func _street() -> void:
	var sy := STREET_Y
	var z1 := _stair_z1()
	# Vereda de losas de concreto: delante del pozo (z1..25) y a los lados del pozo (|x| 6..15, z 14..z1).
	var front := Greybox.sbox(self, "Calle", Vector3(0, sy - 0.25, (z1 + 25.0) * 0.5), Vector3(30, 0.5, 25.0 - z1), "vereda")
	front.name = "Calle"
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (PIT_HW + 15.0) * 0.5
		Greybox.sbox(self, "VeredaLado%d" % int(sx), Vector3(cx, sy - 0.25, (PIT_Z0 + z1) * 0.5), Vector3(15.0 - PIT_HW, 0.5, z1 - PIT_Z0), "vereda")
	# Pista de asfalto mojado y bordillo amarillo al borde de la vereda.
	# Calzada 7 cm bajo la vereda (como en la v0.3: un escalón que el cuerpo sube sin trabarse).
	var pista := Greybox.box(self, "Pista", Vector3(0, sy - 0.07 - 0.25, 29), Vector3(40, 0.5, 8), Color(0.1, 0.1, 0.105))
	pista.material_override = Greybox.material(Color(0.1, 0.1, 0.11), 0.0, 0.3, 0.15)
	Greybox.box(self, "Sardinel", Vector3(0, sy - 0.06, 25.05), Vector3(30, 0.12, 0.12), Greybox.AMARILLO_FRANJA, false)
	# Bordillo amarillo al borde del pozo (como en el site).
	Greybox.box(self, "BordilloPozo", Vector3(0, sy + 0.005, z1 + 0.06), Vector3(STAIR_HW * 2.0, 0.01, 0.12), Greybox.AMARILLO_FRANJA, false)
	# Tapa de buzón genérica (puntos, sin texto ni logo).
	var tapa := Greybox.cylinder(self, "TapaBuzon", Vector3(4.6, sy + 0.006, 23.4), 0.4, 0.012, Color(0.16, 0.16, 0.17), false, 0.5, 0.6)
	for k in 8:
		var a := TAU * k / 8.0
		Greybox.cylinder(tapa, "Punto%d" % k, Vector3(cos(a) * 0.24, 0.007, sin(a) * 0.24), 0.025, 0.004, Color(0.24, 0.24, 0.25))
	# Paradero, perro, postes y cables.
	var paradero := Greybox.box(self, "Paradero", Vector3(8, sy + 2.3, 23), Vector3(3, 0.1, 1.4), Greybox.GRIS_OSCURO, false)
	paradero.material_override = Greybox.material(Greybox.GRIS_OSCURO, 0.0, 0.5, 0.6)
	for px in [6.7, 9.3]:
		Greybox.cylinder(self, "ParaderoPoste%d" % int(px * 10), Vector3(px, sy + 1.15, 23.6), 0.04, 2.3, Greybox.INOX, true, 0.32, 0.45)
	Greybox.box(self, "ParaderoBanca", Vector3(8, sy + 0.45, 23.4), Vector3(2.4, 0.08, 0.4), Greybox.MADERA)
	Greybox.box(self, "ParaderoLuz", Vector3(8, sy + 2.24, 23), Vector3(1.2, 0.03, 0.3), Color(0.85, 0.95, 0.95), false, 1.6)
	Greybox.light(self, Vector3(8, sy + 2.0, 23), Color(0.75, 0.9, 0.9), 0.9, 5.0)
	var perro := NpcFigure.make(self, "perrito_rta", Vector3(7.4, sy, 22.3), 70.0, 0.42, Color(0.55, 0.45, 0.34), "PerroParadero")
	perro.look_radius = 3.5
	perro.look_max_deg = 35.0
	perro.anim_speed = 0.35
	perro.near_anim = "sniff"
	if perro.rig != null:
		perro.rig.rotation_degrees.x = -8.0  # echado
		perro.rig.position.y = -0.06
	for px in [-10.0, 10.0]:
		Greybox.cylinder(self, "Poste%d" % int(px), Vector3(px, sy + 2.5, 24.6), 0.07, 5.0, Greybox.GRIS_OSCURO, true, 0.6, 0.4)
		Greybox.light(self, Vector3(px, sy + 4.8, 24.6), Color(0.9, 0.7, 0.4), 1.6, 9.0)
	for i in 3:
		var c := Greybox.box(self, "Cable%d" % i, Vector3(0, sy + 4.7 + i * 0.18 - 0.25 * absf(i - 1.0), 24.6), Vector3(20.0, 0.02, 0.02), Greybox.NEGRO, false)
		c.rotation_degrees.z = (i - 1) * 0.6
	# Árboles de hoja fina sobre la vereda y jardineras escalonadas.
	SiteProps.tree(self, "ArbolW", Vector3(-12.5, sy, 22.8), 5.5)
	SiteProps.tree(self, "ArbolE", Vector3(13.0, sy, 22.6), 5.0)
	# Límites invisibles de la calle (vereda x ±15, pista x ±20, z 33) y del pozo (barandas a 1,3 m, C16).
	# Los límites bajan hasta el suelo (y -0,5): debajo de la vereda elevada no queda un hueco al que se pueda caer.
	Greybox.invisible_box(self, "LimiteVeredaW", Vector3(-15.1, (sy + 2.5) * 0.5, 19.5), Vector3(0.2, sy + 3.5, 11.2))
	Greybox.invisible_box(self, "LimiteVeredaE", Vector3(15.1, (sy + 2.5) * 0.5, 19.5), Vector3(0.2, sy + 3.5, 11.2))
	Greybox.invisible_box(self, "LimitePistaW", Vector3(-20.1, (sy + 2.5) * 0.5, 29), Vector3(0.2, sy + 3.5, 8.4))
	Greybox.invisible_box(self, "LimitePistaE", Vector3(20.1, (sy + 2.5) * 0.5, 29), Vector3(0.2, sy + 3.5, 8.4))
	Greybox.invisible_box(self, "LimitePistaS", Vector3(0, (sy + 2.5) * 0.5, 33.1), Vector3(40.4, sy + 3.5, 0.2))
	Greybox.invisible_box(self, "LimitePistaSW", Vector3(-17.5, (sy + 2.5) * 0.5, 25.0), Vector3(5.2, sy + 3.5, 0.2))
	Greybox.invisible_box(self, "LimitePistaSE", Vector3(17.5, (sy + 2.5) * 0.5, 25.0), Vector3(5.2, sy + 3.5, 0.2))
	Greybox.marker(self, "calle", Vector3(0, sy, 24), 0.0)  # mirando a la fachada y a la bajada del ingreso


# --- Patio hundido y escalera de ingreso (se BAJA) ---------------------------------------------------

func _step_top(z: float) -> float:
	if z <= STAIR_Z0:
		return 0.0
	var k := clampi(int(ceil((z - STAIR_Z0) / STEP_RUN)), 1, STEPS)
	return STREET_Y * k / STEPS


func _pit() -> void:
	var sy := STREET_Y
	var z1 := _stair_z1()
	var rise := sy / STEPS
	# Fondo del patio: porcelanato negro mojado (z 14..18) y la losa bajo la escalera.
	var patio := Greybox.sfloor(self, "PatioHundido", Vector2(0, (PIT_Z0 + STAIR_Z0) * 0.5), Vector2(PIT_HW * 2.0, STAIR_Z0 - PIT_Z0), "porcelanato_negro")
	patio.material_override = Greybox.surf("porcelanato_negro", Color(0.95, 0.95, 1.0), 0.06)
	# Peldaños de porcelanato negro con alfombras azules en dos carriles; colisión con rampa oculta (como stairwell).
	for i in STEPS:
		var top := rise * (i + 1)
		var zc := STAIR_Z0 + STEP_RUN * (i + 0.5)
		var s := Greybox.box(self, "Peldano%02d" % i, Vector3(0, top - rise * 0.5, zc), Vector3(STAIR_HW * 2.0, rise, STEP_RUN), Greybox.PORCELANATO_NEGRO, false)
		s.material_override = Greybox.surf("porcelanato_negro")
		for lane in [-1.0, 1.0]:
			var m := Greybox.box(s, "Alfombra%d" % int(lane), Vector3(lane * STAIR_HW * 0.5, rise * 0.5 + 0.004, 0.0), Vector3(STAIR_HW - 0.45, 0.008, STEP_RUN - 0.05), Color(0.25, 0.45, 0.74), false)
			m.material_override = Greybox.surf("alfombra_azul")
	var ramp := StaticBody3D.new()
	ramp.name = "RampaIngreso"
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var run := STEPS * STEP_RUN
	var len := sqrt(run * run + sy * sy)
	bs.size = Vector3(STAIR_HW * 2.0, 0.2, len + 0.3)
	shape.shape = bs
	ramp.add_child(shape)
	ramp.position = Vector3(0, sy * 0.5 - 0.1, STAIR_Z0 + run * 0.5)
	ramp.rotation.x = -atan2(sy, run)
	add_child(ramp)
	# La baranda central parte la escalera en dos carriles (también choca: se baja por un lado o por el otro).
	var mid := Greybox.invisible_box(self, "BarandaCentralCol", Vector3(0, sy * 0.5 + 0.55, STAIR_Z0 + run * 0.5), Vector3(0.1, 1.1, len))
	mid.rotation.x = -atan2(sy, run)
	# Relleno bajo la escalera (nadie lo ve, pero cierra la planta para las auditorías).
	Greybox.invisible_box(self, "BajoEscalera", Vector3(0, -0.1, STAIR_Z0 + run * 0.5), Vector3(STAIR_HW * 2.0, 0.2, run))
	# Baranda central inox y barandas laterales de barras horizontales (con colisión alta: no se sale por el costado).
	var inox := Greybox.inox()
	var slope := atan2(sy, run)
	for bx in [-STAIR_HW, 0.0, STAIR_HW]:
		var rail := Greybox.box(self, "Baranda%d" % int(bx * 10 + 50), Vector3(bx, sy * 0.5 + 0.95, STAIR_Z0 + run * 0.5), Vector3(0.05, 0.05, len), Greybox.INOX, false)
		rail.rotation.x = -slope
		rail.material_override = inox
		for k in 4:
			var t := (k + 0.5) / 4.0
			Greybox.cylinder(self, "BarandaPoste%d_%d" % [int(bx * 10 + 50), k], Vector3(bx, sy * t + 0.48, STAIR_Z0 + run * t), 0.022, 0.95, Greybox.INOX, false, 0.32, 0.45).material_override = inox
		if bx != 0.0:
			for k in 3:
				var bar := Greybox.box(self, "BarraLateral%d_%d" % [int(bx * 10 + 50), k], Vector3(bx, sy * 0.5 + 0.25 + k * 0.25, STAIR_Z0 + run * 0.5), Vector3(0.02, 0.02, len), Greybox.INOX, false)
				bar.rotation.x = -slope
				bar.material_override = inox
			var side := Greybox.invisible_box(self, "LimiteEscalera%d" % int(bx), Vector3(bx + signf(bx) * 0.12, sy * 0.5 + 0.9, STAIR_Z0 + run * 0.5), Vector3(0.2, sy + 2.4, run + 0.4))
			side.name = "LimiteEscalera%s" % ("W" if bx < 0 else "E")
		# Remate de la baranda arriba, en la vereda.
		Greybox.cylinder(self, "BarandaRemate%d" % int(bx * 10 + 50), Vector3(bx, sy + 0.5, z1 + 0.25), 0.022, 1.0, Greybox.INOX, false, 0.32, 0.45).material_override = inox
	# Jardineras escalonadas a los costados de la escalera (concreto, palmeras, cordyline, hiedra) y paredes del pozo.
	for sx in [-1.0, 1.0]:
		var x0 := STAIR_HW + 0.05
		var w := PIT_HW - x0
		for k in 3:
			var hh := sy * (k + 1) / 3.0
			var zc2 := STAIR_Z0 + run * (k + 0.5) / 3.0
			SiteProps.planter(self, "Jardinera%d_%d" % [int(sx), k], Vector3(sx * (x0 + w * 0.5), hh * 0.5, zc2), Vector3(w, hh, run / 3.0))
		Greybox.sbox(self, "MuroPozo%d" % int(sx), Vector3(sx * (PIT_HW + 0.15), sy * 0.5, (PIT_Z0 + z1) * 0.5), Vector3(0.3, sy, z1 - PIT_Z0), "concreto")
		# Jardinera baja a lo largo del patio, contra el muro.
		SiteProps.planter(self, "JardineraPatio%d" % int(sx), Vector3(sx * (PIT_HW - 0.45), 0.3, 15.9), Vector3(0.9, 0.6, 3.4))
		# Baranda inox sobre el borde del pozo (en la vereda) + límite invisible de 1,3 m (C16).
		var px: float = sx * (PIT_HW + 0.15)
		Greybox.box(self, "BarandaPozo%d" % int(sx), Vector3(px, sy + 1.0, (PIT_Z0 + z1) * 0.5), Vector3(0.05, 0.05, z1 - PIT_Z0), Greybox.INOX, false).material_override = inox
		for k in 2:
			Greybox.box(self, "BarandaPozoBarra%d_%d" % [int(sx), k], Vector3(px, sy + 0.35 + k * 0.33, (PIT_Z0 + z1) * 0.5), Vector3(0.02, 0.02, z1 - PIT_Z0), Greybox.INOX, false).material_override = inox
		Greybox.invisible_box(self, "LimitePozo%d" % int(sx), Vector3(px, sy + 0.65, (PIT_Z0 + z1) * 0.5), Vector3(0.3, 1.3, z1 - PIT_Z0))
		# Borde frontal del pozo sobre las jardineras (entre la escalera y el muro).
		Greybox.box(self, "BarandaFrente%d" % int(sx), Vector3(sx * (STAIR_HW + PIT_HW) * 0.5, sy + 1.0, z1), Vector3(PIT_HW - STAIR_HW, 0.05, 0.05), Greybox.INOX, false).material_override = inox
		Greybox.invisible_box(self, "LimiteFrente%d" % int(sx), Vector3(sx * (STAIR_HW + PIT_HW) * 0.5, sy + 0.65, z1 + 0.05), Vector3(PIT_HW - STAIR_HW + 0.3, 1.3, 0.3))
	# Dos columnas de concreto en el patio.
	for cx in [-4.0, 4.0]:
		Greybox.sbox(self, "ColumnaPatio%d" % int(cx), Vector3(cx, 2.4, 15.0), Vector3(0.6, 4.8, 0.6), "concreto")
	# Versión más aterradora: el pozo se empoza. Charco que crece cada turno, cartones empapados, cartel de piso
	# mojado y huellas de barro que bajan pero no suben.
	var grow := 1.0 + 0.35 * clampi(GameState.turno - 1, 0, 3)
	Weather.puddle(self, Vector3(0.4, 0.012, 16.6), Vector2(3.4 * grow, 1.7 * grow))
	Weather.puddle(self, Vector3(-2.6, 0.012, 14.9), Vector2(1.4, 0.8))
	SiteProps.cardboard(self, "Carton0", Vector3(-0.8, 0.0, 17.1), 8.0, Vector2(1.1, 0.75))
	SiteProps.cardboard(self, "Carton1", Vector3(0.9, 0.0, 15.6), -14.0, Vector2(0.9, 0.7))
	SiteProps.cardboard(self, "Carton2", Vector3(0.2, 0.0, 14.5), 3.0, Vector2(1.4, 0.6))
	SiteProps.wet_sign(self, "PisoMojado", Vector3(1.8, 0.0, 16.9), 20.0)
	SiteProps.footprints(self, "HuellaBaja", Vector3(-1.5, 0, z1 - 0.15), Vector3(-0.6, 0, 14.4), 0.6, func(p: Vector3) -> float: return _step_top(p.z))


# --- Fachada ----------------------------------------------------------------------------------------

func _facade() -> void:
	var sy := STREET_Y
	# Frente de vidrio del lobby hacia el patio (x -6..6) con el vano de las puertas (x -1,2..1,2).
	Greybox.box(self, "MuroCortinaA", Vector3(-3.6, 1.6, PIT_Z0), Vector3(4.8, 3.2, 0.08), Greybox.VIDRIO)
	Greybox.box(self, "MuroCortinaB", Vector3(3.6, 1.6, PIT_Z0), Vector3(4.8, 3.2, 0.08), Greybox.VIDRIO)
	for fx in [-1.25, 1.25]:
		Greybox.box(self, "Jalador%d" % int(fx * 10), Vector3(fx * 0.96, 1.1, PIT_Z0 + 0.06), Vector3(0.03, 1.4, 0.03), Greybox.INOX, false).material_override = Greybox.inox()
		Greybox.box(self, "MarcoPuerta%d" % int(fx * 10), Vector3(fx, 1.6, PIT_Z0), Vector3(0.08, 3.2, 0.12), Greybox.NEGRO, false)
	Greybox.box(self, "DintelPuerta", Vector3(0, 3.15, PIT_Z0), Vector3(2.6, 0.1, 0.12), Greybox.NEGRO, false)
	for fx in [-3.6, 3.6]:
		Greybox.box(self, "FranjaEsmerilada%d" % int(fx), Vector3(fx, 1.3, PIT_Z0 + 0.05), Vector3(4.6, 0.5, 0.01), Color(0.86, 0.9, 0.9, 0.6), false)
	Greybox.exit_sign(self, "SalidaPuerta", Vector3(0, 2.95, PIT_Z0 - 0.08), 180.0)
	# Muro del sótano a los lados del vidrio (x -9,6..-6 y 6..6,5 a z 14) y el resto de la fachada de concreto claro.
	Greybox.sbox(self, "FachadaW", Vector3(-12.3, sy * 0.5 + 0.9, PIT_Z0), Vector3(5.4, sy + 1.8, 0.3), "concreto")
	Greybox.sbox(self, "FachadaE", Vector3(10.5, sy * 0.5 + 0.9, PIT_Z0), Vector3(9.0, sy + 1.8, 0.3), "concreto")
	Greybox.sbox(self, "FachadaPozoW", Vector3(-7.8, 1.6, PIT_Z0), Vector3(3.6, 3.2, 0.3), "concreto")
	Greybox.sbox(self, "FachadaPozoE", Vector3(6.25, 1.6, PIT_Z0), Vector3(0.5, 3.2, 0.3), "concreto")
	# Medianeras hasta el borde de la vereda (antes se podía rodear la fachada y caer).
	Greybox.sbox(self, "MedianeraW", Vector3(-15.0, sy + 2.0, 14.0 + 2.0), Vector3(0.3, 4.0, 4.0), "concreto")
	Greybox.sbox(self, "MedianeraE", Vector3(15.0, sy + 2.0, 14.0 + 2.0), Vector3(0.3, 4.0, 4.0), "concreto")
	# Muro cortina a doble altura sobre el ingreso (mezzanine) y pisos altos: concreto, aluminio y vidrio en franjas.
	Greybox.sbox(self, "FachadaAlta", Vector3(0, 7.9, 13.85), Vector3(30, 9.4, 0.3), "concreto")
	Greybox.box(self, "MuroCortinaAlto", Vector3(0, 4.9, 14.02), Vector3(11.5, 3.2, 0.06), Color(0.2, 0.26, 0.3, 0.75), false, 0.12)
	for mx in [-5.75, -2.9, 0.0, 2.9, 5.75]:
		Greybox.box(self, "Montante%d" % int(mx * 10), Vector3(mx, 4.9, 14.06), Vector3(0.1, 3.2, 0.08), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "Mezzanine", Vector3(0, 4.6, 13.9), Vector3(11.5, 0.12, 0.25), Greybox.GRIS_OSCURO, false)
	var alu := Greybox.material(Greybox.ALUMINIO, 0.0, 0.35, 0.7)
	for i in 3:
		var y := 7.2 + i * 1.5
		Greybox.box(self, "FranjaAluminio%d" % i, Vector3(0, y, 14.05), Vector3(30, 0.7, 0.06), Greybox.ALUMINIO, false).material_override = alu
		Greybox.box(self, "FranjaVidrio%d" % i, Vector3(0, y + 0.75, 14.05), Vector3(30, 0.8, 0.05), Color(0.12, 0.16, 0.19), false, 0.08)
	# Dintel del ingreso: cobre y madera con apliques ámbar (lote 1), solo sobre las puertas.
	Greybox.box(self, "Dintel", Vector3(0, 3.45, PIT_Z0 + 0.05), Vector3(12.0, 0.5, 0.35), Greybox.COBRE)
	for ax in [-4.5, -1.5, 1.5, 4.5]:
		Greybox.box(self, "Aplique%d" % int(ax + 20), Vector3(ax, 3.1, PIT_Z0 + 0.22), Vector3(0.25, 0.12, 0.12), Greybox.AMBAR, false, 2.0)
	for ax in [-3.0, 3.0]:
		Greybox.light(self, Vector3(ax, 2.9, PIT_Z0 + 0.8), Greybox.AMBAR, 1.25, 6.0)
	_facade_name()


## Letras de la fachada: KONZENTRAMANCE (D1, con «a») en blanco frío sobre la franja de aluminio (una letra falla y
## parpadea) y el nombre chico en el dintel. Sin logo.
func _facade_name() -> void:
	var word := "KONZENTRAMANCE"
	var step := 1.62
	var x0 := -step * (word.length() - 1) * 0.5
	for i in word.length():
		var l := Greybox.label(self, word[i], Vector3(x0 + i * step, 11.9, 14.32), 1.7, Color(0.82, 0.92, 0.95))
		l.name = "Letra%d" % i
		l.outline_size = 0
		if i == 9:  # la "M" falla
			var f := _LetterFlicker.new()
			f.name = "Falla"
			f.label = l
			l.add_child(f)
	Greybox.box(self, "LetrasRiel", Vector3(0, 11.05, 14.25), Vector3(23.5, 0.06, 0.12), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "LetrasLuz", Vector3(0, 11.0, 14.32), Vector3(23.0, 0.03, 0.05), Color(0.7, 0.9, 0.95), false, 2.5)
	var wash := Greybox.light(self, Vector3(0, 10.4, 16.5), Color(0.6, 0.78, 0.85), 1.6, 9.0)
	wash.name = "LuzLetras"
	var dintel := Greybox.label(self, "KONZENTRAMANCE  ·  " + tr("SIGN_TOWER_SUB"), Vector3(0, 3.47, PIT_Z0 + 0.24), 0.26, Greybox.AMBAR)
	dintel.name = "NombreDintel"
	# La torre sigue hacia arriba y se pierde en la niebla: pocas ventanas encendidas (pisos de operación).
	var torre := Greybox.box(self, "Torre", Vector3(0, 32.5, 7.0), Vector3(26.0, 40.0, 14.0), Color(0.05, 0.055, 0.065), false)
	torre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	for floor_i in 26:
		var y := 13.1 + floor_i * 1.5
		var busy := floor_i in [1, 5, 11]  # pisos "de operación": tiras de fluorescente con huecos
		for k in 15:
			if rng.randf() < (0.55 if busy else 0.05):
				var w := rng.randf_range(0.9, 1.4)
				xs.append(Transform3D(Basis.from_scale(Vector3(w, 0.7, 0.05)), Vector3(-11.9 + k * 1.7, y, 14.03)))
				var dim := rng.randf_range(0.35, 0.7)
				cs.append(Color(0.45, 0.75, 0.7) * dim if busy else Color(0.85, 0.62, 0.36) * dim)
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TorreVentanas"
	mmi.multimesh = mm
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	mmi.material_override = wm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var baliza := Greybox.box(self, "Baliza", Vector3(9.5, 52.7, 7.0), Vector3(0.5, 0.5, 0.5), Greybox.ROJO, false, 3.0)
	baliza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


class _LetterFlicker extends Node:
	var label: Label3D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or label == null:
			return
		var on := randf() > 0.35
		label.modulate = Color(0.82, 0.92, 0.95) if on else Color(0.15, 0.18, 0.2)
		_t = randf_range(0.05, 0.25) if randf() < 0.7 else randf_range(1.0, 4.0)


# --- Lobby -----------------------------------------------------------------------------------------

func _lobby() -> void:
	var cz := (4.0 + PIT_Z0) * 0.5
	var w := LOBBY_X1 - LOBBY_X0
	var cx := (LOBBY_X0 + LOBBY_X1) * 0.5
	# Porcelanato negro espejado (rugosidad 0,08) con juntas claras cada 0,6 m.
	var lobby_floor := Greybox.sfloor(self, "Lobby", Vector2(-1.55, 9.0), Vector2(16.3, 10.2), "porcelanato_negro")
	lobby_floor.material_override = Greybox.surf("porcelanato_negro", Color(1.25, 1.25, 1.3), 0.16)
	Greybox.ceiling(self, "LobbyTecho", Vector2(0, 8), Vector2(24, 12), 3.5)  # plenum negro sobre la retícula
	# Retícula negra open-cell a 3,0 m con downlights redondos; por las celdas se adivinan cables colgando.
	Greybox.sceiling(self, "Reticula", Vector2(cx, cz), Vector2(w, PIT_Z0 - 4.0), 3.0, "reticula")
	for i in 3:
		for k in 2:
			Greybox.downlight(self, "DownLobby%d_%d" % [i, k], Vector3(cx - 4.0 + k * 8.0 * 0.6 + 1.2, 2.98, 5.5 + i * 3.2), Color(1.0, 0.85, 0.68), 1.15 if not (i == 1 and k == 0) else 0.25, 6.5, i != 1 or k != 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 9:
		var hang := rng.randf_range(0.15, 0.4)
		Greybox.box(self, "CablePlenum%d" % i, Vector3(rng.randf_range(LOBBY_X0 + 1, LOBBY_X1 - 1), 3.25 - hang * 0.5 + 0.2, rng.randf_range(5, 13)), Vector3(0.012, hang + 0.4, 0.012), Color(0.02, 0.02, 0.02), false)
	# Relleno frío bajo (P6b: el lobby salía negro) y la luz de la puerta.
	for x in [-4.0, 3.0]:
		var rl := Greybox.light(self, Vector3(x, 2.7, 8.5), Color(0.72, 0.82, 0.86), 0.85, 9.5)
		rl.name = "LuzLobbyRelleno%d" % int(x)
	Greybox.light_panel(self, "LuzLobby6", Vector3(-6.5, 2.95, 12.2), false, true)  # el fluorescente que falla, junto al guardia
	# Paredes: oeste blanca con 6 posters sin rostro (z 4..10), este turquesa detrás de la recepción.
	Greybox.swall(self, "ParedLobbyW", Vector3(LOBBY_X0 - 0.1, 1.75, (4.0 + PIT_Z0) * 0.5), Vector3(0.2, 3.5, PIT_Z0 - 4.0), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "ParedLobbyE", Vector3(LOBBY_X1 + 0.1, 1.75, cz), Vector3(0.2, 3.5, PIT_Z0 - 4.0), "pared", Greybox.TURQUESA)
	# Oficina cerrada detrás de la recepción (x 6,5..11): su fondo es la pared de la zona de bienestar (x 11); el rincón
	# x 9,5..11, z 4..5,6 es la franja de conexión (_core).
	Greybox.swall(self, "OficinaS", Vector3((LOBBY_X1 + 9.5) * 0.5 + 0.1, 1.75, 4.0), Vector3(9.5 - LOBBY_X1, 3.5, 0.2), "pared", Greybox.BLANCO_PARED)
	var slogans := ["Q5_POSTER_1", "Q5_POSTER_2", "Q5_POSTER_3", "Q5_POSTER_4", "Q5_POSTER_5", "Q5_POSTER_6"]
	var hues := [Color(0.16, 0.42, 0.6), Color(0.85, 0.6, 0.2), Color(0.2, 0.55, 0.5), Color(0.6, 0.25, 0.3), Color(0.25, 0.35, 0.7), Color(0.7, 0.7, 0.2)]
	for i in 6:
		SiteProps.faceless_poster(self, "PosterLobby%d" % i, Vector3(LOBBY_X0 + 0.03, 1.75, 4.9 + i * 0.95), 90.0, slogans[i], hues[i], GameState.turno - 1 + (i % 3))
	# Bulkhead sobre la entrada al núcleo con el reloj de pared.
	Greybox.sbox(self, "Bulkhead", Vector3(cx, 3.15, 4.0), Vector3(w, 0.7, 0.3), "pared", false, Greybox.BLANCO_PARED)
	_wall_clock(Vector3(0, 2.6, 4.17))
	# Felpudo carbón en la puerta y taburete alto del guardia.
	var felpudo := Greybox.box(self, "Felpudo", Vector3(0, 0.006, 13.2), Vector3(3.0, 0.012, 1.2), Color(0.37, 0.35, 0.34), false)
	felpudo.material_override = Greybox.surf("felpudo")
	var stool := Greybox.cylinder(self, "Taburete", Vector3(-2.6, 0.38, 13.1), 0.18, 0.04, Greybox.NEGRO, false)
	stool.position.y = 0.76
	Greybox.cylinder(self, "TaburetePie", Vector3(-2.6, 0.38, 13.1), 0.025, 0.76, Greybox.NEGRO)
	# Halloween olvidado: murciélagos de papel en el techo.
	SiteProps.bats(self, "Murcielago", Vector3(1.0, 0, 9.5), Vector2(10.0, 6.0), 9, 3.0, 17)


func _wall_clock(pos: Vector3) -> void:
	var c := WorldObjects.WallClock.new()
	c.name = "RelojPared"
	c.size = Vector3(1.0, 0.6, 0.6)
	c.position = pos
	add_child(c)
	Greybox.box(c, "Caja", Vector3.ZERO, Vector3(0.9, 0.4, 0.05), Greybox.GRIS_OSCURO, false)
	c.label = Greybox.label(c, "", Vector3(0, 0, 0.04), 0.3, Greybox.ROJO)  # un solo rojo (GDD 8.2)


## 3 molinetes trípode (uno fuera de servicio) + lector alto, en una barrera de vidrio a z 6 (cruza toda la planta).
## Carriles de 1,0 m libres (centros x -1,0 / 0,25 / 1,5) y el accesible junto al lector (x 2,8).
func _turnstiles() -> void:
	var z := 6.0
	var cabs := [-1.625, -0.375, 0.875, 2.125]
	for i in cabs.size():
		SiteProps.tripod_cabinet(self, "GabineteMolinete%d" % i, Vector3(cabs[i], 0, z), -1.0 if i == cabs.size() - 1 else 1.0)
	SiteProps.tall_reader(self, "LectorAlto", Vector3(3.55, 0, z))
	_arrows = SiteProps.ArrowWave.new()
	_arrows.name = "FlechasMolinetes"
	add_child(_arrows)
	for n in find_children("Flecha*", "MeshInstance3D", true, false):
		if n.has_meta("flecha"):
			_arrows.arrows.append(n as MeshInstance3D)
	var lanes := [-1.0, 0.25, 1.5, 2.8]
	for i in lanes.size():
		var t := WorldObjects.Turnstile.new()
		t.name = "Molinete%d" % i
		t.hint_key = "HUD_TURNSTILE"
		t.size = Vector3(1.05, 1.5, 1.4)
		t.position = Vector3(lanes[i], 0.75, z)
		add_child(t)
		# Barrera fisica real que impide traspasar o saltar el molinete hasta interactuar con [E]
		var sb := StaticBody3D.new()
		sb.name = "BarreraFisicaMolinete%d" % i
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.05, 1.5, 0.28)
		cs.shape = box
		sb.add_child(cs)
		t.add_child(sb)
		t.blocker_body = sb
		if i == 2:
			t.out_of_service = true
			var fs := Greybox.label(t, "FUERA DE SERVICIO", Vector3(0, 0.45, 0.56), 0.1, Greybox.AMBAR)
			fs.name = "FueraDeServicio"
	# Zona detectora detras de los molinetes: si cruzas sin revision, Don Fermin te persigue
	Zone.make(self, "sin_revision_paso", Vector3(0.8, 1.4, 4.6), Vector3(7.0, 2.8, 1.2))
	if GameState.turno == 6 and not bool(GameState.flags.get("frag_carta_3", false)):
		var f3 := WorldObjects.simple(self, WorldObjects.ResignationFragment, "FragmentoCarta3", "HUD_TURNSTILE", Vector3(-2.5, 0.78, -6.5), Vector3(0.24, 0.03, 0.32), Color(0.95, 0.92, 0.82), 25.0, 0.6)
		(f3 as WorldObjects.ResignationFragment).frag_id = 3
	# Barreras de vidrio con pasamanos inox a 1,1 m y colisión hasta 1,3 m (el salto no las cruza).
	var inox := Greybox.inox()
	for seg in [[LOBBY_X0, -1.75], [3.7, LOBBY_X1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		var c := (a + b) * 0.5
		var lw := b - a
		Greybox.box(self, "BarreraVidrio%d" % int(c), Vector3(c, 0.6, z), Vector3(lw, 1.1, 0.03), Color(0.7, 0.82, 0.85, 0.22), false)
		Greybox.box(self, "BarreraPasamanos%d" % int(c), Vector3(c, 1.12, z), Vector3(lw, 0.05, 0.06), Greybox.INOX, false).material_override = inox
		Greybox.invisible_box(self, "BarreraCol%d" % int(c), Vector3(c, 0.65, z), Vector3(lw, 1.3, 0.12))
	Greybox.marker(self, "molinetes", Vector3(0, 0, 8), 180.0)


## Mostrador de recepción en L a la derecha (madera clara, tope blanco), pared turquesa detrás, monitores y la bruja.
func _reception() -> void:
	var front := Greybox.box(self, "Recepcion", Vector3(4.6, 0.55, 9.6), Vector3(0.6, 1.1, 4.2), Color(0.796, 0.694, 0.541))
	front.material_override = Greybox.surf("roble", Color(1.05, 1.0, 0.95))
	Greybox.box(self, "RecepcionTope", Vector3(4.6, 1.12, 9.6), Vector3(0.7, 0.04, 4.3), Color(0.91, 0.9, 0.88), false)
	Greybox.box(self, "RecepcionL", Vector3(5.55, 0.55, 11.95), Vector3(1.9, 1.1, 0.6), Color(0.796, 0.694, 0.541)).material_override = Greybox.surf("roble", Color(1.05, 1.0, 0.95))
	Greybox.box(self, "RecepcionLTope", Vector3(5.55, 1.12, 11.95), Vector3(2.0, 0.04, 0.7), Color(0.91, 0.9, 0.88), false)
	for i in 2:
		var mon := Greybox.box(self, "MonitorRecepcion%d" % i, Vector3(4.9, 1.36, 8.7 + i * 1.6), Vector3(0.03, 0.32, 0.5), Color(0.05, 0.07, 0.1), false, 0.35)
		mon.rotation_degrees.y = 0.0
	Greybox.box(self, "SillaRecepcion", Vector3(5.6, 0.47, 9.6), Vector3(0.48, 0.06, 0.46), Greybox.NEGRO, false)
	Greybox.box(self, "BarandaRecepcion", Vector3(4.2, 0.55, 7.2), Vector3(0.03, 1.1, 0.7), Color(0.7, 0.82, 0.85, 0.22), false)
	SiteProps.witch(self, "BrujaColgante", Vector3(4.4, 2.1, 10.3))
	Greybox.light(self, Vector3(5.4, 2.6, 10.0), Color(0.7, 0.92, 1.0), 0.55, 4.5)


## Puesto de Don Fermín (junto a la puerta), con detector, lámpara, cartel de revisión y marcadores para P5.
func _guard() -> void:
	var booth := WorldObjects.simple(self, WorldObjects.Door, "Guardia", "HUD_FERMIN", Vector3(-8, 0.6, 11), Vector3(2.5, 1.2, 1.0), Greybox.MADERA)
	(booth as WorldObjects.Door).locked = true
	(booth as WorldObjects.Door).locked_key = "MSG_FERMIN"
	var caja := booth.get_node_or_null("Caja") as MeshInstance3D
	if caja != null:
		caja.material_override = Greybox.surf("roble", Color(0.7, 0.62, 0.55))
	var fermin := NpcFigure.make(self, "agente_ttoom", Vector3(-8, 0, 12.1), 180.0, 1.76, Color(0.2, 0.24, 0.4), "Fermin")
	fermin.look_radius = 7.0
	fermin.look_max_deg = 60.0
	fermin.anim_speed = 0.8
	Greybox.box(self, "GorraFermin", Vector3(-8, 1.82, 12.1), Vector3(0.26, 0.07, 0.28), Color(0.12, 0.14, 0.24), false)
	Greybox.box(self, "ViseraFermin", Vector3(-8, 1.8, 12.26), Vector3(0.24, 0.02, 0.1), Greybox.NEGRO, false)
	Greybox.box(self, "Linterna", Vector3(-7.3, 1.23, 11.0), Vector3(0.05, 0.05, 0.22), Greybox.NEGRO, false)
	Greybox.box(self, "Cuaderno", Vector3(-8.4, 1.22, 10.8), Vector3(0.3, 0.02, 0.22), Greybox.BEIGE, false)
	Greybox.box(self, "MonitorGuardia", Vector3(-8.9, 1.42, 11.2), Vector3(0.4, 0.3, 0.04), Color(0.1, 0.14, 0.2), false, 0.5)
	Greybox.light(self, Vector3(-8, 1.6, 11), Color(0.7, 0.85, 0.9), 0.5, 3.0)
	Greybox.cylinder(self, "LamparaGuardiaPie", Vector3(-8.95, 1.38, 10.75), 0.012, 0.32, Greybox.NEGRO)
	var pant := Greybox.cylinder(self, "LamparaGuardia", Vector3(-8.85, 1.55, 10.85), 0.1, 0.12, Greybox.NEGRO, false, 0.5, 0.3, 0.05)
	pant.rotation_degrees.x = 35.0
	var foco := Greybox.cylinder(pant, "Foco", Vector3(0, -0.05, 0), 0.04, 0.03, Greybox.AMBAR)
	foco.material_override = Greybox.material(Greybox.AMBAR, 3.0)
	Greybox.light(self, Vector3(-8.4, 1.6, 11.3), Color(1.0, 0.78, 0.5), 1.5, 4.5)
	var cartel := Greybox.box(self, "CartelRevision", Vector3(-8.0, 2.65, 11.55), Vector3(2.6, 0.5, 0.04), Greybox.NEGRO, false)
	Greybox.box(cartel, "Fondo", Vector3(0, 0, 0.022), Vector3(2.5, 0.42, 0.01), Color(0.12, 0.1, 0.06), false, 0.4)
	var t := Greybox.label(cartel, "", Vector3(0, 0, 0.032), 0.12, Greybox.AMBAR)
	t.text = tr("SIGN_GUARD_CHECK")
	Greybox.box(self, "BandejaRevision", Vector3(-6.9, 1.22, 11.0), Vector3(0.45, 0.05, 0.32), Color(0.16, 0.17, 0.2), false)
	Greybox.box(self, "Llavero", Vector3(-6.95, 1.26, 11.0), Vector3(0.06, 0.02, 0.08), Greybox.INOX, false)
	Greybox.box(self, "Detector", Vector3(-6.3, 1.1, 11), Vector3(1.2, 2.2, 0.1), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "CamaraLobby", Vector3(LOBBY_X0 + 0.2, 2.85, 13.6), Vector3(0.2, 0.14, 0.3), Greybox.GRIS_OSCURO, false)
	var rec := Greybox.box(self, "CamaraLobbyLed", Vector3(LOBBY_X0 + 0.28, 2.85, 13.42), Vector3(0.03, 0.03, 0.02), Greybox.ROJO, false, 3.0)
	rec.name = "CamaraLed"
	Greybox.marker(self, "fermin_puesto", Vector3(-8, 0, 12.1), 0.0)
	Greybox.marker(self, "revision_jugador", Vector3(-6.9, 0, 12.6), 90.0)
	Zone.make(self, "guardia", Vector3(-7.5, 1.5, 12.4), Vector3(4.0, 3.0, 2.6))
	EventBus.player_entered_zone.connect(_on_zone_fermin)
	EventBus.show_message.connect(_on_message_fermin)


## Don Fermín habla al entrar al lobby ("Buenas noches. Pase, marque.") y al marcar ("Pase limpio.").
func _on_zone_fermin(zone: String) -> void:
	if zone == "lobby" and not GameState.flags.get("fermin_saludo", false) and not GameState.shift_over:
		GameState.flags["fermin_saludo"] = true
		AudioManager.play_voice("otros", "fermin_buenas_noches", tr("MSG_FERMIN"), "Sala")
	elif zone == "lobby" and GameState.shift_over and not GameState.flags.get("fermin_despedida", false):
		GameState.flags["fermin_despedida"] = true
		AudioManager.play_voice("otros", "fermin_buenas_noches", tr("MSG_FERMIN_OUT"), "Sala")


func _on_message_fermin(text: String, _seconds: float) -> void:
	if text == tr("MSG_TURNSTILE_IN") and not GameState.flags.get("fermin_marca", false):
		GameState.flags["fermin_marca"] = true
		AudioManager.play_voice("otros", "fermin_marca", tr("MSG_FERMIN_PASS"), "Sala")


# --- Núcleo (hall de ascensores del -1) ------------------------------------------------------------
# v0.3.1 pisos (plano de Joan, REFERENCIA_PISOS_v3 §2 y §6.3). El plano de Joan es una vista desde arriba con la calle
# arriba; para llevarlo al juego (calle en +Z) sin reflejarlo se gira 180°: x_juego = 29,2 − x_Joan, z_juego =
# y_Joan − 18,1 (la fórmula de §6.3, x = x_Joan − 29,2, lo espejaba: el paso de baños quedaba con los individuales a
# la izquierda yendo a la cafetería, y en el video están a la derecha). Lo que en el plano está al oeste aquí queda
# en +X. Pasando los molinetes, el hall de ascensores; en su pared −Z, la PUERTA TIPO PUSH a la cafetería, que queda
# DETRÁS del núcleo; en +X, por la «puerta abierta», la zona de barra y el resto del bloque de bienestar.

const CAFE_X0 := -15.1
const CAFE_X1 := 15.1
const CAFE_Z0 := -17.8
const CAFE_Z1 := -6.0
const PUSH_X0 := 0.4
const PUSH_X1 := 3.6
const REST_X0 := 11.0    # pared de la zona de barra / descanso hacia el núcleo
const REST_X1 := 21.3    # muro exterior del bloque de bienestar
const PASO_X0 := 11.4    # pasillo de baños (paso abierto cafetería ↔ zona de bienestar)
const PASO_X1 := 13.0
const LOUNGE_X0 := 14.6
const BAR_Z0 := -1.0
const DESC_Z0 := 5.4
const DESC_Z1 := 13.95
const ABIERTA_Z0 := 2.75  # «puerta abierta» entre la franja de conexión y la barra (Joan: z 2,75..6,9)
const ABIERTA_Z1 := 5.4


func _core() -> void:
	var nucleo := Greybox.sfloor(self, "Nucleo", Vector2(0, 0), Vector2(22.0, 8), "porcelanato_negro")
	nucleo.material_override = Greybox.surf("porcelanato_negro", Color(1, 1, 1), 0.08)
	Greybox.ceiling(self, "NucleoTecho", Vector2(0, 0), Vector2(22.0, 8), 3.5)
	Greybox.sceiling(self, "NucleoBaldosa", Vector2(0, 0), Vector2(22.0, 8), 2.9, "baldosa_techo")
	# Mármol con el ascensor, el vano de la puerta push (x 0,4..3,6) y la 2.ª puerta de ascensor (en mantenimiento).
	Greybox.swall(self, "ParedNucleoS_A", Vector3((-11.0 + PUSH_X0) * 0.5, 1.75, -4), Vector3(PUSH_X0 + 11.0, 3.5, 0.2), "marmol")
	Greybox.swall(self, "ParedNucleoS_B", Vector3((PUSH_X1 + 9.8) * 0.5, 1.75, -4), Vector3(9.8 - PUSH_X1, 3.5, 0.2), "marmol")
	Greybox.sbox(self, "DintelPush", Vector3((PUSH_X0 + PUSH_X1) * 0.5, 3.0, -4), Vector3(PUSH_X1 - PUSH_X0, 1.0, 0.2), "marmol", false)
	Greybox.swall(self, "ParedNucleoW", Vector3(-11.0, 1.75, 0), Vector3(0.2, 3.5, 8.2), "pared", Greybox.AZUL_MARINO)
	Greybox.swall(self, "ParedNucleoNW", Vector3((-11.0 + LOBBY_X0) * 0.5, 1.75, 4.0), Vector3(LOBBY_X0 + 11.0, 3.5, 0.2), "pared", Greybox.AZUL_MARINO)
	add_elevator(Vector3(-3, 0, -2.8), 0.0)
	# 2.ª cabina: bloque de mármol con hojas inox cerradas y el cartel de mantenimiento.
	Greybox.sbox(self, "Ascensor2", Vector3(5.6, 1.3, -2.7), Vector3(2.4, 2.6, 2.6), "marmol")
	for sx in [-0.45, 0.45]:
		Greybox.box(self, "Ascensor2Hoja%d" % int(sx * 10), Vector3(5.6 + sx, 1.15, -1.39), Vector3(0.9, 2.3, 0.03), Greybox.INOX, false).material_override = Greybox.inox()
	Greybox.box(self, "Ascensor2Junta", Vector3(5.6, 1.15, -1.37), Vector3(0.015, 2.3, 0.01), Greybox.NEGRO, false)
	WorldObjects.signage(self, "ELEVATOR_MAINT", Vector3(5.6, 1.5, -1.36), 0.0, 0.2, Greybox.AMBAR)
	add_stairs(Vector3(-8.0, 0, -3.5), 0, 1)
	for x in [-6.0, 0.0, 6.0]:
		Greybox.downlight(self, "DownNucleo%d" % int(x), Vector3(x, 2.88, 0.0), Color(1.0, 0.9, 0.78), 0.8, 6.0)
	Greybox.light_panel(self, "LuzNucleo", Vector3(8.5, 2.75, 2.2), false, true)
	# v0.3.1 pisos: el oeste del núcleo (azul marino, escalera) y el este (2.ª puerta) también con luz: sin el bloque
	# blanco de los baños viejos, el lobby y los molinetes miraban a un fondo más oscuro que en la beta.
	Greybox.light_panel(self, "LuzNucleoW", Vector3(-9.0, 2.75, 1.6), false, false)
	Greybox.light(self, Vector3(7.0, 2.5, -2.4), Color(1.0, 0.92, 0.82), 0.7, 6.0).name = "LuzNucleoE"
	Greybox.light(self, Vector3(-9.6, 2.4, 0.4), Color(0.9, 0.95, 1.0), 1.9, 9.0).name = "LuzNucleoAzul"
	Greybox.light(self, Vector3(2.0, 2.4, -4.6), Color(1.0, 0.92, 0.82), 0.6, 4.5).name = "LuzVestibuloPush"
	SiteProps.fire_cabinet(self, "GabineteIncendio", Vector3(8.2, 1.4, -3.86), 0.0)
	Greybox.extinguisher(self, "ExtintorNucleo", Vector3(9.2, 0, -3.6), 17)
	_push_door()
	# Franja de conexión a oscuras (Joan: «sin grabar»): el rincón x 9,5..11, z 4..5,6 que sale del núcleo junto a la
	# oficina de la recepción, y la «puerta abierta» (z 2,75..5,4) en la pared de la zona de barra; la expendedora va del
	# otro lado de esa pared.
	Greybox.sfloor(self, "Conexion", Vector2(10.25, 4.8), Vector2(1.5, 1.6), "porcelanato_negro")
	Greybox.ceiling(self, "ConexionTecho", Vector2(10.25, 4.8), Vector2(1.5, 1.6), 3.0, Color(0.03, 0.03, 0.035))
	Greybox.swall(self, "ConexionW", Vector3(9.5, 1.75, 4.8), Vector3(0.2, 3.5, 1.8), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "ConexionN", Vector3(10.25, 1.75, 5.6), Vector3(1.7, 3.5, 0.2), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "ParedBarraW", Vector3(REST_X0, 1.75, (-0.75 + ABIERTA_Z0) * 0.5), Vector3(0.2, 3.5, ABIERTA_Z0 + 0.75), "ladrillo_blanco")
	Greybox.box(self, "PuertaAbiertaDintel", Vector3(REST_X0, 3.15, (ABIERTA_Z0 + ABIERTA_Z1) * 0.5), Vector3(0.2, 0.7, ABIERTA_Z1 - ABIERTA_Z0), Greybox.BLANCO_PARED, false)
	Greybox.box(self, "PuertaAbiertaMarco", Vector3(REST_X0, 2.78, (ABIERTA_Z0 + ABIERTA_Z1) * 0.5), Vector3(0.24, 0.05, ABIERTA_Z1 - ABIERTA_Z0), Greybox.MARCO_NEGRO, false)


## Puerta tipo push (Joan): doble hoja de vidrio con marco que se abre al empujarla y vuelve sola. Sin colisión en las
## hojas: el paso nunca queda bloqueado para los bots ni para los cazadores.
func _push_door() -> void:
	var cx := (PUSH_X0 + PUSH_X1) * 0.5
	Greybox.sfloor(self, "VestibuloPush", Vector2(cx, -5.0), Vector2(PUSH_X1 - PUSH_X0, 2.2), "porcelanato_negro")
	Greybox.ceiling(self, "VestibuloPushTecho", Vector2(cx, -5.0), Vector2(PUSH_X1 - PUSH_X0, 2.2), 2.9, Color(0.12, 0.12, 0.13))
	Greybox.swall(self, "VestibuloPushW", Vector3(PUSH_X0 - 0.1, 1.75, -5.0), Vector3(0.2, 3.5, 2.0), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "VestibuloPushE", Vector3(PUSH_X1 + 0.1, 1.75, -5.0), Vector3(0.2, 3.5, 2.0), "pared", Greybox.BLANCO_PARED)
	var pd := _PushDoor.new()
	pd.name = "PuertaPush"
	pd.position = Vector3(cx, 0, CAFE_Z1 + 0.05)
	add_child(pd)
	var w := (PUSH_X1 - PUSH_X0 - 0.2) * 0.5
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Bisagra%d" % int(side)
		hinge.position = Vector3(side * (w + 0.05), 0, 0)
		pd.add_child(hinge)
		var leaf := Greybox.box(hinge, "HojaPush", Vector3(-side * w * 0.5, 1.1, 0), Vector3(w, 2.2, 0.04), Color(0.6, 0.72, 0.75, 0.35), false)
		var marco := Greybox.box(leaf, "Moldura", Vector3(0, 0, 0), Vector3(w + 0.02, 2.2, 0.05), Greybox.MARCO_NEGRO, false)
		marco.scale = Vector3(1, 1, 0.5)
		Greybox.box(leaf, "Placa", Vector3(-side * (w * 0.5 - 0.18), 0.05, 0.03), Vector3(0.22, 0.3, 0.005), Greybox.INOX, false)
		var l := Greybox.label(leaf, "", Vector3(-side * (w * 0.5 - 0.18), 0.4, 0.03), 0.06, Greybox.BLANCO)
		l.text = tr("Q5_PUERTA_PUSH")
		l.outline_size = 0
		pd.hinges.append(hinge)
		pd.signs.append(float(side))
	Greybox.box(self, "PuertaPushDintel", Vector3(cx, 2.55, CAFE_Z1 + 0.05), Vector3(PUSH_X1 - PUSH_X0, 0.3, 0.15), Greybox.MARCO_NEGRO, false)


## Las hojas de la puerta push se abren (hacia el lado contrario al que vienes) cuando alguien pasa cerca y vuelven.
class _PushDoor extends Node3D:
	var hinges: Array[Node3D] = []
	var signs: Array[float] = []
	var _open: float = 0.0
	var _dir: float = 1.0
	var _acc: float = 0.0

	func _near(n: Node3D) -> bool:
		var lp := to_local(n.global_position)
		return absf(lp.x) < 2.2 and absf(lp.z) < 1.6

	func _process(delta: float) -> void:
		_acc += delta
		if _acc < 1.0 / 30.0:
			return
		var dt := _acc
		_acc = 0.0
		var near := false
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null and _near(p):
			near = true
			if _open < 0.05:
				var lz := to_local(p.global_position).z
				_dir = -signf(lz) if lz != 0.0 else 1.0
		if not near:
			for g in ["shero", "rta", "trainer"]:
				for n in get_tree().get_nodes_in_group(g):
					if n is Node3D and _near(n as Node3D):
						near = true
		var prev := _open
		_open = move_toward(_open, 1.0 if near else 0.0, dt * (3.0 if near else 1.2))
		if absf(_open - prev) < 0.0001:
			return
		if prev == 0.0 and _open > 0.0:
			AudioManager.play_sfx("puerta_vidrio")
		for i in hinges.size():
			hinges[i].rotation.y = signs[i] * _dir * _open * deg_to_rad(80.0)


# --- Baños: pasillo de Joan (paso abierto cafetería ↔ zona de bienestar) ---------------------------

func _bathrooms() -> void:
	# Pasillo x 11,4..13, z −6..−1: vinílico claro, pared azul marino con los pictogramas de línea; sin puertas ni
	# muebles en sus extremos (Corregido por Joan 16:19Z). Yendo a la cafetería, los 2 individuales quedan a la derecha
	# (como en el video) y el accesible a la izquierda. Al final, contra la pared, 2 extintores y el tótem.
	var cx := (PASO_X0 + PASO_X1) * 0.5
	var cz := (CAFE_Z1 + BAR_Z0) * 0.5
	Greybox.sfloor(self, "PasilloBanos", Vector2(cx, cz), Vector2(PASO_X1 - PASO_X0, BAR_Z0 - CAFE_Z1), "vinilico_claro")
	Greybox.ceiling(self, "PasilloBanosTecho", Vector2(cx, cz), Vector2(PASO_X1 - PASO_X0, BAR_Z0 - CAFE_Z1), 2.8, Color(0.14, 0.145, 0.15))
	for i in 2:
		Greybox.downlight(self, "DownPasilloBanos%d" % i, Vector3(cx, 2.78, -4.9 + i * 2.6), Color(1.0, 0.95, 0.88), 0.7, 4.5)
	add_bathroom("bano_m1_h", Vector3(13.8, 0, -4.9), Vector2(1.6, 2.2), true, "w")
	add_bathroom("bano_m1_m", Vector3(13.8, 0, -2.6), Vector2(1.6, 2.2), true, "w")
	add_bathroom("bano_m1_acc", Vector3(10.6, 0, -2.85), Vector2(1.6, 4.1), true, "e", -1.2)
	SiteProps.pictogram(self, Vector3(PASO_X1 - 0.04, 1.45, -5.55), -90.0, "circulo")
	SiteProps.pictogram(self, Vector3(PASO_X1 - 0.04, 1.45, -3.25), -90.0, "triangulo")
	SiteProps.pictogram(self, Vector3(PASO_X0 + 0.04, 1.45, -3.0), 90.0, "accesible")
	Greybox.label(self, "H", Vector3(PASO_X1 - 0.05, 2.2, -4.3), 0.25, Greybox.BLANCO, -PI * 0.5)
	Greybox.label(self, "M", Vector3(PASO_X1 - 0.05, 2.2, -2.0), 0.25, Greybox.BLANCO, -PI * 0.5)
	# Azul marino en los tramos sin puertas: cierre de los individuales hacia la barra y del accesible hacia la cafetería.
	Greybox.swall(self, "PasilloBanosE_N", Vector3(PASO_X1 + 0.8, 1.4, -1.25), Vector3(1.8, 2.8, 0.2), "pared", Greybox.AZUL_MARINO)
	Greybox.swall(self, "PasilloBanosW_N", Vector3(10.6, 1.4, -0.75), Vector3(1.8, 2.8, 0.2), "pared", Greybox.AZUL_MARINO)
	Greybox.swall(self, "PasilloBanosW_S", Vector3(PASO_X0, 1.4, -5.45), Vector3(0.2, 2.8, 1.1), "pared", Greybox.AZUL_MARINO)
	# Revestimiento azul marino en la cara del pasillo de la pared de los individuales (las puertas blancas van en él).
	for seg in [[-6.0, -5.38], [-4.42, -3.08], [-2.12, -1.35]]:
		var a: float = seg[0]
		var b2: float = seg[1]
		Greybox.box(self, "RevestimientoAzul%d" % int(-a * 10), Vector3(PASO_X1 - 0.115, 1.4, (a + b2) * 0.5), Vector3(0.02, 2.8, b2 - a), Greybox.AZUL_MARINO, false).material_override = Greybox.surf("pared", Greybox.AZUL_MARINO)
	for k in 2:
		Greybox.extinguisher(self, "ExtintorBanos%d" % k, Vector3(PASO_X1 - 0.25, 0, -5.75 + k * 0.32), 20 + k)
	var totem := Greybox.box(self, "Totem", Vector3(PASO_X0 + 0.22, 0.9, -5.6), Vector3(0.3, 1.8, 0.5), Greybox.NEGRO)
	Greybox.box(totem, "Pantalla", Vector3(0.16, 0.25, 0), Vector3(0.01, 0.8, 0.38), Color(0.85, 0.85, 0.82), false, 0.4)
	Greybox.exit_sign(self, "SalidaBanos", Vector3(cx, 2.55, -5.7), 180.0, 1, true)
	Zone.make(self, "vinilico", Vector3(cx, 1.4, -3.5), Vector3(1.5, 2.8, 4.8))
	OfficeHorror.out_of_order(self, Vector3(PASO_X0 + 0.11, 1.55, -1.6), 90.0)  # en el accesible (que igual abre)


# --- Cafetería (x −15..15, z −17,8..−6): detrás del núcleo, ventanal al patio inglés al sur ---------

func _cafeteria() -> void:
	var cx := (CAFE_X0 + CAFE_X1) * 0.5
	var cz := (CAFE_Z0 + CAFE_Z1) * 0.5
	var sx := CAFE_X1 - CAFE_X0
	var sz := CAFE_Z1 - CAFE_Z0
	var piso := Greybox.sfloor(self, "Cafeteria", Vector2(cx, cz), Vector2(sx, sz), "vinilico_claro")
	piso.name = "Cafeteria"
	Greybox.ceiling(self, "CafeTecho", Vector2(cx, cz), Vector2(sx, sz), 3.5, Color(0.16, 0.165, 0.17))  # techo abierto gris oscuro
	var pared := Color(0.86, 0.86, 0.84)
	# Pared norte (la del núcleo) con la puerta push (x 0,4..3,6) y el paso abierto de los baños (x 11,4..13).
	Greybox.swall(self, "CafeParedN_A", Vector3((CAFE_X0 + PUSH_X0) * 0.5, 1.75, CAFE_Z1), Vector3(PUSH_X0 - CAFE_X0, 3.5, 0.2), "pared", pared)
	Greybox.swall(self, "CafeParedN_B", Vector3((PUSH_X1 + PASO_X0) * 0.5, 1.75, CAFE_Z1), Vector3(PASO_X0 - PUSH_X1, 3.5, 0.2), "pared", pared)
	Greybox.swall(self, "CafeParedN_C", Vector3((PASO_X1 + CAFE_X1) * 0.5, 1.75, CAFE_Z1), Vector3(CAFE_X1 - PASO_X1, 3.5, 0.2), "pared", pared)
	Greybox.swall(self, "CafeParedW", Vector3(CAFE_X0, 1.75, cz), Vector3(0.2, 3.5, sz), "pared", Greybox.TURQUESA)
	Greybox.swall(self, "CafeParedE_N", Vector3(CAFE_X1, 1.75, (CAFE_Z1 - 7.8) * 0.5), Vector3(0.2, 3.5, 7.8 + CAFE_Z1 + 0.2), "pared", pared)
	Greybox.swall(self, "CafeParedE_S", Vector3(CAFE_X1, 1.75, (CAFE_Z0 - 16.8) * 0.5), Vector3(0.2, 3.5, -16.8 - CAFE_Z0 + 0.2), "pared", pared)
	# Franja entre el núcleo y la cafetería (z −6..−4): maciza salvo el vestíbulo de la puerta push.
	Greybox.box(self, "MacizoN_W", Vector3((-11.0 + PUSH_X0) * 0.5 - 0.1, 1.75, -5.0), Vector3(PUSH_X0 + 11.0 - 0.4, 3.5, 1.8), Greybox.CONCRETO, false)
	Greybox.box(self, "MacizoN_E", Vector3((PUSH_X1 + 9.8) * 0.5 + 0.1, 1.75, -5.0), Vector3(9.8 - PUSH_X1 - 0.4, 3.5, 1.8), Greybox.CONCRETO, false)
	# Pared sur: muro bajo, ventanal alto al patio inglés (x −9,6..7,4) con lluvia y plantas a la altura de los ojos.
	Greybox.swall(self, "CafeParedS_Bajo", Vector3(cx, 0.8, CAFE_Z0), Vector3(sx, 1.6, 0.2), "pared", pared)
	Greybox.box(self, "CafeParedS_Alta", Vector3(cx, 3.15, CAFE_Z0), Vector3(sx, 0.7, 0.2), pared).material_override = Greybox.surf("pared", pared)
	for seg in [[CAFE_X0, -9.6], [7.4, CAFE_X1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		Greybox.box(self, "CafeParedS_Lado%d" % int(a), Vector3((a + b) * 0.5, 2.2, CAFE_Z0), Vector3(b - a, 1.2, 0.2), pared).material_override = Greybox.surf("pared", pared)
	var g := Weather.rain_glass(self, "VentanaPatioIngles", Vector3(-1.1, 2.2, CAFE_Z0 + 0.02), Vector2(16.8, 1.2), 0.0)
	g.name = "VentanaPatioIngles"
	Greybox.invisible_box(self, "VentanaCol", Vector3(-1.1, 2.2, CAFE_Z0), Vector3(17.0, 1.2, 0.2))
	Greybox.box(self, "PatioInglesTierra", Vector3(-1.1, 1.5, CAFE_Z0 - 1.0), Vector3(17.0, 0.4, 1.8), Color(0.1, 0.08, 0.06), false)
	for i in 11:
		Greybox.box(self, "PlantaPatio%d" % i, Vector3(-9.0 + i * 1.55, 1.9 + (i % 3) * 0.12, CAFE_Z0 - 0.9), Vector3(0.7, 0.6 + (i % 2) * 0.3, 0.5), Color(0.1, 0.2, 0.09), false)
	Greybox.light(self, Vector3(-1.1, 3.2, CAFE_Z0 - 1.4), Color(0.55, 0.62, 0.72), 0.6, 7.0)  # gris del patio inglés
	# Techo abierto: ductos, tuberías ROJAS de rociadores, LED lineal.
	Greybox.duct(self, "DuctoCafe", Vector3(cx, 3.15, -11.0), sx - 0.6, 0.28, true, Color(0.26, 0.27, 0.28))
	Greybox.duct(self, "DuctoCafe2", Vector3(cx, 3.25, -14.5), sx - 0.6, 0.18, true, Color(0.24, 0.25, 0.26))
	for i in 3:
		Greybox.duct(self, "Viga%d" % i, Vector3(cx, 3.38, -16.0 + i * 4.0), sx - 0.4, 0.04, true, Color(0.718, 0.196, 0.235))
	for i in 3:
		Greybox.box(self, "LedLineal%d" % i, Vector3(-9.0 + i * 9.0, 3.0, -12.6), Vector3(6.0, 0.04, 0.08), Color(0.95, 0.97, 1.0), false, 1.6)
	for x in [-9.0, 0.0, 9.0]:
		Greybox.light(self, Vector3(x, 2.9, -11.5), Color(0.9, 0.95, 1.0), 0.75, 9.0)
	Greybox.exit_sign(self, "SalidaCafe", Vector3(2.0, 2.75, CAFE_Z1 - 0.3), 0.0, 0, true)
	Greybox.light(self, Vector3(6.6, 2.7, -7.6), Color(1.0, 0.95, 0.88), 0.9, 6.5).name = "LuzEstacion"  # microondas y refris
	# Mesas redondas y rectangulares de roble claro con pie negro, sillas negras y campanas negras (x −0,6..9,4), y los
	# 2 bloques de mesas y sillas al fondo (x −13..−3,8).
	var mesas := [Vector3(8.0, 0, -10.6), Vector3(4.5, 0, -10.6), Vector3(1.0, 0, -10.6), Vector3(8.0, 0, -14.4), Vector3(4.5, 0, -14.4), Vector3(1.0, 0, -14.4), Vector3(-5.4, 0, -15.4), Vector3(-11.2, 0, -15.4)]
	for i in mesas.size():
		var m: Vector3 = mesas[i]
		var round_t := i % 2 == 0 and i < 6
		if round_t:
			Greybox.cylinder(self, "Mesa%d" % i, m + Vector3(0, 0.74, 0), 0.6, 0.05, Greybox.MADERA, true).material_override = Greybox.surf("roble")
			Greybox.cylinder(self, "MesaPie%d" % i, m + Vector3(0, 0.36, 0), 0.05, 0.72, Greybox.NEGRO)
		else:
			Greybox.box(self, "Mesa%d" % i, m + Vector3(0, 0.74, 0), Vector3(1.6 if i < 6 else 2.6, 0.05, 0.8), Greybox.MADERA).material_override = Greybox.surf("roble")
			Greybox.box(self, "MesaPata%d" % i, m + Vector3(0, 0.36, 0), Vector3(1.2 if i < 6 else 2.2, 0.72, 0.08), Greybox.NEGRO, false)
		var chairs := 2 if i < 6 else 6
		for k in chairs:
			var off := (k / 2 - (chairs / 2 - 1) * 0.5) * 0.85 if chairs > 2 else 0.0
			var sz2 := m.z + (0.95 if k % 2 == 0 else -0.95)
			var px := m.x + off
			Greybox.box(self, "Silla%d_%d" % [i, k], Vector3(px, 0.45, sz2), Vector3(0.42, 0.05, 0.42), Greybox.NEGRO, false)
			Greybox.box(self, "SillaResp%d_%d" % [i, k], Vector3(px, 0.72, sz2 + (0.2 if k % 2 == 0 else -0.2)), Vector3(0.42, 0.5, 0.04), Greybox.NEGRO, false)
			for leg in 4:
				Greybox.cylinder(self, "SillaPata%d_%d_%d" % [i, k, leg], Vector3(px + (0.17 if leg % 2 == 0 else -0.17), 0.22, sz2 + (0.17 if leg < 2 else -0.17)), 0.012, 0.44, Greybox.NEGRO, false, 0.5, 0.2)
		Greybox.pendant_lamp(self, "Lampara%d" % i, m + Vector3(0, 2.5, 0), Greybox.AMBAR, 1.0 if i < 6 else 0.8)
	# Listones de madera (tabique de la zona de mesas) y carros bandejeros junto a la puerta push.
	for i in 7:
		Greybox.box(self, "Liston%d" % i, Vector3(-1.4 - i * 0.4, 1.4, -12.7), Vector3(0.1, 2.8, 0.06), Greybox.MADERA, false).material_override = Greybox.surf("roble", Color(0.85, 0.75, 0.62))
	SiteProps.tray_rack(self, "CarroBandejas0", Vector3(-1.2, 0, -7.6), 0.0)
	SiteProps.tray_rack(self, "CarroBandejas1", Vector3(-2.1, 0, -7.65), 6.0)
	SiteProps.tray_rack(self, "CarroBandejas2", Vector3(-3.0, 0, -7.55), -4.0)
	_armchairs()
	_station()
	_food_counter()
	_closed_counter()
	_rest_vending()
	# v0.3.2 (Joan): sin terminal Fonex en la cafetería (el AUX solo en las PCs de la sala o con el comodín).
	Greybox.extinguisher(self, "ExtintorCafe0", Vector3(CAFE_X0 + 0.3, 0, -16.9), 18)
	Greybox.extinguisher(self, "ExtintorCafe1", Vector3(CAFE_X0 + 0.3, 0, -16.45), 19)
	SiteProps.bats(self, "MurcielagoCafe", Vector3(cx, 0, cz), Vector2(24.0, 9.0), 10, 3.4, 23)
	OfficeHorror.moldy_cup(self, Vector3(4.2, 0.765, -10.4))
	OfficeHorror.sticky(self, "Q5_H_NOTA_6", Vector3(1.0, 0.77, -14.3), 0.0, true).rotation_degrees.x = -80.0
	OfficeHorror.tube(self, "TuboMuertoCafe", Vector3(-9.0, 3.2, -9.0), true, false)
	OfficeHorror.tube(self, "TuboTartamudoCafe", Vector3(12.5, 3.2, -15.5), true, true)
	Greybox.marker(self, "cafeteria", Vector3(0, 0, -11.8), 0.0)
	Zone.make(self, "vinilico", Vector3(cx, 1.5, cz), Vector3(sx, 3, sz))  # C15: vinílico claro de la cafetería


## Sillones con mesa (x −15..−6, z −11..−6): sofás gris y rojo contra la pared norte (SleepSpot), mesas bajas, butacas.
func _armchairs() -> void:
	var sofas := [["SofaGris", Vector3(-8.0, 0.4, -6.65), Greybox.GRIS], ["SofaRojo", Vector3(-12.0, 0.4, -6.65), Color(0.48, 0.13, 0.13)]]
	for s in sofas:
		var p: Vector3 = s[1]
		Greybox.box(self, str(s[0]), p, Vector3(2.5, 0.8, 0.9), s[2])
		Greybox.box(self, str(s[0]) + "Resp", p + Vector3(0, 0.6, 0.38), Vector3(2.5, 0.5, 0.15), s[2], false)
		Greybox.box(self, "MesaBaja%d" % int(-p.x), Vector3(p.x, 0.22, -9.6), Vector3(1.2, 0.44, 0.6), Color(0.75, 0.66, 0.52)).material_override = Greybox.surf("roble")
	for bx in [-6.0, -14.2]:
		Greybox.box(self, "Butaca%d" % int(-bx), Vector3(bx, 0.4, -9.2), Vector3(0.8, 0.8, 0.8), Color(0.78, 0.76, 0.7))
	Greybox.box(self, "ParedMenta", Vector3(-10.0, 0.8, CAFE_Z1 - 0.12), Vector3(8.0, 1.6, 0.02), Greybox.MENTA, false)
	# v0.3: los sofás sirven para dormir (lunch, PLAN §2 #30). Al despertar sales hacia el salón (−Z), entre las mesas bajas.
	SleepSpot.make(self, "sofa_gris", Vector3(-8.0, 0.75, -6.8), Vector3(2.5, 0.8, 0.9), 0.78, 180.0, Vector3(-9.7, 0, -8.6))
	SleepSpot.make(self, "sofa_rojo", Vector3(-12.0, 0.75, -6.8), Vector3(2.5, 0.8, 0.9), 0.78, 180.0, Vector3(-10.3, 0, -8.6))
	OfficeHorror.headset(self, Vector3(-12.4, 0.44, -9.32), 0.0)


## Estación de refris, microondas y lavadero (D4/D5) contra la pared norte, mirando a la cafetería (Joan).
func _station() -> void:
	Greybox.box(self, "ParedEstacion", Vector3(6.75, 1.4, CAFE_Z1 - 0.115), Vector3(5.3, 2.8, 0.02), Greybox.TEAL, false)
	SiteProps.fridge(self, "RefriM1_1", Vector3(8.75, 0, -6.5), 180.0)
	SiteProps.fridge(self, "RefriM1_2", Vector3(8.0, 0, -6.5), 180.0)
	SiteProps.microwave_bank(self, Vector3(6.5, 0, -6.45), 180.0, "Microondas")
	SiteProps.sink(self, "Lavadero", Vector3(4.8, 0, -6.45), 180.0)
	Greybox.marker(self, "refri_m1", Vector3(8.3, 0, -7.5), 0.0)
	Greybox.marker(self, "microondas_m1", Vector3(6.5, 0, -7.4), 0.0)
	Greybox.marker(self, "lavadero_m1", Vector3(4.8, 0, -7.3), 0.0)
	Greybox.bin(self, "PapeleraGabinete", Vector3(9.6, 0, -6.5), true)


## Zona donde atienden y despachan comida (Joan): mostrador largo de frente azul y celeste con vitrina caliente, y la
## cocina detrás (x 15,1..18,7). Cerrado (T1-T2) con reja; abierto (T3+) atiende Marleny.
func _food_counter() -> void:
	var kz := (-16.8 + -7.8) * 0.5
	Greybox.sfloor(self, "CocinaPiso", Vector2(16.9, kz), Vector2(3.6, 9.0), "porcelanato_gris")
	Greybox.ceiling(self, "CocinaTecho", Vector2(16.9, kz), Vector2(3.6, 9.0), 3.0, Color(0.2, 0.2, 0.21))
	Greybox.swall(self, "CocinaE", Vector3(18.7, 1.75, kz), Vector3(0.2, 3.5, 9.2), "ceramica_blanca")
	Greybox.swall(self, "CocinaN", Vector3(16.9, 1.75, -7.8), Vector3(3.8, 3.5, 0.2), "pared", Color(0.86, 0.86, 0.84))
	Greybox.swall(self, "CocinaS", Vector3(16.9, 1.75, -16.8), Vector3(3.8, 3.5, 0.2), "pared", Color(0.86, 0.86, 0.84))
	for k in 3:
		Greybox.box(self, "RepisaCocina%d" % k, Vector3(18.45, 1.2 + k * 0.45, kz), Vector3(0.4, 0.04, 6.0), Greybox.INOX, false).material_override = Greybox.inox()
	Greybox.box(self, "Plancha", Vector3(18.3, 0.45, kz - 2.5), Vector3(0.7, 0.9, 1.6), Greybox.INOX).material_override = Greybox.inox()
	var abierto := GameState.turno >= int(DataLoader.bal("economia/cafeteria_marleny/turno_desde", 3))
	var mx := 15.3
	var most := Greybox.box(self, "Mostrador", Vector3(mx, 0.55, -12.3), Vector3(0.8, 1.1, 4.8), Color(0.15, 0.35, 0.6))
	most.material_override = Greybox.material(Color(0.15, 0.33, 0.55), 0.0, 0.6)
	Greybox.box(self, "MostradorFranja", Vector3(mx - 0.405, 0.35, -12.3), Vector3(0.01, 0.25, 4.8), Color(0.45, 0.7, 0.85), false)
	var vit := Greybox.cylinder(self, "VitrinaCurva", Vector3(mx, 1.3, -13.3), 0.35, 1.6, Color(0.7, 0.82, 0.86, 0.3), false, 0.1, 0.2)
	vit.rotation_degrees.x = 90.0
	vit.scale = Vector3(0.8, 1, 1)
	for i in 3:
		Greybox.box(self, "Jaba%d" % i, Vector3(mx + 0.1, 1.2 + i * 0.26, -10.6), Vector3(0.36, 0.24, 0.5), Color(0.9, 0.45, 0.1), false)
	Greybox.light(self, Vector3(16.5, 2.6, -12.3), Color(1.0, 0.8, 0.55), 1.2 if abierto else 0.35, 5.5)
	if abierto:
		Greybox.box(self, "RejaArriba", Vector3(mx, 3.2, -12.3), Vector3(0.05, 0.3, 4.8), Color(0.3, 0.3, 0.3, 0.6), false)
		Greybox.box(self, "Olla", Vector3(mx + 0.2, 1.25, -11.3), Vector3(0.5, 0.3, 0.5), Greybox.INOX, false)
		Greybox.box(self, "Termo", Vector3(mx + 0.2, 1.3, -11.9), Vector3(0.25, 0.4, 0.25), Greybox.INOX, false)
		WorldObjects.signage(self, "SIGN_CAFETERIA_OPEN", Vector3(mx - 0.45, 2.4, -12.3), -90.0, 0.2, Greybox.AMBAR)
		var marleny := NpcFigure.make(self, "agente_jiroshi", Vector3(16.3, 0, -12.3), 90.0, 1.62, Color(0.88, 0.86, 0.8), "Marleny")
		marleny.look_radius = 5.0
		marleny.look_max_deg = 50.0
		marleny.anim_speed = 0.8
		Greybox.box(self, "GorroMarleny", Vector3(16.3, 1.68, -12.3), Vector3(0.24, 0.08, 0.24), Greybox.BLANCO, false)
		WorldObjects.simple(self, WorldObjects.Counter, "MostradorMarleny", "HUD_COUNTER", Vector3(mx - 0.55, 1.0, -12.3), Vector3(0.3, 1.0, 2.2), Color(0.45, 0.33, 0.20, 0.0))
	else:
		Greybox.box(self, "Reja", Vector3(mx - 0.42, 2.2, -12.3), Vector3(0.05, 2.2, 4.8), Color(0.3, 0.3, 0.3, 0.6), false)
		WorldObjects.signage(self, "SIGN_CAFETERIA_CLOSED", Vector3(mx - 0.47, 2.0, -12.3), -90.0, 0.2, Greybox.AMBAR)


## El otro mostrador del plano (sin confirmar): kiosko cerrado con la persiana metálica baja.
func _closed_counter() -> void:
	Greybox.box(self, "KioskoCerrado", Vector3(-4.9, 0.55, -8.4), Vector3(1.6, 1.1, 3.8), Color(0.45, 0.7, 0.85)).material_override = Greybox.material(Color(0.42, 0.66, 0.8), 0.0, 0.6)
	var persiana := Greybox.box(self, "KioskoPersiana", Vector3(-4.9, 1.75, -8.4), Vector3(1.5, 1.3, 3.7), Color(0.5, 0.5, 0.52), false)
	persiana.material_override = Greybox.surf("persiana", Color(0.6, 0.6, 0.62))
	OfficeHorror.sticky(self, "Q5_H_NOTA_1", Vector3(-5.71, 1.6, -8.0), -90.0, false, -5.0)


## Expendedora: pegada a la pared de la zona de barra que da al núcleo, mirando a la barra (Corregido por Joan 16:19Z),
## fuera de la boca del pasillo de baños. Las pruebas y los bots la buscan por nombre («Expendedora»).
func _rest_vending() -> void:
	var v := WorldObjects.simple(self, WorldObjects.Vending, "Expendedora", "HUD_VENDING", Vector3(11.6, 1.0, 1.0), Vector3(1.0, 2.0, 0.8), Color(0.2, 0.35, 0.4), 180.0, 0.6)
	Greybox.box(v, "Vitrina", Vector3(-0.41, 0.2, 0.0), Vector3(0.02, 1.3, 0.62), Color(0.75, 0.9, 0.95), false, 1.4)
	for k in 4:
		Greybox.box(v, "Fila%d" % k, Vector3(-0.38, -0.3 + k * 0.3, 0), Vector3(0.05, 0.03, 0.58), Color(0.9, 0.6, 0.2) if k % 2 == 0 else Color(0.3, 0.6, 0.85), false, 0.5)


# --- Zona de bienestar y descanso (al lado del lobby): lounge, gradería, kitchenette, barra alta, descanso -----------

func _rest_zone() -> void:
	var gris := Greybox.surf("porcelanato_gris", Color(0.78, 0.78, 0.78))
	var p1 := Greybox.sfloor(self, "BienestarPiso", Vector2((REST_X0 + REST_X1) * 0.5, (BAR_Z0 + DESC_Z1) * 0.5), Vector2(REST_X1 - REST_X0, DESC_Z1 - BAR_Z0), "porcelanato_gris")
	p1.material_override = gris
	var p2 := Greybox.sfloor(self, "LoungePiso", Vector2((LOUNGE_X0 + REST_X1) * 0.5, (CAFE_Z1 + BAR_Z0) * 0.5), Vector2(REST_X1 - LOUNGE_X0, BAR_Z0 - CAFE_Z1), "porcelanato_gris")
	p2.material_override = Greybox.surf("porcelanato_gris", Color(0.5, 0.5, 0.52))
	Greybox.ceiling(self, "BienestarTecho", Vector2((REST_X0 + REST_X1) * 0.5, (CAFE_Z1 + DESC_Z1) * 0.5), Vector2(REST_X1 - REST_X0, DESC_Z1 - CAFE_Z1), 3.3, Color(0.09, 0.09, 0.1))
	Greybox.duct(self, "DuctoBienestar", Vector3(16.2, 3.05, 4.0), 18.0, 0.25, false, Color(0.2, 0.21, 0.22))
	# Muros: exterior (x 21,3), sur del lounge (z −6), este del lounge (hacia los baños) y la pared hacia el núcleo y
	# la oficina detrás de la recepción (x 11, z 4..14).
	Greybox.swall(self, "BienestarE", Vector3(REST_X1, 1.65, (CAFE_Z1 + DESC_Z1) * 0.5), Vector3(0.2, 3.3, DESC_Z1 - CAFE_Z1 + 0.2), "ladrillo_blanco")
	Greybox.swall(self, "LoungeS", Vector3((LOUNGE_X0 + REST_X1) * 0.5, 1.65, CAFE_Z1), Vector3(REST_X1 - LOUNGE_X0, 3.3, 0.2), "pared", Color(0.3, 0.3, 0.32))
	Greybox.swall(self, "LoungeW", Vector3(LOUNGE_X0 + 0.1, 1.65, (CAFE_Z1 + BAR_Z0) * 0.5 - 0.15), Vector3(0.2, 3.3, BAR_Z0 - CAFE_Z1 - 0.3), "pared", Color(0.3, 0.3, 0.32))
	Greybox.swall(self, "DescansoW", Vector3(REST_X0, 1.65, (ABIERTA_Z1 + DESC_Z1) * 0.5 + 0.05), Vector3(0.2, 3.3, DESC_Z1 - ABIERTA_Z1 + 0.1), "ladrillo_blanco")
	_lounge()
	_kitchenette()
	_bar()
	_descanso()
	Zone.make(self, "descanso_m1", Vector3((REST_X0 + REST_X1) * 0.5, 1.4, (DESC_Z0 + DESC_Z1) * 0.5), Vector3(REST_X1 - REST_X0 - 0.2, 2.8, DESC_Z1 - DESC_Z0 - 0.2))


## Lounge a oscuras (x 14,6..21,3, z −6..−1): sofás, TV apagado, casi sin luz. Se entra pasando junto a la gradería.
func _lounge() -> void:
	for i in 2:
		var sx := 18.4 - i * 2.0
		Greybox.box(self, "SofaLounge%d" % i, Vector3(sx, 0.38, -3.6), Vector3(0.9, 0.76, 2.2), Color(0.62, 0.62, 0.6))
		Greybox.box(self, "SofaLoungeResp%d" % i, Vector3(sx - 0.4, 0.85, -3.6), Vector3(0.14, 0.5, 2.2), Color(0.6, 0.6, 0.58), false)
	Greybox.box(self, "TVLounge", Vector3(REST_X1 - 0.14, 1.6, -3.6), Vector3(0.05, 0.9, 1.6), Color(0.02, 0.02, 0.025), false, 0.03)
	Greybox.box(self, "MesaLounge", Vector3(19.8, 0.22, -3.6), Vector3(0.6, 0.44, 1.0), Greybox.GRIS_OSCURO)
	var l := Greybox.light(self, Vector3(17.0, 2.4, -3.5), Color(0.55, 0.6, 0.75), 0.18, 5.0)
	l.name = "LuzLounge"
	OfficeHorror.chair_to_wall(self, Vector3(20.7, 0, -5.4), -140.0)


## Kitchenette (x 17,7..21,2, z 2,2..5,6): barra blanca con base de madera, pared teal, 2 extintores, downlights.
func _kitchenette() -> void:
	Greybox.box(self, "ParedTeal", Vector3(REST_X1 - 0.12, 1.5, 3.9), Vector3(0.02, 3.0, 3.6), Greybox.TEAL, false)
	var barra := Greybox.box(self, "BarraKitchenette", Vector3(18.3, 0.5, 3.9), Vector3(0.6, 1.0, 3.0), Color(0.78, 0.68, 0.52))
	barra.material_override = Greybox.surf("roble", Color(0.95, 0.9, 0.82))
	Greybox.box(self, "BarraKitchenetteTope", Vector3(18.3, 1.02, 3.9), Vector3(0.66, 0.04, 3.1), Greybox.BLANCO, false)
	Greybox.box(self, "MuebleAlto", Vector3(REST_X1 - 0.35, 1.9, 3.9), Vector3(0.5, 0.7, 3.0), Greybox.BLANCO, false)
	Greybox.box(self, "MesadaKitchenette", Vector3(REST_X1 - 0.4, 0.45, 3.9), Vector3(0.6, 0.9, 3.0), Greybox.BLANCO)
	for k in 2:
		Greybox.extinguisher(self, "ExtintorKitchenette%d" % k, Vector3(REST_X1 - 0.3, 0, 5.75 + k * 0.32), 23 + k)
	for i in 3:
		Greybox.downlight(self, "DownKitchenette%d" % i, Vector3(19.4, 3.25, 2.9 + i * 1.0), Color(1.0, 0.92, 0.8), 0.6, 4.5, i == 1)
	OfficeHorror.moldy_cup(self, Vector3(18.2, 1.04, 3.2))


## Zona de barra alta (x 11..17,5, z −1..5,4): barra larga con banquetas negras, tabique de listones, gradería de madera
## (x 17,7..21,2, z −1,35..2,15) que baja hacia el lounge, campanas negras. La expendedora contra la pared del núcleo.
func _bar() -> void:
	var b := Greybox.box(self, "BarraAlta", Vector3(14.1, 1.05, 2.15), Vector3(0.8, 0.05, 4.4), Color(0.7, 0.6, 0.46))
	b.material_override = Greybox.surf("roble", Color(0.9, 0.82, 0.7))
	Greybox.box(self, "BarraAltaBase", Vector3(14.1, 0.52, 2.15), Vector3(0.5, 1.04, 4.2), Greybox.BLANCO_PARED)
	for i in 5:
		for side in [-1.0, 1.0]:
			var z := 0.45 + i * 0.85
			var x: float = 14.1 + side * 0.7
			Greybox.cylinder(self, "Banqueta%d_%d" % [i, int(side)], Vector3(x, 0.74, z), 0.18, 0.05, Greybox.NEGRO, false)
			Greybox.box(self, "BanquetaResp%d_%d" % [i, int(side)], Vector3(x + side * 0.17, 0.95, z), Vector3(0.03, 0.4, 0.34), Greybox.NEGRO, false)
			Greybox.cylinder(self, "BanquetaPie%d_%d" % [i, int(side)], Vector3(x, 0.37, z), 0.02, 0.74, Greybox.NEGRO, false)
	for i in 2:
		Greybox.pendant_lamp(self, "LamparaBarra%d" % i, Vector3(14.1, 2.5, 1.0 + i * 2.4), Greybox.AMBAR, 0.9)
	# Tabique de listones de madera entre la barra y la gradería.
	for i in 12:
		Greybox.box(self, "ListonBarra%d" % i, Vector3(17.4, 1.5, -0.9 + i * 0.28), Vector3(0.06, 3.0, 0.1), Greybox.MADERA, false).material_override = Greybox.surf("roble", Color(0.85, 0.75, 0.62))
	# Gradería de madera: 3 escalones (visuales) sobre un bloque macizo (no se sube: nada de caídas por el borde).
	for k in 3:
		var w := 3.5 - k * 1.1
		var st := Greybox.box(self, "Graderia%d" % k, Vector3(REST_X1 - 0.1 - w * 0.5, 0.2 + k * 0.4, 0.4), Vector3(w, 0.4, 3.5), Color(0.7, 0.55, 0.38), false)
		st.material_override = Greybox.surf("roble", Color(0.85, 0.72, 0.55))
	Greybox.invisible_box(self, "GraderiaCol", Vector3(19.45, 0.65, 0.4), Vector3(3.5, 1.3, 3.5))
	Greybox.light(self, Vector3(14.5, 2.6, 2.0), Color(1.0, 0.82, 0.6), 0.75, 7.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_2", Vector3(14.5, 1.08, 3.6), 0.0, true).rotation_degrees.x = -80.0


## Descanso (x 11..21,3, z 5,4..13,95): ladrillo blanco con TV, ping-pong NEGRO, puffs AZULES para dormir, butacas,
## ventanal arriba (al patio). Luz cálida baja.
func _descanso() -> void:
	var pp := Vector3(16.6, 0, 8.6)
	Greybox.box(self, "PingPong", pp + Vector3(0, 0.74, 0), Vector3(1.52, 0.04, 2.74), Color(0.06, 0.06, 0.07))
	Greybox.box(self, "PingPongLinea", pp + Vector3(0, 0.763, 0), Vector3(0.02, 0.005, 2.7), Greybox.BLANCO, false)
	Greybox.box(self, "PingPongRed", pp + Vector3(0, 0.83, 0), Vector3(1.62, 0.15, 0.02), Greybox.BLANCO, false)
	Greybox.box(self, "PingPongPata", pp + Vector3(0, 0.37, 0), Vector3(1.0, 0.72, 2.2), Greybox.GRIS_OSCURO)
	Greybox.cylinder(self, "Paleta1", pp + Vector3(0.3, 0.77, -0.9), 0.08, 0.012, Greybox.ROJO)
	Greybox.cylinder(self, "Paleta2", pp + Vector3(-0.4, 0.77, 1.1), 0.08, 0.012, Greybox.NEGRO)
	var pelota := Greybox.cylinder(self, "Pelota", pp + Vector3(-0.35, 0.78, 0.4), 0.02, 0.04, Greybox.BLANCO)
	pelota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(self, "TV", Vector3(REST_X1 - 0.14, 1.75, 9.4), Vector3(0.05, 0.9, 1.6), Color(0.02, 0.02, 0.025), false, 0.05)
	for z in [7.0, 11.0]:
		Greybox.box(self, "RielSpots%d" % int(z), Vector3(16.2, 3.0, z), Vector3(9.0, 0.04, 0.04), Greybox.NEGRO, false)
	# Puffs AZULES en fila bajo el ventanal (dormir; en el site la gente duerme encima). Al despertar sales hacia la
	# sala (−Z), a piso libre lejos de la mesa de ping-pong (el arreglo del puff atascado de Joan).
	var puffs := [[Vector3(19.8, 0, 12.6), 180.0, Vector3(18.8, 0, 11.4)], [Vector3(17.8, 0, 12.6), 180.0, Vector3(16.8, 0, 11.4)], [Vector3(15.8, 0, 12.6), 180.0, Vector3(14.8, 0, 11.4)], [Vector3(13.8, 0, 12.6), 180.0, Vector3(12.8, 0, 11.4)]]
	for i in puffs.size():
		var p: Vector3 = puffs[i][0]
		Greybox.cylinder(self, "Puff%d" % i, p + Vector3(0, 0.22, 0), 0.45, 0.44, Color(0.14, 0.26, 0.5) if i % 2 == 0 else Color(0.18, 0.3, 0.56), true, 1.0, 0.0, 0.38)
		SleepSpot.make(self, "puff_%d" % i, p + Vector3(0, 0.5, 0), Vector3(0.9, 0.5, 0.9), 0.62, float(puffs[i][1]), puffs[i][2])
	var bulto := Greybox.box(self, "BultoPuff", Vector3(15.8, 0.55, 12.65), Vector3(0.7, 0.25, 0.4), Color(0.06, 0.06, 0.07), false)
	bulto.rotation_degrees.y = 30.0 + 40.0 * (GameState.turno % 3)
	Greybox.box(self, "Butaca", Vector3(20.5, 0.4, 7.0), Vector3(0.8, 0.8, 0.8), Color(0.78, 0.76, 0.7))
	Greybox.box(self, "Butaca2", Vector3(12.0, 0.4, 7.2), Vector3(0.8, 0.8, 0.8), Color(0.78, 0.76, 0.7))
	Greybox.box(self, "MacetaDescanso", Vector3(11.6, 0.3, 13.3), Vector3(0.45, 0.6, 0.45), Greybox.GRIS_OSCURO)
	Greybox.box(self, "PlantaDescanso", Vector3(11.6, 0.95, 13.3), Vector3(0.7, 0.8, 0.7), Color(0.16, 0.24, 0.12), false)
	# Ventanal arriba (al patio, de noche negro con lluvia) con persianas, sobre un antepecho de ladrillo.
	Greybox.swall(self, "DescansoN_Bajo", Vector3((REST_X0 + REST_X1) * 0.5, 0.6, DESC_Z1), Vector3(REST_X1 - REST_X0, 1.2, 0.2), "ladrillo_blanco")
	Greybox.box(self, "DescansoN_Alto", Vector3((REST_X0 + REST_X1) * 0.5, 2.95, DESC_Z1), Vector3(REST_X1 - REST_X0, 0.7, 0.2), Greybox.BLANCO_PARED, false).material_override = Greybox.surf("ladrillo_blanco")
	Greybox.invisible_box(self, "VentanalDescansoCol", Vector3((REST_X0 + REST_X1) * 0.5, 1.9, DESC_Z1 + 0.05), Vector3(REST_X1 - REST_X0, 1.4, 0.2))
	for i in 4:
		var wx := 12.6 + i * 2.5
		Weather.rain_glass(self, "VentanaDescanso%d" % i, Vector3(wx, 1.9, DESC_Z1 - 0.02), Vector2(2.3, 1.2), 180.0)
		SiteProps.blind(self, "PersianaDescanso%d" % i, Vector3(wx, 2.55, DESC_Z1 - 0.12), 2.3, [0.3, 0.6, 0.2, 0.75][i], 180.0)
		Greybox.box(self, "MontanteDescanso%d" % i, Vector3(wx + 1.25, 1.9, DESC_Z1), Vector3(0.08, 1.2, 0.12), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "PatioDescanso", Vector3(16.2, 1.25, DESC_Z1 + 0.6), Vector3(10.0, 0.5, 1.0), Color(0.08, 0.07, 0.06), false)
	Greybox.pendant_lamp(self, "LamparaDescanso", pp + Vector3(0, 2.25, 0), Greybox.AMBAR, 2.2)
	Greybox.light_panel(self, "LuzDescanso", Vector3(13.5, 3.15, 8.0), false, true)  # un fluorescente que falla
	Greybox.light(self, Vector3(13.5, 0.8, 11.6), Color(0.95, 0.55, 0.3), 1.0, 4.5)
	var relleno := Greybox.light(self, Vector3(16.5, 2.5, 8.0), Color(1.0, 0.76, 0.52), 0.9, 8.5)
	relleno.name = "LuzDescansoRelleno"
	WorldObjects.signage(self, "SIGN_REST", Vector3(16.2, 2.75, DESC_Z1 - 0.13), 180.0, 0.22, Greybox.AMBAR)
	HorrorProps.sinister_poster(self, "POSTER_REST", "POSTER_REST_DARK", Vector3(REST_X1 - 0.14, 1.6, 11.8), -90.0, 0.16, 1.4)
	HorrorProps.note(self, "NOTE_PUFF", Vector3(19.2, 0.62, 11.9), 0.0, true, 12.0)
	OfficeHorror.stained_tile(self, Vector3(13.0, 3.24, 6.2), Vector2(1.0, 0.8))
	Greybox.marker(self, "descanso_m1", Vector3(14.4, 0, 9.5), 90.0)


## Exterior (J #52): lluvia, más faroles, vereda de enfrente, ciudad, relámpagos y el bus.
func _exterior() -> void:
	var sy := STREET_Y
	Weather.rain(self, Vector3(0, 0, 23.5), Vector3(34, sy + 9, 21))
	for pz in [[Vector3(-4.5, sy + 0.012, 22.8), Vector2(2.6, 1.4)], [Vector3(5.5, sy + 0.012, 24.4), Vector2(3.2, 1.6)], [Vector3(-9.0, sy - 0.11, 28.0), Vector2(4.0, 2.0)], [Vector3(11.5, sy - 0.11, 30.5), Vector2(3.0, 1.5)], [Vector3(1.5, sy - 0.11, 30.0), Vector2(2.2, 1.2)]]:
		Weather.puddle(self, pz[0], pz[1])
	# Vereda de enfrente y faroles de sodio (fuera del límite: solo se ven).
	Greybox.box(self, "VeredaEnfrente", Vector3(0, sy - 0.06, 34.5), Vector3(60, 0.1, 3), Color(0.12, 0.12, 0.13), false)
	Greybox.box(self, "PistaLejos", Vector3(0, sy - 0.13, 29), Vector3(120, 0.1, 8), Color(0.065, 0.065, 0.07), false)
	for lx in [-26.0, -13.0, 0.0, 13.0, 26.0]:
		Greybox.cylinder(self, "FarolEnfrente%d" % int(lx + 30), Vector3(lx, sy + 3.0, 34.2), 0.08, 6.0, Greybox.GRIS_OSCURO)
		Greybox.box(self, "FarolBrazo%d" % int(lx + 30), Vector3(lx, sy + 5.95, 33.4), Vector3(0.12, 0.1, 1.6), Greybox.GRIS_OSCURO, false)
		Greybox.box(self, "FarolCabeza%d" % int(lx + 30), Vector3(lx, sy + 5.88, 32.7), Vector3(0.5, 0.12, 0.3), Color(1.0, 0.72, 0.38), false, 3.0)
		if absf(lx) < 20.0:
			Greybox.light(self, Vector3(lx, sy + 5.4, 32.6), Color(1.0, 0.66, 0.34), 2.4, 13.0)
	for i in 5:
		var sx := -24.0 + i * 12.0
		Greybox.box(self, "Local%d" % i, Vector3(sx, sy + 2.0, 37.5), Vector3(10.5, 4.0, 3.0), Color(0.07, 0.07, 0.08), false)
		Greybox.box(self, "Reja%d" % i, Vector3(sx, sy + 1.4, 35.95), Vector3(9.0, 2.6, 0.05), Color(0.2, 0.2, 0.21), false)
	var farmacia := Greybox.label(self, "", Vector3(12.0, sy + 3.4, 35.9), 0.35, Color(0.45, 0.95, 0.6))
	farmacia.text = tr("SIGN_STREET_SHOP")
	var ff := _LetterFlicker.new()
	ff.label = farmacia
	farmacia.add_child(ff)
	Weather.skyline(self, 47, -90.0, 90.0, 48.0, 85.0, sy - 0.1, 30, 10.0, 46.0, 0.3)
	# Al este, la autopista elevada pasa por encima de la avenida (puente), con su rumor de faros y camiones,
	# torres de iluminación, alta tensión y los cerros pelados detrás de la garúa (ref. del entorno, genérico).
	SiteProps.entorno_este(self, sy, 72.0, 29.0, -160.0, 200.0, 480.0)
	Weather.lightning(self, Vector3(-20, 40, 70), 6.0, 120.0)
	# Bus: te deja al llegar (23:48) y te espera al salir (08:45).
	if GameState.shift_over:
		Bus.make(self, Bus.Mode.SALIDA)
	elif not GameState.logged_in and not bool(GameState.flags.get("bus_llegada_visto", false)):
		GameState.flags["bus_llegada_visto"] = true
		Bus.make(self, Bus.Mode.LLEGADA)
	EventBus.shift_ended.connect(_on_shift_ended_bus)


func _on_shift_ended_bus() -> void:
	if find_child("Bus", false, false) == null:
		Bus.make(self, Bus.Mode.SALIDA)


## Piso -1: exterior con bruma de madrugada; el ámbar lo ponen las luces. Al salir (08:45) la neblina de Lima.
func env_settings() -> Dictionary:
	if GameState.shift_over:
		return {
			"ambient": Color(0.3, 0.33, 0.37), "ambient_energy": 0.62,
			"fog": Color(0.15, 0.16, 0.18), "fog_density": 0.024, "bg": Color(0.13, 0.14, 0.16),
		}
	return {
		"ambient": Color(0.24, 0.29, 0.36), "ambient_energy": 0.62,
		"fog": Color(0.055, 0.065, 0.08), "fog_density": 0.019, "bg": Color(0.045, 0.055, 0.07),
	}


func grading() -> Dictionary:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var pos := p.global_position - global_position if p != null else Vector3.ZERO
	if pos.z > 14.2:
		return {"tint": Color(0.88, 0.96, 1.08), "sat": 0.68, "contrast": 1.06, "exterior": true}
	if pos.x > REST_X0 and pos.z > BAR_Z0:
		return {"tint": Color(1.04, 0.97, 0.86), "sat": 0.66, "contrast": 1.1, "exterior": false}  # descanso: ámbar
	return {"tint": Color(0.92, 1.0, 0.95), "sat": 0.72, "contrast": 1.08, "exterior": false}


func ambience_events() -> Array[String]:
	return ["pa", "susurro", "silencio", "llanto"]


func ambience_points() -> Array[Vector3]:
	return [Vector3(12.2, 1.5, -3.5), Vector3(17.5, 1.2, -3.6), Vector3(-10, 1.5, -15), Vector3(16, 1.2, 9), Vector3(-8, 1.5, 11)]


func _ambient() -> void:
	AudioManager.play_ambient("calle_madrugada")

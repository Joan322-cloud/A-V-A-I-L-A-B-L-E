extends FloorBase
## Piso 1: hall de ascensores, ala de training (2 salas) y tópico (GDD 7.3 rev 2).
## v0.3.1 pisos (plano del site corregido por Joan, ref_site_v2/REFERENCIA_PISOS_v3.md §3 y §6.1; marco del plano =
## marco del juego, z = −y del plano):
## - HALL angosto (x −9..6, z −1,5..1,5: ~2 m del site + 1 m de holgura para la persecución) de porcelanato negro
##   espejado. Lado −z: MÁRMOL con el ascensor (x −3), una 2.ª puerta de ascensor en mantenimiento (x −6,6), el gabinete
##   (x 0) y la puerta de LIMPIEZA (x 1,35, junto al ala). Lado +z: pared AZUL con el pulsador y, ENFRENTE de los
##   ascensores, la cortafuego de la escalera en U a ~2 m de la puerta del ala (x 4,1). Al fondo oeste, un vidrio con
##   una sala iluminada sin acceso. Puerta de vidrio esmerilado al ala en x = 6.
## - PASILLO DE TRAINING (x 6..8,2, z −1,3..6,5, ~7,8 × 2,2 m) de vinílico cálido, de sur a norte: vestíbulo de baños →
##   cruce. En su pared oeste, la esmerilada al hall (a ~1,3 m del extremo norte) y una puerta blanca con placa.
## - Al fondo, la SALA DE TRAINING PRINCIPAL (x 6..13,5, z −8,5..−1,3, ~7,5 × 7,2 m): frente de vidrio con la puerta del
##   Trainer, 3 filas de PCs, ventanas al exterior; aquí el Trainer entrena a las waves nuevas.
## - En el cruce cuelga el «SALIDA ←»; a su derecha, el RECODO del tópico (x 8,2..12,5, z −1,3..0,7) con la banca de
##   espera, el extintor y el balde; al fondo, la puerta blanca del TÓPICO (cuarto x 12,5..15,5) a ~6,5 m del hall.
## - Al sur: el VESTÍBULO DE BAÑOS (hombres al sur, mujeres al este), la puerta doble de vidrio oscuro a un cuarto sin
##   ver y el PASILLO APAGADO (x 0..5,5) que muere en la puerta con mirilla y resplandor azul de la SALA SECUNDARIA
##   (x −5,4..−0,1, z 6,75..13,65), más chica y a oscuras. Solo hay 2 salas de training.
## Se conservan los IDs: training_sala2 (es la principal), Seat_training_sala2_*, Terminal_training_sala2, el marcador
## y la zona topico (el marcador mira hacia el recodo: topico_control y bot_p5 usan su base), bano_p1 / bano_p1_b.

const ESMERILADO := Color(0.75, 0.85, 0.88, 0.55)
const CALIDA := Color(1.0, 0.72, 0.45)
const HALL_Z := 1.5          # medio ancho útil del hall
const WING_X := 6.0          # puerta del hall al ala
const COR_X1 := 8.2          # pared este del pasillo de training
const FRONT_Z := -1.3        # frente de vidrio de la sala principal
const ROOM_X1 := 13.5
const ROOM_Z0 := -8.5
const RECODO_Z1 := 0.7       # pared sur del recodo
const TOPICO_X0 := 12.5
const TOPICO_C := Vector2(14.0, 0.25)
const TOPICO_S := Vector2(3.0, 3.0)
const TOPICO_DOOR_Z := -0.3
const VEST_Z0 := 6.5
const VEST_Z1 := 9.3
const VEST_X0 := 5.5
const OSC_Z0 := 6.8          # pasillo apagado
const OSC_Z1 := 8.3
const SEC_X0 := -5.4         # sala secundaria
const SEC_X1 := -0.1
const SEC_Z0 := 6.75
const SEC_Z1 := 13.65


func _build() -> void:
	floor_number = 1
	_hall()
	_wing()
	_main_room()
	_topico()
	_bathrooms_lobby()
	_dark_corridor()
	_secondary_room()
	_horror()
	# C15: hall + pasillo + recodo; vinílico en el pasillo, el recodo, el vestíbulo y el pasillo apagado.
	Zone.make(self, "pasillo_p1", Vector3(1.75, 1.5, 0.0), Vector3(21.5, 3, 3.0))
	Zone.make(self, "vinilico", Vector3(7.1, 1.5, 2.6), Vector3(2.2, 3, 7.8))
	Zone.make(self, "vinilico", Vector3(10.35, 1.5, -0.3), Vector3(4.25, 3, 2.0))
	Zone.make(self, "vinilico", Vector3(6.85, 1.5, 7.9), Vector3(2.7, 3, 2.75))
	Zone.make(self, "vinilico", Vector3(2.7, 1.5, 7.55), Vector3(5.5, 3, 1.5))
	# Rutas (Shero, Pursuit): el ala no tiene circuito cerrado; el pasillo apagado es un callejón sin salida.
	waypoints = [Vector3(-6.0, 0, 0), Vector3(-3.0, 0, 0), Vector3(0.0, 0, 0), Vector3(3.0, 0, 0), Vector3(6.9, 0, 0),
		Vector3(7.1, 0, -0.3), Vector3(10.5, 0, -0.3), Vector3(12.0, 0, -0.3), Vector3(7.1, 0, 3.0), Vector3(7.1, 0, 6.5),
		Vector3(6.8, 0, 8.0), Vector3(3.0, 0, 7.55), Vector3(0.5, 0, 7.55)]


## Hall de ascensores (x −9..6, z −1,5..1,5): negro espejado, mármol con los ascensores (−z), azul enfrente (+z).
func _hall() -> void:
	var piso := Greybox.sfloor(self, "Pasillo", Vector2(-1.5, 0), Vector2(15.0, HALL_Z * 2.0 + 0.2), "porcelanato_negro")
	piso.name = "Pasillo"
	piso.material_override = Greybox.surf("porcelanato_negro", Color(1, 1, 1), 0.08)
	Greybox.ceiling(self, "Techo", Vector2(-1.5, 0), Vector2(15.0, 3.4), 3.0, Color(0.05, 0.05, 0.055))
	Greybox.sceiling(self, "TechoHall", Vector2(-1.5, 0), Vector2(15.0, 3.4), 2.7, "baldosa_techo")
	# Mármol con el vano del ascensor (x −4,1..−1,9) y la puerta de limpieza (x 0,9..1,8).
	Greybox.swall(self, "ParedS_A", Vector3(-6.55, 1.5, -HALL_Z), Vector3(4.9, 3, 0.2), "marmol")
	Greybox.swall(self, "ParedS_B", Vector3(-0.5, 1.5, -HALL_Z), Vector3(2.8, 3, 0.2), "marmol")   # x −1,9..0,9
	Greybox.swall(self, "ParedS_C", Vector3(3.9, 1.5, -HALL_Z), Vector3(4.2, 3, 0.2), "marmol")    # x 1,8..6
	Greybox.sbox(self, "DintelLimpieza", Vector3(1.35, 2.55, -HALL_Z), Vector3(0.9, 0.9, 0.2), "marmol", false)
	Greybox.sbox(self, "DintelAscensor", Vector3(-3.0, 2.8, -HALL_Z), Vector3(2.2, 0.4, 0.2), "marmol", false)
	add_elevator(Vector3(-3.0, 0, -2.9), 0.0)
	_maint_elevator(Vector3(-6.6, 0, -HALL_Z + 0.11))
	# Pared azul enfrente, con la cortafuego de la escalera (x 2,6..5,6) a ~2 m de la puerta del ala.
	Greybox.swall(self, "ParedN_A", Vector3(-3.2, 1.5, HALL_Z), Vector3(11.6, 3, 0.2), "pared", Greybox.AZUL_P1)
	Greybox.swall(self, "ParedN_B", Vector3(5.8, 1.5, HALL_Z), Vector3(0.4, 3, 0.2), "pared", Greybox.AZUL_P1)
	Greybox.box(self, "EscaleraDintel", Vector3(4.1, 2.7, HALL_Z), Vector3(3.0, 0.6, 0.2), Greybox.AZUL_P1, false).material_override = Greybox.surf("pared", Greybox.AZUL_P1)
	add_stairs(Vector3(4.1, 0, HALL_Z), -1, 2, false, 180.0)
	_stair_box()
	# Fondo oeste: vidrio con una sala iluminada con mesas detrás (sin acceso, no grabada).
	_west_glass()
	for i in 7:
		var x := -8.2 + i * 2.0
		Greybox.downlight(self, "DownHall%d" % i, Vector3(x, 2.68, 0.0), Color(1.0, 0.9, 0.8), 0.75, 5.5, i % 2 == 0)
	Greybox.box(self, "DomoCCTV", Vector3(-1.0, 2.64, 0.9), Vector3(0.14, 0.08, 0.14), Greybox.NEGRO, false)
	SiteProps.fire_cabinet(self, "GabineteIncendio", Vector3(0.0, 1.4, -HALL_Z + 0.13), 0.0)
	Greybox.box(self, "Pulsador", Vector3(-5.0, 1.4, HALL_Z - 0.12), Vector3(0.1, 0.1, 0.04), Greybox.ROJO_SEGURIDAD, false)
	SiteProps.a4_sheets(self, "HojaA4", Vector3(-4.2, 1.55, HALL_Z - 0.12), 180.0, 3, 41)
	SiteProps.a4_sheets(self, "HojaA4b", Vector3(0.4, 1.4, HALL_Z - 0.12), 180.0, 2, 42)
	HorrorProps.sinister_poster(self, "SIGN_METRICS_WALL", "POSTER_METRICS_DARK", Vector3(-1.6, 1.9, HALL_Z - 0.15), 180.0, 0.2, 2.05)
	_cleaning_door()
	# Puerta de vidrio esmerilado del hall al ala (marco negro, jalador vertical largo; vano libre z −0,7..0,7).
	for seg in [[-HALL_Z, -0.7], [0.7, HALL_Z]]:
		var a: float = seg[0]
		var b: float = seg[1]
		var zc := (a + b) * 0.5
		Greybox.box(self, "TabiqueVidrio%d" % int(zc * 10), Vector3(WING_X, 1.35, zc), Vector3(0.05, 2.7, b - a), ESMERILADO)
		Greybox.box(self, "TabiqueMarco%d" % int(zc * 10), Vector3(WING_X, 0.05, zc), Vector3(0.08, 0.1, b - a), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "DintelVidrio", Vector3(WING_X, 2.85, 0), Vector3(0.1, 0.3, HALL_Z * 2.0), Greybox.MARCO_NEGRO, false)
	for zj in [-0.7, 0.7]:
		Greybox.box(self, "JambaVidrio%d" % int(zj * 10), Vector3(WING_X, 1.35, zj), Vector3(0.1, 2.7, 0.08), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "JaladorAla", Vector3(WING_X + 0.06, 1.15, 0.55), Vector3(0.03, 1.2, 0.03), Greybox.INOX, false).material_override = Greybox.inox()
	Greybox.exit_sign(self, "SalidaColgante2", Vector3(-1.0, 2.45, 0.0), 90.0, 1, true)
	Greybox.light(self, Vector3(2.0, 2.3, 0.6), Color(0.85, 0.92, 1.0), 0.4, 6.0)  # relleno frío bajo


## 2.ª puerta de ascensor en el mármol: hojas inox cerradas y cartel de mantenimiento (no se usa).
func _maint_elevator(pos: Vector3) -> void:
	var inox := Greybox.inox()
	for sx in [-0.45, 0.45]:
		Greybox.box(self, "Ascensor2Hoja%d" % int(sx * 10), pos + Vector3(sx, 1.15, 0), Vector3(0.9, 2.3, 0.03), Greybox.INOX, false).material_override = inox
	Greybox.box(self, "Ascensor2Junta", pos + Vector3(0, 1.15, 0.018), Vector3(0.015, 2.3, 0.01), Greybox.NEGRO, false)
	Greybox.box(self, "Ascensor2Marco", pos + Vector3(0, 2.36, 0.02), Vector3(2.0, 0.08, 0.04), Greybox.NEGRO, false)
	Greybox.box(self, "Ascensor2Indicador", pos + Vector3(0, 2.6, 0.02), Vector3(0.6, 0.24, 0.03), Greybox.NEGRO, false)
	var l := Greybox.label(self, "--", pos + Vector3(0, 2.6, 0.04), 0.18, Greybox.AMBAR)
	l.outline_size = 0
	WorldObjects.signage(self, "ELEVATOR_MAINT", pos + Vector3(0, 1.5, 0.04), 0.0, 0.16, Greybox.AMBAR)


## Caja de la escalera detrás de la pared azul (x 2,6..5,6, z 1,5..6,6): solo cierra la planta; la escalera de verdad es
## la caja liminal (Stairwell).
func _stair_box() -> void:
	Greybox.box(self, "CajaEscaleraW", Vector3(2.5, 1.5, 4.15), Vector3(0.2, 3, 5.3), Greybox.GRIS)
	Greybox.box(self, "CajaEscaleraE", Vector3(5.7, 1.5, 4.15), Vector3(0.2, 3, 5.3), Greybox.GRIS)


func _west_glass() -> void:
	Greybox.box(self, "VidrioFondo", Vector3(-9.0, 1.4, 0), Vector3(0.05, 2.8, HALL_Z * 2.0), Greybox.VIDRIO)
	Greybox.box(self, "VidrioFondoMarco", Vector3(-9.0, 2.82, 0), Vector3(0.1, 0.06, HALL_Z * 2.0), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "VidrioFondoJalador", Vector3(-8.95, 1.1, 0.4), Vector3(0.03, 0.8, 0.03), Greybox.INOX, false)
	Greybox.floor_slab(self, "SalaFondoPiso", Vector2(-11.0, 0), Vector2(4.0, 5.0), Color(0.45, 0.45, 0.44))
	Greybox.box(self, "SalaFondoParedW", Vector3(-13.0, 1.5, 0), Vector3(0.2, 3, 5.0), Greybox.BLANCO_PARED, false)
	Greybox.box(self, "SalaFondoParedN", Vector3(-11.0, 1.5, -2.5), Vector3(4.0, 3, 0.2), Greybox.BLANCO_PARED, false)
	Greybox.box(self, "SalaFondoParedS", Vector3(-11.0, 1.5, 2.5), Vector3(4.0, 3, 0.2), Greybox.BLANCO_PARED, false)
	Greybox.box(self, "SalaFondoTecho", Vector3(-11.0, 2.9, 0), Vector3(4.0, 0.1, 5.0), Greybox.TECHO_BALDOSA, false)
	for k in 2:
		Greybox.box(self, "SalaFondoMesa%d" % k, Vector3(-11.6, 0.74, -1.0 + k * 2.0), Vector3(2.0, 0.04, 0.8), Greybox.BLANCO, false)
	Greybox.box(self, "SalaFondoLuz", Vector3(-11.0, 2.85, 0), Vector3(1.2, 0.04, 0.3), Color(0.95, 0.97, 1.0), false, 2.5)
	Greybox.light(self, Vector3(-11.0, 2.4, 0), Color(0.92, 0.96, 1.0), 1.2, 5.0)


## Puerta blanca de LIMPIEZA en el mármol, junto al ala (entreabierta, sin acceso), con el balde y el trapeador.
func _cleaning_door() -> void:
	var x := 1.35
	Greybox.floor_slab(self, "LimpiezaPiso", Vector2(x, -2.5), Vector2(1.8, 2.0), Color(0.3, 0.3, 0.3))
	Greybox.box(self, "LimpiezaParedW", Vector3(x - 0.95, 1.5, -2.5), Vector3(0.1, 3, 2.0), Greybox.GRIS, false)
	Greybox.box(self, "LimpiezaParedE", Vector3(x + 0.95, 1.5, -2.5), Vector3(0.1, 3, 2.0), Greybox.GRIS, false)
	Greybox.box(self, "LimpiezaParedN", Vector3(x, 1.5, -3.5), Vector3(2.0, 3, 0.1), Greybox.GRIS, false)
	Greybox.ceiling(self, "LimpiezaTecho", Vector2(x, -2.5), Vector2(1.8, 2.0), 2.7, Color(0.2, 0.2, 0.22))
	var hinge := Node3D.new()
	hinge.name = "LimpiezaBisagra"
	hinge.position = Vector3(x - 0.45, 0, -HALL_Z)
	hinge.rotation_degrees.y = -16.0
	add_child(hinge)
	var leaf := Greybox.box(hinge, "LimpiezaHoja", Vector3(0.45, 1.05, 0), Vector3(0.88, 2.1, 0.05), Greybox.PUERTA_BLANCA, false)
	var lbl := Greybox.label(leaf, "LIMPIEZA", Vector3(0, 0.55, 0.03), 0.09, Color(0.15, 0.15, 0.15))
	lbl.outline_size = 0
	Greybox.box(leaf, "Rejilla", Vector3(0, -0.8, 0.028), Vector3(0.4, 0.18, 0.005), Color(0.75, 0.74, 0.7), false)
	Greybox.invisible_box(self, "LimpiezaCierre", Vector3(x, 1.2, -HALL_Z - 0.05), Vector3(0.9, 2.4, 0.2))
	Greybox.cylinder(self, "BaldeLimpieza", Vector3(x + 0.4, 0.18, -2.4), 0.17, 0.36, Color(0.85, 0.85, 0.2), false, 0.6, 0.0, 0.19)
	var palo := Greybox.cylinder(self, "Trapeador", Vector3(x + 0.3, 0.75, -2.6), 0.015, 1.5, Color(0.5, 0.5, 0.52), false)
	palo.rotation_degrees.z = 12.0
	Greybox.light(self, Vector3(x, 2.2, -2.6), Color(0.6, 0.7, 0.75), 0.25, 2.5)
	# Huellas de barro que salen del hall y se meten en el cuarto de limpieza (no salen).
	SiteProps.footprints(self, "HuellaLimpieza", Vector3(-1.5, 0, 0.6), Vector3(x, 0, -HALL_Z - 0.6), 0.55)


## Ala de training: pasillo N-S (x 6..8,2, z −1,3..6,5) y recodo del tópico (x 8,2..12,5, z −1,3..0,7).
func _wing() -> void:
	var vin := Greybox.sfloor(self, "PasilloTraining", Vector2(7.1, 2.6), Vector2(2.2, 7.8), "vinilico_calido")
	vin.name = "PasilloTraining"
	Greybox.sfloor(self, "RecodoPiso", Vector2(10.35, -0.3), Vector2(4.3, 2.0), "vinilico_calido")
	Greybox.sceiling(self, "TechoTraining", Vector2(7.1, 2.6), Vector2(2.2, 7.8), 2.7, "baldosa_techo", Color(0.9, 0.86, 0.8))
	Greybox.sceiling(self, "RecodoTecho", Vector2(10.35, -0.3), Vector2(4.3, 2.0), 2.7, "baldosa_techo", Color(0.88, 0.86, 0.84))
	# Pared oeste del pasillo (x 6, z 1,5..6,5) con la puerta blanca con placa (cerrada) en z ≈ 4.
	Greybox.swall(self, "PasilloW", Vector3(WING_X, 1.5, 4.0), Vector3(0.2, 3, 5.0), "pared", Greybox.CREMA)
	Greybox.box(self, "EsquinaMarmol", Vector3(WING_X, 1.5, -1.4), Vector3(0.2, 3, 0.2), Greybox.MARCO_NEGRO, false)
	var placa := Greybox.box(self, "PuertaPlaca", Vector3(WING_X + 0.12, 1.05, 4.05), Vector3(0.04, 2.1, 0.9), Greybox.PUERTA_BLANCA, false)
	Greybox.box(placa, "Placa", Vector3(0.025, 0.55, 0), Vector3(0.005, 0.1, 0.25), Greybox.INOX, false)
	Greybox.box(placa, "Manija", Vector3(0.04, 0.0, -0.35), Vector3(0.04, 0.03, 0.12), Greybox.INOX, false)
	# Pared este del pasillo (x 8,2, z 0,7..6,5), lisa, con la papelera inox y un aviso.
	Greybox.swall(self, "PasilloE", Vector3(COR_X1, 1.5, 3.6), Vector3(0.2, 3, 5.8), "pared", Greybox.CREMA)
	Greybox.bin(self, "Papelera", Vector3(COR_X1 - 0.3, 0, 2.2))
	SiteProps.a4_sheets(self, "AvisoPasillo", Vector3(COR_X1 - 0.11, 1.5, 3.0), -90.0, 1, 7)
	HorrorProps.sinister_poster(self, "SIGN_AVAILABLE_ATTITUDE", "POSTER_ATTITUDE_DARK", Vector3(COR_X1 - 0.13, 1.9, 4.6), -90.0, 0.2, 1.6)
	# Recodo: pared sur (z 0,7) y la pared del tópico (x 12,5) con su puerta.
	Greybox.swall(self, "RecodoS", Vector3(10.35, 1.5, RECODO_Z1), Vector3(4.5, 3, 0.2), "pared", Greybox.CREMA)
	Greybox.swall(self, "RecodoE_A", Vector3(TOPICO_X0, 1.5, -1.025), Vector3(0.2, 3, 0.55), "pared", Greybox.CREMA)
	Greybox.swall(self, "RecodoE_B", Vector3(TOPICO_X0, 1.5, 0.425), Vector3(0.2, 3, 0.55), "pared", Greybox.CREMA)
	Greybox.box(self, "TopicoDintel", Vector3(TOPICO_X0, 2.6, TOPICO_DOOR_Z), Vector3(0.2, 0.8, 0.95), Greybox.CREMA, false)
	# Luz: difusores cuadrados cálidos a media luz; el tramo sur queda casi apagado.
	for p in [Vector3(7.1, 2.68, 0.0), Vector3(7.1, 2.68, 3.4), Vector3(10.3, 2.68, -0.3)]:
		Greybox.box(self, "Difusor%d" % int(p.x * 10 + p.z), p, Vector3(0.6, 0.03, 0.6), Color(0.95, 0.9, 0.82), false, 0.9)
	Greybox.light(self, Vector3(7.1, 2.4, 0.0), CALIDA, 0.9, 6.0)
	Greybox.light(self, Vector3(7.1, 2.4, 3.4), CALIDA, 0.6, 5.5)
	Greybox.light(self, Vector3(10.3, 2.4, -0.3), CALIDA, 0.75, 5.5)
	for i in 3:
		Greybox.box(self, "Rejilla%d" % i, Vector3(7.1, 2.68, 1.6 + i * 2.0), Vector3(1.0, 0.02, 0.12), Color(0.75, 0.73, 0.7), false)
	# «SALIDA ←» en el cruce (apunta al hall y a la escalera; el tópico queda a su derecha) y otro en el pasillo.
	# rc1: en x 7,45 tapaba el cartel «Sala de training» (mismo x y altura, 0,4 m delante): se corre a la boca del recodo.
	Greybox.exit_sign(self, "SalidaFinal", Vector3(9.3, 2.35, -0.9), 0.0, -1, true)
	Greybox.exit_sign(self, "SalidaColgante1", Vector3(7.1, 2.45, 4.6), 0.0, 0, true)
	Greybox.extinguisher(self, "Extintor2", Vector3(6.35, 0, 6.2), 18)
	HorrorProps.sinister_poster(self, "SIGN_BREAK_PRIVILEGE", "POSTER_BREAK_DARK", Vector3(WING_X + 0.13, 1.9, 2.4), 90.0, 0.18, 1.4)
	Greybox.box(self, "Alcohol", Vector3(WING_X + 0.1, 1.2, 1.9), Vector3(0.1, 0.25, 0.12), Greybox.BLANCO, false)


## El número del extintor cambia cuando no lo miras (17 → 18 → 17).
class _NumberSwap extends Node:
	var label: Label3D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or label == null:
			return
		_t = 1.0
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var to := label.global_position - cam.global_position
		if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.3 and to.length() < 12.0:
			return
		if GameState.turno >= 2 or Dread.level() > 0.4:
			label.text = "18" if label.text == "17" else "17"


## Sala de training PRINCIPAL (x 6..13,5, z −8,5..−1,3): frente de vidrio al cruce con la puerta del Trainer (x 7..7,9),
## machón blanco con el extintor y la terminal, 3 filas de PCs (pasillo libre al oeste, por donde sale el Trainer),
## pizarra y proyector al fondo, ventanas al exterior. T2+: el Trainer da clase a siluetas y puede salir a interceptarte.
func _main_room() -> void:
	var with_trainer := GameState.enemy_enabled("trainer")
	var c := Vector2((WING_X + ROOM_X1) * 0.5, (ROOM_Z0 + FRONT_Z) * 0.5)
	var s := Vector2(ROOM_X1 - WING_X, FRONT_Z - ROOM_Z0)
	Greybox.sfloor(self, "TrainingPiso1", c, s, "vinilico_claro")
	Greybox.sceiling(self, "TrainingTecho1", c, s, 2.7, "baldosa_techo")
	Greybox.swall(self, "TrainingParedW", Vector3(WING_X, 1.5, c.y), Vector3(0.2, 3, s.y), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "TrainingParedE", Vector3(ROOM_X1, 1.5, c.y), Vector3(0.2, 3, s.y), "pared", Greybox.BLANCO_PARED)
	# Pared del fondo: pizarra (x 6,4..10) y ventanas al exterior (x 10,4..13,2) con lluvia.
	Greybox.swall(self, "TrainingParedN_A", Vector3(8.2, 1.5, ROOM_Z0), Vector3(4.4, 3, 0.2), "pared", Greybox.BLANCO_PARED)
	Greybox.box(self, "TrainingVentanaBajo", Vector3(11.85, 0.45, ROOM_Z0), Vector3(3.3, 0.9, 0.2), Greybox.BLANCO_PARED).material_override = Greybox.surf("pared", Greybox.BLANCO_PARED)
	Greybox.box(self, "TrainingVentanaAlto", Vector3(11.85, 2.8, ROOM_Z0), Vector3(3.3, 0.4, 0.2), Greybox.BLANCO_PARED, false).material_override = Greybox.surf("pared", Greybox.BLANCO_PARED)
	Greybox.invisible_box(self, "TrainingVentanaCol", Vector3(11.85, 1.75, ROOM_Z0 - 0.05), Vector3(3.3, 1.7, 0.2))
	var g := Weather.rain_glass(self, "TrainingVentana", Vector3(11.85, 1.75, ROOM_Z0 + 0.02), Vector2(3.1, 1.6), 0.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SiteProps.blind(self, "TrainingPersiana", Vector3(11.85, 2.55, ROOM_Z0 + 0.12), 3.1, 0.35, 0.0)
	# Frente de vidrio (z −1,3): vidrio x 6..7, puerta 7..7,9, machón 7,9..8,4, vidrio 8,4..10, pared blanca 10..13,5.
	Greybox.box(self, "TrainingVidrioA1", Vector3(6.5, 1.5, FRONT_Z), Vector3(1.0, 3, 0.06), Greybox.VIDRIO)
	Greybox.box(self, "TrainingVidrioB1", Vector3(9.2, 1.5, FRONT_Z), Vector3(1.6, 3, 0.06), Greybox.VIDRIO)
	Greybox.box(self, "TrainingVidrioAlto1", Vector3(7.45, 2.6, FRONT_Z), Vector3(0.9, 0.8, 0.06), Greybox.VIDRIO, false)
	Greybox.box(self, "TrainingMarco1", Vector3(8.0, 2.98, FRONT_Z), Vector3(4.0, 0.06, 0.1), Greybox.NEGRO, false)
	for mx in [6.02, 7.0, 7.9, 8.4, 9.98]:
		Greybox.box(self, "TrainingMontante%d" % int(mx * 10), Vector3(mx, 1.5, FRONT_Z), Vector3(0.05, 3, 0.08), Greybox.MARCO_NEGRO, false)
	Greybox.swall(self, "Machon", Vector3(8.15, 1.5, FRONT_Z), Vector3(0.5, 3, 0.24), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "TrainingParedS", Vector3(11.75, 1.5, FRONT_Z), Vector3(3.5, 3, 0.2), "pared", Greybox.BLANCO_PARED)
	SiteProps.frosted_band(self, "TrainingFranja1a", Vector3(6.5, 0, FRONT_Z + 0.04), 0.95)
	SiteProps.frosted_band(self, "TrainingFranja1b", Vector3(9.2, 0, FRONT_Z + 0.04), 1.55)
	var d := WorldObjects.simple(self, WorldObjects.Door, "Training1", "HUD_DOOR", Vector3(7.45, 1.1, FRONT_Z), Vector3(0.88, 2.2, 0.06), Greybox.VIDRIO)
	(d as WorldObjects.Door).locked = true
	(d as WorldObjects.Door).locked_key = "SIGN_TRAINING_CLOSED"
	Greybox.box(d, "Jalador", Vector3(0.36, 0, 0.05), Vector3(0.03, 0.9, 0.03), Greybox.NEGRO, false)
	WorldObjects.signage(self, "SIGN_TRAINING", Vector3(6.95, 2.35, FRONT_Z + 0.06), 0.0, 0.18)  # rc1: entero a la izquierda del pilar
	Greybox.label(self, "1", Vector3(8.15, 2.35, FRONT_Z + 0.14), 0.18, Greybox.CIAN)
	# Machón: extintor sobre base roja (el número cambia si no lo miras) y el lugar de la terminal del training.
	var ext := Greybox.extinguisher(self, "Extintor", Vector3(8.15, 0, FRONT_Z + 0.3), 17)
	var sw := _NumberSwap.new()
	sw.name = "NumeroCambia"
	sw.label = ext.find_child("Numero", true, false) as Label3D
	ext.add_child(sw)
	# La terminal del training (Terminal_training_sala2) la pone training_session.gd en este machón (8,15, 1,3, −1,15).
	# Pizarra con el guion, proyector y su haz (training_session busca ProyectorHaz1), LED lineal.
	Greybox.box(self, "Pizarra1", Vector3(8.2, 1.6, ROOM_Z0 + 0.12), Vector3(3.4, 1.3, 0.05), Greybox.BLANCO, false, 0.15)
	Greybox.box(self, "PizarraMarco1", Vector3(8.2, 1.6, ROOM_Z0 + 0.09), Vector3(3.5, 1.4, 0.03), Greybox.INOX, false)
	Greybox.label(self, tr("SIGN_TRAINING_BOARD"), Vector3(8.2, 1.65, ROOM_Z0 + 0.16), 0.1, Color(0.15, 0.2, 0.45))
	Greybox.box(self, "Proyector1", Vector3(8.2, 2.5, -5.2), Vector3(0.35, 0.12, 0.3), Greybox.BLANCO, false)
	Greybox.box(self, "ProyectorBarra1", Vector3(8.2, 2.6, -5.2), Vector3(0.03, 0.2, 0.03), Greybox.NEGRO, false)
	for k in 2:
		var led := Greybox.box(self, "LedLineal1_%d" % k, Vector3(10.0, 2.35, -3.6 - k * 2.8), Vector3(4.2, 0.04, 0.08), Color(0.95, 0.97, 1.0), false, 1.4 if with_trainer else 0.5)
		Greybox.box(led, "Tirante", Vector3(0, 0.17, 0), Vector3(0.01, 0.3, 0.01), Greybox.NEGRO, false)
	Greybox.light(self, Vector3(9.8, 2.3, -3.8), Color(0.6, 0.75, 0.8), 1.2 if with_trainer else 0.45, 6.0)
	Greybox.light(self, Vector3(9.8, 2.3, -6.8), Color(0.6, 0.75, 0.8), 1.0 if with_trainer else 0.35, 6.0)
	# 3 filas de PCs (x 8,6..12,9, mesas a z −3,9 / −5,6 / −7,3; sillas detrás, mirando a la pizarra).
	for r in 3:
		var dz := -3.9 - r * 1.7
		Greybox.box(self, "MesaTraining%d" % r, Vector3(10.75, 0.74, dz), Vector3(4.3, 0.05, 0.7), Greybox.MADERA).material_override = Greybox.surf("roble", Color(0.95, 0.95, 0.95))
		Greybox.box(self, "MesaTrainingPata%d" % r, Vector3(10.75, 0.36, dz), Vector3(4.1, 0.72, 0.08), Greybox.NEGRO, false)
		for k in 4:
			var sx := 9.15 + k * 1.05
			var on := (r + k) % 5 == 2
			if not (r == 2 and k == 3):  # ese puesto es el monitor de «Usuario desconectado» (_horror)
				Greybox.box(self, "PC%d_%d" % [r, k], Vector3(sx, 0.97, dz - 0.2), Vector3(0.46, 0.28, 0.03), Color(0.25, 0.55, 0.7) if on else Color(0.03, 0.035, 0.04), false, 1.2 if on else 0.0)
			Greybox.box(self, "CPU%d_%d" % [r, k], Vector3(sx + 0.3, 0.2, dz - 0.15), Vector3(0.18, 0.4, 0.42), Color(0.06, 0.06, 0.065), false)
			var cz := dz + 0.75
			Greybox.box(self, "SillaT%d_%d" % [r, k], Vector3(sx, 0.45, cz), Vector3(0.4, 0.05, 0.4), Greybox.NEGRO, false)
			Greybox.box(self, "SillaTResp%d_%d" % [r, k], Vector3(sx, 0.72, cz + 0.2), Vector3(0.4, 0.5, 0.04), Greybox.NEGRO, false)
			if r == 0:
				# v0.3 P2: la 1.ª fila tiene asientos de verdad para el jugador (training_session.gd, P5).
				var ts := WorldObjects.TrainingSeat.new()
				ts.name = "Seat_training_sala2_%d" % k
				ts.seat_id = "training_sala2_%d" % k
				ts.hint_key = "HUD_SIT"
				ts.size = Vector3(0.55, 1.0, 0.55)
				ts.position = Vector3(sx, 0.8, cz + 0.05)
				ts.enabled = not with_trainer or k == 3  # con alumnos, solo queda libre la del extremo
				add_child(ts)
			var student := with_trainer and ((r == 0 and k < 3) or (r == 1 and k != 2) or (r == 2 and k == 1))
			if student:
				# Alumnos: siluetas sentadas, de espaldas al vidrio, que no se mueven.
				Greybox.box(self, "AlumnoT%d_%d" % [r, k], Vector3(sx, 0.85, cz - 0.05), Vector3(0.38, 0.8, 0.26), Color(0.05, 0.05, 0.06), false)
				Greybox.box(self, "AlumnoCabezaT%d_%d" % [r, k], Vector3(sx, 1.4, cz - 0.05), Vector3(0.2, 0.24, 0.22), Color(0.05, 0.05, 0.06), false)
	if with_trainer:
		Greybox.box(self, "ProyectorHaz1", Vector3(8.2, 1.65, ROOM_Z0 + 0.16), Vector3(3.2, 1.1, 0.02), Color(0.75, 0.85, 0.95), false, 1.2)
		(d as WorldObjects.Door).locked = false  # el Trainer sale por aquí; el jugador puede abrirla
		(d as WorldObjects.Door).locked_key = "HUD_DOOR"
		var tr_ := Trainer.new()
		tr_.name = "Trainer"
		add_child(tr_)
		var player := get_tree().get_first_node_in_group("player") as Player
		tr_.setup(self, player, 7.45, d as WorldObjects.Door, FRONT_Z, 6.4)
		# La intercepción se recorta a la L del ala: hall, pasillo de training y recodo (el Trainer no choca).
		tr_.regions = [Rect2(-8.5, -1.2, 14.5, 2.4), Rect2(6.2, -1.1, 1.8, 7.4), Rect2(8.2, -1.1, 4.1, 1.6)]
		tr_.hub = Vector3(7.1, 0, -0.2)
	Greybox.marker(self, "training_sala2", Vector3(7.45, 0, -2.0), 0.0)
	Zone.make(self, "training_sala2", Vector3(9.75, 1.4, -4.9), Vector3(7.3, 2.8, 7.0))
	var nt := HorrorProps.note(self, "NOTE_TRAINING", Vector3(11.0, 0.79, -5.6), 0.0, false, 0.0)
	nt.rotation_degrees.x = -80.0


## Tópico (D6): al fondo del recodo, a la derecha del «SALIDA»; puerta blanca opaca en su pared oeste (x 12,5), con la
## banca de espera, el extintor y el balde contra la pared sur del recodo, junto a la puerta.
func _topico() -> void:
	var c := TOPICO_C
	var s := TOPICO_S
	var x1 := c.x + s.x * 0.5
	var z0 := c.y - s.y * 0.5
	var z1 := c.y + s.y * 0.5
	Greybox.sfloor(self, "TopicoPiso", c, s, "porcelanato_gris")
	Greybox.sceiling(self, "TopicoTecho", c, s, 2.7, "baldosa_techo")
	Greybox.swall(self, "TopicoParedN", Vector3(c.x + 0.25, 1.5, z0), Vector3(s.x - 0.3, 3, 0.2), "pared", Greybox.BLANCO_PARED, false)
	Greybox.swall(self, "TopicoParedS", Vector3(c.x, 1.5, z1), Vector3(s.x + 0.2, 3, 0.2), "pared", Greybox.BLANCO_PARED, false)
	Greybox.swall(self, "TopicoParedE", Vector3(x1, 1.5, c.y), Vector3(0.2, 3, s.y + 0.2), "pared", Greybox.BLANCO_PARED, false)
	Greybox.swall(self, "TopicoParedW_S", Vector3(TOPICO_X0, 1.5, (RECODO_Z1 + z1) * 0.5 + 0.05), Vector3(0.2, 3, z1 - RECODO_Z1 + 0.1), "pared", Greybox.BLANCO_PARED, false)
	var dz := TOPICO_DOOR_Z
	var topico := WorldObjects.simple(self, WorldObjects.Door, "Topico", "HUD_DOOR", Vector3(TOPICO_X0, 1.1, dz), Vector3(1.0, 2.2, 0.06), Greybox.PUERTA_BLANCA, 90.0)
	var topico_open := GameState.turno >= int(DataLoader.bal("topico/turno_desde", 2))
	(topico as WorldObjects.Door).locked = not topico_open
	(topico as WorldObjects.Door).locked_key = "SIGN_TOPICO_CLOSED"
	if topico_open:
		(topico as WorldObjects.Door).hint_key = "HUD_TOPICO_DOOR"
	# La hoja mira al recodo (−x): vinilo con la frase, círculo de línea y jalador.
	var hoja := topico.get_node_or_null("Caja") as Node3D
	if hoja != null:
		SiteProps.pictogram(hoja, Vector3(-0.05, 0.3, -0.035), 180.0, "circulo")
		var frase := Greybox.label(hoja, "", Vector3(0, -0.1, -0.035), 0.05, Color(0.35, 0.35, 0.35), PI)
		frase.text = tr("Q5_TOPICO_VINILO")
		frase.outline_size = 0
		Greybox.box(hoja, "Jalador", Vector3(-0.38, 0, -0.04), Vector3(0.12, 0.03, 0.03), Greybox.INOX, false)
	WorldObjects.signage(self, "SIGN_TOPICO", Vector3(TOPICO_X0 - 0.12, 2.35, dz), -90.0, 0.2, Color(0.25, 0.25, 0.25))
	HorrorProps.note(self, "NOTE_TOPICO", Vector3(TOPICO_X0 - 0.12, 1.35, 0.42), -90.0, true, 6.0)
	# Contra la pared sur del recodo, junto a la puerta: banca de espera, extintor sobre base roja, balde, papelera.
	SiteProps.waiting_bench(self, "BanquetaEspera", Vector3(11.05, 0, RECODO_Z1 - 0.3), 0.0, 1.1)
	Greybox.extinguisher(self, "ExtintorTopico", Vector3(11.85, 0, RECODO_Z1 - 0.25), 18)
	Greybox.cylinder(self, "Balde", Vector3(12.2, 0.17, RECODO_Z1 - 0.28), 0.15, 0.34, Color(0.92, 0.92, 0.9), true, 0.6, 0.0, 0.17)
	Greybox.bin(self, "PapeleraTopico", Vector3(8.65, 0, RECODO_Z1 - 0.3))
	Greybox.downlight(self, "DownRecodo", Vector3(11.6, 2.68, -0.3), Color(0.85, 0.92, 1.0), 0.9, 5.0)
	if not topico_open:
		# T1: en la banca, un bulto con headset que no se mueve. Tras la puerta, la silueta de siempre.
		SiteProps.waiting_figure(self, "BultoEspera", Vector3(11.05, 0, RECODO_Z1 - 0.34), 180.0)
		Greybox.box(self, "Silueta", Vector3(14.3, 0.9, -0.75), Vector3(0.3, 1.8, 0.45), Color(0.04, 0.04, 0.045), false)
		Greybox.box(self, "SiluetaCabeza", Vector3(14.3, 1.95, -0.75), Vector3(0.24, 0.26, 0.22), Color(0.04, 0.04, 0.045), false)
		Greybox.box(self, "RanuraLuz", Vector3(TOPICO_X0 + 0.04, 0.02, dz), Vector3(0.02, 0.02, 0.9), Color(0.85, 0.95, 1.0), false, 2.0)
	# Dentro: camilla, biombo, botiquín, luz fría.
	Greybox.box(self, "TopicoLuz", Vector3(c.x, 2.66, c.y), Vector3(0.3, 0.05, 1.2), Color(0.85, 0.95, 1.0), false, 2.5)
	Greybox.light(self, Vector3(c.x, 2.4, c.y), Color(0.85, 0.95, 1.0), 1.4, 5.0)
	Greybox.box(self, "Camilla", Vector3(15.05, 0.35, 0.45), Vector3(0.7, 0.7, 2.0), Greybox.BLANCO)  # deja 0,4 m libres al punto donde entra el bot
	Greybox.box(self, "Biombo", Vector3(13.5, 0.9, 1.45), Vector3(1.4, 1.8, 0.05), Color(0.6, 0.7, 0.72), false)
	Greybox.box(self, "Botiquin", Vector3(x1 - 0.06, 1.6, -0.8), Vector3(0.12, 0.4, 0.5), Greybox.BLANCO, false)
	if topico_open:
		# T2+: la silueta es la enfermera (rig de agente con uniforme blanco) que te mira al entrar; zona del evento.
		var enf := NpcFigure.make(self, "agente_marko", Vector3(14.3, 0, -0.75), 100.0, 1.68, Color(0.92, 0.93, 0.9), "Enfermera")
		enf.look_radius = 4.0
		enf.look_max_deg = 70.0
		enf.anim_speed = 0.7
		Zone.make(self, "topico", Vector3(c.x, 1.3, c.y), Vector3(s.x - 0.4, 2.6, s.y - 0.4))
	# Marcador dentro del cuarto, mirando a −X (el recodo): su +Z local apunta a la puerta.
	Greybox.marker(self, "topico", Vector3(13.7, 0, dz), -90.0)
	Zone.make(self, "vinilico", Vector3(14.0, 1.5, c.y), Vector3(2.8, 3, 2.8))


## Vestíbulo de baños (x 5,5..8,2, z 6,5..9,3): hombres al sur, mujeres y la puerta doble oscura al este.
func _bathrooms_lobby() -> void:
	Greybox.sfloor(self, "VestibuloPiso", Vector2(6.85, 7.9), Vector2(2.7, 2.8), "vinilico_calido")
	Greybox.sceiling(self, "VestibuloTecho", Vector2(6.85, 7.9), Vector2(2.7, 2.8), 2.7, "baldosa_techo", Color(0.86, 0.85, 0.83))
	Greybox.swall(self, "VestibuloW_N", Vector3(VEST_X0, 1.5, 6.65), Vector3(0.2, 3, 0.3), "pared", Greybox.CREMA)
	Greybox.swall(self, "VestibuloW_S", Vector3(VEST_X0, 1.5, 8.8), Vector3(0.2, 3, 1.0), "pared", Greybox.CREMA)
	Greybox.swall(self, "VestibuloN_W", Vector3(5.75, 1.5, VEST_Z0), Vector3(0.5, 3, 0.2), "pared", Greybox.CREMA)
	# Pared este: puerta doble de vidrio oscuro (z 6,6..7,6, al cuarto sin ver) y, más al sur, la de mujeres.
	Greybox.swall(self, "VestibuloE", Vector3(COR_X1, 1.5, 7.7), Vector3(0.2, 3, 0.2), "pared", Greybox.CREMA)
	for k in 2:
		var hz := 6.85 + k * 0.5
		var leaf := Greybox.box(self, "PuertaDobleOscura%d" % k, Vector3(COR_X1, 1.05, hz), Vector3(0.05, 2.1, 0.48), Color(0.05, 0.07, 0.08, 0.85), false, 0.0)
		Greybox.box(leaf, "Jalador", Vector3(-0.04, 0, 0.18 - k * 0.36), Vector3(0.03, 0.6, 0.03), Greybox.NEGRO, false)
	Greybox.box(self, "PuertaDobleMarco", Vector3(COR_X1, 2.15, 7.1), Vector3(0.1, 0.08, 1.05), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "PuertaDobleA4", Vector3(COR_X1 - 0.04, 1.45, 6.85), Vector3(0.005, 0.3, 0.21), Color(0.92, 0.92, 0.88), false)
	Greybox.invisible_box(self, "PuertaDobleCierre", Vector3(COR_X1, 1.2, 7.1), Vector3(0.2, 2.4, 1.0))
	Greybox.box(self, "PuertaDobleDintel", Vector3(COR_X1, 2.6, 7.1), Vector3(0.2, 0.8, 1.0), Greybox.CREMA, false)
	# Baños comunes: hombres al sur (puerta en su pared norte, z 9,3) y mujeres al este (puerta en su pared oeste).
	add_bathroom("bano_p1", Vector3(5.55, 0, 11.8), Vector2(5.1, 5.0), false, "n", 1.7)
	add_bathroom("bano_p1_b", Vector3(10.95, 0, 10.3), Vector2(5.3, 5.0), false, "w", -1.65, false)
	SiteProps.pictogram(self, Vector3(7.25, 1.45, VEST_Z1 - 0.06), 180.0, "circulo")
	SiteProps.pictogram(self, Vector3(COR_X1 + 0.04, 1.45, 8.65), -90.0, "triangulo")
	Greybox.label(self, "H", Vector3(6.35, 2.3, VEST_Z1 - 0.08), 0.22, Greybox.CIAN, PI)
	Greybox.label(self, "M", Vector3(COR_X1 - 0.02, 2.3, 9.15), 0.22, Greybox.CIAN, -PI * 0.5)
	SiteProps.wet_sign(self, "PisoMojadoBano", Vector3(7.8, 0, 8.45), 160.0)
	Greybox.box(self, "Termostato", Vector3(VEST_X0 + 0.11, 1.4, 9.05), Vector3(0.02, 0.12, 0.09), Greybox.BLANCO, false)
	Greybox.light(self, Vector3(6.85, 2.3, 7.9), Color(0.92, 0.95, 1.0), 0.6, 4.5)
	# El cuarto sin ver detrás de la puerta doble (x 8,2..10,9, z 3,45..7,7): cerrado y a oscuras.
	Greybox.floor_slab(self, "CuartoOscuroPiso", Vector2(9.55, 5.6), Vector2(2.7, 4.2), Color(0.12, 0.12, 0.13))
	Greybox.box(self, "CuartoOscuroN", Vector3(9.55, 1.5, 3.45), Vector3(2.9, 3, 0.2), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "CuartoOscuroE", Vector3(10.9, 1.5, 5.6), Vector3(0.2, 3, 4.4), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "CuartoOscuroS", Vector3(9.55, 1.5, 7.7), Vector3(2.9, 3, 0.15), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "CuartoOscuroTecho", Vector3(9.55, 2.75, 5.6), Vector3(2.7, 0.1, 4.2), Color(0.03, 0.03, 0.035), false)
	for k in 3:
		Greybox.box(self, "SillaApilada%d" % k, Vector3(9.4, 0.45 + k * 0.12, 6.6), Vector3(0.45, 0.06, 0.45), Greybox.NEGRO, false)
	Greybox.box(self, "CajasOscuro", Vector3(10.2, 0.4, 5.2), Vector3(0.8, 0.8, 0.6), Color(0.25, 0.2, 0.14), false)


## Pasillo apagado (x −0,1..5,5, z 6,8..8,3): sale al oeste del vestíbulo, sin luz; dos extintores en la esquina y, al
## fondo, la puerta con mirilla de la sala secundaria. Callejón sin salida.
func _dark_corridor() -> void:
	var cx := (SEC_X1 + VEST_X0) * 0.5
	var w := VEST_X0 - SEC_X1
	Greybox.sfloor(self, "PasilloApagado", Vector2(cx, (OSC_Z0 + OSC_Z1) * 0.5), Vector2(w, OSC_Z1 - OSC_Z0), "vinilico_calido", Color(0.7, 0.7, 0.7))
	Greybox.sceiling(self, "PasilloApagadoTecho", Vector2(cx, (OSC_Z0 + OSC_Z1) * 0.5), Vector2(w, OSC_Z1 - OSC_Z0), 2.7, "baldosa_techo", Color(0.55, 0.55, 0.56))
	Greybox.swall(self, "PasilloApagadoN", Vector3(cx, 1.5, OSC_Z0), Vector3(w, 3, 0.2), "pared", Greybox.CREMA)
	Greybox.swall(self, "PasilloApagadoS", Vector3(cx, 1.5, OSC_Z1), Vector3(w, 3, 0.2), "pared", Greybox.CREMA)
	Greybox.extinguisher(self, "ExtintorEsquina0", Vector3(5.15, 0, OSC_Z0 + 0.22), 21)
	Greybox.extinguisher(self, "ExtintorEsquina1", Vector3(4.8, 0, OSC_Z0 + 0.22), 22)
	OfficeHorror.tube(self, "TuboMuertoApagado", Vector3(2.6, 2.66, 7.55), true, false)
	OfficeHorror.stained_tile(self, Vector3(1.4, 2.645, 7.6))
	# La puerta de la sala secundaria (Training0): cerrada, con la mirilla que deja salir el resplandor azul.
	var d := WorldObjects.simple(self, WorldObjects.Door, "Training0", "HUD_DOOR", Vector3(SEC_X1, 1.1, 7.55), Vector3(0.9, 2.2, 0.06), Greybox.PUERTA_BLANCA, 90.0)
	(d as WorldObjects.Door).locked = true
	(d as WorldObjects.Door).locked_key = "SIGN_TRAINING_CLOSED"
	var hoja := d.get_node_or_null("Caja") as Node3D
	if hoja != null:
		var mirilla := Greybox.box(hoja, "Mirilla", Vector3(0, 0.35, 0.032), Vector3(0.12, 0.2, 0.005), Color(0.2, 0.35, 1.0), false, 2.5)
		mirilla.name = "Mirilla"
		Greybox.box(hoja, "Manija", Vector3(-0.33, -0.05, 0.05), Vector3(0.12, 0.03, 0.03), Greybox.INOX, false)
	WorldObjects.signage(self, "SIGN_TRAINING", Vector3(SEC_X1 + 0.12, 2.35, 7.55), 90.0, 0.16)
	Greybox.label(self, "2", Vector3(SEC_X1 + 0.12, 2.12, 7.55), 0.16, Greybox.CIAN, PI * 0.5)
	Greybox.swall(self, "PasilloApagadoW_N", Vector3(SEC_X1, 1.5, 6.95), Vector3(0.2, 3, 0.3), "pared", Greybox.CREMA)
	Greybox.swall(self, "PasilloApagadoW_S", Vector3(SEC_X1, 1.5, 8.15), Vector3(0.2, 3, 0.3), "pared", Greybox.CREMA)
	Greybox.box(self, "Training0Dintel", Vector3(SEC_X1, 2.6, 7.55), Vector3(0.2, 0.8, 0.9), Greybox.CREMA, false)
	var spill := Greybox.light(self, Vector3(SEC_X1 + 0.5, 1.4, 7.55), Color(0.25, 0.4, 1.0), 0.35, 2.6)
	spill.name = "ResplandorMirilla"


## Sala de training SECUNDARIA (x −5,4..−0,1, z 6,75..13,65): más chica, a oscuras, solo el azul de las pantallas.
func _secondary_room() -> void:
	var c := Vector2((SEC_X0 + SEC_X1) * 0.5, (SEC_Z0 + SEC_Z1) * 0.5)
	var s := Vector2(SEC_X1 - SEC_X0, SEC_Z1 - SEC_Z0)
	Greybox.sfloor(self, "TrainingPiso0", c, s, "vinilico_claro", Color(0.6, 0.6, 0.62))
	Greybox.ceiling(self, "TrainingTecho0", c, s, 2.7, Color(0.08, 0.08, 0.09))
	Greybox.box(self, "Training0ParedW", Vector3(SEC_X0, 1.5, c.y), Vector3(0.2, 3, s.y), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "Training0ParedN", Vector3(c.x, 1.5, SEC_Z0), Vector3(s.x, 3, 0.2), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "Training0ParedS", Vector3(c.x, 1.5, SEC_Z1), Vector3(s.x, 3, 0.2), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "Training0ParedE", Vector3(SEC_X1, 1.5, (8.3 + SEC_Z1) * 0.5), Vector3(0.2, 3, SEC_Z1 - 8.3), Greybox.GRIS_OSCURO, false)
	for r in 3:
		var dz := 9.0 + r * 1.6
		Greybox.box(self, "Mesa0_%d" % r, Vector3(-3.0, 0.74, dz), Vector3(3.6, 0.05, 0.6), Color(0.3, 0.28, 0.25), false)
		for k in 3:
			var sx := -4.2 + k * 1.2
			Greybox.box(self, "PCAzul%d_%d" % [r, k], Vector3(sx, 0.97, dz - 0.18), Vector3(0.46, 0.28, 0.03), Color(0.15, 0.3, 0.95), false, 1.6)
			Greybox.box(self, "Silla0_%d_%d" % [r, k], Vector3(sx, 0.45, dz + 0.6), Vector3(0.4, 0.05, 0.4), Greybox.NEGRO, false)
	OfficeHorror.chair_to_wall(self, Vector3(-4.9, 0, 12.9), 45.0)
	var blue := Greybox.light(self, Vector3(-2.7, 1.2, 10.2), Color(0.25, 0.4, 1.0), 0.9, 5.5)
	blue.name = "ResplandorAzul"


## Capa de horror de oficina (genérica, sin colisión, fuera de rutas y marcadores).
func _horror() -> void:
	OfficeHorror.tube(self, "TuboTartamudo", Vector3(-6.2, 2.66, 0.0), true, true)
	OfficeHorror.stained_tile(self, Vector3(-4.4, 2.645, 0.5))
	# rc1 (capturas 1080p): en z −0,3 colgaba justo delante del cartel «Tópico» (sobre su puerta); se corre al lado sur.
	OfficeHorror.hanging_tile(self, Vector3(10.6, 2.64, 0.35), 90.0)
	OfficeHorror.scratched_kpi(self, Vector3(-7.6, 1.75, HALL_Z - 0.13), 180.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_4", Vector3(6.4, 1.45, FRONT_Z + 0.04), 0.0, true, -6.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_8", Vector3(9.7, 1.6, FRONT_Z + 0.04), 0.0, false, 4.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_1", Vector3(COR_X1 - 0.11, 1.35, 5.4), -90.0, false, 8.0)
	OfficeHorror.headset(self, Vector3(12.6, 0.74, -7.0), 90.0)
	OfficeHorror.moldy_cup(self, Vector3(12.2, 0.765, -5.75))
	OfficeHorror.disconnected_monitor(self, Vector3(12.3, 0.97, -7.5), 0.0)
	OfficeHorror.out_of_order(get_node("Bano_bano_p1_b") as Node3D, Vector3(-1.37, 1.4, -1.25), 90.0)  # en un cubículo


func env_settings() -> Dictionary:
	return {
		"ambient": Color(0.22, 0.27, 0.3), "ambient_energy": 0.34,
		"fog": Color(0.015, 0.024, 0.026), "fog_density": 0.011, "bg": Color(0.008, 0.01, 0.014),
	}


func _ambient() -> void:
	AudioManager.play_ambient("aire_acondicionado")
	AudioManager.play_ambient("fluorescente_zumbido")


func ambience_events() -> Array[String]:
	return ["pa", "susurro", "llanto", "silencio"]


func ambience_points() -> Array[Vector3]:
	return [Vector3(10.0, 1.3, -6.0), Vector3(-6.0, 1.3, 0.0), Vector3(2.5, 1.3, 7.5), Vector3(-2.7, 1.3, 10.2), Vector3(11.0, 1.5, 0.0)]


	if GameState.turno == 6 and not bool(GameState.flags.get("frag_carta_2", false)):
		var f2 := WorldObjects.simple(self, WorldObjects.ResignationFragment, "FragmentoCarta2", "HUD_TURNSTILE", Vector3(8.15, 1.05, -1.35), Vector3(0.24, 0.03, 0.32), Color(0.95, 0.92, 0.82), 0.0, 0.6)
		(f2 as WorldObjects.ResignationFragment).frag_id = 2

func screamer_killers() -> Array:
	return ["shero", "trainer"]

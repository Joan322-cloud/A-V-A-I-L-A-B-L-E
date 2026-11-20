class_name Stairwell
extends FloorBase
## Caja de escalera entre dos pisos como espacio liminal. v0.3.1 Q5 (site, REFERENCIA_PISOS §4 y §7.4): escalera
## de emergencia en U, BLANCA: dos tramos de 10 peldaños de concreto gris con 3 ranuras y franja amarilla gastada en
## las narices de los descansos, descanso a medio nivel donde das la vuelta, baranda de tubo gris con la pintura
## saltada (asoma rojo debajo), pasamanos azul-gris en la pared, montante rojo de incendio en la esquina y un aplique
## redondo por descanso. Puertas cortafuego grises con barra antipánico y "SALIDA".
## En planta los tramos van lado a lado (x > 0 sube hacia +Z, x < 0 sube hacia −Z) y los dos descansos de las
## puertas también, así ninguna celda tiene dos alturas (la rejilla de Pursuit y las auditorías siguen valiendo).
## Con Fatiga alta (>= umbral de microsueño) el tramo se repite una vez EN EL GIRO del descanso: das la vuelta en U,
## un parpadeo, y estás otra vez al pie del mismo tramo. Por el hueco central, si miras abajo, la escalera sigue más
## allá del -1. Subiendo de 2 hay medio tramo más que muere en una cortafuego con lector rojo (pisos 3-8).

const STEPS := 20  # total de peldaños (10 por tramo)
const RISE := 3.2
const RUN := 2.8   # largo de cada tramo
const HALF := RISE * 0.5
const Z_LAND0 := 2.0   # fin de los descansos de las puertas / pie de los tramos
const Z_MID := Z_LAND0 + RUN  # 4,8: descanso a medio nivel (z 4,8..6,8)
const Z_END := Z_MID + 2.0
const GAP := 0.2   # media anchura del hueco central
const WALL := 2.1  # cara interior de las paredes laterales

const BLANCO := Color(0.875, 0.890, 0.906)
const TUBERIA := Color(0.718, 0.196, 0.235)
const BARANDA := Color(0.373, 0.388, 0.400)
const PASAMANOS := Color(0.310, 0.365, 0.420)

var from_floor: int = -1
var to_floor: int = 1
var going_up: bool = true
var _repeated: bool = false
var _entry_marker: Vector3 = Vector3.ZERO
var _entry_yaw: float = 0.0


func _build() -> void:
	floor_number = from_floor
	var piso := Greybox.surf("concreto_escalera")
	var pared := Greybox.surf("pared", BLANCO)
	var h := RISE + 3.2
	var top_floor := to_floor if going_up else from_floor
	var stub := top_floor == 2  # medio tramo hacia 3-8
	var xr := (GAP + WALL) * 0.5  # centro del carril derecho (x > 0)
	var w := WALL - GAP
	# Descansos: bajo (x > 0, z 0..2), medio (todo el ancho, z 4,8..6,8, y 1,6) y alto (x < 0, z 0..2, y 3,2).
	Greybox.box(self, "DescansoBajo", Vector3(xr, -0.05, Z_LAND0 * 0.5), Vector3(w, 0.1, Z_LAND0), Greybox.GRIS).material_override = piso
	var mid := Greybox.box(self, "DescansoMedio", Vector3(0, HALF - 0.05, (Z_MID + Z_END) * 0.5), Vector3(WALL * 2.0, 0.1, Z_END - Z_MID), Greybox.GRIS)
	mid.material_override = piso
	Greybox.box(self, "DescansoAlto", Vector3(-xr, RISE - 0.05, Z_LAND0 * 0.5), Vector3(w, 0.1, Z_LAND0), Greybox.GRIS).material_override = piso
	# Franjas amarillas gastadas en la nariz de los descansos.
	Greybox.box(self, "FranjaMedio", Vector3(0, HALF + 0.002, Z_MID + 0.05), Vector3(WALL * 2.0 - 0.1, 0.004, 0.08), Greybox.AMARILLO_FRANJA, false)
	Greybox.box(self, "FranjaAlto", Vector3(-xr, RISE + 0.002, Z_LAND0 - 0.05), Vector3(w - 0.1, 0.004, 0.08), Greybox.AMARILLO_FRANJA, false)
	Greybox.box(self, "FranjaBajo", Vector3(xr, 0.002, Z_LAND0 - 0.05), Vector3(w - 0.1, 0.004, 0.08), Greybox.AMARILLO_FRANJA, false)
	# Tramos: A (x > 0) sube de z 2 a 4,8; B (x < 0) sube de z 4,8 a 2. Peldaños visuales + rampa de colisión.
	var n := STEPS / 2
	for f in 2:
		var sx := xr if f == 0 else -xr
		for i in n:
			var t := float(i) / n
			var y := HALF * f + HALF * t + HALF / n * 0.5
			var z := Z_LAND0 + RUN * t + RUN / n * 0.5 if f == 0 else Z_MID - RUN * t - RUN / n * 0.5
			var s := Greybox.box(self, "Peldano%d_%02d" % [f, i], Vector3(sx, y, z), Vector3(w, HALF / n, RUN / n), Greybox.GRIS, false)
			s.material_override = piso
			var nose := -RUN / n * 0.5 + 0.05 if f == 0 else RUN / n * 0.5 - 0.05
			for k in 3:
				Greybox.box(s, "Ranura%d" % k, Vector3(0, HALF / n * 0.5 + 0.002, nose + (k * 0.035 if f == 0 else -k * 0.035)), Vector3(w - 0.2, 0.004, 0.012), Color(0.25, 0.24, 0.22), false)
			if i == 0 or i == n - 1:
				Greybox.box(s, "Franja", Vector3(0, HALF / n * 0.5 + 0.003, nose), Vector3(w - 0.1, 0.004, 0.06), Greybox.AMARILLO_FRANJA, false)
		var ramp := StaticBody3D.new()
		ramp.name = "Rampa%s" % ("A" if f == 0 else "B")
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var len := sqrt(RUN * RUN + HALF * HALF)
		bs.size = Vector3(w, 0.2, len + 0.3)
		shape.shape = bs
		ramp.add_child(shape)
		ramp.position = Vector3(sx, HALF * f + HALF * 0.5 - 0.1, Z_LAND0 + RUN * 0.5)
		ramp.rotation.x = -atan2(HALF, RUN) if f == 0 else atan2(HALF, RUN)
		add_child(ramp)
		# Pasamanos azul-gris sobre ménsulas en la pared y baranda de tubo gris del lado del hueco.
		var wall_x := WALL - 0.06 if f == 0 else -WALL + 0.06
		var hand := Greybox.box(self, "Pasamanos%d" % f, Vector3(wall_x, HALF * f + HALF * 0.5 + 0.9, Z_LAND0 + RUN * 0.5), Vector3(0.05, 0.05, len), PASAMANOS, false)
		hand.rotation.x = ramp.rotation.x
		var rail_x := GAP + 0.03 if f == 0 else -GAP - 0.03
		var rail := Greybox.box(self, "Baranda%d" % f, Vector3(rail_x, HALF * f + HALF * 0.5 + 0.95, Z_LAND0 + RUN * 0.5), Vector3(0.05, 0.05, len), BARANDA, false)
		rail.rotation.x = ramp.rotation.x
		rail.material_override = Greybox.material(BARANDA, 0.0, 0.5, 0.3)
		for k in 4:
			var tk := (k + 0.5) / 4.0
			var zk := Z_LAND0 + RUN * tk
			var yk := HALF * f + (HALF * tk if f == 0 else HALF * (1.0 - tk))
			Greybox.box(self, "BarandaPoste%d_%d" % [f, k], Vector3(rail_x, yk + 0.5, zk), Vector3(0.04, 1.0, 0.04), BARANDA, false)
			if k == 2:
				Greybox.box(self, "PinturaSaltada%d" % f, Vector3(rail_x, yk + 0.97, zk), Vector3(0.055, 0.03, 0.12), Color(0.55, 0.12, 0.1), false)  # rojo bajo la pintura
	# Hueco central (x ±0,2): no se cae (colisión a toda altura); abajo la escalera sigue más allá del -1.
	Greybox.invisible_box(self, "HuecoCentral", Vector3(0, h * 0.5, (Z_LAND0 + Z_MID) * 0.5), Vector3(GAP * 2.0, h, RUN))
	Greybox.box(self, "MuroCentral", Vector3(0, h * 0.5, Z_LAND0 * 0.5 - 0.05), Vector3(0.2, h, Z_LAND0 + 0.1), BLANCO).material_override = pared
	for k in 10:
		var d := Greybox.box(self, "PeldanoAbismo%d" % k, Vector3(0.0, -0.6 - k * 0.55, Z_LAND0 + 0.3 + (k % 5) * 0.55), Vector3(GAP * 2.0 - 0.02, 0.08, 0.28), Color(0.3, 0.29, 0.26), false)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var abismo := Greybox.light(self, Vector3(0, -4.5, Z_LAND0 + 1.4), Color(1.0, 0.23, 0.12), 0.5, 4.0)
	abismo.name = "LuzAbismo"
	# Paredes blancas, techo alto, montante rojo en la esquina.
	Greybox.box(self, "ParedW", Vector3(-WALL - 0.1, h * 0.5, Z_END * 0.5), Vector3(0.2, h, Z_END + 0.4), BLANCO).material_override = pared
	Greybox.box(self, "ParedE", Vector3(WALL + 0.1, h * 0.5, Z_END * 0.5), Vector3(0.2, h, Z_END + 0.4), BLANCO).material_override = pared
	Greybox.box(self, "ParedN", Vector3(0, h * 0.5, Z_END + 0.1), Vector3(WALL * 2.0 + 0.4, h, 0.2), BLANCO).material_override = pared
	if stub:
		Greybox.box(self, "ParedS", Vector3(xr, h * 0.5, -0.1), Vector3(w + 0.4, h, 0.2), BLANCO).material_override = pared
		Greybox.box(self, "ParedS_Bajo", Vector3(-xr, (RISE - 0.1) * 0.5, -0.1), Vector3(w + 0.2, RISE - 0.1, 0.2), BLANCO).material_override = pared
	else:
		Greybox.box(self, "ParedS", Vector3(0, h * 0.5, -0.1), Vector3(WALL * 2.0 + 0.4, h, 0.2), BLANCO).material_override = pared
	Greybox.ceiling(self, "Techo", Vector2(0, Z_END * 0.5), Vector2(WALL * 2.0 + 0.4, Z_END + 0.4), h, Color(0.75, 0.76, 0.77))
	for k in 2:
		Greybox.cylinder(self, "Montante%d" % k, Vector3(WALL - 0.12 - k * 0.14, h * 0.5, Z_END - 0.12), 0.055, h, TUBERIA, false, 0.5, 0.2)
	Greybox.box(self, "CajaElectrica", Vector3(WALL - 0.05, 1.5, 0.6), Vector3(0.12, 0.5, 0.4), Greybox.GRIS_OSCURO, false)
	# Un aplique redondo por descanso; el del medio falla (y la blancura se vuelve gris enfermo).
	_wall_lamp("ApliqueBajo", Vector3(WALL - 0.03, 2.3, 1.0), -90.0, 0.85, false)
	_wall_lamp("ApliqueMedio", Vector3(0, HALF + 2.3, Z_END - 0.03), 180.0, 0.75, true)
	_wall_lamp("ApliqueAlto", Vector3(-WALL + 0.03, RISE + 2.3, 1.5), 90.0, 0.8, false)
	# Puertas cortafuego: baja (x > 0, pared sur) y alta (x < 0, pared oeste), con barra antipánico y ventanita.
	_fire_door(Vector3(xr, 1.05, 0.05), 0.0, from_floor if going_up else to_floor, not going_up)
	_fire_door(Vector3(-WALL + 0.05, RISE + 1.05, 1.0), 90.0, to_floor if going_up else from_floor, going_up)
	_stencil(from_floor if going_up else to_floor, Vector3(WALL - 0.02, 1.9, 1.4), -PI * 0.5)
	_stencil(to_floor if going_up else from_floor, Vector3(-0.12, RISE + 1.9, 1.2), PI * 0.5)
	WorldObjects.signage(self, "SIGN_STAIRS_UP_ARROW" if going_up else "SIGN_STAIRS_DOWN_ARROW", Vector3(0, HALF + 1.6, Z_END - 0.02), 180.0, 0.16, Color(0.3, 0.3, 0.3))
	Greybox.exit_sign(self, "SalidaBaja", Vector3(xr, 2.35, 0.03), 0.0)
	Greybox.exit_sign(self, "SalidaAlta", Vector3(-WALL + 0.03, RISE + 2.35, 1.0), 90.0)
	# Huellas en la franja amarilla que no corresponden a ningún zapato.
	SiteProps.footprints(self, "HuellaRara", Vector3(-1.6, HALF, Z_MID + 0.3), Vector3(1.6, HALF, Z_MID + 0.3), 0.9)
	# Medio tramo hacia la oscuridad (hacia 3-8) con cortafuego bloqueada al final.
	if stub:
		_stub(-xr, w, h, piso, pared)
	# Zonas: el giro del descanso (para la repetición) y spawn.
	Zone.make(self, "escalera_salida", Vector3(0, HALF + 1.4, (Z_MID + Z_END) * 0.5), Vector3(WALL * 2.0, 2.8, Z_END - Z_MID))
	if going_up:
		_entry_marker = Vector3(xr, 0, 1.0)
		_entry_yaw = 180.0
	else:
		_entry_marker = Vector3(-xr, RISE, 1.0)
		_entry_yaw = 180.0
	Greybox.marker(self, "escalera", _entry_marker, _entry_yaw)
	Greybox.marker(self, "ascensor", _entry_marker, _entry_yaw)
	# v0.3.1 (integración): la otra puerta de la caja. Si te quedas quieto en la puerta por la que entraste, el
	# cazador entra por esta (Pursuit._entry_point) y no aparece encima de ti.
	var other := Vector3(-xr, RISE, 1.0) if going_up else Vector3(xr, 0, 1.0)
	Greybox.marker(self, "escalera_otra", other, 0.0)
	EventBus.player_entered_zone.connect(_on_zone)


func _stub(cx: float, w: float, h: float, piso: Material, pared: Material) -> void:
	var srun := 2.4
	var srise := 1.2
	for i in 8:
		var sx := Greybox.box(self, "PeldanoX%02d" % i, Vector3(cx, RISE + srise / 8.0 * (i + 0.5), -srun / 8.0 * (i + 0.5)), Vector3(w, srise / 8.0, srun / 8.0), Greybox.GRIS, false)
		sx.material_override = piso
	var stub_ramp := StaticBody3D.new()
	stub_ramp.name = "RampaStub"
	var ss := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	var slen := sqrt(srun * srun + srise * srise)
	sb.size = Vector3(w, 0.2, slen + 0.4)
	ss.shape = sb
	stub_ramp.add_child(ss)
	stub_ramp.position = Vector3(cx, RISE + srise * 0.5 - 0.1, -srun * 0.5)
	stub_ramp.rotation.x = atan2(srise, srun)
	add_child(stub_ramp)
	Greybox.invisible_box(self, "StubDescanso", Vector3(cx, RISE + srise - 0.1, -srun - 0.5), Vector3(w, 0.2, 1.0))
	Greybox.box(self, "StubDescansoVis", Vector3(cx, RISE + srise - 0.05, -srun - 0.5), Vector3(w, 0.1, 1.0), Greybox.GRIS, false).material_override = piso
	Greybox.box(self, "ParedStubE", Vector3(cx + w * 0.5 + 0.1, RISE + h * 0.25, -srun * 0.5 - 0.5), Vector3(0.2, h * 0.5 + 1.2, srun + 1.2), BLANCO).material_override = pared
	Greybox.box(self, "ParedStubW", Vector3(cx - w * 0.5 - 0.1, RISE + h * 0.25, -srun * 0.5 - 0.5), Vector3(0.2, h * 0.5 + 1.2, srun + 1.2), BLANCO).material_override = pared
	Greybox.box(self, "ParedStubS", Vector3(cx, RISE + h * 0.25, -srun - 1.1), Vector3(w + 0.4, h * 0.5 + 1.2, 0.2), BLANCO).material_override = pared
	Greybox.ceiling(self, "TechoStub", Vector2(cx, -srun * 0.5 - 0.5), Vector2(w + 0.4, srun + 1.2), RISE + srise + 2.6, Color(0.1, 0.1, 0.11))
	var blocked := WorldObjects.Stairs.new()
	blocked.name = "PuertaBloqueada"
	blocked.target_floor = 3
	blocked.going_up = true
	blocked.blocked_reader = true
	blocked.size = Vector3(1.2, 2.2, 0.8)
	blocked.position = Vector3(cx, RISE + srise + 1.05, -srun - 0.95)
	add_child(blocked)
	Greybox.box(blocked, "Hoja", Vector3.ZERO, Vector3(1.0, 2.1, 0.08), Greybox.CORTAFUEGO, true)
	Greybox.box(blocked, "Barra", Vector3(0, -0.05, 0.06), Vector3(0.8, 0.05, 0.05), Greybox.INOX, false)
	Greybox.box(blocked, "Lector", Vector3(0.65, 0.2, 0.06), Vector3(0.06, 0.1, 0.03), Greybox.ROJO, false, 2.0)
	Greybox.label(blocked, tr("SIGN_FIRE_DOOR"), Vector3(0, 0.75, 0.06), 0.1, Greybox.ROJO)
	_stencil(3, Vector3(cx + w * 0.5 - 0.02, RISE + srise + 1.9, -srun - 0.4), -PI * 0.5)
	Greybox.light(self, Vector3(cx, RISE + srise + 2.2, -srun - 0.4), Color(1.0, 0.23, 0.12), 0.35, 3.5)  # luz de emergencia


func _wall_lamp(p_name: String, pos: Vector3, yaw: float, energy: float, flicker: bool) -> void:
	var l := Greybox.cylinder(self, p_name, pos, 0.14, 0.06, Color(1.0, 0.96, 0.9))
	l.rotation_degrees = Vector3(90.0, yaw, 0.0)
	l.material_override = Greybox.material(Color(1.0, 0.95, 0.88), 2.2)
	var lt := Greybox.light(l, Vector3(0, 0.3, 0), Color(0.92, 0.95, 1.0), energy, 6.0)
	if flicker:
		var f := FlickerLight.attach(l)
		f.light = lt


## Puerta cortafuego con barra antipánico y ventanita de vidrio armado; lleva al piso `target`.
func _fire_door(pos: Vector3, rot_deg: float, target: int, is_exit: bool) -> Node3D:
	var d := WorldObjects.Stairs.new()
	d.name = "Puerta_%s" % ("salida" if is_exit else "regreso")
	d.target_floor = target
	d.going_up = going_up
	d.direct = true  # desde la caja de escalera se sale directo al piso (sin otra caja)
	d.size = Vector3(1.3, 2.2, 0.9)
	d.position = pos
	d.rotation_degrees.y = rot_deg
	add_child(d)
	Greybox.box(d, "Hoja", Vector3.ZERO, Vector3(1.0, 2.1, 0.08), Greybox.CORTAFUEGO, true)
	Greybox.box(d, "Barra", Vector3(0, -0.05, 0.08), Vector3(0.8, 0.05, 0.05), Greybox.INOX, false)
	Greybox.box(d, "Ventanita", Vector3(0.2, 0.55, 0.045), Vector3(0.2, 0.5, 0.01), Color(0.6, 0.7, 0.7, 0.5), false)
	Greybox.label(d, tr("SIGN_FIRE_DOOR_PUSH"), Vector3(0, 0.15, 0.06), 0.07, Color(0.2, 0.2, 0.2))
	return d


func _stencil(f: int, pos: Vector3, rot_y: float) -> void:
	var txt := Loc.fmt(tr("SIGN_STAIRS_FLOOR"), {"n": ("S" if f == -1 else str(f))})
	Greybox.label(self, txt, pos, 0.3, Color(0.35, 0.34, 0.3), rot_y)


func _on_zone(id: String) -> void:
	if id != "escalera_salida" or _repeated:
		return
	if Fatigue.value < float(DataLoader.bal("fatiga/umbral_microsueno", 70.0)):
		return
	_repeated = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# En el giro del descanso: parpadeo y otra vez al pie del mismo tramo (nunca delante de ti sin parpadeo, GDD 4.7).
	EventBus.screen_black.emit(0.45)
	AudioManager.play_sting()
	player.teleport(global_position + _entry_marker, _entry_yaw)
	EventBus.show_message.emit(tr("MSG_STAIRS_AGAIN"), 3.0)
	EventBus.distortion_triggered.emit("escalera_repetida")


func env_settings() -> Dictionary:
	return {
		"ambient": Color(0.2, 0.21, 0.22), "ambient_energy": 0.3,
		"fog": Color(0.01, 0.012, 0.014), "fog_density": 0.016, "bg": Color(0.004, 0.005, 0.007),
	}


func _ambient() -> void:
	AudioManager.play_ambient("fluorescente_zumbido")

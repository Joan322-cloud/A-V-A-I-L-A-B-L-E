class_name OfficeHorror
extends RefCounted
## v0.3.1 pisos: capa de horror de oficina de call center para -1, 1 y 2 (pedido de Joan: «assets o muchas cosas de
## horror adaptándolo a call center»). Todo genérico (sin marcas, logos ni texto de las fotos), sin colisión (no tapa
## rutas, marcadores ni colisionadores de los bots) y barato: cajas y Label3D sin luces propias; lo que se mueve lo hace
## un _process a pocos Hz, y en Modo liviano lo estático se funde en los lotes de GfxQuality.

const MANCHA := Color(0.36, 0.3, 0.2, 0.55)
const MOHO := Color(0.32, 0.38, 0.22)
const PAPEL := Color(0.93, 0.92, 0.88)


## Tubo fluorescente MUERTO (sin luz) o que parpadea solo con su emisión (sin OmniLight: no suma luces).
static func tube(parent: Node, p_name: String, pos: Vector3, along_x: bool = true, blinking: bool = false) -> MeshInstance3D:
	var size := Vector3(1.2, 0.04, 0.12) if along_x else Vector3(0.12, 0.04, 1.2)
	var t := Greybox.box(parent, p_name, pos, size, Color(0.55, 0.58, 0.58), false, 0.0)
	Greybox.box(t, "Borde", Vector3(0, 0.025, 0), size + Vector3(0.1, 0.0, 0.1), Greybox.GRIS_OSCURO, false)
	# Puntas ennegrecidas del tubo quemado.
	for s in [-1.0, 1.0]:
		var off := Vector3(s * 0.55, -0.005, 0) if along_x else Vector3(0, -0.005, s * 0.55)
		Greybox.box(t, "Punta%d" % int(s), off, Vector3(0.1, 0.03, 0.1), Color(0.1, 0.1, 0.1), false)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if blinking:
		var m := Greybox.material(Color(0.8, 0.95, 0.95), 1.6).duplicate() as StandardMaterial3D
		t.material_override = m
		t.set_meta("no_merge", true)
		var b := _TubeBlink.new()
		b.name = "Tartamudeo"
		b.mat = m
		t.add_child(b)
	return t


class _TubeBlink extends Node:
	var mat: StandardMaterial3D = null
	var _t: float = 0.0
	var _on: bool = true

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or mat == null:
			return
		var soft := bool(Loc.get_setting("flash_reduction", false))
		_on = not _on
		# Tartamudeo: ráfagas cortas apagado/prendido, y a ratos se queda muerto un par de segundos.
		_t = randf_range(0.6, 1.4) if soft else (randf_range(0.04, 0.12) if randf() < 0.75 else randf_range(0.8, 2.6))
		mat.emission_energy_multiplier = (1.6 if _on else 0.05) if not soft else (1.2 if _on else 0.6)


## Mancha de humedad en una baldosa del techo (vista desde abajo).
static func stained_tile(parent: Node, pos: Vector3, size: Vector2 = Vector2(0.6, 0.6)) -> MeshInstance3D:
	var s := Greybox.box(parent, "BaldosaManchada", pos, Vector3(size.x, 0.004, size.y), MANCHA, false)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(s, "Aureola", Vector3(0.05, -0.002, -0.04), Vector3(size.x * 0.55, 0.003, size.y * 0.5), Color(0.22, 0.17, 0.1, 0.6), false)
	return s


## Baldosa del techo descolgada: cuelga de un lado y deja ver el hueco negro del plenum.
static func hanging_tile(parent: Node, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "BaldosaColgando"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	Greybox.box(root, "Hueco", Vector3(0, 0.01, 0), Vector3(0.6, 0.004, 0.6), Color(0.01, 0.01, 0.012), false)
	var hinge := Node3D.new()
	hinge.name = "Bisagra"
	hinge.position = Vector3(-0.3, 0, 0)
	hinge.rotation_degrees.z = -58.0
	root.add_child(hinge)
	var tile := Greybox.sbox(hinge, "Baldosa", Vector3(0.3, -0.01, 0), Vector3(0.6, 0.015, 0.6), "baldosa_techo", false, Color(0.8, 0.75, 0.66))
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(root, "Cable", Vector3(0.05, -0.25, 0.1), Vector3(0.01, 0.5, 0.01), Greybox.NEGRO, false)
	return root


## Notas adhesivas con frases del call center (claves Q5_H_NOTA_*), pegadas a una pared o vidrio.
static func sticky(parent: Node, key: String, pos: Vector3, yaw_deg: float, pink: bool = false, tilt: float = 0.0) -> MeshInstance3D:
	return HorrorProps.note(parent, key, pos, yaw_deg, pink, tilt)


## Headset abandonado colgando del borde de un escritorio, balanceándose solo.
static func headset(parent: Node, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HeadsetColgando"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var pivot := Node3D.new()
	pivot.name = "Pivote"
	root.add_child(pivot)
	Greybox.box(pivot, "Cable", Vector3(0, -0.22, 0), Vector3(0.008, 0.44, 0.008), Greybox.NEGRO, false)
	var band := Greybox.cylinder(pivot, "Vincha", Vector3(0, -0.47, 0), 0.09, 0.02, Color(0.06, 0.06, 0.07), false)
	band.rotation_degrees.x = 90.0
	for s in [-1.0, 1.0]:
		Greybox.cylinder(pivot, "Auricular%d" % int(s), Vector3(s * 0.085, -0.53, 0), 0.035, 0.03, Color(0.04, 0.04, 0.05), false).rotation_degrees.z = 90.0
	var sw := _Swing.new()
	sw.name = "Balanceo"
	sw.target = pivot
	root.add_child(sw)
	return root


class _Swing extends Node:
	var target: Node3D = null
	var _t: float = 0.0
	var _acc: float = 0.0

	func _process(delta: float) -> void:
		_acc += delta
		if _acc < 1.0 / 20.0 or target == null:
			return
		_t += _acc
		_acc = 0.0
		target.rotation.z = sin(_t * 1.3) * 0.12 * (0.6 + 0.4 * sin(_t * 0.21))


## Silla de oficina vacía girada hacia la pared.
static func chair_to_wall(parent: Node, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = "SillaContraPared"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var malla := Greybox.material(Color(0.106, 0.110, 0.118), 0.0, 0.8)
	Greybox.box(root, "Asiento", Vector3(0, 0.47, 0), Vector3(0.48, 0.06, 0.46), Greybox.GRIS_OSCURO, false).material_override = malla
	Greybox.box(root, "Respaldo", Vector3(0, 0.82, 0.22), Vector3(0.44, 0.58, 0.04), Greybox.GRIS_OSCURO, false).material_override = malla
	var p := Greybox.cylinder(root, "Piston", Vector3(0, 0.22, 0), 0.025, 0.42, Greybox.NEGRO, false, 0.6, 0.2)
	Greybox.cylinder(p, "Estrella", Vector3(0, -0.19, 0), 0.26, 0.03, Greybox.NEGRO, false, 0.6, 0.2)
	return root


## Poster viejo de KPI («empleado del mes»): 3 cabezas genéricas sin rostro, tachadas con marcador negro.
static func scratched_kpi(parent: Node, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PosterKpiTachado"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	Greybox.box(root, "Moldura", Vector3(0, 0, -0.01), Vector3(0.95, 0.68, 0.02), Greybox.MARCO_NEGRO, false)
	Greybox.box(root, "Papel", Vector3(0, 0, 0.002), Vector3(0.88, 0.6, 0.004), Color(0.8, 0.78, 0.68), false)
	var t := Greybox.label(root, "", Vector3(0, 0.23, 0.006), 0.05, Color(0.2, 0.28, 0.45))
	t.text = root.tr("Q5_H_KPI") if root.is_inside_tree() else TranslationServer.translate("Q5_H_KPI")
	t.outline_size = 0
	for i in 3:
		var x := -0.28 + i * 0.28
		Greybox.box(root, "Cabeza%d" % i, Vector3(x, 0.02, 0.006), Vector3(0.14, 0.18, 0.002), Color(0.55, 0.53, 0.5), false)
		Greybox.box(root, "Hombros%d" % i, Vector3(x, -0.13, 0.006), Vector3(0.22, 0.1, 0.002), Color(0.3, 0.35, 0.45), false)
		for k in 3:
			var sc := Greybox.box(root, "Tachon%d_%d" % [i, k], Vector3(x + (k - 1) * 0.02, 0.02, 0.009), Vector3(0.2, 0.018, 0.002), Color(0.02, 0.02, 0.02), false)
			sc.rotation_degrees.z = 35.0 + k * 22.0 + i * 9.0
		var pct := Greybox.label(root, "%d%%" % [97, 61, 12][i], Vector3(x, -0.22, 0.007), 0.035, Color(0.7, 0.1, 0.1))
		pct.outline_size = 0
	return root


## Impresora atascada: bandeja con papel desparramado en el piso y un LED ámbar que parpadea «ATASCO».
static func jammed_printer(parent: Node, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = "ImpresoraAtascada"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	Greybox.box(root, "Mueble", Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.55), Greybox.GRIS_OSCURO, false)
	Greybox.box(root, "Cuerpo", Vector3(0, 0.92, 0), Vector3(0.6, 0.45, 0.5), Color(0.82, 0.82, 0.8), false)
	Greybox.box(root, "Bandeja", Vector3(0, 0.86, 0.3), Vector3(0.4, 0.02, 0.18), Color(0.7, 0.7, 0.68), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 9:
		var sh := Greybox.box(root, "Hoja%d" % i, Vector3(rng.randf_range(-0.5, 0.6), 0.004 + i * 0.002, rng.randf_range(0.35, 1.0)), Vector3(0.21, 0.002, 0.29), PAPEL, false)
		sh.rotation_degrees.y = rng.randf_range(-70.0, 70.0)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var colgada := Greybox.box(root, "HojaColgando", Vector3(0, 0.78, 0.3), Vector3(0.21, 0.29, 0.002), PAPEL, false)
	colgada.rotation_degrees.x = 20.0
	var led := Greybox.box(root, "Led", Vector3(0.22, 1.1, 0.252), Vector3(0.03, 0.02, 0.005), Greybox.AMBAR, false, 2.0)
	var l := Greybox.label(root, "", Vector3(0.1, 1.1, 0.253), 0.03, Greybox.AMBAR)
	l.text = root.tr("Q5_H_ATASCO") if root.is_inside_tree() else TranslationServer.translate("Q5_H_ATASCO")
	l.outline_size = 0
	var b := _LedBlink.new()
	b.name = "Parpadea"
	b.targets = [led, l]
	root.add_child(b)
	return root


class _LedBlink extends Node:
	var targets: Array = []
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		var on := fmod(_t, 1.1) < 0.6
		for n in targets:
			if is_instance_valid(n) and (n as Node3D).visible != on:
				(n as Node3D).visible = on


## Taza de café olvidada con moho verde-gris.
static func moldy_cup(parent: Node, pos: Vector3) -> MeshInstance3D:
	var c := Greybox.cylinder(parent, "TazaMoho", pos + Vector3(0, 0.05, 0), 0.042, 0.1, Greybox.BLANCO, false, 0.4, 0.0, 0.046)
	Greybox.cylinder(c, "Moho", Vector3(0, 0.035, 0), 0.04, 0.012, MOHO, false, 1.0)
	Greybox.cylinder(c, "Pelusa", Vector3(0.01, 0.045, -0.01), 0.022, 0.012, Color(0.6, 0.62, 0.55), false, 1.0)
	Greybox.box(c, "Asa", Vector3(0.052, 0, 0), Vector3(0.012, 0.05, 0.02), Greybox.BLANCO, false)
	return c


## Cartel de papel «FUERA DE SERVICIO» pegado con cinta (en una puerta o cubículo).
static func out_of_order(parent: Node, pos: Vector3, yaw_deg: float) -> MeshInstance3D:
	var p := Greybox.box(parent, "FueraDeServicio", pos, Vector3(0.3, 0.21, 0.003), PAPEL, false)
	p.rotation_degrees = Vector3(0, yaw_deg, -4.0)
	var l := Greybox.label(p, "", Vector3(0, 0.01, 0.003), 0.04, Color(0.6, 0.06, 0.05))
	l.text = parent.tr("Q5_H_FUERA_SERVICIO")
	l.outline_size = 0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 0.27 / l.pixel_size
	Greybox.box(p, "Cinta", Vector3(0, 0.1, 0.002), Vector3(0.12, 0.02, 0.002), Color(0.85, 0.8, 0.6, 0.8), false)
	return p


## Monitor encendido que solo dice «Usuario desconectado» (sin nombres ni pantallas reales).
static func disconnected_monitor(parent: Node, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = "MonitorDesconectado"
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	Greybox.box(root, "Pantalla", Vector3(0, 0, 0), Vector3(0.56, 0.34, 0.03), Color(0.08, 0.12, 0.26), false, 0.9)
	Greybox.box(root, "Pie", Vector3(0, -0.24, -0.02), Vector3(0.06, 0.16, 0.06), Greybox.GRIS_OSCURO, false)
	var l := Greybox.label(root, "", Vector3(0, 0.0, 0.017), 0.035, Color(0.75, 0.82, 0.95))
	l.text = root.tr("Q5_H_DESCONECTADO") if root.is_inside_tree() else TranslationServer.translate("Q5_H_DESCONECTADO")
	l.outline_size = 0
	return root


## Botellón de dispensador con algo oscuro flotando adentro.
static func dark_bottle_thing(bottle_parent: Node, pos: Vector3) -> MeshInstance3D:
	var t := Greybox.box(bottle_parent, "AlgoOscuro", pos, Vector3(0.09, 0.14, 0.07), Color(0.05, 0.04, 0.03, 0.85), false)
	t.rotation_degrees = Vector3(18.0, 30.0, -12.0)
	Greybox.box(t, "Hebras", Vector3(0, -0.09, 0), Vector3(0.03, 0.06, 0.02), Color(0.04, 0.03, 0.02, 0.7), false)
	return t

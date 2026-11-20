class_name TrainingRoom
extends RefCounted
## v0.3.2 · La sala de training principal del piso 1 como era el día del Training (el recuerdo). No toca floor_01.gd:
## sobre el piso ya construido quita las tres filas de mesas de hoy y arma el aula de entonces, en HERRADURA abierta
## hacia la pizarra: tu PC de training «T-01» al fondo de la herradura (la sesión del jugador vive aquí; los dos
## monitores van bajos, como en un aula, y por encima se ve la clase), dos compañeros de promoción a cada lado, de
## perfil y con su cartelito de nombre, el Trainer en el claro del medio y, del lado de las ventanas, la mesa del
## café de bienvenida. El aula está recién pintada: zócalo alto turquesa de KipuPay, alfombra azul al centro, sol
## por las ventanas, banderines, plantas, el rotafolio con la agenda y el reloj de pared clavado en 3:47 (grieta).
## Lo llama Tutorial cada vez que se carga el piso 1 en el Training (después de Flashback.clean_floor).
## La LUZ del aula está toda aquí (LOOK): la calidad Media/Alta (scripts/gfx) puede leer estos mismos valores.

const SEAT := "T-01"
const AXIS_X := 8.6  # eje de la herradura (la pizarra queda centrada-izquierda, las ventanas a la derecha)
const SEAT_POS := Vector3(8.6, 0, -3.35)  # raíz del puesto: monitores en z −3,8, silla en z −2,95, mirando a la pizarra
const EYE := Vector3(8.6, 1.25, -2.95)  # el ojo del jugador sentado (Player.sit_at)
const ENTRY := "training_sala2"  # marcador de floor_01 dentro de la sala, junto a la puerta
const OUTSIDE := "training_fuera"  # marcador nuevo en el pasillo, frente a la puerta (módulo «salir»)
const COFFEE_MARK := "training_cafe"
const DOOR_MARK := "training_entrada"  # donde apareces al llegar: en la puerta, mirando al aula en diagonal
const NAME_CARD := "TarjetaNombre"  # el cartelito con tu nombre en la T-01
const DOOR_POS := Vector3(7.45, 0, -2.0)
const DOOR_YAW := -38.0
## La mesa del café (isla del lado de las ventanas) y dónde te paras a servirte, mirando a las ventanas.
const COFFEE_POS := Vector3(12.3, 0, -5.55)
const COFFEE_STAND := Vector3(12.3, 0, -3.95)
## La promoción (índice = Flashback.classmates()): modelo base, silla, hacia dónde se sienta, sitio en el coffee
## break (alrededor de la isla, de frente a ti) y en la foto (delante de la pizarra). No son los otros agentes.
const CLASS: Array[Dictionary] = [
	{"nombre": "Llauri", "modelo": "agente_llauri", "silla": Vector3(6.5, 0, -5.3), "mira": Vector3(1, 0, -0.3), "cafe": Vector3(11.15, 0, -6.05), "foto": Vector3(7.7, 0, -7.75), "tinte": Color(0.86, 0.42, 0.36)},
	{"nombre": "Marko", "modelo": "agente_marko", "silla": Vector3(10.7, 0, -5.3), "mira": Vector3(-1, 0, -0.3), "cafe": Vector3(13.15, 0, -5.75), "foto": Vector3(9.5, 0, -7.75), "tinte": Color(0.95, 0.62, 0.2)},
	{"nombre": "Ttoom", "modelo": "agente_ttoom", "silla": Vector3(6.5, 0, -6.7), "mira": Vector3(1, 0, -0.3), "cafe": Vector3(11.75, 0, -6.6), "foto": Vector3(7.1, 0, -7.7), "tinte": Color(0.6, 0.5, 0.78)},
	{"nombre": "Juan", "modelo": "agente_juan", "silla": Vector3(10.7, 0, -6.7), "mira": Vector3(-1, 0, -0.3), "cafe": Vector3(12.85, 0, -6.6), "foto": Vector3(10.1, 0, -7.7), "tinte": Color(0.28, 0.55, 0.4)},
]
## Dónde se para el Trainer (local del piso). «pizarra»: escribe o señala la pizarra. «centro»: da la clase en el claro
## de la herradura. «cerca»: delante de tu mesa, te habla a ti. «mesa»: en la esquina de tu mesa, mira tu pantalla.
## «cafe»: detrás de la isla del café, entre Nayra y Yimi. «foto»: su sitio en la foto, a tu lado.
const SPOTS := {
	"pizarra": Vector3(8.2, 0, -7.7), "centro": Vector3(8.6, 0, -6.2), "cerca": Vector3(8.6, 0, -5.15),
	"mesa": Vector3(7.75, 0, -4.6), "cafe": Vector3(12.3, 0, -7.0), "foto": Vector3(8.9, 0, -7.9), "puerta": Vector3(8.1, 0, -3.1),
	"camara": Vector3(8.72, 0, -5.8), "salida": Vector3(6.8, 0, -2.85),
}
## La foto de promoción: todos delante de la pizarra; la cámara (con temporizador) queda sobre tu mesa.
const PHOTO_YOU := Vector3(8.3, 0, -7.7)
const PHOTO_CAM := Vector3(8.6, 1.32, -4.15)
const PHOTO_LOOK := Vector3(8.6, 1.18, -7.75)
const PHOTO_FOV := 46.0
## La luz del aula en el recuerdo (calidad Baja/base, sin sombras). Quien suba la calidad parte de aquí.
const LOOK := {
	"ventana_color": Color(1.0, 0.95, 0.84), "ventana_energia": 1.7, "ventana_alcance": 10.5, "ventana_angulo": 62.0,  # el sol que entra (clave)
	"techo_color": Color(1.0, 0.9, 0.76), "techo_energia": 0.38, "techo_alcance": 5.5,  # relleno cálido del techo
	"lampara_color": Color(1.0, 0.78, 0.52), "lampara_energia": 0.75, "lampara_alcance": 3.2,  # lámpara de pie (acento)
	"pared": Color(0.93, 0.9, 0.84), "zocalo": Color(0.16, 0.5, 0.52), "techo": Color(0.9, 0.89, 0.86),
	"cielo": Color(0.6, 0.78, 0.97), "cielo_emision": 0.8, "sol_piso": Color(1.0, 0.93, 0.74, 0.14),
}
const TEAL := Color(0.16, 0.5, 0.52)
const NARANJA := Color(0.95, 0.56, 0.18)
const ROBLE := Color(0.82, 0.7, 0.52)
const TELA := Color(0.2, 0.45, 0.5)


static func is_ready(floor_node: Node) -> bool:
	return floor_node != null and floor_node.find_child("Cub_" + SEAT, true, false) != null


## Arma la sala sobre el piso 1 ya cargado. Devuelve el Trainer amable (o el que ya estaba).
static func setup(floor_node: Node3D) -> TrainerAmable:
	if floor_node == null:
		return null
	if is_ready(floor_node):
		return floor_node.find_child("TrainerAmable", true, false) as TrainerAmable
	_clear_rows(floor_node)
	_shell(floor_node)
	_pc(floor_node)
	var door := floor_node.find_child("Training1", true, false)
	if door != null and door.get("locked") != null:
		door.set("locked", false)
		door.set("locked_key", "HUD_DOOR")
	var topico := floor_node.find_child("Topico", true, false)
	if topico is Interactable:
		(topico as Interactable).enabled = false  # el cartel de hoy («atención de 8 AM a 8 PM») no existe en el recuerdo
		(topico as Interactable).collision_layer = 0
	Greybox.marker(floor_node, OUTSIDE, Vector3(7.45, 0, 0.6), 180.0)
	Greybox.marker(floor_node, DOOR_MARK, DOOR_POS, DOOR_YAW)
	_lights(floor_node)
	_coffee(floor_node)
	_clock(floor_node)
	_dressing(floor_node)
	_classmates(floor_node)
	var t := TrainerAmable.new()
	t.name = "TrainerAmable"
	floor_node.add_child(t)
	t.setup(floor_node)
	return t


## Las tres filas de mesas, PCs, sillas y asientos de la sala de hoy no existían así: se quitan (con su colisión).
static func _clear_rows(fl: Node3D) -> void:
	for n in fl.get_children():
		var nm := String(n.name)
		if nm.begins_with("MesaTraining") or nm.begins_with("SillaT") or nm.begins_with("CPU") or nm.begins_with("AlumnoT") or (nm.begins_with("PC") and nm.length() <= 6 and nm.contains("_")):
			n.queue_free()
		elif nm.begins_with("Seat_training_sala2_"):
			n.set("enabled", false)
			n.queue_free()
		elif nm.begins_with("NOTE_TRAINING") or nm == "ProyectorHaz1":
			n.queue_free()


## Paredes recién pintadas (sin el desgaste de hoy), zócalo alto turquesa, alfombra azul en el claro y el cielo de día
## detrás de las ventanas con sus manchas de sol en el piso.
static func _shell(fl: Node3D) -> void:
	var wall := Greybox.material(LOOK["pared"], 0.0, 0.92)
	for nm in ["TrainingParedW", "TrainingParedE", "TrainingParedN_A", "TrainingVentanaBajo", "TrainingVentanaAlto", "TrainingParedS", "Machon"]:
		var w := fl.find_child(nm, false, false) as MeshInstance3D
		if w != null:
			w.material_override = wall
	var ceil := fl.find_child("TrainingTecho1", false, false) as MeshInstance3D
	if ceil != null:
		ceil.material_override = Greybox.material(LOOK["techo"], 0.0, 0.95)
	# Zócalo alto (0 a 0,95 m) en las paredes oeste, este y norte (bajo la pizarra y las ventanas) y la pared sur.
	var band := 0.95
	for spec in [[Vector3(6.115, band * 0.5, -4.9), Vector3(0.03, band, 7.0)], [Vector3(13.385, band * 0.5, -4.9), Vector3(0.03, band, 7.0)],
			[Vector3(9.75, band * 0.5, -8.385), Vector3(7.3, band, 0.03)], [Vector3(11.75, band * 0.5, -1.415), Vector3(3.4, band, 0.03)]]:
		var z := Greybox.box(fl, "ZocaloAula", spec[0], spec[1], LOOK["zocalo"], false)
		z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for spec in [[Vector3(6.125, band + 0.02, -4.9), Vector3(0.04, 0.04, 7.0)], [Vector3(13.375, band + 0.02, -4.9), Vector3(0.04, 0.04, 7.0)],
			[Vector3(9.75, band + 0.02, -8.375), Vector3(7.3, 0.04, 0.04)], [Vector3(11.75, band + 0.02, -1.425), Vector3(3.4, 0.04, 0.04)]]:
		Greybox.box(fl, "ZocaloFilete", spec[0], spec[1], Color(0.96, 0.94, 0.9), false)
	# Alfombra azul en el claro de la herradura (define el piso y corta el beige).
	var rug := Greybox.box(fl, "AlfombraAula", Vector3(AXIS_X, 0.012, -5.6), Vector3(3.3, 0.012, 4.6), Color(0.22, 0.4, 0.62), false)
	rug.material_override = Greybox.surf("alfombra_azul", Color(0.9, 0.95, 1.0))
	Greybox.box(fl, "AlfombraBorde", Vector3(AXIS_X, 0.008, -5.6), Vector3(3.42, 0.008, 4.72), Color(0.12, 0.26, 0.36), false)
	# El cielo de la mañana detrás del vidrio (era de noche con lluvia) y la persiana recogida.
	var sky := Greybox.box(fl, "CieloVentana", Vector3(11.85, 1.75, -8.56), Vector3(3.2, 1.7, 0.02), LOOK["cielo"], false, float(LOOK["cielo_emision"]))
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:  # edificios lejanos, apenas un perfil
		Greybox.box(fl, "Skyline%d" % i, Vector3(10.8 + i * 1.05, 1.15 + 0.12 * (i % 2), -8.55), Vector3(0.8, 0.5 + 0.24 * (i % 2), 0.02), Color(0.62, 0.7, 0.78), false, 0.7)
	for i in 3:  # parteluces de la ventana
		Greybox.box(fl, "Parteluz%d" % i, Vector3(10.8 + i * 1.05, 1.75, -8.42), Vector3(0.05, 1.7, 0.05), Color(0.95, 0.94, 0.9), false)
	var glass := fl.find_child("TrainingVentana", false, false) as Node3D
	if glass != null:
		glass.visible = false  # el vidrio con lluvia de la noche
	# Manchas de sol en el piso y sobre la alfombra (dos paños de ventana, sesgados).
	var sunm := StandardMaterial3D.new()
	sunm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sunm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sunm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sunm.albedo_color = LOOK["sol_piso"]
	for i in 3:
		var patch := MeshInstance3D.new()
		patch.name = "SolPiso%d" % i
		var q := QuadMesh.new()
		q.size = Vector2(0.8, 1.9)
		patch.mesh = q
		patch.material_override = sunm
		patch.rotation_degrees = Vector3(-90, 18, 0)
		patch.position = Vector3(10.85 + i * 1.02, 0.03, -7.2)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.add_child(patch)


## La PC de training: un puesto propio (Monitor0/Monitor1 + Seat con la sesión) al fondo de la herradura. Los
## monitores van bajos e inclinados (tope a 1,10 m): sentado ves la clase por encima y la pantalla al bajar la vista.
static func _pc(fl: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Cub_" + SEAT
	root.position = SEAT_POS
	fl.add_child(root)
	_desk(root, Vector3(0, 0, -0.3), Vector3(1.5, 0.05, 0.75))
	for i in 2:
		var mx := -0.31 + 0.62 * i
		var mon := Greybox.box(root, "Monitor%d" % i, Vector3(mx, 0.93, -0.45), Vector3(0.56, 0.34, 0.03), Color(0.1, 0.12, 0.2), false, 0.3)
		mon.rotation_degrees.x = -14.0
		Greybox.box(root, "Pie%d" % i, Vector3(mx, 0.8, -0.49), Vector3(0.07, 0.1, 0.05), Greybox.GRIS_OSCURO, false)
		Greybox.box(root, "Base%d" % i, Vector3(mx, 0.772, -0.47), Vector3(0.24, 0.012, 0.16), Greybox.GRIS_OSCURO, false)
	Greybox.box(root, "Teclado", Vector3(0, 0.775, -0.18), Vector3(0.44, 0.02, 0.14), Greybox.NEGRO, false)
	Greybox.box(root, "Mouse", Vector3(0.34, 0.775, -0.16), Vector3(0.06, 0.025, 0.1), Greybox.NEGRO, false)
	_label(root, "KP-TRAINING · " + SEAT, Vector3(0, 0.71, 0.08), 0.045, Greybox.CIAN)
	_chair(root, Vector3(0, 0, 0.42), 0.0)
	var s := WorldObjects.TrainingSeat.new()
	s.name = "Seat_" + SEAT
	s.seat_id = SEAT
	s.hint_key = "HUD_SIT"
	s.size = Vector3(0.7, 1.2, 0.7)
	s.position = Vector3(0, 0.8, 0.4)
	s.has_session = true
	root.add_child(s)
	for scr in MonitorScreen.attach(root, SEAT):
		scr.rotation_degrees.x = -14.0
	# Tu nombre en un cartelito doblado (lo pone el Trainer cuando se lo dices: TrainingStage, cue «nombre»).
	var tent := Greybox.box(root, NAME_CARD, Vector3(0.58, 0.822, -0.33), Vector3(0.27, 0.1, 0.012), Color(0.98, 0.97, 0.93), false)
	tent.rotation_degrees.y = -18.0
	tent.visible = false
	tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label(tent, GameState.agent.to_upper(), Vector3(0, 0, 0.008), 0.05, Color(0.1, 0.3, 0.34))  # hacia ti
	_label(tent, GameState.agent.to_upper(), Vector3(0, 0, -0.008), 0.05, Color(0.1, 0.3, 0.34), PI)  # hacia la clase
	# El contrato y el lapicero llegan a tu mesa en la firma (TrainingStage los muestra).
	var paper := Greybox.box(root, "ContratoMesa", Vector3(-0.5, 0.772, -0.12), Vector3(0.21, 0.004, 0.3), Color(0.97, 0.95, 0.89), false)
	paper.rotation_degrees.y = 8.0
	paper.visible = false
	Greybox.box(paper, "Lapicero", Vector3(0.14, 0.006, 0.02), Vector3(0.012, 0.012, 0.14), TEAL, false)


## Rótulo del aula. Con prepase opaco (escribe profundidad): un texto de la pared nunca se dibuja encima de la cabeza
## de quien está delante (los Label3D normales van en la pasada transparente y el orden depende de la distancia).
static func _label(parent: Node, text: String, pos: Vector3, size: float, color: Color, rot_y: float = 0.0) -> Label3D:
	var l := Greybox.label(parent, text, pos, size, color, rot_y)
	l.outline_size = 0
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	return l


## Mesa de aula: tablero de roble claro con marco y patas negras (con colisión). `pos` = centro en el piso, local.
static func _desk(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var top := Greybox.box(parent, "Mesa", pos + Vector3(0, 0.745, 0), size, ROBLE)
	top.material_override = Greybox.surf("roble", Color(1.0, 0.97, 0.9))
	Greybox.box(parent, "MesaCanto", pos + Vector3(0, 0.705, 0), Vector3(size.x - 0.04, 0.03, size.z - 0.04), Greybox.NEGRO, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Greybox.box(parent, "Pata", pos + Vector3(sx * (size.x * 0.5 - 0.05), 0.35, sz * (size.z * 0.5 - 0.05)), Vector3(0.04, 0.7, 0.04), Greybox.NEGRO, false)
	Greybox.box(parent, "Faldon", pos + Vector3(0, 0.5, -size.z * 0.5 + 0.02), Vector3(size.x - 0.12, 0.34, 0.015), Color(0.86, 0.84, 0.8), false)


## Silla de aula con tapiz turquesa. `pos` = centro del asiento en el piso (local); mira a −Z girada `yaw`.
static func _chair(parent: Node3D, pos: Vector3, yaw_deg: float) -> Node3D:
	var c := Node3D.new()
	c.name = "Silla"
	c.position = pos
	c.rotation_degrees.y = yaw_deg
	parent.add_child(c)
	Greybox.box(c, "Asiento", Vector3(0, 0.46, 0), Vector3(0.44, 0.06, 0.42), TELA, false)
	Greybox.box(c, "Respaldo", Vector3(0, 0.78, 0.21), Vector3(0.42, 0.44, 0.05), TELA, false)
	Greybox.box(c, "Columna", Vector3(0, 0.22, 0.0), Vector3(0.05, 0.42, 0.05), Greybox.NEGRO, false)
	Greybox.box(c, "Estrella", Vector3(0, 0.03, 0.0), Vector3(0.5, 0.03, 0.08), Greybox.NEGRO, false)
	Greybox.box(c, "Estrella2", Vector3(0, 0.03, 0.0), Vector3(0.08, 0.03, 0.5), Greybox.NEGRO, false)
	Greybox.box(c, "Espiga", Vector3(0, 0.6, 0.215), Vector3(0.06, 0.26, 0.03), Greybox.NEGRO, false)
	return c


## Rotación (rad) para que un nodo que mira a −Z mire hacia `dir`.
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## La luz del aula: el sol de las ventanas como clave (lado derecho), relleno cálido del techo y la lámpara de pie.
static func _lights(fl: Node3D) -> void:
	# El sol entra por las ventanas del fondo: dos focos desde afuera, hacia adentro y hacia abajo. Dan volumen a la
	# gente y a las mesas (un lado claro, otro en media sombra) sin quemar la pared de la ventana.
	for p in [Vector3(11.0, 2.3, -9.4), Vector3(12.7, 2.3, -9.4)]:
		var sun := SpotLight3D.new()
		sun.name = "LuzVentana"
		sun.light_color = LOOK["ventana_color"]
		sun.light_energy = float(LOOK["ventana_energia"])
		sun.spot_range = float(LOOK["ventana_alcance"])
		sun.spot_angle = float(LOOK["ventana_angulo"])
		sun.spot_attenuation = 0.6
		sun.spot_angle_attenuation = 0.7
		sun.shadow_enabled = false
		sun.set_meta("recuerdo", true)
		sun.position = p
		fl.add_child(sun)
		sun.look_at(fl.to_global(Vector3(p.x - 2.2, 0.6, -3.6)), Vector3.UP)
	for p in [Vector3(8.2, 2.3, -3.4), Vector3(7.4, 2.3, -6.4), Vector3(11.9, 2.3, -3.2)]:
		var l := OmniLight3D.new()
		l.name = "LuzCalidaTraining"
		l.light_color = LOOK["techo_color"]
		l.light_energy = float(LOOK["techo_energia"])
		l.omni_range = float(LOOK["techo_alcance"])
		l.shadow_enabled = false
		l.set_meta("recuerdo", true)
		l.position = p
		fl.add_child(l)
	var lamp := Node3D.new()
	lamp.name = "LamparaPie"
	lamp.position = Vector3(6.45, 0, -8.05)
	fl.add_child(lamp)
	Greybox.cylinder(lamp, "Base", Vector3(0, 0.02, 0), 0.16, 0.04, Greybox.NEGRO, false)
	Greybox.cylinder(lamp, "Poste", Vector3(0, 0.8, 0), 0.018, 1.6, Greybox.NEGRO, false)
	var shade := Greybox.cylinder(lamp, "Pantalla", Vector3(0, 1.62, 0), 0.2, 0.26, Color(1.0, 0.9, 0.7), false, 0.9, 0.0, 0.12)
	shade.material_override = Greybox.material(Color(1.0, 0.88, 0.66), 0.9)
	var ll := OmniLight3D.new()
	ll.light_color = LOOK["lampara_color"]
	ll.light_energy = float(LOOK["lampara_energia"])
	ll.omni_range = float(LOOK["lampara_alcance"])
	ll.shadow_enabled = false
	ll.set_meta("recuerdo", true)
	ll.position = Vector3(0, 1.55, 0)
	lamp.add_child(ll)


## Café de bienvenida: una isla del lado de las ventanas con termo, tazas y empanaditas. [E] sobre la mesa: te sirves.
static func _coffee(fl: Node3D) -> void:
	var t := Node3D.new()
	t.name = "CafeBienvenida"
	t.position = COFFEE_POS
	fl.add_child(t)
	Greybox.box(t, "Mesa", Vector3(0, 0.74, 0), Vector3(1.4, 0.05, 0.62), Greybox.MADERA)
	Greybox.box(t, "Mantel", Vector3(0, 0.772, 0), Vector3(1.46, 0.012, 0.68), Color(0.9, 0.87, 0.8), false)
	Greybox.box(t, "MantelCaida", Vector3(0, 0.6, 0.345), Vector3(1.46, 0.34, 0.012), Color(0.9, 0.87, 0.8), false)
	Greybox.box(t, "MantelFranja", Vector3(0, 0.5, 0.352), Vector3(1.46, 0.07, 0.012), TEAL, false)
	for sx in [-1.0, 1.0]:
		Greybox.box(t, "Pata", Vector3(sx * 0.62, 0.36, 0), Vector3(0.05, 0.72, 0.5), Greybox.NEGRO, false)
	Greybox.cylinder(t, "Termo", Vector3(-0.5, 0.95, -0.04), 0.085, 0.34, Color(0.75, 0.12, 0.1), false, 0.4, 0.3)
	Greybox.cylinder(t, "TermoTapa", Vector3(-0.5, 1.14, -0.04), 0.05, 0.05, Greybox.NEGRO, false)
	for i in 6:
		Greybox.cylinder(t, "Taza%d" % i, Vector3(-0.28 + 0.1 * (i % 3), 0.82, 0.04 + 0.11 * (i / 3)), 0.036, 0.085, Color(0.98, 0.97, 0.94), false)
	Greybox.box(t, "Bandeja", Vector3(0.36, 0.785, 0.02), Vector3(0.5, 0.02, 0.36), Greybox.INOX, false)
	for i in 8:
		var e := Greybox.box(t, "Empanada%d" % i, Vector3(0.18 + 0.12 * (i % 4), 0.812, -0.07 + 0.16 * (i / 4)), Vector3(0.1, 0.035, 0.07), Color(0.86, 0.6, 0.27), false)
		e.rotation_degrees.y = 12.0 * ((i % 3) - 1)
	Greybox.box(t, "Servilletas", Vector3(0.0, 0.795, -0.2), Vector3(0.13, 0.04, 0.13), Color(0.98, 0.98, 0.96), false)
	var m := MesaCafe.new()
	m.name = "MesaCafe"
	m.size = Vector3(1.6, 1.1, 0.9)
	m.position = Vector3(0, 0.9, 0)
	t.add_child(m)
	Greybox.marker(fl, COFFEE_MARK, COFFEE_STAND, 0.0)
	# Globos de bienvenida en el rincón de la ventana, atados a la maceta (por encima de las cabezas: no tapan a nadie).
	for i in 3:
		var bx := 0.78 + 0.07 * i
		var by := 1.95 + 0.17 * i
		var col: Color = [TEAL, NARANJA, Color(0.97, 0.95, 0.9)][i]
		var b := MeshInstance3D.new()
		b.name = "Globo%d" % i
		var sph := SphereMesh.new()
		sph.radius = 0.125
		sph.height = 0.3
		sph.radial_segments = 16
		sph.rings = 8
		b.mesh = sph
		b.material_override = Greybox.material(col, 0.0, 0.35)
		b.position = Vector3(bx, by, -2.25 + 0.13 * i)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(b)
		Greybox.box(t, "GloboHilo%d" % i, Vector3(bx, (by - 0.15 + 0.5) * 0.5, -2.25 + 0.13 * i), Vector3(0.004, by - 0.15 - 0.5, 0.004), Color(0.85, 0.85, 0.85), false)


class MesaCafe extends Interactable:
	var toast: bool = false  # el brindis del coffee break (TrainingStage lo pone según el paso)

	func hint_text() -> String:
		return tr("HUD_TRAINING_BRINDIS" if toast else "HUD_TRAINING_CAFE")

	func interact(player: Node) -> bool:
		if toast:
			EventBus.show_message.emit(tr("MSG_TRAINING_BRINDIS"), 2.5)
		else:
			AudioManager.play_sfx("cafe_servir")
			Fatigue.add(-1.0)
			EventBus.show_message.emit(tr("MSG_TRAINING_CAFE"), 2.5)
		interacted.emit(player)
		return true


## Reloj de pared sobre la puerta (mirando a la clase): marca 3:47 toda la clase (grieta).
static func _clock(fl: Node3D) -> void:
	var c := Node3D.new()
	c.name = "RelojTraining"
	c.position = Vector3(9.2, 2.3, -1.38)
	c.rotation_degrees.y = 180.0
	fl.add_child(c)
	Greybox.cylinder(c, "Aro", Vector3.ZERO, 0.185, 0.025, Greybox.NEGRO, false).rotation_degrees.x = 90.0
	Greybox.cylinder(c, "Esfera", Vector3(0, 0, 0.004), 0.17, 0.03, Color(0.97, 0.96, 0.93), false).rotation_degrees.x = 90.0
	_label(c, "3:47", Vector3(0, 0, 0.03), 0.09, Color(0.1, 0.1, 0.12))


## Lo que hace del aula un primer día: el cartel de bienvenida sobre la pizarra, banderines, el rotafolio con la
## agenda, plantas, el dispensador de agua y la pantalla del proyector con la diapositiva de KipuPay.
static func _dressing(fl: Node3D) -> void:
	var tr_ := func(k: String) -> String: return TranslationServer.translate(k)
	# Cartel sobre la pizarra.
	var ban := Greybox.box(fl, "CartelBienvenida", Vector3(8.2, 2.5, -8.36), Vector3(3.3, 0.36, 0.02), TEAL, false)
	_label(ban, tr_.call("TUT_CAFE_SIGN"), Vector3(0, -0.005, 0.014), 0.1, Color(0.98, 0.96, 0.9))
	# La diapositiva en la pizarra (el proyector está encendido de día: se ve pálida).
	var slide := Greybox.box(fl, "Diapositiva", Vector3(8.2, 1.62, -8.325), Vector3(2.3, 1.05, 0.01), Color(0.97, 0.98, 1.0), false, 0.35)
	Greybox.box(slide, "Franja", Vector3(0, 0.44, 0.004), Vector3(2.3, 0.16, 0.004), TEAL, false, 0.5)
	_label(slide, "KipuPay", Vector3(-0.8, 0.44, 0.012), 0.085, Color(1, 1, 1))
	_label(slide, tr_.call("TUT_SLIDE_TITLE"), Vector3(0, 0.12, 0.012), 0.11, Color(0.1, 0.3, 0.34))
	_label(slide, tr_.call("TUT_SLIDE_SUB"), Vector3(0, -0.16, 0.012), 0.06, Color(0.3, 0.36, 0.4))
	var old := fl.find_children("*", "Label3D", false, false)
	for l in old:  # el guion viejo de la pizarra («1. Empatía 2. Proceso…») queda bajo la diapositiva
		if (l as Label3D).text == tr_.call("SIGN_TRAINING_BOARD"):
			(l as Label3D).visible = false
	# Banderines de pared a pared, sobre el claro (turquesa, naranja, crema).
	var cols := [TEAL, NARANJA, Color(0.97, 0.95, 0.9)]
	for i in 15:
		var f := float(i) / 14.0
		var x := lerpf(6.3, 13.2, f)
		var sag := 0.22 * sin(f * PI)
		var flag := MeshInstance3D.new()
		flag.name = "Banderin%d" % i
		var pm := PrismMesh.new()
		pm.size = Vector3(0.26, 0.3, 0.012)
		flag.mesh = pm
		flag.material_override = Greybox.material(cols[i % 3], 0.0, 0.8)
		flag.rotation_degrees.z = 180.0
		flag.position = Vector3(x, 2.5 - sag, -6.9)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.add_child(flag)
	# Rotafolio con la agenda del último día (a la derecha de la pizarra, entre la pizarra y las ventanas).
	var easel := Node3D.new()
	easel.name = "Rotafolio"
	easel.position = Vector3(10.15, 0, -8.05)
	easel.rotation_degrees.y = -14.0
	fl.add_child(easel)
	for sx in [-0.3, 0.3]:
		var leg := Greybox.box(easel, "Pata", Vector3(sx, 0.8, 0.0), Vector3(0.03, 1.6, 0.03), Greybox.NEGRO, false)
		leg.rotation_degrees.z = -6.0 * signf(sx)
	Greybox.box(easel, "Hoja", Vector3(0, 1.3, 0.04), Vector3(0.68, 0.9, 0.02), Color(0.98, 0.97, 0.94), false)
	_label(easel, tr_.call("TUT_AGENDA"), Vector3(0, 1.3, 0.055), 0.042, Color(0.12, 0.2, 0.42))
	# Plantas (maceta + copa) en dos esquinas y junto a la puerta.
	for p in [Vector3(13.0, 0, -7.95), Vector3(6.45, 0, -1.85), Vector3(13.0, 0, -1.85)]:
		var plant := Node3D.new()
		plant.name = "PlantaAula"
		plant.position = p
		fl.add_child(plant)
		Greybox.cylinder(plant, "Maceta", Vector3(0, 0.22, 0), 0.17, 0.44, Color(0.93, 0.92, 0.88), false, 0.6, 0.0, 0.21)
		for k in 5:
			var leaf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2 - 0.02 * k
			sm.height = 0.5 - 0.04 * k
			sm.radial_segments = 10
			sm.rings = 5
			leaf.mesh = sm
			leaf.material_override = Greybox.material(Color(0.2 + 0.04 * (k % 2), 0.5 + 0.05 * (k % 3), 0.26), 0.0, 0.8)
			leaf.position = Vector3(0.11 * cos(k * 1.9), 0.62 + 0.14 * k, 0.11 * sin(k * 1.9))
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plant.add_child(leaf)
	# Dispensador de agua junto a la puerta (lado del pasillo libre).
	var disp := Node3D.new()
	disp.name = "DispensadorAula"
	disp.position = Vector3(10.6, 0, -1.72)
	fl.add_child(disp)
	Greybox.box(disp, "Cuerpo", Vector3(0, 0.5, 0), Vector3(0.32, 1.0, 0.32), Color(0.95, 0.95, 0.94), false)
	Greybox.cylinder(disp, "Bidon", Vector3(0, 1.22, 0), 0.13, 0.42, Color(0.55, 0.78, 0.92, 0.75), false, 0.2)
	# Afiches de KipuPay en la pared oeste (los valores de la familia).
	for i in 2:
		var po := Greybox.box(fl, "AficheKipu%d" % i, Vector3(6.125, 1.75, -4.6 - 1.9 * i), Vector3(0.012, 0.8, 0.58), [NARANJA, TEAL][i], false)
		var pl := _label(po, tr_.call("TUT_POSTER_%d" % (i + 1)), Vector3(0.01, 0, 0), 0.05, Color(0.99, 0.97, 0.92), PI * 0.5)
		pl.width = 520.0
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Compañeros de promoción: recién contratados contentos, sentados a los lados de la herradura, de perfil a ti y
## girados hacia la pizarra, cada uno con su mesa, su monitor bajo y su cartelito con el nombre.
static func _classmates(fl: Node3D) -> void:
	for i in CLASS.size():
		var c: Dictionary = CLASS[i]
		var st := Node3D.new()  # el puesto: silla, mesa, monitor y cartel (no se mueve)
		st.name = "PuestoPromocion%d" % i
		st.position = c["silla"]
		st.rotation.y = yaw_to(c["mira"])
		fl.add_child(st)
		_chair(st, Vector3.ZERO, 0.0)
		_desk(st, Vector3(0, 0, -0.78), Vector3(1.1, 0.05, 0.6))
		var mon := Greybox.box(st, "MonitorP", Vector3(0, 0.93, -0.92), Vector3(0.5, 0.31, 0.03), Color(0.1, 0.12, 0.2), false)
		mon.rotation_degrees.x = -14.0
		var scr := Greybox.box(mon, "PantallaP", Vector3(0, 0, 0.017), Vector3(0.46, 0.27, 0.004), Color(0.2, 0.42, 0.55), false, 0.6)
		scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Greybox.box(st, "PieP", Vector3(0, 0.8, -0.96), Vector3(0.07, 0.1, 0.05), Greybox.GRIS_OSCURO, false)
		Greybox.box(st, "TecladoP", Vector3(0, 0.775, -0.66), Vector3(0.4, 0.02, 0.13), Greybox.NEGRO, false)
		var paper := Greybox.box(st, "ContratoMesa", Vector3(0.02, 0.772, -0.56), Vector3(0.21, 0.004, 0.3), Color(0.97, 0.95, 0.89), false)
		paper.rotation_degrees.y = -6.0
		paper.visible = false
		# Cartelito con el nombre, del lado del claro (lo lees desde tu sitio).
		var side := 1.0 if (c["mira"] as Vector3).x > 0.0 else -1.0  # hacia el sur (tú) según el lado
		var tent := Greybox.box(st, "CartelNombre", Vector3(-0.42 * side, 0.82, -0.98), Vector3(0.26, 0.1, 0.012), Color(0.98, 0.97, 0.93), false)
		tent.rotation_degrees.y = -60.0 * side
		_label(tent, str(c["nombre"]).to_upper(), Vector3(0, 0, 0.008), 0.05, Color(0.1, 0.3, 0.34))
		var holder := PromoActor.new()
		holder.name = "Promocion%d" % i
		holder.who = str(c["nombre"])
		holder.index = i
		holder.model = str(c["modelo"])
		holder.tint = c["tinte"]
		holder.seat_pos = c["silla"]
		holder.seat_face = c["mira"]
		holder.position = c["silla"]
		holder.rotation.y = yaw_to(c["mira"])
		fl.add_child(holder)

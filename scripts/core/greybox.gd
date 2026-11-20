class_name Greybox
extends RefCounted
## Ayudas para construir greybox con primitivas (BoxMesh + colisión). Sin modelos importados.

# Paleta nocturna del GDD 8.2 (un solo rojo en todo el juego: ROJO).
const GRIS := Color(0.22, 0.23, 0.24)
const GRIS_OSCURO := Color(0.09, 0.09, 0.10)
const BEIGE := Color(0.55, 0.50, 0.42)
const ALFOMBRA := Color(0.28, 0.29, 0.30)
const CIAN := Color(0.16, 0.42, 0.42)
const MADERA := Color(0.45, 0.33, 0.20)
const BLANCO := Color(0.80, 0.82, 0.84)
const AMBAR := Color(0.95, 0.65, 0.25)
const ROJO := Color(0.85, 0.08, 0.08)
const VIDRIO := Color(0.5, 0.7, 0.75, 0.25)
const CONCRETO := Color(0.42, 0.42, 0.40)
const VERDE_AGUA := Color(0.35, 0.62, 0.58)
const GRANITO := Color(0.58, 0.52, 0.42)
const CERAMICA := Color(0.86, 0.88, 0.88)
const COBRE := Color(0.38, 0.24, 0.14)
const INOX := Color(0.6, 0.62, 0.64)
const NEGRO := Color(0.03, 0.03, 0.035)
const TECHO_INDUSTRIAL := Color(0.05, 0.055, 0.06)

static var _materials: Dictionary = {}

# --- v0.3.1 Q5: materiales del mundo con textura (procedurales, tools/q5_texturas.py) ----------------------------
## Paleta del site (ref_site_v2/PALETA.md) para lo que va sin textura.
const PORCELANATO_NEGRO := Color(0.094, 0.098, 0.106)
const MARMOL := Color(0.788, 0.776, 0.753)
const AZUL_P1 := Color(0.184, 0.384, 0.565)
const AZUL_MARINO := Color(0.137, 0.251, 0.369)
const TURQUESA := Color(0.290, 0.667, 0.776)
const TEAL := Color(0.184, 0.435, 0.518)
const MENTA := Color(0.525, 0.761, 0.678)
const CREMA := Color(0.812, 0.773, 0.702)
const CREMA_P2 := Color(0.839, 0.812, 0.765)
const BLANCO_PARED := Color(0.851, 0.847, 0.831)
const TECHO_BALDOSA := Color(0.902, 0.894, 0.875)
const PUERTA_BLANCA := Color(0.886, 0.863, 0.812)
const CORTAFUEGO := Color(0.435, 0.424, 0.400)
const ZOCALO := Color(0.078, 0.078, 0.078)
const ROJO_SEGURIDAD := Color(0.478, 0.110, 0.110)  # rojo apagado de la seguridad (GDD 8.2: no compite con métricas)
const MARCO_NEGRO := Color(0.102, 0.102, 0.102)
const INOX_PULIDO := Color(0.722, 0.733, 0.745)
const ALUMINIO := Color(0.788, 0.800, 0.808)
const ROBLE := Color(0.788, 0.698, 0.557)
const AMARILLO_FRANJA := Color(0.851, 0.659, 0.110)
const VERDE_SALIDA := Color(0.184, 0.878, 0.478)
const VERDE_LED := Color(0.224, 0.827, 0.325)
## Superficies con textura: archivo (assets/textures/mundo), tamaño de mundo que cubre (m), color medio (para el
## Modo liviano, sin textura), rugosidad, metálico.
const SURF: Dictionary = {
	"porcelanato_negro": ["porcelanato_negro", 1.2, Color(0.115, 0.118, 0.13), 0.1, 0.05],
	"marmol": ["marmol", 1.2, Color(0.76, 0.75, 0.73), 0.25, 0.0],
	"baldosa_techo": ["baldosa_techo", 1.2, Color(0.88, 0.87, 0.85), 0.95, 0.0],
	"reticula": ["reticula", 0.6, Color(0.11, 0.11, 0.118), 0.9, 0.0],
	"vinilico_calido": ["vinilico_calido", 1.2, Color(0.47, 0.40, 0.31), 0.5, 0.0],
	"vinilico_claro": ["vinilico_claro", 1.2, Color(0.74, 0.66, 0.57), 0.5, 0.0],
	"vinilico_pasillo": ["vinilico_pasillo", 1.2, Color(0.63, 0.56, 0.47), 0.5, 0.0],
	"ceramica_blanca": ["ceramica_blanca", 1.2, Color(0.86, 0.86, 0.84), 0.2, 0.0],
	"porcelanato_gris": ["porcelanato_gris", 1.2, Color(0.6, 0.6, 0.59), 0.35, 0.0],
	"granito": ["granito", 0.8, Color(0.7, 0.62, 0.52), 0.3, 0.0],
	"concreto": ["concreto", 1.2, Color(0.66, 0.66, 0.67), 0.9, 0.0],
	"vereda": ["vereda", 2.4, Color(0.58, 0.55, 0.5), 0.75, 0.0],
	"alfombra_azul": ["alfombra_azul", 0.6, Color(0.25, 0.44, 0.73), 0.9, 0.0],
	"ladrillo_blanco": ["ladrillo_blanco", 1.2, Color(0.8, 0.79, 0.76), 0.85, 0.0],
	"sala_gris": ["sala_gris", 1.2, Color(0.70, 0.70, 0.69), 0.55, 0.0],
	"roble": ["roble", 0.8, Color(0.76, 0.67, 0.53), 0.55, 0.0],
	"pared": ["pared_desgaste", 2.0, Color(0.95, 0.95, 0.95), 0.9, 0.0],
	"persiana": ["persiana", 0.5, Color(0.9, 0.9, 0.88), 0.9, 0.0],
	"felpudo": ["felpudo", 0.6, Color(0.37, 0.35, 0.34), 1.0, 0.0],
	"concreto_escalera": ["concreto_escalera", 1.2, Color(0.42, 0.39, 0.34), 0.9, 0.0],
}
static var _surf: Dictionary = {}  # clave -> StandardMaterial3D
static var _flat: bool = false


## Material de superficie con textura triplanar en coordenadas de mundo (se repite sin costura en cualquier caja).
## tint multiplica el color (pared crema, pared blanca…). En Modo liviano sale plano (sin textura).
static func surf(kind: String, tint: Color = Color(1, 1, 1), rough: float = -1.0) -> StandardMaterial3D:
	var key := "%s_%s_%0.2f" % [kind, tint.to_html(), rough]
	if _surf.has(key):
		return _surf[key]
	var cfg: Array = SURF.get(kind, SURF["pared"])
	var m := StandardMaterial3D.new()
	m.roughness = float(cfg[3]) if rough < 0.0 else rough
	m.metallic = float(cfg[4])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var sc := 1.0 / float(cfg[1])
	m.uv1_scale = Vector3(sc, sc, sc)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var path := "res://assets/textures/mundo/%s.png" % str(cfg[0])
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	m.set_meta("q5_tex", tex)
	m.set_meta("q5_tint", tint)
	m.set_meta("q5_avg", cfg[2])
	_surf[key] = m
	_flatten(m, _flat)
	return m


static func _flatten(m: StandardMaterial3D, on: bool) -> void:
	var tex: Texture2D = m.get_meta("q5_tex", null)
	var tint: Color = m.get_meta("q5_tint", Color(1, 1, 1))
	var avg: Color = m.get_meta("q5_avg", Color(0.5, 0.5, 0.5))
	var alpha := bool(m.get_meta("q5_alpha", false))
	if on or tex == null:
		m.albedo_texture = null
		m.uv1_triplanar = false
		m.albedo_color = Color(avg.r * tint.r, avg.g * tint.g, avg.b * tint.b, 1.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	else:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.albedo_color = Color(tint.r, tint.g, tint.b, 1.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if alpha else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.alpha_scissor_threshold = 0.5


## Modo liviano (GfxQuality): todos los materiales de superficie pasan a color plano (y vuelven).
static func set_flat_materials(on: bool) -> void:
	if _flat == on:
		return
	_flat = on
	for k in _surf.keys():
		_flatten(_surf[k] as StandardMaterial3D, on)


## Acero inoxidable cepillado. Sin sondas de reflexión un metálico alto sale negro: metálico medio y albedo claro.
static func inox() -> StandardMaterial3D:
	return material(Color(0.78, 0.79, 0.8), 0.0, 0.32, 0.45)


## Caja con material de superficie (ver surf()).
static func sbox(parent: Node, p_name: String, pos: Vector3, size: Vector3, kind: String, collide: bool = true, tint: Color = Color(1, 1, 1)) -> MeshInstance3D:
	var mi := box(parent, p_name, pos, size, Color(1, 1, 1), collide)
	mi.material_override = surf(kind, tint)
	return mi


## Losa de suelo con superficie (como floor_slab).
static func sfloor(parent: Node, p_name: String, center: Vector2, size: Vector2, kind: String, tint: Color = Color(1, 1, 1)) -> MeshInstance3D:
	return sbox(parent, p_name, Vector3(center.x, -0.05, center.y), Vector3(size.x, 0.1, size.y), kind, true, tint)


## Techo de baldosa 60×60 (o retícula) a altura h, sin colisión.
static func sceiling(parent: Node, p_name: String, center: Vector2, size: Vector2, h: float, kind: String = "baldosa_techo", tint: Color = Color(1, 1, 1)) -> MeshInstance3D:
	return sbox(parent, p_name, Vector3(center.x, h + 0.05, center.y), Vector3(size.x, 0.1, size.y), kind, false, tint)


## Pared con superficie y zócalo negro de 10 cm en las dos caras (pos = centro, size en ejes del mundo).
static func swall(parent: Node, p_name: String, pos: Vector3, size: Vector3, kind: String = "pared", tint: Color = Color(1, 1, 1), skirting: bool = true) -> MeshInstance3D:
	var w := sbox(parent, p_name, pos, size, kind, true, tint)
	if skirting:
		var along_x := size.x >= size.z
		var zs := Vector3(size.x + 0.002, 0.1, size.z + 0.024) if along_x else Vector3(size.x + 0.024, 0.1, size.z + 0.002)
		var z := box(w, "Zocalo", Vector3(0, -size.y * 0.5 + 0.05, 0), zs, ZOCALO, false)
		z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return w


## Downlight LED redondo empotrado (disco emisivo + luz opcional).
static func downlight(parent: Node, p_name: String, pos: Vector3, color: Color = Color(1.0, 0.92, 0.84), energy: float = 0.9, range_m: float = 5.5, with_light: bool = true) -> MeshInstance3D:
	var d := cylinder(parent, p_name, pos, 0.09, 0.02, color)
	d.material_override = material(Color(1.0, 0.96, 0.9), 3.0)
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if with_light:
		light(d, Vector3(0, -0.2, 0), color, energy, range_m)
	return d


## Cartel "SALIDA" verde (fotoluminiscente) con flecha; arrow: -1 izquierda, 0 sin flecha, 1 derecha.
static func exit_sign(parent: Node, p_name: String, pos: Vector3, rot_y_deg: float, arrow: int = 0, hanging: bool = false) -> MeshInstance3D:
	var s := box(parent, p_name, pos, Vector3(0.42, 0.16, 0.03), Color(0.06, 0.32, 0.16), false, 1.2)
	s.rotation_degrees.y = rot_y_deg
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var txt := ("← " if arrow < 0 else "") + "SALIDA" + (" →" if arrow > 0 else "")
	var l := label(s, txt, Vector3(0, 0, 0.017), 0.1, Color(0.85, 1.0, 0.9))
	l.outline_size = 0
	if hanging:
		for cx in [-0.15, 0.15]:
			box(s, "Cable%d" % int(cx * 10), Vector3(cx, 0.22, 0), Vector3(0.008, 0.3, 0.008), NEGRO, false)
	return s


## Extintor sobre base roja (rojo apagado de seguridad) con número de inventario.
static func extinguisher(parent: Node, p_name: String, pos: Vector3, number: int = 17, cart: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = p_name
	root.position = pos
	parent.add_child(root)
	box(root, "Base", Vector3(0, 0.06, 0), Vector3(0.3, 0.12, 0.3), ROJO_SEGURIDAD, false)
	var body := cylinder(root, "Cuerpo", Vector3(0, 0.45, 0), 0.08, 0.62, ROJO_SEGURIDAD, false, 0.4, 0.1)
	cylinder(root, "Valvula", Vector3(0, 0.82, 0), 0.025, 0.1, INOX, false, 0.3, 0.9)
	var n := label(body, str(number), Vector3(0, 0.05, 0.082), 0.07, Color(0.92, 0.9, 0.85))
	n.name = "Numero"
	n.outline_size = 0
	if cart:
		box(root, "Carrito", Vector3(0, 0.5, -0.12), Vector3(0.28, 0.9, 0.04), ROJO_SEGURIDAD, false)
	return root


## Papelera cilíndrica de acero inox.
static func bin(parent: Node, p_name: String, pos: Vector3, tall: bool = false) -> MeshInstance3D:
	var h := 0.75 if tall else 0.55
	var b := cylinder(parent, p_name, pos + Vector3(0, h * 0.5, 0), 0.16, h, INOX_PULIDO, true, 0.3, 0.45)
	cylinder(b, "Boca", Vector3(0, h * 0.5 + 0.005, 0), 0.15, 0.01, NEGRO)
	return b


static func material(color: Color, emissive: float = 0.0, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%0.2f_%0.2f_%0.2f" % [color.to_html(), emissive, roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_materials[key] = m
	return m


## Caja con malla y, opcionalmente, colisión estática. pos = centro.
static func box(parent: Node, p_name: String, pos: Vector3, size: Vector3, color: Color, collide: bool = true, emissive: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = mesh
	mi.material_override = material(color, emissive)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = "Col"
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		mi.add_child(body)
	return mi


## Colisionador invisible (límite, losa de seguridad, parapeto). pos = centro.
static func invisible_box(parent: Node, p_name: String, pos: Vector3, size: Vector3, group: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = p_name
	body.position = pos
	if group != "":
		body.add_to_group(group)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## Cilindro (columna, ducto, mesa redonda, baranda). Eje Y; para ductos horizontales se rota.
static func cylinder(parent: Node, p_name: String, pos: Vector3, radius: float, height: float, color: Color, collide: bool = false, roughness: float = 0.9, metallic: float = 0.0, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = mesh
	mi.material_override = material(color, 0.0, roughness, metallic)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = "Col"
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = radius
		cs.height = height
		shape.shape = cs
		body.add_child(shape)
		mi.add_child(body)
	return mi


## Ducto horizontal de techo (eje X o Z) a altura y.
static func duct(parent: Node, p_name: String, center: Vector3, length: float, radius: float, along_x: bool, color: Color = Color(0.3, 0.31, 0.32)) -> MeshInstance3D:
	var d := cylinder(parent, p_name, center, radius, length, color, false, 0.6, 0.5)
	d.rotation_degrees = Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
	return d


## Lámpara colgante tipo campana (cafetería / azotea) con luz cálida.
static func pendant_lamp(parent: Node, p_name: String, pos: Vector3, color: Color = AMBAR, energy: float = 1.0) -> MeshInstance3D:
	var cable := cylinder(parent, p_name + "_cable", pos + Vector3(0, 0.45, 0), 0.01, 0.9, NEGRO)
	var shade := cylinder(parent, p_name, pos, 0.22, 0.25, NEGRO, false, 0.4, 0.3, 0.06)
	light(shade, Vector3(0, -0.25, 0), color, energy, 5.0)
	var bulb := cylinder(shade, "Foco", Vector3(0, -0.08, 0), 0.04, 0.06, color)
	bulb.material_override = material(color, 2.5)
	cable.visible = true
	return shade


## Suelo: losa fina centrada en (center.x, 0, center.z).
static func floor_slab(parent: Node, p_name: String, center: Vector2, size: Vector2, color: Color) -> MeshInstance3D:
	return box(parent, p_name, Vector3(center.x, -0.05, center.y), Vector3(size.x, 0.1, size.y), color)


## Techo a altura h (por defecto techo industrial abierto, casi negro).
static func ceiling(parent: Node, p_name: String, center: Vector2, size: Vector2, h: float, color: Color = TECHO_INDUSTRIAL) -> MeshInstance3D:
	return box(parent, p_name, Vector3(center.x, h + 0.05, center.y), Vector3(size.x, 0.1, size.y), color, false)


## Pared entre dos puntos en planta (a → b), altura h, grosor t.
static func wall(parent: Node, p_name: String, a: Vector2, b: Vector2, h: float, color: Color = GRIS, t: float = 0.2) -> MeshInstance3D:
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var mi := box(parent, p_name, Vector3(mid.x, h * 0.5, mid.y), Vector3(len, h, t), color)
	mi.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	return mi


## Cuatro paredes de un rectángulo (sin aberturas); skip = lista de lados a omitir: "n","s","e","w".
static func room_walls(parent: Node, p_name: String, center: Vector2, size: Vector2, h: float, color: Color = GRIS, skip: Array = []) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var c := center
	if not skip.has("n"):
		wall(parent, p_name + "_N", Vector2(c.x - hx, c.y - hz), Vector2(c.x + hx, c.y - hz), h, color)
	if not skip.has("s"):
		wall(parent, p_name + "_S", Vector2(c.x - hx, c.y + hz), Vector2(c.x + hx, c.y + hz), h, color)
	if not skip.has("w"):
		wall(parent, p_name + "_W", Vector2(c.x - hx, c.y - hz), Vector2(c.x - hx, c.y + hz), h, color)
	if not skip.has("e"):
		wall(parent, p_name + "_E", Vector2(c.x + hx, c.y - hz), Vector2(c.x + hx, c.y + hz), h, color)


## Texto flotante (letrero, placa). v0.3 P6b: los Label3D de doble cara mostraban el texto AL REVÉS desde atrás
## ("soñaB" desde dentro del baño). Ahora son de una cara: por detrás no se ven (casi todos van contra una pared,
## un panel o una puerta). Un cartel suelto que se lee de los dos lados lleva Greybox.two_sided(label): un reverso
## (MirrorLabel, hijo "Reverso", girado 180°) que copia texto, color y tamaño.
static func label(parent: Node, text: String, pos: Vector3, size: float = 0.35, color: Color = BLANCO, rot_y: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation.y = rot_y
	l.pixel_size = 0.01 * size / 0.35
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.double_sided = false
	parent.add_child(l)
	return l


## Cartel suelto que se lee bien de los dos lados (el reverso sigue los cambios de texto y color).
static func two_sided(l: Label3D) -> Label3D:
	if l.get_node_or_null("Reverso") != null:
		return l
	var back := MirrorLabel.new()
	back.name = "Reverso"
	back.src = l
	back.rotation.y = PI
	back.position = Vector3(0, 0, -0.004)
	back.double_sided = false
	back.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	back.sync()
	l.add_child(back)
	l.double_sided = false
	return l


## Deja el cartel con una sola cara legible (sin reverso): por detrás no se ve.
static func one_sided(l: Label3D) -> Label3D:
	var back := l.get_node_or_null("Reverso")
	if back != null:
		l.remove_child(back)
		back.queue_free()
	l.double_sided = false
	return l


## Reverso de un Label3D: copia lo que se ve de su cara (texto, color, tamaño, fuente) cuando cambia.
class MirrorLabel extends Label3D:
	var src: Label3D = null

	func _ready() -> void:
		set_meta("reverso", true)

	func _process(_d: float) -> void:
		if src == null or not is_instance_valid(src):
			return
		# Comparación directa (barata: hay cientos de carteles).
		if src.text != text or src.modulate != modulate or src.pixel_size != pixel_size or src.font_size != font_size or src.outline_size != outline_size:
			sync()

	func sync() -> void:
		if src == null:
			return
		text = src.text
		modulate = src.modulate
		pixel_size = src.pixel_size
		font_size = src.font_size
		outline_size = src.outline_size
		outline_modulate = src.outline_modulate
		font = src.font
		horizontal_alignment = src.horizontal_alignment
		vertical_alignment = src.vertical_alignment
		width = src.width
		autowrap_mode = src.autowrap_mode
		no_depth_test = src.no_depth_test


## Luz puntual (fluorescente, aplique).
static func light(parent: Node, pos: Vector3, color: Color = Color(0.75, 0.9, 0.9), energy: float = 1.2, range_m: float = 8.0, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.set_meta("shadow_design", shadow)
	l.shadow_enabled = shadow and GfxQuality.shadows_allowed()
	parent.add_child(l)
	return l


## Panel fluorescente de techo (caja emisiva + luz); flicker añade parpadeo aleatorio.
static func light_panel(parent: Node, p_name: String, pos: Vector3, shadow: bool = false, flicker: bool = false) -> MeshInstance3D:
	var mi := box(parent, p_name, pos, Vector3(1.2, 0.05, 0.3), Color(0.8, 0.95, 0.95), false, 2.0)
	box(mi, "Borde", Vector3(0, 0.02, 0), Vector3(1.3, 0.04, 0.4), GRIS_OSCURO, false)
	light(mi, Vector3(0, -0.5, 0), Color(0.75, 0.9, 0.9), 1.0, 7.0, shadow)
	if flicker:
		FlickerLight.attach(mi)
	return mi


## Marcador de posición (spawn) con nombre.
static func marker(parent: Node, p_name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = p_name
	m.position = pos
	m.rotation_degrees.y = rot_y_deg
	parent.add_child(m)
	return m


## Puesto de bench (v0.3.1 Q5, site P2): tablero de roble claro con marco de acero negro, divisor bajo de tela gris
## (1,1 m: sigue cortando el paso como el panel de antes), monitores negros y silla de malla negra con ruedas. Mismos
## nombres de nodos que el cubículo v0.3 (Panel, Escritorio, Monitor%d, Pie%d, Silla, Respaldo) y mismo hueco.
static func cubicle(parent: Node, id: String, pos: Vector3, facing_deg: float = 0.0, monitors: int = 1) -> Node3D:
	var root := Node3D.new()
	root.name = "Cub_" + id
	root.position = pos
	root.rotation_degrees.y = facing_deg
	parent.add_child(root)
	var panel := box(root, "Panel", Vector3(0, 0.55, -0.6), Vector3(1.5, 1.1, 0.05), Color(0.427, 0.439, 0.451))
	panel.material_override = material(Color(0.40, 0.41, 0.42), 0.0, 1.0)
	var top := box(root, "Escritorio", Vector3(0, 0.735, -0.3), Vector3(1.5, 0.03, 0.6), ROBLE)
	top.material_override = surf("roble")
	var frame := material(Color(0.082, 0.082, 0.082), 0.0, 0.5, 0.6)
	for sx in [-0.72, 0.72]:
		var leg := box(root, "Moldura%d" % int(sx * 10), Vector3(sx, 0.36, -0.3), Vector3(0.04, 0.72, 0.56), Color(0.08, 0.08, 0.08), false)
		leg.material_override = frame
	for i in monitors:
		var mx := -0.31 + 0.62 * i if monitors > 1 else 0.0
		box(root, "Monitor%d" % i, Vector3(mx, 1.12, -0.45), Vector3(0.56, 0.34, 0.03), Color(0.1, 0.12, 0.2), false, 0.3)
		box(root, "Pie%d" % i, Vector3(mx, 0.84, -0.47), Vector3(0.06, 0.2, 0.06), GRIS_OSCURO, false)
	var malla := material(Color(0.106, 0.110, 0.118), 0.0, 0.8)
	box(root, "Silla", Vector3(0, 0.47, 0.4), Vector3(0.48, 0.06, 0.46), GRIS_OSCURO, false).material_override = malla
	box(root, "Respaldo", Vector3(0, 0.8, 0.62), Vector3(0.44, 0.55, 0.04), GRIS_OSCURO, false).material_override = malla
	var piston := cylinder(root, "Base", Vector3(0, 0.22, 0.4), 0.025, 0.42, NEGRO, false, 0.6, 0.2)  # pistón y estrella de ruedas
	cylinder(piston, "Estrella", Vector3(0, -0.19, 0), 0.26, 0.03, NEGRO, false, 0.6, 0.2)
	label(root, id, Vector3(0, 1.13, -0.57), 0.075)  # placa chica sobre el divisor
	return root

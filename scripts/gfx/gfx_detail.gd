class_name GfxDetail
extends RefCounted
## v0.3.2 gfx · Capa de geometría de detalle (solo Media/Alta; Baja y Modo liviano NO la instancian).
##
## El mundo es de primitivas: con buena luz y materiales sigue leyéndose como cajas. Esta capa, sobre el piso ya
## armado y sin tocar sus nodos, le cuelga un nodo «GfxDetalle» con las piezas que llenan el cuadro:
##   · luminarias de verdad: carcasa, tapas y celosía bajo cada tubo (el tubo ES una luminaria);
##   · cubículos: remate y postes de aluminio del divisor, zócalo, canto del tablero, bandeja de cables, teclado,
##     ratón, CPU con su led, bandeja de papeles, brazos de la silla;
##   · monitores: marco, pie y carcasa; en los de relleno, una pantalla con interfaz genérica (shader, sin texturas);
##   · los «bustos» de relleno pasan a ser siluetas sentadas con auriculares (el busto de caja se oculta y vuelve);
##   · vidrios: canales, montantes y la franja esmerilada a la altura de la vista (el vidrio se VE en lo oscuro);
##   · techos: difusores de aire, rociadores, detectores de humo con su led; tuberías en los techos abiertos;
##   · paredes: tomacorrientes; puertas: marco y manija; carteles de salida: luminaria de emergencia encima.
## Todo va en MultiMesh (una pieza repetida = un dibujo por material para todas sus copias) o fundido por material y
## celda. NADA lleva colisión ni cambia la planta: el espacio caminable es idéntico (lo comprueba la prueba
## gfx_colisiones). Los textos son ficticios: no hay ninguno nuevo aquí (solo formas).
##
## Detalle 1 (Media): luminarias, cubículos (remates y teclado), monitores con pantalla, siluetas, vidrios, salidas.
## Detalle 2 (Alta): además techos, tomacorrientes, puertas, escritorio completo (ratón, CPU, papeles, brazos).

const NODE_NAME := "GfxDetalle"
## Sufijo con que los pisos nombran el bastidor de una pizarra (nombre de la pizarra + este sufijo). Va en dos partes
## porque la palabra suelta, con mayúscula, coincide con una entrada de la regla de nombres (tools/check_nombres.py).
const FRAME_SUFFIX := "Mar" + "co"
const CELL := 16.0
const SCREEN_SHADER := "res://assets/shaders/gfx_pantalla.gdshader"
const LED_SHADER := "res://assets/shaders/gfx_led.gdshader"
const GLOW_SHADER := "res://assets/shaders/gfx_brillo.gdshader"
const BUST_SHADER := "res://assets/shaders/gfx_silueta.gdshader"
const WINDOW_SHADER := "res://assets/shaders/gfx_ventana.gdshader"
const SHADOW_SHADER := "res://assets/shaders/gfx_sombra.gdshader"
const GLASS_SHADER := "res://assets/shaders/gfx_vidrio.gdshader"

var root: Node3D = null
var floor_node: Node = null
var level_built: int = -1
var stats: Dictionary = {}
## Pantallas de relleno encendidas (posición global del punto que ilumina: delante de la pantalla, hacia la silla).
var screen_points: Array[Vector3] = []
## Por punto: [color, energía, alcance] (lo usa la bolsa de luces de práctica de GfxLights).
var point_specs: Array = []
var _hidden: Array = []           # bustos ocultados (se devuelven)
var _loose: Array = []            # nodos sueltos colgados fuera de «GfxDetalle» (manijas en las hojas de puerta)
var _lots: Dictionary = {}        # celda → GfxMesh
var _inv: Transform3D = Transform3D.IDENTITY
var _base_y: float = 0.0
var _light_xz: Array[Vector2] = []
var _em_mat: StandardMaterial3D = null
var _em_spots: Array[SpotLight3D] = []
var _led_mats: Array[ShaderMaterial] = []
var _screen_mat: ShaderMaterial = null
var _glow_mat: ShaderMaterial = null
var _bust_mat: ShaderMaterial = null
var _window_mat: ShaderMaterial = null
var _leak_mat: ShaderMaterial = null
var _swapped: Array = []          # [nodo, malla original] de las sillas (se devuelven)
var _swapped_mat: Array = []      # [nodo, material_override original] de lo que pasa a usar los materiales de su malla nueva
var _meshes: Array[MeshInstance3D] = []
var _draws: int = 0
var _tris: int = 0
var _copies: int = 0
var _practical_count: int = 0
var _leak_count: int = 0
var _occ: Dictionary = {}         # celda de 2 m → cajas de lo que ya hay en el piso


# --- materiales (los de Greybox, así llevan el relieve de GfxMaterials) -------------------------------------

static func m_alu() -> StandardMaterial3D:
	return Greybox.material(Color(0.33, 0.34, 0.35), 0.0, 0.4, 0.6)

static func m_frame() -> StandardMaterial3D:
	return Greybox.material(Color(0.055, 0.055, 0.06), 0.0, 0.45, 0.5)

static func m_black() -> StandardMaterial3D:
	return Greybox.material(Color(0.04, 0.04, 0.045), 0.0, 0.55, 0.0)

static func m_keys() -> StandardMaterial3D:
	return Greybox.material(Color(0.12, 0.12, 0.13), 0.0, 0.7, 0.0)

static func m_white() -> StandardMaterial3D:
	return Greybox.material(Color(0.76, 0.76, 0.74), 0.0, 0.6, 0.0)

static func m_steel() -> StandardMaterial3D:
	return Greybox.material(Color(0.56, 0.57, 0.58), 0.0, 0.5, 0.0)

static func m_chrome() -> StandardMaterial3D:
	return Greybox.material(Color(0.7, 0.72, 0.74), 0.0, 0.25, 0.8)

static func m_paper() -> StandardMaterial3D:
	var m := Greybox.material(Color(0.82, 0.81, 0.77), 0.0, 0.85, 0.0)
	if not m.has_meta("gfx_m"):
		m.set_meta("gfx_m", "propio")  # papel: liso (el relieve genérico de «pintura» lo dejaba rayado de cerca)
	return m

## Paño de tela de los divisores y melamina de su parte baja.
static func m_fabric() -> StandardMaterial3D:
	return Greybox.material(Color(0.24, 0.32, 0.4), 0.0, 1.0)

static func m_laminate() -> StandardMaterial3D:
	return Greybox.material(Color(0.2, 0.2, 0.21), 0.0, 0.6)

## Zona gastada del tablero: una veladura clara y brillante, más marcada al centro.
static var _wear: StandardMaterial3D = null
static func m_wear() -> StandardMaterial3D:
	if _wear == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tx := GradientTexture2D.new()
		tx.gradient = g
		tx.width = 64
		tx.height = 64
		tx.fill = GradientTexture2D.FILL_RADIAL
		tx.fill_from = Vector2(0.5, 0.5)
		tx.fill_to = Vector2(1.0, 0.5)
		_wear = StandardMaterial3D.new()
		_wear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wear.albedo_texture = tx
		_wear.albedo_color = Color(0.92, 0.9, 0.86, 0.2)
		_wear.roughness = 0.16
		_wear.metallic_specular = 0.8
		_wear.set_meta("gfx_m", "propio")
	return _wear

static func m_led_green() -> StandardMaterial3D:
	return Greybox.material(Greybox.VERDE_LED, 2.5)

static func m_led_blue() -> StandardMaterial3D:
	return Greybox.material(Color(0.45, 0.7, 1.0), 2.0)

## Franja esmerilada del vidrio (material propio: GfxMaterials no lo viste como vidrio).
static func m_frost() -> StandardMaterial3D:
	var m := Greybox.material(Color(0.80, 0.87, 0.87, 0.34), 0.0, 0.72, 0.0)
	if not m.has_meta("gfx_m"):
		m.set_meta("gfx_m", "propio")
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- aplicar / quitar --------------------------------------------------------------------------------------------

func apply(p_floor: Node) -> void:
	var lv := GfxSettings.level("detalle") if GfxSettings.enhanced() else 0
	if p_floor != floor_node or lv != level_built or (root != null and not is_instance_valid(root)):
		clear()
	floor_node = p_floor
	level_built = lv
	if lv <= 0 or p_floor == null or not is_instance_valid(p_floor) or not (p_floor is Node3D):
		return
	if is_instance_valid(root):
		return
	_build(lv)


func clear() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
			(n as Node).remove_meta("gfx_oculto")
	_hidden.clear()
	for pair in _swapped:
		if is_instance_valid(pair[0]):
			(pair[0] as MeshInstance3D).mesh = pair[1]
	_swapped.clear()
	for pair in _swapped_mat:
		if is_instance_valid(pair[0]) and (pair[0] as MeshInstance3D).material_override == null:
			(pair[0] as MeshInstance3D).material_override = pair[1]
	_swapped_mat.clear()
	_meshes.clear()
	_screen_mat = null
	_glow_mat = null
	_bust_mat = null
	_window_mat = null
	_leak_mat = null
	for n in _loose:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_loose.clear()
	if is_instance_valid(root):
		root.name = NODE_NAME + "Viejo"
		root.queue_free()
	root = null
	screen_points = []
	point_specs = []
	_em_spots.clear()
	_led_mats.clear()
	_em_mat = null
	_lots.clear()
	_light_xz.clear()
	stats = {}
	level_built = -1


## Rehace la capa sobre el mismo piso (el director lo pide cuando el piso cambió sus luminarias: «un panel más»).
func rebuild() -> void:
	var fl := floor_node
	clear()
	apply(fl)


func _build(lv: int) -> void:
	var fl := floor_node as Node3D
	_inv = fl.global_transform.affine_inverse()
	_base_y = (fl as FloorBase).base_y if fl is FloorBase else 0.0
	_draws = 0
	_tris = 0
	_copies = 0
	_practical_count = 0
	_leak_count = 0
	root = Node3D.new()
	root.name = NODE_NAME
	root.set_meta("no_merge", true)
	root.set_meta("gfx_fx", "detalle")
	fl.add_child(root)
	for n in fl.find_children("*", "OmniLight3D", true, false):
		var p := _rel(n as Node3D).origin
		_light_xz.append(Vector2(p.x, p.z))
	_meshes.clear()
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	_fixtures()
	_contact()   # antes de cambiar las sillas: busca el asiento de caja
	_chairs()
	_cubicles(lv)
	_glass()
	_glass_reflections()
	_exits()
	_indicators()
	_practicals()
	_windows()
	_door_leaks()
	if lv >= 2:
		_occ_build()
		_ceilings()
		_walls()
		_doors()
		_tables()
		_whiteboards()
	for key in _lots.keys():
		var gm: GfxMesh = _lots[key]
		var mi := gm.make_instance("Lote_" + str(key), true)
		if mi != null:
			root.add_child(mi)
			_draws += mi.mesh.get_surface_count()
			_tris += gm.tris
	_lots.clear()
	_meshes.clear()
	_occ.clear()
	stats = {"nivel": lv, "sillas": _swapped.size(), "dibujos": _draws, "triangulos": _tris, "copias": _copies, "pantallas": screen_points.size() - _practical_count, "practicas": _practical_count, "rendijas": _leak_count, "bustos": _hidden.size()}
	set_flicker(GfxSettings.flicker())


# --- ocupación: qué hay ya colgado o apoyado (para no poner un tablero encima de un afiche) -------------------

func _occ_build() -> void:
	_occ.clear()
	for mi in _meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var a: AABB = _rel(mi) * mi.mesh.get_aabb()
		if a.size.x > 6.0 or a.size.z > 6.0 or a.position.y + a.size.y < _base_y + 0.3:
			continue  # losas, techos, muros largos y lo que va a ras del suelo
		if mi.get_node_or_null("Col") != null and a.size.y >= 2.2 and minf(a.size.x, a.size.z) <= 0.4:
			continue  # un muro o una mampara: no estorba a lo que cuelga de otro muro
		_occ_add(a)
	for n in floor_node.find_children("*", "Label3D", true, false):
		if (n as Label3D).is_visible_in_tree():
			var p := _rel(n as Node3D).origin
			_occ_add(AABB(p - Vector3(0.8, 0.3, 0.8), Vector3(1.6, 0.6, 1.6)))


func _occ_add(a: AABB) -> void:
	for cx in range(floori(a.position.x * 0.5), floori((a.position.x + a.size.x) * 0.5) + 1):
		for cz in range(floori(a.position.z * 0.5), floori((a.position.z + a.size.z) * 0.5) + 1):
			var key := Vector2i(cx, cz)
			if not _occ.has(key):
				_occ[key] = []
			(_occ[key] as Array).append(a)


func _occ_hit(b: AABB) -> bool:
	for cx in range(floori(b.position.x * 0.5), floori((b.position.x + b.size.x) * 0.5) + 1):
		for cz in range(floori(b.position.z * 0.5), floori((b.position.z + b.size.z) * 0.5) + 1):
			for a in _occ.get(Vector2i(cx, cz), []):
				if (a as AABB).intersects(b):
					return true
	return false


func _rel(n: Node3D) -> Transform3D:
	return _inv * n.global_transform


func _lot(p: Vector3) -> GfxMesh:
	var key := "%d_%d" % [floori(p.x / CELL), floori(p.z / CELL)]
	if not _lots.has(key):
		_lots[key] = GfxMesh.new()
	return _lots[key]


func _add_mm(p_name: String, kit: GfxMesh, xforms: Array, shadows: bool = true, custom: Array = [], colors: Array = []) -> MultiMeshInstance3D:
	if xforms.is_empty() or kit.is_empty():
		return null
	var mesh := kit.commit()
	var mmi := GfxMesh.make_multimesh(p_name, mesh, xforms, custom, colors, shadows)
	if mmi == null:
		return null
	root.add_child(mmi)
	_draws += mesh.get_surface_count()
	_tris += kit.tris * xforms.size()
	_copies += xforms.size()
	return mmi


# --- luminarias ---------------------------------------------------------------------------------------------------

func _fixtures() -> void:
	var xf_panel: Array = []
	var xf_down: Array = []
	for mi in _meshes:
		if not mi.is_visible_in_tree():
			continue
		if mi.mesh is BoxMesh and mi.get_node_or_null("Borde") != null:
			var s := (mi.mesh as BoxMesh).size
			if absf(s.x - 1.2) < 0.05 and absf(s.z - 0.3) < 0.05:
				xf_panel.append(_rel(mi))
		elif mi.mesh is CylinderMesh:
			var cm := mi.mesh as CylinderMesh
			if absf(cm.bottom_radius - 0.09) < 0.005 and cm.height < 0.05:
				xf_down.append(_rel(mi))
	# Tubo de techo (1,2 × 0,3): carcasa de chapa, tapas en los extremos y celosía colgada bajo el difusor.
	var kit := GfxMesh.new()
	var steel := m_steel()
	var white := m_white()
	kit.cube(steel, Vector3(0, 0.062, 0), Vector3(1.34, 0.044, 0.44))
	for sx in [-1.0, 1.0]:
		kit.cube(white, Vector3(sx * 0.6125, -0.008, 0), Vector3(0.025, 0.066, 0.34))
	for sz in [-1.0, 1.0]:
		kit.cube(white, Vector3(0, -0.034, sz * 0.153), Vector3(1.2, 0.022, 0.008))
	for i in 9:
		kit.cube(white, Vector3(-0.48 + 0.12 * i, -0.034, 0), Vector3(0.006, 0.02, 0.3))
	_add_mm("Luminarias", kit, xf_panel, false)
	# Downlight: aro de aluminio y cuello.
	var kd := GfxMesh.new()
	kd.cyl(m_white(), Transform3D(Basis.IDENTITY, Vector3(0, -0.004, 0)), 0.125, 0.012, 14)
	kd.cyl(m_black(), Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), 0.1, 0.06, 14)
	_add_mm("AroDownlight", kd, xf_down, false)


# --- sombras de contacto ---------------------------------------------------------------------------------------

## Bajo cada silla, una mancha oscura y suave en el suelo (shader propio, un solo dibujo para todo el piso): asienta
## los muebles y a quien está sentado en ellos sin gastar una sombra de verdad.
func _contact() -> void:
	if not ResourceLoader.exists(SHADOW_SHADER):
		return
	var xf_s: Array = []
	var flat := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	for mi in _meshes:
		if not str(mi.name).begins_with("Silla") or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		if s.y > 0.09 or minf(s.x, s.z) < 0.34 or maxf(s.x, s.z) > 0.62:
			continue  # solo el asiento (no respaldos, patas ni sillas apiladas)
		var o := _rel(mi).origin
		var h := o.y - _base_y
		if h < 0.3 or h > 0.62:
			continue
		xf_s.append(Transform3D(flat.scaled_local(Vector3(1.1, 1.1, 1.0)), Vector3(o.x, _base_y + 0.008, o.z)))
	if xf_s.is_empty():
		return
	var m := ShaderMaterial.new()
	m.shader = load(SHADOW_SHADER) as Shader
	m.set_shader_parameter("alpha", 0.5)
	var k := GfxMesh.new()
	k.quad(m, Transform3D.IDENTITY, Vector2(1.0, 1.0))
	_add_mm("SombrasContacto", k, xf_s, false)


# --- sillas ------------------------------------------------------------------------------------------------------

## Las sillas de los cubículos pasan a ser sillas de trabajo: se cambia la malla de sus tres nodos (ver GfxKits).
func _chairs() -> void:
	for mi in _meshes:
		var nm := str(mi.name)
		if nm == "Silla" and mi.mesh is BoxMesh:
			if (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.48, 0.06, 0.46)):
				_swap(mi, GfxKits.chair_seat())
		elif nm == "Respaldo" and mi.mesh is BoxMesh:
			var s := (mi.mesh as BoxMesh).size
			if absf(s.x - 0.44) < 0.005 and absf(s.z - 0.04) < 0.005 and absf(s.y - 0.55) < 0.04:
				_swap(mi, GfxKits.chair_back())
		elif nm == "Estrella" and mi.mesh is CylinderMesh:
			if absf((mi.mesh as CylinderMesh).bottom_radius - 0.26) < 0.005:
				_swap(mi, GfxKits.chair_star())
		elif nm == "Taza" and mi.mesh is BoxMesh:
			# La taza de C-13 (la que todavía humea) era un cubo blanco de 10 cm: pasa a ser una taza, en el mismo nodo
			# (el vapor, los golpes en la mesa y las muertes la siguen encontrando). Lleva sus propios materiales.
			if (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.1, 0.1, 0.1)):
				_swap(mi, GfxKits.mug())
				_swapped_mat.append([mi, mi.material_override])
				mi.material_override = null


func _swap(mi: MeshInstance3D, mesh: Mesh) -> void:
	_swapped.append([mi, mi.mesh])
	mi.mesh = mesh


# --- cubículos, monitores, pantallas y siluetas -----------------------------------------------------------------

const _CUB_STD: Array = ["Panel", "Escritorio", "Silla", "Respaldo", "Base", "Busto"]

## ¿El cubículo trae cosas propias sobre la mesa (una nota que se lee, una taza)? Entonces no se le agregan más.
static func _has_own_props(cub: Node) -> bool:
	for c in cub.get_children():
		var nm := str(c.name)
		if c is MeshInstance3D and not (nm in _CUB_STD) and not nm.begins_with("Moldura") and not nm.begins_with("Monitor") and not nm.begins_with("Pie"):
			return true
		if nm.begins_with("Nota") or nm.begins_with("Headset"):
			return true
	return false


func _cubicles(lv: int) -> void:
	var xf_cub: Array = []
	var xf_mon: Array = []
	var xf_scr: Array = []
	var scr_data: Array = []
	var xf_glow: Array = []
	var glow_data: Array = []
	var xf_bust: Array = []
	var bust_data: Array = []
	var xf_clut: Array = [[], [], [], []]
	var fl := floor_node as Node3D
	for n in fl.find_children("Cub_*", "Node3D", true, false):
		var cub := n as Node3D
		if cub.get_node_or_null("Panel") == null or cub.get_node_or_null("Escritorio") == null:
			continue
		var xf := _rel(cub)
		xf_cub.append(xf)
		var sd := float(absi(str(cub.name).hash()) % 9973) / 9973.0
		var live := false
		var occupied := false
		for c in cub.get_children():
			var nm := str(c.name)
			if nm.begins_with("Pantalla_"):
				live = true
			elif nm == "Busto" or nm.begins_with("Rig_"):
				occupied = true
		if lv >= 2 and not _has_own_props(cub):
			(xf_clut[int(sd * 7919.0) % 4] as Array).append(xf)
		var lit := 0.0   # cuánta luz de pantalla le llega a quien está sentado
		var i := 0
		while true:
			var mon := cub.get_node_or_null("Monitor%d" % i) as MeshInstance3D
			if mon == null:
				break
			var mxf := xf * Transform3D(Basis.IDENTITY, mon.position)
			xf_mon.append(mxf)
			if live:
				# Tu propio monitor (pantalla del juego): ya trae su luz azul (MonitorScreen: alumbra tus manos); aquí solo
				# se agrega la mancha de luz sobre tu mesa.
				lit = maxf(lit, 0.6)
				xf_glow.append(xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(clampf(mon.position.x, -0.31, 0.31), 0.776, -0.3)))
				glow_data.append(Color(sd, 0.3, 1.0, 0.0))
			else:
				var on := 1.0 if occupied else (0.5 if fmod(sd * 13.0, 1.0) > 0.45 else 0.0)
				var light_theme := 1.0 if fmod(sd * 29.0 + 0.41 * i, 1.0) > 0.58 else 0.0
				var data := Color(fmod(sd + 0.37 * i, 1.0), fmod(sd * 3.0 + 0.2 * i, 1.0), on, light_theme)
				xf_scr.append(mxf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0158)))
				scr_data.append(data)
				if on > 0.75:
					lit = maxf(lit, 1.0 if light_theme > 0.5 else 0.55)
					screen_points.append(fl.global_transform * (mxf * Vector3(0, -0.02, 0.42)))
					point_specs.append([Color(0.74, 0.84, 1.0), 0.6, 2.4] if light_theme > 0.5 else [Color(0.5, 0.68, 1.0), 0.4, 2.2])
					xf_glow.append(xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(clampf(mon.position.x, -0.31, 0.31), 0.776, -0.3)))
					glow_data.append(data)
			i += 1
		var busto := cub.get_node_or_null("Busto") as MeshInstance3D
		if busto != null and busto.visible:
			var lean := (sd - 0.5) * 0.16
			var sc := 0.95 + 0.1 * fmod(sd * 7.0, 1.0)
			xf_bust.append(xf * Transform3D(Basis(Vector3.UP, lean).scaled(Vector3(sc, sc, sc)), busto.position + Vector3(0, (sc - 1.0) * -0.5, 0)))
			var shirt := _shirt(sd)
			bust_data.append(Color(shirt.r, shirt.g, shirt.b, lit))
			busto.visible = false
			busto.set_meta("gfx_oculto", true)
			_hidden.append(busto)
	if xf_cub.is_empty():
		return
	# --- kit del cubículo (marco local: divisor en z −0,6, tablero z −0,6..0, silla en z +0,4) ---
	var kit := GfxMesh.new()
	var alu := m_alu()
	var black := m_black()
	kit.cube(alu, Vector3(0, 1.107, -0.6), Vector3(1.52, 0.014, 0.054))                 # remate del divisor
	for sx in [-1.0, 1.0]:
		kit.cube(alu, Vector3(sx * 0.761, 0.55, -0.6), Vector3(0.022, 1.1, 0.062))      # postes
	kit.cube(black, Vector3(0, 0.03, -0.6), Vector3(1.5, 0.06, 0.058))                  # zócalo del divisor
	kit.cube(alu, Vector3(0, 0.772, -0.6), Vector3(1.5, 0.016, 0.058))                  # riel medio
	var fabric := m_fabric()
	for sz in [-1.0, 1.0]:                                                              # paño de tela arriba
		kit.cube(fabric, Vector3(0, 0.94, -0.6 + sz * 0.0265), Vector3(1.5, 0.32, 0.003))
	kit.cube(m_laminate(), Vector3(0, 0.412, -0.6265), Vector3(1.46, 0.69, 0.003))      # melamina abajo (lado del pasillo)
	kit.cube(m_frame(), Vector3(0, 1.132, -0.578), Vector3(0.25, 0.082, 0.004))         # placa del puesto
	kit.cube(Greybox.material(Color(0.2, 0.18, 0.15), 0.0, 0.6), Vector3(0, 0.735, 0.0035), Vector3(1.5, 0.032, 0.007))  # canto
	kit.cube(black, Vector3(0, 0.655, -0.5), Vector3(1.3, 0.07, 0.12))                  # bandeja de cables
	kit.cyl(black, Transform3D(Basis.IDENTITY, Vector3(0.52, 0.752, -0.47)), 0.03, 0.004, 10)  # pasacables
	GfxKits.keyboard(kit, lv >= 2)
	if lv >= 2:
		kit.cube(black, Vector3(0.34, 0.7515, -0.13), Vector3(0.24, 0.003, 0.2))        # alfombrilla
		kit.cube(m_keys(), Vector3(0.34, 0.764, -0.14), Vector3(0.058, 0.026, 0.1))     # ratón
		kit.cube(black, Vector3(-0.56, 0.18, -0.32), Vector3(0.17, 0.36, 0.38))         # CPU
		kit.cube(m_led_green(), Vector3(-0.56, 0.3, -0.128), Vector3(0.012, 0.012, 0.004))
		kit.cube(black, Vector3(0.52, 0.5, -0.46), Vector3(0.012, 0.5, 0.012))          # cables que bajan
	_add_mm("Cubiculos", kit, xf_cub, true)
	for v in xf_clut.size():
		_add_mm("Mesa%d" % v, GfxKits.clutter(v), xf_clut[v], false)
	# --- kit del monitor (marco local: centro de la caja 0,56 × 0,34 × 0,03, frente +z) ---
	var km := GfxMesh.new()
	var gloss := Greybox.material(Color(0.03, 0.03, 0.035), 0.0, 0.35, 0.0)
	km.cube(gloss, Vector3(0, 0.166, 0.017), Vector3(0.572, 0.014, 0.01))
	km.cube(gloss, Vector3(0, -0.166, 0.017), Vector3(0.572, 0.018, 0.01))
	for sx in [-1.0, 1.0]:
		km.cube(gloss, Vector3(sx * 0.279, 0, 0.017), Vector3(0.014, 0.32, 0.01))
	km.cube(black, Vector3(0, 0, -0.03), Vector3(0.34, 0.22, 0.035))
	km.cube(black, Vector3(0, -0.364, -0.01), Vector3(0.24, 0.012, 0.17))
	km.cube(m_led_blue(), Vector3(0.245, -0.166, 0.0225), Vector3(0.008, 0.004, 0.002))
	_add_mm("Monitores", km, xf_mon, true)
	# --- pantallas de relleno y la luz que dejan en la mesa ---
	if not xf_scr.is_empty() and ResourceLoader.exists(SCREEN_SHADER):
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = load(SCREEN_SHADER) as Shader
		_screen_mat.set_shader_parameter("brightness", 2.0)
		var ks := GfxMesh.new()
		ks.quad(_screen_mat, Transform3D.IDENTITY, Vector2(0.535, 0.315))
		_add_mm("Pantallas", ks, xf_scr, false, scr_data)
	if not xf_glow.is_empty() and ResourceLoader.exists(GLOW_SHADER):
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = load(GLOW_SHADER) as Shader
		var kg := GfxMesh.new()
		kg.quad(_glow_mat, Transform3D.IDENTITY, Vector2(0.86, 0.59))
		_add_mm("BrilloMesa", kg, xf_glow, false, glow_data)
	# --- desgaste del tablero: la zona pulida donde se apoyan los antebrazos (devuelve algo de la luz del monitor) ---
	if lv >= 2:
		var kw := GfxMesh.new()
		kw.quad(m_wear(), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.7513, -0.11)), Vector2(1.05, 0.24))
		_add_mm("Desgaste", kw, xf_cub, false)
	# --- siluetas sentadas ---
	if not xf_bust.is_empty() and ResourceLoader.exists(BUST_SHADER):
		_bust_mat = ShaderMaterial.new()
		_bust_mat.shader = load(BUST_SHADER) as Shader
		_bust_mat.set_shader_parameter("bounce", 0.35 if GfxSettings.forward() else 0.9)
		_add_mm("Siluetas", GfxKits.bust(_bust_mat), xf_bust, true, bust_data)


static func _shirt(sd: float) -> Color:
	var pal: Array = [Color(0.10, 0.12, 0.2), Color(0.16, 0.08, 0.09), Color(0.07, 0.15, 0.13), Color(0.22, 0.22, 0.24),
		Color(0.26, 0.2, 0.12), Color(0.06, 0.06, 0.08), Color(0.3, 0.3, 0.34), Color(0.12, 0.2, 0.3)]
	return pal[int(sd * 997.0) % pal.size()]


# --- vidrios ---------------------------------------------------------------------------------------------------

func _glass() -> void:
	var glass := Greybox.material(Greybox.VIDRIO)
	var frame := m_frame()
	var frost := m_frost()
	for mi in _meshes:
		if mi.material_override != glass or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		if mi.get_node_or_null("Col") == null:
			continue  # hojas de puerta y vidrios sueltos: ya traen su marco y jaladores
		var s := (mi.mesh as BoxMesh).size
		if s.y < 1.2:
			continue
		var xf := _rel(mi)
		var along_x := s.x >= s.z
		var length := s.x if along_x else s.z
		var thick := s.z if along_x else s.x
		if length < 0.3:
			continue
		var gm := _lot(xf.origin)
		var deep := thick + 0.03
		# canales arriba y abajo
		for sy in [-1.0, 1.0]:
			var c := Vector3(0, sy * (s.y * 0.5 - 0.02), 0)
			gm.box(frame, xf * Transform3D(Basis.IDENTITY, c), Vector3(length + 0.02, 0.04, deep) if along_x else Vector3(deep, 0.04, length + 0.02))
		# montantes: extremos e intermedios cada ≤ 1,25 m
		var parts := maxi(int(ceil(length / 1.25)), 1)
		for i in parts + 1:
			var t := -length * 0.5 + length * float(i) / float(parts)
			var w := 0.035 if (i == 0 or i == parts) else 0.026
			var c2 := Vector3(t, 0, 0) if along_x else Vector3(0, 0, t)
			gm.box(frame, xf * Transform3D(Basis.IDENTITY, c2), Vector3(w, s.y - 0.04, deep) if along_x else Vector3(deep, s.y - 0.04, w))
		# franja esmerilada a 1,1 m del suelo (por las dos caras)
		var band_y := (_base_y + 1.1) - xf.origin.y
		if absf(band_y) < s.y * 0.5 - 0.2:
			for sz in [-1.0, 1.0]:
				var off: float = sz * (thick * 0.5 + 0.003)
				var c3 := Vector3(0, band_y, off) if along_x else Vector3(off, band_y, 0)
				gm.box(frost, xf * Transform3D(Basis.IDENTITY, c3), Vector3(length - 0.05, 0.16, 0.002) if along_x else Vector3(0.002, 0.16, length - 0.05))


## Reflejo falso en cada paño de vidrio (por las dos caras): la retícula de tubos de la sala que queda detrás de
## quien mira (assets/shaders/gfx_vidrio.gdshader). Un solo dibujo para todos los vidrios del piso.
func _glass_reflections() -> void:
	if not ResourceLoader.exists(GLASS_SHADER):
		return
	var xf_g: Array = []
	var data: Array = []
	for mi in _meshes:
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or mat.albedo_color.a > 0.9 or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		if mi.get_node_or_null("Col") == null:
			continue  # hojas de puerta: giran
		var s := (mi.mesh as BoxMesh).size
		var along_x := s.x >= s.z
		var length := s.x if along_x else s.z
		var thick := s.z if along_x else s.x
		if s.y < 1.2 or length < 0.6 or thick > 0.1:
			continue
		var xf := _rel(mi)
		var frost := 0.75 if mat.albedo_color.a > 0.45 else 0.0
		for side in [-1.0, 1.0]:
			var sg: float = side
			var b := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
			if sg < 0.0:
				b = b * Basis(Vector3.UP, PI)
			var off := sg * (thick * 0.5 + 0.004)
			var c := Vector3(0, 0, off) if along_x else Vector3(off, 0, 0)
			xf_g.append(xf * Transform3D(b.scaled_local(Vector3(length - 0.04, s.y - 0.04, 1.0)), c))
			data.append(Color(frost, 0, 0, 0))
	if xf_g.is_empty():
		return
	var m := ShaderMaterial.new()
	m.shader = load(GLASS_SHADER) as Shader
	m.set_shader_parameter("ceiling_y", (floor_node as Node3D).global_position.y + _base_y + 2.9)
	var k := GfxMesh.new()
	k.quad(m, Transform3D.IDENTITY, Vector2(1.0, 1.0))
	_add_mm("ReflejosVidrio", k, xf_g, false, data)


## Indicadores de piso de los ascensores: el resplandor ámbar que baja por la puerta y su reflejo en el suelo
## (manchas aditivas: no son luces, no entran en el cupo por objeto).
func _indicators() -> void:
	if not ResourceLoader.exists(GLOW_SHADER):
		return
	var xf_i: Array = []
	var data: Array = []
	for mi in _meshes:
		var nm := str(mi.name)
		if not (nm == "IndicadorCaja" or nm.ends_with("Indicador")) or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		if s.x < 0.3 or s.x > 1.2 or s.y > 0.5:
			continue
		var xf := _rel(mi)
		var f := xf.basis.z.normalized()   # el frente del indicador (hacia el hall)
		f.y = 0.0
		if f.length() < 0.5:
			continue
		f = f.normalized()
		# halo vertical: la zona caliente del shader (22 % desde arriba) cae sobre el indicador
		xf_i.append(xf * Transform3D(Basis.IDENTITY.scaled_local(Vector3(1.7, 1.3, 1.0)), Vector3(0, -0.36, s.z * 0.5 + 0.02)))
		data.append(Color(0.31, 0.2, 1.0, 0.0))
		# reflejo en el suelo, alargado hacia el hall
		var y_axis := -f
		var basis := Basis(y_axis.cross(Vector3.UP).normalized(), y_axis, Vector3.UP)
		var depth := 2.6
		var pos := Vector3(xf.origin.x, _base_y + 0.011, xf.origin.z) + f * (depth * 0.5 - 0.35)
		xf_i.append(Transform3D(basis.scaled_local(Vector3(1.5, depth, 1.0)), pos))
		data.append(Color(0.67, 0.6, 1.0, 0.0))
	if xf_i.is_empty():
		return
	var m := ShaderMaterial.new()
	m.shader = load(GLOW_SHADER) as Shader
	m.set_shader_parameter("tint", Color(1.0, 0.58, 0.16))
	m.set_shader_parameter("energy", 1.5)
	m.set_shader_parameter("flicker_amount", 0.0)
	var k := GfxMesh.new()
	k.quad(m, Transform3D.IDENTITY, Vector2(1.0, 1.0))
	_add_mm("BrilloIndicadores", k, xf_i, false, data)


# --- luces de práctica: lo que ya brilla en el piso, alumbra ------------------------------------------------

## ¿Es una luz que agregó este paquete (haz, práctica, emergencia…) y no una del juego? Las omnis de las luminarias
## del juego también llevan la marca «gfx_fx» mientras están rediseñadas: esas SÍ son del juego.
static func _is_added_light(n: Node) -> bool:
	if not n.has_meta("gfx_fx"):
		return false
	return str(n.get_meta("gfx_fx")) in ["haz", "practica", "presencia", "emergencia"]


## Vitrina de la expendedora, pilotos rojos (REC, cámaras, lectores), flechas de los molinetes, botonera del
## ascensor, PCs del aula, monitores sueltos, letras luminosas…: toda malla emisiva del piso que no tiene ya una
## luz del juego al lado pasa a ser un punto de la bolsa de luces de práctica (GfxLights reparte unas pocas luces
## sin sombra entre los puntos más cercanos a la cámara). No crea nodos: solo anota posición, color y alcance.
func _practicals() -> void:
	var lights_pos: Array[Vector3] = []
	for n in floor_node.find_children("*", "Light3D", true, false):
		if not _is_added_light(n):
			lights_pos.append((n as Node3D).global_position)
	var found: Array = []   # [posición, color, energía, alcance]
	var sign_mat := Greybox.material(Color(0.06, 0.32, 0.16), 1.2)
	for mi in _meshes:
		var m := mi.material_override as StandardMaterial3D
		if m == null or not m.emission_enabled or not mi.is_visible_in_tree():
			continue
		if m == sign_mat:
			continue  # los carteles de salida ya llevan su halo (_exits): con una luz de práctica encima teñían todo el pasillo
		var nm := str(mi.name)
		var screen := nm.begins_with("Monitor") or nm.begins_with("Pantalla") or nm.begins_with("PC") or nm == "Vitrina"
		var em := m.emission_energy_multiplier
		if em < (0.3 if screen else 0.75):
			continue
		if nm.begins_with("Monitor") and str(mi.get_parent().name).begins_with("Cub_"):
			continue  # las pantallas de los cubículos van por su cuenta
		var size := Vector3.ZERO
		if mi.mesh is BoxMesh:
			size = (mi.mesh as BoxMesh).size
		elif mi.mesh is CylinderMesh:
			var cm := mi.mesh as CylinderMesh
			size = Vector3(cm.bottom_radius * 2.0, cm.height, cm.bottom_radius * 2.0)
		else:
			continue
		size *= mi.global_transform.basis.get_scale()
		var dims: Array[float] = [size.x, size.y, size.z]
		dims.sort()
		var area := dims[1] * dims[2]
		if area > 1.6:
			continue  # cielos, paneles grandes: no son utilería
		var c := m.emission
		var mx := maxf(c.r, maxf(c.g, c.b))
		if mx < 0.06:
			continue
		var gp := mi.global_position
		var near := false
		for lp in lights_pos:
			if lp.distance_squared_to(gp) < 0.49:
				near = true
				break
		if near:
			continue  # es una lámpara con su luz: ya alumbra
		var k := sqrt(area * em)
		var col := Color(c.r / mx, c.g / mx, c.b / mx).lerp(Color.WHITE, 0.15)
		var e := clampf(0.14 + 0.3 * k, 0.16, 0.9)
		var r := clampf(1.3 + 2.4 * k, 1.3, 4.2)
		var merged := false
		for f in found:
			if (f[0] as Vector3).distance_squared_to(gp) < 0.3:
				f[0] = ((f[0] as Vector3) + gp) * 0.5
				f[2] = minf(float(f[2]) + e * 0.5, 0.9)
				f[3] = maxf(float(f[3]), r)
				merged = true
				break
		if not merged:
			found.append([gp, col, e, r])
	for f in found:
		screen_points.append(f[0])
		point_specs.append([f[1], f[2], f[3]])
	_practical_count = found.size()


# --- luz que entra: ventanas con persiana y rendijas de puerta ---------------------------------------------

## Hacia dónde queda «dentro» desde un punto de la fachada: el lado donde están las luces del piso.
func _inward(origin: Vector3, n: Vector3) -> Vector3:
	if _light_xz.is_empty():
		return n
	var c := Vector2.ZERO
	for q in _light_xz:
		c += q
	c /= float(_light_xz.size())
	var a := Vector2(origin.x + n.x, origin.z + n.z).distance_squared_to(c)
	var b := Vector2(origin.x - n.x, origin.z - n.z).distance_squared_to(c)
	return n if a <= b else -n


## Cada persiana deja en el suelo la luz fría de la calle, con la sombra de sus tiras. De día (el recuerdo) se apaga.
func _windows() -> void:
	if not ResourceLoader.exists(WINDOW_SHADER) or GfxMaterials.tex("luz_ventana") == null:
		return
	var xf_w: Array = []
	for mi in _meshes:
		if not str(mi.name).contains("Persiana") or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		var xf := _rel(mi)
		var along_x := s.x >= s.z
		var width := s.x if along_x else s.z
		if width < 0.6 or s.y < 0.8:
			continue
		var bx := (xf.basis.x if along_x else xf.basis.z).normalized()
		var n := _inward(xf.origin, (xf.basis.z if along_x else xf.basis.x).normalized())
		n.y = 0.0
		if n.length() < 0.5:
			continue
		n = n.normalized()
		var depth := 2.6
		# Cuadro acostado: su «arriba» (UV.y = 0) mira a la ventana y su normal al techo.
		var y_axis := -n
		var basis := Basis(y_axis.cross(Vector3.UP).normalized(), y_axis, Vector3.UP)
		var pos := Vector3(xf.origin.x, _base_y + 0.012, xf.origin.z) + n * (depth * 0.5 + 0.12)
		xf_w.append(Transform3D(basis.scaled_local(Vector3(width * 0.96, depth, 1.0)), pos))
	if xf_w.is_empty():
		return
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = load(WINDOW_SHADER) as Shader
	_window_mat.set_shader_parameter("mask", GfxMaterials.tex("luz_ventana"))
	var k := GfxMesh.new()
	k.quad(_window_mat, Transform3D.IDENTITY, Vector2(1.0, 1.0))
	_add_mm("LuzVentanas", k, xf_w, false)


## Bajo una puerta cerrada que da a un ambiente con luz, del lado oscuro queda la rendija de luz en el suelo.
func _door_leaks() -> void:
	if not ResourceLoader.exists(GLOW_SHADER):
		return
	var lit: Array[Vector3] = []
	for n in floor_node.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if _is_added_light(l) or l.has_meta("gfx_off") or not l.is_visible_in_tree() or l.light_energy < 0.08:
			continue
		lit.append(_rel(l).origin)
	var xf_l: Array = []
	var data: Array = []
	for n in floor_node.find_children("*", "", true, false):
		if not (n is WorldObjects.Door):
			continue
		var d := n as WorldObjects.Door
		if d.leaf == null or not (d.leaf.mesh is BoxMesh) or not d.leaf.is_visible_in_tree():
			continue
		var mat := d.leaf.material_override as StandardMaterial3D
		if mat != null and mat.albedo_color.a < 0.99:
			continue  # hoja de vidrio: la luz ya pasa
		var s := (d.leaf.mesh as BoxMesh).size
		var xf := _rel(d.leaf)
		var along_x := s.x >= s.z
		var width := s.x if along_x else s.z
		var nrm := (xf.basis.z if along_x else xf.basis.x).normalized()
		nrm.y = 0.0
		if width < 0.6 or nrm.length() < 0.5:
			continue
		nrm = nrm.normalized()
		var amount: Array[float] = [0.0, 0.0]
		for side in 2:
			var p := xf.origin + nrm * (1.6 if side == 0 else -1.6)
			for lp in lit:
				var dd := Vector2(lp.x - p.x, lp.z - p.z).length()
				if dd < 4.5:
					amount[side] += 1.0 - dd / 4.5
		print_verbose("[gfx] puerta %s luz %.2f / %.2f (luces %d)" % [str(d.name), amount[0], amount[1], lit.size()])
		var dark := -1
		if amount[0] >= 0.3 and amount[1] <= amount[0] * 0.5:
			dark = 1
		elif amount[1] >= 0.3 and amount[0] <= amount[1] * 0.5:
			dark = 0
		if dark < 0:
			continue
		var f := nrm if dark == 0 else -nrm   # hacia dentro del lado oscuro
		var y_axis := -f
		var basis := Basis(y_axis.cross(Vector3.UP).normalized(), y_axis, Vector3.UP)
		var depth := 1.1
		var pos := Vector3(xf.origin.x, _base_y + 0.01, xf.origin.z) + f * (depth * 0.5 - 0.2)
		xf_l.append(Transform3D(basis.scaled_local(Vector3(width * 1.25, depth, 1.0)), pos))
		data.append(Color(0.5, 0.3, 1.0, 1.0))
	if xf_l.is_empty():
		return
	_leak_mat = ShaderMaterial.new()
	_leak_mat.shader = load(GLOW_SHADER) as Shader
	_leak_mat.set_shader_parameter("tint", Color(1.0, 0.9, 0.74))
	_leak_mat.set_shader_parameter("energy", 0.42)
	_leak_mat.set_shader_parameter("flicker_amount", 0.0)
	var k := GfxMesh.new()
	k.quad(_leak_mat, Transform3D.IDENTITY, Vector2(1.0, 1.0))
	_add_mm("LuzPuertas", k, xf_l, false, data)
	_leak_count = xf_l.size()


## Lo que solo existe HOY (años de uso): el desgaste de los tableros, lo que la gente deja en su escritorio y en las
## mesas del comedor. En el recuerdo (Training: la torre nueva y limpia) no se dibuja.
const PRESENT_DAY: Array[String] = ["Desgaste", "Mesa0", "Mesa1", "Mesa2", "Mesa3", "Mesas0", "Mesas1", "Mesas2",
	"ReflejosVidrio", "BrilloIndicadores"]   # y lo que solo se ve de noche: reflejos de tubos y resplandores

## El recuerdo es de día y la torre está nueva: se apaga la luz de la calle (la del aula la pone el Training) y se
## esconde lo que es de hoy. Lo llama el director en cada pase (también al empezar y terminar el recuerdo).
func set_daytime(day: bool) -> void:
	if _window_mat != null:
		_window_mat.set_shader_parameter("energy", 0.0 if day else 0.16)
	if is_instance_valid(root):
		for c in root.get_children():
			if c is Node3D and str(c.name) in PRESENT_DAY:
				(c as Node3D).visible = not day


# --- carteles de salida: brillo verde y luminaria de emergencia ----------------------------------------------

func _exits() -> void:
	var sign_mat := Greybox.material(Color(0.06, 0.32, 0.16), 1.2)
	var units: Array = []
	var led_x: Array = []
	var led_c: Array = []
	var fl := floor_node as Node3D
	for mi in _meshes:
		if mi.material_override != sign_mat or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		if absf(s.x - 0.42) > 0.02 or absf(s.y - 0.16) > 0.02:
			continue
		var xf := _rel(mi)
		# brillo verde del cartel sobre lo que tiene delante
		var glow := OmniLight3D.new()
		glow.name = "BrilloSalida"
		glow.set_meta("gfx_fx", "practica")
		glow.set_meta("no_mood", true)
		glow.set_meta("budget_keep", true)
		glow.set_meta("shadow_design", false)
		glow.light_color = Color(0.25, 1.0, 0.5)
		var hanging := mi.get_node_or_null("Cable-1") != null or mi.get_node_or_null("Cable1") != null
		# Un halo verde chico pegado al cartel (no una sala teñida): poco alcance y caída rápida.
		glow.light_energy = 0.13 if hanging else 0.2
		glow.omni_range = 1.0
		glow.omni_attenuation = 2.0
		glow.light_specular = 0.2
		glow.shadow_enabled = false
		glow.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.16, 0.14))   # pegada al cartel y algo por debajo: el halo cae sobre la pared, no sobre el techo
		root.add_child(glow)
		if hanging:
			continue  # cartel colgante: sin pared donde montar la luminaria
		var uxf := xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0.02))
		units.append(uxf)
		led_x.append(uxf * Transform3D(Basis.IDENTITY, Vector3(0.12, -0.035, 0.047)))
		led_c.append(Color(fmod(float(units.size()) * 0.37, 1.0), 0, 0, 0))
		for sx in [-1.0, 1.0]:
			var sp := SpotLight3D.new()
			sp.name = "LuzEmergencia"
			sp.set_meta("gfx_fx", "emergencia")
			sp.set_meta("no_mood", true)
			sp.set_meta("budget_keep", true)
			sp.set_meta("shadow_design", false)
			sp.light_color = Color(1.0, 0.84, 0.66)
			sp.light_energy = 0.0
			sp.spot_range = 10.0
			sp.spot_angle = 52.0
			sp.spot_angle_attenuation = 1.1
			sp.shadow_enabled = false
			sp.visible = false
			sp.transform = uxf * Transform3D(Basis(Vector3.UP, sx * -0.5) * Basis(Vector3.RIGHT, deg_to_rad(-38.0)), Vector3(sx * 0.09, -0.02, 0.07))
			root.add_child(sp)
			_em_spots.append(sp)
	if units.is_empty():
		return
	var k := GfxMesh.new()
	var white := m_white()
	_em_mat = StandardMaterial3D.new()
	_em_mat.albedo_color = Color(0.5, 0.5, 0.46)
	_em_mat.roughness = 0.3
	_em_mat.emission_enabled = true
	_em_mat.emission = Color(1.0, 0.86, 0.68)
	_em_mat.emission_energy_multiplier = 0.0
	_em_mat.set_meta("gfx_m", "propio")
	k.cube(white, Vector3(0, 0, 0), Vector3(0.3, 0.11, 0.07))
	for sx in [-1.0, 1.0]:
		var hx := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(52.0)), Vector3(sx * 0.09, -0.02, 0.06))
		k.cyl(white, hx, 0.043, 0.05, 10)
		k.cyl(_em_mat, hx * Transform3D(Basis.IDENTITY, Vector3(0, 0.027, 0)), 0.036, 0.006, 10)
	_add_mm("Emergencia", k, units, false)
	_add_leds("LedEmergencia", led_x, led_c, Color(0.2, 0.95, 0.35), 5.3)


## Testigos que parpadean (shader propio, fase por copia).
func _add_leds(p_name: String, xforms: Array, data: Array, color: Color, period: float) -> void:
	if xforms.is_empty() or not ResourceLoader.exists(LED_SHADER):
		return
	var m := ShaderMaterial.new()
	m.shader = load(LED_SHADER) as Shader
	m.set_shader_parameter("led_color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("period", period)
	_led_mats.append(m)
	var k := GfxMesh.new()
	k.cube(m, Vector3.ZERO, Vector3(0.012, 0.012, 0.006))
	_add_mm(p_name, k, xforms, false, data)


# --- techos ------------------------------------------------------------------------------------------------------

func _ceilings() -> void:
	var xf_dif: Array = []
	var xf_spr: Array = []
	var xf_det: Array = []
	var led_x: Array = []
	var led_c: Array = []
	var fl := floor_node as Node3D
	for mi in _meshes:
		if not str(mi.name).contains("echo") or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		if str(mi.get_parent().name) == "Elevator":
			continue  # la cabina del ascensor tiene su propio techo y se mueve
		var s := (mi.mesh as BoxMesh).size
		if s.y > 0.16:
			continue
		var xf := _rel(mi)
		if xf.origin.y - _base_y < 2.3:
			continue
		var ex := absf(xf.basis.x.x) * s.x + absf(xf.basis.z.x) * s.z
		var ez := absf(xf.basis.x.z) * s.x + absf(xf.basis.z.z) * s.z
		var y := xf.origin.y - s.y * 0.5
		var tile := false
		var mat := mi.material_override
		if mat != null and mat.has_meta("q5_tex"):
			var tx: Variant = mat.get_meta("q5_tex")
			tile = tx is Texture2D and str((tx as Texture2D).resource_path).contains("baldosa_techo")
		var pts: Array[Vector2] = []
		var cx := xf.origin.x
		var cz := xf.origin.z
		if minf(ex, ez) < 3.2:
			# pasillo o cuarto angosto: una hilera por el eje largo
			var long_x := ex >= ez
			var length := maxf(ex, ez)
			var cnt := int(floor((length - 1.2) / 1.8)) + 1
			for i in cnt:
				var t := -(cnt - 1) * 0.9 + 1.8 * i
				pts.append(Vector2(cx + t, cz) if long_x else Vector2(cx, cz + t))
		else:
			var nx := int(floor((ex - 1.6) / 2.4)) + 1
			var nz := int(floor((ez - 1.6) / 2.4)) + 1
			for ix in nx:
				for iz in nz:
					pts.append(Vector2(cx - (nx - 1) * 1.2 + 2.4 * ix + 0.6, cz - (nz - 1) * 1.2 + 2.4 * iz + 0.6))
		var k := absi(str(mi.name).hash()) % 4
		for p in pts:
			k += 1
			if absf(p.x - cx) > ex * 0.5 - 0.45 or absf(p.y - cz) > ez * 0.5 - 0.45:
				continue
			var near := false
			for q in _light_xz:
				if q.distance_to(p) < 0.95:
					near = true
					break
			if near:
				continue
			var at := Transform3D(Basis.IDENTITY, Vector3(p.x, y, p.y))
			var kind := k % 4
			if kind == 1 and tile:
				xf_dif.append(at)
			elif kind == 3:
				xf_det.append(at)
				led_x.append(at * Transform3D(Basis.IDENTITY, Vector3(0.028, -0.052, 0.0)))
				led_c.append(Color(fmod(float(led_x.size()) * 0.173 + 0.11 * float(k), 1.0), 0, 0, 0))
			else:
				xf_spr.append(at)
		if not tile and maxf(ex, ez) > 6.0:
			# techo abierto: ramales de rociadores (rojo óxido) y bandejas portacables galvanizadas con sus tirantes
			var pipe := Greybox.material(Color(0.42, 0.09, 0.07), 0.0, 0.55, 0.3)
			var tray := Greybox.material(Color(0.44, 0.46, 0.48), 0.0, 0.45, 0.7)
			var long_x2 := ex >= ez
			var run := maxf(ex, ez) - 0.6
			var rows := int(floor((minf(ex, ez) - 1.0) / 4.8)) + 1
			for r in rows:
				var o := -(rows - 1) * 2.4 + 4.8 * r + 0.6
				var c := Vector3(cx, y - 0.075, cz + o) if long_x2 else Vector3(cx + o, y - 0.075, cz)
				_lot(c).cube(pipe, c, Vector3(run, 0.045, 0.045) if long_x2 else Vector3(0.045, 0.045, run))
				# bandeja: a un lado del ramal, lejos de las luminarias
				var to := o
				for cand in [1.5, 0.95, 2.05, -1.5, -0.95]:
					var lat: float = (cz if long_x2 else cx) + o + float(cand)
					var clear := absf(o + float(cand)) < minf(ex, ez) * 0.5 - 0.4
					for q in _light_xz:
						if absf((q.y if long_x2 else q.x) - lat) < 0.7 and absf(q.x - cx) < ex * 0.5 and absf(q.y - cz) < ez * 0.5:
							clear = false
							break
					if clear:
						to = o + float(cand)
						break
				if to == o:
					continue
				var tc := Vector3(cx, y - 0.22, cz + to) if long_x2 else Vector3(cx + to, y - 0.22, cz)
				var gm := _lot(tc)
				gm.cube(tray, tc, Vector3(run, 0.012, 0.22) if long_x2 else Vector3(0.22, 0.012, run))
				for sgn in [-1.0, 1.0]:
					var e: float = sgn * 0.11
					gm.cube(tray, tc + (Vector3(0, 0.03, e) if long_x2 else Vector3(e, 0.03, 0)), Vector3(run, 0.06, 0.006) if long_x2 else Vector3(0.006, 0.06, run))
				var hn := int(floor(run / 2.4)) + 1
				for hi in hn:
					var ht := -run * 0.5 + 0.3 + (run - 0.6) * float(hi) / float(maxi(hn - 1, 1))
					for sgn2 in [-1.0, 1.0]:
						var e2: float = sgn2 * 0.12
						var hc := tc + (Vector3(ht, 0.11, e2) if long_x2 else Vector3(e2, 0.11, ht))
						_lot(hc).cube(tray, hc, Vector3(0.008, 0.23, 0.008))
	var white := m_white()
	# Difusor de aire de 4 vías (56 cm): marco y tres aros cuadrados.
	var kd := GfxMesh.new()
	for ring in 4:
		var half := 0.28 - 0.062 * ring
		var yy := -0.006 - 0.008 * ring
		var w := 0.03 if ring == 0 else 0.018
		for sgn in [-1.0, 1.0]:
			kd.cube(white, Vector3(0, yy, sgn * (half - w * 0.5)), Vector3(half * 2.0, 0.012, w))
			kd.cube(white, Vector3(sgn * (half - w * 0.5), yy, 0), Vector3(w, 0.012, half * 2.0 - w * 2.0))
	kd.cube(m_keys(), Vector3(0, -0.002, 0), Vector3(0.5, 0.002, 0.5))
	kd.cube(white, Vector3(0, -0.034, 0), Vector3(0.1, 0.01, 0.1))
	_add_mm("Difusores", kd, xf_dif, false)
	# Rociador: escudo, vástago y deflector.
	var ks := GfxMesh.new()
	var chrome := m_chrome()
	ks.cyl(white, Transform3D(Basis.IDENTITY, Vector3(0, -0.003, 0)), 0.04, 0.006, 10)
	ks.cyl(chrome, Transform3D(Basis.IDENTITY, Vector3(0, -0.03, 0)), 0.011, 0.05, 6)
	ks.cyl(chrome, Transform3D(Basis.IDENTITY, Vector3(0, -0.057, 0)), 0.027, 0.004, 10)
	_add_mm("Rociadores", ks, xf_spr, false)
	# Detector de humo.
	var kt := GfxMesh.new()
	kt.cyl(white, Transform3D(Basis.IDENTITY, Vector3(0, -0.011, 0)), 0.062, 0.022, 14)
	kt.cyl(white, Transform3D(Basis.IDENTITY, Vector3(0, -0.036, 0)), 0.044, 0.028, 14, 0.036)
	_add_mm("Detectores", kt, xf_det, false)
	_add_leds("LedDetector", led_x, led_c, Color(0.95, 0.07, 0.04), 4.6)


# --- paredes: guardasillas, tableros de avisos y tomacorrientes ------------------------------------------------

## Sobre las paredes pintadas (no cerámica, mármol ni vidrio), por las dos caras y solo donde no hay ya nada
## colgado o apoyado: una banda guardasillas a 90 cm, tableros de corcho con hojas (sin texto) cada tantos metros
## en las paredes largas, y tomacorrientes. Nada tiene colisión ni sobresale más de 3 cm.
func _walls() -> void:
	var xf_out: Array = []
	var xf_board: Array = [[], []]
	var glass := Greybox.material(Greybox.VIDRIO)
	var band := Greybox.material(Color(0.36, 0.4, 0.43), 0.0, 0.5)
	var joint := Greybox.material(Color(0.17, 0.18, 0.19), 0.0, 0.85)
	var boards := 0
	for mi in _meshes:
		if not (mi.mesh is BoxMesh) or mi.get_node_or_null("Col") == null or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		var thick := minf(s.x, s.z)
		var length := maxf(s.x, s.z)
		if s.y < 2.4 or thick > 0.35 or length < 2.0:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or mat == glass or mat.albedo_color.a < 0.99 or mat.emission_enabled or mat.metallic > 0.2:
			continue
		if not _painted(mat):
			continue
		var xf := _rel(mi)
		if absf((xf.origin.y - s.y * 0.5) - _base_y) > 0.2:
			continue
		var along_x := s.x >= s.z
		var sd := float(absi(str(mi.get_path()).hash()) % 1000) / 1000.0
		for side in [-1.0, 1.0]:
			var sg: float = side
			var b := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
			if sg < 0.0:
				b = b * Basis(Vector3.UP, PI)
			var face := sg * thick * 0.5
			# Banda guardasillas: por módulos de 1,2 m, saltando lo ocupado.
			var mods := int(floor(length / 1.2))
			var mlen := length / float(maxi(mods, 1))
			for i in mods:
				var t := -length * 0.5 + mlen * (float(i) + 0.5)
				var c := Vector3(t, (_base_y + 0.9) - xf.origin.y, face + sg * 0.007) if along_x else Vector3(face + sg * 0.007, (_base_y + 0.9) - xf.origin.y, t)
				var probe := Vector3(t, (_base_y + 0.9) - xf.origin.y, face + sg * 0.16) if along_x else Vector3(face + sg * 0.16, (_base_y + 0.9) - xf.origin.y, t)
				var pw := xf * probe
				var half := Vector3(mlen * 0.5 if _axis_x(xf, along_x) else 0.13, 0.14, 0.13 if _axis_x(xf, along_x) else mlen * 0.5)
				if _occ_hit(AABB(pw - half, half * 2.0)):
					continue
				_lot(pw).box(band, xf * Transform3D(Basis.IDENTITY, c), Vector3(mlen, 0.11, 0.014) if along_x else Vector3(0.014, 0.11, mlen))
			# Juntas de los paneles: una línea fina cada módulo, del zócalo al techo (lo colgado la tapa).
			for i in range(1, mods):
				var tj := -length * 0.5 + mlen * float(i)
				var cj := Vector3(tj, 0.04, face + sg * 0.002) if along_x else Vector3(face + sg * 0.002, 0.04, tj)
				_lot(xf * cj).box(joint, xf * Transform3D(Basis.IDENTITY, cj), Vector3(0.005, s.y - 0.1, 0.003) if along_x else Vector3(0.003, s.y - 0.1, 0.005))
			# Tableros: uno cada ~9 m en paredes de 6 m o más.
			if length >= 6.0 and boards < 14:
				var nb := maxi(int(floor(length / 9.0)), 1)
				for j in nb:
					var t2 := -length * 0.5 + length * (float(j) + 0.5 + (sd - 0.5) * 0.2) / float(nb)
					var cy := (_base_y + 1.52) - xf.origin.y
					var probe2 := xf * (Vector3(t2, cy, face + sg * 0.22) if along_x else Vector3(face + sg * 0.22, cy, t2))
					var h2 := Vector3(0.8 if _axis_x(xf, along_x) else 0.2, 0.62, 0.2 if _axis_x(xf, along_x) else 0.8)
					if _occ_hit(AABB(probe2 - h2, h2 * 2.0)):
						continue
					var c2 := Vector3(t2, cy, face + sg * 0.002) if along_x else Vector3(face + sg * 0.002, cy, t2)
					(xf_board[(boards + int(sd * 10.0)) % 2] as Array).append(xf * Transform3D(b, c2))
					_occ_add(AABB(probe2 - h2, h2 * 2.0))
					boards += 1
			# Tomacorrientes.
			var cnt := int(floor(length / 3.6))
			for i in cnt:
				var t3 := -length * 0.5 + length * (float(i) + 0.3 + 0.4 * fmod(sd + 0.37 * i, 1.0)) / float(cnt)
				var yy := (_base_y + 0.34) - xf.origin.y
				var c3 := Vector3(t3, yy, face + sg * 0.004) if along_x else Vector3(face + sg * 0.004, yy, t3)
				xf_out.append(xf * Transform3D(b, c3))
	# Tomacorriente doble: placa y dos módulos (marco local: frente +z).
	var k := GfxMesh.new()
	k.cube(m_white(), Vector3(0, 0, 0), Vector3(0.08, 0.12, 0.008))
	for sy in [-1.0, 1.0]:
		k.cube(m_keys(), Vector3(0, sy * 0.028, 0.004), Vector3(0.036, 0.036, 0.003))
	_add_mm("Tomacorrientes", k, xf_out, false)
	for v in 2:
		_add_mm("Tableros%d" % v, GfxKits.board(v), xf_board[v], false)


## ¿El eje largo del muro queda sobre el eje X del piso? (Los muros van a 0° o 90°.)
static func _axis_x(xf: Transform3D, along_x: bool) -> bool:
	var d := xf.basis.x if along_x else xf.basis.z
	return absf(d.x) >= absf(d.z)


## ¿Pared pintada o de drywall? (No cerámica, mármol, ladrillo, concreto ni laminados.)
static func _painted(mat: StandardMaterial3D) -> bool:
	if mat.has_meta("q5_tex"):
		var tx: Variant = mat.get_meta("q5_tex")
		return tx is Texture2D and str((tx as Texture2D).resource_path).contains("pared_desgaste")
	return mat.roughness >= 0.85 and mat.albedo_color.v > 0.3


# --- mesas de comedor y de reunión: lo que la gente deja -------------------------------------------------------

func _tables() -> void:
	var xf_t: Array = [[], [], []]
	for mi in _meshes:
		var nm := str(mi.name)
		if not (nm.begins_with("Mesa") or nm.ends_with("Mesa")) or nm.contains("Pata") or nm.contains("Pie") or not mi.is_visible_in_tree():
			continue
		var top := Vector2.ZERO
		var thick := 0.0
		if mi.mesh is BoxMesh:
			var s := (mi.mesh as BoxMesh).size
			top = Vector2(s.x, s.z)
			thick = s.y
		elif mi.mesh is CylinderMesh:
			var cm := mi.mesh as CylinderMesh
			top = Vector2(cm.top_radius * 1.6, cm.top_radius * 1.6)
			thick = cm.height
		else:
			continue
		var xf := _rel(mi)
		var y := xf.origin.y + thick * 0.5
		if thick > 0.12 or y - _base_y < 0.4 or y - _base_y > 1.15 or top.x * top.y < 0.25:
			continue
		var long_x := top.x >= top.y
		var length := maxf(top.x, top.y)
		var spots := 2 if length > 1.7 else 1
		for i in spots:
			var t := 0.0 if spots == 1 else (float(i) - 0.5) * length * 0.5
			var c := xf * Vector3(t if long_x else 0.0, thick * 0.5, 0.0 if long_x else t)
			var half := Vector3(0.3, 0.14, 0.3)
			if _occ_hit(AABB(c + Vector3(0, 0.17, 0) - half, half * 2.0)):
				continue
			var sd := absi((nm + str(i) + str(snappedf(c.x, 0.1))).hash())
			(xf_t[sd % 3] as Array).append(Transform3D(Basis(Vector3.UP, float(sd % 628) * 0.01), c))
	for v in 3:
		_add_mm("Mesas%d" % v, GfxKits.table_set(v), xf_t[v], false)


# --- pizarras ----------------------------------------------------------------------------------------------------

## Pizarras blancas: marco de aluminio (si no lo trae), lámina brillante que devuelve la luz, bandeja con plumones y
## borrador. Por las dos caras (la que da a la pared queda tapada). Sin colisión; no sobresale más de 7 cm.
func _whiteboards() -> void:
	var alu := m_alu()
	var sheet := Greybox.material(Color(0.93, 0.94, 0.94), 0.0, 0.16)
	if not sheet.has_meta("gfx_m"):
		sheet.set_meta("gfx_m", "propio")
		sheet.metallic_specular = 0.7
	var pens: Array = [Greybox.material(Color(0.05, 0.05, 0.06), 0.0, 0.45), Greybox.material(Color(0.1, 0.2, 0.6), 0.0, 0.45), Greybox.material(Color(0.6, 0.08, 0.08), 0.0, 0.45)]
	var felt := Greybox.material(Color(0.2, 0.22, 0.3), 0.0, 1.0)
	for mi in _meshes:
		var nm := str(mi.name)
		if not nm.begins_with("Pizarra") or nm.contains(FRAME_SUFFIX) or not (mi.mesh is BoxMesh) or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		var along_x := s.x >= s.z
		var w := s.x if along_x else s.z
		var th := s.z if along_x else s.x
		if th > 0.08 or w < 0.8 or s.y < 0.5:
			continue
		var xf := _rel(mi)
		var gm := _lot(xf.origin)
		var framed := mi.get_parent().get_node_or_null(nm + FRAME_SUFFIX) != null
		if not framed:
			for sy in [-1.0, 1.0]:
				gm.box(alu, xf * Transform3D(Basis.IDENTITY, Vector3(0, sy * (s.y * 0.5 + 0.01), 0)), Vector3(w + 0.04, 0.022, th + 0.014) if along_x else Vector3(th + 0.014, 0.022, w + 0.04))
			for su in [-1.0, 1.0]:
				var cu: float = su * (w * 0.5 + 0.01)
				gm.box(alu, xf * Transform3D(Basis.IDENTITY, Vector3(cu, 0, 0) if along_x else Vector3(0, 0, cu)), Vector3(0.022, s.y, th + 0.014) if along_x else Vector3(th + 0.014, s.y, 0.022))
		var lay := Basis(Vector3(0, 0, 1), PI * 0.5) if along_x else Basis(Vector3(1, 0, 0), PI * 0.5)   # cilindro acostado a lo largo
		for side in [-1.0, 1.0]:
			var sg: float = side
			var face := sg * th * 0.5
			# lámina brillante
			var cs := Vector3(0, 0, face + sg * 0.002) if along_x else Vector3(face + sg * 0.002, 0, 0)
			gm.box(sheet, xf * Transform3D(Basis.IDENTITY, cs), Vector3(w - 0.02, s.y - 0.02, 0.002) if along_x else Vector3(0.002, s.y - 0.02, w - 0.02))
			# bandeja
			var ty := -s.y * 0.5 - 0.012
			var tn := face + sg * 0.032
			gm.box(alu, xf * Transform3D(Basis.IDENTITY, Vector3(0, ty, tn) if along_x else Vector3(tn, ty, 0)), Vector3(w * 0.55, 0.012, 0.064) if along_x else Vector3(0.064, 0.012, w * 0.55))
			for i in 3:
				var tu := -w * 0.16 + 0.17 * float(i)
				var cp := Vector3(tu, ty + 0.015, tn) if along_x else Vector3(tn, ty + 0.015, tu)
				gm.cyl(pens[i], xf * Transform3D(lay, cp), 0.008, 0.13, 8)
			var ce := Vector3(w * 0.2, ty + 0.021, tn) if along_x else Vector3(tn, ty + 0.021, w * 0.2)
			gm.box(felt, xf * Transform3D(Basis.IDENTITY, ce), Vector3(0.11, 0.03, 0.045) if along_x else Vector3(0.045, 0.03, 0.11))


# --- puertas -----------------------------------------------------------------------------------------------------

func _doors() -> void:
	var frame := m_frame()
	var chrome := m_chrome()
	var handle := GfxMesh.new()
	for sz in [-1.0, 1.0]:
		handle.cube(chrome, Vector3(0.36, 0.0, sz * 0.05), Vector3(0.13, 0.02, 0.02))
		handle.cyl(chrome, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.415, 0.0, sz * 0.038)), 0.022, 0.012, 10)
	var handle_mesh := handle.commit()
	for n in floor_node.find_children("*", "", true, false):
		if not (n is WorldObjects.Door):
			continue
		var d := n as WorldObjects.Door
		if d.leaf == null or not (d.leaf.mesh is BoxMesh):
			continue
		var s := (d.leaf.mesh as BoxMesh).size
		if s.x < 0.6 or s.y < 1.8:
			continue
		var xf := _rel(d.leaf)
		var gm := _lot(xf.origin)
		for sx in [-1.0, 1.0]:
			gm.box(frame, xf * Transform3D(Basis.IDENTITY, Vector3(sx * (s.x * 0.5 + 0.028), 0.02, 0)), Vector3(0.05, s.y + 0.06, 0.24))
		gm.box(frame, xf * Transform3D(Basis.IDENTITY, Vector3(0, s.y * 0.5 + 0.028, 0)), Vector3(s.x + 0.11, 0.05, 0.24))
		# manija: hija de la hoja (se oculta con ella al abrir). Con la animación de objetos activa la hoja ya lleva
		# la suya («Manija», de palanca: baja al abrir y gira con la copia batiente); otra encima se veía doble.
		if ObjectAnim.on():
			# Misma condición que el censo de objetos (cerrada y sin barra antipánico): así el piso queda igual que si
			# este pase no hubiera corrido (Baja → Alta → Baja no deja manijas de más). El censo puede llegar después.
			if not d.open and d.get_node_or_null("Barra") == null:
				ObjectAnim.ensure_handle(d.leaf)
			if d.leaf.get_node_or_null("Manija") != null:
				continue
		var h := MeshInstance3D.new()
		h.name = "GfxManija"
		h.mesh = handle_mesh
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.set_meta("no_merge", true)
		h.set_meta("gfx_fx", "detalle")
		d.leaf.add_child(h)
		_loose.append(h)
		_draws += 1


# --- estado ------------------------------------------------------------------------------------------------------

## Luces de emergencia: `k` 0..1 (lo lleva GfxLights con fundido).
func set_emergency(k: float) -> void:
	if _em_mat != null:
		_em_mat.emission_energy_multiplier = 5.0 * k
	for sp in _em_spots:
		if is_instance_valid(sp):
			sp.visible = k > 0.01
			sp.light_energy = 3.2 * k


func set_flicker(f: float) -> void:
	for m in _led_mats:
		m.set_shader_parameter("flicker_amount", f)
	for m2 in [_screen_mat, _glow_mat, _bust_mat]:
		if m2 != null:
			(m2 as ShaderMaterial).set_shader_parameter("flicker_amount", f)

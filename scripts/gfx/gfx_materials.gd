class_name GfxMaterials
extends RefCounted
## v0.3.2 gfx · Superficies en Media/Alta: mapas de relieve y de rugosidad propios (tools/v032_gfx_texturas.py →
## assets/textures/gfx/) sobre los materiales que ya usa el mundo, sin crear materiales nuevos ni tocar las mallas.
##
##   · Greybox.surf(…) (20 superficies con textura triplanar de mundo): relieve + rugosidad que calzan con su albedo.
##   · Greybox.material(…) (colores planos): según lo que sea —metal, tela, plástico, pintura, vidrio— un detalle
##     genérico en triplanar local (no «nada» cuando el objeto se mueve: puertas, sillas).
##   · Vidrio: casi espejo, con huellas a la altura de las manos, pasadas de trapo y polvo junto al zócalo.
##   · Emisivos de práctica (monitores de relleno, carteles de salida): un poco más de energía para que el resplandor
##     los tome.
## Todo queda anotado en metadatos del propio material y se deshace entero al pasar a Baja o a Modo liviano; el Modo
## liviano además aplana los materiales (Greybox.set_flat_materials) como siempre. Si los PNG no están en el build
## (el HTML los excluye), no pasa nada: el material queda como en Baja.

const DIR := "res://assets/textures/gfx/"
## Fuerza del relieve por superficie (1 = como sale del generador).
const NORMAL_SCALE: Dictionary = {
	"porcelanato_negro": 0.9, "marmol": 0.8, "baldosa_techo": 1.0, "reticula": 1.0, "vinilico_calido": 0.9,
	"vinilico_claro": 0.9, "vinilico_pasillo": 0.9, "ceramica_blanca": 1.0, "porcelanato_gris": 1.0, "granito": 0.8,
	"concreto": 1.0, "vereda": 1.0, "alfombra_azul": 1.0, "ladrillo_blanco": 1.0, "sala_gris": 1.0, "roble": 0.9,
	"pared": 0.4, "persiana": 0.8, "felpudo": 1.0, "concreto_escalera": 1.0,
}
## Rugosidad por superficie respecto de la que trae (1 = igual). El tablero de los escritorios es melamina
## semibrillante: devuelve la luz de los monitores.
const ROUGH_SCALE: Dictionary = {"roble": 0.6, "sala_gris": 0.8, "porcelanato_gris": 0.85}
## Detalles genéricos: nombre → tamaño de mundo de la baldosa (m).
const DETAIL_SIZE: Dictionary = {"tela": 0.16, "metal": 0.4, "plastico": 0.12, "pintura": 0.5}
## Emisivos de práctica: clave de Greybox.material → energía en Media/Alta.
const EMISSIVE_BOOST: Array = [
	[Color(0.1, 0.12, 0.2), 0.3, 0.9, Color(0.20, 0.30, 0.52), true],     # monitores de relleno de los cubículos
	[Color(0.06, 0.32, 0.16), 1.2, 1.7, Color(0.06, 0.42, 0.2), false],   # cartel SALIDA
]

## Valor mínimo (sRGB) del color de un plástico oscuro en Media/Alta.
const MIN_PLASTIC_V := 0.2

static var _tex: Dictionary = {}
static var _applied: bool = false
static var _was_recuerdo: bool = false
static var _seen_surf: int = -1
static var _seen_flat: int = -1
static var stats: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var p := DIR + name + ".png"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[name] = t
	return t


## ¿Están los mapas en este build? (El HTML no los lleva.)
static func available() -> bool:
	return tex("pared_n") != null


static func apply() -> void:
	var want := GfxSettings.enhanced() and GfxSettings.on("materiales") and not GfxQuality.is_light() and available()
	if not want:
		if _applied:
			restore()
		return
	_applied = true
	if Flashback.active != _was_recuerdo:
		# Al entrar o salir del recuerdo cambia lo que se viste (vidrios limpios): se parte de cero.
		_was_recuerdo = Flashback.active
		for k in Greybox._materials.keys():
			var gm := Greybox._materials[k] as StandardMaterial3D
			if gm != null and str(gm.get_meta("gfx_m", "")) == "vidrio":
				_undress(gm)
	var n_surf := 0
	var n_flat := 0
	for k in Greybox._surf.keys():
		if _dress_surf(str(k), Greybox._surf[k] as StandardMaterial3D):
			n_surf += 1
	for k in Greybox._materials.keys():
		if _dress_flat(Greybox._materials[k] as StandardMaterial3D):
			n_flat += 1
	_seen_surf = Greybox._surf.size()
	_seen_flat = Greybox._materials.size()
	_boost_emissives(true)
	stats = {"superficies": n_surf, "planos": n_flat}


## Materiales creados después del último pase (los pisos los piden al armarse y en caliente).
static func refresh_if_new() -> void:
	if _applied and (Greybox._surf.size() != _seen_surf or Greybox._materials.size() != _seen_flat):
		apply()
		# Un material recién vestido puede estar ya puesto en un nodo chico que se miró antes: se vuelve a mirar todo.
		_plain_seen.clear()
		plain_dirty = true


static func restore() -> void:
	plain_restore()
	for k in Greybox._surf.keys():
		_undress(Greybox._surf[k] as StandardMaterial3D)
	for k in Greybox._materials.keys():
		_undress(Greybox._materials[k] as StandardMaterial3D)
	_boost_emissives(false)
	_applied = false
	_seen_surf = -1
	_seen_flat = -1
	stats = {}


static func _kind_of(key: String) -> String:
	var best := ""
	for k in Greybox.SURF.keys():
		var ks := str(k)
		if key.begins_with(ks + "_") and ks.length() > best.length():
			best = ks
	return best


static func _dress_surf(key: String, m: StandardMaterial3D) -> bool:
	if m == null or m.has_meta("gfx_m"):
		return m != null
	var kind := _kind_of(key)
	if kind == "":
		return false
	var n := tex(kind + "_n")
	var r := tex(kind + "_r")
	if n == null or r == null:
		return false
	var cfg: Array = Greybox.SURF[kind]
	m.set_meta("gfx_m", "surf")
	m.set_meta("gfx_r0", m.roughness)
	m.normal_enabled = true
	m.normal_texture = n
	m.normal_scale = float(NORMAL_SCALE.get(kind, 1.0))
	m.roughness_texture = r
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	# La textura lleva la rugosidad absoluta; si quien pidió el material fijó otra, se conserva la proporción.
	m.roughness = clampf(m.roughness / maxf(float(cfg[3]), 0.01) * float(ROUGH_SCALE.get(kind, 1.0)), 0.25, 1.6)
	return true


static func _dress_flat(m: StandardMaterial3D) -> bool:
	if m == null:
		return false
	if m.has_meta("gfx_m"):
		return true
	if m.albedo_texture != null or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	if m.emission_enabled and m.emission_energy_multiplier >= 0.25:
		return false  # tubos, pantallas, LEDs: no llevan relieve
	var c := m.albedo_color
	if c.a < 0.999:
		if c.a <= 0.45 and m.roughness >= 0.5 and not Flashback.active:
			return _dress_glass(m)  # en el recuerdo (la torre nueva) el vidrio está limpio
		return false
	var detail := ""
	if m.metallic >= 0.4:
		detail = "metal"
	elif m.roughness >= 0.95:
		detail = "tela"
	elif m.roughness <= 0.4:
		return false  # ya es liso y brillante (cerámica, laca): se queda
	elif c.v < 0.2:
		detail = "plastico"
	else:
		detail = "pintura"
	var n := tex(detail + "_n")
	var r := tex(detail + "_r")
	if n == null or r == null:
		return false
	m.set_meta("gfx_m", detail)
	m.set_meta("gfx_r0", m.roughness)
	m.set_meta("gfx_tri0", [m.uv1_triplanar, m.uv1_world_triplanar, m.uv1_scale])
	var mean: float = {"tela": 0.91, "metal": 0.30, "plastico": 0.52, "pintura": 0.78}[detail]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	var sc := 1.0 / float(DETAIL_SIZE[detail])
	m.uv1_scale = Vector3(sc, sc, sc)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled = true
	m.normal_texture = n
	m.normal_scale = float({"tela": 0.9, "metal": 0.25, "plastico": 0.3, "pintura": 0.6}[detail])
	# Plásticos casi negros (sillas, marcos, teclados): ningún plástico real refleja menos de un 2–3 %. Con la luz de
	# terror un negro de 1 % es un recorte sin forma; se sube lo justo para que tome luz. Los negros mate (techos,
	# fondos) no se tocan.
	if detail == "plastico" and m.roughness <= 0.82 and c.v < MIN_PLASTIC_V:
		m.set_meta("gfx_alb0", c)
		m.albedo_color = Color.from_hsv(c.h, c.s, MIN_PLASTIC_V, c.a)
	m.roughness_texture = r
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = clampf(m.roughness / mean, 0.4, 1.8)
	return true


## Vidrio de mamparas y puertas: liso, con la suciedad que deja la gente.
static func _dress_glass(m: StandardMaterial3D) -> bool:
	var dirt := tex("vidrio_suciedad")
	var r := tex("vidrio_r")
	if dirt == null or r == null:
		return false
	m.set_meta("gfx_m", "vidrio")
	m.set_meta("gfx_r0", m.roughness)
	m.set_meta("gfx_tri0", [m.uv1_triplanar, m.uv1_world_triplanar, m.uv1_scale])
	m.set_meta("gfx_glass0", [m.albedo_color, m.metallic_specular, m.cull_mode])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_texture = dirt
	var c := m.albedo_color
	m.albedo_color = Color(c.r, c.g, c.b, minf(c.a * 1.15, 0.5))
	m.roughness_texture = r
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = 1.0
	m.metallic_specular = 0.7
	return true


static func _undress(m: StandardMaterial3D) -> void:
	if m == null or not m.has_meta("gfx_m"):
		return
	var kind := str(m.get_meta("gfx_m"))
	if kind == "propio":
		return  # material de la capa de detalle que no se viste (franja esmerilada, ropa de las siluetas…)
	m.normal_enabled = false
	m.normal_texture = null
	m.normal_scale = 1.0
	m.roughness_texture = null
	m.roughness = float(m.get_meta("gfx_r0", m.roughness))
	if m.has_meta("gfx_tri0"):
		var t: Array = m.get_meta("gfx_tri0")
		m.uv1_triplanar = bool(t[0])
		m.uv1_world_triplanar = bool(t[1])
		m.uv1_scale = t[2]
		m.remove_meta("gfx_tri0")
	if kind == "vidrio" and m.has_meta("gfx_glass0"):
		var g: Array = m.get_meta("gfx_glass0")
		m.albedo_texture = null
		m.albedo_color = g[0]
		m.metallic_specular = float(g[1])
		m.remove_meta("gfx_glass0")
	if m.has_meta("gfx_alb0"):
		m.albedo_color = m.get_meta("gfx_alb0")
		m.remove_meta("gfx_alb0")
	m.remove_meta("gfx_m")
	m.remove_meta("gfx_r0")


static func _boost_emissives(on: bool) -> void:
	for e in EMISSIVE_BOOST:
		var key := "%s_%0.2f_%0.2f_%0.2f" % [(e[0] as Color).to_html(), float(e[1]), 0.9, 0.0]
		if not Greybox._materials.has(key):
			continue
		var m := Greybox._materials[key] as StandardMaterial3D
		# Con la capa de detalle los monitores de relleno llevan su pantalla: la caja no necesita brillar más.
		var screens := bool(e[4]) and GfxSettings.level("detalle") >= 1
		if on and GfxSettings.on("luz_terror") and not screens:
			m.emission_energy_multiplier = float(e[2])
			m.emission = e[3]
		else:
			m.emission_energy_multiplier = float(e[1])
			m.emission = e[0]


# --- objetos chicos y con texto: sin relieve genérico (v0.3.2-final) -------------------------------------------------
## Los detalles genéricos (pintura, metal, plástico, tela) viven en los materiales COMPARTIDOS de Greybox: la misma
## «pintura» de una pared de 30 m la lleva un pósit, la taza de C-13 o una llave. De lejos da grano; a 40 cm, sobre una
## cara de 10 cm, el mapa de relieve se ve a tamaño de píxel: rayas de camuflaje que ensucian lo que el jugador lee o
## tiene en la mano. Regla: lo que mide menos de 30 cm, lo que lleva texto (un Label3D encima) y el papel en general
## no llevan relieve genérico. No se toca el material compartido: a ese nodo se le pone un gemelo liso (mismo color,
## misma rugosidad de fábrica, sin mapas) y al volver a Baja o a Modo liviano se le devuelve el suyo.
const GENERIC: Array = ["tela", "metal", "plastico", "pintura"]
const SMALL_SIDE := 0.30   # m: por debajo, sin relieve
const TEXT_SIDE := 1.2     # m: un objeto con texto encima hasta este tamaño…
const BOARD_THICK := 0.08  # …o más grande si es una lámina (cartel, pizarra, letrero): grosor máximo
const BOARD_SIDE := 4.0
## Cosas de papel o que se leen aunque el texto vaya en otro nodo (prefijo del nombre del nodo).
const PLAIN_NAMES: PackedStringArray = ["Nota", "Papel", "Posit", "Sticker", "Etiqueta", "Foto", "Polaroid", "Contrato", "Mural", "Cinta", "Llave", "Mochila", "Taper", "Pizarra", "Fotocheck", "Cartel", "Letrero", "Placa", "Carta", "Afiche", "Aviso", "Cuaderno", "Libreta", "Sobre", "HojaA", "HojaColgando", "Volante", "Recibo", "Tarjeta"]

static var _twins: Dictionary = {}       # id del material vestido → gemelo liso
static var _plain_log: Array = []        # [WeakRef del nodo, superficie (−1 = material_override), material anterior, gemelo]
static var _plain_seen: Dictionary = {}  # id del nodo → true (ya se miró y quedó como debía)
static var _plain_queue: Array = []      # WeakRef de nodos nuevos por mirar
static var _plain_tree: SceneTree = null
static var plain_count: int = 0
static var plain_dirty: bool = false     # hay materiales vestidos después del último pase: el director vuelve a pasar


## ¿Este material lleva un relieve genérico del paquete?
static func is_generic(m: Material) -> bool:
	return m != null and m.has_meta("gfx_m") and GENERIC.has(str(m.get_meta("gfx_m")))


## ¿Alguna superficie visible de la malla lleva relieve genérico? (Lo usa la prueba fin_objetos_lisos.)
static func has_relief(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	for i in mi.mesh.get_surface_count():
		if is_generic(mi.get_active_material(i)):
			return true
	return false


static func _twin(m: StandardMaterial3D) -> StandardMaterial3D:
	var id := m.get_instance_id()
	if _twins.has(id):
		return _twins[id]
	var t := m.duplicate() as StandardMaterial3D
	t.normal_enabled = false
	t.normal_texture = null
	t.normal_scale = 1.0
	t.roughness_texture = null
	t.roughness = float(m.get_meta("gfx_r0", m.roughness))
	if m.has_meta("gfx_tri0"):
		var tri: Array = m.get_meta("gfx_tri0")
		t.uv1_triplanar = bool(tri[0])
		t.uv1_world_triplanar = bool(tri[1])
		t.uv1_scale = tri[2]
	for k in ["gfx_r0", "gfx_tri0", "gfx_alb0"]:  # (el color de un plástico oscuro aclarado se queda aclarado)
		if t.has_meta(k):
			t.remove_meta(k)
	t.set_meta("gfx_m", "propio")
	t.set_meta("gfx_liso", true)
	_twins[id] = t
	return t


static func _world_size(mi: MeshInstance3D) -> Vector3:
	var sz := mi.mesh.get_aabb().size
	return sz * mi.global_transform.basis.get_scale().abs() if mi.is_inside_tree() else sz


## ¿A este nodo le toca ir liso? (tamaño, nombre o texto encima)
static func wants_plain(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	var sz := _world_size(mi)
	var big := maxf(sz.x, maxf(sz.y, sz.z))
	var thin := minf(sz.x, minf(sz.y, sz.z))
	if big <= SMALL_SIDE + 0.005:
		return true
	var nm := str(mi.name)
	for pre in PLAIN_NAMES:
		if nm.begins_with(pre):
			# «Papel», «Papel_2», «PapelA4» sí; «Papelera» no (la palabra sigue en minúscula: es otra cosa)
			var rest := nm.substr(pre.length(), 1)
			if rest == "" or rest != rest.to_lower() or not ((rest >= "a" and rest <= "z") or rest == "ñ"):
				return true
	var board := big < TEXT_SIDE or (thin <= BOARD_THICK and big <= BOARD_SIDE)
	if not board:
		return false
	# texto colgado del propio nodo…
	for c in mi.get_children():
		if c is Label3D:
			return true
		for c2 in c.get_children():
			if c2 is Label3D:
				return true
	# …o hermano que cae sobre él (la etiqueta de una caja, el número de un botón)
	var par := mi.get_parent()
	if par != null:
		var labels: Array = _labels_of(par)
		if not labels.is_empty():
			var box := mi.mesh.get_aabb().grow(0.04)
			var inv := mi.transform.affine_inverse()
			for lp in labels:
				if box.has_point(inv * (lp as Vector3)):
					return true
	return false


## Posiciones (locales al padre) de los Label3D hijos directos de `par`. Con memoria por pase: un piso cuelga miles de
## nodos de la misma raíz y preguntarlo por cada malla era cuadrático.
static var _label_memo: Dictionary = {}

static func _labels_of(par: Node) -> Array:
	var id := par.get_instance_id()
	if _label_memo.has(id):
		return _label_memo[id]
	var out: Array = []
	for c in par.get_children():
		if c is Label3D:
			out.append((c as Label3D).position)
	_label_memo[id] = out
	return out


## Pone el gemelo liso en las superficies con relieve genérico de `mi`. Devuelve cuántas cambió.
static func _make_plain(mi: MeshInstance3D) -> int:
	var n := 0
	var ov := mi.material_override as StandardMaterial3D
	if ov != null:
		if is_generic(ov):
			var t := _twin(ov)
			_plain_log.append([weakref(mi), -1, ov, t])
			mi.material_override = t
			n += 1
		return n
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i) as StandardMaterial3D
		if not is_generic(m):
			continue
		var t2 := _twin(m)
		_plain_log.append([weakref(mi), i, mi.get_surface_override_material(i), t2])
		mi.set_surface_override_material(i, t2)
		n += 1
	return n


static func _plain_node(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null or mi.is_queued_for_deletion():
		return
	var id := mi.get_instance_id()
	if _plain_seen.has(id):
		return
	if has_relief(mi) and wants_plain(mi):
		if _make_plain(mi) > 0:
			plain_count += 1
	_plain_seen[id] = true


## Pasa por todas las mallas de `root` (el piso recién vestido). Los nodos que lleguen después entran por la cola.
static func plain_scan(root: Node) -> int:
	if not _applied or root == null or not is_instance_valid(root):
		return 0
	var before := plain_count
	_label_memo.clear()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		_plain_node(n as MeshInstance3D)
	_label_memo.clear()
	var tree := root.get_tree() if root.is_inside_tree() else null
	if tree != null and _plain_tree == null:
		_plain_tree = tree
		tree.node_added.connect(_on_node_added)
	stats["lisos"] = plain_count
	return plain_count - before


static func _on_node_added(n: Node) -> void:
	if not _applied:
		return
	if n is MeshInstance3D or n is Label3D:
		_plain_queue.append(weakref(n))


## Pase lento: lo que apareció desde el último (una nota nueva, la mochila y la llave en la mano, un prop de una
## muerte). El material y el tamaño se asignan después de entrar al árbol: por eso se mira aquí y no al entrar.
static func plain_tick() -> void:
	if not _applied or _plain_queue.is_empty():
		return
	var q := _plain_queue
	_plain_queue = []
	_label_memo.clear()
	var budget := 600  # evaluaciones de verdad por pase (lo ya mirado por plain_scan no cuenta: al cambiar de piso llegan miles)
	for w in q:
		if budget <= 0:
			_plain_queue.append(w)
			continue
		var n := (w as WeakRef).get_ref() as Node
		if n == null or not n.is_inside_tree():
			continue
		if n is Label3D:
			# Un texto nuevo: su soporte (el padre, o un hermano sobre el que cae) pasa a ser «lo que se lee». Solo en
			# grupos chicos: los textos que cuelgan de la raíz de un piso llegan al armarlo y los cubre plain_scan.
			var par := n.get_parent()
			if par is MeshInstance3D and has_relief(par as MeshInstance3D):
				budget -= 1
				_plain_seen.erase(par.get_instance_id())
				_plain_node(par as MeshInstance3D)
			if par != null and par.get_child_count() <= 48:
				for c in par.get_children():
					if c is MeshInstance3D and has_relief(c as MeshInstance3D):
						budget -= 1
						_plain_seen.erase(c.get_instance_id())
						_plain_node(c as MeshInstance3D)
		elif not _plain_seen.has(n.get_instance_id()):
			budget -= 1
			_plain_node(n as MeshInstance3D)
	_label_memo.clear()
	stats["lisos"] = plain_count


static func plain_restore() -> void:
	for e in _plain_log:
		var mi := (e[0] as WeakRef).get_ref() as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		if int(e[1]) < 0:
			if mi.material_override == e[3]:
				mi.material_override = e[2]
		elif mi.mesh != null and int(e[1]) < mi.mesh.get_surface_count() and mi.get_surface_override_material(int(e[1])) == e[3]:
			mi.set_surface_override_material(int(e[1]), e[2])
	_plain_log.clear()
	_plain_seen.clear()
	_plain_queue.clear()
	_twins.clear()
	plain_count = 0
	if _plain_tree != null:
		if is_instance_valid(_plain_tree) and _plain_tree.node_added.is_connected(_on_node_added):
			_plain_tree.node_added.disconnect(_on_node_added)
		_plain_tree = null


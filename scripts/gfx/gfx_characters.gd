class_name GfxCharacters
extends RefCounted
## v0.3.2 gfx · Sombreado de personajes en Alta (opción «Sombreado de piel, ojos y tela»; Media no lo trae).
##
## Los modelos (assets/models/*.glb, CharacterRig) traen un material por zona: <slug>_cara (cabeza en alta),
## <slug>_cuerpo (piel y ropa en un atlas), <slug>_pelo y <slug>_brillo (ojos, lentes, lo que brilla). Aquí NO se
## cambian texturas, mallas ni shaders: solo propiedades del propio material, anotadas para devolverlas:
##   · cara y cuerpo: luz de contorno (rim) —el filo que deja un tubo o una pantalla detrás del personaje y lo
##     despega del fondo oscuro—; en Forward+, además, dispersión bajo la piel en la cara (la luz no corta en seco);
##   · pelo: contorno más marcado y algo de brillo;
##   · brillo (ojos, lentes): casi espejo, con capa clara: el punto de luz en el ojo que hace que te miren.
## Los materiales con shader propio (la cara deformable de los screamers, fx/…, de otro paquete) no se tocan: quien
## los escribe decide su aspecto; para ellos están los ganchos GfxLens.kick() y GfxDirector.blackout()/emergency().
##
## Además, cada modelo lleva bajo los pies una sombra de contacto falsa (una mancha suave, gfx_sombra.gdshader):
## sin ella, un personaje iluminado por un tubo sin sombra parece pegado sobre el suelo. Solo se dibuja mientras el
## modelo está a ras del piso (no en una escalera, ni levantado por una animación de muerte).
##
## Uso desde otros paquetes (opcional): GfxCharacters.dress(nodo) viste ya mismo los materiales de un modelo recién
## creado (si no, el pase lento los encuentra en menos de un segundo). No hace nada en Baja/liviano/Media.

const PROPS: Array[String] = ["rim_enabled", "rim", "rim_tint", "roughness", "metallic_specular", "clearcoat_enabled",
	"clearcoat", "clearcoat_roughness", "subsurf_scatter_enabled", "subsurf_scatter_strength", "subsurf_scatter_skin_mode",
	"texture_filter"]

const SHADOW_SHADER := "res://assets/shaders/gfx_sombra.gdshader"
const BLOB_NAME := "GfxSombra"
## Modelos sin sombra de contacto: lo que no es de carne (Vitzo es una interferencia de pantalla).
const NO_BLOB: Array[String] = ["vitzo"]

static var _saved: Dictionary = {}   # id del material → {propiedad: valor original}
static var _seen: Dictionary = {}    # id del rig → true
static var _blobs: Array = []        # sombras de contacto (MeshInstance3D hijas de cada rig)
static var _blob_mesh: Mesh = null
static var active: bool = false
static var stats: Dictionary = {}


static func wanted() -> bool:
	return GfxSettings.enhanced() and GfxSettings.on("personajes")


## Pase lento: viste los modelos nuevos; si la opción está apagada, devuelve todo.
static func tick(tree: SceneTree) -> void:
	if not wanted():
		if active:
			restore()
		return
	active = true
	for n in tree.root.find_children("Rig_*", "CharacterRig", true, false):
		var id := n.get_instance_id()
		if _seen.has(id):
			continue
		_seen[id] = true
		dress(n)
		_add_blob(n as Node3D)
	stats = {"modelos": _seen.size(), "materiales": _saved.size(), "sombras": _blobs.size()}


## Mancha de sombra bajo un modelo (hija suya: lo sigue sola).
static func _add_blob(rig: Node3D) -> void:
	if rig == null or rig.get_node_or_null(BLOB_NAME) != null or not ResourceLoader.exists(SHADOW_SHADER):
		return
	if rig is CharacterRig and (rig as CharacterRig).model_name in NO_BLOB:
		return
	if _blob_mesh == null:
		var m := ShaderMaterial.new()
		m.shader = load(SHADOW_SHADER) as Shader
		m.set_shader_parameter("alpha", 0.46)
		var q := QuadMesh.new()
		q.size = Vector2(0.95, 0.95)
		q.orientation = PlaneMesh.FACE_Y
		q.material = m
		_blob_mesh = q
	var mi := MeshInstance3D.new()
	mi.name = BLOB_NAME
	mi.mesh = _blob_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("gfx_fx", "detalle")
	mi.set_meta("no_merge", true)
	mi.position = Vector3(0, 0.012, 0)
	mi.visible = false
	rig.add_child(mi)
	_blobs.append(mi)


## Por cuadro (lo llama el director): la mancha solo se ve con el modelo a ras del suelo del piso y visible.
static func frame(floor_y: float) -> void:
	if _blobs.is_empty():
		return
	var i := _blobs.size() - 1
	while i >= 0:
		var b: Variant = _blobs[i]
		if not is_instance_valid(b):
			_blobs.remove_at(i)
		else:
			var mi := b as MeshInstance3D
			var want := absf(mi.global_position.y - 0.012 - floor_y) < 0.1
			if mi.visible != want:
				mi.visible = want
		i -= 1


static func dress(root: Node) -> int:
	if not wanted() or root == null:
		return 0
	var n := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null or _saved.has(mat.get_instance_id()):
				continue
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			_dress_material(mat)
			n += 1
	return n


static func _dress_material(mat: BaseMaterial3D) -> void:
	var keep: Dictionary = {}
	for p in PROPS:
		keep[p] = mat.get(p)
	_saved[mat.get_instance_id()] = keep
	var nm := mat.resource_name.to_lower()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if nm.ends_with("_brillo") or nm == "eye" or nm == "glass":
		mat.roughness = minf(mat.roughness, 0.1)
		mat.metallic_specular = 0.9
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.7
		mat.clearcoat_roughness = 0.08
	elif nm.ends_with("_pelo") or nm == "hair":
		mat.rim_enabled = true
		mat.rim = 0.35
		mat.rim_tint = 0.25
		mat.roughness = clampf(mat.roughness, 0.45, 0.62)
	else:
		mat.rim_enabled = true
		mat.rim = 0.22
		mat.rim_tint = 0.4
		if (nm.ends_with("_cara") or nm == "skin") and GfxSettings.forward():
			mat.subsurf_scatter_enabled = true
			mat.subsurf_scatter_strength = 0.16
			mat.subsurf_scatter_skin_mode = true


static func restore() -> void:
	for id in _saved.keys():
		var mat := instance_from_id(int(id)) as BaseMaterial3D
		if mat == null:
			continue
		var keep: Dictionary = _saved[id]
		for p in keep.keys():
			mat.set(p, keep[p])
	_saved.clear()
	_seen.clear()
	for b in _blobs:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_blobs.clear()
	active = false
	stats = {}

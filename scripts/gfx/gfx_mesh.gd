class_name GfxMesh
extends RefCounted
## v0.3.2 gfx · Acumulador de geometría para la capa de detalle (GfxDetail): junta cajas y cilindros por material en
## un solo ArrayMesh (una superficie por material), sin colisión. Sirve para dos cosas:
##   · «kit»: una pieza repetida (luminaria, cubículo, monitor…) que luego se dibuja con MultiMesh (1 dibujo por
##     material para TODAS las copias);
##   · «lote»: piezas únicas de una zona del piso (marcos, montantes, zócalos) fundidas por material.
## Caras planas con su normal; las UV no importan (los materiales del mundo van en triplanar).

var _tools: Dictionary = {}      # Material → SurfaceTool
var _order: Array[Material] = []
var boxes: int = 0
var tris: int = 0
## Para shaders propios: UV y color de vértice que llevan las piezas que se agreguen a continuación (cajas y
## cilindros). `with_colors` se fija ANTES de la primera pieza (todas las superficies llevan color o ninguna).
var uv: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE
var with_colors: bool = false

const _FACES: Array = [
	# normal, y los 4 vértices (signos x, y, z) en orden antihorario visto desde fuera
	[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
	[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
	[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
	[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
]


func _st(mat: Material) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
		_order.append(mat)
	return _tools[mat]


func is_empty() -> bool:
	return _order.is_empty()


## Caja de tamaño `size` centrada en `xf.origin`, orientada por `xf.basis`.
func box(mat: Material, xf: Transform3D, size: Vector3) -> void:
	var st := _st(mat)
	var h := size * 0.5
	for f in _FACES:
		var n: Vector3 = (xf.basis * (f[0] as Vector3)).normalized()
		var v: Array = f[1]
		var p: Array[Vector3] = []
		for c in v:
			p.append(xf * ((c as Vector3) * h))
		# El motor toma como cara frontal la de sentido horario: se emiten al revés del antihorario.
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uv)
			if with_colors:
				st.set_color(color)
			st.add_vertex(p[i])
	boxes += 1
	tris += 12


## Atajo: caja alineada a los ejes del acumulador (pos = centro).
func cube(mat: Material, pos: Vector3, size: Vector3) -> void:
	box(mat, Transform3D(Basis.IDENTITY, pos), size)


## Cilindro (eje Y local de `xf`), con tapas. `r_top` < 0 = igual que `r`.
func cyl(mat: Material, xf: Transform3D, r: float, height: float, segs: int = 10, r_top: float = -1.0) -> void:
	var st := _st(mat)
	var rt := r if r_top < 0.0 else r_top
	var hy := height * 0.5
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := xf * (d0 * r + Vector3(0, -hy, 0))
		var b1 := xf * (d1 * r + Vector3(0, -hy, 0))
		var t0 := xf * (d0 * rt + Vector3(0, hy, 0))
		var t1 := xf * (d1 * rt + Vector3(0, hy, 0))
		var n0 := (xf.basis * d0).normalized()
		var n1 := (xf.basis * d1).normalized()
		# lado (dos triángulos, sentido horario visto desde fuera)
		for pair in [[b0, n0], [t1, n1], [t0, n0], [b0, n0], [b1, n1], [t1, n1]]:
			st.set_normal(pair[1])
			st.set_uv(uv)
			if with_colors:
				st.set_color(color)
			st.add_vertex(pair[0])
		var up := (xf.basis * Vector3.UP).normalized()
		var ct := xf * Vector3(0, hy, 0)
		var cb := xf * Vector3(0, -hy, 0)
		for pair in [[ct, up], [t0, up], [t1, up]]:
			st.set_normal(pair[1])
			st.set_uv(uv)
			if with_colors:
				st.set_color(color)
			st.add_vertex(pair[0])
		for pair in [[cb, -up], [b1, -up], [b0, -up]]:
			st.set_normal(pair[1])
			st.set_uv(uv)
			if with_colors:
				st.set_color(color)
			st.add_vertex(pair[0])
	tris += segs * 4


## Rectángulo de una cara (normal +Z local de `xf`), con UV 0..1 (para pantallas y manchas de luz).
func quad(mat: Material, xf: Transform3D, size: Vector2) -> void:
	var st := _st(mat)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var n := (xf.basis * Vector3(0, 0, 1)).normalized()
	var p := [xf * Vector3(-hx, -hy, 0), xf * Vector3(hx, -hy, 0), xf * Vector3(hx, hy, 0), xf * Vector3(-hx, hy, 0)]
	var quv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_uv(quv[i])
		if with_colors:
			st.set_color(color)
		st.add_vertex(p[i])
	tris += 2


## Cara suelta de cuatro esquinas (en orden, vista desde fuera en sentido antihorario), con UV.y = 0 en las dos
## primeras y 1 en las dos últimas (para degradados a lo largo de la cara).
func face(mat: Material, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var st := _st(mat)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var p := [p0, p1, p2, p3]
	var fuv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_uv(fuv[i])
		if with_colors:
			st.set_color(color)
		st.add_vertex(p[i])
	tris += 2


## ArrayMesh con una superficie por material (null si no hay nada).
func commit() -> ArrayMesh:
	if _order.is_empty():
		return null
	var am := ArrayMesh.new()
	for mat in _order:
		var st: SurfaceTool = _tools[mat]
		st.commit(am)
		if mat != null:
			am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


## Nodo con la malla fundida, sin colisión, marcado para que nada lo vuelva a fundir.
func make_instance(p_name: String, shadows: bool = true) -> MeshInstance3D:
	var am := commit()
	if am == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_merge", true)
	mi.set_meta("gfx_fx", "detalle")
	return mi


## MultiMeshInstance3D que dibuja `mesh` en cada transformación; `custom` (opcional) = un Color por copia.
static func make_multimesh(p_name: String, mesh: Mesh, xforms: Array, custom: Array = [], colors: Array = [], shadows: bool = true) -> MultiMeshInstance3D:
	if mesh == null or xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not custom.is_empty()
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, custom[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = p_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("no_merge", true)
	mmi.set_meta("gfx_fx", "detalle")
	return mmi

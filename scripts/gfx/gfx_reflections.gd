class_name GfxReflections
extends RefCounted
## v0.3.2 gfx · Reflejos en Media/Alta (opción «Reflejos»: Sondas / Sondas + pantalla).
##
## Una sonda de reflexión por ambiente grande del piso (las losas de suelo más grandes: sala, núcleo de ascensores,
## pasillos, cafetería): los suelos pulidos, el vidrio y los metales devuelven las luminarias y las pantallas en vez
## de un negro plano. Funciona igual en Forward+ y en Compatibilidad; en Forward+, con «Sondas + pantalla», los
## reflejos en pantalla (SSR) se suman encima (GfxAtmosphere).
##   · interiores, con proyección de caja ajustada a la losa, sin sombras propias y con LOD agresivo: capturar una
##     sonda cuesta seis vistas chicas del ambiente, UNA sola vez por piso (y otra si cambia la iluminación);
##   · no cambian la luz ambiente (solo el término especular);
##   · tope de sondas por piso: 4 en Media, 6 en Alta.
## Los nodos cuelgan de «GfxSondas» bajo el piso y se van con él o al pasar a Baja/liviano.

const NODE_NAME := "GfxSondas"
const MIN_AREA := 14.0

var root: Node3D = null
var floor_node: Node = null
var stats: Dictionary = {}
var _built_for: int = -1


func apply(p_floor: Node) -> void:
	var lv := GfxSettings.level("reflejos") if GfxSettings.enhanced() else 0
	var want := lv >= 1 and p_floor != null and is_instance_valid(p_floor) and p_floor is Node3D and not GfxSettings.headless()
	if OS.get_environment("GFX_SIN_SONDAS") == "1":
		want = false  # ayuda de pruebas: con Vulkan por software (lavapipe) las sondas duplican la memoria de compilación
	if p_floor != floor_node or not want or (root != null and not is_instance_valid(root)):
		clear()
	floor_node = p_floor
	if not want:
		return
	if is_instance_valid(root):
		refresh()
		return
	_build()


func clear() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	stats = {}
	_built_for = -1


## Vuelve a capturar (cambió la iluminación del piso: opción, recuerdo, emergencia larga).
func refresh() -> void:
	if not is_instance_valid(root):
		return
	for c in root.get_children():
		if c is ReflectionProbe:
			# Cambiar el modo fuerza otra captura.
			(c as ReflectionProbe).update_mode = ReflectionProbe.UPDATE_ALWAYS
			(c as ReflectionProbe).update_mode = ReflectionProbe.UPDATE_ONCE


func _build() -> void:
	var fl := floor_node as Node3D
	var inv := fl.global_transform.affine_inverse()
	var base_y: float = (fl as FloorBase).base_y if fl is FloorBase else 0.0
	var slabs: Array = []   # [área, centro, tamaño]
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not (mi.mesh is BoxMesh) or mi.get_node_or_null("Col") == null or not mi.is_visible_in_tree():
			continue
		var s := (mi.mesh as BoxMesh).size
		if s.y > 0.25:
			continue
		var xf := inv * mi.global_transform
		if absf(xf.origin.y - base_y) > 0.3:
			continue  # no es un suelo de este nivel (techos, entrepisos)
		var ex := absf(xf.basis.x.x) * s.x + absf(xf.basis.z.x) * s.z
		var ez := absf(xf.basis.x.z) * s.x + absf(xf.basis.z.z) * s.z
		if ex * ez < MIN_AREA or minf(ex, ez) < 2.0:
			continue
		slabs.append([ex * ez, xf.origin, Vector2(ex, ez)])
	slabs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var cap := 6 if GfxQuality.level() == "alta" else 4
	root = Node3D.new()
	root.name = NODE_NAME
	root.set_meta("gfx_fx", "sondas")
	root.set_meta("no_merge", true)
	fl.add_child(root)
	var count := 0
	for sl in slabs:
		if count >= cap:
			break
		var size: Vector2 = sl[2]
		var c: Vector3 = sl[1]
		var p := ReflectionProbe.new()
		p.name = "Sonda%d" % count
		p.set_meta("gfx_fx", "sonda")
		p.update_mode = ReflectionProbe.UPDATE_ONCE
		p.interior = true
		p.box_projection = true
		p.enable_shadows = false
		p.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		p.intensity = 0.85
		p.size = Vector3(size.x + 0.4, 3.6, size.y + 0.4)
		p.origin_offset = Vector3(0, -0.2, 0)
		p.max_distance = maxf(size.x, size.y) + 4.0
		p.mesh_lod_threshold = 8.0
		p.position = Vector3(c.x, base_y + 1.75, c.z)
		root.add_child(p)
		count += 1
	stats = {"sondas": count, "losas": slabs.size()}

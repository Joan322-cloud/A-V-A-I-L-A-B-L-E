class_name GfxQuality
extends RefCounted
## Calidad gráfica (Opciones → "Calidad: Modo liviano / Baja / Media / Alta"), guardada en settings.json como "quality".
## Por defecto Baja en web y Media en escritorio; en web con render por software (SwiftShader, llvmpipe…) arranca en
## Modo liviano.
## Liviano (v0.3.1 Q5, PLAN P2; rc1: 33 %, 640×360 y 3 luces): 3D al 40 % con tope de 768×432 internos, bilineal; como mucho LIGHT_BUDGET luces
## encendidas a la vez (las más cercanas a la cámara; las demás se apagan y el ambiente sube para compensar: los
## paneles siguen emisivos), sin sombras ni MSAA, materiales planos (sin texturas ni triplanar), utilería chica y
## carteles con distancia de dibujado corta, lluvia a ¼ y sin charcos animados, 30 fps máx., y la geometría quieta
## del piso fundida en pocos lotes por material y celda de MERGE_CELL m (menos llamadas de dibujo: en SwiftShader
## el costo es por objeto). Un vigía deshace el lote si un original se mueve, se oculta o desaparece.
## En web, si con Baja los fps se quedan bajos (< AUTO_FPS) el juego pasa solo a Modo liviano una vez y lo avisa
## (opción "Modo liviano automático", por defecto activa). Baja: 3D al 75 %, sin MSAA ni sombras, grano sin desenfoque,
## parpadeos a 15 Hz, LOD agresivo y 60 fps máx. Media: 100 %, MSAA 2×. Alta: MSAA 4×. Nada cambia la jugabilidad
## y el escritorio no se toca salvo que el jugador elija el Modo liviano a mano.

const LEVELS: Array[String] = ["liviano", "baja", "media", "alta"]
## Luces encendidas como mucho en Modo liviano (las más cercanas a la cámara).
const LIGHT_BUDGET := 3  # rc1: 5 → 3 (fps del HTML en SwiftShader)
## Lotes de geometría quieta en liviano: celda (m) y mínimo de piezas para que valga la pena.
const MERGE_CELL := 6.0
const MERGE_MIN := 2
## Web: con Baja y una media de menos de AUTO_FPS en dos ventanas seguidas de AUTO_WINDOW s, pasa a liviano.
const AUTO_FPS := 12.0
const AUTO_WINDOW := 8.0
## Distancias de dibujado en liviano: utilería chica (≤ SMALL_PROP m) y carteles.
const SMALL_PROP := 0.8
const SMALL_RANGE := 20.0
const LABEL_RANGE := 14.0
## Ambiente extra en liviano (compensa las luces apagadas: nada queda negro).
const AMBIENT_BOOST := 1.7

static var current: String = ""
static var auto_switched: bool = false


static func is_software_renderer() -> bool:
	var a := (RenderingServer.get_video_adapter_name() + " " + RenderingServer.get_video_adapter_vendor()).to_lower()
	return a.contains("swiftshader") or a.contains("llvmpipe") or a.contains("software") or a.contains("softpipe")


static func default_level() -> String:
	if OS.has_feature("web"):
		return "liviano" if is_software_renderer() else "baja"
	# v0.3.2 gfx: en escritorio, según la tarjeta (sin GPU → liviano · integrada → media · dedicada → alta);
	# en pruebas y corridas de desarrollo sigue siendo «media».
	return GfxBoot.desktop_default()


static func level() -> String:
	if current == "":
		current = str(Loc.get_setting("quality", default_level()))
		if not LEVELS.has(current):
			current = default_level()
	return current


static func is_light() -> bool:
	return level() == "liviano"


## Baja o liviano (los sistemas que ya se abarataban en Baja lo hacen igual en liviano).
static func is_low() -> bool:
	return level() == "baja" or level() == "liviano"


static func shadows_allowed() -> bool:
	return not is_low()


static func label_key(lv: String) -> String:
	match lv:
		"liviano": return "OPT_QUALITY_LIGHT"
		"baja": return "OPT_QUALITY_LOW"
		"alta": return "OPT_QUALITY_HIGH"
	return "OPT_QUALITY_MEDIUM"


static func next(lv: String) -> String:
	return LEVELS[(LEVELS.find(lv) + 1) % LEVELS.size()]


## ¿El cambio automático a liviano está permitido? (web, opción activa y el jugador no eligió la calidad a mano).
static func auto_allowed() -> bool:
	return OS.has_feature("web") and bool(Loc.get_setting("quality_auto", true)) and not bool(Loc.get_setting("quality_user", false))


## El edificio vivo. En el cuadro en que se cambia de mundo sin pasar por el menú (al firmar el Training: Main borra
## el mundo del recuerdo y arma el del Lunes en la misma llamada) conviven dos: el viejo, ya en cola de borrado, y
## el nuevo. El primero del grupo es el viejo: el pase gráfico se aplicaba a un piso que desaparecía al final del
## cuadro (v0.3.2-final).
static func live_building(tree: SceneTree) -> Building:
	var found: Building = null
	for n in tree.get_nodes_in_group("building"):
		if n is Building and not n.is_queued_for_deletion():
			found = n as Building
	return found


## Aplica el nivel al viewport raíz y a las luces que ya existen. Se llama al arrancar, al cambiar la
## opción y al cargar cada piso (las luces nuevas consultan shadows_allowed() al crearse).
static func apply(tree: SceneTree, lv: String = "") -> void:
	if lv != "":
		current = lv
	var l := level()
	# v0.3.2 gfx: mejoras de Media/Alta (scripts/gfx/). En Baja y Modo liviano deshace en el acto lo que hubiera,
	# ANTES de fundir mallas y de repartir el cupo de luces: el piso queda como sin el paquete.
	GfxDirector.request(tree)
	var vp := tree.root
	var low := is_low()
	var light := l == "liviano"
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if light:
		var w := float(maxi(vp.size.x, 1))
		vp.scaling_3d_scale = clampf(minf(0.33, 640.0 / w), 0.2, 0.33)  # rc1: 0,4/768 → 0,33/640 (SwiftShader)
	else:
		vp.scaling_3d_scale = 0.75 if low else 1.0
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = not low
	vp.mesh_lod_threshold = 8.0 if light else (4.0 if low else (1.0 if l == "media" else 0.5))
	vp.positional_shadow_atlas_size = 1024 if low else 2048
	apply_fps_cap()
	for n in tree.root.find_children("*", "Light3D", true, false):
		var lt := n as Light3D
		var designed: bool = bool(lt.get_meta("shadow_design", lt.shadow_enabled))
		lt.set_meta("shadow_design", designed)
		lt.shadow_enabled = designed and not low
		if not light and lt.has_meta("budget_off"):
			lt.remove_meta("budget_off")
			lt.visible = true
	for env in tree.root.find_children("*", "WorldEnvironment", true, false):
		var e := (env as WorldEnvironment).environment
		if e != null:
			e.ssao_enabled = false
			e.ssil_enabled = false
			e.glow_enabled = false
			e.volumetric_fog_enabled = false
			if light:
				e.adjustment_enabled = false  # el etalonaje del piso cuesta una pasada más a pantalla completa
	Greybox.set_flat_materials(light)
	for w in tree.root.find_children("Lluvia", "Node3D", true, false):
		if w is Weather:
			(w as Weather).apply_quality()
	_draw_ranges(tree, light)
	_merge_static(tree, light)
	_ensure_budget(tree, light)
	_ensure_auto(tree)


## Liviano: la utilería chica y los carteles se dejan de dibujar de lejos (el resto lo corta el frustum).
static func _draw_ranges(tree: SceneTree, light: bool) -> void:
	var b := live_building(tree)
	if b == null:
		return
	for n in b.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi is Label3D:
			gi.visibility_range_end = LABEL_RANGE if light else 0.0
		elif gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh == null:
				continue
			if light:
				var s := mi.get_aabb().size * mi.global_basis.get_scale()
				if maxf(s.x, maxf(s.y, s.z)) <= SMALL_PROP:
					mi.visibility_range_end = SMALL_RANGE
					mi.set_meta("q5_range", true)
			elif mi.has_meta("q5_range"):
				mi.visibility_range_end = 0.0
				mi.remove_meta("q5_range")


## Liviano: funde los MeshInstance3D quietos del piso (sin script propio ni de sus padres, sin hijos visibles,
## opacos, con una sola superficie) en un ArrayMesh por material y celda. Los originales quedan en la capa 0 (no se
## dibujan, la colisión no cambia); el vigía (_MergeWatch) los devuelve si el juego los mueve, oculta o libera.
static func _merge_static(tree: SceneTree, on: bool) -> void:
	var b := live_building(tree)
	if b == null or b.floor_node == null:
		return
	var fl: Node3D = b.floor_node
	var holder := fl.get_node_or_null("GfxLotes")
	if not on:
		if holder != null:
			for c in holder.get_children():
				if c is MeshInstance3D:
					_unmerge(c as MeshInstance3D)
			holder.queue_free()
		return
	if holder != null:
		return
	var inv := fl.global_transform.affine_inverse()
	var groups: Dictionary = {}
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not _mergeable(mi, fl):
			continue
		var mat: Material = mi.material_override
		if mat == null:
			mat = mi.get_surface_override_material(0)
		if mat == null:
			mat = mi.mesh.surface_get_material(0)
		if mat == null or (mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			continue
		var xf := inv * mi.global_transform
		var key := "%d|%d|%d" % [mat.get_instance_id(), floori(xf.origin.x / MERGE_CELL), floori(xf.origin.z / MERGE_CELL)]
		if not groups.has(key):
			groups[key] = {"mat": mat, "items": []}
		(groups[key]["items"] as Array).append([mi, xf])
	holder = Node3D.new()
	holder.name = "GfxLotes"
	fl.add_child(holder)
	var merged := 0
	for k in groups:
		var items: Array = groups[k]["items"]
		if items.size() < MERGE_MIN:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var src: Array = []
		for it in items:
			var mi := it[0] as MeshInstance3D
			st.append_from(mi.mesh, 0, it[1])
			src.append([mi, mi.layers, mi.global_transform, mi.material_override])
		var am := st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		am.surface_set_material(0, groups[k]["mat"])
		var lote := MeshInstance3D.new()
		lote.name = "Lote%d" % holder.get_child_count()
		lote.mesh = am
		lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lote.set_meta("src", src)
		holder.add_child(lote)
		for e in src:
			(e[0] as MeshInstance3D).layers = 0
		merged += src.size()
	var w := _MergeWatch.new()
	w.name = "Vigia"
	holder.add_child(w)
	print("[gfx] liviano: %d piezas en %d lotes" % [merged, holder.get_child_count() - 1])


## Diagnóstico (pruebas): por qué no se funde cada pieza del piso.
static func merge_report(fl: Node) -> Dictionary:
	var out: Dictionary = {}
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var why := "ok"
		if mi.layers == 0:
			why = "fundida"
		elif mi.mesh == null or mi.mesh.get_surface_count() != 1:
			why = "superficies"
		elif not mi.is_visible_in_tree():
			why = "oculta"
		elif mi.get_script() != null:
			why = "script"
		else:
			for c in mi.find_children("*", "", true, false):
				if c is VisualInstance3D or c is Light3D or c.get_script() != null:
					why = "hijos"
					break
			if why == "ok":
				var p := mi.get_parent()
				while p != null and p != fl:
					if p.get_script() != null:
						why = "padre:" + str((p.get_script() as Script).resource_path.get_file())
						break
					p = p.get_parent()
		out[why] = int(out.get(why, 0)) + 1
	return out


static func _mergeable(mi: MeshInstance3D, fl: Node) -> bool:
	if mi.mesh == null or mi.mesh.get_surface_count() != 1 or not mi.is_visible_in_tree() or mi.layers != 1:
		return false
	if mi.get_script() != null or mi.material_overlay != null or mi.has_meta("no_merge") or mi.is_in_group("no_merge"):
		return false
	if not (mi.mesh is PrimitiveMesh or mi.mesh is ArrayMesh):
		return false
	for c in mi.find_children("*", "", true, false):
		if c is VisualInstance3D or c is Light3D or c.get_script() != null or c is AnimationPlayer:
			return false
	var p := mi.get_parent()
	while p != null and p != fl:
		if p.get_script() != null or p.has_meta("no_merge") or p is AnimationPlayer:
			return false
		p = p.get_parent()
	return p == fl


static func _unmerge(lote: MeshInstance3D) -> void:
	for e in lote.get_meta("src", []):
		if is_instance_valid(e[0]):
			(e[0] as MeshInstance3D).layers = int(e[1])
	lote.set_meta("src", [])
	lote.visible = false


## Vigía de los lotes: revisa unos lotes por cuadro; si una pieza se movió, se ocultó, cambió de material o se
## liberó, deshace su lote (vuelven los originales).
class _MergeWatch extends Node:
	var _i: int = 0

	func _process(_delta: float) -> void:
		var lotes := get_parent().get_children()
		if lotes.size() <= 1:
			return
		for _k in 4:
			_i = (_i + 1) % lotes.size()
			var l := lotes[_i] as MeshInstance3D
			if l == null or not l.visible:
				continue
			for e in l.get_meta("src", []):
				var mi: Variant = e[0]
				if not is_instance_valid(mi) or not (mi as MeshInstance3D).is_visible_in_tree() or not (mi as MeshInstance3D).global_transform.is_equal_approx(e[2] as Transform3D) or (mi as MeshInstance3D).material_override != e[3]:
					GfxQuality._unmerge(l)
					break


## rc1: el nodo se agrega diferido; dos apply() en el mismo cuadro (arranque + carga del piso) creaban DOS
## LightBudget que se subían el ambiente uno al otro cada 0,25 s (×1,7 sin fin): el Modo liviano salía blanco.
static var _budget: Node = null


static func _ensure_budget(tree: SceneTree, on: bool) -> void:
	var lb: Node = _budget if is_instance_valid(_budget) and not _budget.is_queued_for_deletion() else null
	if on and lb == null:
		lb = LightBudget.new()
		lb.name = "GfxLightBudget"
		_budget = lb
		tree.root.add_child.call_deferred(lb)
	elif not on and lb != null:
		(lb as LightBudget).restore()
		lb.queue_free()
		_budget = null
	elif on and lb != null and lb.is_inside_tree():
		(lb as LightBudget).rescan()


static func _ensure_auto(tree: SceneTree) -> void:
	if not OS.has_feature("web") and not OS.get_cmdline_user_args().has("--gfx-auto-test"):
		return
	if tree.root.get_node_or_null("GfxAuto") != null:
		return
	var a := AutoLight.new()
	a.name = "GfxAuto"
	tree.root.add_child.call_deferred(a)


## Modo liviano: deja encendidas solo las LIGHT_BUDGET luces más cercanas a la cámara (con prioridad a las que
## están delante) y sube el ambiente para que nada quede negro. Recalcula 4 veces por segundo.
class LightBudget extends Node:
	var _lights: Array[Light3D] = []
	var _t: float = 0.0
	var _scan_t: float = 0.0
	var _env: Environment = null
	var _amb_set: float = -1.0
	var _vp_t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		rescan()

	func rescan() -> void:
		_lights.clear()
		for n in get_tree().root.find_children("*", "Light3D", true, false):
			var l := n as Light3D
			if l is DirectionalLight3D or l.has_meta("budget_keep"):
				continue
			_lights.append(l)
		_scan_t = 0.0
		_t = 0.0

	func restore() -> void:
		for l in _lights:
			if is_instance_valid(l) and l.has_meta("budget_off"):
				l.remove_meta("budget_off")
				l.visible = true
		if _env != null and _amb_set >= 0.0:
			_env.ambient_light_energy = _amb_set / GfxQuality.AMBIENT_BOOST
		_amb_set = -1.0
		for vp in _pc_viewports():
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	## Pantallas de la PC (SubViewports 2D de la Workstation): en liviano se redibujan a 5 Hz salvo con la PC acercada.
	func _pc_viewports() -> Array[SubViewport]:
		var out: Array[SubViewport] = []
		var ws := get_tree().get_first_node_in_group("workstation")
		if ws == null:
			return out
		for c in ws.get_children():
			if c is SubViewport:
				out.append(c as SubViewport)
		return out

	func _throttle_screens(delta: float) -> void:
		_vp_t -= delta
		var ws := get_tree().get_first_node_in_group("workstation")
		var live := ws != null and bool(ws.get("zoomed")) and (ws as CanvasItem).visible if ws is CanvasItem else false
		for vp in _pc_viewports():
			if live:
				vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			elif _vp_t <= 0.0:
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		if _vp_t <= 0.0:
			_vp_t = 0.2

	func _process(delta: float) -> void:
		_scan_t += delta
		if _scan_t > 1.5:
			rescan()  # el piso cambió o aparecieron luces (relámpagos, C-17…)
		_throttle_screens(delta)
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.25
		_boost_ambient()
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var cp := cam.global_position
		var fwd := -cam.global_transform.basis.z
		var scored: Array = []
		for l in _lights:
			if not is_instance_valid(l) or not l.is_inside_tree():
				continue
			var lp := l.global_position
			var d := cp.distance_to(lp)
			var rng := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 10.0)
			if d > rng + 2.0:
				_set_on(l, false)
				continue
			var ahead := fwd.dot((lp - cp).normalized()) if d > 0.5 else 1.0
			scored.append([d - 3.0 * ahead - 0.15 * rng, l])
		scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for i in scored.size():
			_set_on(scored[i][1] as Light3D, i < GfxQuality.LIGHT_BUDGET)

	func _set_on(l: Light3D, on: bool) -> void:
		if on:
			if l.has_meta("budget_off"):
				l.remove_meta("budget_off")
				l.visible = true
		elif not l.has_meta("budget_off"):
			if not l.visible:
				return  # apagada por el juego (C-17, relámpago): no es nuestra
			l.set_meta("budget_off", true)
			l.visible = false

	func _boost_ambient() -> void:
		if _env == null:
			var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
			if we.is_empty():
				return
			_env = (we[0] as WorldEnvironment).environment
		if _env == null:
			return
		# main.gd fija el ambiente del piso al cargarlo: si cambió, ese es el nuevo valor base.
		if absf(_env.ambient_light_energy - _amb_set) > 0.001:
			_amb_set = _env.ambient_light_energy * GfxQuality.AMBIENT_BOOST
			_env.ambient_light_energy = _amb_set


## Web: mide los fps del turno; con Baja (y el automático permitido) y fps bajos, pasa a Modo liviano una vez.
class AutoLight extends Node:
	var _acc: float = 0.0
	var _frames: int = 0
	var _low_windows: int = 0
	var _warm: float = 6.0
	var _t0: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_t0 = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if GfxQuality.auto_switched or not GfxQuality.auto_allowed() or GfxQuality.level() != "baja" or not GameState.running or get_tree().paused:
			_frames = 0
			_t0 = Time.get_ticks_usec()
			return
		_frames += 1
		var t := float(Time.get_ticks_usec() - _t0) / 1000000.0
		if _warm > 0.0:
			if t >= _warm:
				_warm = 0.0
				_frames = 0
				_t0 = Time.get_ticks_usec()
			return
		if t < GfxQuality.AUTO_WINDOW:
			return
		var fps := float(_frames) / t
		_frames = 0
		_t0 = Time.get_ticks_usec()
		_low_windows = _low_windows + 1 if fps < GfxQuality.AUTO_FPS else 0
		if _low_windows >= 2:
			GfxQuality.auto_switched = true
			print("[gfx] fps bajos (%.1f) con Baja: Modo liviano automático" % fps)
			Loc.set_setting("quality", "liviano")
			GfxQuality.apply(get_tree(), "liviano")
			EventBus.show_message.emit(tr("MSG_QUALITY_AUTO_LIGHT"), 6.0)
			EventBus.settings_changed.emit("quality")


static func desired_max_fps() -> int:
	var l := level()
	if l == "liviano":
		return 30
	if l == "baja" or OS.has_feature("web"):
		return 60
	return GfxSettings.max_fps()


static func apply_fps_cap() -> void:
	Engine.max_fps = desired_max_fps()

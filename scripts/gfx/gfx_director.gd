class_name GfxDirector
extends Node
## v0.3.2 gfx · Director de las mejoras gráficas de Media/Alta. Un solo nodo (root/GfxDirector) que reparte el
## trabajo a los módulos de scripts/gfx/:
##   GfxAtmosphere (aire: tonos, exposición, niebla, AO, reflejos, resplandor) · GfxLights (luz de terror y luces de
##   práctica) · GfxMaterials (relieve y rugosidad) · GfxDetail (geometría de detalle) · GfxLens (lente y película).
##
## Entrada única: GfxQuality.apply() llama a GfxDirector.request(tree) al empezar (arranque, cambio de calidad, carga
## de cada piso). request():
##   · en Baja y Modo liviano deshace EN EL ACTO todo lo que hubiera (luces, detalle, materiales, aire, lente): el
##     resto de GfxQuality.apply() —fundir mallas, cupo de luces— ve el piso exactamente como sin este paquete. Si
##     nunca hubo Media/Alta y el brillo está en 1,0, ni siquiera se crea el nodo: cero costo;
##   · en Media/Alta, si el piso cambió, devuelve el Environment a sus valores (main.gd va a escribir los del piso
##     nuevo) y agenda el pase para el final del cuadro, cuando main.gd ya puso el ambiente del piso.
##
## Ganchos públicos (otros paquetes; no hacen nada en Baja/liviano):
##   GfxDirector.emergency(true/false)      luces de emergencia (tubos al mínimo, luminarias encendidas)
##   GfxDirector.blackout(segundos, nivel)  apagón de guion: los tubos caen a `nivel` (0 = negro) y vuelven solos
##   GfxLens.kick(fuerza, segundos)         empuje del lente en un susto
##   GfxDirector.summary()                  estado para pruebas

static var inst: GfxDirector = null

var atmosphere := GfxAtmosphere.new()
var lights := GfxLights.new()
var detail := GfxDetail.new()
var reflections := GfxReflections.new()
var lens: GfxLens = null
var _pending: bool = false
var _floor_id: int = 0
var _was_flashback: bool = false
var _dying: bool = false
var _slow_t: float = 0.0
var _char_t: float = 0.0
var _em_last: float = -1.0
var applied_count: int = 0
var _sun: Array = []   # luces de la ventana del recuerdo a las que se les dio sombra (se les quita al deshacer)


## Lo llama GfxQuality.apply() (y el panel de opciones al cambiar algo suelto).
static func request(tree: SceneTree) -> void:
	if tree == null:
		return
	GfxBoot.once(tree)  # primera llamada del juego: renderizador, primera vez, contador de FPS
	if not is_instance_valid(inst):
		if GfxSettings.web() or (not GfxSettings.enhanced() and absf(GfxSettings.brillo() - 1.0) < 0.005):
			return  # Baja / liviano sin nada que hacer (y el HTML, siempre): el paquete no existe para el juego
		inst = GfxDirector.new()
		inst.name = "GfxDirector"
		tree.root.add_child.call_deferred(inst)
	inst._on_request(tree)


func _on_request(tree: SceneTree) -> void:
	var fl := _floor(tree)
	var fid := fl.get_instance_id() if fl != null else 0
	if not GfxSettings.enhanced():
		_undo_all(tree)
	elif fid != _floor_id:
		atmosphere.restore()
	if not _pending:
		_pending = true
		_apply_deferred.call_deferred()


## Baja / liviano: todo vuelve a como lo dejó el juego, ya.
func _undo_all(tree: SceneTree = null) -> void:
	# Una sesión de Haime en curso suelta sus luces mientras se les devuelve la base y las vuelve a tomar después.
	var scripted := tree != null and lights.active
	if scripted:
		tree.call_group(GfxLights.SCRIPTED_GROUP, "gfx_lights_begin")
	lights.restore()
	detail.clear()
	reflections.clear()
	GfxCharacters.restore()
	atmosphere.restore()
	GfxMaterials.apply()  # con la calidad ya en Baja/liviano, esto solo deshace
	_recuerdo_sun(null)
	if lens != null:
		lens.apply({})
	if scripted:
		tree.call_group(GfxLights.SCRIPTED_GROUP, "gfx_lights_end")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	lens = GfxLens.new()
	add_child(lens)
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void:
		_dying = true
		_event("death_sequence_started"))
	EventBus.respawned.connect(func(_k: String) -> void:
		_dying = false
		emergency(false))
	EventBus.returned_to_menu.connect(func() -> void:
		_dying = false
		emergency(false))
	EventBus.pursuit_started.connect(func(_h: String, _c: String) -> void: _event("pursuit_started"))
	EventBus.pursuit_ended.connect(func(_h: String, _r: String) -> void: _event("pursuit_ended"))
	EventBus.rta_hunt_started.connect(func() -> void: _event("rta_hunt_started"))
	EventBus.settings_changed.connect(_on_setting)


func _exit_tree() -> void:
	if inst == self:
		inst = null


## Reacción del aire a una señal (data/gfx_looks.json → eventos).
func _event(id: String) -> void:
	var ev: Variant = (DataLoader.dict("gfx_looks").get("eventos", {}) as Dictionary).get(id)
	if not (ev is Dictionary):
		return
	var d := ev as Dictionary
	if d.has("emergencia"):
		emergency(bool(d["emergencia"]))
	if d.has("susto"):
		GfxLens.kick(float(d["susto"]), float(d.get("s", 1.0)))


## Para quien administra por guion las luces de una sala (la sesión de Haime). En Baja / liviano no hay rediseño:
## design_energy() da −1 y zone_value() el valor por defecto.
static func design_energy(l: Light3D) -> float:
	return inst.lights.design_energy(l) if is_instance_valid(inst) and GfxSettings.enhanced() else -1.0


static func zone_value(p: Vector3, key: String, fallback: float) -> float:
	return inst.lights.zone_value(p, key, fallback) if is_instance_valid(inst) and GfxSettings.enhanced() else fallback


## Luces de emergencia: los tubos caen casi a cero y quedan las luminarias de emergencia y los carteles de salida.
static func emergency(on: bool) -> void:
	if is_instance_valid(inst):
		inst.lights.set_emergency(on)


## Apagón de guion (un susto, un corte de luz): no hace nada en Baja/liviano ni en el recuerdo. Con «Sin parpadeos
## de luz» los tubos no caen del todo (quedan a la mitad).
static func blackout(seconds: float, level: float = 0.0) -> void:
	if not is_instance_valid(inst) or Flashback.active:
		return
	if bool(Loc.get_setting("flash_reduction", false)):
		level = maxf(level, 0.5)
	inst.lights.blackout(seconds, level)


## El recuerdo (Training) es de día: la luz que entra por la ventana del aula («LuzVentana», de TrainingRoom) recibe
## sombra suave en Media/Alta. En Baja no (GfxQuality apaga las sombras) y al deshacer vuelve a como estaba.
func _recuerdo_sun(fl: Node) -> void:
	var want := fl != null and Flashback.active and GfxSettings.enhanced() and GfxSettings.level("sombras") >= 1
	if not want:
		for l in _sun:
			if is_instance_valid(l):
				(l as Light3D).shadow_enabled = false
				(l as Light3D).set_meta("shadow_design", false)
		_sun.clear()
		return
	for n in fl.find_children("LuzVentana*", "SpotLight3D", true, false):
		var sp := n as SpotLight3D
		if _sun.has(sp):
			continue
		sp.set_meta("shadow_design", true)
		sp.shadow_enabled = true
		sp.shadow_blur = 1.8
		sp.shadow_bias = 0.06
		sp.shadow_normal_bias = 1.5
		sp.shadow_opacity = 0.85
		_sun.append(sp)


func _on_setting(key: String) -> void:
	if key == "quality":
		return  # GfxQuality.apply() ya llama a request()
	if key == "gfx" or key.begins_with("gfx_") or key == "flash_reduction":
		reapply()


## Vuelve a pasar todo (lo usa el panel de opciones al cambiar una opción suelta).
func reapply() -> void:
	if not _pending:
		_pending = true
		_apply_deferred.call_deferred()


func _floor(tree: SceneTree) -> Node:
	var b := GfxQuality.live_building(tree)
	if b == null or b.floor_node == null or not is_instance_valid(b.floor_node) or b.floor_node.is_queued_for_deletion():
		return null
	return b.floor_node


func _environment(tree: SceneTree) -> Environment:
	var b := GfxQuality.live_building(tree)
	if b == null or b.get_parent() == null:
		return null
	for c in b.get_parent().get_children():  # el WorldEnvironment del mundo es hermano del edificio (main.gd)
		if c is WorldEnvironment and not c.is_queued_for_deletion():
			return (c as WorldEnvironment).environment
	return null


func _apply_deferred() -> void:
	_pending = false
	if not is_inside_tree():
		return
	var tree := get_tree()
	var fl := _floor(tree)
	_floor_id = fl.get_instance_id() if fl != null else 0
	_was_flashback = Flashback.active
	GfxMaterials.apply()
	atmosphere.apply(_environment(tree), fl)
	var look: Dictionary = atmosphere.look if atmosphere.active else GfxAtmosphere.look_for(fl)
	# Una sesión de Haime en curso suelta sus luces mientras el pase les cambia la base y las vuelve a tomar después.
	tree.call_group(GfxLights.SCRIPTED_GROUP, "gfx_lights_begin")
	lights.apply(fl, look if atmosphere.active else {}, self)
	tree.call_group(GfxLights.SCRIPTED_GROUP, "gfx_lights_end")
	detail.apply(fl)
	detail.set_daytime(Flashback.active)
	GfxMaterials.plain_scan(fl)  # lo chico y lo que se lee, sin relieve genérico (después del detalle: mira también sus piezas sueltas)
	lights.set_pool(detail.screen_points, detail.point_specs)
	lens.apply(look)
	reflections.apply(fl)
	GfxCharacters.tick(tree)
	_recuerdo_sun(fl)
	_apply_viewport(tree)
	_em_last = -1.0
	lights.rescanned = false
	applied_count += 1


## Ajustes del viewport que dependen de las opciones avanzadas (solo Media/Alta; Baja y liviano los fija GfxQuality).
func _apply_viewport(tree: SceneTree) -> void:
	if not GfxSettings.enhanced():
		return
	var vp := tree.root
	vp.scaling_3d_scale = clampf(GfxSettings.amount("escala_3d"), 0.5, 1.0)
	if GfxSettings.forward() and vp.scaling_3d_scale < 0.99:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	var s := GfxSettings.level("sombras")
	vp.positional_shadow_atlas_size = 2048 if s >= 2 else 1024
	vp.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	vp.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	vp.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16
	vp.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16


func _process(delta: float) -> void:
	if not GfxSettings.enhanced():
		return
	var cam := get_viewport().get_camera_3d()
	lights.tick(delta, cam, _dying or Checkpoints.dying)
	if lights.rescanned:
		# El piso cambió sus luminarias a mitad de turno («un panel más»): la capa de detalle se rehace sobre las nuevas.
		lights.rescanned = false
		detail.rebuild()
		detail.set_daytime(Flashback.active)
		lights.set_pool(detail.screen_points, detail.point_specs)
		_em_last = -1.0
	var fl0 := _floor(get_tree())
	if fl0 is Node3D:
		GfxCharacters.frame((fl0 as Node3D).global_position.y + ((fl0 as FloorBase).base_y if fl0 is FloorBase else 0.0))
	atmosphere.tick(delta, lights.local_light if lights.active else 0.5, GfxLens.scare_level())
	if lights.emergency != _em_last:
		_em_last = lights.emergency
		detail.set_emergency(_em_last)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.25
		GfxMaterials.refresh_if_new()
		if GfxMaterials.plain_dirty:
			GfxMaterials.plain_dirty = false
			GfxMaterials.plain_scan(_floor(get_tree()))
		GfxMaterials.plain_tick()
		_char_t -= 0.25
		if _char_t <= 0.0:
			_char_t = 1.0
			GfxCharacters.tick(get_tree())
		# El recuerdo del Training empieza y termina sin cargar piso: el aspecto cambia con él.
		if Flashback.active != _was_flashback:
			reapply()
		elif Flashback.active:
			_recuerdo_sun(_floor(get_tree()))  # el aula se arma después de cargar el piso
		var fl := _floor(get_tree())
		if (fl.get_instance_id() if fl != null else 0) != _floor_id:
			reapply()


## Resumen para pruebas y para el contador de depuración.
func summary() -> Dictionary:
	return {
		"mejorado": GfxSettings.enhanced(), "forward": GfxSettings.forward(), "aspecto": atmosphere.look_id,
		"aire": atmosphere.active, "luces": lights.stats, "materiales": GfxMaterials.stats, "detalle": detail.stats,
		"lente": GfxLens.active, "sondas": reflections.stats, "personajes": GfxCharacters.stats, "exposicion": atmosphere.exposure_now(), "luz_local": lights.local_light,
	}

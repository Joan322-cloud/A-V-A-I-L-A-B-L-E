class_name CharacterRig
extends Node3D
## Modelo GLB con esqueleto y clips (assets/models/<nombre>.glb) escalado a una altura objetivo.
## Si el modelo no existe, attach() devuelve null y el personaje conserva su placeholder (cápsula).
## Convención: el personaje mira hacia -Z (como Godot); los GLB miran a +Z → yaw_fix 180.
## v0.3 (P6): los 19 modelos v2 (models_v2, Blender) traen su textura embebida (materiales <slug>_cuerpo,
## _pelo, _brillo y, en Trainer/Haime/GRASA/Don Fermín/enfermero, _cara con la cabeza en alta): no se pisan
## ni se tiñen. Nodos conmutables: "Afro" (Shero; set_look("calvo") lo oculta) y "Pelo" (Rasec). La altura
## se mide con todos los nodos visibles (el cuerpo no cambia de tamaño al ocultar el pelo). Shero v2 mide
## 2,2 m con el afro (HEIGHTS_V2). Vitzo lleva el shader de pantalla con glitch (VitzoGlitch).

const MODELS_DIR := "res://assets/models/"
const TEX_DIR := "res://assets/textures/"
## Los GLB de la cantera traen una textura dummy: el atlas real va aparte (assets/textures/<base>_*.png).
const TEX_BASE: Dictionary = {"perrito_rta": "perrito_rta_pelaje", "vitzo": "vitzo_cuerpo"}
## Altura (m) que manda sobre la del llamador cuando el modelo es v2 (PLAN P6: Shero ~2,2 m con el afro;
## el GLB v2 mide 2,73 con afro y 2,47 calvo por la cabeza cartoon).
const HEIGHTS_V2: Dictionary = {"shero": 2.2}
## Agentes jugables con GLB propio v2 (antes Llauri usaba el de Marko).
const AGENT_MODELS: Dictionary = {"jiroshi": "agente_jiroshi", "marko": "agente_marko", "llauri": "agente_llauri", "ttoom": "agente_ttoom", "juan": "agente_juan"}

var anim: AnimationPlayer = null
## v0.3.2-anim: AnimationTree con los clips de Blender (assets/anim/<modelo>.res); null = AnimationPlayer como antes.
var animator: NpcAnimator = null
var current: String = ""
var model_name: String = ""
## true si el GLB trae sus propias texturas (modelo v2): no se reemplazan ni se tiñen.
var is_v2: bool = false


static func attach(parent: Node3D, model: String, target_height: float, yaw_fix_deg: float = 180.0, offset: Vector3 = Vector3.ZERO) -> CharacterRig:
	var scene := _load_scene(model)
	if scene == null:
		return null
	var rig := CharacterRig.new()
	rig.name = "Rig_" + model
	rig.model_name = model
	rig.position = offset
	parent.add_child(rig)
	rig.add_child(scene)
	rig.is_v2 = _has_embedded_textures(scene)
	if rig.is_v2 and HEIGHTS_V2.has(model):
		target_height = float(HEIGHTS_V2[model])
	var h := rig._height(scene)  # con Afro/Pelo visibles (como vienen en el GLB)
	if h > 0.01:
		scene.scale = Vector3.ONE * (target_height / h)
	scene.rotation_degrees.y = yaw_fix_deg
	for c in scene.find_children("*", "AnimationPlayer", true, false):
		rig.anim = c
	rig._apply_textures(scene)
	rig.animator = NpcAnimator.attach(scene, model, rig, rig.anim)
	if model == "rasec":
		rig.set_look("")  # Rasec es calvo; el pelo solo con música / evento
	if model == "vitzo":
		VitzoGlitch.apply(scene)
	return rig


## ¿Algún material importado ya trae albedo_texture? (GLB v2 con textura embebida.)
static func _has_embedded_textures(scene: Node3D) -> bool:
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			if albedo_of(mi.get_active_material(i)) != null:
				return true
	return false


## Textura base de un material: la del StandardMaterial3D del GLB o, con la cara deformable de los screamers
## (ScreamRig, Q2), el parámetro albedo_tex del ShaderMaterial.
static func albedo_of(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		return (mat as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
	return null


## Looks de los modelos v2: "calvo" oculta el nodo Afro (Shero enojado y en sus screamers), "pelo" muestra
## el nodo Pelo (Rasec con música / evento); "" o "afro" = look normal (Shero con afro, Rasec calvo).
## Para P3: shero.gd puede llamar _rig.set_look(look) en su set_look(); hoy ya oculta "Afro" con find_child.
func set_look(look: String) -> void:
	var afro := find_child("Afro", true, false) as Node3D
	if afro != null:
		afro.visible = look != "calvo"
	var pelo := find_child("Pelo", true, false) as Node3D
	if pelo != null:
		pelo.visible = look == "pelo"


## Cara de screamer (textura <slug>_cara_grito: boca abierta, ojos hundidos) o la normal. Solo modelos v2 con
## material <slug>_cara. Devuelve true si cambió algo.
func set_scream_face(on: bool) -> bool:
	return CharacterRig.swap_scream_face(self, model_name, on)


static func swap_scream_face(root: Node, slug: String, on: bool) -> bool:
	var alt: Texture2D = Faces.texture_at(TEX_DIR + slug + "_cara_grito.jpg") if on else null
	var changed := false
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null or not src.resource_name.ends_with("_cara"):
				continue
			if on and alt != null:
				var mat := src.duplicate() as BaseMaterial3D
				mat.albedo_texture = alt
				mi.set_surface_override_material(i, mat)
				changed = true
			elif not on and mi.get_surface_override_material(i) != null:
				mi.set_surface_override_material(i, null)
				changed = true
	return changed


## Asigna el atlas por nombre de material: outfit → <base>_ropa (o pelaje/cuerpo), skin → <base>_piel,
## hair → pelo_mechones, eye/glass/screen/bulb → colores planos.
func _apply_textures(scene: Node3D) -> void:
	var base: String = TEX_BASE.get(model_name, model_name)
	var ropa := base if TEX_BASE.has(model_name) else base + "_ropa"
	var piel := base if TEX_BASE.has(model_name) else base + "_piel"
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				continue  # v2: material importado con su textura embebida (no se pisa)
			var mname := src.resource_name.to_lower() if src != null else ""
			var mat := StandardMaterial3D.new()
			mat.roughness = 0.75
			match mname:
				"outfit":
					_set_tex(mat, ropa, "_normal", "_rugosidad", "")  # el atlas emisivo de la cantera es casi blanco: se deja apagado
				"skin":
					_set_tex(mat, piel, "_normal", "", "")
				"hair":
					if not _set_tex(mat, "pelo_mechones", "", "", ""):
						mat.albedo_color = Color(0.08, 0.06, 0.05)
				"eye":
					mat.albedo_color = Color(0.9, 0.9, 0.88)
					mat.roughness = 0.2
				"glass":
					mat.albedo_color = Color(0.1, 0.12, 0.15, 0.55)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.roughness = 0.1
				"screen":
					mat.albedo_color = Color(0.1, 0.2, 0.35)
					mat.emission_enabled = true
					mat.emission = Color(0.2, 0.5, 0.9)
					mat.emission_energy_multiplier = 1.5
				"bulb", "face":
					mat.albedo_color = Color(0.85, 0.85, 0.8)
				_:
					if not _set_tex(mat, ropa, "_normal", "_rugosidad", ""):
						mat.albedo_color = Color(0.45, 0.47, 0.5)
			mi.set_surface_override_material(i, mat)


func _set_tex(mat: StandardMaterial3D, base: String, normal_sfx: String, rough_sfx: String, emis_sfx: String) -> bool:
	var albedo := Faces.texture_at(TEX_DIR + base + ".png")
	if albedo == null:
		return false
	mat.albedo_texture = albedo
	if normal_sfx != "":
		var n := Faces.texture_at(TEX_DIR + base + normal_sfx + ".png")
		if n != null:
			mat.normal_enabled = true
			mat.normal_texture = n
	if rough_sfx != "":
		var r := Faces.texture_at(TEX_DIR + base + rough_sfx + ".png")
		if r != null:
			mat.roughness_texture = r
			mat.roughness = 1.0
	if emis_sfx != "":
		var e := Faces.texture_at(TEX_DIR + base + emis_sfx + ".png")
		if e != null:
			mat.emission_enabled = true
			mat.emission_texture = e
			mat.emission = Color(1, 1, 1)
			mat.emission_energy_multiplier = 0.8
	return true


static func _load_scene(model: String) -> Node3D:
	var path := MODELS_DIR + model + ".glb"
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	if FileAccess.file_exists(path):
		# Sin importar (p. ej. archivo añadido a mano): carga en caliente.
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			return doc.generate_scene(state) as Node3D
	return null


func _height(scene: Node3D) -> float:
	var top := -INF
	var bottom := INF
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		var xf := scene.global_transform.affine_inverse() * mi.global_transform
		var a := xf * aabb.position
		var b := xf * aabb.end
		top = maxf(top, maxf(a.y, b.y))
		bottom = minf(bottom, minf(a.y, b.y))
	return top - bottom if top > bottom else 0.0


## Oculta la cabeza del rig (cuerpo del jugador en 1ª persona): colapsa el hueso "head" a escala ~0
## después de que la animación actualice la pose (nodo con prioridad alta de proceso).
func hide_head() -> void:
	use_tree(false)  # el cuerpo del jugador en 1.ª persona sigue con el AnimationPlayer (manos y cámara calibradas)
	var skel: Skeleton3D = null
	for c in find_children("*", "Skeleton3D", true, false):
		skel = c
	if skel == null:
		return
	var idx := -1
	for name in ["head", "Head", "cabeza", "neck_01", "neck"]:
		idx = skel.find_bone(name)
		if idx >= 0:
			break
	if idx < 0:
		return
	var h := _HeadHider.new()
	h.name = "OcultaCabeza"
	h.skeleton = skel
	h.bone = idx
	h.process_priority = 1000
	add_child(h)


class _HeadHider extends Node:
	var skeleton: Skeleton3D = null
	var bone: int = -1

	func _process(_delta: float) -> void:
		if skeleton != null and bone >= 0:
			skeleton.set_bone_pose_scale(bone, Vector3(0.001, 0.001, 0.001))


## Modelo GLB de un agente jugable (v2: cada uno tiene el suyo, también Llauri).
static func agent_model(agent: String) -> String:
	var slug := agent.to_lower()
	return str(AGENT_MODELS.get(slug, "agente_" + slug))


## Tiñe la ropa/pelaje (materiales "outfit" y los que caen al atlas de ropa) multiplicando el albedo.
## Los modelos v2 no se tiñen (la cara va en el mismo atlas que la ropa y ya traen el color de cada uno).
func tint_outfit(color: Color) -> void:
	if is_v2:
		if model_name == "perrito_rta":  # el perro del paradero: pelaje blanco del RTA multiplicado (otro perro)
			for m in find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				for i in (mi.mesh.get_surface_count() if mi.mesh != null else 0):
					var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
					if src != null:
						var mat := src.duplicate() as BaseMaterial3D
						mat.albedo_color = color.lightened(0.25)
						mi.set_surface_override_material(i, mat)
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var src := mi.mesh.surface_get_material(i)
			var mname := src.resource_name.to_lower() if src != null else ""
			if mname in ["skin", "eye", "hair", "face", "glass", "screen", "bulb"]:
				continue
			mat.albedo_color = color


## v0.3.1 Q2 (F8): rig de terror del modelo (ScreamRig: cara deformada por shader + mandíbula, agarre con los dos
## brazos, mirada fija). Se crea la primera vez.
func scream_rig() -> ScreamRig:
	return ScreamRig.attach(self, model_name)


## Deformación de la cara 0..1 (0 = normal). La anima cada fila de screamer; también la usan Haime y las pruebas.
func set_deform(k: float) -> void:
	var r := scream_rig()
	if r != null:
		r.deform = clampf(k, 0.0, 1.0)


func get_deform() -> float:
	var r: ScreamRig = null
	for c in find_children("*", "ScreamRig", true, false):
		r = c
	return r.deform if r != null else 0.0


## Severidad de la cara 0..3 (Haime en el feedback: cada oportunidad la endurece).
func set_severity(level: int) -> void:
	var r := scream_rig()
	if r != null:
		r.severity = clampf(level / 3.0, 0.0, 1.0)


## Huesos de los brazos (para "sit_type": brazos del clip type sobre el cuerpo sentado del clip sit).
const ARM_BONES: Array[String] = ["clavicle", "upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb"]
const STAND_S := 0.9


## v0.3.1 Q2 (F19): clips de escritorio armados en tiempo real con los del GLB (sin reexportar):
##   stand_up (0,9 s, de la pose de "sit" a la de "idle", con el torso que se inclina al pararse), sit_down (al revés)
##   y sit_type (sentado tecleando: cuerpo de "sit", brazos de "type"). Devuelve true si existen.
func ensure_desk_clips() -> bool:
	return CharacterRig.desk_clips(anim)


## Igual para cualquier AnimationPlayer de un GLB v2 (P5Actor de Rasec).
static func desk_clips(anim: AnimationPlayer) -> bool:
	if anim == null or not anim.has_animation("sit") or not anim.has_animation("idle"):
		return false
	if anim.has_animation("stand_up"):
		return true
	var lib := anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	var sit := anim.get_animation("sit")
	var idle := anim.get_animation("idle")
	lib.add_animation("stand_up", _blend_clip(sit, idle, STAND_S, true))
	lib.add_animation("sit_down", _blend_clip(idle, sit, STAND_S, false))
	if anim.has_animation("type"):
		lib.add_animation("sit_type", _merge_arms(sit, anim.get_animation("type")))
	return true


## Clip de `a` (su primer fotograma) a `b` en `len` s; `lean` = el torso se va adelante a mitad de camino.
static func _blend_clip(a: Animation, b: Animation, length: float, lean: bool) -> Animation:
	var out := Animation.new()
	out.length = length
	out.loop_mode = Animation.LOOP_NONE
	for i in a.get_track_count():
		var path := a.track_get_path(i)
		var typ := a.track_get_type(i)
		var j := b.find_track(path, typ)
		if j < 0 or a.track_get_key_count(i) == 0:
			continue
		var t := out.add_track(typ)
		out.track_set_path(t, path)
		var bone := str(path.get_concatenated_subnames())
		match typ:
			Animation.TYPE_ROTATION_3D:
				var q0 := a.rotation_track_interpolate(i, 0.0)
				var q1 := b.rotation_track_interpolate(j, 0.0)
				var mid := q0.slerp(q1, 0.5)
				if lean and bone in ["spine_01", "spine_02"]:
					mid = mid * Quaternion(Vector3.RIGHT, deg_to_rad(18.0))
				out.rotation_track_insert_key(t, 0.0, q0)
				out.rotation_track_insert_key(t, length * 0.45, mid)
				out.rotation_track_insert_key(t, length, q1)
			Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(t, 0.0, a.position_track_interpolate(i, 0.0))
				out.position_track_insert_key(t, length, b.position_track_interpolate(j, 0.0))
			Animation.TYPE_SCALE_3D:
				out.scale_track_insert_key(t, 0.0, a.scale_track_interpolate(i, 0.0))
				out.scale_track_insert_key(t, length, b.scale_track_interpolate(j, 0.0))
			_:
				out.remove_track(t)
	return out


## Sentado tecleando: copia "sit" y cambia las pistas de los brazos por las de "type" (en bucle).
static func _merge_arms(sit: Animation, typing: Animation) -> Animation:
	var out := sit.duplicate(true) as Animation
	out.length = maxf(typing.length, 0.5)
	out.loop_mode = Animation.LOOP_LINEAR
	for i in range(out.get_track_count() - 1, -1, -1):
		var bone := str(out.track_get_path(i).get_concatenated_subnames())
		for ab in ARM_BONES:
			if bone.begins_with(ab):
				out.remove_track(i)
				break
	for i in typing.get_track_count():
		var path := typing.track_get_path(i)
		var bone := str(path.get_concatenated_subnames())
		var arm := false
		for ab in ARM_BONES:
			if bone.begins_with(ab):
				arm = true
		if not arm:
			continue
		var typ := typing.track_get_type(i)
		var t := out.add_track(typ)
		out.track_set_path(t, path)
		for k in typing.track_get_key_count(i):
			out.track_insert_key(t, typing.track_get_key_time(i, k), typing.track_get_key_value(i, k))
	return out


## Posición global del hueso de la cabeza (o el 90 % de la altura si no hay esqueleto).
func head_position() -> Vector3:
	for c in find_children("*", "Skeleton3D", true, false):
		var sk := c as Skeleton3D
		var hb := sk.find_bone("head")
		if hb >= 0:
			return sk.global_transform * sk.get_bone_global_pose(hb).origin
	return global_position + Vector3(0, 1.6, 0)


func has_anim(p_name: String) -> bool:
	if animator != null and animator.has_clip(p_name):
		return true
	return anim != null and anim.has_animation(p_name)


## Apaga (false) o deja el AnimationTree: sin él vuelve el AnimationPlayer del GLB con los clips viejos.
func use_tree(on: bool) -> void:
	if on or animator == null:
		return
	var was := current
	if animator.tree != null:
		animator.tree.active = false
		animator.tree.queue_free()
	if anim != null:
		anim.active = true
	animator.queue_free()
	animator = null
	current = ""
	# lo que se había pedido por el árbol sigue por el AnimationPlayer (player.gd pide play("idle") ANTES de hide_head():
	# sin esto el cuerpo del jugador quedaba congelado, sin clip, hasta la primera vez que se sentaba)
	if was != "":
		play(was)


## Reproduce un clip (bucle por defecto). Si no existe, prueba las alternativas y si no, no hace nada.
func play(p_name: String, loop: bool = true, speed: float = 1.0, alternatives: Array = []) -> void:
	if animator != null:
		if animator.play(p_name, loop, speed, alternatives):
			current = animator.current
		return
	if anim == null:
		return
	var chosen := ""
	for n in [p_name] + alternatives:
		if anim.has_animation(str(n)):
			chosen = str(n)
			break
	if chosen == "":
		return
	var a := anim.get_animation(chosen)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if current == chosen and anim.is_playing():
		return
	current = chosen
	anim.play(chosen, 0.2, speed)


func stop() -> void:
	if anim != null:
		anim.stop()
	current = ""

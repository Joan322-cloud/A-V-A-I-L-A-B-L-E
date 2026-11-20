class_name ScreamRig
extends SkeletonModifier3D
## Rig de terror de los modelos v2 (v0.3.1 Q2, F8/F2/F6): se cuelga del Skeleton3D de un modelo y, después de
## la animación, deforma la cara y mueve los brazos y la cabeza:
##   deform (0..1)   — la cara se deforma (shader assets/shaders/cara_deforme.gdshader: mandíbula imposible, cráneo
##                     estirado, ojos hinchados y negros con pupila roja, carne que tiembla) + mandíbula por hueso en
##                     los modelos que tienen vértices en "jaw" (Rasec, Haime, Trainer, Don Fermín, Perrito RTA),
##                     cuello que se estira y cabeza que tiembla.
##   severity (0..1) — la cara se pone seria/terrorífica sin deformarse (Haime en cada oportunidad del feedback).
##   grab (0..1) + grab_l / grab_r (puntos globales) — agarre con los dos brazos (IK analítico de 2 huesos y dedos
##                     en garra): las manos te toman la cabeza a los lados de la cámara.
##   look (0..1) + look_at_point (global) — la cabeza (y el cuello) giran a mirarte de frente.
## La API pública para los personajes es CharacterRig.set_deform()/scream_rig(); Screamers la usa con los modelos
## que pone frente a la cámara (ScreamRig.attach(modelo, slug)).
## Rendimiento: un ShaderMaterial por superficie (≤ 4 por modelo), uniformes por fotograma; ScreamRig.prewarm()
## compila el shader al cargar un piso (sin tirón en el primer screamer).

const SHADER_PATH := "res://assets/shaders/cara_deforme.gdshader"
## Puntos de la cara en el espacio del esqueleto del GLB (sin escalar), medidos con vistas ortográficas
## (qa_q2/lab/ortho.gd): ojos, radio del ojo, centro de la boca, medio ancho de la boca, mentón, coronilla, plano
## de la cara (z). Los GLB miran a +Z.
const FACES: Dictionary = {
	"shero": {"eye": Vector3(0.10, 2.235, 0.175), "eye_rad": 0.05, "mouth": Vector3(0.0, 1.972, 0.16), "mouth_hw": 0.12, "chin": 1.915, "top": 2.46, "face_z": 0.13, "jaw_bone": false},
	"rasec": {"eye": Vector3(0.03, 1.688, 0.135), "eye_rad": 0.022, "mouth": Vector3(0.0, 1.618, 0.15), "mouth_hw": 0.03, "chin": 1.585, "top": 1.80, "face_z": 0.11, "jaw_bone": true},
	"haime": {"eye": Vector3(0.03, 1.643, 0.13), "eye_rad": 0.02, "mouth": Vector3(0.0, 1.585, 0.145), "mouth_hw": 0.026, "chin": 1.553, "top": 1.79, "face_z": 0.11, "jaw_bone": true},
	"trainer": {"eye": Vector3(0.032, 1.645, 0.13), "eye_rad": 0.02, "mouth": Vector3(0.0, 1.597, 0.15), "mouth_hw": 0.034, "chin": 1.548, "top": 1.765, "face_z": 0.11, "jaw_bone": true},
	"guardia_fermin": {"eye": Vector3(0.03, 1.617, 0.13), "eye_rad": 0.018, "mouth": Vector3(0.0, 1.565, 0.15), "mouth_hw": 0.026, "chin": 1.533, "top": 1.72, "face_z": 0.11, "jaw_bone": true},
	"perrito_rta": {"eye": Vector3(0.046, 0.555, 0.35), "eye_rad": 0.022, "mouth": Vector3(0.0, 0.47, 0.42), "mouth_hw": 0.045, "chin": 0.44, "top": 0.64, "face_z": 0.3, "jaw_bone": true, "stretch": 0.05, "jaw_drop": 0.5, "eye_bulge": 0.45},
	# v0.3.2e: GRASA medido otra vez sobre el modelo v2 (hueso del ojo a y = 2,741; la fila vieja, de otro modelo, ponía
	# su cara 54 cm más abajo: el agarre encuadraba su pecho y la cámara terminaba dentro de él). "top" es el cráneo, sin
	# las orejas (3,03).
	"grasa": {"eye": Vector3(0.045, 2.74, 0.205), "eye_rad": 0.03, "mouth": Vector3(0.0, 2.635, 0.225), "mouth_hw": 0.05, "chin": 2.585, "top": 2.91, "face_z": 0.175, "jaw_bone": true},
}
## Ángulo extra de la mandíbula por hueso (grados, eje X local) a deform = 1.
const JAW_DEG := 52.0
const FACE_STYLE: Dictionary = {"shero": 1, "rasec": 2, "haime": 3, "trainer": 4, "guardia_fermin": 5, "grasa": 6, "perrito_rta": 7, "vitzo": 8}  # v0.3.2: mandíbula desencajada (38 en v0.3.1)

var slug: String = ""
var deform: float = 0.0
var severity: float = 0.0
var tremor: float = 1.0
var grab: float = 0.0
var grab_l: Vector3 = Vector3.ZERO
var grab_r: Vector3 = Vector3.ZERO
var look: float = 0.0
var look_at_point: Vector3 = Vector3.ZERO
## v0.3.1 (muertes propias): peso de cada mano en el agarre (0 = ese brazo sigue la animación), cuánto se cierran los
## dedos (1 = garra, 0 = mano abierta y plana, < 0 = dedos estirados hacia atrás) y estiramiento de los brazos
## (1 = normal; Vitzo 1,5: brazos larguísimos).
var grab_w_l: float = 1.0
var grab_w_r: float = 1.0
var claw: float = 1.0
var arm_stretch: float = 1.0
## v0.3.2d (manos que agarran, fx/kill_hands.gd): por mano, el punto del mundo al que mira la palma (INF = la mano
## sigue al antebrazo, como antes) y el agarre de los dedos (nombre de KillHands.GRIPS; "" = la garra de `claw`).
var palm_l: Vector3 = Vector3.INF
var palm_r: Vector3 = Vector3.INF
var grip_l: String = ""
var grip_r: String = ""
var last_elbow_l: Vector3 = Vector3.INF
var last_elbow_r: Vector3 = Vector3.INF
var _kh: Dictionary = {}
var head_tilt: float = 0.0  # ladea la cabeza (rad, sobre la mirada): Vitzo asomándose sobre el divisor
var soft: bool = false
var gore: float = 0.0  # v0.3.2: sangre, moretones, piel rasgada y ojos inyectados (KillGore.face; 0 con Reducido)
var gore_detail: float = 1.0
var jaw_min_deg: float = 0.0  # v0.3.2e: piso de apertura de la mandíbula por hueso (grados, +X local): el grito con un clip de cuerpo puesto
var jaw_mult: float = 1.35  # v0.3.2: mandíbula desencajada (KillMoves._jaw la abre más: «mandíbula super abierta»)  # 0 en Modo liviano/Baja: solo chorros y manchas (sin el ruido del shader)

var _mats: Array[ShaderMaterial] = []
var _meshes: Array[MeshInstance3D] = []
var _orig: Array = []  # [MeshInstance3D, surface, override anterior]
var _bones: Dictionary = {}
var _head_rest: Transform3D = Transform3D.IDENTITY
var _face: Dictionary = {}
var _t: float = 0.0
var _tick: float = 0.0
var _jit: Vector3 = Vector3.ZERO
## Medido en el último fotograma (las poses de un SkeletonModifier3D no quedan guardadas en el esqueleto): para pruebas.
var last_jaw_deg: float = 0.0
var last_hand_l: Vector3 = Vector3.INF
var last_hand_r: Vector3 = Vector3.INF
## Centro de la cara (entre los ojos y la boca) en el mundo, con el cuello estirado: lo calcula la modificación
## (las poses no quedan guardadas después del fotograma). Vector3.INF si no hay cara.
var last_face: Vector3 = Vector3.INF
static var _shader: Shader = null


## Cuelga el rig del primer Skeleton3D de `model` y cambia sus materiales por el shader de la cara.
static func attach(model: Node, p_slug: String) -> ScreamRig:
	if model == null:
		return null
	for c in model.find_children("*", "ScreamRig", true, false):
		return c as ScreamRig
	var sk: Skeleton3D = null
	for c in model.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	if sk == null:
		return null
	var r := ScreamRig.new()
	r.name = "ScreamRig"
	r.slug = p_slug
	sk.add_child(r)
	r._setup(model, sk)
	return r


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## Compila el shader de la cara (y su variante con textura de grito) dibujando un quad fuera de vista unos
## fotogramas: el primer screamer no paga la compilación (Calidad Baja: ningún tirón > 100 ms).
static func prewarm(parent: Node3D) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cam := parent.get_viewport().get_camera_3d()
	if cam == null:
		return
	var node := Node3D.new()
	node.name = "PrecalentarShaderCara"
	parent.add_child(node)
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.002, 0.002)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = shader()
		m.set_shader_parameter("has_scream_tex", i == 1)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		mi.global_position = cam.global_position - cam.global_transform.basis.z * 0.3 + Vector3(0, -0.2 + i * 0.01, 0)
	await parent.get_tree().create_timer(0.25, true, false, true).timeout
	if is_instance_valid(node):
		node.queue_free()


func _setup(model: Node, sk: Skeleton3D) -> void:
	_face = (FACES.get(slug, {}) as Dictionary).duplicate()
	var extra: Dictionary = (DataLoader.dict("screamers").get("caras", {}) as Dictionary).get(slug, {})
	for k in extra.keys():
		var v: Variant = extra[k]
		_face[k] = Vector3(v[0], v[1], v[2]) if v is Array and (v as Array).size() == 3 else v
	for b in ["head", "neck_01", "neck", "jaw", "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "spine_03", "chest"]:
		_bones[b] = sk.find_bone(b)
	# Perrito RTA: las patas delanteras hacen de brazos (se te sube por las piernas, te clava las patas).
	for side in ["l", "r"]:
		if int(_bones["upperarm_" + side]) < 0 and sk.find_bone("fl_up_" + side) >= 0:
			_bones["upperarm_" + side] = sk.find_bone("fl_up_" + side)
			_bones["lowerarm_" + side] = sk.find_bone("fl_lo_" + side)
			_bones["hand_" + side] = sk.find_bone("fl_paw_" + side)
	if int(_bones["neck_01"]) < 0:
		_bones["neck_01"] = _bones["neck"]
	var hb := int(_bones["head"])
	if hb >= 0:
		_head_rest = sk.get_bone_global_rest(hb)
	for side2 in ["l", "r"]:
		_kh[side2] = KillHands.setup(sk, side2)
	soft = bool(Loc.get_setting("flash_reduction", false))
	if _face.is_empty():
		return  # sin puntos de cara (Vitzo: su cara es la pantalla, VitzoGlitch la rompe): solo huesos
	var scream: Texture2D = Faces.texture_at(CharacterRig.TEX_DIR + slug + "_cara_grito.jpg")
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		_meshes.append(mi)
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = shader()
			sm.set_shader_parameter("albedo_tex", src.albedo_texture)
			sm.set_shader_parameter("albedo_color", src.albedo_color)
			sm.set_shader_parameter("roughness_v", src.roughness)
			sm.set_shader_parameter("metallic_v", src.metallic)
			if src.emission_enabled:
				sm.set_shader_parameter("emission_color", src.emission)
				sm.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
			var nm := src.resource_name
			var is_face := not (nm.ends_with("_pelo") or nm.ends_with("_brillo"))
			sm.set_shader_parameter("face_surface", is_face)
			if nm.ends_with("_cara") and scream != null:
				sm.set_shader_parameter("scream_tex", scream)
				sm.set_shader_parameter("has_scream_tex", true)
			var e: Vector3 = _face["eye"]
			sm.set_shader_parameter("eye_l", e)
			sm.set_shader_parameter("eye_r", Vector3(-e.x, e.y, e.z))
			sm.set_shader_parameter("eye_rad", float(_face["eye_rad"]))
			sm.set_shader_parameter("mouth", _face["mouth"])
			sm.set_shader_parameter("mouth_hw", float(_face["mouth_hw"]))
			sm.set_shader_parameter("chin_y", float(_face["chin"]))
			sm.set_shader_parameter("top_y", float(_face["top"]))
			sm.set_shader_parameter("face_z", float(_face["face_z"]))
			sm.set_shader_parameter("soft", 1.0 if soft else 0.0)
			sm.set_shader_parameter("head_binds", _binds(mi, sk))
			sm.set_shader_parameter("skull_stretch", float(_face.get("stretch", 0.32)))
			sm.set_shader_parameter("jaw_drop", float(_face.get("jaw_drop", 0.55)))
			# kills2: cuánto se hinchan los ojos (por defecto 1,7; el Perrito 0,45: con los ojos como globos no se leía un perro)
			sm.set_shader_parameter("eye_bulge", float(_face.get("eye_bulge", 1.7)))
			sm.set_shader_parameter("face_style", int(FACE_STYLE.get(slug, 0)))
			sm.set_meta("mesh", mi)
			_orig.append([mi, i, mi.get_surface_override_material(i)])
			mi.set_surface_override_material(i, sm)
			_mats.append(sm)


## Índices del skin de la malla para los huesos de la cabeza (head, jaw, eye_l, eye_r).
func _binds(mi: MeshInstance3D, sk: Skeleton3D) -> Vector4i:
	var out: Array[int] = [-1, -1, -1, -1]
	var want := ["head", "jaw", "eye_l", "eye_r"]
	var skin := mi.skin
	for i in skin.get_bind_count():
		var bn := str(skin.get_bind_name(i))
		if bn == "":
			var bb := skin.get_bind_bone(i)
			bn = sk.get_bone_name(bb) if bb >= 0 else ""
		var w := want.find(bn)
		if w >= 0:
			out[w] = i
	return Vector4i(out[0], out[1], out[2], out[3])


## Devuelve los materiales originales (el modelo queda como antes).
func detach() -> void:
	for o in _orig:
		var mi := o[0] as MeshInstance3D
		if is_instance_valid(mi):
			mi.set_surface_override_material(int(o[1]), o[2])
	_orig.clear()
	_mats.clear()
	queue_free()


func has_face_shader() -> bool:
	return not _mats.is_empty()


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_t += delta
	var k := clampf(deform, 0.0, 1.0)
	var hb := int(_bones["head"])
	# Temblor de la cabeza (cuantizado a 20 Hz): crece con la deformación.
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.05
		_jit = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	var neck := int(_bones["neck_01"])
	if neck >= 0 and k > 0.0:
		# Cuello que se estira (la cabeza no hereda la escala: se compensa, si no quedaba un cono).
		var ns := Vector3(1.0 - 0.12 * k, 1.0 + 0.45 * k, 1.0 - 0.12 * k)
		sk.set_bone_pose_scale(neck, sk.get_bone_pose_scale(neck) * ns)
		if hb >= 0 and sk.get_bone_parent(hb) == neck:
			sk.set_bone_pose_scale(hb, sk.get_bone_pose_scale(hb) / ns)
	# Mirar a la cámara (cuello 40 %, cabeza 60 %), antes del temblor.
	if look > 0.001 and hb >= 0:
		_aim_head(sk, hb, neck)
	if hb >= 0 and (k > 0.0 or severity > 0.0):
		var amp := deg_to_rad(9.0) * k * tremor * (0.35 if soft else 1.0) + deg_to_rad(0.8) * severity
		var q := Quaternion(Vector3.RIGHT, _jit.x * amp) * Quaternion(Vector3.UP, _jit.y * amp * 0.6) * Quaternion(Vector3.BACK, _jit.z * amp)
		sk.set_bone_pose_rotation(hb, sk.get_bone_pose_rotation(hb) * q)
	var jb := int(_bones["jaw"])
	if jb >= 0 and jaw_min_deg > 0.0:
		# La boca abierta del grito cuando la animación «scream» del GLB no corre (hay un clip de cuerpo): si el clip la
		# abre menos que el piso, el piso (con el temblor de quien grita).
		var jrest := sk.get_bone_rest(jb).basis.get_rotation_quaternion()
		var jrel := jrest.inverse() * sk.get_bone_pose_rotation(jb)
		var open_now := wrapf(2.0 * atan2(jrel.x, jrel.w), -PI, PI)
		var open_min := deg_to_rad(jaw_min_deg) * (0.9 + 0.1 * sin(_t * 23.0))
		if open_now < open_min:
			sk.set_bone_pose_rotation(jb, jrest * Quaternion(Vector3.RIGHT, open_min))
	if jb >= 0 and bool(_face.get("jaw_bone", false)) and k > 0.0:
		var open := deg_to_rad(JAW_DEG) * k * (0.85 + 0.15 * sin(_t * 31.0))
		sk.set_bone_pose_rotation(jb, sk.get_bone_pose_rotation(jb) * Quaternion(Vector3.RIGHT, open))
		last_jaw_deg = rad_to_deg(sk.get_bone_pose_rotation(jb).angle_to(sk.get_bone_rest(jb).basis.get_rotation_quaternion()))
		sk.set_bone_pose_scale(jb, sk.get_bone_pose_scale(jb) * Vector3(1.0 + 0.25 * k, 1.0 + 0.6 * k, 1.0 + 0.25 * k))
	if absf(arm_stretch - 1.0) > 0.01:
		for b2 in ["upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r"]:
			var bi := int(_bones[b2])
			if bi >= 0:
				sk.set_bone_pose_scale(bi, sk.get_bone_pose_scale(bi) * Vector3(1.0, arm_stretch, 1.0))
	if grab > 0.001:
		if grab_w_l > 0.001:
			_arm(sk, "l", grab_l)
		if grab_w_r > 0.001:
			_arm(sk, "r", grab_r)
		_claws(sk)
		var to_sk := sk.global_transform.affine_inverse()
		for side in ["l", "r"]:
			var hb2 := int(_bones["hand_" + side])
			if hb2 < 0:
				continue
			var wv := clampf(grab, 0.0, 1.0) * clampf(grab_w_l if side == "l" else grab_w_r, 0.0, 1.0)
			var palm: Vector3 = palm_l if side == "l" else palm_r
			var hp := sk.global_transform * sk.get_bone_global_pose(hb2).origin
			var inf: Dictionary = _kh.get(side, {})
			if palm != Vector3.INF and wv > 0.001 and not inf.is_empty() and not (inf["fingers"] as Dictionary).is_empty():
				KillHands.orient(sk, inf, to_sk.basis * (palm - hp), Vector3.INF, wv)
			var lb := int(_bones["lowerarm_" + side])
			if side == "l":
				last_hand_l = hp
				last_elbow_l = sk.global_transform * sk.get_bone_global_pose(lb).origin if lb >= 0 else Vector3.INF
			else:
				last_hand_r = hp
				last_elbow_r = sk.global_transform * sk.get_bone_global_pose(lb).origin if lb >= 0 else Vector3.INF
	_update_uniforms(sk, hb)


## Uniformes del shader: el paso de la pose actual de la cabeza a su reposo, por malla.
func _update_uniforms(sk: Skeleton3D, hb: int) -> void:
	if _mats.is_empty() or hb < 0:
		return
	var cur := sk.get_bone_global_pose(hb)
	var rest_from_pose_sk := _head_rest * cur.affine_inverse()
	var cache: Dictionary = {}
	for m in _mats:
		var mi := m.get_meta("mesh") as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var pair: Array
		if cache.has(mi):
			pair = cache[mi]
		else:
			var to_sk := sk.global_transform.affine_inverse() * mi.global_transform  # malla → esqueleto
			var rp := to_sk.affine_inverse() * rest_from_pose_sk * to_sk
			pair = [Projection(rp), Projection(rp.affine_inverse())]
			cache[mi] = pair
			if cache.size() == 1 and not _face.is_empty():
				var e: Vector3 = _face["eye"]
				var mo: Vector3 = _face["mouth"]
				var center := Vector3(0.0, (e.y + mo.y) * 0.5, float(_face.get("face_z", e.z)))
				last_face = mi.global_transform * (rp.affine_inverse() * center)
		m.set_shader_parameter("rest_from_pose", pair[0])
		m.set_shader_parameter("pose_from_rest", pair[1])
		m.set_shader_parameter("deform", clampf(deform, 0.0, 1.0))
		m.set_shader_parameter("severity", clampf(severity, 0.0, 1.0))
		m.set_shader_parameter("tremor", tremor)
		m.set_shader_parameter("gore", clampf(gore, 0.0, 1.0))
		m.set_shader_parameter("gore_detail", gore_detail)
		m.set_shader_parameter("jaw_mult", jaw_mult)


## Gira cuello y cabeza para que la cara apunte a look_at_point (cuello 40 % del giro, la cabeza el resto).
func _aim_head(sk: Skeleton3D, hb: int, neck: int) -> void:
	var target: Vector3 = sk.global_transform.affine_inverse() * look_at_point
	var lw := clampf(look, 0.0, 1.0)
	for pair in [[neck, 0.4], [hb, 1.0]]:
		var b := int(pair[0])
		if b < 0:
			continue
		var g := sk.get_bone_global_pose(b)
		var hg := sk.get_bone_global_pose(hb)
		var fwd := (hg.basis * (_head_rest.basis.inverse() * Vector3.BACK)).normalized()  # la cara mira a +Z en reposo
		var want := target - hg.origin
		if want.length() < 0.05:
			continue
		want = want.normalized()
		var ang := fwd.angle_to(want)
		var axis := fwd.cross(want)
		if ang < 0.001 or axis.length() < 0.0001:
			continue
		var q := Quaternion(axis.normalized(), minf(ang, deg_to_rad(85.0)) * float(pair[1]) * lw)
		var nb := Basis(q) * g.basis
		if b == hb:
			# Sin ladear la cabeza: el "arriba" de la cara vuelve hacia el arriba del esqueleto (gira sobre la mirada).
			var f2 := (nb * (_head_rest.basis.inverse() * Vector3.BACK)).normalized()
			var up_now := nb * (_head_rest.basis.inverse() * Vector3.UP)
			var up_want := Vector3.UP
			up_now = (up_now - f2 * up_now.dot(f2)).normalized()
			up_want = (up_want - f2 * up_want.dot(f2)).normalized()
			if up_now.length() > 0.5 and up_want.length() > 0.5:
				var roll := up_now.signed_angle_to(up_want, f2)
				nb = Basis(f2, roll * lw * 0.85) * nb
			if absf(head_tilt) > 0.001:
				nb = Basis(f2, head_tilt) * nb
		sk.set_bone_global_pose(b, Transform3D(nb, g.origin))


## Brazo con IK analítico (hombro-codo-mano): la mano va al punto `target` (global), el codo hacia afuera y abajo.
func _arm(sk: Skeleton3D, side: String, target_g: Vector3) -> void:
	var ua := int(_bones["upperarm_" + side])
	var la := int(_bones["lowerarm_" + side])
	var ha := int(_bones["hand_" + side])
	if ua < 0 or la < 0 or ha < 0:
		return
	var w := clampf(grab, 0.0, 1.0) * clampf(grab_w_l if side == "l" else grab_w_r, 0.0, 1.0)
	var target: Vector3 = sk.global_transform.affine_inverse() * target_g
	var gu := sk.get_bone_global_pose(ua)
	var gl := sk.get_bone_global_pose(la)
	var gh := sk.get_bone_global_pose(ha)
	var s := gu.origin
	var l1 := s.distance_to(gl.origin)
	var l2 := gl.origin.distance_to(gh.origin)
	var to := target - s
	var d := clampf(to.length(), 0.05, (l1 + l2) * 0.98)
	var dir := to.normalized()
	# Codo: hacia afuera del cuerpo y un poco abajo.
	var out := Vector3(1.0 if side == "l" else -1.0, -0.6, -0.2)
	var pole := (out - dir * out.dot(dir)).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hgt := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var elbow := s + dir * a + pole * hgt
	var cur_u := (gu.basis.y).normalized()
	var want_u := (elbow - s).normalized()
	var qu := Quaternion(cur_u, want_u) if cur_u.dot(want_u) < 0.9999 else Quaternion.IDENTITY
	qu = Quaternion.IDENTITY.slerp(qu, w)
	sk.set_bone_global_pose(ua, Transform3D(Basis(qu) * gu.basis, gu.origin))
	gl = sk.get_bone_global_pose(la)
	var cur_l := (gl.basis.y).normalized()
	var want_l := (s + dir * d - gl.origin).normalized() if w >= 0.999 else ((s + dir * d) - gl.origin).normalized()
	var ql := Quaternion(cur_l, want_l) if cur_l.dot(want_l) < 0.9999 else Quaternion.IDENTITY
	ql = Quaternion.IDENTITY.slerp(ql, w)
	sk.set_bone_global_pose(la, Transform3D(Basis(ql) * gl.basis, gl.origin))


## Dedos en garra (se curvan hacia la palma; claw < 1 los abre: mano plana que tapa una boca o unos ojos).
## Vitzo: tres dedos (f0..f2).
func _claws(sk: Skeleton3D) -> void:
	for side in ["l", "r"]:
		var w := clampf(grab, 0.0, 1.0) * clampf(grab_w_l if side == "l" else grab_w_r, 0.0, 1.0)
		if w <= 0.001:
			continue
		var grip: String = grip_l if side == "l" else grip_r
		if grip != "" and not (_kh.get(side, {}) as Dictionary).is_empty():
			KillHands.curl(sk, _kh[side], grip, w, 0.6 if grip == "garra" else 0.0)
			continue
		var ang := deg_to_rad(38.0) * w * clampf(claw, -0.5, 1.4)
		for f in ["index", "middle", "ring", "pinky"]:
			for j in [1, 2, 3]:
				var b := sk.find_bone("%s_0%d_%s" % [f, j, side])
				if b >= 0:
					sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3.RIGHT, ang))
		for j in 3:
			var b3 := sk.find_bone("f%d_%s" % [j, side])
			if b3 >= 0:
				sk.set_bone_pose_rotation(b3, sk.get_bone_pose_rotation(b3) * Quaternion(Vector3.RIGHT, ang * 1.3))

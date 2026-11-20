class_name KillVictim
extends Node3D
## TÚ en primera persona durante una muerte (v0.3.2d, la barra nueva de Joan: «la víctima forcejea con tiempos
## creíbles… manos que de verdad agarran»). Reemplaza a las manos de cápsulas de KillGore.own_hands: es el modelo de
## TU agente (su piel, sus mangas, sus dedos) colgado de tu vista con un shader que solo deja ver los brazos (o, con
## show_body, todo menos la cabeza: te ves las piernas colgando o pataleando).
##   · Cada mano va a un objetivo con un resorte (se pasa y asienta: no se mueve «en riel»), la palma mira a donde
##     agarra o empuja (KillHands.orient) y los dedos se cierran según el agarre (KillHands.GRIPS).
##   · Los objetivos se dan en el espacio de la vista (KillMoves.L(x derecha, y arriba, f adelante)) o pegados a un
##     punto del mundo que se recalcula cada cuadro (la muñeca del asesino, el lanyard, la hoja en tu cara).
##   · struggle(): temblor y tirones del forcejeo; strength baja cuando te mueres (las manos pierden fuerza y caen).
##   · Heridas (moretones, cortes; no con «Reducido»), venas verdes y piel verde (la fusión de Vitzo).
## Uso (KillMoves): var v := KillVictim.of(fx); v.put("l", L(-0.12, -0.2, 0.3), "garra", L(0, -0.1, 0.5)); v.drop()
## Costo: un GLB de agente más (sin sombras), dos IK de brazo; en Modo liviano igual (es una sola malla).

const EYE_LOCAL := Vector3(0.0, 0.075, -0.1)  # de la base de la cabeza (hueso) a los ojos: arriba y adelante (-Z)
## Capa de render de tus brazos: la luz de cara del screamer (a 12 cm de tus ojos) no los ilumina (los quemaba a blanco);
## las demás luces sí.
const LAYER := 1 << 9
const SHADER_CODE := """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform ivec4 arm_mask = ivec4(0);
uniform ivec4 head_mask = ivec4(0);
uniform float show_body = 0.0;
uniform vec4 skin_ref : source_color = vec4(0.7, 0.5, 0.45, 1.0);
uniform float wounds = 0.0;
uniform float veins = 0.0;
uniform float green = 0.0;
uniform float blood = 0.0;
varying float keep;
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() {
	float wa = 0.0;
	float wh = 0.0;
	for (int j = 0; j < 4; j++) {
		int bi = int(BONE_INDICES[j]);
		if (bi >= 0 && bi < 128) {
			int w = bi >> 5;
			int b = bi & 31;
			if (((arm_mask[w] >> b) & 1) == 1) { wa += BONE_WEIGHTS[j]; }
			if (((head_mask[w] >> b) & 1) == 1) { wh += BONE_WEIGHTS[j]; }
		}
	}
	keep = mix(wa, 1.0 - wh, show_body);
	lp = VERTEX;
}
void fragment() {
	if (keep < 0.5) { discard; }
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float mx = max(c.r, max(c.g, c.b));
	vec3 nc = c / max(mx, 0.001);
	vec3 nr = skin_ref.rgb / max(skin_ref.r, max(skin_ref.g, skin_ref.b));
	float skin = (1.0 - smoothstep(0.10, 0.24, distance(nc, nr))) * smoothstep(0.14, 0.28, mx);
	float rough = 0.8;
	if (wounds > 0.01) {
		float b = smoothstep(0.55, 0.75, n3(lp * 38.0 + vec3(3.0)));
		c = mix(c, vec3(0.32, 0.16, 0.3), b * 0.7 * wounds * skin);
		float cut = 1.0 - smoothstep(0.0, 0.035, abs(n3(lp * vec3(14.0, 60.0, 14.0)) - 0.5));
		c = mix(c, vec3(0.32, 0.0, 0.01), cut * 0.9 * wounds * skin);
		rough = mix(rough, 0.25, cut * wounds * skin);
	}
	if (blood > 0.01) {
		float sp = smoothstep(0.62 - 0.3 * blood, 0.7 - 0.3 * blood, n3(lp * 46.0 + vec3(7.0)));
		c = mix(c, vec3(0.3, 0.0, 0.01), sp * blood);
		rough = mix(rough, 0.2, sp * blood);
	}
	if (veins > 0.001) {
		float v = 1.0 - smoothstep(0.0, 0.05, abs(n3(lp * vec3(46.0, 120.0, 46.0)) - 0.5));
		c = mix(c, vec3(0.03, 0.3, 0.1), v * clamp(veins * 1.3, 0.0, 1.0) * skin);
	}
	if (green > 0.001) {
		float l = dot(c, vec3(0.3, 0.59, 0.11)) / max(dot(skin_ref.rgb, vec3(0.3, 0.59, 0.11)), 0.05);
		vec3 g = vec3(0.29, 0.66, 0.33) * clamp(pow(l, 1.2) * 1.05, 0.05, 1.35);
		c = mix(c, g, skin * clamp(green, 0.0, 1.0));
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	EMISSION = vec3(0.05, 0.3, 0.1) * skin * green * 0.25;
}
"""
const ARM_PREFIX: Array[String] = ["clavicle_", "upperarm_", "lowerarm_", "hand_", "index_", "middle_", "ring_", "pinky_", "thumb_"]
const HEAD_BONES: Array[String] = ["head", "jaw", "eye_l", "eye_r", "neck_01"]
static var _shader: Shader = null


## Estado de una mano.
class Hand extends RefCounted:
	var on: bool = false
	var goal: Vector3 = Vector3.ZERO  # espacio de la vista (o del mundo si world_fn es válido)
	var world_fn: Callable = Callable()  # → Vector3 del mundo (manda sobre goal)
	var palm_to: Vector3 = Vector3.INF  # punto (espacio de la vista) al que mira la palma; INF: sin orientar
	var palm_fn: Callable = Callable()  # → Vector3 del mundo al que mira la palma
	var fingers: Vector3 = Vector3.INF  # dirección de los dedos (espacio de la vista); INF: siguen al antebrazo
	var grip: Variant = "suelta"
	var hz: float = 3.6  # rigidez del resorte (Hz)
	var damp: float = 0.62
	var w: float = 0.0
	var cur: Vector3 = Vector3.INF  # posición del mundo suavizada
	var vel: Vector3 = Vector3.ZERO
	var curl_cur: Dictionary = {}
	var pole: Vector3 = Vector3.INF
	var last_wrist: Vector3 = Vector3.INF  # muñeca resuelta (mundo)


var fx: Screamers = null
var scene: Node3D = null
var sk: Skeleton3D = null
var anim: AnimationPlayer = null
var hands: Dictionary = {"l": Hand.new(), "r": Hand.new()}
var info: Dictionary = {}
var mats: Array[ShaderMaterial] = []
var strength: float = 1.0  # 1 = con fuerza; 0 = muerto (las manos caen, sin temblor)
var shake_amp: float = 0.0  # m: temblor/tirones del forcejeo
var shake_hz: float = 9.0
var pitch_follow: float = 0.55
var _t: float = 0.0
var _head_local: Vector3 = Vector3(0, 1.55, 0)
var _body_show: float = 0.0


## El KillVictim del screamer (uno por muerte; se crea la primera vez). null si no hay modelo del agente.
static func of(p_fx: Screamers) -> KillVictim:
	if p_fx == null or not is_instance_valid(p_fx) or p_fx._stage == null:
		return null
	if p_fx.has_meta("victim"):
		var v0: Variant = p_fx.get_meta("victim")
		if v0 is KillVictim and is_instance_valid(v0):
			return v0
	var v := KillVictim.new()
	v.name = "Victima"
	v.fx = p_fx
	p_fx._stage.add_child(v)
	if not v._build():
		v.queue_free()
		return null
	p_fx.set_meta("victim", v)
	if p_fx._face_light != null and is_instance_valid(p_fx._face_light):
		p_fx._face_light.light_cull_mask &= ~LAYER
	if not (p_fx.last_info["props"] as Array).has("tus_manos"):
		(p_fx.last_info["props"] as Array).append("tus_manos")
	return v


func _build() -> bool:
	var path := CharacterRig.MODELS_DIR + CharacterRig.agent_model(GameState.agent) + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	scene = packed.instantiate() as Node3D
	add_child(scene)
	scene.rotation_degrees.y = 180.0  # los GLB miran a +Z
	for c in scene.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	if sk == null:
		return false
	# Escala: el alto del agente (1,72 m, como el cuerpo del jugador).
	var top := -INF
	var bottom := INF
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		var xf := scene.global_transform.affine_inverse() * mi.global_transform
		for corner in [aabb.position, aabb.end]:
			var p: Vector3 = xf * corner
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
	if top - bottom > 0.01:
		scene.scale = Vector3.ONE * (1.72 / (top - bottom))
	for c in scene.find_children("*", "AnimationPlayer", true, false):
		anim = c
	if anim != null:
		for n in ["idle", "stand"]:
			if anim.has_animation(n):
				anim.play(n, 0.0, 0.0)  # quieto, con los brazos a los lados (los brazos los lleva el IK)
				anim.seek(0.0, true)
				break
	var hb := sk.find_bone("head")
	if hb >= 0:
		_head_local = global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_rest(hb).origin)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var skin_ref: Color = VitzoFusion.SKIN_REF.get(GameState.agent.to_lower(), Color(0.7, 0.5, 0.45))
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null or mi.skin == null:
			mi.visible = false
			continue
		mi.layers = LAYER
		var masks := _masks(mi)
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = _shader
			if src != null:
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				sm.set_shader_parameter("albedo_color", src.albedo_color)
			sm.set_shader_parameter("arm_mask", masks[0])
			sm.set_shader_parameter("head_mask", masks[1])
			sm.set_shader_parameter("skin_ref", skin_ref)
			mi.set_surface_override_material(i, sm)
			mats.append(sm)
		mi.extra_cull_margin = 2.0
	for side in ["l", "r"]:
		info[side] = KillHands.setup(sk, side)
	var mod := _Arms.new()
	mod.name = "BrazosVictima"
	mod.v = self
	sk.add_child(mod)
	process_priority = 50  # después del screamer (que mueve la cámara)
	_place()
	return true


## Máscaras de bits de los índices del skin: huesos de los brazos y de la cabeza.
func _masks(mi: MeshInstance3D) -> Array:
	var arm := [0, 0, 0, 0]
	var head := [0, 0, 0, 0]
	var skin := mi.skin
	for i in mini(skin.get_bind_count(), 128):
		var bn := str(skin.get_bind_name(i))
		if bn == "":
			var bb := skin.get_bind_bone(i)
			bn = sk.get_bone_name(bb) if bb >= 0 else ""
		var is_arm := false
		for pre in ARM_PREFIX:
			if bn.begins_with(pre):
				is_arm = true
				break
		if is_arm:
			arm[i >> 5] |= 1 << (i & 31)
		if HEAD_BONES.has(bn):
			head[i >> 5] |= 1 << (i & 31)
	return [Vector4i(_s32(arm[0]), _s32(arm[1]), _s32(arm[2]), _s32(arm[3])), Vector4i(_s32(head[0]), _s32(head[1]), _s32(head[2]), _s32(head[3]))]


static func _s32(v: int) -> int:
	return v - 4294967296 if v >= 2147483648 else v


class _Arms extends SkeletonModifier3D:
	var v: KillVictim = null

	func _process_modification_with_delta(delta: float) -> void:
		if v != null and is_instance_valid(v):
			v._solve(get_skeleton(), delta)


# --- API ---------------------------------------------------------------------------------------------------------

## La mano `side` ("l" = tu izquierda, "r" = tu derecha) va a `pos` (espacio de la vista). grip: KillHands.GRIPS.
## palm_to: punto de la vista al que mira la palma (lo que agarras o empujas). hz: rigidez del resorte.
func put(side: String, pos: Vector3, grip: Variant = "suelta", palm_to: Vector3 = Vector3.INF, hz: float = 3.6, fingers: Vector3 = Vector3.INF) -> void:
	var h := hands[side] as Hand
	h.on = true
	h.goal = pos
	h.world_fn = Callable()
	h.palm_fn = Callable()
	h.palm_to = palm_to
	h.fingers = fingers
	h.grip = grip
	h.hz = hz


func both(l: Vector3, r: Vector3, grip: Variant = "suelta", palm_to: Vector3 = Vector3.INF, hz: float = 3.6) -> void:
	put("l", l, grip, palm_to, hz)
	put("r", r, grip, palm_to, hz)


## La mano se pega a un punto del mundo que se recalcula cada cuadro (la muñeca del asesino, una cuerda…).
func hold(side: String, world_fn: Callable, grip: Variant = "tubo", palm_fn: Callable = Callable(), hz: float = 6.0) -> void:
	var h := hands[side] as Hand
	h.on = true
	h.world_fn = world_fn
	h.palm_fn = palm_fn
	h.palm_to = Vector3.INF
	h.grip = grip
	h.hz = hz


## Suelta: la mano cae fuera de la vista y el brazo vuelve a colgar.
func drop(side: String = "") -> void:
	for s in (["l", "r"] if side == "" else [side]):
		var h := hands[s] as Hand
		h.on = false
		h.world_fn = Callable()


## Forcejeo: temblor y tirones (amp en metros; 0 lo apaga).
func struggle(amp: float, hz: float = 9.0) -> void:
	shake_amp = amp
	shake_hz = hz


## Tirón de una mano (se suma a la velocidad del resorte: la mano sale despedida y vuelve).
func jolt(side: String, impulse: Vector3) -> void:
	var h := hands[side] as Hand
	var cam := fx._cam()
	if cam != null:
		h.vel += cam.global_transform.basis * impulse


func set_param(name: String, v: float) -> void:
	for m in mats:
		m.set_shader_parameter(name, v)


func tween_param(name: String, from: float, to: float, t: float) -> void:
	create_tween().tween_method(func(x: float) -> void: set_param(name, x), from, to, maxf(t, 0.02))


## Heridas en los brazos (moretones y cortes). Con «Reducido»: nada.
func wounds(k: float) -> void:
	set_param("wounds", k if KillGore.enabled() else 0.0)
	if k > 0.0 and KillGore.enabled():
		KillGore._note(fx, "manos")


## Deja ver todo tu cuerpo menos la cabeza (te ves las piernas: colgando del cuello, arrastrado).
func show_body(on: bool) -> void:
	_body_show = 1.0 if on else 0.0
	set_param("show_body", _body_show)


## Tu cuerpo a la vista (todo menos la cabeza) con un clip de la biblioteca k32 de tu agente (v_patalea: colgando,
## las piernas patalean; v_piernas: de espaldas con las piernas arriba). false si no hay biblioteca o clip.
func body(clip: String, speed: float = 1.0, blend: float = 0.2) -> bool:
	if anim == null:
		return false
	if not anim.has_animation_library("k32"):
		var path := "res://assets/anim/%s_kills.res" % CharacterRig.agent_model(GameState.agent)
		if not ResourceLoader.exists(path):
			return false
		var lib := load(path) as AnimationLibrary
		if lib == null:
			return false
		KillMoves.fix_jaw(lib, anim.get_parent())
		anim.add_animation_library("k32", lib)
	if not anim.has_animation("k32/" + clip):
		return false
	show_body(true)
	anim.play("k32/" + clip, blend, speed)
	return true


## Clip de cuerpo (k32 o del GLB) para el cuerpo visible (las piernas que patalean); los brazos siguen con el IK.
func play(clip: String, speed: float = 1.0, blend: float = 0.15) -> void:
	if anim != null and anim.has_animation(clip):
		anim.play(clip, blend, speed)


## Punto del mundo de un punto de la vista (el mismo marco que las manos del asesino).
func view_point(local: Vector3) -> Vector3:
	return _frame() * local


func wrist(side: String) -> Vector3:
	return (hands[side] as Hand).last_wrist


# --- por cuadro -----------------------------------------------------------------------------------------------------

func _frame() -> Transform3D:
	var cam := fx._cam()
	return cam.global_transform if fx.glance == Vector2.ZERO else fx.view_xf()


## El cuerpo cuelga de la vista: los ojos del modelo en tus ojos, el torso derecho (gira con la vista; se inclina
## pitch_follow de lo que cabecea la vista: tendido de espaldas, el torso queda tendido).
func _place() -> void:
	if fx == null or not is_instance_valid(fx) or fx._player == null or not is_instance_valid(fx._player):
		return
	var v := fx.view_xf()
	var f := -v.basis.z
	var flat := Vector3(f.x, 0.0, f.z)
	if flat.length() < 0.05:
		flat = v.basis.y * (-1.0 if f.y > 0.0 else 1.0)  # mirando al techo/suelo: el «arriba» de la vista marca el rumbo
		flat.y = 0.0
	flat = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	var pitch := asin(clampf(f.y, -1.0, 1.0))
	var roll := atan2(v.basis.x.y, Vector2(v.basis.x.x, v.basis.x.z).length())
	var b := Basis.looking_at(flat, Vector3.UP) * Basis(Vector3.RIGHT, pitch * pitch_follow) * Basis(Vector3.FORWARD, -roll * 0.5)
	var eye_l := _head_local + EYE_LOCAL
	global_transform = Transform3D(b, v.origin - b * eye_l)


func _process(delta: float) -> void:
	_t += delta
	_place()


func _solve(skel: Skeleton3D, delta: float) -> void:
	if fx == null or not is_instance_valid(fx) or fx._cam() == null:
		return
	var frame := _frame()
	var to_sk := skel.global_transform.affine_inverse()
	for side in ["l", "r"]:
		var h := hands[side] as Hand
		var inf: Dictionary = info[side]
		if inf.is_empty():
			continue
		var sgn := -1.0 if side == "l" else 1.0
		# Objetivo del mundo: el pedido o, suelta, abajo y afuera de la vista (el brazo cae).
		var goal_w: Vector3
		if h.on:
			goal_w = h.world_fn.call() if h.world_fn.is_valid() else frame * h.goal
			if shake_amp > 0.0 and strength > 0.05:
				var ph := _t * shake_hz * TAU + (0.0 if side == "l" else 2.1)
				goal_w += frame.basis * (Vector3(sin(ph * 1.0), sin(ph * 1.37 + 1.0), sin(ph * 0.73 + 2.0)) * shake_amp * strength)
			if strength < 1.0:
				goal_w = goal_w.lerp(frame * Vector3(0.3 * sgn, -0.75, -0.1), 1.0 - strength)
		else:
			goal_w = frame * Vector3(0.3 * sgn, -0.8, -0.04)
		if h.cur == Vector3.INF:
			h.cur = frame * Vector3(0.3 * sgn, -0.72, -0.06)  # entra desde abajo
		# Resorte de segundo orden (se pasa un poco y asienta).
		var wn := TAU * h.hz * (0.5 + 0.5 * strength)
		var steps := maxi(1, int(ceil(delta / 0.012)))
		var dt := delta / steps
		for _i in steps:
			var acc := (goal_w - h.cur) * wn * wn - h.vel * 2.0 * h.damp * wn
			h.vel += acc * dt
			h.cur += h.vel * dt
		h.w = move_toward(h.w, 1.0 if h.on else 0.0, delta * (7.0 if h.on else 3.0))
		if h.w <= 0.001:
			h.last_wrist = Vector3.INF
			continue
		var pole := h.pole if h.pole != Vector3.INF else Vector3(-sgn * 0.9, -0.75, -0.1)  # codos abajo y afuera
		KillHands.arm(skel, inf, to_sk * h.cur, h.w, pole)
		# La palma hacia lo que agarra / empuja.
		var palm_w := Vector3.INF
		if h.palm_fn.is_valid():
			palm_w = h.palm_fn.call()
		elif h.palm_to != Vector3.INF:
			palm_w = frame * h.palm_to
		if palm_w != Vector3.INF and h.on:
			var gh := skel.global_transform * skel.get_bone_global_pose(int(inf["ha"])).origin
			var n := to_sk.basis * (palm_w - gh)
			var fdir := (to_sk.basis * (frame.basis * h.fingers)) if h.fingers != Vector3.INF else Vector3.INF
			KillHands.orient(skel, inf, n, fdir, h.w)
		KillHands.curl(skel, inf, h.grip if h.on else "suelta", h.w * (0.35 + 0.65 * strength), 0.6 if str(h.grip) == "garra" else 0.0)
		h.last_wrist = skel.global_transform * skel.get_bone_global_pose(int(inf["ha"])).origin

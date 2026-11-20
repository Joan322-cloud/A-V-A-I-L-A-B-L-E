class_name KillHands
extends RefCounted
## Brazos y manos que AGARRAN (v0.3.2d, la barra nueva de Joan: «manos que de verdad agarran»). Funciones puras
## sobre un Skeleton3D de los rigs v2 (humanoides: clavicle/upperarm/lowerarm/hand + index/middle/ring/pinky/thumb
## _01.._03; Vitzo: upperarm/lowerarm/hand + f0..f2; Perrito: patas delanteras). Las usan ScreamRig (el asesino) y
## KillVictim (tus propios brazos en primera persona), dentro de su _process_modification:
##   info := KillHands.setup(sk, "l")                     una vez por lado (huesos, ejes de la palma, largos)
##   KillHands.arm(sk, info, punto, peso, polo)           IK de 2 huesos: la muñeca va al punto (espacio del esqueleto)
##   KillHands.orient(sk, info, normal, dedos, peso)      la palma mira a `normal`, los dedos apuntan hacia `dedos`
##   KillHands.curl(sk, info, agarre, peso)               cierra los dedos según un agarre (GRIPS) o un número 0..1
## Todo en el espacio del esqueleto (sk.global_transform.affine_inverse() * punto del mundo).
## Agarres (cuánto se cierra cada dedo, 0 = estirado, 1 = puño; el pulgar aparte):
##   "puño" cerrado · "garra" dedos en gancho, separados · "plana" mano abierta (tapa una boca, empuja) ·
##   "gancho" dedos doblados en las segundas falanges (uñas que rascan) · "pinza" índice y pulgar · "tubo" rodea algo
##   grueso (una muñeca, un cuello, una correa) · "suelta" relajada.

const GRIPS: Dictionary = {
	"puño": {"index": 0.95, "middle": 1.0, "ring": 1.0, "pinky": 1.0, "thumb": 0.8},
	"garra": {"index": 0.5, "middle": 0.58, "ring": 0.55, "pinky": 0.48, "thumb": 0.5},
	"plana": {"index": 0.04, "middle": 0.05, "ring": 0.07, "pinky": 0.1, "thumb": 0.0},
	"gancho": {"index": 0.62, "middle": 0.68, "ring": 0.66, "pinky": 0.6, "thumb": 0.35},
	"pinza": {"index": 0.55, "middle": 0.2, "ring": 0.25, "pinky": 0.3, "thumb": 0.7},
	"tubo": {"index": 0.72, "middle": 0.76, "ring": 0.76, "pinky": 0.74, "thumb": 0.6},
	"suelta": {"index": 0.22, "middle": 0.3, "ring": 0.36, "pinky": 0.42, "thumb": 0.2},
}
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky", "thumb"]
## Grados que dobla cada falange a cierre 1 (la primera menos: los nudillos; el pulgar menos).
const CURL_DEG: Array[float] = [62.0, 84.0, 60.0]
const THUMB_DEG: Array[float] = [34.0, 40.0, 48.0]


## Huesos y medidas de un brazo. side "l" / "r". Devuelve {} si el esqueleto no tiene ese brazo.
static func setup(sk: Skeleton3D, side: String) -> Dictionary:
	var ua := sk.find_bone("upperarm_" + side)
	var la := sk.find_bone("lowerarm_" + side)
	var ha := sk.find_bone("hand_" + side)
	if ua < 0 and sk.find_bone("fl_up_" + side) >= 0:  # Perrito RTA: las patas delanteras hacen de brazos
		ua = sk.find_bone("fl_up_" + side)
		la = sk.find_bone("fl_lo_" + side)
		ha = sk.find_bone("fl_paw_" + side)
	if ua < 0 or la < 0 or ha < 0:
		return {}
	var info := {"side": side, "ua": ua, "la": la, "ha": ha, "clav": sk.find_bone("clavicle_" + side), "fingers": {}, "robot": false}
	for f in FINGERS:
		var chain: Array[int] = []
		for j in [1, 2, 3]:
			var b := sk.find_bone("%s_0%d_%s" % [f, j, side])
			if b >= 0:
				chain.append(b)
		if not chain.is_empty():
			(info["fingers"] as Dictionary)[f] = chain
	if (info["fingers"] as Dictionary).is_empty():
		for j in 3:  # Vitzo: tres dedos de un hueso
			var b3 := sk.find_bone("f%d_%s" % [j, side])
			if b3 >= 0:
				(info["fingers"] as Dictionary)[["index", "middle", "pinky"][j]] = [b3]
				info["robot"] = true
	# Ejes de la mano en reposo (como tools/anim/rigkit.py): los dedos van del hueso de la mano al nudillo del medio; la
	# normal de la palma (hacia fuera de la palma) sale de dedos × (índice − meñique), con el signo de cada lado.
	var hr := sk.get_bone_global_rest(ha)
	var names: Array = (["f1_", "f0_", "f2_"] if bool(info["robot"]) else ["middle_01_", "index_01_", "pinky_01_"])
	var ref := sk.find_bone(str(names[0]) + side)
	var bi := sk.find_bone(str(names[1]) + side)
	var bk := sk.find_bone(str(names[2]) + side)
	var f0 := hr.basis.y.normalized()
	var n0 := hr.basis.z.normalized()
	if ref >= 0 and bi >= 0 and bk >= 0:
		var d := sk.get_bone_global_rest(ref).origin - hr.origin
		var s0 := sk.get_bone_global_rest(bi).origin - sk.get_bone_global_rest(bk).origin
		if d.length() > 0.004 and s0.length() > 0.002:
			f0 = d.normalized()
			n0 = (f0.cross(s0) if side == "l" else s0.cross(f0)).normalized()
	n0 = (n0 - f0 * n0.dot(f0)).normalized() if absf(n0.dot(f0)) < 0.98 else f0.cross(Vector3.RIGHT).normalized()
	info["fl"] = hr.basis.inverse() * f0  # dirección de los dedos en el espacio del hueso de la mano
	info["nl"] = hr.basis.inverse() * n0  # normal de la palma (hacia fuera de la palma) en ese espacio
	# Eje de cierre de cada falange en SU espacio local: dedos × palma (el pulgar: su propio hueso × palma).
	var axes: Dictionary = {}
	for f in (info["fingers"] as Dictionary).keys():
		for b2 in (info["fingers"] as Dictionary)[f]:
			var br := sk.get_bone_global_rest(int(b2))
			var ax := (br.basis.y.normalized().cross(n0) if f == "thumb" else f0.cross(n0))
			ax = ax.normalized() if ax.length() > 0.01 else Vector3.RIGHT
			axes[int(b2)] = (br.basis.inverse() * ax).normalized()
	info["axes"] = axes
	info["spread_l"] = Vector3.ZERO
	info["l1"] = sk.get_bone_global_rest(ua).origin.distance_to(sk.get_bone_global_rest(la).origin)
	info["l2"] = sk.get_bone_global_rest(la).origin.distance_to(hr.origin)
	info["palm"] = (sk.get_bone_global_rest(ref).origin.distance_to(hr.origin) if ref >= 0 else 0.08)
	return info


## IK analítico hombro-codo-muñeca: la muñeca va a `target` (espacio del esqueleto) con peso w. pole = hacia dónde va
## el codo (espacio del esqueleto; por defecto afuera y abajo). Devuelve la posición final de la muñeca.
static func arm(sk: Skeleton3D, info: Dictionary, target: Vector3, w: float, pole: Vector3 = Vector3.INF, stretch: float = 1.0) -> Vector3:
	if info.is_empty() or w <= 0.001:
		return Vector3.INF
	var ua := int(info["ua"])
	var la := int(info["la"])
	var ha := int(info["ha"])
	var gu := sk.get_bone_global_pose(ua)
	var gl := sk.get_bone_global_pose(la)
	var gh := sk.get_bone_global_pose(ha)
	var s := gu.origin
	var l1 := s.distance_to(gl.origin)
	var l2 := gl.origin.distance_to(gh.origin)
	var to := target - s
	var d := clampf(to.length(), 0.05, (l1 + l2) * 0.985)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.FORWARD
	var out := pole if pole != Vector3.INF else Vector3(1.0 if str(info["side"]) == "l" else -1.0, -0.6, -0.2)
	var pl := out - dir * out.dot(dir)
	pl = pl.normalized() if pl.length() > 0.001 else dir.cross(Vector3.UP).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hgt := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var elbow := s + dir * a + pl * hgt
	var cur_u := gu.basis.y.normalized()
	var want_u := (elbow - s).normalized()
	var qu := Quaternion(cur_u, want_u) if cur_u.dot(want_u) < 0.9999 else Quaternion.IDENTITY
	qu = Quaternion.IDENTITY.slerp(qu, clampf(w, 0.0, 1.0))
	sk.set_bone_global_pose(ua, Transform3D(Basis(qu) * gu.basis, gu.origin))
	gl = sk.get_bone_global_pose(la)
	var cur_l := gl.basis.y.normalized()
	var want_l := (s + dir * d - gl.origin).normalized()
	var ql := Quaternion(cur_l, want_l) if cur_l.dot(want_l) < 0.9999 else Quaternion.IDENTITY
	ql = Quaternion.IDENTITY.slerp(ql, clampf(w, 0.0, 1.0))
	sk.set_bone_global_pose(la, Transform3D(Basis(ql) * gl.basis, gl.origin))
	var _s := stretch
	return sk.get_bone_global_pose(ha).origin


## Orienta la mano: la palma mira hacia `normal` y los dedos apuntan (lo más posible) hacia `fingers`; si `fingers`
## es INF, siguen al antebrazo. Todo en el espacio del esqueleto. La muñeca no gira más de max_deg respecto del
## antebrazo (sin muñecas rotas).
static func orient(sk: Skeleton3D, info: Dictionary, normal: Vector3, fingers: Vector3, w: float, max_deg: float = 78.0) -> void:
	if info.is_empty() or w <= 0.001 or normal.length() < 0.001:
		return
	var ha := int(info["ha"])
	var gh := sk.get_bone_global_pose(ha)
	var gl := sk.get_bone_global_pose(int(info["la"]))
	var basis0 := gh.basis.orthonormalized()
	var f_cur := (basis0 * (info["fl"] as Vector3)).normalized()
	var n_cur := (basis0 * (info["nl"] as Vector3)).normalized()
	var n_w := normal.normalized()
	var fa := (gh.origin - gl.origin).normalized()  # el antebrazo
	var f_w := fingers if fingers != Vector3.INF else fa
	f_w = f_w - n_w * f_w.dot(n_w)
	if f_w.length() < 0.25:
		# El antebrazo llega de frente a lo que toca (empuja, tapa): los dedos hacia arriba del esqueleto.
		f_w = Vector3.UP - n_w * Vector3.UP.dot(n_w)
		if f_w.length() < 0.25:
			f_w = fa.cross(n_w)
	f_w = f_w.normalized()
	var want := _frame(f_w, n_w)
	var cur := _frame(f_cur, n_cur)
	var q := (want * cur.inverse()).get_rotation_quaternion()
	# Límite de la muñeca: lo que la mano se aparta de «dedos = antebrazo».
	var nb := (Basis(q) * basis0).orthonormalized()
	var f_new := (nb * (info["fl"] as Vector3)).normalized()
	var bend := rad_to_deg(f_new.angle_to(fa))
	if bend > max_deg:
		var k := max_deg / bend
		var axis := fa.cross(f_new)
		if axis.length() > 0.001:
			# Se queda a max_deg del antebrazo, en el mismo plano.
			var f_lim := fa.rotated(axis.normalized(), deg_to_rad(max_deg))
			var n_lim := n_w - f_lim * n_w.dot(f_lim)
			if n_lim.length() > 0.05:
				want = _frame(f_lim, n_lim.normalized())
				q = (want * cur.inverse()).get_rotation_quaternion()
		var _k := k
	q = Quaternion.IDENTITY.slerp(q, clampf(w, 0.0, 1.0))
	sk.set_bone_global_pose(ha, Transform3D(Basis(q) * gh.basis, gh.origin))


static func _frame(f: Vector3, n: Vector3) -> Basis:
	var c := f.cross(n).normalized()
	return Basis(f, n, c)


## Cierra los dedos. grip: nombre de GRIPS, un Dictionary {dedo: 0..1} o un número (todos igual). spread > 0 separa
## los dedos (garra abierta). El pulgar se opone hacia la palma.
static func curl(sk: Skeleton3D, info: Dictionary, grip: Variant, w: float, spread: float = 0.0) -> void:
	if info.is_empty() or w <= 0.001:
		return
	var g: Dictionary = {}
	if grip is String:
		g = GRIPS.get(str(grip), GRIPS["garra"])
	elif grip is Dictionary:
		g = grip
	var all := float(grip) if (grip is float or grip is int) else -1.0
	var fingers: Dictionary = info["fingers"]
	var robot := bool(info["robot"])
	var idx := 0
	for f in fingers.keys():
		var chain: Array = fingers[f]
		var c := all if all >= -0.5 else float(g.get(f, g.get("all", 0.5)))
		c *= w
		for j in chain.size():
			var b := int(chain[j])
			var deg := (THUMB_DEG[mini(j, 2)] if f == "thumb" else CURL_DEG[mini(j, 2)]) * c
			if robot:
				deg = 50.0 * c
			var axis: Vector3 = (info["axes"] as Dictionary).get(b, Vector3.RIGHT)
			var q := Quaternion(axis, deg_to_rad(deg))
			if j == 0 and f != "thumb" and absf(spread) > 0.001:
				# separa los dedos: gira el nudillo alrededor de la normal de la palma (en el espacio de la falange)
				var nb: Vector3 = (sk.get_bone_global_rest(b).basis.inverse() * (sk.get_bone_global_rest(int(info["ha"])).basis * (info["nl"] as Vector3))).normalized()
				q = Quaternion(nb, deg_to_rad(spread * (float(idx) - 1.5) * 7.0 * w * (1.0 if str(info["side"]) == "l" else -1.0))) * q
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * q)
		idx += 1


## Punto de la palma (centro) en el espacio del esqueleto, con la pose actual.
static func palm_point(sk: Skeleton3D, info: Dictionary) -> Vector3:
	if info.is_empty():
		return Vector3.INF
	var gh := sk.get_bone_global_pose(int(info["ha"]))
	return gh.origin + gh.basis.orthonormalized() * ((info["fl"] as Vector3) * float(info["palm"]) * 0.6)


## Dónde poner la MUÑECA para que el centro de la palma quede en `p` mirando a `normal` con los dedos hacia `fingers`.
static func wrist_for_palm(info: Dictionary, p: Vector3, normal: Vector3, fingers: Vector3) -> Vector3:
	if info.is_empty():
		return p
	var f := fingers - normal.normalized() * fingers.dot(normal.normalized())
	f = f.normalized() if f.length() > 0.01 else Vector3.UP
	return p - f * float(info["palm"]) * 0.6

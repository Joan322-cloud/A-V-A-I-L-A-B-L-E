class_name ManosFx
extends Node3D
## Manos en primera persona para las acciones cotidianas (v0.3.1 Q4, F15) · rehecho en v0.3.2-anim.
## Antes eran dos cápsulas pegadas a la cámara. Ahora son los BRAZOS DE VERDAD del agente elegido: el cuerpo del jugador
## (player._rig, el mismo que se ve al mirar hacia abajo y el que muestran las muertes) hace el gesto. Este nodo, hijo
## de la cámara como siempre, reproduce encima de lo que esté haciendo el cuerpo (idle de pie, sentado) SOLO la cadena
## de los brazos de un clip de la biblioteca del agente (tools/anim/clips_fp.py: fp_casillero, fp_dejar, fp_sacar,
## fp_comer) y lleva en las manos el objeto de cada acción:
##   casillero        sube la mochila por la correa con las dos manos, la cuelga adentro, echa llave
##   refri_dejar      el táper sobre la palma, se lee la cinta con tu nombre, adentro; la otra mano cierra la puerta
##   refri_sacar      abre de un tirón, entra, agarra el táper y lo trae (del microondas sale humeando)
##   microondas_meter / microondas_sacar
##   comer            sentado: una mano sostiene el táper, la otra hace tres bocados con el tenedor
## Tiempos idénticos a v0.3.1 (los sonidos y las puertas van a esas horas). La lógica (flags, Fatiga) la hace
## world_objects.gd al instante: esto es solo presentación; un bot o un teletransporte a mitad no rompe nada.
## play() devuelve la duración. API de siempre: for_player(), play(), busy, visible.
##
## Cómo se superpone: cada cuadro, después del AnimationPlayer del cuerpo, escribe la rotación de clavículas, brazos,
## manos y dedos del clip. La clavícula se corrige para que el brazo quede orientado como en el clip aunque el tronco
## del cuerpo esté en otra pose, y sigue un poco la mirada (si mirás más arriba o más abajo que la pose de referencia,
## las manos suben o bajan con vos: como la versión vieja, siempre se ven). Al terminar devuelve cada hueso al cuerpo.
## El vapor del táper es el mismo hilo blando de la taza de C-13 (ObjectAnim.steam); en Modo liviano, cuatro hilos.

const CLIPS := {"casillero": "fp_casillero", "refri_dejar": "fp_dejar", "microondas_meter": "fp_dejar",
	"refri_sacar": "fp_sacar", "microondas_sacar": "fp_sacar", "comer": "fp_comer"}
const DUR := {"casillero": 2.4, "refri_dejar": 2.4, "microondas_meter": 2.4, "refri_sacar": 2.1, "microondas_sacar": 2.1, "comer": 3.3}
## Inclinación de la cámara (grados) para la que se dibujó cada gesto; con otra, las manos acompañan PITCH_FOLLOW.
const REF_PITCH := {"fp_comer": -25.0}
const REF_PITCH_DEF := -12.0
const PITCH_FOLLOW := 0.75
const PITCH_MAX := 30.0

var busy: bool = false
var kind: String = ""  ## acción en curso ("" si ninguna)
var _t: float = 0.0
var _dur: float = 0.0
var _sk: Skeleton3D = null
var _clip: Animation = null
var _arm: Array = []    # [pista, hueso] de brazos, manos y dedos
var _clav: Array = []   # [pista, hueso] de las clavículas
var _chain: Array = []  # [pista o -1, hueso] de la raíz al padre de las clavículas
var _body: Dictionary = {}   # hueso → rotación que le da el cuerpo
var _wrote: Dictionary = {}  # hueso → lo último que escribí
var _hb: Dictionary = {}     # "l"/"r" → [mano, medio, índice, meñique]
var _ref_pitch: float = REF_PITCH_DEF
var _ev: Array = []          # eventos pendientes [t, Callable], en orden
var _follow: Array = []      # [nodo, modo, desplazamiento]: objetos que van en la mano ("l", "r" o "lr")
var _steam: CPUParticles3D = null


static func for_player(p: Node) -> ManosFx:
	if p == null or not (p is Player):
		return null
	var cam := (p as Player).camera
	if cam == null:
		return null
	var m := cam.get_node_or_null("ManosFx") as ManosFx
	if m == null:
		m = ManosFx.new()
		m.name = "ManosFx"
		cam.add_child(m)
	return m


func _ready() -> void:
	visible = false
	process_priority = 950  # después del AnimationPlayer del cuerpo
	set_process(false)


func _player() -> Player:
	var n := get_parent()
	while n != null and not (n is Player):
		n = n.get_parent()
	return n as Player


## Reproduce la animación `kind`; devuelve la duración en segundos.
func play(p_kind: String) -> float:
	_finish()
	kind = p_kind
	busy = true
	visible = true
	_t = 0.0
	_dur = float(DUR.get(p_kind, 0.8))
	_bind(str(CLIPS.get(p_kind, "")))
	_stage(p_kind)
	set_process(true)
	return _dur


## Busca el cuerpo del jugador, su esqueleto y el clip; arma la lista de pistas. Si falta algo no hay brazos (los objetos
## van delante de la cámara) y nada más cambia.
func _bind(clip_name: String) -> void:
	_clip = null
	_sk = null
	_arm.clear()
	_clav.clear()
	_chain.clear()
	_body.clear()
	_wrote.clear()
	_hb.clear()
	_ref_pitch = float(REF_PITCH.get(clip_name, REF_PITCH_DEF))
	var pl := _player()
	var rig := (pl.get("_rig") as CharacterRig) if pl != null else null
	if rig == null or not is_instance_valid(rig) or clip_name == "":
		return
	var sks := rig.find_children("*", "Skeleton3D", true, false)
	var path := NpcAnimator.ANIM_DIR + rig.model_name + ".res"
	if sks.is_empty() or not ResourceLoader.exists(path):
		return
	var lib := load(path) as AnimationLibrary
	if lib == null or not lib.has_animation(clip_name):
		return
	var sk := sks[0] as Skeleton3D
	var clip := lib.get_animation(clip_name)
	var by_bone := {}
	for i in clip.get_track_count():
		if clip.track_get_type(i) == Animation.TYPE_ROTATION_3D and clip.track_get_path(i).get_subname_count() > 0:
			by_bone[str(clip.track_get_path(i).get_subname(0))] = i
	var roots: Array[int] = []
	for s in ["l", "r"]:
		var cb := sk.find_bone("clavicle_" + s)
		if cb < 0 or not by_bone.has("clavicle_" + s):
			return
		roots.append(cb)
		_clav.append([by_bone["clavicle_" + s], cb])
		_hb[s] = [sk.find_bone("hand_" + s), sk.find_bone("middle_01_" + s), sk.find_bone("index_01_" + s), sk.find_bone("pinky_01_" + s)]
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		while p >= 0 and not roots.has(p):
			p = sk.get_bone_parent(p)
		if p >= 0 and by_bone.has(sk.get_bone_name(b)):
			_arm.append([by_bone[sk.get_bone_name(b)], b])
	var up := sk.get_bone_parent(roots[0])
	while up >= 0:
		_chain.push_front([int(by_bone.get(sk.get_bone_name(up), -1)), up])
		up = sk.get_bone_parent(up)
	_sk = sk
	_clip = clip


func _process(delta: float) -> void:
	if not busy:
		return
	_t += delta
	while not _ev.is_empty() and _t >= float(_ev[0][0]):
		((_ev.pop_front() as Array)[1] as Callable).call()
	_pose()
	_carry()
	if _t >= _dur:
		_finish()


## Los brazos del clip encima de la pose del cuerpo.
func _pose() -> void:
	if _clip == null or _sk == null or not is_instance_valid(_sk):
		return
	var w := minf(smoothstep(0.0, 0.12, _t), smoothstep(0.0, 0.15, _dur - _t))
	var tc := minf(_t, _clip.length)
	# el pecho tal como lo trae el clip: el brazo se horneó respecto de ESE pecho, no del que tiene ahora el cuerpo
	var baked := Quaternion.IDENTITY
	for c in _chain:
		baked = baked * (_clip.rotation_track_interpolate(c[0], tc) if int(c[0]) >= 0 else _sk.get_bone_rest(c[1]).basis.get_rotation_quaternion())
	var actual := _sk.get_bone_global_pose(_sk.get_bone_parent(_clav[0][1])).basis.orthonormalized().get_rotation_quaternion()
	var pl := _player()
	var pitch := rad_to_deg(pl.head.rotation.x) if pl != null and pl.head != null else _ref_pitch
	var lift := deg_to_rad(clampf((pitch - _ref_pitch) * PITCH_FOLLOW, -PITCH_MAX, PITCH_MAX))
	# el modelo mira a +Z en su esqueleto: girar −lift sobre X levanta lo que apunta adelante
	var fix := actual.inverse() * Quaternion(Vector3.RIGHT, -lift) * baked
	for c in _clav:
		_pose_bone(c[1], fix * _clip.rotation_track_interpolate(c[0], tc), w)
	for c in _arm:
		_pose_bone(c[1], _clip.rotation_track_interpolate(c[0], tc), w)


func _pose_bone(b: int, q_clip: Quaternion, w: float) -> void:
	var cur := _sk.get_bone_pose_rotation(b)
	if not _wrote.has(b) or not cur.is_equal_approx(_wrote[b]):
		_body[b] = cur  # el cuerpo acaba de escribir este hueso: esa es su pose
	var q := (_body[b] as Quaternion).slerp(q_clip, w)
	_sk.set_bone_pose_rotation(b, q)
	_wrote[b] = q


## Ejes del agarre de una mano, en el mundo: origen en el centro de la palma, X hacia el pulgar con la palma arriba
## (derecha) / hacia el meñique (izquierda), Y = hacia donde mira la palma, −Z = hacia los dedos. Sin cuerpo, un punto
## fijo delante de la cámara.
func grip(s: String) -> Transform3D:
	var ix: Array = _hb.get(s, [])
	if _sk == null or not is_instance_valid(_sk) or ix.size() < 4 or (ix.min() as int) < 0:
		return global_transform * Transform3D(Basis.IDENTITY, Vector3(0.1 if s == "r" else -0.1, -0.26, -0.42))
	var w := _sk.get_bone_global_pose(ix[0]).origin
	var m := _sk.get_bone_global_pose(ix[1]).origin
	var f := (m - w).normalized()
	var n := (_sk.get_bone_global_pose(ix[2]).origin - w).cross(_sk.get_bone_global_pose(ix[3]).origin - w).normalized() * (1.0 if s == "r" else -1.0)
	var side := f.cross(n).normalized()
	n = side.cross(f).normalized()
	var palm := (m - w).length()
	var g := _sk.global_transform * Transform3D(Basis(side, n, -f), w + f * palm * 0.85 + n * palm * 0.22)
	g.basis = g.basis.orthonormalized()
	return g


## Los objetos que van en la mano siguen su agarre.
func _carry() -> void:
	for it in _follow:
		var n := it[0] as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var mode := str(it[1])
		var off: Vector3 = it[2]
		if mode == "lr":
			# colgado de las dos manos (la mochila por la correa): derecho, mirando adonde mira el jugador
			var a := grip("l").origin
			var b := grip("r").origin
			var pl := _player()
			var yaw := Basis(Vector3.UP, pl.global_rotation.y if pl != null else global_rotation.y)
			n.global_transform = Transform3D(yaw, (a + b) * 0.5 + yaw * off)
		else:
			var g := grip(mode)
			n.global_transform = Transform3D(g.basis, g.origin + g.basis * off)


func _at(t: float, c: Callable) -> void:
	_ev.append([t, c])
	_ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _hold(n: Node3D, mode: String, off: Vector3) -> void:
	add_child(n)
	_follow.append([n, mode, off])


func _drop(n: Node3D) -> void:
	for i in range(_follow.size() - 1, -1, -1):
		if (_follow[i] as Array)[0] == n:
			_follow.remove_at(i)


## Suelta el objeto: sigue solo hacia adelante (adentro del casillero / la refri), se achica y desaparece.
func _release(n: Node3D, dist: float, secs: float, lift: float = 0.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	_drop(n)
	var pl := _player()
	var fwd := -(pl.global_transform.basis.z if pl != null else global_transform.basis.z)
	fwd.y = 0.0
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", n.global_position + fwd.normalized() * dist + Vector3(0, lift, 0), secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.72, secs)
	tw.tween_callback(func() -> void: n.visible = false)


## El objeto aparece (con un pequeño rebote) cuando la mano ya está en su agarre.
func _show_at(n: Node3D, t: float) -> void:
	n.visible = false
	_at(t, func() -> void:
		if is_instance_valid(n):
			n.visible = true
			_pop_in(n))


func _pop_in(n: Node3D) -> void:
	n.scale = Vector3.ONE * 0.6
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Qué lleva cada mano y a qué hora (las mismas horas que el clip).
func _stage(k: String) -> void:
	match k:
		"casillero":
			var bag := _backpack()
			_hold(bag, "lr", Vector3(0, -0.36, -0.02))
			_show_at(bag, 0.1)
			_at(1.2, func() -> void: _release(bag, 0.3, 0.45, 0.03))
			var key := _key()
			key.visible = false
			_hold(key, "r", Vector3(0.03, 0.0, -0.075))
			_at(1.5, func() -> void:
				key.visible = true
				_pop_in(key))
			_at(2.28, func() -> void: key.visible = false)
		"refri_dejar", "microondas_meter":
			var tp := _taper(false)
			_hold(tp, "r", Vector3(0.0, 0.045, -0.035))
			_show_at(tp, 0.16)
			_at(1.45, func() -> void: _release(tp, 0.22, 0.3))
		"refri_sacar", "microondas_sacar":
			var tp2 := _taper(k == "microondas_sacar")
			tp2.visible = false
			_hold(tp2, "r", Vector3(0.0, 0.045, -0.035))
			_at(0.7, func() -> void:
				tp2.visible = true
				_pop_in(tp2)
				if _steam != null:
					_steam.emitting = true)
		"comer":
			var tp3 := _taper(true)
			_hold(tp3, "l", Vector3(0.05, 0.045, -0.02))
			_show_at(tp3, 0.3)  # cuando la palma ya está arriba (antes la mano viene girando desde la falda)
			_at(0.3, func() -> void:
				if _steam != null:
					_steam.emitting = true)
			var fork := _fork()
			_hold(fork, "r", Vector3(0.0, -0.012, -0.1))
			_show_at(fork, 0.18)
			_at(3.05, func() -> void:  # el táper de la mesa (ObjectAnim) aparece en este instante
				tp3.visible = false
				fork.visible = false)


func _finish() -> void:
	if _sk != null and is_instance_valid(_sk):
		for b in _body:
			_sk.set_bone_pose_rotation(b, _body[b])
	_body.clear()
	_wrote.clear()
	_clip = null
	_sk = null
	_ev.clear()
	_follow.clear()
	_steam = null
	for c in get_children():
		c.queue_free()
	busy = false
	kind = ""
	visible = false
	set_process(false)


# --- objetos ---------------------------------------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _backpack() -> Node3D:
	var b := Node3D.new()
	b.name = "Mochila"
	_box(b, "Cuerpo", Vector3(0.3, 0.36, 0.13), Vector3.ZERO, Color(0.13, 0.13, 0.15))
	_box(b, "Bolsillo", Vector3(0.22, 0.14, 0.04), Vector3(0, -0.07, -0.08), Color(0.18, 0.2, 0.24))
	_box(b, "Cierre", Vector3(0.24, 0.008, 0.012), Vector3(0, 0.1, -0.068), Color(0.5, 0.5, 0.52))
	# la correa de arriba: un asa por la que la agarran las dos manos
	_box(b, "AsaI", Vector3(0.02, 0.18, 0.02), Vector3(-0.115, 0.26, 0.0), Color(0.08, 0.08, 0.09))
	_box(b, "AsaD", Vector3(0.02, 0.18, 0.02), Vector3(0.115, 0.26, 0.0), Color(0.08, 0.08, 0.09))
	_box(b, "Asa", Vector3(0.25, 0.022, 0.03), Vector3(0, 0.345, 0.0), Color(0.08, 0.08, 0.09))
	return b


func _key() -> Node3D:
	var k := Node3D.new()
	k.name = "Llave"
	_box(k, "Paleta", Vector3(0.018, 0.003, 0.05), Vector3(0, 0, -0.012), Color(0.72, 0.66, 0.42))
	_box(k, "Cabeza", Vector3(0.026, 0.004, 0.024), Vector3(0, 0, 0.026), Color(0.62, 0.56, 0.34))
	return k


func _taper(hot: bool) -> Node3D:
	var t := Node3D.new()
	t.name = "Taper"
	_box(t, "Cuerpo", Vector3(0.17, 0.065, 0.12), Vector3.ZERO, Color(0.9, 0.9, 0.86, 0.72))
	_box(t, "Comida", Vector3(0.15, 0.035, 0.1), Vector3(0, -0.008, 0), Color(0.62, 0.42, 0.18) if hot else Color(0.5, 0.38, 0.2))
	var lid := _box(t, "Tapa", Vector3(0.175, 0.012, 0.125), Vector3(0, 0.038, 0), Color(0.2, 0.42, 0.7))
	lid.visible = not hot
	# la cinta con tu nombre, en la cara que mira al jugador
	_box(t, "CintaFondo", Vector3(0.09, 0.022, 0.002), Vector3(0, 0, 0.061), Color(0.92, 0.9, 0.78))
	var tape := Label3D.new()
	tape.name = "Cinta"
	tape.text = GameState.agent.to_upper() if GameState.agent != "" else "C-14"
	tape.font_size = 28
	tape.pixel_size = 0.0011
	tape.modulate = Color(0.08, 0.08, 0.1)
	tape.outline_size = 0
	tape.position = Vector3(0, 0.0, 0.0625)
	t.add_child(tape)
	if hot:
		# el mismo hilo blando de la taza de C-13, un poco más cargado; en Modo liviano cuatro hilos
		var light := GfxQuality.is_light()
		_steam = ObjectAnim.steam(t, 4 if light else 12, 0.2, Vector2(0.07, 0.1), 1.5)
		_steam.position = Vector3(0, 0.05, 0)
	return t


func _fork() -> Node3D:
	var f := Node3D.new()
	f.name = "Tenedor"
	_box(f, "Mango", Vector3(0.012, 0.006, 0.12), Vector3(0, 0, 0.02), Color(0.75, 0.76, 0.78))
	_box(f, "Dientes", Vector3(0.02, 0.004, 0.045), Vector3(0, 0, -0.06), Color(0.8, 0.81, 0.83))
	return f

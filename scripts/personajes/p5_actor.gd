class_name P5Actor
extends CharacterBody3D
## Actor de los personajes de P5 (Haime, Rasec, enfermero, Don Fermín y los cazadores de P5Pursuit):
## carga el modelo v2 (assets/models/<slug>.glb, con su textura embebida, P6;
## si tampoco, una silueta de cajas), lo escala a una altura, reproduce sus clips y camina por rutas del piso
## (FloorBase.path). Nodos conmutables del v2: "Pelo" (Rasec: visible = con pelo) y "Afro" (Shero).
## No toca CharacterRig (P6 integra los modelos v2 en assets/models/).

const MODEL_DIRS: Array[String] = ["res://assets/models/"]
const LOOPING: Array[String] = ["idle", "walk", "run", "sprint", "sit", "type", "dj", "karaoke", "stare_camera", "hunch", "float", "sniff", "crawl_vent", "sit_type"]

var slug: String = ""
var model: Node3D = null
var anim: AnimationPlayer = null
## v0.3.2-anim: AnimationTree con los clips de Blender (ver NpcAnimator); null = como antes.
var animator: NpcAnimator = null
var current_anim: String = ""
var speed: float = 1.6
var arrive_radius: float = 0.35
var floor_ref: FloorBase = null
var walking: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _face_target: Vector3 = Vector3.INF
var _stuck_t: float = 0.0
var _check_pos: Vector3 = Vector3.INF
var _ghost_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
## Distancia al destino final por debajo de la cual atraviesa (cazadores: saltan el escritorio).
var ghost_near: float = 0.0
static var _cache: Dictionary = {}


## Crea un actor en `parent` (posición local del padre) con el modelo `p_slug` de `height` metros.
static func make(parent: Node, p_slug: String, height: float, pos: Vector3, yaw_deg: float = 0.0, p_name: String = "", collide: bool = false) -> P5Actor:
	var a := P5Actor.new()
	a.name = p_name if p_name != "" else "Actor_" + p_slug
	a.slug = p_slug
	a.position = pos
	a.rotation_degrees.y = yaw_deg
	a.collision_layer = 4 if collide else 0
	a.collision_mask = 1 if collide else 0
	parent.add_child(a)
	a._build(height)
	return a


static func model_path(p_slug: String) -> String:
	for d in MODEL_DIRS:
		if ResourceLoader.exists(d + p_slug + ".glb"):
			return d + p_slug + ".glb"
	return ""


func _build(height: float) -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = maxf(height, 0.7)
	shape.shape = cap
	shape.position = Vector3(0, cap.height * 0.5, 0)
	add_child(shape)
	var path := model_path(slug)
	var packed: PackedScene = null
	if path != "":
		if _cache.has(path):
			packed = _cache[path]
		else:
			packed = load(path) as PackedScene
			_cache[path] = packed
	if packed != null:
		model = packed.instantiate() as Node3D
	if model == null:
		# Sin modelo: silueta oscura con ojos (nunca un hueco).
		model = Node3D.new()
		model.name = "Silueta"
		Greybox.box(model, "Cuerpo", Vector3(0, height * 0.46, 0), Vector3(0.46, height * 0.9, 0.3), Color(0.05, 0.05, 0.06), false)
		Greybox.box(model, "Cabeza", Vector3(0, height * 0.93, 0), Vector3(0.22, 0.24, 0.22), Color(0.07, 0.07, 0.08), false)
		add_child(model)
		return
	add_child(model)
	model.rotation_degrees.y = 180.0  # los GLB miran a +Z; el actor mira a -Z (como Godot)
	var h := _height_of(model)
	if h > 0.01:
		model.scale = Vector3.ONE * (height / h)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in model.find_children("*", "AnimationPlayer", true, false):
		anim = c as AnimationPlayer
		break
	set_hair(false)  # Rasec es calvo; el pelo solo con música/evento
	CharacterRig.desk_clips(anim)  # v0.3.1 Q2: stand_up / sit_down / sit_type (F19)
	animator = NpcAnimator.attach(model, slug, self, anim)


func _height_of(scene: Node3D) -> float:
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
	return top - bottom if top > bottom else 0.0


## Reproduce un clip (o el primero que exista de `fallbacks`). loop: los clips de LOOPING se repiten.
func play(clip: String, restart: bool = false, spd: float = 1.0, fallbacks: Array = []) -> void:
	if animator != null:
		if restart and clip == animator.current:
			animator.stop()
		if animator.play(clip, LOOPING.has(clip), spd, fallbacks):
			current_anim = animator.current
		return
	if anim == null:
		return
	var names: Array = [clip] + fallbacks
	for n in names:
		var nm := str(n)
		if anim.has_animation(nm):
			if nm == current_anim and not restart and anim.is_playing():
				anim.speed_scale = spd
				return
			var a := anim.get_animation(nm)
			a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(nm) else Animation.LOOP_NONE
			anim.play(nm, 0.2)
			anim.speed_scale = spd
			current_anim = nm
			return


## Nodo "Pelo" del modelo v2 (Rasec): visible = con pelo.
func set_hair(on: bool) -> void:
	if model == null:
		return
	var pelo := model.find_child("Pelo", true, false) as Node3D
	if pelo != null:
		pelo.visible = on


func has_hair() -> bool:
	var pelo := model.find_child("Pelo", true, false) as Node3D if model != null else null
	return pelo != null and pelo.visible


## Nodo "Afro" (Shero v2): false = calvo.
func set_afro(on: bool) -> void:
	if model == null:
		return
	var afro := model.find_child("Afro", true, false) as Node3D
	if afro != null:
		afro.visible = on


## Camina hasta `target` (coordenadas globales) por la ruta del piso si la hay.
func walk_to(target: Vector3, clip: String = "walk") -> void:
	if floor_ref != null and is_instance_valid(floor_ref):
		_path = floor_ref.path(global_position, target)
	else:
		_path = PackedVector3Array([target])
	# El waypoint más cercano puede quedar detrás (al recalcular la ruta a mitad de un tramo): si ya estás
	# más cerca del siguiente que el propio waypoint, se salta (si no, va y vuelve).
	var here := Vector3(global_position.x, 0, global_position.z)
	while _path.size() >= 2:
		var p0 := Vector3(_path[0].x, 0, _path[0].z)
		var p1 := Vector3(_path[1].x, 0, _path[1].z)
		if here.distance_to(p1) <= p0.distance_to(p1) + 0.05:
			_path.remove_at(0)
		else:
			break
	_path_i = 0
	if not walking:
		_stuck_t = 0.0
		_check_pos = global_position
	walking = true
	play(clip, false, 1.0, ["walk", "run", "idle"])


func stop_walking(clip: String = "idle") -> void:
	walking = false
	_path = PackedVector3Array()
	velocity = Vector3.ZERO
	play(clip, false, 1.0, ["idle"])


## Gira suave hacia un punto (global) mientras está quieto. Vector3.INF = deja de girar.
func look_toward(p: Vector3) -> void:
	_face_target = p


func face_now(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	if walking:
		_follow(delta)
	elif _face_target != Vector3.INF:
		var d := _face_target - global_position
		d.y = 0.0
		if d.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(delta * 3.0, 1.0))


func _follow(delta: float) -> void:
	if _path_i >= _path.size():
		stop_walking()
		return
	var target := _path[_path_i]
	target.y = global_position.y
	var d := target - global_position
	d.y = 0.0
	if d.length() <= maxf(arrive_radius, speed * delta * 1.2):
		if d.length() > arrive_radius:
			# El último paso llega justo al punto (con delta grande —time_scale alto o pocos fps— se quedaba
			# a un paso entero y un cazador nunca entraba en su alcance).
			global_position = Vector3(target.x, global_position.y, target.z)
		_path_i += 1
		if _path_i >= _path.size():
			stop_walking()
		return
	velocity = d.normalized() * speed
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(delta * 8.0, 1.0))
	# Sin avanzar hacia el punto (atascado o resbalando contra un vidrio/cubículo) durante 1 s: atraviesa
	# un momento. De madrugada, en la penumbra, nadie lo nota.
	# (Se mide el desplazamiento real cada segundo: las rutas se recalculan seguido y no deben reiniciarlo.)
	_stuck_t += delta
	if _stuck_t >= 1.0:
		if global_position.distance_to(_check_pos) < speed * 0.3:
			_ghost_t = 1.2
		_check_pos = global_position
		_stuck_t = 0.0
	var fin := _path[_path.size() - 1] - global_position
	fin.y = 0.0
	if collision_mask == 0 or _ghost_t > 0.0 or (ghost_near > 0.0 and fin.length() < ghost_near):
		_ghost_t = maxf(_ghost_t - delta, 0.0)
		global_position += velocity * delta
	else:
		move_and_slide()
	_last_pos = global_position


func remaining_path() -> int:
	return _path.size() - _path_i if walking else 0

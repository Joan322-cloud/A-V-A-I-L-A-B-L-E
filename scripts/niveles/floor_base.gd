class_name FloorBase
extends Node3D
## Base de los pisos greybox: spawns, waypoints para la IA, baños, ganchos de distorsión.

const ELEVATOR_SCENE := "res://scenes/niveles/Elevator.tscn"

@export var floor_number: int = 2

## Altura del suelo principal del piso (la red de seguridad del jugador actúa 3 m por debajo).
var base_y: float = 0.0

var waypoints: Array[Vector3] = []
var astar: AStar3D = AStar3D.new()


## Piso activo (lo lee Overlays para el etalonaje de pantalla del piso).
static var active: FloorBase = null


func _ready() -> void:
	add_to_group("floor")
	_build()
	_add_base_collider()
	_build_waypoints()
	_ambient()
	active = self
	_attach_behaviours()
	ObjectAnim.attach(self)  # v0.3.2-anim: gestor de animación de objetos del piso
	_start_mood()
	Screamers.prewarm(screamer_killers())


## Modelos de asesinos que conviene precargar en este piso (Screamers.prewarm, en segundo plano).
func screamer_killers() -> Array:
	return ["shero"]


func _exit_tree() -> void:
	if active == self:
		active = null


# --- v0.3 P2: comportamientos por piso (data/comportamientos.json) ------------------------------

## Instancia los scripts de comportamiento que otros paquetes cuelgan de este piso (guardia, tópico,
## training, Haime, Rasec…), SOLO si el script existe. Cada entrada: {id, script, marcador, turno_desde}.
## El nodo recibe setup_behaviour(piso, marcador, entrada) si lo define. Sin el script no pasa nada.
func _attach_behaviours() -> void:
	var cfg: Dictionary = DataLoader.dict("comportamientos")
	var by_floor: Variant = (cfg.get("pisos", {}) as Dictionary).get(str(floor_number), [])
	if not (by_floor is Array):
		return
	for e in by_floor:
		if not (e is Dictionary):
			continue
		var entry := e as Dictionary
		if GameState.turno < int(entry.get("turno_desde", 1)):
			continue
		var path := str(entry.get("script", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var scr := load(path) as GDScript
		if scr == null or not scr.can_instantiate():
			continue
		var inst: Object = scr.new()
		if not (inst is Node):
			continue
		var node := inst as Node
		node.name = "Comportamiento_" + str(entry.get("id", "x"))
		var marker := find_child(str(entry.get("marcador", "")), true, false) if str(entry.get("marcador", "")) != "" else null
		add_child(node)
		if node.has_method("setup_behaviour"):
			node.call("setup_behaviour", self, marker, entry)


## Ids de comportamiento instanciados en este piso (pruebas).
func behaviours() -> Array[String]:
	var out: Array[String] = []
	for c in get_children():
		if str(c.name).begins_with("Comportamiento_"):
			out.append(str(c.name).trim_prefix("Comportamiento_"))
	return out


# --- v0.3 P2: presión del ambiente (luces que se apagan con la Fatiga/el enojo, apagones) --------

var mood: Node = null


func _start_mood() -> void:
	mood = _Mood.new()
	mood.name = "Animo"
	add_child(mood)
	var amb := _Ambience.new()
	amb.name = "Inquietud"
	amb.floor_node = self
	add_child(amb)


## Etalonaje de pantalla del piso (Overlays): tinte, saturación, contraste y si es exterior.
## Interior: fluorescente enfermizo, verde-cian frío. Los pisos lo sobreescriben.
func grading() -> Dictionary:
	return {"tint": Color(0.9, 1.0, 0.94), "sat": 0.72, "contrast": 1.1, "exterior": false}


## Eventos de ambiente de este piso (los elige _Ambience): pa = anuncio por parlantes, susurro, llanto,
## teclado (alguien teclea en una silla vacía), silencio (el zumbido se corta 3 s).
func ambience_events() -> Array[String]:
	return ["susurro", "silencio"]


## Puntos lejanos donde suenan los eventos de ambiente (coordenadas del piso).
func ambience_points() -> Array[Vector3]:
	return [Vector3.ZERO]


class _Mood extends Node:
	var _lights: Array[Light3D] = []
	var _t: float = 0.0
	var _k: float = 1.0
	var _dip: float = 0.0
	var _dip_cd: float = 8.0

	func _ready() -> void:
		await get_tree().process_frame
		for n in get_parent().find_children("*", "Light3D", true, false):
			var l := n as Light3D
			if l.has_meta("no_mood"):
				continue
			l.set_meta("mood_base", l.light_energy)
			if not l.has_meta("flicker"):
				_lights.append(l)

	func _process(delta: float) -> void:
		_t -= delta
		_dip_cd -= delta
		if _dip > 0.0:
			_dip -= delta
		var d := Dread.level()
		if _dip_cd <= 0.0:
			_dip_cd = randf_range(6.0, 14.0)
			# Apagón breve: con presión alta, las luces del piso bajan de golpe y vuelven (con zumbido).
			if d > 0.5 and randf() < (d - 0.35) and not bool(Loc.get_setting("flash_reduction", false)):
				_dip = 0.35
				AudioManager.play_sfx("parpadeo")
		if _t > 0.0 and _dip <= 0.0:
			return
		_t = 0.15
		var k := 1.0 - 0.38 * d
		if _dip > 0.0:
			k *= 0.2 if fmod(_dip, 0.12) < 0.07 else 0.55
		FlickerLight.mood = k
		if absf(k - _k) < 0.01:
			return
		_k = k
		# Los paneles fluorescentes comparten material (Greybox.material): bajar su emisión es 1 asignación.
		Greybox.material(Color(0.8, 0.95, 0.95), 2.0).emission_energy_multiplier = 2.0 * k
		for l in _lights:
			if is_instance_valid(l):
				l.light_energy = float(l.get_meta("mood_base", 1.0)) * k


class _Ambience extends Node:
	var floor_node: FloorBase = null
	var _t: float = 25.0
	var _player3d: AudioStreamPlayer3D = null
	static var _whisper: AudioStreamWAV = null

	func _ready() -> void:
		_t = randf_range(20.0, 45.0)
		_player3d = AudioStreamPlayer3D.new()
		_player3d.name = "Lejos"
		_player3d.bus = "Ambiente"
		_player3d.unit_size = 6.0
		_player3d.max_db = -6.0
		add_child(_player3d)

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = randf_range(40.0, 85.0) * (1.0 - 0.4 * Dread.level())
		if OS.get_cmdline_user_args().has("--escenario") or not GameState.running:
			return
		var evs := floor_node.ambience_events()
		if evs.is_empty():
			return
		play_event(evs[randi() % evs.size()])

	## Lanza un evento de ambiente (también lo usan las pruebas y las capturas).
	func play_event(ev: String) -> void:
		var pts := floor_node.ambience_points()
		var p: Vector3 = pts[randi() % pts.size()] if not pts.is_empty() else Vector3.ZERO
		_player3d.global_position = floor_node.global_position + p
		match ev:
			"pa":
				var n := randi() % 8 + 1
				AudioManager.play_sfx("pa_chime")
				# v0.3.2-core: anuncio de ambiente sin voz = texto de relleno (no ocupa el canal de las voces: antes un
				# «El ascensor 2 sigue en mantenimiento» retenía 5 s las líneas de Rasec o de Haime).
				VoiceDirector.text("parlantes", tr("PA_%d" % n), 5.0, {"must": false, "priority": VoiceDirector.P.AMBIENTE})
			"susurro":
				if _whisper == null:
					_whisper = Weather.noise_stream(2.2, 0.55, 0.35, true)
				_player3d.stream = _whisper
				_player3d.volume_db = -14.0
				_player3d.pitch_scale = randf_range(0.8, 1.2)
				_player3d.play()
			"llanto":
				var slot := "voces/clientes/cliente_la_que_llora_0%d" % (randi() % 4 + 1)
				var path := AudioManager.resolve(slot)
				if path != "" and not VoiceDirector.busy(VoiceDirector.P.BARK):
					_player3d.stream = load(path) as AudioStream
					_player3d.volume_db = -20.0
					_player3d.pitch_scale = 0.82
					VoiceDirector.say_external(_player3d, slot, VoiceDirector.P.BARK, "llanto", {"max_wait": 0.0, "free_on_drop": false})  # v0.3.2
			"teclado":
				var path2 := AudioManager.resolve("ambiente/teclados_lejanos")
				if path2 != "":
					_player3d.stream = load(path2) as AudioStream
					_player3d.volume_db = -10.0
					_player3d.pitch_scale = 1.0
					_player3d.play()
					get_tree().create_timer(4.0).timeout.connect(func() -> void:
						if is_instance_valid(_player3d):
							_player3d.stop())
			"silencio":
				# El zumbido se corta tres segundos: el silencio también asusta.
				AudioManager.set_bus_volume("Ambiente", 0.15 * float(Loc.get_setting("vol_ambiente", 1.0)))
				get_tree().create_timer(3.0).timeout.connect(func() -> void:
					AudioManager.set_bus_volume("Ambiente", float(Loc.get_setting("vol_ambiente", 1.0))))


## Losa de seguridad invisible bajo todo el piso (10 cm por debajo del suelo visible): si queda algún
## hueco entre losas, el cuerpo baja 10 cm en vez de caer al vacío. Cubre la caja envolvente de todos
## los colisionadores a nivel de suelo. Grupo "base_collider" para que la auditoría la pueda ignorar.
func _add_base_collider() -> void:
	var bounds := AABB()
	var first := true
	for s in find_children("*", "CollisionShape3D", true, false):
		var cs := s as CollisionShape3D
		if not (cs.shape is BoxShape3D) or not (cs.get_parent() is StaticBody3D):
			continue
		var size := (cs.shape as BoxShape3D).size
		var gp := cs.global_position
		if size.y > 0.35 or absf(gp.y - base_y) > 0.4:
			continue
		var gt := cs.global_transform
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var p := gt * Vector3(size.x * 0.5 * sx, 0.0, size.z * 0.5 * sz)
				if first:
					bounds = AABB(p, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(p)
	if first:
		return
	Greybox.invisible_box(self, "LosaSeguridad", Vector3(bounds.get_center().x, base_y - 0.15, bounds.get_center().z), Vector3(bounds.size.x + 0.5, 0.1, bounds.size.z + 0.5), "base_collider")


## Cada piso construye su geometría aquí.
func _build() -> void:
	pass


## Ajustes de WorldEnvironment del piso (GDD 8.2: verde-cian frío; ámbar solo en descanso).
func env_settings() -> Dictionary:
	return {
		"ambient": Color(0.2, 0.3, 0.3), "ambient_energy": 0.32,
		"fog": Color(0.015, 0.025, 0.027), "fog_density": 0.012, "bg": Color(0.008, 0.01, 0.014),
	}


## Waypoints por defecto: ninguno (los pisos los definen). Conecta vecinos a < max_dist.
func _build_waypoints(max_dist: float = 7.0) -> void:
	astar.clear()
	for i in waypoints.size():
		astar.add_point(i, waypoints[i])
	for i in waypoints.size():
		for j in range(i + 1, waypoints.size()):
			if waypoints[i].distance_to(waypoints[j]) <= max_dist:
				astar.connect_points(i, j)


func _ambient() -> void:
	AudioManager.play_ambient("fluorescente_zumbido")


## Ruta de waypoints desde from hasta to (ambos se acercan al waypoint más cercano).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if waypoints.is_empty():
		return PackedVector3Array([to])
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	var pts := astar.get_point_path(a, b)
	var out := PackedVector3Array()
	for p in pts:
		out.append(p)
	out.append(to)
	return out


func add_elevator(pos: Vector3, rot_deg: float = 0.0) -> Node3D:
	var packed: PackedScene = load(ELEVATOR_SCENE)
	var e := packed.instantiate() as Node3D
	e.position = pos
	e.rotation_degrees.y = rot_deg
	e.set("current_floor", floor_number)
	add_child(e)
	# v0.3.1 pisos: umbral bajo las hojas (el hall angosto ya no pasa por debajo del portal: quedaba una ranura).
	Greybox.sbox(e, "Umbral", Vector3(0, -0.05, 1.3), Vector3(2.2, 0.1, 0.5), "porcelanato_negro")
	# v0.3.1 pisos: el marcador sale 1,8 m delante del portal en la orientación del ascensor (antes siempre +Z).
	Greybox.marker(self, "ascensor", pos + Basis(Vector3.UP, deg_to_rad(rot_deg)) * Vector3(0, 0, 1.8), rot_deg + 180.0)
	return e


## Escalera: dos interactuables (subir/bajar) con destino. blocked_up = puerta cortafuego 3-8.
## v0.3.1 pisos: rot_deg gira el conjunto (0 = las puertas miran a +Z, como antes; 180 = a −Z, la escalera queda
## del lado opuesto a los ascensores). El marcador `escalera` sale 1,5 m delante de las puertas, de espaldas a ellas.
func add_stairs(pos: Vector3, down_to: int, up_to: int, blocked_up: bool = false, rot_deg: float = 0.0) -> void:
	var root := Node3D.new()
	root.name = "EscaleraNucleo"
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	Greybox.box(root, "Escalera", Vector3(0, 1.2, 0), Vector3(3.0, 2.4, 0.3), Greybox.BLANCO_PARED)
	Greybox.label(root, "ESCALERA", Vector3(0, 2.25, 0.2), 0.2, Color(0.2, 0.2, 0.2))
	Greybox.exit_sign(root, "SalidaEscalera", Vector3(0, 2.6, 0.25), 0.0)
	var basis := Basis(Vector3.UP, deg_to_rad(rot_deg))
	Greybox.marker(self, "escalera", pos + basis * Vector3(0, 0, 1.5), rot_deg + 180.0)
	if down_to != 0:
		var d := WorldObjects.Stairs.new()
		d.name = "EscaleraBajar"
		d.target_floor = down_to
		d.going_up = false
		d.size = Vector3(1.2, 2.0, 0.8)
		d.position = Vector3(-0.8, 1.0, 0.4)
		root.add_child(d)
		_fire_door_leaf(d)
	var u := WorldObjects.Stairs.new()
	u.name = "EscaleraSubir"
	u.target_floor = up_to
	u.going_up = true
	u.blocked_reader = blocked_up
	u.size = Vector3(1.2, 2.0, 0.8)
	u.position = Vector3(0.8, 1.0, 0.4)
	root.add_child(u)
	_fire_door_leaf(u)
	if blocked_up:
		Greybox.box(u, "Lector", Vector3(0.55, 0.2, 0.06), Vector3(0.06, 0.1, 0.03), Greybox.ROJO, false, 2.0)
		Greybox.label(u, tr("SIGN_FIRE_DOOR"), Vector3(0, 0.6, 0.06), 0.12, Greybox.ROJO)


## Hoja de puerta cortafuego gris con barra antipánico (site: escalera de emergencia).
static func _fire_door_leaf(parent: Node3D) -> void:
	Greybox.box(parent, "Puerta", Vector3.ZERO, Vector3(0.9, 2.0, 0.08), Greybox.CORTAFUEGO, false)
	Greybox.box(parent, "Barra", Vector3(0, -0.05, 0.06), Vector3(0.7, 0.05, 0.05), Greybox.INOX, false)
	Greybox.box(parent, "Moldura", Vector3(0, 1.03, 0), Vector3(1.0, 0.06, 0.1), Greybox.GRIS_OSCURO, false)


## Baño común (regular) o individual: cuarto cerrado con puerta, luz, espejo, terminal afuera.
## v0.3.1 pisos: door_side admite "n"/"s"/"e"/"w" y door_offset corre la puerta a lo largo de su pared (en metros,
## sobre el eje x del mundo para "n"/"s" y sobre z para "e"/"w"). Para "e"/"w" el baño se arma girado ±90° (por dentro
## la puerta siempre queda en su pared local +Z), así los artefactos nunca quedan delante de la puerta. Con la puerta
## corrida hacia un lado, cubículos y encimera se espejan para dejar libre la entrada. urinals = false: baño de mujeres
## (solo cubículos).
func add_bathroom(id: String, center: Vector3, size: Vector2, single: bool, door_side: String = "s", door_offset: float = 0.0, urinals: bool = true) -> Bathroom:
	var yaw := 0.0
	var lsize := size
	var lside := door_side
	var loff := door_offset
	if door_side == "e" or door_side == "w":
		yaw = 90.0 if door_side == "e" else -90.0
		lsize = Vector2(size.y, size.x)
		lside = "s"
		loff = -door_offset if door_side == "e" else door_offset
	var b := Bathroom.new()
	b.name = "Bano_" + id
	b.floor_number = floor_number
	b.single = single
	b.zone_id = id
	b.position = center
	b.rotation_degrees.y = yaw
	add_child(b)
	size = lsize
	# v0.3.1 Q5 (site, baño del piso 1): cerámica blanca 30×60 hasta el techo, porcelanato gris 60×60 con sumidero,
	# techo de baldosa, luz de 5000 K, cubículos de laminado blanco con patas inox y mamparas verdosas.
	Greybox.room_walls(b, "Pared", Vector2.ZERO, size, 2.6, Greybox.CERAMICA, [lside])
	for w in b.get_children():
		if w is MeshInstance3D and str(w.name).begins_with("Pared"):
			(w as MeshInstance3D).material_override = Greybox.surf("ceramica_blanca")
	Greybox.sceiling(b, "Techo", Vector2.ZERO, size, 2.6, "baldosa_techo")
	Greybox.sfloor(b, "Piso", Vector2.ZERO, size, "porcelanato_gris")
	Greybox.cylinder(b, "Sumidero", Vector3(0.2, 0.004, 0.1), 0.07, 0.006, Greybox.INOX, false, 0.32, 0.45)
	Greybox.downlight(b, "Downlight", Vector3(0, 2.58, 0), Color(1.0, 0.95, 0.88), 0.0, 1.0, false)
	var l := Greybox.light(b, Vector3(0, 2.3, 0), Color(1.0, 0.94, 0.86), 1.0, 5.0)
	b.light_node = l
	Zone.make(b, id, Vector3(0, 1.3, 0), Vector3(size.x - 0.2, 2.6, size.y - 0.2))
	# Puerta en el lado indicado (corrida loff sobre su pared), con la pared partida en dos tramos.
	var hz := size.y * 0.5
	var hx := size.x * 0.5
	loff = clampf(loff, -hx + 0.6, hx - 0.6)
	var out_s := 1.0 if lside == "s" else -1.0  # hacia afuera, en z local
	var door_pos := Vector3(loff, 1.0, hz * out_s)
	var seg_a := (loff - 0.5) - (-hx)
	var seg_b := hx - (loff + 0.5)
	if seg_a > 0.01:
		Greybox.box(b, "PuertaMarcoA", Vector3(-hx + seg_a * 0.5, 1.3, door_pos.z), Vector3(seg_a, 2.6, 0.2), Greybox.BLANCO)
	if seg_b > 0.01:
		Greybox.box(b, "PuertaMarcoB", Vector3(hx - seg_b * 0.5, 1.3, door_pos.z), Vector3(seg_b, 2.6, 0.2), Greybox.BLANCO)
	# Umbral bajo la puerta (la pared tiene 20 cm y el piso de afuera puede terminar en su cara).
	Greybox.sbox(b, "Umbral", Vector3(loff, -0.05, door_pos.z + 0.05 * out_s), Vector3(1.0, 0.1, 0.5), "porcelanato_gris")
	var door := WorldObjects.Door.new()
	door.name = "Puerta"
	door.size = Vector3(1.2, 2.2, 0.6)
	door.position = door_pos
	b.add_child(door)
	door.leaf = Greybox.box(door, "Hoja", Vector3.ZERO, Vector3(0.95, 2.1, 0.06), Greybox.PUERTA_BLANCA, true)
	Greybox.box(door.leaf, "Rejilla", Vector3(0, -0.8, 0.032 * out_s), Vector3(0.4, 0.18, 0.005), Color(0.75, 0.74, 0.7), false)
	# La encimera (con colisión) va siempre en la pared lateral opuesta a la puerta: con la puerta corrida a −x se espeja.
	var fx := -1.0 if loff < -0.3 else 1.0
	var far := -hz * out_s  # pared opuesta a la puerta
	var inward := out_s  # desde la pared del fondo hacia la puerta
	if not single:
		# Encimera de granito con 3 lavatorios + espejo corrido con luz indirecta (distorsión 5 posible).
		Greybox.sbox(b, "Encimera", Vector3(fx * (-hx + 0.4), 0.85, 0), Vector3(0.6, 0.1, size.y - 1.0), "granito")
		Greybox.box(b, "EncimeraFrente", Vector3(fx * (-hx + 0.4), 0.42, 0), Vector3(0.55, 0.8, size.y - 1.0), Greybox.GRIS_OSCURO)
		for i in 3:
			var lz := -(size.y - 1.0) * 0.5 + (size.y - 1.0) * (i + 0.5) / 3.0
			Greybox.cylinder(b, "Lavatorio%d" % i, Vector3(fx * (-hx + 0.4), 0.88, lz), 0.2, 0.08, Greybox.CERAMICA)
			Greybox.cylinder(b, "Grifo%d" % i, Vector3(fx * (-hx + 0.22), 1.0, lz), 0.015, 0.2, Greybox.INOX, false, 0.32, 0.45)
		Greybox.box(b, "LuzEspejo", Vector3(fx * (-hx + 0.3), 2.25, 0), Vector3(0.1, 0.04, size.y - 1.2), Color(0.9, 0.95, 1.0), false, 1.8)
		Greybox.box(b, "Dispensador", Vector3(fx * (-hx + 0.08), 1.3, (size.y - 1.0) * 0.5 - 0.2), Vector3(0.1, 0.25, 0.12), Greybox.INOX, false)
		var mirror := WorldObjects.Mirror.new()
		mirror.name = "Espejo"
		mirror.zone_id = id
		mirror.size = Vector3(0.6, 1.2, size.y - 1.0)
		mirror.position = Vector3(fx * (-hx + 0.15), 1.6, 0)
		b.add_child(mirror)
		var vidrio := Greybox.box(mirror, "Vidrio", Vector3.ZERO, Vector3(0.04, 1.0, size.y - 1.2), Color(0.55, 0.65, 0.7), false, 0.2)
		vidrio.material_override = Greybox.material(Color(0.5, 0.6, 0.66), 0.15, 0.08, 0.9)
		for i in 3:
			var cz := far * 1.0 + inward * (0.8 + i * 1.2)
			if absf(cz - door_pos.z) < 1.1 and absf(fx * (hx - 0.6) - loff) < 1.2:
				continue  # el cubículo no tapa la entrada
			if absf(cz) > hz - 0.3 or absf(cz + inward * 0.6) > hz - 0.1:
				continue  # baño angosto: no entra otro cubículo
			Greybox.box(b, "Cubiculo%d" % i, Vector3(fx * (hx - 0.6), 1.05, cz), Vector3(1.0, 1.9, 0.04), Color(0.933, 0.933, 0.918), false)
			var cp := Greybox.box(b, "CubiculoPuerta%d" % i, Vector3(fx * (hx - 1.1), 1.05, cz + inward * 0.6), Vector3(0.04, 1.9, 1.15), Color(0.92, 0.92, 0.9), false)
			Greybox.box(cp, "Pata", Vector3(0, -0.98, 0.55), Vector3(0.03, 0.15, 0.03), Greybox.INOX, false)
		# Urinarios con mamparas de vidrio esmerilado verdoso y secador de manos inox.
		for i in (2 if urinals else 0):
			var ux := fx * (-hx + 1.4 + i * 0.75)
			Greybox.box(b, "Urinario%d" % i, Vector3(ux, 0.6, far + inward * 0.25), Vector3(0.35, 0.55, 0.3), Greybox.CERAMICA, false)
			Greybox.box(b, "Mampara%d" % i, Vector3(ux + fx * 0.38, 0.95, far + inward * 0.45), Vector3(0.02, 1.1, 0.7), Color(0.663, 0.725, 0.698, 0.6), false)
		Greybox.box(b, "Secador", Vector3(fx * (-hx + 0.1), 1.25, -(size.y - 1.0) * 0.5 - 0.15), Vector3(0.12, 0.28, 0.24), Greybox.INOX, false).material_override = Greybox.inox()
	else:
		Greybox.box(b, "Inodoro", Vector3(0, 0.25, far + inward * 0.5), Vector3(0.4, 0.5, 0.5), Greybox.CERAMICA, false)
		Greybox.box(b, "Lavatorio", Vector3(hx - 0.4, 0.8, 0), Vector3(0.4, 0.1, 0.4), Greybox.CERAMICA, false)
		var esp := Greybox.box(b, "EspejoChico", Vector3(hx - 0.1, 1.5, 0), Vector3(0.02, 0.5, 0.4), Color(0.5, 0.6, 0.66), false, 0.15)
		esp.material_override = Greybox.material(Color(0.5, 0.6, 0.66), 0.15, 0.08, 0.9)
		Greybox.box(b, "Extractor", Vector3(0, 2.5, far + inward * 0.3), Vector3(0.3, 0.1, 0.3), Greybox.GRIS, false)
		Greybox.box(b, "Pestillo", Vector3(loff + 0.45, 1.0, door_pos.z - out_s * 0.1), Vector3(0.1, 0.05, 0.05), Greybox.GRIS_OSCURO, false)
	# v0.3.2 (Joan): sin terminal Fonex junto al baño; el AUX solo se cambia en una PC de la sala (o con el comodín).
	# v0.3 P6b: una sola cara (por fuera): desde dentro del baño se veía "soñaB" por el hueco de la puerta.
	Greybox.one_sided(WorldObjects.signage(self, "SIGN_BATHROOM", b.transform * Vector3(loff, 2.3, door_pos.z + 0.3 * out_s), yaw + (0.0 if lside == "s" else 180.0), 0.25))
	return b


## Ganchos de distorsión (los pisos sobreescriben lo que les toca).
func apply_distortion(_id: String, _data: Dictionary) -> void:
	pass


func seat_by_id(id: String) -> WorldObjects.Seat:
	var n := find_child("Seat_" + id, true, false)
	return n as WorldObjects.Seat

extends Node
## Rasec en la sala de PCs (piso 2): comportamiento de piso (data/comportamientos.json → marcador
## evento_rasec). El cerebro es RasecControl (persistente). Rasec está de pie al fondo de la sala, en el
## pasillo sur (es TM de otro equipo); es calvo y se pone el pelo (nodo "Pelo") cuando suena su música o en
## su evento. En el evento arma el centro de la sala: cartel "¡FELIZ …!", luces de fiesta, compañeros de pie
## que sonríen demasiado y te miran todos a la vez, y en el juego de la silla las sillas con nombre (una con
## el tuyo). En el escalón verbal de las pistas de coaching (P3) viene a tu sitio en persona.
## v0.3.1 Q2 (F19): trabaja SENTADO en su escritorio del TM (al lado de Shero, NpcDesks), con los audífonos y sin
## pelo, tecleando. Se levanta (stand_up) para su música (DJ de pie junto al escritorio, con pelo), para su evento y
## para venir a tu sitio; al terminar vuelve caminando y se sienta (sit_down).

const POST := Vector3(33.0, 0, -18.9)  # P6b: bajo el reloj de pared, frente a la sala (antes detrás de A-03, casi no se veía)

var floor_node: FloorBase = null
var actor: P5Actor = null
var _post: Vector3 = Vector3.ZERO
var _props: Node3D = null
var _lights: Array[OmniLight3D] = []
var _people: Array[Node3D] = []
var _borrowed: Array = []  # [rig, cubículo, transform] de los agentes de la fila C que vienen al evento
var _chairs: Node3D = null
var _t: float = 0.0
var _return_in: float = 0.0
var _party: bool = false
var _going_home: bool = false
var seated: bool = false
var _post_yaw: float = PI


func setup_behaviour(fl: Node, _marker: Node, _entry: Dictionary) -> void:
	floor_node = fl as FloorBase
	add_to_group("p5_rasec_actor")
	var hub := PersonajesP5.ensure(get_tree())
	_post = floor_node.global_position + POST
	NpcDesks.ensure(floor_node)
	var desk := floor_node.find_child("escritorio_rasec", true, false) as Node3D
	if desk != null:
		_post = desk.global_position
		_post_yaw = desk.global_rotation.y
	actor = P5Actor.make(floor_node, "rasec", 1.84, Vector3.ZERO, 0.0, "Rasec")
	actor.global_position = _post
	actor.rotation.y = _post_yaw  # mira a la sala
	actor.floor_ref = floor_node
	actor.speed = 1.5
	_sit(true)
	actor.set_hair(false)
	var luz := OmniLight3D.new()  # P6b: un fluorescente propio para que se le vea desde C-14
	luz.name = "LuzRasec"
	luz.light_color = Color(0.85, 0.92, 0.9)
	luz.light_energy = 0.8
	luz.omni_range = 3.2
	luz.shadow_enabled = false
	floor_node.add_child(luz)
	luz.global_position = _post + Vector3(0, 2.6, 0.0)
	if hub != null:
		hub.rasec_music.connect(_on_music)
		hub.rasec_event_called.connect(_on_event_called)
		hub.rasec_event_started.connect(_on_event_started)
		hub.rasec_event_finished.connect(_on_event_finished)
		if hub.rasec != null and hub.rasec.music_on:
			_on_music(true)
		if hub.rasec != null and hub.rasec.state in [RasecControl.State.CONVOCADO, RasecControl.State.EVENTO]:
			_on_event_called(hub.rasec.kind)
	EventBus.death_sequence_started.connect(_on_death)
	EventBus.respawned.connect(_on_respawned)


func _event_point() -> Vector3:
	var m := floor_node.find_child("evento_rasec", true, false) as Node3D
	return m.global_position if m != null else _post


## Sentado en su escritorio (tecleando) o de pie. instant: sin clip de transición.
func _sit(instant: bool = false) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	seated = true
	_going_home = false
	actor.global_position = _post
	actor.rotation.y = _post_yaw
	if instant:
		actor.play("sit_type", true, 0.9, ["sit", "idle"])
	else:
		actor.play("sit_down", true, 1.0, ["sit", "idle"])
		var wa: WeakRef = weakref(actor)
		var me: WeakRef = weakref(self)
		get_tree().create_timer(CharacterRig.STAND_S).timeout.connect(func() -> void:
			var a: P5Actor = wa.get_ref()
			var r: Node = me.get_ref()
			if a != null and r != null and bool(r.get("seated")) and not bool(r.get("_party")):
				a.play("sit_type", true, 0.9, ["sit", "idle"]))


## Se levanta del escritorio; devuelve lo que tarda.
func _stand() -> float:
	if not seated or actor == null or not is_instance_valid(actor):
		return 0.0
	seated = false
	actor.play("stand_up", true, 1.0, ["idle"])
	return CharacterRig.STAND_S


func _on_music(on: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.set_hair(on or _party)
	if not _party:
		if on:
			var w := _stand()
			if w > 0.0:
				await get_tree().create_timer(w).timeout
			if actor != null and is_instance_valid(actor) and not _party:
				actor.play("dj", true, 0.9, ["idle"])
		elif not seated:
			_sit()
	if on and _lights.is_empty():
		_add_lights(_post + Vector3(0, 2.4, 1.5), 1)


func _add_lights(at: Vector3, n: int) -> void:
	for i in n:
		var l := OmniLight3D.new()
		l.light_color = [Color(1.0, 0.35, 0.7), Color(0.4, 0.5, 1.0), Color(1.0, 0.7, 0.25)][i % 3]
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.shadow_enabled = false
		l.set_meta("no_mood", true)
		floor_node.add_child(l)
		l.global_position = at + Vector3(cos(i * 2.1) * 1.4, 0, sin(i * 2.1) * 1.4)
		_lights.append(l)


func _clear_lights() -> void:
	for l in _lights:
		if is_instance_valid(l):
			l.queue_free()
	_lights.clear()


func _on_event_called(kind: String) -> void:
	_party = true
	_build_party(kind)
	if actor != null and is_instance_valid(actor):
		actor.set_hair(true)
		var w := _stand()
		if w > 0.0:
			await get_tree().create_timer(w).timeout
		if actor != null and is_instance_valid(actor) and _party:
			actor.walk_to(_event_point() + Vector3(0, 0, -1.6))


func _build_party(kind: String) -> void:
	_clear_party()
	_props = Node3D.new()
	_props.name = "FiestaRasec"
	floor_node.add_child(_props)
	var c := _event_point()
	var hub := PersonajesP5.get_hub(get_tree())
	# v0.3.2-core: la decoración es una guirnalda de banderines con los colores del tema, colgada por encima de las
	# cabezas. Antes era el mismo texto del cartel de la interfaz («¡FELIZ HALLOWEEN!») flotando a 2,75 m y girando
	# hacia la cámara: se veía dos veces (interfaz + mundo), se metía en los ductos y, de cerca, el borde de la
	# pantalla lo cortaba. El texto queda solo en la interfaz del evento (EventoUI).
	var tid := str(hub.rasec.theme().get("id", "")) if hub != null and hub.rasec != null else ""
	_bunting(c + Vector3(-3.4, 0, -3.0), c + Vector3(3.4, 0, -3.0), tid, 0)
	_bunting(c + Vector3(-3.4, 0, 3.6), c + Vector3(3.4, 0, 3.6), tid, 1)
	_add_lights(c + Vector3(0, 2.6, 0), 3)
	# Compañeros de pie alrededor, todos mirando al centro… y a ti: los agentes de la fila C dejan sus sitios
	# (las sillas quedan vacías, con el headset colgando) y se paran en círculo, sonriendo demasiado.
	var k := 0
	for id in ["C-10", "C-11", "C-12", "C-16"]:
		var seat := floor_node.seat_by_id(id)
		if seat == null:
			continue
		var cub := seat.get_parent() as Node3D
		var rig: CharacterRig = null
		for ch in cub.get_children():
			if ch is CharacterRig:
				rig = ch
		if rig == null:
			continue
		var ang := -PI * 0.15 + k * PI * 0.43
		var p := c + Vector3(cos(ang) * 2.2, 0, sin(ang) * 1.3)
		_people.append(rig)
		_borrowed.append([rig, cub, rig.transform])
		rig.global_position = p  # sigue colgado de su cubículo (re-colgarlo recrea sus materiales)
		rig.look_at(Vector3(c.x, p.y, c.z), Vector3.UP)
		rig.play("float" if k % 2 == 0 else "idle", true, 0.35, ["idle"])
		k += 1
	if kind == "sillas":
		_chairs = Node3D.new()
		_chairs.name = "Sillas"
		_props.add_child(_chairs)


## Colores de los banderines por tema (rasec_eventos.json/temas[].id).
const BUNTING := {
	"halloween": [Color(0.95, 0.42, 0.05), Color(0.16, 0.06, 0.22), Color(0.95, 0.42, 0.05), Color(0.05, 0.05, 0.05)],
	"navidad": [Color(0.75, 0.08, 0.08), Color(0.08, 0.45, 0.16), Color(0.85, 0.82, 0.75)],
	"san_valentin": [Color(0.85, 0.12, 0.25), Color(0.95, 0.6, 0.7), Color(0.9, 0.88, 0.86)],
	"madre": [Color(0.92, 0.55, 0.68), Color(0.9, 0.88, 0.86), Color(0.75, 0.45, 0.8)],
	"fiestas_patrias": [Color(0.8, 0.06, 0.08), Color(0.9, 0.9, 0.9)],
	"aniversario": [Color(0.9, 0.72, 0.2), Color(0.137, 0.251, 0.369), Color(0.29, 0.667, 0.776)],
}

## Guirnalda de banderines entre dos puntos (a, b: posiciones en el suelo), colgada del techo a 2,62 m y con comba.
## Todo por encima de 2,2 m: nadie la atraviesa ni tapa la vista; sin colisión y sin luces propias.
func _bunting(a: Vector3, b: Vector3, theme_id: String, phase: int) -> void:
	var cols: Array = BUNTING.get(theme_id, [Greybox.AMBAR, Greybox.TURQUESA, Greybox.CREMA])
	var root := Node3D.new()
	root.name = "Banderines%d" % phase
	_props.add_child(root)
	var top := 2.62
	var sag := 0.14
	var n := 13
	var dir := (b - a)
	var yaw := atan2(dir.x, dir.z) + PI * 0.5
	var prev := a + Vector3(0, top, 0)
	for i in range(1, n + 1):
		var u := float(i) / float(n)
		var p := a.lerp(b, u) + Vector3(0, top - sag * 4.0 * u * (1.0 - u), 0)
		# el hilo: un tramo fino entre punto y punto
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.012, prev.distance_to(p))
		seg.mesh = bm
		seg.material_override = Greybox.material(Greybox.NEGRO)
		root.add_child(seg)
		seg.global_position = (prev + p) * 0.5
		seg.look_at(p, Vector3.UP)
		# el banderín cuelga del medio del tramo, con la punta hacia abajo
		var flag := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.24, 0.28, 0.006)
		flag.mesh = pm
		flag.name = "Banderin%d" % i
		flag.material_override = Greybox.material(cols[(i + phase) % cols.size()], 0.25, 0.8)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flag)
		flag.global_position = (prev + p) * 0.5 - Vector3(0, 0.15, 0)
		flag.rotation = Vector3(0, yaw, PI)
		prev = p
	# dos hilos al techo en los extremos
	for e in [a, b]:
		var hilo := Greybox.cylinder(root, "Hilo", Vector3.ZERO, 0.006, 0.7, Greybox.NEGRO)
		hilo.global_position = (e as Vector3) + Vector3(0, top + 0.35, 0)


## Juego de la silla: sillas en círculo con un nombre cada una (una con el tuyo).
func chairs_round(names: Array) -> void:
	if _chairs == null or not is_instance_valid(_chairs):
		return
	for ch in _chairs.get_children():
		ch.queue_free()
	var c := _event_point()
	for i in names.size():
		var ang := TAU * i / names.size()
		var p := c + Vector3(cos(ang) * 1.3, 0, sin(ang) * 1.1)
		var seat := Greybox.box(_chairs, "Silla%d" % i, Vector3.ZERO, Vector3(0.42, 0.06, 0.42), Greybox.NEGRO, false)
		seat.global_position = p + Vector3(0, 0.45, 0)
		var back := Greybox.box(seat, "Respaldo", Vector3(0, 0.26, 0.2), Vector3(0.42, 0.5, 0.04), Greybox.NEGRO, false)
		back.rotation.y = 0.0
		var lb := Greybox.label(seat, str(names[i]), Vector3(0, 0.62, 0.2), 0.09, Color(1, 0.9, 0.6) if str(names[i]) == GameState.agent else Color(0.8, 0.8, 0.8))
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func mime() -> void:
	if actor != null and is_instance_valid(actor):
		actor.play(["hunch", "float", "point", "stare_camera"][randi() % 4], true, 0.7, ["idle"])


func _on_event_started(kind: String) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.stop_walking("karaoke" if kind == "karaoke" else "dj")
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		actor.look_toward(pl.global_position)
	if kind == "karaoke":
		Greybox.cylinder(actor, "Microfono", Vector3(0.16, 1.32, -0.25), 0.025, 0.2, Greybox.NEGRO)


func _on_event_finished(_kind: String, _took: bool) -> void:
	_party = false
	_return_in = 3.0


func _clear_party() -> void:
	if _props != null and is_instance_valid(_props):
		_props.queue_free()
	_props = null
	_chairs = null
	for b in _borrowed:
		var rig := b[0] as CharacterRig
		var cub := b[1] as Node3D
		if is_instance_valid(rig) and is_instance_valid(cub):
			rig.transform = b[2]
			rig.play("type", true, 0.9, ["sit", "idle"])
	_borrowed.clear()
	_people.clear()
	_clear_lights()


## Escalón verbal de las pistas de coaching (P3): viene a tu sitio y te lo dice en persona.
func come_to_player(text: String, key: String) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var w := _stand()
	if w > 0.0:
		await PersonajesP5.wait(self, w)
	if actor == null or not is_instance_valid(actor):
		return
	var d := actor.global_position - pl.global_position
	d.y = 0.0
	actor.walk_to(pl.global_position + d.normalized() * 1.4)
	_return_in = 14.0
	await PersonajesP5.wait(self, 3.5)
	if actor == null or not is_instance_valid(actor):
		return
	actor.stop_walking("point")
	actor.look_toward(pl.global_position)
	PersonajesP5.say("Rasec", "rasec", key, text)


func _process(delta: float) -> void:
	_t += delta
	# Los compañeros del evento giran despacio hasta mirarte a ti, todos a la vez.
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null and _party:
		for r in _people:
			if is_instance_valid(r):
				var d := pl.global_position - r.global_position
				d.y = 0.0
				if d.length() > 0.3:
					r.rotation.y = lerp_angle(r.rotation.y, atan2(-d.x, -d.z), minf(delta * 0.8, 1.0))
	for i in _lights.size():
		var l := _lights[i]
		if is_instance_valid(l):
			l.light_energy = 0.6 + 0.8 * absf(sin(_t * (2.2 + i) + i))
	if _return_in > 0.0:
		_return_in -= delta
		if _return_in <= 0.0:
			_clear_party()
			_back()
	if _going_home and actor != null and is_instance_valid(actor) and not actor.walking:
		_going_home = false
		var hub := PersonajesP5.get_hub(get_tree())
		var music := hub != null and hub.rasec != null and hub.rasec.music_on
		if music:
			actor.global_position = _post
			actor.rotation.y = _post_yaw
			actor.play("dj", true, 0.9, ["idle"])
		else:
			_sit()


func _back() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.visible = true
	var hub := PersonajesP5.get_hub(get_tree())
	var music := hub != null and hub.rasec != null and hub.rasec.music_on
	actor.set_hair(music)
	actor.look_toward(Vector3.INF)
	var mic := actor.get_node_or_null("Microfono")
	if mic != null:
		mic.queue_free()
	actor.walk_to(_post)
	_going_home = true


func _on_death(_c: String, killer: String, _d: String) -> void:
	if killer == "rasec" and actor != null and is_instance_valid(actor):
		actor.visible = false  # el screamer trae a Rasec frente a tu cámara (con pelo que se le cae)


func _on_respawned(_k: String) -> void:
	_party = false
	_clear_party()
	_return_in = 0.0
	if actor != null and is_instance_valid(actor):
		actor.visible = true
		actor.stop_walking("idle")
		actor.set_hair(false)
		_sit(true)

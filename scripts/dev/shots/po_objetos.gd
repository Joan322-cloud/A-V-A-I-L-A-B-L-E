## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de v0.3.2-anim (animación de OBJETOS, scripts/mundo/object_anim.gd). Para --write-movie (marcas [video]):
##   po_obj:todo        la muestra completa: puerta del baño (manija, giro, se pasa y vuelve; al cerrar toca el marco),
##                      portazo de un perseguidor, sillas (un compañero se para y se sienta), ascensor (indicador que
##                      rueda, gomas), casillero y refri, microondas (plato, luz, puerta), expendedora (cae la lata),
##                      monitores que despiertan, la taza de C-13, papeles con el aire, el teléfono de QA.
##   po_obj:<escena>    una sola: puerta | portazo | silla | ascensor | casillero | refri | microondas | expendedora |
##                      monitor | taza | papeles | telefono | deck
## Cada escena coloca su cámara con relación al objeto (no hay coordenadas fijas del piso).

var _camera: Camera3D = null


func shots() -> Array[String]:
	return ["po_obj:", "po_cam:"]


func _quiet(s: Node) -> void:
	var cm := s._main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()
	var hud := s._main.get("hud") as Control
	if hud != null:
		hud.visible = false
	for n in s.get_tree().get_nodes_in_group("workstation"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


## Cámara propia en coordenadas del mundo.
func _cam(s: Node, pos: Vector3, look: Vector3, fov: float = 50.0) -> Camera3D:
	if _camera == null or not is_instance_valid(_camera):
		_camera = Camera3D.new()
		_camera.name = "CamObjetos"
		s.get_tree().root.add_child(_camera)
	_camera.fov = fov
	_camera.global_position = pos
	_camera.look_at(look, Vector3.UP)
	_camera.current = true
	return _camera


## Cámara relativa a un nodo: `off` y `look` en su espacio local (sin su escala).
func _cam_rel(s: Node, n: Node3D, off: Vector3, look: Vector3 = Vector3.ZERO, fov: float = 50.0) -> Camera3D:
	var g := Transform3D(n.global_transform.basis.orthonormalized(), n.global_position)
	return _cam(s, g * off, g * look, fov)


func _label(s: Node, text: String) -> void:
	var cl := s.get_tree().root.find_child("RotuloObjetos", true, false) as Label
	if cl == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		s.get_tree().root.add_child(layer)
		cl = Label.new()
		cl.name = "RotuloObjetos"
		cl.position = Vector2(28, 22)
		cl.add_theme_font_size_override("font_size", 30)
		cl.add_theme_color_override("font_color", Color(1, 1, 1))
		cl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cl.add_theme_constant_override("outline_size", 8)
		layer.add_child(cl)
	cl.text = text


## Cámara de la escena relativa a `n`: «x|y|z|mirax|miray|miraz|fov». Con po_cam:<escena>@N,<spec> se prueba otra.
func _cam_spec(s: Node, n: Node3D, def: String) -> void:
	var p := (_variant if _variant.count("|") == 6 else def).split("|")
	_cam_rel(s, n, Vector3(float(p[0]), float(p[1]), float(p[2])), Vector3(float(p[3]), float(p[4]), float(p[5])), float(p[6]))


func _floor(s: Node, f: int) -> Node3D:
	var b: Building = s._building()
	if b.current_floor != f or b.floor_node == null:
		b.go_to_floor(f, "ascensor")
		await _wait(s, 0.8)
	var p: Player = s._player()
	if p != null and p.seated:
		p.stand_up()
	return b.floor_node


func _find(fl: Node, n: String) -> Node3D:
	return fl.find_child(n, true, false) as Node3D


## Sitúa al jugador (sin cuerpo a la vista) delante de un nodo: es quien «abre».
func _player_at(s: Node, pos: Vector3, yaw: float = 0.0) -> void:
	var p: Player = s._player()
	if p == null:
		return
	if p.seated:
		p.stand_up()
	p.teleport(pos, yaw)


func _hide_player(s: Node, hide: bool) -> void:
	var p := s._player() as Node3D
	if p != null:
		p.visible = not hide


func _actor(parent: Node3D, slug: String, pos: Vector3, yaw: float, h: float = 1.72) -> CharacterRig:
	var holder := Node3D.new()
	holder.name = "ActorObj_" + slug
	parent.add_child(holder)
	holder.global_position = pos
	holder.rotation_degrees.y = yaw
	return CharacterRig.attach(holder, slug, h)


func shoot(p_name: String, arg: String, s: Node) -> void:
	await _wait(s, 0.5)
	_quiet(s)
	if p_name == "po_cam":
		# una foto: po_cam:<escena>[@segundos][,variante]  (prepara la escena, la echa a andar y captura a los N s)
		var sc := arg.get_slice("@", 0)
		var rest := arg.get_slice("@", 1) if arg.contains("@") else "0"
		_variant = rest.get_slice(",", 1) if rest.contains(",") else ""
		await call("_prep_" + sc, s)
		call("_do_" + sc, s)
		await _wait(s, maxf(float(rest.get_slice(",", 0)), 0.05))
		return
	var what := arg if arg != "" else "todo"
	var list: Array = [what]
	if what == "todo":
		list = ["puerta", "portazo", "silla", "ascensor", "microondas", "expendedora", "monitor", "taza"]
	elif what == "extra":
		list = ["casillero", "refri", "papeles", "telefono", "deck"]
	# preparación fuera de la toma (carga de pisos) y después las marcas
	var first := true
	for sc in list:
		await call("_prep_" + str(sc), s)
		_label(s, str(TITULOS.get(sc, "")))
		if first:
			print("[video] inicio %d" % Engine.get_frames_drawn())
			first = false
		else:
			print("[video] corte %d" % Engine.get_frames_drawn())
		await call("_do_" + str(sc), s)
		print("[video] hasta %d" % Engine.get_frames_drawn())
	print("[video] fin %d" % Engine.get_frames_drawn())
	await _wait(s, 0.3)


const TITULOS := {"puerta": "Puertas · manija, giro con peso, toca el marco", "portazo": "Portazo · un perseguidor la cruza corriendo",
	"silla": "Sillas · ruedan al pararse y al sentarse", "ascensor": "Ascensor · gomas, indicador que rueda",
	"microondas": "Microondas · puerta, luz, plato", "expendedora": "Expendedora · cae la lata", "monitor": "Monitores · despiertan y se duermen",
	"taza": "La taza de C-13 · todavía humea", "casillero": "Casillero", "refri": "Refrigeradora", "papeles": "Papeles con el aire",
	"telefono": "Teléfono de QA", "deck": "Puerta doble"}

# ---------------------------------------------------------------------------------------------------------------------
var _variant: String = ""  # po_cam: variante de cámara
var _n: Node3D = null  # objeto de la escena
var _fl: Node3D = null
var _aux: Array = []


## Puerta batiente: el jugador la abre y la vuelve a cerrar. Variantes de puerta/cámara (po_cam:puerta@1,<variante>):
##   piso|nodo|lado del jugador (±1 en z local de la puerta)|cámara x|y|z (local de la puerta)|fov
const PUERTAS := {
	"": "2|Bano_bano_p2/Puerta|out|-1.15|0.45|-2.3|58",
	"a": "2|Bano_bano_p2/Puerta|out|-1.15|0.45|-2.3|58",
	"b": "1|Topico|1|1.6|0.4|3.2|50",
	"b2": "1|Topico|-1|1.6|0.4|-3.2|50",
	"c": "1|Bano_bano_p1/Puerta|out|1.5|0.45|3.0|52",
	"d": "1|Training0|1|1.6|0.4|3.2|50",
	"d2": "1|Training0|-1|1.6|0.4|-3.2|50",
	"e": "-1|Bano_bano_m1_h/Puerta|out|-1.15|0.45|-2.3|58",
}


func _prep_puerta(s: Node) -> void:
	var spec: PackedStringArray = str(PUERTAS.get(_variant, PUERTAS[""])).split("|")
	_fl = await _floor(s, int(spec[0]))
	var path := spec[1]
	var holder := _find(_fl, path.get_slice("/", 0))
	_n = (holder.get_node(path.get_slice("/", 1)) if path.contains("/") else holder) as Node3D
	_hide_player(s, true)
	(_n as WorldObjects.Door).set_open(false)
	# «out» = el lado opuesto al centro del baño (el pasillo)
	var side := 1.0
	if spec[2] == "out":
		side = -signf((_n.global_transform.affine_inverse() * holder.global_position).z)
	else:
		side = float(spec[2])
	_aux = [side]
	_player_at(s, _n.global_transform * Vector3(0.1, -1.0, 1.1 * side))
	var cz := float(spec[5]) * (side if spec[2] == "out" else 1.0)
	_cam_rel(s, _n, Vector3(float(spec[3]), float(spec[4]), cz), Vector3(0.0, -0.1, 0.0), float(spec[6]))
	_label(s, "")
	await _wait(s, 0.6)


func _do_puerta(s: Node) -> void:
	var d := _n as WorldObjects.Door
	await _wait(s, 0.4)
	d.set_open(true)
	AudioManager.play_sfx("puerta_vidrio")
	await _wait(s, 1.8)
	d.set_open(false)
	AudioManager.play_sfx("puerta_vidrio")
	await _wait(s, 1.2)


## Portazo: un perseguidor cruza la puerta corriendo (la abre de golpe, rebota contra el tope).
func _prep_portazo(s: Node) -> void:
	_fl = await _floor(s, 2)
	var bath := _find(_fl, "Bano_bano_p2")
	_n = bath.get_node("Puerta") as Node3D
	(_n as WorldObjects.Door).set_open(false)
	_hide_player(s, true)
	var side := -signf((_n.global_transform.affine_inverse() * bath.global_position).z)
	_player_at(s, _n.global_transform * Vector3(0.0, -1.0, 9.0 * side))
	_cam_rel(s, _n, Vector3(-1.25, 0.5, -2.7 * side), Vector3(0.0, -0.1, 0.0), 60.0)  # desde dentro del baño: viene hacia la cámara
	var start: Vector3 = _n.global_transform * Vector3(0.0, -1.0, 5.2 * side)
	var to: Vector3 = _n.global_transform * Vector3(0.25, -1.0, -1.7 * side)
	var r := _actor(_fl, "shero", start, 0.0, 2.2)
	var h := r.get_parent() as Node3D
	h.look_at(Vector3(to.x, h.global_position.y, to.z), Vector3.UP)
	r.play("sprint", true, 1.0, ["run", "walk"])
	_aux = [h, to, r]
	await _wait(s, 0.6)


func _do_portazo(s: Node) -> void:
	var h := _aux[0] as Node3D
	var to: Vector3 = _aux[1]
	var d := _n as WorldObjects.Door
	var opened := false
	var t := 0.0
	while t < 2.8:
		var dt: float = s.get_process_delta_time()
		var dir := to - h.global_position
		dir.y = 0.0
		if dir.length() > 0.15:
			h.global_position += dir.normalized() * 4.6 * dt
		else:
			(_aux[2] as CharacterRig).play("idle")
		if not opened and h.global_position.distance_to(Vector3(_n.global_position.x, h.global_position.y, _n.global_position.z)) < 1.8:
			opened = true  # como Pursuit._open_doors
			d.set_open(true)
			AudioManager.play_sfx("puerta_vidrio")
		t += dt
		await s.get_tree().process_frame
	h.queue_free()
	d.set_open(false)


## Sillas: un compañero de la fila C se para (la silla rueda hacia atrás y gira), da un paso y se vuelve a sentar.
func _prep_silla(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	_player_at(s, Vector3(20, 0, 0))
	var cub := _find(_fl, "Cub_C-12")
	_n = cub
	var who: NpcAnimator = null
	for a in NpcAnimator._all:
		if is_instance_valid(a) and a.body != null and a.body.is_inside_tree() and a.state == "seated" and a.body.global_position.distance_to(cub.global_position + Vector3(0, 0, 0.45)) < 0.6:
			who = a
	_aux = [who]
	_cam_rel(s, cub, Vector3(1.9, 1.25, 2.3), Vector3(0.0, 0.7, 0.35), 50.0)
	await _wait(s, 0.6)


func _do_silla(s: Node) -> void:
	var who := _aux[0] as NpcAnimator
	if who == null:
		await _wait(s, 1.0)
		return
	var rig := who.body as CharacterRig
	await _wait(s, 0.4)
	rig.play("idle")
	await _wait(s, 2.3)
	rig.play("type", true, 0.9, ["sit", "idle"])
	await _wait(s, 2.5)


## Ascensor: desde adentro; las hojas cierran (gomas), el indicador rueda con su flecha, las hojas abren.
func _prep_ascensor(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	_n = _find(_fl, "Elevator")
	_player_at(s, _n.global_transform * Vector3(0, 0, 3.4))
	_cam_rel(s, _n, Vector3(-0.35, 1.55, -0.75), Vector3(0.0, 1.7, 1.1), 62.0)
	_n.call("set_doors", true, true)
	_n.call("show_floor", 2)
	await _wait(s, 0.5)


func _do_ascensor(s: Node) -> void:
	await _wait(s, 0.3)
	_n.call("set_doors", false)
	await _wait(s, 1.6)
	for f in [1, -1]:
		_n.call("show_floor", f)
		await _wait(s, 0.55)
	await _wait(s, 0.2)
	for f in [1, 2]:
		_n.call("show_floor", f)
		await _wait(s, 0.55)
	_n.call("set_doors", true)
	await _wait(s, 1.3)


## Casillero del piso 2: abrir (se pasa y vuelve) y cerrar con el golpe de chapa.
func _prep_casillero(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	_n = _find(_fl, "MiCasillero")
	_player_at(s, _n.global_transform * Vector3(0, -0.9, 1.4))
	_cam_rel(s, _n, Vector3(1.1, 0.5, 1.9), Vector3(0.0, 0.0, 0.2), 50.0)
	await _wait(s, 0.5)


func _do_casillero(s: Node) -> void:
	await _wait(s, 0.4)
	WorldObjects.DoorSwing.swing(_n, s._player(), 0.0, 1.5, 0.8)
	AudioManager.play_sfx("casillero_abrir")
	await _wait(s, 1.5)
	AudioManager.play_sfx("casillero_cerrar")
	await _wait(s, 1.3)


func _prep_refri(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	_n = _find(_fl, "Refri1")
	_player_at(s, _n.global_transform * Vector3(0, -0.9, 1.5))
	_cam_rel(s, _n, Vector3(1.3, 0.5, 2.1), Vector3(0.0, 0.0, 0.2), 50.0)
	await _wait(s, 0.5)


func _do_refri(s: Node) -> void:
	await _wait(s, 0.4)
	WorldObjects.DoorSwing.swing(_n, s._player(), 0.0, 1.6, 1.2)
	AudioManager.play_sfx("refri")
	await _wait(s, 3.0)


## Microondas del -1: los que calientan (vidrio encendido, la sombra del táper girando) y la puerta al meter el tuyo.
func _prep_microondas(s: Node) -> void:
	_fl = await _floor(s, -1)
	_hide_player(s, true)
	var bank := _find(_fl, "EstacionMicroondas")
	_n = bank
	_player_at(s, bank.global_transform * Vector3(0.0, 0.0, 1.6))
	var mws: Array = []
	for c in bank.get_children():
		if c is WorldObjects.Microwave:
			mws.append(c)
	if mws.size() >= 6:
		(mws[0] as WorldObjects.Microwave).set_state("libre")
		(mws[1] as WorldObjects.Microwave).set_state("ocupado", GameState.clock_seconds + 900.0, "T-08")
		(mws[2] as WorldObjects.Microwave).set_state("fuera")
		(mws[3] as WorldObjects.Microwave).set_state("ocupado", GameState.clock_seconds + 1500.0, "C-13")
		(mws[4] as WorldObjects.Microwave).set_state("libre")
		(mws[5] as WorldObjects.Microwave).set_state("ocupado", GameState.clock_seconds + 400.0, "E-02")
	_aux = mws
	if mws.size() >= 6:
		_cam_spec(s, mws[4] as Node3D, "0.5|0.2|1.4|0.0|0.0|0.0|46")  # cerca del que vas a usar
	else:
		_cam_rel(s, bank, Vector3(0.5, 1.5, 1.45), Vector3(0.0, 1.25, 0.0), 50.0)
	await _wait(s, 0.8)


func _do_microondas(s: Node) -> void:
	await _wait(s, 0.5)
	if _aux.size() >= 6:
		var mw := _aux[4] as WorldObjects.Microwave
		mw.set_state("mio_calentando", GameState.clock_seconds + 3600.0, "JIROSHI")
		AudioManager.play_sfx("ui_click_v2", "UI")
	await _wait(s, 3.3)


## Expendedora del -1: cae la lata, la tapa de la bandeja se abre con el golpe y vuelve.
func _prep_expendedora(s: Node) -> void:
	_fl = await _floor(s, -1)
	_hide_player(s, true)
	_n = _find(_fl, "Expendedora")
	# la máquina da a la barra por su cara −X local (la pared queda en +X): el jugador en el pasillo entre las dos y la
	# cámara en ese pasillo, casi de frente y baja, mirando a la bandeja
	_player_at(s, _n.global_transform * Vector3(-1.2, -1.0, 0.0))
	_cam_spec(s, _n, "-1.3|-0.1|0.25|-0.5|-0.5|0.0|70")
	await _wait(s, 0.6)


func _do_expendedora(s: Node) -> void:
	await _wait(s, 0.3)
	AudioManager.play_sfx("expendedora")
	ObjectAnim.vend(_n, s._player(), "energetica")
	await _wait(s, 2.7)


## Monitores de tu PC (C-14): se apagan y despiertan con el parpadeo de la retroiluminación.
func _prep_monitor(s: Node) -> void:
	_fl = await _floor(s, 2)
	await s._sit_c14()
	_hide_player(s, false)
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null and ws.has_method("set_zoom"):
		ws.call("set_zoom", false)
	if _camera != null and is_instance_valid(_camera):
		_camera.current = false
	var pc := (s._player() as Player).get_node_or_null("Head/Camera3D") as Camera3D
	if pc == null:
		for c in (s._player() as Node).find_children("*", "Camera3D", true, false):
			pc = c
			break
	if pc != null:
		pc.current = true
	await _wait(s, 0.8)
	for sc in s.get_tree().get_nodes_in_group("monitor_screens"):
		if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14":
			(sc as MonitorScreen).set_powered(false)
	await _wait(s, 0.8)


func _do_monitor(s: Node) -> void:
	await _wait(s, 0.4)
	for sc in s.get_tree().get_nodes_in_group("monitor_screens"):
		if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14":
			(sc as MonitorScreen).set_powered(true)
	await _wait(s, 1.2)
	for sc in s.get_tree().get_nodes_in_group("monitor_screens"):
		if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14":
			(sc as MonitorScreen).set_powered(false)
	await _wait(s, 0.7)
	for sc in s.get_tree().get_nodes_in_group("monitor_screens"):
		if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14":
			(sc as MonitorScreen).set_powered(true)
	await _wait(s, 0.8)


## La taza de C-13, el sitio siempre vacío: todavía humea.
func _prep_taza(s: Node) -> void:
	_fl = await _floor(s, 2)
	var p: Player = s._player()
	if p != null and p.seated:
		p.stand_up()
	_hide_player(s, true)
	_player_at(s, Vector3(39.8, 0, -9.4), 180.0)
	var cub := _find(_fl, "Cub_C-13")
	_n = cub
	GameState.clock_seconds = 5.0 * 60.0
	_cam_rel(s, cub, Vector3(0.75, 1.12, 0.55), Vector3(0.28, 0.84, -0.3), 40.0)
	await _wait(s, 2.5)


func _do_taza(s: Node) -> void:
	await _wait(s, 2.6)


## Papeles con el aire acondicionado (pósits y la hoja que cuelga de la impresora atascada).
func _prep_papeles(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	var hoja := _find(_fl, "HojaColgando")
	_n = hoja
	_player_at(s, hoja.global_position + Vector3(0, -0.78, -2.0))
	_cam(s, hoja.global_position + Vector3(0.9, 0.35, -1.3), hoja.global_position + Vector3(0, 0.0, 0), 45.0)
	await _wait(s, 0.8)


func _do_papeles(s: Node) -> void:
	await _wait(s, 5.0)


## El escritorio de QA: Haime se viene encima de la mesa y el auricular del teléfono salta.
func _prep_telefono(s: Node) -> void:
	_fl = await _floor(s, 2)
	_hide_player(s, true)
	var tel := _find(_fl, "TelefonoAuricular")
	_n = tel
	_player_at(s, tel.global_position + Vector3(2.5, -0.85, 0.0))
	_cam(s, tel.global_position + Vector3(0.75, 0.4, -0.75), tel.global_position + Vector3(0, 0.0, 0.15), 45.0)
	await _wait(s, 0.8)


func _do_telefono(s: Node) -> void:
	await _wait(s, 0.8)
	ObjectAnim.jolt(_n.global_position, 1.2, 0.7)
	await _wait(s, 1.6)
	ObjectAnim.jolt(_n.global_position, 1.2, 1.3)
	await _wait(s, 1.6)


## Puerta de vidrio de la azotea (dos hojas).
func _prep_deck(s: Node) -> void:
	_fl = await _floor(s, 9)
	_hide_player(s, true)
	_n = _find(_fl, "PuertaAzotea")
	_player_at(s, _n.global_transform * Vector3(0.0, -1.1, -1.4))
	_cam_rel(s, _n, Vector3(2.4, 0.5, -3.4), Vector3(0.0, -0.1, 0.3), 52.0)
	await _wait(s, 0.8)


func _do_deck(s: Node) -> void:
	var d := _n as WorldObjects.Door
	await _wait(s, 0.5)
	d.set_open(true)
	AudioManager.play_sfx("puerta_vidrio")
	await _wait(s, 2.0)
	d.set_open(false)
	await _wait(s, 1.2)

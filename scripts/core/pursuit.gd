class_name Pursuit
extends Node
## Pursuit (v0.3 P3, PLAN §4 y §2 #14): persecución en TODO el edificio, común para Shero, el Trainer y el RTA.
## Vive como hijo del autoload Discipline (siempre existe); la API es estática:
##   Pursuit.start(cazador, causa, velocidad = -1, escena = null, detalle = "", piso_origen = -99, desde = Vector3.INF,
##                 al_alcanzar = Callable(), extra = {}) -> bool   (los 7 primeros, igual que P5Pursuit.start de P5)
##   Pursuit.stop(cazador, motivo = "stop") · Pursuit.is_hunting(cazador = "") · Pursuit.info(cazador) ·
##   Pursuit.node_of(cazador) · Pursuit.stats (lista de persecuciones terminadas: piso, s hasta aparecer, s hasta
##   alcanzar, metros, desatascos) · Pursuit.grid_for(piso) (rejilla de rutas del piso, la usa también Shero).
## Cómo funciona: sabe en qué espacio estás (piso -1/1/2/9 o caja de escalera). Si el cazador no está en tu
## espacio, calcula la llegada (escalada.json/persecucion: ascensor 20 s + 6 s por parada; si lo dejas atrás
## cambiando de piso te sigue: ascensor 12 s + 6 s por parada, escalera 5 s para entrar a la caja y 4 s para
## salir de ella) y lo hace aparecer en el marcador "ascensor" o "escalera" de tu piso (sale del ascensor o
## de la cortafuego). Se mueve por una rejilla de rutas que se construye con la colisión real del piso (A*
## sobre celdas de 0,4 m; abre las puertas que no son de baño al pasar; las hojas del ascensor no lo frenan).
## Si estás en un baño, NO entra: espera en la puerta lo que haga falta. Al alcanzarte llama al_alcanzar(info)
## (si devuelve true no hay muerte: perdón del lunch dormido / Fácil sentado) o pide la muerte con el
## cazador como asesino: Checkpoints.request_death(causa, detalle, extra.asesino o el cazador).
## `escena`: ruta (String) o PackedScene; null/"" = la del cazador (Shero, RTA) o, si no tiene, su modelo de
## modelo v2 (assets/models) con CharacterRig (Trainer). `piso_origen`/`desde`: de dónde sale (si estás en ese piso y se pasa
## `desde`, aparece ahí al instante). Solo adopta el nodo del piso si su script tiene `pursuit_driven` (Shero); si
## no (RTA y Trainer de P5, con su propia lógica), lo oculta y persigue con un visitante en su lugar.
## Señales (EventBus): pursuit_started(cazador, causa) · hunter_entered_floor(cazador, piso) ·
## pursuit_ended(cazador, motivo: alcanzado | perdonado | reinicio | calma | stop).
## Mientras persigue, el nodo del cazador lo mueve Pursuit: si el script del cazador define
## on_pursuit_move(moving: bool, speed: float), on_pursuit_catch() o pursuit_driven (bool), se llaman/ponen.
## Presentación: latido y zumbido de persecución (más rápidos cuanto más cerca), pasos 3D del cazador.

const DEFAULT_SCENES: Dictionary = {"shero": "res://scenes/personajes/Shero.tscn", "rta": "res://scenes/personajes/PerritoRTA.tscn"}
const HOME_FLOOR: Dictionary = {"shero": 2, "rta": 2, "trainer": 1, "vitzo": 2, "fermin": -1, "grasa": 9}
## Modelo (assets/models, v2) y alto del visitante cuando el cazador no tiene escena propia.
const RIG_OF: Dictionary = {"trainer": ["trainer", 1.78], "rta": ["perrito_rta", 0.72], "shero": ["shero", 2.2], "rasec": ["rasec", 1.8], "haime": ["haime", 1.75], "vitzo": ["vitzo", 1.8], "fermin": ["guardia_fermin", 1.76], "grasa": ["grasa", 2.6]}  # v0.3.2: Vitzo tamaño persona al salir del monitor
## v0.3.1 Q2 (B1): distancia mínima a la que aparece un cazador que llega de otro piso (sale por la puerta de la
## escalera o del ascensor del piso que esté más lejos de ti si el otro queda a menos de esto).
const MIN_SPAWN_M := 8.0
## Pasos intensos de Q3 (opcionales: sin ellos, los de siempre).
const Q3_PASOS_INTENSOS := "sfx/shero_pasos_intensos"
const GROUP_OF: Dictionary = {"shero": "shero", "rta": "rta", "trainer": "trainer", "fermin": "p5_guardia"}

static var _inst: Pursuit = null
## Persecuciones terminadas (para pruebas e informes): [{cazador, causa, piso, aparece_s, alcanza_s, metros, desatascos, motivo, pisos}]
static var stats: Array = []
## v0.3.1 Q2: última captura (para que el screamer arranque donde estaba el cazador) y eventos de tránsito visibles
## entre pisos ([cazador, evento, ms]: sale, indicador, pasos_escalera, ding, portazo, sale_corriendo).
static var last_catch: Dictionary = {}
static var transit: Array = []

var _hunts: Dictionary = {}  # cazador → Dictionary (estado)
var _clock: float = 0.0  # segundos "reales" del juego (delta escalado por Engine.time_scale)
var _leftovers: Array = []  # visitantes que alcanzaron al jugador: se borran al reaparecer
var _hidden: Array = []  # nodos del piso (Shero en su sitio) ocultos mientras viene en camino
var _grids: Dictionary = {}  # instance_id del piso → NavGrid
var _last_space: String = ""
var _verbose: bool = false
var _heart: AudioStreamPlayer = null
var _drone: AudioStreamPlayer = null


func _enter_tree() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	_verbose = args.has("--escenario") or args.has("--bot") or args.has("--log-pursuit") or args.has("--shot")
	EventBus.respawned.connect(func(_k: String) -> void: stop_all("reinicio"); last_catch = {})
	EventBus.returned_to_menu.connect(func() -> void: stop_all("reinicio"); last_catch = {})
	EventBus.shift_started.connect(func() -> void: stop_all("reinicio"); _grids.clear(); last_catch = {})
	EventBus.shift_ended.connect(func() -> void: stop_all("fin_turno"))
	_heart = AudioStreamPlayer.new()
	_heart.name = "Latido"
	_heart.bus = "Sala"
	add_child(_heart)
	_drone = AudioStreamPlayer.new()
	_drone.name = "ZumbidoPersecucion"
	_drone.bus = "Sala"
	add_child(_drone)


# --- API estática ----------------------------------------------------------------------------------

static func start(hunter: String, cause: String, speed: float = -1.0, scene: Variant = null, detail: String = "", from_floor: int = -99, from_pos: Vector3 = Vector3.INF, on_catch: Callable = Callable(), extra: Dictionary = {}) -> bool:
	if _inst == null:
		return false
	return _inst._start(hunter, cause, speed, scene, detail, from_floor, from_pos, on_catch, extra)


static func stop(hunter: String, reason: String = "stop") -> void:
	if _inst != null:
		_inst._end(hunter, reason)


static func is_hunting(hunter: String = "") -> bool:
	if _inst == null:
		return false
	return not _inst._hunts.is_empty() if hunter == "" else _inst._hunts.has(hunter)


## Estado de una persecución: {cause, state (llegando|cazando|bano), space, arrive_left, dist, speed, log}.
static func info(hunter: String) -> Dictionary:
	if _inst == null or not _inst._hunts.has(hunter):
		return {}
	var h: Dictionary = _inst._hunts[hunter]
	var out := {"cause": h["cause"], "state": h["state"], "space": h["space"], "arrive_left": h["arrive_left"], "speed": h["speed"], "log": h["log"], "meters": h["meters"], "unstuck": h["unstuck"]}
	var n := _inst._node(h)
	var p := _inst._player()
	if n != null and p != null:
		out["dist"] = n.global_position.distance_to(p.global_position)
		out["pos"] = n.global_position
	return out


static func node_of(hunter: String) -> Node3D:
	if _inst == null or not _inst._hunts.has(hunter):
		return null
	return _inst._node(_inst._hunts[hunter])


## Rejilla de rutas del piso (se construye la primera vez; luego queda en caché mientras el piso exista).
static func grid_for(floor_node: Node3D) -> NavGrid:
	if _inst == null or floor_node == null or not is_instance_valid(floor_node):
		return null
	return _inst._grid(floor_node)


static func instance() -> Pursuit:
	return _inst


func stop_all(reason: String) -> void:
	for k in _hunts.keys().duplicate():
		_end(k, reason)
	if reason in ["reinicio", "calma", "fin_turno"]:
		for r in _leftovers:
			var o: Variant = (r as WeakRef).get_ref()
			if o is Node and is_instance_valid(o):
				(o as Node).queue_free()
		_leftovers.clear()
	_restore_hidden()


func _restore_hidden() -> void:
	if not _hunts.is_empty():
		return
	for r in _hidden:
		var o: Variant = (r as WeakRef).get_ref()
		if o is Node3D and is_instance_valid(o):
			(o as Node3D).visible = true
			(o as Node3D).process_mode = Node.PROCESS_MODE_INHERIT
	_hidden.clear()


# --- Persecución ----------------------------------------------------------------------------------

func _cfg() -> Dictionary:
	var v: Variant = DataLoader.dict("escalada").get("persecucion", {})
	return v if v is Dictionary else {}


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building if is_inside_tree() else null


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


## Espacio del jugador: "2", "-1"… o "sw:<de>><a>" en una caja de escalera.
func _space() -> String:
	var b := _building()
	if b == null or b.floor_node == null:
		return ""
	if b.floor_node is Stairwell:
		var sw := b.floor_node as Stairwell
		return "sw:%d>%d" % [sw.from_floor, sw.to_floor]
	return str(b.current_floor)


static func _floor_of_space(s: String) -> int:
	if s.begins_with("sw:"):
		return int(s.substr(3).get_slice(">", 0))
	return int(s) if s.is_valid_int() else 2


## Paradas entre dos pisos contando solo los habilitados (-1, 1, 2, 9): 2→1 = 1, 2→-1 = 2, 2→9 = 1.
func _stops(a: int, b: int) -> int:
	var lst: Array = _cfg().get("paradas", [-1, 1, 2, 9])
	var ia := -1
	var ib := -1
	for i in lst.size():
		if int(lst[i]) == a:
			ia = i
		if int(lst[i]) == b:
			ib = i
	if ia < 0 or ib < 0:
		return absi(a - b)
	return absi(ia - ib)


func _start(hunter: String, cause: String, speed: float, scene: Variant, detail: String, from_floor: int, from_pos: Vector3, on_catch: Callable, extra: Dictionary) -> bool:
	if _hunts.has(hunter):
		return false
	for k in _hunts.keys():
		if bool(((_hunts[k] as Dictionary).get("extra", {}) as Dictionary).get("exclusiva", false)):
			return false  # C4/C7: durante la muerte segura de Vitzo no entra ningún otro cazador
	if hunter != "vitzo" and is_inside_tree() and not get_tree().get_nodes_in_group("vitzo_attack").is_empty():
		return false  # Vitzo está saliendo del monitor: muerte segura, nadie más
	if bool(extra.get("exclusiva", false)):
		for k in _hunts.keys().duplicate():
			_end(k, "exclusiva")
	var c := _cfg()
	var spd := speed if speed > 0.0 else float(c.get("velocidad_shero_ms", 4.6))
	var h := {
		"hunter": hunter, "cause": cause, "detail": detail, "speed": spd, "base_speed": spd, "scene": scene,
		"on_catch": on_catch, "extra": extra, "node_ref": null, "visitor": false, "space": "", "arrive_left": 0.0,
		"arrive_kind": "ascensor", "t0": _now(), "floor_t0": _now(), "same_floor_s": 0.0, "path": PackedVector3Array(),
		"path_i": 0, "repath_left": 0.0, "target_cell": Vector2i(-99999, -99999), "stuck_t": 0.0, "stuck_ref": Vector3.ZERO,
		"state": "llegando", "bano_t": 0.0, "bano_said": false, "seen_said": false, "log": [], "meters": 0.0,
		"unstuck": 0, "floors": [], "door_t": 0.0, "step_t": 0.0, "trail_t": 0.0, "trail": [],
		"hold": 0.0, "transit_total": 0.0, "transit_done": {}, "ind_t": 0.0, "lights_t": 0.0, "spawn_dist": -1.0,
	}
	_hunts[hunter] = h
	var space := _space()
	_last_space = space
	var home := from_floor if from_floor != -99 else int(HOME_FLOOR.get(hunter, 2))
	h["home"] = home
	var gn := _find_group_node(hunter) if space == str(home) else null
	_log(h, "inicio · causa %s · jugador en %s · cazador sale del piso %d" % [cause, space, home])
	EventBus.pursuit_started.emit(hunter, cause)
	if gn != null and from_pos == Vector3.INF and _adoptable(gn):
		_arrive(h, gn, false)
	elif space == str(home) and (from_pos != Vector3.INF or gn != null):
		# Sale de donde está (P5 pasa su posición): visitante ahí mismo; el nodo del piso se oculta.
		h["spawn_at"] = from_pos if from_pos != Vector3.INF else gn.global_position
		if gn != null:
			_hide_node(gn)
		_arrive(h, null, false)
	else:
		var fl := _floor_of_space(space)
		var base := float(c.get("rta_escalera_s", 12.0)) if hunter == "rta" else float(c.get("llegada_ascensor_s", 20.0))
		var per := float(c.get("rta_por_piso_s", 4.0)) if hunter == "rta" else float(c.get("por_piso_s", 6.0))
		h["arrive_left"] = (base + per * _stops(home, fl) + (float(c.get("salir_escalera_s", 4.0)) if space.begins_with("sw:") else 0.0)) * _delay_scale()
		h["arrive_kind"] = "escalera" if hunter == "rta" or space.begins_with("sw:") else "ascensor"
		h["transit_total"] = float(h["arrive_left"])
		h["transit_done"] = {}
		_log(h, "llega a %s en %.1f s (%s)" % [space, float(h["arrive_left"]), h["arrive_kind"]])
		_transit_event(h, "sale")
	return true


## Solo se adopta (se mueve) el nodo del piso que sabe que lo mueve Pursuit (Shero: `pursuit_driven`).
func _adoptable(n: Node) -> bool:
	return n != null and "pursuit_driven" in n


func _hide_node(n: Node3D) -> void:
	if n.visible:
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
		_hidden.append(weakref(n))


## Fácil llega más tarde (×1,5 como los plazos); Difícil, antes.
func _delay_scale() -> float:
	return Difficulty.scale("plazos")


func _end(hunter: String, reason: String) -> void:
	if not _hunts.has(hunter):
		return
	var h: Dictionary = _hunts[hunter]
	_hunts.erase(hunter)
	var n := _node(h)
	var fl := _floor_of_space(str(h["space"])) if str(h["space"]) != "" else _floor_of_space(_space())
	var appear := float(h.get("appear_s", -1.0))
	var row := {"cazador": hunter, "causa": h["cause"], "piso": str(h["space"]) if str(h["space"]) != "" else _space(), "aparece_s": appear,
		"alcanza_s": (_now() - float(h["floor_t0"])) if reason in ["alcanzado", "perdonado"] else -1.0,
		"total_s": _now() - float(h["t0"]), "metros": float(h["meters"]), "desatascos": int(h["unstuck"]), "motivo": reason,
		"pisos": h["floors"], "trail": h["trail"]}
	stats.append(row)
	if stats.size() > 64:
		stats.pop_front()
	_log(h, "fin (%s) · %.1f s · %.1f m · %d desatascos · piso %d" % [reason, float(row["total_s"]), float(h["meters"]), int(h["unstuck"]), fl])
	if n != null:
		if n.has_method("on_pursuit_end"):
			n.call("on_pursuit_end", reason)
		if "pursuit_driven" in n:
			n.set("pursuit_driven", false)
		n.process_mode = Node.PROCESS_MODE_INHERIT
		if bool(h["visitor"]) and reason != "alcanzado":
			_fade_out(n)
		elif bool(h["visitor"]):
			_leftovers.append(weakref(n))
		elif reason != "alcanzado":
			n.visible = true
	_restore_hidden()
	if _hunts.is_empty():
		_heart.stop()
		_drone.stop()
		_restore_lights()
	EventBus.pursuit_ended.emit(hunter, reason)


func _fade_out(n: Node3D) -> void:
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(n):
		n.queue_free()


func _node(h: Dictionary) -> Node3D:
	var r: Variant = h.get("node_ref", null)
	if r is WeakRef:
		var o: Variant = (r as WeakRef).get_ref()
		if o is Node3D and is_instance_valid(o) and (o as Node3D).is_inside_tree():
			return o as Node3D
	return null


func _find_group_node(hunter: String) -> Node3D:
	var b := _building()
	if b == null or b.floor_node == null:
		return null
	for n in get_tree().get_nodes_in_group(str(GROUP_OF.get(hunter, hunter))):
		if n is Node3D and b.floor_node.is_ancestor_of(n) and not (n as Node).is_queued_for_deletion():
			return n as Node3D
	return null


## El cazador aparece en el espacio del jugador (adopta el nodo del piso o instancia su escena).
func _arrive(h: Dictionary, existing: Node3D, at_marker: bool) -> void:
	var b := _building()
	var p := _player()
	if b == null or b.floor_node == null or p == null:
		return
	var hunter := str(h["hunter"])
	var n := existing
	if n == null:
		n = _make_visitor(h)
		if n == null:
			_log(h, "sin escena ni modelo para %s: muerte directa" % hunter)
			_catch(h)
			return
		if n.has_method("set_visitor"):
			n.call("set_visitor", true)
		if n.get_parent() == null:
			b.floor_node.add_child(n)
		if n.has_method("setup_visitor"):
			n.call("setup_visitor", b.floor_node, p)
		elif n.has_method("setup") and b.floor_node is FloorBase:
			n.call("setup", b.floor_node, p)
		h["visitor"] = true
	var placed := h.has("spawn_at") and not at_marker
	if placed:
		n.global_position = h["spawn_at"]
		_face(n, p.global_position)
		h.erase("spawn_at")
	elif at_marker or existing == null:
		var m := _entry_point(h, b.floor_node, p)
		n.global_position = m
		_face(n, p.global_position)
		_arrival_fx(h, n)
		h["spawn_dist"] = m.distance_to(p.global_position)
	n.visible = true
	n.process_mode = Node.PROCESS_MODE_INHERIT
	if "pursuit_driven" in n:
		n.set("pursuit_driven", true)
	if n.has_method("on_pursuit_start"):
		n.call("on_pursuit_start", str(h["cause"]))
	# Sale de su escritorio: se levanta antes de correr (Shero/Rasec/RTA sentados, F19).
	h["hold"] = float(n.call("pursuit_hold")) if n.has_method("pursuit_hold") else 0.0
	# v0.3.1 (integración, auditoría #20): si la caza empieza con el cazador ya a tu lado (el Perrito que te vino a
	# taguear, el que estaba en tu piso), antes te alcanzaba en el acto. A menos de MIN_SPAWN_M se queda mirándote
	# `aviso_cerca_s` (y el Perrito ladra) antes de correr: te da tiempo de huir o de corregir el AUX.
	# v0.3.2 kills2 (Joan: «¿por qué se queda parado como 3 segundos? debe saltarte ni bien está en el rango»): quien
	# ya te dio el tiempo de huir de otra forma (Vitzo: los ~2,9 s que tarda en salir del monitor) pasa `sin_aviso`
	# en extra y corre desde el primer cuadro; si ya estás a su alcance, te salta en ese mismo cuadro.
	var d0 := n.global_position.distance_to(p.global_position)
	if not at_marker and (existing != null or placed) and d0 < MIN_SPAWN_M and not bool((h["extra"] as Dictionary).get("sin_aviso", false)):
		var warn := float(_cfg().get("aviso_cerca_s", 3.0))
		h["hold"] = maxf(float(h["hold"]), warn)
		h["close_warn"] = warn
		if hunter == "rta":
			_3d_sfx(n, "rta_ladrido", 0.0)
		_transit_event(h, "aviso_cerca")
		_log(h, "empieza a %.1f m de ti: te mira %.1f s antes de correr" % [d0, warn])
	if n.has_meta("rig") and at_marker:
		(n.get_meta("rig") as CharacterRig).play("sprint", true, 1.3, ["run", "walk"])
	if at_marker or existing == null:
		_transit_event(h, "sale_corriendo")
	h["node_ref"] = weakref(n)
	h["space"] = _space()
	h["state"] = "cazando"
	h["floor_t0"] = _now()
	h["same_floor_s"] = 0.0
	h["path"] = PackedVector3Array()
	h["repath_left"] = 0.0
	h["stuck_t"] = 0.0
	h["stuck_ref"] = n.global_position
	h["appear_s"] = _now() - float(h["t0"])
	(h["floors"] as Array).append(str(h["space"]))
	var fl := _floor_of_space(str(h["space"]))
	_log(h, "aparece en %s (%s) a los %.1f s, en (%.1f, %.1f, %.1f), a %.1f m del jugador, corriendo" % [h["space"], "donde estaba" if placed else (h["arrive_kind"] if at_marker or existing == null else "su sitio"), float(h["appear_s"]), n.global_position.x, n.global_position.y, n.global_position.z, n.global_position.distance_to(p.global_position)])
	EventBus.hunter_entered_floor.emit(hunter, fl)
	_grid(b.floor_node)  # la rejilla del piso (caché)


## Escena del cazador (ruta o PackedScene, la suya por defecto) o, si no tiene, un nodo con su modelo.
func _make_visitor(h: Dictionary) -> Node3D:
	var hunter := str(h["hunter"])
	var sc: Variant = h["scene"]
	var packed: PackedScene = null
	if sc is PackedScene:
		packed = sc as PackedScene
	else:
		var path := str(sc) if sc is String and str(sc) != "" else str(DEFAULT_SCENES.get(hunter, ""))
		if path != "" and ResourceLoader.exists(path):
			packed = load(path) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		if inst is Node3D:
			return inst as Node3D
		inst.free()
	var rig_def: Array = RIG_OF.get(hunter, [hunter, 1.8])
	var n := Node3D.new()
	n.name = "Cazador_" + hunter
	var b := _building()
	if b != null and b.floor_node != null:
		b.floor_node.add_child(n)  # dentro del árbol: CharacterRig mide la altura con global_transform
	var rig := CharacterRig.attach(n, str(rig_def[0]), float(rig_def[1]))
	if rig == null:
		n.free()
		return null
	n.set_meta("rig", rig)
	return n


func _marker(floor_node: Node3D, kind: String) -> Vector3:
	for k in [kind, "escalera" if kind == "ascensor" else "ascensor"]:
		var m := floor_node.find_child(k, true, false)
		if m is Node3D:
			return (m as Node3D).global_position
	return floor_node.global_position


## Por dónde entra al piso: la puerta de la escalera o la cabina del ascensor (B1: nunca aparece quieto en un marcador
## a tu lado). Si la entrada que le toca queda a menos de MIN_SPAWN_M de ti y la otra está más lejos, usa la otra.
func _entry_point(h: Dictionary, floor_node: Node3D, p: Player) -> Vector3:
	var kind := str(h["arrive_kind"])
	var pp := p.global_position
	var cands: Array = []
	# v0.3.1 (integración): en la caja de escalera «escalera» y «ascensor» son la misma puerta (la tuya); la otra
	# puerta es «escalera_otra». Quieto en tu puerta, entra por la otra (antes aparecía a 0 m).
	for k in [kind, "escalera" if kind == "ascensor" else "ascensor", "escalera_otra"]:
		var m := floor_node.find_child(k, true, false) as Node3D
		if m == null:
			continue
		var pos := m.global_position
		if k == "ascensor":
			var el := _elevator(floor_node)
			if el != null and el.global_position.distance_to(pos) < 6.0:
				pos = el.global_position + el.global_transform.basis.z * 0.1  # dentro de la cabina: sale por las puertas
		cands.append([k, pos])
	if cands.is_empty():
		return floor_node.global_position
	var pick: Array = cands[0]
	if (pick[1] as Vector3).distance_to(pp) < MIN_SPAWN_M:
		for c in cands:
			if (c[1] as Vector3).distance_to(pp) > (pick[1] as Vector3).distance_to(pp):
				pick = c
	if str(pick[0]) != kind:
		_log(h, "la %s está a %.1f m de ti: entra por la %s" % [kind, (cands[0][1] as Vector3).distance_to(pp), pick[0]])
		h["arrive_kind"] = "escalera" if str(pick[0]) == "escalera_otra" else pick[0]
	return pick[1]


func _elevator(floor_node: Node3D) -> Node3D:
	for e in get_tree().get_nodes_in_group("elevator"):
		if e is Node3D and floor_node.is_ancestor_of(e):
			return e as Node3D
	return null


func _transit_event(h: Dictionary, ev: String) -> void:
	transit.append([str(h["hunter"]), ev, Time.get_ticks_msec(), _now() - float(h["t0"])])
	if transit.size() > 200:
		transit.pop_front()
	_log(h, "tránsito: " + ev)


## Tránsito visible y audible mientras viene de otro piso (B1): Ezlaki avisa que salió de su sitio, el indicador del
## ascensor de tu piso baja/sube piso por piso, pasos que corren y puertas en la caja de escalera, el ding y las
## puertas que se abren, el portazo de la cortafuego; y sale CORRIENDO.
func _transit_fx(h: Dictionary, delta: float) -> void:
	var b := _building()
	if b == null or b.floor_node == null or b.floor_node is Stairwell:
		return
	var done: Dictionary = h["transit_done"]
	var left := float(h["arrive_left"])
	var total := maxf(float(h["transit_total"]), 0.1)
	var hunter := str(h["hunter"])
	if not done.has("aviso") and total - left > 1.5:
		done["aviso"] = true
		if hunter in ["shero", "trainer", "rta"]:
			var key := "Q2_TRANSIT_" + hunter.to_upper()
			EventBus.ezlak_post.emit("#team-familia", "companero", tr(key), {"tipo": "transito", "cazador": hunter})
	var kind := str(h["arrive_kind"])
	var fl := b.current_floor
	if kind == "ascensor":
		var el := _elevator(b.floor_node)
		h["ind_t"] = float(h["ind_t"]) - delta
		if el != null and float(h["ind_t"]) <= 0.0:
			h["ind_t"] = 0.5
			var home := int(h.get("home", 2))
			var u := clampf(1.0 - left / total, 0.0, 1.0)
			var f := int(round(lerpf(float(home), float(fl), u)))
			if f != int(h.get("ind_floor", -99)):
				h["ind_floor"] = f
				if el.has_method("show_floor"):
					el.call("show_floor", f)
				if not done.has("indicador"):
					done["indicador"] = true
					_transit_event(h, "indicador")
		if not done.has("ding") and left <= 1.4 and el != null:
			done["ding"] = true
			# v0.3.1 (audio_horror_v2): en T2/T3 el ding del ascensor que trae al cazador suena lento y grave.
			_3d_sfx(el, "ascensor_ding_lento" if GameState.turno >= 2 and AudioManager.has_slot("sfx/ascensor_ding_lento") else "ascensor_llegada", 0.0)
			if el.has_method("set_doors"):
				el.call("set_doors", false, true)
				el.call("set_doors", true)
			_transit_event(h, "ding")
	else:
		var m := b.floor_node.find_child("escalera", true, false) as Node3D
		if m != null:
			if not done.has("pasos") and left <= 6.0:
				done["pasos"] = true
				_3d_sfx(m, "shero_pasos_intensos" if AudioManager.has_slot(Q3_PASOS_INTENSOS) else "shero_corre_acerca", -6.0)
				_3d_sfx(m, "pasos_escalera_v2", -4.0, 1.25)
				_transit_event(h, "pasos_escalera")
			if not done.has("portazo") and left <= 0.25:
				done["portazo"] = true
				_3d_sfx(m, "puerta_cortafuego", 3.0)
				_transit_event(h, "portazo")


func _3d_sfx(at: Node3D, slot: String, db: float, pitch: float = 1.0) -> void:
	var path := AudioManager.resolve("sfx/" + slot)
	if path == "" or at == null:
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(path) as AudioStream
	s.bus = "Sala"
	s.unit_size = 10.0
	s.volume_db = db
	s.pitch_scale = pitch
	at.add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Sale del ascensor (ding) o de la cortafuego (golpe de puerta), con la presencia de Shero.
func _arrival_fx(h: Dictionary, n: Node3D) -> void:
	var sfx := "ascensor_llegada" if str(h["arrive_kind"]) == "ascensor" else "puerta_cortafuego"
	var path := AudioManager.resolve("sfx/" + sfx)
	if path != "":
		var s := AudioStreamPlayer3D.new()
		s.stream = load(path) as AudioStream
		s.bus = "Sala"
		s.unit_size = 8.0
		n.add_child(s)
		s.play()
		s.finished.connect(s.queue_free)
	if str(h["hunter"]) == "shero":
		var disc := get_parent()
		if disc != null and disc.get("presence") != null:
			disc.get("presence").call("hunter_arrived", n)


func _face(n: Node3D, target: Vector3) -> void:
	var d := target - n.global_position
	d.y = 0.0
	if d.length() > 0.05:
		n.rotation.y = atan2(-d.x, -d.z)


func _now() -> float:
	return _clock


func _log(h: Dictionary, msg: String) -> void:
	var line := "[pursuit %s %6.1fs] %s" % [h["hunter"], _now() - float(h["t0"]), msg]
	(h["log"] as Array).append(line)
	if _verbose:
		print(line)


# --- Bucle --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _hunts.is_empty() or get_tree().paused:
		return
	_clock += delta
	var space := _space()
	if space != _last_space and space != "":
		_on_space_changed(_last_space, space)
		_last_space = space
	var paused := Discipline.is_frozen() or Checkpoints.dying or not GameState.running
	for k in _hunts.keys():
		var h: Dictionary = _hunts[k]
		if paused and not (_exclusive(h) and not Checkpoints.dying and GameState.running):
			continue
		if str(h["space"]) == "":
			# En camino: mientras tanto, el nodo del piso (Shero en su sitio) no está.
			var gn := _find_group_node(k)
			if gn != null:
				_hide_node(gn)
			h["arrive_left"] = float(h["arrive_left"]) - delta
			if float(h["transit_total"]) > 0.0:
				_transit_fx(h, delta)
			if float(h["arrive_left"]) <= 0.0:
				_arrive(h, gn if _adoptable(gn) else null, true)
	_chase_audio(delta)


func _on_space_changed(old: String, new: String) -> void:
	var c := _cfg()
	var kind := "escalera" if old.begins_with("sw:") or new.begins_with("sw:") else "ascensor"
	for k in _hunts.keys():
		var h: Dictionary = _hunts[k]
		var was_here := str(h["space"]) == old and old != ""
		var delay := 0.0
		if kind == "escalera":
			delay = float(c.get("seguir_escalera_s", 5.0)) if new.begins_with("sw:") else float(c.get("salir_escalera_s", 4.0))
		else:
			delay = float(c.get("seguir_ascensor_s", 12.0)) + float(c.get("por_piso_s", 6.0)) * _stops(_floor_of_space(old), _floor_of_space(new))
		if was_here:
			h["arrive_left"] = delay
		else:
			# Seguía en camino: suma la diferencia de paradas (nunca menos que la demora de seguirte).
			var extra := float(c.get("por_piso_s", 6.0)) * _stops(_floor_of_space(old), _floor_of_space(new))
			h["arrive_left"] = maxf(float(h["arrive_left"]) + extra, delay * 0.5)
		h["arrive_kind"] = kind
		h["space"] = ""
		h["node_ref"] = null
		h["state"] = "llegando"
		h["transit_total"] = float(h["arrive_left"])
		h["transit_done"] = {"aviso": true}
		h["home"] = _floor_of_space(old)
		_log(h, "el jugador pasa de %s a %s (%s): %s en %.1f s" % [old, new, kind, "te sigue" if was_here else "corrige el rumbo", float(h["arrive_left"])])


func _physics_process(delta: float) -> void:
	if _hunts.is_empty() or get_tree().paused:
		return
	var frozen := Discipline.is_frozen() or Checkpoints.dying or not GameState.running
	for k in _hunts.keys().duplicate():
		if not _hunts.has(k):
			continue
		var h: Dictionary = _hunts[k]
		# La muerte segura de Vitzo (exclusiva) congela la disciplina, pero su caza sigue.
		if frozen and not (_exclusive(h) and not Checkpoints.dying and GameState.running):
			var nn := _node(h)
			if nn != null and nn.has_method("on_pursuit_move"):
				nn.call("on_pursuit_move", false, 0.0)
			continue
		_step(h, delta)


func _exclusive(h: Dictionary) -> bool:
	return bool((h.get("extra", {}) as Dictionary).get("exclusiva", false))


func _step(h: Dictionary, delta: float) -> void:
	if str(h["space"]) == "" or str(h["space"]) != _space():
		return
	var n := _node(h)
	var p := _player()
	var b := _building()
	if n == null or p == null or b == null:
		if str(h["space"]) != "":
			h["space"] = ""
			h["arrive_left"] = 3.0
		return
	var c := _cfg()
	var grid := _grid(b.floor_node)
	if float(h["hold"]) > 0.0:
		# Se está levantando de su escritorio (clip stand_up): todavía no corre.
		h["hold"] = float(h["hold"]) - delta
		_face(n, p.global_position)
		if float(h["hold"]) <= 0.0:
			_log(h, "se levantó de su sitio y sale corriendo")
		return
	var ex: Dictionary = h["extra"]
	h["same_floor_s"] = float(h["same_floor_s"]) + delta
	var accel := float(c.get("aceleracion_ms", 0.15)) * floorf(float(h["same_floor_s"]) / 10.0)
	h["speed"] = minf(float(h["base_speed"]) + accel, maxf(float(c.get("velocidad_max_ms", 5.6)), float(h["base_speed"])))
	var bath := _player_bathroom(b.floor_node) if not bool(ex.get("entra_banos", false)) else null
	var target := p.global_position
	var waiting := false
	if bath != null:
		target = _door_wait_point(bath, grid)
		if h["state"] != "bano":
			h["state"] = "bano"
			h["bano_t"] = 0.0
			h["bano_said"] = false
			h["repath_left"] = 0.0
			_log(h, "el jugador entra al baño %s: espera en la puerta" % bath.zone_id)
		h["bano_t"] = float(h["bano_t"]) + delta
		if not bool(h["bano_said"]) and float(h["bano_t"]) >= float(c.get("bano_linea_s", 6.0)):
			h["bano_said"] = true
			_say_bathroom(h)
		elif float(h["bano_t"]) > float(c.get("bano_linea_s", 6.0)) + float(c.get("bano_recordatorio_s", 45.0)) and fmod(float(h["bano_t"]), float(c.get("bano_recordatorio_s", 45.0))) < delta:
			_say_bathroom(h)
	elif h["state"] == "bano":
		h["state"] = "cazando"
		h["repath_left"] = 0.0
		_log(h, "el jugador sale del baño tras %.1f s" % float(h["bano_t"]))
	# Ruta (A* sobre la rejilla del piso); se rehace cada repath_s o si el objetivo cambió de celda.
	h["repath_left"] = float(h["repath_left"]) - delta
	var tc := grid.cell_of(target) if grid != null else Vector2i.ZERO
	if float(h["repath_left"]) <= 0.0 or tc != h["target_cell"]:
		h["repath_left"] = float(c.get("repath_s", 0.4))
		h["target_cell"] = tc
		if grid != null:
			h["path"] = grid.find_path(n.global_position, target)
		else:
			h["path"] = PackedVector3Array([target])
		h["path_i"] = 0
	var path: PackedVector3Array = h["path"]
	var i := int(h["path_i"])
	var moving := false
	var spd := float(h["speed"])
	var step_len := spd * delta
	var before := n.global_position
	while i < path.size() and step_len > 0.0:
		var wp := path[i]
		var to := wp - n.global_position
		to.y = 0.0
		var d := to.length()
		if d <= step_len:
			n.global_position = Vector3(wp.x, wp.y, wp.z)
			step_len -= d
			i += 1
		else:
			var pos := n.global_position + to / d * step_len
			pos.y = grid.height_at(pos, n.global_position.y) if grid != null else n.global_position.y
			n.global_position = pos
			step_len = 0.0
		moving = true
	if bool(ex.get("entra_banos", false)) and i >= path.size() and step_len > 0.0:
		# Vitzo entra a los baños: el último tramo hasta ti, en línea recta (atraviesa la puerta).
		var to2 := p.global_position - n.global_position
		to2.y = 0.0
		if to2.length() > 0.05:
			n.global_position += to2.normalized() * minf(step_len, to2.length())
			moving = true
	h["path_i"] = i
	var moved := before.distance_to(n.global_position)
	h["meters"] = float(h["meters"]) + moved
	if moving:
		var look := path[mini(i, path.size() - 1)] if path.size() > 0 else target
		_face(n, look)
	elif bath != null:
		_face(n, bath.global_position)
		waiting = true
	else:
		_face(n, p.global_position)
	if n.has_method("on_pursuit_move"):
		n.call("on_pursuit_move", moving, spd if moving else 0.0)
	elif n.has_meta("rig"):
		var rig := n.get_meta("rig") as CharacterRig
		var clip := ("sprint" if rig != null and rig.has_anim("sprint") else "run") if moving else "idle"
		if rig != null and str(n.get_meta("clip", "")) != clip:
			n.set_meta("clip", clip)
			rig.play(clip, true, clampf(spd / 4.2, 0.9, 1.5), ["run", "walk"] if moving else ["stare_camera", "idle_sit"])
		if moving:
			_visitor_steps(h, n, spd, delta)
	if bool(ex.get("intenso", false)):
		_kill_lights(h, n, delta)
	_open_doors(h, n, delta)
	_trail(h, n, delta)
	# Alcance (nunca dentro de un baño).
	if bath == null:
		var dv := p.global_position - n.global_position
		var dy := absf(dv.y)
		dv.y = 0.0
		var dist := dv.length()
		var at_end := i >= path.size()
		if dy < 1.6 and (dist <= float(c.get("alcance_m", 1.25)) or (at_end and dist <= float(c.get("alcance_fin_ruta_m", 2.1)))):
			_catch(h)
			return
		if not bool(h["seen_said"]) and dist < 14.0 and str(h["hunter"]) == "shero":
			h["seen_said"] = true
			var disc := get_parent()
			if disc != null and disc.get("presence") != null:
				disc.get("presence").call("hunter_sees_you", n)
	# Atascos: si no avanza en atasco_s teniendo ruta, rehace la ruta; si sigue, salta al siguiente punto.
	if waiting or not moving or i >= path.size():
		h["stuck_t"] = 0.0
		h["stuck_ref"] = n.global_position
		return
	h["stuck_t"] = float(h["stuck_t"]) + delta
	if float(h["stuck_t"]) >= float(c.get("atasco_s", 1.5)):
		if n.global_position.distance_to(h["stuck_ref"]) < 0.3:
			h["unstuck"] = int(h["unstuck"]) + 1
			if i < path.size():
				# v0.3.1: nunca salta más de 0,9 m de golpe (antes saltaba al siguiente punto de la ruta: se veía teletransportarse).
				n.global_position = n.global_position.move_toward(path[i], 0.9)
			h["repath_left"] = 0.0
			_log(h, "desatasco #%d en (%.1f, %.1f)" % [int(h["unstuck"]), n.global_position.x, n.global_position.z])
		h["stuck_t"] = 0.0
		h["stuck_ref"] = n.global_position


func _trail(h: Dictionary, n: Node3D, delta: float) -> void:
	h["trail_t"] = float(h["trail_t"]) - delta
	if float(h["trail_t"]) > 0.0:
		return
	h["trail_t"] = 0.5
	var tr: Array = h["trail"]
	tr.append([_space(), snappedf(n.global_position.x, 0.1), snappedf(n.global_position.z, 0.1)])
	if tr.size() > 400:
		tr.pop_front()


func _catch(h: Dictionary) -> void:
	var hunter := str(h["hunter"])
	var info := {"hunter": hunter, "cause": h["cause"], "detail": h["detail"], "extra": h["extra"], "space": h["space"], "floor": _floor_of_space(str(h["space"]))}
	var handled := false
	var cb: Callable = h["on_catch"]
	if cb.is_valid():
		handled = bool(cb.call(info))
	_log(h, "alcanza al jugador en %s%s" % [h["space"], " · perdona" if handled else ""])
	var n := _node(h)
	if handled:
		if n != null and n.has_method("on_pursuit_spare"):
			n.call("on_pursuit_spare")
		_end(hunter, "perdonado")
		return
	if n != null and n.has_method("on_pursuit_catch"):
		n.call("on_pursuit_catch")
	var killer := str((h["extra"] as Dictionary).get("asesino", hunter))
	last_catch = {"hunter": hunter, "killer": killer, "pos": n.global_position if n != null else Vector3.INF,
		"ms": Time.get_ticks_msec(), "cause": str(h["cause"]), "intenso": bool((h["extra"] as Dictionary).get("intenso", false))}
	Checkpoints.request_death(str(h["cause"]), str(h["detail"]), killer)  # antes de terminar: nada más se cuela
	if n != null:
		n.visible = false  # el screamer lo trae frente a tu cámara desde donde estaba
	_end(hunter, "alcanzado")


func _player_bathroom(floor_node: Node) -> Bathroom:
	for b in get_tree().get_nodes_in_group("bathrooms"):
		if b is Bathroom and (b as Bathroom).player_inside and floor_node.is_ancestor_of(b):
			return b as Bathroom
	return null


## Punto de espera: la celda transitable más cercana a la puerta del baño, del lado de afuera.
func _door_wait_point(bath: Bathroom, grid: NavGrid) -> Vector3:
	var door := bath.get_node_or_null("Puerta") as Node3D
	var dp := door.global_position if door != null else bath.global_position
	var out := (dp - bath.global_position)
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.01 else Vector3(0, 0, 1)
	var want := dp + dir * 1.1
	want.y = bath.global_position.y
	if grid != null:
		var c := grid.nearest(want, 10)
		if c.x > -99999:
			return grid.pos_of(c)
	return want


func _say_bathroom(h: Dictionary) -> void:
	if str(h["hunter"]) != "shero":
		return
	var disc := get_parent()
	if disc != null and disc.get("presence") != null:
		disc.get("presence").call("bathroom_wait", _node(h))


func _open_doors(h: Dictionary, n: Node3D, delta: float) -> void:
	h["door_t"] = float(h["door_t"]) - delta
	if float(h["door_t"]) > 0.0:
		return
	h["door_t"] = 0.25
	for d in get_tree().get_nodes_in_group("interactables"):
		if d is WorldObjects.Door and not (d as WorldObjects.Door).open and (d as Node3D).global_position.distance_to(n.global_position) < 1.8:
			var in_bath := false
			var a: Node = d
			while a != null:
				if a is Bathroom:
					in_bath = true
					break
				a = a.get_parent()
			if not in_bath:
				(d as WorldObjects.Door).set_open(true)
				AudioManager.play_sfx("puerta_vidrio")
				_log(h, "abre la puerta %s" % (d as Node).name)


## Pasos 3D del cazador que no tiene los suyos (Trainer, RTA, Vitzo visitantes): fuertes y rápidos.
func _visitor_steps(h: Dictionary, n: Node3D, spd: float, delta: float) -> void:
	h["step_t"] = float(h["step_t"]) - delta
	if float(h["step_t"]) > 0.0:
		return
	h["step_t"] = clampf(1.9 / maxf(spd, 0.5), 0.22, 0.6)
	var slot := "shero_pasos_intensos" if bool((h["extra"] as Dictionary).get("intenso", false)) and AudioManager.has_slot(Q3_PASOS_INTENSOS) else ("grasa_paso" if str(h["hunter"]) == "vitzo" else "pasos_alfombra_v2")
	_3d_sfx(n, slot, 2.0 if str(h["hunter"]) != "rta" else -4.0, randf_range(0.85, 1.05))


## Persecución intensa (2.ª siesta, Vitzo): las luces mueren a su paso (bajan y vuelven al rato).
var _dimmed: Array = []  # [Light3D, energía, ms hasta volver]
func _kill_lights(h: Dictionary, n: Node3D, delta: float) -> void:
	h["lights_t"] = float(h["lights_t"]) - delta
	var now := Time.get_ticks_msec()
	for d in _dimmed.duplicate():
		if int(d[2]) <= now:
			if is_instance_valid(d[0]):
				(d[0] as Light3D).light_energy = float(d[1])
			_dimmed.erase(d)
	if float(h["lights_t"]) > 0.0:
		return
	h["lights_t"] = 0.25
	var fl := _building().floor_node if _building() != null else null
	if fl == null:
		return
	for l in fl.find_children("*", "OmniLight3D", true, false) + fl.find_children("*", "SpotLight3D", true, false):
		var li := l as Light3D
		if li.light_energy > 0.05 and li.global_position.distance_to(n.global_position) < 3.5:
			var known := false
			for d in _dimmed:
				if d[0] == li:
					known = true
			if not known:
				_dimmed.append([li, li.light_energy, now + 2200])
				li.light_energy *= 0.08


func _restore_lights() -> void:
	for d in _dimmed:
		if is_instance_valid(d[0]):
			(d[0] as Light3D).light_energy = float(d[1])
	_dimmed.clear()


# --- Rejilla de rutas -----------------------------------------------------------------------------

func _grid(floor_node: Node3D) -> NavGrid:
	var id := floor_node.get_instance_id()
	if _grids.has(id):
		var g: NavGrid = _grids[id]
		if g != null:
			return g
	for k in _grids.keys().duplicate():
		if not is_instance_id_valid(k):
			_grids.erase(k)
	var c := _cfg()
	var g2 := NavGrid.new()
	var p := _player()
	var ex: Array[RID] = []
	if p != null:
		ex.append(p.get_rid())
	var t0 := Time.get_ticks_usec()
	g2.build(floor_node, ex, float(c.get("rejilla_m", 0.4)), float(c.get("cuerpo_m", 0.44)))
	g2.build_ms = int((Time.get_ticks_usec() - t0) / 1000)
	_grids[id] = g2
	if _verbose:
		print("[pursuit] rejilla de %s: %d celdas transitables en %d ms" % [floor_node.name, g2.cells, g2.build_ms])
	return g2


# --- Audio de persecución --------------------------------------------------------------------------

func _chase_audio(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var best := INF
	var arriving := false
	for k in _hunts.keys():
		var h: Dictionary = _hunts[k]
		var n := _node(h)
		if n != null and str(h["space"]) == _space():
			best = minf(best, n.global_position.distance_to(p.global_position))
		else:
			arriving = true
	if best == INF and not arriving:
		return
	var near := 0.0 if best == INF else clampf(1.0 - (best - 2.0) / 30.0, 0.0, 1.0)
	var bpm := lerpf(72.0, 150.0, near) if best != INF else 66.0
	# Latido y zumbido grabados de Q3 (C2); sin el archivo, silencio (nada de tonos sintéticos).
	var heart_loop := _ogg("sfx/persecucion_latido_loop")
	if heart_loop != null:
		if not _heart.playing and not Checkpoints.dying:
			_heart.stream = heart_loop
			_heart.play()
		_heart.pitch_scale = clampf(bpm / 80.0, 0.8, 1.9)
		_heart.volume_db = lerpf(-18.0, -2.0, near) if best != INF else -22.0
	var dl := _ogg("sfx/persecucion_drone_loop")
	if dl != null:
		if not _drone.playing and not Checkpoints.dying:
			_drone.stream = dl
			_drone.play()
		_drone.volume_db = lerpf(-30.0, -9.0, near) if best != INF else -34.0
		_drone.pitch_scale = lerpf(0.9, 1.12, near)
	if Checkpoints.dying:
		_drone.stop()
		_heart.stop()


## C2: el ogg de Q3 si existe (latido/zumbido grabados, en bucle); si no, null (silencio).
var _ogg_cache: Dictionary = {}
func _ogg(slot: String) -> AudioStream:
	if not _ogg_cache.has(slot):
		_ogg_cache[slot] = AudioManager.stream_for(slot, true) if AudioManager.has_slot(slot, false) else null
	return _ogg_cache[slot]


## Rejilla de rutas de un piso: celdas de `step` m donde cabe un cuerpo de `body` m sin chocar con la
## colisión de la capa 1 (las puertas que no son de baño y las hojas del ascensor no cuentan: se abren) y
## con suelo a menos de 0,5 m de la celda vecina; los baños quedan fuera (Shero no entra). A* (AStarGrid2D)
## con diagonales solo si no hay obstáculo y suavizado por línea de vista sobre la rejilla.
class NavGrid extends RefCounted:
	const MAX_STEP := 0.5
	const DROP := 0.6
	var step: float = 0.4
	var origin: Vector2 = Vector2.ZERO
	var nx: int = 0
	var nz: int = 0
	var heights: Dictionary = {}  # Vector2i → y del suelo
	var astar: AStarGrid2D = AStarGrid2D.new()
	var cells: int = 0
	var build_ms: int = 0
	var _blocked_boxes: Array[AABB] = []

	func build(floor_node: Node3D, exclude: Array[RID], p_step: float, body: float) -> void:
		step = p_step
		var space := floor_node.get_world_3d().direct_space_state
		var bounds := AABB()
		var first := true
		for s in floor_node.find_children("*", "CollisionShape3D", true, false):
			var cs := s as CollisionShape3D
			if cs.shape == null or not (cs.get_parent() is StaticBody3D):
				continue
			if ((cs.get_parent() as CollisionObject3D).collision_layer & 1) == 0:
				continue
			var ext := Vector3.ONE * 0.5
			if cs.shape is BoxShape3D:
				ext = (cs.shape as BoxShape3D).size * 0.5
			var gt := cs.global_transform
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var pp := gt * Vector3(ext.x * sx, 0.0, ext.z * sz)
					if first:
						bounds = AABB(pp, Vector3.ZERO)
						first = false
					else:
						bounds = bounds.expand(pp)
		bounds = bounds.grow(1.0)
		origin = Vector2(bounds.position.x, bounds.position.z)
		nx = int(ceil(bounds.size.x / step)) + 1
		nz = int(ceil(bounds.size.z / step)) + 1
		# Baños: fuera de la rejilla (Shero no entra; espera en la puerta).
		_blocked_boxes.clear()
		for b in floor_node.find_children("*", "Node3D", true, false):
			if b is Bathroom:
				for z in (b as Node).get_children():
					if z is Zone:
						var zs := (z as Node).get_child(0) as CollisionShape3D if (z as Node).get_child_count() > 0 else null
						if zs != null and zs.shape is BoxShape3D:
							var sz := (zs.shape as BoxShape3D).size
							var center := (zs as Node3D).global_position
							_blocked_boxes.append(AABB(center - sz * 0.5 - Vector3(0.15, 0, 0.15), sz + Vector3(0.3, 0, 0.3)))
		var box := BoxShape3D.new()
		box.size = Vector3(body, 1.25, body)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.collision_mask = 1
		q.exclude = exclude
		var queue: Array[Vector2i] = []
		for m in floor_node.find_children("*", "Marker3D", true, false):
			var gp := (m as Marker3D).global_position
			if _in_blocked(gp):
				continue
			var c := Vector2i(int(round((gp.x - origin.x) / step)), int(round((gp.z - origin.y) / step)))
			if heights.has(c) or c.x < 0 or c.y < 0 or c.x >= nx or c.y >= nz:
				continue
			var y: Variant = _floor_y(space, pos_xz(c), gp.y + 1.2, exclude)
			if y == null:
				continue
			q.transform = Transform3D(Basis(), Vector3(pos_xz(c).x, float(y) + 0.35 + 0.625, pos_xz(c).z))
			if _blocks(space.intersect_shape(q, 8)):
				continue
			heights[c] = float(y)
			queue.append(c)
		var visited: Dictionary = {}
		for c in queue:
			visited[c] = true
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			var fy: float = heights[c]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = c + d
				if nc.x < 0 or nc.y < 0 or nc.x >= nx or nc.y >= nz or visited.has(nc):
					continue
				visited[nc] = true
				var pp := pos_xz(nc)
				if _in_blocked(Vector3(pp.x, fy + 1.0, pp.z)):
					continue
				var hit: Variant = _floor_y(space, pp, fy + MAX_STEP + 0.7, exclude)
				if hit == null:
					continue
				var ny := float(hit)
				if ny > fy + MAX_STEP or ny < fy - DROP:
					visited.erase(nc)  # desde otra celda quizás sí se llega
					continue
				q.transform = Transform3D(Basis(), Vector3(pp.x, ny + 0.35 + 0.625, pp.z))
				if _blocks(space.intersect_shape(q, 8)):
					continue
				heights[nc] = ny
				queue.append(nc)
		cells = heights.size()
		astar.region = Rect2i(0, 0, nx, nz)
		astar.cell_size = Vector2(step, step)
		astar.offset = origin
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.update()
		astar.fill_solid_region(astar.region, true)
		for c in heights.keys():
			astar.set_point_solid(c, false)

	func _in_blocked(p: Vector3) -> bool:
		for bb in _blocked_boxes:
			if p.x >= bb.position.x and p.x <= bb.end.x and p.z >= bb.position.z and p.z <= bb.end.z:
				return true
		return false

	func pos_xz(c: Vector2i) -> Vector3:
		return Vector3(origin.x + c.x * step, 0.0, origin.y + c.y * step)

	func pos_of(c: Vector2i) -> Vector3:
		var p := pos_xz(c)
		p.y = float(heights.get(c, 0.0))
		return p

	func cell_of(p: Vector3) -> Vector2i:
		return Vector2i(int(round((p.x - origin.x) / step)), int(round((p.z - origin.y) / step)))

	func walkable(c: Vector2i) -> bool:
		return heights.has(c)

	## Celda transitable más cercana a p (búsqueda en anillos hasta max_r celdas). (-99999, -99999) si no hay.
	func nearest(p: Vector3, max_r: int = 8) -> Vector2i:
		var c := cell_of(p)
		if heights.has(c) and absf(float(heights[c]) - p.y) < 1.6:
			return c
		var best := Vector2i(-99999, -99999)
		var best_d := INF
		for r in range(1, max_r + 1):
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if absi(dx) != r and absi(dz) != r:
						continue
					var nc := c + Vector2i(dx, dz)
					if not heights.has(nc):
						continue
					var w := pos_of(nc)
					var d := Vector2(w.x - p.x, w.z - p.z).length() + absf(w.y - p.y) * 2.0
					if d < best_d:
						best_d = d
						best = nc
			if best.x > -99999:
				return best
		return best

	func height_at(p: Vector3, fallback: float) -> float:
		var c := cell_of(p)
		return float(heights.get(c, fallback))

	## Ruta de from a to (la celda más cercana de cada uno), suavizada; termina en to si es transitable.
	func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
		var out := PackedVector3Array()
		var a := nearest(from, 6)
		var b := nearest(to, 10)
		if a.x <= -99999 or b.x <= -99999:
			out.append(to)
			return out
		var ids: Array[Vector2i] = astar.get_id_path(a, b, true)
		if ids.is_empty():
			out.append(pos_of(b))
			return out
		var keep: Array[Vector2i] = [ids[0]]
		var anchor := 0
		var i := 1
		while i < ids.size():
			if not _los(ids[anchor], ids[i]):
				keep.append(ids[i - 1])
				anchor = i - 1
			i += 1
		keep.append(ids[ids.size() - 1])
		for k in range(1, keep.size()):
			out.append(pos_of(keep[k]))
		if out.is_empty():
			out.append(pos_of(b))
		return out

	## Línea de vista sobre la rejilla: todas las celdas que toca el segmento (más un margen) son transitables
	## y sin desniveles bruscos.
	func _los(a: Vector2i, b: Vector2i) -> bool:
		var pa := Vector2(a)
		var pb := Vector2(b)
		var n := int(ceil(pa.distance_to(pb) * 2.0)) + 1
		var prev := float(heights.get(a, 0.0))
		for s in n + 1:
			var t := float(s) / maxf(1.0, float(n))
			var q := pa.lerp(pb, t)
			var center := Vector2i(roundi(q.x), roundi(q.y))
			if not heights.has(center):
				return false
			var hc := float(heights[center])
			if absf(hc - prev) > MAX_STEP:
				return false
			prev = hc
			for off in [Vector2(0.35, 0.35), Vector2(-0.35, 0.35), Vector2(0.35, -0.35), Vector2(-0.35, -0.35)]:
				var c := Vector2i(roundi(q.x + off.x), roundi(q.y + off.y))
				if not heights.has(c):
					return false
		return true

	func _floor_y(space: PhysicsDirectSpaceState3D, p: Vector3, from_y: float, exclude: Array[RID]) -> Variant:
		var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, from_y - 4.2, p.z), 1, exclude)
		var r := space.intersect_ray(rq)
		if r.is_empty():
			return null
		return (r["position"] as Vector3).y

	func _blocks(hits: Array[Dictionary]) -> bool:
		for hh in hits:
			var col: Object = hh.get("collider")
			if not (col is Node):
				continue
			var nd: Node = col
			var ignorable := false
			var in_bath := false
			while nd != null:
				if nd is Bathroom:
					in_bath = true
				if (nd is WorldObjects.Door or nd.name.begins_with("Hoja")) and not in_bath:
					ignorable = true
				nd = nd.get_parent()
			if not ignorable or in_bath:
				return true
		return false

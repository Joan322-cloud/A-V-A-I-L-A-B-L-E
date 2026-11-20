## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## check_collision: auditoría de colisión de los pisos. Carga cada piso (-1, 1, 2, 9) y las cuatro
## cajas de escalera, inunda la planta desde los spawns en una malla de 0,25 m (celda transitable =
## nada bloquea un cuerpo de 0,3 × 1,0 m sobre el suelo; las puertas sin llave y las hojas del
## ascensor no cuentan) y lanza un rayo hacia abajo en cada celda: si no hay colisionador en 3 m es un
## HUECO. Los agrupa en zonas y los imprime con coordenadas. Dos pasadas: "estructural" (sin la losa
## de seguridad invisible de FloorBase) y "real" (con todo). Mapa ASCII por piso en user://logs/.
## Uso: godot --headless --path game -- --check-collision        (sale con 1 si hay huecos reales)

const STEP := 0.25
const FLOORS: Array[int] = [-1, 1, 2, 9]
const STAIRWELLS: Array = [[-1, 1, true], [1, 2, true], [2, 1, false], [1, -1, false]]
const BODY_SIZE := Vector3(0.3, 1.0, 0.3)
const MAX_STEP := 0.5
const DROP_WARN := 0.6
const RAY_DOWN := 3.0

var _main: Node = null
var _player: Player = null
var _building: Building = null
var total_real: int = 0
var total_structural: int = 0
var unreachable: int = 0
var _reach_mode: bool = false
var report: Array[String] = []


func start(main: Node) -> void:
	_main = main
	_run()


func _run() -> void:
	_main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	await get_tree().physics_frame
	_building = get_tree().get_first_node_in_group("building") as Building
	_player = get_tree().get_first_node_in_group("player") as Player
	if _building == null or _player == null:
		printerr("check_collision: no hay edificio/jugador")
		get_tree().quit(2)
		return
	_player.safety_enabled = false
	_player.input_locked = true
	for f in FLOORS:
		_building.go_to_floor(f, "ascensor")
		await _settle()
		await _check_floor("piso %d" % f, _building.floor_node)
	for cfg in STAIRWELLS:
		_building.current_floor = cfg[0]
		_building.go_to_stairwell(cfg[1], cfg[2])
		await _settle()
		await _check_floor("escalera %d→%d" % [cfg[0], cfg[1]], _building.floor_node)
	print("check_collision: %d huecos estructurales (sin losa de seguridad), %d huecos reales, %d marcadores no alcanzables" % [total_structural, total_real, unreachable])
	for line in report:
		print("  " + line)
	get_tree().quit(1 if total_real > 0 or unreachable > 0 else 0)


func _settle() -> void:
	for _i in 3:
		await get_tree().physics_frame


## Devuelve el análisis de un piso: {cells: {Vector2i: {y, state}}, holes: [...], bounds, origin}.
## state: 0 transitable, 1 bloqueado, 2 hueco, 3 desnivel (baja > DROP_WARN pero hay suelo).
func analyze(floor_node: Node3D, ignore_base: bool, seed_names: Array[String] = []) -> Dictionary:
	var space := floor_node.get_world_3d().direct_space_state
	var shapes := floor_node.find_children("*", "CollisionShape3D", true, false)
	var bounds := AABB()
	var first := true
	var exclude: Array[RID] = [_player.get_rid()]
	for s in shapes:
		var cs := s as CollisionShape3D
		if cs.shape == null:
			continue
		var body := cs.get_parent()
		if not (body is CollisionObject3D):
			continue
		if (body as CollisionObject3D).collision_layer & 1 == 0:
			continue
		if body.is_in_group("base_collider"):
			if ignore_base:
				exclude.append((body as CollisionObject3D).get_rid())
			continue
		var ext := Vector3.ONE
		if cs.shape is BoxShape3D:
			ext = (cs.shape as BoxShape3D).size * 0.5
		elif cs.shape is CylinderShape3D:
			var cy := cs.shape as CylinderShape3D
			ext = Vector3(cy.radius, cy.height * 0.5, cy.radius)
		var gt := cs.global_transform
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					var p := gt * Vector3(ext.x * sx, ext.y * sy, ext.z * sz)
					if first:
						bounds = AABB(p, Vector3.ZERO)
						first = false
					else:
						bounds = bounds.expand(p)
	bounds = bounds.grow(1.0)
	var origin := Vector2(bounds.position.x, bounds.position.z)
	var nx := int(ceil(bounds.size.x / STEP)) + 1
	var nz := int(ceil(bounds.size.z / STEP)) + 1
	var cells: Dictionary = {}
	var queue: Array = []
	for m in floor_node.find_children("*", "Marker3D", true, false):
		if not seed_names.is_empty() and not seed_names.has(m.name):
			continue
		var gp := (m as Marker3D).global_position
		var c := Vector2i(int(round((gp.x - origin.x) / STEP)), int(round((gp.z - origin.y) / STEP)))
		var y: Variant = _floor_y(space, _cell_pos(origin, c), gp.y + 1.2, exclude)
		if y == null:
			y = gp.y
		if not cells.has(c):
			cells[c] = {"y": float(y), "state": 0}
			queue.append(c)
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = 1
	q.exclude = exclude
	var holes: Array[Vector2i] = []
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var cur: Dictionary = cells[c]
		if cur["state"] == 1:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or cells.has(n):
				continue
			var p := _cell_pos(origin, n)
			var fy: float = cur["y"]
			var hit: Variant = _floor_y(space, p, fy + MAX_STEP + 0.7, exclude)
			var state := 0
			var ny := fy
			if hit == null:
				state = 2
			else:
				ny = float(hit)
				if ny > fy + MAX_STEP:
					state = 1  # escalón demasiado alto: mesa, sofá, mostrador
				elif ny < fy - DROP_WARN:
					state = 3
			if state != 1:
				q.transform = Transform3D(Basis(), Vector3(p.x, ny + 0.5 + BODY_SIZE.y * 0.5, p.z))
				if _blocked(space.intersect_shape(q, 8)):
					state = 1
			cells[n] = {"y": ny, "state": state}
			if state == 2:
				holes.append(n)
			if state != 1:
				queue.append(n)
	return {"cells": cells, "holes": holes, "origin": origin, "nx": nx, "nz": nz, "bounds": bounds}


func _cell_pos(origin: Vector2, c: Vector2i) -> Vector3:
	return Vector3(origin.x + c.x * STEP, 0.0, origin.y + c.y * STEP)


## Altura del suelo bajo (x, z) partiendo de from_y; null si no hay nada en RAY_DOWN m.
func _floor_y(space: PhysicsDirectSpaceState3D, p: Vector3, from_y: float, exclude: Array[RID]) -> Variant:
	var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, from_y - 1.2 - RAY_DOWN, p.z), 1, exclude)
	var r := space.intersect_ray(rq)
	if r.is_empty():
		return null
	return (r["position"] as Vector3).y


## Un cuerpo bloquea salvo que sea una puerta sin llave o una hoja del ascensor (se abren).
func _blocked(hits: Array[Dictionary]) -> bool:
	for h in hits:
		var col: Object = h.get("collider")
		if not (col is Node):
			continue
		var n: Node = col
		var ignorable := false
		while n != null:
			if n is WorldObjects.Door and (not (n as WorldObjects.Door).locked or _reach_mode):
				ignorable = true
				break
			if n.name.begins_with("Hoja"):
				ignorable = true
				break
			n = n.get_parent()
		if not ignorable:
			return true
	return false


## Agrupa celdas-hueco contiguas en zonas: [{count, min: Vector2, max: Vector2}].
func cluster(holes: Array[Vector2i], origin: Vector2) -> Array[Dictionary]:
	var set: Dictionary = {}
	for h in holes:
		set[h] = true
	var out: Array[Dictionary] = []
	for h in holes:
		if not set.has(h):
			continue
		var stack: Array = [h]
		set.erase(h)
		var count := 0
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			count += 1
			var p := _cell_pos(origin, c)
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if set.has(n):
					set.erase(n)
					stack.append(n)
		out.append({"count": count, "min": mn, "max": mx})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["count"] > b["count"])
	return out


func _check_floor(label: String, floor_node: Node3D) -> void:
	var structural := analyze(floor_node, true)
	var real := analyze(floor_node, false)
	var s_holes: Array[Vector2i] = structural["holes"]
	var r_holes: Array[Vector2i] = real["holes"]
	total_structural += s_holes.size()
	total_real += r_holes.size()
	var walk := 0
	for c in structural["cells"].values():
		if c["state"] != 1:
			walk += 1
	var line := "%s: %d celdas transitables, %d huecos estructurales, %d huecos reales" % [label, walk, s_holes.size(), r_holes.size()]
	print("[colision] " + line)
	report.append(line)
	for z in cluster(s_holes, structural["origin"]):
		var mn: Vector2 = z["min"]
		var mx: Vector2 = z["max"]
		var w := mx - mn + Vector2(STEP, STEP)
		var danger := minf(w.x, w.y) >= 0.5
		var zl := "    zona%s: %d celdas, x %.2f..%.2f  z %.2f..%.2f (%.2f × %.2f m)" % [" PELIGRO" if danger else "", z["count"], mn.x, mx.x + STEP, mn.y, mx.y + STEP, w.x, w.y]
		print("[colision]" + zl)
		report.append(zl)
	_dump_map(label, structural)
	# Alcanzabilidad: desde el spawn del ascensor hay que poder llegar andando a todos los marcadores.
	# v0.3 P2: las puertas con llave por reglas (sala de training, tópico, deck de la azotea) se abren
	# en el juego; para "¿se llega andando?" cuentan como abiertas.
	_reach_mode = true
	var reach := analyze(floor_node, false, ["ascensor"])
	_reach_mode = false
	var rcells: Dictionary = reach["cells"]
	var origin: Vector2 = reach["origin"]
	var missing: Array[String] = []
	for m in floor_node.find_children("*", "Marker3D", true, false):
		var gp := (m as Marker3D).global_position
		var c := Vector2i(int(round((gp.x - origin.x) / STEP)), int(round((gp.z - origin.y) / STEP)))
		var ok := false
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if rcells.has(c + d) and int(rcells[c + d]["state"]) != 1:
				ok = true
		if not ok:
			missing.append("%s (%.1f, %.1f)" % [m.name, gp.x, gp.z])
	if not missing.is_empty():
		var ml := "    NO ALCANZABLE desde el ascensor: " + ", ".join(missing)
		print("[colision]" + ml)
		report.append(ml)
		unreachable += missing.size()


## Mapa ASCII (x horizontal, z vertical): '.' transitable, '#' bloqueado, 'O' hueco, 'v' desnivel, ' ' no alcanzado.
func _dump_map(label: String, a: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var fname := "user://logs/colision_%s.txt" % label.replace(" ", "_").replace("→", "_a_")
	var f := FileAccess.open(fname, FileAccess.WRITE)
	if f == null:
		return
	var origin: Vector2 = a["origin"]
	f.store_line("%s · origen (%.2f, %.2f) · paso %.2f m · columna = x, fila = z" % [label, origin.x, origin.y, STEP])
	var cells: Dictionary = a["cells"]
	for z in a["nz"]:
		var row := ""
		for x in a["nx"]:
			var c := Vector2i(x, z)
			if not cells.has(c):
				row += " "
			else:
				match int(cells[c]["state"]):
					0: row += "."
					1: row += "#"
					2: row += "O"
					3: row += "v"
		f.store_line("%6.2f %s" % [origin.y + z * STEP, row])
	f.close()

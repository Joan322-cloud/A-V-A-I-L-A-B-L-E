class_name TrainingTargets
extends RefCounted
## v0.3.2 (feedback de Joan sobre la beta: «los pasos del Training tapan la interfaz de la PC y de Ezlaki… que se vean
## las dos cosas, quizá con flechas») · Dónde está, EN LA VISTA, lo que un paso del Training pide usar.
##
## Cada paso de data/tutorial.json puede traer `ui`: una lista de ids en orden de preferencia; vale el primero que
## ahora mismo se puede señalar (está a la vista y, si es un botón, activo). Así un mismo paso señala el botón del
## menú AUX si el menú está abierto y, si no, la fila de AUX de Fonex; o el campo del correo si estás en Correo y, si
## no, la pestaña [F2]. Los ids:
##   controles de la PC (llevan set_meta("guia", id) en su script): fonex:aceptar · fonex:hold · fonex:aux ·
##     fonex:aux:<n> · fonex:estado · fonex:kpi · app:<kardex|correo|identa|portal|campus> · pc:siguiente ·
##     kardex:opciones · kardex:buscar · kardex:resultado · correo:<kardex|destinatario|plantilla|campos|adjunto|enviar|
##     tipificar|cerrar> · identa:decidir · portal:buscar · ezlak:lista · ezlak:canal:<id> · ezlak:respuestas ·
##     ezlak:respuesta:<id> · ezlak:fijado · ezlak:reaccion · ezlak:escribir
##   del overlay / otras capas: aux_menu:<n> · ww:ack · ascensor:piso:<n> · muerte:reconectar · comodin
##   del HUD: hud:avl (métricas) · hud:aux · hud:reloj
##   atajos: aux:<NOMBRE> (el botón del menú AUX abierto o, si no, el de Fonex) · correo:paso (el control del paso en
##     que va el correo) · monitor (los dos monitores de tu sitio, en 3D) · mundo (el `objetivo` del paso: la luz guía)
## Un control de la PC se señala con la vista acercada (rect exacto sobre la pantalla) y también SIN acercar: se
## proyecta sobre el monitor 3D (MonitorScreen) con la cámara del jugador.
##
## resolve() → {} si no hay nada que señalar, o {id, rect: Rect2 en px lógicos de la vista, poly: PackedVector2Array
## (las 4 esquinas cuando está proyectado en 3D; vacío si es un rect recto), zona: "vista" | "pc" | "pc3d" | "mundo",
## dentro: bool (cae dentro de la vista), punto: Vector2 (a dónde apunta la flecha), dist: metros (solo «mundo»)}.
## obstacles() → los menús a la vista que la guía tampoco debe tapar (menú AUX, aviso del WW, botonera del ascensor,
## panel del comodín, la columna de la pantalla de muerte).

const AUX_NAMES: Array[String] = ["AVAILABLE", "BO", "BREAK", "LUNCH", "BANO", "COACHING", "TRAINING"]
const CORREO_STEP := {"kardex": "correo:kardex", "destinatario": "correo:destinatario", "plantilla": "correo:plantilla",
	"campos": "correo:campos", "adjunto": "correo:adjunto", "enviar": "correo:enviar", "tipificar": "correo:tipificar", "cerrar": "correo:cerrar"}

static var _cache: Dictionary = {}  # id -> WeakRef del control (los de la PC se reconstruyen: se vuelve a buscar si murió)


static func resolve(tree: SceneTree, ids: Array, tut: Node = null) -> Dictionary:
	for raw in ids:
		var r := _one(tree, str(raw), tut)
		if not r.is_empty():
			return r
	return {}


static func _ws(tree: SceneTree) -> Control:
	return tree.get_first_node_in_group("workstation") as Control


static func _one(tree: SceneTree, id: String, tut: Node) -> Dictionary:
	var ws := _ws(tree)
	if id == "mundo":
		return _world(tree, tut)
	if id == "monitor":
		return _monitors(tree, ws)
	if id == "comodin":
		var layer := Comodin.get("_layer") as CanvasLayer
		if layer != null and layer.visible and layer.get_child_count() > 0:
			return _view_rect(id, layer.get_child(0) as Control)
		return {}
	if id.begins_with("hud:"):
		return _hud(tree, id)
	if id.begins_with("aux:"):
		var n := AUX_NAMES.find(id.substr(4))
		if n < 0 or not GameState.logged_in:
			return {}
		var open := ws != null and bool(GameState.flags.get("aux_menu_open", false))
		return _one(tree, ("aux_menu:%d" if open else "fonex:aux:%d") % n, tut)
	if id == "correo:paso":
		var desk: Object = ws.get("desktop") if ws != null else null
		var correo: Object = desk.get("correo") if desk != null else null
		var st := str(correo.call("current_step")) if correo != null else ""
		return _one(tree, str(CORREO_STEP.get(st, "")), tut) if CORREO_STEP.has(st) else {}
	# Un control con set_meta("guia", id): primero en las dos pantallas de la PC, luego en el overlay y en las capas sueltas.
	if ws != null:
		for side: String in ["left", "right"]:
			var vp: SubViewport = ws.call("screen_viewport", side)
			var c := _find(vp, id, "pc:" + side + ":" + id)
			if c != null:
				return _pc(tree, ws, side, id, c) if _usable(c) else {}
		var oc := _find(ws, id, "ws:" + id, true)
		if oc != null:
			return _view_rect(id, oc) if _usable(oc) else {}
	for root_name: String in ["ElevatorUI"]:
		var lay := tree.root.get_node_or_null(root_name)
		if lay != null:
			var ec := _find(lay, id, root_name + ":" + id)
			if ec != null and _usable(ec):
				return _view_rect(id, ec)
	var main := tree.root.get_node_or_null("Main")
	var death: Node = main.get("death_screen") if main != null else null
	if death != null and id.begins_with("muerte:"):
		var dc := _find(death, id, "death:" + id)
		if dc != null and _usable(dc) and Checkpoints.death_visible:
			return _view_rect(id, dc)
	return {}


## A la vista y, si es un botón, activo (un «Aceptar» apagado no se señala: vale el siguiente id de la lista).
static func _usable(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree() or c.size.x < 2.0 or c.size.y < 2.0:
		return false
	if c is BaseButton and (c as BaseButton).disabled:
		return false
	if c is Container and not (c is PanelContainer) and c.get_child_count() == 0:
		return false  # una fila vacía (sin respuestas rápidas, sin opciones del árbol) no es nada que señalar
	return true


static func _find(root: Node, id: String, key: String, skip_viewports: bool = false) -> Control:
	if root == null:
		return null
	var ref: WeakRef = _cache.get(key)
	if ref != null:
		var c0 := ref.get_ref() as Control
		if c0 != null and is_instance_valid(c0) and c0.is_inside_tree() and str(c0.get_meta("guia", "")) == id and (root == c0 or root.is_ancestor_of(c0)):
			return c0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if skip_viewports and n is SubViewport:
			continue
		if n is Control and n.has_meta("guia") and str(n.get_meta("guia")) == id:
			_cache[key] = weakref(n)
			return n as Control
		stack.append_array(n.get_children())
	_cache.erase(key)
	return null


static func _in_view(tree: SceneTree, r: Rect2) -> bool:
	var v := tree.root.get_visible_rect().size
	return r.size.x > 0.0 and r.size.y > 0.0 and Rect2(Vector2.ZERO, v).intersects(r)


static func _view_rect(id: String, c: Control) -> Dictionary:
	if c == null:
		return {}
	var r := c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
	return {"id": id, "rect": r, "poly": PackedVector2Array(), "zona": "vista", "dentro": _in_view(c.get_tree(), r), "punto": r.get_center()}


static func _hud(tree: SceneTree, id: String) -> Dictionary:
	var main := tree.root.get_node_or_null("Main")
	var hud: Node = main.get("hud") if main != null else null
	if hud == null:
		return {}
	var l := hud.get({"hud:avl": "_metrics", "hud:aux": "_aux", "hud:reloj": "_clock"}.get(id, "")) as Label
	if l == null or not l.is_visible_in_tree() or l.text == "":
		return {}
	var g := l.get_global_transform() * Rect2(Vector2.ZERO, l.size)
	var w := minf(l.get_minimum_size().x, g.size.x)  # la etiqueta mide 500 px y el texto va pegado a la derecha
	var r := Rect2(g.end.x - w, g.position.y, w, g.size.y)
	return {"id": id, "rect": r, "poly": PackedVector2Array(), "zona": "vista", "dentro": _in_view(tree, r), "punto": r.get_center()}


## Un control de una pantalla de la PC: con la vista acercada, su rect sobre la pantalla; sin acercar, proyectado
## sobre el monitor 3D de tu sitio.
static func _pc(tree: SceneTree, ws: Control, side: String, id: String, c: Control) -> Dictionary:
	var vp: SubViewport = ws.call("screen_viewport", side)
	var full := Rect2(Vector2.ZERO, Vector2(vp.size))
	var r := (c.get_global_transform() * Rect2(Vector2.ZERO, c.size)).intersection(full)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return {}  # fuera de la pantalla (la app tiene scroll): no hay nada que señalar ahí
	if bool(ws.call("zoom_shown", side)):
		var vr: Rect2 = ws.call("screen_rect_in_view", side, r)
		return {"id": id, "rect": vr, "poly": PackedVector2Array(), "zona": "pc", "dentro": _in_view(tree, vr), "punto": vr.get_center(), "lado": side}
	if bool(ws.get("zoomed")) or GameState.seated_at == "":
		return {}  # la otra pantalla está acercada sola ([Tab]) o estás de pie
	var cam := tree.root.get_camera_3d()
	if cam == null:
		return {}
	for s in tree.get_nodes_in_group("monitor_screens"):
		var ms := s as MonitorScreen
		if ms == null or ms.seat_id != GameState.seated_at or ms.side != side or not ms.powered:
			continue
		var poly := _project(cam, ms, r, full.size)
		if poly.is_empty():
			return {}
		var br := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			br = br.expand(p)
		return {"id": id, "rect": br, "poly": poly, "zona": "pc3d", "dentro": _in_view(tree, br), "punto": br.get_center(), "lado": side}
	return {}


## Las 4 esquinas, en la vista, de un rect de la pantalla dibujado en el quad del monitor (vacío si queda detrás).
static func _project(cam: Camera3D, ms: MonitorScreen, r: Rect2, vp_size: Vector2) -> PackedVector2Array:
	var quad := ms.get("_quad") as Node3D
	if quad == null or vp_size.x < 1.0 or vp_size.y < 1.0:
		return PackedVector2Array()
	var out := PackedVector2Array()
	var sz := MonitorScreen.SCREEN_SIZE
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var uv := corner / vp_size
		var w := quad.global_transform * Vector3((uv.x - 0.5) * sz.x, (0.5 - uv.y) * sz.y, 0.0)
		if cam.is_position_behind(w):
			return PackedVector2Array()
		out.append(cam.unproject_position(w))
	return out


## Los dos monitores de tu sitio (para «mira un monitor y pulsa [E]»): solo sentado y sin la vista acercada.
static func _monitors(tree: SceneTree, ws: Control) -> Dictionary:
	if GameState.seated_at == "" or (ws != null and bool(ws.get("zoomed"))):
		return {}
	var cam := tree.root.get_camera_3d()
	if cam == null:
		return {}
	var br := Rect2()
	var any := false
	for s in tree.get_nodes_in_group("monitor_screens"):
		var ms := s as MonitorScreen
		if ms == null or ms.seat_id != GameState.seated_at:
			continue
		var poly := _project(cam, ms, Rect2(0, 0, 100, 100), Vector2(100, 100))
		for p in poly:
			br = br.expand(p) if any else Rect2(p, Vector2.ZERO)
			any = true
	if not any:
		return {}
	return {"id": "monitor", "rect": br, "poly": PackedVector2Array(), "zona": "pc3d", "dentro": _in_view(tree, br), "punto": br.get_center()}


## El `objetivo` del paso (silla, mesa del café, puerta, ascensor, puff): donde está la luz guía, visto por la cámara.
static func _world(tree: SceneTree, tut: Node) -> Dictionary:
	if tut == null or not tut.has_method("_target_pos") or str(tut.get("_target")) == "":
		return {}
	var pos: Vector3 = tut.call("_target_pos")
	var cam := tree.root.get_camera_3d()
	if pos == Vector3.INF or cam == null:
		return {}
	var mid := pos + Vector3(0, 1.0, 0)
	var v := tree.root.get_visible_rect().size
	var d := Vector2(cam.global_position.x - pos.x, cam.global_position.z - pos.z).length()
	if cam.is_position_behind(mid):
		# Detrás: la flecha va al borde hacia donde hay que girar.
		var local := cam.global_transform.affine_inverse() * mid
		var side := Vector2(v.x * (0.02 if local.x < 0.0 else 0.98), v.y * 0.5)
		return {"id": "mundo", "rect": Rect2(side, Vector2.ZERO), "poly": PackedVector2Array(), "zona": "mundo", "dentro": false, "punto": side, "dist": d, "detras": true}
	var top := cam.unproject_position(pos + Vector3(0, 1.9, 0))
	var bot := cam.unproject_position(pos + Vector3(0, 0.1, 0))
	var h := maxf(absf(bot.y - top.y), 40.0)
	var w := clampf(h * 0.5, 40.0, 220.0)
	var c := (top + bot) * 0.5
	var r := Rect2(c.x - w * 0.5, minf(top.y, bot.y), w, h)
	return {"id": "mundo", "rect": r, "poly": PackedVector2Array(), "zona": "mundo", "dentro": Rect2(Vector2.ZERO, v).has_point(c), "punto": c, "dist": d}


## Menús a la vista que la guía no debe tapar aunque el paso no los nombre.
static func obstacles(tree: SceneTree) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var ws := _ws(tree)
	if ws != null and ws.is_visible_in_tree() and ws.has_method("overlay_rects"):
		out.append_array(ws.call("overlay_rects"))
	var elev := tree.root.get_node_or_null("ElevatorUI")
	if elev != null and elev.get_child_count() > 0:
		var p := elev.get_child(0) as Control
		if p != null and p.is_visible_in_tree():
			out.append(p.get_global_transform() * Rect2(Vector2.ZERO, p.size))
	var layer := Comodin.get("_layer") as CanvasLayer
	if layer != null and layer.visible and layer.get_child_count() > 0:
		var cp := layer.get_child(0) as Control
		if cp != null:
			out.append(cp.get_global_transform() * Rect2(Vector2.ZERO, cp.size))
	if Checkpoints.death_visible:
		var main := tree.root.get_node_or_null("Main")
		var death: Node = main.get("death_screen") if main != null else null
		var col := _find(death, "muerte:columna", "death:muerte:columna") if death != null else null
		if col != null and col.is_visible_in_tree():
			out.append(col.get_global_transform() * Rect2(Vector2.ZERO, col.size))
	return out

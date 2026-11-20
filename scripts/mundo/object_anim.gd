class_name ObjectAnim
extends Node
## v0.3.2-anim: animación de OBJETOS con peso (puertas, casillero/refri, ascensor, monitores, sillas giratorias,
## expendedora, microondas, reloj, papeles con el aire acondicionado, la taza de C-13, el teléfono del escritorio de QA).
##
## Reglas del paquete:
##  - NO cambia tiempos de juego, colisiones ni textos de interacción: todo lo que se mueve es visual (copias sin
##    colisión, o nodos que ya eran solo malla). La colisión de una puerta se corta en el mismo instante que antes
##    (Door.set_open), las hojas del ascensor siguen EXACTAMENTE la curva de siempre mientras dura el recorrido (lo
##    nuevo va después: el rebote de las gomas al cerrar) y casillero/refri tocan el marco a la misma hora.
##  - En Modo liviano no hace NADA nuevo (on() == false): puertas que desaparecen, los tweens de siempre, el gestor
##    dormido (no censa el piso ni escucha nodos nuevos). Si se pasa a liviano a mitad de partida todo vuelve a su
##    reposo (_calm).
##  - Estado correcto siempre: al reaparecer (EventBus.respawned) y al construir el piso nada queda a medio camino
##    (puertas en su ángulo final, sillas en su sitio, microondas cerrado); los ángulos de reposo se guardan una vez
##    (meta), así que abrir/cerrar mil veces o pisar una animación con otra no acumula deriva.
##  - Un nodo gestor por piso («ObjetosAnim», lo cuelga FloorBase._ready con ObjectAnim.attach(self)) para lo que
##    late solo (papeles, vapor, reloj, microondas) y para lo que llega por EventBus (silla del jugador, expendedora).
##  - Ayudas estáticas para los scripts de objetos (una línea en cada uno):
##      ObjectAnim.door(puerta, hoja, abierta)               ← WorldObjects.Door.set_open
##      ObjectAnim.swing(obj, pivote, luz, abre_s, cierra_s) ← WorldObjects.DoorSwing.swing (casillero, refri)
##      ObjectAnim.elevator_doors(...) / floor_indicator()   ← elevator.gd (_set_doors, _set_indicator)
##      ObjectAnim.monitor(pantalla, quad, luz, on)          ← MonitorScreen.set_powered
##      ObjectAnim.chair_event(pos, "sit"|"stand")           ← NpcAnimator (sit_down / stand_up)
##      ObjectAnim.jolt(pos, radio, fuerza)                  ← un golpe en una mesa: lo que hay encima salta y tintinea
##      ObjectAnim.settle(nodo) / pop(nodo) / set_text()     ← cualquier objeto que «se apoya» o cambia (táper, bandeja…)

const NEAR := 9.0  ## m: más lejos de la cámara nada late (papeles, vapor)
const FLUTTER_MAX := 28  ## papeles/hojas que se mueven por tick como mucho
const DOOR_OPEN_DEG := 96.0
const SLAM_SPEED := 2.2  ## m/s: quien cruza la puerta más rápido que esto la abre de golpe
## La taza de C-13 (el sitio siempre vacío): humea al empezar el turno («alguien acaba de estar») y se enfría sola.
const MUG_HOT_UNTIL := 40.0 * 60.0  ## s de reloj de juego (00:40): hasta acá humea igual
const MUG_COLD_AT := 95.0 * 60.0  ## 01:35: ya no sale nada
const STEAM_ALPHA := 0.14  ## opacidad del centro de cada hilo de vapor recién servida (muy tenue)

## Interruptor general (los escenarios lo apagan para comparar; el Modo liviano lo apaga solo).
static var enabled: bool = true
## Gestor del piso activo.
static var current: ObjectAnim = null
## Cronómetro (escenario obj_costo): µs gastados por el gestor en _process y cuántos cuadros.
static var prof_on: bool = false
static var prof_usec: int = 0
static var prof_frames: int = 0
## Puertas batientes con copia viva (para dejarlas en su sitio al reaparecer o al pasar a liviano).
static var _doors: Array = []

var _floor: Node = null
var _t: float = 0.0
var _tick: float = 0.0
var _scan_left: float = 0.3
var _scanned: bool = false
var _odd: bool = false
var _was_on: bool = true
var _flutter: Array = []  # [{n, rest, kind, ph, h, live, amp}]
var _mugs: Array = []  # MeshInstance3D «Taza»
var _clocks: Array = []  # [{clock, label, last, dot}]
var _mws: Dictionary = {}  # instance_id → {n, state, glass, t, run, …}
var _chairs: Array = []  # [{root, parts, rest, c, back, a, tw, n}]
var _props: Array = []  # cosas chicas sobre las mesas que saltan con un golpe: MeshInstance3D
var _player_chair: Dictionary = {}
var _racks: Array = []  # carros de bandejas de la cafetería: [{root, rails, rest, cool}]
var _eat_prop: Node3D = null  # el táper que queda sobre la mesa mientras estás sentado comiendo
var _eat_token: int = 0
var _seen: Dictionary = {}  # instance_id ya clasificado
var _pending: Array = []  # nodos que entraron al piso después del censo (se clasifican en el tick lento)
var _palm: bool = false


static func on() -> bool:
	return enabled and not GfxQuality.is_light()


## Cuelga el gestor del piso (una vez).
static func attach(fl: Node) -> ObjectAnim:
	if fl == null:
		return null
	var m := fl.get_node_or_null("ObjetosAnim") as ObjectAnim
	if m == null:
		m = ObjectAnim.new()
		m.name = "ObjetosAnim"
		m._floor = fl
		fl.add_child(m)
	return m


## ¿El piso se acaba de construir (o no hay gestor)? Entonces nada se anima: todo aparece ya en su estado final (una
## puerta que el guion deja abierta al cargar no «se abre sola» delante del jugador).
static func _fresh() -> bool:
	return current == null or not is_instance_valid(current) or current._t < 0.5


# =====================================================================================================================
# Ayudas genéricas
# =====================================================================================================================

## Corta el tween guardado en la meta `key` de `n` (si lo hay).
static func kill_tween(n: Object, key: String) -> void:
	if n != null and n.has_meta(key):
		var tw: Variant = n.get_meta(key)
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		n.remove_meta(key)


## Nodo guardado en una lista → Node3D, o null si ya lo liberaron (el Modo liviano funde las mallas estáticas y libera
## las originales; un `as` directo sobre un objeto liberado es un error de script).
static func _n3(x: Variant) -> Node3D:
	return x as Node3D if is_instance_valid(x) else null


## ¿Hay una animación de esa clave en curso sobre el nodo? (pruebas y guardas)
static func _has_tween(n: Object, key: String) -> bool:
	if n == null or not is_instance_valid(n) or not n.has_meta(key):
		return false
	var tw: Variant = n.get_meta(key)
	return tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running()


static func _tween(n: Node, key: String) -> Tween:
	kill_tween(n, key)
	var tw := n.create_tween()
	n.set_meta(key, tw)
	return tw


static func _ss(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / maxf(b - a, 0.0001), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## «Pop» de escala (un indicador que cambia, un botón): crece un pelo y vuelve con rebote a su escala de siempre.
static func pop(n: Node3D, amount: float = 1.22, secs: float = 0.24) -> void:
	if n == null or not n.is_inside_tree() or not on():
		return
	var base: Vector3 = n.get_meta("oa_scale", n.scale)
	n.set_meta("oa_scale", base)
	n.scale = base * amount
	_tween(n, "oa_pop").tween_property(n, "scale", base, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cambia el texto de un Label3D y, si de verdad cambió, le da un pop.
static func set_text(l: Label3D, text: String) -> void:
	if l == null:
		return
	var changed := l.text != text and l.text != ""
	l.text = text
	if changed:
		pop(l, 1.18, 0.22)


## Un objeto que se apoya (táper en la mesa, bandeja, lata): cae `drop` m, rebota dos veces y se asienta con un giro
## mínimo. Vuelve EXACTAMENTE a su transform. `delay` para sincronizar con una mano.
static func settle(n: Node3D, drop: float = 0.05, delay: float = 0.0) -> void:
	if n == null or not n.is_inside_tree() or not on():
		return
	var rest: Transform3D = n.get_meta("oa_rest", n.transform)
	n.set_meta("oa_rest", rest)
	var sgn := 1.0 if (n.get_instance_id() % 2) == 0 else -1.0
	var tw := _tween(n, "oa_settle")
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(u: float) -> void:
		# caída libre hasta u = 0,34; dos rebotes que se apagan; giro y cabeceo que mueren con ellos
		var y := 0.0
		if u < 0.34:
			y = drop * (1.0 - (u / 0.34) * (u / 0.34))
		elif u < 0.62:
			var k := (u - 0.34) / 0.28
			y = drop * 0.22 * 4.0 * k * (1.0 - k)
		elif u < 0.8:
			var k2 := (u - 0.62) / 0.18
			y = drop * 0.06 * 4.0 * k2 * (1.0 - k2)
		var wob := (1.0 - u) * (1.0 - u) * sin(u * 21.0) * (0.0 if u < 0.34 else 1.0)
		var b := Basis(Vector3.UP, deg_to_rad(3.0) * sgn * (1.0 - u)) * Basis(Vector3.RIGHT, deg_to_rad(2.2) * wob)
		n.transform = Transform3D(rest.basis * b, rest.origin + Vector3(0, y, 0))
	, 0.0, 1.0, 0.55)
	tw.tween_callback(func() -> void: n.transform = rest)


## Un golpe en una mesa (alguien la golpea o se le viene encima con los antebrazos): las cosas chicas que hay a menos
## de `radius` m (taza, auricular del teléfono, grabadora, pañuelos…) saltan, tintinean y vuelven a su sitio exacto.
static func jolt(pos: Vector3, radius: float = 1.1, strength: float = 1.0) -> int:
	var m := current
	if m == null or not is_instance_valid(m) or not on():
		return 0
	var hit := 0
	for p in m._props:
		var mi := _n3(p) as MeshInstance3D
		if mi == null or not mi.is_inside_tree() or not mi.is_visible_in_tree():
			continue
		var d := mi.global_position.distance_to(pos)
		if d > radius:
			continue
		hit += 1
		var k := strength * (1.0 - 0.6 * d / radius)
		var rest: Transform3D = mi.get_meta("oa_rest", mi.transform)
		mi.set_meta("oa_rest", rest)
		var ph := float(mi.get_instance_id() % 97) * 0.37
		var tw := _tween(mi, "oa_settle")
		tw.tween_interval(d * 0.02)  # la onda tarda un pelo en llegar
		tw.tween_method(func(u: float) -> void:
			# salto corto (gravedad), dos rebotes y un tintineo de giro que se apaga
			var y := 0.0
			if u < 0.3:
				var a := u / 0.3
				y = 0.016 * k * 4.0 * a * (1.0 - a)
			elif u < 0.5:
				var b := (u - 0.3) / 0.2
				y = 0.004 * k * 4.0 * b * (1.0 - b)
			var damp := (1.0 - u) * (1.0 - u)
			var bas := Basis(Vector3.UP, deg_to_rad(4.0) * k * damp * sin(u * 33.0 + ph)) * Basis(Vector3.BACK, deg_to_rad(2.5) * k * damp * sin(u * 27.0 + ph * 2.0))
			mi.transform = Transform3D(rest.basis * bas, rest.origin + Vector3(0, y, 0))
		, 0.0, 1.0, 0.5)
		tw.tween_callback(func() -> void: mi.transform = rest)
	return hit


# =====================================================================================================================
# Puertas batientes (WorldObjects.Door)
# =====================================================================================================================

## Manija de palanca a los dos lados de una hoja de una sola pieza (inox). La copia que gira la lleva y la baja al abrir.
static func ensure_handle(leaf: MeshInstance3D) -> void:
	var bm := leaf.mesh as BoxMesh
	if bm == null or bm.size.z > 0.2 or bm.size.y < 1.6 or bm.size.x > 1.3 or leaf.get_node_or_null("Manija") != null:
		return
	if leaf.get_node_or_null("GfxManija") != null:
		return  # v0.3.2-final: la capa de detalle (Alta) ya le puso la suya a esta hoja (estaba abierta al vestir el piso): una sola
	var w := bm.size.x
	var th := bm.size.z
	var m := Node3D.new()
	m.name = "Manija"
	m.position = Vector3(w * 0.5 - 0.09, -0.05, 0)
	leaf.add_child(m)
	var inox := Greybox.inox()
	for s in [-1.0, 1.0]:
		var tag := "A" if s > 0.0 else "B"
		Greybox.box(m, "Roseta" + tag, Vector3(0, 0, s * (th * 0.5 + 0.005)), Vector3(0.05, 0.05, 0.01), Greybox.INOX, false).material_override = inox
		Greybox.box(m, "Cuello" + tag, Vector3(0, 0, s * (th * 0.5 + 0.024)), Vector3(0.018, 0.018, 0.034), Greybox.INOX, false).material_override = inox
		Greybox.box(m, "Palanca" + tag, Vector3(-0.055, 0, s * (th * 0.5 + 0.044)), Vector3(0.13, 0.02, 0.022), Greybox.INOX, false).material_override = inox


static func _strip_bodies(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_bodies(c)


## Quién abre: el más cercano entre el jugador y los personajes animados, a menos de 4,5 m. [nodo, velocidad m/s].
static func _opener(d: Node3D) -> Array:
	var best: Node3D = null
	var best_d := 4.5
	var speed := 0.0
	var pl := d.get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		var dd := pl.global_position.distance_to(d.global_position)
		if dd < best_d:
			best = pl
			best_d = dd
	for a in NpcAnimator._all:
		var an := a as NpcAnimator
		if an == null or not is_instance_valid(an) or an.body == null or not is_instance_valid(an.body) or not an.body.is_inside_tree():
			continue
		if not an.body.is_visible_in_tree():
			continue
		var dn := an.body.global_position.distance_to(d.global_position)
		if dn < best_d - 0.25:  # a igual distancia manda el jugador
			best = an.body
			best_d = dn
			speed = an._v
	return [best, speed]


## Llamado por Door.set_open DESPUÉS de cambiar visible/colisión (eso no se toca). En vez de desaparecer, una copia sin
## colisión de la hoja gira sobre su bisagra alejándose de quien la abre, se pasa un poco y vuelve (de golpe y con
## rebote si la cruza alguien corriendo). Al cerrar, la copia vuelve, da un toque contra el marco y aparece la de verdad.
static func door(d: Node3D, leaf: Node, open: bool) -> void:
	if d == null or not d.is_inside_tree() or not (leaf is MeshInstance3D):
		return
	var mi := leaf as MeshInstance3D
	var st: Dictionary = d.get_meta("oa_door", {})
	if not on():
		if not st.is_empty():
			_door_drop(d)
		return
	var bm := mi.mesh as BoxMesh
	if bm == null or bm.size.z > 0.2 or bm.size.y < 1.6:
		return  # la caseta del guardia y cosas así no son hojas
	if st.is_empty():
		if not open:
			return  # cerrar lo que nunca se abrió animado: nada que hacer
		st = _door_build(d, mi, bm)
		d.set_meta("oa_door", st)
		_doors.append(d)
	elif bool(st.get("open", false)) == open and not (st.get("tw") is Tween and (st["tw"] as Tween).is_valid() and (st["tw"] as Tween).is_running()):
		return  # ya estaba así y quieta
	var old: Variant = st.get("tw")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var a0: float = st.get("a", 0.0)
	st["open"] = open
	if open:
		var who := _opener(d)
		var side := 1.0
		if absf(a0) > 0.01:
			side = signf(a0)  # ya venía girando para ese lado
		elif who[0] != null:
			var lp: Vector3 = (d.global_transform * mi.transform).affine_inverse() * (who[0] as Node3D).global_position
			side = 1.0 if lp.z >= 0.0 else -1.0
		var full := deg_to_rad(DOOR_OPEN_DEG) * side
		_door_show(d, mi, st, true)
		if _fresh():
			_door_angle(st, full)
			return
		var t := d.create_tween()
		st["tw"] = t
		var set_a := func(a: float) -> void: _door_angle(st, a)
		var slam: bool = who[0] != null and not (who[0] as Node).is_in_group("player") and float(who[1]) > SLAM_SPEED
		st["slam"] = slam
		if slam:
			# de un empujón: acelera hasta el tope, rebota fuerte y tiembla hasta quedarse
			t.tween_method(set_a, a0, full * 1.09, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_method(set_a, full * 1.09, full * 0.84, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_method(set_a, full * 0.84, full * 0.99, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_method(set_a, full * 0.99, full * 0.955, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_method(set_a, full * 0.955, full * 0.97, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			# manija abajo (anticipación), la hoja arranca con el empujón, se pasa y el brazo hidráulico la devuelve
			for h in st["handles"]:
				if is_instance_valid(h):
					var ht := _tween(h as Node, "oa_manija")
					ht.tween_property(h, "rotation:z", deg_to_rad(32.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					ht.tween_interval(0.22)
					ht.tween_property(h, "rotation:z", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.06)
			t.tween_method(set_a, a0, full * 1.045, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_method(set_a, full * 1.045, full, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		if _fresh() or absf(a0) < 0.001:
			_door_show(d, mi, st, false)
			return
		# la de verdad ya volvió a visible (y su colisión, al instante como siempre): no se dibuja hasta que llega la copia
		mi.layers = 0
		var t2 := d.create_tween()
		st["tw"] = t2
		var set_b := func(a: float) -> void: _door_angle(st, a)
		var sg := signf(a0)
		var dur := clampf(absf(a0) / deg_to_rad(DOOR_OPEN_DEG), 0.25, 1.0) * 0.34
		t2.tween_method(set_b, a0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_method(set_b, 0.0, deg_to_rad(2.6) * sg, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.tween_method(set_b, deg_to_rad(2.6) * sg, 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_callback(func() -> void: _door_show(d, mi, st, false))


static func _door_angle(st: Dictionary, a: float) -> void:
	st["a"] = a
	for p in st["pivots"]:
		if is_instance_valid(p[0]):
			(p[0] as Node3D).rotation.y = a * float(p[1])


## Muestra la copia (abierta o girando) o la guarda y deja dibujar la hoja de verdad (cerrada).
static func _door_show(d: Node3D, mi: MeshInstance3D, st: Dictionary, copy: bool) -> void:
	for p in st.get("pivots", []):
		if is_instance_valid(p[0]):
			(p[0] as Node3D).visible = copy
	if not copy:
		_door_angle(st, 0.0)
		for h in st.get("handles", []):
			if is_instance_valid(h):
				kill_tween(h as Node, "oa_manija")
				(h as Node3D).rotation.z = 0.0
	if is_instance_valid(mi):
		mi.layers = 0 if copy else int(st.get("layers", 1))
	# la barra antipánico suelta de la puerta del deck (hermana de la hoja) va con la copia: no flota en el vano
	var bar := d.get_node_or_null("Barra") as Node3D if is_instance_valid(d) else null
	if bar != null and (st.get("pivots", []) as Array).size() > 1:
		bar.visible = not copy


static func _door_build(d: Node3D, mi: MeshInstance3D, bm: BoxMesh) -> Dictionary:
	var w := bm.size.x
	var pivots: Array = []
	var handles: Array = []
	if w <= 1.3:
		ensure_handle(mi)
		var pv := Node3D.new()
		pv.name = "GiroPuerta"
		pv.transform = mi.transform * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, 0, 0))
		d.add_child(pv)
		var g := mi.duplicate() as MeshInstance3D
		_strip_bodies(g)
		g.name = "Batiente"
		g.transform = Transform3D(Basis.IDENTITY, Vector3(w * 0.5, 0, 0))
		g.visible = true
		g.layers = 1
		g.set_meta("no_merge", true)
		pv.add_child(g)
		pivots.append([pv, 1.0])
		var hm := g.get_node_or_null("Manija")
		if hm != null:
			handles.append(hm)
	else:
		# hoja ancha (vidrio del deck): son dos batientes, una por jamba
		for s in [-1.0, 1.0]:
			var pv2 := Node3D.new()
			pv2.name = "GiroPuerta%s" % ("A" if s < 0.0 else "B")
			pv2.transform = mi.transform * Transform3D(Basis.IDENTITY, Vector3(s * w * 0.5, 0, 0))
			d.add_child(pv2)
			var g2 := MeshInstance3D.new()
			g2.name = "Batiente"
			var m2 := BoxMesh.new()
			m2.size = Vector3(w * 0.5 - 0.01, bm.size.y, bm.size.z)
			g2.mesh = m2
			g2.material_override = mi.material_override
			g2.position = Vector3(-s * w * 0.25, 0, 0)
			g2.set_meta("no_merge", true)
			pv2.add_child(g2)
			var bar := Greybox.box(g2, "Tirador", Vector3(-s * (w * 0.25 - 0.1), 0, 0), Vector3(0.03, 0.5, bm.size.z + 0.1), Greybox.INOX, false)
			bar.material_override = Greybox.inox()
			pivots.append([pv2, -s])
	return {"pivots": pivots, "handles": handles, "a": 0.0, "layers": mi.layers if mi.layers != 0 else 1, "open": false, "leaf": mi}


## Deja la puerta como la deja el juego sin animación (la hoja de verdad se dibuja si está visible) y borra la copia.
static func _door_drop(d: Node3D) -> void:
	_doors.erase(d)
	if not is_instance_valid(d):
		return
	var st: Dictionary = d.get_meta("oa_door", {})
	if st.is_empty():
		return
	var tw: Variant = st.get("tw")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	var mi: Variant = st.get("leaf")
	_door_show(d, mi as MeshInstance3D if is_instance_valid(mi) else null, st, false)
	for p in st.get("pivots", []):
		if is_instance_valid(p[0]):
			(p[0] as Node).queue_free()
	d.remove_meta("oa_door")


## Sin esperar: cada puerta queda ya en el final de lo que estaba haciendo (abierta del todo o cerrada).
static func _doors_finish() -> void:
	for d in _doors.duplicate():
		if not is_instance_valid(d):
			_doors.erase(d)
			continue
		var st: Dictionary = (d as Node).get_meta("oa_door", {})
		var tw: Variant = st.get("tw")
		if not (tw is Tween and (tw as Tween).is_valid()):
			continue
		(tw as Tween).kill()
		var mi: Variant = st.get("leaf")
		if bool(st.get("open", false)):
			var a: float = st.get("a", 0.0)
			_door_angle(st, deg_to_rad(DOOR_OPEN_DEG) * (signf(a) if absf(a) > 0.001 else 1.0))
			for h in st.get("handles", []):
				if is_instance_valid(h):
					kill_tween(h as Node, "oa_manija")
					(h as Node3D).rotation.z = 0.0
		elif is_instance_valid(mi):
			_door_show(d as Node3D, mi as MeshInstance3D, st, false)


# =====================================================================================================================
# Casillero / refri (WorldObjects.DoorSwing): mismas horas, otra curva, sin deriva
# =====================================================================================================================

## La puerta del mueble abre a los `open_at` s y vuelve a tocar el marco a los `close_at` + 0,35 s, como siempre. El
## ángulo de reposo se guarda la primera vez: pedirla otra vez a mitad de camino (el jugador insiste) ya no la deja
## torcida. Con animación: la chapa del casillero se pasa y vuelve, y al cerrar golpea y rebota 4°; la puerta pesada de
## la refri despega la junta, frena sola y al cerrar la junta la chupa (la luz de adentro se apaga cuando casi cerró).
static func swing(obj: Node3D, pivot: Node3D, luz: Light3D, open_at: float, close_at: float) -> void:
	if obj == null or pivot == null or not obj.is_inside_tree():
		return
	var rest: float = pivot.get_meta("oa_rest", pivot.rotation.y)
	pivot.set_meta("oa_rest", rest)
	var full := rest - deg_to_rad(100.0)
	var hold := maxf(close_at - open_at - 0.45, 0.1)
	var tw := _tween(obj, "oa_swing")
	tw.tween_interval(open_at)
	if not on():
		tw.tween_property(pivot, "rotation:y", full, 0.45).set_trans(Tween.TRANS_SINE)
		if luz != null:
			tw.parallel().tween_property(luz, "light_energy", 1.3, 0.25)
		tw.tween_interval(hold)
		tw.tween_property(pivot, "rotation:y", rest, 0.35).set_trans(Tween.TRANS_SINE)
		if luz != null:
			tw.parallel().tween_property(luz, "light_energy", 0.0, 0.3)
		return
	if obj is WorldObjects.Fridge:
		# pesada: la junta magnética se despega (5° lentos), el brazo la lleva y frena sola un pelo pasada
		tw.tween_property(pivot, "rotation:y", rest - deg_to_rad(5.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(pivot, "rotation:y", full - deg_to_rad(2.5), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if luz != null:  # el pulsador de la luz se suelta apenas despega (cada paso dura lo que su tramo más largo: 0,3 s)
			tw.parallel().tween_property(luz, "light_energy", 1.3, 0.1)
		tw.tween_property(pivot, "rotation:y", full, 0.05 + hold * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(hold * 0.6)
		tw.tween_property(pivot, "rotation:y", rest - deg_to_rad(4.0), 0.29).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if luz != null:
			tw.parallel().tween_property(luz, "light_energy", 0.0, 0.08).set_delay(0.21)
		tw.tween_property(pivot, "rotation:y", rest, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# chapa liviana: tirón, se pasa 9° y vuelve; al cerrar golpea el marco, rebota 4° y se queda
		tw.tween_property(pivot, "rotation:y", full - deg_to_rad(9.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation:y", full, 0.15 + hold * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(hold * 0.7)
		tw.tween_property(pivot, "rotation:y", rest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(pivot, "rotation:y", rest - deg_to_rad(4.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation:y", rest, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if luz != null:
		tw.tween_callback(func() -> void: luz.light_energy = 0.0)


# =====================================================================================================================
# Ascensor
# =====================================================================================================================

## Hojas correderas: la MISMA curva de siempre (seno, `secs`) para abrir y para cerrar: llevan colisión y el paso se
## libera y se tapa a la misma hora que antes. Lo nuevo va después del recorrido: al cerrar, las gomas se tocan y
## rebotan 1 cm. Corta el tween anterior (dos órdenes seguidas ya no se pisan).
static func elevator_doors(el: Node, l: Node3D, r: Node3D, xl: float, xr: float, secs: float, open: bool) -> Tween:
	var tw := _tween(el, "oa_puertas")
	tw.tween_property(l, "position:x", xl, secs).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(r, "position:x", xr, secs).set_trans(Tween.TRANS_SINE)
	if on() and not open:
		tw.tween_property(l, "position:x", xl - 0.011, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(r, "position:x", xr + 0.011, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:x", xl, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(r, "position:x", xr, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


static func _floor_rank(t: String) -> int:
	return -1 if t == "S" else (int(t) if t.is_valid_int() else 0)


## Indicador de piso: el número nuevo entra rodando desde abajo si la cabina sube (desde arriba si baja) y una flecha
## ámbar marca el sentido mientras viaja. Sin animación (liviano) solo cambia el texto, como antes.
static func floor_indicator(l: Label3D, text: String) -> void:
	if l == null:
		return
	var old := l.text
	l.text = text
	if old == text or old == "" or not on() or not l.is_inside_tree():
		return
	var dir := signf(float(_floor_rank(text) - _floor_rank(old)))
	var rest: Vector3 = l.get_meta("oa_pos", l.position)
	l.set_meta("oa_pos", rest)
	var col: Color = l.get_meta("oa_col", l.modulate)
	l.set_meta("oa_col", col)
	l.position = rest - Vector3(0, 0.045 * dir, 0)
	l.modulate = Color(col.r, col.g, col.b, 0.25)
	var tw := _tween(l, "oa_ind")
	tw.tween_property(l, "position", rest, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate", col, 0.12)
	var arrow := l.get_node_or_null("Flecha") as MeshInstance3D
	if arrow == null:
		arrow = MeshInstance3D.new()
		arrow.name = "Flecha"
		var pm := PrismMesh.new()
		pm.size = Vector3(0.075, 0.065, 0.004)
		arrow.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(col.r, col.g, col.b)
		arrow.material_override = mat
		arrow.position = Vector3(-0.2, 0, 0)
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.add_child(arrow)
	arrow.visible = true
	arrow.rotation.z = 0.0 if dir >= 0.0 else PI
	arrow.position.y = -0.03 * dir
	var ta := _tween(arrow, "oa_flecha")
	ta.tween_property(arrow, "position:y", 0.02 * dir, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ta.tween_interval(0.85)  # si no llega otro piso en ~1,2 s, el viaje terminó
	ta.tween_callback(func() -> void: arrow.visible = false)


# =====================================================================================================================
# Monitores
# =====================================================================================================================

## Encender: la retroiluminación parpadea dos veces antes de quedarse (imagen y luz azul). Apagar: el vidrio conserva
## un resplandor que se va en 0,3 s. No toca la energía de la luz (es del ánimo del piso): tiñe su color.
static func monitor(scr: Node, quad: MeshInstance3D, glow: Light3D, powered: bool) -> void:
	if scr == null or not scr.is_inside_tree() or quad == null:
		return
	kill_tween(scr, "oa_mon")
	if scr.has_meta("oa_offmat"):  # un apagado cortado a medias: el vidrio queda oscuro del todo
		var om := scr.get_meta("oa_offmat") as StandardMaterial3D
		if om != null and om.albedo_texture == null and scr.has_meta("oa_dark"):
			om.albedo_color = scr.get_meta("oa_dark")
		scr.remove_meta("oa_offmat")
	var mat := quad.material_override as StandardMaterial3D
	var gcol := Color(0.45, 0.6, 0.95)
	if glow != null:
		gcol = scr.get_meta("oa_glow", glow.light_color)
		scr.set_meta("oa_glow", gcol)
		glow.light_color = gcol
	if mat == null:
		return
	if powered:
		mat.albedo_color = Color(1, 1, 1)
		if not on() or _fresh():
			return
		var tw := _tween(scr, "oa_mon")
		mat.albedo_color = Color(0.05, 0.05, 0.06)
		if glow != null:
			glow.light_color = Color(0, 0, 0)
		for s in [[0.12, 0.0], [0.75, 0.05], [0.3, 0.05], [0.55, 0.07], [1.0, 0.16]]:
			var v := float(s[0])
			tw.tween_property(mat, "albedo_color", Color(v, v, v * 1.02 if v < 1.0 else 1.0), float(s[1]))
			if glow != null:
				tw.parallel().tween_property(glow, "light_color", gcol * v, float(s[1]))
	else:
		# apagado: `mat` es el vidrio oscuro (si muestra un reflejo, ni se toca)
		if not on() or _fresh() or mat.albedo_texture != null:
			return
		var dark: Color = scr.get_meta("oa_dark", mat.albedo_color)
		scr.set_meta("oa_dark", dark)
		scr.set_meta("oa_offmat", mat)
		mat.albedo_color = Color(0.2, 0.24, 0.32)
		var tw2 := _tween(scr, "oa_mon")
		tw2.tween_method(func(u: float) -> void:
			if mat.albedo_texture == null:  # si entra un reflejo a mitad, manda él
				mat.albedo_color = Color(0.2, 0.24, 0.32).lerp(dark, u)
		, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_callback(func() -> void:
			if mat.albedo_texture == null:
				mat.albedo_color = dark
			scr.remove_meta("oa_offmat"))


# =====================================================================================================================
# Sillas giratorias
# =====================================================================================================================

## Lo llama NpcAnimator cuando un personaje empieza a sentarse o a pararse con su clip.
static func chair_event(pos: Vector3, kind: String) -> void:
	var m := current
	if m == null or not is_instance_valid(m) or not on():
		return
	m._scan_now()
	var rec := m._chair_near(pos)
	if not rec.is_empty():
		m._chair_play(rec, kind)


func _chair_near(pos: Vector3, reach: float = 0.85) -> Dictionary:
	var best := {}
	var bd := reach
	for rec in _chairs:
		var root := _n3(rec["root"])
		if root == null or not root.is_inside_tree():
			continue
		var c: Vector3 = root.global_transform * (rec["c"] as Vector3)
		var dd := Vector2(c.x - pos.x, c.z - pos.z).length()
		if dd < bd and absf(c.y - pos.y) < 1.5:
			bd = dd
			best = rec
	return best


## Estado de una silla: a = [giro rad, atrás m, hundimiento m]. Las piezas se recolocan desde su reposo, girando
## alrededor del pistón (centro del asiento); no se reemparenta nada (otros buscan «Silla»/«Respaldo» por nombre).
func _chair_apply(rec: Dictionary, yaw: float, back: float, dip: float) -> void:
	rec["a"] = [yaw, back, dip]
	var c: Vector3 = rec["c"]
	var bdir: Vector3 = rec["back"]
	var xf := Transform3D(Basis.IDENTITY, c + bdir * back) * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -c)
	var parts: Array = rec["parts"]
	var rest: Array = rec["rest"]
	for i in parts.size():
		var p := _n3(parts[i])
		if p == null:
			continue
		var t: Transform3D = xf * (rest[i] as Transform3D)
		if i < 2:  # asiento y respaldo bajan con el pistón; la base no
			t.origin.y += dip
		p.transform = t


func _chair_displaced(rec: Dictionary) -> bool:
	var a: Array = rec.get("a", [0.0, 0.0, 0.0])
	return absf(float(a[0])) > 0.0005 or absf(float(a[1])) > 0.0005 or absf(float(a[2])) > 0.0005


func _chair_busy(rec: Dictionary) -> bool:
	var tw: Variant = rec.get("tw")
	return tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running()


func _chair_play(rec: Dictionary, kind: String) -> void:
	var old: Variant = rec.get("tw")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var a: Array = rec.get("a", [0.0, 0.0, 0.0])
	var y0 := float(a[0])
	var b0 := float(a[1])
	if kind == "reset":
		_chair_apply(rec, 0.0, 0.0, 0.0)
		return
	var sg: float = 1.0 if (int(rec.get("n", 0)) % 2) == 0 else -1.0
	rec["n"] = int(rec.get("n", 0)) + 1
	var tw := create_tween()
	rec["tw"] = tw
	match kind:
		"sit", "sit_player":
			# la saca con la mano (si estaba en su sitio), la trae debajo mientras baja, se hunde al recibir el peso y se
			# mece. El peso cae a los 0,9 s del clip sit_down; el jugador se sienta de golpe.
			var t_land := 0.9 if kind == "sit" else 0.08
			var out := 0.26 if (b0 < 0.1 and kind == "sit") else 0.0
			tw.tween_method(func(t: float) -> void:
				var home := 1.0 - _ss(t_land * 0.22, t_land * 0.95, t)
				var back := b0 * home + out * _ss(0.0, 0.3, t) * (1.0 - _ss(0.42, 0.88, t))
				var nudge := deg_to_rad(6.0) * sg * _ss(0.1, 0.45, t) * (1.0 - _ss(0.7, 0.98, t)) * (1.0 if kind == "sit" else 0.0)
				var k := maxf(t - t_land - 0.02, 0.0)
				var land := _ss(t_land, t_land + 0.08, t)
				var yaw := y0 * home + nudge - deg_to_rad(3.5) * sg * land * exp(-k * 3.2) * sin(k * 9.0)
				var dip := -0.022 * land * exp(-k * 4.5) * cos(k * 11.0)
				_chair_apply(rec, yaw, back, dip)
			, 0.0, 2.3, 2.3)
			tw.tween_callback(func() -> void: _chair_apply(rec, 0.0, 0.0, 0.0))
		"stand", "stand_player":
			# se aplasta al empujar, salta al soltar el peso, rueda hacia atrás girando y se queda corrida (quien se
			# vuelva a sentar la trae): así el que se para queda DELANTE de la silla y no metido en ella.
			var far := 0.3 if kind == "stand_player" else 0.4
			var turn := deg_to_rad(17.0 if kind == "stand_player" else 13.0) * sg
			var t_off := 0.12 if kind == "stand_player" else 0.45
			tw.tween_method(func(t: float) -> void:
				var k := maxf(t - t_off, 0.0)
				var dip := -0.008 * _ss(0.0, t_off * 0.7, t) * (1.0 - _ss(t_off * 0.8, t_off + 0.06, t))
				dip += 0.012 * _ss(t_off, t_off + 0.05, t) * exp(-k * 5.0) * sin(k * 12.0)
				var go := 1.0 - exp(-k * 2.6)  # rueda y frena sola
				var yaw := lerpf(y0, turn, go) + deg_to_rad(1.6) * sg * exp(-k * 1.8) * sin(k * 5.5) * _ss(t_off, t_off + 0.2, t)
				_chair_apply(rec, yaw, lerpf(b0, far, go), dip)
			, 0.0, 2.6, 2.6)
			tw.tween_callback(func() -> void: _chair_apply(rec, turn, far, 0.0))
		_:
			tw.kill()


## Sillas corridas sin dueño de pie: si hay alguien SENTADO donde va la silla (apareció sentado, lo teletransportó el
## guion, reapareciste) vuelve a su sitio de un saque. Solo mira las que están corridas y quietas.
func _chairs_fix() -> void:
	for rec in _chairs:
		if not _chair_displaced(rec) or _chair_busy(rec):
			continue
		var root := _n3(rec["root"])
		if root == null or not root.is_inside_tree():
			continue
		var c: Vector3 = root.global_transform * (rec["c"] as Vector3)
		for a in NpcAnimator._all:
			var an := a as NpcAnimator
			if an == null or not is_instance_valid(an) or an.state != "seated" or an.body == null or not is_instance_valid(an.body) or not an.body.is_inside_tree():
				continue
			var p := an.body.global_position
			if Vector2(p.x - c.x, p.z - c.z).length() < 0.7 and absf(p.y - c.y) < 1.5:
				_chair_apply(rec, 0.0, 0.0, 0.0)
				break


# =====================================================================================================================
# Gestor del piso
# =====================================================================================================================

func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	if _floor == null:
		_floor = get_parent()
	_was_on = on()
	EventBus.player_seated.connect(_on_player_seated)
	EventBus.player_stood_up.connect(_on_player_stood)
	EventBus.shop_bought.connect(_on_shop_bought)
	EventBus.respawned.connect(_on_respawned)


func _on_player_seated(_id: String) -> void:
	if not on():
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	_scan_now()
	if _id.begins_with("mesa_comer_"):
		_eat_begin(pl, _id.trim_prefix("mesa_comer_"))
	_player_chair = _chair_near(pl.global_position)
	if not _player_chair.is_empty():
		if _fresh():
			_chair_play(_player_chair, "reset")
		else:
			_chair_play(_player_chair, "sit_player")


func _on_player_stood() -> void:
	_eat_end(true)
	if not on() or _player_chair.is_empty():
		return
	if not _fresh():
		_chair_play(_player_chair, "stand_player")
	_player_chair = {}


# --- cafetería: el táper sobre la mesa y los carros de bandejas ------------------------------------------------------

## Comés sentado a una mesa (WorldObjects.EatSpot): las manos comen del táper (ManosFx, 3,3 s) y al terminar lo dejan
## sobre la mesa, delante tuyo: cae un par de centímetros, se asienta, la tapa queda apoyada al costado y el tenedor
## adentro. Al pararte te lo llevás. Solo malla, sin colisión.
func _eat_begin(pl: Node3D, spot_id: String) -> void:
	_eat_end(false)
	var spot := _floor.find_child("Comer_" + spot_id, false, false) as Node3D
	if spot == null:
		return
	var top := spot.global_position.y
	var half := 0.4
	var tb: Variant = spot.get("table")
	var mi := tb as MeshInstance3D
	if is_instance_valid(mi) and mi.mesh != null:
		var bb := mi.global_transform * mi.mesh.get_aabb()
		top = bb.position.y + bb.size.y
		half = minf(bb.size.x, bb.size.z) * 0.5
	var c := Vector3(spot.global_position.x, top, spot.global_position.z)
	var to_pl := Vector3(pl.global_position.x - c.x, 0, pl.global_position.z - c.z)
	if to_pl.length() < 0.05:
		return
	var at := c + to_pl.normalized() * clampf(half - 0.17, 0.0, 0.45)
	_eat_token += 1
	var tok := _eat_token
	var root := Node3D.new()
	root.name = "TaperMesa"
	_floor.add_child(root)
	root.global_position = at
	root.global_rotation = Vector3(0, atan2(to_pl.x, to_pl.z) + deg_to_rad(8.0), 0)  # +Z hacia el jugador, apenas torcido
	root.visible = false
	_eat_prop = root
	var body := _eat_box(root, "Cuerpo", Vector3(0.17, 0.065, 0.12), Vector3(0, 0.0325, 0), Color(0.9, 0.9, 0.86, 0.6))
	_eat_box(body, "Resto", Vector3(0.15, 0.008, 0.1), Vector3(0, -0.026, 0), Color(0.62, 0.42, 0.18))
	var fork := _eat_box(root, "Tenedor", Vector3(0.012, 0.006, 0.16), Vector3(0.02, 0.058, 0.01), Color(0.75, 0.76, 0.78))
	fork.rotation_degrees = Vector3(-14.0, 34.0, 0)
	var lid := _eat_box(root, "Tapa", Vector3(0.175, 0.012, 0.125), Vector3(-0.19, 0.006, 0.02), Color(0.2, 0.42, 0.7))
	lid.rotation_degrees = Vector3(0, -17.0, 0)
	var tw := _tween(root, "oa_eat")
	tw.tween_interval(0.0 if _fresh() else 3.05)  # cuando las manos lo bajan
	tw.tween_callback(func() -> void:
		if tok != _eat_token or not is_instance_valid(root):
			return
		root.visible = true
		if not _fresh():
			settle(body, 0.035)
			settle(fork, 0.035, 0.03)
			settle(lid, 0.02, 0.22))


func _eat_box(parent: Node3D, n: String, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.5
	if col.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.position = pos
	return m


## Te parás (o reaparecés): el táper se va con vos. `lift` = lo levantás (un gesto corto) en vez de desaparecer en seco.
func _eat_end(lift: bool) -> void:
	_eat_token += 1
	var root := _eat_prop
	_eat_prop = null
	if root == null or not is_instance_valid(root):
		return
	kill_tween(root, "oa_eat")
	if not lift or not root.visible or not on() or _fresh():
		root.queue_free()
		return
	var tw := _tween(root, "oa_eat")
	tw.tween_property(root, "position", root.position + Vector3(0, 0.07, 0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "scale", Vector3.ONE * 0.6, 0.16)
	tw.tween_callback(root.queue_free)


## Carro de bandejas: lo rozás al pasar y las bandejas tintinean en sus rieles (cada una con su fase) y se aquietan.
## Solo se mueven las mallas de los rieles; el carro y su colisión no.
func _rack_rattle(rk: Dictionary, k: float) -> void:
	rk["cool"] = 1.4
	var rails: Array = rk["rails"]
	for i in rails.size():
		var mi := _n3(rails[i]) as MeshInstance3D
		if mi == null:
			continue
		var rest: Transform3D = (rk["rest"] as Array)[i]
		var ph := float(i) * 1.7
		var tw := _tween(mi, "oa_settle")
		tw.tween_interval(0.012 * i)
		tw.tween_method(func(u: float) -> void:
			var damp := (1.0 - u) * (1.0 - u)
			var b := Basis(Vector3.UP, deg_to_rad(1.6) * k * damp * sin(u * 37.0 + ph)) * Basis(Vector3.BACK, deg_to_rad(1.1) * k * damp * sin(u * 29.0 + ph * 2.0))
			mi.transform = Transform3D(rest.basis * b, rest.origin + Vector3(0.003 * k * damp * sin(u * 23.0 + ph), 0.004 * k * damp * absf(sin(u * 30.0 + ph)), 0))
		, 0.0, 1.0, 0.7)
		tw.tween_callback(func() -> void: mi.transform = rest)


func _racks_tick() -> void:
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody3D
	for rk in _racks:
		rk["cool"] = maxf(float(rk["cool"]) - 0.25, 0.0)
		var root := _n3(rk["root"])
		if pl == null or float(rk["cool"]) > 0.0 or root == null:
			continue
		var l := root.to_local(pl.global_position)
		var gap := Vector2(maxf(absf(l.x) - 0.32, 0.0), maxf(absf(l.z) - 0.24, 0.0)).length()
		var sp := Vector2(pl.velocity.x, pl.velocity.z).length()
		if gap < 0.42 and absf(l.y) < 1.9 and sp > 1.2:
			_rack_rattle(rk, clampf(sp / 5.0, 0.45, 1.2))


func _racks_rest() -> void:
	for rk in _racks:
		var rails: Array = rk["rails"]
		for i in rails.size():
			if is_instance_valid(rails[i]):
				kill_tween(rails[i] as Node, "oa_settle")
				(rails[i] as Node3D).transform = (rk["rest"] as Array)[i]


## Reapareciste (muerte → «Reconectando»): nada queda a medio camino ni corrido. Las puertas terminan su giro, las
## sillas vuelven a su sitio, el microondas queda cerrado, los papeles en reposo.
func _on_respawned(_kind: String) -> void:
	settle_all()


## Deja TODO en el final de lo que estaba haciendo (sin esperar). Lo usan el respawn y las pruebas.
func settle_all() -> void:
	_doors_finish()
	for rec in _chairs:
		if _chair_displaced(rec) or _chair_busy(rec):
			_chair_play(rec, "reset")
	_player_chair = {}
	for id in _mws:
		_mw_door_close(_mws[id])
	for p in _props:
		if is_instance_valid(p) and (p as Node).has_meta("oa_rest"):
			kill_tween(p as Node, "oa_settle")
			(p as Node3D).transform = (p as Node).get_meta("oa_rest")
	_racks_rest()
	_eat_end(false)


func _on_shop_bought(shop_id: String, item: String, _price: float) -> void:
	if shop_id != "expendedora" or not on():
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var best: Node3D = null
	var bd := 6.0
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is WorldObjects.Vending and _floor.is_ancestor_of(n):
			var dd := (n as Node3D).global_position.distance_to(pl.global_position) if pl != null else 0.0
			if dd < bd:
				bd = dd
				best = n as Node3D
	if best != null:
		vend(best, pl, item)


## Expendedora: la lata cae del estante a la bandeja (gravedad, dos rebotes, rueda), la tapa de la bandeja se abre al
## golpe y vuelve. Todo es malla sin colisión delante de la cara que mira al jugador; se borra sola.
static func vend(v: Node3D, player: Node3D, item: String = "") -> void:
	if v == null or not v.is_inside_tree() or not on():
		return
	var caja := v.get_node_or_null("Caja") as MeshInstance3D
	var half := Vector3(0.5, 1.0, 0.4)
	if caja != null and caja.mesh is BoxMesh:
		half = (caja.mesh as BoxMesh).size * 0.5
	var dir := Vector3(0, 0, 1)
	if player != null:
		var ld := v.global_transform.affine_inverse() * player.global_position
		dir = Vector3(signf(ld.x), 0, 0) if absf(ld.x) > absf(ld.z) else Vector3(0, 0, signf(ld.z) if ld.z != 0.0 else 1.0)
	var old := v.get_node_or_null("CaidaLata")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "CaidaLata"
	var depth := half.x if absf(dir.x) > 0.5 else half.z
	root.position = dir * (depth + 0.02)
	root.rotation.y = atan2(dir.x, dir.z)
	v.add_child(root)
	var y_tray := -half.y + 0.26
	# boca de la bandeja (hueco oscuro) y su tapa abatible
	Greybox.box(root, "Boca", Vector3(0, y_tray + 0.065, -0.004), Vector3(0.36, 0.15, 0.004), Color(0.02, 0.02, 0.025), false)
	var flap_pivot := Node3D.new()
	flap_pivot.name = "TapaGiro"
	flap_pivot.position = Vector3(0, y_tray + 0.13, 0.012)
	root.add_child(flap_pivot)
	Greybox.box(flap_pivot, "Tapa", Vector3(0, -0.065, 0), Vector3(0.34, 0.13, 0.008), Color(0.06, 0.06, 0.07), false)
	var tint: Color = {"cafe": Color(0.42, 0.26, 0.14), "energetica": Color(0.1, 0.55, 0.25), "gotas": Color(0.88, 0.9, 0.95)}.get(item, Color(0.75, 0.12, 0.1))
	var can := Greybox.cylinder(root, "Lata", Vector3(0.05, 0.25, 0.035), 0.033, 0.12, tint, false, 0.35, 0.6)
	can.rotation_degrees.z = 90.0
	var y0 := 0.25
	var fall := y0 - (y_tray + 0.04)
	var tw := root.create_tween()
	# el espiral la empuja: tiembla en el borde antes de soltarse
	tw.tween_method(func(u: float) -> void:
		can.position.z = 0.035 + 0.012 * u
		can.rotation.x = deg_to_rad(8.0) * sin(u * 19.0) * u
	, 0.0, 1.0, 0.35)
	tw.tween_method(func(u: float) -> void:
		var y := 0.0
		if u < 0.42:
			var k := u / 0.42
			y = fall * (1.0 - k * k)
		elif u < 0.68:
			var k2 := (u - 0.42) / 0.26
			y = fall * 0.14 * 4.0 * k2 * (1.0 - k2)
		elif u < 0.84:
			var k3 := (u - 0.68) / 0.16
			y = fall * 0.04 * 4.0 * k3 * (1.0 - k3)
		can.position.y = y_tray + 0.04 + y
		can.position.x = 0.05 - 0.07 * _ss(0.42, 1.0, u)
		can.rotation.x = u * 5.0
	, 0.0, 1.0, 0.85)
	var ft := root.create_tween()
	ft.tween_interval(0.35 + 0.85 * 0.42)
	ft.tween_property(flap_pivot, "rotation:x", deg_to_rad(-38.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.tween_property(flap_pivot, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	# la mano la saca: sale por la tapa y desaparece
	tw.tween_property(flap_pivot, "rotation:x", deg_to_rad(-55.0), 0.12)
	tw.parallel().tween_property(can, "position:z", 0.16, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(can, "scale", Vector3.ONE * 0.01, 0.1)
	tw.parallel().tween_property(flap_pivot, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_callback(root.queue_free)


func _process(delta: float) -> void:
	var live := on()
	if not live:
		if _was_on:
			_was_on = false
			_calm()
		return
	_was_on = true
	var t0 := Time.get_ticks_usec() if prof_on else 0
	_t += delta
	if _scan_left > 0.0:
		_scan_left -= delta
		if _scan_left <= 0.0:
			_scan()
	_odd = not _odd
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		if _odd:
			_flutter_tick(cam)
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.25
			_slow_tick(cam)
		_microwave_tick(cam, delta)
	if prof_on:
		prof_usec += Time.get_ticks_usec() - t0
		prof_frames += 1


## Modo liviano activado a mitad de partida (o el interruptor apagado): todo a su reposo, sin copias ni vapor.
func _calm() -> void:
	for it in _flutter:
		if is_instance_valid(it["n"]) and it["live"]:
			(it["n"] as Node3D).transform = it["rest"]
			it["live"] = false
	for m in _mugs:
		if is_instance_valid(m):
			var v := (m as Node).get_node_or_null("Vapor") as CPUParticles3D
			if v != null:
				v.emitting = false
	for rec in _chairs:
		if _chair_displaced(rec) or _chair_busy(rec):
			_chair_play(rec, "reset")
	_player_chair = {}
	for id in _mws:
		_mw_door_close(_mws[id])
		_mw_visual(_mws[id], false)
	for d in _doors.duplicate():
		if is_instance_valid(d):
			_door_drop(d as Node3D)
		else:
			_doors.erase(d)  # puerta de un piso que ya no existe (la lista es estática): no se toca un nodo liberado
	for c in _clocks:
		if is_instance_valid(c["dot"]):
			(c["dot"] as Node3D).visible = false
	for p in _props:
		if is_instance_valid(p) and (p as Node).has_meta("oa_rest"):
			kill_tween(p as Node, "oa_settle")
			(p as Node3D).transform = (p as Node).get_meta("oa_rest")
	_racks_rest()
	_eat_end(false)


# --- censo -----------------------------------------------------------------------------------------------------------

func _scan_now() -> void:
	if not _scanned:
		_scan()


## Censo del piso (una vez, 0,3 s después de construirlo). Lo que otros paquetes cuelgan después entra por node_added
## (solo lo que tiene nombre o clase de interés) y se clasifica en el tick lento, cuando ya tiene hermanos y malla.
func _scan() -> void:
	_scan_left = 0.0
	_scanned = true
	if _floor == null or not is_instance_valid(_floor):
		return
	_palm = _floor.get_node_or_null("MacetaPalmera") != null
	for n in _floor.find_children("*", "Node3D", true, false):
		_classify(n)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


static func _interesting(n: Node) -> bool:
	if not (n is Node3D):
		return false
	if n is Interactable:
		return n is WorldObjects.WallClock or n is WorldObjects.Door or n is WorldObjects.Vending or n is WorldObjects.Microwave
	if not (n is MeshInstance3D):
		return false
	var nm := str(n.name)
	return nm.begins_with("Nota_") or nm == "HojaColgando" or nm == "Cinta" or nm == "Taza" or nm == "Silla" or nm == "Respaldo" or nm.begins_with("CablePlenum") or nm.begins_with("Telefono") or nm == "Grabadora" or nm == "Panuelos" or nm == "Riel0"


func _on_node_added(n: Node) -> void:
	if _pending.size() < 512 and _interesting(n):
		_pending.append(n)


func _drain_pending() -> void:
	if _pending.is_empty():
		return
	var list := _pending
	_pending = []
	for n in list:
		if is_instance_valid(n) and (n as Node).is_inside_tree() and _floor.is_ancestor_of(n):
			var nm := str((n as Node).name)
			if nm == "Cinta" or nm == "Respaldo":
				n = (n as Node).get_parent() if nm == "Cinta" else (n as Node).get_parent().get_node_or_null("Silla")
				if n == null:
					continue
			_classify(n)


func _classify(n: Node) -> void:
	var id := n.get_instance_id()
	if _seen.has(id):
		return
	var nm := str(n.name)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var bm := mi.mesh as BoxMesh
		if nm.begins_with("Nota_") or nm == "HojaColgando" or (bm != null and bm.size.z < 0.006 and bm.size.y > 0.15 and mi.get_node_or_null("Cinta") != null):
			# papel pegado por arriba (pósit, hoja con cinta, la hoja que cuelga de la impresora). Los que están acostados
			# sobre un escritorio no se levantan.
			if absf(mi.global_transform.basis.z.normalized().y) < 0.75 or nm == "HojaColgando":
				var h := bm.size.y if bm != null else 0.11
				_flutter.append({"n": mi, "rest": mi.transform, "kind": "papel", "ph": randf() * 40.0, "h": h, "live": false, "amp": 9.0 if nm == "HojaColgando" else (4.0 if h < 0.2 else 2.6)})
				_seen[id] = true
		elif _palm and nm.begins_with("Hoja") and mi.get_parent() == _floor and bm != null and bm.size.x > 1.0:
			_flutter.append({"n": mi, "rest": mi.transform, "kind": "fronda", "ph": randf() * 40.0, "h": bm.size.x, "live": false, "amp": 5.0})
			_seen[id] = true
		elif nm.begins_with("CablePlenum") and bm != null:
			_flutter.append({"n": mi, "rest": mi.transform, "kind": "cable", "ph": randf() * 40.0, "h": bm.size.y, "live": false, "amp": 1.6})
			_seen[id] = true
		elif nm == "Taza":
			_mugs.append(mi)
			_props.append(mi)
			_seen[id] = true
		elif nm == "Riel0" and str(mi.get_parent().name).begins_with("CarroBandejas"):
			var rk := mi.get_parent() as Node3D
			var rails: Array = []
			var rrest: Array = []
			for c in rk.get_children():
				if c is MeshInstance3D and str(c.name).begins_with("Riel"):
					rails.append(c)
					rrest.append((c as Node3D).transform)
			_racks.append({"root": rk, "rails": rails, "rest": rrest, "cool": 0.0})
			_seen[id] = true
		elif nm == "TelefonoAuricular" or nm == "Grabadora" or nm == "Panuelos":
			_props.append(mi)
			if nm == "TelefonoAuricular":
				_phone_cord(mi)
			_seen[id] = true
		elif nm == "Silla" and mi.get_parent() is Node3D:
			var root := mi.get_parent() as Node3D
			var back := root.get_node_or_null("Respaldo") as Node3D
			if back != null and root.get_script() == null:
				var parts: Array = [mi, back]
				var base := root.get_node_or_null("Base") as Node3D
				if base != null:
					parts.append(base)
				var rest: Array = []
				for p in parts:
					rest.append((p as Node3D).transform)
				var bdir := Vector3(back.position.x - mi.position.x, 0, back.position.z - mi.position.z)
				bdir = bdir.normalized() if bdir.length() > 0.05 else Vector3(0, 0, 1)
				_chairs.append({"root": root, "parts": parts, "rest": rest, "c": Vector3(mi.position.x, 0, mi.position.z), "back": bdir})
				_seen[id] = true
	elif n is WorldObjects.WallClock:
		var wc := n as WorldObjects.WallClock
		if wc.label != null:
			_clocks.append({"clock": wc, "label": wc.label, "last": wc.label.text, "dot": _clock_dot(wc)})
			_seen[id] = true
	elif n is WorldObjects.Door:
		var dr := n as WorldObjects.Door
		var hoja: Node = dr.leaf if dr.leaf != null else dr.get_node_or_null("Caja")
		if hoja is MeshInstance3D:  # la hoja puede llegar después que la puerta (leaf se asigna tras add_child)
			if not dr.open and dr.get_node_or_null("Barra") == null:
				ensure_handle(hoja as MeshInstance3D)
			_seen[id] = true
		elif int(n.get_meta("oa_try", 0)) < 8:
			n.set_meta("oa_try", int(n.get_meta("oa_try", 0)) + 1)
			_pending.append(n)
	elif n is WorldObjects.Vending:
		var vd := n as WorldObjects.Vending
		vd.interacted.connect(_on_vending_used.bind(vd))
		_seen[id] = true
	elif n is WorldObjects.Microwave:
		if n.get_node_or_null("Vidrio") is MeshInstance3D:
			_mws[id] = {"n": n, "state": str(n.get("state")), "glass": n.get_node("Vidrio"), "t": randf() * 6.0, "run": false}
			_seen[id] = true


func _on_vending_used(player: Node, v: Node3D) -> void:
	if not Economy.active():  # con economía la lata cae al comprar (shop_bought), no al abrir el menú
		vend(v, player as Node3D, "cafe")


## Cordón en espiral del teléfono fijo: del auricular a la base (hijo del auricular: salta con él).
func _phone_cord(handset: MeshInstance3D) -> void:
	if handset.get_node_or_null("Cordon0") != null:
		return
	var bm := handset.mesh as BoxMesh
	var long_z := bm == null or bm.size.z >= bm.size.x
	for i in 5:
		var u := float(i) / 4.0
		var along := (0.5 - u * 0.25) * (bm.size.z if long_z and bm != null else (bm.size.x if bm != null else 0.2))
		var p := Vector3(0.05 + 0.03 * sin(u * 9.0), -0.035 - 0.012 * sin(u * PI), along) if long_z else Vector3(along, -0.035 - 0.012 * sin(u * PI), 0.05 + 0.03 * sin(u * 9.0))
		var seg := Greybox.box(handset, "Cordon%d" % i, p, Vector3(0.012, 0.012, 0.03) if long_z else Vector3(0.03, 0.012, 0.012), Color(0.06, 0.06, 0.065), false)
		seg.rotation_degrees.y = 35.0 * sin(u * 7.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- papeles, frondas, cables ---------------------------------------------------------------------------------------

func _flutter_tick(cam: Camera3D) -> void:
	var cp := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var moved := 0
	for it in _flutter:
		var n := _n3(it["n"])
		if n == null:
			continue
		var kind: String = it["kind"]
		var rng := NEAR * (3.0 if kind == "fronda" else 1.0)
		var to := n.global_position - cp
		var near := to.length_squared() < rng * rng and (to.dot(fwd) > -1.0) and n.is_visible_in_tree()
		if not near or moved >= FLUTTER_MAX:
			if it["live"]:
				n.transform = it["rest"]
				it["live"] = false
			continue
		moved += 1
		it["live"] = true
		var ph: float = it["ph"]
		var gust := 0.5 + 0.5 * sin(_t * 0.31 + ph * 0.21)
		gust = gust * gust
		var amp := deg_to_rad(float(it["amp"]))
		var rest: Transform3D = it["rest"]
		var h: float = it["h"]
		match kind:
			"papel":
				# pegado por arriba: el borde de abajo se levanta con cada soplo del aire acondicionado
				var a := amp * (0.25 + 0.75 * gust) * (0.55 + 0.45 * sin(_t * 5.3 + ph)) * (0.6 + 0.4 * sin(_t * 1.9 + ph * 1.7))
				n.transform = rest * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)) * Transform3D(Basis(Vector3.RIGHT, -absf(a)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.5, 0))
			"fronda":
				var a2 := amp * (0.4 + 0.6 * gust) * sin(_t * 1.3 + ph) + amp * 0.25 * sin(_t * 3.1 + ph * 2.0)
				n.transform = rest * Transform3D(Basis.IDENTITY, Vector3(-h * 0.5, 0, 0)) * Transform3D(Basis(Vector3.BACK, a2) * Basis(Vector3.RIGHT, a2 * 0.6), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(h * 0.5, 0, 0))
			"cable":
				var a3 := amp * (0.3 + 0.7 * gust) * sin(_t * 1.7 + ph)
				n.transform = rest * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)) * Transform3D(Basis(Vector3.BACK, a3) * Basis(Vector3.RIGHT, a3 * 0.5), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.5, 0))


# --- cosas lentas: vapor de la taza, relojes, sillas huérfanas --------------------------------------------------------

## 1 = recién servida · 0 = fría. La taza se enfría con el reloj del turno.
static func mug_heat() -> float:
	return 1.0 - _ss(MUG_HOT_UNTIL, MUG_COLD_AT, GameState.clock_seconds)


func _slow_tick(cam: Camera3D) -> void:
	_drain_pending()
	_chairs_fix()
	if not _racks.is_empty():
		_racks_tick()
	var cp := cam.global_position
	var heat := mug_heat()
	for m in _mugs:
		var mi := _n3(m) as MeshInstance3D
		if mi == null:
			continue
		var near := heat > 0.02 and mi.is_visible_in_tree() and mi.global_position.distance_squared_to(cp) < 36.0
		var v := mi.get_node_or_null("Vapor") as CPUParticles3D
		if near and v == null:
			v = _steam(mi)
		if v != null:
			if v.emitting != near:
				v.emitting = near
			if near:
				# se enfría: los hilos suben más despacio y cada vez más tenues, hasta que no sale nada
				var mat := (v.mesh as QuadMesh).material as StandardMaterial3D
				if mat != null:
					mat.albedo_color = Color(1, 1, 1, STEAM_ALPHA * (0.2 + 0.8 * heat))
				v.speed_scale = 0.55 + 0.45 * heat
	# el punto del reloj late una vez por segundo; si la hora está congelada (3:47) se queda fijo
	var beat := fmod(_t, 1.0) < 0.5
	for c in _clocks:
		var l := _n3(c["label"]) as Label3D
		if l == null:
			continue
		var dot: Variant = c["dot"]
		var wc: Variant = c["clock"]
		if is_instance_valid(dot):
			var frozen: bool = is_instance_valid(wc) and str((wc as Object).get("frozen_text")) != ""
			(dot as Node3D).visible = true if frozen else beat
		if l.text != str(c["last"]):
			var was := str(c["last"])
			c["last"] = l.text
			# el minuto que cae: un latido chico de los dígitos (solo si cambió el último dígito, no en los saltos raros)
			if was != "" and l.global_position.distance_squared_to(cp) < 196.0 and was.length() == l.text.length():
				pop(l, 1.07, 0.3)


## Punto de segundos del reloj de pared (LED rojo, abajo a la derecha de los dígitos).
func _clock_dot(wc: Node3D) -> MeshInstance3D:
	var old := wc.get_node_or_null("PuntoSegundos") as MeshInstance3D
	if old != null:
		return old
	var caja := wc.get_node_or_null("Caja") as MeshInstance3D
	var half := Vector3(0.45, 0.2, 0.025)
	if caja != null and caja.mesh is BoxMesh:
		half = (caja.mesh as BoxMesh).size * 0.5
	var d := Greybox.box(wc, "PuntoSegundos", Vector3(half.x - 0.05, -half.y + 0.05, half.z + 0.004), Vector3(0.022, 0.022, 0.004), Greybox.ROJO, false, 3.0)
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.set_meta("no_merge", true)
	return d


static var _puff_tex: GradientTexture2D = null


## Mancha redonda que se desvanece hacia el borde (una sola textura de 32 px para todas las tazas).
static func _puff() -> GradientTexture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1.0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
		_puff_tex = GradientTexture2D.new()
		_puff_tex.gradient = g
		_puff_tex.fill = GradientTexture2D.FILL_RADIAL
		_puff_tex.fill_from = Vector2(0.5, 0.5)
		_puff_tex.fill_to = Vector2(1.0, 0.5)
		_puff_tex.width = 32
		_puff_tex.height = 32
	return _puff_tex


static func _steam(mug: Node3D) -> CPUParticles3D:
	return steam(mug)


## Vapor de hilos blandos (la taza de C-13, el táper caliente de ManosFx): partículas con una mancha redonda de bordes
## difusos que suben despacio y se deshacen. Queda APAGADO: quien lo pide lo enciende (`emitting`). `speed` > 1 = sube más
## rápido y vive menos (algo recién salido del microondas).
static func steam(parent: Node3D, amount: int = 6, alpha: float = STEAM_ALPHA, size: Vector2 = Vector2(0.055, 0.085), speed: float = 1.0) -> CPUParticles3D:
	var v := CPUParticles3D.new()
	v.name = "Vapor"
	v.amount = amount
	v.lifetime = 2.4 / speed
	v.direction = Vector3.UP
	v.spread = 10.0
	v.gravity = Vector3(0.012, 0.018, 0) * speed
	v.initial_velocity_min = 0.04 * speed
	v.initial_velocity_max = 0.075 * speed
	v.scale_amount_min = 0.6
	v.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(1, 1, 1, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	v.color_ramp = ramp
	var qm := QuadMesh.new()
	qm.size = size
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 1, alpha)
	sm.albedo_texture = _puff()  # hilo de vapor de bordes blandos (un cuadrado liso se veía como bloques)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# con la escala de cada partícula: sin esto el cartel ignora la escala y los hilos que todavía no nacieron (escala 0,
	# color negro) se dibujaban todos juntos como una mancha oscura sobre el emisor durante la primera vida
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	qm.material = sm
	v.mesh = qm
	v.position = Vector3(0, 0.06, 0)
	v.emitting = false
	parent.add_child(v)
	return v


# --- microondas (no se toca su clase: se mira su `state`) ----------------------------------------------------------

func _microwave_tick(cam: Camera3D, delta: float) -> void:
	if _mws.is_empty():
		return
	var cp := cam.global_position
	for id in _mws:
		var rec: Dictionary = _mws[id]
		var n := _n3(rec["n"])
		if n == null or not n.is_inside_tree():
			continue
		var st := str(n.get("state"))
		var running := st == "ocupado" or st == "mio_calentando"
		if st != str(rec["state"]):
			var was := str(rec["state"])
			rec["state"] = st
			# el jugador mete o saca su táper: la puerta de vidrio se abre y se cierra con la mano (ManosFx)
			if st == "mio_calentando" and was != "":
				_mw_door(rec, 0.25, 1.85)
			elif was == "mio_listo" and st == "libre":
				_mw_door(rec, 0.05, 1.2)
		var near := n.global_position.distance_squared_to(cp) < 64.0
		if running and near:
			rec["t"] = float(rec["t"]) + delta
			_mw_visual(rec, true)
		elif rec["run"]:
			_mw_visual(rec, false)


## Encendido: el vidrio se ilumina por dentro (zumbido de la luz) y se ve la sombra del táper girando en el plato.
func _mw_visual(rec: Dictionary, running: bool) -> void:
	var glass := _n3(rec["glass"]) as MeshInstance3D
	if glass == null:
		return
	if not rec.has("mat"):
		if not running:
			return
		rec["mat0"] = glass.material_override
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.06, 0.06)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.72, 0.36)
		m.emission_energy_multiplier = 0.0
		rec["mat"] = m
		var sil := Greybox.box(glass, "SombraPlato", Vector3(0, -0.045, 0.003), Vector3(0.15, 0.06, 0.002), Color(0.03, 0.02, 0.015), false)
		sil.material_override = Greybox.material(Color(0.03, 0.02, 0.015), 0.0, 1.0)
		sil.visible = false
		rec["sil"] = sil
	var mat := rec["mat"] as StandardMaterial3D
	var sil2: Variant = rec["sil"]
	rec["run"] = running
	if not running:
		glass.material_override = rec["mat0"]
		if is_instance_valid(sil2):
			(sil2 as Node3D).visible = false
		return
	glass.material_override = mat
	var t := float(rec["t"])
	mat.emission_energy_multiplier = 0.55 + 0.05 * sin(t * 37.0) + 0.04 * sin(t * 7.3)
	if is_instance_valid(sil2):
		(sil2 as Node3D).visible = not bool(rec.get("door", false))
		# plato a 6 rpm: el táper rectangular se ve ancho y angosto dos veces por vuelta
		var ang := t * TAU / 10.0
		(sil2 as Node3D).scale.x = 0.62 + 0.38 * absf(cos(ang))
		(sil2 as Node3D).position.x = 0.012 * sin(ang)


## La puerta del microondas (copia del vidrio sobre su bisagra izquierda) abre a los `t_open` s y cierra a los
## `t_close` s con su clic; mientras, el vidrio de verdad no se dibuja.
func _mw_door(rec: Dictionary, t_open: float, t_close: float) -> void:
	var glass := _n3(rec["glass"]) as MeshInstance3D
	var n := _n3(rec["n"])
	if glass == null or n == null or not (glass.mesh is BoxMesh):
		return
	var w := (glass.mesh as BoxMesh).size.x
	var pv := n.get_node_or_null("PuertaMwGiro") as Node3D
	if pv == null:
		pv = Node3D.new()
		pv.name = "PuertaMwGiro"
		pv.transform = glass.transform * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, 0, 0))
		n.add_child(pv)
		var g := MeshInstance3D.new()
		g.name = "PuertaMw"
		g.mesh = glass.mesh
		g.transform = Transform3D(Basis.IDENTITY, Vector3(w * 0.5, 0, 0))
		g.material_override = rec.get("mat0", glass.material_override)
		pv.add_child(g)
	var layers: int = rec.get("layers", glass.layers if glass.layers != 0 else 1)
	rec["layers"] = layers
	pv.visible = true
	pv.rotation.y = 0.0
	glass.layers = 0
	rec["door"] = true
	var tw := _tween(n, "oa_mw")
	tw.tween_interval(t_open)
	tw.tween_property(pv, "rotation:y", deg_to_rad(-92.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(t_close - t_open - 0.24, 0.1))
	tw.tween_property(pv, "rotation:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pv, "rotation:y", deg_to_rad(-3.0), 0.04)
	tw.tween_property(pv, "rotation:y", 0.0, 0.06)
	tw.tween_callback(func() -> void: _mw_door_close(rec))


func _mw_door_close(rec: Dictionary) -> void:
	var n: Variant = rec.get("n")
	if not is_instance_valid(n):
		return
	kill_tween(n as Node, "oa_mw")
	rec["door"] = false
	var pv := (n as Node).get_node_or_null("PuertaMwGiro") as Node3D
	if pv != null:
		pv.visible = false
		pv.rotation.y = 0.0
	var glass: Variant = rec.get("glass")
	if is_instance_valid(glass) and rec.has("layers"):
		(glass as MeshInstance3D).layers = int(rec["layers"])

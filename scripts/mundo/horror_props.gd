class_name HorrorProps
extends RefCounted
## Utilería de "daño psicológico" del call center (v0.3 P2, dirección de Joan 13:37): sigue siendo una
## oficina normal, pero todo empuja: tableros de KPI con números rojos, carteles motivacionales que
## cambian cuando no los miras, notas que dejaron agentes quemados, sillas vacías con el headset todavía
## balanceándose, anuncios por los parlantes. Todo es barato (Label3D, cajas sin colisión, un _process
## a pocos Hz) y sin reglas de juego.

const POSTIT := Color(0.86, 0.8, 0.42)
const POSTIT_ROSA := Color(0.82, 0.55, 0.6)
const TINTA := Color(0.12, 0.1, 0.14)


## Nota adhesiva con texto (tr(key)). rot_deg = hacia dónde mira la cara de la nota (Label3D mira a +Z).
static func note(parent: Node, key: String, pos: Vector3, rot_deg: float = 0.0, pink: bool = false, tilt_deg: float = 0.0) -> MeshInstance3D:
	var n := Greybox.box(parent, "Nota_" + key, pos, Vector3(0.11, 0.11, 0.004), POSTIT_ROSA if pink else POSTIT, false)
	n.rotation_degrees = Vector3(0, rot_deg, tilt_deg)
	var l := Greybox.label(n, "", Vector3(0, 0, 0.004), 0.028, TINTA)
	l.text = parent.tr(key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# rc1 (capturas 1080p): con 950 px (0,76 m) el texto salía del pósit de 11 cm y se leía sobre el divisor vecino.
	l.width = 128.0
	l.font_size = 22
	l.outline_size = 0
	return n


## Nota pegada encima de un escritorio (mirando hacia arriba-al frente).
static func desk_note(parent: Node, key: String, pos: Vector3, yaw_deg: float = 0.0, pink: bool = false) -> MeshInstance3D:
	var n := note(parent, key, pos, yaw_deg, pink)
	n.rotation_degrees.x = -70.0
	return n


## Tablero de KPI del equipo con números rojos; la fila "TÚ" se actualiza con tu Available real.
static func kpi_board(parent: Node, pos: Vector3, rot_deg: float, width: float = 3.2) -> Node3D:
	var root := Node3D.new()
	root.name = "TableroKPI"
	root.position = pos
	root.rotation_degrees.y = rot_deg
	parent.add_child(root)
	Greybox.box(root, "Moldura", Vector3.ZERO, Vector3(width + 0.12, 1.32, 0.06), Greybox.NEGRO, false)
	Greybox.box(root, "Pantalla", Vector3(0, 0, 0.032), Vector3(width, 1.2, 0.01), Color(0.02, 0.03, 0.04), false, 0.4)
	var title := Greybox.label(root, "", Vector3(0, 0.47, 0.04), 0.13, Greybox.CIAN)
	title.text = parent.tr("KPI_TITLE")
	var rows: Array = [["KPI_AVAILABLE", "64 %", true], ["KPI_AHT", "9:47", true], ["KPI_CSAT", "2.1 / 5", true], ["KPI_BREAKS", "0", false], ["KPI_ABANDONO", "18 %", true]]
	for i in rows.size():
		var y := 0.25 - i * 0.17
		var k := Greybox.label(root, "", Vector3(-width * 0.5 + 0.15, y, 0.04), 0.09, Color(0.7, 0.75, 0.75))
		k.text = parent.tr(str(rows[i][0]))
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var v := Greybox.label(root, str(rows[i][1]) + ("  ▼" if bool(rows[i][2]) else ""), Vector3(width * 0.5 - 0.15, y, 0.04), 0.1, Greybox.ROJO if bool(rows[i][2]) else Color(0.7, 0.75, 0.75))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var me := Greybox.label(root, "", Vector3(0, -0.53, 0.04), 0.085, Greybox.AMBAR)
	var live := _KpiLive.new()
	live.label = me
	live.name = "Vivo"
	root.add_child(live)
	return root


class _KpiLive extends Node:
	var label: Label3D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or label == null:
			return
		_t = 2.0
		var pct := int(round(Metrics.available_pct())) if Metrics.available_evaluable() else -1
		var who := GameState.agent.to_upper()
		if pct < 0:
			label.text = tr("KPI_ME_PENDING").replace("{agente}", who)
			label.modulate = Greybox.AMBAR
		else:
			label.text = tr("KPI_ME").replace("{agente}", who).replace("{pct}", str(pct))
			label.modulate = Greybox.ROJO if pct < 70 else Greybox.AMBAR


## Cartel motivacional enmarcado que cambia de texto cuando no lo miras (y la presión es alta, o a partir
## del T2). Cara visible hacia +Z local (rot_deg la orienta).
static func sinister_poster(parent: Node, key_normal: String, key_dark: String, pos: Vector3, rot_deg: float, size: float = 0.22, width: float = 2.0) -> Node3D:
	var frame := Greybox.box(parent, "Cartel_" + key_normal, pos, Vector3(width + 0.15, 0.9, 0.04), Greybox.NEGRO, false)
	frame.rotation_degrees.y = rot_deg
	Greybox.box(frame, "Fondo", Vector3(0, 0, 0.012), Vector3(width, 0.75, 0.02), Color(0.08, 0.17, 0.17), false)
	var l := Greybox.label(frame, "", Vector3(0, 0, 0.03), size, Greybox.CIAN)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = width / l.pixel_size * 0.92
	var sw := _PosterSwap.new()
	sw.name = "Cambia"
	sw.label = l
	sw.normal = parent.tr(key_normal)
	sw.dark = parent.tr(key_dark)
	l.text = sw.normal
	frame.add_child(sw)
	return frame


class _PosterSwap extends Node:
	var label: Label3D = null
	var normal: String = ""
	var dark: String = ""
	var _t: float = 0.0
	var _is_dark: bool = false

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or label == null:
			return
		_t = 0.5
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var to_poster := label.global_position - cam.global_position
		var facing := (-cam.global_transform.basis.z).dot(to_poster.normalized())
		if facing > 0.35 and to_poster.length() < 14.0:
			return  # lo estás mirando: nunca cambia delante de ti
		var want_dark := Dread.level() > 0.45 or (GameState.turno >= 2 and randf() < 0.3)
		if want_dark != _is_dark and randf() < 0.5:
			_is_dark = want_dark
			label.text = dark if _is_dark else normal
			label.modulate = Color(0.75, 0.2, 0.18) if _is_dark else Greybox.CIAN


## Silla vacía girada con el headset colgando del monitor, todavía balanceándose.
static func abandoned_seat(cubicle: Node3D, swing: bool = true) -> void:
	var chair := cubicle.get_node_or_null("Silla") as Node3D
	var back := cubicle.get_node_or_null("Respaldo") as Node3D
	if chair != null:
		chair.rotation_degrees.y = 28.0
		chair.position += Vector3(0.18, 0, 0.12)
	if back != null:
		back.rotation_degrees.y = 28.0
		back.position += Vector3(0.28, 0, 0.0)
	var pivot := Node3D.new()
	pivot.name = "HeadsetPivote"
	pivot.position = Vector3(0.22, 1.28, -0.43)
	cubicle.add_child(pivot)
	Greybox.box(pivot, "Cable", Vector3(0, -0.2, 0), Vector3(0.008, 0.4, 0.008), Greybox.NEGRO, false)
	Greybox.box(pivot, "Diadema", Vector3(0, -0.42, 0.02), Vector3(0.16, 0.03, 0.03), Greybox.GRIS_OSCURO, false)
	Greybox.box(pivot, "Auricular", Vector3(0.08, -0.47, 0.02), Vector3(0.05, 0.07, 0.07), Greybox.NEGRO, false)
	Greybox.box(pivot, "Microfono", Vector3(-0.06, -0.5, 0.06), Vector3(0.012, 0.012, 0.12), Greybox.GRIS_OSCURO, false)
	if swing:
		var s := _Swing.new()
		s.name = "Balanceo"
		s.target = pivot
		cubicle.add_child(s)


class _Swing extends Node:
	var target: Node3D = null
	var _t: float = 0.0
	var _phase: float = 0.0

	func _ready() -> void:
		_phase = randf() * TAU

	func _process(delta: float) -> void:
		if target == null:
			return
		# Lento y amortiguado, como si alguien acabara de levantarse... y nunca se detiene del todo.
		_t += delta
		target.rotation.x = sin(_t * 1.9 + _phase) * (0.12 + 0.05 * sin(_t * 0.23))
		target.rotation.z = sin(_t * 1.3 + _phase * 0.5) * 0.04

## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.1 Q5 · mundo del site y Modo liviano (PLAN §3 Q5, contratos C8, C15, C16):
## - q5_dormir_despertar: en CADA lugar para dormir de todos los pisos: dormir, despertar y caminar 1 m en las 4
##   direcciones (bug de Joan 11:19Z: quedaba atrapado dentro del sofá/puff).
## - q5_sillas_levantarse: sillas de training, calibración y C-14: al pararte quedas en piso libre y puedes caminar.
## - q5_azotea_24_7 (B10): la puerta del deck abre antes del login, en Available y en Break, y desde el deck.
## - q5_konzentramance (D1): letrero de la fachada con la grafía nueva.
## - q5_props_anclas (D4/D5): 2 refris inox en el -1 y 2 en el piso 2 (grupo "refris"), 6 microondas en 2 filas de 3
##   con display y anclas, lavadero; anclas en piso libre.
## - q5_superficies (C15): zonas `exterior` y `vinilico` donde van.
## - q5_topico (D6): el tópico al final del pasillo de training con banqueta; el marcador conserva las convenciones.
## - q5_ventilacion: la frontera del siseo está en el molinete del piso 2 (el hall no está en ninguna zona).
## - q5_salto_sin_fugas (C16): desde la altura de un salto (0,5 m) contra molinetes, barandas y bordes, nadie cruza.
## - q5_ingreso_hundido: se BAJA de la calle al lobby (≈2,1 m) andando por la escalera.
## - q5_liviano: el 4.º nivel de calidad (escala, luces, materiales, lluvia) y la vuelta a Media; en escritorio el
##   nivel por defecto sigue siendo Media.


func escenarios() -> Array[String]:
	return ["q5_dormir_despertar", "q5_sillas_levantarse", "q5_azotea_24_7", "q5_konzentramance", "q5_props_anclas", "q5_superficies", "q5_topico", "q5_ventilacion", "q5_salto_sin_fugas", "q5_ingreso_hundido", "q5_liviano"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"q5_dormir_despertar": await _dormir(t)
		"q5_sillas_levantarse": await _sillas(t)
		"q5_azotea_24_7": await _azotea(t)
		"q5_konzentramance": await _konzentramance(t)
		"q5_props_anclas": await _anclas(t)
		"q5_superficies": await _superficies(t)
		"q5_topico": await _topico(t)
		"q5_ventilacion": await _ventilacion(t)
		"q5_salto_sin_fugas": await _salto(t)
		"q5_ingreso_hundido": await _ingreso(t)
		"q5_liviano": await _liviano(t)


# --- utilidades -----------------------------------------------------------------------------------

func _floor(t: Node) -> FloorBase:
	return t.building().floor_node as FloorBase


func _go(t: Node, f: int, spawn: String = "ascensor") -> void:
	if t.player().seated:
		t.player().stand_up()
	t.building().go_to_floor(f, spawn)
	await t.frames(4)


## Camina con el controlador real hacia yaw_deg hasta avanzar `dist` (en planta) o agotar `max_s`. Devuelve lo avanzado.
func _walk(t: Node, yaw_deg: float, dist: float = 1.0, max_s: float = 3.0) -> float:
	var p: Player = t.player()
	var start := p.global_position
	p.rotation.y = deg_to_rad(yaw_deg)
	Input.action_press("move_forward")
	var left := max_s
	var moved := 0.0
	while left > 0.0:
		await t.get_tree().physics_frame
		left -= t.get_physics_process_delta_time()
		moved = Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
		if moved >= dist:
			break
	Input.action_release("move_forward")
	await t.frames(2)
	return moved


## ¿Cabe la cápsula del jugador parada en p (piso en p.y ± 0,35)?
func _free(t: Node, p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = t.player().get_world_3d().direct_space_state
	var ex: Array[RID] = [t.player().get_rid()]
	var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, -0.6, 0), 1, ex)
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return false
	var fy := float((hit["position"] as Vector3).y)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	q.exclude = ex
	q.transform = Transform3D(Basis(), Vector3(p.x, fy + 0.95, p.z))
	return space.intersect_shape(q, 1).is_empty()


# --- pruebas --------------------------------------------------------------------------------------

func _dormir(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Jiroshi", 1)
	var total := 0
	for f in [-1, 1, 2, 9]:
		await _go(t, f)
		var spots: Array = []
		for n in _floor(t).find_children("Dormir_*", "", true, false):
			if n is SleepSpot:
				spots.append(n)
		if f == -1:
			t.check(spots.size() >= 6, "el -1 tiene los 2 sofás y los 4 puffs (%d)" % spots.size())
		for sp in spots:
			var s := sp as SleepSpot
			total += 1
			t.check(s.exit_marker() != null, "%s tiene ancla de salida" % s.spot_id)
			var p: Player = t.player()
			p.teleport(s.global_position + Vector3(0, -s.global_position.y + (s.get_parent() as Node3D).global_position.y + 0.05, 0) + Vector3(0.0, 0, 1.2), 0.0)
			await t.frames(2)
			t.check(s.interact(p), "%s: me acuesto" % s.spot_id)
			await t.seconds(0.6)
			t.check(p.lying and SleepSpot.sleeping_spot() == s.spot_id, "%s: estoy dormido" % s.spot_id)
			s.wake_up()
			await t.frames(3)
			var at := p.global_position
			t.check(not p.lying and _free(t, at), "%s: al despertar quedo en piso libre (%.2f, %.2f, %.2f)" % [s.spot_id, at.x, at.y, at.z])
			var ok_dirs := 0
			var detail: Array[String] = []
			for k in 4:
				p.teleport(at, 0.0)
				await t.frames(2)
				var yaw := k * 90.0
				var moved := await _walk(t, yaw, 1.0, 3.0)
				detail.append("%d°: %.2f m" % [int(yaw), moved])
				if moved >= 0.95:
					ok_dirs += 1
			t.check(ok_dirs == 4, "%s: camino 1 m en las 4 direcciones (%s)" % [s.spot_id, ", ".join(detail)])
	t.check(total >= 6, "lugares para dormir probados: %d" % total)


func _sillas(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Jiroshi", 2)
	var cases := {1: ["training_sala2_3"], 2: ["calibracion", "C-14", "E-07"]}
	for f in cases.keys():
		await _go(t, int(f))
		for id in cases[f]:
			var seat := _floor(t).find_child("Seat_" + str(id), true, false) as WorldObjects.Seat
			if not t.check(seat != null, "existe la silla %s" % id):
				continue
			var p: Player = t.player()
			p.sit_at(seat, str(id))
			await t.frames(3)
			p.stand_up()
			await t.frames(3)
			var at := p.global_position
			t.check(_free(t, at), "%s: al pararte quedas en piso libre (%.2f, %.2f)" % [id, at.x, at.z])
			var ok_dirs := 0
			for k in 4:
				p.teleport(at, 0.0)
				await t.frames(2)
				if await _walk(t, k * 90.0, 0.6, 2.0) >= 0.55:
					ok_dirs += 1
			t.check(ok_dirs >= 2, "%s: te puedes ir caminando (%d de 4 direcciones)" % [id, ok_dirs])


func _azotea(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	GameState.flags.erase("azotea_abierta_dev")
	await _go(t, 9)
	var door := _floor(t).find_child("PuertaAzotea", true, false) as WorldObjects.Door
	t.player().teleport(_floor(t).global_position + Vector3(0, 0, 0.8), 180.0)
	await t.frames(2)
	t.check(door != null and not GameState.logged_in and door.interact(t.player()) and door.open, "antes del login la puerta del deck abre")
	door.set_open(false)
	await t.login_at_seat()
	t.player().stand_up()
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _go(t, 9)
	door = _floor(t).find_child("PuertaAzotea", true, false) as WorldObjects.Door
	t.player().teleport(_floor(t).global_position + Vector3(0, 0, 0.8), 180.0)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "en Available abre (sin AUX válido cuentas como fuera de la sala)")
	door.set_open(false)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "en Break abre")
	door.set_open(false)
	t.player().teleport(_floor(t).global_position + Vector3(0, 0, 3.2), 0.0)
	await t.frames(2)
	t.check(door.interact(t.player()) and door.open, "desde el deck abre")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)


func _konzentramance(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _go(t, -1, "calle")
	var word := ""
	for i in 14:
		var l := _floor(t).find_child("Letra%d" % i, true, false) as Label3D
		if l != null:
			word += l.text
	t.check(word == "KONZENTRAMANCE", "letras de la fachada: %s" % word)
	var dintel := _floor(t).find_child("NombreDintel", true, false) as Label3D
	t.check(dintel != null and dintel.text.begins_with("KONZENTRAMANCE"), "dintel: %s" % (dintel.text if dintel != null else "-"))
	var src := FileAccess.get_file_as_string("res://scripts/niveles/floor_m1.gd").to_lower()
	t.check(not src.contains("konzentri" + "mance"), "floor_m1.gd sin la grafía vieja")


func _anclas(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _go(t, -1)
	var fl := _floor(t)
	var refris := 0
	var mws: Array = []
	for n in fl.find_children("*", "", true, false):
		if n.is_in_group("refris"):
			refris += 1
		if n.is_in_group("microondas"):
			mws.append(n)
	t.check(refris == 2, "2 refris inox en el -1 (%d)" % refris)
	t.check(mws.size() == 6, "6 microondas en el -1 (%d)" % mws.size())
	var rows := {0: 0, 1: 0}
	for m in mws:
		var mw := m as Node3D
		rows[int(mw.get_meta("fila", -1))] = int(rows.get(int(mw.get_meta("fila", -1)), 0)) + 1
		t.check(mw is WorldObjects.Microwave and mw.get_node_or_null("Reloj") is Label3D and mw.get_node_or_null("Interior") is MeshInstance3D, "%s: microondas con display e interior" % mw.name)
	t.check(int(rows[0]) == 3 and int(rows[1]) == 3, "2 filas de 3 (%s)" % str(rows))
	var hi := INF
	var lo := -INF
	for m in mws:
		hi = minf(hi, (m as Node3D).global_position.y)
		lo = maxf(lo, (m as Node3D).global_position.y)
	t.check(lo - hi > 0.3, "apilados: fila de arriba %.2f m sobre la de abajo" % (lo - hi))
	t.check(fl.find_child("Microondas", true, false) is WorldObjects.Microwave, "el primero conserva el nombre «Microondas» (bots y recorrido)")
	t.check(fl.find_child("Lavadero", true, false) != null and fl.find_child("Lavadero", true, false).is_in_group("lavaderos"), "lavadero en la cafetería")
	for n in fl.find_children("Ancla", "Marker3D", true, false):
		var a := n as Marker3D
		t.check(_free(t, a.global_position), "ancla de %s en piso libre (%.2f, %.2f)" % [a.get_parent().name, a.global_position.x, a.global_position.z])
	for mk in ["refri_m1", "microondas_m1", "lavadero_m1"]:
		t.check(fl.find_child(mk, true, false) is Marker3D, "marcador %s" % mk)
	await _go(t, 2)
	fl = _floor(t)
	for nm in ["Refri1", "Refri2"]:
		var r := fl.find_child(nm, true, false)
		t.check(r is WorldObjects.Fridge and r.is_in_group("refris"), "%s (piso 2) es una refri interactiva del grupo" % nm)
	var lk := fl.find_child("MiCasillero", true, false)
	t.check(lk is WorldObjects.Locker and lk.get_node_or_null("Ancla") is Marker3D, "casillero con ancla")
	for mk in ["escritorio_shero", "escritorio_rasec", "escritorio_rta"]:
		t.check(fl.find_child(mk, true, false) is Marker3D, "marcador %s (C8)" % mk)


func _zone_at(fl: Node, id: String, p: Vector3) -> bool:
	for z in fl.find_children("*", "Area3D", true, false):
		if z is Zone and (z as Zone).zone_id == id:
			var zn := z as Zone
			var lp := zn.global_transform.affine_inverse() * p
			var h := zn.size * 0.5
			if absf(lp.x) <= h.x and absf(lp.y) <= h.y and absf(lp.z) <= h.z:
				return true
	return false


func _superficies(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _go(t, -1)
	var fl := _floor(t)
	t.check(_zone_at(fl, "exterior", Vector3(0, 3.0, 24)), "-1: la vereda es `exterior`")
	t.check(_zone_at(fl, "exterior", Vector3(0, 1.0, 16)), "-1: el patio hundido es `exterior`")
	t.check(not _zone_at(fl, "exterior", Vector3(0, 1.0, 9)), "-1: el lobby no es `exterior`")
	t.check(_zone_at(fl, "vinilico", Vector3(0, 1.0, -11.8)), "-1: la cafetería es `vinilico`")
	await _go(t, 1)
	fl = _floor(t)
	t.check(_zone_at(fl, "vinilico", Vector3(7.1, 1.0, 3.0)), "1: el pasillo de training es `vinilico`")
	t.check(not _zone_at(fl, "vinilico", Vector3(-3, 1.0, 0)), "1: el hall de ascensores no (porcelanato)")
	await _go(t, 2)
	fl = _floor(t)
	t.check(_zone_at(fl, "vinilico", Vector3(0.5, 1.0, -5.0)), "2: casilleros `vinilico`")
	t.check(_zone_at(fl, "vinilico", Vector3(1.0, 1.0, -12.5)), "2: pantry `vinilico`")
	t.check(not _zone_at(fl, "vinilico", Vector3(9.0, 1.0, 0.0)), "2: el hall de ascensores no (porcelanato)")
	t.check(_zone_at(fl, "sala", Vector3(30, 1.0, -6)), "2: la sala sigue siendo `sala`")


func _topico(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await _go(t, 1)
	var fl := _floor(t)
	var m := fl.find_child("topico", true, false) as Marker3D
	t.check(m != null, "marcador topico")
	t.check(_zone_at(fl, "topico", m.global_position + Vector3(0, 1.0, 0)), "el marcador está dentro de la zona topico")
	# v0.3.1 pisos: el bot entra 0,6 m hacia donde mira el marcador y el enfermero te saca 3 m por detrás (su eje z).
	var fwd := -m.global_transform.basis.z
	t.check(_zone_at(fl, "topico", m.global_position + fwd * 0.6 + Vector3(0, 1.0, 0)) and _free(t, m.global_position + fwd * 0.6), "m + 0,6 hacia adentro (donde el bot entra) es dentro y libre")
	t.check(not _zone_at(fl, "topico", m.global_position - fwd * 3.0 + Vector3(0, 1.0, 0)) and _free(t, m.global_position - fwd * 3.0), "m − 3 hacia afuera (donde te saca el enfermero) es fuera y libre")
	var hall_door := fl.find_child("Topico", true, false) as Node3D
	t.check(m.global_position.x - 6.0 > 6.0, "al final del recodo, a más de 6 m de la puerta del hall (x %.1f)" % m.global_position.x)
	t.check(hall_door != null and absf(hall_door.global_position.x - 12.5) < 0.3, "puerta blanca del tópico al final del recodo")
	var door := fl.find_child("Topico", true, false) as WorldObjects.Door
	t.check(door != null and not door.locked, "en T2 la puerta abre")
	t.check(fl.find_child("BanquetaEspera", true, false) != null and fl.find_child("ExtintorTopico", true, false) != null and fl.find_child("PapeleraTopico", true, false) != null, "banqueta de espera, extintor y papelera")
	t.check(fl.find_child("Enfermera", true, false) != null or fl.find_child("Enfermero", true, false) != null, "enfermera/o")
	t.check(fl.find_child("SalidaFinal", true, false) != null, "cartel SALIDA al final del pasillo")
	# Se llega andando desde el ascensor.
	var g := Pursuit.grid_for(fl)
	var path: PackedVector3Array = g.find_path(fl.find_child("ascensor", true, false).global_position, m.global_position)
	t.check(path.size() >= 2 and path[path.size() - 1].distance_to(m.global_position) < 0.6, "ruta del ascensor al tópico (%d puntos)" % path.size())


func _ventilacion(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _go(t, 2)
	var fl := _floor(t)
	var any_vent := func(p: Vector3) -> bool:
		for z in fl.find_children("Zone_ventilacion*", "", true, false):
			if z is Zone and _zone_at(fl, (z as Zone).zone_id, p):
				return true
		return false
	t.check(not any_vent.call(Vector3(9.0, 1.0, 0)), "el hall de ascensores está en silencio")
	t.check(not any_vent.call(Vector3(3.2, 1.0, 0)), "antes del molinete, silencio")
	t.check(any_vent.call(Vector3(1.6, 1.0, 0)), "pasando el molinete empieza el siseo")
	for p in [Vector3(0.5, 1, -6), Vector3(1, 1, -12.5), Vector3(-5, 1, -12), Vector3(10, 1, 5.5), Vector3(18.75, 1, 2.6), Vector3(11, 1, -15), Vector3(30, 1, -8)]:
		t.check(any_vent.call(p), "siseo en (%.1f, %.1f)" % [p.x, p.z])
	t.check(not any_vent.call(Vector3(3.3, 1.0, -17.0)), "el baño está en silencio")
	var mol := fl.find_child("MolineteP2", true, false) as Node3D
	t.check(mol != null and absf(mol.global_position.x - 2.6) < 0.3 and absf(mol.global_position.z) < 1.5, "molinete entre el hall y los casilleros")


## Probe del salto (C16): el jugador arranca a la altura del pico de un salto (0,5 m sobre el piso) a 0,7 m del obstáculo
## y empuja hacia él 1,2 s; no debe quedar del otro lado.
func _probe(t: Node, from: Vector3, yaw_deg: float, label: String, axis: Vector3, limit: float) -> void:
	var p: Player = t.player()
	p.teleport(from + Vector3(0, 0.5, 0), yaw_deg)
	await t.frames(1)
	await _walk(t, yaw_deg, 3.0, 1.2)
	var crossed := (p.global_position - from).dot(axis) > limit
	t.check(not crossed, "salto: %s no se cruza (%.2f, %.2f, %.2f)" % [label, p.global_position.x, p.global_position.y, p.global_position.z])


func _salto(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Jiroshi", 1)
	await _go(t, -1)
	# Molinetes del lobby: desde el lado de la calle contra los gabinetes y la barrera de vidrio (z 6).
	for x in [-1.625, -0.375, 0.875, 2.125, -4.0, 5.0]:
		await _probe(t, Vector3(x, 0, 6.8), 0.0, "molinete/barrera del lobby en x %.1f" % x, Vector3(0, 0, -1), 1.1)
	# Barandas del pozo (desde la vereda) y los costados de la escalera de ingreso.
	await _probe(t, Vector3(-7.0, 2.1, 17.0), -90.0, "baranda oeste del pozo", Vector3(1, 0, 0), 1.0)
	await _probe(t, Vector3(7.0, 2.1, 17.0), 90.0, "baranda este del pozo", Vector3(-1, 0, 0), 1.0)
	await _probe(t, Vector3(-4.6, 2.1, 22.2), 0.0, "borde frontal del pozo", Vector3(0, 0, -1), 0.9)
	await _probe(t, Vector3(-1.6, 1.2, 20.0), -90.0, "costado de la escalera de ingreso", Vector3(1, 0, 0), 2.1)
	await _probe(t, Vector3(0, 2.1, 30.0), 180.0, "fin de la pista", Vector3(0, 0, 1), 3.4)
	await _go(t, 2)
	await _probe(t, Vector3(3.4, 0, -1.3), 90.0, "molinete del piso 2 (tramo cerrado)", Vector3(-1, 0, 0), 1.6)
	await _probe(t, Vector3(2.6, 0, -0.45), 180.0, "gabinete del molinete del piso 2 (de carril a carril)", Vector3(0, 0, 1), 0.95)
	await _probe(t, Vector3(46.8, 0, -14.0), -90.0, "ventanas del piso 2", Vector3(1, 0, 0), 1.4)
	await _go(t, 9)
	GameState.flags["azotea_abierta_dev"] = true
	await _probe(t, Vector3(0, 0, 19.0), 180.0, "parapeto de la azotea", Vector3(0, 0, 1), 1.2)
	await _probe(t, Vector3(9.2, 0, 11.0), -90.0, "parapeto este de la azotea", Vector3(1, 0, 0), 1.0)
	t.check(t.player().fall_rescues == 0, "0 rescates de la red de seguridad (%d)" % t.player().fall_rescues)


func _ingreso(t: Node) -> void:
	Engine.time_scale = 2.0
	await t.start_shift("Jiroshi", 1)
	await _go(t, -1, "calle")
	var p: Player = t.player()
	var y0 := p.global_position.y
	t.check(y0 > 1.9, "la calle está arriba (y %.2f)" % y0)
	p.teleport(Vector3(-1.6, y0 + 0.05, 23.0), 0.0)
	await t.frames(2)
	var moved := await _walk(t, 0.0, 9.0, 9.0)
	t.check(p.global_position.z < 15.0 and absf(p.global_position.y) < 0.2, "bajando por la escalera llego al patio (%.2f, %.2f, %.2f; %.1f m)" % [p.global_position.x, p.global_position.y, p.global_position.z, moved])
	moved = await _walk(t, 180.0, 9.0, 9.0)
	t.check(p.global_position.y > 1.9, "y vuelvo a subir a la vereda (y %.2f)" % p.global_position.y)
	t.check(p.fall_rescues == 0, "sin caídas")


func _liviano(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	t.check(OS.has_feature("web") or GfxQuality.default_level() == "media", "en escritorio la calidad por defecto sigue siendo Media")
	var prev := GfxQuality.level()
	await _go(t, 2, "pc")
	GfxQuality.apply(t.get_tree(), "liviano")
	await t.seconds(0.8)
	var vp: Viewport = t.get_tree().root
	t.check(vp.scaling_3d_scale <= 0.5 + 0.001, "3D al 50 %% o menos (%.2f)" % vp.scaling_3d_scale)
	t.check(Engine.max_fps == 30, "30 fps máx.")
	var on := 0
	var shadows := 0
	for l in t.get_tree().root.find_children("*", "Light3D", true, false):
		var lt := l as Light3D
		if lt.visible and lt.is_visible_in_tree() and lt.light_energy > 0.0 and not (lt is DirectionalLight3D) and not lt.has_meta("budget_keep"):
			on += 1
		if lt.shadow_enabled:
			shadows += 1
	t.check(on <= GfxQuality.LIGHT_BUDGET, "luces encendidas en la sala: %d (máx. %d)" % [on, GfxQuality.LIGHT_BUDGET])
	t.check(shadows == 0, "sin sombras (%d)" % shadows)
	t.check(Greybox.surf("sala_gris").albedo_texture == null, "materiales planos")
	t.check(Weather.drop_count() <= 150, "lluvia a ¼ (%d gotas)" % Weather.drop_count())
	t.check(GfxQuality.is_low(), "los sistemas de Baja también se abaratan en liviano")
	var cm := t.get_tree().root.find_children("*", "MeshInstance3D", true, false)
	var ranged := 0
	for n in cm:
		if (n as MeshInstance3D).visibility_range_end > 0.0:
			ranged += 1
	t.check(ranged > 100, "utilería chica con distancia de dibujado (%d)" % ranged)
	var lotes: Node = t.building().floor_node.get_node_or_null("GfxLotes")
	var rep := GfxQuality.merge_report(t.building().floor_node)
	t.note("lotes: " + str(rep))
	t.check(lotes != null and lotes.get_child_count() > 10, "geometría quieta fundida en lotes (%s)" % str(rep))
	GfxQuality.apply(t.get_tree(), "media")
	await t.seconds(0.4)
	var off := 0
	for l in t.get_tree().root.find_children("*", "Light3D", true, false):
		if (l as Light3D).has_meta("budget_off"):
			off += 1
	t.check(off == 0 and vp.scaling_3d_scale == 1.0, "al volver a Media se restauran las luces y la escala")
	t.check(Greybox.surf("sala_gris").albedo_texture != null, "y las texturas")
	GfxQuality.apply(t.get_tree(), prev)

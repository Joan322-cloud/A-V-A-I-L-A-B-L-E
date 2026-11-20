## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P6b · pulido (PLAN §10 P6b): la zona de huddle del evento de Rasec no pisa ninguna silla, Rasec
## se ve desde C-14, los carteles se leen bien de los dos lados (o solo de uno, en las puertas), los motivos de
## muerte sin detalle no dejan puntuación suelta, "[E] Levantarse" no sale en una sesión bloqueada, el KPI
## "Feedback QA n/3" del Fonex, el C-17 que se enciende a la segunda mirada, sin REC de Haime en la Inducción
## y la versión 0.3.0 en el menú y en los presets de exportación.


func escenarios() -> Array[String]:
	return ["p6b_huddle_rasec", "p6b_carteles", "p6b_causas_texto", "p6b_levantarse_bloqueado", "p6b_fonex_qa",
		"p6b_c17", "p6b_rec_induccion", "p6b_version"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p6b_huddle_rasec": await _huddle(t)
		"p6b_carteles": await _carteles(t)
		"p6b_causas_texto": await _causas(t)
		"p6b_levantarse_bloqueado": await _levantarse(t)
		"p6b_fonex_qa": await _fonex_qa(t)
		"p6b_c17": await _c17(t)
		"p6b_rec_induccion": await _rec(t)
		"p6b_version": await _version(t)


func _floor(t: Node, n: int) -> FloorBase:
	var b: Building = t.building()
	if b.current_floor != n:
		b.go_to_floor(n, "ascensor")
		await t.frames(6)
	return b.floor_node as FloorBase


func _seats(fl: Node) -> Array:
	var out: Array = []
	for n in fl.find_children("*", "", true, false):
		if n is WorldObjects.Seat:
			out.append(n)
	return out


func _huddle(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	var fl := await _floor(t, 2)
	var m := fl.find_child("evento_rasec", true, false) as Node3D
	t.check(m != null, "existe el marcador evento_rasec")
	if m == null:
		return
	for id in ["D-07", "D-08", "D-09", "D-10"]:
		t.check(fl.seat_by_id(id) == null, "%s ya no existe (zona de huddle)" % id)
	t.check(fl.find_child("HuddleAlfombra", true, false) != null, "la zona de huddle tiene su alfombra")
	# Ningún cubículo (silla ni escritorio) dentro del círculo del evento: personas a 2,2 × 1,3 m, sillas a 1,3 × 1,1 m.
	var near := INF
	var who := ""
	for s in _seats(fl):
		var cub := (s as Node3D).get_parent() as Node3D
		var d := Vector2(cub.global_position.x - m.global_position.x, cub.global_position.z - m.global_position.z)
		var r := Vector2(d.x / 2.9, d.y / 2.0).length()  # elipse del evento + medio cubículo
		if r < near:
			near = r
			who = str(s.get("seat_id"))
	t.check(near >= 1.0, "el evento no pisa ningún cubículo (el más cercano, %s, a %.2f de la elipse)" % [who, near])
	# Rasec en su sitio: bajo el reloj (pasillo sur), lejos de las sillas, y se le ve desde C-14 (de pie).
	await t.seconds(0.5)
	var ra: Node = t.main.get_tree().get_first_node_in_group("p5_rasec_actor")
	var actor: Node3D = ra.get("actor") as Node3D if ra != null else null
	t.check(actor != null, "Rasec está en la sala")
	if actor == null:
		return
	var post: Vector3 = actor.global_position
	var min_seat := INF
	for s in _seats(fl):
		min_seat = minf(min_seat, Vector2((s as Node3D).global_position.x - post.x, (s as Node3D).global_position.z - post.z).length())
	t.check(min_seat >= 1.2, "Rasec no está encima de una silla (la más cercana a %.2f m)" % min_seat)
	var c14 := fl.seat_by_id("C-14")
	var eye := c14.global_position + c14.global_transform.basis.z * 0.9 + Vector3(0, 0.8, 0)  # de pie junto a C-14 (1,6 m)
	eye.y = fl.global_position.y + 1.6
	var head := post + Vector3(0, 1.7, 0)
	var space := (fl as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, head)
	q.collide_with_areas = false
	var pl: Player = t.player()
	if pl != null:
		q.exclude = [pl.get_rid()]
	var hit := space.intersect_ray(q)
	var blocker := str((hit.get("collider") as Node).name) if not hit.is_empty() and hit.get("collider") is Node else ""
	var ok_view := hit.is_empty() or (hit.get("position") as Vector3).distance_to(head) < 0.6
	t.check(ok_view, "desde C-14 se ve la cabeza de Rasec (tapa: %s)" % blocker)
	t.check(fl.find_child("LuzRasec", true, false) != null, "Rasec tiene su luz")


func _carteles(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	for n in [-1, 2]:
		var fl := await _floor(t, n)
		var total := 0
		var bad: Array[String] = []
		for l in fl.find_children("*", "Label3D", true, false):
			var lb := l as Label3D
			if lb.has_meta("reverso") or lb.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				continue
			total += 1
			if lb.double_sided:
				bad.append(lb.name)  # doble cara de Godot = texto al revés por detrás
			var back := lb.get_node_or_null("Reverso") as Label3D
			if back != null:
				var z_front := lb.global_transform.basis.z.normalized()
				var z_back := back.global_transform.basis.z.normalized()
				if z_front.dot(z_back) > -0.99 or back.text != lb.text:
					bad.append(str(lb.name) + "(reverso)")
		t.check(bad.is_empty() and total > 10, "piso %d: %d carteles, ninguno se lee al revés por detrás (%s)" % [n, total, ", ".join(bad.slice(0, 6))])
		for key in ["SIGN_BATHROOM"] + (["SIGN_LOCKER", "P6B_HUDDLE"] if n == 2 else []):
			var faces := 0
			var dirs: Array[Vector3] = []
			for l in fl.find_children("*", "Label3D", true, false):
				if (l as Label3D).text == Loc.tr(key) and not l.has_meta("reverso"):
					faces += 1
					dirs.append((l as Node3D).global_transform.basis.z)
			t.check(faces >= 1, "piso %d: hay cartel %s" % [n, key])
			if key == "P6B_HUDDLE":
				t.check(faces == 2 and dirs[0].dot(dirs[1]) < -0.99, "el cartel colgado del huddle tiene una cara por lado")
	# Cartel suelto de dos lados (opcional): el reverso sigue al cartel cuando cambia.
	var fl2 := await _floor(t, 2)
	var probe := Greybox.two_sided(Greybox.label(fl2, "HOLA", Vector3(30, 2, 0), 0.2))
	probe.text = "ADIOS"
	probe.modulate = Color(1, 0, 0)
	await t.frames(2)
	var rb := probe.get_node("Reverso") as Label3D
	t.check(rb.text == "ADIOS" and rb.modulate == Color(1, 0, 0) and rb.global_transform.basis.z.dot(probe.global_transform.basis.z) < -0.99, "two_sided: el reverso mira al otro lado y copia texto y color")
	probe.queue_free()


func _causas(t: Node) -> void:
	var bad: Array[String] = []
	var n := 0
	for c in DataLoader.list("muertes"):
		var id := str(c.get("id", ""))
		for lang in ["es", "en"]:
			TranslationServer.set_locale(lang)
			var txt := Checkpoints.cause_text(id, "")
			n += 1
			if txt.strip_edges() == "" or txt.ends_with(":") or txt.contains(":.") or txt.contains("()") or txt.contains("  ") or txt.contains("{") or txt.ends_with(" ·") or txt.ends_with("("):
				bad.append("%s/%s «%s»" % [id, lang, txt])
			var con_det := Checkpoints.cause_text(id, "02:31")
			if con_det.contains("{"):
				bad.append("%s/%s con detalle «%s»" % [id, lang, con_det])
	TranslationServer.set_locale("es")
	t.check(bad.is_empty(), "%d motivos sin puntuación suelta %s" % [n, str(bad.slice(0, 5))])
	t.check(Checkpoints.cause_text("break_excedido", "") != "" and not Checkpoints.cause_text("break_excedido", "").ends_with(":"), "«Break excedido» sin dos puntos: «%s»" % Checkpoints.cause_text("break_excedido", ""))
	for extra in ["correo", "kyc", "induccion"]:
		var tx := Checkpoints.cause_text(extra, "")
		t.check(tx != extra and not tx.begins_with("CAUSE_"), "motivo de WW «%s» traducido: «%s»" % [extra, tx])


func _levantarse(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var hints: Array = []
	var cb := func(txt: String) -> void: hints.append(txt)
	EventBus.interact_hint.connect(cb)
	var p: Player = t.player()
	p.head.rotation.x = 1.2  # mira al techo: nada interactuable delante
	await t.frames(4)
	t.check(str(p.get("_last_hint")) == Loc.tr("HUD_STAND"), "sentado y libre: «%s»" % str(p.get("_last_hint")))
	p.input_locked = true  # feedback / training / quiz / evento
	await t.frames(4)
	t.check(not hints.is_empty() and hints[-1] == "" and str(p.get("_last_hint")) == "", "sesión bloqueada: no sale «[E] Levantarse»")
	p.input_locked = false
	await t.frames(4)
	t.check(hints[-1] == Loc.tr("HUD_STAND"), "al terminar la sesión vuelve la pista")
	EventBus.interact_hint.disconnect(cb)
	# Un turno nuevo no hereda la pista del jugador anterior.
	EventBus.interact_hint.connect(cb)
	hints.clear()
	await t.start_shift("Jiroshi", 1)
	await t.frames(3)
	t.check(hints.has(""), "al empezar un turno se limpia la pista del HUD")
	EventBus.interact_hint.disconnect(cb)


func _fonex_qa(t: Node) -> void:
	await t.start_shift("Marko", 2)
	PersonajesP5.set_counter("p5_qa_feedbacks", 1)
	var txt := PcFonex.kpi_bbcode()
	# v0.3.1 (D2): en Normal son 4 (el 4.º es el último); en rojo desde el que anticipa la advertencia.
	t.check(txt.contains(Loc.tr("P6B_KPI_QA") + " 1/4"), "Fonex muestra «%s 1/4»" % Loc.tr("P6B_KPI_QA"))
	PersonajesP5.set_counter("p5_qa_feedbacks", 2)
	t.check(PcFonex.kpi_bbcode().contains("#e5241f]%s 2/4" % Loc.tr("P6B_KPI_QA")), "con 2/4 va en rojo (la próxima es la advertencia)")
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)


func _c17(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	var fl := await _floor(t, 2)
	Metrics.breaks_used = 1
	fl.call("debug_show_c17", false)
	var g := fl.find_child("SitioFantasma", true, false) as Node3D
	var brain := fl.find_child("Fantasma", true, false)
	t.check(g != null and g.visible and brain != null, "el C-17 aparece")
	if g == null or brain == null:
		return
	var p: Player = t.player()
	var stand := Vector3(36.5, fl.global_position.y, 0.0)  # franja norte, a 6 m del C-17
	var d := g.global_position - stand
	var yaw := atan2(-d.x, -d.z)
	p.teleport(stand, rad_to_deg(yaw))  # lo mira
	p.head.rotation.x = 0.0
	await t.seconds(0.5)
	p.rotation.y = yaw + PI  # aparta la vista
	await t.seconds(0.5)
	p.rotation.y = yaw  # segunda mirada
	await t.seconds(0.6)
	t.check(bool(brain.get("revealed")), "a la segunda mirada se enciende (miradas: %d)" % int(brain.get("looks")))
	var lamp := brain.get("lamp") as OmniLight3D
	await t.seconds(1.8)
	t.check(lamp != null and lamp.light_energy > 0.5, "su fluorescente se prende encima")
	var info := brain.get("info") as Label3D
	t.check(info != null and info.text.contains(GameState.agent), "la pantalla dice tu nombre: «%s»" % (info.text if info != null else ""))
	await t.seconds(5.0)
	t.check(not g.visible, "a los 6 s desaparece")


func _rec(t: Node) -> void:
	var tut: Node = t.main.call("_start_tutorial", ["contactos"])
	await t.seconds(1.0)
	t.check(GameState.is_tutorial() and GameState.turno == 0, "la inducción es el turno 0")
	var hub := PersonajesP5.get_hub(t.main.get_tree())
	if hub != null and hub.qa != null:
		for i in 3:
			EventBus.contact_accepted.emit({"id": "x%d" % i, "canal": "llamada"})
			await t.frames(1)
			t.check(not hub.qa.monitored, "contacto %d de la inducción sin REC de Haime" % (i + 1))
	else:
		t.note("sin hub de personajes en la inducción (no hay REC que mostrar)")
	if tut != null and is_instance_valid(tut):
		tut.call("skip_module")
	await t.back_to_menu()


func _version(t: Node) -> void:
	t.check(str(ProjectSettings.get_setting("application/config/version", "")) == "0.3.2-beta1", "project.godot: versión 0.3.2-beta1")
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var cfg := f.get_as_text() if f != null else ""
	t.check(cfg.contains("application/file_version=\"0.3.2.0\"") and cfg.contains("application/product_version=\"0.3.2.0\""), "export de Windows: 0.3.2.0")
	await t.back_to_menu()
	var menu: Control = t.main.get("main_menu")
	var found := false
	for l in menu.find_children("*", "Label", true, false):
		if (l as Label).text.contains("v0.3.2-beta1"):
			found = true
	t.check(found, "el pie del menú dice v0.3.2-beta1")

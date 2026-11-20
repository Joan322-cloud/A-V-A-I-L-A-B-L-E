extends FloorBase
## Piso 2 (operaciones): casilleros, refris, máquina de agua, sala de feedback de QA (`sala_calibracion`),
## pasillo de 14 paneles, sala con 6 filas A-F de 16 cubículos (C-14 con 2 monitores), sitio de Shero, La Central
## (impresora), reloj de pared, parlantes, baños comunes (GDD 7.4 rev 2).
## v0.3 P2: dispensador de agua DENTRO de la sala (Fatiga −2, no dispara reglas), ventanas con lluvia
## detrás de Shero (relámpagos), tablero de KPI en rojo, notas de agentes quemados, sillas vacías con el
## headset balanceándose, un sitio "C-17" que no debería existir, marcadores sala_calibracion y
## evento_rasec (centro de la sala, P5).
## v0.3.1 pisos (plano de Joan v3): la sala rodea el núcleo; hall con molinete al extremo de los casilleros y la
## escalera enfrente de los ascensores; pasillo de casilleros con la entrada 2 (vidrio) al norte y el pantry al sur
## (entrada 1); baños al sur del pantry (hombres a la derecha, mujeres a la izquierda, limpieza al frente); sala de
## feedback junto a la limpieza (se entra desde el ala norte); sala auxiliar con el puesto del RTA. El interior de la
## sala no cambia.

const ROWS: Array[String] = ["A", "B", "C", "D", "E", "F"]
const SEATS_PER_ROW := 16
const ROOM_X0 := 18.0
const ROOM_X1 := 48.0
const ROOM_Z0 := -20.0
const ROOM_Z1 := 2.0

const AISLE_XS: Array[float] = [18.7, 23.4, 28.1, 32.8, 37.5, 42.2, 46.4]
## v0.3 P6b: el centro de la sala (fila D, sitios 07-10) es la zona de huddle: ahí arma Rasec su evento
## (antes el círculo caía sobre las sillas del pasillo C/D).
const HUDDLE_SEATS: Array[String] = ["D-07", "D-08", "D-09", "D-10"]
const HUDDLE_CENTER := Vector3(32.375, 0, -7.9)

var panel_count: int = 14
var panels_node: Node3D = null
var wall_clock: WorldObjects.WallClock = null
var shero_spawn: Vector3 = Vector3(46, 0, -9)
var c14_pos: Vector3 = Vector3.ZERO


func _build() -> void:
	floor_number = 2
	# v0.3.1 pisos (planos de Joan v3, girados 180° para que la sala quede donde estaba: x_juego = 9 − x_plano,
	# z_juego = y_plano). Hall de ascensores (x 1,8..18, z −1,5..1,5): porcelanato negro espejado, mármol con los
	# ascensores, la limpieza y el gabinete (+z), pared blanca con la cortafuego enfrente (−z); molinete al extremo
	# del lado de los casilleros (x ≈ 2,6) y vidrio a la sala al otro extremo (x 18, sin paso).
	_hall()
	_lockers_corridor()
	_north_annex()
	_feedback_room()
	_pantry()
	_aux_room()
	_bathroom_block()
	_southwest_annex()
	_p2_zones()
	# Sala de operaciones (x 18..48, z -20..2): alfombra, techo abierto, fluorescentes.
	var rc := Vector2((ROOM_X0 + ROOM_X1) * 0.5, (ROOM_Z0 + ROOM_Z1) * 0.5)
	var rs := Vector2(ROOM_X1 - ROOM_X0, ROOM_Z1 - ROOM_Z0)
	# v0.3.1 Q5 (site): piso GRIS CLARO poco brillante (las siluetas oscuras se leen contra él), techo abierto pintado
	# de NEGRO con ductos y rieles de spots, paredes blancas gastadas, persianas enrollables blancas en las ventanas.
	Greybox.sfloor(self, "Sala", rc, rs, "sala_gris")
	Greybox.ceiling(self, "SalaTecho", rc, rs, 3.4, Color(0.02, 0.02, 0.022))
	for dz in [-16.0, -9.0, -2.0]:
		Greybox.duct(self, "DuctoSala%d" % int(-dz), Vector3(rc.x, 3.15, dz), rs.x - 1.0, 0.25, true, Color(0.06, 0.06, 0.065))
	for dx in [24.0, 36.0]:
		Greybox.box(self, "Bandeja%d" % int(dx), Vector3(dx, 3.25, rc.y), Vector3(0.3, 0.06, rs.y - 1.0), Greybox.NEGRO, false)
		Greybox.box(self, "RielSpots%d" % int(dx), Vector3(dx + 6.0, 3.3, rc.y), Vector3(0.05, 0.05, rs.y - 2.0), Greybox.NEGRO, false)
	Greybox.box(self, "SalaS", Vector3(rc.x, 1.7, ROOM_Z0), Vector3(rs.x, 3.4, 0.2), Greybox.BEIGE).material_override = Greybox.surf("pared", Greybox.BLANCO_PARED)
	_east_windows(rc, rs)
	# Pared oeste: abierta al ala suroeste (entrada 1, z −19,5..−11,2), vidrio al hall (z −1,5..1,5); norte: el paso de la
	# entrada 2 (x 18..19,5).
	for wn in [["SalaN_A", Vector3(ROOM_X0 + 9.75, 1.7, ROOM_Z1), Vector3(16.5, 3.4, 0.2)], ["SalaN_B", Vector3(ROOM_X1 - 6, 1.7, ROOM_Z1), Vector3(12, 3.4, 0.2)], ["SalaW_S", Vector3(ROOM_X0, 1.7, -19.75), Vector3(0.2, 3.4, 0.5)], ["SalaW_A", Vector3(ROOM_X0, 1.7, -6.35), Vector3(0.2, 3.4, 9.7)], ["SalaW_B", Vector3(ROOM_X0, 1.7, 1.75), Vector3(0.2, 3.4, 0.5)]]:
		Greybox.swall(self, str(wn[0]), wn[1], wn[2], "pared", Greybox.BLANCO_PARED)
	Greybox.box(self, "SalaW_Dintel", Vector3(ROOM_X0, 3.25, -15.35), Vector3(0.2, 0.3, 8.3), Greybox.BLANCO_PARED, false).material_override = Greybox.surf("pared", Greybox.BLANCO_PARED)
	Greybox.box(self, "SalaW_VidrioHall", Vector3(ROOM_X0, 1.4, 0), Vector3(0.05, 2.8, 3.0), Greybox.VIDRIO)
	Greybox.box(self, "SalaW_VidrioHallMarco", Vector3(ROOM_X0, 2.85, 0), Vector3(0.12, 0.1, 3.0), Greybox.MARCO_NEGRO, false)
	Greybox.box(self, "SalaW_VidrioHallAlto", Vector3(ROOM_X0, 3.15, 0), Vector3(0.2, 0.5, 3.0), Greybox.BLANCO_PARED, false)
	Greybox.light(self, Vector3(19.6, 2.6, -1.2), Color(0.82, 0.9, 1.0), 0.8, 7.5).name = "LuzSalaVidrioHall"
	Greybox.light(self, Vector3(16.6, 2.3, 0.0), Color(1.0, 0.92, 0.84), 0.7, 5.5).name = "LuzHallFondo"
	Greybox.marker(self, "entrada_sala", Vector3(19, 0, 0), 180.0)
	Greybox.marker(self, "haime_puerta", Vector3(18.75, 0, 3.0), 180.0)  # Haime se asoma desde el paso de la entrada 2
	# Fluorescentes: 14 con sombra, el resto sin; unos pocos parpadean (más cerca de la fila C).
	var n := 0
	for ix in 6:
		for iz in 4:
			var flick := (ix == 4 and iz == 1) or (ix == 1 and iz == 3) or (ix == 5 and iz == 0)
			Greybox.light_panel(self, "LuzSala_%d_%d" % [ix, iz], Vector3(ROOM_X0 + 3 + ix * 4.8, 3.3, ROOM_Z0 + 3 + iz * 5.2), n < 14, flick)
			n += 1
	# 6 filas A-F de 16 cubículos. Fila C = isla KipuPay. C-14 con 2 monitores.
	for r in ROWS.size():
		var z := ROOM_Z0 + 2.5 + r * 3.2
		var is_c := ROWS[r] == "C"
		for i in SEATS_PER_ROW:
			var id := "%s-%02d" % [ROWS[r], i + 1]
			if id in HUDDLE_SEATS:
				continue
			var x := ROOM_X0 + 2.0 + i * 1.65
			var pos := Vector3(x, 0, z)
			var is_c14 := id == "C-14"
			# v0.3.2: los puestos libres de otras islas (E-07/E-08) son PCs de verdad: ahí también se cambia el AUX
			# (sin terminales de pared), con la regla «otra isla» corriendo.
			var free_pc := id in ["E-07", "E-08"]
			var seat := WorldObjects.seat(self, id, pos, 0.0, is_c, 2 if is_c14 or free_pc else 1)
			if free_pc:
				MonitorScreen.attach(seat.get_parent(), id)
			if is_c14:
				seat.has_session = true
				c14_pos = pos
				MonitorScreen.attach(seat.get_parent(), id)  # pantallas vivas (viewports)
				Greybox.label(seat.get_parent(), "don Aurelio", Vector3(0.64, 0.98, -0.43), 0.045, Greybox.AMBAR)  # foto pegada al borde del monitor
			elif id == "C-13":
				seat.enabled = false  # siempre vacío, con una taza
				Greybox.box(seat.get_parent(), "Taza", Vector3(0.3, 0.78, -0.3), Vector3(0.1, 0.1, 0.1), Greybox.BLANCO, false)
			elif not is_c14:
				# Bustos low-poly que teclean (relleno); en la fila C, agentes con rig (C-15 es tu compañero).
				seat.enabled = false
				var placed := false
				if is_c and id in ["C-10", "C-11", "C-12", "C-15", "C-16"]:
					placed = _seat_agent(seat.get_parent(), id)
				if not placed:
					Greybox.box(seat.get_parent(), "Busto", Vector3(0, 1.0, 0.4), Vector3(0.4, 0.6, 0.3), Color(0.2, 0.22, 0.3), false)
		if is_c:
			WorldObjects.signage(self, "SIGN_ISLAND", Vector3(ROOM_X0 + 0.5, 2.2, z), 90.0, 0.22, Greybox.CIAN)
	# Algunos sitios de otras islas sí están libres (para el timer de la isla).
	for free_id in ["E-07", "E-08", "A-03", "F-12"]:
		var s := seat_by_id(free_id)
		if s != null:
			s.enabled = true
			var busto := s.get_parent().get_node_or_null("Busto")
			if busto != null:
				busto.queue_free()
			if free_id in ["A-03", "F-12"]:
				HorrorProps.abandoned_seat(s.get_parent() as Node3D)
	Zone.make(self, "fila_c", Vector3((ROOM_X0 + ROOM_X1) * 0.5, 1.5, ROOM_Z0 + 2.5 + 2 * 3.2), Vector3(ROOM_X1 - ROOM_X0, 3, 3.0))
	Zone.make(self, "sala", Vector3(rc.x, 1.7, rc.y), Vector3(rs.x, 3.4, rs.y))
	_room_dispenser()
	_huddle()
	Greybox.marker(self, "evento_rasec", HUDDLE_CENTER, 180.0)  # P6b: zona de huddle (centro de la sala, sin sillas)
	_room_story()
	_room_site()
	Greybox.marker(self, "pc", c14_pos + Vector3(0, 0, 1.2), 0.0)
	# Sitio de Shero al fondo (este), mirando a la sala.
	Greybox.box(self, "EscritorioShero", Vector3(46, 0.75, -9), Vector3(1.0, 0.06, 2.4), Greybox.GRIS_OSCURO, false)  # sin colisión: Shero sale por aquí
	Greybox.box(self, "SillaShero", Vector3(46.9, 0.5, -9), Vector3(0.6, 0.1, 0.6), Greybox.GRIS_OSCURO, false)
	Greybox.marker(self, "shero_sitio", Vector3(46.9, 0, -9), 90.0)
	if GameState.enemy_enabled("mentor"):
		# T3+: el Mentor se sienta junto a Shero (rig de agente de repuesto reteñido; su lógica vive en Main/Mentor).
		Greybox.box(self, "EscritorioMentor", Vector3(46, 0.75, -13.2), Vector3(1.0, 0.06, 1.6), Greybox.GRIS_OSCURO, false)
		Greybox.box(self, "MonitorMentor", Vector3(45.7, 1.05, -13.2), Vector3(0.03, 0.34, 0.5), Color(0.1, 0.12, 0.2), false, 0.3)
		var mentor := NpcFigure.make(self, "agente_juan", Vector3(46.9, 0, -13.2), 90.0, 1.74, Color(0.55, 0.22, 0.24), "MentorFigura")
		mentor.look_radius = 9.0
		mentor.look_max_deg = 50.0
		mentor.idle_anim = "type"
		mentor.anim_speed = 1.1
		Greybox.label(self, "MENTOR", Vector3(45.4, 1.45, -13.2), 0.08, Greybox.CIAN, -PI * 0.5)  # placa mirando a la sala (oeste)
	# Reloj de pared, parlantes.
	wall_clock = WorldObjects.WallClock.new()
	wall_clock.name = "RelojPared"
	wall_clock.size = Vector3(1.0, 0.6, 0.6)
	wall_clock.position = Vector3(33, 2.8, ROOM_Z0 + 0.15)
	add_child(wall_clock)
	Greybox.box(wall_clock, "Caja", Vector3.ZERO, Vector3(0.9, 0.4, 0.05), Greybox.GRIS_OSCURO, false)
	wall_clock.label = Greybox.label(wall_clock, "", Vector3(0, 0, 0.04), 0.3, Greybox.ROJO)  # un solo rojo (GDD 8.2)
	for x in [24.0, 33.0, 42.0]:
		Greybox.box(self, "Parlante%d" % int(x), Vector3(x, 3.3, -9), Vector3(0.3, 0.1, 0.3), Greybox.GRIS_OSCURO, false)
	# La Central: impresora y rack con puerta de vidrio (esquina sureste).
	Greybox.floor_slab(self, "Central", Vector2(45, -17.5), Vector2(5, 4), Greybox.GRIS)
	Greybox.room_walls(self, "CentralPared", Vector2(45, -17.5), Vector2(5, 4), 3.4, Greybox.VIDRIO, ["s", "e"])
	Greybox.box(self, "Impresora", Vector3(46, 0.5, -18.5), Vector3(0.8, 1.0, 0.6), Greybox.BLANCO)
	Greybox.box(self, "Rack", Vector3(44, 1.0, -18.5), Vector3(0.6, 2.0, 0.6), Greybox.GRIS_OSCURO)
	WorldObjects.signage(self, "SIGN_CENTRAL", Vector3(45, 2.5, -15.4), 0.0, 0.18)
	# v0.3.1 pisos (QA, ya pasaba en la beta): entre la punta del vidrio oeste de La Central (z −15,5) y el divisor de la
	# fila B (z −14,9) quedan 0,6 m; la rejilla de rutas pasaba por ahí y el jugador (0,72 m) se trababa. Se cierra
	# (invisible); a La Central se sigue entrando por su lado abierto, de frente a la sala.
	Greybox.invisible_box(self, "CentralRanuraCierre", Vector3(42.5, 0.65, -15.2), Vector3(0.2, 1.3, 0.62))
	_horror_p2()
	# Waypoints de la sala para Shero / RTA: 7 pasillos entre filas × 7 columnas; las columnas de
	# los extremos (x 18,7 y 46,4) quedan fuera de los cubículos para cruzar entre pasillos sin chocar.
	# v0.3.1 pisos: + el resto del piso con aristas explícitas (_WP_EXTRA/_WP_LINKS).
	_p2_waypoints()
	_setup_v04_events()

func _setup_v04_events() -> void:
	# Turno 4 (Jueves): Papayala ocupa tu silla C-14 tras el lunch y te fuerza a desalojarlo
	if GameState.turno == 4:
		var pap_ctrl := _PapayalaSeatEvent.new()
		pap_ctrl.name = "PapayalaSeatEvent"
		pap_ctrl.floor_ref = self
		add_child(pap_ctrl)
		EventBus.ezlak_post.emit("#team-familia", "papayala", "Buenas noches. Hoy reviso la fila C. Algunos asientos van a quedar libres pronto.", {"tipo": "programado", "typing_s": 2.0})
	# Turno 5 (Viernes - Penultimo): Shero Gigante Colosal + Derrumbe progresivo del site + OM con las 5 ofertas
	if GameState.turno == 5:
		for empty_id in ["C-11", "C-16"]:
			var s_emp := seat_by_id(empty_id)
			if s_emp != null and s_emp.get_parent() != null:
				for ch in s_emp.get_parent().get_children():
					if ch.name != "Caja" and not (ch is WorldObjects.Seat):
						ch.visible = false
		var sh5 := get_node_or_null("Shero") as Node3D
		if sh5 != null:
			sh5.scale = Vector3(2.4, 2.4, 2.4)
			if sh5.has_method("set_look"):
				sh5.call("set_look", "calvo")
		var collapser := _SiteCollapseController.new()
		collapser.name = "SiteCollapseController"
		collapser.floor_ref = self
		add_child(collapser)
		if P5Actor.model_path("om") != "":
			var om_npc := P5Actor.make(self, "om", 1.80, Vector3(44.5, 0, -6.5), 90.0, "OM")
			om_npc.floor_ref = self
			om_npc.play("idle", true, 0.8)
		var om_ctrl := _OmOfferTrigger.new()
		om_ctrl.name = "OmOfferTrigger"
		add_child(om_ctrl)
		EventBus.ezlak_post.emit("dm:shero", "om", "Jiroshi: a las 08:00 AM revisamos tus 5 opciones sobre la mesa.", {"tipo": "programado", "mention": true, "typing_s": 2.5})
	# Turno 6 (Sabado Halloween - Ultimo turno laboral): Fragmento 1 de carta de renuncia + sala devastada
	if GameState.turno == 6:
		var sh6 := get_node_or_null("Shero") as Node3D
		if sh6 != null:
			sh6.visible = false
			sh6.process_mode = Node.PROCESS_MODE_DISABLED
		if not bool(GameState.flags.get("frag_carta_1", false)):
			var f1 := WorldObjects.simple(self, WorldObjects.ResignationFragment, "FragmentoCarta1", "HUD_TURNSTILE", c14_pos + Vector3(-0.45, 0.78, -0.25), Vector3(0.24, 0.03, 0.32), Color(0.95, 0.92, 0.82), 15.0, 0.6)
			(f1 as WorldObjects.ResignationFragment).frag_id = 1


## Zona de huddle (P6b): alfombra, cinta en el piso y un cartel colgado. Sin colisión: se cruza.
func _huddle() -> void:
	var c := HUDDLE_CENTER
	var alf := Greybox.box(self, "HuddleAlfombra", c + Vector3(0, 0.012, 0), Vector3(6.2, 0.02, 4.0), Color(0.16, 0.2, 0.24), false)
	alf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		var cinta := Greybox.box(self, "HuddleCinta%d" % int(side), c + Vector3(0, 0.025, side * 1.9), Vector3(6.0, 0.005, 0.06), Greybox.AMBAR, false, 0.15)
		cinta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(self, "HuddleCartelCaja", c + Vector3(0, 2.95, 0), Vector3(3.0, 0.32, 0.04), Greybox.GRIS_OSCURO, false)
	for cx in [-1.2, 1.2]:
		Greybox.box(self, "HuddleCartelCable%d" % int(cx * 10), c + Vector3(cx, 3.2, 0), Vector3(0.01, 0.18, 0.01), Greybox.NEGRO, false)
	# Una cara por lado (la caja taparía el reverso de Greybox.two_sided).
	Greybox.one_sided(WorldObjects.signage(self, "P6B_HUDDLE", c + Vector3(0, 2.95, 0.03), 0.0, 0.14, Greybox.AMBAR))
	Greybox.one_sided(WorldObjects.signage(self, "P6B_HUDDLE", c + Vector3(0, 2.95, -0.03), 180.0, 0.14, Greybox.AMBAR))


## Agente sentado tecleando en un cubículo (modelo GLB de un compañero distinto al jugador).
func _seat_agent(cubicle: Node3D, id: String) -> bool:
	var others: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			others.append(a.to_lower())
	var model := "agente_" + others[abs(id.hash()) % others.size()]
	var rig := CharacterRig.attach(cubicle, model, 1.7, 180.0, Vector3(0, 0, 0.45))
	if rig == null:
		return false
	rig.play("type" if id.hash() % 2 == 0 else "sit", true, 0.9, ["sit", "idle"])
	if id == "C-15":
		var comp := Companion.new()
		comp.name = "Companero"
		cubicle.add_child(comp)
		comp.setup(rig)
	return true


## Grafo de la sala: solo a lo largo de cada pasillo y por las dos columnas de los extremos
## (cruzar en diagonal atraviesa cubículos). El resto del piso se conecta por cercanía.
func _build_waypoints(max_dist: float = 7.0) -> void:
	astar.clear()
	for i in waypoints.size():
		astar.add_point(i, waypoints[i])
	var n_sala := (ROWS.size() + 1) * AISLE_XS.size()
	for i in waypoints.size():
		for j in range(i + 1, waypoints.size()):
			var a := waypoints[i]
			var b := waypoints[j]
			var d := a.distance_to(b)
			if i < n_sala and j < n_sala:
				var same_aisle := absf(a.z - b.z) < 0.01 and absf(a.x - b.x) <= 4.8
				var side_col := absf(a.x - b.x) < 0.01 and (absf(a.x - AISLE_XS[0]) < 0.01 or absf(a.x - AISLE_XS[-1]) < 0.01) and absf(a.z - b.z) <= 3.3
				if same_aisle or side_col:
					astar.connect_points(i, j)
			elif i < n_sala and j == n_sala and d <= max_dist:
				astar.connect_points(i, j)  # el sitio de Shero, con los pasillos cercanos
	# v0.3.1 pisos: el resto del piso (hall, casilleros, alas, pantry, baños, feedback, auxiliar) con aristas fijas.
	var base := n_sala + 1
	if waypoints.size() >= base + _WP_EXTRA.size():
		for l in _WP_LINKS:
			astar.connect_points(base + int(l[0]), base + int(l[1]))
		for l in _WP_ROOM:
			astar.connect_points(base + int(l[0]), int(l[1]) * AISLE_XS.size() + int(l[2]))


## Ruta de patrulla del RTA en serpentina por los pasillos (sin cruzar cubículos).
func patrol_route() -> PackedVector3Array:
	var out := PackedVector3Array()
	for r in ROWS.size() + 1:
		var z := ROOM_Z0 + 0.9 + r * 3.2
		var xs := AISLE_XS.duplicate()
		if r % 2 == 1:
			xs.reverse()
		for x in xs:
			out.append(Vector3(x, 0, z))
	return out


## Ganchos de distorsión del piso 2 (GDD 4.7).
func apply_distortion(id: String, data: Dictionary) -> void:
	match id:
		"un_panel_mas":
			panel_count += 1
			_rebuild_panels()
		"silla_caliente":
			var cub := find_child("Cub_C-14", true, false)
			if cub != null:
				var chair := Greybox.box(self, "SillaCaliente", c14_pos + Vector3(-0.9, 0.45, 1.0), Vector3(0.45, 0.05, 0.45), Greybox.GRIS_OSCURO, false)
				chair.rotation_degrees.y = 35.0
				Greybox.box(chair, "Respaldo", Vector3(0, 0.3, 0.2), Vector3(0.45, 0.5, 0.05), Greybox.GRIS_OSCURO, false)
		"tres_cuarenta_y_siete":
			if wall_clock != null:
				wall_clock.frozen_text = str(data.get("hora", "3:47 AM"))
		"sesion_otra_fila":
			var c14 := seat_by_id("C-14")
			var e07 := seat_by_id("E-07")
			if c14 != null and e07 != null:
				c14.has_session = false
				e07.has_session = true
				e07.enabled = true
				var mon := c14.get_parent().get_node_or_null("Monitor0")
				if mon is MeshInstance3D:
					(mon as MeshInstance3D).material_override = Greybox.material(Color(0.02, 0.02, 0.02))
				var l1 := Greybox.label(e07.get_parent(), GameState.agent.to_upper(), Vector3(0, 1.2, -0.5), 0.12, Greybox.AMBAR)
				var l2 := Greybox.label(e07.get_parent(), Loc.fmt(tr("HUD_CLIENT_WAITING"), {"t": str(data.get("cliente_en_espera", "0:42"))}), Vector3(0, 1.0, -0.43), 0.08, Greybox.ROJO)
				# v0.3 P2 (arreglo del handoff de P1): la sesión movida es una alucinación CORTA. Al sentarte
				# (en E-07 o en C-14) parpadeas y vuelves a estar en C-14 con tu sesión: no te quedas atendiendo
				# en otra isla y Shero no te castiga por "isla"/"otra isla" (solo cuenta quedarse sentado mucho
				# tiempo en una isla que no es la suya).
				var back := _SessionReturn.new()
				back.name = "SesionVuelve"
				back.c14 = c14
				back.e07 = e07
				back.mon = mon as MeshInstance3D
				back.labels = [l1, l2]
				add_child(back)


func _ambient() -> void:
	AudioManager.play_ambient("fluorescente_zumbido")
	AudioManager.play_ambient("teclados_lejanos")


func ambience_events() -> Array[String]:
	return ["pa", "pa", "susurro", "llanto", "teclado", "silencio"]


func ambience_points() -> Array[Vector3]:
	return [Vector3(3.3, 1.5, -17.0), Vector3(-5.0, 1.3, -11.0), Vector3(0.5, 1.5, -6.0), Vector3(10.0, 1.3, 6.0), Vector3(11.0, 1.2, -18.5), Vector3(20, 1.2, -19), Vector3(46, 1.2, -19), Vector3(44.6, 1.1, -0.5)]


# --- v0.3 P2 -------------------------------------------------------------------------------------

class _SessionReturn extends Node:
	var c14: WorldObjects.Seat = null
	var e07: WorldObjects.Seat = null
	var mon: MeshInstance3D = null
	var labels: Array = []
	var _mon_mat: Material = null
	var _seated_t: float = -1.0
	var done: bool = false

	func _ready() -> void:
		_mon_mat = Greybox.material(Color(0.1, 0.12, 0.2), 0.3)
		EventBus.player_seated.connect(_on_seated)
		EventBus.player_stood_up.connect(_on_stood)
		# v0.3.2-core: si la sesión se muda contigo YA sentado (te sentó el juego: reaparecer, «Continuar»), el aviso
		# de «te sentaste» no llega nunca y la sesión se quedaba en E-07 para siempre: C-14 sin aceptar contactos.
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl != null and pl.seated and pl.seat_id in ["E-07", "C-14"]:
			_seated_t = 0.0

	func _on_stood() -> void:
		_seated_t = -1.0

	func _on_seated(id: String) -> void:
		if not done and (id == "E-07" or id == "C-14"):
			_seated_t = 0.0

	func _process(delta: float) -> void:
		if done or _seated_t < 0.0:
			return
		_seated_t += delta
		if _seated_t >= 2.5 and not GameState.in_contact:
			revert()

	## La sesión vuelve a C-14; si estabas sentado en E-07, "despiertas" sentado en C-14.
	func revert(quiet: bool = false) -> void:
		if done:
			return
		done = true
		if not quiet:
			EventBus.screen_black.emit(0.6)
			AudioManager.play_sfx("parpadeo")
		if c14 != null:
			c14.has_session = true
		if e07 != null:
			e07.has_session = false
		if mon != null:
			mon.material_override = _mon_mat
		for l in labels:
			if is_instance_valid(l):
				(l as Node).queue_free()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and player.seated and player.seat_id == "E-07" and c14 != null:
			player.stand_up()
			player.sit_at(c14, "C-14")
		EventBus.show_message.emit(tr("MSG_SESSION_BACK"), 4.0)


class _Blink extends Node:
	var target: Node3D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if target != null:
			target.visible = fmod(_t, 1.2) < 0.7


## Ventanas al este (detrás de Shero): muro bajo, vidrio con lluvia, pilares, la ciudad y relámpagos.
func _east_windows(rc: Vector2, rs: Vector2) -> void:
	Greybox.box(self, "SalaE_Bajo", Vector3(ROOM_X1, 0.5, rc.y), Vector3(0.2, 1.0, rs.y), Greybox.BEIGE)
	Greybox.box(self, "SalaE_Alto", Vector3(ROOM_X1, 3.0, rc.y), Vector3(0.2, 0.8, rs.y), Greybox.BEIGE, false)
	Greybox.invisible_box(self, "SalaE_Limite", Vector3(ROOM_X1 + 0.05, 1.7, rc.y), Vector3(0.2, 3.4, rs.y))
	var n := 7
	var seg := rs.y / n
	for i in n + 1:
		Greybox.box(self, "SalaE_Pilar%d" % i, Vector3(ROOM_X1, 1.8, ROOM_Z0 + i * seg), Vector3(0.24, 1.6, 0.22), Greybox.BEIGE, false)
	for i in n:
		var g := Weather.rain_glass(self, "SalaE_Vidrio%d" % i, Vector3(ROOM_X1 + 0.02, 1.8, ROOM_Z0 + (i + 0.5) * seg), Vector2(seg - 0.2, 1.6), -90.0)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Weather.skyline(self, 61, 84.0, 130.0, -80.0, 60.0, -18.0, 20, 14.0, 40.0, 0.28, true)
	# Por las ventanas del este: la autopista elevada 13 m abajo, cruzando la avenida (v0.3.1 Q5, ref. del entorno).
	SiteProps.entorno_este(self, -18.0, 66.0, -9.0, -180.0, 160.0, 460.0)
	Weather.rain(self, Vector3(52.5, 0.5, rc.y), Vector3(8.0, 6.0, rs.y), -22.0)
	Weather.lightning(self, Vector3(75, 22, -9), 5.0, 70.0)


## Dispensador de agua DENTRO de la sala de operaciones (PLAN §2 #25), contra la pared norte cerca de
## la entrada (no estorba los pasillos de Shero ni del RTA).
func _room_dispenser() -> void:
	var w := WorldObjects.simple(self, WorldObjects.WaterCooler, "DispensadorSala", "HUD_WATER", Vector3(22.0, 0.6, 1.6), Vector3(0.4, 1.2, 0.4), Color(0.4, 0.6, 0.8))
	(w as WorldObjects.WaterCooler).fatigue_delta = -2.0
	(w as WorldObjects.WaterCooler).message_key = "MSG_WATER_ROOM"
	var bidon := Greybox.box(self, "BidonSala", Vector3(22.0, 1.42, 1.6), Vector3(0.28, 0.42, 0.28), Color(0.55, 0.75, 0.9, 0.55), false, 0.2)
	OfficeHorror.dark_bottle_thing(bidon, Vector3(0.03, -0.04, 0.02))  # v0.3.1 pisos: algo oscuro flota en el bidón
	Greybox.box(self, "VasosSala", Vector3(22.36, 1.0, 1.75), Vector3(0.08, 0.3, 0.08), Greybox.BLANCO, false)
	HorrorProps.note(self, "NOTE_WATER", Vector3(22.0, 0.9, 1.39), 180.0, false, 6.0)
	Greybox.marker(self, "dispensador_sala", Vector3(22.0, 0, 0.3), 0.0)


## Utilería: tablero de KPI en rojo, carteles que cambian, notas, el sitio C-17.
func _room_story() -> void:
	HorrorProps.kpi_board(self, Vector3(25.8, 2.25, ROOM_Z0 + 0.14), 0.0)
	HorrorProps.sinister_poster(self, "POSTER_ROOM_1", "POSTER_ROOM_1_DARK", Vector3(ROOM_X0 + 0.14, 1.95, -6.5), 90.0, 0.2, 2.0)
	HorrorProps.sinister_poster(self, "POSTER_ROOM_2", "POSTER_ROOM_2_DARK", Vector3(40.5, 2.3, ROOM_Z0 + 0.14), 0.0, 0.2, 2.0)
	var notes := [["C-13", "NOTE_C13", false], ["B-05", "NOTE_DESK_1", false], ["D-12", "NOTE_DESK_2", true], ["E-02", "NOTE_DESK_3", false], ["F-14", "NOTE_DESK_4", true], ["A-11", "NOTE_DESK_5", false], ["C-16", "NOTE_DESK_6", false]]
	for n in notes:
		var cub := find_child("Cub_" + str(n[0]), true, false) as Node3D
		if cub != null:
			HorrorProps.note(cub, str(n[1]), Vector3(0.42, 1.0, -0.565), 0.0, bool(n[2]), randf_range(-8.0, 8.0))
	HorrorProps.note(self, "NOTE_LOCKER", Vector3(-0.38, 1.35, -5.6), 90.0, true, 4.0)
	HorrorProps.note(self, "NOTE_BATHROOM", Vector3(BCOR_X1 - 0.12, 1.3, -14.25), -90.0, false, -5.0)
	_ghost_desk()


## "Algo no cuadra": un sitio C-17 (la fila tiene 16) contra la pared norte, con tu nombre en el monitor.
## Aparece al volver a la sala después del 1.er break y se va si te acercas sin mirarlo.
## v0.3 P6b (era demasiado sutil): a la SEGUNDA vez que lo miras (miras, apartas la vista, vuelves a mirar) se
## enciende: el monitor se prende con tu nombre y "Turno 17 · Available 0 %", un fluorescente frío parpadea encima
## (la única luz de esa esquina), la silla gira sola hacia ti, el nombre late en rojo y suena un pitido de auricular.
## Te deja mirarlo 6 s; si te acercas sin mirarlo, o al terminar, se apaga y desaparece.
func _ghost_desk() -> void:
	var g := Node3D.new()
	g.name = "SitioFantasma"
	g.position = Vector3(30.2, 0, 1.3)
	g.rotation_degrees.y = 180.0
	g.visible = false
	add_child(g)
	Greybox.box(g, "Panel", Vector3(0, 0.75, -0.6), Vector3(1.5, 1.5, 0.05), Greybox.BEIGE, false)
	Greybox.box(g, "Escritorio", Vector3(0, 0.72, -0.3), Vector3(1.5, 0.04, 0.6), Greybox.GRIS, false)
	var mon := Greybox.box(g, "Monitor", Vector3(0, 1.12, -0.45), Vector3(0.56, 0.34, 0.03), Color(0.15, 0.2, 0.3), false, 0.8)
	var chair := Node3D.new()
	chair.name = "SillaGiro"
	chair.position = Vector3(0, 0, 0.45)
	g.add_child(chair)
	Greybox.box(chair, "Silla", Vector3(0, 0.45, -0.05), Vector3(0.45, 0.05, 0.45), Greybox.GRIS_OSCURO, false)
	Greybox.box(chair, "Respaldo", Vector3(0, 0.75, 0.15), Vector3(0.45, 0.5, 0.05), Greybox.GRIS_OSCURO, false)
	Greybox.box(g, "Headset", Vector3(0.38, 0.78, -0.25), Vector3(0.16, 0.05, 0.12), Greybox.NEGRO, false)
	Greybox.label(g, "C-17", Vector3(0, 1.42, -0.57), 0.1)
	var who := Greybox.label(g, GameState.agent.to_upper(), Vector3(0, 1.14, -0.43), 0.06, Greybox.AMBAR)
	who.name = "Nombre"
	var info := Greybox.label(g, "", Vector3(0, 1.04, -0.43), 0.035, Color(0.6, 0.95, 0.9))
	info.name = "Info"
	var lamp := OmniLight3D.new()
	lamp.name = "LuzC17"
	lamp.position = Vector3(0, 2.6, 0.2)
	lamp.light_color = Color(0.7, 0.9, 1.0)
	lamp.light_energy = 0.0
	lamp.omni_range = 4.5
	lamp.shadow_enabled = false
	lamp.set_meta("no_mood", true)
	g.add_child(lamp)
	Greybox.box(g, "Fluorescente", Vector3(0, 2.75, 0.2), Vector3(1.2, 0.05, 0.25), Color(0.75, 0.9, 0.9), false, 0.0)
	var gd := _GhostDesk.new()
	gd.name = "Fantasma"
	gd.desk = g
	gd.monitor = mon
	gd.chair = chair
	gd.who = who
	gd.info = info
	gd.lamp = lamp
	g.add_child(gd)


## Pruebas y capturas: muestra el C-17 (reveal = ya encendido, la "segunda mirada").
func debug_show_c17(reveal: bool = false) -> void:
	var gd := find_child("Fantasma", true, false)
	if gd != null:
		gd.call("show_now")
		if reveal:
			gd.call("reveal")


class _GhostDesk extends Node:
	var desk: Node3D = null
	var monitor: MeshInstance3D = null
	var chair: Node3D = null
	var who: Label3D = null
	var info: Label3D = null
	var lamp: OmniLight3D = null
	var looks: int = 0  # veces que lo miraste (de no mirar → mirar)
	var revealed: bool = false
	var _armed: bool = false
	var _was_looking: bool = false
	var _t: float = 0.0
	var _anim: float = 0.0
	var _reveal_left: float = 0.0

	func _ready() -> void:
		EventBus.room_entered.connect(_on_room_entered)

	func _on_room_entered() -> void:
		if not _armed and Metrics.breaks_used >= 1 and not bool(GameState.flags.get("c17_visto", false)):
			_armed = true
			GameState.flags["c17_visto"] = true
			desk.visible = true

	## Pruebas/capturas: mostrarlo ya.
	func show_now() -> void:
		_armed = true
		desk.visible = true

	## La segunda mirada: se enciende y te mira.
	func reveal() -> void:
		if revealed:
			return
		revealed = true
		_reveal_left = 6.0
		_anim = 0.0
		info.text = Loc.fmt(tr("C17_SCREEN"), {"agente": GameState.agent})
		if monitor != null and monitor.material_override is StandardMaterial3D:
			var m := (monitor.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.emission_enabled = true
			m.emission = Color(0.35, 0.75, 0.85)
			m.emission_energy_multiplier = 2.2
			monitor.material_override = m
		AudioManager.play_sfx("auricular_pitido", "Sala")
		EventBus.subtitle.emit("sys", tr("C17_SUB"), 3.0)

	func _process(delta: float) -> void:
		if not desk.visible:
			return
		if revealed:
			_anim += delta
			_reveal_left -= delta
			# Fluorescente que se enciende a tirones, silla que gira hacia ti, nombre que late en rojo.
			var on := fmod(_anim, 0.9) < 0.75 or _anim > 1.5
			lamp.light_energy = (1.6 if on else 0.15) * clampf(_anim * 2.0, 0.0, 1.0)
			var cam0 := get_viewport().get_camera_3d()
			if cam0 != null and chair != null:
				var local := desk.to_local(cam0.global_position)
				var target := atan2(local.x, local.z)
				chair.rotation.y = lerp_angle(chair.rotation.y, target, minf(delta * 0.8, 1.0))
			if who != null:
				who.modulate = Greybox.AMBAR.lerp(Color(0.9, 0.1, 0.08), 0.5 + 0.5 * sin(_anim * 6.0))
			if _reveal_left <= 0.0:
				desk.visible = false
				lamp.light_energy = 0.0
				return
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.15
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var to := desk.global_position + Vector3(0, 1, 0) - cam.global_position
		var looking := (-cam.global_transform.basis.z).dot(to.normalized()) > 0.8 and to.length() < 18.0
		if looking and not _was_looking:
			looks += 1
			if looks >= 2:
				reveal()
		_was_looking = looking
		if to.length() < 3.2 and not looking:
			desk.visible = false
			lamp.light_energy = 0.0


func grading() -> Dictionary:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var pos := p.global_position - global_position if p != null else Vector3.ZERO
	if pos.x > FB_X0 and pos.x < FB_X1 and pos.z > HALL_Z and pos.z < ANX_Z0:
		return {"tint": Color(0.92, 0.98, 1.06), "sat": 0.55, "contrast": 1.16, "exterior": false}  # feedback: clínico
	return {"tint": Color(0.88, 1.0, 0.93), "sat": 0.7, "contrast": 1.12, "exterior": false}


func screamer_killers() -> Array:
	return ["shero", "perrito_rta", "rasec", "haime"]

# --- v0.3.1 Q5: piso 2 desde el site -------------------------------------------------------------

const LOCKER_COLORS: Array[Color] = [Color(0.184, 0.435, 0.518), Color(0.122, 0.329, 0.400), Color(0.525, 0.761, 0.678), Color(0.373, 0.639, 0.733), Color(0.816, 0.376, 0.361), Color(0.886, 0.859, 0.792)]


## Casilleros cubo (0,42 m, 4 filas + tapa) a los dos lados del pasillo: una MultiMesh de puertas (barata) y un bloque
## de colisión por lado; porta-candados y números grandes de acrílico (solo contorno) en una columna de cada dos.
## Uno está entreabierto (adentro un celular que vibra con llamadas de la cola). v0.3.1 pisos: pasillo de 2,6 m entre
## paredes (x −0,9..1,9); al este se cortan en la boca del hall (z −1,5..1,5).
func _cube_lockers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1472
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var door := BoxMesh.new()
	door.size = Vector3(0.025, 0.4, 0.4)
	mm.mesh = door
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var num := 1
	var labels := 0
	# [lado (−1 oeste / +1 este), cara hacia el pasillo, z0, z1]
	for s in [[-1.0, -0.4, -10.5, 2.7], [1.0, 1.4, -10.5, -1.75]]:
		var side: float = s[0]
		var face: float = s[1]
		var z0: float = s[2]
		var z1: float = s[3]
		var cols := int((z1 - z0) / 0.42)
		var bx := face + side * 0.2
		var body := Greybox.box(self, "CasillerosBloque%d" % int(side), Vector3(bx, 0.95, (z0 + z1) * 0.5), Vector3(0.4, 1.9, z1 - z0), Color(0.12, 0.13, 0.14))
		body.material_override = Greybox.material(Color(0.1, 0.11, 0.12), 0.0, 0.6)
		Greybox.box(self, "CasillerosTapa%d" % int(side), Vector3(bx, 1.93, (z0 + z1) * 0.5), Vector3(0.44, 0.06, z1 - z0 + 0.04), Color(0.85, 0.85, 0.83), false)
		for c in cols:
			var z := z0 + 0.21 + c * 0.42
			for r in 4:
				var y := 0.24 + r * 0.43
				if side < 0 and absf(z + 4.5) < 0.55:
					continue  # el casillero del jugador (MiCasillero) va aquí
				var col := LOCKER_COLORS[rng.randi_range(0, LOCKER_COLORS.size() - 1)]
				var open: bool = side > 0 and c == 9 and r == 2
				var t := Transform3D(Basis(), Vector3(face - side * 0.0125, y, z))
				if open:
					t = Transform3D(Basis(Vector3.UP, side * 0.9), Vector3(face - side * 0.1, y, z - 0.17))
				xs.append(t)
				cs.append(col)
				if open:
					Greybox.box(self, "CasilleroAbierto", Vector3(face + side * 0.18, y, z), Vector3(0.36, 0.38, 0.38), Color(0.03, 0.03, 0.035), false)
					var cel := Greybox.box(self, "CelularCasillero", Vector3(face + side * 0.1, y - 0.17, z), Vector3(0.07, 0.01, 0.14), Color(0.2, 0.4, 0.6), false, 1.5)
					var vib := _PhoneBuzz.new()
					vib.name = "Vibra"
					vib.target = cel
					cel.add_child(vib)
				if c % 2 == 0 and r >= 1 and labels < 120:
					var l := Greybox.label(self, "%d" % num, Vector3(face - side * 0.03, y + 0.05, z), 0.12, Color(1, 1, 1, 0.04), -side * PI * 0.5)
					l.outline_size = 9
					l.outline_modulate = Color(0.91, 0.96, 0.96, 0.85)
					labels += 1
				num += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PuertasCasilleros"
	mmi.multimesh = mm
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.4
	m.metallic = 0.25
	mmi.material_override = m
	add_child(mmi)


class _PhoneBuzz extends Node:
	var target: Node3D = null
	var _t: float = 0.0
	var _base: Vector3 = Vector3.INF

	func _process(delta: float) -> void:
		if target == null:
			return
		if _base == Vector3.INF:
			_base = target.position
		_t += delta
		var on := fmod(_t, 2.4) < 0.9
		target.position = _base + (Vector3(sin(_t * 90.0) * 0.004, 0, cos(_t * 77.0) * 0.004) if on else Vector3.ZERO)


## Tablones de vinílico levantados (un poco más en cada turno): decorado sin colisión.
func _lifted_planks(center: Vector3, yaw_deg: float, n: int) -> void:
	var lift := 0.01 + 0.012 * clampi(GameState.turno, 1, 3)
	for i in n:
		var pl := Greybox.box(self, "TablonLevantado%d_%d" % [int(center.x), i], center + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(i * 0.9 - 0.9, lift * 0.5 + 0.004, (i % 2) * 0.2), Vector3(1.2, 0.012, 0.2), Color(0.66, 0.58, 0.49), false)
		pl.material_override = Greybox.surf("vinilico_pasillo", Color(1.05, 1.05, 1.05))
		pl.rotation_degrees = Vector3(0.0, yaw_deg, (2.0 + i) * (1 if i % 2 == 0 else -1))
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sala desde el site: persianas blancas (bajan solas hacia la de Shero), papeleras inox altas al final de las filas,
## Halloween olvidado sobre las filas (una figura ya no es de papel), escritorios TM y RTA (marcadores para Q2, C8).
func _room_site() -> void:
	var n := 7
	var seg := (ROOM_Z1 - ROOM_Z0) / n
	var ctl := _BlindsDown.new()
	ctl.name = "PersianasBajan"
	add_child(ctl)
	for i in n:
		var zc := ROOM_Z0 + (i + 0.5) * seg
		var drop: float = [0.25, 0.6, 0.15, 0.85, 0.4, 0.7, 0.3][i]
		var b := SiteProps.blind(self, "Persiana%d" % i, Vector3(ROOM_X1 - 0.16, 2.62, zc), seg - 0.3, drop, 90.0)
		ctl.blinds.append(b)
		ctl.drops.append(drop)
	for r in [0, 1, 2, 5]:
		var z: float = ROOM_Z0 + 2.5 + r * 3.2
		Greybox.bin(self, "PapeleraFila%d" % r, Vector3(ROOM_X1 - 1.0, 0, z - 0.95), true)
	SiteProps.bats(self, "MurcielagoSala", Vector3(32, 0, -9), Vector2(24.0, 18.0), 14, 3.3, 31)
	SiteProps.witch(self, "BrujaSala", Vector3(27.0, 2.3, -5.6))
	var fig := SiteProps.waiting_figure(self, "FiguraColgada", Vector3(38.8, 1.55, -11.5), 0.0)
	Greybox.box(fig, "Soga", Vector3(0, 1.0, 0.05), Vector3(0.01, 0.7, 0.01), Color(0.5, 0.5, 0.5), false)
	var spin := SiteProps._Spin.new()
	spin.name = "Gira"
	spin.speed = 0.08
	spin.targets.append(fig)
	fig.add_child(spin)
	# Escritorios TM (Shero y Rasec, lado a lado frente a la sala). Sin colisión. v0.3.1 pisos: el del RTA está en la
	# sala auxiliar (_aux_room).
	Greybox.box(self, "EscritorioTM", Vector3(46.0, 0.74, -6.2), Vector3(0.9, 0.04, 1.6), Greybox.ROBLE, false).material_override = Greybox.surf("roble")
	Greybox.box(self, "MonitorRasec", Vector3(45.7, 1.05, -6.2), Vector3(0.03, 0.34, 0.56), Color(0.08, 0.1, 0.16), false, 0.3)
	Greybox.marker(self, "escritorio_shero", Vector3(46.9, 0, -9.0), 90.0)
	Greybox.marker(self, "escritorio_rasec", Vector3(46.9, 0, -6.2), 90.0)


## Las persianas bajan solas, de a una, hacia la de Shero (la única arriba deja ver la lluvia).
class _BlindsDown extends Node:
	var blinds: Array[MeshInstance3D] = []
	var drops: Array = []
	var _t: float = 30.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or blinds.is_empty():
			return
		_t = randf_range(35.0, 80.0) * (1.0 - 0.5 * Dread.level())
		var order := [0, 6, 1, 5, 2, 4]  # de los extremos hacia el centro (la de Shero, z ≈ −9)
		for i in order:
			if float(drops[i]) < 0.95:
				drops[i] = minf(float(drops[i]) + 0.15, 1.0)
				var b := blinds[i]
				var top := b.position.y + b.mesh.get_aabb().size.y * b.scale.y * 0.5
				var h := float(drops[i]) * 1.6
				(b.mesh as BoxMesh).size.y = h
				b.position.y = top - h * 0.5
				var tubo := b.get_node_or_null("Tubo") as Node3D
				var barra := b.get_node_or_null("Barra") as Node3D
				if tubo != null:
					tubo.position.y = h * 0.5 + 0.03
				if barra != null:
					barra.position.y = -h * 0.5
				return

# --- v0.3.1 pisos: núcleo, casilleros, pantry, baños y alas según el plano de Joan (v3) ---------------------------
# Referencia: x_juego = 9 − x_plano, z_juego = y_plano (giro de 180°: la sala de operaciones no se mueve). Con el giro, el
# «este» del plano es −x en el juego: el molinete queda en el extremo del hall del lado de los casilleros (x ≈ 2,6).

const HALL_Z := 1.5        # medio ancho útil del hall
const COR_X0 := -0.9       # pasillo de casilleros (ejes de sus paredes)
const COR_X1 := 1.9
const COR_Z0 := -11.0
const COR_Z1 := 3.2        # entrada 2 (vidrio) al extremo norte
const MOL_X := 2.6         # molinete (frontera del siseo)
const PANTRY_X0 := -3.4
const PANTRY_X1 := 5.4
const PANTRY_Z0 := -14.0
const PANTRY_Z1 := -11.0
const FB_X0 := 8.6         # sala de feedback (sala_calibracion)
const FB_X1 := 12.4
const ANX_Z0 := 4.2        # ala norte, detrás de limpieza/feedback/ascensor
const ANX_Z1 := 7.2
const ANX_X0 := -1.35
const AUX_X0 := -6.7
const AUX_Z0 := -16.3
const AUX_Z1 := -7.9
const BATH_Z0 := -19.9
const BCOR_X0 := -0.15     # pasillo corto de baños
const BCOR_X1 := 1.25
const ESMERILADO_P2 := Color(0.72, 0.8, 0.82, 0.62)


func _hall() -> void:
	var cx := (COR_X1 + ROOM_X0) * 0.5
	var lx := ROOM_X0 - COR_X1
	var nuc := Greybox.sfloor(self, "Nucleo", Vector2(cx - 0.05, 0), Vector2(lx + 0.1, HALL_Z * 2.0 + 0.2), "porcelanato_negro")
	nuc.material_override = Greybox.surf("porcelanato_negro", Color(1, 1, 1), 0.08)
	Greybox.ceiling(self, "NucleoTecho", Vector2(cx, 0), Vector2(lx, 3.4), 3.0)
	Greybox.sceiling(self, "NucleoBaldosa", Vector2(cx, 0), Vector2(lx, 3.4), 2.75, "baldosa_techo")
	# +z: azul marino (x 1,9..6,6, con el poster), mármol con la limpieza (x 7,2..8,1), el gabinete, la 2.ª puerta de
	# ascensor (fuera de servicio) y el ascensor (x 12,5..16,7).
	Greybox.swall(self, "NucleoN_Azul", Vector3(4.25, 1.5, HALL_Z), Vector3(4.7, 3, 0.2), "pared", Greybox.AZUL_MARINO)
	Greybox.swall(self, "NucleoN_MarmolA", Vector3(6.9, 1.5, HALL_Z), Vector3(0.6, 3, 0.2), "marmol")
	Greybox.swall(self, "NucleoN_MarmolB", Vector3(10.3, 1.5, HALL_Z), Vector3(4.4, 3, 0.2), "marmol")
	Greybox.swall(self, "NucleoN_MarmolC", Vector3(17.35, 1.5, HALL_Z), Vector3(1.3, 3, 0.2), "marmol")
	Greybox.sbox(self, "DintelLimpieza", Vector3(7.65, 2.55, HALL_Z), Vector3(0.9, 0.9, 0.2), "marmol", false)
	Greybox.sbox(self, "DintelAscensor", Vector3(14.6, 2.8, HALL_Z), Vector3(4.2, 0.4, 0.2), "marmol", false)
	add_elevator(Vector3(14.6, 0, 2.9), 180.0)
	_maint_elevator(Vector3(11.1, 0, HALL_Z - 0.11))
	SiteProps.fire_cabinet(self, "GabineteIncendio", Vector3(9.3, 1.4, HALL_Z - 0.13), 180.0)
	_cleaning_room()
	# −z: pared blanca con la cortafuego de la escalera enfrente de los ascensores (x 3,7..6,7).
	Greybox.swall(self, "NucleoS_A", Vector3(2.8, 1.5, -HALL_Z), Vector3(1.8, 3, 0.2), "pared", Greybox.BLANCO_PARED)
	Greybox.swall(self, "NucleoS_B", Vector3(12.35, 1.5, -HALL_Z), Vector3(11.3, 3, 0.2), "pared", Greybox.BLANCO_PARED)
	Greybox.box(self, "EscaleraDintel", Vector3(5.2, 2.7, -HALL_Z), Vector3(3.0, 0.6, 0.2), Greybox.BLANCO_PARED, false).material_override = Greybox.surf("pared", Greybox.BLANCO_PARED)
	add_stairs(Vector3(5.2, 0, -HALL_Z), 1, 3, true, 0.0)  # subir a 3: lector rojo
	Greybox.box(self, "CajaEscaleraW", Vector3(3.6, 1.5, -4.05), Vector3(0.2, 3, 5.1), Greybox.GRIS)
	Greybox.box(self, "CajaEscaleraE", Vector3(6.8, 1.5, -4.05), Vector3(0.2, 3, 5.1), Greybox.GRIS)
	Greybox.box(self, "CajaEscaleraS", Vector3(5.2, 1.5, -6.6), Vector3(3.4, 3, 0.2), Greybox.GRIS)
	for i in 6:
		var x := 3.8 + i * 2.6
		Greybox.downlight(self, "DownNucleo%d" % i, Vector3(x, 2.73, 0.0), Color(1.0, 0.9, 0.8), 0.7, 5.5, i % 2 == 0)
	Greybox.light_panel(self, "LuzNucleo", Vector3(9.0, 2.7, -0.6), false, true)
	Greybox.box(self, "PulsadorAlarma", Vector3(8.4, 1.4, -HALL_Z + 0.12), Vector3(0.1, 0.12, 0.04), Greybox.ROJO_SEGURIDAD, false)
	Greybox.box(self, "DomoCCTV", Vector3(6.0, 2.69, -0.9), Vector3(0.14, 0.08, 0.14), Greybox.NEGRO, false)
	SiteProps.a4_sheets(self, "HojaA4", Vector3(5.6, 1.5, HALL_Z - 0.12), 180.0, 2, 77)
	HorrorProps.sinister_poster(self, "POSTER_LOCKERS", "POSTER_LOCKERS_DARK", Vector3(3.6, 1.95, HALL_Z - 0.14), 180.0, 0.14, 1.4)
	# Molinete (2 trípodes + lector) a lo ancho del hall: dos carriles libres; el tramo junto a la pared está cerrado.
	var m1 := SiteProps.tripod_cabinet(self, "MolineteP2", Vector3(MOL_X, 0, -1.0), -1.0)
	m1.rotation_degrees.y = 90.0
	var m2 := SiteProps.tripod_cabinet(self, "MolineteP2b", Vector3(MOL_X, 0, 0.2), -1.0)
	m2.rotation_degrees.y = 90.0
	var rd := SiteProps.tall_reader(self, "LectorP2", Vector3(MOL_X, 0, 1.28))
	rd.scale = Vector3(0.7, 0.85, 0.7)
	rd.rotation_degrees.y = 90.0
	Greybox.invisible_box(self, "MolineteP2Cierre", Vector3(MOL_X, 0.65, -1.31), Vector3(1.1, 1.3, 0.38))
	Greybox.box(self, "StickerCelular", Vector3(MOL_X + 0.56, 1.62, HALL_Z - 0.11), Vector3(0.22, 0.22, 0.004), Color(0.92, 0.92, 0.9), false)
	var cel := Greybox.label(self, "", Vector3(MOL_X + 0.56, 1.62, HALL_Z - 0.115), 0.05, Color(0.6, 0.08, 0.08), PI)
	cel.text = tr("Q5_SIN_CELULAR")
	cel.outline_size = 0
	Greybox.light(self, Vector3(12.0, 2.3, -0.6), Color(0.85, 0.92, 1.0), 0.4, 6.0)  # relleno frío bajo


## 2.ª puerta de ascensor en el mármol (+z), mirando al hall: hojas inox cerradas y cartel de mantenimiento.
func _maint_elevator(pos: Vector3) -> void:
	var r := Node3D.new()
	r.name = "Ascensor2"
	r.position = pos
	r.rotation_degrees.y = 180.0
	add_child(r)
	var inox := Greybox.inox()
	for sx in [-0.45, 0.45]:
		Greybox.box(r, "Ascensor2Hoja%d" % int(sx * 10), Vector3(sx, 1.15, 0), Vector3(0.9, 2.3, 0.03), Greybox.INOX, false).material_override = inox
	Greybox.box(r, "Ascensor2Junta", Vector3(0, 1.15, 0.018), Vector3(0.015, 2.3, 0.01), Greybox.NEGRO, false)
	Greybox.box(r, "Ascensor2Marco", Vector3(0, 2.36, 0.02), Vector3(2.0, 0.08, 0.04), Greybox.NEGRO, false)
	Greybox.box(r, "Ascensor2Indicador", Vector3(0, 2.6, 0.02), Vector3(0.6, 0.24, 0.03), Greybox.NEGRO, false)
	var l := Greybox.label(r, "--", Vector3(0, 2.6, 0.04), 0.18, Greybox.AMBAR)
	l.outline_size = 0
	WorldObjects.signage(r, "ELEVATOR_MAINT", Vector3(0, 1.5, 0.04), 0.0, 0.16, Greybox.AMBAR)


## Cuarto de limpieza (x 6,6..8,6, z 1,5..4,2): puerta blanca con rejilla entreabierta, sin acceso; huellas de barro.
func _cleaning_room() -> void:
	var x := 7.65
	Greybox.floor_slab(self, "LimpiezaPiso", Vector2(7.6, 2.85), Vector2(2.0, 2.7), Color(0.3, 0.3, 0.3))
	Greybox.ceiling(self, "LimpiezaTecho", Vector2(7.6, 2.85), Vector2(2.0, 2.7), 2.7, Color(0.2, 0.2, 0.22))
	Greybox.box(self, "LimpiezaW", Vector3(6.6, 1.5, 2.85), Vector3(0.2, 3, 2.9), Greybox.GRIS)
	Greybox.box(self, "LimpiezaE", Vector3(FB_X0, 1.5, 2.85), Vector3(0.2, 3, 2.9), Greybox.GRIS)
	var hinge := Node3D.new()
	hinge.name = "LimpiezaBisagra"
	hinge.position = Vector3(x - 0.45, 0, HALL_Z)
	hinge.rotation_degrees.y = -16.0
	add_child(hinge)
	var leaf := Greybox.box(hinge, "LimpiezaHoja", Vector3(0.45, 1.05, 0), Vector3(0.88, 2.1, 0.05), Greybox.PUERTA_BLANCA, false)
	var lbl := Greybox.label(leaf, "LIMPIEZA", Vector3(0, 0.55, -0.03), 0.09, Color(0.15, 0.15, 0.15), PI)
	lbl.outline_size = 0
	Greybox.box(leaf, "Rejilla", Vector3(0, -0.8, -0.028), Vector3(0.4, 0.18, 0.005), Color(0.75, 0.74, 0.7), false)
	Greybox.invisible_box(self, "LimpiezaCierre", Vector3(x, 1.2, HALL_Z + 0.05), Vector3(0.9, 2.4, 0.2))
	Greybox.cylinder(self, "BaldeLimpieza", Vector3(x + 0.4, 0.18, 2.6), 0.17, 0.36, Color(0.85, 0.85, 0.2), false, 0.6, 0.0, 0.19)
	var palo := Greybox.cylinder(self, "Trapeador", Vector3(x + 0.3, 0.75, 2.9), 0.015, 1.5, Color(0.5, 0.5, 0.52), false)
	palo.rotation_degrees.z = 12.0
	Greybox.light(self, Vector3(x, 2.2, 2.9), Color(0.6, 0.7, 0.75), 0.25, 2.5)
	SiteProps.footprints(self, "HuellaLimpieza", Vector3(3.6, 0, -0.6), Vector3(x, 0, HALL_Z + 0.6), 0.55)


## Pasillo de casilleros (x −0,9..1,9, z −11..3,2): cubos de colores a los dos lados, vinílico claro, los 14 paneles
## separados del techo (distorsión «un panel más»), la entrada 2 de vidrio al norte y el pantry al sur.
func _lockers_corridor() -> void:
	var cz := (COR_Z0 + COR_Z1) * 0.5
	var cl := COR_Z1 - COR_Z0
	var cx := (COR_X0 + COR_X1) * 0.5
	Greybox.sfloor(self, "Casilleros", Vector2(cx, cz), Vector2(COR_X1 - COR_X0, cl), "vinilico_claro")
	Greybox.sceiling(self, "CasillerosTecho", Vector2(cx, cz), Vector2(COR_X1 - COR_X0, cl), 2.75, "baldosa_techo")
	Greybox.swall(self, "CasillerosParedW", Vector3(COR_X0, 1.4, cz), Vector3(0.2, 2.8, cl), "pared", Greybox.CREMA_P2)
	Greybox.swall(self, "CasillerosParedE_S", Vector3(COR_X1, 1.4, (COR_Z0 - HALL_Z) * 0.5), Vector3(0.2, 2.8, -HALL_Z - COR_Z0), "pared", Greybox.CREMA_P2)
	Greybox.swall(self, "CasillerosParedE_N", Vector3(COR_X1, 1.4, (HALL_Z + COR_Z1) * 0.5), Vector3(0.2, 2.8, COR_Z1 - HALL_Z), "pared", Greybox.CREMA_P2)
	Greybox.box(self, "CasillerosDintelHall", Vector3(COR_X1, 2.78, 0), Vector3(0.2, 0.06, HALL_Z * 2.0), Greybox.CREMA_P2, false)
	_cube_lockers()
	var locker := WorldObjects.simple(self, WorldObjects.Locker, "MiCasillero", "HUD_LOCKER", Vector3(-0.35, 0.9, -4.5), Vector3(0.1, 1.7, 0.9), Greybox.TEAL, 0.0, 0.3)
	Greybox.label(locker, GameState.agent.to_upper(), Vector3(0.12, 0.5, 0), 0.12, Greybox.BLANCO, PI * 0.5)
	var nro := Greybox.label(locker, "%02d" % (absi(GameState.agent.hash()) % 89 + 10), Vector3(0.12, 0.05, 0), 0.5, Color(1, 1, 1, 0.05), PI * 0.5)
	nro.outline_size = 10
	nro.outline_modulate = Color(0.91, 0.96, 0.96, 0.9)
	SiteProps._anchor(locker, Vector3(0.8, -0.9, 0), -90.0)
	Greybox.marker(self, "casillero", Vector3(0.45, 0, -4.5), 90.0)
	Greybox.one_sided(WorldObjects.signage(self, "SIGN_LOCKER", Vector3(-0.68, 2.35, 0.0), 90.0, 0.2))
	_lifted_planks(Vector3(0.5, 0, -7.5), 90.0, 3)
	Greybox.extinguisher(self, "ExtintorCasilleros", Vector3(-0.6, 0, -10.75), 17, true)
	panels_node = Node3D.new()
	panels_node.name = "Paneles"
	add_child(panels_node)
	_rebuild_panels()
	# Zona `pasillo_agua` (nombre de siempre, la usan la distorsión y los bots): el pasillo de casilleros. v0.3.2: sin
	# terminal Fonex (Joan: el AUX solo en las PCs de la sala).
	Zone.make(self, "pasillo_agua", Vector3(cx, 1.4, cz), Vector3(COR_X1 - COR_X0 - 0.2, 2.8, cl - 0.2))
	# Entrada 2: puerta doble de vidrio con marco negro y el sticker de sin celulares; hojas abiertas hacia el ala.
	for seg in [[COR_X0, -0.4], [1.4, COR_X1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		Greybox.box(self, "VidrioEntrada2_%d" % int(a * 10), Vector3((a + b) * 0.5, 1.4, COR_Z1), Vector3(b - a, 2.8, 0.05), Greybox.VIDRIO)
		Greybox.box(self, "StickerEntrada2_%d" % int(a * 10), Vector3((a + b) * 0.5, 1.5, COR_Z1 - 0.035), Vector3(0.2, 0.2, 0.004), Color(0.92, 0.92, 0.9), false)
		var st := Greybox.label(self, "", Vector3((a + b) * 0.5, 1.5, COR_Z1 - 0.04), 0.03, Color(0.6, 0.08, 0.08), PI)
		st.text = tr("Q5_SIN_CELULAR")
		st.outline_size = 0
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.width = 0.18 / st.pixel_size
	Greybox.box(self, "MarcoEntrada2", Vector3(cx, 2.78, COR_Z1), Vector3(COR_X1 - COR_X0, 0.06, 0.1), Greybox.MARCO_NEGRO, false)
	for hx in [[-0.4, -78.0], [1.4, 78.0]]:
		var h := Node3D.new()
		h.name = "HojaEntrada2_%d" % int(float(hx[0]) * 10)
		h.position = Vector3(float(hx[0]), 0, COR_Z1)
		h.rotation_degrees.y = float(hx[1])
		add_child(h)
		var sgn := 1.0 if float(hx[0]) < 0.0 else -1.0
		Greybox.box(h, "Vidrio", Vector3(sgn * 0.45, 1.35, 0), Vector3(0.9, 2.6, 0.03), Greybox.VIDRIO, false)
		Greybox.box(h, "Jalador", Vector3(sgn * 0.8, 1.1, 0.05), Vector3(0.03, 0.5, 0.03), Greybox.NEGRO, false)
	Greybox.light_panel(self, "LuzEntrada2", Vector3(cx, 2.7, 2.5), false, false)


func _rebuild_panels() -> void:
	for c in panels_node.get_children():
		c.queue_free()
	var z0 := COR_Z0 + 0.4
	var step := (COR_Z1 - 0.9 - z0) / panel_count
	for i in panel_count:
		var p := Greybox.light_panel(panels_node, "Panel%02d" % (i + 1), Vector3((COR_X0 + COR_X1) * 0.5, 2.7, z0 + step * (i + 0.5)), false, i == 9)
		p.scale.x = 0.45  # paneles separados (se cuentan: 14… o 15)


## Ala norte de la sala de operaciones (x −1,35..19,5, z 3,2/4,2..7,2): se entra por la puerta de vidrio de los
## casilleros (entrada 2) y llega a la sala por el paso del noroeste (x 18..19,5). Bench con sillas negras, mural de
## colores frente a la puerta, techo negro. Sin colisión en las sillas.
func _north_annex() -> void:
	var a := Greybox.sfloor(self, "AnexoN_A", Vector2((ANX_X0 + 6.6) * 0.5, (COR_Z1 + ANX_Z1) * 0.5), Vector2(6.6 - ANX_X0, ANX_Z1 - COR_Z1), "sala_gris")
	a.name = "AnexoN_A"
	Greybox.sfloor(self, "AnexoN_B", Vector2((6.6 + 19.5) * 0.5, (ANX_Z0 + ANX_Z1) * 0.5), Vector2(19.5 - 6.6, ANX_Z1 - ANX_Z0), "sala_gris")
	Greybox.sfloor(self, "PasoEntrada2", Vector2(18.75, 3.1), Vector2(1.5, 2.2), "sala_gris")
	Greybox.ceiling(self, "AnexoNTecho", Vector2(9.075, 5.2), Vector2(20.85, 4.0), 3.0, Color(0.02, 0.02, 0.022))
	Greybox.ceiling(self, "PasoEntrada2Techo", Vector2(18.75, 3.1), Vector2(1.5, 2.2), 3.0, Color(0.02, 0.02, 0.022))
	Greybox.duct(self, "DuctoAnexoN", Vector3(9.0, 2.8, 6.4), 19.0, 0.2, true, Color(0.06, 0.06, 0.065))
	var wh := Greybox.BLANCO_PARED
	Greybox.swall(self, "AnexoN_N", Vector3(9.075, 1.5, ANX_Z1), Vector3(21.05, 3, 0.2), "pared", wh)
	Greybox.swall(self, "AnexoN_W", Vector3(ANX_X0, 1.5, (COR_Z1 + ANX_Z1) * 0.5), Vector3(0.2, 3, ANX_Z1 - COR_Z1), "pared", wh)
	Greybox.swall(self, "AnexoN_E", Vector3(19.5, 1.5, 4.6), Vector3(0.2, 3, 5.2), "pared", wh)
	Greybox.swall(self, "AnexoN_S1", Vector3((ANX_X0 + COR_X0) * 0.5, 1.5, COR_Z1), Vector3(COR_X0 - ANX_X0, 3, 0.2), "pared", wh)
	Greybox.swall(self, "AnexoN_S2", Vector3((COR_X1 + 6.6) * 0.5, 1.5, COR_Z1), Vector3(6.6 - COR_X1, 3, 0.2), "pared", wh)
	Greybox.box(self, "AnexoN_S2b", Vector3(6.6, 1.5, 3.7), Vector3(0.2, 3, 1.0), Greybox.BLANCO_PARED)
	Greybox.swall(self, "AnexoN_S3", Vector3(7.6, 1.5, ANX_Z0), Vector3(2.0, 3, 0.2), "pared", wh)
	Greybox.swall(self, "AnexoN_S5", Vector3(15.15, 1.5, ANX_Z0), Vector3(5.7, 3, 0.2), "pared", wh)
	Greybox.box(self, "PasoEntrada2W", Vector3(ROOM_X0, 1.5, 2.85), Vector3(0.2, 3, 2.9), Greybox.BLANCO_PARED).material_override = Greybox.surf("pared", wh)
	Greybox.box(self, "PasoEntrada2Dintel", Vector3(18.75, 3.2, ROOM_Z1), Vector3(1.5, 0.4, 0.2), Greybox.BLANCO_PARED, false)
	# Mural de colores en la pared del fondo, frente a la puerta de vidrio (manchas teal, salmón, amarillo y azul).
	var mural := [[Color(0.18, 0.44, 0.52), -0.4, 1.8], [Color(0.82, 0.38, 0.36), 0.6, 1.3], [Color(0.85, 0.7, 0.2), 0.0, 0.8], [Color(0.25, 0.4, 0.7), 1.1, 2.1], [Color(0.53, 0.76, 0.68), -0.95, 1.1]]
	for i in mural.size():
		var mp := Greybox.box(self, "Mural%d" % i, Vector3(float(mural[i][1]), float(mural[i][2]), ANX_Z1 - 0.11), Vector3(0.7, 0.6, 0.01), mural[i][0], false)
		mp.rotation_degrees.z = 20.0 * i
	# Bench contra la pared norte (sillas negras de malla mirando a la pared): x 2,4..15,3.
	var n := 0
	for x in [2.4, 3.95, 5.5, 7.6, 9.15, 10.7, 12.25, 13.8, 15.35]:
		n += 1
		Greybox.cubicle(self, "N-%02d" % n, Vector3(x, 0, ANX_Z1 - 0.7), 180.0, 0 if n in [3, 7] else 1)
	for i in 4:
		Greybox.light_panel(self, "LuzAnexoN%d" % i, Vector3(1.0 + i * 5.0, 2.95, 5.4), false, i == 2)
	Greybox.light_panel(self, "LuzPasoEntrada2", Vector3(18.75, 2.95, 3.2), false, false)
	Greybox.extinguisher(self, "ExtintorPaso", Vector3(19.25, 0, 6.8), 18, true)
	Greybox.bin(self, "PapeleraAnexoN", Vector3(17.0, 0, 6.85), true)


## Sala de feedback (x 8,6..12,4, z 1,5..4,2; ID `sala_calibracion`): junto a la limpieza, detrás del mármol del hall; se
## entra desde el ala norte de la sala (vano en z 4,2). Mesa, dos sillas (la de Haime de espaldas al ladrillo y la tuya),
## monitor con el REC, teléfono fijo, frente de vidrio esmerilado, una sola luz fría.
func _feedback_room() -> void:
	var c := Vector2((FB_X0 + FB_X1) * 0.5, (HALL_Z + ANX_Z0) * 0.5)
	var sz := Vector2(FB_X1 - FB_X0, ANX_Z0 - HALL_Z)
	var piso := Greybox.floor_slab(self, "Calibracion", c, sz, Color(0.24, 0.26, 0.27))
	piso.material_override = Greybox.surf("sala_gris", Color(0.8, 0.82, 0.83))
	Greybox.ceiling(self, "CalibracionTecho", c, sz, 2.8, Color(0.55, 0.57, 0.57))
	Greybox.box(self, "Ladrillo", Vector3(FB_X0 + 0.11, 1.5, c.y), Vector3(0.02, 3, sz.y - 0.2), Color(0.3, 0.2, 0.18), false)
	Greybox.box(self, "CalibracionE", Vector3(FB_X1, 1.5, c.y), Vector3(0.2, 3, sz.y + 0.2), Color(0.3, 0.33, 0.34))
	# Frente de vidrio esmerilado hacia el ala norte, con el vano de entrada en x 11..12,3 (1,3 m: la rejilla de rutas
	# de 0,4 m no pasaba por un vano de 1 m).
	Greybox.box(self, "VidrioCalibracion", Vector3(9.8, 1.4, ANX_Z0), Vector3(2.4, 2.8, 0.06), ESMERILADO_P2)
	Greybox.box(self, "VidrioCalibracionAlto", Vector3(10.5, 2.9, ANX_Z0), Vector3(3.8, 0.2, 0.2), Greybox.BLANCO_PARED, false)
	Greybox.box(self, "VidrioCalibracionMarco", Vector3(10.5, 2.75, ANX_Z0), Vector3(3.8, 0.1, 0.12), Greybox.NEGRO, false)
	Greybox.box(self, "VidrioCalibracionFranja", Vector3(9.8, 1.3, ANX_Z0 + 0.04), Vector3(2.4, 0.18, 0.02), Color(0.5, 0.55, 0.56), false)
	Greybox.box(self, "VidrioCalibracionPilar", Vector3(FB_X1 - 0.05, 1.5, ANX_Z0), Vector3(0.1, 3, 0.2), Greybox.NEGRO)
	var cartel := WorldObjects.signage(self, "Q5_SALA_FEEDBACK", Vector3(11.65, 2.45, ANX_Z0 + 0.12), 0.0, 0.14, Greybox.CIAN)
	cartel.name = "CartelCalibracion"
	var grab := WorldObjects.signage(self, "SIGN_RECORDED", Vector3(11.65, 2.18, ANX_Z0 + 0.12), 0.0, 0.09, Greybox.ROJO)
	grab.name = "CartelGrabada"
	# Mesa con monitor (REC), teléfono fijo, grabadora y una caja de pañuelos (Haime en x 9,15, tú en x 11,1).
	var z := c.y
	Greybox.box(self, "MesaCalibracion", Vector3(10.1, 0.74, z), Vector3(0.9, 0.05, 1.6), Color(0.62, 0.62, 0.6))
	Greybox.box(self, "MesaCalibracionPata", Vector3(10.1, 0.36, z), Vector3(0.1, 0.72, 1.2), Greybox.NEGRO, false)
	Greybox.box(self, "SillaQA", Vector3(9.15, 0.47, z), Vector3(0.48, 0.06, 0.48), Greybox.NEGRO, false)
	Greybox.box(self, "SillaQAResp", Vector3(8.9, 0.9, z), Vector3(0.05, 0.75, 0.48), Greybox.NEGRO, false)
	Greybox.box(self, "SillaAgente", Vector3(11.1, 0.45, z), Vector3(0.44, 0.05, 0.44), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "SillaAgenteResp", Vector3(11.32, 0.72, z), Vector3(0.04, 0.5, 0.44), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "MonitorQA", Vector3(9.85, 1.0, z + 0.25), Vector3(0.04, 0.36, 0.56), Color(0.05, 0.05, 0.07), false, 0.2)
	var rec := Greybox.box(self, "RecPunto", Vector3(9.88, 1.12, z + 0.43), Vector3(0.012, 0.05, 0.05), Greybox.ROJO, false, 4.0)
	var blink := _Blink.new()
	blink.name = "RecParpadeo"
	blink.target = rec
	rec.add_child(blink)
	var rec_txt := Greybox.label(self, "REC", Vector3(9.88, 1.12, z + 0.3), 0.05, Greybox.ROJO, PI * 0.5)
	rec_txt.name = "RecTexto"
	var cal := Greybox.label(self, "", Vector3(9.88, 0.96, z + 0.25), 0.04, Color(0.75, 0.8, 0.8), PI * 0.5)
	cal.text = tr("QA_SCREEN")
	Greybox.box(self, "TelefonoFijo", Vector3(10.0, 0.8, z - 0.55), Vector3(0.22, 0.07, 0.2), Color(0.12, 0.12, 0.13), false)
	Greybox.box(self, "TelefonoAuricular", Vector3(10.0, 0.85, z - 0.55), Vector3(0.06, 0.04, 0.22), Color(0.1, 0.1, 0.11), false)
	Greybox.box(self, "Grabadora", Vector3(10.3, 0.79, z + 0.5), Vector3(0.12, 0.04, 0.08), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "Panuelos", Vector3(10.4, 0.82, z - 0.5), Vector3(0.22, 0.1, 0.12), Greybox.BLANCO, false)
	Greybox.box(self, "PanueloAsoma", Vector3(10.4, 0.9, z - 0.5), Vector3(0.08, 0.06, 0.01), Greybox.BLANCO, false)
	# Pizarra con las "oportunidades de mejora" de alguien que ya no trabaja aquí (sobre el ladrillo, detrás de Haime).
	Greybox.box(self, "PizarraQA", Vector3(FB_X0 + 0.14, 1.6, z), Vector3(0.04, 1.1, 2.0), Greybox.BLANCO, false, 0.1)
	var opm := Greybox.label(self, "", Vector3(FB_X0 + 0.17, 1.62, z), 0.07, Color(0.6, 0.1, 0.1), PI * 0.5)
	opm.text = tr("QA_BOARD")
	Greybox.light_panel(self, "LuzCalibracion", Vector3(10.1, 2.75, z), false, true)
	var relleno := Greybox.light(self, Vector3(11.9, 2.4, z - 0.4), Color(0.82, 0.9, 1.0), 0.75, 7.0)
	relleno.name = "LuzCalibracionRelleno"
	var luz_rec := Greybox.light(self, Vector3(9.9, 1.05, z + 0.3), Color(0.9, 0.15, 0.12), 0.25, 1.6)
	luz_rec.name = "LuzRec"
	var seat := WorldObjects.TrainingSeat.new()
	seat.name = "Seat_calibracion"
	seat.seat_id = "calibracion"
	seat.hint_key = "HUD_SIT"
	seat.size = Vector3(0.8, 1.2, 0.8)
	seat.position = Vector3(11.1, 0.8, z)
	seat.rotation_degrees.y = 90.0  # mira hacia Haime (−X)
	add_child(seat)
	Greybox.marker(self, "sala_calibracion", Vector3(11.65, 0, 3.4), 90.0)
	Greybox.marker(self, "haime_sitio", Vector3(9.15, 0, z), -90.0)
	Zone.make(self, "sala_calibracion", Vector3(c.x, 1.4, c.y), Vector3(sz.x - 0.2, 2.8, sz.y - 0.2))
	HorrorProps.note(self, "NOTE_CALIBRATION", Vector3(9.3, 1.2, ANX_Z0 - 0.05), 180.0, true, -8.0)


## Pantry (x −3,4..5,4, z −14..−11): paredes teal, 2 refris inox + lavadero a la izquierda al salir de los casilleros,
## máquina de agua, la entrada 1 de vidrio (con sticker) al ala suroeste, la sala auxiliar al oeste y el pasillo corto
## de baños al sur.
func _pantry() -> void:
	var c := Vector2((PANTRY_X0 + PANTRY_X1) * 0.5, (PANTRY_Z0 + PANTRY_Z1) * 0.5)
	var sz := Vector2(PANTRY_X1 - PANTRY_X0, PANTRY_Z1 - PANTRY_Z0)
	Greybox.sfloor(self, "Pantry", c, sz, "vinilico_claro")
	Greybox.sceiling(self, "PantryTecho", c, sz, 2.75, "baldosa_techo")
	var t := Greybox.TEAL
	Greybox.swall(self, "PantryN_A", Vector3((PANTRY_X0 + COR_X0) * 0.5, 1.4, PANTRY_Z1), Vector3(COR_X0 - PANTRY_X0, 2.8, 0.2), "pared", t)
	Greybox.swall(self, "PantryN_B", Vector3((COR_X1 + PANTRY_X1) * 0.5, 1.4, PANTRY_Z1), Vector3(PANTRY_X1 - COR_X1, 2.8, 0.2), "pared", t)
	Greybox.swall(self, "PantryS_A", Vector3((PANTRY_X0 + BCOR_X0) * 0.5, 1.4, PANTRY_Z0), Vector3(BCOR_X0 - PANTRY_X0, 2.8, 0.2), "pared", t)
	Greybox.swall(self, "PantryS_B", Vector3((BCOR_X1 + PANTRY_X1) * 0.5, 1.4, PANTRY_Z0), Vector3(PANTRY_X1 - BCOR_X1, 2.8, 0.2), "pared", t)
	Greybox.swall(self, "PantryW_S", Vector3(PANTRY_X0, 1.4, -13.5), Vector3(0.2, 2.8, 1.0), "pared", t)
	Greybox.swall(self, "PantryW_N", Vector3(PANTRY_X0, 1.4, -11.5), Vector3(0.2, 2.8, 1.0), "pared", t)
	Greybox.box(self, "PantryW_Dintel", Vector3(PANTRY_X0, 2.45, -12.5), Vector3(0.2, 0.7, 1.0), t, false)
	Greybox.swall(self, "PantryE_S", Vector3(PANTRY_X1, 1.4, -13.65), Vector3(0.2, 2.8, 0.7), "pared", t)
	Greybox.swall(self, "PantryE_N", Vector3(PANTRY_X1, 1.4, -11.4), Vector3(0.2, 2.8, 0.8), "pared", t)
	Greybox.box(self, "PantryE_Dintel", Vector3(PANTRY_X1, 2.7, -12.55), Vector3(0.2, 0.2, 1.5), Greybox.MARCO_NEGRO, false)
	# Entrada 1: vidrio con marco negro, jalador en D y el sticker de sin celulares; hojas abiertas hacia el ala.
	for hz in [[-13.3, 80.0], [-11.8, -80.0]]:
		var h := Node3D.new()
		h.name = "HojaEntrada1_%d" % int(-float(hz[0]) * 10)
		h.position = Vector3(PANTRY_X1, 0, float(hz[0]))
		h.rotation_degrees.y = float(hz[1])
		add_child(h)
		var sgn := 1.0 if float(hz[0]) < -12.5 else -1.0
		Greybox.box(h, "Vidrio", Vector3(0, 1.3, sgn * 0.37), Vector3(0.03, 2.5, 0.74), Greybox.VIDRIO, false)
		Greybox.box(h, "Jalador", Vector3(0.05, 1.1, sgn * 0.65), Vector3(0.04, 0.5, 0.06), Greybox.NEGRO, false)
		Greybox.box(h, "Sticker", Vector3(-0.02, 1.5, sgn * 0.37), Vector3(0.004, 0.2, 0.2), Color(0.92, 0.92, 0.9), false)
	var st := Greybox.label(self, "", Vector3(PANTRY_X1 - 0.12, 2.25, -12.55), 0.035, Color(0.6, 0.08, 0.08), -PI * 0.5)
	st.text = tr("Q5_SIN_CELULAR")
	st.outline_size = 0
	SiteProps.fridge(self, "Refri1", Vector3(-2.95, 0, -11.5), 180.0)
	SiteProps.fridge(self, "Refri2", Vector3(-2.2, 0, -11.5), 180.0)
	SiteProps.sink(self, "LavaderoP2", Vector3(-1.3, 0, -11.45), 180.0)
	Greybox.box(self, "RepisaRefris", Vector3(-2.2, 2.25, -11.25), Vector3(2.0, 0.04, 0.35), Greybox.BLANCO, false)
	WorldObjects.simple(self, WorldObjects.WaterCooler, "MaquinaAgua", "HUD_WATER", Vector3(3.3, 0.6, -11.4), Vector3(0.4, 1.2, 0.4), Color(0.4, 0.6, 0.8))
	Greybox.bin(self, "PapeleraPantry", Vector3(-0.55, 0, -13.7), true)
	Greybox.box(self, "Termostato", Vector3(-0.55, 1.5, PANTRY_Z0 + 0.12), Vector3(0.1, 0.12, 0.03), Color(0.85, 0.85, 0.82), false)
	Greybox.light_panel(self, "LuzPantry", Vector3(c.x, 2.7, c.y), false, false)
	Greybox.light(self, Vector3(-1.8, 2.3, -12.2), Color(1.0, 0.94, 0.86), 0.6, 5.0)
	Zone.make(self, "vinilico", Vector3(c.x, 1.4, c.y), Vector3(sz.x - 0.2, 2.8, sz.y - 0.2))


## Sala auxiliar (x −6,7..−3,4, z −16,3..−7,9): ahí van los agentes cuando no hay PC libre en la sala, y ahí está el
## puesto del RTA (el Perrito: 3 monitores de gráficos). Se entra por el pantry.
func _aux_room() -> void:
	var c := Vector2((AUX_X0 + PANTRY_X0) * 0.5, (AUX_Z0 + AUX_Z1) * 0.5)
	var sz := Vector2(PANTRY_X0 - AUX_X0, AUX_Z1 - AUX_Z0)
	Greybox.sfloor(self, "SalaAuxiliar", c, sz, "sala_gris")
	Greybox.sceiling(self, "SalaAuxiliarTecho", c, sz, 2.75, "baldosa_techo", Color(0.88, 0.88, 0.86))
	var wh := Greybox.BLANCO_PARED
	Greybox.swall(self, "AuxW", Vector3(AUX_X0, 1.4, c.y), Vector3(0.2, 2.8, sz.y + 0.2), "pared", wh)
	Greybox.swall(self, "AuxN", Vector3(c.x, 1.4, AUX_Z1), Vector3(sz.x, 2.8, 0.2), "pared", wh)
	Greybox.swall(self, "AuxS", Vector3(c.x, 1.4, AUX_Z0), Vector3(sz.x, 2.8, 0.2), "pared", wh)
	Greybox.swall(self, "AuxE_S", Vector3(PANTRY_X0, 1.4, (AUX_Z0 + PANTRY_Z0) * 0.5), Vector3(0.2, 2.8, PANTRY_Z0 - AUX_Z0), "pared", wh)
	Greybox.swall(self, "AuxE_N", Vector3(PANTRY_X0, 1.4, (PANTRY_Z1 + AUX_Z1) * 0.5), Vector3(0.2, 2.8, AUX_Z1 - PANTRY_Z1), "pared", wh)
	var hinge := Node3D.new()
	hinge.name = "AuxBisagra"
	hinge.position = Vector3(PANTRY_X0, 0, -12.95)
	hinge.rotation_degrees.y = -95.0
	add_child(hinge)
	Greybox.box(hinge, "AuxHoja", Vector3(0, 1.05, 0.45), Vector3(0.05, 2.1, 0.88), Greybox.PUERTA_BLANCA, false)
	Greybox.one_sided(WorldObjects.signage(self, "Q5_SALA_AUX", Vector3(PANTRY_X0 + 0.12, 2.35, -12.5), 90.0, 0.12, Greybox.GRIS_OSCURO))
	# Puesto del RTA contra la pared oeste (marcador = la silla, mirando a sus pantallas).
	var rz := -14.2
	Greybox.box(self, "EscritorioRTA", Vector3(-6.1, 0.74, rz), Vector3(0.9, 0.04, 1.8), Greybox.ROBLE, false).material_override = Greybox.surf("roble")
	for k in 3:
		var mon := Greybox.box(self, "MonitorRTA%d" % k, Vector3(-6.4, 1.05, rz - 0.6 + k * 0.6), Vector3(0.03, 0.32, 0.54), Color(0.15, 0.35, 0.3), false, 0.8)
		mon.rotation_degrees.y = (k - 1) * -12.0
	Greybox.box(self, "SillaRTA", Vector3(-5.4, 0.5, rz), Vector3(0.6, 0.1, 0.6), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "SillaRTAResp", Vector3(-5.1, 0.85, rz), Vector3(0.06, 0.6, 0.56), Greybox.NEGRO, false)
	Greybox.label(self, "RTA", Vector3(-5.63, 0.62, rz), 0.07, Greybox.CIAN, PI * 0.5)
	Greybox.marker(self, "escritorio_rta", Vector3(-5.4, 0, rz), 90.0)
	# Puestos sin PC para los agentes que no encontraron sitio en la sala (contra la pared este, al norte de la puerta).
	Greybox.cubicle(self, "AUX-1", Vector3(-4.15, 0, -9.0), -90.0, 0)
	Greybox.cubicle(self, "AUX-2", Vector3(-4.15, 0, -10.6), -90.0, 1)
	Greybox.cubicle(self, "AUX-3", Vector3(-5.95, 0, -9.0), 90.0, 0)
	Greybox.light_panel(self, "LuzAuxiliar0", Vector3(c.x, 2.7, -10.0), false, true)
	Greybox.light_panel(self, "LuzAuxiliar1", Vector3(c.x, 2.7, -14.4), false, false)


## Bloque de baños al sur del pantry (Corregido por Joan 16:19Z/16:26Z): pasillo corto y central (x −0,15..1,25,
## z −17..−14); entrando, hombres a la DERECHA (+x, hasta la pared del ala), mujeres a la IZQUIERDA y la sala del
## personal de limpieza al FRENTE (cerrada, puerta blanca con el pictograma accesible). Llega a la pared exterior.
func _bathroom_block() -> void:
	var cx := (BCOR_X0 + BCOR_X1) * 0.5
	Greybox.sfloor(self, "PasilloBanos", Vector2(cx, -15.5), Vector2(BCOR_X1 - BCOR_X0, 3.0), "vinilico_claro")
	Greybox.sceiling(self, "PasilloBanosTecho", Vector2(cx, -15.5), Vector2(BCOR_X1 - BCOR_X0, 3.0), 2.6, "baldosa_techo")
	var bz := (BATH_Z0 - 14.1) * 0.5
	add_bathroom("bano_p2", Vector3((BCOR_X1 + PANTRY_X1) * 0.5, 0, bz), Vector2(PANTRY_X1 - BCOR_X1, -14.1 - BATH_Z0), false, "w", -15.85 - bz)
	add_bathroom("bano_p2_m", Vector3((-2.75 + BCOR_X0) * 0.5, 0, bz), Vector2(BCOR_X0 + 2.75, -14.1 - BATH_Z0), false, "e", -15.85 - bz, false)
	SiteProps.pictogram(self, Vector3(BCOR_X1 - 0.12, 1.5, -15.05), -90.0, "circulo")
	SiteProps.pictogram(self, Vector3(BCOR_X0 + 0.12, 1.5, -16.65), 90.0, "triangulo")
	# Sala del personal de limpieza (al frente): pared con la puerta blanca cerrada; adentro, oscuro.
	Greybox.box(self, "LimpiezaPersonalPared", Vector3(cx, 1.3, -17.0), Vector3(BCOR_X1 - BCOR_X0, 2.6, 0.12), Greybox.BLANCO_PARED)
	var hoja := Greybox.box(self, "LimpiezaPersonalHoja", Vector3(cx, 1.05, -16.92), Vector3(0.9, 2.1, 0.04), Greybox.PUERTA_BLANCA, false)
	Greybox.box(hoja, "Manija", Vector3(0.35, -0.05, 0.03), Vector3(0.12, 0.03, 0.03), Greybox.INOX, false)
	SiteProps.pictogram(self, Vector3(cx, 1.5, -16.89), 0.0, "accesible")
	Greybox.floor_slab(self, "LimpiezaPersonalPiso", Vector2(cx, (BATH_Z0 - 17.0) * 0.5), Vector2(BCOR_X1 - BCOR_X0, -17.0 - BATH_Z0), Color(0.3, 0.3, 0.3))
	Greybox.box(self, "LimpiezaPersonalFondo", Vector3(cx, 1.3, BATH_Z0), Vector3(BCOR_X1 - BCOR_X0, 2.6, 0.2), Greybox.GRIS)
	Greybox.extinguisher(self, "ExtintorBanos1", Vector3(BCOR_X1 - 0.25, 0, -14.4), 17, true)
	Greybox.extinguisher(self, "ExtintorBanos2", Vector3(BCOR_X1 - 0.25, 0, -14.85), 17, false)
	Greybox.downlight(self, "DownPasilloBanos", Vector3(cx, 2.58, -15.5), Color(1.0, 0.95, 0.88), 0.7, 4.5)
	Zone.make(self, "vinilico", Vector3(cx, 1.3, -15.5), Vector3(BCOR_X1 - BCOR_X0 - 0.2, 2.6, 2.8))


## Ala suroeste de la sala (x 5,4..18, z −20..−11): la entrada 1 desde el pantry; bench en filas (sillas negras),
## techo negro como la sala, abierta a la sala por su pared oeste (z −19,5..−11,2). El pasillo de entrada (z ≈ −12,6)
## sigue el pasillo de la fila A-B de la sala.
func _southwest_annex() -> void:
	var c := Vector2((PANTRY_X1 + ROOM_X0) * 0.5, (ROOM_Z0 + PANTRY_Z1) * 0.5)
	var sz := Vector2(ROOM_X0 - PANTRY_X1, PANTRY_Z1 - ROOM_Z0)
	Greybox.sfloor(self, "AnexoSO", c, sz, "sala_gris")
	Greybox.ceiling(self, "AnexoSOTecho", c, sz, 3.4, Color(0.02, 0.02, 0.022))
	Greybox.duct(self, "DuctoAnexoSO", Vector3(c.x, 3.15, -16.0), sz.x - 0.5, 0.25, true, Color(0.06, 0.06, 0.065))
	var wh := Greybox.BLANCO_PARED
	Greybox.swall(self, "AnexoSO_N", Vector3(c.x, 1.7, PANTRY_Z1), Vector3(sz.x, 3.4, 0.2), "pared", wh)
	Greybox.swall(self, "AnexoSO_S", Vector3(c.x, 1.7, ROOM_Z0), Vector3(sz.x + 0.2, 3.4, 0.2), "pared", wh)
	Greybox.box(self, "AnexoSO_W", Vector3(PANTRY_X1, 1.7, -19.95), Vector3(0.2, 3.4, 0.3), Greybox.BLANCO_PARED)
	Greybox.box(self, "AnexoSO_WAlto", Vector3(PANTRY_X1, 3.0, -15.5), Vector3(0.2, 0.8, 9.0), Greybox.BLANCO_PARED, false)
	# Bench doble (z −15,6) y una fila contra la pared sur; x 16..18 queda libre para cruzar a la sala.
	var n := 0
	for x in [6.6, 8.15, 9.7, 11.25, 12.8]:
		n += 1
		Greybox.cubicle(self, "SO-%02d" % n, Vector3(x, 0, -15.0), 0.0, 1)
		n += 1
		Greybox.cubicle(self, "SO-%02d" % n, Vector3(x, 0, -16.2), 180.0, 0 if n == 4 else 1)
	for x in [8.15, 9.7, 11.25, 12.8]:
		n += 1
		Greybox.cubicle(self, "SO-%02d" % n, Vector3(x, 0, ROOM_Z0 + 0.75), 0.0, 1)
	for i in 3:
		Greybox.light_panel(self, "LuzAnexoSO%d" % i, Vector3(7.5 + i * 4.5, 3.3, -13.6), i == 1, i == 2)
	Greybox.light_panel(self, "LuzAnexoSO3", Vector3(11.0, 3.3, -18.2), false, false)
	Greybox.light(self, Vector3(16.8, 2.8, -15.5), Color(0.85, 0.92, 1.0), 0.9, 7.5).name = "LuzAnexoSOBoca"  # la boca a la sala
	Greybox.bin(self, "PapeleraAnexoSO", Vector3(14.3, 0, -11.35), true)


## Capa de horror de oficina del piso 2 (genérica, sin colisión, fuera de rutas y marcadores).
func _horror_p2() -> void:
	OfficeHorror.tube(self, "TuboMuertoHall", Vector3(16.0, 2.72, 0.6), true, false)
	OfficeHorror.stained_tile(self, Vector3(-0.2, 2.745, -8.3))
	OfficeHorror.stained_tile(self, Vector3(-2.1, 2.745, -13.1), Vector2(0.6, 0.9))
	OfficeHorror.hanging_tile(self, Vector3(4.3, 2.74, -13.3), 90.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_1", Vector3(-0.38, 1.62, -3.6), 90.0, true, 6.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_3", Vector3(1.38, 1.2, -6.9), -90.0, false, -5.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_4", Vector3(BCOR_X1 - 0.12, 1.75, -16.6), -90.0, true, 4.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_2", Vector3(-3.53, 1.35, -9.3), -90.0, false, 7.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_6", Vector3(PANTRY_X0 + 0.12, 1.6, -13.7), 90.0, true, -3.0)
	OfficeHorror.tube(self, "TuboTartamudoAnexoN", Vector3(13.5, 2.97, 5.2), true, true)
	OfficeHorror.headset(self, Vector3(9.15, 0.74, ANX_Z1 - 0.68), 180.0)
	OfficeHorror.chair_to_wall(self, Vector3(14.3, 0, ROOM_Z0 + 0.55), 0.0)
	OfficeHorror.scratched_kpi(self, Vector3(10.0, 1.75, PANTRY_Z1 - 0.13), 180.0)
	OfficeHorror.jammed_printer(self, Vector3(17.6, 0, ANX_Z1 - 0.45), 180.0)
	OfficeHorror.moldy_cup(self, Vector3(-3.8, 0.75, -10.05))
	OfficeHorror.disconnected_monitor(self, Vector3(-3.6, 1.07, -9.0), -90.0)
	OfficeHorror.disconnected_monitor(self, Vector3(8.15, 1.07, -15.78), 180.0)
	OfficeHorror.sticky(self, "Q5_H_NOTA_5", Vector3(12.6, 1.0, -15.57), 0.0, false, 5.0)


## Rutas (Shero, RTA, Haime, P5): la rejilla de la sala (49 nodos, conectados solo por sus pasillos), el sitio de Shero
## y el resto del piso con aristas explícitas (por cercanía se cruzaban paredes: el hall y el ala norte quedan a 5 m).
const _WP_EXTRA: Array[Vector3] = [
	Vector3(MOL_X, 0, -0.4), Vector3(5.2, 0, 0.0), Vector3(9.5, 0, 0.0), Vector3(14.6, 0, 0.6), Vector3(17.0, 0, 0.0),  # 0-4 hall
	Vector3(0.5, 0, -0.4), Vector3(0.5, 0, 2.3), Vector3(0.5, 0, -4.5), Vector3(0.5, 0, -10.2),  # 5-8 casilleros
	Vector3(0.5, 0, 4.0), Vector3(4.0, 0, 4.4), Vector3(8.5, 0, 4.9), Vector3(11.65, 0, 4.9), Vector3(15.5, 0, 4.9), Vector3(18.75, 0, 4.9), Vector3(18.75, 0, 2.8),  # 9-15 ala norte
	Vector3(11.65, 0, 3.4),  # 16 sala de feedback
	Vector3(0.5, 0, -12.5), Vector3(4.3, 0, -12.55), Vector3(-2.6, 0, -12.5),  # 17-19 pantry
	Vector3(-4.3, 0, -12.5), Vector3(-4.7, 0, -14.2), Vector3(-4.9, 0, -10.5),  # 20-22 sala auxiliar
	Vector3(0.55, 0, -14.6), Vector3(0.55, 0, -16.3),  # 23-24 pasillo de baños
	Vector3(6.6, 0, -12.6), Vector3(11.0, 0, -12.6), Vector3(16.6, 0, -12.6), Vector3(16.8, 0, -17.6),  # 25-28 ala suroeste
]
const _WP_LINKS: Array = [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [5, 7], [7, 8], [6, 9], [9, 10], [10, 11], [11, 12],
	[12, 13], [13, 14], [14, 15], [12, 16], [8, 17], [17, 18], [17, 19], [19, 20], [20, 21], [20, 22], [17, 23], [23, 24],
	[18, 25], [25, 26], [26, 27], [27, 28]]
## Enganches con la rejilla de la sala: [extra, fila (0..6), columna (0..6)].
const _WP_ROOM: Array = [[15, 6, 0], [27, 2, 0], [28, 1, 0]]


func _p2_waypoints() -> void:
	waypoints.clear()
	for r in ROWS.size() + 1:
		var z := ROOM_Z0 + 0.9 + r * 3.2
		for ix in AISLE_XS.size():
			waypoints.append(Vector3(AISLE_XS[ix], 0, z))
	waypoints.append(Vector3(46.9, 0, -9))
	for p in _WP_EXTRA:
		waypoints.append(p)


## Siseo de la ventilación (Q3) del lado de la operación: desde el molinete (x 2,6) hacia dentro; el hall queda en
## silencio. Zonas sin solaparse (5 cm de separación) para que entrar a una y salir de otra no se pisen.
func _p2_zones() -> void:
	Zone.make(self, "ventilacion_casilleros", Vector3((COR_X0 + MOL_X) * 0.5, 1.4, (COR_Z0 + 0.05 + COR_Z1) * 0.5), Vector3(MOL_X - COR_X0, 2.8, COR_Z1 - COR_Z0 - 0.05))
	Zone.make(self, "ventilacion_anexo_n", Vector3((ANX_X0 + 19.5) * 0.5, 1.4, (COR_Z1 + 0.05 + ANX_Z1) * 0.5), Vector3(19.5 - ANX_X0, 2.8, ANX_Z1 - COR_Z1 - 0.05))
	Zone.make(self, "ventilacion_paso", Vector3(18.75, 1.4, (ROOM_Z1 + COR_Z1) * 0.5), Vector3(1.5, 2.8, COR_Z1 - ROOM_Z1 - 0.1))
	Zone.make(self, "ventilacion_pantry", Vector3((PANTRY_X0 + PANTRY_X1) * 0.5, 1.4, (PANTRY_Z0 + PANTRY_Z1) * 0.5), Vector3(PANTRY_X1 - PANTRY_X0, 2.8, PANTRY_Z1 - PANTRY_Z0))
	Zone.make(self, "ventilacion_auxiliar", Vector3((AUX_X0 + PANTRY_X0 - 0.05) * 0.5, 1.4, (AUX_Z0 + AUX_Z1) * 0.5), Vector3(PANTRY_X0 - 0.05 - AUX_X0, 2.8, AUX_Z1 - AUX_Z0))
	Zone.make(self, "ventilacion_anexo_so", Vector3((PANTRY_X1 + 0.05 + ROOM_X0 - 0.05) * 0.5, 1.7, (ROOM_Z0 + PANTRY_Z1) * 0.5), Vector3(ROOM_X0 - PANTRY_X1 - 0.1, 3.4, PANTRY_Z1 - ROOM_Z0))
	Zone.make(self, "ventilacion_sala", Vector3(33.0, 1.7, -9.025), Vector3(30.0, 3.4, 21.95))
	# C15: pasos en vinílico (casilleros; el pantry y el pasillo de baños los marca su función).
	Zone.make(self, "vinilico", Vector3((COR_X0 + COR_X1) * 0.5, 1.4, (COR_Z0 + COR_Z1) * 0.5), Vector3(COR_X1 - COR_X0 - 0.2, 2.8, COR_Z1 - COR_Z0 - 0.1))


## v0.4 · Derrumbe progresivo del site (Piso 2) durante todo el Sabado hasta completar el turno.
class _SiteCollapseController extends Node:
	var floor_ref: FloorBase = null
	var _stage: int = 0
	var _tremor_t: float = 8.0
	var _debris_count: int = 0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		_rng.seed = 66606

	func _process(delta: float) -> void:
		if floor_ref == null or not is_instance_valid(floor_ref) or not GameState.running or GameState.shift_over:
			return
		var prog := clampf(GameState.clock_seconds / maxf(GameState.shift_end_seconds(), 1.0), 0.0, 1.0)
		var want_stage := 1 + int(floorf(prog * 5.0))
		while _stage < want_stage and _stage < 5:
			_stage += 1
			_advance_collapse(_stage)
		_tremor_t -= delta
		if _tremor_t <= 0.0:
			_tremor_t = lerpf(14.0, 4.2, prog)
			GfxLens.kick(0.22 + prog * 0.55, 0.65)
			if _rng.randf() < 0.65:
				AudioManager.play_sfx("silla_crujido_largo" if _rng.randf() < 0.5 else "golpes_puerta_lejanos", "Sala")
			_drop_ceiling_debris()

	func _advance_collapse(st: int) -> void:
		GfxLens.kick(0.45 + st * 0.1, 1.2)
		AudioManager.play_sfx("fluorescente_estallido", "Sala")
		for _i in 3:
			_drop_ceiling_debris()
		match st:
			1:
				EventBus.ezlak_post.emit("#site-updates", "sistema", "⚠️ Falla eléctrica en ala norte del Piso 2. Mantengan Available.", {"tipo": "programado"})
			2:
				_wreck_row("A", 14.0)
				_wreck_row("F", -14.0)
				AudioManager.play_sfx("impresora_atasco_grito", "Sala")
			3:
				GfxDirector.emergency(true)
				_wreck_row("B", 11.0)
				EventBus.ezlak_post.emit("#team-familia", "sistema", "🚨 ALERTA ESTRUCTURAL PISO 2 — NO ABANDONE SU ISLA.", {"tipo": "programado", "mention": true})
			4:
				GfxDirector.blackout(3.5, 0.04)
				_wreck_row("E", -11.0)
				AudioManager.play_sfx("fluorescente_estallido", "Sala")
			5:
				GfxDirector.emergency(true)
				_wreck_row("D", -8.0)
				EventBus.ezlak_post.emit("#site-updates", "sistema", "⛔ COLAPSO INMINENTE — EL TURNO TERMINA A LAS 08:45.", {"tipo": "programado", "mention": true})

	func _drop_ceiling_debris() -> void:
		if _debris_count > 48:
			return
		_debris_count += 1
		var dx := _rng.randf_range(19.5, 45.5)
		var dz := _rng.randf_range(-18.5, 0.8)
		# Evita bloquear el asiento C-14 directamente
		if absf(dz - (-11.1)) < 1.3 and absf(dx - 41.45) < 1.5:
			dz += 2.2
		OfficeHorror.hanging_tile(floor_ref, Vector3(dx, 3.25, dz), _rng.randf_range(0.0, 360.0))
		var slab := Greybox.box(floor_ref, "Escombro_%d" % _debris_count, Vector3(dx, 0.08, dz), Vector3(_rng.randf_range(0.45, 1.1), 0.14, _rng.randf_range(0.45, 1.0)), Color(0.14, 0.15, 0.16), false)
		slab.rotation_degrees = Vector3(_rng.randf_range(-12.0, 12.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-12.0, 12.0))

	func _wreck_row(row_letter: String, tilt_deg: float) -> void:
		for i in range(1, 17):
			var seat_id := "%s-%02d" % [row_letter, i]
			var s := floor_ref.seat_by_id(seat_id)
			if s != null and s.get_parent() is Node3D:
				var cub := s.get_parent() as Node3D
				cub.rotation_degrees.z = _rng.randf_range(-tilt_deg, tilt_deg)
				cub.rotation_degrees.x = _rng.randf_range(-6.0, 6.0)


## v0.4.1 · Jueves (Turno 4): Papayala ocupa C-14 al volver del lunch hasta que lo desalojas con [E].
class _PapayalaSeatEvent extends Node3D:
	var floor_ref: FloorBase = null
	var pap_actor: P5Actor = null
	var _evict_trigger: Interactable = null
	var _occupied: bool = false
	var _resolved: bool = false

	func _process(_delta: float) -> void:
		if _resolved or floor_ref == null or not GameState.logged_in or GameState.shift_over:
			return
		var trigger_clock := GameState.lunch_clock() + 30.0 * 60.0
		if not _occupied and GameState.seated_at == "" and (GameState.clock_seconds >= trigger_clock or bool(GameState.flags.get("lunch_taken", false))):
			_occupy_c14()

	func _occupy_c14() -> void:
		_occupied = true
		var s14 := floor_ref.seat_by_id("C-14")
		if s14 != null:
			s14.enabled = false
		var pos: Vector3 = floor_ref.c14_pos
		if P5Actor.model_path("papayala") != "":
			pap_actor = P5Actor.make(self, "papayala", 1.76, pos + Vector3(0.0, 0.0, 0.45), 180.0, "Papayala")
			pap_actor.floor_ref = floor_ref
			pap_actor.play("sit", true, 0.9, ["idle"])
		_evict_trigger = WorldObjects.simple(self, _PapayalaInteract, "DesalojarPapayala", "HUD_TURNSTILE", pos + Vector3(0.0, 0.85, 0.45), Vector3(0.75, 1.3, 0.75), Color(0.85, 0.45, 0.15, 0.0), 0.0, 1.2)
		(_evict_trigger as _PapayalaInteract).parent_event = self
		Metrics.set_aux(Metrics.Aux.BANO)
		EventBus.ezlak_post.emit("#team-familia", "papayala", "Ya te marqué Break en C-14, Jiroshi. De nada.", {"tipo": "programado", "mention": true})
		EventBus.show_message.emit("Papayala ocupó tu asiento C-14. Acércate y pulsa [E] para sacarlo." if Loc.lang != "en" else "Papayala took your C-14 seat. Walk up and press [E] to evict him.", 5.5)

	func evict() -> void:
		if _resolved:
			return
		_resolved = true
		var s14 := floor_ref.seat_by_id("C-14")
		if s14 != null:
			s14.enabled = true
		if _evict_trigger != null:
			_evict_trigger.queue_free()
		if pap_actor != null:
			pap_actor.queue_free()
		SaveSlots.bump_counter("reb", 2, "Jiroshi")
		AudioManager.play_sfx("qa_mesa_golpe", "Sala")
		GfxLens.kick(0.55, 0.6)
		var st := get_node_or_null("/root/SteamManager")
		if st != null and st.has_method("unlock"):
			st.call("unlock", "EVICT_PAPAYALA")
		EventBus.show_message.emit("Recuperaste tu puesto C-14. Vuelve a Available." if Loc.lang != "en" else "You reclaimed seat C-14. Switch back to Available.", 4.0)


class _PapayalaInteract extends Interactable:
	var parent_event: _PapayalaSeatEvent = null

	func hint_text() -> String:
		return "[E] Sacar a Papayala de tu silla C-14" if Loc.lang != "en" else "[E] Evict Papayala from your C-14 chair"

	func interact(_p: Node) -> bool:
		if parent_event != null:
			parent_event.evict()
		return true


## v0.4.1 · Viernes (Turno 5): Dispara el modal interactivo de las 5 ofertas del OM a las 08:00 AM.
class _OmOfferTrigger extends Node:
	var _shown: bool = false

	func _process(_delta: float) -> void:
		if _shown or not GameState.logged_in or GameState.shift_over:
			return
		if GameState.clock_seconds >= 8.0 * 3600.0 and not Checkpoints.dying and GameState.flags.get("om_oferta_elegida", "") == "":
			_shown = true
			var modal := OMOfferUI.new()
			get_tree().root.add_child(modal)

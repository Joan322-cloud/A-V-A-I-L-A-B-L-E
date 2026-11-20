## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.1 Q5: vistas fijas de cada zona reconstruida desde el site, para el antes/después (1280×720) y el brillo.
## El mismo archivo se copia sobre la v0.3.1-q0 para el "antes": la calle está a 2,1 m en la versión nueva, así que las
## vistas de la calle se colocan 2,2 m arriba y el jugador cae al suelo que haya (antes: la calle a 0 m).
## `ANTES` da otro punto de vista solo cuando el lugar no existía (el tópico se mudó al final del pasillo).
## v0.3.1 pisos: las vistas de lo que se movió con los planos de Joan (cafetería, descanso, baños, piso 1 y piso 2) apuntan
## al mismo lugar en el mundo nuevo; el «antes» (v0.3.1-beta1) usa las suyas.
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --shot q5_todas

const VIEWS: Dictionary = {
	"q5_calle": [-1, Vector3(1.6, 2.25, 25.8), 0.0, -0.06],
	"q5_bajada": [-1, Vector3(-1.6, 2.25, 22.6), 0.0, -0.32],
	"q5_patio": [-1, Vector3(-1.4, 0.05, 17.6), 6.0, 0.02],
	"q5_lobby": [-1, Vector3(-0.4, 0.05, 13.0), 0.0, -0.05],
	"q5_lobby_salida": [-1, Vector3(0.6, 0.05, 5.0), 180.0, 0.02],
	"q5_recepcion": [-1, Vector3(-2.5, 0.05, 9.8), -62.0, -0.05],
	"q5_molinetes": [-1, Vector3(-0.4, 0.05, 8.6), 6.0, -0.12],
	"q5_cafeteria_estacion": [-1, Vector3(5.6, 0.05, -9.6), 180.0, -0.1],
	"q5_cafeteria": [-1, Vector3(1.0, 0.05, -7.2), 20.0, -0.08],
	"q5_descanso": [-1, Vector3(12.4, 0.05, 6.2), -125.0, -0.1],
	"q5_ascensor_m1": [-1, Vector3(-3.0, 0.05, 1.4), 0.0, 0.0],
	"q5_bano_m1": [-1, Vector3(13.2, 0.05, -4.9), -90.0, 0.0],
	"q5_p1_hall": [1, Vector3(-4.5, 0.05, 1.2), -75.0, 0.0],
	"q5_p1_training": [1, Vector3(7.1, 0.05, 6.0), 0.0, -0.03],
	"q5_p1_sala": [1, Vector3(7.3, 0.05, 1.2), 10.0, -0.05],
	"q5_p1_topico": [1, Vector3(7.4, 0.05, 0.1), -90.0, -0.04],
	"q5_p1_bano": [1, Vector3(5.0, 0.05, 10.0), 180.0, -0.05],
	"q5_escalera": [0, Vector3.ZERO, 0.0, 0.15],
	"q5_escalera_giro": [0, Vector3.ZERO, 0.0, -0.35],
	"q5_p2_hall": [2, Vector3(3.6, 0.05, -0.7), -90.0, -0.02],
	"q5_p2_molinete": [2, Vector3(6.6, 0.05, 0.4), 95.0, -0.06],
	"q5_p2_casilleros": [2, Vector3(0.5, 0.05, 2.7), 0.0, -0.05],
	"q5_p2_refris": [2, Vector3(3.9, 0.05, -13.4), 105.0, -0.08],
	"q5_p2_pasillo": [2, Vector3(0.5, 0.05, -3.0), 180.0, -0.03],
	"q5_p2_sala": [2, Vector3(20.5, 0.05, 0.8), -55.0, 0.0],
	"q5_p2_sala_fondo": [2, Vector3(45.8, 0.05, 0.7), 48.0, -0.06],
	"q5_p2_calibracion": [2, Vector3(12.0, 0.05, 5.0), 25.0, -0.1],
	"q5_p2_bano": [2, Vector3(2.0, 0.05, -15.85), -90.0, 0.0],
	"q5_azotea": [9, Vector3(0.0, 0.05, -2.0), 180.0, 0.05],
	"q5_azotea_deck": [9, Vector3(-2.0, 0.05, 3.8), 160.0, 0.0],
	# Entorno este (autopista elevada, torres de luz, alta tensión, cerros).
	"q5_entorno_calle": [-1, Vector3(14.0, 2.25, 28.5), -80.0, 0.1],
	"q5_entorno_sala": [2, Vector3(46.6, 0.05, -12.4), -90.0, -0.2],
	"q5_entorno_azotea": [9, Vector3(8.0, 0.05, 12.0), -90.0, -0.1],
}
## Puntos de vista del "antes" donde la zona estaba en otro lugar.
const ANTES: Dictionary = {
	"q5_p1_topico": [1, Vector3(8.0, 0.05, -1.4), 0.0, -0.05],
}


func shots() -> Array[String]:
	var out: Array[String] = ["q5_todas", "q5_recorrido"]
	for k in VIEWS.keys():
		out.append(str(k))
	return out


static func is_new_world(_s: Node) -> bool:
	return ResourceLoader.exists("res://scripts/mundo/site_props.gd")  # solo existe desde la reconstrucción Q5


func shoot(name: String, _arg: String, s: Node) -> void:
	Dread.forced = 0.0
	GameState.flags["azotea_abierta_dev"] = true
	GameState.flags["revision_ok"] = true
	if name == "q5_todas":
		return
	if name == "q5_recorrido":
		await _recorrido(s)
		return
	var v: Array = VIEWS[name]
	if int(v[0]) == 0:
		# Caja de escalera 1 → 2.
		await s._place(1, Vector3(3, 0.05, -1.5), 180.0)
		s._building().go_to_stairwell(2, true)
		await s.get_tree().create_timer(0.4).timeout
		var sw := s._building().floor_node as Node3D
		var m := sw.find_child("escalera", true, false) as Node3D
		if name == "q5_escalera_giro":
			var land: Node3D = sw.find_child("DescansoMedio", true, false) as Node3D
			if land != null:
				s._player().teleport(land.global_position + Vector3(1.2, 0.1, -0.1), 45.0)
			else:
				s._player().teleport(sw.global_position + Vector3(0, 3.25, 10.6), 180.0)
		elif m != null:
			s._player().teleport(m.global_position, m.rotation_degrees.y)
		s._player().head.rotation.x = float(v[3])
		await s.get_tree().create_timer(0.5).timeout
		return
	await s._place(int(v[0]), v[1], float(v[2]), float(v[3]))
	if not is_new_world(s) and ANTES.has(name):
		var a: Array = ANTES[name]
		await s._place(int(a[0]), a[1], float(a[2]), float(a[3]))
	await s.get_tree().create_timer(0.6).timeout  # deja caer al jugador si la calle estaba más abajo
	s._player().head.rotation.x = float(v[3])


# --- Recorrido grabable (Movie Maker): `-- --shot q5_recorrido` con `--write-movie x.avi --fixed-fps 15` ---------
## Usa la conducción real de walk_test.gd (Input + move_and_slide): calle → bajada → recepción/molinetes →
## cafetería/microondas → ascensor → piso 1 training/tópico → escalera → piso 2 casilleros/refris → sala → azotea.
var _wt: Node = null


func _look(s: Node, yaw_deg: float, secs: float, pitch: float = -0.05) -> void:
	var p: Player = s._player()
	var y0 := p.rotation.y
	var y1 := y0 + wrapf(deg_to_rad(yaw_deg) - y0, -PI, PI)
	var p0 := p.head.rotation.x
	var t := 0.0
	while t < secs:
		await s.get_tree().physics_frame
		t += s.get_physics_process_delta_time()
		var k := smoothstep(0.0, 1.0, clampf(t / secs, 0.0, 1.0))
		p.rotation.y = lerpf(y0, y1, k)
		p.head.rotation.x = lerpf(p0, pitch, k)


func _go(pts: Array, each: float = 12.0) -> void:
	var ok: bool = await _wt.call("_goto", pts, each)
	if not ok:
		print("[q5_recorrido] atascado: ", _wt.get("_last_nav"))


func _recorrido(s: Node) -> void:
	EventBus.vitzo_reminder.connect(func(_e: String, _s: float) -> void: EventBus.vitzo_reacted.emit.call_deferred())
	EventBus.ack_window_opened.connect(func(_s: float) -> void: Metrics.give_ack.call_deferred())
	Metrics.set_aux(Metrics.Aux.BREAK)  # recorrido de mundo: sin listas ni persecuciones por estar fuera de la sala
	_wt = (load("res://scripts/dev/walk_test.gd") as GDScript).new()
	_wt.set("_main", s._main)
	_wt.set("_player", s._player())
	_wt.set("_building", s._building())
	s.add_child(_wt)
	var p: Player = s._player()
	await s._place(-1, Vector3(-0.8, 2.15, 25.2), 0.0, 0.02)
	await s.get_tree().create_timer(1.5).timeout
	# Calle → bajada al patio hundido → fachada → lobby.
	await _go([Vector3(-1.6, 0, 23.0), Vector3(-1.6, 0, 16.5), Vector3(-0.6, 0, 15.0), Vector3(-0.6, 0, 11.5)])
	await _look(s, -62.0, 1.6)
	await s.get_tree().create_timer(0.8).timeout
	await _look(s, 0.0, 1.2, -0.12)
	await _go([Vector3(-1.0, 0, 7.4)])
	await s.get_tree().create_timer(0.6).timeout
	await _go([Vector3(-1.0, 0, 4.8), Vector3(0, 0, 2.0)])
	# Núcleo → cafetería (estación de refris, 6 microondas y lavadero) → sofás.
	await _go([Vector3(6, 0, 1.0), Vector3(11.0, 0, 1.0), Vector3(12.5, 0, 1.0), Vector3(14.5, 0, 2.6)])
	await _look(s, 10.0, 1.0, -0.15)
	await _go([Vector3(16.2, 0, 2.3)])
	await _look(s, 0.0, 0.6, -0.15)
	await s.get_tree().create_timer(1.2).timeout
	await _look(s, -100.0, 1.6, -0.05)
	await s.get_tree().create_timer(0.6).timeout
	# Ascensor al piso 1.
	await _go([Vector3(12.5, 0, 1.0), Vector3(6.0, 0, 0.0), Vector3(0, 0, 0)])
	await _wt.call("_ride", 1)
	await _go([Vector3(-3.0, 0, -1.5), Vector3(0.0, 0, 0.0), Vector3(5.0, 0, 0.0), Vector3(9.0, 0, 0.0)])
	await _look(s, -35.0, 1.2)
	await _go([Vector3(17.0, 0, -0.6)])
	await _look(s, -10.0, 1.0)
	await s.get_tree().create_timer(0.6).timeout
	await _go([Vector3(24.0, 0, 0.0), Vector3(24.0, 0, 7.5), Vector3(25.0, 0, 9.6)])
	await _look(s, -90.0, 1.0)
	await s.get_tree().create_timer(1.4).timeout
	# Escalera 1 → 2 (U, descanso del giro).
	await _go([Vector3(24.0, 0, 7.5), Vector3(24.0, 0, 0.0), Vector3(5.0, 0, 0.0), Vector3(3.8, 0, -2.0)])
	(s._building().floor_node.find_child("EscaleraSubir", true, false) as Interactable).interact(p)
	await s.get_tree().create_timer(1.0).timeout
	var base: Vector3 = s._building().floor_node.global_position
	await _go([base + Vector3(1.15, 0, 2.2), base + Vector3(1.15, 1.6, 5.6), base + Vector3(-1.15, 1.6, 5.6), base + Vector3(-1.15, 3.2, 1.0)])
	var salida := s._building().floor_node.find_child("Puerta_salida", true, false) as Interactable
	if salida != null:
		salida.interact(p)
	await s.get_tree().create_timer(1.2).timeout
	# Piso 2: casilleros de colores → refris → pasillo → sala de PCs.
	await _go([Vector3(0, 0, 2.0), Vector3(-0.3, 0, 6.0), Vector3(-0.3, 0, 12.0)])
	await _look(s, 90.0, 0.8)
	await _look(s, -90.0, 1.4)
	await _look(s, 180.0, 0.8)
	await _go([Vector3(-0.3, 0, 17.0), Vector3(-0.8, 0, 19.9)])
	await _look(s, 180.0, 0.6, -0.1)
	await s.get_tree().create_timer(1.0).timeout
	await _go([Vector3(4.0, 0, 20.0), Vector3(9.0, 0, 20.0), Vector3(17.0, 0, 20.0), Vector3(18.0, 0, 17.5), Vector3(18.0, 0, 3.0), Vector3(19.5, 0, 0.6), Vector3(26.0, 0, 0.6)])
	await _look(s, -120.0, 1.6, -0.06)
	await s.get_tree().create_timer(1.0).timeout
	# Azotea (abierta 24/7).
	s._building().go_to_floor(9, "ascensor")
	await s.get_tree().create_timer(1.0).timeout
	await _go([Vector3(-2.0, 0, -1.5), Vector3(0, 0, 1.2)])
	var deck := s._building().floor_node.find_child("PuertaAzotea", true, false) as WorldObjects.Door
	if deck != null and not deck.open:
		deck.interact(p)
	await s.get_tree().create_timer(0.6).timeout
	await _go([Vector3(0, 0, 3.2), Vector3(0, 0, 6.0), Vector3(0.2, 0, 10.0)])
	await _look(s, 150.0, 2.0, 0.04)
	await s.get_tree().create_timer(1.5).timeout

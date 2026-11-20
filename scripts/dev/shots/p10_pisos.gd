## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.1 pisos: vistas para Joan de los pisos -1, 1 y 2 rehechos con sus planos (REFERENCIA_PISOS_v3).
## - `pisos_<vista>`: vistas fijas 1280×720 para el antes/después. El mismo archivo se copia sobre la v0.3.1-beta1 para
##   el «antes»; si el lugar no existía en ese mundo, ANTES da el punto de vista equivalente de entonces.
## - `pisos_planta_<piso>`: planta ortográfica desde arriba, en el marco y la escala del plano de Joan
##   (planos/v3/plano_<piso>.png): mismas medidas en metros y misma orientación (sin espejar). Lo que está por encima de
##   2,2 m (techos, lámparas, carteles) no se dibuja, y el color es plano (sin luces), como un plano.
## - `pisos_recorrido`: recorrido grabable (Movie Maker) calle → -1 → piso 1 → piso 2.
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --shot pisos_m1_cafeteria

## [piso, posición, yaw, pitch]
const VIEWS: Dictionary = {
	"pisos_m1_lobby_nucleo": [-1, Vector3(-0.4, 0.05, 12.6), 0.0, -0.06],
	"pisos_m1_nucleo_push": [-1, Vector3(2.0, 0.05, 1.6), 0.0, -0.08],
	"pisos_m1_cafeteria": [-1, Vector3(1.0, 0.05, -7.2), 20.0, -0.08],
	"pisos_m1_estacion": [-1, Vector3(5.6, 0.05, -9.6), 180.0, -0.1],
	"pisos_m1_marleny": [-1, Vector3(8.5, 0.05, -12.3), -90.0, -0.06],
	"pisos_m1_sillones": [-1, Vector3(-4.0, 0.05, -10.6), 124.0, -0.1],
	"pisos_m1_pasillo_banos": [-1, Vector3(12.2, 0.05, -0.2), 0.0, -0.05],
	"pisos_m1_barra": [-1, Vector3(11.9, 0.05, 4.6), -110.0, -0.08],
	"pisos_m1_descanso": [-1, Vector3(12.4, 0.05, 6.2), -125.0, -0.1],
	"pisos_m1_lounge": [-1, Vector3(15.4, 0.05, -1.0), -120.0, -0.06],
	"pisos_p1_hall": [1, Vector3(-7.8, 0.05, 0.4), -90.0, -0.02],
	"pisos_p1_hall_escalera": [1, Vector3(-1.0, 0.05, -0.6), -60.0, -0.04],
	"pisos_p1_pasillo": [1, Vector3(7.1, 0.05, 6.0), 0.0, -0.03],
	"pisos_p1_sala": [1, Vector3(7.3, 0.05, 1.2), 10.0, -0.05],
	"pisos_p1_topico": [1, Vector3(7.4, 0.05, 0.1), -90.0, -0.04],
	"pisos_p1_banos": [1, Vector3(7.1, 0.05, 4.6), 160.0, -0.08],
	"pisos_p1_apagado": [1, Vector3(5.8, 0.05, 7.6), 90.0, 0.0],
	"pisos_p2_hall": [2, Vector3(3.6, 0.05, -0.7), -90.0, -0.02],
	"pisos_p2_molinete": [2, Vector3(6.6, 0.05, 0.4), 95.0, -0.06],
	"pisos_p2_casilleros": [2, Vector3(0.5, 0.05, 2.7), 0.0, -0.05],
	"pisos_p2_entrada2": [2, Vector3(0.5, 0.05, -3.0), 180.0, -0.03],
	"pisos_p2_pantry": [2, Vector3(3.9, 0.05, -13.4), 105.0, -0.08],
	"pisos_p2_banos": [2, Vector3(0.55, 0.05, -11.8), 0.0, -0.05],
	"pisos_p2_entrada1": [2, Vector3(0.2, 0.05, -12.6), -90.0, -0.04],
	"pisos_p2_anexo_so": [2, Vector3(6.2, 0.05, -12.0), -72.0, -0.08],
	"pisos_p2_anexo_n": [2, Vector3(0.6, 0.05, 4.4), -80.0, -0.04],
	"pisos_p2_sala": [2, Vector3(20.5, 0.05, 0.8), -55.0, -0.02],
	"pisos_p2_feedback": [2, Vector3(12.0, 0.05, 5.0), 25.0, -0.1],
	"pisos_p2_auxiliar": [2, Vector3(-5.3, 0.05, -10.8), 0.0, -0.1],
}
## «Antes» (v0.3.1-beta1): el mismo lugar del site en el mundo viejo (o lo más parecido que había).
const ANTES: Dictionary = {
	"pisos_m1_lobby_nucleo": [-1, Vector3(-0.4, 0.05, 12.6), 0.0, -0.06],
	"pisos_m1_nucleo_push": [-1, Vector3(2.0, 0.05, 1.6), 0.0, -0.08],
	"pisos_m1_cafeteria": [-1, Vector3(13.8, 0.05, 7.5), -70.0, 0.0],
	"pisos_m1_estacion": [-1, Vector3(17.6, 0.05, 4.4), 28.0, -0.12],
	"pisos_m1_marleny": [-1, Vector3(20.0, 0.05, 4.6), 0.0, -0.06],
	"pisos_m1_sillones": [-1, Vector3(22.0, 0.05, 7.6), 180.0, -0.1],
	"pisos_m1_pasillo_banos": [-1, Vector3(-6.0, 0.05, 0.2), 90.0, -0.05],
	"pisos_m1_barra": [-1, Vector3(25.0, 0.05, 4.0), -90.0, -0.08],
	"pisos_m1_descanso": [-1, Vector3(28.4, 0.05, 10.9), -62.0, -0.12],
	"pisos_m1_lounge": [-1, Vector3(28.4, 0.05, 3.2), -120.0, -0.06],
	"pisos_p1_hall": [1, Vector3(-4.5, 0.05, 1.2), -75.0, 0.0],
	"pisos_p1_hall_escalera": [1, Vector3(-1.0, 0.05, 2.0), -120.0, -0.04],
	"pisos_p1_pasillo": [1, Vector3(8.0, 0.05, 0.5), -90.0, -0.03],
	"pisos_p1_sala": [1, Vector3(18.0, 0.05, 0.4), 0.0, -0.05],
	"pisos_p1_topico": [1, Vector3(23.4, 0.05, 9.8), -80.0, -0.04],
	"pisos_p1_banos": [1, Vector3(12.0, 0.05, 1.5), 180.0, -0.05],
	"pisos_p1_apagado": [1, Vector3(8.0, 0.05, -1.4), 0.0, -0.05],
	"pisos_p2_hall": [2, Vector3(-5.2, 0.05, 0.6), -95.0, 0.0],
	"pisos_p2_molinete": [2, Vector3(0.0, 0.05, 1.4), 180.0, -0.05],
	"pisos_p2_casilleros": [2, Vector3(0.0, 0.05, 6.2), 180.0, -0.05],
	"pisos_p2_entrada2": [2, Vector3(18.0, 0.05, 16.8), 0.0, -0.05],
	"pisos_p2_pantry": [2, Vector3(0.6, 0.05, 18.9), 168.0, -0.08],
	"pisos_p2_banos": [2, Vector3(-8.2, 0.05, -1.2), 90.0, 0.0],
	"pisos_p2_entrada1": [2, Vector3(17.0, 0.05, 20.0), 90.0, -0.04],
	"pisos_p2_anexo_so": [2, Vector3(18.0, 0.05, 12.0), 0.0, -0.04],
	"pisos_p2_anexo_n": [2, Vector3(18.0, 0.05, 6.0), 0.0, -0.04],
	"pisos_p2_sala": [2, Vector3(20.5, 0.05, 0.8), -55.0, 0.0],
	"pisos_p2_feedback": [2, Vector3(-2.6, 0.05, 18.2), 75.0, -0.12],
	"pisos_p2_auxiliar": [2, Vector3(45.0, 0.05, -1.0), 170.0, -0.06],
}
## Planta: [piso, centro x, centro z, alto (m) de la imagen, "arriba" de la imagen en el mundo]. El encuadre es el del
## plano de Joan (ext de tools/planos_v3_data.py) pasado al juego con la misma transformación que el piso.
const PLANTAS: Dictionary = {
	# -1: x = 29,2 − x_Joan, z = y_Joan − 18,1; ext (6, −2, 46, 37) → x −16,8..23,2, z −20,1..18,9 (arriba = calle = +z).
	"pisos_planta_m1": [-1, 3.2, -0.6, 39.0, Vector3(0, 0, 1)],
	# 1: x = x_plano, z = −y_plano; ext (−14, −15, 17, 10) → x −14..17, z −10..15 (arriba = −z, los ascensores).
	"pisos_planta_p1": [1, 1.5, 2.5, 25.0, Vector3(0, 0, -1)],
	# 2: x = 9 − x_plano, z = y_plano; ext (−21, −27, 17, 8) → x −8..30, z −27..8 (arriba = +z, los ascensores).
	"pisos_planta_p2": [2, 11.0, -9.5, 35.0, Vector3(0, 0, 1)],
	# 2 entero (la sala de operaciones del juego sigue hasta x 48).
	"pisos_planta_p2_completo": [2, 20.0, -9.5, 35.0, Vector3(0, 0, 1)],
}


func shots() -> Array[String]:
	var out: Array[String] = ["pisos_recorrido"]
	for k in VIEWS.keys():
		out.append(str(k))
	for k in PLANTAS.keys():
		out.append(str(k))
	return out


static func is_new_world(_s: Node) -> bool:
	return ResourceLoader.exists("res://scripts/mundo/office_horror.gd")  # solo existe desde la reconstrucción de los pisos


func shoot(name: String, _arg: String, s: Node) -> void:
	Dread.forced = 0.0
	GameState.flags["revision_ok"] = true
	if name == "pisos_recorrido":
		await _recorrido(s)
		return
	if PLANTAS.has(name):
		await _planta(s, PLANTAS[name])
		return
	var v: Array = VIEWS[name] if is_new_world(s) else ANTES[name]
	await s._place(int(v[0]), v[1], float(v[2]), float(v[3]))
	await s.get_tree().create_timer(0.6).timeout
	s._player().head.rotation.x = float(v[3])


# --- Planta ortográfica ------------------------------------------------------------------------------------------------

func _planta(s: Node, p: Array) -> void:
	await s._place(int(p[0]), Vector3(0, 0.05, 0), 0.0)
	await s.get_tree().create_timer(0.8).timeout
	var tree: SceneTree = s.get_tree()
	var fl: Node3D = s._building().floor_node
	var pl: Node3D = s._player()
	pl.visible = false
	for n in tree.root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in tree.root.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env != null:
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
	for n in fl.find_children("*", "", true, false):
		if n is GPUParticles3D or n is CPUParticles3D or n is Label3D:
			(n as Node3D).visible = false
		elif n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			var bb := gi.global_transform * gi.get_aabb()
			if bb.position.y >= 2.2:
				gi.visible = false
	tree.root.get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var cam := tree.root.get_viewport().get_camera_3d()
	cam.top_level = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = float(p[3])
	cam.near = 0.5
	cam.far = 120.0
	var up: Vector3 = p[4]
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, up), fl.global_position + Vector3(float(p[1]), 60.0, float(p[2])))
	await tree.create_timer(0.4).timeout


# --- Recorrido grabable (Movie Maker): `-- --shot pisos_recorrido` con `--write-movie x.avi --fixed-fps 24` -----------
## Usa la conducción real de walk_test.gd (Input + move_and_slide): calle → bajada → lobby → núcleo → puerta push →
## cafetería → pasillo de baños → barra y descanso → ascensor → piso 1 (hall, pasillo de training, tópico) → escalera →
## piso 2 (casilleros, pantry, baños, entrada 1, sala de operaciones).
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
		print("[pisos_recorrido] atascado: ", _wt.get("_last_nav"))


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
	var tree: SceneTree = s.get_tree()
	await s._place(-1, Vector3(-0.8, 2.15, 25.2), 0.0, 0.02)
	await tree.create_timer(1.0).timeout
	# Calle → bajada al patio hundido → lobby → molinetes.
	await _go([Vector3(-1.6, 0, 23.0), Vector3(-1.6, 0, 16.5), Vector3(-0.6, 0, 15.0), Vector3(-0.6, 0, 11.5)])
	await _look(s, -40.0, 1.0)
	await _look(s, 0.0, 0.8, -0.08)
	await _go([Vector3(-1.0, 0, 7.4), Vector3(-1.0, 0, 4.8), Vector3(1.6, 0, 1.0)])
	# Núcleo → puerta push → cafetería (estación de microondas, mesas, sillones, mostrador de Marleny).
	await _look(s, 0.0, 0.6, -0.05)
	await _go([Vector3(2.0, 0, -2.5), Vector3(2.0, 0, -5.0), Vector3(2.0, 0, -7.4)])
	await _look(s, -15.0, 0.8, -0.1)
	await _go([Vector3(4.0, 0, -8.6), Vector3(6.5, 0, -8.0)])
	await _look(s, 0.0, 0.8, -0.12)
	await tree.create_timer(0.8).timeout
	await _look(s, 100.0, 1.4, -0.05)
	await _go([Vector3(-3.0, 0, -11.0), Vector3(-9.0, 0, -11.0)])  # por el sur del kiosco cerrado
	await _look(s, 0.0, 1.0, -0.05)
	await _look(s, -90.0, 1.8, -0.05)
	await _go([Vector3(-0.5, 0, -12.5), Vector3(6.0, 0, -12.5), Vector3(12.4, 0, -12.3)])
	await _look(s, -90.0, 0.8, -0.05)
	await tree.create_timer(0.6).timeout
	# Paso abierto de los baños → zona de barra (expendedora) → descanso (ping-pong, puffs) → lounge a oscuras.
	await _go([Vector3(12.2, 0, -8.0), Vector3(12.2, 0, -6.4), Vector3(12.2, 0, -1.2), Vector3(12.6, 0, 0.0)])
	await _look(s, 90.0, 1.0, -0.08)
	await _go([Vector3(12.6, 0, 4.6), Vector3(14.6, 0, 6.6)])
	await _look(s, -130.0, 1.6, -0.06)
	await _look(s, -60.0, 1.2, -0.06)
	await _go([Vector3(15.4, 0, 5.4), Vector3(16.2, 0, 2.6), Vector3(16.3, 0, -0.6)])
	await _look(s, -120.0, 1.2, -0.05)
	await tree.create_timer(0.6).timeout
	# De vuelta al núcleo por la puerta abierta y el ascensor al piso 1.
	await _go([Vector3(16.2, 0, 2.6), Vector3(15.4, 0, 5.0), Vector3(12.0, 0, 4.8), Vector3(10.2, 0, 4.6), Vector3(8.5, 0, 2.5), Vector3(4.0, 0, 0.0), Vector3(-3.0, 0, 0.5)])  # rodea la barra alta por el norte
	await _wt.call("_ride", 1)
	# Piso 1: hall angosto → puerta esmerilada → cruce con «SALIDA» y sala principal → recodo → tópico → vestíbulo de
	# baños → pasillo apagado (la mirilla azul).
	await _go([Vector3(-3.0, 0, -0.8), Vector3(-1.0, 0, 0.0)])
	await _look(s, -90.0, 1.2, -0.02)
	await _go([Vector3(4.0, 0, 0.0), Vector3(6.6, 0, 0.0), Vector3(7.2, 0, 0.2)])
	await _look(s, 0.0, 0.9, -0.03)
	await tree.create_timer(0.8).timeout
	await _look(s, -90.0, 1.0, -0.03)
	await _go([Vector3(10.0, 0, -0.3), Vector3(11.4, 0, -0.3)])
	await tree.create_timer(0.8).timeout
	await _go([Vector3(7.2, 0, -0.1), Vector3(7.1, 0, 3.5), Vector3(7.1, 0, 6.8)])
	await _look(s, 90.0, 1.0, 0.0)
	await _go([Vector3(5.0, 0, 7.55), Vector3(2.0, 0, 7.55)])
	await tree.create_timer(0.8).timeout
	# Escalera (en U, la repetición) → piso 2.
	await _go([Vector3(5.0, 0, 7.55), Vector3(7.1, 0, 6.8), Vector3(7.1, 0, 0.0), Vector3(5.0, 0, 0.0), Vector3(4.1, 0, 0.6)])
	(s._building().floor_node.find_child("EscaleraSubir", true, false) as Interactable).interact(p)
	await tree.create_timer(1.0).timeout
	var base: Vector3 = s._building().floor_node.global_position
	await _go([base + Vector3(1.15, 0, 2.2), base + Vector3(1.15, 1.6, 5.6), base + Vector3(-1.15, 1.6, 5.6), base + Vector3(-1.15, 3.2, 1.0)])
	var salida := s._building().floor_node.find_child("Puerta_salida", true, false) as Interactable
	if salida != null:
		salida.interact(p)
	await tree.create_timer(1.2).timeout
	# Piso 2: hall → molinete → casilleros (entrada 2 de vidrio al norte) → pantry (refris, entrada 1) → pasillo corto de
	# baños → ala suroeste → sala de operaciones.
	await _look(s, 90.0, 0.8, -0.02)
	await _go([Vector3(3.6, 0, -0.4), Vector3(2.6, 0, -0.4), Vector3(0.5, 0, -0.4)])
	await _look(s, 180.0, 1.0, -0.03)
	await tree.create_timer(0.8).timeout
	await _look(s, 0.0, 1.2, -0.04)
	await _go([Vector3(0.5, 0, -5.0), Vector3(0.5, 0, -12.0)])
	await _look(s, 75.0, 1.0, -0.08)
	await tree.create_timer(0.5).timeout
	await _look(s, -90.0, 1.2, -0.05)
	await _look(s, 0.0, 0.8, -0.05)
	await _go([Vector3(0.55, 0, -13.2), Vector3(0.55, 0, -14.8)])
	await _look(s, -60.0, 0.8, -0.05)
	await _look(s, 60.0, 1.0, -0.05)
	await _look(s, 0.0, 0.6, -0.05)
	await tree.create_timer(0.4).timeout
	await _go([Vector3(0.55, 0, -12.5), Vector3(4.3, 0, -12.55), Vector3(6.6, 0, -12.6), Vector3(16.6, 0, -12.6), Vector3(18.7, 0, -12.7), Vector3(23.0, 0, -12.7)])
	await _look(s, -60.0, 1.6, -0.04)
	await tree.create_timer(1.0).timeout

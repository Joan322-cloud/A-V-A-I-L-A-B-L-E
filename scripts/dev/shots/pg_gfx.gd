## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.2 gfx: vistas fijas para comparar calidades (Baja ↔ Media ↔ Alta) y renderizadores, sin HUD.
## La calidad sale de settings.json («quality»); cada corrida es un proceso con su XDG_DATA_HOME:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --shot pg       (Compatibilidad)
##   xvfb-run -a godot --path game --rendering-method forward_plus --rendering-driver vulkan … -- --shot pg (Forward+)
## `gfx_info` no captura nada útil: imprime el resumen del director y los monitores de render (dibujos, primitivas).

## [piso, posición, yaw, pitch]
const VIEWS: Dictionary = {
	"gfx_puesto": [2, Vector3.ZERO, 0.0, -0.1],                       # sentado en C-14 (se coloca aparte)
	"gfx_sala": [2, Vector3(20.5, 0.05, 0.8), -55.0, -0.02],          # la sala de operaciones desde la entrada 2
	"gfx_sala_fondo": [2, Vector3(44.6, 0.05, -3.2), 118.0, -0.05],   # hacia las filas desde el fondo (lado de Shero)
	"gfx_pasillo": [2, Vector3(0.5, 0.05, 2.7), 0.0, -0.05],          # pasillo de casilleros
	"gfx_vidrio": [2, Vector3(12.0, 0.05, 5.0), 25.0, -0.1],          # sala de feedback tras el vidrio
	"gfx_vidrio_entrada": [2, Vector3(0.5, 0.05, -3.0), 180.0, -0.03],  # puerta doble de vidrio (entrada 2)
	"gfx_ascensor": [2, Vector3(3.6, 0.05, -0.7), -90.0, -0.02],      # hall de ascensores
	"gfx_calibracion": [2, Vector3(11.9, 0.05, 2.2), 70.0, -0.08],    # dentro de la sala de feedback / calibración
	"gfx_ala_norte": [2, Vector3(4.6, 0.05, 5.6), -82.0, -0.04],       # el ala norte a oscuras con la sala de vidrio encendida al fondo
	"gfx_pasillo_fondo": [2, Vector3(0.5, 0.05, -4.2), 0.0, -0.04],   # desde tu casillero hacia el fondo del pasillo
	"gfx_pantry": [2, Vector3(3.9, 0.05, -13.4), 105.0, -0.08],
	"gfx_cafeteria": [-1, Vector3(1.0, 0.05, -7.2), 20.0, -0.08],
	"gfx_cafeteria_b": [-1, Vector3(5.6, 0.05, -9.6), 180.0, -0.1],
	"gfx_lobby": [-1, Vector3(-0.4, 0.05, 12.6), 0.0, -0.06],
	"gfx_descanso": [-1, Vector3(12.4, 0.05, 6.2), -125.0, -0.1],
	"gfx_p1_pasillo": [1, Vector3(7.1, 0.05, 6.0), 0.0, -0.03],
	"gfx_p1_hall": [1, Vector3(-7.8, 0.05, 0.4), -90.0, -0.02],
	"gfx_azotea": [9, Vector3(0, 0.05, -2.0), 180.0, 0.05],
}


func shots() -> Array[String]:
	var out: Array[String] = []
	for k in VIEWS.keys():
		out.append(str(k))
	out += ["gfx_personaje", "gfx_escalera", "gfx_recuerdo", "gfx_emergencia", "gfx_ui_brillo", "gfx_ui_panel", "gfx_info", "gfx_paseo"]
	return out


func _prep(s: Node) -> void:
	var hud: Variant = s._main.get("hud")
	if hud is CanvasItem:
		(hud as CanvasItem).visible = false
	var tips := s._main.get_node_or_null("UI/AgentTips") as CanvasItem
	if tips != null:
		tips.visible = false
	# El reloj corre durante la corrida: que el recordatorio de Vitzo no mate entre vistas.
	if not EventBus.vitzo_reminder.is_connected(_ack):
		EventBus.vitzo_reminder.connect(_ack)


func _ack(_e: String, _sec: float) -> void:
	EventBus.vitzo_reacted.emit.call_deferred()


## Espera a que el pase gráfico asiente (sombras con fundido, adaptación de la exposición, sondas).
func _settle(s: Node, seconds: float = 2.4) -> void:
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while frames < 14 or float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await s.get_tree().process_frame
		frames += 1


func shoot(name: String, arg: String, s: Node) -> void:
	await _shoot(name, arg, s)
	# Una línea por vista para el informe: exposición, luz donde está la cámara y costo del cuadro.
	var d: GfxDirector = GfxDirector.inst if is_instance_valid(GfxDirector.inst) else null
	print("[gfx] vista %s: calidad=%s exposicion=%.2f luz_local=%.2f dibujos=%d primitivas=%d" % [name, GfxQuality.level(),
		d.atmosphere.exposure_now() if d != null else -1.0, d.lights.local_light if d != null else -1.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])


func _shoot(name: String, _arg: String, s: Node) -> void:
	_prep(s)
	if _fov0 > 0.0:  # la vista anterior era el primer plano: vuelve el campo de visión normal
		var pl0: Player = s._player()
		pl0.camera.fov = _fov0
		pl0.fov_base = _fov0
		_fov0 = -1.0
	if _recuerdo_on:  # la vista anterior era el recuerdo: se sale de él (cada vista es otra instancia de este script)
		if _recuerdo_layer != null and is_instance_valid(_recuerdo_layer):
			_recuerdo_layer.queue_free()
		_recuerdo_layer = null
		_recuerdo_on = false
		Flashback.active = false
	GfxDirector.emergency(false)
	if not name.begins_with("gfx_ui"):
		_ui_clear(s)
	if VIEWS.has(name) and name != "gfx_puesto":
		var v: Array = VIEWS[name]
		await s._place(int(v[0]), v[1], float(v[2]), float(v[3]))
		await _settle(s)
		return
	match name:
		"gfx_puesto":
			await s._sit_c14()
			var ws := s.get_tree().get_first_node_in_group("workstation")
			if ws != null:
				ws.call("set_zoom", false)
			s._player().head.rotation.x = -0.16
			await _settle(s)
		"gfx_personaje":
			# Primer plano del compañero de C-15 tecleando, iluminado por su monitor: lo que ves desde tu silla al girar.
			await s._sit_c14()
			var ws2 := s.get_tree().get_first_node_in_group("workstation")
			if ws2 != null:
				ws2.call("set_zoom", false)
			var pl: Player = s._player()
			pl.rotation.y -= deg_to_rad(78.0)
			pl.head.rotation.x = -0.05
			await s.get_tree().process_frame
			_fov0 = pl.fov_base
			pl.camera.fov = 46.0
			pl.fov_base = 46.0
			await _settle(s)
		"gfx_escalera":
			await s._place(2, Vector3(9, 0.05, -2.0), 0.0)
			s._building().go_to_stairwell(1, false)
			await s.get_tree().create_timer(0.3).timeout
			s._player().head.rotation.x = -0.25
			await _settle(s)
		"gfx_info":
			await s._place(2, Vector3(20.5, 0.05, 0.8), -55.0, -0.02)
			await _settle(s)
			info(s)
		"gfx_paseo":
			await _paseo(s)
		"gfx_ui_brillo":
			# La pantalla de brillo, como sale la primera vez (sobre lo que haya detrás).
			_ui_clear(s)
			var layer2 := CanvasLayer.new()
			layer2.name = "GfxUiPrueba"
			layer2.layer = 105
			s.get_tree().root.add_child(layer2)
			var cal := GfxCalibration.new()
			cal.first_time = true
			layer2.add_child(cal)
			await _settle(s, 0.6)
		"gfx_ui_panel":
			# Opciones → «Gráficos avanzados…» abierto.
			_ui_clear(s)
			var layer3 := CanvasLayer.new()
			layer3.name = "GfxUiPrueba"
			layer3.layer = 105
			s.get_tree().root.add_child(layer3)
			var om := OptionsMenu.new()
			layer3.add_child(om)
			await s.get_tree().process_frame
			await s.get_tree().process_frame
			var btn := om.find_child("BotonGraficosAvanzados", true, false) as Button
			if btn != null:
				btn.pressed.emit()
			GfxSettings.set_global("gfx_fps", true)
			EventBus.settings_changed.emit("gfx_fps")
			await _settle(s, 1.2)
		"gfx_recuerdo":
			# El aula del Training en el recuerdo (de día), armada como lo hace el tutorial: Flashback + TrainingRoom.
			await s._place(1, Vector3(11.2, 0.05, -8.05), 168.0, -0.12)
			Flashback.active = true
			_recuerdo_on = true
			var layer := Flashback.make_layer(s.get_tree().root)
			var f: Node3D = s._building().floor_node
			Flashback.clean_floor(f)
			TrainingRoom.setup(f)
			var envs := s.get_tree().root.find_children("*", "WorldEnvironment", true, false)
			if not envs.is_empty():
				Flashback.brighten_env((envs[0] as WorldEnvironment).environment)
			await _settle(s, 3.0)
			_recuerdo_layer = layer
		"gfx_emergencia":
			# La sala con las luces de emergencia (lo que hace una persecución).
			await s._place(2, Vector3(20.5, 0.05, 0.8), -55.0, -0.02)
			await _settle(s, 1.0)
			GfxDirector.emergency(true)
			await _settle(s, 3.5)


## Resumen del director y monitores de render de la vista actual (dibujos, primitivas, objetos).
static func info(s: Node) -> void:
	var d: Variant = GfxDirector.inst.summary() if is_instance_valid(GfxDirector.inst) else {}
	print("[gfx] director: ", JSON.stringify(d))
	print("[gfx] render: metodo=%s driver=%s adaptador=%s tipo=%d" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_type()])
	print("[gfx] cuadro: dibujos=%d primitivas=%d objetos=%d fps=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		int(Engine.get_frames_per_second())])
	print("[gfx] memoria de video: %.1f MB (texturas %.1f MB)" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])


# --- Paseo grabable (Movie Maker): `--write-movie x.avi --fixed-fps 20 … -- --shot gfx_paseo` ---------------------
## Del pasillo a la sala de operaciones y por el corredor junto a las filas, con la conducción real de walk_test.gd
## (Input + move_and_slide): sirve de clip y de prueba de que el camino se lee en Alta.
static var _recuerdo_layer: Node = null
static var _recuerdo_on: bool = false
static var _fov0: float = -1.0   # campo de visión de antes del primer plano (se devuelve en la vista siguiente)


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


## Camina por `points` girando con suavidad (para el clip): si el destino queda muy de lado, se detiene y gira.
func _walk(s: Node, points: Array, max_s: float = 16.0) -> bool:
	var p: Player = s._player()
	var ok := true
	for target: Vector3 in points:
		var left := max_s
		while true:
			await s.get_tree().physics_frame
			var dt: float = s.get_physics_process_delta_time()
			var to: Vector3 = target - p.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			left -= dt
			if left <= 0.0:
				ok = false
				print("[gfx_paseo] atascado en (%.1f, %.1f) yendo a (%.1f, %.1f)" % [p.global_position.x, p.global_position.z, target.x, target.z])
				break
			var err := wrapf(atan2(-to.x, -to.z) - p.rotation.y, -PI, PI)
			p.rotation.y += clampf(err, -2.4 * dt, 2.4 * dt)
			p.head.rotation.x = lerpf(p.head.rotation.x, -0.04, minf(1.0, 3.0 * dt))
			if absf(err) < 0.45:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
		if not ok:
			break
	Input.action_release("move_forward")
	return ok


func _hold(s: Node, secs: float) -> void:
	var t := 0.0
	while t < secs:
		await s.get_tree().physics_frame
		t += s.get_physics_process_delta_time()


## Hall de ascensores → casilleros → ala norte (sala de vidrio) → entrada 2 → sala de operaciones, a paso lento.
## Los puntos son los del recorrido de walk_test.gd (probados con la colisión real).
func _paseo(s: Node) -> void:
	Metrics.set_aux(Metrics.Aux.BREAK)  # paseo de mundo: sin listas ni persecuciones por estar fuera del puesto
	if not EventBus.ack_window_opened.is_connected(_give_ack):
		EventBus.ack_window_opened.connect(_give_ack)
	await s._place(2, Vector3(3.6, 0.05, -0.4), 90.0, -0.04)
	var p: Player = s._player()
	var speed0 := p.speed
	p.speed = 2.0
	await _settle(s, 1.2)
	print("[gfx_paseo] inicio cuadro=%d" % Engine.get_frames_drawn())
	var ok: bool = await _walk(s, [Vector3(2.6, 0, -0.4), Vector3(0.5, 0, -0.4), Vector3(0.5, 0, 2.3), Vector3(0.5, 0, 4.0), Vector3(4.0, 0, 4.4), Vector3(8.5, 0, 4.9), Vector3(11.4, 0, 4.9)])
	await _look(s, -35.0, 1.2, -0.06)   # la sala de vidrio, a la derecha
	await _hold(s, 1.0)
	var ok2: bool = ok and await _walk(s, [Vector3(18.75, 0, 4.9), Vector3(18.75, 0, 2.8), Vector3(19.0, 0, 0.5), Vector3(20.4, 0, 0.7)])
	await _look(s, -55.0, 1.4, -0.03)   # la sala de operaciones desde la entrada
	await _hold(s, 1.6)
	var ok3: bool = ok2 and await _walk(s, [Vector3(26.5, 0, 0.7)])
	await _look(s, -125.0, 1.6, -0.1)   # los puestos, de cerca
	await _hold(s, 1.6)
	print("[gfx_paseo] fin cuadro=%d ok=%s/%s/%s pos=(%.1f, %.1f, %.1f) caidas=%d" % [Engine.get_frames_drawn(), ok, ok2, ok3, p.global_position.x, p.global_position.y, p.global_position.z, p.fall_rescues])
	p.speed = speed0


func _ui_clear(s: Node) -> void:
	var old := s.get_tree().root.get_node_or_null("GfxUiPrueba")
	if old != null:
		old.free()


func _give_ack(_sec: float) -> void:
	Metrics.give_ack.call_deferred()

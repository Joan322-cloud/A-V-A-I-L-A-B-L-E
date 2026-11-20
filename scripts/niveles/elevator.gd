extends Node3D
## Ascensor con viaje real (GDD 7.1/7.6): cabina con puertas correderas, botonera interior
## (-1/1/2/9 encendidos; 3-8 apagados con lector rojo que rechaza), indicador de piso, zumbido del
## motor y "ding" al llegar. Pulsar 3 veces un piso bloqueado trae una línea de Shero por Ezlaki.
## El segundo ascensor del edificio siempre está "en mantenimiento" (lo pone cada piso).

const FLOORS: Array[int] = [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const SECONDS_PER_FLOOR := 0.75
const DOOR_SECONDS := 1.1

var current_floor: int = -1
var _panel_open: bool = false
var _ui: Control = null
var _leaf_l: MeshInstance3D = null
var _leaf_r: MeshInstance3D = null
var _indicator_in: Label3D = null
var _indicator_out: Label3D = null
var _light: OmniLight3D = null
var _doors_open: bool = true
var _traveling: bool = false
var _buttons: Dictionary = {}  # piso -> MeshInstance3D


func _ready() -> void:
	add_to_group("elevator")
	_build()
	_set_doors(true, true)
	_set_indicator(current_floor)


func _build() -> void:
	var inox := Greybox.inox()
	Greybox.box(self, "Piso", Vector3(0, -0.04, 0), Vector3(2.2, 0.08, 2.2), Greybox.GRIS_OSCURO)
	Greybox.box(self, "Techo", Vector3(0, 2.4, 0), Vector3(2.2, 0.08, 2.2), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "ParedFondo", Vector3(0, 1.2, -1.1), Vector3(2.2, 2.4, 0.1), Greybox.GRIS)
	var espejo := Greybox.box(self, "EspejoFondo", Vector3(0, 1.5, -1.04), Vector3(1.6, 1.0, 0.02), Color(0.5, 0.6, 0.66), false)
	espejo.material_override = Greybox.material(Color(0.45, 0.55, 0.6), 0.1, 0.08, 0.9)
	Greybox.box(self, "Pasamanos", Vector3(0, 0.9, -1.0), Vector3(1.8, 0.04, 0.06), Greybox.INOX, false).material_override = inox
	Greybox.box(self, "ParedIzq", Vector3(-1.1, 1.2, 0), Vector3(0.1, 2.4, 2.2), Greybox.GRIS)
	Greybox.box(self, "ParedDer", Vector3(1.1, 1.2, 0), Vector3(0.1, 2.4, 2.2), Greybox.GRIS)
	var lamp := Greybox.box(self, "Lampara", Vector3(0, 2.35, 0), Vector3(1.0, 0.04, 0.6), Color(0.85, 0.92, 0.92), false, 1.2)
	_light = Greybox.light(lamp, Vector3(0, -0.3, 0), Color(0.8, 0.9, 0.9), 0.55, 3.5)
	# Portal: pilastras anchas (las hojas se esconden detrás) y dintel con indicador exterior.
	for sx in [-1.6, 1.6]:
		Greybox.sbox(self, "Pilastra%d" % int(sx * 10 + 20), Vector3(sx, 1.3, 1.15), Vector3(1.0, 2.6, 0.5), "marmol")  # v0.3.1 Q5: mármol veteado (site)
	Greybox.sbox(self, "Dintel", Vector3(0, 2.5, 1.15), Vector3(2.2, 0.2, 0.5), "marmol")
	# Moldura negra del vano: dos jambas y un cabezal (no una placa).
	for jx in [-1.12, 1.12]:
		Greybox.box(self, "Jamba%d" % int(jx * 100 + 200), Vector3(jx, 1.2, 1.38), Vector3(0.08, 2.4, 0.04), Greybox.NEGRO, false)
	Greybox.box(self, "Cabezal", Vector3(0, 2.38, 1.38), Vector3(2.3, 0.06, 0.04), Greybox.NEGRO, false)
	_indicator_out = Greybox.label(self, "", Vector3(0, 2.72, 1.42), 0.22, Greybox.AMBAR)
	Greybox.box(self, "IndicadorCaja", Vector3(0, 2.72, 1.4), Vector3(0.7, 0.3, 0.04), Greybox.NEGRO, false)
	# Hojas correderas (con colisión: cerradas bloquean el paso).
	_leaf_l = Greybox.box(self, "HojaIzq", Vector3(-0.5, 1.15, 1.1), Vector3(1.0, 2.3, 0.06), Greybox.INOX)
	_leaf_l.material_override = inox
	_leaf_r = Greybox.box(self, "HojaDer", Vector3(0.5, 1.15, 1.1), Vector3(1.0, 2.3, 0.06), Greybox.INOX)
	_leaf_r.material_override = inox
	Greybox.box(_leaf_l, "Junta", Vector3(0.49, 0, 0), Vector3(0.015, 2.3, 0.07), Greybox.NEGRO, false)
	Greybox.box(_leaf_r, "Junta", Vector3(-0.49, 0, 0), Vector3(0.015, 2.3, 0.07), Greybox.NEGRO, false)
	# Botonera interior: -1/1/2/9 retroiluminados; 3-8 sin luz; lector rojo debajo (GDD 7.6).
	var panel := Greybox.box(self, "Panel", Vector3(1.04, 1.3, 0.5), Vector3(0.04, 0.95, 0.32), Greybox.GRIS_OSCURO, false)
	panel.material_override = inox
	for i in FLOORS.size():
		var f := FLOORS[i]
		var lit := not Building.BLOCKED_FLOORS.has(f)
		var col := Color(0.95, 0.9, 0.6) if lit else Color(0.12, 0.12, 0.12)
		var col_idx := i % 2
		var row := int(i / 2)
		var b := Greybox.box(panel, "Btn%d" % f, Vector3(-0.03, 0.36 - row * 0.14, -0.07 + col_idx * 0.14), Vector3(0.02, 0.07, 0.07), col, false, 1.4 if lit else 0.0)
		_buttons[f] = b
		Greybox.label(b, _short_label(f), Vector3(-0.012, 0.0, 0.0), 0.06, Greybox.NEGRO if lit else Color(0.35, 0.35, 0.35), -PI * 0.5)
	Greybox.box(panel, "Lector", Vector3(-0.03, -0.4, 0), Vector3(0.02, 0.05, 0.14), Greybox.ROJO, false, 2.0)
	Greybox.label(panel, tr("ELEVATOR_READER"), Vector3(-0.025, -0.33, 0), 0.05, Greybox.BLANCO, -PI * 0.5)
	Greybox.label(self, tr("ELEVATOR_PLATE"), Vector3(1.0, 1.92, 0.5), 0.045, Greybox.BLANCO, -PI * 0.5)
	_indicator_in = Greybox.label(self, "", Vector3(0, 2.15, 1.05), 0.2, Greybox.AMBAR, PI)
	var inter := Interactable.new()
	inter.name = "PanelInteract"
	inter.hint_key = "HUD_ELEVATOR"
	inter.size = Vector3(0.6, 1.2, 0.8)
	inter.position = Vector3(0.7, 1.3, 0.5)
	add_child(inter)
	inter.interacted.connect(_on_panel_used)
	Greybox.marker(self, "ascensor_dentro", Vector3(0, 0, 0.2), 180.0)


func _short_label(f: int) -> String:
	return "S" if f == -1 else str(f)


func _set_indicator(f: int) -> void:
	var t := ("S" if f == -1 else str(f))
	ObjectAnim.floor_indicator(_indicator_in, t)  # v0.3.2-anim: el número rueda y una flecha marca el sentido
	ObjectAnim.floor_indicator(_indicator_out, t)


## API pública (v0.3.1, la usa Pursuit para el tránsito visible de Q2): indicador de piso y hojas.
func show_floor(f: int) -> void:
	_set_indicator(f)


func set_doors(open: bool, instant: bool = false) -> void:
	_set_doors(open, instant)


## Abre/cierra las hojas (instantáneo o con tween). Cerradas bloquean el paso.
func _set_doors(open: bool, instant: bool = false) -> void:
	_doors_open = open
	var xl := -1.55 if open else -0.5
	var xr := 1.55 if open else 0.5
	ObjectAnim.kill_tween(self, "oa_puertas")  # v0.3.2-anim: una orden nueva corta el recorrido anterior
	if instant:
		_leaf_l.position.x = xl
		_leaf_r.position.x = xr
		return
	ObjectAnim.elevator_doors(self, _leaf_l, _leaf_r, xl, xr, DOOR_SECONDS, open)  # la misma curva + rebote de gomas al cerrar
	AudioManager.play_sfx("puerta_vidrio", "Sala")


## Llamado por Building al llegar a un piso dentro de la cabina: puertas cerradas que se abren.
func arrive() -> void:
	_set_doors(false, true)
	_set_indicator(current_floor)
	AudioManager.play_sfx("ascensor_llegada", "Sala")
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	_set_doors(true)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = false


func _on_panel_used(_player: Node) -> void:
	open_panel()


func open_panel() -> void:
	if _panel_open or _traveling:
		return
	_panel_open = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true
		player.capture_mouse(false)
	_ui = _make_ui()
	var layer := CanvasLayer.new()
	layer.name = "ElevatorUI"
	layer.layer = 20
	layer.add_child(_ui)
	get_tree().root.add_child(layer)


func _make_ui() -> Control:
	var root := UITheme.panel(tr("ELEVATOR_TITLE"), Vector2(420, 0))
	UITheme.center_fit(root)
	var vb := UITheme.vb_of(root)
	var plate := UITheme.label(tr("ELEVATOR_PLATE"), 13, UITheme.DIM)
	plate.custom_minimum_size = Vector2(380, 0)
	vb.add_child(plate)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	for f in [9, 8, 7, 6, 5, 4, 3, 2, 1, -1]:
		var b := Button.new()
		var blocked := Building.BLOCKED_FLOORS.has(f)
		b.text = _floor_label(f)
		b.custom_minimum_size = Vector2(190, 36)
		if blocked:
			b.modulate = Color(0.45, 0.45, 0.45)
		elif f == current_floor:
			b.modulate = Color(0.9, 0.85, 0.6)
		b.pressed.connect(_on_floor_pressed.bind(f))
		b.set_meta("guia", "ascensor:piso:%d" % f)  # v0.3.2: la guía del Training señala el botón del piso (TrainingTargets)
		grid.add_child(b)
	var reader := UITheme.label("■ " + tr("ELEVATOR_READER"), 12, UITheme.RED)
	vb.add_child(reader)
	var close := UITheme.button(tr("OPT_BACK"), close_panel)
	vb.add_child(close)
	return root


func _floor_label(f: int) -> String:
	match f:
		-1: return tr("ELEVATOR_FLOOR_M1")
		1: return tr("ELEVATOR_FLOOR_1")
		2: return tr("ELEVATOR_FLOOR_2")
		9: return tr("ELEVATOR_FLOOR_9")
	return "%d · %s" % [f, tr("ELEVATOR_DENIED")]


func _on_floor_pressed(f: int) -> void:
	if Building.BLOCKED_FLOORS.has(f):
		AudioManager.play_sfx("ascensor_boton_muerto", "UI")
		EventBus.show_message.emit(tr("ELEVATOR_DENIED"), 2.0)
		var n := int(GameState.flags.get("elevator_blocked_presses", 0)) + 1
		GameState.flags["elevator_blocked_presses"] = n
		if n == 3 and GameState.logged_in:
			# Tercera vez: Shero lo ve en el reporte de accesos y escribe por Ezlaki.
			EventBus.shero_message.emit("ascensor_pisos", "dm")
		return
	close_panel()
	if f == current_floor:
		return
	_travel(f)


## Viaje: cierra puertas, zumbido, el indicador recorre los pisos, ding y carga el piso destino.
func _travel(target: int) -> void:
	if _traveling:
		return  # v0.3.2 (integración): un viaje a la vez. Dos pedidos seguidos (el bot humano con dos recorridos a la vez)
		# terminaban en dos Building.go_to_floor en el mismo cuadro: el piso se armaba dos veces y el primero se liberaba
		# con llamadas diferidas pendientes (errores del motor en AudioDirector._attach_highway y RainEngine._adopt).
	_traveling = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true
		player.capture_mouse(true)
		# Dentro de la cabina, mirando a la puerta.
		var inside := global_position + global_transform.basis * Vector3(0, 0, 0.1)
		player.teleport(inside, rotation_degrees.y + 180.0)
		player.input_locked = true
	_set_doors(false)
	await get_tree().create_timer(DOOR_SECONDS + 0.2).timeout
	if not is_inside_tree():
		return
	AudioManager.play_loop("sfx/ascensor_motor", 52.0, -14.0)
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.55, 0.4)
	var f := current_floor
	var step := 1 if target > f else -1
	while f != target:
		f += step
		if f == 0:
			continue  # no hay piso 0: del -1 se pasa al 1
		await get_tree().create_timer(SECONDS_PER_FLOOR).timeout
		if not is_inside_tree():
			return
		_set_indicator(f)
		if player != null:
			player.head.position.y = 1.6 + randf_range(-0.012, 0.012)  # vibración leve de la cabina
	AudioManager.stop_ambient("ascensor_motor")
	AudioManager.play_sfx("ascensor_llegada", "Sala")
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var building := get_tree().get_first_node_in_group("building") as Building
	if building != null:
		building.go_to_floor(target, "ascensor_dentro")
	_traveling = false


func close_panel() -> void:
	if not _panel_open:
		return
	_panel_open = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = false
		player.capture_mouse(true)
	if _ui != null and _ui.get_parent() != null:
		_ui.get_parent().queue_free()
	_ui = null

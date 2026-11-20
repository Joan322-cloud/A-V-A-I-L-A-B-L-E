## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends Node
## screenshot: recorre puntos de vista del edificio y guarda PNG en user://shots/.
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 -- --shot [nombre|all]
## Vistas: pc, pc_zoom, pc_reflejo, sala, casilleros, pasillo_agua, bano_p2, cafeteria, lobby, calle, bano_m1.
## v0.3: registro extensible. Cada paquete añade vistas en scripts/dev/shots/pN_<tema>.gd (RefCounted) con
##   func shots() -> Array[String]: return ["pingpong_m1", "screamer:"]   # "x:" acepta argumento (screamer:break_excedido)
##   func shoot(name: String, arg: String, s: Node) -> void: ...          # corrutina: prepara la escena; luego se captura
## `s` es este nodo: s._place(piso, pos, yaw, pitch), s._sit_c14(), s._building(), s._player(), s._main.
## `-- --shot lista` lista todas; `-- --shot pN` captura las del paquete.

const VIEWS: Array[String] = ["pc", "pc_zoom", "pc_reflejo", "shero", "fila_c", "sala", "casilleros", "pasillo_agua", "bano_p2", "cafeteria", "lobby", "calle", "bano_m1", "piso1", "piso1_training", "azotea", "ascensor", "ascensor_panel", "ascensor_viaje", "ascensor_llegada", "escalera", "escalera_arriba", "espejo_cam", "vitzo", "pc_vitzo_fondo", "cuerpo", "cuerpo_sentado", "rta", "perro", "muerte", "pausa", "menu", "opciones", "creditos"]

## Recorrido para docs/capturas (10 vistas): `-- --shot tour`.
const TOUR: Array[String] = ["calle", "lobby", "cafeteria", "casilleros", "pc", "shero_cerca", "bano_p2", "azotea", "muerte", "menu"]
## v0.2 (con `--turno 2` / `--turno 3`): `-- --shot tour_t2` y `-- --shot tour_t3`.
const TOUR_T2: Array[String] = ["training_vidrio", "trainer_cerca", "topico_enfermera", "expendedora_menu", "fonex_saldo"]
const TOUR_T3: Array[String] = ["ezlak_allocation", "marleny", "mentor_sitio", "menu"]

var _main: Node = null
var _which: String = "all"
var _registry: Dictionary = {}  # nombre (o "x:") -> ruta del script de vistas
const SHOTS_DIR := "res://scripts/dev/shots/"


func start(main: Node, which: String) -> void:
	_main = main
	_which = which
	_run()


func _discover() -> void:
	var d := DirAccess.open(SHOTS_DIR)
	if d == null:
		return
	var seen := {}
	for f0 in d.get_files():
		# v0.3.2-core: en un exportado los guiones van compilados (`x.gdc` + `x.gd.remap`); se cargan como `x.gd`.
		var f: String = f0.trim_suffix(".remap")
		if f.ends_with(".gdc"):
			f = f.trim_suffix(".gdc") + ".gd"
		if seen.has(f):
			continue
		seen[f] = true
		if f.begins_with("p") and f.ends_with(".gd"):
			var scr := load(SHOTS_DIR + f) as GDScript
			if scr == null:
				continue
			var inst: Object = scr.new()
			if inst.has_method("shots"):
				for n in inst.call("shots"):
					_registry[str(n)] = SHOTS_DIR + f


func _run() -> void:
	_discover()
	if _which == "lista":
		for v in VIEWS + TOUR_T2 + TOUR_T3:
			print(v)
		for k in _registry.keys():
			print(k, "   (", str(_registry[k]).get_file(), ")")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
	await get_tree().create_timer(0.5).timeout
	var views: Array[String] = []
	if _which.length() <= 3 and _which.begins_with("p") and _which != "pc":
		for k in _registry.keys():
			if str(_registry[k]).get_file().begins_with(_which + "_") and not str(k).ends_with(":"):
				views.append(str(k))
	elif _which == "all":
		views = VIEWS.duplicate()
	elif _which == "tour":
		views = TOUR.duplicate()
	elif _which == "tour_t2":
		views = TOUR_T2.duplicate()
	elif _which == "tour_t3":
		views = TOUR_T3.duplicate()
	elif _which.contains("+"):  # P7: varias vistas en una sola corrida (`--shot menu+pausa+p7_resumen`)
		for v in _which.split("+", false):
			views.append(v)
		# En una corrida larga el reloj avanza: el recordatorio de Vitzo (03:00) no debe matar entre vistas.
		EventBus.vitzo_reminder.connect(func(_e: String, _s: float) -> void: EventBus.vitzo_reacted.emit.call_deferred())
	else:
		views.append(_which)
	for v in views:
		await _view(v)
	print("[shot] listo: ", ProjectSettings.globalize_path("user://shots"))
	get_tree().quit(0)


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _place(floor_n: int, pos: Vector3, yaw_deg: float, pitch: float = 0.0) -> void:
	var b := _building()
	if b.current_floor != floor_n:
		b.go_to_floor(floor_n, "ascensor")
		await get_tree().create_timer(0.3).timeout
	var p := _player()
	if p.seated:
		p.stand_up()
	p.teleport(pos, yaw_deg)
	p.head.rotation.x = pitch


func _sit_c14() -> void:
	var b := _building()
	if b.current_floor != 2:
		b.go_to_floor(2, "pc")
		await get_tree().create_timer(0.3).timeout
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id("C-14")
	var p := _player()
	if not p.seated:
		p.sit_at(seat, "C-14")
	if not GameState.logged_in:
		GameState.login()
	p.head.rotation.x = -0.12


func _view(v: String) -> void:
	# P7: con varias vistas seguidas (`a+b+c`), las de menú/opciones/créditos dejan el juego en el menú; la
	# siguiente vista del mundo vuelve a empezar un turno (antes, _sit_c14 sin edificio = SCRIPT ERROR).
	if _building() == null and not (v in ["menu", "opciones", "creditos"] or v.begins_with("menu_") or v.begins_with("p6b_menu") or v.begins_with("p6b_tut_menu") or v.begins_with("p6b_turnos")):
		_main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
		await get_tree().create_timer(0.6).timeout
	var ws := get_tree().get_first_node_in_group("workstation")
	match v:
		"pc":
			await _sit_c14()
			ws.call("set_zoom", false)
		"pc_zoom":
			await _sit_c14()
			ws.call("set_zoom", true)
		"pc_reflejo":
			await _sit_c14()
			ws.call("set_zoom", false)
			var sh := get_tree().get_first_node_in_group("shero")
			if sh != null and sh.has_method("scripted_reflection"):
				sh.call("scripted_reflection")
				for _i in 60:  # hasta 6 s a que aparezca el reflejo
					await get_tree().create_timer(0.1).timeout
					var shown := false
					for sc in get_tree().get_nodes_in_group("monitor_screens"):
						if sc is MonitorScreen and (sc as MonitorScreen)._reflection_left > 1.0:
							shown = true
					if shown:
						break
		"shero":
			await _place(2, Vector3(44.0, 0, -9.3), -90.0)
		"shero_cerca":
			await _place(2, Vector3(45.2, 0, -9.0), -90.0, 0.08)
			var sh2 := get_tree().get_first_node_in_group("shero") as Node3D
			if sh2 != null:
				sh2.global_position = Vector3(46.9, 0, -9.0)
				sh2.rotation.y = PI * 0.5
		"fila_c":
			await _place(2, Vector3(45.2, 0, -9.6), 90.0, -0.1)
		"sala":
			await _place(2, Vector3(20.5, 0, 0.8), -55.0)
		"casilleros":
			await _place(2, Vector3(0, 0, 4.6), 180.0)
		"pasillo_agua":
			await _place(2, Vector3(6.8, 0, 20), -90.0)
		"bano_p2":
			await _place(2, Vector3(-8.2, 0, -1.2), 90.0)
		"cafeteria":
			await _place(-1, Vector3(13.8, 0, 7.5), -70.0)
		"lobby":
			await _place(-1, Vector3(0, 0, 12.5), 0.0)
		"calle":
			await _place(-1, Vector3(1.0, 2.15, 26.0), 0.0, 0.1)  # v0.3.1 Q5: vereda a 2,1 m
		"bano_m1":
			await _place(-1, Vector3(-9, 0, -1.9), 0.0)
		"piso1":
			await _place(1, Vector3(-2, 0, 1.5), -75.0)
		"piso1_training":
			await _place(1, Vector3(14, 0, -1.0), 10.0)
		"azotea":
			await _place(9, Vector3(0, 0, -2.0), 180.0, 0.05)
		"ascensor":
			await _place(-1, Vector3(-3, 0, 0.8), 0.0)
		"ascensor_panel":
			await _place(-1, Vector3(-3.4, 0, -2.6), -90.0, -0.1)
		"ascensor_llegada":
			await _place(-1, Vector3(-3, 0, -2.6), 180.0)
			var elev2 := get_tree().get_first_node_in_group("elevator")
			elev2.call("_travel", 2)
			await get_tree().create_timer(6.0).timeout
			print("[shot] tras el viaje: piso %d, input_locked=%s" % [_building().current_floor, str(_player().input_locked)])
		"ascensor_viaje":
			await _place(-1, Vector3(-3, 0, -2.6), 180.0)
			var elev := get_tree().get_first_node_in_group("elevator")
			elev.call("_travel", 2)
			await get_tree().create_timer(1.6).timeout  # puertas cerradas, indicador en marcha
		"escalera":
			await _place(-1, Vector3(9, 0, -2.0), 0.0)
			_building().go_to_stairwell(1, true)
			await get_tree().create_timer(0.3).timeout
			_player().head.rotation.x = 0.15
		"espejo_cam":
			await _place(2, Vector3(-8.2, 0, -1.2), 90.0)
			Fatigue.value = 60.0
			var dc := get_tree().get_first_node_in_group("distortions")
			dc.call("_fire", "el_espejo")
			await get_tree().create_timer(2.5).timeout
		"vitzo":
			await _sit_c14()
			ws.call("set_zoom", false)
			VitzoScreamer.play(self)
		"pc_vitzo_fondo":
			await _sit_c14()
			ws.call("set_zoom", true)
			GameState.flags["vitzo_wallpaper"] = true
		"cuerpo":
			await _place(2, Vector3(20.5, 0, 0.8), -55.0, -1.25)
		"cuerpo_sentado":
			await _sit_c14()
			_player().head.rotation.x = -1.1
		"rta":
			await _place(2, Vector3(20.0, 0, -18.4), -90.0, -0.35)
			var rta := get_tree().get_first_node_in_group("rta") as Node3D
			if rta != null:
				rta.global_position = Vector3(22.0, 0, -19.1)
				rta.rotation.y = PI * 0.5
		"perro":
			await _place(-1, Vector3(5.6, 2.15, 23.6), -110.0, -0.35)
		"muerte":
			await _sit_c14()
			EventBus.death_requested.emit("ww_sin_ack", "")
			# v0.3: el screamer va antes de la pantalla (hasta 5 s).
			for _i in 60:
				await get_tree().create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
		"pausa":
			await _sit_c14()
			_main.get("pause_menu").call("toggle")
		"menu":
			_main.call("_back_to_menu")
			await get_tree().create_timer(0.3).timeout
		"opciones":
			_main.call("_back_to_menu")
			await get_tree().create_timer(0.2).timeout
			_main.get("main_menu").call("_open_options")
		"creditos":
			_main.call("_back_to_menu")
			await get_tree().create_timer(0.2).timeout
			_main.get("main_menu").call("_open_credits")
		"training_vidrio":
			# Piso 1, en el pasillo frente a la sala 2: el Trainer dicta a las siluetas al otro lado del vidrio.
			await _place(1, Vector3(18.0, 0, 0.6), 0.0, -0.02)
			await get_tree().create_timer(1.2).timeout
		"trainer_cerca":
			await _place(1, Vector3(18.0, 0, 0.6), 0.0, 0.0)
			var trn := get_tree().get_first_node_in_group("trainer")
			if trn != null:
				trn.call("force_intercept")
				for _i in 80:  # hasta 8 s a que salga y llegue
					await get_tree().create_timer(0.1).timeout
					if int(trn.get("state")) >= 4:  # SCREAMER o CHARLA
						break
		"topico_enfermera":
			await _place(1, Vector3(8.0, 0, -1.0), 0.0, 0.02)
		"expendedora_menu":
			await _place(-1, Vector3(24.6, 0, 4.0), -90.0, 0.0)
			var vend := _building().floor_node.find_child("Expendedora", true, false)
			if vend is Interactable:
				(vend as Interactable).interact(_player())
		"fonex_saldo":
			await _sit_c14()
			ws.call("set_zoom", true)
		"ezlak_allocation":
			await _sit_c14()
			ws.call("set_zoom", true)
			var men := get_tree().get_first_node_in_group("mentor")
			if men != null:
				men.call("post_allocation_now")
			await get_tree().create_timer(0.6).timeout
		"marleny":
			await _place(-1, Vector3(20.0, 0, 4.6), 0.0, 0.04)
			var mostrador := _building().floor_node.find_child("MostradorMarleny", true, false)
			if mostrador is Interactable:
				(mostrador as Interactable).interact(_player())
		"mentor_sitio":
			await _place(2, Vector3(43.5, 0, -12.2), -90.0, 0.05)
		"escalera_arriba":
			await _place(-1, Vector3(9, 0, -2.0), 0.0)
			_building().go_to_stairwell(1, true)
			await get_tree().create_timer(0.3).timeout
			_player().teleport(_building().floor_node.global_position + Vector3(0, 3.25, 10.5), 0.0)
			_player().head.rotation.x = -0.2
		_:
			if not await _registry_view(v):
				printerr("[shot] vista desconocida: ", v)
				return
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# v0.3.2-core: «vista:argumento» no es un nombre de archivo válido en Windows (el exportado bajo Wine lo dejó ver).
	var path := "user://shots/%s.png" % (v.replace(":", "_") if OS.get_name() == "Windows" else v)
	img.save_png(path)
	print("[shot] ", v, " -> ", ProjectSettings.globalize_path(path))
	if v in ["pc_zoom", "fonex_saldo", "ezlak_allocation"]:
		ws.call("set_zoom", false)
	if v in ["expendedora_menu", "marleny"]:
		var shop := get_tree().get_first_node_in_group("shop_menu")
		if shop != null:
			shop.call("close")
	elif v == "pausa":
		_main.get("pause_menu").call("toggle")
	elif v == "muerte":
		get_tree().paused = false
		Checkpoints.respawn()
	var post := _registry_script(v)
	if post != null and post.has_method("after"):
		await post.call("after", v, self)


func _registry_key(v: String) -> String:
	if _registry.has(v):
		return v
	if v.contains(":") and _registry.has(v.get_slice(":", 0) + ":"):
		return v.get_slice(":", 0) + ":"
	return ""


func _registry_script(v: String) -> Object:
	var key := _registry_key(v)
	if key == "":
		return null
	var scr := load(str(_registry[key])) as GDScript
	return scr.new() if scr != null else null


## Vista de un paquete (scripts/dev/shots/pN_*.gd). false si no existe.
func _registry_view(v: String) -> bool:
	var inst := _registry_script(v)
	if inst == null:
		return false
	var arg := v.substr(v.find(":") + 1) if v.contains(":") else ""
	await inst.call("shoot", v.get_slice(":", 0), arg, self)
	return true

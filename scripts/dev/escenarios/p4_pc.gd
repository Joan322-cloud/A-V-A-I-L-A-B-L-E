## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenario de P4 · PC con ratón (PLAN §2 #50, §6.5): clics reenviados al SubViewport (push_input) en cada
## app de la barra de tareas, en una opción del árbol, en "Aceptar" de Fonex, y en un botón AUX del terminal;
## la vista acercada convierte las coordenadas de la ventana a las de la pantalla; el ratón queda libre.


func escenarios() -> Array[String]:
	return ["ui_pc"]


func run(_id: String, _arg: String, t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var ws: Node = t.main.get_node("UI/Workstation")
	var desk: PcDesktop = ws.get("desktop") as PcDesktop
	var fonex: PcFonex = ws.get("fonex") as PcFonex
	var cm := t.main.get("contacts") as ContactManager
	ws.call("set_zoom", true)
	await t.frames(3)
	t.check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DisplayServer.get_name() == "headless", "vista acercada: ratón visible")
	var lvp: SubViewport = ws.get("_left_vp")
	var rvp: SubViewport = ws.get("_right_vp")
	t.check(not lvp.gui_disable_input and not rvp.gui_disable_input, "las pantallas aceptan ratón (gui_disable_input = false)")
	# Cada app de la barra de tareas con un clic.
	for app in PcDesktop.APPS:
		var b: Button = desk._task_buttons[app]
		ws.call("click_screen", "left", ws.call("screen_pos_of", b))
		await t.frames(2)
		t.check(desk.active_app == app, "clic en la barra de tareas abre %s (activa: %s)" % [app, desk.active_app])
	# Clic a través de la vista acercada (coordenadas de la ventana → pantalla).
	var zl: TextureRect = ws.get("_zoom_left")
	var target: Button = desk._task_buttons["correo"]
	var screen_pos: Vector2 = ws.call("screen_pos_of", target)
	var local := screen_pos * (zl.size / Vector2(lvp.size))
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = local
		ws.call("_forward", lvp, zl, e)
	await t.frames(2)
	t.check(desk.active_app == "correo", "un clic sobre la imagen acercada llega al botón de la pantalla")
	# Fonex: aceptar un contacto con clic; elegir una opción del árbol con clic.
	var call: Dictionary = (DataLoader.dict("contactos_t1").get("contactos", [])[0] as Dictionary).duplicate(true)
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(call)
	await t.frames(2)
	fonex.refresh(0.0)
	ws.call("click_screen", "right", ws.call("screen_pos_of", fonex._accept))
	await t.frames(2)
	t.check(cm.is_active() and cm.tree != null, "clic en «Aceptar» de Fonex acepta la llamada")
	t.check(desk.active_app == "kardex", "la llamada abre Kardex sola")
	desk.refresh(0.0)
	await t.frames(2)
	var node0 := cm.tree.node_id
	var opt: Button = desk.kardex._opts.get_child(0) as Button
	ws.call("click_screen", "left", ws.call("screen_pos_of", opt))
	await t.frames(2)
	t.check(cm.tree == null or cm.tree.node_id != node0 or cm.tree.history.size() > 1, "clic en la opción 1 del árbol avanza la conversación")
	while cm.tree != null:
		cm.choose(0)
		if cm.tree != null and cm.tree.waiting_action():
			cm.tree.action_done("ok")
			cm._after_tree_step()
	# v0.3.2: ya no hay terminales de pared; el clic en un AUX de Fonex vale en la PC acercada.
	ws.call("set_zoom", true)
	await t.frames(2)
	fonex.refresh(0.0)
	var bo_btn: Button = fonex._aux_buttons[Metrics.Aux.BO]
	ws.call("click_screen", "right", ws.call("screen_pos_of", bo_btn))
	await t.frames(2)
	t.check(Metrics.aux == Metrics.Aux.BO and not bool(ws.get("_terminal_mode")), "PC: clic en «BO» de Fonex cambia el AUX")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	# Tab cambia la distribución (ambas → izquierda → derecha → ambas).
	await t.login_at_seat()
	ws.call("set_zoom", true)
	ws.call("cycle_layout")
	t.check(zl.visible and not (ws.get("_zoom_right") as TextureRect).visible, "[Tab]: solo la pantalla izquierda (más grande)")
	ws.call("cycle_layout")
	ws.call("cycle_layout")
	t.check(zl.visible and (ws.get("_zoom_right") as TextureRect).visible, "[Tab] x3: vuelve a las dos pantallas")
	ws.call("set_zoom", false)

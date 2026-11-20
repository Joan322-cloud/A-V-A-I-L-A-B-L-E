extends Control
## Menú de pausa = ventana "Sesión bloqueada" (GDD 8.3): Reanudar, Opciones, Reiniciar contacto, Marcar salida.
## Escape no la abre durante una muerte (GameState.running = false): ahí Escape es "Volver al menú".
## v0.3 P6b: "Manual del agente" (glosario y reglas, ui/agent_manual.gd).

signal quit_to_menu()

var _open: bool = false
var _options: OptionsMenu = null
var _manual: Control = null
var _restart_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	add_child(bg)
	var p := UITheme.panel(tr("PAUSE_TITLE"), Vector2(400, 0))
	UITheme.center_fit(p)
	var vb := UITheme.vb_of(p)
	vb.add_child(UITheme.button(tr("PAUSE_RESUME"), toggle))
	vb.add_child(UITheme.button(tr("MENU_OPTIONS"), _open_options))
	var man := UITheme.button(tr("PAUSE_MANUAL"), open_manual)
	man.name = "ManualBtn"
	vb.add_child(man)
	_restart_btn = UITheme.button(tr("PAUSE_RESTART_CONTACT"), _restart_contact)
	vb.add_child(_restart_btn)
	vb.add_child(UITheme.button(tr("PAUSE_QUIT"), _quit))
	if GameState.DEV_TOOLS_ENABLED:
		vb.add_child(HSeparator.new())
		var dev_lbl := UITheme.label("[DEV TESTER] Saltar / Ganar Turno", 13, UITheme.YELLOW, true)
		dev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(dev_lbl)
		var win_btn := UITheme.button("★ Ganar / Pasar Turno Actual (08:45)", _dev_win_shift)
		win_btn.add_theme_color_override("font_color", UITheme.GREEN)
		vb.add_child(win_btn)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		vb.add_child(grid)
		var labels := ["T0 Tut", "T1 Lun", "T2 Mar", "T3 Mié", "T4 Jue", "T5 Vie", "T6 Sáb", "T7 Dom"]
		for ti in labels.size():
			var tb := UITheme.button(labels[ti], _dev_jump_turn.bind(ti))
			tb.custom_minimum_size = Vector2(82, 32)
			grid.add_child(tb)
	add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if _manual != null:
		return  # el manual se cierra con su propio [Esc]
	if event.is_action_pressed("pause") and GameState.running:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_open = not _open
	visible = _open
	get_tree().paused = _open
	if _open and _restart_btn != null:
		_restart_btn.disabled = not Checkpoints.can_restart_contact()  # Turno real o sin checkpoint: no
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = _open
		player.capture_mouse(not _open)
	var tut_ui := get_tree().root.get_node_or_null("TutorialUI") as CanvasLayer  # P6b: el panel de la inducción no tapa la pausa
	if tut_ui != null:
		tut_ui.visible = not _open


## Cierra la pausa sin efectos (volver al menú, iniciar turno).
func reset() -> void:
	var tut_ui := get_tree().root.get_node_or_null("TutorialUI") as CanvasLayer if is_inside_tree() else null
	if tut_ui != null:
		tut_ui.visible = true
	if _options != null:
		_options.queue_free()
		_options = null
	if _manual != null:
		_manual.queue_free()
		_manual = null
	_open = false
	visible = false


## Manual del agente (glosario + reglas). Con la pausa abierta; la Inducción espera a que se abra.
func open_manual() -> void:
	if _manual != null:
		return
	_manual = AgentManual.new()
	_manual.closed.connect(func() -> void: _manual.queue_free(); _manual = null)
	add_child(_manual)


func _open_options() -> void:
	if _options != null:
		return
	_options = OptionsMenu.new()
	_options.closed.connect(func() -> void: _options.queue_free(); _options = null)
	add_child(_options)


## v0.3: vuelve al inicio del contacto (último checkpoint) sin incidencia, sin Fatiga extra y una sola vez.
## (La v0.2 fingía un colapso y respawneaba dos veces: +30 de Fatiga y el bucle de muerte, PLAN §1.)
func _restart_contact() -> void:
	toggle()
	Checkpoints.restart_contact()


func _quit() -> void:
	toggle()
	quit_to_menu.emit()


func _dev_win_shift() -> void:
	toggle()
	if GameState.is_tutorial():
		var m := get_tree().root.get_node_or_null("Main")
		if m != null and m.has_method("_after_training"):
			m.call("_after_training", "Jiroshi", true, {})
		return
	GameState.logged_in = true
	GameState.clock_seconds = GameState.shift_end_seconds()
	GameState.shift_over = true
	GameState.running = false
	EventBus.shift_ended.emit()

func _dev_jump_turn(t: int) -> void:
	toggle()
	var m := get_tree().root.get_node_or_null("Main")
	if m == null:
		return
	if t == 0:
		if m.has_method("_start_first_training"):
			m.call("_start_first_training", "Jiroshi", GameState.mode)
	else:
		if m.has_method("_start_shift"):
			m.call("_start_shift", "Jiroshi", GameState.mode, t, false)

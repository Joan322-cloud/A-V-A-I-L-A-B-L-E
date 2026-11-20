extends Control
## Menú principal (GDD 8.3). v0.3.1 Q4 (F24, D8 de Joan): al abrir el juego, la INTRO DE ARRANQUE (intro_arranque.gd)
## → MENÚ PRINCIPAL (logo «● A V A I L A B L E»: Jugar, Inducción, Opciones, Manual, Créditos, Salir) → recién con
## «Jugar» la SELECCIÓN DE AGENTE: los 5 con el resumen de su partida (SaveSlots.summary_text) y, por agente,
## Continuar / Elegir turno / Nueva partida (o «Empezar» sin partida), más el modo y la dificultad. «Atrás» vuelve
## al menú principal. Las señales hacia main.gd no cambian (start_requested, continue_requested,
## tutorial_requested, branch_*): main.gd no se toca.
## Compatibilidad (pruebas y capturas de P1/P6b/P7): `agent_index`, `_build()`, `_open_turns()`, `_open_options()`,
## `_open_credits()`, `close_subpanels()` y los nombres StartBtn / ContinueBtn / PickTurnBtn / NewGameBtn /
## TutorialBtn / SlotLbl (los del agente elegido) siguen existiendo: las dos pantallas se construyen siempre y solo
## una es visible (`screen`).
## La intro se ve entera la primera vez; después cualquier tecla o clic la salta (settings: "intro_vista"). Con
## --bot, --escenario, --shot, --check-*, --walk-test, --web-qa o en headless no sale.

signal start_requested(agent: String, mode: int, turno: int)
signal continue_requested()
signal tutorial_requested(modules: Array)
signal first_training_requested(agent: String, mode: int)  # v0.3.2: partida nueva → Training obligatorio
signal branch_requested(turno: int, mode: int)
signal branch_resume_requested()

const TUTORIAL_SCRIPT := "res://scripts/core/tutorial.gd"
const TUTORIAL_MENU_SCRIPT := "res://scripts/ui/tutorial_menu.gd"
const NO_INTRO_ARGS: Array[String] = ["--bot", "--escenario", "--shot", "--check-all", "--check-collision", "--walk-test", "--qa-tour", "--random-walk", "--web-qa", "--bot-tutorial", "--repro-colapso", "--sin-intro"]

const FACE_COLORS: Dictionary = {
	"Jiroshi": Color(0.55, 0.35, 0.25), "Marko": Color(0.3, 0.4, 0.55), "Llauri": Color(0.45, 0.5, 0.3),
	"Ttoom": Color(0.5, 0.3, 0.45), "Juan": Color(0.25, 0.25, 0.28),
}

var agent_index: int = 0
var mode: int = GameState.Mode.NORMAL
var screen: String = "home"  # home | agents
var intro: Control = null
var _root: Control = null
var _home: VBoxContainer = null
var _agents: VBoxContainer = null
var _dot_t: float = 0.0
var _dot: ColorRect = null
var _title: Label = null
var _title_e: Label = null
var _status: Label = null
var _options: OptionsMenu = null
var _credits: CreditsScreen = null
var _manual: Control = null
var _confirm_new: bool = false  # "Nueva partida" pulsado una vez: falta confirmar
var _notice: String = ""
var _turns: TurnSelect = null
var _tut_menu: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.02, 0.025)
	add_child(bg)
	# Rejilla tenue de "escritorio corporativo" y una franja cian arriba (color de la empresa).
	var grid := ColorRect.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.color = Color(1, 1, 1)
	grid.material = _grid_material()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	var bar := ColorRect.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 6
	bar.color = Color(0.16, 0.42, 0.42)
	add_child(bar)
	agent_index = 0
	if not GameState.PLAYABLE_AGENTS.has(SaveSlots.current):
		SaveSlots.select("Jiroshi")
	mode = int(SaveSlots.progress().get("mode", GameState.Mode.NORMAL))
	_build()
	_ensure_cinematics.call_deferred()
	if should_play_intro():
		play_intro()


## Las cinemáticas de turno (scripts/fx/cinematicas.gd) viven junto a la UI, sin tocar main.gd.
func _ensure_cinematics() -> void:
	var p := get_parent()
	if p != null and p.get_node_or_null("Cinematicas") == null:
		var c := Cinematicas.new()
		c.name = "Cinematicas"
		p.add_child(c)


static func should_play_intro() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var args := OS.get_cmdline_user_args()
	for a in NO_INTRO_ARGS:
		if args.has(a):
			return false
	return true


## Intro de arranque (también la usan las capturas y las pruebas). `force_full` = como la primera vez.
func play_intro(force_full: bool = false) -> Control:
	if intro != null and is_instance_valid(intro):
		intro.queue_free()
	intro = IntroArranque.new()
	intro.name = "IntroArranque"
	(intro as IntroArranque).skippable = not force_full and bool(Loc.get_setting("intro_vista", false))
	(intro as IntroArranque).finished.connect(_on_intro_finished)
	add_child(intro)
	return intro


func _on_intro_finished() -> void:
	Loc.set_setting("intro_vista", true)
	if intro != null and is_instance_valid(intro):
		intro.queue_free()
	intro = null
	screen = "home"
	_show_screen()


func _grid_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 px = FRAGCOORD.xy;
	float g = (mod(px.x, 48.0) < 1.0 || mod(px.y, 48.0) < 1.0) ? 0.045 : 0.0;
	float scan = 0.012 * sin(px.y * 3.1416);
	float vig = 1.0 - 0.6 * length(UV - 0.5);
	COLOR = vec4(vec3(0.5, 0.8, 0.8) * (g + scan) * vig, 1.0) * vec4(1.0, 1.0, 1.0, 0.9);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _process(delta: float) -> void:
	if not visible:
		return
	_dot_t += delta
	# En el menú el punto de estado es rojo y la última E late (GDD 8.3): se atenúa, nunca se borra.
	if _title_e != null:
		_title_e.modulate.a = 1.0 if fmod(_dot_t, 2.25) < 2.0 else 0.55
	if _status != null:
		_status.text = Loc.fmt(tr("MENU_STATUS_LINE"), {"hora": Time.get_time_string_from_system().substr(0, 5), "srv": "knz-lim-02"})


func _unhandled_input(event: InputEvent) -> void:
	if not visible or intro != null:
		return
	if screen == "agents" and event.is_action_pressed("ui_cancel") and _turns == null and _options == null and _credits == null and _manual == null and _tut_menu == null:
		go_home()
		get_viewport().set_input_as_handled()


func _build() -> void:
	if _root != null:
		_root.queue_free()
	var agent_now := GameState.AGENTS[agent_index]
	if SaveSlots.current != agent_now:
		SaveSlots.select(agent_now)
	_dot_t = 0.0
	_root = Control.new()
	_root.name = "Pantallas"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# Un panel abierto sigue ENCIMA del menú recién armado (al cambiar de idioma desde Opciones el menú se rearma
	# y quedaba dibujado sobre el panel: título y botones atravesando la lista de opciones).
	for n: Variant in [_turns, _tut_menu, _credits, _options, _manual]:
		if n != null and is_instance_valid(n) and (n as Node).get_parent() == self and not (n as Node).is_queued_for_deletion():
			move_child(n as Node, get_child_count() - 1)
	if intro != null and is_instance_valid(intro):
		move_child(intro, get_child_count() - 1)
	_build_home()
	_build_agents()
	_show_screen()


func _show_screen() -> void:
	if _home != null:
		_home.visible = screen == "home"
	if _agents != null:
		_agents.visible = screen == "agents"


## «Jugar» → selección de agente.
func go_agents() -> void:
	screen = "agents"
	_confirm_new = false
	_show_screen()


func go_home() -> void:
	screen = "home"
	_confirm_new = false
	_show_screen()


func _logo(parent: Control, size: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var dot_box := CenterContainer.new()
	dot_box.custom_minimum_size = Vector2(22, size + 6)
	_dot = ColorRect.new()
	_dot.custom_minimum_size = Vector2(16, 16)
	_dot.color = UITheme.RED
	dot_box.add_child(_dot)
	hb.add_child(dot_box)
	var title_full := tr("GAME_TITLE")
	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 0)
	_title = UITheme.label(title_full.left(title_full.length() - 1), size, UITheme.TEXT, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.add_child(_title)
	_title_e = UITheme.label(title_full.right(1), size, UITheme.TEXT, true)
	_title_e.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.add_child(_title_e)
	hb.add_child(word)
	parent.add_child(hb)


func _footer(parent: Control) -> void:
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var foot := UITheme.label("%s  ·  %s" % [Loc.fmt(tr("MENU_VERSION"), {"ver": ver}), tr("CREDITS_GODOT")], 12, UITheme.DIM, true)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(foot)


# --- menú principal ------------------------------------------------------------------------------

func _build_home() -> void:
	_home = VBoxContainer.new()
	_home.name = "MenuPrincipal"
	_home.custom_minimum_size = Vector2(620, 0)
	_home.add_theme_constant_override("separation", 12)
	_root.add_child(_home)
	UITheme.center_fit(_home, true, false, 150.0)
	_logo(_home, 64)
	var sub := UITheme.label(tr("GAME_SUBTITLE"), 16, UITheme.DIM, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	_home.add_child(gap)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_home.add_child(col)
	var play := _big_button(tr("Q4_MENU_PLAY"), go_agents)
	play.name = "PlayBtn"
	play.add_theme_font_size_override("font_size", 26)
	col.add_child(play)
	var has_tut := ResourceLoader.exists(TUTORIAL_SCRIPT)
	var tut := _big_button(tr("MENU_TUTORIAL") if has_tut else tr("MENU_TUTORIAL_SOON"), _open_tutorial_menu)
	tut.name = "TutorialBtn"
	tut.disabled = not has_tut
	col.add_child(tut)
	var op := _big_button(tr("MENU_OPTIONS"), _open_options)
	op.name = "OptionsBtn"
	col.add_child(op)
	var man := _big_button(tr("Q4_MENU_MANUAL"), _open_manual)
	man.name = "ManualBtn"
	col.add_child(man)
	var cr := _big_button(tr("MENU_CREDITS"), _open_credits)
	cr.name = "CreditsBtn"
	col.add_child(cr)
	var q := _big_button(tr("Q4_MENU_QUIT"), func() -> void: AudioManager.quit_game())
	q.name = "QuitBtn"
	col.add_child(q)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 16)
	_home.add_child(gap2)
	_status = UITheme.label("", 12, UITheme.DIM, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_home.add_child(_status)
	_footer(_home)


func _big_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb)
	b.custom_minimum_size = Vector2(620, 54)
	b.add_theme_font_size_override("font_size", 21)
	return b


# --- selección de agente -------------------------------------------------------------------------

func _build_agents() -> void:
	var agent_now := GameState.AGENTS[agent_index]
	_agents = VBoxContainer.new()
	_agents.name = "SeleccionAgente"
	_agents.custom_minimum_size = Vector2(1780, 0)
	_agents.add_theme_constant_override("separation", 14)
	_root.add_child(_agents)
	UITheme.center_fit(_agents, true, false, 70.0)
	_logo(_agents, 34)
	var head := UITheme.label(tr("Q4_AGENTS_TITLE"), 22, UITheme.TEXT, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_agents.add_child(head)
	var hint := UITheme.label(tr("Q4_AGENTS_HINT"), 13, UITheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_agents.add_child(hint)
	var row := HBoxContainer.new()
	row.name = "Agentes"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_agents.add_child(row)
	row.add_child(_agent_card(0))
	row.add_child(_lore_companions_panel())
	# Ajustes del agente elegido: modo y dificultad (como antes en la ventana de login).
	var cfg := UITheme.window(Loc.fmt(tr("Q4_AGENT_SETTINGS"), {"agente": agent_now}), Vector2(1100, 0))
	cfg.name = "AjustesAgente"
	cfg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_agents.add_child(cfg)
	var vb := UITheme.vb_of(cfg)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	vb.add_child(line)
	line.add_child(_field_label(tr("MENU_MODE")))
	var mode_btn := UITheme.button(tr("MENU_MODE_NORMAL") if mode == GameState.Mode.NORMAL else tr("MENU_MODE_REAL"), _toggle_mode)
	mode_btn.name = "ModeBtn"
	mode_btn.custom_minimum_size = Vector2(200, 0)
	line.add_child(mode_btn)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(30, 0)
	line.add_child(sp)
	line.add_child(_field_label(tr("MENU_DIFFICULTY")))
	var real := mode == GameState.Mode.REAL
	var lvl := Difficulty.Level.DIFICIL if real else Difficulty.level
	var dlbl := UITheme.label(Difficulty.display_name(lvl), 18, UITheme.TEXT, true)
	dlbl.name = "DiffLbl"
	dlbl.custom_minimum_size = Vector2(110, 0)
	dlbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var dprev := UITheme.button("<", _cycle_difficulty.bind(-1))
	var dnext := UITheme.button(">", _cycle_difficulty.bind(1))
	dprev.disabled = real
	dnext.disabled = real
	line.add_child(dlbl)
	line.add_child(dprev)
	line.add_child(dnext)
	var desc := UITheme.label("%s  %s" % [tr("MENU_MODE_NORMAL_DESC") if mode == GameState.Mode.NORMAL else tr("MENU_MODE_REAL_DESC"), tr("DIFF_REAL_LOCKED") if real else tr(Difficulty.NAME_KEYS[lvl] + "_DESC")], 12, UITheme.DIM)
	desc.name = "ModeDesc"
	desc.custom_minimum_size = Vector2(1060, 0)
	vb.add_child(desc)
	if GameState.DEV_TOOLS_ENABLED:
		var dev_box := UITheme.window("[DEV TESTER] Elegir cualquier turno directamente (Desactivar antes de Steam)", Vector2(1100, 0))
		dev_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_agents.add_child(dev_box)
		var drow := HBoxContainer.new()
		drow.alignment = BoxContainer.ALIGNMENT_CENTER
		drow.add_theme_constant_override("separation", 8)
		UITheme.vb_of(dev_box).add_child(drow)
		var dlabels := ["T0 Training", "T1 Lunes", "T2 Martes", "T3 Miércoles", "T4 Jueves", "T5 Viernes (Shero)", "T6 Sábado (GRASA)", "T7 Domingo (Finales)"]
		for ti in dlabels.size():
			var b := UITheme.button(dlabels[ti], func() -> void:
				if ti == 0:
					first_training_requested.emit("Jiroshi", mode)
				else:
					start_requested.emit("Jiroshi", mode, ti))
			drow.add_child(b)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	_agents.add_child(bottom)
	var back := UITheme.button(tr("Q4_MENU_BACK"), go_home)
	back.name = "BackBtn"
	back.custom_minimum_size = Vector2(240, 44)
	bottom.add_child(back)
	if _notice != "":
		var nl := UITheme.label(_notice, 13, UITheme.YELLOW, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_agents.add_child(nl)
		_notice = ""
	_footer(_agents)


func _agent_card(i: int) -> Control:
	var agent := GameState.AGENTS[i]
	var sel := i == agent_index
	var card := PanelContainer.new()
	card.name = "Agente_" + agent
	card.custom_minimum_size = Vector2(336, 430)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.11) if not sel else Color(0.09, 0.13, 0.16)
	sb.border_color = UITheme.EZLAK if sel else UITheme.BORDER.darkened(0.3)
	sb.set_border_width_all(3 if sel else 1)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select_agent(i))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var face := TextureRect.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(0, 150)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture = Faces.texture(Faces.agent_slug(agent))
	face.modulate = FACE_COLORS.get(agent, Color.WHITE).lerp(Color.WHITE, 0.85 if sel else 0.55)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(face)
	var nm := UITheme.label(agent.to_lower() + "@kipupay", 18, UITheme.TEXT if sel else UITheme.DIM, true)
	nm.name = "AgentName" if sel else "AgentName_" + agent
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(nm)
	var exists := SaveSlots.exists(agent)
	var sum := UITheme.label(SaveSlots.summary_text(agent), 13, UITheme.EZLAK if exists else UITheme.DIM, true)
	sum.name = "SlotLbl" if sel else "SlotLbl_" + agent
	sum.custom_minimum_size = Vector2(300, 54)
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sum)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var sfx := "" if sel else "_" + agent
	if not exists:
		var st := UITheme.button(tr("Q4_AGENT_START"), _act.bind(i, "start"))
		st.name = "StartBtn" + sfx
		if ResourceLoader.exists(TUTORIAL_SCRIPT):  # v0.3.2: dejó su Training a medias → el botón dice por dónde sigue
			var done: Dictionary = (load(TUTORIAL_SCRIPT) as GDScript).call("first_state", agent).get("modulos", {})
			if not done.is_empty():
				st.text = Loc.fmt(tr("TS_TRAINING_RESUME"), {"n": mini(done.size() + 1, 14), "total": 14})
		vb.add_child(st)
	else:
		var has_cp := SaveSlots.has_checkpoint(agent)
		var nxt := int(SaveSlots.progress(agent).get("turno_desbloqueado", 1)) if not sel else GameState.next_turno()
		var cont := UITheme.button(tr("MENU_CONTINUE") if has_cp else Loc.fmt(tr("MENU_CONTINUE_NEXT"), {"n": nxt, "dia": Days.day_name(nxt)}), _act.bind(i, "continue"))
		cont.name = "ContinueBtn" + sfx
		vb.add_child(cont)
	var pick := UITheme.button(tr("MENU_PICK_TURN"), _act.bind(i, "turns"))
	pick.name = "PickTurnBtn" + sfx
	pick.disabled = not exists or SaveSlots.choosable_turns(agent).is_empty()
	if not SaveSlots.pending_branch(agent).is_empty():
		pick.text = tr("MENU_PICK_TURN_BRANCH")
		pick.disabled = false
	vb.add_child(pick)
	var confirm := _confirm_new and sel
	var newg := UITheme.button(Loc.fmt(tr("MENU_NEW_GAME_CONFIRM"), {"agente": agent}) if confirm else tr("MENU_NEW_GAME"), _act.bind(i, "new"))
	newg.name = "NewGameBtn" + sfx
	newg.disabled = not exists
	if confirm:
		newg.add_theme_color_override("font_color", UITheme.YELLOW)
		newg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(newg)
	return card


func _select_agent(i: int) -> void:
	if i != 0 or i == agent_index:
		return
	agent_index = 0
	SaveSlots.select(GameState.AGENTS[agent_index])
	mode = int(SaveSlots.progress().get("mode", GameState.Mode.NORMAL))
	_confirm_new = false
	_build()


## Botón de una tarjeta: primero elige a ese agente (su partida) y luego hace la acción.
func _act(i: int, what: String) -> void:
	if i != agent_index:
		_select_agent(i)
	match what:
		"start": _on_start()
		"continue": _on_continue()
		"turns": _open_turns()
		"new": _on_new_game()


func _field_label(text: String) -> Label:
	var l := UITheme.label(text + ":", 14, UITheme.DIM, true)
	l.custom_minimum_size = Vector2(110, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## Cambiar de agente = cambiar de partida (pruebas y teclado).
func _cycle_agent(dir: int) -> void:
	_select_agent((agent_index + dir + GameState.AGENTS.size()) % GameState.AGENTS.size())


func _cycle_difficulty(dir: int) -> void:
	if mode == GameState.Mode.REAL:
		return
	SaveSlots.set_difficulty(clampi(Difficulty.level + dir, Difficulty.Level.FACIL, Difficulty.Level.DIFICIL))
	_build()


## Nueva partida: primera pulsación pide confirmar, la segunda borra la partida del agente.
func _on_new_game() -> void:
	var agent := GameState.AGENTS[agent_index]
	if not _confirm_new:
		_confirm_new = true
		_build()
		return
	_confirm_new = false
	SaveSlots.new(agent)
	_notice = Loc.fmt(tr("MENU_NEW_GAME_DONE"), {"agente": agent})
	_build()


func _toggle_mode() -> void:
	mode = GameState.Mode.REAL if mode == GameState.Mode.NORMAL else GameState.Mode.NORMAL
	_build()


func _open_options() -> void:
	if _options != null:
		return
	_options = OptionsMenu.new()
	_options.closed.connect(func() -> void: _options.queue_free(); _options = null)
	_options.language_changed.connect(_build)
	add_child(_options)


func _open_manual() -> void:
	if _manual != null:
		return
	_manual = AgentManual.new()
	_manual.closed.connect(func() -> void:
		_manual.queue_free()
		_manual = null
		GameState.flags.erase("manual_abierto"))
	add_child(_manual)


## Al volver al menú no queda abierto ningún panel encima (Elegir turno, Inducción, Créditos, Opciones, Manual) y
## se vuelve al menú principal.
func close_subpanels() -> void:
	for n in [_turns, _tut_menu, _credits, _options, _manual]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_turns = null
	_tut_menu = null
	_credits = null
	_options = null
	_manual = null
	screen = "home"


func _open_credits() -> void:
	if _credits != null:
		return
	_credits = CreditsScreen.new()
	_credits.closed.connect(func() -> void: _credits.queue_free(); _credits = null)
	add_child(_credits)


func _on_start() -> void:
	_confirm_new = false
	var agent := GameState.AGENTS[agent_index]
	if SaveSlots.needs_training(agent) and ResourceLoader.exists(TUTORIAL_SCRIPT) and get_signal_connection_list("first_training_requested").size() > 0:
		first_training_requested.emit(agent, mode)  # v0.3.2: la partida nueva empieza por el Training
		return
	_remember_choice()
	start_requested.emit(agent, mode, 1)


func _on_continue() -> void:
	_remember_choice()
	continue_requested.emit()


## Modo y dificultad elegidos quedan en la partida.
func _remember_choice() -> void:
	var p := SaveSlots.progress()
	p["mode"] = mode
	p["dificultad"] = Difficulty.IDS[Difficulty.level]


# --- Elegir turno (P6b) -----------------------------------------------------------------------------

func _open_turns() -> void:
	if _turns != null:
		return
	_turns = TurnSelect.new()
	_turns.agent = GameState.AGENTS[agent_index]
	_turns.mode = mode
	_turns.level = Difficulty.level
	_turns.closed.connect(_close_turns)
	_turns.turn_chosen.connect(func(n: int) -> void:
		_close_turns()
		_remember_choice()
		branch_requested.emit(n, mode))
	_turns.continue_chosen.connect(func() -> void:
		_close_turns()
		_on_continue())
	_turns.branch_resume.connect(func() -> void:
		_close_turns()
		branch_resume_requested.emit())
	_turns.branch_discard.connect(func() -> void:
		SaveSlots.end_branch(false)
		_notice = tr("TS_DISCARDED")
		_close_turns())
	add_child(_turns)


func _close_turns() -> void:
	if _turns != null:
		_turns.queue_free()
		_turns = null
	_build()


# --- Inducción (P6b) ---------------------------------------------------------------------------------

func _open_tutorial_menu() -> void:
	if _tut_menu != null or not ResourceLoader.exists(TUTORIAL_MENU_SCRIPT):
		return
	_tut_menu = (load(TUTORIAL_MENU_SCRIPT) as GDScript).new() as Control
	_tut_menu.connect("closed", func() -> void:
		_tut_menu.queue_free()
		_tut_menu = null)
	_tut_menu.connect("start_modules", func(mods: Array) -> void:
		_tut_menu.queue_free()
		_tut_menu = null
		tutorial_requested.emit(mods))
	add_child(_tut_menu)


func _lore_companions_panel() -> Control:
	var box := PanelContainer.new()
	box.name = "CompanerosPromocion"
	box.custom_minimum_size = Vector2(680, 430)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.07, 0.09)
	sb.border_color = UITheme.BORDER.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)

	# [CAMBIO v2 - Gemini]: usar TranslationServer en lugar de Loc.lang (que no existe en loc.gd)
	var is_en: bool = TranslationServer.get_locale().begins_with("en")
	# [CAMBIO v2 - Gemini]: lectura segura tanto si "finales" es Array como Dictionary
	var raw_endings: Variant = SaveSlots.progress("Jiroshi").get("finales", [])
	var endings_count: int = mini(raw_endings.size(), 5) if (raw_endings is Array or raw_endings is Dictionary) else 0

	var end_lbl := UITheme.label(
		("Jiroshi — Endings unlocked: %d / 5" if is_en else "Jiroshi — Finales desbloqueados: %d / 5") % endings_count,
		16, UITheme.EZLAK, true
	)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_lbl)
	var title := UITheme.label(
		"CLASSMATES & COWORKERS · WAVE OCT 24, 2025 (STORY / NON-PLAYABLE)" if is_en else "COMPAÑEROS DE PROMOCIÓN · OLA 24 OCT 2025 (HISTORIA / NO JUGABLES)",
		13, UITheme.DIM, true
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	var roles := {
		"Marko": "C-15 · El que busca atajos" if not is_en else "C-15 · Shortcut seeker",
		"Llauri": "C-12 · La que anota todo" if not is_en else "C-12 · Keeps every receipt",
		"Ttoom": "C-16 · Cuenta los 147 paneles" if not is_en else "C-16 · Counts 147 ceiling tiles",
		"Juan": "C-11 · Siempre con sueño" if not is_en else "C-11 · Always exhausted",
	}
	for comp in ["Marko", "Llauri", "Ttoom", "Juan"]:
		var item := PanelContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var isb := StyleBoxFlat.new()
		isb.bg_color = Color(0.075, 0.095, 0.12)
		isb.set_content_margin_all(8)
		item.add_theme_stylebox_override("panel", isb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		item.add_child(hb)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(64, 64)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = Faces.texture(Faces.agent_slug(comp))
		hb.add_child(pic)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_child(info)
		info.add_child(UITheme.label(comp + " (" + comp.to_lower() + "@kipupay)", 14, UITheme.TEXT, true))
		info.add_child(UITheme.label(str(roles.get(comp, "")), 12, UITheme.DIM))
		grid.add_child(item)
	return box

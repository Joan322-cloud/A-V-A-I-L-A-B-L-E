class_name OptionsMenu
extends Control
## Opciones (GDD 9.3) en una ventana "Configuración de Fonex": idioma, modo, sensibilidad, FOV,
## balanceo, subtítulos, grano, sin parpadeos, aviso de screamers, tiempo extra de Ack, HUD de ayuda,
## volúmenes por bus y remapeo de teclado/mando (pulsa una tecla o botón). Guarda en settings.json.

signal closed()
signal language_changed()

var _panel: PanelContainer = null
var _waiting_action: String = ""
var _waiting_joy: bool = false
var _rebind_labels: Dictionary = {}  # accion -> [Label teclado, Label mando]
var _hint: Label = null


## v0.3.2-core: tamaño mínimo de la ventana en escritorio. 1280×720 (por debajo el viewport lógico se encoge: eso es
## para el navegador)… salvo que la pantalla sea más chica: en un portátil de 1366×768 una ventana de 720 de alto más
## su barra de título no cabe encima de la barra de tareas, y con un mínimo fijo no se podría ni maximizar bien. Ahí
## el mínimo es lo que cabe (nunca menos de 960×540).
static func min_window_size() -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var deco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	return fit_min_window(usable, deco)


## v0.3.2-core: pantalla completa sin bordes (a la resolución de la pantalla) o ventana. Al volver a ventana, si la
## ventana con su barra de título no cabe en la pantalla, se encoge a lo que cabe y se centra.
static func apply_fullscreen(on: bool) -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if on:
		return
	DisplayServer.window_set_min_size(min_window_size())
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := DisplayServer.window_get_size()
	var deco := DisplayServer.window_get_size_with_decorations() - size
	var fit := windowed_fit(size, usable.size, deco)
	if fit != size:
		DisplayServer.window_set_size(fit)
		var border := maxi(deco.x, 0) / 2
		DisplayServer.window_set_position(usable.position + (usable.size - fit - deco) / 2 + Vector2i(border, maxi(deco.y, 0) - border))


## Tamaño de la ventana (área de juego) que cabe en la pantalla con su marco; el mismo si ya cabe.
static func windowed_fit(size: Vector2i, usable: Vector2i, deco: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return size
	return Vector2i(mini(size.x, usable.x - maxi(deco.x, 0)), mini(size.y, usable.y - maxi(deco.y, 0)))


static func fit_min_window(usable: Vector2i, deco: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return Vector2i(1280, 720)  # sin pantalla (headless): el de siempre
	return Vector2i(clampi(usable.x - maxi(deco.x, 0), 960, 1280), clampi(usable.y - maxi(deco.y, 0), 540, 720))


var _fullscreen_cb: BaseButton = null


func _on_setting_changed(k: String) -> void:
	if k == "fullscreen" and is_instance_valid(_fullscreen_cb):
		_fullscreen_cb.set_pressed_no_signal(bool(Loc.get_setting("fullscreen", false)))


func _ready() -> void:
	EventBus.settings_changed.connect(_on_setting_changed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.55)
	add_child(bg)
	_build()


func _build() -> void:
	if _panel != null:
		_panel.queue_free()
	_rebind_labels.clear()
	_panel = UITheme.panel(tr("OPT_TITLE"), Vector2(1180, 0))
	add_child(_panel)
	UITheme.center_fit(_panel)  # centrado y, si la ventana es estrecha, escalado para que quepa entero
	var vb := UITheme.vb_of(_panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(540, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(560, 0)
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	# --- Izquierda: juego, gráficos, sonido ---
	left.add_child(UITheme.label(tr("OPT_GROUP_GAME"), 13, UITheme.EZLAK))
	var lang := UITheme.button(tr("MENU_LANGUAGE"), func() -> void: Loc.toggle_language(); language_changed.emit(); _build())
	left.add_child(lang)
	_slider(left, "OPT_SENSITIVITY", "sensitivity", 0.3, 2.5, 0.05, 1.0, "%.2f")
	_slider(left, "OPT_FOV", "fov", float(DataLoader.bal("jugador/fov_min", 65.0)), float(DataLoader.bal("jugador/fov_max", 90.0)), 1.0, 75.0, "%d")
	_slider(left, "OPT_HEADBOB", "headbob", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	for key in ["subtitles", "help_hud", "ack_extra", "emoji_texto"]:  # v0.3.2-core: «Emojis como texto» (accesibilidad)
		_check(left, key)
	_shift_length_row(left)  # v0.3.1 Q1 (C14): única fila de Q1 en este archivo
	_ia_calls_row(left)  # v0.3.2 IA: responder llamadas con predefinidas o micrófono
	left.add_child(UITheme.label(tr("OPT_GROUP_GFX"), 13, UITheme.EZLAK))
	_quality_row(left)
	GfxOptions.add_row(left, self)  # v0.3.2 gfx: «Gráficos avanzados…» (única fila del paquete en este archivo)
	for key in ["grain", "flash_reduction", "screamer_warn", "fullscreen"]:
		_check(left, key)
	_graphic_row(left)  # v0.3.2 (paquete de muertes): «Contenido gráfico: Normal / Reducido»
	left.add_child(UITheme.label(tr("OPT_GROUP_SOUND"), 13, UITheme.EZLAK))
	for pair in [["OPT_VOL_MASTER", "vol_master"], ["OPT_VOL_AURICULAR", "vol_auricular"], ["OPT_VOL_SALA", "vol_sala"], ["OPT_VOL_AMBIENTE", "vol_ambiente"], ["OPT_VOL_UI", "vol_ui"]]:
		_slider(left, pair[0], pair[1], 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	# --- Derecha: controles ---
	right.add_child(UITheme.label(tr("OPT_GROUP_CONTROLS"), 13, UITheme.EZLAK))
	var head := HBoxContainer.new()
	var h1 := UITheme.label(tr("OPT_ACTION"), 12, UITheme.DIM)
	h1.custom_minimum_size = Vector2(200, 0)
	var h2 := UITheme.label(tr("OPT_KEYBOARD"), 12, UITheme.DIM)
	h2.custom_minimum_size = Vector2(170, 0)
	var h3 := UITheme.label(tr("OPT_GAMEPAD"), 12, UITheme.DIM)
	h3.custom_minimum_size = Vector2(170, 0)
	head.add_child(h1)
	head.add_child(h2)
	head.add_child(h3)
	right.add_child(head)
	for a in Controls.ACTIONS:
		var row := HBoxContainer.new()
		var name_l := UITheme.label(tr("CTRL_" + a.to_upper()), 13)
		name_l.custom_minimum_size = Vector2(200, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(name_l)
		var kb := Button.new()
		kb.text = Controls.describe(a, false)
		kb.custom_minimum_size = Vector2(170, 24)
		kb.add_theme_font_size_override("font_size", 12)
		kb.pressed.connect(_start_rebind.bind(a, false))
		row.add_child(kb)
		var jb := Button.new()
		jb.text = Controls.describe(a, true)
		jb.custom_minimum_size = Vector2(170, 24)
		jb.add_theme_font_size_override("font_size", 12)
		jb.pressed.connect(_start_rebind.bind(a, true))
		row.add_child(jb)
		_rebind_labels[a] = [kb, jb]
		right.add_child(row)
	_hint = UITheme.label(tr("OPT_REBIND_HINT"), 12, UITheme.DIM)
	right.add_child(_hint)
	var reset := UITheme.button(tr("OPT_RESET_CONTROLS"), func() -> void: Controls.reset_all(); _build())
	right.add_child(reset)
	vb.add_child(HSeparator.new())
	var back := UITheme.button(tr("OPT_BACK"), func() -> void: closed.emit())
	vb.add_child(back)


## Calidad: Modo liviano / Baja / Media / Alta (GfxQuality). Un botón que va rotando; se guarda en settings.json.
## v0.3.1 Q5: elegirla a mano apaga el cambio automático a liviano; casilla "Modo liviano automático (web)".
func _quality_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(tr("OPT_QUALITY"), 14)
	l.custom_minimum_size = Vector2(230, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 0)
	b.text = tr(GfxQuality.label_key(GfxQuality.level()))
	b.pressed.connect(func() -> void:
		var lv := GfxQuality.next(GfxQuality.level())
		Loc.set_setting("quality", lv)
		Loc.set_setting("quality_user", true)
		GfxQuality.apply(get_tree(), lv)
		b.text = tr(GfxQuality.label_key(lv))
		EventBus.settings_changed.emit("quality"))
	row.add_child(b)
	var auto := CheckBox.new()
	auto.name = "ModoLivianoAuto"
	auto.text = tr("OPT_QUALITY_AUTO")
	auto.add_theme_font_size_override("font_size", 12)
	auto.button_pressed = bool(Loc.get_setting("quality_auto", true))
	auto.toggled.connect(func(v: bool) -> void:
		Loc.set_setting("quality_auto", v)
		if v:
			Loc.set_setting("quality_user", false))
	parent.add_child.call_deferred(auto)  # debajo de la fila y su ayuda
	var hint := UITheme.label(tr("OPT_QUALITY_HINT_Q5"), 11, UITheme.DIM)
	hint.custom_minimum_size = Vector2(500, 0)
	parent.add_child(row)
	parent.add_child(hint)


## v0.3.2 (muertes): «Contenido gráfico» Normal / Reducido (setting "contenido_grafico", por defecto Normal).
## Reducido quita sangre, heridas y crujidos de hueso de las muertes (KillGore.enabled); el susto queda.
func _graphic_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.name = "FilaContenidoGrafico"
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(tr("OPT_CONTENIDO_GRAFICO"), 14)
	l.custom_minimum_size = Vector2(230, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var b := Button.new()
	b.name = "BotonContenidoGrafico"
	b.custom_minimum_size = Vector2(220, 0)
	var cur := func() -> String: return "reducido" if str(Loc.get_setting(KillGore.SETTING, "normal")) == "reducido" else "normal"
	b.text = tr("OPT_CONTENIDO_" + str(cur.call()).to_upper())
	b.pressed.connect(func() -> void:
		var nxt := "normal" if str(cur.call()) == "reducido" else "reducido"
		Loc.set_setting(KillGore.SETTING, nxt)
		b.text = tr("OPT_CONTENIDO_" + nxt.to_upper())
		EventBus.settings_changed.emit(KillGore.SETTING))
	row.add_child(b)
	var hint := UITheme.label(tr("OPT_CONTENIDO_HINT"), 11, UITheme.DIM)
	hint.custom_minimum_size = Vector2(500, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(row)
	parent.add_child(hint)


## v0.3.1 Q1 (D3/F21, contrato C14): «Duración del turno» Corta / Normal / Larga, por agente (SaveSlots,
## progreso.json/duracion_turno). Solo acelera los relojes libres (espera sin cola, llegada, break y lunch dentro
## del cupo); los plazos en minutos de juego no cambian. Vale desde el próximo turno (o el checkpoint).
func _shift_length_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.name = "FilaDuracionTurno"
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(Loc.fmt(tr("Q1_OPT_SHIFT_LENGTH"), {"agente": SaveSlots.current}), 14)
	l.custom_minimum_size = Vector2(230, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var b := Button.new()
	b.name = "BotonDuracionTurno"
	b.custom_minimum_size = Vector2(220, 0)
	b.text = tr("Q1_SHIFT_" + SaveSlots.shift_length().to_upper())
	b.pressed.connect(func() -> void:
		var ids := SaveSlots.SHIFT_LENGTHS
		var nxt: String = ids[(ids.find(SaveSlots.shift_length()) + 1) % ids.size()]
		SaveSlots.set_shift_length(nxt)
		b.text = tr("Q1_SHIFT_" + nxt.to_upper()))
	row.add_child(b)
	var hint := UITheme.label(tr("Q1_OPT_SHIFT_LENGTH_HINT"), 11, UITheme.DIM)
	hint.custom_minimum_size = Vector2(500, 0)
	parent.add_child(row)
	parent.add_child(hint)


## v0.3.2 IA: «Responder llamadas: Respuestas predefinidas / Micrófono» (settings «ia_llamadas»). En el navegador el
## micrófono usa la voz del navegador (Chrome manda el audio a Google): hace falta marcar el permiso aquí.
func _ia_calls_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.name = "FilaResponderLlamadas"
	row.add_theme_constant_override("separation", 10)
	var l := UITheme.label(tr("IA_OPT_CALLS"), 14)
	l.custom_minimum_size = Vector2(230, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var b := Button.new()
	b.name = "BotonResponderLlamadas"
	b.custom_minimum_size = Vector2(220, 0)
	var label_of := func(v: String) -> String: return tr("IA_OPT_CALLS_MIC") if v == "microfono" else tr("IA_OPT_CALLS_PRESETS")
	b.text = label_of.call(str(Loc.get_setting("ia_llamadas", "predefinidas")))
	b.pressed.connect(func() -> void:
		var nxt := "predefinidas" if str(Loc.get_setting("ia_llamadas", "predefinidas")) == "microfono" else "microfono"
		Loc.set_setting("ia_llamadas", nxt)
		b.text = label_of.call(nxt)
		EventBus.settings_changed.emit("ia_llamadas"))
	row.add_child(b)
	parent.add_child(row)
	var hint := UITheme.label(tr("IA_OPT_CALLS_HINT"), 11, UITheme.DIM)
	hint.custom_minimum_size = Vector2(500, 0)
	parent.add_child(hint)
	if IASpeech.language_mismatch():
		# v0.3.2-core: en inglés, el motor de voz sin conexión solo entiende español; se dice aquí, donde se elige.
		var es_only := UITheme.label(tr("IA_MIC_ES_ONLY"), 11, UITheme.YELLOW)
		es_only.name = "AvisoVozSoloEspanol"
		es_only.custom_minimum_size = Vector2(500, 0)
		parent.add_child(es_only)
	if OS.has_feature("web"):
		var web := UITheme.label(tr("IA_OPT_WEB_NOTICE"), 11, UITheme.DIM)
		web.custom_minimum_size = Vector2(500, 0)
		parent.add_child(web)
		var cb := CheckBox.new()
		cb.name = "PermisoVozNavegador"
		cb.text = tr("IA_OPT_WEB_ACCEPT")
		cb.add_theme_font_size_override("font_size", 12)
		cb.button_pressed = bool(Loc.get_setting("ia_voz_web_ok", false))
		cb.toggled.connect(func(v: bool) -> void:
			Loc.set_setting("ia_voz_web_ok", v)
			EventBus.settings_changed.emit("ia_voz_web_ok"))
		parent.add_child(cb)


func _check(parent: Node, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = tr("OPT_" + key.to_upper())
	cb.add_theme_font_size_override("font_size", 14)
	cb.button_pressed = bool(Loc.get_setting(key, key in ["subtitles", "grain"]))
	cb.toggled.connect(func(v: bool) -> void:
		Loc.set_setting(key, v)
		if key == "fullscreen":
			apply_fullscreen(v))
	if key == "fullscreen":
		_fullscreen_cb = cb  # Alt+Intro con las Opciones abiertas: la casilla lo refleja (_on_setting_changed)
	parent.add_child(cb)


func _slider(parent: Node, key: String, setting: String, lo: float, hi: float, step: float, def: float, fmt: String, mult: float = 1.0) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(tr(key), 14)
	l.custom_minimum_size = Vector2(230, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Loc.get_setting(setting, def))
	s.custom_minimum_size = Vector2(220, 0)
	row.add_child(s)
	var v := UITheme.label(fmt % (int(s.value * mult) if fmt.contains("d") else s.value * mult), 13, UITheme.DIM)
	v.custom_minimum_size = Vector2(60, 0)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(v)
	s.value_changed.connect(func(val: float) -> void:
		Loc.set_setting(setting, val)
		v.text = fmt % (int(val * mult) if fmt.contains("d") else val * mult)
		if setting.begins_with("vol_"):
			AudioManager.apply_volumes()
		EventBus.settings_changed.emit(setting))
	parent.add_child(row)


func _start_rebind(action: String, joy: bool) -> void:
	_waiting_action = action
	_waiting_joy = joy
	_hint.text = tr("OPT_REBIND_WAIT")
	_hint.add_theme_color_override("font_color", UITheme.YELLOW)


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not visible:
		return
	var ok := false
	if not _waiting_joy and event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_waiting_action = ""
			_hint.text = tr("OPT_REBIND_HINT")
			_hint.add_theme_color_override("font_color", UITheme.DIM)
			get_viewport().set_input_as_handled()
			return
		ok = true
	elif _waiting_joy and event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		ok = true
	elif _waiting_joy and event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.7:
		var m := (event as InputEventJoypadMotion).duplicate() as InputEventJoypadMotion
		m.axis_value = signf(m.axis_value)
		event = m
		ok = true
	if not ok:
		return
	Controls.rebind(_waiting_action, event)
	var labels: Array = _rebind_labels.get(_waiting_action, [])
	if labels.size() == 2:
		(labels[0] as Button).text = Controls.describe(_waiting_action, false)
		(labels[1] as Button).text = Controls.describe(_waiting_action, true)
	_waiting_action = ""
	_hint.text = tr("OPT_REBIND_HINT")
	_hint.add_theme_color_override("font_color", UITheme.DIM)
	get_viewport().set_input_as_handled()

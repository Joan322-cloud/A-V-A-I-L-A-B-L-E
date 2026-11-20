extends Control
## HUD mínimo (GDD 8.3): reloj, AUX + cronómetro, métricas sutiles por color (icono + texto),
## "Cliente en espera", pista de interacción, mensajes, subtítulos. La Fatiga NUNCA se muestra
## como barra (salvo opción "HUD de ayuda" en Accesibilidad).
## v0.3 P3: "Breaks n/2" y el escalón de Shero discreto ("Shero · break · verbal", "Shero viene", "Shero en tu
## piso"), y el aviso del WW cuando estás lejos de tu PC ("Ack desde cualquier terminal Fonex: 52 s").

var _clock: Label = null
var _aux: Label = null
var _metrics: Label = null
var _hold: Label = null
var _disc: Label = null
var _ack: Label = null
var _hint: Label = null
var _msg: Label = null
var _sub: Label = null
var _help_bar: ProgressBar = null
var _note_box: PanelContainer = null
var _note: Label = null
var _note_left: float = 0.0
var _msg_left: float = 0.0
var _sub_left: float = 0.0
var _hold_on: bool = false

## Gris de la línea de disciplina (un punto más claro que UITheme.DIM: es texto pequeño sobre el piso oscuro).
const SOFT := Color(0.68, 0.73, 0.78)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anclado a los bordes (no posiciones fijas de 1920×1080): vale para cualquier tamaño de ventana.
	_clock = _mk_right(20, 20, UITheme.TEXT)
	_aux = _mk_right(50, 16, UITheme.DIM)
	# v0.3.2-core: a 13 px de diseño las métricas y la disciplina quedaban en ~8,7 px en la ventana de 1280×720 (no se
	# leían en ninguna captura). Suben a 16/15 px y el gris de la disciplina se aclara un punto.
	_metrics = _mk_right(80, 16, UITheme.DIM)
	_disc = _mk_right(108, 15, SOFT)
	_hold = _mk_right(136, 15, UITheme.RED)
	_ack = _mk_center(-260, 20, UITheme.RED)
	_hint = _mk_center(20, 18, UITheme.TEXT)
	_msg = _mk_bottom(-180, 600, 18, UITheme.TEXT)
	_sub = _mk_bottom(-120, 900, 20, UITheme.TEXT)
	# v0.3.2: subtítulos y avisos con borde negro (sobre el escritorio claro no se leían) y por encima de la vista de
	# la PC (su fondo del 35 % los oscurecía: con la PC abierta, que es casi todo el turno, quedaban grises).
	for l: Label in [_sub, _msg]:
		l.z_index = 50
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_help_bar = ProgressBar.new()
	_help_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help_bar.offset_left = 20
	_help_bar.offset_right = 220
	_help_bar.offset_top = -40
	_help_bar.offset_bottom = -28
	_help_bar.custom_minimum_size = Vector2(200, 12)
	_help_bar.max_value = 100.0
	_help_bar.show_percentage = false
	_help_bar.visible = false
	add_child(_help_bar)
	_build_notice()
	add_to_group("tip_blocker")
	EventBus.interact_hint.connect(func(t: String) -> void: _hint.text = t)
	EventBus.show_message.connect(_on_message)
	VoiceDirector.subtitle_shown.connect(_on_subtitle)  # v0.3.2: un subtítulo a la vez, en el orden de las voces
	VoiceDirector.notice_shown.connect(_on_notice)  # v0.3.2-core: avisos de texto (Ezlaki, sistema, líneas que no pudieron sonar)
	EventBus.hold_changed.connect(func(on: bool) -> void: _hold_on = on)
	# v0.2: menú de compra (expendedora / mostrador de Marleny).
	var shop := ShopMenu.new()
	shop.name = "ShopMenu"
	add_child(shop)


## Etiqueta pegada al borde derecho (crece hacia la izquierda) a `y` px del borde superior.
func _mk_right(y: float, size: int, color: Color) -> Label:
	var l := UITheme.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF  # sin ancho mínimo, el autowrap partía por letra
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -20
	l.offset_left = -520
	l.offset_top = y
	l.offset_bottom = y + size + 8
	# rc1 (capturas 1080p): sobre las paredes claras de los pisos v3 la hora y el AUX casi no se leían.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


## Etiqueta centrada en pantalla, desplazada `dy` px del centro.
func _mk_center(dy: float, size: int, color: Color) -> Label:
	var l := UITheme.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.offset_top = dy
	l.offset_bottom = dy + size + 8
	add_child(l)
	return l


## Etiqueta centrada abajo (ancho fijo, autowrap), a `dy` px del borde inferior (negativo).
func _mk_bottom(dy: float, width: float, size: int, color: Color) -> Label:
	var l := UITheme.label("", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = -width * 0.5
	l.offset_right = width * 0.5
	l.offset_top = dy
	l.offset_bottom = dy + size + 10
	add_child(l)
	return l


## v0.3.2-core: aviso de texto arriba al centro (la franja libre sobre los monitores de la PC, entre las pistas de
## la izquierda y el reloj de la derecha). No es un subtítulo de voz: es el resumen de un DM de Ezlaki («@Shero ·
## Shero: Break. Ok.»), un texto del sistema («Llamando a Marko…») o una línea importante que no pudo sonar a tiempo.
## Uno a la vez (los ordena VoiceDirector). Los subtítulos de las voces siguen abajo.
func _build_notice() -> void:
	_note_box = PanelContainer.new()
	_note_box.name = "Aviso"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.86)
	sb.border_color = UITheme.EZLAK
	sb.border_width_left = 4
	sb.set_content_margin_all(8)
	sb.content_margin_left = 12
	sb.set_corner_radius_all(2)
	_note_box.add_theme_stylebox_override("panel", sb)
	_note_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note_box.grow_vertical = Control.GROW_DIRECTION_END
	_note_box.offset_top = 14
	_note_box.offset_bottom = 14
	_note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_box.z_index = 50
	_note_box.visible = false
	_note_box.add_to_group("hud_top_box")  # el REC de Haime (QaRec) no se le pone encima
	add_child(_note_box)
	_note = UITheme.label("", 17, UITheme.TEXT)
	_note.name = "Texto"
	_note.custom_minimum_size = Vector2(780, 0)
	_note.max_lines_visible = 3
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note_box.add_child(_note)


## Con la PC acercada, el aviso de primera vez (AgentTips) va en esta misma franja de arriba al centro: mientras hay
## un aviso a la vista, el de primera vez espera (vuelve a salir entero después). De pie no se pisan (va a la izquierda).
## En ventanas estrechas (el navegador, una ventana pequeña: el viewport lógico baja de 1920 de ancho) tampoco caben
## los dos de pie: el de primera vez ocupa hasta x ≈ 560 y el aviso, centrado, empieza antes.
func blocks_tips() -> bool:
	if _note_box == null or not _note_box.visible:
		return false
	var ws := get_tree().get_first_node_in_group("workstation")
	if ws != null and bool(ws.get("zoomed")):
		return true
	return _note_box.get_global_rect().position.x < TIP_RIGHT


## Borde derecho del aviso de primera vez cuando va arriba a la izquierda (AgentTips: 24 + 500 + márgenes).
const TIP_RIGHT := 556.0


## Ancho del aviso según el viewport lógico: 780 px en 1920; en ventanas estrechas se encoge para no meterse en la
## columna del reloj y las métricas (y se queda en dos líneas: tres llegaban a la altura de las métricas).
func _fit_notice() -> void:
	var vp := get_viewport_rect().size
	# Lo que queda entre el centro y la columna de la derecha (lo más ancho de reloj, AUX y métricas), a los dos lados.
	var col := maxf(_clock.get_minimum_size().x, maxf(_aux.get_minimum_size().x, _metrics.get_minimum_size().x))
	var w := clampf(2.0 * (vp.x * 0.5 - 20.0 - col - 14.0) - 22.0, 300.0, 780.0)
	if not is_equal_approx(_note.custom_minimum_size.x, w):
		_note.custom_minimum_size = Vector2(w, 0)
		_note.max_lines_visible = 3 if w >= 700.0 else 2
		_note_box.reset_size()
		_note_box.offset_left = 0.0
		_note_box.offset_right = 0.0


func _on_notice(speaker: String, text: String, seconds: float, must: bool) -> void:
	# v0.3.2 (feedback de Joan: los pasos del Training tapaban cosas): mientras la guía del Training está a la vista,
	# el aviso sale DENTRO de ella (TrainingCoach escucha notice_shown por su cuenta) y esta franja queda libre.
	for h in get_tree().get_nodes_in_group("hud_notice_host"):
		if h.has_method("host_notice") and bool(h.call("host_notice", speaker, text, seconds, must)):
			_note_box.visible = false
			_note_left = 0.0
			return
	if text == "" or (not must and not bool(Loc.get_setting("subtitles", true))):
		_note_box.visible = false
		_note_left = 0.0
		return
	var col := UITheme.EZLAK if speaker == "ezlak" else (UITheme.YELLOW if must else UITheme.DIM)
	var sb := _note_box.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = col
	_note.add_theme_color_override("font_color", UITheme.TEXT if (must or speaker == "ezlak") else Color(0.8, 0.84, 0.88))
	_fit_notice()
	_note.text = text
	_note_box.visible = true
	_note_box.reset_size()
	_note_box.offset_left = 0.0  # reset_size() fija el borde izquierdo: se vuelve a centrar (crece a los dos lados)
	_note_box.offset_right = 0.0
	_note_left = seconds + 0.6  # el director lo quita a su hora; esto es solo la red de seguridad


func _process(delta: float) -> void:
	if not GameState.running and not GameState.shift_over:
		if _note_box.visible:
			_note_box.visible = false
		return
	if _note_left > 0.0:
		_note_left -= delta / maxf(Engine.time_scale, 0.001)
		if _note_left <= 0.0:
			_note_box.visible = false
	_clock.text = _clock_label()
	if GameState.logged_in:
		_aux.text = "%s  %s%s" % [Metrics.aux_name(), Loc.mmss(Metrics.seconds_in_current_aux()), Discipline.aux_margin_text()]  # v0.3.2-core4: « / 10:00 · margen 3:00 · 1 marca»
		if Metrics.reconnecting:
			_aux.text = Reconexion.hud_text()  # v0.3.2: «Reconectando 4 s · elige un AUX» (+ lo que quedaba de lunch)
		var av := Metrics.available_pct()
		_metrics.text = "AVL %d%%  ·  AHT %s  ·  WW %d/3  ·  %s %d" % [int(av), Loc.mmss(Metrics.aht_seconds()), Metrics.written_warnings, tr("HUD_QUEUE"), GameState.queue_size]
		_metrics.add_theme_color_override("font_color", UITheme.color_for(Metrics.color_of("available")))
	else:
		_aux.text = tr("FONEX_LOGGED_OUT")
		_metrics.text = ""
	_update_discipline()
	_hold.text = Loc.fmt(tr("HUD_CLIENT_WAITING"), {"t": "…"}) if _hold_on and GameState.seated_at == "" else ""
	if _msg_left > 0.0:
		_msg_left -= delta
		if _msg_left <= 0.0:
			_msg.text = ""
	if _sub_left > 0.0:
		_sub_left -= delta / maxf(Engine.time_scale, 0.001)  # v0.3.2: al paso de la voz (que no se acelera con time_scale)
		if _sub_left <= 0.0:
			_sub.text = ""
	_stack_bottom()
	_help_bar.visible = bool(Loc.get_setting("help_hud", false))
	if _help_bar.visible:
		_help_bar.value = Fatigue.value


## El mensaje («Estás en una PC: cambia el AUX ahí.») va siempre ENCIMA del subtítulo: con uno de tres líneas se
## pisaban (los dos crecen hacia arriba desde su borde de abajo).
## v0.3.2-core (visto en las partidas en fotos): con la PC acercada, el mensaje caía ENCIMA del borde de abajo de la
## PC (la barra de apps y la línea de estado de Fonex) en cuanto ocupaba dos renglones («Contacto desconectado: vuelve
## a la cola…»). Acercada, el mensaje va en un solo renglón ancho y debajo del subtítulo, en la franja libre entre el
## subtítulo y la línea de atajos.
const MSG_W := 600.0
const MSG_W_ZOOM := 1400.0
const MSG_BOTTOM_ZOOM := -62.0

func _stack_bottom() -> void:
	var sub_top := -90.0 - (maxf(_sub.size.y, 30.0) if _sub.text != "" else 30.0)
	var ws := get_tree().get_first_node_in_group("workstation") as CanvasItem
	var zoomed := ws != null and ws.visible and bool(ws.get("zoomed"))
	var w := MSG_W_ZOOM if zoomed else MSG_W
	if not is_equal_approx(_msg.offset_right, w * 0.5):
		_msg.offset_left = -w * 0.5
		_msg.offset_right = w * 0.5
	var bottom := MSG_BOTTOM_ZOOM if zoomed else minf(-152.0, sub_top - 4.0)
	if not is_equal_approx(_msg.offset_bottom, bottom):
		_msg.offset_bottom = bottom
		_msg.offset_top = bottom - 28.0


## Indicador discreto de la escalera de Shero y del Ack lejos de la PC (P3).
func _update_discipline() -> void:
	if not GameState.logged_in:
		_disc.text = ""
		_ack.text = ""
		return
	var parts: Array[String] = [Loc.fmt(tr("P3_HUD_BREAKS"), {"n": Metrics.breaks_used, "max": Metrics.breaks_allowed()})]
	var col := SOFT
	if Pursuit.is_hunting("shero"):
		var inf := Pursuit.info("shero")
		parts.append(tr("P3_HUD_HUNT_HERE") if str(inf.get("state", "")) != "llegando" else tr("P3_HUD_HUNT_COMING"))
		col = UITheme.RED
	else:
		var best := ""
		var st := 0
		var pp: Dictionary = Discipline.counters.get("por_pista", {})
		for k in pp.keys():
			if int(pp[k]) > st:
				st = int(pp[k])
				best = str(k)
		if st > 0:
			parts.append(Loc.fmt(tr("P3_HUD_STEP"), {"pista": tr("P3_TRACK_" + best.to_upper()), "escalon": tr("P3_STEP_%d" % clampi(st, 1, 4))}))
			col = UITheme.RED if st >= 3 else UITheme.YELLOW if st == 2 else SOFT
	# v0.3.2: el comodín (llamar a un compañero para que te marque el AUX) y si ya lo usaste.
	parts.append(tr("B2_COMODIN_HUD_USED") if Comodin.used else tr("B2_COMODIN_HUD_FREE"))
	# v0.3.2: en el lunch, que se vea que nadie te puede convocar (y la gracia al volver).
	if Discipline.is_lunch_immune() and not Pursuit.is_hunting("shero"):
		if Metrics.aux == Metrics.Aux.LUNCH:
			parts.append(Loc.fmt(tr("B2_HUD_LUNCH_SAFE"), {"t": Loc.mmss(maxf(GameState.lunch_minutes() * 60.0 - Metrics.seconds_in_current_aux(), 0.0))}))
		else:
			parts.append(Loc.fmt(tr("B2_HUD_LUNCH_GRACE"), {"s": int(ceil(Discipline.lunch_grace_left()))}))
	_disc.text = "  ·  ".join(PackedStringArray(parts))
	_disc.add_theme_color_override("font_color", col)
	var ws := get_tree().get_first_node_in_group("workstation") as Control
	if Metrics.ack_pending and (ws == null or not ws.visible):
		_ack.text = Loc.fmt(tr("B2_HUD_ACK_FAR"), {"s": int(ceil(Metrics.ack_left))})
	else:
		_ack.text = ""
		# v0.3.2 (Joan): como Ezlaki ya no abre chats solo, lo que pide una acción se ve aquí si no estás mirando la PC.
		if ws == null or not ws.visible or not bool(GameState.flags.get("pc_zoom", false)):
			var hub := EzlakHub.get_hub(get_tree())
			var vz := get_tree().get_first_node_in_group("vitzo")
			if hub != null and hub.rooms_pending and hub.rooms_left < 1.0e8:
				_ack.text = "%s  %s" % [tr("P4_NEXT_ROOMS"), Loc.mmss(hub.rooms_left)]
			elif vz != null and bool(vz.call("is_reminder_pending")):
				_ack.text = "%s  %d s" % [tr("P4_NEXT_VITZO"), int(ceil(float(vz.call("seconds_left"))))]


func _on_message(text: String, seconds: float) -> void:
	_msg.text = text
	_msg_left = seconds


func _on_subtitle(speaker: String, text: String, seconds: float) -> void:
	if not bool(Loc.get_setting("subtitles", true)):
		return
	for o in get_tree().get_nodes_in_group("subtitle_owner"):
		if o.has_method("owns_subtitles") and bool(o.call("owns_subtitles")) and speaker in ["haime", "qa"]:
			return  # P7: el feedback de Haime ya muestra su línea en grande (salía dos veces)
	var color := UITheme.TEXT
	match speaker:
		"shero": color = UITheme.DIM
		"ezlak", "sys": color = UITheme.EZLAK
	_sub.add_theme_color_override("font_color", color)
	_sub.text = text
	_sub_left = seconds


## v0.3.2: el día de la semana delante de la hora («LUN 9 NOV · 03:47»); en el Training (el recuerdo) es de día.
var _day_cache: Array = [-99, "", ""]  # turno, idioma, texto


func _clock_label() -> String:
	if int(_day_cache[0]) != GameState.turno or str(_day_cache[1]) != Loc.language:
		_day_cache = [GameState.turno, Loc.language, Days.short(GameState.turno)]
	var t := GameState.clock_text()  # en el recuerdo ya viene desplazado (GameState.clock_shift)
	return "%s · %s" % [str(_day_cache[2]), t] if str(_day_cache[2]) != "" else t

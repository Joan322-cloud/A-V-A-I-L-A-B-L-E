class_name PcDesktop
extends Control
## Escritorio de la pantalla izquierda (PLAN §2 #50): barra superior (agente, isla, reloj, KPI), panel
## "Siguiente paso" (qué hacer ahora, en palabras claras), el área de la app activa y la barra de tareas con
## Kardex · Correo · Identa · Portal Vitzo · Campus (clic o F1-F5) con insignias. Cuando entra un contacto la
## app correcta se abre sola. Todo se usa con el ratón al acercar la vista ([E] sobre el monitor) o con atajos.
## v0.3.1 Q1 (B5/F12): las apps van dentro de un ScrollContainer vertical que NO propaga su alto mínimo: Identa
## (reglas + 6 botones) y Campus (3 minitrainings + 5 guías) ya no empujan la barra F1-F5 fuera de la pantalla.

const APPS: Array[String] = ["kardex", "correo", "identa", "portal", "campus"]

var cm: ContactManager = null
var kardex: PcKardex = null
var correo: PcCorreo = null
var identa: PcIdenta = null
var portal: PcPortal = null
var campus: PcCampus = null
var active_app: String = "kardex"
var _top: Label = null
var _top_kpi: RichTextLabel = null
var _next: RichTextLabel = null
var _area: PanelContainer = null
var _scroll: ScrollContainer = null
var _bg: ColorRect = null
var _vb: VBoxContainer = null
var _task: HBoxContainer = null
var _task_buttons: Dictionary = {}
var _blink: float = 0.0
var _apps: Dictionary = {}


func _init() -> void:
	add_to_group("pc_desktop")
	custom_minimum_size = Vector2(PcStyle.W, PcStyle.H)
	size = Vector2(PcStyle.W, PcStyle.H)
	var bg := ColorRect.new()
	bg.color = PcStyle.BG
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_bg = bg
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size = size
	add_child(vb)
	_vb = vb
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", PcStyle.box(PcStyle.BAR, Color(0, 0, 0, 0), 4.0, 0))
	vb.add_child(top)
	var th := HBoxContainer.new()
	top.add_child(th)
	_top = PcStyle.label("", PcStyle.F_SMALL, PcStyle.TEXT, false)
	th.add_child(_top)
	_top_kpi = RichTextLabel.new()
	_top_kpi.bbcode_enabled = true
	_top_kpi.fit_content = true
	_top_kpi.scroll_active = false
	_top_kpi.autowrap_mode = TextServer.AUTOWRAP_OFF
	_top_kpi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_kpi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_kpi.add_theme_font_size_override("normal_font_size", PcStyle.F_TINY)
	th.add_child(_top_kpi)
	var nextp := PanelContainer.new()
	nextp.add_theme_stylebox_override("panel", PcStyle.box(Color(0.1, 0.12, 0.08), Color(0.35, 0.4, 0.2), 5.0, 0))
	nextp.set_meta("guia", "pc:siguiente")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	vb.add_child(nextp)
	_next = RichTextLabel.new()
	_next.bbcode_enabled = true
	_next.fit_content = true
	_next.scroll_active = false
	_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.add_theme_font_size_override("normal_font_size", PcStyle.F_SMALL)
	_next.add_theme_font_size_override("bold_font_size", PcStyle.F_SMALL)
	nextp.add_child(_next)
	_area = PanelContainer.new()
	_area.add_theme_stylebox_override("panel", PcStyle.box(PcStyle.BG, Color(0, 0, 0, 0), 6.0, 0))
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.clip_contents = true
	vb.add_child(_area)
	_scroll = ScrollContainer.new()
	_scroll.name = "AppScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.add_child(_scroll)
	var apps_box := VBoxContainer.new()
	apps_box.name = "Apps"
	apps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(apps_box)
	kardex = PcKardex.new()
	correo = PcCorreo.new()
	identa = PcIdenta.new()
	portal = PcPortal.new()
	campus = PcCampus.new()
	_apps = {"kardex": kardex, "correo": correo, "identa": identa, "portal": portal, "campus": campus}
	for k in APPS:
		var app: Control = _apps[k]
		app.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app.visible = k == active_app
		apps_box.add_child(app)
	var task := PanelContainer.new()
	task.name = "BarraApps"
	task.add_theme_stylebox_override("panel", PcStyle.box(PcStyle.BAR, Color(0, 0, 0, 0), 3.0, 0))
	vb.add_child(task)
	_task = HBoxContainer.new()
	_task.add_theme_constant_override("separation", 4)
	task.add_child(_task)
	for i in APPS.size():
		var k := APPS[i]
		var b := PcStyle.button("", func() -> void: open_app(k), PcStyle.F_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("guia", "app:" + k)
		_task.add_child(b)
		_task_buttons[k] = b


## F10: la pantalla cambia de alto mientras la vista está acercada (Workstation._set_screen_height).
func resize_to(sz: Vector2) -> void:
	custom_minimum_size = sz
	size = sz
	_bg.size = sz
	_vb.size = sz


## Rect de la barra F1-F5 en coordenadas de la pantalla (prueba barra_apps_siempre).
func taskbar_rect() -> Rect2:
	var t := _vb.get_node_or_null("BarraApps") as Control
	return t.get_rect() if t != null else Rect2()


func bind(p_cm: ContactManager) -> void:
	cm = p_cm
	for k in APPS:
		(_apps[k] as Object).set("cm", cm)
	if cm != null and not cm.app_requested.is_connected(open_app):
		cm.app_requested.connect(open_app)


func open_app(app: String) -> void:
	if not _apps.has(app):
		return
	active_app = app
	for k in APPS:
		(_apps[k] as Control).visible = k == app
	if _scroll != null:
		_scroll.scroll_vertical = 0
	if app == "portal" and portal != null and portal.case_tx() != "" and cm != null and cm.portal_view.is_empty():
		portal._search.text = portal.case_tx()


func refresh(delta: float) -> void:
	_blink += delta
	var seat := GameState.seated_at if GameState.seated_at != "" else "—"
	_top.text = "KipuPay · %s · %s  %s  " % [GameState.agent, seat, GameState.clock_text()]
	_top_kpi.text = "[right]%s[/right]" % PcFonex.kpi_bbcode()
	_next.text = next_step_bbcode()
	var hint := AgentTips.next_step_hint(cm)  # v0.3 P6b: en Fácil, una pista extra debajo del paso
	if hint != "":
		_next.text += "\n[color=#9fb0bb][i]%s %s[/i][/color]" % [tr("TUT_HINT_PREFIX"), hint]
	for k in APPS:
		var b: Button = _task_buttons[k]
		var badge := _badge(k)
		b.text = "F%d %s%s" % [APPS.find(k) + 1, tr("P4_APP_" + k.to_upper()), ("  (%s)" % badge) if badge != "" else ""]
		var col := PcStyle.ACCENT.darkened(0.4) if k == active_app else PcStyle.PANEL_HI
		if badge != "" and k != active_app and fmod(_blink, 1.2) < 0.6:
			col = Color(0.4, 0.25, 0.08)
		b.add_theme_stylebox_override("normal", PcStyle.box(col, PcStyle.BORDER, 4.0))
	var app: Object = _apps.get(active_app)
	if app != null and app.has_method("refresh"):
		app.call("refresh", delta)


func _badge(app: String) -> String:
	if cm == null:
		return ""
	match app:
		"kardex":
			return "!" if cm.tree != null else ""
		"correo":
			if not cm.composer.is_empty():
				return "!"
			return "1" if cm.case != null and not cm.case.is_kyc() else ""
		"identa":
			return "1" if cm.case != null and cm.case.is_kyc() else ""
		"portal":
			if cm.tree != null and cm.tree.pending_action().begins_with("portal"):
				return "!"
		"campus":
			var m := get_tree().get_first_node_in_group("mentor") as Mentor if is_inside_tree() else null
			if m != null and m.minitrainings_pending() > 0:
				return str(m.minitrainings_pending())
	return ""


## Texto del panel "Siguiente paso".
func next_step_bbcode() -> String:
	var red := "#ff6a5a"
	var yel := "#edc245"
	if not GameState.logged_in:
		return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_NEXT_LOGIN")]
	if Metrics.ack_pending:
		return "[color=%s][b]%s[/b] %s  %.1f s[/color]" % [red, tr("P4_NEXT"), tr("P4_NEXT_ACK"), Metrics.ack_left]
	var hub := EzlakHub.get_hub(get_tree()) if is_inside_tree() else null
	if hub != null and not hub.pending_actionable().is_empty():
		var v := get_tree().get_first_node_in_group("vitzo")
		var left := float(v.call("seconds_left")) if v != null else 0.0
		return "[color=%s][b]%s[/b] %s  %ds[/color]" % [red, tr("P4_NEXT"), tr("P4_NEXT_VITZO"), int(left)]
	if hub != null and hub.rooms_pending:
		return "[color=%s][b]%s[/b] %s  %s[/color]" % [red, tr("P4_NEXT"), tr("P4_NEXT_ROOMS"), Loc.mmss(hub.rooms_left)]
	if cm == null:
		return ""
	match cm.phase:
		ContactManager.Phase.OFFERING:
			if ContactManager.is_bo(cm.current):
				return "[color=%s][b]%s[/b] %s[/color]" % [yel, tr("P4_NEXT"), tr("P4_NEXT_CASE_IN")]
			if not cm.player_ready():
				return "[color=%s][b]%s[/b] %s  %ds[/color]" % [red, tr("P4_NEXT"), tr("P4_NEXT_SIT"), int(ceil(cm.ring_left))]
			return "[color=%s][b]%s[/b] %s  %ds[/color]" % [yel, tr("P4_NEXT"), tr("P4_NEXT_ACCEPT"), int(ceil(cm.ring_left))]
		ContactManager.Phase.ACTIVE:
			if not cm.composer.is_empty():
				return "[color=%s][b]%s[/b] %s[/color]" % [yel, tr("P4_NEXT"), tr("P4_NEXT_COMPOSER")]
			if cm.tree != null:
				if cm.tree.waiting_action():
					return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_WAIT_PORTAL")]
				if cm.on_hold:
					return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_NEXT_ON_HOLD")]
				return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_NEXT_TREE")]
			if cm.case != null:
				var col := "#ff6a5a" if cm.case_timer_color() in ["rojo", "pasado"] else "#d8e0c0"
				return "[color=%s][b]%s[/b] %s[/color]" % [col, tr("P4_NEXT"), tr(cm.case.next_step_key())]
	if Metrics.aux == Metrics.Aux.BO:
		return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_NEXT_BO")]
	if Metrics.aux == Metrics.Aux.AVAILABLE:
		return "[b]%s[/b] %s" % [tr("P4_NEXT"), tr("P4_NEXT_AVAILABLE")]
	return "[b]%s[/b] %s" % [tr("P4_NEXT"), Loc.fmt(tr("P4_NEXT_AUX"), {"aux": Metrics.aux_name()})]

class_name PcPortal
extends VBoxContainer
## App Portal Vitzo (PLAN §6.3, DIALOGOS §3): buscar transacción → estado (Recibido / Liberado / Depositado /
## En revisión / Revertido), POD ([Descargar POD] y [Adjuntar al caso], o "no disponible"), [Solicitud de
## reversal] y [Contacto partner] (SOL-n). En T3 un aviso de mantenimiento invita a escribir a ops@vitzo.kp:
## es una trampa (abre el redactor dirigido a Vitzo).

var cm: ContactManager = null
var _search: LineEdit = null
var _banner: Button = null
var _result: RichTextLabel = null
var _actions: HBoxContainer = null
var _status: Label = null
var _sig: String = ""
var last_sol: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 5)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", PcStyle.box(Color(0.06, 0.2, 0.11), PcStyle.VITZO.darkened(0.3), 6.0))
	add_child(head)
	head.add_child(PcStyle.label(tr("P4_PORTAL_TITLE"), PcStyle.F_BODY, Color(0.75, 1.0, 0.8), false))
	_banner = Button.new()
	_banner.flat = true
	_banner.focus_mode = Control.FOCUS_NONE
	_banner.text = tr("P4_PORTAL_BANNER")
	_banner.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	_banner.add_theme_color_override("font_color", PcStyle.YELLOW)
	_banner.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_banner.pressed.connect(func() -> void: if cm != null: cm.open_mailto_vitzo())
	_banner.visible = false
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_meta("guia", "portal:buscar")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	add_child(row)
	row.add_child(PcStyle.label(tr("P4_PORTAL_SEARCH"), PcStyle.F_SMALL, PcStyle.DIM, false))
	_search = LineEdit.new()
	_search.placeholder_text = "KP-0000-0000"
	_search.custom_minimum_size = Vector2(190, 0)
	_search.add_theme_font_size_override("font_size", PcStyle.F_SMALL)
	# v0.3.2: como en Kardex, al buscar con [Intro] el campo suelta el foco (las teclas vuelven a ser las del juego).
	_search.text_submitted.connect(func(t: String) -> void:
		search(t)
		_search.release_focus())
	_search.focus_entered.connect(func() -> void: GameState.flags["pc_text_focus"] = true)
	_search.focus_exited.connect(func() -> void: GameState.flags["pc_text_focus"] = false)
	row.add_child(_search)
	row.add_child(PcStyle.button(tr("P4_SEARCH"), func() -> void: search(_search.text)))
	row.add_child(PcStyle.button(tr("P4_PORTAL_USE_CASE"), func() -> void: search(case_tx())))
	add_child(PcStyle.hsep())
	_result = RichTextLabel.new()
	_result.bbcode_enabled = true
	_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result.add_theme_font_size_override("normal_font_size", PcStyle.F_BODY)
	_result.add_theme_font_size_override("bold_font_size", PcStyle.F_BODY)
	add_child(_result)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	add_child(_actions)
	_status = PcStyle.label("", PcStyle.F_SMALL, PcStyle.VITZO)
	add_child(_status)


## KP del contacto/caso abierto (para el botón "Usar KP del caso").
func case_tx() -> String:
	if cm == null:
		return ""
	if cm.case != null:
		return cm.case.tx()
	return str((cm.current.get("portal", {}) as Dictionary).get("tx", ""))


func search(t: String) -> void:
	if cm == null or t.strip_edges() == "":
		return
	_search.text = t.strip_edges().to_upper()
	cm.portal_search(_search.text)
	_status.text = ""
	_sig = ""


func refresh(_delta: float) -> void:
	if cm == null:
		return
	var v := cm.portal_view
	var sig := "%s|%s|%s|%s" % [str(v), str(cm.case.portal_done) if cm.case != null else "", str(cm.case.attach_pod) if cm.case != null else "", str(cm.current.get("id", ""))]
	if sig == _sig:
		return
	_sig = sig
	_result.clear()
	PcStyle.clear(_actions)
	_banner.visible = bool(v.get("banner", false))
	if v.is_empty():
		_result.append_text("[color=#5a6670]%s[/color]" % tr("P4_PORTAL_EMPTY"))
		return
	if v.has("no_existe"):
		_result.append_text("[color=#e5241f]%s[/color]" % Loc.fmt(tr("P4_PORTAL_NOT_FOUND"), {"tx": str(v.get("tx", ""))}))
		return
	var est := str(v.get("estado", ""))
	_result.append_text("[b]%s[/b]\n%s: [color=#6fd08a][b]%s[/b][/color]\n%s: %s  ·  %s: %s\n\n" % [str(v.get("tx", "")), tr("P4_PORTAL_STATE"), tr("P4_PORTAL_ST_" + est.to_upper().replace(" ", "_")), tr("P4_KARDEX_DATE"), str(v.get("fecha", "")), tr("P4_KARDEX_AMOUNT"), str(v.get("monto", ""))])
	if bool(v.get("pod", false)):
		_result.append_text("%s\n" % Loc.fmt(tr("P4_PORTAL_POD_OK"), {"pod": str(v.get("pod_texto", ""))}))
		var dl := PcStyle.button(tr("P4_PORTAL_DOWNLOAD"), func() -> void:
			if cm.portal_download_pod():
				_status.text = tr("P4_PORTAL_DOWNLOADED"))
		_actions.add_child(dl)
		var at := PcStyle.button(tr("P4_PORTAL_ATTACH"), func() -> void:
			if cm.portal_attach_pod():
				_status.text = tr("P4_PORTAL_ATTACHED"))
		at.disabled = cm.case == null or not cm.case.portal_done.has("pod")
		_actions.add_child(at)
	else:
		_result.append_text("[color=#edc245]%s[/color]\n" % tr("P4_PORTAL_POD_NO"))
	_actions.add_child(PcStyle.button(tr("P4_PORTAL_REVERSAL"), func() -> void:
		if cm.portal_reversal():
			_status.text = tr("P4_PORTAL_REVERSAL_OK")))
	_actions.add_child(PcStyle.button(tr("P4_PORTAL_CONTACT"), func() -> void:
		last_sol = cm.portal_contact()
		if last_sol != "":
			_status.text = Loc.fmt(tr("P4_PORTAL_CONTACT_OK"), {"n": last_sol})))

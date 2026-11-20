class_name PcIdenta
extends HBoxContainer
## App Identa (KYC en BO, PLAN §6.2, proceso inventado): perfil (región, total enviado en KP, n.º de envíos),
## resultado de la e-verificación, documentos subidos, comparación documento/selfie, etiquetas (KYC Recheck
## requerido · Revisión reforzada) y cambios de datos; a la derecha las reglas de la región y las acciones:
## Aprobar · Rechazar · Solicitar documento de identidad · Solicitar comprobante de domicilio · Escalar a
## Cumplimiento · Resolver Recheck.

const ACTIONS: Array[String] = ["aprobar", "rechazar", "solicitar_id", "solicitar_comprobante", "escalar", "resolver_recheck"]

var cm: ContactManager = null
var _info: RichTextLabel = null
var _rules: RichTextLabel = null
var _buttons: VBoxContainer = null
var _sig: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var lp := PcStyle.panel(PcStyle.PANEL, 6.0)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(lp)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.add_theme_font_size_override("normal_font_size", PcStyle.F_SMALL)
	_info.add_theme_font_size_override("bold_font_size", PcStyle.F_SMALL)
	lp.add_child(_info)
	var rp := PcStyle.panel(PcStyle.PANEL, 6.0)
	rp.custom_minimum_size = Vector2(270, 0)
	add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rp.add_child(rv)
	# v0.3.1 Q1 (B5): las reglas de la región van en su propio scroll; los 6 botones quedan siempre a la vista.
	var rs := ScrollContainer.new()
	rs.name = "ReglasScroll"
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.custom_minimum_size = Vector2(0, 90)
	rv.add_child(rs)
	_rules = RichTextLabel.new()
	_rules.bbcode_enabled = true
	_rules.fit_content = true
	_rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules.add_theme_font_size_override("normal_font_size", PcStyle.F_TINY)
	_rules.add_theme_font_size_override("bold_font_size", PcStyle.F_TINY)
	rs.add_child(_rules)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 3)
	_buttons.set_meta("guia", "identa:decidir")  # v0.3.2: lo que la guía del Training señala (TrainingTargets)
	rv.add_child(_buttons)
	for a in ACTIONS:
		var act := a
		var b := PcStyle.button(tr("P4_KYC_" + a.to_upper()), func() -> void: if cm != null: cm.kyc_decide(act), PcStyle.F_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_buttons.add_child(b)


func refresh(_delta: float) -> void:
	if cm == null:
		return
	var sig := "%d|%s" % [cm.phase, str(cm.current.get("id", ""))]
	if sig == _sig:
		return
	_sig = sig
	_info.clear()
	_rules.clear()
	var active := cm.case != null and cm.case.is_kyc()
	for b in _buttons.get_children():
		(b as Button).disabled = not active
	var reglas: Dictionary = DataLoader.dict("casos_bo").get("reglas", {}).get("kyc_regiones", {})
	if not active:
		_info.append_text("[color=#5a6670]%s[/color]\n\n%s" % [tr("P4_KYC_IDLE"), tr("P4_KYC_IDLE_HINT")])
		_rules.append_text("[b]%s[/b]\n" % tr("P4_KYC_RULES"))
		for r in reglas.keys():
			# «Cualquiera» es la clave del dato, no un nombre de región: se muestra como en el caso abierto.
			_rules.append_text("[b]%s[/b]: %s\n" % [tr("P4_KYC_ANY") if str(r) == "Cualquiera" else str(r), Loc.pick(reglas[r])])
		return
	var c := cm.current
	var p: Dictionary = c.get("perfil", {})
	var ev: Dictionary = c.get("everif", {})
	var docs: Dictionary = c.get("docs", {})
	var idd: Dictionary = docs.get("id", {})
	var dom: Dictionary = docs.get("domicilio", {})
	var tags: Array = c.get("etiquetas", [])
	if tags.has("reforzada"):
		_info.append_text("[bgcolor=#5a1010][b] %s [/b][/bgcolor]  " % tr("P4_KYC_TAG_REFORZADA"))
	if tags.has("recheck"):
		_info.append_text("[bgcolor=#5a4010][b] %s [/b][/bgcolor]" % tr("P4_KYC_TAG_RECHECK"))
	if not tags.is_empty():
		_info.append_text("\n")
	_info.append_text("[b]%s[/b]  ·  %s: [b]%s[/b]\n" % [str(p.get("nombre", "")), tr("P4_KYC_REGION"), str(p.get("region", ""))])
	_info.append_text("%s: %s KP  ·  %s: %d\n" % [tr("P4_KYC_TOTAL"), _kp(int(p.get("total_kp", 0))), tr("P4_KYC_SENDS"), int(p.get("envios", 0))])
	_info.append_text("%s: %s  ·  %s: %s\n" % [tr("IDENTA_FIELD_DOB"), str(p.get("nacimiento", "")), tr("P4_KYC_DOCNUM"), str(p.get("documento", ""))])
	_info.append_text("%s: %s\n" % [tr("P4_KYC_ADDRESS"), str(p.get("direccion", ""))])
	for ch in c.get("cambios", []):
		_info.append_text("[color=#edc245]%s: %s → %s[/color]\n" % [tr("P4_KYC_CHANGE_" + str(ch.get("campo", "")).to_upper()), str(ch.get("antes", "")), str(ch.get("ahora", ""))])
	var est := str(ev.get("estado", ""))
	var ecol := {"ok": "#3fc77a", "fallo": "#e5241f"}.get(est, "#9fb0bb") as String
	var conf: Array[String] = []
	for f in ev.get("confirmo", []):
		conf.append(tr("P4_KYC_F_" + str(f).to_upper()))
	_info.append_text("\n%s: [color=%s][b]%s[/b][/color]%s\n" % [tr("P4_KYC_EVERIF"), ecol, tr("P4_KYC_EV_" + est.to_upper()), (" (" + tr("P4_KYC_CONFIRMED") + ": " + ", ".join(PackedStringArray(conf)) + ")") if not conf.is_empty() else ""])
	_info.append_text("\n[b]%s[/b]\n" % tr("P4_KYC_DOCS"))
	if bool(idd.get("subido", false)):
		_info.append_text("· %s: %s · %s · %s\n" % [tr("P4_KYC_DOC_ID"), str(idd.get("nombre", "")), str(idd.get("nacimiento", "")), str(idd.get("numero", ""))])
	else:
		_info.append_text("· %s: [color=#e5241f]%s[/color]\n" % [tr("P4_KYC_DOC_ID"), tr("P4_KYC_NOT_UPLOADED")])
	if bool(dom.get("subido", false)):
		_info.append_text("· %s: %s\n" % [tr("P4_KYC_DOC_ADDR"), str(dom.get("direccion", ""))])
	else:
		_info.append_text("· %s: [color=#e5241f]%s[/color]\n" % [tr("P4_KYC_DOC_ADDR"), tr("P4_KYC_NOT_UPLOADED")])
	var selfie_ok := bool((c.get("selfie", {}) as Dictionary).get("coincide", true))
	_info.append_text("· %s: %s\n" % [tr("IDENTA_SELFIE"), tr("P4_KYC_SELFIE_OK") if selfie_ok else "[color=#e5241f]%s[/color]" % tr("P4_KYC_SELFIE_NO")])
	var region := str(p.get("region", ""))
	_rules.append_text("[b]%s · %s[/b]\n%s\n\n[b]%s[/b]\n%s\n" % [tr("P4_KYC_RULES"), region, Loc.pick(reglas.get(region, {})), tr("P4_KYC_ANY"), Loc.pick(reglas.get("Cualquiera", {}))])


static func _kp(n: int) -> String:
	var s := str(n)
	if n >= 1000:
		s = "%d.%03d" % [n / 1000, n % 1000]
	return s

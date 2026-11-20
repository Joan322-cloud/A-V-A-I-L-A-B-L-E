class_name AgentManual
extends Control
## "Manual del agente" (v0.3 P6b, PLAN §2 #84): glosario con cada término del call center (AUX, AHT, CSAT, BO,
## KYC, POD, WMM, reversal, WW, Ack, allocation, isla, TM, QA, OM, RTA, Available %, hold, tipificación, partner…)
## y el resumen de las reglas, en ES/EN, desde data/manual_agente.json. Se abre desde la pausa (y la Inducción
## lo pide en el módulo 10); en la PC está en Campus → Manual. Funciona con el árbol en pausa. [Esc] cierra.

signal closed()

const DATA := "manual_agente"

var tab: String = "glosario"  # glosario | reglas
var _filter: LineEdit = null
var _list: VBoxContainer = null
var _tabs: Dictionary = {}
var _panel: PanelContainer = null


static func data() -> Dictionary:
	return DataLoader.dict(DATA)


static func terms() -> Array:
	return data().get("terminos", [])


## "AUX — Tu estado en Fonex…" (para Campus y las pruebas).
static func term_text(t: Dictionary) -> String:
	return "%s — %s" % [Loc.pick_hint(t.get("termino", {})), Loc.pick_hint(t.get("def", {}))]


func _ready() -> void:
	name = "AgentManual"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.flags["manual_abierto"] = true
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.01, 0.02, 0.86)
	add_child(bg)
	_panel = UITheme.panel(tr("MAN_TITLE"), Vector2(1240, 0))
	_panel.name = "Panel"
	add_child(_panel)
	UITheme.center_fit(_panel)
	var vb := UITheme.vb_of(_panel)
	vb.add_theme_constant_override("separation", 8)
	var intro := UITheme.label(tr("MAN_INTRO"), 14, UITheme.DIM)
	intro.custom_minimum_size = Vector2(1210, 0)
	vb.add_child(intro)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)
	for id in ["glosario", "reglas"]:
		var b := UITheme.button(tr("MAN_TAB_" + id.to_upper()), _set_tab.bind(id))
		b.name = "Tab_" + id
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(180, 0)
		bar.add_child(b)
		_tabs[id] = b
	_filter = LineEdit.new()
	_filter.name = "Buscar"
	_filter.placeholder_text = tr("MAN_SEARCH")
	_filter.custom_minimum_size = Vector2(420, 0)
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_t: String) -> void: _rebuild())
	bar.add_child(_filter)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.custom_minimum_size = Vector2(1210, 700)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	_list = VBoxContainer.new()
	_list.name = "Lista"
	_list.add_theme_constant_override("separation", 8)
	_list.custom_minimum_size = Vector2(1180, 0)
	sc.add_child(_list)
	var close := UITheme.button(tr("MAN_CLOSE"), func() -> void: closed.emit())
	close.name = "Cerrar"
	vb.add_child(close)
	_set_tab(tab)


func _set_tab(id: String) -> void:
	tab = id
	for k in _tabs.keys():
		(_tabs[k] as Button).button_pressed = k == id
	_filter.visible = id == "glosario"
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if tab == "reglas":
		for r in data().get("reglas", []):
			_list.add_child(UITheme.label(Loc.pick_hint(r.get("titulo", {})), 18, UITheme.YELLOW, true))
			var l := UITheme.label(Loc.pick_hint(r.get("texto", {})), 15, UITheme.TEXT)
			l.custom_minimum_size = Vector2(1170, 0)
			_list.add_child(l)
		return
	var q := _filter.text.strip_edges().to_lower()
	var cats: Dictionary = data().get("categorias", {})
	var last_cat := ""
	var n := 0
	for t in terms():
		var txt := term_text(t)
		if q != "" and not txt.to_lower().contains(q):
			continue
		var cat := str(t.get("cat", ""))
		if cat != last_cat and q == "":
			last_cat = cat
			_list.add_child(UITheme.label(Loc.pick_hint(cats.get(cat, {})).to_upper(), 13, Color(0.45, 0.85, 0.85), true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_l := UITheme.label(Loc.pick_hint(t.get("termino", {})), 16, UITheme.TEXT, true)
		name_l.custom_minimum_size = Vector2(300, 0)
		row.add_child(name_l)
		var def_l := UITheme.label(Loc.pick_hint(t.get("def", {})), 15, UITheme.TEXT)
		def_l.custom_minimum_size = Vector2(860, 0)
		def_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(def_l)
		_list.add_child(row)
		n += 1
	if n == 0:
		_list.add_child(UITheme.label(tr("MAN_NONE"), 15, UITheme.DIM))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		closed.emit()
		get_viewport().set_input_as_handled()

class_name TutorialMenu
extends Control
## Selección de módulos de la Inducción (v0.3 P6b, PLAN §2 #84): los 10 módulos con su resumen, su duración
## aproximada y si ya se hicieron o se saltaron (progreso guardado en <partidas>/_induccion/modulos.json).
## "Hacer la inducción" = los pendientes en orden; "Desde el principio" = los 10; cada fila = solo ese módulo.

signal closed()
signal start_modules(mods: Array)

var _panel: PanelContainer = null
var _confirm_reset: bool = false


func _ready() -> void:
	name = "TutorialMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.74)
	add_child(bg)
	build()


func build() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = UITheme.panel(tr("TUTM_TITLE"), Vector2(1040, 0))
	_panel.name = "Panel"
	add_child(_panel)
	UITheme.center_fit(_panel)
	var vb := UITheme.vb_of(_panel)
	vb.add_theme_constant_override("separation", 6)
	var intro := UITheme.label(tr("TUTM_INTRO"), 14, UITheme.TEXT)
	intro.custom_minimum_size = Vector2(1010, 0)
	vb.add_child(intro)
	vb.add_child(HSeparator.new())
	var prog := Tutorial.load_progress()
	var total_min := 0.0
	for m in Tutorial.modules():
		var id := str(m.get("id", ""))
		total_min += float(m.get("min", 1.0))
		var row := HBoxContainer.new()
		row.name = "Mod_" + id
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)
		var st := str(prog.get(id, ""))
		var mark := UITheme.label(tr("TUTM_DONE") if st == "hecho" else (tr("TUTM_SKIPPED") if st == "saltado" else tr("TUTM_PENDING")), 13, UITheme.GREEN if st == "hecho" else (UITheme.YELLOW if st == "saltado" else UITheme.DIM), true)
		mark.custom_minimum_size = Vector2(110, 0)
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		mark.name = "Estado"
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size = Vector2(700, 0)
		row.add_child(col)
		var head := UITheme.label("%d · %s  ·  ~%s min" % [int(m.get("n", 0)), Loc.pick(m.get("titulo", {})), _fmt_min(float(m.get("min", 1.0)))], 16, UITheme.TEXT, true)
		head.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(head)
		col.add_child(UITheme.label(Loc.pick(m.get("resumen", {})), 13, UITheme.DIM))
		var b := UITheme.button(tr("TUTM_DO_ONE"), func() -> void: start_modules.emit([id]))
		b.name = "Hacer"
		b.custom_minimum_size = Vector2(150, 0)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	vb.add_child(HSeparator.new())
	vb.add_child(UITheme.label(Loc.fmt(tr("TUTM_TOTAL"), {"min": int(round(total_min))}), 13, UITheme.DIM, true))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	vb.add_child(acts)
	var pend := Tutorial.pending_modules()
	var all_done := Tutorial.load_progress().size() >= Tutorial.module_ids().size()
	var go := UITheme.button(tr("TUTM_DO_PENDING") if not all_done else tr("TUTM_DO_ALL"), func() -> void: start_modules.emit(pend))
	go.name = "HacerPendientes"
	acts.add_child(go)
	var from_start := UITheme.button(tr("TUTM_FROM_START"), func() -> void: start_modules.emit(Tutorial.module_ids()))
	from_start.name = "DesdeElPrincipio"
	acts.add_child(from_start)
	var reset := UITheme.button(tr("TUTM_RESET_CONFIRM") if _confirm_reset else tr("TUTM_RESET"), _on_reset)
	reset.name = "Reiniciar"
	reset.disabled = Tutorial.load_progress().is_empty()
	acts.add_child(reset)
	var back := UITheme.button(tr("OPT_BACK"), func() -> void: closed.emit())
	back.name = "Volver"
	acts.add_child(back)
	go.grab_focus.call_deferred()


static func _fmt_min(m: float) -> String:
	return ("%.1f" % m).replace(".", ",") if Loc.language == "es" else "%.1f" % m


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		build()
		return
	_confirm_reset = false
	Tutorial.reset_progress()
	build()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

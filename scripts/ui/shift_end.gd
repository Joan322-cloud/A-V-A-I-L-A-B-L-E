extends Control
## Resumen del turno (GDD 3.2; v0.3: 8:45 AM): "Turno cerrado. Available 74 %. Incidencias: 1. WW: 1/3".
## v0.3 P6b (Elegir turno): si el turno era una RAMA (un turno pasado rejugado), al cerrar se elige entre
## "Seguir desde aquí" (con confirmación: la rama pasa a ser la partida principal y se pierde el progreso
## posterior) y "Volver sin cambiar mi partida" (la rama se descarta; [Espacio] hace esto, lo seguro).
## Los finales/epílogos vistos en la rama quedan en la partida para siempre en los dos casos.

signal finished()

var _lbl: Label = null
var _active: bool = false
var _branch_box: VBoxContainer = null
var _branch_lbl: Label = null
var _keep_btn: Button = null
var _drop_btn: Button = null
var _confirm_keep: bool = false
var branch_turn: int = 0  # turno de la rama que se cerró (0 = partida principal)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG
	add_child(bg)
	var p := UITheme.panel(tr("SHIFTEND_TITLE"), Vector2(640, 0))
	_lbl = UITheme.label("", 18)
	UITheme.vb_of(p).add_child(_lbl)
	_branch_box = VBoxContainer.new()
	_branch_box.name = "Rama"
	_branch_box.add_theme_constant_override("separation", 8)
	_branch_box.visible = false
	UITheme.vb_of(p).add_child(_branch_box)
	_branch_box.add_child(HSeparator.new())
	_branch_lbl = UITheme.label("", 15, UITheme.YELLOW)
	_branch_lbl.custom_minimum_size = Vector2(600, 0)
	_branch_box.add_child(_branch_lbl)
	_keep_btn = UITheme.button("", keep_branch)
	_keep_btn.name = "SeguirDesdeAqui"
	_branch_box.add_child(_keep_btn)
	_drop_btn = UITheme.button(tr("SE_BRANCH_DROP"), drop_branch)
	_drop_btn.name = "VolverSinCambiar"
	_branch_box.add_child(_drop_btn)
	add_child(p)
	UITheme.center_fit(p)
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.returned_to_menu.connect(reset)
	EventBus.shift_started.connect(reset)


func reset() -> void:
	_active = false
	visible = false
	_confirm_keep = false
	branch_turn = 0
	if _branch_box != null:
		_branch_box.visible = false


func _on_shift_ended() -> void:
	_active = true
	visible = true
	var fired := Metrics.written_warnings >= 3
	var unlocked := GameState.close_turno(fired)
	var lines: Array[String] = [
		Loc.fmt(tr("FONEX_SHIFT_CLOSED"), {"pct": int(Metrics.available_pct()), "inc": Metrics.incidents, "ww": Metrics.written_warnings}),
		"",
		"%s: %d %%" % [tr("SHIFTEND_AVAILABLE"), int(Metrics.available_pct())],
		"%s: %s" % [tr("SHIFTEND_AHT"), Loc.mmss(Metrics.aht_seconds())],
		"%s: %d" % [tr("SHIFTEND_CONTACTS"), Metrics.contacts_handled],
		"%s: %d" % [tr("SHIFTEND_ANGRY"), Metrics.angry_total],
		"%s: %d" % [tr("SHIFTEND_INCIDENTS"), Metrics.incidents],
		"%s: %d/3" % [tr("SHIFTEND_WW"), Metrics.written_warnings],
		"%s: %d/%d" % [tr("SHIFTEND_BREAKS"), Metrics.breaks_used, Metrics.breaks_allowed()],
		"%s: %s · %s" % [tr("SHIFTEND_MODE"), tr("MENU_MODE_REAL") if GameState.is_real_mode() else tr("MENU_MODE_NORMAL"), Difficulty.display_name()],
	]
	if fired or GameState.turno >= 7:
		var eid := EndingsManager.evaluate(fired)
		var edata := EndingsManager.trigger_ending(eid)
		lines.append("")
		lines.append("=== " + Loc.pick(edata.get("titulo", {})) + " ===")
		lines.append(Loc.pick(edata.get("texto", {})))
	if not Metrics.csat_values.is_empty():
		lines.append("%s: %.1f" % [tr("SHIFTEND_CSAT"), Metrics.csat_avg()])
	if Economy.active():
		lines.append(Loc.fmt(tr("SHIFTEND_SALARY"), {"ganado": Economy.soles(Economy.ganado_turno), "ww": Economy.soles(Economy.ww_discount()), "saldo": Economy.soles(Economy.saldo)}))
	if unlocked > 0 and GameState.turno_available(unlocked):
		lines.append("")
		lines.append(Loc.fmt(tr("SHIFTEND_UNLOCKED"), {"n": unlocked, "dia": Days.full(unlocked)}))
	lines.append("")
	branch_turn = int(SaveSlots.progress().get("rama_de", GameState.turno)) if SaveSlots.in_branch() else 0
	if branch_turn > 0:
		if fired:
			lines.append(tr("SHIFTEND_FIRED"))
		_confirm_keep = false
		_refresh_branch()
	else:
		lines.append(tr("SHIFTEND_FIRED") if fired else tr("SHIFTEND_NEXT"))
	_lbl.text = "\n".join(lines)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true
		player.capture_mouse(false)
	Checkpoints.delete_save()


func _refresh_branch() -> void:
	_branch_box.visible = true
	var later := SaveSlots.frontier() > branch_turn or SaveSlots.has_main_checkpoint()
	if _confirm_keep:
		_branch_lbl.text = Loc.fmt(tr("SE_BRANCH_CONFIRM_TEXT"), {"n": branch_turn, "dia": Days.day_name(branch_turn)}) if later else Loc.fmt(tr("SE_BRANCH_CONFIRM_TEXT_SAFE"), {"n": branch_turn, "dia": Days.day_name(branch_turn)})
		_keep_btn.text = tr("SE_BRANCH_KEEP_CONFIRM")
		_keep_btn.add_theme_color_override("font_color", UITheme.YELLOW)
	else:
		_branch_lbl.text = Loc.fmt(tr("SE_BRANCH_TEXT"), {"n": branch_turn, "dia": Days.day_name(branch_turn)})
		_keep_btn.text = tr("SE_BRANCH_KEEP")
		_keep_btn.remove_theme_color_override("font_color")
	_drop_btn.text = tr("SE_BRANCH_CANCEL") if _confirm_keep else tr("SE_BRANCH_DROP")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.capture_mouse(false)


## "Seguir desde aquí": primera pulsación pide confirmar; la segunda reemplaza la partida principal.
func keep_branch() -> void:
	if branch_turn <= 0 or not _active:
		return
	if not _confirm_keep:
		_confirm_keep = true
		_refresh_branch()
		return
	SaveSlots.end_branch(true)
	_close()


## Volver sin cambiar la partida (descarta la rama). Con la confirmación abierta, la cancela.
func drop_branch() -> void:
	if branch_turn <= 0 or not _active:
		return
	if _confirm_keep:
		_confirm_keep = false
		_refresh_branch()
		return
	SaveSlots.end_branch(false)
	_close()


func _close() -> void:
	_active = false
	visible = false
	branch_turn = 0
	_branch_box.visible = false
	finished.emit()


func _process(_delta: float) -> void:
	if _active and Input.is_action_just_pressed("accept"):
		if branch_turn > 0:
			drop_branch()  # [Espacio] = lo seguro: no tocar la partida principal (o cancelar la confirmación)
			return
		_close()

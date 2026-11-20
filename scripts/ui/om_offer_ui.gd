class_name OMOfferUI
extends CanvasLayer
## v0.4.1 · Viernes 08:00 AM: Ventana interactiva con las 4 ofertas operativas del OM + la 5.ª oferta de Ascenso.

signal offer_chosen(choice_id: String)

var _active: bool = false


func _ready() -> void:
	name = "OMOfferUI"
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_active = true
	get_tree().paused = true
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl != null:
		pl.input_locked = true
		pl.capture_mouse(false)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	add_child(bg)
	var title := "OFICINA DE OPERACIONES · LAS 5 PROPUESTAS DEL OM (08:00 AM)" if Loc.lang != "en" else "OPERATIONS MANAGER · THE 5 OFFERS (08:00 AM)"
	var panel := UITheme.panel(title, Vector2(820, 0))
	add_child(panel)
	UITheme.center_fit(panel)
	var vb := UITheme.vb_of(panel)
	vb.add_theme_constant_override("separation", 10)
	var intro := UITheme.label(
		"«Jiroshi, la Fila C está perdiendo gente. Elige cómo quieres cerrar tu semana antes del turno de mañana.»" if Loc.lang != "en"
		else "«Jiroshi, Row C is losing people. Choose how you want to close out your week before tomorrow's shift.»",
		15, UITheme.TEXT, true
	)
	intro.custom_minimum_size = Vector2(780, 0)
	vb.add_child(intro)
	vb.add_child(HSeparator.new())
	var offers: Array = [
		["doblar", "1. Doblar turno mañana (+S/ 180 · +Obediencia, +Desgaste)" if Loc.lang != "en" else "1. Double shift tomorrow (+S/ 180 · +Obedience, +Burnout)"],
		["traslado", "2. Traslado silencioso de campaña (+S/ 120 · +Obediencia)" if Loc.lang != "en" else "2. Quiet campaign transfer (+S/ 120 · +Obedience)"],
		["silencio", "3. Bono de confidencialidad sobre la Fila C (+S/ 250 · +Obediencia)" if Loc.lang != "en" else "3. Row C non-disclosure bonus (+S/ 250 · +Obedience)"],
		["rechazar", "4. Rechazar todas las ofertas y mantener tu contrato (+Rebeldía)" if Loc.lang != "en" else "4. Reject all offers and keep your contract (+Rebellion)"],
		["ascenso", "★ 5. Aceptar Ascenso a Supervisor de la Fila C (Puesto de Shero)" if Loc.lang != "en" else "★ 5. Accept Promotion to Row C Supervisor (Shero's Desk)"]
	]
	for item in offers:
		var cid := str(item[0])
		var btn := UITheme.button(str(item[1]), _pick.bind(cid))
		btn.custom_minimum_size = Vector2(780, 44)
		if cid == "ascenso":
			btn.add_theme_color_override("font_color", UITheme.YELLOW)
		elif cid == "rechazar":
			btn.add_theme_color_override("font_color", UITheme.EZLAK)
		vb.add_child(btn)


func _pick(choice_id: String) -> void:
	if not _active:
		return
	_active = false
	GameState.flags["om_oferta_elegida"] = choice_id
	match choice_id:
		"doblar":
			SaveSlots.bump_counter("obe", 2, "Jiroshi")
			SaveSlots.bump_counter("des", 2, "Jiroshi")
			Economy.saldo += 180.0
		"traslado":
			SaveSlots.bump_counter("obe", 2, "Jiroshi")
			Economy.saldo += 120.0
		"silencio":
			SaveSlots.bump_counter("obe", 3, "Jiroshi")
			Economy.saldo += 250.0
		"rechazar":
			SaveSlots.bump_counter("reb", 3, "Jiroshi")
		"ascenso":
			GameState.flags["ascenso_aceptado"] = true
			SaveSlots.bump_counter("obe", 5, "Jiroshi")
	var st := get_node_or_null("/root/SteamManager")
	if st != null and st.has_method("unlock"):
		st.call("unlock", "OM_DECISION")
	get_tree().paused = false
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl != null:
		pl.input_locked = false
		pl.capture_mouse(true)
	EventBus.show_message.emit("Decisión registrada ante Gerencia." if Loc.lang != "en" else "Decision logged with Management.", 4.0)
	offer_chosen.emit(choice_id)
	queue_free()

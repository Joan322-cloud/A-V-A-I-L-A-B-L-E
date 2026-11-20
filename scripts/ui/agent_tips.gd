class_name AgentTips
extends Control
## Tooltips de primera vez (v0.3 P6b, PLAN §2 #84): la primera vez que pasa algo en una partida (primer contacto,
## primer correo, primer KYC, primer recordatorio de Vitzo, primer WW, primer break, salir de la sala, la lista del
## Mentor, Rooms, Haime, training, lunch, Fatiga alta, persecución…) aparece un aviso corto con lo que hay que hacer.
## Una sola vez por partida (SaveSlots.tooltips_vistos). Fácil y Normal los muestran; Difícil y Turno real no
## (Difficulty.flag("tooltips")). Fácil añade además pistas extra (persecución: sentarte en C-14 te salva).
## No sale en la Inducción (ahí guía el tutorial). Textos: data/manual_agente.json/tooltips.
## También da la pista extra de Fácil para el panel «Siguiente paso» de la PC (next_step_hint).

const SHOW_S := 9.0

var _box: PanelContainer = null
var _lbl: Label = null
var _queue: Array[String] = []
var _left: float = 0.0
var shown: Array[String] = []  # lo mostrado en esta sesión (pruebas)
var _current: String = ""
var _placed_zoom: bool = false


func _ready() -> void:
	name = "AgentTips"
	add_to_group("agent_tips")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = PanelContainer.new()
	_box.name = "Tip"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.92)
	sb.border_color = UITheme.YELLOW.darkened(0.25)
	sb.set_border_width_all(1)
	sb.border_width_left = 5
	sb.set_content_margin_all(12)
	_box.add_theme_stylebox_override("panel", sb)
	# P7: arriba a la izquierda (franja libre sobre los dos monitores de la PC; al medio tapaba el Kardex / Correo).
	_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_box.offset_left = 24
	_box.offset_top = 18
	_box.offset_bottom = 18
	_box.grow_vertical = Control.GROW_DIRECTION_END
	_box.custom_minimum_size = Vector2(500, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	var vb := VBoxContainer.new()
	_box.add_child(vb)
	vb.add_child(UITheme.label(tr("TIP_TITLE"), 12, UITheme.YELLOW, true))
	_lbl = UITheme.label("", 16, UITheme.TEXT)
	_lbl.custom_minimum_size = Vector2(470, 0)
	vb.add_child(_lbl)
	EventBus.contact_offered.connect(_on_offered)
	EventBus.contact_accepted.connect(_on_accepted)
	EventBus.vitzo_reminder.connect(func(_e: String, _s: float) -> void: tip("vitzo_reminder"))
	EventBus.written_warning_issued.connect(func(_n: int, _r: String) -> void: tip("ww"))
	EventBus.break_started.connect(func(_n: int) -> void: tip("break"))
	EventBus.room_exited.connect(_on_room_exited)
	EventBus.allocation_posted.connect(func(_a: int, _c: float, _u: float) -> void: tip("allocation"))
	EventBus.ezlak_post.connect(_on_post)
	EventBus.coaching_requested.connect(func(_s: float) -> void: tip("rooms"))
	EventBus.qa_feedback_called.connect(func(_n: int) -> void: tip("qa"))
	EventBus.training_called.connect(func() -> void: tip("training"))
	EventBus.lunch_window.connect(func(open: bool) -> void: if open: tip("lunch"))
	EventBus.fatigue_changed.connect(func(v: float, _l: int) -> void: if v >= 60.0: tip("fatiga"))
	EventBus.pursuit_started.connect(func(_h: String, _c: String) -> void:
		tip("persecucion")
		if Difficulty.flag("salvarse_sentado"):
			tip("persecucion_facil"))
	EventBus.shift_started.connect(_clear)
	EventBus.returned_to_menu.connect(_clear)
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: _clear())


## ¿Se muestran tooltips ahora? (no en la Inducción ni en Difícil / Turno real)
static func enabled() -> bool:
	return not GameState.is_tutorial() and Difficulty.flag("tooltips") and not GameState.is_real_mode()


static func text_of(id: String) -> String:
	return Loc.pick_hint((DataLoader.dict("manual_agente").get("tooltips", {}) as Dictionary).get(id, {}))  # con las teclas asignadas


## Muestra el tooltip `id` si es la primera vez en esta partida. Devuelve true si lo encoló.
func tip(id: String) -> bool:
	if not enabled() or not GameState.running or SaveSlots.tooltip_seen(id) or _queue.has(id) or text_of(id) == "":
		return false
	SaveSlots.mark_tooltip(id)
	_queue.append(id)
	return true


func _clear() -> void:
	_queue.clear()
	_current = ""
	_left = 0.0
	if _box != null:
		_box.visible = false


## P7: una pantalla que ocupa la esquina (el feedback de Haime en la sala de calibración, el quiz del Trainer) tiene
## prioridad: el aviso espera y sale al cerrarla.
func _blocked() -> bool:
	for n in get_tree().get_nodes_in_group("subtitle_owner"):
		if n.has_method("owns_subtitles") and bool(n.call("owns_subtitles")):
			return true
	for n in get_tree().get_nodes_in_group("tip_blocker"):
		if n.has_method("blocks_tips") and bool(n.call("blocks_tips")):
			return true
	return false


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _blocked():
		if _box.visible:
			_box.visible = false
			if _current != "" and not _queue.has(_current):
				_queue.push_front(_current)
			_left = 0.0
		return
	if _left > 0.0:
		# La PC se acerca o se aleja con el aviso a la vista: se recoloca en el mismo cuadro (a pocos fps, esperar
		# 10 cuadros lo dejaba varios segundos en el sitio viejo, encima de otro texto).
		if _zoomed() != _placed_zoom or Engine.get_process_frames() % 10 == 0:
			_place()
		_left -= delta
		if _left <= 0.0:
			_box.visible = false
		return
	if _queue.is_empty() or not GameState.running:
		return
	var id: String = _queue.pop_front()
	_current = id
	if not shown.has(id):
		shown.append(id)
	_lbl.text = text_of(id)
	_box.visible = true
	_box.reset_size()
	_box.reset_size.call_deferred()  # la etiqueta con autowrap calcula su alto un frame después
	_left = SHOW_S
	_place()


## v0.3.1 Q1 (revisión de Joan): con la PC acercada el aviso va centrado en la franja libre de arriba (encima de las
## pantallas y a la izquierda del HUD), nunca sobre la cabecera de la PC; sin acercar, arriba a la izquierda.
func _zoomed() -> bool:
	var ws := get_tree().get_first_node_in_group("workstation")
	return ws != null and bool(ws.get("zoomed"))


func _place() -> void:
	var vp := get_viewport_rect().size
	_placed_zoom = _zoomed()
	if _placed_zoom:
		var w := clampf(vp.x - 2.0 * maxf(300.0, vp.x * 0.17), 420.0, 820.0)
		_box.custom_minimum_size = Vector2(w, 0)
		_lbl.custom_minimum_size = Vector2(w - 30.0, 0)
		_lbl.add_theme_font_size_override("font_size", 15)
		_box.offset_left = (vp.x - w) * 0.5
		_box.offset_top = 8
		_box.offset_bottom = 8
	else:
		_box.custom_minimum_size = Vector2(500, 0)
		_lbl.custom_minimum_size = Vector2(470, 0)
		_lbl.add_theme_font_size_override("font_size", 16)
		_box.offset_left = 24
		_box.offset_top = 18
		_box.offset_bottom = 18
	_box.reset_size()


func _on_offered(c: Dictionary) -> void:
	if GameState.logged_in and Metrics.contacts_handled == 0:
		tip("contacto")
	match str(c.get("canal", "")):
		"correo":
			tip("vitzo_caso" if str(c.get("vitzo", "")) != "" else "correo")
		"kyc":
			tip("kyc")


func _on_accepted(c: Dictionary) -> void:
	if c.has("nodos"):
		tip("arbol")


func _on_room_exited() -> void:
	if GameState.logged_in and not Metrics.is_authorized("edificio") and not Metrics.is_authorized("sala_calibracion") and not Metrics.is_authorized("piso_1"):
		tip("fuera_sala")


func _on_post(_ch: String, author: String, _t: String, meta: Dictionary) -> void:
	if str(meta.get("tipo", "")) == "allocations":
		tip("lista")
	elif author == "rasec" and str(meta.get("tipo", "")).contains("evento"):
		tip("rasec")


## v0.3.2: la pista del caso de Vitzo dice lo que pide ESE caso (antes siempre «responde al Cliente», también cuando
## había que mandarle el POD al banco o no había que escribir a nadie).
static func _vitzo_hint(k: CasoBO) -> String:
	match k.vitzo_kind():
		"pod": return "HINT_VITZO_POD"
		"reversal": return "HINT_VITZO_REVERSAL"
	return "HINT_PARTNER_VITZO"


## Pista extra del panel «Siguiente paso» en Fácil (Difficulty.flag("pistas_extra")); "" si no hay.
static func next_step_hint(cm_v: Variant) -> String:
	if not Difficulty.flag("pistas_extra") or GameState.is_tutorial() or not is_instance_valid(cm_v) or not (cm_v is ContactManager):
		return ""
	var cm := cm_v as ContactManager
	match cm.phase:
		ContactManager.Phase.OFFERING:
			return ""
		ContactManager.Phase.ACTIVE:
			if cm.tree != null:
				return TranslationServer.translate("HINT_TREE")
			if cm.case != null:
				var key := cm.case.next_step_key()
				var map := {"P4_STEP_KARDEX": "HINT_KARDEX", "P4_STEP_PARTNER": _vitzo_hint(cm.case) if cm.case.partner() == "Vitzo" else "HINT_PARTNER", "P4_STEP_TIPIFICAR": "HINT_TIPIFICAR", "P4_STEP_KYC": "HINT_KYC", "P4_STEP_CERRAR": "HINT_CERRAR"}
				var k := str(map.get(key, ""))
				return TranslationServer.translate(k) if k != "" else ""
	return ""

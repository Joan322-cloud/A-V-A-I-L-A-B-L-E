extends Node
## Comodin (autoload, v0.3.2; Joan: «si por X razón no puedes llegar a tiempo, tienes un comodín que puedes usar una
## vez por turno de llamar a uno de tus compañeros para que marquen el AUX, fin de lunch, o lo que necesites en tu PC»).
## Sin terminales Fonex de pared, el AUX solo se cambia en una PC de la sala; lejos de ella, una vez por turno:
##   mantén [C] (acción «comodin», 0,6 s) → eliges qué AUX te marcan [1-7] → a quién llamas [1-4] → suena el teléfono
##   y en 10-20 s de juego el compañero contesta y te lo marca en tu PC. Si no contesta (dormido, en lunch, en una
##   llamada, o enojado contigo: IABrain), tienes balance.json/comodin/reintento_s_real (30 s reales) para llamar a otro con
##   el MISMO comodín; si nadie contesta, se pierde. Usado: el HUD dice «Comodín usado (1/1)».
## Shero ve que tu PC cambió sin ti: DM sarcástico; la 1.ª vez en la partida del agente sin castigo, después un verbal.
## Ganchos (contrato con la rama v0.3.2-ia): si existe el autoload IABrain, can_coworker_answer(nombre) y
## coworker_comodin(nombre) -> {answers, line, dm} mandan; si no, contesta quien esté «disponible» o en BO/coaching
## según ColaACD.npc_state (dormido, lunch, training o en un contacto: no contesta).
## v0.3.2-core: solo contesta quien está «activo» en Ezlaki (IABrain.presence), y el panel LO DICE: al lado de cada
## nombre va su estado (activo · en llamada · en lunch · ausente), en vivo. Si nadie está activo, el panel avisa
## («Nadie está activo ahora…») ANTES de gastar el comodín. A quien llamaste estando «activo» te contesta aunque en
## los 10-20 s del timbre le entre una llamada (lo que viste en el panel vale). Al fallar, el subtítulo dice por qué.

signal call_started(who: String)
signal call_answered(who: String, aux: int)
signal call_failed(who: String, reason: String)

const HOLD_S := 0.6

## Se gastó en este turno. v0.3.2-core: vive en GameState.flags (viaja con el checkpoint). Antes era una variable
## suelta: salir al menú y «Continuar» lo devolvía intacto (comodín infinito) y morir no lo devolvía aunque el
## checkpoint fuera anterior a gastarlo.
const FLAG_USED := "comodin_usado"
var used: bool:
	get:
		return bool(GameState.flags.get(FLAG_USED, false))
	set(v):
		if v:
			GameState.flags[FLAG_USED] = true
		else:
			GameState.flags.erase(FLAG_USED)
var phase: String = ""  # "" · aux · who · ringing · retry
var chosen_aux: int = -1
var calling: String = ""
var tried: Array[String] = []
var retry_left: float = 0.0
var answer_at: float = 0.0  # reloj de juego en que contesta (o no)
## Pruebas: Callable(nombre) -> bool que reemplaza a la decisión por defecto (sin IABrain).
var answer_override: Callable = Callable()
## v0.3.2 Training (el recuerdo): con nombres aquí, el comodín es de PRÁCTICA: llamas a tu promoción (no a los agentes
## de hoy), Shero no se entera, no hay DM y no cuenta para la partida (comodin_usos). Lo pone y lo quita Tutorial.
var practice_names: Array[String] = []
var _hold: float = 0.0
var _rng := RandomNumberGenerator.new()
var _layer: CanvasLayer = null
var _label: RichTextLabel = null
var _active_at_call: bool = false  # estaba «activo» cuando lo llamaste: contesta aunque después le entre un contacto
var _ui_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not InputMap.has_action("comodin"):
		InputMap.add_action("comodin")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_C
		InputMap.action_add_event("comodin", k)
	EventBus.shift_started.connect(reset)
	EventBus.returned_to_menu.connect(reset)
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: _close())
	EventBus.respawned.connect(func(_k: String) -> void: _close(); tried.clear())  # «gastado» vuelve con el checkpoint
	_build_ui()
	reset()


func reset() -> void:
	used = false
	_close()
	tried.clear()
	_rng.seed = hash(GameState.agent) + GameState.turno * 31


func _cfg() -> Dictionary:
	return DataLoader.dict("balance").get("comodin", {})


func coworkers() -> Array[String]:
	if not practice_names.is_empty():
		return practice_names
	var out: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			out.append(a)
	return out


func _acd() -> ColaACD:
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager if is_inside_tree() else null
	return cm.acd if cm != null else null


## Estado del compañero (ColaACD): disponible · contacto · bo · break · lunch · coaching · training · dormido.
func coworker_state(n: String) -> String:
	var acd := _acd()
	return acd.npc_state(n) if acd != null else "disponible"


func _brain() -> Node:
	return get_node_or_null("/root/IABrain")


## Estado de Ezlaki del compañero para el panel: {estado (activo · llamada · lunch · pausa · ausente), texto, color}.
## En la práctica del Training (tu promoción al teléfono) todos están activos.
func presence_of(n: String) -> Dictionary:
	if not practice_names.is_empty():
		return {"estado": "activo", "texto": tr("IA_PRES_ACTIVO"), "color": "#3fc77a"}
	var b := _brain()
	if b != null and b.has_method("presence"):
		var p: Variant = b.call("presence", n)
		if p is Dictionary:
			return p
	var st := coworker_state(n)
	var est := "activo"
	match st:
		"contacto", "coaching": est = "llamada"
		"lunch": est = "lunch"
		"break", "training", "dormido", "fuera": est = "ausente"
	var col := {"activo": "#3fc77a", "llamada": "#e8503f", "lunch": "#edb845", "ausente": "#6a7682"}
	return {"estado": est, "texto": tr("IA_PRES_" + est.to_upper()), "color": str(col.get(est, "#6a7682"))}


## ¿Hay alguien a quien todavía puedas llamar que esté «activo» ahora?
func anyone_active() -> bool:
	for n in coworkers():
		if not tried.has(n) and str(presence_of(n).get("estado", "")) == "activo":
			return true
	return false


## ¿Contesta? IABrain (relación, enojo) si existe; si no, dormido / en lunch / en training / en un contacto no contestan.
func can_coworker_answer(n: String) -> bool:
	if answer_override.is_valid():
		return bool(answer_override.call(n))
	var b := _brain()
	if b != null and b.has_method("can_coworker_answer"):
		return bool(b.call("can_coworker_answer", n))
	return coworker_state(n) in ["disponible", "bo", "coaching", "break"]


func _brain_reply(n: String) -> Dictionary:
	if answer_override.is_valid():
		return {}  # pruebas: decide el override (can_coworker_answer), no el cerebro
	if not practice_names.is_empty():
		return {}  # práctica del Training: sin cerebro
	var b := _brain()
	if b != null and b.has_method("coworker_comodin"):
		var r: Variant = b.call("coworker_comodin", n, true, _active_at_call)
		if r is Dictionary:
			return r
	return {}


func can_use() -> bool:
	return GameState.running and GameState.logged_in and not GameState.shift_over and not used and not Checkpoints.dying


## Espacio que no parte la línea: cada opción del panel («7 Training», «4 Juan ● ausente») salta de línea entera
## (antes el número se quedaba arriba y el nombre abajo).
const NBSP := "\u00a0"


static func _nb(t: String) -> String:
	return t.replace(" ", NBSP)


## Abre el comodín (lo mismo que mantener [C]). false si no se puede (ya usado, estás en una PC, sin login).
func open() -> bool:
	if phase != "":
		return false
	if not GameState.logged_in or not GameState.running:
		return false
	if used:
		EventBus.show_message.emit(tr("B2_COMODIN_SPENT"), 2.5)
		return false
	if Discipline.at_pc():
		EventBus.show_message.emit(tr("B2_COMODIN_AT_PC"), 2.5)
		return false
	phase = "aux"
	_refresh_ui()
	return true


func choose_aux(i: int) -> void:
	if phase != "aux" or i < 0 or i >= Metrics.AUX_KEYS.size():
		return
	chosen_aux = i
	phase = "who"
	_refresh_ui()


## Llama al compañero `idx` (0-3 de coworkers()). La primera llamada gasta el comodín.
func choose_coworker(idx: int) -> void:
	var names := coworkers()
	if (phase != "who" and phase != "retry") or idx < 0 or idx >= names.size():
		return
	var n := names[idx]
	if tried.has(n):
		return
	tried.append(n)
	used = true
	calling = n
	_active_at_call = str(presence_of(n).get("estado", "")) == "activo"
	phase = "ringing"
	answer_at = GameState.clock_seconds + _rng.randf_range(float(_cfg().get("contesta_min_s_juego", 10.0)), float(_cfg().get("contesta_max_s_juego", 20.0)))
	AudioManager.play_sfx("telefono_timbre", "UI")
	EventBus.subtitle.emit("sys", Loc.fmt(tr("B2_COMODIN_RINGING"), {"quien": n}), 3.0)
	call_started.emit(n)
	_refresh_ui()


func cancel() -> void:
	if phase in ["aux", "who"]:
		_close()  # aún no llamó a nadie: no se gasta
	elif phase == "retry":
		_lost()


func _close() -> void:
	phase = ""
	calling = ""
	chosen_aux = -1
	retry_left = 0.0
	_hold = 0.0
	if _layer != null:
		_layer.visible = false


func _process(delta: float) -> void:
	if not GameState.running:
		return
	if phase == "":
		if InputMap.has_action("comodin") and Input.is_action_pressed("comodin") and not bool(GameState.flags.get("pc_text_focus", false)):
			_hold += delta
			if _hold >= HOLD_S:
				_hold = 0.0
				open()
		else:
			_hold = 0.0
		return
	if phase == "ringing" and GameState.clock_seconds >= answer_at:
		_resolve()
	elif phase == "retry":
		retry_left -= delta
		if retry_left <= 0.0:
			_lost()
		else:
			_refresh_ui()
	elif phase == "who":
		_ui_t -= delta / maxf(Engine.time_scale, 0.001)
		if _ui_t <= 0.0:
			_ui_t = 0.5
			_refresh_ui()  # los estados cambian mientras eliges


func _unhandled_input(event: InputEvent) -> void:
	if phase == "" or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var k := (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != 0 else (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
		return
	var d := int(k) - int(KEY_1)
	if d < 0 or d > 8:
		return
	if phase == "aux":
		choose_aux(d)
	elif phase in ["who", "retry"]:
		choose_coworker(d)
	get_viewport().set_input_as_handled()


func _resolve() -> void:
	var n := calling
	var reply := _brain_reply(n)
	var ok := bool(reply.get("answers", can_coworker_answer(n))) if not reply.is_empty() else can_coworker_answer(n)
	if not ok:
		var st := coworker_state(n)
		var key := fail_key(n, st, str(reply.get("reason", "")))
		last_fail = {"quien": n, "estado": st, "motivo": str(reply.get("reason", "")), "clave": key}
		EventBus.subtitle.emit("sys", Loc.fmt(tr(key), {"quien": n}), 3.5)
		call_failed.emit(n, st)
		if tried.size() >= coworkers().size():
			_lost()
			return
		phase = "retry"
		calling = ""
		retry_left = float(_cfg().get("reintento_s_real", 30.0))
		_refresh_ui()
		return
	# Contesta y te lo marca en tu PC.
	var aux := chosen_aux
	var line := str(reply.get("line", "")) if not reply.is_empty() else ""
	if line == "":
		line = tr("B2_COMODIN_LINE_%d" % _rng.randi_range(1, 3))
	EventBus.subtitle.emit(n.to_lower(), "[%s] %s" % [n, line], 3.5)
	if GameState.logged_in:
		GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()  # cuenta como cambio tuyo (ACD)
		# v0.3.2-core4: si este Break es uno de más (el tercero), el comodín lo cubre durante su cupo: Discipline lo sabe
		# porque se lo decimos justo antes de marcarlo (la práctica del Training no cuenta).
		if aux == Metrics.Aux.BREAK and practice_names.is_empty():
			Discipline.comodin_marks_break(n)
		Metrics.set_aux(aux)
		Discipline.comodin_marks_break("")
		# El checkpoint, como al elegir el AUX en la PC (un break de más no guarda checkpoint: core3).
		Checkpoints.on_aux_picked(aux)
	EventBus.show_message.emit(Loc.fmt(tr("B2_COMODIN_DONE"), {"quien": n, "aux": Metrics.aux_name()}), 3.5)
	if practice_names.is_empty():
		# Con IABrain, el DM de después («ya te marqué. me debes una») lo publica el cerebro (coworker_comodin): aquí no se repite.
		var dm := "" if not reply.is_empty() else Loc.fmt(tr("B2_COMODIN_DM"), {"aux": Metrics.aux_name()})
		if dm != "":
			EventBus.ezlak_post.emit("dm:" + n.to_lower(), n.to_lower(), dm, {"tipo": "comodin", "typing_s": 2.0})
		_shero_notices(aux)
	call_answered.emit(n, aux)
	_close()


## Por qué no contestó (clave de texto): por su estado (dormido, lunch, break, training, coaching, en un contacto) o,
## si estaba activo, porque no quiso (IABrain: rencor, molesto, lo delataste).
var last_fail: Dictionary = {}


func fail_key(n: String, st: String, reason: String) -> String:
	match st:
		"dormido": return "B2_COMODIN_ASLEEP"
		"lunch": return "B2_COMODIN_LUNCH"
		"contacto": return "B2_COMODIN_BUSY"
		"break": return "B2_COMODIN_BREAK"
		"training": return "B2_COMODIN_TRAINING"
		"coaching": return "B2_COMODIN_COACHING"
		"fuera": return "B2_COMODIN_AWAY"
	if reason in ["rencor", "molesto", "delatado"]:
		return "B2_COMODIN_IGNORED"
	if reason == "presencia" and str(presence_of(n).get("estado", "")) == "ausente":
		return "B2_COMODIN_AWAY"
	return "B2_COMODIN_NO_ANSWER"


## Shero ve que tu PC cambió sin ti: la 1.ª vez en la partida, DM sarcástico; después, además un verbal.
func _shero_notices(_aux: int) -> void:
	var prog := SaveSlots.progress()
	var uses := int(prog.get("comodin_usos", 0)) + 1
	prog["comodin_usos"] = uses
	var key := "B2_COMODIN_SHERO_DM" if uses <= 1 else "B2_COMODIN_SHERO_DM_2"
	var txt := Loc.fmt(tr(key), {"agente": GameState.agent, "aux": Metrics.aux_name()})
	# v0.3.2-core4: el tercer break cubierto por el comodín lo comenta Discipline con su propia línea (voz + DM: «lo dejo
	# pasar 10 minutos»); aquí no se repite el DM, pero el uso cuenta igual (desde el 2.º, un verbal).
	if not Discipline.comodin_break_covered():
		EventBus.ezlak_post.emit("dm:shero", "shero", txt, {"tipo": "comodin", "mention": true, "typing_s": 4.0})
	if uses > 1:
		Discipline.comodin_verbal()


func _lost() -> void:
	used = true
	EventBus.show_message.emit(tr("B2_COMODIN_LOST"), 3.0)
	call_failed.emit("", "nadie")
	_close()


# --- UI --------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ComodinUI"
	_layer.layer = 1
	_layer.visible = false
	add_child(_layer)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.92)
	sb.border_color = Color(0.93, 0.76, 0.27, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -420
	panel.offset_bottom = -250
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)
	_label = RichTextLabel.new()
	_label.name = "Texto"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_label.add_theme_font_size_override(k, 19)
	_label.custom_minimum_size = Vector2(730, 0)
	panel.add_child(_label)


## Texto del panel sin BBCode (pruebas).
func ui_text() -> String:
	return _label.get_parsed_text().replace(NBSP, " ") if _label != null else ""


func _refresh_ui() -> void:
	if _layer == null:
		return
	_layer.visible = phase != ""
	var lines: Array[String] = ["[color=#edc245]%s[/color]" % tr("B2_COMODIN_TITLE")]
	match phase:
		"aux":
			lines.append(tr("B2_COMODIN_PICK_AUX"))
			var opts: Array[String] = []
			for i in Metrics.AUX_KEYS.size():
				opts.append(_nb("[b]%d[/b] %s" % [i + 1, tr(Metrics.AUX_KEYS[i])]))
			lines.append("   ".join(PackedStringArray(opts)))
		"who", "retry":
			lines.append(tr("B2_COMODIN_PICK_WHO") if phase == "who" else Loc.fmt(tr("B2_COMODIN_RETRY"), {"s": int(ceil(retry_left))}))
			var opts2: Array[String] = []
			var names := coworkers()
			for i in names.size():
				if tried.has(names[i]):
					opts2.append("[color=#6a7682]%s[/color]" % _nb("%d %s · %s" % [i + 1, names[i], tr("B2_COMODIN_TRIED")]))
					continue
				var pr := presence_of(names[i])
				opts2.append("[b]%d[/b]%s%s%s[color=%s]●%s%s[/color]" % [i + 1, NBSP, _nb(names[i]), NBSP, str(pr.get("color", "#6a7682")), NBSP, _nb(str(pr.get("texto", "")))])
			lines.append("    ".join(PackedStringArray(opts2)))
			if anyone_active():
				lines.append("[color=#9fb4c8]%s[/color]" % tr("B2_COMODIN_ONLY_ACTIVE"))
			else:
				lines.append("[color=#ff6a5a]%s[/color]" % tr("B2_COMODIN_NOBODY" if phase == "who" else "B2_COMODIN_NOBODY_RETRY"))
		"ringing":
			lines.append(Loc.fmt(tr("B2_COMODIN_RINGING"), {"quien": calling}))
	var txt := "\n".join(PackedStringArray(lines))
	if _label.text != txt:
		_label.text = txt

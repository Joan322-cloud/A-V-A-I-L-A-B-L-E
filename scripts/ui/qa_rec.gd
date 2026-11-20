class_name QaRec
extends CanvasLayer
## Punto REC de Haime (PLAN §2 #32, DIALOGOS §4 "rec"): en 1 de cada 3 contactos aparece arriba a la
## derecha con tu puntaje de calidad en vivo (baja con cada marca de QA y con el ánimo del cliente).
## Cuando Haime te llamó, el punto te SIGUE: se despega de la esquina, deriva por el borde de la pantalla
## y muestra cuánto te queda para llegar a la sala de calibración.

var qa: QaFeedback = null
var _root: Control = null
var _dot: Panel = null
var _label: Label = null
var _score: Label = null
var _t: float = 0.0
var _last_score: int = 100
var _hold: float = 0.0
var _pos: Vector2 = Vector2.ZERO
var _was_zoomed: bool = false


func _ready() -> void:
	layer = 0  # v0.3.1 Q1 (F6): debajo de la UI principal (capa 1): la pausa y la muerte siempre encima
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dot = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.05, 0.05)
	sb.set_corner_radius_all(40)
	_dot.add_theme_stylebox_override("panel", sb)
	_dot.size = Vector2(26, 26)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dot)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.92, 0.12, 0.1))
	_label.add_theme_font_override("font", UITheme.mono())
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	_score = Label.new()
	_score.add_theme_font_size_override("font_size", 18)
	_score.add_theme_color_override("font_color", Color(0.85, 0.8, 0.8))
	_score.add_theme_font_override("font", UITheme.mono())
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_score)
	# v0.3.2-core (pasada 4 de partidas en fotos): sin borde, «HAIME TE ESPERA · CALIBRACIÓN 11:06» no se leía sobre las
	# paredes claras (la sala de calibración, el pasillo de casilleros): justo donde vas cuando te llama. Como el HUD.
	for l: Label in [_label, _score]:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.visible = false


## Puntaje de calidad del contacto en curso (100 - 17 por marca - ánimo negativo).
func live_score() -> int:
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	if cm == null or cm.tree == null:
		return _last_score
	var s := 100 - 17 * cm.tree.qa_marks.size()
	if cm.tree.animo < 0.0:
		s += int(cm.tree.animo * 0.4)
	return clampi(s, 0, 100)


func _process(delta: float) -> void:
	_t += delta
	if qa == null or Checkpoints.dying or not GameState.running:
		_root.visible = false
		return
	var vp := get_viewport().get_visible_rect().size
	var following := qa.state == QaFeedback.State.LLAMADO
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	var in_call := cm != null and cm.is_active() and cm.tree != null
	if in_call and qa.monitored:
		_last_score = live_score()
		_hold = 3.0
	elif _hold > 0.0:
		_hold -= delta
	var show := following or (qa.monitored and in_call) or _hold > 0.0
	_root.visible = show and qa.state != QaFeedback.State.SESION
	if not _root.visible:
		return
	var blink := fmod(_t, 1.0) < 0.62
	_dot.modulate.a = 1.0 if blink else 0.25
	var target := Vector2(vp.x - 230, 164)  # v0.3.1 Q1: debajo del HUD (reloj/AUX/KPIs/Hold llegan a y ≈ 154)
	var ws := get_tree().get_first_node_in_group("workstation")
	var zoomed := ws != null and bool(ws.get("zoomed")) and (ws as CanvasItem).visible
	if following:
		# Te sigue: deriva lento por el borde de arriba y baja por el lado, como un ojo que no parpadea.
		var k := fmod(_t * 0.045, 1.0)
		# v0.3.1 Q1: sin entrar en la columna del HUD de arriba a la derecha (reloj, AUX, KPIs): se pisaban los textos.
		var right := vp.x - maxf(300.0, vp.x * 0.17) - maxf(_score.get_minimum_size().x - 30.0, 0.0)
		target = Vector2(lerpf(right, vp.x * 0.4, 0.5 + 0.5 * sin(_t * 0.31)), 46 + 38 * sin(_t * 0.73) + k * 18)
		var left := qa.seconds_left()
		_label.text = "REC"  # P7: el punto ya lo dibuja _dot (salían dos)
		_score.text = "%s  %s" % [tr("P5_REC_WAITING"), Loc.mmss(maxf(left, 0.0))]
		_score.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if left < 180.0 else Color(0.9, 0.82, 0.8))
	else:
		_label.text = "REC"  # P7: el punto ya lo dibuja _dot (salían dos)
		_score.text = "%s %d  ·  %s %d/%d" % [tr("P5_REC_QUALITY"), _last_score, tr("P5_REC_FEEDBACKS"), qa.feedbacks_done(), qa.max_per_shift()]
		_score.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if _last_score < 60 else Color(0.85, 0.8, 0.8))
	# v0.3.2-core: con la PC acercada (casi toda la llamada) el sitio de la derecha queda DETRÁS del monitor y solo
	# asomaba la cola del texto («…ck QA 0/4»); y al seguirte, bajaba hasta meterse detrás de la cabecera de la PC.
	# Acercada, va fijo a la esquina de arriba a la izquierda, que está libre (los avisos van al centro).
	if zoomed:
		target = Vector2(64, 20)
	# v0.3.1 Q1: nunca encima del aviso de primera vez (con la PC acercada va arriba al centro).
	var tips := get_tree().get_first_node_in_group("agent_tips")
	var boxes: Array = get_tree().get_nodes_in_group("hud_top_box")  # v0.3.2-core: ni encima del aviso de texto del HUD
	if tips != null and tips.get("_box") != null:
		boxes.append(tips.get("_box"))
	for bx in boxes:
		var tbox := bx as Control
		if tbox != null and tbox.is_visible_in_tree():
			var tr_ := tbox.get_global_rect()
			if target.x + 260.0 > tr_.position.x and target.x - 40.0 < tr_.end.x:
				target.y = maxf(target.y, tr_.end.y + 6.0)
	# P7: que el texto de la calidad no se salga por la derecha (a 1280 px se cortaba «Feedbacks n/3»).
	var w := maxf(_score.get_minimum_size().x - 30.0, _label.get_minimum_size().x)
	target.x = clampf(target.x, 48.0, vp.x - w - 16.0)
	if zoomed != _was_zoomed:
		_was_zoomed = zoomed
		_pos = Vector2.ZERO  # salta al sitio nuevo (no cruza la pantalla por encima de la PC)
	_pos = target if _pos == Vector2.ZERO else _pos.lerp(target, minf(delta * 1.5, 1.0))
	_pos.x = minf(_pos.x, vp.x - w - 16.0)
	_dot.position = _pos + Vector2(-34, 6)
	_label.position = _pos
	_score.position = _pos + Vector2(-30, 38)

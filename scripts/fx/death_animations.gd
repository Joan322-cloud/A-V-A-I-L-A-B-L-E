class_name DeathAnimations
extends CanvasLayer
## Animaciones de muerte SIN screamer (v0.3, regla de Joan 2026-11-09 12:54): morir por Fatiga/colapso no
## es que alguien te mate, así que no hay screamer: hay una secuencia de muerte tenebrosa (visión que se
## nubla, latido, la cabeza cae, negro). Toda muerte causada por un personaje pasa por Screamers.
## Contrato (lo crea P1; P2 hace la versión final con cámara: sentado → cabeza al teclado, de pie → al suelo):
##   DeathAnimations.play_collapse(cause, detail) — corrutina; al terminar emite
##                                                 EventBus.death_animation_finished(cause).
##   DeathAnimations.duration(cause)              — duración prevista en segundos.
##   DeathAnimations.stop_all()                   — corta la animación en curso (respawn, menú).
## Checkpoints la elige cuando el asesino de la causa es "" o "fatiga" (Checkpoints.uses_screamer()).
## P1: viñeta que se cierra, pulsos oscuros al ritmo de un latido grave (sin destellos; con "reducir
## destellos" los pulsos son más suaves) y corte a negro. P2 (v0.3): además mueve la cámara del jugador
## (CollapseFx): sentado, la cabeza cae sobre el teclado; de pie, caes al suelo. 3,8 s (tabla: 3-4,5 s).
## v0.3.2 (Joan, en el documento de muertes: «la animación de muerte sale en tercera persona cuando es colapso»):
## tras THIRD_AT s en primera persona (la visión se desdobla, el latido), corte a una cámara en tercera persona: ves a
## tu agente (su modelo) desplomarse (clip "dead") mientras la cámara se acerca despacio; sigue SIN screamer.
## v0.3.2e (Joan: «ese nivel de animación … para todo»; el colapso es en tercera persona y NO tiene screamer): rehecho.
## Tercera persona desde el primer cuadro, 5,4 s, legible (las luces de la sala siguen como están + una luz suave; la
## viñeta recién se cierra en el último segundo) y actuado de cuerpo entero con los clips k32 de tu agente
## (tools/anim/clips_kills.py):
##   sentado (v_colapso_s): se marea, se aferra al borde del escritorio y empuja para enderezarse, la cabeza se le cae,
##     el torso se desploma sobre el escritorio (2,32 s), resbala de la silla (que sale rodando) y cae de costado al
##     piso (3,5 s); la mano tiembla dos veces y para;
##   de pie (v_colapso_p): se marea, la mano a la sien, da un paso y busca de dónde agarrarse, cae de rodillas
##     (2,42 s) y de cara al piso (3,3 s); la mano tiembla dos veces y para.
## Sonido: solo el cuerpo y la sala (respiración que falla, el corazón cada vez más lento, la silla, el teclado, el
## cuerpo contra el piso) y, si estabas en una llamada, el cliente que sigue ahí («¿Aló?»: por el VoiceDirector, con
## el cliente como hablante y prioridad de screamer, que es lo único que suena durante una muerte; su subtítulo sale en
## la capa de la toma, porque la tercera persona esconde el HUD: ver _room_voice y _take_sub) o, sentado en tu
## PC sin llamada, el softphone que suena. Nada grita. La cámara busca el lado despejado (rayos contra paredes y
## muebles) y sigue al cuerpo. Sin modelo de agente o sin su biblioteca: la versión de cámara en primera persona
## (CollapseFx) con la viñeta, como en v0.3.

const GROUP := "death_anim_fx"
const COLLAPSE_SECONDS := 5.4  # v0.3.2e: 4,6 s de actuación + el cierre lento (Checkpoints espera hasta 6,4 s)
const CLIP_S := 4.6
const CLOSE_AT := 4.25  # antes de esto nada tapa la escena
const CHAIR_AT := 2.76  # sentado: la silla sale rodando cuando el cuerpo resbala
const HITS_SEATED := {"escritorio": 2.32, "piso": 3.5}
const HITS_STANDING := {"rodillas": 2.42, "piso": 3.3}

var cause: String = ""
var seconds: float = COLLAPSE_SECONDS
var _done: bool = false
var _cam_fx: CollapseFx = null
var _third: Node3D = null  # escenario de la tercera persona (tu agente que cae, la cámara y su luz)
var _hidden_rig: Node3D = null
var _cam: Camera3D = null
var _sk: Skeleton3D = null
var _b_head: int = -1
var _b_pelvis: int = -1
var _cam_from: Vector3 = Vector3.ZERO
var _cam_to: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _t3: float = 0.0
var _hidden_ui: Array[CanvasLayer] = []
var _hidden_meshes: Array[MeshInstance3D] = []  # lo que quedaba pegado al lente
var _ui_muted: bool = false
var _chair: Array = []  # [[nodo, transform global de partida], …]
var _chair_tw: Tween = null
var _sub: Label = null  # el subtítulo de la toma (el del HUD está escondido mientras dura)
var _sub_serial: int = 0
static var last_info: Dictionary = {}


static func duration(_cause: String) -> float:
	return COLLAPSE_SECONDS


## Corrutina: secuencia de colapso; emite death_animation_finished(cause) al terminar.
static func play_collapse(p_cause: String, _detail: String = "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		EventBus.death_animation_finished.emit(p_cause)
		return
	var fx := DeathAnimations.new()
	fx.cause = p_cause
	fx.seconds = duration(p_cause)
	fx.layer = 20
	fx.name = "DeathAnimation"
	fx.add_to_group(GROUP)
	tree.root.add_child(fx)
	await fx._run_collapse()
	if is_instance_valid(fx) and not fx._done:
		fx._done = true
		fx.queue_free()
		Screamers.hold_black()
		EventBus.death_animation_finished.emit(p_cause)


static func stop_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		(n as DeathAnimations)._done = true
		(n as DeathAnimations)._stop_cam()
		n.queue_free()


func _stop_cam() -> void:
	if _cam_fx != null and is_instance_valid(_cam_fx):
		_cam_fx.stop()
	_cam_fx = null
	_end_third()


func _exit_tree() -> void:
	_end_third()


## Distancia libre (hasta `far` m) desde `from` hacia `dir`: paredes, divisores y muebles con colisión.
func _free(p: Player, from: Vector3, dir: Vector3, far: float) -> float:
	if p == null or not p.is_inside_tree():
		return far
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * far)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return far if hit.is_empty() else from.distance_to(hit["position"] as Vector3)


## Tercera persona: el modelo de tu agente donde está tu cuerpo, con su clip de colapso; cámara propia en el lado
## despejado y una luz suave. false si no hay modelo (el colapso sigue en primera persona).
func _start_third(p: Player) -> bool:
	if p == null or p.get_parent() == null:
		return false
	var seated := p.seated
	var own := p.get("_rig") as Node3D
	_third = Node3D.new()
	_third.name = "ColapsoTerceraPersona"
	p.get_parent().add_child(_third)
	# Donde está TU cuerpo: sentado, el cuerpo propio va 17-20 cm detrás del origen del jugador (la silla).
	var back := p.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else Vector3.BACK
	_third.global_position = p.global_position + (back * 0.2 if seated else Vector3.ZERO)
	_third.rotation.y = p.rotation.y
	var rig := CharacterRig.attach(_third, CharacterRig.agent_model(GameState.agent), 1.72)
	if rig == null:
		_third.queue_free()
		_third = null
		return false
	var clip := "v_colapso_s" if seated else "v_colapso_p"
	var acted := false
	if rig.animator != null:
		var lib_path := "res://assets/anim/%s_kills.res" % CharacterRig.agent_model(GameState.agent)
		if ResourceLoader.exists(lib_path):
			var lib := load(lib_path) as AnimationLibrary
			if lib != null and lib.has_animation(clip):
				KillMoves.fix_jaw(lib, _third)
				rig.animator.add_library("k32", lib)
				rig.animator.look_enabled = false  # la cabeza la lleva el clip (se le cae, la levanta, queda en el piso)
				rig.play("k32/" + clip, false, 1.0)
				# sin mezcla: el primer cuadro de la toma ya es la pose del clip (con la mezcla de 0,15 s del animador se
				# veía un cuadro al agente de pie al lado de su silla)
				var apl := rig.animator.player
				if apl != null and apl.has_animation("k32/" + clip):
					apl.play("k32/" + clip, 0.0, 1.0)
					apl.seek(0.0, true)
				acted = true
	if not acted:
		rig.play("dead", false, 0.75, ["hunch"])
	if own != null and own.visible:
		own.visible = false
		_hidden_rig = own
	_sk = VitzoFusion._skeleton(rig)
	if _sk != null:
		_b_head = VitzoFusion._bone(_sk, ["head", "Head"])
		_b_pelvis = VitzoFusion._bone(_sk, ["pelvis", "hips", "Hips", "spine_01", "spine"])
	# --- la cámara: en el lado despejado, a media altura, mirando el cuerpo
	var fwd := -back
	var right := p.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length() > 0.05 else Vector3.RIGHT
	var origin := _third.global_position
	var chest := origin + Vector3(0, 1.0 if seated else 1.2, 0)
	# sentado cae hacia SU IZQUIERDA: se mira desde atrás y a su izquierda (el pasillo), si no desde el otro lado;
	# de pie cae hacia ADELANTE: tres cuartos de frente.
	var dirs: Array = [(-fwd * 0.75 - right).normalized(), (-fwd * 0.75 + right).normalized(), (-fwd - right * 0.35).normalized(), (-fwd + right * 0.35).normalized()]
	if not seated:
		dirs = [(fwd + right * 0.8).normalized(), (fwd - right * 0.8).normalized(), (-fwd * 0.4 + right).normalized(), (-fwd * 0.4 - right).normalized()]
	var want := 2.5 if seated else 3.0
	var best_d: Vector3 = dirs[0]
	var best_free := -1.0
	for d in dirs:
		var free := _free(p, chest, d as Vector3, want + 0.35)
		if free >= want + 0.3:
			best_d = d
			best_free = free
			break
		if free > best_free:
			best_free = free
			best_d = d
	var dist := clampf(best_free - 0.3, 0.9, want)
	# donde queda el cuerpo: sentado, 0,6 m a su izquierda; de pie, 0,75 m adelante
	var rest := origin + (-right * 0.6 if seated else fwd * 0.75) + Vector3(0, 0.25, 0)
	_cam_from = chest + best_d * dist + Vector3(0, 0.3, 0)
	var back_d := _cam_from - rest
	back_d.y = 0.0
	back_d = back_d.normalized() if back_d.length() > 0.05 else best_d
	_cam_to = rest + back_d * maxf(minf(dist * 0.8, _free(p, rest + Vector3(0, 0.5, 0), back_d, dist) - 0.3), 0.9) + Vector3(0, 0.7, 0)
	_look = chest
	_cam = Camera3D.new()
	_cam.name = "CamaraColapso"
	_cam.fov = 56.0
	_third.add_child(_cam)
	_cam.global_position = _cam_from
	_cam.look_at(_look, Vector3.UP)
	_cam.make_current()
	_t3 = 0.0
	# --- la luz: suave, del lado de la cámara y arriba; sin sombras (Modo liviano la aguanta), el ánimo del piso no la toca
	var key := OmniLight3D.new()
	key.name = "LuzColapso"
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 1.25
	key.omni_range = 6.0
	key.omni_attenuation = 1.2
	key.shadow_enabled = false
	key.set_meta("no_mood", true)
	_third.add_child(key)
	key.global_position = chest + best_d * minf(dist * 0.6, 1.5) + Vector3(0, 0.95, 0)
	# --- lo que tapa: el HUD y la PC abierta (vuelven al terminar)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l == self or l.layer >= 19 or not l.visible or l.is_in_group(Screamers.HOLD_GROUP) or l.name in ["Cinematica", "Subtitulos"]:
			continue
		l.visible = false
		_hidden_ui.append(l)
	# sin pings de Ezlaki ni clics de la PC encima (como en los screamers); vuelve al terminar
	var ui_bus := AudioServer.get_bus_index("UI")
	if ui_bus >= 0 and not AudioServer.is_bus_mute(ui_bus):
		AudioServer.set_bus_mute(ui_bus, true)
		_ui_muted = true
	# --- la silla (sentado): las piezas que están bajo tu cuerpo ruedan juntas cuando resbalas
	if seated and FloorBase.active != null:
		for n in FloorBase.active.find_children("Silla*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var d2 := mi.global_position - p.global_position
			d2.y = 0.0
			if d2.length() < 0.6 and mi.is_visible_in_tree():
				_chair.append([mi, mi.global_transform])
		# v0.3.2 (integración): la silla ENTERA. Solo se llevaba el asiento («Silla*»): el respaldo y la base de ruedas se
		# quedaban donde estaban y el asiento salía rodando solo, en el aire (en Media/Alta, con sus apoyabrazos). Las
		# mismas piezas que KillMoves._chair_parts: el respaldo y la base (con su estrella) del mismo mueble.
		for e in _chair.duplicate():
			var par := (e[0] as Node).get_parent()
			if par == null:
				continue
			for nm in ["Respaldo", "Base"]:
				var part := par.get_node_or_null(nm) as Node3D
				if part == null or not part.is_visible_in_tree() or part.global_position.distance_to((e[0] as Node3D).global_position) > 0.9:
					continue
				var seen := false
				for e2 in _chair:
					if e2[0] == part:
						seen = true
				if not seen:
					_chair.append([part, part.global_transform])
	_clear_view([chest, rest])
	last_info = {"cause": cause, "tercera_persona": true, "agente": GameState.agent, "anim": clip if acted else "dead", "sentado": seated,
		"silla": _chair.size(), "camara_m": dist, "luz": true, "despejado": _hidden_meshes.size()}
	return true


## Lo que queda pegado al lente (el respaldo de un monitor, una silla, un mueble chico a menos de 1,35 m de la cámara
## y dentro del cuadro hacia el cuerpo) se esconde mientras dura la toma y vuelve al terminar. Nunca personas (mallas
## con esqueleto) ni la silla que rueda.
func _clear_view(targets: Array) -> void:
	if FloorBase.active == null:
		return
	var cams: Array[Vector3] = [_cam_from, _cam_to]
	for n in FloorBase.active.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.skin != null:
			continue
		var mine := false
		for e in _chair:
			if e[0] == mi:
				mine = true
		if mine:
			continue
		var bb := mi.global_transform * mi.get_aabb()
		if bb.get_longest_axis_size() > 2.4:
			continue
		var c := bb.get_center()
		if c.distance_to(_cam_from) > 1.35 and c.distance_to(_cam_to) > 1.35:
			continue
		var cut := false
		for cp in cams:
			for tg in targets:
				var side := ((tg as Vector3) - cp).cross(Vector3.UP).normalized()
				for k in [-1.2, -0.6, 0.0, 0.6, 1.2]:
					if bb.intersects_segment(cp, (tg as Vector3) + side * float(k)):
						cut = true
		if cut:
			mi.visible = false
			_hidden_meshes.append(mi)


## La silla sale rodando hacia atrás y a su derecha (el cuerpo cae a su izquierda), girando; frena sola.
func _chair_roll(by: Vector3, yaw: float, t: float) -> void:
	if _chair.is_empty():
		return
	var pivot := Vector3.ZERO
	for e in _chair:
		pivot += (e[1] as Transform3D).origin
	pivot /= float(_chair.size())
	pivot.y = 0.0
	_chair_tw = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_chair_tw.tween_method(func(u: float) -> void:
		var xf := Transform3D(Basis(Vector3.UP, yaw * u), pivot + by * u) * Transform3D(Basis.IDENTITY, -pivot)
		for e in _chair:
			if is_instance_valid(e[0]):
				(e[0] as Node3D).global_transform = xf * (e[1] as Transform3D), 0.0, 1.0, maxf(t, 0.05))
	last_info["silla_rueda"] = true


func _end_third() -> void:
	if _chair_tw != null and _chair_tw.is_valid():
		_chair_tw.kill()
	_chair_tw = null
	for e in _chair:
		if is_instance_valid(e[0]):
			(e[0] as Node3D).global_transform = e[1] as Transform3D  # la silla vuelve a su sitio (reapareces sentado en ella)
	_chair.clear()
	for l in _hidden_ui:
		if is_instance_valid(l):
			l.visible = true
	_hidden_ui.clear()
	if _ui_muted:
		var ui_bus := AudioServer.get_bus_index("UI")
		if ui_bus >= 0:
			AudioServer.set_bus_mute(ui_bus, false)
		_ui_muted = false
	for mi in _hidden_meshes:
		if is_instance_valid(mi):
			mi.visible = true
	_hidden_meshes.clear()
	_cam = null
	_sk = null
	if _third != null and is_instance_valid(_third):
		_third.queue_free()
		var p := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
		if p != null and p.camera != null:
			p.camera.make_current()
	_third = null
	if _hidden_rig != null and is_instance_valid(_hidden_rig):
		_hidden_rig.visible = true
	_hidden_rig = null


## La cámara sigue al cuerpo (entre la cabeza y la cadera) y se acerca despacio hacia donde queda tendido.
func _process(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam) or not _cam.is_inside_tree():
		return
	_t3 += delta
	var u := smoothstep(0.0, 1.0, clampf(_t3 / maxf(seconds - 0.3, 0.5), 0.0, 1.0))
	if _sk != null and is_instance_valid(_sk) and _b_head >= 0 and _b_pelvis >= 0:
		var hd := _sk.global_transform * _sk.get_bone_global_pose(_b_head).origin
		var pv := _sk.global_transform * _sk.get_bone_global_pose(_b_pelvis).origin
		_look = _look.lerp(pv.lerp(hd, 0.55), 1.0 - exp(-delta * 4.5))
	_cam.global_position = _cam_from.lerp(_cam_to, u)
	_cam.fov = lerpf(56.0, 49.0, u)
	if _cam.global_position.distance_to(_look) > 0.05:
		_cam.look_at(_look, Vector3.UP)


## Un sonido de la sala a los `at` s (si la animación sigue).
func _snd_at(at: float, slot: String, db: float, pitch: float = 1.0, max_s: float = 0.0) -> void:
	get_tree().create_timer(maxf(at, 0.01), false).timeout.connect(func() -> void:
		if _done or not is_inside_tree():
			return
		var ap := _snd(slot, db, pitch)
		if ap != null and max_s > 0.0:
			var wr: WeakRef = weakref(ap)  # el reproductor se libera solo al terminar: no se captura el nodo
			get_tree().create_timer(max_s, false).timeout.connect(func() -> void:
				var a := wr.get_ref() as AudioStreamPlayer
				if a != null and is_instance_valid(a):
					a.stop()
					a.queue_free()))


const ALO_SLOT := "voces/clientes/colapso_alo"


## Si estabas en una llamada, el cliente sigue ahí («¿Aló?»); sentado en tu PC sin llamada, el softphone suena.
func _room_voice(p: Player, at: float) -> void:
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	var on_call := cm != null and cm.is_active() and str(cm.current.get("canal", "")) == "llamada"
	last_info["llamada"] = on_call
	if on_call:
		if not VoiceDirector.subtitle_shown.is_connected(_take_sub):
			VoiceDirector.subtitle_shown.connect(_take_sub)
		get_tree().create_timer(at, false).timeout.connect(func() -> void:
			if _done or not is_inside_tree():
				return
			# v0.3.2 (integración): por el VoiceDirector, como toda voz. Mientras dura una muerte el director solo deja
			# pasar la prioridad SCREAMER y los subtítulos de quien te mata; el colapso no tiene asesino, así que esta
			# línea ES la voz de la toma y entra como SCREAMER: suena ella con su subtítulo y nadie más (un subtítulo
			# suelto por EventBus se descartaba con las demás voces y la línea quedaba sin texto). El idioma lo resuelve
			# AudioManager.voice_path (voces/clientes/en/…; si falta, la ES con el subtítulo EN) y el nivel, la tabla
			# de ganancias (audio_index.json: 0 dB sobre un archivo de −23 LUFS: lejos, 7 dB bajo un cliente normal, pero
			# por encima de los golpes del cuerpo; a −4 dB se perdía entre ellos). Se corta sola al reaparecer o en el menú.
			VoiceDirector.say(ALO_SLOT, VoiceDirector.P.SCREAMER, "cliente", Callable(), {"bus": "Auricular", "text": tr("K2_COLAPSO_ALO"), "seconds": 2.6}))
	elif p != null and p.seated and GameState.logged_in:
		_snd_at(at + 1.15, "sfx/telefono_timbre", -15.0, 1.0, 1.5)
		last_info["softphone"] = true


## El subtítulo de la toma. La tercera persona esconde el HUD (y con él su renglón de subtítulos): mientras dura, el
## texto que muestra el VoiceDirector (en una muerte solo pasa la línea del cliente) sale en esta misma capa, en el
## sitio del HUD, un punto más grande y con filo oscuro (es lo único escrito en la toma y va sobre el piso iluminado). Sin la tercera persona (la
## caída en primera persona de v0.3) el HUD sigue a la vista y lo muestra él. Respeta Opciones → Subtítulos.
func _take_sub(_speaker: String, text: String, secs: float) -> void:
	if _done or not is_inside_tree():
		return
	if _sub == null:
		if text == "" or _hidden_ui.is_empty() or not bool(Loc.get_setting("subtitles", true)):
			return
		_sub = UITheme.label("", 24, UITheme.TEXT)
		_sub.name = "SubtituloToma"
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_sub.offset_left = -450.0
		_sub.offset_right = 450.0
		_sub.offset_top = -120.0
		_sub.offset_bottom = -90.0
		_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_sub.add_theme_constant_override("outline_size", 8)
		add_child(_sub)
	_sub.text = text
	_sub_serial += 1
	if text != "" and secs > 0.0:
		var mine := _sub_serial
		get_tree().create_timer(secs, false, false, true).timeout.connect(func() -> void:
			if is_instance_valid(_sub) and _sub_serial == mine:
				_sub.text = "")


func _run_collapse() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(1, 1, 1, 1)
	shade.material = _vignette_material()
	add_child(shade)
	var mat := shade.material as ShaderMaterial
	mat.set_shader_parameter("close", 0.0)
	mat.set_shader_parameter("pulse", 0.0)
	last_info = {"cause": cause, "tercera_persona": false}
	if p != null:
		p.set_cinematic(true)
	if not _start_third(p):
		# sin modelo: la caída de la cámara en primera persona (v0.3) y la viñeta desde el principio
		_cam_fx = CollapseFx.start(p, seconds)
		create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("close", v), 0.0, 1.0, seconds * 0.9)
		_snd("sfx/respiracion", -2.0, 0.82)
		await _wait(seconds)
		return
	var seated := bool(last_info.get("sentado", false))
	# --- el cuerpo: respira mal, el corazón cada vez más lento y más lejos
	# (niveles de sala: a -3 dB estos sonidos, pensados para la primera persona, pegaban en el limitador del bus)
	_snd("sfx/respiracion", -12.0, 0.84)
	_snd_at(0.25, "sfx/latido_lento", -13.0, 0.95)
	_snd_at(1.15, "sfx/latido_lento", -16.0, 0.88)
	_snd_at(2.5, "sfx/latido_lento", -20.0, 0.8)
	# --- la sala: lo que el cuerpo golpea
	if seated:
		_snd_at(1.0, "sfx/silla_crujido_largo", -14.0, 1.0, 1.2)
		_snd_at(float(HITS_SEATED["escritorio"]), "ambiente/teclados_lejanos", -10.0, 0.7, 0.5)
		_snd_at(float(HITS_SEATED["escritorio"]), "sfx/caida_cuerpo", -16.0, 1.35)
		_snd_at(float(HITS_SEATED["piso"]), "sfx/caida_cuerpo", -8.0, 0.9)
		get_tree().create_timer(CHAIR_AT, false).timeout.connect(func() -> void:
			if _done or not is_inside_tree() or p == null or not is_instance_valid(p):
				return
			var b := p.global_transform.basis
			_chair_roll(b.z * 0.95 + b.x * 0.4, 1.15, 1.5)
			if not _chair.is_empty():
				_snd("sfx/kill_silla_giro", -12.0, 0.95))
	else:
		_snd_at(float(HITS_STANDING["rodillas"]), "sfx/caida_cuerpo", -13.0, 1.3)
		_snd_at(float(HITS_STANDING["piso"]), "sfx/caida_cuerpo", -8.0, 0.9)
	_room_voice(p, 2.55)  # el cliente oyó el golpe contra el escritorio
	await _wait(CLOSE_AT)
	if _done:
		return
	# --- el cierre lento: la viñeta se cierra recién ahora
	var close_s := maxf(seconds - CLOSE_AT - 0.12, 0.3)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_method(func(v: float) -> void: mat.set_shader_parameter("close", v), 0.0, 1.0, close_s)
	await _wait(seconds - CLOSE_AT)
	if _done:
		return
	mat.set_shader_parameter("close", 1.0)
	_end_third()


func _snd(slot: String, db: float, pitch: float) -> AudioStreamPlayer:
	var path := AudioManager.resolve(slot)
	if path == "":
		return null
	var ap := AudioStreamPlayer.new()
	ap.stream = load(path) as AudioStream
	ap.bus = "Sala"
	ap.volume_db = db
	ap.pitch_scale = pitch
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)
	return ap


## Los temporizadores de esta secuencia se detienen con la pausa (process_always = false): la animación, la cámara, los
## sonidos y el cierre quedan congelados juntos y siguen juntos al volver.
func _wait(s: float) -> void:
	if s <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(s, false).timeout


func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float close = 0.0;   // 0 = visión normal, 1 = negro total
uniform float pulse = 0.0;   // oscurecimiento del latido
void fragment() {
	float d = length(UV - 0.5) * 1.6;
	float edge = mix(1.4, -0.2, close);
	float v = smoothstep(edge - 0.35, edge, d);
	float a = clamp(v + pulse + close * close * 0.6, 0.0, 1.0);
	COLOR = vec4(0.02, 0.0, 0.0, a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

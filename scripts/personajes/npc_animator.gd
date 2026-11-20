class_name NpcAnimator
extends Node
## v0.3.2-anim: animación de los personajes con AnimationTree (clips de tools/anim/anim_gen.py, hechos en Blender
## y guardados en assets/anim/<slug>.res como biblioteca "a32" del AnimationPlayer del GLB).
##
## Máquina de estados (tree_root, una por modelo y compartida entre instancias):
##   loco      BlendSpace2D (x = marcha 0 quieto · 1 caminar · 2 rápido · 3 correr · 4 sprint, y = giro en el lugar
##             -1..1) → TimeScale. El punto 0 es un Transition con las variantes de idle (respiración y cambio de peso,
##             mirar alrededor, mirar la hora, brazos cruzados) que van rotando solas. Todos los ciclos duran 1 s y van
##             en fase (sync): la marcha y la cadencia salen de la VELOCIDAD MEDIDA del nodo (stride del clip en metros
##             × cadencia = velocidad → los pies no patinan).
##   sit_down → seated → stand_up   (seated = Transition: sentado, tecleando, teléfono, leyendo, cansado…)
##   act       Transition con todo lo demás (gestos, baile, DJ, presentación, clips viejos del GLB: screamers, dead…)
## Transiciones de 0,15-0,3 s. Mirada: LookAtModifier3D en la cabeza hacia la cámara cuando tiene sentido.
## Hablar: cuando el personaje dice una línea (VoiceDirector.subtitle_shown / line_started / finished si existe el
## autoload; si no, EventBus.subtitle) el animador reacciona solo: de pie y quieto elige un gesto de conversación según
## el personaje y la intensidad (talk / open_hands / point / present_*), sentado pasa a sit_talk, y la mandíbula se
## mueve con sílabas moduladas por el volumen del bus de voces (sin efectos ni buses nuevos; apagado en Modo liviano).
## Los guiones no cambian; un gesto pedido a mano con play() (slam_table, lean_in, haime_lean…) siempre manda.
## Rendimiento: el árbol avanza a mano (callback MANUAL). Cerca y a la vista (< 12 m) avanza en cada fotograma, igual
## que el AnimationPlayer de antes; más lejos baja la frecuencia (30 Hz · 22 m: 15 · 35 m o fuera de cámara: 6). Un
## gesto pedido por guion (estado act: screamers, muertes, coreografías) o una pose congelada (speed 0) avanzan
## SIEMPRE en cada fotograma: hay código (kills) que retoca huesos encima de la pose y cuenta con que la animación la
## vuelva a escribir en cada cuadro. Modo liviano: 30 Hz cerca, la mitad lejos y, además, un cupo por fotograma
## (LIGHT_BUDGET animadores, por turnos; los que están pegados a la cámara siempre): el costo por cuadro queda acotado
## aunque el juego vaya a 4 fps, y es menor que el de los AnimationPlayer de v0.3.1. Sin mirada ni mandíbula lejos ni
## en Modo liviano; IK solo horneado.
## API: la misma que CharacterRig.play(nombre, loop, speed, alternativas) — los guiones no cambian.

const LIB := "a32"
const ANIM_DIR := "res://assets/anim/"
const XF := 0.25
## Cadencia nominal (ciclos/s) de cada punto de marcha; el stride (m/ciclo) viene de la biblioteca × escala.
const GAIT_KEYS: Array[String] = ["", "walk", "walk_brisk", "run", "sprint"]
const CADENCE: Array[float] = [0.0, 0.95, 1.1, 1.35, 1.6]
## Tope de marcha según lo que pide el guion (caminar a 3,9 m/s sigue siendo "caminar", con pasos rápidos).
const CAP := {"walk": 2.4, "run": 3.4, "sprint": 4.0, "idle": 4.0}
const SEATED: Array[String] = ["sit", "type", "phone", "read", "bored", "tired_nod", "rub_eyes", "yawn", "pen_tap", "haime_lean", "sit_talk"]
const IDLES: Array[String] = ["idle", "idle_look", "idle_watch", "idle_arms"]
## Gestos de pie que viven en el punto "quieto" del BlendSpace (variantes de idle y de conversación).
const STAND_EXTRA: Array[String] = ["present_a", "present_b", "open_hands", "talk", "point"]
const ALIAS := {"sit_type": "type", "idle_sit": "sit", "stand": "idle"}
const TURN_RATE := 1.2  # rad/s del clip de giro a escala 1 (dos pasitos de 0,6 rad por segundo)

## Por personaje: qué clip va en cada punto de marcha / variantes de idle y sentado / sustituciones.
const PERSONA := {
	# Shero: camina enojado y, a su velocidad de ronda (3,9 m/s), va al trote furioso de zancada larga (run_angry); en
	# persecución, sprint. Cadencias propias: mide 2,2 m, sus pasos son largos y pesados, no rápidos.
	"shero": {"gait": {"walk": "walk_angry", "walk_brisk": "run_angry", "run": "sprint"}, "cadence": [0.0, 0.95, 1.15, 1.4, 1.8],
		"idles": ["idle_arms", "idle", "idle_look"], "map": {},
		"talk": ["talk", "open_hands"], "talk_hard": ["point"]},
	"grasa": {"gait": {"walk": "walk_angry", "walk_brisk": "run_angry", "run": "sprint"}, "cadence": [0.0, 0.95, 1.15, 1.4, 1.8],
		"idles": ["idle", "idle_look"], "map": {}},
	"trainer": {"idles": ["present_a", "idle", "present_b", "open_hands"], "map": {"stare_camera": "terror"},
		"talk": ["present_a", "talk", "present_b", "open_hands"], "talk_hard": ["point"]},
	"haime": {"seated": ["sit", "pen_tap", "sit", "pen_tap"], "idles": ["idle", "idle_arms"], "map": {}, "talk": ["talk"],
		"talk_seated_hard": "haime_lean"},
	"rasec": {"map": {"dj": "dj", "karaoke": "karaoke"}, "dj": ["dj", "dance"], "idles": ["idle", "idle_look"]},
	# Don Fermín: su idle es el de guardia (pulgar en el cinturón, linterna colgando), idle_look es el barrido con la
	# linterna; «hunch» (revisar la mochila) es su clip de inclinarse a alumbrar adentro; al hablar hace pasar con la mano.
	"guardia_fermin": {"idles": ["idle", "idle_look", "idle_watch"], "map": {"hunch": "inspect"}, "talk": ["talk"], "talk_hard": ["point"]},
	# tópico y cafetería: cada uno tiene su manera de estar parado y de hablar (clips propios con el mismo nombre)
	"enfermera": {"idles": ["idle", "idle_look"], "map": {}, "talk": ["talk"]},
	"enfermero": {"idles": ["idle", "idle_look"], "map": {}, "talk": ["talk"]},
	"marleny": {"idles": ["idle"], "map": {}, "talk": ["talk"]},
	"vitzo": {"idles": ["idle"], "map": {}},
	"perrito_rta": {"idles": ["idle"], "map": {}},
}
## Variantes de cansancio al estar sentado (agentes de madrugada).
const TIRED: Array[String] = ["tired_nod", "rub_eyes", "yawn"]
## Qué carpeta / hablante de los subtítulos es cada modelo (VoiceDirector.say(…, hablante) / EventBus.subtitle(hablante, …)).
## Los agentes responden además a su nombre («[Marko] …» con la carpeta genérica "comp").
const SPEAKERS := {"shero": ["shero"], "trainer": ["trainer", "trainer_amable"], "haime": ["haime", "qa"], "rasec": ["rasec", "tm"],
	"mentor": ["mentor"], "guardia_fermin": ["fermin", "guardia"], "enfermero": ["enfermero", "topico"], "enfermera": ["enfermera", "topico"],
	"vitzo": ["vitzo"], "om": ["om"], "marleny": ["marleny"], "papayala": ["papayala"], "grasa": ["grasa"], "perrito_rta": ["rta"]}
const JAW_MAX_DIST := 14.0
## Apertura de la mandíbula con la voz, en grados (> 0 = el mentón BAJA). Medido en primeros planos de los modelos: 4° los
## labios apenas se separan, 8° boca abierta, 12° boca bien abierta, 24° la mandíbula desencajada de los screamers.
const JAW_TALK_DEG := 9.0
const JAW_HARD_DEG := 13.0
## Modo liviano: cuántos animadores "de ambiente" avanzan como máximo por fotograma (se turnan).
const LIGHT_BUDGET := 6

## Perfil (escenario animcosto): microsegundos gastados por los animadores y cuántos avanzaron el árbol.
static var prof_on: bool = false
static var prof_usec: int = 0
static var prof_ticks: int = 0
static var _rr_frame: int = -1
static var _rr_cursor: int = 0

static var _roots: Dictionary = {}
static var _all: Array = []  ## animadores vivos (para saber quién habla)
static var _hub: SpeechHub = null

var slug: String = ""
var player: AnimationPlayer = null
var tree: AnimationTree = null
var skeleton: Skeleton3D = null
var body: Node3D = null  ## el nodo que se mueve (se mide su velocidad)
var unit_m: float = 1.0  ## metros por unidad del GLB (escala del modelo)
var tired: float = 0.0  ## 0..1: los agentes cansados cabecean, se frotan los ojos, bostezan
## API pública estable: `false` = este personaje no gira la cabeza hacia la cámara (lo usa el doble del espejo del baño,
## fx/mirror_view.gd: la cámara del jugador está dentro de su propia cabeza). Se puede cambiar en cualquier momento.
var look_enabled: bool = true
var auto_transitions: bool = true  ## sentarse/pararse con su clip si el guion pasa de pie a sentado
var current: String = ""  ## lo que pidió el guion (nombre original)
var state: String = ""  ## estado del árbol (loco/seated/act/sit_down/stand_up)
var sub: String = ""  ## clip dentro del estado

var _lib: AnimationLibrary = null
var _strides: Array[float] = [0.0, 1.2, 1.4, 2.0, 2.5]
var _cadence: Array = CADENCE  ## ciclos/s nominales por punto de marcha (el perro trae los suyos en la biblioteca)
var _gait_cap: float = 2.4
var _gait_min: float = 0.0
var _req_speed: float = 1.0
var _b: float = 0.0
var _turn: float = 0.0
var _v: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _last_yaw: float = 0.0
var _dsum: float = 0.0
var _ysum: float = 0.0
var _tsum: float = 0.0
var _yaw_rate: float = 0.0
var _age: float = 0.0
var _acc: float = 0.0
var _variant_t: float = 8.0
var _oneshot_left: float = 0.0
var _seat_base: String = "sit"
var _look: LookAtModifier3D = null
var _look_target: Node3D = null
var _look_w: float = 0.0
var _rng := RandomNumberGenerator.new()
var _idles: Array = IDLES
var _seat_pool: Array = []
var _persona: Dictionary = {}
var _tick_interval: float = 0.0
var _unit_ok: bool = false
var _desynced: bool = false
var _raw: bool = false  ## reproduciendo un clip de otra biblioteca directo en el AnimationPlayer
var _talking: bool = false
var _talk_mode: String = ""  ## "seated" · "stand" · "jaw" (solo mandíbula: va caminando o el guion tiene un gesto puesto)
var _talk_n: int = 0
var _speak_until_ms: int = 0  ## este animador en particular (un compañero cualquiera: lo elige el hub por cercanía)
var _speak_hard: bool = false
var _jaw: int = -1
var _jaw_base: Quaternion = Quaternion.IDENTITY
var _jaw_axis: Vector3 = Vector3.RIGHT
var _jaw_open: float = 0.0
var _jaw_rest: Quaternion = Quaternion.IDENTITY
var _jaw_w: float = 0.0  ## 0 = la mandíbula del clip · 1 = la de la voz (la reemplaza, no se suma)
var _jaw_dirty: bool = false
var _clock: float = 0.0
var _keys: Array = []
var _shot_left: float = 0.0  ## gesto de un solo ciclo en curso (play(gesto, false)): al terminar vuelve solo
var _shot_back: String = "idle"
var _last_variant: String = ""  ## última variante de idle que salió (no se repite dos veces seguidas)
var _chair_ev: String = ""  ## "sit_down" / "stand_up" pedido: la silla se mueve cuando el clip arranca
var _jolt_left: float = 0.0  ## golpe pendiente en la mesa (slam_table, haime_lean): segundos hasta el impacto


## Crea el animador si existe assets/anim/<slug>.res. `scene` = raíz del GLB instanciado; `p_body` = nodo que se mueve.
static func attach(scene: Node3D, p_slug: String, p_body: Node3D, ap: AnimationPlayer) -> NpcAnimator:
	if ap == null or not ResourceLoader.exists(ANIM_DIR + p_slug + ".res"):
		return null
	var lib := load(ANIM_DIR + p_slug + ".res") as AnimationLibrary
	if lib == null:
		return null
	var sk: Skeleton3D = null
	for c in scene.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	var a := NpcAnimator.new()
	a.name = "Animador"
	a.slug = p_slug
	a.player = ap
	a.skeleton = sk
	a.body = p_body
	a._lib = lib
	a.unit_m = absf(scene.scale.x)
	if not ap.has_animation_library(LIB):
		ap.add_animation_library(LIB, lib)
	a._setup(scene)
	scene.add_child(a)
	return a


func _setup(scene: Node3D) -> void:
	_rng.seed = hash(slug + str(get_instance_id()))
	_persona = PERSONA.get(slug, {})
	if slug.begins_with("agente_"):
		tired = 0.6
	_idles = _persona.get("idles", IDLES).filter(func(n): return _lib.has_animation(n))
	if _idles.is_empty():
		_idles = ["idle"]
	var loco: Dictionary = _lib.get_meta("loco", {})
	var cad: Array = _lib.get_meta("cadence", [])
	if cad.size() == 5:
		_cadence = cad
	if _persona.has("cadence"):
		_cadence = _persona["cadence"]
	for i in range(1, 5):
		var key := _gait_clip(GAIT_KEYS[i])
		_strides[i] = float(loco.get(key, loco.get(GAIT_KEYS[i], _strides[i])))
	tree = AnimationTree.new()
	tree.name = "Arbol"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = false
	scene.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.tree_root = _root_for(slug, player, _lib, _persona)
	player.stop()
	player.active = false
	tree.active = true
	tree.set("parameters/loco/ts/scale", 1.0)
	_variant_t = _rng.randf_range(3.0, 14.0)
	if skeleton != null:
		_jaw = skeleton.find_bone("jaw")
		if _jaw >= 0:
			_jaw_axis = (skeleton.get_bone_global_rest(_jaw).basis.orthonormalized().inverse() * Vector3.RIGHT).normalized()
			_jaw_rest = skeleton.get_bone_rest(_jaw).basis.get_rotation_quaternion()
	_add_look()


func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)
	if _hub == null or not is_instance_valid(_hub):
		_hub = SpeechHub.new()
		_hub.name = "NpcSpeechHub"
		get_tree().root.add_child.call_deferred(_hub)


func _exit_tree() -> void:
	_all.erase(self)


## clip del punto de marcha (Shero: el caminar enojado ocupa los puntos de caminar)
func _gait_clip(key: String) -> String:
	var g: Dictionary = _persona.get("gait", {})
	var n := str(g.get(key, key))
	return n if _lib.has_animation(n) else key


static func _anim_node(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = StringName(clip)
	return n


## Árbol compartido por modelo (los parámetros viven en cada AnimationTree).
static func _root_for(p_slug: String, ap: AnimationPlayer, lib: AnimationLibrary, persona: Dictionary) -> AnimationNodeStateMachine:
	if _roots.has(p_slug):
		return _roots[p_slug]
	var sm := AnimationNodeStateMachine.new()
	# --- loco
	var lt := AnimationNodeBlendTree.new()
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(0, -1)
	bs.max_space = Vector2(4, 1)
	bs.sync = true
	var idles := AnimationNodeBlendTree.new()
	var iv := AnimationNodeTransition.new()
	iv.xfade_time = 0.6
	var idle_names: Array = []
	for n in IDLES + STAND_EXTRA:
		if lib.has_animation(n) and not idle_names.has(n):
			idle_names.append(n)
	for i in idle_names.size():
		iv.add_input(idle_names[i])
		idles.add_node(idle_names[i], _anim_node(LIB + "/" + idle_names[i]), Vector2(0, i * 80))
	idles.add_node("iv", iv, Vector2(300, 0))
	for i in idle_names.size():
		idles.connect_node("iv", i, idle_names[i])
	idles.connect_node("output", 0, "iv")
	# Godot 4.7: cada punto lleva nombre (sin él avisa «No name provided» en cada arranque). Se nombran con su índice,
	# que es lo que ya usaban las rutas de parámetros (parameters/loco/bs/0/iv/… = las variantes de idle).
	bs.add_blend_point(idles, Vector2(0, 0), -1, &"0")
	var g: Dictionary = persona.get("gait", {})
	for i in range(1, 5):
		var key := GAIT_KEYS[i]
		var clip := str(g.get(key, key))
		if not lib.has_animation(clip):
			clip = key
		if not lib.has_animation(clip):  # el perro: sin trote ni sprint propios
			clip = {"walk_brisk": "walk", "sprint": "run"}.get(clip, "walk")
		bs.add_blend_point(_anim_node(LIB + "/" + clip), Vector2(i, 0), -1, StringName(str(i)))
	if lib.has_animation("turn_l"):
		bs.add_blend_point(_anim_node(LIB + "/turn_l"), Vector2(0, 1), -1, &"5")
		bs.add_blend_point(_anim_node(LIB + "/turn_r"), Vector2(0, -1), -1, &"6")
	lt.add_node("bs", bs, Vector2(0, 0))
	lt.add_node("ts", AnimationNodeTimeScale.new(), Vector2(250, 0))
	lt.connect_node("ts", 0, "bs")
	lt.connect_node("output", 0, "ts")
	sm.add_node("loco", lt, Vector2(0, 0))
	# --- sentado
	sm.add_node("seated", _switch(lib, ap, SEATED, "sv", 0.3), Vector2(400, 0))
	for n in ["sit_down", "stand_up"]:
		if lib.has_animation(n):
			sm.add_node(n, _anim_node(LIB + "/" + n), Vector2(200, -120 if n == "sit_down" else 120))
	# --- todo lo demás (gestos nuevos + clips viejos del GLB)
	var others: Array = []
	for n in lib.get_animation_list():
		var s := str(n)
		if not SEATED.has(s) and not s in ["sit_down", "stand_up", "walk", "walk_brisk", "run", "sprint", "turn_l", "turn_r"] and not IDLES.has(s):
			others.append(LIB + "/" + s)
	for n in ap.get_animation_list():
		var s := str(n)
		if not s.contains("/") and not lib.has_animation(s):
			others.append(s)
	sm.add_node("act", _switch_raw(others, "av", 0.25), Vector2(200, 240))
	# --- transiciones (sentarse/pararse avanzan solas al terminar el clip)
	_tr(sm, "Start", "loco", 0.0, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	if lib.has_animation("sit_down"):
		var t1 := _tr(sm, "sit_down", "seated", 0.15, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
		t1.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		var t2 := _tr(sm, "stand_up", "loco", 0.2, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
		t2.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		for pair in [["loco", "sit_down"], ["act", "sit_down"], ["seated", "stand_up"], ["stand_up", "act"], ["sit_down", "stand_up"],
				["stand_up", "sit_down"], ["sit_down", "act"], ["sit_down", "loco"], ["stand_up", "seated"]]:
			_tr(sm, pair[0], pair[1], 0.2)
	for pair in [["loco", "seated", 0.3], ["seated", "loco", 0.3], ["loco", "act", XF], ["act", "loco", XF], ["act", "seated", 0.3], ["seated", "act", 0.3]]:
		_tr(sm, pair[0], pair[1], pair[2])
	_roots[p_slug] = sm
	return sm


static func _tr(sm: AnimationNodeStateMachine, a: String, b: String, xf: float, adv: int = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED) -> AnimationNodeStateMachineTransition:
	if sm.has_transition(a, b):
		for i in sm.get_transition_count():
			if sm.get_transition_from(i) == StringName(a) and sm.get_transition_to(i) == StringName(b):
				return sm.get_transition(i)
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xf
	t.advance_mode = adv
	sm.add_transition(a, b, t)
	return t


static func _switch(lib: AnimationLibrary, ap: AnimationPlayer, names: Array, node_name: String, xf: float) -> AnimationNodeBlendTree:
	var list: Array = []
	for n in names:
		if lib.has_animation(n):
			list.append(LIB + "/" + n)
	return _switch_raw(list, node_name, xf)


static func _switch_raw(clips: Array, node_name: String, xf: float) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = xf
	tr.allow_transition_to_self = false
	for i in clips.size():
		var input := str(clips[i]).trim_prefix(LIB + "/")
		tr.add_input(input)
		bt.add_node("c%d" % i, _anim_node(str(clips[i])), Vector2(0, i * 60))
	bt.add_node(node_name, tr, Vector2(300, 0))
	for i in clips.size():
		bt.connect_node(node_name, i, "c%d" % i)
	bt.add_node("ts", AnimationNodeTimeScale.new(), Vector2(500, 0))
	bt.connect_node("ts", 0, node_name)
	bt.connect_node("output", 0, "ts")
	return bt


func _add_look() -> void:
	if skeleton == null or skeleton.find_bone("head") < 0 or slug == "vitzo":
		return
	_look_target = Node3D.new()
	_look_target.name = "MiradaObjetivo"
	skeleton.add_child(_look_target)
	_look = LookAtModifier3D.new()
	_look.name = "Mirada"
	_look.bone_name = "head"
	_look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	_look.primary_rotation_axis = Vector3.AXIS_Y
	_look.use_secondary_rotation = true
	_look.use_angle_limitation = true
	_look.symmetry_limitation = true
	_look.primary_limit_angle = deg_to_rad(110.0)
	_look.primary_damp_threshold = 0.7
	_look.secondary_limit_angle = deg_to_rad(50.0)
	_look.secondary_damp_threshold = 0.7
	_look.duration = 0.35
	_look.transition_type = Tween.TRANS_SINE
	_look.ease_type = Tween.EASE_IN_OUT
	_look.influence = 0.0
	skeleton.add_child(_look)
	skeleton.move_child(_look, 0)  # antes que ScreamRig (que va después y manda en los screamers)
	_look.target_node = _look.get_path_to(_look_target)


# ------------------------------------------------------------------ API
func has_clip(n: String) -> bool:
	n = str(ALIAS.get(n, n))
	return _lib.has_animation(n) or player.has_animation(n)


## Igual que CharacterRig.play: pide un clip (o la primera alternativa que exista). Devuelve false si no hay ninguno.
func play(p_name: String, loop: bool = true, speed: float = 1.0, alternatives: Array = []) -> bool:
	var chosen := ""
	for n in [p_name] + alternatives:
		if has_clip(str(n)):
			chosen = str(n)
			break
	if chosen == "":
		return false
	# Sentado y el guion pide "idle" con "sit" de alternativa (el compañero de al lado que deja de teclear un momento
	# para hablarte): se queda sentado quieto en su silla, no se para.
	if chosen == "idle" and alternatives.has("sit") and state in ["seated", "sit_down"] and has_clip("sit"):
		chosen = "sit"
	_req_speed = speed
	if chosen == current:
		_apply_speed()
		if _raw:
			player.speed_scale = maxf(speed, 0.0)
		return true
	if chosen.contains("/") and not chosen.begins_with(LIB + "/"):
		return _play_raw(chosen, loop, speed)  # clip de otra biblioteca (kills…): directo en el AnimationPlayer
	if _raw:
		_raw = false
		player.stop()
		player.active = false
		tree.active = true
	current = chosen
	_talking = false
	_talk_mode = ""
	_shot_left = 0.0
	var n := str(ALIAS.get(chosen, chosen))
	n = str((_persona.get("map", {}) as Dictionary).get(n, n))
	if not has_clip(n):
		n = str(ALIAS.get(chosen, chosen))
	var target := ""
	match n:
		"idle", "walk", "run", "sprint", "walk_brisk", "walk_angry", "walk_tired":
			target = "loco"
			_gait_cap = float(CAP.get(n, 2.4)) if n != "walk_brisk" else 2.4
			_gait_min = {"walk": 1.0, "run": 3.0, "sprint": 4.0, "walk_brisk": 2.0}.get(n, 0.0)
			sub = n
			if n == "idle":
				_pick_idle(true)
		"sit_down", "stand_up":
			target = n if _lib.has_animation(n) else ("seated" if n == "sit_down" else "loco")
			sub = n
		_:
			if _lib.has_animation(n) and SEATED.has(n):
				target = "seated"
				_seat_base = n
				sub = n
				_set_switch("seated/sv", _seat_variant_for(n))
				if n == "haime_lean" and speed > 0.0:
					_jolt_left = 0.3  # los antebrazos caen sobre el escritorio
			else:
				target = "act"
				var input := n
				if not _lib.has_animation(n) and player.has_animation(n):
					input = n
				sub = input
				var a := (_lib.get_animation(n) if _lib.has_animation(n) else player.get_animation(n))
				if a != null and _lib.has_animation(n) == false:
					a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				elif a != null and not loop and a.loop_mode != Animation.LOOP_NONE and speed > 0.0:
					# un gesto en bucle pedido UNA vez (el Trainer señala al decir una línea, Shero al llamarte la atención):
					# dura un ciclo y vuelve solo a la postura de antes, como el clip corto de v0.3.1 (no se queda señalando)
					_shot_left = maxf(a.length / speed - XF, 0.4)
					_shot_back = _seat_base if state in ["seated", "sit_down"] else "idle"
				if n == "slam_table" and speed > 0.0:
					_jolt_left = 0.5 / speed  # el puño llega a la mesa a los 0,5 s del clip
				elif n == "lean_in" and speed > 0.0:
					_jolt_left = 0.3
				_set_switch("act/av", input)
	_go(target)
	_apply_speed()
	if not _desynced and _age < 0.6 and target in ["seated", "loco"] and speed > 0.0:
		# recién creado: cada uno arranca en otro momento de su bucle (una fila de agentes no teclea al unísono)
		_desynced = true
		tree.advance(_rng.randf_range(0.0, 8.0))
	if _look != null and target == "act" and (n.begins_with("jumpscare") or n in ["dead", "scream", "float"]):
		_look_w = 0.0
	return true


func stop() -> void:
	current = ""


## Suma una biblioteca extra al AnimationPlayer del personaje (p. ej. la de muertes: "k32"). Sus clips se piden con
## play("k32/nombre"): se reproducen directo en el AnimationPlayer (el árbol se apaga mientras dura) y al pedir después
## cualquier clip normal (idle, walk, dead…) el árbol vuelve solo.
func add_library(lib_name: String, lib: AnimationLibrary) -> void:
	if lib != null and not player.has_animation_library(lib_name):
		player.add_animation_library(lib_name, lib)


func _play_raw(clip: String, loop: bool, speed: float) -> bool:
	var a := player.get_animation(clip)
	if a == null:
		return false
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	current = clip
	state = "act"
	sub = clip
	_talking = false
	_talk_mode = ""
	_raw = true
	tree.active = false
	player.active = true
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	player.play(clip, 0.15, maxf(speed, 0.0))
	if _look != null:
		_look_w = 0.0
	return true


func current_state() -> String:
	var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	return str(pb.get_current_node()) if pb != null else ""


func current_variant() -> String:
	match current_state():
		"seated":
			return str(tree.get("parameters/seated/sv/current_state"))
		"act":
			return str(tree.get("parameters/act/av/current_state"))
		"loco":
			return str(tree.get("parameters/loco/bs/0/iv/current_state")) if _b < 0.5 else "gait %.2f" % _b
	return current_state()


func gait() -> float:
	return _b


func _go(target: String) -> void:
	var pb := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb == null:
		return
	var cur := str(pb.get_current_node())
	var fresh := _age < 0.6 or not auto_transitions
	if target == "seated" and cur in ["loco", "act", "stand_up"] and not fresh and _lib.has_animation("sit_down"):
		target = "sit_down"  # la auto-transición lo lleva a seated al terminar
	elif target == "loco" and cur in ["seated", "sit_down"] and not fresh and _lib.has_animation("stand_up"):
		target = "stand_up"
	_chair_ev = target if (target != state and target in ["sit_down", "stand_up"]) else ("" if target != state else _chair_ev)
	state = target
	if fresh or cur == "" or cur == "Start":
		pb.start(target)
	else:
		# Siempre se pide el viaje, también cuando el árbol YA está en `target`: eso anula un viaje anterior que todavía no
		# arrancó (una orden que llegó en mitad de un fundido espera a que termine; si el guion cambia de idea en ese
		# rato —sit y enseguida idle— tiene que mandar la última orden, no quedarse sentado con el guion creyéndolo de pie).
		pb.travel(target)


func _set_switch(path: String, input: String) -> void:
	tree.set("parameters/%s/transition_request" % path, input)


func _seat_variant_for(n: String) -> String:
	if n == "sit" and _persona.has("seated"):
		_seat_pool = _persona["seated"]
		return n
	_seat_pool = []
	return n


func _apply_speed() -> void:
	var s := maxf(_req_speed, 0.0)
	tree.set("parameters/seated/ts/scale", s)
	tree.set("parameters/act/ts/scale", s)


## Postura de pie: la primera de `_idles` es la base (un buen rato); de ella sale a una variante (mirar alrededor, la
## hora, brazos cruzados, el barrido de la linterna…) que dura su gesto ENTERO (el clip arranca de cero al entrar y se
## suelta justo cuando vuelve a la postura neutra) y regresa a la base. Nunca repite la misma variante dos veces.
func _pick_idle(first: bool) -> void:
	var n: String = _idles[0]
	var hold := _rng.randf_range(7.0, 14.0)
	if not first and _idles.size() > 1:
		var cur := str(tree.get("parameters/loco/bs/0/iv/current_state"))
		if cur == n:  # de una variante (o de un gesto de hablar) siempre vuelve a la base
			var pool: Array = _idles.filter(func(x): return x != n and x != _last_variant)
			if pool.is_empty():
				pool = _idles.filter(func(x): return x != n)
			n = pool[_rng.randi() % pool.size()]
			_last_variant = n
			var a := _lib.get_animation(n)
			if a != null:
				hold = maxf(a.length * (2.0 if a.length < 4.5 else 1.0) - 0.35, 2.0)
	tree.set("parameters/loco/bs/0/iv/transition_request", n)
	_variant_t = hold


# ------------------------------------------------------------------ cada fotograma
func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec() if prof_on else 0
	_age += delta
	if body == null or not is_instance_valid(body) or tree == null:
		return
	if not _unit_ok and skeleton != null and skeleton.is_inside_tree():
		unit_m = absf(skeleton.global_transform.basis.get_scale().x)  # metros por unidad del GLB (escala del modelo)
		_unit_ok = true
	# velocidad y giro medidos (el guion mueve el nodo; acá solo se mira)
	var p := body.global_position
	var yaw := body.global_rotation.y
	if _last_pos != Vector3.INF and delta > 0.0:
		# velocidad = distancia / tiempo acumulados con olvido (~0,15 s): no se sesga cuando los fotogramas son desparejos
		# ni cuando el guion mueve el cuerpo en physics (un fotograma con dos pasos, otro con ninguno)
		var dist := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
		if dist > 14.0 * delta + 0.5:
			dist = _v * delta  # teletransporte / cambio de piso
		var keep := exp(-delta * 7.0)
		_dsum = _dsum * keep + dist
		_ysum = _ysum * keep + wrapf(yaw - _last_yaw, -PI, PI)
		_tsum = _tsum * keep + delta
		_v = _dsum / _tsum
		_yaw_rate = _ysum / _tsum
	_last_pos = p
	_last_yaw = yaw
	# LOD de actualización
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dist := 0.0
	var visible_cam := true
	if cam != null:
		dist = cam.global_position.distance_to(p)
		visible_cam = cam.is_position_in_frustum(p + Vector3(0, 1.0, 0)) or dist < 3.0
	var hz := 60.0
	var every := true  # cerca y a la vista: cada fotograma (como el AnimationPlayer)
	if not visible_cam or dist > 35.0:
		hz = 6.0
		every = false
	elif dist > 22.0:
		hz = 15.0
		every = false
	elif dist > 12.0:
		hz = 30.0
		every = false
	var light := GfxQuality.is_light()
	if light:
		hz *= 0.5
		every = false
	_sync_state()
	# coreografías y poses congeladas: siempre en cada cuadro (ver arriba)
	var forced := state == "act" or _req_speed <= 0.0 or state in ["sit_down", "stand_up"]
	_tick_interval = 1.0 / hz
	_clock += delta
	if _shot_left > 0.0:
		_shot_left -= delta
		if _shot_left <= 0.0 and state == "act":
			play(_shot_back, true, 1.0)
	if _jolt_left > 0.0:
		_jolt_left -= delta
		if _jolt_left <= 0.0 and (sub in ["slam_table", "lean_in"] or _seat_now() == "haime_lean"):
			# el golpe en la mesa: lo que hay encima (auricular del teléfono, taza, grabadora) salta y tintinea
			var fwd := -body.global_transform.basis.z
			ObjectAnim.jolt(body.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 0.6 + Vector3(0, 0.8, 0), 1.2, 1.3 if sub == "slam_table" else 0.7)
	_update_talk()
	_update_logic(delta)
	_update_look(delta, cam, dist)
	_acc += delta
	var advanced := false
	if _raw:
		_acc = 0.0
	elif forced or every or _acc >= _tick_interval - 0.0005:
		if forced or not light or dist < 4.0 or _light_turn():
			if _jaw_dirty:
				skeleton.set_bone_pose_rotation(_jaw, _jaw_base)
			tree.advance(_acc)
			_acc = 0.0
			advanced = true
			_sync_state()
			if prof_on:
				prof_ticks += 1
	_update_jaw(delta, advanced, dist)
	if prof_on:
		prof_usec += Time.get_ticks_usec() - t0


## Sentarse / pararse terminan solos (transición automática al acabar el clip): `state` sigue al árbol. Sin esto, el que
## se paraba para caminar se quedaba sin lógica de marcha (deslizándose en idle) y avanzando en cada cuadro para siempre.
func _sync_state() -> void:
	if state == "sit_down" or state == "stand_up":
		var cs := current_state()
		if _chair_ev == state and cs == state:
			# el clip arrancó de verdad (una orden en pleno fundido espera): ahora la silla lo acompaña
			_chair_ev = ""
			ObjectAnim.chair_event(body.global_position, "sit" if state == "sit_down" else "stand")
		if (state == "sit_down" and cs == "seated") or (state == "stand_up" and cs == "loco"):
			state = cs


## Variante que suena ahora dentro de «seated» ("" si no está sentado).
func _seat_now() -> String:
	return str(tree.get("parameters/seated/sv/current_state")) if state == "seated" else ""


## Modo liviano: ¿le toca a este animador avanzar en este fotograma? Cupo de LIGHT_BUDGET por cuadro, por turnos.
func _light_turn() -> bool:
	var f := Engine.get_process_frames()
	var n := maxi(_all.size(), 1)
	if f != _rr_frame:
		_rr_frame = f
		_rr_cursor = (_rr_cursor + LIGHT_BUDGET) % n
	return (_all.find(self) - _rr_cursor + n) % n < LIGHT_BUDGET


func _update_logic(delta: float) -> void:
	var st := state
	if st == "loco":
		var want := 0.0
		var k := 1.0
		var v := _v
		var moving := v > 0.12
		var nominal := _gait_min > 0.0 and not moving
		if nominal:
			want = _gait_min
			k = float(_cadence[int(_gait_min)]) * maxf(_req_speed, 0.0)
		elif moving:
			var r := _gait_from_speed(v)
			want = minf(r.x, _gait_cap)
			var stride := _stride_at(want)
			k = v / maxf(stride, 0.05)
			if want < 1.0:
				k = float(_cadence[1]) * clampf(v / maxf(_strides[1] * unit_m * float(_cadence[1]), 0.1), 0.6, 1.0) if want > 0.05 else 1.0
		else:
			want = 0.0
			k = maxf(_req_speed, 0.0) if _req_speed < 0.01 else 1.0
		_b = move_toward(_b, want, delta * 5.0)
		var turn := 0.0
		if _b < 0.6 and absf(_yaw_rate) > 0.4:
			turn = clampf(_yaw_rate / TURN_RATE, -1.0, 1.0) * (1.0 - _b / 0.6)
			k = maxf(k, absf(_yaw_rate) / TURN_RATE)
		_turn = move_toward(_turn, turn, delta * 6.0)
		tree.set("parameters/loco/bs/blend_position", Vector2(_b, _turn))
		tree.set("parameters/loco/ts/scale", clampf(k, 0.0, 3.0))
		if current == "idle" and _b < 0.1 and not _talking:
			_variant_t -= delta
			if _variant_t <= 0.0:
				_pick_idle(false)
	elif st == "seated" and not _talking:
		if _oneshot_left > 0.0:
			_oneshot_left -= delta
			if _oneshot_left <= 0.0:
				_set_switch("seated/sv", _seat_base)
				_variant_t = _rng.randf_range(7.0, 18.0)
		else:
			_variant_t -= delta
			if _variant_t <= 0.0:
				_variant_t = _rng.randf_range(7.0, 18.0)
				var n := _seat_variant()
				if n != "" and _lib.has_animation(n):
					_set_switch("seated/sv", n)
					_oneshot_left = _lib.get_animation(n).length if n in TIRED else _rng.randf_range(8.0, 16.0)


## Qué hace un rato el que está sentado: Haime rota lo suyo; los agentes atienden una llamada, se aburren con la cara
## en la mano, leen, o (según el cansancio) cabecean / se frotan los ojos / bostezan.
func _seat_variant() -> String:
	if not _seat_pool.is_empty() and _seat_base == "sit":
		return str(_seat_pool[_rng.randi() % _seat_pool.size()])
	if tired <= 0.0 or not (_seat_base in ["sit", "type"]) or _req_speed <= 0.0:
		return ""
	var r := _rng.randf()
	if r < 0.45 * tired:
		return TIRED[_rng.randi() % TIRED.size()]
	if r < 0.45 * tired + 0.22:
		return "phone"
	if r < 0.45 * tired + 0.36:
		return "bored"
	if r < 0.45 * tired + 0.44:
		return "read" if _seat_base == "type" else "type"
	return ""


# ------------------------------------------------------------------ hablar
func speaker_keys() -> Array:
	if _keys.is_empty():
		_keys = (SPEAKERS.get(slug, [slug]) as Array).duplicate()
		if slug.begins_with("agente_"):
			_keys.append(slug.trim_prefix("agente_"))
	return _keys


func _speaking() -> bool:
	if SpeechHub.now() < _speak_until_ms:
		return true
	return _hub != null and is_instance_valid(_hub) and _hub.is_speaking(self)


## Marca que ESTE animador habla `secs` segundos (lo usa el hub para "un compañero"; también sirve a mano).
func speak(secs: float, hard: bool = false) -> void:
	_speak_until_ms = SpeechHub.now() + int(secs * 1000.0)
	_speak_hard = hard


func shut_up() -> void:
	_speak_until_ms = 0


func _update_talk() -> void:
	var sp := _speaking()
	if sp and not _talking:
		_talking = true
		_talk_n += 1
		var hard := _speak_hard or (_hub != null and is_instance_valid(_hub) and _hub.is_hard(self))
		if state == "seated" and not sub in ["sit_down", "stand_up"]:
			_talk_mode = "seated"
			var c := "sit_talk"
			if hard and _persona.has("talk_seated_hard"):
				c = str(_persona["talk_seated_hard"])
				_jolt_left = 0.3
			if _lib.has_animation(c):
				_set_switch("seated/sv", c)
			_oneshot_left = 0.0
		elif state == "loco" and current == "idle" and _b < 0.3 and _req_speed > 0.0:
			_talk_mode = "stand"
			var pool: Array = _persona.get("talk_hard", ["open_hands"]) if hard else _persona.get("talk", ["talk", "open_hands"])
			var c2 := str(pool[_talk_n % pool.size()])
			if _lib.has_animation(c2):
				tree.set("parameters/loco/bs/0/iv/transition_request", c2)
			_variant_t = 1e6
		else:
			_talk_mode = "jaw"
	elif not sp and _talking:
		_talking = false
		if _talk_mode == "seated" and state == "seated":
			_set_switch("seated/sv", _seat_base)
			_variant_t = _rng.randf_range(6.0, 14.0)
		elif _talk_mode == "stand" and state == "loco":
			_pick_idle(false)
		_talk_mode = ""


## Mandíbula: sigue la VOZ que suena. La apertura es la envolvente del bus por el que sale la línea (pico por bloque de
## mezcla: sube con cada sílaba y se cierra en las pausas), con un pequeño ritmo propio encima para que dos personajes
## no muevan la boca idéntico; si no hay audio que medir (línea solo de texto, sin dispositivo) va por sílabas a ritmo
## de habla. Mientras suena REEMPLAZA a la mandíbula del clip (la de «hablar sin audio», clips_human.speech_jaw): no se
## suman, así la boca cierra del todo en las pausas y nunca pasa de JAW_TALK_DEG / JAW_HARD_DEG. Abrir = el mentón baja =
## giro POSITIVO sobre el eje X del esqueleto (el sentido de los «scream» de los GLB). Nada en Modo liviano ni a más de
## JAW_MAX_DIST (ahí queda la del clip).
func _update_jaw(delta: float, advanced: bool, dist: float) -> void:
	if _jaw < 0 or skeleton == null:
		return
	var on := _talking and dist < JAW_MAX_DIST and not GfxQuality.is_light() and not (state == "act" and (sub.begins_with("jumpscare") or sub in ["dead", "scream", "float"]))
	if not on and not _jaw_dirty:
		return
	if advanced or not _jaw_dirty:
		_jaw_base = skeleton.get_bone_pose_rotation(_jaw)
	var want := 0.0
	if on:
		var syl := 0.5 + 0.5 * sin(_clock * 31.0 + float(_talk_n))
		syl *= 0.55 + 0.45 * sin(_clock * 11.3 + 1.7)
		var top := JAW_HARD_DEG if _speak_hard or (_hub != null and is_instance_valid(_hub) and _hub.is_hard(self)) else JAW_TALK_DEG
		var lvl := SpeechHub.level()
		if lvl < 0.0:
			want = clampf(syl, 0.0, 1.0) * 0.7 * top
		else:
			want = pow(lvl, 0.8) * (0.7 + 0.3 * clampf(syl, 0.0, 1.0)) * top
	# abre rápido (ataque de la sílaba) y cierra un poco más lento
	_jaw_open = lerpf(_jaw_open, want, 1.0 - exp(-delta * (30.0 if want > _jaw_open else 16.0)))
	_jaw_w = move_toward(_jaw_w, 1.0 if on else 0.0, delta * (10.0 if on else 6.0))
	if not on and _jaw_open < 0.2 and _jaw_w < 0.02:
		_jaw_open = 0.0
		_jaw_w = 0.0
		_jaw_dirty = false
		skeleton.set_bone_pose_rotation(_jaw, _jaw_base)
		return
	_jaw_dirty = true
	skeleton.set_bone_pose_rotation(_jaw, _jaw_base.slerp(_jaw_rest * Quaternion(_jaw_axis, deg_to_rad(_jaw_open)), _jaw_w))


## marcha (x) para una velocidad v (m/s): por tramos entre los puntos de stride×cadencia
func _gait_from_speed(v: float) -> Vector2:
	var prev := 0.0
	for i in range(1, 5):
		var vi := _strides[i] * unit_m * float(_cadence[i])
		if v <= vi:
			var f := (v - prev) / maxf(vi - prev, 0.01)
			return Vector2(float(i - 1) + clampf(f, 0.0, 1.0), 0)
		prev = vi
	return Vector2(4.0, 0)


func _stride_at(b: float) -> float:
	var i := clampi(int(floor(b)), 0, 3)
	var f := b - float(i)
	var s0 := _strides[i] * unit_m if i > 0 else _strides[1] * unit_m * 0.0
	var s1 := _strides[i + 1] * unit_m
	return lerpf(s0, s1, f) if i > 0 else s1 * maxf(f, 0.25)


func _update_look(delta: float, cam: Camera3D, dist: float) -> void:
	if _look == null:
		return
	var want := 0.0
	if look_enabled and cam != null and not GfxQuality.is_light() and dist < 7.0 and dist > 0.4:
		var to := cam.global_position - body.global_position
		to.y = 0.0
		var fwd := -body.global_transform.basis.z
		fwd.y = 0.0
		var facing := fwd.normalized().dot(to.normalized()) if to.length() > 0.01 else 1.0
		var st := state
		var sv := sub
		if st == "loco" and _b < 1.6:
			want = 1.0
		elif st == "seated":
			want = 0.35 if sv == "type" else 0.8
		elif st == "act" and not (sv.begins_with("jumpscare") or sv in ["dead", "scream", "float", "dance", "dj", "slam_table", "peek_door", "bang_door"]):
			want = 0.9
		want *= clampf((facing + 0.35) / 0.6, 0.0, 1.0) * clampf((7.0 - dist) / 2.0, 0.0, 1.0)
		if to.length() < 0.3:
			want = 0.0  # la cámara está DENTRO del personaje (su doble en el espejo, el cuerpo del jugador): no hay a dónde mirar
		_look_target.global_position = cam.global_position
	_look_w = move_toward(_look_w, want, delta * 2.5)
	_look.influence = _look_w
	_look.active = _look_w > 0.001


## Quién está hablando. Un nodo en la raíz (uno solo) escucha al VoiceDirector (v0.3.2: UNA línea a la vez en todo el
## juego, con su principio y su fin exactos) o, si el árbol no lo trae, a EventBus.subtitle (se estima por el texto).
## Con el director: el gesto dura lo que dura EL AUDIO de la línea (no una estimación) y se corta con `finished` (una
## línea interrumpida o cancelada deja de gesticular en el acto); una voz sin subtítulo también cuenta; las que no se
## dicen en persona (parlantes, auricular, pensamientos) no mueven a nadie; si la voz sale de un reproductor 3D colgado
## de un personaje (Shero en persona, el murmullo de un compañero) habla ESE personaje; «[Marko] …» por la carpeta
## genérica "comp" lo dice Marko si está cerca y, si no, el compañero más cercano; si hay dos modelos iguales a la
## vista (el Trainer y una copia) habla el más cercano a la cámara.
class SpeechHub extends Node:
	## Hablantes que no son un personaje presente (sistema, cliente por el auricular, parlantes, pensamientos…).
	const NOT_PERSON: Array[String] = ["", "sys", "sistema", "cliente", "clientes", "ezlak", "ezlaki", "parlantes", "piensa", "rec", "llanto", "haime_replay"]
	## Carpetas genéricas: quién habla sale del nombre entre corchetes o del archivo de voz.
	const GENERIC: Array[String] = ["otros", "comp", "agentes", "agente", "promocion"]
	## Buses por los que la voz no sale de la boca de nadie presente.
	const REMOTE_BUSES: Array[String] = ["Parlantes", "Auricular", "UI"]
	## Nombre visible (en minúsculas) → clave de hablante.
	const TAGS := {"don fermín": "fermin", "don fermin": "fermin", "fermín": "fermin", "fermin": "fermin", "enfermero": "enfermero",
		"enfermera": "enfermera", "nurse": "enfermero", "marleny": "marleny", "trainer": "trainer", "haime": "haime", "shero": "shero",
		"rasec": "rasec", "mentor": "mentor", "vitzo": "vitzo", "papayala": "papayala", "grasa": "grasa", "om": "om",
		"marko": "marko", "llauri": "llauri", "ttoom": "ttoom", "juan": "juan", "jiroshi": "jiroshi"}
	var vd: Node = null
	var until_ms: Dictionary = {}  # hablante → ms (reloj del hub) hasta cuando habla
	var hard: Dictionary = {}      # hablante → la línea es un grito / una orden
	var only: Dictionary = {}      # hablante → el único animador que habla con esa clave (dos modelos iguales a la vista)
	var line_speaker: Dictionary = {}  # id de línea del VoiceDirector → hablante
	var line_anim: Dictionary = {}     # id de línea → animador concreto (un compañero, el dueño del reproductor 3D)
	## Con el director de verdad: la línea que suena AHORA y a quién se la dio el hub. Las ventanas de tiempo de arriba
	## (until_ms, _speak_until_ms) se vuelven a calcular en cada cuadro con el reloj del director (lo que le queda de
	## audio), así que quién habla y hasta cuándo no depende del ritmo de fotogramas ni de un reloj propio.
	var cur: Object = null
	var cur_key: String = ""
	var cur_anim: NpcAnimator = null
	var cur_est_ms: int = 0  # línea sin audio: cuánto dura decir el texto
	## Auditoría / pruebas: a quién le tocó cada línea (id → el NpcAnimator elegido, o la clave de hablante). Últimas 24.
	var picked: Dictionary = {}
	static var _bus: int = -2
	static var _ms: float = 0.0
	static var _line_bus: int = -1  # bus de la línea en curso (para la mandíbula)

	## Reloj de las líneas: tiempo de juego sin escalar (como el del VoiceDirector). Con el de pared, un tirón de carga
	## o una grabación con --write-movie cortaban el gesto antes de tiempo.
	static func now() -> int:
		return int(_ms)

	func _process(delta: float) -> void:
		_ms += minf(delta / maxf(Engine.time_scale, 0.01), 0.25) * 1000.0
		if cur != null:
			_follow_line()

	## Milisegundos de voz que le quedan a la línea en curso según el director (0 = ya no suena).
	func _left_ms() -> int:
		if cur == null or vd == null or bool(cur.get("done")) or vd.get("current") != cur:
			return 0
		var vnow := int(vd.call("now_ms"))
		if bool(cur.get("has_audio")):
			var wend := int(cur.get("wall_end_ms"))
			return 1000 if wend <= int(cur.get("started_ms")) else maxi(wend - vnow, 0)
		return maxi(int(cur.get("started_ms")) + cur_est_ms - vnow, 0)

	## Ajusta las ventanas de quien habla a lo que le queda de voz a la línea (cada cuadro).
	func _follow_line() -> void:
		var left := _left_ms()
		var until := now() + left
		if cur_anim != null and is_instance_valid(cur_anim):
			if left > 0 or cur_anim._speak_until_ms > until:
				cur_anim._speak_until_ms = until
		if cur_key != "" and (left > 0 or int(until_ms.get(cur_key, 0)) > until):
			until_ms[cur_key] = until
		if left <= 0:
			cur = null
			cur_key = ""
			cur_anim = null

	## Anota quién dice la línea `l` (para seguirla cuadro a cuadro y para la auditoría).
	func _track(l: Object, key: String, who: NpcAnimator, est_s: float) -> void:
		if l == null or not vd.has_method("now_ms"):
			return
		if cur != l:
			cur_key = ""
			cur_anim = null
		cur = l
		if key != "":
			cur_key = key
		if who != null:
			cur_anim = who
		cur_est_ms = int(est_s * 1000.0)
		var id := str(l.get("id"))
		if who != null or not (picked.get(id) is NpcAnimator):
			picked[id] = who if who != null else key  # el animador concreto, o la clave si hablan «los de esa clave»
		if picked.size() > 24:
			picked.erase(picked.keys()[0])

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		vd = get_node_or_null("/root/VoiceDirector")
		if vd != null and vd.has_signal("subtitle_shown"):
			vd.connect("subtitle_shown", _on_sub)
			if vd.has_signal("line_started"):
				vd.connect("line_started", _on_line)
			if vd.has_signal("finished"):
				vd.connect("finished", _on_done)
		else:
			vd = null
			EventBus.subtitle.connect(_on_sub)

	static func canon(sp: String) -> String:
		return sp.to_lower().strip_edges()

	## La línea que suena ahora en el director (objeto Line) o null (pruebas con un director falso, v0.3.1).
	func _vd_line() -> Object:
		if vd == null:
			return null
		var l: Variant = vd.get("current")
		return l as Object if l is Object and is_instance_valid(l) else null

	## Segundos de AUDIO que le quedan a la línea en curso (−1 si no trae audio o no se sabe).
	func _audio_left(l: Object) -> float:
		if l == null or not bool(l.get("has_audio")) or not vd.has_method("now_ms"):
			return -1.0
		if int(l.get("wall_end_ms")) <= int(l.get("started_ms")):
			return -1.0  # el director emite el subtítulo antes de calcular el fin del audio: lo afina line_started
		return maxf((int(l.get("wall_end_ms")) - int(vd.call("now_ms"))) / 1000.0, 0.0)

	## ¿La voz de esta línea sale de alguien presente? (no por los parlantes, el auricular ni «en la cabeza»)
	func _in_person(l: Object) -> bool:
		if l == null:
			return true
		var ext: Variant = l.get("external")
		# (primero is_instance_valid: preguntar «is Node» a un reproductor ya liberado —el piso o el mundo cambiaron con
		# la línea en cola— es un error de script)
		var bus := str(ext.get("bus")) if is_instance_valid(ext) and ext is Node else str(l.get("bus"))
		_line_bus = AudioServer.get_bus_index(bus)
		return not REMOTE_BUSES.has(bus)

	## El personaje del que cuelga el reproductor 3D de la línea (Shero en persona, el compañero que murmura).
	func _owner_of(l: Object) -> NpcAnimator:
		if l == null:
			return null
		var ext: Variant = l.get("external")
		if not is_instance_valid(ext) or not (ext is Node):  # (en ese orden: «is» sobre una instancia liberada es un error)
			return null
		var n: Node = (ext as Node).get_parent()
		for _i in 3:
			if n == null:
				return null
			for a in NpcAnimator._all:
				if is_instance_valid(a) and a.body != null and is_instance_valid(a.body) and (a.body == n or a.body.get_parent() == n):
					return a
			n = n.get_parent()
		return null

	func _on_line(line_id: String, speaker: String, _priority: int) -> void:
		var sp := canon(speaker)
		if not line_speaker.has(line_id):  # el subtítulo (que llega antes) puede haber resuelto ya quién es
			line_speaker[line_id] = sp
		if line_speaker.size() > 64:
			line_speaker.erase(line_speaker.keys()[0])
		var l := _vd_line()
		if l == null or str(l.get("id")) != line_id or not bool(l.get("has_audio")):
			return
		if not _in_person(l) or NOT_PERSON.has(sp):
			_hush(sp, line_id)  # el subtítulo llegó antes que la línea y ya lo había puesto a hablar: por parlantes no
			return
		# línea con voz: habla lo que dura el audio (el subtítulo, si lo trae, ya eligió quién y si es un grito)
		var left := _audio_left(l)
		var who := _owner_of(l)
		if who == null and line_anim.has(line_id) and is_instance_valid(line_anim[line_id]):
			who = line_anim[line_id]
		if who != null:
			who.speak(left, who._speak_hard if who._speak_until_ms > now() else false)
			line_anim[line_id] = who
			_track(l, "", who, left)
			if GENERIC.has(sp) or not who.speaker_keys().has(sp):
				return
		var key := sp
		if GENERIC.has(sp):
			key = _key_from(sp, str(l.get("text")), line_id)
			if key == "":
				return
			line_speaker[line_id] = key
		if not until_ms.has(key) or int(until_ms[key]) <= now():
			hard[key] = false
		until_ms[key] = now() + int(left * 1000.0)
		line_speaker[line_id] = key
		_pick_only(key, who)
		_track(l, key, who, left)

	func _hush(sp: String, line_id: String) -> void:
		until_ms.erase(sp)
		if cur != null and str(cur.get("id")) == line_id:
			cur = null
			cur_key = ""
			cur_anim = null
		if line_anim.has(line_id):
			if is_instance_valid(line_anim[line_id]):
				(line_anim[line_id] as NpcAnimator).shut_up()
			line_anim.erase(line_id)

	func _on_done(line_id: String) -> void:
		var sp := str(line_speaker.get(line_id, ""))
		line_speaker.erase(line_id)
		if cur != null and str(cur.get("id")) == line_id:
			cur = null
			cur_key = ""
			cur_anim = null
		if sp != "" and until_ms.has(sp):
			until_ms[sp] = mini(int(until_ms[sp]), now() + 120)
		if line_anim.has(line_id):
			var a: Variant = line_anim[line_id]
			line_anim.erase(line_id)
			if is_instance_valid(a) and (a as NpcAnimator)._speak_until_ms > 0:
				(a as NpcAnimator)._speak_until_ms = mini((a as NpcAnimator)._speak_until_ms, now() + 120)

	## Clave de hablante para una carpeta genérica: el archivo de voz («voces/otros/fermin_buenas_noches») o el nombre
	## entre corchetes del subtítulo («[Don Fermín] …», «[Marko] …»). "" = no se sabe.
	func _key_from(sp: String, text: String, line_id: String) -> String:
		var file := line_id.get_file().to_lower()
		for k in ["fermin", "enfermero", "enfermera", "marleny"]:
			if file.begins_with(k):
				return k
		var tag := ""
		if text.begins_with("[") and text.contains("]"):
			tag = text.substr(1, text.find("]") - 1)
		elif text.contains(": "):
			tag = text.get_slice(": ", 0)
		tag = tag.to_lower().strip_edges()
		if TAGS.has(tag):
			return str(TAGS[tag])
		# por palabras enteras («Marko, bajito» → marko); nunca por trozos («compañero» contiene «om» y no es OM)
		for sep in [",", ".", "(", ")", "-", "·", "/"]:
			tag = tag.replace(sep, " ")
		for w in tag.split(" ", false):
			if TAGS.has(w):
				return str(TAGS[w])
		return ""

	func _on_sub(speaker: String, text: String, seconds: float) -> void:
		var sp := canon(speaker)
		if text == "" or NOT_PERSON.has(sp) or text.begins_with("[REC]"):
			return
		var l := _vd_line()
		var mine: bool = l != null and canon(str(l.get("speaker"))) == sp
		var line_id := str(l.get("id")) if mine else ""
		if mine and not _in_person(l):
			_hush(sp, line_id)
			return
		var body := text
		if body.begins_with("[") and body.contains("]"):
			body = body.get_slice("]", 1)
		elif body.contains(": "):
			body = body.get_slice(": ", 1)
		body = body.strip_edges()
		# cuánto dura: el audio de la línea si lo trae; si no, lo que se tarda en decir el texto
		var secs := clampf(0.5 + body.length() * 0.065, 1.2, maxf(seconds, 1.2))
		var left := _audio_left(l) if mine else -1.0
		if left >= 0.0:
			secs = left
		var letters := 0
		var caps := 0
		for i in body.length():
			var ch := body[i]
			if ch.to_upper() != ch.to_lower():
				letters += 1
				if ch == ch.to_upper():
					caps += 1
		var is_hard := body.contains("!") or (letters > 6 and caps > letters * 0.6)
		var who := _owner_of(l) if mine else null
		var key := sp
		if GENERIC.has(sp):
			key = _key_from(sp, text, line_id)
			if who == null and key != "":
				who = _named(key)
			if who == null and sp != "otros":
				who = _some_agent(text if sp == "promocion" else "")
			if who == null and key == "":
				return
		if who != null:
			who.speak(secs, is_hard)
			if line_id != "":
				line_anim[line_id] = who
			if GENERIC.has(sp) and not who.speaker_keys().has(key):
				if mine:
					_track(l, "", who, secs)
				return
		if line_id != "":
			line_speaker[line_id] = key
		until_ms[key] = now() + int(secs * 1000.0)
		hard[key] = is_hard
		_pick_only(key, who)
		if mine:
			_track(l, key, who, secs)

	## Si hay más de un animador con esta clave a la vista, habla uno solo: `who` o el más cercano a la cámara.
	func _pick_only(key: String, who: NpcAnimator) -> void:
		only.erase(key)
		var cam := get_viewport().get_camera_3d()
		var best: NpcAnimator = who
		var bd := INF
		var n := 0
		for a in NpcAnimator._all:
			if not is_instance_valid(a) or a.body == null or not is_instance_valid(a.body) or not a.body.is_inside_tree() or not a.speaker_keys().has(key):
				continue
			n += 1
			if who == null and cam != null and a.body.is_visible_in_tree():
				var d: float = a.body.global_position.distance_squared_to(cam.global_position)
				if d < bd:
					bd = d
					best = a
		if n > 1 and best != null:
			only[key] = best

	## El agente con ese nombre, si está a menos de 14 m de la cámara.
	func _named(key: String) -> NpcAnimator:
		var cam := get_viewport().get_camera_3d()
		for a in NpcAnimator._all:
			if is_instance_valid(a) and a.slug == "agente_" + key and a.body != null and is_instance_valid(a.body) and a.body.is_inside_tree() and a.body.is_visible_in_tree():
				if cam == null or a.body.global_position.distance_to(cam.global_position) < 14.0:
					return a
		return null

	## «Un compañero» no dice cuál: habla el agente más cercano a la cámara (el que tenés al lado). Con `stable` (el
	## nombre de alguien de la promoción) siempre el mismo de los que hay cerca.
	func _some_agent(stable: String = "") -> NpcAnimator:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return null
		var best: NpcAnimator = null
		var bd := 9.0
		var near: Array = []
		for a in NpcAnimator._all:
			if not is_instance_valid(a) or not a.slug.begins_with("agente_") or a.body == null or not is_instance_valid(a.body) or not a.body.is_inside_tree() or not a.body.is_visible_in_tree():
				continue
			var d: float = a.body.global_position.distance_to(cam.global_position)
			if d > 0.5 and d < 9.0:
				near.append(a)
			if d < bd and d > 0.5:
				bd = d
				best = a
		if stable != "" and near.size() > 1:
			near.sort_custom(func(x: NpcAnimator, y: NpcAnimator) -> bool: return x.body.global_position.x * 31.0 + x.body.global_position.z < y.body.global_position.x * 31.0 + y.body.global_position.z)
			var tag := stable.get_slice("]", 0)
			return near[absi(hash(tag)) % near.size()]
		return best

	func is_speaking(a: NpcAnimator) -> bool:
		var t := now()
		for k in a.speaker_keys():
			if int(until_ms.get(k, 0)) > t and (not only.has(k) or only[k] == a or not is_instance_valid(only[k])):
				return true
		return false

	func is_hard(a: NpcAnimator) -> bool:
		for k in a.speaker_keys():
			if bool(hard.get(k, false)) and int(until_ms.get(k, 0)) > now():
				return true
		return false

	## Nivel de la voz en este instante: 0..1 según el pico del bus por el que suena la línea (Sala), o −1 si no hay
	## audio que medir (línea sin voz, sin dispositivo de audio): ahí la mandíbula va solo por sílabas.
	static func level() -> float:
		if _bus == -2:
			_bus = AudioServer.get_bus_index("Sala")
		var b := _line_bus if _line_bus >= 0 else _bus
		if b < 0 or b >= AudioServer.bus_count:
			return -1.0
		var db := maxf(AudioServer.get_bus_peak_volume_left_db(b, 0), AudioServer.get_bus_peak_volume_right_db(b, 0))
		if db < -90.0:
			return -1.0
		return clampf(remap(db, -46.0, -14.0, 0.0, 1.0), 0.0, 1.0)

	## Compatibilidad (v0.3.2-beta1): 0,35..1.
	static func loudness() -> float:
		var v := level()
		return 0.7 if v < 0.0 else lerpf(0.35, 1.0, v)

class_name TrainingStage
extends Node
## v0.3.2 · Dirección de escena del Training (el recuerdo): quién está dónde y qué hace mientras el guion habla.
## El aula tiene tres ESCENAS: «clase» (la promoción sentada en la herradura), «cafe» (todos de pie alrededor de la
## isla del café, con su taza) y «foto» (en fila delante de la pizarra, posando). Tutorial dice en qué escena empieza
## cada módulo (se acomodan al instante si vienes de saltar uno) y los pasos la cambian caminando (`escena` en el paso).
## El Trainer va al sitio que pide cada paso (`trainer`: centro | pizarra | cerca | mesa | cafe | foto | puerta) y te
## mira cuando te habla. Con cada línea de TrainingVoice habla quien la dice (manos y boca) y, al terminar, la clase
## REACCIONA según data/tutorial.json → «reacciones» {línea: risa | aplauso | miran | asienten | festejo | saludan |
## mano:<nombre> | gesto:<clip del Trainer>}.
## Todo es opcional: sin piso 1 cargado (el jugador bajó al −1) no hace nada, y al volver rearma la escena en curso.

const SCENES := ["clase", "cafe", "foto"]
const LOOK_BACK_S := 2.2  # cuánto te sigue mirando un compañero después de hablarte
## Por dónde sale cada compañero de su silla (índice de TrainingRoom.CLASS) hacia la isla del café y hacia la foto.
const VIA_CAFE := [
	[Vector3(6.5, 0, -4.55), Vector3(7.6, 0, -4.5), Vector3(8.4, 0, -4.8), Vector3(9.55, 0, -4.4), Vector3(11.0, 0, -4.6), Vector3(11.25, 0, -5.4)],
	[Vector3(10.75, 0, -4.55), Vector3(11.6, 0, -4.5), Vector3(13.2, 0, -4.75)],
	[Vector3(6.5, 0, -7.45), Vector3(7.85, 0, -7.6), Vector3(9.6, 0, -7.6), Vector3(11.5, 0, -7.45)],
	[Vector3(10.75, 0, -7.55), Vector3(11.9, 0, -7.6), Vector3(13.0, 0, -7.2)],
]
const VIA_FOTO := [
	[Vector3(6.5, 0, -4.55), Vector3(7.6, 0, -4.5), Vector3(8.2, 0, -5.2), Vector3(8.0, 0, -7.1)],
	[Vector3(10.75, 0, -4.55), Vector3(9.6, 0, -4.5), Vector3(9.0, 0, -5.2), Vector3(9.3, 0, -7.1)],
	[Vector3(6.5, 0, -7.45)],
	[Vector3(10.75, 0, -7.5)],
]

var tut: Node = null
var floor_node: Node3D = null
var trainer: TrainerAmable = null
var promo: Array[PromoActor] = []
var scene: String = "clase"
var cues: Dictionary = {}
var last_cue: String = ""  # pruebas
var cue_log: Array[String] = []  # pruebas
var _look: Dictionary = {}  # actor -> s que le quedan mirándote
var _pending: Array = []  # [segundos, Callable] (gestos escalonados)
var _spot: String = "centro"
var name_shown: bool = false  # el cartelito con tu nombre ya está en tu mesa (desde que se lo dices al Trainer)
## Reacciones que arrancan cuando EMPIEZA la línea (las demás, cuando termina).
const AT_START := ["gesto", "saludan"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cues = (Tutorial.data().get("reacciones", {}) as Dictionary)


# --- piso ------------------------------------------------------------------------------------------------

## El piso 1 se cargó (o se volvió a cargar): toma a los actores y rearma la escena en curso, sin caminar.
func bind(fl: Node3D, p_trainer: TrainerAmable) -> void:
	floor_node = fl
	trainer = p_trainer
	promo.clear()
	for i in TrainingRoom.CLASS.size():
		var a := fl.find_child("Promocion%d" % i, false, false) as PromoActor
		if a != null:
			promo.append(a)
	_look.clear()
	_pending.clear()
	_apply.call_deferred(true)
	_name_card.call_deferred()


func ready_on_floor() -> bool:
	return floor_node != null and is_instance_valid(floor_node) and floor_node.is_inside_tree() and trainer != null and is_instance_valid(trainer)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## El jugador en coordenadas del piso (o su silla si no está en el piso).
func player_local() -> Vector3:
	var pl := _player()
	if pl == null or not ready_on_floor():
		return TrainingRoom.EYE
	var p := floor_node.to_local(pl.global_position)
	return Vector3(p.x, 0, p.z)


func actor(who: String) -> PromoActor:
	for a in promo:
		if is_instance_valid(a) and a.who == who:
			return a
	return null


# --- escenas ----------------------------------------------------------------------------------------------

## Al empezar un módulo: si la escena no es la que toca (se saltó un módulo, se entró por el menú), se acomodan ya.
func module_start(m: Dictionary) -> void:
	if str(m.get("id", "")) != "llegada":
		name_shown = true  # (se entró por otro módulo: el Trainer ya sabe cómo te llamas)
	_name_card()
	var want := str(m.get("escena", "clase"))
	_spot = str(m.get("trainer", "cafe" if want == "cafe" else "centro"))
	if want != scene:
		scene = want
		_apply(true)
	elif ready_on_floor():
		trainer.go(_spot)


## Cambia de escena caminando (o al instante).
func set_scene(p_scene: String, instant: bool = false) -> void:
	if not SCENES.has(p_scene) or (p_scene == scene and not instant):
		return
	var from := scene
	scene = p_scene
	if not ready_on_floor():
		return
	if instant:
		_apply(true)
		return
	for i in promo.size():
		var a := promo[i]
		if not is_instance_valid(a):
			continue
		var c: Dictionary = TrainingRoom.CLASS[i]
		var delay := 0.25 + 0.45 * i  # no se paran todos a la vez
		match scene:
			"cafe":
				_later(delay, _go_cafe.bind(a, i))
			"foto":
				_later(delay, _go_foto.bind(a, i))
			"clase":
				var back: Array = (VIA_CAFE[i] if from == "cafe" else VIA_FOTO[i]).duplicate()
				back.reverse()
				_later(delay, func() -> void:
					if is_instance_valid(a):
						a.look_at_player(false)
						a.walk_and_sit(back, c["silla"], c["mira"], "sit"))
	match scene:
		"cafe":
			_spot = "cafe"
			trainer.go("cafe", func() -> void: _hold(trainer, "cup"))
		"foto":
			pass  # el Trainer pone la cámara y después va a su sitio (Tutorial._group_photo)
		"clase":
			_spot = "centro"
			trainer.go(_spot)


func _go_cafe(who: Variant, i: int) -> void:  # sin tipo: llega por un `bind` diferido y el actor pudo liberarse antes
	if not is_instance_valid(who):
		return
	var a := who as PromoActor
	var c: Dictionary = TrainingRoom.CLASS[i]
	var face: Vector3 = TrainingRoom.COFFEE_STAND - (c["cafe"] as Vector3)
	a.walk((VIA_CAFE[i] as Array) + [c["cafe"]], face, func() -> void: _hold(a, "cup"))


func _go_foto(who: Variant, i: int) -> void:
	if not is_instance_valid(who):
		return
	var a := who as PromoActor
	var c: Dictionary = TrainingRoom.CLASS[i]
	var face: Vector3 = TrainingRoom.PHOTO_CAM - (c["foto"] as Vector3)
	a.walk((VIA_FOTO[i] as Array) + [c["foto"]], face, func() -> void: _hold(a, "pose_a" if i % 2 == 0 else "pose_b"))


## Clip de reposo de pie (la taza, la pose de la foto): queda en bucle y a él vuelve después de cada gesto.
func _hold(a: TrainingActor, clip: String) -> void:
	if not is_instance_valid(a) or a.seated or not a.has_gesture(clip):
		return
	a.base_clip = TrainingActor.T32 + "/" + clip
	if a.rig != null and a.busy_gesture == "":
		a.rig.play(a.base_clip, true)


## Pone a todos en la escena en curso, sin caminar.
func _apply(_instant: bool = true) -> void:
	if not ready_on_floor():
		return
	_pending.clear()
	for i in promo.size():
		var a := promo[i]
		if not is_instance_valid(a):
			continue
		var c: Dictionary = TrainingRoom.CLASS[i]
		a.look_at_player(false)
		match scene:
			"cafe":
				a.place_standing(c["cafe"], TrainingRoom.COFFEE_STAND - (c["cafe"] as Vector3))
				_hold(a, "cup")
			"foto":
				a.place_standing(c["foto"], TrainingRoom.PHOTO_CAM - (c["foto"] as Vector3))
				_hold(a, "pose_a" if i % 2 == 0 else "pose_b")
			_:
				a.place_seated(c["silla"], c["mira"], "type" if i % 2 == 1 else "sit")
	var spot := "foto" if scene == "foto" else _spot
	trainer.place(spot)
	if spot == "cafe":
		_hold(trainer, "cup")
	_follow_player()


# --- pasos --------------------------------------------------------------------------------------------------

## Cada paso: la escena que pide (caminando) y el sitio del Trainer (el que diga el paso; si no, a tu mesa en la
## práctica con la PC y al centro en la explicación).
func step_start(s: Dictionary, running_module: String) -> void:
	if s.has("escena"):
		set_scene(str(s["escena"]))
	if not ready_on_floor():
		return
	var table := floor_node.find_child("MesaCafe", true, false)
	if table != null:
		table.set("toast", str(s.get("id", "")) == "brindis")
	var tipo := str(s.get("tipo", "leer"))
	var cond := str(s.get("cond", ""))
	var want := str(s.get("trainer", ""))
	if want == "" and scene == "clase":
		if tipo == "esperar" and not cond.begins_with("piso:") and cond not in ["fuera_sala", "dormido", "despierto", "manual_abierto", "cafe", "sentado", "comodin_abierto", "comodin_hecho", "muerte_vista", "reconectado", "rub_eyes"]:
			want = "mesa"
		elif tipo in ["leer", "pregunta", "elegir"]:
			want = "centro"
	if want != "" and (scene == "clase" or s.has("trainer")):
		_spot = want
		trainer.go(want, (func() -> void: _hold(trainer, "cup")) if want == "cafe" else Callable())
	_follow_player()
	if s.has("gesto"):  # un gesto del Trainer al empezar el paso (welcome, wave…), cuando ya llegó a su sitio
		var clip := str(s["gesto"])
		_later(0.2, func() -> void: _gesture_when_there(clip, 6.0))
	if running_module != "" and s.has("cue"):
		cue(str(s["cue"]))


## El Trainer te sigue con el cuerpo salvo cuando mira tu pantalla o posa.
func _follow_player() -> void:
	if not ready_on_floor():
		return
	var on := trainer.mode() not in ["mesa", "foto"]
	trainer.track(_player() if on else null)
	trainer.look_at_player(true)


# --- líneas ------------------------------------------------------------------------------------------------

## Empieza una línea del guion (TrainingVoice). `l` = la línea resuelta: quien (trainer | promo | piensa), nombre.
func line_start(l: Dictionary) -> void:
	if not ready_on_floor():
		return
	var id := str(l.get("id", ""))
	var c := str(cues.get(id, ""))
	match str(l.get("quien", "")):
		"trainer":
			trainer.speak_line(40.0, str(l.get("texto", "")).contains("¡"))
			if c.begins_with("gesto:"):
				trainer.gesture(c.substr(6))
			elif c != "" and AT_START.has(c.get_slice(":", 0)):
				cue(c)
		"promo":
			var a := actor(str(l.get("nombre", "")))
			if a != null:
				a.talk(40.0)
				a.look_at_player(true)
				if not a.seated and not a.is_walking():
					a.turn_to(player_local())
				_look[a] = 999.0


## Terminó la línea: quien hablaba calla y la clase reacciona si la línea lo pide.
func line_end(l: Dictionary) -> void:
	if not ready_on_floor():
		return
	match str(l.get("quien", "")):
		"trainer":
			trainer.hush()
		"promo":
			var a := actor(str(l.get("nombre", "")))
			if a != null:
				a.hush()
				_look[a] = LOOK_BACK_S
	var c := str(cues.get(str(l.get("id", "")), ""))
	if c != "" and not AT_START.has(c.get_slice(":", 0)):
		cue(c)


## Segundos de silencio extra después de una línea (la risa, el aplauso): TrainingVoice los espera.
func pause_after(id: String) -> float:
	var c := str(cues.get(id, ""))
	if c.begins_with("risa"):
		return 0.9
	if c.begins_with("aplauso") or c.begins_with("festejo"):
		return 1.4
	return 0.0


## Reacción de la clase. risa · risa:<nombre> · aplauso · festejo · miran (te miran) · asienten · mano:<nombre> ·
## saluda:<nombre> · trainer:<gesto>.
func cue(c: String) -> void:
	last_cue = c
	cue_log.append(c)
	if not ready_on_floor():
		return
	var arg := c.get_slice(":", 1) if c.contains(":") else ""
	match c.get_slice(":", 0):
		"risa":
			for a in promo:
				if is_instance_valid(a) and (arg == "" or a.who == arg):
					_later(randf_range(0.0, 0.35), _gest.bind(a, "laugh_sit", "laugh"))
		"aplauso":
			AudioManager.play_sfx("aplausos", "Sala")
			for a in promo:
				if is_instance_valid(a):
					_later(randf_range(0.0, 0.3), _gest.bind(a, "clap_sit", "clap"))
		"festejo":
			AudioManager.play_sfx("aplausos", "Sala")
			for i in promo.size():
				if is_instance_valid(promo[i]):
					_later(randf_range(0.0, 0.3), _gest.bind(promo[i], "cheer_sit" if i % 2 == 0 else "clap_sit", "clap"))
		"miran":
			for a in promo:
				if is_instance_valid(a):
					a.look_at_player(true)
					_look[a] = 3.5
		"asienten":
			for a in promo:
				if is_instance_valid(a):
					_later(randf_range(0.0, 0.5), _gest.bind(a, "nod_sit", "nod"))
		"mano":
			var a2 := actor(arg)
			if a2 != null:
				_gest(a2, "hand_up", "wave")
		"saluda":
			var a3 := actor(arg)
			if a3 != null:
				a3.look_at_player(true)
				_look[a3] = 3.0
				_gest(a3, "hand_up", "wave")
		"saludan":  # el Trainer los nombra uno por uno («Nayra, Yimi, Zuly, Kenyi»): cada uno te saluda a su turno
			for i in promo.size():
				var a5 := promo[i]
				if is_instance_valid(a5):
					_later(2.5 + 0.62 * i, func() -> void:
						if is_instance_valid(a5):
							a5.look_at_player(true)
							_look[a5] = 3.2
							_gest(a5, "hand_up", "wave"))
		"bosteza":
			var a6 := actor(arg)
			if a6 != null and a6.rig != null and a6.rig.has_anim("yawn"):
				_gest(a6, "yawn", "yawn")
		"nombre":  # tu nombre queda en un cartelito sobre tu mesa, como los de los demás
			name_shown = true
			_name_card()
		"trainer":
			trainer.gesture(arg)
		"ofrece":  # te tiende la mano y la deja tendida hasta que respondas
			if not trainer.is_walking():
				trainer.track(null)
				trainer.turn_to(player_local())
				trainer.gesture_hold("handshake", 0.8)
		"aprieta":  # se la das: el apretón (a dos manos) y suelta
			if trainer.busy_gesture == "handshake":
				trainer.resume_gesture()
			else:
				trainer.gesture("handshake")
		"suelta":  # no se la das: baja la mano y asiente
			trainer._end_gesture()
			trainer.gesture("nod")
		"va":  # el Trainer camina a uno de sus sitios
			_spot = arg
			trainer.go(arg, (func() -> void: _hold(trainer, "cup")) if arg == "cafe" else Callable())
			_follow_player()
		"escena":
			set_scene(arg)
		"contratos":  # el contrato y el lapicero llegan a cada mesa
			for n in floor_node.find_children("ContratoMesa", "MeshInstance3D", true, false):
				(n as Node3D).visible = true
		"firman":
			for a in promo:
				if is_instance_valid(a) and a.seated and a.has_gesture("sign"):
					a.base_clip = TrainingActor.T32 + "/sign"
					if a.rig != null:
						a.rig.play(a.base_clip, true)
		"firmaron":
			AudioManager.play_sfx("aplausos", "Sala")
			for i in promo.size():
				var a4 := promo[i]
				if is_instance_valid(a4) and a4.seated:
					a4.base_clip = "sit"
					_later(randf_range(0.0, 0.4), _gest.bind(a4, "cheer_sit" if i % 2 == 0 else "clap_sit", "clap"))


func _gesture_when_there(clip: String, patience: float) -> void:
	if not ready_on_floor():
		return
	if trainer.is_walking() and patience > 0.0:
		_later(0.25, func() -> void: _gesture_when_there(clip, patience - 0.25))
	else:
		trainer.gesture(clip)


func _name_card() -> void:
	if floor_node == null or not is_instance_valid(floor_node):
		return
	var card := floor_node.find_child(TrainingRoom.NAME_CARD, true, false) as Node3D
	if card != null:
		card.visible = name_shown


func _gest(who: Variant, seated_clip: String, standing_clip: String) -> void:
	if not is_instance_valid(who):
		return  # el gesto estaba en cola y el piso se recargó (bajaste al -1, volviste al menú): ese actor ya no existe
	var a := who as TrainingActor
	if a != null and not a.is_walking():
		a.gesture(seated_clip if a.seated else standing_clip)


func _later(secs: float, fn: Callable) -> void:
	_pending.append([secs, fn])


func _process(delta: float) -> void:
	if not _pending.is_empty():
		var keep: Array = []
		var run: Array = []
		for p in _pending:
			p[0] = float(p[0]) - delta
			if float(p[0]) <= 0.0:
				run.append(p[1])
			else:
				keep.append(p)
		_pending = keep
		for fn in run:
			if (fn as Callable).is_valid():
				(fn as Callable).call()
	if not _look.is_empty():
		for a in _look.keys():
			if not is_instance_valid(a):
				_look.erase(a)
				continue
			_look[a] = float(_look[a]) - delta
			if float(_look[a]) <= 0.0:
				_look.erase(a)
				(a as TrainingActor).look_at_player(false)
				if not (a as TrainingActor).seated and scene == "cafe" and not (a as TrainingActor).is_walking():
					(a as TrainingActor).turn_to(TrainingRoom.COFFEE_STAND)
	if ready_on_floor():
		trainer.set_eye(player_local())

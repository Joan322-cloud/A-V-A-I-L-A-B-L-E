extends Node
## AudioDirector (v0.3 P6a, hijo del AudioManager): el sonido del mundo que no pertenece a un solo script.
##  · Pasos del jugador (v0.3.1 Q3, F25): pasos de verdad, talón-punta, por superficie — alfombra (sala de PCs),
##    porcelanato negro (halls, lobby), vinílico madera (training, zonas de trabajo marcadas «vinilico»), escalera
##    (concreto + eco de la caja), exterior mojado (calle, charcos) y deck (azotea) —, 8 variantes caminando y un set
##    de carrera propio (6, más pesado), a la cadencia del head bob (2,55 pasos/s caminando, 3,8 corriendo),
##    alternando pie izquierdo/derecho (pan ±0,15, buses PasosL/PasosR con la reverb de la superficie) y con la
##    respiración de carrera que sube con el aliento gastado. Aterrizaje del salto por superficie
##    (sfx/pasos/aterrizaje_<sup>_01..03) con EventBus.player_landed (C15, Q1) o, si esa señal todavía no existe,
##    detectando la caída. Nada sentado, acostado, en cinemática o en el aire.
##  · Música adaptativa (MusicDirector, B4) y lluvia larga (RainEngine, B4): ver sus scripts.
##  · Carrera de los cazadores: en una persecución (pursuit_started) el cazador lleva un bucle 3D de pasos de carrera
##    (sfx/shero_corre_loop para Shero, pasos de porcelanato rápidos para el Trainer) y, al entrar a tu piso,
##    sfx/shero_corre_acerca. Se quita en pursuit_ended o al morir.
##  · Ambiente por piso (además de los bucles que pone cada piso): sala de PCs con oficina lejana y fluorescentes; la
##    lluvia es del RainEngine; con Dread alto los fluorescentes "mueren" (fluorescente_muriendo_loop).
##  · Música de Rasec que se degrada (B4): cualquier reproductor que esté tocando musica/rasec_* pasa por el bus
##    RasecDegrada; con el tiempo (y con la presión) se desafina, se ensucia y se apaga el brillo.
##  · Colapso (muerte sin asesino: fatiga/colapso): latido lento, acúfeno y, si estabas de pie, la caída del cuerpo.
##  · Auricular y PC: auricular_conecta al contestar una llamada, auricular_cliente_cuelga cuando el cliente se va
##    molesto, correo_recibido al entrar un correo/KYC, correo_enviado al enviar uno y ui_click_v2 en los botones.
##  · Clips cosechados de ambiente: los compañeros de la fila hablando con su cliente y el inodoro al salir del baño.
## Todo con AudioManager (respeta buses y volúmenes); si falta un archivo no suena nada (sin pitidos).

const SURFACES: Array[String] = ["alfombra", "porcelanato", "vinilico", "escalera", "exterior", "deck"]
## reverb del bus de pasos por superficie: [room_size, wet, damping]
const SURFACE_REVERB := {
	"alfombra": [0.25, 0.03, 0.85], "porcelanato": [0.55, 0.16, 0.35], "vinilico": [0.4, 0.08, 0.55],
	"escalera": [0.8, 0.32, 0.3], "exterior": [0.2, 0.03, 0.7], "deck": [0.2, 0.04, 0.6],
}
const WALK_CADENCE := 2.55  # pasos por segundo (= 2 por ciclo del head bob de player.gd a 8 rad/s)
const RUN_CADENCE := 3.8  # (12 rad/s)
const FLOOR_AMBIENT := {
	2: [["oficina_lejana_loop", -15.0], ["fluorescente_sala_loop", -17.0]],
	1: [["oficina_lejana_loop", -24.0]],
}

var _player: Node3D = null
var _dist: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _zones: Dictionary = {}
var _step_players: Array[AudioStreamPlayer] = []
var _foot: int = 0
var _phase: float = 0.0
var _breath: AudioStreamPlayer = null
var _breath_lvl: float = 0.0
var _air_t: float = 0.0
var _air_top: float = -INF
var music: MusicDirector = null
var rain: RainEngine = null
var landings: int = 0  # pruebas
var last_landing: String = ""
var _rasec_players: Array = []  # weakrefs de reproductores que tocan musica/rasec_*
var _hunters: Dictionary = {}  # hunter -> AudioStreamPlayer3D
var _dread_t: float = 0.0
var _floor: int = 0
var steps_played: int = 0  # pruebas
var _zone_in: Dictionary = {}  # zona -> ticks de entrada
var murmur_t: float = 75.0  # s reales hasta el próximo compañero hablando con su cliente
const MURMURS := {"agente_juan": ["juan_crm", "juan_llamada"], "agente_marko": ["marko_linea"]}
var horror: HorrorAmbience = null
var last_surface: String = ""
var last_step_slot: String = ""  # pruebas: sfx/pasos/<pasos|correr>_<superficie>


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for side in ["PasosL", "PasosR"]:
		var sp := AudioStreamPlayer.new()
		sp.name = "Pasos" + side.substr(5)
		sp.bus = side
		add_child(sp)
		_step_players.append(sp)
	_breath = AudioStreamPlayer.new()
	_breath.name = "RespiracionCarrera"
	_breath.bus = "Sala"
	_breath.volume_db = -60.0
	add_child(_breath)
	music = MusicDirector.new()
	music.name = "MusicDirector"
	add_child(music)
	rain = RainEngine.new()
	rain.name = "RainEngine"
	add_child(rain)
	horror = HorrorAmbience.new()  # v0.3.1 (audio_horror_v2): sustos sonoros sueltos en T2/T3
	horror.name = "HorrorAmbience"
	add_child(horror)
	if EventBus.has_signal("player_landed"):  # C15 (Q1): la caída en metros
		EventBus.connect("player_landed", func(caida: float) -> void: land(caida))
	if EventBus.has_signal("player_jumped"):
		EventBus.connect("player_jumped", func() -> void: jumped())
	EventBus.player_entered_zone.connect(func(z: String) -> void:
		_zones[z] = true
		_zone_in[z] = Time.get_ticks_msec()
		if z.begins_with("ventilacion_"):
			_update_vent())
	EventBus.player_exited_zone.connect(_on_zone_exit)
	EventBus.player_floor_changed.connect(_on_floor)
	EventBus.pursuit_started.connect(_on_pursuit_started)
	EventBus.pursuit_ended.connect(func(h: String, _r: String) -> void: _stop_hunter(h))
	EventBus.hunter_entered_floor.connect(_on_hunter_floor)
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: _stop_all_hunters())
	EventBus.returned_to_menu.connect(_stop_all_hunters)
	# v0.3.1 (integración): la música de play_music va en bucle; al volver al menú no sigue sonando la del turno.
	EventBus.returned_to_menu.connect(AudioManager.stop_music)
	EventBus.contact_offered.connect(func(c: Dictionary) -> void:
		if ContactManager.is_bo(c):
			AudioManager.play_sfx("correo_recibido", "UI"))
	EventBus.contact_accepted.connect(func(c: Dictionary) -> void:
		if not ContactManager.is_bo(c):
			AudioManager.play_sfx("auricular_conecta", "Auricular"))
	EventBus.contact_outcome.connect(func(c: Dictionary, outcome: String, _csat: int) -> void:
		if outcome == "molesto" and not ContactManager.is_bo(c):
			AudioManager.play_sfx("auricular_cliente_cuelga", "Auricular"))
	EventBus.email_sent.connect(func(_r: String, _t: String) -> void: AudioManager.play_sfx("correo_enviado", "UI"))
	get_tree().node_added.connect(_on_node_added)


func _on_floor(f: int) -> void:
	_floor = f
	_zones.clear()
	vent_on = false
	_stop_all_hunters()
	# Los pisos ponen sus bucles al cargarse; los nuestros van un poco después (stop_ambient corre primero).
	get_tree().create_timer(0.3, false).timeout.connect(_floor_ambience.bind(f))


func _floor_ambience(f: int) -> void:
	if f != _floor:
		return
	for pair in FLOOR_AMBIENT.get(f, []):
		AudioManager.play_ambient(str(pair[0]), float(pair[1]))
	if GameState.running or f in [-1, 9]:
		rain.start(f)


## Superficie bajo los pies. Las zonas explícitas de Q5 (C15: «vinilico», «exterior», y si las pone, «alfombra» y
## «porcelanato») mandan; si no, lo de siempre: escalera, azotea, sala de PCs, calle, training y el resto porcelanato.
func surface() -> String:
	var fl := FloorBase.active
	if fl is Stairwell:
		return "escalera"
	for z in ["exterior", "vinilico", "alfombra", "porcelanato"]:
		if _zones.has(z):
			return z
	if _zones.has("calle"):
		return "exterior"
	if _floor == 9 and not _zones.has("azotea_vestibulo"):
		return "deck"
	if _floor == 2 and (_zones.has("sala") or _zones.has("fila_c")):
		return "alfombra"
	for z in _zones.keys():
		if str(z).begins_with("training") or str(z) == "sala_calibracion":
			return "vinilico"
	return "porcelanato"


func _physics_process(delta: float) -> void:
	murmur_t -= delta / maxf(Engine.time_scale, 0.01)
	if murmur_t <= 0.0:
		murmur_t = randf_range(60.0, 120.0)
		murmur()
	_dread_t -= delta
	if _dread_t <= 0.0:
		_dread_t = 1.0
		_update_dread()
	_rasec_degrade(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		_last_pos = Vector3.INF
		if _player == null:
			_breath_to(0.0, delta)
			return
	var p := _player as Player
	var pos := _player.global_position
	if _last_pos == Vector3.INF:
		_last_pos = pos
		return
	var d := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	var dy := pos.y - _last_pos.y
	_last_pos = pos
	_track_air(p, pos, delta)
	var speed := d / maxf(delta, 1e-4)
	var running := speed > 5.4
	_breath_to(_breath_target(p, running and speed > 0.6), delta)
	if p == null or p.seated or p.lying or p.cinematic or not p.is_on_floor() or d > 1.5 or absf(dy) > 1.0:
		_phase = 0.0
		return
	if speed < 0.6:
		_phase = minf(_phase, 0.45)  # al volver a caminar el primer paso sale enseguida
		return
	_phase += delta * (RUN_CADENCE if running else WALK_CADENCE) * clampf(speed / (6.5 if running else 5.0), 0.55, 1.3)
	if _phase >= 1.0:
		_phase -= floorf(_phase)
		_step(running)


func _step(running: bool) -> void:
	var s := surface()
	last_surface = s
	var slot := "sfx/pasos/%s_%s" % ["correr" if running else "pasos", s]
	last_step_slot = slot
	var st := AudioManager.stream_for(slot)
	if st == null:
		return
	_apply_reverb(s)
	var sp := _step_players[_foot]
	_foot = 1 - _foot
	sp.stream = st
	sp.volume_db = (-5.0 if running else -8.0) + randf_range(-1.5, 1.0)
	sp.pitch_scale = randf_range(0.96, 1.04)
	sp.play()
	steps_played += 1


func _apply_reverb(s: String) -> void:
	var cfg: Array = SURFACE_REVERB.get(s, [0.4, 0.08, 0.5])
	for b in ["PasosL", "PasosR"]:
		var rv := AudioManager.bus_effect(b, 1) as AudioEffectReverb
		if rv != null:
			rv.room_size = float(cfg[0])
			rv.wet = float(cfg[1])
			rv.damping = float(cfg[2])


## Aterrizaje de un salto o de una caída corta (C15: EventBus.player_landed(caida_m)).
func land(caida_m: float = 0.45) -> void:
	if caida_m < 0.2:
		return
	var s := surface()
	var st := AudioManager.stream_for("sfx/pasos/aterrizaje_" + s)
	if st == null:
		return
	_apply_reverb(s)
	var sp := _step_players[_foot]
	_foot = 1 - _foot
	sp.stream = st
	sp.volume_db = -4.0 + clampf((caida_m - 0.45) * 6.0, -3.0, 4.0)
	sp.pitch_scale = randf_range(0.96, 1.03)
	sp.play()
	landings += 1
	last_landing = s
	_phase = 0.0


## Impulso del salto: el roce del zapato al despegar (un paso de punta, bajito).
func jumped() -> void:
	var st := AudioManager.stream_for("sfx/pasos/correr_" + surface())
	if st == null:
		return
	var sp := _step_players[_foot]
	sp.stream = st
	sp.volume_db = -13.0
	sp.pitch_scale = 1.08
	sp.play()


## Sin la señal de Q1: detecta la caída (en el aire > 0,15 s y ≥ 0,25 m de diferencia) y suena el aterrizaje.
func _track_air(p: Player, pos: Vector3, delta: float) -> void:
	if EventBus.has_signal("player_landed") or p == null:
		return
	if p.seated or p.lying or p.cinematic:
		_air_t = 0.0
		return
	if not p.is_on_floor():
		_air_t += delta
		_air_top = maxf(_air_top, pos.y)
		return
	if _air_t > 0.15 and _air_top - pos.y >= 0.25 and not (FloorBase.active is Stairwell):
		land(_air_top - pos.y + 0.2)
	_air_t = 0.0
	_air_top = -INF


func _breath_target(p: Player, running: bool) -> float:
	if p == null or p.seated or p.lying or p.cinematic:
		return 0.0
	var spent := 1.0 - clampf(p.breath_left / maxf(p.breath, 0.01), 0.0, 1.0)
	return clampf(spent * 1.1 + (0.25 if running else 0.0), 0.0, 1.0) if (running or spent > 0.15) else 0.0


func _breath_to(target: float, delta: float) -> void:
	_breath_lvl = move_toward(_breath_lvl, target, delta / maxf(Engine.time_scale, 0.01) * (0.8 if target > _breath_lvl else 0.35))
	if _breath_lvl <= 0.01:
		if _breath.playing:
			_breath.stop()
		return
	if not _breath.playing:
		var st := AudioManager.stream_for("sfx/respiracion_carrera_loop", true)
		if st == null:
			return
		_breath.stream = st
		_breath.play(randf_range(0.0, st.get_length()))
	_breath.volume_db = -16.0 + linear_to_db(_breath_lvl)


func _slot(path: String) -> String:
	return path.trim_prefix(AudioManager.AUDIO_ROOT).trim_suffix(".ogg").trim_suffix(".wav")


# --- cazadores ------------------------------------------------------------------

func _hunter_node(hunter: String) -> Node3D:
	for n in get_tree().get_nodes_in_group(hunter):
		if n is Node3D and (n as Node3D).is_inside_tree() and (n as Node3D).visible:
			return n
	var fl := FloorBase.active
	if fl != null:
		var c := fl.find_child("Cazador_" + hunter, true, false) as Node3D
		if c != null:
			return c
	return null


func _on_pursuit_started(hunter: String, _cause: String) -> void:
	await get_tree().process_frame
	_attach_run(hunter)


func _attach_run(hunter: String) -> void:
	if _hunters.has(hunter) and is_instance_valid(_hunters[hunter]):
		return
	var n := _hunter_node(hunter)
	if n == null:
		return
	var slot := "sfx/shero_corre_loop" if hunter == "shero" else "sfx/latido_rapido_loop" if hunter == "rta" else "sfx/pasos_porcelanato_v2"
	var st := AudioManager.stream_for(slot, true)
	if st == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.name = "CarreraAudio"
	a.stream = st
	a.bus = "Sala"
	a.unit_size = 4.0
	a.max_distance = 40.0
	a.volume_db = -2.0 + AudioManager.gain_db(slot)
	a.position = Vector3(0, 0.3, 0)
	n.add_child(a)
	a.play()
	_hunters[hunter] = a


func _on_hunter_floor(hunter: String, f: int) -> void:
	if f != GameState.current_floor:
		return
	if hunter == "shero":
		AudioManager.play_sfx("shero_corre_acerca")
	get_tree().create_timer(0.5, false).timeout.connect(_attach_run.bind(hunter))


func _stop_hunter(hunter: String) -> void:
	if _hunters.has(hunter):
		var a: Variant = _hunters[hunter]
		if a != null and is_instance_valid(a):
			(a as Node).queue_free()
		_hunters.erase(hunter)


func _stop_all_hunters() -> void:
	for h in _hunters.keys():
		_stop_hunter(str(h))


# --- colapso y UI -------------------------------------------------------------

## v0.3.2 (integración): el colapso por Fatiga lo suena entero DeathAnimations (latidos, respiración y golpes a nivel de
## sala, a tiempo con la caída actuada en tercera persona). Aquí estaban las tres señales de la versión en primera
## persona (latido a 0 s, acúfeno a 0,9 s y caída a 1,6 s, a nivel pleno): no iban con la caída nueva y pegaban en el
## limitador; se quitaron junto con el corte que las callaba desde DeathAnimations.


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).has_meta("sin_click"):
		if not (n as BaseButton).pressed.is_connected(_click):  # reparent (p. ej. la pausa a su capa) = otro node_added
			(n as BaseButton).pressed.connect(_click, CONNECT_DEFERRED)
	elif n is AudioStreamPlayer and n.get_parent() != null and n.get_parent() != self and n.get_parent() != AudioManager:
		_rasec_players.append(weakref(n))
	elif n.name == "Trafico" and n.get_parent() != null and n.get_parent().name == "EntornoEste":
		_attach_highway.call_deferred(n)


# --- entorno de Q5: autopista del este y ventilación del piso 2 (v0.3.1) --------------------------------

var highway: HighwayAudio = null  # pruebas
var vent_on: bool = false  # pruebas
const VENT_DB := -17.0


func _attach_highway(traffic: Node) -> void:
	if not is_instance_valid(traffic) or traffic.get_parent() == null or traffic.get_parent().has_node("RumorAutopista"):
		return
	var h := HighwayAudio.new()
	h.name = "RumorAutopista"
	h.setup(traffic)
	traffic.get_parent().add_child(h)
	highway = h


## Siseo de las rejillas en las zonas «ventilacion_*» que arma Q5 en el piso 2 (pasando el molinete).
func _update_vent() -> void:
	var on := false
	for z in _zones.keys():
		if str(z).begins_with("ventilacion_"):
			on = true
			break
	if on == vent_on and (not on or AudioManager.has_ambient("ventilacion_loop")):
		return
	vent_on = on
	if on:
		AudioManager.play_ambient("ventilacion_loop", VENT_DB)
	else:
		AudioManager.stop_ambient("ventilacion_loop")


# --- música de Rasec que se degrada (B4) ----------------------------------------------------------------

var rasec_degrade: float = 0.0  # 0 = limpia, 1 = arruinada (pruebas)
var _rasec_t: float = 0.0
var _rasec_scan: float = 0.0
var _rasec_now: AudioStreamPlayer = null
var _rasec_bus_prev: String = ""


func _is_rasec(p: AudioStreamPlayer) -> bool:
	if p == null or not p.playing or p.stream == null:
		return false
	var path := p.stream.resource_path
	if path == "" and p.stream.has_meta("slot"):
		path = str(p.stream.get_meta("slot"))
	return path.contains("/musica/rasec_") or path.begins_with("musica/rasec_")


func _rasec_degrade(delta: float) -> void:
	var dt := delta / maxf(Engine.time_scale, 0.01)
	_rasec_scan -= dt
	if _rasec_scan <= 0.0:
		_rasec_scan = 0.5
		if _rasec_now != null and (not is_instance_valid(_rasec_now) or not _is_rasec(_rasec_now)):
			if is_instance_valid(_rasec_now) and _rasec_bus_prev != "":
				_rasec_now.bus = _rasec_bus_prev
			_rasec_now = null
		if _rasec_now == null:
			var alive: Array = []
			for w in _rasec_players:
				var n: Variant = (w as WeakRef).get_ref()
				if n != null:
					alive.append(w)
					if _is_rasec(n as AudioStreamPlayer):
						_rasec_now = n
						_rasec_bus_prev = str((n as AudioStreamPlayer).bus)
						(n as AudioStreamPlayer).bus = "RasecDegrada"
						_rasec_t = 0.0
			_rasec_players = alive
	var am_rasec := AudioManager.music_playing().begins_with("musica/rasec_")
	var on := _rasec_now != null or am_rasec
	music.set_rasec(on)
	if not on:
		rasec_degrade = 0.0
		_set_degrade(0.0, 0.0)
		return
	_rasec_t += dt
	# limpia los primeros 20 s; después se va pudriendo en ~90 s (antes con presión alta)
	rasec_degrade = clampf((_rasec_t - 20.0) / 90.0 + Dread.level() * 0.35, 0.0, 1.0)
	_set_degrade(rasec_degrade, _rasec_t)


func _set_degrade(k: float, t: float) -> void:
	var ps := AudioManager.bus_effect("RasecDegrada", 0) as AudioEffectPitchShift
	var di := AudioManager.bus_effect("RasecDegrada", 1) as AudioEffectDistortion
	var lp := AudioManager.bus_effect("RasecDegrada", 2) as AudioEffectLowPassFilter
	if ps != null:
		ps.pitch_scale = 1.0 - 0.09 * k + 0.012 * k * sin(t * TAU * 0.45)  # se desafina y «llora» como cinta gastada
	if di != null:
		di.drive = 0.45 * k
		di.pre_gain = 6.0 * k
		di.post_gain = -6.0 * k
	if lp != null:
		lp.cutoff_hz = lerpf(20000.0, 2200.0, k)


func _click() -> void:
	AudioManager.play_sfx("ui_click_v2", "UI")


# --- ambiente cosechado --------------------------------------------------------

func _on_zone_exit(z: String) -> void:
	_zones.erase(z)
	if z.begins_with("ventilacion_"):
		_update_vent()
	var since := (Time.get_ticks_msec() - int(_zone_in.get(z, Time.get_ticks_msec()))) / 1000.0
	_zone_in.erase(z)
	if z.begins_with("bano_") and since * Engine.time_scale >= 8.0 and GameState.running:
		AudioManager.play_sfx("inodoro")  # alguien (o tú) jala la cadena al salir


## Un compañero de la sala habla con su cliente (3D desde su sitio). Devuelve el reproductor o null.
func murmur() -> AudioStreamPlayer3D:
	if _floor != 2 or not GameState.running or GameState.shift_over or Checkpoints.dying or _player == null:
		return null
	var fl := FloorBase.active
	if fl == null:
		return null
	var cands: Array = []
	for r in fl.find_children("*", "Node3D", true, false):  # (el filtro por tipo no ve los class_name)
		var rig := r as CharacterRig
		if rig != null and MURMURS.has(rig.model_name) and rig.find_child("Murmullo", false, false) == null:
			var d := (rig as Node3D).global_position.distance_to(_player.global_position) if rig is Node3D else 99.0
			if d >= 2.0 and d <= 12.0:
				cands.append(rig)
	if cands.is_empty():
		return null
	if VoiceDirector.busy(VoiceDirector.P.BARK):
		return null  # v0.3.2: un murmullo nunca pisa otra voz (ni espera: se pierde)
	var rig: CharacterRig = cands[randi() % cands.size()]
	var clips: Array = MURMURS[rig.model_name]
	var slot := "voces/agentes/" + str(clips[randi() % clips.size()])
	var st := AudioManager.stream_for(slot)
	if st == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.name = "Murmullo"
	a.stream = st
	a.bus = "Sala"
	a.unit_size = 1.6
	a.max_distance = 14.0
	a.volume_db = -9.0 + AudioManager.gain_db(slot)
	a.position = Vector3(0, 1.1, 0)
	rig.add_child(a)
	a.finished.connect(a.queue_free)
	VoiceDirector.say_external(a, slot, VoiceDirector.P.BARK, "agentes", {"max_wait": 0.0, "free_on_drop": true})
	return a


# --- presión --------------------------------------------------------------------

func _update_dread() -> void:
	if _floor != 2 and _floor != 1:
		return
	var lvl := Dread.level()
	var on := AudioManager.has_ambient("fluorescente_muriendo_loop")
	if lvl > 0.6 and not on:
		AudioManager.play_ambient("fluorescente_muriendo_loop", -22.0 + (lvl - 0.6) * 20.0)
	elif lvl < 0.45 and on:
		AudioManager.stop_ambient("fluorescente_muriendo_loop")

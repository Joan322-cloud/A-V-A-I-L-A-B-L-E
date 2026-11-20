class_name RainEngine
extends Node
## Lluvia larga y fluida, sin bucle audible (v0.3.1 Q3, B4). Antes eran bucles de 30 s que se notaban.
##  · Dos camas largas de duración coprima (ambiente/lluvia 300 s y ambiente/lluvia_cama_b 247 s) que suenan a la
##    vez desde un punto al azar, con ganancias que derivan despacio y al azar (paseo aleatorio) y un pitch que se
##    mueve ±1,5 %: la suma no se repite (el patrón completo tardaría horas) y ninguna gota «se reconoce».
##  · Encima, eventos sueltos al azar en 3D alrededor del jugador: gotas grandes (chapa, vidrio, charco, baranda),
##    ráfagas de viento con lluvia que arrecia y canaletas que rebalsan (12 + 6 + 4 variantes, pitch y posición al
##    azar). Los truenos los sigue poniendo Weather (con más variantes de trueno_lejano/cercano).
##  · Todo por el bus «Lluvia» con un pasa bajos que cambia según dónde estás: a la intemperie (calle, azotea) se
##    oye entera; detrás del vidrio (sala, lobby, vestíbulo) apagada; en el piso 1 y la escalera, lejana.
## Adopta el reproductor de Weather (SonidoLluvia, Q5) sin tocar weather.gd: toma su volumen y lo silencia.

const BED_A := "ambiente/lluvia"
const BED_B := "ambiente/lluvia_cama_b"
## perfil -> [corte del pasa bajos (Hz), ganancia (dB), eventos por minuto: gotas, ráfagas, canaletas]
const PROFILES := {
	"exterior": [20000.0, 0.0, 9.0, 1.6, 1.0],
	"ventana": [2300.0, -7.0, 5.0, 1.2, 0.0],
	"lejano": [800.0, -15.0, 0.0, 0.6, 0.0],
	"ninguno": [600.0, -60.0, 0.0, 0.0, 0.0],
}
## piso -> [nivel base (dB, lo que pedía Weather o el piso), perfil por defecto]
const FLOORS := {
	-1: [-14.0, "ventana"], 1: [-20.0, "lejano"], 2: [-17.0, "ventana"], 9: [-13.0, "exterior"],
}
const EXTERIOR_ZONES: Array[String] = ["calle", "exterior"]
const VENTANA_ZONES_9: Array[String] = ["azotea_vestibulo"]

var bed_a: AudioStreamPlayer = null
var bed_b: AudioStreamPlayer = null
var profile: String = "ninguno"
var base_db: float = -60.0
var cutoff: float = 600.0
var gain_db: float = -60.0
var active: bool = false
var events_played: Dictionary = {"gota": 0, "rafaga": 0, "canaleta": 0}  # pruebas
var _walk_a: float = 0.0
var _walk_b: float = 0.0
var _pitch_a: float = 0.0
var _pitch_b: float = 0.0
var _next: Dictionary = {"gota": 4.0, "rafaga": 25.0, "canaleta": 40.0}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i: int = 0
var _rng := RandomNumberGenerator.new()
var adopted: Array = []  # reproductores de Weather adoptados (pruebas)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	bed_a = _bed("CamaA")
	bed_b = _bed("CamaB")
	for i in 5:
		var p := AudioStreamPlayer3D.new()
		p.name = "Evento%d" % i
		p.bus = "Lluvia"
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_pool.append(p)
	get_tree().node_added.connect(_on_node_added)
	EventBus.returned_to_menu.connect(stop)


func _bed(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = "Lluvia"
	p.volume_db = -60.0
	add_child(p)
	return p


## Empieza (o cambia) la lluvia del piso. level_db: nivel base (INF = el del piso, FLOORS).
func start(floor_id: int, level_db: float = INF) -> void:
	var cfg: Array = FLOORS.get(floor_id, [-22.0, "lejano"])
	base_db = float(cfg[0]) if level_db == INF else level_db
	if not active:
		var a := AudioManager.stream_for(BED_A, true)
		var b := AudioManager.stream_for(BED_B, true)
		if a == null:
			return
		bed_a.stream = a
		bed_a.play(_rng.randf_range(0.0, a.get_length()))
		if b != null:
			bed_b.stream = b
			bed_b.play(_rng.randf_range(0.0, b.get_length()))
		_walk_a = _rng.randf_range(-1.0, 1.0)
		_walk_b = _rng.randf_range(-1.0, 1.0)
	active = true
	_update_profile(true)


func stop() -> void:
	active = false
	bed_a.stop()
	bed_b.stop()
	for p in _pool:
		if p.is_inside_tree():
			p.stop()


func _zones() -> Dictionary:
	var dir := get_parent()
	return dir.get("_zones") if dir != null and dir.get("_zones") is Dictionary else {}


func current_profile() -> String:
	var f := GameState.current_floor
	if FloorBase.active is Stairwell:
		return "lejano"
	var z := _zones()
	for k in EXTERIOR_ZONES:
		if z.has(k):
			return "exterior"
	if f == 9:
		for k in VENTANA_ZONES_9:
			if z.has(k):
				return "ventana"
		return "exterior"
	var cfg: Array = FLOORS.get(f, [-22.0, "lejano"])
	return str(cfg[1])


func _update_profile(snap: bool = false) -> void:
	profile = current_profile()
	var pr: Array = PROFILES[profile]
	var tc := float(pr[0])
	var tg := base_db + float(pr[1])
	if snap:
		cutoff = tc
		gain_db = tg
	var lp := AudioManager.bus_effect("Lluvia", 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = cutoff


func _process(delta: float) -> void:
	if not active:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)
	profile = current_profile()
	var pr: Array = PROFILES[profile]
	# transición suave al entrar/salir (puerta de la calle, vestíbulo de la azotea)
	cutoff = exp(lerpf(log(maxf(cutoff, 50.0)), log(float(pr[0])), clampf(dt * 1.8, 0.0, 1.0)))
	gain_db = lerpf(gain_db, base_db + float(pr[1]), clampf(dt * 1.5, 0.0, 1.0))
	var lp := AudioManager.bus_effect("Lluvia", 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = cutoff
	# paseo aleatorio lento de cada cama (±3 dB) y del pitch (±1,5 %): la mezcla nunca vuelve a ser la misma
	_walk_a = clampf(_walk_a + _rng.randfn(0.0, 0.35) * sqrt(dt) - _walk_a * 0.02 * dt, -1.0, 1.0)
	_walk_b = clampf(_walk_b + _rng.randfn(0.0, 0.35) * sqrt(dt) - _walk_b * 0.02 * dt, -1.0, 1.0)
	_pitch_a = clampf(_pitch_a + _rng.randfn(0.0, 0.06) * sqrt(dt) - _pitch_a * 0.05 * dt, -1.0, 1.0)
	_pitch_b = clampf(_pitch_b + _rng.randfn(0.0, 0.06) * sqrt(dt) - _pitch_b * 0.05 * dt, -1.0, 1.0)
	bed_a.volume_db = gain_db - 2.0 + 3.0 * _walk_a + AudioManager.gain_db(BED_A)
	bed_b.volume_db = gain_db - 4.0 + 3.0 * _walk_b + AudioManager.gain_db(BED_B)
	bed_a.pitch_scale = 1.0 + 0.015 * _pitch_a
	bed_b.pitch_scale = 1.0 + 0.015 * _pitch_b
	for kind in ["gota", "rafaga", "canaleta"]:
		var rate := float(pr[{"gota": 2, "rafaga": 3, "canaleta": 4}[kind]])
		if rate <= 0.0:
			continue
		_next[kind] = float(_next[kind]) - dt
		if float(_next[kind]) <= 0.0:
			_next[kind] = _rng.randf_range(0.4, 1.6) * 60.0 / rate  # proceso de Poisson aproximado
			play_event(kind)


## Un evento suelto (gota grande, ráfaga, canaleta) en 3D alrededor del jugador. Devuelve el reproductor.
func play_event(kind: String) -> AudioStreamPlayer3D:
	var slot := "ambiente/lluvia_" + kind
	var st := AudioManager.stream_for(slot)
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if st == null or cam == null:
		return null
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	if not p.is_inside_tree():
		add_child(p)
	var ang := _rng.randf_range(0.0, TAU)
	var dist := _rng.randf_range(2.5, 7.0) if kind == "gota" else _rng.randf_range(6.0, 14.0)
	p.global_position = cam.global_position + Vector3(cos(ang) * dist, _rng.randf_range(-0.5, 2.5), sin(ang) * dist)
	p.stream = st
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.volume_db = gain_db + (4.0 if kind == "rafaga" else 2.0) + _rng.randf_range(-4.0, 1.0) + AudioManager.gain_db(slot)
	p.play()
	events_played[kind] = int(events_played[kind]) + 1
	return p


# --- Weather (Q5) --------------------------------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is AudioStreamPlayer and n.name == "SonidoLluvia" and n.get_parent() is Weather:
		_adopt.call_deferred(n)


func _adopt(n: AudioStreamPlayer) -> void:
	if not is_instance_valid(n):
		return
	n.stop()
	n.stream = null  # Weather ya no lo vuelve a tocar: la lluvia la pone este motor (nivel por piso, FLOORS)
	adopted.append(n)
	start(GameState.current_floor)

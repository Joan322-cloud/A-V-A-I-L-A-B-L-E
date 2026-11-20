class_name HighwayAudio
extends Node3D
## Rumor de la autopista elevada del este (v0.3.1 Q3, pedido de Q5). El AudioDirector lo cuelga del nodo «EntornoEste»
## que arma SiteProps.entorno_este (Q5) en el -1, el piso 2 y la azotea, leyendo el eje del tráfico de su nodo
## «Trafico» (_x, _y, _z0, _z1): sin tocar los scripts de Q5. Es una fuente lineal: el emisor 3D del rumor se mueve
## por el tablero al punto más cercano a la cámara, así que se oye más fuerte cerca de la fachada este y más bajo
## adentro. Cada 15-45 s pasa un camión (Doppler) cerca de ese punto. Va por el bus «Lluvia»: a la intemperie se oye
## entero; detrás del vidrio del piso 2, apagado (el mismo filtro de la lluvia).

const RUMOR := "ambiente/autopista_rumor_loop"
const CAMION := "ambiente/autopista_camion"

var axis_x: float = 0.0
var deck_y: float = 0.0
var z0: float = -100.0
var z1: float = 100.0
var rumble: AudioStreamPlayer3D = null
var truck: AudioStreamPlayer3D = null
var trucks: int = 0  # pruebas
var _next: float = 10.0
var _rng := RandomNumberGenerator.new()


func setup(traffic: Node) -> void:
	axis_x = float(traffic.get("_x"))
	deck_y = float(traffic.get("_y"))
	z0 = float(traffic.get("_z0"))
	z1 = float(traffic.get("_z1"))


func _ready() -> void:
	_rng.randomize()
	rumble = _emitter("Rumor", 26.0)
	truck = _emitter("Camion", 18.0)
	var st := AudioManager.stream_for(RUMOR, true)
	if st != null:
		rumble.stream = st
		rumble.volume_db = 2.0 + AudioManager.gain_db(RUMOR)
		rumble.play(_rng.randf_range(0.0, st.get_length()))
	_next = _rng.randf_range(6.0, 18.0)


func _emitter(n: String, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.bus = "Lluvia"
	p.unit_size = unit
	p.max_distance = 420.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.attenuation_filter_cutoff_hz = 9000.0
	add_child(p)
	return p


## Punto del tablero más cercano a la cámara (coordenadas locales del entorno).
func nearest_point() -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var local_z := 0.0
	if cam != null:
		local_z = (get_parent() as Node3D).to_local(cam.global_position).z if get_parent() is Node3D else cam.global_position.z
	return Vector3(axis_x, deck_y + 1.0, clampf(local_z, z0, z1))


func _process(delta: float) -> void:
	if rumble == null:
		return
	rumble.position = nearest_point()
	_next -= delta / maxf(Engine.time_scale, 0.01)
	if _next <= 0.0:
		_next = _rng.randf_range(15.0, 45.0)
		pass_truck()


func pass_truck() -> void:
	var st := AudioManager.stream_for(CAMION)
	if st == null:
		return
	truck.stream = st
	truck.position = nearest_point() + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-12.0, 12.0))
	truck.volume_db = _rng.randf_range(-2.0, 3.0) + AudioManager.gain_db(CAMION)
	truck.pitch_scale = _rng.randf_range(0.92, 1.06)
	truck.play()
	trucks += 1

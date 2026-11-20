class_name Bus
extends Node3D
## Bus nocturno (v0.3 P2, J #52: "que el bus se vea más claro", "sin dejar de ser tenebroso").
## LLEGADA (23:48): ya está detenido en el paradero con las puertas abiertas; las cierra y se va hacia el
## oeste. SALIDA (08:45): llega desde el este y te espera con las puertas abiertas. Ruta inventada.
## Va por el carril de la vereda (z 27) mirando a −X, con las puertas del lado del edificio (−Z).
## Faros con una SpotLight (sin sombras), ventanas encendidas con luz fluorescente enfermiza y pasajeros
## que no se mueven (uno mira hacia ti). Sin colisión: es decorado.

enum Mode { LLEGADA, SALIDA }

const STOP := Vector3(8.5, 2.1, 27.0)  # v0.3.1 Q5: la pista está a la altura de la vereda (2,1 m sobre el lobby)
const LENGTH := 11.0
const COLOR_BODY := Color(0.11, 0.14, 0.15)

var mode: int = Mode.LLEGADA
var _doors: Array[MeshInstance3D] = []
var _left: bool = false


static func make(parent: Node, p_mode: int) -> Bus:
	var b := Bus.new()
	b.name = "Bus"
	b.mode = p_mode
	parent.add_child(b)
	return b


func _ready() -> void:
	add_to_group("bus")
	_build()
	_engine()
	if mode == Mode.LLEGADA:
		position = STOP
		_set_doors(true)
		_depart_later(3.5)
	else:
		position = STOP + Vector3(55, 0, 0)
		_arrive()


func _build() -> void:
	var hl := LENGTH * 0.5
	# Carrocería: zócalo, franja de ventanas (huecos con pilares) y techo.
	Greybox.box(self, "Zocalo", Vector3(0, 0.95, 0), Vector3(LENGTH, 1.1, 2.5), COLOR_BODY, false).material_override = Greybox.material(COLOR_BODY, 0.0, 0.45, 0.4)
	Greybox.box(self, "Techo", Vector3(0, 2.95, 0), Vector3(LENGTH, 0.5, 2.5), COLOR_BODY, false).material_override = Greybox.material(COLOR_BODY, 0.0, 0.45, 0.4)
	Greybox.box(self, "Franja", Vector3(0, 1.45, 0), Vector3(LENGTH + 0.02, 0.08, 2.52), Color(0.5, 0.42, 0.2), false)
	for i in 7:
		var x := -hl + 0.9 + i * 1.6
		for side in [-1, 1]:
			Greybox.box(self, "Pilar%d_%d" % [i, side], Vector3(x, 2.1, side * 1.24), Vector3(0.18, 1.2, 0.04), COLOR_BODY, false)
	# Interior encendido (telón emisivo al centro) y pasajeros entre el telón y los vidrios.
	Greybox.box(self, "Interior", Vector3(0.5, 2.1, 0), Vector3(LENGTH - 1.6, 1.2, 0.05), Color(0.4, 0.5, 0.36), false, 0.55)
	Greybox.box(self, "Piso", Vector3(0, 1.52, 0), Vector3(LENGTH - 0.4, 0.04, 2.4), Color(0.08, 0.08, 0.08), false)
	var pasajeros := [-3.6, -1.9, -0.2, 1.6, 3.2]
	for i in pasajeros.size():
		for side in [-1, 1]:
			if (i + side) % 3 == 0:
				continue
			var px: float = pasajeros[i]
			Greybox.box(self, "Pasajero%d_%d" % [i, side], Vector3(px, 1.95, side * 0.65), Vector3(0.42, 0.62, 0.36), Color(0.03, 0.03, 0.035), false)
			var head := Greybox.box(self, "Cabeza%d_%d" % [i, side], Vector3(px, 2.42, side * 0.65), Vector3(0.2, 0.25, 0.22), Color(0.03, 0.03, 0.035), false)
			if i == 2 and side == -1:
				head.rotation_degrees.y = 80.0  # este mira hacia la vereda: hacia ti
	Greybox.light(self, Vector3(0, 2.5, 0), Color(0.65, 0.8, 0.55), 0.9, 5.5)
	# Frente (−X): parabrisas, letrero de ruta, faros; atrás: luces rojas.
	Greybox.box(self, "Parabrisas", Vector3(-hl - 0.02, 2.05, 0), Vector3(0.04, 1.2, 2.3), Color(0.25, 0.3, 0.28), false, 0.4)
	Greybox.box(self, "Letrero", Vector3(-hl - 0.04, 2.83, 0), Vector3(0.04, 0.26, 1.9), Color(0.05, 0.04, 0.02), false)
	var ruta := Greybox.label(self, "", Vector3(-hl - 0.07, 2.83, 0), 0.15, Greybox.AMBAR, -PI * 0.5)
	ruta.text = tr("BUS_ROUTE")
	var ruta_lado := Greybox.label(self, "", Vector3(1.2, 2.78, -1.27), 0.12, Greybox.AMBAR, PI)
	ruta_lado.text = tr("BUS_ROUTE")
	for z in [-0.85, 0.85]:
		Greybox.box(self, "Faro%d" % int(z * 10), Vector3(-hl - 0.03, 0.85, z), Vector3(0.05, 0.22, 0.38), Color(1.0, 0.95, 0.8), false, 4.0)
		Greybox.box(self, "Stop%d" % int(z * 10), Vector3(hl + 0.03, 0.9, z), Vector3(0.05, 0.3, 0.25), Greybox.ROJO, false, 2.5)
	var spot := SpotLight3D.new()
	spot.name = "Faros"
	spot.position = Vector3(-hl - 0.2, 1.0, 0)
	spot.rotation_degrees = Vector3(-6, 90, 0)  # mira a −X
	spot.light_color = Color(1.0, 0.92, 0.78)
	spot.light_energy = 3.0
	spot.spot_range = 22.0
	spot.spot_angle = 32.0
	spot.shadow_enabled = false
	spot.set_meta("no_mood", true)
	add_child(spot)
	var cola := Greybox.light(self, Vector3(hl + 0.4, 0.9, 0), Color(0.9, 0.1, 0.08), 0.6, 3.5)
	cola.set_meta("no_mood", true)
	# Ruedas.
	for wx in [-hl + 1.8, hl - 2.0]:
		for wz in [-1.2, 1.2]:
			var w := Greybox.cylinder(self, "Rueda", Vector3(wx, 0.5, wz), 0.5, 0.3, Color(0.03, 0.03, 0.03))
			w.rotation_degrees.x = 90.0
	# Puertas del lado del edificio (−Z): dos hojas que se abren hacia los lados.
	for k in 2:
		var d := Greybox.box(self, "Puerta%d" % k, Vector3(-hl + 1.4 + k * 0.55, 1.75, -1.26), Vector3(0.55, 1.9, 0.04), Color(0.2, 0.26, 0.26), false, 0.3)
		_doors.append(d)


## P6: motor al ralentí del bus (bucle 3D, se oye al acercarse al paradero).
func _engine() -> void:
	var st := AudioManager.stream_for("ambiente/bus_ralenti_loop", true)
	if st == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.name = "MotorAudio"
	a.stream = st
	a.bus = "Ambiente"
	a.unit_size = 5.0
	a.max_distance = 45.0
	a.volume_db = -4.0
	a.position = Vector3(LENGTH * 0.4, 0.8, 0)
	add_child(a)
	if not OS.get_cmdline_user_args().has("--escenario"):
		a.play()


func _set_doors(open: bool) -> void:
	for k in _doors.size():
		var base_x := -LENGTH * 0.5 + 1.4 + k * 0.55
		_doors[k].position.x = base_x + ((-0.5 if k == 0 else 0.5) if open else 0.0)
		_doors[k].position.z = -1.32 if open else -1.26


func _depart_later(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		return
	_set_doors(false)
	AudioManager.play_sfx("bus_puerta")
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	AudioManager.play_sfx("bus_pasa")  # P6: el bus arranca y se aleja
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:x", STOP.x - 70.0, 7.0)
	tw.tween_callback(queue_free)
	_left = true


func _arrive() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", STOP.x, 6.0)
	tw.tween_callback(func() -> void:
		_set_doors(true)
		AudioManager.play_sfx("bus_frenos_aire")  # P6: frenos de aire y puertas del bus (audio_v2)
		AudioManager.play_sfx("bus_puerta"))


## ¿Se fue el bus de llegada? (pruebas)
func has_left() -> bool:
	return _left

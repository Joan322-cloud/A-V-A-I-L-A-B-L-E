class_name DistortionController
extends Node
## Aplica las 6 distorsiones del T1 (data/distorsiones_t1.json). Regla: nunca delante de ti sin
## parpadeo: se disparan en microsueño, al volver a una zona o al girar un pasillo. Respeta única/cooldown.

var catalog: Array = []
var _seen: Dictionary = {}  # id -> true (únicas ya vistas)
var _last_real: Dictionary = {}  # id -> tiempo real del último disparo
var _had_break: bool = false
var _in_lunch_trip: bool = false
var _clock_looks: int = 0
var mirror_active: bool = false
var _cam_view: SecurityCamView = null


func _ready() -> void:
	catalog = DataLoader.list("distorsiones_t1")
	EventBus.player_exited_zone.connect(_on_zone_exited)
	EventBus.player_entered_zone.connect(_on_zone_entered)
	EventBus.microsleep.connect(_on_microsleep)
	EventBus.player_blinked.connect(_on_blink)
	EventBus.aux_changed.connect(_on_aux_changed)
	EventBus.shift_started.connect(_reset)
	EventBus.respawned.connect(_on_respawned)


func _reset() -> void:
	_seen.clear()
	_last_real.clear()
	_had_break = false
	_in_lunch_trip = false
	_clock_looks = 0
	_on_blink()


## v0.3.2-core (pasada 6 de partidas en fotos, bot torpe «lunch», T3): al reaparecer el reloj vuelve al checkpoint,
## pero «vengo de un break» y «vengo del lunch» se quedaban puestos de la línea de tiempo en la que moriste. Morías
## en el lunch, reaparecías sentado en C-14 («Reconectando»)… y en ese instante saltaba «tu sesión está en otra
## fila»: C-14 dejaba de aceptar, el primer contacto sonaba con «no estás en tu sitio» estando sentado en tu sitio y
## se perdía. Esas dos marcas se vuelven a poner solas cuando tomes el break o el lunch después de reaparecer.
## Y si la sesión ya estaba movida cuando moriste (mismo piso, no se reconstruye), vuelve a C-14 sin parpadeo.
func _on_respawned(_kind: String) -> void:
	_had_break = false
	_in_lunch_trip = false
	var floor_node := get_tree().get_first_node_in_group("floor")
	var back := floor_node.get_node_or_null("SesionVuelve") if floor_node != null else null
	if back != null and back.has_method("revert"):
		back.call("revert", true)


func _entry(id: String) -> Dictionary:
	for d in catalog:
		if str(d.get("id", "")) == id:
			return d
	return {}


func _can_fire(id: String) -> bool:
	var d := _entry(id)
	if d.is_empty():
		return false
	if GameState.turno < int(d.get("turno_minimo", 1)):
		return false
	if bool(d.get("unica", false)) and (_seen.has(id) or GameState.distortions_seen.has(id)):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _last_real.has(id) and now - float(_last_real[id]) < float(d.get("cooldown_s_real", 0.0)):
		return false
	return randf() <= float(d.get("probabilidad", 1.0))


func _fire(id: String) -> void:
	var d := _entry(id)
	_seen[id] = true
	_last_real[id] = Time.get_ticks_msec() / 1000.0
	GameState.mark_distortion(id)
	var floor_node := get_tree().get_first_node_in_group("floor") as FloorBase
	var effect: Dictionary = d.get("efecto", {})
	match str(effect.get("tipo", "")):
		"audio_parlantes":
			AudioManager.play_music(str(effect.get("archivo", "hold_kipupay_parlantes")), false)  # una pasada, no en bucle
		"reflejo_camara_seguridad", "reflejo_espejo":
			# v0.3.2: ya no es la cámara de seguridad de 20 s: en el reflejo de MirrorView (≤ 2 s) alguien queda de pie
			# detrás de ti y al darte vuelta no hay nadie. SecurityCamView queda solo para la captura «espejo_cam».
			if MirrorView.is_open():
				MirrorView.current.haunt()
		_:
			if floor_node != null:
				floor_node.apply_distortion(id, effect)
	EventBus.distortion_triggered.emit(id)


func _on_aux_changed(new_aux: int, _old: int) -> void:
	if new_aux == Metrics.Aux.BREAK:
		_had_break = true
	if new_aux == Metrics.Aux.LUNCH:
		_in_lunch_trip = true


func _on_zone_exited(zone: String) -> void:
	pass


func _on_zone_entered(zone: String) -> void:
	match zone:
		"pasillo_agua":
			# 1. Un panel más: al volver del primer Break por el pasillo (dirección a la sala).
			if _had_break and GameState.seated_at == "" and _can_fire("un_panel_mas"):
				_fire("un_panel_mas")
		"fila_c":
			# 2. La silla caliente: volver a la fila C tras cualquier AUX con Fatiga >= 40.
			if _had_break and Fatigue.value >= float(_entry("silla_caliente").get("trigger", {}).get("fatiga_min", 40)) and _can_fire("silla_caliente"):
				_fire("silla_caliente")
			# 4. Sesión en otra fila: volver del Lunch.
			if _in_lunch_trip and Metrics.aux != Metrics.Aux.LUNCH and _can_fire("sesion_otra_fila"):
				_in_lunch_trip = false
				_fire("sesion_otra_fila")
		"sala":
			if _in_lunch_trip and Metrics.aux != Metrics.Aux.LUNCH and _can_fire("sesion_otra_fila"):
				_in_lunch_trip = false
				_fire("sesion_otra_fila")
	if zone.begins_with("reloj_pared_"):
		# 3. 3:47 otra vez: mirar el reloj de pared dos veces en el Bloque 2.
		if GameState.current_block() == 2:
			_clock_looks += 1
			if _clock_looks >= 2 and _can_fire("tres_cuarenta_y_siete"):
				_fire("tres_cuarenta_y_siete")
	if zone.begins_with("espejo_"):
		# 5. El espejo: cualquier baño común con Fatiga >= 50.
		var d := _entry("el_espejo")
		if Fatigue.value >= float(d.get("trigger", {}).get("fatiga_min", 50)) and _can_fire("el_espejo"):
			_fire("el_espejo")


func _on_microsleep() -> void:
	# 6. Hold por los parlantes: microsueño en el Bloque 3.
	if GameState.current_block() == 3 and GameState.current_floor == 2 and _can_fire("hold_parlantes"):
		_fire("hold_parlantes")


func _on_blink() -> void:
	mirror_active = false
	if _cam_view != null and is_instance_valid(_cam_view):
		_cam_view.finish()
	_cam_view = null

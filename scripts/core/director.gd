class_name Director
extends Node
## Director de tensión (GDD 4.11): Presión 0-100 cada 10 s. En T1 tope de 1 evento simultáneo.
## Presión = métricas amarillas/rojas (hasta 40) + Fatiga/2 (hasta 50) + s desde el último susto (hasta 30) − calma.

var pressure: float = 0.0
var _timer: float = 0.0
var _last_scare_real: float = 0.0
var _active_events: int = 0


func _ready() -> void:
	EventBus.death_shown.connect(func(_c: String) -> void: _last_scare_real = Time.get_ticks_msec() / 1000.0)
	EventBus.distortion_triggered.connect(func(_id: String) -> void: _last_scare_real = Time.get_ticks_msec() / 1000.0)


func _process(delta: float) -> void:
	if not GameState.running:
		return
	_timer += delta
	if _timer >= float(DataLoader.bal("director/intervalo_s", 10.0)):
		_timer = 0.0
		_recompute()


func _recompute() -> void:
	var metrics := 0.0
	for m in ["available", "aht", "ww"]:
		match Metrics.color_of(m):
			"amarillo": metrics += 8.0
			"rojo": metrics += 13.3
	var fat := Fatigue.value * 0.5
	var since := Time.get_ticks_msec() / 1000.0 - _last_scare_real
	var scare := clampf(since / 10.0, 0.0, 30.0)
	var calm := 40.0 if GameState.in_calm else 0.0
	pressure = clampf(metrics + fat + scare - calm, 0.0, 100.0)


## ¿Puede dispararse otro evento activo ahora? (T1: máximo 1 a la vez)
func can_spawn_event() -> bool:
	var max_events := int(DataLoader.bal("director/max_eventos_t1", 1))
	return _active_events < max_events and not GameState.in_calm and pressure >= 30.0


func event_started() -> void:
	_active_events += 1


func event_ended() -> void:
	_active_events = maxi(_active_events - 1, 0)


## Nivel 0-3 para el ritmo de Shero/RTA.
func level() -> int:
	if pressure < 30.0:
		return 0
	if pressure < 60.0:
		return 1
	if pressure < 85.0:
		return 2
	return 3

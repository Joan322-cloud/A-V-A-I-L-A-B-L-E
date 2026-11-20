class_name Bathroom
extends Node3D
## Baño = sala segura (Shero no entra a ningún baño). Límite 90 s (60 s en los individuales del -1):
## la luz parpadea antes, luego se apaga y el RTA taguea por AUX Baño. Terminal Fonex junto a la puerta.

@export var floor_number: int = 2
@export var single: bool = false  # individual con pestillo (-1)
@export var zone_id: String = "bano_p2"

var player_inside: bool = false
var seconds_inside: float = 0.0
var light_node: OmniLight3D = null
var latched: bool = false
var _flicker_t: float = 0.0
var _cfg: Dictionary = {}


func _ready() -> void:
	add_to_group("bathrooms")
	var per: Dictionary = DataLoader.bal("bano/por_piso", {})
	_cfg = per.get(str(floor_number), {})
	EventBus.player_entered_zone.connect(_on_zone_entered)
	EventBus.player_exited_zone.connect(_on_zone_exited)


func safe_seconds() -> float:
	return float(_cfg.get("sala_segura_s", DataLoader.bal("bano/sala_segura_s", 90.0)))


func flicker_from() -> float:
	return float(_cfg.get("luz_parpadea_desde_s", 75.0))


func _on_zone_entered(id: String) -> void:
	if id != zone_id:
		return
	player_inside = true
	seconds_inside = 0.0
	if single:
		latched = true  # se cierra con pestillo por dentro
	if light_node != null:
		light_node.light_energy = 1.0


func _on_zone_exited(id: String) -> void:
	if id != zone_id:
		return
	player_inside = false
	latched = false
	if light_node != null:
		light_node.light_energy = 1.0


func _process(delta: float) -> void:
	if not player_inside or not GameState.running:
		return
	seconds_inside += delta
	# Fatiga baja -5/min hasta 90 s (GDD 4.6).
	if seconds_inside <= 90.0:
		Fatigue.add(float(DataLoader.bal("bano/fatiga_por_min", -5.0)) / 60.0 * delta)
	if light_node != null:
		if seconds_inside >= safe_seconds():
			if light_node.light_energy > 0.0:
				light_node.light_energy = 0.0
				EventBus.show_message.emit(tr("MSG_BATHROOM_LIGHT_OFF"), 3.0)
				AudioManager.play_sfx("fluorescente_parpadeo")
		elif seconds_inside >= flicker_from() and not bool(Loc.get_setting("flash_reduction", false)):
			_flicker_t += delta * 20.0
			light_node.light_energy = 0.4 + 0.6 * absf(sin(_flicker_t * 1.7) * sin(_flicker_t * 0.3))
	# Pasado el límite ya no es sala segura: el RTA cuenta el tiempo de Baño.
	if seconds_inside >= safe_seconds() and Metrics.aux == Metrics.Aux.BANO:
		pass  # PerritoRTA lee quota_left(BANO) y el tiempo en AUX; aquí no se mata directamente.


## ¿Protege al jugador ahora mismo? (dentro y dentro del límite)
func is_safe() -> bool:
	return player_inside and seconds_inside < safe_seconds()

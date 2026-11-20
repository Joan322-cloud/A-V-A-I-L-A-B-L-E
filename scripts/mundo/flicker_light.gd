class_name FlickerLight
extends Node
## Parpadeo de fluorescente (GDD 8.1): ráfagas cortas y aleatorias que bajan la luz y el panel emisivo.
## Respeta la opción de accesibilidad "flash_reduction" (parpadeo suave y lento).

## v0.3 P2: factor de ánimo del piso (FloorBase._Mood: baja con la Fatiga y el enojo de Shero).
static var mood: float = 1.0

var light: OmniLight3D = null
var panel: MeshInstance3D = null
var base_energy: float = 1.0
var rate: float = 0.08  # ráfagas por segundo (media)
var _burst_left: float = 0.0
var _t: float = 0.0
var _mat: StandardMaterial3D = null
var _rng := RandomNumberGenerator.new()
var _acc: float = 0.0


static func attach(p_panel: MeshInstance3D, p_rate: float = 0.08) -> FlickerLight:
	var f := FlickerLight.new()
	f.name = "Parpadeo"
	f.panel = p_panel
	for c in p_panel.get_children():
		if c is OmniLight3D:
			f.light = c
	f.rate = p_rate
	p_panel.add_child(f)
	return f


func _ready() -> void:
	_rng.randomize()
	if light != null:
		base_energy = light.light_energy
		light.set_meta("flicker", true)
	if panel != null and panel.material_override is StandardMaterial3D:
		_mat = (panel.material_override as StandardMaterial3D).duplicate()  # material propio para no apagar todos
		panel.material_override = _mat


func _process(delta: float) -> void:
	if light == null:
		return
	if GfxQuality.is_low():
		# Calidad Baja: el parpadeo se actualiza a 15 Hz (menos cambios de energía/material por frame).
		_acc += delta
		if _acc < 1.0 / 15.0:
			return
		delta = _acc
		_acc = 0.0
	var soft := bool(Loc.get_setting("flash_reduction", false))
	if _burst_left > 0.0:
		_burst_left -= delta
		_t += delta * (6.0 if soft else 28.0)
		var k := 0.55 + 0.45 * sin(_t) * sin(_t * 0.37) if soft else (0.15 if fmod(_t, 1.0) < 0.5 else 1.0)
		_apply(k)
		if _burst_left <= 0.0:
			_apply(1.0)
	elif _rng.randf() < rate * delta * (1.0 + 3.0 * Dread.level()):
		_burst_left = _rng.randf_range(0.15, 0.6)
		_t = 0.0
	elif absf(light.light_energy - base_energy * mood) > 0.01:
		_apply(1.0)


func _apply(k: float) -> void:
	light.light_energy = base_energy * k * mood
	if _mat != null:
		_mat.emission_energy_multiplier = 2.0 * k

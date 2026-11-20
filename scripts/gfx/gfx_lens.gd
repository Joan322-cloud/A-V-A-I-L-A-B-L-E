class_name GfxLens
extends CanvasLayer
## v0.3.2 gfx · Lente y película en Media/Alta.
##
## Dos pases a pantalla completa:
##   1. Lente (esta capa, layer 0, DEBAJO de la interfaz): aberración cromática leve, etalonaje del piso (el mismo
##      tinte/saturación/contraste de FloorBase.grading() + viraje de sombras y luces de data/gfx_looks.json) y el
##      brillo de pantalla como gamma. Solo toca la imagen 3D: el HUD y la PC quedan nítidos y sin teñir.
##   2. Película (el rectángulo de siempre de fx/overlays.gd, ENCIMA del HUD y la PC): se le cambia el material por
##      gfx_pelicula.gdshader, con los mismos uniformes (overlays.gd lo sigue alimentando) pero grano fino de textura
##      y sin etalonaje (ya lo hizo el lente).
## En Baja y Modo liviano esta capa está oculta y overlays.gd usa su material de siempre: nada cambia.
##
## Ganchos para sustos (los puede llamar cualquier paquete; no hacen nada en Baja/liviano):
##   GfxLens.kick(fuerza 0..1, segundos)  → empuja aberración, grano y viñeta y los suelta solos.

const LENS_SHADER := "res://assets/shaders/gfx_lente.gdshader"
const FILM_SHADER := "res://assets/shaders/gfx_pelicula.gdshader"

static var inst: GfxLens = null
## ¿El pase de lente está activo? (Lo consulta quien quiera saber si el etalonaje va por aquí.)
static var active: bool = false

var _rect: ColorRect = null
var _lens: ShaderMaterial = null
var _film: ShaderMaterial = null
var _overlays: Node = null
var _tint: Color = Color(1, 1, 1)
var _scare: float = 0.0
var _scare_target: float = 0.0
var _scare_left: float = 0.0
var _look: Dictionary = {}


func _init() -> void:
	name = "GfxLente"
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	inst = self
	_rect = ColorRect.new()
	_rect.name = "Lente"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1, 1, 1, 1)
	add_child(_rect)
	visible = false


func _exit_tree() -> void:
	if inst == self:
		inst = null
		active = false


static func _material(path: String) -> ShaderMaterial:
	if not ResourceLoader.exists(path):
		return null
	var sh := load(path) as Shader
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Empuje de susto: sube a `strength` de golpe y vuelve a 0 en `seconds`. Con «Reducir parpadeos», a un tercio.
static func kick(strength: float, seconds: float = 1.0) -> void:
	if inst == null or not active:
		return
	var s := clampf(strength, 0.0, 1.0)
	if bool(Loc.get_setting("flash_reduction", false)):
		s *= 0.33
	inst._scare_target = maxf(inst._scare_target, s)
	inst._scare_left = maxf(inst._scare_left, seconds)


static func scare_level() -> float:
	return inst._scare if inst != null else 0.0


func apply(look: Dictionary) -> void:
	_look = look
	var want := GfxSettings.enhanced() and GfxSettings.on("lente") and not GfxSettings.headless()
	if want and _lens == null:
		_lens = _material(LENS_SHADER)
		_film = _material(FILM_SHADER)
		if _film != null:
			_film.set_shader_parameter("grain_tex", GfxMaterials.tex("grano"))
	if _lens == null or _film == null or GfxMaterials.tex("grano") == null:
		want = false  # sin los shaders o sin la textura de grano (el HTML no la lleva): queda la película de siempre
	active = want
	visible = want
	_rect.material = _lens if want else null
	_bind_overlays(want)
	if want:
		_film.set_shader_parameter("grain_k", GfxSettings.amount("grano") * float(look.get("grain", 1.0)))
		_film.set_shader_parameter("vignette_k", GfxSettings.amount("vineta") * float(look.get("vignette", 1.0)))
		_lens.set_shader_parameter("lift", _vec(look.get("lift"), Vector3.ONE))
		_lens.set_shader_parameter("gain", _vec(look.get("gain"), Vector3.ONE))
		_lens.set_shader_parameter("gamma", GfxSettings.brillo())


static func _vec(v: Variant, def: Vector3) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return def


## Cambia (o devuelve) el material del pase de película de fx/overlays.gd.
func _bind_overlays(on: bool) -> void:
	if not is_instance_valid(_overlays):
		_overlays = null
		for n in get_tree().root.find_children("Overlays", "Control", true, false):
			if n.has_method("set_film_material"):
				_overlays = n
				break
	if _overlays != null:
		_overlays.call("set_film_material", _film if on else null)


func _process(delta: float) -> void:
	if not active:
		return
	if not visible:
		visible = true  # la pausa oculta las capas ajenas; el lente va debajo de la interfaz y se queda
	if _scare_left > 0.0:
		_scare_left -= delta
		if _scare_left <= 0.0:
			_scare_target = 0.0
	_scare = lerpf(_scare, _scare_target, clampf(delta * (10.0 if _scare_target > _scare else 2.2), 0.0, 1.0))
	# Etalonaje del piso: los mismos números que usa el pase de película de Baja (overlays.gd), con la presión.
	var g: Dictionary = {}
	if FloorBase.active != null and is_instance_valid(FloorBase.active):
		g = FloorBase.active.grading()
	var d := Dread.level()
	var recuerdo := Flashback.active
	var target: Color = Color(1, 1, 1) if recuerdo else g.get("tint", Color(1, 1, 1))
	_tint = _tint.lerp(target, minf(delta * 2.0, 1.0))
	_lens.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))
	_lens.set_shader_parameter("sat", 1.0 if recuerdo else float(g.get("sat", 0.85)) * (1.0 - 0.3 * d))
	_lens.set_shader_parameter("contrast", 1.0 if recuerdo else float(g.get("contrast", 1.0)) + 0.08 * d)
	_lens.set_shader_parameter("ca", GfxSettings.amount("aberracion") * float(_look.get("aberration", 1.0)))
	_lens.set_shader_parameter("scare", _scare)
	_lens.set_shader_parameter("gamma", GfxSettings.brillo())
	_film.set_shader_parameter("scare", _scare)

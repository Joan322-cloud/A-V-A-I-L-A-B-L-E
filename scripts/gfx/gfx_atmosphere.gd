class_name GfxAtmosphere
extends RefCounted
## v0.3.2 gfx · El aire del piso en Media/Alta: mapeo de tonos, exposición (con adaptación), ambiente bajo, niebla
## (por profundidad siempre; volumétrica en Forward+), oclusión ambiental, luz indirecta y reflejos en pantalla
## (Forward+), resplandor contenido. Lee data/gfx_looks.json (aspecto por piso) y GfxSettings (opciones).
##
## No crea nodos: solo escribe propiedades del Environment que main.gd ya creó. Guarda el valor que tenía cada una
## (el «base» del piso, tal como lo dejó main.gd) y lo devuelve al salir de Media/Alta, al cambiar de piso (antes de que
## main.gd escriba el ambiente del piso nuevo) y al volver al menú. En Baja y Modo liviano no toca nada, salvo la
## exposición si el jugador movió «Brillo» (con brillo 1,0 no cambia ni un valor).

## Propiedades del Environment que este módulo puede tocar (todas se guardan y se devuelven).
const PROPS: Array[String] = [
	"tonemap_mode", "tonemap_exposure", "tonemap_white", "tonemap_agx_white", "tonemap_agx_contrast",
	"ambient_light_color", "ambient_light_energy", "reflected_light_source",
	"fog_enabled", "fog_light_color", "fog_light_energy", "fog_density", "fog_sky_affect",
	"volumetric_fog_enabled", "volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_emission",
	"volumetric_fog_emission_energy", "volumetric_fog_gi_inject", "volumetric_fog_anisotropy", "volumetric_fog_length",
	"volumetric_fog_detail_spread", "volumetric_fog_ambient_inject", "volumetric_fog_sky_affect",
	"volumetric_fog_temporal_reprojection_enabled", "volumetric_fog_temporal_reprojection_amount",
	"ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_power", "ssao_detail", "ssao_horizon", "ssao_sharpness",
	"ssao_light_affect", "ssao_ao_channel_affect",
	"ssil_enabled", "ssil_radius", "ssil_intensity", "ssil_sharpness", "ssil_normal_rejection",
	"ssr_enabled", "ssr_max_steps", "ssr_fade_in", "ssr_fade_out", "ssr_depth_tolerance",
	"sdfgi_enabled",
	"glow_enabled", "glow_levels/1", "glow_levels/2", "glow_levels/3", "glow_levels/4", "glow_levels/5",
	"glow_levels/6", "glow_levels/7", "glow_normalized", "glow_intensity", "glow_strength", "glow_mix", "glow_bloom",
	"glow_blend_mode", "glow_hdr_threshold", "glow_hdr_scale", "glow_hdr_luminance_cap",
	"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
]

var env: Environment = null
var look: Dictionary = {}
var look_id: String = ""
var active: bool = false
var _base: Dictionary = {}
var _exposure: float = 1.0      # exposición del aspecto (sin adaptación ni brillo)
var _adapt: float = 1.0         # adaptación actual (suavizada)
var _adapt_target: float = 1.0
var _scare: float = 0.0
var _low_base: float = -1.0     # exposición base guardada cuando solo se aplica el brillo (Baja / liviano)
var _low_env: Environment = null


# --- aspecto por piso -------------------------------------------------------------------------------------------

## Aspecto del piso: base + piso + (recuerdo). `floor_node` puede ser null (menú): base.
static func look_for(floor_node: Node) -> Dictionary:
	var cfg: Dictionary = DataLoader.dict("gfx_looks")
	var out: Dictionary = (cfg.get("base", {}) as Dictionary).duplicate(true)
	var id := floor_key(floor_node)
	if id != "":
		_merge(out, (cfg.get("pisos", {}) as Dictionary).get(id, {}))
	if Flashback.active:
		_merge(out, cfg.get("recuerdo", {}))
	return out


## Clave del piso en gfx_looks.json: "2", "-1", "1", "9" o "escalera".
static func floor_key(floor_node: Node) -> String:
	if floor_node == null or not is_instance_valid(floor_node):
		return ""
	if floor_node is Stairwell:
		return "escalera"
	if floor_node is FloorBase:
		return str((floor_node as FloorBase).floor_number)
	return ""


static func _merge(into: Dictionary, over: Variant) -> void:
	if not (over is Dictionary):
		return
	for k in (over as Dictionary).keys():
		var v: Variant = (over as Dictionary)[k]
		if v is Dictionary and into.get(k) is Dictionary:
			_merge(into[k], v)
		else:
			into[k] = v


static func _col(v: Variant, def: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return def


func f(key: String, def: float) -> float:
	return float(look.get(key, def))


# --- aplicar / devolver ------------------------------------------------------------------------------------------

## Devuelve el Environment a como lo dejó main.gd (si se había tocado). Seguro de llamar siempre.
func restore() -> void:
	if env != null and not _base.is_empty():
		for k in _base.keys():
			env.set(k, _base[k])
		if Flashback.active:
			Flashback.brighten_env(env)  # el base puede ser de antes del recuerdo: su ambiente de día se repone
	_base.clear()
	active = false
	_adapt = 1.0
	_adapt_target = 1.0


## Solo brillo (Baja / liviano): multiplica la exposición base; con brillo 1,0 devuelve el valor original.
func apply_brightness_only(e: Environment) -> void:
	if e == null:
		return
	if _low_env != e:
		_low_env = e
		_low_base = -1.0
	var b := GfxSettings.brillo()
	if absf(b - 1.0) < 0.005:
		if _low_base >= 0.0:
			e.tonemap_exposure = _low_base
			_low_base = -1.0
		return
	if _low_base < 0.0:
		_low_base = e.tonemap_exposure
	e.tonemap_exposure = _low_base * brightness_to_exposure(b)


## Brillo (gamma 0,6..1,6) → factor de exposición equivalente para las calidades sin pase de lente.
static func brightness_to_exposure(b: float) -> float:
	return pow(clampf(b, GfxSettings.BRILLO_MIN, GfxSettings.BRILLO_MAX), 1.7)


func apply(e: Environment, floor_node: Node) -> void:
	if e != env:
		_base.clear()  # otro Environment (mundo nuevo): el base viejo ya no vale
		env = e
		active = false
	if env == null:
		return
	if not GfxSettings.enhanced():
		restore()
		apply_brightness_only(env)
		return
	if _low_base >= 0.0 and _low_env == env:  # venía de Baja con brillo aplicado: se deshace antes de guardar el base
		env.tonemap_exposure = _low_base
		_low_base = -1.0
	if _base.is_empty():
		for k in PROPS:
			_base[k] = env.get(k)
	else:
		# Mismo piso, cambió una opción: se parte otra vez del base (una opción apagada vuelve a su valor).
		for k in _base.keys():
			env.set(k, _base[k])
	look = look_for(floor_node)
	var recuerdo := Flashback.active
	look_id = floor_key(floor_node) + ("+recuerdo" if recuerdo else "")
	active = true
	if recuerdo:
		# El recuerdo (Training) lo define Flashback: de día, cálido y limpio. Se parte de SUS valores de ambiente,
		# niebla y fondo (los escribe él al cargar el piso; aquí se reponen porque arriba se volvió al base) y este
		# módulo solo agrega lo de Media/Alta: mapeo de tonos, exposición, oclusión y resplandor suaves.
		Flashback.brighten_env(env)
	var fwd := GfxSettings.forward()
	var dark := GfxSettings.on("luz_terror") and bool((look.get("lights", {}) as Dictionary).get("enabled", true))
	# Mapeo de tonos y exposición.
	match str(look.get("tonemap", "agx")):
		"aces":
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_white = f("agx_white", 6.0)
		"filmic":
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_white = f("agx_white", 6.0)
		_:
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
			env.tonemap_agx_white = f("agx_white", 7.0)
			env.tonemap_agx_contrast = f("agx_contrast", 1.2)
	# La exposición de Media/Alta sale entera del aspecto: no hereda la del entorno base (que va con el mapeo Filmic
	# de Baja y su punto blanco; aquí el mapeo es otro).
	_exposure = f("exposure", 1.0)
	# Ambiente: con la luz de terror baja a una fracción (con un piso mínimo: nada queda negro puro).
	var amb := env.ambient_light_energy if recuerdo else float(_base.get("ambient_light_energy", 0.3))
	if recuerdo:
		env.ambient_light_energy = maxf(amb * f("ambient_k", 0.7), f("ambient_min", 0.2))
	elif dark:
		# Sin luz indirecta ni niebla volumétrica (Compatibilidad) nada rebota: el ambiente sube un poco para compensar.
		var ck := 1.0 if fwd else f("compat_ambient", 1.5)
		env.ambient_light_energy = maxf(amb * f("ambient_k", 0.34), f("ambient_min", 0.045)) * ck
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.sdfgi_enabled = false
	# Niebla por profundidad (la de siempre, algo más densa para que el fondo se pierda).
	var niebla := GfxSettings.level("niebla")
	var fog_d: float = env.fog_density if recuerdo else float(_base.get("fog_density", 0.012))
	if niebla >= 1 and not recuerdo:
		env.fog_enabled = true
		env.fog_density = fog_d * f("fog_density_k", 1.2) * (1.0 if (niebla >= 2 and fwd) else f("compat_fog_density", 1.9))
		var fc: Color = _base.get("fog_light_color", Color(0.015, 0.025, 0.027))
		# Sin niebla volumétrica el aire no devuelve luz: la de profundidad se aclara para que el fondo no sea un negro
		# plano y lo cercano se recorte contra él.
		var k := f("fog_color_k", 1.0) * (1.0 if (niebla >= 2 and fwd) else f("compat_fog_color", 1.8))
		env.fog_light_color = Color(fc.r * k, fc.g * k, fc.b * k)
	# Niebla volumétrica (solo Forward+): los tubos dibujan su haz en el aire.
	env.volumetric_fog_enabled = niebla >= 2 and fwd
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = f("vol_density", 0.016)
		env.volumetric_fog_albedo = _col(look.get("vol_albedo"), Color(0.82, 0.88, 0.92))
		env.volumetric_fog_emission = Color(0, 0, 0)
		env.volumetric_fog_emission_energy = 0.0
		env.volumetric_fog_gi_inject = 0.0
		env.volumetric_fog_anisotropy = f("vol_anisotropy", 0.45)
		env.volumetric_fog_length = f("vol_length", 46.0)
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_ambient_inject = f("vol_ambient", 0.06)
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.volumetric_fog_temporal_reprojection_amount = 0.9
		# Con volumétrica, la de profundidad solo oscurece el fondo (no suma dos veces).
		env.fog_density = fog_d * minf(f("fog_density_k", 1.2), 1.0)
	# Oclusión ambiental.
	var ao := GfxSettings.level("ssao")
	env.ssao_enabled = ao >= 1
	if env.ssao_enabled:
		env.ssao_radius = f("ssao_radius", 1.1)
		env.ssao_intensity = f("ssao_intensity", 2.4) * (1.0 if ao >= 2 else 0.7)
		env.ssao_power = 1.5
		env.ssao_detail = 0.5
		env.ssao_horizon = 0.06
		env.ssao_sharpness = 0.98
		env.ssao_light_affect = 0.22  # también bajo luz directa (esquinas, bajo los escritorios)
		env.ssao_ao_channel_affect = 0.0
	# Luz indirecta en pantalla (Forward+).
	env.ssil_enabled = GfxSettings.on("ssil") and fwd
	if env.ssil_enabled:
		env.ssil_radius = 4.0
		env.ssil_intensity = f("ssil_intensity", 0.9)
		env.ssil_sharpness = 0.98
		env.ssil_normal_rejection = 1.0
	# Reflejos en pantalla (Forward+; en Compatibilidad los dan las sondas de reflexión de GfxLights).
	env.ssr_enabled = GfxSettings.level("reflejos") >= 2 and fwd
	if env.ssr_enabled:
		env.ssr_max_steps = 56
		env.ssr_fade_in = 0.12
		env.ssr_fade_out = 2.0
		env.ssr_depth_tolerance = 0.25
	# Resplandor contenido: solo lo que emite de verdad (tubos, pantallas, carteles de salida).
	var gl := GfxSettings.level("glow")
	env.glow_enabled = gl >= 1
	if env.glow_enabled:
		for i in range(1, 8):
			env.set("glow_levels/%d" % i, 1.0 if (i >= 2 and i <= (5 if gl >= 2 else 4)) else 0.0)
		env.glow_normalized = true
		env.glow_intensity = f("glow_intensity", 0.5) * (1.0 if gl >= 2 else 0.75)
		env.glow_strength = 1.0
		env.glow_bloom = f("glow_bloom", 0.03)
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		env.glow_hdr_threshold = f("glow_threshold", 1.0)
		env.glow_hdr_scale = 2.0
		env.glow_hdr_luminance_cap = 12.0
	# El etalonaje del piso lo hace el pase de lente (GfxLens); el ajuste del Environment queda neutro si el lente está.
	if GfxSettings.on("lente"):
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = 1.0
		env.adjustment_saturation = f("saturation", 0.92)
	_apply_quality_levels(ao, fwd)
	_write_exposure()


## Calidad de los efectos de pantalla (ajustes globales del servidor de render; baratos de cambiar).
func _apply_quality_levels(ao: int, fwd: bool) -> void:
	if GfxSettings.headless():
		return
	var hi := GfxQuality.level() == "alta"
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if ao >= 2 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM if ao == 1 and hi else RenderingServer.ENV_SSAO_QUALITY_LOW,
		true, 0.5, 2, 50.0, 300.0)
	if fwd:
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM if hi else RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50.0, 300.0)
		RenderingServer.environment_set_ssr_half_size(true)
		RenderingServer.environment_set_ssr_roughness_quality(RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW)
		RenderingServer.environment_set_volumetric_fog_volume_size(64 if hi else 48, 64 if hi else 48)
		RenderingServer.environment_set_volumetric_fog_filter_active(true)
		RenderingServer.environment_glow_set_use_bicubic_upscale(hi)


# --- por cuadro ---------------------------------------------------------------------------------------------------

## `local_light` = estimación barata de cuánta luz hay donde está el jugador (0 = negro, 1 = bajo un tubo), que da
## GfxLights; con la adaptación activa la exposición sube en lo oscuro y baja bajo la luz (despacio, sin bombeo).
func tick(delta: float, local_light: float, scare: float) -> void:
	if env == null or not active:
		return
	_scare = scare
	if GfxSettings.on("adaptacion") and not Flashback.active:
		# 0 → ×1,45 · 0,5 → ×1,0 · 1 → ×0,82 · 1,6 (varios tubos encima, sala blanca) → ×0,66
		if local_light < 0.5:
			_adapt_target = lerpf(1.45, 1.0, clampf(local_light / 0.5, 0.0, 1.0))
		elif local_light < 1.0:
			_adapt_target = lerpf(1.0, 0.82, clampf((local_light - 0.5) / 0.5, 0.0, 1.0))
		else:
			_adapt_target = lerpf(0.82, 0.66, clampf((local_light - 1.0) / 0.6, 0.0, 1.0))
	else:
		_adapt_target = 1.0
	# El ojo se acostumbra más rápido a la luz que a la oscuridad.
	var speed := 1.6 if _adapt_target < _adapt else 0.55
	_adapt = lerpf(_adapt, _adapt_target, clampf(delta * speed, 0.0, 1.0))
	_write_exposure()


func _write_exposure() -> void:
	if env == null or not active:
		return
	var e := _exposure * _adapt
	if not GfxSettings.on("lente"):
		e *= brightness_to_exposure(GfxSettings.brillo())  # sin pase de lente el brillo va por exposición
	env.tonemap_exposure = e


## Para pruebas y para el contador de depuración.
func exposure_now() -> float:
	return env.tonemap_exposure if env != null else 1.0

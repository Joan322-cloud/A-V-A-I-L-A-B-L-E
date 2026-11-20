class_name GfxSettings
extends RefCounted
## v0.3.2 gfx · Catálogo de las opciones gráficas avanzadas (Opciones → «Gráficos avanzados…»).
##
## La calidad de siempre (GfxQuality: Modo liviano / Baja / Media / Alta, settings.json «quality») sigue mandando.
## Baja y el Modo liviano NO cambian: para ellos toda opción de este catálogo vale su valor «apagado» (OFF) y nada
## de scripts/gfx/ crea nodos, carga texturas ni toca luces. Media y Alta traen un valor por opción (PRESETS) que el
## jugador puede cambiar una por una; lo que cambia queda en settings.json «gfx» = {clave: valor} y se borra al
## elegir otra calidad (vuelve a mandar el preset).
##
## Opciones globales (valen en cualquier calidad, no las pisa el preset): brillo, contador de FPS, V-Sync,
## renderizador. Viven en settings.json con el prefijo «gfx_».

## Apagado: lo que vale cada opción en Baja y en Modo liviano.
const OFF: Dictionary = {
	"luz_terror": false,   # iluminación nocturna rehecha: casi todo a oscuras, pozas de luz, tubos con sombra
	"sombras": 0,          # 0 sin · 1 pocas · 2 media · 3 alta (cantidad de luces con sombra y nitidez)
	"niebla": 0,           # 0 la de siempre · 1 por profundidad + haces falsos · 2 volumétrica (Forward+)
	"ssao": 0,             # oclusión ambiental: 0 sin · 1 baja · 2 alta
	"ssil": false,         # luz indirecta en pantalla (solo Forward+)
	"reflejos": 0,         # 0 sin · 1 sondas de reflexión · 2 sondas + reflejos en pantalla (SSR, solo Forward+)
	"glow": 0,             # resplandor: 0 sin · 1 contenido · 2 completo
	"materiales": false,   # mapas de relieve y rugosidad de las superficies
	"detalle": 0,          # geometría de detalle: 0 sin · 1 esencial · 2 completa
	"personajes": false,   # sombreado de piel, ojos y tela
	"lente": false,        # pase de lente propio (etalonaje por piso, viñeta, grano fino, aberración)
	"aberracion": 0.0,     # aberración cromática 0..1
	"grano": 1.0,          # intensidad del grano 0..1 (la casilla «Grano de película» sigue siendo el interruptor)
	"vineta": 1.0,         # viñeta 0..1
	"adaptacion": false,   # adaptación de la exposición al pasar de zonas claras a oscuras
	"parpadeo": 1.0,       # intensidad de los parpadeos de luz 0..1 («Reducir parpadeos» la deja en lo mínimo)
	"escala_3d": 1.0,      # escala de resolución del 3D (0,5..1): Baja y liviano usan la suya de siempre
}

const PRESETS: Dictionary = {
	"media": {
		"luz_terror": true, "sombras": 2, "niebla": 1, "ssao": 1, "ssil": false, "reflejos": 1, "glow": 1,
		"materiales": true, "detalle": 1, "personajes": false, "lente": true, "aberracion": 0.5, "grano": 1.0,
		"vineta": 1.0, "adaptacion": true, "parpadeo": 1.0, "escala_3d": 1.0,
	},
	"alta": {
		"luz_terror": true, "sombras": 3, "niebla": 2, "ssao": 2, "ssil": true, "reflejos": 2, "glow": 2,
		"materiales": true, "detalle": 2, "personajes": true, "lente": true, "aberracion": 1.0, "grano": 1.0,
		"vineta": 1.0, "adaptacion": true, "parpadeo": 1.0, "escala_3d": 1.0,
	},
}

## Opciones con lista de valores (el panel las muestra como botón que rota): clave → [[valor, clave de texto], …].
const CHOICES: Dictionary = {
	"sombras": [[0, "GFX_V_OFF"], [1, "GFX_V_LOW"], [2, "GFX_V_MED"], [3, "GFX_V_HIGH"]],
	"niebla": [[0, "GFX_V_FOG_BASIC"], [1, "GFX_V_FOG_DEPTH"], [2, "GFX_V_FOG_VOL"]],
	"ssao": [[0, "GFX_V_OFF"], [1, "GFX_V_LOW"], [2, "GFX_V_HIGH"]],
	"reflejos": [[0, "GFX_V_OFF"], [1, "GFX_V_REFL_PROBES"], [2, "GFX_V_REFL_SSR"]],
	"glow": [[0, "GFX_V_OFF"], [1, "GFX_V_GLOW_SOFT"], [2, "GFX_V_GLOW_FULL"]],
	"detalle": [[0, "GFX_V_OFF"], [1, "GFX_V_DETAIL_BASIC"], [2, "GFX_V_DETAIL_FULL"]],
}
## Casillas.
const TOGGLES: Array[String] = ["luz_terror", "ssil", "materiales", "personajes", "lente", "adaptacion"]
## Deslizadores: clave → [mínimo, máximo, paso].
const SLIDERS: Dictionary = {
	"aberracion": [0.0, 1.0, 0.05], "grano": [0.0, 1.5, 0.05], "vineta": [0.0, 1.5, 0.05],
	"parpadeo": [0.0, 1.0, 0.05], "escala_3d": [0.5, 1.0, 0.05],
}
## Lo que solo existe en Forward+ (en Compatibilidad se salta limpio y el panel lo dice).
const FORWARD_ONLY: Dictionary = {"ssil": true}
## Valor de la opción a partir del cual hace falta Forward+ (por debajo hay sustituto en Compatibilidad).
const FORWARD_FROM: Dictionary = {"niebla": 2, "reflejos": 2}

## Globales: clave de settings.json → valor por defecto.
const GLOBALS: Dictionary = {
	"gfx_brillo": 1.0,          # gamma de pantalla 0,6..1,6 (pantalla «Brillo»)
	"gfx_calibrado": false,     # ya pasó por la pantalla de brillo del primer arranque
	"gfx_fps": false,           # contador de FPS visible
	"gfx_max_fps": 60,         # tope de FPS (60 recomendado para evitar sobrecalentamiento; 0 = sin límite)
	"gfx_vsync": true,
	"gfx_renderer": "auto",     # auto · forward_plus · gl_compatibility (vale al reiniciar)
	"gfx_bench_hecho": false,   # ya corrió la detección automática del primer arranque
	"gfx_sub_fondo": false,     # fondo oscuro tras los subtítulos y avisos del HUD
}
const BRILLO_MIN := 0.6
const BRILLO_MAX := 1.6

static var _forward_cache: int = -1
## Brillo que se está probando en la pantalla «Brillo» (−1 = ninguno: vale el guardado).
static var brillo_preview: float = -1.0


## El HTML no lleva el paquete (ni sus texturas: los presets Web las excluyen): en web Media y Alta siguen siendo
## las de la beta y el menú no muestra «Gráficos avanzados…». `web_forzado` solo lo usan las pruebas.
static var web_forzado: bool = false


static func web() -> bool:
	return web_forzado or OS.has_feature("web")


## ¿Las mejoras de Media/Alta están activas? (No en Baja ni en Modo liviano, ni en el HTML.)
static func enhanced() -> bool:
	return not GfxQuality.is_low() and not web()


## Valor efectivo de una opción del catálogo con la calidad actual.
static func value(key: String) -> Variant:
	if not enhanced():
		return OFF.get(key)
	var ov: Variant = Loc.get_setting("gfx", {})
	if ov is Dictionary and (ov as Dictionary).has(key):
		return _coerce(key, (ov as Dictionary)[key])
	return (PRESETS.get(GfxQuality.level(), PRESETS["media"]) as Dictionary).get(key, OFF.get(key))


static func on(key: String) -> bool:
	return bool(value(key))


static func level(key: String) -> int:
	return int(value(key))


static func amount(key: String) -> float:
	return float(value(key))


## settings.json guarda números como float: cada opción vuelve con el tipo de su valor «apagado».
static func _coerce(key: String, v: Variant) -> Variant:
	var ref: Variant = OFF.get(key)
	if ref is bool:
		return bool(v)
	if ref is int:
		return int(v)
	if ref is float:
		return float(v)
	return v


## ¿El jugador cambió esta opción respecto del preset?
static func overridden(key: String) -> bool:
	var ov: Variant = Loc.get_setting("gfx", {})
	return ov is Dictionary and (ov as Dictionary).has(key)


static func any_override() -> bool:
	var ov: Variant = Loc.get_setting("gfx", {})
	return ov is Dictionary and not (ov as Dictionary).is_empty()


## Cambia una opción (solo tiene efecto en Media/Alta). Si queda igual al preset, se quita de los cambios.
static func set_value(key: String, v: Variant) -> void:
	if not OFF.has(key):
		return
	var ov: Dictionary = {}
	var cur: Variant = Loc.get_setting("gfx", {})
	if cur is Dictionary:
		ov = (cur as Dictionary).duplicate()
	var preset: Variant = (PRESETS.get(GfxQuality.level(), PRESETS["media"]) as Dictionary).get(key)
	v = _coerce(key, v)
	if v == preset or (v is float and preset is float and is_equal_approx(float(v), float(preset))):
		ov.erase(key)
	else:
		ov[key] = v
	Loc.set_setting("gfx", ov)


## Vuelve al preset de la calidad actual (borra los cambios uno por uno).
static func reset_overrides() -> void:
	Loc.set_setting("gfx", {})


static func global(key: String) -> Variant:
	return Loc.get_setting(key, GLOBALS.get(key))


static func set_global(key: String, v: Variant) -> void:
	Loc.set_setting(key, v)


static func brillo() -> float:
	if brillo_preview > 0.0:
		return clampf(brillo_preview, BRILLO_MIN, BRILLO_MAX)
	return clampf(float(global("gfx_brillo")), BRILLO_MIN, BRILLO_MAX)


## ¿El renderizador en uso es Forward+ (o Mobile)? Con Compatibilidad (OpenGL) o sin pantalla (headless), false.
static func forward() -> bool:
	if _forward_cache < 0:
		var m := RenderingServer.get_current_rendering_method()
		_forward_cache = 1 if (m == "forward_plus" or m == "mobile") else 0
	return _forward_cache == 1


## ¿Hay pantalla de verdad? (Las pruebas headless corren la lógica igual, pero sin nada que dependa de la GPU.)
static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## ¿La opción se puede usar con el renderizador actual tal como está puesta?
static func available(key: String) -> bool:
	if forward():
		return true
	if FORWARD_ONLY.has(key):
		return false
	return true


## «Reducir parpadeos» (la casilla de siempre, settings «flash_reduction») manda sobre la intensidad.
static func flicker() -> float:
	if bool(Loc.get_setting("flash_reduction", false)):
		return 0.0
	return clampf(amount("parpadeo"), 0.0, 1.0)


## Tope de FPS elegido por el jugador (60 por defecto en escritorio para mantener baja temperatura).
static func max_fps() -> int:
	return int(global("gfx_max_fps"))

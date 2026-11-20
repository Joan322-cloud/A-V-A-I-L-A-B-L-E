class_name VitzoGlitch
extends RefCounted
## Pantalla-cara de Vitzo que se deforma y glitchea (PLAN §2 #85c): reemplaza el material emisivo del GLB v2
## (vitzo_brillo: pantalla + antena) por un shader que toma la MISMA textura del atlas y la rompe con el tiempo:
## franjas que se desplazan, separación RGB, la cara que "se derrite" hacia abajo a ráfagas, líneas de barrido,
## ruido y parpadeos. `intensity` (0..1) sube durante el screamer (Screamers la anima); en reposo queda en 0,25
## para que nunca sea una textura fija. Sin destellos blancos (respeta "reducir destellos": `soft`).

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.25;
uniform float soft = 0.0;
uniform float energy = 1.6;
uniform vec4 tint : source_color = vec4(1.0);
float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float k = clamp(intensity, 0.0, 1.0);
	float t = TIME;
	float tick = floor(t * 18.0);
	vec2 uv = UV;
	// bandas horizontales que saltan (en el espacio del atlas: desplazamientos chicos para no salir de la isla)
	float band = floor(uv.y * 90.0);
	float jump = step(1.0 - 0.55 * k, h2(vec2(band, tick)));
	uv.x += (h2(vec2(band * 1.7, tick)) - 0.5) * 0.018 * k * jump;
	// derretido: a ráfagas la imagen se estira hacia abajo
	float burst = step(0.72 - 0.4 * k, h1(floor(t * 4.0)));
	uv.y += sin(uv.x * 260.0 + t * 9.0) * 0.004 * k * burst;
	// separación RGB
	float sh = 0.004 * k * (0.4 + 0.6 * h1(tick + 3.0));
	vec3 c;
	c.r = texture(tex, uv + vec2(sh, 0.0)).r;
	c.g = texture(tex, uv).g;
	c.b = texture(tex, uv - vec2(sh, 0.0)).b;
	// líneas de barrido y ruido
	float scan = 0.82 + 0.18 * sin((UV.y * 900.0 + t * 60.0));
	float noise = h2(UV * 400.0 + tick) * 0.35 * k;
	c = c * scan + vec3(noise * 0.4, noise, noise * 0.5);
	// parpadeo: cae la energía unos fotogramas (sin blanco)
	float drop = mix(1.0, 0.25 + 0.75 * step(0.18 * k, h1(tick * 0.37)), k);
	c *= drop;
	// bloques corruptos verdes (pantalla del bot)
	float blk = step(1.0 - 0.12 * k, h2(floor(UV * vec2(24.0, 60.0)) + tick));
	c = mix(c, vec3(0.1, 1.0, 0.45) * (0.5 + 0.5 * h1(tick)), blk * (1.0 - soft * 0.7));
	ALBEDO = c * tint.rgb;
	EMISSION = c * tint.rgb * energy;
}
"""

static var _shader: Shader = null


## Aplica el shader a las superficies emisivas de Vitzo (material importado con emisión, o *_brillo).
## Devuelve los ShaderMaterial creados (para animar `intensity`).
static func apply(scene: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var soft := 1.0 if bool(Loc.get_setting("flash_reduction", false)) else 0.0
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			if not (src.resource_name.ends_with("_brillo") or (src.emission_enabled and src.albedo_texture != null)):
				continue
			var sm := ShaderMaterial.new()
			sm.shader = _shader
			sm.set_shader_parameter("tex", src.albedo_texture)
			sm.set_shader_parameter("soft", soft)
			sm.set_shader_parameter("intensity", 0.25)
			mi.set_surface_override_material(i, sm)
			out.append(sm)
	scene.set_meta("vitzo_glitch", out)
	return out


## Sube/baja el glitch de una escena ya preparada con apply() (0..1).
static func set_intensity(scene: Node, v: float) -> void:
	if scene == null or not scene.has_meta("vitzo_glitch"):
		return
	for sm in scene.get_meta("vitzo_glitch"):
		(sm as ShaderMaterial).set_shader_parameter("intensity", clampf(v, 0.0, 1.0))


## Busca en el árbol (bajo `root`) las escenas de Vitzo con glitch y las anima de `from` a `to` en `t` s.
static func ramp(root: Node, from: float, to: float, t: float) -> void:
	if root == null or not root.is_inside_tree():
		return
	var targets: Array[Node] = []
	if root.has_meta("vitzo_glitch"):
		targets.append(root)
	for n in root.find_children("*", "Node3D", true, false):
		if n.has_meta("vitzo_glitch"):
			targets.append(n)
	for n in targets:
		var tw := root.create_tween()
		tw.tween_method(func(v: float) -> void: VitzoGlitch.set_intensity(n, v), from, to, maxf(t, 0.01))

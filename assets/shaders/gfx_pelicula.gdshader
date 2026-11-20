// v0.3.2 gfx · Pase de película de Media/Alta: reemplaza al de Baja (fx/overlays.gd) con los MISMOS uniformes, así
// overlays.gd lo alimenta igual. Diferencias: el etalonaje del piso (tint/sat/contrast) NO se aplica aquí (en
// Media/Alta lo hace gfx_lente.gdshader sobre el 3D, bajo la interfaz) y el grano es fino, de textura, con más
// peso en las sombras que en las luces. Desenfoque por Fatiga, viñeta que se cierra con la presión, latido,
// oscurecimiento y párpados: idénticos.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D grain_tex : filter_linear, repeat_enable;
uniform float blur = 0.0;
uniform float grain = 0.04;
uniform float darken = 0.0;
uniform float t = 0.0;
uniform vec3 tint = vec3(1.0);      // sin uso aquí (lo aplica el pase de lente)
uniform float sat = 1.0;            // ídem
uniform float contrast = 1.0;       // ídem
uniform float dread = 0.0;
uniform float beat = 0.0;
uniform float eyes = 0.0;
uniform float grain_k = 1.0;        // intensidad elegida por el jugador (0..1,5)
uniform float vignette_k = 1.0;     // ídem
uniform float scare = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	if (blur > 0.001) {
		float r = blur * 0.0045;
		vec3 acc = col * 0.2;
		acc += texture(screen_tex, uv + vec2(r, 0.0)).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, 0.0)).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(0.0, r)).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(0.0, r)).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(r, r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(r, -r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, -r) * 0.7).rgb * 0.1;
		col = acc;
	}
	float lum = clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	// Grano: la textura (128 px, ruido fino) salta a 24 pasos por segundo; con «sin parpadeos» t no avanza y queda fijo.
	float tick = floor(t * 24.0);
	vec2 jump = vec2(fract(tick * 0.3183), fract(tick * 0.7071));
	vec3 g = texture(grain_tex, FRAGCOORD.xy / 128.0 * 0.75 + jump).rgb - 0.5;
	float gmono = dot(g, vec3(0.333));
	vec3 gn = mix(vec3(gmono), g, 0.35);  // casi monocromo, con un resto de color
	float weight = mix(1.25, 0.4, smoothstep(0.05, 0.75, lum));
	vec3 n = gn * (grain * grain_k * 3.2 + scare * 0.10) * weight;
	float r = length(uv - 0.5) * 1.35;
	float vig = 1.0 - (0.22 * vignette_k + 0.38 * dread) * pow(r, 2.0 - 0.6 * dread) - beat * 0.35 * r - scare * 0.22 * r;
	float lid = smoothstep(0.0, 1.0, eyes);
	col = (col + n) * clamp(vig, 0.0, 1.0) * (1.0 - darken) * (1.0 - 0.82 * lid);
	COLOR = vec4(col, 1.0);
}

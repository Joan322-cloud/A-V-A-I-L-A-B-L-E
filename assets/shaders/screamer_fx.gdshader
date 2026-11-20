// Post-proceso del screamer (v0.3.1 Q2): la imagen se rompe mientras te agarra y grita.
// k (0..1): aberración cromática radial, ojo de pez que late, desgarro de líneas, desaturación y contraste, grano.
// red (0..1): viñeta rojo-sangre que se cierra. soft = "reducir destellos" (todo al 30-40 %, sin parpadeos).
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float k : hint_range(0.0, 1.0) = 0.0;
uniform float red : hint_range(0.0, 1.0) = 0.0;
uniform float soft = 0.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float s = 1.0 - 0.65 * soft;
	float kk = k * s;
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	float tick = floor(TIME * 24.0);
	// ojo de pez que late
	uv = 0.5 + c * (1.0 - kk * 0.22 * r2 * (1.0 + 0.6 * sin(TIME * 17.0)));
	// desgarro: bandas que saltan de lado
	float band = floor(uv.y * 36.0);
	float tear = step(1.0 - 0.3 * kk, h2(vec2(band, tick)));
	uv.x += (h2(vec2(band * 1.3, tick)) - 0.5) * 0.07 * kk * tear;
	// aberración cromática radial
	float ca = 0.018 * kk;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca).b;
	// enfermo: desaturado, contrastado
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(1.05, 0.88, 0.82), 0.55 * kk);
	col = (col - 0.45) * (1.0 + 0.7 * kk) + 0.45;
	// viñeta roja que se cierra
	float v = smoothstep(0.12, 0.72, sqrt(r2) * 1.35);
	col = mix(col, vec3(0.22, 0.0, 0.0), v * red * s);
	col *= 1.0 - v * 0.55 * kk;
	// grano
	col += (h2(SCREEN_UV * vec2(1280.0, 720.0) + vec2(tick)) - 0.5) * 0.14 * kk;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

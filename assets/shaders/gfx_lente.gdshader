// v0.3.2 gfx · Pase de lente de Media/Alta (scripts/gfx/gfx_lens.gd). Va en una capa propia DEBAJO de la interfaz:
// solo procesa la imagen 3D (el HUD y la PC no llevan aberración ni etalonaje).
//   · aberración cromática radial muy leve (crece hacia las esquinas; `scare` la empuja en los sustos);
//   · etalonaje del piso: saturación, contraste y tinte (los mismos que usa el pase de película de Baja) más un
//     viraje partido: `lift` tiñe las sombras y `gain` las luces;
//   · brillo de pantalla como gamma (pantalla «Brillo»): aclara las sombras sin quemar las luces.
// El grano, la viñeta, el desenfoque por Fatiga y los párpados siguen en el pase de película (gfx_pelicula.gdshader),
// que va encima de la interfaz como siempre.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float sat = 1.0;
uniform float contrast = 1.0;
uniform vec3 lift = vec3(1.0);
uniform vec3 gain = vec3(1.0);
uniform float gamma = 1.0;
uniform float ca = 0.0;      // 0..1 (1 ≈ 1,4 px a 1080p en la esquina)
uniform float scare = 0.0;   // 0..1

const float PIVOT = 0.4;
// Hombro: por encima de KNEE las luces se comprimen en vez de recortarse (un piso claro bajo un tubo conserva sus
// juntas y su textura; nada del 3D llega al blanco puro).
const float KNEE = 0.7;
const float ROLL = 1.9;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	float k = ca * 0.0026 + scare * 0.012;
	vec3 col;
	if (k > 0.00002) {
		vec2 off = c * r2 * 2.0 * k;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, sat);
	// Contraste como curva de potencia alrededor de un gris medio: oscurece las sombras y aclara las luces SIN
	// recortar a negro lo que queda por debajo (con la fórmula lineal de siempre, todo lo que estaba bajo un 6 % de
	// la pantalla se iba a negro puro: en una oficina a oscuras eso es casi toda la imagen).
	col = max(col, vec3(0.0));
	col = PIVOT * pow(col / PIVOT, vec3(contrast));
	vec3 over = max(col - KNEE, vec3(0.0));
	col = min(col, vec3(KNEE)) + over / (1.0 + over * ROLL);
	col *= tint;
	float l2 = clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	col *= mix(lift, gain, smoothstep(0.02, 0.62, l2));
	if (abs(gamma - 1.0) > 0.004) {
		col = pow(col, vec3(1.0 / gamma));
	}
	COLOR = vec4(col, 1.0);
}

// v0.3.2 gfx · Reflejo falso en los vidrios (Media/Alta): lo que el vidrio devuelve de la sala que tienes detrás.
// No hay reflexión de verdad (ni sondas por vidrio ni SSR en Compatibilidad): el rayo reflejado se lleva hasta un
// techo virtual con su retícula de tubos —la mayoría apagados, es de noche— y lo que encuentra se suma sobre el
// vidrio. Como sale del rayo de la cámara, el reflejo se desliza al caminar igual que uno de verdad.
//   INSTANCE_CUSTOM.x = esmerilado (0 vidrio limpio … 1 muy difuso)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float energy = 0.2;
uniform float ceiling_y = 2.9;                 // altura (mundo) del techo virtual
uniform vec3 tube_color : source_color = vec3(0.75, 0.9, 0.92);

varying float v_frost;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	v_frost = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(v, wn);
	float lum = 0.0;
	if (r.y > 0.03) {
		float t = (ceiling_y - wpos.y) / r.y;
		vec2 c = wpos.xz + r.xz * t;
		vec2 cell = vec2(3.6, 2.4);
		vec2 id = floor(c / cell);
		vec2 f = (fract(c / cell) - 0.5) * cell;
		float on = step(0.66, h2(id));
		vec2 d = abs(f) - vec2(0.6, 0.15);
		float soft = 0.05 + 0.5 * v_frost;
		lum = (1.0 - smoothstep(0.0, soft, max(d.x, d.y))) * on / (1.0 + 0.012 * t * t);
	}
	float fres = pow(clamp(1.0 - abs(dot(v, wn)), 0.0, 1.0), 2.0);  // base acotada: pow() de un negativo no está definido
	ALBEDO = tube_color * energy * (lum * (0.3 + 0.7 * fres) * (1.0 - 0.45 * v_frost) + 0.05 * fres);
}

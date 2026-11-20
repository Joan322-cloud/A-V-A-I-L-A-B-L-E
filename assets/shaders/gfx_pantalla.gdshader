// v0.3.2 gfx · Pantalla de un monitor de relleno (capa de detalle de Media/Alta). Sin texturas: una interfaz de
// trabajo genérica dibujada con rectángulos (barra superior, columna de la cola, filas de «texto», un panel con
// casillas), distinta en cada monitor según INSTANCE_CUSTOM. No copia ninguna aplicación real ni lleva logos.
//   INSTANCE_CUSTOM.x = semilla (0..1) · .y = fase · .z = encendida (1) / bloqueada (0,5) / apagada (0)
// Sin sombreado: la pantalla emite su propio color (el resplandor lo toma si pasa del umbral).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float brightness = 1.0;
uniform float flicker_amount = 1.0;

varying flat vec4 v_data;

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void vertex() {
	v_data = INSTANCE_CUSTOM;
}

float box(vec2 uv, vec2 a, vec2 b) {
	vec2 s = step(a, uv) * step(uv, b);
	return s.x * s.y;
}

void fragment() {
	vec2 uv = UV;
	float seed = v_data.x * 61.0 + 3.0;
	float on = v_data.z;
	// Dos temas: oscuro (la mayoría) y de fondo claro (planillas, correo): estos son los que más alumbran.
	float light = step(0.5, v_data.a);
	vec3 accent = mix(vec3(0.10, 0.52, 0.55), vec3(0.20, 0.36, 0.70), step(0.5, h1(seed)));
	vec3 bg = mix(vec3(0.020, 0.028, 0.044), vec3(0.66, 0.71, 0.76), light);
	vec3 side = mix(vec3(0.040, 0.055, 0.080), vec3(0.50, 0.56, 0.63), light);
	vec3 card = mix(vec3(0.050, 0.068, 0.095), vec3(0.74, 0.78, 0.82), light);
	vec3 field_bg = mix(vec3(0.095, 0.12, 0.16), vec3(0.86, 0.89, 0.92), light);
	vec3 text = mix(vec3(0.56, 0.64, 0.70), vec3(0.13, 0.16, 0.21), light);
	vec3 text_hi = mix(vec3(0.86, 0.92, 0.95), vec3(0.04, 0.06, 0.10), light);
	vec3 text_lo = mix(vec3(0.42, 0.48, 0.53), vec3(0.28, 0.33, 0.39), light);
	vec3 col = bg;
	if (on > 0.75) {
		// barra superior con la pastilla de estado
		col = mix(col, accent * mix(0.48, 0.9, light), box(uv, vec2(0.0, 0.0), vec2(1.0, 0.075)));
		float st = h1(seed + 4.0);
		vec3 pill = st < 0.62 ? vec3(0.16, 0.74, 0.34) : (st < 0.86 ? vec3(0.86, 0.66, 0.12) : vec3(0.80, 0.16, 0.13));
		col = mix(col, pill, box(uv, vec2(0.80, 0.018), vec2(0.975, 0.058)));
		col = mix(col, vec3(0.80, 0.86, 0.90), box(uv, vec2(0.02, 0.026), vec2(0.02 + 0.10 + 0.16 * h1(seed + 5.0), 0.050)));
		// columna izquierda: la cola
		col = mix(col, side, box(uv, vec2(0.0, 0.075), vec2(0.215, 1.0)));
		float ry = (uv.y - 0.10) / 0.083;
		float ri = floor(ry);
		float rf = fract(ry);
		if (uv.x > 0.015 && uv.x < 0.20 && ri >= 0.0 && ri < 10.0) {
			float w = 0.06 + 0.11 * h1(seed + ri * 3.1);
			float line = step(0.28, rf) * step(rf, 0.62) * step(uv.x, 0.03 + w);
			float sel = step(abs(ri - floor(h1(seed + 9.0) * 6.0)), 0.5);
			col = mix(col, accent * mix(0.36, 1.1, light), sel * step(0.08, rf) * step(rf, 0.92));
			col = mix(col, text, line * 0.9);
		}
		// zona central: el caso, con filas de texto de largo distinto y una que se va escribiendo
		float cy = (uv.y - 0.105) / 0.058;
		float ci = floor(cy);
		float cf = fract(cy);
		if (uv.x > 0.24 && uv.x < 0.70 && ci >= 0.0 && ci < 14.0) {
			float w2 = 0.10 + 0.34 * h1(seed * 1.7 + ci * 5.3);
			float typing = floor(mod(TIME * 0.35 + v_data.y * 14.0, 14.0));
			if (abs(ci - typing) < 0.5) {
				w2 *= fract(TIME * 0.35 + v_data.y * 14.0);
			}
			float gap = step(0.5, h1(seed + ci * 0.77));  // líneas en blanco entre párrafos
			float line2 = step(0.30, cf) * step(cf, 0.66) * step(uv.x, 0.245 + w2) * (1.0 - 0.9 * gap * step(ci, 12.0) * step(h1(seed + ci), 0.25));
			float head = step(ci, 0.5);
			col = mix(col, mix(text, text_hi, head), line2 * 0.92);
		}
		// panel derecho: ficha con casillas y un botón
		col = mix(col, card, box(uv, vec2(0.725, 0.105), vec2(0.985, 0.965)));
		float py = (uv.y - 0.14) / 0.10;
		float pi = floor(py);
		float pf = fract(py);
		if (uv.x > 0.745 && uv.x < 0.965 && pi >= 0.0 && pi < 7.0) {
			float lbl = step(0.12, pf) * step(pf, 0.30) * step(uv.x, 0.745 + 0.07 + 0.08 * h1(seed + pi * 2.3));
			float field = step(0.42, pf) * step(pf, 0.84);
			col = mix(col, text_lo, lbl * 0.9);
			col = mix(col, field_bg, field);
			col = mix(col, text, field * step(0.55, pf) * step(pf, 0.70) * step(uv.x, 0.76 + 0.14 * h1(seed + pi * 7.9)) * step(0.755, uv.x));
		}
		col = mix(col, accent * 1.1, box(uv, vec2(0.80, 0.885), vec2(0.965, 0.945)));
	} else if (on > 0.25) {
		// bloqueada: reloj y candado en el centro, casi a oscuras
		col = vec3(0.012, 0.018, 0.03) + accent * 0.05;
		col = mix(col, vec3(0.55, 0.62, 0.67), box(uv, vec2(0.40, 0.40), vec2(0.60, 0.47)));
		col = mix(col, vec3(0.28, 0.33, 0.37), box(uv, vec2(0.44, 0.52), vec2(0.56, 0.545)));
	} else {
		col = vec3(0.006, 0.007, 0.010);
	}
	// trama de píxeles muy leve y respiración de la retroiluminación
	float px = 0.94 + 0.06 * step(0.5, fract(uv.y * 150.0));
	float breathe = 1.0 - 0.035 * flicker_amount * (0.5 + 0.5 * sin(TIME * (7.0 + 5.0 * v_data.y) + v_data.y * 40.0));
	ALBEDO = col * px * breathe * brightness;
}

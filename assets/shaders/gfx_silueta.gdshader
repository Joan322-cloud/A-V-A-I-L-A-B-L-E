// v0.3.2 gfx · Silueta sentada de relleno (capa de detalle de Media/Alta), en un solo dibujo para todas.
// El color de cada pieza viene en el vértice; la ropa (UV.x = 1) toma el color de la copia (INSTANCE_CUSTOM.rgb).
// INSTANCE_CUSTOM.a = cuánta luz le da su monitor (0 apagado … 1 pantalla clara): la cara, el pecho y las manos
// reciben esa luz fría SIN poner una luz de verdad por puesto (se calcula por vértice y se suma como emisión).
shader_type spatial;
render_mode cull_back;

uniform vec3 screen_color : source_color = vec3(0.56, 0.72, 1.0);
uniform float screen_energy = 1.0;
uniform float flicker_amount = 1.0;
// Rebote de su propia pantalla en todo el cuerpo (sube en Compatibilidad, donde no hay luz indirecta).
uniform float bounce = 0.35;
// Dónde está la pantalla en el marco de la silueta (delante y algo arriba del pecho).
uniform vec3 screen_pos = vec3(0.0, 0.12, -0.8);

varying vec3 v_base;
varying float v_glow;
varying float v_lit;

void vertex() {
	vec3 c = mix(COLOR.rgb, INSTANCE_CUSTOM.rgb, UV.x);
	v_base = pow(max(c, vec3(0.0)), vec3(2.2));
	vec3 l = screen_pos - VERTEX;
	float d = length(l);
	float ndl = max(dot(NORMAL, l / d), 0.0);
	float breathe = 1.0 - 0.05 * flicker_amount * (0.5 + 0.5 * sin(TIME * (7.0 + 5.0 * INSTANCE_CUSTOM.r) + INSTANCE_CUSTOM.g * 40.0));
	v_glow = ndl / (0.35 + 2.2 * d * d) * INSTANCE_CUSTOM.a * breathe;
	v_lit = INSTANCE_CUSTOM.a * breathe;
}

void fragment() {
	ALBEDO = v_base;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	// Además de la luz directa de la pantalla: un rebote muy tenue en todo el cuerpo y un filo en los bordes, para
	// que de espaldas no sea un recorte negro sino alguien sentado frente a una pantalla encendida.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = screen_color * screen_energy * (v_base * (v_glow + bounce * v_lit) + vec3(0.05) * rim * v_lit);
}

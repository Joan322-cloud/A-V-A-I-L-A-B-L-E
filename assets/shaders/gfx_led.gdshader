// v0.3.2 gfx · LED testigo que parpadea solo (detectores de humo, luminarias de emergencia en reposo): un destello
// corto cada pocos segundos, con fase propia por copia (INSTANCE_CUSTOM.x). `flicker_amount` 0 = fijo y tenue
// («Reducir parpadeos»). `boost` lo sube en el modo de emergencia.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 led_color : source_color = vec3(0.9, 0.06, 0.04);
uniform float period = 4.6;
uniform float flicker_amount = 1.0;
uniform float boost = 0.0;

varying flat float v_phase;

void vertex() {
	v_phase = INSTANCE_CUSTOM.x;
}

void fragment() {
	float t = fract(TIME / period + v_phase);
	float flash = smoothstep(0.0, 0.004, t) * (1.0 - smoothstep(0.018, 0.03, t));
	float e = mix(0.35, 0.10 + 5.0 * flash, flicker_amount) + boost * 3.0;
	ALBEDO = led_color * e;
}

// v0.3.2 gfx · Mancha de luz falsa (capa de detalle de Media/Alta): la luz que deja un monitor encendido sobre su
// escritorio, sumada con mezcla aditiva sobre lo que haya debajo. No es una luz: no cuesta sombras ni entra en el
// cupo de luces por objeto, así que puede haber una por pantalla en toda la sala.
//   INSTANCE_CUSTOM.x = semilla (la misma de la pantalla: decide si es de fondo claro) · .y = fase · .z = encendida
// UV: (0,5; 0,22) es el pie del monitor; la mancha cae hacia el borde del tablero.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.50, 0.68, 1.0);
uniform float energy = 0.9;
uniform float flicker_amount = 1.0;

varying flat vec4 v_data;

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void vertex() {
	v_data = INSTANCE_CUSTOM;
}

void fragment() {
	float seed = v_data.x * 61.0 + 3.0;
	float light = step(0.5, v_data.a);
	vec2 p = (UV - vec2(0.5, 0.22)) * vec2(2.0, 1.45);
	float f = clamp(1.0 - length(p), 0.0, 1.0);
	f = f * f * (3.0 - 2.0 * f);
	// borde del cuadro: que no se note el rectángulo
	vec2 e = smoothstep(vec2(0.0), vec2(0.08), UV) * smoothstep(vec2(0.0), vec2(0.08), 1.0 - UV);
	float on = step(0.75, v_data.z);
	float breathe = 1.0 - 0.05 * flicker_amount * (0.5 + 0.5 * sin(TIME * (7.0 + 5.0 * v_data.y) + v_data.y * 40.0));
	ALBEDO = mix(tint, vec3(0.80, 0.88, 1.0), light * 0.6) * (energy * mix(0.5, 1.0, light) * f * e.x * e.y * on * breathe);
}

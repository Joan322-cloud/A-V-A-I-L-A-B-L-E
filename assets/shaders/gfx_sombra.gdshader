// v0.3.2 gfx · Sombra de contacto falsa (Media/Alta): una mancha oscura y suave en el suelo bajo las sillas y bajo
// los personajes. No es una sombra de verdad: no cuesta pases de sombra, no entra en el cupo de luces y se ve igual
// en Forward+ y en Compatibilidad. Asienta en el suelo lo que si no parece pegado encima.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float alpha = 0.5;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float f = clamp(1.0 - dot(p, p), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = f * f * alpha;
}

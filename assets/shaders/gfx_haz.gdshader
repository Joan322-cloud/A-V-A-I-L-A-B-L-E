// v0.3.2 gfx · Haz de luz falso bajo una luminaria encendida (Media/Alta cuando NO hay niebla volumétrica: en
// Compatibilidad siempre, y en Forward+ con la niebla en «Por profundidad»). Un tronco de pirámide que cuelga del
// tubo, sumado con mezcla aditiva: más denso arriba, se pierde hacia el suelo, y sus caras se desvanecen cuando
// se ven de canto o de muy cerca (al pasar por dentro no se nota ninguna pared).
//   INSTANCE_CUSTOM.r = cuánto alumbra el tubo ahora (0..1: sigue al parpadeo, al apagón y a la emergencia)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.80, 0.92, 0.95);
uniform float energy = 0.075;

varying flat float v_k;

void vertex() {
	v_k = INSTANCE_CUSTOM.r;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float side = smoothstep(0.05, 0.75, facing);
	// La base va acotada: en el borde inferior del haz UV.y pasa de 1 por un pelo y pow() de un negativo no está
	// definido (en Forward+ daba píxeles negros con un halo de resplandor alrededor).
	float fall = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.6);
	float near = smoothstep(0.5, 2.6, length(VERTEX));
	float far = 1.0 - smoothstep(22.0, 34.0, length(VERTEX));
	ALBEDO = tint * (energy * v_k * side * fall * near * far);
}

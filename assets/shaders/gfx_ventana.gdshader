// v0.3.2 gfx · Luz de la calle que entra por una ventana con persiana y cae en el suelo (Media/Alta, de noche):
// una mancha fría con la sombra de los parantes y las tiras de la persiana, sumada sobre el piso. No es una luz.
// UV.y = 0 al pie de la ventana, 1 hacia dentro del ambiente.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D mask : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.50, 0.62, 0.86);
uniform float energy = 0.16;
uniform float slats = 13.0;

void fragment() {
	float m = texture(mask, UV).r;
	float s = 0.45 + 0.55 * smoothstep(0.25, 0.45, abs(fract(UV.y * slats) - 0.5) * 2.0);
	ALBEDO = tint * (energy * m * s);
}

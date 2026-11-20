// Cara deforme (v0.3.1 Q2, F8): reemplaza el material de los modelos v2 (misma textura del atlas) y deforma la
// cabeza en tiempo real según `deform` (0..1, lo anima cada fila de screamer) y `severity` (0..1, Haime en el
// feedback). Los GLB no tienen blend shapes y Shero no tiene vértices en el hueso "jaw": todo se hace aquí, en el
// espacio de REPOSO de la malla (rest_from_pose lleva el vértice ya skinneado al reposo de la cabeza, ahí se
// deforma con los puntos de la cara medidos en ese espacio, y pose_from_rest lo devuelve).
//   · la boca se rasga: lo que está bajo la línea de la boca cae (mandíbula imposible) y las comisuras se abren;
//     los triángulos que cruzan la línea se estiran y se pintan como la cavidad (negro-rojo con dientes);
//   · el cráneo se estira hacia arriba y se angosta;
//   · los ojos se hinchan y se vuelven cuencas negras con una pupila roja que brilla;
//   · la carne tiembla (ruido cuantizado, sin destellos);
//   · la piel se pone gris-enferma y las cuencas se oscurecen (también con `severity`).
// v0.3.2 (kills, Joan: «mucho más grotescas»): mandíbula más desencajada (jaw_mult) y ojos más saltones (eye_bulge);
// con `gore` (0..1; 0 con «Contenido gráfico: Reducido»): sangre que chorrea de la boca, la nariz y los ojos,
// moretones morados, piel rasgada (grietas rojas en mejillas y frente), salpicaduras y ojos inyectados en sangre
// (esclerótica con venas en vez de la cuenca negra). gore_detail = 0 (Modo liviano/Baja): solo los chorros y las
// manchas, sin el ruido de las grietas.
// Uniformes de la cara en unidades de la malla (hh = alto de la cabeza, del mentón a la coronilla).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scream_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_scream_tex = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_v = 0.8;
uniform float metallic_v = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool face_surface = true;   // cuerpo/cara: boca y ojos; pelo: solo el estiramiento y el temblor

uniform float deform : hint_range(0.0, 1.0) = 0.0;
uniform float severity : hint_range(0.0, 1.0) = 0.0;
uniform float tremor = 1.0;
uniform float soft = 0.0;          // "reducir destellos": menos temblor y brillo
uniform mat4 rest_from_pose = mat4(1.0);
uniform mat4 pose_from_rest = mat4(1.0);

uniform vec3 eye_l = vec3(0.03, 1.64, 0.13);
uniform vec3 eye_r = vec3(-0.03, 1.64, 0.13);
uniform float eye_rad = 0.02;
uniform vec3 mouth = vec3(0.0, 1.59, 0.15);
uniform float mouth_hw = 0.03;
uniform float chin_y = 1.55;
uniform float top_y = 1.78;
uniform float face_z = 0.12;       // los vértices con z (reposo) mayor son la cara
uniform float fwd_sign = 1.0;      // +1: la cara mira a +z en el reposo
uniform float jaw_drop = 0.55;     // caída de la mandíbula en múltiplos de hh
uniform float skull_stretch = 0.32;
uniform ivec4 head_binds = ivec4(-1);
uniform float gore : hint_range(0.0, 1.0) = 0.0;
uniform float gore_detail = 1.0;
uniform float jaw_mult = 1.35;     // v0.3.2: mandíbula desencajada
uniform float eye_bulge = 1.7;
uniform int face_style = 0; // 1=shero 2=rasec 3=haime 4=trainer 5=fermin 6=grasa 7=perrito 8=vitzo     // v0.3.2: ojos saltones  // índices del skin de head/jaw/eye_l/eye_r: la máscara de la cabeza sale de los pesos

varying vec3 v_rest;
varying float v_open;
varying float v_wx;
varying float v_head;

float h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float h11(float x) { return fract(sin(x * 91.17) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
// Chorreones verticales (en el reposo de la cabeza) que bajan desde y0 en una franja de ancho w alrededor de x0.
float streaks(vec3 p, float x0, float w, float y0, float len, float col_w) {
	float dx = p.x - x0;
	float col = floor(dx / col_w);
	float l = len * (0.35 + 0.65 * h11(col + 7.0));
	float inx = step(abs(dx), w) * step(0.35, fract(dx / col_w)) * step(fract(dx / col_w), 0.85);
	float iny = step(p.y, y0) * step(y0 - l, p.y);
	return inx * iny;
}

void vertex() {
	vec3 p = (rest_from_pose * vec4(VERTEX, 1.0)).xyz;
	v_rest = p;
	float hh = max(top_y - chin_y, 0.01);
	float k = clamp(deform, 0.0, 1.0);
	float sev = clamp(severity, 0.0, 1.0);
	// Máscara de cabeza: del cuello (bajo el mentón) a la coronilla, sin tocar el torso.
	float wh = 0.0;
	for (int j = 0; j < 4; j++) {
		int bi = int(BONE_INDICES[j]);
		if (bi == head_binds.x || bi == head_binds.y || bi == head_binds.z || bi == head_binds.w) {
			wh += BONE_WEIGHTS[j];
		}
	}
	float head = smoothstep(0.2, 0.8, wh) * smoothstep(chin_y - 0.3 * hh, chin_y - 0.1 * hh, p.y);
	v_head = head;
	float front = smoothstep(face_z - 0.35 * hh, face_z + 0.05 * hh, p.z * fwd_sign);
	vec3 d = vec3(0.0);
	// 1) Mandíbula imposible: lo que está bajo la línea de la boca cae (el cuello se estira con él).
	float m_hw = (face_style == 3) ? mouth_hw * 0.58 : ((face_style == 2) ? mouth_hw * 1.45 : mouth_hw);
	float below = 1.0 - smoothstep(mouth.y - 0.012 * hh, mouth.y + 0.004 * hh, p.y);
	float wx = 1.0 - smoothstep(m_hw * 1.1, m_hw * 2.6 + 0.25 * hh, abs(p.x - mouth.x));
	float jaw = below * head * mix(0.55, 1.0, front) * wx;
	float style_drop = (face_style == 3) ? 1.32 : ((face_style == 4) ? 1.25 : ((face_style == 5) ? 0.85 : ((face_style == 6) ? 1.38 : 1.0)));
	float drop = k * k * jaw_drop * jaw_mult * style_drop * hh * (0.7 + 0.3 * sin(TIME * 23.0) * tremor);
	d.y -= drop * jaw;
	d.z += drop * jaw * ((face_style == 3) ? 0.14 : 0.25) * fwd_sign;
	if (face_style == 4) { d.x += drop * jaw * 0.22; }
	else if (face_style == 5) { d.y -= k * 0.06 * hh * head * smoothstep(chin_y, top_y, p.y) * step(0.0, p.x); }
	else if (face_style == 6) {
		// GRASA: mandibula partida y desencajada en espasmos + mejillas hinchadas saliendo de la capucha
		d.x += sin(TIME * 31.0 + p.y * 18.0) * k * 0.032 * hh * jaw;
		float bloat = smoothstep(chin_y, top_y, p.y) * head * (1.0 - front * 0.35);
		d.x += sign(p.x - mouth.x) * k * 0.075 * hh * bloat;
		d.z += k * 0.045 * hh * bloat * fwd_sign;
	}
	v_open = face_surface ? below : 0.0;
	v_wx = wx * head * mix(0.4, 1.0, front);
	float lip = exp(-pow((p.y - mouth.y) / (0.06 * hh), 2.0)) * front * head;
	float lip_dir = (face_style == 3) ? -0.28 : ((face_style == 2) ? 0.68 : 0.35);
	d.x += sign(p.x - mouth.x) * k * lip_dir * m_hw * lip;
	if (face_style == 2) { d.y += k * 0.18 * hh * lip * smoothstep(m_hw * 0.4, m_hw * 1.8, abs(p.x - mouth.x)); }
	float above = smoothstep(mouth.y, top_y, p.y) * head;
	float st_k = (face_style == 3) ? 0.15 : ((face_style == 1) ? 1.25 : 1.0);
	d.y += k * skull_stretch * st_k * (p.y - mouth.y) * above;
	d.x += k * ((face_style == 1) ? 0.14 : -0.18) * (p.x - mouth.x) * above;
	// 3) Ojos que se hinchan (y se hunden un poco con la severidad).
	float de_l = distance(p, eye_l);
	float de_r = distance(p, eye_r);
	float el = 1.0 - smoothstep(eye_rad * 0.9, eye_rad * 2.2, de_l);
	float er = 1.0 - smoothstep(eye_rad * 0.9, eye_rad * 2.2, de_r);
	d += normalize(p - eye_l + vec3(0.0001)) * el * eye_rad * (0.9 * eye_bulge * k - 0.25 * sev);
	d += normalize(p - eye_r + vec3(0.0001)) * er * eye_rad * (0.9 * eye_bulge * k - 0.25 * sev);
	// Cejas que bajan con la severidad (más serio).
	float brow = exp(-pow((p.y - (eye_l.y + 1.6 * eye_rad)) / (0.9 * eye_rad), 2.0)) * front * head;
	d.y -= sev * 0.5 * eye_rad * brow;
	// 4) La carne tiembla (cuantizado a 24 Hz, sin destellos).
	float tick = floor(TIME * 24.0);
	float n = h31(floor(p * 60.0) + vec3(tick)) - 0.5;
	d += NORMAL * n * k * 0.03 * hh * head * tremor * (1.0 - 0.7 * soft);
	VERTEX = (pose_from_rest * vec4(p + d, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float k = clamp(deform, 0.0, 1.0);
	float sev = clamp(severity, 0.0, 1.0);
	if (has_scream_tex && face_surface) {
		c = mix(c, texture(scream_tex, UV).rgb, smoothstep(0.25, 0.6, k));
	}
	vec3 e = emission_color.rgb * emission_energy;
	float rough = roughness_v;
	if (face_surface) {
		float hh = max(top_y - chin_y, 0.01);
		// Piel gris-enferma con venas oscuras.
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		vec3 sick = vec3(l) * vec3(0.78, 0.84, 0.74);
		float m = v_head * (0.6 * k + 0.25 * sev);
		c = mix(c, sick, m);
		// Cuencas: negras (k) / sombreadas (severidad), con la pupila roja que brilla.
		float de = min(distance(v_rest, eye_l), distance(v_rest, eye_r));
		float sock = 1.0 - smoothstep(eye_rad * 0.7, eye_rad * 1.7, de);
		c *= 1.0 - sock * clamp(1.15 * k + 0.45 * sev, 0.0, 0.97);
		float pupil = 1.0 - smoothstep(eye_rad * 0.12, eye_rad * 0.34, de);
		vec3 eye_glow = (face_style == 6) ? vec3(1.0, 0.02, 0.0) * 5.2 : vec3(1.0, 0.06, 0.03) * 3.2;
		e += eye_glow * pupil * (k + 0.3 * sev) * (1.0 - 0.5 * soft);
		// Cavidad de la boca: los triángulos estirados (v_open entre 0 y 1) son la garganta; cerca de los bordes,
		// dientes sucios.
		float cav = smoothstep(0.03, 0.12, v_open) * (1.0 - smoothstep(0.88, 0.97, v_open)) * smoothstep(0.15, 0.45, v_wx) * smoothstep(0.02, 0.12, k);
		float edge = 1.0 - smoothstep(0.0, 0.22, min(v_open, 1.0 - v_open));
		float gaps = step(0.45, fract(v_rest.x / max(mouth_hw * 0.22, 0.001)));
		float center = 1.0 - abs(v_open - 0.5) * 2.0;
		vec3 throat = mix(vec3(0.16, 0.0, 0.01), vec3(0.0), smoothstep(0.3, 0.8, center));
		vec3 tooth = vec3(0.74, 0.68, 0.52) * (0.75 + 0.25 * gaps);
		c = mix(c, throat, cav);
		c = mix(c, tooth, cav * edge * gaps);
		rough = mix(rough, 0.25, cav);
		float g = clamp(gore, 0.0, 1.0) * v_head * (1.0 - cav);
		if (g > 0.001) {
			vec3 blood = vec3(0.3, 0.0, 0.012);
			// Moretones morados alrededor de los ojos y en una mejilla.
			float bru = (1.0 - smoothstep(eye_rad * 1.2, eye_rad * 3.2, de)) * 0.7;
			bru += (1.0 - smoothstep(0.0, 0.09 * hh, distance(v_rest.xy, vec2(eye_l.x + 0.4 * hh, mouth.y + 0.12 * hh)))) * 0.8;
			c = mix(c, vec3(0.26, 0.1, 0.22), clamp(bru, 0.0, 1.0) * g * 0.8);
			// Ojos inyectados: la cuenca negra se vuelve esclerótica rojiza con venas (la pupila roja queda).
			float scl = 1.0 - smoothstep(eye_rad * 0.75, eye_rad * 1.05, de);
			float vein = 1.0 - smoothstep(0.0, 0.08, abs(vn(v_rest * 900.0) - 0.5));
			vec3 eye = mix(vec3(0.86, 0.7, 0.64), vec3(0.55, 0.02, 0.03), clamp(vein * 0.9 + 0.25, 0.0, 1.0));
			c = mix(c, eye, scl * g * (1.0 - pupil));
			// Sangre de la boca rasgada (mentón abajo), de la nariz y de los ojos (lágrimas de sangre).
			float bl = streaks(v_rest, mouth.x, mouth_hw * 2.2, mouth.y - 0.01 * hh, 0.55 * hh * g, mouth_hw * 0.45);
			bl = max(bl, streaks(v_rest, mouth.x, mouth_hw * 0.5, mouth.y + 0.12 * hh, 0.12 * hh * g, mouth_hw * 0.3));
			bl = max(bl, streaks(v_rest, eye_l.x, eye_rad * 0.6, eye_l.y - eye_rad, 0.4 * hh * g, eye_rad * 0.4));
			bl = max(bl, streaks(v_rest, eye_r.x, eye_rad * 0.6, eye_r.y - eye_rad, 0.4 * hh * g, eye_rad * 0.4));
			// Salpicaduras y piel rasgada (grietas) — sin el ruido fino en Modo liviano.
			float spl = 0.0;
			float tear = 0.0;
			if (gore_detail > 0.5) {
				spl = smoothstep(0.74, 0.8, vn(v_rest * 140.0)) * step(0.3, g);
				float cr = abs(vn(v_rest * vec3(70.0, 22.0, 70.0)) - 0.5);
				float cheek = 1.0 - smoothstep(0.1 * hh, 0.32 * hh, abs(v_rest.y - (mouth.y + 0.16 * hh)));
				tear = (1.0 - smoothstep(0.0, 0.025, cr)) * cheek * smoothstep(0.35, 0.8, g);
				float rim = (1.0 - smoothstep(0.025, 0.05, cr)) * cheek * smoothstep(0.35, 0.8, g);
				c = mix(c, vec3(0.78, 0.48, 0.42), rim * 0.6);  // carne viva al borde de la rasgadura
			}
			float wet_m = clamp(max(max(bl, spl), tear), 0.0, 1.0) * g;
			c = mix(c, blood, clamp(max(bl, spl) * 0.95 + tear, 0.0, 1.0) * smoothstep(0.0, 0.25, g));
			rough = mix(rough, 0.18, wet_m);
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metallic_v;
	EMISSION = e;
}

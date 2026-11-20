class_name VitzoFusion
extends RefCounted
## El agente fusionado con Vitzo (v0.3.2, muerte vitzo_fusion de KillMoves; concepto de Joan: piel verde, calvo
## con UNA antena, lentes de marco negro con los ojos desorbitados, cejas de furia, sonrisa maníaca de oreja a
## oreja con los dientes apretados, traje, camisa blanca y corbata). Se arma con el modelo del propio agente
## (models_v2: agente_jiroshi/marko/llauri/ttoom/juan, su cabeza y su cuerpo) mezclado con Vitzo:
##   · la piel pasa al verde de Vitzo (toda la cabeza y el cuello por altura, las manos por el tono de piel medido
##     de cada agente: sirve para todos los tonos), el pelo se oculta (debajo hay cuero cabelludo), la ropa se
##     oscurece a traje (también los brazos descubiertos: mangas);
##   · utilería pegada a los HUESOS (BoneAttachment3D: sigue la animación): lentes y ojos, cejas, la sonrisa (una
##     malla curva ajustada a la cara de cada agente con la boca dibujada por shader), la antena con su zócalo de
##     metal, una placa remachada de Vitzo en la sien y los cables en la nuca (lo de máquina que le quedó), y en el
##     pecho la camisa con corbata y solapas (otra malla ajustada al pecho);
##   · un nodo Driver mantiene el shader al día con la pose y, en la escena 2, le da los tirones de cabeza de Vitzo.
## Medidas (boca y pecho de cada agente): tools/k2_fusion_medir.gd. Nada de caras reales: solo los modelos del juego.

const HEIGHT := 1.72
const GREEN := Color(0.29, 0.66, 0.33)
## Tono de piel de cada agente en su atlas (frente / manos; tools/k2_fusion_medir.gd).
const SKIN_REF: Dictionary = {"jiroshi": Color(0.61, 0.455, 0.41), "marko": Color(0.56, 0.415, 0.42), "llauri": Color(0.705, 0.517, 0.475),
	"ttoom": Color(0.725, 0.494, 0.408), "juan": Color(0.723, 0.56, 0.47)}
## Rejillas medidas (las mismas constantes que la herramienta): radio de la cara en la zona de la boca (cilíndricas
## alrededor del eje x=0, z=MOUTH_AXIS_Z; filas de arriba abajo) y frente del pecho por altura. Unidades del modelo,
## origen en el hueso de la cabeza en reposo, +Z hacia delante.
const MOUTH_COLS := 13
const MOUTH_ROWS := 9
const MOUTH_USE := 8  # filas que usa la malla (la última queda bajo el mentón)
const MOUTH_DEG := 66.0
const MOUTH_Y0 := -0.006
const MOUTH_Y1 := -0.082
const MOUTH_AXIS_Z := 0.015
const CHEST_ROWS := 10
const CHEST_Y0 := -0.105
const CHEST_Y1 := -0.375
const FACES: Dictionary = {
	"jiroshi": {"mouth": [0.0715, 0.0745, 0.0795, 0.0825, 0.0825, 0.0835, 0.076, 0.0835, 0.0825, 0.0825, 0.0795, 0.0745, 0.0715, 0.069, 0.072, 0.077, 0.0805, 0.083, 0.0855, 0.09, 0.0855, 0.083, 0.0805, 0.077, 0.072, 0.069, 0.0665, 0.0695, 0.0745, 0.0785, 0.082, 0.088, 0.0915, 0.088, 0.082, 0.0785, 0.0745, 0.0695, 0.0665, 0.0625, 0.066, 0.071, 0.0755, 0.0805, 0.0845, 0.087, 0.0845, 0.0805, 0.0755, 0.071, 0.066, 0.0625, 0.0575, 0.062, 0.066, 0.0715, 0.077, 0.082, 0.0835, 0.082, 0.077, 0.0715, 0.066, 0.062, 0.0575, 0.0495, 0.0525, 0.059, 0.0665, 0.0725, 0.0785, 0.082, 0.0785, 0.0725, 0.0665, 0.059, 0.0525, 0.0495, 0.0415, 0.0425, 0.046, 0.0555, 0.0675, 0.075, 0.079, 0.075, 0.0675, 0.0555, 0.046, 0.0425, 0.0415, 0.0, 0.0, 0.0, 0.041, 0.0475, 0.0615, 0.064, 0.0615, 0.0475, 0.041, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0355, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "chest": [0.063, 0.047, 0.054, 0.07, 0.082, 0.096, 0.107, 0.109, 0.107, 0.106]},
	"marko": {"mouth": [0.0705, 0.0755, 0.0815, 0.0855, 0.087, 0.087, 0.1055, 0.087, 0.087, 0.0855, 0.0815, 0.0755, 0.0705, 0.0695, 0.0735, 0.079, 0.0835, 0.0865, 0.09, 0.095, 0.09, 0.0865, 0.0835, 0.079, 0.0735, 0.0695, 0.068, 0.0715, 0.077, 0.081, 0.086, 0.0925, 0.098, 0.0925, 0.086, 0.081, 0.077, 0.0715, 0.068, 0.0655, 0.0685, 0.0735, 0.079, 0.0845, 0.089, 0.0925, 0.089, 0.0845, 0.079, 0.0735, 0.0685, 0.0655, 0.0615, 0.065, 0.0695, 0.075, 0.0815, 0.0875, 0.091, 0.0875, 0.0815, 0.075, 0.0695, 0.065, 0.0615, 0.055, 0.06, 0.065, 0.071, 0.0775, 0.084, 0.0875, 0.084, 0.0775, 0.071, 0.065, 0.06, 0.055, 0.047, 0.05, 0.0555, 0.064, 0.073, 0.0815, 0.0865, 0.0815, 0.073, 0.064, 0.0555, 0.05, 0.047, 0.0, 0.0, 0.042, 0.0485, 0.0575, 0.0725, 0.078, 0.0725, 0.0575, 0.0485, 0.042, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0445, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "chest": [0.055, 0.093, 0.093, 0.093, 0.093, 0.097, 0.108, 0.114, 0.112, 0.11]},
	"llauri": {"mouth": [0.071, 0.074, 0.0795, 0.0835, 0.084, 0.086, 0.0965, 0.086, 0.084, 0.0835, 0.0795, 0.074, 0.071, 0.0685, 0.0715, 0.0775, 0.081, 0.0835, 0.0885, 0.0915, 0.0885, 0.0835, 0.081, 0.0775, 0.0715, 0.0685, 0.066, 0.0685, 0.0745, 0.0785, 0.0835, 0.09, 0.094, 0.09, 0.0835, 0.0785, 0.0745, 0.0685, 0.066, 0.063, 0.0655, 0.0705, 0.076, 0.0825, 0.088, 0.091, 0.088, 0.0825, 0.076, 0.0705, 0.0655, 0.063, 0.058, 0.062, 0.067, 0.073, 0.0785, 0.085, 0.0885, 0.085, 0.0785, 0.073, 0.067, 0.062, 0.058, 0.049, 0.0545, 0.0615, 0.0685, 0.0755, 0.081, 0.085, 0.081, 0.0755, 0.0685, 0.0615, 0.0545, 0.049, 0.041, 0.043, 0.049, 0.0595, 0.071, 0.0795, 0.0835, 0.0795, 0.071, 0.0595, 0.049, 0.043, 0.041, 0.0, 0.0, 0.0, 0.04, 0.0505, 0.067, 0.0745, 0.067, 0.0505, 0.04, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "chest": [-0.008, 0.028, 0.045, 0.058, 0.073, 0.089, 0.101, 0.105, 0.104, 0.101]},
	"ttoom": {"mouth": [0.072, 0.0745, 0.08, 0.085, 0.0865, 0.0865, 0.08, 0.0865, 0.0865, 0.085, 0.08, 0.0745, 0.072, 0.0695, 0.072, 0.0775, 0.0825, 0.0855, 0.0905, 0.0945, 0.0905, 0.0855, 0.0825, 0.0775, 0.072, 0.0695, 0.0665, 0.0695, 0.075, 0.0805, 0.0855, 0.0925, 0.0975, 0.0925, 0.0855, 0.0805, 0.075, 0.0695, 0.0665, 0.0635, 0.067, 0.072, 0.078, 0.084, 0.089, 0.093, 0.089, 0.084, 0.078, 0.072, 0.067, 0.0635, 0.0595, 0.063, 0.068, 0.0745, 0.081, 0.087, 0.0905, 0.087, 0.081, 0.0745, 0.068, 0.063, 0.0595, 0.0515, 0.057, 0.0635, 0.0705, 0.0775, 0.0835, 0.0875, 0.0835, 0.0775, 0.0705, 0.0635, 0.057, 0.0515, 0.043, 0.0455, 0.0515, 0.063, 0.073, 0.0825, 0.087, 0.0825, 0.073, 0.063, 0.0515, 0.0455, 0.043, 0.0, 0.0, 0.0, 0.044, 0.0565, 0.073, 0.079, 0.073, 0.0565, 0.044, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.033, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "chest": [-0.006, 0.027, 0.051, 0.067, 0.082, 0.096, 0.107, 0.112, 0.11, 0.107]},
	"juan": {"mouth": [0.0705, 0.0735, 0.078, 0.082, 0.082, 0.0835, 0.094, 0.0835, 0.082, 0.082, 0.078, 0.0735, 0.0705, 0.068, 0.071, 0.0755, 0.079, 0.082, 0.0865, 0.0895, 0.0865, 0.082, 0.079, 0.0755, 0.071, 0.068, 0.0655, 0.068, 0.073, 0.077, 0.0815, 0.088, 0.093, 0.088, 0.0815, 0.077, 0.073, 0.068, 0.0655, 0.0625, 0.065, 0.0695, 0.0745, 0.08, 0.085, 0.089, 0.085, 0.08, 0.0745, 0.0695, 0.065, 0.0625, 0.0565, 0.061, 0.065, 0.071, 0.0765, 0.0825, 0.0845, 0.0825, 0.0765, 0.071, 0.065, 0.061, 0.0565, 0.048, 0.0525, 0.0595, 0.067, 0.073, 0.079, 0.083, 0.079, 0.073, 0.067, 0.0595, 0.0525, 0.048, 0.039, 0.041, 0.045, 0.0565, 0.068, 0.0765, 0.0805, 0.0765, 0.068, 0.0565, 0.045, 0.041, 0.039, 0.0, 0.0, 0.0, 0.0385, 0.045, 0.06, 0.067, 0.06, 0.045, 0.0385, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "chest": [0.036, 0.028, 0.049, 0.067, 0.082, 0.094, 0.105, 0.108, 0.104, 0.101]},
}
const EYE := Vector3(0.031, 0.041, 0.112)  # centro de cada lente (x = ±)
const CROWN := Vector3(0.0, 0.149, 0.012)

const SKIN_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 green : source_color = vec4(0.27, 0.70, 0.34, 1.0);
uniform vec4 skin_ref : source_color = vec4(0.7, 0.5, 0.45, 1.0);
uniform float neck_y = 1.4;   // desde aquí hacia arriba todo es piel (cuello y cabeza), en el espacio de la malla
uniform float wrist_y = 0.0;  // de aquí hacia abajo la piel detectada son las manos; entre medio, mangas
uniform float fuse = 1.0;     // 0 = el agente como era, 1 = verde de Vitzo (etapas de la fusión)
uniform float hands_fuse = 0.0;  // verde propio de manos y antebrazos (les llega antes que a la cara)
uniform float arm_x = 99.0;   // |x| de la malla en reposo desde donde es antebrazo y mano
uniform float veins = 0.0;    // venas verde oscuro que se extienden
uniform float suit = 1.0;     // la ropa pasa a traje oscuro
uniform float glitch = 1.0;
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float mx = max(c.r, max(c.g, c.b));
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float rl = dot(skin_ref.rgb, vec3(0.3, 0.59, 0.11));
	// Piel por tono (el de ESTE agente: vale para piel clara y oscura) y, sobre el cuello, todo.
	vec3 nc = c / max(mx, 0.001);
	vec3 nr = skin_ref.rgb / max(skin_ref.r, max(skin_ref.g, skin_ref.b));
	float tone = (1.0 - smoothstep(0.10, 0.22, distance(nc, nr))) * smoothstep(0.14, 0.28, mx);
	float head = smoothstep(neck_y - 0.014, neck_y + 0.004, lp.y);
	float hands = 1.0 - smoothstep(wrist_y, wrist_y + 0.03, lp.y);
	float upper = smoothstep(neck_y - 0.11, neck_y - 0.07, lp.y);  // el cuello dentro del cuello de la camisa
	float skin = max(head, tone * max(max(hands, upper), 1.0 - suit));  // sin traje aún, los brazos también
	// Verde con la luz de la piel original relativa a su tono (cejas, ojos y pliegues siguen oscuros).
	float rel = l / max(rl, 0.05);
	vec3 g = green.rgb * clamp(pow(rel, 1.2) * 1.05, 0.05, 1.35);
	float far = smoothstep(arm_x - 0.03, arm_x + 0.05, abs(lp.x));
	float sk = skin * clamp(max(fuse, hands_fuse * far), 0.0, 1.0);
	// Venas: crestas finas de ruido verde oscuro; al completarse el verde se hunden en la piel.
	float vn = (1.0 - smoothstep(0.0, 0.035, abs(n3(lp * vec3(46.0, 120.0, 46.0)) - 0.5)));
	float v = vn * skin * veins * mix(1.0, 0.14, smoothstep(0.8, 1.0, max(fuse, hands_fuse * far)));
	vec3 cs = mix(c, g, sk);
	cs = mix(cs, vec3(0.03, 0.24, 0.08), v * 0.8);
	// Traje oscuro: lo que no es piel (ropa, mangas, brazos descubiertos) se oscurece.
	cs = mix(cs, vec3(0.018, 0.04, 0.028) + cs * 0.07, (1.0 - skin) * suit);
	// Glitch: bandas horizontales que parpadean (12 Hz), verdes.
	float band = step(0.975, fract(sin(floor(FRAGCOORD.y / 5.0) * 12.9898 + floor(TIME * 12.0)) * 43758.5)) * glitch * step(0.55, fract(TIME * 0.9));
	ALBEDO = mix(cs, vec3(0.2, 1.0, 0.45), band * 0.5);
	// Tinte subsuperficial: el verde brilla en los bordes (fresnel) como piel translúcida.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = vec3(0.08, 0.5, 0.18) * sk * (0.06 + 0.45 * fres) + vec3(0.1, 0.6, 0.25) * band;
	ROUGHNESS = mix(0.8, 0.4, sk);
	SPECULAR = mix(0.3, 0.6, sk);
}
"""

## La sonrisa: se dibuja sobre una malla curva pegada a la cara (u de comisura a comisura, v de la nariz al mentón).
const GRIN_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float grin = 1.0;      // 0 = boca cerrada chica, 1 = de oreja a oreja
uniform float open = 0.0;      // 0 = dientes apretados, 1 = la boca abierta en grito (las filas separadas, negro al fondo)
uniform vec4 green : source_color = vec4(0.27, 0.70, 0.34, 1.0);
void fragment() {
	float a = UV.x * 2.0 - 1.0;
	float v = UV.y;
	float amax = 0.86 * (0.4 + 0.6 * grin) * (1.0 - 0.1 * open);
	float vc = 0.60 + 0.045 * open - 0.42 * a * a * (0.3 + 0.7 * grin) * (1.0 - 0.45 * open);   // comisuras hacia arriba
	float hh = 0.17 * (0.3 + 0.7 * grin) * (1.0 + 0.7 * open) * sqrt(max(1.0 - pow(abs(a) / amax, 2.4), 0.0));
	float d = abs(v - vc);
	float inside = step(abs(a), amax) * step(d, hh);
	float lip = step(abs(a), amax + 0.035) * step(d, hh + 0.05) * (1.0 - inside);
	// Pliegues de la mejilla (de la comisura hacia la nariz) y arrugas de la comisura.
	float vcor = 0.60 - 0.42 * amax * amax * (0.3 + 0.7 * grin);
	float fold_x = amax + 0.09 + 0.55 * (v - vcor) * (v - vcor) - 0.25 * max(vcor - v, 0.0);
	float fold = (1.0 - smoothstep(0.012, 0.03, abs(abs(a) - fold_x))) * step(vcor - 0.42, v) * step(v, vcor + 0.2) * grin;
	// Piel verde entre la nariz y la boca: tapa la boca pintada del agente; el borde se difumina con tramado.
	float cov = smoothstep(amax * 0.98, amax * 0.62, abs(a)) * smoothstep(0.10, 0.24, v) * step(v, vc + hh) * step(0.25, grin);
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cover = step(dither, cov) * (1.0 - inside) * (1.0 - lip);
	if (inside + lip + fold + cover < 0.5) { discard; }
	vec3 col = green.rgb * 0.34;                                           // labio / pliegue: verde oscuro
	float em = 0.0;
	if (cover > 0.5 && fold < 0.5) { col = green.rgb * (0.92 - 0.22 * a * a); em = 0.05; }
	if (inside > 0.5) {
		float t = (a / amax * 0.5 + 0.5) * 11.0;                          // 11 dientes por fila
		float gap = min(fract(t), 1.0 - fract(t));
		float e0 = d / max(hh, 0.001);                                     // 0 = línea de mordida, 1 = encía
		float gapw = 0.56 * open;                                          // lo que queda abierto entre las dos filas
		float edge = clamp((e0 - gapw) / (1.0 - gapw), 0.0, 1.0);          // dentro del diente: 0 = filo, 1 = encía
		vec3 tooth = mix(vec3(0.93, 0.91, 0.80), vec3(0.74, 0.68, 0.50), smoothstep(0.35, 1.0, edge));
		col = tooth;
		em = 0.16;
		col = mix(col, vec3(0.05, 0.02, 0.02), 1.0 - smoothstep(0.02, 0.07, gap));       // separación entre dientes
		col = mix(col, vec3(0.03, 0.0, 0.0), 1.0 - smoothstep(0.03, 0.09, edge));        // dientes apretados
		col = mix(col, vec3(0.30, 0.04, 0.06), smoothstep(0.80, 0.97, edge));            // encías
		em *= smoothstep(0.03, 0.09, edge) * smoothstep(0.02, 0.07, gap);
		if (e0 < gapw) {
			// la boca abierta: negro al fondo y la lengua abajo
			float low = smoothstep(0.0, 1.0, (v - vc) / max(hh * gapw, 0.001));
			col = mix(vec3(0.015, 0.0, 0.0), vec3(0.34, 0.05, 0.07), low * (1.0 - 0.6 * a * a / max(amax * amax, 0.01)) * 0.8);
			em = 0.0;
		}
	}
	ALBEDO = col;
	EMISSION = col * em;
	ROUGHNESS = 0.4;
}
"""

## Camisa blanca, cuello, corbata y solapas del traje sobre el pecho (u = ancho, v = del cuello hacia abajo).
const SHIRT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float k = 1.0;  // 0..1: aparece
void fragment() {
	float x = UV.x * 2.0 - 1.0;   // -1..1 = ±9 cm
	float v = UV.y;
	float open = 0.62 * (1.0 - smoothstep(0.0, 0.9, v)) + 0.02;           // la V de la chaqueta
	float shirt = step(abs(x), open) * step(v, 0.92 * k);
	float lapel = step(abs(x), open + 0.2 * (1.0 - v * 0.6)) * (1.0 - step(abs(x), open)) * step(v, 0.95 * k);
	if (shirt + lapel < 0.5) { discard; }
	vec3 col = vec3(0.03, 0.06, 0.042);                                    // solapa
	if (lapel > 0.5) { col += vec3(0.05) * smoothstep(0.02, 0.0, abs(abs(x) - open - 0.012)); }
	if (shirt > 0.5) {
		col = vec3(0.90, 0.91, 0.88) * (1.0 - 0.25 * smoothstep(open * 0.5, open, abs(x)));
		// Cuello de la camisa: dos puntas.
		float collar = step(v, 0.16 - 0.5 * abs(abs(x) - 0.2)) ;
		col = mix(col, vec3(0.97, 0.97, 0.95), collar);
		col = mix(col, vec3(0.55, 0.57, 0.55), collar * (1.0 - smoothstep(0.0, 0.02, abs(v - (0.16 - 0.5 * abs(abs(x) - 0.2))))));
		// Corbata: nudo y pala (verde casi negro, a rayas finas).
		float knot = step(abs(x), 0.115 - 0.25 * (v - 0.04)) * step(0.04, v) * step(v, 0.15);
		float hw = mix(0.075, 0.15, smoothstep(0.15, 0.8, v));
		float blade = step(0.15, v) * step(abs(x), hw) * step(v, 0.80 + (hw - abs(x)) * 0.7);
		float tie = max(knot, blade);
		vec3 tc = mix(vec3(0.035, 0.04, 0.07), vec3(0.5, 0.07, 0.08), step(0.86, fract((v * 1.6 + x * 0.5) * 7.0)));
		col = mix(col, tc, tie);
	}
	ALBEDO = col;
	ROUGHNESS = 0.7;
}
"""
## El pelo: se le cae a mechones (gone 0 → 1; ruido en el espacio de la malla) dejando el cuero cabelludo, que ya es
## piel verde. Por defecto calvo (escena 2 y vistas); la escena 1 lo va soltando (etapa "hair").
const HAIR_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float gone = 1.0;
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() { lp = VERTEX; }
void fragment() {
	float n = n3(lp * 10.0) * 0.7 + n3(lp * 26.0) * 0.3;   // mechones de 8-10 cm con el borde deshilachado
	float cut = gone * 1.04;
	if (n <= cut) { discard; }
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	ALBEDO = mix(vec3(0.07, 0.3, 0.12), c, smoothstep(cut, cut + 0.07, n));   // el borde del mechón, verdoso
	ROUGHNESS = 0.85;
}
"""
static var _shader: Shader = null
static var _grin_shader: Shader = null
static var _shirt_shader: Shader = null
static var _hair_shader: Shader = null


## Mantiene el shader de la piel al día con la pose (cuello y muñecas) y da los tirones de cabeza (escena 2).
class Driver extends Node3D:
	var sk: Skeleton3D = null
	var mesh: MeshInstance3D = null
	var mats: Array = []
	var head_i: int = -1
	var hand_i: Array = []
	var antenna: Node3D = null
	var twitch: bool = false
	var shake: float = 0.0  # te resistes: la cabeza se sacude de lado a lado (rad)
	var _next: float = 0.6
	var _q: Quaternion = Quaternion.IDENTITY
	var _t: float = 0.0

	func _ready() -> void:
		process_priority = 100  # después del AnimationPlayer
		_sync()

	func _sync() -> void:
		if sk == null or not is_instance_valid(sk) or mesh == null or head_i < 0:
			return
		var to_mesh := mesh.global_transform.affine_inverse() * sk.global_transform
		var neck := (to_mesh * sk.get_bone_global_pose(head_i).origin).y - 0.092
		var wrist := -99.0
		for hi in hand_i:
			wrist = maxf(wrist, (to_mesh * sk.get_bone_global_pose(hi).origin).y)
		for m in mats:
			(m as ShaderMaterial).set_shader_parameter("neck_y", neck)
			(m as ShaderMaterial).set_shader_parameter("wrist_y", wrist + 0.035)

	func _process(delta: float) -> void:
		_t += delta
		if twitch and sk != null and is_instance_valid(sk) and head_i >= 0:
			_next -= delta
			if _next <= 0.0:
				# Un tirón seco (como Vitzo: a saltos): la cabeza cae a un lado o se endereza de golpe.
				_next = randf_range(0.35, 1.1)
				_q = Quaternion.from_euler(Vector3(randf_range(-0.10, 0.12), randf_range(-0.16, 0.16), randf_range(-0.3, 0.3))) if randf() < 0.75 else Quaternion.IDENTITY
			sk.set_bone_pose_rotation(head_i, sk.get_bone_pose_rotation(head_i) * _q)
		if shake > 0.001 and sk != null and is_instance_valid(sk) and head_i >= 0:
			var sq := Quaternion.from_euler(Vector3(sin(_t * 23.0) * shake * 0.35, sin(_t * 37.0) * shake, sin(_t * 29.0) * shake * 0.5))
			sk.set_bone_pose_rotation(head_i, sk.get_bone_pose_rotation(head_i) * sq)
		if antenna != null and is_instance_valid(antenna):
			antenna.rotation.z = sin(_t * 9.0) * 0.05 + (0.12 * sin(_t * 31.0) if twitch and _next < 0.12 else 0.0)
		_sync()


## El agente fusionado, en el escenario del screamer. close = escena 1 (donde estás, mirando a tu vista); si no, de
## pie mirando hacia -Z del nodo. Devuelve la raíz (meta "rig", "head", "driver").
static func build(fx: Screamers, agent: String, close: bool) -> Node3D:
	var root := build_at(fx._stage, agent)
	if close and root.has_meta("rig"):
		var e := fx._eye()
		var f := fx._dir(0.0)
		root.global_position = Vector3(e.x, fx._floor_y(), e.z)
		root.look_at(root.global_position + f, Vector3.UP)
	return root


## El modelo fusionado colgado de `parent` (sin screamer: lo usan las vistas de revisión y las pruebas).
static func build_at(parent: Node, agent: String) -> Node3D:
	var root := Node3D.new()
	root.name = "AgenteFusionado"
	parent.add_child(root)
	var rig := CharacterRig.attach(root, CharacterRig.agent_model(agent), HEIGHT)
	if rig == null:
		Greybox.box(root, "Silueta", Vector3(0, 0.86, 0), Vector3(0.45, 1.72, 0.28), GREEN, false)
		root.set_meta("head", Vector3(0, 1.6, 0))
		return root
	rig.play("idle", true, 0.0, ["stand"])  # quieto: el reminder lo dice sin moverse
	root.set_meta("rig", rig)
	root.set_meta("agent", agent.to_lower())
	_skin(rig, agent.to_lower())
	var head_l := _head_local(rig)
	root.set_meta("head", head_l)
	_props(root, rig, agent.to_lower())
	stage(root, 1.0, 1.0, 1.0, 1.0)
	return root


## Etapas de la fusión (0..1): verde de la piel (y el traje), venas, lentes (con ojos y cejas), sonrisa, antena.
static func stage(root: Node3D, green: float, glasses: float, grin: float, antenna: float) -> void:
	_stage_set(root, "green", green)
	_stage_set(root, "veins", green)
	_stage_set(root, "glasses", glasses)
	_stage_set(root, "grin", grin)
	_stage_set(root, "antenna", antenna)


static func _stage_set(root: Node3D, what: String, v: float) -> void:
	root.set_meta("st_" + what, v)
	match what:
		"green", "veins":
			for sm in root.get_meta("mats", []) as Array:
				(sm as ShaderMaterial).set_shader_parameter("fuse" if what == "green" else "veins", v)
				if what == "green":
					(sm as ShaderMaterial).set_shader_parameter("suit", smoothstep(0.25, 0.9, v))
			if what == "green":
				var sh := root.find_child("Camisa", true, false) as MeshInstance3D
				if sh != null:
					sh.visible = v > 0.3
					(sh.material_override as ShaderMaterial).set_shader_parameter("k", smoothstep(0.3, 1.0, v))
				if not root.has_meta("st_hw"):  # sin etapa propia, lo de máquina sale con el verde (escena 2, vistas)
					for n in ["PlacaVitzo", "CablesNuca"]:
						var hw := root.find_child(n, true, false) as Node3D
						if hw != null:
							hw.visible = v > 0.55
		"hw":
			# Lo de máquina (perillas en las orejas, cables en la nuca) le BROTA de la cabeza: crece desde adentro.
			for n in ["PlacaVitzo", "CablesNuca"]:
				var hw2 := root.find_child(n, true, false) as Node3D
				if hw2 != null:
					hw2.visible = v > 0.02
					hw2.scale = Vector3.ONE * clampf(v, 0.02, 1.0)
		"glasses":
			for n in ["Lentes", "OjosSaltones", "Cejas"]:
				var g := root.find_child(n, true, false) as Node3D
				if g != null:
					g.visible = v > 0.02
					g.scale = Vector3.ONE * maxf(v, 0.02)
					if n == "Lentes":
						# Se le CLAVAN: el marco aparece a 3 cm de la cara y entra hasta hundirse un poco en la piel.
						g.position.z = EYE.z + 0.03 * (1.0 - clampf(v, 0.0, 1.0)) - 0.003 * clampf(v, 0.0, 1.0)
		"grin":
			var s := root.find_child("Sonrisa", true, false) as MeshInstance3D
			if s != null:
				s.visible = v > 0.02
				(s.material_override as ShaderMaterial).set_shader_parameter("grin", v)
		"open":
			# La boca de la sonrisa se abre (grita) o se cierra de golpe (los dientes apretados del concepto).
			var s2 := root.find_child("Sonrisa", true, false) as MeshInstance3D
			if s2 != null:
				(s2.material_override as ShaderMaterial).set_shader_parameter("open", clampf(v, 0.0, 1.0))
		"hands":
			# El verde de manos y antebrazos (va adelantado al de la cara: es lo primero que se te pone verde).
			for sm3 in root.get_meta("mats", []) as Array:
				(sm3 as ShaderMaterial).set_shader_parameter("hands_fuse", clampf(v, 0.0, 1.0))
		"hair":
			# Cuánto pelo le queda (1 = todo, 0 = calvo): se le cae a mechones.
			for hm in root.get_meta("hair_mats", []) as Array:
				(hm as ShaderMaterial).set_shader_parameter("gone", 1.0 - clampf(v, 0.0, 1.0))
		"antenna":
			var a := root.find_child("Antena", true, false) as Node3D
			if a != null:
				a.visible = v > 0.02
				a.scale = Vector3(1, maxf(v, 0.02), 1)


## Una etapa animada (a saltos si jumpy: los lentes se materializan con glitch).
static func stage_to(root: Node3D, what: String, v: float, t: float, jumpy: bool = false) -> void:
	var v0 := float(root.get_meta("st_" + what, 0.0))
	var tw := root.create_tween()
	if jumpy:
		for i in 5:
			var u := (i + 1) / 5.0
			tw.tween_callback(func() -> void:
				if is_instance_valid(root):
					_stage_set(root, what, lerpf(v0, v, u) if i % 2 == 0 or i == 4 else 0.0))
			tw.tween_interval(t / 5.0)
	else:
		tw.tween_method(func(x: float) -> void:
			if is_instance_valid(root):
				_stage_set(root, what, x), v0, v, maxf(t, 0.02))


## Los tirones de cabeza de Vitzo (escena 2: quieto, recitando, con la cabeza que salta).
static func set_twitch(root: Node3D, on: bool) -> void:
	var d := root.get_meta("driver", null) as Driver
	if d != null and is_instance_valid(d):
		d.twitch = on


## Te resistes (escena 1, tercera persona): la cabeza se sacude; amp en radianes (0 = quieta).
static func set_shake(root: Node3D, amp: float) -> void:
	var d := root.get_meta("driver", null) as Driver
	if d != null and is_instance_valid(d):
		d.shake = amp


## Punto de la cabeza (mundo).
static func head_point(root: Node3D) -> Vector3:
	return root.global_transform * (root.get_meta("head", Vector3(0, 1.6, 0)) as Vector3)


## Un punto de la CARA con la pose de este cuadro (mundo): local en el marco de la cara (x derecha del modelo, y
## arriba, +z delante; origen en el hueso de la cabeza). Sin argumento: entre los ojos.
static func face_point(root: Node3D, local: Vector3 = Vector3(0.0, 0.041, 0.09)) -> Vector3:
	var face := root.get_meta("face", null) as Node3D
	if face != null and is_instance_valid(face) and face.is_inside_tree():
		return face.global_transform * local
	return head_point(root)


## Sangre que brota donde algo se le clava (los lentes en las sienes y el puente de la nariz; con «Reducido», nada):
## gotas pegadas a la cara que crecen y corren hacia abajo en t s.
static func bleed(fx: Screamers, root: Node3D, t: float = 1.0) -> void:
	if not KillGore.enabled():
		return
	var face := root.get_meta("face", null) as Node3D
	if face == null or not is_instance_valid(face):
		return
	var m := KillProps.mat(Color(0.42, 0.0, 0.02), 0.0, false, 0.12)
	var spots: Array[Vector3] = [Vector3(EYE.x + 0.036, EYE.y + 0.004, EYE.z - 0.014), Vector3(-EYE.x - 0.036, EYE.y + 0.004, EYE.z - 0.014),
		Vector3(EYE.x + 0.03, EYE.y - 0.021, EYE.z - 0.006), Vector3(-EYE.x - 0.03, EYE.y - 0.021, EYE.z - 0.006), Vector3(0.007, EYE.y + 0.004, EYE.z + 0.004)]
	for i in spots.size():
		var d := _mesh(face, _sphere(0.0042), m, spots[i], "Sangre%d" % i)
		d.scale = Vector3.ONE * 0.2
		var run := randf_range(0.02, 0.045)
		var tw := d.create_tween().set_parallel(true)
		tw.tween_property(d, "scale", Vector3(1.0, 1.0 + run * 70.0, 0.55), maxf(t, 0.05)).set_delay(0.07 * i)
		tw.tween_property(d, "position:y", spots[i].y - run * 0.5, maxf(t, 0.05)).set_delay(0.07 * i)
	KillGore._note(fx, "sangre")


## Toma de tercera persona: la cámara va de `a` a `b` en `dur` s (suavizado), apuntando a look() (un punto del mundo
## que se recalcula cada cuadro: sigue la cabeza del agente, con un retardo de operador), con pulso de cámara en mano,
## sacudones (kick) y, si se pide, inclinada (roll). Una sola por muerte: cut() cambia de plano.
class Shot extends Node:
	var cam: Camera3D = null
	var a: Vector3 = Vector3.ZERO
	var b: Vector3 = Vector3.ZERO
	var dur: float = 1.0
	var t: float = 0.0
	var look: Callable = Callable()
	var aim: Vector3 = Vector3.INF
	var aim_rate: float = 9.0
	var roll: float = 0.0
	var fov_a: float = 50.0
	var fov_b: float = 50.0
	var hand: float = 0.004
	var kick: float = 0.0
	var soft: bool = false
	var light: OmniLight3D = null  # luz de la toma: va con la cámara (arriba y a un lado), más suave de cerca
	var _n: float = 0.0

	func _ready() -> void:
		process_priority = 120  # después de la animación y de quien cuelga la vista de la cabeza

	func cut(p_a: Vector3, p_b: Vector3, p_dur: float, p_look: Callable, p_fov_a: float = 50.0, p_fov_b: float = -1.0, p_roll: float = 0.0) -> void:
		a = p_a
		b = p_b
		dur = maxf(p_dur, 0.05)
		t = 0.0
		look = p_look
		fov_a = p_fov_a
		fov_b = p_fov_b if p_fov_b > 0.0 else p_fov_a
		roll = p_roll
		aim = Vector3.INF
		_apply(0.0)

	func _process(delta: float) -> void:
		t += delta
		_n += delta
		kick = move_toward(kick, 0.0, delta * 0.45)
		_apply(delta)

	func _apply(delta: float) -> void:
		if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
			return
		var u := clampf(t / dur, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var want: Vector3 = look.call() if look.is_valid() else cam.global_position - cam.global_transform.basis.z
		aim = want if aim == Vector3.INF else aim.lerp(want, minf(delta * aim_rate, 1.0))
		var pos := a.lerp(b, e)
		cam.global_position = pos
		if pos.distance_to(aim) > 0.05 and absf((aim - pos).normalized().y) < 0.995:
			cam.look_at(aim, Vector3.UP)
		var k := kick * (0.35 if soft else 1.0)
		var j := Vector3(sin(_n * 5.3) + 0.5 * sin(_n * 11.7), sin(_n * 4.1 + 1.3) + 0.5 * sin(_n * 9.3), 0.0) * hand * 0.66
		if k > 0.0005:
			j += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * k
		cam.global_position = pos + cam.global_transform.basis * j
		if light != null and is_instance_valid(light):
			light.global_position = pos + cam.global_transform.basis * Vector3(-0.3, 0.32, 0.12)
			light.light_energy = 0.25 + 0.7 * clampf(pos.distance_to(aim), 0.4, 2.4)
		if absf(roll) > 0.0001:
			cam.rotate_object_local(Vector3.BACK, roll)
		cam.fov = lerpf(fov_a, fov_b, e)


static func _skeleton(rig: Node) -> Skeleton3D:
	var sk: Skeleton3D = null
	for c in rig.find_children("*", "Skeleton3D", true, false):
		sk = c
	return sk


static func _bone(sk: Skeleton3D, names: Array) -> int:
	for n in names:
		var i := sk.find_bone(n)
		if i >= 0:
			return i
	return -1


## Centro de la cara (ojos/nariz) en el espacio de la raíz.
static func _head_local(rig: CharacterRig) -> Vector3:
	var sk := _skeleton(rig)
	if sk != null:
		var i := _bone(sk, ["head", "Head", "cabeza"])
		if i >= 0:
			var wp := sk.global_transform * (sk.get_bone_global_pose(i).origin + Vector3(0, 0.03, 0))
			var p := rig.get_parent() as Node3D
			return p.global_transform.affine_inverse() * wp
	return Vector3(0, HEIGHT - 0.12, 0)


## Piel verde (del atlas del propio agente), sin pelo, ropa a traje.
static func _skin(rig: CharacterRig, agent: String) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SKIN_SHADER
	var root := rig.get_parent()
	var mats: Array = []
	var hair: Array = []
	var first: MeshInstance3D = null
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if str(mi.name).to_lower().contains("pelo") or str(mi.name).to_lower().contains("afro"):
			mi.visible = false
			continue
		if first == null:
			first = mi
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			if src.resource_name.ends_with("_pelo"):
				if _hair_shader == null:
					_hair_shader = Shader.new()
					_hair_shader.code = HAIR_SHADER
				var hm := ShaderMaterial.new()
				hm.shader = _hair_shader
				hm.set_shader_parameter("albedo_tex", src.albedo_texture)
				hm.set_shader_parameter("albedo_color", src.albedo_color)
				hm.set_shader_parameter("gone", 1.0)  # calvo, salvo que la escena 1 pida el pelo (etapa "hair")
				mi.set_surface_override_material(i, hm)
				hair.append(hm)
				continue
			var sm := ShaderMaterial.new()
			sm.shader = _shader
			sm.set_shader_parameter("albedo_tex", src.albedo_texture)
			sm.set_shader_parameter("albedo_color", src.albedo_color)
			sm.set_shader_parameter("green", GREEN)
			sm.set_shader_parameter("skin_ref", SKIN_REF.get(agent, Color(0.7, 0.5, 0.45)))
			mi.set_surface_override_material(i, sm)
			mats.append(sm)
	root.set_meta("mats", mats)
	root.set_meta("hair_mats", hair)
	var sk := _skeleton(rig)
	var d := Driver.new()
	d.name = "FusionDriver"
	d.sk = sk
	d.mesh = first
	d.mats = mats
	if sk != null:
		d.head_i = _bone(sk, ["head", "Head", "cabeza"])
		for n in ["hand_l", "hand_r"]:
			if sk.find_bone(n) >= 0:
				d.hand_i.append(sk.find_bone(n))
		# Desde dónde es antebrazo (malla en reposo, brazos abiertos): un tercio del camino del codo a la muñeca.
		var el := sk.find_bone("lowerarm_l")
		var wr := sk.find_bone("hand_l")
		if el >= 0 and wr >= 0 and first != null:
			var to_mesh := first.global_transform.affine_inverse() * sk.global_transform
			var ex := absf((to_mesh * sk.get_bone_global_rest(el).origin).x)
			var wx := absf((to_mesh * sk.get_bone_global_rest(wr).origin).x)
			if wx > ex + 0.05:
				for sm2 in mats:
					(sm2 as ShaderMaterial).set_shader_parameter("arm_x", lerpf(ex, wx, 0.33))
	root.add_child(d)
	root.set_meta("driver", d)


## Un marco pegado a un hueso con los ejes del modelo (x derecha, y arriba, +z delante) y origen en el hueso de la
## cabeza en reposo: ahí se colocan las piezas con las medidas de tools/k2_fusion_medir.gd.
static func _frame(sk: Skeleton3D, bone: int, head: int, name: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.name = "Hueso" + name
	ba.bone_idx = bone
	sk.add_child(ba)
	var f := Node3D.new()
	f.name = name
	ba.add_child(f)
	f.transform = sk.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis.IDENTITY, sk.get_bone_global_rest(head).origin)
	return f


static func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


static func _cyl(r0: float, r1: float, hgt: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = hgt
	c.radial_segments = 12
	return c


## Malla curva de la boca: sigue el radio medido de la cara de este agente (+ 3,5 mm).
static func _grin_mesh(agent: String) -> ArrayMesh:
	var tab: Array = (FACES.get(agent, FACES["jiroshi"]) as Dictionary)["mouth"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for j in MOUTH_USE:
		var y := lerpf(MOUTH_Y0, MOUTH_Y1, j / float(MOUTH_ROWS - 1))
		for i in MOUTH_COLS:
			var th := deg_to_rad(lerpf(-MOUTH_DEG, MOUTH_DEG, i / float(MOUTH_COLS - 1)))
			var r := float(tab[j * MOUTH_COLS + i])
			var jj := j
			while r < 0.02 and jj > 0:  # bajo el mentón no hay cara: se usa la fila de arriba, algo metida
				jj -= 1
				r = float(tab[jj * MOUTH_COLS + i]) - 0.004 * (j - jj)
			if j == 0:
				r = minf(r, float(tab[MOUTH_COLS + i]) + 0.004)  # sin la punta de la nariz
			pts.append(Vector3(sin(th) * (r + 0.0035), y, MOUTH_AXIS_Z + cos(th) * (r + 0.0035)))
	for j in MOUTH_USE - 1:
		for i in MOUTH_COLS - 1:
			var q := [j * MOUTH_COLS + i, j * MOUTH_COLS + i + 1, (j + 1) * MOUTH_COLS + i + 1, (j + 1) * MOUTH_COLS + i]
			for k in [0, 1, 2, 0, 2, 3]:
				var idx: int = q[k]
				var pj := idx / MOUTH_COLS
				var pi := idx % MOUTH_COLS
				st.set_uv(Vector2(pi / float(MOUTH_COLS - 1), pj / float(MOUTH_USE - 1)))
				var p: Vector3 = pts[idx]
				st.set_normal(Vector3(p.x, 0, p.z - MOUTH_AXIS_Z).normalized())
				st.add_vertex(p)
	return st.commit()


## Malla de la camisa: 18 cm de ancho, sigue el frente del pecho medido (+ 9 mm) y se curva hacia los lados.
static func _shirt_mesh(agent: String) -> ArrayMesh:
	var tab: Array = (FACES.get(agent, FACES["jiroshi"]) as Dictionary)["chest"]
	var zs: Array = []
	for j in CHEST_ROWS:
		zs.append(float(tab[j]))
	for j in range(CHEST_ROWS - 2, -1, -1):  # arriba (cuello, audífonos al cuello): nunca muy por detrás de la fila de abajo
		zs[j] = clampf(float(zs[j]), float(zs[j + 1]) - 0.022, float(zs[j + 1]) + 0.004)
	var cols := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for j in CHEST_ROWS:
		var y := lerpf(CHEST_Y0, CHEST_Y1, j / float(CHEST_ROWS - 1))
		for i in cols:
			var x := lerpf(-0.09, 0.09, i / float(cols - 1))
			pts.append(Vector3(x, y, float(zs[j]) + 0.009 - 1.1 * x * x))
	for j in CHEST_ROWS - 1:
		for i in cols - 1:
			var q := [j * cols + i, j * cols + i + 1, (j + 1) * cols + i + 1, (j + 1) * cols + i]
			for k in [0, 1, 2, 0, 2, 3]:
				var idx: int = q[k]
				st.set_uv(Vector2((idx % cols) / float(cols - 1), (idx / cols) / float(CHEST_ROWS - 1)))
				st.set_normal(Vector3(0, 0.25, 1).normalized())
				st.add_vertex(pts[idx])
	return st.commit()


## Lentes y ojos, cejas, sonrisa, antena, placa, cables (cabeza) y camisa con corbata (pecho).
static func _props(root: Node3D, rig: CharacterRig, agent: String) -> void:
	var sk := _skeleton(rig)
	if sk == null:
		return
	var hi := _bone(sk, ["head", "Head", "cabeza"])
	if hi < 0:
		return
	var face := _frame(sk, hi, hi, "CaraFusion")
	root.set_meta("face", face)
	var black := KillProps.mat(Color(0.025, 0.025, 0.03), 0.0, false, 0.25)
	var metal := KillProps.mat(Color(0.34, 0.4, 0.37), 0.0, false, 0.35)
	metal.metallic = 0.6
	var skin_dark := KillProps.mat(Color(GREEN.r * 0.3, GREEN.g * 0.3, GREEN.b * 0.3), 0.0, false, 0.5)
	# --- Ojos desorbitados: el blanco entero a la vista, pupila chica, venitas rojas (dentro del marco).
	var eyes := Node3D.new()
	eyes.name = "OjosSaltones"
	eyes.position = Vector3(0, EYE.y, EYE.z)
	face.add_child(eyes)
	for sd in [-1.0, 1.0]:
		var eb := _mesh(eyes, _sphere(0.0185), KillProps.mat(Color(0.96, 0.94, 0.9), 0.3, false, 0.15), Vector3(EYE.x * sd, -0.001, -0.0075))
		eb.scale = Vector3(1.12, 0.78, 0.5)
		var pup := _mesh(eyes, _sphere(0.0052), KillProps.mat(Color(0.01, 0.01, 0.01), 0.0, false, 0.1), Vector3(EYE.x * sd - 0.001 * sd, -0.001, 0.0012))
		pup.scale = Vector3(1, 1, 0.35)
		var glint := _mesh(eyes, _sphere(0.0014), KillProps.mat(Color(1, 1, 1), 1.5), Vector3(EYE.x * sd + 0.002, 0.002, 0.003))
		glint.scale = Vector3(1, 1, 0.4)
		for k in 4:  # venitas rojas hacia el borde
			var ang := (k - 1.5) * 0.5 + (PI if sd < 0.0 else 0.0)
			var vb := KillProps.box(eyes, Vector3(0.008, 0.001, 0.0008), Color(0.72, 0.05, 0.05), Vector3(EYE.x * sd + cos(ang) * 0.0145, -0.001 + sin(ang) * 0.009, 0.0002))
			vb.rotation.z = ang
	# --- Lentes rectangulares de marco negro grueso (como el concepto de Joan).
	var gl := Node3D.new()
	gl.name = "Lentes"
	gl.position = Vector3(0, EYE.y, EYE.z)
	face.add_child(gl)
	var fc := Color(0.02, 0.02, 0.025)
	for sd in [-1.0, 1.0]:
		var cx: float = (EYE.x + 0.002) * sd
		KillProps.box(gl, Vector3(0.062, 0.0065, 0.006), fc, Vector3(cx, 0.0175, 0.0))    # arriba (más grueso)
		KillProps.box(gl, Vector3(0.058, 0.0045, 0.006), fc, Vector3(cx, -0.0185, 0.0))   # abajo
		KillProps.box(gl, Vector3(0.0055, 0.04, 0.006), fc, Vector3(cx + 0.0285 * sd, -0.0005, 0.0))  # lado de fuera
		KillProps.box(gl, Vector3(0.0045, 0.04, 0.006), fc, Vector3(cx - 0.0275 * sd, -0.0005, 0.0))  # lado de la nariz
		var lens := KillProps.box(gl, Vector3(0.054, 0.034, 0.001), Color(0.75, 1.0, 0.85, 0.10), Vector3(cx, -0.0005, 0.0025), 0.5)
		lens.name = "Vidrio"
		var temple := KillProps.box(gl, Vector3(0.004, 0.007, 0.105), fc, Vector3((EYE.x + 0.034) * sd, 0.012, -0.052))  # patillas
		temple.rotation.y = -0.1 * sd
	KillProps.box(gl, Vector3(0.012, 0.006, 0.006), fc, Vector3(0, 0.012, 0.0))  # puente
	# --- Ceño de furia: cejas oscuras inclinadas hacia la nariz (asoman sobre el marco) y arrugas del entrecejo.
	var brows := Node3D.new()
	brows.name = "Cejas"
	brows.position = Vector3(0, EYE.y + 0.027, EYE.z - 0.006)
	face.add_child(brows)
	var brow_m := KillProps.mat(Color(0.03, 0.14, 0.06), 0.0, false, 0.7)
	for sd in [-1.0, 1.0]:
		var b := _mesh(brows, BoxMesh.new(), brow_m, Vector3(0.03 * sd, 0.002, 0))
		(b.mesh as BoxMesh).size = Vector3(0.042, 0.008, 0.01)
		b.rotation.z = 0.33 * sd
		b.rotation.y = -0.3 * sd
	for sd in [-1.0, 1.0]:
		var f := _mesh(brows, BoxMesh.new(), brow_m, Vector3(0.004 * sd, 0.002, 0.004))
		(f.mesh as BoxMesh).size = Vector3(0.0018, 0.02, 0.003)
		f.rotation.z = -0.12 * sd
	for k in 3:  # arrugas de la frente (siguen la curva de la frente)
		var w := _mesh(brows, BoxMesh.new(), brow_m, Vector3(0, 0.026 + 0.011 * k, -0.0075 - 0.0052 * k * (1.0 + 0.3 * k)))
		(w.mesh as BoxMesh).size = Vector3(0.046 - 0.008 * k, 0.0012, 0.002)
		w.rotation.x = -0.35 - 0.12 * k
	# --- Sonrisa: malla curva sobre la cara con la boca dibujada.
	if _grin_shader == null:
		_grin_shader = Shader.new()
		_grin_shader.code = GRIN_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = _grin_shader
	gm.set_shader_parameter("green", GREEN)
	_mesh(face, _grin_mesh(agent), gm, Vector3.ZERO, "Sonrisa")
	# --- Antena corta con su bola verde (como el concepto), en un zócalo de metal.
	var ant := Node3D.new()
	ant.name = "Antena"
	ant.position = CROWN
	face.add_child(ant)
	_mesh(ant, _cyl(0.007, 0.0105, 0.01), metal, Vector3(0, 0.003, 0))
	_mesh(ant, _cyl(0.0026, 0.0036, 0.05), KillProps.mat(GREEN.darkened(0.25), 0.1, false, 0.35), Vector3(0, 0.03, 0))
	var ball_m := KillProps.mat(GREEN.lightened(0.05), 0.3, false, 0.25)
	_mesh(ant, _sphere(0.0145), ball_m, Vector3(0, 0.064, 0))
	if KillGore.enabled():  # piel rasgada alrededor del zócalo (Reducido: no)
		for k in 7:
			var a := k * TAU / 7.0
			var sc := KillProps.box(ant, Vector3(0.006, 0.002, 0.01), Color(0.34, 0.02, 0.03), Vector3(cos(a) * 0.014, -0.001, sin(a) * 0.014))
			sc.rotation.y = -a + PI * 0.5
	(root.get_meta("driver") as Driver).antenna = ant
	# --- Lo de máquina que le quedó: las perillas verdes de Vitzo en las orejas (concepto) y cables en la nuca.
	var plate := Node3D.new()
	plate.name = "PlacaVitzo"
	face.add_child(plate)
	for sd in [-1.0, 1.0]:
		var knob := _mesh(plate, _sphere(0.021), KillProps.mat(GREEN.darkened(0.12), 0.12, false, 0.3), Vector3(0.094 * sd, 0.03, -0.004))
		knob.scale = Vector3(0.8, 1.0, 1.0)
		var stem := _mesh(plate, _cyl(0.008, 0.008, 0.02), metal, Vector3(0.079 * sd, 0.03, -0.004))
		stem.rotation.z = PI * 0.5
	var cab := Node3D.new()
	cab.name = "CablesNuca"
	face.add_child(cab)
	for k in 3:
		var x0 := -0.03 + 0.03 * k
		var a0 := Vector3(x0, 0.03 - 0.01 * absf(k - 1.0), -0.088)
		var a1 := Vector3(x0 * 1.4, -0.05, -0.105)
		var a2 := Vector3(x0 * 1.1, -0.13, -0.085)
		var prev := a0
		for sgm in range(1, 7):
			var u := sgm / 6.0
			var p := a0.lerp(a1, u).lerp(a1.lerp(a2, u), u)
			var seg := _mesh(cab, _cyl(0.0032, 0.0032, prev.distance_to(p) + 0.002), KillProps.mat(Color(0.03, 0.05, 0.04) if k != 1 else Color(0.1, 0.4, 0.18), 0.0, false, 0.4), (prev + p) * 0.5)
			var yv := (p - prev).normalized()  # el cilindro va a lo largo de su eje Y
			var zv := Vector3(1, 0, 0).cross(yv).normalized()
			seg.transform = Transform3D(Basis(yv.cross(zv), yv, zv), (prev + p) * 0.5)
			prev = p
	# --- Camisa blanca, corbata y solapas sobre el pecho.
	var si := _bone(sk, ["spine_03", "spine_02", "spine_01"])
	if si >= 0:
		var chest := _frame(sk, si, hi, "PechoFusion")
		if _shirt_shader == null:
			_shirt_shader = Shader.new()
			_shirt_shader.code = SHIRT_SHADER
		var shm := ShaderMaterial.new()
		shm.shader = _shirt_shader
		_mesh(chest, _shirt_mesh(agent), shm, Vector3.ZERO, "Camisa")


## Escena 1: la antena sale rasgando el cráneo (crece de golpe, salpica sangre y piel; Reducido: solo crece).
static func antenna_tear(fx: Screamers, root: Node3D, t: float) -> void:
	var ant := root.find_child("Antena", true, false) as Node3D
	if ant == null:
		return
	ant.scale = Vector3(1, 0.02, 1)
	var tw := ant.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ant, "scale", Vector3.ONE, maxf(t, 0.03))
	KillGore.bone(fx, 1.0)
	KillGore.wet(fx, 1.0)
	if KillGore.enabled():
		KillProps.debris(fx, 10, Vector3(0.008, 0.008, 0.008), [Color(0.36, 0.0, 0.02), Color(0.3, 0.6, 0.32)], ant.global_position,
			func(_k: int) -> Vector3: return Vector3(randf_range(-0.6, 0.6), randf_range(0.8, 1.8), randf_range(-0.6, 0.6)), 4.0)
	(fx.last_info["props"] as Array).append("antena")


## Cámara del screamer (tercera persona): reemplaza a la del jugador hasta el final (Screamers._cleanup la devuelve).
static func camera(fx: Screamers, pos: Vector3, look: Vector3) -> Camera3D:
	var c := Camera3D.new()
	c.name = "CamaraFusion"
	c.fov = 55.0
	fx._stage.add_child(c)
	c.global_position = pos
	c.look_at(look, Vector3.UP)
	c.make_current()
	fx.set_meta("cam_override", c)
	return c


## Luz de una toma de tercera persona (Shot.light): blanca apenas verdosa, sin sombras; no la toca el ánimo del piso.
static func shot_light(fx: Screamers) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "LuzToma"
	l.light_color = Color(0.93, 1.0, 0.9)
	l.light_energy = 1.0
	l.omni_range = 5.0
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.set_meta("no_mood", true)
	fx._stage.add_child(l)
	return l


## Centro de la sala de operaciones (marcador evento_rasec del piso 2: la zona de huddle entre las filas de PC);
## en otro piso, donde estás.
static func ops_center(fx: Screamers) -> Vector3:
	var fl := FloorBase.active
	if fl != null:
		var mk := fl.find_child("evento_rasec", true, false) as Node3D
		if mk != null:
			return mk.global_position
	var e := fx._eye()
	return Vector3(e.x, fx._floor_y(), e.z)


## Órbita lenta en tercera persona alrededor del agente fusionado (a la altura del pecho, mirando la cara).
static func orbit(fx: Screamers, root: Node3D, cam: Camera3D, t: float) -> Tween:
	var center := root.global_position
	# El agente mira hacia el pasillo más largo desde el centro (un rumbo fijo: +X), como quien recita a la sala.
	var front := Vector3(1, 0, 0)
	root.look_at(center + front, Vector3.UP)  # look_at apunta -Z (el frente del modelo) hacia `front`
	var head := head_point(root)
	var tw := cam.create_tween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(cam) or not is_instance_valid(root):
			return
		var e := u * u * (3.0 - 2.0 * u)
		var a := deg_to_rad(lerpf(-42.0, 6.0, e))  # de tres cuartos a casi de frente
		var rr := lerpf(2.1, 0.72, e)  # se acerca despacio hasta la cara
		var dir := front.rotated(Vector3.UP, a)
		cam.global_position = Vector3(center.x, head.y, center.z) + dir * rr + Vector3(0, lerpf(0.05, -0.03, e), 0)
		cam.look_at(head - Vector3(0, lerpf(0.26, 0.035, e), 0), Vector3.UP), 0.0, 1.0, maxf(t, 0.1))
	return tw


## El reminder («Reminder: no envíen correos a Vitzo», Joan) con la voz del agente rota en la de Vitzo, en bucle:
## tres tomas cada vez más rotas (voces/agentes/fusion_reminder_<agente>_01..03), una detrás de otra.
static func repeat_line(fx: Screamers, agent: String) -> void:
	var me: WeakRef = weakref(fx)
	var at := 0.0
	for rep in range(1, 4):
		var slot := "voces/agentes/fusion_reminder_%s_%02d" % [agent.to_lower(), rep]
		var path := AudioManager.voice_path(slot)
		if path == "":
			continue
		if rep == 1:
			fx.last_info["fusion_voz"] = path
		var st := load(path) as AudioStream
		fx.get_tree().create_timer(at, true).timeout.connect(func() -> void:
			var f: Screamers = me.get_ref()
			if f != null and not f._done:
				f._snd(slot, 2.0 + rep)
				f.last_info["fusion_reps"] = rep)
		at += (st.get_length() if st != null else 2.5) + 0.12
	fx._snd("sfx/kill_teclas", -8.0, 0.9)  # los demás siguen tipeando
	fx._snd("ambiente/teclado_fantasma_loop", -6.0)

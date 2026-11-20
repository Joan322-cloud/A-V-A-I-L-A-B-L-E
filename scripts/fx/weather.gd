class_name Weather
extends Node3D
## Lluvia y exterior (v0.3 P2, PLAN §2 #52): más visible pero tenebroso.
## Rendimiento (web/Compatibility y calidad Baja): NADA de GPUParticles. La lluvia es UNA MultiMesh de
## gotas (dos quads cruzados por gota) animada en el vertex shader con TIME: cero trabajo de CPU por
## frame y una sola llamada de dibujo. Cantidad por calidad: Baja 450 · Media 1100 · Alta 1800.
## Charcos: quads con poca rugosidad (brillo de los faroles) y ondas en el shader. Vidrio con lluvia:
## shader de surcos sobre un quad. Relámpago: una OmniLight lejana que se enciende 2 veces 80 ms
## (con "reducir destellos": solo un resplandor suave). Sonido: ambiente/lluvia si existe; si no, ruido
## filtrado generado aquí (2 s en bucle).
##
## API:
##   Weather.rain(parent, center, size, height)          → Weather (lluvia en una caja)
##   Weather.puddle(parent, pos, size)                   → charco
##   Weather.rain_glass(parent, name, pos, size, rot_y)  → vidrio con surcos de lluvia
##   Weather.lightning(parent, pos)                      → relámpagos ocasionales
##   Weather.skyline(parent, seed, x0, x1, z0, z1, y_base, count, h_min, h_max) → silueta de ciudad (2 MultiMesh)
##   Weather.noise_stream(seconds, lowpass, gain)        → AudioStreamWAV de ruido (lluvia, susurro, trueno)

var area_size: Vector3 = Vector3(30, 8, 20)
var drops: int = 1100
var _mmi: MultiMeshInstance3D = null
var _sound: AudioStreamPlayer = null

static var _rain_shader: Shader = null
static var _thunder_noise: AudioStreamWAV = null
static var _glass_mat: ShaderMaterial = null
static var _puddle_mat: ShaderMaterial = null
static var _rain_noise: AudioStreamWAV = null


static func drop_count() -> int:
	match GfxQuality.level():
		"liviano": return 120  # v0.3.1 Q5: Modo liviano, ¼ de las gotas de Baja
		"baja": return 450
		"alta": return 1800
	return 1100


## v0.3.1 Q5: al cambiar la calidad en caliente (GfxQuality.apply) la lluvia que ya existe dibuja menos gotas.
func apply_quality() -> void:
	if _mmi != null and _mmi.multimesh != null:
		_mmi.multimesh.visible_instance_count = mini(drops, Weather.drop_count())


static func rain(parent: Node, center: Vector3, size: Vector3, volume_db: float = -13.0) -> Weather:
	var w := Weather.new()
	w.name = "Lluvia"
	w.position = center
	w.area_size = size
	w.drops = drop_count()
	parent.add_child(w)
	w._build(volume_db)
	return w


func _build(volume_db: float) -> void:
	var quad := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	# Dos quads cruzados de 1,5 cm × 45 cm (gota alargada por el movimiento).
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var hw := 0.008
	var hh := 0.24
	for axis in 2:
		var dx := Vector3(hw, 0, 0) if axis == 0 else Vector3(0, 0, hw)
		v.append_array([-dx + Vector3(0, -hh, 0), dx + Vector3(0, -hh, 0), dx + Vector3(0, hh, 0), -dx + Vector3(0, -hh, 0), dx + Vector3(0, hh, 0), -dx + Vector3(0, hh, 0)])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = drops
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in drops:
		var p := Vector3(rng.randf_range(-0.5, 0.5) * area_size.x, 0.0, rng.randf_range(-0.5, 0.5) * area_size.z)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.8, 1.25), rng.randf(), 0))
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Gotas"
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.material_override = Weather.rain_material(area_size.y)
	_mmi.custom_aabb = AABB(Vector3(-area_size.x * 0.5, 0, -area_size.z * 0.5), area_size)
	add_child(_mmi)
	_sound = AudioStreamPlayer.new()
	_sound.name = "SonidoLluvia"
	_sound.bus = "Ambiente"
	_sound.volume_db = volume_db
	var path := AudioManager.resolve("ambiente/lluvia")
	var stream: AudioStream = load(path) as AudioStream if path != "" else null
	if stream == null:
		if _rain_noise == null:
			_rain_noise = Weather.noise_stream(2.0, 0.35, 0.5)
		stream = _rain_noise
	_sound.stream = stream
	add_child(_sound)
	if not OS.get_cmdline_user_args().has("--escenario"):
		_sound.play()


static func rain_material(height: float) -> ShaderMaterial:
	if _rain_shader == null:
		_rain_shader = Shader.new()
		_rain_shader.code = RAIN_SHADER
	var m := ShaderMaterial.new()
	m.shader = _rain_shader
	m.set_shader_parameter("height", height)
	return m


const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float height = 8.0;
uniform float speed = 9.5;
uniform vec4 tint : source_color = vec4(0.55, 0.62, 0.7, 0.33);
varying float v_fade;
void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float spd = speed * INSTANCE_CUSTOM.g;
	float y = height * (1.0 - fract(phase + TIME * spd / height));
	VERTEX.y += y;
	VERTEX.x += (y - height) * 0.05;   // viento: cae un poco inclinada
	v_fade = smoothstep(0.0, 0.6, y) * smoothstep(height, height - 1.0, y);
}
void fragment() {
	float core = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = tint.rgb;
	ALPHA = tint.a * core * v_fade * (0.35 + 0.65 * UV.y);
}
"""


## Vidrio con lluvia: surcos que bajan, gotas y un poco de reflejo. Transparente.
static func glass_material() -> ShaderMaterial:
	if _glass_mat != null:
		return _glass_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
uniform vec4 base : source_color = vec4(0.18, 0.24, 0.28, 0.32);
float h(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
void fragment() {
	vec2 uv = UV * vec2(14.0, 4.0);
	float col = floor(uv.x);
	float rnd = h(vec2(col, 3.1));
	float t = TIME * (0.25 + rnd * 0.5) + rnd * 10.0;
	float y = fract(uv.y * 0.5 + t);
	float stream = smoothstep(0.48, 0.5, fract(uv.x)) * smoothstep(0.52, 0.5, fract(uv.x));
	float drip = smoothstep(0.0, 0.08, y) * smoothstep(0.35, 0.0, y) * step(0.55, rnd);
	vec2 cell = floor(UV * vec2(60.0, 22.0));
	float dot_ = step(0.93, h(cell + floor(TIME * 0.2)));
	float wet = clamp(stream * drip * 1.4 + dot_ * 0.5, 0.0, 1.0);
	ALBEDO = base.rgb + wet * vec3(0.25, 0.3, 0.33);
	ROUGHNESS = mix(0.08, 0.02, wet);
	METALLIC = 0.2;
	SPECULAR = 0.8;
	ALPHA = clamp(base.a + wet * 0.35, 0.0, 0.9);
}
"""
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = sh
	return _glass_mat


static func rain_glass(parent: Node, p_name: String, pos: Vector3, size: Vector2, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = p_name
	mi.mesh = q
	mi.material_override = Weather.glass_material()
	mi.position = pos
	mi.rotation_degrees.y = rot_y_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func puddle_material() -> ShaderMaterial:
	if _puddle_mat != null:
		return _puddle_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * 6.0;
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float t = fract(TIME * 0.9 + h(cell));
	float ring = smoothstep(0.05, 0.0, abs(length(f) - t * 0.5)) * (1.0 - t);
	float edge = smoothstep(0.5, 0.36, length(UV - 0.5));
	ALBEDO = vec3(0.02, 0.025, 0.03) + ring * 0.08;
	ROUGHNESS = 0.04 + ring * 0.2;
	METALLIC = 0.55;
	SPECULAR = 0.9;
	ALPHA = 0.88 * edge;
}
"""
	_puddle_mat = ShaderMaterial.new()
	_puddle_mat.shader = sh
	return _puddle_mat


static var _puddle_flat: StandardMaterial3D = null


## v0.3.1 Q5: en Modo liviano el charco es un material estándar sin ondas animadas (sin shader por píxel).
static func puddle_flat_material() -> StandardMaterial3D:
	if _puddle_flat == null:
		_puddle_flat = StandardMaterial3D.new()
		_puddle_flat.albedo_color = Color(0.03, 0.035, 0.04, 0.85)
		_puddle_flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puddle_flat.roughness = 0.06
		_puddle_flat.metallic = 0.4
	return _puddle_flat


static func puddle(parent: Node, pos: Vector3, size: Vector2) -> MeshInstance3D:
	var q := PlaneMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Charco"
	mi.mesh = q
	mi.material_override = Weather.puddle_flat_material() if GfxQuality.is_light() else Weather.puddle_material()
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Relámpagos lejanos: cada 35-90 s, dos destellos de 80 ms (suave con "reducir destellos") y un trueno.
static func lightning(parent: Node, pos: Vector3, energy: float = 5.0, range_m: float = 60.0) -> Node:
	var n := _Lightning.new()
	n.name = "Relampago"
	parent.add_child(n)
	n.setup(pos, energy, range_m)
	return n


class _Lightning extends Node:
	var light: OmniLight3D = null
	var energy: float = 5.0
	var _t: float = 12.0
	var _thunder: AudioStreamPlayer = null

	func setup(pos: Vector3, p_energy: float, range_m: float) -> void:
		energy = p_energy
		light = OmniLight3D.new()
		light.position = pos
		light.light_color = Color(0.7, 0.78, 0.95)
		light.light_energy = 0.0
		light.visible = false  # apagada fuera del destello: en Compatibility cada luz visible cuesta una pasada
		light.omni_range = range_m
		light.omni_attenuation = 0.6
		light.set_meta("no_mood", true)
		light.shadow_enabled = false
		get_parent().add_child.call_deferred(light)
		_thunder = AudioStreamPlayer.new()
		_thunder.bus = "Ambiente"
		_thunder.volume_db = -8.0
		if Weather._thunder_noise == null:
			Weather._thunder_noise = Weather.noise_stream(2.6, 0.06, 1.0, true)
		_thunder.stream = Weather._thunder_noise
		add_child(_thunder)
		_t = randf_range(8.0, 25.0)

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = randf_range(35.0, 90.0)
		_strike()

	func strike_now() -> void:
		_strike()

	func _strike() -> void:
		if light == null or not light.is_inside_tree():
			return
		var soft := bool(Loc.get_setting("flash_reduction", false))
		var e := energy * (0.25 if soft else 1.0)
		light.visible = true
		var tw := create_tween()
		if soft:
			tw.tween_property(light, "light_energy", e, 0.4)
			tw.tween_property(light, "light_energy", 0.0, 0.8)
		else:
			tw.tween_property(light, "light_energy", e, 0.03)
			tw.tween_property(light, "light_energy", 0.0, 0.08)
			tw.tween_interval(0.12)
			tw.tween_property(light, "light_energy", e * 0.7, 0.03)
			tw.tween_property(light, "light_energy", 0.0, 0.25)
		tw.tween_callback(func() -> void: light.visible = false)
		if not OS.get_cmdline_user_args().has("--escenario"):
			get_tree().create_timer(randf_range(0.6, 1.8)).timeout.connect(func() -> void:
				if is_instance_valid(_thunder) and _thunder.is_inside_tree():
					# P6: trueno grabado del audio_v2 (lejano o cercano al azar); si no hay, el ruido sintético.
					var st: AudioStream = AudioManager.stream_for("ambiente/trueno_cercano" if randf() < 0.3 else "ambiente/trueno_lejano")
					if st != null:
						_thunder.stream = st
					_thunder.play())


## Silueta de ciudad: cuerpos de edificios oscuros + ventanas encendidas, en DOS MultiMesh (2 llamadas
## de dibujo en total). Edificios inventados: sin letreros ni logos (PLAN R2).
static func skyline(parent: Node, seed_v: int, x0: float, x1: float, z0: float, z1: float, y_base: float, count: int, h_min: float, h_max: float, lit: float = 0.35, along_z: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Skyline"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bodies: Array[Transform3D] = []
	var wins: Array[Transform3D] = []
	var win_cols: Array[Color] = []
	for i in count:
		var h := rng.randf_range(h_min, h_max)
		var w := rng.randf_range(4.0, 9.0)
		var d := rng.randf_range(4.0, 8.0)
		var x := lerpf(x0, x1, (i + rng.randf_range(0.1, 0.9)) / float(count))
		var z := rng.randf_range(z0, z1)
		if along_z:
			# Fila a lo largo de Z (vista desde una ventana que mira a +X): x al azar en [x0, x1].
			z = lerpf(z0, z1, (i + rng.randf_range(0.1, 0.9)) / float(count))
			x = rng.randf_range(x0, x1)
		var c := Vector3(x, y_base + h * 0.5, z)
		bodies.append(Transform3D(Basis.from_scale(Vector3(d if along_z else w, h, w if along_z else d)), c))
		# Ventanas en la cara que mira al edificio (hacia -Z si z > 0, hacia +Z si z < 0; -X si along_z).
		var face_z := z - d * 0.5 - 0.02 if z > 0.0 else z + d * 0.5 + 0.02
		var face_x := x - d * 0.5 - 0.02
		var rows := int(h / 1.4)
		var cols := int(w / 1.2)
		for r in rows:
			for k in cols:
				if rng.randf() < lit * (0.5 if r > rows - 2 else 1.0):
					var off := -w * 0.5 + 0.6 + k * 1.2
					var wy := y_base + 0.9 + r * 1.4
					if along_z:
						wins.append(Transform3D(Basis.from_scale(Vector3(0.02, 0.42, 0.55)), Vector3(face_x, wy, z + off)))
					else:
						wins.append(Transform3D(Basis.from_scale(Vector3(0.55, 0.42, 0.02)), Vector3(x + off, wy, face_z)))
					var roll := rng.randf()
					win_cols.append(Color(0.95, 0.72, 0.38) if roll < 0.55 else (Color(0.55, 0.8, 0.95) if roll < 0.9 else Color(0.75, 0.95, 0.75)))
	var box := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = bodies.size()
	for i in bodies.size():
		mm.set_instance_transform(i, bodies[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Cuerpos"
	mi.multimesh = mm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.035, 0.04, 0.055)
	bm.roughness = 1.0
	mi.material_override = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var wmm := MultiMesh.new()
	wmm.transform_format = MultiMesh.TRANSFORM_3D
	wmm.use_colors = true
	wmm.mesh = box
	wmm.instance_count = wins.size()
	for i in wins.size():
		wmm.set_instance_transform(i, wins[i])
		wmm.set_instance_color(i, win_cols[i])
	var wmi := MultiMeshInstance3D.new()
	wmi.name = "Ventanas"
	wmi.multimesh = wmm
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	wm.albedo_color = Color(1, 1, 1)
	wmi.material_override = wm
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wmi)
	return root


## Ruido filtrado mono 22 kHz (lluvia: lowpass ~0,35; trueno: 0,06 con envolvente). Se genera una vez.
static func noise_stream(seconds: float, lowpass: float, gain: float, envelope: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lowpass * 1000.0) + n
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		y += lowpass * (x - y)
		y2 += lowpass * (y - y2)
		var s := y2 * gain * 3.0
		if envelope:
			var t := float(i) / float(n)
			s *= minf(t * 12.0, 1.0) * pow(1.0 - t, 1.6) * (0.6 + 0.4 * sin(t * 37.0))
		else:
			# Bucle sin clic: fundido corto en los extremos.
			var edge := minf(float(i), float(n - i)) / (rate * 0.05)
			s *= clampf(edge, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if not envelope:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w

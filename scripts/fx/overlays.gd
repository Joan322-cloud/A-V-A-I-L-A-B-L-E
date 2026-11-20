extends Control
## Overlays de pantalla: microsueño y frotarse los ojos (párpados con curvas suaves, v0.3.2),
## desenfoque por Fatiga (oscurecimiento progresivo), reflejo del espejo (texto), aviso de screamer.

var _black: ColorRect = null
var _blur: ColorRect = null
var _cheap: ColorRect = null  # rc1: Modo liviano, viñeta/párpados sin leer la pantalla (sin copia del backbuffer)
var _mirror: Label = null
var _hint: PanelContainer = null  # v0.3.1 (B7): aviso de Fatigue.blur_hint_text, nítido (encima del desenfoque)
var _hint_lbl: Label = null
var _black_left: float = 0.0
var _film_t: float = 0.0
var _grade_tint: Color = Color(1, 1, 1)
var _beat_t: float = 0.0
var _eyes: float = 0.0
## v0.3.2 (Joan: «la animación de parpadeo debe ser más fluida y un poco más rápida»): antes era un ColorRect negro
## de golpe durante 1 s (aparecía y desaparecía en un cuadro). Ahora dos párpados con borde curvo y difuso que
## bajan (ease-in-out), quedan cerrados un instante y suben (más despacio, ease-out). lid = 0 abierto … 1 cerrado.
var _lids: ColorRect = null
var lid: float = 0.0
var _lid_t: float = -1.0
var _lid_close: float = 0.13
var _lid_hold: float = 0.09
var _lid_open: float = 0.28
var lid_samples: Array[float] = []  # pruebas: valores del último parpadeo, cuadro a cuadro


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Grano de película + desenfoque por Fatiga en un shader de pantalla (respeta "sin parpadeos").
	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.color = Color(1, 1, 1, 1)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.material = _make_film_material()
	add_child(_blur)
	_cheap = ColorRect.new()
	_cheap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cheap.color = Color(0, 0, 0, 1)
	_cheap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cheap.material = _make_cheap_material()
	_cheap.visible = false
	add_child(_cheap)
	_make_hint()
	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 1)
	_black.visible = false
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_lids = ColorRect.new()
	_lids.name = "Parpados"
	_lids.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lids.color = Color(0, 0, 0, 1)
	_lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lids.material = _make_lid_material()
	_lids.visible = false
	add_child(_lids)
	_mirror = Label.new()
	_mirror.set_anchors_preset(Control.PRESET_CENTER)
	_mirror.position = Vector2(560, 480)
	_mirror.add_theme_font_size_override("font_size", 22)
	_mirror.modulate = Color(0.8, 0.85, 0.85, 0.9)
	_mirror.visible = false
	add_child(_mirror)
	EventBus.microsleep.connect(_on_microsleep)
	EventBus.player_blinked.connect(_on_blink)
	EventBus.distortion_triggered.connect(_on_distortion)
	EventBus.screen_black.connect(func(sec: float) -> void: _black_left = maxf(_black_left, sec))


## v0.3.1 (B7): el aviso de frotarse los ojos va después del rectángulo del desenfoque: el shader lee la pantalla
## que hay DETRÁS, así que este panel se dibuja nítido (todo lo demás sigue borroso hasta pulsar R).
func _make_hint() -> void:
	_hint = PanelContainer.new()
	_hint.name = "AvisoOjos"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.88)
	sb.border_color = UITheme.YELLOW.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	_hint.add_theme_stylebox_override("panel", sb)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_top = -300
	_hint.offset_bottom = -236
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)
	_hint_lbl = UITheme.label("", 20, UITheme.TEXT)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.custom_minimum_size = Vector2(690, 0)
	_hint.add_child(_hint_lbl)


## v0.3.2 gfx: en Media/Alta el pase de película usa otro material con los mismos uniformes (scripts/gfx/gfx_lens.gd:
## grano fino; el etalonaje del piso pasa al lente, bajo la interfaz). null devuelve el de siempre (Baja).
var _film_default: ShaderMaterial = null


func set_film_material(m: ShaderMaterial) -> void:
	if _blur == null:
		return
	if _film_default == null:
		_film_default = _blur.material as ShaderMaterial
	_blur.material = m if m != null else _film_default


func hint_visible() -> bool:
	return _hint != null and _hint.visible


func _process(delta: float) -> void:
	var hv := Fatigue.blur_hint_left > 0.0 and Fatigue.blur_hint_text != "" and GameState.running
	if hv and _hint_lbl.text != Fatigue.blur_hint_text:
		_hint_lbl.text = Fatigue.blur_hint_text
	_hint.visible = hv
	_hint.modulate.a = clampf(Fatigue.blur_hint_left / 0.6, 0.0, 1.0)
	if _black_left > 0.0:
		_black_left -= delta
		_black.visible = true
	else:
		_black.visible = false
	_tick_lids(delta)
	# Grano y desenfoque (shader): el grano es fijo con "sin parpadeos"; el blur sigue a la Fatiga.
	# rc1 (fps del HTML en SwiftShader): en Modo liviano el pase de película lee la pantalla entera cada cuadro (copia del
	# backbuffer a 1280×720 aunque el 3D vaya a 0,33): se cambia por una capa negra con alfa (viñeta, Dread, párpados).
	var light := GfxQuality.is_light()
	_blur.visible = not light
	_cheap.visible = light
	var fm := _blur.material as ShaderMaterial
	if light:
		var cm := _cheap.material as ShaderMaterial
		var d0 := Dread.level()
		var sleeping0 := SleepSpot.is_player_sleeping()
		_eyes = lerpf(_eyes, 1.0 if sleeping0 else 0.0, minf(delta * (1.5 if sleeping0 else 4.0), 1.0))
		cm.set_shader_parameter("dread", d0)
		cm.set_shader_parameter("darken", Fatigue.blur_amount() * 0.25)
		cm.set_shader_parameter("eyes", _eyes)
		fm = null
	if fm != null:
		var soft := bool(Loc.get_setting("flash_reduction", false))
		if not soft:
			_film_t += delta
		var grain := 0.0
		if bool(Loc.get_setting("grain", true)):
			grain = 0.035 + 0.012 * Fatigue.level()
			if soft:
				grain *= 0.6
		fm.set_shader_parameter("t", _film_t)
		fm.set_shader_parameter("grain", grain)
		# Calidad Baja: sin los 8 taps de desenfoque (el oscurecimiento por Fatiga se mantiene).
		fm.set_shader_parameter("blur", 0.0 if GfxQuality.is_low() else Fatigue.blur_amount())
		fm.set_shader_parameter("darken", Fatigue.blur_amount() * 0.25)
		# v0.3 P2: etalonaje del piso (fluorescente enfermizo dentro, azul frío fuera) + presión (Dread):
		# viñeta que se cierra, menos color y, con presión muy alta, un latido que oscurece el borde.
		var g: Dictionary = FloorBase.active.grading() if FloorBase.active != null and is_instance_valid(FloorBase.active) else {}
		var d := Dread.level()
		_grade_tint = _grade_tint.lerp(g.get("tint", Color(1, 1, 1)), minf(delta * 2.0, 1.0))
		fm.set_shader_parameter("tint", Vector3(_grade_tint.r, _grade_tint.g, _grade_tint.b))
		fm.set_shader_parameter("sat", float(g.get("sat", 0.85)) * (1.0 - 0.3 * d))
		fm.set_shader_parameter("contrast", float(g.get("contrast", 1.0)) + 0.08 * d)
		fm.set_shader_parameter("dread", d)
		_beat_t += delta * (1.1 + 0.9 * d)
		var beat := pow(maxf(sin(_beat_t * TAU), 0.0), 8.0) if d > 0.6 and not soft else 0.0
		fm.set_shader_parameter("beat", beat * (d - 0.6) * 2.0)
		var sleeping := SleepSpot.is_player_sleeping()
		_eyes = lerpf(_eyes, 1.0 if sleeping else 0.0, minf(delta * (1.5 if sleeping else 4.0), 1.0))
		fm.set_shader_parameter("eyes", _eyes * (0.9 + 0.06 * sin(_film_t * 1.3)))
	_mirror.visible = false  # la distorsión 5 usa SecurityCamView (cámara real)


func _make_cheap_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float dread = 0.0;
uniform float darken = 0.0;
uniform float eyes = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 1.35;
	float vig = (0.22 + 0.38 * dread) * pow(r, 2.0 - 0.6 * dread);
	float keep = clamp(1.0 - vig, 0.0, 1.0) * (1.0 - darken) * (1.0 - 0.82 * smoothstep(0.0, 1.0, eyes));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - keep);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _make_film_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float grain = 0.04;
uniform float darken = 0.0;
uniform float t = 0.0;
uniform vec3 tint = vec3(1.0);
uniform float sat = 1.0;
uniform float contrast = 1.0;
uniform float dread = 0.0;
uniform float beat = 0.0;
uniform float eyes = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	if (blur > 0.001) {
		float r = blur * 0.0045;  // v0.3.1 (B7): con el tope 0,6 son ~5 px a 1080p: molesta, pero se lee
		vec3 acc = col * 0.2;
		acc += texture(screen_tex, uv + vec2(r, 0.0)).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, 0.0)).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(0.0, r)).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(0.0, r)).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(r, r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv + vec2(r, -r) * 0.7).rgb * 0.1;
		acc += texture(screen_tex, uv - vec2(r, -r) * 0.7).rgb * 0.1;
		col = acc;
	}
	float n = (hash(floor(uv * vec2(960.0, 540.0)) + vec2(fract(t * 7.31) * 13.0, fract(t * 3.17) * 29.0)) - 0.5) * grain;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, sat);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint;
	float r = length(uv - 0.5) * 1.35;
	float vig = 1.0 - (0.22 + 0.38 * dread) * pow(r, 2.0 - 0.6 * dread) - beat * 0.35 * r;
	float lid = smoothstep(0.0, 1.0, eyes);
	col = (col + n) * clamp(vig, 0.0, 1.0) * (1.0 - darken) * (1.0 - 0.82 * lid);
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _on_microsleep() -> void:
	var hold := 0.2 if bool(Loc.get_setting("flash_reduction", false)) else float(DataLoader.bal("fatiga/microsueno_negro_s", 0.5))
	blink(float(DataLoader.bal("jugador/parpadeo_cerrar_s", 0.13)), hold, float(DataLoader.bal("jugador/microsueno_abrir_s", 0.4)))


func _on_blink() -> void:
	blink(float(DataLoader.bal("jugador/parpadeo_cerrar_s", 0.13)), float(DataLoader.bal("jugador/parpadeo_cerrado_s", 0.09)), float(DataLoader.bal("jugador/parpadeo_abrir_s", 0.28)))


## Un parpadeo: cierra en `close_s`, queda cerrado `hold_s` y abre en `open_s` (curvas suaves, sin saltos).
func blink(close_s: float, hold_s: float, open_s: float) -> void:
	_lid_close = maxf(close_s, 0.02)
	_lid_hold = maxf(hold_s, 0.0)
	_lid_open = maxf(open_s, 0.02)
	# Si ya estaba a medio cerrar, sigue desde ahí (sin volver a abrir de golpe).
	_lid_t = _lid_close * clampf(lid, 0.0, 1.0) if lid > 0.0 and _lid_t >= 0.0 else 0.0
	lid_samples.clear()


static func lid_curve(t: float, c: float, h: float, o: float) -> float:
	if t < 0.0:
		return 0.0
	if t < c:
		return 0.5 - 0.5 * cos(PI * t / c)  # ease-in-out (seno)
	if t < c + h:
		return 1.0
	if t < c + h + o:
		var x := (t - c - h) / o
		return pow(1.0 - x, 2.0) * (1.0 + 2.0 * x)  # 1 − smoothstep: arranca y termina sin escalón
	return 0.0


func blink_total() -> float:
	return _lid_close + _lid_hold + _lid_open


func _tick_lids(delta: float) -> void:
	if _lid_t < 0.0:
		lid = 0.0
		_lids.visible = false
		return
	_lid_t += delta
	lid = lid_curve(_lid_t, _lid_close, _lid_hold, _lid_open)
	lid_samples.append(lid)
	if _lid_t >= blink_total():
		_lid_t = -1.0
		lid = 0.0
	_lids.visible = lid > 0.0005
	(_lids.material as ShaderMaterial).set_shader_parameter("lid", lid)


func _make_lid_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float lid = 0.0;
void fragment() {
	float x = UV.x - 0.5;
	float open = 1.0 - lid;
	// Borde del párpado curvo (más bajo al centro), difuso; con lid = 1 se tocan en el medio.
	float bow = 0.09 * open * (1.0 - 4.0 * x * x);
	float edge = lid * 0.56 + bow;
	float soft = 0.025 + 0.09 * open;
	float top = 1.0 - smoothstep(edge - soft, edge, UV.y);
	float bot = 1.0 - smoothstep(edge - soft, edge, 1.0 - UV.y);
	float a = max(top, bot);
	a = max(a, lid * lid * 0.35);  // la luz que se cuela por los párpados también baja
	COLOR = vec4(0.012, 0.006, 0.006, clamp(a, 0.0, 1.0));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _on_distortion(id: String) -> void:
	if id == "el_espejo":
		# En el reflejo estás sentado en tu PC desde el ángulo de la cámara de seguridad.
		_mirror.text = "[ CAM 02 · FILA C · %s ]" % GameState.clock_text()

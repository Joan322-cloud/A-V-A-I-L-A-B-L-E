class_name IntroArranque
extends Control
## v0.3.1 Q4 (F24, D8): intro de arranque, ~10,5 s de terror antes del menú principal.
##   0,0-3,6 s  lluvia y estática sobre la torre KONZENTRAMANCE de noche (ventanas que parpadean, una silueta en
##              una ventana del piso 2), trueno y relámpago.
##   3,6-6,8 s  corte a negro: un monitor viejo se enciende solo (línea blanca que se abre) y escribe
##              «Usuario desconectado.» con interferencia.
##   6,8-10,5 s el título A V A I L A B L E aparece y se RASGA (cortes horizontales, separación RGB, el punto rojo),
##              golpe grave y fundido al menú.
## La primera vez se ve entera (`skippable = false`); después cualquier tecla o clic la salta (MainMenu guarda
## "intro_vista" en settings.json). «Reducir destellos» quita el relámpago y baja el glitch.
## Pruebas/capturas: `seek(t)` salta a un instante; `t` es el tiempo actual; `finished` al terminar o saltar.

signal finished()

const DURATION := 10.5
const T_MONITOR := 3.6
const T_TITLE := 6.8

var skippable: bool = false
var t: float = 0.0
var paused_at: float = -1.0  # capturas: congela en ese instante
var _done: bool = false
var _soft: bool = false
var _tower: _Tower = null
var _rain: ColorRect = null
var _static: ColorRect = null
var _flash: ColorRect = null
var _monitor: Control = null
var _screen: ColorRect = null
var _mon_text: Label = null
var _mon_sub: Label = null
var _title_vp: SubViewport = null
var _title_rect: TextureRect = null
var _skip_lbl: Label = null
var _fade: ColorRect = null
var _sounds: Dictionary = {}
var _played: Dictionary = {}
var _rain_player: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_soft = bool(Loc.get_setting("flash_reduction", false))
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_tower = _Tower.new()
	_tower.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tower)
	_rain = _shader_rect(RAIN_SHADER)
	add_child(_rain)
	_build_monitor()
	_build_title()
	_static = _shader_rect(STATIC_SHADER)
	add_child(_static)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_skip_lbl = UITheme.label(tr("Q4_INTRO_SKIP"), 14, Color(0.6, 0.62, 0.65, 0.0), true)
	_skip_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_lbl.position = Vector2(1920 - 420, 1080 - 56)
	_skip_lbl.size = Vector2(390, 30)
	_skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_skip_lbl)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = "Ambiente"
	_rain_player.stream = AudioManager.stream_for("ambiente/lluvia", true)
	_rain_player.volume_db = -10.0
	add_child(_rain_player)
	if _rain_player.stream != null:
		_rain_player.play()
	_apply(0.0)


const RAIN_SHADER := """
shader_type canvas_item;
uniform float amount = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * vec2(110.0, 7.0);
	uv.x += uv.y * 0.18;
	vec2 cell = floor(uv);
	float r = h(cell);
	float y = fract(uv.y + TIME * (2.2 + r * 1.6) + r * 7.0);
	float streak = smoothstep(0.0, 0.04, y) * (1.0 - smoothstep(0.08, 0.22, y));
	float lane = 1.0 - smoothstep(0.0, 0.06, abs(fract(uv.x) - 0.5));
	float a = streak * lane * step(0.55, r) * 0.38 * amount;
	COLOR = vec4(0.7, 0.78, 0.85, a);
}
"""

const STATIC_SHADER := """
shader_type canvas_item;
uniform float amount = 0.3;
uniform float bars = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 2.0);
	float n = h(px + vec2(floor(TIME * 30.0) * 7.0, 0.0));
	float band = step(0.985, h(vec2(floor(FRAGCOORD.y / 6.0), floor(TIME * 12.0)))) * bars;
	float scan = 0.06 * sin(FRAGCOORD.y * 1.7);
	COLOR = vec4(vec3(n), clamp(amount * (0.35 + 0.65 * n) + band * 0.5 + scan * amount, 0.0, 0.9));
}
"""

const TEAR_SHADER := """
shader_type canvas_item;
uniform float tear = 0.0;
uniform float split = 0.0;
uniform float t = 0.0;
float h(float x) { return fract(sin(x * 91.17) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * 24.0);
	float k = h(row + floor(t * 9.0));
	float shift = (k > 0.72 ? (k - 0.72) * 2.2 : 0.0) * tear;
	shift *= sign(h(row * 3.1 + floor(t * 13.0)) - 0.5);
	uv.x += shift;
	vec4 c = texture(TEXTURE, uv);
	float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	float gap = step(0.93, h(row * 7.7 + floor(t * 17.0))) * tear;
	c.rgb = vec3(r, c.g, b);
	c.a = max(c.a, max(texture(TEXTURE, uv + vec2(split, 0.0)).a, texture(TEXTURE, uv - vec2(split, 0.0)).a) * 0.85);
	c.a *= 1.0 - gap;
	COLOR = c;
}
"""


func _shader_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r


func _build_monitor() -> void:
	_monitor = Control.new()
	_monitor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_monitor)
	var bezel := ColorRect.new()
	bezel.color = Color(0.05, 0.055, 0.06)
	bezel.position = Vector2(560, 250)
	bezel.size = Vector2(800, 560)
	_monitor.add_child(bezel)
	var stand := ColorRect.new()
	stand.color = Color(0.04, 0.045, 0.05)
	stand.position = Vector2(900, 810)
	stand.size = Vector2(120, 90)
	_monitor.add_child(stand)
	_screen = ColorRect.new()
	_screen.color = Color(0.02, 0.03, 0.035)
	_screen.position = Vector2(600, 290)
	_screen.size = Vector2(720, 470)
	_screen.pivot_offset = _screen.size * 0.5
	_monitor.add_child(_screen)
	_mon_text = UITheme.label(tr("Q4_INTRO_DISCONNECTED"), 44, Color(0.92, 0.2, 0.18), true)
	_mon_text.position = Vector2(600, 460)
	_mon_text.size = Vector2(720, 70)
	_mon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monitor.add_child(_mon_text)
	_mon_sub = UITheme.label(tr("Q4_INTRO_REASON"), 18, Color(0.7, 0.72, 0.74), true)
	_mon_sub.position = Vector2(600, 540)
	_mon_sub.size = Vector2(720, 40)
	_mon_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monitor.add_child(_mon_sub)


func _build_title() -> void:
	_title_vp = SubViewport.new()
	_title_vp.size = Vector2i(1500, 220)
	_title_vp.transparent_bg = true
	_title_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_title_vp)
	var hb := HBoxContainer.new()
	hb.position = Vector2(0, 0)
	hb.size = Vector2(1500, 220)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 26)
	_title_vp.add_child(hb)
	var dot_box := CenterContainer.new()
	dot_box.custom_minimum_size = Vector2(40, 220)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(30, 30)
	dot.color = UITheme.RED
	dot_box.add_child(dot)
	hb.add_child(dot_box)
	var l := UITheme.label(tr("GAME_TITLE"), 120, Color(0.9, 0.92, 0.93), true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 220)
	hb.add_child(l)
	_title_rect = TextureRect.new()
	_title_rect.texture = _title_vp.get_texture()
	_title_rect.position = Vector2(210, 430)
	_title_rect.size = Vector2(1500, 220)
	_title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = TEAR_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_title_rect.material = m
	add_child(_title_rect)


func _process(delta: float) -> void:
	if _done:
		return
	if paused_at >= 0.0:
		t = paused_at
	else:
		t += delta
	_apply(t)
	if t >= DURATION and paused_at < 0.0:
		finish()


## Salta a un instante (capturas y pruebas).
func seek(p_t: float, freeze: bool = true) -> void:
	t = p_t
	paused_at = p_t if freeze else -1.0
	_apply(t)


func _apply(tt: float) -> void:
	var in_city := tt < T_MONITOR
	var in_mon := tt >= T_MONITOR and tt < T_TITLE
	var in_title := tt >= T_TITLE
	# fundido de entrada y de salida
	var fade_a := 1.0 - clampf(tt / 0.8, 0.0, 1.0)
	if tt > DURATION - 0.9:
		fade_a = clampf((tt - (DURATION - 0.9)) / 0.9, 0.0, 1.0)
	_fade.color.a = fade_a
	_tower.visible = in_city
	_tower.t = tt
	_tower.queue_redraw()
	_rain.visible = in_city or in_title
	(_rain.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if in_city else 0.35)
	# estática: fuerte en los cortes
	var st := 0.12
	if in_city:
		st = 0.12 + 0.25 * clampf(1.0 - absf(tt - 2.6) * 2.0, 0.0, 1.0)
	elif in_mon:
		st = 0.55 * clampf(1.0 - (tt - T_MONITOR) * 2.0, 0.0, 1.0) + 0.08
	else:
		st = 0.5 * clampf(1.0 - (tt - T_TITLE) * 2.5, 0.0, 1.0) + 0.06
	if _soft:
		st *= 0.5
	(_static.material as ShaderMaterial).set_shader_parameter("amount", st)
	(_static.material as ShaderMaterial).set_shader_parameter("bars", 1.0 if in_mon or in_title else 0.0)
	# relámpago
	var fl := 0.0
	if not _soft and tt > 2.5 and tt < 2.95:
		fl = 0.55 * (1.0 - absf(tt - 2.6) / 0.35) if tt < 2.7 or tt > 2.8 else 0.15
	_flash.color.a = clampf(fl, 0.0, 0.6)
	# monitor
	_monitor.visible = in_mon
	if in_mon:
		var k := tt - T_MONITOR
		var open := clampf((k - 0.25) / 0.35, 0.0, 1.0)
		_screen.scale = Vector2(clampf(k / 0.25, 0.02, 1.0), lerpf(0.006, 1.0, open))
		_screen.color = Color(0.02, 0.03, 0.035).lerp(Color(0.85, 0.9, 0.92), clampf(1.0 - (k - 0.2) * 3.0, 0.0, 1.0) * float(k > 0.05))
		var typed := clampi(int((k - 0.8) * 26.0), 0, tr("Q4_INTRO_DISCONNECTED").length())
		_mon_text.visible_characters = typed
		_mon_text.visible = k > 0.8
		_mon_text.modulate.a = 0.55 + 0.45 * float(fmod(k * 7.3, 1.0) > 0.12)
		_mon_sub.visible = k > 2.0
	# título
	_title_rect.visible = in_title
	if in_title:
		var k2 := tt - T_TITLE
		var tear := clampf(1.0 - k2 * 0.9, 0.0, 1.0) * 0.18 + (0.12 if fmod(k2, 1.3) < 0.12 else 0.0)
		if k2 > 2.6:
			tear = 0.35 * clampf((k2 - 2.6) / 0.6, 0.0, 1.0)  # se rasga al irse
		var m := _title_rect.material as ShaderMaterial
		m.set_shader_parameter("tear", tear * (0.5 if _soft else 1.0))
		m.set_shader_parameter("split", (0.004 + tear * 0.02) * (0.5 if _soft else 1.0))
		m.set_shader_parameter("t", tt)
		_title_rect.modulate.a = clampf(k2 / 0.3, 0.0, 1.0)
	_skip_lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65, 0.8 if skippable and tt > 0.6 else 0.0))
	_sound_cues(tt)


func _sound_cues(tt: float) -> void:
	_cue(tt, 2.55, "ambiente/trueno_cercano_01", "Ambiente", -4.0)
	_cue(tt, T_MONITOR - 0.05, "sfx/estatica_desconexion|sfx/auricular_desconexion", "UI", -6.0)
	_cue(tt, T_MONITOR + 0.1, "sfx/monitor_encender", "UI", -4.0)
	_cue(tt, T_TITLE - 0.05, "sfx/tono_grave_sting", "Sala", 0.0)
	_cue(tt, T_TITLE + 0.05, "sfx/estatica_desconexion|sfx/auricular_desconexion", "UI", -8.0)
	_cue(tt, T_TITLE + 2.65, "sfx/latido_lento", "Sala", -6.0)


func _cue(tt: float, at: float, slots: String, bus: String, db: float) -> void:
	if tt < at or _played.has(at) or paused_at >= 0.0:
		return
	_played[at] = true
	for s in slots.split("|"):
		var st := AudioManager.stream_for(s)
		if st != null:
			var p := AudioStreamPlayer.new()
			p.stream = st
			p.bus = bus
			p.volume_db = db
			add_child(p)
			p.play()
			p.finished.connect(p.queue_free)
			return


func _gui_input(event: InputEvent) -> void:
	_try_skip(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_skip(event)


func _try_skip(event: InputEvent) -> void:
	if not skippable or _done:
		return
	if (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed):
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	if _rain_player != null:
		_rain_player.stop()
	finished.emit()


## La torre de noche: silueta, rejilla de ventanas que parpadean, letrero y una silueta en el piso 2.
class _Tower extends Control:
	var t: float = 0.0

	func _draw() -> void:
		var w := 1920.0
		var h := 1080.0
		# cielo y ciudad
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.025, 0.035))
		for i in 22:
			var bx := float(i) * 92.0 - 30.0
			var bh := 160.0 + float((i * 37) % 90) * 2.1
			draw_rect(Rect2(bx, h - bh, 84, bh), Color(0.035, 0.04, 0.05))
		var drift := t * 6.0  # la cámara sube despacio
		var tx := 700.0
		var tw := 520.0
		var top := 70.0 - drift
		draw_rect(Rect2(tx, top, tw, h - top), Color(0.055, 0.06, 0.07))
		draw_rect(Rect2(tx - 10, top - 14, tw + 20, 16), Color(0.07, 0.075, 0.085))
		var rng := RandomNumberGenerator.new()
		rng.seed = 47
		var rows := 22
		for r in rows:
			for c in 9:
				var x := tx + 24.0 + float(c) * 54.0
				var y := top + 80.0 + float(r) * 44.0
				var lit := rng.randf()
				var phase := rng.randf() * 10.0
				var on := lit > 0.62 and fmod(t * 0.7 + phase, 3.7) > 0.25
				var col := Color(0.09, 0.1, 0.11)
				if on:
					col = Color(0.42, 0.62, 0.58) * (0.55 + 0.45 * lit) if r > 12 else Color(0.75, 0.58, 0.32) * (0.45 + 0.4 * lit)
				draw_rect(Rect2(x, y, 34, 26), col)
		# piso 2 (fila 19): ventana encendida con una silueta que mira
		var wx := tx + 24.0 + 4.0 * 54.0
		var wy := top + 80.0 + 19.0 * 44.0
		draw_rect(Rect2(wx, wy, 34, 26), Color(0.62, 0.78, 0.74))
		var sway := sin(t * 0.8) * 1.0
		draw_rect(Rect2(wx + 12 + sway, wy + 3, 10, 9), Color(0.02, 0.02, 0.025))
		draw_rect(Rect2(wx + 9 + sway, wy + 12, 16, 14), Color(0.02, 0.02, 0.025))
		# letrero (una letra falla)
		var font := ThemeDB.fallback_font
		var sign := "KONZENTRAMANCE"
		var fs := 34
		var sw := font.get_string_size(sign, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sx := tx + (tw - sw) * 0.5
		var flick := fmod(t * 3.1, 2.3) < 0.18
		for i in sign.length():
			var ch := sign.substr(i, 1)
			var a := 0.12 if (i == 9 and flick) else 0.95
			draw_string(font, Vector2(sx, top + 46), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.86, 0.9, 0.95, a))
			sx += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# niebla baja
		draw_rect(Rect2(0, h - 260, w, 260), Color(0.05, 0.06, 0.07, 0.55))

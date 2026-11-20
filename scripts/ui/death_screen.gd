extends Control
## "Usuario desconectado. Motivo: ___" (GDD 4.8). v0.3: aparece después del screamer (death_shown); [Espacio]
## reconecta (Checkpoints.respawn) y [Esc] vuelve al menú como salida segura. Se resetea con shift_started,
## respawned y returned_to_menu, así nunca queda visible ni activa encima de un turno nuevo (bug de la v0.2).
## v0.3.1 Q2 (F1/B8): mucho más tenso. Un monitor que se muere: ráfaga de estática al entrar que se apaga a un
## ruido de fondo, líneas de barrido, barra que rueda, cortes de señal ("SEÑAL PERDIDA"), glitch RGB en el título,
## el motivo que se "reescribe" con caracteres corruptos hasta quedar fijo, y la cara del que te mató que aparece
## un instante entre la estática. Audio: estática (ruido, nunca tonos), el zumbido del monitor que muere y el eco
## grave de su grito. Con "reducir destellos": sin la cara ni los cortes, estática suave y quieta.

signal menu_requested()

const FACE_KEYS: Dictionary = {"shero": "shero_calvo_grito", "rasec": "rasec", "vitzo": "res://assets/ui/vitzo_cara.png",
	"rta": "perrito_rta_enojado", "trainer": "trainer_grito", "haime": "haime", "cliente": "shero_calvo_grito",
	"grasa": "grasa", "guardia": "guardia_fermin"}
## Slot de Q3 (opcional: sin él suena ruido procedural).
const Q3_ESTATICA := "sfx/estatica_desconexion"
const GLITCH_CHARS := "#%&@$*!?/\\|<>~^=+01█▓▒░"

var _avatar: TextureRect = null  # P6: quién te desconectó (ref_caras_v2)
var _title: Label = null
var _title_r: Label = null
var _title_c: Label = null
var _signal: Label = null
var _reason: Label = null
var _mode: Label = null
var _hint: Label = null
var _static: ColorRect = null
var _face: TextureRect = null
var _ghost: TextureRect = null  # la misma cara, fija y casi invisible, que se acerca muy despacio: sigue ahí
var _active: bool = false
var _min_wait: float = 0.0
var _t: float = 0.0
var _k: float = 0.0
var _burst_in: float = 0.0
var _face_in: float = 0.0
var _reason_full: String = ""
var _reason_t: float = 0.0
var _soft: bool = false
var _killer: String = ""
var _audio: Array[AudioStreamPlayer] = []
static var _noise_wav: AudioStreamWAV = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)
	# La cara del asesino entre la estática (detrás de todo, casi invisible).
	_face = TextureRect.new()
	_face.name = "CaraEntreEstatica"
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.modulate = Color(1, 1, 1, 0)
	_face.material = _face_material()
	_ghost = _face.duplicate() as TextureRect
	_ghost.name = "CaraQueSigueAhi"
	_ghost.material = _face_material()
	add_child(_ghost)
	add_child(_face)
	_static = ColorRect.new()
	_static.name = "Estatica"
	_static.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static.material = _static_material()
	add_child(_static)
	# Columna centrada por anclas.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(col)
	_avatar = TextureRect.new()
	_avatar.name = "AvatarAsesino"
	_avatar.custom_minimum_size = Vector2(112, 112)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_avatar.material = _face_material()
	col.add_child(_avatar)
	_signal = UITheme.label("", 16, Color(0.85, 0.2, 0.18))
	_signal.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_signal)
	# Título con separación RGB: dos copias (roja y cian) que saltan detrás del texto.
	var tbox := Control.new()
	tbox.custom_minimum_size = Vector2(640, 52)
	tbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tbox)
	_title_r = _title_copy(tbox, Color(1.0, 0.1, 0.12, 0.75))
	_title_c = _title_copy(tbox, Color(0.1, 0.95, 1.0, 0.6))
	_title = _title_copy(tbox, UITheme.EZLAK)
	_reason = UITheme.label("", 26, UITheme.TEXT)
	_reason.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_reason)
	_mode = UITheme.label("", 16, UITheme.DIM)
	_mode.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_mode)
	_hint = UITheme.label("", 16, UITheme.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.set_meta("guia", "muerte:reconectar")  # v0.3.2: la guía del Training señala «[Espacio] Reconectar» (TrainingTargets)
	col.add_child(_hint)
	col.set_meta("guia", "muerte:columna")
	UITheme.center_fit(col)
	EventBus.death_shown.connect(_on_death)
	EventBus.shift_started.connect(reset)
	EventBus.respawned.connect(func(_k: String) -> void: reset())
	EventBus.returned_to_menu.connect(reset)


func _title_copy(parent: Control, c: Color) -> Label:
	var l := UITheme.label("", 34, c)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(l)
	return l


## Oculta y desactiva la pantalla (y devuelve el control al jugador si hay uno).
func reset() -> void:
	var was := _active or visible
	_active = false
	visible = false
	_stop_audio()
	if was:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			player.input_locked = false


func is_active() -> bool:
	return _active


func _on_death(cause: String) -> void:
	_active = true
	visible = true
	_min_wait = 1.5
	_t = 0.0
	_k = 1.0
	(_static.material as ShaderMaterial).set_shader_parameter("k", _k)  # la ráfaga desde el primer fotograma
	_burst_in = randf_range(1.8, 3.0)
	_face_in = randf_range(0.5, 0.9)
	_soft = bool(Loc.get_setting("flash_reduction", false))
	var title := tr("DEATH_TITLE")
	for l in [_title, _title_r, _title_c]:
		l.text = title
	_signal.text = tr("DEATH_Q2_SIGNAL")
	var killer := Checkpoints.death_killer if Checkpoints.death_cause == cause else ""
	_killer = killer
	_avatar.texture = EzlakHub.avatar(Faces.killer_avatar_slug(killer))
	_avatar.modulate = Color(0.55, 0.55, 0.58) if killer in ["", "fatiga"] else Color(1, 1, 1)
	_face.texture = _killer_face(killer)
	_face.modulate = Color(1, 1, 1, 0)
	_ghost.texture = _face.texture
	_ghost.modulate = Color(1, 0.8, 0.8, 0)
	_ghost.scale = Vector2.ONE
	var detail := Checkpoints.death_detail if Checkpoints.death_cause == cause else ""
	_reason_full = Loc.fmt(tr("DEATH_REASON"), {"motivo": Checkpoints.cause_text(cause, detail)})
	_reason_t = 0.0
	_reason.text = _corrupt(_reason_full, 1.0)
	if GameState.is_real_mode():
		_mode.text = tr("DEATH_REAL_MODE")
	elif cause == "colapso":
		# v0.3.2-core3: ya no es siempre «Fatiga 60»: como mucho el tope de la dificultad, nunca más que el checkpoint.
		_mode.text = Loc.fmt(tr("CORE3_DEATH_COLLAPSE"), {"n": int(round(Checkpoints.next_respawn_fatigue(cause)))})
	else:
		_mode.text = tr("CORE3_DEATH_MODE")  # v0.3.2-core3: ya sin «(Fatiga +15)»: reaparecer no suma Fatiga
	_hint.text = ""
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true
	_sound(cause, killer)


func _killer_face(killer: String) -> Texture2D:
	if killer in ["", "fatiga"]:
		return null
	var key := str(FACE_KEYS.get(killer, ""))
	if key == "":
		return null
	if key.begins_with("res://"):
		return Faces.texture_at(key)
	var t := Faces.texture_at("res://assets/screamers/" + key + ".png")
	return t if t != null else Faces.texture(key)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Estática: ráfaga al entrar que se apaga a un ruido de fondo; cortes de señal de vez en cuando.
	var base := 0.22 if not _soft else 0.14
	_k = move_toward(_k, base, delta * (0.7 if _t < 1.4 else 2.0))
	_burst_in -= delta
	if _burst_in <= 0.0 and not _soft:
		_burst_in = randf_range(2.2, 4.0)
		_k = 0.75
		_play_noise(-16.0, 0.25)
	var m := _static.material as ShaderMaterial
	m.set_shader_parameter("k", _k)
	m.set_shader_parameter("soft", 1.0 if _soft else 0.0)
	# La cara entre la estática: 2-3 fotogramas, nunca fija.
	if _face.texture != null and not _soft:
		_face_in -= delta
		if _face_in <= 0.0:
			_face_in = randf_range(1.6, 3.4) if _t > 1.0 else randf_range(0.25, 0.5)
			var tw := create_tween()
			tw.tween_property(_face, "modulate", Color(1, 1, 1, randf_range(0.35, 0.6)), 0.03)
			tw.tween_property(_face, "modulate", Color(1, 1, 1, 0.0), randf_range(0.06, 0.12))
			if _t > 1.0:
				_k = maxf(_k, 0.6)  # la señal se rompe con ella
	# Debajo de todo, la cara se queda: casi invisible, respirando y acercándose (2 % cada 3 s).
	if _ghost.texture != null:
		var fade_in := clampf((_t - 1.2) / 2.0, 0.0, 1.0)
		var a := (0.09 + 0.04 * sin(_t * 1.7)) * fade_in * (0.4 if _soft else 1.0)
		_ghost.modulate = Color(1, 0.78, 0.78, a)
		_ghost.pivot_offset = _ghost.size * 0.5
		_ghost.scale = Vector2.ONE * minf(1.0 + _t * 0.007, 1.35)
	# Título con separación RGB que salta.
	var j := (6.0 if _k > 0.5 else 2.0) * (0.3 if _soft else 1.0)
	_title_r.position = Vector2(randf_range(-j, j), randf_range(-j, j) * 0.4)
	_title_c.position = Vector2(randf_range(-j, j), randf_range(-j, j) * 0.4)
	_title.position = Vector2(randf_range(-1.0, 1.0), 0.0) if _k > 0.5 and not _soft else Vector2.ZERO
	_signal.visible = fmod(_t, 1.1) < 0.7 or _soft
	# El motivo se reescribe: corrupto al principio, se va fijando letra por letra.
	_reason_t += delta
	var settle := clampf((_reason_t - 0.3) / 1.4, 0.0, 1.0)
	var glitchy := 1.0 - settle
	if _k > 0.6 and settle >= 1.0 and not _soft:
		glitchy = 0.15
	_reason.text = _corrupt(_reason_full, glitchy) if glitchy > 0.001 else _reason_full
	if not _active:
		return
	if _min_wait > 0.0:
		_min_wait -= delta
		return
	_hint.text = "%s     %s" % [tr("DEATH_CONTINUE"), tr("DEATH_BACK_MENU")]
	if Input.is_action_just_pressed("accept"):
		_reconnect()
	elif Input.is_action_just_pressed("pause"):
		_active = false
		menu_requested.emit()


## Texto con una fracción `amount` de caracteres corruptos (los espacios quedan).
func _corrupt(text: String, amount: float) -> String:
	if amount <= 0.0:
		return text
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ch != " " and randf() < amount * 0.85:
			out += GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
		else:
			out += ch
	return out


## [Espacio] Reconectar: una sola vez por muerte (respawn() ignora llamadas repetidas).
func _reconnect() -> void:
	_active = false
	visible = false
	_stop_audio()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = false
	Checkpoints.respawn()


# --- audio (sin tonos: ruido, zumbido grave, eco del grito) ----------------------------------------

func _sound(_cause: String, killer: String) -> void:
	_stop_audio()
	_silence_tonal()
	if AudioManager.has_slot(Q3_ESTATICA):
		_play(AudioManager.resolve(Q3_ESTATICA), -4.0, 1.0)
	else:
		_play_noise(-6.0, 0.9)
	# El monitor que muere: zumbido grave (acúfeno bajado) que se va.
	var hum := _play(AudioManager.resolve("sfx/acufeno"), -20.0, 0.5)
	if hum != null:
		create_tween().tween_property(hum, "volume_db", -42.0, 3.5)
	# El eco de su grito, lento y grave.
	var row := Screamers.row_for(killer, Checkpoints.death_cause) if killer != "" and killer != "fatiga" else {}
	var frase := str(row.get("frase", ""))
	if frase != "":
		var p := AudioManager.voice_path(frase + "_01")
		if p == "":
			p = AudioManager.voice_path(frase)
		var e := _play(p, -17.0, 0.48)
		if e != null:
			create_tween().tween_property(e, "volume_db", -40.0, 3.0)
	if killer in ["", "fatiga"]:
		_play(AudioManager.resolve("sfx/latido_lento"), -14.0, 0.8)


## El "clic del auricular" de la v0.3 (tono sintético) no va con la pantalla nueva: se corta si sonó.
func _silence_tonal() -> void:
	for p in AudioManager.find_children("*", "AudioStreamPlayer", true, false):
		var ap := p as AudioStreamPlayer
		if ap.playing and ap.stream != null and (ap.stream.resource_path.contains("auricular_desconexion") or ap.stream is AudioStreamWAV and str(AudioManager.last_sfx.get("slot", "")) == "sfx/auricular_desconexion"):
			ap.stop()


func _play(path: String, db: float, pitch: float) -> AudioStreamPlayer:
	if path == "":
		return null
	var st := load(path) as AudioStream
	if st == null:
		return null
	return _play_stream(st, db, pitch)


func _play_stream(st: AudioStream, db: float, pitch: float) -> AudioStreamPlayer:
	var ap := AudioStreamPlayer.new()
	ap.stream = st
	ap.bus = "Sala"
	ap.volume_db = db
	ap.pitch_scale = pitch
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)
	_audio.append(ap)
	return ap


func _play_noise(db: float, seconds: float) -> void:
	# La estática grabada de Q3 si está; si no, ruido blanco (ruido, no un tono).
	var ap: AudioStreamPlayer = null
	if AudioManager.has_slot(Q3_ESTATICA):
		ap = _play(AudioManager.resolve(Q3_ESTATICA), db, randf_range(0.9, 1.1))
	else:
		if _noise_wav == null:
			_noise_wav = _make_noise()
		ap = _play_stream(_noise_wav, db, 1.0)
	if ap != null:
		var w: WeakRef = weakref(ap)
		var me: WeakRef = weakref(self)
		get_tree().create_timer(seconds, true).timeout.connect(func() -> void:
			var a: AudioStreamPlayer = w.get_ref()
			var d: Control = me.get_ref()
			if a != null and d != null:
				d.create_tween().tween_property(a, "volume_db", -60.0, 0.2))


func _stop_audio() -> void:
	for ap in _audio:
		if is_instance_valid(ap):
			ap.stop()
			ap.queue_free()
	_audio.clear()


## Estática de TV (ruido blanco con chasquidos y caída de señal), 1,2 s mono.
static func _make_noise() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 1.2)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var v := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, v, 0.45)
		var crackle := (rng.randf_range(-1.0, 1.0) * 3.0) if rng.randf() < 0.002 else 0.0
		var env := (1.0 - t) * (0.75 + 0.25 * sin(t * 37.0))
		data.encode_s16(i * 2, int(clampf((lp * 0.8 + crackle) * env * 0.6, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


# --- shaders ----------------------------------------------------------------------------------------

func _static_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float k = 1.0;
uniform float soft = 0.0;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float tick = floor(TIME * (soft > 0.5 ? 8.0 : 30.0));
	vec2 px = floor(uv * vec2(480.0, 270.0));
	float n = h2(px + vec2(tick * 13.0, tick * 7.0));
	// barra que rueda y líneas de barrido
	float roll = smoothstep(0.0, 0.08, abs(fract(uv.y - TIME * 0.23) - 0.5) - 0.38);
	float scan = 0.75 + 0.25 * sin(uv.y * 270.0 * 3.14159);
	// cortes horizontales de señal
	float band = floor(uv.y * 24.0);
	float cut = step(0.93, h2(vec2(band, tick))) * step(0.4, k) * (1.0 - soft);
	float a = clamp(k * (0.55 + 0.45 * n) * scan + cut * 0.6, 0.0, 1.0);
	vec3 c = vec3(n * 0.85 + 0.15) * vec3(0.82, 0.86, 0.9);
	c = mix(c, vec3(0.0), roll * 0.6);
	// viñeta
	float v = smoothstep(0.35, 0.95, length(uv - 0.5) * 1.5);
	COLOR = vec4(c * (1.0 - v * 0.7), a * (1.0 - v * 0.4));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _face_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
float h(float x) { return fract(sin(x * 91.7) * 43758.5453); }
void fragment() {
	float tt = floor(TIME * 24.0);
	vec2 uv = UV;
	uv.x += (h(tt + floor(uv.y * 30.0)) - 0.5) * 0.03;
	vec4 c = texture(TEXTURE, uv);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 g = clamp((vec3(l) - 0.45) * 2.2 + 0.3, 0.0, 1.0) * vec3(0.9, 0.85, 0.85);
	float r = length(UV - 0.5) * 2.0;
	COLOR = vec4(g * (1.0 - 0.6 * smoothstep(0.3, 1.0, r)), c.a * COLOR.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

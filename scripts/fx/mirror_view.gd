class_name MirrorView
extends Node
## v0.3.2 (Joan: «el espejo cuando le das interactuar muestra una cámara con una fila de 3 asientos… y se queda un
## buen rato»). Antes, mirarse en el espejo de un baño con Fatiga ≥ 50 disparaba la distorsión 5 «El espejo» (GDD 4.7,
## H5): la pantalla entera pasaba a la cámara de seguridad de la Fila C (C-13/C-14/C-15 armados 60 m bajo el piso,
## tú de espaldas en tu PC y Shero detrás de la silla UN fotograma) y duraba hasta frotarte los ojos (R) o 20 s.
## Nadie entendía que era «tu reflejo» y la vista no se iba.
## Ahora: mirarte = TU reflejo de verdad durante ~1,8 s (máx. 2 s) y el control vuelve siempre. Una cámara se pone en
## el punto reflejado de tus ojos al otro lado del plano del espejo, con el plano cercano EN el espejo (la pared de
## atrás no tapa), filma a un SubViewport que se muestra invertido (como un espejo) con un marco oscuro. Tu cuerpo
## es un doble del agente elegido (con cabeza) en tu sitio, mirando al espejo, solo mientras dura.
## Susto opcional y raro (haunt): alguien queda de pie detrás de ti en el reflejo; al terminar el doble y la figura se
## borran, así que al darte vuelta no hay nadie. Lo pide la distorsión 5 (Fatiga ≥ 50, una vez por turno) o, muy de
## vez en cuando, el azar (RARE_CHANCE). Modo liviano: SubViewport de 320×180 y sin MSAA; calidad Baja: 480×270.

const DURATION := 1.8
const MAX_SECONDS := 2.0
const RARE_CHANCE := 0.06
const HAUNT_AT := 0.55
const BEHIND_M := 1.15  # a qué distancia detrás de ti se para la figura
const TURN_MAX := 0.7  # rad: cuánto puede girar el doble respecto del espejo (≈ 40°)
const LAMP_ENERGY := 1.25

static var current: MirrorView = null

var mirror: Node3D = null
var haunted: bool = false
var t: float = 0.0
var _player: Player = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _layer: CanvasLayer = null
var _rect: TextureRect = null
var _root: Node3D = null
var _double: Node3D = null
var _figure: Node3D = null
var lamp: OmniLight3D = null  # luz de tocador (solo mientras dura el reflejo)
var _locked_by_me: bool = false
var _rig_was_visible: bool = true
var _done: bool = false
var normal: Vector3 = Vector3.FORWARD  # normal del espejo hacia el baño (pruebas)


## Muestra el reflejo frente a `p_mirror`. Si ya hay uno abierto, no abre otro (devuelve el actual).
static func show_for(p_mirror: Node3D, p: Player) -> MirrorView:
	if current != null and is_instance_valid(current) and not current._done:
		return current
	if p_mirror == null or p == null or not p.is_inside_tree():
		return null
	var v := MirrorView.new()
	v.name = "MirrorView"
	v.mirror = p_mirror
	v._player = p
	(p.get_parent() if p.get_parent() != null else p).add_child(v)
	v._start()
	current = v
	return v


static func is_open() -> bool:
	return current != null and is_instance_valid(current) and not current._done


func _start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: finish())
	EventBus.returned_to_menu.connect(finish)
	# Plano del espejo: su eje fino (Vidrio de 0,04 m en x local) mirando hacia el jugador.
	var m := mirror.global_transform
	var axis := m.basis.x.normalized()
	var glass := mirror.get_node_or_null("Vidrio") as MeshInstance3D
	if glass != null and glass.mesh is BoxMesh:
		var bs := (glass.mesh as BoxMesh).size
		axis = (m.basis.x if bs.x <= bs.z else m.basis.z).normalized()
	var eye := _player.camera.global_position
	if axis.dot(eye - m.origin) < 0.0:
		axis = -axis
	axis.y = 0.0
	normal = axis.normalized()
	var d := maxf(normal.dot(eye - m.origin), 0.25)
	var refl := eye - 2.0 * d * normal
	# --- Vista: SubViewport con el mundo del juego ---
	var light := GfxQuality.is_light()
	_vp = SubViewport.new()
	_vp.name = "ReflejoVP"
	_vp.size = Vector2i(320, 180) if light else (Vector2i(480, 270) if GfxQuality.is_low() else Vector2i(960, 540))
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.world_3d = _player.get_viewport().world_3d
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.near = d + 0.04  # el plano cercano en el espejo: la pared de atrás no tapa
	_cam.far = 40.0
	_vp.add_child(_cam)
	_cam.global_position = refl
	_cam.look_at(refl + normal, Vector3.UP)
	_cam.current = true
	# --- Tu doble (con cabeza) donde estás, mirando al espejo ---
	_root = Node3D.new()
	_root.name = "ReflejoSet"
	_player.get_parent().add_child(_root)
	_double = Node3D.new()
	_double.name = "Doble"
	_root.add_child(_double)
	var feet := _player.global_position
	_double.global_position = feet
	# v0.3.2-core: de CARA al espejo. `normal` va del espejo hacia el baño, así que el espejo queda en −normal. Antes
	# miraba a +normal (de espaldas al espejo): el reflejo enseñaba tu nuca, y como además salía en silueta nadie lo vio.
	_double.look_at(feet - normal, Vector3.UP)
	# v0.3.2-core: el doble mira hacia donde miras tú (si te pones de lado, de lado sales), sin llegar a dar la espalda.
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		_double.rotate_y(clampf((-normal).signed_angle_to(fwd.normalized(), Vector3.UP), -TURN_MAX, TURN_MAX))
	var rig := CharacterRig.attach(_double, CharacterRig.agent_model(GameState.agent), 1.72, 180.0)
	if rig != null:
		rig.play("idle")
		# La mirada automática de los personajes sigue a la cámara del jugador, que aquí está DENTRO de la cabeza del
		# doble: la cabeza se torcía hacia un lado. Apagada (interruptor público del animador), mira al frente: al espejo.
		var an: Variant = rig.get("animator")
		if an != null and "look_enabled" in an:
			an.set("look_enabled", false)
	else:
		Greybox.box(_double, "Cuerpo", Vector3(0, 0.9, 0), Vector3(0.45, 1.7, 0.3), Color(0.2, 0.25, 0.35), false)
	_vanity_light(eye - d * normal)
	var prig: Variant = _player.get("_rig")
	if prig is Node3D:
		_rig_was_visible = (prig as Node3D).visible
		(prig as Node3D).visible = false
	# --- Pantalla: el reflejo invertido, con marco y viñeta ---
	_layer = CanvasLayer.new()
	_layer.name = "ReflejoCapa"
	_layer.layer = 11
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bg)
	_rect = TextureRect.new()
	_rect.name = "Reflejo"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.texture = _vp.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.flip_h = true  # un espejo invierte izquierda y derecha
	_rect.material = _glass_material()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)
	_layer.visible = true
	_rect.modulate.a = 0.0
	# El jugador no se mueve mientras se mira (máx. 2 s); el control vuelve siempre en finish().
	if not _player.input_locked:
		_player.input_locked = true
		_locked_by_me = true
	# Susto raro aunque no haya Fatiga alta (la distorsión 5 lo pide aparte, con haunt()).
	if not bool(GameState.flags.get("espejo_susto_visto", false)) and randf() < RARE_CHANCE:
		haunt()


## v0.3.2-core · Luz de tocador. El doble mira al espejo y la luz del baño le queda detrás y arriba: en el reflejo
## salía una SILUETA NEGRA (no se veía que eras tú). Mientras dura el reflejo, una luz suave en el borde de arriba del
## espejo, frente a ti, te ilumina la cara y la ropa (y a quien esté detrás, de refilón: se le ve la forma, no la
## cara). Sin sombras y con poco alcance: no cambia el baño cuando no te miras. Vive en el set del reflejo (se borra
## con él). `at` = el punto del espejo que tienes delante de los ojos.
func _vanity_light(at: Vector3) -> void:
	lamp = OmniLight3D.new()
	lamp.name = "LuzTocador"
	lamp.light_color = Color(0.93, 0.97, 1.0)
	lamp.light_energy = LAMP_ENERGY
	lamp.omni_range = 2.1  # llega a ti (0,6-1 m del espejo); a quien esté detrás solo de refilón
	lamp.omni_attenuation = 1.0
	lamp.light_specular = 0.15
	lamp.shadow_enabled = false
	_root.add_child(lamp)
	lamp.global_position = at + normal * 0.28 + Vector3.UP * 0.5


## Alguien de pie detrás de ti en el reflejo (y no está cuando te das vuelta). Una vez por turno.
func haunt() -> void:
	if haunted or _done or _root == null:
		return
	haunted = true
	GameState.flags["espejo_susto_visto"] = true
	_figure = Node3D.new()
	_figure.name = "AlguienDetras"
	_root.add_child(_figure)
	var side := normal.cross(Vector3.UP).normalized()
	# v0.3.2-core: DETRÁS de ti = más lejos del espejo (+normal). Antes iba a −normal: 1,25 m hacia el espejo desde tus
	# pies, o sea dentro de la pared, por delante del plano cercano de la cámara: la figura nunca llegó a verse.
	var p := _player.global_position + normal * BEHIND_M + side * 0.38
	_figure.global_position = p
	_figure.look_at(p - normal, Vector3.UP)  # te mira a ti (y al espejo)
	var sr := CharacterRig.attach(_figure, "shero", 2.05, 180.0)
	if sr != null:
		sr.play("stare_camera", true, 0.6, ["idle"])
	else:
		Greybox.box(_figure, "Silueta", Vector3(0, 1.0, 0), Vector3(0.5, 2.0, 0.35), Color(0.03, 0.03, 0.035), false)
	_figure.visible = false  # aparece a HAUNT_AT s, con el reflejo ya a la vista


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var fade := 0.14
	if _rect != null:
		_rect.modulate.a = clampf(minf(t / fade, (DURATION - t) / fade), 0.0, 1.0)
		if _rect.material is ShaderMaterial:
			(_rect.material as ShaderMaterial).set_shader_parameter("t", t)
	if _figure != null and not _figure.visible and t >= HAUNT_AT:
		_figure.visible = true
		if not bool(Loc.get_setting("flash_reduction", false)):
			AudioManager.play_sfx("kill_susurro")  # sutil: un susurro, sin golpe
	if t >= DURATION or t >= MAX_SECONDS:
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	if current == self:
		current = null
	if _root != null and is_instance_valid(_root):
		_root.queue_free()  # el doble y la figura se van: al darte vuelta no hay nadie
	if _player != null and is_instance_valid(_player):
		var prig: Variant = _player.get("_rig")
		if prig is Node3D:
			(prig as Node3D).visible = _rig_was_visible
		if _locked_by_me:
			_player.input_locked = false
	queue_free()


func _exit_tree() -> void:
	finish()


func _glass_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float t = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(lum), c.rgb, 0.8) * vec3(0.93, 0.98, 1.0);
	float r = length((UV - 0.5) * vec2(1.25, 1.0));
	float vig = 1.0 - smoothstep(0.42, 0.78, r);
	float smudge = 0.04 * sin(UV.x * 23.0 + UV.y * 11.0) * sin(UV.y * 17.0 - 1.3);
	col = col * (0.2 + 0.8 * vig) + smudge * vig;
	COLOR = vec4(col, c.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

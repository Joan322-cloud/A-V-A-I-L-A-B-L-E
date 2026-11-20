class_name Flashback
extends RefCounted
## v0.3.2 · El Training es un RECUERDO (decidido por Joan 2026-11-11, docs/AVAILABLE_trama_semana §1.3): un flashback
## jugable del día en que el agente entró (fecha de la biblia, en data/turnos.json → turno 0 → "recuerdo"), con el
## agente todavía contento, la torre nueva y limpia y el Trainer amable. Al firmar el contrato, corte seco al presente:
## «Lunes 9 de noviembre de 2026 — 3 años y 2 meses después» y un contraste breve (la foto sonriente del fotocheck
## frente a la cara cansada del espejo, con el fotocheck rajado).
## Aquí: datos del recuerdo por agente · la capa de imagen (tonos cálidos, viñeta y grano suaves) · la tarjeta
## «Recuerdo · fecha» · el fotocheck · limpiar un piso (sin horror de oficina, tubos firmes, luz de día) · el look del
## agente (recuerdo / presente) · el corte al presente.

const DAY0 := 0
const FACE_VARIANTS := "res://assets/faces/"
## Prefijos de los nodos de la capa de horror de oficina (OfficeHorror / HorrorProps) que el recuerdo no tiene.
const HORROR_PREFIXES: Array[String] = ["TuboMuerto", "TuboTartamudo", "Tartamudeo", "BaldosaManchada", "BaldosaColgando",
	"HeadsetColgando", "SillaContraPared", "PosterKpiTachado", "ImpresoraAtascada", "FueraDeServicio",
	"MonitorDesconectado", "TazaMoho", "AlgoOscuro", "Nota_", "NumeroCambia", "Cambia",
	# lo que el edificio de hoy tiene tirado o colgado y aquel día no: el Halloween olvidado (murciélagos, brujas, la
	# figura que ya no es de papel), el bulto con headset de la banca del tópico y la silueta tras su puerta, las
	# huellas que no son de ningún zapato y los cartones del lobby
	"Murcielago", "Bruja", "FiguraColgada", "BultoEspera", "Silueta", "RanuraLuz", "Huella", "Carton"]

static var active: bool = false  # el recuerdo está en pantalla (lo consultan el HUD y el look del agente)
## El recuerdo es de mañana: el texto del reloj (HUD, PC, Fonex, Ezlak) va 9 h por delante del reloj de juego.
const CLOCK_SHIFT := 9.0 * 3600.0

## EL ASPECTO DEL RECUERDO (calidad Baja/base, sin sombras): cálido y agradable, nunca quemado. Todo sale de aquí y de
## TrainingRoom.LOOK (las luces del aula). La calidad Media/Alta (scripts/gfx, data/gfx_looks.json → "recuerdo") puede
## partir de estos mismos valores. Ambiente neutro-cálido a media energía (las luces dan el volumen), las luces del
## piso apenas entibiadas y sin subirlas, y una gradación SUAVE sobre la pantalla: tinte cálido leve, un poco más de
## saturación y contraste, viñeta y grano casi invisibles.
const LOOK := {
	"ambiente_color": Color(0.82, 0.81, 0.79), "ambiente_energia": 0.5,
	"niebla_densidad": 0.001, "niebla_color": Color(0.7, 0.68, 0.64), "fondo": Color(0.7, 0.8, 0.92),
	"luces_tinte": Color(1.0, 0.92, 0.8), "luces_mezcla": 0.85, "luces_ganancia": 0.9,
	"grade_tinte": Color(1.03, 1.0, 0.95), "grade_saturacion": 1.06, "grade_contraste": 1.06, "grade_vineta": 0.1, "grade_grano": 0.016,
	# Rodilla de las luces altas (1.0 → 0.95, tope 0.96): nada llega a blanco en Baja/Modo liviano. Suave a propósito:
	# la rama de gráficos baja además los blancos del entorno (tonemap_white 2.2, exposición 1.3) y con una rodilla más
	# fuerte las dos cosas juntas dejaban el aula plana (blancos en 221; con esta, ~230).
	"grade_hombro": 0.86, "grade_hombro_k": 2.5,
}


# --- datos ------------------------------------------------------------------------------------------

static func _day0() -> Dictionary:
	for t in DataLoader.list("turnos"):
		if int(t.get("turno", -1)) == DAY0:
			return t
	return {}


static func memory(agent: String) -> Dictionary:
	var r: Dictionary = _day0().get("recuerdo", {})
	return r.get(agent, r.get("Jiroshi", {}))


## «Viernes 8 de septiembre de 2023».
static func date_text(agent: String) -> String:
	return Loc.pick(memory(agent).get("fecha", {}))


## «3 años y 2 meses después».
static func later_text(agent: String) -> String:
	return Loc.pick(memory(agent).get("despues", {}))


## «Lunes 9 de noviembre de 2026».
static func present_text() -> String:
	return Loc.pick(_day0().get("presente", {"es": "Lunes 9 de noviembre de 2026", "en": "Monday, November 9, 2026"}))


## Líneas del monólogo interior del agente (alegre) y de los compañeros de promoción.
static func inner_lines(agent: String) -> Array:
	return memory(agent).get("piensa", [])


static func classmate_lines() -> Array:
	return _day0().get("promocion", [])


## Lo que te contesta cada compañero cuando lo llamas con el comodín de práctica: {Nombre: {es, en, voz}}.
static func comodin_lines() -> Dictionary:
	return _day0().get("comodin", {})


## Los nombres de tu promoción (los cuatro que se sientan contigo en el recuerdo).
static func classmates() -> Array:
	return _day0().get("clase", ["Llauri", "Marko", "Ttoom", "Juan"])


## Eco del recuerdo en la semana: {texto, voz} de lo que piensa el agente (turnos.json → ecos; voces/agentes/<agente>_<eco>).
static func echo(agent: String, key: String) -> Dictionary:
	var e: Dictionary = (_day0().get("ecos", {}) as Dictionary).get(key, {})
	if e.is_empty():
		return {}
	var d := date_text(agent)
	var spoken := d.get_slice(", ", 1) if d.contains(", ") else d.substr(d.find(" ") + 1)  # sin el día de la semana
	return {"texto": Loc.fmt(Loc.pick(e), {"fecha": spoken}), "voz": "%s_%s" % [agent.to_lower(), str(e.get("voz", key))]}


## Un eco que no dice tu agente (el Trainer de hoy): {texto, voz} tal cual, sin el prefijo del agente.
static func echo_raw(key: String) -> Dictionary:
	var e: Dictionary = (_day0().get("ecos", {}) as Dictionary).get(key, {})
	if e.is_empty():
		return {}
	return {"texto": Loc.pick(e), "voz": str(e.get("voz", key))}


## Cara del agente en el recuerdo (cálida, nítida) o en el presente (pálida, con ojeras). Generadas desde la foto de
## Joan por tools (assets/faces/<slug>_recuerdo.png / _presente.png); si faltan, la normal.
static func face(agent: String, mode: String) -> Texture2D:
	var slug := agent.to_lower()
	var p := FACE_VARIANTS + slug + "_" + mode + ".png"
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return Faces.texture(Faces.agent_slug(agent))


# --- capa de imagen ----------------------------------------------------------------------------------

static func grade_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;  // sin mipmaps: la gradación lee el píxel tal cual (y el equipo flojo no arma la cadena en cada cuadro)
uniform float amount = 1.0;
uniform float time_s = 0.0;
uniform vec3 tint = vec3(1.03, 1.0, 0.95);
uniform float saturation = 1.06;
uniform float contrast = 1.06;
uniform float vignette = 0.1;
uniform float grain = 0.016;
uniform float shoulder = 0.86;  // desde aquí las luces altas se comprimen: una pared al sol queda crema, nunca blanco quemado
uniform float shoulder_k = 2.5;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 w = mix(vec3(l), c, saturation) * tint;
	w = (w - 0.5) * contrast + 0.5;
	vec3 top = min(w, vec3(shoulder + 0.5 / max(shoulder_k, 0.001)));  // hasta el vértice de la curva: siempre creciente
	vec3 over = max(top - shoulder, vec3(0.0));
	w = top - over * over * shoulder_k;
	float v = smoothstep(0.98, 0.42, length(SCREEN_UV - 0.5));
	w *= mix(1.0 - vignette, 1.0, v);
	float g = hash(floor(FRAGCOORD.xy * 0.5) + vec2(floor(time_s * 24.0) * 3.1, 0.0)) - 0.5;
	w += g * grain;
	COLOR = vec4(mix(c, clamp(w, 0.0, 1.0), amount), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var t: Color = LOOK["grade_tinte"]
	m.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
	m.set_shader_parameter("saturation", float(LOOK["grade_saturacion"]))
	m.set_shader_parameter("contrast", float(LOOK["grade_contraste"]))
	m.set_shader_parameter("vignette", float(LOOK["grade_vineta"]))
	m.set_shader_parameter("grain", float(LOOK["grade_grano"]))
	m.set_shader_parameter("shoulder", float(LOOK["grade_hombro"]))
	m.set_shader_parameter("shoulder_k", float(LOOK["grade_hombro_k"]))
	return m


## Capa a pantalla completa con el tratamiento del recuerdo (debajo del panel del Training y de los subtítulos).
static func make_layer(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "FlashbackLayer"
	layer.layer = 4
	var rect := ColorRect.new()
	rect.name = "Gradacion"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = grade_material()
	layer.add_child(rect)
	var tick := _GrainClock.new()
	tick.mat = rect.material as ShaderMaterial
	rect.add_child(tick)
	if parent.is_node_ready():
		parent.add_child(layer)
	else:
		parent.add_child.call_deferred(layer)  # el Training arranca desde Main._ready (bot --tras-training): la raíz aún arma sus hijos
	return layer


class _GrainClock extends Node:
	var mat: ShaderMaterial = null
	var t: float = 0.0

	func _process(delta: float) -> void:
		t += delta
		if mat != null:
			mat.set_shader_parameter("time_s", t)


## Tarjeta del comienzo: «RECUERDO · Viernes 8 de septiembre de 2023 · Training KipuPay» con el fotocheck nuevo.
## Se desvanece sola; devuelve el nodo (las pruebas lo buscan como "TarjetaRecuerdo").
static func date_card(parent: Node, agent: String, seconds: float = 4.5) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "TarjetaRecuerdo"
	layer.layer = 27
	parent.add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.045, 0.03, 0.86)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(vb)
	var top := UITheme.label(TranslationServer.translate("FB_RECUERDO"), 20, Color(1.0, 0.86, 0.62), true)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(top)
	var dl := UITheme.label(date_text(agent), 40, Color(1.0, 0.95, 0.86), true)
	dl.name = "Fecha"
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(dl)
	var sub := UITheme.label(TranslationServer.translate("FB_RECUERDO_SUB"), 18, Color(0.95, 0.85, 0.7), false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(sub)
	var cc := CenterContainer.new()
	vb.add_child(cc)
	cc.add_child(fotocheck(agent, "recuerdo"))
	vb.position -= vb.get_combined_minimum_size() * 0.5
	var tw := layer.create_tween()
	root.modulate.a = 0.0
	tw.tween_property(root, "modulate:a", 1.0, 0.6)
	tw.tween_interval(maxf(seconds - 1.6, 0.5))
	tw.tween_property(root, "modulate:a", 0.0, 1.0)
	tw.tween_callback(layer.queue_free)
	return root


## Fotocheck (tarjeta de identificación): "recuerdo" nuevo y brillante con la foto sonriente; "presente" gastado y
## rajado. Juan no tiene foto (la biblia: el sistema rechazó las cuatro): «FOTO PENDIENTE».
static func fotocheck(agent: String, mode: String) -> Control:
	var card := PanelContainer.new()
	card.name = "Fotocheck_" + mode
	card.custom_minimum_size = Vector2(300, 420)
	var sb := StyleBoxFlat.new()
	var fresh := mode == "recuerdo"
	sb.bg_color = Color(0.97, 0.97, 0.95) if fresh else Color(0.72, 0.71, 0.66)
	sb.border_color = Color(0.16, 0.52, 0.52) if fresh else Color(0.32, 0.36, 0.36)
	sb.set_border_width_all(4)
	sb.border_width_top = 26
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)
	var brand := UITheme.label("KONZENTRAMANCE · KipuPay", 13, Color(0.1, 0.32, 0.34) if fresh else Color(0.2, 0.24, 0.24), true)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(brand)
	var photo := TextureRect.new()
	photo.name = "Foto"
	photo.custom_minimum_size = Vector2(240, 240)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if agent == "Juan":
		photo.texture = Faces.texture("juan_silueta")
	else:
		photo.texture = face(agent, mode)
	if not fresh:
		photo.modulate = Color(0.8, 0.8, 0.8)
	vb.add_child(photo)
	if agent == "Juan":
		var pend := UITheme.label(TranslationServer.translate("FB_FOTO_PENDIENTE"), 12, Color(0.55, 0.2, 0.15), true)
		pend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(pend)
	var nm := UITheme.label(agent.to_upper(), 26, Color(0.08, 0.08, 0.1), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(nm)
	var role := UITheme.label(TranslationServer.translate("FB_FOTOCHECK_ROL"), 13, Color(0.25, 0.27, 0.3), false)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(role)
	if not fresh:
		var crack := _Crack.new()
		crack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(crack)
	return card


class _Crack extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(w * 0.08, h * 0.0), Vector2(w * 0.3, h * 0.22), Vector2(w * 0.24, h * 0.41),
			Vector2(w * 0.55, h * 0.58), Vector2(w * 0.5, h * 0.77), Vector2(w * 0.86, h * 1.0)])
		draw_polyline(pts, Color(0.12, 0.12, 0.12, 0.85), 2.5, true)
		draw_line(pts[2], Vector2(w * 0.02, h * 0.5), Color(0.12, 0.12, 0.12, 0.7), 1.6, true)
		draw_line(pts[3], Vector2(w * 0.92, h * 0.46), Color(0.12, 0.12, 0.12, 0.6), 1.4, true)


# --- la torre nueva y limpia ---------------------------------------------------------------------------

## Deja un piso como era hace años: sin la capa de horror de oficina, los fluorescentes firmes, la pintura y la
## alfombra más claras, luz de día por las ventanas y un ambiente más alto. Solo se llama en el recuerdo.
static func clean_floor(floor_node: Node3D) -> int:
	if floor_node == null:
		return 0
	var hidden := 0
	for n in floor_node.find_children("*", "", true, false):
		var nm := String(n.name)
		for pre in HORROR_PREFIXES:
			if nm.begins_with(pre):
				if n is Node3D:
					(n as Node3D).visible = false
				n.set_process(false)
				n.set_physics_process(false)
				hidden += 1
				break
		if nm == "Inquietud" or nm == "Animo":
			n.set_process(false)  # nada del presente en el recuerdo: ni anuncios por parlantes, ni susurros, ni apagones
		if n is FlickerLight:
			n.set_process(false)  # todos los tubos prenden, sin parpadeo
			var fl := n as FlickerLight
			if fl.light != null:
				fl.light.light_energy = fl.base_energy
		elif (n is OmniLight3D or n is SpotLight3D) and not n.has_meta("recuerdo"):
			var l := n as Light3D  # las luces de hoy, entibiadas (sin subirlas: el recuerdo no se quema)
			l.light_color = l.light_color.lerp(LOOK["luces_tinte"], float(LOOK["luces_mezcla"]))
			l.light_energy *= float(LOOK["luces_ganancia"])
			l.set_meta("recuerdo", true)
	return hidden


## Ambiente del piso en el recuerdo (más luz, sin niebla oscura). `env` = el Environment del mundo.
static func brighten_env(env: Environment) -> void:
	if env == null:
		return
	env.ambient_light_color = LOOK["ambiente_color"]
	env.ambient_light_energy = float(LOOK["ambiente_energia"])
	env.fog_density = float(LOOK["niebla_densidad"])
	env.fog_light_color = LOOK["niebla_color"]
	env.background_color = LOOK["fondo"]
	if env.adjustment_enabled:
		env.adjustment_saturation = 1.0  # sin la paleta nocturna desaturada de los turnos


# --- el agente: recuerdo y presente ------------------------------------------------------------------

## Tinte del cuerpo del agente: "recuerdo" = piel con más color, ropa limpia y viva; "presente" = pálido y
## desaturado. Trabaja sobre materiales duplicados (nunca toca el recurso del GLB).
static func apply_look(rig: Node, mode: String) -> int:
	if rig == null:
		return 0
	var n := 0
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_surface_override_material(i)
			if src == null:
				src = m.mesh.surface_get_material(i)
			if not (src is BaseMaterial3D):
				continue
			var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			var nm := String(mat.resource_name).to_lower()
			var skin := nm.contains("skin") or nm.contains("face") or nm.contains("piel") or nm.contains("cara")
			var c := mat.albedo_color
			if mode == "recuerdo":
				c = c * (Color(1.08, 1.0, 0.93) if skin else Color(1.08, 1.06, 1.04))
			else:
				var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				c = Color(l, l, l).lerp(c, 0.55) * Color(0.86, 0.87, 0.9)
			c.a = mat.albedo_color.a
			mat.albedo_color = c
			m.set_surface_override_material(i, mat)
			n += 1
	return n


## Quita los materiales propios que puso apply_look (o la ropa de civil de la promoción). Hay que llamarlo ANTES de
## liberar el cuerpo: si el nodo muere con materiales que solo él tiene, el servidor de render se queda un instante con
## su RID ya liberado («Parameter "material" is null» en el log, con el renderizador de pruebas).
static func clear_look(rig: Node) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			if m.get_surface_override_material(i) != null:
				m.set_surface_override_material(i, null)


# --- el corte al presente --------------------------------------------------------------------------------

## Corte seco a negro → «Lunes 9 de noviembre de 2026 — 3 años y 2 meses después» → el fotocheck nuevo junto a la cara
## cansada del espejo y el fotocheck rajado (≈ 7 s; [Espacio] o clic lo apuran). Devuelve el nodo (las pruebas lo
## buscan como "CortePresente") y emite `finished` en él.
static func present_cut(parent: Node, agent: String, total_s: float = 7.5) -> _PresentCut:
	var c := _PresentCut.new()
	c.name = "CortePresente"
	c.agent = agent
	c.total_s = total_s
	parent.add_child(c)
	return c


class _PresentCut extends CanvasLayer:
	signal finished()
	var agent: String = ""
	var total_s: float = 7.5
	var t: float = 0.0
	var done: bool = false
	var _title: Control = null
	var _pair: Control = null

	func _ready() -> void:
		layer = 60
		process_mode = Node.PROCESS_MODE_ALWAYS
		var bg := ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0, 0, 0)
		add_child(bg)
		var tv := VBoxContainer.new()
		tv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 12)
		add_child(tv)
		_title = tv
		var a := UITheme.label(Flashback.present_text(), 40, Color(0.86, 0.9, 0.92), true)
		a.name = "Presente"
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		tv.add_child(a)
		var b := UITheme.label("— " + Flashback.later_text(agent), 24, Color(0.6, 0.66, 0.7), false)
		b.name = "Despues"
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		tv.add_child(b)
		var pair := HBoxContainer.new()
		pair.name = "Contraste"
		pair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_theme_constant_override("separation", 90)
		pair.modulate.a = 0.0
		add_child(pair)
		_pair = pair
		var left := VBoxContainer.new()
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(Flashback.fotocheck(agent, "recuerdo"))
		var ll := UITheme.label(Flashback.date_text(agent), 16, Color(1.0, 0.86, 0.62), true)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(ll)
		pair.add_child(left)
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_theme_constant_override("separation", 10)
		var mirror := PanelContainer.new()
		mirror.name = "Espejo"
		var ms := StyleBoxFlat.new()
		ms.bg_color = Color(0.12, 0.14, 0.15)
		ms.border_color = Color(0.42, 0.44, 0.42)
		ms.set_border_width_all(10)
		ms.set_content_margin_all(6)
		mirror.add_theme_stylebox_override("panel", ms)
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(300, 300)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.texture = Flashback.face(agent, "presente")
		face.modulate = Color(0.78, 0.84, 0.86)
		mirror.add_child(face)
		right.add_child(mirror)
		var small := Flashback.fotocheck(agent, "presente")
		small.scale = Vector2(0.45, 0.45)
		small.custom_minimum_size = Vector2(300, 420)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(300 * 0.45, 420 * 0.45)
		holder.add_child(small)
		right.add_child(holder)
		var rl := UITheme.label(Flashback.present_text(), 16, Color(0.6, 0.66, 0.7), true)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(rl)
		pair.add_child(right)
		AudioManager.play_sfx("tono_grave_sting", "UI")

	func _process(delta: float) -> void:
		if done:
			return
		t += delta
		var split := total_s * 0.38
		_title.modulate.a = clampf(1.0 - (t - split + 0.4) / 0.4, 0.0, 1.0) if t > split - 0.4 else 1.0
		_pair.modulate.a = clampf((t - split) / 0.6, 0.0, 1.0) * clampf((total_s - t) / 0.5, 0.0, 1.0)
		if t >= total_s:
			finish()

	func _unhandled_input(event: InputEvent) -> void:
		if done:
			return
		if (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			if t > 1.5:
				t = maxf(t, total_s - 0.4)
				get_viewport().set_input_as_handled()

	func finish() -> void:
		if done:
			return
		done = true
		finished.emit()
		queue_free()

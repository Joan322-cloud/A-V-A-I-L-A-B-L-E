class_name GfxLights
extends RefCounted
## v0.3.2 gfx · «Luz de terror» (Media/Alta): la iluminación nocturna del piso sin tocar los constructores.
##
## Los pisos se arman con Greybox.light_panel / downlight / pendant_lamp / light: omnis sin sombra que se solapan y lo
## dejan todo parejo. Este pase, sobre el piso ya armado:
##   · apaga parte de los tubos (horario nocturno: ninguno encendido a menos de `spacing` metros de otro; los que
##     parpadean por diseño quedan siempre) y les pone vidrio apagado;
##   · a cada tubo encendido le cuelga un foco hacia abajo (SpotLight3D «GfxHaz») que hace la poza de luz y proyecta
##     sombra; la omni original queda como relleno suave del techo;
##   · reparte las sombras entre los tubos más cercanos a la cámara (cupo por calidad y renderizador), con fundido;
##   · baja las luces de relleno sin luminaria visible;
##   · hace inestables unos pocos tubos (respeta «Reducir parpadeos» y la intensidad de parpadeo);
##   · lleva una luz de presencia tenue en la cámara: en lo oscuro siempre se lee el camino, la puerta y el objeto.
##
## Regla de oro: las luces nuevas son ESCLAVAS de las del juego. La energía de cada haz sale, cuadro a cuadro, de la
## energía de su omni; así el ánimo del piso (FloorBase._Mood), los parpadeos (FlickerLight), Haime, la presencia de
## Shero y los screamers (que apagan o bajan las luces del piso) siguen mandando sin saber que esto existe.
## Al salir de Media/Alta, al cambiar de piso o en el recuerdo del Training, todo vuelve a como lo dejó el piso.
##
## ZONAS (data/gfx_looks.json → pisos.<n>.lights.zonas): dirección de arte por ambiente. Cada zona es un rectángulo
## [x0, x1, z0, z1] en coordenadas del piso y puede fijar:
##   · "solo": los únicos tubos encendidos (por nombre del panel) y/o "solo_cerca": [[x, z], …] (el tubo más cercano
##     a cada punto: sirve cuando el piso rehace y renombra sus paneles); el resto se apaga. Los que parpadean por
##     diseño quedan siempre (se pueden bajar con "tenue" o, todos los de la zona, con "tenue_parpadeo");
##   · "tenue": {nombre: factor} para dejar una luminaria a media luz;
##   · "spot", "angle", "soft": energía, ángulo y caída del haz; "fill", "fill_range": relleno de la omni;
##   · "room_k", "accent_k": las luces sin luminaria de esa zona; "off_glow": brillo residual de los tubos apagados
##     (siguen contándose a oscuras: «un panel más»);
##   · "extras": luces de apoyo ESCLAVAS de una luz del juego ("de": su nombre): el derrame de una sala por su
##     vidrio, el filo rojo del REC… Si el juego baja o apaga esa luz (la sesión de Haime), la extra la sigue;
##   · "sigue": true → la luz de presencia y las de práctica de esa zona también siguen a las luces del juego de la
##     zona (un apagón de guion deja la sala de verdad a oscuras);
##   · "presence": factor de la luz de presencia con la cámara dentro de la zona (una sala chica con su propia luz no
##     la necesita entera: aplana las paredes cercanas);
##   · "rotulos": factor de brillo de los rótulos blancos (Label3D sin sombreado: de noche son lo más claro del
##     cuadro) y "tinte": {nombre de nodo: factor} sobre el color de su material propio. Se devuelven al salir.

const SPOT_NAME := "GfxHaz"
## Quien baja o apaga por guion las luces del piso guardando sus energías para devolverlas después (la sesión de
## Haime) entra a este grupo. El director llama gfx_lights_begin() antes de cambiar las bases de las luces (al vestir
## o desvestir el piso: cambio de calidad) y gfx_lights_end() al terminar, para que suelte y vuelva a tomar las suyas.
const SCRIPTED_GROUP := "gfx_luces_de_guion"
## Cupo de tubos con sombra según «sombras» (0..3): [Compatibilidad, Forward+].
const SHADOW_BUDGET: Array = [[0, 0], [1, 2], [2, 4], [3, 6]]
const OFF_TUBE := Color(0.46, 0.5, 0.5)

class Fixture:
	var omni: OmniLight3D = null
	var panel: MeshInstance3D = null
	var kind: String = "panel"
	var spot: SpotLight3D = null
	var lit: bool = true
	var flicker: FlickerLight = null
	var e0: float = 1.0          # energía original de la omni
	var e1: float = 1.0          # energía base rediseñada de la omni (relleno)
	var range0: float = 7.0
	var spot_e: float = 0.0      # energía del haz con la omni en su base
	var unstable: bool = false
	var phase: float = 0.0
	var stutter_t: float = 0.0   # tiempo hasta el próximo tartamudeo
	var stutter_left: float = 0.0
	var mat: StandardMaterial3D = null   # material propio del tubo (inestable)
	var mat0: Material = null            # material que tenía el tubo
	var mat_set: bool = false
	var shadow_w: float = 0.0
	var shadow_on: bool = false
	var pos: Vector3 = Vector3.ZERO
	var pool: float = 3.0        # radio de la poza en el suelo (m)
	var was_visible: bool = true
	var zone: int = -1           # índice de su zona (−1 = ninguna)


var floor_node: Node = null
var fixtures: Array[Fixture] = []
var _by_omni: Dictionary = {}     # id de la omni → Fixture
var _others: Array = []           # [luz, energía original] de las luces de relleno reescaladas
var _cfg: Dictionary = {}
var active: bool = false
var presence: OmniLight3D = null
var emergency: float = 0.0        # 0..1 suavizado
var emergency_target: float = 0.0
var _blackout_left: float = 0.0   # apagón de guion: segundos que quedan
var _blackout_k: float = 1.0      # y a cuánto quedan los tubos mientras dura (0 = negro)
var local_light: float = 0.5
## Bolsa de luces de práctica: unas pocas omnis frías que se mudan a las pantallas encendidas más cercanas (los
## monitores iluminan caras y escritorios sin poner una luz por monitor). Tamaño: _pool_size().
var pool: Array[OmniLight3D] = []
var pool_points: Array[Vector3] = []
## Por punto: [color, energía, alcance]. Sin entrada = pantalla de monitor (azulada, 0,42, 2,2 m).
var pool_specs: Array = []
const POOL_DEFAULT: Array = [Color(0.52, 0.68, 1.0), 0.42, 2.2]
## Haces falsos (sin niebla volumétrica): un MultiMesh con un tronco de pirámide por tubo encendido.
const BEAM_SHADER := "res://assets/shaders/gfx_haz.gdshader"
var _beams: MultiMeshInstance3D = null
var _beam_fx: Array[Fixture] = []
var _beam_k: PackedFloat32Array = PackedFloat32Array()
var _pool_at: Array[int] = []       # índice del punto que ilumina cada luz (−1 = libre)
var _pool_next: Array[int] = []     # punto al que se mudará cuando se apague (−1 = ninguno, −2 = solo apagarse)
var _pool_e: Array[float] = []
var _pool_t: float = 0.0
var _budget_t: float = 0.0
var _local_t: float = 0.0
var _time: float = 0.0
var _rescan_count: int = -1
var stats: Dictionary = {}
var _zones: Array = []            # zonas del piso (diccionarios de gfx_looks.json)
var _zone_k: PackedFloat32Array = PackedFloat32Array()   # por zona: cuánto queda de sus luces del juego (0..1)
## Lo mismo, pero por la energía de BASE de cada luz (lo que el guion la bajó), sin el parpadeo del momento ni el ánimo.
var _zone_base_k: PackedFloat32Array = PackedFloat32Array()
## Luces extra de las zonas: [luz, Fixture o null, luz del juego o null, base de referencia, energía, zona, sigue_min].
var _extras: Array = []
var _pool_zone: Array[int] = []   # zona del punto que ilumina cada luz de la bolsa
var _tweaks: Array = []           # [objeto, propiedad, valor original] de rótulos y tintes de zona
## Se pone en true cuando aparecieron o desaparecieron luminarias (el director rehace la capa de detalle).
var rescanned: bool = false


## Marca «gfx_fx» de las luces DEL JUEGO que el paquete rediseña (tipo de luminaria o de relleno; ver _classify).
## Cualquier otra marca es de una luz que el paquete añadió.
const GAME_KINDS: Array[String] = ["panel", "down", "pendant", "difusor", "room", "accent"]

## ¿Esta luz la AÑADIÓ el paquete? (Haces de los tubos, luces extra de zona, presencia, luces de práctica, halos de
## los carteles de salida y luminarias de emergencia: ninguna es del piso.) Quien administra las luces de una sala por guion —la sesión de Haime— debe
## saltarlas: bajar o «matar» una de estas no hace nada (el paquete le vuelve a escribir la energía cada cuadro) y le
## quita el turno a la luz de verdad.
static func is_added(l: Light3D) -> bool:
	return l != null and l.has_meta("gfx_fx") and not (str(l.get_meta("gfx_fx", "")) in GAME_KINDS)


# --- aplicar / devolver ------------------------------------------------------------------------------------------

func apply(p_floor: Node, look: Dictionary, host: Node) -> void:
	var want := GfxSettings.enhanced() and GfxSettings.on("luz_terror") and p_floor != null and is_instance_valid(p_floor) \
		and bool((look.get("lights", {}) as Dictionary).get("enabled", true))
	if p_floor != floor_node or not want:
		restore()
	floor_node = p_floor
	_cfg = look.get("lights", {}) if want else {}
	var zs: Variant = _cfg.get("zonas", [])
	_zones = zs if zs is Array else []
	_zone_k.resize(_zones.size())
	_zone_k.fill(1.0)
	_zone_base_k.resize(_zones.size())
	_zone_base_k.fill(1.0)
	_ensure_presence(host, want)
	if not want:
		return
	active = true
	for fx in fixtures:
		if fx.lit and is_instance_valid(fx.omni):
			fx.omni.shadow_enabled = false  # la sombra la da su haz (GfxQuality se la devuelve en cada pase)
	_scan()
	_zone_paint()
	_apply_shadow_quality()
	_ensure_pool(host)
	_ensure_beams()


## Devuelve cada luz del piso a como la dejó el constructor y borra lo añadido.
func restore() -> void:
	for fx in fixtures:
		if not is_instance_valid(fx.omni):
			continue
		_set_omni_base(fx, fx.e0)
		fx.omni.omni_range = fx.range0
		if fx.omni.has_meta("gfx_off"):
			fx.omni.remove_meta("gfx_off")
			fx.omni.visible = fx.was_visible
		fx.omni.remove_meta("gfx_fx")
		if is_instance_valid(fx.spot):
			fx.spot.queue_free()
		if fx.mat_set and is_instance_valid(fx.panel):
			fx.panel.material_override = fx.mat0
	for pair in _others:
		var l: Variant = pair[0]
		if is_instance_valid(l):
			_set_plain_base(l as Light3D, float(pair[1]))
			(l as Light3D).remove_meta("gfx_fx")
	if is_instance_valid(_beams):
		_beams.queue_free()
	_beams = null
	_beam_fx.clear()
	for ex in _extras:
		if is_instance_valid(ex[0]):
			(ex[0] as Node).queue_free()
	_extras.clear()
	for tw in _tweaks:
		if is_instance_valid(tw[0]):
			(tw[0] as Object).set(str(tw[1]), tw[2])
	_tweaks.clear()
	fixtures.clear()
	_by_omni.clear()
	_others.clear()
	for l in pool:
		if is_instance_valid(l):
			l.queue_free()
	pool.clear()
	_pool_at.clear()
	_pool_next.clear()
	_pool_e.clear()
	_pool_zone.clear()
	pool_points = []
	pool_specs = []
	active = false
	emergency = 0.0
	emergency_target = 0.0
	_blackout_left = 0.0
	_rescan_count = -1


## Una omni de luminaria: cambia su energía base respetando al ánimo del piso y a su parpadeo.
func _set_omni_base(fx: Fixture, base: float) -> void:
	var l := fx.omni
	var old := fx.flicker.base_energy if is_instance_valid(fx.flicker) else float(l.get_meta("mood_base", l.light_energy))
	if is_instance_valid(fx.flicker):
		fx.flicker.base_energy = base
	if l.has_meta("mood_base") or not is_instance_valid(fx.flicker):
		l.set_meta("mood_base", base)
	# La energía de ahora conserva su proporción (ánimo, apagón, screamer en curso…).
	l.light_energy = l.light_energy * (base / old) if old > 0.0001 else base * FlickerLight.mood


func _set_plain_base(l: Light3D, base: float) -> void:
	var old := float(l.get_meta("mood_base", l.light_energy))
	l.set_meta("mood_base", base)
	l.light_energy = l.light_energy * (base / old) if old > 0.0001 else base * FlickerLight.mood


## Energía de diseño (la del piso, antes del rediseño nocturno) de una luz del juego; −1 si el paquete no la tocó.
func design_energy(l: Light3D) -> float:
	if not active or l == null:
		return -1.0
	for pair in _others:
		if pair[0] == l:
			return float(pair[1])
	var fx: Fixture = _by_omni.get(l.get_instance_id())
	return fx.e0 if fx != null else -1.0


## Valor de una clave de la zona de un punto del mundo (p. ej. "rojo_guion"); `fallback` fuera de toda zona o sin
## luz nocturna.
func zone_value(p: Vector3, key: String, fallback: float) -> float:
	if not active:
		return fallback
	return float(_zone(_zone_at(p)).get(key, fallback))


## Zona de un punto del mundo (índice en _zones; −1 = ninguna). La primera que lo contiene manda.
func _zone_at(p: Vector3) -> int:
	if _zones.is_empty() or not is_instance_valid(floor_node) or not (floor_node is Node3D):
		return -1
	var q := (floor_node as Node3D).to_local(p)
	for i in _zones.size():
		var r: Variant = (_zones[i] as Dictionary).get("rect")
		if r is Array and (r as Array).size() == 4 and q.x >= float(r[0]) and q.x <= float(r[1]) and q.z >= float(r[2]) and q.z <= float(r[3]):
			return i
	return -1


func _zone(i: int) -> Dictionary:
	return _zones[i] if (i >= 0 and i < _zones.size()) else {}


## Valor de una clave para una luminaria: el de su zona si lo trae; si no, el del piso.
func _zf(fx: Fixture, key: String, base: float) -> float:
	return float(_zone(fx.zone).get(key, base))


## Busca luminarias nuevas en el piso (al cargarlo y cuando aparece una: «un panel más», el recuerdo…).
func _scan() -> void:
	if floor_node == null or not is_instance_valid(floor_node):
		return
	# Las que ya no existen (el piso rehízo sus paneles) se olvidan: no cuentan para el horario nocturno.
	var alive: Array[Fixture] = []
	for old in fixtures:
		if is_instance_valid(old.omni):
			alive.append(old)
		else:
			if is_instance_valid(old.spot):
				old.spot.queue_free()
			rescanned = true
	if alive.size() != fixtures.size():
		fixtures = alive
		_by_omni.clear()
		for a in fixtures:
			_by_omni[a.omni.get_instance_id()] = a
		for ex in _extras:   # sus luces de referencia pudieron irse con los paneles: se vuelven a crear abajo
			if is_instance_valid(ex[0]):
				(ex[0] as Node).queue_free()
		_extras.clear()
	var found: Array[Fixture] = []
	# Difusores de techo (cuadro emisivo «Difusor…») cuya luz es una omni suelta justo debajo: también son luminarias.
	var diffusers: Array[MeshInstance3D] = []
	for n0 in floor_node.find_children("Difusor*", "MeshInstance3D", true, false):
		var dm := n0 as MeshInstance3D
		if dm.mesh is BoxMesh and (dm.mesh as BoxMesh).size.y < 0.08 and dm.is_visible_in_tree():
			diffusers.append(dm)
	for n in floor_node.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if l.has_meta("gfx_fx") or l.has_meta("gfx_skip") or l.name == "GfxPresencia":
			continue
		var kind := _classify(l)
		if kind == "":
			continue
		var holder := l.get_parent() as MeshInstance3D
		if kind == "room" or kind == "accent":
			var lp := l.global_position
			for dm2 in diffusers:
				var dp := dm2.global_position
				if absf(dp.x - lp.x) < 0.25 and absf(dp.z - lp.z) < 0.25 and dp.y - lp.y > 0.0 and dp.y - lp.y < 0.7:
					kind = "difusor"
					holder = dm2
					break
		if kind == "room" or kind == "accent":
			var zi := _zone_at(l.global_position)
			var key := "room_k" if kind == "room" else "accent_k"
			var k := float(_zone(zi).get(key, _cfg.get(key, 0.5 if kind == "room" else 0.9)))
			l.set_meta("gfx_fx", kind)
			var e0 := float(l.get_meta("mood_base", l.light_energy))
			_others.append([l, e0, zi, e0 * k])
			_set_plain_base(l, e0 * k)
			continue
		var fx := Fixture.new()
		fx.omni = l
		fx.kind = kind
		fx.panel = holder
		for c in fx.panel.get_children():
			if c is FlickerLight:
				fx.flicker = c as FlickerLight
		fx.e0 = fx.flicker.base_energy if fx.flicker != null else float(l.get_meta("mood_base", l.light_energy))
		fx.range0 = l.omni_range
		fx.pos = l.global_position
		fx.was_visible = l.visible
		fx.phase = float(absi(str(fx.panel.name).hash()) % 1000) * 0.0063
		fx.zone = _zone_at(fx.pos)
		l.set_meta("gfx_fx", kind)
		found.append(fx)
	if not found.is_empty():
		_thin(found)
		for fx in found:
			_dress(fx)
			fixtures.append(fx)
			_by_omni[fx.omni.get_instance_id()] = fx
		rescanned = true
	_ensure_extras()
	_rescan_count = floor_node.find_children("*", "OmniLight3D", true, false).size()
	_count()


## Tipo de una omni del piso: "panel" (tubo de techo), "down" (downlight empotrado), "pendant" (campana colgante),
## "difusor" (cuadro emisivo de techo con su omni suelta debajo; lo decide _scan y se trata como un tubo),
## "room" (relleno blanco sin luminaria), "accent" (color / corto alcance) o "" (no se toca: es de un objeto con
## guion propio —microondas, refri, monitor, C-17, personajes— y ese guion le escribe la energía).
func _classify(l: OmniLight3D) -> String:
	var p := l.get_parent()
	if p is MeshInstance3D:
		var mi := p as MeshInstance3D
		if mi.mesh is BoxMesh and mi.get_node_or_null("Borde") != null:
			return "panel"
		if mi.mesh is CylinderMesh:
			var cm := mi.mesh as CylinderMesh
			if absf(cm.bottom_radius - 0.09) < 0.005 and cm.height < 0.05:
				return "down"
			if absf(cm.bottom_radius - 0.22) < 0.01 and absf(cm.top_radius - 0.06) < 0.01:
				return "pendant"
		return ""
	if p == floor_node or p is Bathroom:
		if l.get_script() != null or l.has_meta("no_mood") or not l.visible or l.light_energy <= 0.01:
			return ""  # relámpago, lámpara de C-17, luces de guion: su dueño les escribe la energía
		var c := l.light_color
		var white := c.s < 0.32
		# Por su energía de BASE (v0.3.2-final): la del momento baja con el ánimo del piso, y al volver a vestir el piso
		# con la tensión alta (cambiar de calidad a mitad de turno) un relleno de 0,7 pasaba por luz de acento.
		if white and l.omni_range >= 4.4 and float(l.get_meta("mood_base", l.light_energy)) >= 0.5:
			return "room"
		return "accent"
	return ""


## Horario nocturno: ningún tubo encendido a menos de `spacing` m de otro. Primero los que parpadean por diseño.
func _thin(found: Array[Fixture]) -> void:
	var spacing := float(_cfg.get("spacing", 6.4))
	var panels: Array[Fixture] = []
	for fx in found:
		if fx.kind == "panel" or fx.kind == "difusor":
			panels.append(fx)
	panels.sort_custom(func(a: Fixture, b: Fixture) -> bool:
		var fa := 0 if a.flicker != null else 1
		var fb := 0 if b.flicker != null else 1
		if fa != fb:
			return fa < fb
		return str(a.panel.get_path()) < str(b.panel.get_path()))
	var lit_pos: Array[Vector3] = []
	for fx in fixtures:  # las ya encendidas de antes cuentan (un panel nuevo no se enciende pegado a otro)
		if (fx.kind == "panel" or fx.kind == "difusor") and fx.lit:
			lit_pos.append(fx.pos)
	# Tubos elegidos por posición ("solo_cerca": el más cercano a cada punto [x, z] del piso).
	var keep: Dictionary = {}
	for zi in _zones.size():
		var pts: Variant = (_zones[zi] as Dictionary).get("solo_cerca", [])
		if not (pts is Array) or not (floor_node is Node3D):
			continue
		for pt in (pts as Array):
			if not (pt is Array) or (pt as Array).size() != 2:
				continue
			var best: Fixture = null
			var best_d := 1.0e9
			for fx in found:
				if fx.zone != zi or fx.flicker != null:
					continue
				var q := (floor_node as Node3D).to_local(fx.pos)
				var d := Vector2(q.x - float(pt[0]), q.z - float(pt[1])).length_squared()
				if d < best_d:
					best_d = d
					best = fx
			if best != null:
				keep[best.get_instance_id()] = true
	for fx in panels:
		var ok := true
		var z := _zone(fx.zone)
		if z.has("solo") or z.has("solo_cerca"):
			# Dirección de arte de la zona: solo los tubos elegidos (y los que parpadean por diseño).
			ok = fx.flicker != null or keep.has(fx.get_instance_id()) or (z.get("solo", []) as Array).has(str(fx.panel.name))
		else:
			var sp := float(z.get("spacing", spacing))
			if sp > 0.0 and fx.flicker == null:
				for q in lit_pos:
					if absf(q.y - fx.pos.y) < 1.5 and Vector2(q.x - fx.pos.x, q.z - fx.pos.z).length() < sp:
						ok = false
						break
		fx.lit = ok and fx.was_visible
		if fx.lit:
			lit_pos.append(fx.pos)
	# Downlights y campanas: solo se apagan si su zona los deja fuera de "solo".
	for fx in found:
		if fx.kind != "panel" and fx.kind != "difusor":
			var z2 := _zone(fx.zone)
			if (z2.has("solo") or z2.has("solo_cerca")) and fx.flicker == null and not keep.has(fx.get_instance_id()) \
					and not (z2.get("solo", []) as Array).has(str(fx.panel.name)):
				fx.lit = false


## Viste una luminaria: haz hacia abajo si está encendida; vidrio apagado si no.
func _dress(fx: Fixture) -> void:
	var l := fx.omni
	if not fx.lit:
		l.set_meta("gfx_off", true)
		l.visible = false
		if (fx.kind == "panel" or fx.kind == "difusor") and is_instance_valid(fx.panel) and fx.flicker == null:
			fx.mat0 = fx.panel.material_override
			fx.mat_set = true
			var glow := _zf(fx, "off_glow", float(_cfg.get("off_glow", 0.0)))
			fx.panel.material_override = Greybox.material(OFF_TUBE, snappedf(glow, 0.05), 0.25)
		return
	var h := _height_above_floor(fx)
	var spot := SpotLight3D.new()
	spot.name = SPOT_NAME
	spot.set_meta("gfx_fx", "haz")
	spot.set_meta("no_mood", true)
	spot.set_meta("budget_keep", true)
	spot.set_meta("shadow_design", false)  # GfxQuality no le toca las sombras: las reparte el cupo de aquí
	spot.rotation_degrees.x = -90.0
	spot.light_color = l.light_color
	spot.light_specular = 0.4
	spot.shadow_enabled = false
	spot.shadow_bias = 0.05
	spot.shadow_normal_bias = 1.4
	spot.shadow_blur = 2.0
	spot.shadow_opacity = 0.0
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 36.0
	spot.distance_fade_length = 8.0
	spot.distance_fade_shadow = 26.0
	spot.light_volumetric_fog_energy = float(_cfg.get("vol_energy", 2.0))
	var fill := 0.3
	match fx.kind:
		"down":
			spot.position = Vector3(0, -0.03, 0)
			spot.spot_angle = 46.0
			spot.spot_angle_attenuation = 0.8
			spot.spot_range = maxf(h * 2.2, 5.0)
			fx.spot_e = float(_cfg.get("down_spot", 2.2)) * fx.e0
			fill = float(_cfg.get("down_fill", 0.3))
		"pendant":
			spot.position = Vector3(0, -0.14, 0)
			spot.spot_angle = 62.0
			spot.spot_angle_attenuation = 0.8
			spot.spot_range = maxf(h * 2.6, 5.0)
			fx.spot_e = float(_cfg.get("down_spot", 2.2)) * 1.1 * fx.e0
			fill = float(_cfg.get("down_fill", 0.3))
		_:
			spot.position = Vector3(0, -0.07, 0)
			spot.spot_angle = _zf(fx, "angle", float(_cfg.get("panel_angle", 62.0)))
			spot.spot_angle_attenuation = _zf(fx, "soft", float(_cfg.get("panel_soft", 1.7)))
			spot.spot_range = maxf(h * 2.5, 6.5)
			fx.spot_e = float(_cfg.get("panel_spot", 3.0)) * fx.e0
			fill = float(_cfg.get("panel_fill", 0.22))
	# Zona: energía del haz, relleno y media luz de esta luminaria.
	var zd := _zone(fx.zone)
	var dim := float((zd.get("tenue", {}) as Dictionary).get(str(fx.panel.name), 1.0)) if zd.get("tenue", {}) is Dictionary else 1.0
	if fx.flicker != null and is_equal_approx(dim, 1.0):
		dim = float(zd.get("tenue_parpadeo", 1.0))
	fx.spot_e *= float(zd.get("spot", 1.0)) * dim
	fill *= float(zd.get("fill", 1.0)) * dim
	if zd.has("fill_range"):
		l.omni_range = float(zd["fill_range"])
	spot.spot_attenuation = 1.0
	spot.light_energy = 0.0
	fx.pool = maxf(h, 1.0) * tan(deg_to_rad(minf(spot.spot_angle, 70.0))) * 0.55
	fx.panel.add_child(spot)
	fx.spot = spot
	if not GfxSettings.forward():
		fill *= float(_cfg.get("compat_fill", 1.8))  # sin luz indirecta en pantalla, el relleno hace de rebote
	fx.e1 = fx.e0 * minf(fill, 1.0)
	_set_omni_base(fx, fx.e1)
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.25
	# Unos pocos tubos, inestables (nunca los que ya parpadean por diseño).
	if fx.kind == "panel" and fx.flicker == null:
		var frac := float(_cfg.get("unstable", 0.12))
		fx.unstable = frac > 0.0 and float(absi(str(fx.panel.name).hash()) % 100) < frac * 100.0
		if fx.unstable and fx.panel.material_override is StandardMaterial3D:
			fx.mat0 = fx.panel.material_override
			fx.mat = (fx.panel.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			fx.panel.material_override = fx.mat
			fx.mat_set = true
			fx.stutter_t = 6.0 + fmod(fx.phase * 37.0, 14.0)


## Alto de la luminaria sobre el suelo del piso.
func _height_above_floor(fx: Fixture) -> float:
	var base := 0.0
	if floor_node is FloorBase:
		base = (floor_node as FloorBase).base_y + (floor_node as Node3D).global_position.y
	elif floor_node is Node3D:
		base = (floor_node as Node3D).global_position.y
	var h := fx.pos.y - base
	return clampf(h, 2.0, 6.0) if h > 0.5 else 2.7


func _apply_shadow_quality() -> void:
	if GfxSettings.headless():
		return
	var s := GfxSettings.level("sombras")
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if s >= 3 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if s == 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)


func _count() -> void:
	var lit := 0
	var off := 0
	for fx in fixtures:
		if fx.lit:
			lit += 1
		else:
			off += 1
	stats = {"luminarias": fixtures.size(), "encendidas": lit, "apagadas": off, "relleno": _others.size(), "bolsa": pool.size(), "haces": _beam_fx.size(), "zonas": _zones.size(), "extras": _extras.size()}


# --- rótulos y tintes de zona ----------------------------------------------------------------------------------

## En una zona a oscuras lo más claro no debe ser la pintura: baja el brillo de los rótulos blancos (que no reciben
## luz: Label3D sin sombreado) y el color de los materiales propios que la zona nombre. Una vez por piso; restore()
## lo devuelve.
func _zone_paint() -> void:
	if not _tweaks.is_empty() or _zones.is_empty() or not (floor_node is Node3D):
		return
	var labels: Array = []
	var any_labels := false
	for z in _zones:
		if float((z as Dictionary).get("rotulos", 1.0)) < 0.999:
			any_labels = true
	if any_labels:
		labels = floor_node.find_children("*", "Label3D", true, false)
	for n in labels:
		var lb := n as Label3D
		var k := float(_zone(_zone_at(lb.global_position)).get("rotulos", 1.0))
		if k >= 0.999 or lb.shaded:
			continue
		var c := lb.outline_modulate if (lb.outline_size > 0 and lb.modulate.a < 0.5) else lb.modulate
		if c.s > 0.3 or c.v < 0.55:
			continue  # texto de color (REC, salida, avisos): es luminoso o ya es oscuro
		_tweaks.append([lb, "modulate", lb.modulate])
		_tweaks.append([lb, "outline_modulate", lb.outline_modulate])
		lb.modulate = Color(lb.modulate.r * k, lb.modulate.g * k, lb.modulate.b * k, lb.modulate.a)
		lb.outline_modulate = Color(lb.outline_modulate.r * k, lb.outline_modulate.g * k, lb.outline_modulate.b * k, lb.outline_modulate.a)
	for z2 in _zones:
		var tint: Variant = (z2 as Dictionary).get("tinte", {})
		if not (tint is Dictionary):
			continue
		for nm in (tint as Dictionary).keys():
			var node := floor_node.find_child(str(nm), true, false) as GeometryInstance3D
			var mat := (node.material_override as StandardMaterial3D) if node != null else null
			if mat == null:
				continue
			var f := float((tint as Dictionary)[nm])
			_tweaks.append([mat, "albedo_color", mat.albedo_color])
			mat.albedo_color = Color(mat.albedo_color.r * f, mat.albedo_color.g * f, mat.albedo_color.b * f, mat.albedo_color.a)


# --- luces extra de las zonas (esclavas de una luz del juego) -----------------------------------------------

func _ensure_extras() -> void:
	if not _extras.is_empty() or _zones.is_empty() or not (floor_node is Node3D):
		return
	for zi in _zones.size():
		var list: Variant = (_zones[zi] as Dictionary).get("extras", [])
		if not (list is Array):
			continue
		for item in (list as Array):
			if not (item is Dictionary):
				continue
			var d := item as Dictionary
			var src := floor_node.find_child(str(d.get("de", "")), true, false)
			if src == null:
				continue
			var fx: Fixture = null
			var ref: Light3D = null
			var base := 1.0
			if src is Light3D:
				ref = src as Light3D
				base = float(ref.get_meta("mood_base", ref.light_energy))
			else:
				for f in fixtures:
					if f.panel == src:
						fx = f
			if (fx == null and ref == null) or base <= 0.0001:
				continue
			var pos := _v3(d.get("pos"), Vector3.ZERO)
			var col := _v3(d.get("color"), Vector3.ONE)
			var l: Light3D = null
			if str(d.get("tipo", "omni")) == "spot":
				var sp := SpotLight3D.new()
				sp.spot_range = float(d.get("range", 6.0))
				sp.spot_angle = float(d.get("angle", 40.0))
				sp.spot_angle_attenuation = float(d.get("soft", 1.2))
				sp.spot_attenuation = 1.0
				l = sp
			else:
				var om := OmniLight3D.new()
				om.omni_range = float(d.get("range", 2.0))
				om.omni_attenuation = float(d.get("att", 1.3))
				l = om
			l.name = "GfxExtra%d" % _extras.size()
			l.set_meta("gfx_fx", "haz")
			l.set_meta("no_mood", true)
			l.set_meta("budget_keep", true)
			l.set_meta("shadow_design", false)
			l.light_color = Color(col.x, col.y, col.z)
			l.light_specular = float(d.get("specular", 0.3))
			l.shadow_enabled = false
			l.light_volumetric_fog_energy = 1.0
			l.light_energy = 0.0
			floor_node.add_child(l)
			l.position = pos
			if l is SpotLight3D:
				var fl3 := floor_node as Node3D
				var gp := fl3.to_global(pos)
				var gt := fl3.to_global(_v3(d.get("hacia"), pos + Vector3.DOWN))
				if not gt.is_equal_approx(gp):
					var up := Vector3.UP if absf((gt - gp).normalized().y) < 0.98 else Vector3.FORWARD
					l.look_at_from_position(gp, gt, up)
			_extras.append([l, fx, ref, base, float(d.get("energy", 1.0)), zi, float(d.get("sigue_min", 1.0))])


static func _v3(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


## Cada extra sigue a su luz del juego; y por zona se anota cuánto queda de las luces del juego (para "sigue").
func _tick_zones(em_k: float) -> void:
	for ex in _extras:
		var l: Variant = ex[0]
		if not is_instance_valid(l):
			continue
		var ratio := 0.0
		var fx: Fixture = ex[1]
		if fx != null:
			if fx.lit and is_instance_valid(fx.omni) and fx.omni.visible and fx.e1 > 0.0001:
				ratio = fx.omni.light_energy / fx.e1
		elif is_instance_valid(ex[2]):
			var r := ex[2] as Light3D
			if r.visible:
				ratio = r.light_energy / float(ex[3])
		# "sigue_min" < 1: además baja con la luz blanca que queda en su zona, hasta esa fracción (el filo rojo del REC
		# se pensó contra el haz del tubo: con la sala a oscuras, entero, sería la luz principal).
		# Por la energía de base de las luces de la zona (lo que el guion las bajó), no por el parpadeo del momento.
		var zb := int(ex[5])
		var base_k := _zone_base_k[zb] if (zb >= 0 and zb < _zone_base_k.size()) else 1.0
		var dim_k := lerpf(float(ex[6]), 1.0, base_k) if float(ex[6]) < 0.999 else 1.0
		(l as Light3D).light_energy = float(ex[4]) * clampf(ratio, 0.0, 1.5) * em_k * dim_k
		(l as Light3D).visible = ratio > 0.002
	if _zone_k.is_empty():
		return
	var mood := maxf(FlickerLight.mood, 0.001)
	for zi in _zones.size():
		if not bool((_zones[zi] as Dictionary).get("sigue", false)):
			continue
		var k := 1.0
		var kb := 1.0
		var any := false
		for fx2 in fixtures:
			if fx2.zone == zi and fx2.lit and is_instance_valid(fx2.omni) and fx2.e1 > 0.0001:
				any = true
				k = minf(k, (fx2.omni.light_energy / fx2.e1 / mood) if fx2.omni.visible else 0.0)
				var b2 := fx2.flicker.base_energy if is_instance_valid(fx2.flicker) else float(fx2.omni.get_meta("mood_base", fx2.omni.light_energy / mood))
				kb = minf(kb, (b2 / fx2.e1) if fx2.omni.visible else 0.0)
		for pair in _others:
			if int(pair[2]) == zi and is_instance_valid(pair[0]) and float(pair[3]) > 0.0001:
				any = true
				var pl := pair[0] as Light3D
				k = minf(k, (pl.light_energy / float(pair[3]) / mood) if pl.visible else 0.0)
				# (El relleno no cuenta para la base: la sesión puede pedirlo en absoluto, por encima de su nivel de reposo.)
		_zone_k[zi] = clampf(k, 0.0, 1.0) if any else 1.0
		_zone_base_k[zi] = clampf(kb, 0.0, 1.0) if any else 1.0


## Cuánto deja pasar la zona de un punto (1 fuera de las zonas con "sigue").
func _zone_follow(zi: int) -> float:
	return _zone_k[zi] if (zi >= 0 and zi < _zone_k.size()) else 1.0


# --- luz de presencia ---------------------------------------------------------------------------------------------

func _ensure_presence(host: Node, want: bool) -> void:
	var e := float(_cfg.get("presence", 0.16)) if want else 0.0
	if not want or e <= 0.0:
		if is_instance_valid(presence):
			presence.queue_free()
		presence = null
		return
	if not is_instance_valid(presence):
		presence = OmniLight3D.new()
		presence.name = "GfxPresencia"
		presence.set_meta("gfx_fx", "presencia")
		presence.set_meta("no_mood", true)
		presence.set_meta("budget_keep", true)
		presence.set_meta("shadow_design", false)
		presence.light_color = Color(0.78, 0.86, 0.92)
		presence.omni_range = 5.0
		presence.omni_attenuation = 1.25
		presence.light_specular = 0.0
		presence.shadow_enabled = false
		presence.light_volumetric_fog_energy = 0.0
		presence.light_energy = 0.0
		host.add_child(presence)


# --- bolsa de luces de práctica (pantallas) ------------------------------------------------------------------

func _pool_size() -> int:
	var hi := GfxQuality.level() == "alta"
	if GfxSettings.forward():
		return 16 if hi else 8
	return 6 if hi else 4


func _ensure_pool(host: Node) -> void:
	var n := _pool_size()
	while pool.size() > n:
		var l: OmniLight3D = pool.pop_back()
		if is_instance_valid(l):
			l.queue_free()
		_pool_at.pop_back()
		_pool_next.pop_back()
		_pool_e.pop_back()
		_pool_zone.pop_back()
	while pool.size() < n:
		var l2 := OmniLight3D.new()
		l2.name = "GfxPantalla%d" % pool.size()
		l2.set_meta("gfx_fx", "practica")
		l2.set_meta("no_mood", true)
		l2.set_meta("budget_keep", true)
		l2.set_meta("shadow_design", false)
		l2.light_color = Color(0.52, 0.68, 1.0)
		l2.omni_range = 2.2
		l2.omni_attenuation = 1.3
		l2.light_specular = 0.3
		l2.shadow_enabled = false
		l2.light_volumetric_fog_energy = 0.5
		l2.light_energy = 0.0
		l2.visible = false
		host.add_child(l2)
		pool.append(l2)
		_pool_at.append(-1)
		_pool_next.append(-1)
		_pool_e.append(0.0)
		_pool_zone.append(-1)


## Puntos de luz de práctica del piso (pantallas encendidas, vitrina de la expendedora, pilotos…): si cambian, la
## bolsa se vacía con todo apagado y vuelve a repartirse.
func set_pool(points: Array[Vector3], specs: Array) -> void:
	var same := points.size() == pool_points.size() and (points.is_empty() or points[0].is_equal_approx(pool_points[0]))
	pool_points = points
	pool_specs = specs
	if same:
		return
	for k in pool.size():
		_pool_at[k] = -1
		_pool_next[k] = -1
		_pool_e[k] = 0.0
		if is_instance_valid(pool[k]):
			pool[k].light_energy = 0.0
			pool[k].visible = false


func _spec(i: int) -> Array:
	return pool_specs[i] if (i >= 0 and i < pool_specs.size() and pool_specs[i] is Array) else POOL_DEFAULT


## Reparte la bolsa entre las pantallas encendidas más cercanas a la cámara; las mudanzas van con fundido (la luz
## baja a cero, salta al punto nuevo y vuelve a subir: nunca se ve un salto).
func _tick_pool(delta: float, cam: Camera3D, dying: bool) -> void:
	if pool.is_empty():
		return
	_pool_t -= delta
	if _pool_t <= 0.0 and cam != null:
		_pool_t = 0.3
		var cp := cam.global_position
		var fwd := -cam.global_transform.basis.z
		var scored: Array = []
		for i in pool_points.size():
			var to := pool_points[i] - cp
			var d := to.length()
			if d > 22.0:
				continue
			var ahead := fwd.dot(to / d) if d > 0.4 else 1.0
			scored.append([d - 2.5 * ahead - (1.0 if _pool_at.has(i) else 0.0) - 3.0 * float(_spec(i)[1]), i])
		scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var wanted: Array[int] = []
		for j in mini(scored.size(), pool.size()):
			wanted.append(int(scored[j][1]))
		var free_points: Array[int] = []
		for w in wanted:
			if not _pool_at.has(w) and not _pool_next.has(w):
				free_points.append(w)
		for k in pool.size():
			if _pool_at[k] >= 0 and wanted.has(_pool_at[k]):
				_pool_next[k] = -1  # se queda donde está
				continue
			if _pool_next[k] >= 0 and wanted.has(_pool_next[k]):
				continue  # ya va camino a un punto elegido
			_pool_next[k] = free_points.pop_front() if not free_points.is_empty() else -1
			if _pool_next[k] < 0 and _pool_at[k] >= 0:
				_pool_next[k] = -2  # nada que iluminar cerca: se apaga y queda libre
	var e_on := 0.0 if dying else FlickerLight.mood
	for k in pool.size():
		var l := pool[k]
		if not is_instance_valid(l):
			continue
		var moving := _pool_next[k] != -1
		var target := 0.0 if (moving or _pool_at[k] < 0) else e_on
		_pool_e[k] = move_toward(_pool_e[k], target, delta * 3.2)
		if moving and _pool_e[k] <= 0.001:
			if _pool_next[k] >= 0 and _pool_next[k] < pool_points.size():
				_pool_at[k] = _pool_next[k]
				var sp := _spec(_pool_at[k])
				l.global_position = pool_points[_pool_at[k]]
				l.light_color = sp[0]
				l.omni_range = float(sp[2])
				_pool_zone[k] = _zone_at(pool_points[_pool_at[k]])
			else:
				_pool_at[k] = -1
			_pool_next[k] = -1
		l.light_energy = _pool_e[k] * float(_spec(_pool_at[k])[1]) * _zone_follow(_pool_zone[k])
		l.visible = _pool_e[k] > 0.002


# --- haces falsos -------------------------------------------------------------------------------------------------

## ¿Hacen falta los haces falsos? Solo con niebla ≥ 1 y sin la volumétrica de verdad.
func _want_beams() -> bool:
	var n := GfxSettings.level("niebla")
	return active and n >= 1 and not (n >= 2 and GfxSettings.forward()) and ResourceLoader.exists(BEAM_SHADER)


func _ensure_beams() -> void:
	if is_instance_valid(_beams):
		_beams.queue_free()
	_beams = null
	_beam_fx.clear()
	if not _want_beams() or floor_node == null or not (floor_node is Node3D):
		return
	var inv := (floor_node as Node3D).global_transform.affine_inverse()
	var xforms: Array = []
	var data: Array = []
	for fx in fixtures:
		if not fx.lit or fx.kind != "panel" or not is_instance_valid(fx.panel) or not is_instance_valid(fx.spot):
			continue
		var h := clampf(_height_above_floor(fx) - 0.1, 1.6, 4.2)
		var pxf := inv * fx.panel.global_transform
		xforms.append(Transform3D(pxf.basis.orthonormalized().scaled_local(Vector3(1, h, 1)), pxf.origin + Vector3(0, -0.06, 0)))
		data.append(Color(0, 0, 0, 0))
		_beam_fx.append(fx)
	if xforms.is_empty():
		return
	var mat := ShaderMaterial.new()
	mat.shader = load(BEAM_SHADER) as Shader
	var gm := GfxMesh.new()
	# Tronco de pirámide de altura 1 (la copia lo estira a la altura del tubo): boca 1,2 × 0,3 y base 2,5 × 1,7.
	var top := Vector2(0.6, 0.15)
	var bot := Vector2(1.25, 0.85)
	var c: Array[Vector3] = [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for i in 4:
		var a := c[i]
		var b := c[(i + 1) % 4]
		var p0 := Vector3(a.x * top.x, 0, a.z * top.y)
		var p1 := Vector3(b.x * top.x, 0, b.z * top.y)
		var p2 := Vector3(b.x * bot.x, -1, b.z * bot.y)
		var p3 := Vector3(a.x * bot.x, -1, a.z * bot.y)
		gm.face(mat, p0, p1, p2, p3)
	_beams = GfxMesh.make_multimesh("GfxHaces", gm.commit(), xforms, data, [], false)
	if _beams == null:
		return
	_beams.set_meta("gfx_fx", "haces")
	floor_node.add_child(_beams)
	_beam_k.resize(_beam_fx.size())
	_beam_k.fill(-1.0)


## Cada haz sigue a su tubo (parpadeo, apagón, emergencia): solo se escribe cuando cambia.
func _tick_beams() -> void:
	if not is_instance_valid(_beams):
		return
	var mm := _beams.multimesh
	for i in _beam_fx.size():
		var fx := _beam_fx[i]
		var k := 0.0
		if is_instance_valid(fx.spot) and fx.spot.visible and fx.spot_e > 0.001:
			k = clampf(fx.spot.light_energy / fx.spot_e, 0.0, 1.5)
		if absf(k - _beam_k[i]) > 0.02:
			_beam_k[i] = k
			mm.set_instance_custom_data(i, Color(k, 0, 0, 0))


## Apagón de guion: los tubos caen a `level` (0 = negro) durante `seconds` y vuelven con un tartamudeo.
func blackout(seconds: float, level: float = 0.0) -> void:
	_blackout_left = maxf(seconds, 0.0)
	_blackout_k = clampf(level, 0.0, 1.0)


# --- por cuadro ---------------------------------------------------------------------------------------------------

func tick(delta: float, cam: Camera3D, dying: bool) -> void:
	if active and not is_instance_valid(floor_node):
		# v0.3.2-final: el piso se fue sin pasar por apply() (volver al menú, Training → Lunes): hasta que el director
		# vuelva a pasar no queda nada que seguir. Antes las luces de práctica y la de presencia preguntaban la zona a un
		# piso ya liberado («previously freed instance», un error por luz y por cuadro).
		restore()
		floor_node = null
	if not active:
		if is_instance_valid(presence):
			presence.light_energy = 0.0
		return
	_time += delta
	emergency = move_toward(emergency, emergency_target, delta * 1.5)
	var flick := GfxSettings.flicker()
	var mood := FlickerLight.mood
	var em_k := 1.0 - 0.78 * emergency
	if _blackout_left > 0.0:
		_blackout_left -= delta
		# Corte seco al empezar y vuelta con un tartamudeo en el último cuarto de segundo.
		em_k *= _blackout_k if (_blackout_left > 0.25 or fmod(_blackout_left, 0.1) < 0.05) else 1.0
	for fx in fixtures:
		if not fx.lit or not is_instance_valid(fx.omni) or not is_instance_valid(fx.spot):
			continue
		var l := fx.omni
		# Proporción de la omni respecto de su base: ánimo × parpadeo × lo que le hagan los screamers.
		var ratio := (l.light_energy / fx.e1) if fx.e1 > 0.0001 else 0.0
		var k := 1.0
		if fx.unstable and flick > 0.0:
			k = _unstable_k(fx, delta, flick)
			if fx.mat != null:
				fx.mat.emission_energy_multiplier = 2.0 * k * mood
		elif fx.flicker != null and flick < 1.0 and mood > 0.001:
			# Parpadeo de diseño atenuado por la intensidad elegida: la ráfaga no baja tanto.
			var fk := clampf(ratio / mood, 0.0, 1.0)
			ratio = mood * lerpf(1.0, fk, flick)
		fx.spot.light_energy = fx.spot_e * ratio * k * em_k
		fx.spot.visible = l.visible and ratio > 0.002
	_budget_t -= delta
	if _budget_t <= 0.0:
		_budget_t = 0.2
		_assign_shadows(cam)
		_maybe_rescan()
	_fade_shadows(delta)
	_tick_beams()
	_tick_zones(em_k)
	_tick_pool(delta, cam, dying)
	_local_t -= delta
	if _local_t <= 0.0 and cam != null:
		_local_t = 0.1
		# En una zona con "sigue" (la sala de calibración) la oscuridad la pone el guion: si la sesión de Haime baja o
		# apaga las luces, el ojo NO se abre para compensar (v0.3.2-final: con la adaptación subiendo la exposición,
		# la escalera de luz de las calibraciones se aplanaba y «solo el REC» era una sala rosada, no una sala a oscuras).
		# Las luminarias de esa zona cuentan para la exposición como si estuvieran en su nivel de diseño.
		var zl := _zone_at(cam.global_position)
		var held := zl if bool(_zone(zl).get("sigue", false)) else -1
		var here := _estimate_local(cam.global_position, held)
		if here < 0.5:
			# Mirando una poza de luz desde lo oscuro el ojo no se abre del todo: sin esto la exposición sube como si
			# todo lo que se ve estuviera a oscuras y la poza de enfrente se quema.
			var fwd := -cam.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length() > 0.1:
				fwd = fwd.normalized()
				var ahead := maxf(_estimate_local(cam.global_position + fwd * 2.0, held), _estimate_local(cam.global_position + fwd * 4.0, held))
				here = maxf(here, minf(0.5, ahead * 0.9))
		local_light = here
	if is_instance_valid(presence):
		if cam != null:
			presence.global_position = cam.global_position + Vector3(0, -0.15, 0)
		var base := float(_cfg.get("presence", 0.16))
		var target := 0.0 if dying else base * lerpf(1.0, 0.35, clampf(local_light * 1.4, 0.0, 1.0))
		# En una zona con "sigue" (la sala de calibración) un apagón de guion también apaga esta luz, y al instante.
		var zc := _zone_at(cam.global_position) if cam != null else -1
		target *= float(_zone(zc).get("presence", 1.0))
		var follow := _zone_follow(zc)
		if follow < 0.999:
			presence.light_energy = minf(presence.light_energy, target * follow)
		presence.light_energy = lerpf(presence.light_energy, target * follow, clampf(delta * 3.0, 0.0, 1.0))


## Tubo inestable: respiración irregular y, cada tanto, dos tartamudeos cortos.
func _unstable_k(fx: Fixture, delta: float, flick: float) -> float:
	var t := _time + fx.phase * 9.0
	var breathe := 0.87 + 0.13 * sin(t * 11.3) * sin(t * 2.9 + fx.phase)
	var k := breathe
	fx.stutter_t -= delta
	if fx.stutter_t <= 0.0:
		fx.stutter_left = 0.42
		fx.stutter_t = 7.0 + fmod(absf(sin(t * 0.37)) * 23.0, 16.0)
	if fx.stutter_left > 0.0:
		fx.stutter_left -= delta
		var ph := fx.stutter_left
		if (ph > 0.30 and ph < 0.40) or (ph > 0.10 and ph < 0.19):
			k *= 0.12
	return lerpf(1.0, k, flick)


## Las sombras van a los tubos más cercanos (con ventaja a los que están delante y a los que ya la tienen).
func _assign_shadows(cam: Camera3D) -> void:
	var s := clampi(GfxSettings.level("sombras"), 0, 3)
	var n := int((SHADOW_BUDGET[s] as Array)[1 if GfxSettings.forward() else 0])
	if cam == null or n <= 0:
		for fx in fixtures:
			fx.shadow_on = false
		return
	var cp := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var scored: Array = []
	for fx in fixtures:
		if not fx.lit or not is_instance_valid(fx.spot) or not fx.spot.visible:
			fx.shadow_on = false
			continue
		var to := fx.pos - cp
		var d := to.length()
		var ahead := fwd.dot(to / d) if d > 0.5 else 1.0
		var score := d - 3.5 * ahead - (1.2 if fx.shadow_on else 0.0) + (2.5 if fx.kind != "panel" else 0.0)
		scored.append([score, fx])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in scored.size():
		(scored[i][1] as Fixture).shadow_on = i < n and float(scored[i][0]) < 30.0


func _fade_shadows(delta: float) -> void:
	for fx in fixtures:
		if not fx.lit or not is_instance_valid(fx.spot):
			continue
		var target := 1.0 if fx.shadow_on else 0.0
		if fx.shadow_w != target:
			fx.shadow_w = move_toward(fx.shadow_w, target, delta * 2.5)
			fx.spot.shadow_opacity = fx.shadow_w * 0.92
		# Siempre se impone: GfxQuality.apply() apaga las sombras de toda luz sin «shadow_design» en cada pase.
		var want := fx.shadow_w > 0.01
		if fx.spot.shadow_enabled != want:
			fx.spot.shadow_enabled = want


## Luminarias que aparecieron después (un panel de más, luces de una escena guionizada).
func _maybe_rescan() -> void:
	if floor_node == null or not is_instance_valid(floor_node):
		return
	var n := floor_node.find_children("*", "OmniLight3D", true, false).size()
	if n != _rescan_count:
		_rescan_count = n
		var before := fixtures.size()
		_scan()
		if rescanned or fixtures.size() != before:
			_ensure_beams()


## Estimación barata de la luz en un punto (0 = lejos de toda poza, 1 = bajo un tubo encendido).
## `design_zone`: las luminarias de esa zona cuentan a su nivel de diseño (aunque el guion las tenga bajas o apagadas).
func _estimate_local(p: Vector3, design_zone: int = -1) -> float:
	var acc := 0.0
	for fx in fixtures:
		if not fx.lit or not is_instance_valid(fx.spot) or fx.spot_e <= 0.0:
			continue
		if absf(fx.pos.y - p.y) > 4.5:
			continue
		var d := Vector2(fx.pos.x - p.x, fx.pos.z - p.z).length()
		var w := 1.0 - smoothstep(fx.pool * 0.35, fx.pool * 1.25, d)
		if w > 0.0:
			acc += w * (1.0 if (design_zone >= 0 and fx.zone == design_zone) else clampf(fx.spot.light_energy / fx.spot_e, 0.0, 1.0))
	if fixtures.is_empty():
		return 0.5
	return clampf(acc, 0.0, 1.6)   # > 1 = bajo varios tubos a la vez (salas chicas y blancas): la exposición baja algo más


func set_emergency(on: bool) -> void:
	emergency_target = 1.0 if on else 0.0

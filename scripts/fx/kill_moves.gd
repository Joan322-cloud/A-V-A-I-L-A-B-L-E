class_name KillMoves
extends RefCounted
## Muertes propias (v0.3.1, pedido de Joan: «todos los enemigos tienen la misma animación de manos para matarte…
## haz una personalizada dependiendo la muerte»). Cada fila de data/screamers.json lleva "kill" (y "kill_alcance"
## para cuando te alcanza en una persecución, Vitzo de pie): la INTRO sigue siendo la de la fila (_i_<intro> de
## fx/screamers.gd); desde el instante del agarre (t_agarre) esta clase hace el AGARRE, la ACCIÓN y el FINAL
## propios de esa muerte, en primera persona:
##   · las manos van a otro sitio en cada una (garganta, nuca, boca, ojos, mandíbula, mejillas, hombros, oreja,
##     lanyard, cable del headset…: Screamers.hand_l/hand_r, IK de ScreamRig) con los dedos en garra o planos;
##   · la cámara se mueve con el golpe (caes al suelo, te levantan del cuello, te estrellan contra el monitor, la
##     silla se vuelca o gira…: cabeza del jugador + Screamers.cam_off/cam_roll/cam_pitch);
##   · el asesino se te sube encima, te mira de cabeza o de costado (Screamers.lock_*);
##   · utilería simple (fx/kill_props.gd), impactos, la pantalla que se raja y las luces.
## La duración total, la frase gritada, la deformación de la cara y la pantalla de muerte no cambian (los pone
## Screamers). SPEC: lo que cada muerte debe mostrar (props y tiempos); las pruebas (v031_kills.gd) lo comparan con
## Screamers.last_info["props"] / ["beats"].

const SPEC: Dictionary = {
	# --- Shero ---
	"shero_placaje": {"asesino": "shero", "props": [], "beats": ["agarre", "placaje", "suelo", "encima", "grito", "final"]},
	"shero_cuello_pared": {"asesino": "shero", "props": ["pared"], "beats": ["agarre", "pared", "levanta", "mira_abajo", "grito", "final"]},
	"shero_mesa_taper": {"asesino": "shero", "props": ["mesa_taper", "arroz", "comida"], "beats": ["agarre", "grito", "golpe_1", "golpe_2", "come", "golpe_3", "final"]},
	"shero_boca_sofa": {"asesino": "shero", "props": ["tus_manos"], "beats": ["agarre", "boca", "levanta", "forcejeo", "grito", "sofoca", "final"]},
	"shero_monitor": {"asesino": "shero", "props": [], "beats": ["agarre", "golpe_1", "golpe_2", "giro", "grito", "final"]},
	"shero_teclado": {"asesino": "shero", "props": ["teclado", "teclas"], "beats": ["agarre", "golpe", "costado", "grito", "final"]},
	"shero_lanyard": {"asesino": "shero", "props": ["lanyard", "fotocheck"], "beats": ["agarre", "jalon", "ahorca", "cuello", "grito", "final"]},
	"shero_lanyard_arrastre": {"asesino": "shero", "props": ["lanyard", "fotocheck"], "beats": ["agarre", "suelo", "arrastre", "grito", "final"]},
	"shero_cable_arrastre": {"asesino": "shero", "props": ["cable_headset"], "beats": ["agarre", "jalon", "suelo", "grito", "final"]},
	"shero_cable_cuello": {"asesino": "shero", "props": ["cable_headset"], "beats": ["agarre", "ahorca", "amarra", "silla_cae", "de_cabeza", "grito", "final"]},
	"shero_cable_lazo": {"asesino": "shero", "props": ["cable_headset"], "beats": ["agarre", "lazo", "aprieta", "recoge", "grito", "final"]},
	"shero_lista": {"asesino": "shero", "props": ["lista"], "beats": ["agarre", "lista", "mandibula", "lee", "grito", "final"]},
	"shero_ojos": {"asesino": "shero", "props": [], "beats": ["agarre", "ojos", "pulgares", "luz", "grito", "final"]},
	"shero_hoja_ww": {"asesino": "shero", "props": ["hoja_ww"], "beats": ["agarre", "cachetada", "arranca", "rostro", "grito", "final"]},
	"shero_fotocheck": {"asesino": "shero", "props": ["lanyard", "fotocheck"], "beats": ["agarre", "arranca", "caes", "parte", "grito", "empuja", "final"]},
	"shero_tickets": {"asesino": "shero", "props": ["tickets"], "beats": ["agarre", "avalancha", "hunde", "grito", "ahogo", "final"]},
	# --- Rasec ---
	"rasec_micro_cabina": {"asesino": "rasec", "props": ["microfono"], "beats": ["agarre", "microfono", "grito", "arrastre", "final"]},
	"rasec_platos": {"asesino": "rasec", "props": ["cabina", "estrobo"], "beats": ["agarre", "gira", "para", "cuello", "grito", "final"]},
	"rasec_silla_giro": {"asesino": "rasec", "props": ["estrobo", "tus_manos"], "beats": ["agarre", "gira", "para", "grito", "brazo", "desangra", "final"]},
	"rasec_gorro_silla": {"asesino": "rasec", "props": ["gorro", "confeti", "tus_manos"], "beats": ["agarre", "resiste", "gorro", "silla", "grito", "final"]},
	# --- Haime ---
	"haime_hombro_hoja": {"asesino": "haime", "props": ["hoja_calibracion"], "beats": ["agarre", "hombro", "giro", "hoja", "grito", "final"]},
	"haime_mejillas": {"asesino": "haime", "props": [], "beats": ["agarre", "cae", "grito", "golpe", "mejillas", "sacude", "piel", "final"]},
	# --- Trainer ---
	"trainer_pizarra": {"asesino": "trainer", "props": ["pizarra"], "beats": ["agarre", "pizarra", "segundo", "arrastra", "grito", "nuca", "final"]},
	"trainer_oido": {"asesino": "trainer", "props": [], "beats": ["agarre", "oido", "grito", "oreja", "zumbido", "cuello", "final"]},
	# --- Perrito RTA ---
	"rta_trepa_mordida": {"asesino": "rta", "props": [], "beats": ["salto", "derriba", "antebrazo", "sacude", "fauces", "grito", "dentelladas", "garganta", "shock", "final"]},
	# --- Vitzo ---
	"vitzo_vidrio_bandeja": {"asesino": "vitzo", "props": ["vidrios", "bandeja"], "beats": ["agarre", "vidrio", "adentro", "grito", "final"]},
	"vitzo_salto": {"asesino": "vitzo", "props": [], "beats": ["agarre", "salto", "suelo", "grito", "final"]},
	"vitzo_fusion": {"asesino": "vitzo", "props": ["popups", "tus_manos", "antena", "fusion_sala"], "beats": ["agarre", "manos", "grito", "resiste", "aparta", "verde", "tercera", "arranca", "sonrisa", "lentes", "antena", "grito_agente", "rigido", "corte", "sala", "fundido"]},
	"vitzo_pantalla_correo": {"asesino": "vitzo", "props": ["correo"], "beats": ["agarre", "jala", "adentro", "grito", "correo", "final"]},
	"vitzo_divisor": {"asesino": "vitzo", "props": ["divisor", "contraluz"], "beats": ["agarre", "arrastra", "divisor", "silueta", "salta", "grito", "final"]},
}

## v0.3.2: fracción del tiempo de la muerte (u de _at) en la que grita. Desde ahí, el resto de la muerte dura lo que la
## frase (Screamers.voice_total) + Screamers.TAIL_S: la frase termina siempre antes del corte. Antes del grito, la
## acción (golpes, arrastres…) ocupa lo que quede de la fila (ver _map).
const GRITO_U: Dictionary = {
	"shero_placaje": 0.4, "shero_cuello_pared": 0.58, "shero_mesa_taper": 0.05, "shero_boca_sofa": 0.5, "shero_monitor": 0.62,
	"shero_teclado": 0.55, "shero_lanyard": 0.42, "shero_lanyard_arrastre": 0.6, "shero_cable_arrastre": 0.5,
	"shero_cable_cuello": 0.52, "shero_cable_lazo": 0.58, "shero_lista": 0.56, "shero_ojos": 0.44, "shero_hoja_ww": 0.5,
	"shero_fotocheck": 0.44, "shero_tickets": 0.5, "rasec_micro_cabina": 0.3, "rasec_platos": 0.36, "rasec_silla_giro": 0.48,
	"rasec_gorro_silla": 0.5, "haime_hombro_hoja": 0.56, "haime_mejillas": 0.18, "trainer_pizarra": 0.62, "trainer_oido": 0.22,
	"rta_trepa_mordida": 0.5, "vitzo_vidrio_bandeja": 0.42, "vitzo_salto": 0.36, "vitzo_fusion": 0.0,
	"vitzo_pantalla_correo": 0.36, "vitzo_divisor": 0.4, "vitzo_popups": 0.4,
}

## Estrobo (Rasec): tope de destellos por segundo (fotosensibilidad).
const STROBE_HZ := 3.0

var fx: Screamers = null
var _t0: float = 0.0
var _R: float = 2.0
var _base: Vector3 = Vector3(0, 1.6, 0)
var _us: float = 0.0  # u del grito (GRITO_U); 0 = reparto lineal
var _A: float = 0.0  # segundos de acción antes del grito
var _S: float = 0.0  # segundos desde el grito hasta el final (frase + cola - corte)
var _screamed: bool = false


static func has(id: String) -> bool:
	return SPEC.has(id)


## La muerte que toca: "kill_alcance" si te alcanzó en una persecución (intro alcance/salto), si no "kill".
static func kill_for(row: Dictionary, intro: String, _seated: bool) -> String:
	if intro in ["alcance", "salto"] and str(row.get("kill_alcance", "")) != "":
		return str(row["kill_alcance"])
	return str(row.get("kill", ""))


## Todas las muertes posibles de una fila (las pruebas y el bot comparan con esto).
static func kills_of(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in ["kill", "kill_alcance"]:
		if str(row.get(k, "")) != "":
			out.append(str(row[k]))
	return out


## Corrutina: agarre, acción y final de la muerte `id`; termina en seconds - CUT (el corte lo hace Screamers).
static func run(p_fx: Screamers, id: String) -> void:
	var km := KillMoves.new()
	km.fx = p_fx
	km._t0 = p_fx._spent
	km._R = maxf(p_fx.seconds - Screamers.CUT - p_fx._spent, 0.6)
	km._base = p_fx._head_base if p_fx._head_base != Vector3.INF else Vector3(0, 1.6, 0)
	km._us = float(GRITO_U.get(id, 0.0))
	var v := p_fx.voice_total()
	if km._us > 0.0 and v > 0.0:
		km._S = clampf(v + Screamers.TAIL_S - Screamers.CUT, 0.3, maxf(km._R - 0.35, 0.3))
		km._A = km._R - km._S
		# kills2: "accion_s" en la fila = segundos FIJOS de acción antes del grito, sea cual sea la toma de la frase (las
		# tres del Trainer miden 2,45 / 3,12 / 3,41 s: con la larga, a la pizarra le quedaban 0,35 s; con la corta, 1,2 s).
		# La muerte dura agarre + accion_s + la toma + cola: con una toma corta termina antes, no se queda esperando.
		var acc := float(p_fx.row.get("accion_s", 0.0))
		if acc > 0.0 and Engine.time_scale < 8.0:
			km._S = maxf(v + Screamers.TAIL_S - Screamers.CUT, 0.3)
			km._A = acc
			km._R = km._A + km._S
			p_fx.seconds = km._t0 + km._R + Screamers.CUT
			p_fx.last_info["duracion"] = p_fx.seconds
	else:
		km._us = 0.0
	p_fx.last_info["accion_s"] = km._A
	# v0.3.2c: si el golpe de la toma está más adentro del archivo (frase_golpe_s), la voz arranca antes del grito
	# para que su golpe caiga en el golpe de la imagen (Screamers.voice_lead).
	var lead := p_fx.voice_lead()
	if km._us > 0.0 and lead > 0.02:
		p_fx.prestart_voice(km._t0 + km._A - lead - p_fx._clock)
	p_fx.kill_obj = km
	if p_fx._move_tw != null and p_fx._move_tw.is_valid():
		p_fx._move_tw.kill()
	p_fx._face_keep = -1.0
	p_fx._overhead = false
	km._face_light()
	km._hide_own_body()
	km._clear_seat()
	await km.call("_k_" + id)
	if is_instance_valid(p_fx) and not p_fx._done:
		await p_fx._wait(p_fx.seconds - Screamers.CUT - p_fx._spent)


# --- herramientas ---------------------------------------------------------------------------------------------

## Tu propio cuerpo (el rig del agente con la cabeza en la cámara) se esconde: la cámara cae al piso, sube o se
## vuelca y se metía dentro del torso (un plano gris tapaba al asesino). Screamers._cleanup lo vuelve a mostrar.
func _hide_own_body() -> void:
	var p := fx._player
	if p == null:
		return
	var body := p.get("_rig") as Node3D
	if body != null and body.visible:
		body.visible = false
		fx._hidden.append(body)


## Tu silla (asiento y respaldo) se esconde: al caer, volcarte o hundirte la cámara pasa por donde está y su
## tabla tapaba la vista. Screamers._cleanup la vuelve a mostrar.
func _clear_seat() -> void:
	var fl := FloorBase.active
	var p := fx._player
	if fl == null or p == null:
		return
	var at := p.global_position
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := str(mi.name)
		if not (nm.begins_with("Silla") or nm.begins_with("Respaldo")) or not mi.visible:
			continue
		var d := mi.global_position - at
		if Vector2(d.x, d.z).length() < 1.3:
			mi.visible = false
			fx._hidden.append(mi)


## Cuánto caer hacia atrás: sentado, lejos de la silla (al pasillo); de pie, poco.
func _back() -> float:
	return 0.85 if _p().seated else 0.35


## Luz de cara que sigue a la cámara (la que ya tiene Haime): en el suelo, de cabeza o contra la mesa la luz del
## modelo queda lejos de su cara; esta la saca de la oscuridad sin aplanar el terror (fría y baja).
func _face_light() -> void:
	if fx._stage == null or (fx._face_light != null and is_instance_valid(fx._face_light)):
		return
	var slug := str(fx.row.get("modelo", fx._default_model()))
	var lc: Array = Screamers.LIGHTS.get(slug, [Color(0.85, 0.95, 0.85), 2.4])
	var l := OmniLight3D.new()
	l.name = "LuzCaraMuerte"
	l.light_color = (lc[0] as Color).lerp(Color(0.9, 0.95, 0.9), 0.5)
	l.light_energy = 0.55
	l.omni_range = 1.1
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.set_meta("no_mood", true)
	fx._stage.add_child(l)
	fx._face_light = l


## Punto en el espacio de la cámara: x derecha, y arriba, f adelante.
static func L(x: float, y: float, f: float) -> Vector3:
	return Vector3(x, y, -f)


## Segundos (desde el agarre) de la fracción u: antes del grito, la acción reparte _A; desde el grito, _S (lo que
## dura la frase): así la frase siempre cabe entera.
func _map(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	if _us <= 0.0:
		return _R * u
	if u <= _us:
		return _A * u / _us
	return _A + _S * (u - _us) / (1.0 - _us)


## Espera hasta la fracción u del tiempo de la muerte. Devuelve true si el screamer se cortó.
func _at(u: float) -> bool:
	await fx._wait(_t0 + _map(u) - fx._spent)
	return fx._done or not is_instance_valid(fx)


## Un lapso de u (para las tweens): al ritmo de la acción antes del grito y al de la frase después.
func _s(u: float) -> float:
	if _us <= 0.0:
		return maxf(_R * u, 0.02)
	var rate := (_S / (1.0 - _us)) if _screamed else (_A / _us)
	return maxf(rate * u, 0.02)


func _beat(name: String) -> void:
	(fx.last_info["beats"] as Array).append(name)
	fx._dbg("tiempo " + name)


func _prop(name: String) -> void:
	if not (fx.last_info["props"] as Array).has(name):
		(fx.last_info["props"] as Array).append(name)


func _tw() -> Tween:
	return fx.create_tween()


func _p() -> Player:
	return fx._player


func _grab(on: bool = true) -> void:
	fx._grab_goal = 1.0 if on else 0.0
	if on:
		KillGore.pain(fx, true)  # el primer grito tuyo al agarrarte


func _hands(l: Vector3, r: Vector3, claw: float = 1.0, speed: float = 14.0) -> void:
	fx.hand_l = l
	fx.hand_r = r
	fx.hand_claw = claw
	fx.hand_speed = speed
	fx.palm_l = Vector3.INF  # vuelve a la palma automática (hacia tu eje) y a la garra de `claw`
	fx.palm_r = Vector3.INF
	fx.grip_l = ""
	fx.grip_r = ""


## Manos que agarran (v0.3.2d): agarre de los dedos por lado de TU vista (KillHands.GRIPS: "puño", "garra", "plana",
## "gancho", "pinza", "tubo", "suelta"; "" = la garra de _hands) y, opcional, hacia dónde mira cada palma (punto del
## espacio de la vista; Screamers.PALM_OFF = sin orientar). Llamar DESPUÉS de _hands (que lo reinicia).
func _grip(l: String, r: String, palm_l: Vector3 = Vector3.INF, palm_r: Vector3 = Vector3.INF) -> void:
	fx.grip_l = l
	fx.grip_r = r
	fx.palm_l = palm_l
	fx.palm_r = palm_r


func _lock(face: Vector3, rate: float = 12.0, upright: bool = false, tilt: Vector3 = Vector3.ZERO) -> void:
	fx.lock_on = true
	fx.lock_face = face
	fx.lock_rate = rate
	fx.lock_upright = upright
	fx.lock_tilt = tilt
	fx._follow = 0.0


func _lock_to(face: Vector3, t: float, trans: int = Tween.TRANS_SINE, ease: int = Tween.EASE_IN_OUT) -> Tween:
	var tw := _tw().set_trans(trans).set_ease(ease)
	tw.tween_property(fx, "lock_face", face, maxf(t, 0.02))
	return tw


## La cabeza del jugador a base + d (m, espacio del jugador).
func _head(d: Vector3, t: float, trans: int = Tween.TRANS_QUAD, ease: int = Tween.EASE_OUT) -> Tween:
	var tw := _tw().set_trans(trans).set_ease(ease)
	tw.tween_property(_p().head, "position", _base + d, maxf(t, 0.02))
	return tw


func _pitch(rad: float, t: float, trans: int = Tween.TRANS_QUAD, ease: int = Tween.EASE_OUT) -> Tween:
	var tw := _tw().set_trans(trans).set_ease(ease)
	tw.tween_property(_p().head, "rotation:x", rad, maxf(t, 0.02))
	return tw


func _yaw_by(rad: float, t: float, trans: int = Tween.TRANS_CUBIC, ease: int = Tween.EASE_IN_OUT) -> Tween:
	var tw := _tw().set_trans(trans).set_ease(ease)
	tw.tween_property(_p(), "rotation:y", _p().rotation.y + rad, maxf(t, 0.02))
	return tw


func _cam(prop: String, v: Variant, t: float, trans: int = Tween.TRANS_QUAD, ease: int = Tween.EASE_OUT) -> Tween:
	var tw := _tw().set_trans(trans).set_ease(ease)
	tw.tween_property(fx, prop, v, maxf(t, 0.02))
	return tw


## Golpe: sacudón, sonido, vibración, un fotograma negro (la cabeza choca) y la imagen más rota.
## v0.3.2: debajo, la capa de impacto (KillGore.slam: transitorio, slam grave, rugido, chillido; al bus con el
## limitador); los golpes fuertes salpican sangre en la vista y las grietas de la pantalla sangran (Reducido: no).
func _impact(k: float = 1.0, slot: String = "sfx/trainer_golpe", pitch: float = 1.0, crack: bool = false) -> void:
	fx._shake = 0.05 + 0.1 * k
	fx._snd(slot, 3.0, pitch)
	KillGore.slam(fx, k)
	if k >= 0.75:
		KillGore.pain(fx)
		_hitstop(3)
		_chips(k)
	Controls.vibrate(1.0, 1.0, 0.25 + 0.35 * k)
	fx._red = minf(1.0, fx._red + 0.25 * k)
	fx._fx_k = minf(1.0, fx._fx_k + 0.35 * k)
	if crack:
		KillGore.crack_blood(fx)
	elif k >= 0.85:
		KillGore.splatter(fx, 0.45 * k)
	KillGore.face(fx, minf(1.0, (fx._rig.gore if fx._rig != null else 0.0) + 0.2 * k), 0.15)
	_flash(Color(0, 0, 0, 0.9 * k), 0.08)
	KillGore.gfx("GfxLens", "kick", [0.3 + 0.5 * k, 0.35])
	_rebound(k)


## Cuadro de impacto: 2-3 fotogramas en cámara lenta (no en los bots rápidos ni si ya hay uno).
func _hitstop(frames: int) -> void:
	if Engine.time_scale > 2.5 or fx.has_meta("hitstop"):
		return
	var ts := Engine.time_scale
	fx.set_meta("hitstop", ts)
	Engine.time_scale = ts * 0.3
	var me: WeakRef = weakref(fx)
	# v0.3.2e: dura lo que `frames` cuadros a 60 fps (en tiempo real), no `frames` cuadros de los que haya: con la máquina
	# lenta (10-20 fps) tres cuadros eran 0,2-0,3 s de cámara lenta por golpe y la muerte se alargaba.
	var until := Time.get_ticks_msec() + int(frames * 16.7)
	await fx.get_tree().process_frame
	while Time.get_ticks_msec() < until and me.get_ref() != null:
		await fx.get_tree().process_frame
	var f: Screamers = me.get_ref()
	if f != null and f.has_meta("hitstop"):
		Engine.time_scale = float(f.get_meta("hitstop"))
		f.remove_meta("hitstop")
	elif f == null:
		Engine.time_scale = ts


## Restos del golpe (astillas y polvo) que saltan delante de la vista.
func _chips(k: float) -> void:
	var at := fx._cam().global_transform * L(0, -0.06, 0.32)
	KillProps.debris(fx, KillProps.count(10), Vector3(0.008, 0.006, 0.004), [Color(0.55, 0.55, 0.52), Color(0.25, 0.24, 0.22), Color(0.4, 0.0, 0.02) if KillGore.enabled() else Color(0.3, 0.3, 0.3)], at,
		func(_k: int) -> Vector3: return Vector3(randf_range(-1.2, 1.2), randf_range(0.2, 1.6), randf_range(-1.2, 1.2)) * (0.6 + 0.5 * k), 4.0)


## Anticipación: la cabeza (la vista) se echa atrás un instante antes del golpe.
func _windup(t: float = 0.08) -> void:
	var tw := _tw().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "cam_off", Vector3(0, 0.02, 0.06), t)
	tw.tween_property(fx, "cam_off", Vector3.ZERO, t * 0.6)


## Destello a pantalla completa (negro del golpe, rojo de la mordida, colores del estrobo). Suave si se pidió
## reducir destellos.
func _flash(c: Color, t: float) -> void:
	if fx._root == null:
		return
	if fx._soft and c.r + c.g + c.b > 0.3:
		c.a *= 0.25
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = c
	fx._root.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, maxf(t, 0.02))
	tw.tween_callback(r.queue_free)


## El final: la cara llena la pantalla (la deformación al máximo) en lo que queda.
func _final(face: Vector3 = L(0, 0, 0.24), red: float = 0.85) -> void:
	_beat("final")
	fx.lock_min_front = 0.0
	fx._fov_goal = 50.0
	fx._shake_goal = 0.06
	fx._fx_goal = 1.0
	fx._red = red
	if fx._rig != null:
		fx._rig.deform = 1.0
	KillGore.face(fx, 1.0, 0.25)
	KillGore.splatter(fx, 0.8, Vector2(randf_range(0.3, 0.7), randf_range(0.25, 0.45)))
	KillGore.slam(fx, 0.8)
	KillGore.gfx("GfxLens", "kick", [1.0, maxf(fx.seconds - fx._spent, 0.4)])
	if fx.lock_on:
		_lock_to(face, maxf(fx.seconds - Screamers.CUT - fx._spent, 0.05) * 0.8, Tween.TRANS_EXPO, Tween.EASE_IN)
	# Tus manos pierden fuerza y caen (te mueres).
	var v := _victim()
	if v != null:
		v.struggle(0.0)
		v.create_tween().tween_property(v, "strength", 0.0, maxf(fx.seconds - Screamers.CUT - fx._spent, 0.1) * 0.7)


func _scream(anim: bool = true) -> void:
	_screamed = true
	# Si el grito llega tarde (un fotograma largo), el final se corre lo mismo (hasta 0,25 s): la frase no se corta.
	if _us > 0.0:
		var late := clampf(fx._clock - (_t0 + _A), 0.0, 0.25)
		if late > 0.01:
			fx.seconds += late
			_R += late
			_A += late
			fx.last_info["grito_tarde"] = late
	_beat("grito")
	fx.scream_fx(anim and not _body_on)
	# Con un clip de cuerpo puesto, la animación «scream» del GLB no corre: la boca abierta del grito (sus +24°) la pone
	# el rig como piso de la mandíbula (si el clip la abre más, manda el clip).
	if _body_on and fx._rig != null and is_instance_valid(fx._rig):
		fx._rig.jaw_min_deg = 24.0
	# Shero tiene la cabeza enorme (26 cm de los ojos a la boca): a 0,3-0,4 m los ojos se le salían por arriba del cuadro
	# durante todo el grito. Mientras grita su cara no se acerca a menos de 0,5 m; el final (_final) se te viene encima.
	var mk := _m()
	if mk != null and str(mk.get_meta("slug", "")) == "shero":
		fx.lock_min_front = 0.5
	# Terror debajo de la frase (se aparta bajo la voz: cadena lateral del bus ScreamerSFX).
	KillGore.roar(fx, -2.0)
	KillGore.screech(fx, -6.0)
	KillGore.face(fx, 0.7, 0.4)
	KillGore.gfx("GfxLens", "kick", [0.8, 0.9])


func _m() -> Node3D:
	return fx._killer_model()


## Visto desde la cámara: punto del mundo de un punto del espacio de la cámara (en este fotograma).
func _wp(local: Vector3) -> Vector3:
	return fx._cam().global_transform * local


func _detail_or(v: String) -> String:
	return fx.detail if fx.detail != "" else v


# =============================================================================================================
# LA BARRA v0.3.2 (cuerpo entero; pedido D de Joan): el cuerpo del asesino (clips k32 de tools/anim/clips_kills.py),
# TUS brazos (KillVictim) y los golpes con anticipación → descarga → rebote. Lo usan todas las muertes.
# =============================================================================================================

## Segundo del clip k32 en el que cae el golpe (tools/anim/clips_kills.py).
const HIT_T: Dictionary = {"k_estrella": 0.30, "k_azote": 0.42, "k_cachetada": 0.28, "k_embiste": 0.34, "k_levanta": 0.36}
var _la_tw: Tween = null  # el tween de lock_add (carga y rebote): uno nuevo mata al anterior
var _body_on: bool = false  # el cuerpo del asesino lo lleva un clip k32 (el grito no lo pisa con el clip del GLB)


func _note(key: String, v: Variant) -> void:
	if not fx.last_info.has(key):
		fx.last_info[key] = []
	(fx.last_info[key] as Array).append(v)


## La biblioteca k32 del asesino (assets/anim/<modelo>_kills.res) en su AnimationPlayer; false si no tiene.
func _k32() -> bool:
	var ok := ensure_k32(_m())
	fx.last_info["k32"] = ok
	return ok


## Lo mismo para cualquier modelo de screamer (lo usa también la intro de Haime: Screamers._haime_vault).
static func ensure_k32(m: Node3D) -> bool:
	if m == null or not m.has_meta("anim"):
		return false
	if m.has_meta("k32"):
		return bool(m.get_meta("k32"))
	var ap := m.get_meta("anim") as AnimationPlayer
	var path := "res://assets/anim/%s_kills.res" % str(m.get_meta("slug", ""))
	var ok := false
	if ap != null and ResourceLoader.exists(path):
		var lib := load(path) as AnimationLibrary
		if lib != null:
			fix_jaw(lib, m)
			var mine: AnimationLibrary = ap.get_animation_library("k32") if ap.has_animation_library("k32") else null
			if mine == null:
				mine = AnimationLibrary.new()
				ap.add_animation_library("k32", mine)
			for n in lib.get_animation_list():
				if not mine.has_animation(n):
					mine.add_animation(n, lib.get_animation(n))
			ok = true
	m.set_meta("k32", ok)
	return ok


## La mandíbula de los clips k32, al derecho. rigkit la gira alrededor de −X local (la CIERRA contra el cráneo: la boca no
## se abría al gritar); los GLB la abren alrededor de +X (su «scream»: +24°; medido en los 7 rigs humanos). Al cargar una
## biblioteca, cada clave de la mandíbula que gire hacia −X se refleja a +X. Una sola vez por biblioteca (meta); si
## rigkit se corrige algún día, aquí no pasa nada. Devuelve las claves reflejadas.
static func fix_jaw(lib: AnimationLibrary, model: Node) -> int:
	if lib == null or model == null or lib.has_meta("jaw_ok"):
		return 0
	var sk: Skeleton3D = model as Skeleton3D
	if sk == null:
		for c in model.find_children("*", "Skeleton3D", true, false):
			sk = c as Skeleton3D
			break
	if sk == null:
		return 0
	lib.set_meta("jaw_ok", true)
	var jb := sk.find_bone("jaw")
	if jb < 0:
		return 0
	var rest := sk.get_bone_rest(jb).basis.get_rotation_quaternion()
	var n := 0
	for an in lib.get_animation_list():
		var a := lib.get_animation(an)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or not str(a.track_get_path(t)).ends_with(":jaw"):
				continue
			for k in a.track_get_key_count(t):
				var rel: Quaternion = rest.inverse() * (a.track_get_key_value(t, k) as Quaternion)
				if rel.w < 0.0:
					rel = -rel
				if rel.x < -0.0005:
					a.track_set_key_value(t, k, rest * rel.inverse())
					n += 1
	return n


## Clip de cuerpo del asesino («k32/<clip>»): de cuerpo entero, con su anticipación y su rebote. from: segundo del
## clip desde el que arranca. Si el modelo no tiene biblioteca k32 (el perrito, Vitzo), los clips del GLB `fallback`.
func _body(clip: String, speed: float = 1.0, blend: float = 0.12, from: float = 0.0, fallback: Array = []) -> bool:
	var m := _m()
	if m == null or not m.has_meta("anim"):
		return false
	var ap := m.get_meta("anim") as AnimationPlayer
	if _k32() and ap.has_animation("k32/" + clip):
		ap.play("k32/" + clip, blend, speed)
		if from > 0.0:
			ap.seek(from, false)
		_note("cuerpo", clip)
		_body_on = true
		return true
	if not fallback.is_empty():
		fx._anim(m, fallback, speed)
	return false


## Golpe con ANTICIPACIÓN. Espera hasta `wind` s antes de la fracción u; ahí el asesino CARGA (su cara se va atrás y
## arriba `back` m, el clip de golpe arranca para caer justo en u) y vuelve en u: quien llama da el golpe (_impact,
## que hace el rebote). true = el screamer se cortó.
func _hit(u: float, wind: float = 0.16, clip: String = "k_estrella", back: float = 0.09) -> bool:
	return await _hit_in(_t0 + _map(u) - fx._spent, wind, clip, back)


## Lo mismo, con el golpe dentro de dt segundos.
func _hit_in(dt: float, wind: float = 0.16, clip: String = "k_estrella", back: float = 0.09) -> bool:
	var w := clampf(dt, 0.0, wind)
	await fx._wait(dt - w)
	if fx._done or not is_instance_valid(fx):
		return true
	if w > 0.04:
		_wind(w, clip, back)
	await fx._wait(w)
	return fx._done or not is_instance_valid(fx)


## La carga del golpe (dura w s): la cara del asesino atrás y arriba, el clip de golpe desde su anticipación.
func _wind(w: float, clip: String = "k_estrella", back: float = 0.09) -> void:
	if _la_tw != null and _la_tw.is_valid():
		_la_tw.kill()
	_la_tw = _tw().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# «atrás» es alejándose de TI: delante de la cámara es -z; si te tiene por la espalda (lock_face.z > 0) es +z
	# (con -z se te metía por la nuca y su manga llenaba la pantalla en cada azote)
	var away := 1.0 if fx.lock_on and fx.lock_face.z > 0.0 else -1.0
	_la_tw.tween_property(fx, "lock_add", Vector3(0, back * 0.5, back * away), maxf(w * 0.85, 0.03))
	if clip != "":
		var t0 := float(HIT_T.get(clip, 0.3))
		if w >= t0:
			_body(clip, t0 / w, 0.06)
		else:
			_body(clip, 1.0, 0.05, t0 - w)
	_note("cargas", clip)


## El rebote del golpe: el asesino se viene encima con la descarga y vuelve pasándose; tus manos salen despedidas.
func _rebound(k: float) -> void:
	if fx.lock_on:
		if _la_tw != null and _la_tw.is_valid():
			_la_tw.kill()
		var near := clampf(-fx.lock_face.z - 0.27, 0.0, 0.07)  # sin meterse en la cámara
		_la_tw = _tw()
		_la_tw.tween_property(fx, "lock_add", Vector3(0, -0.035 * k, near * k), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_la_tw.tween_property(fx, "lock_add", Vector3.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var v := _victim()
	if v != null and k >= 0.5:
		v.jolt("l", Vector3(-1.3, 0.9, 0.5) * k)
		v.jolt("r", Vector3(1.3, 0.9, 0.5) * k)


## Tu KillVictim si ya existe (sin crearlo).
func _victim() -> KillVictim:
	if fx.has_meta("victim"):
		var v0: Variant = fx.get_meta("victim")
		if v0 is KillVictim and is_instance_valid(v0):
			return v0
	return null


## Punto del brazo del asesino que está del lado `view_side` de TU vista ("l"/"r"): de su mano (along 0) a su codo
## (along 1). INF si esa mano no te agarra.
func _k_arm(view_side: String, along: float = 0.35) -> Vector3:
	var rig := fx._rig
	var m := _m()
	var cam := fx._cam()
	if rig == null or not is_instance_valid(rig) or m == null or cam == null:
		return Vector3.INF
	var facing := (-m.global_transform.basis.z).dot(-cam.global_transform.basis.z) < 0.0
	var left := (view_side == "r") if facing else (view_side == "l")
	var h := rig.last_hand_l if left else rig.last_hand_r
	var e := rig.last_elbow_l if left else rig.last_elbow_r
	var w := rig.grab_w_l if left else rig.grab_w_r
	if h == Vector3.INF or w < 0.3 or rig.grab < 0.3:
		return Vector3.INF
	return h.lerp(e, along) if e != Vector3.INF else h


## TUS brazos según lo que te hacen (KillVictim: el modelo de tu agente, con resorte, palma orientada y dedos que
## agarran). Se llama en cada tiempo de la muerte; los golpes (_impact) te los sacuden y en el final caen sin fuerza.
##   "munecas"  te agarras de sus antebrazos (siguen a sus manos cuadro a cuadro); si esa mano no te toca, lo empujas
##   "cara"     le empujas la cara / la mandíbula con las dos manos
##   "pecho"    lo empujas del pecho
##   "cuello"   te arañas el cuello (el cable, el lanyard, sus dedos)
##   "escudo"   los antebrazos delante de la cara
##   "manotea"  manotazos al aire (caes, te arrastran)
##   "boca"     las dos manos a lo que te tapa la boca / la cara (la hoja, su mano)
##   "ojos"     las manos a tus ojos (ciego, sangrando)
##   "brazo_l" / "brazo_r"  las dos manos al brazo suyo que está del lado l / r de tu vista
##   "cae"      pierden fuerza y caen (amp = segundos)
func _vic(mode: String, amp: float = 0.012) -> KillVictim:
	var v := KillVictim.of(fx)
	if v == null:
		return null
	_note("victima", mode)
	var me: WeakRef = weakref(self)
	match mode:
		"munecas":
			v.struggle(amp, 9.0)
			for side in ["l", "r"]:
				var sgn := -1.0 if side == "l" else 1.0
				var s2: String = side
				# Dónde le agarras el antebrazo: cerca de su muñeca si se ve; si su mano queda fuera de tu vista (te tiene de la
				# cabeza, del cuello), más arriba, hacia su codo, hasta que tu mano entra en cuadro (el forcejeo tiene que
				# VERSE). Solo avanza hacia el codo, nunca vuelve: sin saltos de un cuadro a otro.
				var step: Array = [0]
				var at := func() -> Vector3:
					var km: KillMoves = me.get_ref()
					if km == null or not is_instance_valid(km.fx):
						return v.view_point(L(0.13 * sgn, -0.25, 0.36))
					var cam2 := km.fx._cam()
					var pt := Vector3.INF
					while true:
						pt = km._k_arm(s2, [0.35, 0.5, 0.65, 0.8][int(step[0])])
						if pt == Vector3.INF or cam2 == null or int(step[0]) >= 3:
							break
						var lp: Vector3 = cam2.global_transform.affine_inverse() * pt
						if lp.z < -0.1 and absf(lp.x) < 0.85 * -lp.z and absf(lp.y) < 0.48 * -lp.z:
							break
						step[0] = int(step[0]) + 1
					return pt if pt != Vector3.INF else v.view_point(L(0.13 * sgn, -0.25, 0.36))
				v.hold(side, func() -> Vector3: return (at.call() as Vector3) + v.view_point(L(0.035 * sgn, -0.05, -0.02)) - v.view_point(Vector3.ZERO), "tubo", at, 6.5)
		"cara":
			v.struggle(amp, 8.0)
			# Shero tiene la cabeza enorme (tus manos caben a los lados de su cara); el perrito y Vitzo se sujetan del hocico /
			# la pantalla. Los demás tienen la cabeza chica: con las manos EN la cara se la tapabas entera todo el grito →
			# empujas de la mandíbula y el cuello (su cara queda a la vista encima de tus manos).
			var mk0: Node3D = _m()
			var big: bool = mk0 == null or str(mk0.get_meta("slug", "")) in ["shero", "perrito_rta", "vitzo", "grasa"]
			var off := L(0.075, -0.09, -0.11) if big else L(0.07, -0.17, -0.09)
			for side in ["l", "r"]:
				var sgn := -1.0 if side == "l" else 1.0
				var face := func() -> Vector3:
					var km: KillMoves = me.get_ref()
					var mm: Node3D = km._m() if km != null and is_instance_valid(km.fx) else null
					return km.fx._head_point(mm) if mm != null else v.view_point(L(0, 0, 0.45))
				v.hold(side, func() -> Vector3: return (face.call() as Vector3) + v.view_point(Vector3(off.x * sgn, off.y, off.z)) - v.view_point(Vector3.ZERO), "garra", face, 5.5)
		"pecho":
			v.struggle(amp, 8.0)
			v.both(L(-0.13, -0.27, 0.36), L(0.13, -0.27, 0.36), "plana", L(0, -0.2, 0.8), 4.5)
		"cuello":
			v.struggle(amp * 1.4, 10.0)
			v.put("l", L(-0.085, -0.135, 0.21), "gancho", L(0, -0.3, 0.0), 6.0, L(0.6, 0.5, -0.6))
			v.put("r", L(0.085, -0.135, 0.21), "gancho", L(0, -0.3, 0.0), 6.0, L(-0.6, 0.5, -0.6))
		"escudo":
			v.struggle(amp * 0.6, 7.0)
			v.put("l", L(-0.14, -0.13, 0.27), "suelta", L(-0.05, -0.1, 0.9), 5.0, L(0.35, 0.9, 0.2))
			v.put("r", L(0.14, -0.13, 0.27), "suelta", L(0.05, -0.1, 0.9), 5.0, L(-0.35, 0.9, 0.2))
		"manotea":
			v.struggle(maxf(amp, 0.05), 3.4)
			v.both(L(-0.24, -0.12, 0.38), L(0.24, -0.12, 0.38), "suelta", L(0, 0.0, 0.9), 3.0)
		"ojos":  # las manos a tus ojos / tu cara (ciego, sangrando)
			v.struggle(amp, 7.0)
			v.put("l", L(-0.075, -0.06, 0.13), "garra", L(0.0, 0.0, -0.05), 5.5)
			v.put("r", L(0.075, -0.06, 0.13), "garra", L(0.0, 0.0, -0.05), 5.5)
		"ciego":  # ciego y sangrando: las manos bajan temblando a los lados de tu cara (SU cara queda a la vista)
			v.struggle(maxf(amp, 0.02), 6.0)
			v.put("l", L(-0.2, -0.21, 0.2), "garra", L(0.0, -0.05, -0.05), 3.2)
			v.put("r", L(0.2, -0.21, 0.2), "garra", L(0.0, -0.05, -0.05), 3.2)
		"boca":
			v.struggle(amp, 10.0)
			v.put("l", L(-0.1, -0.1, 0.2), "garra", L(0, -0.05, 0.12), 6.0)
			v.put("r", L(0.1, -0.1, 0.2), "garra", L(0, -0.05, 0.12), 6.0)
		"brazo_l", "brazo_r":  # las dos manos al brazo que te ahoga (el del lado l / r de tu vista)
			var vs := mode.right(1)
			v.struggle(amp, 9.0)
			for side in ["l", "r"]:
				var sgn := -1.0 if side == "l" else 1.0
				var along := 0.2 if side == vs else 0.55
				var at := func() -> Vector3:
					var km: KillMoves = me.get_ref()
					var pt := km._k_arm(vs, along) if km != null and is_instance_valid(km.fx) else Vector3.INF
					return pt if pt != Vector3.INF else v.view_point(L(0.1 * sgn, -0.24, 0.3))
				v.hold(side, func() -> Vector3: return (at.call() as Vector3) + v.view_point(L(0.03 * sgn, -0.055, -0.02)) - v.view_point(Vector3.ZERO), "tubo", at, 6.5)
		"cae":
			v.struggle(0.0)
			v.create_tween().tween_property(v, "strength", 0.0, maxf(amp, 0.1))
	return v


## Tus manos cambian de modo dentro de dt s, sin frenar la coreografía (te tapas los ojos y después bajan temblando:
## tus manos no pueden tapar la cara del que te grita más de un instante).
func _vic_later(dt: float, mode: String, amp: float = 0.012) -> void:
	var f: Screamers = fx
	# Por el reloj del screamer, NO con f._wait(): _wait suma a _spent (el acumulador de la coreografía principal) y una
	# espera en paralelo lo corría: el cambio de manos llegaba recién con el final.
	var until := f._clock + dt
	while is_instance_valid(f) and not f._done and f.is_inside_tree() and f._clock < until:
		await f.get_tree().process_frame
	if is_instance_valid(f) and not f._done and _victim() != null:
		_vic(mode, amp)


## Tus manos se apoyan en una superficie horizontal del mundo a la altura y (la mesa, el escritorio, el piso): empujas
## para zafarte. fwd / wide: m adelante de tus ojos y a cada lado.
func _vic_plant(y: float, fwd: float = 0.3, wide: float = 0.26, amp: float = 0.01) -> KillVictim:
	var v := KillVictim.of(fx)
	if v == null:
		return null
	_note("victima", "apoyo")
	v.struggle(amp, 8.0)
	var me: WeakRef = weakref(self)
	for side in ["l", "r"]:
		var sgn := -1.0 if side == "l" else 1.0
		var at := func() -> Vector3:
			var km: KillMoves = me.get_ref()
			if km == null or not is_instance_valid(km.fx) or km.fx._player == null:
				return Vector3.ZERO
			var pb := km.fx._player.global_transform.basis
			var e := km.fx._player.global_position
			return Vector3(e.x, y + 0.03, e.z) - pb.z * (fwd + 0.25) + pb.x * (wide * sgn)
		v.hold(side, at, "plana", func() -> Vector3: return (at.call() as Vector3) - Vector3(0, 0.3, 0), 5.0)
	return v


## La pared detrás de ti acusa el golpe: tiembla, el afiche queda torcido y cae yeso delante de tu vista.
func _wall_react(wall: Node3D) -> void:
	if wall == null or not is_instance_valid(wall):
		return
	var poster := wall.get_meta("poster", null) as Node3D
	if poster != null and is_instance_valid(poster):
		var tw := poster.create_tween().set_parallel(true)
		tw.tween_property(poster, "rotation:z", deg_to_rad(-13.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(poster, "position:y", poster.position.y - 0.07, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var p0 := wall.position
	var sh := wall.create_tween()
	sh.tween_property(wall, "position", p0 - wall.global_transform.basis.z * 0.015, 0.03)
	sh.tween_property(wall, "position", p0, 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	KillProps.debris(fx, KillProps.count(14), Vector3(0.012, 0.004, 0.012), [Color(0.8, 0.8, 0.78), Color(0.6, 0.62, 0.6)],
		fx._eye() + fx._dir(0.0) * 0.12 + Vector3(0, 0.3, 0),
		func(_k: int) -> Vector3: return Vector3(randf_range(-0.7, 0.7), randf_range(-0.1, 0.8), randf_range(-0.5, 0.5)), 4.0)
	_prop("yeso")


## La luz de cara (va a 12 cm de tus ojos) a k veces su energía en t s: con tu cara contra una mesa, un teclado o el
## piso, a toda energía quemaba la superficie a blanco y no se veía nada (k 0,2-0,3); de vuelta, k = 1.
func _fl(k: float, t: float = 0.12) -> void:
	var l := fx._face_light
	if l == null or not is_instance_valid(l):
		return
	if not l.has_meta("e0"):
		l.set_meta("e0", l.light_energy)
	l.create_tween().tween_property(l, "light_energy", float(l.get_meta("e0")) * k, maxf(t, 0.02))


## Tu silla sale rodando hacia el lado despejado (si estabas sentado): la que _clear_seat escondió vuelve a verse.
func _chair_away(t: float = 0.7) -> bool:
	var p := _p()
	if p == null or not p.seated:
		return false
	var pb := p.global_transform.basis
	var from := fx._eye() - Vector3(0, 0.6, 0)
	var side := 1.0 if _free(from, pb.x, 1.6) >= _free(from, -pb.x, 1.6) else -1.0
	return _chair_roll(pb.x * side * 0.9 + pb.z * 0.7, 1.9 * side, t)


## Lo que hay en tu escritorio (monitor, teclado, headset, taza) SALTA con el golpe y vuelve a caer (k 0..1). rock: los
## monitores, además, se mecen hacia atrás sobre su base (les pegó tu cabeza).
func _desk_jolt(k: float = 1.0, rock: bool = false) -> void:
	var fl := FloorBase.active
	var p := fx._player
	if fl == null or p == null:
		return
	var at := p.global_position
	var n_ok := 0
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := str(mi.name)
		if not (nm.begins_with("Monitor") or nm.begins_with("Teclado") or nm.begins_with("Headset") or nm.begins_with("Taza") or nm.begins_with("Mouse") or nm.begins_with("Telefono")):
			continue
		var d := mi.global_position - at
		if Vector2(d.x, d.z).length() > 1.5 or not mi.is_visible_in_tree():
			continue
		if not fx._xf_back.has(mi):
			fx._xf_back[mi] = mi.transform
		var home: Transform3D = fx._xf_back[mi]
		var up := (0.012 + 0.02 * randf()) * k
		var tilt := deg_to_rad(randf_range(-7.0, 7.0)) * k
		var tw := mi.create_tween()
		if nm.begins_with("Monitor") and rock:
			# El monitor se mece: se va atrás sobre su base (lo empujó tu cabeza) y vuelve con dos rebotes.
			var away := mi.global_position - at
			away.y = 0.0
			away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
			var axis_l := (mi.global_transform.basis.inverse() * Vector3.UP.cross(away)).normalized()
			var back_b := home.basis * Basis(axis_l, deg_to_rad(13.0) * k)
			var back_o := home.origin + (mi.get_parent() as Node3D).global_transform.basis.inverse() * (away * 0.035 * k) if mi.get_parent() is Node3D else home.origin
			tw.tween_property(mi, "transform", Transform3D(back_b, back_o), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "transform", home, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			n_ok += 1
			continue
		tw.tween_property(mi, "transform", Transform3D(home.basis * Basis(Vector3.FORWARD, tilt), home.origin + Vector3(0, up, 0)), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "transform", Transform3D(home.basis * Basis(Vector3.FORWARD, tilt * 0.3), home.origin), 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		n_ok += 1
		if n_ok >= 8:
			break
	if n_ok > 0:
		_prop("escritorio")


# =============================================================================================================
# SHERO
# =============================================================================================================

## Break excedido: te taclea a la carrera. Caes, la cabeza rebota en el piso, se te sube encima, te clava los
## hombros al suelo y te grita con la cara pegada a la tuya.
func _k_shero_placaje() -> void:
	var m := _m()
	_grab()
	_hands(L(-0.22, -0.5, 0.22), L(0.22, -0.5, 0.22), 1.0, 10.0)  # te toma por la cintura
	_grip("garra", "garra")
	_lock(L(0, -0.25, 0.55), 9.0, true, Vector3(-25, 0, 0))
	fx._anim(m, ["sprint", "jumpscare_main"], 1.5)
	_vic("escudo")  # alcanzas a levantar los brazos
	_beat("agarre")
	# Se agazapa con los brazos abiertos (anticipación) y embiste con el hombro.
	if await _hit(0.1, 0.2, "k_embiste", 0.1):
		return
	_beat("placaje")
	_impact(1.0, "sfx/caida_cuerpo", 0.9)
	fx._snd("sfx/kill_golpe_seco", 0.0, 1.0)
	_vic("manotea")
	_chair_away()  # si estabas sentado, la silla sale rodando
	_desk_jolt(0.7)
	# Caes de espaldas: la cabeza al piso, la vista gira y termina mirando al techo.
	_head(Vector3(0, 0.22 - _base.y, _back()), _s(0.15), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(1.3, _s(0.16), Tween.TRANS_QUAD, Tween.EASE_IN)
	_cam("cam_roll", 0.75, _s(0.12)).chain().tween_property(fx, "cam_roll", 0.22, _s(0.2))
	_lock(L(0, 0.05, 0.75), 7.0, false, Vector3(-8, 0, 0))
	if await _at(0.27):
		return
	_beat("suelo")
	_impact(0.9, "sfx/trainer_golpe", 0.6)
	fx._snd("sfx/acufeno", -10.0)
	# La cabeza rebota en el piso.
	var floor_d := Vector3(0, 0.22 - _base.y, _back())
	var hb := _head(floor_d + Vector3(0, 0.05, 0), 0.07)
	hb.tween_property(_p().head, "position", _base + floor_d, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Se te sube encima, a horcajadas (en la vista está "de pie" frente a ti: en el mundo, arqueado sobre tu cuerpo).
	_lock_to(L(0, 0.0, 0.5), _s(0.2))
	# Te clava los hombros: la vista baja un poco y entran los dos antebrazos, uno a cada lado, las palmas hacia abajo.
	_hands(L(-0.21, -0.2, 0.1), L(0.21, -0.2, 0.1), 0.7, 9.0)
	_grip("garra", "garra", L(-0.21, -0.5, 0.0), L(0.21, -0.5, 0.0))
	_cam("cam_pitch", -0.3, _s(0.15))
	_body("k_encima", 1.0, 0.25, 0.0, ["hunch", "jumpscare_alt"])
	_vic("munecas", 0.014)  # te agarras de sus antebrazos
	_beat("encima")
	if await _at(0.4):
		return
	_scream()
	_vic("cara", 0.016)  # le empujas la cara
	_lock_to(L(0, 0.02, 0.32), _s(0.3))
	for i in 3:
		# Te sacude de los hombros contra el piso.
		var tw := _cam("cam_off", Vector3(0, -0.03, 0.02), 0.06)
		tw.tween_property(fx, "cam_off", Vector3.ZERO, 0.12)
		var v := _victim()
		if v != null:
			v.jolt("l", Vector3(-0.8, 0.5, 0.3))
			v.jolt("r", Vector3(0.8, 0.5, 0.3))
		fx._snd("sfx/kill_golpe_seco", -8.0, 0.7 + 0.05 * i)
		if await _at(0.48 + i * 0.1):
			return
	_vic("munecas", 0.008)
	if await _at(0.8):
		return
	_final(L(0, 0, 0.17))


## 3.er break: te alcanza, te agarra del cuello y te estrella contra la pared; te levanta (los pies dejan el
## piso), la vista sube y se ladea mientras te ahoga.
func _k_shero_cuello_pared() -> void:
	var m := _m()
	_grab()
	# Una mano (plana) a la pared junto a tu cabeza, la otra te rodea el cuello.
	_hands(L(-0.32, 0.1, 0.0), L(0.02, -0.23, 0.15), 0.75, 12.0)
	_grip("plana", "tubo", L(-0.32, 0.1, -0.6), L(0.0, -0.22, -0.06))
	_lock(L(0, -0.05, 0.5), 10.0, true, Vector3(-15, 0, 0))
	fx._anim(m, ["jumpscare_main"], 1.3)
	_vic("brazo_r")  # las dos manos al brazo que te ahoga
	_beat("agarre")
	# La pared (con un afiche) a tu espalda, adonde te estrella.
	var wall := _wall_behind(0.62)
	# Te echa un palmo hacia sí (carga) y te estrella de espaldas contra la pared con todo el cuerpo.
	if await _hit(0.13, 0.16, "k_estrella", 0.07):
		return
	_beat("pared")
	_head(Vector3(0, 0, 0.3), 0.07, Tween.TRANS_EXPO, Tween.EASE_IN)
	await fx._wait(0.07)
	if fx._done or not is_instance_valid(fx):
		return
	_impact(1.0, "sfx/trainer_golpe", 0.75)
	fx._snd("sfx/kill_golpe_seco", 0.0, 0.8)
	_wall_react(wall)
	# Te levanta del cuello: se agacha (carga), empuja con las piernas y la cámara sube (y tu cuerpo con ella), se
	# ladea y mira hacia abajo a su cara. Tus piernas patalean en el aire.
	if await _hit(0.22, 0.24, "k_levanta", 0.04):
		return
	_beat("levanta")
	var v := _victim()
	if v == null or not v.body("v_patalea", 1.25):
		var body := _show_own_body()
		if body != null:
			_tw().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(body, "position", body.position + Vector3(0, 0.5, 0.42), _s(0.25))
	_head(Vector3(0, 0.5, 0.3), _s(0.25), Tween.TRANS_BACK, Tween.EASE_OUT)
	_pitch(-0.42, _s(0.25))
	_cam("cam_roll", 0.2, _s(0.25))
	_lock(L(0, -0.16, 0.5), 8.0, false, Vector3(20, 0, 0))
	_hands(L(-0.3, 0.12, -0.02), L(0.02, -0.2, 0.13), 0.9, 10.0)
	_grip("plana", "tubo", L(-0.3, 0.12, -0.6), L(0.0, -0.2, -0.06))
	_vic("brazo_r", 0.018)
	fx._snd("sfx/kill_ahogo", -2.0)
	fx._snd("sfx/latido_rapido_loop", -6.0)
	if await _at(0.36):
		return
	# Un vistazo atrás y abajo: tus piernas pataleando sobre el piso, la pared y el afiche (torcido) detrás.
	_beat("mira_abajo")
	fx.lock_on = false
	var g := _tw().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	g.tween_property(fx, "glance", Vector2(-0.85, 0.6), _s(0.1))
	g.tween_interval(_s(0.13))
	g.tween_property(fx, "glance", Vector2.ZERO, _s(0.08)).set_ease(Tween.EASE_IN)
	fx._snd("sfx/kill_arrastre", -8.0, 1.6)
	if await _at(0.58):
		return
	_lock(L(0, -0.16, 0.5), 12.0, false, Vector3(20, 0, 0))
	_scream()
	_vic("brazo_r", 0.008)
	if v != null:
		v.create_tween().tween_property(v, "strength", 0.45, _s(0.25))  # se te van las fuerzas
		if v.anim != null:
			v.anim.speed_scale = 0.6  # el pataleo se apaga
	# Pataleas colgando: la vista se mece.
	var sway := _tw().set_loops(3)
	sway.tween_property(fx, "cam_roll", 0.3, _s(0.06))
	sway.tween_property(fx, "cam_roll", 0.1, _s(0.06))
	_lock_to(L(0, -0.06, 0.38), _s(0.2))  # su cara sube al centro: la frase (abajo) no la tapa
	if await _at(0.84):
		return
	if v != null and v.anim != null:
		v.anim.speed_scale = 0.15
	var own := _p().get("_rig") as Node3D
	if own != null and (v == null or not v.visible):
		own.visible = false
	_final(L(0, -0.1, 0.2))
	var _w := wall


## Pared del pasillo a tu espalda (a `back` m detrás de tus ojos), con un afiche de la empresa.
func _wall_behind(back: float) -> Node3D:
	var p := _p()
	var root := Node3D.new()
	root.name = "ParedDetras"
	fx._stage.add_child(root)
	var fwd := fx._dir(0.0)
	var e := fx._eye()
	root.global_position = Vector3(e.x, fx._floor_y(), e.z) - fwd * back
	root.look_at(root.global_position + fwd, Vector3.UP)  # su frente (-Z… +Z del panel) mira hacia ti
	root.rotate_object_local(Vector3.UP, PI)
	KillProps.box(root, Vector3(2.6, 2.8, 0.06), Color(0.62, 0.64, 0.6), Vector3(0, 1.4, -0.03))
	KillProps.box(root, Vector3(2.6, 0.12, 0.08), Color(0.22, 0.22, 0.24), Vector3(0, 0.06, 0.0))
	var poster := KillProps.box(root, Vector3(0.6, 0.85, 0.01), Color(0.85, 0.2, 0.18), Vector3(0.55, 1.35, 0.01))
	KillProps.label(poster, KillProps.t("SCR_K_POSTER_1", "KONZENTRAMANCE"), 0.0009, Color(1, 1, 1), Vector3(0, 0.3, 0.007), 0.0, 64)
	KillProps.label(poster, KillProps.t("SCR_K_POSTER_2", "¡SUPERA TU AHT!"), 0.0008, Color(1, 0.95, 0.85), Vector3(0, -0.02, 0.007), 0.0, 64)
	KillProps.label(poster, KillProps.t("SCR_K_POSTER_3", "META DEL MES: 100 %"), 0.0007, Color(1, 0.95, 0.85), Vector3(0, -0.2, 0.007), 0.0, 64)
	root.set_meta("poster", poster)
	_prop("pared")
	return root


## Vuelve a mostrar tu cuerpo (se escondió al empezar) para verte colgando. Devuelve el rig.
func _show_own_body() -> Node3D:
	var body := _p().get("_rig") as Node3D
	if body != null:
		body.visible = true
		if body.has_method("play"):
			body.call("play", "idle", true, 1.0, ["stand"])  # de pie: las piernas cuelgan (sentado salían hacia adelante)
		if not fx._xf_back.has(body):
			fx._xf_back[body] = body.transform
	return body


## Lunch excedido: te agarra de la nuca y te estrella la cara contra la mesa y el táper, dos veces; luego te
## sostiene ahí y baja su cara de costado a la altura de la tuya.
func _k_shero_mesa_taper() -> void:
	var m := _m()
	var p := _p()
	# La mesa con el táper entre tú y él (sentado en el comedor o de pie junto a una mesa).
	var t_root := Node3D.new()
	fx._stage.add_child(t_root)
	var tt := KillProps.table_taper(t_root)
	var f := fx._dir(0.0)
	var eye := fx._eye()
	var top_y := fx._floor_y() + (0.74 if not p.seated else 0.76)
	t_root.global_position = Vector3(eye.x, top_y, eye.z) + f * 0.5
	t_root.look_at(Vector3(eye.x, top_y, eye.z), Vector3.UP)
	(tt["taper"] as Node3D).position = Vector3(0, 0, -0.28)  # bajo tu cara
	_prop("mesa_taper")
	_grab()
	# Desde el frente: la mano derecha te toma la nuca (los dedos se ven arriba), la izquierda en la mesa.
	_hands(L(-0.3, -0.42, 0.42), L(0.02, 0.15, -0.02), 0.9, 12.0)
	_grip("plana", "garra", L(-0.3, -0.8, 0.42), L(0.0, 0.0, 0.0))  # una mano plana en la mesa, la otra en garra en tu nuca
	_lock(L(0, 0.12, 0.5), 10.0, true, Vector3(-35, 0, 0))
	if not _body("k_inclina", 1.0, 0.15):
		fx._anim(m, ["hunch", "jumpscare_main"], 1.2)
	_vic_plant(top_y, 0.3, 0.27)  # tus manos en la mesa: empujas para zafarte
	_beat("agarre")
	# v0.3.2c (Joan, 11/11): «¡45 MINUTOOOS! ¡NI UN SEGUNDO MÁAAAS!» DURANTE toda la violencia: grita desde el primer
	# golpe. «¡45 MINUTOS!» va sobre los golpes 1 y 2 (y la «OOOS» mientras te frota la cara en el guiso); el tercer
	# golpe cae donde arranca «¡NI UN SEGUNDO MÁS!» ("frase_parte2_s" de la fila) y la «MÁAAAS» la sostiene con su
	# cara de costado pegada a la mesa hasta que mueres. Los tiempos son segundos de la VOZ, no fracciones.
	if await _at(_us if _us > 0.0 else 0.05):
		return
	_scream(false)  # sigue encorvado sobre ti (sin el gesto de embestida)
	var ts := fx._spent
	var vl := fx.voice_total() if fx.voice_total() > 0.5 else 3.8
	var p2 := clampf(float(fx.row.get("frase_parte2_s", vl * 0.56)), 1.2, vl - 0.8)
	var room := maxf(fx.seconds - Screamers.CUT - ts, 1.0)
	var k := minf(1.0, room / (vl + 0.18))  # sin archivo de voz (pruebas): lo mismo, comprimido a lo que haya
	var hits: Array[float] = [0.28 * k, minf(1.08, p2 - 0.75) * k, (p2 + 0.1) * k]
	for i in 3:
		# Abajo de golpe: la cara contra el táper (antes, te echa la cabeza atrás: anticipación).
		var down := 0.16 if i < 2 else 0.2
		await fx._wait(ts + hits[i] - down - fx._spent)
		if fx._done or not is_instance_valid(fx):
			return
		_windup(0.06)
		_wind(down, "k_estrella", 0.07)  # el asesino carga el hombro y descarga con todo el cuerpo
		_fl(0.22, down)
		_pitch(-1.15, down, Tween.TRANS_EXPO, Tween.EASE_IN)
		_head(Vector3(0, -(_base.y - (top_y - fx._floor_y()) - 0.16), -0.2), down, Tween.TRANS_EXPO, Tween.EASE_IN)
		await fx._wait(ts + hits[i] - fx._spent)
		if fx._done or not is_instance_valid(fx):
			return
		_beat("golpe_%d" % (i + 1))
		_impact(1.0, "sfx/kill_golpe_seco", 0.85 + i * 0.1, i == 2)
		fx._snd("sfx/caida_cuerpo", 0.0, 1.3)
		var tp := tt["taper"] as Node3D
		var o := tp.global_position + Vector3(0, 0.06, 0)
		KillProps.debris(fx, 18, Vector3(0.01, 0.006, 0.008), [Color(0.93, 0.9, 0.8), Color(0.55, 0.28, 0.12)], o,
			func(_k: int) -> Vector3: return Vector3(randf_range(-0.9, 0.9), randf_range(0.6, 1.6), randf_range(-0.9, 0.9)), 5.0)
		_prop("arroz")
		_food_smear(i)
		tp.scale = Vector3(1.15, maxf(0.15, 0.55 - i * 0.2), 1.1)
		# La mesa salta con el golpe y, al tercero, el táper sale volando.
		var tr0 := t_root.position
		var jt := t_root.create_tween()
		jt.tween_property(t_root, "position", tr0 + Vector3(0, 0.018, 0), 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jt.tween_property(t_root, "position", tr0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if i == 2:
			var fly := tp.create_tween().set_parallel(true)
			fly.tween_property(tp, "position", tp.position + Vector3(0.42, 0.0, -0.1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			fly.tween_property(tp, "position:y", tp.position.y + 0.3, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			fly.tween_property(tp, "rotation", Vector3(2.6, 1.9, 4.2), 0.5)
			fly.chain().tween_property(tp, "position:y", tp.position.y - 0.02, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			fx._snd("sfx/kill_plastico_quiebra", -3.0, 1.3)
			_prop("taper_vuela")
			_vic("cae", 0.5)
		if i == 1:
			# Te frota la cara en el guiso mientras estira la «OOOS»: «¡come!» (te ahogas con la comida).
			_beat("come")
			fx._snd("sfx/kill_ahogo", 2.0, 1.1)
			KillGore.wet(fx, 0.5)
			var grind_t := maxf((hits[2] - 0.2 - hits[1] - 0.3) / 8.0, 0.03)
			var grind := _tw().set_loops(4)
			grind.tween_property(fx, "cam_off", Vector3(0.025, 0, 0), grind_t)
			grind.tween_property(fx, "cam_off", Vector3(-0.025, 0, 0), grind_t)
			KillGore.pain(fx, true)
		if i < 2:
			# Te levanta la cabeza del pelo para el siguiente golpe.
			var up_at := hits[i] + (0.22 if i == 0 else maxf(hits[2] - 0.2 - hits[1] - 0.3, 0.2))
			await fx._wait(ts + up_at - fx._spent)
			if fx._done or not is_instance_valid(fx):
				return
			var up_t := clampf(hits[i + 1] - up_at - (0.16 if i == 0 else 0.2) - 0.04, 0.06, 0.3)
			_fl(1.0, up_t)
			_pitch(-0.45, up_t, Tween.TRANS_SINE, Tween.EASE_OUT)
			_head(Vector3(0, -0.12, 0), up_t)
	# La mejilla en la mesa; él baja su cara de costado hasta tu altura, pegada a la mesa, sosteniendo la «MÁAAAS».
	_cam("cam_roll", 1.25, 0.3 * k)
	_fl(0.3, 0.3 * k)
	_hands(Vector3.INF, L(0.05, 0.22, -0.12), 0.9, 10.0)  # solo la mano en tu nuca (fuera de cuadro): su cara a la vista
	_grip("", "garra", Vector3.INF, L(0.0, 0.0, 0.0))
	_lock(L(0.5, 0.0, 0.42), 8.0, false, Vector3(0, 0, 0))
	_lock_to(L(0.0, -0.02, 0.36), 0.35 * k)
	if not _body("k_inclina", 1.2, 0.2):
		fx._anim(m, [str(fx.row.get("anim", "jumpscare_main")), "scream"], 1.25)
	var fin_at := maxf(minf(vl * k - 0.55, room - 0.6), hits[2] + 0.4)
	await fx._wait(ts + fin_at - fx._spent)
	if fx._done or not is_instance_valid(fx):
		return
	_final(L(0, 0, 0.2))
	# «…y mueres»: la vista se apaga con la mejilla en la mesa.
	KillGore.red_out(fx, maxf(fx.seconds - Screamers.CUT - fx._spent, 0.1))


## Comida aplastada en la vista (arroz y guiso; no es sangre: también con «Reducido»).
func _food_smear(i: int) -> void:
	if fx._top == null:
		return
	var b := KillGore.Blood.new()
	b.tint = Color(0.62, 0.36, 0.14, 0.9) if i % 2 == 0 else Color(0.92, 0.9, 0.82, 0.92)
	b.amount = 0.6 + 0.2 * i
	b.at = Vector2(0.5 + 0.1 * (i - 1), 0.62)
	b.seed_v = 40 + i
	b.light = KillGore.light()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx._top.add_child(b)
	_prop("comida")


## Lunch dormido (2.ª siesta): abres los ojos en el sofá con él encima; te tapa la boca con la mano (te ahogas)
## y de un jalón te sienta frente a su cara.
func _k_shero_boca_sofa() -> void:
	var m := _m()
	_grab()
	_lock(L(0, 0.02, 0.5), 10.0, false, Vector3(-5, 0, 0))
	_hands(L(0.0, -0.12, 0.1), L(0.26, -0.3, 0.12), 0.05, 12.0)  # la mano plana sobre tu boca; la otra en tu hombro
	_grip("plana", "garra", L(0.0, -0.12, -0.1), L(0.26, -0.5, 0.0))
	if not _body("k_encima", 0.8, 0.1):
		fx._anim(m, ["hunch"], 0.8)
	_vic("brazo_l", 0.014)  # las dos manos al brazo de la mano que te tapa la boca
	_beat("agarre")
	if await _at(0.08):
		return
	_beat("boca")
	_impact(0.6, "sfx/caida_cuerpo", 1.4)
	fx._snd("sfx/kill_ahogo", 0.0)
	_lock_to(L(0, 0.02, 0.36), _s(0.25))
	_cam("cam_off", Vector3(0, -0.02, 0.01), _s(0.25))
	if await _at(0.24):
		return
	# v0.3.2 (Joan): con UNA mano te levanta del sofá en el aire; la otra sigue en tu boca.
	_beat("levanta")
	_hands(L(0.0, -0.12, 0.1), L(0.04, -0.33, 0.16), 0.05, 16.0)  # boca + cuello de la camisa
	_grip("plana", "puño", L(0.0, -0.12, -0.1), L(0.04, -0.33, -0.1))
	_body("k_levanta", 1.0, 0.08, 0.3)  # ya cargado: el empujón de piernas y te sostiene arriba
	_head(Vector3(0, 1.75 - _base.y, -0.1), _s(0.12), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_pitch(0.0, _s(0.12), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_cam("cam_off", Vector3.ZERO, 0.1)
	_lock(L(0, -0.02, 0.4), 14.0, false, Vector3.ZERO)
	_impact(0.8, "sfx/caida_cuerpo", 0.8)
	if await _at(0.34):
		return
	# Intentas gritar: gemidos ahogados detrás de su mano; tus manos le arañan el brazo.
	_beat("forcejeo")
	var v := _vic("brazo_l", 0.03)  # le arañas el brazo de la mano que te tapa la boca
	if v != null:
		v.wounds(0.6)
	_prop("tus_manos")
	fx._snd("sfx/kill_ahogo", 4.0, 1.25)
	fx._snd("sfx/respiracion", 2.0, 1.4)
	var sway := _tw().set_loops(4)
	sway.tween_property(fx, "cam_roll", 0.12, _s(0.04))
	sway.tween_property(fx, "cam_roll", -0.12, _s(0.04))
	if await _at(0.5):
		return
	fx.cam_roll = 0.0
	_scream()  # «¡PONTE LA CAMISETA!»
	if await _at(0.74):
		return
	# Te sigue sofocando hasta que mueres: la vista se cierra, tus manos caen.
	_beat("sofoca")
	_hands(L(0.0, -0.1, 0.09), L(0.04, -0.33, 0.16), 0.0, 20.0)
	_grip("plana", "puño", L(0.0, -0.1, -0.1), L(0.04, -0.33, -0.1))
	_vic("cae", _s(0.2))  # tus manos pierden fuerza y caen
	fx._snd("sfx/kill_ahogo", 0.0, 0.8)
	fx._fov_goal = 40.0
	KillGore.red_out(fx, _s(0.22))
	if await _at(0.86):
		return
	_final(L(0, 0, 0.2))


## AHT / BO: lo ves en el reflejo del monitor, detrás de ti. Te agarra la cabeza por detrás y te la estrella
## contra el monitor dos veces (la pantalla se raja), te jala hacia atrás y te gira hacia su cara.
func _k_shero_monitor() -> void:
	var m := _m()
	_grab()
	_lock(L(0.12, 0.18, -0.32), 40.0, true, Vector3(-20, 0, 0))  # detrás de ti, inclinado sobre tu cabeza (rígido: con retraso, al volver tu cabeza del golpe la cámara se metía en su torso)
	_hands(L(0.0, 0.125, 0.07), L(0.24, -0.24, -0.02), 0.95, 14.0)  # la mano en tu cabeza: los dedos, en garra, asoman por arriba de tu vista
	_grip("garra", "garra", L(0.0, -0.02, 0.02), L(0.2, -0.4, 0.0))
	_body("k_inclina", 1.0, 0.15)
	var desk_y := fx._floor_y() + 0.75
	_vic_plant(desk_y, 0.28, 0.27, 0.012)  # tus manos se aferran al borde del escritorio
	_beat("agarre")
	fx._snd("sfx/respiracion", -2.0, 0.7)
	if await _at(0.1):
		return
	for i in 2:
		_windup(_s(0.03))
		_wind(_s(0.06) + 0.04, "", 0.05)  # sin clip de cuerpo: está detrás de ti (su arco metía la cadera y los brazos delante de la cámara)
		_head(_head_rel() + Vector3(0, -0.08, -0.36), _s(0.06), Tween.TRANS_EXPO, Tween.EASE_IN)
		_pitch(-0.15, _s(0.06))
		if await _at(0.16 + i * 0.2):
			return
		_beat("golpe_%d" % (i + 1))
		_impact(1.0, "sfx/monitor_rompe", 1.0 - i * 0.1, true)
		fx._snd("sfx/kill_golpe_seco", 0.0, 1.0)
		_desk_jolt(1.0, true)  # el monitor se mece, el teclado y la taza saltan
		_head(Vector3.ZERO, _s(0.1), Tween.TRANS_SINE, Tween.EASE_OUT)
		_pitch(0.05, _s(0.1))
		if await _at(0.28 + i * 0.2):
			return
	# Te jala hacia atrás y te gira de un tirón: está ahí, a medio metro.
	_beat("giro")
	fx.lock_on = false
	_yaw_by(PI, _s(0.12), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_hands(L(-0.2, -0.02, 0.1), L(0.2, -0.02, 0.1), 1.0, 12.0)
	_grip("garra", "garra")
	_vic("manotea")  # tus manos se sueltan del escritorio con el giro
	_body("k_grito", 1.0, 0.2)
	if await _at(0.62):
		return
	_lock(L(0, 0, 0.42), 10.0, true)
	_scream()
	_vic("munecas", 0.014)
	if await _at(0.84):
		return
	_final()


## Reflejo KYC: lo ves en el reflejo; te aplasta la cara contra el teclado (las teclas saltan), te sostiene ahí
## y asoma su cara de costado sobre el escritorio, a la altura de la tuya.
func _k_shero_teclado() -> void:
	var m := _m()
	_grab()
	_lock(L(0.1, 0.2, -0.3), 40.0, true, Vector3(-25, 0, 0))
	_hands(L(0.0, 0.125, 0.07), L(-0.22, -0.26, -0.02), 0.95, 14.0)  # sus dedos asoman por arriba de tu vista
	_grip("garra", "garra", L(0.0, -0.02, 0.02), L(-0.2, -0.4, 0.0))  # la palma de la mano de tu cabeza hacia tu cabeza; la del hombro, hacia tu hombro (estaban cruzadas)
	_body("k_inclina", 1.0, 0.15)
	_vic_plant(fx._floor_y() + 0.75, 0.26, 0.3, 0.012)  # tus manos en el escritorio, a los lados del teclado
	_beat("agarre")
	var kb_root := Node3D.new()
	fx._stage.add_child(kb_root)
	KillProps.keyboard(kb_root)
	var e := fx._eye()
	var f := fx._dir(0.0)
	var desk_y := fx._floor_y() + 0.75
	kb_root.global_position = Vector3(e.x, desk_y + 0.012, e.z) + f * 0.45
	kb_root.look_at(Vector3(e.x, desk_y, e.z), Vector3.UP)
	_prop("teclado")
	_windup(_s(0.04))
	if await _at(0.1):
		return
	_wind(_s(0.08), "", 0.05)  # sin clip de cuerpo: está detrás de ti
	_fl(0.25, _s(0.07))
	_pitch(-1.25, _s(0.07), Tween.TRANS_EXPO, Tween.EASE_IN)
	_head(Vector3(0, -(_base.y - 0.75 - 0.14), -0.4), _s(0.07), Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _at(0.18):
		return
	_beat("golpe")
	_impact(1.0, "sfx/kill_golpe_seco", 0.9)
	fx._snd("sfx/kill_teclas", 2.0)
	KillProps.debris(fx, 16, Vector3(0.016, 0.01, 0.016), [Color(0.16, 0.16, 0.18), Color(0.85, 0.85, 0.85)], kb_root.global_position + Vector3(0, 0.02, 0),
		func(_k: int) -> Vector3: return Vector3(randf_range(-1.0, 1.0), randf_range(0.8, 2.0), randf_range(-1.0, 1.0)), 6.0)
	_prop("teclas")
	_desk_jolt(1.0)
	# El teclado salta con el golpe y queda torcido.
	var kb0 := kb_root.position
	var kj := kb_root.create_tween()
	kj.tween_property(kb_root, "position", kb0 + Vector3(0, 0.025, 0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kj.parallel().tween_property(kb_root, "rotation:y", kb_root.rotation.y + 0.22, 0.2)
	kj.tween_property(kb_root, "position", kb0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_cam("cam_roll", -1.2, _s(0.1))
	# Te frota la cara contra el teclado (clics) mientras baja la suya.
	var grind := _tw().set_loops(3)
	grind.tween_property(fx, "cam_off", Vector3(0.025, 0, 0), _s(0.05))
	grind.tween_property(fx, "cam_off", Vector3(-0.02, 0, 0), _s(0.05))
	if await _at(0.34):
		return
	_beat("costado")
	# La mejilla sobre las teclas, mirando a lo largo del escritorio: su cara baja a esa altura y se asoma de lado.
	_pitch(-0.3, _s(0.12))
	_head(Vector3(0, -(_base.y - 0.75 - 0.1), -0.4), _s(0.12))
	_lock(L(-0.5, 0.05, 0.4), 9.0, false, Vector3.ZERO)
	_lock_to(L(0.0, -0.03, 0.5), _s(0.18))
	_hands(L(-0.17, 0.11, -0.03), L(0.27, -0.17, 0.1), 0.95, 10.0)  # la mano en tu cabeza entra por el costado (al centro, su antebrazo le tapaba la cara)
	_grip("garra", "plana", L(-0.05, 0.0, 0.0), L(0.27, -0.5, 0.1))
	_vic("cae", _s(0.3))  # tus manos resbalan del escritorio
	if await _at(0.55):
		return
	_scream()
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Posición de la cabeza respecto de la base (para golpes relativos).
func _head_rel() -> Vector3:
	return _p().head.position - _base


## Lanyard (para abandono y el despido): la cinta de tu cuello al fotocheck que cuelga en el pecho o en su puño.
func _lanyard(hold: Callable) -> Array:
	var cam := fx._cam()
	var b := KillProps.badge(fx._stage, GameState.agent)
	var badge_root := b[0] as Node3D
	var fol := KillProps.follow(fx, L(0, -0.24, 0.34), Vector3(-20, 0, 0))
	badge_root.reparent(fol, false)
	badge_root.position = Vector3.ZERO
	var r := KillProps.rope(fx, Color(0.12, 0.3, 0.75), 0.016, func() -> PackedVector3Array:
		var neck_l := cam.global_transform * L(-0.09, -0.22, 0.0)
		var neck_r := cam.global_transform * L(0.09, -0.22, 0.0)
		var at: Vector3 = hold.call()
		var pts := PackedVector3Array()
		pts.append_array(KillProps.sag(neck_l, at, 6, 0.01))
		var back := KillProps.sag(at, neck_r, 6, 0.01)
		back.remove_at(0)
		pts.append_array(back)
		return pts, 0.15)
	_prop("lanyard")
	_prop("fotocheck")
	return [r, fol, b]


## Abandono: te intercepta en el pasillo, te agarra del lanyard, te jala hasta su cara y lo retuerce: te ahoga.
func _k_shero_lanyard() -> void:
	var m := _m()
	_grab()
	var fol_ref: Array = [null]
	var lan := _lanyard(func() -> Vector3:
		var f0: KillProps.Follow = fol_ref[0]
		return f0.global_position + f0.global_transform.basis.y * 0.04 if f0 != null else fx._eye())
	fol_ref[0] = lan[1]
	var fol := lan[1] as KillProps.Follow
	_hands(Vector3.INF, L(0.0, -0.26, 0.36), 1.1, 14.0)  # el puño cerrado en tu fotocheck
	_grip("", "puño")
	_lock(L(0, -0.04, 0.6), 10.0, true, Vector3(-12, 0, 0))
	fx._snd("sfx/lanyard_tintineo", 2.0)
	_vic("cuello", 0.01)  # tus manos van a la cinta que te aprieta
	_beat("agarre")
	# Carga (se echa atrás con el puño en la cinta) y te jala hasta su cara.
	if await _hit(0.12, 0.2, "k_tira", 0.1):
		return
	_beat("jalon")
	_head(Vector3(0, 0.05, -0.28), _s(0.08), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_impact(0.7, "sfx/kill_cable_tenso", 1.0)
	_lock_to(L(0, 0.0, 0.5), _s(0.12))
	var tw := _tw()
	tw.tween_property(fol, "pos", L(0.0, -0.17, 0.3), _s(0.1))
	if await _at(0.26):
		return
	# Retuerce el lanyard: el puño sube y gira, la cinta se tensa y te corta el aire.
	_beat("ahorca")
	_hands(L(-0.08, -0.16, 0.3), L(0.02, -0.12, 0.28), 1.2, 8.0)
	_grip("puño", "puño")
	_body("k_ahorca", 1.0, 0.2)
	_vic("cuello", 0.02)
	var tw2 := _tw().set_parallel(true)
	tw2.tween_property(fol, "pos", L(0.0, -0.1, 0.25), _s(0.3))
	tw2.tween_property(fol, "rot", Vector3(-30, 0, 160), _s(0.3))
	_head(Vector3(0, 0.12, -0.28), _s(0.3))
	_cam("cam_roll", -0.18, _s(0.16))
	fx._snd("sfx/kill_ahogo", 2.0)
	fx._red = 0.5
	if await _at(0.32):
		return
	# v0.3.2 (Joan): «retorciéndolo tu cuello de manera grotesca»: la vista gira de más (el cuello cede), crujido.
	_beat("cuello")
	_wind(_s(0.07), "k_cachetada", 0.05)  # el tirón seco de las dos manos
	_cam("cam_roll", -0.95, _s(0.07), Tween.TRANS_EXPO, Tween.EASE_IN)
	KillGore.bone(fx, 1.0)
	_impact(0.9, "sfx/kill_golpe_seco", 0.7)
	KillGore.splatter(fx, 0.5, Vector2(0.3, 0.7))
	_vic("cae", 0.35)  # el cuello cedió: tus manos caen
	if await _at(0.42):
		return
	_scream()
	_cam("cam_roll", -0.75, _s(0.2))
	if await _at(0.82):
		return
	_final(L(0, 0, 0.2))


## Regreso tardío del training: te agarra del lanyard, te tira al piso de un jalón y te arrastra por la alfombra
## hacia tu sitio; se detiene, se agacha sobre ti y te grita.
func _k_shero_lanyard_arrastre() -> void:
	var m := _m()
	_grab()
	var lan := _lanyard(func() -> Vector3:
		var hp: Vector3 = fx._rig.last_hand_r if fx._rig != null and fx._rig.last_hand_r != Vector3.INF else fx._eye()
		return hp)
	var fol := lan[1] as KillProps.Follow
	fol.visible = false  # el fotocheck queda en su puño (lo tapa la mano)
	_hands(Vector3.INF, L(0.0, -0.36, 0.3), 1.1, 14.0)
	_grip("", "puño")
	_lock(L(0, -0.02, 0.62), 10.0, true, Vector3(-10, 0, 0))
	fx._snd("sfx/lanyard_tintineo", 2.0)
	_vic("cuello", 0.01)
	_beat("agarre")
	# Carga y te tira al piso de un jalón.
	if await _hit(0.1, 0.2, "k_tira", 0.1):
		return
	# Al piso de un jalón: caes de rodillas y de cara.
	_beat("suelo")
	_head(Vector3(0, 0.35 - _base.y, -0.25), _s(0.12), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(0.35, _s(0.12))
	_impact(1.0, "sfx/caida_cuerpo", 0.85)
	_lock(L(0, 0.35, 1.0), 9.0, true, Vector3(-30, 0, 0))
	_hands(Vector3.INF, L(0.0, -0.18, 0.55), 1.1, 10.0)
	_grip("", "puño")
	_vic("manotea")
	_chair_away()
	if not _body("k_arrastra", 1.4, 0.2):
		fx._anim(m, ["walk", "run"], 0.9)
	if await _at(0.24):
		return
	# Te arrastra: camina hacia atrás y la alfombra pasa debajo (tirones, el lanyard tenso).
	_beat("arrastre")
	fx._snd("sfx/kill_arrastre", 0.0)
	_vic("cuello", 0.03)  # te agarras de la cinta para que no te ahorque mientras te arrastra
	var back := -fx._dir(0.0)
	var p := _p()
	var from := p.global_position
	var tw := _tw()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(p):
			p.global_position = from - back * (u * 0.9) + Vector3(0, 0, 0)
			fx.cam_off = Vector3(0, sin(u * 18.0) * 0.012, 0)
			fx.cam_roll = sin(u * 9.0) * 0.08, 0.0, 1.0, _s(0.34))
	if await _at(0.6):
		return
	# Se agacha sobre ti.
	if not _body("k_encima", 1.0, 0.3):
		fx._anim(m, ["hunch"], 1.0)
	_lock(L(0, 0.05, 0.42), 8.0, false, Vector3(10, 0, 0))
	_hands(L(-0.18, -0.08, 0.16), L(0.0, -0.3, 0.2), 1.0, 10.0)
	_grip("garra", "puño")
	_scream()
	_vic("cara", 0.014)
	if await _at(0.84):
		return
	_final(L(0, 0, 0.22))


## Cable del headset: de tu oreja derecha a `hold` (su puño), colgando un poco.
func _headset_cable(hold: Callable, from_local: Vector3 = L(0.11, -0.04, -0.01)) -> KillProps.Rope:
	var cam := fx._cam()
	var r := KillProps.rope(fx, Color(0.07, 0.07, 0.08), 0.012, func() -> PackedVector3Array:
		var a := cam.global_transform * from_local
		return KillProps.sag(a, hold.call(), 12, 0.05))
	_prop("cable_headset")
	return r


func _hand_r_world() -> Vector3:
	return fx._rig.last_hand_r if fx._rig != null and fx._rig.last_hand_r != Vector3.INF else fx._eye() + fx._dir(0.0) * 0.5


func _hand_l_world() -> Vector3:
	return fx._rig.last_hand_l if fx._rig != null and fx._rig.last_hand_l != Vector3.INF else fx._eye() + fx._dir(0.0) * 0.5


## Inasistencia a coaching: sale de la pantalla, te agarra el cable del headset y te arranca de la silla de un
## jalón; caes al piso a sus pies y te arrastra del cable hasta su cara.
func _k_shero_cable_arrastre() -> void:
	var m := _m()
	_grab()
	_headset_cable(_hand_r_world)
	_hands(Vector3.INF, L(0.2, -0.08, 0.45), 1.1, 12.0)
	_grip("", "puño")
	_lock(L(0, 0.02, 0.62), 10.0, true, Vector3(-10, 0, 0))
	fx._snd("sfx/auricular_pitido", -4.0, 0.9)
	_vic("escudo")
	_beat("agarre")
	# Carga (se echa atrás con el cable en el puño) y te arranca de la silla.
	if await _hit(0.14, 0.2, "k_tira", 0.1):
		return
	_beat("jalon")
	_vic("manotea")
	_chair_away()
	fx._snd("sfx/kill_cable_tenso", 2.0)
	_hands(Vector3.INF, L(0.25, -0.15, 0.75), 1.1, 18.0)
	_head(Vector3(0, -0.1, -0.45), _s(0.1), Tween.TRANS_EXPO, Tween.EASE_IN)
	_cam("cam_roll", 0.35, _s(0.1))
	if await _at(0.24):
		return
	# Al piso.
	_beat("suelo")
	# v0.3.2e: sentado, el jalón te tira DE BRUCES SOBRE TU ESCRITORIO (antes caías «al piso» por delante: la cabeza
	# quedaba debajo del tablero y él, del otro lado, no se veía); de pie, al piso a sus pies.
	var on_desk := _p().seated
	if on_desk:
		_head(Vector3(0, 0.88 - _base.y, -0.42), _s(0.1), Tween.TRANS_QUAD, Tween.EASE_IN)
		_pitch(0.3, _s(0.14))
		_fl(0.3, _s(0.1))
	else:
		_head(Vector3(0, 0.3 - _base.y, -0.55), _s(0.1), Tween.TRANS_QUAD, Tween.EASE_IN)
		_pitch(0.45, _s(0.14))
	_impact(1.0, "sfx/caida_cuerpo", 0.8)
	fx._snd("sfx/auricular_pitido", 0.0, 0.7)
	if on_desk:
		_desk_jolt(1.0, true)  # el monitor se mece, el teclado y la taza saltan
		_vic_plant(fx._floor_y() + 0.75, 0.3, 0.3, 0.02)  # tus manos buscan apoyo en el escritorio
		_lock(L(0, 0.14, 0.72), 8.0, true, Vector3(-35, 0, 0))
	else:
		_lock(L(0, 0.15, 0.85), 8.0, true, Vector3(-35, 0, 0))
	_body("k_tira", 1.3, 0.2)  # te recoge del cable, mano sobre mano
	if await _at(0.4):
		return
	# Te recoge del cable, mano sobre mano, hasta su cara.
	_fl(1.0, _s(0.2))
	_cam("cam_roll", 0.1, _s(0.2))
	_lock_to(L(0, 0.0, 0.5), _s(0.2))
	_hands(L(-0.04, -0.1, 0.25), L(0.1, -0.05, 0.3), 1.1, 10.0)
	_grip("puño", "puño")
	_vic("munecas", 0.016)  # te agarras de sus puños
	if not _body("k_inclina", 1.2, 0.25):
		fx._anim(m, ["hunch"], 1.0)
	if await _at(0.5):
		return
	_scream()
	_vic("cara", 0.014)
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Llamadas perdidas: suenan los teléfonos; se te pierde de vista y el cable del headset te rodea el cuello por
## detrás; te jala hacia atrás, la silla se vuelca y desde el piso lo ves de cabeza, encima de ti.
func _k_shero_cable_cuello() -> void:
	var m := _m()
	var cam := fx._cam()
	_grab()
	# Se va detrás de ti (un parpadeo y ya no está delante).
	_flash(Color(0, 0, 0, 1), 0.1)
	_lock(L(0.0, 0.25, -0.4), 30.0, true, Vector3(-30, 0, 0))
	_hands(L(-0.22, -0.2, -0.08), L(0.22, -0.2, -0.08), 1.1, 12.0)
	_grip("puño", "puño")
	_body("k_tira", 1.0, 0.15)
	_vic("cuello", 0.014)  # tus dedos buscan el cable en tu cuello
	KillProps.rope(fx, Color(0.07, 0.07, 0.08), 0.015, func() -> PackedVector3Array:
		var pts := PackedVector3Array()
		for i in 9:
			var a := lerpf(-1.4, 1.4, i / 8.0)
			pts.append(cam.global_transform * Vector3(sin(a) * 0.13, -0.15 - 0.02 * cos(a), -cos(a) * 0.14 - 0.03))
		return pts)
	_prop("cable_headset")
	_beat("agarre")
	if await _at(0.08):
		return
	_beat("ahorca")
	fx._snd("sfx/kill_cable_tenso", 2.0)
	fx._snd("sfx/kill_ahogo", 0.0)
	_head(Vector3(0, 0, 0.12), _s(0.12), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_pitch(0.35, _s(0.2))
	if await _at(0.16):
		return
	# v0.3.2 (Joan): «te lo amarra para ahorcarte»: segunda vuelta del cable y el nudo de un tirón.
	_beat("amarra")
	KillProps.rope(fx, Color(0.06, 0.06, 0.07), 0.014, func() -> PackedVector3Array:
		var pts := PackedVector3Array()
		for i in 9:
			var a := lerpf(-1.4, 1.4, i / 8.0)
			pts.append(cam.global_transform * Vector3(sin(a) * 0.12, -0.13 - 0.02 * cos(a), -cos(a) * 0.13 - 0.03))
		return pts)
	fx._snd("sfx/kill_cable_tenso", 4.0, 0.8)
	_impact(0.8, "sfx/kill_cable_tenso", 0.9)
	_hands(L(-0.05, -0.18, -0.12), L(0.05, -0.18, -0.12), 1.2, 20.0)  # los puños juntos: el nudo
	_grip("puño", "puño")
	_head(Vector3(0, 0.04, 0.16), _s(0.05), Tween.TRANS_EXPO, Tween.EASE_OUT)
	fx._fov_goal = 52.0
	_vic("cuello", 0.03)
	if await _at(0.24):
		return
	_hands(L(-0.22, -0.2, -0.08), L(0.22, -0.2, -0.08), 1.1, 12.0)
	_grip("puño", "puño")
	# La silla se vuelca hacia atrás (contigo): tus piernas quedan arriba, miras al techo y el piso te golpea la espalda.
	_beat("silla_cae")
	_head(Vector3(0, 0.35 - _base.y, 0.55), _s(0.16), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(1.35, _s(0.16), Tween.TRANS_QUAD, Tween.EASE_IN)
	fx._snd("sfx/kill_silla_cae", 2.0)
	if _p().seated:
		_chair_tip(_s(0.16))
		var v0 := _victim()
		if v0 != null:
			v0.body("v_piernas", 1.3, 0.15)
	if await _at(0.4):
		return
	_impact(1.0, "sfx/caida_cuerpo", 0.75)
	var fd := Vector3(0, 0.35 - _base.y, 0.55)
	var hb := _head(fd + Vector3(0, 0.05, 0), 0.07)  # la cabeza rebota en el piso
	hb.tween_property(_p().head, "position", _base + fd, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# De cabeza: su cara invertida sobre la tuya, el cable en sus puños.
	_beat("de_cabeza")
	_lock(L(0, 0.18, 0.42), 9.0, false, Vector3(0, 0, 180))
	_hands(L(-0.12, -0.24, 0.1), L(0.12, -0.24, 0.1), 1.1, 10.0)
	_grip("puño", "puño")
	_body("k_ahorca", 1.0, 0.25)
	# Invertida, sus ojos quedan ABAJO: la cara sube 11 cm y se queda a 0,62 m para que los ojos queden sobre la frase
	# escrita y la boca, arriba, dentro del cuadro (a 0,5 m no caben las dos cosas: 26 cm de los ojos a la boca).
	_lock_to(L(0, 0.11, 0.62), _s(0.2))
	if await _at(0.52):
		return
	_scream()
	_vic("cuello", 0.012)
	var v1 := _victim()
	if v1 != null:
		v1.create_tween().tween_property(v1, "strength", 0.4, _s(0.25))
		if v1.anim != null:
			v1.anim.speed_scale = 0.5
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Fuera de tu isla: te lanza el cable del headset como un lazo al cuello y te recoge, mano sobre mano, hasta
## su cara (cada tirón te arrastra los pies).
func _k_shero_cable_lazo() -> void:
	var m := _m()
	var cam := fx._cam()
	_grab()
	_lock(L(0, 0.0, 0.9), 10.0, true, Vector3(-5, 0, 0))
	_hands(L(-0.15, -0.1, 0.75), L(0.12, -0.1, 0.7), 1.1, 14.0)
	_grip("puño", "puño")
	_body("k_tira", 0.8, 0.15)
	_vic("escudo")
	_beat("agarre")
	# El lazo: dos vueltas de cable grueso, cerca de la cámara en la parte baja de la vista (alrededor de tu cuello),
	# que se cierran y siguen hasta sus puños.
	var coil := [0.22]
	KillProps.rope(fx, Color(0.17, 0.17, 0.19), 0.03, func() -> PackedVector3Array:
		var pts := PackedVector3Array()
		var r: float = coil[0]
		for i in 26:
			var a := lerpf(-PI * 0.5, PI * 3.5, i / 25.0)
			var ri := r * (1.0 - 0.1 * (i / 25.0))
			pts.append(fx.view_xf() * L(sin(a) * ri, -0.16 + cos(a) * ri * 0.3 - 0.02 * (i / 25.0), 0.3 + cos(a) * ri * 0.45))
		var front := fx.view_xf() * L(0, -0.16 - r * 0.3, 0.3 - r * 0.45)
		pts.append_array(KillProps.sag(front, _hand_l_world(), 8, 0.04))
		pts.append_array(KillProps.sag(_hand_l_world(), _hand_r_world(), 5, 0.06))
		return pts, 0.08)
	_prop("cable_headset")
	fx._snd("sfx/kill_cable_tenso", 2.0, 1.2)
	if await _at(0.1):
		return
	_beat("lazo")
	_impact(0.6, "sfx/kill_cable_tenso", 0.9)
	# El lazo se cierra: las vueltas se aprietan contra tu cuello.
	_beat("aprieta")
	var tc := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tc.tween_method(func(v: float) -> void: coil[0] = v, 0.22, 0.1, _s(0.18))
	fx._snd("sfx/kill_ahogo", -2.0)
	_cam("cam_pitch", -0.12, _s(0.1))
	_vic("cuello", 0.016)  # tus manos al cable que se cierra
	# Tres tirones: en cada uno se echa atrás (carga), tira, y tú te vas un paso hacia él; alterna las manos.
	for i in 3:
		if await _hit(0.2 + i * 0.1, 0.14, "k_tira", 0.08):
			return
		if i == 0:
			_beat("recoge")
		var d := 0.75 - i * 0.14
		_lock_to(L(0, 0.0, d - 0.08), _s(0.08), Tween.TRANS_EXPO, Tween.EASE_OUT)
		_head(Vector3(0, -0.02, -0.1 * (i + 1)), _s(0.06), Tween.TRANS_EXPO, Tween.EASE_OUT)
		if i % 2 == 0:
			_hands(L(-0.12, -0.24, d * 0.6), L(0.12, -0.1, d), 1.1, 18.0)
		else:
			_hands(L(-0.12, -0.1, d), L(0.12, -0.24, d * 0.6), 1.1, 18.0)
		_impact(0.5, "sfx/kill_cable_tenso", 1.0 + i * 0.1)
		fx._snd("sfx/kill_ahogo", -6.0 + i * 2.0)
		_grip("puño", "puño")
		var r_from: float = coil[0]
		_tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_method(func(v: float) -> void: coil[0] = v, r_from, r_from - 0.012, _s(0.05))
	if await _at(0.5):
		return
	fx.cam_pitch = 0.0
	_hands(L(-0.18, -0.08, 0.12), L(0.18, -0.08, 0.12), 1.0, 12.0)
	_grip("garra", "garra")
	_body("k_ahorca", 1.0, 0.2)
	_vic("munecas", 0.012)
	_lock_to(L(0, 0, 0.5), _s(0.1))
	if await _at(0.58):
		return
	_scream()
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Available bajo: te agarra de la mandíbula con una mano y con la otra te pega a la cara la lista impresa con
## tu % en rojo; te hace asentir leyéndola; la arruga y te grita.
func _k_shero_lista() -> void:
	var m := _m()
	_grab()
	var pct := _detail_or(str(int(Metrics.available_pct())))
	var fol := KillProps.follow(fx, L(0.06, -0.02, 0.5), Vector3(0, 0, 4))
	KillProps.sheet(fol, tr("SCR_LIST_TITLE"), KillProps.t("SCR_K_LIST_BODY", "{agente}\nAVAILABLE {pct} %").replace("{agente}", GameState.agent.to_upper()).replace("{pct}", pct), Color(0.8, 0.1, 0.08), "%s %%" % pct)
	_prop("lista")
	_lock(L(0, 0.02, 0.62), 10.0, true, Vector3(-10, 0, 0))
	_hands(L(0.0, -0.18, 0.13), L(0.12, -0.12, 0.5), 0.6, 14.0)  # mandíbula; la otra sostiene la lista
	_grip("garra", "pinza", L(0.0, -0.05, 0.0), Vector3.INF)
	_vic("brazo_l")  # las dos manos al brazo que te tiene de la mandíbula
	_beat("agarre")
	fx._snd("sfx/kill_papel_golpe", 0.0, 1.0)
	if await _at(0.1):
		return
	_beat("lista")
	_wind(_s(0.08), "k_cachetada", 0.06)  # carga el brazo y te estampa la lista en la cara
	var tw := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(fol, "pos", L(0.0, 0.0, 0.17), _s(0.08))
	_hands(L(0.0, -0.18, 0.12), L(0.1, -0.04, 0.2), 0.6, 18.0)
	_grip("garra", "plana", L(0.0, -0.05, 0.0), L(0.0, 0.0, 0.0))
	if await _at(0.18):
		return
	_impact(0.6, "sfx/kill_papel_golpe", 1.0)
	# v0.3.2 (Joan): «mandíbula super abierta»: detrás de la hoja la suya se desencaja (crujido) y no se cierra.
	_beat("mandibula")
	_jaw(2.4, _s(0.12))
	KillGore.bone(fx, 0.7)
	KillGore.screech(fx, -4.0)
	# Te hace asentir (te mueve la cabeza de la mandíbula): «lee».
	_beat("lee")
	var nod := _tw().set_loops(3)
	nod.tween_property(fx, "cam_pitch", -0.16, _s(0.06))
	nod.tween_property(fx, "cam_pitch", 0.06, _s(0.06))
	if await _at(0.5):
		return
	# La arruga y la tira: su cara detrás.
	fx._snd("sfx/kill_papel_rasga", 2.0)
	var tw2 := _tw().set_parallel(true)
	tw2.tween_property(fol, "pos", L(0.6, -0.5, 0.4), _s(0.1))
	tw2.tween_property(fol, "rot", Vector3(40, 60, 80), _s(0.1))
	_hands(L(0.0, -0.17, 0.12), L(0.22, -0.02, 0.12), 0.8, 14.0)
	_grip("garra", "garra", L(0.0, -0.05, 0.0), Vector3.INF)
	_body("k_grito", 1.0, 0.2)
	fx.cam_pitch = 0.0
	_lock_to(L(0, 0, 0.5), _s(0.1))
	if await _at(0.56):
		return
	_scream()
	_vic("brazo_l", 0.02)
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Mandíbula del asesino: jaw_mult del shader (1,35 de base en v0.3.2) y la deformación al máximo.
func _jaw(mult: float, t: float) -> void:
	if fx._rig == null or not is_instance_valid(fx._rig):
		return
	_tw().tween_property(fx._rig, "jaw_mult", mult, maxf(t, 0.02))
	_tw().tween_property(fx._rig, "deform", 1.0, maxf(t, 0.02))


## Work avoiding: a oscuras, dos manos te tapan los ojos por detrás (luz entre los dedos, su respiración en tu
## oreja); vuelve la luz y está DELANTE de ti, a un palmo, gritando.
func _k_shero_ojos() -> void:
	var m := _m()
	_grab()
	fx._bg.color = Color(0, 0, 0, 0.55)
	_lock(L(0.0, 0.14, -0.26), 40.0, true, Vector3(-25, 0, 0))
	_hands(L(-0.3, 0.02, 0.08), L(0.3, 0.02, 0.08), 0.0, 9.0)  # entran por los costados…
	_beat("agarre")
	if await _at(0.06):
		return
	_hands(L(-0.065, 0.0, 0.15), L(0.065, 0.0, 0.15), -0.2, 10.0)  # …y te tapan los ojos (manos planas)
	_grip("plana", "plana")
	_vic("munecas", 0.012)  # te agarras de las muñecas de las manos que te tapan los ojos
	_beat("ojos")
	fx._snd("sfx/respiracion", 2.0, 0.65)
	fx._snd("sfx/kill_susurro", 0.0)
	_cam("cam_pitch", 0.12, _s(0.2))
	_cam("cam_roll", -0.08, _s(0.2))
	var tw := _tw()
	tw.tween_property(fx._bg, "color", Color(0, 0, 0, 0.8), _s(0.2))
	if await _at(0.24):
		return
	# v0.3.2 (Joan: «te los saca muy grotesco»; intermedio entre explícito e implícito): un instante los pulgares
	# se hunden (las manos avanzan hacia el centro, crujido húmedo), la sangre brota en la vista y todo se pone rojo.
	_beat("pulgares")
	fx._bg.color = Color(0, 0, 0, 0.2)
	_hands(L(-0.03, 0.0, 0.1), L(0.03, 0.0, 0.1), 0.8, 30.0)
	_grip("garra", "garra")
	_vic("munecas", 0.035)  # tiras de sus muñecas con todo
	_cam("cam_pitch", 0.2, _s(0.05))
	fx._snd("sfx/kill_ahogo", 4.0, 1.3)
	var red := KillGore.eyes(fx, _s(0.12))
	if await _at(0.44):
		return
	# La luz vuelve (roja, entre la sangre): las manos ya no están; él sí, delante.
	_beat("luz")
	fx._snd("sfx/parpadeo", 0.0)
	fx._bg.color = Color(0, 0, 0, 0.0)
	if red != null and is_instance_valid(red):
		red.create_tween().tween_property(red, "color", Color(0.45, 0.0, 0.0, 0.42), 0.12)
	fx.cam_pitch = 0.0
	fx.cam_roll = 0.0
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 30.0)
	_grip("garra", "garra")
	_lock(L(0, 0.0, 0.3), 60.0, false, Vector3.ZERO)
	_body("k_grito", 1.0, 0.0)
	_impact(0.8, "sfx/caida_cuerpo", 1.3)
	_scream()
	_vic("ojos", 0.012)  # las manos a tus ojos…
	_vic_later(0.5, "ciego", 0.022)  # …y bajan temblando: él, delante, gritándote
	if await _at(0.8):
		return
	_final(L(0, 0, 0.18))


## WW sin Ack: te estampa la hoja del Written Warning en la cara (todo blanco, el texto al revés a contraluz), te
## la aprieta mientras te ahogas, te la arranca y está gritándote.
func _k_shero_hoja_ww() -> void:
	var m := _m()
	_grab()
	var fol := KillProps.follow(fx, L(0.2, -0.05, 0.55), Vector3(0, 0, 6))
	KillProps.sheet(fol, tr("SCR_WW_TITLE"), tr("SCR_WW_BODY"), Color(0.8, 0.1, 0.08), "WW")
	_prop("hoja_ww")
	_lock(L(0, 0.02, 0.6), 10.0, true, Vector3(-10, 0, 0))
	_hands(L(-0.2, -0.05, 0.12), L(0.18, 0.0, 0.52), 0.9, 14.0)
	_grip("garra", "plana", Vector3.INF, L(0.0, 0.0, 0.0))
	_vic("escudo")
	_beat("agarre")
	if await _at(0.1):
		return
	# ¡Plaf!: carga el brazo abierto y te estampa la hoja en la cara, su mano abierta detrás.
	_beat("cachetada")
	_wind(_s(0.04) + 0.05, "k_cachetada", 0.07)
	var tw := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(fol, "pos", L(0.0, 0.0, 0.085), _s(0.05))
	tw.parallel().tween_property(fol, "rot", Vector3(0, 0, -3), _s(0.05))
	_hands(L(-0.2, -0.05, 0.12), L(0.02, 0.0, 0.16), 0.0, 22.0)
	if await _at(0.14):
		return
	_impact(0.9, "sfx/kill_papel_golpe", 1.0)
	_head(Vector3(0, 0, 0.08), _s(0.06))
	fx._snd("sfx/kill_ahogo", -2.0)
	_grip("garra", "plana", Vector3.INF, L(0.0, 0.0, 0.0))
	_body("k_ahorca", 1.0, 0.2)  # te la aprieta con el peso del cuerpo
	_vic("boca", 0.02)  # arañas la hoja que te tapa la cara
	var crump := _tw().set_loops(4)
	crump.tween_property(fol, "pos", L(0.006, 0.004, 0.08), _s(0.05))
	crump.tween_property(fol, "pos", L(-0.004, -0.003, 0.09), _s(0.05))
	if await _at(0.5):
		return
	# Te la arranca de la cara: ahí está.
	_beat("arranca")
	fx._snd("sfx/kill_papel_rasga", 5.0)
	# v0.3.2 (Joan): «te la arranca con una parte de tu rostro»: la hoja sale con la marca de tu cara en sangre;
	# la vista queda rasgada y roja (intermedio: se ve la hoja manchada un instante, no la herida).
	_beat("rostro")
	if KillGore.enabled():
		var print_q := KillProps.box(fol, Vector3(0.13, 0.17, 0.002), Color(0.38, 0.0, 0.02, 0.92), Vector3(0, 0.0, 0.004))
		print_q.name = "MarcaRostro"
		KillGore.wet(fx, 1.0)
		KillGore.splatter(fx, 1.2, Vector2(0.5, 0.42))
		KillGore.splatter(fx, 0.6, Vector2(0.35, 0.6))
	KillGore.screech(fx, 0.0)
	_impact(0.9, "sfx/kill_golpe_seco", 1.1)
	var tw2 := _tw().set_parallel(true)
	tw2.tween_property(fol, "pos", L(0.42, 0.18, 0.3), _s(0.06))
	tw2.tween_property(fol, "rot", Vector3(-20, 40, 30), _s(0.06))
	tw2.chain().tween_property(fol, "pos", L(0.8, 0.45, 0.3), _s(0.06))
	_hands(L(-0.2, -0.05, 0.12), L(0.5, 0.25, 0.3), 0.9, 18.0)
	_grip("garra", "puño")
	_lock(L(0, 0, 0.32), 30.0, false, Vector3.ZERO)
	_body("k_grito", 1.0, 0.1)
	_scream()
	_vic("ojos", 0.02)  # las manos a tu cara…
	_vic_later(0.45, "ciego", 0.025)  # …y bajan temblando (su cara a la vista mientras grita)
	var vv := _victim()
	if vv != null:
		vv.set_param("blood", 0.7 if KillGore.enabled() else 0.0)
	if await _at(0.82):
		return
	_final(L(0, 0, 0.18))


## 3.er WW (despido): a oscuras (las luces ya murieron en fila), te arranca el fotocheck del cuello (la cinta se
## rompe), te lo pone delante de los ojos y lo PARTE en dos; grita ¡ESTÁS DESPEDIDO! y te empuja hacia atrás, a la
## oscuridad, mientras se apagan las últimas luces.
func _k_shero_fotocheck() -> void:
	var m := _m()
	_grab()
	var held: Array = [false]
	var lan := _lanyard(func() -> Vector3:
		if held[0]:
			return _hand_r_world()
		return fx._cam().global_transform * L(0, -0.2, 0.34))
	var rope := lan[0] as KillProps.Rope
	var fol := lan[1] as KillProps.Follow
	var b: Array = lan[2]
	_lock(L(0, 0.0, 0.62), 10.0, true, Vector3(-10, 0, 0))
	_hands(Vector3.INF, L(0.0, -0.24, 0.36), 1.1, 14.0)
	_grip("", "puño")
	_vic("cuello", 0.01)
	_beat("agarre")
	# Carga y lo arranca: la cinta se revienta.
	if await _hit(0.12, 0.18, "k_tira", 0.09):
		return
	_beat("arranca")
	held[0] = true
	fx._snd("sfx/kill_cable_tenso", 3.0, 1.3)
	fx._snd("sfx/lanyard_tintineo", 3.0, 0.8)
	_impact(1.0, "sfx/kill_cable_tenso", 1.2)
	# v0.3.2 (Joan): «a la fuerza haciéndote caer»: el tirón te tira de rodillas; él te mira desde arriba.
	_beat("caes")
	_head(Vector3(0, -0.7, -0.15), _s(0.07), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(0.45, _s(0.08))
	_lock(L(0, 0.32, 0.62), 12.0, true, Vector3(-10, 0, 0))
	_vic("manotea")
	_chair_away()
	if await _at(0.18):
		return
	_impact(0.9, "sfx/caida_cuerpo", 0.8)
	rope.visible = false
	var tw := _tw().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fol, "pos", L(0.0, -0.01, 0.15), _s(0.12))
	tw.tween_property(fol, "rot", Vector3(0, 0, 0), _s(0.12))
	tw.tween_property(b[0] as Node3D, "scale", Vector3.ONE * 1.25, _s(0.12))
	_hands(L(-0.055, -0.05, 0.19), L(0.055, -0.05, 0.19), 1.0, 16.0)
	_grip("pinza", "pinza")
	_body("k_inclina", 1.0, 0.25)
	var vr := _victim()
	if vr != null:  # estiras las manos hacia tu fotocheck
		vr.struggle(0.012, 7.0)
		vr.both(L(-0.16, -0.16, 0.26), L(0.16, -0.16, 0.26), "suelta", L(0.0, -0.05, 0.19), 3.2)
	if await _at(0.34):
		return
	# Lo parte en dos delante de tus ojos.
	_beat("parte")
	fx._snd("sfx/kill_plastico_quiebra", 4.0)
	_impact(0.5, "sfx/kill_plastico_quiebra", 1.0)
	var l_half := b[1] as Node3D
	var r_half := b[2] as Node3D
	var tw2 := _tw().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw2.tween_property(l_half, "rotation", Vector3(0.3, 0.9, -0.5), _s(0.1))
	tw2.tween_property(r_half, "rotation", Vector3(0.3, -0.9, 0.5), _s(0.1))
	tw2.tween_property(l_half, "position", Vector3(-0.06, -0.01, 0.01), _s(0.1))
	tw2.tween_property(r_half, "position", Vector3(0.06, -0.01, 0.01), _s(0.1))
	_hands(L(-0.13, -0.07, 0.2), L(0.13, -0.07, 0.2), 1.0, 16.0)
	_grip("puño", "puño")
	if vr != null:
		vr.jolt("l", Vector3(-1.0, -0.6, 0.2))
		vr.jolt("r", Vector3(1.0, -0.6, 0.2))
	if await _at(0.44):
		return
	_scream()
	_body("k_grito", 1.0, 0.15)
	_vic("escudo")
	_lock_to(L(0, -0.02, 0.5), _s(0.07), Tween.TRANS_QUAD, Tween.EASE_OUT)  # se agacha a gritártelo (0,5 s con la cara fuera de cuadro era mucho)
	# Te empuja hacia atrás, a la oscuridad (carga con los dos brazos y descarga): caes y se apagan las últimas luces.
	if await _hit(0.7, 0.18, "k_azote", 0.08):
		return
	_beat("empuja")
	fol.visible = false
	_impact(0.7, "sfx/kill_golpe_seco", 0.9)
	_vic("manotea")
	_hands(L(-0.15, -0.3, 0.18), L(0.15, -0.3, 0.18), 0.3, 20.0)
	_grip("plana", "plana")
	_head(Vector3(0, -0.5, 0.6), _s(0.2), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(0.5, _s(0.2))
	fx.lock_on = false
	for l in fx._room_lights():
		var li := l as Light3D
		if li.light_energy > 0.01:
			fx._lights_off.append([li, li.light_energy])
			li.light_energy = 0.0
	fx.gfx_dark(0.0)
	_tw().tween_property(fx._bg, "color", Color(0, 0, 0, 0.85), _s(0.2))
	fx._snd("sfx/parpadeo", 0.0, 0.7)
	if await _at(0.88):
		return
	_final()


## Tres molestos: la impresora escupe tickets sin parar; te caen encima a montones y él te hunde en la pila con
## las manos en tu cabeza y hombros hasta que solo ves papel… y su cara.
func _k_shero_tickets() -> void:
	var m := _m()
	var cam := fx._cam()
	_grab()
	_lock(L(0, 0.15, 0.6), 10.0, true, Vector3(-25, 0, 0))
	_hands(L(-0.16, 0.12, 0.08), L(0.18, -0.22, 0.12), 0.7, 12.0)  # una en tu cabeza, otra en tu hombro
	_grip("garra", "garra", L(-0.1, 0.0, 0.0), L(0.18, -0.5, 0.0))
	_body("k_inclina", 1.0, 0.15)
	_vic("escudo")  # te cubres de los tickets que caen
	_beat("agarre")
	fx._snd("sfx/impresora", 3.0, 1.6)
	fx._snd("sfx/impresora", 0.0, 2.1)
	if await _at(0.06):
		return
	_beat("avalancha")
	_prop("tickets")
	for wave in 3:
		var top := cam.global_transform * L(0, 0.9, 0.35)
		KillProps.debris(fx, 16, Vector3(0.085, 0.002, 0.2), [Color(0.95, 0.95, 0.92), Color(0.88, 0.9, 0.86)], top,
			func(_k: int) -> Vector3: return Vector3(randf_range(-0.8, 0.8), randf_range(-1.5, -0.2), randf_range(-0.8, 0.8)), 2.0)
		if await _at(0.1 + wave * 0.08):
			return
	# Te hunde en la pila: la vista baja y el papel sube alrededor.
	_beat("hunde")
	_head(Vector3(0, -0.55, 0.05), _s(0.35), Tween.TRANS_SINE, Tween.EASE_IN)
	_pitch(-0.25, _s(0.3))
	_hands(L(-0.12, 0.14, 0.04), L(0.12, 0.14, 0.04), 0.5, 10.0)
	_grip("garra", "garra", L(-0.1, 0.0, 0.0), L(0.1, 0.0, 0.0))
	_body("k_ahorca", 0.9, 0.25)  # te hunde con el peso del cuerpo
	_vic("munecas", 0.02)
	_chair_away()
	fx._snd("sfx/kill_papel_rasga", 0.0, 0.7)
	var pile := KillProps.follow(fx, L(0, -0.16, 0.25), Vector3(-60, 0, 0), false)
	for i in KillProps.count(14):
		var sh := KillProps.box(pile, Vector3(0.09, 0.002, 0.2), Color(0.93, 0.93, 0.9), Vector3(randf_range(-0.3, 0.3), randf_range(-0.04, 0.04), randf_range(-0.12, 0.12)))
		sh.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-PI, PI), randf_range(-0.5, 0.5))
		if i < 3:
			var tl := KillProps.label(sh, KillProps.t("SCR_K_TICKET", "TICKET #{n}\nCLIENTE MOLESTO").replace("{n}", str(4471 + i)), 0.0002, Color(0.7, 0.05, 0.05), Vector3(0, 0.002, 0), 0.08, 48)
			tl.rotation.x = -PI * 0.5
	if await _at(0.5):
		return
	_lock(L(0, -0.04, 0.5), 12.0, false, Vector3(-10, 0, 0))  # a 0,4 m sus ojos se salían por arriba del cuadro
	_hands(L(-0.22, -0.2, 0.12), L(0.22, -0.2, 0.12), 0.7, 10.0)  # las manos bajan a tus hombros: su cara a la vista
	_grip("garra", "garra", L(-0.22, -0.5, 0.0), L(0.22, -0.5, 0.0))
	_jaw(1.9, _s(0.1))
	_scream()
	_vic("manotea")  # manoteas entre el papel
	if await _hit(0.7, 0.16, "k_azote", 0.07):
		return
	# v0.3.2 (Joan): «te ahogas entre los tickets»: te hunde del todo, el papel tapa la vista, tos y asfixia.
	_beat("ahogo")
	_head(Vector3(0, -0.8, 0.05), _s(0.12), Tween.TRANS_SINE, Tween.EASE_IN)
	_vic("cae", _s(0.14))
	fx._snd("sfx/kill_ahogo", 4.0, 0.9)
	fx._snd("sfx/kill_papel_rasga", 2.0, 0.6)
	_paper_cover(_s(0.12))
	if await _at(0.86):
		return
	_final(L(0, 0, 0.2))


## Hojas 2D que tapan la vista desde abajo (te hunden en la pila).
func _paper_cover(t: float) -> void:
	if fx._root == null:
		return
	var vp := fx.get_viewport().get_visible_rect().size
	for i in (10 if not KillProps.light_mode() else 5):
		var r := ColorRect.new()
		r.color = Color(0.93, 0.93, 0.9, 0.97)
		r.size = Vector2(vp.x * randf_range(0.3, 0.5), vp.y * randf_range(0.35, 0.6))
		r.pivot_offset = r.size * 0.5
		r.rotation = randf_range(-0.6, 0.6)
		r.position = Vector2(randf_range(-0.1, 0.8) * vp.x, vp.y * 1.05)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx._root.add_child(r)
		r.create_tween().tween_property(r, "position:y", vp.y * randf_range(-0.1, 0.55), t * randf_range(0.6, 1.0))


# =============================================================================================================
# RASEC
# =============================================================================================================

## Coaching (Rasec): te agarra del cuello de la camisa, te mete el micrófono de karaoke a la boca (acople que
## chilla), te arrastra hasta la cabina de DJ y te la estrella en la cara.
func _k_rasec_micro_cabina() -> void:
	var m := _m()
	_grab()
	var fol := KillProps.follow(fx, L(0.15, -0.15, 0.45), Vector3(10, 0, 0))
	var mic := KillProps.mic(fol)
	mic.rotation_degrees = Vector3(0, 180, 0)  # la rejilla hacia ti
	_prop("microfono")
	_lock(L(0, 0.0, 0.6), 10.0, true, Vector3(-8, 0, 0))
	_hands(L(-0.03, -0.3, 0.16), L(0.14, -0.15, 0.48), 1.0, 14.0)
	_grip("puño", "tubo")  # el puño en el cuello de tu camisa; la otra empuña el micrófono
	_vic("brazo_l")  # las dos manos al brazo que te tiene del cuello de la camisa
	_beat("agarre")
	if await _at(0.08):
		return
	_beat("microfono")
	_wind(_s(0.06), "k_estrella", 0.06)  # carga el brazo del micrófono y te lo mete en la boca
	var tw := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(fol, "pos", L(0.0, -0.08, 0.075), _s(0.08))
	_hands(L(-0.03, -0.3, 0.16), L(0.02, -0.1, 0.2), 1.0, 18.0)
	_grip("puño", "tubo")
	if await _at(0.14):
		return
	_impact(0.7, "sfx/kill_golpe_seco", 1.4)
	_vic("boca", 0.02)  # tus manos al micrófono
	fx._snd("sfx/auricular_pitido", 4.0, 0.55)
	fx._snd("sfx/auricular_pitido", 0.0, 0.8)
	_lock_to(L(0, 0.0, 0.4), _s(0.15))
	if await _at(0.3):
		return
	_scream()
	if await _at(0.42):
		return
	# Te arrastra a la cabina (tirones del cuello).
	_beat("arrastre")
	_body("k_arrastra", 1.4, 0.2)
	_vic("manotea")
	_chair_away()
	_yaw_by(0.6, _s(0.14), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_head(Vector3(0, -0.15, -0.2), _s(0.12))
	_cam("cam_roll", 0.25, _s(0.12))
	fx._snd("sfx/kill_arrastre", 0.0)
	if await _at(0.56):
		return
	fol.visible = false
	fx.lock_on = false
	_vic("escudo")  # levantas los brazos: la cabina viene encima
	_beat("final")
	await fx._f_cabina()


## Coaching sin permiso: estás sentado; te agarra la silla por el respaldo y la hace girar una vuelta entera (su
## cabina de DJ pasa por delante con el estrobo, que nunca pasa de 3 destellos por segundo), la frena de golpe
## sobre él y te sostiene la mirada 0,4 s, quieto; luego te grita.
func _k_rasec_platos() -> void:
	var m := _m()
	var p := _p()
	var booth := fx._dj_booth()
	_prop("cabina")
	var e := fx._eye()
	if booth != null:
		# La cabina detrás de él, encendida: el contexto de su «sala».
		var bf := fx._dir(25.0)
		booth.global_position = Vector3(e.x, fx._floor_y() + 0.6, e.z) + bf * 1.5
		booth.look_at(Vector3(e.x, booth.global_position.y, e.z), Vector3.UP)
	_grab()
	_lock(L(0, -0.02, 0.55), 10.0, true, Vector3(-20, 0, 0))
	_hands(L(-0.3, -0.5, 0.2), L(0.3, -0.5, 0.2), 1.0, 12.0)  # en tus apoyabrazos
	_grip("tubo", "tubo", L(-0.3, -0.9, 0.2), L(0.3, -0.9, 0.2))
	if not _body("k_inclina", 1.0, 0.15):
		fx._anim(m, ["hunch"], 1.0)
	_vic("pecho", 0.012)  # lo empujas del pecho
	_beat("agarre")
	_start_scratch()
	# Carga (el torso gira atrás) y lanza la silla a girar.
	if await _hit(0.08, 0.16, "k_cachetada", 0.06):
		return
	# Una vuelta entera: lo pierdes de vista, pasa la cabina, vuelve él.
	_beat("gira")
	_vic("manotea")
	fx.lock_on = false
	fx._snd("sfx/kill_silla_giro", 2.0, 0.9)
	var y0 := p.rotation.y
	var tw := _tw().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "rotation:y", y0 + TAU, _s(0.24))
	_strobe(_s(0.26))
	_cam("cam_roll", 0.12, _s(0.12)).chain().tween_property(fx, "cam_roll", 0.0, _s(0.12))
	# La frena 0,4 s antes del grito (la mirada sostenida cabe dentro de la acción, no empuja la frase).
	await fx._wait(_t0 + maxf(_A - 0.4, _map(0.2)) - fx._spent)
	if fx._done:
		return
	# La frena en seco sobre él y te sostiene la mirada: 0,4 s quietos, solo su respiración.
	_beat("para")
	p.rotation.y = y0 + TAU
	fx.cam_roll = 0.0
	_impact(0.7, "sfx/kill_golpe_seco", 0.8)
	_lock(L(0, 0.0, 0.36), 40.0, false, Vector3.ZERO)
	_hands(L(-0.2, -0.02, 0.1), L(0.2, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_body("k_inclina", 0.4, 0.1)  # quieto: solo respira
	_vic("escudo")
	fx._shake_goal = 0.0
	fx._shake = 0.0
	if fx._music != null:
		fx._music.stop()
	fx._snd("sfx/respiracion", 2.0, 0.75)
	if await _at(GRITO_U["rasec_platos"]):
		return
	# v0.3.2 (Joan): «te sostiene del cuello y te grita para quitarte la cabeza»: las dos manos al cuello y tira hacia
	# arriba (la vista se estira y sube, crujidos); intermedio: sin decapitación, corte en el pico.
	_beat("cuello")
	_hands(L(-0.105, -0.115, 0.14), L(0.105, -0.115, 0.14), 1.2, 20.0)  # de la mandíbula, a la vista: se ve el tirón
	_grip("tubo", "tubo", L(0.0, -0.1, 0.0), L(0.0, -0.1, 0.0))
	_body("k_levanta", 0.5, 0.15, 0.3)  # tira de tu cabeza hacia arriba con las piernas y la espalda
	_scream()
	_vic("munecas", 0.02)  # te agarras de sus muñecas
	var vk := _victim()
	if vk != null:
		vk.create_tween().tween_property(vk, "strength", 0.3, _s(0.4))
	_head(Vector3(0, 0.32, 0.05), _s(0.3), Tween.TRANS_SINE, Tween.EASE_IN)
	_cam("cam_pitch", -0.25, _s(0.3))
	fx._fov_goal = 48.0
	fx._snd("sfx/kill_ahogo", 3.0, 0.9)
	var me: WeakRef = weakref(self)
	for i in 2:
		fx.get_tree().create_timer(_s(0.12) * (i + 1), true).timeout.connect(func() -> void:
			var km: KillMoves = me.get_ref()
			if km != null and is_instance_valid(km.fx) and not km.fx._done:
				KillGore.bone(km.fx, 0.8 + 0.2 * i)
				km.fx._shake = 0.12
				if i == 1:
					KillGore.splatter(km.fx, 0.6, Vector2(0.5, 0.85)))
	if await _at(0.86):
		return
	_final(L(0, 0, 0.2))


func _start_scratch() -> void:
	fx._start_music(str(fx.row.get("musica", "musica/hold_kipupay_parlantes")))
	if fx._music != null:
		var tw := fx._music.create_tween().set_loops(6)
		tw.tween_property(fx._music, "pitch_scale", 1.6, 0.07)
		tw.tween_property(fx._music, "pitch_scale", 0.4, 0.09)


## Estrobo: luz de colores que parpadea sobre la escena (y destellos 2D suaves; con "reducir destellos", tenues).
func _strobe(t: float) -> void:
	_prop("estrobo")
	var l := OmniLight3D.new()
	l.omni_range = 4.0
	l.shadow_enabled = false
	l.set_meta("no_mood", true)
	fx._stage.add_child(l)
	l.global_position = fx._eye() + Vector3(0, 0.6, 0)
	var cols := [Color(1, 0.15, 0.6), Color(0.2, 0.6, 1.0), Color(1.0, 0.95, 0.3), Color(0.4, 1.0, 0.5)]
	# Fotosensibilidad: como mucho 3 destellos por segundo, suaves, sobre una luz base (su cara se sigue leyendo).
	var n := maxi(1, int(floor(t * STROBE_HZ)))
	var period := t / n
	var tw := l.create_tween()
	for i in n:
		var c: Color = cols[i % cols.size()]
		tw.tween_callback(func() -> void:
			l.light_color = c
			l.light_energy = 0.5 if fx._soft else 1.4
			_flash(Color(c.r, c.g, c.b, 0.1), 0.12))
		tw.tween_interval(period * 0.5)
		tw.tween_callback(func() -> void: l.light_energy = 0.35)
		tw.tween_interval(period * 0.5)
	tw.tween_callback(l.queue_free)


## 11 horas en coaching: te agarra la silla por los apoyabrazos y la hace girar cada vez más rápido bajo el
## estrobo; la frena de golpe cara a cara, te toma la cabeza y grita; te estrella la cabina.
func _k_rasec_silla_giro() -> void:
	var m := _m()
	_grab()
	_lock(L(0, -0.05, 0.55), 10.0, true, Vector3(-25, 0, 0))
	_hands(L(-0.32, -0.55, 0.15), L(0.32, -0.55, 0.15), 1.0, 12.0)
	_grip("tubo", "tubo", L(-0.32, -0.9, 0.15), L(0.32, -0.9, 0.15))
	if not _body("k_inclina", 1.0, 0.15):
		fx._anim(m, ["hunch"], 1.0)
	_vic("pecho", 0.012)
	_beat("agarre")
	_start_scratch()
	if await _hit(0.08, 0.16, "k_cachetada", 0.06):
		return
	# Gira la silla: tú das vueltas, él queda donde está (lo ves pasar en cada vuelta).
	_beat("gira")
	_vic("manotea")
	fx.lock_on = false
	fx._snd("sfx/kill_silla_giro", 2.0)
	var p := _p()
	var y0 := p.rotation.y
	var turns := 3.0
	var tw := _tw().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "rotation:y", y0 + TAU * turns, _s(0.4))
	_strobe(_s(0.42))
	_cam("cam_roll", 0.18, _s(0.3))
	if await _at(0.48):
		return
	# La frena de golpe cara a cara.
	_beat("para")
	p.rotation.y = y0 + TAU * turns
	fx.cam_roll = 0.0
	_impact(1.0, "sfx/kill_golpe_seco", 0.8)
	_lock(L(0, 0.0, 0.34), 30.0, false, Vector3.ZERO)  # cabeza chica: a 0,42 se veía lejos
	_hands(L(-0.2, -0.02, 0.1), L(0.2, -0.02, 0.1), 1.0, 14.0)
	_scream()  # «¡¿11 HORAS EN COACHING?!»
	# v0.3.2 (Joan: «te arranca los brazos por work avoider… mueres por desangramiento»; intermedio): tu antebrazo entra
	# en cuadro, él lo jala y se dobla al revés (crujido, chorro de sangre); corte en el pico, sin miembro separado.
	_grip("garra", "garra")
	_body("k_grito", 1.0, 0.1)
	# Tu brazo derecho entra en cuadro (lo levantas para cubrirte) y él te lo toma de la muñeca.
	var v := KillVictim.of(fx)
	if v != null:
		v.struggle(0.014, 9.0)
		v.put("r", L(0.13, -0.17, 0.3), "suelta", L(0.0, -0.1, 0.9), 5.0)
		v.put("l", L(-0.16, -0.2, 0.3), "plana", L(0.0, -0.1, 0.9), 4.0)
	_hands(L(-0.2, -0.02, 0.1), L(0.12, -0.14, 0.3), 1.2, 18.0)  # su mano a tu muñeca
	_grip("garra", "tubo")
	# Carga (tira de tu brazo hacia sí) y lo dobla al revés.
	if await _hit(0.6, 0.18, "k_cachetada", 0.07):
		return
	_beat("brazo")
	if v != null:
		# El codo cede al revés: el antebrazo salta hacia arriba y afuera, la mano cuelga.
		var hr := v.hands["r"] as KillVictim.Hand
		hr.pole = Vector3(0.3, 0.95, -0.1) if KillGore.enabled() else Vector3(0.9, -0.3, -0.1)
		hr.grip = "suelta"
		hr.hz = 9.0
		v.put("r", L(0.21, 0.01, 0.3) if KillGore.enabled() else L(0.2, -0.1, 0.28), "suelta", Vector3.INF, 9.0)
		v.jolt("r", Vector3(1.6, 1.4, 0.0))
		v.set_param("blood", 0.9 if KillGore.enabled() else 0.0)
		v.wounds(1.0)
		v.struggle(0.03, 13.0)
		v.put("l", L(0.12, -0.12, 0.26), "garra", L(0.3, 0.0, 0.26), 6.0)  # la otra mano va al brazo roto
	if KillGore.enabled():
		KillGore.bone(fx, 1.0)
		KillGore.wet(fx, 0.8)
		KillGore.splatter(fx, 1.0, Vector2(0.62, 0.62))
		KillGore.splatter(fx, 0.5, Vector2(0.4, 0.3))
		KillGore._note(fx, "brazo")
	_impact(1.0, "sfx/kill_golpe_seco", 0.7)
	if await _at(0.7):
		return
	_beat("desangra")
	_vic("cae", _s(0.08))
	fx._fx_goal = 1.0
	KillGore.red_out(fx, _s(0.12), 0.5)  # te desangras: la vista se tiñe a medias (a negro del todo, la cabina del final no se veía)
	fx._fov_goal = 45.0
	if await _at(0.76):
		return
	fx.lock_on = false
	_beat("final")
	await fx._f_cabina()


## Evento de Rasec: todos te miran. Te encasqueta un gorro de fiesta (el elástico te muerde la barbilla) y te
## sienta de los hombros en la silla musical; confeti, y su cara.
func _k_rasec_gorro_silla() -> void:
	var m := _m()
	_grab()
	var fol := KillProps.follow(fx, L(0.0, 0.1, 0.42), Vector3(0, 0, 0))
	KillProps.hat(fol)
	_prop("gorro")
	_lock(L(0, 0.05, 0.62), 10.0, true, Vector3(-10, 0, 0))
	_hands(L(-0.09, 0.12, 0.42), L(0.09, 0.12, 0.42), 0.6, 14.0)
	_beat("agarre")
	_grip("pinza", "pinza")
	_body("k_inclina", 1.0, 0.15)
	# v0.3.2 (Joan): «aunque te resistas a ponértelo»: tus manos empujan el gorro y forcejeas; él empuja más fuerte.
	var v := KillVictim.of(fx)
	if v != null:
		v.struggle(0.02, 10.0)
		for side in ["l", "r"]:
			var sgn := -1.0 if side == "l" else 1.0
			var at := func() -> Vector3: return fol.global_position + fol.global_transform.basis * Vector3(0.07 * sgn, -0.07, 0.0) if is_instance_valid(fol) else Vector3.ZERO
			v.hold(side, func() -> Vector3: return (at.call() as Vector3) + v.view_point(L(0.02 * sgn, -0.06, -0.06)) - v.view_point(Vector3.ZERO), "plana", at, 6.0)
	_beat("resiste")
	fx._snd("sfx/kill_ahogo", 0.0, 1.4)
	var strug := _tw().set_loops(3)
	strug.tween_property(fx, "cam_roll", 0.1, _s(0.02))
	strug.tween_property(fx, "cam_roll", -0.1, _s(0.02))
	# Carga los hombros y descarga: te gana.
	if await _hit(0.12, 0.14, "k_estrella", 0.05):
		return
	if v != null:
		v.jolt("l", Vector3(-1.4, -1.0, 0.3))
		v.jolt("r", Vector3(1.4, -1.0, 0.3))
	_vic("manotea")
	fx.cam_roll = 0.0
	# ¡Plop!: el gorro baja sobre tu cabeza (el borde tapa el cielo de la vista).
	_beat("gorro")
	var tw := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(fol, "pos", L(0.0, 0.13, -0.02), _s(0.08))
	tw.parallel().tween_property(fol, "rot", Vector3(-15, 0, 0), _s(0.08))
	_hands(L(-0.1, 0.12, 0.02), L(0.1, 0.12, 0.02), 0.5, 22.0)
	_grip("garra", "garra")
	if await _at(0.2):
		return
	_impact(0.5, "sfx/kill_elastico", 1.0)
	fx._snd("sfx/kill_elastico", 2.0)
	_cam("cam_pitch", -0.08, 0.06).chain().tween_property(fx, "cam_pitch", 0.0, 0.1)
	_vic("cuello", 0.014)  # el elástico te muerde la barbilla: tus dedos lo buscan
	# Te sienta de los hombros en la silla musical: se yergue (carga) y te baja con todo el peso.
	if await _hit(0.28, 0.16, "k_azote", 0.06):
		return
	_beat("silla")
	_hands(L(-0.26, -0.3, 0.1), L(0.26, -0.3, 0.1), 0.8, 16.0)
	_grip("garra", "garra", L(-0.26, -0.6, 0.0), L(0.26, -0.6, 0.0))
	_head(Vector3(0, -0.45, 0.05), _s(0.1), Tween.TRANS_QUAD, Tween.EASE_IN)
	_lock_to(L(0, 0.05, 0.45), _s(0.12))
	if await _at(0.4):
		return
	_impact(0.9, "sfx/caida_cuerpo", 0.9)
	fx._snd("sfx/kill_silla_cae", -2.0, 1.4)
	_vic("munecas", 0.014)
	_body("k_inclina", 1.3, 0.2)
	if await _at(0.5):
		return
	# Confeti y su cara.
	fx._snd("sfx/kill_confeti", 3.0)
	_prop("confeti")
	KillProps.debris(fx, 60, Vector3(0.022, 0.022, 0.001), [Color(1, 0.2, 0.6), Color(1, 0.9, 0.2), Color(0.2, 0.7, 1), Color(0.4, 1, 0.5)],
		fx._cam().global_transform * L(0, 0.22, 0.4),
		func(_k: int) -> Vector3: return Vector3(randf_range(-0.9, 0.9), randf_range(0.3, 1.5), randf_range(-0.5, 0.5)), 1.0)
	_hands(L(-0.2, -0.02, 0.1), L(0.2, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_body("k_grito", 1.0, 0.15)
	_scream()
	_vic("cara", 0.014)
	_vic_later(0.6, "munecas", 0.02)  # …y bajan a sus muñecas (te tiene de la cabeza)
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


# =============================================================================================================
# HAIME
# =============================================================================================================

## Inasistencia a QA: oyes sus pasos detrás; una mano se te clava en el hombro, te da vuelta de un tirón y te
## aprieta contra la cara la hoja de calibración con tu nota; la baja y te grita.
func _k_haime_hombro_hoja() -> void:
	var m := _m()
	_grab()
	_lock(L(0.15, 0.08, -0.42), 30.0, true, Vector3(-10, 0, 0))
	_hands(Vector3.INF, L(0.24, -0.22, 0.02), 1.1, 14.0)  # la mano en tu hombro derecho, desde atrás
	_grip("", "garra", Vector3.INF, L(0.24, -0.6, 0.0))
	_beat("agarre")
	if await _at(0.08):
		return
	_beat("hombro")
	_impact(0.6, "sfx/caida_cuerpo", 1.4)
	var vh := KillVictim.of(fx)
	if vh != null:  # tu mano va a la mano que te aprieta el hombro
		vh.struggle(0.012, 9.0)
		vh.put("l", L(0.2, -0.2, 0.1), "garra", L(0.24, -0.22, 0.0), 5.0)
	if await _at(0.16):
		return
	_beat("giro")
	fx.lock_on = false
	_yaw_by(PI, _s(0.12), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_vic("escudo")
	_body("k_cachetada", 0.01, 0.2)  # el brazo de la hoja ya cargado atrás
	if await _at(0.3):
		return
	_beat("hoja")
	_wind(_s(0.06), "k_cachetada", 0.06)
	var fol := KillProps.follow(fx, L(0.0, -0.05, 0.4), Vector3(0, 0, -3))
	KillProps.sheet(fol, KillProps.t("SCR_K_CAL_TITLE", "CALIBRACIÓN QA"), KillProps.t("SCR_K_CAL_BODY", "{agente}\nEMPATÍA: 0\nSALUDO: 0\nCIERRE: 0").replace("{agente}", GameState.agent.to_upper()), Color(0.8, 0.1, 0.1), "0/100")
	_prop("hoja_calibracion")
	_lock(L(0, 0.0, 0.5), 14.0, true, Vector3(-5, 0, 0))
	var tw := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(fol, "pos", L(0.0, 0.0, 0.14), _s(0.06))
	_hands(L(-0.09, 0.0, 0.16), L(0.09, 0.0, 0.16), 0.2, 18.0)
	_grip("plana", "plana", L(0.0, 0.0, 0.0), L(0.0, 0.0, 0.0))
	if await _at(0.38):
		return
	_impact(0.7, "sfx/kill_papel_golpe", 1.1)
	fx._snd("voces/haime/rec", -2.0)
	_body("k_ahorca", 1.0, 0.2)
	_vic("boca", 0.02)  # arañas la hoja
	if await _at(0.56):
		return
	var tw2 := _tw().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw2.tween_property(fol, "pos", L(0.0, -0.45, 0.25), _s(0.08))
	_hands(L(-0.2, -0.02, 0.1), L(0.2, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_body("k_grito", 1.0, 0.12)
	_lock_to(L(0, 0, 0.32), _s(0.1))
	# v0.3.2 (Joan): «grita con su cara deforme»: la cara se desencaja de golpe al bajar la hoja.
	_jaw(2.0, _s(0.06))
	KillGore.face(fx, 0.9, 0.1)
	_scream()
	_vic("munecas", 0.016)
	if await _at(0.84):
		return
	_final(L(0, 0, 0.2))


## Calibración final (v0.3.2e, la barra de cuerpo entero): salta la mesa y TE CAE ENCIMA con todo su peso: la silla se
## vuelca hacia atrás contigo (tus piernas quedan arriba, pataleando) y caes de espaldas con él a horcajadas; en el piso
## te aprieta las mejillas con las dos manos (la vista se estrecha, tú te agarras de sus muñecas), te grita ¡EMPATÍAAAA!
## dos veces con el headset chillando mientras te azota la cabeza contra el piso, y te desgarra la piel de las mejillas.
## De pie (sin silla) caes igual; sentado sin sitio detrás (una pared), te estrella contra el respaldo.
func _k_haime_mejillas() -> void:
	var p := _p()
	_grab()
	_lock(L(0, 0.0, 0.48), 12.0, true, Vector3(-10, 0, 0))
	_hands(L(-0.14, -0.09, 0.1), L(0.14, -0.09, 0.1), 0.55, 16.0)
	_grip("garra", "garra")
	_beat("agarre")
	# Te cae encima.
	_impact(0.9, "sfx/caida_cuerpo", 0.9)
	_body("k_encima", 1.0, 0.22, 0.0, ["hunch"])
	_vic("manotea")
	var pb := p.global_transform.basis
	var room := _free(fx._eye() - Vector3(0, 0.35, 0), pb.z, 1.6)
	var falls := room > 0.85
	var t_fall := _s(0.18)  # hasta el grito
	var down := Vector3(0, 0, minf(0.14, maxf(room - 0.4, 0.0)))
	_beat("cae")
	if falls:
		var back_m := minf(0.74, room - 0.32) if p.seated else minf(0.4, room - 0.32)
		down = Vector3(0, 0.3 - _base.y, back_m)
		if p.seated:
			_chair_tip(t_fall + 0.03, maxf(back_m - 0.5, 0.0))
			fx._snd("sfx/kill_silla_cae", 2.0)
			var v0 := _victim()
			if v0 != null:
				v0.body("v_piernas", 1.3, 0.15)  # tus piernas quedan arriba, pataleando
		_head(down, t_fall, Tween.TRANS_QUAD, Tween.EASE_IN)
		_pitch(1.2, t_fall, Tween.TRANS_QUAD, Tween.EASE_IN)
		_cam("cam_roll", -0.3, t_fall * 0.55).chain().tween_property(fx, "cam_roll", 0.0, t_fall * 0.5)
		_lock(L(0, 0.04, 0.5), 9.0, false, Vector3(-6, 0, 0))
	else:
		_head(down, t_fall, Tween.TRANS_BACK, Tween.EASE_OUT)  # sin sitio detrás: te estrella contra el respaldo
	if await _at(0.18):
		return
	_scream()
	fx._snd("sfx/auricular_pitido", 4.0, 1.0)
	fx._snd("sfx/auricular_pitido", 0.0, 1.35)
	_beat("golpe")
	_impact(1.0 if falls else 0.7, "sfx/caida_cuerpo", 0.75)
	if falls:
		# La cabeza rebota en el piso.
		var hb := _head(down + Vector3(0, 0.05, 0), 0.07)
		hb.tween_property(p.head, "position", _base + down, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fx._snd("sfx/acufeno", -12.0)
	_vic("cara", 0.016)  # le empujas la cara con las dos manos
	if await _at(0.27):
		return
	_beat("mejillas")
	# Las palmas en tus mejillas: entran por los bordes de la vista (los pulgares hacia el centro) y la vista se estrecha.
	_hands(L(-0.115, -0.08, 0.12), L(0.115, -0.08, 0.12), 0.6, 18.0)
	_grip("garra", "garra")
	_impact(0.6, "sfx/kill_golpe_seco", 1.5)
	fx._fov_goal = 55.0
	_lock_to(L(0, 0, 0.34), _s(0.12))
	if await _at(0.4):
		return
	# Te sacude MUY violentamente mientras grita dos veces ¡EMPATÍAAAA! (frase_rep 2): te levanta la cabeza de las
	# mejillas y te la azota contra el piso, tres veces.
	_beat("sacude")
	var shake := _tw().set_loops(9)
	shake.tween_property(fx, "cam_roll", 0.42, _s(0.025))
	shake.tween_property(fx, "cam_roll", -0.42, _s(0.025))
	var yaw := _tw().set_loops(9)
	yaw.tween_property(fx, "cam_off", Vector3(0.07, 0.02, 0), _s(0.025))
	yaw.tween_property(fx, "cam_off", Vector3(-0.07, -0.02, 0), _s(0.025))
	for i in 3:
		var wind := minf(_s(0.05), 0.2)
		if falls:
			_head(down + Vector3(0, 0.07, -0.03), wind, Tween.TRANS_SINE, Tween.EASE_OUT)
		if await _hit(0.46 + i * 0.08, wind, "", 0.05):
			return
		if falls:
			_head(down, 0.045, Tween.TRANS_EXPO, Tween.EASE_IN)
		_impact(0.6 + 0.1 * i, "sfx/kill_golpe_seco", 1.3 + 0.1 * i)
		if falls:
			fx._snd("sfx/caida_cuerpo", -4.0, 1.5 + 0.1 * i)
			_chips(0.5)
	if await _at(0.7):
		return
	# …hasta que te desgarra la piel de las mejillas: sus dedos arrastran hacia afuera, sangre en la vista; tus manos
	# sueltan sus muñecas; mueres.
	_beat("piel")
	_hands(L(-0.2, -0.17, 0.16), L(0.2, -0.17, 0.16), 1.3, 26.0)
	_grip("gancho", "gancho")
	KillGore.wet(fx, 1.0)
	KillGore.screech(fx, 0.0)
	KillGore.splatter(fx, 0.9, Vector2(0.25, 0.6))
	KillGore.splatter(fx, 0.9, Vector2(0.75, 0.6))
	fx._snd("sfx/kill_papel_rasga", 3.0, 0.5)  # el desgarro (grave)
	_vic("cae", _s(0.1))
	var v := _victim()
	if v != null and v.anim != null:
		v.anim.speed_scale = 0.25  # las piernas dejan de patalear
	if await _at(0.82):
		return
	fx.cam_roll = 0.0
	fx.cam_off = Vector3.ZERO
	_final(L(0, 0, 0.19))


# =============================================================================================================
# TRAINER
# =============================================================================================================

## Training reprobado: te toma del cuello y te estampa la cara contra la pizarra; te arrastra la cara por la
## pizarra (el plumón chirría, pasa "2/5 REPROBADO" frente a tus ojos), te voltea y te grita GAAAAA.
func _k_trainer_pizarra() -> void:
	# kills2 (Joan: «la del Trainer: no se ve bien cómo te mata… debe ser explícito, como en primera persona real»). Cada
	# cosa que te hace se VE desde tus ojos: te toma la cabeza con las dos manos (sus antebrazos a los lados del cuadro) →
	# te gira y te estampa la cara en la pizarra (tus palmas en ella; queda tu sangre) → te echa la cabeza atrás de los
	# pelos (ves la mancha y su mano arriba, en tu pelo) y te estampa otra vez (la pizarra se ladea, saltan los plumones)
	# → te arrastra la cara pizarra abajo → te da vuelta: lo tienes encima, sus manos en tu cabeza, las tuyas empujándole
	# el pecho (abajo: su cara queda a la vista); grita «¡GAAAA!» y, a lo largo del grito, te revienta la nuca contra la
	# pizarra tres veces (cada golpe con su carga; tus manos pierden fuerza en cada uno) → final.
	var m := _m()
	_grab()
	_lock(L(0, 0.02, 0.5), 14.0, true, Vector3(-8, 0, 0))
	_hands(L(-0.17, 0.0, 0.12), L(0.17, 0.0, 0.12), 1.0, 16.0)
	_grip("garra", "garra", L(0.0, 0.0, 0.0), L(0.0, 0.0, 0.0))  # las dos manos en tu cabeza: los antebrazos se ven
	_body("k_levanta", 1.3, 0.1)
	_vic("munecas", 0.014)
	_beat("agarre")
	_impact(0.6, "sfx/caida_cuerpo", 1.3)
	if await _at(0.07):
		return
	# Te voltea hacia la pizarra (está a tu espalda) y te estampa.
	_beat("pizarra")
	_vic("manotea")
	fx.lock_on = false
	_yaw_by(PI, _s(0.08), Tween.TRANS_EXPO, Tween.EASE_OUT)
	if await _at(0.13):
		return
	var e := fx._eye()
	var f := fx._dir(0.0)
	var wb_root := Node3D.new()
	fx._stage.add_child(wb_root)
	KillProps.whiteboard(wb_root, _detail_or("2/5"))
	wb_root.global_position = Vector3(e.x, e.y - 0.1, e.z) + f * 0.42
	wb_root.look_at(Vector3(e.x, e.y - 0.1, e.z), Vector3.UP)
	wb_root.rotate_object_local(Vector3.UP, PI)
	_prop("pizarra")
	_lock(L(-0.05, 0.12, -0.35), 20.0, true, Vector3(-25, 0, 0))
	# Una mano te empuja la nuca; la otra te tiene del pelo: sus dedos asoman arriba, delante de tus ojos.
	_hands(L(-0.02, -0.18, -0.04), L(0.05, 0.17, 0.08), 1.0, 14.0)
	_grip("garra", "garra")
	# Tus manos van a la pizarra (abiertas, a los lados de tu cara): quieres frenar el golpe.
	var vp := _victim()
	if vp != null:
		vp.struggle(0.012, 8.0)
		vp.both(L(-0.24, -0.03, 0.3), L(0.24, -0.03, 0.3), "plana", L(0.0, -0.03, 1.2), 5.0)
	_windup(_s(0.02))
	_wind(_s(0.05), "", 0.05)  # sin clip de cuerpo: está detrás de ti
	_head(Vector3(0, 0, -0.3), _s(0.05), Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _at(0.2):
		return
	_impact(1.0, "sfx/kill_golpe_seco", 0.9)
	KillGore.bone(fx, 0.6)
	var w0 := wb_root.position
	var ws := wb_root.create_tween()
	ws.tween_property(wb_root, "position", w0 + wb_root.global_transform.basis.z * -0.02, 0.03)
	ws.tween_property(wb_root, "position", w0, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Tu sangre queda en la pizarra, donde dio tu cara.
	if KillGore.enabled():
		for b in [[Vector3(0.0, 0.1, 0.012), Vector3(0.05, 0.035, 0.003), 0.5], [Vector3(0.03, 0.085, 0.012), Vector3(0.035, 0.03, 0.003), -0.6],
				[Vector3(-0.03, 0.08, 0.012), Vector3(0.03, 0.022, 0.003), 0.2], [Vector3(0.06, 0.12, 0.012), Vector3(0.016, 0.014, 0.003), 0.8],
				[Vector3(-0.06, 0.13, 0.012), Vector3(0.012, 0.012, 0.003), 0.3], [Vector3(-0.01, 0.02, 0.012), Vector3(0.01, 0.12, 0.003), 0.03],
				[Vector3(0.035, 0.0, 0.012), Vector3(0.008, 0.17, 0.003), -0.02]]:
			var st := KillProps.box(wb_root, b[1], Color(0.42, 0.0, 0.02, 0.92), b[0])
			st.rotation.z = float(b[2])
		_prop("sangre_pizarra")
	# Te echa la cabeza ATRÁS de los pelos: ves la mancha, tus manos en la pizarra y su mano en tu pelo… y otra vez.
	_beat("segundo")
	fx._red = minf(fx._red, 0.2)
	_head(Vector3(0, 0.0, 0.03), _s(0.07), Tween.TRANS_QUAD, Tween.EASE_OUT)
	_cam("cam_pitch", 0.1, _s(0.07))
	if await _at(0.31):
		return
	_windup(_s(0.02))
	_cam("cam_pitch", 0.0, _s(0.04))
	_head(Vector3(0.03, -0.04, -0.31), _s(0.045), Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _at(0.38):
		return
	_impact(1.2, "sfx/kill_golpe_seco", 0.8)
	KillGore.bone(fx, 0.9)
	fx._snd("sfx/kill_plastico_quiebra", 0.0, 0.8)
	var tilt := wb_root.create_tween()
	tilt.tween_property(wb_root, "rotation:z", wb_root.rotation.z + 0.07, 0.05)
	tilt.parallel().tween_property(wb_root, "position", w0 + wb_root.global_transform.basis.z * -0.03, 0.03)
	tilt.tween_property(wb_root, "position", w0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if KillGore.enabled():
		for b in [[Vector3(0.02, 0.06, 0.013), Vector3(0.07, 0.05, 0.003), -0.4], [Vector3(-0.04, 0.1, 0.013), Vector3(0.05, 0.035, 0.003), 0.7],
				[Vector3(0.07, 0.09, 0.013), Vector3(0.04, 0.03, 0.003), 0.1], [Vector3(-0.09, 0.05, 0.013), Vector3(0.02, 0.016, 0.003), 0.5],
				[Vector3(0.11, 0.14, 0.013), Vector3(0.014, 0.014, 0.003), 0.9], [Vector3(0.06, -0.07, 0.013), Vector3(0.009, 0.2, 0.003), 0.02],
				[Vector3(-0.02, -0.1, 0.013), Vector3(0.011, 0.26, 0.003), -0.02], [Vector3(0.015, -0.05, 0.013), Vector3(0.007, 0.14, 0.003), 0.01]]:
			var st2 := KillProps.box(wb_root, b[1], Color(0.36, 0.0, 0.015, 0.95), b[0])
			st2.rotation.z = float(b[2])
	# Los plumones saltan de la bandeja.
	KillProps.debris(fx, KillProps.count(5), Vector3(0.014, 0.014, 0.1), [Color(0.1, 0.2, 0.8), Color(0.8, 0.1, 0.1), Color(0.05, 0.05, 0.05), Color(0.1, 0.6, 0.2)],
		wb_root.global_position + Vector3(0, -0.45, 0),
		func(_k: int) -> Vector3: return Vector3(randf_range(-0.9, 0.9), randf_range(0.6, 1.6), randf_range(-0.4, 0.4)), 5.0)
	_prop("plumones")
	if await _at(0.42):
		return
	# Te arrastra la cara por la pizarra (deja una estela de sangre).
	_beat("arrastra")
	fx._red = minf(fx._red, 0.3)
	fx._snd("sfx/kill_marcador", 5.0)
	if KillGore.enabled():
		var smear := KillProps.box(wb_root, Vector3(0.5, 0.06, 0.003), Color(0.4, 0.0, 0.02, 0.9), Vector3(-0.1, -0.25, 0.014))
		smear.rotation.z = 0.5
		smear.scale = Vector3(0.05, 1, 1)
		_tw().tween_property(smear, "scale", Vector3.ONE, _s(0.13))
	_cam("cam_roll", 0.4, _s(0.06))
	if vp != null:
		vp.struggle(0.03, 6.0)  # tus manos resbalan por la pizarra
	var tw := _tw().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_p().head, "position", _base + Vector3(-0.3, -0.45, -0.26), _s(0.13))
	if await _at(0.56):
		return
	# Te voltea hacia él: quedas de espaldas a la pizarra, más abajo; él encima.
	_head(Vector3(0, -0.22, 0), _s(0.05))
	fx.cam_roll = 0.0
	_yaw_by(PI, _s(0.05), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_vic("manotea")
	if await _at(0.62):
		return
	_lock(L(0, 0.05, 0.44), 14.0, true, Vector3(-6, 0, 0))
	_hands(L(-0.18, 0.0, 0.1), L(0.18, 0.0, 0.1), 1.0, 14.0)  # tu cabeza entre sus manos: los antebrazos, a los lados
	_grip("garra", "garra", L(0.0, 0.0, 0.0), L(0.0, 0.0, 0.0))
	_body("k_ahorca", 1.3, 0.15)
	_jaw(2.6, _s(0.06))  # «ultra terrorífico y grotesco»
	KillGore.face(fx, 1.0, 0.15)
	_scream()
	fx._red = minf(fx._red, 0.25)
	fx._fx_goal = minf(fx._fx_goal, 0.4)
	_vic("pecho", 0.02)  # le empujas el pecho: tus manos abajo, su cara entera a la vista
	# LA NUCA: tres veces contra la pizarra, mientras grita. Cada una: carga (se echa atrás), descarga (tu cabeza se va
	# atrás de golpe, la imagen salta), rebote. Tus manos aflojan un poco más cada vez.
	_beat("nuca")
	for i in 3:
		if await _hit(0.69 + 0.075 * i, 0.16, "k_estrella", 0.08):
			return
		_head(Vector3(0, -0.22 - 0.02 * i, 0.1), 0.045, Tween.TRANS_EXPO, Tween.EASE_OUT)
		_impact(0.85 + 0.1 * i, "sfx/kill_golpe_seco", 0.95 - 0.07 * i)
		fx._red = minf(fx._red, 0.3 + 0.08 * i)
		fx._fx_goal = minf(fx._fx_goal, 0.45 + 0.1 * i)
		KillGore.splatter(fx, 0.35 + 0.2 * i, Vector2(randf_range(0.2, 0.8), randf_range(0.12, 0.3)))
		fx._snd("sfx/kill_plastico_quiebra", -6.0, 1.0 - 0.1 * i)
		if vp != null:
			vp.strength = 1.0 - 0.28 * (i + 1)
			vp.struggle(0.03 - 0.008 * i, 7.0 - i)
		var back_tw := _tw()
		back_tw.tween_interval(0.05)
		back_tw.tween_property(_p().head, "position", _base + Vector3(0, -0.22 - 0.02 * (i + 1), 0.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if await _at(0.92):
		return
	_vic("cae", _s(0.04))
	_final(L(0, 0, 0.2))


## Abandono del training: te alcanza, te atrapa la cabeza por detrás con las dos manos, te la ladea y te grita
## GAAAAA metido en la oreja (su boca en el borde de la vista); te queda el zumbido.
func _k_trainer_oido() -> void:
	# kills2 (Joan: «no se ve bien cómo te mata»). Antes: la vista ladeada 30°, su brazo cruzando arriba y su cara cortada
	# en el borde. Ahora se LEE: te atrapa la cabeza de frente con las dos manos → te la TUERCE a la izquierda (tu vista
	# gira: ves el pasillo de costado) y mete la boca en tu oreja derecha: su cara, de tres cuartos, llena la derecha del
	# cuadro con la boca abierta de más; su antebrazo sube desde abajo a tu mandíbula (te la sujeta), tu mano derecha tira
	# de ese antebrazo, la izquierda manotea → «¡GAAAA!» en tu oído: la imagen salta con la voz → te arranca la oreja
	# (carga, tirón, sangre en el borde derecho; tu mano va a la herida) → el zumbido: todo se apaga menos el pitido,
	# tus manos caen → te endereza la cabeza hacia él de un tirón (el cuello cruje, la vista se vence) y es lo último.
	var m := _m()
	_grab()
	_lock(L(0, 0.02, 0.46), 16.0, true, Vector3(-6, 0, 0))
	_hands(L(-0.17, 0.0, 0.12), L(0.17, 0.0, 0.12), 1.0, 16.0)
	_grip("garra", "garra", L(0.0, 0.0, 0.0), L(0.0, 0.0, 0.0))
	_body("k_inclina", 1.0, 0.1)
	_vic("munecas", 0.014)
	_beat("agarre")
	_impact(0.6, "sfx/caida_cuerpo", 1.2)
	if await _at(0.07):
		return
	# Te tuerce la cabeza: tu oreja derecha queda hacia él.
	_beat("oido")
	_yaw_by(0.8, _s(0.1), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_cam("cam_roll", -0.14, _s(0.1))
	_cam("cam_pitch", -0.05, _s(0.1))
	_lock(L(0.2, 0.0, 0.3), 14.0, false, Vector3(-4, -38, 0))
	# Su mano (la de tu derecha) te sujeta la mandíbula: el antebrazo sube desde abajo; la otra, detrás de tu cabeza.
	_hands(L(0.13, 0.06, -0.08), L(0.03, -0.17, 0.13), 1.0, 16.0)
	_grip("garra", "garra", L(0.0, 0.0, 0.0), L(0.0, -0.05, 0.0))
	var vo := _victim()
	var me: WeakRef = weakref(self)
	if vo != null:
		vo.struggle(0.016, 9.0)
		var arm := func() -> Vector3:
			var km: KillMoves = me.get_ref()
			var pt: Vector3 = km._k_arm("r", 0.55) if km != null and is_instance_valid(km.fx) else Vector3.INF
			return pt if pt != Vector3.INF else vo.view_point(L(0.1, -0.24, 0.22))
		vo.hold("r", arm, "tubo", arm, 6.5)
		vo.put("l", L(-0.24, -0.12, 0.36), "suelta", L(0, 0.0, 0.9), 3.0)
	KillGore.bone(fx, 0.4)
	fx._snd("sfx/respiracion", 3.0, 0.8)
	if await _at(0.22):
		return
	_scream()
	fx._red = minf(fx._red, 0.25)
	fx._fx_goal = minf(fx._fx_goal, 0.4)
	_lock_to(L(0.17, -0.01, 0.25), _s(0.06))
	# La voz te sacude: tres golpes de imagen dentro del grito.
	for i in 2:
		if await _at(0.3 + 0.09 * i):
			return
		fx._shake = 0.07
		fx.cam_off = Vector3(-0.02, 0.0, 0.0)
		_cam("cam_off", Vector3.ZERO, 0.12)
		Controls.vibrate(0.9, 0.9, 0.15)
		if vo != null:
			vo.jolt("l", Vector3(-0.8, 0.3, 0.0))
	# Te arranca la oreja: carga (el puño se cierra en tu oreja), tirón, desgarro; sangre en el borde de la vista.
	if await _hit(0.5, 0.16, "", 0.05):  # sin clip de cuerpo: lo tienes pegado al costado
		return
	_beat("oreja")
	_hands(L(0.13, 0.06, -0.08), L(0.3, 0.02, 0.2), 1.2, 30.0)
	_grip("garra", "puño")
	if vo != null:  # tu mano va a la oreja; la otra pierde fuerza
		vo.struggle(0.02, 9.0)
		vo.put("r", L(0.12, -0.03, 0.09), "garra", L(0.0, -0.03, 0.0), 6.0)
		vo.put("l", L(-0.2, -0.3, 0.25), "suelta", Vector3.INF, 2.5)
		vo.set_param("blood", 0.5 if KillGore.enabled() else 0.0)
	KillGore.wet(fx, 1.0)
	KillGore.bone(fx, 0.5)
	_impact(0.9, "sfx/kill_papel_rasga", 0.6)
	fx._red = minf(fx._red, 0.35)
	KillGore.ear_flash(fx, L(0.24, 0.02, 0.24), 0.2)
	KillGore.splatter(fx, 0.8, Vector2(0.92, 0.45))
	if await _at(0.62):
		return
	# El zumbido: todo se apaga menos el pitido (sordera).
	_beat("zumbido")
	fx._snd("sfx/acufeno", 4.0)
	fx._fx_goal = 0.6
	_vic("cae", _s(0.14))
	_stop_audio_except_ring()
	if await _at(0.8):
		return
	# Te endereza la cabeza hacia él de un tirón: el cuello.
	_beat("cuello")
	_yaw_by(-0.8, 0.07, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_lock(L(0, 0.0, 0.36), 18.0, false, Vector3.ZERO)
	_hands(L(-0.17, 0.0, 0.12), L(0.17, 0.0, 0.12), 1.0, 20.0)
	_grip("garra", "garra", L(0.0, 0.0, 0.0), L(0.0, 0.0, 0.0))
	if await _at(0.83):
		return
	_impact(1.1, "sfx/kill_golpe_seco", 1.2)
	KillGore.bone(fx, 1.0)
	_cam("cam_roll", 0.42, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
	_head(Vector3(0.05, -0.12, 0.0), 0.3)
	if await _at(0.9):
		return
	_final(L(0, 0, 0.2))
	KillGore.red_out(fx, maxf(fx.seconds - Screamers.CUT - fx._spent, 0.1))


func _stop_audio_except_ring() -> void:
	for ap in fx._audio:
		if is_instance_valid(ap) and ap.playing and ap.stream != null and not ap.stream.resource_path.contains("acufeno"):
			ap.create_tween().tween_property(ap, "volume_db", -30.0, 0.25)


# =============================================================================================================
# PERRITO RTA
# =============================================================================================================

## AUX incorrecto: viene bajo, pegado al piso, gruñendo; se te trepa por las piernas (las patas te clavan los
## muslos), las fauces abiertas a un palmo, la MORDIDA (sacudón y rojo) y te jala al piso del brazo, sacudiendo
## la cabeza como un perro con su presa.
func _k_rta_trepa_mordida() -> void:
	# kills2 (Joan: «aún no está clara la animación de la muerte del Perrito RTA»). Antes trepaba pegado a la cámara: una
	# mancha blanca con los ojos hinchados, tus dos manos tapándole la cara y, desde la mordida, todo rojo. Ahora se LEE,
	# desde tus ojos: te salta al pecho → caes de espaldas con él encima (su cabeza entera en cuadro, las patas clavadas en
	# tus hombros) → subes el antebrazo y te lo muerde (lo ves en sus fauces, tu otra mano le empuja el cuello) → lo sacude
	# de lado a lado, sangra → lo suelta, tu brazo cae, abre las fauces y ladra la frase a un palmo → dos dentelladas que
	# tu mano apenas frena → la mano cede y va a tu garganta. La cara del perro ya no se hincha (ScreamRig: eye_bulge).
	# El tamaño del perro no importa: todo va por su CARA (el punto que da ScreamRig sobre el esqueleto ya escalado) y por
	# el espacio de tu vista; las patas se clavan en tus hombros (abajo, a los lados del cuadro) midan lo que midan.
	KillGore.pain(fx, true)  # sin las patas todavía (IK): mientras salta y caes las mueve su animación
	if fx._rig != null:
		fx._rig.arm_stretch = 1.2
	var v := _victim()
	var me: WeakRef = weakref(self)
	var neck := func() -> Vector3:
		var km: KillMoves = me.get_ref()
		var mm: Node3D = km._m() if km != null and is_instance_valid(km.fx) else null
		return km.fx._head_point(mm) if mm != null else Vector3.ZERO
	# EL SALTO: sus patas te dan en el pecho.
	_beat("salto")
	fx._snd("sfx/kill_grunido", 3.0, 1.1)
	_lock(L(0, -0.16, 0.5), 16.0, false, Vector3(-18, 0, 0))
	_vic("escudo", 0.012)
	_impact(0.8, "sfx/caida_cuerpo", 1.5)
	if await _at(0.03):
		return
	# TE DERRIBA: caes de espaldas (la silla sale rodando) y queda encima de ti; lo miras desde abajo.
	_beat("derriba")
	_chair_away()
	_vic("manotea")
	_head(Vector3(0.0, 0.42 - _base.y, 0.28), _s(0.12), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(0.42, _s(0.14))
	_cam("cam_roll", 0.08, _s(0.12))
	_lock(L(0, -0.05, 0.5), 16.0, false, Vector3(-12, 0, 0))
	if await _at(0.15):
		return
	_impact(1.0, "sfx/caida_cuerpo", 0.8)  # tu espalda contra el piso
	_cam("cam_roll", 0.0, _s(0.1))
	fx._red = minf(fx._red, 0.2)
	if await _at(0.2):
		return
	# EL ANTEBRAZO: lo subes para cubrirte y lo atrapa; con la otra mano le empujas el cuello.
	_beat("antebrazo")
	# Tu puño sube delante de tu cara (el antebrazo entra por abajo a la derecha) y su boca se cierra sobre la muñeca:
	# la cara del perro queda justo detrás de tu mano, con la boca (5 cm bajo el punto de la cara, 7 cm hacia ti) en ella.
	_grab()
	_hands(L(-0.17, -0.31, 0.3), L(0.17, -0.31, 0.3), 1.3, 14.0)
	var bite := L(0.05, -0.01, 0.38)
	# Tu puño va DENTRO de su boca y la sigue (5 cm bajo el punto de su cara, 8 cm hacia ti): cuando sacude la cabeza, tu
	# brazo va con ella. La cara casi no se deforma aquí (la curva de la fila): es un perro mordiendo, se lee.
	var mouth := func() -> Vector3:
		var km: KillMoves = me.get_ref()
		var c: Vector3 = neck.call()
		if km != null and is_instance_valid(km.fx) and km.fx._rig != null and is_instance_valid(km.fx._rig) and km.fx._rig.last_face != Vector3.INF:
			c = km.fx._rig.last_face
		return c + v.view_point(Vector3(0.0, -0.045, 0.05)) - v.view_point(Vector3.ZERO)
	if v != null:
		v.struggle(0.012, 10.0)
		v.hold("r", mouth, "puño", neck, 16.0)
		v.hold("l", func() -> Vector3: return (neck.call() as Vector3) + v.view_point(Vector3(-0.08, -0.12, 0.05)) - v.view_point(Vector3.ZERO), "garra", neck, 6.5)
	_lock(bite, 16.0, false, Vector3(-4, 0, 18))
	if await _at(0.25):
		return
	_impact(0.9, "sfx/kill_mordida", 1.05)
	if v != null:
		v.wounds(0.55)
		v.set_param("blood", 0.55 if KillGore.enabled() else 0.0)
	KillGore.splatter(fx, 0.35, Vector2(0.5, 0.62))
	fx._red = minf(fx._red, 0.25)
	if await _at(0.33):
		return
	# LO SACUDE: la cabeza de lado a lado con tu brazo en la boca; tu mano va con él.
	_beat("sacude")
	fx._snd("sfx/kill_grunido", 5.0, 0.9)
	var swing: Array = [0.13, -0.07, 0.12, -0.04]
	for i in swing.size():
		var dx: float = swing[i]
		var roll := 26.0 if dx > 0.0 else -18.0
		fx.lock_tilt = Vector3(-4, 0, roll)
		_lock_to(bite + Vector3(dx, -0.02 * (i % 2), 0.0), _s(0.03), Tween.TRANS_QUAD, Tween.EASE_OUT)
		fx.cam_off = Vector3(dx * 0.25, 0.0, 0.0)
		fx._shake = 0.05
		Controls.vibrate(0.8, 0.5, 0.12)
		if i == 1:
			fx._snd("sfx/kill_mordida", 0.0, 0.9)
			KillGore.wet(fx, 0.8)
			KillGore.splatter(fx, 0.4, Vector2(0.42, 0.6))
			if v != null:
				v.wounds(0.9)
				v.set_param("blood", 0.85 if KillGore.enabled() else 0.0)
		if await _at(0.33 + 0.04 * (i + 1)):
			return
	fx.cam_off = Vector3.ZERO
	# LAS FAUCES: suelta el brazo (cae, herido), se alza sobre ti y te ladra la frase con la boca abierta de más.
	_beat("fauces")
	if v != null:
		v.put("r", L(0.3, -0.5, 0.16), "suelta", Vector3.INF, 2.2)  # el brazo mordido cae fuera de tu vista
		v.struggle(0.02, 11.0)
	_lock(L(0, 0.01, 0.46), 10.0, false, Vector3(-8, 0, 0))
	_hands(L(-0.19, -0.27, 0.28), L(0.19, -0.27, 0.28), 1.3, 14.0)
	if fx._rig != null:
		_tw().tween_property(fx._rig, "jaw_mult", 1.3, 0.1)
	_scream(false)
	fx._red = minf(fx._red, 0.22)
	fx._fx_goal = minf(fx._fx_goal, 0.32)
	fx._snd("sfx/rta_ladrido", 2.0, 0.6)
	if await _at(0.62):
		return
	# DENTELLADAS: dos veces se te viene a la cara y tu mano apenas lo frena.
	_beat("dentelladas")
	for i in 2:
		_lock_to(L(0.02 * (1 - 2 * i), 0.0, 0.33 - 0.03 * i), _s(0.025), Tween.TRANS_EXPO, Tween.EASE_IN)
		if await _at(0.645 + 0.11 * i):
			return
		fx._snd("sfx/kill_mordida", -3.0, 1.25)
		fx._shake = 0.06
		Controls.vibrate(0.7, 0.7, 0.15)
		if v != null:
			v.jolt("l", Vector3(0.0, 0.0, 1.2))
		_lock_to(L(0, 0.01, 0.44 - 0.03 * i), _s(0.05), Tween.TRANS_QUAD, Tween.EASE_OUT)
		if await _at(0.73 + 0.11 * i):
			return
	# LA GARGANTA: tu mano cede y se te viene encima con la boca abierta: lo último que ves es su garganta.
	_beat("garganta")
	_vic("cae", _s(0.06))
	if fx._rig != null:
		_tw().tween_property(fx._rig, "jaw_mult", 1.5, 0.08)
	fx.lock_tilt = Vector3(-4, 0, 0)
	_lock_to(L(0.0, 0.11, 0.21), _s(0.03), Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _at(0.875):
		return
	_impact(1.2, "sfx/kill_mordida", 0.85)
	KillGore.wet(fx, 1.0)
	KillGore.splatter(fx, 0.8, Vector2(0.5, 0.7))
	fx._red = minf(fx._red, 0.35)
	var thrash := _tw().set_loops(3)
	thrash.tween_property(fx, "cam_off", Vector3(0.035, -0.01, 0), _s(0.012))
	thrash.tween_property(fx, "cam_off", Vector3(-0.035, 0.01, 0), _s(0.012))
	if await _at(0.93):
		return
	# Muerte por shock: la vista se congela a tirones y se apaga.
	_beat("shock")
	KillGore.screech(fx, 0.0)
	fx._snd("sfx/latido_rapido_loop", 0.0, 1.6)
	var fr := _tw().set_loops(3)
	fr.tween_callback(func() -> void: fx._shake = 0.0; fx._shake_goal = 0.0)
	fr.tween_interval(_s(0.012))
	fr.tween_callback(func() -> void: _flash(Color(0, 0, 0, 0.8), 0.04))
	fr.tween_interval(_s(0.012))
	if await _at(0.96):
		return
	_final(L(0, 0.12, 0.15), 0.5)
	fx._fx_goal = 0.6


# =============================================================================================================
# VITZO (robótico y con glitches, nunca 8 bits)
# =============================================================================================================

## v0.3.2 (Joan: «me gusta más el anterior screamer de Vitzo… adáptalo a sus demás variantes»): vuelve el estilo Q2
## en todas sus muertes: brazos normales (no larguísimos), sin el lock a saltos, DE PIE frente a ti y derecho, las dos
## manos a los lados de tu cabeza, la pantalla-cara llenando el cuadro y glitcheando, la viñeta roja oscura detrás.
## Cada variante conserva su contexto (vidrios y bandeja, salto, correo, divisor). Mide 1,8 m (crece al salir del
## monitor: Screamers._grow_vitzo).
## Final Q2 de Vitzo: la pantalla-cara entera en cuadro (a 1,8 m, más cerca solo se veía el borde).
const VITZO_FINAL := Vector3(0, 0.0, -0.4)
const VITZO_GRAB := Screamers.VITZO_GRAB_FACE  # la pantalla-cara entera en cuadro, hombros y brazos a la vista


func _vitzo_arms() -> void:
	if fx._rig != null:
		fx._rig.arm_stretch = 1.0
	fx.lock_step_hz = 0.0
	# El cuerpo queda en su clip de reposo (el del salto es de una pasada y termina arqueado hacia atrás: con la
	# cabeza-pantalla tan grande se le veía el borde de abajo en vez de la cara).
	fx._anim(fx._m, ["idle", "stare_camera"], 1.0)


## El agarre Q2: de pie, cara a 0,5 m que se acerca, manos a los lados de tu cabeza, rojo oscuro detrás.
func _vitzo_q2(face_d: float = 0.5) -> void:
	_vitzo_arms()
	# v0.3.2d: face_d sigue siendo «qué tan encima» (0,36-0,5), pero la cara se encuadra entera: +0,16 m.
	_lock(L(0, 0.04, face_d + 0.16), 12.0, true, Vector3.ZERO)
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	fx._fx_goal = 0.8
	fx._red = 0.65
	_lock_to(L(0, 0.03, face_d + 0.04), _s(0.4))
	_vitzo_tilts()


## La cabeza-pantalla se ladea a saltos mientras grita (stop-motion robótico, como en el screamer Q2): cada ~0,22 s
## cae a un lado, se endereza o cae al otro; nunca suave.
func _vitzo_tilts() -> void:
	var rig := fx._rig
	if rig == null or not is_instance_valid(rig):
		return
	var seq := [0.26, 0.26, -0.08, -0.3, -0.3, 0.12, 0.34, 0.0, -0.22, 0.28, 0.28, -0.16]
	var tw := _tw()
	for a in seq:
		tw.tween_callback(func() -> void:
			if is_instance_valid(rig):
				rig.head_tilt = a)
		tw.tween_interval(0.22)


## Correo a Vitzo (sentado): la pantalla revienta en vidrios; te agarra la cabeza y te mete la cara en el monitor
## (v0.3.2, Joan: «te mete al Ezlaki a la fuerza, grotesco»: atraviesas el vidrio, cortes y sangre); adentro, la
## bandeja que se inunda; vuelve a la cara Q2 gritando.
func _k_vitzo_vidrio_bandeja() -> void:
	var m := _m()
	_vitzo_arms()
	_grab()
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_lock(VITZO_GRAB, 12.0, true, Vector3.ZERO)
	_vic("munecas", 0.014)  # te agarras de sus brazos
	_beat("agarre")
	_beat("vidrio")
	_desk_jolt(1.0, true)
	fx._snd("sfx/monitor_rompe", 6.0)
	fx._snd("sfx/kill_vidrio", 6.0)
	_impact(1.0, "sfx/kill_golpe_seco", 1.3, true)
	KillProps.debris(fx, 22, Vector3(0.05, 0.07, 0.003), [Color(0.7, 0.9, 1.0, 0.55), Color(0.3, 1.0, 0.6, 0.6)], fx._cam().global_transform * L(0, -0.05, 0.55),
		func(_k: int) -> Vector3: return (fx._eye() - fx._cam().global_transform * L(0, -0.05, 0.55)).normalized() * randf_range(1.5, 3.5) + Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 1.2), randf_range(-1.2, 1.2)), 3.0, true)
	_prop("vidrios")
	if await _at(0.2):
		return
	# Te mete la cara en la pantalla a la fuerza: el vidrio te corta (sangre en la vista).
	_beat("adentro")
	_vic_plant(fx._floor_y() + 0.75, 0.3, 0.3, 0.02)  # te apoyas en el escritorio con las dos manos: no quieres entrar
	_windup(_s(0.03))
	_wind(_s(0.1), "", 0.08)
	_head(Vector3(0, -0.05, -0.45), _s(0.15), Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _at(0.3):
		return
	_impact(1.0, "sfx/kill_vidrio", 0.8)
	_desk_jolt(0.8)
	var vg := _victim()
	if vg != null:
		vg.wounds(0.8)
		vg.set_param("blood", 0.6 if KillGore.enabled() else 0.0)
	KillGore.wet(fx, 1.0)
	KillGore.splatter(fx, 1.0, Vector2(0.42, 0.4))
	KillGore.splatter(fx, 0.7, Vector2(0.65, 0.58))
	_inbox_flood(_s(0.6))
	_prop("bandeja")
	if await _at(0.42):
		return
	_head(Vector3(0, -0.02, -0.2), _s(0.1))
	_vitzo_q2(0.5)
	_scream(false)
	_vic("munecas", 0.01)
	if await _at(0.84):
		return
	_final(VITZO_FINAL)


## Bandeja de entrada que se inunda (2D): filas de correos que entran sin parar con su cara en el centro.
func _inbox_flood(t: float) -> void:
	var w := fx._window(KillProps.t("SCR_K_INBOX", "Ezlaki Mail — Bandeja de entrada"), "", Color(0.2, 0.85, 0.5), 1500, 860)
	w.name = "BandejaVitzo"
	var list := VBoxContainer.new()
	list.position = Vector2(20, 54)
	list.size = Vector2(1460, 790)
	list.clip_contents = true
	w.add_child(list)
	var subjects := KillProps.t("SCR_K_INBOX_SUBJECTS", "RE: RE: RE: STATUS|URGENTE: confirmar|FW: Reminder").split("|")
	var n := 26 if not KillProps.light_mode() else 12
	var me: WeakRef = weakref(fx)
	for i in n:
		fx.get_tree().create_timer(t * float(i) / n, true).timeout.connect(func() -> void:
			var f0: Screamers = me.get_ref()
			if f0 == null or f0._done or not is_instance_valid(list):
				return
			var row := Label.new()
			row.text = "●  Vitzo  ·  %s  ·  %s" % [subjects[i % subjects.size()], GameState.clock_text()]
			row.add_theme_font_size_override("font_size", 36)
			row.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9) if i % 3 else Color(1.0, 0.35, 0.3))
			list.add_child(row)
			list.move_child(row, 0)
			if i % 4 == 0:
				f0._snd("sfx/correo_recibido", -6.0, 0.8 + 0.05 * (i % 6)))
	var face := TextureRect.new()
	face.texture = fx._face_tex("res://assets/ui/vitzo_cara.png")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.position = Vector2(520, 180)
	face.size = Vector2(460, 460)
	face.material = fx._horror_material()
	face.modulate = Color(1, 1, 1, 0.0)
	w.add_child(face)
	var tw := face.create_tween()
	tw.tween_interval(t * 0.25)
	tw.tween_property(face, "modulate", Color(1, 1, 1, 0.9), t * 0.3)
	w.modulate = Color(1, 1, 1, 0.0)
	w.create_tween().tween_property(w, "modulate", Color(1, 1, 1, 0.92), 0.12)


## Vitzo de pie (te persiguió): como el clip Q2 que eligió Joan: te alcanza y salta; caes de espaldas, te
## inmoviliza (las manos en tus hombros, crujido) y su pantalla-cara Q2 te grita encima, grotesca (v0.3.2).
func _k_vitzo_salto() -> void:
	var m := _m()
	_vitzo_arms()
	_grab()
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_lock(VITZO_GRAB, 12.0, false, Vector3(-10, 0, 0))
	_beat("agarre")
	_beat("salto")
	_impact(1.0, "sfx/caida_cuerpo", 0.9)
	_vic("manotea")
	_chair_away()
	_head(Vector3(0, 0.25 - _base.y, 0.3), _s(0.14), Tween.TRANS_QUAD, Tween.EASE_IN)
	_pitch(1.3, _s(0.15), Tween.TRANS_QUAD, Tween.EASE_IN)
	_cam("cam_roll", -0.5, _s(0.12)).chain().tween_property(fx, "cam_roll", -0.12, _s(0.15))
	if await _at(0.22):
		return
	_beat("suelo")
	_impact(1.0, "sfx/trainer_golpe", 0.6)
	KillGore.bone(fx, 0.9)
	_hands(L(-0.24, -0.22, 0.14), L(0.24, -0.22, 0.14), 1.2, 16.0)  # te clava los hombros
	_grip("garra", "garra", L(-0.24, -0.6, 0.0), L(0.24, -0.6, 0.0))
	_lock_to(L(0, 0.06, 0.6), _s(0.15))
	fx._snd("sfx/vitzo_arrastre_loop", 2.0, 1.4)
	_vic("munecas", 0.016)
	var fd := Vector3(0, 0.25 - _base.y, 0.3)
	var hb := _head(fd + Vector3(0, 0.05, 0), 0.07)  # la cabeza rebota en el piso
	hb.tween_property(_p().head, "position", _base + fd, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if await _at(0.36):
		return
	_lock(L(0, 0.05, 0.62), 12.0, false, Vector3.ZERO)
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	fx._fx_goal = 0.8
	fx._red = 0.65
	_scream(false)  # «¡ENVÍENME CORREOOO!»
	_vic("cara", 0.016)  # empujas su pantalla
	_lock_to(L(0, 0.03, 0.5), _s(0.4))
	_vitzo_tilts()
	if await _at(0.66):
		return
	KillGore.splatter(fx, 0.9, Vector2(0.5, 0.75))
	KillGore.wet(fx, 0.8)
	_vic("munecas", 0.008)
	if await _at(0.84):
		return
	_final(VITZO_FINAL)


# --- La fusión (Reminder ignorado) ---------------------------------------------------------------------------

const FUSION_SKIP_AFTER := 3.0  # s: desde aquí se puede saltar, solo si ya la viste antes (muerte repetida)
## Tiempos de la fusión (v0.3.2d), en segundos desde el agarre. En primera persona hasta "tercera"; después cada etapa
## dura lo que su clip (k32/fus_*); el grito, lo que la toma del agente; la escena 2 ocupa lo que quede de la fila.
const FUSION_T: Dictionary = {"manos": 0.09, "resiste": 0.8, "aparta": 1.8, "verde": 2.7, "tercera": 3.5}
const FUSION_LEN: Dictionary = {"tercera": 1.6, "arranca": 1.3, "sonrisa": 1.5, "lentes": 1.0, "antena": 0.95, "rigido": 1.8}
## El empujón del clip fus_empuja (la misma curva que tools/anim/clips_kills.py): Vitzo va y viene con tus manos.
const FUSION_PUSH: Array = [[0.0, 0.0], [0.2, -0.3], [0.36, 1.07], [0.48, 1.0], [0.78, 0.25], [1.0, -0.22], [1.15, 1.05], [1.27, 0.95], [1.6, 0.0]]
## kills2 (Joan: «la fusión está perfecta, solo creo que debería durar un poquito menos… sin quitar el detalle de la pelea
## y resistirse con grito»): mismo guion, mismas etapas, a FUSION_TEMPO: todo lo que no es el grito (primera persona,
## empujones, arrancarse lo verde, mandíbula, lentes, antena, rígido) corre 1,3 veces más rápido (clips, cortes de cámara y
## golpes: _ts estira el reloj, _fplay acelera el clip); el grito dura lo que la voz del agente, como antes; la sala dura
## lo que el reminder dos veces entero + FUSION_SALA_PAD (antes: lo que sobrara de 22,9 s). De 22,9 s a 18,2-19,9 s.
const FUSION_TEMPO := 1.3
const FUSION_SALA_PAD := 0.35
## Integración kills2: a tempo fijo 1,3 la fusión quedaba entre 18,3 y 19,8 s según el agente (Jiroshi y Juan solo 14 %
## más corta, por su grito y su reminder más largos). El tempo de cada muerte se calcula para que el total caiga en
## FUSION_TARGET_S (22,9 × 0,825 = 17,5 % menos, en la mitad del 15-20 % que pidió Joan), entre FUSION_TEMPO_MIN y
## FUSION_TEMPO_MAX; el grito y el reminder siguen durando lo que su voz.
const FUSION_TARGET_S := 18.9
const FUSION_TEMPO_MIN := 1.2
const FUSION_TEMPO_MAX := 1.5
var _fus_tempo: float = FUSION_TEMPO
var _fused: Node3D = null
var _skip: bool = false
var _fus_on: bool = false
var _fus_tg: float = 0.0  # s del guion en que empieza el grito (hasta ahí, a tempo)
var _fus_tr: float = 0.0  # s del guion en que termina (desde ahí, otra vez a tempo)


## Segundo real (desde el agarre) de un segundo del guion de la fusión.
func _fus_map(sec: float) -> float:
	if not _fus_on:
		return sec
	if sec <= _fus_tg:
		return sec / _fus_tempo
	if sec <= _fus_tr:
		return _fus_tg / _fus_tempo + (sec - _fus_tg)
	return _fus_tg / _fus_tempo + (_fus_tr - _fus_tg) + (sec - _fus_tr) / _fus_tempo


## v0.3.2, la muerte de ignorar el recordatorio de Vitzo (vitzo_reminder): él se vuelve el recordatorio. Joan: «agarra
## al agente y se fusiona a la fuerza con él en una animación grotesca, luego cambia la escena y el agente está al
## centro de la sala de operaciones (PCs), parado y repitiendo el reminder de Vitzo». v0.3.2d (Joan: «que dure más la
## animación donde el agente se resiste a fusionarse con Vitzo, más detallado y grotesco, incluso que grite cuando ya
## no puede resistirse y al final se fusione por completo»): la resistencia va POR ETAPAS y se pierde terreno a la vista.
##   Escena 1, primera persona (3,5 s): te tomó la cabeza en el salto; grita «¡ENVÍENME CORREOOO!» y recién entonces
##     revientan sus recordatorios alrededor. Lo EMPUJAS con las dos manos (tus brazos de verdad: KillVictim), te paras
##     de la silla, que sale rodando, y retrocedes al pasillo con él colgado de tu cabeza; APARTAS LA CARA y te la
##     endereza a tirones; bajas la vista: el VERDE te trepa por las manos y te lo quieres arrancar.
##   Escena 1, tercera persona (~12 s; clips k32/fus_* de tools/anim/clips_kills.py): de perfil, lo empujas dos veces y
##     se te mete en la cara (glitch); te ARAÑAS el cuello y la mejilla; la MANDÍBULA se te abre en cuatro tirones hasta
##     la sonrisa de oreja a oreja; los LENTES se te clavan (sangre en las sienes, no con «Reducido») y te brotan sus
##     perillas en las orejas; la ANTENA te rompe el cráneo y caes sobre una rodilla; ya no puedes: de rodillas, el
##     pecho en arco, GRITAS con tu propia voz, que se va rompiendo hasta ser la de Vitzo
##     (voces/agentes/fusion_grito_<agente>, ES/EN); recién ahí la fusión se completa: los brazos caen muertos y te
##     pones de pie en tres tirones, firme, la cabeza ladeada.
##   Corte seco. Escena 2 (tercera persona, órbita lenta): tu agente fusionado, quieto en el centro de la sala de
##     operaciones, repite el reminder con su voz rota en la de Vitzo (voces/agentes/fusion_reminder_<agente>); los
##     demás siguen tipeando. Fundido a la pantalla de muerte.
##   ~23 s (la fila: 22,9; la sala dura lo que quede, ≥ 6,4 s: el reminder cabe entero dos veces con cualquier agente
##   e idioma). Desde los 3 s se salta con [Espacio]/[Enter] solo si ya la viste (Loc "kills_vistas").
func _k_vitzo_fusion() -> void:
	var m := _m()
	var p := _p()
	var agent := GameState.agent
	var ag := agent.to_lower()
	_vitzo_arms()
	_grab()
	var seen := _seen("vitzo_fusion")
	fx.last_info["fusion_saltable"] = seen
	if seen:
		# Muerte repetida: desde los 3 s, «[Espacio] Saltar» abajo a la derecha.
		var me0: WeakRef = weakref(fx)
		fx.get_tree().create_timer(maxf(FUSION_SKIP_AFTER - fx._clock, 0.05), true).timeout.connect(func() -> void:
			var f0: Screamers = me0.get_ref()
			if f0 == null or f0._done or f0._top == null:
				return
			var hint := Label.new()
			hint.name = "PistaSaltar"
			hint.text = tr("SCR_K2_SALTAR")
			hint.add_theme_font_size_override("font_size", 22)
			hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
			hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			hint.offset_left = -260
			hint.offset_top = -60
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			f0._top.add_child(hint))
	# --- Los tiempos: el grito del agente manda el largo de su etapa (el clip va más lento o más rápido para que los
	# brazos caigan muertos justo cuando la voz termina de romperse).
	var scream_slot := "voces/agentes/fusion_grito_%s" % ag
	var scream_path := AudioManager.voice_path(scream_slot)
	var scream_len := 3.2
	if scream_path != "":
		var sst := load(scream_path) as AudioStream
		if sst != null:
			scream_len = sst.get_length()
	var g_speed := clampf(2.69 / maxf(scream_len - 0.25, 1.0), 0.78, 1.15)
	var g_len := 3.45 / g_speed
	var t_ap: float = FUSION_T["aparta"]
	var t_ve: float = FUSION_T["verde"]
	var t_tp: float = FUSION_T["tercera"]
	var t_arranca := t_tp + float(FUSION_LEN["tercera"])
	var t_sonrisa := t_arranca + float(FUSION_LEN["arranca"])
	var t_lentes := t_sonrisa + float(FUSION_LEN["sonrisa"])
	var t_antena := t_lentes + float(FUSION_LEN["lentes"])
	var t_grito := t_antena + float(FUSION_LEN["antena"])
	var t_rigido := t_grito + g_len
	var t_corte := t_rigido + float(FUSION_LEN["rigido"])
	_fus_tg = t_grito
	_fus_tr = t_rigido
	# La sala: el reminder dos veces entero (tomas _01 y _02 del agente) + un respiro; la fila solo es el tope.
	var two := 0.0
	for rep in [1, 2]:
		var rp := AudioManager.voice_path("voces/agentes/fusion_reminder_%s_%02d" % [ag, rep])
		var rst := load(rp) as AudioStream if rp != "" else null
		two += (rst.get_length() if rst != null else 2.8) + 0.12
	# El tempo que deja el total en FUSION_TARGET_S (lo que no es voz se acelera; la voz dura lo que dura).
	var fixed_s := _t0 + g_len + two + FUSION_SALA_PAD + Screamers.CUT
	var scaled_s := t_grito + (t_corte - t_rigido)
	_fus_tempo = clampf(scaled_s / maxf(FUSION_TARGET_S - fixed_s, 0.1), FUSION_TEMPO_MIN, FUSION_TEMPO_MAX)
	_fus_on = true
	var t_corte_r := _fus_map(t_corte)
	var need := t_corte_r + two + FUSION_SALA_PAD
	if need < _R:
		_R = need
		fx.seconds = _t0 + _R + Screamers.CUT
		fx.last_info["duracion"] = fx.seconds
	fx.last_info["fusion_corte_s"] = _t0 + t_corte_r
	fx.last_info["fusion_sala_s"] = _R - t_corte_r
	fx.last_info["fusion_tempo"] = _fus_tempo

	# ================= PRIMERA PERSONA =================
	# El agarre: te tomó la cabeza en el aire (intro zarpazo). Su pantalla-cara llena la vista.
	_lock(VITZO_GRAB, 14.0, true, Vector3.ZERO)
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_beat("agarre")
	if await _ts(FUSION_T["manos"]):
		return
	# Te aprieta la cabeza y grita; DESPUÉS del golpe revientan sus recordatorios alrededor (sin pared antes del salto).
	_beat("manos")
	_impact(0.9, "sfx/kill_golpe_seco", 1.3)
	_popups_burst()
	fx._fx_goal = 0.8
	fx._red = 0.6
	_lock_to(L(0, 0.03, 0.52), 0.45, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_vitzo_tilts()
	_scream(false)  # «¡ENVÍENME CORREOOO!»
	if await _ts(FUSION_T["resiste"]):
		return
	# RESISTES (1): lo empujas con las dos manos; te paras de la silla (sale rodando) y retrocedes al pasillo con él
	# colgado de tu cabeza. Tres empujones: cada uno lo aparta menos y él vuelve más cerca.
	_beat("resiste")
	var v := KillVictim.of(fx)
	if v != null:
		v.both(L(-0.14, -0.09, 0.33), L(0.14, -0.09, 0.33), "plana", L(0, -0.04, 1.2), 5.0)
		v.struggle(0.01, 11.0)
	fx._snd("voces/agentes/fusion_protesta_%s" % ag, 2.0)
	var seated := p.seated
	var back := 0.8 if seated else 0.3
	# El lado más despejado del pasillo es el de la cámara de la tercera persona; la silla rueda al otro.
	var pb := p.global_transform.basis
	var aisle := p.head.global_position + pb.z * back
	aisle.y = fx._floor_y() + 1.3
	var side := 1.0 if _free(aisle, pb.x, 2.6) >= _free(aisle, -pb.x, 2.6) - 0.3 else -1.0
	if seated:
		_chair_roll(-pb.x * side * 0.95 + pb.z * 0.8, 1.9 * side, 0.7)
	_head(Vector3(0, 1.6 - _base.y, back), 0.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	for i in 3:
		if await _ts(float(FUSION_T["resiste"]) + 0.2 + 0.27 * i):
			return
		if v != null:
			v.both(L(-0.14, -0.07, 0.46), L(0.14, -0.07, 0.46), "plana", L(0, -0.04, 1.2), 9.0)
		_lock_to(L(0, 0.03, 0.72 - 0.05 * i), 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
		_cam("cam_off", Vector3(0, 0, -0.03), 0.07).chain().tween_property(fx, "cam_off", Vector3.ZERO, 0.12)
		fx._snd("sfx/kill_golpe_seco", -5.0, 1.5 + 0.1 * i)
		fx._shake = 0.05
		if await _ts(float(FUSION_T["resiste"]) + 0.32 + 0.27 * i):
			return
		if v != null:
			v.both(L(-0.14, -0.1, 0.31 - 0.025 * i), L(0.14, -0.1, 0.31 - 0.025 * i), "plana", L(0, -0.04, 1.2), 4.5)
		_lock_to(L(0, 0.03, 0.5 - 0.035 * i), 0.15, Tween.TRANS_QUAD, Tween.EASE_IN)
	if await _ts(t_ap):
		return
	# RESISTES (2): apartas la cara. Te la endereza de un tirón; la apartas al otro lado; otro tirón, más fuerte.
	_beat("aparta")
	_green_creep(t_tp - t_ap)
	if v != null:
		v.put("l", L(-0.15, -0.1, 0.34), "plana", L(0, -0.04, 1.2), 4.5)
		v.put("r", L(0.2, 0.0, 0.26), "garra", L(0.24, 0.02, 0.6), 5.0)  # la derecha se le prende de la muñeca
	_cam("glance", Vector2(0.05, -0.44), 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_lock_to(L(0, 0.03, 0.46), 0.3)
	KillGore.pain(fx, true)
	if await _ts(t_ap + 0.34):
		return
	_cam("glance", Vector2.ZERO, 0.07, Tween.TRANS_EXPO, Tween.EASE_IN)
	_cam("cam_roll", 0.16, 0.06).chain().tween_property(fx, "cam_roll", 0.0, 0.16)
	_impact(0.6, "sfx/kill_golpe_seco", 1.1)
	KillGore.bone(fx, 0.5)
	if await _ts(t_ap + 0.5):
		return
	_cam("glance", Vector2(0.04, 0.42), 0.18, Tween.TRANS_QUAD, Tween.EASE_OUT)
	if v != null:
		v.put("r", L(0.15, -0.1, 0.34), "plana", L(0, -0.04, 1.2), 4.5)
		v.put("l", L(-0.2, 0.0, 0.26), "garra", L(-0.24, 0.02, 0.6), 5.0)
	if await _ts(t_ap + 0.8):
		return
	_cam("glance", Vector2.ZERO, 0.06, Tween.TRANS_EXPO, Tween.EASE_IN)
	_cam("cam_roll", -0.2, 0.06).chain().tween_property(fx, "cam_roll", 0.0, 0.16)
	_impact(0.85, "sfx/kill_golpe_seco", 0.9)
	KillGore.bone(fx, 0.8)
	_lock_to(L(0, 0.02, 0.42), 0.1)
	_glitch_burst(2)
	if await _ts(t_ve):
		return
	# RESISTES (3): algo te sube por los brazos. Bajas la vista: las venas verdes te trepan por las manos; con la
	# derecha te arañas el antebrazo izquierdo, quieres arrancártelo.
	_beat("verde")
	_cam("glance", Vector2(-0.62, 0.0), 0.22, Tween.TRANS_QUAD, Tween.EASE_OUT)
	if v != null:
		v.struggle(0.006, 15.0)
		v.put("l", L(-0.09, -0.34, 0.3), "garra", L(-0.04, 0.1, 0.0), 4.0)
		v.put("r", L(0.1, -0.33, 0.3), "garra", L(0.04, 0.1, 0.0), 4.0)
		v.tween_param("veins", 0.0, 1.0, 0.5)
		v.tween_param("green", 0.0, 0.8, 0.75)
	fx._snd("sfx/kill_elastico", 4.0, 0.5)
	KillGore.wet(fx, 0.9)
	KillGore.pain(fx, true)
	fx._snd("sfx/vitzo_arrastre_loop", 2.0, 0.7)
	if fx._shout_label != null and is_instance_valid(fx._shout_label):
		fx._shout_label.create_tween().tween_property(fx._shout_label, "modulate:a", 0.0, 0.3)
	if await _ts(t_ve + 0.32):
		return
	if v != null:
		var along := Vector3(-0.03, -0.04, 0.05)  # del dorso de la muñeca izquierda hacia el codo (espacio de la vista)
		var scratch := func() -> Vector3:
			var w := v.wrist("l")
			if w == Vector3.INF:
				return v.view_point(L(-0.06, -0.3, 0.26))
			return w + fx.view_xf().basis * (along * (1.0 + 0.7 * sin(fx._clock * 24.0)) + Vector3(0.05, 0.055, 0.02))
		var scratch_palm := func() -> Vector3:
			var w2 := v.wrist("l")
			return (w2 + fx.view_xf().basis * along) if w2 != Vector3.INF else v.view_point(L(-0.1, -0.4, 0.3))
		v.hold("r", scratch, "gancho", scratch_palm, 8.0)
	fx._snd("sfx/kill_tela", 0.0, 1.5)
	if await _ts(t_tp - 0.14):
		return
	# Te levanta la cara de un tirón hacia su pantalla: el corte cae en el golpe.
	_cam("glance", Vector2.ZERO, 0.1, Tween.TRANS_EXPO, Tween.EASE_IN)
	_lock_to(L(0, 0.0, 0.3), 0.12, Tween.TRANS_EXPO, Tween.EASE_IN)
	if v != null:
		v.drop()
	if await _ts(t_tp):
		return

	# ================= TERCERA PERSONA: te VES =================
	_beat("tercera")
	if v != null:
		v.visible = false
	for c in fx._top.get_children():
		if str(c.name) == "VerdeFusion" or c is KillGore.Blood:
			(c as CanvasItem).visible = false  # la vista va limpia (sin el verde ni sangre en el lente): se tiene que VER el cuerpo
	_popups_clear()
	fx.glance = Vector2.ZERO
	fx.cam_roll = 0.0
	fx.cam_pitch = 0.0
	fx.cam_off = Vector3.ZERO
	fx._red = 0.1
	fx._fx_goal = 0.25
	fx._shake_goal = 0.0
	fx._shake = 0.0
	if fx._face_light != null and is_instance_valid(fx._face_light):
		fx._face_light.light_energy = 0.0  # la luz de cara va con TU vista: ahora quedaría pegada a su cara (lo quemaba)
	_fused = VitzoFusion.build(fx, agent, true)
	VitzoFusion._stage_set(_fused, "hw", 0.0)  # lo de máquina le brota después (con los lentes)
	VitzoFusion._stage_set(_fused, "hair", 1.0)  # todavía es él, con su pelo: se le va a caer a mechones
	VitzoFusion.stage(_fused, 0.14, 0.0, 0.0, 0.0)  # apenas verde, sin lentes ni sonrisa ni antena
	VitzoFusion._stage_set(_fused, "veins", 0.4)
	VitzoFusion._stage_set(_fused, "hands", 0.8)  # las manos ya las tenías verdes (lo último que viste)
	var frig := _fused.get_meta("rig", null) as CharacterRig
	var ap: AnimationPlayer = null
	if frig != null and frig.animator != null:
		var lib_path := "res://assets/anim/%s_kills.res" % CharacterRig.agent_model(agent)
		if ResourceLoader.exists(lib_path):
			var flib := load(lib_path) as AnimationLibrary
			fx.last_info["fusion_mandibula_claves"] = fix_jaw(flib, _fused)
			frig.animator.add_library("k32", flib)
		frig.animator.look_enabled = false  # la cabeza la llevan los clips (se aparta, latiguea, se va atrás)
		ap = frig.animator.player
	_fplay(frig, "fus_empuja", true, 1.0)
	var fwd3 := -_fused.global_transform.basis.z
	var right3 := _fused.global_transform.basis.x * side
	var floor_y := fx._floor_y()
	# Los ojos del agente: en reposo (eye0, del esqueleto) y con la pose de cada cuadro (eye_fn; el primer cuadro el
	# hueso aún no se actualizó: vale el reposo).
	var eye0 := VitzoFusion.head_point(_fused) + fwd3 * 0.09 + Vector3(0, 0.011, 0)
	var eye_fn := func() -> Vector3:
		if not is_instance_valid(_fused):
			return eye0
		var e0 := VitzoFusion.face_point(_fused)
		return e0 if e0.distance_to(eye0) < 0.9 else eye0
	# Tu vista (de la que cuelgan Vitzo y sus manos) va con los ojos del agente: él sigue agarrado a ESA cabeza. Mientras
	# lo empujas, va y viene con tus manos (la curva del clip). Parado en el piso: su pantalla a la altura de tu cuello.
	var st := {"empuja": true}
	var each := KillProps.Each.new()
	each.name = "VistaEnLaCabeza"
	fx._stage.add_child(each)
	each.fn = func(_d: float) -> void:
		if not is_instance_valid(_fused) or not is_instance_valid(p):
			return
		var e: Vector3 = eye_fn.call()
		p.head.global_position = e
		p.head.rotation.x = 0.0
		if bool(st["empuja"]):
			var sh := _kf(fposmod(ap.current_animation_position, 1.6), FUSION_PUSH) if ap != null and ap.is_playing() else 0.0
			fx.lock_face = L(0, floor_y + 1.4 - e.y, 0.5 + 0.125 * clampf(sh, -0.3, 1.1))
	p.head.global_position = eye0
	p.head.rotation.x = 0.0
	var vy := floor_y + 1.4 - eye0.y
	_lock(L(0, vy, 0.5), 20.0, true, Vector3.ZERO)
	_hands(L(-0.1, 0.0, -0.07), L(0.1, 0.0, -0.07), 1.0, 22.0)
	_grip("garra", "garra")
	if m != null and is_instance_valid(m):
		m.global_transform = fx.lock_want(fx.lock_face, true, Vector3.ZERO)  # sin viaje: ya está ahí al cortar
	# La cámara de la tercera persona (con su luz). Un plano se da en metros desde los ojos del agente DE PIE: adelante
	# (hacia donde mira), al lado de la cámara (el lado despejado del pasillo), arriba. Los planos abiertos van por el
	# pasillo (adelante están el escritorio y los monitores).
	var cam3 := VitzoFusion.camera(fx, eye0 + right3 * 2.2, eye0)
	var shot := VitzoFusion.Shot.new()
	shot.name = "TomaFusion"
	shot.cam = cam3
	shot.soft = fx._soft
	shot.light = VitzoFusion.shot_light(fx)
	fx._stage.add_child(shot)
	# Contraluz verde detrás y arriba (del lado opuesto a la cámara): el traje negro se recorta contra el fondo oscuro.
	var rim := VitzoFusion.shot_light(fx)
	rim.name = "LuzContra"
	rim.light_color = Color(0.45, 1.0, 0.6)
	rim.light_energy = 1.7
	rim.omni_range = 3.4
	rim.global_position = eye0 - fwd3 * 0.9 - right3 * 0.55 + Vector3(0, 0.45, 0)
	var at := func(f: float, r: float, u: float) -> Vector3:
		return _clear_pos(eye0, eye0 + fwd3 * f + right3 * r + Vector3(0, u, 0))
	var face_fn := func() -> Vector3: return eye_fn.call()
	var neck_fn := func() -> Vector3: return (eye_fn.call() as Vector3) - Vector3(0, 0.13, 0)
	# De perfil, cuerpo entero (los pies plantados, el empujón se lee), acercándose.
	var mid := func() -> Vector3: return (eye_fn.call() as Vector3) + fwd3 * 0.26 - Vector3(0, 0.42, 0)
	shot.cut(at.call(0.3, 2.25, -0.3), at.call(0.32, 1.9, -0.35), 1.6 / _fus_tempo, mid, 50.0, 48.0)
	_flash(Color(0, 0, 0, 1), 0.06)
	KillGore.pain(fx, true)
	for i in 2:
		if await _ts(t_tp + float([0.34, 1.13][i])):
			return
		fx._snd("sfx/kill_golpe_seco", -3.0, 1.4 - 0.2 * i)  # el empujón
		KillGore.slam(fx, 0.35)
		shot.kick = 0.006
		fx._fx_k = minf(1.0, fx._fx_k + 0.25)
	if await _ts(t_tp + 1.27):
		return
	# …y se te METE: la pantalla se te estrella en la cara (0,1 s), el cuerpo se le achica y se desarma en glitch.
	st["empuja"] = false
	fx.lock_rate = 40.0
	_lock_to(L(0, vy + 0.12, 0.2), 0.09, Tween.TRANS_EXPO, Tween.EASE_IN)
	if await _ts(t_tp + 1.37):
		return
	_flash(Color(0.2, 1.0, 0.45, 0.4), 0.08)
	fx._fx_k = 1.0
	shot.kick = 0.014
	fx._snd("sfx/estatica_rafaga_02", -2.0)
	fx._snd("sfx/ww_popup_corrupto", 0.0, 0.8)
	KillGore.slam(fx, 0.8)
	KillGore.pain(fx, true)
	_lock_to(L(0, 0.0, 0.04), 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	_tw().tween_property(fx, "lock_scale", 0.4, 0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if m != null:
		var blink := m.create_tween()
		for gap in [0.09, 0.05]:
			blink.tween_interval(float(gap))
			blink.tween_callback(func() -> void:
				if is_instance_valid(m):
					m.visible = false)
			blink.tween_interval(0.028)
			blink.tween_callback(func() -> void:
				if is_instance_valid(m):
					m.visible = true)
	if await _ts(t_arranca):
		return
	# Ya está dentro. Te ARAÑAS el cuello y la mejilla (te quieres arrancar lo verde), encorvado, tambaleando; el pelo se
	# te cae a mechones con cada arañazo.
	_beat("arranca")
	if m != null:
		m.visible = false
	fx.lock_on = false
	_grab(false)
	_flash(Color(0.2, 1.0, 0.45, 0.5), 0.1)
	fx._fx_k = 1.0
	_impact(0.8, "sfx/kill_golpe_seco", 0.8)
	KillGore.wet(fx, 1.0)
	_fplay(frig, "fus_arranca", true, 1.15)
	VitzoFusion.set_shake(_fused, 0.1)
	VitzoFusion.stage_to(_fused, "green", 0.5, 1.2)
	VitzoFusion.stage_to(_fused, "veins", 1.0, 0.6)
	shot.kick = 0.012
	shot.cut(at.call(1.2, -0.5, -0.25), at.call(0.95, -0.38, -0.28), 1.3 / _fus_tempo, neck_fn, 48.0, 46.0)
	for i in 4:
		if await _ts(t_arranca + 0.14 + 0.29 * i):
			return
		fx._snd("sfx/kill_tela" if i % 2 == 0 else "sfx/kill_papel_rasga", -2.0, 1.5 - 0.1 * i)  # las uñas
		VitzoFusion.stage_to(_fused, "hair", float([0.82, 0.62, 0.45, 0.3][i]), 0.12)
		_hair_fall(4)
		if i % 2 == 1:
			KillGore.pain(fx, true)
			if KillGore.enabled():
				# gotas del cuello arañado
				KillProps.debris(fx, KillProps.count(5), Vector3(0.006, 0.006, 0.006), [Color(0.36, 0.0, 0.02), Color(0.2, 0.5, 0.25)], VitzoFusion.face_point(_fused, Vector3(0.06, -0.1, 0.05)),
					func(_k: int) -> Vector3: return Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.7), randf_range(-0.4, 0.4)), 4.0)
	if await _ts(t_sonrisa):
		return
	# La MANDÍBULA: se sujeta la cara con las dos manos y la boca se le abre igual, más con cada tirón (tres); en el
	# cuarto los dientes se le cierran de golpe: la sonrisa de oreja a oreja.
	_beat("sonrisa")
	_fplay(frig, "fus_mandibula", false, 1.5, 0.3)
	VitzoFusion.set_shake(_fused, 0.0)
	VitzoFusion.stage_to(_fused, "green", 0.7, 1.4)
	shot.cut(at.call(0.74, 0.13, 0.03), at.call(0.56, 0.05, 0.0), 1.5 / _fus_tempo,
		func() -> Vector3: return (eye_fn.call() as Vector3) - Vector3(0, 0.04, 0), 40.0, 38.0)
	for i in 4:
		if await _ts(t_sonrisa + float([0.107, 0.527, 0.96, 1.327][i])):
			return
		VitzoFusion.stage_to(_fused, "grin", float([0.3, 0.6, 0.9, 1.0][i]), 0.06)
		VitzoFusion.stage_to(_fused, "open", float([0.45, 0.75, 1.0, 0.0][i]), 0.05)
		VitzoFusion.stage_to(_fused, "hair", float([0.2, 0.1, 0.0, 0.0][i]), 0.1)
		if i < 3:
			_hair_fall(3)
		else:
			fx._snd("sfx/kill_mordida", 2.0, 1.2)  # los dientes se cierran: clac
		KillGore.bone(fx, 0.45 + 0.15 * i)
		fx._snd("sfx/kill_elastico", 2.0 + i, 0.9 - 0.08 * i)
		shot.kick = 0.004 + 0.002 * i
		fx._fx_k = minf(1.0, fx._fx_k + 0.3)
		if i % 2 == 0:
			KillGore.pain(fx, true)
	if await _ts(t_lentes):
		return
	# Los LENTES: se materializan a saltos delante de la cara y se le CLAVAN; las manos suben a las sienes y tiran del
	# marco; sangre donde entra (no con «Reducido») y le brotan las perillas de Vitzo en las orejas.
	_beat("lentes")
	_fplay(frig, "fus_lentes", false, 1.55)
	VitzoFusion.stage_to(_fused, "green", 0.85, 0.9)
	VitzoFusion.stage_to(_fused, "glasses", 1.0, 0.5, true)
	fx._snd("sfx/ww_popup", 0.0, 0.6)
	shot.cut(at.call(0.8, -0.18, -0.33), at.call(0.68, -0.12, -0.3), 1.0 / _fus_tempo, face_fn, 40.0, 38.0, 0.12 * side)
	if await _ts(t_lentes + 0.5):
		return
	VitzoFusion.bleed(fx, _fused, 0.9)
	KillGore.wet(fx, 0.7)
	KillGore.bone(fx, 0.6)
	fx._snd("sfx/kill_plastico_quiebra", 0.0, 1.2)
	VitzoFusion.stage_to(_fused, "hw", 1.0, 0.16)
	KillGore.pain(fx, true)
	shot.kick = 0.007
	fx._fx_k = 1.0
	if await _ts(t_antena):
		return
	# La ANTENA le rompe el cráneo desde adentro: la cabeza se le va atrás, las manos salen despedidas, cae sobre una
	# rodilla. La cámara, arriba y de frente: la coronilla.
	_beat("antena")
	_fplay(frig, "fus_antena", false, 1.25)
	shot.cut(at.call(0.78, 0.12, 0.42), at.call(0.98, 0.2, 0.3), 0.95 / _fus_tempo,
		func() -> Vector3: return (eye_fn.call() as Vector3) + Vector3(0, 0.04, 0), 46.0, 50.0)
	if await _ts(t_antena + 0.23):
		return
	VitzoFusion.antenna_tear(fx, _fused, 0.07)
	var lens := KillGore.splatter(fx, 0.5, Vector2(0.52, 0.2))  # salpica el lente y se va
	if lens != null:
		var twl := lens.create_tween()
		twl.tween_interval(0.5)
		twl.tween_property(lens, "modulate:a", 0.0, 0.8)
		twl.tween_callback(lens.queue_free)
	KillGore.screech(fx, 0.0)
	_impact(0.8, "sfx/kill_golpe_seco", 1.5)
	VitzoFusion.stage_to(_fused, "green", 0.93, 0.6)
	shot.kick = 0.014
	if await _ts(t_antena + 0.68):
		return
	fx._snd("sfx/caida_cuerpo", -2.0, 1.2)  # la rodilla en el piso
	shot.kick = 0.006
	if await _ts(t_grito):
		return
	# Ya no puede: cae de rodillas, el pecho en arco, y GRITA con su propia voz, que se va rompiendo hasta ser la de
	# Vitzo. Recién ahí se rinde: lo último humano se le va de la piel, la boca se le cierra en la sonrisa y los brazos
	# le caen muertos. La cámara sube del piso (de costado, el cuerpo entero) a su cara.
	_beat("grito_agente")
	_fplay(frig, "fus_grito", false, g_speed)
	fx._fx_goal = 0.4
	shot.hand = 0.007
	shot.cut(at.call(0.42, 1.7, -0.95), at.call(0.5, 0.12, -0.05), g_len, face_fn, 52.0, 42.0)
	if await _ts(t_grito + 0.12 / g_speed):
		return
	fx._snd("sfx/caida_cuerpo", -3.0, 0.9)  # la otra rodilla
	if await _ts(t_grito + 0.26 / g_speed):
		return
	fx._snd(scream_slot, 3.0)
	fx.last_info["fusion_grito"] = scream_path
	fx.last_info["fusion_grito_s"] = fx._clock
	KillGore.duck_music(fx, scream_len)
	KillGore.slam(fx, 0.7)
	Controls.vibrate(1.0, 1.0, minf(scream_len, 2.5))
	VitzoFusion.stage_to(_fused, "open", 1.0, 0.1)
	VitzoFusion.stage_to(_fused, "green", 1.0, scream_len * 0.9)
	VitzoFusion.stage_to(_fused, "hands", 1.0, scream_len * 0.5)
	VitzoFusion.set_shake(_fused, 0.06)
	shot.kick = 0.012
	fx._red = 0.3
	if await _ts(t_grito + 0.26 / g_speed + scream_len * 0.62):
		return
	_glitch_burst(3)  # la voz ya es de máquina
	if await _ts(t_grito + 0.26 / g_speed + scream_len - 0.3):
		return
	VitzoFusion.stage_to(_fused, "open", 0.0, 0.3)
	VitzoFusion.set_shake(_fused, 0.0)
	fx._snd("sfx/estatica_rafaga_03", -3.0)
	fx._red = 0.08
	shot.hand = 0.003
	if await _ts(t_rigido):
		return
	# La fusión se completa: se pone de pie en tres tirones (como colgado de hilos), firme. De costado, cuerpo entero.
	_beat("rigido")
	_fplay(frig, "fus_rigido", false, 1.3)
	fx._fx_goal = 0.2
	shot.cut(at.call(0.45, 2.4, -0.7), at.call(0.42, 2.2, -0.65), 1.4 / _fus_tempo,
		func() -> Vector3: return (eye_fn.call() as Vector3) - Vector3(0, 0.36, 0), 57.0, 55.0)
	for i in 3:
		if await _ts(t_rigido + float([0.17, 0.56, 0.9][i])):
			return
		fx._snd("sfx/kill_plastico_quiebra", -6.0, 0.7 + 0.12 * i)
		KillGore.bone(fx, 0.3)
		shot.kick = 0.004
	if await _ts(t_rigido + 1.33):
		return
	# La cabeza se le ladea de un tirón: corte a su cara.
	KillGore.bone(fx, 0.6)
	fx._snd("sfx/ww_popup", -6.0, 0.5)
	VitzoFusion.set_twitch(_fused, true)
	shot.cut(at.call(0.68, 0.14, -0.02), at.call(0.56, 0.1, -0.02), (t_corte - t_rigido - 1.33) / _fus_tempo, face_fn, 40.0, 37.0)
	if await _ts(t_corte - 0.1):
		return
	_glitch_burst(2)  # glitch y desgarro de la imagen antes del corte
	fx._fx_k = 1.0
	if await _ts(t_corte):
		return

	# ================= Corte seco a la escena 2 =================
	_beat("corte")
	_fus_on = false  # desde aquí, segundos de verdad (la sala)
	_flash(Color(0, 0, 0, 1), 0.12)
	fx._snd("sfx/estatica_rafaga_01", -4.0)
	fx._stop_audio(0.05)
	_clear_overlays()
	fx._fx_goal = 0.15
	fx._red = 0.0
	if fx._stage != null:
		for c in fx._stage.get_children():
			if c is KillProps.Follow:
				(c as Node3D).visible = false
	each.set_process(false)
	shot.set_process(false)
	each.queue_free()
	shot.queue_free()
	_fused.queue_free()
	_fused = VitzoFusion.build(fx, agent, false)
	VitzoFusion.stage(_fused, 1.0, 1.0, 1.0, 1.0)
	VitzoFusion.set_twitch(_fused, true)  # quieto, recitando, con los tirones de cabeza de Vitzo
	var center := VitzoFusion.ops_center(fx)
	_fused.global_position = center
	cam3.fov = 50.0
	_beat("sala")
	var orbit := VitzoFusion.orbit(fx, _fused, cam3, _R - t_corte_r)
	_prop("fusion_sala")
	VitzoFusion.repeat_line(fx, agent)
	fx._shout("SCR_K2_FUSION", 44, Color(0.45, 1.0, 0.55))  # subtítulo del reminder que repite
	fx.last_info["fusion_agente"] = agent
	if await _ts(_R - 0.65):
		return
	_beat("fundido")
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 0)
	fx._top.add_child(fade)
	fade.create_tween().tween_property(fade, "color:a", 1.0, maxf(fx.seconds - Screamers.CUT - fx._spent, 0.05))
	_mark_seen("vitzo_fusion")
	var _o := orbit


## Mechones de pelo que caen de la cabeza del agente (tercera persona de la fusión).
func _hair_fall(n: int) -> void:
	if _fused == null or not is_instance_valid(_fused):
		return
	KillProps.debris(fx, KillProps.count(n), Vector3(0.014, 0.003, 0.035), [Color(0.05, 0.04, 0.035), Color(0.1, 0.08, 0.06), Color(0.06, 0.2, 0.1)],
		VitzoFusion.face_point(_fused, Vector3(randf_range(-0.05, 0.05), 0.11, -0.02)),
		func(_k: int) -> Vector3: return Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5)), 3.0)


## Clip k32 del agente fusionado (tools/anim/clips_kills.py); si falta la biblioteca, uno del GLB que se le parezca.
func _fplay(frig: CharacterRig, clip: String, loop: bool, speed: float, from: float = 0.0) -> void:
	if frig == null or not is_instance_valid(frig):
		return
	if frig.animator != null and frig.animator.player.has_animation("k32/" + clip):
		if _fus_on and clip != "fus_grito":
			speed *= _fus_tempo  # kills2: la fusión a tempo (el grito no: dura lo que la voz)
		frig.play("k32/" + clip, loop, speed)
		if from > 0.0:
			frig.animator.player.seek(from, true)
		fx.last_info["fusion_clip"] = clip
		return
	var alt: Dictionary = {"fus_empuja": "bang_door", "fus_arranca": "bang_door", "fus_grito": "scream", "fus_antena": "scream"}
	frig.play(str(alt.get(clip, "idle")), loop, speed, ["jumpscare_alt", "idle", "stand"])


## Curva por claves [[t, v], …] con suavizado entre claves (la de rigkit.kf de los clips).
static func _kf(t: float, keys: Array) -> float:
	var prev: Array = keys[0]
	if t <= float(prev[0]):
		return float(prev[1])
	for i in range(1, keys.size()):
		var k: Array = keys[i]
		if t <= float(k[0]):
			var u := (t - float(prev[0])) / maxf(float(k[0]) - float(prev[0]), 0.0001)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(float(prev[1]), float(k[1]), u)
		prev = k
	return float(prev[1])


## Distancia libre (hasta `far` m) desde `from` hacia `dir`: paredes, divisores y escritorios del piso (colisiones).
func _free(from: Vector3, dir: Vector3, far: float) -> float:
	var p := _p()
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return far
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * far)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return far if hit.is_empty() else from.distance_to(hit["position"] as Vector3)


## Posición de cámara despejada: si entre `look` (lo que mira) y `pos` hay pared o mueble, se queda 18 cm antes.
func _clear_pos(look: Vector3, pos: Vector3) -> Vector3:
	var d := pos - look
	var far := d.length()
	if far < 0.45:
		return pos
	var free := _free(look, d / far, far + 0.18)
	return pos if free >= far + 0.17 else look + d / far * maxf(free - 0.18, 0.4)


## La silla sale RODANDO (v0.3.2d: nada se esconde ni desaparece): las piezas que _clear_seat escondió vuelven a verse
## y ruedan juntas `by` (m, mundo) girando `yaw` rad en t s, con su base de ruedas. Screamers._cleanup las devuelve a
## su sitio. false si no había silla cerca.
func _chair_roll(by: Vector3, yaw: float, t: float) -> bool:
	var ch := _chair_parts()
	if ch.is_empty():
		return false
	var parts: Array = ch["parts"]
	var start: Array = ch["start"]
	var pivot: Vector3 = ch["pivot"]
	var tw := _tw().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(u: float) -> void:
		var xf := Transform3D(Basis(Vector3.UP, yaw * u), pivot + by * u) * Transform3D(Basis.IDENTITY, -pivot)
		for i in parts.size():
			if is_instance_valid(parts[i]):
				(parts[i] as Node3D).global_transform = xf * (start[i] as Transform3D), 0.0, 1.0, maxf(t, 0.05))
	fx._snd("sfx/kill_silla_giro", -3.0, 1.1)
	_prop("silla")
	return true


## La silla se VUELCA hacia atrás contigo (gira sobre el borde trasero de su base, acelerando, y rebota al caer) en t s
## y además se va `slide` m hacia atrás. false si no había silla cerca.
func _chair_tip(t: float, slide: float = 0.0) -> bool:
	var ch := _chair_parts()
	if ch.is_empty() or _p() == null:
		return false
	var parts: Array = ch["parts"]
	var start: Array = ch["start"]
	var back := _p().global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else Vector3.BACK
	var pivot: Vector3 = (ch["pivot"] as Vector3) + back * 0.26
	pivot.y = fx._floor_y()
	var axis := Vector3.UP.cross(back).normalized()
	var tw := _tw()
	tw.tween_method(func(u: float) -> void:
		var xf := Transform3D(Basis(axis, deg_to_rad(86.0) * u), pivot + back * (slide * u)) * Transform3D(Basis.IDENTITY, -pivot)
		for i in parts.size():
			if is_instance_valid(parts[i]):
				(parts[i] as Node3D).global_transform = xf * (start[i] as Transform3D), 0.0, 1.0, maxf(t, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(u: float) -> void:
		var xf := Transform3D(Basis(axis, deg_to_rad(86.0 - 7.0 * sin(u * PI))), pivot + back * slide) * Transform3D(Basis.IDENTITY, -pivot)
		for i in parts.size():
			if is_instance_valid(parts[i]):
				(parts[i] as Node3D).global_transform = xf * (start[i] as Transform3D), 0.0, 1.0, 0.16)
	_prop("silla")
	return true


## Las piezas de tu silla (las que _clear_seat escondió, que vuelven a verse, y su base de ruedas), su sitio de partida
## y el punto del piso bajo ella. {} si no hay silla. Screamers._cleanup las devuelve a su sitio.
func _chair_parts() -> Dictionary:
	var parts: Array[Node3D] = []
	for n in fx._hidden.duplicate():
		if is_instance_valid(n) and n is MeshInstance3D and (str(n.name).begins_with("Silla") or str(n.name).begins_with("Respaldo")):
			parts.append(n)
	if parts.is_empty():
		return {}
	var par := parts[0].get_parent()
	var base := par.get_node_or_null("Base") as Node3D if par != null else null
	if base != null and not parts.has(base) and base.global_position.distance_to(parts[0].global_position) < 0.9:
		parts.append(base)
	var pivot := Vector3.ZERO
	for n in parts:
		pivot += n.global_position
	pivot /= float(parts.size())
	pivot.y = 0.0
	var start: Array[Transform3D] = []
	for n in parts:
		n.visible = true
		fx._hidden.erase(n)
		if not fx._xf_back.has(n):
			fx._xf_back[n] = n.transform
		start.append(n.global_transform)
	return {"parts": parts, "start": start, "pivot": pivot}


## Sus recordatorios revientan alrededor DESPUÉS del golpe (v0.3.2d: ya no hay pared de ventanas antes del salto):
## en los bordes de la vista, una tras otra en medio segundo; el centro (su pantalla-cara) queda libre.
func _popups_burst() -> void:
	var spots: Array[Vector2] = [Vector2(-0.39, -0.39), Vector2(0.39, -0.39), Vector2(-0.42, -0.14), Vector2(0.42, -0.14), Vector2(-0.19, -0.43),
		Vector2(0.2, -0.43), Vector2(-0.42, 0.1), Vector2(0.42, 0.1), Vector2(-0.4, 0.33), Vector2(0.4, 0.33)]
	var n := spots.size() if not KillProps.light_mode() else 6
	var vp := fx.get_viewport().get_visible_rect().size
	var k_size := 0.6 * vp.x / 1280.0  # una quinta parte del ancho de la vista cada una
	var me: WeakRef = weakref(fx)
	for i in n:
		var w := fx._window(KillProps.t("SCR_K_REMINDER_TITLE", "Recordatorio · Vitzo"), KillProps.t("SCR_K_REMINDER_BODY", "Confirma el recordatorio. Confírmalo. CONFÍRMALO."),
			Color(0.2, 0.85, 0.5), 400, 150)
		w.name = "Popup%d" % i
		var c: Vector2 = spots[i] * vp + Vector2(randf_range(-18.0, 18.0), randf_range(-12.0, 12.0))
		w.offset_left += c.x
		w.offset_right += c.x
		w.offset_top += c.y
		w.offset_bottom += c.y
		w.rotation = randf_range(-0.07, 0.07)
		w.scale = Vector2.ONE * 0.1
		w.visible = false
		var wr: WeakRef = weakref(w)
		fx.get_tree().create_timer(0.04 + 0.055 * i, true).timeout.connect(func() -> void:
			var f0: Screamers = me.get_ref()
			var pw: Panel = wr.get_ref()
			if f0 == null or f0._done or pw == null:
				return
			pw.visible = true
			pw.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(pw, "scale", Vector2.ONE * k_size, 0.09)
			if i % 2 == 0:
				f0._snd("sfx/ww_popup", -5.0, 0.9 + 0.05 * (i % 5)))
	_prop("popups")


## Las ventanas de recordatorio se van (rasgadas hacia los bordes) al pasar a la tercera persona.
func _popups_clear() -> void:
	for c in fx._root.get_children():
		if c is Panel and str(c.name).begins_with("Popup"):
			(c as Panel).queue_free()


## Espera hasta u; con la fusión ya vista, desde los 3 s [Espacio]/[Enter] salta al final (true = cortar aquí).
func _at_skip(u: float) -> bool:
	return await _until_skip(_t0 + _map(u))


## Como _at_skip, pero en segundos desde el agarre (la fusión va por segundos: sus etapas duran lo que sus clips).
func _ts(sec: float) -> bool:
	return await _until_skip(_t0 + _fus_map(sec))


func _until_skip(target: float) -> bool:
	# v0.3.2-final: [Esc] → «Salir al menú» en plena fusión borra el mundo con la coreografía a medias. Sin estas dos
	# guardas la corrutina seguía sobre el screamer ya liberado: errores de script en cada etapa y, a veces, un cuelgue
	# del motor (signal 11 en fx._snd). Si el screamer ya no existe o salió del árbol, se corta aquí.
	while is_instance_valid(fx) and fx._clock < target - 0.004 and not fx._done and fx.is_inside_tree():
		if bool(fx.last_info.get("fusion_saltable", false)) and fx._clock >= FUSION_SKIP_AFTER and _skip_pressed():
			_skip = true
			fx.last_info["fusion_saltada"] = fx._clock
			_mark_seen("vitzo_fusion")
			fx._spent = fx._clock
			fx.seconds = fx._clock + Screamers.CUT + 0.05
			return true
		await fx.get_tree().process_frame
	if not is_instance_valid(fx) or not fx.is_inside_tree():
		return true
	fx._spent = maxf(fx._spent, target)
	return fx._done


func _skip_pressed() -> bool:
	for a in ["ui_accept", "interact", "respawn"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return bool(fx.last_info.get("fusion_forzar_salto", false))


static func _seen(id: String) -> bool:
	var v: Variant = Loc.get_setting("kills_vistas", {})
	return v is Dictionary and (v as Dictionary).has(id)


static func _mark_seen(id: String) -> void:
	var v: Variant = Loc.get_setting("kills_vistas", {})
	var d: Dictionary = (v as Dictionary).duplicate() if v is Dictionary else {}
	if not d.has(id):
		d[id] = true
		Loc.set_setting("kills_vistas", d)


## Ráfaga de glitch: n destellos verdes y la imagen desgarrada (ScreenFx al máximo) a saltos.
func _glitch_burst(n: int) -> void:
	var me: WeakRef = weakref(self)
	for i in n:
		fx.get_tree().create_timer(0.06 * (i + 1), true).timeout.connect(func() -> void:
			var km: KillMoves = me.get_ref()
			if km != null and is_instance_valid(km.fx) and not km.fx._done:
				km._flash(Color(0.2, 1.0, 0.45, 0.3), 0.05)
				km.fx._fx_k = 1.0
				km.fx._snd("sfx/estatica_rafaga_0%d" % (i % 4 + 1), -6.0))


## El verde entra por los bordes de la vista (la piel de Vitzo te cubre) con desgarros de glitch.
func _green_creep(t: float) -> void:
	if fx._top == null:
		return
	var g := ColorRect.new()
	g.name = "VerdeFusion"
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.0, 0.8));
	float band = step(0.5, fract(UV.y * 40.0 + TIME * 7.0)) * 0.15;
	float a = smoothstep(0.78 - k * 0.42, 0.9 - k * 0.42, r + band * k);
	COLOR = vec4(0.12, 0.55, 0.22, a * 0.7);
}
"""
	sm.shader = sh
	g.material = sm
	fx._top.add_child(g)
	g.create_tween().tween_method(func(v: float) -> void: sm.set_shader_parameter("k", v), 0.0, 1.0, maxf(t, 0.05))


## Quita lo 2D de la escena 1 (popups, verde, sangre) al cortar a la escena 2.
func _clear_overlays() -> void:
	for c in fx._root.get_children():
		if c != fx._bg and c is Control:
			(c as Control).visible = false
	for c in fx._top.get_children():
		if c != fx._fx and c is Control and str(c.name) != "PistaSaltar":
			(c as Control).queue_free()


## WMM: te agarra la cabeza y te jala DENTRO de la pantalla (la vista se hunde en píxeles); lo último que ves es
## una ventana de correo que se escribe sola: «Para: Vitzo…».
func _k_vitzo_pantalla_correo() -> void:
	var m := _m()
	_vitzo_arms()
	_grab()
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_lock(VITZO_GRAB, 12.0, true, Vector3.ZERO)
	_vic_plant(fx._floor_y() + 0.75, 0.3, 0.3, 0.016)  # te aferras al escritorio: te quiere meter en la pantalla
	_beat("agarre")
	fx._snd("sfx/vitzo_arrastre_loop", 0.0)
	# Carga (se echa atrás hacia su pantalla) y te jala.
	if await _hit(0.1, 0.16, "", 0.1):
		return
	_beat("jala")
	_impact(0.8, "sfx/kill_golpe_seco", 1.2)
	_desk_jolt(0.8, true)
	_vic("manotea")  # se te sueltan las manos
	_head(Vector3(0, -0.06, -0.6), _s(0.28), Tween.TRANS_EXPO, Tween.EASE_IN)
	_lock_to(L(0, 0, 0.22), _s(0.2))
	fx._fov_goal = 30.0
	fx._fx_goal = 1.0
	if await _at(0.3):
		return
	_beat("adentro")
	fx._snd("sfx/monitor_rompe", 3.0, 0.7)
	_flash(Color(0.3, 1.0, 0.55, 0.6), 0.2)
	if await _at(0.36):
		return
	_vitzo_q2(0.36)
	_scream(false)
	_vic("munecas", 0.014)
	if await _at(0.58):
		return
	_beat("correo")
	_email_window()
	_prop("correo")
	if await _at(0.9):
		return
	_final(VITZO_FINAL)


## Ventana de correo 2D que se escribe sola (el final del WMM).
func _email_window() -> void:
	var w := fx._window(KillProps.t("SCR_K_MAIL_NEW", "Ezlaki Mail — Correo nuevo"), "", Color(0.2, 0.85, 0.5), 1100, 620)
	w.name = "CorreoVitzo"
	var hdr := Label.new()
	hdr.text = KillProps.t("SCR_K_MAIL_HDR", "De: {agente}\nPara: Vitzo\nAsunto: RE: RE: RE: Status del WMM").replace("{agente}", GameState.agent)
	hdr.position = Vector2(28, 60)
	hdr.add_theme_font_size_override("font_size", 34)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.9, 0.88))
	w.add_child(hdr)
	var body := Label.new()
	body.position = Vector2(28, 200)
	body.size = Vector2(1040, 380)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 56)
	body.add_theme_color_override("font_color", Color(1.0, 0.3, 0.28))
	w.add_child(body)
	var full := tr(str(fx.row.get("frase_texto", "SCR_Q2_CORREO")))
	var tw := body.create_tween()
	tw.tween_method(func(u: float) -> void: body.text = full.substr(0, int(round(u * full.length()))), 0.0, 1.0, _s(0.25))
	fx._snd("sfx/ezlak_escribiendo", 0.0)


## POD (v0.3.2d: sin segundo aviso; el divisor y la silueta pasan a la ACCIÓN, después del salto): Vitzo ya te saltó
## a la cara desde tu escritorio (intro zarpazo). Te toma la cabeza, te arranca de la silla por encima de tu
## escritorio y te estrella el cuello contra el canto del divisor del pod; se corta la luz y, del otro lado, queda su
## silueta a contraluz de los monitores del pod de enfrente, la cabeza-pantalla ladeándose a tirones; se enciende
## su cara y te grita.
func _k_vitzo_divisor() -> void:
	var m := _m()
	_vitzo_arms()
	_grab()
	_hands(L(-0.21, -0.02, 0.1), L(0.21, -0.02, 0.1), 1.0, 14.0)
	_grip("garra", "garra")
	_lock(VITZO_GRAB, 12.0, true, Vector3.ZERO)
	_vic("munecas", 0.014)
	_beat("agarre")
	var pod := _pod_divider()
	if await _at(0.07):
		return
	# Te arranca de la silla: la vista sube y se va hacia adelante sobre tu escritorio; él retrocede sobre el divisor.
	_beat("arrastra")
	_windup(_s(0.03))
	_wind(_s(0.06), "", 0.08)
	_chair_away(0.6)  # la silla sale rodando: te arrancó de ella
	_desk_jolt(0.7)
	fx._snd("sfx/vitzo_arrastre_loop", 2.0, 1.3)
	fx._snd("sfx/kill_silla_giro", 0.0, 1.5)
	_head(Vector3(0, 0.12, -0.5), _s(0.13), Tween.TRANS_EXPO, Tween.EASE_IN)
	_pitch(-0.35, _s(0.13), Tween.TRANS_QUAD, Tween.EASE_IN)
	_cam("cam_roll", -0.16, _s(0.1))
	_lock_to(L(0, 0.1, 0.62), _s(0.13), Tween.TRANS_QUAD, Tween.EASE_OUT)
	if await _at(0.2):
		return
	# El canto del divisor en tu cuello: golpe seco, crujido; se corta la luz del piso.
	_beat("divisor")
	_impact(1.0, "sfx/kill_golpe_seco", 0.8)
	KillGore.bone(fx, 0.9)
	fx._snd("sfx/kill_ahogo", 2.0, 1.1)
	fx._snd("sfx/kill_teclas", 0.0, 1.2)
	_pod_rock(pod)
	_vic("cuello", 0.02)  # las manos al cuello
	_cam("cam_pitch", 0.22, 0.05, Tween.TRANS_EXPO, Tween.EASE_OUT).chain().tween_property(fx, "cam_pitch", 0.06, 0.2)
	_cam("cam_roll", 0.0, _s(0.06))
	_pod_dark(true)
	if await _at(0.24):
		return
	# Silueta: del otro lado del divisor, a contraluz; la cabeza se ladea a saltos (stop-motion).
	_beat("silueta")
	fx._snd("sfx/parpadeo", -2.0)
	_lock(L(0, 0.06, 0.6), 30.0, true, Vector3.ZERO)
	fx._shake_goal = 0.0
	if fx._rig != null and is_instance_valid(fx._rig):
		var rig := fx._rig
		var twh := _tw()
		for i in 3:
			twh.tween_callback(func() -> void:
				if is_instance_valid(rig):
					rig.head_tilt = 0.2 * float(i + 1)
				fx._snd("sfx/kill_teclas", -12.0, 2.2))
			twh.tween_interval(_s(0.035))
	if await _at(GRITO_U["vitzo_divisor"]):
		return
	# Se enciende su pantalla-cara y te jala sobre el divisor hasta ella.
	_beat("salta")
	_pod_dark(false)
	_impact(0.9, "sfx/kill_golpe_seco", 1.2)
	_head(Vector3(0, 0.16, -0.62), _s(0.1), Tween.TRANS_EXPO, Tween.EASE_OUT)
	_pitch(-0.1, _s(0.1))
	if fx._rig != null and is_instance_valid(fx._rig):
		_tw().tween_property(fx._rig, "head_tilt", 0.0, _s(0.06))
	_vitzo_q2(0.45)
	_scream(false)
	_vic("munecas", 0.01)
	if await _at(0.84):
		return
	_final(VITZO_FINAL)


## El divisor del pod (delante de ti, tras tus monitores) y, del otro lado, los monitores encendidos del pod de
## enfrente con una luz fría: el contraluz de la silueta. Devuelve el nodo del divisor.
func _pod_divider() -> Node3D:
	var e := fx._eye()
	var f := fx._dir(0.0)
	var top_y := e.y - 0.14
	var div_root := Node3D.new()
	fx._stage.add_child(div_root)
	KillProps.divider(div_root)
	div_root.global_position = Vector3(e.x, top_y - 0.31, e.z) + f * 1.0
	div_root.look_at(Vector3(e.x, div_root.global_position.y, e.z), Vector3.UP)
	_prop("divisor")
	var back := Node3D.new()
	back.name = "PodEnfrente"
	fx._stage.add_child(back)
	back.global_position = Vector3(e.x, top_y + 0.3, e.z) + f * 2.1
	back.look_at(Vector3(e.x, back.global_position.y, e.z), Vector3.UP)
	for sx in [-0.62, 0.0, 0.62]:
		KillProps.box(back, Vector3(0.6, 0.4, 0.03), Color(0.03, 0.03, 0.04), Vector3(sx, 0.0, 0.0))
		KillProps.box(back, Vector3(0.54, 0.33, 0.01), Color(0.55, 0.75, 0.95), Vector3(sx, 0.01, -0.02), 1.8)  # -Z mira hacia ti
	var rim := OmniLight3D.new()
	rim.name = "ContraluzDivisor"
	rim.light_color = Color(0.7, 0.86, 1.0)
	rim.light_energy = 0.0
	rim.omni_range = 1.1
	rim.shadow_enabled = false
	rim.set_meta("no_mood", true)
	fx._stage.add_child(rim)
	rim.global_position = Vector3(e.x, top_y + 0.3, e.z) + f * 1.6
	_prop("contraluz")
	# Lo que tape la línea entre tus ojos y el divisor (tus monitores, su brazo) se esconde: te arrastra por ahí.
	fx._clear_line([div_root.global_position + Vector3(0, 0.31, 0), back.global_position], 0.5)
	return div_root


## El divisor se sacude con el golpe (se inclina hacia atrás y vuelve, dos rebotes).
func _pod_rock(pod: Node3D) -> void:
	if pod == null or not is_instance_valid(pod):
		return
	var r0 := pod.rotation
	var tw := pod.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pod, "rotation:x", r0.x - 0.16, 0.05)
	tw.tween_property(pod, "rotation:x", r0.x + 0.06, 0.12)
	tw.tween_property(pod, "rotation:x", r0.x - 0.025, 0.12)
	tw.tween_property(pod, "rotation:x", r0.x, 0.14)


## Se corta la luz del piso y la propia de Vitzo (queda la silueta a contraluz) o vuelven.
func _pod_dark(on: bool) -> void:
	var m := fx._m
	if m != null and is_instance_valid(m):
		for c in m.get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).light_energy = 0.0 if on else float((Screamers.LIGHTS.get("vitzo", [Color.WHITE, 2.0]) as Array)[1])
	if fx._face_light != null and is_instance_valid(fx._face_light):
		fx._face_light.visible = not on
	for c in fx._stage.find_children("ContraluzDivisor", "OmniLight3D", true, false):
		(c as OmniLight3D).light_energy = 3.2 if on else 0.8
	if on:
		if FloorBase.active != null:
			for n in FloorBase.active.find_children("*", "Light3D", true, false):
				var li := n as Light3D
				if li.visible and li.light_energy > 0.0 and not li.has_meta("no_mood"):
					fx._lights_off.append([li, li.light_energy])
					li.light_energy *= 0.1
		fx.gfx_dark(0.1)
	else:
		fx.gfx_dark(1.0, 0.0)
		for pair in fx._lights_off:
			var l := pair[0] as Light3D
			if is_instance_valid(l):
				l.light_energy = lerpf(l.light_energy, float(pair[1]), 0.5)

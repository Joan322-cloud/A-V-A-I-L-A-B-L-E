class_name Screamers
extends CanvasLayer
## Screamers (v0.3, PLAN §8.1; rehechos en v0.3.1 Q2, F1-F3/F8/F11/B2/B8): toda muerte que causa un personaje pasa
## por aquí antes de "Usuario desconectado". La muerte por Fatiga/colapso NO tiene screamer (DeathAnimations).
## Contrato (P1, C6 de v0.3.1 — el flujo no cambia):
##   Screamers.play(killer, cause, detail)  — corrutina: muestra el screamer y al terminar emite
##                                            EventBus.screamer_finished(cause). Se puede hacer `await`.
##   Screamers.duration(killer, cause)      — duración en segundos (data/screamers.json, campo "duracion").
##   Screamers.stop_all()                   — corta cualquier screamer en curso (respawn, menú).
## v0.3.1 (Joan): cada screamer dura 3-4 s (dato por fila, fácil de afinar) y tiene tres tiempos:
##   1. INTRO (fila "intro"; "variante" queda como nombre heredado): cómo llega — corre hacia ti, está detrás, sale
##      del monitor arrastrándose (Vitzo), salta la mesa (Haime), las luces se apagan en fila (despido)…;
##   2. AGARRE (t_agarre, fracción de la duración): te agarra con los dos brazos (IK: las manos a los lados de la
##      cámara, dedos en garra), la cámara es tirada hacia su cara, tiembla y se cierra (FOV), y GRITA la frase de la
##      causa (fila "frase" = slot voces/<slug>/scr_grito_<id>, tres tomas gritadas; "frase_texto" = el texto en
##      pantalla). La cara se deforma progresivamente (fila "deform" = curva [[t, k], …] sobre la duración; ScreamRig +
##      assets/shaders/cara_deforme.gdshader: mandíbula imposible, cráneo estirado, ojos negros con pupila roja);
##      la imagen se rompe (aberración cromática, desgarro, viñeta roja; ScreenFx);
##   3. FINAL (fila "final"): embestida contra la cámara (por defecto), la cabina de DJ que Rasec te estrella en la
##      cara ("cabina"), la mordida del perro ("mordida"); corte a negro.
## Shero sale SIEMPRE calvo. Durante el screamer se esconde toda la UI (la PC acercada tapaba al modelo: la
## "pantalla roja" de Haime que vio Joan era el REC rojo + la PC de la silla de calibración encima del modelo).
## Con "reducir destellos": sin destellos de color, temblor y aberración al 30-40 %. "Avisar antes de screamers":
## tono grave antes (recortado para que el total no pase de 4,85 s). Sin pitidos: un slot que falte no suena.
## Rendimiento: un GLB por screamer (prewarm en segundo plano), un ShaderMaterial por superficie, una OmniLight sin
## sombra, un ColorRect de post-proceso; Screamers.prewarm() también compila los shaders al cargar el piso.

const GROUP := "screamer_fx"
const DATA := "screamers"
const DEFAULT_SECONDS := 3.6
const WARN_SECONDS := 1.0
const GOLPE_LEAD := 0.02  # kills2: s del archivo del golpe que suenan antes de su golpe (nada de crecida)
## v0.3.2 (Joan: «Shero no termina de decir su frase… su screamer debe durar algo más»): cada fila dura lo que
## haga falta para que la frase gritada termine + TAIL_S (data/screamers.json; la prueba v032_kills lo mide con la
## toma más larga ES/EN). Tope de una fila: TOTAL_CAP (antes 4,85 s); las muertes de dos escenas («escena»: true,
## la fusión de Vitzo) llegan a LONG_CAP. Checkpoints espera wait_cap() (la fila + el aviso + margen).
## v0.3.2c: la duración ya no es solo la constante de la fila: seconds_for() mide el archivo de la frase (la toma más
## larga del idioma actual) y, si es más larga que la que conocía la fila (frase_s_max), alarga la muerte lo mismo
## (tomas nuevas del Trainer de 2,2-3,5 s sin tocar el JSON). Por eso el tope sube de 6,0 a 7,5 s.
const TOTAL_CAP := 7.5
## v0.3.2d (Joan: «que dure más la animación donde el agente se resiste a fusionarse… que grite cuando ya no puede
## resistirse y al final se fusione por completo»): la fusión por etapas dura ~22 s (la fila manda; ya vista, se salta).
const LONG_CAP := 24.0
const TAIL_S := 0.3
const CUT := 0.12  # corte a negro final (dentro de la duración)
const FACES_DIR := "res://assets/screamers/"
const MODEL_DIRS: Array[String] = ["res://assets/models/"]
const FX_SHADER := "res://assets/shaders/screamer_fx.gdshader"
## Cara 2D por asesino (destello subliminal y avatar), sin la foto de perfil vieja de Shero.
const FACE_BY_KILLER: Dictionary = {
	"shero": "shero_calvo_grito",
	"rasec": "rasec",
	"vitzo": "res://assets/ui/vitzo_cara.png",
	"rta": "perrito_rta_enojado",
	"trainer": "trainer_grito",
	"haime": "haime",
	"cliente": "shero_calvo_grito",
	"grasa": "grasa",
	"guardia": "guardia_fermin",
}
## Altura objetivo de cada modelo (m). Shero v2 ~2,2 m (PLAN P6).
## kills2 (Joan: «el Perrito RTA un poco más grande, igual de terrorífico»): alto del perro del screamer, en UN sitio.
## 0,72 m: el del perro del mundo ya agrandado ×1,2 (PerritoRTA.HEIGHT_M, del paquete de animación; al integrar puede
## leerse de ahí): el que te persigue y el que te mata miden lo mismo. Antes el del screamer medía 0,70 y el del mundo 0,60.
const RTA_H := 0.72
const HEIGHTS: Dictionary = {"shero": 2.2, "rasec": 1.8, "haime": 1.75, "trainer": 1.78, "perrito_rta": RTA_H, "vitzo": 1.8, "grasa": 2.6, "guardia_fermin": 1.76, "enfermero": 1.75}
## Luz del modelo (color, energía): fría y sucia desde abajo; Haime roja (REC); GRASA fría y baja.
const LIGHTS: Dictionary = {"haime": [Color(1.0, 0.35, 0.3), 2.2], "grasa": [Color(0.62, 0.7, 0.86), 2.6], "guardia_fermin": [Color(0.86, 0.9, 1.0), 1.8], "perrito_rta": [Color(0.8, 0.9, 0.82), 1.2], "vitzo": [Color(0.4, 1.0, 0.55), 2.0]}
## Stinger por asesino (audio_v2) y segundo del golpe dentro del archivo (para que caiga en el agarre).
const STINGERS: Dictionary = {"shero": "screamer_shero", "cliente": "screamer_shero", "rasec": "screamer_rasec", "vitzo": "vitzo_salto",
	"rta": "screamer_rta", "trainer": "screamer_trainer", "haime": "screamer_haime", "grasa": "screamer_grasa", "guardia": "screamer_guardia"}
const STINGER_HIT: Dictionary = {"screamer_shero": 0.9, "screamer_rasec": 0.75, "screamer_vitzo": 0.8, "vitzo_salto": 0.03, "screamer_rta": 0.7,
	"screamer_trainer": 0.46, "screamer_haime": 1.75, "screamer_grasa": 0.45, "screamer_guardia": 0.55}
## Estruendo del salto de Vitzo (v0.3.2d): dB con que se toca, casi silencio antes (s) y retraso respecto del arranque
## del salto (un cuadro). El archivo tiene pico verdadero -0,97 dBTP; a -0,4 dB queda en -1,37 dBTP. Mientras suena
## (todo lo demás está a -30 dB) el limitador de Master vuelve a su techo normal (-1 dBFS) BANG_WINDOW_S segundos, así
## no lo toca: medido en clip, el estruendo queda entero (ni el limitador de efectos ni el de Master lo aplastan).
const BANG_DB := -0.4
const BANG_SILENCE_S := 0.2
const BANG_WINDOW_S := 0.6  # mientras suena solo (lo demás a -30 dB), Master vuelve a su techo normal: no lo limita
const VITZO_FACE_LOCAL := Vector3(0.0, 0.2, 0.0)
## Dónde queda la pantalla-cara de Vitzo al agarrarte (espacio de la vista): entera en cuadro, con los hombros y los
## brazos a la vista (el encuadre del screamer Q2 que prefiere Joan), no un primerísimo plano del borde.
const VITZO_GRAB_FACE := Vector3(0.0, 0.04, -0.66)
const BANG_AFTER_S := 0.02
## Intro por variante heredada (filas viejas sin "intro").
const INTRO_OF: Dictionary = {"rec": "salto_mesa", "monitor": "monitor", "portal": "monitor", "suelo": "suelo", "pizarra": "pizarra",
	"evento": "evento", "pantalla": "pantalla", "cese": "cese", "generico": "frente"}
## Distancia de la cara del asesino a la cámara en el agarre (m).
## kills2 (susto de golpe): intros que no son un aviso sino la escena misma (dónde está el asesino cuando te mata): el
## que te alcanzó corriendo, el salto de Vitzo, el sofá, la mesa del lunch / de QA, el cese, el Perrito desde el piso.
const INTROS_ESCENA: Array = ["alcance", "zarpazo", "dormido", "mesa", "salto_mesa", "cese", "acecho_suelo"]
const GRAB_DIST: Dictionary = {"perrito_rta": 0.6, "vitzo": 0.66, "shero": 0.82}
const FACE_GRAB_M := 0.5  # la cara del asesino a medio metro de tus ojos durante el agarre
const GRAB_DEFAULT := 0.74  # distancia de la RAÍZ del modelo a la cámara: la cara queda a ~0,55 m

var killer: String = ""
var cause: String = ""
var detail: String = ""
var seconds: float = DEFAULT_SECONDS
var row: Dictionary = {}
var _done: bool = false
var _spent: float = 0.0
var _clock: float = 0.0
var _soft: bool = false
var _root: Control = null
var _bg: ColorRect = null
var _top: CanvasLayer = null
var _fx: ColorRect = null
var _stage: Node3D = null
var _player: Player = null
var _hidden: Array[Node3D] = []
var _hidden_ui: Array[CanvasLayer] = []
var _ui_muted := false
var _face_keep := -1.0  # > 0: distancia cara-ojos que se mantiene (agarre 0,5 m, embestida 0,3 m)
var _overhead := false  # tendido (lunch dormido): la cara viene de arriba, no se baja a tus ojos
var _turned: Dictionary = {}  # Node3D -> Basis original (agentes que giraron la cabeza en el evento de Rasec)
var _lights_off: Array = []  # [Light3D, energía] apagadas por el despido
var _music: AudioStreamPlayer = null
var _has_model: bool = false
var _stinger_done: bool = false
var _stinger_due: Array = []  # kills2: [segundo del reloj del screamer, slot, desde (s del archivo), s hasta su golpe]
var _m: Node3D = null  # raíz del asesino en cámara
var _rig: ScreamRig = null
var _t_grab: float = 1.0
var _grabbing: float = 0.0  # 0..1 peso del agarre (sube rápido en el agarre)
var _grab_goal: float = 0.0
var _follow: float = 0.0  # 0..1: la cámara sigue la cara del asesino
var _shake: float = 0.0  # amplitud del temblor de cámara (m)
var _shake_goal: float = 0.0
var _fov_goal: float = -1.0
var _fx_goal: float = 0.0
var _fx_k: float = 0.0
var _red: float = 0.0
var _grab_dist: float = 0.74
var _hand_up: float = 0.0  # Rasec: las manos suben con la cabina
var _curve: Array = []
var _shout_label: Label = null
var _cam_rest_pos: Vector3 = Vector3.ZERO
var _jit: Vector3 = Vector3.ZERO
var _jit_t: float = 0.0
var _audio: Array[AudioStreamPlayer] = []
var _catch_pos: Vector3 = Vector3.INF
var _move_tw: Tween = null  # el único tween que mueve al asesino (uno nuevo mata al anterior)
var _take_path: String = ""  # v0.3.2: la toma de la frase se elige al empezar (KillMoves reparte el tiempo con su largo)
var _take_len: float = 0.0
## v0.3.1 (muertes propias, KillMoves): cada muerte tiene su agarre y su acción. Estos campos los maneja
## fx/kill_moves.gd y _process los aplica cada fotograma:
##   hand_l / hand_r      objetivo de cada mano en el espacio de la cámara (x derecha, y arriba, z = -adelante);
##                        Vector3.INF = esa mano no agarra (el brazo sigue la animación). Se suavizan (hand_speed).
##   hand_claw            1 garra · 0 mano plana (tapa la boca/los ojos) · < 0 dedos estirados
##   lock_on / lock_face  el asesino queda "pegado" a tu vista: su cara en lock_face (espacio de la vista, sin el
##                        temblor) y su cuerpo derecho respecto de la vista girado lock_tilt (grados): así se te sube
##                        encima en el suelo, te mira de cabeza (silla volcada) o se asoma de costado sobre la mesa.
##   cam_off / cam_roll / cam_pitch   desplazamiento, giro y cabeceo de la cámara (además de la cabeza del jugador).
var hand_l: Vector3 = Vector3.INF
var hand_r: Vector3 = Vector3.INF
var hand_claw: float = 1.0
var hand_speed: float = 14.0
## v0.3.2d: hacia dónde mira la palma de cada mano (punto del espacio de la vista; lado de TU vista como hand_l/r).
## palm_auto: si no se da, la palma mira a tu eje (x = 0 a la altura de la mano): la cabeza, el cuello, los hombros
## que agarra. PALM_OFF: esa mano no se orienta (sigue al antebrazo). grip_*: agarre de los dedos (KillHands.GRIPS).
const PALM_OFF := Vector3(0.0, -999.0, 0.0)
var palm_l: Vector3 = Vector3.INF
var palm_r: Vector3 = Vector3.INF
var palm_auto: bool = true
var grip_l: String = ""
var grip_r: String = ""
var _hl_cur: Vector3 = Vector3.INF
var _hr_cur: Vector3 = Vector3.INF
var lock_on: bool = false
var lock_face: Vector3 = Vector3(0, 0, -0.5)
var lock_tilt: Vector3 = Vector3.ZERO
var lock_rate: float = 14.0
var lock_upright: bool = false  # true: de pie respecto del suelo (solo gira en yaw); false: pegado a la vista
var lock_step_hz: float = 0.0  # > 0: el asesino se mueve a saltos (Vitzo robótico: stop-motion)
var lock_add: Vector3 = Vector3.ZERO  # v0.3.2e: carga y rebote de los golpes (m, espacio de la vista), SIN suavizar
var _lock_add_w: Vector3 = Vector3.ZERO
var lock_min_front: float = 0.0  # v0.3.2e: mientras grita, su cara (si está delante) no más cerca que esto (m); 0 = sin piso
var lock_scale: float = 1.0  # escala del asesino pegado a la vista (Vitzo se achica al hundirse en ti)
var _lock_acc: float = 0.0
var cam_off: Vector3 = Vector3.ZERO
var cam_roll: float = 0.0
var cam_pitch: float = 0.0
var glance: Vector2 = Vector2.ZERO  # vistazo (cabeceo, giro) sobre la vista: miras atrás/abajo sin mover al asesino
var _xf_back: Dictionary = {}  # nodo -> Transform3D: se devuelven en _cleanup (tu cuerpo, que una muerte movió)
var kill_id: String = ""
var kill_hands_early: bool = false  # el salto de Vitzo: sus manos ya van a hand_l/hand_r en la intro (antes de kill_id)
## Manos del asesino en puntos del MUNDO (v0.3.2d): () → [su izquierda, su derecha] (Vector3; INF = esa mano libre).
## Manda sobre hand_l/hand_r mientras sea válido: las manos plantadas en la mesa mientras se encoge para saltar, en el
## borde de un monitor, en un hueso de otro modelo. release_hands_world() las suelta sin tirón.
var hands_world: Callable = Callable()
var hands_world_grip: String = "plana"
var _bridge: Array = []  # [capa de la UI, [hijos escondidos]]: la película de la pantalla que sigue un momento (_film_bridge)
var kill_obj: RefCounted = null  # la KillMoves en curso (vive hasta que se libera el screamer: cuerdas y tweens la usan)
var _face_light: OmniLight3D = null
var _head_base: Vector3 = Vector3.INF  # posición de la cabeza del jugador al empezar (para devolverla)
static var _prewarmed: Dictionary = {}
static var last_info: Dictionary = {}  # última ejecución (pruebas): {cause, killer, intro, final, frase, deform_max, grab, duracion}


# --- datos ----------------------------------------------------------------------------------------

## Fila de screamers.json para (asesino, causa): "causa@asesino" > "causa" > por_asesino.
## v0.3.1: el lunch excedido de quien duerme en un sofá (2.ª siesta, F14) usa la fila "lunch_dormido".
static func row_for(p_killer: String, p_cause: String) -> Dictionary:
	var d: Dictionary = DataLoader.dict(DATA)
	var causas: Dictionary = d.get("causas", {})
	if p_cause == "lunch_excedido" and p_killer == "shero" and causas.has("lunch_dormido") and _player_lying():
		p_cause = "lunch_dormido"
	var r: Dictionary = {}
	if causas.has(p_cause + "@" + p_killer):
		r = (causas[p_cause + "@" + p_killer] as Dictionary).duplicate()
	elif causas.has(p_cause) and str((causas[p_cause] as Dictionary).get("asesino", p_killer)) in [p_killer, ""]:
		r = (causas[p_cause] as Dictionary).duplicate()
	elif causas.has(p_cause) and not (d.get("por_asesino", {}) as Dictionary).has(p_killer):
		r = (causas[p_cause] as Dictionary).duplicate()
	var base: Dictionary = (d.get("por_asesino", {}) as Dictionary).get(p_killer, {})
	for k in base.keys():
		if not r.has(k):
			r[k] = base[k]
	return r


static var _asleep: bool = false
static var _sleep_hooked: bool = false


## Dormido en un sofá/puff: la muerte despierta al jugador en silencio (SleepSpot) antes del screamer, así que se
## sigue con las señales (dormido hasta player_woke, reaparecer o volver al menú).
static func _hook_sleep() -> void:
	if _sleep_hooked:
		return
	_sleep_hooked = true
	EventBus.player_slept.connect(func(_s: String) -> void: Screamers._asleep = true)
	EventBus.player_woke.connect(func() -> void: Screamers._asleep = false)
	EventBus.respawned.connect(func(_k: String) -> void: Screamers._asleep = false)
	EventBus.returned_to_menu.connect(func() -> void: Screamers._asleep = false)


static func _player_lying() -> bool:
	_hook_sleep()
	return _asleep or SleepSpot.is_player_sleeping()


static func has_row(p_cause: String) -> bool:
	return (DataLoader.dict(DATA).get("causas", {}) as Dictionary).has(p_cause)


## Duración prevista del screamer (fila de screamers.json; si no hay, 3,6 s).
static func duration(p_killer: String, p_cause: String) -> float:
	return seconds_for(row_for(p_killer, p_cause))


static var _slot_len: Dictionary = {}  # "idioma|slot" → s de la toma más larga


## Largo (s) de la toma más larga de una frase gritada en el idioma actual, leído del archivo (se mide una vez).
static func slot_len(slot: String) -> float:
	if slot == "":
		return 0.0
	var key := Loc.language + "|" + slot
	if _slot_len.has(key):
		return float(_slot_len[key])
	var v := 0.0
	var paths: Array[String] = []
	for i in range(1, 4):
		var p := AudioManager.voice_path("%s_%02d" % [slot, i])
		if p != "":
			paths.append(p)
	if paths.is_empty() and AudioManager.voice_path(slot) != "":
		paths.append(AudioManager.voice_path(slot))
	for p in paths:
		var st := load(p) as AudioStream
		if st != null:
			v = maxf(v, st.get_length())
	_slot_len[key] = v
	return v


## Duración real de una fila: la del JSON y, si el archivo de la frase es más largo que lo que la fila conocía
## (frase_s_max) o no cabe después del agarre, lo que haga falta para que termine + TAIL_S. La regla «el screamer dura
## al menos lo que su frase» se cumple leyendo el archivo, no una constante.
static func seconds_for(r: Dictionary) -> float:
	var escena := bool(r.get("escena", false))
	var d0 := float(r.get("duracion", DEFAULT_SECONDS))
	var d := d0
	var slot := str(r.get("frase", ""))
	if slot != "" and not escena:
		var rep := maxi(1, int(r.get("frase_rep", 1)))
		var one := slot_len(slot)
		if one > 0.0:
			var vt := one * rep + REP_GAP * (rep - 1)
			if r.has("frase_s_max"):
				d += maxf(vt - float(r["frase_s_max"]), 0.0)
			d = maxf(d, grab_s(r, d0) + vt + TAIL_S + CUT)
			# kills2: con "accion_s" (acción fija antes del grito; KillMoves.run) la fila dura agarre + acción + frase + cola.
			if float(r.get("accion_s", 0.0)) > 0.0:
				d = grab_s(r, d0) + float(r["accion_s"]) + vt + TAIL_S + CUT
	return clampf(d, 1.0, LONG_CAP if escena else TOTAL_CAP)


## Segundo del agarre de una fila: "t_agarre_s" (absoluto, v0.3.2d: los saltos «sin aviso» de Vitzo caen a ~0,36 s)
## o, si no está, la fracción "t_agarre" de la duración base (como siempre).
static func grab_s(r: Dictionary, d: float) -> float:
	if r.has("t_agarre_s"):
		return clampf(float(r["t_agarre_s"]), 0.05, maxf(d * 0.7, 0.05))
	return d * clampf(float(r.get("t_agarre", 0.3)), 0.08, 0.7)


## Cuánto espera Checkpoints al screamer antes de mostrar la pantalla de muerte: la fila (con su tope), el aviso y
## un margen de 0,4 s.
static func wait_cap(p_killer: String, p_cause: String) -> float:
	var r := row_for(p_killer, p_cause)
	var d := seconds_for(r)
	var warn := WARN_SECONDS if bool(Loc.get_setting("screamer_warn", false)) else 0.0
	return d + warn + 0.4


## Precarga en segundo plano los modelos de los asesinos de un piso (lo llama FloorBase al cargarse) y compila los
## shaders del screamer (cara deforme y post-proceso) para que el primero no dé un tirón.
static func prewarm(slugs: Array) -> void:
	_hook_sleep()
	for s in slugs:
		var path := _model_path(str(s))
		if path != "" and not _prewarmed.has(path):
			_prewarmed[path] = true
			KillGore.request(path)  # solo ResourceLoader en el hilo; lo recoge el hilo principal
	KillGore.prewarm()  # v0.3.2: la capa de impacto y los shaders de sangre/manos (sin tirones a mitad de la muerte)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return
	var fl := FloorBase.active
	if fl != null:
		ScreamRig.prewarm.call_deferred(fl)
	if not _prewarmed.has("fx"):
		_prewarmed["fx"] = true
		var layer := CanvasLayer.new()
		layer.layer = -10
		layer.name = "PrecalentarScreamerFx"
		var r := ColorRect.new()
		r.size = Vector2(2, 2)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.material = _fx_material(0.0, false)
		layer.add_child(r)
		tree.root.add_child.call_deferred(layer)
		tree.create_timer(0.4, true, false, true).timeout.connect(layer.queue_free)


## VoiceDirector (paquete de bugs, rama v0.3.2-bugs) es opcional: esta rama corre sola sin él.
static func voice_director() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("VoiceDirector") if tree != null else null


static func voice_director_stop(why: String) -> void:
	var vd := voice_director()
	if vd != null and vd.has_method("stop_all"):
		vd.call("stop_all", why)


static func _model_path(slug: String) -> String:
	for d in MODEL_DIRS:
		if ResourceLoader.exists(d + slug + ".glb"):
			return d + slug + ".glb"
	return ""


static func _fx_material(k: float, soft: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(FX_SHADER) as Shader
	m.set_shader_parameter("k", k)
	m.set_shader_parameter("soft", 1.0 if soft else 0.0)
	return m


# --- contrato -------------------------------------------------------------------------------------

## Corrutina: reproduce el screamer y emite screamer_finished(cause) al terminar.
static func play(p_killer: String, p_cause: String, p_detail: String = "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		EventBus.screamer_finished.emit(p_cause)
		return
	var fx := Screamers.new()
	fx.killer = p_killer
	fx.cause = p_cause
	fx.detail = p_detail
	fx.row = row_for(p_killer, p_cause)
	fx.seconds = seconds_for(fx.row)
	if Engine.time_scale >= 8.0:
		# Bots a 16x: un fotograma dura ~1 s de juego y Checkpoints corta a los 5 s; el screamer se acorta para
		# terminar solo (a 1x nunca pasa).
		fx.seconds = minf(fx.seconds, 3.0)
	fx.layer = 20
	fx.name = "Screamer"
	fx.add_to_group(GROUP)
	tree.root.add_child(fx)
	await fx._run()
	if is_instance_valid(fx):
		last_info["duracion_real"] = fx._clock  # reloj propio (delta de juego)
	if is_instance_valid(fx) and not fx._done:
		fx._done = true
		fx._cleanup()
		fx.queue_free()
		Screamers.hold_black()
		EventBus.screamer_finished.emit(p_cause)


const HOLD_GROUP := "death_black_hold"


## El bus UI (pings de Ezlaki, clics) queda mudo desde el grito hasta que reapareces o vuelves al menú: nada de
## «ding» encima del screamer ni de «Usuario desconectado».
static func _unmute_ui_on_return() -> void:
	var unmute := func(_a: Variant = null) -> void:
		var ui := AudioServer.get_bus_index("UI")
		if ui >= 0:
			AudioServer.set_bus_mute(ui, false)
	if Checkpoints.dying:
		EventBus.respawned.connect(unmute, CONNECT_ONE_SHOT)
		EventBus.returned_to_menu.connect(unmute, CONNECT_ONE_SHOT)
	else:
		unmute.call()


## Negro entre el final del screamer/colapso y la pantalla "Usuario desconectado". Se desvanece al llegar
## death_shown; se quita al reaparecer o volver al menú (tope 3 s).
static func hold_black() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 19
	layer.name = "NegroHastaPantalla"
	layer.add_to_group(HOLD_GROUP)
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0, 0, 0, 1)
	layer.add_child(r)
	tree.root.add_child(layer)
	var wl: WeakRef = weakref(layer)
	var fade := func(_c: String = "") -> void:
		var l: CanvasLayer = wl.get_ref()
		if l != null and l.is_inside_tree() and l.get_child_count() > 0:
			var tw := l.create_tween()
			tw.tween_property(l.get_child(0), "color", Color(0, 0, 0, 0), 0.35)
			tw.tween_callback(l.queue_free)
	EventBus.death_shown.connect(fade, CONNECT_ONE_SHOT)
	var kill := func(_k: String = "") -> void:
		var l: CanvasLayer = wl.get_ref()
		if l != null:
			l.queue_free()
	EventBus.returned_to_menu.connect(kill, CONNECT_ONE_SHOT)
	EventBus.respawned.connect(kill, CONNECT_ONE_SHOT)
	tree.create_timer(3.0, true).timeout.connect(kill)


static func clear_hold() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(HOLD_GROUP):
		n.queue_free()


## Corta todos los screamers en curso (sin emitir screamer_finished).
static func stop_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		(n as Screamers)._done = true
		(n as Screamers)._cleanup()
		n.queue_free()


func _exit_tree() -> void:
	_cleanup()


func _cleanup() -> void:
	_film_bridge_end()
	KillGore.dip_restore()
	KillGore.master_guard(false, KillGore.GUARD_HOLD_S)
	if has_meta("hitstop"):
		Engine.time_scale = float(get_meta("hitstop"))
		remove_meta("hitstop")
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	_stage = null
	_m = null
	_rig = null
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for l in _hidden_ui:
		if is_instance_valid(l):
			l.visible = true
	_hidden_ui.clear()
	if _ui_muted:
		_ui_muted = false
		_unmute_ui_on_return()
	for n in _turned.keys():
		if is_instance_valid(n):
			(n as Node3D).basis = _turned[n]
	_turned.clear()
	for n in _xf_back.keys():
		if is_instance_valid(n):
			(n as Node3D).transform = _xf_back[n]
	_xf_back.clear()
	if not _lights_off.is_empty():
		gfx_dark(1.0, 0.0)
	for pair in _lights_off:
		var l := pair[0] as Light3D
		if is_instance_valid(l):
			l.light_energy = float(pair[1])
	_lights_off.clear()
	if _music != null and is_instance_valid(_music):
		_music.stop()
	if _top != null and is_instance_valid(_top):
		_top.queue_free()
	_top = null
	if _player != null and is_instance_valid(_player) and _player.camera != null and has_meta("cam_override"):
		_player.camera.make_current()  # la fusión de Vitzo usó su cámara de tercera persona
		remove_meta("cam_override")
	if _player != null and is_instance_valid(_player) and _player.camera != null:
		_player.camera.position = Vector3.ZERO
		_player.camera.rotation.z = 0.0
		_player.camera.rotation.x = 0.0
		_player.camera.rotation.y = 0.0
		if _head_base != Vector3.INF and kill_id != "":
			# Las muertes propias mueven la cabeza (caes al suelo, te levantan del cuello): vuelve a su sitio.
			_player.head.position = _head_base


# --- secuencia ------------------------------------------------------------------------------------

func _run() -> void:
	_soft = bool(Loc.get_setting("flash_reduction", false))
	var warn := bool(Loc.get_setting("screamer_warn", false))
	_player = get_tree().get_first_node_in_group("player") as Player
	if warn:
		AudioManager.play_sting()
		await get_tree().create_timer(WARN_SECONDS, true).timeout
		if _done:
			return
	# v0.3.2 (integración con el paquete de bugs): si existe el autoload VoiceDirector, corta todo diálogo en curso;
	# desde aquí solo habla el asesino (su frase la toca el screamer con su reproductor y el subtítulo sale con el
	# asesino como hablante: _shout → EventBus.subtitle(killer, …), que VoiceDirector deja pasar como SCREAMER).
	voice_director_stop("screamer")
	KillGore.ensure_buses()
	KillGore.master_guard(true, 0.0, float(KillGore.CEIL_BY_KILL.get(str(row.get("kill", "")), KillGore.MASTER_CEIL_SCREAMER)))
	_pick_voice()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bg = _rect(Color(0, 0, 0, 0))
	_make_fx()
	_hide_ui()
	if _player != null:
		_player.set_cinematic(true)
		_cam_rest_pos = _player.camera.position
		_head_base = _player.head.position
		if OS.get_cmdline_user_args().has("--log-screamer"):
			print("[screamer %s] cámara al empezar: fov %.1f · cabeza %s giro %.3f/%.3f · cám %s rot %s" % [cause, _player.camera.fov, str(_player.head.position.snapped(Vector3.ONE * 0.001)), _player.rotation.y, _player.head.rotation.x, str(_player.camera.position.snapped(Vector3.ONE * 0.001)), str(_player.camera.rotation.snapped(Vector3.ONE * 0.001))])
	# El agarre cae donde lo puso la fila (en segundos de su duración base), aunque la frase la haya alargado.
	_t_grab = grab_s(row, minf(seconds, float(row.get("duracion", seconds))))
	_curve = row.get("deform", []) as Array if row.get("deform", []) is Array else []
	_grab_dist = float(row.get("dist_agarre", GRAB_DIST.get(str(row.get("modelo", _default_model())), GRAB_DEFAULT)))
	if _player != null and _player.seated:
		_grab_dist *= 0.72  # sentado: se inclina sobre tu escritorio (si no, quedaba detrás de los monitores)
	var intro := str(row.get("intro", INTRO_OF.get(str(row.get("variante", "")), str(row.get("variante", "carrera")))))
	# Te alcanzó en una persecución: el screamer arranca DONDE ESTABA el cazador (no aparece corriendo de otro lado).
	var lc: Dictionary = Pursuit.last_catch
	if str(lc.get("killer", "")) == killer and Time.get_ticks_msec() - int(lc.get("ms", -99999)) < 2500 and (lc.get("pos", Vector3.INF) as Vector3) != Vector3.INF and not intro in ["cese", "dormido"]:
		intro = str(row.get("intro_alcance", "alcance"))
		_catch_pos = lc["pos"]
	if not has_method("_i_" + intro):
		intro = "carrera"
	# kills2 (Joan: «sustos de golpe»): la intro de la fila ya no se actúa (corría 1-1,8 s con pasos, parpadeos, ventanas
	# y la crecida del golpe: avisaba). Solo quedan las que SON la escena; las demás entran con _i_golpe.
	var intro_fn := intro if intro in INTROS_ESCENA else "golpe"
	last_info = {"cause": cause, "killer": killer, "intro": intro, "final": str(row.get("final", "embestida")), "frase": str(row.get("frase", "")),
		"deform_max": 0.0, "grab": 0.0, "duracion": seconds, "t0": Time.get_ticks_msec(), "f0": Engine.get_process_frames(), "agarre_s": _t_grab,
		"kill": "", "beats": [], "props": [], "gore": [], "frase_path": _take_path, "frase_s": voice_total(),
		"contenido_grafico": "normal" if KillGore.enabled() else "reducido"}
	set_process(true)
	_start_stinger()
	_dbg("intro " + intro)
	# Sin muerte propia (agarre genérico) el grito cae en el agarre: la voz arranca voice_lead() antes.
	# La muerte de alcance (kill_alcance: Vitzo de pie) va cuando te alcanzó en una persecución, se llame como se llame
	# su intro (v0.3.2d: «zarpazo» sirve sentado y de pie).
	var intro_k := "alcance" if _catch_pos != Vector3.INF else intro
	if voice_lead() > 0.02 and not KillMoves.has(KillMoves.kill_for(row, intro_k, _player != null and _player.seated)):
		prestart_voice(_t_grab - voice_lead())
	last_info["intro_fn"] = intro_fn
	await call("_i_" + intro_fn)
	if _done:
		return
	await _wait(_t_grab - _spent)
	if _done:
		return
	kill_id = KillMoves.kill_for(row, intro_k, _player != null and _player.seated)
	last_info["kill"] = kill_id
	if kill_id != "" and KillMoves.has(kill_id):
		_dbg("muerte " + kill_id)
		last_info["muerte_s"] = _clock
		await KillMoves.run(self, kill_id)
		if _done:
			return
		await _cut()
		return
	_dbg("agarre")
	await _grab_and_scream()
	if _done:
		return
	_dbg("final")
	var fin := str(row.get("final", "embestida"))
	if has_method("_f_" + fin):
		await call("_f_" + fin)
	else:
		await _f_embestida()
	if _done:
		return
	await _cut()


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	if not _stinger_due.is_empty() and _clock >= float(_stinger_due[0]) - 0.004:
		# kills2: el golpe del asesino, por el reloj del screamer (el mismo que mueve la imagen): cae en el agarre.
		_snd(str(_stinger_due[1]), 0.0, 1.0, float(_stinger_due[2]))
		last_info["golpe_s"] = minf(float(last_info.get("golpe_s", 99.0)), _clock + float(_stinger_due[3]))
		_stinger_due = []
	if _player == null or not is_instance_valid(_player):
		return
	var cam := _player.camera
	# Deformación por la curva de la fila (si no hay, sube desde el agarre).
	if _rig != null and is_instance_valid(_rig):
		var k := _deform_at(_clock / maxf(seconds, 0.01))
		_rig.deform = maxf(_rig.deform, k) if bool(row.get("deform_monotona", true)) else k
		last_info["deform_max"] = maxf(float(last_info.get("deform_max", 0.0)), _rig.deform)
		_grabbing = move_toward(_grabbing, _grab_goal, delta * 9.0)
		_rig.grab = _grabbing
		last_info["grab"] = maxf(float(last_info.get("grab", 0.0)), _grabbing)
		if hands_world.is_valid():
			var hw: Array = hands_world.call()
			for i in mini(hw.size(), 2):
				var pt: Vector3 = hw[i]
				var on := pt != Vector3.INF
				if i == 0:
					_rig.grab_w_l = move_toward(_rig.grab_w_l, 1.0 if on else 0.0, delta * 8.0)
					if on:
						_rig.grab_l = pt
						_rig.palm_l = pt + Vector3(0, -0.3, 0)  # la palma hacia abajo (apoyada)
						_rig.grip_l = hands_world_grip
				else:
					_rig.grab_w_r = move_toward(_rig.grab_w_r, 1.0 if on else 0.0, delta * 8.0)
					if on:
						_rig.grab_r = pt
						_rig.palm_r = pt + Vector3(0, -0.3, 0)
						_rig.grip_r = hands_world_grip
		elif _grabbing > 0.0 and cam != null and (kill_id != "" or kill_hands_early):
			_hands_step(cam, delta)
		elif _grabbing > 0.0 and cam != null:
			var f := -cam.global_transform.basis.z
			var r := cam.global_transform.basis.x
			var u := cam.global_transform.basis.y
			var spread := 0.21
			# v0.3.2e: con la cara pegada a la vista (agarre genérico), sus manos van a tus HOMBROS: a la altura de tu cabeza
			# los antebrazos de GRASA (gruesos, de abajo hacia la cámara) le tapaban la cara desde los dos segundos.
			var low := -0.2 if lock_on and kill_id == "" else -0.02
			if low < -0.1:
				spread = 0.25
			# Te mira de frente: su brazo izquierdo queda a TU derecha. Antes cada brazo iba al lado contrario y se cruzaban
			# en X (con las manos en tus hombros la X quedaba delante de su boca).
			var sw := -1.0 if _m != null and is_instance_valid(_m) and (-_m.global_transform.basis.z).dot(f) < 0.0 else 1.0
			_rig.grab_l = cam.global_position - r * spread * sw + f * (0.1 if low > -0.1 else 0.04) + u * (low + _hand_up)
			_rig.grab_r = cam.global_position + r * spread * sw + f * (0.1 if low > -0.1 else 0.04) + u * (low + _hand_up)
		_rig.look = 1.0
		_rig.look_at_point = cam.global_position if cam != null else Vector3.ZERO
	if lock_on and _m != null and is_instance_valid(_m) and cam != null:
		_lock_step(delta)
	elif not lock_on:
		_lock_add_w = Vector3.ZERO
	if _face_light != null and is_instance_valid(_face_light) and cam != null:
		_face_light.global_position = cam.global_position - cam.global_transform.basis.z * 0.12 + cam.global_transform.basis.y * 0.1
	# La cara se mantiene a _face_keep m de tus ojos (y a su altura) aunque se incline o estire el cuello: corrige
	# la raíz cuando no hay un movimiento en curso.
	if _face_keep > 0.0 and not lock_on and _m != null and is_instance_valid(_m) and not (_move_tw != null and _move_tw.is_valid() and _move_tw.is_running()):
		var e := _eye()
		var hp := _head_point(_m)
		var d := Vector3(hp.x - e.x, 0.0, hp.z - e.z)
		var k := minf(delta * 10.0, 1.0)
		if _overhead:
			var full := hp - e
			if full.length() > 0.01:
				_m.global_position += (e + full.normalized() * _face_keep - hp) * k
		else:
			if d.length() > 0.01:
				_m.global_position -= d.normalized() * (d.length() - _face_keep) * k
			_m.global_position.y += (e.y - hp.y) * minf(delta * 6.0, 1.0)
	# Cámara: sigue la cara, tiembla y se cierra.
	if _follow > 0.0 and _m != null and is_instance_valid(_m):
		_look_step(_m, clampf(_follow * delta * 14.0, 0.0, 1.0))
	_shake = move_toward(_shake, _shake_goal, delta * 0.4)
	_jit_t -= delta
	if _jit_t <= 0.0:
		_jit_t = 0.033
		_jit = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	if cam != null:
		var a := _shake * (0.35 if _soft else 1.0)
		cam.position = cam.position.lerp(_cam_rest_pos + cam_off + Vector3(_jit.x, _jit.y, 0) * a, minf(delta * 30.0, 1.0))
		cam.rotation.z = lerpf(cam.rotation.z, cam_roll + _jit.z * a * 3.0, minf(delta * 20.0, 1.0))
		cam.rotation.x = lerpf(cam.rotation.x, cam_pitch + glance.x, minf(delta * 20.0, 1.0))
		cam.rotation.y = lerpf(cam.rotation.y, glance.y, minf(delta * 20.0, 1.0))
		if _fov_goal > 0.0:
			cam.fov = lerpf(cam.fov, _fov_goal, minf(delta * 7.0, 1.0))
	_fx_k = move_toward(_fx_k, _fx_goal, delta * 2.5)
	if _fx != null:
		var m := _fx.material as ShaderMaterial
		m.set_shader_parameter("k", _fx_k)
		m.set_shader_parameter("red", _red if not _soft else _red * 0.3)
	if _shout_label != null and is_instance_valid(_shout_label):
		_shout_label.position = _shout_label.get_meta("base", _shout_label.position) + Vector2(_jit.x, _jit.y) * 9.0 * (0.3 if _soft else 1.0) * (0.4 + _fx_k)


func _dbg(msg: String) -> void:
	if OS.get_cmdline_user_args().has("--log-screamer"):
		print("[screamer %s %.2fs/%.2f f%d] %s" % [cause, _clock, _spent, Engine.get_process_frames(), msg])


func _deform_at(tn: float) -> float:
	if _curve.size() < 2:
		var g := _t_grab / maxf(seconds, 0.01)
		_curve = [[0.0, 0.0], [maxf(g - 0.06, 0.0), 0.04], [g + 0.12, 0.4], [0.8, 0.85], [0.95, 1.0]]
	var prev: Array = _curve[0]
	if tn <= float(prev[0]):
		return float(prev[1])
	for i in range(1, _curve.size()):
		var p: Array = _curve[i]
		if tn <= float(p[0]):
			var u := (tn - float(prev[0])) / maxf(float(p[0]) - float(prev[0]), 0.0001)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(float(prev[1]), float(p[1]), u)
		prev = p
	return float(prev[1])


## Stinger del asesino: su golpe cae en el agarre.
func _start_stinger() -> void:
	var slot := str(row.get("stinger", STINGERS.get(killer, "")))
	if slot == "" or not AudioManager.has_slot("sfx/" + slot):
		return
	var hit := float(STINGER_HIT.get(slot, 0.6))
	_stinger_done = true
	if slot == "vitzo_salto":
		# v0.3.2d (Joan: «que suene aún mucho más fuerte y escandaloso… al mismo nivel de potencia de la voz de Vitzo»;
		# «susto sin preparar»): el estruendo (sfx/vitzo_salto v3: sin crecida, el golpe a 30 ms del archivo) cae en el
		# INSTANTE DEL SALTO (jump_s(): un cuadro después de que arranca, no en el agarre). Los 0,2 s anteriores todo lo
		# demás calla (hit_dip: Sala y sus hijos, Ambiente/Música, Auricular, UI a -30 dB) y vuelve 0,45 s después; el
		# estruendo va solo por su bus (ScreamerGolpe → Master, sin el compresor ni el limitador de efectos) a
		# BANG_DB, y durante BANG_WINDOW_S Master vuelve a su techo normal: ningún limitador lo toca.
		var me0: WeakRef = weakref(self)
		var hit_at := jump_s() + BANG_AFTER_S
		get_tree().create_timer(maxf(hit_at - BANG_SILENCE_S - 0.05, 0.0), true).timeout.connect(func() -> void:
			var f2: Screamers = me0.get_ref()
			if f2 != null and not f2._done:
				KillGore.hit_dip(f2, 0.05, BANG_SILENCE_S + 0.45, 0.3))
		get_tree().create_timer(maxf(hit_at - hit, 0.0), true).timeout.connect(func() -> void:
			var f: Screamers = me0.get_ref()
			if f != null and not f._done:
				KillGore.duck_music(f, 1.6)
				KillGore.master_window(f, BANG_WINDOW_S)
				KillGore.gfx("GfxLens", "kick", [1.0, 0.6])
				f._snd("sfx/" + slot, BANG_DB)
				f.last_info["golpe_s"] = f._clock + hit
				f.last_info["vitzo_salto_s"] = f._clock + hit)
		last_info["golpe_previsto_s"] = hit_at
		return
	# kills2 (Joan: «suena una musiquita y tarda… avisándote que morirás»): del archivo solo se oye EL GOLPE. Antes
	# arrancaba `hit` s antes del agarre y su crecida (0,45-1,75 s) anunciaba la muerte; ahora entra GOLPE_LEAD s antes
	# del golpe, en el agarre: lo primero que se oye es el golpe.
	var from_s := maxf(hit - GOLPE_LEAD, 0.0)
	var at := _t_grab - (hit - from_s)
	last_info["golpe_previsto_s"] = maxf(at, 0.0) + (hit - from_s)
	_stinger_due = [maxf(at, 0.0), "sfx/" + slot, from_s, hit - from_s]


## Segundo (del screamer) en que arranca el SALTO de Vitzo: "salto_s" de la fila; si no, 0,1 s antes del agarre.
func jump_s() -> float:
	return clampf(float(row.get("salto_s", _t_grab - 0.1)), 0.0, maxf(_t_grab - 0.06, 0.0))


## Espera hasta el instante _spent + s del screamer, medido con el reloj propio (_clock, el delta de cada
## fotograma): los tirones (cargar el modelo) no alargan el screamer y la duración total es la de la fila.
func _wait(s: float) -> void:
	if s <= 0.0 or _done or not is_inside_tree():
		return
	_spent += s
	while _clock < _spent - 0.004 and not _done and is_inside_tree():
		await get_tree().process_frame


func _left() -> float:
	return maxf(seconds - _spent, 0.0)


## Corte a negro final: estática un instante y negro (ocupa lo que quede de la duración).
func _cut() -> void:
	_dbg("corte")
	_bg.color = Color(0, 0, 0, 1)
	for c in _root.get_children():
		if c != _bg:
			(c as CanvasItem).visible = false
	if _top != null:
		_top.visible = false
	if _stage != null and is_instance_valid(_stage):
		_stage.visible = false
	_snd("sfx/estatica_desconexion", -4.0)
	_stop_audio(0.08)
	await _wait(_left())


# --- tiempos comunes --------------------------------------------------------------------------------

## AGARRE: te toma con los dos brazos, la cámara es tirada hacia su cara y grita la frase.
func _grab_and_scream() -> void:
	if _m != null:
		# La cara entera en cuadro (ojos, boca rajada y mentón) a ~0,5 m; la raíz donde haga falta según se incline.
		if _overhead:
			_face_toward_eye(_m, FACE_GRAB_M, 0.12)  # tendido en el sofá: la cara se te viene encima desde arriba
		else:
			var to_face := clampf(_root_dist_for_face(FACE_GRAB_M), 0.3, maxf(_grab_dist, 0.9))
			_approach(_m, to_face, 0.09)
		_face_keep = FACE_GRAB_M
		if _player != null:
			var cam := _player.camera
			var pull := (_head_point(_m) - cam.global_position).normalized() * 0.05
			var tw := create_tween()
			tw.tween_property(cam, "global_position", cam.global_position + pull, 0.08)
			tw.tween_callback(func() -> void:
				if _player != null and is_instance_valid(_player):
					_cam_rest_pos = _player.camera.position)
	var agarre := str(row.get("agarre", "dos_brazos"))
	_grab_goal = 1.0 if agarre != "ninguno" else 0.0
	_follow = 1.0
	# v0.3.2e: en el agarre genérico con el final de siempre (GRASA, Don Fermín, las filas por asesino) su cara queda
	# PEGADA a tu vista a 0,5 m (el mismo seguimiento de las muertes propias). Con _face_keep sola, al estirársele el
	# cuello y deformarse la cabeza, la cara de GRASA se iba por arriba del cuadro a los dos segundos.
	if _m != null and not _overhead and str(row.get("final", "embestida")) == "embestida":
		lock_face = Vector3(0.0, 0.0, -FACE_GRAB_M)
		lock_upright = true
		lock_tilt = Vector3.ZERO
		lock_rate = 9.0
		lock_on = true
	scream_fx()
	# v0.3.2e (la barra de cuerpo entero también en el agarre genérico: GRASA, Don Fermín, las filas por asesino): el
	# cuerpo del asesino con su clip de grito (k32), TUS brazos de verdad agarrados a sus antebrazos (KillVictim) y, en
	# el final, caen sin fuerza.
	var km := KillMoves.new()
	km.fx = self
	kill_obj = km
	# GRASA no: con el clip k32 su cabeza se le venía encima a la cámara (2,6 m de alto, otro esqueleto: 58 huesos) y la
	# vista quedaba metida en su cuello, con la malla de la cara hecha astillas. Él grita con la animación de su modelo
	# (brazos abiertos, de cuerpo entero), que es con la que se encuadró este agarre.
	if _m == null or str(_m.get_meta("slug", "")) != "grasa":
		km._body("k_grito", 1.0, 0.12)
	if agarre != "ninguno" and _m != null:
		km._vic("munecas", 0.014)
		KillGore.pain(self, true)
	var fin_at := seconds * clampf(float(row.get("t_final", 0.84)), 0.5, 0.95)
	await _wait(fin_at * 0.55 + _t_grab * 0.45 - _spent)
	_shake_goal = 0.035
	_fx_goal = 0.8
	_red = 0.6
	await _wait(fin_at - _spent)


## El grito: la frase gritada, el texto, el destello de su cara, temblor, FOV que se cierra y la imagen que se
## rompe (lo comparten el agarre genérico y todas las muertes propias de KillMoves).
func scream_fx(anim: bool = true) -> void:
	_shake_goal = 0.022
	_shake = 0.05
	_fov_goal = 64.0
	_fx_goal = 0.55
	_red = 0.35
	if anim:
		_anim(_m, [str(row.get("anim", "jumpscare_main")), "scream", "jumpscare_alt"], 1.25)
	_scream_voice()
	_snd("sfx/caida_cuerpo", -2.0, 1.4)
	Controls.vibrate(1.0, 1.0, 0.8)
	_flash_face(str(row.get("cara", FACE_BY_KILLER.get(killer, ""))))
	_shout(str(row.get("frase_texto", row.get("linea", ""))))
	last_info["grito_s"] = _clock


## Manos de las muertes propias: cada una va (suavizada) a su objetivo en el espacio de la cámara.
## hand_l / hand_r son el lado IZQUIERDO / DERECHO DE TU VISTA; si el asesino te mira de frente, su mano derecha va
## a tu izquierda (si no, los brazos se cruzaban en X delante de su cara); si además está de cabeza, no se cruzan.
func _hands_step(cam: Camera3D, delta: float) -> void:
	var k := minf(delta * hand_speed, 1.0)
	# Con un vistazo (glance) las manos siguen en tu cuello/hombros: van con la vista sin el vistazo.
	var xf := cam.global_transform if glance == Vector2.ZERO else view_xf()
	var facing := _m != null and is_instance_valid(_m) and (-_m.global_transform.basis.z).dot(-xf.basis.z) < 0.0
	# De cabeza (su cara invertida sobre la tuya: te mira, pero girado sobre el eje de la vista) su hombro derecho vuelve
	# a quedar a TU derecha: ahí no se cruzan los lados (si no, los brazos hacían la X justo delante de sus ojos).
	if facing and _m.global_transform.basis.y.dot(xf.basis.y) < -0.25:
		facing = false
		last_info["manos_de_cabeza"] = true
	for side in ["l", "r"]:
		var goal: Vector3 = (hand_l if side == "l" else hand_r) if not facing else (hand_r if side == "l" else hand_l)
		var cur: Vector3 = _hl_cur if side == "l" else _hr_cur
		var on := goal != Vector3.INF
		if on:
			cur = goal if cur == Vector3.INF else cur.lerp(goal, k)
		var wv := move_toward(_rig.grab_w_l if side == "l" else _rig.grab_w_r, 1.0 if on else 0.0, delta * 8.0)
		# La palma: el punto pedido para ese lado de tu vista o, en automático, tu eje a la altura de la mano.
		var pv: Vector3 = (palm_l if side == "l" else palm_r) if not facing else (palm_r if side == "l" else palm_l)
		var gv: String = (grip_l if side == "l" else grip_r) if not facing else (grip_r if side == "l" else grip_l)
		var pw := Vector3.INF
		if cur != Vector3.INF and pv != PALM_OFF:
			if pv != Vector3.INF:
				pw = xf * pv
			elif palm_auto:
				pw = xf * Vector3(0.0, cur.y, minf(cur.z + 0.06, 0.02))
		if side == "l":
			_hl_cur = cur
			_rig.grab_w_l = wv
			_rig.palm_l = pw
			_rig.grip_l = gv
			if cur != Vector3.INF:
				_rig.grab_l = xf * cur
		else:
			_hr_cur = cur
			_rig.grab_w_r = wv
			_rig.palm_r = pw
			_rig.grip_r = gv
			if cur != Vector3.INF:
				_rig.grab_r = xf * cur
	_rig.claw = lerpf(_rig.claw, hand_claw, k)


## Donde el screamer apaga las luces del piso a mano (_lights_off), en Media/Alta manda el gestor de luces del paquete
## gráfico (pisa la energía de cada tubo en cada cuadro): se le pide el mismo apagón por su gancho. level: 0 = a
## oscuras; hasta que termine el screamer (+0,6 s: la pantalla de muerte ya tapa). seconds = 0 lo levanta.
func gfx_dark(level: float = 0.0, secs: float = -1.0) -> void:
	KillGore.gfx("GfxDirector", "blackout", [(maxf(seconds - _clock, 0.2) + 0.6) if secs < 0.0 else secs, level])


## Suelta las manos plantadas en el mundo (hands_world): desde ahí siguen a hand_l/hand_r SIN tirón (parten de donde
## estaban: _hands_step las lleva suavizadas a su nuevo sitio).
func release_hands_world() -> void:
	if not hands_world.is_valid():
		return
	var hw: Array = hands_world.call()
	hands_world = Callable()
	var cam := _cam()
	if cam == null or hw.size() < 2:
		return
	var inv := cam.global_transform.affine_inverse()
	_hl_cur = inv * (hw[0] as Vector3) if (hw[0] as Vector3) != Vector3.INF else Vector3.INF
	_hr_cur = inv * (hw[1] as Vector3) if (hw[1] as Vector3) != Vector3.INF else Vector3.INF


## Transformación de la vista sin el temblor: cabeza del jugador + cam_off/cam_pitch/cam_roll.
func view_xf() -> Transform3D:
	var h := _player.head.global_transform
	return h * Transform3D(Basis.from_euler(Vector3(cam_pitch, 0.0, cam_roll)), _cam_rest_pos + cam_off)


## Asesino pegado a la vista (lock_on): su cara en lock_face, el cuerpo de frente a ti girado lock_tilt.
func _lock_step(delta: float) -> void:
	if lock_step_hz > 0.0:
		_lock_acc += delta
		if _lock_acc < 1.0 / lock_step_hz:
			return
		delta = _lock_acc
		_lock_acc = 0.0
	var lf := lock_face
	if lock_min_front > 0.0 and lf.z < 0.0 and lf.z > -lock_min_front:
		lf.z = -lock_min_front
	var want := lock_want(lf, lock_upright, lock_tilt, lock_scale)
	var k := 1.0 if lock_step_hz > 0.0 else minf(delta * lock_rate, 1.0)
	# lock_add (la carga y el rebote de un golpe) va ENCIMA del seguimiento suavizado: se quita el del cuadro anterior,
	# se suaviza la base y se pone el de ahora.
	var base := _m.global_transform
	base.origin -= _lock_add_w
	base = base.interpolate_with(want, k)
	_lock_add_w = view_xf().basis * lock_add
	base.origin += _lock_add_w
	_m.global_transform = base
	if Engine.get_process_frames() % 8 == 0 and OS.get_cmdline_user_args().has("--log-lock"):
		var c := _cam().global_transform
		var hp := _head_point(_m)
		var loc := c.affine_inverse() * hp
		print("[lock] cara en cámara %s (pedida %s) · raíz %s · cabeza %s pitch %.2f · mira %s · ojo y %.2f" % [str(loc.snapped(Vector3.ONE * 0.01)), str(lock_face), str((c.affine_inverse() * _m.global_position).snapped(Vector3.ONE * 0.01)), str(_player.head.position.snapped(Vector3.ONE * 0.01)), _player.head.rotation.x, str((-c.basis.z).snapped(Vector3.ONE * 0.01)), c.origin.y - _floor_y()])



## Transformación de la raíz del asesino para que su cara quede en `face` (espacio de la vista, sin el temblor), de
## pie respecto del suelo (upright) o pegado a la vista, girado tilt (grados). La usan el lock y el salto de Vitzo.
func lock_want(face: Vector3, upright: bool, tilt: Vector3, scale_to: float = 1.0) -> Transform3D:
	var v := view_xf()
	var face_w := v * face
	var bw: Basis
	# v0.3.2e: si su cara va DETRÁS de ti (face.z > 0) mira hacia tu espalda (el mismo rumbo que tú). Hasta ahora quedaba
	# de espaldas a ti (como si estuviera delante): al inclinarse «sobre ti» su cadera y sus mangas se metían delante de
	# la cámara, sus brazos te alcanzaban hacia atrás y al girarte tenía que darse vuelta entero.
	var behind := face.z > 0.0
	if upright:
		var f := -v.basis.z
		f.y = 0.0
		f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
		bw = Basis.looking_at(f if behind else -f, Vector3.UP) * Basis.from_euler(tilt * (PI / 180.0))
	else:
		bw = v.basis.orthonormalized() * Basis.from_euler(tilt * (PI / 180.0))
		if not behind:
			bw = bw * Basis(Vector3.UP, PI)
	# La cabeza en el espacio de la raíz SIN su escala actual (el salto de Vitzo lo trae creciendo de 1 m a 1,8 m).
	var s := maxf(_m.global_transform.basis.get_scale().x, 0.001)
	var hl := (_m.global_transform.affine_inverse() * _head_point(_m)) * s
	return Transform3D(bw.scaled(Vector3.ONE * scale_to), face_w - bw * (hl * (scale_to / s)))


## FINAL por defecto: se te tira encima (la cara llena la pantalla) y corte.
func _f_embestida() -> void:
	if _m != null:
		# La cara (no la raíz) queda a 0,3 m: llena la pantalla sin que la cámara entre en la cabeza.
		# Se te tira encima: la distancia que se mantiene baja de 0,5 a 0,3 m.
		if _move_tw != null and _move_tw.is_valid():
			_move_tw.kill()
		var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "_face_keep", 0.3, maxf(_left() - CUT, 0.05) * 0.8)
		if lock_on and kill_id == "":  # el agarre genérico pegado a la vista: la embestida va por el mismo seguimiento
			tw.parallel().tween_property(self, "lock_face", Vector3(lock_face.x, lock_face.y, -0.3), maxf(_left() - CUT, 0.05) * 0.8)
	_fov_goal = 50.0
	_shake_goal = 0.06
	_fx_goal = 1.0
	_red = 0.85
	if _rig != null:
		_rig.deform = float(row.get("deform_final", 1.0))  # GRASA: 0,62 (al máximo su cara queda negra)
	if kill_obj is KillMoves and kill_id == "":
		(kill_obj as KillMoves)._vic("cae", maxf(_left() - CUT, 0.1) * 0.7)  # tus manos caen
	await _wait(_left() - CUT)


## Rasec: suelta tu cabeza, levanta la cabina de DJ sobre la cabeza y te la estrella en la cara.
func _f_cabina() -> void:
	_grab_goal = 0.0
	var booth := _dj_booth()
	var t := maxf(_left() - CUT, 0.3)
	if booth != null and _player != null:
		var cam := _player.camera
		var f := -cam.global_transform.basis.z
		var up := Vector3.UP
		var above := cam.global_position + f * 0.55 + up * 0.75
		booth.global_position = above + up * 0.2
		booth.look_at(cam.global_position, Vector3.UP)
		_hand_up = 0.6
		# v0.3.2e: clip de cuerpo entero (azote a dos manos por encima de la cabeza): levanta la cabina (anticipación) y
		# descarga justo cuando te la estrella (golpe del clip en 0,42 s → t * 0,7).
		var ap := _m.get_meta("anim") as AnimationPlayer if _m != null and _m.has_meta("anim") else null
		if ap != null and KillMoves.ensure_k32(_m) and ap.has_animation("k32/k_azote"):
			ap.play("k32/k_azote", 0.12, 0.42 / maxf(t * 0.7, 0.1))
		else:
			_anim(_m, ["throw", "bang_door", "jumpscare_main"], 1.6)
		_follow = 0.0
		var tw := create_tween()
		tw.tween_property(booth, "global_position", above, t * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_player.head, "rotation:x", _player.head.rotation.x + 0.35, t * 0.45)
		tw.tween_property(booth, "global_position", cam.global_position + f * 0.12, t * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		await _wait(t * 0.7)
		if _done:
			return
		_snd("sfx/rasec_cabina_golpe", 2.0)
		_snd("sfx/trainer_golpe", 0.0, 0.7)
		_snd("sfx/caida_cuerpo", 0.0, 0.8)
		_shake = 0.12
		_shake_goal = 0.12
		_crack()
		_fx_goal = 1.0
		_red = 1.0
		await _wait(_left() - CUT)
	else:
		await _f_embestida()


## Perrito RTA: la mandíbula se cierra sobre la cámara.
func _f_mordida() -> void:
	if _m != null:
		if _move_tw != null and _move_tw.is_valid():
			_move_tw.kill()
		var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "_face_keep", 0.22, maxf(_left() - CUT, 0.05) * 0.6)  # el hocico encima
	_snd("sfx/rta_ladrido", 2.0, 0.7)
	_fov_goal = 52.0
	_shake_goal = 0.07
	_fx_goal = 1.0
	_red = 0.9
	await _wait(_left() - CUT)


# --- intros ------------------------------------------------------------------------------------------

## Corre hacia ti desde un lado (la cámara gira sola hacia él).
func _i_carrera() -> void:
	var m := _killer_model()
	var side := float(row.get("desde_grados", 35.0))
	var d0 := float(row.get("desde_m", 6.0))
	# v0.3.2e: de pie, viene por donde HAY camino. Si entre tú y su punto de partida hay una pared o un mueble (estás
	# contra un rincón, en un pasillo angosto), antes la atravesaba corriendo: ahora se prueba el otro lado, de frente,
	# los costados y atrás, y parte del lado más despejado, tan lejos como se pueda. Sentado no cambia: llega por
	# delante y se inclina sobre tu escritorio (las muertes te tiran hacia atrás, al pasillo).
	var free := _free_dir(side, d0 + 0.6)
	if free < d0 + 0.5 and _player != null and not _player.seated:
		var best := side
		for cand in [-side, side * 2.0, -side * 2.0, 0.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
			var fd := _free_dir(float(cand), d0 + 0.6)
			if fd > free + 0.3:
				free = fd
				best = float(cand)
			if fd >= d0 + 0.5:
				break
		side = best
		d0 = clampf(free - 0.55, 1.4, d0)
		last_info["carrera_desde"] = [side, d0]
	_place(m, d0, side)
	_anim(m, ["sprint", "run"], 1.4)
	_snd_steps(0.0)
	_turn_to(_eye() + _dir(side) * d0 + Vector3(0, 0.1, 0), minf(0.22, _t_grab * 0.3))
	await _wait(minf(0.22, _t_grab * 0.3))
	if _done:
		return
	_rush(m, _grab_dist + 0.4, maxf(_t_grab - _spent - 0.05, 0.1))
	_aim_face(m, 0.25)
	_follow = 0.6
	_bg_flicker(_t_grab - _spent)
	await _wait(_t_grab - _spent)


## Metros libres desde ti en la dirección yaw_off (grados desde tu vista), a la altura de las piernas y del pecho: lo que
## puede recorrer alguien que viene corriendo sin atravesar nada.
func _free_dir(yaw_off: float, far: float) -> float:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return far
	var dir := _dir(yaw_off)
	var space := _player.get_world_3d().direct_space_state
	var out := far
	for h in [0.45, 1.25]:
		var from := Vector3(_eye().x, _floor_y() + float(h), _eye().z)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * far)
		q.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			out = minf(out, from.distance_to(hit["position"] as Vector3))
	return out


## Alcance (fin de una persecución): estaba a un paso; la cámara gira hacia él de un tirón y se te tira encima.
func _i_alcance() -> void:
	var m := _killer_model()
	if m != null and _catch_pos != Vector3.INF:
		m.global_position = Vector3(_catch_pos.x, _floor_y(), _catch_pos.z)
		var e := _eye()
		if Vector2(m.global_position.x - e.x, m.global_position.z - e.z).length() < _grab_dist + 0.3:
			m.global_position = Vector3(e.x, _floor_y(), e.z) + (Vector3(m.global_position.x - e.x, 0, m.global_position.z - e.z).normalized() if Vector2(m.global_position.x - e.x, m.global_position.z - e.z).length() > 0.05 else _dir(0.0)) * 1.3
		_face_cam(m)
	if not _chase_pose(m, 1.3):
		_anim(m, ["sprint", "run"], 1.3)
	if m != null:
		_turn_to(_head_point(m), minf(0.18, _t_grab * 0.3))
	await _wait(minf(0.18, _t_grab * 0.3))
	_follow = 0.8
	_rush(m, _grab_dist + 0.25, maxf(_t_grab - _spent, 0.08))
	await _wait(_t_grab - _spent)


## kills2 — SUSTO DE GOLPE (Joan: «deberían iniciar las animaciones de manera más instantánea para que sean sustos de
## golpe»). No hay intro: en el cuadro del disparo el asesino ya está a un paso, fuera del borde de tu vista (o pegado a tu
## espalda si la fila no te da vuelta), y en lo que dura el agarre (0,10 s) te cae encima mientras tu cabeza gira a él de
## un tirón. Nada suena antes: el golpe (_start_stinger) cae en el agarre. De pie entra por un lado donde HAY sitio (rayos,
## como la carrera de antes); sentado, por delante, inclinado sobre tu escritorio (las muertes sentadas parten de ahí).
func _i_golpe() -> void:
	var m := _killer_model()
	if m == null:
		await _wait(_t_grab - _spent)
		return
	var seated := _player != null and _player.seated
	if not bool(row.get("gira", true)):
		_place(m, 0.55, 180.0)
		_anim(m, ["hunch", "stare_camera"], 1.0)
		last_info["golpe_desde"] = [180.0, 0.55]
		await _wait(_t_grab - _spent)
		return
	var side := float(row.get("desde_grados", 35.0))
	side = (1.0 if side >= 0.0 else -1.0) * (35.0 if seated else 56.0)
	var d0 := _grab_dist + 0.85
	if not seated and _free_dir(side, d0 + 0.3) < d0 + 0.2:
		for cand in [-side, 0.0, 100.0, -100.0, 180.0]:
			if _free_dir(float(cand), d0 + 0.3) >= d0 + 0.2:
				side = float(cand)
				break
	last_info["golpe_desde"] = [side, d0]
	_place(m, d0, side)
	_anim(m, ["sprint", "run"], 1.6)
	_turn_to(_head_point(m), minf(0.08, _t_grab * 0.8))
	_follow = 0.85
	_rush(m, _grab_dist + 0.3, maxf(_t_grab - _spent - 0.01, 0.05))
	await _wait(_t_grab - _spent)


## Detrás: sin aviso la cámara gira 180° sola y está ahí, inclinado sobre ti.
func _i_detras() -> void:
	var m := _killer_model()
	_place(m, 0.75, 180.0)
	_anim(m, ["stare_camera", "idle"], 1.0)
	_breath()
	await _wait(_t_grab * 0.35)
	_yaw_by(180.0, _t_grab * 0.4)
	_follow = 0.5
	await _wait(_t_grab - _spent)


## Aparece de la oscuridad frente a ti (luces que parpadean).
func _i_frente() -> void:
	var m := _killer_model()
	_place(m, 1.6, 0.0)
	m.visible = false
	_snd("sfx/parpadeo", 0.0)
	_bg.color = Color(0, 0, 0, 0.96)
	await _wait(_t_grab * 0.35)
	m.visible = true
	_bg.color = Color(0, 0, 0, 0.4)
	_anim(m, ["stare_camera", "idle"], 1.0)
	_aim_face(m, 0.08)
	_follow = 0.7
	await _wait(_t_grab * 0.15)
	_bg.color = Color(0, 0, 0, 0.0)
	_rush(m, _grab_dist + 0.25, maxf(_t_grab - _spent, 0.1))
	await _wait(_t_grab - _spent)


## Apagón (tópico, coaching excedido): "Reunión finalizada" y el reloj corriendo; luz fuera; está ahí.
func _i_apagon() -> void:
	if str(row.get("extra", "")) == "reloj":
		var w := _window(tr("SCR_ROOMS_TITLE"), tr("SCR_ROOMS_ENDED"), Color(0.35, 0.35, 0.4), 640, 300)
		var clock := Label.new()
		clock.position = Vector2(220, 150)
		clock.add_theme_font_size_override("font_size", 56)
		clock.add_theme_color_override("font_color", Greybox.ROJO)
		w.add_child(clock)
		var t0 := GameState.clock_seconds
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: clock.text = GameState.clock_text_at(t0 + v), 0.0, 11.0 * 3600.0, _t_grab * 0.5)
		await _wait(_t_grab * 0.5)
		w.visible = false
	await _i_frente()


## Reflejo (correo/AHT/KYC): su cara en el monitor apagado; la silla gira sola y está ahí.
func _i_reflejo() -> void:
	_bg.color = Color(0, 0, 0, 0.55)
	var ghost := _ghost_face(str(row.get("cara", FACE_BY_KILLER.get(killer, ""))))
	await _wait(_t_grab * 0.45)
	ghost.visible = false
	_bg.color = Color(0, 0, 0, 0)
	var m := _killer_model()
	if not bool(row.get("gira", true)):
		# v0.3.1 (muertes propias): no te das vuelta; está justo detrás de ti y te agarra la cabeza (monitor/teclado).
		_place(m, 0.55, 180.0)
		_anim(m, ["hunch", "stare_camera"], 1.0)
		_breath()
		if m != null:
			m.visible = false  # no se ve: está detrás (solo su reflejo)
		await _wait(_t_grab - _spent)
		if m != null:
			m.visible = true
		return
	_place(m, 0.75, 160.0)
	_anim(m, ["point", "stare_camera"], 1.2)
	_yaw_by(160.0, _t_grab * 0.35)
	_follow = 0.4
	await _wait(_t_grab - _spent)


## Pantalla (coaching): Ezlaki Rooms se abre sola con su cara; la imagen se corta y sale de la pantalla en 3D.
func _i_pantalla() -> void:
	if killer == "rasec":
		_start_music(str(row.get("musica", "musica/hold_kipupay_parlantes")))
	var w := _window(tr(str(row.get("titulo", "SCR_ROOMS_TITLE"))), tr(str(row.get("cuerpo", "SCR_ROOMS_BODY"))), Color(0.2, 0.45, 0.75), 760, 470)
	w.scale = Vector2.ONE * 0.4
	var video := TextureRect.new()
	video.texture = _face_tex(str(row.get("cara_antes", row.get("cara", FACE_BY_KILLER.get(killer, "")))))
	video.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	video.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	video.position = Vector2(230, 120)
	video.size = Vector2(300, 300)
	video.material = _horror_material()
	w.add_child(video)
	_snd("sfx/estatica_desconexion", -10.0)
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE * 1.05, _t_grab * 0.5)
	await _wait(_t_grab * 0.55)
	if _music != null:
		_music.stop()
	w.visible = false
	_bg.color = Color(0, 0, 0, 1)
	await _wait(_t_grab * 0.12)
	_bg.color = Color(0, 0, 0, 0)
	var m := _killer_model()
	_place(m, 0.9, 0.0, -0.1)
	_aim_face(m, 0.05)
	_follow = 0.8
	if m != null:
		m.scale = Vector3.ONE * 0.3
		create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(m, "scale", Vector3.ONE, maxf(_t_grab - _spent, 0.1))
	_anim(m, ["stare_camera", "idle"], 1.0)
	await _wait(_t_grab - _spent)


func _start_music(slot: String) -> void:
	var path := AudioManager.resolve(slot)
	if path == "":
		return
	_music = AudioStreamPlayer.new()
	_music.bus = "Sala"
	_music.stream = load(path) as AudioStream
	_music.volume_db = -8.0
	add_child(_music)
	_music.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music, "volume_db", 0.0, _t_grab * 0.5)
	tw.tween_property(_music, "pitch_scale", 0.55, _t_grab * 0.5)


## Teléfono (llamadas perdidas / otra isla): timbres superpuestos; giras y viene corriendo señalándote.
func _i_telefono() -> void:
	var me: WeakRef = weakref(self)
	for i in 3:
		get_tree().create_timer(i * 0.11, true).timeout.connect(func() -> void:
			var fx: Screamers = me.get_ref()
			if fx != null and not fx._done:
				fx._snd("sfx/telefono_timbre", -2.0, 0.8 + i * 0.1))
	var m := _killer_model()
	var side := float(row.get("desde_grados", -70.0))
	_place(m, 3.0, side)
	_anim(m, ["point"], 1.0)
	await _wait(_t_grab * 0.3)
	_turn_to(_eye() + _dir(side) * 3.0 + Vector3(0, 0.1, 0), _t_grab * 0.2)
	await _wait(_t_grab * 0.2)
	_anim(m, ["sprint", "run"], 1.4)
	_rush(m, _grab_dist + 0.3, maxf(_t_grab - _spent, 0.1))
	_follow = 0.7
	await _wait(_t_grab - _spent)


## Lista del Mentor (Available bajo): la lista con tu % en rojo, y él detrás de ella.
func _i_lista() -> void:
	var pct := detail if detail != "" else str(int(Metrics.available_pct()))
	var lines := tr("SCR_LIST_BODY").replace("{agente}", GameState.agent).replace("{pct}", pct)
	var w := _window(tr("SCR_LIST_TITLE"), lines, Greybox.ROJO, 760, 460)
	w.scale = Vector2.ONE * 0.6
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2.ONE * 1.1, _t_grab * 0.5)
	await _wait(_t_grab * 0.55)
	w.visible = false
	await _i_frente_corto()


## WW sin Ack: la ventana del WW crece hasta llenar la pantalla y se desgarra; detrás está él.
func _i_ww() -> void:
	var w := _window(tr("SCR_WW_TITLE"), tr("SCR_WW_BODY"), Greybox.ROJO, 640, 360)
	w.scale = Vector2.ONE * 0.6
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(w, "scale", Vector2.ONE * 3.0, _t_grab * 0.5)
	tw.tween_property(w, "modulate", Color(1, 1, 1, 0.0), _t_grab * 0.5)
	_fx_goal = 0.35
	await _wait(_t_grab * 0.5)
	w.visible = false
	await _i_frente_corto()


## Tres molestos: las voces de los clientes en el auricular, la imagen se inclina, los tickets, y él.
func _i_tickets() -> void:
	for i in 3:
		var path := AudioManager.resolve("voces/clientes/cliente_estafado_0%d" % (i + 1))
		if path != "":
			var ap := AudioStreamPlayer.new()
			ap.stream = load(path) as AudioStream
			ap.bus = "Auricular"
			ap.pitch_scale = 0.8 + i * 0.1
			add_child(ap)
			ap.play()
			_audio.append(ap)
	if _player != null:
		create_tween().tween_property(_cam(), "rotation:z", deg_to_rad(14.0), _t_grab * 0.4)
	for i in 3:
		var tk := _window(tr("SCR_TICKET_TITLE") % (i + 1), tr("SCR_TICKET_BODY"), Greybox.ROJO, 420, 200)
		tk.offset_left += -380 + i * 380
		tk.offset_right += -380 + i * 380
		tk.offset_top += -200 + i * 60
		tk.offset_bottom += -200 + i * 60
		tk.rotation = -0.1 + i * 0.1
		tk.scale = Vector2.ONE * 0.2
		var tw2 := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(i * _t_grab * 0.12)
		tw2.tween_property(tk, "scale", Vector2.ONE, 0.12)
	await _wait(_t_grab * 0.5)
	for c in _root.get_children():
		if c is Panel:
			(c as Panel).visible = false
	await _i_frente_corto()


## Está a un metro en la penumbra y se te tira encima (tras una ventana 2D).
func _i_frente_corto() -> void:
	var m := _killer_model()
	_place(m, 1.1, 0.0)
	_aim_face(m, 0.06)
	_follow = 0.8
	_anim(m, ["point", "stare_camera"], 1.3)
	_snd("sfx/parpadeo", -4.0)
	_rush(m, _grab_dist + 0.2, maxf(_t_grab - _spent, 0.1))
	await _wait(_t_grab - _spent)


## Mesa (lunch, sentado): estaba sentado frente a ti; se para de golpe y salta por encima de la mesa.
func _i_mesa() -> void:
	if _player == null or not _player.seated:
		await _i_golpe()
		return
	await _i_salto_mesa()


## Haime en la calibración: sentado frente a ti, se para y salta la mesa hacia tu cabeza.
func _i_salto_mesa() -> void:
	var m := _killer_model()
	# v0.3.2d: si el Haime del mundo está ahí (la sesión fatal lo deja de pie, apoyado en la mesa), el screamer toma su
	# sitio y su pose y salta la mesa desde ahí: un solo plano, sin teletransporte.
	if killer == "haime" and m != null:
		var src := _world_actor("haime")
		if src != null and _take_over(m, src):
			await _haime_vault(m, src)
			return
	var sitting := _player != null and _player.seated
	_place(m, 1.25 if sitting else 1.8, 0.0, -0.4 if sitting else 0.0)
	_anim(m, ["sit", "stare_camera"] if sitting else ["stare_camera"], 0.8)
	_aim_face(m, 0.05)
	_follow = 0.8
	# kills2 (susto de golpe): sin el «REC» de aviso; se encoge un instante (≤ 0,13 s) y salta: el golpe es lo primero.
	var t_sit := minf(_t_grab * 0.4, 0.13)
	last_info["golpe_previsto_s"] = _clock + t_sit
	await _wait(t_sit)
	if _done or m == null:
		return
	_anim(m, ["jumpscare_alt", "jumpscare_main"], 1.5)
	_snd("sfx/caida_cuerpo", -4.0, 1.3)
	last_info["golpe_s"] = minf(float(last_info.get("golpe_s", 99.0)), _clock)
	var t := maxf(_t_grab - _spent, 0.12)
	var start := m.global_position
	var end_flat := _eye() + (Vector3(start.x, 0, start.z) - Vector3(_eye().x, 0, _eye().z)).normalized() * (_grab_dist + 0.1)
	var end := Vector3(end_flat.x, _floor_y() + _drop_for(m), end_flat.z)
	var tw := _mtween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			m.global_position = start.lerp(end, u) + Vector3(0, sin(u * PI) * 0.55, 0)
			_face_cam(m), 0.0, 1.0, t)
	await _wait(t)


## El actor del MUNDO de este asesino (el que _hide_world_killer acaba de esconder) si estaba a la vista y cerca: el
## screamer puede tomar su sitio y su pose (v0.3.2d: nada se teletransporta).
func _world_actor(slug: String, max_dist: float = 3.6) -> P5Actor:
	for n in _hidden:
		if n is P5Actor and is_instance_valid(n) and (n as P5Actor).slug == slug and (n as P5Actor).model != null \
				and (n as Node3D).global_position.distance_to(_eye()) < max_dist:
			return n as P5Actor
	return null


static func _skeleton_of(n: Node) -> Skeleton3D:
	if n == null:
		return null
	for c in n.find_children("*", "Skeleton3D", true, false):
		return c as Skeleton3D
	return null


## TOMA DE RELEVO (v0.3.2d): el modelo del screamer queda EXACTAMENTE donde está el actor del mundo y con su pose: una
## animación de una sola clave hecha con los huesos del otro esqueleto (biblioteca «k32» del reproductor del screamer;
## el clip que venga después se mezcla desde ahí). false si no se pudo (sin esqueleto o sin reproductor).
func _take_over(m: Node3D, src: P5Actor) -> bool:
	var ssk := _skeleton_of(src.model)
	var dsk := _skeleton_of(m)
	if ssk == null or dsk == null or not m.has_meta("anim"):
		return false
	var ap := m.get_meta("anim") as AnimationPlayer
	var ap_root := ap.get_node_or_null(ap.root_node)
	if ap_root == null:
		return false
	# El sitio: mi esqueleto donde está el suyo (posición, giro e inclinación; la escala, la mía).
	var rel := m.global_transform.affine_inverse() * dsk.global_transform
	var want := ssk.global_transform.orthonormalized() * rel.orthonormalized().affine_inverse()
	m.global_transform = Transform3D(want.basis.orthonormalized().scaled(m.global_transform.basis.get_scale()), want.origin)
	# La pose.
	var a := Animation.new()
	a.length = 0.2
	a.loop_mode = Animation.LOOP_LINEAR
	var base := str(ap_root.get_path_to(dsk))
	var n_ok := 0
	for i in dsk.get_bone_count():
		var bn := dsk.get_bone_name(i)
		var j := ssk.find_bone(bn)
		if j < 0:
			continue
		var tp := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tp, NodePath("%s:%s" % [base, bn]))
		a.position_track_insert_key(tp, 0.0, ssk.get_bone_pose_position(j))
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath("%s:%s" % [base, bn]))
		a.rotation_track_insert_key(tr, 0.0, ssk.get_bone_pose_rotation(j))
		n_ok += 1
	if n_ok < 10:
		return false
	var lib: AnimationLibrary = ap.get_animation_library("k32") if ap.has_animation_library("k32") else null
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library("k32", lib)
	if lib.has_animation("relevo"):
		lib.remove_animation("relevo")
	lib.add_animation("relevo", a)
	ap.play("k32/relevo", 0.0)
	ap.advance(0.0)
	last_info["relevo"] = src.slug
	last_info["relevo_huesos"] = n_ok
	last_info["relevo_error_m"] = (dsk.global_transform.origin - ssk.global_transform.origin).length()
	return true


## Haime salta la mesa desde donde estaba (toma de relevo de la sesión fatal: de pie, apoyado con las dos manos en la
## mesa, la sala a oscuras con el rojo del REC). Un solo plano, sin teletransporte ni salto de luz:
##   MIRA (22 % del tiempo al agarre): quieto en su pose; la sala sigue como la dejó la sesión (un velo propio tapa el
##     salto de imagen de esconder la UI, que se llevaba el grano y la viñeta) y sus luces suben de cero;
##   SE ENCOGE (33 %): clip k32/k_salto (0-0,30 s): los hombros bajan entre los brazos plantados, la cadera atrás;
##   SALTA (45 %): empuja la mesa (salta y vuelve), recoge las rodillas y pasa POR ENCIMA, la cara por delante; voltea
##     el monitor de QA; las manos sueltan la mesa y vienen a tu cara en garra;
##   cae sobre ti: el agarre de su muerte (KillMoves._k_haime_mejillas) sigue desde ese mismo sitio.
func _haime_vault(m: Node3D, src: P5Actor) -> void:
	var ssk := _skeleton_of(src.model)
	var lights: Array = []
	for c in m.get_children():
		if c is Light3D:
			lights.append([c, (c as Light3D).light_energy * 0.5])  # la sala está a oscuras: con menos luz ya se le ve
			(c as Light3D).light_energy = 0.0
	if _face_light != null and is_instance_valid(_face_light):
		lights.append([_face_light, _face_light.light_energy * 0.45])
		_face_light.light_energy = 0.0
	if _rig != null:
		_rig.look = 1.0
		_rig.look_at_point = _eye()
		for sr in src.model.find_children("*", "ScreamRig", true, false):
			_rig.deform = maxf(_rig.deform, (sr as ScreamRig).deform)
			_rig.severity = (sr as ScreamRig).severity
			break
	# Las manos, plantadas donde las tenía (en la mesa).
	var hl := Vector3.INF
	var hr := Vector3.INF
	if ssk != null and ssk.find_bone("hand_l") >= 0 and ssk.find_bone("hand_r") >= 0:
		hl = ssk.global_transform * ssk.get_bone_global_pose(ssk.find_bone("hand_l")).origin
		hr = ssk.global_transform * ssk.get_bone_global_pose(ssk.find_bone("hand_r")).origin
		hands_world = func() -> Array: return [hl, hr]
		_grab_goal = 1.0
		_grabbing = 1.0
	_aim_face(m, 0.1)
	_follow = 0.85
	_dbg_lights("relevo")
	# kills2 (susto de golpe): ya no te mira ni se le oye respirar antes (ni el «REC»): se encoge 0,12 s (la anticipación
	# del salto) y salta; el golpe en la mesa es lo primero que se oye.
	var t_all := maxf(_t_grab - _spent, 0.4)
	var t_stare := 0.0
	var t_coil := minf(t_all * 0.26, 0.13)
	last_info["golpe_previsto_s"] = _clock + t_coil
	# El primer cuadro de la muerte es LA MISMA IMAGEN que el último de la sesión: al esconder la UI se iban el grano, la
	# viñeta y el tinte de la pantalla (fx/overlays.gd, en la capa de la UI) y la sala «saltaba» a más clara en un cuadro
	# (medido: ×1,75). La película sigue encendida mientras mira y se encoge, y se apaga en el salto (con el golpe en la
	# mesa, el temblor y el fogonazo de sus luces: ahí el cambio de imagen es el del salto).
	_film_bridge()
	# MIRA.
	for pair in lights:
		create_tween().tween_property(pair[0], "light_energy", float(pair[1]) * 0.25, t_stare)
	_fx_goal = 0.12
	if t_stare > 0.0:
		await _wait(t_stare)
	if _done or not is_instance_valid(m):
		return
	# SE ENCOGE.
	_dbg("se encoge")
	var ap := m.get_meta("anim") as AnimationPlayer
	var k32 := KillMoves.ensure_k32(m) and ap.has_animation("k32/k_salto")
	if k32:
		ap.play("k32/k_salto", minf(0.3, t_coil * 0.6), 0.30 / t_coil)
	var start := m.global_transform
	var back := start.origin - _eye()
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else -_dir(0.0)
	var coil := start
	coil.origin += back * 0.08 - Vector3(0, 0.05 if k32 else 0.11, 0)
	var twc := _mtween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	twc.tween_property(m, "global_transform", coil, t_coil)
	for pair in lights:
		create_tween().tween_property(pair[0], "light_energy", float(pair[1]) * 0.5, t_coil)
	_fx_goal = 0.22
	await _wait(t_coil)
	if _done or not is_instance_valid(m):
		return
	# EL SALTO.
	_dbg("salto")
	last_info["salto_s"] = _clock
	_film_bridge_end()
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	var t := maxf(_t_grab - _spent, 0.25)
	if k32:
		ap.play("k32/k_salto", 0.05, 0.7 / t)
		ap.seek(0.30, false)
	else:
		for n in ["jumpscare_alt", "jumpscare_main"]:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_NONE
				ap.play(n, 0.22, 1.3)
				break
	_snd("sfx/caida_cuerpo", -4.0, 1.3)
	_snd("sfx/kill_mesa_01", 0.0, 1.1)
	last_info["golpe_s"] = minf(float(last_info.get("golpe_s", 99.0)), _clock)
	_shake = 0.05
	_shake_goal = 0.02
	_fov_goal = 62.0
	_fx_goal = 0.5
	_red = 0.3
	Controls.vibrate(0.8, 1.0, 0.3)
	_qa_table_kick()
	for pair in lights:
		create_tween().tween_property(pair[0], "light_energy", float(pair[1]), 0.3)
	var from := m.global_transform
	# El camino de su cara, en el MUNDO (en el espacio de la vista no: la vista lo sigue y el salto se iría al techo): de
	# donde está a 0,48 m de tus ojos, a su altura, con un arco; el cuerpo cuelga de la cara.
	var face0 := _head_point(m)
	var dirp := face0 - _eye()
	dirp.y = 0.0
	dirp = dirp.normalized() if dirp.length() > 0.05 else _dir(0.0)
	var st := {"sueltas": false, "monitor": false, "cae": false}
	var tw := _mtween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(m) or _done:
			return
		var e := pow(u, 1.25)  # te llega encima acelerando
		var target := _eye() + dirp * 0.48  # donde lo toma su muerte (KillMoves._k_haime_mejillas: L(0, 0, 0.48))
		var fw := face0.lerp(target, e) + Vector3(0, 0.24 * sin(u * PI), 0)
		var dive := sin(clampf(u / 0.85, 0.0, 1.0) * PI)  # echado adelante en el aire; enderezado al caer
		var bw := Basis.looking_at(-dirp, Vector3.UP) * Basis.from_euler(Vector3(deg_to_rad(-8.0 - 34.0 * dive), 0, 0))
		var sc := maxf(m.global_transform.basis.get_scale().x, 0.001)
		var head_l := (m.global_transform.affine_inverse() * _head_point(m)) * sc
		var want := Transform3D(bw, fw - bw * head_l)
		m.global_transform = from.interpolate_with(want, clampf(u * 5.0, 0.0, 1.0)) if u < 0.2 else want
		if u > 0.2 and not bool(st["sueltas"]):
			st["sueltas"] = true
			release_hands_world()  # empujó la mesa: ahora las manos vienen a tu cara, en garra
			kill_hands_early = true
			hand_l = Vector3(-0.16, -0.04, -0.32)
			hand_r = Vector3(0.16, -0.04, -0.32)
			hand_claw = 0.9
			hand_speed = 10.0
		if u > 0.3 and not bool(st["monitor"]):
			st["monitor"] = true
			_qa_monitor_topple()
		if u > 0.78 and not bool(st["cae"]):
			st["cae"] = true
			hand_l = Vector3(-0.13, -0.09, -0.06)
			hand_r = Vector3(0.13, -0.09, -0.06)
			hand_claw = 0.55
			hand_speed = 16.0, 0.0, 1.0, t)
	await _wait(t)


## La «película» de la pantalla (grano, viñeta y tinte de fx/overlays.gd, que vive en la capa de la UI) sigue encendida
## aunque la UI esté escondida: la imagen no cambia en el primer cuadro de la muerte. En su capa solo queda visible la
## rama que lleva a la película; _film_bridge_end() lo deshace (y _cleanup, si el screamer se corta antes).
func _film_bridge() -> bool:
	if not _bridge.is_empty():
		return true
	for n in get_tree().root.find_children("*", "Control", true, false):
		var sc: Script = n.get_script()
		if sc == null or not sc.resource_path.ends_with("fx/overlays.gd"):
			continue
		var layer: CanvasLayer = null
		var path: Array[Node] = [n]
		var p := n.get_parent()
		while p != null:
			if p is CanvasLayer:
				layer = p
				break
			path.append(p)
			p = p.get_parent()
		if layer == null or not _hidden_ui.has(layer):
			return false
		var saved: Array = []
		var keep: Node = layer
		for i in range(path.size() - 1, -1, -1):
			for c in keep.get_children():
				if c is CanvasItem and c != path[i] and (c as CanvasItem).visible:
					saved.append(c)
					(c as CanvasItem).visible = false
			keep = path[i]
		layer.visible = true
		_bridge = [layer, saved]
		last_info["pelicula_puente"] = true
		return true
	return false


func _film_bridge_end() -> void:
	if _bridge.is_empty():
		return
	var layer := _bridge[0] as CanvasLayer
	if is_instance_valid(layer) and _hidden_ui.has(layer):
		layer.visible = false
	for c in _bridge[1]:
		if is_instance_valid(c):
			(c as CanvasItem).visible = true
	_bridge.clear()


## Depuración (--log-screamer): las luces encendidas cerca y las capas de UI escondidas.
func _dbg_lights(tag: String) -> void:
	if not OS.get_cmdline_user_args().has("--log-screamer"):
		return
	var e := _eye()
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l.is_visible_in_tree() and l.light_energy > 0.01 and l.global_position.distance_to(e) < 9.0:
			print("[luces %s] %s (%s) e=%.2f color %s a %.1f m" % [tag, l.name, l.get_parent().name, l.light_energy, str(l.light_color), l.global_position.distance_to(e)])
	var names: Array = []
	for l2 in _hidden_ui:
		names.append("%s(%d)" % [l2.name, l2.layer])
	print("[luces %s] capas escondidas: %s · fx k %.2f red %.2f · bg %s" % [tag, str(names), _fx_k, _red, str(_bg.color) if _bg != null else "-"])
	for l3 in _hidden_ui:
		for c in l3.find_children("*", "Control", true, false):
			var ci := c as Control
			var vp := get_viewport().get_visible_rect().size
			if ci.size.x >= vp.x * 0.9 and ci.size.y >= vp.y * 0.9 and (ci is ColorRect or ci is TextureRect) and ci.visible:
				var col: Color = (ci as ColorRect).color if ci is ColorRect else ci.modulate
				print("[luces %s]   %s/%s %s color %s mod %s self %s mat %s" % [tag, l3.name, ci.name, ci.get_class(), str(col), str(ci.modulate), str(ci.self_modulate), str(ci.material)])
	var we := get_viewport().get_camera_3d().get_world_3d().environment if get_viewport().get_camera_3d() != null else null
	if we != null:
		print("[luces %s] ambiente: energía %.2f color %s · exposición %.2f · brillo %.2f" % [tag, we.ambient_light_energy, str(we.ambient_light_color), we.tonemap_exposure, we.adjustment_brightness])


## La mesa de la sala de calibración salta cuando Haime la empuja para saltar (vuelve a su sitio sola).
func _qa_table_kick() -> void:
	var fl := FloorBase.active
	if fl == null:
		return
	for nm in ["MesaCalibracion", "MesaCalibracionPata"]:
		var n := fl.find_child(nm, true, false) as Node3D
		if n == null:
			continue
		if not _xf_back.has(n):
			_xf_back[n] = n.transform
		var y0 := n.position.y
		var tw := n.create_tween()
		tw.tween_property(n, "position:y", y0 + 0.03, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position:y", y0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if not (last_info["props"] as Array).has("mesa"):
		(last_info["props"] as Array).append("mesa")


## El monitor de QA (con su REC) se va de cara contra la mesa cuando Haime le pasa por encima: cae hacia ti, rebota y
## el vidrio se raja. Se mueve entero (pantalla, punto y rótulo del REC, su luz) y vuelve a su sitio al terminar.
func _qa_monitor_topple() -> void:
	var fl := FloorBase.active
	if fl == null or _player == null:
		return
	var mon := fl.find_child("MonitorQA", true, false) as Node3D
	if mon == null or mon.global_position.distance_to(_eye()) > 4.0:
		return
	var parts: Array[Node3D] = [mon]
	for nm in ["RecPunto", "RecTexto", "LuzRec"]:
		var n := fl.find_child(nm, true, false) as Node3D
		if n != null:
			parts.append(n)
	for c in fl.get_children():
		if c is Label3D and not parts.has(c) and (c as Label3D).global_position.distance_to(mon.global_position) < 0.14:
			parts.append(c as Node3D)  # el rótulo de la pantalla
	var start: Array[Transform3D] = []
	for n in parts:
		if not _xf_back.has(n):
			_xf_back[n] = n.transform
		start.append(n.global_transform)
	# Cae hacia donde estás tú, girando sobre el borde de su base.
	var to := _eye() - mon.global_position
	to.y = 0.0
	to = to.normalized() if to.length() > 0.05 else Vector3.RIGHT
	var axis := Vector3.UP.cross(to).normalized()
	var pivot := mon.global_position - Vector3(0, 0.18, 0) + to * 0.02
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		var ang := deg_to_rad(86.0) * u
		var xf := Transform3D(Basis(axis, ang), pivot) * Transform3D(Basis.IDENTITY, -pivot)
		for i in parts.size():
			if is_instance_valid(parts[i]):
				parts[i].global_transform = xf * start[i], 0.0, 1.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_snd("sfx/kill_plastico_quiebra", 0.0, 0.9)
	var me: WeakRef = weakref(self)
	get_tree().create_timer(0.09, true).timeout.connect(func() -> void:
		var f: Screamers = me.get_ref()
		if f != null and not f._done:
			KillGore.glass(f, 0.0)
			f._snd("sfx/kill_mesa_02", -2.0, 1.2))
	if not (last_info["props"] as Array).has("monitor_qa"):
		(last_info["props"] as Array).append("monitor_qa")


## Haime (inasistencia): te llama el teléfono, pasos que corren detrás; la cámara gira y viene corriendo con el
## headset puesto.
func _i_detras_corre() -> void:
	_snd("sfx/telefono_timbre", -2.0)
	EventBus.subtitle.emit("haime", tr("SCR_REC_LINE"), 1.4)
	var m := _killer_model()
	_place(m, 5.0, 180.0)
	_anim(m, ["sprint", "run"], 1.5)
	_snd_steps(0.0)
	await _wait(_t_grab * 0.35)
	if not bool(row.get("gira", true)):
		# v0.3.1 (muertes propias): no alcanzas a darte vuelta; los pasos llegan hasta tu espalda.
		_rush(m, 0.45, maxf(_t_grab - _spent, 0.1))
		await _wait(_t_grab - _spent)
		return
	_yaw_by(180.0, _t_grab * 0.25)
	_rush(m, _grab_dist + 0.3, maxf(_t_grab - _spent, 0.1))
	_follow = 0.6
	await _wait(_t_grab - _spent)


## Vitzo: sale ARRASTRÁNDOSE del monitor (cabeza y brazos primero) hacia tu cara. Si ya salió (la fase 1 en el
## mundo, VitzoScreamer), sigue desde donde está.
func _i_monitor() -> void:
	var world := get_tree().root.find_child("VitzoScreamer", true, false) as Node3D
	var start := Vector3.INF
	if world != null:
		start = world.call("head_position") if world.has_method("head_position") else world.global_position
		world.visible = false
	else:
		for s in get_tree().get_nodes_in_group("monitor_screens"):
			if s is MonitorScreen and (s as MonitorScreen).seat_id == GameState.seated_at and (s as MonitorScreen).side == "right":
				start = (s as Node3D).global_position
				(s as MonitorScreen).show_reflection(Faces.texture_at("res://assets/ui/vitzo_cara.png"), 1.0)
	if start == Vector3.INF:
		start = _eye() + _dir(0.0) * 0.9 - Vector3(0, 0.35, 0)
	var m := _killer_model()
	if m == null:
		await _wait(_t_grab - _spent)
		return
	VitzoScreamer.crawl_pose(m, 1.0)
	_grow_vitzo(m, maxf(_t_grab - _spent, 0.2))
	m.global_position = start - Vector3(0, 0.55, 0)
	_face_cam(m)
	_snd("sfx/monitor_rompe", 0.0)
	_snd("sfx/vitzo_arrastre_loop", -2.0)
	_aim_face(m, 0.05)
	_follow = 0.9
	var t := maxf(_t_grab - _spent, 0.2)
	var end := _eye() + (Vector3(start.x, _eye().y, start.z) - _eye()).normalized() * _grab_dist
	var tw := _mtween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			m.global_position = (start - Vector3(0, 0.55, 0)).lerp(Vector3(end.x, _eye().y - _head_rel_y(m), end.z), u * u)
			VitzoScreamer.crawl_pose(m, 1.0 - u * 0.6)
			_face_cam(m), 0.0, 1.0, t)
	await _wait(t)


## v0.3.2 (Joan: «estaría bueno si haces a Vitzo tamaño de una persona cuando salga de la pantalla»): sale del
## monitor del tamaño de la pantalla (1 m) y crece a tirones hasta 1,8 m (HEIGHTS) en la segunda mitad del salir.
const VITZO_SMALL := 1.0
func _grow_vitzo(m: Node3D, t: float) -> void:
	if m == null or str(row.get("modelo", _default_model())) != "vitzo":
		return
	var k := VITZO_SMALL / float(HEIGHTS.get("vitzo", 1.8))
	m.scale = Vector3.ONE * k
	var tw := create_tween()
	tw.tween_interval(t * 0.45)
	for i in 5:  # a saltos (glitch), no un crecimiento suave
		tw.tween_callback(func() -> void:
			if is_instance_valid(m):
				m.scale = Vector3.ONE * lerpf(k, 1.0, (i + 1) / 5.0)
				_snd("sfx/kill_elastico", -6.0, 0.5 + 0.08 * i))
		tw.tween_interval(t * 0.55 / 5.0)
	last_info["vitzo_crece"] = true


## Pose de gateo de un modelo de screamer (como VitzoScreamer.crawl_pose, pero en metros del mundo aunque la raíz
## esté escalada): el cuerpo tendido hacia adelante (w = 1), la cabeza en el origen de la raíz.
func _crawl(m: Node3D, w: float) -> void:
	if m == null or not m.has_meta("scene"):
		return
	var scene := m.get_meta("scene") as Node3D
	var k := clampf(w, 0.0, 1.0)
	var inv := 1.0 / maxf(m.scale.x, 0.001)
	scene.rotation.x = deg_to_rad(72.0) * k
	scene.position = Vector3(0.0, 0.18 * k, float(CharacterRig.HEIGHTS_V2.get("vitzo", 1.0)) * 0.86 * k) * inv


## Vitzo (v0.3.2d, Joan: «lo único "avisado" de Vitzo es cuando sale de la pantalla… cuando ya te saltó o ya es la
## animación de muerte… el screamer debe ser más rápido para que sea de impacto, susto sin preparar»). Desde que te
## atrapa, el salto cae YA: nada de pared de recordatorios ni de un segundo gateo. El modelo arranca EXACTAMENTE
## donde quedó el Vitzo del mundo (tendido sobre tu escritorio al terminar de salir del monitor, de 1 m; o corriendo
## detrás de ti, de 1,8 m, si te persiguió), se encoge un instante (jump_s() s: todo calla, la anticipación) y salta
## a tu cara en lo que falta hasta el agarre (~0,1 s) con el estruendo (sfx/vitzo_salto, _start_stinger).
func _i_zarpazo() -> void:
	var m := _killer_model()
	if m == null:
		await _wait(_t_grab - _spent)
		return
	var world := get_tree().root.find_child("VitzoScreamer", true, false) as Node3D
	var chase := _catch_pos != Vector3.INF
	var k_small := VITZO_SMALL / float(HEIGHTS.get("vitzo", 1.8))
	var crawl := 0.0
	if chase:
		# Te alcanzó corriendo: sigue desde donde estaba el cazador (si quedó pegado a ti, a un paso).
		m.global_position = Vector3(_catch_pos.x, _floor_y(), _catch_pos.z)
		var e0 := _eye()
		var flat := Vector3(m.global_position.x - e0.x, 0.0, m.global_position.z - e0.z)
		if flat.length() < 0.9:
			m.global_position = Vector3(e0.x, _floor_y(), e0.z) + (flat.normalized() if flat.length() > 0.05 else _dir(0.0)) * 0.9
		_face_cam(m)
		if not _chase_pose(m, 1.5):
			_anim(m, ["sprint", "run"], 1.5)
	elif world != null and is_instance_valid(world):
		# Terminó de salir del monitor y sigues sentado: el mismo sitio, tamaño y pose de gateo (sin salto de imagen).
		m.scale = Vector3.ONE * k_small
		m.global_position = world.global_position
		_face_cam(m)
		crawl = 1.0
		_crawl(m, crawl)
		_anim(m, ["walk", "run", "idle"], 1.6)
		world.visible = false
		last_info["vitzo_crece"] = true
	else:
		# Sin fase del mundo (pruebas, causas sin monitor): sale del borde de tu escritorio, a 0,9 m.
		m.scale = Vector3.ONE * k_small
		var st := _eye() + _dir(0.0) * 0.9 - Vector3(0, 0.55, 0)
		m.global_position = st
		_face_cam(m)
		crawl = 1.0
		_crawl(m, crawl)
		last_info["vitzo_crece"] = true
	if _rig != null:
		_rig.arm_stretch = 1.0
		# La pantalla-cara te mira desde el primer cuadro (el _process del screamer recién corre en el siguiente: sin
		# esto, tendido, se le veía la coronilla un cuadro).
		_rig.look = 1.0
		_rig.look_at_point = _eye()
	var start := m.global_transform
	_aim_face(m, 0.06)
	_follow = 0.9
	_fx_goal = 0.25
	# Anticipación (jump_s): se encoge hacia atrás y abajo, la pantalla-cara se queda fija en ti.
	var t_coil := maxf(jump_s() - _spent, 0.0)
	var back := (start.origin - _eye())
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else -_dir(0.0)
	if t_coil > 0.02:
		var coil := start
		coil.origin += back * 0.07 - Vector3(0, 0.03 if not chase else 0.1, 0)
		var twc := _mtween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		twc.tween_property(m, "global_transform", coil, t_coil)
		await _wait(t_coil)
		if _done or not is_instance_valid(m):
			return
	# EL SALTO: de donde está a tu cara (el lugar exacto del agarre de su muerte), creciendo a 1,8 m y enderezándose.
	_dbg("salto")
	last_info["salto_s"] = _clock
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	_anim(m, ["jumpscare_main", "jumpscare_alt"], 1.6)
	_grab_goal = 1.0  # los brazos salen hacia ti en el aire
	hand_l = Vector3(-0.21, -0.02, -0.1)
	hand_r = Vector3(0.21, -0.02, -0.1)
	kill_hands_early = true
	_shake = 0.07
	_shake_goal = 0.03
	_fov_goal = 66.0
	_fx_goal = 0.7
	_red = 0.5
	Controls.vibrate(1.0, 1.0, 0.35)
	var from := m.global_transform
	var t_leap := maxf(_t_grab - _spent, 0.06)
	var face := VITZO_GRAB_FACE
	var steps := [k_small, lerpf(k_small, 1.0, 0.45), 1.0] if crawl > 0.0 else [1.0, 1.0, 1.0]
	var tw := _mtween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(m) or _done:
			return
		var e := 1.0 - pow(1.0 - u, 3.0)  # sale disparado y frena en tu cara
		var sc: float = steps[mini(int(u * 3.0), 2)]  # crece a saltos (glitch), no suave
		_crawl(m, crawl * (1.0 - e))
		var want := lock_want(face, true, Vector3.ZERO, sc)
		var xf := from.interpolate_with(want, e)
		xf.origin += Vector3(0, sin(u * PI) * (0.1 if crawl > 0.0 else 0.22), 0)
		m.global_transform = xf, 0.0, 1.0, t_leap)
	await _wait(t_leap)
	if is_instance_valid(m):
		_crawl(m, 0.0)


## Salto: estaba a dos metros (Vitzo tras perseguirte, el Trainer) y salta hacia tu cara.
func _i_salto() -> void:
	var m := _killer_model()
	_place(m, 2.2, 0.0)
	_anim(m, ["run", "sprint"], 1.4)
	_aim_face(m, 0.05)
	_follow = 0.8
	await _wait(_t_grab * 0.3)
	if m == null:
		await _wait(_t_grab - _spent)
		return
	_anim(m, ["jumpscare_main", "jumpscare_alt"], 1.5)
	var t := maxf(_t_grab - _spent, 0.12)
	var start := m.global_position
	var end_flat := _eye() + (Vector3(start.x, 0, start.z) - Vector3(_eye().x, 0, _eye().z)).normalized() * (_grab_dist + 0.1)
	var end := Vector3(end_flat.x, _floor_y() + _drop_for(m), end_flat.z)
	var tw := _mtween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			m.global_position = start.lerp(end, u) + Vector3(0, sin(u * PI) * 0.7, 0)
			_face_cam(m), 0.0, 1.0, t)
	await _wait(t)


## Perrito RTA: la cámara cae al nivel del piso; el perro sale corriendo de debajo de los escritorios.
func _i_suelo() -> void:
	if _player != null:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_player.head, "position:y", 0.42, _t_grab * 0.3)
		tw.tween_property(_player.head, "rotation:x", -0.05, _t_grab * 0.3)
		tw.tween_property(_cam(), "rotation:z", deg_to_rad(-12.0), _t_grab * 0.3)
	_snd("sfx/lanyard_tintineo", 0.0)
	_snd("sfx/caida_cuerpo", -4.0)
	await _wait(_t_grab * 0.3)
	var m := _killer_model()
	_place(m, 2.4, 15.0)
	_anim(m, ["run"], 1.8)
	_rush(m, _grab_dist + 0.15, maxf(_t_grab - _spent, 0.1))
	_aim_face(m, 0.1)
	_follow = 0.7
	_snd("sfx/rta_ladrido", 0.0)
	await _wait(_t_grab - _spent)


## Perrito RTA (v0.3.1, muertes propias): miras al piso; viene bajo, arrastrándose pegado a la alfombra desde
## debajo de los escritorios, gruñendo, hasta tus pies.
func _i_acecho_suelo() -> void:
	# kills2 (susto de golpe): ya no acecha desde 3,4 m con el gruñido de aviso: está agazapado a un paso y, en lo que
	# dura el agarre, te salta al pecho mientras tu cabeza baja a él de un tirón.
	var m := _killer_model()
	_place(m, 1.25, 14.0)
	_anim(m, ["jumpscare_main", "run"], 1.8)
	if m != null:
		_turn_to(m.global_position + Vector3(0, 0.4, 0), minf(0.07, _t_grab * 0.7))
	_rush(m, 0.62, maxf(_t_grab - _spent - 0.01, 0.05))
	if _player != null and m != null:
		var tw := create_tween()
		tw.tween_method(func(_u: float) -> void:
			if is_instance_valid(m):
				_look_step(m, 0.25), 0.0, 1.0, maxf(_t_grab - _spent, 0.08))
	await _wait(_t_grab - _spent)


## Vitzo (recordatorio sin confirmar; v0.3.1 muertes propias): el monitor y la vista se llenan de ventanas de
## recordatorio, una encima de otra, hasta taparlo todo; él espera detrás.
func _i_popups() -> void:
	var world := get_tree().root.find_child("VitzoScreamer", true, false) as Node3D
	if world != null:
		world.visible = false
	var m := _killer_model()
	_place(m, 1.0, 0.0, -0.3)
	_face_cam(m)
	var n := 18 if not KillProps.light_mode() else 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var vp := get_viewport().get_visible_rect().size
	for i in n:
		var w := _window(KillProps.t("SCR_K_REMINDER_TITLE", "Recordatorio · Vitzo"), KillProps.t("SCR_K_REMINDER_BODY", "Confirma el recordatorio. Confírmalo. CONFÍRMALO."),
			Color(0.2, 0.85, 0.5), 460, 170)
		w.name = "Popup%d" % i
		w.offset_left += rng.randf_range(-vp.x * 0.38, vp.x * 0.38)
		w.offset_right = w.offset_left + 460
		w.offset_top += rng.randf_range(-vp.y * 0.38, vp.y * 0.38)
		w.offset_bottom = w.offset_top + 170
		w.scale = Vector2.ONE * 0.1
		w.visible = false
		var wr: WeakRef = weakref(w)
		var me: WeakRef = weakref(self)
		get_tree().create_timer(_t_grab * 0.85 * float(i) / n, true).timeout.connect(func() -> void:
			var fx: Screamers = me.get_ref()
			var pw: Panel = wr.get_ref()
			if fx == null or fx._done or pw == null:
				return
			pw.visible = true
			pw.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(pw, "scale", Vector2.ONE, 0.1)
			if i % 2 == 0:
				fx._snd("sfx/ww_popup", -4.0, 0.9 + 0.04 * (i % 5)))
	(last_info["props"] as Array).append("popups")
	_fx_goal = 0.3
	await _wait(_t_grab - _spent)


## Vitzo (POD; v0.3.1 muertes propias): se agacha y desaparece; la vista se queda en el borde del divisor del pod.
## Contraluz: detrás, los monitores del pod de enfrente; Vitzo sin luz propia sube a tirones (stop-motion) en
## silueta, la cabeza-pantalla asoma sobre el borde y se ladea. Después (KillMoves) las manos caen en tu escritorio.
func _i_divisor() -> void:
	var world := get_tree().root.find_child("VitzoScreamer", true, false) as Node3D
	if world != null:
		world.visible = false
	var e := _eye()
	var f := _dir(-50.0)  # a un costado: detrás de tus monitores no se vería
	var top_y := e.y - 0.12
	var div_root := Node3D.new()
	if _stage == null:
		_killer_model()
	_stage.add_child(div_root)
	KillProps.divider(div_root)
	div_root.global_position = Vector3(e.x, top_y - 0.31, e.z) + f * 0.85
	div_root.look_at(Vector3(e.x, div_root.global_position.y, e.z), Vector3.UP)
	(last_info["props"] as Array).append("divisor")
	# El contraluz: dos monitores encendidos del pod de enfrente y una luz fría entre ellos y Vitzo.
	var back := Node3D.new()
	back.name = "PodEnfrente"
	_stage.add_child(back)
	back.global_position = Vector3(e.x, top_y + 0.3, e.z) + f * 1.9
	back.look_at(Vector3(e.x, back.global_position.y, e.z), Vector3.UP)
	for sx in [-0.62, 0.0, 0.62]:
		KillProps.box(back, Vector3(0.6, 0.4, 0.03), Color(0.03, 0.03, 0.04), Vector3(sx, 0.0, 0.0))
		KillProps.box(back, Vector3(0.54, 0.33, 0.01), Color(0.55, 0.75, 0.95), Vector3(sx, 0.01, -0.02), 1.8)  # -Z mira hacia ti
	var rim := OmniLight3D.new()
	rim.name = "ContraluzDivisor"
	rim.light_color = Color(0.7, 0.86, 1.0)
	rim.light_energy = 3.2
	rim.omni_range = 0.9
	rim.shadow_enabled = false
	rim.set_meta("no_mood", true)
	_stage.add_child(rim)
	rim.global_position = Vector3(e.x, top_y + 0.3, e.z) + f * 1.45
	(last_info["props"] as Array).append("contraluz")
	var m := _killer_model()
	_place(m, 1.1, -50.0, -0.9)
	if m != null:
		m.global_position.y = top_y - 0.4 - _head_rel_y(m)  # v0.3.2 (1,8 m): la cabeza empieza bajo el borde
	_face_cam(m)
	if m != null:
		for c in m.get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).light_energy = 0.0  # silueta: sin su luz propia hasta que salta
	# Se corta la luz del piso (vuelve cuando sus manos caen en tu escritorio): solo quedan los monitores de atrás.
	if FloorBase.active != null:
		for n in FloorBase.active.find_children("*", "Light3D", true, false):
			var li := n as Light3D
			if li.visible and li.light_energy > 0.0:
				_lights_off.append([li, li.light_energy])
				li.light_energy *= 0.12
		gfx_dark(0.12)
	_clear_line([div_root.global_position + Vector3(0, 0.31, 0), back.global_position], 0.5)
	if _rig != null:
		_rig.arm_stretch = 1.0  # v0.3.2: estilo Q2 (brazos normales) en todas las de Vitzo
	_snd("sfx/parpadeo", -4.0)
	_breath()
	if _player != null:
		# La vista se queda en el borde del divisor (el borde un poco bajo el centro: arriba queda lugar para la cabeza).
		var edge := Vector3(div_root.global_position.x, top_y + 0.1, div_root.global_position.z)
		_turn_to(edge, _t_grab * 0.18)
	await _wait(_t_grab * 0.25)
	if _done or m == null:
		return
	# Sube a tirones (stop-motion robótico) hasta que la cabeza-pantalla entera asoma sobre el borde.
	var y0 := m.global_position.y
	var rise := (top_y + 0.19) - (y0 + _head_rel_y(m))
	var steps := 8
	var t_rise := (_t_grab * 0.7) - _spent
	for i in steps:
		var wm: WeakRef = weakref(m)
		var me: WeakRef = weakref(self)
		get_tree().create_timer(t_rise * float(i) / steps, true).timeout.connect(func() -> void:
			var fx: Screamers = me.get_ref()
			var mm: Node3D = wm.get_ref()
			if fx == null or fx._done or mm == null:
				return
			mm.global_position.y = y0 + rise * float(i + 1) / steps
			if i % 2 == 0:
				fx._snd("sfx/vitzo_arrastre_loop", -10.0, 1.6))
	_snd("voces/vitzo/vitzo_screamer_capa", -6.0)
	await _wait(_t_grab * 0.72 - _spent)
	if _done or m == null:
		return
	# Se asoma: ladea la cabeza sobre el borde, a saltos, y se inclina hacia ti.
	var lean := m.global_position - f * 0.08
	for i in 3:
		var wm2: WeakRef = weakref(m)
		var me2: WeakRef = weakref(self)
		get_tree().create_timer((_t_grab * 0.24) * float(i) / 3.0, true).timeout.connect(func() -> void:
			var fx: Screamers = me2.get_ref()
			var mm: Node3D = wm2.get_ref()
			if fx == null or fx._done or mm == null:
				return
			if fx._rig != null and is_instance_valid(fx._rig):
				fx._rig.head_tilt = 0.18 * float(i + 1)
			mm.global_position = mm.global_position.lerp(lean, 0.4)
			fx._snd("sfx/kill_teclas", -14.0, 2.2))
	await _wait(_t_grab - _spent)


## Esconde lo que tapa la línea de la vista a esos puntos (tus monitores, una silla): objetos chicos del piso
## cuya caja corta un segmento desde tus ojos, abierto `spread` m a cada lado. Se devuelven en _cleanup.
func _clear_line(points: Array, spread: float) -> void:
	if FloorBase.active == null:
		return
	var e := _eye()
	var segs: Array = []
	for pt in points:
		var side: Vector3 = ((pt as Vector3) - e).cross(Vector3.UP).normalized() * spread
		for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			segs.append([e, (pt as Vector3) + side * float(k)])
	for n in FloorBase.active.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.get_aabb()
		if bb.get_longest_axis_size() > 2.2:
			continue
		for sg in segs:
			if bb.intersects_segment(sg[0], sg[1]):
				mi.visible = false
				_hidden.append(mi)
				break


## Trainer (training reprobado): golpe en la mesa, la cara a medio metro, y se te tira encima.
func _i_pizarra() -> void:
	_snd("sfx/trainer_golpe", 0.0)
	_shake = 0.06
	_shake_goal = 0.01
	var m := _killer_model()
	_place(m, 1.0, 0.0)
	_aim_face(m, 0.08)
	_follow = 0.7
	_anim(m, ["bang_door", "point"], 1.6)
	await _wait(_t_grab * 0.5)
	_rush(m, _grab_dist + 0.15, maxf(_t_grab - _spent, 0.1))
	await _wait(_t_grab - _spent)


## Evento de Rasec: la música para de golpe; los agentes giran la cabeza hacia ti; Rasec con el micrófono.
func _i_evento() -> void:
	_start_music(str(row.get("musica", "musica/hold_kipupay_parlantes")))
	await _wait(_t_grab * 0.25)
	if _music != null:
		_music.stop()
	var e := _eye()
	for rig in get_tree().get_nodes_in_group("npcs") + _row_rigs():
		if rig is Node3D and (rig as Node3D).global_position.distance_to(e) < 25.0:
			var n := rig as Node3D
			_turned[n] = n.basis
			n.look_at(Vector3(e.x, n.global_position.y, e.z), Vector3.UP)
	_breath()
	await _wait(_t_grab * 0.25)
	var m := _killer_model()
	_place(m, 1.0, 0.0)
	_anim(m, ["karaoke", "point"], 1.3)
	_aim_face(m, 0.08)
	_follow = 0.7
	if m != null:
		Greybox.cylinder(m, "Microfono", Vector3(0.18, 1.35, -0.28), 0.025, 0.2, Greybox.NEGRO)
	_rush(m, _grab_dist + 0.2, maxf(_t_grab - _spent, 0.1))
	await _wait(_t_grab - _spent)


## Despido (3.er WW): las luces de la sala se apagan en fila hasta ti; en la oscuridad tu gafete se raja y Shero
## está ahí, iluminado desde abajo, acercándose despacio. Nada de ventanas blancas ni "ding".
func _i_cese() -> void:
	var lights := _room_lights()
	var n := lights.size()
	var span := _t_grab * 0.55
	for i in n:
		var l := lights[i] as Light3D
		var delay := span * float(i) / maxf(float(n), 1.0)
		var me: WeakRef = weakref(self)
		var wl: WeakRef = weakref(l)
		get_tree().create_timer(delay, true).timeout.connect(func() -> void:
			var fx: Screamers = me.get_ref()
			var li: Light3D = wl.get_ref()
			if fx == null or fx._done or li == null:
				return
			fx._lights_off.append([li, li.light_energy])
			li.light_energy = 0.0
			if i == n / 2:
				fx.gfx_dark(0.0)  # Media/Alta: el gestor de luces corta a mitad de la fila
			if i % 3 == 0:
				fx._snd("sfx/parpadeo", -6.0 - float(i % 5)))
	var dark := create_tween()
	dark.tween_property(_bg, "color", Color(0, 0, 0, 0.55), span)
	_breath()
	await _wait(span)
	if _done:
		return
	var badge := _badge()
	_snd("sfx/caida_cuerpo", -6.0, 1.6)
	await _wait(_t_grab * 0.15)
	if badge != null:
		badge.call("crack")
	_snd("sfx/trainer_golpe", -8.0, 1.5)
	var m := _killer_model()
	_place(m, 1.6, 0.0)
	_anim(m, ["stare_camera", "idle"], 0.8)
	_aim_face(m, 0.05)
	_follow = 0.8
	_rush(m, _grab_dist + 0.25, maxf(_t_grab - _spent, 0.1))
	await _wait(_t_grab - _spent)
	if badge != null:
		badge.visible = false


## Lunch dormido (2.ª siesta): abres los ojos en el sofá y está encima de ti, mirándote desde arriba.
func _i_dormido() -> void:
	_overhead = true
	_bg.color = Color(0, 0, 0, 1)
	if _player != null:
		# Sigues tendido en el sofá: la cámara baja y mira al techo.
		_player.head.position.y = 0.55
		_player.head.rotation.x = 1.0
		_cam_rest_pos = _player.camera.position
	var m := _killer_model()
	if m != null and _player != null:
		var cam := _player.camera
		var up := cam.global_transform.basis.y
		var f := -cam.global_transform.basis.z
		var head := cam.global_position + f * 0.7
		m.global_position = Vector3(head.x, head.y - _head_rel_y(m) + 0.15, head.z)
		_face_cam(m)
		_anim(m, ["hunch", "stare_camera"], 0.6)
		_aim_face(m, 0.05)
		_follow = 1.0
		var _u := up
	_breath()
	await _wait(_t_grab * 0.3)
	var tw := create_tween()
	tw.tween_property(_bg, "color", Color(0, 0, 0, 0.6), _t_grab * 0.2)
	tw.tween_property(_bg, "color", Color(0, 0, 0, 0.9), _t_grab * 0.1)
	tw.tween_property(_bg, "color", Color(0, 0, 0, 0.0), _t_grab * 0.2)
	await _wait(_t_grab - _spent)


# --- piezas 2D ------------------------------------------------------------------------------------

func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = c
	_root.add_child(r)
	return r


## Post-proceso del screamer (aberración cromática, desgarro, viñeta roja, grano) y capa de arriba (la frase).
func _make_fx() -> void:
	_top = CanvasLayer.new()
	_top.layer = 21
	_top.name = "ScreamerFx"
	add_child(_top)
	_fx = ColorRect.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.material = _fx_material(0.0, _soft)
	_top.add_child(_fx)


## Esconde la UI (PC acercada, HUD, feedback, menús) mientras dura: si no, tapa al modelo 3D.
func _hide_ui() -> void:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var l := n as CanvasLayer
		if l == self or l == _top or l.layer >= 19 or not l.visible or l.is_in_group(HOLD_GROUP):
			continue
		if l.name in ["Cinematica", "Subtitulos"]:
			continue
		l.visible = false
		_hidden_ui.append(l)
	# Sin pings de Ezlaki ni clics de UI encima del grito (C despido: sin «ding»).
	var ui := AudioServer.get_bus_index("UI")
	if ui >= 0 and not AudioServer.is_bus_mute(ui):
		AudioServer.set_bus_mute(ui, true)
		_ui_muted = true


func _face_tex(key: String) -> Texture2D:
	if key.begins_with("res://"):
		return Faces.texture_at(key)
	var t := Faces.texture_at(FACES_DIR + key + ".png")
	return t if t != null else Faces.texture(key)


## Destello subliminal de su cara 2D (2 fotogramas a 1/4 de opacidad) en el agarre.
func _flash_face(key: String) -> void:
	if key == "" or _soft:
		return
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture = _face_tex(key)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.modulate = Color(1, 1, 1, 0.0)
	face.material = _horror_material()
	face.name = "DestelloCara"
	_root.add_child(face)
	var tw := create_tween()
	tw.tween_property(face, "modulate", Color(1, 1, 1, 0.22), 0.04)
	tw.tween_property(face, "modulate", Color(1, 1, 1, 0.0), 0.1)


## Cara fantasma en el monitor apagado (reflejo): tenue y temblorosa.
func _ghost_face(key: String) -> TextureRect:
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture = _face_tex(key)
	face.set_anchors_preset(Control.PRESET_CENTER)
	face.offset_left = -260
	face.offset_top = -260
	face.offset_right = 260
	face.offset_bottom = 260
	face.modulate = Color(0.6, 0.7, 0.7, 0.0)
	face.material = _horror_material()
	_root.add_child(face)
	create_tween().tween_property(face, "modulate", Color(0.6, 0.7, 0.7, 0.3), _t_grab * 0.35)
	return face


func _horror_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float jitter = 1.0;
uniform float soft = 0.0;
float h(float x) { return fract(sin(x * 91.7) * 43758.5453); }
void fragment() {
	float tt = floor(TIME * 24.0);
	vec2 uv = UV;
	uv.x += (h(tt + floor(uv.y * 18.0)) - 0.5) * 0.025 * jitter * (1.0 - soft);
	uv.y = 0.5 + (uv.y - 0.5) * (0.92 + 0.08 * h(tt * 1.3));
	vec4 c = texture(TEXTURE, uv);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 mono = vec3(l) * vec3(0.82, 0.9, 0.8);
	vec3 g = mix(mono, c.rgb * vec3(1.15, 0.5, 0.45), smoothstep(0.3, 0.55, sat));
	g = clamp((g - 0.45) * 2.1 + 0.3, 0.0, 1.0);
	float r = length(UV - 0.5) * 2.0;
	g *= 1.0 - 0.7 * smoothstep(0.2, 0.95, r);
	g *= 0.85 + 0.15 * h(tt * 3.1);
	float mask = smoothstep(1.0, 0.62, r);
	COLOR = vec4(g, c.a * mask * COLOR.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("soft", 1.0 if _soft else 0.0)
	return m


## La frase gritada en pantalla (y el subtítulo): grande, roja, temblando.
func _shout(key: String, size: int = 82, color: Color = Color(0.95, 0.1, 0.08)) -> Label:
	if key == "":
		return null
	var txt := tr(key).replace("{pct}", detail if detail != "" else "61")
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v0.3.2e: la frase va ABAJO (pegada al borde inferior, crezca una o tres líneas), no en el tercio central: tapaba la
	# cara del asesino en las muertes donde queda baja (te levanta del cuello, de cabeza, en el piso). Antes su altura
	# dependía del largo del texto (la caja se medía antes de tener ancho y quedaba más arriba cuanto más larga).
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# v0.3.1: el ancho sigue a la ventana (a 1280 px «¡AMONESTACIÓN DISCIPLINARIA!» se cortaba en los bordes).
	var hw := minf(880.0, get_viewport().get_visible_rect().size.x * 0.47)
	l.offset_left = -hw
	l.offset_right = hw
	l.offset_bottom = -40
	l.offset_top = -40 - 340
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.pivot_offset = Vector2(hw, 280)
	l.scale = Vector2.ONE * 1.6
	_top.add_child(l)
	l.set_meta("base", l.position)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(l, "scale", Vector2.ONE, 0.14)
	_shout_label = l
	EventBus.subtitle.emit(killer, txt, 2.0)
	return l


## Ventana tipo app (Ezlaki Rooms, WW, lista del Mentor). Devuelve el panel.
func _window(title: String, body: String, accent: Color, w: float = 720.0, h: float = 420.0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1)
	sb.border_color = accent
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -w * 0.5
	p.offset_right = w * 0.5
	p.offset_top = -h * 0.5
	p.offset_bottom = h * 0.5
	p.pivot_offset = Vector2(w * 0.5, h * 0.5)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	var bar := ColorRect.new()
	bar.color = accent
	bar.size = Vector2(w, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	var tl := Label.new()
	tl.text = title
	tl.position = Vector2(16, 6)
	tl.add_theme_font_size_override("font_size", 24)
	tl.add_theme_color_override("font_color", Color(1, 1, 1))
	p.add_child(tl)
	var bl := Label.new()
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bl.offset_left = 24
	bl.offset_top = 64
	bl.offset_right = -24
	bl.offset_bottom = -16
	bl.clip_text = true
	bl.add_theme_font_size_override("font_size", 22)
	bl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.86))
	p.add_child(bl)
	return p


## Parpadeo de la luz mientras corre hacia ti (negros cortos, nunca blancos).
func _bg_flicker(t: float) -> void:
	if t <= 0.05:
		return
	var tw := create_tween()
	var steps := int(clampf(t / 0.12, 1.0, 8.0))
	for i in steps:
		tw.tween_property(_bg, "color", Color(0, 0, 0, 0.75 if i % 2 == 0 else 0.0), t / steps)
	tw.tween_property(_bg, "color", Color(0, 0, 0, 0.0), 0.02)


## La pantalla se raja (golpe de la cabina): líneas negras que salen del centro (v0.3.2b: con el vidrio rompiéndose).
func _crack() -> void:
	KillGore.glass(self, 0.0)
	var c := _Crack.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(c)


class _Crack extends Control:
	var _lines: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var sz := get_viewport_rect().size
		var c := sz * Vector2(0.5 + rng.randf_range(-0.05, 0.05), 0.45)
		for i in 14:
			var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
			var pts := PackedVector2Array([c])
			var p := c
			for j in 6:
				p += Vector2(cos(a), sin(a)) * rng.randf_range(40.0, 140.0)
				a += rng.randf_range(-0.35, 0.35)
				pts.append(p)
			_lines.append(pts)
		queue_redraw()

	func _draw() -> void:
		for pts in _lines:
			draw_polyline(pts, Color(0.02, 0.02, 0.02, 0.95), 5.0)
			draw_polyline(pts, Color(0.85, 0.85, 0.9, 0.35), 1.5)


## Gafete del despido: tu fotocheck en la oscuridad; crack() lo raja.
func _badge() -> Control:
	var b := _Badge.new()
	b.agent = GameState.agent
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -170
	b.offset_right = 170
	b.offset_top = -230
	b.offset_bottom = 230
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate = Color(1, 1, 1, 0)
	_root.add_child(b)
	create_tween().tween_property(b, "modulate", Color(0.75, 0.75, 0.75, 1), 0.2)
	return b


class _Badge extends Control:
	var agent: String = ""
	var cracked: bool = false

	func crack() -> void:
		cracked = true
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "rotation", -0.18, 0.08)
		tw.tween_property(self, "position:y", position.y + 40.0, 0.3)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.82, 0.83, 0.82))
		draw_rect(Rect2(0, 0, size.x, 70), Color(0.12, 0.13, 0.16))
		draw_rect(Rect2(size.x * 0.25, 100, size.x * 0.5, size.x * 0.5), Color(0.3, 0.3, 0.32))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(20, 46), "KONZENTRAMANCE", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 26, Color(0.85, 0.85, 0.85))
		draw_string(font, Vector2(20, size.y - 90), agent.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 40, Color(0.1, 0.1, 0.1))
		draw_string(font, Vector2(20, size.y - 40), "AGENTE", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 22, Color(0.3, 0.3, 0.3))
		if cracked:
			var c := size * Vector2(0.55, 0.45)
			var pts := [c + Vector2(-200, -260), c + Vector2(-30, -40), c + Vector2(20, 10), c + Vector2(-10, 80), c + Vector2(60, 300)]
			for i in pts.size() - 1:
				draw_line(pts[i], pts[i + 1], Color(0.05, 0.05, 0.05), 6.0)
			draw_line(c, c + Vector2(180, -120), Color(0.05, 0.05, 0.05), 4.0)
			draw_line(c + Vector2(20, 10), c + Vector2(-190, 60), Color(0.05, 0.05, 0.05), 4.0)
			draw_rect(Rect2(0, 0, size.x, size.y), Color(0.4, 0.0, 0.0, 0.25))


# --- audio ----------------------------------------------------------------------------------------

## v0.3.2b: capas que se suman solas a ciertos golpes (todas las muertes): el monitor/vidrio suma el estallido de
## vidrio en capas; las teclas y la mesa, el golpe del tablero y la bandeja; el papel y el lanyard, la tela.
const LAYER: Dictionary = {"sfx/monitor_rompe": "glass", "sfx/kill_vidrio": "glass", "sfx/kill_teclas": "sfx/kill_mesa_01",
	"sfx/kill_papel_golpe": "sfx/kill_tela", "sfx/lanyard_tintineo": "sfx/kill_tela", "sfx/caida_cuerpo": "sfx/kill_tela"}


## Reproduce un slot con un reproductor propio (sin pitidos: si falta, no suena).
func _snd(slot: String, db: float = 0.0, pitch: float = 1.0, from: float = 0.0) -> AudioStreamPlayer:
	if LAYER.has(slot):
		var lay := str(LAYER[slot])
		if lay == "glass":
			KillGore.glass(self, db)
		else:
			_snd(lay, db - 2.0, pitch)
	var path := AudioManager.voice_path(slot) if slot.begins_with("voces/") else AudioManager.resolve(slot)
	if path == "":
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	ap.bus = _bus_for(slot)
	ap.volume_db = db
	ap.pitch_scale = pitch
	add_child(ap)
	ap.play(maxf(from, 0.0))
	ap.finished.connect(ap.queue_free)
	_audio.append(ap)
	return ap


## Bus de cada sonido del screamer: los efectos (sfx/) van al bus con el agache bajo la voz y el limitador; las
## voces, al de la voz (la cadena lateral). Sin los buses (pruebas sin audio), «Sala».
func _bus_for(slot: String) -> String:
	var b := KillGore.BUS_SFX if slot.begins_with("sfx/") else (KillGore.BUS_VOZ if slot.begins_with("voces/") else "Sala")
	if slot == "sfx/vitzo_salto":
		# El golpe del salto de Vitzo (Q2) va directo a Master por su bus: sin el agache ni el limitador de efectos, y
		# entero mientras lo demás se calla un instante (KillGore.hit_dip).
		KillGore.sync_golpe()
		b = KillGore.BUS_GOLPE if AudioServer.get_bus_index(KillGore.BUS_GOLPE) >= 0 else "Sala"
	if slot.contains("/dolor_") or slot.contains("fusion_protesta"):
		b = KillGore.BUS_SFX  # tus gritos de dolor van debajo de la frase del asesino (agache en cadena lateral)
	return b if AudioServer.get_bus_index(b) >= 0 else "Sala"


func _stop_audio(fade: float) -> void:
	for ap in _audio:
		if is_instance_valid(ap) and ap.playing:
			var tw := create_tween()
			tw.tween_property(ap, "volume_db", -60.0, fade)
	_audio.clear()


## v0.3.2: elige la toma al empezar (tres por slot, al azar) y mide su largo; "frase_rep" = veces que la grita
## (Haime: «¡EMPATÍAAAA! ¡EMPATÍAAAA!»).
func _pick_voice() -> void:
	var slot := str(row.get("frase", ""))
	_take_path = _voice_take(slot) if slot != "" else ""
	_take_len = 0.0
	if _take_path != "":
		var st := load(_take_path) as AudioStream
		if st != null:
			_take_len = st.get_length()


const REP_GAP := 0.08
## v0.3.2c: dónde cae el GOLPE fuerte dentro del archivo de la frase (s). Hasta ahora ~0,11 s (HIT_BASE): la voz
## arranca en el instante del grito y el golpe visual coincide. Una toma con el golpe más adentro (las tomas nuevas
## del Trainer traen una subida en reversa: 0,22-0,34 s) declara "frase_golpe_s" en su fila de data/screamers.json
## (un número o una lista por toma _01.._03) y la voz arranca ese tanto ANTES del grito: el golpe del audio cae en
## el golpe de la imagen.
const HIT_BASE := 0.11
var _voice_started: bool = false


## Largo total de la frase gritada (todas sus repeticiones).
func voice_total() -> float:
	var rep_n := maxi(1, int(row.get("frase_rep", 1)))
	return _take_len * rep_n + REP_GAP * (rep_n - 1) if _take_len > 0.0 else 0.0


## Segundo del golpe dentro de la toma elegida ("frase_golpe_s" de la fila; por defecto HIT_BASE).
func voice_hit_s() -> float:
	var v: Variant = row.get("frase_golpe_s", HIT_BASE)
	if v is Array:
		var arr := v as Array
		var n := maxi(_take_path.get_basename().right(2).to_int(), 1)  # …_01 / _02 / _03
		return float(arr[clampi(n - 1, 0, arr.size() - 1)]) if not arr.is_empty() else HIT_BASE
	return float(v)


## Cuánto antes del grito tiene que arrancar la voz para que su golpe caiga en el golpe de la imagen.
func voice_lead() -> float:
	return clampf(voice_hit_s() - HIT_BASE, 0.0, 0.8) if _take_path != "" else 0.0


## Arranca la voz `delay` s después (KillMoves: el instante del grito menos voice_lead()).
func prestart_voice(delay: float) -> void:
	var me: WeakRef = weakref(self)
	get_tree().create_timer(maxf(delay, 0.0), true).timeout.connect(func() -> void:
		var f: Screamers = me.get_ref()
		if f != null and not f._done and not f._voice_started:
			f.last_info["voz_adelanto_s"] = f.voice_lead()
			f.last_info["voz_inicio_s"] = f._clock
			f._play_take())


## La toma elegida (todas sus repeticiones). Una sola vez por screamer.
func _play_take() -> bool:
	if _take_path == "" or _voice_started:
		return _voice_started
	_voice_started = true
	var path := _take_path
	var rep_n := maxi(1, int(row.get("frase_rep", 1)))
	for i in rep_n:
		var ap := AudioStreamPlayer.new()
		ap.stream = load(path) as AudioStream
		ap.bus = _bus_for("voces/")
		# +3 dB: medido en clip (v0.3.2d), con el limitador de Master la frase queda ~1 dB bajo el nivel del archivo. Un
		# limitador propio con pre-ganancia en el bus de la voz se probó y la dejaba 0,9 dB MÁS baja (el limitador de
		# Godot reduce la ganancia sostenida, no densifica): no se usa.
		ap.volume_db = 3.0 if i == 0 else 4.0
		add_child(ap)
		if i == 0:
			ap.play()
		else:
			var wr: WeakRef = weakref(ap)
			get_tree().create_timer((_take_len + REP_GAP) * i, true).timeout.connect(func() -> void:
				var a: AudioStreamPlayer = wr.get_ref()
				if a != null and not _done:
					a.pitch_scale = 1.04
					a.play())
		_audio.append(ap)
	last_info["frase_path"] = path
	last_info["frase_s"] = voice_total()
	return true


## La frase gritada (la toma elegida al empezar) con el aullido debajo.
func _scream_voice() -> void:
	var played := _play_take()
	if not played:
		for key in ["voz", "voz_respaldo"]:
			var v := str(row.get(key, ""))
			if v != "" and v.contains("/") and _snd("voces/" + v, 2.0) != null:
				played = true
				break
	if not _stinger_done:
		AudioManager.play_sting()
	var capa := str(row.get("capa", ""))
	if capa != "":
		_snd(capa, -2.0)


## Una toma de la frase: voces/<slug>/scr_grito_<id>_01..03 (EN en en/ si existe).
func _voice_take(slot: String) -> String:
	var takes: Array[String] = []
	for i in range(1, 4):
		var s := "%s_%02d" % [slot, i]
		var p := AudioManager.voice_path(s)
		if p != "":
			takes.append(p)
	if takes.is_empty():
		return AudioManager.voice_path(slot)
	return takes[randi() % takes.size()]


func _breath() -> void:
	_snd("sfx/respiracion", -3.0, 0.85)


## Pasos del asesino que corre (pasos intensos si existen; si no, los de alfombra más graves).
func _snd_steps(_delay: float) -> void:
	if _snd("sfx/shero_pasos_intensos", 0.0) == null:
		_snd("sfx/shero_corre_acerca", 0.0)


# --- piezas 3D ------------------------------------------------------------------------------------

func _cam() -> Camera3D:
	return _player.camera if _player != null else null


func _eye() -> Vector3:
	return _cam().global_position if _cam() != null else Vector3.ZERO


func _floor_y() -> float:
	return _player.global_position.y if _player != null else 0.0


## Dirección horizontal a la que mira la cámara, girada yaw_off grados.
func _dir(yaw_off: float = 0.0) -> Vector3:
	if _cam() == null:
		return Vector3.FORWARD
	var f := -_cam().global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3.FORWARD
	return f.normalized().rotated(Vector3.UP, deg_to_rad(yaw_off))


## Tween de movimiento del asesino: mata al anterior (si no, la carrera y el agarre peleaban por la posición y
## la cámara terminaba mirando al techo).
func _mtween() -> Tween:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	return _move_tw


func _killer_model() -> Node3D:
	if _m != null and is_instance_valid(_m):
		return _m
	_m = _model(str(row.get("modelo", _default_model())), str(row.get("look", "")))
	return _m


func _default_model() -> String:
	match killer:
		"rta":
			return "perrito_rta"
		"guardia":
			return "guardia_fermin"
		"cliente":
			return "shero"
	return killer


## Modelo del asesino (GLB v2, con ScreamRig) frente a la cámara.
func _model(slug: String, look: String = "") -> Node3D:
	if _player == null:
		return null
	if slug == "shero":
		look = "calvo"  # S 13:28: Shero mata siempre calvo
	if _stage == null:
		_stage = Node3D.new()
		_stage.name = "EscenarioScreamer"
		_player.get_parent().add_child(_stage)
	var path := _model_path(slug)
	var root := Node3D.new()
	root.name = "Asesino_" + slug
	_stage.add_child(root)
	var scene: Node3D = null
	if path != "":
		var packed: PackedScene = null
		if packed == null:
			packed = load(path) as PackedScene
		if packed != null:
			scene = packed.instantiate() as Node3D
	if scene == null:
		Greybox.box(root, "Silueta", Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.3), Color(0.02, 0.02, 0.02), false)
		Greybox.box(root, "Ojos", Vector3(0, 1.62, -0.16), Vector3(0.22, 0.03, 0.01), Color(0.9, 0.1, 0.08), false, 4.0)
	else:
		root.add_child(scene)
		scene.rotation_degrees.y = 180.0  # los GLB miran a +Z
		var h := _height_of(scene)
		if h > 0.01:
			scene.scale = Vector3.ONE * (float(HEIGHTS.get(slug, 1.8)) / h)
		for m in scene.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_look(scene, look)
		KillGore.gfx("GfxCharacters", "dress", [scene])  # en Media/Alta: el mismo acabado que los personajes del piso (antes de ScreamRig: la cara la lleva su shader)
		for c in scene.find_children("*", "AnimationPlayer", true, false):
			root.set_meta("anim", c)
		root.set_meta("scene", scene)
		root.set_meta("slug", slug)
		_has_model = true
		if slug == "vitzo":
			VitzoGlitch.apply(scene)
			VitzoGlitch.ramp(scene, 0.4, 1.0, seconds * 0.7)
		if slug == "guardia_fermin":
			_flashlight(scene)
		var sr := ScreamRig.attach(scene, slug)
		if sr != null:
			sr.soft = _soft
			if root == _m or _m == null:
				_rig = sr
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0.35, -0.6)
	var lc: Array = LIGHTS.get(slug, [Color(0.85, 0.95, 0.85), 2.4])
	l.light_color = lc[0]
	l.light_energy = float(lc[1])
	l.omni_range = 3.2
	l.shadow_enabled = false
	l.set_meta("no_mood", true)
	if slug == "grasa":
		l.position = Vector3(0, 1.1, -0.7)
		l.omni_range = 4.2
	root.add_child(l)
	if slug == "haime":
		# Su luz roja la deja en silueta: una luz enferma desde abajo le saca la cara (ojos, boca rajada).
		var f := OmniLight3D.new()
		f.position = Vector3(0, float(HEIGHTS.get(slug, 1.75)) * 0.78, -0.45)
		f.light_color = Color(1.0, 0.86, 0.8)
		f.light_energy = 1.2  # v0.3.1: 1,9 en la beta; con la luz de cara suave de abajo la cara salía quemada
		f.omni_range = 1.8
		f.shadow_enabled = false
		f.set_meta("no_mood", true)
		root.add_child(f)
		# v0.3.1 (muertes propias; pedido de integración): luz suave de frente que sigue a la cámara, como el brillo
		# de un monitor: la cara de Haime (ojos, boca, el headset con el REC) se lee sin perder la luz roja de atrás.
		_face_light = OmniLight3D.new()
		_face_light.name = "LuzCaraSuave"
		_face_light.light_color = Color(1.0, 0.92, 0.86)
		_face_light.light_energy = 0.7
		_face_light.omni_range = 1.2
		_face_light.omni_attenuation = 1.6
		_face_light.shadow_enabled = false
		_face_light.set_meta("no_mood", true)
		_stage.add_child(_face_light)
	if slug == "grasa" or slug == "guardia_fermin":
		# v0.3.2e (agarre genérico): la luz propia de GRASA queda 1,6 m por debajo de su cara (mide 2,6 m) y la linterna
		# de Don Fermín te apunta a ti: cuando la sala se apaga en el grito, la cara (piel sin brillo propio, dentro de la
		# capucha / bajo la gorra) quedaba casi negra. La misma luz suave de frente de Haime.
		_face_light = OmniLight3D.new()
		_face_light.name = "LuzCaraSuave"
		_face_light.light_color = Color(0.9, 0.94, 1.0)
		_face_light.light_energy = 1.1 if slug == "grasa" else 0.9
		_face_light.omni_range = 1.5
		_face_light.omni_attenuation = 1.4
		_face_light.shadow_enabled = false
		_face_light.set_meta("no_mood", true)
		_stage.add_child(_face_light)
	_hide_world_killer(slug)
	return root


## Esconde la versión del mundo del asesino (Shero en su sitio, el cazador que te alcanzó, el actor de P5 cerca).
func _hide_world_killer(slug: String) -> void:
	var nodes: Array = []
	if slug == "shero":
		nodes += get_tree().get_nodes_in_group("shero")
	var hn := Pursuit.node_of(killer)
	if hn != null:
		nodes.append(hn)
	var e := _eye()
	for a in get_tree().get_nodes_in_group("p5_actor_" + slug):
		nodes.append(a)
	var fl := FloorBase.active
	if fl != null:
		for a in fl.find_children("*", "P5Actor", true, false):
			if (a as P5Actor).slug == slug and (a as Node3D).global_position.distance_to(e) < 9.0:
				nodes.append(a)
	for n in nodes:
		if n is Node3D and (n as Node3D).visible and not (_stage != null and _stage.is_ancestor_of(n)):
			(n as Node3D).visible = false
			_hidden.append(n as Node3D)


## Linterna de Don Fermín: SpotLight colgado del hueso de la mano derecha que te apunta.
func _flashlight(scene: Node3D) -> void:
	var sk: Skeleton3D = null
	for c in scene.find_children("*", "Skeleton3D", true, false):
		sk = c
	if sk == null or sk.find_bone("hand_r") < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.name = "ManoLinterna"
	ba.bone_name = "hand_r"
	sk.add_child(ba)
	var aim := _Aim.new()
	aim.name = "Linterna"
	aim.cam = _cam()
	ba.add_child(aim)
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.96, 0.82)
	sp.light_energy = 6.0 if not _soft else 2.5
	sp.spot_range = 4.0
	sp.spot_angle = 22.0
	sp.shadow_enabled = false
	aim.add_child(sp)


class _Aim extends Node3D:
	var cam: Camera3D = null

	func _process(_d: float) -> void:
		if cam != null and is_instance_valid(cam) and global_position.distance_to(cam.global_position) > 0.05:
			look_at(cam.global_position, Vector3.UP)


## Cabina de DJ de Rasec (prop): mueble negro con platos, perillas encendidas y parlantes.
func _dj_booth() -> Node3D:
	if _stage == null:
		return null
	var b := Node3D.new()
	b.name = "CabinaDJ"
	_stage.add_child(b)
	var path := "res://assets/models/rasec_dj_booth.glb"
	if ResourceLoader.exists(path):
		var sc := (load(path) as PackedScene).instantiate() as Node3D
		b.add_child(sc)
	else:
		Greybox.box(b, "Mueble", Vector3(0, 0, 0), Vector3(1.0, 0.42, 0.5), Color(0.05, 0.05, 0.06), false)
		Greybox.box(b, "Tapa", Vector3(0, 0.22, 0), Vector3(1.04, 0.03, 0.54), Color(0.12, 0.12, 0.14), false)
		for sx in [-0.27, 0.27]:
			Greybox.cylinder(b, "Plato%d" % int(sx * 100), Vector3(sx, 0.245, 0), 0.15, 0.02, Color(0.08, 0.08, 0.09))
			Greybox.box(b, "Luz%d" % int(sx * 100), Vector3(sx, 0.26, 0), Vector3(0.06, 0.005, 0.06), Color(1.0, 0.2, 0.6), false, 3.0)
		for i in 6:
			Greybox.box(b, "Perilla%d" % i, Vector3(-0.1 + i * 0.04, 0.25, 0.18), Vector3(0.02, 0.02, 0.02), [Color(0.2, 0.6, 1.0), Color(1, 0.3, 0.7)][i % 2], false, 2.5)
		Greybox.box(b, "Frente", Vector3(0, 0, 0.26), Vector3(0.9, 0.3, 0.01), Color(0.6, 0.1, 0.5), false, 1.6)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.3, 0.7)
		l.light_energy = 1.4
		l.omni_range = 1.6
		l.position = Vector3(0, 0.4, 0.3)
		b.add_child(l)
	return b


## Looks: "calvo" oculta el nodo Afro (Shero v2); "pelo" muestra el nodo Pelo (Rasec v2), "" lo oculta.
func _apply_look(scene: Node3D, look: String) -> void:
	var afro := scene.find_child("Afro", true, false) as Node3D
	if afro != null:
		afro.visible = look != "calvo"
	var pelo := scene.find_child("Pelo", true, false) as Node3D
	if pelo != null:
		pelo.visible = look == "pelo"


func _height_of(scene: Node3D) -> float:
	var top := -INF
	var bottom := INF
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		var xf := scene.global_transform.affine_inverse() * mi.global_transform
		for corner in [aabb.position, aabb.end]:
			var p: Vector3 = xf * corner
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
	return top - bottom if top > bottom else 0.0


func _anim(m: Node3D, names: Array, speed: float = 1.0) -> void:
	if m == null or not m.has_meta("anim"):
		return
	var ap := m.get_meta("anim") as AnimationPlayer
	for n in names:
		if ap.has_animation(str(n)):
			var once := str(n).begins_with("jumpscare") or str(n) in ["point", "throw", "bang_door", "scream"]
			ap.get_animation(str(n)).loop_mode = Animation.LOOP_NONE if once else Animation.LOOP_LINEAR
			ap.play(str(n), 0.08, speed)
			return


## kills2 — gancho con el paquete de animación (rama v0.3.2-fb-anim): si existe la biblioteca de persecución del
## cazador (res://assets/anim/<modelo>_chase.res, biblioteca «c32»), la copia del screamer arranca en la MISMA pose en
## que lo viste alcanzarte («c32/chase_close»: Shero inclinado con el memo, el Trainer con los brazos a tu cara, Vitzo
## alzado de cuatro patas, el Perrito en galope tendido), sin salto de pose. Sin la biblioteca (esta rama): false y sigue
## con «sprint»/«run» como siempre.
func _chase_pose(m: Node3D, speed: float = 1.0) -> bool:
	if m == null or not is_instance_valid(m) or not m.has_meta("anim"):
		return false
	var ap := m.get_meta("anim") as AnimationPlayer
	if ap == null:
		return false
	if not ap.has_animation_library("c32"):
		var path := "res://assets/anim/%s_chase.res" % str(m.get_meta("slug", ""))
		if not ResourceLoader.exists(path):
			return false
		var lib := load(path) as AnimationLibrary
		if lib == null:
			return false
		ap.add_animation_library("c32", lib)
	if not ap.has_animation("c32/chase_close"):
		return false
	ap.play("c32/chase_close", 0.0, speed)
	last_info["pose_alcance"] = "c32/chase_close"
	return true


## Altura de la cabeza sobre los pies del modelo (m).
func _head_rel_y(m: Node3D) -> float:
	return _head_point(m).y - m.global_position.y


## Lleva la cara del asesino a `dist` m de tus ojos por la línea en que la ves (para cuando estás tendido y la
## cara viene de arriba: no se baja a la altura de los ojos como al estar sentado o de pie).
func _face_toward_eye(m: Node3D, dist: float, t: float) -> void:
	if m == null or not is_instance_valid(m):
		return
	var e := _eye()
	var hp := _head_point(m)
	var d := hp - e
	if d.length() < 0.01:
		return
	var target := m.global_position + (e + d.normalized() * dist - hp)
	var tw := _mtween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "global_position", target, maxf(t, 0.02))


## Distancia de la raíz del modelo a tu cámara para que su cara quede a `face_m` (la cara va adelantada a la raíz
## lo que se incline: Shero agachado, el Perrito estirado).
func _root_dist_for_face(face_m: float) -> float:
	if _m == null or not is_instance_valid(_m):
		return face_m
	var e := _eye()
	var r := _m.global_position
	var to_cam := Vector3(e.x - r.x, 0.0, e.z - r.z)
	if to_cam.length() < 0.01:
		return face_m
	var f := _head_point(_m)
	var lead := Vector3(f.x - r.x, 0.0, f.z - r.z).dot(to_cam.normalized())
	return face_m + lead


## Cuánto bajar al asesino para que su cara quede a la altura de tus ojos (se agacha sobre ti).
func _drop_for(m: Node3D) -> float:
	return (_eye().y - _floor_y()) - _head_rel_y(m) + 0.04


## Coloca el modelo a `dist` m de la cámara (yaw_off grados desde donde mira), en el suelo, mirándote.
func _place(m: Node3D, dist: float, yaw_off: float = 0.0, y_off: float = 0.0) -> void:
	if m == null:
		return
	var p := _eye() + _dir(yaw_off) * dist
	m.global_position = Vector3(p.x, _floor_y() + y_off, p.z)
	_face_cam(m)


func _face_cam(m: Node3D) -> void:
	var e := _eye()
	var to := Vector3(e.x, m.global_position.y, e.z)
	if to.distance_to(m.global_position) > 0.05:
		m.look_at(to, Vector3.UP)


## Corre hasta quedar a `dist` m de la cámara.
func _rush(m: Node3D, dist: float, t: float) -> void:
	if m == null:
		return
	var e := _eye()
	var flat := Vector3(m.global_position.x, 0, m.global_position.z) - Vector3(e.x, 0, e.z)
	if flat.length() < 0.01:
		flat = -_dir(0.0)
	var target := Vector3(e.x, m.global_position.y, e.z) + flat.normalized() * dist
	var tw := _mtween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "global_position", target, maxf(t, 0.02))


## Se acerca a `dist` m de la cámara con la cara a la altura de tus ojos (agarre/embestida).
func _approach(m: Node3D, dist: float, t: float) -> void:
	if m == null or not is_instance_valid(m):
		return
	var e := _eye()
	var flat := Vector3(m.global_position.x, 0, m.global_position.z) - Vector3(e.x, 0, e.z)
	if flat.length() < 0.01:
		flat = -_dir(0.0)
	var target_xz := Vector3(e.x, 0, e.z) + flat.normalized() * dist
	var target := Vector3(target_xz.x, _floor_y() + _drop_for(m), target_xz.z)
	var tw := _mtween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "global_position", target, maxf(t, 0.02))
	tw.parallel().tween_method(func(_u: float) -> void:
		if is_instance_valid(m):
			_face_cam(m), 0.0, 1.0, maxf(t, 0.02))


## Gira la cámara hacia un punto (giro forzado).
func _turn_to(point: Vector3, t: float) -> void:
	if _player == null:
		return
	var e := _eye()
	var to := point - e
	var yaw := atan2(-to.x, -to.z)
	var cur := _player.rotation.y
	yaw = cur + wrapf(yaw - cur, -PI, PI)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.2)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_player, "rotation:y", yaw, maxf(t, 0.02))
	tw.tween_property(_player.head, "rotation:x", pitch, maxf(t, 0.02))


## Mira a la cara del asesino (sigue el hueso de la cabeza cada fotograma).
func _aim_face(m: Node3D, t: float) -> void:
	if m == null or _player == null:
		return
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void: _look_step(m, lerpf(0.12, 1.0, k * k)), 0.0, 1.0, maxf(t, 0.01))


## Punto entre los ojos del asesino: hueso "head" del rig v2 (+8 cm), o el 90 % de su altura.
func _head_point(m: Node3D) -> Vector3:
	# Con la cara deformable: el centro de la cara (ojos-boca) con el cuello estirado, para que la boca abierta
	# quede en cuadro y no mires hacia arriba a la frente.
	if m == _m and _rig != null and is_instance_valid(_rig) and _rig.last_face != Vector3.INF:
		return _rig.last_face
	if not m.has_meta("head_bone"):
		var found := [null, -1]
		for c in m.find_children("*", "Skeleton3D", true, false):
			var idx := (c as Skeleton3D).find_bone("head")
			if idx >= 0:
				found = [c, idx]
		m.set_meta("head_bone", found)
	var hb: Array = m.get_meta("head_bone")
	var sk := hb[0] as Skeleton3D
	if sk != null and is_instance_valid(sk):
		if str(m.get_meta("slug", "")) == "vitzo":
			# Su cara es la pantalla: el centro de la caja de la cabeza queda 0,2 (unidades del GLB) sobre el hueso, que
			# está en el cuello. Con el hueso + 6 cm se encuadraba el borde de abajo de la pantalla (v0.3.2d).
			return sk.global_transform * (sk.get_bone_global_pose(int(hb[1])) * VITZO_FACE_LOCAL)
		return sk.global_transform * (sk.get_bone_global_pose(int(hb[1])).origin) + Vector3(0, 0.06, 0)
	var slug := str(m.name).trim_prefix("Asesino_")
	return m.global_position + Vector3(0, float(HEIGHTS.get(slug, 1.8)) * 0.9, 0)


func _look_step(m: Node3D, w: float) -> void:
	if _player == null or not is_instance_valid(m) or not is_instance_valid(_player):
		return
	var to := _head_point(m) - _eye()
	if to.length() < 0.05:
		return
	var yaw := atan2(-to.x, -to.z)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.2)
	_player.rotation.y = lerp_angle(_player.rotation.y, yaw, w)
	_player.head.rotation.x = lerpf(_player.head.rotation.x, pitch, w)


func _yaw_by(deg: float, t: float) -> void:
	if _player == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_player, "rotation:y", _player.rotation.y + deg_to_rad(deg), maxf(t, 0.02))


func _head_y() -> float:
	return _player.head.position.y if _player != null else 1.6


## Luces del piso cercanas, de la más lejana a la más cercana (el despido las apaga en fila hacia ti).
func _room_lights() -> Array:
	var out: Array = []
	var fl := FloorBase.active
	if fl == null:
		return out
	var e := _eye()
	for l in fl.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		if li is DirectionalLight3D or not li.visible or li.light_energy <= 0.01:
			continue
		var d := li.global_position.distance_to(e)
		if d < 26.0:
			out.append([d, li])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var lights: Array = []
	for p in out:
		lights.append(p[1])
	return lights


func _row_rigs() -> Array:
	var out: Array = []
	var fl := FloorBase.active
	if fl == null:
		return out
	for c in fl.find_children("Rig_*", "Node3D", true, false):
		out.append(c)
	return out

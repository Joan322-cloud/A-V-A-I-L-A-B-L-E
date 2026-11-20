class_name KillGore
extends RefCounted
## Capa gráfica y sonora de las muertes (v0.3.2, pedido de Joan: «muchísimo más estruendosos… mucho más grotescas
## las animaciones con las cosas explícitas que pedí, pues será un juego 14+»). La usan fx/kill_moves.gd y
## fx/screamers.gd. Clasificación 14+: sangre, moretones, heridas, piel rasgada, huesos que crujen; sin
## desmembramiento (lo de ojos, orejas y brazos es «intermedio»: evidencia breve y parcial y corte en el pico) y sin
## contenido sexual.
##   · Opciones → «Contenido gráfico: Normal / Reducido» (setting "contenido_grafico"). Reducido quita la sangre, las
##     heridas, los moretones y los crujidos de hueso; el susto queda (la cara deforme, los golpes, el grito, los
##     cortes a negro).
##   · Sonido: bus «ScreamerSFX» (todo sfx/ del screamer) con compresor en cadena lateral desde «ScreamerVoz» (la
##     frase gritada): el golpe se aparta bajo la voz y la frase se entiende; un limitador duro (techo -1 dBFS) con
##     preganancia hace el pico corto. Capa de impacto: sfx/kill_impacto_*, kill_slam_*, kill_hueso_*, kill_gore_*,
##     kill_rugido, kill_chillido (tools/k2_audio, pico verdadero ≤ -1 dBTP).
##   · Modo liviano / Baja: la mitad de las gotas y manchas planas en la cara (sin el ruido del shader).

const SETTING := "contenido_grafico"
const BUS_SFX := "ScreamerSFX"
const BUS_VOZ := "ScreamerVoz"
const BUS_GOLPE := "ScreamerGolpe"
const BLOOD := Color(0.36, 0.0, 0.015, 0.92)
const BLOOD_DARK := Color(0.16, 0.0, 0.0, 0.95)
## Tono de piel de las manos de cada agente (models_v2: los mismos que su rig).
const SKIN: Dictionary = {"Jiroshi": Color(0.86, 0.7, 0.56), "Marko": Color(0.78, 0.6, 0.46), "Llauri": Color(0.88, 0.72, 0.6),
	"Ttoom": Color(0.62, 0.45, 0.32), "Juan": Color(0.74, 0.56, 0.42)}


## Sonidos de la capa de impacto (se cargan en segundo plano al cargar el piso: Screamers.prewarm).
const PREWARM_SFX: Array[String] = ["sfx/kill_impacto_01", "sfx/kill_impacto_02", "sfx/kill_impacto_03", "sfx/kill_impacto_04",
	"sfx/kill_slam_01", "sfx/kill_slam_02", "sfx/kill_hueso_01", "sfx/kill_hueso_02", "sfx/kill_hueso_03", "sfx/kill_gore_01",
	"sfx/kill_gore_02", "sfx/kill_gore_03", "sfx/kill_rugido", "sfx/kill_chillido", "sfx/latido_rapido_loop",
	"sfx/kill_vidrio_rompe_01", "sfx/kill_vidrio_rompe_02", "sfx/kill_vidrio_rompe_03", "sfx/kill_mesa_01", "sfx/kill_tela", "sfx/vitzo_salto"]
static var _warm: bool = false
static var _skin_shader: Shader = null


static func prewarm() -> void:
	_warm = true
	ensure_buses()  # al cargar el piso (no a mitad del primer screamer)
	var all: Array[String] = PREWARM_SFX.duplicate()
	if GameState.agent != "":
		for i in range(1, 5):
			all.append("voces/agentes/dolor_%s_%02d" % [GameState.agent.to_lower(), i])
	for s in all:
		request(AudioManager.voice_path(s) if s.begins_with("voces/") else AudioManager.resolve(s, false))
	_skin_mat(Color.WHITE, true)


## Carga en segundo plano segura (v0.3.2, el cuelgue «propagate_notification from a non-main thread» en el almuerzo):
## en el hilo de trabajo SOLO corre ResourceLoader (nada de nodos, add_child, señales ni propiedades del árbol);
## cada ruta se pide una sola vez (no se repide la que ya está en caché o en camino, aunque el piso se recargue o haya
## un contacto activo), y la recoge el hilo principal (un temporizador del SceneTree llama a load_threaded_get) y la
## retiene, así ninguna carga queda colgada. Si se llama fuera del hilo principal, se difiere al principal.
static var _req: Dictionary = {}  # ruta → pedida, aún sin recoger
static var _held: Dictionary = {}  # ruta → recurso ya cargado (retenido)
static var _reaping: bool = false
static var _asked: Dictionary = {}  # ruta → veces pedida al hilo (debe ser 1)


static func request(p: String) -> void:
	if p == "":
		return
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		KillGore.request.call_deferred(p)
		return
	if _req.has(p) or _held.has(p):
		return
	if ResourceLoader.has_cached(p):
		_held[p] = ResourceLoader.load(p)  # ya está: solo se retiene (sin hilo)
		return
	if ResourceLoader.load_threaded_request(p) != OK:
		return
	_asked[p] = int(_asked.get(p, 0)) + 1
	_req[p] = true
	_arm_reaper()


static func pending() -> int:
	return _req.size()


static func _arm_reaper() -> void:
	if _reaping:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_reaping = true
	tree.create_timer(0.2, true, false, true).timeout.connect(KillGore._reap)


static func _reap() -> void:
	_reaping = false
	for p in _req.keys():
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_held[p] = ResourceLoader.load_threaded_get(p)
			_req.erase(p)
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_req.erase(p)  # falló o ya la recogió otro (Screamers._spawn_model): se carga normal si hace falta
	if not _req.is_empty():
		_arm_reaper()


static func enabled() -> bool:
	return str(Loc.get_setting(SETTING, "normal")) != "reducido"


static func light() -> bool:
	return KillProps.light_mode()


static func _note(fx: Screamers, what: String) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	var g: Array = fx.last_info.get("gore", [])
	g.append(what)
	fx.last_info["gore"] = g


# --- ganchos del paquete gráfico ------------------------------------------------------------------------------

## Los ganchos del paquete gráfico (rama v0.3.2-gfx; funciones ESTÁTICAS de clases globales): GfxLens.kick(fuerza,
## segundos), GfxDirector.blackout(segundos, nivel), GfxDirector.emergency(on), GfxCharacters.dress(nodo). Se llaman
## SOLO si la clase existe (esta rama corre sola sin ese paquete): la clase se busca por nombre en la lista de clases
## globales, nunca se nombra en el código. GFX_ON = false los apaga todos (si hicieran falta en la integración).
static var GFX_ON: bool = true
static var _gfx: Dictionary = {}  # clase → Script o null
static var gfx_calls: Dictionary = {}  # "Clase.método" → veces (pruebas)


static func gfx(cls: String, method: String, args: Array = []) -> bool:
	if not GFX_ON:
		return false
	if not _gfx.has(cls):
		var scr: Script = null
		for c in ProjectSettings.get_global_class_list():
			if str((c as Dictionary).get("class", "")) == cls:
				scr = load(str((c as Dictionary).get("path", ""))) as Script
				break
		_gfx[cls] = scr
	var sc: Script = _gfx[cls]
	if sc == null:
		return false
	var has := false
	for m in sc.get_script_method_list():
		if str((m as Dictionary).get("name", "")) == method:
			has = true
			break
	if not has:
		return false
	sc.callv(method, args)
	gfx_calls[cls + "." + method] = int(gfx_calls.get(cls + "." + method, 0)) + 1
	return true


# --- buses ----------------------------------------------------------------------------------------------------

## Crea (una vez) los dos buses del screamer, hijos de «Sala»: voz y efectos con el agache en cadena lateral.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_SFX) >= 0:
		return
	var parent := "Sala" if AudioServer.get_bus_index("Sala") >= 0 else "Master"
	var comp := AudioEffectCompressor.new()
	comp.sidechain = BUS_VOZ
	comp.threshold = -30.0
	comp.ratio = 5.0
	comp.attack_us = 4000.0
	comp.release_ms = 160.0
	comp.gain = 0.0
	var lim := AudioEffectHardLimiter.new()
	lim.pre_gain_db = 9.0  # el golpe entra fuerte al limitador: el pico corto y denso
	lim.ceiling_db = -1.6
	lim.release = 0.08
	# v0.3.2c: AudioServer.add_bus() y set_bus_send() NO toman el candado del driver en el motor (4.7.2): tocan la
	# lista y el mapa de buses que el hilo de audio recorre en cada mezcla. Todo el armado va con el candado tomado
	# (es recursivo: set_bus_name/add_bus_effect lo vuelven a tomar sin problema).
	AudioServer.lock()
	AudioServer.add_bus()
	var vi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(vi, BUS_VOZ)
	AudioServer.set_bus_send(vi, parent)
	AudioServer.add_bus()
	var si := AudioServer.bus_count - 1
	AudioServer.set_bus_name(si, BUS_SFX)
	AudioServer.set_bus_send(si, parent)
	AudioServer.add_bus_effect(si, comp)
	AudioServer.add_bus_effect(si, lim)
	# El golpe del salto de Vitzo va por su propio bus, directo a Master: suena entero mientras todo lo demás se
	# agacha un instante (hit_dip): silencio → GOLPE.
	AudioServer.add_bus()
	var gi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(gi, BUS_GOLPE)
	AudioServer.set_bus_send(gi, "Master")
	AudioServer.unlock()


## Durante el screamer (y la pantalla de muerte que le sigue) el limitador de Master baja a -2,6 dBFS (-3,0 en la
## fusión de Vitzo, CEIL_BY_KILL: sus crujidos densos pasaban de -1 dBTP con -2,6): el
## HardLimiter de Godot limita la muestra, no el pico verdadero, y con la voz y la capa de impacto saturadas los
## picos entre muestras suben ~1 dB; así el pico verdadero queda ≤ -1 dBTP. Se devuelve GUARD_HOLD_S después de
## terminar el screamer (cubre los golpes de la pantalla de muerte), salvo que empiece otro.
const MASTER_CEIL_SCREAMER := -2.6
const CEIL_BY_KILL: Dictionary = {"vitzo_fusion": -3.0}
static var _ceil_now: float = MASTER_CEIL_SCREAMER
const GUARD_HOLD_S := 4.0
static var _master_ceil: float = 1.0
static var _guard_gen: int = 0


static func master_guard(on: bool, hold: float = 0.0, ceil_db: float = MASTER_CEIL_SCREAMER) -> void:
	_guard_gen += 1
	if on:
		_ceil_now = minf(ceil_db, MASTER_CEIL_SCREAMER)
	if not on and hold > 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var gen := _guard_gen
			tree.create_timer(hold, true, false, true).timeout.connect(func() -> void:
				if gen == _guard_gen:
					master_guard(false))
			return
	for i in AudioServer.get_bus_effect_count(0):
		var e := AudioServer.get_bus_effect(0, i)
		if e is AudioEffectHardLimiter:
			var lim := e as AudioEffectHardLimiter
			if on:
				if _master_ceil > 0.5:
					_master_ceil = lim.ceiling_db
				lim.ceiling_db = minf(_master_ceil, _ceil_now)
			elif _master_ceil <= 0.5:
				lim.ceiling_db = _master_ceil
				_master_ceil = 1.0
			return


## Ventana sin techo de screamer (v0.3.2d): durante `t` s el limitador de Master vuelve a su techo normal (el del
## bus, -1 dBFS) y después baja otra vez al del screamer, si la guarda sigue puesta. Solo para un sonido que suena
## SOLO y con pico verdadero conocido (el estruendo del salto de Vitzo: lo demás está a -30 dB por hit_dip).
static func master_window(fx: Screamers, t: float) -> void:
	if _master_ceil > 0.5 or fx == null or not is_instance_valid(fx):
		return  # la guarda no está puesta: ya está en su techo normal
	var lim: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			lim = AudioServer.get_bus_effect(0, i)
			break
	if lim == null:
		return
	lim.ceiling_db = _master_ceil
	var gen := _guard_gen
	fx.get_tree().create_timer(t, true, false, true).timeout.connect(func() -> void:
		if gen == _guard_gen and _master_ceil <= 0.5:
			lim.ceiling_db = minf(_master_ceil, _ceil_now))
	fx.last_info["golpe_ventana_s"] = t


# --- sonido -----------------------------------------------------------------------------------------------------

## La capa de impacto: transitorio + slam grave + rugido + chillido (kill_impacto) y el golpe grave (kill_slam).
static func slam(fx: Screamers, k: float = 1.0) -> void:
	fx._snd("sfx/kill_impacto_%02d" % (randi() % 4 + 1), lerpf(-1.0, 4.0, clampf(k, 0.0, 1.0)), randf_range(0.94, 1.06))
	if k >= 0.6:
		fx._snd("sfx/kill_slam_%02d" % (randi() % 2 + 1), 2.0, randf_range(0.9, 1.05))


## Hueso que cruje (Reducido: un golpe seco).
static func bone(fx: Screamers, k: float = 1.0) -> void:
	if enabled():
		fx._snd("sfx/kill_hueso_%02d" % (randi() % 3 + 1), lerpf(-3.0, 3.0, k), randf_range(0.92, 1.08))
		_note(fx, "hueso")
	else:
		fx._snd("sfx/kill_golpe_seco", 0.0, 0.8)


## Impacto húmedo (Reducido: el slam).
static func wet(fx: Screamers, k: float = 1.0) -> void:
	if enabled():
		fx._snd("sfx/kill_gore_%02d" % (randi() % 3 + 1), lerpf(-4.0, 2.0, k), randf_range(0.9, 1.1))
	else:
		fx._snd("sfx/kill_slam_01", -3.0)


## Tu grito de dolor (voz de tu agente: voces/agentes/dolor_<agente>_01..04, ES/EN): va al bus de efectos, así que
## se aparta bajo la frase del asesino (que siempre va delante). Como mucho uno cada 0,7 s.
static func pain(fx: Screamers, force: bool = false) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	var last := float(fx.get_meta("dolor_t", -9.0))
	if not force and fx._clock - last < 0.7:
		return
	fx.set_meta("dolor_t", fx._clock)
	fx._snd("voces/agentes/dolor_%s_%02d" % [GameState.agent.to_lower(), randi() % 4 + 1], -2.0, randf_range(0.97, 1.05))
	var n := int(fx.last_info.get("dolor", 0))
	fx.last_info["dolor"] = n + 1


## Vidrio / pantalla que se rompe: grieta + estallido + trozos que tintinean (al bus de efectos).
static func glass(fx: Screamers, db: float = 2.0) -> void:
	fx._snd("sfx/kill_vidrio_rompe_%02d" % (randi() % 3 + 1), db, randf_range(0.95, 1.05))
	fx.last_info["vidrio"] = int(fx.last_info.get("vidrio", 0)) + 1


## Silencio → GOLPE (v0.3.2c, Joan: «el sonido muy fuerte justo cuando salta, antes de su frase»): todo lo que no es
## el golpe (Sala y sus hijos, Ambiente, Auricular, UI) se hunde `depth` dB en t_down s, se queda `hold` s y vuelve en
## t_up s; el golpe (bus ScreamerGolpe, directo a Master) suena entero encima. Los volúmenes originales se guardan y
## se devuelven siempre (dip_restore, también al limpiar el screamer).
const DIP_BUSES: Array[String] = ["Sala", "Ambiente", "Auricular", "UI"]
static var _dip_orig: Dictionary = {}
static var _dip_gen: int = 0


static func hit_dip(fx: Screamers, t_down: float = 0.06, hold: float = 0.6, t_up: float = 0.3, depth: float = -30.0) -> void:
	var tree := fx.get_tree() if fx != null and is_instance_valid(fx) else null
	if tree == null:
		return
	for bn in DIP_BUSES:
		var bi := AudioServer.get_bus_index(bn)
		if bi >= 0 and not _dip_orig.has(bn):
			_dip_orig[bn] = AudioServer.get_bus_volume_db(bi)
	_dip_gen += 1
	var gen := _dip_gen
	var tw := fx.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(k: float) -> void:
		if gen == _dip_gen:
			_dip_apply(k * depth), 0.0, 1.0, maxf(t_down, 0.01))
	tw.tween_interval(maxf(hold, 0.01))
	tw.tween_method(func(k: float) -> void:
		if gen == _dip_gen:
			_dip_apply(k * depth), 1.0, 0.0, maxf(t_up, 0.01))
	tw.tween_callback(func() -> void:
		if gen == _dip_gen:
			dip_restore())
	fx.last_info["golpe_silencio_s"] = fx._clock


static func _dip_apply(db: float) -> void:
	for bn in _dip_orig.keys():
		var bi := AudioServer.get_bus_index(bn)
		if bi >= 0:
			AudioServer.set_bus_volume_db(bi, float(_dip_orig[bn]) + db)


static func dip_restore() -> void:
	_dip_gen += 1
	_dip_apply(0.0)
	_dip_orig.clear()


## El bus del golpe sigue al volumen de «Sala» (Opciones → efectos), sin el agache.
static func sync_golpe() -> void:
	var gi := AudioServer.get_bus_index(BUS_GOLPE)
	var si := AudioServer.get_bus_index("Sala")
	if gi >= 0 and si >= 0:
		AudioServer.set_bus_volume_db(gi, float(_dip_orig.get("Sala", AudioServer.get_bus_volume_db(si))))
		AudioServer.set_bus_mute(gi, AudioServer.is_bus_mute(si))


## Agacha la música y el ambiente (buses Ambiente y Parlantes, y la música del screamer) t segundos.
static func duck_music(fx: Screamers, t: float) -> void:
	for bn in ["Ambiente", "Parlantes"]:
		var bi := AudioServer.get_bus_index(bn)
		if bi < 0:
			continue
		var v0 := float(_dip_orig.get(bn, AudioServer.get_bus_volume_db(bi)))  # el volumen de verdad, no el del silencio del golpe
		AudioServer.set_bus_volume_db(bi, v0 - 14.0)
		fx.get_tree().create_timer(t, true).timeout.connect(func() -> void: AudioServer.set_bus_volume_db(bi, v0))
	if fx._music != null and is_instance_valid(fx._music):
		var m := fx._music
		var mv := m.volume_db
		m.volume_db = mv - 18.0
		fx.get_tree().create_timer(t, true).timeout.connect(func() -> void:
			if is_instance_valid(m):
				m.volume_db = mv)


static func roar(fx: Screamers, db: float = 0.0) -> void:
	fx._snd("sfx/kill_rugido", db, randf_range(0.95, 1.05))


static func screech(fx: Screamers, db: float = 0.0) -> void:
	fx._snd("sfx/kill_chillido", db, randf_range(0.95, 1.08))


# --- sangre en pantalla ----------------------------------------------------------------------------------------

## Salpicadura en la pantalla (manchas + gotas + chorreones que bajan). at en fracción de la vista (x, y); amount
## 0..1 tamaño. Reducido: nada.
static func splatter(fx: Screamers, amount: float = 1.0, at: Vector2 = Vector2(-1, -1), seed: int = -1) -> Control:
	if not enabled() or fx == null or fx._top == null:
		return null
	var b := Blood.new()
	b.amount = clampf(amount, 0.1, 2.0)
	b.at = at if at.x >= 0.0 else Vector2(randf_range(0.25, 0.75), randf_range(0.2, 0.6))
	b.seed_v = seed if seed >= 0 else randi()
	b.light = light()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx._top.add_child(b)
	_note(fx, "sangre")
	if not (fx.last_info.get("props", []) as Array).has("sangre"):
		(fx.last_info["props"] as Array).append("sangre")
	return b


## La pantalla se raja con sangre en las grietas (golpe contra el monitor, la cabina…).
static func crack_blood(fx: Screamers) -> void:
	fx._crack()
	if enabled():
		splatter(fx, 0.7, Vector2(0.5, 0.45))


## Todo se tiñe de rojo y se apaga (desangrarse, los ojos). Reducido: solo se apaga a negro.
static func red_out(fx: Screamers, t: float, hold_a: float = -1.0) -> ColorRect:
	if fx._root == null or fx._top == null:
		return null
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0.3, 0.0, 0.0, 0.0) if enabled() else Color(0, 0, 0, 0)
	fx._top.add_child(r)
	var tw := r.create_tween()
	if hold_a >= 0.0:
		tw.tween_property(r, "color:a", hold_a, maxf(t, 0.05))  # se queda teñido a medias: lo que sigue se ve
		return r
	tw.tween_property(r, "color:a", 0.82, maxf(t * 0.6, 0.05))
	tw.tween_property(r, "color", Color(0.04, 0.0, 0.0, 0.96), maxf(t * 0.4, 0.05))
	return r


## Sangre, moretones, piel rasgada y ojos inyectados en la cara del asesino (shader cara_deforme: gore).
static func face(fx: Screamers, amount: float, t: float = 0.3) -> void:
	if fx._rig == null or not is_instance_valid(fx._rig):
		return
	var a := clampf(amount, 0.0, 1.0) if enabled() else 0.0
	fx._rig.gore_detail = 0.0 if light() else 1.0
	fx.create_tween().tween_property(fx._rig, "gore", maxf(a, fx._rig.gore), maxf(t, 0.02))
	if a > 0.0:
		_note(fx, "cara")


class Blood extends Control:
	var amount: float = 1.0
	var at: Vector2 = Vector2(0.5, 0.5)
	var seed_v: int = 1
	var light: bool = false
	var tint: Color = Color(0, 0, 0, 0)  # a > 0: otro color (la comida del táper)
	var _blobs: Array = []  # [centro, radio, color]
	var _drips: Array = []  # [x, y0, largo, máx, ancho, velocidad]
	var _t: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var sz := get_viewport_rect().size
		var c := sz * at
		var base := 70.0 * amount * (sz.y / 720.0)
		var col := tint if tint.a > 0.0 else BLOOD
		var dark := tint.darkened(0.45) if tint.a > 0.0 else BLOOD_DARK
		_blobs.append([c, base, col])
		var n := 12 if not light else 6
		for i in n:
			var a := rng.randf_range(0, TAU)
			var d := base * rng.randf_range(0.8, 3.2)
			var r := base * rng.randf_range(0.06, 0.32)
			_blobs.append([c + Vector2(cos(a), sin(a)) * d, r, col if rng.randf() < 0.7 else dark])
		for i in ((7 if not light else 3) if tint.a <= 0.0 else 2):
			var x := c.x + rng.randf_range(-base, base)
			_drips.append([x, c.y + rng.randf_range(-base * 0.3, base * 0.5), 0.0, rng.randf_range(base * 1.2, base * 5.0),
				rng.randf_range(4.0, 11.0) * amount * (sz.y / 720.0), rng.randf_range(60.0, 220.0) * (sz.y / 720.0)])
		modulate = Color(1, 1, 1, 0.0)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.04)

	func _process(delta: float) -> void:
		_t += delta
		for d in _drips:
			d[2] = minf(float(d[3]), float(d[2]) + float(d[5]) * delta)
		queue_redraw()

	func _draw() -> void:
		for b in _blobs:
			var p: Vector2 = b[0]
			var r: float = b[1]
			draw_circle(p, r, b[2])
			draw_circle(p + Vector2(r * 0.25, -r * 0.2), r * 0.55, (b[2] as Color).darkened(0.4))
			draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.12, Color(0.75, 0.25, 0.25, 0.35))  # brillo húmedo
		for d in _drips:
			var x: float = d[0]
			var y0: float = d[1]
			var l: float = d[2]
			var w: float = d[4]
			if l <= 1.0:
				continue
			var dc := tint if tint.a > 0.0 else BLOOD
			draw_rect(Rect2(x - w * 0.5, y0, w, l), dc)
			draw_circle(Vector2(x, y0 + l), w * 0.75, dc)


# --- tus manos ----------------------------------------------------------------------------------------------------

## Tus antebrazos y manos en el borde de la vista (forcejeas). wounds: moretones y cortes (Reducido: limpias).
## Devuelve [follow_izq, follow_der] (KillProps.Follow: pos/rot animables).
static func own_hands(fx: Screamers, wounds: bool = true) -> Array:
	var out: Array = []
	var skin: Color = SKIN.get(GameState.agent, Color(0.8, 0.64, 0.5))
	var sleeve := Color(0.12, 0.13, 0.16)
	for side in [-1.0, 1.0]:
		var f := KillProps.follow(fx, KillMoves.L(0.26 * side, -0.42, 0.38), Vector3(55, -20 * side, 0))
		f.name = "TuMano%s" % ("Izq" if side < 0 else "Der")
		var mat := _skin_mat(skin, wounds and enabled())
		# manga, antebrazo, palma, dedos y pulgar
		var arm := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.034
		cm.height = 0.3
		arm.mesh = cm
		arm.material_override = mat
		arm.position = Vector3(0, -0.17, 0)
		f.add_child(arm)
		var cuff := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.045
		cy.bottom_radius = 0.048
		cy.height = 0.16
		cuff.mesh = cy
		cuff.material_override = KillProps.mat(sleeve)
		cuff.position = Vector3(0, -0.32, 0)
		f.add_child(cuff)
		var palm := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.085, 0.09, 0.028)
		palm.mesh = pm
		palm.material_override = mat
		palm.position = Vector3(0, 0.02, 0)
		f.add_child(palm)
		for i in 4:
			var fi := MeshInstance3D.new()
			var fm := CapsuleMesh.new()
			fm.radius = 0.009
			fm.height = 0.07 - absf(i - 1.5) * 0.008
			fi.mesh = fm
			fi.material_override = mat
			fi.position = Vector3(-0.03 + i * 0.02, 0.09, 0.004)
			fi.rotation_degrees = Vector3(-18, 0, 0)
			f.add_child(fi)
		var th := MeshInstance3D.new()
		var tm := CapsuleMesh.new()
		tm.radius = 0.01
		tm.height = 0.06
		th.mesh = tm
		th.material_override = mat
		th.position = Vector3(0.05 * -side, 0.02, 0.01)
		th.rotation_degrees = Vector3(0, 0, 50 * side)
		f.add_child(th)
		for m in f.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(f)
	(fx.last_info["props"] as Array).append("tus_manos")
	if wounds and enabled():
		_note(fx, "manos")
	return out


## Material de piel con moretones (morado-verdoso) y cortes con sangre (ruido, sin texturas).
static func _skin_mat(skin: Color, wounds: bool) -> ShaderMaterial:
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = SKIN_CODE
	var m := ShaderMaterial.new()
	m.shader = _skin_shader
	m.set_shader_parameter("skin", skin)
	m.set_shader_parameter("wounds", 1.0 if wounds else 0.0)
	return m


const SKIN_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 skin : source_color;
uniform float wounds = 1.0;
uniform float veins = 0.0;  // la fusión de Vitzo: venas verdes que se extienden
varying vec3 lp;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) { vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 c = skin.rgb;
	float r = 0.8;
	if (wounds > 0.5) {
		float b = smoothstep(0.55, 0.75, n3(lp * 38.0 + vec3(3.0)));
		c = mix(c, vec3(0.32, 0.16, 0.3), b * 0.75);
		c = mix(c, vec3(0.42, 0.42, 0.22), smoothstep(0.7, 0.8, n3(lp * 38.0 + vec3(3.0))) * 0.3);
		float cut = 1.0 - smoothstep(0.0, 0.035, abs(n3(lp * vec3(14.0, 60.0, 14.0)) - 0.5));
		c = mix(c, vec3(0.32, 0.0, 0.01), cut * 0.9);
		float sp = smoothstep(0.78, 0.84, n3(lp * 90.0));
		c = mix(c, vec3(0.3, 0.0, 0.01), sp);
		r = mix(r, 0.25, max(cut, sp));
	}
	if (veins > 0.001) {
		float v = 1.0 - smoothstep(0.0, 0.05, abs(n3(lp * vec3(30.0, 90.0, 30.0)) - 0.5));
		float reach = smoothstep(0.15 - veins * 0.5, 0.2 - veins * 0.5, -lp.y * 2.0 + 0.1);
		c = mix(c, vec3(0.05, 0.42, 0.12), v * clamp(veins * 1.4, 0.0, 1.0) * (0.4 + 0.6 * reach));
	}
	ALBEDO = c;
	ROUGHNESS = r;
}
"""


## El antebrazo doblado al revés (Coaching 11 h): el codo se quiebra, crujido y chorro de sangre. Corte en el pico.
static func arm_break(fx: Screamers, hand: KillProps.Follow, t: float) -> void:
	if hand == null or not is_instance_valid(hand):
		return
	var tw := hand.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	if enabled():
		tw.tween_property(hand, "rot", hand.rot + Vector3(-70, 0, 75), maxf(t, 0.03))
		tw.tween_callback(func() -> void:
			if is_instance_valid(fx) and not fx._done:
				bone(fx, 1.0)
				wet(fx, 0.8)
				splatter(fx, 1.0, Vector2(0.62, 0.62))
				splatter(fx, 0.5, Vector2(0.4, 0.3)))
		_note(fx, "brazo")
	else:
		tw.tween_property(hand, "rot", hand.rot + Vector3(-25, 0, 20), maxf(t, 0.03))
		tw.tween_callback(func() -> void:
			if is_instance_valid(fx) and not fx._done:
				fx._snd("sfx/kill_golpe_seco", 0.0, 0.8))


## El borde de una oreja rasgada en su puño, unos fotogramas (Abandono del training). Reducido: nada.
static func ear_flash(fx: Screamers, at_local: Vector3, frames_s: float = 0.22) -> void:
	if not enabled():
		return
	var f := KillProps.follow(fx, at_local, Vector3(0, 20, -15))
	f.name = "BordeOreja"
	var skin: Color = SKIN.get(GameState.agent, Color(0.8, 0.64, 0.5))
	var e := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.075
	e.mesh = sm
	e.scale = Vector3(1.0, 1.0, 0.3)
	e.material_override = _skin_mat(skin, true)
	f.add_child(e)
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.012, 0.07, 0.016)
	edge.mesh = em
	edge.material_override = KillProps.mat(Color(0.34, 0.0, 0.01), 0.0, false, 0.2)
	edge.position = Vector3(-0.026, 0, 0)
	f.add_child(edge)
	_note(fx, "oreja")
	fx.get_tree().create_timer(frames_s, true).timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.queue_free())


## Los pulgares que se hunden en tus ojos: la sangre brota desde el centro de la vista y todo se pone rojo.
static func eyes(fx: Screamers, t: float) -> ColorRect:
	if not enabled():
		return red_out(fx, t)
	splatter(fx, 0.55, Vector2(0.38, 0.46), 3)
	splatter(fx, 0.55, Vector2(0.62, 0.46), 4)
	wet(fx, 1.0)
	bone(fx, 0.6)
	_note(fx, "ojos")
	return red_out(fx, t)

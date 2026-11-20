extends Node
## Fatigue: 0-100, sin barra (GDD 4.6). Expone umbrales para el controlador de distorsiones.
## v0.3 (PLAN §1): el colapso se pide por flanco (solo al cruzar 100 con add) y nunca mientras hay una
## muerte en curso o un respawn; set_value() fija el valor sin poder matar (lo usa el respawn).

var value: float = 20.0
var _hours_applied: int = -1
var _microsleep_timer: float = 0.0
var _blink_timer: float = 0.0
var _blur_off_until: float = 0.0  # gotas para los ojos (v0.2): segundos reales hasta que vuelve el desenfoque
var _microsleep_off_until: float = 0.0  # v0.3.1 (Q4, comer): segundos reales sin microsueños
var _blur_hint_given: bool = false  # v0.3.1 (B7): aviso «[R] Frotarte los ojos», una vez por turno
## v0.3.1 (B7): el aviso lo dibuja Overlays ENCIMA del desenfoque (un show_message del HUD salía borroso: el aviso
## que explica el desenfoque no se podía leer). Texto y segundos que le quedan; hints_shown cuenta los del turno.
var blur_hint_text: String = ""
var blur_hint_left: float = 0.0
var blur_hints_shown: int = 0


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.returned_to_menu.connect(_on_shift_started)
	# v0.3.1 (B7): tras reconectar el parpadeo vuelve a empezar (antes seguía contando y todo quedaba borroso).
	# v0.3.2-core3: y la subida por hora se cuenta desde la hora del checkpoint: antes, si morías en la hora siguiente
	# a la del checkpoint, esa hora ya no volvía a sumar al repetirla (y si morías más tarde, sí).
	EventBus.respawned.connect(func(_k: String) -> void: _blink_timer = 0.0; _reset_microsleep_timer(); _hours_applied = GameState.current_hour())
	_reset_microsleep_timer()


func _process(delta: float) -> void:
	if not GameState.running or get_tree().paused:
		return
	if blur_hint_left > 0.0:
		blur_hint_left -= delta
		if not blink_needed() or blur_amount() <= 0.0:
			blur_hint_left = minf(blur_hint_left, 0.6)  # al frotarte los ojos el aviso se va
	# Microsueños: pantalla negra 0,5 s cada 60-90 s con Fatiga >= 70.
	if microsleep_enabled() and not microsleep_suppressed():
		_microsleep_timer -= delta
		if _microsleep_timer <= 0.0:
			_reset_microsleep_timer()
			EventBus.microsleep.emit()
	# Parpadeo necesario (40-69): la imagen se desenfoca cada 40 s hasta pulsar R.
	if blink_needed():
		_blink_timer += delta
		if not _blur_hint_given and blur_amount() > 0.02:
			_blur_hint_given = true
			if Difficulty.level <= Difficulty.Level.NORMAL and not GameState.is_real_mode():
				blur_hint_text = Loc.fmt(tr("Q1_HINT_RUB_EYES"), {"tecla": _rub_key()})
				blur_hint_left = 7.0
				blur_hints_shown += 1


func _on_shift_started() -> void:
	var base := float(DataLoader.bal("fatiga/inicio_t1", 20.0))
	var per_turno := float(DataLoader.bal("fatiga/inicio_por_turno", 5.0))
	# Fatiga inicial del turno: turnos.json/fatiga_inicio si existe (T1 = 20, T2 = 25, T3 = 30 = misma fórmula).
	value = float(GameState.turno_cfg("fatiga_inicio", base + per_turno * (GameState.turno - 1)))
	_hours_applied = -1
	_blur_off_until = 0.0
	_microsleep_off_until = 0.0
	_blink_timer = 0.0
	_blur_hint_given = false
	blur_hint_left = 0.0
	blur_hints_shown = 0
	_emit()


## Gotas para los ojos (expendedora, T2+): sin desenfoque durante `seconds` reales.
func suppress_blur(seconds: float) -> void:
	_blur_off_until = Time.get_ticks_msec() / 1000.0 + seconds
	_blink_timer = 0.0


func blur_suppressed() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _blur_off_until


## v0.3.1 (Q4, comer el taper): sin microsueños durante `seconds` reales; al terminar, el próximo llega en 60-90 s.
func suppress_microsleep(seconds: float) -> void:
	_microsleep_off_until = maxf(_microsleep_off_until, Time.get_ticks_msec() / 1000.0 + seconds)
	_reset_microsleep_timer()


func microsleep_suppressed() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _microsleep_off_until


## Tecla de «frotarse los ojos» (la remapeada si la hay). Sin pasar por la distribución del teclado: en headless
## DisplayServer.keyboard_get_keycode_from_physical no existe.
func _rub_key() -> String:
	for ev in InputMap.action_get_events("rub_eyes") if InputMap.has_action("rub_eyes") else []:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var s := OS.get_keycode_string(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
			if s != "":
				return s
	return "R"


func _on_hour_changed(hour: int) -> void:
	if not GameState.logged_in:
		return
	if _hours_applied == hour:
		return
	_hours_applied = hour
	add(float(DataLoader.bal("fatiga/por_hora", 4.0)))  # × ganancia de la dificultad (v0.3.2, en add)


## Suma (o resta) Fatiga. Pide el colapso solo al cruzar 100 desde abajo, y nunca si ya hay una muerte
## en curso o un respawn (Checkpoints.can_die()).
## v0.3.2: lo que sube se multiplica por Difficulty.fatigue_rate("ganancia") y lo que baja por ("recuperacion")
## (dificultad.json/fatiga: Fácil, Normal, Difícil y Turno real). `raw` = sin escalar (pruebas, Inducción).
func add(amount: float, raw: bool = false) -> void:
	if not raw:
		amount *= Difficulty.fatigue_rate("ganancia" if amount > 0.0 else "recuperacion")
	var old := value
	value = clampf(value + amount, 0.0, 100.0)
	_emit()
	if value >= 100.0 and old < 100.0:
		if Checkpoints.can_die():
			EventBus.death_requested.emit("colapso", "")
		else:
			value = 99.0  # sin muerte posible ahora: queda justo debajo para que el próximo cruce cuente
			_emit()


## Fija la Fatiga sin disparar el colapso (respawn, checkpoints, escenarios). Se queda por debajo de 100.
func set_value(v: float) -> void:
	value = clampf(v, 0.0, 99.0)
	_emit()


func _emit() -> void:
	EventBus.fatigue_changed.emit(value, level())


## 0: nada · 1: parpadeo necesario (40-69) · 2: microsueños (70-89) · 3: texto cambia (90-99) · 4: colapso.
func level() -> int:
	if value >= 100.0:
		return 4
	if value >= float(DataLoader.bal("fatiga/umbral_texto", 90.0)):
		return 3
	if value >= float(DataLoader.bal("fatiga/umbral_microsueno", 70.0)):
		return 2
	if value >= float(DataLoader.bal("fatiga/umbral_parpadeo", 40.0)):
		return 1
	return 0


func blink_needed() -> bool:
	return level() >= 1


func microsleep_enabled() -> bool:
	return level() >= 2


func text_corruption() -> bool:
	return level() >= 3


## Segundos desde el último frotarse los ojos; la UI desenfoca pasados 40 s, sube en 5 s y tiene tope 0,6
## (v0.3.1, B7: se sigue leyendo).
func blur_amount() -> float:
	if not blink_needed() or blur_suppressed():
		return 0.0
	var every := float(DataLoader.bal("fatiga/desenfoque_cada_s", 40.0))
	var rise := maxf(float(DataLoader.bal("fatiga/desenfoque_sube_s", 5.0)), 0.1)
	var cap := float(DataLoader.bal("fatiga/desenfoque_tope", 0.6))
	return clampf((_blink_timer - every) / rise, 0.0, 1.0) * cap


func blink_timer() -> float:
	return _blink_timer


func rub_eyes() -> void:
	_blink_timer = 0.0
	AudioManager.play_sfx("parpadeo")
	EventBus.player_blinked.emit()


func _reset_microsleep_timer() -> void:
	var lo := float(DataLoader.bal("fatiga/microsueno_min_s", 60.0))
	var hi := float(DataLoader.bal("fatiga/microsueno_max_s", 90.0))
	_microsleep_timer = randf_range(lo, hi)


## Balanceo extra al caminar por Fatiga (0-1).
func headbob_factor() -> float:
	return clampf((value - 40.0) / 60.0, 0.0, 1.0)

class_name MusicDirector
extends Node
## Música de fondo adaptativa (v0.3.1 Q3, B4). Cuatro capas de la misma duración (192 s, Re, 75 lpm) que suenan
## SIEMPRE juntas y sincronizadas; lo que cambia es el volumen de cada una según la presión:
##   capa 1 · calma con pavor   (cuerdas muy graves, piano preparado lejano)  — base durante el turno
##   capa 2 · tensión            (ostinato de chelos)                          — Dread ≥ ~0,25
##   capa 3 · alta tensión       (trémolo en cluster, reloj, «braams»)        — Dread ≥ ~0,55
##   capa 4 · persecución        (taikos, chelos frenéticos)                   — Pursuit activo (o Dread ≈ 1)
## Silencio a propósito en la azotea (solo lluvia y viento) y durante una muerte (el screamer manda). Con la cama del
## feedback de Haime (musica/feedback_haime_loop, por AudioManager.play_music) o la música de Rasec sonando, las capas
## bajan para no pisarse. Hijo del AudioDirector. Sin archivo: no suena nada.

const LAYERS: Array[String] = ["musica/tension_capa_1", "musica/tension_capa_2", "musica/tension_capa_3", "musica/tension_capa_4"]
const BASE_DB := -7.0  # las capas vienen a −22 LUFS: en el juego, una cama de fondo de ~−29
const FLOOR_DB := -60.0

var players: Array[AudioStreamPlayer] = []
var levels: Array[float] = [0.0, 0.0, 0.0, 0.0]  # 0..1, suavizados (pruebas y capturas)
var targets: Array[float] = [0.0, 0.0, 0.0, 0.0]
var forced: Array = []  # pruebas/capturas: [l1, l2, l3, l4] fija los objetivos
var reason: String = ""  # por qué suena así (pruebas)
var _started: bool = false
var _rasec_on: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in LAYERS.size():
		var p := AudioStreamPlayer.new()
		p.name = "Capa%d" % (i + 1)
		p.bus = "Musica"
		p.volume_db = FLOOR_DB
		add_child(p)
		players.append(p)
	EventBus.returned_to_menu.connect(func() -> void: _stop())


func _load_all() -> bool:
	var off := -1.0
	for i in LAYERS.size():
		var st := AudioManager.stream_for(LAYERS[i], true)
		if st == null:
			return false
		players[i].stream = st
		if off < 0.0:
			off = randf_range(0.0, maxf(st.get_length() - 1.0, 0.0))
	for p in players:
		p.play(off)  # mismo punto de partida: las capas quedan en fase
	_started = true
	return true


func _stop() -> void:
	for p in players:
		p.stop()
	_started = false
	for i in 4:
		levels[i] = 0.0


func set_rasec(on: bool) -> void:
	_rasec_on = on


## Objetivos (0..1) de las 4 capas para el momento actual.
func compute_targets() -> Array[float]:
	var t: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if not forced.is_empty():
		for i in 4:
			t[i] = float(forced[i])
		reason = "forzado"
		return t
	if not GameState.running or GameState.shift_over:
		reason = "fuera del turno"
		return t
	if Flashback.active:
		reason = "recuerdo (Training: suena su música cálida)"
		return t
	if Checkpoints.dying:
		reason = "muerte"
		return t
	var dir := get_parent()
	var f := GameState.current_floor
	if f == 9 and dir != null and not (dir.get("_zones") as Dictionary).has("azotea_vestibulo"):
		reason = "azotea (silencio a propósito)"
		return t
	var p := Dread.level()
	var hunting := Pursuit.is_hunting()
	t[0] = 1.0 if not hunting else 0.55
	t[1] = smoothstep(0.18, 0.42, p)
	t[2] = smoothstep(0.5, 0.75, p)
	t[3] = 1.0 if hunting else smoothstep(0.93, 1.0, p) * 0.6
	if not GameState.logged_in:  # todavía en la calle o subiendo: solo el pavor, bajito
		t[0] *= 0.6
	var other := AudioManager.music_playing()
	if other != "" or _rasec_on:
		for i in 4:
			t[i] *= 0.15 if i < 3 else 0.6  # la cama del feedback / la música de Rasec manda (la persecución no)
		reason = "otra música (%s)" % (other if other != "" else "rasec")
	else:
		reason = "persecución" if hunting else "presión %.2f" % p
	return t


func _process(delta: float) -> void:
	targets = compute_targets()
	var any := false
	for i in 4:
		any = any or targets[i] > 0.001
	if any and not _started:
		if not _load_all():
			return
	if not _started:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)  # en segundos reales (los escenarios aceleran el tiempo)
	for i in 4:
		var up := 1.0 / (0.6 if i == 3 else 3.5)  # la persecución entra rápido; el resto, de a poco
		var down := 1.0 / (1.2 if Checkpoints.dying else 4.0)
		var rate := up if targets[i] > levels[i] else down
		levels[i] = move_toward(levels[i], targets[i], rate * dt)
		players[i].volume_db = FLOOR_DB if levels[i] <= 0.001 else BASE_DB + linear_to_db(levels[i]) + AudioManager.gain_db(LAYERS[i])
	if not any and levels.max() <= 0.001:
		_stop()

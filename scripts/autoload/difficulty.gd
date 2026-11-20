extends Node
## Difficulty (v0.3, PLAN §3.6): Fácil / Normal / Difícil para el Turno normal. El Turno real fija Difícil
## (y además no tiene checkpoints y reinicia el turno completo al morir: eso lo decide Checkpoints).
## Tabla en data/dificultad.json. API para los demás paquetes:
##   Difficulty.scale("plazos")  → multiplicador de plazos (escalera de Shero, Trainer, RTA)
##   Difficulty.scale("ack") / ("calma") / ("fatiga_hora") / ("tolerancia_rta") / ("vitzo_reaccion") / ("mentor_cumplir")
##   Difficulty.flag("salvarse_sentado") / ("confirmar_tercer_break") / ("pistas_trampas")
##   Difficulty.value("quiz_aprobar") / ("checkpoints")
## La elección se guarda en la partida del agente (SaveSlots, clave "dificultad").

enum Level { FACIL, NORMAL, DIFICIL }

const IDS: Array[String] = ["facil", "normal", "dificil"]
const NAME_KEYS: Array[String] = ["DIFF_FACIL", "DIFF_NORMAL", "DIFF_DIFICIL"]

var level: int = Level.NORMAL


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--dificultad")
	if i >= 0 and i + 1 < args.size():
		set_level(level_from_id(args[i + 1]))


## Fija el nivel elegido en el menú (no el efectivo: el Turno real siempre es Difícil).
func set_level(l: int) -> void:
	l = clampi(l, Level.FACIL, Level.DIFICIL)
	if l == level:
		return
	level = l
	EventBus.difficulty_changed.emit(level)


## Nivel que manda en el turno: Difícil en Turno real; si no, el elegido.
func effective() -> int:
	if GameState.is_real_mode():
		return Level.DIFICIL
	return level


func id(l: int = -1) -> String:
	return IDS[clampi(effective() if l < 0 else l, 0, IDS.size() - 1)]


func display_name(l: int = -1) -> String:
	return tr(NAME_KEYS[clampi(effective() if l < 0 else l, 0, NAME_KEYS.size() - 1)])


static func level_from_id(s: String) -> int:
	match s.to_lower():
		"facil", "fácil", "easy", "0":
			return Level.FACIL
		"dificil", "difícil", "hard", "2":
			return Level.DIFICIL
	return Level.NORMAL


## Multiplicador del nivel efectivo (1.0 si la clave no existe).
func scale(key: String) -> float:
	return float(_column("escalas", key, 1.0))


func flag(key: String) -> bool:
	return bool(_column("banderas", key, false))


func value(key: String, default: Variant = null) -> Variant:
	return _column("valores", key, default)


## v0.3.2: multiplicador de Fatiga del nivel efectivo, con columna propia para el Turno real (dificultad.json/fatiga).
## kind: "ganancia" (lo que sube) o "recuperacion" (lo que baja).
func fatigue_rate(kind: String) -> float:
	var f: Dictionary = DataLoader.dict("dificultad").get("fatiga", {})
	var row: Variant = f.get(kind, null)
	if not (row is Array) or (row as Array).is_empty():
		return 1.0
	var col := 3 if GameState.is_real_mode() else effective()
	return float((row as Array)[clampi(col, 0, (row as Array).size() - 1)])


## ¿Morir reinicia el turno completo? (Turno real)
func restarts_full_shift() -> bool:
	return GameState.is_real_mode()


func _column(group: String, key: String, default: Variant) -> Variant:
	var row: Variant = DataLoader.dict("dificultad").get(group, {}).get(key, null)
	if row is Array and not (row as Array).is_empty():
		var arr := row as Array
		return arr[clampi(effective(), 0, arr.size() - 1)]
	return default

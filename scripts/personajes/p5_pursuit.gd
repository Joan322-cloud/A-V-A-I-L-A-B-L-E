class_name P5Pursuit
extends Node
## Persecución de los cazadores de P5 (Trainer por training_inasistencia, Perrito RTA por aux_incorrecto y, si P3
## no lleva la pista del tópico, Shero por work_avoiding). Desde el merge de P5 en v0.3 hay UN solo sistema de
## persecución: el `Pursuit` de P3 (core/pursuit.gd, hijo del autoload Discipline). Esta clase es solo la fachada
## con la API que usan los controles de P5:
##   P5Pursuit.start(cazador, causa, velocidad, escena = null, detalle = "", piso_origen = -99, desde = INF) -> bool
##   P5Pursuit.stop(cazador, motivo = "detenida")   ·   P5Pursuit.is_hunting(cazador = "")   ·   P5Pursuit.node_of(cazador)
## Todos los argumentos pasan tal cual a Pursuit.start (detalle, piso de origen y posición incluidos), así el
## Trainer y el RTA salen de DONDE ESTÁN si estás en su piso (sin pasar por el ascensor/escalera) y, si no, llegan
## por el ascensor (Trainer: 20 s + 6 por parada desde el 1) o la escalera (RTA: 12 s + 4 por parada desde el 2).
## El asesino es el propio cazador (Pursuit pide Checkpoints.request_death(causa, detalle, cazador)). Las rutas,
## los baños (espera en la puerta), el cambio de piso y las señales pursuit_started / hunter_entered_floor /
## pursuit_ended las hace Pursuit. El nodo (vive en PersonajesP5) solo corta las persecuciones de P5 con stop_all.

const GROUP := "p5_pursuit"
## Cazadores de P5 (para stop_all) y su asesino.
const HUNTERS: Dictionary = {"trainer": "trainer", "rta": "rta", "shero": "shero"}


static func get_node_in(tree: SceneTree) -> P5Pursuit:
	return tree.get_first_node_in_group(GROUP) as P5Pursuit if tree != null else null


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.death_sequence_started.connect(_on_death)


## Como antes del merge: una muerte por OTRA causa corta la caza de los cazadores de P5 (el Trainer o el RTA no
## siguen corriendo durante el screamer de Shero). Si es su propia captura, Pursuit la termina con "alcanzado".
func _on_death(cause: String, _killer: String, _detail: String) -> void:
	for k in ["trainer", "rta"]:
		if Pursuit.is_hunting(k) and str(Pursuit.info(k).get("cause", "")) != cause:
			Pursuit.stop(k, "muerte")


# --- API estática (delegan en Pursuit) ------------------------------------------------------------

static func start(hunter: String, cause: String, spd: float = 4.6, scene: Variant = null, detail: String = "", from_floor: int = -99, from_pos: Vector3 = Vector3.INF) -> bool:
	if not GameState.running:
		return false
	return Pursuit.start(hunter, cause, spd, scene, detail, from_floor, from_pos, Callable(), {"asesino": str(HUNTERS.get(hunter, hunter)), "p5": true})


static func stop(hunter: String, reason: String = "detenida") -> void:
	Pursuit.stop(hunter, reason)


static func is_hunting(hunter: String = "") -> bool:
	return Pursuit.is_hunting(hunter)


static func node_of(hunter: String) -> Node3D:
	return Pursuit.node_of(hunter)


## Corta las persecuciones de los cazadores de P5 (las pruebas y las capturas).
func stop_all(reason: String) -> void:
	for k in HUNTERS.keys():
		if Pursuit.is_hunting(str(k)):
			Pursuit.stop(str(k), reason)

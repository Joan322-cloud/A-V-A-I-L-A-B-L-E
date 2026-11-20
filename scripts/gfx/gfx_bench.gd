class_name GfxBench
extends Node
## v0.3.2 gfx · Medición de rendimiento.
##
## 1. Primera vez (escritorio, el jugador todavía no eligió calidad a mano): el juego arranca con la calidad que
##    corresponde a la tarjeta (GfxBoot.desktop_default) y, ya dentro del primer turno, este nodo mide los fps de
##    verdad durante unos segundos. Si no alcanzan (ver FLOOR_FPS) baja un escalón —Alta → Media → Baja— y vuelve a
##    medir; al terminar lo avisa una vez y no vuelve a correr (settings «gfx_bench_hecho»). Nunca sube sola ni
##    pasa a Modo liviano (eso lo decide el adaptador por software o el jugador).
## 2. A pedido (Gráficos avanzados → «Medir y elegir calidad», con un piso cargado): prueba Alta, Media y Baja
##    unos segundos cada una en la vista actual y se queda con la más alta que llega a TARGET_FPS.
##
## Presupuesto (lo que se le pide a cada calidad a 1080p): Alta 60 fps en una tarjeta dedicada de gama media de
## hace unos años (clase GTX 1660 / RX 580); Media 30–60 fps en gráficos integrados recientes; Baja y liviano,
## como siempre. La medición usa el tiempo real entre cuadros (no el contador del motor) y descarta los cuadros
## de carga (> 250 ms).

## Por debajo de esto, la primera vez se baja un escalón.
const FLOOR_FPS: Dictionary = {"alta": 45.0, "media": 30.0}
## A pedido: lo que tiene que dar una calidad para quedarse con ella.
const TARGET_FPS: Dictionary = {"alta": 50.0, "media": 40.0, "baja": 0.0}
const WARMUP := 3.0
const WINDOW := 5.0
const MANUAL_WARMUP := 1.2
const MANUAL_WINDOW := 2.5

signal finished(report: Dictionary)

static var inst: GfxBench = null

var mode: String = "primera"
## Umbrales y tiempos de esta medición (las pruebas los cambian).
var floor_fps: Dictionary = FLOOR_FPS
var warmup: float = WARMUP
var window: float = WINDOW
var report: Dictionary = {}
var _state: String = "espera"
var _t: float = 0.0
var _frames: int = 0
var _last_usec: int = 0
var _acc: float = 0.0
var _steps: int = 0
var _queue: Array[String] = []
var _results: Dictionary = {}
var _prev_level: String = ""


static func first_run(tree: SceneTree) -> void:
	if OS.has_feature("web") or bool(GfxSettings.global("gfx_bench_hecho")) or bool(Loc.get_setting("quality_user", false)):
		return
	if is_instance_valid(inst):
		return
	inst = GfxBench.new()
	inst.mode = "primera"
	tree.root.add_child.call_deferred(inst)


## Medición a pedido. Devuelve el nodo (señal `finished`) o null si no hay piso cargado.
static func manual(tree: SceneTree) -> GfxBench:
	if not has_floor(tree):
		return null
	if is_instance_valid(inst):
		inst.queue_free()
	inst = GfxBench.new()
	inst.mode = "manual"
	tree.root.add_child(inst)
	return inst


static func has_floor(tree: SceneTree) -> bool:
	var b := GfxQuality.live_building(tree)
	return b != null and b.floor_node != null and is_instance_valid(b.floor_node)


func _ready() -> void:
	name = "GfxBench"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == "manual":
		_prev_level = GfxQuality.level()
		_queue = ["alta", "media", "baja"]
		_next_manual()


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _reset(state: String) -> void:
	_state = state
	_t = 0.0
	_frames = 0
	_acc = 0.0
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_usec) / 1000000.0
	_last_usec = now
	if mode == "primera":
		_first(dt)
	else:
		_manual(dt)


## ¿Se está jugando? (Piso cargado, sin pausa, turno en marcha y sin cambio de piso a medias.)
func _playing() -> bool:
	return has_floor(get_tree()) and not get_tree().paused and GameState.running and not GameState.shift_over


func _measure(dt: float, warm: float, window: float) -> float:
	_t += dt
	if _t < warm:
		return -1.0
	if dt < 0.25:
		_frames += 1
		_acc += dt
	if _acc < window:
		return -1.0
	return float(_frames) / maxf(_acc, 0.001)


func _first(dt: float) -> void:
	if bool(Loc.get_setting("quality_user", false)):
		_finish_first(false)  # el jugador eligió a mano mientras tanto: manda él
		return
	if not _playing():
		_reset("espera")
		return
	if _state == "espera":
		_reset("midiendo")
		return
	var fps := _measure(dt, warmup, window)
	if fps < 0.0:
		return
	var lv := GfxQuality.level()
	_results[lv] = fps
	var need := float(floor_fps.get(lv, 0.0))
	if fps < need and _steps < 2:
		_steps += 1
		var down := "media" if lv == "alta" else "baja"
		Loc.set_setting("quality", down)
		GfxQuality.apply(get_tree(), down)
		EventBus.settings_changed.emit("quality")
		_reset("espera")
		return
	_finish_first(_steps > 0)


func _finish_first(changed: bool) -> void:
	GfxSettings.set_global("gfx_bench_hecho", true)
	report = {"modo": "primera", "fps": _results, "elegida": GfxQuality.level(), "bajo": changed}
	print("[gfx] medición del primer turno: %s" % JSON.stringify(report))
	if changed:
		GfxBoot.strings()
		EventBus.show_message.emit(tr("GFX_BENCH_AUTO") % tr(GfxQuality.label_key(GfxQuality.level())), 7.0)
	finished.emit(report)
	queue_free()


func _next_manual() -> void:
	if _queue.is_empty():
		_finish_manual()
		return
	var lv: String = _queue[0]
	GfxQuality.apply(get_tree(), lv)
	_reset("midiendo")


func _manual(dt: float) -> void:
	if _state != "midiendo":
		return
	if not has_floor(get_tree()):
		_queue.clear()
		GfxQuality.apply(get_tree(), _prev_level)
		report = {"modo": "manual", "fps": _results, "elegida": _prev_level, "cancelada": true}
		finished.emit(report)
		queue_free()
		return
	var fps := _measure(dt, MANUAL_WARMUP, MANUAL_WINDOW)
	if fps < 0.0:
		return
	_results[_queue[0]] = fps
	_queue.remove_at(0)
	_next_manual()


func _finish_manual() -> void:
	_state = "fin"
	var pick := "baja"
	for lv in ["alta", "media", "baja"]:
		if float(_results.get(lv, 0.0)) >= float(TARGET_FPS[lv]):
			pick = lv
			break
	Loc.set_setting("quality", pick)
	Loc.set_setting("quality_user", true)
	GfxSettings.set_global("gfx_bench_hecho", true)
	GfxQuality.apply(get_tree(), pick)
	EventBus.settings_changed.emit("quality")
	report = {"modo": "manual", "fps": _results, "elegida": pick}
	print("[gfx] medición a pedido: %s" % JSON.stringify(report))
	finished.emit(report)
	queue_free()


## Elección pura para las pruebas: la calidad más alta que llega a su objetivo.
static func pick_level(fps: Dictionary) -> String:
	for lv in ["alta", "media", "baja"]:
		if float(fps.get(lv, 0.0)) >= float(TARGET_FPS[lv]):
			return lv
	return "baja"

class_name Dread
extends RefCounted
## Nivel de "presión" del momento (0 = calma, 1 = te están cazando), para la presentación del mundo
## (v0.3 P2, dirección de Joan 13:37: "que se sienta la presión, desesperación y daño psicológico").
## Lo leen las luces del piso (FloorBase: se atenúan y parpadean más), el etalonaje de pantalla
## (Overlays: más frío, viñeta más cerrada), el FOV del jugador (se estrecha un poco) y los carteles que
## "cambian" cuando no los miras. No tiene reglas: solo mira la Fatiga, el escalón de disciplina más alto
## (Discipline, P3) y el estado de Shero / del RTA. Barato: se calcula como mucho 10 veces por segundo.

static var _cache: float = 0.0
static var _cache_ms: int = -1000
## Forzado para capturas/pruebas (-1 = sin forzar).
static var forced: float = -1.0


static func level() -> float:
	if forced >= 0.0:
		return forced
	var now := Time.get_ticks_msec()
	if now - _cache_ms < 100:
		return _cache
	_cache_ms = now
	_cache = _compute()
	return _cache


## Solo la Fatiga (0..1): desde 40 empieza a pesar, a 95 es máxima.
static func fatigue_part() -> float:
	return clampf((Fatigue.value - 40.0) / 55.0, 0.0, 1.0)


## Enojo (0..1): escalón de Discipline (llamado 0,2 · verbal 0,4 · WW 0,65 · persecución 1) o Shero/RTA.
static func anger_part() -> float:
	var a := 0.0
	var por_pista: Variant = Discipline.counters.get("por_pista", {})
	if por_pista is Dictionary:
		for k in (por_pista as Dictionary).keys():
			var st := int((por_pista as Dictionary)[k])
			a = maxf(a, [0.0, 0.2, 0.4, 0.65, 1.0, 1.0][clampi(st, 0, 5)])
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var sh := tree.get_first_node_in_group("shero")
		if sh != null:
			var s := int(sh.get("state"))  # Shero.State: OBSERVAR, ESCRIBIR, CAMINAR, COACHING, PERSEGUIR, SCREAMER
			a = maxf(a, [0.0, 0.25, 0.5, 0.35, 1.0, 1.0][clampi(s, 0, 5)])
		var rta := tree.get_first_node_in_group("rta")
		if rta != null and rta.has_method("is_hunting") and bool(rta.call("is_hunting")):
			a = maxf(a, 0.85)
	return a


static func _compute() -> float:
	if not GameState.running and not Checkpoints.dying:
		return 0.0
	var f := fatigue_part()
	var a := anger_part()
	# El enojo pesa más que el cansancio; juntos se suman con techo.
	return clampf(maxf(a, f * 0.75) + minf(a, f) * 0.25, 0.0, 1.0)

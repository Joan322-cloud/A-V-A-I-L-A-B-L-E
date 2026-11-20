class_name Days
extends RefCounted
## v0.3.2 · La semana (docs/AVAILABLE_trama_semana): el número de turno sigue siendo el mismo entero de siempre
## (las partidas de la v0.3 no se migran) y aquí se traduce a su día: 0 = Training (domingo 8), 1 = Lunes 9,
## 2 = Martes 10, 3 = Miércoles 11, 4 = Jueves 12, 5 = Viernes 13, 6 = Sábado 14, 7 = Domingo 15 (descanso y
## finales). Los nombres y las fechas viven en data/turnos.json (campos dia, nombre, fecha, corto, titulo).
## API: Days.day_name(n) «Lunes» · Days.full(n) «Lunes 9 de noviembre» · Days.short(n) «LUN 9 NOV» ·
##      Days.title(n) «Primera amanecida» · Days.id(n) «lunes» · Days.week() (lista de los 8) · Days.LAST_SHIFT.

const TRAINING := 0
const FIRST_SHIFT := 1
const LAST_SHIFT := 6  # sábado: el último turno
const SUNDAY := 7


static func _entry(n: int) -> Dictionary:
	for t in DataLoader.list("turnos"):
		if int(t.get("turno", -1)) == n:
			return t
	return {}


static func _pick(n: int, key: String, fallback: String) -> String:
	var e := _entry(n)
	var v: Variant = e.get(key, null)
	if v is Dictionary:
		var s := Loc.pick(v)
		if s != "":
			return s
	return fallback


## «Lunes». El Training (0) se llama «Training».
static func day_name(n: int) -> String:
	if n == TRAINING:
		return TranslationServer.translate("DAY_TRAINING")
	return _pick(n, "nombre", Loc.fmt(TranslationServer.translate("DAY_FALLBACK"), {"n": n}))


## «Lunes 9 de noviembre» (EN «Monday, November 9»).
static func full(n: int) -> String:
	return _pick(n, "fecha", day_name(n))


## «LUN 9 NOV» (HUD).
static func short(n: int) -> String:
	return _pick(n, "corto", day_name(n).to_upper())


## Título de la noche: «Primera amanecida», «Actualización de campaña»…
static func title(n: int) -> String:
	return _pick(n, "titulo", "")


static func id(n: int) -> String:
	return str(_entry(n).get("dia", "dia_%d" % n))


## Los 8 días de la semana (Training + lunes a sábado + domingo) con su número, nombre, fecha y si se juegan.
static func week() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in DataLoader.list("turnos"):
		var n := int(t.get("turno", -1))
		if n < 0:
			continue
		out.append({"n": n, "id": id(n), "nombre": day_name(n), "fecha": full(n), "corto": short(n),
			"habilitado": bool(t.get("habilitado", false)), "descanso": bool(t.get("descanso", false))})
	return out

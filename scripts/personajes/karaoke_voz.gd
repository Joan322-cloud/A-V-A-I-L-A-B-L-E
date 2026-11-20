class_name KaraokeVoz
extends RefCounted
## v0.3.2 (Joan: «las canciones del karaoke: lo que se canta debe corresponder a los subtítulos»). Índice de las voces
## CANTADAS del karaoke de Rasec. data/karaoke_voz.json lo escribe tools/v032_karaoke_voz.py al sintetizar: por verso
## e idioma, el texto que se canta (= la letra de data/rasec_eventos.json, letra por letra), su duración, el md5 del
## archivo y las marcas de tiempo de cada sílaba. Regla: la letra que se ve mientras suena el verso ES el `texto` de
## su voz; si la letra de los datos cambia y no se vuelve a cantar, la prueba fbk_letra_voz falla.
##   · Tono y tempo: Do mayor, 108 pulsos por minuto, los de `musica/rasec_karaoke` (tools/sfx_gen_p6.py). Cada verso
##     entra en un compás de la pista (bar_wait).
##   · El último verso viene ya frenado ×SLOW: RasecControl frena la pista con pitch_scale = SLOW en ese verso y voz
##     y pista bajan juntas, como una cinta que se para.

const DATA := "karaoke_voz"
const SLOW := 0.62
const BPM := 108.0
const BAR_S := 4.0 * 60.0 / BPM  # 2,222 s
## La pista dura 15,1 compases (el bucle se funde 2 s): un verso de 2 compases no puede empezar después del 13.º, o
## cruzaría la costura del bucle con la cuadrícula corrida.
const LOOP_BARS := 15


static func _versos() -> Array:
	return DataLoader.dict(DATA).get("versos", []) as Array


static func count() -> int:
	return _versos().size()


static func slot(i: int) -> String:
	if i < 0 or i >= _versos().size():
		return ""
	return str((_versos()[i] as Dictionary).get("slot", ""))


## Datos del verso `i` en el idioma (EN si existe; si no, ES, como AudioManager.voice_path): {texto, dur, canto, md5,
## marcas}. {} si no hay voz.
static func verse(i: int, lang: String = "") -> Dictionary:
	if i < 0 or i >= _versos().size():
		return {}
	var v: Dictionary = _versos()[i]
	var l := lang if lang != "" else Loc.language
	if v.has(l):
		return v[l] as Dictionary
	return v.get("es", {}) as Dictionary


## ¿Hay voz cantada para el verso `i` (dato y archivo)?
static func has_voice(i: int) -> bool:
	return slot(i) != "" and not verse(i).is_empty() and AudioManager.voice_path(slot(i)) != ""


## Letras de `texto` ya cantadas a los `t` segundos de empezar la voz (para pintar la letra a medida que se canta).
static func chars_at(marks: Array, t: float) -> int:
	var n := 0
	for m in marks:
		var a := m as Array
		if a.size() >= 3 and t >= float(a[0]):
			n = int(a[2])
	return n


## Segundos de PISTA (posición del reproductor) que faltan para el próximo compás en el que cabe un verso de `bars`
## compases, estando la pista en `pos` (s) de un bucle de `loop_s`. Nunca menos de `min_s`.
static func bar_wait(pos: float, loop_s: float, bars: int = 2, min_s: float = 0.08) -> float:
	var last_ok := float(LOOP_BARS - bars) * BAR_S  # último compás en el que el verso cabe antes de la costura
	var k := ceilf((pos + min_s) / BAR_S)
	var t := k * BAR_S
	if t > last_ok + 0.001:
		return maxf(loop_s - pos, min_s)  # espera a que la pista vuelva a empezar
	return maxf(t - pos, min_s)

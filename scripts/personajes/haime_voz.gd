class_name HaimeVoz
extends RefCounted
## v0.3.2 (Joan: «lo que dice Haime no concuerda con los subtítulos»): índice de las voces de Haime.
## data/haime_voz.json lo escribe tools/h2_voz_index.py después de sintetizar (Kokoro, cast de Haime, -16 LUFS): por cada
## voces/haime/[en/]<id>.ogg guarda el texto EXACTO con el que se sintetizó, su duración y el md5 del archivo instalado.
## Regla: el subtítulo de una línea hablada de Haime ES ese texto (spoken()); si el dato y la voz se separan, manda la voz
## (y la prueba h2_subtitulos_voz falla). Sin marcadores ({score}, {min}, {agente}): el puntaje se ve en la pantalla.

const DATA := "haime_voz"


static func _voces() -> Dictionary:
	return DataLoader.dict(DATA).get("voces", {}) as Dictionary


static func has(id: String) -> bool:
	return _voces().has(id)


static func _lang(lang: String) -> String:
	return lang if lang != "" else Loc.language


## Texto con el que se sintetizó la voz `id` en el idioma (EN si existe; si no, ES, como voice_path). "" si no hay voz.
static func text(id: String, lang: String = "") -> String:
	var v: Dictionary = _voces().get(id, {})
	var l := _lang(lang)
	if v.has(l):
		return str((v[l] as Dictionary).get("texto", ""))
	if v.has("es"):
		return str((v["es"] as Dictionary).get("texto", ""))
	return ""


## Duración (s) del archivo de la voz en el idioma; `fallback` si no hay voz.
static func duration(id: String, lang: String = "", fallback: float = -1.0) -> float:
	var v: Dictionary = _voces().get(id, {})
	var l := _lang(lang)
	var e: Dictionary = v.get(l, v.get("es", {}))
	return float(e.get("dur", fallback)) if not e.is_empty() else fallback


## El subtítulo de una línea hablada: el texto de su voz si existe; si no, el del dato (línea sin voz).
static func spoken(id: String, data_text: String) -> String:
	var t := text(id)
	if t == "":
		return data_text
	if t != data_text and OS.is_debug_build() and data_text != "":
		push_warning("HaimeVoz: «%s» difiere de su voz; se muestra lo que dice la voz" % id)
	return t


## v0.3.2 (ritmo): segundo en que Haime TERMINA DE HABLAR en la toma («fin» del índice: el último tramo por encima de
## −45 dB + 60 ms). Cada archivo trae ~0,3 s de cola (silencio y reverb); la calibración no la espera: la línea
## siguiente entra ahí. Sin el dato, la duración del archivo.
static func speech_end(id: String, lang: String = "") -> float:
	var v: Dictionary = _voces().get(id, {})
	var e: Dictionary = v.get(_lang(lang), v.get("es", {}))
	if e.is_empty():
		return -1.0
	var d := float(e.get("dur", -1.0))
	return clampf(float(e.get("fin", d)), minf(0.2, d), d)


## Lo que tarda en decir una línea (s): hasta que deja de hablar; sin voz, por largo del texto.
static func talk(id: String, text_v: String) -> float:
	var d := speech_end(id)
	return d if d > 0.0 else estimate(id, text_v)


## Duración estimada de una línea (s): la de su voz o, sin voz, por largo del texto.
static func estimate(id: String, text_v: String) -> float:
	var d := duration(id)
	if d > 0.0:
		return d
	return clampf(0.8 + text_v.length() * 0.062, 1.0, 7.0)

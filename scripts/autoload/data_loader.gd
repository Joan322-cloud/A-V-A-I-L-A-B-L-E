extends Node
## DataLoader: lee los JSON de res://data/ una sola vez y los cachea.

const DATA_DIR := "res://data/"

var _cache: Dictionary = {}


func load_json(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	var path := DATA_DIR + name + ".json"
	if not FileAccess.file_exists(path):
		push_error("DataLoader: no existe %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: no se pudo abrir %s" % path)
		return null
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err != OK:
		push_error("DataLoader: error en %s línea %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	_cache[name] = json.data
	return json.data


## Atajo: devuelve un Dictionary (o {} si falla).
func dict(name: String) -> Dictionary:
	var d: Variant = load_json(name)
	return d if d is Dictionary else {}


## Atajo: devuelve un Array (o [] si falla).
func list(name: String) -> Array:
	var d: Variant = load_json(name)
	return d if d is Array else []


## Lee un valor anidado de balance.json: bal("reloj/contacto", 12.0).
func bal(path: String, default: Variant = null) -> Variant:
	var cur: Variant = dict("balance")
	for part in path.split("/"):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return default
	return cur


func clear_cache() -> void:
	_cache.clear()

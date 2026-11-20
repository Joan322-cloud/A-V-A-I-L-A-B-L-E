## Sin class_name: check_all.gd y los escenarios lo cargan con load() solo en modo herramienta.
extends RefCounted
## Regla de nombres (v0.3.2-core): nada del mundo real en el árbol del proyecto, no solo en game/.
## `--check-all` falla si en CUALQUIER archivo del repositorio (game/, docs/, tools/, steam/…) aparece:
##   1. un nombre prohibido (los nombres reales de la primera versión o una empresa real), en el texto o en la ruta;
##   2. cualquier archivo bajo docs/ref/ (las fotos y caras de referencia no van en el repositorio).
## La lista va PARTIDA a propósito (este archivo también se revisa). Lo mismo, más los archivos retirados que
## vuelven con otro nombre y el historial de git, lo hace tools/check_nombres.py (que usa package_release.sh).
##   var g = load("res://scripts/dev/name_guard.gd").new()
##   g.scan_tree(g.repo_root())  → ["ruta: motivo", …]   (vacío = limpio)
##   g.scan_text("…")            → palabras encontradas, enmascaradas («p***a»)

const TEXT_EXT: Array[String] = ["gd", "gdshader", "tscn", "tres", "json", "csv", "md", "txt", "cfg", "godot", "py", "sh", "bat",
	"vdf", "nsi", "js", "html", "c", "h", "svg", "yml", "yaml", "toml", "ini", "xml", "css", "gitignore"]
const ZIP_DOC_EXT: Array[String] = ["docx", "xlsx", "pptx", "odt", "ods"]
## Carpetas que no son del proyecto (salidas, caché, el modelo de voz de terceros).
const SKIP_DIRS: Array[String] = [".git", "game/.godot", "builds", "dist", "tools/asr_sidecar/dist", "tools/__pycache__", "node_modules"]
const REF_DIR := "docs/ref/"
const LETTERS := "A-Za-zÁÉÍÓÚÜáéíóúüñÑ0-9_"

var files_checked: int = 0
var _rx_ci := RegEx.new()
var _rx_cs := RegEx.new()
var _rx_tag := RegEx.new()


func _init() -> void:
	# Palabra entera, sin distinguir mayúsculas.
	var ci: Array[String] = ["che" + "ro", "hiro" + "shi", "yau" + "ri", "en" + "zo", "bit" + "so", "te" + "laris", "web" + "help"]
	# También son palabras comunes: solo cuentan con mayúscula inicial o todo en mayúsculas.
	var cs: Array[String] = ["Mar" + "co", "To" + "m", "MAR" + "CO", "TO" + "M"]
	_rx_ci.compile("(?i)(?<![%s])(%s)(?![%s])" % [LETTERS, "|".join(ci), LETTERS])
	_rx_cs.compile("(?<![%s])(%s)(?![%s])" % [LETTERS, "|".join(cs), LETTERS])
	_rx_tag.compile("<[^>]+>")


static func mask(w: String) -> String:
	return w if w.length() < 3 else w[0] + "*".repeat(w.length() - 2) + w[w.length() - 1]


## Palabras prohibidas que hay en el texto (enmascaradas, sin repetir).
func scan_text(txt: String) -> PackedStringArray:
	var out := PackedStringArray()
	if txt == "":
		return out
	for m in _rx_ci.search_all(txt):
		var w := mask(m.get_string(1).to_lower())
		if not out.has(w):
			out.append(w)
	for m in _rx_cs.search_all(txt):
		var w := mask(m.get_string(1))
		if not out.has(w):
			out.append(w)
	return out


## La raíz del repositorio (la carpeta que contiene game/) o "" si no la hay (build exportado).
func repo_root() -> String:
	var game_dir := ProjectSettings.globalize_path("res://")
	if game_dir == "" or not DirAccess.dir_exists_absolute(game_dir):
		return ""
	var root := game_dir.path_join("..").simplify_path()
	return root if DirAccess.dir_exists_absolute(root.path_join("docs")) or FileAccess.file_exists(root.path_join(".gitignore")) else ""


## Revisa una carpeta entera. Devuelve los problemas como "ruta: motivo".
func scan_tree(root: String) -> Array[String]:
	var out: Array[String] = []
	files_checked = 0
	if root == "":
		return out
	_walk(root, "", out)
	return out


func _walk(root: String, rel: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root.path_join(rel) if rel != "" else root)
	if dir == null:
		return
	dir.include_hidden = true
	var names: Array[String] = []
	var dirs: Array[String] = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if n != "." and n != "..":
			if dir.current_is_dir():
				dirs.append(n)
			else:
				names.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	names.sort()
	dirs.sort()
	for f in names:
		_check_file(root, (rel + "/" + f).trim_prefix("/"), out)
	for d in dirs:
		var sub := (rel + "/" + d).trim_prefix("/")
		if sub in SKIP_DIRS:
			continue
		_walk(root, sub, out)


func _check_file(root: String, rel: String, out: Array[String]) -> void:
	files_checked += 1
	if rel.begins_with(REF_DIR) or rel.contains("/" + REF_DIR):
		out.append("%s: está bajo docs/ref/ (referencias del mundo real)" % rel)
	var in_name := scan_text(rel)
	if not in_name.is_empty():
		out.append("%s: nombre prohibido en la ruta (%s)" % [rel, ", ".join(in_name)])
	var ext := rel.get_extension().to_lower()
	var txt := ""
	if ext in TEXT_EXT or rel.get_file().begins_with("LEEME") or rel.get_file().begins_with("README"):
		txt = FileAccess.get_file_as_string(root.path_join(rel))
	elif ext in ZIP_DOC_EXT:
		txt = _zip_text(root.path_join(rel))
	if txt == "":
		return
	var hits := scan_text(txt)
	if not hits.is_empty():
		out.append("%s: nombre prohibido en el contenido (%s)" % [rel, ", ".join(hits)])


## El texto de un documento de ofimática (zip con XML dentro).
func _zip_text(path: String) -> String:
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return ""
	var parts := PackedStringArray()
	for f in z.get_files():
		if f.ends_with(".xml") or f.ends_with(".rels"):
			parts.append(_rx_tag.sub(z.read_file(f).get_string_from_utf8(), " ", true))
	z.close()
	return " ".join(parts)

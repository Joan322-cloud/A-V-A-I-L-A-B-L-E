## Sin class_name: main.gd lo carga con load() solo en modo herramienta.
extends RefCounted
## check_all: carga todos los .gd y .tscn del proyecto (con los autoloads vivos) y reporta errores.
## Uso: godot --headless --path game -- --check-all   (scripts/dev/, lo invoca main.gd y sale con código 1 si hay errores)
## v0.3: además comprueba que cada causa de muerte usada en el código exista en data/muertes.json (con
## motivo ES/EN), que los JSON de data/ parseen, y corre tools/arboles_contactos.py sobre los árboles.
## v0.3.2-core: además la REGLA DE NOMBRES en todo el repositorio, no solo en game/ (name_guard.gd): ningún nombre
## real ni empresa real en un texto o una ruta, nada bajo docs/ref/, y tools/check_nombres.py (archivos retirados
## que vuelven con otro nombre).

var errors: int = 0
var checked: int = 0


func run() -> int:
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	for f in files:
		checked += 1
		if f.ends_with(".gd"):
			_check_script(f)
		elif f.ends_with(".tscn"):
			_check_scene(f)
	_check_data_json()
	_check_death_causes(files)
	_check_trees()
	_check_names()
	_check_translations()
	print("check_all: %d archivos revisados, %d errores" % [checked, errors])
	return errors


## Todos los .json de res://data/ deben parsear.
func _check_data_json() -> void:
	var d := DirAccess.open("res://data/")
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var txt := FileAccess.get_file_as_string("res://data/" + f)
		var j := JSON.new()
		if j.parse(txt) != OK:
			errors += 1
			printerr("ERROR json no parsea: res://data/%s línea %d: %s" % [f, j.get_error_line(), j.get_error_message()])


## Cada causa pedida en el código (death_requested.emit(<causa>), request_death(<causa>[, detalle, <asesino>]),
## _request_kill(<causa>), _quota_cause/_pending_reason = <causa>, t.die(<causa>), Pursuit.start(<cazador>, <causa>)
## y P5Pursuit.start(<cazador>, <causa>) —el asesino es el cazador—, y las muertes de data/escalada.json con su
## ejecutor) debe existir en muertes.json con motivo es/en y asesino; el asesino que el código pide debe ser el de
## muertes.json o tener su fila "causa@asesino" en screamers.json; y toda muerte con asesino (salvo colapso) debe
## tener su screamer: fila de la causa en screamers.json con ese asesino (o "causa@asesino") y la del asesino en
## por_asesino.
func _check_death_causes(files: Array[String]) -> void:
	var known: Dictionary = {}
	for c in DataLoader.list("muertes"):
		var id := str(c.get("id", ""))
		var mot: Variant = c.get("motivo", {})
		if not (mot is Dictionary) or str(mot.get("es", "")) == "" or str(mot.get("en", "")) == "":
			errors += 1
			printerr("ERROR muertes.json: '%s' sin motivo es/en" % id)
		if not c.has("quien"):
			errors += 1
			printerr("ERROR muertes.json: '%s' sin 'quien' (asesino)" % id)
		elif c.has("screamer") and str(c.get("screamer", "")) != "" and str(c.get("screamer", "")) != str(c.get("quien", "")):
			errors += 1
			printerr("ERROR muertes.json: '%s' con screamer '%s' distinto de su asesino '%s'" % [id, str(c.get("screamer", "")), str(c.get("quien", ""))])
		known[id] = str(c.get("quien", ""))
	var re := RegEx.new()
	re.compile("(?:death_requested\\.emit|request_death|_request_kill|\\.die)\\(\\s*\"([a-z0-9_]+)\"(?:\\s*,[^,\\n]*,\\s*\"([a-z0-9_]+)\")?|(?:_quota_cause|_pending_reason)\\s*=\\s*\"([a-z0-9_]+)\"")
	var re_hunt := RegEx.new()
	re_hunt.compile("\\bP?5?Pursuit\\.start\\(\\s*\"([a-z0-9_]+)\"\\s*,\\s*\"([a-z0-9_]+)\"")
	var used: Dictionary = {}  # causa → archivo
	var pairs: Dictionary = {}  # "causa|asesino" → archivo ("" = el de muertes.json)
	for f in files:
		if not f.ends_with(".gd") or f == "res://scripts/dev/check_all.gd":
			continue
		var txt := FileAccess.get_file_as_string(f)
		for m in re.search_all(txt):
			var cause := m.get_string(1) if m.get_string(1) != "" else m.get_string(3)
			if cause != "":
				used[cause] = f
				pairs[cause + "|" + m.get_string(2)] = f
		for m in re_hunt.search_all(txt):
			used[m.get_string(2)] = f
			pairs[m.get_string(2) + "|" + m.get_string(1)] = f
	var esc: Dictionary = DataLoader.dict("escalada").get("pistas", {})
	for tr_id in esc.keys():
		var pista: Dictionary = esc[tr_id]
		var cause := str(pista.get("muerte", ""))
		if cause != "":
			used[cause] = "data/escalada.json/" + str(tr_id)
			pairs[cause + "|" + str(pista.get("ejecutor", ""))] = "data/escalada.json/" + str(tr_id)
	var scr: Dictionary = DataLoader.dict("screamers")
	var rows: Dictionary = scr.get("causas", {})
	var by_killer: Dictionary = scr.get("por_asesino", {})
	for cause in used.keys():
		if not known.has(cause):
			errors += 1
			printerr("ERROR causa de muerte '%s' (%s) no está en muertes.json" % [cause, used[cause]])
	for key in pairs.keys():
		var cause := str(key).get_slice("|", 0)
		var killer := str(key).get_slice("|", 1)
		if not known.has(cause):
			continue
		var own := str(known[cause])
		if killer == "":
			killer = own
		elif killer != own and not rows.has(cause + "@" + killer):
			errors += 1
			printerr("ERROR muerte '%s' con asesino '%s' (%s): muertes.json dice '%s' y screamers.json no tiene '%s@%s'" % [cause, killer, pairs[key], own, cause, killer])
			continue
		if not Checkpoints.uses_screamer(killer) or (known.has(cause) and cause == "reflejo_kyc"):
			continue
		var row: Dictionary = rows.get(cause + "@" + killer, rows.get(cause, {}))
		if row.is_empty() or str(row.get("asesino", killer)) not in [killer, ""]:
			errors += 1
			printerr("ERROR muerte '%s' (asesino %s, %s) sin su screamer en screamers.json" % [cause, killer, pairs[key]])
		elif not by_killer.has(killer):
			errors += 1
			printerr("ERROR screamers.json/por_asesino sin '%s' (muerte '%s')" % [killer, cause])
	print("check_all: %d causas de muerte usadas en el código (%d pares causa/asesino), todas en muertes.json con su asesino y su screamer" % [used.size(), pairs.size()] if errors == 0 else "check_all: causas revisadas")


## tools/arboles_contactos.py sobre los borradores (docs/v0.3/datos) y los contactos con árbol de data/ (P4).
func _check_trees() -> void:
	var game_dir := ProjectSettings.globalize_path("res://")
	var root := game_dir.path_join("..").simplify_path()
	var tool := root.path_join("tools/arboles_contactos.py")
	if not FileAccess.file_exists(tool):
		print("check_all: (sin tools/arboles_contactos.py en este build: árboles no validados)")
		return
	var targets: Array[String] = []
	var drafts := root.path_join("docs/v0.3/datos")
	var dd := DirAccess.open(drafts)
	if dd != null:
		for f in dd.get_files():
			if f.ends_with("_arbol.json"):
				targets.append(drafts.path_join(f))
	var data := DirAccess.open("res://data/")
	if data != null:
		for f in data.get_files():
			if (f.begins_with("contactos_t") or f == "tutorial.json") and f.ends_with(".json") and FileAccess.get_file_as_string("res://data/" + f).contains("\"nodos\""):
				targets.append(ProjectSettings.globalize_path("res://data/" + f))
	if targets.is_empty():
		return
	var out: Array = []
	var code := OS.execute("python3", ["-I", tool] + targets, out, true)
	var text := "".join(out).strip_edges()
	if code == -1 or code == 127:
		print("check_all: (python3 no disponible: árboles no validados)")
		return
	print("check_all: arboles_contactos.py → ", text.get_slice("\n", text.count("\n")) if text != "" else "?")
	if code != 0:
		errors += 1
		printerr("ERROR árboles de contactos:\n", text)


## v0.3.2-core: las traducciones se importan SIN comprimir (compress=0 en localization/*.csv.import). Comprimidas no
## guardan las claves y Loc.retranslate no puede pasar al idioma nuevo los textos ya construidos (la PC se queda en el
## idioma con el que se abrió el juego). Un .csv nuevo trae compress=1 por defecto: cambiarlo y reimportar.
func _check_translations() -> void:
	var d := DirAccess.open("res://localization")
	if d == null:
		return
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".csv.import"):
			continue
		var txt := FileAccess.get_file_as_string("res://localization/" + f)
		if not txt.contains("[params]"):
			continue  # exportado: el .import solo trae el remap (que las claves vienen se comprueba abajo)
		n += 1
		if not txt.contains("compress=0"):
			errors += 1
			printerr("ERROR traducciones: localization/%s se importa comprimido (pon compress=0 y reimporta con --import)" % f)
	for path in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		var t := load(str(path)) as Translation
		if t != null and t.get_message_count() > 0 and t.get_message_list().is_empty():
			errors += 1
			printerr("ERROR traducciones: %s no trae sus claves (reimporta con --import tras poner compress=0)" % str(path))
	print("check_all: traducciones → %d .csv sin comprimir" % n)


## Regla de nombres en todo el repositorio (game/, docs/, tools/, steam/…): ver name_guard.gd.
func _check_names() -> void:
	var guard: RefCounted = (load("res://scripts/dev/name_guard.gd") as GDScript).new()
	var root := str(guard.call("repo_root"))
	if root == "":
		root = ProjectSettings.globalize_path("res://")
		if root == "" or not DirAccess.dir_exists_absolute(root):
			print("check_all: (sin árbol de archivos en este build: regla de nombres no revisada)")
			return
	var problems: Array[String] = guard.call("scan_tree", root)
	for p in problems:
		errors += 1
		printerr("ERROR regla de nombres: ", p)
	print("check_all: regla de nombres → %d archivos del repositorio, %d problemas" % [int(guard.get("files_checked")), problems.size()])
	var tool := root.path_join("tools/check_nombres.py")
	if not FileAccess.file_exists(tool):
		return
	var out: Array = []
	var code := OS.execute("python3", ["-I", tool, "--max", "40"], out, true)
	var text := "".join(out).strip_edges()
	if code == -1 or code == 127:
		print("check_all: (python3 no disponible: tools/check_nombres.py no se corrió)")
		return
	print("check_all: ", text.get_slice("\n", text.count("\n")) if text != "" else "check_nombres.py → ?")
	if code != 0:
		errors += 1
		printerr("ERROR regla de nombres (tools/check_nombres.py):\n", text)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if n.begins_with("."):
			n = dir.get_next()
			continue
		var p := dir_path.path_join(n)
		if dir.current_is_dir():
			_collect(p, out)
		elif n.ends_with(".gd") or n.ends_with(".tscn"):
			out.append(p)
		n = dir.get_next()
	dir.list_dir_end()


func _check_script(path: String) -> void:
	var res: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REUSE)
	var gd := res as GDScript
	if gd == null:
		errors += 1
		printerr("ERROR script no carga: ", path)
		return
	# No se recarga (reload) porque los autoloads ya están vivos; cargar ya compila.
	if not gd.can_instantiate() and not gd.is_abstract():
		errors += 1
		printerr("ERROR script no instanciable: ", path)


func _check_scene(path: String) -> void:
	var packed: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	var ps := packed as PackedScene
	if ps == null:
		errors += 1
		printerr("ERROR escena no carga: ", path)
		return
	if path == "res://scenes/main/Main.tscn":
		return  # ya está corriendo
	var inst := ps.instantiate()
	if inst == null:
		errors += 1
		printerr("ERROR escena no instancia: ", path)
	else:
		inst.free()

extends Node
## Loc: idioma actual (es/en) y ayudas de formato. Todo texto visible pasa por tr().

## El idioma cambió con el juego abierto (después de retraducir los textos fijos): quien dibuja con caché se redibuja.
signal language_changed(code: String)
signal key_hints_changed()  # v0.3.2-core: cambió una tecla y las traducciones ya traen las pistas nuevas

const LANGS: Array[String] = ["es", "en"]
const SETTINGS_PATH := "user://settings.json"

var language: String = "es"
const DISPLAY_V := 1  # versión de la elección de pantalla guardada en settings.json («display_v»)
var _file_has_fullscreen: bool = false  # ¿settings.json ya trae una elección de pantalla de ESTA versión? (si no, es la primera vez)
var settings: Dictionary = {
	"fov": 75.0,
	"headbob": 1.0,
	"subtitles": true,
	"help_hud": false,
	"ack_extra": false,
	"flash_reduction": false,
	"screamer_warn": false,
	"sensitivity": 1.0,
	"grain": true,
	"fullscreen": false,
	"vol_master": 1.0,
	"vol_auricular": 1.0,
	"vol_sala": 1.0,
	"vol_ambiente": 1.0,
	"vol_ui": 1.0,
	"bindings": {},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Alt+Intro (pantalla completa) también con el juego en pausa
	_load_settings()
	_first_launch_display()
	# P7: `-- --lang en|es` (capturas y pruebas en inglés sin tocar settings.json a mano)
	var args := OS.get_cmdline_user_args()
	var li := args.find("--lang")
	if li >= 0 and li + 1 < args.size() and LANGS.has(args[li + 1]):
		language = args[li + 1]
	set_language(language)


func set_language(code: String) -> void:
	if not LANGS.has(code):
		code = "es"
	var old := language
	language = code
	TranslationServer.set_locale(code)
	_save_settings()
	if old != code and is_inside_tree():
		retranslate(old)
		language_changed.emit(code)


## v0.3.2-core · cambiar de idioma con la interfaz ya construida. La PC (Workstation), el softphone, los avisos de
## primera vez… se construyen UNA vez al abrir el juego con tr(): quien abría en español, pasaba a English en Opciones
## y empezaba un turno veía la PC con «Aceptar [Espacio]», «Enviar», «Dile al cliente…» hasta reiniciar el juego
## (y lo mismo al cambiarlo desde la Pausa). Al cambiar de idioma se recorre el árbol y todo texto FIJO que coincide
## exactamente con una traducción del idioma anterior pasa al nuevo (también «5 Baño», «F2 Correo»: prefijo corto +
## texto). Lo que se arma con formato («AVL 97 %») ya lo redibuja su código en el siguiente cuadro.
## Necesita las claves: los .csv se importan SIN comprimir (compress=0 en localization/*.csv.import; lo vigila
## --check-all). Devuelve cuántos textos cambió.
var retranslated: int = 0
var _rx_prefix: RegEx = null


func retranslate(from: String) -> int:
	retranslated = 0
	var pairs := translation_pairs(from)
	if pairs.is_empty() or not is_inside_tree():
		return 0
	_swap_tree(pairs)
	return retranslated


## Recorre el árbol y cambia cada texto fijo que coincide con una clave de `pairs` por su valor.
func _swap_tree(pairs: Dictionary) -> void:
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children(true))
		if n is Label or n is Button or n is LinkButton or n is Label3D:
			_swap_prop(n, "text", pairs)
		if n is LineEdit or n is TextEdit:
			_swap_prop(n, "placeholder_text", pairs)
		if n is Control and (n as Control).tooltip_text != "":
			_swap_prop(n, "tooltip_text", pairs)


## {texto en el idioma `from`: texto en el idioma actual} de todas las claves cuyo texto cambia entre los dos.
func translation_pairs(from: String) -> Dictionary:
	var out := {}
	for path in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		var t := load(str(path)) as Translation
		if t == null or t.locale != from:
			continue
		for k in t.get_message_list():
			var old := str(t.get_message(k))
			var neu := str(TranslationServer.translate(k))
			if old != "" and old != str(k) and neu != old and neu != str(k) and not out.has(old):
				out[old] = neu
	return out


## El texto en el idioma nuevo, o el mismo si no es un texto fijo traducible.
func swap_text(text: String, pairs: Dictionary) -> String:
	if text == "" or text.length() > 400:
		return text
	if pairs.has(text):
		return str(pairs[text])
	if _rx_prefix == null:
		_rx_prefix = RegEx.new()
		_rx_prefix.compile("^(\\S{1,3}) (.+)$")
	var m := _rx_prefix.search(text)
	if m != null and pairs.has(m.get_string(2)):
		return "%s %s" % [m.get_string(1), str(pairs[m.get_string(2)])]
	return text


func _swap_prop(n: Node, prop: String, pairs: Dictionary) -> void:
	var old := str(n.get(prop))
	var neu := swap_text(old, pairs)
	if neu != old:
		n.set(prop, neu)
		retranslated += 1


## v0.3.2-core · las pistas de teclas siguen el remapeo (ver Controls.hint). Reescribe, en las traducciones cargadas
## de los dos idiomas, cada texto que nombra una tecla entre corchetes con la tecla asignada ahora; guarda el texto de
## fábrica de cada clave para poder volver. Lo que ya está en pantalla y es texto fijo se cambia igual que al cambiar
## de idioma. Lo llama Controls cada vez que cambia una tecla (y al arrancar, con las teclas guardadas).
## Devuelve cuántos textos de traducción cambió.
var _hint_orig: Dictionary = {}  # idioma → {clave: texto de fábrica}

func refresh_key_hints() -> int:
	var changed := 0
	var pairs := {}
	for path in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		var t := load(str(path)) as Translation
		if t == null:
			continue
		var loc := str(t.locale)
		if not _hint_orig.has(loc):
			_hint_orig[loc] = {}
		var orig: Dictionary = _hint_orig[loc]
		for k in t.get_message_list():
			var key := str(k)
			var cur := str(t.get_message(k))
			if not orig.has(key):
				if cur.find("[") < 0 and not Controls.HINT_RANGES.has(key) and not Controls.HINT_BARE_KEYS.has(key):
					continue
				orig[key] = cur
			var neu := Controls.hint_for_key(key, str(orig[key]), loc)
			if neu != cur:
				t.add_message(k, neu)
				changed += 1
				if loc == language and cur != "" and not pairs.has(cur):
					pairs[cur] = neu
	if not pairs.is_empty() and is_inside_tree():
		_swap_tree(pairs)
	if changed > 0:
		key_hints_changed.emit()
	return changed


## El texto de fábrica de una clave en un idioma (antes de cualquier remapeo); "" si no nombra teclas.
func key_hint_original(key: String, loc: String = "") -> String:
	return str((_hint_orig.get(loc if loc != "" else language, {}) as Dictionary).get(key, ""))


## pick() con las pistas de teclas al día: para textos de datos que nombran teclas (el manual del agente).
func pick_hint(d: Variant) -> String:
	return Controls.hint(pick(d))


# --- v0.3.2-core · pantalla completa -----------------------------------------------------------------------
# La primera vez en escritorio el juego abre en pantalla completa sin bordes, a la resolución de la pantalla (en un
# portátil de 1366×768 la ventana de 1280×720 con su barra de título no cabía sobre la barra de tareas). Después manda
# lo que el jugador deje puesto en Opciones o con Alt+Intro, que queda guardado. En el navegador no se toca.

## ¿Abrir en pantalla completa la primera vez? No con herramientas de desarrollo ni si se pidió un tamaño de ventana.
static func first_launch_fullscreen(web: bool, headless: bool, engine_args: PackedStringArray, user_args: PackedStringArray) -> bool:
	if web or headless or not user_args.is_empty():
		return false
	for a in engine_args:
		if str(a) in ["--resolution", "--write-movie", "-w", "--windowed", "-m", "--maximized", "--position", "--headless", "--import", "--export-release", "--export-debug", "--editor", "-e"]:
			return false
	return true


## ¿El archivo de ajustes ya trae una elección de pantalla hecha con esta versión? Un settings.json viejo (o uno
## creado por una herramienta: --check-all, un escenario, el bot) trae «fullscreen: false» de fábrica sin que nadie
## lo haya elegido; por eso no basta con que la clave exista: hace falta la marca «display_v».
static func display_chosen(file: Dictionary) -> bool:
	return file.has("fullscreen") and int(file.get("display_v", 0)) >= DISPLAY_V


## Argumentos de usuario que son de una herramienta de desarrollo. La marca con que el paquete gráfico relanza el
## juego en otro renderizador (GfxBoot.RELAUNCH_ARG) no lo es: ese segundo arranque sigue siendo «la primera vez»
## (v0.3.2-final: si el primero no llegó a guardar los ajustes, el relanzado abría en ventana).
static func tool_args(user_args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for a in user_args:
		if str(a) != GfxBoot.RELAUNCH_ARG:
			out.append(a)
	return out


func _first_launch_display() -> void:
	if _file_has_fullscreen:
		return  # ya hay una elección guardada
	if first_launch_fullscreen(OS.has_feature("web"), DisplayServer.get_name() == "headless", OS.get_cmdline_args(), tool_args(OS.get_cmdline_user_args())):
		if not bool(settings.get("fullscreen", false)):
			settings["fullscreen"] = true
		settings["display_v"] = DISPLAY_V
		_save_settings()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or OS.has_feature("web"):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and k.alt_pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Alt+Intro y la casilla de Opciones: cambia, aplica y guarda.
func toggle_fullscreen() -> void:
	var on := not bool(get_setting("fullscreen", false))
	set_setting("fullscreen", on)
	OptionsMenu.apply_fullscreen(on)
	EventBus.settings_changed.emit("fullscreen")


func toggle_language() -> void:
	var i := LANGS.find(language)
	set_language(LANGS[(i + 1) % LANGS.size()])


## Devuelve el texto de un dict {"es": .., "en": ..} en el idioma actual (para datos JSON).
func pick(d: Variant) -> String:
	if d is Dictionary:
		if d.has(language):
			return str(d[language])
		if d.has("es"):
			return str(d["es"])
		return ""
	return str(d)


## Sustituye {clave} por valores: fmt("Hola {n}", {"n": "Juan"}).
func fmt(text: String, vars: Dictionary) -> String:
	var out := text
	for k in vars.keys():
		out = out.replace("{%s}" % str(k), str(vars[k]))
	return out


## mm:ss a partir de segundos.
func mmss(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "fullscreen":
		settings["display_v"] = DISPLAY_V  # el jugador eligió (casilla de Opciones o Alt+Intro): ya no es «la primera vez»
	_save_settings()


func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed.keys():
			settings[k] = parsed[k]
		language = str(parsed.get("language", "es"))
		_file_has_fullscreen = display_chosen(parsed as Dictionary)


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	var out := settings.duplicate()
	out["language"] = language
	f.store_string(JSON.stringify(out, "\t"))

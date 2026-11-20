class_name Controls
extends RefCounted
## Mando y remapeo (GDD 9.2): añade al InputMap los botones/ejes del mando por defecto, crea las
## acciones de mirar con el stick derecho y aplica/guarda los cambios del jugador (settings.json →
## "bindings": {accion: [eventos serializados]}). Las teclas por defecto viven en project.godot.

## Acciones remapeables (clave de texto en strings.csv: CTRL_<ACCION>).
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "interact", "accept", "jump",
	"aux_wheel", "hold", "aux_menu", "monitor_toggle", "rub_eyes", "crouch", "walk_fast",
	"phrase_1", "phrase_2", "phrase_3", "phrase_4", "pause",
	"aux_1", "aux_2", "aux_3", "aux_4", "aux_5", "aux_6", "aux_7",
	"comodin", "ia_hablar",  # v0.3.2-core: el comodín [C] y hablar por el micrófono [T] también se pueden remapear
]
## v0.3: elegir AUX en el menú de Fonex (Available, BO, Break, Lunch, Baño, Coaching, Training), teclas 1-7
## por defecto y remapeables (PLAN §6.5; las usa la PC de P4). Se crean aquí si project.godot no las trae.
const AUX_ACTIONS: Array[String] = ["aux_1", "aux_2", "aux_3", "aux_4", "aux_5", "aux_6", "aux_7"]
const LOOK_ACTIONS: Array[String] = ["look_left", "look_right", "look_up", "look_down"]

## Mando por defecto: A interactuar (o saltar, de pie y sin nada delante), X aceptar/Ack, Y Ezlaki, LB rueda AUX, RB hold, B agacharse,
## LT frotarse los ojos, RT monitor, L3 correr, D-pad frases 1-4, Start pausa.
const JOY_BUTTONS: Dictionary = {
	"interact": JOY_BUTTON_A, "accept": JOY_BUTTON_X, "aux_menu": JOY_BUTTON_Y,
	"aux_wheel": JOY_BUTTON_LEFT_SHOULDER, "hold": JOY_BUTTON_RIGHT_SHOULDER, "crouch": JOY_BUTTON_B,
	"walk_fast": JOY_BUTTON_LEFT_STICK, "pause": JOY_BUTTON_START,
	"jump": JOY_BUTTON_A,  # v0.3.1 (F26): A salta solo cuando no hay nada que interactuar (player.gd)
	"phrase_1": JOY_BUTTON_DPAD_UP, "phrase_2": JOY_BUTTON_DPAD_RIGHT, "phrase_3": JOY_BUTTON_DPAD_DOWN, "phrase_4": JOY_BUTTON_DPAD_LEFT,
}
const JOY_AXES: Dictionary = {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"rub_eyes": [JOY_AXIS_TRIGGER_LEFT, 1.0], "monitor_toggle": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

static var _defaults: Dictionary = {}  # accion -> eventos por defecto (proyecto + mando)


## Se llama una vez al arrancar (Main): mando por defecto y remapeos guardados.
static func setup() -> void:
	for a in LOOK_ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
	for i in AUX_ACTIONS.size():
		var a := AUX_ACTIONS[i]
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
			var k := InputEventKey.new()
			k.physical_keycode = (KEY_1 + i) as Key
			InputMap.action_add_event(a, k)
	for a in ACTIONS + LOOK_ACTIONS:
		if not InputMap.has_action(a):
			continue
		var has_joy := false
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
		if not has_joy:
			if JOY_BUTTONS.has(a):
				var b := InputEventJoypadButton.new()
				b.button_index = JOY_BUTTONS[a]
				InputMap.action_add_event(a, b)
			if JOY_AXES.has(a):
				var m := InputEventJoypadMotion.new()
				m.axis = JOY_AXES[a][0]
				m.axis_value = JOY_AXES[a][1]
				InputMap.action_add_event(a, m)
		if not _defaults.has(a):
			_defaults[a] = InputMap.action_get_events(a).duplicate()
	apply_saved()


static func apply_saved() -> void:
	var saved: Dictionary = Loc.get_setting("bindings", {})
	for a in saved.keys():
		if not InputMap.has_action(str(a)):
			continue
		var events: Array = []
		for d in saved[a]:
			var ev := deserialize(d)
			if ev != null:
				events.append(ev)
		if events.is_empty():
			continue
		InputMap.action_erase_events(str(a))
		for ev in events:
			InputMap.action_add_event(str(a), ev)
	refresh_hints()


## Sustituye el evento de teclado (o de mando, según `event`) de una acción y lo guarda.
static func rebind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var is_joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var kept: Array = []
	for ev in InputMap.action_get_events(action):
		var ev_joy := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if ev_joy != is_joy:
			kept.append(ev)  # se conserva la otra familia (teclado ↔ mando)
	kept.append(event)
	InputMap.action_erase_events(action)
	for ev in kept:
		InputMap.action_add_event(action, ev)
	var saved: Dictionary = Loc.get_setting("bindings", {})
	var out: Array = []
	for ev in kept:
		out.append(serialize(ev))
	saved[action] = out
	Loc.set_setting("bindings", saved)
	refresh_hints()


static func reset_all() -> void:
	for a in _defaults.keys():
		InputMap.action_erase_events(a)
		for ev in _defaults[a]:
			InputMap.action_add_event(a, ev)
	Loc.set_setting("bindings", {})
	refresh_hints()


## Texto legible de las teclas/botones de una acción ("E · Botón A").
static func describe(action: String, joy: bool) -> String:
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var ev_joy := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if ev_joy != joy:
			continue
		parts.append(describe_event(ev))
	return " · ".join(parts) if not parts.is_empty() else "—"


const ES_KEYS: Dictionary = {"Space": "Espacio", "Escape": "Esc", "Shift": "Mayús", "Enter": "Intro", "Backspace": "Retroceso", "Delete": "Supr", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "PageUp": "RePág", "PageDown": "AvPág", "Home": "Inicio", "End": "Fin", "Insert": "Insert", "CapsLock": "Bloq Mayús"}


static func describe_event(ev: InputEvent, lang: String = "") -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		# v0.3.1: en headless DisplayServer no traduce teclas físicas (cada llamada imprimía un ERROR).
		var physical_ok := k.physical_keycode != 0 and DisplayServer.get_name() != "headless"
		var txt := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if physical_ok else code)
		# rc1: en la interfaz en español las teclas salían en inglés (Space, Escape, Shift…).
		if (lang if lang != "" else Loc.language) == "es":
			txt = str(ES_KEYS.get(txt, txt))
		return txt
	if ev is InputEventMouseButton:
		return ("Ratón %d" if Loc.language == "es" else "Mouse %d") % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back", JOY_BUTTON_DPAD_UP: "D↑", JOY_BUTTON_DPAD_DOWN: "D↓", JOY_BUTTON_DPAD_LEFT: "D←", JOY_BUTTON_DPAD_RIGHT: "D→"}
		return str(names.get((ev as InputEventJoypadButton).button_index, "Btn %d" % (ev as InputEventJoypadButton).button_index))
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		var names := {JOY_AXIS_LEFT_X: "LS X", JOY_AXIS_LEFT_Y: "LS Y", JOY_AXIS_RIGHT_X: "RS X", JOY_AXIS_RIGHT_Y: "RS Y", JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
		return "%s%s" % [names.get(m.axis, "Eje %d" % m.axis), "+" if m.axis_value > 0 else "-"]
	return "?"


static func serialize(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"type": "key", "code": k.physical_keycode if k.physical_keycode != 0 else k.keycode, "physical": k.physical_keycode != 0}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": (ev as InputEventMouseButton).button_index}
	if ev is InputEventJoypadButton:
		return {"type": "joy", "button": (ev as InputEventJoypadButton).button_index}
	if ev is InputEventJoypadMotion:
		return {"type": "axis", "axis": (ev as InputEventJoypadMotion).axis, "value": (ev as InputEventJoypadMotion).axis_value}
	return {}


static func deserialize(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	match str(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			if bool(d.get("physical", true)):
				k.physical_keycode = int(d.get("code", 0)) as Key
			else:
				k.keycode = int(d.get("code", 0)) as Key
			return k
		"mouse":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(d.get("button", 1)) as MouseButton
			return mb
		"joy":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("button", 0)) as JoyButton
			return b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d.get("axis", 0)) as JoyAxis
			m.axis_value = float(d.get("value", 1.0))
			return m
	return null


## ¿Hay mando conectado? (para mostrar la columna de mando y la vibración)
# --- v0.3.2-core: las pistas de teclas siguen el remapeo -----------------------------------------------------
# Los textos nombran las teclas entre corchetes («[E] Sentarse», «Aceptar [Espacio]»). Antes eran fijos: quien
# cambiaba una tecla en Opciones → Controles seguía leyendo la de fábrica. Ahora hay UN ayudante, `hint()`, que
# cambia cada corchete por la tecla asignada en el InputMap; Loc lo pasa por todas las traducciones cada vez que
# cambia una tecla (Loc.refresh_key_hints), así que cualquier tr() ya devuelve la pista correcta, en ES y en EN.
# Con las teclas de fábrica no cambia ni un carácter.

## Corchete → acción. Solo acciones que el juego lee del InputMap (las de Opciones → Controles).
const HINT_TOKENS: Dictionary = {
	"E": "interact", "Espacio": "accept", "Space": "accept", "Q": "aux_wheel", "H": "hold", "Tab": "aux_menu",
	"F": "monitor_toggle", "R": "rub_eyes", "C": "comodin", "T": "ia_hablar",
}
## Textos cuya tecla está fija en el código (no pasa por el InputMap): se dejan como están.
##   cinemáticas y muertes: Espacio «físico» / ui_accept · panel del comodín: números y Esc fijos.
const HINT_FIXED_KEYS: Array[String] = ["SCR_K2_SALTAR", "Q4_CINE_SKIP", "B2_COMODIN_PICK_AUX", "B2_COMODIN_PICK_WHO", "B2_COMODIN_RETRY", "B2_COMODIN_NOBODY"]
## [Esc] solo es la acción «pausa» en estos textos (en los demás es la tecla Esc fija: cancelar, cerrar).
const HINT_ESC_KEYS: Array[String] = ["DEATH_BACK_MENU"]
## Teclas de números: clave → [texto a buscar, prefijo de la acción, cuántas, formato del reemplazo].
const HINT_RANGES: Dictionary = {
	"B2_RECON_HUD": ["[1-7]", "aux_", 7, "[%s]"], "SHOP_CLOSE": ["[1-3]", "phrase_", 3, "[%s]"],
	"P4_NEXT_TREE": ["(1-4 ", "phrase_", 4, "(%s "], "P4_HELP_PC": ["1-4 ", "phrase_", 4, "%s "],
	"P4_HELP_TERMINAL": ["1-7 ", "aux_", 7, "%s "],
}
const HINT_SINGLE: Dictionary = {"IDENTA_APPROVE": ["[1]", "phrase_1"], "IDENTA_REJECT": ["[2]", "phrase_2"]}
## Líneas de atajos sin corchetes («… · Espacio aceptar/Ack · H hold · Tab pantallas · Q AUX · E salir»).
const HINT_BARE_KEYS: Array[String] = ["P4_HELP_PC", "P4_HELP_TERMINAL"]

static var hints_active: bool = false  # ¿alguna tecla con pista está cambiada? (si no, hint() devuelve el texto tal cual)


## ¿La tecla de teclado de la acción es la de fábrica?
static func kb_default(action: String) -> bool:
	if not InputMap.has_action(action) or not _defaults.has(action):
		return true
	return _kb_code(InputMap.action_get_events(action)) == _kb_code(_defaults[action])


static func _kb_code(events: Array) -> int:
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return int(k.physical_keycode) if k.physical_keycode != 0 else int(k.keycode)
	return 0


## Nombre de la tecla de teclado de la acción («E», «Espacio»/«Space»…); "" si no tiene.
static func kb_label(action: String, lang: String = "") -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return describe_event(ev, lang)
	return ""


## Vuelve a mirar el InputMap y pide a Loc que reescriba las pistas de todas las traducciones.
static func refresh_hints() -> void:
	var on := false
	for a: String in ACTIONS:
		if not kb_default(a):
			on = true
			break
	hints_active = on
	Loc.refresh_key_hints()


## Un texto cualquiera con sus corchetes al día (para textos que no vienen de una traducción: datos, código).
static func hint(text: String, lang: String = "") -> String:
	if not hints_active or text.find("[") < 0:
		return text
	return _swap_tokens(text, lang, false, false)


## Lo mismo para el texto de una clave de traducción: respeta las claves con teclas fijas y arregla los números y
## las líneas de atajos sin corchetes. `text` es el texto ORIGINAL (de fábrica) de la clave.
static func hint_for_key(key: String, text: String, lang: String = "") -> String:
	if not hints_active or HINT_FIXED_KEYS.has(key):
		return text
	var out := _swap_tokens(text, lang, HINT_ESC_KEYS.has(key), key.begins_with("TUT_"))
	if HINT_RANGES.has(key):
		var r: Array = HINT_RANGES[key]
		var labels: Array[String] = []
		var changed := false
		for i in int(r[2]):
			var a := "%s%d" % [str(r[1]), i + 1]
			changed = changed or not kb_default(a)
			labels.append(kb_label(a, lang))
		if changed:
			out = out.replace(str(r[0]), str(r[3]) % "/".join(PackedStringArray(labels)))
	if HINT_SINGLE.has(key):
		var s1: Array = HINT_SINGLE[key]
		if not kb_default(str(s1[1])):
			out = out.replace(str(s1[0]), "[%s]" % kb_label(str(s1[1]), lang))
	if HINT_BARE_KEYS.has(key):
		var segs := out.split(" · ")
		for i in segs.size():
			var words := segs[i].split(" ")
			for j in words.size():
				var w := words[j]
				if HINT_TOKENS.has(w) and (j == 0 or words[j - 1] == "/"):  # «E salir», «Q / E salir»
					var a2 := str(HINT_TOKENS[w])
					if not kb_default(a2):
						words[j] = kb_label(a2, lang)
			segs[i] = " ".join(words)
		out = " · ".join(segs)
	return out


static var _rx_hint: RegEx = null

## Cada corchete se cambia por separado y de una sola pasada (si E pasa a Q y Q pasa a E, no se pisan).
static func _swap_tokens(text: String, lang: String, esc: bool, tutorial: bool) -> String:
	if _rx_hint == null:
		_rx_hint = RegEx.new()
		_rx_hint.compile("\\[([^\\[\\]]{1,12})\\]")
	var out := ""
	var last := 0
	for m in _rx_hint.search_all(text):
		var token := m.get_string(1)
		var label := ""
		if HINT_TOKENS.has(token) and not (tutorial and token == "T"):  # en el Training [T] es «continuar», no el micrófono
			var a := str(HINT_TOKENS[token])
			if not kb_default(a):
				label = kb_label(a, lang)
		elif esc and token == "Esc" and not kb_default("pause"):
			label = kb_label("pause", lang)
		out += text.substr(last, m.get_start() - last)
		out += ("[" + label + "]") if label != "" else m.get_string(0)
		last = m.get_end()
	return out + text.substr(last)


static func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func vibrate(weak: float, strong: float, seconds: float) -> void:
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, seconds)

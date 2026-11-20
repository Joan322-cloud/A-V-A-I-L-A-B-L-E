## Sin class_name: solo herramienta (escenarios v032_fbmail y el bot con `--correo-ui`).
extends RefCounted
## «Manos» de un jugador sobre la PC (v0.3.2, feedback de Joan sobre los correos). Hace los casos de BO por el camino
## REAL de la interfaz, no llamando a ContactManager: cada clic es un evento de ratón que entra por la ventana, pasa
## por la imagen acercada del monitor (Workstation._forward) y llega al control del SubViewport; cada tecla entra
## por la ventana y la reparte Workstation._input / _unhandled_input, igual que con el teclado de verdad.
##   · botones y casillas: clic en su centro (se comprueba antes que el control está a la vista y no tapado);
##   · desplegables (OptionButton): clic, se abre el menú embebido, se pasa el ratón por las filas hasta que la
##     fila bajo el cursor es la pedida (PopupMenu.get_focused_item) y se hace clic ahí;
##   · enlaces de Kardex (RichTextLabel): se pasa el ratón por el texto y se hace clic donde `meta_hover_started`
##     dice que está el enlace pedido;
##   · campos de texto: clic para enfocar y luego las teclas, una por una, y [Intro].
## Si algo no se puede hacer como lo haría una persona (control deshabilitado, fuera de la pantalla, tapado), NO se
## hace por otro lado: queda apuntado en `fails` y el paso devuelve false.

var tree: SceneTree = null
var main: Node = null
var ws: Node = null  # Workstation
var desk: PcDesktop = null
var cm: ContactManager = null
var fails: Array[String] = []
var trace: Array[String] = []
var clicks: int = 0
var _hover_meta: String = ""
var _last_wp: Vector2 = Vector2.INF
var _down: bool = false
## Milisegundos reales que el botón queda apretado en cada clic (un clic normal dura 60-150 ms).
var hold_ms: int = 0


func setup(p_main: Node) -> bool:
	main = p_main
	tree = main.get_tree()
	ws = main.get_node_or_null("UI/Workstation")
	if ws == null:
		return false
	desk = ws.get("desktop") as PcDesktop
	cm = main.get("contacts") as ContactManager
	return desk != null and cm != null


func _fail(msg: String) -> bool:
	fails.append(msg)
	trace.append("✗ " + msg)
	return false


func frames(n: int = 1) -> void:
	for i in n:
		await tree.process_frame


# --- eventos por el camino real ------------------------------------------------------------------------------------

## Pantalla ("left" | "right") en la que vive un control (o su menú embebido).
func _side_of(c: Node) -> String:
	var vp := c.get_viewport()
	while vp != null and not (vp is SubViewport) and vp != tree.root:
		vp = vp.get_parent().get_viewport() if vp.get_parent() != null else null  # un menú embebido es una Window
	if vp == ws.get("_left_vp"):
		return "left"
	if vp == ws.get("_right_vp"):
		return "right"
	return ""


## Punto de la VENTANA que corresponde a un punto de una pantalla (a través de la imagen acercada, con su escala).
func _window_point(side: String, screen_pos: Vector2) -> Vector2:
	var t: TextureRect = ws.get("_zoom_left" if side == "left" else "_zoom_right")
	var vp: SubViewport = ws.get("_left_vp" if side == "left" else "_right_vp")
	var local := screen_pos * (t.size / Vector2(vp.size))
	return t.get_global_transform() * local


func _ensure_zoom(side: String) -> bool:
	if not bool(ws.get("visible")):
		return _fail("la PC no está a la vista (no estás sentado en un puesto con pantallas)")
	var t: TextureRect = ws.get("_zoom_left" if side == "left" else "_zoom_right")
	if not bool(ws.get("zoomed")) or not t.is_visible_in_tree():
		# Como el jugador: [F1] acerca la vista (o [E] sobre el monitor). Si solo se ve la otra pantalla, [Tab].
		if not bool(ws.get("zoomed")):
			await key(KEY_F1 + PcDesktop.APPS.find(desk.active_app))
		var guard := 0
		while not t.is_visible_in_tree() and guard < 3:
			ws.call("cycle_layout")  # [Tab]
			await frames(2)
			guard += 1
		await frames(3)
	return t.is_visible_in_tree()


func _mouse(side: String, screen_pos: Vector2, kind: String) -> void:
	var wp := _window_point(side, screen_pos)
	var ev: InputEventMouse = null
	if kind == "move":
		var m := InputEventMouseMotion.new()
		m.relative = wp - _last_wp if _last_wp != Vector2.INF and wp != _last_wp else Vector2(1, 0)
		m.velocity = m.relative * 60.0  # PopupMenu ignora un movimiento sin velocidad
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if _down else 0
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = kind == "down"
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if b.pressed else 0
		_down = b.pressed
		ev = b
	_last_wp = wp
	_send(ev, wp)


## Entrega un evento como lo entrega el sistema: por Input (así el estado del ratón que consulta el motor —botones
## apretados al abrir un menú, posición— es el de verdad) y de ahí a la ventana.
func _send(ev: InputEvent, canvas_pos: Vector2 = Vector2.INF) -> void:
	if ev is InputEventMouse and canvas_pos != Vector2.INF:
		var wpos := tree.root.get_final_transform() * canvas_pos  # coordenadas de ventana
		(ev as InputEventMouse).position = wpos
		(ev as InputEventMouse).global_position = wpos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Clic del ratón en un punto de una pantalla.
func click_at(side: String, screen_pos: Vector2) -> void:
	_mouse(side, screen_pos, "move")
	_mouse(side, screen_pos, "down")
	if hold_ms > 0:
		await tree.create_timer(hold_ms / 1000.0, true, false, true).timeout
	_mouse(side, screen_pos, "up")
	clicks += 1


## Tecla por la ventana (Workstation._input / _unhandled_input la reparten como la del teclado).
func key(code: Key, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = unicode if pressed else 0
		e.pressed = pressed
		_send(e)
	await frames(2)


## ¿El control está a la vista en su pantalla (dentro del SubViewport y de los ScrollContainer que lo contienen)?
func _visible_point(c: Control) -> Vector2:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Vector2.INF
	var r := c.get_global_rect()
	var vp := c.get_viewport()
	var clip := Rect2(Vector2.ZERO, Vector2(vp.get_visible_rect().size))
	var p: Node = c.get_parent()
	while p != null and p is Control:
		if (p as Control).clip_contents or p is ScrollContainer:
			clip = clip.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	var vis := r.intersection(clip)
	if vis.size.x < 4.0 or vis.size.y < 4.0:
		return Vector2.INF
	return vis.get_center()


## Si el control quedó por debajo del borde de la app (pantalla sin acercar: 492 px), rueda el scroll como el jugador.
func _scroll_into_view(c: Control) -> void:
	var guard := 0
	while _visible_point(c) == Vector2.INF and guard < 12:
		var sc: ScrollContainer = null
		var p: Node = c.get_parent()
		while p != null:
			if p is ScrollContainer:
				sc = p
				break
			p = p.get_parent()
		if sc == null:
			return
		var r := c.get_global_rect()
		var down := r.position.y > sc.get_global_rect().position.y
		var side := _side_of(sc)
		var wp := _window_point(side, sc.get_global_rect().get_center())
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		e.factor = 1.0
		_send(e, wp)
		var e2 := e.duplicate() as InputEventMouseButton
		e2.pressed = false
		_send(e2, wp)
		await frames(2)
		guard += 1


## Clic en un botón / casilla / pestaña. Falla (sin hacer nada) si está deshabilitado o no se ve.
func click(c: Control, what: String = "") -> bool:
	var label := what if what != "" else (str(c.name) if c != null else "?")
	if c == null or not is_instance_valid(c):
		return _fail("no existe el control «%s»" % label)
	var side := _side_of(c)
	if side == "":
		return _fail("«%s» no está en una pantalla de la PC" % label)
	if not await _ensure_zoom(side):
		return _fail("no se pudo acercar la vista a la pantalla de «%s»" % label)
	if c is BaseButton and (c as BaseButton).disabled:
		return _fail("«%s» está deshabilitado" % label)
	await _scroll_into_view(c)
	var p := _visible_point(c)
	if p == Vector2.INF:
		return _fail("«%s» no está a la vista" % label)
	await click_at(side, p)
	trace.append("clic «%s»" % label)
	await frames(2)
	return true


## Elige una opción de un desplegable por su texto (como se lee en pantalla).
func pick(ob: OptionButton, text: String, what: String = "") -> bool:
	var label := what if what != "" else (str(ob.name) if ob != null else "?")
	if ob == null or not is_instance_valid(ob):
		return _fail("no existe el desplegable «%s»" % label)
	var idx := -1
	for i in ob.item_count:
		if ob.get_item_text(i) == text:
			idx = i
	if idx < 0:
		return _fail("«%s» no tiene la opción «%s»" % [label, text])
	if not await click(ob, label):
		return false
	var pop := ob.get_popup()
	var side := _side_of(ob)
	await frames(2)
	if not pop.visible:
		return _fail("«%s»: el menú no se abrió" % label)
	var origin := Vector2(pop.position)
	var sz := Vector2(pop.size)
	var hit := Vector2.INF
	var y := 3.0
	while y < sz.y - 1.0:
		var sp := origin + Vector2(sz.x * 0.5, y)
		_mouse(side, sp, "move")
		if pop.get_focused_item() == idx:
			hit = sp + Vector2(0, 4)
			# el centro de la fila: avanzar mientras siga siendo la misma
			var y2 := y
			while y2 < sz.y - 1.0:
				_mouse(side, origin + Vector2(sz.x * 0.5, y2), "move")
				if pop.get_focused_item() != idx:
					break
				y2 += 2.0
			hit = origin + Vector2(sz.x * 0.5, (y + y2) * 0.5)
			break
		y += 3.0
	if hit == Vector2.INF:
		# cerrar el menú como el jugador (clic fuera) y apuntarlo
		await click_at(side, Vector2(4, 4))
		await frames(2)
		return _fail("«%s»: no se pudo llegar con el ratón a «%s»" % [label, text])
	await click_at(side, hit)
	trace.append("elige «%s» = %s" % [label, text])
	await frames(3)
	return true


## Escribe en un campo de texto (clic para enfocar, teclas, y [Intro] si `enter`).
func type_in(le: LineEdit, text: String, enter: bool = true, what: String = "") -> bool:
	var label := what if what != "" else "campo de texto"
	if not await click(le, label):
		return false
	if le.get_viewport().gui_get_focus_owner() != le:
		return _fail("«%s» no tomó el foco con el clic" % label)
	# Borrar lo que hubiera: [Fin] y retroceso las veces que haga falta, como una persona.
	await _key_fast(KEY_END, 0)
	for i in le.text.length():
		await _key_fast(KEY_BACKSPACE, 0)
	if le.text != "":
		return _fail("«%s»: no se pudo borrar lo que había («%s»)" % [label, le.text])
	for i in text.length():
		var ch := text.unicode_at(i)
		await _key_fast(_keycode_for(ch), ch)
	trace.append("escribe «%s» en %s" % [text, label])
	if enter:
		await key(KEY_ENTER)
	return true


func _key_fast(code: Key, unicode: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = unicode if pressed else 0
		e.pressed = pressed
		_send(e)
	await tree.process_frame


func _keycode_for(ch: int) -> Key:
	var s := String.chr(ch).to_upper()
	var k := OS.find_keycode_from_string(s)
	if k != KEY_NONE:
		return k
	if s == "-":
		return KEY_MINUS
	return KEY_UNKNOWN


## Cajas de los enlaces de un RichTextLabel, en orden de lectura (coordenadas de su pantalla). Se sacan del cursor
## que el propio control dice que mostraría en cada punto (mano = enlace), sin mover ni tocar nada.
func link_boxes(rtl: RichTextLabel) -> Array:
	var gr := rtl.get_global_rect()
	var r := gr
	var clip := Rect2(Vector2.ZERO, Vector2(rtl.get_viewport().get_visible_rect().size))
	var p: Node = rtl.get_parent()
	while p != null and p is Control:
		if (p as Control).clip_contents or p is ScrollContainer:
			clip = clip.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	r = r.intersection(clip)
	var boxes: Array = []  # Rect2
	var y := r.position.y + 1.0
	while y < r.end.y:
		var x := r.position.x + 1.0
		var start := -1.0
		while x <= r.end.x + 2.0:
			var hand := x < r.end.x and rtl.get_cursor_shape(Vector2(x, y) - gr.position) == Control.CURSOR_POINTING_HAND
			if hand and start < 0.0:
				start = x
			elif not hand and start >= 0.0:
				var seg := Rect2(start, y, x - 2.0 - start, 2.0)
				var merged := false
				for i in boxes.size():
					var bx: Rect2 = boxes[i]
					if absf(bx.end.y - seg.position.y) <= 3.0 and seg.position.x < bx.end.x and seg.end.x > bx.position.x:
						boxes[i] = bx.merge(seg)
						merged = true
						break
				if not merged:
					boxes.append(seg)
				start = -1.0
			x += 2.0
		y += 2.0
	boxes.sort_custom(func(a: Rect2, b2: Rect2) -> bool:
		if absf(a.get_center().y - b2.get_center().y) > 6.0:
			return a.get_center().y < b2.get_center().y
		return a.position.x < b2.position.x)
	return boxes


## Clic en el enlace n.º `index` (en orden de lectura) de un RichTextLabel.
func link(rtl: RichTextLabel, index: int, what: String = "") -> bool:
	var label := what if what != "" else ("enlace %d" % index)
	if rtl == null or not is_instance_valid(rtl) or not rtl.is_visible_in_tree():
		return _fail("no se ve el texto donde está «%s»" % label)
	var side := _side_of(rtl)
	if not await _ensure_zoom(side):
		return _fail("no se pudo acercar la vista para «%s»" % label)
	await frames(2)
	var boxes := link_boxes(rtl)
	if index < 0 or index >= boxes.size():
		return _fail("«%s»: hay %d enlaces a la vista y se pedía el n.º %d" % [label, boxes.size(), index])
	await click_at(side, (boxes[index] as Rect2).get_center())
	trace.append("clic en «%s»" % label)
	await frames(2)
	return true


## Busca un botón por su texto dentro de un nodo (los de las apps no siempre tienen nombre).
func button_by_text(root: Node, text: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and not (n is OptionButton) and (n as Button).text == text and (n as Control).is_visible_in_tree():
			return n
		stack.append_array(n.get_children())
	return null


func node_named(root: Node, n: String) -> Node:
	return root.find_child(n, true, false)


# --- pasos de un caso, como los hace una persona -------------------------------------------------------------------

## Abre una app con su tecla (F1-F5) o con un clic en la barra de tareas.
func app(name: String, with_key: bool = true) -> bool:
	if with_key:
		await key(KEY_F1 + PcDesktop.APPS.find(name))
	else:
		if not await click(desk._task_buttons[name], "barra " + name):
			return false
	await frames(2)
	if desk.active_app != name:
		return _fail("no se abrió la app %s (está %s)" % [name, desk.active_app])
	return true


## Acepta el contacto que suena: [Espacio] o el botón de Fonex.
func accept(with_key: bool = true) -> bool:
	if cm.phase != ContactManager.Phase.OFFERING:
		return _fail("no hay contacto sonando")
	if with_key:
		var e := InputEventAction.new()
		e.action = "accept"
		e.pressed = true
		_send(e)
		var e2 := InputEventAction.new()
		e2.action = "accept"
		e2.pressed = false
		_send(e2)
		await frames(2)
	else:
		var fonex: PcFonex = ws.get("fonex")
		fonex.refresh(0.0)
		if not await click(fonex._accept, "Aceptar (Fonex)"):
			return false
	if cm.phase != ContactManager.Phase.ACTIVE:
		return _fail("el contacto no se aceptó")
	await frames(2)
	return true


## Kardex: buscar la operación. modo "enlace" (clic en el KP del caso), "boton" (botón «Ver en Kardex» del correo),
## "teclado" (escribir el número + Intro) o "teclado_boton" (escribir + botón Buscar). `typed` = lo que se teclea.
func kardex_lookup(mode: String = "enlace", typed: String = "") -> bool:
	var tx := cm.case.tx() if cm.case != null else ""
	match mode:
		"boton":
			if not await app("correo"):
				return false
			var b := button_by_text(desk.correo, "%s %s" % [desk.tr("P4_MAIL_OPEN_KARDEX"), tx])
			if not await click(b, "Ver en Kardex"):
				return false
		"teclado", "teclado_boton":
			if not await app("kardex"):
				return false
			if not await type_in(desk.kardex._search, typed if typed != "" else tx, mode == "teclado", "buscador de Kardex"):
				return false
			if mode == "teclado_boton":
				if not await click(button_by_text(desk.kardex._search_row, desk.tr("P4_SEARCH")), "Buscar (Kardex)"):
					return false
		_:
			if not await app("kardex"):
				return false
			if not await link(desk.kardex._conv, 0, "KP del caso en Kardex"):
				return false
	await frames(3)
	return true


## Kardex: clic en un valor para copiarlo al correo. `campo` = columna (id | monto | fecha); `fila` 0 = la operación
## del caso, 1.. = las operaciones parecidas de debajo. Comprueba lo que Kardex dice que copió (el pie «Copiado…»).
func kardex_copy(campo: String, fila: int = 0) -> bool:
	if desk.active_app != "kardex":
		if not await app("kardex"):
			return false
	await frames(2)
	var idx := fila * 3 + CasoBO.FIELDS.find(campo)
	return await link(desk.kardex._result, idx, "%s (fila %d) en Kardex" % [campo, fila])


func mail_node(n: String) -> Control:
	return node_named(desk.correo, n) as Control


func mail_open() -> bool:
	if desk.active_app != "correo":
		return await app("correo")
	return true


func mail_recipient(r: String) -> bool:
	if not await mail_open():
		return false
	return await pick(mail_node("OptDestinatario") as OptionButton, r, "Destinatario")


func mail_template(tpl: String) -> bool:
	if not await mail_open():
		return false
	return await pick(mail_node("OptPlantilla") as OptionButton, tpl, "Plantilla")


func mail_field(k: String, v: String) -> bool:
	if not await mail_open():
		return false
	return await pick(mail_node("Campo_" + k) as OptionButton, v, "Campo " + k)


func mail_mark(k: String) -> bool:
	if not await mail_open():
		return false
	return await click(mail_node("Activo_" + k), "marcar campo " + k)


func mail_attach() -> bool:
	if not await mail_open():
		return false
	return await click(mail_node("Adjunto"), "casilla Adjuntar POD")


func mail_send() -> bool:
	if not await mail_open():
		return false
	return await click(mail_node("Enviar"), "Enviar")


func mail_typify(text: String) -> bool:
	if not await mail_open():
		return false
	return await pick(mail_node("OptTipificacion") as OptionButton, text, "Tipificación")


func mail_close() -> bool:
	if not await mail_open():
		return false
	return await click(mail_node("Cerrar"), "Cerrar caso")


## Portal Vitzo: buscar ("caso" = botón «Usar KP del caso», "teclado" = escribir + Intro, "boton" = escribir + Buscar,
## "prellenado" = el campo ya trae el KP al abrir la app: solo Buscar).
func portal_search(mode: String = "caso", typed: String = "") -> bool:
	if not await app("portal"):
		return false
	var p := desk.portal
	match mode:
		"teclado":
			if not await type_in(p._search, typed if typed != "" else p.case_tx(), true, "buscador del Portal"):
				return false
		"boton":
			if not await type_in(p._search, typed if typed != "" else p.case_tx(), false, "buscador del Portal"):
				return false
			if not await click(button_by_text(p, desk.tr("P4_SEARCH")), "Buscar (Portal)"):
				return false
		"prellenado":
			if not await click(button_by_text(p, desk.tr("P4_SEARCH")), "Buscar (Portal)"):
				return false
		_:
			if not await click(button_by_text(p, desk.tr("P4_PORTAL_USE_CASE")), "Usar KP del caso"):
				return false
	await frames(3)
	return true


func portal_button(key: String) -> bool:
	if desk.active_app != "portal":
		if not await app("portal"):
			return false
	await frames(2)
	return await click(button_by_text(desk.portal, desk.tr(key)), desk.tr(key))


## Identa: decidir el KYC con su botón.
func kyc(action: String) -> bool:
	if not await app("identa"):
		return false
	await frames(2)
	return await click(button_by_text(desk.identa, desk.tr("P4_KYC_" + action.to_upper())), "KYC " + action)


# --- un caso entero ------------------------------------------------------------------------------------------------

static func tip_text(id: String) -> String:
	for tp in DataLoader.dict("casos_bo").get("tipificaciones", []):
		if str(tp.get("id", "")) == id:
			return Loc.pick(tp)
	return id


## Los pasos del camino del manual para un caso ya aceptado (correo, correo de Vitzo o KYC), como los haría un
## agente que sabe: Kardex → (Portal Vitzo) → destinatario → plantilla → campos copiados de Kardex → (adjunto) →
## enviar → tipificar → cerrar. Son nombres de paso para step().
static func manual_steps(c: Dictionary) -> Array:
	if str(c.get("canal", "")) == "kyc":
		return ["kyc:" + str(c.get("correcto", ""))]
	var corr: Dictionary = c.get("correcto", {})
	var out: Array = ["kardex"]
	for p in corr.get("portal", []):
		match str(p):
			"buscar": out.append("portal")
			"pod": out.append("pod_descargar")
			"reversal": out.append("reversal")
			"contacto": out.append("contacto")
	if str(corr.get("destinatario", "")) != "":
		out.append("dest:" + str(corr.get("destinatario", "")))
		out.append("tpl:" + str(corr.get("plantilla", "")))
		out.append_array(["copiar:id", "copiar:monto", "copiar:fecha"])
		if bool(corr.get("adjunto_pod", false)):
			out.append("pod_adjuntar")
		out.append("enviar")
	out.append("tip:" + str(corr.get("tipificacion", "")))
	out.append("cerrar")
	return out


## Un paso por su nombre. Devuelve false si no se pudo hacer (queda en `fails`).
func step(st: String) -> bool:
	var k := st.get_slice(":", 0)
	var a := st.substr(k.length() + 1) if st.contains(":") else ""
	match k:
		"aceptar": return await accept(true)
		"aceptar_boton": return await accept(false)
		"kardex": return await kardex_lookup("enlace")
		"kardex_boton": return await kardex_lookup("boton")
		"kardex_teclado": return await kardex_lookup("teclado", a)
		"kardex_teclado_boton": return await kardex_lookup("teclado_boton", a)
		"copiar": return await kardex_copy(a.get_slice(":", 0), int(a.get_slice(":", 1)) if a.contains(":") else 0)
		"copiar2":
			if not await kardex_copy(a, 0):
				return false
			return await kardex_copy(a, 0)
		"marcar": return await mail_mark(a)
		"dest": return await mail_recipient(a)
		"tpl": return await mail_template(a)
		"campo": return await mail_field(a.get_slice(":", 0), a.substr(a.find(":") + 1))
		"adjuntar": return await mail_attach()
		"enviar": return await mail_send()
		"tip": return await mail_typify(tip_text(a))
		"cerrar": return await mail_close()
		"portal": return await portal_search("caso")
		"portal_teclado": return await portal_search("teclado", a)
		"portal_boton": return await portal_search("boton", a)
		"portal_prellenado": return await portal_search("prellenado")
		"pod_descargar": return await portal_button("P4_PORTAL_DOWNLOAD")
		"pod_adjuntar": return await portal_button("P4_PORTAL_ATTACH")
		"reversal": return await portal_button("P4_PORTAL_REVERSAL")
		"contacto": return await portal_button("P4_PORTAL_CONTACT")
		"kyc": return await kyc(a)
		"app": return await app(a, true)
		"app_clic": return await app(a, false)
	return _fail("paso desconocido: " + st)


## Hace los pasos en orden; se detiene en el primero que no se puede. Antes de cada uno espera a que no haya nada
## tapando la PC (un WW esperando su Ack, el menú de AUX) y se rinde si el caso ya no está (muerte, reconexión).
func play(steps: Array, case_id: String = "") -> bool:
	for st in steps:
		var guard := 0
		while guard < 900 and (Metrics.ack_pending or bool(GameState.flags.get("aux_menu_open", false))):
			await tree.process_frame
			guard += 1
		if Checkpoints.dying or Checkpoints.death_visible:
			return _fail("muerte a mitad del caso")
		if case_id != "" and (cm.phase != ContactManager.Phase.ACTIVE or str(cm.current.get("id", "")) != case_id):
			return _fail("el caso %s ya no está abierto" % case_id)
		if not await step(str(st)):
			return false
	return true

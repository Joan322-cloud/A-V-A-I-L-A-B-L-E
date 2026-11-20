## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 · feedback de Joan sobre la beta (jugó la de Windows en Normal). Grupo `v032_fbui`.
##   fbui_pasos            puntos 1-3: el Training ENTERO (14 módulos, con el bot) y, en CADA paso con panel y en cada
##                         mini-check (antes y después de contestar), en 9 tamaños de vista lógica (1920×1080 = las
##                         ventanas de 1280×720, 1366×768 y 1920×1080; 16:10, 4:3, 21:9, ventana recortada, el navegador
##                         chico) y con la PC acercada y sin acercar:
##                           · el panel entero dentro de la vista; cada botón a la vista dentro del panel y de la vista;
##                           · el panel no toca lo que el paso señala (el control exacto de la PC, de Ezlaki, del HUD,
##                             del menú AUX, del WW, del ascensor, la luz guía del mundo);
##                           · con la PC acercada, el panel no toca las pantallas (y las pantallas conservan su ancho);
##                           · no toca la columna del HUD, ni la franja de los subtítulos y avisos, ni un menú abierto;
##                           · a 1920×1080 ningún paso necesita scroll; todo paso con `ui` señala algo.
##   fbui_pasos_en         lo mismo en inglés (los textos más largos) y contestando mal los mini-checks que el otro acierta.
##   fbui_pasos_liviano    tres módulos (AUX, correo, Ezlaki) en Modo liviano.
##   fbui_objetivos        TrainingTargets: cada id cae donde debe (acercado: sobre su pantalla; sin acercar: proyectado
##                         en el monitor 3D; menú AUX; WW; HUD) y el orden de preferencia de la lista funciona.
##   fbui_aviso            cada paso nuevo avisa una vez (destello + sfx/tut_paso por el bus UI, sin ocupar el canal de
##                         las voces); el aviso de texto del HUD sale dentro de la guía mientras dura el Training y
##                         vuelve al HUD después; al salir, la PC recupera su encuadre (reserve_top = 0).
##   fbui_reserva          Workstation.reserve_top: sin reserva el encuadre es el de F10; con reserva las pantallas
##                         empiezan debajo y conservan el ancho en 16:9, 16:10 y 21:9.

const BOT := "res://scripts/dev/bot_tutorial.gd"
## Ventanas (px). La vista lógica sale de ellas como en el juego (Main._apply_ui_scale + estirado «expand»): las tres
## primeras dan 1920×1080 (1921 en 1366×768); luego una ventana de 1280×720 con su barra en un portátil de 1366×768
## (1920×1040), 16:10, 4:3, 21:9 y el navegador o una ventana chica (1536×864, 1440×810 y 1067×600 lógicos).
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(1280, 693), Vector2i(1600, 1000),
	Vector2i(1024, 768), Vector2i(2560, 1080), Vector2i(1024, 576), Vector2i(960, 540), Vector2i(711, 400)]
## Pasos cuyo control solo existe cuando el jugador ya empezó a hacerlo (al entrar al paso aún no hay nada que señalar).
const LATE_TARGET: Array[String] = ["salir/comodin"]

var _fails: Array[String] = []
var _n: int = 0
var _steps: int = 0
var _with_target: int = 0
var _ui_steps: int = 0
var _zoom_n: int = 0
var _max_h: float = 0.0
var _quiz_n: int = 0
var _quiz_scroll: int = 0
var _true_ups: int = 0
var _tiny_overlaps: int = 0
var _unresolved: Array[String] = []
var _zones: Dictionary = {}


func escenarios() -> Array[String]:
	return ["fbui_pasos", "fbui_pasos_en", "fbui_pasos_liviano", "fbui_objetivos", "fbui_aviso", "fbui_reserva", "fbui_ver:"]


func run(id: String, _arg: String, t: Node) -> void:
	# Sin pantalla la ventana raíz mide 64×64 (vista cuadrada): se mide con la ventana de 1280×720 de verdad.
	var root: Window = t.get_tree().root
	var win0 := root.size
	var css0 := root.content_scale_size
	_window(t, Vector2i(1280, 720))
	await t.frames(2)
	await _run(id, _arg, t)
	root.size = win0
	root.content_scale_size = css0


func _run(id: String, _arg: String, t: Node) -> void:
	match id:
		"fbui_pasos": await _pasos(t, "es", [], false)
		"fbui_pasos_en": await _pasos(t, "en", [], true)
		"fbui_pasos_liviano": await _pasos(t, "es", ["aux", "correo", "ezlak"], false, "liviano")
		"fbui_objetivos": await _objetivos(t)
		"fbui_aviso": await _aviso(t)
		"fbui_reserva": await _reserva(t)
		"fbui_ver": await _ver(t, _arg)


## Pone la ventana (sin pantalla la raíz mide 64×64 y la vista sale cuadrada) y la vista lógica que le toca.
func _window(t: Node, win: Vector2i) -> Vector2:
	var root := t.get_tree().root
	var s := minf(win.x / 1920.0, win.y / 1080.0)
	root.size = win
	root.content_scale_size = Vector2i(1920, 1080) if s >= 2.0 / 3.0 else Vector2i((Vector2(win) * 1.5).ceil())
	return root.get_visible_rect().size


func _bad(msg: String) -> void:
	if _fails.size() < 400:
		_fails.append(msg)


func _ws(t: Node) -> Control:
	return t.get_tree().get_first_node_in_group("workstation") as Control


func _settle(t: Node, coach: TrainingCoach) -> void:
	# El panel se acomoda en su _process: dos cuadros para medir y corregir, y uno más para que la PC se reacomode.
	for i in 5:
		await t.get_tree().process_frame
	var r0 := coach.panel_rect()
	await t.get_tree().process_frame
	if not r0.is_equal_approx(coach.panel_rect()):
		for i in 12:
			await t.get_tree().process_frame


## Mide el panel en la vista actual. `where` = «módulo/paso · fase · tamaño · modo».
func _measure(t: Node, coach: TrainingCoach, where: String, zoom: bool, strict_scroll: bool) -> void:
	_n += 1
	var v := t.get_tree().root.get_visible_rect().size
	var view := Rect2(Vector2.ZERO, v)
	var pr := coach.panel_rect()
	_max_h = maxf(_max_h, pr.size.y / v.y)
	if not coach.panel.is_visible_in_tree():
		return
	if pr.size.x < 300.0 or pr.size.y < 100.0:
		_bad("%s: panel demasiado chico %s" % [where, str(pr)])
	if not view.grow(0.5).encloses(pr):
		_bad("%s: el panel sale de la vista %s (vista %s)" % [where, str(pr), str(v)])
	for b in coach.live_buttons():
		var br := b.get_global_transform() * Rect2(Vector2.ZERO, b.size)
		if not view.grow(0.5).encloses(br) or not pr.grow(0.5).encloses(br):
			_bad("%s: el botón «%s» no está entero a la vista %s (panel %s)" % [where, (b as Button).text, str(br), str(pr)])
	# El texto del paso: a la vista (o alcanzable con el scroll, con el pie fijo).
	var sc := coach.scroll.get_global_transform() * Rect2(Vector2.ZERO, coach.scroll.size)
	if not pr.grow(0.5).encloses(sc) or sc.size.y < 20.0:
		_bad("%s: el área del texto no cabe en el panel %s (panel %s)" % [where, str(sc), str(pr)])
	if strict_scroll and coach.scrolls():
		_bad("%s: a 1920×1080 el paso necesita scroll (panel %s)" % [where, str(pr)])
	# Ninguna etiqueta con menos alto que sus líneas (lo que no cabe va con scroll, nunca cortado).
	var cut := coach.clipped_labels()
	if not cut.is_empty():
		_bad("%s: texto cortado en %s (panel %s)" % [where, ", ".join(PackedStringArray(cut)), str(pr)])
	# Mini-check: mientras no se contesta, un botón fijo por opción en el pie (live_buttons ya comprobó que se ven);
	# a 1920×1080, además, las tres opciones enteras sin scroll.
	if coach.opts_box.is_visible_in_tree():
		_quiz_n += 1
		var pinned := 0
		for b in coach.btn_ans:
			if b.is_visible_in_tree():
				pinned += 1
		var open_q := coach.option_button(0) != null and not coach.option_button(0).disabled
		if open_q and pinned != coach.opts_box.get_child_count():
			_bad("%s: mini-check con %d opciones y %d botones fijos en el pie" % [where, coach.opts_box.get_child_count(), pinned])
		if not open_q and (pinned != 0 or not coach.btn_next.is_visible_in_tree()):
			_bad("%s: mini-check contestado sin «Continuar» a la vista (o con los botones de respuesta todavía puestos)" % where)
		if strict_scroll and coach.hidden_options() > 0:
			_bad("%s: a 1920×1080 hay %d opciones del mini-check fuera de la vista" % [where, coach.hidden_options()])
		if coach.hidden_options() > 0:
			_quiz_scroll += 1
	# Vistas más chicas que 960×540 (no existen en escritorio: la ventana no baja de 1280×720; solo un navegador en una
	# ventana mínima): con la columna del HUD ancha y un cuadro centrado puede no haber sitio ni para el alto mínimo
	# del panel. Ahí el panel se queda en su mínimo (dentro de la vista, con sus botones y su texto: eso se exige
	# siempre, arriba) y lo que pise se cuenta y se informa en vez de fallar.
	var tiny := v.y < 700.0 and pr.size.y <= coach.min_h + 1.0
	var over: Array[String] = []
	var tg := coach.target
	if not tg.is_empty() and bool(tg.get("dentro", false)):
		var tr_: Rect2 = tg["rect"]
		if pr.intersects(tr_):
			over.append("tapa lo que señala (%s en %s)" % [str(tg.get("id", "")), str(tr_)])
	var ws := _ws(t)
	if zoom and ws != null:
		var zr: Rect2 = ws.call("zoom_rect")
		if zr.size.x > 0.0 and pr.intersects(zr):
			_bad("%s: el panel %s tapa las pantallas de la PC %s" % [where, str(pr), str(zr)])
		if zr.size.x > 0.0 and not view.grow(1.0).encloses(zr):
			_bad("%s: las pantallas salen de la vista %s" % [where, str(zr)])
	var hud := coach.hud_column()
	if hud.size.x > 0.0 and pr.intersects(hud):
		_bad("%s: el panel %s tapa la columna del HUD %s" % [where, str(pr), str(hud)])
	# Franja de los subtítulos (hasta 3 renglones del recuerdo: 27 px, 1240 de ancho) y del aviso del HUD (_msg).
	var subs := Rect2(v.x * 0.5 - 620.0, v.y - 90.0 - 3.0 * 40.0, 1240.0, 3.0 * 40.0)
	var msg := Rect2(v.x * 0.5 - 300.0, v.y - 262.0, 600.0, 28.0)
	if pr.intersects(subs) or pr.intersects(msg):
		over.append("entra en la franja de subtítulos/avisos")
	for o in TrainingTargets.obstacles(t.get_tree()):
		if pr.intersects(o):
			over.append("tapa un menú abierto %s" % str(o))
	for o in over:
		if tiny:
			_tiny_overlaps += 1
		else:
			_bad("%s: el panel %s %s" % [where, str(pr), o])


## Un paso, ya dibujado: todas las vistas, con la PC acercada (si hay PC) y sin acercar.
func _gate(t: Node, tut: Node, bot: Node, mod: String, s: Dictionary, phase: String) -> void:
	var coach: TrainingCoach = tut.get("coach")
	if coach == null or not coach.panel.visible:
		return
	bot.set_process(false)
	var root := t.get_tree().root
	var css := root.content_scale_size
	var win0 := root.size
	var ws := _ws(t)
	var key := "%s/%s" % [mod, str(s.get("id", ""))]
	var has_ui := not (s.get("ui", []) as Array).is_empty() or str(s.get("objetivo", "")) != ""
	if phase == "inicio":
		_steps += 1
		if has_ui:
			_ui_steps += 1
	var can_zoom := ws != null and ws.visible and GameState.seated_at != ""
	var resolved := false
	var aux_step := false
	for u in s.get("ui", []):
		if str(u).begins_with("aux:"):
			aux_step = true
	for size in SIZES:
		var lv := _window(t, size)
		var hd := is_equal_approx(lv.y, 1080.0) and lv.x < 1930.0
		for zoom in ([true, false] if can_zoom else [false]):
			if can_zoom:
				ws.call("set_zoom", zoom)
			await _settle(t, coach)
			var where := "%s · %s · ventana %dx%d (vista %.0fx%.0f) · %s" % [key, phase, size.x, size.y, lv.x, lv.y, "PC acercada" if zoom else ("sentado" if can_zoom else "de pie")]
			_measure(t, coach, where, zoom, hd)
			if zoom:
				_zoom_n += 1
			if not coach.target.is_empty():
				resolved = true
				var z := str(coach.target.get("zona", ""))
				_zones[z] = int(_zones.get(z, 0)) + 1
			if aux_step and can_zoom and size in [Vector2i(1280, 720), Vector2i(960, 540)] and GameState.logged_in:
				# El mismo paso con el menú AUX abierto: señala el botón del menú y no tapa el menú.
				ws.call("_toggle_aux_menu", true)
				await _settle(t, coach)
				_measure(t, coach, where + " · menú AUX", zoom, false)
				if str(coach.target.get("id", "")).begins_with("aux_menu:") == false:
					_bad("%s: con el menú AUX abierto debería señalar su botón (señala «%s»)" % [where, str(coach.target.get("id", ""))])
				ws.call("_toggle_aux_menu", false)
		if can_zoom and size == Vector2i(1280, 720):
			for lay in [1, 2]:  # [Tab]: una sola pantalla acercada
				ws.set("_layout", lay)
				ws.call("set_zoom", true)
				await _settle(t, coach)
				_measure(t, coach, "%s · %s · ventana 1280x720 · solo pantalla %s" % [key, phase, "izquierda" if lay == 1 else "derecha"], true, true)
			ws.set("_layout", 0)
	root.size = win0
	root.content_scale_size = css
	if can_zoom:
		ws.call("set_zoom", false)
	if phase == "inicio" and has_ui:
		if resolved:
			_with_target += 1
		elif not LATE_TARGET.has(key):
			_unresolved.append(key)
	_true_ups = coach.true_ups
	await t.get_tree().process_frame
	bot.set_process(true)


func _pasos(t: Node, lang: String, mods: Array, wrong_odd: bool, quality: String = "") -> void:
	_fails.clear()
	_unresolved.clear()
	_zones.clear()
	_n = 0
	_steps = 0
	_with_target = 0
	_ui_steps = 0
	_zoom_n = 0
	_max_h = 0.0
	_quiz_n = 0
	_quiz_scroll = 0
	_tiny_overlaps = 0
	var lang0 := Loc.language
	Loc.set_language(lang)
	if quality != "":
		GfxQuality.apply(t.get_tree(), quality)
	SaveSlots.select("Llauri")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotFbui"
	bot.set("log_steps", false)
	bot.set("timeout_s", 60000.0)  # segundos de juego (la batería corre a ×8) y cada paso se mide en diez ventanas
	var ids := Tutorial.module_ids()
	var wrong: Array = []
	for i in ids.size():
		if (i % 2 == 1) == wrong_odd:
			wrong.append(ids[i])
	bot.set("quiz_wrong", wrong)
	t.add_child(bot)
	var out: Array = []
	bot.connect("done", func(r: Dictionary) -> void: out.append(r))
	bot.call("start", t.main, mods if not mods.is_empty() else ids, [])
	var tut: Node = t.main.find_child("Tutorial", true, false)
	t.check(tut != null and tut.get("coach") != null, "el Training tiene su guía (TrainingCoach)")
	if tut == null or tut.get("coach") == null:
		bot.queue_free()
		return
	(tut.get("coach") as TrainingCoach).sound = false
	tut.set("step_gate", func(mod: String, s: Dictionary, phase: String) -> void: await _gate(t, tut, bot, mod, s, phase))
	await t.until(func() -> bool: return not out.is_empty(), 60000.0)
	var r: Dictionary = out[0] if not out.is_empty() else {"errores": ["el bot no terminó"], "modulos": {}}
	bot.queue_free()
	var want := mods.size() if not mods.is_empty() else ids.size()
	t.check((r.get("errores", []) as Array).is_empty() and (r.get("modulos", {}) as Dictionary).size() == want, "el bot hizo los %d módulos (%s) sin errores %s" % [want, lang, str(r.get("errores", []))])
	t.check(_steps >= (95 if mods.is_empty() else 20) and _n > _steps * SIZES.size(), "se midieron %d pasos con panel, %d veces (%d con la PC acercada), %d ventanas" % [_steps, _n, _zoom_n, SIZES.size()])
	t.check(_fails.is_empty(), "el panel nunca sale de la vista, sus botones siempre se ven y no tapa lo que señala, la PC, el HUD ni los subtítulos: %d fallos%s" % [_fails.size(), (" · " + " · ".join(PackedStringArray(_fails.slice(0, 12)))) if not _fails.is_empty() else ""])
	t.check(_unresolved.is_empty(), "todo paso con `ui` u `objetivo` señala algo al empezar (%d de %d)%s" % [_with_target, _ui_steps, (" · sin señal: " + ", ".join(PackedStringArray(_unresolved))) if not _unresolved.is_empty() else ""])
	t.check(int(_zones.get("pc", 0)) > 0 and int(_zones.get("pc3d", 0)) > 0 and int(_zones.get("vista", 0)) > 0 and (not mods.is_empty() or int(_zones.get("mundo", 0)) > 0), "señala controles de la PC acercada, del monitor 3D, del overlay/HUD y del mundo %s" % str(_zones))
	t.check(_quiz_n > 0, "mini-checks medidos: %d veces (%d con alguna opción bajo el scroll: se contestan con los botones fijos del pie)" % [_quiz_n, _quiz_scroll])
	t.note("pasos con panel: %d (%d con `ui`/objetivo, %d señalan algo al empezar) · medidas: %d (%d con la PC acercada) · ventanas: %s" % [_steps, _ui_steps, _with_target, _n, _zoom_n, ", ".join(PackedStringArray(SIZES.map(func(v: Vector2i) -> String: return "%dx%d" % [v.x, v.y])))])
	t.note("alto máximo del panel: %.0f %% de la vista · correcciones de medida (etiqueta ≠ regla): %d · vista mínima (711×400) sin sitio para el panel mínimo (pisa un cuadro centrado o el borde de la franja de avisos): %d" % [_max_h * 100.0, _true_ups, _tiny_overlaps])
	if not _fails.is_empty():
		for f in _fails.slice(0, 60):
			print("      · ", f)
	Loc.set_language(lang0)
	if quality != "":
		GfxQuality.apply(t.get_tree(), str(Loc.get_setting("quality", GfxQuality.default_level())))


# --- TrainingTargets --------------------------------------------------------------------------------------

func _start_training(t: Node, mods: Array, stop: String) -> Array:
	SaveSlots.select("Marko")
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotFbui"
	bot.set("log_steps", false)
	bot.set("stop_at", stop)
	t.add_child(bot)
	bot.call("start", t.main, mods, [])
	await t.until(func() -> bool: return bool(bot.get("stopped")), 120.0)
	bot.set_process(false)
	var tut: Node = t.main.find_child("Tutorial", true, false)
	return [bot, tut]


func _resolve(t: Node, tut: Node, ids: Array) -> Dictionary:
	return TrainingTargets.resolve(t.get_tree(), ids, tut)


func _objetivos(t: Node) -> void:
	var pair := await _start_training(t, ["aux"], "aux/menu_aux")
	var bot: Node = pair[0]
	var tut: Node = pair[1]
	var ws := _ws(t)
	var coach: TrainingCoach = tut.get("coach") if tut != null else null
	t.check(tut != null and coach != null and GameState.logged_in and GameState.seated_at == "T-01", "en la T-01, con sesión, en el paso «abre el menú AUX» (%s)" % GameState.seated_at)
	if coach == null:
		return
	coach.sound = false
	var view := Rect2(Vector2.ZERO, t.get_tree().root.get_visible_rect().size)
	# Sin acercar: el control se proyecta sobre el monitor 3D de tu sitio (4 esquinas) y cae dentro de la vista.
	ws.call("set_zoom", false)
	await t.frames(6)
	var a3 := _resolve(t, tut, ["fonex:aux"])
	t.check(str(a3.get("zona", "")) == "pc3d" and (a3.get("poly", PackedVector2Array()) as PackedVector2Array).size() == 4 and view.encloses(a3.get("rect", Rect2())), "sin acercar, la fila de AUX de Fonex se señala sobre el monitor derecho en 3D %s" % str(a3.get("rect", Rect2())))
	var k3 := _resolve(t, tut, ["app:kardex"])
	t.check(str(k3.get("zona", "")) == "pc3d" and (k3.get("rect", Rect2()) as Rect2).get_center().x < (a3.get("rect", Rect2()) as Rect2).get_center().x, "y la pestaña de Kardex, sobre el monitor izquierdo (a la izquierda de Fonex)")
	var mon := _resolve(t, tut, ["monitor"])
	t.check(str(mon.get("zona", "")) == "pc3d" and (mon.get("rect", Rect2()) as Rect2).encloses(a3.get("rect", Rect2())), "«monitor» abarca los dos monitores del sitio %s" % str(mon.get("rect", Rect2())))
	t.check(coach.target.get("id", "") == "fonex:aux" and not coach.panel_rect().intersects(coach.target["rect"]), "el paso señala la fila de AUX y el panel no la toca (panel %s)" % str(coach.panel_rect()))
	# Acercado: el rect exacto sobre la pantalla derecha, dentro de su marco, debajo de la franja de la guía.
	ws.call("set_zoom", true)
	await t.frames(10)
	var zr: Rect2 = ws.call("zoom_rect")
	var a2 := _resolve(t, tut, ["fonex:aux"])
	var ar: Rect2 = a2.get("rect", Rect2())
	t.check(str(a2.get("zona", "")) == "pc" and zr.encloses(ar) and ar.get_center().x > zr.get_center().x and ar.size.x > 300.0, "acercado, la fila de AUX cae en la pantalla derecha %s (pantallas %s)" % [str(ar), str(zr)])
	var one := _resolve(t, tut, ["fonex:aux:1"])
	t.check(ar.encloses(one.get("rect", Rect2())) and (one.get("rect", Rect2()) as Rect2).size.x < ar.size.x * 0.3, "y el botón BO, dentro de esa fila %s" % str(one.get("rect", Rect2())))
	t.check(coach.side == "pc" and coach.panel_rect().end.y <= zr.position.y and is_equal_approx(float(ws.get("reserve_top")), coach.panel_rect().end.y + TrainingCoach.GAP), "la guía es una franja arriba y la PC empieza debajo (franja hasta y=%.0f, pantallas desde %.0f)" % [coach.panel_rect().end.y, zr.position.y])
	# «Aceptar» apagado no se señala: vale el siguiente de la lista.
	var acc := _resolve(t, tut, ["fonex:aceptar", "fonex:kpi"])
	t.check(str(acc.get("id", "")) == "fonex:kpi", "un botón apagado («Aceptar» sin contacto) no se señala: pasa al siguiente id (%s)" % str(acc.get("id", "")))
	# «aux:BO»: el botón de Fonex con el menú cerrado y el del menú con el menú abierto.
	var bo0 := _resolve(t, tut, ["aux:BO"])
	ws.call("_toggle_aux_menu", true)
	await t.frames(6)
	var bo1 := _resolve(t, tut, ["aux:BO"])
	var menus: Array = ws.call("overlay_rects")
	t.check(str(bo0.get("id", "")) == "fonex:aux:1" and str(bo1.get("id", "")) == "aux_menu:1" and menus.size() == 1 and (menus[0] as Rect2).encloses(bo1.get("rect", Rect2())), "«aux:BO» señala el botón de Fonex y, con el menú abierto, el del menú (%s → %s)" % [str(bo0.get("id", "")), str(bo1.get("id", ""))])
	t.check(not coach.panel_rect().intersects(menus[0] as Rect2) if menus.size() == 1 else false, "la guía no tapa el menú AUX abierto")
	ws.call("_toggle_aux_menu", false)
	# El HUD: «AVL» arriba a la derecha, solo el ancho del texto.
	var avl := _resolve(t, tut, ["hud:avl"])
	var hr: Rect2 = avl.get("rect", Rect2())
	t.check(str(avl.get("zona", "")) == "vista" and hr.size.x > 40.0 and hr.size.x < 500.0 and hr.end.x > view.size.x - 40.0 and not coach.panel_rect().intersects(hr), "«hud:avl» = las métricas del HUD, a la derecha (%s), fuera del panel" % str(hr))
	# Ezlaki: el canal en la lista; un id que no existe no señala nada.
	var ch := _resolve(t, tut, ["ezlak:canal:#site-updates"])
	t.check(str(ch.get("zona", "")) == "pc" and zr.encloses(ch.get("rect", Rect2())) and (ch.get("rect", Rect2()) as Rect2).get_center().x > zr.get_center().x, "el canal #site-updates se señala en la lista de Ezlaki %s" % str(ch.get("rect", Rect2())))
	t.check(_resolve(t, tut, ["ezlak:canal:#no-existe", "nada:de:nada"]).is_empty(), "un id que no existe no señala nada")
	# El WW de práctica: el botón Ack del aviso; la guía no tapa el aviso.
	Metrics.issue_written_warning("induccion")
	await t.frames(8)
	var ack := _resolve(t, tut, ["ww:ack"])
	var ov: Array = ws.call("overlay_rects")
	t.check(str(ack.get("zona", "")) == "vista" and not ov.is_empty() and (ov[0] as Rect2).encloses(ack.get("rect", Rect2())) and not coach.panel_rect().intersects(ov[0] as Rect2), "«ww:ack» = el botón Ack del aviso del WW, y la guía no tapa el aviso")
	Metrics.give_ack()
	# De pie: la luz guía del mundo; el objetivo detrás de la cámara va al borde.
	ws.call("set_zoom", false)
	var p: Player = t.player()
	p.stand_up()
	await t.frames(6)
	tut.call("_set_target", "seat:T-01")
	await t.frames(4)
	var wd := _resolve(t, tut, ["fonex:aux", "mundo"])
	t.check(str(wd.get("id", "")) == "mundo" and wd.has("dist"), "de pie, lo de la PC no se señala: vale la luz guía del mundo (a %.1f m)" % float(wd.get("dist", -1.0)))
	p.rotation.y += PI
	await t.frames(4)
	var behind := _resolve(t, tut, ["mundo"])
	t.check(bool(behind.get("detras", false)) != bool(wd.get("detras", false)), "al girar media vuelta el objetivo pasa de delante a detrás (la flecha va al borde)")
	bot.queue_free()


func _aviso(t: Node) -> void:
	var pair := await _start_training(t, ["aux"], "aux/poner_bo")
	var bot: Node = pair[0]
	var tut: Node = pair[1]
	var coach: TrainingCoach = tut.get("coach") if tut != null else null
	t.check(coach != null, "guía creada")
	if coach == null:
		return
	var hud: Node = t.main.get("hud")
	var note_box := hud.get("_note_box") as Control
	# Aviso de paso nuevo: una vez por paso; no ocupa el canal de las voces.
	var sfx: Array = []
	var prev := str(AudioManager.get("last_sfx")) if "last_sfx" in AudioManager else ""
	var cue0 := float(coach.get("_cue_t"))
	coach.set("_cue_t", 0.0)
	var busy0 := VoiceDirector.voices_playing()
	tut.call("_show", "T", "Cuerpo de prueba", "", "leer")
	t.check(is_zero_approx(float(coach.get("_cue_t"))), "reescribir el mismo paso (cambio de idioma) no vuelve a avisar")
	tut.set("current_step", {"id": "otro", "tipo": "leer"})
	tut.call("_show", "T", "Otro paso", "", "leer")
	t.check(float(coach.get("_cue_t")) > 0.5 and VoiceDirector.voices_playing() == busy0, "un paso nuevo avisa (destello %.2f s) sin ocupar el canal de las voces" % float(coach.get("_cue_t")))
	t.check(AudioManager.has_slot("sfx/tut_paso", false), "el sonido del aviso existe (sfx/tut_paso)")
	sfx.append(prev)
	sfx.append(cue0)
	# El aviso de texto del HUD sale dentro de la guía.
	VoiceDirector.notice("ezlak", "@Shero · Shero: Break. Ok.", 2.0, true)
	await t.frames(6)
	t.check(coach.notice_text().contains("Shero: Break. Ok.") and not note_box.visible, "con la guía a la vista, el aviso de texto sale dentro de ella y no en la franja del HUD («%s»)" % coach.notice_text())
	var pr := coach.panel_rect()
	var v := t.get_tree().root.get_visible_rect().size
	t.check(Rect2(Vector2.ZERO, v).encloses(pr), "y el panel sigue entero en la vista con el aviso dentro %s" % str(pr))
	VoiceDirector.clear_notices()
	await t.frames(4)
	t.check(coach.notice_text() == "", "al quitarse el aviso, la guía lo suelta")
	# Entre dos pasos el panel se apaga y vuelve a encenderse.
	coach.set_idle(true)
	t.check(coach.panel.modulate.a < 0.8, "entre dos pasos el panel se apaga")
	tut.set("current_step", {"id": "otro2", "tipo": "esperar"})
	tut.call("_show", "T", "Paso siguiente", "", "esperar")
	t.check(is_equal_approx(coach.panel.modulate.a, 1.0) and coach.waiting, "y se enciende con el paso siguiente")
	# Con mando: los botones nombran su botón; sin mando, solo la tecla.
	t.check(InputMap.action_get_events("tutorial_next").size() == 2 and str(tut.call("_btn_text", "TUT_BTN_NEXT", "tutorial_next")).contains("[T"), "«Continuar» responde a [T] y al botón Back del mando (%s)" % Controls.describe("tutorial_next", true))
	# Fuera del Training: el aviso vuelve al HUD y la PC recupera su encuadre.
	var ws := _ws(t)
	ws.call("set_zoom", true)
	await t.frames(8)
	t.check(float(ws.get("reserve_top")) > 100.0, "con la PC acercada la guía reserva su franja (%.0f px)" % float(ws.get("reserve_top")))
	bot.queue_free()
	await t.back_to_menu()
	await t.frames(6)
	t.check(is_zero_approx(float(ws.get("reserve_top"))) and t.get_tree().get_nodes_in_group("hud_notice_host").is_empty(), "al salir del Training la PC recupera su encuadre y no queda guía")
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	VoiceDirector.notice("ezlak", "@Shero · Shero: Break. Ok.", 2.0, true)
	await t.frames(6)
	t.check(note_box.visible, "en un turno normal el aviso de texto sale en el HUD como siempre")
	VoiceDirector.clear_notices()


func _reserva(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var ws := _ws(t)
	ws.call("set_zoom", true)
	await t.frames(6)
	for area: Vector2 in [Vector2(1920, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		ws.set("layout_area_override", area)
		ws.set("reserve_top", 0.0)
		ws.call("_layout_zoom")
		await t.frames(4)
		var r0: Rect2 = ws.call("zoom_rect")
		var top0 := maxf(area.y * 0.12, (area.y - 30.0 - r0.size.y) * 0.5)
		t.check(absf(r0.position.y - top0) < 1.5 and r0.size.x >= area.x * 0.9 * 0.97, "%dx%d sin reserva: el encuadre de siempre (pantallas %s)" % [int(area.x), int(area.y), str(r0)])
		ws.set("reserve_top", 230.0)
		ws.call("_layout_zoom")
		await t.frames(4)
		var r1: Rect2 = ws.call("zoom_rect")
		# 16:9 y 16:10: mismo ancho (solo pierden alto). 21:9: la pantalla ya está en su alto mínimo (492) y cede un 1 %.
		var keep := 0.999 if area.x / area.y < 2.0 else 0.97
		t.check(r1.position.y >= 230.0 - 0.5 and r1.size.x >= r0.size.x * keep and r1.end.y <= r0.end.y + 1.0 and int(ws.call("screen_height")) >= 492, "%dx%d con 230 px reservados: las pantallas empiezan debajo y conservan el ancho (%.0f → %.0f; alto de pantalla %d)" % [int(area.x), int(area.y), r0.size.x, r1.size.x, int(ws.call("screen_height"))])
	ws.set("layout_area_override", Vector2.ZERO)
	ws.set("reserve_top", 0.0)
	ws.call("set_zoom", false)


## Depuración (no corre con «all»): `--escenario fbui_ver:<modulo>.<paso>.<ancho>.<alto>[.zoom]` imprime cómo quedó la guía.
func _ver(t: Node, arg: String) -> void:
	var a := arg.split(".")
	var pair := await _start_training(t, [a[0]], "%s/%s" % [a[0], a[1]])
	var bot: Node = pair[0]
	var tut: Node = pair[1]
	var coach: TrainingCoach = tut.get("coach")
	coach.sound = false
	var root := t.get_tree().root
	var css := root.content_scale_size
	var win0 := root.size
	_window(t, Vector2i(int(a[2]), int(a[3])))
	var ws := _ws(t)
	if a.size() > 4 and ws != null:
		ws.call("set_zoom", true)
	await _settle(t, coach)
	var v := root.get_visible_rect().size
	var m: Dictionary = coach.call("_measure", coach.panel.size.x, coach.zoomed())
	print("[ver] vista %s · lado %s · panel %s · min panel %s" % [str(v), coach.side, str(coach.panel_rect()), str(coach.panel.get_combined_minimum_size())])
	print("[ver] scroll %s (min %s) · contenido %s (min %s) · medidas %s" % [str(coach.scroll.size), str(coach.scroll.get_combined_minimum_size()), str(coach.get("_content").size), str(coach.get("_content").get_combined_minimum_size()), str(m)])
	for c in coach.panel.get_node("VB").get_children():
		print("[ver]   %s  min %s  size %s  visible %s" % [c.name, str((c as Control).get_combined_minimum_size()), str((c as Control).size), str((c as Control).visible)])
	for c in coach.get("_content").get_children():
		print("[ver]     %s  min %s  size %s  visible %s" % [c.name, str((c as Control).get_combined_minimum_size()), str((c as Control).size), str((c as Control).visible)])
	print("[ver] objetivo %s · HUD %s · evita %s · reserva %.0f" % [str(coach.target), str(coach.hud_column()), str(coach.avoid_rects()), float(ws.get("reserve_top")) if ws != null else -1.0])
	t.check(true, "visto")
	root.size = win0
	root.content_scale_size = css
	bot.queue_free()

class_name EzlakiCaptura
extends Node
## «Captura de pantalla» de la vista de adherencia en tiempo real (v0.3.1 Q3, pedido de Joan 10:53Z): cuando Shero o el
## Perrito RTA tagean a alguien en #allocations (AUX que no es, correo pasado, break excedido, contacto perdido, ACW…)
## pegan una imagen de la tabla, como un supervisor de call center de verdad. Filas «alias@kipupay.kp (Apellidos,
## Nombre)» con identidades INVENTADAS del juego (data/ezlaki_q3.json/capturas), el desplegable del estado y el
## cronómetro en naranja (rojo si se pasó); la fila del infractor resaltada. Tema oscuro o claro; una fila (el tag) o
## una lista (@here … pasamos a BO). La imagen se arma con Controls y se dibuja UNA vez en un SubViewport (se guarda
## como ImageTexture; sin GPU/headless queda un marcador del mismo tamaño). Clic en la imagen = verla grande (ezlak.gd).

const W := 520
const ROW_H := 30
const PAD := 8
const ESTADOS: Array[String] = ["available", "bo", "break", "lunch", "bano", "coaching", "training", "contacto", "perdido", "acw"]
## segundos de juego a partir de los cuales el cronómetro sale en rojo
const LIMITE := {"break": 600, "bano": 300, "acw": 120, "lunch": 2700, "contacto": 600, "perdido": 0, "coaching": 900}

var cache: Dictionary = {}  # id -> Texture2D
var built: int = 0  # pruebas
var _rng := RandomNumberGenerator.new()

signal ready_shot(id: int)


static func cfg() -> Dictionary:
	return DataLoader.dict("ezlaki_q3").get("capturas", {})


static func identity(slug: String) -> Dictionary:
	var c := cfg()
	var ids: Dictionary = c.get("identidades", {})
	var dom := str(c.get("dominio", "kipupay.kp"))
	var row: Array = ids.get(slug, [slug, slug.capitalize(), slug.capitalize()])
	return {"slug": slug, "correo": "%s@%s" % [row[0], dom], "apellidos": str(row[1]), "nombre": str(row[2]),
		"texto": "%s@%s (%s, %s)" % [row[0], dom, row[1], row[2]]}


static func state_text(key: String) -> String:
	return Loc.pick((cfg().get("estados", {}) as Dictionary).get(key, {"es": key, "en": key}))


static func hms(secs: float) -> String:
	var s := int(maxf(secs, 0.0))
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


## Estado del jugador (clave de ESTADOS) según su AUX actual (y «En contacto» si atiende un caso en Available/BO).
static func player_state() -> String:
	var keys: Array[String] = ["available", "bo", "break", "lunch", "bano", "coaching", "training"]
	var k := keys[clampi(Metrics.aux, 0, keys.size() - 1)]
	var tree := Engine.get_main_loop() as SceneTree
	var cm := tree.get_first_node_in_group("contact_manager") as ContactManager if tree != null else null
	if k in ["available", "bo"] and cm != null and cm.case != null:
		return "contacto"
	return k


## Datos de la captura para un mensaje: {tema, tipo, filas: [{slug, texto, estado, estado_txt, segundos, cron, rojo,
## destacado}]}. spec: {tipo: uno|lista, estado, quien: "jugador" | slug | "a,b", n, tema}.
func make(spec: Dictionary, seed_id: int) -> Dictionary:
	_rng.seed = 9100 + seed_id * 31 + GameState.turno
	if str(spec.get("tipo", "")) == "hoja":
		# miniatura de planilla borrosa (caso diario): solo barras, ningún texto legible
		var rows: Array = []
		for r in clampi(int(spec.get("n", 12)), 4, 16):
			var cells: Array = []
			for c in 6:
				cells.append(_rng.randf_range(0.25, 0.95))
			rows.append(cells)
		return {"tema": str(spec.get("tema", "claro")), "tipo": "hoja", "filas": [], "celdas": rows}
	var me := GameState.agent.to_lower()
	var tipo := str(spec.get("tipo", "uno"))
	var estado := str(spec.get("estado", ""))
	var quien: Array = []
	for q in str(spec.get("quien", "jugador" if tipo == "uno" else "")).split(",", false):
		quien.append(me if q.strip_edges() == "jugador" else q.strip_edges())
	var pool: Array = (cfg().get("identidades", {}) as Dictionary).keys()
	pool.erase(me)
	for q in quien:
		pool.erase(q)
	# barajado con semilla
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var slugs: Array = quien.duplicate()
	if tipo == "lista":
		var n := clampi(int(spec.get("n", 6)), 2, 8)
		if not slugs.has(me) and _rng.randf() < 0.75:
			slugs.append(me)  # te ves en la lista
		while slugs.size() < n and not pool.is_empty():
			slugs.append(pool.pop_back())
	if slugs.is_empty():
		slugs.append(me)
	var filas: Array = []
	for s in slugs:
		var sl := str(s)
		var est := estado
		var secs := 0.0
		if sl == me:
			# el jugador sale con su estado real salvo que el post diga otro (pista de disciplina, «cerramos los casos»)
			if est == "" or (tipo == "lista" and not quien.has(me)):
				est = player_state()
			secs = Metrics.seconds_in_current_aux() if est == player_state() else _fake_secs(est, quien.has(me))
		else:
			if est == "":
				est = ESTADOS[_rng.randi_range(0, 3)]
			secs = _fake_secs(est, quien.has(sl))
		var lim := float(LIMITE.get(est, 99999))
		var red := secs >= lim or est == "perdido"
		filas.append({"slug": sl, "texto": identity(sl)["texto"], "estado": est, "estado_txt": state_text(est),
			"segundos": secs, "cron": hms(secs), "rojo": red, "destacado": quien.has(sl)})
	return {"tema": str(spec.get("tema", "oscuro")), "tipo": tipo, "filas": filas}


func _fake_secs(est: String, offender: bool) -> float:
	var lim := float(LIMITE.get(est, 1200))
	match est:
		"bo", "available", "training":
			return _rng.randf_range(4.0, 1300.0)
		"perdido":
			return _rng.randf_range(6.0, 40.0)
	return _rng.randf_range(lim * 1.15, lim * 2.6) if offender else _rng.randf_range(lim * 0.2, lim * 1.6)


## Planilla borrosa: celdas con barras grises (como texto desenfocado) y la cabecera verde.
static func _build_sheet(data: Dictionary) -> PanelContainer:
	var root := PanelContainer.new()
	root.name = "CapturaPlanilla"
	root.add_theme_stylebox_override("panel", PcStyle.box(Color(1, 1, 1), Color(0.82, 0.82, 0.85), PAD, 3))
	root.custom_minimum_size = Vector2(W, 0)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	root.add_child(grid)
	var rows: Array = [[0.8, 0.6, 0.7, 0.5, 0.6, 0.4]] + (data.get("celdas", []) as Array)
	for ri in rows.size():
		for c in 6:
			var cell := PanelContainer.new()
			var head := ri == 0
			cell.add_theme_stylebox_override("panel", PcStyle.box(Color(0.82, 0.92, 0.84) if head else (Color(0.97, 0.97, 0.98) if ri % 2 else Color(1, 1, 1)), Color(0.88, 0.88, 0.9), 3, 0))
			cell.custom_minimum_size = Vector2(W / 6.0 - 1.0, 14)
			var bar := ColorRect.new()
			bar.color = Color(0.45, 0.5, 0.48, 0.55) if head else Color(0.55, 0.57, 0.6, 0.35)
			bar.custom_minimum_size = Vector2((W / 6.0 - 10.0) * float(rows[ri][c]), 5)
			bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(bar)
			grid.add_child(cell)
	return root


## Control de la tabla (también lo usan las pruebas para leer los textos).
static func build_control(data: Dictionary) -> PanelContainer:
	if str(data.get("tipo", "")) == "hoja":
		return _build_sheet(data)
	var dark := str(data.get("tema", "oscuro")) != "claro"
	var bg := Color(0.09, 0.1, 0.12) if dark else Color(1, 1, 1)
	var line := Color(0.2, 0.22, 0.25) if dark else Color(0.88, 0.88, 0.9)
	var txt := Color(0.62, 0.66, 0.7) if dark else Color(0.28, 0.3, 0.33)
	var hi := Color(0.2, 0.14, 0.08) if dark else Color(1.0, 0.92, 0.92)
	var orange := Color(0.98, 0.62, 0.12)
	var red := Color(1.0, 0.27, 0.2) if dark else Color(0.86, 0.12, 0.12)
	var mono := load("res://assets/fonts/DejaVuSansMono.ttf") as Font  # trae ▾ y números parejos para el cronómetro
	var root := PanelContainer.new()
	root.name = "CapturaAdherencia"
	root.add_theme_stylebox_override("panel", PcStyle.box(bg, line, PAD, 4))
	root.custom_minimum_size = Vector2(W, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	root.add_child(vb)
	for f in data.get("filas", []):
		var row := PanelContainer.new()
		var rb := PcStyle.box(hi if bool(f.get("destacado", false)) else bg, Color(0, 0, 0, 0), 3, 0)
		rb.border_color = line
		rb.border_width_bottom = 1
		row.add_theme_stylebox_override("panel", rb)
		row.custom_minimum_size = Vector2(0, ROW_H)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var who := Label.new()
		who.name = "Identidad"
		who.text = str(f.get("texto", ""))
		who.add_theme_font_size_override("font_size", 11)
		who.add_theme_color_override("font_color", txt)
		who.custom_minimum_size = Vector2(238, 0)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(who)
		var chip := PanelContainer.new()
		var cb := PcStyle.box(Color(0.12, 0.13, 0.16) if dark else Color(1, 1, 1), Color(0.36, 0.4, 0.46) if dark else Color(0.75, 0.75, 0.78), 3, 3)
		if str(f.get("estado", "")) == "perdido" and not dark:
			cb.border_color = red
		chip.add_theme_stylebox_override("panel", cb)
		chip.custom_minimum_size = Vector2(150, 0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cl := Label.new()
		cl.name = "Estado"
		cl.text = "%s  ▾" % str(f.get("estado_txt", ""))
		cl.add_theme_font_size_override("font_size", 11)
		if mono != null:
			cl.add_theme_font_override("font", mono)
		cl.add_theme_color_override("font_color", red if str(f.get("estado", "")) == "perdido" else (Color(0.85, 0.88, 0.9) if dark else Color(0.2, 0.22, 0.25)))
		chip.add_child(cl)
		hb.add_child(chip)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(sp)
		var tl := Label.new()
		tl.name = "Cronometro"
		tl.text = str(f.get("cron", "00:00:00"))
		tl.add_theme_font_size_override("font_size", 12)
		if mono != null:
			tl.add_theme_font_override("font", mono)
		tl.add_theme_color_override("font_color", red if bool(f.get("rojo", false)) else orange)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(tl)
		vb.add_child(row)
	return root


static func size_of(data: Dictionary) -> Vector2i:
	if str(data.get("tipo", "")) == "hoja":
		return Vector2i(W + PAD * 2, ((data.get("celdas", []) as Array).size() + 1) * 15 + PAD * 2 + 2)
	return Vector2i(W + PAD * 2, (data.get("filas", []) as Array).size() * (ROW_H + 1) + PAD * 2 + 4)


## Textura de la captura (cacheada por id). La primera vez devuelve un marcador y la imagen real llega con ready_shot.
func texture_for(id: int, data: Dictionary) -> Texture2D:
	if cache.has(id):
		return cache[id]
	var sz := size_of(data)
	var ph := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	ph.fill(Color(0.09, 0.1, 0.12) if str(data.get("tema", "oscuro")) != "claro" else Color(0.97, 0.97, 0.98))
	var tex := ImageTexture.create_from_image(ph)
	cache[id] = tex
	built += 1
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		_render(id, data, sz)
	return tex


func _render(id: int, data: Dictionary, sz: Vector2i) -> void:
	var vp := SubViewport.new()
	vp.name = "CapturaVP%d" % id
	vp.size = sz
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := build_control(data)
	c.size = Vector2(sz)
	vp.add_child(c)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var it := cache[id] as ImageTexture
		if it != null and it.get_size() == Vector2(img.get_size()):
			it.update(img)
		else:
			cache[id] = ImageTexture.create_from_image(img)
	vp.queue_free()
	ready_shot.emit(id)

class_name RecuerdosSemana
extends Node
## v0.3.2 · Ecos del Training en la semana (el presente). El recuerdo no se queda en el recuerdo:
##   1. La POLAROID de tu promoción está apoyada en tu mesa, en C-14, todos los días. Es la foto que el Trainer tomó
##      en el Training (la tuya, guardada en la carpeta de la partida; en las partidas viejas, desteñida). De pie junto
##      a la mesa, [E] la mira de cerca. La primera vez que te sientas en C-14, tu agente piensa en ella (con voz):
##      «Promoción del 25 de agosto de 2023. Éramos cinco. Nayra duró tres meses. Yimi, seis. Quedo yo.»
##   2. El primer CAFÉ que pagas en la expendedora: «Dos cincuenta. "Cortesía de la empresa", decía el Trainer.»
##   3. La foto CAMBIA: el martes ya no sale Zuly; desde el miércoles, tampoco Kenyi (las tres copias se sacaron el día
##      de la foto: Tutorial._photo_variants). Al mirarla de cerca tu agente lo nota: «Zuly salía aquí, a la izquierda.
##      Lo sé. ¿Lo sé?» · «Kenyi tampoco. No voy a mirar más esta foto.»
##   4. El COMODÍN: la primera vez que llamas a un compañero de hoy, «Antes llamaba a Nayra. Contestaba al toque.»
##   5. Tu CONTRATO firmado, amarillento, clavado junto a la puerta del aula de training (piso 1) desde el martes, con
##      TU firma (los trazos que hiciste). [E] lo mira: la letra chica y «Mi firma. La hice sonriendo.»
##   6. Cuando el Trainer de hoy te suelta de la «Actualización de campaña», repite la frase amable del recuerdo:
##      «Aquí siempre se vuelve. Siempre.»
##   7. La pantalla de desconexión cita, abajo y en chico, la CLÁUSULA del contrato que justifica esa muerte (entera si
##      la leíste antes de firmar; si no, «la firmaste sin leerla»). No toca el código de las muertes: escucha
##      EventBus.death_shown y agrega un rótulo a la pantalla.
## Cada eco suena una vez por partida (progreso «recuerdo»: eco_foto / eco_cafe…), por el VoiceDirector con prioridad
## AMBIENTE: si alguien más habla, espera; si no llega a sonar, lo intenta la próxima vez. Nunca en el Training.
## Lo crea Main._build_world. Textos: turnos.json → ecos (tools/v032_training_guion.py); voces/agentes/<agente>_<eco>.

const SEAT := "C-14"
const PHOTO_FILE := "foto_promocion.jpg"
const PHOTO_FILES := ["foto_promocion.jpg", "foto_promocion_2.jpg", "foto_promocion_3.jpg"]  # entera · sin Zuly · sin Zuly ni Kenyi
## Lo que piensa al mirar la foto de cerca según la copia del día (lunes: lo que le pasó a cada uno; martes y
## miércoles: quién ya no sale). Al sentarte el lunes suena «eco_foto», más corto (la primera llamada entra enseguida).
const PHOTO_ECHO := ["eco_foto_cerca", "eco_foto_2", "eco_foto_3"]
const HEARD_MIN := 0.5  # un eco cuenta como dicho si sonó al menos la mitad (si lo cortó una llamada, vuelve a intentarlo)
const RETRY_S := 20.0  # el pensamiento de la foto, cortado o sin sonar: otro intento si sigues sentado y hay silencio
const RETRY_MAX := 3
const CONTRACT_POS := Vector3(8.15, 1.5, -1.426)  # piso 1: pegado a la cara interior del machón (z −1,42), junto a la puerta del aula
## «Una copia va al mural del piso uno, con todas las promociones» (el Trainer, el día de la foto). Piso 1, dentro del
## aula de training, en la pared blanca del frente (x 10..13,5): casi todas las fotos ya se borraron con el sol.
const MURAL_POS := Vector3(11.75, 1.52, -1.412)
const MURAL_COLS := 8
const MURAL_ROWS := 3
const MURAL_MINE := 13  # el hueco de tu promoción (fila del medio)
const MURAL_LEFT := [2, 9, 13, 20]  # las que todavía se ven: la tuya y tres que nadie descolgó
## Qué cláusula del contrato (data/contrato.json) justifica cada desconexión. Las que no están: la 15 (renovación).
const CLAUSE_BY_DEATH := {
	"break_excedido": 6, "tercer_break": 6, "lunch_excedido": 6,
	"abandono": 4, "otra_isla": 4, "work_avoiding": 4, "available_bajo": 4, "aux_incorrecto": 4, "llamadas_perdidas": 4, "regreso_tardio": 4,
	"coaching_sin_permiso": 10, "coaching_exceso": 10, "coaching": 10, "qa_inasistencia": 10, "calibracion_final": 10, "tres_molestos": 10,
	"aht_bo": 10, "reflejo_kyc": 10,
	"ww_sin_ack": 11, "tercer_ww": 11,
	"training_reprobado": 7, "training_inasistencia": 7,
	"correo_vitzo": 8, "wmm_correo_vitzo": 8, "wmm_pod_correo": 8, "vitzo_reminder": 8,
	"rasec_evento": 1, "colapso": 3,
}
const POS := Vector3(-0.6, 0.752, -0.34)  # local del cubículo: apoyada en el pie del monitor izquierdo

var building: Building = null
var photo: Node3D = null
var _busy: Dictionary = {}  # eco -> ya está pidiendo la línea
var _retries: int = 0  # reintentos del pensamiento de la foto en este turno


## Dónde queda la foto de promoción del agente (carpeta de su partida principal). `variant`: 1 entera · 2 · 3.
static func photo_path(agent: String, variant: int = 1) -> String:
	return SaveSlots.root + SaveSlots.slug(agent) + "/" + str(PHOTO_FILES[clampi(variant, 1, PHOTO_FILES.size()) - 1])


## La copia de la foto que toca hoy: lunes la entera; martes ya sin Zuly; desde el miércoles, sin Zuly ni Kenyi. Si
## esa copia no existe (partidas de antes), la anterior.
static func photo_variant(agent: String) -> int:
	var want := clampi(GameState.turno, 1, PHOTO_FILES.size())
	while want > 1 and not FileAccess.file_exists(photo_path(agent, want)):
		want -= 1
	return want


static func load_photo(agent: String, variant: int = 0) -> Texture2D:
	var p := photo_path(agent, variant if variant > 0 else photo_variant(agent))
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	return ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null


static func record() -> Dictionary:
	var r: Variant = SaveSlots.progress().get("recuerdo", {})
	return r if r is Dictionary else {}


static func mark(key: String) -> void:
	var p := SaveSlots.progress()
	var r: Dictionary = p.get("recuerdo", {}) if p.get("recuerdo", {}) is Dictionary else {}
	r[key] = true
	p["recuerdo"] = r


func setup(b: Building) -> void:
	building = b
	if b != null:
		b.floor_loaded.connect(_on_floor)
	EventBus.player_seated.connect(_on_seated)
	EventBus.shop_bought.connect(_on_bought)
	EventBus.death_shown.connect(_on_death_shown)
	EventBus.training_ended.connect(_on_training_ended)
	Comodin.call_started.connect(_on_comodin)


func _active() -> bool:
	return GameState.turno >= 1 and not Flashback.active and GameState.agent != ""


func _on_floor(n: int, fl: Node3D) -> void:
	photo = null
	if n == 1 and _active() and GameState.turno >= 2 and bool(SaveSlots.contract(GameState.agent).get("firmado", false)):
		_build_contract(fl)
	if n == 1 and _active():
		_build_mural(fl)
	if n != 2 or not _active() or not (fl is FloorBase):
		return
	var seat := (fl as FloorBase).seat_by_id(SEAT)
	if seat == null or not (seat.get_parent() is Node3D):
		return
	photo = _build(seat.get_parent() as Node3D)


## El mural de promociones del piso 1: un corcho con tres filas de polaroids. Casi todas están borradas por el sol
## (papel en blanco con su chinche); quedan tres de otros años, apenas, y la tuya, con la copia de la foto que toca hoy.
## [E] la muestra de cerca, igual que la de tu mesa. Sin colisión ni sombras: es un rótulo más de la pared.
func _build_mural(fl: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "MuralPromociones"
	root.position = MURAL_POS
	root.rotation_degrees = Vector3(0, 180.0, 0)  # mira al aula
	fl.add_child(root)
	var w := 2.5
	var h := 1.16
	var cork := Greybox.box(root, "Corcho", Vector3.ZERO, Vector3(w, h, 0.014), Color(0.8, 0.67, 0.48), false)  # claro: el aula de hoy tiene poca luz y fría
	cork.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sgn in [-1.0, 1.0]:
		Greybox.box(root, "Liston%s" % ("A" if sgn < 0.0 else "B"), Vector3(0, sgn * (h * 0.5 + 0.012), 0.004), Vector3(w + 0.05, 0.025, 0.024), Color(0.3, 0.22, 0.15), false)
		Greybox.box(root, "Larguero%s" % ("A" if sgn < 0.0 else "B"), Vector3(sgn * (w * 0.5 + 0.012), 0, 0.004), Vector3(0.025, h, 0.024), Color(0.3, 0.22, 0.15), false)
	var title := Greybox.label(root, tr("ECO_MURAL_TITULO"), Vector3(0, h * 0.5 - 0.085, 0.012), 0.075, Color(0.93, 0.88, 0.74))
	title.outline_size = 0
	title.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var tex := load_photo(GameState.agent)
	var cw := (w - 0.2) / MURAL_COLS
	var ch := (h - 0.26) / MURAL_ROWS
	for i in MURAL_COLS * MURAL_ROWS:
		var slot := Node3D.new()
		slot.name = "Promo%d" % i
		slot.position = Vector3(-w * 0.5 + 0.1 + cw * (i % MURAL_COLS + 0.5) + rng.randf_range(-0.012, 0.012), h * 0.5 - 0.2 - ch * (floorf(float(i) / MURAL_COLS) + 0.5) + rng.randf_range(-0.01, 0.01), 0.009)
		slot.rotation_degrees.z = rng.randf_range(-4.0, 4.0)
		root.add_child(slot)
		var paper := Greybox.box(slot, "Papel", Vector3.ZERO, Vector3(0.2, 0.235, 0.003), Color(0.9, 0.88, 0.82).darkened(rng.randf_range(0.0, 0.1)), false)
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Greybox.box(slot, "Chinche", Vector3(0, 0.1, 0.004), Vector3(0.012, 0.012, 0.006), Color(0.62, 0.1, 0.08) if i == MURAL_MINE else Color(0.35, 0.36, 0.38), false)
		var pic := MeshInstance3D.new()
		pic.name = "Foto"
		var q := QuadMesh.new()
		q.size = Vector2(0.176, 0.132)
		pic.mesh = q
		pic.position = Vector3(0, 0.022, 0.0022)
		pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()  # con la luz del aula, como el papel: una foto que brilla sola no es una foto
		mat.roughness = 0.9
		if i == MURAL_MINE and tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(0.95, 0.9, 0.82)  # la tuya todavía se ve
		elif MURAL_LEFT.has(i) and i != MURAL_MINE:
			mat.albedo_color = Color(0.42, 0.38, 0.33).lerp(Color(0.3, 0.34, 0.36), rng.randf())  # una mancha: ya no se sabe quiénes eran
		else:
			mat.albedo_color = Color(0.8, 0.76, 0.66).darkened(rng.randf_range(0.0, 0.08))  # borrada por el sol
		pic.material_override = mat
		slot.add_child(pic)
	var area := MuralBoard.new()
	area.name = "MuralArea"
	area.size = Vector3(w, h, 0.5)
	area.position = Vector3(0, 0, 0.22)
	area.owner_node = self
	root.add_child(area)
	return root


class MuralBoard extends Interactable:
	var owner_node: RecuerdosSemana = null

	func hint_text() -> String:
		return tr("HUD_ECO_MURAL")

	func interact(player: Node) -> bool:
		if owner_node != null and is_instance_valid(owner_node):
			owner_node.look()
		interacted.emit(player)
		return true


## La polaroid: marco blanco inclinado contra el monitor, con la foto (o desteñida) y su zona de [E].
func _build(cub: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "PolaroidPromocion"
	root.position = POS
	root.rotation_degrees = Vector3(-18.0, 14.0, 0.0)
	cub.add_child(root)
	var frame := Greybox.box(root, "Moldura", Vector3(0, 0.06, 0), Vector3(0.1, 0.12, 0.004), Color(0.93, 0.91, 0.85), false)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pic := MeshInstance3D.new()
	pic.name = "Foto"
	var q := QuadMesh.new()
	q.size = Vector2(0.086, 0.074)
	pic.mesh = q
	pic.position = Vector3(0, 0.072, 0.0026)
	var mat := StandardMaterial3D.new()
	var tex := load_photo(GameState.agent)
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.82, 0.78, 0.7)  # desteñida por tres años de fluorescente
	else:
		mat.albedo_color = Color(0.72, 0.66, 0.55)
	mat.roughness = 0.9
	pic.material_override = mat
	root.add_child(pic)
	var area := Polaroid.new()
	area.name = "PolaroidArea"
	area.size = Vector3(0.24, 0.22, 0.2)
	area.position = Vector3(0, 0.06, 0.02)
	area.owner_node = self
	root.add_child(area)
	return root


class Polaroid extends Interactable:
	var owner_node: RecuerdosSemana = null

	func hint_text() -> String:
		return tr("HUD_ECO_FOTO")

	func interact(player: Node) -> bool:
		if owner_node != null and is_instance_valid(owner_node):
			owner_node.look()
		interacted.emit(player)
		return true


## [E]: la foto de cerca (4 s) y lo que piensa tu agente.
func look() -> void:
	if not _active() or get_tree().root.get_node_or_null("EcoFoto") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "EcoFoto"
	layer.layer = 12
	get_tree().root.add_child(layer)
	var card := card_ui(load_photo(GameState.agent), GameState.agent, record())
	card.modulate.a = 0.0
	layer.add_child(card)
	var tw := layer.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	think(str(PHOTO_ECHO[photo_variant(GameState.agent) - 1]), true)  # el martes y el miércoles nota quién falta


## La polaroid en pantalla: la foto (o el hueco desteñido), «Promoción · fecha» y cómo saliste.
static func card_ui(tex: Texture2D, agent: String, rec: Dictionary) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.87, 0.8)
	sb.set_content_margin_all(16)
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(500, 440)
	card.position = Vector2(1920 * 0.5 - 250, 1080 * 0.5 - 260)
	card.pivot_offset = Vector2(250, 220)
	card.rotation_degrees = 2.5
	root.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(468, 300)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.modulate = Color(0.8, 0.76, 0.68)
	if tex != null:
		pic.texture = tex
	else:
		var g := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(0.78, 0.72, 0.6))
		gr.set_color(1, Color(0.6, 0.55, 0.47))
		g.gradient = gr
		g.fill_to = Vector2(1, 1)
		pic.texture = g
	vb.add_child(pic)
	var how := "ECO_FOTO_BORRADA" if tex == null else ("ECO_FOTO_SONRIE" if bool(rec.get("foto", true)) else "ECO_FOTO_SERIO")
	var txt := Loc.fmt(TranslationServer.translate("TUT_FOTO_CAPTION"), {"fecha": Flashback.date_text(agent)}).get_slice("\n", 0)
	var cap := UITheme.label("%s\n%s" % [txt, TranslationServer.translate(how)], 19, Color(0.2, 0.18, 0.3))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(cap)
	return root


func _on_seated(id: String) -> void:
	if id != SEAT or not _active() or bool(record().get("eco_foto", false)):
		return
	await get_tree().create_timer(2.5, false).timeout
	if is_inside_tree() and GameState.seated_at == SEAT:
		think("eco_foto")


func _on_bought(shop_id: String, item_id: String, _price: float) -> void:
	if shop_id == "expendedora" and item_id == "cafe" and _active() and not bool(record().get("eco_cafe", false)):
		think("eco_cafe")


## Lo piensa tu agente (subtítulo y voz, una vez por partida salvo `again`). Queda marcado solo si llegó a sonar.
func think(key: String, again: bool = false) -> void:
	if _busy.get(key, false) or (bool(record().get(key, false)) and not again):
		return
	var e := Flashback.echo(GameState.agent, key)
	if e.is_empty():
		return
	_busy[key] = true
	var line: Object = VoiceDirector.say("voces/agentes/" + str(e["voz"]), VoiceDirector.P.AMBIENTE, "piensa", Callable(),
		{"text": "(%s) %s" % [GameState.agent, str(e["texto"])], "bus": "UI", "max_wait": 8.0})
	if line != null and not bool(line.get("done")):
		await line.finished
	_busy[key] = false
	if _heard(line):
		mark(key)
	elif key == "eco_foto" and not again:
		_retry_photo()


## ¿La línea sonó lo bastante como para darla por dicha? Entera, o cortada después de la mitad (desde que el eco es
## relleno para el VoiceDirector, la primera llamada del turno lo corta: no vale haber oído dos palabras).
static func _heard(line: Object) -> bool:
	if line == null:
		return false
	var res := str(line.get("result"))
	if res == "dicha":
		return true
	var t0 := int(line.get("started_ms"))
	if res != "interrumpida" or t0 < 0:
		return false
	var total := maxf(float(int(line.get("wall_end_ms")) - t0), 1.0)
	return float(VoiceDirector.now_ms() - t0) / total >= HEARD_MIN


## El pensamiento de la foto no llegó a sonar (o lo cortaron al empezar): mientras sigas en tu mesa lo intenta de nuevo
## cuando hay silencio y no estás con un cliente, hasta RETRY_MAX veces por turno. Al volver a sentarte, también.
func _retry_photo() -> void:
	if _retries >= RETRY_MAX:
		return
	_retries += 1
	var turno := GameState.turno
	await get_tree().create_timer(RETRY_S, false).timeout
	while is_inside_tree() and _active() and GameState.turno == turno and GameState.seated_at == SEAT and (VoiceDirector.busy(1) or GameState.in_contact):
		await get_tree().create_timer(2.0, false).timeout
	if is_inside_tree() and _active() and GameState.turno == turno and GameState.seated_at == SEAT and not bool(record().get("eco_foto", false)):
		think("eco_foto")


# --- el comodín, el Trainer de hoy -------------------------------------------------------------------------

func _on_comodin(_who: String) -> void:
	if _active() and Comodin.practice_names.is_empty() and not bool(record().get("eco_comodin", false)):
		think("eco_comodin")


## El Trainer de hoy te suelta de la «Actualización de campaña» con la frase amable del recuerdo (una vez por partida).
func _on_training_ended(passed: bool) -> void:
	if not passed or not _active() or bool(record().get("eco_trainer", false)) or _busy.get("eco_trainer", false):
		return
	var e := Flashback.echo_raw("eco_trainer")
	if e.is_empty():
		return
	_busy["eco_trainer"] = true
	var line: Object = VoiceDirector.say("voces/trainer/" + str(e["voz"]), VoiceDirector.P.AMBIENTE, "trainer", Callable(),
		{"text": "[Trainer] %s" % str(e["texto"]), "bus": "Sala", "max_wait": 14.0})
	if line != null and not bool(line.get("done")):
		await line.finished
	_busy["eco_trainer"] = false
	if _heard(line):
		mark("eco_trainer")


# --- la letra chica -----------------------------------------------------------------------------------------

static func clause_for(cause: String) -> int:
	return int(CLAUSE_BY_DEATH.get(cause, 15))


static func clause_text(n: int) -> String:
	for c in ContractUI.data().get("clausulas", []):
		if int((c as Dictionary).get("n", 0)) == n:
			return Loc.pick(c)
	return ""


static func contract_number(agent: String) -> String:
	return "KP-%05d" % (abs(agent.hash()) % 100000)  # el mismo número que lleva el papel (ContractUI)


## El rótulo de la pantalla de desconexión: «Contrato KP-01234 · Cláusula 4. Disponibilidad. …».
static func clause_line(agent: String, cause: String) -> String:
	var c := SaveSlots.contract(agent)
	if not bool(c.get("firmado", false)):
		return ""
	var n := clause_for(cause)
	var key := "ECO_CLAUSULA" if bool(c.get("leido", false)) else "ECO_CLAUSULA_SIN_LEER"
	return Loc.fmt(TranslationServer.translate(key), {"num": contract_number(agent), "n": n, "texto": clause_text(n)})


func _on_death_shown(cause: String) -> void:
	if not _active():
		return
	var txt := clause_line(GameState.agent, cause)
	var ds := get_tree().root.find_child("DeathScreen", true, false) as Control
	if txt == "" or ds == null:
		return
	var old := ds.get_node_or_null("ClausulaContrato")
	if old != null:
		old.free()
	var l := _Clause.new()
	l.name = "ClausulaContrato"
	l.text = txt
	l.cause = cause
	l.lang = Loc.language
	ds.add_child(l)


## Rótulo chico al pie de la pantalla de desconexión; aparece cuando el motivo ya se leyó y se va solo con la pantalla.
class _Clause extends Label:
	var _t: float = 0.0
	var cause: String = ""
	var lang: String = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_theme_font_size_override("font_size", 15)
		add_theme_color_override("font_color", Color(0.66, 0.62, 0.52))
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		offset_left = 260.0
		offset_right = -260.0
		offset_top = -80.0  # un renglón de aire bajo el rótulo de la causa («¡AMONESTACIÓN DISCIPLINARIA!»)
		offset_bottom = -28.0
		modulate.a = 0.0

	func _process(delta: float) -> void:
		var p := get_parent() as Control
		if p == null or not p.visible:
			queue_free()
			return
		_t += delta
		modulate.a = clampf((_t - 2.4) / 1.2, 0.0, 0.85)
		if lang != Loc.language and cause != "":  # el idioma cambió con la desconexión en pantalla
			lang = Loc.language
			text = RecuerdosSemana.clause_line(GameState.agent, cause)


# --- tu contrato, clavado en el aula ------------------------------------------------------------------------

## El papel amarillento con tu firma, junto a la puerta del aula de training (piso 1), desde el martes.
func _build_contract(fl: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ContratoFirmado"
	root.position = CONTRACT_POS
	root.rotation_degrees = Vector3(0, 180.0, -2.0)  # mira al aula, apenas torcido
	fl.add_child(root)
	var paper := Greybox.box(root, "Papel", Vector3.ZERO, Vector3(0.21, 0.297, 0.003), Color(0.84, 0.79, 0.64), false)
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(root, "Chinche", Vector3(0, 0.135, 0.004), Vector3(0.014, 0.014, 0.006), Color(0.62, 0.1, 0.08), false)
	for i in 7:  # renglones
		Greybox.box(root, "Renglon%d" % i, Vector3(-0.01 + 0.004 * (i % 2), 0.09 - 0.022 * i, 0.002), Vector3(0.15 - 0.012 * (i % 3), 0.003, 0.001), Color(0.42, 0.4, 0.36), false)
	var sig := MeshInstance3D.new()
	sig.name = "Firma"
	var q := QuadMesh.new()
	q.size = Vector2(0.13, 0.05)
	sig.mesh = q
	sig.position = Vector3(0.02, -0.105, 0.0022)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = signature_texture(record().get("firma", []))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sig.material_override = mat
	sig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sig)
	var area := ContractPaper.new()
	area.name = "ContratoArea"
	area.size = Vector3(0.5, 0.6, 0.5)
	area.position = Vector3(0, 0, 0.2)
	area.owner_node = self
	root.add_child(area)
	return root


class ContractPaper extends Interactable:
	var owner_node: RecuerdosSemana = null

	func hint_text() -> String:
		return tr("HUD_ECO_CONTRATO")

	func interact(player: Node) -> bool:
		if owner_node != null and is_instance_valid(owner_node):
			owner_node.look_contract()
		interacted.emit(player)
		return true


## Los trazos de tu firma ([[x0, y0, x1, y1, …], …] de 0 a 1) como puntos de pantalla dentro de `box`.
static func signature_points(strokes: Variant, box: Rect2) -> Array:
	var out: Array = []
	if not (strokes is Array) or (strokes as Array).is_empty():
		var def := PackedVector2Array()  # partidas de antes: un garabato cualquiera
		for i in 24:
			def.append(box.position + Vector2(box.size.x * i / 23.0, box.size.y * (0.5 + 0.32 * sin(i * 0.9))))
		return [def]
	var max_y := 0.001
	for st in strokes:
		for i in range(1, (st as Array).size(), 2):
			max_y = maxf(max_y, float(st[i]))
	var k := minf(box.size.x, box.size.y / max_y)
	var off := box.position + Vector2((box.size.x - k) * 0.5, (box.size.y - k * max_y) * 0.5)
	for st in strokes:
		var pts := PackedVector2Array()
		for i in range(0, (st as Array).size() - 1, 2):
			pts.append(off + Vector2(float(st[i]), float(st[i + 1])) * k)
		if pts.size() >= 2:
			out.append(pts)
	return out


## La firma como textura (tinta azul sobre transparente) para el papel de la pared.
static func signature_texture(strokes: Variant) -> ImageTexture:
	var w := 260
	var h := 100
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.14, 0.4, 0.0))
	var ink := Color(0.1, 0.14, 0.4, 0.95)
	for pts in signature_points(strokes, Rect2(8, 8, w - 16, h - 16)):
		for i in range(1, (pts as PackedVector2Array).size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var n := int(maxf(1.0, a.distance_to(b)))
			for s in n + 1:
				var p := a.lerp(b, float(s) / float(n))
				for dx in 2:
					for dy in 2:
						var x := int(p.x) + dx
						var y := int(p.y) + dy
						if x >= 0 and y >= 0 and x < w and y < h:
							img.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(img)


## [E]: tu contrato de cerca (5 s): la letra chica, tu firma, y lo que piensa tu agente.
func look_contract() -> void:
	if not _active() or get_tree().root.get_node_or_null("EcoContrato") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "EcoContrato"
	layer.layer = 12
	get_tree().root.add_child(layer)
	var card := contract_card(GameState.agent, record())
	card.modulate.a = 0.0
	layer.add_child(card)
	var tw := layer.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	think("eco_firma", true)


static func contract_card(agent: String, rec: Dictionary) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.81, 0.66)
	sb.set_content_margin_all(30)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(620, 560)
	card.position = Vector2(1920 * 0.5 - 310, 1080 * 0.5 - 300)
	card.pivot_offset = Vector2(310, 280)
	card.rotation_degrees = -1.8
	root.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var ink := Color(0.16, 0.15, 0.14)
	var d := ContractUI.data()
	var title := UITheme.label(Loc.pick(d.get("titulo", {})), 19, ink)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)
	var num := UITheme.label("N.º %s · %s" % [contract_number(agent), Flashback.date_text(agent)], 13, Color(0.42, 0.39, 0.32))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(num)
	for n in [1, 4, 15]:  # las que más pesan hoy; la 15 es la letra chica
		var cl := UITheme.label("%s %d. %s" % [TranslationServer.translate("CONTRACT_CLAUSE"), n, clause_text(n)], 12 if n == 15 else 15, ink if n != 15 else Color(0.3, 0.28, 0.24))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(560, 0)
		vb.add_child(cl)
	var pad := _Signature.new()
	pad.strokes = rec.get("firma", [])
	pad.custom_minimum_size = Vector2(560, 130)
	vb.add_child(pad)
	var who := UITheme.label("%s · %s" % [Loc.pick(d.get("firma", {})), agent.to_upper()], 13, Color(0.42, 0.39, 0.32))
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(who)
	return root


class _Signature extends Control:
	var strokes: Variant = []

	func _draw() -> void:
		draw_line(Vector2(60, size.y - 14), Vector2(size.x - 60, size.y - 14), Color(0.25, 0.24, 0.22), 1.5)
		for pts in RecuerdosSemana.signature_points(strokes, Rect2(120, 10, size.x - 240, size.y - 34)):
			draw_polyline(pts, Color(0.1, 0.14, 0.4), 2.2, true)


extends Node
## SteamManager (v0.4.1): Integración segura con GodotSteam (Steamworks SDK) + Steam Cloud Saves.
## Funciona 100 % sin errores en builds locales/web sin DLLs de Steam y se activa automáticamente
## al detectar el singleton `Steam` de GodotSteam en producción.

signal achievement_unlocked(id: String, title: String)

const APP_ID := 0  # Reemplazar con tu App ID de Steam Direct antes de publicar
const ACHIEVEMENTS: Dictionary = {
	"TRAINING_COMPLETE": {"es": "Bienvenido a la Familia", "en": "Welcome to the Family"},
	"SURVIVE_MON": {"es": "Primera Amanecida (Lunes)", "en": "First Graveyard Shift (Monday)"},
	"SURVIVE_TUE": {"es": "Actualización 3.2 (Martes)", "en": "Campaign Update 3.2 (Tuesday)"},
	"SURVIVE_WED": {"es": "En la Lista (Miércoles)", "en": "On the List (Wednesday)"},
	"SURVIVE_THU": {"es": "Puesto Ocupado (Jueves)", "en": "Occupied Seat (Thursday)"},
	"EVICT_PAPAYALA": {"es": "Este es Mi Sitio (C-14)", "en": "This Is My Seat (C-14)"},
	"SURVIVE_FRI": {"es": "Bajo el Coloso (Viernes)", "en": "Beneath the Colossus (Friday)"},
	"OM_DECISION": {"es": "La Oferta del OM", "en": "The OM's Offer"},
	"SURVIVE_SAT": {"es": "Cláusula 15 Rota (Sábado)", "en": "Clause 15 Broken (Saturday)"},
	"FACE_GRASA": {"es": "¡HAIL GRASAAAA!", "en": "HAIL GRASAAAA!"},
	"USE_COMODIN": {"es": "Cobertura de Compañero [C]", "en": "Teammate Cover [C]"},
	"READ_CONTRACT": {"es": "Letra Chica (15 Cláusulas)", "en": "Fine Print (15 Clauses)"},
	"ENDING_RENUNCIAR": {"es": "Final 1 · Renunciar", "en": "Ending 1 · Resign"},
	"ENDING_DESPEDIDO": {"es": "Final 2 · Despedido", "en": "Ending 2 · Fired"},
	"ENDING_SHERO": {"es": "Final 3 · Volverse Shero", "en": "Ending 3 · Become Shero"},
	"ENDING_ALMA": {"es": "Final 4 · Alma en el Software", "en": "Ending 4 · Soul in the Software"},
	"ENDING_SECRETO": {"es": "Final 5 · El Fotocheck (Secreto)", "en": "Ending 5 · The Badge (Secret)"},
	"ALL_ENDINGS": {"es": "Expediente Completo (5/5 Finales)", "en": "Complete Dossier (5/5 Endings)"}
}

var steam_active: bool = false
var unlocked_local: Array[String] = []
var _toast_layer: CanvasLayer = null
var _toast_lbl: Label = null
var _toast_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local()
	_init_steam()
	_build_toast()
	EventBus.shift_ended.connect(_on_shift_ended)
	if has_node("/root/Comodin"):
		get_node("/root/Comodin").connect("call_answered", func(_w: String, _a: int) -> void: unlock("USE_COMODIN"))


func _init_steam() -> void:
	if Engine.has_singleton("Steam"):
		var st: Object = Engine.get_singleton("Steam")
		if st != null and st.has_method("steamInit"):
			var res: Variant = st.call("steamInit", false)
			if res is Dictionary and int((res as Dictionary).get("status", 0)) == 1:
				steam_active = true
			elif res is bool and bool(res):
				steam_active = true


func _process(delta: float) -> void:
	if steam_active and Engine.has_singleton("Steam"):
		var st: Object = Engine.get_singleton("Steam")
		if st != null and st.has_method("run_callbacks"):
			st.call("run_callbacks")
	if _toast_t > 0.0 and _toast_layer != null:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_layer.visible = false


func unlock(ach_id: String) -> void:
	if ach_id == "" or not ACHIEVEMENTS.has(ach_id):
		return
	var first_time := not unlocked_local.has(ach_id)
	if first_time:
		unlocked_local.append(ach_id)
		_save_local()
		var title := Loc.pick(ACHIEVEMENTS[ach_id])
		achievement_unlocked.emit(ach_id, title)
		_show_toast(title)
	if steam_active and Engine.has_singleton("Steam"):
		var st: Object = Engine.get_singleton("Steam")
		if st != null:
			if st.has_method("setAchievement"):
				st.call("setAchievement", ach_id)
			if st.has_method("storeStats"):
				st.call("storeStats")


func sync_cloud_save() -> void:
	if not steam_active or not Engine.has_singleton("Steam"):
		return
	var st: Object = Engine.get_singleton("Steam")
	if st == null or not st.has_method("fileWrite"):
		return
	var p := SaveSlots.main_progress_path("Jiroshi")
	if FileAccess.file_exists(p):
		var bytes := FileAccess.get_file_as_bytes(p)
		if not bytes.is_empty():
			st.call("fileWrite", "jiroshi_progreso.json", bytes)


func _on_shift_ended() -> void:
	var fired := Metrics.written_warnings >= 3
	if not fired:
		match GameState.turno:
			0: unlock("TRAINING_COMPLETE")
			1: unlock("SURVIVE_MON")
			2: unlock("SURVIVE_TUE")
			3: unlock("SURVIVE_WED")
			4: unlock("SURVIVE_THU")
			5: unlock("SURVIVE_FRI")
			6: unlock("SURVIVE_SAT")
	if bool(SaveSlots.progress("Jiroshi").get("contrato_leido", false)):
		unlock("READ_CONTRACT")
	if fired or GameState.turno >= 7:
		var eid := EndingsManager.evaluate(fired)
		match eid:
			"renunciar": unlock("ENDING_RENUNCIAR")
			"despedido": unlock("ENDING_DESPEDIDO")
			"volverse_shero": unlock("ENDING_SHERO")
			"alma_en_software": unlock("ENDING_ALMA")
			"secreto": unlock("ENDING_SECRETO")
		var unlocked_ends: Array = SaveSlots.progress("Jiroshi").get("finales", [])
		if unlocked_ends.size() >= 5:
			unlock("ALL_ENDINGS")
	sync_cloud_save()


func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "SteamToastLayer"
	_toast_layer.layer = 115
	_toast_layer.visible = false
	add_child(_toast_layer)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -390
	box.offset_right = -20
	box.offset_top = -96
	box.offset_bottom = -20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.12, 0.94)
	sb.border_color = Color(0.22, 0.72, 0.78)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", sb)
	_toast_layer.add_child(box)
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_font_size_override("font_size", 15)
	_toast_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98))
	box.add_child(_toast_lbl)


func _show_toast(title: String) -> void:
	if _toast_lbl == null or _toast_layer == null:
		return
	var prefix := "LOGRO DESBLOQUEADO" if Loc.lang != "en" else "ACHIEVEMENT UNLOCKED"
	_toast_lbl.text = "★ %s\n%s" % [prefix, title]
	_toast_layer.visible = true
	_toast_t = 4.5


func _save_local() -> void:
	var f := FileAccess.open("user://achievements.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(unlocked_local))


func _load_local() -> void:
	if not FileAccess.file_exists("user://achievements.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://achievements.json"))
	if parsed is Array:
		unlocked_local.clear()
		for item in parsed:
			unlocked_local.append(str(item))

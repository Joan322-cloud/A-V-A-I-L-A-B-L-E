class_name Vitzo
extends Node
## Vitzo: cuenta WORKFLOW de Ezlaki (GDD 6.1, PLAN §6.3). Es una cuenta regresiva, no percibe nada.
## - Recordatorio en #site-updates a las horas de balance.json/vitzo (03:00 y 06:00): reaccionar con el emoji
##   pedido (clic en la reacción o [Enter] en Ezlaki, en la PC o en un terminal) en reaccionar_s reales; si no,
##   muerte `vitzo_reminder`. Si la disciplina está congelada (feedback, training, coaching) se aplaza.
## - Cualquier correo enviado a Vitzo (ContactManager.email_detected): `correo_vitzo` en un caso de BO;
##   en un WMM (árbol) la causa del árbol (`wmm_correo_vitzo` / `wmm_pod_correo`). Screamer: sale del monitor.
## v0.3.1 Q2 (F11): la muerte de Vitzo es VitzoScreamer.attack(causa): sale arrastrándose del monitor; si sigues
## sentado te agarra y grita; si te paras, te persigue corriendo (muerte segura, en exclusiva) hasta saltarte.

var _reminder_pending: bool = false
var _reminder_left: float = 0.0
var _emoji_index: int = 0
var _hours_done: Array[int] = []
var _postponed: Array[int] = []
var emoji: String = "✅"


func _ready() -> void:
	add_to_group("vitzo")
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.vitzo_reacted.connect(_on_reacted)
	EventBus.shift_started.connect(func() -> void: _hours_done.clear(); _postponed.clear(); _reminder_pending = false)
	EventBus.respawned.connect(func(_k: String) -> void: _reminder_pending = false)
	EventBus.freeze_discipline.connect(_on_freeze)


func _process(delta: float) -> void:
	if not _postponed.is_empty() and not _reminder_pending and GameState.logged_in and not Discipline.is_frozen() and not _shielded():
		_postponed.clear()
		post_reminder()  # v0.3.2: lo aplazado por el lunch sale después de la gracia
	if not _reminder_pending or get_tree().paused or not GameState.running:
		return
	if Discipline.is_lunch_immune():
		return  # v0.3.2: un recordatorio que te agarró al poner Lunch espera (sigue al volver, con lo que le quedaba)
	_reminder_left -= delta
	if _reminder_left <= 0.0:
		_reminder_pending = false
		if GameState.is_tutorial():  # P6b: en la Inducción se explica y no grita (el tutorial lo vuelve a publicar)
			EventBus.show_message.emit(tr("TUT_VITZO_MISSED"), 4.0)
			return
		_scream()
		VitzoScreamer.attack("vitzo_reminder")


## v0.3.2: ni en el lunch (aplazado) ni al reaparecer («Reconectando» y la gracia de 60 s) empieza un recordatorio.
func _shielded() -> bool:
	return Discipline.is_lunch_immune("vitzo") or Metrics.reconnecting or Checkpoints.in_respawn_grace()


func _on_hour_changed(hour: int) -> void:
	if not GameState.logged_in:
		return
	var hours: Array = DataLoader.bal("vitzo/horas_recordatorio", [3, 6])
	for h in hours:
		if int(h) == hour and not _hours_done.has(hour):
			_hours_done.append(hour)
			if Discipline.is_frozen() or _shielded():
				_postponed.append(hour)  # se publica cuando termine el feedback / training / coaching
			else:
				post_reminder()


func _on_freeze(on: bool, _reason: String) -> void:
	if not on and not _postponed.is_empty() and not Discipline.is_frozen() and not _shielded():
		_postponed.clear()
		post_reminder()


## Publica el recordatorio ahora (también lo usan las pruebas y las capturas).
func post_reminder() -> void:
	var data: Dictionary = DataLoader.dict("lineas_vitzo")
	var emojis: Array = data.get("emojis_reaccion", ["✅"])
	emoji = str(emojis[_emoji_index % emojis.size()])
	var lines: Array = data.get("recordatorio", {}).get("lineas", [])
	var txt := Loc.pick(lines[_emoji_index % lines.size()]) if not lines.is_empty() else "Reminder"
	_emoji_index += 1
	_reminder_left = float(DataLoader.bal("vitzo/reaccionar_s", 45.0)) * Difficulty.scale("vitzo_reaccion")
	if not Discipline.at_pc():
		# v0.3.2: sin terminales de pared, lejos de una PC hay que llegar a una (como el Ack lejos: 60 / 90 s).
		_reminder_left = maxf(_reminder_left, Discipline.ack_window_seconds(0.0))
	_reminder_pending = true
	AudioManager.play_sfx("ezlak_notificacion", "UI")
	EventBus.ezlak_post.emit("#site-updates", "vitzo", txt, {"tipo": "vitzo_reminder", "reaccion": emoji, "react_s": _reminder_left, "mention": true})
	EventBus.vitzo_reminder.emit("%s  ·  %s" % [txt, emoji], _reminder_left)


func _on_reacted() -> void:
	if _reminder_pending:
		_reminder_pending = false
		AudioManager.play_sfx("ack_click", "UI")
		var ok: Dictionary = DataLoader.dict("lineas_vitzo").get("reaccion_ok", {})
		if not ok.is_empty():
			EventBus.ezlak_post.emit("#site-updates", "vitzo", Loc.pick(ok), {"tipo": "vitzo_ok"})


## Se envió un correo a Vitzo. wmm = desde una llamada/chat (árbol).
func email_detected(cause: String, wmm: bool) -> void:
	var data: Dictionary = DataLoader.dict("lineas_vitzo")
	var key := "wmm_detectado" if wmm else "correo_detectado"
	var lines: Array = data.get(key, {}).get("lineas", [])
	if not lines.is_empty():
		EventBus.ezlak_post.emit("#site-updates", "vitzo", Loc.pick(lines[randi() % lines.size()]), {"tipo": "vitzo_detectado", "causa": cause})
	_scream(wmm)
	VitzoScreamer.attack(cause)


func _scream(wmm: bool = false) -> void:
	var data: Dictionary = DataLoader.dict("lineas_vitzo")
	var lines: Array = data.get("screamer_wmm" if wmm else "screamer", {}).get("lineas", [])
	if lines.is_empty():
		lines = data.get("screamer", {}).get("lineas", [])
	var txt := Loc.pick(lines[0]) if not lines.is_empty() else "!"
	EventBus.subtitle.emit("vitzo", txt, 2.0)
	GameState.flags["vitzo_wallpaper"] = true  # deja su cara de fondo de pantalla


func is_reminder_pending() -> bool:
	return _reminder_pending


func seconds_left() -> float:
	return _reminder_left

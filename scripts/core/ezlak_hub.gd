class_name EzlakHub
extends Node
## Ezlaki (PLAN §6.4, §2 #41-45): canales, DMs, no leídos, menciones, reacciones, respuestas rápidas, Rooms y
## los mensajes programados del turno. Es el "servidor" de Ezlaki; la app (scripts/ui/pc/ezlak.gd) lo dibuja.
## Vive dentro de la Workstation (siempre existe) y se busca con EzlakHub.get_hub(tree) (grupo "ezlak_hub").
##
## API para P3/P5/P6 (sin referencias directas):
##   EventBus.ezlak_post.emit(canal, autor, texto, meta)
##     canal: "#allocations" | "#site-updates" | "#team-familia" | "dm:shero" | "dm:trainer" | "dm:haime" |
##            "dm:rasec" | "dm:enfermera" | "dm:<agente>"  (también "allocations", "site-updates", "team-familia")
##     autor: slug de ezlak_canales.json/autores ("shero", "rta", "mentor", "vitzo", "om", "rasec", "haime",
##            "trainer", "enfermera", "jiroshi"…, "yo" = el jugador, "sistema")
##     meta (todo opcional): tipo (texto libre: "llamado", "verbal", "ww", "allocations", "rooms", …) ·
##       mention: bool (resalta y suena mención) · typing_s: s reales de "escribiendo…" antes de publicar ·
##       edita: texto nuevo + edita_s: s reales → el mensaje se edita ("(editado)") ·
##       borra_s: s reales → "Este mensaje fue eliminado." · quick_replies: [ids] (botones en el DM) ·
##       reaccion: emoji (botón de reacción; Vitzo) · rooms: segundos (invitación a Ezlaki Rooms con botón Unirse) ·
##       ack: true (botón Ack del WW) · silent: true (sin sonido) · _ya_publicado (uso interno).
##   EventBus.ezlak_quick_reply(canal, id_respuesta)  ← lo emite la app cuando el jugador responde
##     ids: ack · ok · me_siento_mal (→ EventBus.topico_requested) · en_un_caso · jaja · no_me_metas · gracias ·
##          voy · no_gracias · excusa_1..3 · join_rooms
##   EzlakHub.typing(canal, autor, segundos)  — indicador "escribiendo…" sin mensaje (o usar meta.typing_s)
##   EzlakHub.typed_reply(canal, texto)  — v0.3.1 Q3 (B6): el jugador ESCRIBE su respuesta; se clasifica por palabras
##     clave en una intención (classify_intent: insulto, ayuda, ack, voy, excusa, negar, pregunta, gracias, broma,
##     saludo, queja, ok, otro) y el personaje del canal contesta en personaje (data/ezlaki_q3.json/respuestas). Si la
##     intención equivale a una respuesta rápida (ack, voy, ok, me_siento_mal, no_gracias, jaja, gracias) hace lo mismo
##     que el botón (emite ezlak_quick_reply). A Shero le caen mal las excusas; insultarlo cuenta como falta
##     (Metrics.report_miss: alerta y luego WW). Nunca rompe el juego: texto vacío, spam o canales de solo lectura
##     tienen respuesta propia.
## v0.3.1 Q3: variantes de cada línea sin repetir en el turno (ezlaki_q3.json/variantes), el doble de publicaciones
## programadas, charla extra por DM (dm_extra), limitador de 1 mensaje cada 20 s por canal y autor para lo que se
## repite (B9/F7; WW, Ack, Rooms, disciplina y lo programado no se limitan: lo limitado espera, no se pierde salvo si es
## un duplicado), «capturas» de la vista de adherencia en #allocations (EzlakiCaptura) y reacciones de los compañeros.
## Adaptadores v0.2 (para no romper a nadie): shero_message(texto, "dm"|"canal") → dm:shero / #team-familia
## ("[Mentor] …" → Mentor), rta_tag → #allocations, written_warning_issued → DM de Shero con Ack,
## coaching_requested → invitación a Rooms en el DM de Shero.

signal posted(channel: String, msg: Dictionary)
signal updated(channel: String)
signal typing_changed(channel: String, author: String, on: bool)
signal reaction_alone(msg: Dictionary)  # v0.3.2 IA: en el aviso que pide reacción ya solo faltas tú

const FIXED: Array[String] = ["#allocations", "#site-updates", "#team-familia", "dm:shero"]

var channels: Dictionary = {}  # id -> {id, mensajes: [], unread: int, mention: bool, titulo}
var order: Array[String] = []
var typing_now: Dictionary = {}  # canal -> autor
var rooms_pending: bool = false
var rooms_left: float = 0.0
var rooms_from: String = "shero"
var excuse_pending: bool = false
var _next_id: int = 1
var _sched_next: int = 0
var _dm_lines: Array = []  # [{t, canal, autor, msg}] DMs de compañeros del turno, ordenados
var _dm_next: int = 0
var _ghosts: Array[float] = []
var _ghost_next: int = 0
var _degrade_done: Array[String] = []
var _rng := RandomNumberGenerator.new()
## v0.3.1 Q3
const LIMIT_S := 55.0
const LIMITED_TIPOS: Array[String] = ["v02", "alerta", "ambiente", "tag", "dm_companero", "lamebotas", "fin_allocation"]
var _used: Dictionary = {}  # clave de línea -> [índices ya usados en el turno]
var _last_post: Dictionary = {}  # "canal|autor" -> ms del último mensaje publicado (limitador)
var _queued: Dictionary = {}  # "canal|autor" -> [canal, autor, texto, meta] esperando (uno por clave)
var limited_count: int = 0  # pruebas: mensajes retenidos o descartados por el limitador
var _typed_ms: Array = []  # ms de los últimos mensajes escritos por el jugador
var last_intent: String = ""  # pruebas
var last_typed_reply: Dictionary = {}  # pruebas: {canal, intencion, autor, texto}
var last_nlu: Dictionary = {}  # v0.3.2 IA (pruebas): análisis IANlu del último texto escrito
var last_brain: Dictionary = {}  # v0.3.2 IA (pruebas): última respuesta de IABrain
var captura: EzlakiCaptura = null
var _extra_dm: Array = []  # [{t, canal, autor, msg}] charla extra de los compañeros (dm_extra)
var _extra_next: int = 0
var _insults: int = 0


static func get_hub(tree: SceneTree) -> EzlakHub:
	return tree.get_first_node_in_group("ezlak_hub") as EzlakHub


func _init() -> void:
	captura = EzlakiCaptura.new()
	captura.name = "Capturas"
	add_child(captura)


func _ready() -> void:
	add_to_group("ezlak_hub")
	EventBus.ezlak_post.connect(_on_post)
	EventBus.shero_message.connect(_on_shero_message)
	EventBus.rta_tag.connect(func(t: String) -> void: EventBus.ezlak_post.emit("#allocations", "rta", t, {"tipo": "tag", "mention": t.contains(GameState.agent)}))
	EventBus.written_warning_issued.connect(_on_ww)
	EventBus.ack_given.connect(func() -> void: _close_ack())
	EventBus.coaching_requested.connect(_on_coaching_requested)
	EventBus.coaching_joined.connect(func() -> void: rooms_pending = false; updated.emit("dm:" + rooms_from))
	EventBus.email_over_time.connect(_on_email_over_time)
	EventBus.clock_tick.connect(_on_clock)
	EventBus.shift_started.connect(reset)
	EventBus.returned_to_menu.connect(reset)
	EventBus.respawned.connect(func(_k: String) -> void: _rewind())
	reset()


func _cfg() -> Dictionary:
	return DataLoader.dict("ezlak_canales")


func reset() -> void:
	_rng.seed = 77 + GameState.turno
	channels.clear()
	order.clear()
	typing_now.clear()
	rooms_pending = false
	excuse_pending = false
	reaction_pending = {}
	_epoch += 1
	_degrade_done.clear()
	_used.clear()
	_last_post.clear()
	_queued.clear()
	_typed_ms.clear()
	_insults = 0
	for id in FIXED:
		_ensure(id)
	for a in agent_dms(GameState.agent):
		_ensure("dm:" + a)
	_build_dm_schedule()
	_build_extra_dms()
	var gh: Dictionary = _cfg().get("typing_fantasma", {})
	_ghosts.clear()
	for h in gh.get(str(GameState.turno), []):
		_ghosts.append(GameState.hhmm_to_seconds(str(h)))
	_resync()
	updated.emit("")


## v0.3.2-core · Al reaparecer el chat vuelve a la hora del checkpoint, como el resto del turno. Antes el historial
## se quedaba con los mensajes «del futuro» (los publicados entre el checkpoint y la muerte) y, al volver a pasar
## el reloj por su hora, lo programado salía OTRA VEZ: el mismo aviso dos veces en el canal, el WW de Shero todavía
## en su DM aunque el contador de WW había vuelto atrás, y un aviso de coaching que pedía reacción seguía con su
## cuenta atrás corriendo (y su «¿No viste el mensaje?» + alerta) por un mensaje que en el turno rebobinado todavía
## no existe. Ahora: se quitan los mensajes emitidos después de la hora del checkpoint (cada mensaje guarda `t`),
## lo que alguien estaba escribiendo no llega, y la reacción pendiente se cancela si su aviso se fue.
var _rewinds: int = 0


func _rewind() -> void:
	_rewinds += 1
	rooms_pending = false
	excuse_pending = false
	for ch in typing_now.keys():
		typing_changed.emit(str(ch), str(typing_now[ch]), false)
	typing_now.clear()
	var now := GameState.clock_seconds
	var pend := int(reaction_pending.get("id", -1))
	var pend_alive := reaction_pending.is_empty()
	for id in channels.keys():
		var c: Dictionary = channels[id]
		var all: Array = c["mensajes"]
		var keep: Array = []
		var cut_others := 0
		for m in all:
			if float((m as Dictionary).get("t", -1.0)) > now:
				if str((m as Dictionary).get("autor", "")) != "yo":
					cut_others += 1
			else:
				keep.append(m)
				if int((m as Dictionary).get("id", -2)) == pend:
					pend_alive = true
		if keep.size() != all.size():
			c["mensajes"] = keep
			c["unread"] = clampi(int(c["unread"]) - cut_others, 0, keep.size())
			if int(c["unread"]) == 0:
				c["mention"] = false
	if not pend_alive:
		reaction_pending = {}
		_react_running = false
		_react_alone_id = -1
	_resync()
	updated.emit("")


## Tras un respawn el reloj vuelve atrás: los mensajes programados ya publicados no se repiten.
func _resync() -> void:
	var now := GameState.clock_seconds
	var prog: Array = _cfg().get("programados", [])
	_sched_next = 0
	while _sched_next < prog.size() and GameState.hhmm_to_seconds(str((prog[_sched_next] as Dictionary).get("hora", "00:00"))) <= now and GameState.logged_in:
		_sched_next += 1
	_dm_next = 0
	while _dm_next < _dm_lines.size() and float(_dm_lines[_dm_next]["t"]) <= now and GameState.logged_in:
		_dm_next += 1
	_ghost_next = 0
	while _ghost_next < _ghosts.size() and _ghosts[_ghost_next] <= now and GameState.logged_in:
		_ghost_next += 1
	_extra_next = 0
	while _extra_next < _extra_dm.size() and float(_extra_dm[_extra_next]["t"]) <= now and GameState.logged_in:
		_extra_next += 1
	_queued.clear()


## DMs de compañero del agente (ezlak_canales.json/dms_por_agente).
func agent_dms(agent: String) -> Array:
	return (_cfg().get("dms_por_agente", {}) as Dictionary).get(agent, [])


func _ensure(id: String) -> Dictionary:
	if not channels.has(id):
		channels[id] = {"id": id, "mensajes": [], "unread": 0, "mention": false}
		order.append(id)
	return channels[id]


static func normalize(channel: String) -> String:
	var c := channel.strip_edges()
	match c:
		"allocations", "site-updates", "team-familia":
			return "#" + c
		"dm", "shero":
			return "dm:shero"
		"canal":
			return "#team-familia"
	return c


func author_info(slug: String) -> Dictionary:
	if slug == "yo":
		return {"nombre": GameState.agent, "avatar": Faces.agent_slug(GameState.agent).replace("_silueta", ""), "color": "#ffffff"}
	return (_cfg().get("autores", {}) as Dictionary).get(slug, {"nombre": slug.capitalize(), "avatar": slug, "color": "#cccccc"})


func channel_title(id: String) -> String:
	if id.begins_with("dm:"):
		return "@" + str(author_info(id.substr(3)).get("nombre", id.substr(3)))
	return id


## Total de no leídos (para el icono de Ezlaki y la barra de tareas).
func unread_total() -> int:
	var n := 0
	for c in channels.values():
		n += int(c.get("unread", 0))
	return n


func mark_read(id: String) -> void:
	if channels.has(id):
		channels[id]["unread"] = 0
		channels[id]["mention"] = false
		updated.emit(id)


func messages(id: String) -> Array:
	return (channels.get(id, {}) as Dictionary).get("mensajes", [])


## Último mensaje con reacción pendiente (Vitzo) o con Rooms / Ack pendiente, para [Enter] en la PC.
func pending_actionable() -> Dictionary:
	for id in ["#site-updates"]:
		var ms := messages(id)
		for i in range(ms.size() - 1, -1, -1):
			var m: Dictionary = ms[i]
			if str(m.get("reaccion", "")) != "" and not bool(m.get("reaccionado", false)) and bool(m.get("reaccion_viva", false)):
				return m
	return {}


func _on_post(channel: String, author: String, text: String, meta: Dictionary) -> void:
	var ch := normalize(channel)
	if bool(meta.get("_ya_publicado", false)):
		return
	if _limit(ch, author, text, meta):
		return
	var typing_s := float(meta.get("typing_s", 0.0))
	var t0 := GameState.clock_seconds  # la hora en que se emitió (lo que tarda en «escribir» no cuenta)
	if typing_s > 0.0 and is_inside_tree():
		var epoch := _epoch
		var rw := _rewinds
		typing(ch, author, typing_s)
		await get_tree().create_timer(typing_s).timeout
		if not is_inside_tree() or epoch != _epoch or (rw != _rewinds and t0 > GameState.clock_seconds):
			return  # cambió el turno, o reapareciste antes de la hora de este mensaje: ya no existe
	_publish(ch, author, text, meta, t0)


func _publish(ch: String, author: String, text: String, meta: Dictionary, at: float = -1.0) -> Dictionary:
	if author == "companero":
		author = _random_coworker()
	var c := _ensure(ch)
	var m := {
		"id": _next_id, "canal": ch, "autor": author, "texto": text, "hora": GameState.clock_text(),
		"t": at if at >= 0.0 else GameState.clock_seconds,  # reloj de juego en que se emitió (ver _rewind)
		"meta": meta, "tipo": str(meta.get("tipo", "")), "editado": false, "borrado": false,
		"reaccion": str(meta.get("reaccion", "")), "reaccionado": false, "reaccion_viva": str(meta.get("reaccion", "")) != "",
		"mention": bool(meta.get("mention", false)) or text.contains("@" + GameState.agent) or text.contains("@here"),
		"quick_replies": meta.get("quick_replies", []), "respondido": false,
		"ack": bool(meta.get("ack", false)), "rooms": meta.has("rooms"),
	}
	_next_id += 1
	if str(meta.get("tipo", "")) in LIMITED_TIPOS:  # solo lo «repetible» abre la ventana del limitador
		_last_post["%s|%s" % [ch, author]] = Time.get_ticks_msec()
	if author != "yo":
		_attach_capture(ch, author, m, meta)
	(c["mensajes"] as Array).append(m)
	if (c["mensajes"] as Array).size() > 120:
		(c["mensajes"] as Array).pop_front()
	if author != "yo":
		c["unread"] = int(c["unread"]) + 1
		if m["mention"] or ch.begins_with("dm:"):
			c["mention"] = true
	if typing_now.get(ch, "") == author:
		typing_now.erase(ch)
		typing_changed.emit(ch, author, false)
	if not bool(meta.get("silent", false)) and author != "yo":
		AudioManager.play_sfx("ezlak_mencion" if (m["mention"] or ch.begins_with("dm:")) else "ezlak_notificacion", "UI")
	# Subtítulo solo para lo que te toca (DM o mención) y si no estás mirando la PC.
	if author != "yo" and (m["mention"] or ch.begins_with("dm:")) and not bool(GameState.flags.get("pc_zoom", false)):
		EventBus.subtitle.emit("ezlak", "%s · %s: %s" % [channel_title(ch), str(author_info(author).get("nombre", author)), PcStyle.clean(text)], 4.0)
	if meta.has("edita") and float(meta.get("edita_s", 0.0)) > 0.0:
		_edit_later(m, str(meta.get("edita")), float(meta.get("edita_s")))
	if float(meta.get("borra_s", 0.0)) > 0.0:
		_delete_later(m, float(meta.get("borra_s")))
	if meta.has("react_s"):
		_expire_reaction(m, float(meta.get("react_s")))
	if bool(meta.get("pide_reaccion", false)):
		request_reaction(m)
	if bool(meta.get("pide_reaccion", false)):
		pass  # el aviso que pide reacción lleva su propia pared de emojis (no las caras de Q3)
	elif m.has("captura") or bool(meta.get("reacciones", false)) or (ch.begins_with("#") and author in ["shero", "rta", "om", "rasec", "mentor"] and _rng.randf() < 0.35):
		_react_later(m)
	posted.emit(ch, m)
	updated.emit(ch)
	return m


func _random_coworker() -> String:
	var pool: Array[String] = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			pool.append(a.to_lower())
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _edit_later(m: Dictionary, new_text: String, s: float) -> void:
	await get_tree().create_timer(s).timeout
	if not is_inside_tree():
		return
	m["texto"] = new_text
	m["editado"] = true
	AudioManager.play_sfx("ezlak_notificacion", "UI")
	updated.emit(str(m.get("canal", "")))


func _delete_later(m: Dictionary, s: float) -> void:
	await get_tree().create_timer(s).timeout
	if not is_inside_tree():
		return
	m["borrado"] = true
	m["quick_replies"] = []
	updated.emit(str(m.get("canal", "")))


func _expire_reaction(m: Dictionary, s: float) -> void:
	await get_tree().create_timer(s + 0.5).timeout
	if is_inside_tree():
		m["reaccion_viva"] = false
		updated.emit(str(m.get("canal", "")))


## "Fulano está escribiendo…" durante `seconds` reales (sin mensaje si nadie publica después).
func typing(channel: String, author: String, seconds: float) -> void:
	var ch := normalize(channel)
	typing_now[ch] = author
	typing_changed.emit(ch, author, true)
	updated.emit(ch)
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree() and typing_now.get(ch, "") == author:
		typing_now.erase(ch)
		typing_changed.emit(ch, author, false)
		updated.emit(ch)


# --- Acciones del jugador -------------------------------------------------------------------------

## Reacciona a un mensaje (clic o Enter). Si es el recordatorio de Vitzo, cuenta como reacción a tiempo.
func react(msg: Dictionary) -> bool:
	if msg.is_empty() or bool(msg.get("reaccionado", false)) or str(msg.get("reaccion", "")) == "":
		return false
	msg["reaccionado"] = true
	if str(msg.get("tipo", "")) == "vitzo_reminder" and bool(msg.get("reaccion_viva", false)):
		EventBus.vitzo_reacted.emit()
	updated.emit(str(msg.get("canal", "")))
	return true


## Respuesta rápida del jugador en un canal (botones del DM).
func quick_reply(channel: String, reply_id: String, msg: Dictionary = {}, typed_text: String = "") -> void:
	var ch := normalize(channel)
	var textos: Dictionary = _cfg().get("textos_respuesta", {})
	if msg.is_empty():
		msg = _pending_with(ch, reply_id)
	if not msg.is_empty():
		msg["respondido"] = true
		msg["quick_replies"] = []
	if reply_id == "join_rooms":
		if typed_text != "":
			_publish(ch, "yo", typed_text, {"tipo": "respuesta_escrita", "silent": true})
		join_rooms()
		return
	_publish(ch, "yo", typed_text if typed_text != "" else Loc.pick(textos.get(reply_id, {"es": reply_id, "en": reply_id})), {"tipo": "respuesta_escrita" if typed_text != "" else "respuesta", "silent": true})
	EventBus.ezlak_quick_reply.emit(ch, reply_id)
	match reply_id:
		"ack":
			if Metrics.ack_pending:
				Metrics.give_ack()
			_reply_later(ch, "shero", line_text("lineas_canales", "shero_ack_ok"), 1.5)
		"ok":
			if ch == "dm:shero":
				_reply_later(ch, "shero", line_text("lineas_canales", "shero_ok"), 2.0)
		"me_siento_mal":
			EventBus.topico_requested.emit()
		"en_un_caso":
			_reply_later(ch, "shero", line_text("lineas_canales", "en_un_caso"), 1.5)
		"excusa_1", "excusa_2", "excusa_3":
			_answer_excuse(int(reply_id.substr(7)) - 1)
		_:
			# v0.3.2 IA: si lo escribiste, contesta el cerebro (typed_reply); el botón sigue con su línea de siempre
			if typed_text == "" and ch.begins_with("dm:") and agent_dms(GameState.agent).has(ch.substr(3)):
				var who := ch.substr(3)
				var r: Dictionary = (DataLoader.dict("lineas_agentes").get("respuestas", {}) as Dictionary).get(who, {})
				if r.has(reply_id):
					_reply_later(ch, who, Loc.pick(r[reply_id]), _rng.randf_range(2.0, 5.0))
	updated.emit(ch)


func _reply_later(ch: String, author: String, text: String, s: float) -> void:
	if text == "":
		return
	var epoch := _epoch
	var rw := _rewinds
	typing(ch, author, s)
	await get_tree().create_timer(s).timeout
	if is_inside_tree() and epoch == _epoch and rw == _rewinds:  # tras reaparecer, la respuesta a algo que ya no está sobra
		_publish(ch, author, text, {"tipo": "respuesta_npc"})


func join_rooms() -> void:
	if not rooms_pending:
		return
	rooms_pending = false
	EventBus.coaching_joined.emit()
	updated.emit("dm:" + rooms_from)


func quick_replies_for(channel: String) -> Array:
	var qr: Dictionary = _cfg().get("respuestas_rapidas", {})
	if qr.has(channel):
		return qr[channel]
	if channel.begins_with("dm:") and agent_dms(GameState.agent).has(channel.substr(3)):
		return qr.get("agente", [])
	return []


# --- Adaptadores y reglas que viven en Ezlaki ------------------------------------------------------

func _on_shero_message(text: String, channel: String) -> void:
	if text == "__typing__":
		typing("dm:shero", "shero", 3.0)
		return
	if text in ["alerta", "de_pie_en_live", "convocar_coaching_evento", "ascensor_pisos", "topico_anotado"]:
		text = line_text("lineas_shero", "convocar_coaching" if text == "convocar_coaching_evento" else text)
		if text == "":
			return
	if _limit("dm:shero" if channel == "dm" else "#team-familia", "shero", text, {"tipo": "v02"}) and not text.begins_with("["):
		return  # B9/F7: mismo canal y autor dentro de 20 s → espera (o se descarta si es la misma línea)
	if text.begins_with("[Mentor] "):
		_publish("#team-familia", "mentor", text.substr(9), {"tipo": "v02"})
		return
	if text.begins_with("[Vitzo"):
		var i := text.find("] ")
		_publish("#site-updates", "vitzo", text.substr(i + 2) if i >= 0 else text, {"tipo": "v02"})
		return
	if text.begins_with("[") and text.contains("] "):
		var j := text.find("] ")
		var who := text.substr(1, j - 1).to_lower().split(" ")[0]
		_publish("#team-familia" if channel != "dm" else "dm:shero", who if author_info(who).has("avatar") else "sistema", text.substr(j + 2), {"tipo": "v02"})
		return
	_publish("dm:shero" if channel == "dm" else "#team-familia", "shero", text, {"tipo": "v02", "mention": channel == "dm"})


func _on_ww(number: int, reason: String) -> void:
	var lc: Dictionary = DataLoader.dict("lineas_canales")
	var txt := Loc.fmt(Loc.pick(lc.get("ww_dm", {})), {"n": number, "motivo": Checkpoints.cause_text(reason)})
	_publish("dm:shero", "shero", txt, {"tipo": "ww", "ack": true, "quick_replies": ["ack"], "mention": true, "n": number, "motivo": reason})


func _close_ack() -> void:
	for m in messages("dm:shero"):
		if bool(m.get("ack", false)):
			m["ack"] = false
			m["quick_replies"] = []
	updated.emit("dm:shero")


func _on_coaching_requested(seconds: float) -> void:
	rooms_pending = true
	rooms_left = seconds
	rooms_from = "shero"
	var lc: Dictionary = DataLoader.dict("lineas_canales")
	_publish("dm:shero", "shero", line_text("lineas_canales", "rooms_invitacion"), {"tipo": "rooms", "rooms": seconds, "quick_replies": ["join_rooms"], "mention": true})


## v0.2: a los 10 min de un correo Shero pide una excusa (mientras P3 no ejecute la pista "correo").
func _on_email_over_time(_id: String, _s: float) -> void:
	if ContactManager.discipline_owns("correo"):
		return
	excuse_pending = true
	var lc: Dictionary = DataLoader.dict("lineas_canales").get("excusa", {})
	_publish("dm:shero", "shero", Loc.pick(lc.get("pregunta", {})), {"tipo": "excusa", "quick_replies": ["excusa_1", "excusa_2", "excusa_3"], "mention": true, "typing_s": 0.0})


func _answer_excuse(i: int) -> void:
	if not excuse_pending:
		return
	excuse_pending = false
	var lc: Dictionary = DataLoader.dict("lineas_canales").get("excusa", {})
	var correct := int(DataLoader.bal("correo_bo/excusa_correcta", 2)) - 1
	if i == correct:
		Metrics.report_miss("aht_bo")
		_reply_later("dm:shero", "shero", Loc.pick(lc.get("respuesta_ok", {})), 1.5)
	else:
		_reply_later("dm:shero", "shero", Loc.pick(lc.get("respuesta_mal", {})), 1.0)
		Metrics.issue_written_warning("aht_bo")


func _process(delta: float) -> void:
	_tick_reaction(delta)
	if rooms_pending and GameState.running and not get_tree().paused and not Discipline.is_lunch_immune():
		rooms_left -= delta
		if rooms_left <= 0.0:
			rooms_pending = false
			updated.emit("dm:" + rooms_from)
			if not ContactManager.discipline_owns("coaching_noshow"):
				Checkpoints.request_death("coaching", "", "shero")


func _on_clock(now: float) -> void:
	if not GameState.logged_in or GameState.shift_over:
		return
	var prog: Array = _cfg().get("programados", [])
	while _sched_next < prog.size() and GameState.hhmm_to_seconds(str((prog[_sched_next] as Dictionary).get("hora", "00:00"))) <= now:
		var p: Dictionary = prog[_sched_next]
		_sched_next += 1
		var turnos: Array = p.get("turnos", [1, 2, 3])
		if not turnos.has(GameState.turno) and not turnos.has(float(GameState.turno)):
			continue
		if about_player(p):
			continue  # v0.3.2-core: un aviso «sobre un compañero» no sale cuando ese compañero eres tú
		var lc: Dictionary = DataLoader.dict("lineas_canales")
		var meta: Dictionary = {"tipo": "programado", "typing_s": float(p.get("typing_s", 0.0))}
		var body := ""
		if p.has("edita"):
			meta["edita"] = Loc.pick(lc.get(str(p.get("edita")), {}))
			meta["edita_s"] = float(p.get("edita_s", 6.0))
			body = Loc.pick(lc.get(str(p.get("linea", "")), {}))  # la que se edita va sin variante (el texto editado la sigue)
		else:
			body = line_text("lineas_canales", str(p.get("linea", "")))
			if body == "" and tr(str(p.get("linea", ""))) != str(p.get("linea", "")):
				body = tr(str(p.get("linea", "")))  # v0.3.1 Q3: líneas en strings_v031_q3.csv
		if str(p.get("tags", "")) == "coaching":
			body += " " + coaching_tags()
			# v0.3.2 IA (referencia real de Joan): el aviso pide reacción; reaccionar es el «estoy al tanto»
			body += "\n" + tr("IA_REACT_ASK")
			meta["pide_reaccion"] = true
		if bool(p.get("reacciones", false)):
			meta["reacciones"] = true
		if p.has("borra"):
			meta["borra_s"] = float(p.get("borra_s", 6.0))
		if p.has("captura"):
			meta["captura"] = p["captura"]
		EventBus.ezlak_post.emit(str(p.get("canal", "#team-familia")), str(p.get("autor", "sistema")), Loc.fmt(body, {"agente": GameState.agent}), meta)
	while _dm_next < _dm_lines.size() and float(_dm_lines[_dm_next]["t"]) <= now:
		var d: Dictionary = _dm_lines[_dm_next]
		_dm_next += 1
		EventBus.ezlak_post.emit(str(d["canal"]), str(d["autor"]), Loc.pick(d["msg"]), {"tipo": "dm_companero", "typing_s": _rng.randf_range(1.0, 3.0), "quick_replies": quick_replies_for(str(d["canal"]))})
	while _extra_next < _extra_dm.size() and float(_extra_dm[_extra_next]["t"]) <= now:
		var x: Dictionary = _extra_dm[_extra_next]
		_extra_next += 1
		if channels.has(str(x["canal"])) and IABrain.off_floor_t3() != str(x["autor"]):  # el que ya no está en la sala (miércoles) no charla
			EventBus.ezlak_post.emit(str(x["canal"]), str(x["autor"]), Loc.pick(x["msg"]), {"tipo": "dm_companero", "typing_s": _rng.randf_range(1.0, 3.0), "quick_replies": quick_replies_for(str(x["canal"]))})
	while _ghost_next < _ghosts.size() and _ghosts[_ghost_next] <= now:
		_ghost_next += 1
		var gh: Dictionary = _cfg().get("typing_fantasma", {})
		var secs := float(gh.get("typing_s", 6.0))
		typing("dm:shero", "shero", secs)
		if GameState.turno >= 2 and _ghost_next % 2 == 0:
			EventBus.ezlak_post.emit("dm:shero", "shero", Loc.pick(gh.get("final_vi", {})), {"tipo": "visto", "typing_s": secs + 0.2})
	_maybe_degrade(now)


## De madrugada (bloque 3) o con Fatiga alta, los DMs de los compañeros se degradan.
func _maybe_degrade(now: float) -> void:
	var la: Dictionary = DataLoader.dict("lineas_agentes")
	var horas: Array = la.get("degradacion_horas", [])
	for i in horas.size():
		var key := "h%d" % i
		if _degrade_done.has(key):
			continue
		var t := GameState.hhmm_to_seconds(str(horas[i]))
		var early := Fatigue.value >= 70.0 and now >= t - 3.0 * 3600.0
		if now < t and not early:
			continue
		_degrade_done.append(key)
		var dms := agent_dms(GameState.agent)
		if dms.is_empty():
			return
		var who := str(dms[i % dms.size()])
		var pool: Array = (la.get("degradacion", {}) as Dictionary).get(who, [])
		if pool.is_empty():
			continue
		var line: Dictionary = pool[(i + GameState.turno) % pool.size()]
		var meta := {"tipo": "degradacion", "typing_s": 4.0}
		if i == horas.size() - 1:
			meta["borra_s"] = 5.0
		EventBus.ezlak_post.emit("dm:" + who, who, Loc.pick(line), meta)


func _build_dm_schedule() -> void:
	_dm_lines.clear()
	var me := GameState.agent.to_lower()
	var hilos: Dictionary = DataLoader.dict("lineas_agentes").get("hilos", {})
	for k in hilos.keys():
		var parts := str(k).split(">")
		if parts.size() != 2 or parts[1] != me:
			continue
		for msg in (hilos[k] as Dictionary).get(str(GameState.turno), []):
			_dm_lines.append({"t": GameState.hhmm_to_seconds(str(msg.get("hora", "00:00"))), "canal": "dm:" + parts[0], "autor": parts[0], "msg": msg})
	_dm_lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## Avatar de Ezlaki (128 px, ref_caras_v2) por slug; silueta si falta.
static func avatar(slug: String) -> Texture2D:
	if slug == "":
		return null
	slug = Faces.mood_slug(slug)  # P6: Shero enojado → avatar calvo
	var t := Faces.texture_at("res://assets/ui/ezlak/%s.png" % slug)
	if t != null:
		return t
	return Faces.texture(slug)


# --- v0.3.1 Q3 · variedad sin repetir ------------------------------------------------------------------------

static func q3() -> Dictionary:
	return DataLoader.dict("ezlaki_q3")


## Todas las variantes de una línea: la base (dict {es,en}, lista de dicts o {lineas: [...]}) + ezlaki_q3/variantes.
func line_pool(file: String, key: String) -> Array:
	var out: Array = []
	var base: Variant = DataLoader.dict(file).get(key, null)
	if base is Dictionary and (base as Dictionary).has("lineas"):
		base = (base as Dictionary)["lineas"]
	if base is Dictionary and ((base as Dictionary).has("es") or (base as Dictionary).has("en")):
		out.append(base)
	elif base is Array:
		for b in base:
			if b is Dictionary:
				out.append(b)
	var extra: Variant = ((q3().get("variantes", {}) as Dictionary).get(file, {}) as Dictionary).get(key, [])
	if extra is Array:
		for e in extra:
			out.append(e)
	return out


## Una variante que no salió todavía en este turno (cuando se agotan, vuelve a empezar). Con {agente} y {hora}.
## v0.3.2-core (pasada 8 de partidas en fotos, jugando con Marko): ¿este aviso programado habla de un compañero que
## eres TÚ? A las 4:50 el RTA publica «@Marko perdiste un contacto. Missed.» con su captura; jugando con Marko te
## acusaba en público de una perdida que no existía (0 perdidas, y estabas en el lunch). Igual con «@Ttoom AUX
## incorrecto», «@Llauri tercer tag casi», «@Juan…» y la lista de Shero de correos excedidos (@Llauri, @Juan).
## Lo que el juego dice de ti sale de lo que hiciste (Perrito RTA, Discipline), no del guion de ambiente.
func about_player(p: Dictionary) -> bool:
	var me := SaveSlots.slug(GameState.agent)
	if me == "":
		return false
	var cap: Variant = p.get("captura", null)
	if cap is Dictionary:
		for q in str((cap as Dictionary).get("quien", "")).split(",", false):
			if q.strip_edges() == me:
				return true
	return str(p.get("linea", "")).ends_with("_npc_" + me)


func line_text(file: String, key: String) -> String:
	return Loc.fmt(Loc.pick(_pick_unused(file + "/" + key, line_pool(file, key))), {"agente": GameState.agent, "hora": GameState.clock_text()})


func _pick_unused(key: String, pool: Array) -> Variant:
	if pool.is_empty():
		return {}
	var used: Array = _used.get(key, [])
	if used.size() >= pool.size():
		used = []
	var free: Array = []
	for i in pool.size():
		if not used.has(i):
			free.append(i)
	# la primera vez en el turno, la variante depende del turno (así T1, T2 y T3 no abren igual)
	var i: int = free[(GameState.turno - 1) % free.size()] if used.is_empty() else free[_rng.randi_range(0, free.size() - 1)]
	used.append(i)
	_used[key] = used
	return pool[i]


## Charla extra de los compañeros por DM: 3 por DM y turno, a horas al azar, sin repetir.
func _build_extra_dms() -> void:
	_extra_dm.clear()
	_extra_next = 0
	var pool: Dictionary = q3().get("dm_extra", {})
	var r := RandomNumberGenerator.new()
	r.seed = 4040 + GameState.turno * 7 + GameState.AGENTS.find(GameState.agent)
	for who in agent_dms(GameState.agent):
		var lines: Array = pool.get(str(who), [])
		if lines.is_empty():
			continue
		var idx: Array = range(lines.size())
		for k in range(idx.size() - 1, 0, -1):
			var j := r.randi_range(0, k)
			var tmp: Variant = idx[k]
			idx[k] = idx[j]
			idx[j] = tmp
		for n in mini(1, idx.size()):
			var t := GameState.hhmm_to_seconds("00:30") + r.randf_range(0.0, 7.0 * 3600.0)
			_extra_dm.append({"t": t, "canal": "dm:" + str(who), "autor": str(who), "msg": lines[idx[n]]})
	_extra_dm.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


# --- v0.3.1 Q3 · limitador (B9/F7, lado del hub) -------------------------------------------------------------

## true si el mensaje queda retenido (o se descarta por duplicado). Lo retenido sale al cumplirse los 20 s.
func _limit(ch: String, author: String, text: String, meta: Dictionary) -> bool:
	if author in ["yo", "sistema"] or not (str(meta.get("tipo", "")) in LIMITED_TIPOS) or bool(meta.get("_sin_limite", false)):
		return false
	var key := "%s|%s" % [ch, author]
	var last := int(_last_post.get(key, -100000))
	var wait_ms := LIMIT_S * 1000.0 / maxf(Engine.time_scale, 0.01) - float(Time.get_ticks_msec() - last)
	if wait_ms <= 0.0 and not _queued.has(key):
		return false
	limited_count += 1
	var dup := false
	for m in messages(ch).slice(maxi(0, messages(ch).size() - 3)):
		if str((m as Dictionary).get("texto", "")) == text and str((m as Dictionary).get("autor", "")) == author:
			dup = true
	if dup:
		return true  # la misma línea otra vez (aliento agotado 30 veces): se descarta
	var had := _queued.has(key)
	_queued[key] = [ch, author, text, meta]  # uno por clave: el último manda
	if not had and is_inside_tree():
		_flush_later(key, maxf(wait_ms, 50.0) / 1000.0 * Engine.time_scale)
	return true


func _flush_later(key: String, s: float) -> void:
	await get_tree().create_timer(s).timeout
	if not is_inside_tree() or not _queued.has(key):
		return
	var q: Array = _queued[key]
	_queued.erase(key)
	var meta: Dictionary = (q[3] as Dictionary).duplicate()
	meta["_sin_limite"] = true
	_on_post(str(q[0]), str(q[1]), str(q[2]), meta)


# --- v0.3.1 Q3 · capturas y reacciones ----------------------------------------------------------------------

## Pista de disciplina -> estado de la vista de adherencia.
const PISTA_ESTADO := {"break": "break", "break_1": "break", "break_2": "break", "tercer_break": "break", "lunch": "lunch",
	"correo": "contacto", "llamadas_perdidas": "perdido", "coaching": "coaching", "coaching_exceso": "coaching",
	"coaching_noshow": "coaching", "topico": "bano", "topico_excedido": "bano", "training_regreso": "training",
	"tres_molestos": "acw", "available": "", "sala": "", "otra_isla": ""}


func _attach_capture(ch: String, author: String, m: Dictionary, meta: Dictionary) -> void:
	if meta.get("captura", null) is Dictionary and author in ["shero", "rta"]:  # pedida explícitamente: en cualquier canal
		m["captura"] = captura.make((meta["captura"] as Dictionary).duplicate(), int(m.get("id", 0)))
		m["reacciones"] = []
		return
	if ch != "#allocations" or not (author in ["shero", "rta"]):
		return
	var spec: Dictionary = {}
	if meta.get("captura", null) is Dictionary:
		spec = (meta["captura"] as Dictionary).duplicate()
	else:
		var tipo := str(meta.get("tipo", ""))
		if tipo == "disciplina":
			var pista := str(meta.get("pista", ""))
			spec = {"tipo": "uno", "estado": str(PISTA_ESTADO.get(pista, "")), "quien": "jugador", "tema": "claro" if pista in ["llamadas_perdidas", "correo"] else "oscuro"}
		elif tipo == "tag":
			var who := "jugador"
			for a in GameState.AGENTS:
				if str(m.get("texto", "")).contains("@" + a) and a != GameState.agent:
					who = a.to_lower()
			spec = {"tipo": "uno", "estado": "", "quien": who, "tema": "oscuro"}
		elif tipo == "orden_aux":
			spec = {"tipo": "lista", "estado": "available", "n": 7, "tema": "oscuro"}
	if spec.is_empty():
		return
	m["captura"] = captura.make(spec, int(m.get("id", 0)))
	m["reacciones"] = []


## Los compañeros reaccionan a los posts de #allocations (y a algunos de los canales) con emoji propios del site: las
## caras de Ezlaki. Llegan de a poco, como en un canal de verdad.
func _react_later(m: Dictionary) -> void:
	if not is_inside_tree():
		return
	m["reacciones"] = []
	var pool: Array = (EzlakiCaptura.cfg().get("reacciones", []) as Array).duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = 777 + int(m.get("id", 0)) * 13
	var kinds := r.randi_range(2, 6)
	for k in kinds:
		await get_tree().create_timer(r.randf_range(0.8, 3.5)).timeout
		if not is_inside_tree() or pool.is_empty():
			return
		var e: String = pool.pop_at(r.randi_range(0, pool.size() - 1))
		(m["reacciones"] as Array).append([e, r.randi_range(1, 10)])
		updated.emit(str(m.get("canal", "")))


# --- v0.3.1 Q3 · respuesta escrita (B6) -----------------------------------------------------------------------

static func _norm(text: String) -> String:
	var t := " " + text.to_lower() + " "
	var rep := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n", "¿": " ", "¡": " ", "'": "", "’": ""}
	for k in rep.keys():
		t = t.replace(k, rep[k])
	var out := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == "?":
			out += ch
		else:
			out += " "
	while out.contains("  "):
		out = out.replace("  ", " ")
	return " " + out.strip_edges() + " "


## Intención de un texto libre (ES/EN). v0.3.2 IA: la entiende IANlu (jerga, faltas, frases; data/ia/nlu.json) y la
## traduce a las intenciones de la v0.3.1 (insulto, ayuda, ack, voy, excusa, negar, pregunta, gracias, broma, saludo,
## queja, ok, otro, vacio), que son las que usa la mecánica (Ack, Rooms, tópico, botones).
static func classify_intent(text: String) -> String:
	return str(IANlu.analyze(text).get("coarse", "otro"))


## v0.3.1 (Q3): clasificador por palabras clave de ezlaki_q3.json/intenciones (se conserva para comparar).
static func classify_intent_q3(text: String) -> String:
	var t := _norm(text)
	if t.strip_edges() == "":
		return "vacio"
	var cfg: Dictionary = q3().get("intenciones", {})
	for intent in cfg.get("_orden", []):
		for kw in cfg.get(str(intent), []):
			var k := str(kw)
			if k == "?":
				if t.contains("?"):
					return str(intent)
				continue
			if t.contains(" " + _norm(k).strip_edges() + " "):
				return str(intent)
	return "otro"


## v0.3.2 IA: lo que el personaje del canal espera ahora (para que «sí», «dale», «ok» cuenten como Ack / ir al Rooms).
func brain_ctx(ch: String) -> Dictionary:
	var ctx := {"expect": [], "afirmar_es": ""}
	if ch == "dm:shero" and Metrics.ack_pending:
		ctx["expect"] = ["ack"]
		ctx["afirmar_es"] = "ack"
	elif ch == "dm:" + rooms_from and rooms_pending:
		ctx["expect"] = ["voy"]
		ctx["afirmar_es"] = "voy"
	elif not _pending_with(ch, "voy").is_empty():
		ctx["expect"] = ["voy", "negar"]
		ctx["afirmar_es"] = "voy"
	return ctx


## Quién contesta en un canal: el dueño del DM, o el que corresponda en los canales.
func _mentioned_actor(clean_text: String) -> String:
	var low := _norm(clean_text)
	var targets := {
		"mentor": ["mentor"],
		"rasec": ["rasec", "dj"],
		"haime": ["haime", "qa", "calibracion"],
		"trainer": ["trainer", "grasa"],
		"rta": ["rta", "perrito"],
		"papayala": ["papayala", "papaya"],
		"om": ["om", "gerente"],
		"marko": ["marko"],
		"llauri": ["llauri"],
		"ttoom": ["ttoom"],
		"juan": ["juan"],
		"shero": ["shero"],
	}
	for slug in targets.keys():
		for kw in targets[slug]:
			if low.contains(" " + kw + " "):
				return slug
	return ""


func responder_for(ch: String, intent: String, clean_text: String = "") -> String:
	if ch.begins_with("dm:"):
		return ch.substr(3)
	var mentioned := _mentioned_actor(clean_text)
	if mentioned != "":
		return mentioned
	match ch:
		"#allocations":
			return "shero" if intent in ["insulto", "excusa"] else "rta"
		"#site-updates":
			return "om"
		"#team-familia":
			if intent in ["insulto", "excusa", "queja", "saludo"]:
				return "shero"
			if intent == "pregunta":
				return "mentor"
			return "companero"
	return "sistema"


## Respuesta rápida que equivale a la intención en ese canal ("" = ninguna).
func reply_id_for(ch: String, intent: String) -> String:
	var qr: Array = quick_replies_for(ch)
	match intent:
		"ack":
			return "ack" if ch == "dm:shero" and Metrics.ack_pending else ""
		"voy":
			if ch == "dm:" + rooms_from and rooms_pending:
				return "join_rooms"
			return "voy" if qr.has("voy") else ""
		"ok":
			return "ok" if qr.has("ok") else ""
		"ayuda":
			return "me_siento_mal" if ch == "dm:shero" else ""
		"negar":
			return "no_gracias" if qr.has("no_gracias") else ""
		"broma":
			return "jaja" if qr.has("jaja") else ""
		"gracias":
			return "gracias" if qr.has("gracias") else ""
	return ""


## El jugador escribió `text` en `channel` (campo «Escribir…» de la app). Devuelve la intención detectada.
func typed_reply(channel: String, text: String) -> String:
	var ch := normalize(channel)
	var clean := text.strip_edges().replace("[", "(").replace("]", ")").left(160)
	var nlu := IANlu.analyze(clean, brain_ctx(ch))
	var intent := str(nlu.get("coarse", "vacio"))
	last_intent = intent
	last_nlu = nlu
	if intent == "vacio":
		return intent
	_ensure(ch)
	var now := Time.get_ticks_msec()
	_typed_ms.append(now)
	var lim: Dictionary = q3().get("limite_jugador", {})
	var win_ms := float(lim.get("ventana_s", 20.0)) * 1000.0 / maxf(Engine.time_scale, 0.01)
	while not _typed_ms.is_empty() and now - int(_typed_ms[0]) > win_ms:
		_typed_ms.pop_front()
	var spam := _typed_ms.size() > int(lim.get("mensajes", 3))
	var who := responder_for(ch, intent, clean)
	last_typed_reply = {"canal": ch, "intencion": intent, "autor": who, "texto": clean}
	# excusa al correo de más de 10 min: se evalúa como la excusa de los botones
	if excuse_pending and ch == "dm:shero" and intent in ["excusa", "otro", "pregunta", "ok"]:
		_publish(ch, "yo", clean, {"tipo": "respuesta_escrita", "silent": true})
		var n := _norm(clean)
		var good := n.contains(" nota") or n.contains("duplic") or n.contains("verific") or n.contains(" revise") or n.contains("checked") or n.contains("duplicate")
		var correct := int(DataLoader.bal("correo_bo/excusa_correcta", 2)) - 1
		_answer_excuse(correct if good else (correct + 1) % 3)
		updated.emit(ch)
		return "excusa"
	var rid := reply_id_for(ch, intent)
	if rid != "":  # la mecánica (Ack, Rooms, tópico, P5) nunca la frena el antispam
		quick_reply(ch, rid, {}, clean)
		if rid in ["ack", "en_un_caso", "join_rooms", "me_siento_mal"] or (rid == "ok" and ch == "dm:shero"):
			if rid == "me_siento_mal" and ch == "dm:shero":
				_reply_later(ch, "shero", _response("shero", "ayuda"), 1.6)
			return intent
		if rid in ["voy", "no_gracias", "ok"] and not (ch.substr(3) in agent_dms(GameState.agent)):
			brain_reply(ch, who, clean, nlu)
		elif ch.begins_with("dm:") and ch.substr(3) in agent_dms(GameState.agent):
			brain_reply(ch, ch.substr(3), clean, nlu)
		return intent
	_publish(ch, "yo", clean, {"tipo": "respuesta_escrita", "silent": true})
	if spam:
		if not bool(_used.get("_spam_aviso_%d" % int(now / maxf(win_ms, 1.0)), false)):
			_used["_spam_aviso_%d" % int(now / maxf(win_ms, 1.0))] = true
			_reply_later(ch if ch == "dm:shero" else "dm:shero", "shero", Loc.pick(lim.get("aviso_shero", {})), 1.2)
		updated.emit(ch)
		return intent
	# v0.3.2 IA (estados): Shero «en llamada» no está leyendo los canales (su DM sí): lo que le sueltes ahí no lo ve
	# ahora; un compañero te avisa. Es la pista de su estado: «activo» = está leyendo.
	if who == "shero" and not ch.begins_with("dm:") and IABrain.presence_state("shero") != "activo":
		var avisos: Array = (IABrain.cfg().get("presencia", {}) as Dictionary).get("shero_no_lee", [])
		var cw := _random_coworker()
		last_typed_reply["autor"] = cw
		last_brain = {"shero_no_lee": true}
		if not avisos.is_empty():
			_reply_later(ch, cw, Loc.pick(_pick_unused("ia/shero_no_lee", avisos)), _rng.randf_range(1.5, 3.0))
		updated.emit(ch)
		return intent
	if who == "shero" and intent == "insulto":
		_insults += 1
	var real := who if who != "companero" else _random_coworker()
	brain_reply(ch, real, clean, nlu)
	updated.emit(ch)
	return intent


## v0.3.2 IA: el cerebro (IABrain) decide qué contesta `who` y con qué consecuencias; aquí se publica con su
## «escribiendo…», uno o varios mensajes, o se queda en «Visto».
func brain_reply(ch: String, who: String, text: String, nlu: Dictionary = {}) -> Dictionary:
	var ctx := {"nlu": nlu} if not nlu.is_empty() else {}
	var r: Dictionary = IABrain.reply(who, ch, text, ctx)
	last_brain = r
	if bool(r.get("visto", false)):
		_mark_seen(ch, who)
		return r
	_post_sequence(ch, who, r.get("mensajes", []))
	return r


func _mark_seen(ch: String, who: String) -> void:
	var ms := messages(ch)
	if not ms.is_empty() and str((ms.back() as Dictionary).get("autor", "")) == "yo":
		(ms.back() as Dictionary)["visto_por"] = who
		(ms.back() as Dictionary)["visto_hora"] = GameState.clock_text()
	updated.emit(ch)


func _post_sequence(ch: String, who: String, msgs: Array) -> void:
	var epoch := _epoch
	var rw := _rewinds
	for m in msgs:
		var s := float((m as Dictionary).get("espera", 1.5))
		typing(ch, who, s)
		await get_tree().create_timer(s).timeout
		if not is_inside_tree() or epoch != _epoch or rw != _rewinds:  # cambió el turno, volviste al menú o reapareciste: esa charla ya no existe
			return
		_publish(ch, who, str((m as Dictionary).get("texto", "")), {"tipo": "respuesta_npc"})


## Línea de respuesta de `who` a una intención, sin repetir en el turno (cae a «otro» y después al pool de compañeros).
func _response(who: String, intent: String) -> String:
	var r: Dictionary = q3().get("respuestas", {})
	var role := who
	if not r.has(role):
		role = "companero" if GameState.AGENTS.map(func(a: String) -> String: return a.to_lower()).has(who) else "sistema"
	var by: Dictionary = r.get(role, {})
	var pool: Array = by.get(intent, by.get("otro", []))
	if pool.is_empty():
		pool = (r.get("companero", {}) as Dictionary).get("otro", [])
	var pick: Variant = _pick_unused("resp/%s/%s" % [role, intent if by.has(intent) else "otro"], pool)
	return Loc.fmt(Loc.pick(pick), {"agente": GameState.agent, "hora": GameState.clock_text()})


## El último mensaje del canal que ofrece esa respuesta rápida y no se respondió (para que escribir «ack» lo cierre).
func _pending_with(ch: String, reply_id: String) -> Dictionary:
	var ms := messages(ch)
	for i in range(ms.size() - 1, -1, -1):
		var m: Dictionary = ms[i]
		if (m.get("quick_replies", []) as Array).has(reply_id) and not bool(m.get("respondido", false)):
			return m
	return {}


## «@here … ingresan al Rooms de coachings: @… @…» (07:00): 3-4 compañeros inventados del site y el jugador SOLO si
## tiene un coaching pendiente de verdad (invitación a Rooms abierta o la pista de coaching de Discipline corriendo).
func coaching_tags() -> String:
	var pool: Array = []
	for k in (EzlakiCaptura.cfg().get("identidades", {}) as Dictionary).keys():
		if not GameState.AGENTS.map(func(a: String) -> String: return a.to_lower()).has(str(k)):
			pool.append(str(k))
	var r := RandomNumberGenerator.new()
	r.seed = 5150 + GameState.turno
	var tags: Array[String] = []
	for i in r.randi_range(3, 4):
		if pool.is_empty():
			break
		tags.append("@" + str(pool.pop_at(r.randi_range(0, pool.size() - 1))).capitalize())
	if coaching_pending():
		tags.insert(r.randi_range(0, tags.size()), "@" + GameState.agent)
	return " ".join(tags)


func coaching_pending() -> bool:
	if rooms_pending:
		return true
	var tracks := Discipline.active_tracks()
	for k in tracks.keys():
		if str(k).begins_with("coaching"):
			return true
	return false


# --- v0.3.2 IA · avisos que piden reacción (emoji = «estoy al tanto») y la pared de reacciones ---------------
## Shero publica «@here … Espero su reacción para saber que están al tanto»: el jugador reacciona con un emoji (clic
## en «+ reaccionar» bajo el mensaje, o [Enter] con Ezlaki a la vista y luego ← → y [Enter]). 👍 ✅ 👀 🙏 🫡 👌 = acuse;
## 😂 🤡 💀 🙄 = falta de respeto (IABrain).
## La pared: el team (los 4 agentes + compañeros inventados del site) reacciona uno por uno con emojis estándar; el
## contador sube y la app dice cuántos faltan hasta que queda «SOLO FALTAS TÚ» con la cuenta atrás. Los compañeros
## que no están en línea (en lunch, ausentes: IABrain.presence) no reaccionan y salen como tales.
## El miércoles (turno 3), entre los que reaccionaron al aviso de coaching hay un compañero que a esa hora ya no está
## en la sala (personas.json/presencia/fuera_t3): su estado dice «ausente» y su ✅ está ahí, en la lista, sin más.
## La ventana va en segundos REALES (personas.json/reaccion_aviso) y solo corre sentado en tu PC, sin pausa, fuera del
## lunch y de la calma. Vencida: Shero escribe «¿No viste el mensaje?» y alerta; vencida otra vez, WW.

const REACT_OK: Array[String] = ["👍", "✅", "👀", "🙏", "🫡", "👌"]
const REACT_BAD: Array[String] = ["😂", "🤡", "💀", "🙄"]

var reaction_pending: Dictionary = {}  # {id, canal, quedan (s reales), ventana, etapa}
var last_reaction: Dictionary = {}  # pruebas: {id, emoji, resultado}
var _react_running: bool = false
var _epoch: int = 0  # cambia en cada reset(): lo que quedó «escribiendo» del turno anterior no se publica en el nuevo
var _react_alone_id: int = -1


static func reaction_choices() -> Array[String]:
	var out: Array[String] = []
	out.append_array(REACT_OK)
	out.append_array(REACT_BAD)
	return out


func _react_cfg() -> Dictionary:
	return (IABrain.cfg().get("reaccion_aviso", {}) as Dictionary)


## Ventana para reaccionar, en segundos reales (según la dificultad).
func reaction_window_s() -> float:
	var c := _react_cfg()
	var k: Dictionary = c.get("por_dificultad", {})
	return float(c.get("ventana_s_real", 45.0)) * float(k.get(Difficulty.IDS[clampi(Difficulty.effective(), 0, 2)], 1.0))


## Segundos reales que te quedan para reaccionar (0 si no hay aviso pendiente).
func reaction_left() -> float:
	return maxf(float(reaction_pending.get("quedan", 0.0)), 0.0) if not reaction_pending.is_empty() else 0.0


func request_reaction(m: Dictionary) -> void:
	m["pide_reaccion"] = true
	m["emojis"] = []
	var w := reaction_window_s()
	reaction_pending = {"id": int(m.get("id", 0)), "canal": str(m.get("canal", "")), "quedan": w, "ventana": w, "etapa": 0}
	_react_alone_id = -1
	m["pared"] = _build_wall()
	_coworker_emojis(m)


## El team que debe reaccionar: los otros 4 agentes y unos cuantos compañeros inventados del site.
func _build_wall() -> Dictionary:
	var equipo: Array = []
	for a in GameState.AGENTS:
		if a != GameState.agent:
			equipo.append({"slug": a.to_lower(), "nombre": a, "agente": true})
	var ids: Dictionary = EzlakiCaptura.cfg().get("identidades", {})
	var pool: Array = []
	for k in ids.keys():
		if not GameState.AGENTS.map(func(a: String) -> String: return a.to_lower()).has(str(k)):
			pool.append(str(k))
	var r := RandomNumberGenerator.new()
	r.seed = 6160 + GameState.turno
	for i in mini(int(_react_cfg().get("equipo_inventados", 7)), pool.size()):
		var k: String = pool.pop_at(r.randi_range(0, pool.size() - 1))
		var id: Array = ids[k]
		equipo.append({"slug": k, "nombre": str(id[2]) if id.size() > 2 else k.capitalize(), "agente": false})
	return {"equipo": equipo, "esperados": [], "raro": ""}


## Los compañeros en línea reaccionan uno por uno (el contador sube) dentro de la primera parte de la ventana.
func _coworker_emojis(m: Dictionary) -> void:
	var wall: Dictionary = m["pared"]
	var r := RandomNumberGenerator.new()
	r.seed = 4242 + int(m.get("id", 0)) + GameState.turno * 17
	var who: Array = []
	for p in wall["equipo"]:
		if not bool(p["agente"]) or IABrain.presence_state(str(p["slug"])) in ["activo", "llamada"]:
			who.append(str(p["nombre"]))
	for k in range(who.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp: String = who[k]
		who[k] = who[j]
		who[j] = tmp
	# Miércoles: uno que ya no está en la sala también aparece entre los que reaccionaron (no suena ni se anuncia).
	var gone := IABrain.off_floor_t3()
	if gone != "":
		for p in wall["equipo"]:
			if str(p["slug"]) == gone and not who.has(str(p["nombre"])):
				who.insert(maxi(who.size() - 2, 0), str(p["nombre"]))
				wall["raro"] = str(p["nombre"])
	wall["esperados"] = who.duplicate()
	var pool: Array[String] = ["✅", "✅", "✅", "✅", "👍", "👍", "👍", "👀", "🫡", "🙏"]
	var epoch := _epoch
	var span := float(reaction_pending.get("ventana", 45.0)) * float(_react_cfg().get("reparto", 0.55))
	var prev := 0.0
	for i in who.size():
		var at := span * pow(float(i + 1) / float(who.size()), 1.25) * r.randf_range(0.92, 1.05)
		await get_tree().create_timer(maxf(at - prev, 0.15)).timeout
		prev = maxf(at, prev)
		if not is_inside_tree() or epoch != _epoch:
			return
		_add_emoji(m, pool[r.randi_range(0, pool.size() - 1)], false, who[i])
		updated.emit(str(m.get("canal", "")))
		_check_alone(m)


func _add_emoji(m: Dictionary, e: String, mine: bool, who: String = "") -> void:
	if not m.has("emojis"):
		m["emojis"] = []
	for row in m["emojis"]:
		if str(row[0]) == e:
			row[1] = int(row[1]) + 1
			if mine:
				row[2] = true
			if who != "":
				(row[3] as Array).append(who)
			return
	(m["emojis"] as Array).append([e, 1, mine, [who] if who != "" else []])


## Quiénes reaccionaron ya a un mensaje (nombres, sin ti).
func reactors(m: Dictionary) -> Array:
	var out: Array = []
	for row in m.get("emojis", []):
		if (row as Array).size() > 3:
			out.append_array(row[3])
	return out


## Estado de la pared de un aviso: {total, hechos, faltan: [nombres en línea que aún no reaccionan], fuera: [[nombre,
## estado]] (no están en línea), solo_tu, yo (ya reaccionaste), quedan (s reales), raro (el que no debería estar)}.
func wall_status(m: Dictionary) -> Dictionary:
	var wall: Dictionary = m.get("pared", {})
	var done := reactors(m)
	var faltan: Array = []
	var fuera: Array = []
	for p in wall.get("equipo", []):
		var n := str(p["nombre"])
		if done.has(n):
			continue
		if (wall.get("esperados", []) as Array).has(n):
			faltan.append(n)
		else:
			fuera.append([n, str(IABrain.presence(str(p["slug"]))["texto"])])
	var yo := str(m.get("mi_emoji", "")) != ""
	var pending := int(reaction_pending.get("id", -1)) == int(m.get("id", -2))
	return {"total": (wall.get("equipo", []) as Array).size() + 1, "hechos": done.size() + (1 if yo else 0), "faltan": faltan, "fuera": fuera,
		"solo_tu": not yo and faltan.is_empty() and not (wall.get("esperados", []) as Array).is_empty(), "yo": yo,
		"quedan": reaction_left() if pending else 0.0, "pendiente": pending, "raro": str(wall.get("raro", ""))}


func _check_alone(m: Dictionary) -> void:
	if int(reaction_pending.get("id", -1)) != int(m.get("id", -2)) or _react_alone_id == int(m.get("id", 0)):
		return
	if bool(wall_status(m)["solo_tu"]):
		_react_alone_id = int(m.get("id", 0))
		reaction_alone.emit(m)
		if not bool(GameState.flags.get("pc_zoom", false)):
			EventBus.subtitle.emit("ezlak", Loc.fmt(tr("IA_REACT_ALONE_SUB"), {"canal": channel_title(str(m.get("canal", "")))}), 4.0)


func message_by_id(id: int) -> Dictionary:
	for ch in channels.keys():
		for m in messages(str(ch)):
			if int(m.get("id", -1)) == id:
				return m
	return {}


## El jugador reacciona a un mensaje. Devuelve "acuse" (era el aviso y el emoji es correcto), "falta" (emoji burlón
## a Shero), "ya" (ya habías reaccionado) u "ok" (reacción a cualquier otro mensaje).
func player_react(m: Dictionary, e: String) -> String:
	if m.is_empty() or e == "":
		return ""
	if str(m.get("mi_emoji", "")) != "":
		return "ya"
	m["mi_emoji"] = e
	_add_emoji(m, e, true)
	AudioManager.play_sfx("ezlak_notificacion", "UI")
	var res := "ok"
	var bad := REACT_BAD.has(e)
	var is_notice := bool(m.get("pide_reaccion", false)) and int(reaction_pending.get("id", -1)) == int(m.get("id", -2))
	if is_notice:
		reaction_pending = {}
		res = "acuse"
	if bad and str(m.get("autor", "")) in ["shero", "om", "mentor", "rasec", "haime"]:
		res = "falta"
		var r: Dictionary = IABrain.react_disrespect(str(m.get("autor", "")), str(m.get("canal", "")), e)
		_post_sequence("dm:" + str(m.get("autor", "")) if str(m.get("autor", "")) == "shero" else str(m.get("canal", "")), str(m.get("autor", "")), r.get("mensajes", []))
	elif is_notice:
		IABrain.meter_add("obe", 1, "reaccion_aviso")
	last_reaction = {"id": int(m.get("id", 0)), "emoji": e, "resultado": res}
	updated.emit(str(m.get("canal", "")))
	return res


## ¿Corre la cuenta atrás? Solo cuando puedes verla y contestar: sentado en una PC, con sesión, sin pausa, fuera del
## lunch y de la calma, y vivo.
func reaction_clock_runs() -> bool:
	return GameState.running and GameState.logged_in and not GameState.shift_over and not get_tree().paused and not Checkpoints.dying \
		and GameState.seated_at != "" and not GameState.in_calm and not Discipline.is_lunch_immune()


func _tick_reaction(delta: float) -> void:
	if reaction_pending.is_empty():
		_react_running = false
		return
	var runs := reaction_clock_runs()
	if runs and not _react_running:  # vuelves a tu PC con el aviso esperando: te queda al menos un mínimo
		reaction_pending["quedan"] = maxf(float(reaction_pending["quedan"]), float(_react_cfg().get("minimo_al_volver_s", 15.0)))
	_react_running = runs
	if not runs:
		return
	var before := int(ceil(float(reaction_pending["quedan"])))
	reaction_pending["quedan"] = float(reaction_pending["quedan"]) - delta
	if float(reaction_pending["quedan"]) <= 0.0:
		_reaction_timeout()
	elif int(ceil(float(reaction_pending["quedan"]))) != before:
		updated.emit(str(reaction_pending.get("canal", "")))  # la cuenta atrás visible


func _reaction_timeout() -> void:
	var etapa := int(reaction_pending.get("etapa", 0))
	reaction_pending["etapa"] = etapa + 1
	reaction_pending["quedan"] = float(reaction_pending.get("ventana", reaction_window_s()))
	var c := _react_cfg()
	var ch := str(reaction_pending.get("canal", ""))
	if etapa == 0:
		_publish("dm:shero", "shero", Loc.pick(c.get("recordatorio", {"es": "¿No viste el mensaje?", "en": "Didn't you see the message?"})), {"tipo": "ia_sin_reaccion", "mention": true})
		Metrics.report_miss("sin_reaccion")
	else:
		_publish("dm:shero", "shero", Loc.pick(c.get("recordatorio_2", {"es": "Dos veces. Lo dejo por escrito.", "en": "Twice. I'm putting it in writing."})), {"tipo": "ia_sin_reaccion", "mention": true})
		Metrics.issue_written_warning("sin_reaccion")
		reaction_pending = {}
	updated.emit(ch)

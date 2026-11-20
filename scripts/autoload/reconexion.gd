extends Node
## Reconexion (autoload, v0.3.2; Joan: «me mató el Trainer… y reaparecí en Available pero fuera de la sala de
## operaciones»; «que el tiempo de Reconectando sea de 5 segundos»). Regla del respawn:
##   1. Después de cualquier muerte (menos el fin del turno, el Turno real que reinicia el turno y el checkpoint de
##      inicio en la calle, antes del login) reapareces SENTADO en tu PC (C-14) con la vista de la PC abierta
##      (main.gd/_on_respawned).
##   2. AUX especial «Reconectando» (Metrics.reconnecting) durante balance.json/reconexion/duracion_s_real (5 s
##      reales, con la cuenta a la vista en el HUD y en Fonex): no te ofrecen contactos ni cuenta nada como perdido,
##      nadie convoca (Shero, Rasec, Haime, Trainer, Vitzo, Mentor: además de la gracia de 60 s de Checkpoints) y el
##      Available % no lo cuenta. Termina cuando eliges un AUX o, al llegar a 0, pasa solo a Available.
##   3. Lo restaurado: el reloj vuelve al checkpoint como siempre. El contacto que tenías en curso se cierra como
##      «desconectado» (ni perdido ni AHT) y vuelve a la cola (ContactManager._on_respawned). Si en el checkpoint
##      estabas en un Break o Lunch con cupo, el HUD dice «Te quedaban X min de lunch» y elegir ese AUX lo retoma
##      (no gasta otro break ni reinicia el cupo). El lunch que la muerte pisó se corre: la ventana «a su hora»
##      vuelve a durar entera desde que reapareces (GameState.flags.lunch_retraso_s). El Trainer, el Mentor y Rasec
##      ya convocan con su ventana completa después de la gracia/calma del respawn (ver CHANGELOG).
##   4. v0.3.2-core: si la muerte fue por Available bajo, el Available % se cuenta de nuevo desde cero (aviso arriba);
##      mientras dura «Reconectando», la gracia y la calma, Shero no lee las listas del Mentor.

signal started
signal ended(aux: int)

var active: bool = false
var left: float = 0.0
## AUX con cupo que tenías en el checkpoint (Break / Lunch) y lo que te quedaba (segundos de juego); -1 = ninguno.
var resume_aux: int = -1
var resume_left_s: float = 0.0
var _clock0: float = 0.0
var _death_clock: float = -1.0
var _notice: String = ""  # aviso pendiente para el primer cuadro de «Reconectando»


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: _death_clock = GameState.clock_seconds)
	EventBus.respawned.connect(_on_respawned)
	EventBus.returned_to_menu.connect(func() -> void: _stop())


func duration() -> float:
	return float(DataLoader.bal("reconexion/duracion_s_real", 5.0))


func _on_respawned(kind: String) -> void:
	var death_at := _death_clock
	_death_clock = -1.0
	if kind in ["inicio", "casillero"] or GameState.is_tutorial() or not GameState.logged_in or GameState.shift_over:
		var keep := _notice  # v0.3.2-core3: sin «Reconectando» (reapareces antes del login) el aviso sale igual
		_stop()
		_notice = keep
		return
	_retime_lunch(death_at)
	start()
	if bool(GameState.flags.get("available_reinicio", false)):
		# Moriste por Available bajo: el porcentaje se cuenta de nuevo (Checkpoints._fresh_available). Se dice una vez,
		# en el primer cuadro de «Reconectando» (el respawn limpia los avisos que hubiera en pantalla).
		GameState.flags.erase("available_reinicio")
		notice(tr("B2_RECON_AVL"))


## Aviso para el primer cuadro de «Reconectando» (v0.3.2-core3: también lo usa Checkpoints para decir con qué
## Fatiga reapareces y si hubo ayuda). Varios avisos se juntan en uno.
func notice(text: String) -> void:
	if text == "":
		return
	_notice = text if _notice == "" else _notice + "  ·  " + text


func pending_notice() -> String:
	return _notice


## Empieza «Reconectando» (también lo usan las pruebas).
func start() -> void:
	active = true
	left = duration()
	_clock0 = GameState.clock_seconds
	Metrics.reconnecting = true
	resume_aux = -1
	resume_left_s = 0.0
	if Metrics.aux in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH]:
		var q := Metrics.quota_left(Metrics.aux)
		if q > 30.0:
			resume_aux = Metrics.aux
			resume_left_s = q
	started.emit()


func _process(delta: float) -> void:
	if Checkpoints.dying or not GameState.running:
		return
	if _notice != "":
		VoiceDirector.notice("sys", _notice, 7.0, true)
		_notice = ""
	if not active:
		return
	left -= delta
	if left <= 0.0:
		finish(Metrics.Aux.AVAILABLE, false)


## Fin de «Reconectando»: `aux` es lo que elegiste (o Available al vencer). Elegir el mismo Break/Lunch del checkpoint
## lo retoma con el cupo que quedaba.
func finish(aux: int, by_player: bool) -> void:
	if not active:
		return
	active = false
	Metrics.reconnecting = false
	var elapsed := maxf(GameState.clock_seconds - _clock0, 0.0)
	if aux == Metrics.aux:
		Metrics.aux_since += elapsed  # el tiempo reconectando no cuenta para el AUX que retomas (cupo intacto)
	else:
		if by_player:
			GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
		elif resume_aux == Metrics.Aux.LUNCH and resume_left_s > 60.0:
			# v0.3.2-core3: se acabó la cuenta sin elegir y pasas a Available, pero lo que te quedaba del Lunch del
			# checkpoint sigue ahí (su cupo es de todo el turno): se dice, porque el texto de «Reconectando» ya no está.
			EventBus.show_message.emit(Loc.fmt(tr("CORE3_RECON_QUEDA"), {"min": int(ceil(resume_left_s / 60.0)), "aux": Metrics.aux_name(resume_aux)}), 6.0)
		elif resume_aux == Metrics.Aux.BREAK:
			# El Break no: ese break ya está gastado, y elegir Break otra vez sería OTRO (el tercero mata). Se dice.
			EventBus.show_message.emit(Loc.fmt(tr("CORE3_RECON_BREAK_FIN"), {"n": Metrics.breaks_used, "max": Metrics.breaks_allowed()}), 6.0)
		Metrics.set_aux(aux)
	resume_aux = -1
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager if is_inside_tree() else null
	if cm != null:
		cm.after_reconnect()
	ended.emit(aux)


func _stop() -> void:
	active = false
	_notice = ""
	left = 0.0
	resume_aux = -1
	Metrics.reconnecting = false


## Texto del HUD / Fonex: «Reconectando 4 s · elige un AUX» y, si aplica, «Te quedaban 31 min de lunch».
func hud_text() -> String:
	if not active:
		return ""
	var t := Loc.fmt(tr("B2_RECON_HUD"), {"s": int(ceil(maxf(left, 0.0)))})
	if resume_aux >= 0:
		t += "  ·  " + Loc.fmt(tr("B2_RECON_RESUME"), {"min": int(ceil(resume_left_s / 60.0)), "aux": Metrics.aux_name(resume_aux), "n": resume_aux + 1})
	return t


## El lunch que la muerte pisó (la ventana «a su hora» ya estaba abierta al morir y no lo tomaste) se corre para que
## la ventana vuelva a durar entera desde que reapareces: hora nueva = ahora + ventana_antes_min.
func _retime_lunch(death_at: float) -> void:
	var taken := bool(GameState.flags.get("p5_lunch_hecho", false)) or Metrics.aux == Metrics.Aux.LUNCH or float(Metrics.time_in_aux.get(Metrics.Aux.LUNCH, 0.0)) > 0.0
	if taken:
		return
	var now := GameState.clock_seconds
	var base := GameState.base_lunch_clock()
	var before := float(DataLoader.bal("lunch/ventana_antes_min", 5.0)) * 60.0
	var after := float(DataLoader.bal("lunch/ventana_despues_min", 15.0)) * 60.0
	var l := GameState.lunch_clock()
	var died := death_at if death_at >= 0.0 else now
	if died < l - before or now >= l + after:
		return  # la muerte no pisó la ventana (antes de abrir o con el checkpoint ya pasada la ventana)
	var want := now + before
	if want > l:
		GameState.flags["lunch_retraso_s"] = want - base

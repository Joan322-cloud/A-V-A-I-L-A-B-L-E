extends Node
## Checkpoints: híbrido gradual (GDD 4.9) + secuencia de muerte (v0.3, PLAN §1 y §8.1).
## Turno normal: checkpoint según la dificultad/turnos.json; muerte = incidencia, el espacio no se reinicia.
## Turno real: sin checkpoints; morir reinicia el turno completo.
## Secuencia: death_requested → death_sequence_started(causa, asesino, detalle) → Screamers.play →
## screamer_finished (o 5 s de tope) → death_shown → [Espacio] respawn() → respawned(tipo).
## Excepción (Joan): Fatiga/colapso (asesino "" o "fatiga") no tiene screamer: DeathAnimations.play_collapse
## → death_animation_finished. Ver uses_screamer().
## Arreglo del bug de colapso (PLAN §1): respawn() es una transacción (restaura todo, fija la Fatiga sin poder
## matar y recién al final pone dying = false), tras respawnear hay una gracia corta, el checkpoint es por
## agente (SaveSlots) y lleva agente y turno, y reset_runtime() limpia todo al volver al menú.

const CAUSES_FILE := "muertes"
const VERSION := 3
## Tope de espera del screamer antes de mostrar la pantalla (v0.3.2: 5,0 → 6,4: la fila más larga, 6,0 s, para que
## la frase gritada termine, + margen; la fusión de Vitzo, dos escenas, espera Screamers.wait_cap: hasta 10,4 s).
const SCREAMER_CAP_S := 6.4
const GRACE_S := 2.0  # tras respawnear no se acepta otra muerte durante este tiempo (segundos escalados)
## v0.3.1 Q1 (C12, F17/F20): gracia de los PERSONAJES tras reaparecer, en segundos reales (escalados por
## Engine.time_scale, como el resto del juego; no corre en pausa). Dentro de ella ningún personaje convoca ni pide
## una muerte por convocatoria o plazo; los plazos empiezan al terminarla. Las muertes por la acción del jugador
## (3.er break, colapso) no tienen esta gracia.
const RESPAWN_GRACE_S := 60.0

var last_checkpoint: Dictionary = {}
var dying: bool = false
var death_cause: String = ""
var death_detail: String = ""
var death_killer: String = ""
var death_visible: bool = false  # ya se mostró "Usuario desconectado" (se puede reconectar)
var deaths_this_shift: int = 0

var _respawning: bool = false
var _seq: int = 0  # cada secuencia de muerte tiene su número; respawn/menú la invalidan
var _screamer_done: bool = false
var _grace_left: float = 0.0
var _killer_override: String = ""
var _restart_used: bool = false  # "Reiniciar contacto" ya usado sobre el checkpoint actual
var _respawn_grace_left: float = 0.0
var last_respawn_cause: String = ""  # causa de la última muerte de la que se reapareció (QaFeedback, F17)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.death_requested.connect(_on_death_requested)
	EventBus.screamer_finished.connect(func(_c: String) -> void: _screamer_done = true)
	EventBus.death_animation_finished.connect(func(_c: String) -> void: _screamer_done = true)


func _process(delta: float) -> void:
	if _grace_left > 0.0 and not get_tree().paused:  # v0.3.2-core4: en pausa no corre (como la gracia de abajo)
		_grace_left -= delta
	if _respawn_grace_left > 0.0 and not get_tree().paused and not dying:
		_respawn_grace_left -= delta


## v0.3.1 Q1 (C12): ¿estamos en los primeros 60 s reales después de reaparecer?
func in_respawn_grace() -> bool:
	return _respawn_grace_left > 0.0


func respawn_grace_left() -> float:
	return maxf(_respawn_grace_left, 0.0)


## v0.3.1 Q1 (F17): corrige contadores del turno en el checkpoint vivo (memoria y disco), para que un respawn
## posterior desde el mismo checkpoint no traiga de vuelta lo que ya se purgó (p. ej. el contacto malo que causó
## la calibración final). Solo toca Discipline.counters del checkpoint.
func patch_checkpoint_counters(values: Dictionary) -> void:
	if last_checkpoint.is_empty() or not matches_current(last_checkpoint):
		return
	var disc: Dictionary = last_checkpoint.get("discipline", {})
	var c: Dictionary = disc.get("counters", {})
	for k in values.keys():
		c[k] = values[k]
	disc["counters"] = c
	last_checkpoint["discipline"] = disc
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)


## v0.3.2-core2: apunta valores en el «extra» del checkpoint vivo (memoria y disco). Lo usa ContactManager para que
## lo que atendiste después del checkpoint (y los huecos que deja) sobreviva a otra muerte desde el mismo checkpoint,
## a «Reiniciar contacto» y a salir y «Continuar».
func patch_checkpoint_extra(values: Dictionary) -> void:
	if values.is_empty() or last_checkpoint.is_empty() or not matches_current(last_checkpoint):
		return
	var e: Dictionary = last_checkpoint.get("extra", {})
	for k in values.keys():
		e[k] = values[k]
	last_checkpoint["extra"] = e
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)


## Lo que guarda elegir un AUX en el menú de la PC (Break, Lunch, Baño): checkpoint «aux» (Fácil) y, si el modo no
## lo acepta, «break» al empezar un Break (Normal T2/T3, Difícil). Lo llama Workstation._pick_aux; el bot humano
## también (v0.3.2-core3: ponía el AUX por debajo y sus breaks no guardaban checkpoint, como sí le pasa a quien juega).
## v0.3.2-core3: un break que no te toca NO guarda checkpoint. El tercer break del turno es una falta que mata, y su
## checkpoint se guardaba con la falta ya hecha (tres breaks gastados, Shero en camino): reaparecías dentro del break
## prohibido, con «Te quedaban 10 min de Break» en pantalla. Ahora la muerte por el tercer break te devuelve al
## checkpoint de antes de la falta. Tampoco guarda el Break que Fácil te devuelve para que lo confirmes.
func on_aux_picked(aux: int) -> void:
	if aux == Metrics.Aux.BREAK and (Metrics.breaks_used > Metrics.breaks_allowed() or Discipline.third_break_confirming() or Metrics.aux != Metrics.Aux.BREAK):
		return
	if aux in [Metrics.Aux.BREAK, Metrics.Aux.LUNCH, Metrics.Aux.BANO]:
		save_checkpoint("aux")
		if aux == Metrics.Aux.BREAK and not accepts("aux"):
			save_checkpoint("break")


## ¿Se puede morir ahora? (no hay otra muerte en curso, ni respawn, ni gracia, y el turno corre)
func can_die() -> bool:
	return not dying and not _respawning and _grace_left <= 0.0 and GameState.running and not GameState.shift_over


## Pide una muerte fijando el asesino (si no, sale de muertes.json/quien).
func request_death(cause: String, detail: String = "", killer: String = "") -> void:
	_killer_override = killer
	EventBus.death_requested.emit(cause, detail)
	_killer_override = ""


# --- Checkpoints -------------------------------------------------------------------------------

## Modo de checkpoint del turno actual: "contacto", "dos_contactos", "login_break_lunch", "login_lunch", "inicio", "ninguno".
## Turno real: ninguno. Fácil: cada contacto. Difícil: login/break/lunch. Normal: lo de turnos.json.
func checkpoint_mode() -> String:
	if GameState.is_real_mode():
		return "ninguno"
	var by_diff := str(Difficulty.value("checkpoints", "turno"))
	if by_diff != "turno" and by_diff != "":
		return by_diff
	return str(GameState.turno_cfg("checkpoints", "contacto"))


## ¿Este tipo de evento guarda checkpoint en el turno actual? kind: contacto, contacto_par, aux, break, lunch, login, inicio.
func accepts(kind: String) -> bool:
	match checkpoint_mode():
		"ninguno":
			return kind == "inicio"
		"contacto":
			return kind in ["contacto", "aux", "break", "lunch", "login", "inicio"]
		"dos_contactos":
			return kind in ["contacto_par", "break", "lunch", "login", "inicio"]
		"login_break_lunch":
			return kind in ["break", "lunch", "login", "inicio"]
		"login_lunch":
			return kind in ["lunch", "login", "inicio"]
		"inicio":
			return kind == "inicio"
	return false


func save_checkpoint(kind: String, extra: Dictionary = {}) -> void:
	if not accepts(kind) or (dying and not _respawning):
		return  # durante el screamer/pantalla no se guarda; durante el respawn sí (checkpoint "inicio")
	# v0.3.2-core2: TODO checkpoint lleva el estado de la cola (qué guiones ya salieron, los huecos de sustituto, el
	# ACD). Antes solo lo llevaban los de «contacto»: en Difícil (login/break/lunch) «Continuar» te volvía a pasar
	# todos los clientes del turno desde el primero. El de «inicio» no: el turno empieza de cero.
	if kind != "inicio" and not extra.has("cm_served"):
		var cm := get_tree().get_first_node_in_group("contact_manager")
		if cm != null and cm.has_method("checkpoint_extra"):
			extra = extra.duplicate()
			extra.merge(cm.call("checkpoint_extra") as Dictionary, false)
	# v0.3.2-core3: un checkpoint guardado nada más reaparecer (en «Reconectando» o dentro de la gracia: p. ej. eliges
	# Break, o en Fácil contestas el primer contacto) no pone a cero la cuenta de muertes seguidas ni devuelve la ayuda.
	var carry_deaths := 0
	var carry_help := false
	if kind != "inicio" and (Metrics.reconnecting or _respawn_grace_left > 0.0) and matches_current(last_checkpoint):
		carry_deaths = int(last_checkpoint.get("muertes", 0))
		carry_help = bool(last_checkpoint.get("ayuda", false))
	last_checkpoint = {
		"version": VERSION,
		"kind": kind,
		"agente": GameState.agent,
		"turno": GameState.turno,
		"modo": GameState.mode,
		"dificultad": Difficulty.id(),
		"game_state": GameState.to_save_dict(),
		"metrics": Metrics.to_save_dict(),
		"fatigue": Fatigue.value,
		"discipline": Discipline.to_save_dict(),
		# v0.3.2-core3: el saldo también vuelve con el checkpoint. Antes el café comprado después del checkpoint se
		# quedaba pagado y su descanso se perdía al reaparecer: repetir el tramo salía más caro que la primera vez.
		"economy": Economy.to_save(),
		"extra": extra,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	if carry_deaths > 0:
		last_checkpoint["muertes"] = carry_deaths
		if carry_help:
			last_checkpoint["ayuda"] = true
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)
	_restart_used = false
	EventBus.checkpoint_saved.emit(kind)


## ¿El checkpoint es de este agente y este turno? (si no, respawn reinicia el turno: nunca cruza partidas)
func matches_current(cp: Dictionary) -> bool:
	if cp.is_empty():
		return false
	var gs: Dictionary = cp.get("game_state", {})
	var a := str(cp.get("agente", gs.get("agent", "")))
	var t := int(cp.get("turno", gs.get("turno", -1)))
	return a == GameState.agent and t == GameState.turno


## Vacía el checkpoint en memoria (inicio de turno). No borra el archivo.
func clear_memory() -> void:
	last_checkpoint = {}


## Reinicio completo del estado de muerte (volver al menú, iniciar turno): sin muerte en curso, sin
## checkpoint en memoria, screamers cortados.
func reset_runtime() -> void:
	_seq += 1
	dying = false
	_respawning = false
	death_visible = false
	death_cause = ""
	death_detail = ""
	death_killer = ""
	_grace_left = 0.0
	_respawn_grace_left = 0.0
	last_respawn_cause = ""
	_screamer_done = false
	_restart_used = false
	deaths_this_shift = 0
	last_checkpoint = {}
	Screamers.stop_all()
	DeathAnimations.stop_all()


# --- Muerte ------------------------------------------------------------------------------------

## Asesino de una causa (muertes.json/quien: shero, rta, vitzo, haime, trainer, fatiga, cliente).
func killer_of(cause_id: String) -> String:
	var c := cause_data(cause_id)
	return str(c.get("quien", ""))


## ¿Esta muerte lleva screamer? Sí si la causa un personaje; no si el asesino es "" o "fatiga" (colapso:
## animación de muerte sin screamer, regla de Joan).
static func uses_screamer(killer: String) -> bool:
	return killer != "" and killer != "fatiga"


func cause_data(cause_id: String) -> Dictionary:
	for c in DataLoader.list(CAUSES_FILE):
		if str(c.get("id", "")) == cause_id:
			return c
	return {}


func _on_death_requested(cause_id: String, detail: String) -> void:
	if not can_die():
		return
	if GameState.in_calm and bool(cause_data(cause_id).get("respeta_calma", false)):
		return  # Shero en reunión: calma garantizada
	# v0.3 P6b: en la Inducción nadie te mata de verdad; solo la muerte "de práctica" que pide el tutorial.
	if GameState.is_tutorial() and not bool(GameState.flags.get("tutorial_permite_muerte", false)):
		GameState.flags["tutorial_muerte_evitada"] = cause_id
		EventBus.show_message.emit(Loc.fmt(tr("TUT_DEATH_BLOCKED"), {"motivo": cause_text(cause_id, detail)}), 4.0)
		return
	# Todo el estado de la muerte cambia junto (PLAN §1: dying y running nunca quedan desparejos).
	dying = true
	death_visible = false
	GameState.running = false
	death_cause = cause_id
	death_detail = detail
	death_killer = _killer_override if _killer_override != "" else killer_of(cause_id)
	_seq += 1
	var seq := _seq
	_screamer_done = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true
	EventBus.death_sequence_started.emit(cause_id, death_killer, detail)
	if uses_screamer(death_killer):
		Screamers.play(death_killer, cause_id, detail)
	else:
		DeathAnimations.play_collapse(cause_id, detail)
	var waited := 0.0
	var cap := SCREAMER_CAP_S
	if uses_screamer(death_killer):
		cap = maxf(minf(Screamers.wait_cap(death_killer, cause_id), Screamers.LONG_CAP + 0.4), SCREAMER_CAP_S)
	while not _screamer_done and waited < cap:
		await get_tree().process_frame
		if seq != _seq:
			return  # respawn o menú durante el screamer: la secuencia se cancela
		# v0.3.2-core4: el tope no corre con el juego en pausa. Checkpoints procesa siempre (también en pausa) y antes
		# una pausa larga en plena muerte agotaba el tope: al volver, la animación se cortaba y salía la pantalla.
		if not get_tree().paused:
			waited += get_process_delta_time()
	if seq != _seq:
		return
	Screamers.stop_all()
	DeathAnimations.stop_all()
	Metrics.register_incident()
	deaths_this_shift += 1
	death_visible = true
	AudioManager.play_sfx("auricular_desconexion")
	EventBus.death_shown.emit(cause_id)
	EventBus.shero_message.emit(Loc.fmt(tr("EZLAK_INCIDENT"), {"motivo": cause_text(cause_id, detail)}), "canal")


## Texto del motivo: "AUX incorrecto (Baño 02:31)" (P7: el detalle va entre paréntesis; con "Motivo: …" delante,
## "Break excedido: 16:00" dejaba dos dos puntos seguidos en la pantalla de muerte).
func cause_text(cause_id: String, detail: String = "") -> String:
	var c := cause_data(cause_id)
	if c.is_empty():
		var key := "CAUSE_" + cause_id.to_upper()  # motivos de WW que no son muertes (correo, kyc)
		return tr(key) if tr(key) != key else cause_id
	var txt := Loc.pick(c.get("motivo", {}))
	if detail.strip_edges() != "":
		return Loc.fmt(txt, {"detalle": detail.strip_edges()})
	# Sin detalle: se quita el hueco con su puntuación ("Break excedido ({detalle})" → "Break excedido", nunca
	# "Break excedido:"; "Training reprobado ({detalle})" → "Training reprobado"; "Available {detalle} %" → "Available").
	for pat in [": {detalle}", " ({detalle})", " {detalle} %", " {detalle}", "{detalle}"]:
		txt = txt.replace(pat, "")
	return txt.strip_edges().trim_suffix(":").trim_suffix(" ·").strip_edges()

## v0.3.2-core3 — Fatiga al reaparecer (antes: checkpoint + 15 con tope 85, y 60 tras un colapso).
## Con la cola llena al repetir un tramo (core2) esas reglas daban un bucle: mueres con Fatiga 66 en el checkpoint,
## reapareces con 81, el tramo sube 35 → colapso → reapareces con 60 → colapso otra vez, y otra. Ahora:
##   · reaparecer NUNCA da más Fatiga que la que guardó el checkpoint;
##   · tras un colapso, o desde la segunda muerte seguida desde el mismo checkpoint (cualquier causa), como mucho
##     fatiga/tope_tras_colapso[Fácil, Normal, Difícil, Turno real]; desde la tercera, ese tope baja
##     fatiga/ayuda_baja_por_muerte por muerte (suelo fatiga/ayuda_suelo): el tramo siempre acaba siendo superable;
##   · la segunda muerte seguida trae además una ayuda, una vez por checkpoint (_death_help).
func respawn_fatigue(cause_id: String, checkpoint_value: float, deaths_here: int = 1) -> float:
	if cause_id != "colapso" and deaths_here < 2:
		return checkpoint_value
	var cap := fatigue_cap()
	if deaths_here > 2:
		cap = maxf(cap - float(DataLoader.bal("fatiga/ayuda_baja_por_muerte", 10.0)) * float(deaths_here - 2), float(DataLoader.bal("fatiga/ayuda_suelo", 10.0)))
	return minf(checkpoint_value, cap)


## Tope de Fatiga al reaparecer tras un colapso, según la dificultad (columna propia para el Turno real).
func fatigue_cap() -> float:
	var caps: Array = DataLoader.bal("fatiga/tope_tras_colapso", [40.0, 40.0, 45.0, 50.0])
	var i := 3 if GameState.is_real_mode() else clampi(Difficulty.level, 0, 2)
	return float(caps[clampi(i, 0, caps.size() - 1)])


## Fatiga con la que vas a reaparecer si mueres ahora por `cause_id` (la pantalla de muerte la dice tras un colapso).
func next_respawn_fatigue(cause_id: String) -> float:
	if Difficulty.restarts_full_shift() or not matches_current(last_checkpoint):
		return float(GameState.turno_cfg("fatiga_inicio", float(DataLoader.bal("fatiga/inicio_t1", 20.0)) + float(DataLoader.bal("fatiga/inicio_por_turno", 5.0)) * float(GameState.turno - 1)))
	return respawn_fatigue(cause_id, float(last_checkpoint.get("fatigue", Fatigue.value)), int(last_checkpoint.get("muertes", 0)) + 1)


## Muertes seguidas desde el checkpoint vivo (un checkpoint nuevo empieza la cuenta de cero).
func deaths_from_checkpoint() -> int:
	return int(last_checkpoint.get("muertes", 0)) if matches_current(last_checkpoint) else 0


## Apunta la muerte en el checkpoint vivo y, a la segunda seguida desde él, da la ayuda (una vez por checkpoint): el
## tópico te atiende otra vez y la máquina te debe un café. Lo dice un aviso en «Reconectando» para que no parezca
## azar. `before` = Fatiga del checkpoint; `after` = la que te queda.
func _death_help(cause: String, streak: int, before: float, after: float) -> void:
	if last_checkpoint.is_empty() or not matches_current(last_checkpoint):
		return
	last_checkpoint["muertes"] = streak
	if after < before - 0.01:
		last_checkpoint["fatigue"] = after  # el checkpoint queda como reapareciste: «Continuar» no devuelve la Fatiga de antes
	var note := ""
	if streak >= 2 and not bool(last_checkpoint.get("ayuda", false)) and not GameState.is_tutorial():
		last_checkpoint["ayuda"] = true
		Discipline.counters["p5_topico_pedidos"] = 0
		var paid := Economy.active()  # desde el T2 el café se paga: este no; en el T1 es el único café del turno, otra vez
		if paid:
			GameState.flags["cafe_cortesia"] = true
		GameState.flags.erase("coffee_used")
		# También en el checkpoint: otra muerte desde él (o «Continuar») no se lleva la ayuda.
		var disc: Dictionary = last_checkpoint.get("discipline", {})
		var counters: Dictionary = disc.get("counters", {})
		counters["p5_topico_pedidos"] = 0
		disc["counters"] = counters
		last_checkpoint["discipline"] = disc
		var gs: Dictionary = last_checkpoint.get("game_state", {})
		var fl: Dictionary = gs.get("flags", {})
		if paid:
			fl["cafe_cortesia"] = true
		fl.erase("coffee_used")
		gs["flags"] = fl
		last_checkpoint["game_state"] = gs
		note = Loc.fmt(tr("CORE3_AYUDA" if TopicoControl.is_open() else "CORE3_AYUDA_T1"), {"n": int(round(after))})
	elif after < before - 0.5:
		note = Loc.fmt(tr("CORE3_FATIGA_COLAPSO" if cause == "colapso" else "CORE3_FATIGA_BAJA"), {"n": int(round(after))})
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)
	if note != "":
		Reconexion.notice(note)


## Reconectar (Espacio en la pantalla de muerte). Transacción: solo hace algo si hay una muerte en curso.
func respawn() -> void:
	if not dying or _respawning:
		return
	_respawning = true
	_seq += 1  # invalida la secuencia (si se llamó antes de terminar el screamer)
	Screamers.stop_all()
	DeathAnimations.stop_all()
	var cause := death_cause
	var kind := ""
	if Difficulty.restarts_full_shift() or not matches_current(last_checkpoint):
		# Turno real (o sin checkpoint válido de este agente/turno): el turno completo otra vez.
		GameState.start_new_shift(GameState.turno, GameState.agent, GameState.mode)
		kind = "casillero"
	else:
		var incidents := Metrics.incidents  # con la de esta muerte ya sumada (se registra al mostrar la pantalla)
		var streak := int(last_checkpoint.get("muertes", 0)) + 1  # muertes seguidas desde este checkpoint
		var cp_fatigue := float(last_checkpoint.get("fatigue", Fatigue.value))
		kind = _restore(last_checkpoint)
		Fatigue.set_value(respawn_fatigue(cause, cp_fatigue, streak))
		_keep_incidents(incidents)
		_fresh_available(cause)
		_death_help(cause, streak, cp_fatigue, Fatigue.value)
	GameState.running = true
	_grace_left = GRACE_S
	_respawn_grace_left = RESPAWN_GRACE_S
	last_respawn_cause = cause
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = false
	EventBus.respawned.emit(kind)
	_sync_place()
	# Calma garantizada del turno (turnos.json/calma_s; T1 = 120 s) × Difficulty "calma".
	GameState.start_calm(float(GameState.turno_cfg("calma_s", DataLoader.bal("calma_garantizada_s", 120.0))))
	death_visible = false
	death_cause = ""
	death_detail = ""
	death_killer = ""
	_respawning = false
	dying = false  # al final: nada de lo de arriba puede encadenar otra muerte


## v0.3.2-core (lo encontró el bot humano, T3 en Difícil): el checkpoint guarda DÓNDE estabas (el del lunch se guarda
## en la cafetería: piso -1, de pie o sentado a una mesa) y al reaparecer vuelves sentado a C-14, en el piso 2. Pero si
## habías muerto en el piso 2 el piso no se recarga, y si habías muerto sentado en C-14 nadie te vuelve a sentar: no
## sale ningún aviso de «cambió de piso» ni de «se sentó», y GameState se quedaba con lo del checkpoint. Para el juego
## estabas en el -1 y de pie aunque estuvieras en tu silla:
##   · lo que pregunta «¿llegaste?» en el piso 2 (el evento de Rasec, la sala de calibración) respondía que no: te
##     mataban por no ir estando ahí;
##   · sin «sentado en C-14» no se podía aceptar ningún contacto ([Espacio] no hacía nada): perdidas, WW y otra muerte,
##     desde el mismo checkpoint, hasta que te levantaras y te volvieras a sentar.
## Cualquier muerte en tu puesto entre el lunch y el segundo break caía aquí. Lo que vale es dónde está el jugador.
func _sync_place() -> void:
	var b := get_tree().get_first_node_in_group("building")
	if b != null and b.get("current_floor") != null:
		var real := int(b.get("current_floor"))
		if real != GameState.current_floor:
			GameState.current_floor = real
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		var seat := p.seat_id if p.seated else ""
		if seat != GameState.seated_at:
			GameState.seated_at = seat
			GameState.call("_refresh_clock_mode")


## v0.3.2-core: «Incidencia registrada»… y el respawn la borraba: las métricas volvían al checkpoint, que es anterior
## a la muerte, y el resumen del turno decía «Incidencias: 0» hubieras muerto las veces que fuera. La cuenta de
## incidencias no vuelve atrás: se conserva al reaparecer y se apunta en el checkpoint vivo (memoria y disco), para
## que otra muerte desde el mismo checkpoint, «Reiniciar contacto» o «Continuar» no la pierdan.
func _keep_incidents(n: int) -> void:
	if n <= Metrics.incidents:
		return
	Metrics.incidents = n
	if last_checkpoint.is_empty() or not matches_current(last_checkpoint):
		return
	var m: Dictionary = last_checkpoint.get("metrics", {})
	m["incidents"] = n
	last_checkpoint["metrics"] = m
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)


## v0.3.2-core: morir por Available bajo ya no te condena a morir en cada lista que quede. El Available % es
## acumulado (Available / (Available + BO) de todo el turno) y el checkpoint lo trae tal cual: con 20 % a las 03:00
## es imposible llegar al 70 % para la lista de las 04:30 aunque no vuelvas a tocar BO, y la cuenta de listas malas
## no se borra en el turno, así que cada lista siguiente era otra persecución. Ahora, al reaparecer de esa muerte,
## el Available se cuenta de nuevo desde cero (y no se evalúa hasta tener otra vez 30 min productivos); la cuenta de
## listas malas sigue: quien se porta bien se salva, quien sigue igual vuelve a morir. Se corrige también el
## checkpoint vivo (memoria y disco) para que otro respawn desde él no traiga el porcentaje viejo.
func _fresh_available(cause: String) -> void:
	if cause != "available_bajo":
		return
	Metrics.restart_available()
	GameState.flags["available_reinicio"] = true
	if last_checkpoint.is_empty() or not matches_current(last_checkpoint):
		return
	var m: Dictionary = last_checkpoint.get("metrics", {})
	var t: Dictionary = (m.get("time_in_aux", {}) as Dictionary).duplicate(true)
	for k in t.keys():
		if int(k) == Metrics.Aux.AVAILABLE or int(k) == Metrics.Aux.BO:
			t[k] = 0.0
	m["time_in_aux"] = t
	last_checkpoint["metrics"] = m
	SaveSlots.write_checkpoint(GameState.agent, last_checkpoint)


## Pausa → "Reiniciar contacto": vuelve al último checkpoint sin incidencia y sin Fatiga extra.
## Una sola vez por checkpoint (pulsarlo dos veces no hace dos respawns; el siguiente checkpoint lo
## vuelve a permitir). Devuelve true si lo hizo.
func restart_contact() -> bool:
	if not can_restart_contact():
		return false
	_respawning = true
	var fat := Fatigue.value
	var money := Economy.to_save()  # v0.3.2-core3: aquí el dinero no vuelve atrás (la Fatiga tampoco): no devuelve lo comprado
	var kind := _restore(last_checkpoint)
	Economy.from_save(money)
	Fatigue.set_value(fat)
	_restart_used = true
	GameState.running = true
	_grace_left = GRACE_S
	EventBus.respawned.emit(kind)
	_respawning = false
	return true


func can_restart_contact() -> bool:
	return not dying and not _respawning and not _restart_used and GameState.running and not GameState.is_real_mode() and matches_current(last_checkpoint) and not _in_calibration() and not Pursuit.is_hunting()


## v0.3.2-core4: durante una calibración de Haime no hay «Reiniciar contacto»: volvía al checkpoint sin incidencia y la
## sesión (también la fatal) se quedaba sin dar. La calibración no se esquiva ni se reinicia. Tampoco con alguien
## persiguiéndote (Shero, el Perrito, el Trainer, Vitzo): reiniciar el contacto cortaba la persecución en seco.
func _in_calibration() -> bool:
	var hub := PersonajesP5.get_hub(get_tree()) if is_inside_tree() else null
	return hub != null and hub.qa != null and hub.qa.state == QaFeedback.State.SESION


## Restaura el estado del checkpoint (sin tocar running ni dying). Devuelve su tipo.
func _restore(cp: Dictionary) -> String:
	GameState.from_save_dict(cp.get("game_state", {}))
	Metrics.from_save_dict(cp.get("metrics", {}))
	Discipline.from_save_dict(cp.get("discipline", {}))
	if cp.has("economy"):
		Economy.from_save(cp.get("economy", {}))
	return str(cp.get("kind", "contacto"))


## "Continuar": adopta un checkpoint leído del disco como el del turno en curso (Main ya restauró el estado).
func continue_from(cp: Dictionary) -> void:
	last_checkpoint = cp
	_restore(cp)
	Fatigue.set_value(float(cp.get("fatigue", 20.0)))
	SaveSlots.write_checkpoint(GameState.agent, cp)
	_settle_after_continue.call_deferred()  # cuando Main ya armó el mundo y puso al jugador


## v0.3.2-core: «Continuar» te dejaba DE PIE junto a tu PC mientras el juego creía que seguías sentado en C-14 (el
## reloj corría como sentado y se podía aceptar un contacto sin estar en la silla). Si el checkpoint se guardó sentado
## en tu puesto, retomas sentado; y en cualquier caso lo que el juego cree (piso, silla) es donde está el jugador.
func _settle_after_continue() -> void:
	if not is_inside_tree() or not GameState.running:
		return
	var main := get_tree().current_scene
	if GameState.logged_in and GameState.seated_at == "C-14" and GameState.current_floor == 2 and not GameState.is_tutorial() and main != null and main.has_method("seat_at_own_pc"):
		main.call("seat_at_own_pc", false)
	_sync_place()


# --- Archivo del checkpoint (partida del agente activo) -----------------------------------------

func has_save() -> bool:
	return SaveSlots.has_checkpoint(SaveSlots.current)


## Lee el checkpoint del agente activo (migrando el enum de AUX si es de la v0.2). {} si no hay.
func read_save(agent: String = "") -> Dictionary:
	var cp := SaveSlots.read_checkpoint(SaveSlots.current if agent == "" else agent)
	if cp.is_empty():
		return {}
	cp["metrics"] = Metrics.migrate_save_dict(cp.get("metrics", {}))
	return cp


## Compatibilidad v0.2: carga el checkpoint del agente activo en memoria.
func load_save() -> bool:
	var cp := read_save()
	if cp.is_empty():
		return false
	last_checkpoint = cp
	return true


func delete_save() -> void:
	SaveSlots.delete_checkpoint(GameState.agent)
	last_checkpoint.clear()

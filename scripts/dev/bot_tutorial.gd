## Sin class_name: lo cargan main.gd (`-- --bot-tutorial`) y los escenarios de P6b con load().
extends Node
## Bot del Training (antes «Inducción»; v0.3 P6b, v0.3.2: sesión en la PC de training T-01 del piso 1, firma del
## contrato con ContractUI y corte al presente): hace cada paso de cada módulo como un jugador (sentarse con la silla, Fonex,
## menú AUX, aceptar, elegir respuestas del árbol, Kardex, Correo, Identa, Portal Vitzo, Ezlaki, reaccionar a Vitzo,
## Rooms, salir de la sala, el ascensor, dormir en un puff, Reconectar, el Manual en la pausa). `skip` = ids de
## módulos que salta con [F8] (para probar que todo se puede saltar). Termina con `done(report)`.
## Uso: `godot --headless --path game -- --bot-tutorial [--saltar id,id]` o desde un escenario: start(main, mods, skip).

signal done(report: Dictionary)

var main: Node = null
var tut: Node = null
var skip: Array = []
var answer_yes: bool = true  # el screamer de práctica: sí lo mira (prueba la limpieza de la cámara)
var report: Dictionary = {"pasos": 0, "modulos": {}, "errores": [], "muertes_evitadas": 0, "tiempo_real_s": 0.0}
var log_steps: bool = true
var _step_key: String = ""
var _step_t: float = 0.0
var _act_t: float = 0.0
var _path: Array = []
var _path_for: String = ""
var _path_i: int = 0
var _t0: int = 0
var _finished: bool = false
var timeout_s: float = 900.0  # tope por si un paso se traba (segundos reales escalados)
var stop_at: String = ""  # "modulo/paso": el bot se queda quieto al llegar ahí (capturas)
var stopped: bool = false
var _total: float = 0.0
var _cut_t: float = 0.0
var read_contract: bool = true  # el bot baja hasta la letra chica antes de firmar
var read_delay: float = 0.4  # segundos antes de pulsar «Continuar» (los videos usan más, para que se lea)
var sign_delay: float = 0.4  # segundos con la tablet abierta antes de firmar
var skip_cut: bool = true  # apura el corte al presente (los videos lo dejan correr entero)
## v0.3.2 rehecho: las líneas del Trainer duran un instante (pruebas). false = el bot escucha cada línea entera, como
## un jugador, y recién actúa cuando el Trainer calla (la corrida larga del timeline y los videos).
var fast_speech: bool = true
var think_delay: float = 1.5  # con fast_speech = false: segundos que «piensa» cada respuesta de una llamada o chat
var _think_t: float = 0.0
var video: bool = false  # grabaciones y storyboards: encuadres pensados para verse (la mesa del café)
var quiz_wrong: Array = []  # ids de módulo en los que el bot contesta mal el mini-check (prueba el ánimo del Trainer)


func start(p_main: Node, mods: Array = [], p_skip: Array = []) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue con la pausa abierta (paso del Manual)
	skip = p_skip
	_t0 = Time.get_ticks_msec()
	tut = main.call("_start_tutorial", mods)
	if tut == null:
		report["errores"].append("no hay scripts/core/tutorial.gd")
		_finish()
		return
	_hook()


## v0.3.2: se engancha a un Training ya arrancado (el obligatorio de una partida nueva, desde el menú).
func attach(p_main: Node, p_tut: Node, p_skip: Array = []) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS
	skip = p_skip
	_t0 = Time.get_ticks_msec()
	tut = p_tut
	_hook()


func _hook() -> void:
	if tut.get("voice") != null:
		tut.get("voice").set("fast", fast_speech)
	tut.connect("module_finished", func(id: String, st: String) -> void:
		report["modulos"][id] = st
		if log_steps:
			print("[bot-tut] módulo %s: %s" % [id, st]))
	tut.connect("all_finished", func(_r: Dictionary) -> void: _on_all())
	EventBus.show_message.connect(func(t: String, _s: float) -> void:
		if t.begins_with(tr("TUT_DEATH_BLOCKED").get_slice("«", 0).strip_edges()):
			report["muertes_evitadas"] = int(report["muertes_evitadas"]) + 1)


func _on_all() -> void:
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(tut):
		tut.call("press_continue")  # "[T] Volver al menú"
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	report["tiempo_real_s"] = (Time.get_ticks_msec() - _t0) / 1000.0
	done.emit(report)


func _process(delta: float) -> void:
	if _finished or tut == null or not is_instance_valid(tut) or get_tree().paused and not _manual_step():
		return
	_total += delta
	if _total > timeout_s:
		report["errores"].append("tope de tiempo en %s/%s" % [str(tut.call("module_id")), str(tut.call("step").get("id", ""))])
		_finish()
		return
	if get_tree().root.get_node_or_null("CortePresente") != null:
		_cut_t += delta
		if skip_cut and _cut_t > 0.6:
			tut.call("bot_skip_cut")  # el corte al presente se apura como con [Espacio]
		return
	if bool(tut.get("finished")):
		return
	var s: Dictionary = tut.call("step")
	var mid := str(tut.call("module_id"))
	var key := mid + "/" + str(s.get("id", ""))
	if key != _step_key:
		_step_key = key
		_step_t = 0.0
		_act_t = 0.0
		report["pasos"] = int(report["pasos"]) + 1
		if log_steps:
			print("[bot-tut] %s · %s %s" % [key, str(s.get("tipo", "")), str(s.get("cond", ""))])
	if stop_at != "" and key == stop_at:
		stopped = true
		return
	_step_t += delta
	if skip.has(mid):
		if _step_t > 0.3:
			tut.call("skip_module")
		return
	_act_t -= delta
	if _act_t > 0.0:
		return
	_act_t = 0.25  # un "clic" cada cuarto de segundo, como una persona apurada
	if not fast_speech and bool(tut.call("is_speaking")):
		return  # escucha al Trainer hasta el final (nunca lo corta con [T])
	match str(s.get("tipo", "")):
		"accion":
			if str(s.get("accion", "")) == "contrato" and _step_t > sign_delay:
				tut.call("bot_sign", read_contract, sign_delay > 1.0)
		"leer":
			if _step_t > read_delay:
				tut.call("press_continue")
		"elegir":
			if _step_t > 0.4:
				tut.call("answer", answer_yes)
		"pregunta":
			if int(tut.get("_choice")) < 0:
				if _step_t > read_delay:
					var ok := int(s.get("correcta", 0))
					tut.call("choose", (ok + 1) % 3 if quiz_wrong.has(mid) else ok)
			elif _step_t > read_delay:
				tut.call("press_continue")
		"esperar":
			_act(str(s.get("cond", "")))


func _manual_step() -> bool:
	return tut != null and is_instance_valid(tut) and str(tut.call("waiting_for")) == "manual_abierto"


# --- un paso como jugador ----------------------------------------------------------------------------

func _ws() -> Control:
	return get_tree().get_first_node_in_group("workstation") as Control


func _cm() -> ContactManager:
	return get_tree().get_first_node_in_group("contact_manager") as ContactManager


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func _hub() -> EzlakHub:
	return EzlakHub.get_hub(get_tree())


func _home_seat() -> String:
	return str(tut.get("home_seat")) if tut != null and is_instance_valid(tut) else "C-14"


func _home_floor() -> int:
	return int(tut.get("home_floor")) if tut != null and is_instance_valid(tut) else 2


func _seat() -> WorldObjects.Seat:
	var b := _building()
	if b == null or b.current_floor != _home_floor():
		return null
	return (b.floor_node as FloorBase).seat_by_id(_home_seat())


func _sit() -> void:
	var b := _building()
	if b.current_floor != _home_floor():
		b.go_to_floor(_home_floor(), TrainingRoom.ENTRY if _home_floor() == 1 else "pc")
		return
	var seat := _seat()
	var p := _player()
	if seat != null and not p.seated:
		p.teleport(seat.global_position + seat.global_transform.basis.z * 0.9, seat.global_rotation_degrees.y)
		seat.interact(p)


func _act(cond: String) -> void:
	var cm := _cm()
	var ws := _ws()
	var p := _player()
	if cond.begins_with("aux:"):
		if GameState.seated_at == "":
			_sit()
			return
		ws.call("_pick_aux", int(Metrics.Aux.get(cond.substr(4), 0)))
		return
	if cond.begins_with("quick_reply:"):
		var id := cond.substr(12)
		for m in _hub().messages("dm:shero"):
			if (m.get("quick_replies", []) as Array).has(id) and not bool(m.get("respondido", false)):
				_hub().quick_reply("dm:shero", id, m)
				return
		return
	if cond.begins_with("ezlak_canal:"):
		ws.get("ezlak").call("open_channel", cond.substr(12))
		return
	if cond.begins_with("piso:"):
		var n := int(cond.substr(5))
		if p.seated:
			p.stand_up()
		if _building().current_floor != n:
			_building().go_to_floor(n, "ascensor")
		return
	match cond:
		"sentado", "sentado_available":
			if GameState.seated_at != _home_seat():
				_sit()
			elif cond == "sentado_available" and Metrics.aux != Metrics.Aux.AVAILABLE:
				ws.call("_pick_aux", Metrics.Aux.AVAILABLE)
		"logueado":
			if GameState.seated_at == "":
				_sit()
			else:
				ws.call("press_accept")
		"aux_menu":
			ws.call("_toggle_aux_menu", true)
		"contacto_activo":
			if cm.phase == ContactManager.Phase.OFFERING:
				if GameState.seated_at == "":
					_sit()
				else:
					ws.call("press_accept")
		"contacto_fin", "caso_cerrado", "kyc_decidido":
			_work(cm)
		"kardex", "destinatario_ok", "plantilla_ok", "campos_ok", "enviado", "enviado_ok", "tipificado", "portal_buscar":
			_work(cm)
		"reaccion":
			var m := _hub().pending_actionable()
			if not m.is_empty():
				_hub().react(m)
		"rooms":
			if _hub().rooms_pending:
				_hub().join_rooms()
		"ack":
			if Metrics.ack_pending:
				ws.call("press_accept")
		"fuera_sala":
			if p.seated:
				p.stand_up()
			else:
				var m := _building().floor_node.find_child(TrainingRoom.OUTSIDE, true, false) as Node3D
				if m == null:
					m = _building().floor_node.find_child("ascensor", true, false) as Node3D
				if m != null:
					p.teleport(m.global_position, m.rotation_degrees.y)
		"rub_eyes":
			Fatigue.rub_eyes()
		"cafe":
			if p.seated:
				p.stand_up()
				return
			var mk := _building().floor_node.find_child(TrainingRoom.COFFEE_MARK, true, false) as Node3D
			var table := _building().floor_node.find_child("MesaCafe", true, false) as Interactable
			if mk != null and table != null:
				# De pie en la marca, mirando la isla del café (al norte), con la promoción alrededor.
				if p.global_position.distance_to(mk.global_position) > 0.6:
					p.teleport(mk.global_position, mk.rotation_degrees.y)
					if video:
						(p.get("head") as Node3D).rotation.x = -0.12
				table.interact(p)
		"perdido_o_atendido":
			pass  # la deja sonar: el contacto se pierde solo
		"comodin_abierto":
			if p.seated:
				p.stand_up()
			else:
				Comodin.open()  # lo mismo que mantener [C]
		"comodin_hecho":
			if Comodin.phase == "aux":
				Comodin.choose_aux(Metrics.Aux.AVAILABLE)
			elif Comodin.phase == "who":
				Comodin.choose_coworker(0)
			elif Comodin.phase == "" and not bool(tut.get("_comodin_done")):
				Comodin.open()
		"dormido":
			if p.seated:
				p.stand_up()
			for s in get_tree().get_nodes_in_group("sleep_spots"):
				if str(s.get("spot_id")).begins_with("puff") or str(s.get("spot_id")).begins_with("sofa"):
					p.teleport((s as Node3D).global_position + Vector3(0, 0, 1.0), 0.0)
					(s as Interactable).interact(p)
					return
		"despierto":
			if _step_t > 1.5:
				for s in get_tree().get_nodes_in_group("sleep_spots"):
					if SleepSpot.sleeping_spot() == str(s.get("spot_id")):
						(s as Interactable).interact(p)
						return
		"reconectado":
			if Checkpoints.death_visible:
				main.get_node("UI/DeathScreen").call("_reconnect")
		"manual_abierto":
			var pm := main.get("pause_menu") as Control
			if not get_tree().paused:
				pm.call("toggle")
			else:
				pm.call("open_manual")
				await get_tree().process_frame
				var man := pm.find_child("AgentManual", true, false)
				if man != null:
					man.emit_signal("closed")
				pm.call("toggle")


## Correo / KYC / Vitzo / árbol: un paso por "clic", lo correcto (como el bot listo).
func _work(cm: ContactManager) -> void:
	if cm.phase == ContactManager.Phase.OFFERING:
		_ws().call("press_accept")
		return
	if cm.phase != ContactManager.Phase.ACTIVE:
		return
	if cm.tree != null:
		if not fast_speech:  # como un jugador: deja hablar al cliente y piensa un momento antes de elegir
			if VoiceDirector.busy(VoiceDirector.P.CLIENTE):
				_think_t = 0.0
				return
			_think_t += 0.25
			if _think_t < think_delay:
				return
			_think_t = 0.0
		var id := str(cm.current.get("id", ""))
		if _path_for != id:
			_path_for = id
			_path = DialogTree.best_path(cm.current)
			_path_i = 0
		if _path_i < _path.size():
			cm.choose(int(_path[_path_i]["i"]))
			_path_i += 1
		else:
			cm.choose(0)
		return
	var k := cm.case
	if k == null:
		return
	var c := cm.current
	if k.is_kyc():
		if _step_t > 0.8:
			cm.kyc_decide(str(c.get("correcto", "rechazar")))
		return
	var corr: Dictionary = c.get("correcto", {})
	if not k.kardex_done:
		cm.kardex_lookup(k.tx())
		return
	for pa in corr.get("portal", []):
		if not k.portal_done.has(str(pa)):
			if str(pa) == "buscar":
				cm.portal_search(k.tx())
			return
	var dest := str(corr.get("destinatario", ""))
	if dest != "" and k.sent.is_empty():
		if k.recipient != dest:
			cm.set_recipient(dest)
			return
		if k.template != str(corr.get("plantilla", "")):
			cm.set_template(str(corr.get("plantilla", "")))
			return
		for f in CasoBO.FIELDS:
			var want := str((corr.get("campos", {}) as Dictionary).get(f, ""))
			if str(k.fields.get(f, "")) != want:
				cm.set_field(f, want)
				return
		cm.send_email()
		return
	if k.typification != str(corr.get("tipificacion", "")):
		cm.set_typification(str(corr.get("tipificacion", "")))
		return
	if str(tut.call("waiting_for")) == "caso_cerrado":
		cm.close_case()

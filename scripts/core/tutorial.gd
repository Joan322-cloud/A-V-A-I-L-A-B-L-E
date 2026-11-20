class_name Tutorial
extends Node
## v0.3.2 · TRAINING (antes «Inducción»; docs/AVAILABLE_trama_semana §1.3-1.4): es un RECUERDO jugable del día en que
## el agente entró (Flashback: fecha de la biblia, torre nueva y limpia, agente contento, tonos cálidos), en la sala de
## training principal del piso 1 (TrainingRoom), con la PC de training T-01 y el Trainer AMABLE (TrainerAmable) que
## presenta cada módulo y camina hasta tu mesa en la práctica. Termina con la FIRMA DEL CONTRATO (ContractUI, módulo
## «contrato», que no se puede saltar) y el corte al presente (Flashback.present_cut). `first_time` = el Training
## obligatorio de una partida nueva: al terminar, Main._after_training() abre el Lunes; si no, vuelve al menú.
## Lo de abajo (v0.3 P6b) sigue valiendo salvo que la sesión vive en T-01 (piso 1) y no en C-14.
## Inducción (v0.3 P6b, PLAN §2 #84): Turno 0, Fácil, 10 módulos que se pueden saltar uno por uno (~12 min reales en
## total). Todo pasa en el mundo de verdad: el jugador se sienta en C-14, inicia sesión, cambia de AUX, atiende una
## llamada y un chat (árboles), resuelve un correo paso a paso con el reloj de 10 min, un KYC en Identa, un caso de
## Vitzo por el portal, responde en Ezlaki, reacciona al recordatorio de Vitzo, entra a Ezlaki Rooms, sale de la sala
## en Break, da Ack a un WW de práctica, baja al -1 a dormir y ve un colapso de práctica con su Reconectar.
## Lo guían la voz del sistema (panel + voces/sistema/tut_*) y un compañero por Ezlaki (DM).
## Sin muertes reales: Checkpoints ignora cualquier muerte en la Inducción (aviso "aquí habrías muerto") salvo la de
## práctica del colapso; la disciplina está congelada (motivo "tutorial"), el reloj va a 4x (salvo en los módulos de
## correo, con su reloj de caso de verdad) y el guardado vive aparte (SaveSlots contexto "induccion").
## Datos: data/tutorial.json (módulos, pasos, casos del tutorial, transacciones). Progreso de módulos en
## <SaveSlots.root>/_induccion/modulos.json ({id: "hecho" | "saltado"}).
## Teclas: [T] continuar / sí · [N] no · [F8] saltar módulo. También con clic en el panel.
## API para el bot y los escenarios: begin(main, modules) · press_continue() · answer(yes) · skip_module() ·
##   step() · module_id() · waiting_for() · finished · results · señales step_started / module_finished / all_finished.

signal step_started(module_id: String, step_id: String)
signal module_finished(module_id: String, status: String)
signal all_finished(results: Dictionary)

const DATA := "tutorial"
const PROGRESS_FILE := "modulos.json"
const FREEZE_REASON := "tutorial"
const CLOCK_KEY := "tutorial"
const C14 := "C-14"  # compatibilidad (v0.3): la sesión del Training vive en home_seat (T-01, piso 1)
const CONTRACT_MODULE := "contrato"

var main: Node = null
var queue: Array[String] = []
var results: Dictionary = {}  # id -> "hecho" | "saltado"
var finished: bool = false
var running_module: String = ""
var current_step: Dictionary = {}
var step_index: int = 0
var step_count: int = 0

var _continue: bool = false
var _answer: int = -1  # elegir: 1 sí, 0 no
var _skip: bool = false
var _ev: Dictionary = {}  # eventos vistos durante el paso (contacto_fin, qr:ok, ack, ...)
var _last_outcome: Dictionary = {}
var _offered_id: String = ""
var _step_t: float = 0.0
var _clock_mode: String = CLOCK_KEY
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _title: Label = null
var _body: Label = null
var _hint: Label = null
var _target_lbl: Label = null
var _keys: Label = null
var _btn_next: Button = null
var _btn_yes: Button = null
var _btn_no: Button = null
var _btn_skip: Button = null
var _beacon: Node3D = null
var _target: String = ""
var _beacon_t: float = 0.0
## v0.3.2 (feedback de Joan sobre la beta): el panel y lo que señala son de TrainingCoach (scripts/ui/training_coach.gd):
## resalta, avisa cada paso nuevo, nunca tapa lo que hay que usar (con la PC acercada es una franja arriba y la PC se
## acomoda debajo) y sus botones van en un pie fijo. Aquí solo se escriben los textos (_title, _body, _hint…).
var coach: TrainingCoach = null
var _cue_key: String = ""  # módulo/paso del último aviso de paso nuevo (cambiar de idioma no vuelve a avisar)
## Pruebas (v032_fbui): si está puesto, cada paso espera aquí con el panel ya escrito —step_gate(módulo, paso, fase)—
## para que la prueba lo mida en todos los tamaños de vista; fase = "inicio" | "respondido" (mini-check contestado).
var step_gate: Callable = Callable()
## v0.3.2 · Training (recuerdo)
var home_seat: String = TrainingRoom.SEAT
var home_floor: int = 1
var first_time: bool = false  # Training obligatorio de una partida nueva (al terminar se abre el Lunes)
var trainer: TrainerAmable = null
var contract: ContractUI = null
var contract_read: bool = false
var contract_signed: bool = false
var present_cut_shown: bool = false
var _in_aula: bool = true
var _fb_layer: CanvasLayer = null
var _card_shown: bool = false
var _lang: String = ""  # idioma con el que se escribió el panel (si cambia en Opciones, se reescribe)
var _modules_run: int = 0  # módulos ya empezados en esta sesión del Training (el primero nunca funde a negro)
## v0.3.2 rehecho (Joan: «estás cruzando todos los diálogos a la vez»): todo lo que se dice en el Training pasa por
## TrainingVoice, una línea a la vez, y graba la línea de tiempo de las voces. `quiz` = {módulo: acertó el mini-check}.
var voice: TrainingVoice = null
var stage: TrainingStage = null  # dirección de escena: la promoción y el Trainer en el aula (TrainingStage)
var quiz: Dictionary = {}
var photo_taken: bool = false
var signature: Array = []  # tu firma: [[x0, y0, x1, y1, …], …] de 0 a 1 (ancho) y de 0 a `aspecto` (alto) · ver _keep_signature
var photo_image: Image = null
var timeline_path: String = ""  # si no está vacío, al terminar escribe ahí la línea de tiempo de las voces
var _choice: int = -1
var _opts_box: BoxContainer = null
## Lo que elegiste en los pasos «elegir» con `guarda` (p. ej. {"foto": true} = sonreíste en la foto de promoción).
## Con la foto, pasa a la partida al firmar (Main._after_training → progreso «recuerdo») para los ecos de la semana.
var choices: Dictionary = {}
const MUSIC := "training_calida"


# --- datos y progreso -------------------------------------------------------------------------------

static func data() -> Dictionary:
	return DataLoader.dict(DATA)


## Un texto {es, en} de data/tutorial.json con las teclas que nombra entre corchetes puestas al día: las que el
## jugador asignó en Opciones → Controles (v0.3.2-final, pedido del paquete core: 49 textos nombran teclas). Con una
## clave que empieza por «TUT_» el ayudante deja quieta [T], que en el Training es su tecla propia (continuar / sí;
## [N] = no), fija en este archivo, y no la del micrófono; las demás ([E], [Q], [Espacio], [H], [C], [R], [Tab]) siguen
## el remapeo. Con las teclas de fábrica devuelve el texto tal cual.
static func _txt(d: Variant) -> String:
	return Controls.hint_for_key("TUT_JSON", Loc.pick(d), Loc.language)


static func modules() -> Array:
	return data().get("modulos", [])


static func module_ids() -> Array[String]:
	var out: Array[String] = []
	for m in modules():
		out.append(str(m.get("id", "")))
	return out


static func module_by_id(id: String) -> Dictionary:
	for m in modules():
		if str(m.get("id", "")) == id:
			return m
	return {}


static func case_by_id(id: String) -> Dictionary:
	for c in data().get("casos", []):
		if str(c.get("id", "")) == id:
			return (c as Dictionary).duplicate(true)
	return {}


static func progress_path() -> String:
	return SaveSlots.root + SaveSlots.TUTORIAL_DIR + PROGRESS_FILE


## {id: "hecho" | "saltado"} de la Inducción (todas las partidas comparten la misma inducción).
static func load_progress() -> Dictionary:
	var p := progress_path()
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		return ((parsed as Dictionary).get("modulos", {}) as Dictionary)
	return {}


static func save_progress(mods: Dictionary) -> void:
	var p := progress_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": 1, "modulos": mods, "actualizado": Time.get_datetime_string_from_system()}, "\t"))


static func reset_progress() -> void:
	var p := progress_path()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Pendientes en orden (lo que hace "Hacer la inducción").
static func pending_modules() -> Array[String]:
	var done := load_progress()
	var out: Array[String] = []
	for id in module_ids():
		if str(done.get(id, "")) != "hecho":  # saltado sigue pendiente
			out.append(id)
	return out if not out.is_empty() else module_ids()


# --- el Training obligatorio de una partida nueva: se puede dejar a medias y seguir (por agente) ---------------

static func first_path(agent: String) -> String:
	return SaveSlots.root + SaveSlots.TUTORIAL_DIR + "primer_%s.json" % agent.to_lower()


## Lo que ese agente ya hizo de SU Training obligatorio: {modulos: {id: hecho|saltado}, choices, quiz}. Vacío = no empezó.
static func first_state(agent: String) -> Dictionary:
	var p := first_path(agent)
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}


## Los módulos que le faltan a ese agente, en orden (la firma siempre es el último). Sin nada guardado: los 14.
static func first_pending(agent: String) -> Array[String]:
	var done: Dictionary = first_state(agent).get("modulos", {})
	var out: Array[String] = []
	for id in module_ids():
		if id == CONTRACT_MODULE or not done.has(id):
			out.append(id)
	return out


static func clear_first(agent: String) -> void:
	var p := first_path(agent)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Al reanudar: lo que ya elegiste (contaste por qué entraste, ayudaste a Nayra…) y tus mini-checks siguen contando.
func resume_first() -> void:
	var st := first_state(GameState.agent)
	for k in (st.get("choices", {}) as Dictionary).keys():
		choices[str(k)] = bool(st["choices"][k])
	for k in (st.get("quiz", {}) as Dictionary).keys():
		quiz[str(k)] = bool(st["quiz"][k])
	_first_done = (st.get("modulos", {}) as Dictionary).duplicate()


var _first_done: Dictionary = {}


func _save_first(id: String, status: String) -> void:
	_first_done[id] = status
	var p := first_path(GameState.agent)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "agente": GameState.agent, "modulos": _first_done, "choices": choices, "quiz": quiz}, "\t"))


# --- arranque --------------------------------------------------------------------------------------

## Main._start_tutorial ya arrancó el Turno 0 en el contexto "induccion". `mods` vacío = los pendientes.
func begin(p_main: Node, mods: Array = []) -> void:
	main = p_main
	queue.clear()
	for m in (mods if not mods.is_empty() else pending_modules()):
		if not module_by_id(str(m)).is_empty():
			queue.append(str(m))
	if queue.is_empty():
		queue = module_ids()
	results = load_progress().duplicate()
	voice = TrainingVoice.new()
	voice.name = "TrainingVoice"
	add_child(voice)
	stage = TrainingStage.new()
	stage.name = "TrainingStage"
	stage.tut = self
	add_child(stage)
	voice.stage = stage
	_inject_data()
	_build_ui()
	_flashback_begin()
	_connect()
	_add_actions()
	_comodin_practice(false)  # en todo el recuerdo el comodín llama a tu promoción, no a los agentes de hoy
	Difficulty.set_level(Difficulty.Level.FACIL)
	_freeze()
	_run.call_deferred()


## Las transacciones y el portal del tutorial entran en el caché de casos_bo (Kardex y el Portal los leen de ahí).
func _inject_data() -> void:
	var bo := DataLoader.dict("casos_bo")
	var tx: Dictionary = bo.get("transacciones", {})
	for k in (data().get("transacciones", {}) as Dictionary).keys():
		tx[k] = data()["transacciones"][k]
	var portal: Dictionary = bo.get("portal", {})
	for k in (data().get("portal", {}) as Dictionary).keys():
		portal[k] = data()["portal"][k]


func _connect() -> void:
	EventBus.contact_outcome.connect(_on_outcome)
	EventBus.ezlak_quick_reply.connect(func(_c: String, id: String) -> void: _ev["qr:" + id] = true)
	EventBus.vitzo_reacted.connect(func() -> void: _ev["reaccion"] = true)
	EventBus.coaching_joined.connect(func() -> void: _ev["rooms"] = true)
	EventBus.ack_given.connect(func() -> void: _ev["ack"] = true)
	EventBus.ack_expired.connect(_on_ack_expired)
	EventBus.player_blinked.connect(func() -> void: _ev["rub"] = true)
	EventBus.player_slept.connect(func(_s: String) -> void: _ev["dormido"] = true)
	EventBus.player_woke.connect(func() -> void: _ev["despierto"] = true)
	EventBus.death_shown.connect(func(_c: String) -> void: _ev["muerte_vista"] = true)
	EventBus.respawned.connect(_on_respawned)
	EventBus.discipline_step.connect(func(track: String, _s: int, info: Dictionary) -> void:
		if track.begins_with("coaching_sesion") and str(info.get("sesion", "")) == "fin":
			_ev["coaching_fin"] = true)
	EventBus.player_entered_zone.connect(func(z: String) -> void: if z == TrainingRoom.ENTRY: _in_aula = true)
	EventBus.player_exited_zone.connect(func(z: String) -> void: if z == TrainingRoom.ENTRY: _in_aula = false)
	var b := _building()
	if b != null:
		b.floor_loaded.connect(func(_n: int, _f: Node3D) -> void:
			_on_floor_loaded(_n, _f)
			_refresh_beacon.call_deferred(true))


func _add_actions() -> void:
	for pair in [["tutorial_next", KEY_T, JOY_BUTTON_BACK], ["tutorial_no", KEY_N, JOY_BUTTON_RIGHT_STICK], ["tutorial_skip", KEY_F8, -1]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var k := InputEventKey.new()
			k.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], k)
			if int(pair[2]) >= 0:  # v0.3.2: con mando, «continuar / sí» = Back y «no» = R3 (libres en el juego)
				var jb := InputEventJoypadButton.new()
				jb.button_index = int(pair[2]) as JoyButton
				InputMap.action_add_event(pair[0], jb)


## «Continuar [T]», «Sí [T]», «No [N]»: la tecla del Training (fija) y, con un mando conectado, su botón.
func _btn_text(key: String, action: String) -> String:
	var txt := tr(key)
	if Controls.has_gamepad():
		var joy := Controls.describe(action, true)
		if joy != "—":
			txt = txt.replace("]", " · %s]" % joy)
	return txt


func _freeze() -> void:
	if not Discipline.is_frozen() or not Discipline.freeze_reasons().has(FREEZE_REASON):
		Discipline.freeze(true, FREEZE_REASON)


func _exit_tree() -> void:
	_comodin_end()
	_subtitle_style(false)
	_hint_low(true)
	var pl0 := _player() if is_inside_tree() else null
	if pl0 != null and is_instance_valid(pl0):
		Flashback.clear_look(pl0.get("_rig"))  # el cuerpo del jugador deja la piel del recuerdo antes de liberarse
	if AudioManager.music_slot == "musica/" + MUSIC:
		AudioManager.stop_music()
	Flashback.active = false
	GameState.clock_shift = 0.0
	if _fb_layer != null and is_instance_valid(_fb_layer):
		_fb_layer.queue_free()
	if contract != null and is_instance_valid(contract):
		contract.queue_free()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	var ws0 := get_tree().get_first_node_in_group("workstation") if is_inside_tree() else null
	if ws0 != null:
		ws0.set("reserve_top", 0.0)  # la PC vuelve a su encuadre de siempre (la franja de la guía ya no está)
	_clear_beacon()
	if GameState.clock_override == CLOCK_KEY:
		GameState.clear_clock_override(CLOCK_KEY)


# --- bucle principal ---------------------------------------------------------------------------------

func _run() -> void:
	for id in queue:
		if not is_inside_tree():
			return
		var m := module_by_id(id)
		var status: String = await _run_module(m)
		if not is_inside_tree():
			return
		results[id] = status if not (status == "saltado" and str(results.get(id, "")) == "hecho") else "hecho"
		save_progress(results)
		if first_time and id != CONTRACT_MODULE:
			_save_first(id, status)  # si sales ahora, al volver sigues en el módulo siguiente
		module_finished.emit(id, status)
	running_module = ""
	_clear_beacon()
	if timeline_path != "" and voice != null:
		voice.write_log(timeline_path, {"agente": GameState.agent, "idioma": Loc.language, "modulos": ", ".join(PackedStringArray(queue)), "quiz": JSON.stringify(quiz)})
	if contract_signed and not present_cut_shown:
		await _present_cut()
		if not is_inside_tree():
			return
	finished = true
	if first_time and contract_signed:
		clear_first(GameState.agent)
		all_finished.emit(results)
		if main != null and main.has_method("_after_training"):
			main.call("_after_training", GameState.agent, contract_read, memory_record())
		return
	var done := 0
	var skipped := 0
	for id in module_ids():
		match str(results.get(id, "")):
			"hecho": done += 1
			"saltado": skipped += 1
	_show(tr("TUT_DONE_TITLE"), Loc.fmt(tr("TUT_DONE_BODY"), {"hechos": done, "saltados": skipped, "total": module_ids().size()}), "", "leer")
	all_finished.emit(results)
	_continue = false
	while not _continue:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if main != null and main.has_method("_back_to_menu"):
		main.call("_back_to_menu")


func _run_module(m: Dictionary) -> String:
	running_module = str(m.get("id", ""))
	current_step = {}  # el paso del módulo anterior no vale aquí (el bot actuaba sobre él: abría la pausa del Manual)
	_skip = false
	_clock_mode = "normal" if str(m.get("reloj", "")) == "normal" else CLOCK_KEY
	await _prepare(str(m.get("preparar", "sentado")))
	if _clock_mode == "normal" and GameState.clock_override == CLOCK_KEY:
		GameState.clear_clock_override(CLOCK_KEY)
	if GameState.clock_seconds > 40.0 * 60.0:
		_set_clock(10.0 * 60.0)
	_memory_hour(str(m.get("hora", "")))
	_modules_run += 1
	_post("#team-familia", "mentor", Loc.fmt(tr("TUT_MENTOR_MODULE"), {"n": int(m.get("n", 0)), "titulo": Loc.pick(m.get("titulo", {}))}), {"tipo": "induccion", "silent": true})
	_module_intro(m)
	if stage != null:
		stage.module_start(m)
	var steps: Array = m.get("pasos", [])
	step_count = steps.size()
	for i in steps.size():
		step_index = i
		if _skip or not is_inside_tree():
			break
		await _run_step(m, steps[i])
	var status := "saltado" if _skip else "hecho"
	await _cleanup(m)
	_skip = false
	_clock_mode = CLOCK_KEY
	return status


func _run_step(m: Dictionary, s: Dictionary) -> void:
	current_step = s
	_ev.clear()
	_continue = false
	_answer = -1
	_choice = -1
	_step_t = 0.0
	var tipo := str(s.get("tipo", "leer"))
	step_started.emit(running_module, str(s.get("id", "")))
	if voice != null:
		voice.trainer = trainer if trainer != null and is_instance_valid(trainer) else null
	if stage != null:
		stage.step_start(s, running_module)
	if tipo == "accion":
		if coach != null:
			coach.set_idle(true)  # el paso anterior ya está hecho: su texto se apaga hasta el paso siguiente
		await _speak(s.get("dice", []))
		if not (s.get("mientras", []) as Array).is_empty():
			_speak(s.get("mientras", []))  # sin esperar: suena durante la acción (el Trainer te apura mientras lees el contrato)
		await _do(str(s.get("accion", "")), s.get("args", {}))
		await _speak(s.get("luego", []))
		return
	var body := _fill(_txt(s.get("texto", {})))
	var title := Loc.fmt(tr("TUT_PANEL_TITLE"), {"n": int(m.get("n", 0)), "total": module_ids().size(), "titulo": Loc.pick(m.get("titulo", {})), "paso": step_index + 1, "pasos": step_count})
	_set_target(str(s.get("objetivo", "")))
	if coach != null:
		coach.target_ids = _ui_ids(s)
	if bool(s.get("panel", true)):
		_show(title, body, "", tipo)
	else:
		_panel.visible = false
	if tipo == "pregunta":
		_show_options(s)
	if step_gate.is_valid():
		await step_gate.call(running_module, s, "inicio")
		if not is_inside_tree():
			return
	_say(s, body)
	# primero se habla (una línea a la vez); el jugador puede ir haciendo la acción mientras tanto
	await _speak((s.get("dice", []) as Array) + _by_outcome(s.get("dice_por", {})))
	if not is_inside_tree():
		return
	match tipo:
		"leer":
			if not bool(s.get("auto", false)):
				while not _continue and not _skip:
					await get_tree().process_frame
					if not is_inside_tree():
						return
		"esperar":
			var cond := str(s.get("cond", ""))
			if cond == "comodin_abierto":
				_comodin_practice(true)
			while not _skip:
				if _cond(cond):
					break
				await get_tree().process_frame
				if not is_inside_tree():
					return
				_step_t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
				if s.has("pista") and _hint.text == "" and _step_t > 8.0:
					_hint.text = tr("TUT_HINT_PREFIX") + " " + _fill(_txt(s.get("pista", {})))
				await _watchdog(cond)
			if not _skip and s.has("al_cumplir") and stage != null:
				stage.cue(str(s["al_cumplir"]))  # lo que pasa en el aula cuando lo hiciste (el Trainer se acerca, aplauden…)
			if not _skip:
				await _speak(_by_outcome(s.get("luego_por", {})))
		"elegir":
			while _answer < 0 and not _skip:
				await get_tree().process_frame
				if not is_inside_tree():
					return
			if s.has("guarda") and _answer >= 0:
				choices[str(s.get("guarda"))] = _answer == 1
			if _answer >= 0 and stage != null and s.has("cue_si" if _answer == 1 else "cue_no"):
				stage.cue(str(s["cue_si" if _answer == 1 else "cue_no"]))
			if _answer == 1:
				await _speak(s.get("luego_si", []))
				if str(s.get("accion", "")) != "":
					await _do(str(s.get("accion", "")), s.get("args", {}))
			elif _answer == 0:
				await _speak(s.get("luego_no", []))
		"pregunta":
			await _ask(s)
	if not _skip:
		await _speak(s.get("luego", []))
	_set_target("")
	if coach != null:
		coach.target_ids = []
		coach.waiting = false
	_panel.visible = true


## Lo que el paso señala en la pantalla (TrainingTargets): sus `ui` y, si tiene `objetivo`, la luz guía del mundo.
func _ui_ids(s: Dictionary) -> Array:
	var ids: Array = (s.get("ui", []) as Array).duplicate()
	if str(s.get("objetivo", "")) != "":
		ids.append("mundo")
	return ids


## Las líneas del paso, en orden y sin pisarse (TrainingVoice). Saltar el módulo [F8] corta lo que queda.
func _speak(ids: Array) -> void:
	if voice == null or ids.is_empty():
		return
	for id in ids:
		if _skip or not is_inside_tree():
			return
		await voice.say(str(id))


## dice_por / luego_por: {resultado: [líneas], "_": [las de cualquier otro resultado]} según el último contacto.
func _by_outcome(d: Variant) -> Array:
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return []
	var r := str(_last_outcome.get("outcome", ""))
	return ((d as Dictionary).get(r, (d as Dictionary).get("_", [])) as Array).duplicate()


func is_speaking() -> bool:
	return voice != null and voice.speaking


# --- mini-check (tipo «pregunta») -------------------------------------------------------------------------

func _show_options(s: Dictionary) -> void:
	var opts: Array = s.get("opciones", [])
	var texts: Array = []
	for o in opts:
		texts.append(_txt(o))
	coach.set_options(texts, choose)
	# El sitio del resultado se guarda desde ya (el más largo de los dos): al contestar, nada salta ni se sale de la vista.
	var right := _txt(opts[int(s.get("correcta", 0))]) if not opts.is_empty() else ""
	coach.result.text = ""
	coach.result_reserve = "%s  %s" % [Loc.fmt(tr("TUT_QUIZ_WRONG"), {"r": right}), _txt(s.get("explica", {}))]


## Responde el mini-check (botón, [1]-[3] o el bot). Vale una vez por pregunta.
func choose(i: int) -> void:
	if str(current_step.get("tipo", "")) == "pregunta" and _choice < 0:
		_choice = i
		if voice != null:
			voice.skip_line()  # si el Trainer seguía con la pregunta, se calla (no se pisa con la respuesta)


func _ask(s: Dictionary) -> void:
	while _choice < 0 and not _skip:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if _skip:
		_end_options()
		return
	var ok := _choice == int(s.get("correcta", 0))
	quiz[running_module] = ok
	var opts: Array = s.get("opciones", [])
	var right := _txt(opts[int(s.get("correcta", 0))]) if not opts.is_empty() else ""
	coach.mark_options(int(s.get("correcta", 0)), _choice)
	var head := tr("TUT_QUIZ_OK") if ok else Loc.fmt(tr("TUT_QUIZ_WRONG"), {"r": right})
	coach.result.text = "%s  %s" % [head, _txt(s.get("explica", {}))]
	coach.result.add_theme_color_override("font_color", Color(0.62, 1.0, 0.7) if ok else Color(1.0, 0.72, 0.62))
	_btn_next.visible = true
	_keys.text = tr("TUT_KEY_SKIP")
	coach.waiting = true  # falta pulsar «Continuar»
	AudioManager.play_sfx("ezlak_mencion", "UI")
	if step_gate.is_valid():
		await step_gate.call(running_module, s, "respondido")
		if not is_inside_tree():
			return
	await _speak(["bien" if ok else "casi"])
	_continue = false
	while not _continue and not _skip:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_end_options()


func _end_options() -> void:
	_opts_box.visible = false
	coach.result.text = ""
	coach.result_reserve = ""


## Texto con los valores del momento: {agente} {resultado} {csat} {tiempo} {kyc}.
func _fill(txt: String) -> String:
	var out := Loc.fmt(txt, {"agente": GameState.agent})
	if out.contains("{resultado}") or out.contains("{csat}"):
		var r := str(_last_outcome.get("outcome", "neutral"))
		out = Loc.fmt(out, {"resultado": tr("TUT_OUTCOME_" + r.to_upper()), "csat": int(_last_outcome.get("csat", 3))})
	if out.contains("{tiempo}"):
		out = Loc.fmt(out, {"tiempo": Loc.mmss(float(_last_outcome.get("bo_s", 0.0)))})
	if out.contains("{kyc}"):
		out = Loc.fmt(out, {"kyc": tr("TUT_KYC_OK") if str(_last_outcome.get("outcome", "")) == "bo_ok" else tr("TUT_KYC_WRONG")})
	return out


## Voz del paso (voces/<slug>/<id>; la sintetiza P6a) y el compañero por Ezlaki.
func _say(s: Dictionary, body: String) -> void:
	var voz := str(s.get("voz", ""))
	if Flashback.active or voice != null:
		voz = ""  # v0.3.2: en el recuerdo solo habla el guion (TrainingVoice, una línea a la vez); el panel conserva el texto
	if voz.contains("/"):
		AudioManager.play_voice(voz.get_slice("/", 0), voz.get_slice("/", 1), "", "UI")
	if str(s.get("quien", "")) == "companero" or bool(s.get("ezlak", false)):
		_post("dm:" + companion(), companion(), body, {"tipo": "induccion", "mention": true})


## El compañero que acompaña la inducción por DM: Jiroshi (o Marko si el jugador es Jiroshi).
func companion() -> String:
	return "marko" if GameState.agent == "Jiroshi" else "jiroshi"


func _post(ch: String, author: String, text: String, meta: Dictionary) -> void:
	EventBus.ezlak_post.emit(ch, author, text, meta)


# --- condiciones ---------------------------------------------------------------------------------------

func waiting_for() -> String:
	return str(current_step.get("cond", "")) if str(current_step.get("tipo", "")) == "esperar" else str(current_step.get("tipo", ""))


func _cm() -> ContactManager:
	return get_tree().get_first_node_in_group("contact_manager") as ContactManager


func _ws() -> Control:
	return get_tree().get_first_node_in_group("workstation") as Control


func _case_ok(cm: ContactManager) -> bool:
	return cm != null and cm.case != null and str(cm.current.get("id", "")) == _offered_id


func _cond(c: String) -> bool:
	var cm := _cm()
	if c.begins_with("aux:"):
		return GameState.logged_in and Metrics.aux == int(Metrics.Aux.get(c.substr(4), -1))
	if c.begins_with("quick_reply:"):
		return bool(_ev.get("qr:" + c.substr(12), false))
	if c.begins_with("ezlak_canal:"):
		var ws := _ws()
		return ws != null and ws.get("ezlak") != null and str(ws.get("ezlak").get("current")) == c.substr(12)
	if c.begins_with("piso:"):
		return GameState.current_floor == int(c.substr(5))
	match c:
		"sentado":
			return GameState.seated_at == home_seat
		"sentado_available":
			return GameState.seated_at == home_seat and GameState.logged_in and Metrics.aux == Metrics.Aux.AVAILABLE
		"logueado":
			return GameState.logged_in
		"aux_menu":
			return bool(GameState.flags.get("aux_menu_open", false))
		"contacto_activo":
			return cm != null and cm.phase == ContactManager.Phase.ACTIVE and str(cm.current.get("id", "")) == _offered_id
		"contacto_fin", "caso_cerrado", "kyc_decidido":
			return bool(_ev.get("fin:" + _offered_id, false)) or str(_last_outcome.get("id", "")) == _offered_id and bool(_last_outcome.get("nuevo", false))
		"kardex":
			return _case_ok(cm) and cm.case.kardex_done
		"destinatario_ok":
			return _case_ok(cm) and (cm.case.recipient == str(cm.case.correct().get("destinatario", "")) or not cm.case.sent.is_empty())
		"plantilla_ok":
			return _case_ok(cm) and (cm.case.template == str(cm.case.correct().get("plantilla", "")) or not cm.case.sent.is_empty())
		"campos_ok":
			if not _case_ok(cm):
				return false
			if not cm.case.sent.is_empty():
				return true
			var want: Dictionary = cm.case.correct().get("campos", {})
			for k in want.keys():
				if str(cm.case.fields.get(k, "")) != str(want[k]):
					return false
			return true
		"enviado":
			return _case_ok(cm) and not cm.case.sent.is_empty()
		"enviado_ok":
			return _case_ok(cm) and bool(cm.case.call("_has_correct_mail"))
		"tipificado":
			return _case_ok(cm) and cm.case.typification == str(cm.case.correct().get("tipificacion", ""))
		"portal_buscar":
			return _case_ok(cm) and cm.case.portal_done.has("buscar")
		"reaccion", "rooms", "coaching_fin", "ack", "dormido", "despierto", "muerte_vista":
			return bool(_ev.get(c, false))
		"rub_eyes":
			return bool(_ev.get("rub", false))
		"reconectado":
			return bool(_ev.get("reconectado", false))
		"fuera_sala":
			if home_floor == 1:
				return GameState.logged_in and GameState.seated_at == "" and (GameState.current_floor != 1 or not _in_aula)
			return GameState.logged_in and not GameState.in_room
		"firmado":
			return contract_signed
		"cafe":
			return bool(_ev.get("cafe", false))
		"comodin_abierto":
			return Comodin.phase != "" or _comodin_done
		"comodin_hecho":
			return _comodin_done
		"perdido_o_atendido":
			if str(_last_outcome.get("id", "")) == _offered_id and str(_last_outcome.get("outcome", "")) == "perdido":
				return true
			if cm != null and cm.phase == ContactManager.Phase.ACTIVE and str(cm.current.get("id", "")) == _offered_id:
				cm.call("_on_respawned", "tutorial")  # la contestó: se suelta sin incidencias y el Trainer lo comenta
				_last_outcome = {"id": _offered_id, "outcome": "atendida", "nuevo": true}
				return true
			return false
		"manual_abierto":
			return bool(GameState.flags.get("manual_abierto", false))
	push_warning("Tutorial: condición desconocida %s" % c)
	return true


## v0.3.2 · El comodín de verdad (autoload Comodin, [C] mantenida) en el recuerdo: llamas a alguien de TU promoción
## (Flashback.classmates), que siempre contesta; Shero no se entera y no cuenta para la partida (Comodin.practice_names).
var _comodin_done: bool = false


func _comodin_practice(fresh: bool) -> void:
	var names: Array[String] = []
	for n in Flashback.classmates():
		names.append(str(n))
	Comodin.practice_names = names
	Comodin.answer_override = func(_n: String) -> bool: return true
	if not Comodin.call_answered.is_connected(_on_comodin):
		Comodin.call_answered.connect(_on_comodin)
	if fresh:
		Comodin.reset()  # el de práctica siempre está disponible
		_comodin_done = false


func _on_comodin(who: String, _aux: int) -> void:
	_comodin_done = true
	if voice != null:
		voice.comodin_who = who  # la línea «comodin» del paso: te contesta con su voz


func _comodin_end() -> void:
	Comodin.practice_names = []
	Comodin.answer_override = Callable()
	if Comodin.call_answered.is_connected(_on_comodin):
		Comodin.call_answered.disconnect(_on_comodin)
	Comodin.reset()


## Si algo de la práctica se perdió (la llamada sonó y no la tomaste, el recordatorio de Vitzo venció, la
## invitación a Rooms caducó), se explica y se vuelve a lanzar: la inducción nunca queda trabada.
var _retry_t: float = 0.0


func _watchdog(cond: String) -> void:
	_retry_t += get_process_delta_time()
	if _retry_t < 2.0:
		return
	_retry_t = 0.0
	match cond:
		"contacto_activo":
			var cm := _cm()
			if cm != null and cm.phase == ContactManager.Phase.IDLE and str(_last_outcome.get("id", "")) == _offered_id and str(_last_outcome.get("outcome", "")) == "perdido":
				EventBus.show_message.emit(tr("TUT_MISSED_RETRY"), 4.0)
				await _offer(_offered_id)
		"reaccion":
			var v := get_tree().get_first_node_in_group("vitzo")
			if v != null and not bool(v.call("is_reminder_pending")) and not bool(_ev.get("reaccion", false)):
				v.call("post_reminder")
		"rooms":
			var hub := EzlakHub.get_hub(get_tree())
			if hub != null and not hub.rooms_pending and not bool(_ev.get("rooms", false)):
				Discipline.request_coaching("shero", 300.0)
		"ack":
			if not Metrics.ack_pending and not bool(_ev.get("ack", false)):
				Metrics.issue_written_warning("induccion")


func _on_outcome(c: Dictionary, outcome: String, csat: int) -> void:
	var id := str(c.get("id", ""))
	_last_outcome = {"id": id, "outcome": outcome, "csat": csat, "bo_s": float(c.get("_bo_elapsed", c.get("_duration", 0.0))), "nuevo": true}
	_ev["fin:" + id] = true


func _on_ack_expired() -> void:
	# En la Inducción el Ack vencido no persigue a nadie (Discipline lo ignora): se explica y se repite.
	if running_module != "" and str(current_step.get("cond", "")) == "ack":
		EventBus.show_message.emit(tr("TUT_ACK_EXPIRED"), 4.0)  # _watchdog vuelve a mandar el WW de práctica


func _on_respawned(_k: String) -> void:
	_ev["reconectado"] = true
	_freeze()  # el respawn suelta todos los motivos de congelamiento
	GameState.flags.erase("tutorial_permite_muerte")


# --- acciones -------------------------------------------------------------------------------------------

func _do(a: String, args: Variant) -> void:
	var ar: Dictionary = args if args is Dictionary else {}
	match a:
		"ofrecer":
			await _offer(str(ar.get("contacto", "")))
			var cm0 := _cm()
			if ar.has("timbre_s") and cm0 != null and cm0.phase == ContactManager.Phase.OFFERING:
				cm0.ring_left = minf(cm0.ring_left, float(ar["timbre_s"]))  # la llamada que se deja sonar: timbre corto
		"post":
			var meta: Dictionary = (ar.get("meta", {}) as Dictionary).duplicate(true)
			_post(str(ar.get("canal", "dm:shero")), str(ar.get("autor", "shero")), _fill(_txt(ar.get("texto", {}))), meta)
		"vitzo_reminder":
			var v := get_tree().get_first_node_in_group("vitzo")
			if v != null and v.has_method("post_reminder"):
				v.call("post_reminder")
		"rooms":
			Discipline.request_coaching("shero", 300.0)
		"ww_practica":
			if not Metrics.ack_pending:
				Metrics.issue_written_warning("induccion")
		"fatiga":
			Fatigue.set_value(float(ar.get("valor", 70.0)))
		"screamer_practica":
			await _practice_screamer()
		"colapso_practica":
			_practice_collapse()
		"contrato":
			await _sign_contract()
		"trainer", "decir":
			await _speak([str(ar.get("linea", ""))] if ar.has("linea") else ar.get("lineas", []))
		"aplauso":
			if trainer != null and is_instance_valid(trainer):
				trainer.applaud()
		"tarjeta":
			await _date_card()
		"foto":
			await _group_photo()
		_:
			push_warning("Tutorial: acción desconocida %s" % a)


## Ofrece un contacto del tutorial (espera a que la cola esté libre y el jugador listo en su silla).
func _offer(id: String) -> void:
	var c := case_by_id(id)
	if c.is_empty():
		return
	_offered_id = id
	_last_outcome = {}
	var cm := _cm()
	var waited := 0.0
	while cm != null and is_inside_tree() and not _skip:
		if cm.phase == ContactManager.Phase.IDLE and cm.player_ready() and cm.offer_now(c):
			return
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 30.0 and cm.phase == ContactManager.Phase.OFFERING and str(cm.current.get("id", "")) != id:
			cm.call("_miss")  # otro contacto colgado: se libera la cola


func _practice_screamer() -> void:
	_panel.visible = false
	var pl := _player()
	await Screamers.play("shero", "break_excedido", "")
	Screamers.clear_hold()
	if pl != null and is_instance_valid(pl):
		pl.reset_camera()
		pl.input_locked = false
		if pl.seated:
			pl.capture_mouse(false)
	if is_inside_tree():
		_panel.visible = true


## Colapso de práctica: checkpoint ahí mismo, permiso de muerte (solo esta) y la Fatiga a 100.
func _practice_collapse() -> void:
	Checkpoints.save_checkpoint("aux")
	if Checkpoints.last_checkpoint.is_empty():
		Checkpoints.save_checkpoint("login")
	GameState.flags["tutorial_permite_muerte"] = true
	Fatigue.set_value(99.0)
	Fatigue.add(5.0)


# --- preparar / limpiar módulos ------------------------------------------------------------------------

func _prepare(kind: String) -> void:
	var b := _building()
	var pl := _player()
	if b == null or pl == null:
		return
	if Checkpoints.dying:
		Checkpoints.respawn()
		await get_tree().process_frame
	if SleepSpot.is_player_sleeping():
		for s in get_tree().get_nodes_in_group("sleep_spots"):
			if s.has_method("wake_up"):
				s.call("wake_up")
	match kind:
		"entrada_sala":
			if pl.seated:
				pl.stand_up()
			var entry: String = TrainingRoom.ENTRY if home_floor == 1 else "entrada_sala"
			if b.current_floor != home_floor:
				b.go_to_floor(home_floor, entry)
				await _frames(3)
				b = _building()
				pl = _player()
				if not is_inside_tree() or b == null or pl == null:
					return
			var m := b.floor_node.find_child(TrainingRoom.DOOR_MARK if home_floor == 1 else entry, true, false) as Node3D
			if m == null:
				m = b.floor_node.find_child(entry, true, false) as Node3D
			if m != null:
				pl.teleport(m.global_position, m.rotation_degrees.y)  # en la puerta, mirando al aula
			_in_aula = true
		"sentado", "silla":
			# Si el módulo anterior te dejó lejos (el -1 de la Fatiga, el pasillo, un módulo saltado a medio camino), el
			# recuerdo salta a tu mesa con un parpadeo a negro: nunca un teletransporte a la vista.
			var jump := Flashback.active and _modules_run > 0 and (not pl.seated or pl.seat_id != home_seat or b.current_floor != home_floor)
			var soft := jump and not (voice != null and voice.fast)
			if soft:
				await _fade(1.0, 0.35)
			await ensure_seated(kind == "sentado")  # «silla»: sentado en la T-01 pero sin sesión (el módulo te enseña a iniciarla)
			if soft:
				await _fade(0.0, 0.45)
	_clock_reset()


## Deja al jugador sentado en C-14, con sesión iniciada, en Available y sin contacto (lo usan los módulos y el bot).
func ensure_seated(login: bool = true) -> void:
	var b := _building()
	var pl := _player()
	if b == null or pl == null:
		return
	if b.current_floor != home_floor:
		b.go_to_floor(home_floor, TrainingRoom.ENTRY if home_floor == 1 else "pc")
		await _frames(3)
		b = _building()
		pl = _player()
		if not is_inside_tree() or b == null or pl == null:
			return  # el escenario cambió de partida a mitad de camino
	if home_floor == 1 and not TrainingRoom.is_ready(b.floor_node):
		_on_floor_loaded(1, b.floor_node)
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id(home_seat) if fl != null else null
	if seat != null and (not pl.seated or pl.seat_id != home_seat):
		if pl.seated:
			pl.stand_up()
		pl.sit_at(seat, home_seat)
	_in_aula = true
	if not login:
		await _frames(2)
		return
	if not GameState.logged_in:
		var ws := _ws()
		if ws != null and ws.has_method("press_accept"):
			ws.call("press_accept")
		if not GameState.logged_in:
			GameState.login()
	if Metrics.aux != Metrics.Aux.AVAILABLE:
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _frames(2)


func _cleanup(_m: Dictionary) -> void:
	_set_target("")
	var cm := _cm()
	if cm != null and cm.phase != ContactManager.Phase.IDLE:
		cm.call("_on_respawned", "tutorial")  # suelta el contacto del tutorial sin incidencias
	if Metrics.ack_pending:
		Metrics.give_ack()
	Metrics.written_warnings = 0
	Metrics.alerts = 0
	if cm != null:
		cm.missed_count = 0  # el contacto perdido de práctica (módulo «metricas») no queda en ninguna cuenta
	var hub := EzlakHub.get_hub(get_tree())
	if hub != null:
		hub.rooms_pending = false
	if Checkpoints.dying:
		Checkpoints.respawn()
	GameState.flags.erase("tutorial_permite_muerte")
	if Fatigue.value > 60.0:
		Fatigue.set_value(40.0)
	var pl := _player()
	if pl != null:
		pl.input_locked = false
	_freeze()
	await _frames(1)


func _clock_reset() -> void:
	if GameState.clock_seconds > 40.0 * 60.0:
		_set_clock(10.0 * 60.0)


func _set_clock(s: float) -> void:
	if Flashback.active:
		GameState.clock_shift += GameState.clock_seconds - s  # el reloj que se VE en el recuerdo no retrocede
	GameState.clock_seconds = s
	EventBus.clock_tick.emit(s)


## El recuerdo es un día entero de clase contado en un cuarto de hora: cada módulo empieza a su hora («hora» en
## tutorial.json: la bienvenida 8:48, el coffee break 11:40, la firma 17:00). Solo cambia el texto del reloj (HUD, PC,
## Fonex, Ezlaki) y nunca hacia atrás; el reloj de juego sigue siendo el de la Inducción.
func _memory_hour(hhmm: String) -> void:
	if not Flashback.active or hhmm == "":
		return
	var want := GameState.hhmm_to_seconds(hhmm)
	if want < 0.0:
		return
	var shown := GameState.clock_seconds + GameState.clock_shift
	if want > shown:
		GameState.clock_shift = want - GameState.clock_seconds


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	# Reloj de la inducción (4x) salvo en los módulos de correo y mientras otro reloj especial manda (Rooms, dormido).
	if _clock_mode == CLOCK_KEY and GameState.clock_override == "" and GameState.running:
		GameState.set_clock_override(CLOCK_KEY)
	if not Discipline.freeze_reasons().has(FREEZE_REASON) and not Checkpoints.dying:
		_freeze()
	_update_beacon(delta)
	_hint_low()
	if _lang != Loc.language:
		_relang()


## El idioma cambió con el Training abierto (Opciones desde la pausa): el panel se reescribe en el idioma nuevo sin
## reiniciar el paso (título, texto, pista, opciones del mini-check con su resultado, botones). Los rótulos fijos del
## aula los retraduce Loc.retranslate (core); las líneas habladas salen en el idioma nuevo desde la siguiente.
func _relang() -> void:
	var first := _lang == ""
	_lang = Loc.language
	if first or _panel == null or not is_instance_valid(_panel):
		return
	_button_texts()
	var s := current_step
	var m := module_by_id(running_module)
	var tipo := str(s.get("tipo", "leer"))
	if s.is_empty() or m.is_empty() or tipo == "accion":
		return
	_title.text = Loc.fmt(tr("TUT_PANEL_TITLE"), {"n": int(m.get("n", 0)), "total": module_ids().size(), "titulo": Loc.pick(m.get("titulo", {})), "paso": step_index + 1, "pasos": step_count})
	var body := _fill(_txt(s.get("texto", {})))
	var keys: Array[String] = []
	if tipo == "pregunta":
		var opts: Array = s.get("opciones", [])
		for i in mini(opts.size(), _opts_box.get_child_count()):
			coach.set_option_text(i, _txt(opts[i]))
		if not opts.is_empty() and _opts_box.visible:
			var wrong := Loc.fmt(tr("TUT_QUIZ_WRONG"), {"r": _txt(opts[int(s.get("correcta", 0))])})
			coach.result_reserve = "%s  %s" % [wrong, _txt(s.get("explica", {}))]
			if _choice >= 0:  # ya contestado: el resultado y la explicación, también en el idioma nuevo
				coach.result.text = "%s  %s" % [tr("TUT_QUIZ_OK") if _choice == int(s.get("correcta", 0)) else wrong, _txt(s.get("explica", {}))]
		if _choice < 0:
			keys.append(tr("TUT_KEY_QUIZ"))
	elif tipo not in ["leer", "elegir"]:
		keys.append(tr("TUT_KEY_DO"))
	keys.append(tr("TUT_KEY_SKIP"))
	_body.text = body
	_keys.text = "  ·  ".join(PackedStringArray(keys))
	if _hint.text != "" and s.has("pista"):
		_hint.text = tr("TUT_HINT_PREFIX") + " " + _fill(_txt(s.get("pista", {})))
	_refresh_beacon(true)


## Sentado en clase, la pista del centro de la pantalla («[E] Levantarse») caía justo sobre el Trainer: baja a la altura
## de tus monitores. De pie vuelve al centro (junto a lo que miras).
func _hint_low(restore: bool = false) -> void:
	var hud: Node = main.get("hud") if main != null and is_instance_valid(main) else null
	var hint := hud.get("_hint") as Label if hud != null else null
	if hint == null:
		return
	var pl := _player()
	var low := not restore and Flashback.active and pl != null and pl.seated and not bool(GameState.flags.get("pc_zoom", false))
	var top := 236.0 if low else 20.0
	if not is_equal_approx(hint.offset_top, top):
		hint.offset_top = top
		hint.offset_bottom = top + 26.0


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("tutorial_skip"):
		skip_module()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tutorial_next"):
		# [T] mientras alguien habla SIEMPRE corta esa línea (también en un «elegir»: antes contestaba «sí» sin querer y
		# la línea seguía); con el aula en silencio, [T] es «sí» / «continuar».
		if voice != null and voice.speaking and not finished:
			voice.skip_line()
		elif str(current_step.get("tipo", "")) == "elegir":
			answer(true)
		else:
			press_continue()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and str(current_step.get("tipo", "")) == "pregunta" and (event as InputEventKey).physical_keycode in [KEY_1, KEY_2, KEY_3]:
		choose([KEY_1, KEY_2, KEY_3].find((event as InputEventKey).physical_keycode))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and str(current_step.get("tipo", "")) == "pregunta":
		for i in 3:  # con mando: la cruceta (las mismas «frases 1-3» con que se contesta a un cliente)
			if event.is_action_pressed("phrase_%d" % (i + 1)):
				choose(i)
				get_viewport().set_input_as_handled()
				break
	elif event.is_action_pressed("tutorial_no") and str(current_step.get("tipo", "")) == "elegir":
		answer(false)
		get_viewport().set_input_as_handled()


func press_continue() -> void:
	if voice != null and voice.speaking and not finished:
		voice.skip_line()  # [T] mientras habla: corta esa línea (la siguiente empieza después, nunca encima)
		return
	if finished or str(current_step.get("tipo", "")) in ["leer", "pregunta"]:
		_continue = true


func answer(yes: bool) -> void:
	_answer = 1 if yes else 0


func skip_module() -> void:
	if running_module != "" and not finished and running_module != CONTRACT_MODULE:
		_skip = true
		if voice != null:
			voice.skip_line()  # [F8] también calla la línea en curso: el módulo se salta ya, no cuando el Trainer termine


func step() -> Dictionary:
	return current_step


func module_id() -> String:
	return running_module


# --- UI: panel de la inducción ----------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 25  # sobre la pantalla de muerte (Reconectar del módulo 9); los screamers lo ocultan
	_layer.name = "TutorialUI"
	get_tree().root.add_child.call_deferred(_layer)  # Main puede estar aún en _ready (modo -- --bot-tutorial)
	coach = TrainingCoach.new()
	coach.tut = self
	_layer.add_child(coach)
	_panel = coach.panel
	_title = coach.title
	_body = coach.body
	_opts_box = coach.opts_box
	_hint = coach.hint
	_target_lbl = coach.target_lbl
	_keys = coach.keys
	_btn_next = coach.btn_next
	_btn_yes = coach.btn_yes
	_btn_no = coach.btn_no
	_btn_skip = coach.btn_skip
	_btn_next.pressed.connect(press_continue)
	_btn_yes.pressed.connect(answer.bind(true))
	_btn_no.pressed.connect(answer.bind(false))
	_btn_skip.pressed.connect(skip_module)
	_button_texts()
	if not Input.joy_connection_changed.is_connected(_on_joy):
		Input.joy_connection_changed.connect(_on_joy)


func _button_texts() -> void:
	_btn_next.text = _btn_text("TUT_BTN_NEXT", "tutorial_next")
	_btn_yes.text = _btn_text("TUT_BTN_YES", "tutorial_next")
	_btn_no.text = _btn_text("TUT_BTN_NO", "tutorial_no")
	_btn_skip.text = tr("TUT_BTN_SKIP")
	for i in coach.btn_ans.size():  # [1] [2] [3] del mini-check (teclas fijas); con mando, la cruceta
		var txt := "[%d]" % (i + 1)
		if Controls.has_gamepad():
			var joy := Controls.describe("phrase_%d" % (i + 1), true)
			if joy != "—":
				txt = "[%d · %s]" % [i + 1, joy]
		coach.btn_ans[i].text = txt


func _on_joy(_device: int, _connected: bool) -> void:
	if _btn_next != null and is_instance_valid(_btn_next):
		_button_texts()


func _show(title: String, body: String, hint: String, tipo: String) -> void:
	_panel.visible = true
	coach.set_idle(false)
	_title.text = title
	_body.text = body
	_hint.text = hint
	_btn_next.visible = tipo == "leer"
	if _opts_box != null and tipo != "pregunta":
		_opts_box.visible = false
		coach.result.text = ""
		coach.result_reserve = ""
	_btn_yes.visible = tipo == "elegir"
	_btn_no.visible = tipo == "elegir"
	_btn_skip.visible = not finished
	var keys: Array[String] = []
	if tipo == "pregunta":
		keys.append(tr("TUT_KEY_QUIZ"))
	elif tipo not in ["leer", "elegir"]:
		keys.append(tr("TUT_KEY_DO"))  # leer / elegir: la tecla ya va en el botón («Continuar [T]», «Sí [T]»)
	keys.append(tr("TUT_KEY_SKIP"))  # [F8] ya va en el botón «Saltar módulo [F8]»
	_keys.text = "  ·  ".join(PackedStringArray(keys))
	# Lo que se espera del jugador en este paso va en el color de la guía; «[Esc] pausa» solo, en gris.
	_keys.add_theme_color_override("font_color", TrainingCoach.GOLD if tipo in ["esperar", "pregunta"] else UITheme.DIM)
	coach.progress = float(step_index + 1) / float(maxi(step_count, 1)) if not finished else 1.0
	coach.waiting = tipo != "leer" or not bool(current_step.get("auto", false))
	var key := "%s/%s/%d" % [running_module, str(current_step.get("id", "")), int(finished)]
	if key != _cue_key:  # paso nuevo: destello + sonido corto (TrainingCoach.cue)
		_cue_key = key
		coach.cue()


# --- luz guía (objetivo) ----------------------------------------------------------------------------

func _set_target(t: String) -> void:
	_target = t
	_refresh_beacon(true)


func _refresh_beacon(_force: bool = false) -> void:
	_clear_beacon()
	if _target == "" or not is_inside_tree():
		if _target_lbl != null:
			_target_lbl.text = ""
		return
	var pos := _target_pos()
	if pos == Vector3.INF:
		return
	var b := _building()
	if b == null or b.floor_node == null:
		return
	_beacon = Node3D.new()
	_beacon.name = "LuzGuia"
	b.floor_node.add_child(_beacon)
	_beacon.global_position = pos
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.42
	cyl.height = 3.2
	cyl.radial_segments = 16
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	mi.position.y = 1.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.25, 0.85, 0.9, 0.34)
	mat.no_depth_test = false
	mi.material_override = mat
	_beacon.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.52
	ring.mesh = tm
	ring.position.y = 0.04
	ring.material_override = mat
	ring.name = "Aro"
	_beacon.add_child(ring)
	var tag := Label3D.new()  # se ve de lejos y a través de las mamparas: «▼ aquí»
	tag.name = "Etiqueta"
	tag.text = tr("TUT_BEACON_TAG")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0011
	tag.font_size = 30
	tag.outline_size = 8
	tag.modulate = Color(0.45, 0.95, 1.0)
	tag.outline_modulate = Color(0, 0.08, 0.1, 0.9)
	tag.position.y = 3.5
	tag.render_priority = 10
	_beacon.add_child(tag)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 0.9, 0.95)
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position.y = 1.2
	l.shadow_enabled = false
	_beacon.add_child(l)


func _clear_beacon() -> void:
	if _beacon != null and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null


func _target_pos() -> Vector3:
	var b := _building()
	if b == null or b.floor_node == null:
		return Vector3.INF
	var fl := b.floor_node
	if _target.begins_with("seat:"):
		if b.current_floor != (home_floor if _target.substr(5) == home_seat else 2):
			return Vector3.INF
		var seat := (fl as FloorBase).seat_by_id(_target.substr(5)) if fl is FloorBase else null
		if seat == null:
			return Vector3.INF
		var base := seat.global_position
		return Vector3(base.x, (fl as Node3D).global_position.y, base.z)
	if _target.begins_with("marker:"):
		var m := fl.find_child(_target.substr(7), true, false) as Node3D
		return Vector3(m.global_position.x, (fl as Node3D).global_position.y, m.global_position.z) if m != null else Vector3.INF
	if _target == "sleep":
		if b.current_floor != -1:
			return Vector3.INF
		var best: Node3D = null
		var pl := _player()
		for s in get_tree().get_nodes_in_group("sleep_spots"):
			if s is Node3D and str(s.get("spot_id")).begins_with("puff"):
				if best == null or (pl != null and (s as Node3D).global_position.distance_to(pl.global_position) < best.global_position.distance_to(pl.global_position)):
					best = s
		if best == null:
			for s in get_tree().get_nodes_in_group("sleep_spots"):
				if s is Node3D:
					best = s
					break
		return Vector3(best.global_position.x, (fl as Node3D).global_position.y, best.global_position.z) if best != null else Vector3.INF
	return Vector3.INF


func _update_beacon(delta: float) -> void:
	if _target == "":
		if _target_lbl != null:
			_target_lbl.text = ""
		return
	_beacon_t += delta
	var pl := _player()
	if _beacon == null or not is_instance_valid(_beacon):
		_target_lbl.text = tr("TUT_TARGET_OTHER_FLOOR") if _target.begins_with("seat:") or _target == "sleep" else ""
		return
	var ring := _beacon.get_node_or_null("Aro") as Node3D
	if ring != null:
		var s := 1.0 + 0.12 * sin(_beacon_t * 4.0)
		ring.scale = Vector3(s, 1.0, s)
	if pl != null:
		var d := Vector2(pl.global_position.x - _beacon.global_position.x, pl.global_position.z - _beacon.global_position.z).length()
		_target_lbl.text = Loc.fmt(tr("TUT_TARGET"), {"m": int(round(d))})
		_beacon.visible = d > 0.9
		var tag := _beacon.get_node_or_null("Etiqueta") as Label3D
		if tag != null:
			tag.text = tr("TUT_BEACON_TAG") + "  %d m" % int(round(d))


# --- ayudas ---------------------------------------------------------------------------------------------

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _building() -> Building:
	return get_tree().get_first_node_in_group("building") as Building


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- v0.3.2 · el recuerdo: sala, Trainer amable, contrato y corte al presente ------------------------------

func _flashback_begin() -> void:
	Flashback.active = true
	GameState.clock_shift = Flashback.CLOCK_SHIFT
	_fb_layer = Flashback.make_layer(get_tree().root)
	var b := _building()
	if b != null and b.floor_node != null:
		_on_floor_loaded(b.current_floor, b.floor_node)
	var pl := _player()
	if pl != null:
		Flashback.apply_look(pl.get("_rig"), "recuerdo")
	_subtitle_style(true)
	AudioManager.play_music(MUSIC)  # cálida y baja (−30 LUFS): va por debajo de las voces, nunca compite con ellas


## En el recuerdo todo es claro (paredes crema, luz de día): el subtítulo del HUD, pensado para la torre oscura, no se
## leía. Mientras dura el recuerdo va más grande y con borde negro; al salir vuelve a como estaba.
func _subtitle_style(on: bool) -> void:
	var hud: Node = main.get("hud") if main != null else null
	var sub := hud.get("_sub") as Label if hud != null else null
	if sub == null:
		return
	for k in ["_clock", "_aux", "_metrics", "_hold", "_disc", "_hint", "_msg"]:  # todo el HUD con borde sobre el aula clara
		var l := hud.get(k) as Label
		if l == null:
			continue
		if on:
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 6)
		else:
			l.remove_theme_color_override("font_outline_color")
			l.remove_theme_constant_override("outline_size")
	var msg := hud.get("_msg") as Label
	if msg != null:  # el subtítulo del recuerdo es más grande y crece hacia arriba: el aviso sube para no quedar debajo
		msg.offset_top = -262.0 if on else -180.0
		msg.offset_bottom = -234.0 if on else -152.0
	if on:
		sub.add_theme_font_size_override("font_size", 27)
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		sub.add_theme_constant_override("outline_size", 9)
		sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		sub.add_theme_constant_override("shadow_offset_y", 2)
		sub.offset_left = -620.0
		sub.offset_right = 620.0
	else:
		for k in ["font_outline_color", "font_shadow_color"]:
			sub.remove_theme_color_override(k)
		for k in ["outline_size", "shadow_offset_y"]:
			sub.remove_theme_constant_override(k)
		sub.add_theme_font_size_override("font_size", 20)
		sub.offset_left = -450.0
		sub.offset_right = 450.0


## Cada piso que se carga en el recuerdo está nuevo y limpio; el piso 1 trae la sala de training armada.
func _on_floor_loaded(n: int, f: Node3D) -> void:
	if f == null:
		return
	Flashback.clean_floor(f)  # antes de armar el aula: las luces del aula del recuerdo son las de TrainingRoom.LOOK
	if n == 1:
		trainer = TrainingRoom.setup(f)
		if voice != null:
			voice.trainer = trainer
		if stage != null:
			stage.bind(f, trainer)
		for c in f.find_children("MesaCafe*", "", true, false):
			if c is Interactable and not c.is_connected("interacted", _on_coffee):
				c.connect("interacted", _on_coffee)
	var envs := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if not envs.is_empty():
		Flashback.brighten_env((envs[0] as WorldEnvironment).environment)


func _on_coffee(_p: Node) -> void:
	_ev["cafe"] = true


## Al empezar cada módulo el Trainer vuelve a la pizarra. Si el Training no empieza por la bienvenida (repetir un
## módulo desde el menú), la tarjeta «Recuerdo · fecha» sale igual al principio. Lo que se dice va en los pasos.
func _module_intro(_m: Dictionary) -> void:
	if not _card_shown and str(_m.get("id", "")) != "llegada":
		_card_shown = true
		Flashback.date_card(get_tree().root, GameState.agent)


## La tarjeta «Recuerdo · fecha» con el fotocheck nuevo; el guion sigue cuando se fue.
func _date_card() -> void:
	_card_shown = true
	_panel.visible = false
	var secs := 0.4 if voice != null and voice.fast else 4.5
	Flashback.date_card(get_tree().root, GameState.agent, secs)
	await PersonajesP5.wait(self, secs + 0.2)  # el panel vuelve con el primer paso que tenga texto


## Lo que la partida guarda del recuerdo (ecos de la semana: la polaroid en C-14): {foto: sonreíste, quiz: aciertos}.
func memory_record() -> Dictionary:
	var ok := 0
	for k in quiz.keys():
		if bool(quiz[k]):
			ok += 1
	var rec := {"foto": bool(choices.get("foto", true)), "foto_tomada": photo_taken, "quiz_ok": ok, "quiz_total": quiz.size()}
	for k in ["conto", "pregunto", "ayudo"]:  # lo que elegiste con tu promoción y con el Trainer
		if choices.has(k):
			rec[k] = bool(choices[k])
	if not signature.is_empty():
		rec["firma"] = signature  # tu firma de verdad (trazos normalizados): el contrato clavado en el aula, en la semana
	return rec


## La foto de promoción queda en la carpeta de la partida del agente (la polaroid que aparece en C-14 el lunes).
func _save_photo() -> void:
	if photo_image == null or photo_image.is_empty():
		return
	var img := photo_image.duplicate() as Image
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	var path := RecuerdosSemana.photo_path(GameState.agent)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	img.save_jpg(path, 0.85)


## Foto de promoción (con temporizador, para que salga también el Trainer): la vista pasa a la cámara, que queda sobre
## tu mesa; la promoción camina a la pizarra, tú ya estás en tu sitio (un doble con tu cara del recuerdo), el Trainer
## aprieta el botón y corre a ponerse a tu lado; flash, y la polaroid con la fecha. La imagen queda en la partida.
func _group_photo() -> void:
	_panel.visible = false
	var b := _building()
	var fl: Node3D = b.floor_node if b != null else null
	var prev := get_viewport().get_camera_3d()
	var cam: Camera3D = null
	var double: TrainingActor = null
	var own_rig: Node3D = null
	var fast := voice != null and voice.fast
	var on_floor := fl != null and b.current_floor == 1 and stage != null and stage.ready_on_floor()
	if on_floor:
		await _fade(1.0, 0.0 if fast else 0.3)
		if not is_inside_tree():
			return
		cam = Camera3D.new()
		cam.name = "CamaraFoto"
		cam.fov = TrainingRoom.PHOTO_FOV
		fl.add_child(cam)
		cam.position = TrainingRoom.PHOTO_CAM
		cam.look_at(fl.to_global(TrainingRoom.PHOTO_LOOK), Vector3.UP)
		cam.current = true
		# Tú también sales: tu cuerpo en primera persona no tiene cabeza, así que posa un doble (el agente del recuerdo).
		var pl := _player()
		double = TrainingActor.new()
		double.name = "TuFoto"
		fl.add_child(double)
		if double.build(CharacterRig.agent_model(GameState.agent), 1.72):
			double.place_standing(TrainingRoom.PHOTO_YOU, TrainingRoom.PHOTO_CAM - TrainingRoom.PHOTO_YOU)
			if bool(choices.get("foto", true)) and double.has_gesture("pose_a"):
				double.base_clip = TrainingActor.T32 + "/pose_a"
				double.rig.play(double.base_clip, true)
			else:
				double.rig.play("idle_arms", true, 1.0, ["idle"])  # serio: brazos cruzados
		if pl != null:
			own_rig = pl.get("_rig") as Node3D
			if own_rig != null:
				own_rig.visible = false
		stage.set_scene("foto", fast)
		trainer.place("camara")
		trainer.turn_to(TrainingRoom.PHOTO_CAM)
		await _fade(0.0, 0.0 if fast else 0.3)
		if not is_inside_tree():
			return
		trainer.gesture("camera")
		await _speak(["t_foto_timer"])
		if not is_inside_tree():
			return
		trainer.go("foto", func() -> void: stage._hold(trainer, "pose_a"))
		var left := 0.0 if fast else 9.0  # hasta que todos llegaron a su sitio (con tope)
		while left > 0.0 and is_inside_tree() and not _photo_ready():
			await get_tree().process_frame
			left -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		await _speak(["t_foto_ya"])
		await PersonajesP5.wait(self, 0.1 if fast else 0.5)
		if not is_inside_tree():
			return
	if DisplayServer.get_name() != "headless":
		# La foto es la sala, no la pantalla: sin el HUD (reloj, subtítulo) ni el grano del recuerdo en el cuadro.
		var hud := main.get("hud") as CanvasItem if main != null else null
		var hud_was := hud.visible if hud != null else false
		if hud != null:
			hud.visible = false
		await get_tree().process_frame
		await RenderingServer.frame_post_draw  # (sin pantalla nunca llega: la foto queda en blanco)
		var img := get_viewport().get_texture().get_image() if get_viewport().get_texture() != null else null
		photo_image = img if img != null and not img.is_empty() else null
		if hud != null and is_instance_valid(hud):
			hud.visible = hud_was
		_save_photo()
		if on_floor:
			await _photo_variants(cam)  # (2 o 3 fotogramas más con todos quietos, antes del flash)
	photo_taken = true
	AudioManager.play_sfx("foto_obturador", "Sala")
	var layer := CanvasLayer.new()
	layer.name = "FotoPromocion"
	layer.layer = 26
	get_tree().root.add_child(layer)
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 1)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.7)
	var card := _polaroid()
	card.modulate.a = 0.0
	layer.add_child(card)
	var tw3 := create_tween()
	tw3.tween_interval(0.35)
	tw3.tween_property(card, "modulate:a", 1.0, 0.5)
	var hold := 0.3 if fast else 4.6
	await PersonajesP5.wait(self, hold)
	if cam != null and is_instance_valid(cam):  # detrás de la polaroid la vista vuelve a tus ojos y todos a su sitio
		if prev != null and is_instance_valid(prev):
			prev.current = true
		cam.queue_free()
		if double != null and is_instance_valid(double):
			double.queue_free()
		if own_rig != null and is_instance_valid(own_rig):
			own_rig.visible = true
		if stage != null:
			stage.set_scene("clase", fast)
	if is_instance_valid(layer):
		var tw2 := create_tween()
		tw2.tween_property(card, "modulate:a", 0.0, 0.5)
		await tw2.finished
		layer.queue_free()


## ¿Ya están todos quietos en su sitio de la foto?
func _photo_ready() -> bool:
	if stage == null or not stage.ready_on_floor():
		return true
	if trainer.is_walking() or trainer.mode() != "foto":
		return false
	for a in stage.promo:
		if is_instance_valid(a) and a.is_walking():
			return false
	return true


## Funde la pantalla a negro (1) o desde negro (0) en `secs` (la foto cambia de cámara detrás).
func _fade(to: float, secs: float) -> void:
	var layer := get_tree().root.get_node_or_null("FundidoTraining") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "FundidoTraining"
		layer.layer = 24
		get_tree().root.add_child(layer)
		var r := ColorRect.new()
		r.name = "Negro"
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.color = Color(0, 0, 0, 0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
	var rect := layer.get_node("Negro") as ColorRect
	if secs <= 0.0:
		rect.color.a = to
	else:
		var tw := create_tween()
		tw.tween_property(rect, "color:a", to, secs)
		await tw.finished
	if to <= 0.0 and is_instance_valid(layer):
		layer.queue_free()


func _polaroid() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(560, 470)
	card.position = Vector2(1920 * 0.5 - 280, 1080 * 0.5 - 250)
	card.pivot_offset = Vector2(280, 235)
	card.rotation_degrees = -3.5
	root.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(524, 360)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if photo_image != null:
		pic.texture = ImageTexture.create_from_image(photo_image)
	vb.add_child(pic)
	var cap := UITheme.label(Loc.fmt(tr("TUT_FOTO_CAPTION"), {"fecha": Flashback.date_text(GameState.agent)}), 20, Color(0.18, 0.16, 0.3))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(cap)
	return root


## La firma: el contrato en papel; espera la firma (o el bot). El fotograma que falla lo hace ContractUI.
func _sign_contract() -> void:
	if contract_signed:
		return
	_panel.visible = false
	var pl := _player()
	if pl != null:
		pl.input_locked = true
	if stage != null:
		stage.cue("firman")  # cada uno con su contrato: la promoción firma el suyo mientras lees
	contract = ContractUI.new()
	contract.agent = GameState.agent
	contract.date_text = Flashback.date_text(GameState.agent)
	get_tree().root.add_child(contract)
	var done := [false]
	contract.signed.connect(func(read_all: bool) -> void:
		contract_read = read_all
		done[0] = true)
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	contract_signed = true
	_bot_signing = false
	if is_instance_valid(contract):
		_keep_signature(contract.strokes)
	await PersonajesP5.wait(self, 0.25)
	if is_instance_valid(contract):
		contract.queue_free()
	contract = null
	if pl != null and is_instance_valid(pl):
		pl.input_locked = false
		if pl.seated:
			pl.capture_mouse(false)
	if stage != null:
		stage.cue("firmaron")  # la promoción suelta el lapicero y festeja contigo
	if trainer != null and is_instance_valid(trainer):
		trainer.applaud()
	# El panel vuelve con el paso siguiente (la foto): aquí solo se oye al Trainer. Lo que dice depende de si leíste.
	await _speak(["t_firmado", "t_leyo" if contract_read else "t_no_leyo"])


## Guarda los trazos de la firma, normalizados a su caja (x de 0 a 1; y en la misma escala) y aligerados (≤ 240 puntos).
func _keep_signature(strokes: Array) -> void:
	signature = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var total := 0
	for st in strokes:
		for p in (st as PackedVector2Array):
			lo = lo.min(p)
			hi = hi.max(p)
			total += 1
	if total < 2 or hi.x - lo.x < 1.0:
		return
	var k := 1.0 / (hi.x - lo.x)
	var every := maxi(1, int(ceil(total / 240.0)))
	for st in strokes:
		var pts := st as PackedVector2Array
		var flat: Array = []
		for i in pts.size():
			if i % every == 0 or i == pts.size() - 1:
				flat.append(snappedf((pts[i].x - lo.x) * k, 0.001))
				flat.append(snappedf((pts[i].y - lo.y) * k, 0.001))
		if flat.size() >= 4:
			signature.append(flat)


## Las otras copias de la foto, para los ecos de la semana (RecuerdosSemana): la misma toma entera, sin Zuly, y sin Zuly
## ni Kenyi. Se sacan en un visor aparte que mira el mismo mundo con otra máscara de capas: en tu pantalla no cambia nada.
func _photo_variants(cam: Camera3D) -> void:
	if stage == null or cam == null or not is_instance_valid(cam) or DisplayServer.get_name() == "headless":
		return
	var gone: Array = [stage.actor("Ttoom"), stage.actor("Juan")]
	var touched: Array = []  # [VisualInstance3D, capas de antes]
	for i in gone.size():
		if gone[i] == null:
			continue
		for v in (gone[i] as Node).find_children("*", "VisualInstance3D", true, false):
			touched.append([v, (v as VisualInstance3D).layers])
			(v as VisualInstance3D).layers = 1 << (10 + i)  # capas 11 y 12: las cámaras normales las ven; el visor, según la copia
	var sv := SubViewport.new()
	sv.name = "VisorFoto"
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)  # sin mundo propio: mira el mismo World3D (con su ambiente)
	var c2 := Camera3D.new()
	sv.add_child(c2)
	c2.global_transform = cam.global_transform
	c2.fov = cam.fov
	c2.current = true
	var all := 0xFFFFF
	var masks := [all, all & ~(1 << 10), all & ~(1 << 10) & ~(1 << 11)]
	for k in masks.size():
		c2.cull_mask = masks[k]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_inside_tree() or not is_instance_valid(sv):
			break
		var img := sv.get_texture().get_image()
		if img != null and not img.is_empty():
			var path := RecuerdosSemana.photo_path(GameState.agent, k + 1)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			img.save_jpg(path, 0.85)
	for t in touched:
		if is_instance_valid(t[0]):
			(t[0] as VisualInstance3D).layers = int(t[1])
	if is_instance_valid(sv):
		sv.queue_free()


## Corte seco al presente: «Lunes 9 de noviembre de 2026 — N después» y el contraste del fotocheck y el espejo.
func _present_cut() -> void:
	present_cut_shown = true
	_panel.visible = false
	_hint_low(true)
	if AudioManager.music_slot == "musica/" + MUSIC:
		AudioManager.stop_music()  # corte seco: la música cálida se va con el recuerdo
	_subtitle_style(false)
	Flashback.active = false
	GameState.clock_shift = 0.0
	if _fb_layer != null and is_instance_valid(_fb_layer):
		_fb_layer.queue_free()
	var cut := Flashback.present_cut(get_tree().root, GameState.agent)
	var done := [false]
	cut.finished.connect(func() -> void: done[0] = true)
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree():
		_panel.visible = true


## Bot/pruebas: firma ya (si el contrato está en la mesa).
func bot_sign(read: bool = true, animate: bool = false) -> bool:
	if contract != null and is_instance_valid(contract) and not contract.is_signed and not _bot_signing:
		_bot_signing = true
		contract.sign_for_bot(read, animate)
		return true
	return false


var _bot_signing: bool = false


## Bot/pruebas: apura el corte al presente.
func bot_skip_cut() -> void:
	var c := get_tree().root.get_node_or_null("CortePresente")
	if c != null and c.has_method("finish"):
		c.call("finish")

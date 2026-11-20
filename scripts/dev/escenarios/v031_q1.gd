extends RefCounted
## Escenarios del paquete Q1 de la v0.3.1 (PLAN_v0.3.1 §3 Q1 y §4, prefijo q1_, contrato C11).
## Los 9 repros de qa_plan031/repro/p9_repro.gd pasan a ser pruebas con las condiciones al revés (q1_r_*), más una
## prueba por arreglo (B3, B5, B7, B9/F7, F4, F5, F6, F9, F10, F14, F17, F20, F21, F26) y la auditoría de bucles tras
## reaparecer para cada causa de muerte (q1_bucles_todas: reaparece y espera 60 s reales sin hacer nada).

var p5: Object = null
var p3: Object = null


func escenarios() -> Array[String]:
	return [
		"q1_r_b3_pc", "q1_r_b7_blur", "q1_r_b9_dms", "q1_r_f7_dms", "q1_r_f4_calib", "q1_r_f6_feedback", "q1_r_f17_haime",
		"q1_r_f20_rasec", "q1_r_f20_rasec_parado",
		"q1_b5_barra_apps", "q1_b7_aviso", "q1_f6_pausa_encima", "q1_f4_trainer", "q1_f4_haime_pone_coaching", "q1_f6_capas", "q1_f6_pararse_a_mitad",
		"q1_f6_pararse_dada", "q1_f9_cuarta", "q1_f9_dificil_tercera", "q1_f10_encuadre", "q1_f14_segunda_siesta",
		"q1_f5_tercer_break", "q1_f5_tercer_break_facil", "q1_f17_contacto_nuevo", "q1_f20_plazos_sentado", "q1_f20_gracia",
		"q1_f21_presets", "q1_f21_cupos", "q1_f21_opcion", "q1_f26_salto", "q1_f26_molinete", "q1_salir_del_puff", "q1_levantarse_libre", "q1_atrapado_watchdog", "q1_haime_segun_caso", "q1_bucles_todas",
		"q1_f23_timbre", "q1_c12_rta_gracia", "q1_f23_allocation_tras_morir", "q1_f23_orden_lunch", "q1_f23_correo_congelado", "q1_f23_permiso_topico", "q1_f10_aviso_fuera",
	]


func _p5() -> Object:
	if p5 == null:
		p5 = (load("res://scripts/dev/escenarios/p5_personajes.gd") as GDScript).new()
	return p5


func _p3() -> Object:
	if p3 == null:
		p3 = (load("res://scripts/dev/escenarios/p3_disciplina.gd") as GDScript).new()
	return p3


func _ws(t: Node) -> Control:
	return t.main.get_node("UI/Workstation") as Control


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"q1_r_b3_pc": await _b3(t)
		"q1_r_b7_blur": await _b7(t)
		"q1_r_b9_dms": await _dms(t, false)
		"q1_r_f7_dms": await _dms(t, true)
		"q1_r_f4_calib": await _f4_calib(t)
		"q1_r_f6_feedback": await _f6_feedback(t)
		"q1_r_f17_haime": await _f17(t)
		"q1_r_f20_rasec": await _f20(t, false)
		"q1_r_f20_rasec_parado": await _f20(t, true)
		"q1_b5_barra_apps": await _b5(t)
		"q1_b7_aviso": await _b7_hint(t)
		"q1_f4_trainer": await _f4_trainer(t)
		"q1_f4_haime_pone_coaching": await _f4_haime(t)
		"q1_f6_capas", "q1_f6_pausa_encima": await _f6_layers(t)
		"q1_f6_pararse_a_mitad": await _f6_stand(t, false)
		"q1_f6_pararse_dada": await _f6_stand(t, true)
		"q1_f9_cuarta": await _f9(t, 1)
		"q1_f9_dificil_tercera": await _f9(t, 2)
		"q1_f10_encuadre": await _f10(t)
		"q1_f14_segunda_siesta": await _f14(t)
		"q1_f5_tercer_break": await _f5(t, false)
		"q1_f5_tercer_break_facil": await _f5(t, true)
		"q1_f17_contacto_nuevo": await _f17_new(t)
		"q1_f20_plazos_sentado": await _f20_seated(t)
		"q1_f20_gracia": await _f20_grace(t)
		"q1_f21_presets": await _f21_presets(t)
		"q1_f21_cupos": await _f21_quotas(t)
		"q1_f21_opcion": await _f21_option(t)
		"q1_f26_salto": await _f26(t)
		"q1_f26_molinete": await _f26_turnstile(t)
		"q1_salir_del_puff": await _wake_free(t)
		"q1_levantarse_libre": await _stand_free(t)
		"q1_atrapado_watchdog": await _watchdog(t)
		"q1_haime_segun_caso": await _haime_case(t)
		"q1_bucles_todas": await _loops(t)
		"q1_f23_timbre": await _ring(t)
		"q1_c12_rta_gracia": await _rta_grace(t)
		"q1_f23_allocation_tras_morir": await _alloc_respawn(t)
		"q1_f23_orden_lunch": await _lunch_order(t)
		"q1_f23_correo_congelado": await _correo_frozen(t)
		"q1_f23_permiso_topico": await _topico_permit(t)
		"q1_f10_aviso_fuera": await _tip_outside(t)


# --- ayudas ----------------------------------------------------------------------------------------

## Espera `s` segundos reales del juego (escalados) contando cuadros, y devuelve lo que pasó.
func _idle(t: Node, s: float, stop: Callable = Callable()) -> float:
	var w := 0.0
	while w < s:
		if stop.is_valid() and bool(stop.call()):
			return w
		await t.frames(1)
		w += t.get_tree().root.get_process_delta_time()
	return w


func _haime_session(t: Node, hub: PersonajesP5, marks: Array = ["prometer_sin_verificar"]) -> void:
	_p5().call("_bad_contact", marks)
	await t.frames(1)
	hub.qa.call_now()
	await t.frames(1)
	await _p5().call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)


# --- Repros al revés (qa_plan031/repro/p9_repro.gd) -------------------------------------------------

## B3: sentado con la PC acercada → menú → turno nuevo con otro agente: la PC no queda abierta.
func _b3(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	_ws(t).call("set_zoom", true)
	await t.frames(2)
	t.check(_ws(t).visible and bool(_ws(t).get("zoomed")), "sentado con la PC acercada (condición del repro)")
	await t.back_to_menu()
	t.check(not _ws(t).visible and not bool(_ws(t).get("zoomed")), "tras volver al menú la PC está cerrada")
	t.check(not bool(GameState.flags.get("pc_zoom", false)) and not bool(GameState.flags.get("aux_menu_open", false)), "sin flags pc_zoom / aux_menu_open")
	await t.start_shift("Llauri", 1)
	await t.frames(5)
	t.check(GameState.current_floor == -1 and GameState.seated_at == "", "turno nuevo en la calle, de pie")
	t.check(not _ws(t).visible and not bool(_ws(t).get("zoomed")), "turno nuevo: la PC NO aparece al bajar del bus (ws.visible=%s zoomed=%s)" % [_ws(t).visible, _ws(t).get("zoomed")])
	t.check(int(_ws(t).call("screen_height")) == PcStyle.H, "las pantallas vuelven al alto de los monitores 3D")


## B7: Fatiga 45 y 60 s sin frotarse → borroso (con tope 0,6); al reconectar y en un turno nuevo, 0.
func _b7(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	Fatigue.set_value(45.0)
	await t.login_at_seat()  # el checkpoint del login lleva la Fatiga 45 (reaparece con 60: el caso del bug)
	GameState.stop_calm()
	await t.seconds(60.0)
	var b := Fatigue.blur_amount()
	t.check(b > 0.3 and b <= 0.6 + 0.001, "Fatiga 45, 60 s sin frotarse: desenfoque con tope 0,6 (%.2f)" % b)
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.seconds(5.0)
	await t.reconnect()
	var r0: float = t.game_s()
	await t.seconds(0.5)
	t.check(Fatigue.value >= 40.0, "tras reconectar la Fatiga sigue ≥ 40 (%.0f): el caso del bug" % Fatigue.value)
	# v0.3.2-core3: el parpadeo se mide contra lo que de verdad pasó desde reconectar (con la máquina cargada un solo
	# cuadro largo a escala 8 son 2 s de juego y «< 1.0» fallaba sin que hubiera fallo: el contador sí se reinicia).
	t.check(Fatigue.blur_amount() == 0.0 and Fatigue.blink_timer() < 1.0 + (t.game_s() - r0), "tras reconectar NO está borroso (blur %.2f, parpadeo %.1f s, pasaron %.1f s)" % [Fatigue.blur_amount(), Fatigue.blink_timer(), t.game_s() - r0])
	await t.seconds(30.0)
	t.check(Fatigue.blur_amount() == 0.0, "30 s después sigue nítido")
	await t.seconds(16.0)
	t.check(Fatigue.blur_amount() > 0.0, "a los 40-46 s vuelve a desenfocar (%.2f)" % Fatigue.blur_amount())
	await t.back_to_menu()
	await t.start_shift("Llauri", 1)
	Fatigue.set_value(45.0)
	await t.frames(3)
	t.check(Fatigue.blur_amount() == 0.0 and Fatigue.blink_timer() < 1.0, "turno nuevo con Fatiga 45: nítido desde el primer cuadro (%.2f)" % Fatigue.blur_amount())


## B9/F7: correr sin login = 0 mensajes; logueado de pie en la sala, 60 s corriendo = ≤ 3 mensajes y sin parpadeo.
func _dms(t: Node, logged: bool) -> void:
	await t.start_shift("Jiroshi", 1)
	if logged:
		await t.login_at_seat()
		GameState.stop_calm()
		t.player().stand_up()
		await t.frames(3)
	var posts: Array = t.spy("ezlak_post")
	var msgs: Array = t.spy("shero_message")
	var steps: Array = t.spy("discipline_step")
	Input.action_press("walk_fast")
	Input.action_press("move_forward")
	var flips := 0
	var was_run := false
	var w := 0.0
	var dur := 60.0 if logged else 12.0
	var pl: Player = t.player()
	while w < dur:
		await t.frames(1)
		var dt := t.get_tree().root.get_process_delta_time()
		w += dt
		# Corre en círculos dentro de la sala (o en la calle): girar evita chocar siempre contra lo mismo.
		# Giro por segundo de juego (no por cuadro): con la máquina cargada los cuadros son largos y el círculo se abría hasta salir.
		pl.rotate_y(1.2 * dt)
		var run_now := Input.is_action_pressed("walk_fast") and not bool(pl.get("_exhausted")) and pl.breath_left > 0.0
		if run_now != was_run:
			flips += 1
		was_run = run_now
	Input.action_release("walk_fast")
	Input.action_release("move_forward")
	var n := 0
	for p in posts:
		if str(p[0]) == "dm:shero" and str(p[1]) == "shero":
			n += 1
	var ns := 0
	for m in msgs:
		if str(m[0]) == "de_pie_en_live":
			ns += 1
	var verbals := 0
	for s in steps:
		if str(s[0]) == "correr":
			verbals += 1
	if not logged:
		t.check(ns == 0 and n == 0, "B9: sin login, 12 s con Shift: 0 avisos de Shero (hubo %d / %d posts)" % [ns, n])
	else:
		t.check(GameState.in_room, "corriendo dentro de la sala")
		t.check(ns + verbals >= 1 and ns + verbals <= 3, "F7: 60 s corriendo en la sala = 1-3 avisos (%d DMs + %d en persona)" % [ns, verbals])
		t.check(n <= 3, "≤ 3 posts en dm:shero (%d)" % n)
	t.check(flips <= int(dur / 2.0), "el aliento agotado no «parpadea» correr/caminar cada cuadro (%d cambios en %.0f s)" % [flips, dur])


## F4: sentado en la silla de calibración (sin llamado): sin PC, sin AUX, sin Ezlaki.
func _f4_calib(t: Node) -> void:
	await _p5().call("_prep", t, 1)
	var aux0 := Metrics.aux
	await _p5().call("_sit", t, "calibracion")
	await t.frames(3)
	t.check(GameState.seated_at == "calibracion", "sentado en 'calibracion'")
	t.check(not _ws(t).visible and not bool(_ws(t).get("zoomed")), "la PC (Fonex/AUX/Ezlaki) NO aparece en la silla de calibración")
	var ev := InputEventAction.new()
	ev.action = "aux_wheel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.frames(2)
	var ev2 := InputEventAction.new()
	ev2.action = "aux_3"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await t.frames(2)
	t.check(Metrics.aux == aux0 and not bool(GameState.flags.get("aux_menu_open", false)), "Q y 1-7 no cambian el AUX ahí (AUX %s)" % Metrics.aux_name())
	t.player().stand_up()
	await t.frames(2)
	await _p5().call("_sit", t, "C-14")
	await t.frames(2)
	t.check(_ws(t).visible, "en C-14 la PC sí está")


## F6: con la FeedbackUI abierta la pausa queda encima; al terminar la sesión no se reabre la PC en la silla.
func _f6_feedback(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	await _p5().call("_call_haime", t, hub)
	await _p5().call("_go_calibration", t)
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)
	var ui = hub.qa.ui
	var main_layer := int((t.main.get_node("UI") as CanvasLayer).layer)
	t.check(ui != null and int(ui.get("layer")) < main_layer, "FeedbackUI (capa %d) debajo de la UI principal (capa %d)" % [int(ui.get("layer")) if ui != null else -1, main_layer])
	await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 150.0)
	await t.frames(3)
	var left := t.get_tree().root.find_children("FeedbackUI", "", true, false).size()
	t.check(left == 0, "fin de la sesión: FeedbackUI fuera del árbol")
	t.check(not _ws(t).visible and not bool(_ws(t).get("zoomed")), "fin de la sesión sentado en calibración: la PC NO se reabre (ws.visible=%s)" % _ws(t).visible)
	t.player().stand_up()
	await t.frames(5)
	t.check(not _ws(t).visible, "de pie: nada en pantalla")


## F17: checkpoint con 3 feedbacks (Normal: max−1) + 1 contacto malo → 4.ª = calibración final → reconectar:
## el pendiente se purga, quedan 3 y Haime no vuelve a llamar (quieto en C-14, 200 s reales).
func _f17(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	var maxn: int = hub.qa.max_per_shift()
	t.check(maxn == 4, "Normal: 4 feedbacks por turno (D2)")
	PersonajesP5.set_counter("p5_qa_feedbacks", maxn - 1)
	PersonajesP5.set_counter("p5_qa_ultimo", GameState.clock_seconds - 3600.0)
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	Checkpoints.save_checkpoint("contacto")
	var seq: Array = t.spy("death_sequence_started")
	hub.qa.call_now()
	await _p5().call("_go_calibration", t)
	await t.until(func() -> bool: return not seq.is_empty(), 150.0)
	t.check(not seq.is_empty() and str(seq[0][0]) == "calibracion_final", "la 4.ª sesión termina en calibracion_final (%s)" % str(seq))
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(3)
	t.check(hub.qa.pending().is_empty(), "tras reaparecer el contacto que causó la llamada se descartó (pendientes %d)" % hub.qa.pending().size())
	t.check(hub.qa.feedbacks_done() == maxn - 1, "feedbacks = max−1 (%d)" % hub.qa.feedbacks_done())
	t.check(hub.qa.state == QaFeedback.State.LIBRE and hub.qa.call_at > 1e9, "sin llamada programada")
	var cp: Dictionary = Checkpoints.last_checkpoint.get("discipline", {}).get("counters", {})
	t.check((cp.get("p5_qa_pend", [1]) as Array).is_empty(), "la purga quedó también en el checkpoint vivo")
	seq.clear()
	_p5().call("_quiet", t)
	# Solo se mide a Haime: el evento de Rasec y el RTA tienen sus propias reglas (un jugador que ignora a Rasec
	# muere por rasec_evento, a propósito; eso lo cubren q1_r_f20_*).
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rta.process_mode = Node.PROCESS_MODE_DISABLED
	var called := false
	var w := 0.0
	while w < 200.0 and seq.is_empty():
		await t.frames(1)
		w += t.get_tree().root.get_process_delta_time()
		if hub.qa.state == QaFeedback.State.LLAMADO:
			called = true
	t.check(not called and seq.is_empty(), "quieto en C-14 200 s reales: Haime no vuelve a llamar ni hay muerte (sin bucle) %s" % str(seq))


## F20: Rasec convoca con el jugador sentado (o de pie): 1.ª advertencia ≥ 30 s reales; tras reaparecer, no vuelve a
## matar en 60 s.
func _f20(t: Node, stand: bool) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2)
	var seq: Array = t.spy("death_sequence_started")
	# v0.3.1 (fusión con Q2): saltar el reloj a las 05:16 de T2 deja pendiente el training de las 02:20 y el RTA
	# exige Training; con su escritorio en el piso 2 su caza llega en el acto (~55 s). Esta prueba mide solo a Rasec.
	hub.rta.process_mode = Node.PROCESS_MODE_DISABLED
	await _p5().call("_rasec_call", t, hub)
	if stand:
		t.player().stand_up()
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), GameState.reloj("de_pie_aux")), "convocado: el reloj a 4x aunque esté %s (%.1fx)" % ["de pie" if stand else "sentado", GameState.clock_speed()])
	var w := 0.0
	var first := -1.0
	while seq.is_empty() and w < 150.0:
		await t.frames(1)
		w += t.get_tree().root.get_process_delta_time()
		if first < 0.0 and hub.rasec.warnings() >= 1:
			first = w
	# El plazo de Rasec corre desde la convocatoria; `w` empieza 2 cuadros + una comprobación después (con la máquina
	# cargada, ~0,5-1 s): margen de 2 s.
	t.check(first < 0.0 or first >= 28.0, "1.ª advertencia a los %.1f s reales (≥ 30, margen de cuadros)" % first)
	t.check(seq.is_empty() or w >= 58.0, "si muere, no antes de los 60 s reales (%.1f)" % w)
	if seq.is_empty():
		hub.rasec.warn("tarde")
		hub.rasec.warn("tarde")
		await t.until(func() -> bool: return not seq.is_empty(), 5.0)
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(2)
	seq.clear()
	w = await _idle(t, 60.0, func() -> bool: return not seq.is_empty())
	t.check(seq.is_empty(), "tras reaparecer, quieto 60 s reales: sin muerte (%s a los %.1f s)" % [str(seq), w])
	t.check(hub.rasec.state != RasecControl.State.CONVOCADO or w >= 59.0, "Rasec no convoca dentro de la gracia")
	hub.rta.process_mode = Node.PROCESS_MODE_INHERIT


# --- Arreglos ----------------------------------------------------------------------------------

## B5/F12: la barra F1-F5 queda dentro de la pantalla en las 5 apps (y con cada caso KYC en Identa), con la vista
## normal y la acercada.
func _b5(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var ws := _ws(t)
	var desk: PcDesktop = ws.get("desktop")
	for zoom in [false, true]:
		ws.call("set_zoom", zoom)
		await t.frames(4)
		for app in PcDesktop.APPS:
			desk.open_app(app)
			await t.frames(4)
			var r: Rect2 = desk.taskbar_rect()
			var h := float(ws.call("screen_height"))
			t.check(r.size.y > 8.0 and r.end.y <= h + 0.5 and r.position.y >= h * 0.6, "%s%s: barra F1-F5 dentro de la pantalla (y %.0f-%.0f de %.0f)" % [app, " (acercada)" if zoom else "", r.position.y, r.end.y, h])
	ws.call("set_zoom", false)
	var cm: ContactManager = t.main.get("contacts")
	var p4c: GDScript = load("res://scripts/dev/escenarios/p4_casos.gd")
	var n := 0
	for c in p4c.call("all_cases"):
		if str((c as Dictionary).get("canal", "")) != "kyc":
			continue
		cm.phase = ContactManager.Phase.IDLE
		cm.current = {}
		cm._offer((c as Dictionary).duplicate(true))
		cm.accept()
		desk.open_app("identa")
		await t.frames(4)
		var r: Rect2 = desk.taskbar_rect()
		if r.end.y > float(ws.call("screen_height")) + 0.5 or r.size.y < 8.0:
			t.fail("KYC %s: la barra sale de la pantalla (%.0f)" % [str(c.get("id", "")), r.end.y])
		n += 1
		cm.kyc_decide(str(c.get("correcto", "rechazar")))
		await t.frames(2)
	t.check(n >= 3, "%d casos KYC revisados con la barra a la vista" % n)


## B7: el aviso «[R] Frotarte los ojos» sale una vez por turno en Normal (no en Difícil).
func _b7_hint(t: Node) -> void:
	for dif in [1, 2]:
		await t.start_shift("Jiroshi", 1, 0, dif)
		await t.login_at_seat()
		GameState.stop_calm()
		Fatigue.set_value(48.0)
		var seen: Array = [false]  # las lambdas capturan por valor: un Array para poder marcarlo
		var ov: Node = t.main.get("overlays")
		await _idle(t, 47.0, func() -> bool:
			if ov != null and bool(ov.call("hint_visible")):
				seen[0] = true
			return false)
		if dif == 1:
			t.check(bool(seen[0]) and (Fatigue.blur_hint_text.contains("[R]") or Fatigue.blur_hint_text.contains("rub your eyes")), "Normal: el aviso sale nítido encima del desenfoque («%s»)" % Fatigue.blur_hint_text)
			t.check(ov != null and (ov.get("_hint") as Control).get_index() > (ov.get("_blur") as Control).get_index(), "el aviso va después del rectángulo del desenfoque (no sale borroso)")
		Fatigue.rub_eyes()
		await t.frames(3)
		t.check(Fatigue.blur_hint_left <= 0.6, "al frotarse los ojos el aviso se va")
		await t.seconds(47.0)
		var n := Fatigue.blur_hints_shown
		if dif == 1:
			t.check(n == 1, "Normal: el aviso de frotarse los ojos sale una sola vez en el turno (%d)" % n)
		else:
			t.check(n == 0, "Difícil: sin aviso (%d)" % n)
		await t.back_to_menu()


## F4: el Trainer te pone en Training al sentarte en la sala 2 (sin PC ahí).
func _f4_trainer(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2)
	await _p5().call("_training_call", t, hub)
	t.check(is_equal_approx(GameState.clock_speed(), GameState.reloj("de_pie_aux")), "convocado por el Trainer: 4x sentado en C-14 (%.1fx)" % GameState.clock_speed())
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	var subs: Array = t.spy("subtitle")
	await _p5().call("_floor", t, 1)
	await _p5().call("_sit", t, "training_sala2_3")
	await t.frames(3)
	t.check(not _ws(t).visible, "silla del training: sin PC")
	t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.SESION, 3.0), "sentado en Available: el Trainer te pone en Training y empieza la clase")
	var said_pone := false
	for sb in subs:
		if str(sb[1]).contains(t.tr("Q1_TRAINER_PONE_TRAINING")):
			said_pone = true
	t.check(Metrics.aux == Metrics.Aux.TRAINING and said_pone, "AUX Training puesto por el Trainer («Te pongo en Training yo»)")
	t.check(is_equal_approx(GameState.clock_speed(), GameState.reloj("training")) and is_equal_approx(GameState.reloj("training"), 24.0), "reloj del training 24x (v0.3.1)")


## F4: Haime te pone en Coaching al sentarte en la sala de calibración (cuenta como llegar a tiempo).
func _f4_haime(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	var seq: Array = t.spy("death_sequence_started")
	await _p5().call("_call_haime", t, hub)
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE, "sigue en Available")
	await _p5().call("_floor", t, 2)
	await _p5().call("_sit", t, "calibracion")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "sentado sin Coaching: Haime te pone en Coaching y empieza")
	t.check(Metrics.aux == Metrics.Aux.COACHING and not _ws(t).visible, "AUX Coaching puesto por Haime; sin PC")
	t.check(seq.is_empty(), "sin muerte")


## F6: todas las capas de P5 debajo de la UI principal; la pausa se ve con la FeedbackUI abierta.
func _f6_layers(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	await _haime_session(t, hub)
	var main_layer := int((t.main.get_node("UI") as CanvasLayer).layer)
	for path in ["res://scripts/ui/feedback_ui.gd", "res://scripts/ui/qa_rec.gd", "res://scripts/ui/quiz_ui.gd", "res://scripts/ui/evento_ui.gd"]:
		var src := (load(path) as GDScript).source_code
		t.check(src.contains("\tlayer = 0"), "%s: capa 0, debajo de la UI principal (%d)" % [path.get_file(), main_layer])
	# Todo lo que puede estar en pantalla a la vez durante una calibración: FeedbackUI + REC + un quiz y un evento
	# de prueba + un panel tipo inducción en capa alta + una capa tipo screamer.
	var extra: Array[CanvasLayer] = []
	var q := QuizUI.new()
	q.name = "QuizPrueba"
	t.get_tree().root.add_child(q)
	extra.append(q)
	for pair in [["TutorialUIPrueba", 25], ["ScreamerPrueba", 20], ["AscensorPrueba", 20]]:
		var cl := CanvasLayer.new()
		cl.name = str(pair[0])
		cl.layer = int(pair[1])
		var cr := ColorRect.new()
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cl.add_child(cr)
		t.get_tree().root.add_child(cl)
		extra.append(cl)
	await t.frames(2)
	var before: Dictionary = {}
	for n in t.get_tree().root.find_children("*", "CanvasLayer", true, false):
		before[n] = (n as CanvasLayer).visible
	var pm: Control = t.main.get("pause_menu")
	pm.call("toggle")
	await t.frames(2)
	t.check(pm.visible and t.get_tree().paused, "pausa abierta con la sesión en curso")
	var pl: CanvasLayer = t.main.get("pause_layer")
	t.check(pl != null and pm.get_parent() == pl, "la pausa vive en su propia capa (%d)" % (pl.layer if pl != null else -1))
	var top_ok := true
	var hidden_ok := true
	var n_layers := 0
	for n in t.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		n_layers += 1
		if cl == pl:
			continue
		if cl.visible and cl.layer >= pl.layer:
			top_ok = false
			t.note("capa encima o igual que la pausa: %s (%d)" % [cl.get_path(), cl.layer])
		if cl.visible and cl != t.main.get_node("UI"):
			hidden_ok = false
			t.note("capa visible con la pausa abierta: %s (%d)" % [cl.get_path(), cl.layer])
	t.check(top_ok, "ninguna de las %d CanvasLayers queda encima de la pausa" % n_layers)
	t.check(hidden_ok, "con la pausa abierta las demás capas se ocultan (la UI principal queda atenuada por el fondo de la pausa)")
	pm.call("toggle")
	await t.frames(2)
	var restored := true
	for n in before.keys():
		if is_instance_valid(n) and (n as CanvasLayer).visible != bool(before[n]):
			restored = false
	t.check(restored and not t.get_tree().paused, "al cerrar la pausa vuelve todo como estaba")
	for cl in extra:
		cl.queue_free()
	await t.frames(2)


## F6: pararse durante la sesión. Antes de las 3 oportunidades = «te fuiste a mitad» (vuelve a llamarte desde el
## aviso); después = sesión dada.
func _f6_stand(t: Node, after_three: bool) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	var seq: Array = t.spy("death_sequence_started")
	await _haime_session(t, hub, ["prometer_sin_verificar", "respuesta_vaga"])
	t.check(t.player().input_locked, "1.ª línea: sin control")
	t.check(await t.until(func() -> bool: return not t.player().input_locked, 20.0), "desde la 2.ª línea te puedes parar")
	if after_three:
		# v0.3.1 (fusión con Q4): las oportunidades salen del guion de HaimeGuion, una por marca real (aquí 2).
		# v0.3.2-core4 (punto 9): pararte solo «da» la sesión cuando además ya no queda más que el cierre (antes bastaba con
		# las oportunidades y se saltaba lo que viniera después; la estructura es al azar, así que se espera a las dos cosas).
		await t.until(func() -> bool: return hub.qa.heard_opportunities >= hub.qa.session_opportunities and bool(hub.qa.call("_only_closing_left")), 120.0)
	else:
		# v0.3.2: con 2 marcas, al decir la 2.ª línea seguro que no escuchaste las dos (la estructura es al azar).
		await t.until(func() -> bool: return hub.qa.session_log.size() >= 2, 30.0)
	t.player().stand_up()
	await t.frames(4)
	t.check(t.get_tree().root.find_children("FeedbackUI", "", true, false).is_empty(), "al pararte la pantalla del feedback se va")
	t.check(not Discipline.is_frozen() and GameState.clock_override == "" and not t.player().input_locked, "todo descongelado, con control")
	if after_three:
		t.check(hub.qa.last_session_end == "dada" and hub.qa.feedbacks_done() == 1 and hub.qa.state == QaFeedback.State.LIBRE, "con todas las oportunidades escuchadas y solo el cierre por delante cuenta como dada (%s, %d)" % [hub.qa.last_session_end, hub.qa.feedbacks_done()])
	else:
		t.check(hub.qa.last_session_end == "a_mitad" and hub.qa.feedbacks_done() == 0, "a mitad: no cuenta (%s)" % hub.qa.last_session_end)
		t.check(hub.qa.state == QaFeedback.State.LLAMADO and hub.qa.noshow_warned, "Haime vuelve a llamarte desde el aviso")
		var left: float = hub.qa.seconds_left()
		t.check(left > 60.0 and left <= 3.0 * 60.0 + 1.0, "quedan los minutos de juego del plazo tras el aviso (%.0f s)" % left)
		await _p5().call("_go_calibration", t)
		t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0), "volver a sentarse reanuda la sesión")
	t.check(seq.is_empty(), "sin muerte")


## F9 (D2): Normal: 3 sesiones sobreviven (la 3.ª = advertencia), la 4.ª mata tras la 3.ª oportunidad.
## Difícil: la 3.ª mata (la 2.ª es la advertencia).
func _f9(t: Node, dif: int) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1, true, dif)
	var seq: Array = t.spy("death_sequence_started")
	var maxn: int = hub.qa.max_per_shift()
	t.check(maxn == (4 if dif <= 1 else 3), "máximo por turno: %d" % maxn)
	PersonajesP5.set_counter("p5_qa_feedbacks", maxn - 2)
	for n in [maxn - 1, maxn]:
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		await _haime_session(t, hub)
		t.check(hub.qa.n_call == n, "sesión %d" % n)
		if n < maxn:
			await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 150.0)
			t.check(seq.is_empty(), "la %d.ª sobrevive" % n)
			t.check(hub.qa.session_log.has("advertencia_cierre"), "la %d.ª es la última advertencia: «La próxima es la calibración de la muerte» (%s)" % [n, str(hub.qa.session_log)])
			t.check(str((DataLoader.dict("lineas_haime").get("advertencia_cierre", {}) as Dictionary).get("es", "")).to_lower().contains("la próxima es la calibración de la muerte"), "texto de la advertencia")
			t.player().stand_up()
			await t.frames(2)
		else:
			await t.until(func() -> bool: return not seq.is_empty(), 150.0)
			t.check(not seq.is_empty() and str(seq[0][0]) == "calibracion_final", "la %d.ª mata (calibracion_final)" % n)
			# v0.3.2: la última «oportunidad» de la fatal ya no es del contacto (grupo fatal_om; sin él, fb3_om3); después
			# solo queda la frase de la certeza y el cierre.
			var log: Array = hub.qa.session_log
			var last_om := -1
			for i in log.size():
				if str(log[i]).begins_with("h2_fom_") or str(log[i]) == "fb3_om3":
					last_om = i
			var close := log.find("fb3_cierre")
			t.check(last_om >= 0 and close == log.size() - 1 and close - last_om <= 2, "mata apenas terminan las oportunidades (%s)" % str(log))


## F10: encuadre de la vista acercada en 16:9 (1280×720 / 1920×1080 / 2560×1440 → 1920×1080 lógicos), 16:10 y 21:9.
func _f10(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var ws := _ws(t)
	for sz in [Vector2(1920, 1080), Vector2(1920, 1200), Vector2(2520, 1080), Vector2(1440, 1080)]:
		ws.set("layout_area_override", sz)  # la vista lógica de 16:9, 16:10, 21:9 y 4:3 (headless no cambia la ventana)
		for layout in [0, 1]:
			ws.set("_layout", layout)
			ws.call("set_zoom", true)
			await t.frames(4)
			ws.call("_layout_zoom")
			await t.frames(2)
			var area: Vector2 = sz
			var r: Rect2 = ws.call("zoom_rect")
			var wf := r.size.x / area.x
			var hf := r.size.y / area.y
			var lbl := "%dx%d %s" % [sz.x, sz.y, "dos pantallas" if layout == 0 else "una pantalla (Tab)"]
			if layout == 0 and sz.x / sz.y < 1.5:
				t.check(wf >= 0.84 and hf >= 0.45, "%s (4:3): pantallas %.0f %% del ancho y %.0f %% del alto" % [lbl, wf * 100.0, hf * 100.0])
			elif layout == 0:
				t.check(wf >= 0.84 and hf >= 0.62 and wf <= 0.9 and hf <= 0.8, "%s: pantallas %.0f %% del ancho y %.0f %% del alto (84-90 / 62-80: queda la sala)" % [lbl, wf * 100.0, hf * 100.0])
			else:
				t.check(hf >= 0.62 and wf >= 0.5, "%s: %.0f %% × %.0f %%" % [lbl, wf * 100.0, hf * 100.0])
			t.check(r.position.x >= -1.0 and r.end.x <= area.x + 1.0 and r.position.y >= -1.0 and r.end.y <= area.y + 1.0, "%s: dentro de la vista" % lbl)
			t.check(wf < 0.995 or hf < 0.995, "%s: queda sala alrededor" % lbl)
	ws.set("layout_area_override", Vector2.ZERO)
	ws.set("_layout", 0)
	ws.call("set_zoom", false)
	await t.frames(3)
	t.check(int(ws.call("screen_height")) == PcStyle.H, "sin acercar, las pantallas vuelven a 800×492 (monitores 3D)")
	var bd := ws.get("_backdrop") as ColorRect
	t.check(bd != null and bd.color.a <= 0.36, "fondo de la vista acercada al 35 % (antes 82 %)")


## F14: 2.ª vez dormido en el lunch: sin escalones intermedios, persecución en ≤ 2 s reales al vencer el lunch.
func _f14(t: Node) -> void:
	await _p3().call("_prep", t)
	var steps: Array = t.spy("discipline_step")
	var hunts: Array = t.spy("pursuit_started")
	Discipline.counters["perdon_dormido"] = true
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await _p3().call("_go", t, -1, "descanso_m1")
	var puff := t.building().floor_node.find_child("Dormir_puff_1", true, false) as SleepSpot
	t.check(puff != null, "puff en el -1")
	if puff == null:
		return
	puff.interact(t.player())
	await t.frames(3)
	t.check(SleepSpot.is_player_sleeping(), "dormido")
	var t_lunch := GameState.clock_seconds
	await _p3().call("_adv", t, 42.0 * 60.0, 20.0)  # dormido el reloj corre a 30x también entre cuadros
	t.check(hunts.is_empty() and GameState.clock_seconds - t_lunch < 45.0 * 60.0, "antes de los 45 min no pasa nada (%.1f min)" % ((GameState.clock_seconds - t_lunch) / 60.0))
	await t.until(func() -> bool: return GameState.clock_seconds - t_lunch >= 45.0 * 60.0, 30.0)
	var w := await _idle(t, 2.0, func() -> bool: return not hunts.is_empty())
	t.check(not hunts.is_empty() and str(hunts[0][1]) == "lunch_excedido", "persecución del lunch en %.1f s reales (≤ 2)" % w)
	var lunch_low := 0
	for s in steps:
		if str(s[0]) == "lunch" and int(s[1]) < Discipline.Step.PERSECUCION:
			lunch_low += 1
	t.check(lunch_low == 0, "sin llamado, verbal ni WW del lunch (hubo %d)" % lunch_low)
	t.check(Discipline.step_of("lunch") == Discipline.Step.PERSECUCION, "pista del lunch en persecución")
	var seq: Array = t.spy("death_sequence_started")
	await t.until(func() -> bool: return not seq.is_empty(), 90.0)
	t.check(not seq.is_empty() and str(seq[0][0]) == "lunch_excedido", "la 2.ª siesta no tiene perdón: lunch_excedido (%s)" % str(seq))


## F5: el 3.er break = Shero sale corriendo desde donde está (no muerte en el acto) y te alcanza; Fácil sentado no salva.
func _f5(t: Node, facil: bool) -> void:
	await _p3().call("_prep", t, 1, 0 if facil else 1)
	var seq: Array = t.spy("death_sequence_started")
	var hunts: Array = t.spy("pursuit_started")
	for i in 2:
		Metrics.set_aux(Metrics.Aux.BREAK)
		await _p3().call("_adv", t, 60.0)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await _p3().call("_adv", t, 60.0)
	var escala := Engine.time_scale
	Engine.time_scale = 1.0  # con la máquina cargada, 6 cuadros a 8x ya alcanzan los 4,9 m de Shero
	Metrics.set_aux(Metrics.Aux.BREAK)
	await t.frames(3)
	if facil:
		t.check(seq.is_empty() and Metrics.breaks_used == 2, "Fácil: confirmación previa")
		Metrics.set_aux(Metrics.Aux.BREAK)
		await t.frames(3)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)  # vuelve a Available sentado en C-14: en Fácil, otras persecuciones perdonan
	await t.frames(3)
	Engine.time_scale = escala
	t.check(seq.is_empty() or not hunts.is_empty(), "no hay muerte instantánea (si ya hubo muerte, vino de la persecución: %s)" % str(seq))
	t.check(not hunts.is_empty() and str(hunts[0][0]) == "shero" and str(hunts[0][1]) == "tercer_break", "Shero sale con la persecución del 3.er break (%s)" % str(hunts))
	await t.until(func() -> bool: return not seq.is_empty(), 90.0)
	t.check(not seq.is_empty() and str(seq[0][0]) == "tercer_break" and str(seq[0][1]) == "shero", "te alcanza: tercer_break por Shero (%s)" % str(seq))


## F17: tras la purga, la siguiente llamada exige un contacto malo NUEVO y respeta los 60 min de margen.
func _f17_new(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	PersonajesP5.set_counter("p5_qa_feedbacks", 3)
	PersonajesP5.set_counter("p5_qa_ultimo", GameState.clock_seconds - 3600.0)
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	Checkpoints.save_checkpoint("contacto")
	hub.qa.call_now()
	await t.frames(2)
	await t.die("qa_inasistencia", "", "haime")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(3)
	t.check(hub.qa.pending().is_empty() and hub.qa.state == QaFeedback.State.LIBRE, "qa_inasistencia también purga")
	var t0 := GameState.clock_seconds
	await t.advance_clock(70.0 * 60.0)
	t.check(hub.qa.state == QaFeedback.State.LIBRE, "70 min de juego sin contacto malo nuevo: no llama")
	_p5().call("_bad_contact", ["respuesta_vaga"])
	await t.frames(1)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE and hub.qa.call_at >= t0 + 3600.0 - 1.0, "contacto malo nuevo: llamada programada (≥ 60 min tras la muerte)")
	# Respawn por otra causa desde el mismo checkpoint: la purga no se deshace.
	await t.die("colapso", "", "")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(2)
	var back := false
	for e in hub.qa.pending():
		if ((e as Dictionary).get("marcas", []) as Array).has("prometer_sin_verificar"):
			back = true
	t.check(not back, "otro respawn desde el checkpoint no trae de vuelta el contacto purgado (%s)" % str(hub.qa.pending()))


## F20: plazos de Haime y el Trainer con el jugador sentado: ≥ 30 s reales antes de la 1.ª advertencia.
func _f20_seated(t: Node) -> void:
	# Trainer (T2): convocado sentado en C-14 (pone AUX Training en la PC como pide el RTA y se queda leyendo).
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2)
	await _p5().call("_training_call", t, hub)
	Metrics.set_aux(Metrics.Aux.TRAINING)
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "convocado por el Trainer, sentado: 4x (%.1fx)" % GameState.clock_speed())
	var wt := await _idle(t, 300.0, func() -> bool: return hub.training.espera_warned)
	t.check(wt >= 30.0, "aviso del Trainer a los %.1f s reales (≥ 30; antes ~10)" % wt)
	# Haime (T1).
	hub = await _p5().call("_prep", t, 1)
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	await t.frames(1)
	hub.qa.call_now()
	await t.frames(2)
	t.check(Discipline.summons_pending() and is_equal_approx(GameState.clock_speed(), 4.0), "Haime convoca: 4x sentado (%.1fx)" % GameState.clock_speed())
	var w := await _idle(t, 200.0, func() -> bool: return hub.qa.noshow_warned)
	# v0.3.2-core4: con la tabla aprobada (llegar 4 min, aviso a falta de 2) el aviso cae justo en el piso de 30 s reales
	# (2 min de juego a 4x): margen de cuadros, como la 1.ª advertencia de arriba.
	t.check(w >= 29.5, "aviso de Haime a los %.1f s reales (≥ 30 con margen de cuadros; antes 6,7)" % w)


## C12: gracia de 60 s reales tras reaparecer: nadie de P5 convoca; después, sí.
func _f20_grace(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	t.check(Checkpoints.in_respawn_grace() and not hub.can_interrupt(), "gracia tras reaparecer: can_interrupt() = false")
	_p5().call("_bad_contact", ["prometer_sin_verificar"])
	hub.qa.call_at = GameState.clock_seconds
	await _idle(t, 30.0)
	t.check(hub.qa.state != QaFeedback.State.LLAMADO, "a los 30 s Haime todavía no llama")
	await _idle(t, 32.0)
	t.check(not Checkpoints.in_respawn_grace(), "la gracia termina a los 60 s")
	t.check(await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0), "después de la gracia sí llama")


## F21 (D3): cada preset cambia solo los 4 relojes libres; los umbrales en minutos de juego no.
func _f21_presets(t: Node) -> void:
	# v0.3.1 (integración): los valores salen de balance.json/reloj_presets (T2: sin el ajuste «t1»).
	var want := {}
	var presets: Dictionary = DataLoader.dict("balance").get("reloj_presets", {})
	for p in ["corta", "normal", "larga"]:
		var pd: Dictionary = presets.get(p, {})
		var pt: Dictionary = pd.get("t2", {})
		var vals: Array = []
		for k in ["sin_cola", "llegada_salida", "break", "lunch"]:
			vals.append(float(pt.get(k, pd.get(k, -1.0))))
		want[p] = vals
	var th0 := {}
	for tr_id in ["break", "lunch", "correo", "sala", "coaching_noshow"]:
		th0[tr_id] = Discipline.thresholds(tr_id)
	for p in want.keys():
		SaveSlots.select("Marko")
		SaveSlots.set_shift_length(p)
		await t.start_shift("Marko", 2)
		t.check(GameState.clock_preset == p, "turno con el preset %s" % p)
		var v: Array = want[p]
		var got := [GameState.reloj("sin_cola"), GameState.reloj("llegada_salida"), GameState.reloj("break"), GameState.reloj("lunch")]
		t.check(got == v, "%s: sin_cola/llegada/break/lunch = %s (hay %s)" % [p, str(v), str(got)])
		for k in ["contacto", "caso_bo", "de_pie_aux", "training", "feedback", "quiz", "dormido", "coaching_sesion"]:
			t.check(is_equal_approx(GameState.reloj(k), GameState.base_clock(k)), "%s: %s sin cambios (%.0fx)" % [p, k, GameState.reloj(k)])
		t.check(is_equal_approx(GameState.clock_speed(), v[1]), "%s: llegada a %.0fx" % [p, v[1]])
		await t.login_at_seat()
		GameState.stop_calm()
		await t.frames(2)
		t.check(is_equal_approx(GameState.clock_speed(), v[0]), "%s: sentado sin cola a %.0fx (hay %.1f)" % [p, v[0], GameState.clock_speed()])
		for tr_id in th0.keys():
			t.check(Discipline.thresholds(tr_id) == th0[tr_id], "%s: umbrales de %s iguales" % [p, tr_id])
	SaveSlots.set_shift_length("normal")


## F21: salvaguardas: break/lunch rápidos solo dentro del cupo; con una convocatoria, 4x.
func _f21_quotas(t: Node) -> void:
	await _p3().call("_prep", t)
	var hub := PersonajesP5.get_hub(t.get_tree())
	if hub != null:
		hub.process_mode = Node.PROCESS_MODE_DISABLED  # sin convocatorias de P5 de por medio (eso lo mide abajo)
	Metrics.set_aux(Metrics.Aux.BREAK)
	await _p3().call("_leave_room", t)
	t.check(is_equal_approx(GameState.clock_speed(), GameState.reloj("break")), "break dentro del cupo: %.0fx" % GameState.clock_speed())
	await _p3().call("_adv", t, 10.5 * 60.0)
	_p3().call("_ack_now")
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "break pasado de los 10 min: 4x (hay %.1f)" % GameState.clock_speed())
	await _p3().call("_go", t, 2, "pc")
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	GameState.clock_seconds = GameState.lunch_clock()
	EventBus.clock_tick.emit(GameState.clock_seconds)
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), GameState.reloj("lunch")), "lunch dentro del cupo: %.0fx" % GameState.clock_speed())
	await _p3().call("_adv", t, 46.0 * 60.0, 20.0)
	_p3().call("_ack_now")
	# v0.3.2 (sin terminales: hay que volver a una PC): pasado el cupo el reloj va como de pie en AUX (4x), antes 9x.
	t.check(is_equal_approx(GameState.clock_speed(), GameState.base_clock("de_pie_aux", 4.0)), "lunch pasado de los 45 min: 4x como de pie en AUX (hay %.1f)" % GameState.clock_speed())
	Discipline.hold_slow_clock("prueba", true)
	await t.frames(2)
	t.check(is_equal_approx(GameState.clock_speed(), 4.0), "con una convocatoria (hold_slow_clock) el lunch va a 4x")
	Discipline.hold_slow_clock("prueba", false)
	await t.frames(2)
	t.check(not Discipline.summons_pending(), "al soltarla no queda nada retenido")


## F21: la fila «Duración del turno» de Opciones cambia y guarda el preset por agente.
func _f21_option(t: Node) -> void:
	SaveSlots.select("Ttoom")
	SaveSlots.set_shift_length("normal")
	SaveSlots.save("Ttoom")
	var om := OptionsMenu.new()
	t.main.get_node("UI").add_child(om)
	await t.frames(2)
	var b := om.find_child("BotonDuracionTurno", true, false) as Button
	t.check(b != null, "Opciones tiene la fila «Duración del turno»")
	if b == null:
		om.queue_free()
		return
	t.check(SaveSlots.shift_length() == "normal", "por defecto Normal")
	b.pressed.emit()
	t.check(SaveSlots.shift_length() == "larga", "un clic: Larga (%s)" % SaveSlots.shift_length())
	b.pressed.emit()
	t.check(SaveSlots.shift_length() == "corta", "dos clics: Corta")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveSlots.main_progress_path("Ttoom")))
	t.check(parsed is Dictionary and str((parsed as Dictionary).get("duracion_turno", "")) == "corta", "guardado en progreso.json del agente")
	t.check(SaveSlots.shift_length("Jiroshi") == "normal", "otro agente sigue en Normal")
	om.queue_free()
	SaveSlots.set_shift_length("normal", "Ttoom")


## F26: salto de pie ~0,45 m; sentado, Espacio = aceptar (no salta); sin doble salto; aterrizaje con señal.
func _f26(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var pl: Player = t.player()
	var jumped: Array = t.spy("player_jumped")
	var landed: Array = t.spy("player_landed")
	# Sentado: Espacio es aceptar.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.frames(3)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await t.frames(3)
	t.check(jumped.is_empty() and pl.seated, "sentado: Espacio no salta")
	pl.stand_up()
	await t.frames(10)
	var y0 := pl.global_position.y
	Input.parse_input_event(ev)
	await t.frames(1)
	Input.parse_input_event(up)
	var peak := y0
	var w := 0.0
	var second_try := false
	while w < 2.0:
		await t.get_tree().physics_frame
		w += t.get_tree().root.get_physics_process_delta_time()
		peak = maxf(peak, pl.global_position.y)
		if not second_try and pl.is_airborne() and pl.global_position.y > y0 + 0.2:
			second_try = true
			t.check(not pl.request_jump(), "en el aire no hay doble salto")
	var h := peak - y0
	t.check(jumped.size() == 1, "de pie: Espacio salta (%d)" % jumped.size())
	t.check(h >= 0.38 and h <= 0.52, "altura del salto %.2f m (0,40-0,50)" % h)
	t.check(landed.size() >= 1 and absf(float(landed[0][0]) - h) < 0.1, "aterriza con player_landed(%.2f)" % (float(landed[0][0]) if not landed.is_empty() else -1.0))
	# Enfriamiento: saltar y probar justo al aterrizar.
	landed.clear()
	await t.seconds(0.5)
	t.check(pl.request_jump(), "otro salto")
	await t.until(func() -> bool: return not landed.is_empty(), 3.0)
	t.check(not pl.request_jump(), "enfriamiento de 0,4 s tras aterrizar (no encadena)")
	await t.seconds(0.5)
	t.check(pl.can_jump(), "pasado el enfriamiento se puede volver a saltar (%s)" % pl.jump_block_reason())
	Metrics.ack_pending = true
	t.check(not pl.can_jump(), "con un Ack pendiente Espacio es aceptar")
	Metrics.ack_pending = false
	pl.breath_left = 0.1
	t.check(not pl.can_jump(), "sin aliento no salta")


## F26/C16: con el salto no se cruza el molinete sin la revisión de Don Fermín.
func _f26_turnstile(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.frames(5)
	var pl: Player = t.player()
	GameState.flags["revision_ok"] = false
	pl.teleport(Vector3(-2.0, 0.05, 8.0), 0.0)  # contra el molinete 0 (poste de 1 m de alto, z 5,4-6,6)
	await t.frames(5)
	Input.action_press("move_forward")
	Input.action_press("walk_fast")
	var w := 0.0
	var min_z := pl.global_position.z
	while w < 8.0:
		await t.get_tree().physics_frame
		w += t.get_tree().root.get_physics_process_delta_time()
		pl.rotation.y = 0.0
		pl.request_jump()
		min_z = minf(min_z, pl.global_position.z)
	Input.action_release("move_forward")
	Input.action_release("walk_fast")
	await t.until(func() -> bool: return pl.is_on_floor(), 3.0)  # el último salto pedido puede estar en el aire
	t.check(pl.jumps >= 3, "saltó %d veces contra el molinete" % pl.jumps)
	# v0.3.1 (fusión con Q5): en el -1 nuevo la barrera de vidrio y los molinetes están a z 6 (cara norte a 6,06); en el
	# mapa de la rc1 el poste terminaba en z 6,6.
	var limit := 6.6
	var mol := t.building().floor_node.find_child("Molinete0", true, false) as Node3D
	if mol != null and t.building().floor_node.find_child("BarreraCol*", true, false) != null:
		limit = mol.global_position.z + 0.1
	t.check(min_z > limit, "saltando no se sube ni pasa por encima del molinete ni de la barrera (z mínima %.2f > %.2f)" % [min_z, limit])
	t.check(pl.global_position.y < 0.3, "sigue en el suelo (y %.2f)" % pl.global_position.y)
	t.check(pl.fall_rescues == 0, "sin caídas")


## Auditoría de bucles: para cada causa de muerte, morir → reconectar → 60 s reales quieto sentado en C-14 (con la
## pantalla de muerte de por medio, como un jugador que no hace nada): 0 muertes nuevas.
func _loops(t: Node) -> void:
	var causes: Array = []
	for c in DataLoader.list("muertes"):
		causes.append(str((c as Dictionary).get("id", "")))
	var turn_of := {"training_reprobado": 2, "training_inasistencia": 2, "rasec_evento": 2, "available_bajo": 3, "wmm_correo_vitzo": 2, "wmm_pod_correo": 2, "tres_molestos": 2}
	var bad: Array[String] = []
	for cause in causes:
		if cause == "":
			continue
		await t.start_shift("Jiroshi", int(turn_of.get(cause, 1)))
		await t.login_at_seat()
		Checkpoints.save_checkpoint("contacto")
		var cm := t.main.get("contacts") as Node
		var seq: Array = t.spy("death_sequence_started")
		await t.die(cause, "", Checkpoints.killer_of(cause))
		# La espera sigue a la tabla de screamers (la fusión de Vitzo dura 22,9 s desde v0.3.2; con 15 s fijos la prueba
		# reconectaba a media fusión).
		var cap_s := 15.0
		if Checkpoints.uses_screamer(Checkpoints.killer_of(cause)) and Screamers.has_row(cause):
			cap_s = maxf(cap_s, Screamers.duration(Checkpoints.killer_of(cause), cause) + 6.0)
		if not await t.wait_death_shown(cap_s):
			bad.append("%s: no llegó a la pantalla" % cause)
			continue
		await t.reconnect()
		await t.frames(2)
		seq.clear()
		if cm != null:
			cm.process_mode = Node.PROCESS_MODE_DISABLED  # quieto: no atiende contactos (no puede perderlos tampoco)
		var w := await _idle(t, 60.0, func() -> bool: return not seq.is_empty())
		if not seq.is_empty():
			bad.append("%s → %s a los %.1f s" % [cause, str(seq[0]), w])
		if cm != null and is_instance_valid(cm):
			cm.process_mode = Node.PROCESS_MODE_INHERIT
	t.check(bad.is_empty(), "%d causas: reaparecer y quedarse quieto 60 s reales no vuelve a matar %s" % [causes.size(), str(bad)])


# --- No quedar atrapado (Joan 11:19Z: al despertar del puff quedó dentro del sofá) -----------------------------

## ¿Se puede mover? Prueba 8 direcciones con el cuerpo real (0,4 m).
func _can_move(pl: Player) -> bool:
	var xf := pl.global_transform
	xf.origin += Vector3(0, 0.06, 0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		if not pl.test_move(xf, Vector3(cos(a), 0.0, sin(a)) * 0.4):
			return true
	return false


## Cada sofá/puff de cada piso: acostarse, despertar → el cuerpo no queda metido en el mueble y puede caminar.
func _wake_free(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.frames(3)
	var n := 0
	for fl in [-1, 1, 2, 9]:
		t.building().go_to_floor(fl, "ascensor")
		await t.frames(4)
		for sp in t.get_tree().get_nodes_in_group("sleep_spots"):
			if not (sp is SleepSpot) or not t.building().floor_node.is_ancestor_of(sp):
				continue
			var pl: Player = t.player()
			(sp as SleepSpot).interact(pl)
			await t.frames(3)
			(sp as SleepSpot).wake_up()
			for _i in 4:
				await t.get_tree().physics_frame
			var stuck := pl.overlaps_at(pl.global_position)
			t.check(not stuck and _can_move(pl) and not pl.lying, "piso %d · %s: al despertar queda libre y puede caminar (%s)" % [fl, (sp as SleepSpot).spot_id, str(pl.global_position)])
			n += 1
	t.check(n >= 3, "%d lugares para dormir revisados" % n)


## Pararse de los asientos con reglas (C-14, calibración, otra isla, training) nunca deja el cuerpo dentro de algo.
func _stand_free(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	for pair in [[2, "C-14"], [2, "calibracion"], [2, "E-07"], [1, "training_sala2_3"]]:
		if t.building().current_floor != int(pair[0]):
			t.player().stand_up()
			t.building().go_to_floor(int(pair[0]), "ascensor")
			await t.frames(4)
		var ok: bool = await _p5().call("_sit", t, str(pair[1]))
		if not ok:
			t.fail("no existe la silla %s" % pair[1])
			continue
		t.player().stand_up()
		for _i in 4:
			await t.get_tree().physics_frame
		var pl: Player = t.player()
		t.check(not pl.overlaps_at(pl.global_position) and _can_move(pl), "pararse de %s: libre" % pair[1])


## Encerrado (cuatro paredes a 10 cm del cuerpo): el perro guardián lo saca en ≤ 3 s; metido dentro de un bloque:
## unstick() lo saca; empujando una pared normal NO lo mueve.
func _box(parent: Node, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = pos
	return b


func _watchdog(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.frames(3)
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	var pl: Player = t.player()
	var fl: Node = t.building().floor_node
	var c := Vector3(16.0, 0.0, 6.0)
	pl.teleport(c + Vector3(0, 0.05, 0), 0.0)
	for _i in 4:
		await t.get_tree().physics_frame
	var walls: Array[StaticBody3D] = []
	for d in [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
		var sz := Vector3(0.1, 2.6, 1.2) if d.x != 0.0 else Vector3(1.2, 2.6, 0.1)
		walls.append(_box(fl, c + d + Vector3(0, 1.3, 0), sz))
	for _i in 3:
		await t.get_tree().physics_frame
	t.check(not _can_move(pl), "encerrado entre cuatro paredes (condición de la prueba)")
	var u0 := pl.unstuck_count
	Input.action_press("move_forward")
	var w := 0.0
	while w < 3.5 and pl.unstuck_count == u0:
		await t.get_tree().physics_frame
		w += t.get_tree().root.get_physics_process_delta_time()
	Input.action_release("move_forward")
	t.check(pl.unstuck_count > u0, "el perro guardián lo sacó en %.1f s (≤ 3)" % w)
	for _i in 3:
		await t.get_tree().physics_frame
	t.check(_can_move(pl) and Vector2(pl.global_position.x - c.x, pl.global_position.z - c.z).length() > 0.5, "fuera del encierro y puede caminar (%s)" % str(pl.global_position))
	for b in walls:
		b.queue_free()
	await t.get_tree().physics_frame
	# Dentro de un bloque macizo: unstick() (lo que corre al pararse, al despertar y al reaparecer) lo saca.
	var blk := _box(fl, c + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 1.0))
	pl.global_position = c + Vector3(0, 0.05, 0)
	await t.get_tree().physics_frame
	t.check(pl.overlaps_at(pl.global_position) or pl.global_position.y > 1.5, "metido en el bloque (o encima)")
	pl.global_position = c + Vector3(0, 0.05, 0)
	t.check(pl.unstick(Vector3.INF, "prueba"), "unstick() lo saca del bloque")
	t.check(not pl.overlaps_at(pl.global_position), "queda libre (%s)" % str(pl.global_position))
	blk.queue_free()
	await t.get_tree().physics_frame
	# Contra una pared de verdad: empujar no es estar atrapado.
	pl.teleport(Vector3(-14.6, 0.05, -9.0), 90.0)  # v0.3.1 pisos: pegado a la pared oeste (turquesa) de la cafetería, mirando a ella
	for _i in 3:
		await t.get_tree().physics_frame
	var u1 := pl.unstuck_count
	Input.action_press("move_forward")
	await t.seconds(3.0)
	Input.action_release("move_forward")
	t.check(pl.unstuck_count == u1, "empujando contra una pared 3 s no lo teletransporta (%d)" % (pl.unstuck_count - u1))



## Joan (11:14Z): la calibración de un CORREO no puede hablar de una llamada. Las líneas siguen el tipo de caso.
func _haime_case(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	var p4c: GDScript = load("res://scripts/dev/escenarios/p4_casos.gd")
	for kind in ["correo", "kyc"]:
		var c: Dictionary = {}
		for x in p4c.call("all_cases"):
			if str((x as Dictionary).get("canal", "")) == kind:
				c = (x as Dictionary).duplicate(true)
				break
		t.check(not c.is_empty(), "hay un caso %s" % kind)
		c["_qa"] = ["sin_enviar"] if kind == "correo" else ["kyc_aprobado_mal"]
		var posts: Array = t.spy("ezlak_post")
		EventBus.contact_outcome.emit(c, "bo_miss", 1)
		await t.frames(1)
		PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
		hub.qa.call_now()
		await t.frames(2)
		var dm := ""
		for p in posts:
			if str(p[0]) == "dm:haime":
				dm = str(p[2])
		t.check(dm.contains("correo") if kind == "correo" else dm.contains("KYC"), "%s: el llamado habla del caso («%s»)" % [kind, dm])
		hub.qa.test_opts = {"apertura": "intro"}  # v0.3.2: la apertura es al azar; aquí se comprueba la intro del tipo
		await _p5().call("_go_calibration", t)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 3.0)
		# v0.3.1 (fusión con Q4): intro y repaso salen del guion de HaimeGuion según el tipo del caso.
		await t.until(func() -> bool: return hub.qa.session_log.size() >= 3, 60.0)
		var log_s := str(hub.qa.session_log)
		var tipos: Array = ["correo", "vitzo"] if kind == "correo" else [kind]
		var intro_ok := false
		for tp in tipos:
			intro_ok = intro_ok or log_s.contains("q4_in_%s_" % tp)
		t.check(intro_ok, "%s: intro propia del tipo de caso (%s)" % [kind, log_s])
		await t.until(func() -> bool: return hub.qa.heard_opportunities >= 1 or hub.qa.state != QaFeedback.State.SESION, 60.0)
		var spoken := " ".join(hub.qa.session_texts)
		t.check(not spoken.contains("respiraste") and not spoken.contains("cliente habla"), "%s: nada de voz/respiración de una llamada" % kind)
		await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LIBRE, 150.0)
		t.player().stand_up()
		await t.frames(2)


## F23 (lo encontró el bot obediente con el preset Normal): mientras suena un contacto el reloj seguía en el «sin
## cola» (240x): t2c2 («ignorar_s_juego» 90) se perdía en 0,4 s reales. Ahora suena a 6x (≈ 15 s reales).
func _ring(t: Node) -> void:
	SaveSlots.select("Marko")
	SaveSlots.set_shift_length("normal")
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.frames(2)
	t.check(GameState.clock_mode == GameState.ClockMode.SIN_COLA, "sentado sin cola: reloj libre (%.0fx)" % GameState.clock_speed())
	var cm: ContactManager = t.main.get("contacts")
	var c: Dictionary = {}
	for x in DataLoader.dict("contactos_t2").get("contactos", []):
		if str((x as Dictionary).get("id", "")) == "t2c2":
			c = (x as Dictionary).duplicate(true)
	t.check(float(c.get("ignorar_s_juego", 0.0)) >= 60.0, "t2c2 se pierde si no se contesta (ignorar_s_juego %.0f)" % float(c.get("ignorar_s_juego", 0.0)))
	t.check(cm.offer_now(c), "suena t2c2")
	await t.frames(2)
	t.check(GameState.clock_mode == GameState.ClockMode.TIMBRE and is_equal_approx(GameState.clock_speed(), GameState.reloj("contacto")), "mientras suena: reloj del contacto (%.0fx, modo %s)" % [GameState.clock_speed(), Metrics.clock_state_name()])
	await _idle(t, 6.0)
	t.check(cm.phase == ContactManager.Phase.OFFERING, "a los 6 s reales (lo que tarda un humano) sigue sonando")
	cm.accept()
	await t.frames(2)
	t.check(GameState.clock_mode == GameState.ClockMode.CONTACTO, "al contestar: reloj del contacto")
	# Un caso BO que espera no cambia el reloj (no se pierde).
	EventBus.contact_ended.emit(cm.current, true, false)
	cm.phase = ContactManager.Phase.IDLE
	cm.current = {}
	var kyc: Dictionary = {}
	for x in (load("res://scripts/dev/escenarios/p4_casos.gd") as GDScript).call("all_cases"):
		if str((x as Dictionary).get("canal", "")) == "kyc":
			kyc = (x as Dictionary).duplicate(true)
			break
	cm._offer(kyc)
	await t.frames(2)
	t.check(GameState.clock_mode != GameState.ClockMode.TIMBRE, "un KYC en espera no usa el reloj del timbre (%s)" % Metrics.clock_state_name())
	cm.phase = ContactManager.Phase.IDLE
	cm.current = {}
	GameState.queue_size = 0


## C12 en el RTA (bucle visto en el bot obediente, Marko T3: 15 muertes seguidas por aux_incorrecto a las 4:49): tras
## reaparecer con un AUX que ya no toca y 2 strikes, la tolerancia del RTA no corre durante la gracia y empieza de
## cero al terminarla.
func _rta_grace(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 1)
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	GameState.stop_calm()
	PersonajesP5.set_counter("p5_rta_strikes", 2)
	Metrics.expected_aux = Metrics.Aux.AVAILABLE
	Metrics.set_aux(Metrics.Aux.BO)
	await t.frames(2)
	t.check(hub.rta.wrong_reason() == "aux", "AUX incorrecto tras reaparecer (BO, se espera Available)")
	await _idle(t, 50.0, func() -> bool: return not Checkpoints.in_respawn_grace())
	t.check(hub.rta.wrong_elapsed < 0.0 and not hub.rta.hunting and hub.rta.strikes() == 2, "50 s de gracia: el RTA no cuenta (%.1f s, strikes %d, caza %s)" % [hub.rta.wrong_elapsed, hub.rta.strikes(), str(hub.rta.hunting)])
	await t.until(func() -> bool: return not Checkpoints.in_respawn_grace(), 15.0)
	await _idle(t, 1.0)
	t.check(hub.rta.wrong_elapsed >= 0.0 and hub.rta.wrong_elapsed < 30.0 and not hub.rta.hunting, "al terminar la gracia la tolerancia empieza de cero (%.1f s)" % hub.rta.wrong_elapsed)
	Metrics.set_aux(Metrics.expected_aux)  # lo que dicta el RTA (sentado 60 s sin cola el reloj pudo llegar al lunch)
	await t.frames(3)
	t.check(hub.rta.wrong_elapsed < 0.0, "corrigiendo el AUX el RTA lo da por bueno (AUX %s, esperado %s, motivo '%s', %.1f s)" % [Metrics.aux_name(), Metrics.aux_name(Metrics.expected_aux), hub.rta.wrong_reason(), hub.rta.wrong_elapsed])


## F23 (bot humano, Jiroshi T3): murió durante una allocation del Mentor posterior a su checkpoint; al reaparecer la
## allocation seguía activa hasta su fin (2 h de juego después): el RTA pedía BO y Shero castigaba el Available (0 %).
func _alloc_respawn(t: Node) -> void:
	await t.start_shift("Marko", 3)
	await t.login_at_seat()
	GameState.stop_calm()
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(mentor != null, "el Mentor existe")
	Checkpoints.save_checkpoint("login")  # un tipo que guardan todos los modos de checkpoint
	await t.frames(2)
	await t.advance_clock(30.0 * 60.0)
	mentor.post_allocation_now()
	await t.frames(2)
	t.check(mentor.active and Metrics.allocation_aux == Metrics.Aux.BO and Metrics.expected_aux == Metrics.Aux.BO, "allocation a BO en curso")
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(3)
	t.check(not mentor.active and Metrics.allocation_aux < 0, "al reaparecer antes de esa allocation ya no sigue (activa %s, allocation %d)" % [str(mentor.active), Metrics.allocation_aux])
	t.check(Metrics.expected_aux != Metrics.Aux.BO, "el RTA ya no pide BO (pide %s)" % Metrics.aux_name(Metrics.expected_aux))
	# Checkpoint DENTRO de la allocation: sigue (es la orden vigente en ese momento).
	Checkpoints.set("_grace_left", 0.0)  # la gracia corta de 3 s tras reconectar no deja morir enseguida
	GameState.stop_calm()
	mentor.post_allocation_now()
	Metrics.set_aux(Metrics.Aux.BO)
	await t.frames(2)
	Checkpoints.save_checkpoint("login")
	await t.frames(2)
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(3)
	t.check(mentor.active and Metrics.allocation_aux == Metrics.Aux.BO and Metrics.expected_aux == Metrics.Aux.BO, "checkpoint dentro de la allocation: sigue pidiendo BO (activa %s, esperado %s)" % [str(mentor.active), Metrics.aux_name(Metrics.expected_aux)])


## F23 (bot humano en Corta): a la hora del lunch el RTA dicta Lunch; sentado en Available el reloj seguía a 400x y
## los 15 min de ventana se iban en 2 s reales. Una orden de AUX sin cumplir retiene el reloj a 4x (como una
## convocatoria); al ponerla, el lunch corre con su preset.
func _lunch_order(t: Node) -> void:
	SaveSlots.select("Llauri")
	SaveSlots.set_shift_length("corta")
	await t.start_shift("Llauri", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	# v0.3.2 (prueba inestable): al saltar el reloj al lunch, un contacto del guion que ya «tocaba» podía sonar en
	# ese mismo cuadro y el reloj pasaba al del timbre (6x) en vez del de pie. Aquí se mide el reloj de la orden
	# del RTA, no el de la cola: sin contactos ofrecidos mientras dura la prueba (y sin uno que ya sonara).
	var cm: ContactManager = t.main.get("contacts")
	cm.set_process(false)
	if cm.phase == ContactManager.Phase.OFFERING:
		cm.phase = ContactManager.Phase.IDLE
		cm.current = {}
		GameState.queue_size = 0
	await t.frames(2)
	t.check(GameState.clock_mode == GameState.ClockMode.SIN_COLA and is_equal_approx(GameState.clock_speed(), GameState.reloj("sin_cola")) and GameState.reloj("sin_cola") >= 200.0, "Corta, sentado sin cola: %.0fx" % GameState.clock_speed())
	await t.set_clock(GameState.lunch_clock() - 20.0)
	await t.frames(2)
	await t.until(func() -> bool: return Metrics.expected_aux == Metrics.Aux.LUNCH, 5.0)
	await t.frames(2)
	t.check(Metrics.expected_aux == Metrics.Aux.LUNCH and Discipline.summons_pending(), "el RTA dicta Lunch: orden abierta")
	t.check(GameState.clock_mode == GameState.ClockMode.DE_PIE and is_equal_approx(GameState.clock_speed(), GameState.reloj("de_pie_aux")), "con la orden sin cumplir el reloj va a %.0fx (no al sin cola)" % GameState.clock_speed())
	var c0 := GameState.clock_seconds
	await _idle(t, 3.0)
	t.check(GameState.clock_seconds - c0 < 60.0, "3 s reales = %.0f s de juego (la ventana de 15 min no se va en 2 s)" % (GameState.clock_seconds - c0))
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(not Discipline.summons_pending() and GameState.clock_mode == GameState.ClockMode.LUNCH, "con Lunch puesto: reloj del lunch (%.0fx)" % GameState.clock_speed())
	cm.set_process(true)
	SaveSlots.set_shift_length("normal")


## F23 (bot humano, Llauri T3): un caso de correo abierto y 30 min de juego en el training (Discipline congelada): al
## volver salían los 4 escalones del correo en el mismo minuto (llamado, verbal, WW y persecución: muerte aht_bo).
## El tiempo congelado ya no cuenta para la escalera; el caso sigue y la escalera empieza de a un escalón.
func _correo_frozen(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var steps: Array = t.spy("discipline_step")
	var cm: ContactManager = t.main.get("contacts")
	var c: Dictionary = {}
	for x in (load("res://scripts/dev/escenarios/p4_casos.gd") as GDScript).call("all_cases"):
		if str((x as Dictionary).get("canal", "")) == "correo":
			c = (x as Dictionary).duplicate(true)
			break
	t.check(cm.offer_now(c), "caso de correo ofrecido")
	cm.accept()
	await t.frames(2)
	Metrics.set_aux(Metrics.Aux.BO)
	Discipline.freeze(true, "training")
	await t.advance_clock(30.0 * 60.0)
	Discipline.freeze(false, "training")
	await t.advance_clock(60.0)
	var correo := steps.filter(func(e: Array) -> bool: return str(e[0]) == "correo")
	t.check(correo.size() <= 1, "al descongelar: como mucho un escalón del correo, no los cuatro (%s)" % str(correo.map(func(e: Array) -> int: return int(e[1]))))
	t.check(not Pursuit.is_hunting("shero") and not Checkpoints.dying, "sin persecución ni muerte por el tiempo del training")
	cm.phase = ContactManager.Phase.IDLE
	cm.current = {}


## F23 (bot humano, Jiroshi T3): «Me siento mal» → 15 min de juego de permiso que, sentado terminando el contacto,
## corrían a 240x (4 s reales). Mientras el permiso está abierto el reloj va a 4x; al vencer, vuelve el sin cola.
func _topico_permit(t: Node) -> void:
	var hub: PersonajesP5 = await _p5().call("_prep", t, 2)
	await t.frames(2)
	t.check(GameState.clock_mode == GameState.ClockMode.SIN_COLA, "sentado sin cola (%.0fx)" % GameState.clock_speed())
	Fatigue.set_value(60.0)
	EzlakHub.get_hub(t.get_tree()).quick_reply("dm:shero", "me_siento_mal")
	await t.frames(3)
	t.check(hub.topico.state == TopicoControl.State.PERMISO and Discipline.summons_pending(), "permiso del tópico abierto: convocatoria (estado %d)" % hub.topico.state)
	t.check(GameState.clock_mode == GameState.ClockMode.DE_PIE, "con el permiso abierto el reloj va a %.0fx" % GameState.clock_speed())
	await t.advance_clock(16.0 * 60.0)
	await t.frames(3)
	t.check(not Discipline.summons_pending(), "vencido el permiso ya no retiene el reloj")


## F10 (revisión de Joan): con la PC acercada el aviso de primera vez no tapa las pantallas ni el HUD, y alrededor de
## las pantallas queda sala a la vista.
func _tip_outside(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var ws := _ws(t)
	ws.call("set_zoom", true)
	await t.frames(3)
	var tips := t.get_tree().get_first_node_in_group("agent_tips")
	var box: Control = tips.get("_box")
	(tips.get("_lbl") as Label).text = "Haime (QA) te llama a feedback: pon Coaching y ve a la sala de calibración (piso 2) antes de 8 min."
	box.visible = true
	tips.call("_place")
	await t.frames(3)
	var r: Rect2 = ws.call("zoom_rect")
	var b := box.get_global_rect()
	var vp := t.get_tree().root.get_visible_rect().size
	t.check(not b.intersects(r), "el aviso (%s) no tapa las pantallas (%s)" % [str(b), str(r)])
	t.check(b.end.x <= vp.x - 290.0, "el aviso no llega a la columna del HUD (x hasta %.0f de %.0f)" % [b.end.x, vp.x])
	t.check(r.position.y >= vp.y * 0.1 and r.position.x >= vp.x * 0.04, "queda sala alrededor de las pantallas (arriba %.0f px, al lado %.0f px)" % [r.position.y, r.position.x])
	box.visible = false
	ws.call("set_zoom", false)

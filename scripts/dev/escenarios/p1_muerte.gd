## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P1 · muerte y colapso (PLAN §1, §8.1): el bucle de "Motivo: Colapso" de la v0.2 no vuelve.


func escenarios() -> Array[String]:
	return ["repro_colapso", "colapso_reconectar", "menu_otro_agente", "reiniciar_contacto", "muerte_cada_causa", "secuencia_muerte", "turno_real_reinicia"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"repro_colapso": await _repro(t)
		"colapso_reconectar": await _colapso_reconectar(t)
		"menu_otro_agente": await _menu_otro_agente(t)
		"reiniciar_contacto": await _reiniciar_contacto(t)
		"muerte_cada_causa": await _cada_causa(t)
		"secuencia_muerte": await _secuencia(t)
		"turno_real_reinicia": await _turno_real(t)


## Colapso con Fatiga 90 en el checkpoint de login (la secuencia del repro de la v0.2).
func _colapsar(t: Node) -> void:
	await t.login_at_seat()
	Fatigue.set_value(90.0)
	Checkpoints.save_checkpoint("login")
	Fatigue.add(10.0)  # cruza 100 → colapso
	await t.frames(1)


## tools/repro_colapso_v02.gd como regresión (`-- --repro-colapso`): colapso → Reconectar ×3 → menú →
## turno de Marko → Reconectar. v0.2: 5 muertes encadenadas; ahora 1 y el turno de Marko es suyo.
func _repro(t: Node) -> void:
	var seqs: Array = t.spy("death_sequence_started")
	var shown: Array = t.spy("death_shown")
	await t.start_shift("Jiroshi", 1)
	await _colapsar(t)
	t.check(Checkpoints.dying and not GameState.running, "tras el colapso: dying=true y running=false juntos")
	t.check(await t.wait_death_shown(8.0), "la pantalla aparece tras la animación de colapso")
	for i in 3:
		await t.reconnect()  # Espacio ×3: solo el primero reconecta
		t.check(not Checkpoints.dying and GameState.running, "Reconectar #%d: dying=false, running=true" % (i + 1))
		t.check(not t.death_screen().visible, "Reconectar #%d: pantalla oculta" % (i + 1))
	# v0.3.2-core3: ya no es «60 siempre»: como mucho el tope de la dificultad (40 en Normal) y nunca más que el checkpoint.
	t.check(is_equal_approx(Fatigue.value, Checkpoints.fatigue_cap()) and Fatigue.value < 90.0, "tras un colapso se despierta con la Fatiga del tope (%.0f; hay %.1f)" % [Checkpoints.fatigue_cap(), Fatigue.value])
	await t.seconds(3.0)
	t.check(seqs.size() == 1, "una sola muerte, sin bucle (secuencias: %d)" % seqs.size())
	await t.back_to_menu()
	t.check(not t.death_screen().visible and not bool(t.death_screen().call("is_active")), "el menú oculta y desactiva la pantalla de muerte")
	t.check(not Checkpoints.dying and Checkpoints.last_checkpoint.is_empty(), "el menú limpia dying y el checkpoint en memoria")
	await t.start_shift("Marko", 1)
	t.check(not t.death_screen().visible, "el turno de Marko arranca sin pantalla de muerte")
	Checkpoints.respawn()  # Espacio sin muerte: no hace nada
	await t.frames(2)
	t.check(GameState.agent == "Marko", "Reconectar en el turno nuevo no restaura a Jiroshi (agente %s)" % GameState.agent)
	t.check(str(Checkpoints.last_checkpoint.get("agente", "")) == "Marko", "el checkpoint vivo es de Marko")
	t.check(shown.size() == 1, "exactamente 1 death_shown en todo el repro (hubo %d)" % shown.size())


func _colapso_reconectar(t: Node) -> void:
	var seqs: Array = t.spy("death_sequence_started")
	var scr: Array = t.spy("screamer_finished")
	var anim: Array = t.spy("death_animation_finished")
	await t.start_shift("Llauri", 1)
	await _colapsar(t)
	t.check(seqs.size() == 1 and str(seqs[0][1]) == "fatiga", "el colapso arranca la secuencia con asesino 'fatiga'")
	t.check(await t.wait_death_shown(8.0), "aparece 'Usuario desconectado'")
	t.check(anim.size() == 1 and scr.is_empty(), "colapso = animación de muerte SIN screamer (anim %d, screamer %d)" % [anim.size(), scr.size()])
	var inc := Metrics.incidents
	await t.reconnect()
	t.check(not Checkpoints.dying and GameState.running, "dying=false y running=true")
	t.check(not t.death_screen().visible, "pantalla oculta")
	t.check(is_equal_approx(Fatigue.value, Checkpoints.fatigue_cap()), "Fatiga del tope (%.0f) tras el colapso (hay %.1f)" % [Checkpoints.fatigue_cap(), Fatigue.value])
	t.check(GameState.agent == "Llauri", "mismo agente")
	await t.seconds(2.5)
	t.check(seqs.size() == 1, "no hay segunda muerte (secuencias %d)" % seqs.size())
	t.check(Metrics.incidents <= inc, "la incidencia no se duplica al reconectar")


## Muerte → [Esc] Volver al menú → turno con otro agente: sin pantalla y con su propia partida.
func _menu_otro_agente(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _colapsar(t)
	t.check(await t.wait_death_shown(8.0), "pantalla de muerte de Jiroshi")
	t.death_screen().emit_signal("menu_requested")  # lo que hace [Esc]
	await t.frames(3)
	t.check(not t.death_screen().visible, "Esc → menú: pantalla oculta")
	t.check(not Checkpoints.dying and not GameState.running, "Esc → menú: sin muerte en curso y sin turno corriendo")
	t.check(bool(t.main.get("main_menu").visible), "se ve el menú")
	var jir := SaveSlots.read_checkpoint("Jiroshi")
	t.check(str(jir.get("agente", "")) == "Jiroshi", "el checkpoint de Jiroshi sigue en su carpeta")
	await t.start_shift("Marko", 1)
	t.check(not t.death_screen().visible, "el turno de Marko arranca sin pantalla de muerte")
	t.check(GameState.agent == "Marko" and GameState.running, "turno de Marko corriendo")
	t.check(str(Checkpoints.last_checkpoint.get("agente", "")) == "Marko" and str(Checkpoints.last_checkpoint.get("kind", "")) == "inicio", "Marko tiene su checkpoint de inicio")
	await t.login_at_seat()
	await t.die("aht_bo", "11:00")
	t.check(await t.wait_death_shown(8.0), "Marko puede morir normalmente")
	await t.reconnect()
	t.check(GameState.agent == "Marko" and not Checkpoints.dying, "reconecta como Marko")
	t.check(str(SaveSlots.read_checkpoint("Jiroshi").get("agente", "")) == "Jiroshi", "la partida de Jiroshi no se tocó")


## Pausa → Reiniciar contacto: 0 incidencias, Fatiga sin cambios, un solo respawn.
func _reiniciar_contacto(t: Node) -> void:
	var resp: Array = t.spy("respawned")
	var shown: Array = t.spy("death_shown")
	await t.start_shift("Ttoom", 1)
	await t.login_at_seat()
	Fatigue.set_value(50.0)
	await t.advance_clock(300.0)
	var inc := Metrics.incidents
	var pm: Control = t.main.get("pause_menu")
	pm.call("toggle")
	await t.frames(1)
	pm.call("_restart_contact")
	await t.frames(2)
	t.check(resp.size() == 1, "un solo respawn (hubo %d)" % resp.size())
	t.check(shown.is_empty(), "no se muestra 'Usuario desconectado'")
	t.check(Metrics.incidents == inc, "0 incidencias nuevas")
	t.check(is_equal_approx(Fatigue.value, 50.0), "Fatiga sin cambios (hay %.1f)" % Fatigue.value)
	t.check(not Checkpoints.dying and GameState.running and not t.get_tree().paused, "sigue jugando, sin pausa")
	t.check(not Checkpoints.restart_contact(), "pulsarlo otra vez sin avanzar no hace un segundo respawn")
	t.check(resp.size() == 1, "sigue habiendo un solo respawn")


## Cada causa de muertes.json dos veces seguidas: siempre se reconecta (PLAN §2 #2).
func _cada_causa(t: Node) -> void:
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	var n := 0
	for c in DataLoader.list("muertes"):
		if bool(c.get("solo_ww", false)):
			continue
		var cause := str(c.get("id", ""))
		for rep in 2:
			GameState.stop_calm()
			await t.seconds(Checkpoints.GRACE_S + 0.1)
			await t.die(cause, "1")
			if not t.check(Checkpoints.dying, "%s #%d: se acepta la muerte" % [cause, rep + 1]):
				continue
			# La espera sigue a la tabla de screamers (la fusión de Vitzo dura 22,9 s desde v0.3.2; con 8 s fijos se cortaba).
			var killer := Checkpoints.killer_of(cause)
			var cap := 8.0
			if Checkpoints.uses_screamer(killer) and Screamers.has_row(cause):
				cap = maxf(cap, Screamers.duration(killer, cause) + 6.0)
			t.check(await t.wait_death_shown(cap), "%s #%d: aparece la pantalla" % [cause, rep + 1])
			await t.reconnect()
			t.check(not Checkpoints.dying and GameState.running and not t.death_screen().visible, "%s #%d: reconecta" % [cause, rep + 1])
			t.check(Fatigue.value < 100.0, "%s #%d: la Fatiga queda bajo el colapso" % [cause, rep + 1])
			n += 1
	t.note("%d muertes y reconexiones" % n)


## Orden de la secuencia: death_sequence_started → screamer_finished → death_shown (muerte con asesino).
func _secuencia(t: Node) -> void:
	var order: Array[String] = []
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: order.append("start"), CONNECT_ONE_SHOT)
	EventBus.screamer_finished.connect(func(_c: String) -> void: order.append("screamer"), CONNECT_ONE_SHOT)
	EventBus.death_shown.connect(func(_c: String) -> void: order.append("shown"), CONNECT_ONE_SHOT)
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	await t.die("tercer_ww")
	t.check(t.player().input_locked, "el jugador pierde el control durante el screamer")
	t.check(not t.death_screen().visible, "la pantalla no aparece antes del screamer")
	await t.wait_death_shown(8.0)
	t.check(order == ["start", "screamer", "shown"], "orden start → screamer → shown (fue %s)" % str(order))
	t.check(Checkpoints.killer_of("tercer_ww") == "shero" and Checkpoints.uses_screamer("shero"), "tercer_ww la causa Shero: con screamer")
	t.check(not Checkpoints.uses_screamer("fatiga") and not Checkpoints.uses_screamer(""), "Fatiga/nadie: sin screamer")
	await t.reconnect()
	# Respawn durante el screamer: la secuencia se cancela y la pantalla nunca aparece.
	GameState.stop_calm()
	await t.seconds(Checkpoints.GRACE_S + 0.1)
	var shown: Array = t.spy("death_shown")
	await t.die("aux_incorrecto", "Baño 12:00", "rta")
	t.check(Checkpoints.death_killer == "rta", "request_death fija el asesino")
	Checkpoints.respawn()
	await t.seconds(3.0)
	t.check(shown.is_empty() and not t.death_screen().visible, "un respawn a mitad del screamer cancela la pantalla")
	t.check(t.get_tree().get_nodes_in_group(Screamers.GROUP).is_empty(), "no quedan screamers colgados")


## Turno real (= Difícil): morir reinicia el turno completo desde el casillero a las 23:48.
func _turno_real(t: Node) -> void:
	var resp: Array = t.spy("respawned")
	await t.start_shift("Jiroshi", 1, GameState.Mode.REAL, Difficulty.Level.FACIL)
	t.check(Difficulty.effective() == Difficulty.Level.DIFICIL, "Turno real es siempre Difícil aunque se eligió Fácil")
	t.check(Checkpoints.checkpoint_mode() == "ninguno", "Turno real sin checkpoints")
	await t.login_at_seat()
	await t.advance_clock(3600.0)
	await t.die("abandono")
	await t.wait_death_shown(8.0)
	await t.reconnect()
	t.check(resp.size() == 1 and str(resp[0][0]) == "casillero", "respawn de tipo casillero")
	t.check(GameState.clock_seconds < 0.0 and not GameState.logged_in, "el reloj vuelve a las 23:48 sin login (%.0f)" % GameState.clock_seconds)
	t.check(GameState.running and not Checkpoints.dying, "el turno corre otra vez")

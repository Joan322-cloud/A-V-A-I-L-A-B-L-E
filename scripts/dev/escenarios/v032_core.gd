extends RefCounted
## v0.3.2-core · regresiones del paquete «sistemas, pruebas de juego y pulido» (`--escenario v032_core`).
##   core_voces_importantes  VoiceDirector v2: una línea importante no se corta ni se pierde (espera su turno o sale
##                           como aviso); el cliente del mismo contacto se reemplaza a sí mismo; la misma línea pedida
##                           varias veces no se apila; el relleno vence; los avisos de Ezlaki no ocupan el canal; 0 solapes.
##   core_voces_fermin       la revisión de Don Fermín a velocidad real: sus 6 líneas suenan enteras y en orden (antes la
##                           última, «Pase, está limpio», vencía en la cola).
##   core_voces_evento       el evento de Rasec a velocidad real con un jugador que contesta rápido: sus preguntas suenan
##                           (antes vencían detrás de 5 «¡Eso! Más fuerte»), los susurros de relleno ceden.
##   core_voces_veto         quien le quita la palabra a otro en el instante en que empieza (la calibración de Haime
##                           calla a todos los demás) no hace que se pierda una línea importante: su texto sale como
##                           aviso; el relleno se calla sin más; cancelar una línea propia a medias no cambia.
##   core_voces_eco          lo que piensa tu agente al sentarse por primera vez en C-14 (el eco del Training, ~10 s)
##                           es relleno: el cliente, Haime o un jefe lo cortan en el acto (antes el primer cliente del
##                           turno se quedaba sin voz y la calibración empezaba con un hueco); un susurro de la sala
##                           no lo corta; el monólogo del Training (DIRECTO) sigue siendo importante; de principio a
##                           fin con el eco de verdad: te sientas, piensa, entra la llamada y el cliente se oye.
##   core_emoji              los emojis son dibujos (texturas propias) en mensajes, selector y pared; texto solo como
##                           alternativa accesible.
##   core_comodin_estados    el panel del comodín dice el estado de cada compañero, avisa si nadie está activo antes de
##                           gastarlo, cumple lo que mostró (activo al llamar = contesta) y dice por qué no contestaron.
##   core_comodin_real       el comodín por el camino real, sin estados forzados: cada estado del ACD sacado del
##                           horario del turno (lunch, break, training, coaching, dormido, en un contacto, BO,
##                           disponible) sale en el panel como lo ve Ezlaki, contesta solo quien está «activo» y el
##                           aviso dice por qué no; con todos ocupados el panel avisa antes de gastar, y llamarlos a
##                           todos (o dejar pasar el reintento) pierde el comodín; la práctica del Training (tu
##                           promoción siempre contesta) no gasta el del turno ni avisa a Shero.
##   core_available_respawn  morir por Available bajo no es un bucle: la lista del Mentor que ya había salido antes del
##                           checkpoint no se repite al reaparecer ni al Continuar (antes Shero la contaba dos veces y
##                           te perseguía en «Reconectando»), Shero no lee listas en Reconectando/gracia/calma, y el
##                           Available % se cuenta de nuevo tras esa muerte (antes cada lista siguiente te mataba).
##   core_respawn_estado     lo que no vuelve atrás y lo que sí: la incidencia de cada muerte se conserva (antes el
##                           respawn la borraba y el turno cerraba con «Incidencias: 0»); el comodín gastado, los
##                           minitrainings hechos, los guiones ya atendidos y la allocation en curso sobreviven a
##                           «Continuar» (antes: comodín infinito, clientes repetidos, RTA pidiendo BO para siempre).
##   core_allocation_respawn una allocation a BO que estaba en curso en el checkpoint sigue en curso al reaparecer
##                           aunque hubiera terminado antes de la muerte (el reloj vuelve a estar dentro de su horario),
##                           con su hora de fin; y se cierra a su hora.
##   core_ezlaki_respawn     al reaparecer el chat vuelve a la hora del checkpoint: sin mensajes «del futuro», sin
##                           avisos programados duplicados y sin la cuenta atrás de una reacción que ya no existe.
##   core_ingles             en inglés: lo ESCRITO se entiende (léxico inglés → español de IANlu: intenciones, y las
##                           respuestas al cliente en los 53 árboles con faltas y palabras de menos), sin empeorar el
##                           español; el micrófono dice claro que la voz es solo en español (Opciones y panel de la
##                           llamada) y deja a mano las respuestas rápidas; el botón del micrófono tiene icono.
##   core_idioma_en_caliente cambiar de idioma con el juego abierto (Opciones del menú o de la Pausa) no deja la PC, el
##                           softphone ni los avisos en el idioma anterior: 0 textos fijos sin traducir, ida y vuelta.
##   core_convocan_de_a_uno  con un llamado pendiente (Haime, el Trainer, el evento de Rasec) nadie más te convoca:
##                           el bot humano murió en el T2 porque Haime llamó a las 5:14 y el evento cayó a las 5:15
##   core_respawn_piso       checkpoint del lunch en la cafetería (-1), mueres sentado en C-14: al reaparecer el juego
##                           sabe que estás en el piso 2 y sentado (antes creía que seguías en el -1 y de pie: no
##                           podías «llegar» al evento de Rasec ni aceptar un contacto)
##   core_repite_tramo       (core2) morir y repetir un tramo en Difícil, Normal y Fácil: los contactos por hora de juego
##                           del tramo repetido quedan dentro de una banda de los de la primera vez (antes: horas sin
##                           un contacto con «Cola 21»); los guiones ya resueltos no vuelven, el que estaba a medias
##                           sí; lo atendido sigue contado una sola vez; nunca el mismo cliente dos veces seguidas;
##                           la cola del HUD es lo que te puede entrar; igual tras otra muerte y tras «Continuar».
##   core_cola_no_para       (core2) la cola rebobina con el reloj (compañeros que no quedan «en contacto» horas);
##                           con gente esperando y el cupo del turno servido te sigue entrando; la bolsa de relleno
##                           no se acaba (turnos anteriores, luego otra vuelta con otro humor) y todo checkpoint
##                           guarda la cola (en Difícil «Continuar» repetía los clientes desde el primero).
##   core_reaparece_sin_bucle (core3) por dificultad (Difícil, Normal, Fácil): te matan tarde en el tramo, reapareces con
##                           la Fatiga del checkpoint (antes +15), con su saldo, sus breaks, su tópico y su AUX esperado
##                           (en Difícil el del lunch: el HUD dice lo que te quedaba y, si se pasa la cuenta, que sigue
##                           ahí); repetir el tramo no cansa más que la primera vez (los contactos «de más» no suman)
##                           y llegas al checkpoint siguiente sin morir.
##   core_reaparece_colapso  (core3) el bucle del integrador, en Difícil: checkpoint del lunch con Fatiga 66, Haime te
##                           mata a las 7:08, reapareces con 66 (antes 81 → colapso a las 8:00, y otra vez, y otra) y
##                           llegas a las 8:00; un colapso deja como mucho el tope de la dificultad (la pantalla lo
##                           dice); a la segunda muerte seguida desde el mismo checkpoint, la ayuda (tópico otra vez,
##                           café sin cobrar, aviso) una sola vez; con el tope el tramo se juega entero sin morir aun
##                           con un cliente molesto de cada tres; cada muerte seguida baja el tope hasta el suelo;
##                           «Continuar» no devuelve la Fatiga de antes; un checkpoint nuevo empieza la cuenta de cero
##                           (pero no el que se guarda nada más reaparecer).
##   core_reaparece_reglas   (core3) la regla en tabla por dificultad y Turno real; nunca más Fatiga que el checkpoint;
##                           T1 (sin tópico ni dinero): la ayuda devuelve el café del turno; «Reiniciar contacto» no
##                           devuelve lo comprado; el Turno real sigue reiniciando el turno entero; el tercer break
##                           (la falta que mata) no guarda checkpoint: no reapareces dentro del break prohibido.
##   core_pistas_teclas      las pistas de teclas siguen el remapeo de Opciones (ES y EN) y vuelven al restablecer;
##                           pantalla completa la primera vez, Alt+Intro, ventana que cabe en la pantalla
##   core_hud_franjas        lo que comparte franja no se pisa: el aviso de primera vez espera al aviso de texto con la
##                           PC acercada, el mensaje va encima de un subtítulo de tres líneas, el REC de Haime no queda
##                           detrás del monitor, y las métricas del HUD se leen (≥ 15 px de diseño).
##   core_regla_nombres      la regla de nombres vale para TODO el repositorio (no solo game/): un nombre real en un
##                           texto o en una ruta, algo bajo docs/ref/ o un archivo retirado que vuelve con otro nombre
##                           hacen fallar a --check-all y a tools/check_nombres.py; el repositorio está limpio; los
##                           paquetes usan una lista explícita (Steam sin «*»); el GDD y el plan de la v0.3 están como
##                           copias saneadas.

func escenarios() -> Array[String]:
	return ["core_voces_importantes", "core_voces_veto", "core_voces_eco", "core_voces_fermin", "core_voces_evento", "core_emoji", "core_comodin_estados", "core_comodin_real", "core_available_respawn", "core_respawn_estado", "core_allocation_respawn", "core_ezlaki_respawn", "core_ingles", "core_idioma_en_caliente", "core_hud_franjas", "core_convocan_de_a_uno", "core_respawn_piso", "core_repite_tramo", "core_cola_no_para", "core_reaparece_sin_bucle", "core_reaparece_colapso", "core_reaparece_reglas", "core_pistas_teclas", "core_regla_nombres"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"core_voces_importantes": await _voces_importantes(t)
		"core_voces_veto": await _voces_veto(t)
		"core_voces_eco": await _voces_eco(t)
		"core_voces_fermin": await _voces_fermin(t)
		"core_voces_evento": await _voces_evento(t)
		"core_emoji": await _emoji(t)
		"core_comodin_estados": await _comodin_estados(t)
		"core_comodin_real": await _comodin_real(t)
		"core_available_respawn": await _available_respawn(t)
		"core_respawn_estado": await _respawn_estado(t)
		"core_allocation_respawn": await _allocation_respawn(t)
		"core_ezlaki_respawn": await _ezlaki_respawn(t)
		"core_ingles": await _ingles(t)
		"core_idioma_en_caliente": await _idioma_en_caliente(t)
		"core_hud_franjas": await _hud_franjas(t)
		"core_convocan_de_a_uno": await _convocan_de_a_uno(t)
		"core_respawn_piso": await _respawn_piso(t)
		"core_repite_tramo": await _repite_tramo(t)
		"core_cola_no_para": await _cola_no_para(t)
		"core_reaparece_sin_bucle": await _sin_bucle(t)
		"core_reaparece_colapso": await _colapso_sin_bucle(t)
		"core_reaparece_reglas": await _reaparece_reglas(t)
		"core_pistas_teclas": await _pistas_teclas(t)
		"core_regla_nombres": await _regla_nombres(t)


func _cm(t: Node) -> ContactManager:
	return t.get_tree().get_first_node_in_group("contact_manager") as ContactManager


## Espera hasta que cond() o pasen `real_s` segundos del reloj del audio (sin escalar: el de las voces).
func _vd_until(t: Node, cond: Callable, real_s: float) -> bool:
	var t0 := VoiceDirector.now_ms()
	while not bool(cond.call()):
		if VoiceDirector.now_ms() - t0 > int(real_s * 1000.0):
			return false
		await t.frames(1)
	return true


func _vd_wait(t: Node, real_s: float) -> void:
	var t0 := VoiceDirector.now_ms()
	while VoiceDirector.now_ms() - t0 < int(real_s * 1000.0):
		await t.frames(1)


func _idle(t: Node, real_s: float = 40.0) -> bool:
	return await _vd_until(t, func() -> bool: return VoiceDirector.current == null and VoiceDirector.queue.is_empty(), real_s)


## Turno en marcha, sentado, sin contactos ni nada que hable por su cuenta, con el director limpio.
func _quiet_shift(t: Node, agent: String = "Marko") -> void:
	await t.start_shift(agent, 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.frames(3)
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	await _vd_wait(t, 0.3)
	VoiceDirector.reset_audit()


func _cur_id() -> String:
	return VoiceDirector.current.id if VoiceDirector.current != null else ""


# --- 1. Líneas importantes y relleno -------------------------------------------------------------------------

func _voces_importantes(t: Node) -> void:
	# En el menú (sin turno en marcha): el director es un autoload y aquí nadie más habla ni corre el reloj del juego.
	await t.back_to_menu()
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	await _vd_wait(t, 0.3)
	VoiceDirector.reset_audit()
	var vd := VoiceDirector
	var peak := [0]
	var watch := func() -> void: peak[0] = maxi(peak[0], vd.voices_playing())
	t.get_tree().process_frame.connect(watch)
	var notes: Array = []
	var on_note := func(sp: String, tx: String, _s: float, must: bool) -> void:
		if tx != "":
			notes.append([sp, tx, must])
	vd.notice_shown.connect(on_note)
	var g := "contacto:prueba"

	# (a) El cliente habla; lo convocan por los parlantes: la convocatoria espera (no corta al cliente) y suena después.
	var a: Object = vd.say("voces/clientes/t1c1_inicio", vd.P.CLIENTE, "clientes", Callable(), {"text": "Aló, ¿KipuPay? Mi envío no llega.", "bus": "Auricular", "group": g, "elsewhere": true})
	await t.frames(2)
	var b: Object = vd.say("voces/shero/convocar", vd.P.DIRECTO, "shero", Callable(), {"text": "Shero (parlantes): Marko, a mi sitio. Ahora.", "bus": "Parlantes"})
	t.check(vd.current == a and vd.queue.has(b) and bool(b.get("must")), "con el cliente hablando, la convocatoria espera su turno (importante)")
	var b_started := await _vd_until(t, func() -> bool: return vd.current == b, 14.0)
	t.check(b_started and str(a.get("result")) == "dicha", "el cliente termina su frase (%s) y después suena la convocatoria" % str(a.get("result")))
	# (b) Contestas y el cliente pasa a su línea siguiente mientras suena la convocatoria: NO la corta; espera.
	var c: Object = vd.say("voces/clientes/t1c1_pide_numero", vd.P.CLIENTE, "clientes", Callable(), {"text": "¿Qué número le doy?", "bus": "Auricular", "group": g, "elsewhere": true})
	t.check(vd.current == b and vd.queue.has(c), "una importante que ya suena no se corta: el cliente (más prioridad) espera a que termine")
	var c_started := await _vd_until(t, func() -> bool: return vd.current == c, 14.0)
	t.check(c_started and str(b.get("result")) == "dicha", "la convocatoria se dijo entera (%s) y entonces habló el cliente" % str(b.get("result")))
	# (c) Contestas antes de que el cliente termine: su línea siguiente (mismo contacto) lo reemplaza en el acto.
	await _vd_wait(t, 0.5)
	var d: Object = vd.say("voces/clientes/t1c1_revisa", vd.P.CLIENTE, "clientes", Callable(), {"text": "Ya, reviso.", "bus": "Auricular", "group": g, "elsewhere": true})
	t.check(vd.current == d and str(c.get("result")) == "interrumpida", "el cliente del mismo contacto se reemplaza a sí mismo (la voz va con lo que ves en Kardex)")
	t.check(int(vd.lines_dropped) == 0 and vd.lost_important.is_empty(), "nada perdido hasta aquí (descartadas %d)" % int(vd.lines_dropped))
	await _idle(t)

	# (d) La misma línea pedida 5 veces seguidas no se apila; la pregunta que viene detrás suena.
	var said_bien := [0]
	var on_start := func(id2: String, _sp: String, _p: int) -> void:
		if id2.contains("karaoke_bien"):
			said_bien[0] += 1
	vd.line_started.connect(on_start)
	for i in 5:
		PersonajesP5.say("Rasec", "rasec", "karaoke_bien", "¡Eso! Más fuerte. Que te escuche Shero.")
		await t.frames(2)
	var prompt: Object = vd.say("voces/rasec/q4_karaoke_d2", vd.P.DIRECTO, "rasec", Callable(), {"text": "[Rasec] Segunda estrofa. ¿Quién sigue?"})
	t.check(int(vd.lines_merged) >= 4 and vd.queue.size() <= 1, "5 veces la misma línea = 1 sonando (repetidas %d · en cola %d)" % [int(vd.lines_merged), vd.queue.size()])
	var p_ok := await _vd_until(t, func() -> bool: return bool(prompt.get("done")), 20.0)
	t.check(p_ok and str(prompt.get("result")) == "dicha" and said_bien[0] == 1, "la pregunta de Rasec suena (%s) y «¡Eso! Más fuerte» sonó una vez (%d)" % [str(prompt.get("result")), said_bien[0]])
	vd.line_started.disconnect(on_start)
	await _idle(t)

	# (e) El aviso del compañero («no te pares») es importante: espera detrás de Rasec y suena.
	var r1: Object = vd.say("voces/rasec/inicio_karaoke", vd.P.DIRECTO, "rasec", Callable(), {"text": "[Rasec] ¡Karaoke!"})
	await t.frames(2)
	AudioManager.play_voice("comp", "comp_no_te_pares", TranslationServer.translate("COMP_NO_TE_PARES"), "Sala")
	var warn: Object = null
	for q in vd.queue:
		if str((q as Object).get("id")).contains("comp_no_te_pares"):
			warn = q
	t.check(warn != null and bool(warn.get("must")) and vd.current == r1, "el aviso del compañero espera detrás de Rasec (importante)")
	var w_ok := warn != null and await _vd_until(t, func() -> bool: return bool(warn.get("done")), 20.0)
	t.check(w_ok and str(warn.get("result")) == "dicha", "y suena cuando Rasec termina (%s)" % (str(warn.get("result")) if warn != null else "—"))
	await _idle(t)

	# (f) El relleno (susurro de un compañero harto) cede ante una directa y vence en cola: eso sí puede perderse.
	var fill: Object = vd.say("voces/comp/q4_harto_2", vd.P.AMBIENTE, "comp", Callable(), {"text": "[Jiroshi susurra] Otra vez el karaoke…", "must": false})
	await t.frames(2)
	var r2: Object = vd.say("voces/rasec/q4_karaoke_d1", vd.P.DIRECTO, "rasec", Callable(), {"text": "[Rasec] ¿Quién abre el karaoke?"})
	t.check(vd.current == r2 and str(fill.get("result")) == "interrumpida", "un relleno que suena lo corta una línea directa")
	var fill2: Object = vd.say("voces/comp/q4_harto_3", vd.P.AMBIENTE, "comp", Callable(), {"text": "[Llauri susurra] No aplaudas.", "must": false, "max_wait": 0.4})
	var dropped_before := int(vd.lines_dropped)
	await _vd_until(t, func() -> bool: return bool(fill2.get("done")), 6.0)
	t.check(str(fill2.get("result")) == "vencida" and int(vd.lines_dropped) == dropped_before + 1 and vd.lost_important.is_empty(), "un relleno que no puede sonar a tiempo vence (y no cuenta como importante perdida)")
	await _idle(t)

	# (g) Una importante que no logra sonar en su plazo sale como AVISO de texto (no desaparece).
	var long1: Object = vd.say("voces/shero/shero_que_tomo_tanto", vd.P.DIRECTO, "shero", Callable(), {"text": "Shero: ¿Qué te tomó tanto?"})
	await t.frames(2)
	var late: Object = vd.say("voces/otros/fermin_pase_limpio", vd.P.AMBIENTE, "otros", Callable(), {"text": "[Don Fermín] Pase, está limpio.", "max_wait": 1.0})
	t.check(vd.current == long1 and bool(late.get("must")), "una importante espera detrás de una línea larga")
	await _vd_until(t, func() -> bool: return bool(late.get("done")), 6.0)
	var noted := false
	for n in notes:
		noted = noted or (str(n[1]).contains("Pase, está limpio") and bool(n[2]))
	t.check(str(late.get("result")) == "aviso" and int(vd.lines_noticed) == 1 and noted, "pasado su plazo sale como aviso de texto importante (%s · avisos %d)" % [str(late.get("result")), int(vd.lines_noticed)])
	vd.cancel(long1, "prueba")
	await _idle(t)

	# (h) Un aviso de Ezlaki no ocupa el canal: la voz que llega arranca en el acto y el aviso se ve arriba.
	vd.clear_notices()
	notes.clear()
	EventBus.subtitle.emit("ezlak", "@Shero · Shero: ¿Dónde estás?", 4.0)
	t.check(vd.current == null and str(vd.notice_current.get("text", "")).contains("¿Dónde estás?"), "el resumen de un DM es un aviso (no una línea de voz)")
	var v1: Object = vd.say("voces/comp/comp_viene_shero", vd.P.AMBIENTE, "comp", Callable(), {"text": "(susurro) Viene. No lo mires."})
	t.check(vd.current == v1 and int(v1.get("started_ms")) >= 0, "y no retrasa a la voz siguiente")
	# (i) Un anuncio de ambiente sin voz (relleno de texto) no retrasa a nadie: lo corta cualquier voz.
	await _idle(t)
	var pa: Object = vd.text("parlantes", "El ascensor 2 sigue en mantenimiento. No lo esperen.", 5.0, {"must": false, "priority": vd.P.AMBIENTE})
	t.check(vd.current == pa, "con el canal libre, el anuncio de ambiente se ve como subtítulo")
	var v2: Object = vd.say("voces/rasec/fin_evento", vd.P.DIRECTO, "rasec", Callable(), {"text": "[Rasec] ¡Gracias por participar!"})
	t.check(vd.current == v2 and bool(pa.get("done")), "y una voz lo reemplaza en el acto (antes retenía el canal 5 s)")
	await _idle(t)
	t.get_tree().process_frame.disconnect(watch)
	vd.notice_shown.disconnect(on_note)
	t.note(vd.audit_line())
	t.check(int(vd.overlaps) == 0 and peak[0] <= 1, "0 solapes (%d) y nunca más de una voz a la vez (máx. %d)" % [int(vd.overlaps), peak[0]])
	t.check(vd.lost_important.is_empty(), "0 líneas importantes perdidas %s" % str(vd.lost_important))
	await t.back_to_menu()


# --- 1c. Lo que piensa tu agente (eco del Training) es relleno ----------------------------------------------------

func _voces_eco(t: Node) -> void:
	await t.back_to_menu()
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	await _vd_wait(t, 0.3)
	VoiceDirector.reset_audit()
	var vd := VoiceDirector
	var eco_text := "(Marko) Promoción del 25 de julio de 2025. Éramos cinco."
	var eco := func() -> Object:
		return vd.say("voces/agentes/marko_eco_foto", vd.P.AMBIENTE, "piensa", Callable(), {"text": eco_text, "bus": "UI", "max_wait": 8.0, "dedupe": false})
	# (a) El cliente lo corta en el acto.
	var e1: Object = eco.call()
	await t.frames(2)
	t.check(vd.current == e1 and not bool(e1.get("must")), "el eco suena y es relleno (importante: %s)" % str(e1.get("must")))
	var cli: Object = vd.say("voces/clientes/t1c1_inicio", vd.P.CLIENTE, "clientes", Callable(), {"text": "Aló, ¿KipuPay?", "bus": "Auricular", "elsewhere": true})
	await t.frames(2)
	t.check(vd.current == cli and bool(e1.get("done")) and str(e1.get("result")) == "interrumpida", "entra el cliente: su voz arranca en el acto y el eco se calla (%s)" % str(e1.get("result")))
	vd.cancel(cli, "prueba")
	await _idle(t)
	# (b) Haime (y cualquier jefe: DIRECTO) también.
	var e2: Object = eco.call()
	await t.frames(2)
	var h: Object = vd.say("voces/haime/advertencia", vd.P.DIRECTO, "haime", Callable(), {"text": "[Haime] Siéntate.", "elsewhere": true})
	await t.frames(2)
	t.check(vd.current == h and bool(e2.get("done")), "empieza la calibración de Haime: sin esperar al eco")
	vd.cancel(h, "prueba")
	await _idle(t)
	# (c) Un susurro de la sala (misma prioridad) no lo corta: espera.
	var e3: Object = eco.call()
	await t.frames(2)
	var w: Object = vd.say("voces/comp/comp_no_te_pares", vd.P.AMBIENTE, "comp", Callable(), {"text": "(susurro) No te pares. No ahora."})
	await t.frames(2)
	t.check(vd.current == e3 and vd.queue.has(w), "un susurro de la sala espera a que tu agente termine de pensar")
	vd.stop_all("prueba")
	await _idle(t)
	# (d) El monólogo del Training va como DIRECTO: sigue siendo importante (no lo corta un jefe a medias).
	var mono: Object = vd.say("voces/agentes/marko_eco_foto", vd.P.DIRECTO, "piensa", Callable(), {"text": "(Marko) Primer día.", "bus": "UI", "dedupe": false})
	await t.frames(2)
	t.check(bool(mono.get("must")), "el monólogo del Training (DIRECTO) sigue siendo importante")
	vd.stop_all("prueba")
	await _idle(t)
	t.check(vd.lost_important.is_empty() and int(vd.overlaps) == 0, "ninguna importante perdida y 0 solapes (%d)" % int(vd.overlaps))
	# (e) De principio a fin con el eco de verdad: partida nueva, te sientas en C-14, tu agente piensa en la foto y
	#     entra la primera llamada: el cliente se oye enseguida.
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var said: Array = []
	var on_line := func(id: String, speaker: String, _p: int) -> void: said.append([id, speaker])
	vd.line_started.connect(on_line)
	var thought: bool = await _vd_until(t, func() -> bool: return vd.current != null and str(vd.current.speaker) == "piensa", 12.0)
	t.check(thought, "al sentarte por primera vez tu agente piensa en la foto (suena %s)" % _cur_id())
	var cm := _cm(t)
	var first: Dictionary = cm.next_scripted()
	GameState.clock_seconds = ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0
	await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 12.0)
	var eco_line: Object = vd.current if vd.current != null and str(vd.current.speaker) == "piensa" else null
	cm.accept()
	# La 1.ª llamada del turno va monitoreada: primero el «[REC] Esta llamada puede ser monitoreada…» de Haime (~4 s,
	# importante) y enseguida el cliente. Ninguno de los dos espera a que tu agente termine de pensar.
	var cut: bool = await _vd_until(t, func() -> bool: return eco_line == null or bool(eco_line.get("done")), 1.5)
	t.check(cut, "aceptas la primera llamada con el eco sonando: el eco se calla en el acto (suena %s)" % _cur_id())
	var heard: bool = await _vd_until(t, func() -> bool:
		for row in said:
			if str(row[1]) in ["clientes", "cliente"]:
				return true
		return false, 10.0)
	t.check(heard, "y la voz del cliente arranca sin esperar los ~10 s del eco (%s)" % str(said.slice(maxi(said.size() - 4, 0))))
	vd.line_started.disconnect(on_line)
	await t.back_to_menu()


# --- 1b. Veto al empezar (la calibración de Haime calla a los demás) ---------------------------------------------

func _voces_veto(t: Node) -> void:
	await t.back_to_menu()
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	await _vd_wait(t, 0.3)
	VoiceDirector.reset_audit()
	var vd := VoiceDirector
	var subs: Array = []
	var on_sub := func(sp: String, tx: String, _s: float) -> void: subs.append([sp, tx])
	vd.subtitle_shown.connect(on_sub)
	# El mismo portero que usa la calibración (qa_feedback.gd, v0.3.2-haime): al empezar una línea ajena por debajo del
	# cliente, la corta en el acto.
	var gate_on := [true]
	var silenced: Array = []
	var gate := func(id: String, speaker: String, priority: int) -> void:
		if not gate_on[0] or priority >= vd.P.CLIENTE or speaker in ["haime", "haime_replay"]:
			return
		var l: Variant = vd.current
		if l == null or str(l.id) != id:
			return
		silenced.append(id)
		vd.cancel(l, "calibración")
	vd.line_started.connect(gate)
	# (a) Haime habla; por los parlantes convocan al jugador: espera su turno, arranca en el silencio de Haime y el
	#     portero la corta. Era importante y tenía texto: sale como aviso, no se pierde.
	var h1: Object = vd.say("voces/haime/advertencia", vd.P.DIRECTO, "haime", Callable(), {"text": "[Haime] Siéntate.", "elsewhere": true})
	await t.frames(2)
	var conv_text := "Shero (parlantes): Marko, a mi sitio. Ahora."
	var conv: Object = vd.say("voces/shero/convocar", vd.P.DIRECTO, "shero", Callable(), {"text": conv_text, "bus": "Parlantes"})
	t.check(vd.current == h1 and vd.queue.has(conv), "con Haime hablando, la convocatoria de Shero espera en la cola")
	t.check(await _vd_until(t, func() -> bool: return bool(conv.get("done")), 16.0), "cuando Haime calla, la convocatoria arranca y el portero la corta (o, si Haime tarda, sale como aviso)")
	t.check(str(conv.get("result")) == "aviso", "la convocatoria no se pierde: su texto sale como aviso (%s; cortada al empezar: %s)" % [str(conv.get("result")), silenced.has("voces/shero/convocar")])
	t.check(_notice_seen(conv_text), "el aviso lleva el texto de la convocatoria")
	t.check(vd.lost_important.is_empty() and int(vd.lines_noticed) == 1, "ninguna importante perdida (a texto %d, vetadas %d)" % [int(vd.lines_noticed), int(vd.lines_vetoed)])
	await _idle(t)
	# (a2) Lo mismo con el canal libre: arranca en el acto y el portero la corta en ese mismo instante.
	subs.clear()
	var conv2_text := "Rasec (parlantes): ¡Todos al centro de la sala!"
	var conv2: Object = vd.say("voces/rasec/inicio_karaoke", vd.P.DIRECTO, "rasec", Callable(), {"text": conv2_text})
	await t.frames(2)
	t.check(bool(conv2.get("done")) and str(conv2.get("result")) == "aviso" and silenced.has("voces/rasec/inicio_karaoke"), "cortada en el instante de empezar → aviso (%s)" % str(conv2.get("result")))
	t.check(_notice_seen(conv2_text) and int(vd.lines_vetoed) >= 1 and vd.lost_important.is_empty(), "con su texto arriba y sin contarla como perdida (vetadas %d)" % int(vd.lines_vetoed))
	t.check(not subs.is_empty() and str((subs[subs.size() - 1] as Array)[1]) == "", "su subtítulo no se queda en pantalla sin voz")
	await _vd_wait(t, 0.3)
	t.check(vd.voices_playing() == 0, "y no queda sonando (%d voces)" % vd.voices_playing())
	# (b) Relleno (un susurro de la sala): se calla sin aviso.
	var notes0 := vd.notice_log.size()
	var w: Object = vd.say("voces/comp/q4_harto_1", vd.P.AMBIENTE, "comp", Callable(), {"text": "(susurro) Otra vez…", "must": false})
	await t.frames(3)
	t.check(bool(w.get("done")) and str(w.get("result")) == "interrumpida" and vd.notice_log.size() == notes0 and not _notice_seen("(susurro) Otra vez…"), "el relleno vetado se calla sin aviso (%s)" % str(w.get("result")))
	# (c) El cliente (prioridad CLIENTE) pasa el portero.
	var cli: Object = vd.say("voces/clientes/t1c1_inicio", vd.P.CLIENTE, "clientes", Callable(), {"text": "Aló, ¿KipuPay?", "bus": "Auricular", "elsewhere": true})
	await t.frames(2)
	t.check(vd.current == cli and not silenced.has("voces/clientes/t1c1_inicio"), "el cliente no es asunto del portero")
	vd.cancel(cli, "prueba")
	await _idle(t)
	# (d) Importante cuyo texto ya está en otra parte: vetada, sin aviso ni pérdida.
	var e: Object = vd.say("voces/shero/convocar", vd.P.DIRECTO, "shero", Callable(), {"text": "Texto que ya se lee en otra parte", "elsewhere": true})
	await t.frames(3)
	t.check(bool(e.get("done")) and not _notice_seen("Texto que ya se lee en otra parte") and vd.lost_important.is_empty(), "importante con el texto ya en pantalla: vetada sin aviso y sin contarla como perdida")
	# (e) Importante sin texto (solo voz): no hay nada que mostrar → queda anotada (la auditoría la ve).
	var f: Object = vd.say("voces/shero/convocar", vd.P.DIRECTO, "shero", Callable(), {"dedupe": false})
	await t.frames(3)
	t.check(bool(f.get("done")) and vd.lost_important.size() == 1, "importante sin texto vetada: queda anotada como perdida (%d)" % vd.lost_important.size())
	# (f) Sin portero: cancelar una línea propia A MEDIAS (lo que hace Haime con las suyas) no la convierte en aviso.
	gate_on[0] = false
	var notes1 := vd.notice_log.size()
	var own_text := "[Haime] Cincuenta y ocho sobre cien."
	var own: Object = vd.say("voces/haime/advertencia", vd.P.DIRECTO, "haime", Callable(), {"text": own_text, "dedupe": false})
	await _vd_wait(t, 0.4)
	t.check(vd.current == own, "la línea propia está sonando")
	vd.cancel(own, "acelerado")
	await t.frames(2)
	t.check(str(own.get("result")) == "interrumpida" and vd.notice_log.size() == notes1 and not _notice_seen(own_text), "cancelada a medias por su dueño: interrumpida, sin aviso")
	t.check(int(vd.overlaps) == 0, "0 solapes (%d)" % int(vd.overlaps))
	vd.line_started.disconnect(gate)
	vd.subtitle_shown.disconnect(on_sub)
	vd.stop_all("prueba")
	vd.clear_notices()


# --- 2. La revisión de Don Fermín a velocidad real --------------------------------------------------------------

func _voces_fermin(t: Node) -> void:
	await t.start_shift("Llauri", 1)
	await t.frames(4)
	var guard := t.get_tree().get_first_node_in_group("p5_guardia")
	if not t.check(guard != null and bool(guard.call("needs_check")), "llegas al lobby: Don Fermín tiene que revisarte"):
		await t.back_to_menu()
		return
	VoiceDirector.stop_all("prueba")
	await _vd_wait(t, 0.3)
	VoiceDirector.reset_audit()
	var order: Array = []
	var on_start := func(id2: String, _sp: String, _p: int) -> void:
		if id2.contains("fermin_"):
			order.append(id2.get_file())
	VoiceDirector.line_started.connect(on_start)
	var peak := [0]
	var watch := func() -> void: peak[0] = maxi(peak[0], VoiceDirector.voices_playing())
	t.get_tree().process_frame.connect(watch)
	var scale := Engine.time_scale
	Engine.time_scale = 1.0  # a velocidad real: las voces duran lo que duran
	var t0 := VoiceDirector.now_ms()
	guard.call("start_check")
	var done := await _vd_until(t, func() -> bool: return bool(GameState.flags.get("revision_ok", false)), 75.0)
	var check_s := (VoiceDirector.now_ms() - t0) / 1000.0
	await _idle(t, 20.0)
	Engine.time_scale = scale
	VoiceDirector.line_started.disconnect(on_start)
	t.get_tree().process_frame.disconnect(watch)
	t.note("revisión: %.1f s · líneas %s · %s" % [check_s, str(order), VoiceDirector.audit_line()])
	t.check(done, "la revisión termina (%.1f s)" % check_s)
	var want := ["saludo", "fotocheck", "mochila", "detector", "celular", "pase_limpio"]
	var in_order := order.size() == want.size()
	for i in mini(order.size(), want.size()):
		in_order = in_order and str(order[i]).contains(str(want[i])) or (i == 0 and str(order[i]).contains("tarde"))
	t.check(in_order, "sus 6 líneas suenan, en orden: %s" % str(order))
	t.check(int(VoiceDirector.lines_dropped) == 0 and int(VoiceDirector.lines_noticed) == 0 and VoiceDirector.lost_important.is_empty(), "ninguna vence ni queda en aviso (descartadas %d · a texto %d)" % [int(VoiceDirector.lines_dropped), int(VoiceDirector.lines_noticed)])
	t.check(int(VoiceDirector.overlaps) == 0 and peak[0] <= 1, "0 solapes (%d · máx. %d voces)" % [int(VoiceDirector.overlaps), peak[0]])
	t.check(check_s <= 45.0, "y no se alarga más de la cuenta (%.1f s ≤ 45 s)" % check_s)
	var pl: Player = t.player()
	t.check(pl != null and not pl.input_locked, "al terminar te devuelve el control")
	await t.back_to_menu()


# --- 3. El evento de Rasec a velocidad real ----------------------------------------------------------------------

func _voces_evento(t: Node) -> void:
	await _quiet_shift(t, "Llauri")
	var hub := PersonajesP5.get_hub(t.get_tree())
	var rasec: RasecControl = hub.rasec
	if not t.check(rasec != null, "hay Rasec en el turno"):
		await t.back_to_menu()
		return
	var started_ids: Array = []
	var fillers := [0]
	var on_start := func(id2: String, sp: String, _p: int) -> void:
		started_ids.append(id2.get_file())
		if sp == "comp":
			fillers[0] += 1
	VoiceDirector.line_started.connect(on_start)
	var peak := [0]
	var watch := func() -> void: peak[0] = maxi(peak[0], VoiceDirector.voices_playing())
	t.get_tree().process_frame.connect(watch)
	var scale := Engine.time_scale
	Engine.time_scale = 1.0  # a velocidad real
	rasec.forced_play = "ok"  # un jugador rápido: canta a los 0,35 s y decide a los 0,5 s (el peor caso para las voces)
	Metrics.set_aux(Metrics.Aux.BO)
	rasec.call_event("karaoke")
	await t.frames(3)
	var pl: Player = t.player()
	pl.stand_up()
	await t.frames(2)
	var mk := hub.marker("evento_rasec")
	if mk != null:
		pl.teleport(mk.global_position, 0.0)
	var began := await _vd_until(t, func() -> bool: return rasec.state == RasecControl.State.EVENTO, 20.0)
	t.check(began, "llegas en BO al centro de la sala: empieza el evento")
	var t0 := VoiceDirector.now_ms()
	# Las decisiones del evento (inicio, mitad y final del karaoke); el relleno de después se salta adelantando el reloj.
	await _vd_until(t, func() -> bool: return rasec.state != RasecControl.State.EVENTO or rasec.decisions_log.size() >= 3, 150.0)
	var event_s := (VoiceDirector.now_ms() - t0) / 1000.0
	await _idle(t, 30.0)
	var asked: Array = []
	for d in rasec.decisions_log:
		asked.append(str((d as Dictionary).get("pregunta", "")))
	var noticed: Array = []
	for n in VoiceDirector.notice_log:
		if bool(n[3]):
			noticed.append(str(n[2]).left(40))
	var missing: Array = []
	for q in asked:
		var heard := false
		for id2 in started_ids:
			heard = heard or str(id2).begins_with(str(q))
		if not heard:
			missing.append(q)
	t.note("evento: %.0f s · preguntas %s · sin voz %s · avisos importantes %s · susurros %d · %s" % [event_s, str(asked), str(missing), str(noticed), fillers[0], VoiceDirector.audit_line()])
	t.check(asked.size() >= 2, "Rasec hizo sus preguntas (%d)" % asked.size())
	t.check(missing.is_empty(), "todas sus preguntas SONARON (antes vencían en la cola detrás de «¡Eso! Más fuerte»): faltan %s" % str(missing))
	t.check(VoiceDirector.lost_important.is_empty() and noticed.is_empty(), "ninguna línea importante se perdió ni quedó en aviso de texto %s %s" % [str(VoiceDirector.lost_important), str(noticed)])
	var no_te_pares := false
	for id2 in started_ids:
		no_te_pares = no_te_pares or str(id2).contains("comp_no_te_pares")
	for n in VoiceDirector.notice_log:
		no_te_pares = no_te_pares or str(n[2]) == TranslationServer.translate("COMP_NO_TE_PARES")
	t.check(not no_te_pares, "el compañero no te dice «no te pares» cuando Rasec te convocó a pararte")
	t.check(int(VoiceDirector.overlaps) == 0 and peak[0] <= 1, "0 solapes (%d · máx. %d voces)" % [int(VoiceDirector.overlaps), peak[0]])
	Engine.time_scale = scale
	rasec.forced_play = ""
	VoiceDirector.line_started.disconnect(on_start)
	t.get_tree().process_frame.disconnect(watch)
	await t.back_to_menu()


# --- 4. Emojis --------------------------------------------------------------------------------------------------

func _emoji(t: Node) -> void:
	var missing: Array = []
	var bad_size: Array = []
	for e in Emoji.TABLE.keys():
		var tex := Emoji.texture(str(e))
		if tex == null:
			missing.append(e)
		elif tex.get_width() != 64 or tex.get_height() != 64:
			bad_size.append(e)
	t.check(missing.is_empty() and bad_size.is_empty() and Emoji.TABLE.size() >= 30, "%d emojis con su dibujo de 64×64 (faltan %s)" % [Emoji.TABLE.size(), str(missing)])
	var no_art: Array = []
	for e in EzlakHub.reaction_choices() + ["✅", "👍", "👀", "🫡", "🙏"]:
		if Emoji.texture(str(e)) == null:
			no_art.append(e)
	t.check(no_art.is_empty(), "todas las reacciones del selector y de la pared tienen dibujo (faltan %s)" % str(no_art))
	var bb := Emoji.bb("👍", 18)
	t.check(bb.begins_with("[img") and bb.contains("res://assets/ui/emoji/1f44d.png") and bb.contains("tooltip="), "Emoji.bb = imagen con su nombre de tooltip: %s" % bb)
	var rich := Emoji.rich("Buen trabajo team 💪🔥 sigan así ❤️")
	t.check(rich.count("[img") == 3 and not rich.contains("💪") and not rich.contains("️"), "un mensaje con emojis → 3 imágenes y ningún carácter que la fuente no tiene")
	var plain := Emoji.plain("Listo ✅ gracias 🙏 team 🎉")
	t.check(plain == "Listo [OK] gracias [gracias] team", "en un Label (sin BBCode) queda la etiqueta de los que significan algo: «%s»" % plain)
	t.check(Emoji.plain("sin emojis: ñ á ♪ ✓ ★ «»") == "sin emojis: ñ á ♪ ✓ ★ «»" and Emoji.rich("a ♪ ✓ b") == "a ♪ ✓ b", "lo que la fuente sí tiene no se toca")
	t.check(Emoji.rich("raro 🦄 fin") == "raro  fin", "un emoji sin dibujo se quita (no deja un recuadro vacío)")
	# En la PC de verdad: el aviso de coaching con su pared, el selector y un mensaje con emojis.
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var ws: Node = t.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	var app: PcEzlak = ws.get("ezlak")
	var hub: EzlakHub = ws.get("hub")
	app.open_channel("#team-familia")
	EventBus.ezlak_post.emit("#team-familia", "rasec", "¡Vamos team! 💪🔥 Hoy la rompemos 🎉", {})
	EventBus.ezlak_post.emit("#team-familia", "shero", "@here Team, coaching a las 7:30. Espero su reacción para saber que están al tanto.", {"pide_reaccion": true, "mention": true})
	await t.seconds(0.6)
	app.refresh(0.016, true)
	await t.frames(3)
	var parsed := app.visible_text()
	t.check(not parsed.contains("💪") and not parsed.contains("[OK]") and not parsed.contains("[+1]"), "en el chat no quedan ni caracteres sin dibujo ni etiquetas de texto")
	var rasec_msg: Dictionary = {}
	var notice: Dictionary = {}
	for mm in hub.messages("#team-familia"):
		if str(mm.get("autor", "")) == "rasec" and str(mm.get("texto", "")).contains("💪"):
			rasec_msg = mm
		if bool(mm.get("pide_reaccion", false)):
			notice = mm
	t.check(not rasec_msg.is_empty() and PcStyle.rich(str(rasec_msg.get("texto", ""))).count("[img") == 3, "el mensaje de Rasec lleva sus 3 emojis como imágenes")
	if not t.check(not notice.is_empty(), "el aviso de Shero pide reacción"):
		await t.back_to_menu()
		return
	# la pared: los compañeros van reaccionando; cada reacción es un dibujo con su contador
	await t.until(func() -> bool: return (notice.get("emojis", []) as Array).size() >= 1, 60.0)
	var row := app.emoji_row_bb(notice)
	t.check(row.count("[img") >= 1 and row.count("[img") == (notice.get("emojis", []) as Array).size() and not row.contains("[OK]"), "pared de reacciones: %d emojis distintos, todos como dibujo" % row.count("[img"))
	app.open_picker()
	await t.frames(3)
	var pk := app.picker_bb(notice)
	t.check(app.picker_id == int(notice.get("id", -1)) and pk.count("[img") == EzlakHub.reaction_choices().size() and pk.count("tooltip=") == pk.count("[img"), "el selector muestra sus %d emojis como dibujos, cada uno con su nombre de tooltip" % EzlakHub.reaction_choices().size())
	t.check(hub.player_react(notice, "👍") == "acuse", "reaccionas con el pulgar: cuenta como acuse")
	app.refresh(0.016, true)
	await t.frames(3)
	t.check(app.emoji_row_bb(notice).contains("1f44d.png"), "y tu pulgar queda en la fila del aviso")
	Loc.set_setting("emoji_texto", true)
	t.check(Emoji.bb("👍") == "[lb]+1]" and Emoji.rich("ok 👍") == "ok [lb]+1]", "con «Emojis como texto» (accesibilidad) vuelve la etiqueta: %s" % Emoji.bb("👍"))
	Loc.set_setting("emoji_texto", false)
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	await t.back_to_menu()


# --- 5. El comodín dice quién puede contestar ------------------------------------------------------------------

func _comodin_estados(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	IABrain.forget_all()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	var names := Comodin.coworkers()
	# (a) El panel muestra el estado de cada uno, en vivo.
	IABrain.presence_override = {"jiroshi": "llamada", "llauri": "lunch", "ttoom": "activo", "juan": "ausente"}
	t.check(Comodin.open(), "lejos de tu PC abres el comodín")
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	var txt := Comodin.ui_text()
	var tr_ := func(k: String) -> String: return TranslationServer.translate(k)
	t.check(txt.contains("Jiroshi") and txt.contains(tr_.call("IA_PRES_LLAMADA")) and txt.contains(tr_.call("IA_PRES_LUNCH")) and txt.contains(tr_.call("IA_PRES_ACTIVO")) and txt.contains(tr_.call("IA_PRES_AUSENTE")), "el panel dice el estado de cada compañero: «%s»" % txt.replace("\n", " / ").right(150))
	t.check(txt.contains(tr_.call("B2_COMODIN_ONLY_ACTIVE")) and Comodin.anyone_active(), "y que solo contesta quien está «activo»")
	IABrain.presence_override["ttoom"] = "llamada"
	await _vd_wait(t, 0.8)  # el panel se refresca cada 0,5 s reales
	txt = Comodin.ui_text()
	t.check(not Comodin.anyone_active() and txt.contains(tr_.call("B2_COMODIN_NOBODY")) and not Comodin.used, "si nadie está activo lo avisa ANTES de gastar el comodín")
	# (b) [Esc] sin llamar no lo gasta.
	Comodin.cancel()
	t.check(Comodin.phase == "" and not Comodin.used, "cerrar sin llamar no gasta el comodín")
	# (c) Lo que viste vale: activo al llamar = contesta, aunque le entre un contacto mientras suena.
	IABrain.presence_override["ttoom"] = "activo"
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	Comodin.choose_coworker(names.find("Ttoom"))
	IABrain.presence_override["ttoom"] = "llamada"  # le entra una llamada mientras suena el teléfono
	await t.until(func() -> bool: return Comodin.phase != "ringing", 40.0)
	t.check(Comodin.phase == "" and Metrics.aux == Metrics.Aux.AVAILABLE, "llamaste a Ttoom estando «activo»: contesta y te marca Available aunque después le entró una llamada")
	await t.back_to_menu()
	# (d) Por qué no contestó: cada estado dice lo suyo; y con el mismo comodín puedes llamar a otro.
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	IABrain.forget_all()
	cm = _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var acd: ColaACD = cm.acd
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	IABrain.presence_override = {}
	VoiceDirector.clear_notices()
	VoiceDirector.reset_audit()
	acd.npc_busy_until["Jiroshi"] = GameState.clock_seconds + 3600.0  # Jiroshi en un contacto
	names = Comodin.coworkers()
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.BO)
	Comodin.choose_coworker(names.find("Jiroshi"))
	await t.until(func() -> bool: return Comodin.phase != "ringing", 40.0)
	await t.frames(3)
	var busy_txt := Loc.fmt(tr_.call("B2_COMODIN_BUSY"), {"quien": "Jiroshi"})
	t.check(Comodin.phase == "retry" and str(Comodin.last_fail.get("clave", "")) == "B2_COMODIN_BUSY" and _notice_seen(busy_txt), "Jiroshi en llamada: no contesta y el aviso dice por qué («%s»)" % busy_txt)
	txt = Comodin.ui_text()
	t.check(txt.contains(tr_.call("B2_COMODIN_TRIED")) and Metrics.aux != Metrics.Aux.BO, "en el reintento su nombre queda como «%s»" % tr_.call("B2_COMODIN_TRIED"))
	# estados que antes solo decían «no contesta»
	t.check(Comodin.fail_key("X", "break", "presencia") == "B2_COMODIN_BREAK" and Comodin.fail_key("X", "coaching", "presencia") == "B2_COMODIN_COACHING" and Comodin.fail_key("X", "training", "presencia") == "B2_COMODIN_TRAINING", "en break, en coaching y en Training tienen su propio motivo")
	t.check(Comodin.fail_key("X", "disponible", "rencor") == "B2_COMODIN_IGNORED", "y si estaba activo pero no quiso («vio tu llamada… y no contestó»)")
	for k in ["B2_COMODIN_BREAK", "B2_COMODIN_COACHING", "B2_COMODIN_TRAINING", "B2_COMODIN_AWAY", "B2_COMODIN_IGNORED", "B2_COMODIN_NOBODY", "B2_COMODIN_ONLY_ACTIVE", "B2_COMODIN_TRIED"]:
		if TranslationServer.translate(k) == k:
			t.fail("falta el texto " + k)
	var other := ""
	for n in names:
		if n != "Jiroshi" and str(Comodin.presence_of(n).get("estado", "")) == "activo":
			other = n
			break
	if other != "":
		Comodin.choose_coworker(names.find(other))
		await t.until(func() -> bool: return Comodin.phase != "ringing", 40.0)
		t.check(Comodin.phase == "" and Metrics.aux == Metrics.Aux.BO, "con el mismo comodín llamas a %s (activo): contesta y te marca BO" % other)
	else:
		t.note("ningún otro compañero activo a esta hora (no se probó el reintento con éxito)")
	IABrain.presence_override = {}
	await t.back_to_menu()


## ¿Ese aviso salió (se ve, espera su turno o ya pasó)?
## Un compañero y una hora del horario REAL del turno en que su estado del ACD es `st` ([nombre, hora] o []).
func _sched_find(acd: ColaACD, st: String, from: float = 0.0) -> Array:
	var sched: Dictionary = acd.get("_sched")
	for n in acd.coworkers():
		for b in sched.get(n, []):
			var mid := (float(b[0]) + float(b[1])) * 0.5
			if str(b[2]) == st and mid > from and acd.npc_state(n, mid) == st:
				return [n, mid]
	return []


## Llama a `n` con el comodín (ya abierto en «a quién») y espera a que conteste o no. Devuelve la fase final.
func _comodin_call(t: Node, n: String) -> String:
	Comodin.choose_coworker(Comodin.coworkers().find(n))
	await t.until(func() -> bool: return Comodin.phase != "ringing", 25.0)
	return Comodin.phase


func _comodin_real(t: Node) -> void:
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.start_calm(3600.0)  # sin Shero ni listas: aquí se mira el comodín, no la disciplina
	IABrain.forget_all()
	IABrain.presence_override = {}
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var acd: ColaACD = cm.acd
	# El escenario salta por el reloj del turno: el Training del jugador y el evento de Rasec se dan por hechos (si no,
	# al pasar por su hora convocan de verdad y matan la inasistencia). El horario de los compañeros no cambia.
	var p5 := PersonajesP5.get_hub(t.get_tree())
	if p5 != null and p5.training != null:
		p5.training.state = TrainingControl.State.HECHO
	if p5 != null and p5.rasec != null:
		p5.rasec.state = RasecControl.State.HECHO
	# Los recordatorios de Vitzo de las 3:00 y las 6:00 también se dan por hechos: los saltos de reloj los publican y, de pie
	# en el -1, su plazo lejos de la PC (v0.3.2-core4: 60 s desde otro piso, antes 90) vence a mitad de la prueba.
	var vz0 := t.get_tree().get_first_node_in_group("vitzo")
	if vz0 != null:
		(vz0.get("_hours_done") as Array).append_array([3, 6])
	var deaths: Array = t.spy("death_sequence_started")
	t.player().stand_up()
	t.building().go_to_floor(-1, "cafeteria")
	await t.frames(4)
	var tr_ := func(k: String) -> String: return TranslationServer.translate(k)
	# (a) Cada estado, sacado del horario del turno (nada forzado en IABrain ni en el comodín). El Training va al
	# final del escenario: saltar el reloj a su hora hace que el Trainer convoque de verdad (y persiga la inasistencia).
	var seen: Array[String] = []
	for st: String in ["contacto", "break", "coaching", "lunch", "dormido"]:
		if await _comodin_no_contesta(t, acd, st):
			seen.append(st)
	# BO y disponible: «activo» en Ezlaki, contestan y te marcan el AUX en tu PC.
	for st: String in ["bo", "disponible"]:
		var who2 := ""
		if st == "bo":
			var f2 := _sched_find(acd, "bo")
			if not f2.is_empty():
				who2 = str(f2[0])
				GameState.clock_seconds = float(f2[1])
				EventBus.clock_tick.emit(GameState.clock_seconds)
		else:
			GameState.clock_seconds = _hms(0, 20)
			EventBus.clock_tick.emit(GameState.clock_seconds)
			var libres2 := acd.available_npcs()
			who2 = libres2[0] if not libres2.is_empty() else ""
		if who2 == "":
			t.note("nadie en «%s» ahora" % st)
			continue
		Comodin.reset()
		IABrain.forget_all()
		await t.frames(2)
		t.check(str(Comodin.presence_of(who2).get("estado", "")) == "activo", "%s (%s): «activo» en el panel" % [st, who2])
		var answered: Array = []
		var cb := func(w: String, a: int) -> void: answered.append([w, a])
		Comodin.call_answered.connect(cb)
		Comodin.open()
		Comodin.choose_aux(Metrics.Aux.BANO)
		var ph2: String = await _comodin_call(t, who2)
		Comodin.call_answered.disconnect(cb)
		t.check(ph2 == "" and answered.size() == 1 and Metrics.aux == Metrics.Aux.BANO and Comodin.used, "%s: %s contesta y te marca Baño en tu PC (fase «%s», AUX %s)" % [st, who2, ph2, Metrics.aux_name()])
		t.check(not Comodin.open(), "%s: ya gastado, no se abre otra vez" % st)
	# (b) Todos en un contacto: el panel avisa antes de gastar; llamarlos a todos pierde el comodín.
	Comodin.reset()
	IABrain.forget_all()
	# Una media hora del horario real en la que los cuatro están en su sitio (sin break, lunch, BO…): la hora punta.
	var punta := -1.0
	var m := 10.0 * 60.0
	while m < 7.5 * 3600.0 and punta < 0.0:
		var libres3 := true
		for n in acd.coworkers():
			for k in 7:
				if acd.npc_state(n, m + k * 300.0) != "disponible":
					libres3 = false
		if libres3:
			punta = m
		m += 300.0
	t.check(punta > 0.0, "hay una media hora en que los cuatro están en su sitio (%s)" % (GameState.clock_text_at(punta) if punta > 0.0 else "—"))
	GameState.clock_seconds = maxf(punta, 600.0)
	EventBus.clock_tick.emit(GameState.clock_seconds)
	for n in acd.coworkers():
		acd.npc_busy_until[n] = GameState.clock_seconds + 3600.0  # a todos les entró un contacto
	await t.frames(2)
	var lost: Array = []
	var cb2 := func(w: String, why: String) -> void: lost.append([w, why])
	Comodin.call_failed.connect(cb2)
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await _vd_wait(t, 0.7)
	var all_busy := true
	for n in acd.coworkers():
		if str(Comodin.presence_of(n).get("estado", "")) == "activo":
			all_busy = false
	t.check(all_busy and not Comodin.anyone_active() and Comodin.ui_text().contains(tr_.call("B2_COMODIN_NOBODY")) and not Comodin.used, "con los cuatro ocupados el panel avisa ANTES de gastar el comodín")
	var names := Comodin.coworkers()
	for i in names.size():
		var ph3: String = await _comodin_call(t, names[i])
		if i < names.size() - 1:
			t.check(ph3 == "retry" and Comodin.ui_text().contains(tr_.call("B2_COMODIN_NOBODY_RETRY")), "llamas a %s: no contesta, te queda el reintento y el panel sigue avisando" % names[i])
	t.check(Comodin.phase == "" and Comodin.used and lost.size() == names.size() + 1 and str(lost[lost.size() - 1][1]) == "nadie", "nadie contestó: el comodín se pierde (%d llamadas fallidas + «nadie»)" % (lost.size() - 1))
	t.check(not Comodin.open(), "y no se puede volver a abrir en el turno")
	await t.frames(3)
	var hud := t.main.get("hud") as Control
	t.check((hud.get("_disc") as Label).text.contains(tr_.call("B2_COMODIN_HUD_USED")), "el HUD lo dice («%s»)" % tr_.call("B2_COMODIN_HUD_USED"))
	# … y dejar pasar el reintento sin llamar a otro también lo pierde.
	Comodin.reset()
	lost.clear()
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await _comodin_call(t, names[0])
	t.check(Comodin.phase == "retry" and Comodin.retry_left > 0.0, "tras el primer «no contesta» corre el reintento (%.0f s reales)" % Comodin.retry_left)
	await t.until(func() -> bool: return Comodin.phase == "", 60.0)
	t.check(Comodin.phase == "" and Comodin.used and lost.size() == 2 and str(lost[1][1]) == "nadie", "si no llamas a otro a tiempo, se pierde")
	Comodin.call_failed.disconnect(cb2)
	for n in acd.coworkers():
		acd.npc_busy_until.erase(n)
	# (c) La práctica del Training: tu promoción al teléfono (lo mismo que hace tutorial.gd), sin gastar el del turno.
	Comodin.reset()
	var hub := EzlakHub.get_hub(t.get_tree())
	# Antes, lo que dejaron las dos llamadas contestadas de arriba: Shero vio que tu PC cambió sin ti y te escribe.
	var shero_dm := func() -> int:
		var k := 0
		for msg in hub.messages("dm:shero"):
			if str((msg as Dictionary).get("tipo", "")) == "comodin":
				k += 1
		return k
	await t.until(func() -> bool: return int(shero_dm.call()) >= 2, 12.0)
	t.check(int(shero_dm.call()) == 2 and int(SaveSlots.progress().get("comodin_usos", 0)) >= 2, "Shero te escribió por cada comodín que te contestaron (%d DM)" % int(shero_dm.call()))
	var usos0 := int(SaveSlots.progress().get("comodin_usos", 0))
	var dm0 := int(shero_dm.call())
	var clase: Array[String] = ["Nayra", "Yimi", "Brando", "Keyla"]
	Comodin.practice_names = clase
	Comodin.answer_override = func(_n: String) -> bool: return true
	Comodin.reset()
	t.check(Comodin.coworkers() == clase and str(Comodin.presence_of("Nayra").get("estado", "")) == "activo" and Comodin.anyone_active(), "práctica: los nombres son los de tu promoción y todos salen «activo»")
	Comodin.open()
	Comodin.choose_aux(Metrics.Aux.BREAK)
	var ph4: String = await _comodin_call(t, "Nayra")
	t.check(ph4 == "" and Metrics.aux == Metrics.Aux.BREAK, "práctica: Nayra contesta y marca Break (fase «%s», AUX %s)" % [ph4, Metrics.aux_name()])
	Comodin.practice_names = []
	Comodin.answer_override = Callable()
	Comodin.reset()
	await _vd_wait(t, 1.0)
	t.check(not Comodin.used and not bool(GameState.flags.get(Comodin.FLAG_USED, false)) and Comodin.coworkers().has("Jiroshi"), "al terminar la práctica el comodín del turno está sin gastar y los compañeros vuelven a ser los del piso")
	await _vd_wait(t, 1.0)
	t.check(int(SaveSlots.progress().get("comodin_usos", 0)) == usos0 and int(shero_dm.call()) == dm0, "la práctica no cuenta para la partida ni le llega a Shero (usos %d → %d, DM de Shero por el comodín %d → %d)" % [usos0, int(SaveSlots.progress().get("comodin_usos", 0)), dm0, int(shero_dm.call())])
	# (a, final) En Training.
	if await _comodin_no_contesta(t, acd, "training"):
		seen.append("training")
	t.check(seen.size() >= 5, "estados que no contestan vistos por el camino real: %s" % str(seen))
	t.check(deaths.is_empty(), "nada mató al jugador mientras usaba el comodín (%s)" % str(deaths))
	IABrain.presence_override = {}
	GameState.stop_calm()
	await t.back_to_menu()


## Un estado del ACD que no contesta, por el camino real: lo dice el panel, la llamada falla y el aviso dice por qué.
## false si en este turno nadie pasa por ese estado.
func _comodin_no_contesta(t: Node, acd: ColaACD, st: String) -> bool:
	var keys := {"lunch": "B2_COMODIN_LUNCH", "break": "B2_COMODIN_BREAK", "training": "B2_COMODIN_TRAINING", "coaching": "B2_COMODIN_COACHING", "dormido": "B2_COMODIN_ASLEEP", "contacto": "B2_COMODIN_BUSY"}
	var pres_map: Dictionary = (IABrain.cfg().get("presencia", {}) as Dictionary).get("acd", {})
	var who := ""
	if st == "contacto":
		var libres := acd.available_npcs()
		if not libres.is_empty():
			who = libres[0]
			acd.npc_busy_until[who] = GameState.clock_seconds + 600.0  # como cuando el ACD le asigna un contacto
	else:
		var f := _sched_find(acd, st)
		if f.is_empty():
			t.note("en este turno nadie tiene «%s» en su horario" % st)
			return false
		who = str(f[0])
		GameState.clock_seconds = float(f[1])
		EventBus.clock_tick.emit(GameState.clock_seconds)
	if who == "":
		return false
	Comodin.reset()
	await t.frames(2)
	var want := str(pres_map.get(st, "activo"))
	var pr := Comodin.presence_of(who)
	t.check(acd.npc_state(who) == st and str(pr.get("estado", "")) == want, "%s (%s, %s) sale en el panel como «%s» (sale «%s»)" % [st, who, GameState.clock_text(), want, str(pr.get("estado", ""))])
	t.check(Comodin.open(), "%s: el comodín se abre" % st)
	Comodin.choose_aux(Metrics.Aux.AVAILABLE)
	await t.frames(2)
	var txt := Comodin.ui_text()
	t.check(txt.contains(who) and txt.contains(str(pr.get("texto", "?"))), "%s: el panel lo dice al lado de su nombre" % st)
	var aux0 := Metrics.aux
	var ph: String = await _comodin_call(t, who)
	var say := Loc.fmt(TranslationServer.translate(str(keys[st])), {"quien": who})
	t.check(ph == "retry" and str(Comodin.last_fail.get("clave", "")) == str(keys[st]) and _notice_seen(say), "%s: no contesta y el aviso dice por qué («%s»; fase %s, clave %s)" % [st, say, ph, str(Comodin.last_fail.get("clave", ""))])
	t.check(Metrics.aux == aux0 and Comodin.used, "%s: nadie te marcó nada y el comodín queda en reintento" % st)
	Comodin.cancel()
	if st == "contacto":
		acd.npc_busy_until.erase(who)
	return true


func _notice_seen(text: String) -> bool:
	if str(VoiceDirector.notice_current.get("text", "")) == text:
		return true
	for n in VoiceDirector.notices:
		if str((n as Dictionary).get("text", "")) == text:
			return true
	for row in VoiceDirector.notice_log:
		if str(row[2]) == text:
			return true
	return false


# ----------------------------------------------------------------------------------------------------------------
# Morir por Available bajo (auditoría de bucles, variante «available» en el T3).


func _lists(log: Array) -> int:
	var n := 0
	for e in log:
		if str((e as Array)[1]) == "mentor" and str(((e as Array)[3] as Dictionary).get("tipo", "")) == "allocations":
			n += 1
	return n


func _set_avl(av_s: float, bo_s: float) -> void:
	Metrics.time_in_aux[Metrics.Aux.AVAILABLE] = av_s
	Metrics.time_in_aux[Metrics.Aux.BO] = bo_s


func _available_respawn(t: Node) -> void:
	# En el T1 (sin training que se cruce): el caso salió en el T3, pero la regla es la misma en todos los turnos.
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(mentor != null, "hay Mentor en el turno")
	if mentor == null:
		return
	var posts: Array = t.spy("ezlak_post")
	var steps: Array = t.spy("discipline_step")
	var hunts: Array = t.spy("pursuit_started")
	var h := func(hh: int, mm: int, ss: int = 0) -> float: return float(hh * 3600 + mm * 60 + ss)
	# 01:30 y 03:00: dos listas con el Available por los suelos (casi todo el turno en BO, más de 30 min productivos).
	# (Cada salto de reloj suma su tramo al AUX actual, Available: por eso el BO de partida es enorme.)
	_set_avl(600.0, 90000.0)
	await t.set_clock(h.call(1, 30, 5))
	await t.frames(2)
	t.check(_lists(posts) == 1 and int(Discipline.counters.get("listas_bajo", 0)) == 1, "lista de la 01:30 con Available %d %%: primera lista mala (%d listas, cuenta %d)" % [int(Metrics.available_pct()), _lists(posts), int(Discipline.counters.get("listas_bajo", 0))])
	await t.set_clock(h.call(3, 0, 5))
	await t.frames(2)
	t.check(_lists(posts) == 2 and int(Discipline.counters.get("listas_bajo", 0)) == 2, "lista de las 03:00: segunda lista mala")
	t.check(Discipline.step_of("available") == Discipline.Step.WW, "con dos listas malas, Shero va por el WW (escalón %d)" % Discipline.step_of("available"))
	# El checkpoint cae en el minuto siguiente a la lista (en el T3 el KYC de las 03:00 abre con ella).
	GameState.clock_seconds = h.call(3, 0, 25)  # sin esperar un cuadro: el checkpoint tiene que caer dentro de ese minuto
	Checkpoints.save_checkpoint("login")
	var cp_clock := float((Checkpoints.last_checkpoint.get("game_state", {}) as Dictionary).get("clock_seconds", 0.0))
	t.check(cp_clock >= h.call(3, 0, 0) and cp_clock < h.call(3, 1, 0), "checkpoint dentro del minuto siguiente a la lista de las 03:00 (%d s después)" % int(cp_clock - h.call(3, 0, 0)))
	t.check(int((Checkpoints.last_checkpoint.get("game_state", {}) as Dictionary).get("flags", {}).get(Mentor.FLAG_LISTS, -1)) == 2, "el checkpoint sabe que ya salieron dos listas")
	# 04:30: tercera lista mala → persecución → muerte por Available bajo.
	await t.set_clock(h.call(4, 30, 5))
	await t.frames(2)
	t.check(Discipline.step_of("available") >= Discipline.Step.PERSECUCION and hunts.size() == 1, "tercera lista mala: persecución de Shero (escalón %d, %d persecuciones)" % [Discipline.step_of("available"), hunts.size()])
	await t.die("available_bajo", "10", "shero")
	t.check(await t.wait_death_shown(12.0), "muerte por Available bajo: pantalla «Usuario desconectado»")
	var lists0 := _lists(posts)
	var hunts0 := hunts.size()
	steps.clear()
	var notice0 := VoiceDirector.notice_log.size()
	await t.reconnect()
	# 1. Al reaparecer (03:00:25, en «Reconectando») la lista de las 03:00 NO se repite ni Shero sale a perseguirte.
	t.check(Metrics.reconnecting and GameState.seated_at == "C-14", "reapareces sentado en C-14 en «Reconectando»")
	t.check(GameState.clock_seconds >= h.call(3, 0, 25) and GameState.clock_seconds < h.call(3, 15), "el reloj volvió al checkpoint de las 03:00 (%s)" % GameState.clock_text())
	await _vd_wait(t, 0.6)
	t.check(_lists(posts) == lists0, "la lista de las 03:00, que ya había salido antes del checkpoint, no se vuelve a publicar (%d → %d)" % [lists0, _lists(posts)])
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == 2, "la cuenta de listas malas es la del checkpoint (2), no una más (%d)" % int(Discipline.counters.get("listas_bajo", 0)))
	t.check(hunts.size() == hunts0 and Discipline.step_of("available") < Discipline.Step.PERSECUCION, "nadie te persigue al reaparecer")
	t.check(int(mentor.get("_list_next")) == 2, "la siguiente lista del Mentor es la de las 04:30")
	# 2. El Available se cuenta de nuevo (y el checkpoint vivo queda corregido), con su aviso.
	t.check(Metrics.productive_seconds() < 900.0 and not Metrics.available_evaluable(), "tras morir por Available bajo el porcentaje se cuenta de nuevo (productivo %d s, %d %%)" % [int(Metrics.productive_seconds()), int(Metrics.available_pct())])
	var cpt: Dictionary = (Checkpoints.last_checkpoint.get("metrics", {}) as Dictionary).get("time_in_aux", {})
	var cp_sum := 0.0
	for k in cpt.keys():
		if int(k) == Metrics.Aux.AVAILABLE or int(k) == Metrics.Aux.BO:
			cp_sum += float(cpt[k])
	t.check(cp_sum == 0.0, "el checkpoint vivo también (otro respawn desde él no trae el porcentaje viejo)")
	var said := false
	for i in range(notice0, VoiceDirector.notice_log.size()):
		if str(VoiceDirector.notice_log[i]).contains(tr("B2_RECON_AVL")):
			said = true
	t.check(said or _notice_seen(tr("B2_RECON_AVL")), "aviso: «tu Available % se cuenta de nuevo desde ahora»")
	t.check(not GameState.flags.has("available_reinicio"), "el aviso se da una sola vez")
	# 3. Una lista que sale en Reconectando / gracia / calma: Shero no la lee.
	_set_avl(60.0, 3000.0)
	var n0 := int(Discipline.counters.get("listas_bajo", 0))
	mentor.post_list_now()
	await t.frames(2)
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == n0 and hunts.size() == hunts0, "una lista mala en «Reconectando» no cuenta ni dispara nada (reconectando=%s, gracia=%s, calma=%s)" % [Metrics.reconnecting, Checkpoints.in_respawn_grace(), GameState.in_calm])
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	mentor.post_list_now()
	await t.frames(2)
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == n0 and hunts.size() == hunts0, "tampoco en la gracia/calma del respawn (gracia=%s, calma=%s)" % [Checkpoints.in_respawn_grace(), GameState.in_calm])
	# 4. Quien se porta bien después no vuelve a morir: Available todo el rato hasta la lista de las 04:30.
	_set_avl(0.0, 0.0)
	GameState.stop_calm()
	await t.until(func() -> bool: return not Checkpoints.in_respawn_grace(), 90.0)
	t.check(not Checkpoints.in_respawn_grace() and not GameState.in_calm, "pasó la gracia del respawn")
	_set_avl(4800.0, 300.0)  # 85 min: casi todo en Available desde que reapareció
	lists0 = _lists(posts)
	await t.set_clock(h.call(4, 30, 5))
	await t.frames(3)
	t.check(_lists(posts) == lists0 + 1, "la lista de las 04:30 sale a su hora")
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == n0 and hunts.size() == hunts0 and not Checkpoints.dying, "con Available 94 %% desde el respawn esa lista ya no te mata (antes: 10 %% acumulado → otra persecución) [cuenta %d→%d, persecuciones %d→%d, %d %%, evaluable=%s]" % [n0, int(Discipline.counters.get("listas_bajo", 0)), hunts0, hunts.size(), int(Metrics.available_pct()), Metrics.available_evaluable()])
	# … y quien sigue igual, sí: la cuenta de listas malas no se borra en el turno.
	_set_avl(300.0, 90000.0)
	# A 1x mientras llega Shero: a 8x sus 3 s de «te mira antes de correr» son 0,4 s reales y, con la máquina cargada,
	# un par de cuadros lentos bastaban para que te alcanzara antes de que la prueba parase la persecución (la muerte
	# devolvía todo al checkpoint y fallaban las comprobaciones de «Continuar» de más abajo).
	var scale8 := Engine.time_scale
	Engine.time_scale = 1.0
	await t.set_clock(h.call(6, 0, 5))
	for i in 60:
		if hunts.size() > hunts0:
			break
		await t.frames(1)
	Discipline.call("_stop_pursuits", "prueba")
	Engine.time_scale = scale8
	t.check(int(Discipline.counters.get("listas_bajo", 0)) == n0 + 1 and hunts.size() == hunts0 + 1, "si sigues en BO, la lista de las 06:00 vuelve a traer a Shero (la cuenta no se borra) [cuenta %d→%d, persecuciones %d→%d, escalón %d]" % [n0, int(Discipline.counters.get("listas_bajo", 0)), hunts0, hunts.size(), Discipline.step_of("available")])
	Discipline.call("_stop_pursuits", "prueba")
	# 5. «Continuar» desde el menú con ese checkpoint: tampoco repite la lista que ya había salido.
	GameState.clock_seconds = h.call(6, 0, 30)
	_set_avl(300.0, 90000.0)
	Checkpoints.save_checkpoint("login")
	var bad_at_cp := int(Discipline.counters.get("listas_bajo", 0))
	await t.back_to_menu()
	SaveSlots.select("Marko")
	posts.clear()
	hunts.clear()
	t.main.call("_continue_shift")
	await t.frames(6)
	t.check(GameState.running and GameState.turno == 1 and absf(GameState.clock_seconds - h.call(6, 0, 30)) < 600.0, "Continuar retoma el turno en el checkpoint (%s; con la máquina cargada el reloj corre unos minutos de juego mientras se arma el piso)" % GameState.clock_text())
	await _vd_wait(t, 0.8)
	t.check(_lists(posts) == 0 and int(Discipline.counters.get("listas_bajo", 0)) == bad_at_cp and hunts.is_empty(), "al Continuar la lista de las 06:00 no se repite ni Shero la cuenta otra vez (%d listas, cuenta %d → %d)" % [_lists(posts), bad_at_cp, int(Discipline.counters.get("listas_bajo", 0))])
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# Estado que sobrevive a un respawn y a «Continuar».


func _hms(hh: int, mm: int, ss: int = 0) -> float:
	return float(hh * 3600 + mm * 60 + ss)


func _respawn_estado(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(mentor != null and Metrics.incidents == 0, "turno limpio: 0 incidencias")
	# --- A. Incidencias y comodín al reaparecer ---
	await t.set_clock(_hms(0, 40))
	Checkpoints.save_checkpoint("login")
	Comodin.used = true  # gastado DESPUÉS del checkpoint
	await t.die("abandono", "", "shero")
	t.check(await t.wait_death_shown(12.0) and Metrics.incidents == 1, "primera muerte: incidencia registrada (%d)" % Metrics.incidents)
	await t.reconnect()
	t.check(Metrics.incidents == 1, "al reaparecer la incidencia sigue contada (antes volvía a 0 con el checkpoint): %d" % Metrics.incidents)
	t.check(int((Checkpoints.last_checkpoint.get("metrics", {}) as Dictionary).get("incidents", -1)) == 1, "y queda apuntada en el checkpoint vivo")
	t.check(not Comodin.used and Comodin.tried.is_empty(), "el comodín gastado después del checkpoint vuelve con él (el turno rebobina entero)")
	GameState.stop_calm()
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	await t.die("abandono", "", "shero")
	t.check(await t.wait_death_shown(12.0), "segunda muerte desde el mismo checkpoint")
	await t.reconnect()
	t.check(Metrics.incidents == 2, "dos muertes = dos incidencias (%d)" % Metrics.incidents)
	GameState.stop_calm()
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	# --- B. Lo que tiene que sobrevivir a «Continuar» ---
	var first: Dictionary = cm.next_scripted()
	var first_id := str(first.get("id", ""))
	t.check(first_id != "", "hay un primer guion del turno (%s)" % first_id)
	(cm.get("_served") as Array).append(first_id)
	Metrics.contacts_handled = 1
	Comodin.used = true
	await t.set_clock(_hms(0, 26))  # el reloj ya pasó de las 00:20: primer minitraining anunciado
	await t.frames(2)
	var mt_open: Array = mentor.minitrainings_open.duplicate()
	t.check(mt_open.size() >= 1, "minitraining anunciado (%s)" % str(mt_open))
	mentor.complete_minitraining(str(mt_open[0]))
	t.check(mentor.minitrainings_pending() == mt_open.size() - 1, "minitraining hecho")
	await t.set_clock(_hms(2, 0))
	await t.frames(2)
	mentor.post_allocation_now()
	Metrics.set_aux(Metrics.Aux.BO)
	var until := float(mentor.until_clock)
	t.check(mentor.active and Metrics.allocation_aux == Metrics.Aux.BO and until > _hms(2, 10), "allocation a BO en curso hasta las %s" % GameState.clock_text_at(until))
	GameState.clock_seconds = _hms(2, 5)
	Checkpoints.save_checkpoint("contacto", cm.call("_cp_extra"))
	t.check(str(Checkpoints.last_checkpoint.get("kind", "")) == "contacto", "checkpoint guardado en plena allocation, a las 02:05")
	await t.back_to_menu()
	SaveSlots.select("Marko")
	t.main.call("_continue_shift")
	await t.frames(6)
	t.check(GameState.running and GameState.turno == 1 and GameState.clock_seconds >= _hms(2, 5) and GameState.clock_seconds < _hms(2, 15), "Continuar retoma el turno a las 02:05 (%s)" % GameState.clock_text())
	var cm2 := _cm(t)
	var mentor2 := t.get_tree().get_first_node_in_group("mentor") as Mentor
	t.check(cm2 != cm and mentor2 != mentor and mentor2 != null, "el mundo se armó de nuevo (otro ContactManager, otro Mentor)")
	cm2.process_mode = Node.PROCESS_MODE_DISABLED
	t.check((cm2.get("_served") as Array).has(first_id) and str(cm2.next_scripted().get("id", "")) != first_id, "el guion ya atendido (%s) no vuelve a llamar; el siguiente es %s" % [first_id, str(cm2.next_scripted().get("id", ""))])
	t.check(Comodin.used and not Comodin.can_use(), "el comodín gastado sigue gastado (antes: salir y Continuar lo devolvía)")
	t.check(mentor2.minitrainings_done.has(str(mt_open[0])) and mentor2.minitrainings_pending() == mt_open.size() - 1, "el minitraining hecho sigue hecho (pendientes %d)" % mentor2.minitrainings_pending())
	t.check(Metrics.incidents == 2, "las incidencias del turno siguen ahí (%d)" % Metrics.incidents)
	t.check(mentor2.active and Metrics.allocation_aux == Metrics.Aux.BO and is_equal_approx(float(mentor2.until_clock), until), "la allocation a BO sigue en curso hasta su hora (%s)" % GameState.clock_text_at(float(mentor2.until_clock)))
	t.check(int(mentor2.get("_list_next")) == 1, "y la lista de la 01:30 no se repite (siguiente: la de las 03:00)")
	var ended: Array = t.spy("allocation_ended")
	await t.set_clock(until + 30.0)
	await t.frames(3)
	t.check(ended.size() == 1 and not mentor2.active and Metrics.allocation_aux == -1 and Metrics.expected_aux == Metrics.Aux.AVAILABLE, "y termina a su hora: el RTA vuelve a pedir Available (antes: BO para siempre) [fin=%d, activa=%s, orden=%s]" % [ended.size(), mentor2.active, Metrics.aux_name(Metrics.expected_aux)])
	# El aviso de las 08:00 por minitrainings pendientes sale una vez, no otra vez al Continuar.
	var posts: Array = t.spy("ezlak_post")
	await t.set_clock(_hms(8, 0, 30))
	await t.frames(3)
	var warned := 0
	for e in posts:
		if str(((e as Array)[3] as Dictionary).get("tipo", "")) == "minitraining_pendiente" and str((e as Array)[1]) == "mentor":
			warned += 1
	t.check(warned == 1 and bool(GameState.flags.get(Mentor.FLAG_MT_WARNED, false)), "aviso de minitrainings pendientes a las 08:00 (%d)" % warned)
	Checkpoints.save_checkpoint("contacto", cm2.call("_cp_extra"))
	await t.back_to_menu()
	SaveSlots.select("Marko")
	posts.clear()
	t.main.call("_continue_shift")
	await t.frames(6)
	await t.set_clock(_hms(8, 2))
	await t.frames(3)
	warned = 0
	for e in posts:
		if str(((e as Array)[3] as Dictionary).get("tipo", "")) == "minitraining_pendiente":
			warned += 1
	t.check(warned == 0, "al Continuar después de las 08:00 el aviso no se repite (%d)" % warned)
	await t.back_to_menu()


func _allocation_respawn(t: Node) -> void:
	await t.start_shift("Marko", 3)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
	Checkpoints.set("_grace_left", 0.0)
	mentor.post_allocation_now()
	Metrics.set_aux(Metrics.Aux.BO)
	await t.frames(2)
	var until := mentor.until_clock
	Checkpoints.save_checkpoint("login")
	t.check(mentor.active and until > GameState.clock_seconds + 60.0, "checkpoint guardado en plena allocation a BO (hasta %s)" % GameState.clock_text_at(until))
	# La allocation termina a su hora y DESPUÉS el jugador muere (pasa también si la secuencia de muerte se alarga).
	await t.set_clock(until + 30.0)
	await t.frames(3)
	t.check(not mentor.active and Metrics.allocation_aux < 0, "la allocation terminó a su hora, antes de la muerte")
	await t.die("abandono", "", "shero")
	await t.wait_death_shown(15.0)
	await t.reconnect()
	await t.frames(3)
	t.check(GameState.clock_seconds < until, "al reaparecer el reloj vuelve a la hora del checkpoint, dentro de la allocation (%s)" % GameState.clock_text())
	t.check(mentor.active and is_equal_approx(mentor.until_clock, until) and Metrics.allocation_aux == Metrics.Aux.BO, "la allocation del checkpoint vuelve a estar en curso, con su misma hora de fin (activa %s, allocation %d)" % [str(mentor.active), Metrics.allocation_aux])
	t.check(Metrics.expected_aux == Metrics.Aux.BO, "y el RTA sigue pidiendo BO (pide %s)" % Metrics.aux_name(Metrics.expected_aux))
	var ended: Array = t.spy("allocation_ended")
	GameState.stop_calm()
	await t.set_clock(until + 5.0)
	await t.frames(3)
	t.check(ended.size() == 1 and not mentor.active and Metrics.allocation_aux < 0 and Metrics.expected_aux != Metrics.Aux.BO, "se cierra a su hora una sola vez y el RTA vuelve a pedir %s" % Metrics.aux_name(Metrics.expected_aux))
	await t.back_to_menu()


func _count_msgs(hub: EzlakHub, ch: String, text: String) -> int:
	var n := 0
	for m in hub.messages(ch):
		if str((m as Dictionary).get("texto", "")) == text:
			n += 1
	return n


func _ezlaki_respawn(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var hub := t.get_tree().get_first_node_in_group("ezlak_hub") as EzlakHub
	t.check(hub != null, "hay Ezlaki")
	if hub == null:
		return
	# pasada 8 (jugando con Marko): el RTA publicaba «@Marko perdiste un contacto» a las 4:50 aunque no perdieras nada
	t.check(hub.about_player({"linea": "rta_npc_marko", "captura": {"quien": "marko"}}) and hub.about_player({"linea": "shero_correos_excedidos", "captura": {"quien": "llauri,marko"}}),
		"un aviso programado sobre «un compañero» que eres tú (Marko) se reconoce")
	t.check(not hub.about_player({"linea": "rta_npc_ttoom", "captura": {"quien": "ttoom"}}) and not hub.about_player({"linea": "shero_madrugada", "captura": {"quien": "jugador"}}) and not hub.about_player({"linea": "rta_todos_available"}),
		"y los de los demás compañeros (o los que hablan de ti por lo que hiciste) siguen saliendo")
	await t.set_clock(_hms(2, 0))
	await t.seconds(4.0)  # lo programado hasta las 02:00 termina de «escribirse»
	GameState.clock_seconds = _hms(2, 1)  # (el reloj corre mientras se espera: se fija antes de cada paso que importa)
	EventBus.ezlak_post.emit("#team-familia", "mentor", "Mensaje A (antes del checkpoint)", {})
	await t.frames(2)
	var a_t := -1.0
	for m in hub.messages("#team-familia"):
		if str((m as Dictionary).get("texto", "")) == "Mensaje A (antes del checkpoint)":
			a_t = float((m as Dictionary).get("t", -1.0))
	t.check(a_t >= _hms(2, 0) and a_t < _hms(2, 5), "el mensaje A está en el chat con su hora (%s)" % GameState.clock_text_at(a_t))
	hub.mark_read("#team-familia")
	hub.mark_read("dm:shero")
	GameState.clock_seconds = _hms(2, 5)
	Checkpoints.save_checkpoint("login")
	# Después del checkpoint: lo programado de las 02:20, un DM de Shero, un aviso que pide reacción, algo tuyo y
	# alguien escribiendo cuando mueres.
	await t.set_clock(_hms(2, 30))
	await t.seconds(4.0)
	var prog_n := 0
	for m in hub.messages("#team-familia"):
		if str((m as Dictionary).get("tipo", "")) == "programado" and float((m as Dictionary).get("t", 0.0)) > _hms(2, 5) and float((m as Dictionary).get("t", 0.0)) < _hms(2, 35):
			prog_n += 1
	t.check(prog_n == 1, "entre las 02:05 y las 02:30 salió 1 mensaje programado en #team-familia (%d)" % prog_n)
	EventBus.ezlak_post.emit("dm:shero", "shero", "Mensaje B (después del checkpoint)", {"mention": true})
	EventBus.ezlak_post.emit("#team-familia", "shero", "Aviso C: coaching a las 7:30. Reaccionen.", {"pide_reaccion": true, "mention": true})
	await t.frames(2)
	hub.typed_reply("dm:shero", "ok, entendido")
	await t.frames(2)
	t.check(_count_msgs(hub, "dm:shero", "Mensaje B (después del checkpoint)") == 1 and not hub.reaction_pending.is_empty(), "antes de morir: el DM de Shero está y el aviso espera tu reacción")
	var mine := 0
	for m in hub.messages("dm:shero"):
		if str((m as Dictionary).get("autor", "")) == "yo":
			mine += 1
	t.check(mine >= 1, "y lo que escribiste también (%d)" % mine)
	EventBus.ezlak_post.emit("#team-familia", "rasec", "Mensaje D (lo estaban escribiendo cuando moriste)", {"typing_s": 3.0})
	await t.frames(1)
	await t.die("abandono", "", "shero")
	t.check(await t.wait_death_shown(12.0), "muerte")
	await t.reconnect()
	t.check(GameState.clock_seconds >= _hms(2, 5) and GameState.clock_seconds < _hms(2, 18), "reapareces a las 02:05 (%s)" % GameState.clock_text())
	# El chat volvió al checkpoint.
	t.check(_count_msgs(hub, "#team-familia", "Mensaje A (antes del checkpoint)") == 1, "lo anterior al checkpoint sigue en el chat (%d mensajes en el canal)" % hub.messages("#team-familia").size())
	t.check(_count_msgs(hub, "dm:shero", "Mensaje B (después del checkpoint)") == 0, "el DM posterior al checkpoint ya no está")
	t.check(_count_msgs(hub, "#team-familia", "Aviso C: coaching a las 7:30. Reaccionen.") == 0 and hub.reaction_pending.is_empty() and hub.reaction_left() == 0.0, "el aviso que pedía reacción se fue y su cuenta atrás también")
	mine = 0
	for m in hub.messages("dm:shero"):
		if str((m as Dictionary).get("autor", "")) == "yo":
			mine += 1
	t.check(mine == 0, "lo que escribiste después del checkpoint tampoco (%d)" % mine)
	var future := 0
	for ch in hub.channels.keys():
		for m in hub.messages(str(ch)):
			if float((m as Dictionary).get("t", 0.0)) > GameState.clock_seconds + 1.0:
				future += 1
	t.check(future == 0, "ningún mensaje «del futuro» en ningún canal (%d)" % future)
	t.check(int((hub.channels["dm:shero"] as Dictionary).get("unread", 0)) == 0 and not bool((hub.channels["dm:shero"] as Dictionary).get("mention", false)), "sin no leídos fantasma en el DM de Shero")
	await t.seconds(5.0)
	t.check(_count_msgs(hub, "#team-familia", "Mensaje D (lo estaban escribiendo cuando moriste)") == 0, "lo que alguien estaba escribiendo al morir no llega después")
	# Al volver a pasar por las 02:20 lo programado sale UNA vez (antes quedaban dos copias).
	GameState.stop_calm()
	await t.set_clock(_hms(2, 30))
	await t.seconds(4.0)
	prog_n = 0
	for m in hub.messages("#team-familia"):
		if str((m as Dictionary).get("tipo", "")) == "programado" and float((m as Dictionary).get("t", 0.0)) > _hms(2, 5) and float((m as Dictionary).get("t", 0.0)) < _hms(2, 35):
			prog_n += 1
	t.check(prog_n == 1, "lo programado de las 02:20 sale otra vez al volver a pasar su hora, una sola copia en el chat (%d)" % prog_n)
	# Un aviso que pedía reacción ANTES del checkpoint sigue esperando después de reaparecer.
	GameState.clock_seconds = _hms(2, 36)
	EventBus.ezlak_post.emit("#team-familia", "shero", "Aviso E: reaccionen.", {"pide_reaccion": true, "mention": true})
	await t.frames(2)
	GameState.clock_seconds = _hms(2, 39)
	Checkpoints.save_checkpoint("login")
	await t.set_clock(_hms(2, 50))
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	await t.die("abandono", "", "shero")
	t.check(await t.wait_death_shown(12.0), "segunda muerte")
	await t.reconnect()
	t.check(_count_msgs(hub, "#team-familia", "Aviso E: reaccionen.") == 1 and not hub.reaction_pending.is_empty(), "un aviso anterior al checkpoint sigue en el chat y sigue pidiendo tu reacción")
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# Inglés: lo escrito se entiende; la voz avisa que es solo en español.


const EN_GENERIC := {
	"empatia": ["I understand your concern, I'll help you right now", "You're absolutely right, I apologize", "I understand, don't worry, I'll take care of it",
		"I'm so sorry, let's review it together", "I understand, that must be hard, I'm going to help you"],
	"proceso": ["Can you confirm the transaction number please", "Let me check in the system", "I'm going to verify with the partner",
		"Could you give me your ID so I can validate it", "I'll review your case in Kardex"],
	"cierre": ["It has been registered, is there anything else I can help you with?", "I'll send you the tracking number, have a good night",
		"Your transfer is being processed and it will be credited in 24 hours", "All set, it's solved now"],
}


func _ingles(t: Node) -> void:
	await t.back_to_menu()
	var pct := func(r: Dictionary) -> float: return 100.0 * float(r["ok"]) / maxf(1.0, float(r["n"]))
	# 1. Intenciones: el español no empeora y el inglés escrito se entiende.
	for f in ["test_intents", "test_intents_holdout", "test_intents_ciego"]:
		var r: Dictionary = IAEval.run(f)
		t.check(int(r["ok"]) == int(r["n"]), "español, %s: %d/%d (el léxico inglés no rompe nada)" % [f, r["ok"], r["n"]])
	var en: Dictionary = IAEval.run("test_intents_en")
	var en2: Dictionary = IAEval.run("test_intents_en_ciego")
	t.check(int(en["n"]) >= 120 and float(pct.call(en)) >= 95.0, "inglés, test_intents_en: %.1f %% (%d/%d; sin el léxico: 45,5 %%)" % [float(pct.call(en)), en["ok"], en["n"]])
	t.check(int(en2["n"]) >= 80 and float(pct.call(en2)) >= 90.0, "inglés, conjunto ciego: %.1f %% (%d/%d)" % [float(pct.call(en2)), en2["ok"], en2["n"]])
	for f in en2["fallos"]:
		t.note("  ciego ✗ " + str(f))
	# 2. Respuestas al cliente escritas en inglés: el mejor camino de todos los árboles con el texto inglés de cada
	#    opción reescrito a mano (palabras de menos, minúsculas, una falta) y con frases genéricas en inglés.
	var pia: GDScript = load("res://scripts/dev/escenarios/pia_conversacion.gd")
	var trees: Array = pia.call("all_trees")
	var steps := 0
	var exact := 0
	var resolved := 0
	var g_steps := 0
	var g_good := 0
	var g_same := 0
	var no_en := 0
	for c in trees:
		IACustomer.prepare(c)
		var path: Array = DialogTree.best_path(c)
		var dt := DialogTree.new()
		dt.start(c)
		var ok_all := true
		for s in path:
			if dt.ended():
				break
			var o: Dictionary = dt.options()[int(s["i"])]
			var en_text := str(o.get("en", ""))
			if en_text == "":
				no_en += 1
			var m := IACustomer.match_option(dt, str(pia.call("paraphrase", en_text, steps * 7 + 3)))
			steps += 1
			if int(m["i"]) == int(s["i"]):
				exact += 1
			else:
				ok_all = false
			var tipo := str(o.get("tipo", ""))
			if EN_GENERIC.has(tipo):
				var phr: Array = EN_GENERIC[tipo]
				var mg := IACustomer.match_option(dt, str(phr[steps % phr.size()]))
				g_steps += 1
				if int(mg["i"]) >= 0:
					var og: Dictionary = dt.options()[int(mg["i"])]
					if str(og.get("tipo", "")) == tipo:
						g_same += 1
					if not str(og.get("tipo", "")) in ["trampa", "fuera"]:
						g_good += 1
			dt.choose(int(s["i"]))
			if dt.waiting_action():
				dt.action_done(str(s.get("r", "ok")))
		if ok_all:
			resolved += 1
	var pe := 100.0 * float(exact) / maxf(1.0, float(steps))
	var pg := 100.0 * float(g_good) / maxf(1.0, float(g_steps))
	var ps := 100.0 * float(g_same) / maxf(1.0, float(g_steps))
	t.note("inglés escrito: %d árboles · %d pasos · paráfrasis → opción correcta %.1f %% · árboles enteros %d/%d · frase genérica → mismo tipo %.1f %%, opción buena %.1f %%" % [trees.size(), steps, pe, resolved, trees.size(), ps, pg])
	t.check(no_en == 0, "todas las opciones del mejor camino tienen texto en inglés (%d sin él)" % no_en)
	t.check(pe >= 85.0, "inglés: paráfrasis con faltas → opción correcta: %.1f %% (misma vara que en español)" % pe)
	t.check(float(resolved) / maxf(1.0, float(trees.size())) >= 0.75, "inglés: árboles resueltos enteros escribiendo: %d/%d" % [resolved, trees.size()])
	t.check(pg >= 70.0, "inglés: frase genérica razonable → opción buena (no trampa): %.1f %%" % pg)
	# 3. El micrófono con el juego en inglés: la voz sin conexión es solo en español y se dice claro.
	var lang0 := Loc.language
	Loc.set_language("en")
	await t.frames(2)
	t.check(IASpeech.spanish_only() and IASpeech.language_mismatch(), "en inglés, el motor de voz sin conexión no entiende el idioma del juego")
	t.check(tr("IA_MIC_ES_ONLY").to_upper().contains("SPANISH ONLY") and tr("IA_MIC_ES_ONLY").contains("quick reply"), "el aviso lo dice claro: «%s»" % tr("IA_MIC_ES_ONLY"))
	var opt := OptionsMenu.new()
	opt.name = "OpcionesPrueba"
	(t.main.get_node("UI") as Node).add_child(opt)
	await t.frames(3)
	var note := opt.find_child("AvisoVozSoloEspanol", true, false) as Label
	t.check(note != null and note.text == tr("IA_MIC_ES_ONLY"), "Opciones (inglés): aviso de «solo español» junto a la opción del micrófono")
	opt.queue_free()
	await t.frames(2)
	var panel := PcIACall.new()
	(t.main.get_node("UI") as Node).add_child(panel)
	Loc.set_setting("ia_llamadas", "microfono")
	await t.frames(2)
	panel.refresh(0.016)
	var ln := panel.find_child("AvisoVozSoloEspanol", true, false) as Label
	t.check(ln != null and ln.visible and ln.text == tr("IA_MIC_ES_ONLY_SHORT") and panel.fallback, "panel de la llamada (inglés, micrófono): aviso visible y respuestas rápidas a mano")
	var btn := panel.get("_btn") as Button
	t.check(btn != null and (btn.icon != null or btn.text != ""), "el botón del micrófono tiene icono (antes: un emoji que la fuente no trae)")
	Loc.set_language("es")
	await t.frames(2)
	panel.fallback = false
	panel.refresh(0.016)
	t.check(not IASpeech.language_mismatch() and not ln.visible, "en español no hay aviso")
	Loc.set_setting("ia_llamadas", "predefinidas")
	panel.queue_free()
	IASpeech.shutdown()
	Loc.set_language(lang0)
	await t.frames(2)


# ----------------------------------------------------------------------------------------------------------------
# Regla de nombres (legal): nada del mundo real en el repositorio ni en los paquetes.


## Textos fijos (Label, Button, Label3D, placeholders) bajo `root` que siguen en el idioma `from`.
func _stale(root: Node, from: String) -> Array[String]:
	var pairs := Loc.translation_pairs(from)
	var out: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children(true))
		var txt := ""
		if n is Label or n is Button or n is LinkButton or n is Label3D:
			txt = str(n.get("text"))
		elif n is LineEdit or n is TextEdit:
			txt = str(n.get("placeholder_text"))
		if txt != "" and Loc.swap_text(txt, pairs) != txt and not out.has(txt):
			out.append(txt)
	return out


func _idioma_en_caliente(t: Node) -> void:
	Loc.set_language("es")
	await t.back_to_menu()
	await t.frames(3)
	var comprimidos: Array[String] = []
	var d := DirAccess.open("res://localization")
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".csv.import"):
				continue
			var imp := FileAccess.get_file_as_string("res://localization/" + f)
			if imp.contains("[params]") and not imp.contains("compress=0"):  # en un exportado el .import solo trae el remap
				comprimidos.append(f)
	t.check(comprimidos.is_empty(), "ningún .csv se importa comprimido (sin claves no se puede retraducir): %s" % str(comprimidos))
	# 1) Como el jugador que abre en español y pasa a English en Opciones ANTES de empezar el turno.
	Loc.set_language("en")
	var es_en := Loc.translation_pairs("es")
	t.check(es_en.size() > 400, "las traducciones traen sus claves (%d textos distintos entre español e inglés)" % es_en.size())
	t.check(Loc.retranslated > 20, "al pasar a inglés en el menú se retraducen los textos ya construidos (%d)" % Loc.retranslated)
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var ws := t.get_tree().get_first_node_in_group("workstation") as Control
	ws.call("set_zoom", true)
	await t.frames(6)
	var fonex: Node = ws.get("fonex")
	var accept := fonex.get("_accept") as Button
	t.check(accept != null and accept.text == "Accept [Space]", "el botón de aceptar del softphone está en inglés («%s»)" % (accept.text if accept != null else "—"))
	var aux_b: Array = fonex.get("_aux_buttons")
	t.check(aux_b.size() >= 5 and (aux_b[4] as Button).text == "5 Restroom", "y los AUX («%s»)" % ((aux_b[4] as Button).text if aux_b.size() >= 5 else "—"))
	var stale := _stale(t.main, "es")
	t.check(stale.is_empty(), "turno en inglés: 0 textos fijos en español en toda la interfaz (%d: %s)" % [stale.size(), str(stale.slice(0, 12))])
	var tips := t.get_tree().get_first_node_in_group("agent_tips")
	var title := ((tips.get("_box") as Control).get_child(0).get_child(0) as Label).text
	t.check(title == "FIRST TIME", "el título del aviso de primera vez también («%s»)" % title)
	# Lo que las apps dibujan con caché (Kardex sin caso, reglas de Identa) también se redibuja.
	var desk: Node = ws.get("desktop")
	var conv := ((desk.get("kardex") as Node).get("_conv") as RichTextLabel).get_parsed_text()
	t.check(conv.contains("No open case") and not conv.contains("Sin caso"), "el Kardex sin caso se redibuja en inglés («%s»)" % conv.substr(0, 40).replace("\n", " "))
	desk.call("open_app", "identa")
	await t.frames(4)
	var rules := ((desk.get("identa") as Node).get("_rules") as RichTextLabel).get_parsed_text()
	t.check(rules.contains("All regions") and not rules.contains("Cualquiera"), "las reglas de Identa no enseñan la clave «Cualquiera»")
	desk.call("open_app", "kardex")
	# 2) Desde la Pausa, con el turno en marcha y la PC abierta: de vuelta al español.
	Loc.set_language("es")
	await t.frames(6)
	t.check(accept.text == "Aceptar [Espacio]" and (aux_b[4] as Button).text == "5 Baño", "al volver al español en pleno turno el softphone cambia en el acto («%s», «%s»)" % [accept.text, (aux_b[4] as Button).text])
	stale = _stale(t.main, "en")
	t.check(stale.is_empty(), "0 textos fijos en inglés (%d: %s)" % [stale.size(), str(stale.slice(0, 12))])
	conv = ((desk.get("kardex") as Node).get("_conv") as RichTextLabel).get_parsed_text()
	t.check(conv.contains("Sin caso abierto"), "y el Kardex vuelve al español sin esperar a un contacto")
	# 3) Lo que escribe el jugador no se toca aunque coincida con un texto de la interfaz.
	var le := LineEdit.new()
	le.text = "Enviar"
	le.placeholder_text = tr("IA_CALL_SAY")
	t.main.add_child(le)
	Loc.set_language("en")
	t.check(le.text == "Enviar" and le.placeholder_text == "Say to the customer… (Enter)", "lo escrito por el jugador no se traduce; el texto de ayuda de la caja sí («%s» / «%s»)" % [le.text, le.placeholder_text])
	le.queue_free()
	Loc.set_language("es")
	await t.back_to_menu()


func _rects_apart(a: Control, b: Control) -> bool:
	return not a.is_visible_in_tree() or not b.is_visible_in_tree() or not a.get_global_rect().intersects(b.get_global_rect())


func _hud_franjas(t: Node) -> void:
	Loc.set_language("es")
	await _quiet_shift(t, "Jiroshi")
	var hud := t.main.get("hud") as Control
	var ws := t.get_tree().get_first_node_in_group("workstation") as Control
	var tips := t.get_tree().get_first_node_in_group("agent_tips")
	var tbox: Control = tips.get("_box")
	var note: Control = hud.get("_note_box")
	# 1) Tamaños: a 13 px de diseño no se leían en 1280×720.
	var m := hud.get("_metrics") as Label
	var dsc := hud.get("_disc") as Label
	t.check(m.get_theme_font_size("font_size") >= 16 and dsc.get_theme_font_size("font_size") >= 15, "métricas y disciplina del HUD a %d y %d px de diseño" % [m.get_theme_font_size("font_size"), dsc.get_theme_font_size("font_size")])
	var help := ws.get("_help") as Label
	var help_bg := (help.get_parent() as Control).get_theme_stylebox("panel") as StyleBoxFlat
	t.check(help.get_theme_font_size("font_size") >= 15 and help_bg != null and help_bg.bg_color.a >= 0.6, "la línea de atajos de la PC a %d px sobre fondo oscuro" % help.get_theme_font_size("font_size"))
	# 2) PC acercada: aviso de primera vez y aviso de texto comparten la franja de arriba.
	ws.call("set_zoom", true)
	await t.frames(3)
	(tips.get("_queue") as Array).append("contacto")
	await _vd_wait(t, 0.4)
	t.check(tbox.visible, "sale un aviso de primera vez")
	VoiceDirector.notice("ezlak", "@Shero · Shero: ¿Dónde estás? Tu AUX dice Available y tu silla está vacía.", 3.0, true)
	await _vd_wait(t, 0.4)
	t.check(note.visible and not tbox.visible, "llega un aviso de texto: el de primera vez se aparta (aviso %s, primera vez %s)" % [str(note.visible), str(tbox.visible)])
	var overlap := false
	var back := await _vd_until(t, func() -> bool:
		if note.visible and tbox.visible and note.get_global_rect().intersects(tbox.get_global_rect()):
			overlap = true
		return not note.visible and tbox.visible, 8.0)
	t.check(back, "al irse el aviso de texto, el de primera vez vuelve a salir")
	t.check(not overlap, "nunca estuvieron uno encima del otro")
	# 3) De pie no comparten franja: los dos a la vez, sin pisarse, y recolocado en el mismo cuadro.
	ws.call("set_zoom", false)
	await t.frames(2)
	VoiceDirector.notice("sys", "Llamando a Marko…", 2.0, true)
	await _vd_wait(t, 0.3)
	t.check(note.visible and tbox.visible and _rects_apart(note, tbox), "sin acercar la PC salen los dos y no se pisan (%s / %s)" % [str(note.get_global_rect()), str(tbox.get_global_rect())])
	VoiceDirector.clear_notices()
	tips.call("_clear")
	# 4) El mensaje va encima del subtítulo, también con uno de tres líneas.
	var sub := hud.get("_sub") as Label
	var msg := hud.get("_msg") as Label
	EventBus.show_message.emit("Estás en una PC: cambia el AUX ahí.", 6.0)
	hud.call("_on_subtitle", "comp", "(Jiroshi) Promoción del 25 de agosto de 2023. Éramos cinco. Nayra duró tres meses. Yimi, seis. Quedo yo. Y cada noche, a las 3:47, alguien que ya no trabaja aquí vuelve a marcar Available en la PC de al lado, y Shero le contesta como si nada hubiera pasado.", 6.0)
	await t.frames(4)
	t.check(sub.size.y > 60.0, "el subtítulo largo ocupa varias líneas (%.0f px)" % sub.size.y)
	t.check(_rects_apart(sub, msg), "y el mensaje queda encima, sin pisarlo (mensaje hasta y=%.0f, subtítulo desde y=%.0f)" % [msg.get_global_rect().end.y, sub.get_global_rect().position.y])
	hud.call("_on_subtitle", "comp", "Corto.", 3.0)
	await t.frames(4)
	t.check(_rects_apart(sub, msg) and msg.get_global_rect().end.y > sub.get_global_rect().position.y - 80.0, "con un subtítulo corto el mensaje vuelve a su sitio")
	ws.call("set_zoom", true)
	await t.frames(4)
	# 4b) PC acercada: un mensaje que antes ocupaba dos renglones caía encima de la barra de apps y de la línea de
	#     estado de Fonex. Ahora va en un renglón, debajo del subtítulo y encima de la línea de atajos.
	EventBus.show_message.emit("Contacto desconectado: vuelve a la cola (no cuenta como perdida ni en el AHT).", 6.0)
	hud.call("_on_subtitle", "clientes", "Aló. Quiero saber el estado de mi envío. Mi envío. El estado.", 6.0)
	await t.frames(4)
	var zb := ws.get("_zoom_box") as Control
	var pc_bottom := zb.global_position.y + zb.size.y * zb.scale.y
	var mr := msg.get_global_rect()
	var hb0 := (help.get_parent() as Control).get_global_rect()
	t.check(mr.size.y < 40.0, "PC acercada: el mensaje largo cabe en un renglón (%.0f px de alto)" % mr.size.y)
	t.check(mr.position.y >= pc_bottom - 1.0, "no pisa la PC (PC hasta y=%.0f, mensaje desde y=%.0f)" % [pc_bottom, mr.position.y])
	t.check(_rects_apart(sub, msg) and mr.position.y >= sub.get_global_rect().end.y - 1.0, "va debajo del subtítulo sin pisarlo (subtítulo hasta y=%.0f)" % sub.get_global_rect().end.y)
	t.check(mr.end.y <= hb0.position.y + 1.0, "y encima de la línea de atajos (mensaje hasta y=%.0f, atajos desde y=%.0f)" % [mr.end.y, hb0.position.y])
	EventBus.show_message.emit("", 0.1)
	hud.call("_on_subtitle", "comp", "Corto.", 0.5)
	var hb := (help.get_parent() as Control).get_global_rect()
	var vps := t.get_tree().root.get_visible_rect().size
	t.check(help.is_visible_in_tree() and hb.position.x >= 0.0 and hb.end.x <= vps.x and hb.end.y <= vps.y and not hb.intersects(ws.call("zoom_rect")), "los atajos caben enteros debajo de los monitores (%s; pantalla %s; monitores %s)" % [str(hb), str(vps), str(ws.call("zoom_rect"))])
	Loc.set_language("en")
	await t.frames(4)
	hb = (help.get_parent() as Control).get_global_rect()
	t.check(hb.position.x >= 0.0 and hb.end.x <= vps.x and help.text.begins_with("Mouse"), "también en inglés (%s)" % str(hb))
	Loc.set_language("es")
	await t.frames(2)
	# 5) El REC de Haime con la PC acercada: entero a la vista, fuera de los monitores y de los avisos.
	var rec: Node = t.get_tree().root.find_child("QaRec", true, false)
	t.check(rec != null, "hay un REC de Haime")
	if rec != null:
		ws.call("set_zoom", true)
		rec.set("_hold", 30.0)
		await t.frames(6)
		var score := rec.get("_score") as Label
		var vp := t.get_tree().root.get_visible_rect().size
		var r: Rect2 = ws.call("zoom_rect")
		var sr := score.get_global_rect()
		t.check(score.is_visible_in_tree() and not sr.intersects(r) and sr.position.x >= 0.0 and sr.end.x <= vp.x and sr.position.y >= 0.0, "con la PC acercada el REC está entero y fuera de los monitores (%s; monitores %s)" % [str(sr), str(r)])
		VoiceDirector.notice("ezlak", "@Shero · Shero: Break. Ok.", 2.0, true)
		await _vd_wait(t, 0.3)
		t.check(_rects_apart(score, note), "y no se pisa con el aviso de texto")
		rec.set("_hold", 0.0)
	VoiceDirector.clear_notices()
	# 6) Ventana estrecha (el navegador, una ventana pequeña): el viewport lógico baja de 1920 de ancho. El aviso se
	#    encoge, no entra en la columna del reloj y el de primera vez espera aunque estés de pie.
	var root := t.get_tree().root
	var css := root.content_scale_size
	root.content_scale_size = Vector2i(1067, 600)
	ws.call("set_zoom", false)
	tips.call("_clear")
	await t.frames(4)
	(tips.get("_queue") as Array).append("break")
	await _vd_wait(t, 0.4)
	var largo := "@Juan · Juan: Lunch. 45 minutos exactos, ni uno más. Yo me pasé una vez y desperté en el sofá rojo con un WW en la frente. Pero desperté."
	VoiceDirector.notice("ezlak", largo, 3.0, true)
	await _vd_wait(t, 0.5)
	var vpn := root.get_visible_rect().size
	var nr := note.get_global_rect()
	var clock := hud.get("_clock") as Label
	var clock_left := clock.get_global_rect().end.x - clock.get_minimum_size().x
	var met_left := m.get_global_rect().end.x - m.get_minimum_size().x
	t.check(vpn.x < 1200.0 and note.visible and not tbox.visible, "ventana estrecha (%.0f px lógicos): sale el aviso y el de primera vez espera" % vpn.x)
	t.check(nr.position.x >= 0.0 and nr.end.x <= clock_left - 4.0, "el aviso no llega al reloj (aviso hasta x=%.0f, reloj desde %.0f)" % [nr.end.x, clock_left])
	t.check(nr.end.x <= met_left - 4.0 or nr.end.y <= m.get_global_rect().position.y, "ni a las métricas (aviso hasta x=%.0f y=%.0f; métricas desde x=%.0f y=%.0f)" % [nr.end.x, nr.end.y, met_left, m.get_global_rect().position.y])
	root.content_scale_size = css
	VoiceDirector.clear_notices()
	tips.call("_clear")
	await t.frames(3)
	VoiceDirector.notice("sys", "Llamando a Marko…", 1.0, true)
	await _vd_wait(t, 0.3)
	nr = note.get_global_rect()
	var vpw := root.get_visible_rect().size
	t.check(absf((nr.position.x + nr.end.x) * 0.5 - vpw.x * 0.5) < 3.0 and nr.size.x >= 780.0, "de vuelta a la ventana normal el aviso recupera su ancho y sigue centrado (%s)" % str(nr))
	VoiceDirector.clear_notices()
	# Un panel centrado con UITheme.center_fit no deja nada colgado del viewport al cerrarse.
	var n0 := root.size_changed.get_connections().size()
	var tmp := PanelContainer.new()
	root.add_child(tmp)
	UITheme.center_fit(tmp)
	await t.frames(2)
	var n1 := root.size_changed.get_connections().size()
	tmp.queue_free()
	await t.frames(3)
	var n2 := root.size_changed.get_connections().size()
	t.check(n1 > n0 and n2 == n0, "center_fit: se conecta al viewport al entrar (%d → %d) y se suelta al cerrarse (%d)" % [n0, n1, n2])
	# El cartel del evento de Rasec («¡FELIZ …!») no queda debajo del aviso de texto y está centrado también en una
	# pantalla más ancha que 16:9.
	var ev := EventoUI.new()
	root.add_child(ev)
	await t.frames(2)
	ev.open("karaoke", "Halloween")
	await t.frames(3)
	var cartel := ev.get("_banner") as Label
	var y0 := cartel.get_global_rect().position.y
	VoiceDirector.notice("ezlak", "@Rasec · Rasec: pasa a BO y ven al centro de la sala. Te guardé un sitio. Ya tiene tu nombre. Te lo guardé yo mismo, con cariño, como a todos los que ya no están. No tardes, que la sonrisa cansa y el karaoke no espera a nadie.", 3.0, true)
	await _vd_wait(t, 0.4)
	nr = note.get_global_rect()
	var cr := cartel.get_global_rect()
	t.check(note.visible and cr.position.y >= nr.end.y, "con un aviso de varios renglones el cartel del evento baja (aviso hasta %.0f, cartel desde %.0f; sin aviso estaba en %.0f)" % [nr.end.y, cr.position.y, y0])
	VoiceDirector.clear_notices()
	await t.frames(3)
	t.check(absf(cartel.get_global_rect().position.y - y0) < 1.0, "sin aviso el cartel vuelve a su sitio (%.0f)" % cartel.get_global_rect().position.y)
	root.content_scale_size = Vector2i(2560, 1080)
	await t.frames(4)
	cr = cartel.get_global_rect()
	var vw := root.get_visible_rect().size.x
	t.check(absf((cr.position.x + cr.end.x) * 0.5 - vw * 0.5) < 2.0, "en una pantalla ultrapanorámica el cartel sigue centrado (centro %.0f de %.0f)" % [(cr.position.x + cr.end.x) * 0.5, vw])
	root.content_scale_size = css
	ev.queue_free()
	await t.frames(3)
	var carteles := [["Halloween", "es", "¡FELIZ HALLOWEEN!"], ["el aniversario de la campaña KipuPay", "es", "¡FELIZ ANIVERSARIO DE LA CAMPAÑA KIPUPAY!"],
		["el Día de la Madre", "es", "¡FELIZ DÍA DE LA MADRE!"], ["Fiestas Patrias", "es", "¡FELICES FIESTAS PATRIAS!"], ["San Valentín", "es", "¡FELIZ SAN VALENTÍN!"],
		["the KipuPay campaign anniversary", "en", "HAPPY KIPUPAY CAMPAIGN ANNIVERSARY!"], ["Mother's Day", "en", "HAPPY MOTHER'S DAY!"]]
	var mal_c: Array[String] = []
	for c: Array in carteles:
		var got_c := EventoUI.banner_text(str(c[0]), str(c[1]), "¡FELIZ {tema}!" if str(c[1]) == "es" else "HAPPY {tema}!")
		if got_c != str(c[2]):
			mal_c.append("%s → %s" % [str(c[0]), got_c])
	t.check(mal_c.is_empty(), "el cartel del evento sin artículo y en plural cuando toca (7 temas): %s" % str(mal_c))
	# Ventana mínima en escritorio: 1280×720, o lo que quepa si la pantalla es más chica (portátil de 1366×768).
	var casos := [[Vector2i(1920, 1040), Vector2i(16, 39), Vector2i(1280, 720)], [Vector2i(1366, 728), Vector2i(16, 39), Vector2i(1280, 689)],
		[Vector2i(1280, 720), Vector2i(0, 22), Vector2i(1280, 698)], [Vector2i(0, 0), Vector2i(0, 0), Vector2i(1280, 720)], [Vector2i(800, 600), Vector2i(0, 0), Vector2i(960, 600)]]
	var mal: Array[String] = []
	for c: Array in casos:
		var got: Vector2i = OptionsMenu.fit_min_window(c[0], c[1])
		if got != c[2]:
			mal.append("%s+%s → %s (quería %s)" % [str(c[0]), str(c[1]), str(got), str(c[2])])
	t.check(mal.is_empty(), "ventana mínima según la pantalla (5 casos): %s" % str(mal))
	await t.back_to_menu()


func _write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_rm_tree(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


## Id de blob de git de un contenido (sha1 de «blob <n>\0» + bytes), como lo calcula tools/check_nombres.py.
func _blob_id(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	var head := ("blob %d" % data.size()).to_utf8_buffer()
	head.append(0)
	h.update(head)
	if not data.is_empty():
		h.update(data)
	return h.finish().hex_encode()


func _count(problems: Array, needle: String) -> int:
	var n := 0
	for p in problems:
		if str(p).contains(needle):
			n += 1
	return n


func _regla_nombres(t: Node) -> void:
	var guard: RefCounted = (load("res://scripts/dev/name_guard.gd") as GDScript).new()
	# Las palabras van partidas también aquí: este archivo pasa por la misma regla.
	var persona: String = "che" + "ro"
	var empresa: String = "web" + "help"
	var comun: String = "Mar" + "co"
	# 1. El detector: palabra entera; las que además son palabras comunes solo cuentan con mayúscula.
	t.check((guard.call("scan_text", "ayer vino %s a la sala" % persona.capitalize()) as PackedStringArray).size() == 1, "un nombre real en un texto se detecta")
	t.check((guard.call("scan_text", "LOGO DE %s EN LA VIDRIERA" % empresa.to_upper()) as PackedStringArray).size() == 1, "una empresa real se detecta (también en mayúsculas)")
	t.check((guard.call("scan_text", "saluda a %s y a %s" % [comun, comun.to_upper()]) as PackedStringArray).size() == 2, "el nombre que también es palabra común cuenta con mayúscula inicial o en mayúsculas")
	t.check((guard.call("scan_text", "el %s de la puerta, tomar agua, Lorenzo, comienzo, %sn, Tomás" % [comun.to_lower(), persona]) as PackedStringArray).is_empty(), "las palabras comunes y los trozos de otra palabra no cuentan")
	var masked := guard.call("scan_text", "hola " + persona) as PackedStringArray
	t.check(masked.size() == 1 and not masked[0].contains(persona) and masked[0].contains("*"), "el informe enmascara la palabra (%s)" % (masked[0] if masked.size() > 0 else "?"))
	# 2. Un árbol de prueba con las tres faltas y dos archivos limpios.
	var root := ProjectSettings.globalize_path("user://regla_nombres")
	_rm_tree(root)
	_write(root.path_join("docs/ref/site/fachada.png"), "no es una imagen")
	_write(root.path_join("docs/notas.md"), "# Notas\n\nLa referencia de %s sirve para la postura.\n" % persona.to_upper())
	_write(root.path_join("game/caras/%s/avatar.txt" % empresa), "limpio")
	_write(root.path_join("game/limpio.gd"), "## el %s de la puerta; tomar la llamada\n" % comun.to_lower())
	_write(root.path_join("docs/limpio.md"), "Shero, Jiroshi, Marko, Llauri, Ttoom y Juan trabajan en Konzentramance.\n")
	var problems: Array = guard.call("scan_tree", root)
	t.check(_count(problems, "docs/ref/site/fachada.png: está bajo docs/ref/") == 1, "un archivo bajo docs/ref/ es una falta")
	t.check(_count(problems, "docs/notas.md: nombre prohibido en el contenido") == 1, "un nombre real en un .md de docs/ es una falta (no solo en game/)")
	t.check(_count(problems, "avatar.txt: nombre prohibido en la ruta") == 1, "un nombre real en una ruta es una falta")
	t.check(problems.size() == 3 and _count(problems, "limpio") == 0, "los archivos limpios no dan falsos positivos (%d faltas)" % problems.size())
	t.check(_count(problems, persona) == 0 and _count(problems, persona.to_upper()) == 0, "las faltas se informan sin repetir el nombre")
	# 3. El repositorio de verdad está limpio y docs/ref ya no existe.
	var repo := str(guard.call("repo_root"))
	if repo == "":
		t.note("sin repositorio alrededor de game/ (build exportado): no se revisa el árbol real")
	else:
		var real: Array = guard.call("scan_tree", repo)
		t.check(real.is_empty(), "el repositorio entero pasa la regla de nombres (%d archivos, %d faltas%s)" % [int(guard.get("files_checked")), real.size(), ": " + str(real.slice(0, 3)) if not real.is_empty() else ""])
		t.check(int(guard.get("files_checked")) > 300, "se revisó el repositorio entero, no una carpeta suelta (%d archivos)" % int(guard.get("files_checked")))
		t.check(not DirAccess.dir_exists_absolute(repo.path_join("docs/ref")), "docs/ref/ no está en el repositorio")
		t.check(not DirAccess.dir_exists_absolute(repo.path_join("docs/capturas")), "docs/capturas/ (capturas de desarrollo con nombres viejos) no está en el repositorio")
		# El GDD v0.1 y el plan de la v0.3 (los citan ~110 comentarios del código) vuelven como copias saneadas.
		for doc in ["docs/GDD_AVAILABLE_v0.1.md", "docs/GDD_AVAILABLE_v0.1.docx", "docs/PLAN_v0.3.md"]:
			var dp := repo.path_join(doc)
			t.check(FileAccess.file_exists(dp), "%s está (copia saneada)" % doc)
			var dtxt := FileAccess.get_file_as_string(dp) if doc.ends_with(".md") else str(guard.call("_zip_text", dp))
			t.check(dtxt.length() > 20000 and (guard.call("scan_text", dtxt) as PackedStringArray).is_empty(), "%s no tiene nombres prohibidos (%d caracteres)" % [doc, dtxt.length()])
		await _regla_nombres_tools(t, repo, root, persona)
	_rm_tree(root)


## tools/check_nombres.py (lo usan package_release.sh y la subida a Steam) y las listas explícitas de los paquetes.
func _regla_nombres_tools(t: Node, repo: String, root: String, persona: String) -> void:
	var tool := repo.path_join("tools/check_nombres.py")
	t.check(FileAccess.file_exists(tool), "tools/check_nombres.py existe")
	var out: Array = []
	var code := OS.execute("python3", ["-I", tool, "--dir", root], out, true)
	if code == -1 or code == 127:
		t.note("python3 no disponible: tools/check_nombres.py y las listas de paquetes no se prueban aquí")
		return
	var text := "".join(out)
	t.check(code == 1 and text.contains("3 problemas"), "check_nombres.py --dir falla con las mismas tres faltas (código %d: %s)" % [code, text.strip_edges().get_slice("\n", text.strip_edges().count("\n"))])
	t.check(not text.to_lower().contains(persona), "check_nombres.py tampoco repite el nombre en su informe")
	# Un archivo retirado que vuelve con otro nombre: su id de blob está en la lista de bloqueados.
	var data := "contenido de una foto retirada\n".to_utf8_buffer()
	var extra := ProjectSettings.globalize_path("user://regla_nombres_b")
	_rm_tree(extra)
	_write(extra.path_join("arte/otra_cosa.bin"), "contenido de una foto retirada\n")
	_write(extra.path_join("bloqueados.txt"), "# prueba\n%s docs/ref/site/site_00.png\n" % _blob_id(data))
	out = []
	code = OS.execute("python3", ["-I", tool, "--dir", extra.path_join("arte"), "--bloqueados", extra.path_join("bloqueados.txt")], out, true)
	text = "".join(out)
	t.check(code == 1 and text.contains("archivo retirado que ha vuelto"), "un archivo retirado que vuelve con otro nombre se detecta por su contenido (código %d)" % code)
	_rm_tree(extra)
	var blocked := FileAccess.get_file_as_string(repo.path_join("tools/nombres_bloqueados.txt"))
	t.check(blocked.count("\n") >= 100 and blocked.contains(" docs/ref/site/"), "tools/nombres_bloqueados.txt lista los archivos retirados (%d líneas)" % blocked.count("\n"))
	# El árbol de trabajo real, con la herramienta (incluye binarios, modelos y la lista de bloqueados).
	out = []
	code = OS.execute("python3", ["-I", tool, "--quiet"], out, true)
	t.check(code == 0, "check_nombres.py sobre el árbol de trabajo: limpio (%s)" % "".join(out).strip_edges())
	# Paquete del proyecto: lista explícita.
	var allow := FileAccess.get_file_as_string(repo.path_join("tools/release_allowlist.txt"))
	t.check(allow != "" and not allow.contains("\ndocs/\n") and not allow.contains("\n.\n") and not allow.contains("\n*\n"), "tools/release_allowlist.txt no mete docs/ entera ni «todo»")
	var pkg := FileAccess.get_file_as_string(repo.path_join("tools/package_release.sh"))
	t.check(not pkg.contains("--others") and pkg.contains("release_allowlist.txt") and pkg.contains("check_nombres.py"), "package_release.sh empaqueta solo la lista explícita y pasa la regla de nombres (sin archivos no versionados)")
	t.check(not pkg.contains("builds/web/* ") and not pkg.contains("builds/windows/*.dll"), "los zips de juego nombran sus archivos (sin comodín sobre la carpeta del build)")
	out = []
	code = OS.execute("bash", [repo.path_join("tools/package_release.sh"), "--lista-proyecto"], out, true)
	if code != 0:
		t.note("bash o git no disponibles (código %d): la lista del paquete del proyecto no se prueba aquí" % code)
	else:
		var lines := "".join(out).strip_edges().split("\n")
		var bad := 0
		var game_n := 0
		for l in lines:
			if l.begins_with("docs/capturas/") or l.begins_with("docs/ref/") or l.begins_with("dist/") or l.contains(".godot/"):
				bad += 1
			if l.begins_with("game/"):
				game_n += 1
		t.check(lines.size() > 1000 and game_n > 1000 and bad == 0, "la lista del zip del proyecto: %d archivos (%d de game/), ninguno de docs/capturas, docs/ref, dist ni .godot (%d)" % [lines.size(), game_n, bad])
		t.check(lines.has("game/project.godot") and lines.has("docs/CHANGELOG.md") and lines.has("tools/check_nombres.py") and lines.has("game/scripts/dev/name_guard.gd"), "la lista lleva el proyecto, el CHANGELOG y la propia regla")
	# Steam: cada depot nombra sus archivos.
	for plat in ["windows", "linux"]:
		var vdf := FileAccess.get_file_as_string(repo.path_join("steam/scripts/depot_build_%s.vdf" % plat))
		t.check(vdf != "" and not vdf.contains("\"LocalPath\" \"*\"") and vdf.contains("\"LocalPath\" \"AVAILABLE.pck\""), "depot de Steam de %s: lista explícita (sin «*» sobre la carpeta del build)" % plat)
	var up := FileAccess.get_file_as_string(repo.path_join("steam/scripts/subir_steam.sh"))
	t.check(up.contains("check_nombres.py"), "subir_steam.sh pasa la regla de nombres antes de subir")
	await t.frames(1)


## De a uno. Lo que le pasó al bot humano (Juan, T2, Normal): Haime llama a las 5:14, el evento de Rasec cae a las
## 5:15, vas al evento y a las 5:22 vence el plazo de Haime: `qa_inasistencia`, sin salida. Ahora el segundo espera.
func _convocan_de_a_uno(t: Node) -> void:
	await t.start_shift("Juan", 2)
	await t.login_at_seat()
	GameState.start_calm(3600.0)  # sin Shero ni listas: aquí se mira quién convoca, no la disciplina
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	Checkpoints.set("_grace_left", 0.0)
	var hub := PersonajesP5.get_hub(t.get_tree())
	t.check(hub != null and hub.qa != null and hub.rasec != null and hub.training != null, "hay Haime, Rasec y Trainer")
	if hub == null or hub.qa == null or hub.rasec == null or hub.training == null:
		await t.back_to_menu()
		return
	hub.training.state = TrainingControl.State.HECHO  # el Trainer no entra en esta prueba
	var ev := hub.rasec.event_clock()
	t.check(ev > 0.0, "el T2 tiene evento de Rasec (%s)" % GameState.clock_text_at(ev))
	# 2 min antes (sentado y sin llamados el reloj corre rápido: un margen de 1 min se va en unos cuadros). v0.3.2-core4:
	# antes 5 min, pero Haime da ahora 4 min de juego para llegar (qa_haime.json/margen_llegada_min, antes 8): el salto
	# hasta ev + 30 s tiene que quedar dentro de ese plazo.
	await t.set_clock(ev - 120.0)
	t.check(hub.rasec.state == RasecControl.State.LIBRE and hub.qa.state != QaFeedback.State.LLAMADO, "antes del evento nadie te ha convocado (Rasec %d, Haime %d, %s)" % [hub.rasec.state, hub.qa.state, GameState.clock_text()])
	# 1) Haime llama; poco después cae la hora del evento
	hub.qa.call_now()
	t.check(hub.qa.state == QaFeedback.State.LLAMADO, "Haime te llama")
	t.check(hub.summon_pending("rasec") == "haime" and not hub.can_interrupt(false, "rasec"), "con Haime esperándote, Rasec no puede convocar (pendiente: «%s»)" % hub.summon_pending("rasec"))
	await t.set_clock(ev + 30.0)
	await t.frames(10)
	t.check(hub.rasec.state == RasecControl.State.LIBRE, "llega la hora del evento y Rasec espera su turno (estado %d)" % hub.rasec.state)
	t.check(hub.qa.state == QaFeedback.State.LLAMADO and not Checkpoints.dying, "el llamado de Haime sigue en pie y nadie te mata")
	# 2) lo de Haime se resuelve → ahora sí el evento
	hub.qa.state = QaFeedback.State.LIBRE
	Discipline.hold_slow_clock("haime", false)
	await t.frames(10)
	t.check(hub.rasec.state == RasecControl.State.CONVOCADO, "resuelto lo de Haime, Rasec convoca el evento (estado %d)" % hub.rasec.state)
	t.check(hub.summon_pending("rasec") == "", "Rasec no se bloquea a sí mismo")
	# 3) con el evento convocado, Haime (pendiente y con su hora pasada) espera; el Trainer tampoco puede
	hub.qa.state = QaFeedback.State.PENDIENTE
	hub.qa.call_at = GameState.clock_seconds - 1.0
	await t.frames(10)
	t.check(hub.qa.state == QaFeedback.State.PENDIENTE and hub.summon_pending("haime") == "rasec", "con el evento convocado, Haime espera (estado %d, pendiente «%s»)" % [hub.qa.state, hub.summon_pending("haime")])
	t.check(not hub.can_interrupt(false, "trainer"), "y el Trainer tampoco convoca")
	hub.qa.state = QaFeedback.State.LIBRE
	hub.qa.call_at = INF
	# 4) el camino forzado del Trainer («no espera más»: 20 min de juego sin hueco). Pasada 4, bot torpe T2: un contacto
	#    largo tenía esperando a Haime y al Trainer; al colgar llamó Haime y, en el mismo cuadro, el Trainer forzó el suyo.
	hub.rasec.state = RasecControl.State.HECHO
	hub.rasec.call("_hold_clock", false)
	PersonajesP5.set_counter("p5_training", "")
	await t.set_clock(maxf(GameState.clock_seconds, GameState.training_clock() + 60.0))
	t.check(hub.trainer_hold != null and hub.trainer_hold.get_index() > hub.qa.get_index() and hub.trainer_hold.get_index() < hub.training.get_index(), "el freno del Trainer corre después de Haime y antes del Trainer")
	for con_freno in [true, false]:
		hub.busy = "prueba"  # lo que tenía a los dos esperando (en la partida, el contacto largo)
		hub.trainer_hold.set_process(con_freno)
		hub.training.state = TrainingControl.State.LIBRE
		hub.training.waited_since = GameState.clock_seconds - 21.0 * 60.0
		hub.qa.state = QaFeedback.State.PENDIENTE
		hub.qa.call_at = GameState.clock_seconds - 1.0
		await t.frames(3)
		t.check(hub.qa.state == QaFeedback.State.PENDIENTE and hub.training.state == TrainingControl.State.LIBRE, "ocupado, los dos esperan (Haime %d, Trainer %d)" % [hub.qa.state, hub.training.state])
		hub.busy = ""  # se libera: Haime (que corre antes) llama…
		await t.frames(3)
		t.check(hub.qa.state == QaFeedback.State.LLAMADO, "al liberarte llama Haime (estado %d)" % hub.qa.state)
		if con_freno:
			t.check(hub.training.state == TrainingControl.State.LIBRE, "…y el Trainer, aunque lleve 21 min esperando, no fuerza su llamado encima (estado %d)" % hub.training.state)
			await t.frames(20)
			t.check(hub.training.state == TrainingControl.State.LIBRE and hub.summon_pending("trainer") == "haime", "ni un rato después: sigue esperando a que Haime termine")
			hub.qa.state = QaFeedback.State.LIBRE
			Discipline.hold_slow_clock("haime", false)
			Metrics.revoke("qa")
			await t.frames(5)
			t.check(hub.training.state == TrainingControl.State.LLAMADO, "resuelto lo de Haime, el Trainer convoca por su camino normal (estado %d)" % hub.training.state)
		else:
			t.check(hub.training.state == TrainingControl.State.LLAMADO, "sin el freno, el Trainer convocaba a la vez (la prueba mira lo que debe; estado %d)" % hub.training.state)
			hub.qa.state = QaFeedback.State.LIBRE
			Discipline.hold_slow_clock("haime", false)
			Metrics.revoke("qa")
		hub.training.state = TrainingControl.State.LIBRE
		hub.training.waited_since = -1.0
		Discipline.hold_slow_clock("trainer", false)
		Metrics.revoke("trainer")
		hub.busy = "prueba"
		await t.frames(2)
	hub.trainer_hold.set_process(true)
	hub.busy = ""
	hub.training.state = TrainingControl.State.HECHO
	hub.qa.call_at = INF
	await t.back_to_menu()


## Lo que le pasó al bot humano (Llauri, T3, Difícil): comió en la cafetería (checkpoint del lunch, piso -1), volvió
## a su PC, lo mató Haime en el piso 2, reapareció en C-14… y el evento de Rasec lo mató «por no ir» estando en el sitio.
func _respawn_piso(t: Node) -> void:
	await t.start_shift("Llauri", 2)
	await t.login_at_seat()
	GameState.start_calm(3600.0)
	Fatigue.set_value(5.0)  # sin distorsiones: con Fatiga alta la sesión «se muda» a E-07 a propósito y C-14 no acepta
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	Checkpoints.set("_grace_left", 0.0)
	var b: Building = t.building()
	var hub := PersonajesP5.get_hub(t.get_tree())
	if hub != null and hub.training != null:
		hub.training.state = TrainingControl.State.HECHO
	if hub != null and hub.rasec != null:
		hub.rasec.state = RasecControl.State.HECHO
	# checkpoint en la cafetería, como al comer el taper en el lunch. (Sin poner el AUX Lunch: al volver de un lunch de
	# verdad salta la distorsión «tu sesión está en otra fila» y C-14 deja de aceptar a propósito; aquí no se mira eso.)
	GameState.distortions_seen.append("sesion_otra_fila")
	t.player().stand_up()
	b.go_to_floor(-1, "ascensor")
	await t.frames(4)
	Checkpoints.save_checkpoint("lunch")
	t.check(GameState.current_floor == -1 and int((Checkpoints.last_checkpoint.get("game_state", {}) as Dictionary).get("current_floor", 99)) == -1, "checkpoint del lunch guardado en la cafetería (piso -1)")
	# de vuelta al piso 2, a tu silla
	b.go_to_floor(2, "ascensor")
	await t.frames(4)
	await t.login_at_seat()
	t.check(GameState.current_floor == 2 and b.current_floor == 2 and cm.player_ready(), "de vuelta en el piso 2, sentado y listo para aceptar")
	await t.die("calibracion_final", "", "haime")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.frames(4)
	t.check(b.current_floor == 2 and t.player().seated and t.player().seat_id == "C-14", "reapareces sentado en C-14, piso 2 (edificio en el %d, silla «%s»)" % [b.current_floor, t.player().seat_id])
	t.check(GameState.current_floor == 2, "y el juego sabe que estás en el piso 2 (cree que en el %d)" % GameState.current_floor)
	t.check(GameState.seated_at == "C-14", "y que estás sentado en C-14 (cree que en «%s»)" % GameState.seated_at)
	var fl2 := t.get_tree().get_first_node_in_group("floor") as FloorBase
	var s14 := fl2.seat_by_id("C-14") if fl2 != null else null
	t.check(cm.player_ready(), "así que puedes aceptar contactos (sesión %s, piso «%s», silla %s, has_session %s)" % [str(GameState.logged_in), str(fl2.name) if fl2 != null else "-", str(s14 != null), str(s14.has_session) if s14 != null else "-"])
	if hub != null:
		var d: float = hub.dist_to_marker("evento_rasec", 2)
		t.check(d < 1000.0, "se puede «llegar» al evento de Rasec desde ahí (distancia %.1f m, no infinita)" % d)
	# el otro camino: mueres en OTRO piso con el checkpoint del lunch → el piso 2 se carga y también queda coherente
	t.player().stand_up()
	b.go_to_floor(1, "ascensor")
	await t.frames(4)
	Checkpoints.set("_grace_left", 0.0)
	await t.die("training_inasistencia", "", "trainer")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.frames(4)
	t.check(b.current_floor == 2 and GameState.current_floor == 2 and GameState.seated_at == "C-14" and cm.player_ready(), "muriendo en el piso 1: reapareces en C-14, el piso es el 2 y puedes aceptar (%d / %d / «%s»)" % [b.current_floor, GameState.current_floor, GameState.seated_at])
	# pasada 6 de partidas en fotos (bot torpe «lunch», T3): mueres EN el lunch, reapareces sentado en C-14… y en ese
	# instante saltaba «tu sesión está en otra fila» (la marca de «vengo del lunch» era de la vida anterior): C-14
	# dejaba de aceptar y el primer contacto se perdía con «no estás en tu sitio» estando sentado en tu sitio.
	var dc := t.main.get("distortions") as DistortionController
	t.check(dc != null, "hay controlador de distorsiones")
	GameState.distortions_seen.erase("sesion_otra_fila")  # arriba se marcó como vista para que no estorbara
	if dc != null:
		(dc.get("_seen") as Dictionary).erase("sesion_otra_fila")
	Checkpoints.save_checkpoint("login")  # checkpoint de ANTES del lunch, sentado en C-14
	Metrics.set_aux(Metrics.Aux.LUNCH)
	await t.frames(2)
	t.check(dc != null and bool(dc.get("_in_lunch_trip")), "al poner Lunch queda anotado que «vienes del lunch»")
	t.player().stand_up()
	b.go_to_floor(1, "ascensor")
	await t.frames(4)
	Checkpoints.set("_grace_left", 0.0)
	await t.die("training_inasistencia", "", "trainer")
	await t.wait_death_shown(20.0)
	await t.reconnect()
	await t.until(func() -> bool: return Metrics.aux == Metrics.Aux.AVAILABLE, 20.0)
	await t.frames(60)  # las zonas avisan con la física: si «la sesión en otra fila» fuera a saltar, salta aquí
	var fl3 := t.get_tree().get_first_node_in_group("floor") as FloorBase
	var c14b := fl3.seat_by_id("C-14") if fl3 != null else null
	t.check(dc != null and not bool(dc.get("_in_lunch_trip")) and not bool(dc.get("_had_break")), "al reaparecer se borran «vengo del lunch» y «vengo de un break» de la vida anterior")
	t.check(not GameState.distortions_seen.has("sesion_otra_fila") and c14b != null and c14b.has_session and cm.player_ready(),
		"mueres en el lunch: al reaparecer NO salta «tu sesión está en otra fila» y C-14 acepta (AUX %s, vista %s, sesión en C-14 %s)" % [Metrics.aux_name(), str(GameState.distortions_seen.has("sesion_otra_fila")), str(c14b.has_session) if c14b != null else "-"])
	# y si la sesión se muda contigo YA sentado (te sentó el juego), vuelve sola: antes se quedaba en E-07 para siempre
	var pl3: Player = t.player()
	t.check(fl3 != null and c14b != null and pl3 != null and pl3.seated and pl3.seat_id == "C-14", "tras reaparecer estás sentado en C-14 (sentado %s, silla «%s»)" % [str(pl3.seated) if pl3 != null else "-", pl3.seat_id if pl3 != null else "-"])
	if fl3 != null and c14b != null and pl3 != null and pl3.seated:
		fl3.apply_distortion("sesion_otra_fila", {})
		t.check(not c14b.has_session and not cm.player_ready(), "la alucinación: la sesión se muda a E-07 y C-14 no acepta")
		var volvio: bool = await t.until(func() -> bool: return c14b.has_session, 30.0)
		t.check(volvio and cm.player_ready(), "sentado en C-14, a los pocos segundos la sesión vuelve sola y C-14 acepta")
		# y al reaparecer con la sesión todavía movida (mismo piso, no se reconstruye), vuelve sin esperar
		fl3.get_node("SesionVuelve").name = "SesionVuelveVieja"
		fl3.apply_distortion("sesion_otra_fila", {})
		var back2 := fl3.get_node_or_null("SesionVuelve")
		if back2 != null:
			back2.set_process(false)  # que no vuelva sola: aquí se mira el respawn
		EventBus.respawned.emit("prueba")
		await t.frames(2)
		t.check(c14b.has_session and cm.player_ready(), "al reaparecer con la sesión movida, vuelve a C-14 en el acto")
	# «Continuar» desde el menú: lo que el juego cree (piso, silla) es lo que hay
	Checkpoints.save_checkpoint("login")  # sentado en C-14, piso 2
	await t.back_to_menu()
	SaveSlots.select("Llauri")
	t.main.call("_continue_shift")
	await t.frames(6)
	var p2: Player = t.player()
	var b2: Building = t.building()
	t.check(p2 != null and b2 != null and GameState.running, "Continuar retoma el turno")
	if p2 != null and b2 != null:
		t.check(GameState.current_floor == b2.current_floor, "Continuar: el piso coincide (%d / %d)" % [GameState.current_floor, b2.current_floor])
		t.check(GameState.seated_at == (p2.seat_id if p2.seated else ""), "Continuar: la silla coincide (el juego cree «%s», el jugador está %s)" % [GameState.seated_at, ("sentado en " + p2.seat_id) if p2.seated else "de pie"])
	await t.back_to_menu()


func _tecla(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


## Primer Label/Button bajo `root` (también dentro de las pantallas de la PC) cuyo texto contiene `needle`.
func _con_texto(root: Node, needle: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children(true))
		if (n is Label or n is Button) and (n as Control).is_visible_in_tree() and str(n.get("text")).contains(needle):
			return n  # solo lo que se ve: una etiqueta oculta puede guardar un texto con formato de hace rato
	return null


## Las pistas de teclas siguen el remapeo: se cambian acciones como en Opciones → Controles y lo que se lee en pantalla
## (ES y EN) dice la tecla nueva; los textos cuya tecla está fija en el código no cambian; al restablecer, todo vuelve
## letra por letra. Y la pantalla: completa la primera vez, Alt+Intro, ventana que cabe.
func _pistas_teclas(t: Node) -> void:
	Loc.set_language("es")
	Controls.reset_all()
	await _quiet_shift(t, "Jiroshi")
	var ws := t.get_tree().get_first_node_in_group("workstation") as Control
	ws.call("set_zoom", true)
	await t.frames(3)
	var claves: Array[String] = ["HUD_SIT", "HUD_STAND", "P4_FONEX_ACCEPT", "FONEX_INCOMING_CALL", "P4_HELP_PC", "P4_HELP_TERMINAL", "Q4_CINE_SKIP", "SCR_K2_SALTAR",
		"B2_COMODIN_PICK_WHO", "B2_COMODIN_HUD_FREE", "P4_NEXT_TREE", "DEATH_BACK_MENU", "DEATH_CONTINUE", "MAN_CLOSE", "SHOP_CLOSE", "B2_RECON_HUD", "FONEX_AUX_HINT", "TUT_KEY_NEXT"]
	var antes := {}
	for k in claves:
		antes[k] = tr(k)
	t.check(not Controls.hints_active and str(antes["HUD_SIT"]).contains("[E]") and str(antes["P4_FONEX_ACCEPT"]).contains("[Espacio]") and Controls.hint("[E] Levantarse") == "[E] Levantarse",
		"de fábrica las pistas son las de siempre («%s», «%s»)" % [str(antes["HUD_SIT"]), str(antes["P4_FONEX_ACCEPT"])])
	t.check(_con_texto(ws, "[Espacio]") != null, "en la PC hay un botón con «[Espacio]»")
	t.check(Controls.ACTIONS.has("comodin") and Controls.ACTIONS.has("ia_hablar") and tr("CTRL_COMODIN") != "CTRL_COMODIN" and tr("CTRL_IA_HABLAR") != "CTRL_IA_HABLAR", "el comodín y el micrófono salen en Opciones → Controles con su nombre")
	# 1) como en Opciones → Controles: interactuar → G, aceptar → V
	Controls.rebind("interact", _tecla(KEY_G))
	Controls.rebind("accept", _tecla(KEY_V))
	await t.frames(2)
	t.check(Controls.hints_active and tr("HUD_SIT") == str(antes["HUD_SIT"]).replace("[E]", "[G]") and tr("HUD_STAND").contains("[G]") and not tr("HUD_STAND").contains("[E]"), "interactuar → G: «%s», «%s»" % [tr("HUD_SIT"), tr("HUD_STAND")])
	t.check(tr("P4_FONEX_ACCEPT") == str(antes["P4_FONEX_ACCEPT"]).replace("[Espacio]", "[V]") and tr("FONEX_INCOMING_CALL").contains("[V]") and tr("DEATH_CONTINUE").contains("[V]"), "aceptar → V: «%s», «%s», «%s»" % [tr("P4_FONEX_ACCEPT"), tr("FONEX_INCOMING_CALL"), tr("DEATH_CONTINUE")])
	t.check(tr("P4_HELP_PC").contains("V aceptar") and tr("P4_HELP_PC").ends_with("G salir") and not tr("P4_HELP_PC").contains("Espacio"), "la línea de atajos de la PC (sin corchetes) también: «%s»" % tr("P4_HELP_PC"))
	t.check(tr("P4_HELP_TERMINAL").ends_with("Q / G salir"), "y la de la terminal: «%s»" % tr("P4_HELP_TERMINAL"))
	t.check(tr("Q4_CINE_SKIP") == str(antes["Q4_CINE_SKIP"]) and tr("SCR_K2_SALTAR") == str(antes["SCR_K2_SALTAR"]) and tr("B2_COMODIN_PICK_WHO") == str(antes["B2_COMODIN_PICK_WHO"]) and tr("MAN_CLOSE") == str(antes["MAN_CLOSE"]) and tr("TUT_KEY_NEXT") == str(antes["TUT_KEY_NEXT"]),
		"los textos con la tecla fija en el código no cambian («%s», «%s»)" % [tr("Q4_CINE_SKIP"), tr("B2_COMODIN_PICK_WHO")])
	var viejo := _con_texto(ws, "[Espacio]")
	t.check(_con_texto(ws, "[V]") != null and viejo == null, "lo que ya estaba en pantalla cambió: el botón de la PC dice «[V]» (queda con Espacio: %s)" % (("«%s» en %s" % [str(viejo.get("text")), str(viejo.get_path()).right(60)]) if viejo != null else "nada"))
	var pill := ws.get("_help") as Label
	t.check(pill.text.ends_with("G salir"), "y la línea de atajos de abajo: «…%s»" % pill.text.right(24))
	var tip_txt := str((load("res://scripts/ui/agent_tips.gd") as GDScript).call("text_of", "contacto"))
	t.check(tip_txt.contains("[V]") and not tip_txt.contains("[Espacio]"), "el aviso de primera vez (sale del manual, no de una traducción) también: «%s»" % tip_txt.left(60))
	t.check(Controls.hint("[E] Sentarte · [Espacio] aceptar · [Esc] salir") == "[G] Sentarte · [V] aceptar · [Esc] salir", "el ayudante para textos sueltos: «%s»" % Controls.hint("[E] Sentarte · [Espacio] aceptar · [Esc] salir"))
	# inglés: la misma tecla, con su nombre en inglés
	Loc.set_language("en")
	await t.frames(2)
	t.check(tr("HUD_SIT").contains("[G]") and tr("P4_FONEX_ACCEPT").contains("[V]") and tr("P4_HELP_PC").contains("V accept") and _con_texto(ws, "[V]") != null and _con_texto(ws, "[Space]") == null, "en inglés igual: «%s», «%s»" % [tr("HUD_SIT"), tr("P4_FONEX_ACCEPT")])
	Controls.rebind("interact", _tecla(KEY_SPACE))
	Controls.rebind("accept", _tecla(KEY_E))
	t.check(tr("HUD_SIT").contains("[Space]") and tr("P4_FONEX_ACCEPT").contains("[E]"), "una tecla con nombre se dice en el idioma («%s») y el cruce E ↔ Espacio no se pisa («%s»)" % [tr("HUD_SIT"), tr("P4_FONEX_ACCEPT")])
	Loc.set_language("es")
	await t.frames(2)
	t.check(tr("HUD_SIT").contains("[Espacio]") and Controls.hint("[E] a · [Espacio] b") == "[Espacio] a · [E] b", "y en español «%s»; de una pasada: «%s»" % [tr("HUD_SIT"), Controls.hint("[E] a · [Espacio] b")])
	# 2) números, comodín, pausa
	Controls.rebind("phrase_1", _tecla(KEY_Z))
	Controls.rebind("aux_7", _tecla(KEY_0))
	Controls.rebind("comodin", _tecla(KEY_B))
	Controls.rebind("pause", _tecla(KEY_P))
	Controls.rebind("aux_wheel", _tecla(KEY_X))
	t.check(tr("P4_NEXT_TREE").contains("(Z/2/3/4 ") and tr("SHOP_CLOSE").contains("[Z/2/3]") and tr("SHOP_CLOSE").contains("[X]"), "frases y rueda de AUX: «%s», «%s»" % [tr("P4_NEXT_TREE"), tr("SHOP_CLOSE")])
	t.check(tr("B2_RECON_HUD").contains("[1/2/3/4/5/6/0]") and tr("FONEX_AUX_HINT").contains("[X]"), "AUX 1-7: «%s»" % tr("B2_RECON_HUD"))
	t.check(tr("B2_COMODIN_HUD_FREE").contains("[B]") and tr("DEATH_BACK_MENU").contains("[P]") and tr("MAN_CLOSE").contains("[Esc]"), "comodín → B: «%s»; pausa → P: «%s» (y «%s» sigue con Esc: ahí es la tecla fija)" % [tr("B2_COMODIN_HUD_FREE"), tr("DEATH_BACK_MENU"), tr("MAN_CLOSE")])
	# 3) queda guardado y vuelve al arrancar (apply_saved); restablecer lo deja todo como de fábrica, letra por letra
	var saved: Dictionary = Loc.get_setting("bindings", {})
	t.check(saved.has("interact") and saved.has("comodin") and saved.has("pause"), "lo remapeado queda en settings.json (%d acciones)" % saved.size())
	Controls.apply_saved()
	t.check(tr("B2_COMODIN_HUD_FREE").contains("[B]"), "y al volver a aplicar lo guardado las pistas siguen")
	Controls.reset_all()
	await t.frames(2)
	var distintos: Array[String] = []
	for k in claves:
		if tr(k) != str(antes[k]):
			distintos.append("%s: «%s»" % [k, tr(k)])
	t.check(distintos.is_empty() and not Controls.hints_active and _con_texto(ws, "[Espacio]") != null and pill.text == str(antes["P4_HELP_PC"]), "restablecer controles: todas las pistas vuelven letra por letra %s" % str(distintos))
	# 4) pantalla: completa la primera vez (no con herramientas ni con un tamaño pedido), Alt+Intro, ventana que cabe
	var none := PackedStringArray()
	t.check(Loc.first_launch_fullscreen(false, false, none, none), "primera vez en escritorio: pantalla completa")
	t.check(not Loc.first_launch_fullscreen(true, false, none, none) and not Loc.first_launch_fullscreen(false, true, none, none) and not Loc.first_launch_fullscreen(false, false, none, PackedStringArray(["--bot", "1"])) and not Loc.first_launch_fullscreen(false, false, PackedStringArray(["--resolution", "1280x720"]), none),
		"no en el navegador, ni sin pantalla, ni con herramientas, ni si se pidió un tamaño de ventana")
	t.check(not Loc.display_chosen({}) and not Loc.display_chosen({"fullscreen": false}) and Loc.display_chosen({"fullscreen": false, "display_v": 1}) and Loc.display_chosen({"fullscreen": true, "display_v": 1}),
		"un settings.json viejo o creado por una herramienta («fullscreen: false» sin marca) no cuenta como elección: la primera vez sigue siendo la primera")
	t.check(OptionsMenu.windowed_fit(Vector2i(1280, 720), Vector2i(1366, 728), Vector2i(16, 39)) == Vector2i(1280, 689) and OptionsMenu.windowed_fit(Vector2i(1280, 720), Vector2i(1920, 1040), Vector2i(16, 39)) == Vector2i(1280, 720),
		"al volver a ventana, cabe en la pantalla (1366×768 → 1280×689; 1920×1080 → 1280×720)")
	var fs0 := bool(Loc.get_setting("fullscreen", false))
	var alt := InputEventKey.new()
	alt.keycode = KEY_ENTER
	alt.physical_keycode = KEY_ENTER
	alt.alt_pressed = true
	alt.pressed = true
	# v0.3.2-core2: la tecla también se suelta. Antes Intro se quedaba «pulsada» para el resto de la corrida y las
	# pruebas siguientes en el mismo proceso que miran `ui_accept` (saltar una cinemática) lo veían mantenido.
	var alt_up := alt.duplicate() as InputEventKey
	alt_up.pressed = false
	Input.parse_input_event(alt)
	await t.frames(1)
	Input.parse_input_event(alt_up)
	await t.frames(3)
	var fs1 := bool(Loc.get_setting("fullscreen", false))
	Input.parse_input_event(alt)
	await t.frames(1)
	Input.parse_input_event(alt_up)
	await t.frames(3)
	t.check(not Input.is_action_pressed("ui_accept") and not Input.is_physical_key_pressed(KEY_ENTER), "y la tecla queda suelta (no se arrastra «Intro mantenido» a lo que venga después)")
	t.check(fs1 != fs0 and bool(Loc.get_setting("fullscreen", false)) == fs0, "Alt+Intro cambia la pantalla completa y lo guarda (%s → %s → %s)" % [str(fs0), str(fs1), str(Loc.get_setting("fullscreen", false))])
	t.check(int(Loc.get_setting("display_v", 0)) >= Loc.DISPLAY_V, "y deja la marca de que ya elegiste (la próxima vez no se vuelve a poner en pantalla completa sola)")
	await t.back_to_menu()



# --- v0.3.2-core2 · repetir un tramo ---------------------------------------------------------------------------

## Deja sola a la cola: nadie más convoca, persigue ni te cambia el AUX mientras se mide.
func _solo_cola(t: Node) -> void:
	for g in ["shero", "rta", PersonajesP5.GROUP, "vitzo", "mentor", "director", "distortions"]:
		for n in t.get_tree().get_nodes_in_group(g):
			(n as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _cierra_contacto(cm: ContactManager) -> void:
	if cm.tree != null:
		cm.tree.force_final(cm.tree.first_final("satisfecho"))
		cm.call("_end_tree")
	elif cm.phase == ContactManager.Phase.ACTIVE:
		cm.call("_finish", cm.current, true, false, "bo_ok", 0)


## Juega sentado en Available hasta que el reloj llegue a `until`: contesta lo que suena y lo cierra (5 min de juego
## por contacto). Apunta cada contacto en `log` y, en `st["libre"]`, lo más que estuvo libre con gente esperando en
## la cola (segundos reales del juego). `leave_open`: deja a medias el primer contacto que entre desde esa hora.
func _juega(t: Node, cm: ContactManager, until: float, log: Array, st: Dictionary, leave_open: float = -1.0) -> void:
	var from := -1.0
	var guard := 0
	while GameState.clock_seconds < until and not Checkpoints.dying and guard < 60000:
		guard += 1
		await t.frames(1)
		Fatigue.set_value(20.0)
		if Metrics.aux != Metrics.Aux.AVAILABLE and not Metrics.reconnecting:
			Metrics.set_aux(Metrics.Aux.AVAILABLE)
		if cm.phase == ContactManager.Phase.OFFERING:
			var c: Dictionary = cm.current
			var filler := bool(c.get("relleno", false))
			var e := {
				"id": str(c.get("id", "")), "base": str(c.get("ref_id", c.get("id", ""))) if filler else str(c.get("id", "")),
				"t": GameState.clock_seconds, "relleno": filler, "sustituto": bool(c.get("sustituto", false)),
				"desborde": bool(c.get("desborde", false)), "cola": GameState.queue_size, "fin": false,
			}
			cm.accept()
			if cm.phase != ContactManager.Phase.ACTIVE:
				continue
			log.append(e)
			from = -1.0
			await t.frames(2)
			if leave_open >= 0.0 and GameState.clock_seconds >= leave_open:
				return
			GameState.add_game_time(300.0)
			await t.frames(1)
			_cierra_contacto(cm)
			e["fin"] = true
		elif cm.phase == ContactManager.Phase.IDLE and Metrics.aux == Metrics.Aux.AVAILABLE and not Metrics.reconnecting and cm.player_ready() and GameState.queue_size > 0:
			if from < 0.0:
				from = t.game_s()
			st["libre"] = maxf(float(st.get("libre", 0.0)), t.game_s() - from)
		else:
			from = -1.0


func _muere_y_vuelve(t: Node) -> bool:
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	await t.die("abandono", "", "shero")
	var shown: bool = await t.wait_death_shown(14.0)
	await t.reconnect()
	GameState.stop_calm()
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	await t.frames(2)
	return shown and GameState.running and not Checkpoints.dying


func _cp_clock() -> float:
	return float((Checkpoints.last_checkpoint.get("game_state", {}) as Dictionary).get("clock_seconds", 0.0))


## Contactos del registro que entraron desde `from` (el que se aceptó en el propio checkpoint cuenta).
func _desde(log: Array, from: float) -> Array:
	var out: Array = []
	for e in log:
		if float((e as Dictionary).get("t", 0.0)) >= from - 1.0:
			out.append(e)
	return out


func _ids(log: Array) -> Array[String]:
	var out: Array[String] = []
	for e in log:
		out.append(str((e as Dictionary).get("id", "")))
	return out


## ¿Algún cliente dos veces seguidas?
func _seguidos(log: Array) -> String:
	for i in range(1, log.size()):
		if str((log[i] as Dictionary).get("base", "")) == str((log[i - 1] as Dictionary).get("base", "?")):
			return str((log[i] as Dictionary).get("base", ""))
	return ""


func _en_banda(n_ref: int, n: int) -> bool:
	return float(n) >= 0.7 * float(n_ref) and float(n) <= 1.4 * float(n_ref)


func _repite_tramo(t: Node) -> void:
	for lvl in [Difficulty.Level.DIFICIL, Difficulty.Level.NORMAL, Difficulty.Level.FACIL]:
		await _repite_en(t, lvl)
	await t.back_to_menu()


func _repite_en(t: Node, lvl: int) -> void:
	var dif := Difficulty.id(lvl).to_upper()
	var agent := "Llauri"
	await t.start_shift(agent, 3, 0, lvl)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	var cm := _cm(t)
	var modo := Checkpoints.checkpoint_mode()
	t.check(modo == ["contacto", "dos_contactos", "login_break_lunch"][lvl], "%s: checkpoints «%s»" % [dif, modo])
	var st := {}
	# Difícil: tramo largo (del login a las 03:55, con los guiones opcionales que toquen). Normal y Fácil: el tramo es
	# corto por construcción (checkpoint cada dos contactos / cada contacto); sin los dos opcionales de las 02:25 y
	# 02:40 la cuenta es fija: Normal muere con el chat de las 03:30 A MEDIAS (checkpoint: el correo de la 01:20);
	# Fácil muere libre a las 03:00 (checkpoint: ese mismo correo).
	var muere_a := _hms(3, 0) if lvl == Difficulty.Level.FACIL else _hms(3, 55)
	if lvl != Difficulty.Level.DIFICIL:
		for id in ["t3c10", "t3c4"]:
			if not (cm.get("_served") as Array).has(id):
				(cm.get("_served") as Array).append(id)
		Checkpoints.save_checkpoint("login")
	# --- Primera vez ---
	var log1: Array = []
	await _juega(t, cm, muere_a, log1, st, _hms(3, 25) if lvl == Difficulty.Level.NORMAL else -1.0)
	var cp := _cp_clock()
	# El tramo que se compara: del checkpoint a la muerte (y como poco una hora de juego: reaparecer ya gasta lo suyo).
	var d1 := maxf(GameState.clock_seconds if lvl != Difficulty.Level.NORMAL else muere_a, cp + 3600.0)
	var horas := (d1 - cp) / 3600.0
	var tramo1 := _desde(log1, cp)
	var n1 := tramo1.size()
	var resueltos: Array[String] = []
	var a_medias := ""
	for e in tramo1:
		if not bool(e.get("relleno", false)):
			if bool(e.get("fin", false)):
				resueltos.append(str(e.get("id", "")))
			else:
				a_medias = str(e.get("id", ""))
	var handled1 := Metrics.contacts_handled
	t.note("%s primera vez: %d contactos en el turno, %d desde el checkpoint de las %s hasta las %s (%.1f/h de juego) · %s" % [dif, log1.size(), n1, GameState.clock_text_at(cp), GameState.clock_text_at(d1), float(n1) / horas, str(_ids(tramo1))])
	t.check(n1 >= (4 if lvl == Difficulty.Level.DIFICIL else 1) and log1.size() >= 3, "%s: en la primera vez entraron contactos (%d; %d en el tramo que se repite)" % [dif, log1.size(), n1])
	if lvl == Difficulty.Level.NORMAL:
		t.check(a_medias != "" and cm.phase == ContactManager.Phase.ACTIVE, "NORMAL: mueres con un guion a medias (%s)" % a_medias)
	# --- Muerte 1: repetir el tramo ---
	t.check(await _muere_y_vuelve(t), "%s: muere y reaparece" % dif)
	t.check(absf(GameState.clock_seconds - cp) < 900.0, "%s: el reloj vuelve al checkpoint (%s)" % [dif, GameState.clock_text()])
	t.check(Metrics.contacts_handled == handled1, "%s: lo que atendiste sigue atendido (%d contactos, antes el checkpoint se los llevaba)" % [dif, Metrics.contacts_handled])
	var busy_ok := true
	for n in cm.acd.coworkers():
		busy_ok = busy_ok and float(cm.acd.npc_busy_until.get(n, -INF)) <= GameState.clock_seconds + 8.0 * 60.0 + 1.0
	t.check(busy_ok and cm.acd.ambient.size() <= 3, "%s: la cola rebobinó con el reloj (ningún compañero «en contacto» hasta la hora de la muerte; ambiente %d)" % [dif, cm.acd.ambient.size()])
	var huecos := cm.slots_pending()
	t.check(huecos == n1 - (1 if a_medias != "" else 0), "%s: cada contacto atendido del tramo dejó un hueco (%d de %d)" % [dif, huecos, n1])
	var log2: Array = []
	await _juega(t, cm, d1, log2, st)
	var n2 := log2.size()
	t.note("%s segunda vez: %d contactos (%.1f/h) · %s" % [dif, n2, float(n2) / horas, str(_ids(log2))])
	t.check(_en_banda(n1, n2), "%s: contactos por hora de juego al repetir dentro de la banda 0,7-1,4 de la primera vez (%.1f/h → %.1f/h)" % [dif, float(n1) / horas, float(n2) / horas])
	var vueltos: Array[String] = []
	for id in _ids(log2):
		if resueltos.has(id):
			vueltos.append(id)
	t.check(vueltos.is_empty(), "%s: ningún guion ya resuelto vuelve a llamar %s" % [dif, str(vueltos)])
	if a_medias != "":
		t.check(_ids(log2).has(a_medias), "%s: el guion que estaba a medias sí vuelve (%s)" % [dif, a_medias])
	var subs := 0
	var fin2 := 0
	for e in log2:
		subs += 1 if bool(e.get("sustituto", false)) else 0
		fin2 += 1 if bool(e.get("fin", false)) else 0
	t.check(subs == huecos, "%s: en los huecos entraron sustitutos (%d de %d)" % [dif, subs, huecos])
	t.check(Metrics.contacts_handled == handled1 + fin2, "%s: nada contado dos veces (%d = %d + %d)" % [dif, Metrics.contacts_handled, handled1, fin2])
	t.check(_seguidos(log1 + log2) == "", "%s: nunca el mismo cliente dos veces seguidas %s" % [dif, _seguidos(log1 + log2)])
	# --- Muerte 2: otra vez ---
	var cp2 := _cp_clock()
	var d2 := maxf(GameState.clock_seconds, cp2 + 3600.0)
	var tramo2 := _desde(log2, cp2)
	var handled2 := Metrics.contacts_handled
	t.check(await _muere_y_vuelve(t), "%s: segunda muerte" % dif)
	t.check(Metrics.contacts_handled == handled2, "%s: tras la segunda muerte lo atendido sigue atendido (%d)" % [dif, Metrics.contacts_handled])
	var log3: Array = []
	await _juega(t, cm, d2, log3, st)
	t.note("%s tercera vez: %d contactos (segunda vez en ese tramo: %d) · %s" % [dif, log3.size(), tramo2.size(), str(_ids(log3))])
	t.check(_en_banda(tramo2.size(), log3.size()), "%s: tercera vez, dentro de la banda de la segunda (%d → %d)" % [dif, tramo2.size(), log3.size()])
	vueltos.clear()
	for id in _ids(log3):
		if resueltos.has(id) or (a_medias != "" and id == a_medias):
			vueltos.append(id)
	t.check(vueltos.is_empty() and _seguidos(log2 + log3) == "", "%s: tercera vez sin guiones repetidos %s ni el mismo cliente seguido" % [dif, str(vueltos)])
	t.check(float(st.get("libre", 0.0)) <= 20.0, "%s: con gente esperando y tú libre en Available, lo más que tardó en entrar un contacto: %.1f s reales" % [dif, float(st.get("libre", 0.0))])
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 2, "%s: solo las dos muertes buscadas (%d)" % [dif, Checkpoints.deaths_this_shift])
	if lvl != Difficulty.Level.DIFICIL:
		return
	# --- «Continuar» (Difícil: el checkpoint es el del login) ---
	var handled3 := Metrics.contacts_handled
	var atendidos: Array = (cm.get("_attended") as Dictionary).keys()
	await t.back_to_menu()
	SaveSlots.select(agent)
	t.main.call("_continue_shift")
	await t.frames(6)
	var cm2 := _cm(t)
	_solo_cola(t)
	GameState.stop_calm()
	t.check(cm2 != cm and GameState.running and absf(GameState.clock_seconds - cp2) < 900.0, "DIFICIL · Continuar: retoma en el checkpoint (%s)" % GameState.clock_text())
	var falta: Array[String] = []
	for id in atendidos:
		if not (cm2.get("_served") as Array).has(str(id)):
			falta.append(str(id))
	t.check(falta.is_empty() and not atendidos.is_empty(), "DIFICIL · Continuar: los %d guiones que atendiste siguen atendidos %s (antes, en Difícil, volvían todos desde el primero)" % [atendidos.size(), str(falta)])
	t.check(Metrics.contacts_handled == handled3, "DIFICIL · Continuar: lo atendido sigue contado (%d)" % Metrics.contacts_handled)
	t.check(cm2.slots_pending() >= tramo2.size(), "DIFICIL · Continuar: los huecos del tramo siguen ahí (%d)" % cm2.slots_pending())
	var log4: Array = []
	await _juega(t, cm2, d2, log4, st)
	t.note("DIFICIL tras Continuar: %d contactos · %s" % [log4.size(), str(_ids(log4))])
	vueltos.clear()
	for id in _ids(log4):
		if atendidos.has(id):
			vueltos.append(id)
	t.check(_en_banda(tramo2.size(), log4.size()) and vueltos.is_empty(), "DIFICIL · Continuar: el tramo vuelve con la misma carga (%d → %d) y sin guiones repetidos %s" % [tramo2.size(), log4.size(), str(vueltos)])


func _cola_no_para(t: Node) -> void:
	# --- A. La cola rebobina con el reloj ---
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED  # aquí solo se mira el ACD (hijo de la cola: se procesa a mano)
	await t.set_clock(_hms(2, 0))
	Checkpoints.save_checkpoint("aux")
	var extra: Dictionary = Checkpoints.last_checkpoint.get("extra", {})
	t.check(extra.has("cm_served") and extra.has("cm_acd") and extra.has("cm_slots"), "todo checkpoint guarda la cola (el de AUX también: %s)" % str(extra.keys()))
	var amb0 := cm.acd.ambient.size()
	await t.set_clock(_hms(4, 30))
	for i in 5:
		cm.acd.ambient.append(_hms(4, 0) + 60.0 * i)
	for n in cm.acd.coworkers():
		cm.acd.npc_busy_until[n] = _hms(4, 36)
	cm.acd.taken_by_npc["t1c9"] = cm.acd.coworkers()[0]
	(cm.get("_served") as Array).append("t1c9")
	t.check(await _muere_y_vuelve(t), "muere a las 04:30 y reaparece en el checkpoint de las 02:00")
	var late := 0
	for n in cm.acd.coworkers():
		late += 1 if float(cm.acd.npc_busy_until.get(n, -INF)) > GameState.clock_seconds + 8.0 * 60.0 + 1.0 else 0
	var futuro := 0
	for a in cm.acd.ambient:
		futuro += 1 if a > GameState.clock_seconds + 1.0 else 0
	t.check(late == 0, "ningún compañero queda «en un contacto» hasta la hora de la muerte (antes: 2 h y media sin que nadie atendiera → «Cola 21»)")
	t.check(futuro == 0 and cm.acd.ambient.size() == amb0, "el ambiente de la cola vuelve al del checkpoint (%d; sin llegadas «del futuro»)" % cm.acd.ambient.size())
	t.check(not cm.acd.taken_by_npc.has("t1c9") and not (cm.get("_served") as Array).has("t1c9"), "el guion que un compañero tomó después del checkpoint vuelve a estar pendiente")
	await t.back_to_menu()
	# --- B. Con gente esperando te sigue entrando, aunque el cupo del turno esté servido ---
	await t.start_shift("Juan", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	cm = _cm(t)
	for c in cm.get("_schedule"):
		(cm.get("_served") as Array).append(str(c.get("id", "")))  # sin guiones: solo la cola
	await t.set_clock(_hms(5, 0))
	cm.filler_quota = 0
	var now := GameState.clock_seconds
	for n in cm.acd.coworkers():
		(cm.acd.get("_sched") as Dictionary)[n] = [[now - 60.0, now + 4.0 * 3600.0, "lunch"]]
	cm.acd.ambient.clear()
	cm.acd.ambient.append(now)
	cm.acd.ambient.append(now + 1.0)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	var offers: Array = t.spy("contact_offered")
	var max_wait := float((DataLoader.bal("cola_acd/espera_max_min_juego", [40.0, 30.0, 20.0]) as Array)[1]) * 60.0
	var ok: bool = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 40.0)
	var waited := GameState.clock_seconds - now
	t.check(ok and bool(cm.current.get("desborde", false)) and cm.overflow_count == 1, "cupo de relleno servido, nadie atiende y 2 esperando: te entra uno (antes: nada, con «Cola 2» en el HUD) [%s]" % str(cm.current.get("id", "")))
	t.check(waited >= max_wait and waited <= max_wait + 45.0 * 60.0, "entra cuando el más antiguo lleva esperando más de %d min de juego (esperó %d)" % [int(max_wait / 60.0), int(waited / 60.0)])
	cm.accept()
	await t.frames(2)
	_cierra_contacto(cm)
	ok = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 40.0)
	t.check(ok and cm.overflow_count == 2 and str(offers[1][0].get("ref_id", "")) != str(offers[0][0].get("ref_id", "?")), "y después el siguiente, que es otro cliente (%s → %s)" % [str(offers[0][0].get("id", "")), str(offers[1][0].get("id", "")) if offers.size() > 1 else "-"])
	cm.accept()
	await t.frames(2)
	_cierra_contacto(cm)
	# Con un compañero libre el ambiente no espera: a ti no te entra nada de más.
	for n in cm.acd.coworkers():
		(cm.acd.get("_sched") as Dictionary)[n] = []
	var n_off := offers.size()
	await t.seconds(14.0)
	t.check(offers.size() == n_off and cm.acd.ambient.size() <= 1, "con compañeros libres la cola se atiende sola y no te entra nada de más (cola %d)" % cm.acd.size())
	await t.back_to_menu()
	# --- C. La bolsa de relleno no se acaba ---
	await t.start_shift("Juan", 3, 0, Difficulty.Level.NORMAL)
	cm = _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	var own := (cm.call("_fillers") as Array).size()
	var total := cm.pool_size()
	t.check(total > own and own >= 6, "miércoles: %d árboles de relleno propios y %d en la bolsa ampliada (con los del martes y el lunes)" % [own, total])
	var seen := {}
	var prestados := 0
	var sin_voz: Array[String] = []
	var last := ""
	var seguido := false
	for i in total:
		var f: Dictionary = cm.call("_filler")
		var base := str(f.get("ref_id", ""))
		seen[base] = true
		seguido = seguido or base == last
		last = base
		if bool(f.get("prestado", false)):
			prestados += 1
			if (f.get("_arq_cfg", {}) as Dictionary).is_empty():
				sin_voz.append(base + " (sin arquetipo)")
			for nd in (f.get("nodos", {}) as Dictionary).values():
				var a := str((nd as Dictionary).get("audio", ""))
				if a != "" and str(f.get("canal", "")) == "llamada" and not ResourceLoader.exists("res://assets/audio/" + a):
					sin_voz.append(a)
		elif i >= own:
			sin_voz.append(base + " (propio fuera de sitio)")
	t.check(seen.size() == total and prestados == total - own and not seguido, "una vuelta entera a la bolsa: %d clientes distintos, primero los %d del turno y luego %d prestados" % [seen.size(), own, prestados])
	t.check(sin_voz.is_empty(), "los prestados traen su arquetipo y su voz grabada %s" % str(sin_voz.slice(0, 4)))
	var rep1: Dictionary = cm.call("_filler")
	var rep2: Dictionary = cm.call("_filler")
	var orig: Dictionary = {}
	for f in cm.call("_fillers"):
		if str((f as Dictionary).get("id", "")) == str(rep1.get("ref_id", "")):
			orig = f
	t.check(str(rep1.get("id", "")).ends_with("_2") and int(rep1.get("repetido", 0)) == 1 and str(rep1.get("ref_id", "")) != last and str(rep2.get("ref_id", "")) != str(rep1.get("ref_id", "")), "agotada la bolsa empieza otra vuelta (%s), nunca con el que acaba de salir (%s)" % [str(rep1.get("id", "")), last])
	t.check(not orig.is_empty() and not is_equal_approx(float(rep1.get("animo_inicial", 0.0)), float(orig.get("animo_inicial", 0.0))), "y el cliente que repite llega de otro humor (%s → %s)" % [str(orig.get("animo_inicial", 0)), str(rep1.get("animo_inicial", 0))])
	await t.back_to_menu()
	await t.start_shift("Juan", 1)
	cm = _cm(t)
	t.check(cm.pool_size() == (cm.call("_fillers") as Array).size(), "el lunes no toma prestado de turnos posteriores (%d)" % cm.pool_size())
	await t.back_to_menu()
	# --- D. «Reiniciar contacto» (Fácil: checkpoint en cada contacto) ---
	await t.start_shift("Juan", 1, 0, Difficulty.Level.FACIL)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	cm = _cm(t)
	ok = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 40.0)
	var x := str(cm.current.get("id", ""))
	cm.accept()
	await t.frames(2)
	t.check(ok and x != "" and cm.phase == ContactManager.Phase.ACTIVE and str(Checkpoints.last_checkpoint.get("kind", "")) == "contacto", "Fácil: contesta %s y se guarda el checkpoint del contacto" % x)
	t.check(Checkpoints.restart_contact(), "«Reiniciar contacto» con el contacto a medias")
	await t.frames(2)
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	t.check(cm.phase == ContactManager.Phase.IDLE and not (cm.get("_served") as Array).has(x) and cm.slots_pending() == 0, "el contacto a medias vuelve a estar pendiente (sin sustituto)")
	ok = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 40.0)
	t.check(ok and str(cm.current.get("id", "")) == x, "y vuelve a sonar el mismo (%s)" % str(cm.current.get("id", "")))
	var h0 := Metrics.contacts_handled
	cm.accept()
	await t.frames(2)
	_cierra_contacto(cm)
	t.check(Metrics.contacts_handled == h0 + 1, "lo cierras: 1 contacto atendido")
	t.check(Checkpoints.restart_contact(), "«Reiniciar contacto» con el contacto ya cerrado")
	await t.frames(2)
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	t.check(Metrics.contacts_handled == h0 + 1 and (cm.get("_served") as Array).has(x) and cm.slots_pending() == 1, "lo cerrado sigue cerrado y contado (antes desaparecía de las métricas) y en su lugar espera un sustituto [%d, %d]" % [Metrics.contacts_handled, cm.slots_pending()])
	ok = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 40.0)
	t.check(ok and bool(cm.current.get("sustituto", false)) and str(cm.current.get("id", "")) != x, "y entra el sustituto, que es otro cliente (%s)" % str(cm.current.get("id", "")))
	await t.back_to_menu()
	# --- E. «Continuar» con un checkpoint de una versión anterior (sin la cola guardada) ---
	await t.start_shift("Juan", 1, 0, Difficulty.Level.DIFICIL)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	cm = _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.set_clock(_hms(2, 30))
	Checkpoints.save_checkpoint("lunch")
	var viejo: Dictionary = Checkpoints.last_checkpoint.duplicate(true)
	viejo["extra"] = {}  # como lo guardaba la v0.3.2-core en Difícil
	SaveSlots.write_checkpoint(GameState.agent, viejo)
	await t.back_to_menu()
	SaveSlots.select("Juan")
	t.main.call("_continue_shift")
	await t.frames(6)
	cm = _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	t.check((Checkpoints.last_checkpoint.get("extra", {}) as Dictionary).has("cm_served"), "y el checkpoint viejo pasa a guardar la cola")
	var pasados := 0
	var sin_marcar: Array[String] = []
	for c in cm.get("_schedule"):
		if ContactManager.clock_of(str(c.get("hora_juego", "00:00"))) < _hms(2, 29):
			pasados += 1
			if not (cm.get("_served") as Array).has(str(c.get("id", ""))):
				sin_marcar.append(str(c.get("id", "")))
	var nxt: Dictionary = cm.next_scripted()
	t.check(pasados >= 4 and sin_marcar.is_empty() and ContactManager.clock_of(str(nxt.get("hora_juego", "00:00"))) >= _hms(2, 29), "checkpoint viejo sin la cola: los %d guiones de antes de las 02:30 no vuelven a sonar %s; el siguiente es %s" % [pasados, str(sin_marcar), str(nxt.get("id", ""))])
	await t.back_to_menu()


# ----------------------------------------------------------------------------------------------------------------
# v0.3.2-core3 · Reaparecer sin bucle de Fatiga. El integrador lo encontró con el bot humano (T3, Difícil): checkpoint
# del lunch con Fatiga 66, Haime mata a las 7:08, reapareces con 81 (66 + 15), el tramo hasta las 8:00 sube 20 y te
# desplomas; reapareces con 60, el tramo (ya con la cola llena, core2) sube 35-40 y te desplomas otra vez, y otra.

func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## Cierra el contacto en curso con el resultado que se le dice (sin pasar por el árbol: _cierra_contacto toma el
## primer final que haya, y en los árboles sin final «satisfecho» ese es «molesto»: aquí cada molesto cuenta).
func _cierra_como(cm: ContactManager, angry: bool) -> void:
	Metrics.angry_streak.clear()  # aquí se mira la Fatiga, no la racha de molestos (esa es de Discipline)
	if cm.phase != ContactManager.Phase.ACTIVE:
		return
	if angry:
		cm.call("_finish", cm.current, false, true, "molesto", 1)
	elif cm.tree != null:
		cm.call("_finish", cm.current, true, false, "satisfecho", 5)
	else:
		cm.call("_finish", cm.current, true, false, "bo_ok", 0)


func _suma_fatiga(st: Dictionary, last: float) -> float:
	if Fatigue.value > last:
		st["sube"] = float(st.get("sube", 0.0)) + Fatigue.value - last
	st["max"] = maxf(float(st.get("max", 0.0)), Fatigue.value)
	return Fatigue.value


## Juega sentado en Available hasta `until` con la Fatiga DE VERDAD (cada hora suma, cada cliente molesto suma):
## contesta lo que suena y lo cierra (5 min de juego por contacto). De los contactos que la primera vez existían
## (guiones, relleno, sustitutos) uno de cada `cada` sale molesto (0 = ninguno); los contactos «de más» de un tramo
## repetido salen TODOS molestos (no deben cansar). st: n, reales, molestos, demas, demas_sube (Fatiga que subieron
## los «de más»), sube (todo lo que subió la Fatiga), max; st["tope_molestos"] (opcional) = como mucho tantos molestos.
## Aquí se mira la Fatiga: los WW que traiga el mal trato se acusan y no llegan a tres, y el chat no vence solo.
func _juega_cansado(t: Node, cm: ContactManager, until: float, cada: int, st: Dictionary) -> void:
	var guard := 0
	var last := Fatigue.value
	while GameState.clock_seconds < until and not Checkpoints.dying and not GameState.shift_over and guard < 90000:
		guard += 1
		await t.frames(1)
		last = _suma_fatiga(st, last)
		if Metrics.ack_pending:
			Metrics.give_ack()
		if Metrics.written_warnings >= 2:
			Metrics.written_warnings = 1
		if Metrics.aux != Metrics.Aux.AVAILABLE and not Metrics.reconnecting:
			Metrics.set_aux(Metrics.Aux.AVAILABLE)
		if cm.phase != ContactManager.Phase.OFFERING:
			continue
		var extra := bool(cm.current.get("de_mas", false))
		cm.accept()
		if cm.phase != ContactManager.Phase.ACTIVE:
			continue
		cm.set("_suspend_chat", true)  # el chat no vence solo con el salto de reloj (saldría molesto por su cuenta)
		await t.frames(2)
		GameState.add_game_time(300.0)
		await t.frames(1)
		cm.set("_suspend_chat", false)
		if Checkpoints.dying:
			break
		last = _suma_fatiga(st, last)
		st["n"] = int(st.get("n", 0)) + 1
		var angry := extra
		if extra:
			st["demas"] = int(st.get("demas", 0)) + 1
		else:
			st["reales"] = int(st.get("reales", 0)) + 1
			angry = cada > 0 and int(st["reales"]) % cada == 0 and int(st.get("molestos_reales", 0)) < int(st.get("tope_molestos", 999))
			if angry:
				st["molestos_reales"] = int(st.get("molestos_reales", 0)) + 1
		_cierra_como(cm, angry)
		await t.frames(1)
		if angry:
			st["molestos"] = int(st.get("molestos", 0)) + 1
			if extra:
				st["demas_sube"] = float(st.get("demas_sube", 0.0)) + maxf(Fatigue.value - last, 0.0)
		last = _suma_fatiga(st, last)


## Los KYC del guion solo entran en BO (los trae la allocation del Mentor, que estas pruebas apagan). Pendientes, no
## dejan entrar relleno a su ritmo (_filler_allowed espera al guion pendiente): se dan por servidos.
func _sin_kyc(cm: ContactManager) -> void:
	for c in (cm.get("_schedule") as Array):
		var id := str((c as Dictionary).get("id", ""))
		if str((c as Dictionary).get("canal", "")) == "kyc" and not (cm.get("_served") as Array).has(id):
			(cm.get("_served") as Array).append(id)


## Contactos que atendiste hasta el final desde el checkpoint vivo.
func _vida_hecha(cm: ContactManager) -> int:
	var n := 0
	for e in (cm.get("_life") as Array):
		n += 1 if bool((e as Dictionary).get("fin", false)) else 0
	return n


## El reloj corre hasta `until` sin que entre nada (de a 10 min de juego, para que cada hora dé su aviso).
func _pasa_reloj(t: Node, until: float) -> void:
	while GameState.clock_seconds < until - 1.0 and not Checkpoints.dying and not GameState.shift_over:
		await t.advance_clock(minf(600.0, until - GameState.clock_seconds))
		await t.frames(1)


## El lunch como quien juega: el RTA lo dicta a su hora, eliges Lunch, y a los 8 min comes el taper con la Fatiga
## `f_antes` (ahí se guarda el checkpoint «lunch», con la Fatiga ya bajada).
func _lunch_checkpoint(t: Node, f_antes: float) -> void:
	PerritoRTA.dictate(Metrics.Aux.AVAILABLE)  # a la hora del lunch se lee como Lunch (RtaControl.pending_order)
	GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
	Metrics.set_aux(Metrics.Aux.LUNCH)
	Checkpoints.on_aux_picked(Metrics.Aux.LUNCH)
	await t.advance_clock(8.0 * 60.0)
	Fatigue.set_value(f_antes)
	WorldObjects.TaperFlow.eat(t.player())
	await t.frames(2)


func _modo_muerte(t: Node) -> String:
	var l := t.death_screen().get("_mode") as Label
	return l.text if l != null else ""


func _msg_con(msgs: Array, needle: String) -> bool:
	for m in msgs:
		if str((m as Array)[0]).contains(needle):
			return true
	return false


func _etiqueta_con(root: Node, needle: String) -> bool:
	for l in root.find_children("*", "Label", true, false):
		if not (l as Node).is_queued_for_deletion() and str((l as Label).text).contains(needle):
			return true
	return false


func _aviso_con(needle: String) -> bool:
	if str(VoiceDirector.notice_current.get("text", "")).contains(needle):
		return true
	for n in VoiceDirector.notices:
		if str((n as Dictionary).get("text", "")).contains(needle):
			return true
	for row in VoiceDirector.notice_log:
		if str(row[2]).contains(needle):
			return true
	return false


## Colapso de verdad (cruza 100 con add). Devuelve si salió la pantalla de muerte por colapso.
func _colapsa(t: Node) -> bool:
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	Fatigue.set_value(99.0)
	Fatigue.add(5.0, true)
	await t.frames(1)
	var ok: bool = Checkpoints.dying and Checkpoints.death_cause == "colapso"
	var shown: bool = await t.wait_death_shown(20.0)
	return ok and shown


func _mata(t: Node, cause: String, killer: String) -> bool:
	await t.until(func() -> bool: return Checkpoints.can_die(), 10.0)
	await t.die(cause, "", killer)
	return await t.wait_death_shown(20.0)


func _cp_saldo() -> float:
	return float((Checkpoints.last_checkpoint.get("economy", {}) as Dictionary).get("saldo", -1.0))


func _sin_bucle(t: Node) -> void:
	for lvl in [Difficulty.Level.DIFICIL, Difficulty.Level.NORMAL, Difficulty.Level.FACIL]:
		await _sin_bucle_en(t, lvl)
	await t.back_to_menu()


func _sin_bucle_en(t: Node, lvl: int) -> void:
	var dif := Difficulty.id(lvl).to_upper()
	await t.start_shift("Juan", 3, 0, lvl)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	var cm := _cm(t)
	_sin_kyc(cm)
	var guardados: Array = t.spy("checkpoint_saved")
	var msgs: Array = t.spy("show_message")
	var lunch := Metrics.Aux.LUNCH
	var por_molesto := float(DataLoader.bal("fatiga/por_molesto", 8.0)) * Difficulty.fatigue_rate("ganancia")
	# --- Primera vez: se juega con la Fatiga de verdad, un cliente molesto de cada tres (en el tramo largo de Difícil,
	# como mucho dos: con tres el propio tramo ya acaba en colapso y aquí se mira el que te maten, no eso) ---
	var st0 := {}
	var st1 := {"tope_molestos": 2}
	if lvl == Difficulty.Level.DIFICIL:
		await _juega_cansado(t, cm, GameState.lunch_clock(), 3, st0)
		await t.until(func() -> bool: return cm.phase == ContactManager.Phase.IDLE, 20.0)
		await _lunch_checkpoint(t, 68.0)
		t.check(str(Checkpoints.last_checkpoint.get("kind", "")) == "lunch", "DIFICIL: checkpoint del lunch al comer el taper (%s)" % GameState.clock_text())
		await _pasa_reloj(t, _cp_clock() + 32.0 * 60.0)  # lo que queda del lunch
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await _juega_cansado(t, cm, _hms(7, 10), 3, st1)
	else:
		GameState.flags["p5_lunch_hecho"] = true  # en Normal y Fácil aquí no se mira el lunch
		await _juega_cansado(t, cm, _hms(5, 30), 3, st0)
		await t.until(func() -> bool: return cm.phase == ContactManager.Phase.IDLE, 20.0)
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 0, "%s: la primera vez llega vivo al final del tramo (Fatiga %.0f, máxima %.0f)" % [dif, Fatigue.value, maxf(float(st0.get("max", 0.0)), float(st1.get("max", 0.0)))])
	var cp := Checkpoints.last_checkpoint
	var cp_f := float(cp.get("fatigue", -1.0))
	var cp_clock := _cp_clock()
	var cp_saldo := _cp_saldo()
	var cp_breaks := int((cp.get("metrics", {}) as Dictionary).get("breaks_used", -1))
	var cp_topico := int(((cp.get("discipline", {}) as Dictionary).get("counters", {}) as Dictionary).get("p5_topico_pedidos", 0))
	var f1 := Fatigue.value
	var d1 := GameState.clock_seconds
	var n_cp := guardados.size()
	var reales1 := _vida_hecha(cm)
	t.note("%s primera vez: checkpoint «%s» de las %s con Fatiga %.0f · a las %s llevas Fatiga %.0f (%d contactos desde el lunch o el login, %d molestos)" % [dif, str(cp.get("kind", "")), GameState.clock_text_at(cp_clock), cp_f, GameState.clock_text(), f1, int(st1.get("n", st0.get("n", 0))), int(st1.get("molestos", st0.get("molestos", 0)))])
	t.check(cp_f >= 0.0 and cp_saldo >= 0.0 and d1 - cp_clock >= 240.0, "%s: te matan tarde en el tramo (%.0f min de juego después del checkpoint; el checkpoint guarda Fatiga y saldo)" % [dif, (d1 - cp_clock) / 60.0])
	# Después del checkpoint gastaste: un café (vuelve el dinero y su descanso se va con el reloj).
	t.check(Economy.buy("cafe", 2.5, "expendedora") and absf(Economy.saldo - (cp_saldo - 2.5)) < 0.005, "%s: compras un café después del checkpoint (saldo %s)" % [dif, Economy.soles(Economy.saldo)])
	# --- Te matan (no es un colapso) ---
	t.check(await _mata(t, "calibracion_final", "haime"), "%s: Haime te mata a las %s" % [dif, GameState.clock_text_at(d1)])
	var modo := _modo_muerte(t)
	t.check(modo == _tr("CORE3_DEATH_MODE") and not modo.contains("15"), "%s: la pantalla de muerte ya no dice «Fatiga +15» («%s»)" % [dif, modo])
	await t.reconnect()
	GameState.stop_calm()
	n_cp = guardados.size()  # los checkpoints que se guarden desde aquí son «el siguiente»
	t.check(absf(Fatigue.value - cp_f) < 0.01, "%s: reapareces con la Fatiga del checkpoint, ni un punto más (%.0f; el checkpoint %.0f; con la regla de antes %.0f)" % [dif, Fatigue.value, cp_f, minf(cp_f + 15.0, 85.0)])
	t.check(absf(Economy.saldo - cp_saldo) < 0.005, "%s: el saldo vuelve al del checkpoint (%s): el café de después se devuelve" % [dif, Economy.soles(Economy.saldo)])
	t.check(Metrics.breaks_used == cp_breaks and int(PersonajesP5.counter("p5_topico_pedidos", 0)) == cp_topico, "%s: breaks (%d) y tópico (%d) como en el checkpoint" % [dif, Metrics.breaks_used, int(PersonajesP5.counter("p5_topico_pedidos", 0))])
	t.check(Checkpoints.deaths_from_checkpoint() == 1 and not _aviso_con("Fatiga"), "%s: primera muerte desde ese checkpoint (%d): sin aviso de Fatiga (no cambió)" % [dif, Checkpoints.deaths_from_checkpoint()])
	if lvl == Difficulty.Level.DIFICIL:
		# El checkpoint se guardó en pleno lunch: el lunch vuelve a estar ahí y esperado, y el HUD lo dice.
		await t.frames(2)
		var hud_txt := str((t.main.get("hud").get("_aux") as Label).text)
		t.check(Metrics.reconnecting and Metrics.aux == lunch and Metrics.expected_aux == lunch and RtaControl.lunch_taken(), "DIFICIL: reapareces en «Reconectando» con el Lunch del checkpoint puesto y esperado (AUX %s, esperado %s)" % [Metrics.aux_name(Metrics.aux), Metrics.aux_name(Metrics.expected_aux)])
		t.check(Reconexion.resume_aux == lunch and Reconexion.resume_left_s > 30.0 * 60.0, "DIFICIL: te quedaban %.0f min de Lunch" % (Reconexion.resume_left_s / 60.0))
		t.check(hud_txt == Reconexion.hud_text() and hud_txt.contains(Metrics.aux_name(lunch)) and hud_txt.contains("[%d]" % (lunch + 1)), "DIFICIL: el HUD lo dice («%s»)" % hud_txt)
		# Se pasa la cuenta sin elegir: Available, y el juego dice que el lunch sigue ahí.
		var ended: bool = await t.until(func() -> bool: return not Metrics.reconnecting, 15.0)
		var queda := _tr("CORE3_RECON_QUEDA").split("{")[0].strip_edges()
		t.check(ended and Metrics.aux == Metrics.Aux.AVAILABLE and _msg_con(msgs, queda), "DIFICIL: sin elegir pasas a Available y sale el aviso de que te sigue quedando Lunch")
		var hub := PersonajesP5.get_hub(t.get_tree())
		Metrics.set_aux(lunch)
		await t.frames(2)
		t.check(Metrics.aux == lunch and Metrics.quota_left(lunch) > 30.0 * 60.0 and (hub == null or hub.rta == null or hub.rta.wrong_reason() == ""), "DIFICIL: y lo puedes retomar desde el menú de AUX con su cupo (%.0f min) sin que el RTA lo tome por falta" % (Metrics.quota_left(lunch) / 60.0))
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
	else:
		Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	await t.frames(2)
	# --- Repetir el tramo: mismo juego, misma Fatiga como mucho ---
	var st2 := {"tope_molestos": 2}
	await _juega_cansado(t, cm, d1, 3, st2)
	var f2 := Fatigue.value
	# (un guion cuya hora llegó justo cuando te mataron entra al repetir y la primera vez no llegó a entrar: es del
	# turno, no «de más», y si le toca salir molesto suma lo suyo)
	var nuevos := maxi(int(st2.get("reales", 0)) - reales1, 0)
	t.note("%s al repetir: a las %s llevas Fatiga %.0f (la primera vez %.0f) · %d contactos (%d «de más», todos molestos: subieron %.1f) · molestos %d" % [dif, GameState.clock_text(), f2, f1, int(st2.get("n", 0)), int(st2.get("demas", 0)), float(st2.get("demas_sube", 0.0)), int(st2.get("molestos", 0))])
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 1, "%s: repites el tramo sin morir (%d muertes)" % [dif, Checkpoints.deaths_this_shift])
	t.check(f2 <= f1 + float(nuevos) * por_molesto + 0.01, "%s: repetir el tramo no cansa más que la primera vez (Fatiga %.0f → %.0f a la misma hora; contactos que cuentan %d → %d)" % [dif, f1, f2, reales1, int(st2.get("reales", 0))])
	t.check(float(st2.get("demas_sube", 0.0)) < 0.01, "%s: los contactos «de más» del tramo repetido no suman Fatiga aunque salgan molestos (%d, +%.1f)" % [dif, int(st2.get("demas", 0)), float(st2.get("demas_sube", 0.0))])
	t.check(int(st2.get("reales", 0)) <= reales1 + 1, "%s: al repetir no entran más contactos de los que cuentan que la primera vez (%d → %d; como mucho, el guion que estaba al caer)" % [dif, reales1, int(st2.get("reales", 0))])
	# --- Hasta el checkpoint siguiente, sin morir ---
	if lvl == Difficulty.Level.DIFICIL:
		await t.until(func() -> bool: return cm.phase == ContactManager.Phase.IDLE, 20.0)
		GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
		Metrics.set_aux(Metrics.Aux.BREAK)
		Checkpoints.on_aux_picked(Metrics.Aux.BREAK)
		await t.frames(2)
	else:
		var hasta := d1
		while guardados.size() <= n_cp and hasta < d1 + 2.0 * 3600.0 and not Checkpoints.dying:
			hasta += 600.0
			await _juega_cansado(t, cm, hasta, 3, st2)
	t.check(guardados.size() > n_cp and _cp_clock() >= cp_clock, "%s: llegas al checkpoint siguiente («%s» de las %s; el de antes era de las %s)" % [dif, str(Checkpoints.last_checkpoint.get("kind", "")), GameState.clock_text_at(_cp_clock()), GameState.clock_text_at(cp_clock)])
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 1 and Fatigue.value < 100.0, "%s: sin morir otra vez (muertes %d, Fatiga %.0f, a las %s%s)" % [dif, Checkpoints.deaths_this_shift, Fatigue.value, GameState.clock_text(), (" · muriendo de " + Checkpoints.death_cause) if Checkpoints.dying else ""])


func _colapso_sin_bucle(t: Node) -> void:
	var agent := "Jiroshi"
	await t.start_shift(agent, 3, 0, Difficulty.Level.DIFICIL)
	await t.login_at_seat()
	GameState.stop_calm()
	_solo_cola(t)
	var cm := _cm(t)
	_sin_kyc(cm)
	var msgs: Array = t.spy("show_message")
	var lunch := Metrics.Aux.LUNCH
	var cap := Checkpoints.fatigue_cap()
	t.check(is_equal_approx(cap, 45.0), "Difícil: tope de Fatiga tras un colapso %.0f" % cap)
	var st0 := {}
	await _juega_cansado(t, cm, GameState.lunch_clock(), 3, st0)
	await t.until(func() -> bool: return cm.phase == ContactManager.Phase.IDLE, 20.0)
	t.check(not Checkpoints.dying, "llega vivo al lunch (Fatiga %.0f, %d contactos, %d molestos)" % [Fatigue.value, int(st0.get("n", 0)), int(st0.get("molestos", 0))])
	PersonajesP5.set_counter("p5_topico_pedidos", 1)  # ya fue al tópico antes del lunch: en el checkpoint está gastado
	Economy.saldo = 12.0
	await _lunch_checkpoint(t, 78.0)
	var cp_clock := _cp_clock()
	var cp_g := float((Checkpoints.last_checkpoint.get("economy", {}) as Dictionary).get("ganado", -1.0))
	t.check(str(Checkpoints.last_checkpoint.get("kind", "")) == "lunch" and absf(float(Checkpoints.last_checkpoint.get("fatigue", 0.0)) - 66.0) < 0.01, "checkpoint del lunch a las %s con Fatiga %.0f (78 − 20 × 0,6), como en el informe" % [GameState.clock_text_at(cp_clock), float(Checkpoints.last_checkpoint.get("fatigue", 0.0))])
	t.check(Economy.buy("cafe", 2.5, "expendedora"), "después del checkpoint compras un café")
	WorldObjects.apply_purchase("expendedora", {"id": "cafe", "fatiga": -15.0})
	t.check(absf(Economy.saldo - 9.5) < 0.005 and absf(Fatigue.value - 57.0) < 0.01, "café: saldo S/ 9,50 y Fatiga 57 (hay %s y %.0f)" % [Economy.soles(Economy.saldo), Fatigue.value])
	await _pasa_reloj(t, cp_clock + 32.0 * 60.0)
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	await _juega_cansado(t, cm, _hms(7, 8), 0, {})
	# --- 7:08: Haime (la muerte del informe) ---
	t.check(await _mata(t, "calibracion_final", "haime"), "7:08: Haime te mata (calibración final)")
	await t.reconnect()
	GameState.stop_calm()
	t.check(absf(Fatigue.value - 66.0) < 0.01, "reapareces a las %s con Fatiga %.0f = la del checkpoint (antes: 81, y 86 a las 5:00)" % [GameState.clock_text(), Fatigue.value])
	t.check(absf(Economy.saldo - 12.0) < 0.005 and absf(Economy.ganado_turno - cp_g) < 0.005, "el saldo y lo ganado vuelven al checkpoint (%s; ganado %s)" % [Economy.soles(Economy.saldo), Economy.soles(Economy.ganado_turno)])
	t.check(int(PersonajesP5.counter("p5_topico_pedidos", 0)) == 1, "el tópico sigue gastado: en el checkpoint ya lo estaba")
	t.check(Metrics.reconnecting and Metrics.expected_aux == lunch and Reconexion.resume_aux == lunch and Reconexion.hud_text().contains(Metrics.aux_name(lunch)), "AUX esperado Lunch y el HUD dice lo que te quedaba («%s»)" % Reconexion.hud_text())
	var ended: bool = await t.until(func() -> bool: return not Metrics.reconnecting, 15.0)
	t.check(ended and Metrics.aux == Metrics.Aux.AVAILABLE, "sin elegir nada pasas a Available (como el bot del informe)")
	# --- Un contacto «de más»: relleno que entra a su ritmo mientras repites (la primera vez, a esta hora, comías) ---
	t.check(cm.repeating(), "a las %s repites un tramo ya jugado" % GameState.clock_text())
	cm.set("filler_quota", maxi(int(cm.get("filler_quota")), 2))
	(cm.get("_filler_per_block") as Dictionary).clear()
	cm.set("_offer_wait", 0.0)
	cm.set("_min_gap", 0.0)
	var entra: bool = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 20.0)
	var extra_id := str(cm.current.get("id", ""))
	t.check(entra and bool(cm.current.get("de_mas", false)) and bool(cm.current.get("relleno", false)) and not bool(cm.current.get("sustituto", false)) and cm.extra_count >= 1, "entra un relleno a su ritmo y va marcado «de más» (%s)" % extra_id)
	cm.accept()
	await t.frames(2)
	GameState.add_game_time(240.0)
	await t.frames(1)
	var f_extra := Fatigue.value
	var molestos0 := Metrics.angry_total
	_cierra_como(cm, true)
	await t.frames(1)
	t.check(Metrics.angry_total == molestos0 + 1 and absf(Fatigue.value - f_extra) < 0.01, "sale molesto (cuenta como molesto) y no suma Fatiga (%.0f → %.0f): la primera vez ese contacto no existía" % [f_extra, Fatigue.value])
	# --- Repetir sin retomar nada (ni lunch, ni tópico, ni café): con la regla de antes, colapso a las 8:00 ---
	var st2 := {}
	await _juega_cansado(t, cm, _hms(8, 0) + 120.0, 0, st2)
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 1 and absf(Fatigue.value - 86.0) < 0.01, "pasas de las 8:00 vivo, con Fatiga %.0f (66 + 4 horas × 5; antes 81 + 20 → colapso a las 8:00)" % Fatigue.value)
	t.check(absf(Economy.ganado_turno - (cp_g + 4.0 * Economy.hourly_pay())) < 0.01, "las horas del tramo se pagan una vez (ganado %s)" % Economy.soles(Economy.ganado_turno))
	# --- El peor caso: aun así te desplomas. Segunda muerte seguida desde el mismo checkpoint ---
	t.check(await _colapsa(t), "colapso (Fatiga 100)")
	var modo := _modo_muerte(t)
	t.check(modo == Loc.fmt(_tr("CORE3_DEATH_COLLAPSE"), {"n": 45}), "la pantalla dice con qué Fatiga despiertas («%s»)" % modo)
	await t.reconnect()
	GameState.stop_calm()
	var de_extra := 0
	for sl in (cm.get("_slots") as Array):
		de_extra += 1 if str((sl as Dictionary).get("de", "")) == extra_id else 0
	t.check(de_extra == 0 and cm.slots_pending() >= 3, "el contacto «de más» no deja hueco al volver a morir (el tramo no engorda): %d huecos, ninguno suyo" % cm.slots_pending())
	t.check(absf(Fatigue.value - 45.0) < 0.01 and Checkpoints.deaths_from_checkpoint() == 2, "tras el colapso reapareces con Fatiga %.0f = min(66, tope 45) (antes 60) · muertes seguidas desde el checkpoint: %d" % [Fatigue.value, Checkpoints.deaths_from_checkpoint()])
	var ayuda := Loc.fmt(_tr("CORE3_AYUDA"), {"n": 45})
	await t.frames(3)
	t.check(_notice_seen(ayuda), "segunda muerte seguida: sale el aviso de la ayuda («%s»)" % ayuda)
	t.check(int(PersonajesP5.counter("p5_topico_pedidos", 0)) == 0, "la ayuda: el tópico te atiende otra vez (pedidos %d)" % int(PersonajesP5.counter("p5_topico_pedidos", 0)))
	var hub := PersonajesP5.get_hub(t.get_tree())
	t.check(hub == null or hub.topico == null or hub.topico.state == TopicoControl.State.LIBRE, "y el tópico está libre para pedirlo")
	t.check(Economy.courtesy_coffee(), "la ayuda: la máquina te debe un café")
	EventBus.shop_opened.emit("expendedora", "Expendedora", Economy.shop_items("expendedora"))
	await t.frames(2)
	var shop := t.get_tree().get_first_node_in_group("shop_menu")
	t.check(shop != null and _etiqueta_con(shop, _tr("CORE3_CAFE_GRATIS")), "el menú de la expendedora lo dice antes de comprarlo («%s»)" % _tr("CORE3_CAFE_GRATIS"))
	var s0 := Economy.saldo
	var f0 := Fatigue.value
	t.check(shop != null and bool(shop.call("buy_index", 0)) and absf(Economy.saldo - s0) < 0.005 and not Economy.courtesy_coffee() and absf(Fatigue.value - (f0 - 9.0)) < 0.01, "el café de cortesía no se cobra (saldo %s) y descansa (Fatiga %.0f → %.0f); es uno solo" % [Economy.soles(Economy.saldo), f0, Fatigue.value])
	t.check(_msg_con(msgs, _tr("CORE3_CAFE_CORTESIA")), "y un mensaje lo dice al sacarlo («%s»)" % _tr("CORE3_CAFE_CORTESIA"))
	t.check(Economy.buy("cafe", 2.5, "expendedora") and absf(Economy.saldo - (s0 - 2.5)) < 0.005, "el siguiente café ya se paga")
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	Fatigue.set_value(45.0)  # (sin el café: el tramo se juega entero desde el tope)
	# --- Con el tope el tramo se juega entero sin morir, con un cliente molesto de cada tres ---
	var st3 := {}
	await _juega_cansado(t, cm, _hms(8, 40), 3, st3)
	t.note("tramo entero desde el tope: %d contactos (%d molestos, %d «de más») · Fatiga máxima %.0f" % [int(st3.get("n", 0)), int(st3.get("molestos", 0)), int(st3.get("demas", 0)), float(st3.get("max", 0.0))])
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 2 and float(st3.get("max", 0.0)) < 100.0 and int(st3.get("n", 0)) >= 4, "desde el tope el tramo de 4 horas se juega entero sin morir aun con un molesto de cada tres (%d contactos, Fatiga máxima %.0f)" % [int(st3.get("n", 0)), float(st3.get("max", 0.0))])
	# --- Cada muerte seguida más baja el tope (suelo 10); la ayuda no se repite como aviso pero sigue en el tramo ---
	var esperado := [35.0, 25.0, 15.0, 10.0, 10.0]
	var vistos: Array[float] = []
	for i in esperado.size():
		if not await _colapsa(t):
			break
		await t.reconnect()
		GameState.stop_calm()
		vistos.append(Fatigue.value)
		if i == 0:
			await t.frames(3)
			t.check(_notice_seen(Loc.fmt(_tr("CORE3_FATIGA_COLAPSO"), {"n": 35})) and Economy.courtesy_coffee() and int(PersonajesP5.counter("p5_topico_pedidos", 0)) == 0, "tercera muerte: aviso con la Fatiga nueva; el tópico y el café de la ayuda siguen disponibles en el tramo")
		Reconexion.finish(Metrics.Aux.AVAILABLE, true)
		await t.frames(2)
	var iguales := vistos.size() == esperado.size()
	for i in mini(vistos.size(), esperado.size()):
		iguales = iguales and absf(vistos[i] - float(esperado[i])) < 0.01
	t.check(iguales, "cada muerte seguida desde el mismo checkpoint baja el tope 10 puntos hasta el suelo: %s" % str(vistos))
	t.check(absf(float(Checkpoints.last_checkpoint.get("fatigue", 0.0)) - 10.0) < 0.01 and Checkpoints.deaths_from_checkpoint() == 7, "el checkpoint queda como reapareciste (Fatiga %.0f, %d muertes seguidas)" % [float(Checkpoints.last_checkpoint.get("fatigue", 0.0)), Checkpoints.deaths_from_checkpoint()])
	# --- «Continuar» ---
	await t.back_to_menu()
	SaveSlots.select(agent)
	t.main.call("_continue_shift")
	await t.frames(6)
	GameState.stop_calm()
	_solo_cola(t)
	t.check(GameState.running and absf(Fatigue.value - 10.0) < 0.01 and Checkpoints.deaths_from_checkpoint() == 7, "Continuar: no devuelve la Fatiga de antes (%.0f) ni olvida las muertes seguidas (%d)" % [Fatigue.value, Checkpoints.deaths_from_checkpoint()])
	t.check(absf(Economy.saldo - 12.0) < 0.005 and absf(Economy.ganado_turno - cp_g) < 0.005, "Continuar: saldo y ganado del checkpoint (%s, %s)" % [Economy.soles(Economy.saldo), Economy.soles(Economy.ganado_turno)])
	# --- Un checkpoint nuevo empieza la cuenta de cero… salvo el que se guarda nada más reaparecer ---
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	Checkpoints.set("_respawn_grace_left", 0.0)
	await t.frames(2)
	Metrics.set_aux(Metrics.Aux.BREAK)
	Checkpoints.on_aux_picked(Metrics.Aux.BREAK)
	t.check(str(Checkpoints.last_checkpoint.get("kind", "")) == "break" and Checkpoints.deaths_from_checkpoint() == 0, "un checkpoint nuevo (Break) empieza la cuenta de cero (%d)" % Checkpoints.deaths_from_checkpoint())
	t.check(await _mata(t, "abandono", "shero"), "otra muerte, ya desde el checkpoint del break")
	await t.reconnect()
	t.check(Checkpoints.deaths_from_checkpoint() == 1 and Metrics.reconnecting and Reconexion.resume_aux == Metrics.Aux.BREAK, "primera desde ese checkpoint; «Reconectando» ofrece seguir el Break")
	var used := Metrics.breaks_used
	GameState.flags["aux_por_jugador_frame"] = Engine.get_process_frames()
	Metrics.set_aux(Metrics.Aux.BREAK)  # [n] para seguir
	Checkpoints.on_aux_picked(Metrics.Aux.BREAK)
	t.check(Metrics.aux == Metrics.Aux.BREAK and Metrics.breaks_used == used and Checkpoints.deaths_from_checkpoint() == 1, "retomar el Break no gasta otro (%d) y el checkpoint que guarda nada más reaparecer no borra la cuenta (%d)" % [Metrics.breaks_used, Checkpoints.deaths_from_checkpoint()])
	await t.back_to_menu()


func _reaparece_reglas(t: Node) -> void:
	# --- La regla, en tabla, por dificultad ---
	var caps := [40.0, 40.0, 45.0]
	for lvl in [Difficulty.Level.FACIL, Difficulty.Level.NORMAL, Difficulty.Level.DIFICIL]:
		await t.start_shift("Marko", 2, 0, lvl)
		var cap := Checkpoints.fatigue_cap()
		var dif := Difficulty.id(lvl)
		t.check(is_equal_approx(cap, float(caps[lvl])), "%s: tope tras un colapso %.0f" % [dif, cap])
		t.check(is_equal_approx(Checkpoints.respawn_fatigue("abandono", 66.0, 1), 66.0) and is_equal_approx(Checkpoints.respawn_fatigue("abandono", 97.0, 1), 97.0), "%s: una muerte que no es colapso deja la Fatiga del checkpoint" % dif)
		t.check(is_equal_approx(Checkpoints.respawn_fatigue("colapso", 66.0, 1), cap) and is_equal_approx(Checkpoints.respawn_fatigue("colapso", 30.0, 1), 30.0), "%s: colapso → min(checkpoint, %.0f)" % [dif, cap])
		t.check(is_equal_approx(Checkpoints.respawn_fatigue("abandono", 66.0, 2), cap) and is_equal_approx(Checkpoints.respawn_fatigue("abandono", 66.0, 3), cap - 10.0) and is_equal_approx(Checkpoints.respawn_fatigue("colapso", 66.0, 12), 10.0), "%s: segunda muerte seguida → tope; tercera → tope − 10; suelo 10" % dif)
		var nunca_mas := true
		for cp_f in [0.0, 5.0, 12.0, 33.0, 40.0, 45.0, 66.0, 99.0]:
			for cause in ["colapso", "abandono", "calibracion_final"]:
				for n in [1, 2, 3, 4, 9]:
					nunca_mas = nunca_mas and Checkpoints.respawn_fatigue(cause, cp_f, n) <= cp_f + 0.001
		t.check(nunca_mas, "%s: reaparecer nunca da más Fatiga que la del checkpoint (120 combinaciones)" % dif)
		await t.back_to_menu()
	# --- Turno real: columna propia, y sigue reiniciando el turno entero ---
	await t.start_shift("Marko", 2, GameState.Mode.REAL, Difficulty.Level.DIFICIL)
	t.check(is_equal_approx(Checkpoints.fatigue_cap(), 50.0), "Turno real: tope %.0f" % Checkpoints.fatigue_cap())
	await t.login_at_seat()
	var f_inicio := float(GameState.turno_cfg("fatiga_inicio", 25.0))
	Fatigue.set_value(80.0)
	t.check(is_equal_approx(Checkpoints.next_respawn_fatigue("colapso"), f_inicio), "Turno real: la pantalla anunciaría la Fatiga del inicio del turno (%.0f)" % Checkpoints.next_respawn_fatigue("colapso"))
	t.check(await _mata(t, "abandono", "shero"), "Turno real: muerte")
	await t.reconnect()
	t.check(not GameState.logged_in and is_equal_approx(Fatigue.value, f_inicio) and not Metrics.reconnecting, "Turno real: el turno empieza de nuevo (sin sesión, Fatiga %.0f)" % Fatigue.value)
	await t.back_to_menu()
	# --- T1 (sin tópico y sin dinero): colapso y ayuda ---
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	GameState.stop_calm()
	var cm := _cm(t)
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	Fatigue.set_value(90.0)
	GameState.flags["coffee_used"] = true  # ya se tomó el único café del turno
	Checkpoints.save_checkpoint("login")
	t.check(await _colapsa(t), "T1: colapso con Fatiga 90 en el checkpoint")
	t.check(_modo_muerte(t) == Loc.fmt(_tr("CORE3_DEATH_COLLAPSE"), {"n": 40}), "T1: la pantalla dice «Fatiga 40» («%s»)" % _modo_muerte(t))
	await t.reconnect()
	await t.frames(3)
	t.check(is_equal_approx(Fatigue.value, 40.0) and _notice_seen(Loc.fmt(_tr("CORE3_FATIGA_COLAPSO"), {"n": 40})), "T1: despiertas con Fatiga 40 (antes 60) y el aviso lo dice")
	t.check(bool(GameState.flags.get("coffee_used", false)), "T1: a la primera muerte no hay ayuda (el café sigue gastado)")
	Reconexion.finish(Metrics.Aux.AVAILABLE, true)
	GameState.stop_calm()  # (la calma tras reaparecer no deja que Shero mate: aquí se quiere la segunda muerte ya)
	t.check(await _mata(t, "abandono", "shero"), "T1: segunda muerte seguida desde el mismo checkpoint")
	await t.reconnect()
	await t.frames(3)
	t.check(Checkpoints.deaths_from_checkpoint() == 2 and not bool(GameState.flags.get("coffee_used", false)) and not Economy.courtesy_coffee(), "T1: la ayuda devuelve el café del turno (y no deja un café «de cortesía» colgado: en el T1 no se paga)")
	t.check(_notice_seen(Loc.fmt(_tr("CORE3_AYUDA_T1"), {"n": 40})) and not _tr("CORE3_AYUDA_T1").to_lower().contains("tópico"), "T1: el aviso de la ayuda no habla del tópico (está cerrado en el T1)")
	await t.back_to_menu()
	# --- «Reiniciar contacto» no devuelve lo comprado (ni cambia la Fatiga, ni cuenta como muerte) ---
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	Economy.saldo = 12.0
	Fatigue.set_value(50.0)
	Checkpoints.save_checkpoint("login")
	t.check(Economy.buy("cafe", 2.5, "expendedora"), "T2: compras un café después del checkpoint")
	WorldObjects.apply_purchase("expendedora", {"id": "cafe", "fatiga": -15.0})
	var f_cafe := Fatigue.value
	await t.advance_clock(300.0)
	t.check(Checkpoints.restart_contact(), "«Reiniciar contacto»")
	await t.frames(2)
	t.check(absf(Economy.saldo - 9.5) < 0.005 and is_equal_approx(Fatigue.value, f_cafe) and Checkpoints.deaths_from_checkpoint() == 0, "«Reiniciar contacto»: el café sigue pagado (%s), la Fatiga no cambia (%.1f) y no cuenta como muerte" % [Economy.soles(Economy.saldo), Fatigue.value])
	await t.back_to_menu()
	# --- El tercer break (la falta que mata) no guarda checkpoint: no reapareces dentro del break prohibido ---
	# (lo encontró el bot humano al elegir el AUX como en el menú de la PC: tercer break → checkpoint con la falta ya
	# hecha → reaparece en el break prohibido → otro break → otra muerte, y otra)
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	var brk := Metrics.Aux.BREAK
	for i in 2:
		Metrics.set_aux(brk)
		Checkpoints.on_aux_picked(brk)
		await t.frames(2)
		t.check(str(Checkpoints.last_checkpoint.get("kind", "")) == "break" and int((Checkpoints.last_checkpoint.get("metrics", {}) as Dictionary).get("breaks_used", -1)) == i + 1, "Normal T2: el break %d guarda su checkpoint" % (i + 1))
		await t.advance_clock(180.0)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await t.advance_clock(900.0)
	var cp_antes := _cp_clock()
	var msgs: Array = t.spy("show_message")
	Metrics.set_aux(brk)  # el tercero
	Checkpoints.on_aux_picked(brk)
	await t.frames(2)
	t.check(Metrics.breaks_used == 3 and is_equal_approx(_cp_clock(), cp_antes) and int((Checkpoints.last_checkpoint.get("metrics", {}) as Dictionary).get("breaks_used", -1)) == 2, "el tercer break NO guarda checkpoint (el vivo sigue siendo el del segundo, de las %s)" % GameState.clock_text_at(_cp_clock()))
	var murio: bool = await t.until(func() -> bool: return Checkpoints.dying, 120.0)
	t.check(murio and Checkpoints.death_cause == "tercer_break", "Shero te alcanza: muerte por el tercer break (%s)" % Checkpoints.death_cause)
	await t.wait_death_shown(20.0)
	await t.reconnect()
	t.check(Metrics.breaks_used == 2 and Metrics.reconnecting and Reconexion.resume_aux == brk, "reapareces antes de la falta: 2 breaks gastados, en el segundo (%d)" % Metrics.breaks_used)
	var fuera: bool = await t.until(func() -> bool: return not Metrics.reconnecting, 15.0)
	var fin_break := _tr("CORE3_RECON_BREAK_FIN").split("{")[0].strip_edges()
	t.check(fuera and Metrics.aux == Metrics.Aux.AVAILABLE and Metrics.breaks_used == 2 and _msg_con(msgs, fin_break) and not _msg_con(msgs, _tr("CORE3_RECON_QUEDA").split("{")[0].strip_edges()), "se pasa la cuenta: Available, y el aviso dice que ese Break se da por terminado (no invita a «retomarlo»: sería el tercero)")
	GameState.stop_calm()
	Checkpoints.set("_respawn_grace_left", 0.0)
	await t.seconds(45.0)
	t.check(not Checkpoints.dying and Checkpoints.deaths_this_shift == 1 and not Pursuit.is_hunting("shero"), "y nadie vuelve a buscarte por ese break: sin segunda muerte (muertes %d)" % Checkpoints.deaths_this_shift)
	await t.back_to_menu()
	# Fácil: el tercer break se devuelve para que lo confirmes; ese Break que no empezó tampoco guarda checkpoint.
	await t.start_shift("Marko", 2, 0, Difficulty.Level.FACIL)
	await t.login_at_seat()
	GameState.stop_calm()
	_cm(t).process_mode = Node.PROCESS_MODE_DISABLED
	for i in 2:
		Metrics.set_aux(brk)
		Checkpoints.on_aux_picked(brk)
		await t.advance_clock(180.0)
		Metrics.set_aux(Metrics.Aux.AVAILABLE)
		await t.advance_clock(900.0)
	Checkpoints.save_checkpoint("login")
	var cp_facil := Checkpoints.last_checkpoint
	Metrics.set_aux(brk)
	Checkpoints.on_aux_picked(brk)
	await t.frames(3)
	t.check(Metrics.breaks_used == 2 and Metrics.aux == Metrics.Aux.AVAILABLE and Checkpoints.last_checkpoint == cp_facil and str(Checkpoints.last_checkpoint.get("kind", "")) == "login", "Fácil: el tercer break pide confirmación, vuelves a Available y no se guarda checkpoint de ese Break (AUX %s, breaks %d)" % [Metrics.aux_name(Metrics.aux), Metrics.breaks_used])
	await t.back_to_menu()

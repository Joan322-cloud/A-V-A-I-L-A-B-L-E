## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2-final · integración: las costuras entre los paquetes de la v0.3.2 (gráficos × Haime × Training × IA).
##   `--escenario v032_fin`
##   fin_gfx_mundo_nuevo     (gráficos × Training) al firmar el Training, Main borra el mundo del recuerdo y arma el del
##                           Lunes en la misma llamada: el pase gráfico debe vestir el piso NUEVO (no el que se borra al
##                           final del cuadro), el Modo liviano debe fundir el piso nuevo, y el nodo de personajes (P5)
##                           debe existir desde el primer cuadro del Lunes. Al volver al menú el director suelta el piso.
##   fin_haime_luces[:cal]   (gráficos × Haime) la escalera de luz de la calibración fatal con las luces del paquete
##                           gráfico (Alta por defecto; `:media`): la sesión solo administra luces del juego (ninguna de
##                           las que añade el paquete), «afuera» y «la de tu lado» apagan las luces de verdad, el final
##                           deja solo el rojo del REC (haz, derrame, presencia y luces de práctica a cero; el filo rojo
##                           sigue al REC), y al soltar la sala todo vuelve a como estaba antes de sentarte.
##   fin_haime_calidad       (gráficos × Haime) cambiar de calidad en Opciones con una calibración en curso (Baja → Alta
##                           y Alta → Baja): la sesión sigue mandando sobre la luz y, al terminar, la sala queda igual
##                           que si la sesión nunca hubiera pasado, en la calidad nueva y al volver a la anterior.
##   fin_semana_lunes        (Training × Haime × IA × VoiceDirector) el primer Lunes de una partida nueva, por el camino
##                           de verdad (Training → firma → Lunes): la polaroid de tu promoción en C-14 dispara el
##                           pensamiento de tu agente; le mientes a Haime por Ezlaki (IABrain de verdad:
##                           haime_calibration_penalty() = 1); Haime te convoca con el pensamiento sonando: al sentarte
##                           en su sala nadie más habla (el pensamiento se corta y su subtítulo se va), la sesión te
##                           echa en cara la mentira, no hay voces solapadas; y como el pensamiento no llegó a la
##                           mitad, vuelve a intentarlo cuando regresas a tu mesa (y entonces sí queda dicho).
##   fin_idioma_opciones     (menú × gráficos × core) cambiar de idioma desde Opciones, abierto desde el menú principal de
##                           verdad: el panel sigue ENCIMA del menú recién rearmado (antes el título y los botones del
##                           menú quedaban dibujados sobre la lista de opciones), y la parte gráfica (calidad, «Gráficos
##                           avanzados…», su panel) queda en el idioma nuevo, de ida y de vuelta.
##   fin_objetos_detalle     (animación × gráficos) la animación de objetos sobre las piezas de la capa de detalle, en Alta
##                           y en Media: cada hoja de puerta tiene UNA manija (antes, en Alta, la del paquete gráfico y
##                           la de palanca de la animación quedaban una encima de la otra) y la copia batiente también;
##                           la silla de trabajo (malla cambiada por el paquete gráfico) rueda entera, con su estrella
##                           de ruedas, y vuelve a su sitio; el monitor de detalle sigue despertando; al pasar a Modo
##                           liviano se van las dos capas (ni GfxDetalle ni copias, y la animación de objetos apagada).
##   fin_muertes_graficos    (muertes × gráficos) los ganchos del paquete de muertes con las clases de verdad: una muerte
##                           con apagón en Alta (tercer_ww) llama a GfxDirector.blackout, GfxLens.kick y
##                           GfxCharacters.dress; el piso queda a oscuras de verdad mientras dura; al reconectar el
##                           apagón se levanta, las luces vuelven a su energía y no queda nada del screamer; en Baja y
##                           en Modo liviano los ganchos no visten ni un material ni tocan las luces.
##   fin_objetos_lisos       (gráficos, encargo del coordinador) en Media y Alta lo que el jugador lee o tiene en la mano no
##                           lleva el relieve genérico del paquete gráfico (se veía como rayas de camuflaje de cerca):
##                           ninguna malla de menos de 30 cm, con texto encima o de papel (notas, pósits, carteles,
##                           pizarras, fotocheck, botones del ascensor…) en los pisos 2, 1 y −1; la taza de C-13 es una
##                           taza (misma pieza, malla nueva) y sigue humeando; un objeto que aparece después (una nota
##                           nueva) también queda liso; las paredes y los muebles grandes conservan su relieve; al
##                           volver a Baja todo queda exactamente como lo dejó el juego.
##   fin_voces_turno_nuevo   (voces × animación × Main) un turno que arranca sin pasar por el menú (el Lunes al firmar el
##                           Training, las rondas encadenadas de los bots) no hereda voces en cola ni avisos del turno
##                           anterior; y una línea cuyo reproductor 3D ya fue liberado no rompe el gesto de hablar
##                           (SpeechHub preguntaba «is Node» a una instancia liberada: error de script visto en el bot).
##   fin_menu_en_plena_muerte (muertes × Main) [Esc] → «Salir al menú» en mitad de una muerte (la pausa se abre con el
##                           turno en marcha, también durante un screamer): el mundo se borra con la coreografía a
##                           medias. No debe quedar nada en pantalla ni errores, y el turno siguiente arranca limpio.
##                           Causas: la fusión de Vitzo (22,9 s), tercer_ww, la calibración fatal y el colapso.
##   fin_colapso_cliente     (muertes × VoiceDirector) el colapso por Fatiga en plena llamada (kills-rc2): la línea del
##                           cliente («¿Aló?… ¿Sigue ahí?») va por el VoiceDirector como voz de la toma (prioridad de
##                           screamer: el colapso no tiene asesino cuyo subtítulo dejar pasar). En una muerte de verdad,
##                           con un compañero, Shero, Ezlaki y Rasec queriendo hablar: suena ella sola, por el
##                           auricular, a su nivel, con su subtítulo en el HUD, en ES y en EN (voz de voces/clientes/en);
##                           nadie más pasa ni antes ni mientras suena; al reconectar no queda ni la voz ni el texto.
##                           Y la silla (muertes × animación de objetos × gráficos): sale rodando ENTERA (asiento,
##                           respaldo y base juntos; antes solo el asiento, flotando) y vuelve a su sitio al reconectar.
##   fin_veto_sin_perdidas   (Haime × VoiceDirector × audio) cuando la calibración le quita la palabra a los demás en el
##                           instante en que empiezan (veto al empezar), la auditoría de voces no cuenta como «importante
##                           perdida» lo que no se perdió: la voz de un personaje pedida sin texto cuyo subtítulo llega
##                           en ese mismo cuadro (Rasec: su texto sale como aviso), un anuncio por los parlantes, ni un
##                           susto de ambiente (relleno). Una importante de verdad sin texto sí queda anotada. Visto en
##                           un bot de Difícil con dos calibraciones fatales: «importantes perdidas 2» sin pérdida real.
##   fin_ascensor_doble      (mundo × bots) dos pedidos de viaje al ascensor en el mismo cuadro: un solo viaje, el piso
##                           se arma una vez y con su nombre (antes se armaba dos veces: el primero se liberaba con
##                           llamadas diferidas pendientes, dos errores del motor en el registro del bot humano).
##   fin_primer_arranque     (gráficos × core) la primera vez en escritorio: pantalla completa (core) también en el
##                           arranque relanzado por el paquete gráfico en otro renderizador; calidad inicial según la
##                           tarjeta; con argumentos de herramienta, ni pantalla completa ni calidad por tarjeta («media»).
##   fin_training_teclas     (Training × core) los textos del Training que nombran teclas (data/tutorial.json) siguen el
##                           remapeo de Opciones → Controles en ES y EN, menos [T] y [N], que son sus teclas propias; con
##                           las teclas de fábrica no cambia ni una letra.


func escenarios() -> Array[String]:
	return ["fin_gfx_mundo_nuevo", "fin_haime_luces", "fin_haime_luces:", "fin_haime_calidad", "fin_training_teclas", "fin_primer_arranque", "fin_idioma_opciones", "fin_objetos_detalle", "fin_muertes_graficos", "fin_objetos_lisos", "fin_voces_turno_nuevo", "fin_menu_en_plena_muerte", "fin_colapso_cliente", "fin_veto_sin_perdidas", "fin_ascensor_doble", "fin_semana_lunes"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"fin_gfx_mundo_nuevo": await _mundo_nuevo(t)
		"fin_haime_luces": await _haime_luces(t, arg if arg != "" else "alta")
		"fin_haime_calidad": await _haime_calidad(t)
		"fin_training_teclas": await _training_teclas(t)
		"fin_primer_arranque": await _primer_arranque(t)
		"fin_idioma_opciones": await _idioma_opciones(t)
		"fin_objetos_detalle": await _objetos_detalle(t)
		"fin_muertes_graficos": await _muertes_graficos(t)
		"fin_objetos_lisos": await _objetos_lisos(t)
		"fin_voces_turno_nuevo": await _voces_turno_nuevo(t)
		"fin_menu_en_plena_muerte": await _menu_en_plena_muerte(t)
		"fin_colapso_cliente": await _colapso_cliente(t)
		"fin_veto_sin_perdidas": await _veto_sin_perdidas(t)
		"fin_ascensor_doble": await _ascensor_doble(t)
		"fin_semana_lunes": await _semana_lunes(t)


## Cambia la calidad como lo hace el menú y espera a que el pase gráfico (diferido) termine.
func _quality(t: Node, lv: String) -> void:
	Loc.set_setting("quality", lv)
	GfxQuality.apply(t.get_tree(), lv)
	EventBus.settings_changed.emit("quality")
	await t.frames(6)


func _floor_of(t: Node) -> Node3D:
	var b: Building = GfxQuality.live_building(t.get_tree())
	return b.floor_node if b != null else null


# --- gráficos × Training: el mundo del Lunes se arma en el mismo cuadro en que se borra el del recuerdo ---------------

func _mundo_nuevo(t: Node) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	var tree: SceneTree = t.get_tree()
	for lv in ["alta", "liviano"]:
		SaveSlots.select("Jiroshi")
		var tut: Node = t.main.call("_start_first_training", "Jiroshi", GameState.Mode.NORMAL)
		t.check(tut != null and GameState.is_tutorial(), "%s: el Training obligatorio arranca" % lv)
		await t.frames(4)
		await _quality(t, lv)
		await t.frames(8)
		var old_floor := _floor_of(t)
		var old_hub := PersonajesP5.get_hub(tree)
		t.check(old_floor != null, "%s: el recuerdo tiene piso cargado" % lv)
		if lv == "alta":
			t.check(is_instance_valid(GfxDirector.inst) and GfxDirector.inst._floor_id == old_floor.get_instance_id(), "alta: el director vistió el piso del recuerdo")
		# La firma: Main._after_training → _start_shift (borra el mundo y arma el del Lunes en la misma llamada).
		t.main.call("_after_training", "Jiroshi", true, {})
		var new_floor := _floor_of(t)
		t.check(new_floor != null and new_floor != old_floor and GameState.turno == 1 and not GameState.is_tutorial(), "%s: el Lunes se arma en la misma llamada (piso nuevo)" % lv)
		var hub_now := PersonajesP5.get_hub(tree)
		await t.frames(1)
		# Un cuadro después el mundo viejo ya no existe: nadie debe haberse quedado con él.
		t.check(not is_instance_valid(old_floor), "%s: el piso del recuerdo ya se borró" % lv)
		var hub := PersonajesP5.get_hub(tree)
		t.check(hub != null and is_instance_valid(hub) and not hub.is_queued_for_deletion() and hub != old_hub and hub == hub_now, "%s: el Lunes tiene su nodo de personajes (P5) desde el primer cuadro" % lv)
		t.check(t.player() != null and is_instance_valid(t.player()) and t.building() != null and t.building().floor_node == new_floor, "%s: «jugador» y «edificio» son los del mundo nuevo" % lv)
		if lv == "alta":
			var d: GfxDirector = GfxDirector.inst
			t.check(is_instance_valid(d) and d._floor_id == new_floor.get_instance_id(), "alta: el pase gráfico vistió el piso del Lunes (no el que se borraba)")
			t.check(d.lights.floor_node == null or is_instance_valid(d.lights.floor_node), "alta: las luces del paquete no apuntan a un piso liberado")
			t.check(d.detail.floor_node == new_floor, "alta: la capa de detalle es la del piso nuevo")
			await t.frames(3)
			t.check(d.lights.active == (d.lights.floor_node == new_floor) and (not d.lights.active or d.lights.fixtures.size() > 0), "alta: luz nocturna aplicada al piso nuevo (%d luminarias)" % d.lights.fixtures.size())
		else:
			await t.frames(3)
			t.check(new_floor.get_node_or_null("GfxLotes") != null, "liviano: la geometría quieta del piso NUEVO queda fundida en lotes")
		# Volver al menú: el piso se va sin pasar por el pase gráfico.
		await t.back_to_menu()
		await t.frames(2)
		if lv == "alta" and is_instance_valid(GfxDirector.inst):
			var d2: GfxDirector = GfxDirector.inst
			t.check(not d2.lights.active and d2.lights.floor_node == null and d2.lights.pool.is_empty(), "alta: al volver al menú las luces del paquete sueltan el piso (activas %s, bolsa %d)" % [d2.lights.active, d2.lights.pool.size()])
		await t.frames(4)
	await _quality(t, q0)


# --- gráficos × Haime: la escalera de luz de la fatal con las luces del paquete ----------------------------------------

func _haime(t: Node) -> Node:
	return t.get_tree().get_first_node_in_group("p5_haime_actor")


## Máximo en unos cuadros de una lectura que parpadea (el tubo de la sala parpadea por diseño).
func _peak(t: Node, read: Callable, frames: int = 45) -> float:
	var m := 0.0
	for _i in frames:
		await t.frames(1)
		m = maxf(m, float(read.call()))
	return m


## Entra a la sala de calibración (de pie junto a tu silla) con los demás personajes quietos.
func _enter_room(t: Node) -> Node:
	var p5: RefCounted = load("res://scripts/dev/escenarios/p5_personajes.gd").new()
	var hub: PersonajesP5 = await p5.call("_prep", t, 1, true, Difficulty.Level.NORMAL)
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	hub.qa.process_mode = Node.PROCESS_MODE_DISABLED
	for v in t.get_tree().get_nodes_in_group("vitzo"):
		(v as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var fl := _floor_of(t)
	if t.player().seated:
		t.player().stand_up()
	t.player().teleport(fl.to_global(Vector3(11.1, 0.05, 2.85)), 90.0)
	await t.seconds(1.2)
	return _haime(t)


func _haime_luces(t: Node, lv: String) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	await t.start_shift("Jiroshi", 1)
	await _quality(t, lv)
	var node := await _enter_room(t)
	var fl := _floor_of(t)
	var d: GfxDirector = GfxDirector.inst if is_instance_valid(GfxDirector.inst) else null
	t.check(node != null and d != null and d.lights.active, "%s: Haime en su sala y la luz nocturna del paquete activa" % lv)
	if node == null or d == null:
		await _quality(t, q0)
		await t.back_to_menu()
		return
	var lights: GfxLights = d.lights
	var cal: GfxLights.Fixture = null
	for fx in lights.fixtures:
		if is_instance_valid(fx.panel) and str(fx.panel.name) == "LuzCalibracion":
			cal = fx
	var relleno := fl.find_child("LuzCalibracionRelleno", true, false) as Light3D
	var luz_rec := fl.find_child("LuzRec", true, false) as Light3D
	var white_extra: Light3D = null
	var red_extra: Light3D = null
	for ex in lights._extras:
		var l := ex[0] as Light3D
		if l.light_color.r > 0.8 and l.light_color.g < 0.35:
			red_extra = l
		else:
			white_extra = l
	t.check(cal != null and cal.lit and is_instance_valid(cal.spot) and relleno != null and luz_rec != null and white_extra != null and red_extra != null, "la sala tiene su panel con haz, su relleno, el REC y las dos luces extra del paquete")
	if cal == null or relleno == null or luz_rec == null or white_extra == null or red_extra == null:
		await _quality(t, q0)
		await t.back_to_menu()
		return
	var spot0: float = await _peak(t, func() -> float: return cal.spot.light_energy)
	var fill0 := relleno.light_energy
	var rec0 := luz_rec.light_energy
	var wex0: float = await _peak(t, func() -> float: return white_extra.light_energy)
	var rex0 := red_extra.light_energy
	var base: float = await _peak(t, func() -> float: return float(node.call("room_light")))
	var state0 := _room_state(t)
	t.check(spot0 > 0.5 and fill0 > 0.001 and wex0 > 0.3 and rex0 > 0.5 and base > 0.05, "antes de sentarte: haz %.2f, relleno %.3f, derrame %.2f, filo rojo %.2f, luz blanca %.2f" % [spot0, fill0, wex0, rex0, base])
	# La fatal, con las mismas llamadas que hace la sesión (QaFeedback._start_session, _light_dies y el cierre).
	node.call("session_mode", true, 4)
	node.call("room_session", true, 4)
	node.call("lock_door")
	node.call("set_dim", QaFeedback.LIGHT_START[4])
	node.call("set_outside", QaFeedback.OUTSIDE_START[4])
	node.call("set_fill", QaFeedback.FILL_START[4], true)
	node.call("sick_light", 0.45)
	await t.frames(3)
	var added := 0
	var outside_n := 0
	for e in node.get("_lights"):
		if GfxLights.is_added(e[0] as Light3D):
			added += 1
		if bool(e[5]):
			outside_n += 1
	t.check(added == 0, "la sesión administra solo luces del juego: ninguna de las que añade el paquete (%d)" % added)
	t.check(outside_n > 0, "y cuenta las de afuera que alcanzan la sala (%d)" % outside_n)
	var s0: float = await _peak(t, func() -> float: return float(node.call("room_light")), 30)
	t.check(s0 < base * 0.75 and s0 > 0.01, "al sentarte en la fatal la sala ya está más oscura (%.3f de %.3f)" % [s0, base])
	# La luz de tu lado: en reposo el paquete la deja casi apagada (room_k de la zona); la fatal la pide «en absoluto»
	# y entonces cuenta contra la luz que diseñó el piso ("relleno_guion" de la zona).
	t.check(relleno.light_energy > fill0 * 2.0 and relleno.light_energy >= 0.1, "la luz de tu lado alumbra de verdad durante la fatal (%.3f; en reposo %.3f)" % [relleno.light_energy, fill0])
	var side := fl.to_global(Vector3(12.2, 1.4, 2.0))  # la pared de tu lado, junto a la puerta (fuera del haz del tubo)
	var side0 := _white_at(fl, side)
	# 1) Se apaga el piso de afuera.
	node.call("fail_light", "afuera")
	await t.frames(3)
	var out_on := 0
	for e in node.get("_lights"):
		var l := e[0] as Light3D
		if bool(e[5]) and is_instance_valid(l) and l.visible and l.light_energy > 0.001:
			out_on += 1
	var out_spots := 0
	for fx in lights.fixtures:
		if fx != cal and fx.lit and is_instance_valid(fx.spot) and fx.spot.visible and fx.spot.light_energy > 0.01 and _reaches_room(fx.spot):
			out_spots += 1
	t.check(out_on == 0 and out_spots == 0, "«afuera»: ninguna luz de afuera alcanza ya la sala (del juego %d, haces del paquete %d)" % [out_on, out_spots])
	var s1: float = await _peak(t, func() -> float: return float(node.call("room_light")), 30)
	t.check(relleno.light_energy > 0.001, "«afuera» no toca la luz de tu lado (%.3f)" % relleno.light_energy)
	# 2) Se apaga la luz de tu lado: la de verdad, no una de las que añade el paquete.
	node.call("fail_light", "relleno")
	await t.frames(3)
	t.check(relleno.light_energy <= 0.0001, "«la de tu lado»: muere el relleno de la sala (energía %.4f)" % relleno.light_energy)
	var s2: float = await _peak(t, func() -> float: return float(node.call("room_light")), 30)
	var side2 := _white_at(fl, side)
	# En Media/Alta la mesa la alumbra el haz del tubo (cerrado, sobre ella): «afuera» se mide ahí; «la de tu lado» se
	# mide donde alumbra, en tu lado de la sala (la mesa casi no cambia).
	t.check(s1 <= s0 * 0.85 and s2 < s1, "«afuera» se nota en la mesa y «la de tu lado» la baja algo más (%.3f → %.3f → %.3f)" % [s0, s1, s2])
	t.check(side0 > 0.004 and side2 <= side0 * 0.5, "«la de tu lado» deja tu lado de la sala a oscuras (%.4f → %.4f)" % [side0, side2])
	t.check(int(node.call("lights_alive")) == 1, "queda una sola luz blanca viva: el tubo (%d)" % int(node.call("lights_alive")))
	# 3) El cierre: apagón, solo el REC.
	node.call("blackout", 0.4)
	node.call("only_rec")
	node.call("brace", true)
	await t.frames(4)
	var pool_e := 0.0
	for k in lights.pool.size():
		if lights._pool_zone[k] == cal.zone and lights.pool[k].visible:
			pool_e += lights.pool[k].light_energy
	var spot_e := cal.spot.light_energy if cal.spot.visible else 0.0
	var wex_e := white_extra.light_energy if white_extra.visible else 0.0
	t.check(spot_e < 0.005 and wex_e < 0.005 and pool_e < 0.005 and (lights.presence == null or lights.presence.light_energy < 0.01), "solo REC: haz %.3f, derrame %.3f, luces de práctica %.3f y presencia %.3f a cero" % [spot_e, wex_e, pool_e, lights.presence.light_energy if lights.presence != null else 0.0])
	t.check(float(node.call("room_light")) <= 0.005 and bool(node.get("rec_only")), "ninguna luz blanca llega a la mesa (%.3f)" % float(node.call("room_light")))
	# (El ánimo del piso baja las luces con la tensión: el rojo se compara con holgura, no al milímetro.)
	# (El ánimo del piso baja las luces con la tensión: el rojo se compara con holgura. El filo rojo del paquete sigue
	# encendido, pero bajo —"sigue_min"—: con la sala a oscuras, entero, sería la luz principal.)
	t.check(luz_rec.visible and luz_rec.light_energy >= rec0 * 0.5 and red_extra.visible and red_extra.light_energy >= 0.05 and red_extra.light_energy <= rex0 * 0.3 and float(node.call("rec_light")) >= 0.3, "queda el rojo: REC del monitor %.2f (antes %.2f), su filo %.2f (antes %.2f) y el de Haime %.2f" % [luz_rec.light_energy, rec0, red_extra.light_energy, rex0, float(node.call("rec_light"))])
	# La muerte retiene la sala; al reaparecer vuelve a como estaba antes de sentarte.
	node.call("hold_for_death")
	node.call("room_session", false, 0)
	await t.frames(3)
	t.check(float(node.call("room_light")) <= 0.005, "retenida para la muerte: sigue a oscuras")
	node.call("release_after_death")
	var spot1: float = await _peak(t, func() -> float: return cal.spot.light_energy)
	var wex1: float = await _peak(t, func() -> float: return white_extra.light_energy)
	var base1: float = await _peak(t, func() -> float: return float(node.call("room_light")))
	var diff := _state_diff(state0, _room_state(t))
	t.check(diff.is_empty() and state0.size() >= 3, "al soltar la sala, cada luz del juego vuelve a su base de antes de sentarte (%d luces; diferencias: %s)" % [state0.size(), "; ".join(diff.slice(0, 4))])
	# Lo esclavo vuelve con ellas (el ánimo del piso —la tensión— baja algo todas las luces: holgura).
	t.check(spot1 >= spot0 * 0.6 and spot1 <= spot0 * 1.1 and wex1 >= wex0 * 0.6 and red_extra.visible and base1 >= base * 0.6 and base1 <= base * 1.1, "y lo que añade el paquete vuelve con ellas: haz %.2f (%.2f), derrame %.2f (%.2f), luz blanca %.3f (%.3f)" % [spot1, spot0, wex1, wex0, base1, base])
	t.note("%s · luz blanca en la mesa: normal %.3f · fatal %.3f → %.3f → %.3f → 0" % [lv, base, s0, s1, s2])
	await _quality(t, q0)
	await t.back_to_menu()


## Luz blanca que llega a un punto (como Haime.room_light(), pero en cualquier sitio y contando el cono de los focos):
## cada luz visible que no sea roja pesa por su energía y por lo que se atenúa hasta ahí.
func _white_at(fl: Node, at: Vector3) -> float:
	var sum := 0.0
	for n in fl.get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or (l.light_color.r > 0.8 and l.light_color.g < 0.35):
			continue
		var r := (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		var to := at - l.global_position
		var d := to.length()
		if r <= 0.0 or d >= r:
			continue
		if l is SpotLight3D and d > 0.01:
			var ang := rad_to_deg((-l.global_transform.basis.z).angle_to(to / d))
			if ang > (l as SpotLight3D).spot_angle:
				continue
		sum += l.light_energy * pow(1.0 - pow(d / r, 4.0), 2.0) / (1.0 + d * d)
	return sum


## ¿El alcance de esta luz toca la sala de calibración? (La misma caja que usa Haime.)
func _reaches_room(l: Light3D) -> bool:
	var room := AABB(Vector3(8.5, -0.2, 1.4), Vector3(4.0, 3.4, 2.9))
	var p := l.global_position
	var near := Vector3(clampf(p.x, room.position.x, room.end.x), clampf(p.y, room.position.y, room.end.y), clampf(p.z, room.position.z, room.end.z))
	var r := (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 0.0)
	return p.distance_to(near) <= r * 0.85


# --- gráficos × Haime: cambiar de calidad con la calibración en curso -------------------------------------------------

## Estado de cada luz del juego que la sesión o el paquete pueden tocar: nombre → [visible, energía base, alcance].
func _room_state(t: Node) -> Dictionary:
	var out: Dictionary = {}
	var fl := _floor_of(t)
	for n in fl.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if GfxLights.is_added(l) or l.has_meta("no_mood"):
			continue
		if not _reaches_room(l):
			continue
		var e := float(l.get_meta("mood_base", l.light_energy))
		if l.get_parent() != null:
			for c in l.get_parent().get_children():
				if c is FlickerLight and (c as FlickerLight).light == l:
					e = (c as FlickerLight).base_energy
		out[str(fl.get_path_to(l))] = [l.visible, snappedf(e, 0.0005), (l as OmniLight3D).omni_range if l is OmniLight3D else 0.0]
	return out


func _state_diff(a: Dictionary, b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in a.keys():
		if not b.has(k):
			out.append("falta %s" % k)
		elif str(a[k]) != str(b[k]):
			out.append("%s %s → %s" % [k, str(a[k]), str(b[k])])
	for k in b.keys():
		if not a.has(k):
			out.append("sobra %s" % k)
	return out


func _haime_calidad(t: Node) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	await t.start_shift("Jiroshi", 1)
	await _quality(t, "baja")
	var node := await _enter_room(t)
	t.check(node != null, "Haime en su sala")
	if node == null:
		await _quality(t, q0)
		await t.back_to_menu()
		return
	# Referencias sin sesión: la sala en Baja y en Alta.
	var ref_baja := _room_state(t)
	await _quality(t, "alta")
	await t.frames(8)
	var ref_alta := _room_state(t)
	await _quality(t, "baja")
	await t.frames(4)
	t.check(_state_diff(ref_baja, _room_state(t)).is_empty() and ref_baja.size() >= 3, "ida y vuelta Baja → Alta → Baja sin sesión deja la sala igual (%d luces)" % ref_baja.size())
	for dir in [["baja", "alta"], ["alta", "baja"]]:
		var from := str(dir[0])
		var to := str(dir[1])
		await _quality(t, from)
		await t.frames(6)
		var ref_from: Dictionary = ref_baja if from == "baja" else ref_alta
		var ref_to: Dictionary = ref_baja if to == "baja" else ref_alta
		t.check(_state_diff(ref_from, _room_state(t)).is_empty(), "%s: la sala arranca en su estado de referencia %s" % [from, str(_state_diff(ref_from, _room_state(t)).slice(0, 3))])
		# La advertencia a medio camino: sala más oscura, afuera casi nada, y el tubo ya murió en el apagón.
		node.call("session_mode", true, 3)
		node.call("room_session", true, 3)
		node.call("set_dim", QaFeedback.LIGHT_START[3])
		node.call("set_outside", QaFeedback.OUTSIDE_START[3])
		node.call("set_fill", QaFeedback.FILL_START[3], false)
		node.call("fail_light", "")
		await t.frames(3)
		var dark0: float = await _peak(t, func() -> float: return float(node.call("room_light")), 20)
		var alive0 := int(node.call("lights_alive"))
		# El jugador abre la pausa → Opciones y cambia la calidad.
		await _quality(t, to)
		await t.frames(8)
		var dark1: float = await _peak(t, func() -> float: return float(node.call("room_light")), 20)
		var panel := _floor_of(t).find_child("LuzCalibracion", true, false)
		var tube: OmniLight3D = null
		for c in panel.get_children():
			if c is OmniLight3D:
				tube = c
		t.check(tube != null and (not tube.visible or tube.light_energy <= 0.0001), "%s → %s con la sesión en curso: el tubo que murió sigue muerto (energía %.3f)" % [from, to, tube.light_energy if tube != null else -1.0])
		t.check(int(node.call("lights_alive")) == alive0, "y la sesión sigue contando las mismas luces vivas (%d, antes %d)" % [int(node.call("lights_alive")), alive0])
		var ref_room: float = 0.0
		t.note("%s → %s: luz blanca con la sesión %.3f → %.3f" % [from, to, dark0, dark1])
		# La sesión sigue mandando: un apagón deja la sala sin luz blanca.
		node.call("blackout", 30.0)
		await t.frames(4)
		ref_room = float(node.call("room_light"))
		t.check(ref_room <= 0.005, "un apagón de la sesión sigue dejando la sala a oscuras en la calidad nueva (%.3f)" % ref_room)
		node.call("room_session", false, 0)
		node.call("session_mode", false, 0)
		await t.frames(6)
		var diff := _state_diff(ref_to, _room_state(t))
		t.check(diff.is_empty(), "al terminar la sesión la sala queda como si nunca hubiera pasado, en %s (%d diferencias: %s)" % [to, diff.size(), "; ".join(diff.slice(0, 4))])
		await _quality(t, from)
		await t.frames(8)
		var diff2 := _state_diff(ref_from, _room_state(t))
		t.check(diff2.is_empty(), "y al volver a %s también (%d diferencias: %s)" % [from, diff2.size(), "; ".join(diff2.slice(0, 4))])
	await _quality(t, q0)
	await t.back_to_menu()


# --- Training × core: los textos del Training siguen el remapeo de teclas ----------------------------------------------

## Todos los textos {es, en} de data/tutorial.json (en cualquier nivel).
func _tut_texts(o: Variant, out: Array) -> void:
	if o is Dictionary:
		if (o as Dictionary).has("es") and (o as Dictionary).has("en") and (o as Dictionary)["es"] is String:
			out.append(o)
			return
		for k in (o as Dictionary).keys():
			_tut_texts((o as Dictionary)[k], out)
	elif o is Array:
		for v in (o as Array):
			_tut_texts(v, out)


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	return ev


func _training_teclas(t: Node) -> void:
	var lang0 := Loc.language
	Loc.set_language("es")
	Controls.reset_all()
	await t.frames(2)
	var texts: Array = []
	_tut_texts(Tutorial.data(), texts)
	var with_keys: Array = []
	for d in texts:
		if str((d as Dictionary)["es"]).find("[") >= 0:
			with_keys.append(d)
	t.check(texts.size() > 200 and with_keys.size() >= 40, "data/tutorial.json: %d textos, %d nombran alguna tecla" % [texts.size(), with_keys.size()])
	# De fábrica: ni una letra cambia.
	var changed := 0
	for d in texts:
		if Tutorial._txt(d) != str((d as Dictionary)["es"]):
			changed += 1
	t.check(not Controls.hints_active and changed == 0, "con las teclas de fábrica los textos salen tal cual (%d distintos)" % changed)
	# Como en Opciones → Controles: interactuar → G, aceptar → V, rueda de AUX → X, micrófono → M.
	Controls.rebind("interact", _key(KEY_G))
	Controls.rebind("accept", _key(KEY_V))
	Controls.rebind("aux_wheel", _key(KEY_X))
	Controls.rebind("ia_hablar", _key(KEY_M))
	await t.frames(2)
	var stale: Array[String] = []
	var t_moved: Array[String] = []
	var swapped := {"[G]": 0, "[V]": 0, "[X]": 0}
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		await t.frames(1)
		for d in with_keys:
			var src := str((d as Dictionary)[lang])
			var out := Tutorial._txt(d)
			for old in ["[E]", "[Espacio]", "[Space]", "[Q]"]:
				if out.contains(old):
					stale.append("%s: «%s»" % [lang, out.left(70)])
			# [T] y [N] son las teclas propias del Training (continuar / sí / no): no se tocan aunque el micrófono cambie.
			if src.count("[T]") != out.count("[T]") or src.count("[N]") != out.count("[N]") or out.contains("[M]"):
				t_moved.append("%s: «%s»" % [lang, out.left(70)])
			for k in swapped.keys():
				swapped[k] = int(swapped[k]) + out.count(str(k))
	t.check(stale.is_empty(), "interactuar → G, aceptar → V, rueda → X: ningún texto del Training sigue nombrando la tecla vieja (%d: %s)" % [stale.size(), "; ".join(stale.slice(0, 3))])
	t.check(int(swapped["[G]"]) >= 20 and int(swapped["[V]"]) >= 10 and int(swapped["[X]"]) >= 10, "y nombran la nueva en ES y EN (%s)" % str(swapped))
	t.check(t_moved.is_empty(), "[T] y [N] (las teclas del Training) quedan como están (%d: %s)" % [t_moved.size(), "; ".join(t_moved.slice(0, 3))])
	# El paso de verdad: el panel del Training muestra el texto con la tecla nueva.
	Loc.set_language("es")
	var sample := ""
	for d in with_keys:
		if str((d as Dictionary)["es"]).contains("[Espacio]"):
			sample = Tutorial._txt(d)
			break
	t.check(sample.contains("[V]") and not sample.contains("[Espacio]"), "p. ej. «%s»" % sample.left(90))
	# Y el Training los saca por ahí: en core/tutorial.gd ningún texto de paso, pista, opción, explicación o mensaje
	# se lee ya con Loc.pick() a secas (en un exportado el código fuente no viaja: ahí no se mira).
	var src := (load("res://scripts/core/tutorial.gd") as GDScript).source_code
	if src != "":
		var raw: Array[String] = []
		for pat in ["Loc.pick(s.get(\"texto\"", "Loc.pick(s.get(\"pista\"", "Loc.pick(opts[", "Loc.pick(s.get(\"explica\"", "Loc.pick(ar.get(\"texto\""]:
			if src.contains(pat):
				raw.append(pat)
		t.check(raw.is_empty() and src.count("_txt(") >= 11, "core/tutorial.gd saca esos textos con _txt() (quedan a secas: %s)" % str(raw))
	Controls.reset_all()
	await t.frames(2)
	changed = 0
	for d in texts:
		if Tutorial._txt(d) != str((d as Dictionary)["es"]):
			changed += 1
	t.check(changed == 0, "restablecer controles: los textos vuelven letra por letra (%d distintos)" % changed)
	Loc.set_language(lang0)


# --- gráficos × core: la primera vez ----------------------------------------------------------------------------------

func _primer_arranque(t: Node) -> void:
	var none := PackedStringArray()
	var relaunch := PackedStringArray([GfxBoot.RELAUNCH_ARG])
	var forced := PackedStringArray(["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"])
	t.check(Loc.first_launch_fullscreen(false, false, none, Loc.tool_args(none)), "primera vez, sin argumentos: pantalla completa")
	t.check(Loc.tool_args(relaunch).is_empty() and Loc.first_launch_fullscreen(false, false, forced, Loc.tool_args(relaunch)), "el arranque relanzado por el paquete gráfico (otro renderizador + %s) sigue siendo la primera vez: pantalla completa" % GfxBoot.RELAUNCH_ARG)
	t.check(not Loc.first_launch_fullscreen(false, false, none, Loc.tool_args(PackedStringArray(["--bot", "1"]))) and not Loc.first_launch_fullscreen(false, false, none, Loc.tool_args(PackedStringArray([GfxBoot.RELAUNCH_ARG, "--shot", "menu"]))), "con una herramienta (--bot, --shot), no")
	# Calidad inicial: por la tarjeta en un arranque de verdad; «media» en pruebas (esta corrida lleva --escenario).
	t.check(GfxBoot.dev_run() and GfxBoot.desktop_default() == "media", "en una corrida de pruebas la calidad inicial es «media» (%s)" % GfxBoot.desktop_default())
	t.check(GfxBoot.level_for(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_CPU, "llvmpipe (LLVM 17, 256 bits)", "Mesa")) == "liviano"
		and GfxBoot.level_for(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, "Intel(R) UHD Graphics 620", "Intel")) == "media"
		and GfxBoot.level_for(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "NVIDIA GeForce GTX 1660", "NVIDIA")) == "alta", "sin tarjeta → Modo liviano · integrada → Media · dedicada → Alta")
	# El relanzado no repite el relanzamiento y, con un adaptador por software en Forward+, el primero sí relanza.
	var d1 := GfxBoot.decide({"metodo": "forward_plus", "quiere": "auto", "clase": "software", "marca_pendiente": false, "cli": false, "relanzado": false, "fallo_previo": false})
	var d2 := GfxBoot.decide({"metodo": "gl_compatibility", "quiere": "auto", "clase": "software", "marca_pendiente": false, "cli": true, "relanzado": true, "fallo_previo": false})
	t.check(str(d1["accion"]) == "relanzar" and str(d1["metodo"]) == "gl_compatibility" and str(d2["accion"]) == "", "Forward+ por software relanza una vez en Compatibilidad y el relanzado se queda (%s / «%s»)" % [str(d1["motivo"]), str(d2["motivo"])])
	# La pantalla de brillo y la medición solo en un arranque sin herramientas: aquí no deben existir.
	await t.frames(2)
	t.check(t.get_tree().root.find_child("GfxBrillo", true, false) == null and t.get_tree().root.find_child("GfxBench", true, false) == null, "en una corrida de pruebas no sale la pantalla de brillo ni corre la medición")


# --- Training × Haime × IA × VoiceDirector: el primer Lunes ------------------------------------------------------------

func _thinking() -> Object:
	for q in [VoiceDirector.current] + VoiceDirector.queue.duplicate():
		if q != null and str(q.speaker) == "piensa":
			return q
	return null


func _semana_lunes(t: Node) -> void:
	var tree: SceneTree = t.get_tree()
	var agent := "Marko"
	var p5: RefCounted = load("res://scripts/dev/escenarios/p5_personajes.gd").new()
	var h2: RefCounted = load("res://scripts/dev/escenarios/ph2_haime.gd").new()
	# Partida nueva por el camino de verdad: Training obligatorio → firma → Lunes.
	SaveSlots.select(agent)
	t.check(SaveSlots.needs_training(agent), "partida nueva: %s todavía no hizo el Training" % agent)
	var tut: Node = t.main.call("_start_first_training", agent, GameState.Mode.NORMAL)
	await t.frames(6)
	t.check(tut != null and Flashback.active and GameState.is_tutorial(), "el recuerdo arranca")
	t.main.call("_after_training", agent, true, {"foto": true})
	await t.frames(4)
	t.check(GameState.turno == 1 and not GameState.is_tutorial() and not Flashback.active and GameState.agent == agent, "tras la firma empieza el Lunes de %s" % agent)
	t.check(bool(SaveSlots.contract(agent).get("firmado", false)) and bool(RecuerdosSemana.record().get("foto", false)) and not bool(RecuerdosSemana.record().get("eco_foto", false)), "con el contrato firmado y la foto de promoción en la partida (%s)" % str(RecuerdosSemana.record()))
	var cm := t.main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	for v in tree.get_nodes_in_group("vitzo"):
		(v as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await t.login_at_seat()
	for sh in tree.get_nodes_in_group("shero"):
		(sh as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()
	var hub := PersonajesP5.get_hub(tree)
	t.check(hub != null, "el nodo de personajes del Lunes existe")
	if hub == null:
		await t.back_to_menu()
		return
	hub.training.process_mode = Node.PROCESS_MODE_DISABLED
	hub.rasec.process_mode = Node.PROCESS_MODE_DISABLED
	# (Por clase, no por nombre: al armarse en el mismo cuadro en que se borra el mundo del recuerdo, los nodos del
	# mundo nuevo que se llaman igual que uno viejo reciben un nombre automático.)
	var ecos: RecuerdosSemana = null
	for c in (t.main.get("world") as Node).get_children():
		if c is RecuerdosSemana and not c.is_queued_for_deletion():
			ecos = c as RecuerdosSemana
	t.check(ecos != null and ecos.photo != null and is_instance_valid(ecos.photo), "la polaroid de tu promoción está en C-14")
	# 1) Sentado en tu mesa, tu agente piensa en la foto.
	var thought: bool = await t.until(func() -> bool: return _thinking() != null and VoiceDirector.current != null and str(VoiceDirector.current.speaker) == "piensa", 12.0)
	var line: Object = _thinking()
	t.check(thought and line != null, "al sentarte en C-14 suena el pensamiento de la foto (voz «piensa»)")
	var hud_sub := (t.main.find_child("HUD", true, false) as Node).get("_sub") as Label
	var thought_text := hud_sub.text if hud_sub != null else ""
	t.check(thought_text.contains(agent), "con su subtítulo en el HUD («%s»)" % thought_text.left(60))
	# 2) Le mientes a Haime por Ezlaki después de un contacto con marca (el cerebro de IA de verdad).
	var ez := EzlakHub.get_hub(tree)
	IABrain.forget_all()
	IABrain.recent_contacts.append({"id": "t1c1", "qa": ["calmese"], "caso": "Estado de envío #KP-2210-7741", "frase": "Señor, si no se calma no puedo ayudarle."})
	ez.call("_ensure", "dm:haime")
	ez.typed_reply("dm:haime", "haime yo hice todo bien, seguí el procedimiento")
	t.check(IABrain.haime_calibration_penalty() == 1 and hub.qa.lie_penalty() == 1, "mentirle a Haime: IABrain.haime_calibration_penalty() = %d y Haime lo lee (%d)" % [IABrain.haime_calibration_penalty(), hub.qa.lie_penalty()])
	# 3) Haime te convoca con el pensamiento todavía sonando (o esperando); vas y te sientas.
	PersonajesP5.set_counter("p5_qa_feedbacks", 0)
	PersonajesP5.set_counter("p5_qa_ultimo", -99999.0)
	hub.qa.test_answers = ["ok", "ok", "ok"]
	var overlaps0: int = VoiceDirector.overlaps
	p5.call("_bad_contact", ["prometer_sin_verificar", "respuesta_vaga"])
	await t.frames(1)
	await t.set_clock(hub.qa.call_at + 1.0)
	var called: bool = await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.LLAMADO, 5.0)
	t.check(called and hub.summon_pending("") == "haime", "primera convocatoria de la semana: Haime llama (pendiente: «%s»)" % hub.summon_pending(""))
	if _thinking() == null:
		ecos.think("eco_foto")  # ya había terminado: vuelve a pensarlo (como al volver a sentarte), para llegar con él sonando
		await t.frames(3)
	line = _thinking()
	t.check(line != null and not bool(RecuerdosSemana.record().get("eco_foto", false)), "el pensamiento sigue en curso y todavía no cuenta como dicho")
	await p5.call("_go_calibration", t)
	var in_session: bool = await t.until(func() -> bool: return hub.qa.state == QaFeedback.State.SESION, 5.0)
	t.check(in_session, "sentado en la sala de calibración, la sesión empieza")
	await t.until(func() -> bool: return hub.qa.session_log.size() >= 1, 30.0)
	await t.frames(2)
	# 4) Durante una calibración nadie más habla.
	t.check(line != null and bool(line.done) and str(line.result) != "dicha", "el pensamiento se corta al empezar la sesión (%s)" % (str(line.result) if line != null else "?"))
	t.check(hud_sub != null and not hud_sub.text.contains("(%s)" % agent), "y su subtítulo no queda en el HUD («%s»)" % (hud_sub.text.left(50) if hud_sub != null else "?"))
	var foreign := 0
	var who := {}
	var w := 0.0
	while hub.qa.state == QaFeedback.State.SESION and w < 300.0:
		await t.frames(1)
		w += t.get_process_delta_time()
		# («haime_replay» es la grabación de tu contacto que él mismo reproduce: es de la sesión.)
		if VoiceDirector.current != null and not str(VoiceDirector.current.speaker).begins_with("haime") and str(VoiceDirector.current.speaker) != "":
			foreign += 1
			who["%s:%s" % [str(VoiceDirector.current.speaker), str(VoiceDirector.current.id)]] = int(who.get("%s:%s" % [str(VoiceDirector.current.speaker), str(VoiceDirector.current.id)], 0)) + 1
	t.note("voces ajenas durante la sesión: %s · cortadas por la sesión: %s" % [str(who), str(hub.qa.silenced)])
	t.check(hub.qa.last_session_end == "dada" and hub.qa.lost.is_empty(), "la 1.ª calibración se da entera (fin «%s», líneas vencidas %s)" % [hub.qa.last_session_end, str(hub.qa.lost)])
	t.check(foreign == 0 and hub.qa.silenced.has("voces/agentes/%s_eco_foto" % agent.to_lower()), "ninguna voz ajena llegó a sonar durante la sesión (%d cuadros) y la sesión anotó el pensamiento como cortado (%s)" % [foreign, str(hub.qa.silenced)])
	t.check(hub.qa.beats_done.has("mentira") and str(hub.qa.session_log).contains("h2_mentira_"), "y Haime te echa en cara lo que le escribiste por Ezlaki (%s)" % str(hub.qa.beats_done))
	t.check(VoiceDirector.overlaps == overlaps0, "sin voces solapadas (%d)" % (VoiceDirector.overlaps - overlaps0))
	t.check(not bool(RecuerdosSemana.record().get("eco_foto", false)), "el pensamiento cortado no quedó como dicho")
	# 5) De vuelta en tu mesa lo vuelve a intentar, y esta vez queda dicho.
	await h2.call("_back_to_desk", t)
	var again: bool = await t.until(func() -> bool: return _thinking() != null, 12.0)
	t.check(again, "al volver a C-14 el pensamiento de la foto vuelve a intentarlo")
	# (La voz dura hasta 5,5 s reales; el plazo de `until` va en segundos de juego, a 8x en las pruebas.)
	var said: bool = await t.until(func() -> bool: return bool(RecuerdosSemana.record().get("eco_foto", false)), 160.0)
	t.check(said, "y, sin nadie que lo corte, queda dicho")
	t.check(VoiceDirector.overlaps == overlaps0, "todo el tramo sin voces solapadas (%d)" % (VoiceDirector.overlaps - overlaps0))
	IABrain.forget_all()
	await t.back_to_menu()


# --- menú × gráficos × core: cambiar de idioma con Opciones abierto desde el menú principal -------------------------

func _texts_of(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "", true, false):
		if n is Label and (n as Label).is_visible_in_tree():
			out.append((n as Label).text)
		elif n is Button and (n as Button).is_visible_in_tree():
			out.append((n as Button).text)
	return out


func _idioma_opciones(t: Node) -> void:
	var lang0 := Loc.language
	var mm: Control = t.main.main_menu
	if not mm.is_visible_in_tree():
		await t.back_to_menu()
	if Loc.language != "es":
		Loc.set_language("es")
		mm.call("_build")
		await t.frames(2)
	mm.call("_open_options")
	await t.frames(3)
	var om := mm.get("_options") as OptionsMenu
	t.check(om != null and om.get_parent() == mm, "Opciones se abre desde el menú principal")
	if om == null:
		return
	var pant := mm.get("_root") as Control  # (el nodo «Pantallas» vivo: al rearmar, el nuevo recibe otro nombre)
	t.check(pant != null and om.get_index() > pant.get_index(), "el panel se dibuja encima del menú")
	for lang in ["en", "es"]:
		var before := Loc.language
		var btn: Button = null
		for b in om.find_children("*", "Button", true, false):
			if (b as Button).text == TranslationServer.translate("MENU_LANGUAGE"):
				btn = b as Button
				break
		t.check(btn != null, "%s → %s: el botón de idioma está" % [before, lang])
		if btn == null:
			break
		btn.pressed.emit()
		await t.frames(4)
		t.check(Loc.language == lang, "%s: el idioma cambió" % lang)
		om = mm.get("_options") as OptionsMenu
		t.check(om != null and is_instance_valid(om) and om.is_visible_in_tree(), "%s: Opciones sigue abierto" % lang)
		if om == null:
			break
		# El menú se rearmó (su texto cambió de idioma) y quedó DEBAJO del panel.
		var live := mm.get("_root") as Control
		t.check(live != null and live != pant and not live.is_queued_for_deletion(), "%s: el menú se rearmó" % lang)
		pant = live
		var play := live.find_child("PlayBtn", true, false) as Button if live != null else null
		t.check(play != null and play.text == TranslationServer.translate("Q4_MENU_PLAY"), "%s: el menú de debajo se rearmó en el idioma nuevo (%s)" % [lang, play.text if play != null else "?"])
		t.check(live != null and om.get_index() > live.get_index(), "%s: el panel sigue ENCIMA del menú rearmado (panel %d, menú %d de %d)" % [lang, om.get_index(), live.get_index() if live != null else -1, mm.get_child_count()])
		var above := 0
		for i in range(om.get_index() + 1, mm.get_child_count()):
			var c := mm.get_child(i) as CanvasItem
			if c != null and c.visible and not c.is_queued_for_deletion():
				above += 1
		t.check(above == 0, "%s: nada visible del menú por encima del panel (%d)" % [lang, above])
		# La parte gráfica del panel, en el idioma nuevo.
		var texts := _texts_of(om)
		var want_q := TranslationServer.translate(GfxQuality.label_key(GfxQuality.level()))
		t.check(texts.has(want_q) and texts.has(TranslationServer.translate("OPT_QUALITY")), "%s: la fila de calidad dice «%s»" % [lang, want_q])
		var open := om.find_child("BotonGraficosAvanzados", true, false) as Button
		t.check(open != null and open.text == TranslationServer.translate("GFX_OPEN"), "%s: «%s»" % [lang, open.text if open != null else "?"])
		var other := "es" if lang == "en" else "en"
		var stale := 0
		for k in ["OPT_QUALITY", "GFX_OPEN", "OPT_GROUP_GAME", "OPT_BACK"]:
			var tr_other := str(TranslationServer.get_translation_object(other).get_message(k)) if TranslationServer.get_translation_object(other) != null else ""
			if tr_other != "" and tr_other != str(TranslationServer.translate(k)) and texts.has(tr_other):
				stale += 1
		t.check(stale == 0, "%s: ningún texto del panel quedó en el idioma anterior (%d)" % [lang, stale])
		var raw := 0
		for x in texts:
			if x.begins_with("GFX_") or x.begins_with("OPT_") or x.begins_with("MENU_"):
				raw += 1
		t.check(raw == 0, "%s: sin claves sin traducir (%d)" % [lang, raw])
		if open != null:
			open.pressed.emit()
			await t.frames(3)
			var panel := om.get_node_or_null("GfxOpciones") as Control
			t.check(panel != null, "%s: «Gráficos avanzados…» abre su panel" % lang)
			if panel != null:
				var ptexts := _texts_of(panel)
				var praw := 0
				for x in ptexts:
					if x.begins_with("GFX_") or x.begins_with("OPT_"):
						praw += 1
				t.check(praw == 0 and ptexts.size() > 8, "%s: el panel avanzado sale traducido (%d textos, %d claves crudas)" % [lang, ptexts.size(), praw])
				var close := panel.find_child("Volver", true, false) as Button
				if close != null:
					close.pressed.emit()
				else:
					panel.queue_free()
				await t.frames(3)
	om = mm.get("_options") as OptionsMenu
	if om != null and is_instance_valid(om):
		om.closed.emit()
	await t.frames(3)
	t.check(mm.get("_options") == null, "Opciones se cierra")
	if Loc.language != lang0:
		Loc.set_language(lang0)
		mm.call("_build")
		await t.frames(2)


# --- animación × gráficos: la animación de objetos sobre la capa de detalle ---------------------------------------------

func _secs(t: Node, sec: float) -> void:
	var el := 0.0
	while el < sec:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()


func _handles(leaf: Node) -> Array[String]:
	var out: Array[String] = []
	for c in leaf.get_children():
		if str(c.name) == "Manija" or str(c.name) == "GfxManija":
			if not c.is_queued_for_deletion():
				out.append(str(c.name))
	return out


func _objetos_detalle(t: Node) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	var tree: SceneTree = t.get_tree()
	await t.start_shift("Jiroshi", 1)
	GameState.stop_calm()
	var cm := tree.get_first_node_in_group("contact_manager")
	if cm != null:
		(cm as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var b: Building = t.building()
	for lv in ["alta", "media"]:
		await _quality(t, lv)
		b.go_to_floor(1, "ascensor")
		await _secs(t, 0.4)
		b.go_to_floor(2, "ascensor")
		await _secs(t, 1.0)
		await t.frames(8)
		var fl := b.floor_node as FloorBase
		var m := fl.get_node_or_null("ObjetosAnim") as ObjectAnim
		t.check(m != null and ObjectAnim.on(), "%s: la animación de objetos está activa" % lv)
		if m == null:
			continue
		m._scan_now()
		var det := fl.find_child("GfxDetalle", true, false)
		t.check(det != null and is_instance_valid(GfxDirector.inst) and int(GfxDirector.inst.detail.stats.get("sillas", 0)) > 20, "%s: el piso 2 lleva la capa de detalle (%s)" % [lv, str(GfxDirector.inst.detail.stats) if is_instance_valid(GfxDirector.inst) else "?"])
		# 1) Puertas: una sola manija por hoja, en reposo y en la copia que gira.
		var doors := 0
		var double := 0
		var bare := 0
		for n in fl.find_children("*", "", true, false):
			if not (n is WorldObjects.Door):
				continue
			var d0 := n as WorldObjects.Door
			var leaf0 := (d0.leaf if d0.leaf != null else d0.get_node_or_null("Caja")) as MeshInstance3D
			if leaf0 == null or not (leaf0.mesh is BoxMesh):
				continue
			doors += 1
			var hs := _handles(leaf0)
			if hs.size() > 1:
				double += 1
			var sz := (leaf0.mesh as BoxMesh).size
			if hs.is_empty() and sz.x <= 1.3 and sz.z <= 0.2 and sz.y >= 1.8 and not d0.open and d0.get_node_or_null("Barra") == null:
				bare += 1
		t.check(doors >= 1 and double == 0, "%s: ninguna hoja de puerta con dos manijas (%d de %d)" % [lv, double, doors])
		t.check(bare == 0, "%s: ninguna puerta de una hoja se quedó sin manija (%d)" % [lv, bare])
		var bath := fl.find_child("Bano_bano_p2", true, false) as Node3D
		var d := bath.get_node("Puerta") as WorldObjects.Door if bath != null else null
		if t.check(d != null and d.leaf != null, "%s: la puerta del baño del piso 2" % lv):
			var out_s := -signf((d.global_transform.affine_inverse() * bath.global_position).z)
			t.player().teleport(d.global_transform * Vector3(0.1, -1.0, 1.1 * out_s), 0.0)
			await t.frames(2)
			d.set_open(true)
			await t.frames(2)
			var g := d.get_node_or_null("GiroPuerta/Batiente")
			t.check(g != null and _handles(g) == ["Manija"], "%s: la copia batiente lleva una manija, la de palanca (%s)" % [lv, str(_handles(g)) if g != null else "sin copia"])
			await _secs(t, 1.2)
			d.set_open(false)
			await _secs(t, 1.6)
			t.check(d.leaf.visible and _handles(d.leaf) == ["Manija"], "%s: cerrada, la hoja de verdad vuelve con su única manija (%s)" % [lv, str(_handles(d.leaf))])
		# 2) Sillas: la malla es la de trabajo del paquete gráfico y la animación mueve la silla ENTERA.
		var who: NpcAnimator = null
		for a in NpcAnimator._all:
			if is_instance_valid(a) and a.slug.begins_with("agente_") and a.state == "seated" and a.body != null and a.body.is_inside_tree() and fl.is_ancestor_of(a.body):
				who = a
				break
		if t.check(who != null, "%s: hay un compañero sentado" % lv):
			var rec := m._chair_near(who.body.global_position)
			if t.check(not rec.is_empty(), "%s: su silla está censada" % lv):
				var seat := rec["parts"][0] as MeshInstance3D
				var back := rec["parts"][1] as MeshInstance3D
				var base := (rec["root"] as Node3D).get_node_or_null("Base") as Node3D
				var star := base.get_node_or_null("Estrella") as MeshInstance3D if base != null else null
				t.check(seat != null and not (seat.mesh is BoxMesh) and back != null and not (back.mesh is BoxMesh) and star != null and not (star.mesh is CylinderMesh), "%s: asiento, respaldo y estrella llevan la malla de la silla de trabajo" % lv)
				var seat0 := seat.global_position
				var star0 := star.global_position if star != null else Vector3.ZERO
				t.player().teleport(who.body.global_position + Vector3(0, 0, 3.0), 180.0)
				await t.frames(3)
				var rig := who.body as CharacterRig
				rig.play("idle")
				var started: bool = await t.until(func() -> bool: return m._chair_busy(rec), 3.0)
				await _secs(t, 3.4)
				var ds := Vector2(seat.global_position.x - seat0.x, seat.global_position.z - seat0.z).length()
				var dst := Vector2(star.global_position.x - star0.x, star.global_position.z - star0.z).length() if star != null else -1.0
				t.check(started and ds > 0.3 and absf(ds - dst) < 0.12, "%s: al pararse la silla rueda entera: asiento %.2f m, estrella de ruedas %.2f m" % [lv, ds, dst])
				rig.play("type", true, 0.9, ["sit", "idle"])
				await t.until(func() -> bool: return m._chair_busy(rec), 3.0)
				await _secs(t, 3.4)
				t.check(seat.global_position.distance_to(seat0) < 0.005 and (star == null or star.global_position.distance_to(star0) < 0.005), "%s: al sentarse vuelve exactamente a su sitio (%.3f m)" % [lv, seat.global_position.distance_to(seat0)])
				t.check(not (seat.mesh is BoxMesh), "%s: y sigue siendo la silla de trabajo" % lv)
		# 3) Monitor de C-14: despierta con su parpadeo aunque el paquete gráfico vista el puesto.
		var scr: MonitorScreen = null
		for sc in tree.get_nodes_in_group("monitor_screens"):
			if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14" and fl.is_ancestor_of(sc as Node):
				scr = sc as MonitorScreen
		if t.check(scr != null, "%s: el monitor de C-14" % lv):
			scr.set_powered(false)
			await _secs(t, 0.9)
			var quad := scr.get("_quad") as GeometryInstance3D
			var off_visible: bool = quad != null and quad.visible
			scr.set_powered(true)
			await _secs(t, 1.4)
			t.check(quad != null and quad.visible and quad.is_visible_in_tree() and scr.powered, "%s: el monitor vuelve a encenderse (apagado se veía: %s)" % [lv, str(off_visible)])
	# 4) Modo liviano: se van las dos capas.
	await _quality(t, "liviano")
	await _secs(t, 0.6)
	var fl2 := b.floor_node as FloorBase
	var m2 := fl2.get_node_or_null("ObjetosAnim") as ObjectAnim
	t.check(GfxQuality.is_light() and not ObjectAnim.on(), "liviano: la animación de objetos queda apagada")
	t.check(fl2.find_child("GfxDetalle", true, false) == null or (fl2.find_child("GfxDetalle", true, false) as Node).is_queued_for_deletion(), "liviano: sin capa de detalle")
	var copies := 0
	var gfx_handles := 0
	for n in fl2.find_children("*", "", true, false):
		if str(n.name).begins_with("GiroPuerta") and not n.is_queued_for_deletion():
			copies += 1
		if str(n.name) == "GfxManija" and not n.is_queued_for_deletion():
			gfx_handles += 1
	t.check(copies == 0 and gfx_handles == 0, "liviano: sin copias batientes ni manijas de detalle (%d, %d)" % [copies, gfx_handles])
	var boxes := 0
	var total := 0
	for n in fl2.find_children("Silla", "MeshInstance3D", true, false):
		total += 1
		if (n as MeshInstance3D).mesh is BoxMesh:
			boxes += 1
	t.check(total > 20 and boxes == total, "liviano: las sillas vuelven a ser las del juego base (%d de %d)" % [boxes, total])
	if m2 != null:
		ObjectAnim.prof_on = true
		ObjectAnim.prof_usec = 0
		ObjectAnim.prof_frames = 0
		await _secs(t, 0.8)
		ObjectAnim.prof_on = false
		t.check(ObjectAnim.prof_frames == 0, "liviano: el gestor de objetos no gasta nada por cuadro (%d cuadros)" % ObjectAnim.prof_frames)
	await _quality(t, q0)
	await t.back_to_menu()


# --- muertes × gráficos: los ganchos KillGore.gfx con las clases del paquete gráfico ----------------------------------

func _light_sum(fl: Node) -> float:
	var e := 0.0
	if fl == null:
		return e
	for l in fl.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		if li.is_visible_in_tree():
			e += li.light_energy
	return e


## Mata con `cause` y sigue la muerte hasta la pantalla. Devuelve lo que se vio por el camino.
func _death_watch(t: Node, cause: String) -> Dictionary:
	var out := {"min_sum": INF, "apagon": false, "k_min": 1.0, "shown": false, "asesino": false}
	GameState.stop_calm()
	await t.seconds(Checkpoints.GRACE_S + 0.1)
	var killer := Checkpoints.killer_of(cause)
	var cap := 10.0
	if Checkpoints.uses_screamer(killer) and Screamers.has_row(cause):
		cap = maxf(cap, Screamers.duration(killer, cause) + 8.0)
	t.die(cause, "1")
	var w := 0.0
	while w < cap and not (Checkpoints.death_visible and t.death_screen().visible):
		await t.get_tree().process_frame
		w += t.get_process_delta_time()
		var fl := _floor_of(t)
		out["min_sum"] = minf(float(out["min_sum"]), _light_sum(fl))
		if is_instance_valid(GfxDirector.inst):
			var L: GfxLights = GfxDirector.inst.lights
			if L._blackout_left > 0.0 and L._blackout_k < 0.5:
				out["apagon"] = true
				out["k_min"] = minf(float(out["k_min"]), L._blackout_k)
		if t.get_tree().root.find_child("Asesino_*", true, false) != null:
			out["asesino"] = true
	out["shown"] = Checkpoints.death_visible and t.death_screen().visible
	return out


func _muertes_graficos(t: Node) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	await t.start_shift("Jiroshi", 1)
	var cm := t.main.get("contacts") as Node
	if cm != null:
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	await t.login_at_seat()
	# --- Alta: los tres ganchos, el apagón de verdad y todo devuelto al reconectar ---
	await _quality(t, "alta")
	await t.seconds(1.0)
	t.check(is_instance_valid(GfxDirector.inst) and GfxDirector.inst.lights.active and GfxCharacters.wanted(), "alta: luces y acabado de personajes del paquete gráfico activos")
	var e0 := _light_sum(_floor_of(t))
	KillGore.gfx_calls.clear()
	var r: Dictionary = await _death_watch(t, "tercer_ww")
	var calls: Dictionary = KillGore.gfx_calls.duplicate()
	t.note("alta · tercer_ww: ganchos %s · luz del piso %.1f → mínimo %.1f · apagón visto %s (nivel %.2f)" % [str(calls), e0, float(r["min_sum"]), str(r["apagon"]), float(r["k_min"])])
	t.check(bool(r["shown"]) and bool(r["asesino"]), "alta: la muerte corre entera hasta la pantalla")
	t.check(int(calls.get("GfxDirector.blackout", 0)) > 0 and bool(r["apagon"]), "alta: el apagón del screamer pasa por GfxDirector.blackout (%d llamadas) y el gestor de luces lo aplica" % int(calls.get("GfxDirector.blackout", 0)))
	t.check(float(r["min_sum"]) < e0 * 0.3, "alta: el piso queda a oscuras de verdad (suma de luces %.1f de %.1f)" % [float(r["min_sum"]), e0])
	t.check(int(calls.get("GfxLens.kick", 0)) > 0, "alta: los golpes y el grito empujan la lente (GfxLens.kick ×%d)" % int(calls.get("GfxLens.kick", 0)))
	t.check(int(calls.get("GfxCharacters.dress", 0)) > 0, "alta: el modelo del asesino recibe el acabado de personajes (GfxCharacters.dress ×%d)" % int(calls.get("GfxCharacters.dress", 0)))
	await t.reconnect()
	await t.seconds(2.0)
	await t.frames(6)
	var L1: GfxLights = GfxDirector.inst.lights
	var e1 := _light_sum(_floor_of(t))
	t.check(L1._blackout_left <= 0.0 or L1._blackout_k >= 0.999, "alta: al reconectar no queda apagón pendiente (%.2f s a nivel %.2f)" % [L1._blackout_left, L1._blackout_k])
	t.check(absf(e1 - e0) < e0 * 0.25, "alta: las luces del piso vuelven a su energía (%.1f antes, %.1f después)" % [e0, e1])
	t.check(GfxLens.scare_level() < 0.05 and not bool(GfxDirector.inst.get("_dying")), "alta: lente en reposo y el director ya no está «muriendo» (%.2f)" % GfxLens.scare_level())
	t.check(t.get_tree().root.find_child("Asesino_*", true, false) == null and not Checkpoints.dying and not t.death_screen().visible, "alta: no queda nada del screamer en escena")
	# --- Baja y Modo liviano: los ganchos no cuestan nada ---
	for lv in ["baja", "liviano"]:
		await _quality(t, lv)
		await t.seconds(0.6)
		if not t.player().seated:
			await t.login_at_seat()
		var saved0: int = GfxCharacters._saved.size()
		var b0 := _light_sum(_floor_of(t))
		KillGore.gfx_calls.clear()
		var r2: Dictionary = await _death_watch(t, "tercer_ww")
		t.check(bool(r2["shown"]), "%s: la muerte corre entera" % lv)
		t.check(not GfxCharacters.wanted() and GfxCharacters._saved.size() == 0 and saved0 == 0, "%s: ningún material vestido por el acabado de personajes (%d)" % [lv, GfxCharacters._saved.size()])
		t.check(not bool(r2["apagon"]) or not GfxDirector.inst.lights.active, "%s: el gestor de luces del paquete gráfico no interviene" % lv)
		await t.reconnect()
		await t.seconds(2.0)
		await t.frames(6)
		var b1 := _light_sum(_floor_of(t))
		t.check(absf(b1 - b0) < maxf(b0 * 0.25, 0.5), "%s: las luces del piso vuelven a como estaban (%.1f antes, %.1f después)" % [lv, b0, b1])
		t.note("%s · tercer_ww: ganchos %s · luz %.1f → mínimo %.1f → %.1f" % [lv, str(KillGore.gfx_calls), b0, float(r2["min_sum"]), b1])
	await _quality(t, q0)
	await t.back_to_menu()


# --- gráficos: lo chico y lo que se lee va sin relieve genérico -----------------------------------------------------

## [con relieve, lisos, infractores (deberían ir lisos y llevan relieve), nombres de infractores]
func _relief_census(fl: Node) -> Array:
	var relief := 0
	var plain := 0
	var bad: Array[String] = []
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.is_queued_for_deletion():
			continue
		var liso := false
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null and m.has_meta("gfx_liso"):
				liso = true
		if liso:
			plain += 1
		if GfxMaterials.has_relief(mi):
			relief += 1
			if GfxMaterials.wants_plain(mi):
				bad.append(str(mi.name))
	return [relief, plain, bad]


func _objetos_lisos(t: Node) -> void:
	var q0 := str(Loc.get_setting("quality", "media"))
	var tree: SceneTree = t.get_tree()
	await t.start_shift("Jiroshi", 1)
	GameState.stop_calm()
	var cm := tree.get_first_node_in_group("contact_manager")
	if cm != null:
		(cm as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var b: Building = t.building()
	for lv in ["alta", "media"]:
		await _quality(t, lv)
		for f in [1, -1, 2]:
			b.go_to_floor(f, "ascensor")
			await _secs(t, 1.2)
			await t.frames(10)
			var fl: Node = b.floor_node
			var c: Array = _relief_census(fl)
			var bad: Array = c[2]
			t.check(bad.is_empty(), "%s · piso %d: nada chico, de papel o con texto lleva relieve genérico (%d: %s)" % [lv, f, bad.size(), str(bad.slice(0, 8))])
			t.check(int(c[1]) >= 10 and int(c[0]) >= 60, "%s · piso %d: %d piezas lisas y %d (paredes, muebles) conservan su relieve" % [lv, f, int(c[1]), int(c[0])])
			# lo que se lee, por nombre
			var notes := 0
			var notes_bad := 0
			for n in fl.find_children("Nota_*", "MeshInstance3D", true, false):
				notes += 1
				if GfxMaterials.has_relief(n as MeshInstance3D):
					notes_bad += 1
			t.check(notes >= 1 and notes_bad == 0, "%s · piso %d: las %d notas van lisas" % [lv, f, notes])
			for pat in ["Cartel_*", "Pizarra*", "Fotocheck", "Btn*", "Sticker*", "Etiqueta*", "Foto*", "Mural*", "Papel", "Papel_*", "Cuaderno*"]:
				var seen := 0
				var wrong := 0
				for n in fl.find_children(pat, "MeshInstance3D", true, false):
					seen += 1
					if GfxMaterials.has_relief(n as MeshInstance3D):
						wrong += 1
				if seen > 0:
					t.check(wrong == 0, "%s · piso %d: %s sin relieve (%d de %d)" % [lv, f, pat, wrong, seen])
		# piso 2: la taza de C-13
		var fl2: Node = b.floor_node
		var cub := fl2.find_child("Cub_C-13", true, false) as Node3D
		var mug := cub.get_node_or_null("Taza") as MeshInstance3D if cub != null else null
		if t.check(mug != null, "%s: la taza de C-13 está" % lv):
			t.check(not (mug.mesh is BoxMesh) and mug.mesh.get_surface_count() >= 2 and not GfxMaterials.has_relief(mug), "%s: es una taza (malla nueva en el mismo nodo, %d superficies) y sin relieve" % [lv, mug.mesh.get_surface_count()])
			var aabb := mug.mesh.get_aabb()
			t.check(aabb.size.y > 0.08 and aabb.size.y < 0.11 and absf(aabb.position.y + 0.05) < 0.006, "%s: apoya en la mesa como la caja original (base a %.3f m del centro, alto %.3f)" % [lv, aabb.position.y, aabb.size.y])
			t.player().teleport(Vector3(mug.global_position.x, (fl2 as Node3D).global_position.y, mug.global_position.z + 1.5), 0.0)
			GameState.clock_seconds = 300.0
			await _secs(t, 1.0)
			var steam := mug.get_node_or_null("Vapor") as CPUParticles3D
			t.check(steam != null and steam.emitting, "%s: y sigue humeando (el vapor cuelga del mismo nodo)" % lv)
		# algo que aparece después: una nota nueva y un tabique nuevo
		var note := Greybox.box(fl2, "Nota_PRUEBA_FIN", Vector3(20.0, 1.2, 0.5), Vector3(0.09, 0.09, 0.004), Greybox.BLANCO, false)
		var lb := Label3D.new()
		lb.text = "prueba"
		note.add_child(lb)
		var wall := Greybox.box(fl2, "TabiquePruebaFin", Vector3(20.0, 1.2, 0.9), Vector3(2.4, 2.4, 0.15), Greybox.BLANCO, false)
		await _secs(t, 0.9)
		await t.frames(4)
		t.check(not GfxMaterials.has_relief(note), "%s: una nota que aparece a mitad de turno también queda lisa" % lv)
		t.check(GfxMaterials.has_relief(wall), "%s: y un tabique nuevo del mismo color conserva su relieve" % lv)
		note.queue_free()
		wall.queue_free()
		await t.frames(2)
	# --- vuelta a Baja: todo como lo dejó el juego ---
	await _quality(t, "baja")
	await t.frames(6)
	var fl3: Node = b.floor_node
	var left := 0
	for n in fl3.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null and (m.has_meta("gfx_liso") or GfxMaterials.is_generic(m)):
				left += 1
	t.check(left == 0 and GfxMaterials._plain_log.is_empty() and GfxMaterials._twins.is_empty(), "baja: no queda ningún gemelo liso ni relieve (%d)" % left)
	var cub3 := fl3.find_child("Cub_C-13", true, false) as Node3D
	var mug3 := cub3.get_node_or_null("Taza") as MeshInstance3D if cub3 != null else null
	t.check(mug3 != null and mug3.mesh is BoxMesh and mug3.material_override == Greybox.material(Greybox.BLANCO), "baja: la taza vuelve a ser la caja del juego base con su material")
	await _quality(t, q0)
	await t.back_to_menu()


# --- voces × animación × Main: nada del turno anterior llega al siguiente ------------------------------------------

func _voces_turno_nuevo(t: Node) -> void:
	await t.start_shift("Marko", 1)
	await t.login_at_seat()
	await t.frames(4)
	# 1) Una línea con reproductor 3D propio cuyo dueño se libera antes de que le toque.
	var holder := Node3D.new()
	t.building().floor_node.add_child(holder)
	var pl := AudioStreamPlayer3D.new()
	holder.add_child(pl)
	var first := VoiceDirector.say("voces/shero/reflejo_mirando", VoiceDirector.P.DIRECTO, "shero")
	var ext := VoiceDirector.say_external(pl, "voces/rasec/fin_evento", VoiceDirector.P.DIRECTO, "rasec")
	t.check(ext != null, "hay una línea externa en cola detrás de otra")
	holder.queue_free()
	await t.frames(3)
	if first != null and not first.done:
		VoiceDirector.cancel(first, "prueba")
	await t.seconds(1.0)
	await t.frames(4)
	# Directo al oyente del gesto de hablar: una línea cuyo reproductor ya no existe.
	var hub_sp: Node = null
	for c in t.get_tree().root.get_children():
		if c.has_method("_in_person"):
			hub_sp = c
	t.check(hub_sp != null, "el oyente de voces de la animación (SpeechHub) está en la raíz")
	if hub_sp != null:
		var pl2 := AudioStreamPlayer3D.new()
		t.get_tree().root.add_child(pl2)
		var fake := VoiceDirector.Line.new()
		fake.bus = "Sala"
		fake.external = pl2
		pl2.free()
		var res: Variant = hub_sp.call("_in_person", fake)
		t.check(res is bool and bool(res), "una línea cuyo reproductor 3D ya fue liberado se trata como voz de la sala, sin error (%s)" % str(res))
		var own: Variant = hub_sp.call("_owner_of", fake)
		var sub_ok := true
		VoiceDirector.current = fake
		fake.speaker = "shero"
		fake.id = "prueba_fin"
		hub_sp.call("_on_sub", "shero", "Sigo mirando. Tú sigue.", 2.0)  # el camino entero que recorre el subtítulo de la línea
		VoiceDirector.current = null
		t.check(own == null and sub_ok, "y nadie figura como su dueño; el subtítulo de esa línea recorre el oyente entero sin error")
	# 2) Voces y avisos pendientes y un turno nuevo abierto en directo (como Main._after_training y los bots).
	VoiceDirector.stop_all("prueba")
	VoiceDirector.notice("rasec", "Agente Marko, al centro de la sala. Todos te estamos esperando.", 6.0, true)
	VoiceDirector.notice("shero", "Marko. A mi oficina.", 6.0, true)
	var a := VoiceDirector.say("voces/shero/reflejo_mirando", VoiceDirector.P.DIRECTO, "shero")
	var b := VoiceDirector.say("voces/rasec/fin_evento", VoiceDirector.P.DIRECTO, "rasec")
	await t.frames(2)
	t.check(VoiceDirector.notices.size() + (1 if VoiceDirector.current != null else 0) + VoiceDirector.queue.size() >= 2, "al cerrar el turno quedan voces y avisos pendientes (%d avisos, %d en cola)" % [VoiceDirector.notices.size(), VoiceDirector.queue.size()])
	t.main.call("_start_shift", "Marko", GameState.Mode.NORMAL, 1)
	t.check(VoiceDirector.queue.is_empty() and VoiceDirector.current == null and VoiceDirector.notices.is_empty(), "el turno nuevo arranca sin voces en cola ni avisos del anterior (%d en cola, %d avisos)" % [VoiceDirector.queue.size(), VoiceDirector.notices.size()])
	t.check((a == null or a.done) and (b == null or b.done), "las líneas del turno anterior quedaron cerradas")
	await t.seconds(2.0)
	var hud_sub := t.main.hud.get("_sub") as Label
	t.check(hud_sub != null and not hud_sub.text.contains("centro de la sala") and not hud_sub.text.contains("oficina"), "y no asoma ningún subtítulo viejo («%s»)" % (hud_sub.text if hud_sub != null else "—"))
	t.check(GameState.running and t.building() != null, "el turno nuevo está en marcha")
	await t.back_to_menu()


# --- muertes × Main: salir al menú con la muerte a medias ---------------------------------------------------------------

func _menu_en_plena_muerte(t: Node) -> void:
	# [causa, segundo de la muerte en el que sales]: la fusión de Vitzo es larga y por etapas: se sale en cada una.
	for pair in [["vitzo_reminder", 2.5], ["vitzo_reminder", 9.5], ["vitzo_reminder", 15.0], ["vitzo_reminder", 19.0], ["tercer_ww", 2.5], ["calibracion_final", 2.5], ["colapso", 1.0], ["wmm_pod_correo", 2.2], ["correo_vitzo", 2.0]]:
		var cause := str(pair[0])
		var at_s := float(pair[1])
		await t.start_shift("Marko", 2)
		await t.login_at_seat()
		GameState.stop_calm()
		await t.seconds(Checkpoints.GRACE_S + 0.1)
		t.die(cause, "1")
		await t.frames(2)
		if not t.check(Checkpoints.dying, "%s: la muerte arranca" % cause):
			await t.back_to_menu()
			continue
		var killer := Checkpoints.killer_of(str(pair[0]))
		var total := Screamers.duration(killer, str(pair[0])) if Checkpoints.uses_screamer(killer) and Screamers.has_row(str(pair[0])) else 3.0
		at_s = minf(at_s, maxf(total - 2.0, 0.5))
		await t.seconds(at_s)
		cause = "%s@%.1fs" % [cause, at_s]
		t.check(not t.main.main_menu.visible, "%s: sales con la muerte en curso (dura %.1f s)" % [cause, total])
		# Lo que hace «Salir al menú» de la pausa.
		t.main.call("_back_to_menu")
		await t.frames(3)
		t.check(t.main.main_menu.visible and not GameState.running and not Checkpoints.dying, "%s: estás en el menú, sin muerte en curso" % cause)
		await t.seconds(total + 3.0)  # la coreografía que quedó a medias ya habría terminado
		await t.frames(3)
		var left: Array[String] = []
		for n in t.get_tree().root.find_children("Asesino_*", "", true, false):
			if not n.is_queued_for_deletion():
				left.append(str(n.name))
		for n in t.get_tree().root.find_children("*", "CanvasLayer", true, false):
			var nm := str(n.name)
			if (nm.begins_with("Screamer") or nm.begins_with("Kill") or nm.begins_with("Muerte") or nm.begins_with("Gore")) and (n as CanvasLayer).visible and not n.is_queued_for_deletion():
				left.append(nm)
		t.check(left.is_empty(), "%s: no queda nada del screamer en escena ni en pantalla (%s)" % [cause, str(left)])
		t.check(not t.death_screen().visible and t.main.main_menu.visible, "%s: la pantalla de muerte no aparece sola en el menú" % cause)
		t.check(Engine.time_scale > 0.0 and not t.get_tree().paused, "%s: el juego no queda en pausa ni congelado" % cause)
		# El turno siguiente arranca limpio.
		await t.start_shift("Marko", 1)
		await t.seconds(2.0)
		t.check(GameState.running and not Checkpoints.dying and not t.death_screen().visible and not t.player().input_locked, "%s: el turno siguiente arranca sin muerte heredada y con control" % cause)
		await t.back_to_menu()


# --- muertes × VoiceDirector: el cliente sigue en la línea mientras te desplomas -------------------------------------------

func _colapso_cliente(t: Node) -> void:
	var lang0 := Loc.language
	for lang in ["es", "en"]:
		if Loc.language != lang:
			Loc.set_language(lang)
		await t.start_shift("Marko", 1)
		await t.login_at_seat()
		GameState.stop_calm()
		VoiceDirector.reset_audit()
		var cm := t.main.get("contacts") as ContactManager
		var first: Dictionary = cm.next_scripted()
		await t.set_clock(ContactManager.clock_of(str(first.get("hora_juego", "00:30"))) + 5.0)
		var offered: bool = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING, 8.0)
		if offered:
			cm.accept()
		await t.frames(4)
		if not t.check(offered and cm.is_active() and str(cm.current.get("canal", "")) == "llamada", "%s: llamada en curso (%s, canal %s)" % [lang, str(cm.current.get("id", "")), str(cm.current.get("canal", ""))]):
			await t.back_to_menu()
			continue
		await t.seconds(Checkpoints.GRACE_S + 0.1)
		var started: Array = []
		var subs: Array = []
		var on_line := func(id: String, sp: String, pr: int) -> void: started.append([id, sp, pr])
		var on_sub := func(sp: String, tx: String, _s: float) -> void:
			if tx != "":
				subs.append([sp, tx])
		var dying: Array = t.spy("death_sequence_started")
		var shown: Array = t.spy("death_shown")
		# Tu silla, pieza por pieza (asiento, respaldo y base de ruedas del mismo cubículo), antes de que te desplomes.
		var seat_mi: Node3D = null
		for n in FloorBase.active.find_children("Silla", "MeshInstance3D", true, false):
			var d2: Vector3 = (n as Node3D).global_position - (t.player() as Player).global_position
			d2.y = 0.0
			if d2.length() < 0.6:
				seat_mi = n as Node3D
		var chair: Array = []
		if seat_mi != null:
			for nm in ["Silla", "Respaldo", "Base"]:
				var part := seat_mi.get_parent().get_node_or_null(nm) as Node3D
				if part != null:
					chair.append([part, part.global_transform])
		Fatigue.set_value(99.0)
		Fatigue.add(10.0)
		var began: bool = await t.until(func() -> bool: return not dying.is_empty(), 3.0)
		if not t.check(began and str(dying[0][0]) == "colapso" and Checkpoints.dying, "%s: la Fatiga te desploma en plena llamada (%s)" % [lang, str(dying)]):
			await t.back_to_menu()
			continue
		VoiceDirector.line_started.connect(on_line)
		VoiceDirector.subtitle_shown.connect(on_sub)
		# Los demás quieren hablar durante la toma: nadie pasa (ni voz, ni subtítulo suelto, ni aviso). El director los
		# descarta en el acto, así que se mira en este mismo cuadro (sin depender del ritmo de cuadros de la máquina).
		AudioManager.play_voice("comp", "comp_viene_shero", tr("COMP_VIENE_SHERO"), "Sala")
		EventBus.subtitle.emit("shero", "Shero: Bien.", 2.0)
		EventBus.subtitle.emit("ezlak", "Aviso de Ezlaki", 3.0)
		VoiceDirector.notice("rasec", "Agente Marko, al centro de la sala.", 4.0, true)
		t.check(started.is_empty() and subs.is_empty() and VoiceDirector.current == null and VoiceDirector.queue.is_empty() and VoiceDirector.notices.is_empty() and VoiceDirector.notice_current.is_empty(),
			"%s: antes de la línea del cliente nadie habla (%d voces, %d subtítulos, %d avisos)" % [lang, started.size(), subs.size(), VoiceDirector.notices.size()])
		# Toda la toma, cuadro a cuadro (un vigía en process_frame: con la máquina cargada y el tiempo ×8 un cuadro puede
		# valer casi un segundo de juego, así que nada se mira «N cuadros después»): la voz, su subtítulo, la silla.
		var want := tr("K2_COLAPSO_ALO")
		var hud_sub := t.main.hud.get("_sub") as Label
		var w := {"voz": false, "path": "", "sub": false, "hud": false, "intr": false, "rigid": true, "moved": [0.0, 0.0, 0.0], "cuadros": 0}
		var watch := func() -> void:
			var fx: DeathAnimations = null
			for n in t.get_tree().get_nodes_in_group(DeathAnimations.GROUP):
				if not n.is_queued_for_deletion():
					fx = n as DeathAnimations
			if fx == null:
				return
			w["cuadros"] = int(w["cuadros"]) + 1
			var cur := VoiceDirector.current
			if cur != null and cur.id == DeathAnimations.ALO_SLOT:
				var vp := VoiceDirector.get("_player") as AudioStreamPlayer
				if vp != null and vp.playing and str(vp.bus) == "Auricular" and is_equal_approx(vp.volume_db, AudioManager.gain_db(DeathAnimations.ALO_SLOT)) and absf(vp.volume_db) <= 1.0:
					w["voz"] = true
				w["path"] = cur.path
				# La tercera persona esconde el HUD: el subtítulo se ve en la capa de la toma (el HUD, escondido, lleva el mismo).
				var ts := fx.get_node_or_null("SubtituloToma") as Label
				if ts != null and ts.text == want and ts.is_visible_in_tree() and (ts.get_parent() as CanvasLayer).layer >= 19:
					w["sub"] = true
					if hud_sub != null and hud_sub.text == want and not hud_sub.is_visible_in_tree():
						w["hud"] = true
				if not bool(w["intr"]):
					w["intr"] = true  # mientras suena, los demás siguen sin pasar
					AudioManager.play_voice("comp", "comp_viene_shero", tr("COMP_VIENE_SHERO"), "Sala")
					EventBus.subtitle.emit("shero", "Shero: Bien.", 2.0)
			if chair.size() == 3 and fx._third != null and is_instance_valid(fx._third):
				var s0: Vector3 = (chair[0][1] as Transform3D).origin
				var s1: Vector3 = (chair[0][0] as Node3D).global_position
				for i in 3:
					var now: Vector3 = (chair[i][0] as Node3D).global_position
					var was: Vector3 = (chair[i][1] as Transform3D).origin
					(w["moved"] as Array)[i] = maxf(float((w["moved"] as Array)[i]), Vector2(now.x - was.x, now.z - was.z).length())
					if absf(now.distance_to(s1) - was.distance_to(s0)) > 0.02 or absf(now.y - was.y) > 0.02:
						w["rigid"] = false
		t.get_tree().process_frame.connect(watch)
		var ended: bool = await t.until(func() -> bool: return not shown.is_empty(), 14.0)
		t.get_tree().process_frame.disconnect(watch)
		t.check(ended and Checkpoints.death_visible, "%s: «Usuario desconectado» llega al terminar la toma" % lang)
		# La línea del cliente, a los 2,55 s de la toma (oyó el golpe contra el escritorio).
		t.check(started.size() == 1 and str(started[0][0]) == DeathAnimations.ALO_SLOT and str(started[0][1]) == "cliente" and int(started[0][2]) == VoiceDirector.P.SCREAMER,
			"%s: suena la línea del cliente y solo ella, como voz de la toma (%s)" % [lang, str(started)])
		t.check(subs.size() == 1 and str(subs[0][0]) == "cliente" and str(subs[0][1]) == want, "%s: con su subtítulo y solo el suyo (%s)" % [lang, str(subs)])
		t.check(bool(w["voz"]), "%s: por el auricular, al nivel de la toma (%.1f dB; %d cuadros mirados)" % [lang, AudioManager.gain_db(DeathAnimations.ALO_SLOT), int(w["cuadros"])])
		var spath := str(w["path"])
		t.check(spath.contains("/clientes/en/") == (lang == "en") and spath.contains("colapso_alo"), "%s: la voz es la de su idioma (%s)" % [lang, spath])
		t.check(bool(w["sub"]), "%s: el subtítulo se ve en la capa de la toma: «%s»" % [lang, want])
		t.check(bool(w["hud"]), "%s: el HUD (escondido por la tercera persona) lleva el mismo texto, sin verse dos veces" % lang)
		t.check(bool(w["intr"]), "%s: mientras suena, un compañero y Shero intentan hablar (y no pasan: sigue habiendo una sola voz y un solo subtítulo)" % lang)
		# La silla sale rodando ENTERA cuando resbalas (antes solo el asiento: el respaldo y la base se quedaban).
		var moved: Array = w["moved"]
		t.note("%s: silla · asiento %.2f m, respaldo %.2f m, base %.2f m · %d cuadros" % [lang, float(moved[0]), float(moved[1]), float(moved[2]), int(w["cuadros"])])
		t.check(chair.size() == 3 and float(moved.min()) > 0.4 and bool(w["rigid"]), "%s: la silla rueda entera, sin desarmarse ni despegarse del piso (%d piezas: asiento %.2f m, respaldo %.2f m, base %.2f m)" % [lang, chair.size(), float(moved[0]), float(moved[1]), float(moved[2])])
		await t.reconnect()
		await t.frames(4)
		var back_ok := true
		for e in chair:
			if not ((e[0] as Node3D).global_transform as Transform3D).is_equal_approx(e[1] as Transform3D):
				back_ok = false
		t.check(back_ok and t.player().seated, "%s: al reconectar la silla está entera en su sitio y tú sentado en ella" % lang)
		var cur := VoiceDirector.current
		t.check((cur == null or cur.id != DeathAnimations.ALO_SLOT) and (hud_sub == null or hud_sub.text != tr("K2_COLAPSO_ALO")), "%s: al reconectar no queda la voz del cliente ni su subtítulo" % lang)
		t.check(VoiceDirector.overlaps == 0 and VoiceDirector.lost_important.is_empty(), "%s: sin solapes ni líneas importantes perdidas (%d, %s)" % [lang, VoiceDirector.overlaps, str(VoiceDirector.lost_important)])
		VoiceDirector.line_started.disconnect(on_line)
		VoiceDirector.subtitle_shown.disconnect(on_sub)
		await t.back_to_menu()
	if Loc.language != lang0:
		Loc.set_language(lang0)


# --- Haime × VoiceDirector × audio: el veto al empezar no inventa pérdidas ---------------------------------------------

func _veto_sin_perdidas(t: Node) -> void:
	await t.start_shift("Marko", 3)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.frames(4)
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	VoiceDirector.reset_audit()
	# Como la calibración de Haime: quien escucha line_started le quita la palabra a los demás en el acto.
	var veto := func(_id: String, sp: String, _pr: int) -> void:
		if sp != "haime" and VoiceDirector.current != null:
			VoiceDirector.cancel(VoiceDirector.current, "calibración")
	VoiceDirector.line_started.connect(veto)
	# 1) Un personaje: la voz sin texto y su subtítulo enseguida (PersonajesP5.say).
	var txt := str(PersonajesP5.line("lineas_rasec", "musica_off"))
	PersonajesP5.say("Rasec", "rasec", "musica_off", txt)
	await t.frames(3)
	var noticed := false
	for e in VoiceDirector.notice_log:
		if str(e[2]).contains(txt.left(20)):
			noticed = true
	t.check(txt != "" and VoiceDirector.lost_important.is_empty(), "Rasec vetado al empezar: no cuenta como importante perdida (%s)" % str(VoiceDirector.lost_important))
	t.check(noticed and VoiceDirector.current == null, "y su texto sale como aviso («%s…»), sin voz" % txt.left(28))
	# 2) Un anuncio por los parlantes (voz por el bus Parlantes + subtítulo «parlantes»).
	PersonajesP5.pa("El ascensor 2 sigue en mantenimiento. No lo esperen.", "shero", "shero_bien")
	await t.frames(3)
	t.check(VoiceDirector.lost_important.is_empty(), "un anuncio por los parlantes vetado: tampoco (%s)" % str(VoiceDirector.lost_important))
	# 3) Los sustos de ambiente con voz (parlantes y auricular): relleno.
	var ha: HorrorAmbience = AudioManager.director.get("horror")
	var fired := 0
	if ha != null:
		for e in HorrorAmbience.EVENTS:
			if str(e.get("donde", "")) in ["parlantes", "auricular"] and AudioManager.has_slot(str(e["slot"])):
				ha.fire(e)
				fired += 1
				await t.frames(3)
	t.check(fired == 2 and VoiceDirector.lost_important.is_empty(), "los %d sustos de ambiente con voz, vetados: relleno, nada perdido (%s)" % [fired, str(VoiceDirector.lost_important)])
	# 4) Una importante de verdad, sin texto y sin subtítulo detrás: esa sí queda anotada.
	VoiceDirector.say("voces/shero/esc_lunch_verbal", -1, "shero")
	await t.frames(4)
	t.check(VoiceDirector.lost_important.size() == 1 and str(VoiceDirector.lost_important[0][1]) == "voces/shero/esc_lunch_verbal", "una importante sin texto vetada sí queda como perdida (%s)" % str(VoiceDirector.lost_important))
	VoiceDirector.line_started.disconnect(veto)
	VoiceDirector.stop_all("prueba")
	VoiceDirector.clear_notices()
	VoiceDirector.reset_audit()
	await t.back_to_menu()


# --- mundo × bots: dos pedidos de ascensor a la vez -----------------------------------------------------------------------

func _ascensor_doble(t: Node) -> void:
	await t.start_shift("Marko", 2)
	GameState.stop_calm()
	await t.frames(4)
	var b: Building = t.building()
	var elev: Node = null
	for e in t.get_tree().get_nodes_in_group("elevator"):
		if b.floor_node != null and b.floor_node.is_ancestor_of(e):
			elev = e
	if not t.check(elev != null, "hay ascensor en el piso donde empieza el turno (%d)" % b.current_floor):
		await t.back_to_menu()
		return
	var dest := 1 if b.current_floor == 2 else 2
	var loads: Array = []
	var on_load := func(n: int, _fl: Node) -> void: loads.append(n)
	b.floor_loaded.connect(on_load)
	elev.call("_travel", dest)
	elev.call("_travel", dest)  # el segundo pedido, en el mismo cuadro
	var arrived: bool = await t.until(func() -> bool: return b.current_floor == dest and not t.player().input_locked, 40.0)
	await t.frames(6)
	t.check(arrived, "el viaje termina en el piso %d con el control devuelto" % dest)
	t.check(loads == [dest], "el piso se arma una sola vez (%s)" % str(loads))
	var floors := 0
	for c in b.get_children():
		if c is FloorBase and not c.is_queued_for_deletion():
			floors += 1
	t.check(floors == 1 and b.floor_node != null and not str(b.floor_node.name).begins_with("@"), "queda un solo piso, con su nombre (%d, «%s»)" % [floors, str(b.floor_node.name) if b.floor_node != null else "—"])
	b.floor_loaded.disconnect(on_load)
	await t.back_to_menu()

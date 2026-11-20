## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 · feedback de Joan sobre la beta, puntos 16 y 17 (grupo `v032_fbmt`):
##   16. «Tres minitrainings distintos por turno en vez de los mismos tres» → lineas_mentor.json/minitrainings_por_dia
##       (Mentor.day_minitrainings): 9 temas, 3 por turno, ninguno repetido en el día ni entre días.
##   17. «En los últimos turnos la nota del quiz debería ser 4 de 5 en vez de 3» → turnos.json/quiz_aprobar
##       (TrainingControl.pass_mark): martes Fácil 2 · Normal 3 · Difícil 4; miércoles 3 · 4 · 4. La nota se ve en el
##       anuncio, en el DM del llamado, en Campus, en la pizarra y en el quiz.
##   Además (coordinador): cada «Actualización de campaña» tiene su clase, su pizarra y su banco de preguntas
##   (training.json/dias; los bancos del martes y del miércoles no comparten ninguna) y lo que DICE el Trainer es lo
##   que se lee (sin números al aprobar o reprobar; todas sus líneas habladas contra el índice de audio, ES y EN).
## Los tiempos del llamado (espera_min, persecucion_min) se leen de training.json: no hay ninguno escrito aquí.

const P5 := "res://scripts/dev/escenarios/p5_personajes.gd"
const SPOKEN_FIXED: Array[String] = ["quiz_intro", "quiz_bien", "quiz_mal", "aprobado", "reprobado", "repaso", "alta", "escapa", "persecucion"]

var _p5: Object = null


func escenarios() -> Array[String]:
	return ["fbmt_reparto", "fbmt_dias", "fbmt_campus", "fbmt_nota", "fbmt_bancos", "fbmt_clase", "fbmt_miercoles_4de5", "fbmt_voz"]


func run(id: String, _arg: String, t: Node) -> void:
	_p5 = (load(P5) as GDScript).new()
	var lang0 := Loc.language
	match id:
		"fbmt_reparto": _reparto(t)
		"fbmt_dias": await _dias(t)
		"fbmt_campus": await _campus(t)
		"fbmt_nota": await _nota(t)
		"fbmt_bancos": _bancos(t)
		"fbmt_clase": await _clase(t)
		"fbmt_miercoles_4de5": await _miercoles(t)
		"fbmt_voz": _voz(t)
	if Loc.language != lang0:
		Loc.set_language(lang0)
	for c in (_p5.get("_conns") as Array):
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	(_p5.get("_conns") as Array).clear()
	_p5 = null


func _enabled_days() -> Array[int]:
	var out: Array[int] = []
	for d in DataLoader.list("turnos"):
		if bool((d as Dictionary).get("habilitado", false)) and int((d as Dictionary).get("turno", 0)) >= 1:
			out.append(int((d as Dictionary).get("turno", 0)))
	return out


# --- 16 · datos ---------------------------------------------------------------------------------------------

func _reparto(t: Node) -> void:
	var days := _enabled_days()
	t.check(days == [1, 2, 3], "turnos jugables de esta versión: lunes, martes y miércoles %s" % str(days))
	var seen: Dictionary = {}
	var sets: Array = []
	var bad: Array[String] = []
	for d in days:
		var mts: Array = Mentor.day_minitrainings(d)
		var ids: Array[String] = []
		var hours: Array[float] = []
		for mt in mts:
			var m := mt as Dictionary
			var id := str(m.get("id", ""))
			ids.append(id)
			hours.append(GameState.hhmm_to_seconds(str(m.get("hora", ""))))
			if seen.has(id):
				bad.append("«%s» sale el turno %d y el %d" % [id, int(seen[id]), d])
			seen[id] = d
			for lang in ["es", "en"]:
				for k in ["anuncio", "titulo", "texto", "pregunta"]:
					if str((m.get(k, {}) as Dictionary).get(lang, "")).strip_edges() == "":
						bad.append("%s sin %s (%s)" % [id, k, lang])
				if not str((m.get("anuncio", {}) as Dictionary).get(lang, "")).contains(str((m.get("titulo", {}) as Dictionary).get(lang, "~"))):
					bad.append("%s: el anuncio no nombra el minitraining (%s)" % [id, lang])
			var opts: Array = m.get("opciones", [])
			if opts.size() != 3 or int(m.get("correcta", -1)) < 0 or int(m.get("correcta", -1)) >= opts.size():
				bad.append("%s: opciones/correcta" % id)
			var texts: Dictionary = {}
			for o in opts:
				for lang in ["es", "en"]:
					if str((o as Dictionary).get(lang, "")).strip_edges() == "":
						bad.append("%s: opción vacía (%s)" % [id, lang])
				texts[str((o as Dictionary).get("es", ""))] = true
			if texts.size() != opts.size():
				bad.append("%s: opciones repetidas" % id)
		t.check(mts.size() == 3 and ids.size() == 3, "turno %d: tres minitrainings %s" % [d, str(ids)])
		t.check(hours == [GameState.hhmm_to_seconds("00:20"), GameState.hhmm_to_seconds("03:30"), GameState.hhmm_to_seconds("06:15")], "turno %d: a las 00:20, 03:30 y 06:15" % d)
		var sorted_ids := ids.duplicate()
		sorted_ids.sort()
		sets.append(sorted_ids)
	t.check(seen.size() == 9, "nueve temas distintos en la semana jugable (%d)" % seen.size())
	t.check(sets.size() == 3 and sets[0] != sets[1] and sets[1] != sets[2] and sets[0] != sets[2], "ningún día repite el trío de otro")
	t.check(bad.is_empty(), "ningún tema repetido entre días; cada uno con anuncio, título, texto, pregunta y 3 opciones en ES y EN %s" % str(bad))
	# La posición de la respuesta correcta cambia (no siempre la misma).
	var pos: Dictionary = {}
	for d in days:
		for mt in Mentor.day_minitrainings(d):
			pos[int((mt as Dictionary).get("correcta", 0))] = true
	t.check(pos.size() == 3, "la respuesta correcta cae en los tres puestos a lo largo de la semana %s" % str(pos.keys()))
	# Los tres de siempre siguen tal cual (texto y pregunta), repartidos: Empatía y Adherencia el lunes, Vitzo el martes.
	var mon: Array = Mentor.day_minitrainings(1)
	var tue: Array = Mentor.day_minitrainings(2)
	t.check(str(mon[0].get("id", "")) == "mt_empatia" and str(mon[2].get("id", "")) == "mt_adherencia" and str(tue[1].get("id", "")) == "mt_vitzo", "los tres que ya existían siguen en la semana (lunes 1.º y 3.º, martes 2.º)")
	# Un turno sin lista propia (los de la v0.4) rota entre las que hay: nunca queda sin minitrainings.
	t.check(Mentor.day_minitrainings(4).size() == 3 and Mentor.day_minitrainings(6).size() == 3, "un turno sin lista propia toma una de las que hay (3 minitrainings)")


# --- 16 · en el turno --------------------------------------------------------------------------------------------

func _dias(t: Node) -> void:
	for d in _enabled_days():
		await t.start_shift("Llauri", d)
		await t.login_at_seat()
		GameState.running = false
		var posts: Array = t.spy("ezlak_post")
		var mentor := t.get_tree().get_first_node_in_group("mentor") as Mentor
		t.check(mentor != null, "turno %d: hay Mentor (publica en Ezlaki todos los días)" % d)
		if mentor == null:
			await t.back_to_menu()
			continue
		var mts: Array = Mentor.day_minitrainings()
		var ids: Array[String] = []
		for mt in mts:
			ids.append(str((mt as Dictionary).get("id", "")))
		var ws: Node = t.main.get_node("UI/Workstation")
		var desk: PcDesktop = ws.get("desktop") as PcDesktop
		for i in mts.size():
			var mt: Dictionary = mts[i]
			posts.clear()
			await t.set_clock(GameState.hhmm_to_seconds(str(mt.get("hora", "00:00"))) + 30.0)
			await t.frames(2)
			var announced := ""
			for p in posts:
				if str((p[3] as Dictionary).get("tipo", "")) == "minitraining" and str(p[1]) == "mentor" and str(p[0]) == "#team-familia":
					announced = str(p[2])
			t.check(mentor.minitrainings_open == ids.slice(0, i + 1), "turno %d · %s: abierto «%s» %s" % [d, str(mt.get("hora", "")), ids[i], str(mentor.minitrainings_open)])
			t.check(announced == Loc.pick(mt.get("anuncio", {})) and announced.contains(Loc.pick(mt.get("titulo", {}))), "turno %d: el Mentor lo anuncia en #team-familia con su título («%s»)" % [d, announced.left(70)])
		desk.open_app("campus")
		await t.frames(3)
		var listed: Array[String] = []
		for b in desk.campus.find_children("*", "Button", true, false):
			for mt in mts:  # los botones de minitraining llevan dos renglones: «título / estado» (las guías, uno)
				if (b as Button).text.begins_with(Loc.pick((mt as Dictionary).get("titulo", {})) + "\n"):
					listed.append(str((mt as Dictionary).get("id", "")))
		t.check(listed == ids, "turno %d: Campus lista los tres de hoy y solo esos %s" % [d, str(listed)])
		var other: Array[String] = []
		for od in _enabled_days():
			if od == d:
				continue
			for mt in Mentor.day_minitrainings(od):
				for b in desk.campus.find_children("*", "Button", true, false):
					if (b as Button).text.begins_with(Loc.pick((mt as Dictionary).get("titulo", {})) + "\n"):
						other.append(str((mt as Dictionary).get("id", "")))
		t.check(other.is_empty(), "turno %d: ninguno de otro día en Campus %s" % [d, str(other)])
		# Responder: mal no completa, bien sí; el contador de «hoy» sube.
		desk.campus.answer(ids[0], false)
		t.check(mentor.minitrainings_done.is_empty(), "turno %d: respuesta incorrecta, no se completa" % d)
		desk.campus.answer(ids[0], true)
		await t.frames(3)
		var head := desk.campus.find_child("MinitrainingsHoy", true, false) as Label
		t.check(mentor.minitrainings_done == [ids[0]] and mentor.minitrainings_pending() == 2, "turno %d: respuesta correcta, completado; quedan 2" % d)
		t.check(head != null and head.text == Loc.fmt(TranslationServer.translate("FBUI_CAMPUS_MT_HOY"), {"hechos": 1, "total": 3}), "turno %d: Campus dice cuántos van de hoy («%s»)" % [d, head.text if head != null else ""])
		# 08:00 con dos pendientes: aviso del Mentor y DM de Shero, una vez.
		posts.clear()
		await t.set_clock(GameState.hhmm_to_seconds("08:01"))
		await t.seconds(2.5)
		var warn_m := 0
		var warn_s := 0
		for p in posts:
			if str((p[3] as Dictionary).get("tipo", "")) == "minitraining_pendiente":
				if str(p[1]) == "mentor":
					warn_m += 1
				elif str(p[1]) == "shero" and str(p[0]) == "dm:shero":
					warn_s += 1
		t.check(warn_m == 1 and warn_s == 1, "turno %d: a las 08:00, con 2 pendientes, aviso del Mentor y DM de Shero (%d, %d)" % [d, warn_m, warn_s])
		await t.back_to_menu()
	# Con los tres hechos, a las 08:00 nadie avisa.
	await t.start_shift("Ttoom", 2)
	await t.login_at_seat()
	GameState.running = false
	var posts2: Array = t.spy("ezlak_post")
	var mentor2 := t.get_tree().get_first_node_in_group("mentor") as Mentor
	await t.set_clock(GameState.hhmm_to_seconds("06:16"))
	await t.frames(2)
	for mt in Mentor.day_minitrainings():
		mentor2.complete_minitraining(str((mt as Dictionary).get("id", "")))
	posts2.clear()
	await t.set_clock(GameState.hhmm_to_seconds("08:01"))
	await t.seconds(2.5)
	var late := 0
	for p in posts2:
		if str((p[3] as Dictionary).get("tipo", "")) == "minitraining_pendiente":
			late += 1
	t.check(mentor2.minitrainings_pending() == 0 and late == 0, "con los tres hechos no hay aviso a las 08:00 (%d)" % late)


# --- 17 · Campus --------------------------------------------------------------------------------------------------

## Rect de un control de la PC en px de su pantalla.
func _in_screen(c: Control) -> bool:
	var vp := c.get_viewport()
	if vp == null:
		return false
	var r := c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
	return Rect2(Vector2.ZERO, vp.get_visible_rect().size).grow(0.5).encloses(r)


func _campus(t: Node) -> void:
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		for d in _enabled_days():
			await t.start_shift("Marko", d)
			await t.login_at_seat()
			GameState.running = false
			await t.set_clock(GameState.hhmm_to_seconds("06:16"))  # los tres abiertos: la lista más larga
			var ws: Node = t.main.get_node("UI/Workstation")
			var desk: PcDesktop = ws.get("desktop") as PcDesktop
			desk.open_app("campus")
			await t.frames(4)
			var has := GameState.training_clock() >= 0.0
			var need := TrainingControl.pass_mark()
			var tema := Loc.pick(TrainingControl.day_info().get("tema", {}))
			# Cada vista de Campus (bienvenida, cada minitraining con su respuesta marcada, una guía): la franja de la
			# actualización arriba, con hora, tema y nota mínima, y TODO dentro de la pantalla (la lista y la barra F1-F5).
			var views: Array[String] = [""]
			for mt in Mentor.day_minitrainings():
				views.append(str((mt as Dictionary).get("id", "")))
			views.append("guia_kyc")
			var out: Array[String] = []
			var banner_bad: Array[String] = []
			var scroll := desk.campus.find_child("CuerpoScroll", true, false) as ScrollContainer
			for view in views:
				desk.campus.set("_selected", view)
				if view.begins_with("mt_"):
					desk.campus.answer(view, false)  # con el aviso «Incorrecto» puesto: la vista más alta
				await t.frames(4)
				var upd := desk.campus.find_child("ActualizacionHoy", true, false) as Label
				var want_banner := has and not view.begins_with("mt_")
				if (upd != null) != want_banner:
					banner_bad.append("%s: %s" % [view, "falta" if want_banner else "sobra"])
				elif upd != null and not (upd.text.contains(GameState.clock_text_at(GameState.training_clock())) and upd.text.contains(tema) and tema != "" and upd.text.contains("%d" % need) and not upd.text.contains("{") and _in_screen(upd)):
					banner_bad.append("%s: «%s»" % [view, upd.text])
				# La lista, la barra F1-F5 y el resto de la PC: siempre dentro de la pantalla.
				for c in desk.find_children("*", "Control", true, false):
					var ctl := c as Control
					if scroll != null and scroll.is_ancestor_of(ctl):
						continue
					if (ctl is Button or ctl is Label) and ctl.is_visible_in_tree() and not _in_screen(ctl):
						out.append("%s: %s" % [view, str(ctl.get("text")).replace("\n", " / ").left(40)])
				# El cuerpo: un minitraining cabe ENTERO sin mover el scroll (texto, pregunta, las tres opciones y el aviso).
				if scroll != null and view.begins_with("mt_"):
					var sr := scroll.get_global_transform() * Rect2(Vector2.ZERO, scroll.size)
					for c in scroll.find_children("*", "Control", true, false):
						var ctl := c as Control
						if (ctl is Button or ctl is Label) and ctl.is_visible_in_tree() and not sr.grow(0.5).encloses(ctl.get_global_transform() * Rect2(Vector2.ZERO, ctl.size)):
							out.append("%s (cuerpo): %s" % [view, str(ctl.get("text")).replace("\n", " / ").left(40)])
				if scroll == null or not _in_screen(scroll):
					out.append("%s: el cuerpo de Campus sale de la pantalla" % view)
			t.check(banner_bad.is_empty(), "%s · turno %d: Campus %s la «Actualización de campaña» de hoy con su hora, su tema y la nota mínima (%d), en la bienvenida y en las guías %s" % [lang, d, "muestra" if has else "no muestra", need, str(banner_bad)])
			t.check(out.is_empty(), "%s · turno %d: en las %d vistas de Campus la lista y la barra F1-F5 quedan dentro de la pantalla y cada minitraining cabe entero sin scroll %s" % [lang, d, views.size(), str(out.slice(0, 6))])
			await t.back_to_menu()


# --- 17 · nota mínima ---------------------------------------------------------------------------------------------

func _nota(t: Node) -> void:
	var want := {2: [2, 3, 4], 3: [3, 4, 4]}
	for d in [2, 3]:
		for dif in 3:
			await t.start_shift("Juan", d, 0, dif)
			t.check(TrainingControl.pass_mark() == int((want[d] as Array)[dif]), "turno %d · %s: nota mínima %d de 5 (hay %d)" % [d, Difficulty.id(), int((want[d] as Array)[dif]), TrainingControl.pass_mark()])
			await t.back_to_menu()
	# Turno real = Difícil: 4 de 5 los dos días.
	await t.start_shift("Juan", 2, 1, 0)
	t.check(not GameState.is_real_mode() or TrainingControl.pass_mark() == 4, "Turno real (Difícil): 4 de 5 (hay %d)" % TrainingControl.pass_mark())
	await t.back_to_menu()
	t.check(TrainingControl.pass_mark(1) == int(Difficulty.value("quiz_aprobar", 3)), "un turno sin training ni días anteriores con nota: la de dificultad.json")
	# Nunca se exige 5 de 5 (el final secreto de Jiroshi pide aprobar con 4 fallando una a propósito).
	var five := false
	for d in DataLoader.list("turnos"):
		for v in (d as Dictionary).get("quiz_aprobar", []):
			if int(v) >= 5:
				five = true
	t.check(not five, "ningún día pide 5 de 5")
	# En Normal, el anuncio de las 00:10, el DM del llamado y la pizarra de la sala dicen la nota del día.
	for d in [2, 3]:
		var hub: PersonajesP5 = await _p5.call("_prep", t, d)
		var need := TrainingControl.pass_mark()
		var tema := Loc.pick(TrainingControl.day_info().get("tema", {}))
		await t.set_clock(GameState.hhmm_to_seconds(str(DataLoader.dict("training").get("anuncio_hora", "00:10"))) + 5.0)
		await t.frames(3)
		var ann := ""
		for m in EzlakHub.get_hub(t.get_tree()).messages("#site-updates"):
			if str((m as Dictionary).get("tipo", "")) == "training_anuncio":
				ann = str((m as Dictionary).get("texto", (m as Dictionary).get("text", "")))
		t.check(ann.contains(tema) and tema != "" and ann.contains(str(need)) and not ann.contains("{"), "turno %d: el anuncio trae el tema y la nota mínima («%s»)" % [d, ann])
		await _p5.call("_training_call", t, hub)
		var dm: Dictionary = await _p5.call("_last_msg", t, "dm:trainer")
		var dm_text := str(dm.get("texto", dm.get("text", "")))
		t.check(dm_text.contains(str(need)) and not dm_text.contains("{"), "turno %d: el DM del llamado dice el mínimo («%s»)" % [d, dm_text.right(48)])
		await _p5.call("_training_arrive", t, hub)
		var board := ""
		await t.frames(3)
		for l in (t.building().floor_node as Node).find_children("*", "Label3D", true, false):
			if (l as Label3D).text.contains("QUIZ") and not (l as Label3D).has_meta("reverso"):
				board = (l as Label3D).text
		t.check(board == Loc.fmt(Loc.pick(TrainingControl.day_info().get("pizarra", {})), {"min": need}) and board != "", "turno %d: la pizarra de la sala es la del día y dice el mínimo («%s»)" % [d, board.replace("\n", " / ").left(90)])
		await t.back_to_menu()


func _miercoles(t: Node) -> void:
	# Normal, miércoles: 3 de 5 ya no alcanza (reprueba y muere); 4 de 5, fallando una, aprueba.
	for pair in [[[-1, -1, -1, -2, -2], false, 3], [[-1, -1, -2, -1, -1], true, 4]]:
		var hub: PersonajesP5 = await _p5.call("_prep", t, 3)
		var seq: Array = t.spy("death_sequence_started")
		var subs: Array = t.spy("subtitle")
		await _p5.call("_training_call", t, hub)
		await _p5.call("_training_arrive", t, hub)
		hub.training.forced_answers = pair[0]
		hub.training.session_at -= 29.0 * 60.0
		t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0), "miércoles: llega el quiz")
		t.check(hub.training.quiz != null and hub.training.quiz.need == 4, "miércoles Normal: mínimo 4 de 5 (hay %d)" % (hub.training.quiz.need if hub.training.quiz != null else -1))
		var status := hub.training.quiz.get("_status") as Label if hub.training.quiz != null else null
		t.check(status != null and status.text == Loc.fmt(TranslationServer.translate("FBUI_QUIZ_STATUS"), {"n": 0, "min": 4, "total": 5}), "el quiz muestra «%s»" % (status.text if status != null else ""))
		var title := hub.training.quiz.get("_title") as Label if hub.training.quiz != null else null
		t.check(title != null and title.text == Loc.pick(TrainingControl.day_info().get("quiz_titulo", {})), "con el título del día («%s»)" % (title.text if title != null else ""))
		await t.until(func() -> bool: return hub.training.last_score >= 0, 25.0)
		t.check(hub.training.last_score == int(pair[2]), "nota %d de 5 (hay %d)" % [int(pair[2]), hub.training.last_score])
		var key := "aprobado" if bool(pair[1]) else "reprobado"
		var line := ""
		for s in subs:
			if str(s[0]) == "trainer" and str(s[1]).contains(PersonajesP5.line("lineas_trainer", key)):
				line = str(s[1])
		t.check(hub.training.said.has(key) and line != "" and not _has_digit(line), "el Trainer dice «%s»: sin números (la nota está en la pizarra del quiz)" % line)
		if bool(pair[1]):
			t.check(await t.until(func() -> bool: return hub.training.quiz == null and hub.training.state == TrainingControl.State.SESION, 20.0) and seq.is_empty(), "4 de 5 fallando una: aprueba (sirve para el final secreto de Jiroshi)")
		else:
			t.check(await t.until(func() -> bool: return not seq.is_empty(), 25.0) and str(seq[0][0]) == "training_reprobado" and str(seq[0][2]) == "3/5", "3 de 5 el miércoles: reprueba (%s)" % (str(seq[0]) if not seq.is_empty() else "sin muerte"))
		await t.back_to_menu()


func _has_digit(s: String) -> bool:
	for i in s.length():
		if s[i] >= "0" and s[i] <= "9":
			return true
	return false


# --- bancos de preguntas -----------------------------------------------------------------------------------------

func _bancos(t: Node) -> void:
	var cfg: Dictionary = DataLoader.dict("training")
	var by_id: Dictionary = {}
	for q in cfg.get("preguntas", []):
		by_id[str((q as Dictionary).get("id", ""))] = q
	var tc := TrainingControl.new()
	var pools: Dictionary = {}
	for d in [2, 3]:
		var day: Dictionary = TrainingControl.day_info(d)
		var pool: Array = day.get("preguntas", [])
		pools[d] = pool
		var mix: Dictionary = day.get("mezcla", {})
		var bad: Array[String] = []
		var seen: Dictionary = {}
		var corr_pos: Dictionary = {}
		for seed_v in range(1, 61):
			var qs: Array = tc.pick_questions(seed_v * 97 + d, d)
			if qs.size() != 5:
				bad.append("semilla %d: %d preguntas" % [seed_v, qs.size()])
				continue
			var cats: Dictionary = {}
			var ids: Dictionary = {}
			for q in qs:
				var qd := q as Dictionary
				var id := str(qd.get("id", ""))
				ids[id] = true
				seen[id] = true
				cats[str(qd.get("cat", ""))] = int(cats.get(str(qd.get("cat", "")), 0)) + 1
				if not pool.has(id):
					bad.append("semilla %d: %s no es del banco del día" % [seed_v, id])
				# La opción marcada como correcta sigue siendo la del banco aunque se barajen.
				var src: Dictionary = by_id.get(id, {})
				var right := str(((src.get("opciones", []) as Array)[int(src.get("correcta", 0))] as Dictionary).get("es", ""))
				var got := str(((qd.get("opciones", []) as Array)[int(qd.get("correcta", 0))] as Dictionary).get("es", ""))
				if right != got:
					bad.append("semilla %d: %s perdió su respuesta correcta" % [seed_v, id])
				corr_pos[int(qd.get("correcta", 0))] = true
			if ids.size() != 5:
				bad.append("semilla %d: pregunta repetida" % seed_v)
			for c in mix.keys():
				if int(cats.get(c, 0)) != int(mix[c]):
					bad.append("semilla %d: %d de «%s» (van %d)" % [seed_v, int(cats.get(c, 0)), c, int(mix[c])])
			var fixed: Dictionary = day.get("fija", {})
			if not fixed.is_empty() and str((qs[int(fixed.get("pos", 1)) - 1] as Dictionary).get("id", "")) != str(fixed.get("id", "")):
				bad.append("semilla %d: la pregunta fija no está en su puesto" % seed_v)
		t.check(bad.is_empty(), "turno %d: 60 quizzes de 5 preguntas, todas del banco del día, con su mezcla %s y la respuesta correcta intacta %s" % [d, str(mix), str(bad.slice(0, 6))])
		t.check(seen.size() == pool.size(), "turno %d: todas las preguntas del banco llegan a salir (%d de %d)" % [d, seen.size(), pool.size()])
		t.check(corr_pos.size() == 3, "turno %d: la correcta cae en los tres puestos" % d)
	tc.free()
	var shared: Array = []
	for id in (pools[2] as Array):
		if (pools[3] as Array).has(id):
			shared.append(id)
	t.check(shared.is_empty() and (pools[2] as Array).size() >= 10 and (pools[3] as Array).size() >= 10, "martes y miércoles no comparten ninguna pregunta (%d y %d; comunes %s)" % [(pools[2] as Array).size(), (pools[3] as Array).size(), str(shared)])
	var all_ids: Dictionary = {}
	for id in (pools[2] as Array) + (pools[3] as Array):
		all_ids[id] = true
	t.check(all_ids.size() == by_id.size(), "todo el banco (%d) está repartido entre los dos días" % by_id.size())
	var tue: Dictionary = TrainingControl.day_info(2)
	var q4: Dictionary = by_id.get(str((tue.get("fija", {}) as Dictionary).get("id", "")), {})
	var no_breaks := false
	for o in q4.get("opciones", []):
		if str((o as Dictionary).get("es", "")) == "No hay breaks":
			no_breaks = true
	t.check(int((tue.get("fija", {}) as Dictionary).get("pos", 0)) == 4 and str(q4.get("es", "")) == "¿Cuántos breaks hay por turno?" and no_breaks, "martes: la 4.ª pregunta es «¿Cuántos breaks hay por turno?», con la opción «No hay breaks» (trama, día 2)")
	# Cada pregunta: 3 opciones, correcta en rango, pista, ES y EN.
	var malformed: Array[String] = []
	for id in by_id.keys():
		var q: Dictionary = by_id[id]
		var opts: Array = q.get("opciones", [])
		if opts.size() != 3 or int(q.get("correcta", -1)) < 0 or int(q.get("correcta", -1)) > 2 or str(q.get("es", "")) == "" or str(q.get("en", "")) == "" or str((q.get("pista", {}) as Dictionary).get("es", "")) == "" or str((q.get("pista", {}) as Dictionary).get("en", "")) == "":
			malformed.append(id)
		for o in opts:
			if str((o as Dictionary).get("es", "")) == "" or str((o as Dictionary).get("en", "")) == "":
				malformed.append(id)
	t.check(malformed.is_empty(), "las %d preguntas están completas (3 opciones, correcta, pista, ES y EN) %s" % [by_id.size(), str(malformed)])


# --- la clase de cada día ----------------------------------------------------------------------------------------

func _clase(t: Node) -> void:
	var c2: Array = TrainingControl.day_info(2).get("clase", [])
	var c3: Array = TrainingControl.day_info(3).get("clase", [])
	var common: Array = []
	for k in c2:
		if c3.has(k):
			common.append(k)
	t.check(c2.size() >= 5 and c3.size() >= 5 and common.is_empty(), "la clase del martes y la del miércoles no comparten ninguna línea (%d y %d)" % [c2.size(), c3.size()])
	t.check(Loc.pick(TrainingControl.day_info(2).get("tema", {})) != Loc.pick(TrainingControl.day_info(3).get("tema", {})) and Loc.pick(TrainingControl.day_info(2).get("pizarra", {})) != Loc.pick(TrainingControl.day_info(3).get("pizarra", {})), "tema y pizarra distintos cada día")
	for d in [2, 3]:
		var hub: PersonajesP5 = await _p5.call("_prep", t, d)
		await _p5.call("_training_call", t, hub)
		await _p5.call("_training_arrive", t, hub)
		var clase: Array = hub.training.class_lines()
		t.check(clase == (c2 if d == 2 else c3), "turno %d: la clase es la del día %s" % [d, str(clase)])
		t.check(hub.training.said.has(str(clase[0])), "turno %d: empieza con su bienvenida («%s»)" % [d, PersonajesP5.line("lineas_trainer", str(clase[0])).left(60)])
		hub.training.forced_answers = [-1, -1, -1, -1, -1]
		hub.training.session_at -= (float(TrainingControl.day_info().get("quiz_en_min", DataLoader.dict("training").get("quiz_en_min", 22.0))) - 0.1) * 60.0
		t.check(await t.until(func() -> bool: return hub.training.state == TrainingControl.State.QUIZ, 6.0), "turno %d: llega el quiz" % d)
		var missing: Array = []
		for k in clase:
			if not hub.training.said.has(str(k)):
				missing.append(k)
		var foreign: Array = []
		for k in (c3 if d == 2 else c2):
			if hub.training.said.has(str(k)):
				foreign.append(k)
		t.check(missing.is_empty() and foreign.is_empty(), "turno %d: dio toda su clase antes del quiz y nada de la del otro día (faltan %s, sobran %s)" % [d, str(missing), str(foreign)])
		await t.until(func() -> bool: return hub.training.last_score >= 0, 25.0)
		await t.back_to_menu()
	# El miércoles repite, palabra por palabra y sin reírse, bromas del Trainer amable del Training.
	var amable: Dictionary = DataLoader.dict("lineas_trainer_amable")
	var echoes := 0
	for pair in [["b3_clase_3", "t_bo_kyc", "Lo que no está en Kardex, no pasó. Y si ustedes no están en Kardex… bueno, ustedes tampoco pasaron."], ["b3_clase_4", "t_rta", "Perrito RTA cuida los AUX. Si te dice BO, BO. Es buenito. Muerde poquito."], ["b3_clase_5", "t_aux_pct", "Arriba de setenta, eres familia. Abajo de setenta… también, pero te llaman"]]:
		var now := str((DataLoader.dict("lineas_trainer").get(pair[0], {}) as Dictionary).get("es", ""))
		var then := str((amable.get(pair[1], {}) as Dictionary).get("es", ""))
		if now.contains(str(pair[2])) and then.contains(str(pair[2])) and not now.contains("Ja, ja") and not now.contains("jeje"):
			echoes += 1
	t.check(echoes == 3, "miércoles: tres bromas del Training repetidas palabra por palabra, sin la risa (%d de 3)" % echoes)


# --- lo que dice = lo que se lee -------------------------------------------------------------------------------------

func _plain(s: String) -> String:
	var out := s.strip_edges()
	for pair in [["«", "\""], ["»", "\""], ["“", "\""], ["”", "\""], ["’", "'"], ["  ", " "]]:
		out = out.replace(pair[0], pair[1])
	return out


func _voz(t: Node) -> void:
	var lines: Dictionary = DataLoader.dict("lineas_trainer")
	var index: Dictionary = DataLoader.dict("audio_index").get("textos", {})
	var keys: Array[String] = []
	for k in SPOKEN_FIXED:
		keys.append(k)
	for src in [DataLoader.dict("training").get("clase", []), TrainingControl.day_info(2).get("clase", []), TrainingControl.day_info(3).get("clase", [])]:
		for k in src:
			if not keys.has(str(k)):
				keys.append(str(k))
	var bad: Array[String] = []
	for k in keys:
		var data: Dictionary = lines.get(k, {})
		var heard: Dictionary = index.get("voces/trainer/" + k, {})
		for lang in ["es", "en"]:
			var txt := str(data.get(lang, ""))
			if txt == "":
				bad.append("%s sin texto (%s)" % [k, lang])
			elif txt.contains("{"):
				bad.append("%s lleva una variable: la voz no puede decirla (%s)" % [k, lang])
			elif _plain(str(heard.get(lang, ""))) != _plain(txt):
				bad.append("%s (%s): se lee «%s» y la voz dice «%s»" % [k, lang, txt, str(heard.get(lang, ""))])
		if not FileAccess.file_exists("res://assets/audio/voces/trainer/%s.ogg" % k) or not FileAccess.file_exists("res://assets/audio/voces/trainer/en/%s.ogg" % k):
			bad.append("%s sin archivo de voz (es/en)" % k)
	t.check(keys.size() >= 20 and bad.is_empty(), "las %d líneas que el Trainer dice en la «Actualización de campaña» se leen igual que se oyen, en ES y EN, y tienen su voz: %s" % [keys.size(), str(bad)])
	# «Te pongo en Training yo» (texto en las traducciones).
	var pone: Dictionary = index.get("voces/trainer/pone_training", {})
	var diff: Array[String] = []
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		var txt := str(TranslationServer.translate("Q1_TRAINER_PONE_TRAINING"))
		if txt == "Q1_TRAINER_PONE_TRAINING" or _plain(txt) != _plain(str(pone.get(lang, ""))):
			diff.append("%s: «%s» / «%s»" % [lang, txt, str(pone.get(lang, ""))])
	t.check(diff.is_empty(), "«Te pongo en Training yo» también coincide con su voz %s" % str(diff))
	# El subtítulo sale del texto de la voz: si alguien cambia la línea sin volver a sintetizarla, se lee lo que se oye.
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		t.check(TrainingControl.spoken_text("aprobado", "Aprobado. 5 de 5.") == str((index.get("voces/trainer/aprobado", {}) as Dictionary).get(lang, "")), "%s: una línea cambiada sin sintetizar se subtitula con lo que dice la voz" % lang)
		t.check(TrainingControl.spoken_text("aprobado", PersonajesP5.line("lineas_trainer", "aprobado")) == PersonajesP5.line("lineas_trainer", "aprobado"), "%s: «aprobado» se lee tal cual («%s»)" % [lang, PersonajesP5.line("lineas_trainer", "aprobado")])
	for k in ["aprobado", "reprobado"]:
		for lang in ["es", "en"]:
			t.check(not _has_digit(str((lines.get(k, {}) as Dictionary).get(lang, ""))) and not _has_digit(str((index.get("voces/trainer/" + k, {}) as Dictionary).get(lang, "~1"))), "«%s» (%s) no lleva números ni en el texto ni en la voz" % [k, lang])

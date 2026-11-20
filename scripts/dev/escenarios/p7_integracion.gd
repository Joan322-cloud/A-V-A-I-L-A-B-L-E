## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de la integración final de la v0.3.0 (P7: merge de P6a sobre P1-P5 + P6b):
## - p7_shero_altura: Shero mide 2,2 m (con el afro) en su sitio, como visitante de Pursuit y en el screamer, y en el
##   screamer sale siempre calvo (sin el nodo Afro); el look sigue a Discipline.shero_bald() (WW → calvo, calma → afro).
## - p7_parlantes: el bus "Parlantes" (filtro de bocina en tiempo real) existe y manda a Sala; Shero y los personajes
##   de P5 hablan por él cuando suenan por los parlantes; en persona, por Sala.
## - p7_voces_escalera: cada línea hablada de la escalera (voz/pa/rooms) tiene su archivo ES y EN en la carpeta de su
##   autor (Rasec en voces/rasec) y el audio dice lo mismo que el subtítulo (texto del índice ≥ 0,6).
## - p7_tutorial_voces: la voz del sistema de la Inducción dice el texto del panel; los clientes de práctica tienen voz.
## - p7_retraso: un mensaje con "retraso" sale después (dos verbales → "Primero la alerta…" a los 4,5 s) y se descarta
##   si en el medio hay una muerte.
## - p7_segundo_ww: el 2.º WW del turno lo anuncia Shero por los parlantes ("Segundo WW enviado…").
## - p7_ambiente: los clips cosechados de Shero en su sitio a su hora (madrugada, Ezlaki profesional) con su post.
## - p7_sin_ronquido: el clip cosechado juan_ronquido (decía «Receiver») ya no está en el juego ni se pide.
## - p7_motivos: ningún motivo de muerte (ES y EN, con y sin detalle) tiene dos puntos ni puntuación suelta: tras
##   «Motivo: » de la pantalla de muerte, «Break excedido: 16:00» dejaba dos dos puntos (ahora «Break excedido (16:00)»).
## - p7_migracion_v02 / p7_migracion_beta1: partidas REALES guardadas por la v0.2.0-dev2 y la v0.3.0-beta1 (las jugó su
##   bot; fixtures en scripts/dev/fixtures/saves/): se migran, Continuar sigue el turno a medias, Elegir turno ofrece
##   los turnos alcanzados y una rama no toca la partida principal.


func escenarios() -> Array[String]:
	return ["p7_shero_altura", "p7_parlantes", "p7_voces_escalera", "p7_tutorial_voces", "p7_retraso", "p7_segundo_ww",
		"p7_ambiente", "p7_sin_ronquido", "p7_migracion_v02", "p7_migracion_beta1", "p7_motivos"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p7_shero_altura": await _altura(t)
		"p7_parlantes": await _parlantes(t)
		"p7_voces_escalera": await _voces(t)
		"p7_tutorial_voces": await _tutorial(t)
		"p7_retraso": await _retraso(t)
		"p7_segundo_ww": await _segundo_ww(t)
		"p7_ambiente": await _ambiente(t)
		"p7_sin_ronquido": await _ronquido(t)
		"p7_migracion_v02": await _mig_v02(t)
		"p7_migracion_beta1": await _mig_beta1(t)
		"p7_motivos": await _motivos(t)


static func _height(root: Node) -> float:
	var lo := INF
	var hi := -INF
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.mesh.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
	return hi - lo if hi > lo else 0.0


func _altura(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var sh := t.get_tree().get_first_node_in_group("shero") as Node3D
	t.check(sh != null, "Shero está en el piso 2")
	if sh == null:
		return
	var afro := sh.find_child("Afro", true, false) as Node3D
	t.check(afro != null and afro.visible, "Shero tranquilo: con afro (nodo Afro visible)")
	var h := _height(sh)
	t.check(absf(h - 2.2) < 0.08, "Shero mide 2,2 m con el afro (%.2f m)" % h)
	# WW reciente → calvo (shero.gd consulta Discipline.shero_bald() cada 0,25 s)
	Discipline.set("_bald_until_clock", GameState.clock_seconds + 1200.0)
	await t.seconds(0.6)
	t.check(str(sh.get("look")) == "calvo" and afro != null and not afro.visible, "tras un WW: calvo (Afro oculto)")
	Discipline.set("_bald_until_clock", -INF)
	await t.seconds(0.6)
	t.check(str(sh.get("look")) == "afro" and afro != null and afro.visible, "sin enojo vuelve el afro")
	# Visitante de Pursuit (otro piso) y presencia: 2,2 m
	t.check(float((Pursuit.RIG_OF["shero"] as Array)[1]) == 2.2, "Pursuit crea al Shero visitante de 2,2 m")
	# Screamer: siempre calvo aunque la fila no lo diga
	var fx := Screamers.new()
	fx.set("_player", t.player())
	t.get_tree().root.add_child(fx)
	var m: Node3D = fx.call("_model", "shero", "") as Node3D
	t.check(m != null, "el screamer arma el modelo de Shero")
	if m != null:
		var a2 := m.find_child("Afro", true, false) as Node3D
		t.check(a2 != null and not a2.visible, "en el screamer Shero sale calvo (nodo Afro oculto)")
		t.check(absf(_height(m) - 2.0) < 0.25, "el Shero del screamer, calvo, mide ~2 m (%.2f; 2,2 con el afro)" % _height(m))
	var stage := fx.get("_stage") as Node
	if stage != null:
		stage.queue_free()
	fx.queue_free()
	await t.frames(1)


func _parlantes(t: Node) -> void:
	var bi := AudioServer.get_bus_index("Parlantes")
	t.check(bi >= 0, "existe el bus Parlantes")
	if bi < 0:
		return
	t.check(AudioServer.get_bus_send(bi) == &"Sala", "Parlantes manda a Sala (el volumen de Sala lo regula)")
	t.check(AudioServer.get_bus_effect_count(bi) >= 3, "Parlantes tiene el filtro de bocina (%d efectos)" % AudioServer.get_bus_effect_count(bi))
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	Discipline.presence.call("pa", "shero", "Ya voy.", "esc_sala_persecucion")
	await t.seconds(0.9)
	t.check(str(AudioManager.last_voice.get("bus", "")) == "Parlantes" and str(AudioManager.last_voice.get("slot", "")) == "voces/shero/esc_sala_persecucion", "Shero por los parlantes: bus Parlantes (%s)" % str(AudioManager.last_voice))
	t.check(str(AudioManager.last_voice.get("path", "")) != "", "la voz de los parlantes tiene archivo")
	PersonajesP5.pa("x", "haime", "pa_llamado")
	await t.frames(2)
	t.check(str(AudioManager.last_voice.get("bus", "")) == "Parlantes" and str(AudioManager.last_voice.get("slot", "")) == "voces/haime/pa_llamado", "Haime por los parlantes: bus Parlantes")
	# En persona (Shero en el piso, cerca): Sala, voz 3D
	var sh := t.get_tree().get_first_node_in_group("shero") as Node3D
	var before := sh.find_children("*", "AudioStreamPlayer3D", true, false).size() if sh != null else 0
	Discipline.presence.call("speak", "shero", "¡Regresa a tu sitio ahora mismo!", "shero_regresa_sitio", "voz")
	await t.frames(2)
	var after := sh.find_children("*", "AudioStreamPlayer3D", true, false).size() if sh != null else 0
	t.check(after > before, "en persona: voz 3D desde Shero (no por los parlantes)")


func _voces(t: Node) -> void:
	var esc: Dictionary = DataLoader.dict("lineas_shero").get("escalera", {})
	var n := 0
	var bad: Array = []
	for track in esc.keys():
		if not (esc[track] is Dictionary):
			continue
		for key in (esc[track] as Dictionary).keys():
			var msgs: Variant = esc[track][key]
			if not (msgs is Array):
				continue
			for m in msgs:
				if not (m is Dictionary) or str(m.get("voz", "")) == "" or not (str(m.get("canal", "dm")) in ["voz", "pa", "rooms"]):
					continue
				n += 1
				var autor := str(m.get("autor", "shero"))
				var slot := "voces/%s/%s" % [autor, str(m["voz"])]
				if AudioManager.resolve(slot) == "":
					bad.append(slot + " (sin ES)")
					continue
				if AudioManager.resolve("voces/%s/en/%s" % [autor, str(m["voz"])]) == "":
					bad.append(slot + " (sin EN)")
				var sub := str(m.get("es", "")).replace("{agente}", "").replace("{pct}", "")
				var txt: Dictionary = AudioManager._texts.get(slot, {})
				var sc := AudioManager.text_score(sub, str(txt.get("es", "")))
				if sc < 0.6:
					bad.append("%s dice «%s» y el subtítulo «%s» (%.2f)" % [slot, str(txt.get("es", "?")), sub, sc])
	t.note("%d líneas habladas de la escalera" % n)
	for b in bad:
		t.fail(b)
	t.check(bad.is_empty() and n >= 50, "todas las líneas habladas de la escalera tienen su voz (ES y EN) y dicen su subtítulo")
	for tr in ["coaching", "coaching_exceso", "coaching_sesion_rasec"]:
		for key in (esc[tr] as Dictionary).keys():
			for m in esc[tr][key]:
				if m is Dictionary and str(m.get("autor", "")) == "rasec" and str(m.get("canal", "")) in ["voz", "pa", "rooms"]:
					t.check(AudioManager.resolve("voces/rasec/" + str(m["voz"])) != "", "Rasec habla con su voz: voces/rasec/" + str(m["voz"]))
	t.check(AudioManager.resolve("voces/shero/esc_coaching_verbal") == "", "ya no queda la línea de Rasec con la voz de Shero")


func _tutorial(t: Node) -> void:
	var tut: Dictionary = DataLoader.dict("tutorial")
	# v0.3.2 (Training rehecho): los pasos ya no llevan la voz del sistema; habla el Trainer amable, la promoción y el
	# agente, una línea a la vez (TrainingVoice). Cada línea que cita un paso tiene su voz en ES y EN.
	var n := 0
	var ids: Dictionary = {}
	for m in tut.get("modulos", []):
		for p in (m as Dictionary).get("pasos", []):
			if str((p as Dictionary).get("voz", "")).begins_with("sistema/"):
				n += 1
			for key in ["dice", "luego", "luego_si", "luego_no", "mientras"]:
				for id in (p as Dictionary).get(key, []):
					ids[str(id)] = true
			for key in ["dice_por", "luego_por"]:
				for arr in ((p as Dictionary).get(key, {}) as Dictionary).values():
					for id in arr:
						ids[str(id)] = true
	t.check(n == 0, "ningún paso usa ya la voz del sistema de la Inducción (%d)" % n)
	for id in ["t_firmado", "t_leyo", "t_no_leyo", "t_foto_timer", "t_foto_ya"]:  # las que dice el código (firma, foto)
		ids[id] = true
	var missing: Array = []
	var slots := 0
	for id in ids.keys():
		for slot in _training_slots(str(id)):
			slots += 1
			var en := str(slot).get_base_dir() + "/en/" + str(slot).get_file()
			if AudioManager.resolve(str(slot)) == "" or AudioManager.resolve(en) == "":
				missing.append(slot)
	t.check(ids.size() >= 90 and slots >= 150, "el guion del Training cita %d líneas (%d voces)" % [ids.size(), slots])
	t.check(missing.is_empty(), "todas tienen voz en ES y EN %s" % str(missing.slice(0, 8)))
	for c in tut.get("casos", []):
		for grp in ["nodos", "finales"]:
			for nid in ((c as Dictionary).get(grp, {}) as Dictionary).keys():
				var a := str(c[grp][nid].get("audio", ""))
				if a != "":
					var slot := a.trim_suffix(".ogg") if a.begins_with("voces/") else "voces/clientes/" + a.trim_suffix(".ogg")
					t.check(AudioManager.resolve(slot) != "", "cliente de práctica " + slot)
	await t.frames(1)


func _retraso(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	Discipline.call("_two_verbals", "sala")
	await t.seconds(1.0)
	var subs: Array = t.spy("subtitle")
	t.check(not str(Discipline.presence.get("last_pa")).contains("Primero la alerta"), "la alerta no sale de inmediato (no corta la voz del escalón)")
	var ok: bool = await t.until(func() -> bool:
		for s in subs:
			if str(s[1]).contains("Primero la alerta"):
				return true
		return false, 6.0)
	t.check(ok, "a los 4,5 s: «Primero la alerta. Después el written warning…» (clip cosechado)")
	t.check(AudioManager.resolve("voces/shero/shero_alerta_primero") != "", "el clip cosechado shero_alerta_primero existe (suena en persona o por los parlantes)")
	# Con una muerte en el medio se descarta
	Discipline.call("_two_verbals", "sala")
	var subs2: Array = t.spy("subtitle")
	await t.die("abandono", "", "shero")
	await t.seconds(5.5)
	var late := false
	for s in subs2:
		if str(s[1]).contains("Primero la alerta"):
			late = true
	t.check(not late, "tras una muerte el mensaje con retraso se descarta")
	await t.wait_death_shown()
	await t.reconnect()


func _segundo_ww(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	Discipline.call("_issue_ww", "abandono")
	await t.seconds(0.5)
	var subs: Array = t.spy("subtitle")
	Discipline.call("_issue_ww", "abandono")
	t.check(Metrics.written_warnings == 2, "dos WW en el turno (%d)" % Metrics.written_warnings)
	var ok: bool = await t.until(func() -> bool:
		for s in subs:
			if str(s[1]).contains("Segundo WW enviado"):
				return true
		return false, 7.0)
	t.check(ok, "el 2.º WW lo anuncia Shero por los parlantes («Segundo WW enviado, con copia a los tres OM…»)")
	var heard: bool = await t.until(func() -> bool: return str(AudioManager.last_voice.get("slot", "")) == "voces/shero/shero_procedimiento", 1.5)
	t.check(heard and str(AudioManager.last_voice.get("bus", "")) == "Parlantes", "suena el clip cosechado shero_procedimiento por el bus Parlantes")


func _ambiente(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	var posts: Array = t.spy("ezlak_post")
	await t.set_clock(GameState.hhmm_to_seconds("01:09"))
	await t.advance_clock(120.0)
	var said: Array = Discipline.presence.get("ambient_said")
	var found := false
	for s in said:
		if str(s["voz"]) == "shero_ezlak_profesional":
			found = true
			t.check(bool(s["en_persona"]), "en C-14 Shero lo dice en persona desde su sitio")
	t.check(found, "01:10 (T2): Shero dice «Ezlaki es una herramienta profesional…»")
	var posted := false
	for p in posts:
		if str(p[0]) == "#team-familia" and str(p[1]) == "shero" and str(p[2]).contains("herramienta profesional"):
			posted = true
	t.check(posted, "y lo publica en #team-familia")
	t.check(AudioManager.resolve("voces/shero/shero_ezlak_profesional") != "" and AudioManager.resolve("voces/shero/en/shero_ezlak_profesional") != "", "clip ES cosechado + EN")
	# Un checkpoint con el reloj ya muy pasado no los dispara todos de golpe
	var n0 := said.size()
	await t.set_clock(GameState.hhmm_to_seconds("07:00"))
	await t.frames(2)
	t.check((Discipline.presence.get("ambient_said") as Array).size() == n0, "con el reloj muy pasado no suenan todos de golpe")


func _ronquido(t: Node) -> void:
	t.check(AudioManager.resolve("voces/agentes/juan_ronquido") == "", "juan_ronquido ya no está en el juego")
	var raw := FileAccess.get_file_as_string("res://data/lineas_agentes.json")
	t.check(not raw.contains("juan_ronquido"), "ningún dato lo pide")
	t.check(AudioManager.resolve("voces/agentes/dm_juan_llauri_2") != "", "su DM tiene la voz sintética de Juan")
	await t.frames(1)


const FIX := "res://scripts/dev/fixtures/saves/"


static func _has_branch_turn(list: Array, n: int) -> bool:
	for e in list:
		if e is Dictionary and int(e.get("turno", 0)) == n and bool(e.get("rama", false)):
			return true
	return false


static func _copy(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(src))
	f.close()


func _mig_v02(t: Node) -> void:
	var legacy := SaveSlots.legacy_dir
	_copy(FIX + "v02/progreso.json", legacy + "progreso.json")
	_copy(FIX + "v02/save_slot_1.json", legacy + "save_slot_1.json")
	var old_cp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v02/save_slot_1.json"))
	var old_clock := float((old_cp.get("game_state", {}) as Dictionary).get("clock_seconds", 0.0))
	var done: Array = SaveSlots.migrate_v02()
	t.check(done.size() == 2, "v0.2 real: migra progreso y checkpoint (%s)" % str(done))
	var p := SaveSlots.load("Jiroshi")
	t.check(int(p.get("turno_desbloqueado", 0)) == 2 and int(p.get("version", 0)) == SaveSlots.VERSION, "Jiroshi: T2 desbloqueado, partida v%d" % int(p.get("version", 0)))
	t.check(_has_branch_turn(SaveSlots.choosable_turns("Jiroshi"), 1), "Elegir turno ofrece el T1 ya jugado (como rama)")
	t.check(SaveSlots.summary_text("Jiroshi") != "", "el menú muestra su resumen: " + SaveSlots.summary_text("Jiroshi"))
	SaveSlots.select("Jiroshi")
	t.main.call("_continue_shift")
	await t.frames(1)
	var c0 := GameState.clock_seconds
	await t.frames(4)
	t.check(GameState.running and GameState.turno == 2 and GameState.agent == "Jiroshi", "Continuar sigue el T2 a medias de la v0.2")
	t.check(absf(c0 - old_clock) < 90.0, "en su hora (%s; guardado %s)" % [GameState.clock_text_at(c0), GameState.clock_text_at(old_clock)])
	t.check(Metrics.aux == Metrics.Aux.AVAILABLE, "AUX migrado (Available)")
	await t.back_to_menu()
	t.check(SaveSlots.start_branch(1, -1, -1, "Jiroshi"), "rama del T1 desde la partida migrada")
	SaveSlots.end_branch(false)
	t.check(int(SaveSlots.load("Jiroshi").get("turno_desbloqueado", 0)) == 2, "la rama no cambia la partida principal")


func _mig_beta1(t: Node) -> void:
	var dir := SaveSlots.root + "marko/"
	(SaveSlots.get("_cache") as Dictionary).clear()
	_copy(FIX + "v03beta1/marko/progreso.json", dir + "progreso.json")
	_copy(FIX + "v03beta1/marko/checkpoint.json", dir + "checkpoint.json")
	var p := SaveSlots.load("Marko")
	t.check(int(p.get("version", 0)) == SaveSlots.VERSION and (p.get("turnos", {}) as Dictionary).size() == 2, "v0.3-beta1 real (v3) → v%d con instantáneas de T1 y T2 (%d)" % [int(p.get("version", 0)), (p.get("turnos", {}) as Dictionary).size()])
	t.check(str(p.get("dificultad", "")) == "normal" and int(p.get("turno_desbloqueado", 0)) == 2, "dificultad y turno conservados")
	t.check(SaveSlots.frontier("Marko") == 2 and _has_branch_turn(SaveSlots.choosable_turns("Marko"), 1), "Elegir turno: T1 como rama (frontera T2)")
	SaveSlots.select("Marko")
	t.main.call("_continue_shift")
	await t.frames(5)
	t.check(GameState.running and GameState.turno == 2 and GameState.agent == "Marko", "Continuar sigue el T2 de Marko desde su checkpoint de login")
	await t.back_to_menu()
	t.check(not SaveSlots.exists("Jiroshi"), "no crea partidas de otros agentes")


func _motivos(t: Node) -> void:
	var n := 0
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/muertes.json")):
			var id := str((c as Dictionary).get("id", ""))
			for det in ["", "16:00", "Baño 02:31", "4"]:
				var txt := Checkpoints.cause_text(id, det)
				var rest := txt.replace(det, "") if det != "" else txt
				n += 1
				if rest.contains(":"):
					t.fail("%s [%s] «%s»: dos puntos" % [id, lang, txt])
				if txt.ends_with(" ") or txt.contains("()") or txt.contains(" .") or txt.ends_with(":"):
					t.fail("%s [%s] «%s»: puntuación suelta" % [id, lang, txt])
	Loc.set_language("es")
	t.check(n > 100, "%d motivos revisados (ES/EN, con y sin detalle)" % n)
	await t.frames(1)



## Los archivos de voz de una línea del guion del Training (TrainingVoice): "t_<id>" Trainer (una sola voz, o una por
## agente si dice tu nombre), "piensa:<n>" (cada agente), "promo:<id>", "comodin" (quien conteste), "bien" / "casi".
func _training_slots(id: String) -> Array:
	var out: Array = []
	if id == "bien" or id == "casi":
		for k in (TrainingVoice.PRAISE if id == "bien" else TrainingVoice.CHEER):
			out.append("voces/trainer_amable/" + str(k))
	elif id.begins_with("piensa:"):
		for a in GameState.AGENTS:
			var lines := Flashback.inner_lines(a)
			var k := int(id.substr(7))
			out.append("voces/agentes/" + (str((lines[k] as Dictionary).get("voz", "?")) if k < lines.size() else "falta_%s_%d" % [a, k]))
	elif id.begins_with("promo:"):
		var found := false
		for c in Flashback.classmate_lines():
			if str((c as Dictionary).get("id", "")) == id.substr(6):
				out.append("voces/promocion/" + str((c as Dictionary).get("voz", "?")))
				found = true
		if not found:
			out.append("voces/promocion/falta_" + id.substr(6))
	elif id == "comodin":
		for c in Flashback.comodin_lines().values():
			out.append("voces/promocion/" + str((c as Dictionary).get("voz", "?")))
	elif AudioManager.resolve("voces/trainer_amable/" + id) != "":
		out.append("voces/trainer_amable/" + id)
	else:
		for a in GameState.AGENTS:
			out.append("voces/trainer_amable/%s_%s" % [id, str(a).to_lower()])
	return out

## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P4 (PC acercada): escritorio, cada app, Ezlaki por canal, Portal Vitzo, KYC, árbol y Fatiga alta.
## `-- --shot p4` las captura todas (también con `--resolution 1280x720`).


func shots() -> Array[String]:
	return ["p4_escritorio", "p4_arbol", "p4_arbol_wmm", "p4_correo", "p4_portal", "p4_identa", "p4_campus", "p4_ezlak_allocations", "p4_ezlak_site", "p4_ezlak_team", "p4_ezlak_dm_shero", "p4_terminal", "p4_fatiga", "p4_monitores"]


func _ws(s: Node) -> Node:
	return s.get_tree().get_first_node_in_group("workstation")


func _cm(s: Node) -> ContactManager:
	return s._main.get("contacts") as ContactManager


func _contact(cid: String) -> Dictionary:
	for tn in [1, 2, 3]:
		for c in DataLoader.dict("contactos_t%d" % tn).get("contactos", []):
			if str(c.get("id", "")) == cid:
				return (c as Dictionary).duplicate(true)
	var bo := DataLoader.dict("casos_bo")
	for tn in ["1", "2", "3"]:
		for c in (bo.get("turnos", {}) as Dictionary).get(tn, []):
			if str(c.get("id", "")) == cid:
				return (c as Dictionary).duplicate(true)
	return {}


func _start(s: Node, cid: String) -> void:
	var cm := _cm(s)
	_end(s)
	cm._offer(_contact(cid))
	cm.accept()


func _end(s: Node) -> void:
	var cm := _cm(s)
	cm.phase = ContactManager.Phase.IDLE
	cm.current = {}
	cm.tree = null
	cm.case = null
	cm.composer = {}
	cm.portal_view = {}


func _seed_ezlak(s: Node) -> void:
	await s.get_tree().create_timer(0.1).timeout
	GameState.clock_seconds = 3.4 * 3600.0
	EventBus.clock_tick.emit(GameState.clock_seconds)
	await s.get_tree().create_timer(3.5).timeout


func shoot(name: String, _arg: String, s: Node) -> void:
	await s._sit_c14()
	var ws := _ws(s)
	var desk: PcDesktop = ws.get("desktop")
	var ez: PcEzlak = ws.get("ezlak")
	ws.call("set_zoom", true)
	Fatigue.set_value(35.0)
	match name:
		"p4_escritorio":
			_end(s)
			await _seed_ezlak(s)
			desk.open_app("kardex")
			ez.open_channel("#team-familia")
		"p4_arbol":
			await _seed_ezlak(s)
			_start(s, "t1c2")
			_cm(s).choose(0)
			ez.open_channel("dm:shero")
		"p4_arbol_wmm":
			_start(s, "t2c9")
			_cm(s).choose(0)
			ez.open_channel("#site-updates")
		"p4_correo":
			_start(s, "vz_pod")
			var cm := _cm(s)
			cm.kardex_lookup("KP-2302-7731")
			cm.set_recipient("Banco Andino")
			cm.set_template("POD")
			cm.set_field("id", "KP-2302-7731")
			GameState.add_game_time(400.0)
			desk.open_app("correo")
		"p4_portal":
			_start(s, "vz_pod")
			_cm(s).portal_search("KP-2302-7731")
			desk.open_app("portal")
		"p4_identa":
			_start(s, "t3_kyc_reforzada")
			desk.open_app("identa")
		"p4_campus":
			_end(s)
			var m := s.get_tree().get_first_node_in_group("mentor") as Mentor
			if m != null and not m.minitrainings_open.has("mt_vitzo"):
				m.minitrainings_open.append_array(["mt_empatia", "mt_vitzo"])
			desk.open_app("campus")
			desk.campus._selected = "mt_vitzo"
		"p4_ezlak_allocations":
			await _seed_ezlak(s)
			var m2 := s.get_tree().get_first_node_in_group("mentor") as Mentor
			if m2 != null:
				m2.post_allocation_now()
			ez.open_channel("#allocations")
		"p4_ezlak_site":
			await _seed_ezlak(s)
			var v := s.get_tree().get_first_node_in_group("vitzo")
			v.call("post_reminder")
			ez.open_channel("#site-updates")
		"p4_ezlak_team":
			await _seed_ezlak(s)
			var m3 := s.get_tree().get_first_node_in_group("mentor") as Mentor
			if m3 != null:
				m3.post_list_now()
			ez.open_channel("#team-familia")
		"p4_ezlak_dm_shero":
			await _seed_ezlak(s)
			Metrics.issue_written_warning("aht_bo")
			EventBus.ezlak_post.emit("dm:shero", "shero", "Vi.", {"typing_s": 8.0})
			await s.get_tree().create_timer(0.3).timeout
			ez.open_channel("dm:shero")
		"p4_terminal":
			ws.call("set_zoom", true)  # v0.3.2: sin terminales de pared; la vista equivalente es la PC
			await _seed_ezlak(s)
			ez.open_channel("#allocations")
		"p4_fatiga":
			Fatigue.set_value(92.0)
			_start(s, "t2c8")
			_cm(s).choose(0)
			ws.set("_glitch_wait", 0.0)
		"p4_monitores":
			ws.call("set_zoom", false)
			_start(s, "t1c1")
	await s.get_tree().create_timer(0.4).timeout


func after(name: String, s: Node) -> void:
	var ws := _ws(s)
	if Metrics.ack_pending:
		Metrics.give_ack()
	_end(s)
	if name == "p4_terminal":
		ws.call("_close_terminal")
	ws.call("set_zoom", false)
	Fatigue.set_value(35.0)
	await s.get_tree().create_timer(0.1).timeout

## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas del feedback de Joan (v0.3.2): los correos por pasos y el karaoke cantado.
##   `-- --shot fb_correo:<caso>,<etapa>`   la PC acercada con el correo <caso> (t1_correo_pod, vz_status, vz_pod,
##        vz_reversal, t2_correo_reversal, t3_correo_status) en la etapa: inicio (antes de Kardex) · kardex (recién
##        buscada la operación) · portal (casos de Vitzo: con el Portal hecho) · campos (redactado, antes de enviar) ·
##        listo (enviado y tipificado). `,kardex_app` al final muestra la app Kardex en vez del Correo.
##   `-- --shot fb_karaoke:<verso>[,en]`    el evento de karaoke a mitad del verso <verso> (1-5), con la letra pintada.
##   `-- --shot fb_video:karaoke[,en]`      el karaoke entero para grabar con --write-movie (marcas [video] inicio/fin).

const P5 := "res://scripts/dev/shots/p5_personajes.gd"
const FBM := "res://scripts/dev/escenarios/v032_fbmail.gd"


func shots() -> Array[String]:
	return ["fb_correo:", "fb_karaoke:", "fb_video:"]


func _wait(s: Node, secs: float) -> void:
	await s.get_tree().create_timer(secs).timeout


func _quiet(s: Node) -> void:
	for n in s.get_tree().get_nodes_in_group("shero"):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	GameState.stop_calm()


func shoot(name: String, arg: String, s: Node) -> void:
	match name:
		"fb_correo":
			await _mail(s, arg)
		"fb_karaoke":
			await _karaoke(s, int(arg.get_slice(",", 0)), arg.contains(",en"), false)
		"fb_video":
			await _karaoke(s, 5, arg.contains(",en"), true)


func after(name: String, s: Node) -> void:
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null:
		ws.call("set_zoom", false)
	if name != "fb_correo":
		var hub := PersonajesP5.get_hub(s.get_tree())
		if hub != null and hub.rasec != null:
			hub.rasec.call("_end_event_ui")
		Loc.set_language("es")


func _mail(s: Node, arg: String) -> void:
	var cid := arg.get_slice(",", 0)
	var stage := arg.get_slice(",", 1) if arg.contains(",") else "kardex"
	var fbm: Object = (load(FBM) as GDScript).new()
	var c: Dictionary = fbm.call("case_by_id", cid)
	await s._sit_c14()
	_quiet(s)
	(SaveSlots.progress().get("tooltips_vistos", []) as Array).erase(PcCorreo.GUIDE_FLAG)
	var cm := s._main.get("contacts") as ContactManager
	cm.process_mode = Node.PROCESS_MODE_INHERIT
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(c.duplicate(true))
	cm.accept()
	cm.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(s, 0.2)
	var desk := s.get_tree().get_first_node_in_group("pc_desktop") as PcDesktop
	desk.correo._guide_off = false
	desk.correo._guide_case = ""
	var corr: Dictionary = c.get("correcto", {})
	var tx := str(c.get("tx", ""))
	if stage != "inicio":
		cm.kardex_lookup(tx)
	if stage in ["portal", "campos", "listo"]:
		for p in corr.get("portal", []):
			match str(p):
				"buscar": cm.portal_search(tx)
				"pod": cm.portal_download_pod()
				"reversal": cm.portal_reversal()
	if stage in ["campos", "listo"] and str(corr.get("destinatario", "")) != "":
		cm.set_recipient(str(corr.get("destinatario", "")))
		cm.set_template(str(corr.get("plantilla", "")))
		for f in CasoBO.FIELDS:
			desk.kardex.copy_value(str((corr.get("campos", {}) as Dictionary).get(f, "")), f)
		if bool(corr.get("adjunto_pod", false)):
			cm.portal_attach_pod()
	if stage == "listo":
		if str(corr.get("destinatario", "")) != "":
			cm.send_email()
		cm.set_typification(str(corr.get("tipificacion", "")))
	desk.open_app("kardex" if arg.ends_with(",kardex_app") else ("portal" if arg.ends_with(",portal_app") else "correo"))
	var ws := s.get_tree().get_first_node_in_group("workstation")
	ws.call("set_zoom", true)
	ws.call("cycle_layout")  # solo la pantalla izquierda, más grande
	await _wait(s, 0.6)


## El jugador del evento: canta a 1 s de que salga el verso y responde la primera opción a 1,2 s de cada pregunta.
func _play_event(s: Node, rasec: RasecControl, until_verse: int, mid: bool) -> void:
	var last_mode := ""
	var since := 0.0
	var guard := 0.0
	while guard < 200.0 and rasec.state == RasecControl.State.EVENTO:
		await s.get_tree().process_frame
		var dt: float = s.get_process_delta_time()
		guard += dt
		var ui := rasec.ui
		if ui == null or not is_instance_valid(ui):
			continue
		var mode := str(ui.get("_mode"))
		if mode != last_mode:
			last_mode = mode
			since = 0.0
		since += dt
		if mode == "press" and since > 1.0 and since < 50.0:
			ui.call("_resolve", true)
			since = 100.0
		elif mode == "choose" and since > 1.2 and since < 50.0:
			ui.call("_resolve", 0)
			since = 100.0
		if rasec.sung.size() >= until_verse:
			var line: Object = rasec.sung[until_verse - 1][3]
			var st := int(line.get("started_ms"))
			if mid and st >= 0 and float(VoiceDirector.now_ms() - st) / 1000.0 > float(KaraokeVoz.verse(until_verse - 1).get("canto", 4.0)) * 0.55:
				return
			if not mid and bool(line.get("done")):
				return


func _karaoke(s: Node, verse: int, en: bool, video: bool) -> void:
	Loc.set_language("en" if en else "es")
	var p5: Object = (load(P5) as GDScript).new()
	var hub := PersonajesP5.get_hub(s.get_tree())
	hub.rasec.forced_play = ""
	await p5.call("_event", s, "karaoke")
	await p5.call("_face_rasec", s)
	if video:
		# hasta que va a empezar el primer verso (la intro y la primera pregunta quedan fuera del clip)
		var guard := 0.0
		var last_mode := ""
		var since := 0.0
		while guard < 60.0 and hub.rasec.sung.is_empty() and hub.rasec.state == RasecControl.State.EVENTO:
			await s.get_tree().process_frame
			var dt: float = s.get_process_delta_time()
			guard += dt
			var ui := hub.rasec.ui
			if ui == null or not is_instance_valid(ui):
				continue
			var mode := str(ui.get("_mode"))
			if mode != last_mode:
				last_mode = mode
				since = 0.0
			since += dt
			if mode == "choose" and since > 1.2 and since < 50.0:
				ui.call("_resolve", 0)
				since = 100.0
			if ui.call("shown_text") == Loc.pick(((DataLoader.dict("rasec_eventos").get("karaoke", {}) as Dictionary).get("versos", [{}]) as Array)[0]):
				break
		print("[video] inicio %d" % Engine.get_frames_drawn())
		await _play_event(s, hub.rasec, 5, false)
		await _wait(s, 2.5)
		print("[video] fin %d" % Engine.get_frames_drawn())
	else:
		await _play_event(s, hub.rasec, clampi(verse, 1, 5), true)

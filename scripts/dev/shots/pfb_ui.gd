## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.2 · feedback de Joan sobre la beta (los pasos del Training): un paso cualquiera del Training tal como lo ve el
## jugador, con la PC acercada o no, antes o después de contestar el mini-check.
##   -- --shot fbui:<modulo>.<paso>[.zoom][.resp][.mal][.izq][.der]
##     zoom = con la vista de la PC acercada · resp = con el mini-check ya contestado (bien; .mal = mal)
##     izq / der = solo la pantalla izquierda / derecha acercada ([Tab])
## Varias en una corrida: `--shot fbui:aux.menu_aux.zoom+fbui:correo.check.zoom.resp`. `--lang en` para el inglés.
## Este archivo corre igual en el árbol de la beta (solo usa la API del bot del Training): las capturas «antes».

const BOT := "res://scripts/dev/bot_tutorial.gd"


func shots() -> Array[String]:
	return ["fbui:"]


func shoot(_name: String, arg: String, s: Node) -> void:
	var parts := arg.split(".", false)
	if parts.size() < 2:
		printerr("[shot] fbui:<modulo>.<paso>[.zoom][.resp]")
		return
	var mod := str(parts[0])
	var step := str(parts[1])
	var flags: Array = []
	for i in range(2, parts.size()):
		flags.append(str(parts[i]))
	s._main.call("_back_to_menu")
	await s.get_tree().create_timer(0.2).timeout
	var bot: Node = (load(BOT) as GDScript).new()
	bot.name = "BotShot"
	bot.set("stop_at", mod + "/" + step)
	bot.set("log_steps", false)
	s.add_child(bot)
	bot.call("start", s._main, [mod], [])
	var w := 0.0
	while not bool(bot.get("stopped")) and w < 90.0:
		await s.get_tree().create_timer(0.1).timeout
		w += 0.1
	if not bool(bot.get("stopped")):
		printerr("[shot] fbui: el bot no llegó a %s/%s" % [mod, step])
	bot.set_process(false)
	await s.get_tree().create_timer(1.0).timeout
	# La toma arranca el Training en este módulo: la tarjeta de fecha del recuerdo (4,5 s reales) aún se está
	# yendo. En el juego, cuando llegas a este paso ya pasó hace rato: se espera a que se vaya.
	var wc := 0.0
	while s.get_tree().root.find_child("TarjetaRecuerdo", false, false) != null and wc < 20.0:
		await s.get_tree().create_timer(0.2).timeout
		wc += 0.2
	var ws := s.get_tree().get_first_node_in_group("workstation")
	if ws != null and GameState.seated_at != "":
		if flags.has("izq") or flags.has("der"):
			ws.set("_layout", 1 if flags.has("izq") else 2)
		ws.call("set_zoom", flags.has("zoom") or flags.has("izq") or flags.has("der"))
	var tut: Node = bot.get("tut")
	if (flags.has("resp") or flags.has("mal")) and tut != null and is_instance_valid(tut):
		var st: Dictionary = tut.call("step")
		if str(st.get("tipo", "")) == "pregunta":
			var ok := int(st.get("correcta", 0))
			tut.call("choose", (ok + 1) % 3 if flags.has("mal") else ok)
	await s.get_tree().create_timer(1.6).timeout
	bot.queue_free()

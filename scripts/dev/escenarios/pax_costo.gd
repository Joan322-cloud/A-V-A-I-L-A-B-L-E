## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Medición del costo de la animación de personajes (v0.3.2-anim). No es una prueba de reglas: imprime números.
##   `--escenario animcosto`  (archivo pax_costo.gd: queda fuera del grupo `pan`)
## En el piso 2 con todos sus compañeros sentados, logueado en C-14 (la vista real del jugador), mide el tiempo de
## proceso por fotograma (Performance.TIME_PROCESS) y lo que gastan los NpcAnimator (su propio cronómetro):
##   A) árbol, calidad normal      B) árbol, Modo liviano
##   C) como v0.3.1 (AnimationPlayer del GLB, sin árbol), normal      D) como v0.3.1, Modo liviano
## y lo mismo simulando un equipo a 4 fps (el HTML sin GPU): max_fps = 4, donde lo que cuenta es el costo POR CUADRO.
## Con `--headless` no hay dibujo: lo que se compara es CPU de animación + lógica.

func escenarios() -> Array[String]:
	return ["animcosto"]


func run(_id: String, _arg: String, t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	await t.seconds(2.0)
	var fl: Node = t.building().floor_node
	var rigs: Array = fl.find_children("*", "CharacterRig", true, false)
	var with_tree := rigs.filter(func(r): return (r as CharacterRig).animator != null)
	var n_anim := NpcAnimator._all.size()
	t.note("piso 2: %d CharacterRig, %d con árbol (NpcAnimator vivos: %d)" % [rigs.size(), with_tree.size(), n_anim])
	t.check(with_tree.size() >= 5, "hay gente en el piso 2 para medir (%d)" % with_tree.size())
	var prev_q := GfxQuality.current
	var res := {}
	# --- A/B: árbol (cronómetro propio de NpcAnimator: lógica + avance del árbol + mirada + mandíbula)
	for q in ["normal", "liviano"]:
		GfxQuality.current = "liviano" if q == "liviano" else ("media" if prev_q == "liviano" else prev_q)
		for fps in [0, 30, 4]:
			Engine.max_fps = fps if fps > 0 else 120
			await t.frames(8 if fps == 4 else 40)
			NpcAnimator.prof_usec = 0
			NpcAnimator.prof_ticks = 0
			NpcAnimator.prof_on = true
			var n := 28 if fps == 4 else 300
			for i in n:
				await t.get_tree().process_frame
			NpcAnimator.prof_on = false
			var key := "arbol/%s/%s" % [q, ("%dfps" % fps) if fps > 0 else "libre"]
			res[key] = [NpcAnimator.prof_usec / 1000.0 / n, float(NpcAnimator.prof_ticks) / n]
			t.note("%-22s %.3f ms/cuadro · %.1f árboles/cuadro · %.3f ms por árbol" % [key, res[key][0], res[key][1], res[key][0] / maxf(res[key][1], 0.01)])
	GfxQuality.current = prev_q
	# --- C: como v0.3.1 — cada personaje con su AnimationPlayer avanzando en CADA cuadro (no había LOD ni cupo). Se
	# cronometra el mismo trabajo que hacía el motor: advance(delta) de todos los AnimationPlayer del piso.
	var players: Array = []
	for a in NpcAnimator._all.duplicate():
		var an := a as NpcAnimator
		if not is_instance_valid(an) or an.player == null:
			continue
		var ap: AnimationPlayer = an.player
		var clip := an.current
		an.tree.active = false
		an.set_process(false)
		ap.active = true
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var legacy := "type" if clip in ["type", "sit_type"] else ("sit" if an.state == "seated" else "idle")
		if ap.has_animation(legacy):
			ap.play(legacy, -1.0, 0.9)
		players.append(ap)
	await t.frames(5)
	for fps in [0, 30, 4]:
		Engine.max_fps = fps if fps > 0 else 120
		await t.frames(8 if fps == 4 else 40)
		var n := 28 if fps == 4 else 300
		var usec := 0
		for i in n:
			await t.get_tree().process_frame
			var d: float = t.get_process_delta_time()
			var t0 := Time.get_ticks_usec()
			for ap in players:
				(ap as AnimationPlayer).advance(d)
			usec += Time.get_ticks_usec() - t0
		var key := "v031/%s" % [("%dfps" % fps) if fps > 0 else "libre"]
		res[key] = [usec / 1000.0 / n, float(players.size())]
		t.note("%-22s %.3f ms/cuadro · %d AnimationPlayer/cuadro · %.3f ms por AnimationPlayer" % [key, res[key][0], players.size(), res[key][0] / maxf(players.size(), 1)])
	Engine.max_fps = 0
	for fps in ["libre", "30fps", "4fps"]:
		var a: Array = res["arbol/normal/" + fps]
		var b: Array = res["arbol/liviano/" + fps]
		var c: Array = res["v031/" + fps]
		t.note("RESUMEN %s: árbol normal %.3f · árbol liviano %.3f · v0.3.1 %.3f ms/cuadro" % [fps, a[0], b[0], c[0]])
		t.check(b[0] <= c[0] * 1.05 + 0.02, "Modo liviano (%s): la animación no cuesta más que en v0.3.1 (%.3f vs %.3f ms/cuadro)" % [fps, b[0], c[0]])
	t.check(float(res["arbol/normal/libre"][0]) < 1.0, "calidad normal: animación del piso 2 < 1 ms/cuadro (%.3f)" % res["arbol/normal/libre"][0])
	Engine.time_scale = ts

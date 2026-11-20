## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios de v0.3.2-anim (AnimationTree de los personajes, NpcAnimator). `--escenario pan` (archivo pan_anim.gd); ids anim_.
##   anim_biblioteca     los 19 modelos traen su biblioteca a32 con los clips pedidos (y Perrito/Vitzo los suyos)
##   anim_marcha         quieto → caminar 1,3 → rápido 1,9 → correr 3,4 → sprint 4,6 m/s: estado loco, la marcha sube con
##                       la velocidad medida y los pies apoyados casi no patinan (velocidad del pie en el piso)
##   anim_giro           girar en el lugar mezcla turn_l / turn_r
##   anim_idle_variantes las variantes de idle rotan solas
##   anim_sentarse       sit_down → seated (solo) → type → stand_up → loco; sentarse desde de pie pasa por sit_down
##   anim_gestos         talk / point / open_hands / lean_in / slam_table van al estado act con su clip
##   anim_personajes     Shero camina enojado, el Trainer presenta y su mirada al pasillo es la postura de terror,
##                       Haime golpea el lapicero, Rasec baila / pincha, el agente cansado cabecea
##   anim_perrito / anim_vitzo   el perro (walk/run/sniff/growl) y Vitzo (glitch, gateo)
##   anim_clips_viejos   jumpscare_main / dead / stare_camera (del GLB) siguen sonando por el árbol; speed 0 congela
##   anim_lod            lejos baja la frecuencia y no mira; en Modo liviano no hay mirada
##   anim_jugador        el cuerpo del jugador (hide_head) sigue con el AnimationPlayer
##   anim_p5actor        los P5Actor (Haime, Rasec, Don Fermín…) usan el árbol con la misma API
##   anim_habla          cuando el personaje habla (EventBus.subtitle o VoiceDirector) gesticula solo: de pie elige un
##                       gesto de conversación, sentado pasa a sit_talk, mueve la mandíbula; al terminar vuelve; un gesto
##                       pedido a mano (slam_table) manda; en Modo liviano no hay mandíbula
##   anim_bucles         los bucles empalman: el último fotograma y el primero de cada clip en bucle casi coinciden
##   anim_voz_real       con el VoiceDirector de verdad y voces de verdad: el Trainer gesticula lo que dura EL AUDIO de
##                       su línea (ni menos ni más) y mueve la mandíbula; Haime sentado habla en sit_talk y, si le cortan
##                       la línea (cancel), calla en el acto; el Trainer amable del Training responde a su carpeta
##                       (trainer_amable) y su «señalar» de un ciclo vuelve solo a los gestos de hablar; por los parlantes
##                       o el auricular no gesticula nadie; una voz 3D colgada de Shero (en persona) lo hace hablar a él,
##                       el murmullo de un compañero mueve a ESE compañero; «[Marko] …» lo dice Marko
##   anim_mandibula      la mandíbula ABRE (el mentón baja; medido con la malla de cada modelo, no con un signo): en los
##                       clips de las bibliotecas que la mueven (hablar, bostezo, gruñido del perro), igual que en los
##                       «scream» propios de los GLB, y con la voz en el juego; nunca se mete en el cráneo ni pasa del
##                       tope de hablar (hasta WIP10 giraba al revés)
##   anim_manos          las manos en primera persona (ManosFx) son los brazos del agente: los cinco agentes traen los
##                       cuatro gestos con los tiempos de siempre; al guardar la mochila, dejar / sacar el táper y comer,
##                       las manos del cuerpo llegan delante de la cámara y se ven, llevan su objeto y lo sueltan, siguen
##                       la mirada, no se pisan con el sentado, vuelven al cuerpo, no dejan nodos; vapor blando (4 hilos
##                       en Modo liviano)

const HUMANS: Array[String] = ["shero", "grasa", "trainer", "haime", "agente_jiroshi", "agente_marko", "agente_llauri", "agente_ttoom",
	"agente_juan", "mentor", "om", "rasec", "papayala", "guardia_fermin", "enfermera", "enfermero", "marleny"]
const HUMAN_CLIPS: Array[String] = ["idle", "idle_look", "idle_watch", "idle_arms", "walk", "walk_brisk", "run", "sprint", "walk_angry",
	"walk_tired", "turn_l", "turn_r", "sit", "sit_down", "stand_up", "type", "phone", "read", "tired_nod", "rub_eyes", "yawn", "talk",
	"point", "open_hands", "lean_in", "slam_table", "present_a", "present_b", "terror", "dance", "dj", "pen_tap", "haime_lean", "sit_talk", "bored"]


func escenarios() -> Array[String]:
	return ["anim_biblioteca", "anim_marcha", "anim_giro", "anim_idle_variantes", "anim_sentarse", "anim_gestos", "anim_personajes",
		"anim_perrito", "anim_vitzo", "anim_clips_viejos", "anim_lod", "anim_jugador", "anim_p5actor", "anim_habla", "anim_bucles", "anim_voz_real", "anim_mandibula", "anim_manos"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"anim_biblioteca": _biblioteca(t)
		"anim_marcha": await _marcha(t)
		"anim_giro": await _giro(t)
		"anim_idle_variantes": await _idle_variantes(t)
		"anim_sentarse": await _sentarse(t)
		"anim_gestos": await _gestos(t)
		"anim_personajes": await _personajes(t)
		"anim_perrito": await _perrito(t)
		"anim_vitzo": await _vitzo(t)
		"anim_clips_viejos": await _viejos(t)
		"anim_lod": await _lod(t)
		"anim_jugador": await _jugador(t)
		"anim_p5actor": await _p5actor(t)
		"anim_habla": await _habla(t)
		"anim_bucles": _bucles(t)
		"anim_voz_real": await _voz_real(t)
		"anim_mandibula": await _mandibula(t)
		"anim_manos": await _manos(t)


## Banco de pruebas: un nodo en la raíz con una cámara mirando desde `cam_dist` m (para la mirada y el LOD).
func _bench(t: Node, cam_dist: float = 4.0) -> Node3D:
	var old := t.get_tree().root.get_node_or_null("BancoAnim")
	if old != null:
		old.free()
	var b := Node3D.new()
	b.name = "BancoAnim"
	t.get_tree().root.add_child(b)
	b.global_position = Vector3(500, 0, 500)
	var cam := Camera3D.new()
	cam.name = "Cam"
	b.add_child(cam)
	cam.position = Vector3(0, 1.6, -cam_dist)  # delante del personaje (miran a -Z)
	cam.rotation_degrees.y = 180.0
	cam.current = true
	return b


func _rig(b: Node3D, slug: String, h: float = 1.75) -> CharacterRig:
	var holder := Node3D.new()
	holder.name = "H_" + slug
	b.add_child(holder)
	return CharacterRig.attach(holder, slug, h)


## Estado del árbol (y variante del estado) ESPERANDO a que llegue: una orden que cae en mitad de un fundido espera a
## que termine (regla del motor: una transición a la vez, 0,15-0,3 s), así que cuántos fotogramas tarda depende de los
## fps. Las pruebas esperan la condición con un plazo en segundos de juego, nunca un número fijo de fotogramas (con
## fotogramas fijos pasaban a 20 fps con ventana y fallaban a 120 fps sin ventana o sin tope de fps).
func _en(t: Node, a: NpcAnimator, st: String, variante: String = "", plazo: float = 2.0) -> bool:
	return await t.until(func() -> bool:
		if a.current_state() != st:
			return false
		return variante == "" or _var(a) == variante, plazo)


func _var(a: NpcAnimator) -> String:
	match a.current_state():
		"seated":
			return str(a.tree.get("parameters/seated/sv/current_state"))
		"act":
			return str(a.tree.get("parameters/act/av/current_state"))
	return a.current_variant()


## Espera a que no quede ningún fundido entre estados (la pose ya es solo la del estado actual).
func _sin_fundido(t: Node, a: NpcAnimator, plazo: float = 2.0) -> bool:
	var pb := a.tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var ok: bool = await t.until(func() -> bool: return str(pb.get_fading_from_node()) == "" and pb.get_travel_path().is_empty(), plazo)
	await t.frames(2)
	return ok


func _cleanup(t: Node) -> void:
	var old := t.get_tree().root.get_node_or_null("BancoAnim")
	if old != null:
		old.queue_free()
	await t.frames(2)


func _biblioteca(t: Node) -> void:
	for m in HUMANS:
		var lib := load(NpcAnimator.ANIM_DIR + m + ".res") as AnimationLibrary
		if not t.check(lib != null, "%s: biblioteca a32" % m):
			continue
		var missing: Array = HUMAN_CLIPS.filter(func(c): return not lib.has_animation(c))
		t.check(missing.is_empty(), "%s: %d clips humanoides (faltan %s)" % [m, HUMAN_CLIPS.size(), str(missing)])
		var loco: Dictionary = lib.get_meta("loco", {})
		t.check(float(loco.get("walk", 0.0)) > 0.5 and float(loco.get("run", 0.0)) > float(loco.get("walk", 0.0)), "%s: stride de caminar < correr" % m)
		var w := lib.get_animation("walk")
		t.check(is_equal_approx(w.length, 1.0) and w.loop_mode == Animation.LOOP_LINEAR, "%s: ciclos de 1 s en bucle (en fase en el BlendSpace)" % m)
	for pair in [["perrito_rta", ["idle", "walk", "run", "sniff", "growl"]], ["vitzo", ["idle", "walk", "run", "crawl"]]]:
		var lib := load(NpcAnimator.ANIM_DIR + str(pair[0]) + ".res") as AnimationLibrary
		if t.check(lib != null, "%s: biblioteca" % pair[0]):
			for c in pair[1]:
				t.check(lib.has_animation(c), "%s: clip %s" % [pair[0], c])


## Velocidad horizontal (m/s) de los pies cuando están apoyados: con la cadencia ajustada a la velocidad ~0.
func _foot_slip(t: Node, r: CharacterRig, holder: Node3D, speed: float, secs: float) -> float:
	var sk: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
	var bones := [sk.find_bone("ball_l"), sk.find_bone("ball_r")]
	var prev: Array = [Vector3.INF, Vector3.INF]
	var was_down: Array = [false, false]
	var slips: Array[float] = []
	var el := 0.0
	while el < secs:
		var d := t.get_tree().root.get_process_delta_time()
		holder.position += Vector3(0, 0, -speed * d)
		var cam := holder.get_parent().get_node_or_null("Cam") as Node3D
		if cam != null:
			cam.position += Vector3(0, 0, -speed * d)  # la cámara acompaña (sigue de frente y cerca)
		await t.get_tree().process_frame
		el += d
		if el < 0.6:
			continue
		for i in 2:
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(bones[i]).origin
			# solo cuenta si el pie estaba apoyado en los dos fotogramas (con la máquina cargada un fotograma largo puede
			# juntar el apoyo con el vuelo y eso no es patinar)
			var down: bool = p.y - holder.global_position.y < 0.03
			if prev[i] != Vector3.INF and down and bool(was_down[i]) and d > 0.0 and d < 0.1:
				slips.append(Vector2(p.x - prev[i].x, p.z - prev[i].z).length() / d)
			prev[i] = p
			was_down[i] = down
	if slips.is_empty():
		return 99.0
	slips.sort()
	return slips[slips.size() / 2]


func _marcha(t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	var b := _bench(t, 6.0)
	var r := _rig(b, "agente_marko", 1.72)
	var h := r.get_parent() as Node3D
	t.check(r.animator != null and r.animator.tree != null and r.animator.tree.active, "el rig tiene AnimationTree activo")
	r.play("idle")
	await t.seconds(0.5)
	t.check(r.animator.current_state() == "loco" and r.animator.gait() < 0.1, "quieto: loco con marcha 0 (idle)")
	t.note("escala %.3f m/unidad · zancadas (unidades) %s · cadencias %s" % [r.animator.unit_m, str(r.animator._strides), str(r.animator._cadence)])
	var last := 0.0
	for row in [[1.3, "walk", 0.7, 1.6], [1.9, "walk", 1.4, 2.4], [3.4, "run", 2.3, 3.4], [4.6, "sprint", 3.0, 4.0]]:
		r.play(str(row[1]))
		var slip := await _foot_slip(t, r, h, float(row[0]), 2.2)
		var g := r.animator.gait()
		t.check(r.animator.current_state() == "loco", "%.1f m/s: estado loco" % row[0])
		t.check(g >= float(row[2]) and g <= float(row[3]) and g >= last - 0.05, "%.1f m/s: marcha %.2f en [%.1f, %.1f]" % [row[0], g, row[2], row[3]])
		var sc := float(r.animator.tree.get("parameters/loco/ts/scale"))
		t.check(sc > 0.5 and sc < 2.6, "%.1f m/s: cadencia %.2f ciclos/s" % [row[0], sc])
		t.check(slip < 0.12 + 0.03 * float(row[0]), "%.1f m/s: pie apoyado patina %.2f m/s (mediana)" % [row[0], slip])
		t.note("%.1f m/s: marcha %.2f, cadencia %.2f, el pie apoyado se mueve %.3f m/s" % [row[0], g, sc, slip])
		last = g
	r.play("idle")
	await t.seconds(0.8)
	t.check(r.animator.gait() < 0.2, "frena: vuelve a idle (marcha %.2f)" % r.animator.gait())
	Engine.time_scale = ts
	await _cleanup(t)


func _giro(t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	var b := _bench(t)
	var r := _rig(b, "om")
	var h := r.get_parent() as Node3D
	r.play("idle")
	await t.seconds(0.3)
	var el := 0.0
	var max_y := 0.0
	while el < 1.2:
		var d := t.get_tree().root.get_process_delta_time()
		h.rotation.y += 1.4 * d
		await t.get_tree().process_frame
		el += d
		max_y = maxf(max_y, (r.animator.tree.get("parameters/loco/bs/blend_position") as Vector2).y)
	t.check(max_y > 0.6, "girar a la izquierda en el lugar mezcla turn_l (y = %.2f)" % max_y)
	Engine.time_scale = ts
	await _cleanup(t)


func _idle_variantes(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "shero", 2.2)
	r.play("idle")
	var seen := {}
	for i in 40:
		await t.seconds(1.0)
		seen[r.animator.current_variant()] = true
	t.check(seen.size() >= 2, "Shero rota variantes de idle: %s" % str(seen.keys()))
	await _cleanup(t)


func _sentarse(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "agente_ttoom")
	var a := r.animator
	r.play("idle")
	await t.seconds(1.0)
	r.play("sit_down", false, 1.0, ["sit"])
	t.check(await _en(t, a, "sit_down", "", 1.0), "sit_down: estado %s" % a.current_state())
	t.check(await _en(t, a, "seated", "", 4.0), "al terminar sit_down pasa solo a seated")
	r.play("type", true, 1.0, ["sit"])
	t.check(await _en(t, a, "seated", "type"), "type: seated/type (%s)" % _var(a))
	r.play("phone")
	t.check(await _en(t, a, "seated", "phone"), "phone: seated/phone (mano al headset)")
	r.play("read")
	t.check(await _en(t, a, "seated", "read"), "read: seated/read")
	r.play("stand_up", false, 1.0, ["idle"])
	t.check(await _en(t, a, "stand_up", "", 1.0), "stand_up: estado stand_up")
	t.check(await _en(t, a, "loco", "", 4.0), "al terminar stand_up vuelve a loco")
	# sentarse sin pedir sit_down: lo pone el animador. La orden llega en pleno fundido stand_up → loco: espera a que
	# termine (≤ 0,3 s) y arranca; lo que NO puede pasar es que salte a seated sin pasar por sit_down.
	r.play("sit")
	var saw_down := false
	var skipped := false
	var el := 0.0
	while el < 4.0 and a.current_state() != "seated":
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		saw_down = saw_down or a.current_state() == "sit_down"
	skipped = not saw_down
	t.check(saw_down and el > 0.6, "de pie → sit: pasa por sit_down (visto %s, %.2f s)" % [str(saw_down), el])
	t.check(a.current_state() == "seated" and not skipped, "… y queda sentado")
	r.play("idle")
	t.check(await _en(t, a, "stand_up", "", 1.0), "sentado → idle: pasa por stand_up (%s)" % a.current_state())
	t.check(await _en(t, a, "loco", "", 4.0), "… y termina de pie (loco)")
	t.check(a.state == "loco", "… y el animador lo sabe (state = %s): vuelve la lógica de marcha y el LOD" % a.state)
	# sentado → walk: se para y, ya de pie, CAMINA (la marcha sube con la velocidad medida)
	r.play("sit")
	t.check(await _en(t, a, "seated", "", 4.0), "se vuelve a sentar")
	t.check(a.state == "seated", "… y el animador lo sabe (state = %s)" % a.state)
	r.play("walk")
	var h := r.get_parent() as Node3D
	var cam := b.get_node("Cam") as Node3D
	el = 0.0
	while el < 3.5:
		var d := t.get_process_delta_time()
		if a.current_state() == "loco":
			h.position += Vector3(0, 0, -1.3 * d)
			cam.position += Vector3(0, 0, -1.3 * d)
		await t.get_tree().process_frame
		el += d
	t.check(a.current_state() == "loco" and a.gait() > 0.6, "sentado → walk: se para y camina con marcha %.2f (no se desliza en idle)" % a.gait())
	r.play("idle")
	await t.seconds(0.8)
	# dos órdenes seguidas en el mismo fotograma (el guion cambia de idea): manda la última
	r.play("sit")
	r.play("idle")
	await t.seconds(2.5)
	t.check(a.current_state() == "loco", "sit e idle en el mismo fotograma: queda de pie (%s)" % a.current_state())
	# recién creado sentado: sin animación de sentarse (los agentes que ya están en su escritorio)
	var r2 := _rig(b, "agente_juan")
	r2.play("type", true, 0.9, ["sit", "idle"])
	t.check(await _en(t, r2.animator, "seated", "", 0.5), "spawn sentado: directo a seated (%s)" % r2.animator.current_state())
	await _cleanup(t)


func _gestos(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "mentor")
	for g in ["talk", "point", "open_hands", "lean_in", "slam_table"]:
		r.play(g, g != "slam_table")
		t.check(await _en(t, r.animator, "act", g), "%s: act/%s" % [g, g])
	r.play("idle")
	t.check(await _en(t, r.animator, "loco"), "vuelve a loco")
	await _cleanup(t)


func _personajes(t: Node) -> void:
	var b := _bench(t)
	var sh := _rig(b, "shero", 2.2)
	var bs := ((sh.animator.tree.tree_root as AnimationNodeStateMachine).get_node("loco") as AnimationNodeBlendTree).get_node("bs") as AnimationNodeBlendSpace2D
	t.check(str((bs.get_blend_point_node(1) as AnimationNodeAnimation).animation) == "a32/walk_angry", "Shero: el punto de caminar es walk_angry")
	var tr := _rig(b, "trainer", 1.86)
	tr.play("stare_camera", true, 1.0, ["idle"])
	t.check(await _en(t, tr.animator, "act", "terror"), "Trainer mirando el pasillo: postura de terror")
	tr.play("idle")
	var pres := false
	for i in 30:
		await t.seconds(1.0)
		if tr.animator.current_variant().begins_with("present") or tr.animator.current_variant() == "open_hands":
			pres = true
			break
	t.check(pres, "Trainer dictando: gestos de presentador (%s)" % tr.animator.current_variant())
	var ha := _rig(b, "haime", 1.78)
	ha.play("pen_tap")
	t.check(await _en(t, ha.animator, "seated", "pen_tap"), "Haime: lapicero")
	ha.play("haime_lean")
	t.check(await _en(t, ha.animator, "seated", "haime_lean"), "Haime: se inclina")
	var ra := _rig(b, "rasec", 1.84)
	for c in ["dance", "dj"]:
		ra.play(c)
		t.check(await _en(t, ra.animator, "act", c), "Rasec: %s" % c)
	var ag := _rig(b, "agente_llauri")
	ag.play("type")
	ag.animator.tired = 1.0
	# cada elección de variante es un sorteo (45 % de cansancio con tired = 1): en vez de esperar 50 s y fallar 1 de cada
	# 10 corridas, se acorta el reloj entre sorteos (40 sorteos: imposible que no salga ninguno si el camino funciona)
	var tired := false
	var picks := 0
	var seen := {}
	var el := 0.0
	while el < 60.0 and not tired:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		var v := str(ag.animator.tree.get("parameters/seated/sv/current_state"))
		seen[v] = true
		tired = v in NpcAnimator.TIRED
		if ag.animator._oneshot_left <= 0.0 and ag.animator._variant_t > 0.4:
			ag.animator._variant_t = 0.4
			picks += 1
	t.check(tired, "agente cansado: cabecea / se frota los ojos / bosteza (visto %s en %.1f s)" % [str(seen.keys()), el])
	await _cleanup(t)


func _perrito(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "perrito_rta", 0.7)
	t.check(r.animator != null, "Perrito RTA con árbol")
	for c in ["walk", "run"]:
		r.play(c)
		t.check(await _en(t, r.animator, "loco"), "perrito %s: loco" % c)
	for c in ["sniff", "growl"]:
		r.play(c)
		t.check(await _en(t, r.animator, "act", c), "perrito %s: act/%s" % [c, c])
	await _cleanup(t)


func _vitzo(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "vitzo", 1.9)
	t.check(r.animator != null, "Vitzo con árbol")
	r.play("idle")
	t.check(await _en(t, r.animator, "loco"), "Vitzo idle con glitch (loco)")
	r.play("crawl")
	t.check(await _en(t, r.animator, "act", "crawl"), "Vitzo gatea")
	r.play("jumpscare_main", false, 1.4, ["jumpscare_alt", "idle"])
	t.check(await _en(t, r.animator, "act", "jumpscare_main"), "su screamer viejo sigue")
	await _cleanup(t)


func _viejos(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "agente_marko")
	for c in ["jumpscare_main", "dead", "stare_camera", "hunch"]:
		r.play(c, c == "stare_camera")
		t.check(await _en(t, r.animator, "act", c), "clip del GLB %s por el árbol" % c)
	# speed 0 (kills: el reminder quieto): funde 0,25 s desde el gesto anterior hasta la pose de idle y ahí se queda
	# clavado. Se mide cuando el fundido terminó, sea cual sea el ritmo de fotogramas.
	r.play("idle", true, 0.0, ["stand"])
	var sk: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
	t.check(await _en(t, r.animator, "loco", "", 1.0) and await _sin_fundido(t, r.animator, 1.0), "speed 0: en menos de 1 s está en idle sin fundido pendiente")
	var p0: Array = []
	for i in sk.get_bone_count():
		p0.append(sk.get_bone_global_pose(i))
	var worst := 0.0
	var el := 0.0
	while el < 1.5:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		for i in sk.get_bone_count():
			var g := sk.get_bone_global_pose(i)
			worst = maxf(worst, g.origin.distance_to((p0[i] as Transform3D).origin))
			worst = maxf(worst, g.basis.get_rotation_quaternion().angle_to((p0[i] as Transform3D).basis.get_rotation_quaternion()) * 0.1)
	t.check(worst < 0.0005, "speed 0: pose congelada, ningún hueso se mueve en 1,5 s (máx. %.5f)" % worst)
	# y sigue congelada aunque el guion retoque huesos encima (kills): el árbol reescribe la pose en cada fotograma
	var hb := sk.find_bone("head")
	var q0 := sk.get_bone_pose_rotation(hb)
	sk.set_bone_pose_rotation(hb, q0 * Quaternion(Vector3.UP, 0.5))
	await t.frames(2)
	t.check(sk.get_bone_pose_rotation(hb).angle_to(q0) < 0.01, "speed 0: el árbol reescribe la pose en cada fotograma (un hueso retocado a mano vuelve)")
	r.play("idle", true, 1.0, ["stand"])
	await t.seconds(0.6)
	var moved := 0.0
	for i in sk.get_bone_count():
		moved = maxf(moved, sk.get_bone_global_pose(i).origin.distance_to((p0[i] as Transform3D).origin))
	t.check(moved > 0.0005, "speed 1 otra vez: vuelve a respirar (%.4f)" % moved)
	# biblioteca extra de otro paquete (muertes): play("k32/clip") va directo al AnimationPlayer y después vuelve el árbol
	var extra := AnimationLibrary.new()
	extra.add_animation("garra", (load(NpcAnimator.ANIM_DIR + "agente_marko.res") as AnimationLibrary).get_animation("slam_table").duplicate())
	r.animator.add_library("k32", extra)
	t.check(r.has_anim("k32/garra"), "biblioteca extra: has_anim(\"k32/garra\")")
	r.play("k32/garra", false, 1.0)
	await t.frames(3)
	t.check(r.current == "k32/garra" and not r.animator.tree.active and r.anim.current_animation == "k32/garra", "play(\"k32/garra\"): directo en el AnimationPlayer (%s)" % r.anim.current_animation)
	r.play("idle")
	t.check(r.animator.tree.active and await _en(t, r.animator, "loco"), "después play(\"idle\") vuelve al árbol")
	await _cleanup(t)


func _lod(t: Node) -> void:
	var b := _bench(t, 2.5)
	var r := _rig(b, "om")
	r.play("idle")
	await t.seconds(1.5)
	var near_iv := r.animator._tick_interval
	var look_near := r.animator._look.influence if r.animator._look != null else 0.0
	(b.get_node("Cam") as Camera3D).position = Vector3(0, 1.6, -40.0)
	await t.seconds(1.0)
	t.check(r.animator._tick_interval > near_iv * 3.0, "lejos actualiza menos (%.3f s vs %.3f s)" % [r.animator._tick_interval, near_iv])
	t.check(look_near > 0.3, "cerca y de frente mira a la cámara (%.2f)" % look_near)
	t.check(r.animator._look.influence < 0.05, "lejos no mira")
	(b.get_node("Cam") as Camera3D).position = Vector3(0, 1.6, -2.5)
	var prev := GfxQuality.current
	GfxQuality.current = "liviano"
	await t.seconds(1.0)
	t.check(r.animator._look.influence < 0.05, "Modo liviano: sin mirada")
	t.check(r.animator._tick_interval >= near_iv * 1.9, "Modo liviano: mitad de frecuencia")
	GfxQuality.current = prev
	# interruptor público look_enabled (lo usa el doble del espejo, paquete core) y cámara dentro del personaje
	var back: bool = await t.until(func() -> bool: return r.animator._look.influence > 0.3, 3.0)
	t.check(back, "de vuelta en calidad normal mira otra vez (%.2f)" % r.animator._look.influence)
	r.animator.look_enabled = false
	var off: bool = await t.until(func() -> bool: return r.animator._look.influence < 0.02 and not r.animator._look.active, 3.0)
	t.check(off, "look_enabled = false: deja de mirar y el modificador queda apagado (%.2f)" % r.animator._look.influence)
	r.animator.look_enabled = true
	back = await t.until(func() -> bool: return r.animator._look.influence > 0.3, 3.0)
	t.check(back, "look_enabled = true: vuelve a mirar")
	(b.get_node("Cam") as Camera3D).position = Vector3(0, 1.6, -0.1)
	off = await t.until(func() -> bool: return r.animator._look.influence < 0.02, 3.0)
	t.check(off, "con la cámara dentro de su cabeza no intenta mirarla (%.2f)" % r.animator._look.influence)
	await _cleanup(t)


func _jugador(t: Node) -> void:
	var b := _bench(t)
	var r := _rig(b, "agente_jiroshi", 1.72)
	r.hide_head()
	await t.frames(2)
	t.check(r.animator == null and r.anim.active, "cuerpo del jugador: AnimationPlayer (sin árbol)")
	r.play("sit")
	await t.frames(2)
	t.check(r.anim.current_animation == "sit", "y sigue reproduciendo sus clips (%s)" % r.anim.current_animation)
	await _cleanup(t)
	# el jugador de verdad, recién empezado el turno y SIN haberse sentado todavía: su cuerpo tiene que estar en «idle»
	# con los brazos colgando (player.gd pide play("idle") ANTES de hide_head(): si esa orden se pierde con el árbol, el
	# cuerpo queda en la pose de reposo del GLB con los brazos estirados delante de la cámara)
	await t.start_shift("Jiroshi", 1)
	await t.seconds(0.6)
	var pr := t.player().get("_rig") as CharacterRig
	if t.check(pr != null and pr.animator == null and pr.anim != null, "el jugador tiene su cuerpo con AnimationPlayer"):
		t.check(pr.anim.is_playing() and str(pr.anim.current_animation) == "idle", "recién llegado, de pie: reproduce idle (suena «%s», activo %s)" % [pr.anim.current_animation, str(pr.anim.is_playing())])
		var sk: Skeleton3D = pr.find_children("*", "Skeleton3D", true, false)[0]
		for side in ["l", "r"]:
			var ua := sk.find_bone("upperarm_" + side)
			var la := sk.find_bone("lowerarm_" + side)
			var hd := sk.find_bone("hand_" + side)
			if ua < 0 or la < 0 or hd < 0:
				continue
			var a := sk.get_bone_global_pose(ua).origin
			var e := sk.get_bone_global_pose(la).origin
			var c := sk.get_bone_global_pose(hd).origin
			var dir := (c - a).normalized()
			var fore := (c - e).normalized()
			t.note("brazo %s: hombro→mano (%.2f, %.2f, %.2f) · antebrazo (%.2f, %.2f, %.2f)" % [side, dir.x, dir.y, dir.z, fore.x, fore.y, fore.z])
			t.check(dir.y < -0.9 and fore.y < -0.8, "brazo %s colgando al costado (hombro→mano baja %.2f, antebrazo baja %.2f)" % [side, dir.y, fore.y])
	await t.back_to_menu()


func _p5actor(t: Node) -> void:
	var b := _bench(t)
	for slug in ["haime", "rasec", "guardia_fermin", "enfermero"]:
		var a := P5Actor.make(b, slug, 1.78, Vector3.ZERO)
		t.check(a.animator != null, "%s: P5Actor con árbol" % slug)
		a.play("sit", false, 0.6, ["idle"])
		t.check(await _en(t, a.animator, "seated", "", 0.5) and a.current_anim == "sit", "%s: sit → seated" % slug)
		a.play("walk")
		t.check(await t.until(func() -> bool: return a.animator.current_state() in ["loco", "stand_up"], 1.0), "%s: walk → loco" % slug)
	await _cleanup(t)



## Señales del VoiceDirector de v0.3.2 (paquete de bugs) para probar el animador sin ese autoload.
class FakeVoice extends Node:
	signal finished(line_id: String)
	signal line_started(line_id: String, speaker: String, priority: int)
	signal subtitle_shown(speaker: String, text: String, seconds: float)


## Dónde está el mentón: centro de los vértices con peso > 0,5 en el hueso "jaw", respecto del pivote, en el espacio del
## esqueleto en reposo (Y arriba). Vector3.ZERO si el modelo no tiene hueso o no tiene malla pegada a la mandíbula.
func _chin(sk: Skeleton3D) -> Vector3:
	var j := sk.find_bone("jaw")
	if j < 0:
		return Vector3.ZERO
	var gr := sk.get_bone_global_rest(j)
	var sum := Vector3.ZERO
	var n := 0
	for node in sk.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var k := -1
		for bi in mi.skin.get_bind_count():
			if str(mi.skin.get_bind_name(bi)) == "jaw" or mi.skin.get_bind_bone(bi) == j:
				k = bi
		if k < 0:
			continue
		var to_sk := gr * mi.skin.get_bind_pose(k)
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null or vs.is_empty():
				continue
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bs.size() / vs.size()
			for vi in vs.size():
				for c in per:
					if bs[vi * per + c] == k and ws[vi * per + c] > 0.5:
						sum += to_sk * vs[vi]
						n += 1
	return (sum / float(n) - gr.origin) if n >= 8 else Vector3.ZERO


## Cuánto BAJA el mentón (m; > 0 = la boca abre, < 0 = la mandíbula se mete en el cráneo) con la rotación local `q` del
## hueso "jaw", con el resto del cuerpo en reposo.
func _chin_drop(sk: Skeleton3D, chin: Vector3, q: Quaternion) -> float:
	var j := sk.find_bone("jaw")
	var rest := sk.get_bone_rest(j).basis.get_rotation_quaternion()
	var pg := sk.get_bone_global_rest(sk.get_bone_parent(j)).basis.orthonormalized()
	var cp := pg.inverse() * chin
	return (pg * (cp - (q * rest.inverse()) * cp)).y


## Pista de rotación de la mandíbula de un clip: [mínimo, máximo] de lo que baja el mentón (m) y el giro máximo (°).
func _jaw_track(sk: Skeleton3D, chin: Vector3, a: Animation) -> Array:
	var lo := 0.0
	var hi := 0.0
	var deg := 0.0
	var rest := sk.get_bone_rest(sk.find_bone("jaw")).basis.get_rotation_quaternion()
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D or not str(a.track_get_path(i)).ends_with(":jaw"):
			continue
		for k in a.track_get_key_count(i):
			var q: Quaternion = a.track_get_key_value(i, k)
			var d := _chin_drop(sk, chin, q)
			lo = minf(lo, d)
			hi = maxf(hi, d)
			deg = maxf(deg, rad_to_deg(q.angle_to(rest)))
	return [lo, hi, deg]


func _mandibula(t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _reset_hub(t)
	var b := _bench(t, 3.0)
	var medidos := 0
	var habla: Array[String] = ["talk", "sit_talk", "phone", "present_a", "present_b"]
	for slug in HUMANS + ["perrito_rta"]:
		var r := _rig(b, slug, 1.75)
		var sk: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
		var chin := _chin(sk)
		if chin == Vector3.ZERO:
			t.note("%s: sin malla en la mandíbula (no se mide)" % slug)
			r.get_parent().free()
			continue
		medidos += 1
		var dog: bool = slug == "perrito_rta"
		t.check(chin.y < -0.005 and Vector2(chin.x, chin.z).length() > 0.02, "%s: el mentón queda adelante y debajo del pivote (%.3f, %.3f, %.3f)" % [slug, chin.x, chin.y, chin.z])
		# referencia: el clip propio del GLB que abre la boca
		var ap: AnimationPlayer = r.find_children("*", "AnimationPlayer", true, false)[0]
		for c in ["scream", "jumpscare_main"]:
			if ap.has_animation(c):
				var g: Array = _jaw_track(sk, chin, ap.get_animation(c))
				t.check(float(g[1]) > 0.004 and float(g[0]) > -0.0005, "%s: su «%s» del GLB abre la boca (el mentón baja %.1f cm, %.0f°)" % [slug, c, float(g[1]) * 100.0, g[2]])
				break
		# la biblioteca a32: todo clip que mueve la mandíbula la ABRE
		var lib := load(NpcAnimator.ANIM_DIR + slug + ".res") as AnimationLibrary
		var worst := 0.0
		var worst_clip := ""
		var abren := 0
		var tope := 0.0
		for cn in lib.get_animation_list():
			var m: Array = _jaw_track(sk, chin, lib.get_animation(cn))
			if float(m[0]) < worst:
				worst = float(m[0])
				worst_clip = cn
			if float(m[1]) > 0.0015:
				abren += 1
			if str(cn) in habla:
				tope = maxf(tope, float(m[2]))
		t.check(worst > -0.0005, "%s: ningún clip mete la mandíbula en el cráneo (peor: %s, %.1f mm)" % [slug, worst_clip, worst * 1000.0])
		t.note("%s: mentón a (%.3f, %.3f, %.3f) del pivote · %d clips abren la boca · pico al hablar sin voz %.1f° · peor cierre %.2f mm" % [slug, chin.x, chin.y, chin.z, abren, tope, worst * 1000.0])
		if dog:
			var gr: Array = _jaw_track(sk, chin, lib.get_animation("growl"))
			t.check(float(gr[1]) > 0.01, "el perro gruñe con el hocico abierto (baja %.1f cm, %.0f°)" % [float(gr[1]) * 100.0, gr[2]])
		else:
			var y: Array = _jaw_track(sk, chin, lib.get_animation("yawn"))
			t.check(float(y[1]) > 0.008 and float(y[2]) > 14.0 and float(y[2]) < 20.0, "%s: el bostezo abre bien la boca sin desencajarla (%.0f°, baja %.1f cm)" % [slug, y[2], float(y[1]) * 100.0])
			t.check(abren >= 6 and tope > 4.0 and tope < 9.6, "%s: %d clips abren la boca; al hablar sin voz el pico es de %.1f° (entre 4 y 9,5)" % [slug, abren, tope])
		r.get_parent().free()
	t.check(medidos >= 12, "modelos con malla en la mandíbula medidos: %d" % medidos)
	# con la voz, en el juego (sin audio que medir va por sílabas): abre, nunca al revés, y no pasa del tope
	var tr := _rig(b, "trainer", 1.88)
	tr.play("idle")
	await t.seconds(0.5)
	var sk2: Skeleton3D = tr.find_children("*", "Skeleton3D", true, false)[0]
	var chin2 := _chin(sk2)
	var jaw := sk2.find_bone("jaw")
	var rest2 := sk2.get_bone_rest(jaw).basis.get_rotation_quaternion()
	var real_vd := t.get_tree().root.get_node_or_null("VoiceDirector")
	if real_vd != null:
		real_vd.emit_signal("subtitle_shown", "trainer", "[Trainer] Bienvenidos a la capacitación, tomen asiento por favor.", 4.0)
	else:
		EventBus.subtitle.emit("trainer", "[Trainer] Bienvenidos a la capacitación, tomen asiento por favor.", 4.0)
	var lo := 0.0
	var hi := 0.0
	var deg := 0.0
	var el := 0.0
	while el < 2.5:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		var q := sk2.get_bone_pose_rotation(jaw)
		var d := _chin_drop(sk2, chin2, q)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		deg = maxf(deg, rad_to_deg(q.angle_to(rest2)))
	t.note("Trainer con voz: el mentón baja hasta %.1f mm (pico %.1f°), sube %.2f mm" % [hi * 1000.0, deg, -lo * 1000.0])
	t.check(tr.animator._talking and hi > 0.002 and lo > -0.0005, "el Trainer habla: el mentón baja (hasta %.1f mm) y nunca sube (%.2f mm)" % [hi * 1000.0, lo * 1000.0])
	t.check(deg > 2.0 and deg <= NpcAnimator.JAW_TALK_DEG + 0.3, "la voz REEMPLAZA a la mandíbula del clip: pico %.1f° (tope %.0f°)" % [deg, NpcAnimator.JAW_TALK_DEG])
	t.check(await t.until(func() -> bool: return not tr.animator._talking and not tr.animator._jaw_dirty, 8.0), "al callar suelta la mandíbula (queda la del clip)")
	Engine.time_scale = ts
	await _cleanup(t)


## Recorre una animación de ManosFx midiendo la mano `bone` en el espacio de la cámara. Devuelve
## [duró_s, punto_más_alto_en_cámara, s_en_pantalla, máx_nodos_hijos, distancia_mínima_a_la_cámara, veces_que_se_acercó].
func _medir_manos(t: Node, m: ManosFx, sk: Skeleton3D, bone: int, cam: Camera3D, near: float = 0.3) -> Array:
	var best := Vector3(0, -9, 0)
	var seen := 0.0
	var el := 0.0
	var kids := 0
	var dmin := 9.0
	var bites := 0
	var was_near := false
	while m.busy and el < 6.0:
		await t.get_tree().process_frame
		var dt := t.get_process_delta_time()
		el += dt
		if not m.busy:
			break
		var gp := sk.global_transform * sk.get_bone_global_pose(bone).origin
		var c := cam.global_transform.affine_inverse() * gp
		if c.y > best.y:
			best = c
		if cam.is_position_in_frustum(gp):
			seen += dt
		kids = maxi(kids, m.get_child_count())
		dmin = minf(dmin, c.length())
		var is_near := c.length() < near
		if is_near and not was_near:
			bites += 1
		was_near = is_near
	return [el, best, seen, kids, dmin, bites]


func _manos(t: Node) -> void:
	for a in ["agente_jiroshi", "agente_marko", "agente_llauri", "agente_ttoom", "agente_juan"]:
		var lib := load(NpcAnimator.ANIM_DIR + a + ".res") as AnimationLibrary
		var falta: Array = []
		for c in [["fp_casillero", 2.4], ["fp_dejar", 2.4], ["fp_sacar", 2.1], ["fp_comer", 3.3]]:
			if lib == null or not lib.has_animation(c[0]) or absf(lib.get_animation(c[0]).length - float(c[1])) > 0.06:
				falta.append(c[0])
		t.check(falta.is_empty(), "%s: trae los cuatro gestos de primera persona con sus tiempos (faltan %s)" % [a, str(falta)])
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await t.start_shift("Jiroshi", 1)
	await t.seconds(0.6)
	var pl := t.player() as Player
	var pr := pl.get("_rig") as CharacterRig
	var sk: Skeleton3D = pr.find_children("*", "Skeleton3D", true, false)[0]
	var cam := pl.camera
	var m := ManosFx.for_player(pl)
	var hr := sk.find_bone("hand_r")
	var hl := sk.find_bone("hand_l")
	var ua := sk.find_bone("upperarm_r")
	t.check(m != null and not m.busy and not m.visible and m.get_child_count() == 0, "ManosFx: nodo en la cámara, en reposo y vacío")
	for k in ["casillero", "refri_dejar", "refri_sacar", "microondas_meter", "microondas_sacar"]:
		pl.head.rotation.x = deg_to_rad(-12.0)
		await t.frames(2)
		var q0 := sk.get_bone_pose_rotation(ua)
		var d := m.play(k)
		var arms: bool = m._clip != null and m._arm.size() >= 30
		t.check(is_equal_approx(d, float(ManosFx.DUR[k])) and m.busy and m.visible and m.kind == k and arms, "%s: dura %.1f s (como en v0.3.1), ocupado y con los brazos del agente (%d huesos)" % [k, d, m._arm.size() + m._clav.size()])
		var r: Array = await _medir_manos(t, m, sk, hr, cam)
		var top: Vector3 = r[1]
		t.note("%s: duró %.2f s · mano derecha más alta en cámara (%.2f, %.2f, %.2f) · %.1f s en pantalla · %d objetos" % [k, r[0], top.x, top.y, top.z, r[2], r[3]])
		t.check(absf(float(r[0]) - d) < 0.25 and not m.busy and not m.visible, "%s: termina sola a su hora (%.2f s)" % [k, r[0]])
		t.check(top.z < -0.22 and top.z > -0.6 and top.y > -0.27 and absf(top.x) < 0.3, "%s: la mano derecha llega delante de la cámara (%.2f, %.2f, %.2f)" % [k, top.x, top.y, top.z])
		t.check(float(r[2]) > d * 0.35, "%s: la mano se ve en pantalla (%.1f s de %.1f)" % [k, r[2], d])
		t.check(int(r[3]) >= 1, "%s: lleva su objeto (%d)" % [k, r[3]])
		await t.frames(3)
		t.check(m.get_child_count() == 0, "%s: no deja nodos (%d)" % [k, m.get_child_count()])
		t.check(rad_to_deg(sk.get_bone_pose_rotation(ua).angle_to(q0)) < 10.0, "%s: el brazo vuelve a la pose del cuerpo (%.1f°)" % [k, rad_to_deg(sk.get_bone_pose_rotation(ua).angle_to(q0))])
	# el táper va SOBRE la palma y con la cinta hacia el jugador
	m.play("refri_dejar")
	await t.seconds(0.75)
	var tp := m.get_node_or_null("Taper") as Node3D
	var g := m.grip("r")
	if t.check(tp != null, "refri_dejar: táper en la mano"):
		var handw := sk.global_transform * sk.get_bone_global_pose(hr).origin
		t.check(g.basis.y.y > 0.6 and tp.global_position.y > handw.y, "la palma mira arriba y el táper va encima (palma %.2f, táper %.3f m sobre la muñeca)" % [g.basis.y.y, tp.global_position.y - handw.y])
		var to_cam := (cam.global_position - tp.global_position).normalized()
		t.check(tp.global_transform.basis.z.dot(to_cam) > 0.5, "la cinta con el nombre queda de cara al jugador (%.2f)" % tp.global_transform.basis.z.dot(to_cam))
	# la mirada: con la cámara más arriba que la referencia, las manos suben con ella
	var y_ref := (sk.global_transform * sk.get_bone_global_pose(hr).origin).y
	pl.head.rotation.x = deg_to_rad(12.0)
	await t.frames(3)
	var y_up := (sk.global_transform * sk.get_bone_global_pose(hr).origin).y
	t.check(y_up > y_ref + 0.06, "mirás 24° más arriba y la mano sube %.0f cm (sigue la mirada)" % ((y_up - y_ref) * 100.0))
	# pedir otra a mitad: reemplaza, sin fugas; y un teletransporte no rompe nada
	m.play("casillero")
	await t.frames(2)
	t.check(m.kind == "casillero" and m.busy, "otra acción a mitad reemplaza a la anterior")
	pl.teleport(pl.global_position + Vector3(0.3, 0, 0), 0.0)
	var r2: Array = await _medir_manos(t, m, sk, hr, cam)
	await t.frames(3)
	t.check(not m.busy and m.get_child_count() == 0, "termina y no deja nodos tras el reemplazo y un teletransporte (%.2f s)" % r2[0])
	# vapor del táper caliente: hilo blando (textura), 12 hilos; en Modo liviano 4
	for mode in ["media", "liviano"]:
		GfxQuality.current = mode
		m.play("microondas_sacar")
		await t.seconds(0.9)
		var v := m.find_child("Vapor", true, false) as CPUParticles3D
		var soft: bool = v != null and v.mesh is QuadMesh and ((v.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture != null
		t.check(v != null and v.emitting and soft and v.amount == (4 if mode == "liviano" else 12), "calidad %s: vapor de bordes blandos encendido con %d hilos" % [mode, v.amount if v != null else -1])
		t.check(m._clip != null, "calidad %s: los brazos son los del agente" % mode)
		await _medir_manos(t, m, sk, hr, cam)
	GfxQuality.current = "media"
	# sentado (comer): el cuerpo sigue en su clip de sentado, la derecha va tres veces a la boca, la izquierda sostiene
	await t.login_at_seat()
	await t.seconds(0.4)
	pl.head.rotation.x = deg_to_rad(-25.0)
	var d2 := m.play("comer")
	var r3: Array = await _medir_manos(t, m, sk, hr, cam, 0.27)
	t.note("comer: duró %.2f s · distancia mínima mano–cámara %.2f m · bocados %d · clip del cuerpo «%s»" % [r3[0], r3[4], r3[5], pr.anim.current_animation])
	t.check(is_equal_approx(d2, 3.3) and absf(float(r3[0]) - 3.3) < 0.25, "comer: 3,3 s")
	t.check(int(r3[5]) == 3, "comer: la mano del tenedor va tres veces a la boca (%d; mínima %.2f m de la cámara)" % [r3[5], r3[4]])
	t.check(str(pr.anim.current_animation) in ["sit", "type"] and pl.seated, "el cuerpo sigue sentado en su clip (%s)" % pr.anim.current_animation)
	await t.frames(3)
	t.check(m.get_child_count() == 0 and not m.visible, "comer: no deja nodos")
	Engine.time_scale = ts
	await t.back_to_menu()


func _reset_hub(t: Node) -> void:
	if NpcAnimator._hub != null and is_instance_valid(NpcAnimator._hub):
		NpcAnimator._hub.free()
	NpcAnimator._hub = null
	await t.frames(1)


func _habla(t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _reset_hub(t)
	var real_vd := t.get_tree().root.get_node_or_null("VoiceDirector")
	var b := _bench(t, 3.0)
	var tr := _rig(b, "trainer", 1.88)
	var ha := _rig(b, "haime", 1.78)
	var ag := _rig(b, "agente_marko", 1.7)
	tr.play("idle")
	ha.play("sit", true, 0.6, ["idle"])
	ag.play("type", true, 0.9, ["sit"])
	await t.seconds(0.5)
	var sk: Skeleton3D = tr.find_children("*", "Skeleton3D", true, false)[0]
	var jaw := sk.find_bone("jaw")
	# --- camino 1: EventBus.subtitle (v0.3.1) o el VoiceDirector real si este árbol ya lo trae
	var say := func(sp: String, text: String, secs: float) -> void:
		if real_vd != null:
			real_vd.emit_signal("subtitle_shown", sp, text, secs)
		else:
			EventBus.subtitle.emit(sp, text, secs)
	say.call("trainer", "[Trainer] Bienvenidos a la capacitación, tomen asiento por favor.", 4.0)
	await t.seconds(0.4)
	var v := tr.animator.current_variant()
	t.check(tr.animator._talking and v in ["present_a", "present_b", "open_hands", "talk"], "el Trainer habla de pie: gesto de conversación (%s)" % v)
	var moved := 0.0
	var q0 := sk.get_bone_pose_rotation(jaw)
	var elj := 0.0
	while elj < 0.9:  # por tiempo de juego, no por cuadros (a 120 fps o sin tope, 30 cuadros eran menos de una sílaba)
		await t.get_tree().process_frame
		elj += t.get_process_delta_time()
		moved = maxf(moved, sk.get_bone_pose_rotation(jaw).angle_to(q0))
	t.check(moved > deg_to_rad(2.0), "mueve la mandíbula al hablar (%.1f°)" % rad_to_deg(moved))
	t.check(not ha.animator._talking and not ag.animator._talking, "los demás no gesticulan con la línea del Trainer")
	say.call("haime", "[Haime] Siéntese. Vamos a escuchar su llamada.", 3.0)
	await t.seconds(0.4)
	t.check(str(ha.animator.tree.get("parameters/seated/sv/current_state")) == "sit_talk", "Haime sentado habla: sit_talk (%s)" % str(ha.animator.tree.get("parameters/seated/sv/current_state")))
	say.call("comp", "[Marko] oe, ¿ya viste la cola?", 3.0)
	await t.seconds(0.4)
	t.check(ag.animator._talking and str(ag.animator.tree.get("parameters/seated/sv/current_state")) == "sit_talk", "«un compañero» = el agente más cercano: sit_talk")
	t.check(await t.until(func() -> bool: return not tr.animator._talking, 8.0), "al terminar la línea deja de gesticular")
	await t.seconds(0.3)
	t.check(tr.animator.current_variant() in tr.animator._idles, "… y vuelve a sus idles (%s)" % tr.animator.current_variant())
	t.check(await t.until(func() -> bool: return str(ha.animator.tree.get("parameters/seated/sv/current_state")) == "sit", 8.0), "Haime vuelve a sit")
	# un grito: Shero señala
	var sh := _rig(b, "shero", 2.2)
	sh.play("idle")
	await t.seconds(0.7)
	say.call("shero", "Shero: ¡A TU SITIO! ¡AHORA!", 3.0)
	await t.seconds(0.4)
	t.check(sh.animator.current_variant() == "point", "Shero grita: señala (%s)" % sh.animator.current_variant())
	# un gesto pedido a mano manda sobre la reacción
	say.call("trainer", "[Trainer] ¡Silencio!", 3.0)
	await t.seconds(0.2)
	tr.play("slam_table", false)
	t.check(await _en(t, tr.animator, "act", "slam_table"), "play(\"slam_table\") manda aunque esté hablando")
	tr.play("idle")
	# Modo liviano: sin mandíbula
	var prev := GfxQuality.current
	GfxQuality.current = "liviano"
	await t.seconds(2.5)
	say.call("trainer", "[Trainer] Seguimos con el módulo dos, presten atención a la pantalla.", 4.0)
	await t.seconds(0.5)
	q0 = sk.get_bone_pose_rotation(jaw)
	moved = 0.0
	for i in 20:
		await t.get_tree().process_frame
		moved = maxf(moved, sk.get_bone_pose_rotation(jaw).angle_to(q0))
	t.check(tr.animator._talking and not tr.animator._jaw_dirty and tr.animator._jaw_open == 0.0, "Modo liviano: gesticula pero sin mandíbula por voz")
	GfxQuality.current = prev
	await _cleanup(t)
	# --- camino 2: VoiceDirector (v0.3.2): el fin exacto de la línea corta el gesto
	if real_vd == null:
		await _reset_hub(t)
		var fv := FakeVoice.new()
		fv.name = "VoiceDirector"
		t.get_tree().root.add_child(fv)
		var b2 := _bench(t, 3.0)
		var tr2 := _rig(b2, "trainer", 1.88)
		tr2.play("idle")
		await t.seconds(0.5)
		fv.line_started.emit("voces/trainer/bienvenida", "trainer", 2)
		fv.subtitle_shown.emit("trainer", "[Trainer] Bienvenidos a la capacitación de hoy, vamos a empezar por el saludo.", 6.0)
		await t.seconds(0.4)
		t.check(tr2.animator._talking, "con VoiceDirector: subtitle_shown lo hace hablar")
		EventBus.subtitle.emit("trainer", "[Trainer] otra", 3.0)
		fv.finished.emit("voces/trainer/bienvenida")
		t.check(await t.until(func() -> bool: return not tr2.animator._talking, 1.0), "finished(line_id) corta el gesto enseguida (y EventBus.subtitle ya no se escucha)")
		await _cleanup(t)
		fv.free()
		await _reset_hub(t)
	Engine.time_scale = ts


## Costura de los bucles: el salto del último fotograma al primero no es mayor que entre dos fotogramas vecinos.
func _bucles(t: Node) -> void:
	for m in ["agente_marko", "shero", "trainer", "haime", "perrito_rta", "vitzo"]:
		var lib := load(NpcAnimator.ANIM_DIR + m + ".res") as AnimationLibrary
		var bad: Array = []
		for cn in lib.get_animation_list():
			var a := lib.get_animation(cn)
			if a.loop_mode != Animation.LOOP_LINEAR or str(cn) in ["dance"]:
				continue
			var worst := 0.0
			var wb := ""
			for i in a.get_track_count():
				if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
					continue
				var bone := str(a.track_get_path(i).get_concatenated_subnames())
				if bone.begins_with("index") or bone.begins_with("middle") or bone.begins_with("ring") or bone.begins_with("pinky") or bone.begins_with("thumb") or (bone.begins_with("f") and bone.length() == 4) or bone.begins_with("ball") or bone.begins_with("eye"):
					continue
				var dt := a.length / maxf(1.0, float(a.track_get_key_count(i))) if a.track_get_key_count(i) > 2 else 1.0 / 30.0
				var q_end := a.rotation_track_interpolate(i, a.length - dt)
				var q_0 := a.rotation_track_interpolate(i, 0.0)
				var q_1 := a.rotation_track_interpolate(i, dt)
				var seam := q_end.angle_to(q_0)
				var step := maxf(q_0.angle_to(q_1), a.rotation_track_interpolate(i, a.length - 2.0 * dt).angle_to(q_end))
				if seam - 2.5 * step > worst:
					worst = seam - 2.5 * step
					wb = bone
			if worst > deg_to_rad(4.0):
				bad.append("%s %.0f° %s" % [cn, rad_to_deg(worst), wb])
		t.check(bad.is_empty(), "%s: los bucles empalman sin salto %s" % [m, str(bad)])


## Segundos de reloj de audio (sin escalar: el del VoiceDirector) que un animador pasa hablando mientras suena `line`.
## Devuelve [habló_s, duró_la_línea_s, apertura_máx_de_mandíbula_rad, siguió_hablando_después_s].
func _medir_linea(t: Node, vd: Node, line: Object, a: NpcAnimator, tope: float = 14.0) -> Array:
	var sk := a.skeleton
	var jaw := sk.find_bone("jaw")
	var talked := 0.0
	var dur := 0.0
	var jaw_max := 0.0
	var after := 0.0
	var t0 := int(vd.call("now_ms"))
	var last := t0
	while not bool(line.get("done")) and (int(vd.call("now_ms")) - t0) / 1000.0 < tope:
		await t.get_tree().process_frame
		var now := int(vd.call("now_ms"))
		var d := (now - last) / 1000.0
		last = now
		dur += d
		if a._talking:
			talked += d
		jaw_max = maxf(jaw_max, a._jaw_open)
	var t1 := int(vd.call("now_ms"))
	while a._talking and (int(vd.call("now_ms")) - t1) / 1000.0 < 3.0:
		await t.get_tree().process_frame
	after = (int(vd.call("now_ms")) - t1) / 1000.0
	return [talked, dur, jaw_max, after]


func _voz_real(t: Node) -> void:
	var vd := t.get_tree().root.get_node_or_null("VoiceDirector")
	if not t.check(vd != null and vd.has_method("say"), "el árbol trae el autoload VoiceDirector"):
		return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _reset_hub(t)
	vd.call("stop_all", "prueba")
	var b := _bench(t, 3.0)
	var tr := _rig(b, "trainer", 1.88)
	var ha := _rig(b, "haime", 1.78)
	(ha.get_parent() as Node3D).position = Vector3(1.4, 0, 0)
	var sh := _rig(b, "shero", 2.2)
	(sh.get_parent() as Node3D).position = Vector3(-1.6, 0, 0)
	var mk := _rig(b, "agente_marko", 1.7)
	(mk.get_parent() as Node3D).position = Vector3(2.6, 0, 0.5)
	var ll := _rig(b, "agente_llauri", 1.66)
	(ll.get_parent() as Node3D).position = Vector3(-2.8, 0, 0.5)
	tr.play("idle")
	ha.play("sit", true, 0.6, ["idle"])
	sh.play("idle")
	mk.play("type", true, 0.9, ["sit"])
	ll.play("type", true, 0.9, ["sit"])
	await t.seconds(0.8)
	t.check(NpcAnimator._hub != null and NpcAnimator._hub.vd == vd, "el hub de voz escucha al VoiceDirector real")

	# 1) el Trainer dice su bienvenida (5,8 s de audio) como en el juego: voz sin texto + subtítulo en el mismo cuadro
	PersonajesP5.say("Trainer", "trainer", "bienvenida", "Bienvenidos a la capacitación. Tomen asiento, por favor.")
	await t.frames(2)
	var line: Object = vd.get("current")
	if t.check(line != null and bool(line.get("has_audio")) and str(line.get("speaker")) == "trainer", "la línea del Trainer suena por el director con su audio"):
		var m: Array = await _medir_linea(t, vd, line, tr.animator)
		t.note("Trainer: habló %.2f s de %.2f s que duró la línea · mandíbula máx %.1f° · siguió %.2f s" % [m[0], m[1], m[2], m[3]])
		t.check(float(m[1]) > 4.5, "la línea dura lo que su audio (%.2f s, el ogg mide 5,8)" % m[1])
		t.check(float(m[0]) > float(m[1]) - 0.5, "gesticula TODO lo que dura el audio (%.2f de %.2f s; antes se cortaba por la estimación del texto)" % [m[0], m[1]])
		t.check(float(m[3]) < 0.45, "y deja de gesticular al terminar la línea (%.2f s después)" % m[3])
		t.check(float(m[2]) > 1.5, "mueve la mandíbula con la voz (máx %.1f°)" % m[2])
		t.check(not ha.animator._talking and not sh.animator._talking and not mk.animator._talking, "los demás no se mueven con la línea del Trainer")
	await t.seconds(0.5)
	t.check(tr.animator.current_variant() in tr.animator._idles, "el Trainer vuelve a sus idles (%s)" % tr.animator.current_variant())

	# 2) Haime sentado; le cortan la línea (la calibración usa cancel): calla en el acto
	line = vd.call("say", "voces/haime/a_mitad", 2, "haime", Callable(), {"text": "[Haime] Vamos a escuchar tu llamada desde el inicio.", "seconds": 4.0, "bus": "Sala"})
	await t.seconds(0.5)
	t.check(ha.animator._talking and _var(ha.animator) == "sit_talk", "Haime sentado habla: sit_talk (%s)" % _var(ha.animator))
	t.check(not tr.animator._talking, "el Trainer no se mueve con la línea de Haime")
	vd.call("cancel", line, "prueba")
	t.check(await t.until(func() -> bool: return not ha.animator._talking, 0.5), "le cortan la línea (cancel): deja de gesticular en menos de 0,5 s")
	t.check(await t.until(func() -> bool: return _var(ha.animator) != "sit_talk", 2.0), "… y vuelve a su postura (%s)" % _var(ha.animator))
	await t.seconds(0.3)

	# 3) el Trainer amable del Training: carpeta trainer_amable + gesture() (play("point", false)) en cada línea
	var slot := "voces/trainer_amable/t_aux"
	line = vd.call("say", slot, 2, "trainer_amable", Callable(), {"text": "[Trainer] El estado AUX le dice al sistema qué estás haciendo.", "bus": "Sala", "seconds": 5.0})
	tr.play("point", false, 0.9, ["idle"])
	t.check(await _en(t, tr.animator, "act", "point", 1.0), "Training: el Trainer señala al empezar la línea (act/point)")
	var back: bool = await t.until(func() -> bool: return tr.animator.current_state() == "loco" and tr.animator.state == "loco", 3.2)
	t.check(back, "… un ciclo (~2 s) y vuelve solo, no se queda señalando (%s)" % tr.animator.current_state())
	if bool(line.get("has_audio")) and not bool(line.get("done")):
		await t.seconds(0.5)
		t.check(tr.animator._talking and tr.animator._talk_mode == "stand" and tr.animator.current_variant() in ["present_a", "present_b", "talk", "open_hands", "point"], "… y sigue con gestos de hablar mientras dura la voz (%s)" % tr.animator.current_variant())
	else:
		t.note("la línea t_aux duró menos que el gesto: no se comprueba el gesto de después")
	tr.play("point", false, 0.9, ["idle"])
	t.check(await _en(t, tr.animator, "act", "point", 1.0), "pedir el gesto otra vez (línea siguiente) lo repite")
	vd.call("stop_all", "prueba")
	tr.play("idle")
	await t.seconds(0.6)

	# 4) por los parlantes y por el auricular no gesticula nadie (no lo dice en persona)
	AudioManager.play_voice("trainer", "anuncio", "", "Parlantes")
	EventBus.subtitle.emit("parlantes", "Parlantes: se les recuerda que el break es de quince minutos.", 5.0)
	await t.seconds(0.6)
	line = vd.get("current")
	t.check(line != null and str(line.get("bus")) == "Parlantes", "la línea va por el bus Parlantes")
	t.check(not tr.animator._talking, "voz del Trainer por los parlantes: el Trainer presente NO gesticula")
	vd.call("stop_all", "prueba")
	PersonajesP5.say("REC", "haime", "rec", "Gracias por comunicarse con nosotros.", "Auricular")
	await t.seconds(0.5)
	t.check(not ha.animator._talking, "grabación de Haime por el auricular: Haime NO gesticula")
	vd.call("stop_all", "prueba")
	await t.seconds(0.3)

	# 5) Shero en persona: la voz sale de un reproductor 3D colgado de él (SheroPresence._voice_3d)
	var st := AudioManager.stream_for("voces/shero/coach_1")
	if t.check(st != null, "existe voces/shero/coach_1"):
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = st
		p3.bus = "Sala"
		(sh.get_parent() as Node3D).add_child(p3)
		line = vd.call("say_external", p3, "voces/shero/coach_1", 2, "shero", {"free_on_drop": true})
		EventBus.subtitle.emit("shero", "[Shero] ¡A TU SITIO! ¡AHORA!", 3.0)
		await t.seconds(0.6)
		t.check(sh.animator._talking and sh.animator.current_variant() == "point", "Shero en persona grita: señala (%s)" % sh.animator.current_variant())
		var m2: Array = await _medir_linea(t, vd, line, sh.animator)
		t.check(float(m2[3]) < 0.45, "y calla cuando termina su audio (%.2f s después)" % m2[3])

	# 6) el murmullo de un compañero (reproductor 3D colgado de SU rig, hablante genérico «agentes») mueve a ese compañero
	st = AudioManager.stream_for("voces/agentes/dm_marko_jiroshi_1")
	if t.check(st != null, "existe voces/agentes/dm_marko_jiroshi_1"):
		var p4 := AudioStreamPlayer3D.new()
		p4.stream = st
		p4.bus = "Sala"
		ll.add_child(p4)
		line = vd.call("say_external", p4, "voces/agentes/dm_marko_jiroshi_1", 0, "agentes", {"max_wait": 0.0, "free_on_drop": true})
		await t.seconds(0.5)
		t.check(ll.animator._talking and _var(ll.animator) == "sit_talk", "murmullo colgado de Llauri: habla Llauri (%s)" % _var(ll.animator))
		t.check(not mk.animator._talking, "… y no Marko, aunque esté igual de cerca")
		vd.call("stop_all", "prueba")
		t.check(await t.until(func() -> bool: return not ll.animator._talking, 0.5), "se corta el murmullo: Llauri calla")
	# «[Marko] …» por la carpeta genérica comp: lo dice Marko
	AudioManager.play_voice("comp", "comp_viene_shero", "[Marko] Oe, viene Shero.", "Sala")
	await t.seconds(0.5)
	t.check(mk.animator._talking and not ll.animator._talking, "«[Marko] …» (carpeta comp): habla Marko y no Llauri")
	vd.call("stop_all", "prueba")
	# Don Fermín por la carpeta «otros»: la clave sale del archivo de voz
	var fe := _rig(b, "guardia_fermin", 1.74)
	(fe.get_parent() as Node3D).position = Vector3(0, 0, 1.6)
	fe.play("idle")
	await t.seconds(0.8)
	AudioManager.play_voice("otros", "fermin_buenas_noches", "Buenas noches, joven.", "Sala")
	await t.seconds(0.5)
	t.check(fe.animator._talking, "voces/otros/fermin_…: habla Don Fermín")
	t.check(not mk.animator._talking and not tr.animator._talking, "… y nadie más")
	vd.call("stop_all", "prueba")

	# 7) Modo liviano: gesto sí, mandíbula no (costo cero por voz)
	var prev := GfxQuality.current
	GfxQuality.current = "liviano"
	await t.seconds(1.0)
	line = vd.call("say", "voces/trainer/bienvenida", 2, "trainer", Callable(), {"text": "[Trainer] Bienvenidos.", "bus": "Sala"})
	await t.seconds(1.2)
	t.check(tr.animator._talking and tr.animator._jaw_open == 0.0 and not tr.animator._jaw_dirty, "Modo liviano: gesticula sin mandíbula por voz")
	vd.call("stop_all", "prueba")
	GfxQuality.current = prev
	await t.seconds(0.3)
	await _cleanup(t)
	await _reset_hub(t)
	Engine.time_scale = ts

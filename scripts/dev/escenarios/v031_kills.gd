## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios de las muertes propias (v0.3.1, fx/kill_moves.gd; docs/ANIMACIONES_MUERTE.md). `--escenario v031_kills`
## corre todos; ids con prefijo k_.
##   k_datos            cada fila de screamers.json tiene su muerte propia (distinta en cada fila), del asesino de la
##                      fila, con intro y final existentes y 3-4 s; toda muerte de KillMoves.SPEC se usa
##   k_<causa>          UNA muerte como en el juego (sentado, de pie, dormido, en la sala de training o de
##                      calibración; Vitzo sale del monitor): corre su animación (id), todos sus tiempos en orden
##                      (agarre … grito … final), su utilería, el agarre, la cara deformada, la frase gritada, la
##                      duración de la fila (±0,25 s) y la pantalla «Usuario desconectado» después
##   k_correo_vitzo_pie te paras cuando Vitzo sale del monitor: te persigue, te alcanza y corre vitzo_salto
##   k_liviano          en Modo liviano los restos (tickets) son un tercio y la muerte dura lo mismo
##   k_colapso          la Fatiga sigue sin screamer ni muerte propia

const REPORT := "user://logs/kills.log"
## Causa → [asesino, dónde estás]. "silla" = C-14; "pie" = de pie en la sala; "dormido" = en el sofá del sótano.
const CASES: Dictionary = {
	"break_excedido": ["shero", "pie"], "tercer_break": ["shero", "pie"], "lunch_excedido": ["shero", "comedor"],
	"lunch_dormido": ["shero", "dormido"], "aht_bo": ["shero", "silla"], "reflejo_kyc": ["shero", "silla"],
	"abandono": ["shero", "pie"], "regreso_tardio": ["shero", "pie"], "coaching": ["shero", "silla"],
	"llamadas_perdidas": ["shero", "silla"], "otra_isla": ["shero", "pie"], "available_bajo": ["shero", "silla"],
	"work_avoiding": ["shero", "pie"], "ww_sin_ack": ["shero", "silla"], "tercer_ww": ["shero", "silla"],
	"tres_molestos": ["shero", "silla"], "coaching_rasec": ["rasec", "silla"], "coaching_sin_permiso": ["rasec", "silla"],
	"coaching_exceso": ["rasec", "silla"], "rasec_evento": ["rasec", "pie"], "qa_inasistencia": ["haime", "pie"],
	"calibracion_final": ["haime", "calibracion"], "training_reprobado": ["trainer", "training"],
	"training_inasistencia": ["trainer", "pie"], "aux_incorrecto": ["rta", "pie"], "correo_vitzo": ["vitzo", "silla"],
	"vitzo_reminder": ["vitzo", "silla"], "wmm_correo_vitzo": ["vitzo", "silla"], "wmm_pod_correo": ["vitzo", "silla"],
}


func escenarios() -> Array[String]:
	var out: Array[String] = ["k_datos", "k_correo_vitzo_pie", "k_liviano", "k_colapso", "k_muerte:"]
	for c in CASES.keys():
		out.append("k_" + str(c))
	return out


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"k_datos": _datos(t)
		"k_correo_vitzo_pie": await _vitzo_pie(t)
		"k_liviano": await _liviano(t)
		"k_colapso": await _colapso(t)
		"k_muerte": await one(t, arg)
		_:
			if id.begins_with("k_") and CASES.has(id.substr(2)):
				await one(t, id.substr(2))


func _report(line: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open(REPORT, FileAccess.READ_WRITE) if FileAccess.file_exists(REPORT) else FileAccess.open(REPORT, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	f.close()


## Causa real y asesino de un caso (coaching_rasec = "coaching" pedido por Rasec; lunch_dormido = lunch excedido
## dormido en el sofá).
static func real_of(case_id: String) -> Array:
	match case_id:
		"coaching_rasec":
			return ["coaching", "rasec"]
		"lunch_dormido":
			return ["lunch_excedido", "shero"]
	return [case_id, str((CASES.get(case_id, ["shero"]) as Array)[0])]


static func row_key(case_id: String) -> String:
	return "coaching@rasec" if case_id == "coaching_rasec" else case_id


# --- datos -------------------------------------------------------------------------------------------------

func _datos(t: Node) -> void:
	var rows: Dictionary = DataLoader.dict("screamers").get("causas", {})
	var fx := Screamers.new()
	var seen: Dictionary = {}
	for key in rows.keys():
		var r: Dictionary = rows[key]
		var kill := str(r.get("kill", ""))
		t.check(KillMoves.has(kill), "%s: muerte propia «%s» existe" % [key, kill])
		t.check(not seen.has(kill), "%s: «%s» no la usa otra fila (%s)" % [key, kill, str(seen.get(kill, "-"))])
		seen[kill] = key
		var spec: Dictionary = KillMoves.SPEC.get(kill, {})
		t.check(str(spec.get("asesino", "")) == str(r.get("asesino", "")), "%s: «%s» es de %s" % [key, kill, str(r.get("asesino", ""))])
		t.check(fx.has_method("_i_" + str(r.get("intro", ""))), "%s: intro %s" % [key, str(r.get("intro", ""))])
		t.check(fx.has_method("_f_" + str(r.get("final", "embestida"))), "%s: final %s" % [key, str(r.get("final", "embestida"))])
		var d := Screamers.seconds_for(r)  # v0.3.2c: la fila + lo que pida el archivo de la frase
		var cap := Screamers.LONG_CAP if bool(r.get("escena", false)) else Screamers.TOTAL_CAP
		t.check(d >= 3.0 and d <= cap, "%s: %.1f s (3 s … %.1f s; v0.3.2: la frase termina)" % [key, d, cap])
		var last_beat := "fundido" if bool(r.get("escena", false)) else "final"  # la fusión (dos escenas) termina en fundido
		t.check((spec.get("beats", []) as Array).has("grito") and (spec.get("beats", []) as Array).has(last_beat), "%s: grita y tiene %s" % [key, last_beat])
		var ka := str(r.get("kill_alcance", ""))
		if ka != "":
			t.check(KillMoves.has(ka) and str((KillMoves.SPEC[ka] as Dictionary).get("asesino", "")) == str(r.get("asesino", "")), "%s: alcance «%s»" % [key, ka])
			seen[ka] = key
	for k in KillMoves.SPEC.keys():
		t.check(seen.has(k), "«%s» la usa alguna fila" % k)
	t.check(rows.size() == 29 and seen.size() == 30, "29 filas, 30 muertes propias (con Vitzo de pie): %d / %d" % [rows.size(), seen.size()])
	# Los humanos ya no comparten las manos: cada muerte con asesino humano pone las manos en otro sitio (lo verifica
	# el escenario de cada causa con last_info.manos).
	fx.free()


# --- una muerte --------------------------------------------------------------------------------------------

func _setup(t: Node, case_id: String) -> void:
	var where := str((CASES.get(case_id, ["shero", "silla"]) as Array)[1])
	var turno := 1 if where == "training" else 2
	await t.start_shift("Jiroshi", turno)
	var b: Building = t.building()
	var p: Player = t.player()
	match where:
		"silla":
			await t.login_at_seat()
		"pie":
			await t.login_at_seat()
			p.stand_up()
			await t.frames(2)
			p.teleport(p.global_position + Vector3(0, 0, 1.2), 180.0)
			await t.frames(2)
		"comedor":
			if not GameState.logged_in:
				GameState.login()
			b.go_to_floor(-1, "ascensor")
			await t.frames(3)
			p.teleport(Vector3(8.0, 0, 6.0), 0.0)
			await t.frames(2)
		"dormido":
			await t.login_at_seat()
			b.go_to_floor(-1, "ascensor")
			await t.frames(3)
			if p.seated:
				p.stand_up()
			for s in t.get_tree().get_nodes_in_group("sleep_spots"):
				(s as SleepSpot).interact(p)
				break
			await t.seconds(0.4)
		"calibracion", "training":
			var fl_n := 2 if where == "calibracion" else 1
			b.go_to_floor(fl_n, "pc")
			await t.frames(3)
			var sid := "calibracion" if where == "calibracion" else "training_sala2_1"
			var seat := (b.floor_node as FloorBase).seat_by_id(sid)
			if seat != null:
				p.sit_at(seat, sid)
			if not GameState.logged_in:
				GameState.login()
			await t.frames(2)
	GameState.stop_calm()


## Una muerte entera, medida desde dentro (Screamers.last_info).
func one(t: Node, case_id: String) -> void:
	if not CASES.has(case_id):
		t.fail("caso desconocido %s" % case_id)
		return
	await _setup(t, case_id)
	var rc: Array = real_of(case_id)
	var cause := str(rc[0])
	var killer := str(rc[1])
	var key := row_key(case_id) if case_id != "lunch_dormido" else "lunch_dormido"
	var row: Dictionary = (DataLoader.dict("screamers").get("causas", {}) as Dictionary).get(key, {})
	var expected_kill := str(row.get("kill", ""))
	var expected_s := Screamers.seconds_for(row)
	var spec: Dictionary = KillMoves.SPEC.get(expected_kill, {})
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)
	Screamers.last_info = {}
	var shown: Array = t.spy("death_shown")
	var finished: Array = t.spy("screamer_finished")
	var ms_trig := -1
	var f_trig := -1
	# Voces encimadas (con el VoiceDirector de la integración; sin él, no se mide): ningún solape registrado durante la
	# muerte y ninguna voz del juego (NPC, cliente, AudioManager) sonando bajo la frase del asesino.
	var vd: Node = t.get_tree().root.get_node_or_null("VoiceDirector")
	var ov0 := int(vd.get("overlaps")) if vd != null else 0
	var under := 0
	if killer == "vitzo":
		VitzoScreamer.attack(cause)  # sale del monitor (fase 1) y te agarra sentado
	else:
		ms_trig = Time.get_ticks_msec()
		f_trig = Engine.get_process_frames()
		t.die(cause, _detail(cause), killer)
	var el := 0.0
	var max_def := 0.0
	var hands_seen: Array = []
	while el < 34.0 and shown.is_empty():  # la fusión de Vitzo dura ~22 s (más su salida del monitor)
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		if ms_trig < 0 and Checkpoints.dying:
			ms_trig = Time.get_ticks_msec()
		max_def = maxf(max_def, float(Screamers.last_info.get("deform_max", 0.0)))
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP) as Screamers
		if vd != null and fx != null and int(vd.call("voices_playing")) > 0:
			under += 1
		if fx != null and fx.kill_id != "":
			for h in [fx.hand_l, fx.hand_r]:
				if h != Vector3.INF and not hands_seen.has(h):
					hands_seen.append(h)
	var info: Dictionary = Screamers.last_info
	t.check(str(info.get("cause", "")) == cause and str(info.get("killer", "")) == killer, "%s: muere por %s (%s) — fue %s (%s)" % [case_id, cause, killer, str(info.get("cause", "")), str(info.get("killer", ""))])
	t.check(str(info.get("kill", "")) == expected_kill, "%s: animación «%s» (corrió «%s»)" % [case_id, expected_kill, str(info.get("kill", ""))])
	var beats: Array = info.get("beats", [])
	var want: Array = spec.get("beats", [])
	t.check(beats == want, "%s: tiempos %s (esperados %s)" % [case_id, str(beats), str(want)])
	var props: Array = info.get("props", [])
	var missing: Array = []
	for pr in spec.get("props", []):
		if not props.has(pr):
			missing.append(pr)
	t.check(missing.is_empty(), "%s: utilería %s (falta %s)" % [case_id, str(props), str(missing)])
	if str(row.get("agarre", "dos_brazos")) != "ninguno":
		t.check(float(info.get("grab", 0.0)) > 0.9, "%s: te agarra (%.2f)" % [case_id, float(info.get("grab", 0.0))])
	# Ya no es el agarre genérico de la beta (las dos manos a 21 cm a los lados de la cámara): alguna mano va a otro sitio.
	var own_spot := 0
	for h in hands_seen:
		if (h as Vector3).distance_to(Vector3(-0.21, -0.02, -0.1)) > 0.06 and (h as Vector3).distance_to(Vector3(0.21, -0.02, -0.1)) > 0.06:
			own_spot += 1
	# v0.3.2: Vitzo vuelve al agarre Q2 (Joan prefiere ese): las manos a los lados de tu cabeza; su muerte propia es
	# el contexto (vidrios, salto, correo, divisor, la fusión).
	if killer != "vitzo":
		t.check(own_spot >= 1, "%s: manos propias de la muerte (%d sitios distintos del agarre genérico, %d en total)" % [case_id, own_spot, hands_seen.size()])
	else:
		t.check(hands_seen.size() >= 2, "%s: agarre Q2 (las dos manos a los lados de tu cabeza)" % case_id)
	t.check(max_def >= 0.9, "%s: la cara se deforma hasta %.2f" % [case_id, max_def])
	t.check(str(info.get("frase_path", "")) != "", "%s: grita la frase (%s)" % [case_id, str(info.get("frase_path", "")).get_file()])
	var own := float(info.get("duracion_real", -1.0))
	if expected_kill == "vitzo_fusion" or float(row.get("accion_s", 0.0)) > 0.0:
		expected_s = float(info.get("duracion", expected_s))  # kills2: la fusión dura lo que su agente necesita (la fila es el tope)
	var late := float(info.get("grito_tarde", 0.0))  # v0.3.2: si el grito llegó tarde, el final se corre (la frase no se corta)
	t.check(absf(own - late - expected_s) <= 0.25, "%s: dura %.2f s (fila %.2f, +%.2f del grito tarde)" % [case_id, own, expected_s, late])
	t.check(float(info.get("grito_s", -1.0)) > 0.0 and float(info.get("grito_s", 99.0)) < expected_s, "%s: el grito a %.2f s" % [case_id, float(info.get("grito_s", -1.0))])
	t.check(not finished.is_empty() and not shown.is_empty() and t.death_screen().visible, "%s: «Usuario desconectado» después" % case_id)
	_report("%s · %s (%s) · %s · intro %s · %.2f s · tiempos %s · utilería %s" % [case_id, cause, killer, str(info.get("kill", "")), str(info.get("intro", "")), own, str(beats), str(props)])
	golpe_check(t, case_id, info, row, ms_trig, f_trig)
	if vd != null:
		t.check(int(vd.get("overlaps")) - ov0 == 0 and under == 0, "%s: 0 voces encimadas (solapes %d · cuadros con otra voz bajo el screamer %d)" % [case_id, int(vd.get("overlaps")) - ov0, under])
		print("[voces] %s · solapes %d · cuadros con otra voz %d" % [case_id, int(vd.get("overlaps")) - ov0, under])
	Engine.time_scale = scale0
	await t.reconnect()
	await t.until(func() -> bool: return Checkpoints.can_die(), 6.0)


## kills2 (Joan: «sustos de golpe»): del disparo de la muerte (Checkpoints.request_death / el alcance) al primer cuadro
## de la animación de la muerte y al primer golpe fuerte. El screamer arranca en el mismo cuadro del disparo; el asesino
## ya se te viene encima desde ese cuadro (anim_s = 0); el agarre y el golpe caen a 0,10 s (Vitzo: salto a 0,25 s y
## agarre a 0,36 s, como le gustó a Joan; el salto de la mesa de Haime: golpe en la mesa a ~0,13 s, encima a 0,50 s).
## Nada suena antes del golpe (la crecida del archivo ya no se toca) y ninguna intro «de aviso» corre.
static func golpe_check(t: Node, case_id: String, info: Dictionary, row: Dictionary, ms_trig: int, f_trig: int = -1) -> void:
	var fn := str(info.get("intro_fn", ""))
	var lag := (int(info.get("t0", 0)) - ms_trig) / 1000.0 if ms_trig >= 0 else 0.0
	var grab := float(info.get("agarre_s", 9.0))
	var hit := float(info.get("golpe_s", 9.0))
	var plan := float(info.get("golpe_previsto_s", hit))
	# Topes: el valor de la fila + 2 cuadros (la prueba corre a 2x: un cuadro son ~17 ms de juego).
	var lim := 0.11
	var lim_hit := 0.15
	if fn == "zarpazo":
		lim = 0.37
		lim_hit = 0.33
	elif fn in ["salto_mesa", "mesa"] and str(info.get("killer", "")) == "haime":
		lim = 0.51
		lim_hit = 0.2
	var before: Dictionary = row.get("antes_golpe", {})
	t.check(fn == "golpe" or fn in Screamers.INTROS_ESCENA, "%s: sin intro de aviso (entra con «%s»)" % [case_id, fn])
	# En el MISMO cuadro del disparo (los cuadros no dependen de la carga de la máquina; los ms sí: van solo al informe).
	if f_trig >= 0:
		var df := int(info.get("f0", -99)) - f_trig
		t.check(df == 0, "%s: el screamer arranca en el mismo cuadro del disparo (%d cuadros después; %.3f s de reloj)" % [case_id, df, lag])
	t.check(grab <= lim, "%s: del disparo al agarre %.2f s (antes %.2f s; tope %.2f)" % [case_id, grab, float(before.get("agarre_s", -1.0)), lim])
	# El golpe está puesto a ≤ tope del reloj del screamer y sonó en el cuadro que le tocaba (holgura: cuadros largos).
	t.check(plan <= lim_hit - 0.02 and hit - plan <= 0.3, "%s: primer golpe fuerte puesto a %.2f s del disparo (tope %.2f) y sonó a %.2f s" % [case_id, plan, lim_hit - 0.02, hit])
	# Gancho c32/chase_close: sin la biblioteca de persecución del asesino no hace nada (sigue con sprint/run).
	var slug := str(info.get("killer", ""))
	if not ResourceLoader.exists("res://assets/anim/%s_chase.res" % slug):
		t.check(not info.has("pose_alcance"), "%s: sin %s_chase.res el gancho c32/chase_close no cambia la pose" % [case_id, slug])
	var line := "susto de golpe · %s · disparo→screamer %.3f s · agarre %.2f s (antes %.2f) · primer golpe %.2f s · entra «%s» · dura %.2f s (antes %.2f)" % [case_id, lag, grab, float(before.get("agarre_s", -1.0)), hit, fn, float(info.get("duracion", 0.0)), float(before.get("duracion", -1.0))]
	print("[golpe] " + line)


static func _detail(cause: String) -> String:
	match cause:
		"available_bajo":
			return "61"
		"break_excedido":
			return "16:00"
		"lunch_excedido":
			return "52:00"
		"coaching_exceso":
			return "11:00"
		"training_reprobado":
			return "2/5"
		"aux_incorrecto":
			return "Baño 02:31"
	return ""


# --- Vitzo de pie ------------------------------------------------------------------------------------------

func _vitzo_pie(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	Screamers.last_info = {}
	var seq: Array = t.spy("death_sequence_started")
	var shown: Array = t.spy("death_shown")
	VitzoScreamer.attack("correo_vitzo")
	await t.seconds(0.6)
	var p: Player = t.player()
	p.stand_up()
	p.teleport(p.global_position + Vector3(0, 0, 3.0), 180.0)
	var ok: bool = await t.until(func() -> bool: return Pursuit.is_hunting("vitzo"), 6.0)
	t.check(ok, "te paraste: Vitzo te persigue")
	var caught: bool = await t.until(func() -> bool: return not seq.is_empty(), 30.0)
	t.check(caught, "te alcanza")
	await t.until(func() -> bool: return str(Screamers.last_info.get("kill", "")) != "", 3.0)
	t.check(str(Screamers.last_info.get("kill", "")) == "vitzo_salto", "salta y te inmoviliza en el piso (%s)" % str(Screamers.last_info.get("kill", "")))
	await t.until(func() -> bool: return not shown.is_empty(), 8.0)
	var beats: Array = Screamers.last_info.get("beats", [])
	t.check(beats == (KillMoves.SPEC["vitzo_salto"] as Dictionary)["beats"], "tiempos %s" % str(beats))
	t.check(not shown.is_empty(), "«Usuario desconectado» después")
	await t.reconnect()


# --- Modo liviano -------------------------------------------------------------------------------------------

func _liviano(t: Node) -> void:
	# Solo el nivel (lo que leen KillProps.count/light_mode): aplicar el Modo liviano entero cambia luces y escala y
	# q5_liviano (que corre después) compara contra ese estado.
	var lv0 := GfxQuality.current
	GfxQuality.current = "liviano"
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	Screamers.last_info = {}
	var shown: Array = t.spy("death_shown")
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)  # a 8x+ el screamer se acorta a 3 s (bots)
	t.die("tres_molestos", "", "shero")
	var max_pieces := 0
	for _i in 600:
		await t.get_tree().process_frame
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP) as Screamers
		if fx != null and fx._stage != null and is_instance_valid(fx._stage):
			var n := 0
			for d in fx._stage.find_children("*", "Node3D", true, false):
				if d is KillProps.Debris:
					n += (d as KillProps.Debris).parts.size()
			max_pieces = maxi(max_pieces, n)
		if not shown.is_empty():
			break
	t.check(max_pieces > 0 and max_pieces <= 16, "Modo liviano: %d tickets en el aire (Alta: 48)" % max_pieces)
	var want := Screamers.duration("shero", "tres_molestos")
	# Como en cada muerte (_kill): si el grito llegó tarde (un fotograma largo), el final se corre lo mismo (hasta 0,25 s).
	var real_s := float(Screamers.last_info.get("duracion_real", 0.0))
	var late_s := float(Screamers.last_info.get("grito_tarde", 0.0))
	t.check(absf(real_s - late_s - want) <= 0.25, "dura lo mismo (%.2f s, fila %.1f, +%.2f del grito tarde)" % [real_s, want, late_s])
	Engine.time_scale = scale0
	await t.reconnect()
	GfxQuality.current = lv0


# --- colapso -------------------------------------------------------------------------------------------------

func _colapso(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var scr: Array = t.spy("screamer_finished")
	var shown: Array = t.spy("death_shown")
	Screamers.last_info = {}
	Fatigue.set_value(99.0)
	Fatigue.add(10.0)
	await t.until(func() -> bool: return not shown.is_empty(), 12.0)
	t.check(scr.is_empty() and t.get_tree().get_nodes_in_group(Screamers.GROUP).is_empty(), "colapso sin screamer")
	t.check(str(Screamers.last_info.get("kill", "")) == "", "colapso sin muerte propia")
	t.check(not shown.is_empty(), "«Usuario desconectado» después del colapso")
	await t.reconnect()

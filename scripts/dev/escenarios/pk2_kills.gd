## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios del paquete de muertes v0.3.2 (docs/ANIMACIONES_MUERTE.md; fx/kill_moves.gd, fx/kill_gore.gd,
## fx/vitzo_fusion.gd). `--escenario pk2` corre todos; ids con prefijo k2_.
##   k2_frase_cabe        TODA fila: la frase gritada más larga (3 tomas ES + 3 EN, por frase_rep) + 0,3 s cabe
##                        desde el agarre; la fila no pasa su tope; Checkpoints espera lo suficiente
##   k2_<causa>           cada muerte que cambió Joan: corre como en el juego (v031_kills.one: animación, tiempos,
##                        utilería, duración, pantalla de muerte) y además la frase termina antes del corte, hay
##                        sangre/heridas con Contenido gráfico Normal y la capa de impacto suena
##   k2_fusion_<agente>   la fusión de Vitzo (vitzo_reminder) con los 5 agentes: las dos escenas, la resistencia por
##                        etapas (clips k32), el grito con su voz, la antena, el agente fusionado en la sala con su voz
##                        rota, ~22 s, la cámara vuelve, la pantalla de muerte
##   k2_fusion_salto      la primera vez no se salta; ya vista, se salta desde los 3 s
##   k2_grafico           Opciones «Contenido gráfico» Normal/Reducido (por defecto Normal); Reducido: sin sangre
##                        ni crujidos, el susto queda (misma muerte, misma duración, grito, cara deforme)
##   k2_buses             bus ScreamerSFX: agache en cadena lateral desde ScreamerVoz y limitador a -1 dBFS
##   k2_vitzo_tamano      Vitzo sale del monitor de 1 m y crece a 1,8 m; la persecución usa 1,8 m; estilo Q2
##   k2_colapso_3p        la Fatiga sigue sin screamer; tercera persona actuada de cuerpo entero (sentado y de pie)
##   k2_menu_en_muerte    salir al menú en mitad de cualquier muerte (colapso sentado/de pie, fusión, propias, genérica)
##                        corta sus corrutinas y tweens sin dejar nada en escena, en pantalla ni en los buses
##   k2_prewarm_estres    la precarga (Screamers.prewarm / KillGore.prewarm) 20 veces en el almuerzo y 20 con un
##                        contacto activo (y una vez desde un hilo de trabajo): en el hilo solo corre ResourceLoader,
##                        cada ruta se pide una vez, el hilo principal recoge todo, sin nodos de más

const K1 := "res://scripts/dev/escenarios/v031_kills.gd"
const REPORT := "user://logs/kills_v032.log"
const AGENTS: Array[String] = ["Jiroshi", "Marko", "Llauri", "Ttoom", "Juan"]
## Las que Joan cambió en el documento (y las de Vitzo, que vuelven al estilo Q2) → lo nuevo que debe verse.
const CHANGED: Dictionary = {
	"lunch_excedido": ["golpe_3", "come"], "lunch_dormido": ["levanta", "forcejeo", "sofoca"], "aht_bo": [], "reflejo_kyc": [],
	"abandono": ["cuello"], "llamadas_perdidas": ["amarra"], "available_bajo": ["mandibula"], "work_avoiding": ["pulgares"],
	"ww_sin_ack": ["rostro"], "tercer_ww": ["caes"], "tres_molestos": ["ahogo"], "coaching_sin_permiso": ["cuello"],
	"coaching_exceso": ["brazo", "desangra"], "rasec_evento": ["resiste"], "qa_inasistencia": [], "calibracion_final": ["piel"],
	"training_reprobado": [], "training_inasistencia": ["oreja"], "aux_incorrecto": ["shock"], "correo_vitzo": [],
	"wmm_correo_vitzo": [], "wmm_pod_correo": [],
}
## Frase que debe gritar (Joan: «¿acaso no sabes trabajar?», «PONTE LA CAMISETA», «EMPATÍA» dos veces).
## Joan (11/11): las muertes de Shero por breaks gritan «¡NO HAY BREAKS!»; lunch excedido «¡45 MINUTOS! ¡NI UN SEGUNDO MÁS!».
## kills2 (Joan, 12/11): correo excedido grita «¡TE PASASTE 10 MINUTOS DE CORREOO!»; «¿acaso…?» pasa a work_avoiding (y sigue en reflejo_kyc).
const FRASE: Dictionary = {"aht_bo": "scr_grito_correo10", "work_avoiding": "scr_grito_acaso", "reflejo_kyc": "scr_grito_acaso", "lunch_dormido": "scr_grito_camiseta",
	"break_excedido": "scr_grito_no_hay_breaks", "tercer_break": "scr_grito_tercer_break", "lunch_excedido": "scr_grito_45_minutos"}


func escenarios() -> Array[String]:
	var out: Array[String] = ["k2_frase_cabe", "k2_fusion_salto", "k2_grafico", "k2_buses", "k2_vitzo_tamano", "k2_colapso_3p", "k2_menu_en_muerte", "k2_vitzo_sin_espera", "k2_prewarm_estres", "k2_muerte:"]
	for c in CHANGED.keys():
		out.append("k2_" + str(c))
	for a in AGENTS:
		out.append("k2_fusion_" + a.to_lower())
	return out


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"k2_frase_cabe": _frase_cabe(t)
		"k2_fusion_salto": await _fusion_salto(t)
		"k2_grafico": await _grafico(t)
		"k2_buses": await _buses(t)
		"k2_vitzo_tamano": await _vitzo_tamano(t)
		"k2_colapso_3p": await _colapso(t)
		"k2_menu_en_muerte": await _menu_en_muerte(t)
		"k2_vitzo_sin_espera": await _vitzo_sin_espera(t)
		"k2_prewarm_estres": await _prewarm_estres(t)
		"k2_muerte": await one(t, arg)
		_:
			if id.begins_with("k2_fusion_"):
				await _fusion(t, id.substr(10).capitalize())
			elif id.begins_with("k2_") and CHANGED.has(id.substr(3)):
				await one(t, id.substr(3))


func _report(line: String) -> void:
	print("[pk2] " + line)
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open(REPORT, FileAccess.READ_WRITE) if FileAccess.file_exists(REPORT) else FileAccess.open(REPORT, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	f.close()


# --- la frase cabe ---------------------------------------------------------------------------------------------

static func _takes(slot: String) -> Array[String]:
	var out: Array[String] = []
	var parts := slot.split("/")
	for i in range(1, 4):
		var es := AudioManager.resolve("%s_%02d" % [slot, i], false)
		if es != "":
			out.append(es)
		if parts.size() == 3:
			var en := AudioManager.resolve("%s/%s/en/%s_%02d" % [parts[0], parts[1], parts[2], i], false)
			if en != "":
				out.append(en)
	return out


func _frase_cabe(t: Node) -> void:
	var rows: Dictionary = DataLoader.dict("screamers").get("causas", {})
	var max_d := 0.0
	for key in rows.keys():
		var r: Dictionary = rows[key]
		var slot := str(r.get("frase", ""))
		var takes := _takes(slot)
		t.check(takes.size() == 6, "%s: %s con 3 tomas ES + 3 EN (%d)" % [key, slot.get_file(), takes.size()])
		var v := 0.0
		for p in takes:
			var st := load(p) as AudioStream
			if st != null:
				v = maxf(v, st.get_length())
		var rep := maxi(1, int(r.get("frase_rep", 1)))
		var vt := v * rep + Screamers.REP_GAP * (rep - 1)
		var d := float(r.get("duracion", 0.0))
		var tg := d * float(r.get("t_agarre", 0.3))
		var escena := bool(r.get("escena", false))
		var cap := Screamers.LONG_CAP if escena else Screamers.TOTAL_CAP
		# Desde el agarre: al menos 0,3 s de acción, la frase entera y 0,3 s de cola.
		# v0.3.2c: la duración real la da Screamers.seconds_for (la fila + lo que el ARCHIVO de la frase pida de más):
		# si alguien instala tomas más largas (Trainer nuevo) la muerte se alarga sola, sin tocar el JSON.
		var real := Screamers.seconds_for(r)
		t.check(real - tg >= vt_now(r) + Screamers.TAIL_S + 0.3, "%s: %.1f s ≥ agarre %.2f + frase %.2f + 0,3 de cola (+0,3 de acción)" % [key, real, tg, vt_now(r)])
		t.check(real <= cap, "%s: %.1f s dentro del tope (%.1f)" % [key, real, cap])
		if absf(float(r.get("frase_s_max", -1.0)) - vt) > 0.02:
			_report("AVISO %s: frase_s_max %.3f ≠ la toma más larga %.3f (seconds_for lo compensa: %.2f s)" % [key, float(r.get("frase_s_max", -1.0)), vt, real])
		if not escena:
			max_d = maxf(max_d, d)
		_report("frase %s · %s · %.2f s (×%d) · fila %.1f s · agarre %.2f" % [key, slot.get_file(), v, rep, d, tg])
	# Checkpoints espera max(SCREAMER_CAP_S, Screamers.wait_cap) = la duración real de la fila + margen (v0.3.2c).
	var worst := 0.0
	for key2 in rows.keys():
		var r2: Dictionary = rows[key2]
		if not bool(r2.get("escena", false)):
			worst = maxf(worst, Screamers.seconds_for(r2) + 0.3 - maxf(Checkpoints.SCREAMER_CAP_S, Screamers.wait_cap(str(r2.get("asesino", "")), str(key2).get_slice("@", 0))))
	t.check(worst <= 0.0, "Checkpoints espera cada fila entera + 0,3 s (la más larga: %.2f s; peor diferencia %.2f)" % [max_d, worst])
	t.check(Screamers.TOTAL_CAP >= max_d, "TOTAL_CAP %.1f ≥ %.1f" % [Screamers.TOTAL_CAP, max_d])
	# La regla lee el archivo: una fila con una frase más larga de lo que conocía (frase_s_max viejo) se alarga sola,
	# y una fila por defecto sin frase_s_max (GRASA) dura al menos agarre + frase + cola.
	# kills2: las filas con accion_s (Trainer, Perrito) ya miden la toma real (agarre + acción + toma + cola, sin
	# frase_s_max): la regla de frase_s_max se prueba en la misma fila sin accion_s, y la de accion_s aparte.
	var probe: Dictionary = (rows["training_inasistencia"] as Dictionary).duplicate()
	probe.erase("accion_s")
	var base_d := Screamers.seconds_for(probe)
	probe["frase_s_max"] = float(probe.get("frase_s_max", 2.2)) - 1.0  # como si la toma nueva durara 1 s más
	t.check(absf(Screamers.seconds_for(probe) - (base_d + 1.0)) <= 0.03, "una toma 1 s más larga alarga la muerte 1 s (%.2f → %.2f)" % [base_d, Screamers.seconds_for(probe)])
	for ak in rows.keys():
		var ar: Dictionary = rows[ak]
		if float(ar.get("accion_s", 0.0)) > 0.0 and str(ar.get("frase", "")) != "":
			var avt := Screamers.slot_len(str(ar["frase"])) * maxi(1, int(ar.get("frase_rep", 1))) + Screamers.REP_GAP * (maxi(1, int(ar.get("frase_rep", 1))) - 1)
			var want := clampf(Screamers.grab_s(ar, float(ar.get("duracion", Screamers.DEFAULT_SECONDS))) + float(ar["accion_s"]) + avt + Screamers.TAIL_S + Screamers.CUT, 1.0, Screamers.TOTAL_CAP)
			t.check(absf(Screamers.seconds_for(ar) - want) <= 0.01, "%s: con accion_s %.2f dura agarre + acción + la toma más larga + cola (%.2f s)" % [ak, float(ar["accion_s"]), want])
	t.check(Screamers.wait_cap("trainer", "training_inasistencia") >= Screamers.seconds_for(rows["training_inasistencia"]) + 0.39, "Checkpoints espera la duración real + margen")
	# El golpe de la toma (frase_golpe_s): la voz arranca antes del grito lo que el golpe esté más adentro del archivo.
	for tk in ["training_reprobado", "training_inasistencia"]:
		t.check((rows[tk] as Dictionary).get("frase_golpe_s", null) is Array and ((rows[tk] as Dictionary)["frase_golpe_s"] as Array).size() == 3, "%s declara frase_golpe_s por toma" % tk)
	var fxp := Screamers.new()
	fxp.row = {"frase_golpe_s": [0.24, 0.30, 0.34]}
	fxp._take_path = "res://x/scr_grito_gaaaa_02.ogg"
	t.check(absf(fxp.voice_hit_s() - 0.30) < 0.001 and absf(fxp.voice_lead() - 0.19) < 0.001, "toma _02 con golpe a 0,30 s: la voz arranca 0,19 s antes (%.2f)" % fxp.voice_lead())
	fxp.row = {}
	t.check(fxp.voice_lead() < 0.001, "sin frase_golpe_s: como siempre (0 s de adelanto)")
	fxp.free()
	var gr := Screamers.row_for("grasa", "x")
	var gl := Screamers.slot_len(str(gr.get("frase", "")))
	t.check(str(gr.get("frase", "")).ends_with("scr_grito_hail_grasa") and gl > 0.5, "GRASA grita «¡HAIL GRASAAAA!» (%.2f s)" % gl)
	t.check(tr("SCR_K2_HAIL_GRASA").contains("HAIL GRASA"), "texto «%s»" % tr("SCR_K2_HAIL_GRASA"))
	t.check(Screamers.seconds_for(gr) >= float(gr.get("duracion", 0.0)) * float(gr.get("t_agarre", 0.3)) + gl + Screamers.TAIL_S, "GRASA: %.2f s ≥ agarre + frase %.2f + cola" % [Screamers.seconds_for(gr), gl])
	for c in FRASE.keys():
		t.check(str((rows[c] as Dictionary).get("frase", "")).ends_with(str(FRASE[c])), "%s grita %s" % [c, FRASE[c]])
	# En español es la frase de Joan tal cual; en otro idioma (--lang en) basta con que esté traducida.
	var rows_k2: Dictionary = DataLoader.dict("screamers").get("causas", {})
	t.check(str((rows_k2["aht_bo"] as Dictionary).get("frase_texto", "")) == "SCR_K2_CORREO10" and str((rows_k2["work_avoiding"] as Dictionary).get("frase_texto", "")) == "SCR_K2_ACASO" and str((rows_k2["reflejo_kyc"] as Dictionary).get("frase_texto", "")) == "SCR_K2_ACASO", "correo excedido: «10 minutos de correo»; work avoiding y reflejo KYC: «¿acaso no sabes trabajar?»")
	var c10 := tr("SCR_K2_CORREO10")
	t.check(c10 != "SCR_K2_CORREO10" and (c10.contains("10 MINUTOS DE CORREO") or c10.contains("10 MINUTES")), "texto «%s» (la frase de Joan para el correo)" % c10)
	for i in range(1, 4):
		t.check(AudioManager.voice_path("voces/shero/scr_grito_correo10_%02d" % i) != "", "toma %d de la frase del correo (%s)" % [i, Loc.language])
	var acaso := tr("SCR_K2_ACASO")
	if TranslationServer.get_locale().begins_with("es"):
		t.check(acaso.contains("ACASO NO SABES TRABAJAR"), "texto «%s» (la frase de Joan)" % acaso)
	else:
		t.check(acaso != "" and acaso != "SCR_K2_ACASO" and not acaso.contains("ACASO"), "texto «%s» (la frase de Joan, traducida a %s)" % [acaso, TranslationServer.get_locale()])
	t.check(tr("SCR_K2_45_MINUTOS") == "¡45 MINUTOS! ¡NI UN SEGUNDO MÁS!" or tr("SCR_K2_45_MINUTOS") == "45 MINUTES! NOT ONE SECOND MORE!", "lunch excedido: «%s»" % tr("SCR_K2_45_MINUTOS"))
	t.check(str((rows["lunch_excedido"] as Dictionary).get("frase_texto", "")) == "SCR_K2_45_MINUTOS" and float((rows["lunch_excedido"] as Dictionary).get("frase_parte2_s", 0.0)) > 1.5, "lunch excedido: subtítulo y el arranque de la 2.ª mitad (%.2f s)" % float((rows["lunch_excedido"] as Dictionary).get("frase_parte2_s", 0.0)))
	t.check(tr("SCR_Q2_TERCER_BREAK").contains("NO HAY BREAKS") or tr("SCR_Q2_TERCER_BREAK").contains("NO BREAKS"), "tercer break termina en «¡NO HAY BREAKS!»")
	t.check(int((rows["calibracion_final"] as Dictionary).get("frase_rep", 1)) == 2, "Haime grita «¡EMPATÍAAAA!» dos veces")
	t.check(str((rows["vitzo_reminder"] as Dictionary).get("kill", "")) == "vitzo_fusion" and str((rows["vitzo_reminder"] as Dictionary).get("kill_alcance", "")) == "vitzo_fusion", "reminder ignorado → la fusión (sentado y de pie)")
	for k in ["correo_vitzo", "wmm_correo_vitzo", "wmm_pod_correo"]:
		t.check(str((rows[k] as Dictionary).get("kill_alcance", "")) == "vitzo_salto", "%s: de pie sigue con vitzo_salto" % k)


## Largo de la frase en el idioma actual (lo que mide Screamers.seconds_for).
func vt_now(r: Dictionary) -> float:
	var rep := maxi(1, int(r.get("frase_rep", 1)))
	return Screamers.slot_len(str(r.get("frase", ""))) * rep + Screamers.REP_GAP * (rep - 1)


# --- una muerte cambiada --------------------------------------------------------------------------------------

func one(t: Node, case_id: String) -> void:
	var k1: Object = (load(K1) as GDScript).new()
	Loc.set_setting(KillGore.SETTING, "normal")
	await k1.call("one", t, case_id)
	var info: Dictionary = Screamers.last_info
	var d := float(info.get("duracion_real", 0.0))
	var g := float(info.get("grito_s", -1.0))
	var fs := float(info.get("frase_s", 0.0))
	t.check(fs > 0.5 and g > 0.0 and g + fs + 0.25 <= d, "%s: la frase termina (grito %.2f + %.2f s ≤ %.2f s − cola)" % [case_id, g, fs, d])
	var beats: Array = info.get("beats", [])
	for b in CHANGED.get(case_id, []):
		t.check(beats.has(b), "%s: tiempo nuevo «%s» (Joan)" % [case_id, b])
	var gore: Array = info.get("gore", [])
	t.check(gore.has("sangre") or gore.has("cara"), "%s: sangre / heridas con Contenido gráfico Normal (%s)" % [case_id, str(gore)])
	if FRASE.has(case_id):
		t.check(str(info.get("frase_path", "")).contains(str(FRASE[case_id])), "%s: grita %s (%s)" % [case_id, FRASE[case_id], str(info.get("frase_path", "")).get_file()])
	_report("%s · %.2f s · grito %.2f + %.2f · tiempos %s · gore %s" % [case_id, d, g, fs, str(beats), str(gore)])


# --- la fusión ------------------------------------------------------------------------------------------------

func _fusion_run(t: Node, agent: String, seen: bool, force_skip_at: float = -1.0) -> Dictionary:
	await t.start_shift(agent, 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var vistas: Dictionary = {}
	if seen:
		vistas["vitzo_fusion"] = true
	Loc.set_setting("kills_vistas", vistas)
	Screamers.last_info = {}
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)
	var shown: Array = t.spy("death_shown")
	var t0 := Time.get_ticks_msec()
	t.die("vitzo_reminder", "", "vitzo")
	var el := 0.0
	var cam3 := false
	var fused_seen := false
	var hair_max := 0.0
	var hair_min := 9.0
	var open_max := 0.0
	var k32 := false
	while el < 34.0 and shown.is_empty():
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP) as Screamers
		if fx != null:
			if fx.has_meta("cam_override"):
				cam3 = true
			var fz := fx._stage.find_child("AgenteFusionado", true, false) as Node3D if fx._stage != null and is_instance_valid(fx._stage) else null
			if fz != null:
				# v0.3.2d: el pelo se le cae por etapas (no aparece calvo), la boca se le abre al gritar y el cuerpo va
				# con los clips k32 (tools/anim/clips_kills.py).
				if fz.has_meta("st_hair"):
					hair_max = maxf(hair_max, float(fz.get_meta("st_hair")))
					hair_min = minf(hair_min, float(fz.get_meta("st_hair")))
				open_max = maxf(open_max, float(fz.get_meta("st_open", 0.0)))
				var fr := fz.get_meta("rig", null) as CharacterRig
				if fr != null and fr.animator != null and fr.animator.current.begins_with("k32/fus_"):
					k32 = true
			if fx._stage != null and is_instance_valid(fx._stage) and fx._stage.find_child("AgenteFusionado", true, false) != null:
				fused_seen = true
			if force_skip_at > 0.0 and fx._clock >= force_skip_at:
				Screamers.last_info["fusion_forzar_salto"] = true
	var info: Dictionary = Screamers.last_info.duplicate()
	info["_cam3"] = cam3
	info["_hair_max"] = hair_max
	info["_hair_min"] = hair_min
	info["_open_max"] = open_max
	info["_k32"] = k32
	info["_fused"] = fused_seen
	info["_shown"] = not shown.is_empty()
	info["_cam_back"] = t.player() != null and t.player().camera.current
	Engine.time_scale = scale0
	await t.reconnect()
	await t.until(func() -> bool: return Checkpoints.can_die(), 6.0)
	var _u := t0
	return info


func _fusion(t: Node, agent: String) -> void:
	var info: Dictionary = await _fusion_run(t, agent, false)
	var spec: Dictionary = KillMoves.SPEC["vitzo_fusion"]
	t.check(str(info.get("kill", "")) == "vitzo_fusion", "%s: la fusión (corrió «%s»)" % [agent, str(info.get("kill", ""))])
	t.check(info.get("beats", []) == spec["beats"], "%s: tiempos %s" % [agent, str(info.get("beats", []))])
	var props: Array = info.get("props", [])
	for p in spec["props"]:
		t.check(props.has(p), "%s: %s" % [agent, p])
	t.check(bool(info.get("_fused", false)) and bool(info.get("_cam3", false)), "%s: agente fusionado en tercera persona" % agent)
	t.check(str(info.get("fusion_agente", "")) == agent, "%s: es su propio agente (%s)" % [agent, str(info.get("fusion_agente", ""))])
	t.check(str(info.get("fusion_voz", "")).contains("fusion_reminder_" + agent.to_lower()), "%s: repite el reminder con su voz rota (%s)" % [agent, str(info.get("fusion_voz", "")).get_file()])
	var d := float(info.get("duracion_real", 0.0))
	# kills2 (Joan: «un poquito menos»): de 22,9 s (antes_golpe de la fila) a 15-20 % menos con cada agente e idioma
	# (KillMoves.FUSION_TARGET_S: el tempo de lo que no es voz se ajusta a su grito y su reminder); la fila (20,0 s)
	# queda de tope.
	var before := float((Screamers.row_for("vitzo", "vitzo_reminder").get("antes_golpe", {}) as Dictionary).get("duracion", 22.9))
	t.check(d >= before * 0.8 - 0.05 and d <= before * 0.85 + 0.05 and absf(d - float(info.get("duracion", 0.0))) <= 0.3, "%s: dura %.2f s (antes %.1f s: %.0f %% menos; mismas etapas a tempo %.2f)" % [agent, d, before, 100.0 * (1.0 - d / before), float(info.get("fusion_tempo", 1.0))])
	_report("fusión %s: %.2f s (antes %.1f s, %.0f %% menos) · escena 1 %.2f s · sala %.2f s" % [agent, d, before, 100.0 * (1.0 - d / before), float(info.get("fusion_corte_s", 0.0)), float(info.get("fusion_sala_s", 0.0))])
	# v0.3.2d (Joan: «que dure más… donde el agente se resiste… que grite cuando ya no puede resistirse y al final se
	# fusione por completo»): las etapas, el grito con SU voz, el cuerpo animado y lo que se ve.
	t.check(bool(info.get("_k32", false)), "%s: el cuerpo va con los clips k32/fus_* (último: %s)" % [agent, str(info.get("fusion_clip", "-"))])
	t.check(str(info.get("fusion_grito", "")).contains("fusion_grito_" + agent.to_lower()), "%s: grita con su propia voz (%s)" % [agent, str(info.get("fusion_grito", "")).get_file()])
	var beats: Array = info.get("beats", [])
	t.check(beats.find("grito_agente") > beats.find("antena") and beats.find("rigido") > beats.find("grito_agente") and beats.find("corte") > beats.find("rigido"), "%s: se resiste, grita, y recién ahí se completa" % agent)
	var two := 0.12
	for rep in [1, 2]:
		var rst := load(AudioManager.voice_path("voces/agentes/fusion_reminder_%s_%02d" % [agent.to_lower(), rep])) as AudioStream
		two += rst.get_length() if rst != null else 9.0
	t.check(float(info.get("fusion_sala_s", 0.0)) >= two + 0.3, "%s: la escena de la sala dura %.2f s (el reminder cabe entero dos veces: %.2f s)" % [agent, float(info.get("fusion_sala_s", 0.0)), two])
	t.check(float(info.get("_hair_max", 0.0)) >= 0.99 and float(info.get("_hair_min", 9.0)) <= 0.01, "%s: empieza con su pelo y se le cae (%.2f → %.2f)" % [agent, float(info.get("_hair_max", 0.0)), float(info.get("_hair_min", 9.0))])
	t.check(float(info.get("_open_max", 0.0)) >= 0.99, "%s: la boca se le abre al gritar (%.2f)" % [agent, float(info.get("_open_max", 0.0))])
	t.check(props.has("silla"), "%s: la silla sale rodando (no se esconde)" % agent)
	t.check(int(info.get("fusion_reps", 0)) >= 2, "%s: el reminder se oye entero al menos dos veces (%d)" % [agent, int(info.get("fusion_reps", 0))])
	t.check(not bool(info.get("fusion_saltable", true)), "%s: la primera vez no se salta" % agent)
	t.check(bool(info.get("_shown", false)) and bool(info.get("_cam_back", false)), "%s: «Usuario desconectado» y vuelve tu cámara" % agent)
	_report("fusión %s · %.2f s · %s · voz %s" % [agent, d, str(info.get("beats", [])), str(info.get("fusion_voz", "")).get_file()])


func _fusion_salto(t: Node) -> void:
	var info: Dictionary = await _fusion_run(t, "Marko", true, 3.3)
	t.check(bool(info.get("fusion_saltable", false)), "ya vista: se puede saltar")
	var s := float(info.get("fusion_saltada", -1.0))
	t.check(s >= 3.0 and s < 4.5, "se saltó a los %.2f s (desde los 3 s)" % s)
	t.check(float(info.get("duracion_real", 99.0)) < 5.0 and bool(info.get("_shown", false)), "salta a la pantalla de muerte (%.2f s)" % float(info.get("duracion_real", 0.0)))
	t.check(bool(info.get("_cam_back", false)), "vuelve tu cámara")
	var info2: Dictionary = await _fusion_run(t, "Marko", true, 1.5)
	t.check(float(info2.get("fusion_saltada", -1.0)) < 0.0 or float(info2.get("fusion_saltada", -1.0)) >= 3.0, "antes de los 3 s no se salta (%.2f)" % float(info2.get("fusion_saltada", -1.0)))
	Loc.set_setting("kills_vistas", {})


# --- contenido gráfico ------------------------------------------------------------------------------------------

func _grafico(t: Node) -> void:
	Loc.set_setting(KillGore.SETTING, "")
	t.check(KillGore.enabled(), "por defecto: Normal")
	var om := OptionsMenu.new()
	t.main.get_node("UI").add_child(om)
	await t.frames(2)
	var b := om.find_child("BotonContenidoGrafico", true, false) as Button
	t.check(b != null and b.text == tr("OPT_CONTENIDO_NORMAL"), "Opciones: «%s: %s»" % [tr("OPT_CONTENIDO_GRAFICO"), b.text if b != null else "-"])
	if b != null:
		b.pressed.emit()
		t.check(str(Loc.get_setting(KillGore.SETTING, "")) == "reducido" and not KillGore.enabled() and b.text == tr("OPT_CONTENIDO_REDUCIDO"), "un clic: Reducido")
	om.queue_free()
	var k1: Object = (load(K1) as GDScript).new()
	# Reducido: la misma muerte sin sangre ni crujidos; el susto queda.
	await k1.call("one", t, "ww_sin_ack")
	var red: Dictionary = Screamers.last_info.duplicate()
	t.check(str(red.get("contenido_grafico", "")) == "reducido", "corrió en Reducido")
	t.check((red.get("gore", []) as Array).is_empty() and not (red.get("props", []) as Array).has("sangre"), "Reducido: sin sangre, heridas ni crujidos (%s)" % str(red.get("gore", [])))
	t.check(float(red.get("deform_max", 0.0)) >= 0.9 and str(red.get("frase_path", "")) != "", "Reducido: el susto queda (cara %.2f, grito)" % float(red.get("deform_max", 0.0)))
	Loc.set_setting(KillGore.SETTING, "normal")
	await k1.call("one", t, "ww_sin_ack")
	var nor: Dictionary = Screamers.last_info.duplicate()
	t.check(not (nor.get("gore", []) as Array).is_empty(), "Normal: sangre y heridas (%s)" % str(nor.get("gore", [])))
	t.check(absf(float(nor.get("duracion_real", 0.0)) - float(red.get("duracion_real", 0.0))) <= 0.25, "misma duración en los dos modos")
	# Las intermedias de Joan (ojos, oreja, brazo) desaparecen en Reducido.
	Loc.set_setting(KillGore.SETTING, "reducido")
	await k1.call("one", t, "coaching_exceso")
	t.check(not (Screamers.last_info.get("gore", []) as Array).has("brazo"), "Reducido: sin el brazo quebrado")
	Loc.set_setting(KillGore.SETTING, "normal")
	await k1.call("one", t, "coaching_exceso")
	t.check((Screamers.last_info.get("gore", []) as Array).has("brazo"), "Normal: el antebrazo se dobla al revés (intermedio)")


# --- buses ------------------------------------------------------------------------------------------------------

func _buses(t: Node) -> void:
	KillGore.ensure_buses()
	var si := AudioServer.get_bus_index(KillGore.BUS_SFX)
	var vi := AudioServer.get_bus_index(KillGore.BUS_VOZ)
	t.check(si >= 0 and vi >= 0, "buses ScreamerSFX y ScreamerVoz")
	var comp: AudioEffectCompressor = null
	var lim: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(si):
		var e := AudioServer.get_bus_effect(si, i)
		if e is AudioEffectCompressor:
			comp = e
		if e is AudioEffectHardLimiter:
			lim = e
	t.check(comp != null and str(comp.sidechain) == KillGore.BUS_VOZ, "agache en cadena lateral desde la voz (la frase se entiende)")
	t.check(lim != null and lim.ceiling_db <= -1.0, "limitador a %.1f dBFS (sin recortes)" % (lim.ceiling_db if lim != null else 0.0))
	t.check(AudioServer.get_bus_send(si) == "Sala" and AudioServer.get_bus_send(vi) == "Sala", "los dos van a Sala (volumen de Opciones)")
	var gi := AudioServer.get_bus_index(KillGore.BUS_GOLPE)
	t.check(gi >= 0 and AudioServer.get_bus_send(gi) == "Master", "bus ScreamerGolpe (el golpe del salto de Vitzo) directo a Master")
	# Silencio → golpe: los buses bajan y vuelven exactamente a su volumen.
	var sala := AudioServer.get_bus_index("Sala")
	var v_sala := AudioServer.get_bus_volume_db(sala)
	var fxd := Screamers.new()
	fxd._done = true
	fxd.set_process(false)
	t.get_tree().root.add_child(fxd)
	KillGore.hit_dip(fxd, 0.03, 0.4, 0.03)
	await t.get_tree().create_timer(0.2, true, false, false).timeout
	t.check(AudioServer.get_bus_volume_db(sala) < v_sala - 20.0, "silencio antes del golpe: Sala a %.0f dB" % AudioServer.get_bus_volume_db(sala))
	KillGore.sync_golpe()
	t.check(absf(AudioServer.get_bus_volume_db(gi) - v_sala) < 0.01, "el golpe suena al volumen de Sala (%.1f dB) mientras lo demás calla" % AudioServer.get_bus_volume_db(gi))
	await t.get_tree().create_timer(0.6, true, false, false).timeout
	t.check(absf(AudioServer.get_bus_volume_db(sala) - v_sala) < 0.01, "y Sala vuelve a %.1f dB" % v_sala)
	fxd.queue_free()
	var mlim: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			mlim = AudioServer.get_bus_effect(0, i)
	if mlim != null:
		KillGore.master_guard(false)  # si un screamer anterior dejó el techo puesto (espera de 4 s), se quita antes de medir
		var c0 := mlim.ceiling_db
		KillGore.master_guard(true)
		t.check(mlim.ceiling_db <= KillGore.MASTER_CEIL_SCREAMER + 0.01, "durante el screamer Master limita a %.1f dBFS (pico verdadero ≤ -1 dBTP)" % mlim.ceiling_db)
		KillGore.master_guard(false)
		t.check(absf(mlim.ceiling_db - c0) < 0.01, "y vuelve a %.1f al terminar" % c0)
	for s in ["sfx/kill_impacto_01", "sfx/kill_slam_01", "sfx/kill_hueso_01", "sfx/kill_gore_01", "sfx/kill_rugido", "sfx/kill_chillido"]:
		t.check(AudioManager.has_slot(s, false), "capa de impacto: %s" % s)


# --- Precarga en segundo plano (cuelgue «propagate_notification from a non-main thread») ------------------------

func _prewarm_estres(t: Node) -> void:
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var killers := ["shero", "rasec", "haime", "trainer", "vitzo", "rta", "perrito"]
	var extra: Array[String] = []
	for a in AGENTS:
		for i in range(1, 5):
			extra.append(AudioManager.voice_path("voces/agentes/dolor_%s_%02d" % [a.to_lower(), i]))
	var root := t.get_tree().root
	var kids0 := root.get_child_count()
	var errs := 0
	# 1) En el almuerzo.
	Metrics.set_aux(Metrics.Aux.LUNCH)
	for i in 20:
		Screamers.prewarm(killers)
		KillGore.prewarm()
		for p in extra:
			KillGore.request(p)
		if FloorBase.active != null:
			ScreamRig.prewarm(FloorBase.active)
		await t.frames(2)
	for p in KillGore._asked:
		if int(KillGore._asked[p]) > 1:
			errs += 1
	t.check(Metrics.aux == Metrics.Aux.LUNCH, "sigue en almuerzo durante las 20 precargas")
	t.check(errs == 0, "cada ruta se pide al hilo una sola vez (%d rutas, %d repetidas)" % [KillGore._asked.size(), errs])
	# 2) Con un contacto activo.
	Metrics.set_aux(Metrics.Aux.AVAILABLE)
	var cm: ContactManager = t.main.get("contacts")
	var active := false
	if cm != null:
		var p4c: GDScript = load("res://scripts/dev/escenarios/p4_casos.gd")
		var cases: Array = p4c.call("all_cases")
		if not cases.is_empty():
			cm.phase = ContactManager.Phase.IDLE
			cm.current = {}
			cm._offer((cases[0] as Dictionary).duplicate(true))
			cm.accept()
			active = cm.phase == ContactManager.Phase.ACTIVE
	t.check(active, "contacto activo")
	for i in 20:
		Screamers.prewarm(killers)
		KillGore.prewarm()
		await t.frames(1)
	errs = 0
	for p in KillGore._asked:
		if int(KillGore._asked[p]) > 1:
			errs += 1
	t.check(errs == 0, "con el contacto activo tampoco se repide nada")
	# 3) Pedida desde un hilo de trabajo: se difiere al principal (no toca nada desde el hilo).
	var wid := WorkerThreadPool.add_task(func() -> void: KillGore.request("res://assets/audio/sfx/kill_tela.ogg"))
	WorkerThreadPool.wait_for_task_completion(wid)
	await t.until(func() -> bool: return KillGore.pending() == 0, 20.0)
	t.check(KillGore.pending() == 0, "el hilo principal recogió todas las cargas (%d pendientes)" % KillGore.pending())
	t.check(KillGore._held.size() >= PREWARM_TOTAL, "%d recursos precargados y retenidos" % KillGore._held.size())
	await t.seconds(0.6)
	var fxl := 0
	for c in root.get_children():
		if str(c.name).begins_with("PrecalentarScreamerFx"):
			fxl += 1
	t.check(fxl == 0 and root.get_child_count() <= kids0 + 1, "sin nodos de precarga sobrantes (raíz %d → %d)" % [kids0, root.get_child_count()])
	if cm != null:
		cm.phase = ContactManager.Phase.IDLE
		cm.current = {}
	# 4) Y el screamer sigue funcionando justo después.
	Screamers.last_info = {}
	var shown: Array = t.spy("death_shown")
	t.die("lunch_excedido")
	await t.until(func() -> bool: return not shown.is_empty(), 20.0)
	t.check(not shown.is_empty() and str(Screamers.last_info.get("kill", "")) != "", "tras el estrés el screamer corre normal (%s)" % str(Screamers.last_info.get("kill", "")))
	await t.reconnect()


const PREWARM_TOTAL := 21


# --- Vitzo -----------------------------------------------------------------------------------------------------

func _vitzo_tamano(t: Node) -> void:
	t.check(absf(float(Screamers.HEIGHTS["vitzo"]) - 1.8) < 0.01 and absf(VitzoScreamer.HUMAN_H - 1.8) < 0.01, "Vitzo mide 1,8 m al salir de la pantalla")
	t.check(absf(float((Pursuit.RIG_OF["vitzo"] as Array)[1]) - 1.8) < 0.01, "y te persigue con 1,8 m")
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	Screamers.last_info = {}
	var shown: Array = t.spy("death_shown")
	var scale0 := Engine.time_scale
	Engine.time_scale = minf(scale0, 2.0)
	VitzoScreamer.attack("correo_vitzo")
	var small := 9.0
	var big := 0.0
	var stretch := 0.0
	for _i in 2000:
		await t.get_tree().process_frame
		var fx := t.get_tree().get_first_node_in_group(Screamers.GROUP) as Screamers
		if fx != null and fx._m != null and is_instance_valid(fx._m):
			small = minf(small, fx._m.scale.x)
			big = maxf(big, fx._m.scale.x)
			if fx._rig != null:
				stretch = maxf(stretch, fx._rig.arm_stretch)
		if not shown.is_empty():
			break
	t.check(small < 0.6 and big > 0.99, "sale chico (×%.2f) y crece a tamaño persona (×%.2f)" % [small, big])
	t.check(bool(Screamers.last_info.get("vitzo_crece", false)), "crece al salir del monitor")
	t.check(stretch <= 1.01, "estilo Q2: brazos normales (×%.2f; kills2 tenía ×1,55)" % stretch)
	Engine.time_scale = scale0
	await t.reconnect()


# --- colapso ---------------------------------------------------------------------------------------------------

func _colapso(t: Node) -> void:
	# --- sentado en tu PC, muerte de flujo real (la Fatiga llega a 100)
	await t.start_shift("Jiroshi", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	var r: Dictionary = await _colapso_run(t)
	var info: Dictionary = r["info"]
	t.check((r["scr"] as Array).is_empty() and t.get_tree().get_nodes_in_group(Screamers.GROUP).is_empty(), "colapso sin screamer")
	t.check(bool(r["cam3"]) and bool(info.get("tercera_persona", false)), "colapso en tercera persona (Joan)")
	t.check(str(info.get("anim", "")) == "v_colapso_s" and bool(info.get("sentado", false)), "sentado: actuado de cuerpo entero (clip %s)" % str(info.get("anim", "")))
	t.check(int(info.get("silla", 0)) >= 1 and bool(info.get("silla_rueda", false)), "la silla sale rodando (%d piezas)" % int(info.get("silla", 0)))
	t.check(bool(info.get("luz", false)) and float(info.get("camara_m", 0.0)) >= 0.9, "luz propia y cámara despejada a %.2f m" % float(info.get("camara_m", 0.0)))
	t.check(float(r["early_close"]) <= 0.001, "la viñeta no se cierra antes de %.2f s (máx. %.3f)" % [DeathAnimations.CLOSE_AT, float(r["early_close"])])
	t.check(bool(info.get("softphone", false)) and not bool(info.get("llamada", true)), "sin llamada: el softphone suena en la sala")
	t.check(not info.has("senales_v03_cortadas") and not ("collapse_sounds" in AudioManager.get_node("AudioDirector")), "las señales de colapso de v0.3 (latido y acúfeno a nivel pleno) ya no se lanzan")
	var d := DeathAnimations.duration("colapso")
	t.check(d >= 3.5 and d <= 5.6 and d < Checkpoints.SCREAMER_CAP_S - 0.5, "dura %.1f s (cabe en la espera de Checkpoints, %.1f)" % [d, Checkpoints.SCREAMER_CAP_S])
	t.check(not (r["shown"] as Array).is_empty(), "«Usuario desconectado» después")
	t.check(t.player().camera.current, "vuelve tu cámara")
	t.check(bool(r["chair_back"]), "la silla vuelve a su sitio")
	await t.reconnect()
	await t.until(func() -> bool: return Checkpoints.can_die(), 8.0)
	# --- de pie, lejos del escritorio, en Modo liviano
	var lv0 := GfxQuality.current
	GfxQuality.current = "liviano"
	var p: Player = t.player()
	if p.seated:
		p.stand_up()
	p.teleport(Vector3(20.5, p.global_position.y, 0.8), -55.0)
	await t.get_tree().create_timer(0.3).timeout
	var r2: Dictionary = await _colapso_run(t)
	var info2: Dictionary = r2["info"]
	t.check(bool(r2["cam3"]) and str(info2.get("anim", "")) == "v_colapso_p" and not bool(info2.get("sentado", true)), "de pie (Modo liviano): tercera persona con el clip %s" % str(info2.get("anim", "")))
	t.check((r2["scr"] as Array).is_empty() and not (r2["shown"] as Array).is_empty() and t.player().camera.current, "de pie: sin screamer, «Usuario desconectado», vuelve tu cámara")
	GfxQuality.current = lv0
	await t.reconnect()
	# --- los cinco agentes traen los dos clips; la voz del cliente y su subtítulo existen (ES y EN)
	for ag in ["Jiroshi", "Marko", "Llauri", "Ttoom", "Juan"]:
		var lib := load("res://assets/anim/%s_kills.res" % CharacterRig.agent_model(ag)) as AnimationLibrary
		var ok := lib != null and lib.has_animation("v_colapso_s") and lib.has_animation("v_colapso_p")
		t.check(ok and absf(lib.get_animation("v_colapso_s").length - DeathAnimations.CLIP_S) < 0.2, "%s: clips de colapso sentado y de pie" % ag)
	t.check(AudioManager.resolve("voces/clientes/colapso_alo", false) != "" and AudioManager.resolve("voces/clientes/en/colapso_alo", false) != "", "voz del cliente en la línea (ES y EN)")
	t.check(tr("K2_COLAPSO_ALO") != "K2_COLAPSO_ALO" and tr("K2_COLAPSO_ALO") != "", "subtítulo «%s»" % tr("K2_COLAPSO_ALO"))
	# --- con una llamada activa: el cliente sigue ahí (su voz por el auricular y el subtítulo con él como hablante).
	# v0.3.2 (integración): la línea va por el VoiceDirector con prioridad SCREAMER (lo único que suena durante una
	# muerte); `fin_colapso_cliente` (v032_fin) la mira en una muerte de verdad, con otros queriendo hablar.
	var cm := t.get_tree().get_first_node_in_group("contact_manager") as ContactManager
	if cm != null:
		var ph0 := cm.phase
		var cur0: Dictionary = cm.current
		var started: Array = []
		var subs: Array = []
		var on_line := func(id: String, sp: String, pr: int) -> void: started.append([id, sp, pr])
		var on_sub := func(sp: String, tx: String, _s: float) -> void: subs.append([sp, tx])
		VoiceDirector.line_started.connect(on_line)
		VoiceDirector.subtitle_shown.connect(on_sub)
		var fx := DeathAnimations.new()
		fx.name = "PruebaVozColapso"
		t.get_tree().root.add_child(fx)
		cm.phase = ContactManager.Phase.ACTIVE
		cm.current = {"canal": "llamada", "id": "prueba_colapso"}
		fx._room_voice(t.player(), 0.05)
		cm.phase = ph0
		cm.current = cur0
		await t.get_tree().create_timer(0.4).timeout
		var voz := VoiceDirector.get("_player") as AudioStreamPlayer
		var line_ok := false
		for e in started:
			if str(e[0]) == DeathAnimations.ALO_SLOT and str(e[1]) == "cliente" and int(e[2]) == VoiceDirector.P.SCREAMER:
				line_ok = true
		var said := false
		for e in subs:
			if str(e[0]) == "cliente" and str(e[1]) == tr("K2_COLAPSO_ALO"):
				said = true
		t.check(bool(DeathAnimations.last_info.get("llamada", false)) and line_ok and voz != null and str(voz.bus) == "Auricular" and said,
			"con llamada: el cliente dice «%s» por el VoiceDirector (bus %s, prioridad de screamer, subtítulo con el cliente como hablante)" % [tr("K2_COLAPSO_ALO"), str(voz.bus) if voz != null else "-"])
		t.check(voz != null and is_equal_approx(voz.volume_db, AudioManager.gain_db(DeathAnimations.ALO_SLOT)) and voz.volume_db >= -1.0 and voz.volume_db <= 1.0, "al nivel de la toma (%.1f dB)" % (voz.volume_db if voz != null else 0.0))
		VoiceDirector.line_started.disconnect(on_line)
		VoiceDirector.subtitle_shown.disconnect(on_sub)
		VoiceDirector.stop_all("prueba")
		VoiceDirector.subtitle_shown.emit("", "", 0.0)
		fx.queue_free()


## Una muerte por Fatiga de flujo real (Fatigue llega a 100 → Checkpoints → DeathAnimations) vigilada cuadro a cuadro.
func _colapso_run(t: Node) -> Dictionary:
	var scr: Array = t.spy("screamer_finished")
	var shown: Array = t.spy("death_shown")
	DeathAnimations.last_info = {}
	var p: Player = t.player()
	var chairs: Array = []
	if p.seated and FloorBase.active != null:
		for n in FloorBase.active.find_children("Silla*", "MeshInstance3D", true, false):
			var d2 := (n as Node3D).global_position - p.global_position
			d2.y = 0.0
			if d2.length() < 0.6:
				chairs.append([n, (n as Node3D).global_transform])
	var cam3 := false
	var early_close := 0.0
	var info: Dictionary = {}
	Fatigue.set_value(99.0)
	Fatigue.add(10.0)
	for _i in 2400:
		await t.get_tree().process_frame
		var c := t.get_tree().root.get_viewport().get_camera_3d()
		if c != null and str(c.name) == "CamaraColapso":
			cam3 = true
		for n in t.get_tree().get_nodes_in_group(DeathAnimations.GROUP):
			var fx := n as DeathAnimations
			if fx._t3 > 0.0 and fx._t3 < DeathAnimations.CLOSE_AT - 0.15:
				for ch in fx.get_children():
					if ch is ColorRect and (ch as ColorRect).material is ShaderMaterial:
						early_close = maxf(early_close, float(((ch as ColorRect).material as ShaderMaterial).get_shader_parameter("close")))
		if not DeathAnimations.last_info.is_empty():
			info = DeathAnimations.last_info.duplicate()
		if not shown.is_empty():
			break
	var chair_back := true
	for e in chairs:
		if is_instance_valid(e[0]) and not ((e[0] as Node3D).global_transform as Transform3D).is_equal_approx(e[1] as Transform3D):
			chair_back = false
	return {"scr": scr, "shown": shown, "cam3": cam3, "early_close": early_close, "info": info, "chair_back": chair_back}



## [Esc] → «Salir al menú» en mitad de una muerte (pedido de la integración, v0.3.2-final 2803b33: en plena fusión la
## coreografía seguía sobre el screamer liberado). Aquí, sobre este paquete: el colapso rehecho (sentado en cuatro
## momentos: mareo, sobre el escritorio, con la silla rodando y durante el cierre; de pie en dos), la fusión en cuatro
## etapas, muertes propias de cada asesino, la toma de Haime y el agarre genérico (GRASA). Los errores de script los
## cuenta quien corre el escenario (t.sh: «0 script errors»).
func _menu_en_muerte(t: Node) -> void:
	var cases: Array = [["colapso", 0.6, "", false], ["colapso", 2.5, "", false], ["colapso", 3.1, "", false], ["colapso", 4.7, "", false],
		["colapso", 1.4, "", true], ["colapso", 3.0, "", true],
		["vitzo_reminder", 2.5, "", false], ["vitzo_reminder", 9.5, "", false], ["vitzo_reminder", 15.0, "", false], ["vitzo_reminder", 19.0, "", false],
		["tercer_ww", 2.5, "", false], ["calibracion_final", 1.0, "", false], ["calibracion_final", 3.0, "", false], ["llamadas_perdidas", 3.0, "", false],
		["coaching_exceso", 3.0, "", false], ["training_reprobado", 3.0, "", false], ["aux_incorrecto", 2.5, "", false], ["wmm_pod_correo", 2.5, "", false],
		["break_excedido", 2.0, "grasa", false]]
	var ui_bus := AudioServer.get_bus_index("UI")
	# --- pausa en pleno colapso: todo se congela junto (clip, cámara, temporizadores) y sigue al volver
	await t.start_shift("Marko", 2)
	await t.login_at_seat()
	GameState.stop_calm()
	await t.seconds(Checkpoints.GRACE_S + 0.1)
	var shown0: Array = t.spy("death_shown")
	Fatigue.set_value(99.0)
	Fatigue.add(10.0)
	await t.seconds(1.5)
	var dfx: DeathAnimations = null
	for n in t.get_tree().get_nodes_in_group(DeathAnimations.GROUP):
		dfx = n as DeathAnimations
	if t.check(dfx != null and dfx._t3 > 0.5, "pausa: el colapso está en curso"):
		t.get_tree().paused = true
		await t.frames(2)
		var t3a := dfx._t3
		await t.seconds(0.6)
		t.check(is_instance_valid(dfx) and absf(dfx._t3 - t3a) < 0.02 and shown0.is_empty(), "pausa: el colapso se congela (%.2f → %.2f s) y no aparece la pantalla de muerte" % [t3a, dfx._t3 if is_instance_valid(dfx) else -1.0])
		t.get_tree().paused = false
		var ok_shown: bool = await t.until(func() -> bool: return not shown0.is_empty(), 9.0)
		t.check(ok_shown and t.get_tree().get_nodes_in_group(DeathAnimations.GROUP).is_empty(), "pausa: al volver termina y sale «Usuario desconectado»")
	await t.back_to_menu()
	for c in cases:
		var cause := str(c[0])
		var at_s := float(c[1])
		var killer_o := str(c[2])
		await t.start_shift("Marko", 2)
		await t.login_at_seat()
		GameState.stop_calm()
		await t.seconds(Checkpoints.GRACE_S + 0.1)
		if bool(c[3]):
			var p: Player = t.player()
			if p.seated:
				p.stand_up()
			p.teleport(Vector3(20.5, p.global_position.y, 0.8), -55.0)
			await t.seconds(0.3)
		if cause == "colapso":
			Fatigue.set_value(99.0)
			Fatigue.add(10.0)
			await t.frames(2)
		else:
			await t.die(cause, "1", killer_o)
			await t.frames(1)
		var tag := "%s%s%s" % [cause, "@" + killer_o if killer_o != "" else "", " de pie" if bool(c[3]) else ""]
		if not t.check(Checkpoints.dying, "%s: la muerte arranca" % tag):
			await t.back_to_menu()
			continue
		var killer := killer_o if killer_o != "" else Checkpoints.killer_of(cause)
		var total := DeathAnimations.duration(cause)
		if Checkpoints.uses_screamer(killer):
			total = Screamers.duration(killer, cause)
		at_s = minf(at_s, maxf(total - 0.4, 0.5))
		await t.seconds(at_s)
		tag = "%s a los %.1f s" % [tag, at_s]
		t.check(Checkpoints.dying and not t.main.main_menu.visible, "%s: sales con la muerte en curso (dura %.1f s)" % [tag, total])
		t.main.call("_back_to_menu")  # lo que hace «Salir al menú» de la pausa
		await t.frames(3)
		t.check(t.main.main_menu.visible and not GameState.running and not Checkpoints.dying, "%s: estás en el menú, sin muerte en curso" % tag)
		await t.seconds(maxf(total - at_s, 0.0) + 2.5)  # lo que quedaba de la coreografía ya habría corrido
		await t.frames(3)
		var left: Array[String] = []
		for n in t.get_tree().root.find_children("Asesino_*", "", true, false) + t.get_tree().root.find_children("ColapsoTerceraPersona", "", true, false) \
				+ t.get_tree().get_nodes_in_group(Screamers.GROUP) + t.get_tree().get_nodes_in_group(DeathAnimations.GROUP):
			if not (n as Node).is_queued_for_deletion():
				left.append(str((n as Node).name))
		t.check(left.is_empty(), "%s: no queda nada de la muerte en escena ni en pantalla (%s)" % [tag, str(left)])
		t.check(not t.death_screen().visible and t.main.main_menu.visible, "%s: la pantalla de muerte no aparece sola en el menú" % tag)
		t.check(Engine.time_scale > 0.0 and not t.get_tree().paused, "%s: el juego no queda en pausa ni congelado" % tag)
		t.check(ui_bus < 0 or not AudioServer.is_bus_mute(ui_bus), "%s: el bus UI no queda mudo" % tag)
		# el techo de screamer del limitador de Master se devuelve GUARD_HOLD_S segundos REALES después (no escalados)
		var g0 := Time.get_ticks_msec()
		while KillGore._master_ceil <= 0.5 and Time.get_ticks_msec() - g0 < int((KillGore.GUARD_HOLD_S + 2.0) * 1000.0):
			await t.frames(1)
		t.check(KillGore._master_ceil > 0.5, "%s: el limitador de Master vuelve a su techo normal (%.1f s reales)" % [tag, (Time.get_ticks_msec() - g0) / 1000.0])
		# El turno siguiente arranca limpio (con su silla en su sitio y tu cámara).
		await t.start_shift("Marko", 1)
		await t.seconds(1.5)
		t.check(GameState.running and not Checkpoints.dying and not t.death_screen().visible and not t.player().input_locked and t.player().camera.current,
			"%s: el turno siguiente arranca sin muerte heredada, con control y con tu cámara" % tag)
		await t.back_to_menu()


## kills2 (Joan: «el Vitzo que te persigue, ¿por qué se queda parado como 3 segundos? debe saltarte ni bien está en el
## rango»): el camino real (correo a Vitzo → sale del monitor → te paras). (a) Te quedas al lado del escritorio: te salta en
## el mismo instante en que termina de salir. (b) Huyes 6 m: corre desde el primer cuadro (sin el aviso de 3 s de Pursuit)
## y, del alcance al salto, pasa lo que dice su fila (salto_s). En los dos, el tiempo de salida del monitor no cambia.
func _vitzo_sin_espera(t: Node) -> void:
	var scale0 := Engine.time_scale
	for far in [false, true]:
		await t.start_shift("Jiroshi", 2)
		await t.login_at_seat()
		GameState.stop_calm()
		Engine.time_scale = 1.0  # se miden segundos de verdad
		var seq: Array = t.spy("death_sequence_started")
		Screamers.last_info = {}
		Pursuit.transit.clear()
		var v := t.get_tree().get_first_node_in_group("vitzo")
		if v == null:
			t.check(false, "Vitzo existe")
			return
		var tag := "huyendo 6 m" if far else "quieto junto al escritorio"
		v.call("email_detected", "correo_vitzo", false)
		var t0 := Time.get_ticks_msec()
		await t.seconds(0.6)
		var p: Player = t.player()
		p.stand_up()
		if far:
			p.teleport(p.global_position + Vector3(0, 0, 6.0), 180.0)
		var ok: bool = await t.until(func() -> bool: return Pursuit.is_hunting("vitzo") or not seq.is_empty(), 6.0)
		var t_out := (Time.get_ticks_msec() - t0) / 1000.0
		t.check(ok and absf(t_out - (VitzoScreamer.CRAWL_S + VitzoScreamer.DROP_S)) < 0.35, "%s: tarda en salir del monitor lo de siempre (%.2f s; %.1f + %.1f)" % [tag, t_out, VitzoScreamer.CRAWL_S, VitzoScreamer.DROP_S])
		var t1 := Time.get_ticks_msec()
		var d0 := float(Pursuit.info("vitzo").get("dist", -1.0))
		var evs: Array = []
		for e in Pursuit.transit:
			evs.append(str(e[1]))
		t.check(not evs.has("aviso_cerca"), "%s: sin el aviso de 3 s (%s)" % [tag, str(evs)])
		if far:
			await t.seconds(0.5)
			var run_m := float(Pursuit.info("vitzo").get("meters", 0.0))
			t.check(seq.is_empty() and run_m > 1.5, "%s: corre desde el primer cuadro (%.1f m corridos en 0,5 s; con el aviso eran 0 m en 3 s)" % [tag, run_m])
		var caught: bool = await t.until(func() -> bool: return not seq.is_empty(), 20.0)
		var t_catch := (Time.get_ticks_msec() - t1) / 1000.0
		t.check(caught and str(seq[0][1]) == "vitzo", "%s: te alcanza" % tag)
		if not far:
			t.check(t_catch < 0.25, "%s: ya estabas en su rango (%.2f m): te salta en el acto (%.2f s desde que termina de salir; antes ~3 s)" % [tag, d0, t_catch])
		else:
			t.check(t_catch < 0.5 + d0 / VitzoScreamer.CHASE_SPEED + 1.0, "%s: te alcanza en lo que tarda en correr %.1f m (%.2f s)" % [tag, d0, t_catch])
		var ms_catch := int(Pursuit.last_catch.get("ms", 0))
		await t.until(func() -> bool: return Screamers.last_info.has("salto_s"), 3.0)
		var salto := float(Screamers.last_info.get("salto_s", -1.0))
		t.check(salto >= 0.0 and salto <= 0.3, "%s: del alcance al salto %.2f s (fila: salto_s 0,25)" % [tag, salto])
		await t.until(func() -> bool: return str(Screamers.last_info.get("kill", "")) != "", 4.0)
		t.check(str(Screamers.last_info.get("intro", "")) == "zarpazo" and str(Screamers.last_info.get("kill", "")) == "vitzo_salto", "%s: zarpazo + vitzo_salto" % tag)
		_report("vitzo sin espera · %s: sale %.2f s · distancia al empezar %.2f m · alcance %.2f s después · salto %.2f s tras el alcance (ms %d)" % [tag, t_out, d0, t_catch, salto, ms_catch])
		Engine.time_scale = scale0
		await t.wait_death_shown(10.0)
		await t.reconnect()
		await t.frames(3)

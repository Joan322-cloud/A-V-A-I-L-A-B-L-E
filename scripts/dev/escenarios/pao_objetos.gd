## Sin class_name: lo carga scripts/dev/escenarios/runner.gd.
extends RefCounted
## Escenarios de v0.3.2-anim para la animación de OBJETOS (scripts/mundo/object_anim.gd). `--escenario pao`; ids obj_.
##   obj_puerta        puerta batiente: la colisión y `visible` cambian en el mismo instante que antes; la copia llega al
##                     ángulo (96°), al cerrar vuelve y aparece la hoja de verdad; 1000 aperturas/cierres sin deriva ni
##                     copias de más; portazo si la cruza alguien corriendo; reaparecer la deja terminada
##   obj_casillero     casillero y refri (DoorSwing): abren y tocan el marco a la misma hora que en v0.3.1; 1000 pedidos
##                     (muchos a mitad de camino) y la puerta termina EXACTAMENTE en su reposo (antes se torcía)
##   obj_ascensor      hojas: la misma curva seno durante el recorrido (± 2 mm), rebote de gomas después de cerrar,
##                     destino exacto tras 1000 órdenes; el indicador cambia el texto siempre y rueda con su flecha
##   obj_monitor       encender/apagar: el material cambia en el acto (como antes), el parpadeo termina en blanco puro
##                     y el vidrio apagado en su oscuro; 1000 veces sin que quede a medio fundido
##   obj_sillas        un compañero se para: la silla rueda atrás y se queda; se sienta: vuelve a su sitio exacto; el
##                     jugador; 300 veces sin deriva; nombres y padres de las piezas intactos
##   obj_expendedora   cae la lata y todo lo temporal se borra solo (sin fugas tras 60 compras seguidas)
##   obj_microondas    el que calienta se ilumina y vuelve a su vidrio; la puerta abre/cierra al meter el táper y el
##                     vidrio de verdad vuelve a dibujarse
##   obj_ambiente      papeles cerca de la cámara se mueven y lejos vuelven a su reposo exacto; el punto del reloj late
##                     y se queda fijo con la hora congelada; la taza de C-13 humea al empezar el turno y se enfría
##   obj_golpe         un golpe en la mesa hace saltar lo que hay encima y todo vuelve a su sitio exacto
##   obj_liviano       Modo liviano: nada nuevo (sin copias, sin censo, sin vapor); pasar a liviano a mitad lo recoge todo
##   obj_reaparecer    morir y reconectar con cosas a medio camino: todo queda en su estado final
##   obj_costo         costo del gestor por cuadro (piso 2 y -1; normal y liviano)
##   obj_cafeteria     comer el táper en una mesa: al terminar las manos queda sobre el tablero (sin colisión, dentro de
##                     la mesa) y se va al pararte; los carros de bandejas tintinean al rozarlos y vuelven a su reposo
##                     exacto (el carro y su colisión no se mueven); nada de eso en Modo liviano

func escenarios() -> Array[String]:
	return ["obj_puerta", "obj_casillero", "obj_ascensor", "obj_monitor", "obj_sillas", "obj_expendedora", "obj_microondas",
		"obj_ambiente", "obj_golpe", "obj_liviano", "obj_reaparecer", "obj_costo", "obj_cafeteria"]


func run(id: String, _arg: String, t: Node) -> void:
	var ts := Engine.time_scale
	Engine.time_scale = 1.0  # los tweens de los objetos duran décimas: a 8x no habría cuadros que medir
	var q := GfxQuality.current
	ObjectAnim.enabled = true
	match id:
		"obj_puerta": await _puerta(t)
		"obj_casillero": await _casillero(t)
		"obj_ascensor": await _ascensor(t)
		"obj_monitor": await _monitor(t)
		"obj_sillas": await _sillas(t)
		"obj_expendedora": await _expendedora(t)
		"obj_microondas": await _microondas(t)
		"obj_ambiente": await _ambiente(t)
		"obj_golpe": await _golpe(t)
		"obj_liviano": await _liviano(t)
		"obj_reaparecer": await _reaparecer(t)
		"obj_costo": await _costo(t)
		"obj_cafeteria": await _cafeteria(t)
	GfxQuality.current = q
	ObjectAnim.enabled = true
	Engine.time_scale = ts


# --- ayudas ----------------------------------------------------------------------------------------------------------

func _piso(t: Node, f: int) -> FloorBase:
	if t.building() == null:
		await t.start_shift("Jiroshi", 1)
	var b: Building = t.building()
	GfxQuality.current = "media"
	GameState.stop_calm()
	var cm := t.get_tree().get_first_node_in_group("contact_manager")
	if cm != null:
		(cm as Node).process_mode = Node.PROCESS_MODE_DISABLED
	if b.current_floor != f or not (b.floor_node is FloorBase):
		b.go_to_floor(f, "ascensor")
	await _secs(t, 0.8)  # el gestor censa el piso a los 0,3 s y deja de considerarlo «recién construido» a los 0,5
	var fl := b.floor_node as FloorBase
	var m := fl.get_node_or_null("ObjetosAnim") as ObjectAnim
	if m != null:
		m._scan_now()
	return fl


func _pl(t: Node) -> Player:
	return t.player() as Player


func _gestor(fl: Node) -> ObjectAnim:
	return fl.get_node_or_null("ObjetosAnim") as ObjectAnim


## Espera `s` segundos de juego contando deltas (no depende de timers ni de los fps).
func _secs(t: Node, s: float) -> void:
	var el := 0.0
	while el < s:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()


## Segundos que lleva corriendo el tween guardado en la meta `key` (−1 si no hay). Las horas se miden con el reloj del
## propio tween: un cuadro largo justo al pedirlo (cargar un sonido, crear la puerta) no desfasa la medida.
func _tw_s(n: Object, key: String) -> float:
	var tw: Variant = n.get_meta(key, null)
	return (tw as Tween).get_total_elapsed_time() if tw is Tween and (tw as Tween).is_valid() else -1.0


func _hoja(d: WorldObjects.Door) -> MeshInstance3D:
	return (d.leaf if d.leaf != null else d.get_node_or_null("Caja")) as MeshInstance3D


func _col_off(leaf: MeshInstance3D) -> bool:
	var col := leaf.get_node_or_null("Col")
	return col != null and (col as Node).process_mode == Node.PROCESS_MODE_DISABLED


func _copias(d: Node) -> int:
	var n := 0
	for c in d.get_children():
		if str(c.name).begins_with("GiroPuerta") and not c.is_queued_for_deletion():
			n += 1
	return n


func _ang(d: Node) -> float:
	return rad_to_deg(float((d.get_meta("oa_door", {}) as Dictionary).get("a", 0.0)))


# --- puertas ---------------------------------------------------------------------------------------------------------

func _puerta(t: Node) -> void:
	var fl := await _piso(t, 2)
	var bath := fl.find_child("Bano_bano_p2", true, false) as Node3D
	var d := bath.get_node("Puerta") as WorldObjects.Door
	var leaf := _hoja(d)
	if not t.check(d != null and leaf != null, "hay puerta de baño con su hoja en el piso 2"):
		return
	var out_s := -signf((d.global_transform.affine_inverse() * bath.global_position).z)
	_pl(t).teleport(d.global_transform * Vector3(0.1, -1.0, 1.1 * out_s), 0.0)
	await t.frames(2)
	var xf0 := leaf.transform
	var layers0 := leaf.layers
	t.check(leaf.get_node_or_null("Manija") != null, "la hoja tiene manija de palanca (la pone el gestor al censar)")
	# abrir: lo de siempre en el mismo instante + la copia que gira
	d.set_open(true)
	t.check(d.open and not leaf.visible and _col_off(leaf), "abrir: open, hoja oculta y colisión cortada en la misma llamada (como en v0.3.1)")
	t.check(_copias(d) == 1 and (d.get_node("GiroPuerta") as Node3D).visible, "aparece la copia que gira (GiroPuerta/Batiente)")
	var g := d.get_node("GiroPuerta/Batiente")
	t.check(g.find_children("*", "CollisionObject3D", true, false).is_empty(), "la copia no tiene colisión")
	var man := g.get_node_or_null("Manija") as Node3D
	var dip := 0.0
	var peak := 0.0
	var el := 0.0
	# la hoja y la manija se recorren a pasos fijos de 1/120 s (el muestreo por cuadro se salta la manija, que baja
	# 0,3 s, o el pico del giro cuando la máquina está cargada)
	var tws: Array = [(d.get_meta("oa_door", {}) as Dictionary).get("tw")]
	if man != null and man.has_meta("oa_manija"):
		tws.append(man.get_meta("oa_manija"))
	for tw in tws:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).pause()
	while el < 1.3:
		for tw in tws:
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).custom_step(1.0 / 120.0)
		el += 1.0 / 120.0
		if man != null:
			dip = maxf(dip, rad_to_deg(man.rotation.z))
		peak = maxf(peak, absf(_ang(d)))
	for tw in tws:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).play()
	await t.frames(2)
	var side := signf(_ang(d))
	t.check(absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 0.5, "llega a %.0f° (está en %.1f°)" % [ObjectAnim.DOOR_OPEN_DEG, _ang(d)])
	t.check(peak > ObjectAnim.DOOR_OPEN_DEG + 2.0 and peak < ObjectAnim.DOOR_OPEN_DEG + 8.0, "se pasa un poco y vuelve (pico %.1f°)" % peak)
	t.check(dip > 20.0 and man != null and absf(man.rotation.z) < 0.01, "la manija baja al abrir y vuelve (bajó %.0f°)" % dip)
	# se aleja de quien la abre: la punta libre de la hoja queda del lado contrario al jugador
	var tip: Vector3 = (g as Node3D).global_transform * Vector3(0.45, 0, 0)
	var pl_z := (d.global_transform.affine_inverse() * _pl(t).global_position).z
	var tip_z := (d.global_transform.affine_inverse() * tip).z
	t.check(signf(tip_z) == -signf(pl_z) and absf(tip_z) > 0.5, "gira alejándose del jugador (jugador z %.2f, punta z %.2f)" % [pl_z, tip_z])
	t.check(leaf.transform == xf0, "la hoja de verdad no se movió")
	# cerrar
	d.set_open(false)
	t.check(not d.open and leaf.visible and not _col_off(leaf), "cerrar: hoja visible y colisión de vuelta en la misma llamada")
	t.check(leaf.layers == 0, "mientras la copia vuelve, la hoja de verdad no se dibuja (capa 0)")
	await _secs(t, 0.7)
	t.check(leaf.layers == layers0 and not (d.get_node("GiroPuerta") as Node3D).visible and absf(_ang(d)) < 0.01, "al llegar: se dibuja la de verdad y la copia se guarda en 0°")
	# reabrir desde el otro lado: gira para el otro lado
	_pl(t).teleport(d.global_transform * Vector3(0.1, -1.0, -1.1 * out_s), 0.0)
	await t.frames(2)
	d.set_open(true)
	await _secs(t, 1.3)
	t.check(signf(_ang(d)) == -side and absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 0.5, "abierta desde el otro lado gira al revés (%.1f°)" % _ang(d))
	d.set_open(false)
	await _secs(t, 0.7)
	# 1000 veces: muchas a mitad de camino
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok_sync := true
	for i in 1000:
		d.set_open(not d.open)
		ok_sync = ok_sync and leaf.visible == (not d.open) and _col_off(leaf) == d.open
		if rng.randf() < 0.3:
			await t.get_tree().process_frame
		if rng.randf() < 0.03:
			await _secs(t, rng.randf_range(0.05, 0.6))
	t.check(ok_sync, "1000 aperturas/cierres: visible y colisión siempre al día en la misma llamada")
	if d.open:
		d.set_open(false)
	await _secs(t, 0.8)
	t.check(_copias(d) == 1, "1000 veces después sigue habiendo UNA copia (%d)" % _copias(d))
	t.check(absf(_ang(d)) < 0.01 and leaf.layers == layers0 and leaf.visible and leaf.transform == xf0 and not (d.get_node("GiroPuerta") as Node3D).visible, "… cerrada: copia en 0° guardada, hoja de verdad a la vista y en su sitio (sin deriva)")
	d.set_open(true)
	await _secs(t, 1.3)
	t.check(absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 0.5, "… y abierta llega a su ángulo exacto (%.2f°)" % _ang(d))
	d.set_open(false)
	await _secs(t, 0.7)
	# portazo: un perseguidor la cruza corriendo (como Pursuit._open_doors: abre a 1,8 m)
	_pl(t).teleport(d.global_transform * Vector3(0.0, -1.0, 8.0 * out_s), 0.0)
	var holder := Node3D.new()
	fl.add_child(holder)
	holder.global_position = d.global_transform * Vector3(0.0, -1.0, 4.5 * out_s)
	var r := CharacterRig.attach(holder, "shero", 2.2)
	r.play("sprint", true, 1.0, ["run", "walk"])
	var to: Vector3 = d.global_transform * Vector3(0.0, -1.0, -2.0 * out_s)
	var opened := false
	var peak2 := 0.0
	var t_peak := 0.0
	var t_open := 0.0
	el = 0.0
	while el < 2.6:
		var dt: float = t.get_process_delta_time()
		var dir := to - holder.global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			holder.global_position += dir.normalized() * 4.6 * dt
		if not opened and Vector2(holder.global_position.x - d.global_position.x, holder.global_position.z - d.global_position.z).length() < 1.8:
			opened = true
			t_open = el
			d.set_open(true)
			# el pico del portazo (104,6°) dura un instante: se recorre la animación a pasos fijos de 1/120 s en vez de
			# confiar en el muestreo por cuadro (con la máquina cargada un cuadro largo se lo saltaba)
			var twp := (d.get_meta("oa_door", {}) as Dictionary).get("tw") as Tween
			if twp != null and twp.is_valid():
				twp.pause()
				var e2 := 0.0
				while e2 < 0.6:
					var alive := twp.custom_step(1.0 / 120.0)
					e2 += 1.0 / 120.0
					if absf(_ang(d)) > peak2:
						peak2 = absf(_ang(d))
						t_peak = e2
					if not alive:
						break
				if twp.is_valid():
					twp.play()
		await t.get_tree().process_frame
		el += dt
	var st: Dictionary = d.get_meta("oa_door", {})
	t.check(opened and bool(st.get("slam", false)), "un perseguidor a 4,6 m/s la abre de un portazo (velocidad medida %.1f m/s)" % (r.animator._v if r.animator != null else -1.0))
	t.check(peak2 > 100.0 and t_peak < 0.3, "el portazo llega al tope en %.2f s, se pasa y rebota (pico %.1f°)" % [t_peak, peak2])
	t.check(absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 4.0, "y queda abierta contra el tope (%.1f°)" % _ang(d))
	holder.queue_free()
	# reaparecer a mitad de un giro: queda terminada
	d.set_open(false)
	await _secs(t, 0.7)
	_pl(t).teleport(d.global_transform * Vector3(0.1, -1.0, 1.1 * out_s), 0.0)
	await t.frames(2)
	d.set_open(true)
	await _secs(t, 0.2)
	t.check(absf(_ang(d)) > 2.0 and absf(_ang(d)) < 90.0, "a los 0,2 s va a mitad de camino (%.0f°)" % _ang(d))
	EventBus.respawned.emit("checkpoint")
	t.check(absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 0.01 and (d.get_node("GiroPuerta") as Node3D).visible, "reaparecer: la puerta que se estaba abriendo queda abierta del todo (%.1f°)" % _ang(d))
	d.set_open(false)
	await _secs(t, 0.1)
	EventBus.respawned.emit("checkpoint")
	t.check(leaf.layers == layers0 and not (d.get_node("GiroPuerta") as Node3D).visible and absf(_ang(d)) < 0.01, "reaparecer mientras se cerraba: cerrada del todo, con la hoja de verdad a la vista")
	await t.back_to_menu()


# --- casillero / refri -----------------------------------------------------------------------------------------------

func _casillero(t: Node) -> void:
	var fl := await _piso(t, 2)
	for pair in [["MiCasillero", "casillero"], ["Refri1", "refri"]]:
		var obj := fl.find_child(str(pair[0]), true, false) as Node3D
		if not t.check(obj != null, "hay %s en el piso 2" % pair[1]):
			continue
		_pl(t).teleport(obj.global_transform * Vector3(0, -0.9, 1.3), 0.0)
		await t.frames(2)
		WorldObjects.DoorSwing.swing(obj, _pl(t), 0.0, 1.0, 0.8)
		var pivot := obj.get_node_or_null("PuertaPivote") as Node3D
		if not t.check(pivot != null, "%s: la puerta tiene su pivote" % pair[1]):
			continue
		var rest: float = pivot.get_meta("oa_rest", 99.0)
		var luz := obj.get_node_or_null("LuzRefri") as OmniLight3D
		var a_045 := 0.0
		var a_max := 0.0
		var a_touch := 99.0
		var a_before := 0.0
		var luz_max := 0.0
		var el := 0.0
		while el < 2.4:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			var a := rad_to_deg(rest - pivot.rotation.y)
			var ts := _tw_s(obj, "oa_swing")
			a_max = maxf(a_max, a)
			if luz != null:
				luz_max = maxf(luz_max, luz.light_energy)
			if ts >= 0.0 and ts <= 0.5:
				a_045 = a
			if ts >= 0.0 and ts <= 0.97:
				a_before = a
			if ts >= 1.35 and a_touch > 90.0:
				a_touch = a
		t.check(a_045 > 92.0, "%s: a los 0,45-0,5 s ya está abierta (%.0f°), como antes" % [pair[1], a_045])
		t.check(a_before > 95.0, "%s: sigue abierta hasta la hora de cerrar (%.0f° a los 0,97 s)" % [pair[1], a_before])
		t.check(absf(a_touch) < 6.0, "%s: toca el marco a la hora de siempre, cierre + 0,35 s (%.1f° a los 1,35 s)" % [pair[1], a_touch])
		t.check(a_max > 100.5 and a_max < 112.0, "%s: se pasa un poco y vuelve (máx. %.1f°)" % [pair[1], a_max])
		t.check(is_equal_approx(pivot.rotation.y, rest), "%s: termina exactamente en su reposo" % pair[1])
		if luz != null:
			t.check(luz_max > 1.2 and luz.light_energy == 0.0, "refri: la luz de adentro prende al abrir (%.1f) y queda apagada" % luz_max)
		# 1000 pedidos, muchos a mitad de camino (el jugador insiste con [E])
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 1000:
			WorldObjects.DoorSwing.swing(obj, _pl(t), 0.0, rng.randf_range(0.3, 1.2), 0.8)
			if rng.randf() < 0.4:
				await t.get_tree().process_frame
			if rng.randf() < 0.02:
				await _secs(t, rng.randf_range(0.1, 0.5))
		await _secs(t, 2.4)
		t.check(is_equal_approx(pivot.rotation.y, rest), "%s: 1000 pedidos después la puerta está en su reposo exacto (desvío %.4f°; en v0.3.1 quedaba torcida)" % [pair[1], rad_to_deg(pivot.rotation.y - rest)])
		var pivots := 0
		for c in obj.get_children():
			if str(c.name).begins_with("PuertaPivote"):
				pivots += 1
		t.check(pivots == 1, "%s: un solo pivote (%d)" % [pair[1], pivots])
		# liviano: la curva de siempre, a las mismas horas, y también sin deriva
		GfxQuality.current = "liviano"
		WorldObjects.DoorSwing.swing(obj, _pl(t), 0.0, 1.0, 0.8)
		await _secs(t, 0.25)
		WorldObjects.DoorSwing.swing(obj, _pl(t), 0.0, 1.0, 0.8)
		var over := 0.0
		el = 0.0
		while el < 2.2:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			over = maxf(over, rad_to_deg(rest - pivot.rotation.y))
		t.check(over <= 100.01 and over > 99.0 and is_equal_approx(pivot.rotation.y, rest), "%s en Modo liviano: seno hasta 100° sin pasarse (%.2f°) y vuelve a su reposo, aun pedida dos veces" % [pair[1], over])
		GfxQuality.current = "media"
	await t.back_to_menu()


# --- ascensor --------------------------------------------------------------------------------------------------------

func _ascensor(t: Node) -> void:
	var fl := await _piso(t, 2)
	var el_n := fl.find_child("Elevator", true, false) as Node3D
	if not t.check(el_n != null, "hay ascensor en el piso 2"):
		return
	var l := el_n.get("_leaf_l") as Node3D
	var r := el_n.get("_leaf_r") as Node3D
	var secs := float(el_n.get("DOOR_SECONDS"))
	el_n.call("set_doors", true, true)
	await t.frames(2)
	t.check(is_equal_approx(l.position.x, -1.55) and is_equal_approx(r.position.x, 1.55), "abiertas al instante: −1,55 / 1,55")
	for open in [false, true]:
		var x0 := l.position.x
		var x1 := -1.55 if open else -0.5
		el_n.call("set_doors", open)
		var worst := 0.0
		var sym := 0.0
		var el := 0.0
		var extra := 0.0
		while el < secs + 0.6:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			sym = maxf(sym, absf(l.position.x + r.position.x))
			var ts := _tw_s(el_n, "oa_puertas")
			if ts >= 0.0 and ts <= secs:
				# curva vieja: seno de entrada y salida durante `secs`
				var u := clampf(ts / secs, 0.0, 1.0)
				var want := lerpf(x0, x1, 0.5 - 0.5 * cos(u * PI))
				worst = maxf(worst, absf(l.position.x - want))
			elif ts > secs or ts < 0.0:
				extra = maxf(extra, absf(l.position.x - x1))
		t.check(worst < 0.004, "%s: durante el recorrido las hojas van por la curva de siempre (desvío máx. %.1f mm)" % ["abrir" if open else "cerrar", worst * 1000.0])
		t.check(sym < 0.0001, "%s: las dos hojas van espejadas" % ("abrir" if open else "cerrar"))
		if open:
			t.check(extra < 0.0005, "abrir: al llegar no hay nada más (%.1f mm)" % (extra * 1000.0))
		else:
			t.check(extra > 0.006 and extra < 0.0125, "cerrar: después de llegar, las gomas rebotan ~1 cm (%.1f mm)" % (extra * 1000.0))
		t.check(is_equal_approx(l.position.x, x1) and is_equal_approx(r.position.x, -x1), "%s: terminan exactamente en su tope" % ("abrir" if open else "cerrar"))
	# 1000 órdenes seguidas (algunas instantáneas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var last := true
	for i in 1000:
		last = rng.randf() < 0.5
		el_n.call("set_doors", last, rng.randf() < 0.1)
		if rng.randf() < 0.3:
			await t.get_tree().process_frame
	await _secs(t, secs + 0.5)
	var xl := -1.55 if last else -0.5
	t.check(is_equal_approx(l.position.x, xl) and is_equal_approx(r.position.x, -xl), "1000 órdenes después: hojas en el tope exacto de la última (%.4f / %.4f)" % [l.position.x, r.position.x])
	el_n.call("set_doors", false)
	await _secs(t, 0.3)
	el_n.call("set_doors", true, true)
	await _secs(t, secs + 0.5)
	t.check(is_equal_approx(l.position.x, -1.55), "una orden instantánea corta el recorrido en curso (antes el tween viejo la pisaba): %.3f" % l.position.x)
	# indicador
	var ind := el_n.get("_indicator_in") as Label3D
	var ind_out := el_n.get("_indicator_out") as Label3D
	el_n.call("show_floor", 2)
	await _secs(t, 1.5)
	var pos0 := ind.position
	var col0 := ind.modulate
	el_n.call("show_floor", 9)
	t.check(ind.text == "9" and ind_out.text == "9", "el indicador cambia el texto en el acto (dentro y fuera)")
	var fle := ind.get_node_or_null("Flecha") as Node3D
	t.check(fle != null and fle.visible and absf(fle.rotation.z) < 0.01, "sube: flecha hacia arriba")
	t.check(ind.position.y < pos0.y - 0.02, "el número nuevo entra desde abajo (rueda)")
	await _secs(t, 0.4)
	t.check(ind.position.is_equal_approx(pos0) and ind.modulate.is_equal_approx(col0), "y queda en su sitio y con su color")
	el_n.call("show_floor", -1)
	t.check(ind.text == "S" and fle != null and absf(absf(fle.rotation.z) - PI) < 0.01, "baja al sótano: «S» y flecha hacia abajo")
	await _secs(t, 1.6)
	t.check(fle != null and not fle.visible and ind.position.is_equal_approx(pos0), "terminó el viaje: la flecha se apaga")
	for i in 300:
		el_n.call("show_floor", [1, 2, 9, -1][i % 4])
		if i % 3 == 0:
			await t.get_tree().process_frame
	await _secs(t, 1.6)
	t.check(ind.position.is_equal_approx(pos0) and ind.modulate.is_equal_approx(col0) and ind.text == "S", "300 cambios después: en su sitio, con su color, texto «%s»" % ind.text)
	GfxQuality.current = "liviano"
	el_n.call("show_floor", 2)
	t.check(ind.text == "2" and ind.position.is_equal_approx(pos0), "Modo liviano: solo cambia el texto")
	el_n.call("set_doors", false)
	var bounce := 0.0
	var el2 := 0.0
	while el2 < secs + 0.5:
		await t.get_tree().process_frame
		el2 += t.get_process_delta_time()
		# «después del recorrido» según el reloj del propio tween (−1 = ya terminó): contando cuadros, a 15 fps el
		# recorrido todavía no había acabado cuando la prueba creía que sí
		var ts2 := _tw_s(el_n, "oa_puertas")
		if ts2 < 0.0 or ts2 > secs + 0.001:
			bounce = maxf(bounce, absf(l.position.x + 0.5))
	t.check(bounce < 0.0005, "Modo liviano: cerrar sin rebote de gomas")
	GfxQuality.current = "media"
	el_n.call("set_doors", true, true)
	await t.back_to_menu()


# --- monitores -------------------------------------------------------------------------------------------------------

func _monitor(t: Node) -> void:
	var fl := await _piso(t, 2)
	await t.login_at_seat()
	await _secs(t, 0.6)
	var scr: MonitorScreen = null
	for sc in t.get_tree().get_nodes_in_group("monitor_screens"):
		if sc is MonitorScreen and (sc as MonitorScreen).seat_id == "C-14" and fl.is_ancestor_of(sc):
			scr = sc
			break
	if not t.check(scr != null, "hay pantalla viva en C-14"):
		return
	var quad := scr.get("_quad") as MeshInstance3D
	var on_mat := scr.get("_on_mat") as StandardMaterial3D
	var off_mat := scr.get("_off_mat") as StandardMaterial3D
	var glow := scr.get("_glow") as OmniLight3D
	var gcol := glow.light_color
	var dark := off_mat.albedo_color
	scr.set_powered(false)
	t.check(quad.material_override == off_mat and not glow.visible and not scr.powered, "apagar: material y luz cambian en el acto (como antes)")
	t.check(off_mat.albedo_color.r > dark.r + 0.05, "el vidrio conserva un resplandor al apagarse")
	await _secs(t, 0.5)
	t.check(off_mat.albedo_color.is_equal_approx(dark), "… que se va y queda en su oscuro de siempre")
	scr.set_powered(true)
	t.check(quad.material_override == on_mat and glow.visible and scr.powered, "encender: material y luz cambian en el acto")
	# el parpadeo dura 0,33 s con escalones de 0,05 s: se recorre el tween a pasos fijos de 1/120 s (muestreado por
	# cuadro, con la máquina cargada, un cuadro largo se saltaba la caída)
	var lo := 1.0
	var steps := 0
	var prev := -1.0
	var twm: Tween = (scr.get_meta("oa_mon") as Tween) if scr.has_meta("oa_mon") else null
	if t.check(twm != null and twm.is_valid(), "encender arranca la animación de despertar"):
		twm.pause()
		var el := 0.0
		while el < 0.6:
			var alive := twm.custom_step(1.0 / 120.0)
			el += 1.0 / 120.0
			lo = minf(lo, on_mat.albedo_color.r)
			if prev >= 0.0 and on_mat.albedo_color.r < prev - 0.05:
				steps += 1
			prev = on_mat.albedo_color.r
			if not alive:
				break
		if twm.is_valid():
			twm.play()
	await t.frames(2)
	t.check(lo < 0.5 and steps >= 1, "la retroiluminación parpadea al despertar (bajó a %.2f, %d caídas)" % [lo, steps])
	t.check(on_mat.albedo_color == Color(1, 1, 1) and glow.light_color.is_equal_approx(gcol), "y queda en blanco puro (la textura de la PC tal cual) con su luz azul")
	for i in 1000:
		scr.set_powered(i % 2 == 0)
		if i % 4 == 0:
			await t.get_tree().process_frame
	scr.set_powered(false)
	await _secs(t, 0.5)
	scr.set_powered(true)
	await _secs(t, 0.6)
	t.check(on_mat.albedo_color == Color(1, 1, 1) and off_mat.albedo_color.is_equal_approx(dark) and glow.light_color.is_equal_approx(gcol), "1000 veces después: blanco puro, vidrio oscuro y luz en su color")
	# un reflejo en la pantalla apagada manda sobre el resplandor
	scr.set_powered(false)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	scr.show_reflection(ImageTexture.create_from_image(img), 0.6)
	await _secs(t, 0.2)
	t.check(off_mat.albedo_color.is_equal_approx(Color(0.75, 0.85, 1.0)), "con un reflejo en pantalla el resplandor no lo pisa")
	await _secs(t, 0.8)
	t.check(off_mat.albedo_texture == null and off_mat.albedo_color.is_equal_approx(dark), "y al terminar el reflejo el vidrio vuelve a su oscuro")
	scr.set_powered(true)
	await t.back_to_menu()


# --- sillas ----------------------------------------------------------------------------------------------------------

func _estado_silla(rec: Dictionary) -> Array:
	return rec.get("a", [0.0, 0.0, 0.0])


## Recorre la animación en curso de una silla a pasos fijos de 1/60 s y devuelve [hundimiento mínimo (m), segundo de la
## animación en que ocurre]. No depende de los cuadros reales: con la máquina cargada un cuadro largo se salta el
## hundimiento (dura 0,15 s) y la prueba fallaba por muestreo, no por la silla.
func _silla_a_pasos(rec: Dictionary, secs: float) -> Array:
	var tw := rec.get("tw") as Tween
	if tw == null or not tw.is_valid():
		return [0.0, 0.0]
	tw.pause()
	var dip := 0.0
	var at := 0.0
	var el := 0.0
	while el < secs:
		var alive := tw.custom_step(1.0 / 60.0)
		el += 1.0 / 60.0
		var d := float(_estado_silla(rec)[2])
		if d < dip:
			dip = d
			at = tw.get_total_elapsed_time()  # el reloj de la propia animación (ya había avanzado algún cuadro)
		if not alive:
			break
	if tw.is_valid():
		tw.play()
	return [dip, at]


func _en_reposo(rec: Dictionary) -> bool:
	var parts: Array = rec["parts"]
	var rest: Array = rec["rest"]
	for i in parts.size():
		if not (parts[i] as Node3D).transform.is_equal_approx(rest[i] as Transform3D):
			return false
	return true


func _sillas(t: Node) -> void:
	var fl := await _piso(t, 2)
	var m := _gestor(fl)
	if not t.check(m != null and m._chairs.size() > 20, "el gestor censó las sillas del piso 2 (%d)" % (m._chairs.size() if m != null else 0)):
		return
	# un compañero sentado en la fila C
	var who: NpcAnimator = null
	for a in NpcAnimator._all:
		if is_instance_valid(a) and a.slug.begins_with("agente_") and a.state == "seated" and a.body != null and a.body.is_inside_tree() and fl.is_ancestor_of(a.body):
			who = a
			break
	if not t.check(who != null, "hay un compañero sentado"):
		return
	var rec := m._chair_near(who.body.global_position)
	if not t.check(not rec.is_empty(), "su silla está censada (a %.2f m)" % 0.0):
		return
	var root := rec["root"] as Node3D
	var names: Array = []
	for p in rec["parts"]:
		names.append([str((p as Node).name), (p as Node).get_parent()])
	_pl(t).teleport(who.body.global_position + Vector3(0, 0, 3.0), 180.0)
	await t.frames(3)
	var rig := who.body as CharacterRig
	rig.play("idle")
	var el := 0.0
	var dip_min := 0.0
	var started: bool = await t.until(func() -> bool: return m._chair_busy(rec), 3.0)  # la silla arranca cuando el clip stand_up arranca
	t.check(started, "al pararse el compañero la silla empieza a moverse")
	dip_min = float(_silla_a_pasos(rec, 3.4)[0])
	await _secs(t, 3.4)
	var a: Array = _estado_silla(rec)
	t.check(absf(float(a[1]) - 0.4) < 0.01 and absf(absf(rad_to_deg(float(a[0]))) - 13.0) < 0.3, "se para: la silla rueda 0,40 m hacia atrás y gira 13° (está en %.2f m, %.1f°)" % [a[1], rad_to_deg(float(a[0]))])
	t.check(dip_min < -0.004, "al empujarse para pararse el asiento se aplasta (%.1f mm)" % (dip_min * 1000.0))
	# la silla quedó DETRÁS del que se paró (no metida en él)
	var seat := rec["parts"][0] as Node3D
	var fwd := -who.body.global_transform.basis.z
	var rel := seat.global_position - who.body.global_position
	t.check(Vector2(rel.x, rel.z).dot(Vector2(fwd.x, fwd.z)) < -0.3, "queda detrás del que se paró (%.2f m)" % Vector2(rel.x, rel.z).dot(Vector2(fwd.x, fwd.z)))
	rig.play("type", true, 0.9, ["sit", "idle"])
	started = await t.until(func() -> bool: return m._chair_busy(rec), 3.0)  # arranca con el clip sit_down
	var sd: Array = _silla_a_pasos(rec, 3.2)
	dip_min = float(sd[0])
	var t_dip := float(sd[1])
	await _secs(t, 3.2)
	t.check(started and _en_reposo(rec), "se sienta: la silla vuelve EXACTAMENTE a su sitio")
	t.check(dip_min < -0.012 and t_dip > 0.85 and t_dip < 1.25, "se hunde al recibir el peso (%.0f mm a los %.2f s de la animación: cuando la cadera llega al asiento, 0,9 s)" % [dip_min * 1000.0, t_dip])
	var same := true
	for i in names.size():
		same = same and str((rec["parts"][i] as Node).name) == names[i][0] and (rec["parts"][i] as Node).get_parent() == names[i][1]
	t.check(same, "las piezas conservan nombre y padre (kills busca «Silla»/«Respaldo» por nombre)")
	# 300 veces seguidas (órdenes a mitad de camino)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		m._chair_play(rec, ["sit", "stand", "sit_player", "stand_player"][rng.randi() % 4])
		if rng.randf() < 0.5:
			await t.get_tree().process_frame
	m._chair_play(rec, "sit")
	await _secs(t, 2.6)
	t.check(_en_reposo(rec), "300 órdenes después, sentada: reposo exacto (sin deriva)")
	# aparece alguien sentado donde va una silla corrida: vuelve sola
	m._chair_play(rec, "stand")
	await _secs(t, 2.0)
	t.check(not _en_reposo(rec), "corrida de nuevo (rodando)")
	await _secs(t, 1.3)
	t.check(_en_reposo(rec), "con alguien sentado en ese sitio la silla corrida vuelve sola en cuanto frena (el guion lo sentó sin clip)")
	# el jugador
	var seat_c14 := fl.seat_by_id("C-14")
	var p := _pl(t)
	if p.seated:
		p.stand_up()
		await _secs(t, 3.0)
	p.sit_at(seat_c14, "C-14")
	var prec := m._player_chair
	if t.check(not prec.is_empty(), "el jugador se sienta en C-14: su silla está censada"):
		dip_min = float(_silla_a_pasos(prec, 0.5)[0])
		t.check(dip_min < -0.012, "se hunde y se mece al sentarte (%.0f mm)" % (dip_min * 1000.0))
		await _secs(t, 2.4)
		t.check(_en_reposo(prec), "y queda en su sitio exacto")
		p.stand_up()
		await _secs(t, 3.0)
		var pa: Array = _estado_silla(prec)
		t.check(absf(float(pa[1]) - 0.3) < 0.01, "te parás: rueda 0,30 m hacia atrás (%.2f)" % pa[1])
		p.sit_at(seat_c14, "C-14")
		await _secs(t, 2.8)
		t.check(_en_reposo(prec), "te sentás otra vez: vuelve a su sitio")
	await t.back_to_menu()


# --- expendedora -----------------------------------------------------------------------------------------------------

func _expendedora(t: Node) -> void:
	var fl := await _piso(t, -1)
	var v := fl.find_child("Expendedora", true, false) as Node3D
	if not t.check(v != null, "hay expendedora en el -1"):
		return
	var n0 := v.get_child_count()
	_pl(t).teleport(v.global_transform * Vector3(-1.5, -1.0, 0.0), 0.0)
	await t.frames(2)
	ObjectAnim.vend(v, _pl(t), "energetica")
	var root := v.get_node_or_null("CaidaLata") as Node3D
	if t.check(root != null, "cae la lata (nodo temporal CaidaLata)"):
		var can := root.get_node("Lata") as Node3D
		var y0 := can.position.y
		t.check(root.find_children("*", "CollisionObject3D", true, false).is_empty(), "sin colisión")
		# del lado del jugador
		var lp := v.global_transform.affine_inverse() * _pl(t).global_position
		t.check(signf(root.position.x) == signf(lp.x) and absf(root.position.x) > 0.4, "sale por la cara que mira al jugador")
		await _secs(t, 1.3)
		t.check(can.position.y < y0 - 0.5, "la lata cayó a la bandeja (%.2f m)" % (y0 - can.position.y))
	await _secs(t, 3.2)
	t.check(v.get_node_or_null("CaidaLata") == null and v.get_child_count() == n0, "y todo lo temporal se borra solo (hijos %d = %d)" % [v.get_child_count(), n0])
	for i in 60:
		ObjectAnim.vend(v, _pl(t))
		if i % 5 == 0:
			await t.get_tree().process_frame
	await _secs(t, 4.6)
	t.check(v.get_child_count() == n0, "60 compras seguidas: sin fugas (hijos %d = %d)" % [v.get_child_count(), n0])
	# por el camino real: la compra (con economía) dispara la caída
	EventBus.shop_bought.emit("expendedora", "cafe", 2.5)
	await t.frames(1)
	t.check(v.get_node_or_null("CaidaLata") != null, "EventBus.shop_bought(\"expendedora\") hace caer el producto")
	await _secs(t, 4.6)
	await t.back_to_menu()


# --- microondas ------------------------------------------------------------------------------------------------------

func _microondas(t: Node) -> void:
	var fl := await _piso(t, -1)
	var bank := fl.find_child("EstacionMicroondas", true, false) as Node3D
	if not t.check(bank != null, "hay estación de microondas en el -1"):
		return
	var m := _gestor(fl)
	var mw: WorldObjects.Microwave = null
	for c in bank.get_children():
		if c is WorldObjects.Microwave:
			mw = c
			break
	_pl(t).teleport(bank.global_transform * Vector3(0.0, 0.0, 1.5), 0.0)
	await t.frames(3)
	t.check(m._mws.size() == 6, "el gestor conoce los 6 microondas (%d)" % m._mws.size())
	var glass := mw.get_node("Vidrio") as MeshInstance3D
	mw.set_state("libre")
	await _secs(t, 0.3)
	var mat0 := glass.material_override
	var layers0 := glass.layers
	mw.set_state("ocupado", GameState.clock_seconds + 3600.0, "T-08")
	await _secs(t, 0.4)
	var lit := glass.material_override as StandardMaterial3D
	t.check(lit != mat0 and lit != null and lit.emission_enabled and lit.emission_energy_multiplier > 0.3, "calentando: el vidrio se ilumina por dentro")
	var sil := glass.get_node_or_null("SombraPlato") as Node3D
	var sx0 := sil.scale.x if sil != null else 0.0
	# la sombra gira (su ancho oscila): se mira cuánto llegó a cambiar en 1,2 s, no solo el último cuadro (si las dos
	# muestras caían en el mismo punto del giro, la prueba fallaba sin motivo)
	var turn := 0.0
	var elp := 0.0
	while elp < 1.2:
		await t.get_tree().process_frame
		elp += t.get_process_delta_time()
		if sil != null:
			turn = maxf(turn, absf(sil.scale.x - sx0))
	t.check(sil != null and sil.visible and turn > 0.01, "y la sombra del táper gira en el plato (su ancho cambia %.3f)" % turn)
	mw.set_state("libre")
	await _secs(t, 0.3)
	t.check(glass.material_override == mat0 and sil != null and not sil.visible, "termina: vuelve el vidrio de siempre")
	# el jugador mete su táper: la puerta abre y cierra
	mw.set_state("mio_calentando", GameState.clock_seconds + 3600.0, "JIROSHI")
	await _secs(t, 0.6)
	var pv := mw.get_node_or_null("PuertaMwGiro") as Node3D
	t.check(pv != null and pv.visible and glass.layers == 0 and rad_to_deg(pv.rotation.y) < -60.0, "metés el táper: la puerta de vidrio se abre (%.0f°) y el vidrio de verdad no se dibuja" % (rad_to_deg(pv.rotation.y) if pv != null else 0.0))
	t.check(mw.get_node("Vidrio") == glass and glass.visible, "el nodo «Vidrio» sigue en su sitio y visible (solo cambia de capa)")
	await _secs(t, 2.0)
	t.check(pv != null and not pv.visible and glass.layers == layers0, "a los 2,6 s está cerrada y el vidrio de verdad se dibuja")
	# lo saca
	mw.set_state("mio_listo")
	await _secs(t, 0.3)
	mw.set_state("libre")
	await _secs(t, 0.5)
	t.check(pv.visible and glass.layers == 0, "sacás el táper: se abre otra vez")
	EventBus.respawned.emit("checkpoint")
	t.check(not pv.visible and glass.layers == layers0 and is_zero_approx(pv.rotation.y), "reaparecer con la puerta abierta: queda cerrada")
	for i in 200:
		mw.set_state(["libre", "mio_calentando", "mio_listo", "ocupado"][i % 4], GameState.clock_seconds + 3600.0, "X")
		await t.get_tree().process_frame
	mw.set_state("libre")
	await _secs(t, 2.6)
	var pvs := 0
	for c in mw.get_children():
		if str(c.name).begins_with("PuertaMwGiro"):
			pvs += 1
	t.check(pvs == 1 and glass.layers == layers0 and glass.material_override == mat0 and not pv.visible, "200 cambios de estado después: una sola puerta, cerrada, vidrio original a la vista")
	TaperFlow_reset()
	await t.back_to_menu()


func TaperFlow_reset() -> void:
	GameState.flags.erase("taper_mw")
	GameState.flags.erase("taper_mw_hasta")


# --- papeles, reloj, taza --------------------------------------------------------------------------------------------

func _ambiente(t: Node) -> void:
	var fl := await _piso(t, 2)
	var m := _gestor(fl)
	if not t.check(m != null and m._flutter.size() > 5, "el gestor censó papeles (%d)" % (m._flutter.size() if m != null else 0)):
		return
	# papeles: cerca se mueven, lejos vuelven a su reposo exacto
	var it: Dictionary = m._flutter[0]
	for f in m._flutter:
		if str((f["n"] as Node).name) == "HojaColgando":
			it = f
	var n := it["n"] as Node3D
	# El gestor mide desde la CÁMARA: se usa una cámara propia (cerca y después a 25 m) sin mover al jugador (antes se
	# lo teletransportaba delante del papel y 25 m al costado: los dos puntos caían fuera del piso y lo rescataba la red).
	var cam: Camera3D = t.get_viewport().get_camera_3d()
	var far_cam := Camera3D.new()
	fl.add_child(far_cam)
	far_cam.global_position = n.global_position + Vector3(0.0, 0.1, 1.6)  # mira a −Z: el papel delante
	far_cam.make_current()
	await _secs(t, 0.3)
	t.note("papel %s a %.1f m de la cámara" % [n.name, far_cam.global_position.distance_to(n.global_position)])
	var moved := 0.0
	var el := 0.0
	while el < 2.0:
		await t.get_tree().process_frame
		el += t.get_process_delta_time()
		moved = maxf(moved, n.transform.basis.get_rotation_quaternion().angle_to((it["rest"] as Transform3D).basis.get_rotation_quaternion()))
	t.check(moved > deg_to_rad(0.5) and moved < deg_to_rad(12.0), "cerca de la cámara el papel se mueve con el aire (%.1f°)" % rad_to_deg(moved))
	far_cam.global_position = n.global_position + Vector3(25.0, 0.4, 0.0)
	await _secs(t, 0.4)
	t.check(t.get_viewport().get_camera_3d() == far_cam and _pl(t).fall_rescues == 0, "la cámara se alejó 25 m del papel (y el jugador no se movió ni se cayó del piso)")
	t.check(n.transform.is_equal_approx(it["rest"] as Transform3D) and not bool(it["live"]), "lejos vuelve a su reposo exacto y deja de calcularse")
	var live := 0
	for f in m._flutter:
		if bool(f["live"]):
			live += 1
	t.check(live <= ObjectAnim.FLUTTER_MAX, "como mucho %d papeles vivos a la vez (%d)" % [ObjectAnim.FLUTTER_MAX, live])
	far_cam.queue_free()
	cam.make_current()
	await t.frames(2)
	# reloj de pared: el punto late; con la hora congelada se queda fijo
	var wc := fl.find_child("RelojPared", true, false) as WorldObjects.WallClock
	if t.check(wc != null and wc.get_node_or_null("PuntoSegundos") != null, "el reloj de pared tiene su punto de segundos"):
		var dot := wc.get_node("PuntoSegundos") as Node3D
		t.check(wc.label.text == GameState.clock_text(), "el reloj muestra la hora del juego (%s)" % wc.label.text)
		var seen := {}
		el = 0.0
		while el < 2.2:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			seen[dot.visible] = true
		t.check(seen.size() == 2, "el punto late (encendido y apagado en 2 s)")
		wc.frozen_text = "3:47 AM"
		seen = {}
		await _secs(t, 0.6)
		el = 0.0
		while el < 2.2:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			seen[dot.visible] = true
		t.check(seen.size() == 1 and dot.visible, "con la hora congelada (3:47) el punto se queda fijo: el reloj está muerto")
		wc.frozen_text = ""
	# la taza de C-13
	var mug := (fl.find_child("Cub_C-13", true, false) as Node3D).get_node_or_null("Taza") as Node3D
	if t.check(mug != null and m._mugs.has(mug), "la taza de C-13 está censada"):
		GameState.clock_seconds = 6.0 * 60.0
		_pl(t).teleport(Vector3(mug.global_position.x, fl.global_position.y, mug.global_position.z + 1.6), 0.0)
		await _secs(t, 0.8)
		var v := mug.get_node_or_null("Vapor") as CPUParticles3D
		t.check(v != null and v.emitting, "00:06, de cerca: la taza humea (alguien acaba de estar)")
		t.check(v != null and v.amount <= 8 and ((v.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a <= ObjectAnim.STEAM_ALPHA + 0.001 and ObjectAnim.STEAM_ALPHA < 0.2 and ((v.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture != null, "muy sutil: %d hilos de bordes blandos, casi transparentes (centro %.2f)" % [v.amount if v != null else 0, ObjectAnim.STEAM_ALPHA])
		t.check(is_equal_approx(ObjectAnim.mug_heat(), 1.0), "calor 1,0 al empezar el turno")
		GameState.clock_seconds = 70.0 * 60.0
		await _secs(t, 0.6)
		var a_mid := ((v.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a
		t.check(v.emitting and ObjectAnim.mug_heat() < 0.75 and ObjectAnim.mug_heat() > 0.2 and a_mid < ObjectAnim.STEAM_ALPHA * 0.75, "01:10: se va enfriando (calor %.2f, más tenue)" % ObjectAnim.mug_heat())
		GameState.clock_seconds = 2.0 * 3600.0
		await _secs(t, 0.6)
		t.check(not v.emitting and is_zero_approx(ObjectAnim.mug_heat()), "02:00: ya no humea (se enfrió sola)")
		GameState.clock_seconds = 6.0 * 60.0
		_pl(t).teleport(Vector3(mug.global_position.x - 20.0, fl.global_position.y, mug.global_position.z + 6.0), 0.0)
		await _secs(t, 0.6)
		t.check(not v.emitting, "de lejos no emite (aunque esté caliente)")
	await t.back_to_menu()


# --- golpe en la mesa ------------------------------------------------------------------------------------------------

## Recorre el tween del salto de una cosa de mesa (meta "oa_settle") a pasos de 1/120 s y lo deja seguir.
## Devuelve [altura máxima sobre su reposo (m), giro máximo (rad)].
func _salto(n: Node3D, rest: Transform3D) -> Array:
	var up := 0.0
	var rot := 0.0
	var tw: Tween = (n.get_meta("oa_settle") as Tween) if n.has_meta("oa_settle") else null
	if tw == null or not tw.is_valid():
		return [up, rot]
	tw.pause()
	var e := 0.0
	while e < 1.5:
		var alive := tw.custom_step(1.0 / 120.0)
		e += 1.0 / 120.0
		up = maxf(up, n.position.y - rest.origin.y)
		rot = maxf(rot, n.transform.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()))
		if not alive:
			break
	if tw.is_valid():
		tw.play()
	return [up, rot]


func _golpe(t: Node) -> void:
	var fl := await _piso(t, 2)
	var m := _gestor(fl)
	var tel := fl.find_child("TelefonoAuricular", true, false) as MeshInstance3D
	if not t.check(tel != null and m._props.has(tel), "el auricular del teléfono de QA está censado"):
		return
	t.check(tel.get_node_or_null("Cordon0") != null, "tiene su cordón en espiral")
	var rest := tel.transform
	_pl(t).teleport(tel.global_position + Vector3(2.0, -tel.global_position.y + fl.global_position.y, 0.0), 0.0)
	await t.frames(2)
	var hit := ObjectAnim.jolt(tel.global_position, 1.2, 1.3)
	t.check(hit >= 1, "un golpe en la mesa alcanza %d cosas" % hit)
	# el salto dura unas décimas: se recorre su tween a pasos fijos de 1/120 s (muestreado por cuadro, con cuadros
	# largos —ventana virtual, máquina cargada— el pico se perdía)
	var j: Array = _salto(tel, rest)
	var up: float = j[0]
	var rot: float = j[1]
	t.check(up > 0.006 and up < 0.03 and rot > deg_to_rad(0.5), "el auricular salta %.0f mm y tintinea (%.1f°)" % [up * 1000.0, rad_to_deg(rot)])
	await _secs(t, 0.4)
	t.check(tel.transform == rest, "y vuelve a su sitio exacto")
	for i in 500:
		ObjectAnim.jolt(tel.global_position, 1.2, 1.0 + (i % 3) * 0.3)
		if i % 2 == 0:
			await t.get_tree().process_frame
	await _secs(t, 0.8)
	t.check(tel.transform == rest, "500 golpes después: en su sitio exacto (sin deriva)")
	# por el camino real: Haime se viene encima de la mesa
	var ha: NpcAnimator = null
	for a in NpcAnimator._all:
		if is_instance_valid(a) and a.slug == "haime" and a.body != null and a.body.is_inside_tree() and fl.is_ancestor_of(a.body):
			ha = a
	if ha != null and ha.state == "seated":
		t.note("Haime a %.2f m del auricular" % ha.body.global_position.distance_to(tel.global_position))
		_pl(t).teleport(ha.body.global_position + Vector3(2.5, 0, 0.5), 0.0)
		await t.frames(3)
		(ha.body as Object).call("play", "haime_lean")
		# el golpe lo dispara el animador a mitad del gesto: se espera (por condición) a que el salto del auricular exista.
		# Cuánto salta ya se midió arriba paso a paso; acá el salto empezó un cuadro antes de que la prueba lo vea, así que
		# la altura que queda por recorrer depende de los fps y solo se anota.
		var llego: bool = await t.until(func() -> bool: return _tw_s(tel, "oa_settle") >= 0.0, 3.0)
		up = (_salto(tel, rest)[0] as float) if llego else 0.0
		t.note("haime_lean: al auricular le quedaban %.1f mm de salto cuando la prueba lo vio" % (up * 1000.0))
		t.check(llego, "Haime se viene encima de la mesa (haime_lean): el golpe del gesto hace saltar el auricular")
		await _secs(t, 0.6)
		t.check(tel.transform == rest, "y vuelve")
	else:
		t.note("Haime no está sentado en su escritorio ahora: no se prueba el camino real")
	await t.back_to_menu()


# --- Modo liviano ----------------------------------------------------------------------------------------------------

func _liviano(t: Node) -> void:
	if t.building() == null:
		await t.start_shift("Jiroshi", 1)
	GfxQuality.current = "liviano"
	var b: Building = t.building()
	b.go_to_floor(1, "ascensor")
	await _secs(t, 0.3)
	b.go_to_floor(2, "ascensor")
	await _secs(t, 1.2)
	GfxQuality.current = "liviano"
	var fl := b.floor_node as FloorBase
	var m := _gestor(fl)
	t.check(m != null and not ObjectAnim.on(), "en Modo liviano ObjectAnim.on() es falso")
	t.check(m._chairs.is_empty() and m._flutter.is_empty() and m._mugs.is_empty() and not m._scanned, "el gestor ni censa el piso (sillas %d, papeles %d)" % [m._chairs.size(), m._flutter.size()])
	t.check(not t.get_tree().node_added.is_connected(m._on_node_added), "ni escucha los nodos nuevos")
	var bath := fl.find_child("Bano_bano_p2", true, false) as Node3D
	var d := bath.get_node("Puerta") as WorldObjects.Door
	var leaf := _hoja(d)
	t.check(leaf.get_node_or_null("Manija") == null, "sin manija añadida")
	_pl(t).teleport(d.global_transform * Vector3(0.1, -1.0, 1.1), 0.0)
	await t.frames(2)
	d.set_open(true)
	t.check(d.open and not leaf.visible and _col_off(leaf) and _copias(d) == 0 and leaf.layers != 0, "puerta: desaparece como en v0.3.1, sin copia")
	d.set_open(false)
	t.check(leaf.visible and not _col_off(leaf) and leaf.layers != 0, "y reaparece al cerrar")
	var mug := (fl.find_child("Cub_C-13", true, false) as Node3D).get_node_or_null("Taza") as Node3D
	_pl(t).teleport(Vector3(mug.global_position.x, fl.global_position.y, mug.global_position.z + 1.5), 0.0)
	GameState.clock_seconds = 300.0
	await _secs(t, 0.8)
	t.check(mug.get_node_or_null("Vapor") == null, "la taza no humea")
	var wc := fl.find_child("RelojPared", true, false) as Node3D
	t.check(wc.get_node_or_null("PuntoSegundos") == null, "el reloj no tiene punto")
	ObjectAnim.chair_event(Vector3(38.15, 0, -10.65), "stand")
	t.check(ObjectAnim.jolt(Vector3(10, 0.85, 2.3), 2.0, 1.0) == 0, "un golpe no mueve nada")
	ObjectAnim.prof_on = true
	ObjectAnim.prof_usec = 0
	ObjectAnim.prof_frames = 0
	await _secs(t, 1.0)
	ObjectAnim.prof_on = false
	t.check(ObjectAnim.prof_frames == 0, "el gestor no gasta nada por cuadro (%d cuadros medidos)" % ObjectAnim.prof_frames)
	# pasar a liviano a mitad de partida lo recoge todo
	GfxQuality.current = "media"
	await _secs(t, 0.8)
	m._scan_now()
	t.check(m._chairs.size() > 20 and leaf.get_node_or_null("Manija") != null, "al volver a calidad normal el gestor censa (sillas %d) y pone manijas" % m._chairs.size())
	_pl(t).teleport(d.global_transform * Vector3(0.1, -1.0, 1.1), 0.0)
	await t.frames(2)
	d.set_open(true)
	var rec: Dictionary = m._chairs[0]
	m._chair_play(rec, "stand")
	_pl(t).teleport(Vector3(mug.global_position.x, fl.global_position.y, mug.global_position.z + 1.5), 0.0)
	await _secs(t, 0.7)
	var v := mug.get_node_or_null("Vapor") as CPUParticles3D
	t.check(_copias(d) == 1 and v != null and v.emitting and not _en_reposo(rec), "en normal: puerta con copia girando, taza humeando, una silla corrida")
	GfxQuality.current = "liviano"
	await t.frames(3)
	t.check(_copias(d) == 0 and not d.has_meta("oa_door") and leaf.layers != 0 and not leaf.visible, "paso a liviano: la copia se borra y la puerta queda abierta como en v0.3.1 (hoja oculta)")
	t.check(_en_reposo(rec), "la silla vuelve a su reposo")
	t.check(not v.emitting, "la taza deja de humear")
	d.set_open(false)
	t.check(leaf.visible and leaf.layers != 0, "y la puerta cierra normal")
	GfxQuality.current = "media"
	await t.back_to_menu()


# --- reaparecer ------------------------------------------------------------------------------------------------------

func _reaparecer(t: Node) -> void:
	var fl := await _piso(t, 2)
	await t.login_at_seat()
	await _secs(t, 2.6)
	var m := _gestor(fl)
	var bath := fl.find_child("Bano_bano_p2", true, false) as Node3D
	var d := bath.get_node("Puerta") as WorldObjects.Door
	var leaf := _hoja(d)
	# un compañero se para (silla corrida), un perseguidor deja una puerta a medio abrir, y te matan
	var who: NpcAnimator = null
	for a in NpcAnimator._all:
		if is_instance_valid(a) and a.slug.begins_with("agente_") and a.state == "seated" and a.body != null and a.body.is_inside_tree() and fl.is_ancestor_of(a.body):
			who = a
			break
	var rec := m._chair_near(who.body.global_position) if who != null else {}
	if who != null:
		(who.body as CharacterRig).play("idle")
	await _secs(t, 1.2)
	d.set_open(true)
	await _secs(t, 0.15)
	t.check(not rec.is_empty() and not _en_reposo(rec) and absf(_ang(d)) < 80.0, "antes de morir: una silla rodando y una puerta a medio abrir (%.0f°)" % _ang(d))
	var floor_id := fl.get_instance_id()
	await t.die("break_excedido", "obj_reaparecer", "shero")
	await t.wait_death_shown(12.0)
	await t.reconnect()
	await _secs(t, 0.3)
	var fl2 := t.building().floor_node as FloorBase
	t.check(fl2 != null and fl2.get_instance_id() == floor_id, "reaparecés en el mismo piso sin reconstruirlo (los objetos son los mismos)")
	t.check(_pl(t).seated and _pl(t).seat_id == "C-14", "sentado en tu PC (C-14)")
	if is_instance_valid(d):
		t.check(d.open and absf(absf(_ang(d)) - ObjectAnim.DOOR_OPEN_DEG) < 0.01, "la puerta que se estaba abriendo quedó abierta del todo (%.1f°), no a medio camino" % _ang(d))
		var st: Dictionary = d.get_meta("oa_door", {})
		var tw: Variant = st.get("tw")
		t.check(not (tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running()), "sin giro pendiente")
	if not rec.is_empty():
		t.check(_en_reposo(rec) or m._chair_busy(rec) == false, "la silla del compañero no quedó rodando")
	var prec := m._chair_near(_pl(t).global_position)
	await _secs(t, 2.6)
	t.check(not prec.is_empty() and _en_reposo(prec), "tu silla está en su sitio")
	var moving := 0
	for r in m._chairs:
		if m._chair_busy(r):
			moving += 1
	t.check(moving == 0, "ninguna silla en movimiento 2,6 s después (%d)" % moving)
	await t.back_to_menu()


# --- costo -----------------------------------------------------------------------------------------------------------

## Costo del gestor: ms por cuadro. Se mide en ventanas de 0,3 s y vale la MEJOR ventana: con la máquina cargada el
## sistema le quita la CPU al proceso en medio de una medida (decenas de ms) y el promedio simple salía 20 veces más alto.
func _medir(t: Node, secs: float) -> Array:
	var best := 1e9
	var frames := 0
	var el := 0.0
	while el < secs:
		ObjectAnim.prof_usec = 0
		ObjectAnim.prof_frames = 0
		ObjectAnim.prof_on = true
		await _secs(t, 0.3)
		ObjectAnim.prof_on = false
		el += 0.3
		if ObjectAnim.prof_frames > 0:
			best = minf(best, ObjectAnim.prof_usec / 1000.0 / ObjectAnim.prof_frames)
			frames += ObjectAnim.prof_frames
	return [best if frames > 0 else 0.0, frames]


func _costo(t: Node) -> void:
	var fl := await _piso(t, 2)
	var m := _gestor(fl)
	# el censo se mide 5 veces y vale la mejor (con la máquina cargada una sola medida puede salir al triple)
	var scan_ms := 1e9
	for _i in 5:
		var t0 := Time.get_ticks_usec()
		m._scanned = false
		m._seen.clear()
		m._chairs.clear()
		m._flutter.clear()
		m._mugs.clear()
		m._clocks.clear()
		m._props.clear()
		m._racks.clear()
		m._scan()
		scan_ms = minf(scan_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		await t.get_tree().process_frame
	t.note("censo del piso 2: %.2f ms una vez (sillas %d · papeles %d · relojes %d · cosas de mesa %d)" % [scan_ms, m._chairs.size(), m._flutter.size(), m._clocks.size(), m._props.size()])
	t.check(scan_ms < 60.0, "el censo del piso 2 cuesta %.1f ms (una vez, a los 0,3 s de cargar el piso)" % scan_ms)
	# peor caso del piso 2: junto a la impresora y los pósits, mirando a la sala
	var hoja := fl.find_child("HojaColgando", true, false) as Node3D
	_pl(t).teleport(Vector3(hoja.global_position.x, fl.global_position.y, hoja.global_position.z - 1.5), 0.0)
	await _secs(t, 0.5)
	var a: Array = await _medir(t, 3.0)
	var live := 0
	for f in m._flutter:
		if bool(f["live"]):
			live += 1
	t.note("piso 2, calidad normal, %d papeles vivos: %.4f ms por cuadro (%d cuadros)" % [live, a[0], a[1]])
	# Presupuesto: 1,5 % de un cuadro de 60 fps. (Medido: 0,03–0,04 ms; el número se infla con la máquina cargada.)
	t.check(float(a[0]) < 0.25, "piso 2: el gestor gasta %.4f ms por cuadro (< 0,25 ms)" % a[0])
	var fl2 := await _piso(t, -1)
	var m2 := _gestor(fl2)
	var bank := fl2.find_child("EstacionMicroondas", true, false) as Node3D
	_pl(t).teleport(bank.global_transform * Vector3(0.0, 0.0, 1.5), 0.0)
	for c in bank.get_children():
		if c is WorldObjects.Microwave:
			(c as WorldObjects.Microwave).set_state("ocupado", GameState.clock_seconds + 3600.0, "X")
	await _secs(t, 0.5)
	var b: Array = await _medir(t, 3.0)
	t.note("piso -1, 6 microondas calentando a la vista: %.4f ms por cuadro (%d cuadros; microondas %d)" % [b[0], b[1], m2._mws.size()])
	# peor caso posible (los seis a la vez): 0,09 ms con la máquina tranquila, 0,16 ms con carga 30+; tope 3 % de un cuadro
	t.check(float(b[0]) < 0.5, "piso -1, peor caso: %.4f ms por cuadro (< 0,5 ms)" % b[0])
	GfxQuality.current = "liviano"
	await _secs(t, 0.3)
	var c2: Array = await _medir(t, 1.5)
	t.note("Modo liviano: %d cuadros medidos (el gestor sale en la primera línea)" % c2[1])
	t.check(int(c2[1]) == 0, "Modo liviano: costo cero (no entra al cuerpo del gestor)")
	GfxQuality.current = "media"
	await t.back_to_menu()


# --- cafetería: táper sobre la mesa y carros de bandejas -------------------------------------------------------------

func _cafeteria(t: Node) -> void:
	var fl := await _piso(t, -1)
	var m := _gestor(fl)
	var TF := WorldObjects.TaperFlow
	TF.ensure_eat_spots(fl)
	var spot := fl.find_child("Comer_0", false, false) as Interactable
	if not t.check(spot != null and m != null, "hay mesas para comer en el -1"):
		return
	var pl := _pl(t)
	var st0: Variant = TF.state()
	# --- comer: el táper queda sobre la mesa cuando las manos terminan y se va al pararse
	TF.set_state(TF.CALIENTE)
	pl.teleport(spot.global_position + spot.global_transform.basis.z * 1.5 + Vector3(0, -spot.global_position.y + fl.global_position.y, 0), 0.0)
	await t.frames(2)
	var ok: bool = spot.interact(pl)
	t.check(ok and pl.seated and TF.state() == TF.COMIDO, "comer por el camino real: sentado y el táper comido (como antes)")
	t.check(m._eat_prop != null and not m._eat_prop.visible, "mientras las manos comen todavía no hay nada sobre la mesa")
	await _secs(t, 3.5)
	var tp := m._eat_prop
	if t.check(tp != null and is_instance_valid(tp) and tp.visible, "al terminar, el táper queda sobre la mesa"):
		var tb := spot.get("table") as MeshInstance3D
		var bb := tb.global_transform * tb.mesh.get_aabb() if tb != null and tb.mesh != null else AABB(spot.global_position, Vector3.ZERO)
		var top := bb.position.y + bb.size.y
		await _secs(t, 0.8)
		var body := tp.get_node("Cuerpo") as Node3D
		t.check(absf(body.global_position.y - 0.0325 - top) < 0.004, "apoyado en el tablero (base a %.3f m, tablero %.3f m)" % [body.global_position.y - 0.0325, top])
		t.check(tb == null or (tp.global_position.x > bb.position.x + 0.05 and tp.global_position.x < bb.end.x - 0.05 and tp.global_position.z > bb.position.z + 0.05 and tp.global_position.z < bb.end.z - 0.05), "dentro de la mesa")
		var dpl := Vector2(tp.global_position.x - pl.global_position.x, tp.global_position.z - pl.global_position.z).length()
		t.check(dpl > 0.25 and dpl < 0.95, "delante del jugador (a %.2f m)" % dpl)
		t.check(tp.find_children("*", "CollisionObject3D", true, false).is_empty(), "sin colisión")
	pl.stand_up()
	await _secs(t, 0.5)
	t.check(m._eat_prop == null and fl.get_node_or_null("TaperMesa") == null, "al pararte te lo llevás (no queda nada)")
	# --- 30 veces sentarse/pararse a medias: no quedan táperes sueltos
	for i in 30:
		EventBus.player_seated.emit("mesa_comer_0")
		if i % 3 == 0:
			await t.get_tree().process_frame
		EventBus.player_stood_up.emit()
	await _secs(t, 0.5)
	var left := 0
	for c in fl.get_children():
		if str(c.name).begins_with("TaperMesa") or str(c.name).begins_with("@TaperMesa"):
			left += 1
	t.check(left == 0 and m._eat_prop == null, "30 veces sentarse y pararse: sin táperes sueltos (%d)" % left)
	# --- carros de bandejas
	if t.check(m._racks.size() >= 1, "el gestor censó los carros de bandejas (%d)" % m._racks.size()):
		var rk: Dictionary = m._racks[0]
		var root := rk["root"] as Node3D
		var rails: Array = rk["rails"]
		var rest: Array = rk["rest"]
		var root_tf := root.transform
		var col := root.get_node_or_null("Col") as Node3D
		var col_tf := col.global_transform if col != null else Transform3D()
		pl.teleport(root.global_transform * Vector3(0.0, 0.0, 0.55), 0.0)
		await t.frames(2)
		pl.velocity = Vector3.ZERO
		m._racks_tick()
		t.check(not ObjectAnim._has_tween(rails[0], "oa_settle"), "parado al lado no pasa nada")
		rk["cool"] = 0.0
		pl.velocity = root.global_transform.basis.x * 3.0
		m._racks_tick()
		t.check(ObjectAnim._has_tween(rails[0], "oa_settle"), "rozarlo caminando hace tintinear las bandejas")
		var moved := 0.0
		var el := 0.0
		while el < 0.45:
			await t.get_tree().process_frame
			el += t.get_process_delta_time()
			for i in rails.size():
				moved = maxf(moved, (rails[i] as Node3D).transform.origin.distance_to((rest[i] as Transform3D).origin))
		t.check(moved > 0.0005 and moved < 0.012, "se mueven apenas (%.1f mm)" % (moved * 1000.0))
		t.check(root.transform == root_tf and (col == null or col.global_transform == col_tf), "el carro y su colisión no se mueven")
		for k in 200:
			rk["cool"] = 0.0
			m._rack_rattle(rk, 1.0)
			if k % 10 == 0:
				await t.get_tree().process_frame
		await _secs(t, 1.2)
		var exact := true
		for i in rails.size():
			exact = exact and (rails[i] as Node3D).transform == (rest[i] as Transform3D)
		t.check(exact, "200 golpes después cada bandeja está EXACTAMENTE en su reposo")
		# liviano: ni tintineo ni táper
		GfxQuality.current = "liviano"
		rk["cool"] = 0.0
		pl.velocity = root.global_transform.basis.x * 3.0
		await _secs(t, 0.6)
		t.check(not ObjectAnim._has_tween(rails[0], "oa_settle"), "Modo liviano: los carros no se mueven")
		EventBus.player_seated.emit("mesa_comer_0")
		await t.frames(2)
		t.check(m._eat_prop == null and fl.get_node_or_null("TaperMesa") == null, "Modo liviano: no aparece el táper en la mesa")
		EventBus.player_stood_up.emit()
		GfxQuality.current = "media"
	# una puerta con copia en la lista (estática) cuyo piso ya se liberó: pasar a liviano no debe tocar el nodo muerto
	# (lo encontró v031_q5: «Trying to cast a freed object» en ObjectAnim._calm)
	await _secs(t, 0.3)
	var ghost := Node3D.new()
	fl.add_child(ghost)
	ObjectAnim._doors.append(ghost)
	ghost.free()
	# y una silla corrida a la que le liberaron una pieza (el Modo liviano funde las mallas estáticas)
	if not m._chairs.is_empty():
		var crec: Dictionary = m._chairs[0]
		m._chair_play(crec, "stand")
		await _secs(t, 0.3)
		((crec["parts"] as Array)[1] as Node).free()
		m._chair_near(pl.global_position, 50.0)
		m._chairs_fix()
	if not m._racks.is_empty():
		(((m._racks[0] as Dictionary)["rails"] as Array)[0] as Node).free()
		m._rack_rattle(m._racks[0], 1.0)
		m._racks_tick()
	GfxQuality.current = "liviano"
	await _secs(t, 0.3)
	var dead := 0
	for d in ObjectAnim._doors:
		if not is_instance_valid(d):
			dead += 1
	t.check(dead == 0, "liviano con una puerta de un piso ya liberado en la lista: se descarta sin tocarla (%d muertas)" % dead)
	t.check(m._player_chair.is_empty(), "y con piezas de silla y de carro liberadas no se toca ningún nodo muerto (ver «SCRIPT ERROR» en el log: 0)")
	GfxQuality.current = "media"
	TF.set_state(st0)
	await t.back_to_menu()

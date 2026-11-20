## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 gfx · pruebas del paquete gráfico (scripts/gfx/):
## - gfx_baja_intacta: en Baja (y en Modo liviano) el paquete no existe: ni director, ni capa de detalle, ni luces
##   propias; y un ida y vuelta Baja → Alta → Baja deja el piso EXACTAMENTE como estaba (luces, mallas, materiales,
##   ambiente, sillas, bustos).
## - gfx_colisiones: con Alta (capa de detalle completa) las colisiones de los cuatro pisos y la escalera son las
##   mismas que en Baja (misma cantidad de formas, mismos sitios, mismos tamaños).
## - gfx_alta_pisos: en Alta cada piso recibe su pase (aire, luces, materiales, detalle) y al salir el ambiente
##   vuelve a sus valores; Media arma menos detalle que Alta.
## - gfx_opciones: catálogo de opciones (valor por calidad, cambio suelto, vuelta al ajuste, persistencia),
##   decisiones del arranque (renderizador, calidad por tarjeta) y elección de la medición.
## - gfx_emergencia: GfxDirector.emergency() baja los tubos y enciende las luminarias de emergencia, y vuelve.
## - gfx_medicion: la medición del primer turno baja de calidad si los fps no alcanzan (y avisa una vez); la medición
##   a pedido prueba Alta/Media/Baja y se queda con la que llega.
## - gfx_panel: el menú de opciones abre «Gráficos avanzados», cambia opciones y abre la pantalla de brillo.
## - gfx_web: el HTML no lleva el paquete (simulado): en web ni Alta crea nodos del paquete, el menú no ofrece
##   «Gráficos avanzados…» y Alta sin paquete → con paquete → sin paquete deja el piso como estaba.
## - gfx_zonas: las zonas de luz del piso 2 (pasillo de casilleros, ala norte, sala de calibración): qué tubos quedan
##   encendidos, el brillo residual de los apagados, las luces extra esclavas; la sesión de Haime (set_dim, blackout)
##   baja y apaga también lo que añade el paquete; y «un panel más» rehace luces y capa de detalle sobre los 15.
## - gfx_volcado:<piso>: herramienta (no prueba reglas): vuelca a user://gfx_volcado_<piso>.json las mallas, luces,
##   puertas, vidrios y colisiones del piso tal como quedan armados, para diseñar y auditar la capa de detalle.


func escenarios() -> Array[String]:
	return ["gfx_baja_intacta", "gfx_colisiones", "gfx_alta_pisos", "gfx_zonas", "gfx_opciones", "gfx_emergencia", "gfx_medicion", "gfx_panel", "gfx_web", "gfx_volcado:"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"gfx_baja_intacta": await _baja_intacta(t)
		"gfx_colisiones": await _colisiones(t)
		"gfx_alta_pisos": await _alta_pisos(t)
		"gfx_zonas": await _zonas(t)
		"gfx_opciones": await _opciones(t)
		"gfx_emergencia": await _emergencia(t)
		"gfx_medicion": await _medicion(t)
		"gfx_panel": await _panel(t)
		"gfx_web": await _web(t)
		"gfx_volcado": await _volcado(t, arg)


## Cambia la calidad como lo hace el menú y espera a que el pase gráfico (diferido) termine.
func _quality(t: Node, lv: String) -> void:
	Loc.set_setting("quality", lv)
	GfxQuality.apply(t.get_tree(), lv)
	EventBus.settings_changed.emit("quality")
	await t.frames(6)


## Estado del piso que el paquete podría tocar, como lista de líneas (para comparar y decir qué cambió).
static func snapshot(tree: SceneTree, fl: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n in tree.root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		var e := float(l.get_meta("mood_base", l.light_energy)) if l.get_script() == null else float(l.get("base_energy")) if l.get("base_energy") != null else 0.0
		# Las luces con «no_mood» las anima su dueño (el REC de Haime late cada 2 s): su energía no se compara.
		var e_txt := "guion" if l.has_meta("no_mood") else "%.3f" % e
		out.append("luz %s vis=%s e=%s sombra=%s color=%s r=%.2f" % [str(l.get_path()), l.visible, e_txt, l.shadow_enabled, l.light_color.to_html(false), (l as OmniLight3D).omni_range if l is OmniLight3D else 0.0])
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var shape := ""
		if mi.mesh is BoxMesh:
			shape = "caja" + str((mi.mesh as BoxMesh).size)
		elif mi.mesh != null:
			shape = mi.mesh.get_class()
		# Lo que el juego hace parpadear solo (el led de la impresora atascada) no se compara por su «visible».
		var vis := "parpadea" if mi.get_parent() != null and mi.get_parent().has_node("Parpadea") else str(mi.visible)
		out.append("malla %s vis=%s %s mat=%d" % [str(fl.get_path_to(mi)), vis, shape, mi.material_override.get_instance_id() if mi.material_override != null else 0])
	for dict in [Greybox._materials, Greybox._surf]:
		for k in (dict as Dictionary).keys():
			var m := (dict as Dictionary)[k] as StandardMaterial3D
			if m == null:
				continue
			out.append("mat %s n=%s r=%.3f rt=%s at=%s tri=%s/%s esc=%s a=%s em=%.2f metas=%s" % [str(k), m.normal_enabled, m.roughness, m.roughness_texture != null, m.albedo_texture != null, m.uv1_triplanar, m.uv1_world_triplanar, str(m.uv1_scale), m.albedo_color.to_html(), m.emission_energy_multiplier, str(m.get_meta_list())])
	var world := tree.root.find_children("*", "WorldEnvironment", true, false)
	for w in world:
		var env := (w as WorldEnvironment).environment
		if env == null:
			continue
		for prop in GfxAtmosphere.PROPS:
			out.append("env %s=%s" % [prop, str(env.get(prop))])
	out.append("nodos %d" % fl.find_children("*", "", true, false).size())
	return out


static func _diff(a: PackedStringArray, b: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var sa := {}
	for x in a:
		sa[x] = true
	var sb := {}
	for x in b:
		sb[x] = true
	for x in a:
		if not sb.has(x):
			out.append("- " + x)
	for x in b:
		if not sa.has(x):
			out.append("+ " + x)
	return out


## Diferencias entre dos estados, cada uno tomado dos veces: solo cuentan las líneas que estaban quietas en un
## estado (iguales en sus dos tomas) y no aparecen en ninguna toma del otro.
static func _diff_stable(a1: PackedStringArray, a2: PackedStringArray, b1: PackedStringArray, b2: PackedStringArray) -> Array[String]:
	var sets: Array = []
	for arr in [a1, a2, b1, b2]:
		var d := {}
		for x in arr:
			d[x] = true
		sets.append(d)
	var out: Array[String] = []
	for x in a1:
		if sets[1].has(x) and not sets[2].has(x) and not sets[3].has(x):
			out.append("- " + x)
	for x in b1:
		if x.begins_with("mat "):
			continue  # un material NUEVO en la caché de Greybox (lo pidió la capa de detalle) no cambia nada de lo que había
		if sets[3].has(x) and not sets[0].has(x) and not sets[1].has(x):
			out.append("+ " + x)
	return out


func _gfx_nodes(t: Node) -> int:
	var n := 0
	for c in t.get_tree().root.find_children("*", "", true, false):
		if c.has_meta("gfx_fx") or str(c.name) in ["GfxDetalle", "GfxDirector", "GfxLente"]:
			n += 1
	return n


func _baja_intacta(t: Node) -> void:
	Loc.set_setting("quality", "baja")
	GfxQuality.current = "baja"
	await t.start_shift("Jiroshi", 1)
	await _go(t, 2, "pc")
	await _quality(t, "baja")
	if is_instance_valid(GfxDirector.inst):  # otra prueba de la misma corrida pudo dejarlo creado
		GfxDirector.inst.free()
	await t.frames(3)
	t.check(not is_instance_valid(GfxDirector.inst), "en Baja el director no existe")
	t.check(_gfx_nodes(t) == 0, "en Baja no hay ningún nodo del paquete (%d)" % _gfx_nodes(t))
	t.check(GfxMaterials.stats.is_empty(), "en Baja los materiales no llevan relieve")
	var fl: Node = t.building().floor_node
	# Dos tomas separadas: lo que cambia solo (el piloto REC que parpadea, un led) no cuenta como diferencia.
	var before := snapshot(t.get_tree(), fl)
	await t.seconds(0.7)
	var before2 := snapshot(t.get_tree(), fl)
	await _quality(t, "alta")
	await t.seconds(0.6)
	t.check(is_instance_valid(GfxDirector.inst), "en Alta el director existe")
	var sm: Dictionary = GfxDirector.inst.summary() if is_instance_valid(GfxDirector.inst) else {}
	t.note("alta: " + JSON.stringify(sm))
	t.check(int((sm.get("luces", {}) as Dictionary).get("luminarias", 0)) > 20, "en Alta las luminarias pasan a ser focos")
	t.check(int((sm.get("detalle", {}) as Dictionary).get("dibujos", 0)) > 10, "en Alta hay capa de detalle")
	t.check(fl.get_node_or_null("GfxDetalle") != null, "con su nodo en el piso")
	var mid := snapshot(t.get_tree(), fl)
	t.check(_diff(before, mid).size() > 50, "y el piso cambió de verdad (%d diferencias)" % _diff(before, mid).size())
	await _quality(t, "baja")
	await t.frames(4)
	var after := snapshot(t.get_tree(), fl)
	await t.seconds(0.7)
	var after2 := snapshot(t.get_tree(), fl)
	var d := _diff_stable(before, before2, after, after2)
	for i in mini(d.size(), 12):
		t.note("diferencia: " + d[i])
	t.check(GfxCharacters._saved.is_empty(), "los materiales de los personajes vuelven a los suyos")
	t.check(d.is_empty(), "Baja → Alta → Baja deja el piso exactamente como estaba (%d diferencias)" % d.size())
	t.check(fl.get_node_or_null("GfxDetalle") == null or fl.get_node("GfxDetalle").is_queued_for_deletion(), "sin capa de detalle")
	t.check(not GfxLens.active, "sin pase de lente")
	# Modo liviano: mismo trato (y la fusión de mallas ve los bustos y las sillas de siempre).
	await _quality(t, "alta")
	await t.seconds(0.4)
	await _quality(t, "liviano")
	await t.seconds(0.6)
	var hidden := 0
	for n in fl.find_children("Busto", "MeshInstance3D", true, false):
		if n.has_meta("gfx_oculto"):
			hidden += 1
	t.check(hidden == 0, "en liviano ningún busto queda marcado por el paquete (%d)" % hidden)
	var swapped := 0
	for n in fl.find_children("Silla", "MeshInstance3D", true, false):
		if not ((n as MeshInstance3D).mesh is BoxMesh):
			swapped += 1
	t.check(swapped == 0, "y las sillas vuelven a ser las de siempre (%d cambiadas)" % swapped)
	t.check(fl.get_node_or_null("GfxLotes") != null, "liviano funde la geometría como siempre")
	await _quality(t, "baja")
	Loc.set_setting("quality", "media")
	GfxQuality.apply(t.get_tree(), "media")


func _colisiones(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	for piso in [2, -1, 1, 9]:
		await _quality(t, "baja")
		await _go(t, piso)
		await t.frames(6)
		var fl: Node = t.building().floor_node
		var a := collision_signature(fl)
		await _quality(t, "alta")
		await t.seconds(0.5)
		t.check(fl == t.building().floor_node, "piso %d: sigue siendo el mismo nodo" % piso)
		var b := collision_signature(fl)
		var det: Node = fl.get_node_or_null("GfxDetalle")
		t.check(det != null, "piso %d: hay capa de detalle en Alta" % piso)
		var extra := 0
		if det != null:
			extra = det.find_children("*", "CollisionObject3D", true, false).size() + det.find_children("*", "CollisionShape3D", true, false).size()
		t.check(extra == 0, "piso %d: la capa de detalle no trae colisiones (%d)" % [piso, extra])
		t.check(a == b, "piso %d: mismas colisiones con y sin detalle (%s ↔ %s)" % [piso, str(a), str(b)])
		t.note("piso %d: %s · detalle %s" % [piso, str(b), JSON.stringify(GfxDirector.inst.summary().get("detalle", {})) if is_instance_valid(GfxDirector.inst) else "-"])
	await _quality(t, "media")


func _alta_pisos(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _quality(t, "alta")
	var detail_alta := 0
	for piso in [2, -1, 1, 9]:
		await _go(t, piso)
		await t.seconds(0.6)
		var sm: Dictionary = GfxDirector.inst.summary()
		t.note("piso %d: %s" % [piso, JSON.stringify(sm)])
		t.check(bool(sm.get("aire", false)) and str(sm.get("aspecto", "")) == str(piso), "piso %d: aire con su aspecto (%s)" % [piso, str(sm.get("aspecto", ""))])
		t.check(int((sm.get("materiales", {}) as Dictionary).get("superficies", 0)) > 0 or not GfxMaterials.available(), "piso %d: materiales con relieve" % piso)
		if piso == 2:
			detail_alta = int((sm.get("detalle", {}) as Dictionary).get("triangulos", 0))
			t.check(int((sm.get("detalle", {}) as Dictionary).get("pantallas", 0)) > 40, "piso 2: monitores con pantalla")
			t.check(int((sm.get("detalle", {}) as Dictionary).get("sillas", 0)) > 200, "piso 2: sillas de trabajo")
		var env: Environment = GfxDirector.inst.atmosphere.env
		t.check(env != null and env.tonemap_mode == Environment.TONE_MAPPER_AGX, "piso %d: mapeo de tonos del paquete" % piso)
	await _go(t, 2)
	await t.seconds(0.4)
	await _quality(t, "media")
	await t.seconds(0.5)
	var sm2: Dictionary = GfxDirector.inst.summary()
	var detail_media := int((sm2.get("detalle", {}) as Dictionary).get("triangulos", 0))
	t.check(detail_media > 0 and detail_media < detail_alta, "Media arma menos detalle que Alta (%d < %d)" % [detail_media, detail_alta])
	# Una opción suelta: sin capa de detalle.
	GfxSettings.set_value("detalle", 0)
	EventBus.settings_changed.emit("gfx")
	await t.frames(6)
	t.check(t.building().floor_node.get_node_or_null("GfxDetalle") == null or t.building().floor_node.get_node("GfxDetalle").is_queued_for_deletion(), "detalle = No quita la capa")
	GfxSettings.reset_overrides()
	EventBus.settings_changed.emit("gfx")
	await t.frames(6)
	t.check(t.building().floor_node.get_node_or_null("GfxDetalle") != null, "y volver al ajuste la repone")
	await t.back_to_menu()
	await t.frames(6)


func _zonas(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _quality(t, "alta")
	await _go(t, 2)
	await t.seconds(0.6)
	var lights: GfxLights = GfxDirector.inst.lights
	var fl: Node3D = t.building().floor_node
	t.check(int(lights.stats.get("zonas", 0)) >= 4, "piso 2: zonas de luz cargadas (%d)" % int(lights.stats.get("zonas", 0)))
	# Pasillo de casilleros: de los 14 paneles quedan el del casillero y el que parpadea por diseño.
	var lit := _corridor_lit(lights)
	t.check(int(lit[0]) == 14 and lit[1] == ["Panel07", "Panel10"], "pasillo: 14 paneles, encendidos %s" % str(lit[1]))
	var p1 := fl.find_child("Panel01", true, false) as MeshInstance3D
	var m1 := (p1.material_override as StandardMaterial3D) if p1 != null else null
	t.check(m1 != null and m1.emission_enabled and m1.emission_energy_multiplier > 0.1 and m1.emission_energy_multiplier < 0.6, "los tubos apagados del pasillo conservan un brillo residual (se siguen contando)")
	# Sala de calibración: un panel con haz cerrado y dos luces extra esclavas.
	t.check(int(lights.stats.get("extras", 0)) == 2, "sala de calibración: derrame al ala norte y filo rojo (%d extras)" % int(lights.stats.get("extras", 0)))
	var cal: GfxLights.Fixture = null
	for fx in lights.fixtures:
		if is_instance_valid(fx.panel) and str(fx.panel.name) == "LuzCalibracion":
			cal = fx
	t.check(cal != null and cal.lit and is_instance_valid(cal.spot) and cal.spot.spot_angle < 50.0, "su panel lleva un haz cerrado sobre la mesa")
	# La sesión de Haime manda: baja y apaga las luces de la sala, y lo que añade el paquete la sigue.
	var haime: Node = null
	for n in fl.find_children("*", "", true, false):
		if n.has_method("room_session") and n.has_method("set_dim") and n.has_method("blackout"):
			haime = n
	t.check(haime != null, "el comportamiento de Haime está en el piso")
	if haime != null and cal != null:
		t.player().teleport(fl.to_global(Vector3(11.1, 0.05, 2.85)), 90.0)
		await t.seconds(1.2)
		# El panel de la sala parpadea por diseño: se toma el máximo de unos cuantos cuadros.
		var full := 0.0
		var extra_full := 0.0
		for _i in 45:
			await t.frames(1)
			full = maxf(full, cal.spot.light_energy)
			var sum := 0.0
			for ex in lights._extras:
				sum += (ex[0] as Light3D).light_energy
			extra_full = maxf(extra_full, sum)
		t.check(full > 0.5 and extra_full > 0.5, "antes de la sesión: haz %.2f, extras %.2f" % [full, extra_full])
		haime.call("room_session", true, 1)
		await t.frames(3)
		haime.call("set_dim", 0.8)
		var dim_e := 0.0
		for _i in 45:
			await t.frames(1)
			dim_e = maxf(dim_e, cal.spot.light_energy)
		t.check(dim_e < full * 0.45 and dim_e > 0.0, "set_dim(0,8): el haz baja con la sala (%.2f → %.2f)" % [full, dim_e])
		haime.call("blackout", 30.0)
		await t.frames(4)
		# v0.3.2-final: la sesión de Haime nunca apaga el REC del monitor («LuzRec»: al final de la fatal es lo único
		# que queda). El filo rojo del paquete es esclavo de esa luz: la sigue. Lo blanco (haz, derrame) sí cae a cero.
		var extra_e := 0.0
		var red_e := 0.0
		for ex in lights._extras:
			var el := ex[0] as Light3D
			if not el.visible:
				continue
			if el.light_color.r > 0.8 and el.light_color.g < 0.35:
				red_e += el.light_energy
			else:
				extra_e += el.light_energy
		var spot_e := cal.spot.light_energy if cal.spot.visible else 0.0
		t.check(spot_e < 0.01 and extra_e < 0.01, "apagón de Haime: haz y derrame a cero (%.3f, %.3f)" % [spot_e, extra_e])
		var luz_rec := fl.find_child("LuzRec", true, false) as Light3D
		# Sigue encendido porque el REC sigue encendido, pero bajo ("sigue_min" de la zona): con la sala a oscuras,
		# entero (3,2) sería la luz principal y la sala quedaría rosada.
		t.check(luz_rec != null and luz_rec.visible and luz_rec.light_energy > 0.05 and red_e > 0.05 and red_e < 1.0, "el filo rojo sigue al REC del monitor, que la sesión no apaga, pero bajo (filo %.2f, REC %.2f)" % [red_e, luz_rec.light_energy if luz_rec != null else -1.0])
		t.check(lights.presence == null or lights.presence.light_energy < 0.01, "y la luz de presencia también (%.3f)" % (lights.presence.light_energy if lights.presence != null else 0.0))
		var pool_e := 0.0
		for k in lights.pool.size():
			if lights._pool_zone[k] == cal.zone and lights.pool[k].visible:
				pool_e += lights.pool[k].light_energy
		t.check(pool_e < 0.01, "ninguna luz de práctica queda encendida dentro de la sala (%.3f)" % pool_e)
		haime.call("room_session", false, 0)
		var back := 0.0
		for _i in 45:
			await t.frames(1)
			back = maxf(back, cal.spot.light_energy)
		t.check(back > full * 0.8, "al terminar la sesión la sala vuelve (%.2f)" % back)
	# «Un panel más»: el piso rehace sus paneles; luces y capa de detalle se rehacen sobre los 15.
	var mm0 := fl.get_node_or_null("GfxDetalle/Luminarias") as MultiMeshInstance3D
	var n0 := mm0.multimesh.instance_count if mm0 != null else 0
	fl.call("apply_distortion", "un_panel_mas", {})
	await t.seconds(1.0)
	var lit2 := _corridor_lit(lights)
	var near_locker := 0
	var flickers := 0
	for fx in lights.fixtures:
		if is_instance_valid(fx.panel) and str(fx.panel.get_parent().name) == "Paneles" and fx.lit:
			if fx.flicker != null:
				flickers += 1
			elif absf(fl.to_local(fx.pos).z + 4.6) < 0.6:
				near_locker += 1
	t.check(int(lit2[0]) == 15 and (lit2[1] as Array).size() == 2 and near_locker == 1 and flickers == 1, "un panel más: 15 paneles, encendidos el del casillero y el que parpadea (%d + %d de %d)" % [near_locker, flickers, (lit2[1] as Array).size()])
	var mm1 := fl.get_node_or_null("GfxDetalle/Luminarias") as MultiMeshInstance3D
	var n1 := mm1.multimesh.instance_count if mm1 != null else 0
	t.check(n0 > 0 and n1 == n0 + 1, "y la capa de detalle viste los 15 (%d → %d carcasas)" % [n0, n1])
	var stale := 0
	for fx in lights.fixtures:
		if not is_instance_valid(fx.omni):
			stale += 1
	t.check(stale == 0, "sin luminarias viejas en la lista (%d)" % stale)
	await t.back_to_menu()
	await t.frames(6)


## [cuántos paneles hay en el pasillo de casilleros, nombres de los encendidos (ordenados)].
func _corridor_lit(lights: GfxLights) -> Array:
	var names: Array = []
	var total := 0
	for fx in lights.fixtures:
		if is_instance_valid(fx.panel) and str(fx.panel.get_parent().name) == "Paneles":
			total += 1
			if fx.lit:
				names.append(str(fx.panel.name))
	names.sort()
	return [total, names]


func _opciones(t: Node) -> void:
	var prev := GfxQuality.level()
	GfxQuality.current = "baja"
	t.check(not GfxSettings.enhanced(), "Baja: sin mejoras")
	for k in GfxSettings.OFF.keys():
		t.check(GfxSettings.value(k) == GfxSettings.OFF[k], "Baja: %s vale su apagado" % k)
		t.check(GfxSettings.PRESETS["media"].has(k) and GfxSettings.PRESETS["alta"].has(k), "%s está en los dos ajustes" % k)
	GfxQuality.current = "liviano"
	t.check(GfxSettings.level("detalle") == 0 and not GfxSettings.on("luz_terror"), "liviano: todo apagado")
	GfxQuality.current = "alta"
	GfxSettings.reset_overrides()
	t.check(GfxSettings.level("sombras") == 3 and GfxSettings.level("detalle") == 2, "Alta: su ajuste")
	GfxSettings.set_value("sombras", 1)
	t.check(GfxSettings.level("sombras") == 1 and GfxSettings.overridden("sombras"), "cambio suelto de una opción")
	t.check((Loc.get_setting("gfx", {}) as Dictionary).has("sombras"), "queda guardado en settings.json («gfx»)")
	GfxSettings.set_value("sombras", 3)
	t.check(not GfxSettings.any_override(), "volver al valor del ajuste borra el cambio")
	GfxSettings.set_value("aberracion", 0.25)
	GfxSettings.set_value("grano", 0.5)
	t.check(is_equal_approx(GfxSettings.amount("aberracion"), 0.25), "barra de aberración")
	EventBus.settings_changed.emit("quality")
	t.check(not GfxSettings.any_override(), "elegir una calidad borra los cambios sueltos")
	Loc.set_setting("flash_reduction", true)
	t.check(GfxSettings.flicker() == 0.0, "«Sin parpadeos de luz» manda sobre la intensidad")
	Loc.set_setting("flash_reduction", false)
	t.check(GfxSettings.flicker() == 1.0, "y al quitarla vuelve")
	GfxQuality.current = "media"
	t.check(GfxSettings.level("detalle") == 1 and not GfxSettings.on("ssil"), "Media: su ajuste")
	# Arranque: decisiones puras.
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_CPU, "llvmpipe (LLVM 20)", "Mesa") == "software", "llvmpipe = sin tarjeta")
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_OTHER, "SwiftShader Device", "Google") == "software", "SwiftShader = sin tarjeta")
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "NVIDIA GeForce GTX 1660", "NVIDIA") == "dedicada", "dedicada por tipo")
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_OTHER, "NVIDIA GeForce GTX 1660/PCIe/SSE2", "NVIDIA Corporation") == "dedicada", "dedicada por nombre (OpenGL)")
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, "Intel(R) UHD Graphics 620", "Intel") == "integrada", "integrada")
	t.check(GfxBoot.classify(RenderingDevice.DEVICE_TYPE_OTHER, "AMD Radeon(TM) Graphics", "ATI") == "integrada", "integrada por nombre")
	t.check(GfxBoot.level_for("software") == "liviano" and GfxBoot.level_for("integrada") == "media" and GfxBoot.level_for("dedicada") == "alta", "calidad por tarjeta")
	t.check(GfxBoot.desktop_default() == "media", "en pruebas la calidad por defecto sigue siendo Media")
	var base := {"metodo": "forward_plus", "quiere": "auto", "clase": "dedicada", "marca_pendiente": false, "cli": false, "relanzado": false, "fallo_previo": false}
	var dec := func(over: Dictionary) -> Dictionary:
		var s := base.duplicate()
		s.merge(over, true)
		return GfxBoot.decide(s)
	t.check(str(dec.call({})["accion"]) == "", "auto + Forward+ en una dedicada: sigue")
	t.check(str(dec.call({"clase": "software"})["metodo"]) == "gl_compatibility" and str(dec.call({"clase": "software"})["accion"]) == "relanzar", "Forward+ por software: relanza en Compatibilidad")
	t.check(str(dec.call({"marca_pendiente": true})["accion"]) == "relanzar" and bool(dec.call({"marca_pendiente": true})["anotar_fallo"]), "arranque anterior colgado: Compatibilidad y se anota")
	t.check(str(dec.call({"fallo_previo": true})["accion"]) == "relanzar", "con fallo anotado, auto = Compatibilidad")
	t.check(str(dec.call({"quiere": "gl_compatibility"})["accion"]) == "relanzar", "opción Compatibilidad con Forward+ en uso: relanza")
	t.check(str(dec.call({"quiere": "forward_plus", "metodo": "gl_compatibility"})["metodo"]) == "forward_plus", "opción Forward+ con Compatibilidad en uso: relanza en Forward+")
	t.check(str(dec.call({"quiere": "forward_plus", "fallo_previo": true})["accion"]) == "", "Forward+ a mano manda sobre el fallo anotado")
	t.check(str(dec.call({"metodo": "gl_compatibility"})["accion"]) == "", "auto + Compatibilidad (el motor cayó solo): sigue")
	t.check(str(dec.call({"quiere": "gl_compatibility", "cli": true})["accion"]) == "", "la línea de comandos manda")
	t.check(str(dec.call({"clase": "software", "relanzado": true})["accion"]) == "", "nunca se relanza dos veces")
	# Medición.
	t.check(GfxBench.pick_level({"alta": 72.0, "media": 110.0, "baja": 140.0}) == "alta", "medición: Alta si llega")
	t.check(GfxBench.pick_level({"alta": 31.0, "media": 55.0, "baja": 90.0}) == "media", "medición: Media")
	t.check(GfxBench.pick_level({"alta": 12.0, "media": 22.0, "baja": 41.0}) == "baja", "medición: Baja")
	# Brillo.
	GfxQuality.current = "alta"
	t.check(GfxCalibration.shown(GfxCalibration.DARK, 1.0) == GfxCalibration.DARK, "brillo 1,0 no cambia nada")
	t.check(GfxCalibration.shown(GfxCalibration.DARK, 1.5) > GfxCalibration.DARK * 2.0, "más brillo aclara las sombras")
	t.check(GfxCalibration.shown(GfxCalibration.DARK, 0.7) < GfxCalibration.DARK * 0.5, "menos brillo las hunde")
	GfxQuality.current = "baja"
	t.check(is_equal_approx(GfxCalibration.shown(GfxCalibration.DARK, 1.0), GfxCalibration.DARK), "Baja: brillo 1,0 tampoco")
	t.check(GfxCalibration.shown(GfxCalibration.DARK, 1.5) > GfxCalibration.DARK * 1.2, "Baja: el brillo va por exposición")
	t.check(TranslationServer.translate("GFX_TITLE") != "GFX_TITLE", "las cadenas del paquete están cargadas")
	GfxQuality.current = prev
	await t.frames(1)


func _emergencia(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _quality(t, "alta")
	await _go(t, 2, "pc")
	await t.seconds(0.8)
	var d: GfxDirector = GfxDirector.inst
	var lit := 0
	var sum0 := 0.0
	for fx in d.lights.fixtures:
		if fx.spot != null and is_instance_valid(fx.spot) and fx.spot.light_energy > 0.05:
			lit += 1
			sum0 += fx.spot.light_energy
	t.check(lit > 5, "hay tubos encendidos (%d)" % lit)
	GfxDirector.emergency(true)
	await t.seconds(2.5)
	var sum1 := 0.0
	for fx in d.lights.fixtures:
		if fx.spot != null and is_instance_valid(fx.spot):
			sum1 += fx.spot.light_energy
	t.check(sum1 < sum0 * 0.35, "emergencia: los tubos caen (%.1f → %.1f)" % [sum0, sum1])
	var em := 0
	for n in t.building().floor_node.find_children("LuzEmergencia*", "SpotLight3D", true, false):
		if (n as SpotLight3D).visible and (n as SpotLight3D).light_energy > 0.5:
			em += 1
	t.check(em > 0, "y se encienden las luminarias de emergencia (%d)" % em)
	GfxDirector.emergency(false)
	await t.seconds(3.0)
	var sum2 := 0.0
	for fx in d.lights.fixtures:
		if fx.spot != null and is_instance_valid(fx.spot):
			sum2 += fx.spot.light_energy
	t.check(sum2 > sum0 * 0.8, "al terminar vuelven (%.1f)" % sum2)
	# Ganchos de susto: no fallan aunque el lente no exista (pruebas sin pantalla).
	GfxLens.kick(1.0, 0.5)
	EventBus.pursuit_started.emit("haime", "prueba")
	await t.seconds(0.5)
	t.check(d.lights.emergency_target > 0.5, "una persecución enciende la emergencia")
	EventBus.pursuit_ended.emit("haime", "prueba")
	await t.seconds(0.3)
	t.check(d.lights.emergency_target < 0.5, "y al terminar se apaga")
	await _quality(t, "media")


func _medicion(t: Node) -> void:
	await t.start_shift("Jiroshi", 1)
	await _go(t, 2, "pc")
	await _quality(t, "alta")
	Loc.set_setting("quality_user", false)
	GfxSettings.set_global("gfx_bench_hecho", false)
	Engine.time_scale = 1.0
	var msgs: Array = t.spy("show_message")
	var prefix := TranslationServer.translate("GFX_BENCH_AUTO").get_slice("%s", 0)
	var avisos := func() -> int:
		var n := 0
		for m in msgs:
			if str(m[0]).begins_with(prefix):
				n += 1
		return n
	# Primera vez, con un equipo que «no llega»: Alta → Media → Baja, dos escalones como mucho, y un solo aviso.
	var b := GfxBench.new()
	b.mode = "primera"
	b.floor_fps = {"alta": 1.0e9, "media": 1.0e9}
	b.warmup = 0.2
	b.window = 0.3
	GfxBench.inst = b
	var rep1: Array = [{}]
	b.finished.connect(func(r: Dictionary) -> void: rep1[0] = r)
	t.get_tree().root.add_child(b)
	await t.until(func() -> bool: return not (rep1[0] as Dictionary).is_empty(), 20.0)
	t.note("primera: " + JSON.stringify(rep1[0]))
	t.check(GfxQuality.level() == "baja" and str(Loc.get_setting("quality", "")) == "baja", "sin fps suficientes baja hasta Baja (%s)" % GfxQuality.level())
	t.check(bool(GfxSettings.global("gfx_bench_hecho")), "y no vuelve a medir sola")
	t.check(not bool(Loc.get_setting("quality_user", false)), "sin marcar la calidad como elegida a mano")
	t.check(int(avisos.call()) == 1, "avisa una sola vez (%d)" % int(avisos.call()))
	await t.frames(3)
	t.check(not is_instance_valid(GfxDirector.inst) or t.building().floor_node.get_node_or_null("GfxDetalle") == null or t.building().floor_node.get_node("GfxDetalle").is_queued_for_deletion(), "y el piso queda como en Baja")
	# Primera vez, con un equipo que llega: se queda en Alta y no avisa.
	await _quality(t, "alta")
	GfxSettings.set_global("gfx_bench_hecho", false)
	var b2 := GfxBench.new()
	b2.mode = "primera"
	b2.floor_fps = {"alta": 0.5, "media": 0.5}
	b2.warmup = 0.2
	b2.window = 0.3
	var rep2: Array = [{}]
	b2.finished.connect(func(r: Dictionary) -> void: rep2[0] = r)
	t.get_tree().root.add_child(b2)
	await t.until(func() -> bool: return not (rep2[0] as Dictionary).is_empty(), 20.0)
	t.check(GfxQuality.level() == "alta" and int(avisos.call()) == 1, "con fps de sobra se queda en Alta, sin aviso")
	# A pedido.
	var b3 := GfxBench.manual(t.get_tree())
	t.check(b3 != null, "la medición a pedido arranca con un piso cargado")
	if b3 != null:
		var rep3: Array = [{}]
		b3.finished.connect(func(r: Dictionary) -> void: rep3[0] = r)
		await t.until(func() -> bool: return not (rep3[0] as Dictionary).is_empty(), 40.0)
		var r3: Dictionary = rep3[0]
		t.note("a pedido: " + JSON.stringify(r3))
		t.check((r3.get("fps", {}) as Dictionary).size() == 3, "mide las tres calidades")
		t.check(str(r3.get("elegida", "")) == GfxBench.pick_level(r3.get("fps", {})) and GfxQuality.level() == str(r3.get("elegida", "")), "y aplica la elegida (%s)" % str(r3.get("elegida", "")))
		t.check(bool(Loc.get_setting("quality_user", false)), "que queda como elección del jugador")
	Loc.set_setting("quality_user", false)
	Engine.time_scale = 8.0
	await _quality(t, "media")


## El HTML no lleva el paquete. Se simula con `GfxSettings.web_forzado`: en web, Alta no crea nada del paquete, el
## menú de opciones no ofrece «Gráficos avanzados…» y, si el paquete venía activo, el piso queda exactamente como la
## Alta que nunca lo tuvo (la de la beta).
func _web(t: Node) -> void:
	Loc.set_setting("quality", "baja")
	GfxQuality.current = "baja"
	await t.start_shift("Jiroshi", 1)
	await _go(t, 2, "pc")
	await _quality(t, "baja")
	if is_instance_valid(GfxDirector.inst):  # otra prueba de la misma corrida pudo dejarlo creado
		GfxDirector.inst.free()
	await t.frames(3)
	GfxSettings.web_forzado = true
	await _quality(t, "alta")
	await t.seconds(0.6)
	var fl: Node = t.building().floor_node
	t.check(not GfxSettings.enhanced(), "en web las mejoras no cuentan como activas ni en Alta")
	t.check(not is_instance_valid(GfxDirector.inst), "en web, Alta no crea el director")
	t.check(_gfx_nodes(t) == 0, "ni ningún nodo del paquete (%d)" % _gfx_nodes(t))
	t.check(GfxMaterials.stats.is_empty(), "ni relieve en los materiales")
	var web1 := snapshot(t.get_tree(), fl)
	await t.seconds(0.7)
	var web1b := snapshot(t.get_tree(), fl)
	var om := OptionsMenu.new()
	t.get_tree().root.add_child(om)
	await t.frames(3)
	t.check(om.find_child("BotonGraficosAvanzados", true, false) == null, "en web el menú de opciones no tiene «Gráficos avanzados…»")
	om.queue_free()
	await t.frames(2)
	# De vuelta en escritorio el paquete entra; al volver a «web» el piso queda como la Alta de la beta.
	GfxSettings.web_forzado = false
	await _quality(t, "alta")
	await t.seconds(0.6)
	t.check(is_instance_valid(GfxDirector.inst) and fl.get_node_or_null("GfxDetalle") != null, "en escritorio, Alta sí lo lleva")
	t.check(_diff(web1, snapshot(t.get_tree(), fl)).size() > 50, "y el piso cambia de verdad")
	GfxSettings.web_forzado = true
	await _quality(t, "alta")
	await t.seconds(0.6)
	var web2 := snapshot(t.get_tree(), fl)
	await t.seconds(0.7)
	var web2b := snapshot(t.get_tree(), fl)
	var d := _diff_stable(web1, web1b, web2, web2b)
	for i in mini(d.size(), 12):
		t.note("diferencia: " + d[i])
	t.check(d.is_empty(), "Alta sin paquete → con paquete → sin paquete deja el piso como estaba (%d diferencias)" % d.size())
	t.check(not GfxLens.active, "sin pase de lente")
	t.check(fl.get_node_or_null("GfxDetalle") == null or fl.get_node("GfxDetalle").is_queued_for_deletion(), "sin capa de detalle")
	GfxSettings.web_forzado = false
	await _quality(t, "baja")
	Loc.set_setting("quality", "media")
	GfxQuality.apply(t.get_tree(), "media")


func _panel(t: Node) -> void:
	var prev := GfxQuality.level()
	GfxQuality.apply(t.get_tree(), "alta")
	GfxSettings.reset_overrides()
	var om := OptionsMenu.new()
	t.get_tree().root.add_child(om)
	await t.frames(3)
	var open := om.find_child("BotonGraficosAvanzados", true, false) as Button
	t.check(open != null, "el menú de opciones tiene «Gráficos avanzados…»")
	if open == null:
		om.queue_free()
		return
	t.check(open.text == TranslationServer.translate("GFX_OPEN") and not open.text.begins_with("GFX_"), "con su texto (%s)" % open.text)
	open.pressed.emit()
	await t.frames(3)
	var panel := om.get_node_or_null("GfxOpciones") as Control
	t.check(panel != null, "y abre el panel")
	if panel == null:
		om.queue_free()
		return
	for k in GfxSettings.OFF.keys():
		t.check(panel.find_child("Op_" + str(k), true, false) != null, "el panel tiene la opción %s" % k)
	var untranslated := 0
	for n in panel.find_children("*", "", true, false):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if txt.begins_with("GFX_") or txt.begins_with("OPT_"):
			untranslated += 1
			t.note("sin traducir: " + txt)
	t.check(untranslated == 0, "sin claves sin traducir (%d)" % untranslated)
	# Cambiar de idioma con el panel abierto lo vuelve a armar (sin reiniciar), y al volver también.
	var lang0 := Loc.language
	Loc.set_language("en" if lang0 == "es" else "es")
	await t.frames(4)
	panel = om.get_node_or_null("GfxOpciones") as Control
	var back := panel.find_child("Volver", true, false) as Button
	t.check(back != null and back.text == TranslationServer.translate("OPT_BACK") and back.text != "", "el panel sigue al idioma (%s)" % (back.text if back != null else "-"))
	var title_en := TranslationServer.translate("GFX_TITLE")
	Loc.set_language(lang0)
	await t.frames(4)
	panel = om.get_node_or_null("GfxOpciones") as Control
	t.check(str(TranslationServer.translate("GFX_TITLE")) != str(title_en), "ES y EN tienen textos distintos")
	var f := FileAccess.open("res://localization/strings_v032_gfx.csv.import", FileAccess.READ)
	t.check(f == null or f.get_as_text().contains("compress=0"), "el CSV del paquete se importa sin comprimir (regla de localización)")
	var cb := panel.find_child("Op_materiales", true, false) as CheckBox
	cb.button_pressed = false
	await t.frames(2)
	t.check(not GfxSettings.on("materiales") and GfxSettings.overridden("materiales"), "una casilla cambia su opción")
	var sh := panel.find_child("Op_sombras", true, false) as Button
	sh.pressed.emit()
	await t.frames(2)
	t.check(GfxSettings.level("sombras") == 0, "un botón rota su valor (Alta → No)")
	var fps := panel.find_child("Op_gfx_fps", true, false) as CheckBox
	fps.button_pressed = true
	await t.frames(3)
	t.check(bool(GfxSettings.global("gfx_fps")), "contador de FPS: opción guardada")
	fps.button_pressed = false
	await t.frames(2)
	var rb := panel.find_child("Op_gfx_renderer", true, false) as Button
	rb.pressed.emit()
	t.check(str(GfxSettings.global("gfx_renderer")) == "forward_plus", "renderizador: auto → Forward+")
	rb.pressed.emit()
	rb.pressed.emit()
	t.check(str(GfxSettings.global("gfx_renderer")) == "auto", "y da la vuelta hasta auto")
	(panel.find_child("Restablecer", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.check(not GfxSettings.any_override(), "«Volver al ajuste» borra los cambios")
	panel = om.get_node_or_null("GfxOpciones") as Control
	(panel.find_child("Calibrar", true, false) as Button).pressed.emit()
	await t.frames(3)
	var cal: GfxCalibration = null
	for c in panel.get_children():
		if c is GfxCalibration:
			cal = c
	t.check(cal != null, "«Calibrar brillo…» abre la pantalla de brillo")
	if cal != null:
		var ok0 := (cal.find_child("Aceptar", true, false) as Button).text
		Loc.set_language("en" if Loc.language == "es" else "es")
		await t.frames(4)
		var ok1 := ""
		for b in cal.find_children("*", "Button", true, false):
			if (b as Button).text == TranslationServer.translate("GFX_CAL_OK"):
				ok1 = (b as Button).text
		t.check(ok1 != "" and ok1 != ok0, "la pantalla de brillo sigue al idioma (%s → %s)" % [ok0, ok1])
		Loc.set_language(lang0)
		await t.frames(4)
		(cal.find_child("Barra", true, false) as HSlider).value = 1.2
		await t.frames(2)
		t.check(is_equal_approx(GfxSettings.brillo(), 1.2), "la barra se prueba en vivo")
		cal.accept()
		await t.frames(3)
		t.check(is_equal_approx(float(GfxSettings.global("gfx_brillo")), 1.2) and bool(GfxSettings.global("gfx_calibrado")), "aceptar guarda el brillo")
		GfxSettings.set_global("gfx_brillo", 1.0)
		EventBus.settings_changed.emit("gfx_brillo")
	# En Baja: mejoras deshabilitadas, pantalla disponible.
	GfxQuality.apply(t.get_tree(), "baja")
	panel.call("_build")
	await t.frames(3)
	t.check((panel.find_child("Op_sombras", true, false) as Button).disabled, "en Baja las mejoras quedan deshabilitadas")
	t.check(not (panel.find_child("Op_gfx_fps", true, false) as CheckBox).disabled, "y las de pantalla siguen disponibles")
	om.queue_free()
	GfxQuality.apply(t.get_tree(), prev)
	await t.frames(2)


func _go(t: Node, f: int, spawn: String = "ascensor") -> void:
	if t.player().seated:
		t.player().stand_up()
	t.building().go_to_floor(f, spawn)
	await t.frames(4)


static func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


## Firma de las colisiones de un piso: cuántas formas hay y la suma de sus cajas (para comprobar que la capa de detalle
## no añade ni mueve ninguna).
static func collision_signature(fl: Node) -> Dictionary:
	var n := 0
	var acc := 0.0
	for s in fl.find_children("*", "CollisionShape3D", true, false):
		var cs := s as CollisionShape3D
		if cs.shape == null:
			continue
		n += 1
		var gp := cs.global_position
		acc += gp.x * 1.3 + gp.y * 2.7 + gp.z * 3.1
		if cs.shape is BoxShape3D:
			var sz := (cs.shape as BoxShape3D).size
			acc += sz.x + sz.y * 1.7 + sz.z * 2.3
	return {"formas": n, "suma": snappedf(acc, 0.01), "cuerpos": fl.find_children("*", "CollisionObject3D", true, false).size()}


func _volcado(t: Node, arg: String) -> void:
	var piso := int(arg) if arg.is_valid_int() else 2
	await t.start_shift("Jiroshi", 1)
	await _go(t, piso)
	await t.frames(6)
	var fl: Node3D = t.building().floor_node
	var inv := fl.global_transform.affine_inverse()
	var out: Dictionary = {"piso": piso, "mallas": [], "luces": [], "puertas": [], "etiquetas": [], "otros": []}
	for n in fl.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var e: Dictionary = {"n": str(mi.name), "p": str(mi.get_parent().name), "ruta": str(fl.get_path_to(mi)), "pos": _v3((inv * mi.global_transform).origin)}
		var b := (inv * mi.global_transform).basis
		e["yaw"] = snappedf(rad_to_deg(atan2(b.z.x, b.z.z)), 0.1)
		if mi.mesh is BoxMesh:
			e["caja"] = _v3((mi.mesh as BoxMesh).size)
		elif mi.mesh is CylinderMesh:
			var cm := mi.mesh as CylinderMesh
			e["cil"] = [cm.bottom_radius, cm.top_radius, cm.height]
		else:
			e["malla"] = mi.mesh.get_class()
			e["aabb"] = _v3(mi.mesh.get_aabb().size)
		var mat: Material = mi.material_override
		if mat == null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			var key := ""
			for k in Greybox._surf.keys():
				if Greybox._surf[k] == sm:
					key = "surf:" + str(k)
			if key == "":
				for k in Greybox._materials.keys():
					if Greybox._materials[k] == sm:
						key = "mat:" + str(k)
			e["mat"] = key if key != "" else "propio:%s a=%.2f e=%.2f" % [sm.albedo_color.to_html(false), sm.albedo_color.a, sm.emission_energy_multiplier if sm.emission_enabled else 0.0]
		e["col"] = mi.get_node_or_null("Col") != null
		e["vis"] = mi.is_visible_in_tree()
		var scr: Variant = mi.get_parent().get_script()
		if scr != null:
			e["pscr"] = str((scr as Script).resource_path.get_file())
		(out["mallas"] as Array).append(e)
	for n in fl.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		var e2: Dictionary = {"n": str(l.name), "p": str(l.get_parent().name), "clase": l.get_class(), "pos": _v3((inv * l.global_transform).origin), "e": l.light_energy, "color": l.light_color.to_html(false), "sombra": l.shadow_enabled, "vis": l.visible}
		if l is OmniLight3D:
			e2["r"] = (l as OmniLight3D).omni_range
		(out["luces"] as Array).append(e2)
	for n in fl.find_children("*", "", true, false):
		if n is WorldObjects.Door:
			var d := n as WorldObjects.Door
			var e3: Dictionary = {"n": str(d.name), "p": str(d.get_parent().name), "pos": _v3((inv * d.global_transform).origin), "tam": _v3(d.size)}
			var b2 := (inv * d.global_transform).basis
			e3["yaw"] = snappedf(rad_to_deg(atan2(b2.z.x, b2.z.z)), 0.1)
			e3["hoja"] = d.leaf != null
			e3["cerrada"] = d.locked
			(out["puertas"] as Array).append(e3)
		elif n is Label3D:
			var lb := n as Label3D
			(out["etiquetas"] as Array).append({"n": str(lb.name), "p": str(lb.get_parent().name), "pos": _v3((inv * lb.global_transform).origin), "t": lb.text.substr(0, 40), "px": lb.pixel_size, "fs": lb.font_size})
		elif n is Interactable or n is Marker3D or n is Zone:
			(out["otros"] as Array).append({"n": str(n.name), "clase": (n.get_script() as Script).resource_path.get_file() if n.get_script() != null else n.get_class(), "p": str(n.get_parent().name), "pos": _v3((inv * (n as Node3D).global_transform).origin)})
	out["colisiones"] = collision_signature(fl)
	var path := "user://gfx_volcado_%d.json" % piso
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	t.note("volcado: %s · %d mallas, %d luces, %d puertas, %d etiquetas" % [ProjectSettings.globalize_path(path), (out["mallas"] as Array).size(), (out["luces"] as Array).size(), (out["puertas"] as Array).size(), (out["etiquetas"] as Array).size()])
	t.check(not (out["mallas"] as Array).is_empty(), "el piso %d no tiene mallas" % piso)

extends FloorBase
## Piso 9 (azotea, GDD 7.5): vestíbulo del ascensor con puerta de vidrio al deck, abierta 24/7 (v0.3.1, B10). A través del
## vidrio: deck de madera, pérgola con policarbonato, bombillas colgantes, mesas blancas, sillas
## plásticas y de ratán, baranda de vidrio, parapeto con remate de ladrillo, palmera, baños chicos y
## el skyline bajo de Lima a las 2 AM (cielo degradado). Único lugar del juego sin zumbido.

const DECK := Color(0.42, 0.28, 0.16)
const DECK_B := Color(0.38, 0.25, 0.14)
const PERGOLA := Color(0.2, 0.14, 0.09)
const POLICARBONATO := Color(0.75, 0.8, 0.85, 0.35)
const RATAN := Color(0.62, 0.52, 0.36)
const LADRILLO := Color(0.42, 0.24, 0.19)


func _build() -> void:
	floor_number = 9
	# Vestíbulo (x -4..4, z -4..2): porcelanato, concreto, luz ámbar tenue.
	var v := Greybox.floor_slab(self, "Vestibulo", Vector2(0, -1), Vector2(8, 6), Greybox.GRIS)
	v.material_override = Greybox.surf("porcelanato_gris", Color(0.85, 0.85, 0.86), 0.3)
	Greybox.ceiling(self, "VestibuloTecho", Vector2(0, -1), Vector2(8, 6), 2.8, Color(0.5, 0.52, 0.52))
	Greybox.room_walls(self, "VestibuloPared", Vector2(0, -1), Vector2(8, 6), 2.8, Greybox.CONCRETO, ["s"])
	Greybox.light(self, Vector3(0, 2.5, -1), Greybox.AMBAR, 1.1, 6.0)
	Greybox.box(self, "LuzVestibulo", Vector3(0, 2.75, -1), Vector3(0.8, 0.05, 0.3), Greybox.AMBAR, false, 1.5)
	add_elevator(Vector3(-2, 0, -3.8), 0.0)
	Greybox.box(self, "Ascensor2", Vector3(2, 1.2, -3.9), Vector3(2.2, 2.4, 0.2), Greybox.GRIS)
	WorldObjects.signage(self, "ELEVATOR_MAINT", Vector3(2, 1.5, -3.7), 0.0, 0.2, Greybox.AMBAR)
	Greybox.box(self, "Maceta", Vector3(3.3, 0.3, 1.2), Vector3(0.5, 0.6, 0.5), Greybox.GRIS_OSCURO)
	Greybox.box(self, "Planta", Vector3(3.3, 0.95, 1.2), Vector3(0.7, 0.8, 0.7), Color(0.12, 0.3, 0.16), false)
	# Puerta de vidrio a la azotea con marco oscuro.
	Greybox.box(self, "VidrioA", Vector3(-2.5, 1.4, 2), Vector3(3, 2.8, 0.06), Greybox.VIDRIO)
	Greybox.box(self, "VidrioB", Vector3(2.5, 1.4, 2), Vector3(3, 2.8, 0.06), Greybox.VIDRIO)
	Greybox.box(self, "VidrioAlto", Vector3(0, 2.5, 2), Vector3(2, 0.6, 0.06), Greybox.VIDRIO, false)
	for mx in [-4.0, -1.0, 1.0, 4.0]:
		Greybox.box(self, "Moldura%d" % int(mx + 10), Vector3(mx, 1.4, 2), Vector3(0.1, 2.8, 0.12), Greybox.NEGRO, false)
	Greybox.box(self, "MarcoAlto", Vector3(0, 2.78, 2), Vector3(8, 0.06, 0.12), Greybox.NEGRO, false)
	# v0.3.1 Q5 (B10, D7): la puerta del deck está abierta 24/7 (antes: solo con AUX Break o Lunch). Las reglas siguen:
	# estar en la azotea sin un AUX válido cuenta como fuera de la sala (pista "sala", Discipline).
	var door := WorldObjects.simple(self, _DeckDoor, "PuertaAzotea", "HUD_DOOR", Vector3(0, 1.1, 2), Vector3(1.8, 2.2, 0.06), Greybox.VIDRIO)
	(door as WorldObjects.Door).locked = false
	Greybox.box(door, "Barra", Vector3(0, 0, -0.08), Vector3(0.6, 0.04, 0.04), Greybox.INOX, false)
	var aviso := WorldObjects.signage(self, "Q5_ROOFTOP_SIGN", Vector3(0, 2.3, 1.9), 180.0, 0.12, Greybox.AMBAR)
	aviso.name = "AvisoAzotea"
	# Deck de madera (z 2..20, x -10..10): listones alternados.
	Greybox.floor_slab(self, "DeckBase", Vector2(0, 11), Vector2(20, 18), DECK_B)
	for i in 60:
		var z := 2.15 + i * 0.3
		var l := Greybox.box(self, "Liston%d" % i, Vector3(0, 0.01, z), Vector3(20, 0.02, 0.24), DECK if i % 2 == 0 else DECK_B, false)
		l.material_override = Greybox.material(DECK if i % 2 == 0 else DECK_B, 0.0, 0.8, 0.0)
	# Pérgola (x -4.5..4.5, z 6.5..13.5): postes de madera oscura, vigas de acero, policarbonato ondulado.
	for i in 4:
		var px := -4.0 + (i % 2) * 8.0
		var pz := 7.0 + int(i / 2) * 6.0
		Greybox.box(self, "Poste%d" % i, Vector3(px, 1.45, pz), Vector3(0.22, 2.9, 0.22), PERGOLA)
	for pz in [7.0, 13.0]:
		Greybox.box(self, "VigaP%d" % int(pz), Vector3(0, 2.95, pz), Vector3(9, 0.12, 0.12), Greybox.GRIS_OSCURO, false)
	for px in [-4.0, 4.0]:
		Greybox.box(self, "VigaL%d" % int(px + 10), Vector3(px, 2.95, 10), Vector3(0.12, 0.12, 7), Greybox.GRIS_OSCURO, false)
	for i in 7:
		Greybox.box(self, "Correa%d" % i, Vector3(0, 3.02, 7.0 + i * 1.0), Vector3(9, 0.05, 0.08), Greybox.GRIS_OSCURO, false)
	for i in 9:
		var ox := -4.0 + i * 1.0
		Greybox.box(self, "Poli%d" % i, Vector3(ox, 3.1 + (0.04 if i % 2 == 0 else 0.0), 10), Vector3(1.0, 0.03, 7.2), POLICARBONATO, false)
	# Bombillas colgantes bajo la pérgola (ámbar: lugar de descanso).
	for i in 3:
		for k in 2:
			Greybox.pendant_lamp(self, "Bombilla%d_%d" % [i, k], Vector3(-2.5 + i * 2.5, 2.3, 8.5 + k * 3.0), Greybox.AMBAR, 0.95)
	# Mesas rectangulares blancas con sillas plásticas blancas y grises (respaldo calado) y algunas de ratán.
	var mesas := [Vector3(-2.5, 0, 8.5), Vector3(2.5, 0, 8.5), Vector3(-2.5, 0, 11.5), Vector3(2.5, 0, 11.5)]
	for i in mesas.size():
		var m: Vector3 = mesas[i]
		Greybox.box(self, "MesaBlanca%d" % i, m + Vector3(0, 0.74, 0), Vector3(1.6, 0.05, 0.8), Greybox.BLANCO)
		for leg in 4:
			Greybox.box(self, "MesaPata%d_%d" % [i, leg], m + Vector3((0.7 if leg % 2 == 0 else -0.7), 0.36, (0.3 if leg < 2 else -0.3)), Vector3(0.05, 0.72, 0.05), Greybox.BLANCO, false)
		for k in 2:
			var sz := m.z + (0.85 if k == 0 else -0.85)
			var ratan := (i + k) % 3 == 0
			var col := RATAN if ratan else (Greybox.BLANCO if k == 0 else Greybox.GRIS)
			Greybox.box(self, "SillaA%d_%d" % [i, k], Vector3(m.x, 0.45, sz), Vector3(0.42, 0.05, 0.42), col, false)
			var resp := Greybox.box(self, "SillaAResp%d_%d" % [i, k], Vector3(m.x, 0.72, sz + (0.2 if k == 0 else -0.2)), Vector3(0.42, 0.5, 0.04), col, false)
			if not ratan:
				for s in 3:  # respaldo calado: ranuras oscuras
					Greybox.box(resp, "Ranura%d" % s, Vector3(0, -0.15 + s * 0.15, 0), Vector3(0.3, 0.03, 0.05), Greybox.NEGRO, false)
			for leg in 4:
				Greybox.box(self, "SillaAPata%d_%d_%d" % [i, k, leg], Vector3(m.x + (0.17 if leg % 2 == 0 else -0.17), 0.22, sz + (0.17 if leg < 2 else -0.17)), Vector3(0.03, 0.44, 0.03), col, false)
	# Palmera en maceta, baños pequeños (cerrados) al oeste.
	Greybox.box(self, "MacetaPalmera", Vector3(7, 0.4, 15), Vector3(0.9, 0.8, 0.9), Greybox.GRIS_OSCURO)
	Greybox.cylinder(self, "Tronco", Vector3(7, 1.9, 15), 0.1, 2.2, Color(0.3, 0.22, 0.14), false, 0.9, 0.0, 0.07)
	for i in 6:
		var fr := Greybox.box(self, "Hoja%d" % i, Vector3(7, 3.0, 15), Vector3(1.6, 0.04, 0.3), Color(0.12, 0.32, 0.16), false)
		fr.rotation_degrees = Vector3(0, i * 60.0, -18.0)
		fr.position += Vector3(cos(deg_to_rad(i * 60.0)) * 0.7, 0.0, -sin(deg_to_rad(i * 60.0)) * 0.7)
	Greybox.floor_slab(self, "BanosAzoteaPiso", Vector2(-8, 16), Vector2(4, 3), Greybox.CERAMICA)
	Greybox.room_walls(self, "BanosAzotea", Vector2(-8, 16), Vector2(4, 3), 2.4, Greybox.BLANCO)
	Greybox.ceiling(self, "BanosAzoteaTecho", Vector2(-8, 16), Vector2(4, 3), 2.4, Greybox.GRIS)
	WorldObjects.signage(self, "SIGN_BATHROOM", Vector3(-8, 1.9, 14.4), 0.0, 0.18)
	# Baranda de vidrio sobre parapeto bajo con remate de ladrillo (perímetro del deck).
	Greybox.box(self, "ParapetoN", Vector3(0, 0.3, 19.9), Vector3(20, 0.6, 0.3), Greybox.CONCRETO)
	Greybox.box(self, "RemateN", Vector3(0, 0.63, 19.9), Vector3(20, 0.08, 0.36), LADRILLO, false)
	Greybox.box(self, "BarandaN", Vector3(0, 1.15, 19.9), Vector3(20, 1.0, 0.04), Greybox.VIDRIO, false)
	for sx in [-10.0, 10.0]:
		Greybox.box(self, "Parapeto%d" % int(sx + 20), Vector3(sx, 0.3, 11), Vector3(0.3, 0.6, 18), Greybox.CONCRETO)
		Greybox.box(self, "Remate%d" % int(sx + 20), Vector3(sx, 0.63, 11), Vector3(0.36, 0.08, 18), LADRILLO, false)
		Greybox.box(self, "Baranda%d" % int(sx + 20), Vector3(sx, 1.15, 11), Vector3(0.04, 1.0, 18), Greybox.VIDRIO, false)
	for i in 11:
		Greybox.box(self, "BarandaPoste%d" % i, Vector3(-10 + i * 2.0, 1.15, 19.9), Vector3(0.05, 1.0, 0.06), Greybox.INOX, false)
	# Límites invisibles sobre el parapeto y el borde sur del deck: nunca se cae de la azotea.
	Greybox.invisible_box(self, "LimiteParapetoN", Vector3(0, 1.8, 19.9), Vector3(20.4, 3.6, 0.3))
	Greybox.invisible_box(self, "LimiteParapetoW", Vector3(-10, 1.8, 11), Vector3(0.3, 3.6, 18.4))
	Greybox.invisible_box(self, "LimiteParapetoE", Vector3(10, 1.8, 11), Vector3(0.3, 3.6, 18.4))
	Greybox.invisible_box(self, "LimiteDeckSE", Vector3(7, 1.8, 2), Vector3(6.2, 3.6, 0.2))
	Greybox.invisible_box(self, "LimiteDeckSW", Vector3(-9.5, 1.8, 2), Vector3(1.2, 3.6, 0.2))
	# Pared ciega del edificio (caja del ascensor) al fondo oeste del vestíbulo.
	Greybox.box(self, "CajaAscensor", Vector3(-6.5, 2.0, 0), Vector3(5, 4.0, 8), Greybox.CONCRETO)
	_city()
	_open_air_cafe()
	Weather.rain(self, Vector3(0, 0, 11.5), Vector3(21, 9, 18.5), -12.0)
	for pz in [[Vector3(-6.0, 0.03, 5.0), Vector2(2.2, 1.2)], [Vector3(5.5, 0.03, 16.5), Vector2(2.6, 1.4)], [Vector3(-2.0, 0.03, 17.5), Vector2(1.8, 1.0)]]:
		Weather.puddle(self, pz[0], pz[1])
	Weather.lightning(self, Vector3(30, 30, 80), 6.0, 140.0)
	Weather.rain_glass(self, "VidrioLluviaA", Vector3(-2.5, 1.4, 2.04), Vector2(3.0, 2.8), 0.0)
	Weather.rain_glass(self, "VidrioLluviaB", Vector3(2.5, 1.4, 2.04), Vector2(3.0, 2.8), 0.0)
	Greybox.marker(self, "escalera", Vector3(-3.0, 0, -2.0), 180.0)  # Pursuit: el RTA sube por la escalera de servicio
	Zone.make(self, "azotea_vestibulo", Vector3(0, 1.4, -1), Vector3(8, 2.8, 6))
	waypoints = [Vector3(0, 0, -1)]
	if GameState.turno == 6:
		var boss := _GrasaBossEncounter.new()
		boss.name = "GrasaBossEncounter"
		boss.floor_ref = self
		add_child(boss)
		var term := WorldObjects.simple(self, _ResignTerminal, "TerminalRenuncia", "HUD_TURNSTILE", Vector3(-4.5, 0.6, 11.0), Vector3(0.8, 1.2, 0.6), Color(0.85, 0.12, 0.12), 90.0, 1.8)
		term.name = "TerminalRenuncia"
		Greybox.light(self, Vector3(-4.5, 1.8, 11.0), Color(0.2, 0.9, 0.95), 2.2, 7.5).name = "FaroTerminalRenuncia"
		var st := get_node_or_null("/root/SteamManager")
		if st != null and st.has_method("unlock"):
			st.call("unlock", "FACE_GRASA")


## Azotea: cielo degradado (noche de Lima con resplandor naranja en el horizonte). v0.3 (J #52): más
## visible (ambiente 0,3 → 0,45, bruma que deja ver la ciudad) y con lluvia; sigue siendo de madrugada.
func env_settings() -> Dictionary:
	return {
		"ambient": Color(0.24, 0.28, 0.36), "ambient_energy": 0.55,
		"fog": Color(0.07, 0.065, 0.075), "fog_density": 0.006, "bg": Color(0.02, 0.022, 0.035),
		"sky": {"top": Color(0.012, 0.014, 0.03), "horizon": Color(0.22, 0.12, 0.06), "ground": Color(0.03, 0.03, 0.035)},
	}


func grading() -> Dictionary:
	return {"tint": Color(0.94, 0.97, 1.06), "sat": 0.74, "contrast": 1.05, "exterior": true}


func ambience_events() -> Array[String]:
	return ["susurro", "silencio"]


func ambience_points() -> Array[Vector3]:
	return [Vector3(-8, 1.2, 16), Vector3(8, 1.2, 18)]


# --- v0.3 P2 -------------------------------------------------------------------------------------

class _DeckDoor extends WorldObjects.Door:
	## v0.3.1 Q5 (B10): abierta a toda hora, con o sin login, en cualquier AUX.
	func _refresh() -> void:
		locked = false

	func hint_text() -> String:
		_refresh()
		return super.hint_text()

	func interact(p: Node) -> bool:
		_refresh()
		return super.interact(p)


## Ciudad alrededor (inspirada en la referencia de Joan, sin edificios reconocibles ni letreros): torres de
## oficinas al frente, avenida ancha con faroles abajo, un parque oscuro y el resplandor naranja.
func _city() -> void:
	Weather.skyline(self, 9, -120.0, 80.0, 45.0, 95.0, -30.0, 30, 16.0, 62.0, 0.3)
	Weather.skyline(self, 19, -140.0, 85.0, 100.0, 140.0, -30.0, 18, 20.0, 80.0, 0.22)
	Weather.skyline(self, 29, -60.0, -40.0, -40.0, 40.0, -30.0, 8, 14.0, 44.0, 0.25, true)
	# Al este (derecha del deck): la autopista elevada cruza la avenida; torres de luz, alta tensión y cerros.
	SiteProps.entorno_este(self, -30.0, 104.0, 36.0, -200.0, 160.0, 480.0)
	# Avenida: dos hileras de faroles de sodio (puntos) y luces de autos (una MultiMesh).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	for i in 46:
		var x := -115.0 + i * 5.0
		for z in [32.0, 40.0]:
			xs.append(Transform3D(Basis.from_scale(Vector3(0.6, 0.3, 0.6)), Vector3(x, -24.5, z)))
			cs.append(Color(1.0, 0.62, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 14:
		var cx := rng.randf_range(-100.0, 100.0)
		var lane := rng.randi_range(0, 1)
		xs.append(Transform3D(Basis.from_scale(Vector3(0.9, 0.25, 0.4)), Vector3(cx, -29.6, 35.0 + lane * 2.0)))
		cs.append(Color(1.0, 0.95, 0.85) if lane == 0 else Color(0.9, 0.1, 0.08))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Avenida"
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	add_child(mmi)
	var park := Greybox.box(self, "Parque", Vector3(-35, -30.2, 30), Vector3(40, 0.2, 30), Color(0.02, 0.035, 0.025), false)
	park.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		Greybox.box(self, "AntenaLuz%d" % i, Vector3(-30 + i * 35, 22.0, 70), Vector3(0.5, 0.5, 0.5), Greybox.ROJO, false, 3.0)
	var glow := Greybox.light(self, Vector3(0, 6, 40), Color(0.9, 0.6, 0.3), 0.45, 60.0)
	glow.set_meta("no_mood", true)


## Cafetería al aire libre (J #28): quiosco con toldo, microondas, expendedora, carta, bombillas en
## guirnalda y dos sombrillas. Abre con Break o Lunch (la puerta del deck). Comer aquí = lunch completo.
func _open_air_cafe() -> void:
	var k := Vector3(7.4, 0, 4.8)
	Greybox.box(self, "QuioscoBarra", k + Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 0.8), DECK)
	Greybox.box(self, "QuioscoTope", k + Vector3(0, 1.12, 0), Vector3(3.3, 0.05, 0.9), Greybox.GRIS_OSCURO, false)
	Greybox.box(self, "QuioscoFondo", k + Vector3(0, 1.3, -1.2), Vector3(3.2, 2.6, 0.12), Color(0.18, 0.16, 0.14))
	for i in 6:
		var stripe := Greybox.box(self, "Toldo%d" % i, k + Vector3(-1.35 + i * 0.54, 2.75, -0.55), Vector3(0.54, 0.04, 1.5), Color(0.55, 0.12, 0.1) if i % 2 == 0 else Color(0.75, 0.72, 0.62), false)
		stripe.rotation_degrees.x = 12.0
	for px in [-1.55, 1.55]:
		Greybox.box(self, "QuioscoPoste%d" % int(px * 10), k + Vector3(px, 1.35, 0.1), Vector3(0.08, 2.7, 0.08), Greybox.GRIS_OSCURO, false)
	WorldObjects.simple(self, WorldObjects.Microwave, "MicroondasAzotea", "HUD_MICROWAVE", k + Vector3(-0.9, 1.35, -0.1), Vector3(0.55, 0.38, 0.45), Greybox.GRIS_OSCURO)
	WorldObjects.simple(self, WorldObjects.Vending, "ExpendedoraAzotea", "HUD_VENDING", k + Vector3(1.95, 1.0, -0.75), Vector3(0.95, 2.0, 0.8), Color(0.25, 0.32, 0.3), -20.0, 0.5)
	var carta := Greybox.box(self, "Carta", k + Vector3(0.6, 1.9, -1.13), Vector3(1.3, 0.8, 0.03), Greybox.NEGRO, false)
	var ct := Greybox.label(carta, "", Vector3(0, 0, 0.02), 0.075, Color(0.9, 0.85, 0.7))
	ct.text = tr("ROOFTOP_MENU")
	var sign := WorldObjects.signage(self, "SIGN_ROOFTOP_CAFE", k + Vector3(0, 2.95, 0.25), 0.0, 0.17, Greybox.AMBAR)
	sign.name = "CartelCafeteriaAzotea"
	var luz := Greybox.light(self, k + Vector3(0, 2.3, 0.6), Color(1.0, 0.78, 0.5), 2.3, 7.5)
	luz.name = "LuzQuiosco"
	# Guirnalda de bombillas del quiosco a la pérgola (sin luces propias: solo emisivas).
	for i in 10:
		var t := float(i) / 9.0
		var p := (k + Vector3(-1.5, 2.6, 0.6)).lerp(Vector3(4.0, 2.85, 7.0), t)
		p.y -= sin(t * PI) * 0.45
		var b := Greybox.cylinder(self, "Guirnalda%d" % i, p, 0.045, 0.08, Greybox.AMBAR)
		b.material_override = Greybox.material(Greybox.AMBAR, 2.6 if i != 6 else 0.2)  # una está quemada
	# Sombrillas sobre dos mesas fuera de la pérgola.
	for sp in [Vector3(-6.5, 0, 15.5), Vector3(5.5, 0, 15.0)]:
		Greybox.box(self, "MesaSombrilla%d" % int(sp.x), sp + Vector3(0, 0.74, 0), Vector3(1.0, 0.05, 1.0), Greybox.BLANCO)
		Greybox.cylinder(self, "PieSombrilla%d" % int(sp.x), sp + Vector3(0, 1.2, 0), 0.03, 2.4, Greybox.INOX)
		Greybox.cylinder(self, "Sombrilla%d" % int(sp.x), sp + Vector3(0, 2.35, 0), 1.3, 0.35, Color(0.2, 0.24, 0.22), false, 0.9, 0.0, 0.05)
		for c in 2:
			Greybox.box(self, "SillaSombrilla%d_%d" % [int(sp.x), c], sp + Vector3(0, 0.45, 0.75 if c == 0 else -0.75), Vector3(0.42, 0.05, 0.42), Greybox.GRIS, false)
	HorrorProps.note(self, "NOTE_ROOFTOP", k + Vector3(-1.6, 1.0, 0.41), 0.0, false, 5.0)
	Greybox.marker(self, "cafeteria_azotea", Vector3(6.0, 0, 7.2), 160.0)
	Zone.make(self, "cafeteria_azotea", Vector3(0, 1.5, 11.1), Vector3(20, 3, 17.8))  # v0.3.2: desde z 2,2 (el vestíbulo llega al vidrio de z 2)


func _ambient() -> void:
	AudioManager.play_ambient("azotea_viento")
	EventBus.show_message.emit(tr("MSG_ROOFTOP"), 4.0)


class _ResignTerminal extends Interactable:
	func hint_text() -> String:
		return "Firmar renuncia escrita (Cláusula 9)" if Loc.lang != "en" else "Sign written resignation (Clause 9)"

	func interact(_p: Node) -> bool:
		GameState.flags["renuncia_firmada"] = true
		SaveSlots.bump_counter("reb", 5, "Jiroshi")
		AudioManager.play_sfx("molinete")
		EventBus.show_message.emit("Renuncia registrada. El turno se cierra..." if Loc.lang != "en" else "Resignation logged. Shift closing...", 3.0)
		GameState.shift_over = true
		GameState.running = false
		EventBus.shift_ended.emit()
		return true


## v0.4 · Encuentro Final de Terror contra GRASA (Jefe Final) en la Azotea (Sabado 31 Oct · Halloween).
class _GrasaBossEncounter extends Node3D:
	var floor_ref: FloorBase = null
	var grasa_actor: P5Actor = null
	var _grasa_sr: ScreamRig = null
	var _aura_light: OmniLight3D = null
	var _voice_t: float = 1.5
	var _step_t: float = 0.0
	var _line_i: int = 0
	var _exposure_s: float = 0.0
	var _triggered: bool = false

	const BOSS_LINES: Array = [
		["grasa/grasa_presencia", "GRASA: «Por fin subiste, Jiroshi. El Trainer murió abajo hace un año.»"],
		["grasa/grasa_atencion_piso", "GRASA: «¡ATENCIÓN EN EL PISO! ¡NADIE SE VA DE KIPUPAY!»"],
		["grasa/grasa_no_me_mires", "GRASA: «NO ME MIRES ASÍ… YO SOY LA CAMPAÑA.»"],
		["grasa/grasa_turno_extra", "GRASA: «TU CONTRATO SE RENUEVA ESTA NOCHE… PARA SIEMPRE.»"]
	]

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		if P5Actor.model_path("grasa") != "":
			grasa_actor = P5Actor.make(self, "grasa", 2.95, Vector3(0.0, 0.0, 12.5), 180.0, "GRASA")
			grasa_actor.floor_ref = floor_ref
			grasa_actor.play("idle", true, 0.65)
			# v0.4.1 fix: P5Actor no tiene CharacterRig; el ScreamRig se engancha a su modelo.
			_grasa_sr = ScreamRig.attach(grasa_actor.model, "grasa")
			if _grasa_sr != null:
				_grasa_sr.deform = 0.42
				_grasa_sr.gore = 0.85
				_grasa_sr.tremor = 1.8
		_aura_light = OmniLight3D.new()
		_aura_light.name = "LuzAbisalGrasa"
		_aura_light.position = Vector3(0.0, 2.2, 12.5)
		_aura_light.light_color = Color(0.95, 0.08, 0.05)
		_aura_light.light_energy = 4.2
		_aura_light.omni_range = 14.0
		add_child(_aura_light)
		AudioManager.play_sfx("grasa_risa_reversa", "Sala")
		GfxLens.kick(0.75, 1.5)

	func _process(delta: float) -> void:
		if _triggered or GameState.shift_over or Checkpoints.dying:
			return
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl == null or not is_instance_valid(pl):
			return
		var t_ms := Time.get_ticks_msec()
		if _aura_light != null:
			_aura_light.light_energy = 3.5 + 2.4 * sin(t_ms * 0.019)
		if grasa_actor != null and is_instance_valid(grasa_actor):
			grasa_actor.look_toward(pl.global_position)
			var dist := grasa_actor.global_position.distance_to(pl.global_position)
			var terror_k := clampf(1.0 - (dist - 2.2) / 14.0, 0.35, 1.0)
			if _grasa_sr != null and is_instance_valid(_grasa_sr):
				_grasa_sr.deform = clampf(terror_k + 0.07 * sin(t_ms * 0.025), 0.35, 1.0)
				_grasa_sr.look = 1.0
				_grasa_sr.look_at_point = pl.head.global_position if pl.head != null else pl.global_position + Vector3(0, 1.6, 0)
			# GRASA avanza lentamente hacia ti mientras rie y distorsiona tu vision
			if dist > 2.1 and dist < 17.5:
				var dir := (pl.global_position - grasa_actor.global_position)
				dir.y = 0.0
				if dir.length() > 0.1:
					grasa_actor.global_position += dir.normalized() * 1.45 * delta
					_aura_light.position = grasa_actor.global_position + Vector3(0, 2.2, 0)
				_step_t -= delta
				if _step_t <= 0.0:
					_step_t = 0.72
					AudioManager.play_sfx("grasa_paso_01" if int(t_ms / 700) % 2 == 0 else "grasa_paso_02", "Sala")
					GfxLens.kick(terror_k * 0.65, 0.35)
			_voice_t -= delta
			if _voice_t <= 0.0 and dist < 17.0:
				_voice_t = 6.2
				var entry: Array = BOSS_LINES[_line_i % BOSS_LINES.size()]
				_line_i += 1
				AudioManager.play_voice("grasa", str(entry[0]).get_file(), str(entry[1]), "Sala")
				GfxLens.kick(0.85, 0.9)
			if dist < 14.0:
				_exposure_s += delta
			# Captura letal si GRASA te alcanza (< 2.25 m) o te quedas paralizado en su aura > 24 s
			if dist <= 2.25 or _exposure_s >= 24.0:
				_triggered = true
				Checkpoints.request_death("grasa_azotea", "GRASA · Azotea Piso 9", "grasa")

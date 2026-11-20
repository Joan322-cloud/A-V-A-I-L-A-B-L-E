## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## Escenarios de P6a · modelos y caras (PLAN #20, #74, #77, #85): los 19 GLB v2 en assets/models (textura
## embebida en cada superficie, clips idle/walk/run/sit/type/jumpscare_main, pies en el suelo, sin T-pose en idle,
## sin la carpeta provisional models_v2), CharacterRig (no pisa ni tiñe los v2, Llauri con su modelo, Shero ~2,2 m
## con el afro y el mismo tamaño calvo), cabeza en alta (material _cara de 1024-2048 px) y cara de grito, clips
## propios de Trainer / Haime / Don Fermín, screamers con el modelo 3D (sin la cara 2D encima), pantalla de Vitzo
## con glitch, linterna de Don Fermín, caras y avatares de ref_caras_v2 (Shero calvo cuando está enojado).

const MODELS: Array[String] = ["agente_jiroshi", "agente_juan", "agente_llauri", "agente_marko", "agente_ttoom", "enfermera", "enfermero",
	"grasa", "guardia_fermin", "haime", "marleny", "mentor", "om", "papayala", "perrito_rta", "rasec", "shero", "trainer", "vitzo"]
const NON_HUMAN: Array[String] = ["perrito_rta", "vitzo"]
const HD_HEADS: Dictionary = {"trainer": 2048, "haime": 2048, "grasa": 2048, "guardia_fermin": 1024, "enfermero": 1024}


func escenarios() -> Array[String]:
	return ["p6_modelos", "p6_modelos_pose", "p6_rig_v2", "p6_shero_altura", "p6_clips_propios", "p6_screamer_modelos", "p6_vitzo_glitch", "p6_caras"]


func run(id: String, _arg: String, t: Node) -> void:
	match id:
		"p6_modelos": await _modelos(t)
		"p6_modelos_pose": await _pose(t)
		"p6_rig_v2": await _rig(t)
		"p6_shero_altura": await _shero(t)
		"p6_clips_propios": await _clips(t)
		"p6_screamer_modelos": await _screamers(t)
		"p6_vitzo_glitch": await _glitch(t)
		"p6_caras": await _caras(t)


static func load_model(slug: String) -> Node3D:
	var ps := load("res://assets/models/%s.glb" % slug) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


static func anim_of(n: Node) -> AnimationPlayer:
	for c in n.find_children("*", "AnimationPlayer", true, false):
		return c as AnimationPlayer
	return null


static func skel_of(n: Node) -> Skeleton3D:
	for c in n.find_children("*", "Skeleton3D", true, false):
		return c as Skeleton3D
	return null


func _modelos(t: Node) -> void:
	t.check(not DirAccess.dir_exists_absolute("res://assets/models_v2"), "la copia provisional assets/models_v2 ya no existe")
	var files := DirAccess.get_files_at("res://assets/models")
	var glbs := 0
	for f in files:
		if f.ends_with(".glb"):
			glbs += 1
	t.check(glbs == MODELS.size(), "%d GLB en assets/models (esperados %d)" % [glbs, MODELS.size()])
	for slug in MODELS:
		var m := load_model(slug)
		if not t.check(m != null, "carga %s.glb" % slug):
			continue
		var ap := anim_of(m)
		t.check(ap != null and skel_of(m) != null, "%s: esqueleto y AnimationPlayer" % slug)
		var need := ["idle", "walk", "run", "jumpscare_main"] + ([] if slug in NON_HUMAN else ["sit", "type", "sprint", "point", "stare_camera", "jumpscare_alt"])
		for c in need:
			t.check(ap != null and ap.has_animation(c), "%s: clip %s" % [slug, c])
		var surf := 0
		var textured := 0
		var cara := false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for i in (mesh.get_surface_count() if mesh != null else 0):
				surf += 1
				var mat := mesh.surface_get_material(i) as BaseMaterial3D
				if mat != null and mat.albedo_texture != null:
					textured += 1
					if mat.resource_name.ends_with("_cara"):
						cara = true
						var px := mat.albedo_texture.get_width()
						t.check(px >= int(HD_HEADS.get(slug, 1024)), "%s: cabeza en alta (%d px)" % [slug, px])
		t.check(surf > 0 and textured == surf, "%s: %d/%d superficies con textura embebida" % [slug, textured, surf])
		if HD_HEADS.has(slug):
			t.check(cara, "%s: material _cara (cabeza propia en alta)" % slug)
			if slug != "enfermero":
				t.check(Faces.texture_at("res://assets/textures/%s_cara_grito.jpg" % slug) != null, "%s: textura de cara de grito" % slug)
		m.free()


## Pies en el suelo y nada de T-pose: idle avanzado, huesos en mundo.
func _pose(t: Node) -> void:
	var root := Node3D.new()
	t.get_tree().root.add_child(root)
	for slug in MODELS:
		var rig := CharacterRig.attach(root, slug, 1.75)
		if not t.check(rig != null, "attach %s" % slug):
			continue
		for clip in (["idle", "walk", "run"] if slug in NON_HUMAN else ["idle", "walk", "run", "sit", "type"]):
			rig.play(clip, true)
			if rig.animator != null:
				# v0.3.2-anim: la pose la escribe el AnimationTree en _process (la marcha entra en ~0,2 s); el AnimationPlayer
				# está apagado y hacerle seek no mueve nada (antes esto medía la pose de un instante al azar del idle).
				await t.seconds(0.5)
			else:
				rig.anim.advance(0.0)
				rig.anim.seek(0.4, true)
			var sk := skel_of(rig)
			sk.force_update_all_bone_transforms()
			var low := INF
			for i in sk.get_bone_count():
				low = minf(low, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
			if clip in ["idle", "walk", "run"]:
				t.check(low > -0.12 and low < 0.2, "%s/%s: pies en el suelo (hueso más bajo a %.2f m)" % [slug, clip, low])
			if slug in NON_HUMAN:
				continue
			var hand := sk.find_bone("hand_l")
			var arm := sk.find_bone("upperarm_l")
			if hand >= 0 and arm >= 0 and clip in ["idle", "walk"]:
				var hy := (sk.global_transform * sk.get_bone_global_pose(hand)).origin.y
				var ay := (sk.global_transform * sk.get_bone_global_pose(arm)).origin.y
				if rig.animator != null:
					# v0.3.2-anim: el idle de algunos personajes es un gesto (Shero de brazos cruzados: manos al pecho; el Trainer
					# presentando: un brazo extendido), así que «mano 20 cm bajo el hombro» ya no vale para idle. Sin T-pose =
					# el clip sacó los dos brazos de la pose de reposo del modelo; caminando, además, las manos cuelgan.
					var moved := 180.0
					for bn in ["upperarm_l", "upperarm_r"]:
						var bi := sk.find_bone(bn)
						if bi >= 0:
							moved = minf(moved, rad_to_deg(sk.get_bone_pose_rotation(bi).angle_to(sk.get_bone_rest(bi).basis.get_rotation_quaternion())))
					t.check(moved > 8.0 and hy < ay - (0.2 if clip == "walk" else 0.03), "%s/%s: sin T-pose (brazos a %.0f° de la pose de reposo, mano %.2f m bajo el hombro)" % [slug, clip, moved, ay - hy])
				else:
					t.check(hy < ay - 0.2, "%s/%s: sin T-pose (mano %.2f m bajo el hombro)" % [slug, clip, ay - hy])
		rig.queue_free()
	root.queue_free()
	await t.frames(1)


func _rig(t: Node) -> void:
	var root := Node3D.new()
	t.get_tree().root.add_child(root)
	var seen := {}
	for agent in GameState.AGENTS:
		var m := CharacterRig.agent_model(agent)
		seen[m] = true
		t.check(ResourceLoader.exists("res://assets/models/%s.glb" % m), "%s → %s.glb" % [agent, m])
	t.check(seen.size() == GameState.AGENTS.size(), "cada agente con su modelo (Llauri ya no usa el de Marko)")
	t.check(CharacterRig.agent_model("Llauri") == "agente_llauri", "Llauri → agente_llauri")
	var r := CharacterRig.attach(root, "agente_marko", 1.7)
	t.check(r.is_v2, "agente_marko es v2")
	var overrides := 0
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		for i in ((mi as MeshInstance3D).mesh.get_surface_count()):
			if (mi as MeshInstance3D).get_surface_override_material(i) != null:
				overrides += 1
	t.check(overrides == 0, "_apply_textures no pisa los materiales v2 (%d overrides)" % overrides)
	r.tint_outfit(Color(1, 0, 0))
	var tinted := 0
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		for i in ((mi as MeshInstance3D).mesh.get_surface_count()):
			if (mi as MeshInstance3D).get_surface_override_material(i) != null:
				tinted += 1
	t.check(tinted == 0, "tint_outfit no tiñe los v2")
	# NpcFigure: las figuras de P2 usan su modelo propio
	for pair in [["Fermin", "guardia_fermin"], ["Marleny", "marleny"], ["MentorFigura", "mentor"], ["Enfermera", "enfermera"]]:
		var n := NpcFigure.make(root, "agente_ttoom", Vector3.ZERO, 0.0, 1.7, Color(0.2, 0.2, 0.4), pair[0])
		t.check(n.rig != null and n.rig.model_name == pair[1], "NpcFigure %s → %s" % [pair[0], n.rig.model_name if n.rig != null else "—"])
	# El cuerpo del jugador en 1.ª persona usa el rig v2 del agente elegido
	await t.start_shift("Llauri", 1)
	var p: Player = t.player()
	var body := p.get("_rig") as CharacterRig
	t.check(body != null and body.model_name == "agente_llauri" and body.is_v2, "cuerpo en 1.ª persona: %s" % (body.model_name if body != null else "—"))
	root.queue_free()
	await t.frames(1)


func _shero(t: Node) -> void:
	var root := Node3D.new()
	t.get_tree().root.add_child(root)
	var r := CharacterRig.attach(root, "shero", 1.85)  # P3 pide 1,85: el v2 manda 2,2 m (con el afro)
	var afro := r.find_child("Afro", true, false) as Node3D
	t.check(afro != null and afro.visible, "Shero v2 con nodo Afro visible")
	var h := r._height(r.get_child(0) as Node3D) * (r.get_child(0) as Node3D).scale.y
	t.check(absf(h - 2.2) < 0.03, "Shero mide %.2f m con el afro" % h)
	var sc := (r.get_child(0) as Node3D).scale
	r.set_look("calvo")
	t.check(not afro.visible and (r.get_child(0) as Node3D).scale == sc, "calvo: Afro oculto y el cuerpo no cambia de tamaño")
	r.set_look("afro")
	t.check(afro.visible, "vuelve el afro")
	var rs := CharacterRig.attach(root, "rasec", 1.84)
	var pelo := rs.find_child("Pelo", true, false) as Node3D
	t.check(pelo != null and not pelo.visible, "Rasec aparece calvo")
	rs.set_look("pelo")
	t.check(pelo.visible, "Rasec con pelo (música / evento)")
	root.queue_free()
	await t.frames(1)


## Los clips propios ya no son el jumpscare_main compartido: duración y que la mandíbula se abre.
func _clips(t: Node) -> void:
	var lengths := {}
	for slug in ["trainer", "haime", "guardia_fermin", "mentor"]:
		var m := load_model(slug)
		var ap := anim_of(m)
		var a := ap.get_animation("jumpscare_main")
		lengths[slug] = snappedf(a.length, 0.01)
		var sk := skel_of(m)
		var jaw := sk.find_bone("jaw")
		var tr_idx := -1
		for i in a.get_track_count():
			if str(a.track_get_path(i)).ends_with(":jaw") and a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				tr_idx = i
		if slug != "mentor":
			t.check(jaw >= 0 and tr_idx >= 0, "%s: el jumpscare propio anima la mandíbula" % slug)
			if tr_idx >= 0:
				var q0: Quaternion = a.rotation_track_interpolate(tr_idx, 0.0)
				var ang := 0.0
				for k in 21:
					ang = maxf(ang, rad_to_deg(q0.angle_to(a.rotation_track_interpolate(tr_idx, a.length * k / 20.0))))
				t.check(ang > (30.0 if slug == "trainer" else 15.0), "%s: la boca se abre %.0f°" % [slug, ang])
		m.free()
	t.note("duraciones jumpscare_main: %s" % str(lengths))
	t.check(lengths["trainer"] != lengths["mentor"] and lengths["haime"] != lengths["mentor"] and lengths["guardia_fermin"] != lengths["mentor"], "Trainer, Haime y Don Fermín tienen su propio clip")
	var g := load_model("guardia_fermin")
	var has_lens := false
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var mat := (mi as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.resource_name.ends_with("_brillo") and mat.emission_enabled:
				has_lens = true
	t.check(has_lens, "Don Fermín: linterna con lente emisiva")
	g.free()
	var hm := load_model("haime")
	var rec := false
	for mi in hm.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var mat := (mi as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.resource_name.ends_with("_brillo"):
				rec = true
	t.check(rec, "Haime: headset con el punto REC emisivo")
	hm.free()


## Muere por cada asesino y mira el screamer: modelo 3D, cara de grito, sin la cara 2D tapándolo.
func _screamers(t: Node) -> void:
	var cases := [["training_reprobado", "trainer", "trainer"], ["calibracion_final", "haime", "haime"], ["break_excedido", "shero", "shero"],
		["rasec_evento", "rasec", "rasec"], ["aux_incorrecto", "rta", "perrito_rta"], ["wmm_correo_vitzo", "vitzo", "vitzo"],
		["coaching", "shero", "shero"], ["tercer_ww", "shero", "shero"]]
	for c in cases:
		await t.start_shift("Jiroshi", 2)
		await t.login_at_seat()
		GameState.stop_calm()
		var seen := {"model": false, "textured": false, "big_face": false, "scream": false, "flash": false}
		t.die(c[0], "", c[1])
		var waited := 0.0
		while waited < 6.0 and not Checkpoints.death_visible:
			await t.get_tree().process_frame
			waited += t.get_process_delta_time()
			var fx := t.get_tree().root.find_child("Screamer", false, false)
			var stage := t.get_tree().root.find_child("EscenarioScreamer", true, false)
			if stage != null:
				var a := stage.find_child("Asesino_" + str(c[2]), false, false)
				if a != null and a.has_meta("scene"):
					seen["model"] = true
					var sc := a.get_meta("scene") as Node
					seen["textured"] = CharacterRig._has_embedded_textures(sc as Node3D)
					for mi in sc.find_children("*", "MeshInstance3D", true, false):
						for i in (mi as MeshInstance3D).mesh.get_surface_count():
							var om := (mi as MeshInstance3D).get_surface_override_material(i)
							var o := om as BaseMaterial3D
							if o != null and o.albedo_texture != null and o.albedo_texture.resource_path.contains("cara_grito"):
								seen["scream"] = true
							# v0.3.1 Q2: la cara deformable (ScreamRig) lleva la cara de grito en el shader.
							var sm := om as ShaderMaterial
							if sm != null and sm.get_shader_parameter("has_scream_tex") == true:
								var st := sm.get_shader_parameter("scream_tex") as Texture2D
								if st != null and st.resource_path.contains("cara_grito"):
									seen["scream"] = true
			if fx != null:
				for tr in fx.find_children("*", "TextureRect", true, false):
					var r := tr as TextureRect
					if r.name == "DestelloCara":
						seen["flash"] = true
					elif bool(seen["model"]) and r.visible and r.modulate.a > 0.5 and r.scale.x > 1.4:
						seen["big_face"] = true
		t.check(bool(seen["model"]) and bool(seen["textured"]), "%s: modelo 3D v2 con textura en el screamer" % c[0])
		t.check(not bool(seen["big_face"]), "%s: la cara 2D no tapa al modelo" % c[0])
		if c[2] in ["trainer", "haime"]:
			t.check(bool(seen["scream"]), "%s: cara de grito en el clímax" % c[0])
		t.check(await t.wait_death_shown(6.0), "%s: llega la pantalla" % c[0])
		var av := (t.death_screen().find_child("AvatarAsesino", true, false) as TextureRect)
		t.check(av != null and av.texture != null, "%s: avatar de quien te mató en la pantalla" % c[0])
		await t.reconnect()
	# Don Fermín (aún no mata en la v0.3): screamer directo con su linterna
	await t.start_shift("Jiroshi", 1)
	await t.login_at_seat()
	var got := {"light": false}
	var fn := func() -> void:
		var spot := t.get_tree().root.find_child("Linterna", true, false)
		if spot != null and spot.get_child_count() > 0:
			got["light"] = true
	t.get_tree().process_frame.connect(fn)
	await Screamers.play("guardia", "p6_demo", "")
	t.get_tree().process_frame.disconnect(fn)
	t.check(bool(got["light"]), "Don Fermín se abalanza con la linterna (SpotLight en la mano)")


func _glitch(t: Node) -> void:
	var root := Node3D.new()
	t.get_tree().root.add_child(root)
	var r := CharacterRig.attach(root, "vitzo", 1.0)
	var scene := r.get_child(0)
	var mats: Array = scene.get_meta("vitzo_glitch", [])
	t.check(mats.size() >= 1, "Vitzo: pantalla con shader de glitch (%d)" % mats.size())
	VitzoGlitch.set_intensity(scene, 1.0)
	t.check(is_equal_approx(float((mats[0] as ShaderMaterial).get_shader_parameter("intensity")), 1.0), "la intensidad sube en el screamer")
	t.check((mats[0] as ShaderMaterial).get_shader_parameter("tex") != null, "usa la textura del atlas (la cara se deforma, no se reemplaza)")
	root.queue_free()
	await t.frames(1)


func _caras(t: Node) -> void:
	for slug in ["shero", "shero_calvo", "haime", "trainer", "grasa", "rasec", "rasec_pelo", "perrito_rta", "vitzo", "jiroshi", "marko", "llauri", "ttoom", "juan", "papayala", "enfermero", "guardia_fermin", "marleny", "mentor", "om"]:
		t.check(Faces.has_face(slug), "cara 512 px de " + slug)
		t.check(Faces.texture_at("res://assets/ui/ezlak/%s.png" % slug) != null or slug in ["papayala"], "avatar de Ezlaki de " + slug)
	t.check(Faces.agent_slug("Juan") == "juan", "Juan ya tiene cara (no la silueta)")
	# El avatar de Shero en Ezlaki pasa a calvo cuando está enojado
	t.check(Faces.mood_slug("shero") == "shero" or Faces.shero_is_bald(), "Shero normal: afro")
	# Desde el merge con P3 (v0.3-merge-p6) lo decide Discipline.shero_bald(): un WW reciente lo pone calvo.
	var calm_was := GameState.in_calm
	GameState.in_calm = false
	Discipline.set("_bald_until_clock", GameState.clock_seconds + 600.0)
	t.check(Faces.mood_slug("shero") == "shero_calvo", "Shero enojado (WW reciente) → avatar shero_calvo")
	t.check(EzlakHub.avatar("shero") == Faces.texture_at("res://assets/ui/ezlak/shero_calvo.png"), "EzlakHub.avatar usa el calvo")
	Discipline.set("_bald_until_clock", -INF)
	GameState.in_calm = calm_was
	t.check(Faces.mood_slug("shero") == "shero", "con la calma vuelve el afro")
	t.check(Faces.killer_avatar_slug("shero") == "shero_calvo" and Faces.killer_avatar_slug("rta") == "perrito_rta_enojado", "avatares de la pantalla de muerte")
	await t.frames(1)


class _BaldShero extends Node:
	var bald: bool = true

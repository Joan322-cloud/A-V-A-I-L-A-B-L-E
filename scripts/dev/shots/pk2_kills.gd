## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas del paquete kills v0.3.2.
##   k2_fusion_modelo:<agente>[:<grados>[:<dist>[:<etapa>]]]   el agente fusionado con Vitzo (fx/vitzo_fusion.gd) solo,
##       con luz de estudio y fondo verde, visto desde <grados> (0 = de frente, 90 = perfil) a <dist> m de la cabeza
##       (0 = cuerpo entero); etapa 0..1 (1 = fusión completa).
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 -- --shot k2_fusion_modelo:Jiroshi:0:0.6


func shots() -> Array[String]:
	return ["k2_fusion_modelo:"]


func shoot(name: String, arg: String, s: Node) -> void:
	Dread.forced = -1.0
	if name != "k2_fusion_modelo":
		return
	var parts := arg.split(":")
	var agent := parts[0] if parts.size() > 0 and parts[0] != "" else "Jiroshi"
	var deg := float(parts[1]) if parts.size() > 1 else 0.0
	var dist := float(parts[2]) if parts.size() > 2 else 0.6
	var st := float(parts[3]) if parts.size() > 3 else 1.0
	await s._place(2, Vector3(20.5, 0, 0.8), -55.0, 0.0)
	GameState.stop_calm()
	var p: Player = s._player()
	var old := p.get_parent().get_node_or_null("LabFusion")
	if old != null:
		old.free()
	var lab := Node3D.new()
	lab.name = "LabFusion"
	p.get_parent().add_child(lab)
	lab.global_position = Vector3(0, 60.0, 0)  # lejos del piso: nada tapa
	# Fondo verde (como el concepto) y luces de estudio.
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(12, 8, 12)
	bm.flip_faces = true
	bg.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.62, 0.36)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = mat
	bg.position = Vector3(0, 2.0, 0)
	lab.add_child(bg)
	for d in [[Vector3(1.2, 2.2, -1.8), 2.4], [Vector3(-1.6, 1.6, -1.2), 1.2], [Vector3(0, 2.4, 1.6), 0.9]]:
		var l := OmniLight3D.new()
		l.light_energy = float(d[1])
		l.omni_range = 6.0
		l.position = d[0]
		lab.add_child(l)
	var root := VitzoFusion.build_at(lab, agent)
	if st < 1.0:
		VitzoFusion.stage(root, st, st, st, st)
	if parts.size() > 4 and parts[4] == "raw":  # sin utilería: solo el modelo del agente con la piel verde
		for n in ["CaraFusion", "PechoFusion"]:
			var c := root.find_child(n, true, false) as Node3D
			if c != null:
				c.visible = false
	if parts.size() > 5 and root.has_meta("rig"):  # un clip del rig a mitad (para elegir poses)
		(root.get_meta("rig") as CharacterRig).play(parts[5], true, 1.0, ["idle"])
		await s.get_tree().create_timer(float(parts[6]) if parts.size() > 6 else 0.5).timeout
	if parts.size() > 4 and parts[4] == "tic":
		VitzoFusion.set_twitch(root, true)
	var head: Vector3 = root.global_transform * (root.get_meta("head", Vector3(0, 1.6, 0)) as Vector3)
	var cam := Camera3D.new()
	cam.fov = 40.0
	lab.add_child(cam)
	var a := deg_to_rad(deg)
	var fwd := -root.global_transform.basis.z  # el modelo mira a -Z
	var dir := fwd.rotated(Vector3.UP, a)
	if dist <= 0.0:
		cam.global_position = root.global_position + dir * 3.0 + Vector3(0, 1.0, 0)
		cam.look_at(root.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	else:
		cam.global_position = head + dir * dist + Vector3(0, -0.02, 0)
		cam.look_at(head - Vector3(0, 0.04, 0), Vector3.UP)
	cam.make_current()
	for c in s.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await s.get_tree().create_timer(0.5).timeout

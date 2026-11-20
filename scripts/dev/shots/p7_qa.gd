## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de la integración final (P7): las letras de los baños del -1 junto al cartel «Baños», la expendedora del
## -1 de frente, el resumen del turno (ShiftEnd) y una vista libre `p7_vista:<piso>,<x>,<y>,<z>,<giro>,<pitch>`.


func shots() -> Array[String]:
	return ["p7_banos_m1_h", "p7_banos_m1_m", "p7_expendedora", "p7_resumen", "p7_vista:"]


func shoot(name: String, arg: String, s: Node) -> void:
	match name:
		"p7_banos_m1_h":
			await s._place(-1, Vector3(-9.3, 0, -3.75), 180.0, 0.12)
			await s.get_tree().create_timer(0.4).timeout
		"p7_banos_m1_m":
			await s._place(-1, Vector3(-9.3, 0, 3.9), 0.0, 0.12)
			await s.get_tree().create_timer(0.4).timeout
		"p7_expendedora":
			await s._place(-1, Vector3(23.0, 0, 3.6), -90.0, -0.12)
			await s.get_tree().create_timer(0.4).timeout
		"p7_resumen":
			await s._sit_c14()
			Metrics.contacts_handled = 12
			Metrics.register_outcome("satisfecho", 5)
			EventBus.shift_ended.emit()
			await s.get_tree().create_timer(0.8).timeout
		"p7_vista":
			var v := arg.split(",")
			if v.size() >= 5:
				await s._place(int(v[0]), Vector3(float(v[1]), float(v[2]), float(v[3])), float(v[4]), float(v[5]) if v.size() > 5 else 0.0)
				await s.get_tree().create_timer(0.4).timeout


func after(name: String, s: Node) -> void:
	if name == "p7_resumen":
		s._main.call("_back_to_menu")
		await s.get_tree().create_timer(0.2).timeout
		s._main.call("_start_shift", "Jiroshi", GameState.Mode.NORMAL)
		await s.get_tree().create_timer(0.6).timeout

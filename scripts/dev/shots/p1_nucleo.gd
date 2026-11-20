## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## Vistas de P1: menú con partidas y dificultad, screamer genérico a mitad, animación de colapso (sin
## screamer) a mitad y pantalla de muerte con [Esc] Volver al menú.


func shots() -> Array[String]:
	return ["menu_partidas", "muerte_screamer", "muerte_colapso", "muerte_pantalla"]


func shoot(name: String, _arg: String, s: Node) -> void:
	match name:
		"menu_partidas":
			s._main.call("_back_to_menu")
			var menu: Control = s._main.get("main_menu")
			SaveSlots.select("Marko")
			menu.set("agent_index", GameState.AGENTS.find("Marko"))
			menu.call("_build")
			await s.get_tree().create_timer(0.4).timeout
		"muerte_screamer":
			await s._sit_c14()
			Engine.time_scale = 0.2  # fotogramas lentos en xvfb: así la captura cae a mitad del screamer
			Checkpoints.request_death("break_excedido", "16:00")
			await s.get_tree().create_timer(0.05).timeout  # + 0,8 s de screenshot.gd = a mitad del screamer (1,4 s)
		"muerte_colapso":
			await s._sit_c14()
			Engine.time_scale = 0.2
			Fatigue.set_value(95.0)
			Fatigue.add(10.0)
			await s.get_tree().create_timer(0.6).timeout  # + 0,8 s de screenshot.gd = a mitad del colapso (3 s)
		"muerte_pantalla":
			await s._sit_c14()
			Checkpoints.request_death("tercer_break")
			for _i in 60:
				await s.get_tree().create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
			await s.get_tree().create_timer(1.7).timeout  # que aparezcan [Espacio] y [Esc]


## Después de capturar: dejar el turno vivo para la siguiente vista.
func after(name: String, _s: Node) -> void:
	Engine.time_scale = 1.0
	if name.begins_with("muerte"):
		await _s.get_tree().create_timer(0.1).timeout
		if not Checkpoints.death_visible:
			for _i in 60:
				await _s.get_tree().create_timer(0.1).timeout
				if Checkpoints.death_visible:
					break
		Checkpoints.respawn()
		GameState.stop_calm()

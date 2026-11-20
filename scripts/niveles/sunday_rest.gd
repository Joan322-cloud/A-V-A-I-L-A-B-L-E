class_name SundayRestRoom
extends Node3D
## v0.4 · Turno 7 (Domingo 1 de noviembre · Día de descanso interactivo).
## Escena 3D interactiva en la habitación de Jiroshi en Lima (23:35 -> 23:48).
## El jugador camina en primera persona, examina sus recuerdos/documentos y responde el celular
## para desbloquear uno de los 5 finales de Jiroshi según todo lo que hizo en la semana.

var _phone_ringing: bool = true
var _ring_t: float = 0.0
var _examined: Dictionary = {}

func setup(player: Player) -> void:
	# Construir habitación acogedora de Jiroshi en Lima
	Greybox.floor_slab(self, "PisoCuarto", Vector2(0, 0), Vector2(7.0, 7.0), Color(0.24, 0.18, 0.14))
	Greybox.ceiling(self, "TechoCuarto", Vector2(0, 0), Vector2(7.0, 7.0), 2.8, Color(0.75, 0.74, 0.72))
	Greybox.room_walls(self, "ParedesCuarto", Vector2(0, 0), Vector2(7.0, 7.0), 2.8, Color(0.68, 0.7, 0.72), [])

	# Cama y velador
	Greybox.box(self, "CamaBase", Vector3(-2.1, 0.25, -2.0), Vector3(1.6, 0.5, 2.2), Color(0.22, 0.28, 0.36))
	Greybox.box(self, "Almohada", Vector3(-2.1, 0.56, -2.8), Vector3(0.9, 0.14, 0.45), Color(0.9, 0.9, 0.92), false)
	Greybox.box(self, "Velador", Vector3(-0.9, 0.32, -2.7), Vector3(0.55, 0.64, 0.55), Color(0.32, 0.22, 0.14))

	# Escritorio con laptop, contrato, polaroid y fotocheck
	Greybox.box(self, "Escritorio", Vector3(2.1, 0.38, -1.8), Vector3(1.1, 0.76, 2.2), Color(0.34, 0.24, 0.16))
	Greybox.box(self, "LaptopBase", Vector3(2.0, 0.78, -1.8), Vector3(0.42, 0.03, 0.32), Color(0.15, 0.16, 0.18), false)
	Greybox.box(self, "LaptopPantalla", Vector3(2.15, 0.92, -1.8), Vector3(0.03, 0.26, 0.32), Color(0.1, 0.35, 0.45), false, 0.8)

	# Ventana con vista nocturna de Lima
	Greybox.box(self, "VentanaMarco", Vector3(0.0, 1.55, -3.42), Vector3(2.2, 1.3, 0.08), Color(0.12, 0.14, 0.18), false)
	Greybox.box(self, "VentanaVidrio", Vector3(0.0, 1.55, -3.38), Vector3(2.0, 1.15, 0.02), Color(0.06, 0.1, 0.18), false, 0.45)

	# Luz cálida de lámpara de cuarto
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.45, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 1.6
	lamp.omni_range = 8.5
	add_child(lamp)

	# Objetos interactivos del Domingo
	_add_item("Fotocheck", Vector3(1.85, 0.80, -1.2), Vector3(0.18, 0.03, 0.24), Color(0.2, 0.7, 0.85), "fotocheck")
	_add_item("PolaroidPromo", Vector3(1.85, 0.80, -2.35), Vector3(0.22, 0.03, 0.22), Color(0.95, 0.92, 0.85), "polaroid")
	_add_item("ContratoCasa", Vector3(2.25, 0.80, -1.25), Vector3(0.26, 0.03, 0.34), Color(0.88, 0.84, 0.72), "contrato")
	_add_item("Celular2348", Vector3(-0.9, 0.68, -2.7), Vector3(0.16, 0.04, 0.26), Color(0.9, 0.2, 0.2), "celular")

	if player != null:
		player.teleport(Vector3(0.0, 0.0, 1.8), 180.0)
		player.input_locked = false

	GameState.logged_in = true
	GameState.clock_seconds = 23.0 * 3600.0 + 42.0 * 60.0  # 23:42 PM
	EventBus.show_message.emit("Domingo 1 de noviembre · Día de descanso. Examina tus cosas en el escritorio y contesta el celular en el velador." if Loc.lang != "en" else "Sunday, November 1 · Day off. Examine your items on the desk and answer the phone on the nightstand.", 6.0)

func _add_item(p_name: String, pos: Vector3, sz: Vector3, col: Color, kind: String) -> void:
	var obj := WorldObjects.simple(self, _SundayItem, p_name, "HUD_TURNSTILE", pos, sz, col, 0.0, 0.5)
	(obj as _SundayItem).kind = kind
	(obj as _SundayItem).room = self

func _process(delta: float) -> void:
	if not _phone_ringing or GameState.shift_over:
		return
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 3.2
		AudioManager.play_sfx("ezlak_mencion", "UI")

func on_examine(kind: String) -> void:
	_examined[kind] = true
	match kind:
		"fotocheck":
			SaveSlots.bump_counter("polaroid_vista", 1, "Jiroshi")
			EventBus.show_message.emit("Tu fotocheck de KipuPay (Puesto C-14). El código magnético sigue caliente." if Loc.lang != "en" else "Your KipuPay badge (Seat C-14). The magnetic strip is still warm.", 4.5)
		"polaroid":
			SaveSlots.bump_counter("polaroid_vista", 1, "Jiroshi")
			EventBus.show_message.emit("Foto de promoción (24 Oct 2025): Llauri, Marko, Ttoom, Juan y tú. Prometieron salir juntos de ahí." if Loc.lang != "en" else "Wave photo (Oct 24, 2025): Llauri, Marko, Ttoom, Juan, and you. You promised to make it out together.", 5.0)
		"contrato":
			var leido := bool(SaveSlots.progress("Jiroshi").get("contrato_leido", false))
			EventBus.show_message.emit(("Cláusula 15: Este contrato se renueva automáticamente cada domingo." if leido else "Un contrato indefinido lleno de letra chica que firmaste sin leer...") if Loc.lang != "en" else ("Clause 15: This contract renews automatically every Sunday." if leido else "An indefinite contract full of fine print you signed unread..."), 5.0)
		"celular":
			_phone_ringing = false
			AudioManager.play_sfx("molinete", "UI")
			var eid := EndingsManager.evaluate(false)
			EndingsManager.trigger_ending(eid)
			GameState.shift_over = true
			GameState.running = false
			EventBus.shift_ended.emit()

class _SundayItem extends Interactable:
	var kind: String = ""
	var room: SundayRestRoom = null

	func hint_text() -> String:
		match kind:
			"fotocheck": return "[E] Examinar Fotocheck de KipuPay" if Loc.lang != "en" else "[E] Examine KipuPay Badge"
			"polaroid": return "[E] Mirar Polaroid de Promoción" if Loc.lang != "en" else "[E] Look at Wave Polaroid"
			"contrato": return "[E] Revisar Contrato Indefinido" if Loc.lang != "en" else "[E] Review Indefinite Contract"
			"celular": return "[E] Contestar llamada de las 23:48 (Ver Final)" if Loc.lang != "en" else "[E] Answer 11:48 PM Call (Trigger Ending)"
		return "[E]"

	func interact(_p: Node) -> bool:
		if room != null:
			room.on_examine(kind)
		return true

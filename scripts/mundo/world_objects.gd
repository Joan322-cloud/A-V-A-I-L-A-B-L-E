class_name WorldObjects
extends RefCounted
## Fábrica de objetos interactuables del greybox: silla, terminal Fonex, casillero, refri,
## expendedora, microondas, máquina de agua, molinete, puerta, escalera, espejo, reloj de pared.
## Cada uno es una caja + Interactable con su lógica en una subclase pequeña (abajo).


static func seat(parent: Node, id: String, pos: Vector3, facing_deg: float, is_island: bool, monitors: int) -> Seat:
	var cub := Greybox.cubicle(parent, id, pos, facing_deg, monitors)
	var s := Seat.new()
	s.name = "Seat_" + id
	s.seat_id = id
	s.is_island = is_island
	s.hint_key = "HUD_SIT"
	s.size = Vector3(1.2, 1.5, 1.0)
	s.position = Vector3(0, 0.8, 0.4)
	cub.add_child(s)
	return s


## v0.3.2 (Joan: «quita los Fonex del resto del mapa, no es realista»): ya no se arman terminales de pared. El AUX
## solo se cambia en tu PC o en otra PC de la sala (regla «otra isla»), o con el comodín (Comodin). Queda la firma
## para el código que todavía la llama (training_session.gd): no crea nada y devuelve null.
static func terminal(_parent: Node, _id: String, _pos: Vector3, _rot_deg: float = 0.0) -> WallTerminal:
	return null


static func simple(parent: Node, cls: GDScript, p_name: String, hint: String, pos: Vector3, size: Vector3, color: Color, rot_deg: float = 0.0, emissive: float = 0.0) -> Interactable:
	var o: Interactable = cls.new()
	o.name = p_name
	o.hint_key = hint
	o.size = size + Vector3(0.4, 0.4, 0.4)
	o.position = pos
	o.rotation_degrees.y = rot_deg
	parent.add_child(o)
	Greybox.box(o, "Caja", Vector3.ZERO, size, color, true, emissive)
	return o


static func signage(parent: Node, key: String, pos: Vector3, rot_deg: float = 0.0, size: float = 0.3, color: Color = Greybox.BLANCO) -> Label3D:
	var l := Greybox.label(parent, "", pos, size, color, deg_to_rad(rot_deg))
	l.text = parent.tr(key)
	return l


# ---------------------------------------------------------------------------
# Subclases de Interactable (una por objeto). Cada una emite por EventBus.
# ---------------------------------------------------------------------------

class Seat extends Interactable:
	var seat_id: String = ""
	var is_island: bool = false
	var has_session: bool = false  # la sesión del jugador está en esta PC

	func hint_text() -> String:
		return tr("HUD_SIT")

	func interact(player: Node) -> bool:
		if not enabled:
			return false
		if player is Player:
			(player as Player).sit_at(self, seat_id)
			if not is_island:
				EventBus.show_message.emit(tr("MSG_SEAT_OTHER_ISLAND"), 3.0)
			return true
		return false


## v0.3 P2: silla de la sala 2 de training (piso 1). No es de ninguna isla: emite player_seated con un id
## "training_sala2_N" (P3: no cuenta para "otra isla"; P5: training_session.gd la usa).
class TrainingSeat extends Seat:
	func interact(player: Node) -> bool:
		if not enabled:
			return false
		if player is Player:
			(player as Player).sit_at(self, seat_id)
			return true
		return false


class WallTerminal extends Interactable:
	var terminal_id: String = ""

	func interact(_player: Node) -> bool:
		if not enabled:
			return false
		AudioManager.play_sfx("fonex_cambio_aux", "UI")
		var ws := _find_workstation()
		if ws != null:
			ws.call("open_terminal", terminal_id)
		interacted.emit(_player)
		return true

	func _find_workstation() -> Node:
		return get_tree().get_first_node_in_group("workstation")


class Locker extends Interactable:
	var used: bool = false

	func hint_text() -> String:
		return tr("HUD_LOCKER")

	func interact(_player: Node) -> bool:
		if used:
			return false
		used = true
		AudioManager.play_sfx("casillero_abrir")
		GameState.flags["locker_done"] = true
		EventBus.show_message.emit(tr("MSG_LOCKER_DONE"), 4.0)
		Checkpoints.save_checkpoint("inicio")
		# v0.3.1 Q4 (F15): abrir, colgar la mochila, cerrar con llave (manos en cámara + puerta que gira).
		var m := ManosFx.for_player(_player)
		var d := m.play("casillero") if m != null else 0.0
		DoorSwing.swing(self, _player, 0.0, 1.9, 0.8)
		if d > 0.0:
			get_tree().create_timer(1.9).timeout.connect(func() -> void: AudioManager.play_sfx("casillero_cerrar"))
			get_tree().create_timer(2.15).timeout.connect(func() -> void: AudioManager.play_sfx("lanyard_tintineo", "UI"))
		interacted.emit(_player)
		return true


## v0.3.1 Q4 (F15, D4): refri del -1 o del piso 2 (cualquiera sirve). Antes del lunch: dejas el taper con tu
## nombre en cinta; en el lunch: lo sacas. lunch_stored / lunch_in_hand se mantienen para el código viejo.
class Fridge extends Interactable:
	func hint_text() -> String:
		match TaperFlow.state():
			TaperFlow.MOCHILA:
				return tr("Q4_HUD_FRIDGE_LEAVE")
			TaperFlow.REFRI:
				return tr("Q4_HUD_FRIDGE_TAKE") if TaperFlow.lunch_now() else tr("HUD_FRIDGE")
		return tr("HUD_FRIDGE")

	func interact(_player: Node) -> bool:
		AudioManager.play_sfx("refri")
		TaperFlow.check_spoiled()
		var st := TaperFlow.state()
		var m := ManosFx.for_player(_player)
		if st == TaperFlow.MOCHILA:
			TaperFlow.set_state(TaperFlow.REFRI)
			EventBus.show_message.emit(Loc.fmt(tr("Q4_MSG_TAPER_IN"), {"agente": GameState.agent}), 3.0)
			if m != null:
				m.play("refri_dejar")
			DoorSwing.swing(self, _player, 0.0, 1.85, 1.2)
		elif st == TaperFlow.REFRI:
			if TaperFlow.lunch_now():
				TaperFlow.set_state(TaperFlow.MANO)
				EventBus.show_message.emit(tr("Q4_MSG_TAPER_OUT"), 3.0)
				if m != null:
					m.play("refri_sacar")
				DoorSwing.swing(self, _player, 0.0, 1.3, 1.2)
			else:
				EventBus.show_message.emit(tr("Q4_MSG_TAPER_WAIT"), 3.0)
				DoorSwing.swing(self, _player, 0.0, 0.7, 1.2)
		elif st == TaperFlow.MALOGRADO:
			EventBus.show_message.emit(tr("Q4_MSG_TAPER_SPOILED"), 3.0)
		else:
			DoorSwing.swing(self, _player, 0.0, 0.7, 1.2)
		interacted.emit(_player)
		return true


class Vending extends Interactable:
	func hint_text() -> String:
		return tr("HUD_VENDING_T2") if Economy.active() else tr("HUD_VENDING")

	func interact(_player: Node) -> bool:
		AudioManager.play_sfx("expendedora")
		if Economy.active():
			# v0.2: menú con precios (café / energética / gotas) que se paga del saldo.
			EventBus.shop_opened.emit("expendedora", tr("SHOP_VENDING_TITLE"), Economy.shop_items("expendedora"))
			interacted.emit(_player)
			return true
		if GameState.flags.get("coffee_used", false):
			EventBus.show_message.emit(tr("MSG_COFFEE_USED"), 3.0)
		else:
			GameState.flags["coffee_used"] = true
			Fatigue.add(float(DataLoader.bal("fatiga/cafe", -15.0)))
			EventBus.show_message.emit(tr("MSG_COFFEE"), 3.0)
		interacted.emit(_player)
		return true


## Mostrador de Marleny (cafetería del -1, T3+): menú caliente que cuenta como lunch completo.
class Counter extends Interactable:
	func hint_text() -> String:
		return tr("HUD_COUNTER")

	func interact(_player: Node) -> bool:
		if not GameState.flags.get("marleny_saludo", false):
			GameState.flags["marleny_saludo"] = true
			var lines: Array = DataLoader.dict("lineas_neutrales").get("marleny", {}).get("saludo", [])
			if not lines.is_empty():
				AudioManager.play_voice("otros", "marleny_saludo", "[Marleny] " + Loc.pick(lines[randi() % lines.size()]), "Sala")
		EventBus.shop_opened.emit("cafeteria_marleny", tr("SHOP_MARLENY_TITLE"), Economy.shop_items("cafeteria_marleny"))
		interacted.emit(_player)
		return true


## Efecto de una compra (expendedora o Marleny): Fatiga, gotas (sin desenfoque un rato), lunch.
static func apply_purchase(shop_id: String, item: Dictionary) -> void:
	var id := str(item.get("id", ""))
	var fat := float(item.get("fatiga", 0.0))
	if fat != 0.0:
		Fatigue.add(fat)
	if item.has("desenfoque_off_s"):
		Fatigue.suppress_blur(float(item.get("desenfoque_off_s", 240.0)))
		EventBus.show_message.emit(Loc.tr("MSG_GOTAS"), 3.0)
	elif shop_id == "expendedora":
		EventBus.show_message.emit(Loc.fmt(Loc.tr("MSG_ENERGETICA" if id != "cafe" else "MSG_COFFEE_T2"), {"n": int(fat)}), 3.0)
	else:
		EventBus.show_message.emit(Loc.fmt(Loc.tr("MSG_MARLENY_LUNCH"), {"n": int(fat)}), 3.0)
	if bool(item.get("lunch", false)) and not GameState.flags.get("lunch_eaten", false):
		GameState.flags["lunch_eaten"] = true
		Checkpoints.save_checkpoint("lunch")


## v0.3.1 Q4 (F15, D5): microondas de la cafetería del -1 (2 filas de 3 + lavadero; los pone Q5). Uno está fuera
## de servicio y otros ocupados con tapers ajenos que terminan solos (cuenta regresiva en la puerta). Con tu taper
## en la mano: lo metes, 60 s de juego con cuenta regresiva y vapor, «ding», lo sacas caliente y lo comes en una
## mesa (EatSpot). Compatibilidad: sin la nueva mecánica (flag lunch_in_hand de la v0.2) también calienta.
class Microwave extends Interactable:
	var state: String = ""  # "" (sin asignar) | libre | ocupado | fuera | mio_calentando | mio_listo
	var until: float = 0.0  # reloj de juego en que termina lo que calienta
	var tape: String = ""
	var _label: Label3D = null
	var _light: OmniLight3D = null
	var _steam: CPUParticles3D = null
	var eternal: bool = false  # el taper de C-13: ocupado para siempre, sin cuenta ni «ding»
	var dings: int = 0  # «ding» que sonaron (pruebas)
	var _last_ding_ms: int = -100000
	static var _any_ding_ms: int = -100000
	const DING_MIN_S := 3.0

	func _ready() -> void:
		super._ready()
		add_to_group("microondas")
		_ensure_fridge.call_deferred()
		_ensure_tables.call_deferred()

	## v0.3.2: las mesas de la cafetería de este piso (-1 o azotea) sirven para comer el taper (una por mesa, siempre).
	func _ensure_tables() -> void:
		if is_inside_tree():
			TaperFlow.ensure_eat_spots(TaperFlow.floor_of(self), self)

	## D4: la refri de la cafetería del -1 también es interactiva. Si el piso solo trae la caja (RefriCafe, sin
	## lógica), se le pone encima un Fridge invisible del mismo tamaño; si el piso ya trae un Fridge, nada.
	func _ensure_fridge() -> void:
		var fl := TaperFlow.floor_of(self)
		if fl == null or not is_inside_tree():
			return
		for c in fl.find_children("*", "", true, false):  # v0.3.1: Q5 pone RefriM1_1/RefriM1_2 (Fridge) en el -1
			if c is Fridge:
				return
		var box := fl.get_node_or_null("RefriCafe") as Node3D
		if box == null:
			return
		var f := Fridge.new()
		f.name = "RefriM1"
		f.hint_key = "HUD_FRIDGE"
		f.size = Vector3(1.2, 2.2, 1.2)
		f.position = box.position
		fl.add_child(f)

	func hint_text() -> String:
		_assign()
		match state:
			"fuera":
				return tr("Q4_HUD_MW_BROKEN")
			"ocupado":
				return Loc.fmt(tr("Q4_HUD_MW_BUSY"), {"t": "0:01" if eternal else Loc.mmss(maxf(until - GameState.clock_seconds, 0.0))})
			"mio_calentando":
				return Loc.fmt(tr("Q4_HUD_MW_HEATING"), {"t": Loc.mmss(maxf(until - GameState.clock_seconds, 0.0))})
			"mio_listo":
				return tr("Q4_HUD_MW_TAKE")
		return tr("Q4_HUD_MW_HEAT") if TaperFlow.state() == TaperFlow.MANO else tr("HUD_MICROWAVE")

	func _assign() -> void:
		if state != "":
			return
		TaperFlow.assign_microwaves(get_tree(), self)

	func set_state(p_state: String, p_until: float = 0.0, p_tape: String = "") -> void:
		if p_state != "ocupado":
			eternal = false
		state = p_state
		until = p_until
		tape = p_tape
		_refresh_visual()

	func _process(_delta: float) -> void:
		if state in ["ocupado", "mio_calentando"]:
			if eternal:
				# El taper de C-13 nunca termina: se queda en 0:01, en silencio (v0.3.2: antes volvía a programarse cada
				# segundo de juego y sonaba el «ding» cada vez: a 9-45x eran decenas por segundo, sin parar).
				if _label != null and _label.text != "0:01\nC-13":
					_label.text = "0:01\nC-13"
				return
			if GameState.clock_seconds >= until:
				_ding(state == "mio_calentando")
				if state == "mio_calentando":
					set_state("mio_listo")
					TaperFlow.set_state(TaperFlow.LISTO)
					EventBus.show_message.emit(tr("Q4_MSG_MW_DING"), 3.0)
				elif tape == "C-13":
					eternal = true  # el de C-13 nunca termina (un solo «ding» falso y se queda en 0:01)
					_refresh_visual()
				else:
					set_state("libre")
			elif _label != null:
				_label.text = "%s\n%s" % [Loc.mmss(maxf(until - GameState.clock_seconds, 0.0)), tape]

	## Un «ding» por microondas como mucho cada DING_MIN_S reales (con el reloj del lunch a 9x varios microondas
	## pueden terminar en el mismo segundo real: se oye uno, no una ráfaga).
	func _ding(mine: bool = false) -> void:
		var now := Time.get_ticks_msec()
		if not mine and (now - _last_ding_ms < int(DING_MIN_S * 1000.0) or now - _any_ding_ms < 400):
			return
		_last_ding_ms = now
		Microwave._any_ding_ms = now
		dings += 1
		AudioManager.play_sfx("microondas_fin")

	func _refresh_visual() -> void:
		if _label == null:
			_label = Label3D.new()
			_label.name = "Pantalla"
			_label.font_size = 36
			_label.pixel_size = 0.0011
			_label.modulate = Color(0.4, 1.0, 0.55)
			_label.outline_size = 0
			_label.position = Vector3(0.0, 0.0, 0.0)
			add_child(_label)
			_place_on_front(_label)
		_label.visible = state != "libre"
		var site_clock := get_node_or_null("Reloj") as Node3D  # v0.3.1: el reloj de adorno de Q5 (SiteProps)
		if site_clock != null:
			site_clock.visible = not _label.visible
		match state:
			"fuera":
				_label.text = tr("Q4_MW_OUT_SIGN")
				_label.modulate = Color(0.95, 0.85, 0.3)
			"mio_listo":
				_label.text = "0:00\n" + GameState.agent.to_upper()
				_label.modulate = Color(0.4, 1.0, 0.55)
			_:
				_label.modulate = Color(0.4, 1.0, 0.55)
		var running := state in ["ocupado", "mio_calentando"]
		if running and _light == null:
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.85, 0.5)
			_light.light_energy = 0.5
			_light.omni_range = 1.2
			add_child(_light)
		if _light != null:
			_light.visible = running
		if state == "mio_listo" and _steam == null:
			_steam = CPUParticles3D.new()
			_steam.amount = 16
			_steam.lifetime = 1.6
			_steam.direction = Vector3.UP
			_steam.spread = 25.0
			_steam.initial_velocity_min = 0.08
			_steam.initial_velocity_max = 0.2
			var qm := QuadMesh.new()
			qm.size = Vector2(0.06, 0.06)
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(1, 1, 1, 0.16)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			qm.material = sm
			_steam.mesh = qm
			_steam.position = Vector3(0, 0.25, 0)
			add_child(_steam)
		if _steam != null:
			_steam.emitting = state == "mio_listo"

	## La etiqueta va en la cara que mira al pasillo (la más cercana al marcador de la cafetería o al jugador).
	func _place_on_front(n: Node3D) -> void:
		var caja := get_node_or_null("Caja") as MeshInstance3D
		var half := Vector3(0.3, 0.2, 0.25)
		if caja != null and caja.mesh is BoxMesh:
			half = (caja.mesh as BoxMesh).size * 0.5
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		var local_dir := Vector3(0, 0, 1)
		if pl != null:
			local_dir = (global_transform.affine_inverse() * pl.global_position)
			local_dir.y = 0.0
			if absf(local_dir.x) > absf(local_dir.z):
				local_dir = Vector3(signf(local_dir.x), 0, 0)
			else:
				local_dir = Vector3(0, 0, signf(local_dir.z) if local_dir.z != 0.0 else 1.0)
		n.position = Vector3(local_dir.x * (half.x + 0.012), half.y * 0.35, local_dir.z * (half.z + 0.012))
		n.rotation.y = atan2(local_dir.x, local_dir.z)

	func interact(_player: Node) -> bool:
		_assign()
		TaperFlow.check_spoiled()
		var m := ManosFx.for_player(_player)
		match state:
			"fuera":
				AudioManager.play_sfx("ascensor_boton_muerto", "UI")
				EventBus.show_message.emit(tr("Q4_MSG_MW_BROKEN"), 2.5)
				return false
			"ocupado":
				AudioManager.play_sfx("ascensor_boton_muerto", "UI")
				EventBus.show_message.emit(Loc.fmt(tr("Q4_MSG_MW_BUSY"), {"t": "0:01" if eternal else Loc.mmss(maxf(until - GameState.clock_seconds, 0.0)), "etiqueta": tape}), 2.5)
				return false
			"mio_calentando":
				EventBus.show_message.emit(Loc.fmt(tr("Q4_HUD_MW_HEATING"), {"t": Loc.mmss(maxf(until - GameState.clock_seconds, 0.0))}), 2.0)
				return false
			"mio_listo":
				set_state("libre")
				TaperFlow.set_state(TaperFlow.CALIENTE)
				AudioManager.play_sfx("refri")
				if m != null:
					m.play("microondas_sacar")
				TaperFlow.spawn_eat_spots(self)
				EventBus.show_message.emit(tr("Q4_MSG_TAPER_HOT"), 3.0)
				interacted.emit(_player)
				return true
		if TaperFlow.state() == TaperFlow.MANO:
			var heat := float(TaperFlow.cfg().get("calentar_s_juego", 60.0))
			set_state("mio_calentando", GameState.clock_seconds + heat, GameState.agent.to_upper())
			TaperFlow.set_state(TaperFlow.CALENTANDO)
			TaperFlow.current_microwave = self
			GameState.flags["taper_mw"] = str(name)  # v0.3.2: si el piso se recarga, tu taper sigue en ESTE microondas
			GameState.flags["taper_mw_hasta"] = until
			AudioManager.play_sfx("ui_click_v2", "UI")
			if m != null:
				m.play("microondas_meter")
			EventBus.show_message.emit(tr("Q4_MSG_MW_START"), 3.0)
		elif TaperFlow.state() == TaperFlow.COMIDO:
			EventBus.show_message.emit(tr("Q4_MSG_TAPER_DONE"), 2.0)
		else:
			EventBus.show_message.emit(tr("Q4_MSG_MW_NOTHING"), 2.0)
		interacted.emit(_player)
		return true


## v0.3.1 Q4 (F15): sitio para comer el taper caliente, uno por mesa de las cafeterías (-1 y azotea). Comer: Fatiga
## −20 × recuperación de la dificultad, energía (sin desenfoque ni microsueños 3 min reales, aliento ×1,5 hasta el fin
## del lunch), cuenta como lunch completo.
## v0.3.2 (Joan: «no me deja sentarme a comer el taper en las mesas»): (1) el área era una caja de 1,6 × 1,2 × 1,6 m
## centrada en la mesa que llegaba a 1,64 m: parado junto a la mesa la cámara (1,6 m) quedaba DENTRO de la caja y el
## rayo de interacción no la detecta desde dentro; ahora es una losa a la altura del tablero (0,5–1,0 m). (2) Solo se
## creaban en el piso del microondas al sacar el taper y se perdían al cambiar de piso (y la azotea no tenía mesas
## «Mesa<n>»): ahora hay una por mesa en el -1 y en el 9 siempre que el piso se arma. (3) Te sientas en la silla más
## cercana, comes (manos, 3,3 s) y te puedes levantar con [E].
class EatSpot extends Interactable:
	var table: Node3D = null

	func hint_text() -> String:
		match TaperFlow.state():
			TaperFlow.CALIENTE:
				return tr("B2_HUD_EAT_SIT")
			TaperFlow.MANO, TaperFlow.CALENTANDO:
				return tr("B2_HUD_TABLE_HEAT")
			TaperFlow.LISTO:
				return tr("B2_HUD_TABLE_TAKE")
		return ""

	func interact(_player: Node) -> bool:
		var st := TaperFlow.state()
		if st != TaperFlow.CALIENTE:
			if st in [TaperFlow.MANO, TaperFlow.CALENTANDO, TaperFlow.LISTO]:
				EventBus.show_message.emit(hint_text(), 2.5)
			return false
		if _player is Player:
			sit(_player as Player)
		TaperFlow.eat(_player)
		interacted.emit(_player)
		return true

	## Silla más cercana al jugador alrededor de la mesa (a 0,95 m del centro por el lado largo), mirando a la mesa.
	func sit(p: Player) -> void:
		if p.seated:
			return
		var fl := TaperFlow.floor_of(self)
		var c := global_position
		c.y = fl.global_position.y if fl != null else 0.0
		var best := Vector3.INF
		for d in [Vector3(0, 0, 0.95), Vector3(0, 0, -0.95), Vector3(0.95, 0, 0), Vector3(-0.95, 0, 0)]:
			var q: Vector3 = c + global_transform.basis * d
			if best == Vector3.INF or q.distance_to(p.global_position) < best.distance_to(p.global_position):
				best = q
		var seat := get_node_or_null("SillaComer") as Node3D
		if seat == null:
			seat = Node3D.new()
			seat.name = "SillaComer"
			(fl if fl != null else get_parent()).add_child(seat)
			seat.set_meta("eat_spot", true)
		seat.global_position = best
		var to_table := c - best
		seat.global_rotation = Vector3(0, atan2(-to_table.x, -to_table.z), 0)  # −Z (adelante) hacia la mesa
		seat.set_meta("salida", best - to_table.normalized() * 0.55)
		p.sit_at(seat, "mesa_comer_%s" % str(name).trim_prefix("Comer_"))


## Puerta que se abre y se cierra en la cara del mueble que mira al jugador (casillero, refri). Solo presentación.
class DoorSwing:
	static func swing(obj: Node3D, player: Node, open_at: float, close_at: float, width: float) -> void:
		if obj == null or not obj.is_inside_tree():
			return
		var caja := obj.get_node_or_null("Caja") as MeshInstance3D
		var half := Vector3(0.4, 0.9, 0.4)
		if caja != null and caja.mesh is BoxMesh:
			half = (caja.mesh as BoxMesh).size * 0.5
		var pivot := obj.get_node_or_null("PuertaPivote") as Node3D
		if pivot == null:
			pivot = Node3D.new()
			pivot.name = "PuertaPivote"
			obj.add_child(pivot)
			var dir := Vector3(0, 0, 1)
			var pl := player as Node3D
			if pl != null:
				var ld := obj.global_transform.affine_inverse() * pl.global_position
				dir = Vector3(signf(ld.x), 0, 0) if absf(ld.x) > absf(ld.z) else Vector3(0, 0, signf(ld.z) if ld.z != 0.0 else 1.0)
			var side := Vector3(dir.z, 0, -dir.x)  # a lo ancho de la cara
			var face_w := (half.z if absf(dir.x) > 0.5 else half.x) * 2.0
			face_w = minf(face_w, width)
			pivot.position = Vector3(dir.x * (half.x + 0.015), 0, dir.z * (half.z + 0.015)) - side * face_w * 0.5
			pivot.rotation.y = atan2(dir.x, dir.z)
			var leaf := MeshInstance3D.new()
			leaf.name = "Hoja"
			var bm := BoxMesh.new()
			bm.size = Vector3(face_w, half.y * 1.9, 0.025)
			leaf.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.72, 0.74) if obj is Fridge else Color(0.16, 0.42, 0.42)
			mat.metallic = 0.4 if obj is Fridge else 0.2
			mat.roughness = 0.45
			leaf.material_override = mat
			leaf.position = Vector3(face_w * 0.5, 0, 0)
			pivot.add_child(leaf)
			if obj is Fridge:  # la luz de adentro se prende al abrir
				var lz := OmniLight3D.new()
				lz.name = "LuzRefri"
				lz.light_color = Color(0.85, 0.93, 1.0)
				lz.light_energy = 0.0
				lz.omni_range = 2.2
				lz.position = Vector3(dir.x * (half.x + 0.25), half.y * 0.3, dir.z * (half.z + 0.25))
				obj.add_child(lz)
		var luz := obj.get_node_or_null("LuzRefri") as OmniLight3D
		ObjectAnim.swing(obj, pivot, luz, open_at, close_at)  # v0.3.2-anim: mismas horas, con peso y sin deriva al repetir


## v0.3.1 Q4 (F15): estado del taper (GameState.flags["taper"], va en el checkpoint) y reglas de data/comida.json.
class TaperFlow:
	const MOCHILA := "mochila"
	const REFRI := "refri"
	const MANO := "mano"
	const CALENTANDO := "calentando"
	const LISTO := "listo"
	const CALIENTE := "caliente"
	const COMIDO := "comido"
	const MALOGRADO := "malogrado"
	static var current_microwave: Node = null

	static func cfg() -> Dictionary:
		return DataLoader.dict("comida").get("taper", {})

	static func state() -> String:
		var s := str(GameState.flags.get("taper", ""))
		if s != "":
			return s
		# Compatibilidad con las partidas y pruebas de la v0.2/v0.3 (solo los flags viejos).
		if GameState.flags.get("lunch_eaten", false):
			return COMIDO
		if GameState.flags.get("lunch_in_hand", false):
			return MANO
		if GameState.flags.get("lunch_stored", false):
			return REFRI
		return MOCHILA

	static func set_state(s: String) -> void:
		GameState.flags["taper"] = s
		GameState.flags["lunch_stored"] = s != MOCHILA and s != MALOGRADO
		GameState.flags["lunch_in_hand"] = s in [MANO, CALENTANDO, LISTO, CALIENTE]
		if s == COMIDO:
			GameState.flags["lunch_eaten"] = true

	static func lunch_now() -> bool:
		return Metrics.aux == Metrics.Aux.LUNCH

	## A las N horas de turno sin refri, el taper de la mochila se echa a perder.
	static func check_spoiled() -> void:
		if state() != MOCHILA:
			return
		if GameState.clock_seconds - GameState.ARRIVAL_SECONDS >= float(cfg().get("se_malogra_tras_h", 4.0)) * 3600.0:
			set_state(MALOGRADO)
			EventBus.show_message.emit(tr_static("Q4_MSG_TAPER_SPOILED"), 3.0)

	static func tr_static(k: String) -> String:
		return TranslationServer.translate(k)

	## Reparte los estados de los microondas del piso (comida.json/microondas): uno fuera de servicio, varios
	## ocupados con tapers ajenos; al menos uno libre.
	static func assign_microwaves(tree: SceneTree, who: Node) -> void:
		var all: Array = []
		var fl := floor_of(who)
		for n in tree.get_nodes_in_group("microondas"):
			if n is Microwave and floor_of(n as Node) == fl:
				all.append(n)
		all.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
		var mc: Dictionary = DataLoader.dict("comida").get("microondas", {})
		var broken: Array = mc.get("fuera_de_servicio", [2])
		var busy: Array = mc.get("ocupados", [0, 3, 5])
		var rng_s: Array = mc.get("ocupado_s_juego", [30.0, 110.0])
		var tapes: Array = mc.get("etiquetas_ajenas", ["C-13"])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(GameState.agent) + GameState.turno * 101
		# v0.3.2: el piso se rearma al volver (ascensor, escalera, reaparecer): tu taper sigue en el microondas donde lo
		# dejaste (antes quedaba «calentando/listo» sin microondas y el lunch no se podía terminar).
		var mine_name := str(GameState.flags.get("taper_mw", ""))
		if state() in [CALENTANDO, LISTO] and (current_microwave == null or not is_instance_valid(current_microwave) or not current_microwave.is_inside_tree()):
			for n in all:
				if str((n as Node).name) == mine_name or mine_name == "":
					var until_c := float(GameState.flags.get("taper_mw_hasta", 0.0))
					if state() == LISTO or GameState.clock_seconds >= until_c:
						(n as Microwave).set_state("mio_listo")
						set_state(LISTO)
					else:
						(n as Microwave).set_state("mio_calentando", until_c, GameState.agent.to_upper())
					current_microwave = n
					break
		for i in all.size():
			var mw := all[i] as Microwave
			if mw.state != "":
				continue
			if all.size() >= 3 and (broken.has(i) or broken.has(float(i))):
				mw.set_state("fuera")
			elif all.size() >= 3 and (busy.has(i) or busy.has(float(i))):
				mw.set_state("ocupado", GameState.clock_seconds + rng.randf_range(float(rng_s[0]), float(rng_s[1])), str(tapes[i % tapes.size()]))
			else:
				mw.set_state("libre")

	## Sitios para comer: mesas de la cafetería (grupo "mesa_comer" o mallas "Mesa<n>"); si no hay, junto al microondas.
	## v0.3.1: piso que contiene al nodo (los microondas de Q5 cuelgan de EstacionMicroondas, no del piso).
	static func floor_of(n: Node) -> Node3D:
		var p := n.get_parent()
		while p != null:
			if p.is_in_group("floor"):
				return p as Node3D
			p = p.get_parent()
		return n.get_parent() as Node3D

	static func spawn_eat_spots(mw: Node3D) -> void:
		ensure_eat_spots(floor_of(mw), mw)

	## Mesas de las cafeterías: grupo "mesa_comer" o mallas «Mesa<n>» (-1), «MesaBlanca<n>» / «MesaSombrilla<n>» (azotea) y
	## «MesaBaja<n>» (sillones del -1), en cualquier nivel del piso.
	static func cafe_tables(fl: Node) -> Array[Node3D]:
		var out: Array[Node3D] = []
		if fl == null:
			return out
		for n in fl.get_tree().get_nodes_in_group("mesa_comer"):
			if n is Node3D and fl.is_ancestor_of(n):
				out.append(n as Node3D)
		if not out.is_empty():
			return out
		for c in fl.find_children("Mesa*", "MeshInstance3D", true, false):
			var nm := str(c.name)
			for pre in ["MesaBlanca", "MesaSombrilla", "MesaBaja", "Mesa"]:
				if nm.begins_with(pre) and nm.trim_prefix(pre).trim_prefix("-").is_valid_int():
					out.append(c as Node3D)
					break
		return out

	## Un sitio para comer por mesa en el piso `fl` (idempotente). Sin mesas, uno junto al microondas `mw`.
	static func ensure_eat_spots(fl: Node3D, mw: Node3D = null) -> void:
		if fl == null or not fl.is_inside_tree():
			return
		if fl.find_child("Comer_0", false, false) != null:
			return
		var tables := cafe_tables(fl)
		var i := 0
		for tb in tables:
			var e := EatSpot.new()
			e.name = "Comer_%d" % i
			e.hint_key = "Q4_HUD_EAT"
			e.table = tb
			var sz := Vector3(1.2, 0.05, 1.2)
			var mi := tb as MeshInstance3D
			if mi != null and mi.mesh != null:
				var aabb := mi.mesh.get_aabb()
				sz = aabb.size * mi.scale
			e.size = Vector3(sz.x + 0.3, 0.5, sz.z + 0.3)  # losa a la altura del tablero: la cámara nunca queda dentro
			fl.add_child(e)
			e.global_position = tb.global_position
			e.global_rotation = Vector3(0, tb.global_rotation.y, 0)
			i += 1
		if i == 0 and mw != null:
			var e2 := EatSpot.new()
			e2.name = "Comer_0"
			e2.hint_key = "Q4_HUD_EAT"
			e2.size = Vector3(1.2, 0.5, 1.2)
			fl.add_child(e2)
			e2.global_position = mw.global_position + mw.global_transform.basis.z * 0.8 + Vector3(0, -0.3, 0)

	## Comer: animación, Fatiga −20, energía y lunch completo.
	static func eat(player: Node) -> void:
		var c := cfg()
		set_state(COMIDO)
		var m := ManosFx.for_player(player)
		if m != null:
			m.play("comer")
		var f0 := Fatigue.value
		Fatigue.add(float(c.get("fatiga", -20.0)))  # × recuperación de la dificultad (Fatigue.add, v0.3.2)
		var e := float(c.get("energia_s_real", 180.0))
		Fatigue.suppress_blur(e)
		Fatigue.suppress_microsleep(e)  # sin microsueños durante la energía
		if player is Player:
			Energia.give(player as Player, float(c.get("aliento_x", 1.5)), e)
		EventBus.show_message.emit(Loc.fmt(TranslationServer.translate("Q4_MSG_TAPER_EATEN"), {"n": int(round(absf(f0 - Fatigue.value)))}), 3.5)
		Checkpoints.save_checkpoint("lunch")

	## Bot: avanza el taper solo (lo usa stress_bot en el lunch): saca del microondas listo y come.
	static func bot_step(player: Node) -> void:
		match state():
			LISTO:
				if current_microwave != null and is_instance_valid(current_microwave):
					(current_microwave as Microwave).interact(player)
			CALIENTE:
				eat(player)


## Aliento ×1,5 hasta el fin del lunch (y 3 min reales de energía): nodo hijo del jugador que lo deshace solo.
class Energia extends Node:
	var base: float = 6.0
	var left: float = 0.0

	static func give(p: Player, mult: float, seconds: float) -> void:
		var e := p.get_node_or_null("EnergiaTaper") as Energia
		if e == null:
			e = Energia.new()
			e.name = "EnergiaTaper"
			e.base = p.breath
			p.add_child(e)
		p.breath = e.base * mult
		p.breath_left = p.breath
		e.left = seconds

	func _process(delta: float) -> void:
		left -= delta
		var p := get_parent() as Player
		if p == null:
			return
		if left <= 0.0 and Metrics.aux != Metrics.Aux.LUNCH:
			p.breath = base
			p.breath_left = minf(p.breath_left, base)
			queue_free()


class WaterCooler extends Interactable:
	## v0.3 P2: el dispensador de DENTRO de la sala de PCs baja la Fatiga (−2) y no dispara ninguna
	## regla (pararse dentro de la sala es libre, PLAN §2 #25). El del vestíbulo conserva su efecto v0.2.
	var fatigue_delta: float = 0.0
	var message_key: String = "MSG_WATER"

	func hint_text() -> String:
		return tr("HUD_WATER")

	func interact(_player: Node) -> bool:
		AudioManager.play_sfx("maquina_agua")
		if fatigue_delta != 0.0:
			Fatigue.add(fatigue_delta)
		EventBus.show_message.emit(tr(message_key), 2.0)
		interacted.emit(_player)
		return true


class Turnstile extends Interactable:
	var out_of_service: bool = false
	var blocker_body: StaticBody3D = null
	var _open_token: int = 0

	func hint_text() -> String:
		return tr("HUD_TURNSTILE")

	func set_gate_open(open: bool) -> void:
		if blocker_body != null and is_instance_valid(blocker_body):
			blocker_body.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
			for ch in blocker_body.get_children():
				if ch is CollisionShape3D:
					(ch as CollisionShape3D).disabled = open

	func interact(_player: Node) -> bool:
		if out_of_service:
			AudioManager.play_sfx("ascensor_boton_muerto", "UI")
			return false
		# v0.4: con la revisión de Don Fermín activa, el molinete bloquea físicamente y avisa; insistir dispara persecución.
		if not GameState.shift_over and bool(GameState.flags.get("guardia_revision_activa", false)) and not bool(GameState.flags.get("revision_ok", false)):
			AudioManager.play_sfx("ascensor_boton_muerto", "UI")
			EventBus.show_message.emit(tr("MSG_TURNSTILE_NO_CHECK"), 3.0)
			EventBus.guard_check.emit("molinete_bloqueado")
			return false
		AudioManager.play_sfx("molinete")
		set_gate_open(true)
		_open_token += 1
		var tok := _open_token
		if is_inside_tree():
			get_tree().create_timer(4.5).timeout.connect(func() -> void:
				if is_inside_tree() and tok == _open_token:
					set_gate_open(false))
		if GameState.shift_over:
			EventBus.show_message.emit(tr("MSG_TURNSTILE_OUT"), 3.0)
			GameState.flags["clocked_out"] = true
		else:
			EventBus.show_message.emit(tr("MSG_TURNSTILE_IN"), 3.0)
			GameState.flags["clocked_in"] = true
		EventBus.turnstile_passed.emit(not GameState.shift_over)
		interacted.emit(_player)
		return true


class Door extends Interactable:
	var locked: bool = false
	var locked_key: String = "HUD_DOOR_LOCKED"
	var open: bool = false
	var leaf: MeshInstance3D = null

	func hint_text() -> String:
		return tr(locked_key) if locked else tr("HUD_DOOR")

	func interact(_player: Node) -> bool:
		if locked:
			AudioManager.play_sfx("ascensor_boton_muerto", "UI")
			EventBus.show_message.emit(tr(locked_key), 2.0)
			return false
		set_open(not open)
		AudioManager.play_sfx("puerta_vidrio")
		interacted.emit(_player)
		return true

	## Abre/cierra la hoja (leaf, o la Caja de WorldObjects.simple) con su colisión. Lo usa también el Trainer.
	func set_open(on: bool) -> void:
		open = on
		var hoja: Node = leaf if leaf != null else get_node_or_null("Caja")
		if hoja is MeshInstance3D:
			(hoja as MeshInstance3D).visible = not open
			var col := hoja.get_node_or_null("Col")
			if col is StaticBody3D:
				(col as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
		ObjectAnim.door(self, hoja, on)  # v0.3.2-anim: la hoja gira en vez de desaparecer (solo visual)


class Stairs extends Interactable:
	var target_floor: int = 1
	var going_up: bool = true
	var blocked_reader: bool = false
	var direct: bool = false  # true = puerta de la caja de escalera: sale directo al piso

	func hint_text() -> String:
		if blocked_reader:
			return tr("SIGN_FIRE_DOOR")
		return tr("MSG_STAIRS_UP") if going_up else tr("MSG_STAIRS_DOWN")

	func interact(_player: Node) -> bool:
		if blocked_reader:
			AudioManager.play_sfx("ascensor_boton_muerto", "UI")
			EventBus.show_message.emit(tr("ELEVATOR_DENIED"), 2.0)
			return false
		AudioManager.play_sfx("puerta_cortafuego")
		var building := get_tree().get_first_node_in_group("building") as Building
		if building != null:
			if direct:
				building.go_to_floor(target_floor, "escalera")
			else:
				building.go_to_stairwell(target_floor, going_up)
		interacted.emit(_player)
		return true


class Mirror extends Interactable:
	var zone_id: String = ""

	func hint_text() -> String:
		return tr("HUD_MIRROR")

	func interact(_player: Node) -> bool:
		# v0.3.2: mirarse = tu reflejo ~1,8 s (MirrorView) y vuelve el control. Después el controlador de distorsiones
		# decide si alguien aparece detrás de ti (distorsión 5, Fatiga ≥ 50: MirrorView.haunt()).
		if MirrorView.is_open():
			return false
		if _player is Player:
			MirrorView.show_for(self, _player as Player)
		EventBus.player_entered_zone.emit("espejo_" + zone_id)
		interacted.emit(_player)
		return true


class WallClock extends Interactable:
	var label: Label3D = null
	var frozen_text: String = ""
	var looks: int = 0
	## v0.3 P2 (algo no cuadra): con presión alta el reloj a veces "salta" un minuto atrás un instante.
	var _skip_left: float = 0.0
	var _skip_text: String = ""
	var _skip_cd: float = 20.0

	func hint_text() -> String:
		return tr("HUD_CLOCK")

	func _process(delta: float) -> void:
		if label == null:
			return
		if frozen_text != "":
			label.text = frozen_text
			return
		_skip_cd -= delta
		if _skip_left > 0.0:
			_skip_left -= delta
			label.text = _skip_text
			return
		if _skip_cd <= 0.0:
			_skip_cd = randf_range(25.0, 70.0)
			if GameState.running and randf() < 0.25 + 0.6 * Dread.level():
				_skip_left = randf_range(0.6, 1.4)
				_skip_text = GameState.clock_text_at(GameState.clock_seconds - (60.0 if randf() < 0.7 else -3600.0))
				return
		label.text = GameState.clock_text()

	func interact(_player: Node) -> bool:
		looks += 1
		EventBus.player_entered_zone.emit("reloj_pared_%d" % looks)
		interacted.emit(_player)
		return true


## v0.4 · Fragmento de carta de renuncia (Sabado Turno 6: rompe el bucle 05:59 y permite enfrentar/escapar de GRASA).
class ResignationFragment extends Interactable:
	var frag_id: int = 1

	func hint_text() -> String:
		return "[E] Recoger Fragmento %d/3 de Carta de Renuncia" % frag_id if Loc.lang != "en" else "[E] Pick up Resignation Fragment %d/3" % frag_id

	func interact(_player: Node) -> bool:
		var key := "frag_carta_%d" % frag_id
		if bool(GameState.flags.get(key, false)):
			return false
		GameState.flags[key] = true
		var total := int(GameState.flags.get("carta_fragmentos", 0)) + 1
		GameState.flags["carta_fragmentos"] = total
		SaveSlots.bump_counter("reb", 2, "Jiroshi")
		AudioManager.play_sfx("papel", "UI")
		GfxLens.kick(0.65, 0.8)
		visible = false
		enabled = false
		if total >= 3:
			GameState.flags["sat_0559_broken"] = true
			EventBus.show_message.emit("¡Carta de renuncia completa (3/3)! El bucle de las 05:59 se ha roto. Sube a la Azotea (Piso 9) antes de las 08:45." if Loc.lang != "en" else "Resignation letter complete (3/3)! The 05:59 loop is broken. Go to the Rooftop (Floor 9) before 08:45.", 6.0)
		else:
			EventBus.show_message.emit("Fragmento %d/3 recogido. Shero Gigante sintió el papel..." % total if Loc.lang != "en" else "Fragment %d/3 collected. Giant Shero felt the paper..." % total, 4.5)
		return true

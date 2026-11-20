class_name ShopMenu
extends PanelContainer
## Menú de compra (v0.2): expendedora del -1 y mostrador de Marleny. Teclas 1-N compran (Economy.buy),
## Q cierra. Mientras está abierto el jugador no se mueve (modal). Los precios vienen de balance.json/economia.

var shop_id: String = ""
var items: Array = []
var _vb: VBoxContainer = null
var _open: bool = false


func _ready() -> void:
	add_to_group("shop_menu")
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.PANEL
	sb.border_color = UITheme.BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(400, 0)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 6)
	add_child(_vb)
	UITheme.center_fit(self)  # centrado por anclas y ajustado a la ventana (antes posición fija de 1920×1080)
	EventBus.shop_opened.connect(open_shop)
	EventBus.shift_started.connect(func() -> void: close())
	EventBus.death_shown.connect(func(_c: String) -> void: close())
	EventBus.death_sequence_started.connect(func(_c: String, _k: String, _d: String) -> void: close())
	EventBus.returned_to_menu.connect(func() -> void: close())


func open_shop(id: String, title: String, p_items: Array) -> void:
	shop_id = id
	items = p_items
	for c in _vb.get_children():
		c.queue_free()
	_vb.add_child(UITheme.label(title, 20, UITheme.TEXT, true))
	if Economy.active():
		_vb.add_child(UITheme.label("%s %s" % [tr("ECON_SALDO"), Economy.soles(Economy.saldo)], 14, UITheme.DIM))
	for i in items.size():
		var it: Dictionary = items[i]
		var price_txt := Economy.soles(float(it.get("price", 0.0)))
		if str(it.get("id", "")) == "cafe" and Economy.active() and Economy.courtesy_coffee():
			price_txt = tr("CORE3_CAFE_GRATIS")  # v0.3.2-core3: el café de la ayuda no se cobra, y se ve antes de comprarlo
		_vb.add_child(UITheme.label("%d · %s   %s" % [i + 1, str(it.get("label", "")), price_txt], 16))
	_vb.add_child(UITheme.label(tr("SHOP_CLOSE"), 13, UITheme.DIM))
	visible = true
	_open = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.input_locked = true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not Checkpoints.dying:
		player.input_locked = false
	EventBus.shop_closed.emit(shop_id)


## Compra el ítem i (también lo usa el bot). Devuelve true si se compró.
func buy_index(i: int) -> bool:
	if not _open or i < 0 or i >= items.size():
		return false
	var it: Dictionary = items[i]
	var price := float(it.get("price", 0.0))
	if not Economy.buy(str(it.get("id", "")), price, shop_id):
		return false
	AudioManager.play_sfx("expendedora" if shop_id == "expendedora" else "microondas_fin", "Sala")
	WorldObjects.apply_purchase(shop_id, it.get("data", {}))
	close()
	return true


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("aux_wheel") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
		return
	for i in mini(items.size(), 4):
		if event.is_action_pressed("phrase_%d" % (i + 1)):
			buy_index(i)
			get_viewport().set_input_as_handled()
			return

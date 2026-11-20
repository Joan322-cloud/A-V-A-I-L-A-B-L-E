extends Node
## Economy (v0.2, GDD 1.4 roadmap): sueldo en soles que se acumula por hora de juego logueado,
## pasaje descontado al marcar el molinete, compras en la expendedora y en el mostrador de Marleny,
## descuento por WW al cerrar el turno (GDD 4.5). Solo se muestra/cobra desde balance.json/economia/turno_desde
## (T2); en T1 acumula en silencio y no cambia nada. El saldo vive en user://progreso.json.
## Todos los montos son [PROPUESTA] hasta que Joan dé la tabla real.

var saldo: float = 0.0
var ganado_turno: float = 0.0
var gastado_turno: float = 0.0
var _hours_paid: Array[int] = []


func _ready() -> void:
	EventBus.shift_started.connect(_on_shift_started)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.turnstile_passed.connect(_on_turnstile)
	EventBus.shift_ended.connect(_on_shift_ended)


## ¿La economía está activa (visible y con cobros) en este turno?
func active() -> bool:
	return GameState.turno >= int(DataLoader.bal("economia/turno_desde", 2))


func _on_shift_started() -> void:
	GameState.load_progress()
	var saved := float(GameState.progress.get("saldo", -1.0))
	saldo = saved if saved >= 0.0 else float(DataLoader.bal("economia/saldo_inicial_soles", 12.0))
	ganado_turno = 0.0
	gastado_turno = 0.0
	_hours_paid.clear()
	_emit()


## v0.3: sueldo del turno repartido en los 525 min (00:00-08:45): 8 pagos al cerrar cada hora
## (1:00 … 8:00) y el cierre de los últimos 45 min al terminar el turno (PLAN §3.1).
func _on_hour_changed(hour: int) -> void:
	if not GameState.logged_in or _hours_paid.has(hour) or hour < 1 or hour > int(DataLoader.bal("economia/pagos_turno", 8)):
		return
	_hours_paid.append(hour)
	ganado_turno += hourly_pay()
	_emit()


## Pago de una hora completa de turno.
func hourly_pay() -> float:
	var shift_h := GameState.shift_end_seconds() / 3600.0
	return float(DataLoader.bal("economia/sueldo_turno_soles", 58.0)) / maxf(shift_h, 1.0)


## Pago del cierre (la fracción de hora tras el último pago entero: 8:00-8:45).
func closing_pay() -> float:
	var shift_h := GameState.shift_end_seconds() / 3600.0
	var frac := shift_h - float(int(DataLoader.bal("economia/pagos_turno", 8)))
	return hourly_pay() * maxf(frac, 0.0)


func _on_turnstile(entering: bool) -> void:
	if not entering or not active() or GameState.flags.get("pasaje_cobrado", false):
		return
	GameState.flags["pasaje_cobrado"] = true
	var pasaje := float(DataLoader.bal("economia/pasaje_soles", 3.0))
	saldo = maxf(saldo - pasaje, 0.0)
	gastado_turno += pasaje
	EventBus.show_message.emit(Loc.fmt(tr("ECON_PASAJE"), {"monto": soles(pasaje), "saldo": soles(saldo)}), 3.5)
	_emit()


## Compra: descuenta si alcanza. Devuelve false (y avisa) si no hay saldo.
func buy(item_id: String, price: float, shop_id: String = "") -> bool:
	if not active():
		return true  # en T1 nada cuesta
	if item_id == "cafe" and courtesy_coffee():
		# v0.3.2-core3: el café de la ayuda (segunda muerte seguida desde el mismo checkpoint) no se cobra.
		GameState.flags.erase("cafe_cortesia")
		price = 0.0
		EventBus.show_message.emit(tr("CORE3_CAFE_CORTESIA"), 3.0)
	if saldo + 0.001 < price:
		EventBus.show_message.emit(Loc.fmt(tr("ECON_NO_SALDO"), {"saldo": soles(saldo), "precio": soles(price)}), 3.0)
		AudioManager.play_sfx("ascensor_boton_muerto", "UI")
		return false
	saldo -= price
	gastado_turno += price
	EventBus.shop_bought.emit(shop_id, item_id, price)
	_emit()
	return true


## Cierre del turno: sueldo ganado menos descuento por cada WW (GDD 4.5: los WW se descuentan del sueldo desde v0.2).
func _on_shift_ended() -> void:
	if not _hours_paid.has(-1):
		_hours_paid.append(-1)  # cierre pagado
		ganado_turno += closing_pay()
	var ww_cost := float(DataLoader.bal("economia/descuento_ww_soles", 15.0)) * Metrics.written_warnings
	var neto := maxf(ganado_turno - ww_cost, 0.0)
	saldo += neto
	GameState.load_progress()
	GameState.progress["saldo"] = saldo
	GameState.save_progress()
	_emit()


## v0.3.2-core3: ¿la máquina te debe un café? (la ayuda de la segunda muerte seguida, Checkpoints._death_help)
func courtesy_coffee() -> bool:
	return bool(GameState.flags.get("cafe_cortesia", false))


## v0.3.2-core3: lo que el checkpoint guarda del dinero (Checkpoints.save_checkpoint / _restore). Al reaparecer
## vuelve el saldo del checkpoint: lo comprado después se devuelve (su efecto también volvió atrás) y las horas
## pagadas después se vuelven a pagar a su hora.
func to_save() -> Dictionary:
	return {"saldo": saldo, "ganado": ganado_turno, "gastado": gastado_turno, "horas": _hours_paid.duplicate()}


func from_save(d: Dictionary) -> void:
	if not d.has("saldo"):
		return
	saldo = float(d.get("saldo", saldo))
	ganado_turno = float(d.get("ganado", ganado_turno))
	gastado_turno = float(d.get("gastado", gastado_turno))
	_hours_paid.clear()
	for h in d.get("horas", []):
		_hours_paid.append(int(h))
	_emit()


func ww_discount() -> float:
	return float(DataLoader.bal("economia/descuento_ww_soles", 15.0)) * Metrics.written_warnings


func _emit() -> void:
	EventBus.economy_changed.emit(saldo, ganado_turno)


## "S/ 12.50"
static func soles(v: float) -> String:
	return "S/ %.2f" % v


## Items de una tienda de balance.json ("expendedora" | "cafeteria_marleny") como lista para el menú.
func shop_items(shop_id: String) -> Array:
	var out: Array = []
	var items: Array = DataLoader.bal("economia/%s/items" % shop_id, [])
	for it in items:
		var id := str(it.get("id", ""))
		out.append({"id": id, "label": tr("SHOP_ITEM_" + id.to_upper()), "price": float(it.get("precio", 0.0)), "data": it})
	return out

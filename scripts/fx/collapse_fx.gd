class_name CollapseFx
extends Node
## Colapso por Fatiga con la cámara del jugador (v0.3 P2, PLAN §8.1): SIN screamer (nadie te mata).
## Sentado: la visión se nubla, la cabeza se va hacia adelante y cae sobre el teclado (la cámara baja
## ~40 cm y queda torcida mirando las teclas). De pie: las piernas fallan, giro y caída al suelo (0,3 m),
## un rebote sordo. DeathAnimations pone encima la viñeta que se cierra con el latido.
## Lo lanza DeathAnimations.play_collapse(); se corta con DeathAnimations.stop_all() (respawn/menú).

var player: Player = null
var seconds: float = 3.8
var _done: bool = false


static func start(p: Player, total: float) -> CollapseFx:
	if p == null:
		return null
	var fx := CollapseFx.new()
	fx.name = "Colapso"
	fx.player = p
	fx.seconds = total
	p.add_child(fx)
	fx._run()
	return fx


func _ready() -> void:
	EventBus.respawned.connect(_on_respawned)


func _on_respawned(_k: String) -> void:
	stop()


func stop() -> void:
	if _done:
		return
	_done = true
	queue_free()


func _run() -> void:
	player.set_cinematic(true)
	var head := player.head
	var cam := player.camera
	var soft := bool(Loc.get_setting("flash_reduction", false))
	# 1) Mareo: balanceo lento que se agranda (dos oscilaciones).
	var sway := create_tween().set_trans(Tween.TRANS_SINE)
	for i in 2:
		var k := 0.6 + i * 0.6
		sway.tween_property(cam, "rotation:z", deg_to_rad(5.0 * k), seconds * 0.06)
		sway.tween_property(cam, "rotation:z", deg_to_rad(-4.0 * k), seconds * 0.06)
	await _wait(seconds * 0.24)
	if _done:
		return
	if player.seated:
		_keyboard_sound()
		# 2) La cabeza cae hacia adelante sobre el teclado.
		var fall := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(head, "position:y", head.position.y - 0.42, seconds * 0.16)
		fall.tween_property(head, "position:z", head.position.z - 0.32, seconds * 0.16)
		fall.tween_property(head, "rotation:x", -1.15, seconds * 0.16)
		fall.tween_property(cam, "rotation:z", deg_to_rad(24.0), seconds * 0.16)
		await _wait(seconds * 0.16)
		if _done:
			return
		AudioManager.play_sting()
		_bump(cam, 0.02 if soft else 0.05)
	else:
		# 2) Las piernas fallan: medio giro, caída al suelo y rebote.
		var fall2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall2.tween_property(head, "position:y", 0.3, seconds * 0.18)
		fall2.tween_property(player, "rotation:y", player.rotation.y + deg_to_rad(35.0), seconds * 0.18)
		fall2.tween_property(cam, "rotation:z", deg_to_rad(78.0), seconds * 0.18)
		fall2.tween_property(head, "rotation:x", 0.15, seconds * 0.18)
		await _wait(seconds * 0.18)
		if _done:
			return
		AudioManager.play_sting()
		_bump(cam, 0.03 if soft else 0.07)
		var settle := create_tween().set_trans(Tween.TRANS_SINE)
		settle.tween_property(head, "position:y", 0.26, 0.12)
		settle.tween_property(head, "position:y", 0.3, 0.2)
	# 3) Quieto: la respiración se apaga (la viñeta y el negro los pone DeathAnimations).
	AudioManager.play_sfx("respiracion")


func _bump(cam: Camera3D, amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(cam, "position", Vector3(0, -amount, 0), 0.05)
	tw.tween_property(cam, "position", Vector3(0, amount * 0.3, 0), 0.08)
	tw.tween_property(cam, "position", Vector3.ZERO, 0.1)


func _keyboard_sound() -> void:
	var path := AudioManager.resolve("ambiente/teclados_lejanos")
	if path == "":
		return
	var ap := AudioStreamPlayer.new()
	ap.stream = load(path) as AudioStream
	ap.bus = "Sala"
	ap.volume_db = -4.0
	ap.pitch_scale = 0.7
	add_child(ap)
	ap.play()
	get_tree().create_timer(0.5, true).timeout.connect(ap.stop)


func _wait(s: float) -> void:
	if s <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(s, true).timeout

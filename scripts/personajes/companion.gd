class_name Companion
extends Node
## Compañero de C-15 (GDD 7.4): nunca levanta la cabeza, pero susurra tres cosas a lo largo del turno
## (voces/comp/*, con subtítulo): "no te pares", "viene Shero", "mira el reflejo". Solo si estás
## sentado en tu sitio de la fila C y a menos de 3 m; cada susurro una vez por turno, con pausa entre ellos.

const COOLDOWN_REAL_S := 45.0

var _said: Dictionary = {}
var _last_real: float = -1000.0
var _rig: CharacterRig = null


func setup(rig: CharacterRig) -> void:
	_rig = rig


func _ready() -> void:
	EventBus.player_stood_up.connect(_on_stood_up)
	EventBus.shero_state_changed.connect(_on_shero_state)
	EventBus.scripted_event.connect(_on_scripted)
	EventBus.shift_started.connect(func() -> void: _said.clear())


func _player_near() -> bool:
	if not GameState.seated_at.begins_with("C-") and GameState.seated_at != "":
		return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var parent := get_parent() as Node3D
	if player == null or parent == null:
		return false
	return player.global_position.distance_to(parent.global_position) <= 3.2


func _whisper(slot: String, key: String) -> void:
	if _said.has(slot) or not GameState.logged_in or GameState.shift_over:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_real < COOLDOWN_REAL_S or not _player_near():
		return
	_said[slot] = true
	_last_real = now
	AudioManager.play_voice("comp", slot, tr(key), "Sala")
	if _rig != null:
		_rig.play("idle", true, 0.6, ["sit"])  # deja de teclear un momento
		await get_tree().create_timer(2.5).timeout
		if is_inside_tree() and _rig != null:
			_rig.play("type", true, 0.9, ["sit", "idle"])


## ¿Alguien te convocó (Rasec a su evento, Haime, el Trainer, Shero, el tópico)? Entonces pararte es lo correcto.
func _summoned() -> bool:
	for a in Metrics.authorizations:
		if not (str(a.get("source", "")) in ["break", "lunch", "bano"]) and float(a.get("until", 0.0)) > GameState.clock_seconds:
			return true
	return false


func _on_stood_up() -> void:
	# Te paraste en Live sin AUX de pausa: "no te pares…" (llega cuando ya estás de pie, a tu espalda).
	# v0.3.2-core: no si te convocaron (antes te decía «no te pares» justo cuando Rasec te llamaba a su evento).
	if Metrics.is_productive(Metrics.aux) and GameState.current_block() >= 1 and not _summoned():
		var player := get_tree().get_first_node_in_group("player") as Node3D
		var parent := get_parent() as Node3D
		if player != null and parent != null and player.global_position.distance_to(parent.global_position) <= 3.5 and not _said.has("comp_no_te_pares"):
			_said["comp_no_te_pares"] = true
			_last_real = Time.get_ticks_msec() / 1000.0
			AudioManager.play_voice("comp", "comp_no_te_pares", tr("COMP_NO_TE_PARES"), "Sala")


func _on_shero_state(state: int) -> void:
	if state == Shero.State.CAMINAR or state == Shero.State.PERSEGUIR:
		_whisper("comp_viene_shero", "COMP_VIENE_SHERO")


func _on_scripted(id: String) -> void:
	if id == "shero_en_el_reflejo":
		# Unos segundos antes de que Shero llegue a tu espalda.
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			_whisper("comp_mira_el_reflejo", "COMP_MIRA_EL_REFLEJO")

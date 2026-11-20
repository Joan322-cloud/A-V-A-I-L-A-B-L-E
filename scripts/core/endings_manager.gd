class_name EndingsManager
extends RefCounted
## v0.4 · Evaluador de los 5 finales de Jiroshi (Renunciar, Despedido, Volverse Shero, Alma en el Software, Secreto).

static func evaluate(fired: bool = false) -> String:
	var p := SaveSlots.progress("Jiroshi")
	var c: Dictionary = p.get("contadores", {})
	var obe := int(c.get("obe", 0))
	var reb := int(c.get("reb", 0))
	var des := int(c.get("des", 0))
	var read_contract := bool(p.get("contrato_leido", false))
	var polaroid_checks := int(c.get("polaroid_vista", 0))

	if fired or Metrics.written_warnings >= 3:
		return "despedido"
	if bool(GameState.flags.get("renuncia_firmada", false)) or reb >= 4:
		return "renunciar"
	if read_contract and polaroid_checks >= 2 and absi(obe - reb) <= 2:
		return "secreto"
	if bool(GameState.flags.get("ascenso_aceptado", false)) or (Metrics.available_pct() >= 85.0 and Metrics.written_warnings == 0 and obe >= reb):
		return "volverse_shero"
	if des >= 3 or Fatigue.value >= 80.0:
		return "alma_en_software"
	return "volverse_shero" if Metrics.available_pct() >= 80.0 else "alma_en_software"

static func trigger_ending(ending_id: String) -> Dictionary:
	SaveSlots.unlock_ending(ending_id, "Jiroshi")
	SaveSlots.unlock_epilogue(ending_id, "Jiroshi")
	var list: Array = DataLoader.dict("finales").get("finales", [])
	for item in list:
		if str((item as Dictionary).get("id", "")) == ending_id:
			return item as Dictionary
	return {"id": ending_id, "titulo": {"es": ending_id, "en": ending_id}, "texto": {"es": "", "en": ""}}

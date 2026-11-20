extends SceneTree
## v0.3.2 IA · `godot --headless --path game -s res://scripts/dev/ia_eval.gd` → acierto del conjunto de prueba de
## intenciones (data/ia/test_intents.json) y los fallos. La prueba de escenario `pia_intents` usa lo mismo.


func _initialize() -> void:
	for file in ["test_intents", "test_intents_holdout", "test_intents_ciego", "test_intents_en", "test_intents_en_ciego"]:
		var r: Dictionary = IAEval.run(file)
		print("[ia_eval] %s: %d/%d = %.1f %% (%.2f ms por línea)" % [file, r["ok"], r["n"], 100.0 * float(r["ok"]) / maxf(1.0, float(r["n"])), r["ms"]])
		for f in r["fallos"]:
			print("  ✗ ", f)
	quit(0)

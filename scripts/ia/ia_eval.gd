class_name IAEval
extends RefCounted
## v0.3.2 IA · Mide el acierto de IANlu sobre data/ia/test_intents.json (lo usan ia_eval.gd y el escenario pia_intents).


static func run(file: String = "test_intents") -> Dictionary:
	var d: Dictionary = IANlu.load_json("res://data/ia/%s.json" % file)
	var lines: Array = d.get("lineas", [])
	var ok := 0
	var fallos: Array = []
	var t0 := Time.get_ticks_usec()
	for l in lines:
		var txt := str(l[0])
		var want: Array = (l as Array).slice(1)
		var got := IANlu.classify(txt)
		if want.has(got):
			ok += 1
		else:
			var a := IANlu.analyze(txt)
			fallos.append("«%s» → %s (quería %s) %s" % [txt, got, "/".join(want), str(a.get("top", []))])
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, float(lines.size()))
	return {"n": lines.size(), "ok": ok, "fallos": fallos, "ms": ms}

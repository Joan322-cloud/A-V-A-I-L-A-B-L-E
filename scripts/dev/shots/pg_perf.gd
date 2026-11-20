## Sin class_name: lo carga scripts/dev/screenshot.gd.
extends RefCounted
## v0.3.2 gfx: tiempo de cuadro en vistas fijas, para comparar builds y calidades bajo el MISMO renderizador
## (p. ej. Baja/liviano antes y después del paquete gráfico). No usa nada de scripts/gfx/: el mismo archivo corre en
## un build anterior. La calidad sale de settings.json («quality»).
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --shot perf
## Imprime «[perf] vista calidad ms dibujos primitivas» (media y mínimo de 3 tandas de 24 cuadros).

const VIEWS: Dictionary = {
	"perf_sala": [2, Vector3(20.5, 0.05, 0.8), -55.0, -0.02],
	"perf_pasillo": [2, Vector3(0.5, 0.05, 2.7), 0.0, -0.05],
	"perf_cafeteria": [-1, Vector3(1.0, 0.05, -7.2), 20.0, -0.08],
}


func shots() -> Array[String]:
	return ["perf_sala", "perf_pasillo", "perf_cafeteria"]


func shoot(name: String, _arg: String, s: Node) -> void:
	var v: Array = VIEWS[name]
	await s._place(int(v[0]), v[1], float(v[2]), float(v[3]))
	for i in 16:
		await s.get_tree().process_frame
	var runs: Array[float] = []
	for r in 3:
		var t0 := Time.get_ticks_usec()
		for i in 24:
			await s.get_tree().process_frame
		runs.append(float(Time.get_ticks_usec() - t0) / 24.0 / 1000.0)
	var mean := (runs[0] + runs[1] + runs[2]) / 3.0
	print("[perf] %s calidad=%s ms_media=%.1f ms_min=%.1f dibujos=%d primitivas=%d escala=%.2f" % [name, str(Loc.get_setting("quality", "?")), mean, runs.min(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		s.get_tree().root.scaling_3d_scale])

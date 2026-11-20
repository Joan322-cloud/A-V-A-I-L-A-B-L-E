class_name GfxBoot
extends RefCounted
## v0.3.2 gfx · Arranque del paquete de gráficos (una vez, en el primer GfxQuality.apply() del juego):
##   · cadenas propias (localization/strings_v032_gfx.*) sin tocar project.godot;
##   · renderizador: opción «Renderizador» (auto / Forward+ / Compatibilidad) y guardia de arranque;
##   · primera vez en escritorio: calidad según la tarjeta, medición de fps y pantalla de brillo;
##   · contador de FPS y V-Sync.
##
## RENDERIZADOR. El proyecto arranca en Forward+ en escritorio y el motor ya cae solo a OpenGL si no hay Vulkan ni
## Direct3D 12 (rendering/rendering_device/fallback_to_opengl3, activo por defecto): el juego NUNCA deja de abrir
## por eso. Encima de eso:
##   · si Forward+ arrancó sobre un adaptador por software (lavapipe, SwiftShader, WARP), se relanza en
##     Compatibilidad (el OpenGL por software rinde mucho más y es lo que usa el Modo liviano);
##   · guardia: al empezar a arrancar en Forward+ se deja una marca en user://gfx_arranque.json y se borra cuando
##     ya se dibujaron cuadros. Si la marca sigue ahí en el arranque siguiente (el anterior se colgó o se cerró
##     antes de dibujar), este arranque se relanza en Compatibilidad y «auto» pasa a significar Compatibilidad
##     hasta que el jugador elija Forward+ a mano;
##   · opción «Renderizador»: si pide uno distinto del que está en uso, se relanza con --rendering-method.
## Relanzar = abrir de nuevo el ejecutable con los mismos argumentos más el renderizador, y cerrar este. Solo en
## builds exportados (con el binario del editor y en las pruebas no se relanza nunca: se anota en el log lo que
## haría). Si la línea de comandos ya trae --rendering-method o --rendering-driver, manda la línea de comandos.
## El argumento de usuario --gfx-relanzado impide un segundo relanzamiento (nunca hay bucle).

const MARK := "user://gfx_arranque.json"
const RELAUNCH_ARG := "--gfx-relanzado"
const STRINGS: Array[String] = ["res://localization/strings_v032_gfx.es.translation", "res://localization/strings_v032_gfx.en.translation"]

static var _done: bool = false
static var _strings_done: bool = false
## Lo que decidió el arranque (para pruebas y para el log): {"accion": "", "metodo": "", "motivo": ""}.
static var decision: Dictionary = {}


## Cadenas del paquete: se suman al servidor de traducciones la primera vez que alguien las necesita.
static func strings() -> void:
	if _strings_done:
		return
	_strings_done = true
	for p in STRINGS:
		if ResourceLoader.exists(p):
			var t := load(p) as Translation
			if t != null:
				TranslationServer.add_translation(t)


static func once(tree: SceneTree) -> void:
	if _done or tree == null:
		return
	_done = true
	if GfxSettings.web():
		return  # el HTML no lleva el paquete: ni renderizador, ni medición, ni brillo, ni contador
	strings()
	EventBus.settings_changed.connect(func(key: String) -> void: _on_setting(key))
	if GfxSettings.headless():
		return
	_renderer(tree)
	_apply_vsync(false)
	GfxFps.sync(tree)
	GfxSubPlate.sync.call_deferred(tree)
	if dev_run():
		return
	GfxBench.first_run(tree)
	GfxCalibration.first_run(tree)


## ¿Es una corrida de desarrollo o de pruebas? (Argumentos de usuario tras «--»: --shot, --escenario, --bot…)
static func dev_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a != RELAUNCH_ARG:
			return true
	return false


static func _on_setting(key: String) -> void:
	match key:
		"quality":
			# Elegir una calidad vuelve a su ajuste: los cambios sueltos de «Gráficos avanzados» se borran.
			if GfxSettings.any_override():
				GfxSettings.reset_overrides()
				if is_instance_valid(GfxDirector.inst):
					GfxDirector.inst.reapply()
		"gfx_vsync":
			_apply_vsync(true)
		"gfx_max_fps":
			GfxQuality.apply_fps_cap()
		"gfx_fps", "gfx_sub_fondo":
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				GfxFps.sync(tree)
				GfxSubPlate.sync(tree)


## V-Sync: mientras nadie toque la opción no se llama a nada (queda lo que trae el proyecto).
static func _apply_vsync(force: bool) -> void:
	var cur: Variant = Loc.get_setting("gfx_vsync", null)
	if cur == null and not force:
		return
	var on := bool(GfxSettings.global("gfx_vsync"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)


# --- calidad por defecto en escritorio ------------------------------------------------------------------------

## Calidad con la que arranca un escritorio que todavía no eligió ninguna: sin tarjeta gráfica (render por
## software) → Modo liviano; integrada → Media; dedicada → Alta. La medición del primer turno la corrige a la baja
## si los fps no alcanzan (GfxBench). En pruebas y corridas de desarrollo queda «media», como siempre.
static func desktop_default() -> String:
	if GfxSettings.headless() or dev_run():
		return "media"
	return level_for(adapter_class())


static func level_for(cls: String) -> String:
	match cls:
		"software": return "liviano"
		"dedicada": return "alta"
	return "media"


## «software», «integrada» o «dedicada», por el tipo que informa el motor y, si no lo sabe (OpenGL), por el nombre.
static func adapter_class() -> String:
	return classify(RenderingServer.get_video_adapter_type(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor())


static func classify(type: int, adapter: String, vendor: String) -> String:
	var a := (adapter + " " + vendor).to_lower()
	for s in ["llvmpipe", "lavapipe", "swiftshader", "softpipe", "software", "microsoft basic render", "warp"]:
		if a.contains(s):
			return "software"
	if type == RenderingDevice.DEVICE_TYPE_CPU:
		return "software"
	if type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		return "dedicada"
	if type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return "integrada"
	for s in ["geforce", "nvidia", "rtx", "gtx", "quadro", "radeon rx", "radeon pro", "intel(r) arc", "arc(tm)"]:
		if a.contains(s):
			return "dedicada"
	return "integrada"


# --- renderizador -----------------------------------------------------------------------------------------------

static func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_args():
		if a == prefix or a.begins_with(prefix + "="):
			return true
	return false


static func _read_mark() -> Dictionary:
	if not FileAccess.file_exists(MARK):
		return {}
	var f := FileAccess.open(MARK, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _write_mark(d: Dictionary) -> void:
	var f := FileAccess.open(MARK, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


## Decisión pura (la usan las pruebas): qué hacer con el renderizador en este arranque.
##   s = {metodo: en uso, quiere: opción guardada, clase: adapter_class(), marca_pendiente: bool, cli: bool,
##        relanzado: bool, fallo_previo: bool}
## Devuelve {accion: "" | "relanzar", metodo, motivo, anotar_fallo: bool}.
static func decide(s: Dictionary) -> Dictionary:
	var cur := str(s.get("metodo", ""))
	var want := str(s.get("quiere", "auto"))
	var out := {"accion": "", "metodo": cur, "motivo": "", "anotar_fallo": false}
	if bool(s.get("cli", false)):
		out["motivo"] = "la línea de comandos fija el renderizador"
		return out
	if bool(s.get("relanzado", false)):
		out["motivo"] = "ya se relanzó una vez"
		return out
	var forward := cur == "forward_plus" or cur == "mobile"
	if want == "gl_compatibility":
		if forward:
			out["accion"] = "relanzar"
			out["metodo"] = "gl_compatibility"
			out["motivo"] = "opción Renderizador = Compatibilidad"
		return out
	if want == "forward_plus":
		if not forward:
			out["accion"] = "relanzar"
			out["metodo"] = "forward_plus"
			out["motivo"] = "opción Renderizador = Forward+"
		return out
	# auto
	if forward and bool(s.get("marca_pendiente", false)):
		out["accion"] = "relanzar"
		out["metodo"] = "gl_compatibility"
		out["motivo"] = "el arranque anterior en Forward+ no llegó a dibujar"
		out["anotar_fallo"] = true
		return out
	if forward and (str(s.get("clase", "")) == "software" or bool(s.get("fallo_previo", false))):
		out["accion"] = "relanzar"
		out["metodo"] = "gl_compatibility"
		out["motivo"] = "adaptador por software" if str(s.get("clase", "")) == "software" else "Forward+ falló en un arranque anterior"
	return out


static func _renderer(tree: SceneTree) -> void:
	var cur := RenderingServer.get_current_rendering_method()
	var mark := _read_mark()
	var s := {
		"metodo": cur,
		"quiere": str(GfxSettings.global("gfx_renderer")),
		"clase": adapter_class(),
		"marca_pendiente": str(mark.get("metodo", "")) == "forward_plus" and not bool(mark.get("ok", true)),
		"cli": _has_arg("--rendering-method") or _has_arg("--rendering-driver"),
		"relanzado": OS.get_cmdline_user_args().has(RELAUNCH_ARG),
		"fallo_previo": bool(Loc.get_setting("gfx_forward_fallo", false)),
	}
	decision = decide(s)
	if bool(decision.get("anotar_fallo", false)):
		Loc.set_setting("gfx_forward_fallo", true)
	if str(decision["accion"]) == "relanzar":
		if OS.has_feature("editor") or OS.has_feature("web") or dev_run():
			print("[gfx] renderizador: se relanzaría en %s (%s); no se hace con el binario del editor ni en pruebas" % [decision["metodo"], decision["motivo"]])
		else:
			_write_mark({"metodo": cur, "ok": true})
			var args := PackedStringArray()
			for a in OS.get_cmdline_args():
				args.append(a)
			args.append("--rendering-method")
			args.append(str(decision["metodo"]))
			if str(decision["metodo"]) == "gl_compatibility":
				args.append("--rendering-driver")
				args.append("opengl3")
			args.append("--")
			for a in OS.get_cmdline_user_args():
				args.append(a)
			args.append(RELAUNCH_ARG)
			print("[gfx] renderizador: relanzando en %s (%s)" % [decision["metodo"], decision["motivo"]])
			if OS.create_process(OS.get_executable_path(), args) > 0:
				tree.quit()
				return
	# Guardia: marca «arrancando» y, cuando ya se dibujaron cuadros, «ok».
	if dev_run() or OS.has_feature("editor"):
		return
	_write_mark({"metodo": cur, "ok": false})
	var w := _Mark.new()
	w.name = "GfxArranque"
	w.method = cur
	tree.root.add_child.call_deferred(w)


## Elegir Forward+ a mano borra la nota de fallo (el jugador quiere volver a intentarlo).
static func set_renderer(v: String) -> void:
	GfxSettings.set_global("gfx_renderer", v)
	if v == "forward_plus":
		Loc.set_setting("gfx_forward_fallo", false)


class _Mark extends Node:
	var method: String = ""
	var _frames: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames >= 90:
			GfxBoot._write_mark({"metodo": method, "ok": true})
			queue_free()

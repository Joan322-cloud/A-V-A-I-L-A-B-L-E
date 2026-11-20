class_name GfxSubPlate
extends Panel
## v0.3.2 gfx · Fondo oscuro tras los subtítulos y los avisos del HUD (Gráficos avanzados → «Fondo oscuro tras los
## subtítulos», apagado por defecto). El borde negro de las letras ya existe; sobre un piso muy iluminado o una
## pantalla clara, la placa asegura el contraste. No toca ui/hud.gd: se cuelga de sus dos etiquetas (detrás del
## texto) y se ajusta sola al tamaño de lo escrito; sin texto no se dibuja.

const PAD := Vector2(12, 5)

var _label: Label = null


## Pone o quita las placas según la opción (al arrancar y cuando cambia).
static func sync(tree: SceneTree) -> void:
	var want := bool(GfxSettings.global("gfx_sub_fondo"))
	for hud in tree.root.find_children("HUD", "Control", true, false):
		for prop in ["_sub", "_msg"]:
			var l: Variant = hud.get(prop)
			if not (l is Label):
				continue
			var have := (l as Label).get_node_or_null("GfxPlaca")
			if want and have == null:
				var p := GfxSubPlate.new()
				p.name = "GfxPlaca"
				(l as Label).add_child(p)
			elif not want and have != null:
				have.queue_free()


func _ready() -> void:
	_label = get_parent() as Label
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", sb)
	visible = false


func _process(_delta: float) -> void:
	if _label == null:
		return
	var text := _label.text
	if text == "":
		visible = false
		return
	var font := _label.get_theme_font("font")
	var fs := _label.get_theme_font_size("font_size")
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _label.size.x, fs)
	var w := minf(sz.x, _label.size.x)
	position = Vector2((_label.size.x - w) * 0.5 - PAD.x, -PAD.y)
	size = Vector2(w + PAD.x * 2.0, maxf(sz.y, float(fs)) + PAD.y * 2.0)
	visible = true

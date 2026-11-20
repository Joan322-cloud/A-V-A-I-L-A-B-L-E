class_name PcStyle
extends RefCounted
## Estilo de la PC (software corporativo viejo, oscuro y opresivo) y utilidades comunes de las apps:
## tamaños de letra pensados para leerse a 1280×720 con las dos pantallas juntas, botones planos, insignias,
## emojis (dibujos propios en los RichTextLabel, etiqueta de texto en los Label: Emoji) y el texto "corrompido" de
## madrugada con Fatiga alta.

const W := 800
const H := 492
const F_BIG := 20
const F_BODY := 17
const F_SMALL := 15
const F_TINY := 13

const BG := Color(0.055, 0.065, 0.08)
const BAR := Color(0.12, 0.15, 0.19)
const PANEL := Color(0.09, 0.11, 0.14)
const PANEL_HI := Color(0.14, 0.17, 0.22)
const BORDER := Color(0.28, 0.34, 0.42)
const TEXT := Color(0.86, 0.89, 0.9)
const DIM := Color(0.56, 0.61, 0.66)
const ACCENT := Color(0.33, 0.58, 0.92)
const GREEN := Color(0.25, 0.78, 0.48)
const YELLOW := Color(0.93, 0.76, 0.27)
const RED := Color(0.9, 0.14, 0.12)
const VITZO := Color(0.35, 0.82, 0.5)

## Texto para un Label o un subtítulo (sin BBCode): sin emojis (la fuente no los tiene). Los que significan algo
## quedan como etiqueta («[OK]», «[+1]»); los de adorno se quitan. Para un RichTextLabel usa rich().
static func clean(text: String) -> String:
	return Emoji.plain(text)


## Texto para un RichTextLabel: los emojis salen como dibujo (Emoji, assets/ui/emoji).
static func rich(text: String, px: int = 18) -> String:
	return Emoji.rich(text, px)


## Un emoji suelto para un RichTextLabel (el dibujo; su nombre queda de tooltip).
static func emoji_label(e: String, px: int = 18, tip: bool = true) -> String:
	return Emoji.bb(e, px, tip)


static func box(color: Color, border: Color = Color(0, 0, 0, 0), margin: float = 6.0, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	if border.a > 0.0:
		sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	sb.set_corner_radius_all(radius)
	return sb


static func panel(color: Color = PANEL, margin: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, BORDER, margin))
	return p


static func label(text: String, size: int = F_BODY, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable, size: int = F_SMALL, color: Color = PANEL_HI) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box(color, BORDER, 5.0))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), ACCENT, 5.0))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), ACCENT, 5.0))
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.35), BORDER.darkened(0.4), 5.0))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", DIM.darkened(0.3))
	b.pressed.connect(cb)
	return b


static func option(items: Array, selected_text: String, cb: Callable, placeholder: String = "—") -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_size_override("font_size", F_SMALL)
	o.add_theme_stylebox_override("normal", box(PANEL_HI, BORDER, 4.0))
	o.add_theme_stylebox_override("hover", box(PANEL_HI.lightened(0.1), ACCENT, 4.0))
	o.add_item(placeholder)
	var sel := 0
	for i in items.size():
		o.add_item(str(items[i]))
		if str(items[i]) == selected_text and selected_text != "":
			sel = i + 1
	o.select(sel)
	o.item_selected.connect(func(idx: int) -> void: cb.call("" if idx == 0 else str(items[idx - 1])))
	o.get_popup().add_theme_font_size_override("font_size", F_SMALL)
	return o


static func hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 4)
	return s


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func color_hex(c: Color) -> String:
	return "#" + c.to_html(false)


## Texto de madrugada: con Fatiga ≥ 70 algunas palabras de la línea del cliente se oscurecen o se cambian
## por un susurro (solo en la línea del cliente; las opciones siempre se leen bien).
static func haunt(text: String, seed: int) -> String:
	var f := Fatigue.value
	if f < 70.0 or text == "":
		return text
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var whispers := ["no cuelgues", "te escucho", "sigues aquí", "detrás", "no hay breaks", "respira"]
	var words := text.split(" ")
	var chance := clampf((f - 70.0) / 60.0, 0.05, 0.35)
	for i in words.size():
		if rng.randf() < chance * 0.4:
			words[i] = "[color=#5a1010]%s[/color]" % words[i]
	var out := " ".join(words)
	if rng.randf() < chance:
		out += "  [color=#7a2020][i](%s)[/i][/color]" % whispers[rng.randi_range(0, whispers.size() - 1)]
	return out

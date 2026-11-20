class_name CreditsScreen
extends Control
## Créditos como "Acerca de Fonex": roles sin nombres reales, motor, fuente y aviso de ficción.

signal closed()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	add_child(bg)
	var p := UITheme.panel(tr("CREDITS_TITLE"), Vector2(760, 0))
	add_child(p)
	UITheme.center_fit(p)
	var vb := UITheme.vb_of(p)
	vb.add_theme_constant_override("separation", 8)
	var title := UITheme.label(tr("GAME_TITLE"), 34, UITheme.TEXT, true)
	vb.add_child(title)
	vb.add_child(UITheme.label(tr("GAME_SUBTITLE"), 15, UITheme.DIM, true))
	vb.add_child(HSeparator.new())
	for i in range(1, 10):
		var key := "CREDITS_L%d" % i
		var txt := tr(key)
		if txt == key:
			continue
		var l := UITheme.label(txt, 15 if i < 8 else 13, UITheme.TEXT if i < 8 else UITheme.DIM)
		l.custom_minimum_size = Vector2(720, 0)
		vb.add_child(l)
	vb.add_child(HSeparator.new())
	var godot := UITheme.label(tr("CREDITS_GODOT"), 15, UITheme.EZLAK, true)
	vb.add_child(godot)
	vb.add_child(UITheme.button(tr("OPT_BACK"), func() -> void: closed.emit()))

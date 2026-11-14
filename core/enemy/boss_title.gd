class_name BossTitle
extends CanvasLayer
## the boss's name as a title, in the encounter HUD's voice (Cinzel, dusk-gold, a subtitle
## beneath), arriving as he rises instead of one small line of toast-coloured text. Large, centred over the
## upper third where the camera (BossFrame) has put him, fades in with the rise and out before the roar
## ends. Layer 41, like the raid-warning line: the unit frames hide the bar layer, not this. Pure UI, no
## per-frame work (one tween).

const TITLE_FONT := "res://ui/fonts/Cinzel.ttf"
const GOLD := Color(1.0, 0.82, 0.5)
const HOLD := 3.0
const TextDirector := preload("res://ui/text_director.gd")


static func show_for(host: Node, title: String, subtitle: String, col := GOLD) -> BossTitle:
	# one large card at a time, and this one wins: the text director clears a zone card or a discovery banner
	var td := TextDirector.of(host)
	if td != null:
		td.begin(&"boss_title", HOLD + 0.4, Rect2(host.get_viewport().get_visible_rect().size.x * 0.5 - 700.0, 206.0, 1400.0, 150.0), true)
	var t := BossTitle.new()
	t.layer = 41
	t.name = "BossTitle"
	t.add_to_group(&"boss_title")           # the HUD holds its lessons while a name card is up
	host.add_child(t)
	t._build(title, subtitle, col)
	return t


func _build(title: String, subtitle: String, col: Color) -> void:
	var font := load(TITLE_FONT) as Font
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -700
	box.offset_right = 700
	box.offset_top = 210
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(_label(title.to_upper(), 64, col, font))
	var rule := ColorRect.new()                       # a thin gilt rule between name and epithet
	rule.color = Color(col.r, col.g, col.b, 0.55)
	rule.custom_minimum_size = Vector2(420, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	box.add_child(_label(subtitle, 26, Color(0.86, 0.82, 0.94), font))
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.7)
	tw.tween_interval(HOLD - 1.9)
	tw.tween_property(box, "modulate:a", 0.0, 1.2)
	tw.tween_callback(queue_free)


func _label(text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	return l

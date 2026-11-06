extends RefCounted
## The small widgets the gear page is made of: labels, rich text, slot chips, action buttons (a name, its
## key chip and a line of cost) and the tooltip cards. Static, no state. Load by path:
##   const W := preload("res://ui/gear_widgets.gd")

const UIType := preload("res://ui/type.gd")
const Med := preload("res://ui/medieval_style.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM


static func label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else UIType.body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


static func rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", UIType.body())
	r.add_theme_font_override("bold_font", UIType.body())
	r.add_theme_font_override("italics_font", UIType.body())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 2)
	r.add_theme_font_size_override("italics_font_size", size - 1)
	r.add_theme_color_override("default_color", INK)
	return r


static func chip(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_override("font", UIType.title())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", QUIET)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", Med.GILT)
	b.add_theme_color_override("font_hover_pressed_color", Med.GILT)
	Med.style_tab(b)
	b.pressed.connect(cb)
	return b


## An action button: its name and its key chip on one line, the cost (or what it does) beneath.
static func action(name: String, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 86)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Med.style_button(b, 17, 12, 8)
	b.pressed.connect(cb)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14.0
	col.offset_right = -12.0
	col.offset_top = 8.0
	col.offset_bottom = -6.0
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var nm := label(name, 18, INK, UIType.title())
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(nm)
	var kc := PanelContainer.new()
	var ksb := Med.slot(Med.BRONZE.lightened(0.2))
	ksb.set_content_margin_all(2)
	ksb.content_margin_left = 8
	ksb.content_margin_right = 8
	kc.add_theme_stylebox_override("panel", ksb)
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kl := label(key, 13, Med.GILT, UIType.title())
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kc.add_child(kl)
	top.add_child(kc)
	var sub := label("", 15, QUIET)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	b.set_meta(&"name", nm)
	b.set_meta(&"sub", sub)
	return b


static func set_action(b: Button, name: String, sub: String) -> void:
	(b.get_meta(&"name") as Label).text = name
	(b.get_meta(&"sub") as Label).text = sub
	var disabled := b.disabled
	(b.get_meta(&"name") as Label).add_theme_color_override("font_color", Med.BONE_FAINT if disabled else INK)


static func card(caption: String) -> Array:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	var cap := label(caption, 15, QUIET, UIType.title())
	wrap.add_child(cap)
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", Med.slip_dark(LootDB.quality_color(0)))
	wrap.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.add_child(sc)
	var r := rich(19)
	sc.add_child(r)
	return [wrap, pc, r, cap]

extends RefCounted
## One medieval look for every menu. Adopt it: `const Med := preload("res://ui/medieval_style.gd")`, `root.theme = Med.theme()`, then build boxes from
## Med.panel/slot/plaque/tab/banner/rule and the BONE/GILT/INK colours. ui/medieval_theme.tres is the baked Theme; art/ui/*.png come from tools/gen_ui_textures.gd.

const UIType := preload("res://ui/type.gd")
const DIR := "res://art/ui/"

## Warm bone on dark leather, ink-brown on parchment, gilt for names and the lit entry.
const BONE := Color(0.93, 0.87, 0.74)
const BONE_DIM := Color(0.74, 0.66, 0.52)
const BONE_FAINT := Color(0.56, 0.49, 0.38)
const GILT := Color(0.95, 0.78, 0.4)
const GILT_DEEP := Color(0.78, 0.58, 0.24)
const BRONZE := Color(0.62, 0.45, 0.2)
const INK := Color(0.16, 0.09, 0.05)
const INK_DIM := Color(0.36, 0.25, 0.15)
const INK_RED := Color(0.5, 0.12, 0.08)
const OXBLOOD := Color(0.42, 0.08, 0.07)
const LEATHER := Color(0.12, 0.075, 0.045)
const LEATHER_DEEP := Color(0.07, 0.045, 0.03)
const IRON := Color(0.34, 0.34, 0.37)
const BACKDROP := Color(0.02, 0.012, 0.006, 0.7)

static var _theme: Theme
static var _tex := {}
static var _knob_tex: Texture2D
static var _knob_hi_tex: Texture2D
static var _on_tex: Texture2D
static var _off_tex: Texture2D


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png")
	return _tex[n]


static func _nine(n: String, margin: int, pad := 10, tint := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(n)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(pad)
	sb.modulate_color = tint
	return sb


## "leather" (dark oiled hide, bronze fittings), "parchment" (inked vellum) or "slip" (a small torn tooltip slip).
static func panel(kind := "leather", pad := 26) -> StyleBoxTexture:
	match kind:
		"parchment":
			return _nine("parchment_panel", 26, pad)
		"slip":
			return _nine("parchment_slip", 12, 8)
	return _nine("leather_panel", 48, pad)        # the forged frame (192 px, 48 px corners)


## A tea-stained, darkened slip for tooltips that carry light text in rarity colours; `rim` leans the stain towards a colour.
static func slip_dark(rim := Color(0.5, 0.42, 0.32)) -> StyleBoxTexture:
	var sb := _nine("parchment_slip", 12, 12)
	sb.modulate_color = Color(0.3, 0.22, 0.15).lerp(rim.darkened(0.45), 0.4)
	return sb


## A flat inset recess of leather (a list well, a text block), thin lit rim underneath.
static func inset(pad := 10) -> StyleBoxTexture:
	return _nine("inset", 10, pad)


## An item or ability socket: leather inset, metal rim. The tint colours the rim (rarity); white leaves bare iron.
static func slot(tint := Color.WHITE) -> StyleBoxTexture:
	return _nine("slot", 12, 4, tint)


static func frame(pad := 8) -> StyleBoxTexture:
	return _nine("iron_frame", 10, pad)


static func banner() -> StyleBoxTexture:
	var sb := _nine("banner", 14, 6)
	sb.texture_margin_right = 22
	sb.content_margin_right = 26
	sb.content_margin_left = 16
	return sb


## state: normal, hover, pressed, disabled, focus
static func plaque(state := "normal", pad_x := 14, pad_y := 6) -> StyleBoxTexture:
	var sb := _nine("plaque_" + state, 12, 6)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func tab(on: bool) -> StyleBoxTexture:
	var sb := _nine("tab_on" if on else "tab_off", 12, 4)
	sb.texture_margin_bottom = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


## Plaque button states onto any Button; size 0 keeps the font size already set.
static func style_button(b: Button, size := 0, pad_x := 14, pad_y := 6) -> void:
	b.add_theme_stylebox_override("normal", plaque("normal", pad_x, pad_y))
	b.add_theme_stylebox_override("hover", plaque("hover", pad_x, pad_y))
	b.add_theme_stylebox_override("pressed", plaque("pressed", pad_x, pad_y))
	b.add_theme_stylebox_override("hover_pressed", plaque("pressed", pad_x, pad_y))
	b.add_theme_stylebox_override("disabled", plaque("disabled", pad_x, pad_y))
	b.add_theme_stylebox_override("focus", plaque("focus", pad_x, pad_y))
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", Color(1, 0.94, 0.78))
	b.add_theme_color_override("font_focus_color", Color(1, 0.94, 0.78))
	b.add_theme_color_override("font_pressed_color", GILT)
	b.add_theme_color_override("font_disabled_color", BONE_FAINT)
	if size > 0:
		b.add_theme_font_size_override("font_size", size)


## A leather bookmark tab: the lit one is lighter with gilt stitching.
static func style_tab(b: Button) -> void:
	var off := tab(false)
	var hov := tab(false)
	hov.modulate_color = Color(1.35, 1.25, 1.1)
	var on := tab(true)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", BONE_DIM)
	b.add_theme_color_override("font_hover_color", BONE)
	b.add_theme_color_override("font_pressed_color", GILT)
	b.add_theme_color_override("font_hover_pressed_color", GILT)


## Gilt-ink title: Cinzel in warm gold, a dark outline for the engraved edge.
static func gilt(l: Label, size: int, col := GILT) -> void:
	l.add_theme_font_override("font", UIType.title())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.045, 0.01))
	l.add_theme_constant_override("outline_size", maxi(2, size / 14))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)


## BBCode for a book page: the first letter large in Cinzel, the rest at body size.
static func drop_cap(text: String, cap_size := 56, col := Color("#7A1E12")) -> String:
	if text.is_empty():
		return text
	return "[font=%s][font_size=%d][color=#%s]%s[/color][/font_size][/font]%s" % [
		UIType.TITLE_PATH, cap_size, col.to_html(false), text.substr(0, 1), text.substr(1)]


## An ink rule with a small diamond at its centre. Add it to any container.
class InkRule extends Control:
	var col := Color(0.62, 0.45, 0.2)
	var flourish := true

	func _init(c := Color(0.62, 0.45, 0.2), fl := true) -> void:
		col = c
		flourish = fl
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var cx := size.x * 0.5
		var gap := 21.0 if flourish else 0.0
		# an engraved rule, full near the middle and fading out to the ends, with its shadow cut below
		var n := 20
		for side: float in [-1.0, 1.0]:
			var x0 := cx + side * gap
			var x1 := 0.0 if side < 0.0 else size.x
			for i in n:
				var pa := Vector2(lerpf(x0, x1, float(i) / n), y)
				var pb := Vector2(lerpf(x0, x1, float(i + 1) / n), y)
				var fade := 1.0 - pow(float(i) / n, 1.6)
				draw_line(pa, pb, Color(col, col.a * fade), 1.0)
				draw_line(pa + Vector2(0, 1), pb + Vector2(0, 1), Color(0, 0, 0, 0.5 * fade), 1.0)
		if not flourish:
			return
		# a faceted lozenge between two small curls, a dot beyond each
		var d := 5.5
		var dark := Color(0, 0, 0, 0.75)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - d - 1.6, y), Vector2(cx, y - d - 1.6), Vector2(cx + d + 1.6, y), Vector2(cx, y + d + 1.6)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - d, y), Vector2(cx, y - d), Vector2(cx + d, y), Vector2(cx, y + d)]), col)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - d, y), Vector2(cx, y - d), Vector2(cx, y)]), col.lightened(0.4))
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y), Vector2(cx + d, y), Vector2(cx, y + d)]), col.darkened(0.35))
		draw_arc(Vector2(cx - 11.0, y), 4.5, PI * 0.38, PI * 1.62, 10, col, 1.4, true)
		draw_arc(Vector2(cx + 11.0, y), 4.5, -PI * 0.62, PI * 0.62, 10, col, 1.4, true)
		draw_circle(Vector2(cx - 18.5, y), 1.5, col)
		draw_circle(Vector2(cx + 18.5, y), 1.5, col)


static func rule(col := BRONZE, flourish := true) -> Control:
	return InkRule.new(col, flourish)


## The same rule as a StyleBox for HSeparator (no flourish).
static func line_box(col := BRONZE) -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = Color(col, 0.7)
	l.thickness = 1
	return l


static func _disc(s: int, rim: Color, core: Color, shine := true) -> Texture2D:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s, s) * 0.5 - Vector2(0.5, 0.5)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c)
			var r := s * 0.5 - 1.0
			if d > r:
				continue
			var col := rim if d > r - 2.5 else core
			if shine and d < r - 2.5:
				var hl := clampf(1.0 - Vector2(x - c.x + 3.0, y - c.y + 3.0).length() / (r * 0.8), 0.0, 1.0)
				col = col.lightened(hl * 0.5)
			if d > r - 1.0:
				col = Color(0.05, 0.03, 0.02)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _socket(on: bool) -> Texture2D:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in s:
		for x in s:
			var e := mini(mini(x, s - 1 - x), mini(y, s - 1 - y))
			if e == 0:
				img.set_pixel(x, y, Color(0.04, 0.025, 0.015))
			elif e <= 2:
				img.set_pixel(x, y, BRONZE.lightened(0.15) if (x + y) < s else BRONZE.darkened(0.35))
			elif e == 3:
				img.set_pixel(x, y, Color(0.03, 0.02, 0.012))
			else:
				img.set_pixel(x, y, LEATHER_DEEP)
	var tx := ImageTexture.create_from_image(img)
	if on:
		var gem := _disc(12, GILT_DEEP, GILT)
		img.blend_rect(gem.get_image(), Rect2i(0, 0, 12, 12), Vector2i(6, 6))
		tx = ImageTexture.create_from_image(img)
	return tx


static func _scroll_flat(col: Color, w := 8, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = w * 0.5
	sb.content_margin_right = w * 0.5
	sb.content_margin_top = w * 0.5
	sb.content_margin_bottom = w * 0.5
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	return sb


## The shared Theme. Pages set `root.theme = Med.theme()`.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UIType.body()
	t.default_font_size = 18
	for cls in ["Label", "CheckButton", "CheckBox", "OptionButton"]:
		t.set_color("font_color", cls, BONE)
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font("normal_font", "RichTextLabel", UIType.body())
	t.set_font("bold_font", "RichTextLabel", UIType.body())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	# panels
	t.set_stylebox("panel", "PanelContainer", panel("leather"))
	t.set_stylebox("panel", "Panel", panel("leather"))
	# buttons as carved plaques
	for cls in ["Button", "OptionButton"]:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(st, cls, plaque(st))
		t.set_stylebox("hover_pressed", cls, plaque("pressed"))
		t.set_color("font_color", cls, BONE)
		t.set_color("font_hover_color", cls, Color(1, 0.94, 0.78))
		t.set_color("font_focus_color", cls, Color(1, 0.94, 0.78))
		t.set_color("font_pressed_color", cls, GILT)
		t.set_color("font_hover_pressed_color", cls, GILT)
		t.set_color("font_disabled_color", cls, BONE_FAINT)
	# toggles as brass sockets
	_on_tex = _on_tex if _on_tex else _socket(true)
	_off_tex = _off_tex if _off_tex else _socket(false)
	for cls in ["CheckButton", "CheckBox"]:
		for ic in ["checked", "checked_mirrored"]:
			t.set_icon(ic, cls, _on_tex)
		for ic in ["unchecked", "unchecked_mirrored", "checked_disabled", "unchecked_disabled"]:
			t.set_icon(ic, cls, _off_tex)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var e := StyleBoxEmpty.new()
			e.content_margin_left = 4
			e.content_margin_right = 4
			t.set_stylebox(st, cls, e)
		t.set_stylebox("focus", cls, plaque("focus", 4, 2))
		t.set_color("font_hover_color", cls, Color(1, 0.94, 0.78))
		t.set_color("font_pressed_color", cls, BONE)
		t.set_color("font_hover_pressed_color", cls, BONE)
		t.set_color("font_focus_color", cls, Color(1, 0.94, 0.78))
	# scrollbars as thin iron rods
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, _scroll_flat(Color(0.05, 0.03, 0.02, 0.8), 6, Color(0.2, 0.14, 0.08)))
		t.set_stylebox("scroll_focus", cls, _scroll_flat(Color(0.05, 0.03, 0.02, 0.8), 6, GILT_DEEP))
		t.set_stylebox("grabber", cls, _scroll_flat(IRON, 6, Color(0.1, 0.1, 0.12)))
		t.set_stylebox("grabber_highlight", cls, _scroll_flat(IRON.lightened(0.25), 6, Color(0.1, 0.1, 0.12)))
		t.set_stylebox("grabber_pressed", cls, _scroll_flat(GILT_DEEP, 6, Color(0.1, 0.1, 0.12)))
	# sliders: iron rod with a brass knob
	_knob_tex = _knob_tex if _knob_tex else _disc(20, BRONZE.lightened(0.1), BRONZE)
	_knob_hi_tex = _knob_hi_tex if _knob_hi_tex else _disc(20, GILT, GILT_DEEP)
	for cls in ["HSlider", "VSlider"]:
		var rod := _scroll_flat(Color(0.06, 0.04, 0.03), 4, Color(0.3, 0.3, 0.33))
		rod.content_margin_top = 3
		rod.content_margin_bottom = 3
		t.set_stylebox("slider", cls, rod)
		var fill := _scroll_flat(BRONZE, 4, Color(0.3, 0.2, 0.08))
		fill.content_margin_top = 3
		fill.content_margin_bottom = 3
		t.set_stylebox("grabber_area", cls, fill)
		t.set_stylebox("grabber_area_highlight", cls, fill)
		t.set_icon("grabber", cls, _knob_tex)
		t.set_icon("grabber_highlight", cls, _knob_hi_tex)
		t.set_icon("grabber_disabled", cls, _knob_tex)
	# dividers
	t.set_stylebox("separator", "HSeparator", line_box())
	t.set_constant("separation", "HSeparator", 10)
	t.set_stylebox("separator", "VSeparator", line_box())
	# tooltips: a torn parchment slip
	t.set_stylebox("panel", "TooltipPanel", panel("slip"))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 16)
	# dropdown lists
	var pm := StyleBoxFlat.new()
	pm.bg_color = Color(0.1, 0.065, 0.04, 0.98)
	pm.border_color = BRONZE
	pm.set_border_width_all(2)
	pm.set_corner_radius_all(2)
	pm.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", pm)
	var ph := StyleBoxFlat.new()
	ph.bg_color = Color(0.32, 0.2, 0.09)
	ph.border_color = GILT_DEEP
	ph.set_border_width_all(1)
	t.set_stylebox("hover", "PopupMenu", ph)
	t.set_color("font_color", "PopupMenu", BONE)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.94, 0.78))
	t.set_color("font_separator_color", "PopupMenu", BONE_DIM)
	t.set_stylebox("separator", "PopupMenu", line_box())
	t.set_stylebox("panel", "ItemList", inset(6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", BONE_DIM)
	t.set_color("font_selected_color", "ItemList", GILT)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.32, 0.2, 0.09, 0.8)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	_theme = t
	return t

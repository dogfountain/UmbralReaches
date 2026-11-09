extends RefCounted
## The one item card (gear page, tooltips, the loot window, the pack): a frame in the item's rarity colour,
## a header band carrying the name with small ornamented ends, then the body in blocks with an engraved
## divider between them. Blocks are BBCode strings split on DIV / DIV_STRONG (see ui/item_tooltip.gd, which
## writes them). Load by path:
##   const Card := preload("res://ui/item_card.gd")
##   var card := Card.make(340.0)               # a PanelContainer; Card.make(w, true) scrolls its body
##   Card.fill(card, "Name", quality, bbcode)   # name "" hides the band

const UIType := preload("res://ui/type.gd")
const Med := preload("res://ui/medieval_style.gd")
const LootDB := preload("res://core/items/loot_db.gd")

const DIV := "\u0001"             ## a plain engraved divider
const DIV_STRONG := "\u0002"      ## the divider with a lozenge (under the type line)
const BODY_SIZE := 17

static var _italic: Font


## Body italics: the body serif sheared, so the flavour text really leans.
static func italic() -> Font:
	if _italic == null:
		var fv := FontVariation.new()
		fv.base_font = UIType.body()
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
		_italic = fv
	return _italic


class Band extends PanelContainer:
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		for side: float in [0.0, 1.0]:
			var x := 16.0 if side == 0.0 else size.x - 16.0
			var dir := 1.0 if side == 0.0 else -1.0
			draw_line(Vector2(x + dir * 9.0, y), Vector2(x + dir * 20.0, y), Color(col, 0.7), 1.0)
			var d := 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - d - 1, y), Vector2(x, y - d - 1), Vector2(x + d + 1, y), Vector2(x, y + d + 1)]), Color(0, 0, 0, 0.7))
			draw_colored_polygon(PackedVector2Array([Vector2(x - d, y), Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(x - d, y), Vector2(x, y - d), Vector2(x, y)]), col.lightened(0.4))
		draw_line(Vector2(0, 1), Vector2(size.x, 1), Color(col.lightened(0.3), 0.5), 1.0)


static func _band_box(q: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(q.r * 0.34, q.g * 0.34, q.b * 0.34, 0.92).lerp(Color(0.05, 0.03, 0.02), 0.45)
	sb.border_color = q
	sb.border_width_bottom = 2
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 8
	sb.content_margin_bottom = 9
	return sb


static func make(width := 0.0, scroll := false) -> PanelContainer:
	var pc := PanelContainer.new()
	var fr := Med.slot(LootDB.quality_color(0))
	fr.set_content_margin_all(5)
	pc.add_theme_stylebox_override("panel", fr)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		pc.custom_minimum_size.x = width
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(col)
	var band := Band.new()
	var nm := Label.new()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_override("font", UIType.title())
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.9))
	nm.add_theme_constant_override("outline_size", 3)
	band.add_child(nm)
	col.add_child(band)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 12)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(body)
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(m)
		col.add_child(sc)
	else:
		col.add_child(m)
	pc.set_meta(&"band", band)
	pc.set_meta(&"name", nm)
	pc.set_meta(&"body", body)
	return pc


static func rich(size := BODY_SIZE) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", UIType.body())
	r.add_theme_font_override("bold_font", UIType.body())
	r.add_theme_font_override("italics_font", italic())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 2)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", Med.BONE)
	return r


## Tint the frame and the band for a quality.
static func set_quality(card: PanelContainer, q: int) -> void:
	var qc := LootDB.quality_color(q)
	var fr := card.get_theme_stylebox("panel") as StyleBoxTexture
	if fr:
		fr.modulate_color = Color(1, 1, 1).lerp(qc, 0.55) if q > 0 else Color(1, 1, 1)
	var band := card.get_meta(&"band") as Band
	band.col = qc
	band.add_theme_stylebox_override("panel", _band_box(qc))
	(card.get_meta(&"name") as Label).add_theme_color_override("font_color", qc.lightened(0.3))
	band.queue_redraw()


## Show `bb` (blocks split on DIV / DIV_STRONG) under the name `nm` in quality `q`.
static func fill(card: PanelContainer, nm: String, q: int, bb: String, size := BODY_SIZE) -> void:
	set_quality(card, q)
	var band := card.get_meta(&"band") as Control
	band.visible = nm != ""
	(card.get_meta(&"name") as Label).text = nm
	var body := card.get_meta(&"body") as VBoxContainer
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var rest := bb
	while rest != "":
		var cut := -1
		var kind := ""
		for i in rest.length():
			var ch := rest.unicode_at(i)
			if ch == 1 or ch == 2:
				cut = i
				kind = "strong" if ch == 2 else "plain"
				break
		var chunk := rest if cut < 0 else rest.substr(0, cut)
		chunk = chunk.strip_edges()
		if chunk != "":
			var r := rich(size)
			r.text = chunk
			body.add_child(r)
		if cut < 0:
			break
		rest = rest.substr(cut + 1)
		if rest.strip_edges() != "" and body.get_child_count() > 0:
			body.add_child(Med.rule(Color(Med.BRONZE, 0.85), kind == "strong"))

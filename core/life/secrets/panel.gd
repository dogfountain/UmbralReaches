extends CanvasLayer
## The secrets' own UI (no class_name): a reading panel for their writings, styled like the
## journal's reader (ui/codex.gd), and a small banner when a secret place is found or opened.
## It never pauses; the reading closes when the wanderer walks off, reads again, or is hurt.

const Pages := preload("res://core/life/secrets/pages.gd")
const TextDirector := preload("res://ui/text_director.gd")
const INK := Color(0.93, 0.88, 0.8)
const PAPER := Color(0.85, 0.8, 0.72)
const QUIET := Color(0.6, 0.55, 0.62)
const EMBER := Color(1.0, 0.62, 0.3)
const COLD := Color(0.62, 0.8, 1.0)
const EDGE := Color(0.46, 0.34, 0.26)
const BG := Color(0.05, 0.035, 0.04, 0.95)
const CLOSE_DIST := 4.5

var _reader: PanelContainer
var _meta: Label
var _title: Label
var _body: Label
var _foot: Label
var _src: Node3D
var _id := ""
var _tw: Tween
var _banner: VBoxContainer
var _b_top: Label
var _b_name: Label
var _b_tw: Tween
var _bq: Array[Array] = []        ## banners waiting for the text director: [top, name]


func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("secrets_panel")
	var title_font: Font = load("res://ui/fonts/Cinzel.ttf") if ResourceLoader.exists("res://ui/fonts/Cinzel.ttf") else null
	var sf: Font = preload("res://ui/type.gd").body()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_reader = PanelContainer.new()
	_reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	_reader.add_theme_stylebox_override("panel", sb)
	_reader.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_reader.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reader.offset_left = -440
	_reader.offset_right = 440
	_reader.offset_bottom = -232
	_reader.offset_top = -232
	root.add_child(_reader)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader.add_child(col)
	_meta = _label(col, 15, QUIET, title_font)
	_title = _label(col, 30, INK, title_font)
	var rule := ColorRect.new()
	rule.color = Color(EDGE.r, EDGE.g, EDGE.b, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_body = _label(col, 25, PAPER, sf)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(820, 0)
	_body.add_theme_constant_override("line_spacing", 6)
	_foot = _label(col, 15, QUIET, sf)
	_reader.visible = false
	# banner (top centre, under the region banner's line)
	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 150
	_banner.offset_left = -400
	_banner.offset_right = 400
	root.add_child(_banner)
	_b_top = _label(_banner, 16, COLD, title_font)
	_b_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_b_name = _label(_banner, 32, INK, title_font)
	_b_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	Events.player_hurt.connect(func(_a: float, _f: Vector3) -> void: close())


func _label(parent: Node, size: int, c: Color, font: Font) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	if font:
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l


func show_page(id: String, src: Node3D, fresh: bool) -> void:
	if _id == id and _reader.visible and not fresh:
		close()
		return
	var e := Pages.entry(id)
	if e.is_empty():
		return
	_id = id
	_src = src
	_meta.text = String(e.get("kind", "inscription")).to_upper() + ("    ·    NEW" if fresh else "")
	_title.text = String(e.title)
	_body.text = String(e.text)
	_foot.text = "[%s] read again to close" % Interactable.prompt_key()
	_reader.visible = true
	if _tw:
		_tw.kill()
	_reader.modulate.a = 0.0
	_tw = create_tween()
	_tw.tween_property(_reader, "modulate:a", 1.0, 0.35)


func close() -> void:
	if not _reader.visible:
		return
	_id = ""
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_reader, "modulate:a", 0.0, 0.25)
	_tw.tween_callback(func() -> void: _reader.visible = false)


func reading_id() -> String:
	return _id if _reader.visible else ""


## A secret-place banner: a discovery-class line in the text director's banner lane (priority 2, one per
## 90 s; past that limit a quiet corner line, the Journal has it anyway). No director: it draws now.
func banner(top: String, name_text: String) -> void:
	var td := TextDirector.of(self)
	if td == null:
		_show_banner(top, name_text)
		return
	while _bq.size() >= 3:
		var gone: Array = _bq.pop_front()
		td.quiet(String(gone[1]))
	_bq.append([top, name_text])
	_pump_banners()


func _pump_banners() -> void:
	var td := TextDirector.of(self)
	if td == null:
		for b in _bq:
			_show_banner(String(b[0]), String(b[1]))
		_bq.clear()
		return
	while not _bq.is_empty() and td.can_begin(&"discovery"):
		var b: Array = _bq.pop_front()
		if not td.discovery_ok():
			td.quiet(String(b[1]))
			continue
		td.begin(&"discovery", 5.6)
		_show_banner(String(b[0]), String(b[1]))
		return


func _show_banner(top: String, name_text: String) -> void:
	_b_top.text = top
	_b_name.text = name_text
	if _b_tw:
		_b_tw.kill()
	_b_tw = create_tween()
	_b_tw.tween_property(_banner, "modulate:a", 1.0, 0.8)
	_b_tw.tween_interval(3.2)
	_b_tw.tween_property(_banner, "modulate:a", 0.0, 1.4)


func _process(_d: float) -> void:
	if not _bq.is_empty():
		_pump_banners()
	if not _reader.visible or _src == null:
		return
	if not is_instance_valid(_src):
		close()
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p and p.global_position.distance_to(_src.global_position) > CLOSE_DIST:
		close()

class_name Satchel
extends CanvasLayer
## The inventory. [Tab] / [I] / d-pad up opens it (the world pauses, the mouse is freed); the
## same key, Esc or the close button shuts it. Left: the slots, grouped Relics / Trophies /
## Materials, each drawn as a small emblem with its count. Right: the selected item's name,
## kind and lore. Below the HUD, a quiet "+1 Grave Ash" line confirms every pickup.
## r33 loot: every slot is framed in its item's quality colour (core/items/loot_db.gd), the name
## takes it too, and the lore reads as gold italic flavour under what the item does.

const UiSound := preload("res://ui/ui_sound.gd")
const SLOT := 92.0
const GROUPS := [["relic", "Relics"], ["trophy", "Trophies"], ["core", "Staff Cores"], ["charm", "Charms"], ["material", "Materials"]]
const _PROG := preload("res://core/life/progression/icons.gd")   # progression: charm icons, worn notes
const INK := Color(0.9, 0.84, 1.0)
const QUIET := Color(0.62, 0.56, 0.72)
const EDGE := Color(0.42, 0.32, 0.58)
const _LOOT := preload("res://core/items/loot_db.gd")       # r33 loot: item quality
const _GOLD := Color(0.95, 0.8, 0.5)

var _root: Control
var _grid_box: VBoxContainer
var _name: Label
var _kind: Label
var _text: Label
var _empty: Label
var _slots: Array[Slot] = []
var _sel := 0
var _was_captured := false
var _font: Font
var _feed: VBoxContainer
var _attune := false
var _hint: Label
var _flav: RichTextLabel


class Slot extends Control:
	var id := ""
	var count := 0
	var selected := false
	var owner_menu: Satchel

	func _init() -> void:
		custom_minimum_size = Vector2(SLOT, SLOT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if selected:
				owner_menu.try_attune()
			owner_menu.select_id(id)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			owner_menu.select_id(id)

	func _draw() -> void:
		var d := ItemDB.def(id)
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_rect(r, Color(0.06, 0.03, 0.09, 0.92), true)
		var qc := _LOOT.quality_color(_LOOT.item_quality(id))
		draw_rect(r, qc.lightened(0.35) if selected else qc.darkened(0.15), false, 3.0 if selected else 2.0)
		var c := size * 0.5
		var t: Color = d.tint
		match String(d.shape):
			"skull":
				draw_circle(c + Vector2(0, -6), 20, t)
				draw_rect(Rect2(c + Vector2(-12, 8), Vector2(24, 12)), t)
				draw_circle(c + Vector2(-8, -8), 5, Color(0.05, 0.03, 0.06))
				draw_circle(c + Vector2(8, -8), 5, Color(0.05, 0.03, 0.06))
			"heart":
				draw_circle(c + Vector2(-9, -6), 12, t)
				draw_circle(c + Vector2(9, -6), 12, t)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -2), c + Vector2(20, -2), c + Vector2(0, 22)]), t)
				for k in 5:
					var a := TAU * float(k) / 5.0
					draw_line(c + Vector2(cos(a), sin(a)) * 16, c + Vector2(cos(a), sin(a)) * 26, Color(0.35, 0.08, 0.1), 2.0)
			"crown":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 14), c + Vector2(22, 14), c + Vector2(22, -10), c + Vector2(11, 2), c + Vector2(0, -18), c + Vector2(-11, 2), c + Vector2(-22, -10)]), t)
				for x: float in [-12.0, 0.0, 12.0]:
					draw_circle(c + Vector2(x, 9), 3, Color(0.5, 0.1, 0.15))
			"shard":   # relic fragment (secrets): three broken slivers
				for k in 3:
					var o := c + Vector2(-12 + 12 * k, 4 - 6 * (k % 2))
					draw_colored_polygon(PackedVector2Array([o + Vector2(0, -18), o + Vector2(6, -2), o + Vector2(2, 14), o + Vector2(-5, 4)]), t.darkened(0.12 * k))
					draw_line(o + Vector2(0, -18), o + Vector2(2, 14), t.lightened(0.4), 1.0)
			"sigil":
				draw_arc(c, 22, 0, TAU, 32, t, 2.5)
				draw_arc(c, 14, 0, TAU, 24, t, 1.5)
				for k in 6:
					var a := TAU * float(k) / 6.0
					draw_line(c + Vector2(cos(a), sin(a)) * 14, c + Vector2(cos(a), sin(a)) * 22, t, 2.0)
				draw_circle(c, 4, t)
			_:
				if not _PROG.item(self, id, c, 24.0):   # progression: charms draw their own icon
					draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 14), c + Vector2(-12, -2), c + Vector2(0, -12), c + Vector2(12, -2), c + Vector2(22, 14)]), t)
					draw_circle(c + Vector2(-6, 2), 2.5, t.lightened(0.3))
					draw_circle(c + Vector2(7, 6), 2, t.lightened(0.3))
		if String(d.kind) == "material":
			var f := ThemeDB.fallback_font
			draw_string(f, Vector2(8, size.y - 11), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 18, 15, INK)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/Cinzel.ttf")
	_build()
	_root.visible = false
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.position = Vector2(-360, -220)
	_feed.custom_minimum_size = Vector2(320, 0)
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	Events.item_gained.connect(_on_gained)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.06, 0.96)
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.position = Vector2(-500, -300)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("SATCHEL", 30, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	# lore hook: the Journal (ui/codex.gd, group "codex") opens from here too
	var journal := Button.new()
	journal.text = "Journal  [J]"
	journal.flat = true
	journal.add_theme_color_override("font_color", QUIET)
	journal.pressed.connect(func() -> void:
		var cx := get_tree().get_first_node_in_group("codex")
		if cx:
			close_menu()
			cx.call("open_book"))
	head.add_child(journal)
	# r33 loot: the gear panel ([G])
	var gear_b := Button.new()
	gear_b.text = "Gear  [G]"
	gear_b.flat = true
	gear_b.add_theme_color_override("font_color", QUIET)
	gear_b.pressed.connect(func() -> void:
		var gp := get_tree().get_first_node_in_group("gear_panel")
		if gp:
			close_menu()
			gp.call("open_menu"))
	head.add_child(gear_b)
	# progression hook: the Kindling ([K]; ash is spent at a lit fire)
	var kindling := Button.new()
	kindling.text = "Kindling  [K]"
	kindling.flat = true
	kindling.add_theme_color_override("font_color", QUIET)
	kindling.pressed.connect(func() -> void:
		var g := get_tree().get_first_node_in_group("growth")
		if g:
			close_menu()
			g.call("open_menu"))
	head.add_child(kindling)
	var close := Button.new()
	close.text = "Close  [Tab]"
	close.flat = true
	close.add_theme_color_override("font_color", QUIET)
	close.pressed.connect(close_menu)
	head.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override("separation", 12)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_box)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	_name = _label("", 26, INK)
	info.add_child(_name)
	_kind = _label("", 15, QUIET)
	info.add_child(_kind)
	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size = Vector2(0, 1)
	info.add_child(rule)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(340, 0)
	_text.add_theme_font_size_override("font_size", 17)
	_text.add_theme_color_override("font_color", Color(0.82, 0.78, 0.88))
	info.add_child(_text)
	_flav = RichTextLabel.new()
	_flav.bbcode_enabled = true
	_flav.fit_content = true
	_flav.scroll_active = false
	_flav.custom_minimum_size = Vector2(340, 0)
	_flav.add_theme_font_size_override("italics_font_size", 16)
	_flav.add_theme_font_size_override("normal_font_size", 16)
	info.add_child(_flav)
	_hint = _label("", 16, Color(1.0, 0.72, 0.42))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(340, 0)
	info.add_child(_hint)
	_empty = _label("Empty. Put to rest what hunts you; the great ones leave more than ash.", 17, QUIET)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid_box.add_child(_empty)


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _rebuild() -> void:
	for c in _grid_box.get_children():
		if c != _empty:
			c.queue_free()
	_slots.clear()
	var any := false
	for g: Array in GROUPS:
		var ids: Array[String] = []
		for id: String in ItemDB.ORDER:
			if String(ItemDB.def(id).kind) == g[0] and Travel.count(id) > 0:
				ids.append(id)
		for id in Travel.items:
			if not ItemDB.ORDER.has(id) and String(ItemDB.def(id).kind) == g[0] and Travel.count(id) > 0:
				ids.append(String(id))
		if ids.is_empty():
			continue
		any = true
		_grid_box.add_child(_label(String(g[1]).to_upper(), 15, QUIET))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_grid_box.add_child(grid)
		for id in ids:
			var s := Slot.new()
			s.id = id
			s.count = Travel.count(id)
			s.owner_menu = self
			grid.add_child(s)
			_slots.append(s)
	_empty.visible = not any
	_sel = clampi(_sel, 0, maxi(_slots.size() - 1, 0))
	_show()


func select_id(id: String) -> void:
	if not _slots.is_empty() and _slots[_sel].id != id:
		UiSound.play(self, "move")
	for i in _slots.size():
		if _slots[i].id == id:
			_sel = i
	_show()


func _show() -> void:
	for i in _slots.size():
		_slots[i].selected = i == _sel
		_slots[i].queue_redraw()
	if _slots.is_empty():
		_name.text = ""
		_kind.text = ""
		_text.text = ""
		_flav.text = ""
		return
	var id := _slots[_sel].id
	var d := ItemDB.def(id)
	_name.text = String(d.name)
	var q := _LOOT.item_quality(id)
	_name.add_theme_color_override("font_color", _LOOT.quality_color(q).lightened(0.1))
	var kind := _LOOT.quality_name(q) + "  ·  " + String(d.kind).capitalize()
	var sp := _LOOT.sell_price_item(id)
	if sp > 0:
		kind += "  ·  sells for %d ash" % sp
	var desc := String(d.get("desc", ""))
	_flav.text = ("[i][color=#%s]\"%s\"[/color][/i]" % [_GOLD.to_html(false), desc.replace("[", "[lb]")]) if desc != "" else ""
	if String(d.kind) == "material":
		kind += "  ·  %d carried" % Travel.count(id)
	_kind.text = kind.to_upper()
	var txt := String(d.text) + _PROG.note(id)   # progression: a charm says whether it is worn
	var rid := String(d.get("relic", ""))
	_hint.text = ""
	if rid != "" and Travel.relics.has(rid):
		txt += "\n\nAttuned: %s." % String(Travel.relics[rid]).capitalize()
		if _attune:
			var opts: Array = Reliquary.VARIANTS.get(rid, [])
			var cur: StringName = Travel.relics[rid]
			var nxt: StringName = opts[(opts.find(cur) + 1) % opts.size()] if not opts.is_empty() else cur
			_hint.text = "[%s] or click: attune to %s" % [Interactable.prompt_key(), String(nxt).capitalize()]
	elif _attune and rid == "":
		_hint.text = "Only relics can be attuned."
	_text.text = txt


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _root.visible:
			close_menu()
		elif not get_tree().paused:
			open_menu()
		get_viewport().set_input_as_handled()
		return
	if not _root.visible:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		step = 5
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		step = -5
	if _attune and event.is_action_pressed("interact"):
		try_attune()
		get_viewport().set_input_as_handled()
		return
	if step != 0 and not _slots.is_empty():
		var was := _sel
		_sel = clampi(_sel + step, 0, _slots.size() - 1)
		if _sel != was:
			UiSound.play(self, "move")
		_show()
		get_viewport().set_input_as_handled()


func try_attune() -> void:
	if not _attune or _slots.is_empty():
		return
	var rid := String(ItemDB.def(_slots[_sel].id).get("relic", ""))
	if rid != "" and Travel.relics.has(rid):
		Reliquary.attune(rid)
		UiSound.play(self, "confirm")
		_show()


func open_menu(attune := false) -> void:
	_attune = attune
	_rebuild()
	var g := get_tree().get_first_node_in_group("growth") if attune else null
	if g:   # progression: a kindled fire opens the Kindling; relics are attuned on its Relics page
		g.call("open_menu", true, "relics")
		return
	_root.visible = true
	UiSound.play(self, "tab")
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func close_menu() -> void:
	if _root.visible:
		UiSound.play(self, "back")
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _root.visible


func _on_gained(id: String, amount: int, total: int) -> void:
	if amount <= 0:                       # r33 loot: spending (a sale, a trade) is not a pickup
		if _root.visible:
			_rebuild()
		return
	var d := ItemDB.def(id)
	var line := _label("+%d  %s" % [amount, d.name] if String(d.kind) == "material" else "%s added to your satchel" % d.name, 18, (d.tint as Color).lightened(0.25))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	line.add_theme_constant_override("shadow_offset_x", 2)
	line.add_theme_constant_override("shadow_offset_y", 2)
	# ENS art pass: a pickup toast on a dark plate with an edge in the item's own colour, popping in
	# from the right, so a gain reads at a glance over a bright sky
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	plate.border_color = (d.tint as Color).lightened(0.2)
	plate.border_width_right = 3
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 14
	plate.content_margin_right = 12
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	line.add_theme_stylebox_override("normal", plate)
	line.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.set_meta(&"item", id)
	_feed.add_child(line)
	if String(d.kind) == "material":
		# merge a burst of ash pickups into the newest line (matched by id: the old text test never
		# matched once the running total was appended)
		for c in _feed.get_children():
			if c != line and c is Label and String(c.get_meta(&"item", "")) == id and not c.is_queued_for_deletion():
				c.queue_free()
		line.text = "+%d  %s   (%d)" % [amount, d.name, total]
	line.modulate.a = 0.0
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(line, "modulate:a", 0.0, 0.8)
	tw.tween_callback(line.queue_free)
	if _root.visible:
		_rebuild()

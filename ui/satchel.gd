class_name Satchel
extends CanvasLayer
## The inventory. [Tab] / [I] / d-pad up opens it (the world pauses, the mouse is freed); the
## same key, Esc or the close button shuts it. Left: the slots, grouped Relics / Trophies /
## Materials, each drawn as a small emblem with its count. Right: the selected item's name,
## kind and lore. Below the HUD, a quiet "+1 Grave Ash" line confirms every pickup.
## r33 loot: every slot is framed in its item's quality colour (core/items/loot_db.gd), the name
## takes it too, and the lore reads as gold italic flavour under what the item does.

const UiSound := preload("res://ui/ui_sound.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const SLOT := 96.0
const COLS := 8
const MIN_CELLS := 16                 ## every group shows at least this many sockets, the empty ones too
const GROUPS := [["relic", "Relics"], ["trophy", "Trophies"], ["core", "Staff Cores"], ["charm", "Charms"], ["material", "Materials"]]
const _PROG := preload("res://core/life/progression/icons.gd")   # progression: charm icons, worn notes
const Med := preload("res://ui/medieval_style.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const Card := preload("res://ui/item_card.gd")
const UIType := preload("res://ui/type.gd")
const PageGrid := preload("res://ui/page_grid.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const EDGE := Med.BRONZE
const _LOOT := preload("res://core/items/loot_db.gd")       # r33 loot: item quality
const _GOLD := Med.GILT

var _root: Control
var hosted := false                 ## r35: a page of the character screen (it owns keys and pause)
var only_groups: Array = []         ## r35: show only these GROUPS kinds (the Pack page: trophies, materials)
var _links: Array[Control] = []
var _title_lbl: Label     ## the header's Journal / Gear / Kindling / Close links
var _grid_box: VBoxContainer
var _card: PanelContainer           ## the selected item's card (ui/item_card.gd)
var _empty: Label
var _slots: Array[Slot] = []
var _sel := 0
var _was_captured := false
var _font: Font
var _feed: VBoxContainer
var _attune := false
var _count: Label


## A socket with nothing in it: the same rim as a full one, dimmer, so a group reads as a shelf with room left.
class Hollow extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(SLOT, SLOT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(Med.slot(Color(0.62, 0.58, 0.55)), Rect2(Vector2.ZERO, size))


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
		var qc := _LOOT.quality_color(_LOOT.item_quality(id))
		draw_style_box(Med.slot(qc.lightened(0.45) if selected else qc), Rect2(Vector2.ZERO, size))
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(Med.GILT, 0.12))
			draw_rect(Rect2(Vector2.ZERO, size).grow(1), Color(1.0, 0.92, 0.62), false, 2.5)
			draw_rect(Rect2(Vector2.ZERO, size).grow(4), Color(Med.GILT, 0.3), false, 2.0)
		var c := size * 0.5
		var t: Color = d.tint
		match "" if IconArt.art("item", id) != null else String(d.shape):   # painted art goes through _PROG.item below
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
			draw_string(f, Vector2(10, size.y - 9), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 18, 16, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(9, size.y - 10), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 18, 16, INK)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/Cinzel.ttf")
	_build()
	_root.visible = false
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_feed.offset_left = -700.0                 # left of the minimap, right-aligned, wide enough for a long item name
	_feed.offset_right = -250.0
	_feed.offset_top = -330.0
	_feed.offset_bottom = -44.0
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
	dim.color = Med.BACKDROP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var margin := PageGrid.cell(_root)           # the character screen's one grid cell: the window fills it
	var panel := PanelContainer.new()
	panel.theme = Med.theme()
	panel.add_theme_stylebox_override("panel", Med.panel("leather", 34))
	margin.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("SATCHEL", 32, INK)
	_title_lbl = title
	Med.gilt(title, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = _label("", 17, QUIET)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	# lore hook: the Journal (ui/codex.gd, group "codex") opens from here too
	var journal := _link("Journal  [J]", func() -> void:
		var cx := get_tree().get_first_node_in_group("codex")
		if cx:
			close_menu()
			cx.call("open_book"))
	head.add_child(journal)
	# r33 loot: the gear panel (action "gear"; its key read from the InputMap)
	var gear_b := _link("Gear  [%s]" % GearRuntime._gear_key(), func() -> void:
		var gp := get_tree().get_first_node_in_group("gear_panel")
		if gp:
			close_menu()
			gp.call("open_menu"))
	head.add_child(gear_b)
	# progression hook: the Kindling ([K]; ash is spent at a lit fire)
	var kindling := _link("Kindling  [K]", func() -> void:
		var g := get_tree().get_first_node_in_group("growth")
		if g:
			close_menu()
			g.call("open_menu"))
	head.add_child(kindling)
	head.add_child(_link("Close  [Tab]", close_menu))
	col.add_child(Med.rule())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var well := PanelContainer.new()             # the shelves: a recessed well holding the groups
	well.add_theme_stylebox_override("panel", Med.inset(14))
	body.add_child(well)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLS * SLOT + (COLS - 1) * 10.0 + 14.0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override("separation", 12)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_box)
	_card = Card.make(400.0, true)
	_card.custom_minimum_size.y = 430
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL      # the item's card takes what the shelves leave of the cell
	Card.fill(_card, "", 0, "")
	body.add_child(_card)
	_empty = _label("Empty. Put to rest what hunts you; the great ones leave more than ash.", 18, QUIET)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid_box.add_child(_empty)


## A header link: quiet text that lights on hover (these only show when the satchel stands alone).
func _link(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", UIType.body())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", QUIET)
	b.add_theme_color_override("font_hover_color", Med.GILT)
	b.pressed.connect(cb)
	_links.append(b)
	return b


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
	var kinds := 0
	for g: Array in GROUPS:
		if not only_groups.is_empty() and not only_groups.has(g[0]):
			continue
		var ids: Array[String] = []
		for id: String in ItemDB.ORDER:
			if String(ItemDB.def(id).kind) == g[0] and Travel.count(id) > 0:
				ids.append(id)
		for id in Travel.items:
			if not ItemDB.ORDER.has(id) and String(ItemDB.def(id).kind) == g[0] and Travel.count(id) > 0:
				ids.append(String(id))
		if ids.is_empty() and only_groups.is_empty():
			continue                              # the standalone satchel lists what you carry; the Pack page shows every shelf
		any = true
		kinds += ids.size()
		_grid_box.add_child(_label(String(g[1]).to_upper(), 18, Med.GILT_DEEP.lerp(Med.GILT, 0.35)))
		_grid_box.add_child(Med.rule(Color(Med.BRONZE, 0.8), false))
		var grid := GridContainer.new()
		grid.columns = COLS
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
		var cells := maxi(MIN_CELLS if not ids.is_empty() else COLS, int(ceil(float(ids.size()) / COLS)) * COLS)
		for _k in cells - ids.size():
			grid.add_child(Hollow.new())
	_empty.visible = not any
	_count.text = "%d kinds carried" % kinds if kinds != 1 else "1 kind carried"
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
		Card.fill(_card, "", 0, "[center]\n\n%s[/center]" % Tip._c(QUIET, "Nothing carried yet.\nWhat you pick up is laid out here."))
		return
	var id := _slots[_sel].id
	var d := ItemDB.def(id)
	var q := _LOOT.item_quality(id)
	var extra := PackedStringArray()
	var note := _PROG.note(id).strip_edges()    # progression: a charm says whether it is worn
	if note != "":
		extra.append(Tip._c(INK, note))
	var rid := String(d.get("relic", ""))
	if rid != "" and Travel.relics.has(rid):
		extra.append(Tip._c(INK, "Attuned: %s." % String(Travel.relics[rid]).capitalize()))
		if _attune:
			var opts: Array = Reliquary.VARIANTS.get(rid, [])
			var cur: StringName = Travel.relics[rid]
			var nxt: StringName = opts[(opts.find(cur) + 1) % opts.size()] if not opts.is_empty() else cur
			extra.append(Tip._c(_GOLD, "[%s] or click: attune to %s" % [Interactable.prompt_key(), String(nxt).capitalize()]))
	elif _attune and rid == "":
		extra.append(Tip._c(_GOLD, "Only relics can be attuned."))
	var bb := Tip.item(id, Travel.count(id), {"head": false, "blocks": true})
	if not extra.is_empty():
		bb += "\n" + Card.DIV + "\n" + "\n".join(extra)
	Card.fill(_card, String(d.name), q, bb)


func _input(event: InputEvent) -> void:
	if _cs() != null and (hosted or not _root.visible):
		if not _root.visible:
			return                              # the character screen opens and closes it
		if event.is_action_pressed("inventory") or event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse"):
			return
	elif event.is_action_pressed("inventory"):
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
		step = COLS
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		step = -COLS
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
	_attune = attune                    # kept even when routed: try_attune() and select_id() read these
	_rebuild()
	if not hosted and _cs() != null:
		_cs().call("open_at", "wanderer" if attune else "pack", "relics" if attune else "")
		return
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
	if hosted:
		_root.visible = false                # a page of the character screen: it keeps the pause and the mouse
		var cs := get_tree().get_first_node_in_group(&"character_screen")
		if cs:
			cs.release(self)                  # closed directly: the screen closes too and gives the night back
		return
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
	plate.bg_color = Color(0.05, 0.03, 0.015, 0.78)
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


## r35: hosted on the character screen, the header's links to the other screens go (its tabs do that).
func set_hosted(on: bool) -> void:
	if _title_lbl:
		_title_lbl.text = "PACK" if on else "SATCHEL"
	for l in _links:
		if is_instance_valid(l):
			l.visible = not on


## r35: the one character screen (ui/character_screen.gd), when the night has one.
func _cs() -> Node:
	return get_tree().get_first_node_in_group(&"character_screen") if is_inside_tree() else null

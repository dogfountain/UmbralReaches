extends CanvasLayer
## The loot window (r33, after WoW's): opened on a loot bag (core/items/loot_bag.gd) with [E]. One
## row per thing inside: an icon framed in its quality colour, the name in that colour, the count.
## Hover (or move with W/S) shows the full tooltip beside it (ui/item_tooltip.gd), gear compared
## with what you wear. Click a row or press its number to take it; [E] / Take all takes the lot;
## [Esc] closes. The world does NOT pause (as in WoW): walk away from the bag and it closes.
## One per Realm, added by progression.gd; group "loot_window". No class_name.

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const LootBag := preload("res://core/items/loot_bag.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const Icons := preload("res://core/life/progression/icons.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const UIType := preload("res://ui/type.gd")

const Med := preload("res://ui/medieval_style.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const LEAVE_R := 5.0

var bag: Node3D
var sel := 0
var _root: Control
var _panel: PanelContainer
var _title: Label
var _rows_box: VBoxContainer
var _tip: PanelContainer
var _hint: Label
var _rows: Array[Control] = []
var _was_captured := false
var _paused_it := false
var _font: Font


func _ready() -> void:
	layer = 59
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("loot_window")
	_font = UIType.body()
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.theme = Med.theme()
	_panel.add_theme_stylebox_override("panel", Med.panel("leather", 30))
	_panel.position = Vector2(140, 220)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_title = Label.new()
	Med.gilt(_title, 22)
	col.add_child(_title)
	col.add_child(Med.rule())
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	col.add_child(_rows_box)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)
	btns.add_child(_button("Take all [%s]" % Interactable.prompt_key(), take_all))
	btns.add_child(_button("Close [Esc]", close))
	_hint = Label.new()
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", QUIET)
	_hint.text = "Click or press 1-9 to take one."
	col.add_child(_hint)
	_tip = Tip.panel(_font, 340.0)
	_tip.visible = false
	_root.add_child(_tip)


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 16)
	Med.style_button(b, 16, 12, 5)
	b.pressed.connect(cb)
	return b


# --- open / close -------------------------------------------------------------------------------

func is_open() -> bool:
	return _root.visible


func open_bag(b: Node3D) -> void:
	if b == null or not is_instance_valid(b):
		return
	bag = b
	sel = 0
	_title.text = String(b.get("title")).capitalize()
	_rebuild()
	if not _root.visible:
		_root.visible = true
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_paused_it = not get_tree().paused       # the bag pauses the night, and gives it back only if it was the one to
		get_tree().paused = true
		Events.interact_hint.emit("")
		UiSound.play(self, "tab")


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	_tip.visible = false
	bag = null
	UiSound.play(self, "back")
	if _paused_it:
		get_tree().paused = false
		_paused_it = false
	if _was_captured and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _entries() -> Array:
	if bag == null or not is_instance_valid(bag):
		return []
	return bag.get("entries")


func _rebuild() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var es := _entries()
	for i in es.size():
		var e: Dictionary = es[i]
		var q := LootBag.entry_quality(e)
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(340, 50)
		row.mouse_entered.connect(func() -> void:
			sel = i
			_mark())
		row.pressed.connect(func() -> void: take(i))
		var ic := Control.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(4, 3)
		ic.size = Vector2(44, 44)
		ic.draw.connect(func() -> void: _draw_icon(ic, e, q))
		row.add_child(ic)
		var nm := Label.new()
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.add_theme_font_override("font", _font)
		nm.add_theme_font_size_override("font_size", 17)
		nm.add_theme_color_override("font_color", LootDB.quality_color(q).lightened(0.1))
		nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		nm.position = Vector2(58, 4)
		nm.size = Vector2(270, 24)
		nm.clip_text = true
		nm.text = LootBag.entry_name(e)
		row.add_child(nm)
		var sub := Label.new()
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", QUIET)
		sub.position = Vector2(58, 27)
		sub.text = "%d  ·  %s" % [i + 1, _sub(e, q)]
		row.add_child(sub)
		_rows_box.add_child(row)
		_rows.append(row)
	_mark()


func _sub(e: Dictionary, q: int) -> String:
	if String(e.get("kind", "")) == "gear":
		var p: Dictionary = e.get("piece", {})
		return "%s %s  ·  ilvl %d" % [LootDB.quality_name(q), String(GearDB.SLOT_NAMES.get(String(p.get("slot", "")), "")), GearDB.item_level(p)]
	return "%s %s" % [LootDB.quality_name(q), String(ItemDB.def(String(e.get("id", ""))).get("kind", "")).capitalize()]


func _draw_icon(ci: Control, e: Dictionary, q: int) -> void:
	var col := LootDB.quality_color(q)
	ci.draw_style_box(Med.slot(col), Rect2(Vector2.ZERO, ci.size))
	var c := ci.size * 0.5
	if String(e.get("kind", "")) == "gear":
		var p: Dictionary = e.get("piece", {})
		Icons.draw(ci, String(GearDB.SLOT_GLYPH.get(String(p.get("slot", "")), "prism")), c, 14.0, col.lightened(0.2))
	else:
		if not Icons.item(ci, String(e.get("id", "")), c, 14.0):
			ci.draw_circle(c, 9.0, col)


func _mark() -> void:
	var es := _entries()
	for i in _rows.size():
		var on := i == sel
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.36, 0.22, 0.09, 0.55) if on else Color(0, 0, 0, 0)
		s.border_color = Color(Med.GILT, 0.6) if on else Color(0, 0, 0, 0)
		s.set_border_width_all(1)
		_rows[i].add_theme_stylebox_override("normal", s)
		_rows[i].add_theme_stylebox_override("hover", s)
	if sel < 0 or sel >= es.size():
		_tip.visible = false
		return
	var e: Dictionary = es[sel]
	var q := LootBag.entry_quality(e)
	if String(e.get("kind", "")) == "gear":
		var p: Dictionary = e.get("piece", {})
		var st := GearStats.state()
		var cur: Dictionary = GearStats.worn(st).get(String(p.get("slot", "")), {})
		Tip.set_text(_tip, Tip.piece(p, cur, st), q)
	else:
		Tip.set_text(_tip, Tip.item(String(e.get("id", "")), int(e.get("n", 1))), q)
	_tip.visible = true
	_tip.reset_size()
	_tip.position = _panel.position + Vector2(_panel.size.x + 12, 0)


# --- taking -------------------------------------------------------------------------------------

func take(i: int) -> void:
	if bag == null or not is_instance_valid(bag):
		close()
		return
	var line := String(bag.call("take", i))
	if line != "":
		Events.toast.emit(line)
	UiSound.play(self, "confirm")
	_after()


func take_all() -> void:
	if bag == null or not is_instance_valid(bag):
		close()
		return
	var lines: PackedStringArray = bag.call("take_all")
	var gear_lines := PackedStringArray()
	for l in lines:
		if l != "" and not l.contains(" x"):
			gear_lines.append(l)                 # items announce themselves (the satchel's feed)
	if not gear_lines.is_empty():
		Events.toast.emit("  ".join(gear_lines))
	UiSound.play(self, "confirm")
	_after()


func _after() -> void:
	if bag == null or not is_instance_valid(bag) or bag.is_queued_for_deletion() or _entries().is_empty():
		close()
		return
	sel = clampi(sel, 0, _entries().size() - 1)
	_rebuild()


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	if bag == null or not is_instance_valid(bag) or bag.is_queued_for_deletion():
		close()
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p and p.global_position.distance_to(bag.global_position) > LEAVE_R:
		close()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		take_all()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		sel = mini(sel + 1, _entries().size() - 1)
		_mark()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		sel = maxi(sel - 1, 0)
		_mark()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var i := int(k - KEY_1)
			if i < _entries().size():
				take(i)
				get_viewport().set_input_as_handled()

extends CanvasLayer
## The Count (B): what the night has cost, on one leather page. Left: the foes put down by kind, the great ones, the
## wanderer's falls, fires kindled, lamps lit, places found, bells answered, camps made and the night it is. Right: the names
## the fire remembers (core/story/tally.gd gives every hollowed thing put down a pilgrim's name; the latest fourteen are
## listed). Pauses the night while it is read, like the map. After a camp the interact key opens it for six seconds
## (arm()), which is how a pad reads it. Added by the story director. Load by path (no class_name).

const Tally := preload("res://core/story/tally.gd")
const Days := preload("res://core/story/days.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")
const MenuGate := preload("res://ui/menu_gate.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.93, 0.87, 0.74)
const DIM := Color(0.74, 0.66, 0.52)
const GILT := Color(1.0, 0.78, 0.4)

var _open := false
var _was_captured := false
var _armed_until := 0
var _root: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _opened_ms := 0


static func arm_after_camp(tree: SceneTree) -> void:
	var p := tree.get_first_node_in_group(&"tally_panel") as CanvasLayer
	if p != null:
		p.set("_armed_until", Time.get_ticks_msec() + 6000)


func _ready() -> void:
	name = "TallyPanel"
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"tally_panel")
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.01, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Med.panel("leather", 40))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 560)
	panel.offset_left = -460.0
	panel.offset_right = 460.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := Label.new()
	title.text = "THE COUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Med.gilt(title, 34)
	col.add_child(title)
	var sub := _label("What the night has cost, and who the fire remembers", 17, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Med.rule())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 3)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 3)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)
	col.add_child(Med.rule())
	var foot := _label("[%s] or [Esc] close" % InputSetup.live_label("tally", false, "B"), 15, DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _head(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	Med.gilt(l, 20, GILT)
	box.add_child(l)


func _row(box: VBoxContainer, what: String, n: String) -> void:
	var h := HBoxContainer.new()
	var a := _label(what, 18, INK)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_label(n, 18, GILT))
	box.add_child(h)


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill() -> void:
	_clear(_left)
	_clear(_right)
	var d := Tally.data()
	_head(_left, "PUT DOWN  %d" % Tally.total())
	var rows := Tally.by_kind()
	for i in mini(rows.size(), 7):
		_row(_left, Tally.kind_name(String(rows[i][0])), str(int(rows[i][1])))
	if rows.is_empty():
		_row(_left, "Nothing yet", "")
	elif rows.size() > 7:
		var rest := 0
		for i in range(7, rows.size()):
			rest += int(rows[i][1])
		_row(_left, "Others", str(rest))
	_left.add_child(Control.new())
	_head(_left, "THE GREAT ONES")
	var great: Array = Travel.bosses_slain.keys()
	if great.is_empty():
		_row(_left, "None has fallen", "")
	for g in great:
		_row(_left, Tally.kind_name(String(g)), "fallen")
	_left.add_child(Control.new())
	_head(_right, "THE NIGHT")
	_row(_right, "Night", str(Days.current() + 1))
	_row(_right, "Camps made", str(int(d.get("camps", 0))))
	_row(_right, "Times hollowed", str(int(d.get("falls", 0))))
	_row(_right, "Places found", str(int(d.get("places", 0))))
	_row(_right, "Bells answered", "%d of %d" % [QuestBook.bells(), Chains.BELLS.size()])
	_row(_right, "Fires burning", str(_lit(Groups.BRAZIER)))
	_row(_right, "Lamps you lit", str(_lit(&"lamp")))
	_right.add_child(Control.new())
	_head(_right, "THE FIRE REMEMBERS")
	var names := Tally.latest(12)
	for n in names:
		_row(_right, String(n), "")
	if names.is_empty():
		_row(_right, "No one yet. The Bearers wait.", "")
	elif Tally.total() > names.size():
		_row(_right, "and %d more" % (Tally.total() - names.size()), "")


func _lit(group: StringName) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(group):
		if b is Brazier and (b as Brazier).lit:
			n += 1
		elif b is Lamp and (b as Lamp).lit:
			n += 1
	return n


func can_open() -> bool:
	var zone := get_tree().current_scene
	if zone == null or not zone.has_meta("realm_done") or get_tree().paused or MenuGate.blocked(self):
		return false
	return zone.get_node_or_null("LoadingScreen") == null and get_tree().get_first_node_in_group(Groups.PLAYER) != null


func open() -> void:
	if _open or not can_open():
		return
	_open = true
	_opened_ms = Time.get_ticks_msec()
	_armed_until = 0
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_fill()
	_root.visible = true
	UiSound.play(self, "tab")


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "back")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tally") and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		if Time.get_ticks_msec() < _armed_until and event.is_action_pressed("interact") and not event.is_echo():
			open()
			get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() - _opened_ms < 200:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

extends CanvasLayer
## r33 world: the Ember Road (WoW's flight paths, in our own fire). Every lit brazier is a stop: at
## the ember-post beside a lit fire (ember_post.gd) this menu lists the other fires, lit ones to
## choose and cold ones greyed; choosing one flies you there as an ember (fire_flight.gd) and the
## fire there remembers you (it becomes your checkpoint). Never mid-fight: a boss fight, or anything
## hunting you within FIGHT_R, closes the road (blocked_reason()).
## Opened with FireRoad.open(brazier) (static: it finds or makes the one menu under the scene).
## Pauses the world while open, like the Satchel. Load by path (no class_name).
##   Events.fire_travelled(from_fire, to_fire) when the flight lands (brazier node names).

const Flight := preload("res://core/world/fire_flight.gd")
const UIType := preload("res://ui/type.gd")
const FIGHT_R := 18.0                    ## Stamina.FIGHT_R: an awake foe this close and the road is shut
const INK := Color(0.93, 0.88, 0.8)
const QUIET := Color(0.6, 0.55, 0.62)
const EMBER := Color(1.0, 0.62, 0.3)
const COLD := Color(0.48, 0.46, 0.5)
const WARN := Color(1.0, 0.45, 0.38)

var from: Brazier
var _root: Control
var _list: VBoxContainer
var _title: Label
var _sub: Label
var _warn: Label
var _was_captured := false
var _first: Button
var _opened_ms := 0                      ## the key press that opened the menu must not also close it


## Open the road at `b` (a lit fire). Returns the menu.
static func open(b: Brazier) -> CanvasLayer:
	var tree := b.get_tree()
	var host := tree.current_scene if tree.current_scene else tree.root
	var m := host.get_node_or_null("FireRoad") as CanvasLayer
	if m == null:
		m = (load("res://core/world/fire_road.gd") as GDScript).new()
		m.name = "FireRoad"
		host.add_child(m)
	m.call("show_from", b)
	return m


## Every Brazier in the night (lit or cold), nearest first from `at`.
static func fires(tree: SceneTree, at: Vector3) -> Array[Brazier]:
	var out: Array[Brazier] = []
	for n in tree.get_nodes_in_group(Groups.BRAZIER):
		var b := n as Brazier
		if b != null and b.is_inside_tree() and not b.is_queued_for_deletion():
			out.append(b)
	out.sort_custom(func(a: Brazier, c: Brazier) -> bool:
		return a.global_position.distance_squared_to(at) < c.global_position.distance_squared_to(at))
	return out


## Why the road is shut right now ("" = open): a boss fight anywhere, a flight already under way,
## or a foe awake and close (the Stamina's rule).
static func blocked_reason(tree: SceneTree) -> String:
	if Player.boss_fight_active(tree):
		return "The fires will not carry you out of a warden's fight."
	if tree.get_first_node_in_group(Flight.GROUP) != null:
		return "You are already on the road."
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return "No one to carry."
	var at := p.global_position
	for node in tree.get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_inside_tree() or e.is_queued_for_deletion() or not e.is_alive() or e._state == Enemy.IDLE:
			continue
		if e.global_position.distance_squared_to(at) < FIGHT_R * FIGHT_R:
			return "Something hunts you. Break off the fight first."
	return ""


## Fly from `a` to `b` now (tests call this; the menu does too). Returns the flight, or null with
## the reason toasted.
static func travel(a: Brazier, b: Brazier) -> Node:
	if a == null or b == null or a == b or not b.lit:
		return null
	var tree := a.get_tree()
	var why := blocked_reason(tree)
	if why != "":
		Events.toast.emit(why)
		return null
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return null
	var f: Node = Flight.new()
	f.name = "FireFlight"
	(tree.current_scene if tree.current_scene else tree.root).add_child(f)
	f.call("start", p, a, b)
	return f


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.02, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.04, 0.96)
	sb.border_color = Color(0.46, 0.34, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = _label(col, "THE EMBER ROAD", 34, INK, UIType.title(), HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _label(col, "", 21, QUIET, UIType.body(), HORIZONTAL_ALIGNMENT_CENTER)
	var rule := ColorRect.new()
	rule.color = Color(0.46, 0.34, 0.26, 0.8)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_warn = _label(col, "", 21, WARN, UIType.body(), HORIZONTAL_ALIGNMENT_CENTER)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col.add_child(_list)
	var foot := _label(col, "Choose a lit fire. Cold fires wake the road when you kindle them.", 17, QUIET, UIType.body(), HORIZONTAL_ALIGNMENT_CENTER)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stay := _button(col, "Stay by this fire", true)
	stay.pressed.connect(close)
	_root.visible = false


func show_from(b: Brazier) -> void:
	from = b
	_opened_ms = Time.get_ticks_msec()
	_rebuild()
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if _first:
		_first.grab_focus.call_deferred()


func is_open() -> bool:
	return _root != null and _root.visible


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The rows: one per other fire, nearest first; lit ones go, cold ones are named and greyed.
func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_first = null
	_sub.text = "From %s" % from.display_name()
	var why := blocked_reason(get_tree())
	_warn.text = why
	_warn.visible = why != ""
	for b in fires(get_tree(), from.global_position):
		if b == from:
			continue
		var d := b.global_position.distance_to(from.global_position)
		var where := region_name(b)
		var txt := "%s   ·   %s   ·   %d m" % [b.display_name(), where, roundi(d)] if where != "" else "%s   ·   %d m" % [b.display_name(), roundi(d)]
		if not b.lit:
			txt += "   (cold)"
		var btn := _button(_list, txt, b.lit and why == "")
		if b.lit and why == "":
			btn.pressed.connect(_go.bind(b))
			if _first == null:
				_first = btn
	if _first == null:
		_warn.visible = true
		if why == "":
			_warn.text = "No other fire burns yet."
			_warn.add_theme_color_override("font_color", QUIET)
	else:
		_warn.add_theme_color_override("font_color", WARN)


## The place a fire stands in, by name (the summit's fire stands over the Ossuary's rect: its own).
static func region_name(b: Brazier) -> String:
	if String(b.name) == "SummitFire" or b.global_position.y > 20.0:
		return "Summit of Ascension"
	return String(RealmLayout.region_at(b.global_position.x, b.global_position.z).get("name", ""))


func _go(b: Brazier) -> void:
	var a := from
	close()
	travel(a, b)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or Time.get_ticks_msec() - _opened_ms < 200:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") \
			or event.is_action_pressed("inventory") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()


func _label(parent: Node, text: String, px: int, col: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not on
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	b.add_theme_font_override("font", UIType.body())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", EMBER)
	b.add_theme_color_override("font_focus_color", EMBER)
	b.add_theme_color_override("font_disabled_color", COLD)
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.09, 0.06, 0.06, 0.9) if st == "normal" else (Color(0.16, 0.09, 0.06, 0.95) if st in ["hover", "focus", "pressed"] else Color(0.06, 0.05, 0.06, 0.6))
		s.border_color = EMBER if st in ["hover", "focus"] else Color(0.3, 0.22, 0.18)
		s.set_border_width_all(1)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(st, s)
	parent.add_child(b)
	return b

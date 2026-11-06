extends CanvasLayer
## r35 (docs/critique/r35_full.md "Decisions, round two"): the one character screen. One key
## (inventory: Tab / I / d-pad up) opens four tabs, each with its own pages:
##   WANDERER  Gear · Charms · Relics · Staff        what you wear and carry into a fight
##   KINDLING  Embers · Spells · Loadout · Oaths · Paths · Hearth
##   PACK      trophies and materials
##   JOURNAL   Wenna's Journal · Stories · Writings · Places · Map · Relics · Tasks
## It replaces four separate screens (Satchel, Gear, the nine-tab Kindling and the Journal, plus the
## Tasks ledger) without rewriting them: each page is one of those panels, opened "hosted" (its own
## title links and tab strip hidden, the global keys left to this screen). This screen owns the pause,
## the mouse and the keys:
##   Tab / I / Esc / pad B   close            1 2 3 4 / pad LT RT   the four tabs
##   Q E / pad LB RB         the pages         O K J L               jump to Gear, Kindling, Journal, Tasks
## Anything that opens one of the old panels directly (a fire's Kindling, a test) is routed here by
## the panel itself (its open_menu asks for this screen when it is not hosted). Group
## "character_screen"; built by world/main.gd. Load by path (no class_name).

const UIType := preload("res://ui/type.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.9, 0.84, 1.0)
const DIM := Color(0.55, 0.5, 0.66)
const LILAC := Color(0.78, 0.66, 1.0)
const EMBER := Color(1.0, 0.62, 0.3)

## [id, title, [[page id, page title, panel, panel page], ...]]. panel: gear | growth | satchel | codex | tasks.
const TABS := [
	["wanderer", "Wanderer", [["gear", "Gear", "gear", ""], ["charms", "Charms", "growth", "charms"],
		["relics", "Relics", "growth", "relics"], ["staff", "Staff", "growth", "staff"]]],
	["kindling", "Kindling", [["embers", "Embers", "growth", "embers"], ["spells", "Spells", "growth", "spells"],
		["loadout", "Loadout", "growth", "loadout"], ["oaths", "Oaths", "growth", "oaths"],
		["paths", "Paths", "growth", "paths"], ["hearth", "Hearth", "growth", "hearth"]]],
	["pack", "Pack", [["pack", "Trophies and materials", "satchel", ""]]],
	["journal", "Journal", [["journal", "Wenna's Journal", "codex", "0"], ["stories", "Stories", "codex", "1"],
		["writings", "Writings", "codex", "2"], ["places", "Places", "codex", "3"], ["map", "Map", "codex", "4"],
		["lore", "Relic lore", "codex", "5"], ["tasks", "Tasks", "tasks", ""]]],
]
## the old keys still work: each opens (or, on its own page, closes) the screen at its page
const JUMPS := [["gear", "wanderer", "gear"], ["kindling", "kindling", ""], ["codex", "journal", ""], ["quest_log", "journal", "tasks"]]
const PACK_GROUPS := ["trophy", "material"]
const BAR_Y := 26.0

var _top := 0
var _sub: Array[int] = [0, 0, 0, 0]
var _open := false
var _was_captured := false
var _panel: Node = null                    ## the hosted panel showing now
var _root: Control
var _top_btns: Array[Button] = []
var _sub_row: HBoxContainer
var _trig := [false, false]                ## pad LT / RT held (edge detect on the axes)
var _hint: Label
var _backdrop: CanvasLayer                 ## a dim under every page (layer 58): pages without their own dim


func _ready() -> void:
	layer = 63                                 # over the hosted panels (59-62), under Settings (70)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"character_screen")
	_build()
	_root.visible = false
	_backdrop = CanvasLayer.new()
	_backdrop.name = "Backdrop"
	_backdrop.layer = 58                       # under the hosted panels (59-62), over the HUD
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(dim)
	_backdrop.visible = false
	add_child(_backdrop)


func is_open() -> bool:
	return _open


## Open at `top` (a tab id) and `page` (a page id; "" keeps that tab's last page).
## The close word names every key bound to inventory (Tab and I by default); Q and E are the physical page keys.
func _hint_refresh() -> void:
	if _hint == null:
		return
	var names := PackedStringArray()
	for ev in InputMap.action_get_events("inventory"):
		if InputSetup.slot_of(ev) == "key":
			names.append(InputSetup.event_name(ev))
	_hint.text = "[1-4] tabs   ·   [Q] [E] pages   ·   [%s] close" % " / ".join(names if not names.is_empty() else PackedStringArray(["Tab"]))


func open_at(top: String, page := "", from_fire := false) -> void:
	_hint_refresh()
	var ti := _tab_index(top)
	if ti < 0:
		return
	if page != "":
		var pi := _page_index(ti, page)
		if pi >= 0:
			_sub[ti] = pi
	if not _open:
		_open = true
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		_root.visible = true
		_backdrop.visible = true
		UiSound.play(self, "tab")
	_show(ti, _sub[ti], from_fire)


func close() -> void:
	if not _open:
		return
	_open = false
	_unhost()
	_root.visible = false
	_backdrop.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "back")


## The page showing now: [tab id, page id] (tests, hints).
func showing() -> Array:
	return [String(TABS[_top][0]), String(TABS[_top][2][_sub[_top]][0])] if _open else []


# --- pages ----------------------------------------------------------------------------------------

func _show(ti: int, pi: int, from_fire := false) -> void:
	_top = ti
	_sub[ti] = pi
	var page: Array = TABS[ti][2][pi]
	var want := _panel_node(String(page[2]))
	if want != _panel:
		_unhost()
	_panel = want
	if _panel != null:
		_panel.set("hosted", true)
		if _panel.has_method("set_hosted"):
			_panel.call("set_hosted", true)
		_open_page(String(page[2]), String(page[3]), from_fire)
		get_tree().paused = true                # a hosted panel's close (on a switch) may have unpaused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_bar()


func _open_page(kind: String, arg: String, from_fire: bool) -> void:
	match kind:
		"gear":
			if not bool(_panel.call("is_open")):
				_panel.call("open_menu")
		"growth":
			if bool(_panel.call("is_open")):
				_panel.call("show_tab_id", arg)
			else:
				_panel.call("open_menu", from_fire, arg)
		"satchel":
			_panel.set("only_groups", PACK_GROUPS)
			if bool(_panel.call("is_open")):
				_panel.call("_rebuild")
			else:
				_panel.call("open_menu")
		"codex":
			if bool(_panel.call("is_open")):
				_panel.call("show_tab", int(arg))
			else:
				_panel.call("open_book", int(arg))
		"tasks":
			if not bool(_panel.call("is_open")):
				_panel.call("open")


## Close the hosted panel without letting it hand the world back (this screen keeps it paused).
func _unhost() -> void:
	if _panel == null or not is_instance_valid(_panel):
		_panel = null
		return
	var p := _panel
	_panel = null
	if bool(p.call("is_open")):
		for m: String in ["close_menu", "close_book", "close"]:
			if p.has_method(m):
				p.call(m)
				break
	p.set("hosted", false)
	if p.has_method("set_hosted"):
		p.call("set_hosted", false)
	if p.get("only_groups") != null:
		p.set("only_groups", [])
	if _open:
		get_tree().paused = true


func _panel_node(kind: String) -> Node:
	var t := get_tree()
	match kind:
		"gear":
			return t.get_first_node_in_group(&"gear_panel")
		"growth":
			return t.get_first_node_in_group(&"growth")
		"satchel":
			var cs := t.current_scene
			var s: Node = cs.get_node_or_null("Satchel") if cs else null
			if s == null:
				for n in t.root.find_children("Satchel", "CanvasLayer", true, false):
					return n
			return s
		"codex":
			return t.get_first_node_in_group(&"codex")
		"tasks":
			return t.get_first_node_in_group(&"quest_log")
	return null


func _process(_delta: float) -> void:
	if not _open:
		return
	# someone else closed the page (its own close button, pad B in the ledger, a test): close it all
	if _panel == null or not is_instance_valid(_panel) or not bool(_panel.call("is_open")):
		_panel = null
		close()


# --- input ----------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _open:
		if get_tree().paused:
			return                               # a conversation, Settings or a shop has the screen
		if event.is_action_pressed("inventory") and not event.is_echo():
			open_at(String(TABS[_top][0]))
			get_viewport().set_input_as_handled()
			return
		for j: Array in JUMPS:
			if InputMap.has_action(j[0]) and event.is_action_pressed(j[0]) and not event.is_echo():
				open_at(j[1], j[2])
				get_viewport().set_input_as_handled()
				return
		return
	if event.is_echo():
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()
		return
	for j: Array in JUMPS:
		if InputMap.has_action(j[0]) and event.is_action_pressed(j[0]):
			var here := showing()
			if here[0] == j[1] and (j[2] == "" or here[1] == j[2]):
				close()
			else:
				open_at(j[1], j[2])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_4:
			_go_top(int(kc - KEY_1))
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_Q:
			_step_page(-1)
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_E:
			_step_page(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER:
			_step_page(-1 if b == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		var k := 0 if m.axis == JOY_AXIS_TRIGGER_LEFT else (1 if m.axis == JOY_AXIS_TRIGGER_RIGHT else -1)
		if k >= 0:
			var down := m.axis_value > 0.6
			if down and not _trig[k]:
				_go_top((_top + (-1 if k == 0 else 1) + TABS.size()) % TABS.size())
			_trig[k] = down
			get_viewport().set_input_as_handled()


func _go_top(i: int) -> void:
	if i < 0 or i >= TABS.size() or (i == _top and _open):
		return
	UiSound.play(self, "tab")
	_show(i, _sub[i])


func _step_page(d: int) -> void:
	var n: int = (TABS[_top][2] as Array).size()
	if n <= 1:
		return
	UiSound.play(self, "tab")
	_show(_top, (_sub[_top] + d + n) % n)


func _tab_index(id: String) -> int:
	for i in TABS.size():
		if TABS[i][0] == id:
			return i
	return -1


func _page_index(ti: int, id: String) -> int:
	var pages: Array = TABS[ti][2]
	for i in pages.size():
		if pages[i][0] == id:
			return i
	return -1


# --- the bar --------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var band := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.92)
	sb.border_color = Color(0.5, 0.4, 0.8, 0.55)
	sb.border_width_bottom = 2
	band.add_theme_stylebox_override("panel", sb)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = 0.0
	band.offset_bottom = BAR_Y + 108.0
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(band)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	col.offset_top = BAR_Y
	col.add_theme_constant_override("separation", 8)
	_root.add_child(col)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	for i in TABS.size():
		var b := _button("%d  %s" % [i + 1, String(TABS[i][1]).to_upper()], 22, Vector2(230, 44))
		var idx := i
		b.pressed.connect(func() -> void: _go_top(idx))
		top.add_child(b)
		_top_btns.append(b)
	_sub_row = HBoxContainer.new()
	_sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_row.add_theme_constant_override("separation", 6)
	col.add_child(_sub_row)
	var hint := Label.new()
	_hint = hint
	_hint_refresh()
	hint.add_theme_font_override("font", UIType.body())
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", DIM)
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -470.0
	hint.offset_right = -28.0
	hint.offset_top = BAR_Y + 12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(hint)


func _refresh_bar() -> void:
	for i in _top_btns.size():
		_top_btns[i].button_pressed = i == _top
	for c in _sub_row.get_children():
		c.queue_free()
	var pages: Array = TABS[_top][2]
	if pages.size() <= 1:
		return
	for i in pages.size():
		var b := _button(String(pages[i][1]).to_upper(), 15, Vector2(0, 32))
		b.button_pressed = i == _sub[_top]
		var idx := i
		b.pressed.connect(func() -> void:
			if idx != _sub[_top]:
				UiSound.play(self, "tab")
				_show(_top, idx))
		_sub_row.add_child(b)


func _button(text: String, pt: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UIType.title())
	b.add_theme_font_size_override("font_size", pt)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", LILAC)
	b.add_theme_color_override("font_hover_pressed_color", LILAC)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0.08, 0.05, 0.12, 0.7)
	off.set_corner_radius_all(3)
	off.set_content_margin_all(8)
	var on := off.duplicate() as StyleBoxFlat
	on.bg_color = Color(0.2, 0.14, 0.36, 0.95)
	on.border_color = LILAC
	on.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	return b

extends CanvasLayer
## The stable panel, opened at a hitching post's rail. Three pages (Q / E, or the tab buttons; the pad's d-pad and A use the
## buttons themselves):
##   Care     the horse's name, bond and spirit; Feed (an ash-bloom, +45 spirit), Groom (free once a night, +20 spirit and a little
##            bond); the tack to buy (shoes, barding, a saddle lantern, larger and deep saddlebags), each with its cost and why not.
##   Saddlebags  materials moved between the satchel and the bags (what is in the bags is safe: a fall into the dark does not
##            drop it). The capacity grows with the tack. The bags belong to the breed, and are opened at any post.
##   Courier  the parcels this post gives (core/world/mount/courier.gd), their gold times, your best, and the whole board.
## Pauses the night while it is open. Built hidden at the start (no first-use cost) and filled when opened. Load by path.

const HorseBond := preload("res://core/world/mount/horse_bond.gd")
const Horse := preload("res://core/world/mount/horse.gd")
const DB := preload("res://core/world/mount/horse_db.gd")
const Profile := preload("res://core/util/profile.gd")
const Med := preload("res://ui/medieval_style.gd")
const MenuGate := preload("res://ui/menu_gate.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.93, 0.87, 0.74)
const DIM := Color(0.74, 0.66, 0.52)
const GILT := Color(1.0, 0.78, 0.4)
const WARN := Color(1.0, 0.5, 0.4)
const PAGES := ["Care", "Saddlebags", "Courier"]
const MATERIALS := ["grave_ash", "ember_shard", "ash_bloom", "grave_iron", "relic_fragment"]

var _open := false
var _was_captured := false
var _breed := ""
var _page := 0
var _root: Control
var _title: Label
var _body: VBoxContainer
var _tabs: HBoxContainer
var _foot: Label
var _opened_ms := 0


func _ready() -> void:
	name = "HorsePanel"
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"horse_panel")
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.01, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Med.panel("leather", 36))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -470.0
	panel.offset_right = 470.0
	panel.offset_top = -340.0
	panel.offset_bottom = 340.0
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Med.gilt(_title, 30)
	col.add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_tabs)
	col.add_child(Med.rule())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 5)
	scroll.add_child(_body)
	col.add_child(Med.rule())
	_foot = _label("[Q] [E] page     [Esc] leave", 15, DIM)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_foot)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(parent: Node, text: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	Med.style_button(b, 17, 12, 5)
	if on:
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _owned() -> bool:
	return (Horse.state().owned as Array).has(_breed)


func open_for(breed: String) -> void:
	if _open or not DB.BREEDS.has(breed) or get_tree().paused or MenuGate.blocked(self):
		return
	_breed = breed
	_open = true
	_opened_ms = Time.get_ticks_msec()
	_page = 0
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


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill() -> void:
	_clear(_tabs)
	_clear(_body)
	var d: Dictionary = DB.BREEDS[_breed]
	_title.text = ("%s, the %s" % [HorseBond.name_of(_breed), String(d.name)]) if _owned() else String(d.name)
	for i in PAGES.size():
		var idx := i
		var t := _button(_tabs, String(PAGES[i]), i != _page, func() -> void:
			_page = idx
			_fill())
		t.focus_mode = Control.FOCUS_ALL
	var first: Control = null
	match _page:
		0:
			first = _care(d)
		1:
			first = _bags()
		2:
			first = _courier()
	if first != null:
		first.grab_focus.call_deferred()


func _care(d: Dictionary) -> Control:
	var first: Control = null
	if not _owned():
		_body.add_child(_label("%s\n\nKept at %s. %d grave ash buys it: stand beside it and take the reins. Its trot is %d m/s and its gallop %d, against your sprint of 7." % [String(d.line), String(d.where), int(d.cost), roundi(float(d.trot)), roundi(float(d.gallop))], 18, INK))
		return null
	var lv := HorseBond.level(_breed)
	var m := HorseBond.metres(_breed)
	var next := "" if lv >= 3 else "  Next: %d km." % roundi(float(HorseBond.LEVELS[lv + 1]) / 1000.0)
	_body.add_child(_label("Bond: %s, %.1f km ridden.%s" % [HorseBond.title(_breed), m / 1000.0, next], 19, INK))
	_body.add_child(_label("Spirit: %d of 100. A worn horse is 8%% slower; one in good spirit learns you half again as fast." % roundi(HorseBond.spirit(_breed)), 18, INK))
	var care := HBoxContainer.new()
	_body.add_child(care)
	var bloom := Travel.count("ash_bloom")
	first = _button(care, "Feed  (an ash-bloom; you carry %d)" % bloom, bloom >= HorseBond.FEED_COST and HorseBond.spirit(_breed) < 99.0, func() -> void:
		Travel.items["ash_bloom"] = Travel.count("ash_bloom") - HorseBond.FEED_COST
		HorseBond.set_spirit(_breed, HorseBond.spirit(_breed) + 45.0)
		Events.toast.emit("%s eats from your hand." % HorseBond.name_of(_breed))
		UiSound.play(self, "confirm")
		Travel.save_soon()
		_fill())
	_button(care, "Groom  (free, once a night)", not HorseBond.groomed_tonight(_breed), func() -> void:
		HorseBond.mark_groomed(_breed)
		HorseBond.set_spirit(_breed, HorseBond.spirit(_breed) + 20.0)
		HorseBond.add(_breed, 50.0)
		Events.toast.emit("%s leans into the brush." % HorseBond.name_of(_breed))
		UiSound.play(self, "confirm")
		Travel.save_soon()
		_fill())
	_body.add_child(Med.rule())
	_body.add_child(_label("TACK", 20, GILT))
	for id: String in HorseBond.TACK:
		var t: Dictionary = HorseBond.TACK[id]
		var why := HorseBond.why_not_tack(_breed, id)
		var cost := ", ".join((t.cost as Dictionary).keys().map(func(k: String) -> String: return "%d %s" % [int(t.cost[k]), String(ItemDB.def(k).name)]))
		var row := VBoxContainer.new()
		_body.add_child(row)
		var tid := id
		var b := _button(row, "%s  (%s)%s" % [String(t.name), cost, "   on" if HorseBond.has_tack(_breed, id) else ""], why == "", func() -> void:
			HorseBond.pay_tack(_breed, tid)
			Events.toast.emit("%s: %s." % [HorseBond.name_of(_breed), String(HorseBond.TACK[tid].name)])
			UiSound.play(self, "confirm")
			_fill())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(_label(String(t.text) + ("" if why == "" or why == "Already on." else "  " + why), 15, DIM if why == "" or why == "Already on." else WARN))
	return first


func _bags() -> Control:
	if not _owned():
		_body.add_child(_label("Buy the horse first. The saddlebags go with it.", 18, INK))
		return null
	var cap := HorseBond.bag_capacity(_breed)
	var total := HorseBond.bag_total(_breed)
	_body.add_child(_label("Saddlebags: %d of %d. What is in the bags is safe from the dark: a fall does not drop it." % [total, cap], 19, INK))
	var first: Control = null
	for id: String in MATERIALS:
		var item := id
		var def := ItemDB.def(item)
		var row := HBoxContainer.new()
		_body.add_child(row)
		var nm := _label("%s   carried %d   in the bags %d" % [String(def.name), Travel.count(item), int(HorseBond.bag(_breed).get(item, 0))], 18, INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		for step: Array in [["Put 1", 1], ["Put all", 9999], ["Take 1", -1], ["Take all", -9999]]:
			var n := int(step[1])
			var can := (Travel.count(item) > 0 and total < cap) if n > 0 else int(HorseBond.bag(_breed).get(item, 0)) > 0
			var b := _button(row, String(step[0]), can, func() -> void:
				if HorseBond.move_item(_breed, item, n) != 0:
					UiSound.play(self, "tab")
					Travel.save_soon()
				_fill())
			if first == null and can:
				first = b
	return first


func _courier() -> Control:
	Profile.ensure()
	var courier := get_tree().get_first_node_in_group(&"courier") as Courier
	var first: Control = null
	if courier == null:
		return null
	if Courier.active():
		var id := String(Travel.story.get("courier", {}).get("route", ""))
		_body.add_child(_label("You carry %s. Deliver it before you take another." % Courier.route_name(id), 18, WARN))
		first = _button(_body, "Give the parcel back", true, func() -> void:
			courier.abandon()
			_fill())
	_body.add_child(_label("PARCELS FROM THIS POST", 20, GILT))
	var mine := Courier.routes_from(_breed)
	if mine.is_empty():
		_body.add_child(_label("Nothing is sent from here. Try another post's rail.", 17, DIM))
	for id: String in mine:
		var rid := id
		var dist := Courier.distance(get_tree(), rid)
		var lim := Courier.limits(dist)
		var best := float(Profile.best.get(rid, 0.0))
		var row := VBoxContainer.new()
		_body.add_child(row)
		var b := _button(row, "%s   %d m   gold %s   best %s" % [Courier.route_name(rid), roundi(dist), Courier.fmt(lim[0]), Courier.fmt(best) if best > 0.0 else "none"], not Courier.active(), func() -> void:
			var why := courier.take(rid)
			if why != "":
				Events.toast.emit(why)
			else:
				close())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(_label("Carry " + String((Courier.ROUTES[rid] as Array)[3]) + ".", 15, DIM))
		if first == null and not Courier.active():
			first = b
	_body.add_child(Med.rule())
	_body.add_child(_label("THE BOARD: best times on every road", 20, GILT))
	for id: String in Courier.ROUTES:
		var best2 := float(Profile.best.get(id, 0.0))
		_body.add_child(_label("%s   %s" % [Courier.route_name(id), Courier.fmt(best2) if best2 > 0.0 else "no time yet"], 16, INK if best2 > 0.0 else DIM))
	return first


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if Time.get_ticks_msec() - _opened_ms < 200:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and (event.physical_keycode in [KEY_Q, KEY_E]):
		_page = (_page + (1 if event.physical_keycode == KEY_E else PAGES.size() - 1)) % PAGES.size()
		_fill()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and ((event as InputEventJoypadButton).button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]):
		_page = (_page + (1 if (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER else PAGES.size() - 1)) % PAGES.size()
		_fill()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

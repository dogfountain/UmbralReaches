extends RefCounted
## The Controls page of the settings menu (ui/settings_menu.gd): a row for each rebindable action with a keyboard / mouse button and a
## controller button (or trigger) to press, a line saying what was refused or done, and a reset. `host` is the menu (it lends its
## label and button styling); the menu asks `listen` while a button waits, hands it every input event then, and calls `refresh()` when
## it fills or resets. Load by path (no class_name).

const Med := preload("res://ui/medieval_style.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const DIM := Med.BONE_DIM
const QUIET := Med.BONE

var host: Variant                      ## the settings menu
var btns := {}                         ## "action|slot" -> Button
var msg: Label
var listen := ""                       ## the "action|slot" waiting for a key
var listen_ms := 0


## the bindings are editable. Click a button, press the new key / mouse button (or controller button for the
## pad column); Esc cancels. A key or button that already does something else is refused, with the message below.
## Saved in settings.cfg (Settings.bindings) and applied by InputSetup on boot.
func build(p: VBoxContainer) -> void:
	msg = host._label("Click a button (or press A on it), then press the new key, button or trigger. LB, RB and the d-pad stay the menus' own.", DIM, 16)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(msg)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	p.add_child(head)
	var h0: Label = host._label("", DIM, 16)
	h0.custom_minimum_size = Vector2(240, 0)
	head.add_child(h0)
	for t: String in ["Keyboard / mouse", "Controller"]:
		var hl: Label = host._label(t, DIM, 16)
		hl.custom_minimum_size = Vector2(190, 0)
		head.add_child(hl)
	for r: Array in InputSetup.REBINDABLE:
		var action: String = r[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var a: Label = host._label(String(r[0]), QUIET, 18)
		a.custom_minimum_size = Vector2(240, 0)
		row.add_child(a)
		for slot: String in ["key", "pad"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(190, 34)
			b.clip_text = true
			host._style_small(b, 16)
			var sl := slot
			b.pressed.connect(func() -> void: begin(action, sl))
			row.add_child(b)
			btns["%s|%s" % [action, slot]] = b
	var reset := Button.new()
	reset.text = "Reset Keys to Defaults"
	host._style_small(reset, 17)
	Med.style_button(reset, 17, 16, 5)
	reset.pressed.connect(func() -> void:
		InputSetup.reset_bindings()
		listen = ""
		refresh()
		msg.text = "Keys and buttons are back to their defaults.")
	p.add_child(reset)
	refresh()


func refresh() -> void:
	for key: String in btns:
		var parts := key.split("|")
		var b: Button = btns[key]
		if key == listen:
			b.text = "press a key..." if parts[1] == "key" else "press a button..."
			continue
		var ev: InputEvent = InputSetup.first_event(parts[0], parts[1])
		if ev != null:
			b.text = InputSetup.event_name(ev)
		else:
			b.text = pad_text([parts[0]], "") if parts[1] == "pad" else "-"


func begin(action: String, slot: String) -> void:
	listen = "%s|%s" % [action, slot]
	listen_ms = Time.get_ticks_msec()
	msg.text = "Press the new %s for %s. %s cancels." % ["key or mouse button" if slot == "key" else "controller button or trigger", InputSetup.label_of(action), "Esc" if slot == "key" else "Menu"]
	refresh()


## While a button waits for its binding every key, mouse button and pad button is its answer.
func input(event: InputEvent) -> void:
	var parts := listen.split("|")
	var action: String = parts[0]
	var slot: String = parts[1]
	var ev: InputEvent = null
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		listen = ""                             # Menu is fixed (it opens Settings): on a pad it is the way out of a rebind
		msg.text = "Cancelled."
		refresh()
		host.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			listen = ""
			msg.text = "Cancelled."
			refresh()
			host.get_viewport().set_input_as_handled()
			return
		if slot == "pad":
			msg.text = "That is a keyboard key. Press a controller button, or Menu to cancel."
			host.get_viewport().set_input_as_handled()
			return
		ev = event
	elif event is InputEventMouseButton and event.pressed and slot == "key" and Time.get_ticks_msec() - listen_ms > 250 \
			and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		ev = event
	elif event is InputEventJoypadButton and event.pressed and slot == "pad":
		ev = event
	elif event is InputEventJoypadMotion and slot == "pad" and InputSetup.is_trigger(event as InputEventJoypadMotion) and (event as InputEventJoypadMotion).axis_value > 0.7:
		ev = event                                  # a trigger is an answer too (the pad's LT and RT bind like buttons)
	if ev == null:
		return
	host.get_viewport().set_input_as_handled()
	var copy: InputEvent
	if ev is InputEventKey:
		copy = InputEventKey.new()
		var code := (ev as InputEventKey).physical_keycode
		(copy as InputEventKey).physical_keycode = code if code != KEY_NONE else (ev as InputEventKey).keycode
	elif ev is InputEventMouseButton:
		copy = InputEventMouseButton.new()
		(copy as InputEventMouseButton).button_index = (ev as InputEventMouseButton).button_index
	elif ev is InputEventJoypadMotion:
		copy = InputEventJoypadMotion.new()
		(copy as InputEventJoypadMotion).axis = (ev as InputEventJoypadMotion).axis
		(copy as InputEventJoypadMotion).axis_value = 1.0
	else:
		copy = InputEventJoypadButton.new()
		(copy as InputEventJoypadButton).button_index = (ev as InputEventJoypadButton).button_index
	var why: String = InputSetup.rebind(action, slot, copy)
	if why == "":
		msg.text = "%s is now %s." % [InputSetup.label_of(action), InputSetup.event_name(copy)]
		listen = ""
		UiSound.play(host, "confirm")
	else:
		msg.text = why + " Press another, or Esc."
		UiSound.play(host, "back")
	refresh()


func pad_text(actions: Array, fallback: String) -> String:
	if fallback != "":
		return fallback
	var parts := PackedStringArray()
	for act: String in actions:
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			if ev is InputEventJoypadButton:
				var bi := (ev as InputEventJoypadButton).button_index
				parts.append(InputSetup.event_name(ev))
				break
			if ev is InputEventJoypadMotion:
				var ax := (ev as InputEventJoypadMotion).axis
				parts.append("RT" if ax == JOY_AXIS_TRIGGER_RIGHT else ("LT" if ax == JOY_AXIS_TRIGGER_LEFT else "Stick"))
				break
	return "  ·  ".join(parts) if not parts.is_empty() else "-"



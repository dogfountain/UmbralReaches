extends Node
## Input actions defined in code so the bindings live in one readable place.
## Keyboard uses physical keys (layout-independent); gamepad follows the Xbox layout.

func _ready() -> void:
	_keys("move_forward", [KEY_W, KEY_UP])
	_keys("move_back", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("sprint", [KEY_SHIFT])
	_keys("jump", [KEY_SPACE])
	_keys("interact", [KEY_E])
	# Hotbar. Mouse/pad first so the hotbar label picks the primary binding.
	_mouse("skill_bolt", MOUSE_BUTTON_LEFT)
	_axis("skill_bolt", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_mouse("skill_lance", MOUSE_BUTTON_RIGHT)
	_keys("skill_lance", [KEY_R])
	_axis("skill_lance", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_keys("skill_nova", [KEY_Q])
	_button("skill_nova", JOY_BUTTON_RIGHT_SHOULDER)
	_keys("skill_ward", [KEY_F])
	_button("skill_ward", JOY_BUTTON_LEFT_SHOULDER)
	_keys("skill_step", [KEY_C])
	_button("skill_step", JOY_BUTTON_Y)
	_keys("slide", [KEY_CTRL])
	_button("slide", JOY_BUTTON_B)
	_keys("toggle_grade", [KEY_F1])
	_keys("toggle_debug", [KEY_F3])
	_keys("fullscreen", [KEY_F11])
	_keys("render_scale", [KEY_F4])
	_keys("toggle_settings", [KEY_F2, KEY_ESCAPE])
	_keys("benchmark", [KEY_F8])
	# "release_mouse" was checked by the player, settings, satchel and journal but never defined, so
	# every input event logged an InputMap error; defined without a key (Esc already frees the mouse
	# through the settings menu), it is a no-op instead of an error
	_ensure("release_mouse")
	_mouse("lock_on", MOUSE_BUTTON_MIDDLE)          # agent C: target lock (pad: right stick click)
	_button("lock_on", JOY_BUTTON_RIGHT_STICK)
	_keys("dodge", [KEY_V])                         # agent C: dodge roll (pad: slide button when slow or locked)
	# r31 staff arts: the primary trigger strikes by itself up close; these are the explicit keys.
	# Pad: RT strikes up close, guard is the slide button held while locked on with the stick idle.
	_keys("staff_strike", [KEY_G])                  # tap = a light strike, hold = a heavy
	_mouse("staff_strike", MOUSE_BUTTON_XBUTTON1)
	_keys("guard", [KEY_X])                         # hold = guard; its first instant parries
	_mouse("guard", MOUSE_BUTTON_XBUTTON2)
	_keys("inventory", [KEY_TAB, KEY_I])
	# r35: the Gear menu. It was G (gear_panel.gd bound it itself), which is also the staff strike: one
	# press opened Gear, the next closed it and swung. O sits with the other menu keys (I J K L M), away
	# from the fight's V C X G, so a missed key cannot pause a fight. zz/robust_test fails on any key
	# bound to two actions.
	_keys("gear", [KEY_O])
	_button("inventory", JOY_BUTTON_DPAD_UP)
	_button("toggle_settings", JOY_BUTTON_START)

	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_button("jump", JOY_BUTTON_A)
	_button("interact", JOY_BUTTON_X)
	_button("sprint", JOY_BUTTON_LEFT_STICK)         # on a pad L3 latches the sprint (Player._sprint_latch)
	# r29: the View/Back button opened the developer stats overlay for pad players; it is F3 only now.
	# The Kindling menu had no pad button at all (only K, or a fire): d-pad right, beside the other
	# menus on the d-pad (up satchel, down journal, left tasks). K is added here too, since the
	# growth UI only adds its own binding when the action does not exist yet.
	_keys("kindling", [KEY_K])
	_keys("mount", [KEY_H])                          # r36: call your horse (core/world/mount/stables.gd)
	_button("kindling", JOY_BUTTON_DPAD_RIGHT)
	# every other action lives here too (zz/robust_test fails on InputMap.add_action elsewhere)
	_keys("quest_log", [KEY_L])
	_button("quest_log", JOY_BUTTON_DPAD_LEFT)
	_keys("minimap", [KEY_N])                        # the corner dial: near, wide, off
	_keys("world_map", [KEY_M])                      # the whole Realm on a sheet of parchment (ui/world_map.gd)
	_button("world_map", JOY_BUTTON_MISC1)           # the Share / Capture button; the Journal's Map page reaches it on any pad
	_keys("codex", [KEY_J])
	_keys("tally", [KEY_B])                         # the Count: what the night has cost (ui/tally_panel.gd)
	_button("codex", JOY_BUTTON_DPAD_DOWN)
	_keys("show_objective", [KEY_Y])                 # hold to see the objective (it shows for 6 s when it changes, then hides)
	_button("show_objective", JOY_BUTTON_BACK)
	_keys("target_next", [KEY_T])                    # r33 combat: cycle targets nearest-first (Tab itself is the satchel)
	# what the player's own bindings replace is remembered first (Reset to defaults), then theirs are laid over
	for act in InputMap.get_actions():
		if not String(act).begins_with("ui_"):
			_defaults[String(act)] = InputMap.action_get_events(act).duplicate()


## The actions the Controls page lets the player rebind: [label, action]. Settings (Esc / F2 / Menu) and the
## developer keys (F8, F9) are fixed.
const REBINDABLE := [
	["Move Forward", "move_forward"], ["Move Back", "move_back"], ["Move Left", "move_left"], ["Move Right", "move_right"],
	["Sprint", "sprint"], ["Jump", "jump"], ["Slide", "slide"], ["Dodge Roll", "dodge"],
	["Lock On", "lock_on"], ["Next Target", "target_next"], ["Staff Strike", "staff_strike"], ["Guard / Parry", "guard"],
	["Kindle / Talk / Use", "interact"], ["Call Your Horse", "mount"],
	["Skill 1 (Bolt)", "skill_bolt"], ["Skill 2 (Lance)", "skill_lance"], ["Skill 3 (Nova)", "skill_nova"],
	["Skill 4 (Ward)", "skill_ward"], ["Skill 5 (Step)", "skill_step"],
	["Show Objective (Hold)", "show_objective"], ["Character", "inventory"], ["Gear", "gear"], ["Kindling", "kindling"], ["Journal", "codex"], ["The Count", "tally"], ["Tasks", "quest_log"], ["World Map", "world_map"], ["Minimap", "minimap"],
	["Fullscreen", "fullscreen"], ["Colour Grade", "toggle_grade"], ["Stats Overlay", "toggle_debug"],
]
## Keys the menus read themselves (pages Q / E, tabs 1-4, the cursor on W / S and the arrows, the Gear page's
## U Y R X F V): refused for an action that does not already have them by default, so a rebind cannot make a
## key do two things inside a menu. (A key an action ships with stays rebindable to that action.)
const MENU_KEYS := [KEY_Q, KEY_E, KEY_1, KEY_2, KEY_3, KEY_4, KEY_W, KEY_S, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_U, KEY_Y, KEY_R, KEY_X, KEY_F, KEY_V]
## Keys that cannot be bound: Esc is Settings and cancels the rebind itself.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_F2, KEY_F8, KEY_F9]

var _defaults: Dictionary = {}                      ## action -> its events as InputSetup defined them


func label_of(action: String) -> String:
	for r: Array in REBINDABLE:
		if r[1] == action:
			return String(r[0])
	return action


## A saved binding {"t": "key"|"mouse"|"btn", "c": int} as an event (null if it is not a valid one).
static func event_from(d: Variant) -> InputEvent:
	if not (d is Dictionary):
		return null
	var dd := d as Dictionary
	var c: Variant = dd.get("c", -1)
	if not (c is int or c is float) or not (dd.get("t") is String):
		return null
	var code := int(c)
	match String(dd.t):
		"key":
			if code <= 0 or code in RESERVED_KEYS:
				return null
			var k := InputEventKey.new()
			k.physical_keycode = code as Key
			return k
		"mouse":
			if code < 1 or code > 9:
				return null
			var m := InputEventMouseButton.new()
			m.button_index = code as MouseButton
			return m
		"btn":
			if code < 0 or code >= JOY_BUTTON_SDL_MAX:
				return null
			var b := InputEventJoypadButton.new()
			b.button_index = code as JoyButton
			return b
	return null


## The saved form of a key, mouse or pad-button event ({} for anything else).
static func event_to(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"t": "key", "c": int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "c": int((ev as InputEventMouseButton).button_index)}
	if ev is InputEventJoypadButton:
		return {"t": "btn", "c": int((ev as InputEventJoypadButton).button_index)}
	return {}


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return event_to(a) == event_to(b) and not event_to(a).is_empty()


## Which slot an event belongs to: "key" (keyboard and mouse) or "pad" (buttons); "" for axes and the rest.
static func slot_of(ev: InputEvent) -> String:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return "key"
	if ev is InputEventJoypadButton:
		return "pad"
	return ""


## The first event of `action` in `slot`, or null.
func first_event(action: String, slot: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if slot_of(ev) == slot:
			return ev
	return null


## What `action` is called now for the device in hand: the first pad button when `pad`, else the first key or
## mouse button; `fallback` (or the action's name) when nothing of that kind is bound. Lessons, prompts and
## the menu feet read this so a rebind is never taught as the old letter.
func live_label(action: String, pad := false, fallback := "") -> String:
	var ev := first_event(action, "pad" if pad else "key")
	if ev != null:
		return event_name(ev)
	return fallback if fallback != "" else action


## "" if `ev` may be bound to `action`; else why not (the message the Controls page shows).
func refusal(action: String, ev: InputEvent) -> String:
	var d := event_to(ev)
	if d.is_empty():
		return "That cannot be bound."
	if ev is InputEventKey and int(d.c) in RESERVED_KEYS:
		return "%s is reserved." % OS.get_keycode_string(int(d.c) as Key)
	for r: Array in REBINDABLE:
		var other: String = r[1]
		if other == action or not InputMap.has_action(other):
			continue
		for e in InputMap.action_get_events(other):
			if _same(e, ev):
				return "%s is already %s." % [event_name(ev), String(r[0])]
	# (after the clash check: a key another action holds says which one)
	if ev is InputEventKey and int(d.c) in MENU_KEYS and not _default_has(action, ev):
		return "%s is used inside the menus." % OS.get_keycode_string(int(d.c) as Key)
	for fixed: String in ["toggle_settings", "benchmark"]:
		for e in InputMap.action_get_events(fixed):
			if _same(e, ev):
				return "%s is reserved." % event_name(ev)
	return ""


func _default_has(action: String, ev: InputEvent) -> bool:
	for e: InputEvent in _defaults.get(action, []):
		if _same(e, ev):
			return true
	return false


## Rebind `action`'s first `slot` event to `ev` (it replaces that event, keeping the order: the hotbar and the
## prompts name the first one). Returns "" or the refusal. Saved in settings.cfg through Settings.bindings.
func rebind(action: String, slot: String, ev: InputEvent) -> String:
	var why := refusal(action, ev)
	if why != "":
		return why
	_replace(action, slot, ev)
	var b: Dictionary = Settings.bindings
	var mine: Dictionary = (b.get(action, {}) as Dictionary).duplicate()
	mine[slot] = event_to(ev)
	b[action] = mine
	Settings.apply()
	_forget_tips(action)
	return ""


## The just-in-time lessons (ui/hud.gd) that name each action: a rebind forgets them, so the next one prints the new key.
const TIP_ACTIONS := {"move": ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"], "jump2": ["jump"],
	"hang": ["jump", "slide"], "slide": ["slide", "jump"], "lock": ["lock_on", "dodge"], "roll": ["dodge"]}


func _forget_tips(action: String) -> void:
	var l: Variant = Travel.story.get("lessons", {})
	if not (l is Dictionary):
		return
	for id: String in TIP_ACTIONS:
		if action in (TIP_ACTIONS[id] as Array):
			(l as Dictionary).erase("tip_" + id)


func _replace(action: String, slot: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var evs := InputMap.action_get_events(action)
	var at := -1
	for i in evs.size():
		if slot_of(evs[i]) == slot:
			at = i
			break
	if at >= 0:
		evs[at] = ev
	else:
		evs.append(ev)
	if slot == "pad":
		# a pad button bound here replaces the default trigger / stick too: the skill's LT would still fire it
		# after being rebound to a button (and show in the Controls page as nothing)
		evs = evs.filter(func(e: InputEvent) -> bool: return not (e is InputEventJoypadMotion))
	InputMap.action_erase_events(action)
	for e in evs:
		InputMap.action_add_event(action, e)


## Lay the player's saved bindings over the defaults (boot, after Settings has read settings.cfg).
func apply_overrides(b: Dictionary) -> void:
	for action: String in b:
		if not InputMap.has_action(action) or not (b[action] is Dictionary):
			continue
		for slot: String in ["key", "pad"]:
			var ev := event_from((b[action] as Dictionary).get(slot))
			if ev != null and slot_of(ev) == slot and refusal(action, ev) == "":
				_replace(action, slot, ev)


## Every rebindable action back to what InputSetup defined; the saved bindings are cleared.
func reset_bindings() -> void:
	for r: Array in REBINDABLE:
		var action: String = r[1]
		if _defaults.has(action) and InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for e in _defaults[action]:
				InputMap.action_add_event(action, e)
	Settings.bindings.clear()
	Settings.apply()


## "W", "LMB", "A", "D-pad up": an event as the Controls page and prompts write it.
static func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		return String({MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB", MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get((ev as InputEventMouseButton).button_index, "Mouse"))
	if ev is InputEventJoypadButton:
		return String(PAD_NAMES.get((ev as InputEventJoypadButton).button_index, "Button %d" % (ev as InputEventJoypadButton).button_index))
	if ev is InputEventJoypadMotion:
		var ax := (ev as InputEventJoypadMotion).axis
		return "RT" if ax == JOY_AXIS_TRIGGER_RIGHT else ("LT" if ax == JOY_AXIS_TRIGGER_LEFT else "Stick")
	return "-"


const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Share"}


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = direction
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)

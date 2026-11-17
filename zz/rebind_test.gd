extends Node
## Rebinding (r37): Settings -> Controls edits InputMap through InputSetup. A key or button that already does
## something else is refused with a message; bindings are saved in settings.cfg and laid over the defaults on boot;
## Reset puts the defaults back; no key ends up on two actions.
##   HOME=<scratch> godot --headless --path . res://zz/rebind_test.tscn
const BK := "user://rebind_test_backup/"
var bad := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BK))
	if FileAccess.file_exists(Settings.PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(Settings.PATH), ProjectSettings.globalize_path(BK + "settings.cfg"))
	Settings.bindings.clear()
	_model()
	await _menu()
	InputSetup.reset_bindings()
	Settings.flush()
	if FileAccess.file_exists(Settings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	if FileAccess.file_exists(BK + "settings.cfg"):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BK + "settings.cfg"), ProjectSettings.globalize_path(Settings.PATH))
	Settings.set("_save_pending", false)
	print("REBIND done bad=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _first_key(action: String) -> int:
	var ev: InputEvent = InputSetup.first_event(action, "key")
	return int((ev as InputEventKey).physical_keycode) if ev is InputEventKey else -1


func _model() -> void:
	_ok(_first_key("jump") == KEY_SPACE, "jump starts on Space")
	var why: String = InputSetup.rebind("jump", "key", _key(KEY_J))
	_ok(why.contains("Journal") and _first_key("jump") == KEY_SPACE, "J is refused: '%s'" % why)
	_ok(InputSetup.rebind("jump", "key", _key(KEY_ESCAPE)) != "", "Esc cannot be bound")
	_ok(InputSetup.rebind("jump", "key", _key(KEY_B)) == "" and _first_key("jump") == KEY_B, "jump goes to B")
	_ok(not _bound("jump", KEY_SPACE) and (Settings.bindings.get("jump") as Dictionary).has("key"), "...Space is free again, and the binding is in Settings.bindings")
	_ok(InputSetup.rebind("skill_nova", "key", _key(KEY_SPACE)) == "" and _first_key("skill_nova") == KEY_SPACE, "the freed Space can be given to another action")
	_ok(InputSetup.rebind("move_forward", "key", _key(KEY_Z)) == "" and _first_key("move_forward") == KEY_Z and _bound("move_forward", KEY_UP), "move forward to Z, its arrow key stays")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	_ok(String(InputSetup.rebind("jump", "pad", pad)).contains("already"), "pad X (use) is refused for jump")
	pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_TOUCHPAD
	_ok(InputSetup.rebind("jump", "pad", pad) == "", "jump on the controller goes to the touchpad button")
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	_ok(String(InputSetup.rebind("jump", "key", m)).contains("Skill 1"), "LMB is refused (it is Skill 1)")
	_ok(_clashes().is_empty(), "no key or mouse button does two things %s" % [_clashes()])
	# saved, read back, laid over the defaults
	Settings.save_settings()
	InputSetup.reset_bindings()                       # also clears Settings.bindings and re-saves
	_ok(_first_key("jump") == KEY_SPACE and _first_key("move_forward") == KEY_W, "reset: the defaults are back")
	Settings.bindings = {"jump": {"key": {"t": "key", "c": int(KEY_B)}}, "move_forward": {"key": {"t": "key", "c": int(KEY_Z)}}, "nonsense": 5,
		"skill_nova": {"key": {"t": "key", "c": int(KEY_ESCAPE)}}, "dodge": {"key": "x"}}
	Settings.save_settings()
	Settings.bindings = {}
	Settings.load_settings()
	InputSetup.apply_overrides(Settings.bindings)
	_ok(_first_key("jump") == KEY_B and _first_key("move_forward") == KEY_Z, "bindings read back from settings.cfg and applied (jump %d)" % _first_key("jump"))
	_ok(_first_key("skill_nova") == KEY_Q and _first_key("dodge") == KEY_V, "a reserved key and a wrong-typed entry in the file are ignored")
	InputSetup.reset_bindings()


func _menu() -> void:
	var sm: CanvasLayer = (load("res://ui/settings_menu.gd") as GDScript).new()
	add_child(sm)
	await get_tree().process_frame
	sm.call("open")
	var btn: Button = (sm.get("_b").btns as Dictionary)["interact|key"]
	_ok(btn.text == "E", "the Controls page shows interact = E (%s)" % btn.text)
	sm.get("_b").begin("interact", "key")
	_ok(btn.text.begins_with("press"), "clicking a binding waits for a key")
	sm.get("_b").input(_press(KEY_Q))
	_ok(_first_key("interact") == KEY_E and String((sm.get("_b").msg as Label).text).contains("already"), "...Q is refused with a message (%s)" % (sm.get("_b").msg as Label).text)
	sm.get("_b").input(_press(KEY_ESCAPE))
	_ok(String(sm.get("_b").listen) == "" and btn.text == "E", "Esc cancels the rebind")
	sm.get("_b").begin("interact", "key")
	sm.get("_b").input(_press(KEY_B))
	_ok(_first_key("interact") == KEY_B and btn.text == "B", "B is accepted and shown")
	sm.call("close")
	InputSetup.reset_bindings()


func _press(code: Key) -> InputEventKey:
	var e := _key(code)
	e.pressed = true
	return e


func _bound(action: String, key: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false


func _clashes() -> PackedStringArray:
	var by := {}
	for act: StringName in InputMap.get_actions():
		if String(act).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(act):
			var id := ""
			if ev is InputEventKey:
				id = "key %d" % int((ev as InputEventKey).physical_keycode)
			elif ev is InputEventMouseButton:
				id = "mouse %d" % int((ev as InputEventMouseButton).button_index)
			if id == "":
				continue
			var acts: Array = by.get(id, [])
			if not acts.has(String(act)):
				acts.append(String(act))
			by[id] = acts
	var out := PackedStringArray()
	for id: String in by:
		if (by[id] as Array).size() > 1:
			out.append("%s: %s" % [id, " + ".join(by[id])])
	return out


func _ok(cond: bool, what: String) -> void:
	print(("REBIND ok   " if cond else "REBIND FAIL ") + what)
	if not cond:
		bad += 1

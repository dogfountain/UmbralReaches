extends Node
## Robustness of what the player brings with them (critF):
##   - a damaged settings.cfg (wrong types, out-of-range indices, NaN) loads as sane values
##   - a save whose checkpoint is over nothing wakes the wanderer at the spawn brazier, not in the void
##   - every brazier's spawn point (where a kindle sends you back) is standable
##   - the settings menu builds, every tab opens, the KEYS list comes from the InputMap
## Backs up and restores the real save and settings itself; holds Travel._busy; quits itself (90 s).
##   HOME=<scratch> godot --headless --path . res://zz/robust_test.tscn
const BK := "user://robust_test_backup/"
var bad := 0
var main: Node
var t := 0.0
var _phase := 0


func _ready() -> void:
	Travel._busy = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BK))
	for f: String in [Travel.SAVE_PATH, Travel.SAVE_PATH + ".bak", Settings.PATH]:
		_mv(f, BK + f.get_file())
	# 1. damaged settings
	var sc := ConfigFile.new()
	sc.set_value("display", "window_size_index", 9)
	sc.set_value("display", "fps_limit", -7)
	sc.set_value("display", "fullscreen", "yes")
	sc.set_value("graphics", "aa_mode", 99)
	sc.set_value("graphics", "shadow_quality", -3)
	sc.set_value("graphics", "quality_preset", 12)
	sc.set_value("graphics", "motion_blur", NAN)
	sc.set_value("camera", "fov", "wide")
	sc.set_value("camera", "mouse_sensitivity", 5.0)
	sc.set_value("camera", "stick_sensitivity", 99.0)
	sc.set_value("audio", "master", "loud")
	sc.set_value("audio", "music", 3.0)
	sc.save(Settings.PATH)
	Settings.load_settings()
	_ok(Settings.window_size_index >= 0 and Settings.window_size_index < Settings.WINDOW_SIZES.size(), "settings: window size index in range")
	_ok(Settings.fps_limit == -1, "settings: negative fps limit means match display")
	_ok(Settings.fullscreen == false, "settings: wrong-typed fullscreen falls back")
	_ok(Settings.aa_mode == Settings.AA_NAMES.size() - 1 and Settings.shadow_quality == 0 and Settings.quality_preset == 2, "settings: indices clamped")
	_ok(is_finite(Settings.motion_blur) and Settings.motion_blur >= 0.0 and Settings.motion_blur <= 1.0, "settings: NaN blur refused")
	_ok(Settings.fov >= 50.0 and Settings.fov <= 90.0 and Settings.mouse_sensitivity <= 0.01 and Settings.stick_sensitivity == 5.0, "settings: camera values sane")
	_ok(Settings.master_volume <= 1.0 and Settings.music_volume == 1.0, "settings: volumes clamped")
	# atomic settings write: no temp left behind
	Settings.save_settings()
	_ok(FileAccess.file_exists(Settings.PATH) and not FileAccess.file_exists(Settings.PATH + ".tmp"), "settings: written atomically")
	Settings.reset_defaults()
	Settings.flush()
	# 2. a save whose checkpoint is over nothing (outside the Realm)
	var sv := ConfigFile.new()
	sv.set_value("progress", "version", 1)
	sv.set_value("progress", "checkpoints", {"res://world/main.tscn": Vector3(400.0, 3.0, 400.0)})
	sv.save(Travel.SAVE_PATH)
	Travel.load_game()
	_ok(Travel.checkpoint_for("res://world/main.tscn") == Vector3(400.0, 3.0, 400.0), "save: checkpoint loaded")
	# 3. lint: every InputMap action is defined in InputSetup (six scripts used to add their own)
	var strays := _stray_add_actions("res://")
	_ok(strays.is_empty(), "input: no InputMap.add_action outside InputSetup %s" % [strays])
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _stray_add_actions(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub: String in DirAccess.get_directories_at(dir):
		if sub == "zz" or sub.begins_with(".") or sub == "art" or sub == "docs":
			continue
		out.append_array(_stray_add_actions(dir.path_join(sub)))
	for f: String in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if not f.ends_with(".gd") or path == "res://autoload/input_setup.gd":
			continue
		if FileAccess.get_file_as_string(path).contains("InputMap." + "add_action"):
			out.append(path)
	return out


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 90.0:
		_ok(false, "timed out in phase %d" % _phase)
		_finish()
		return
	if _phase == 0 and main.has_meta("realm_done"):
		_phase = 1
		t = minf(t, 80.0)
		await get_tree().create_timer(0.5).timeout
		_ok(main.get_script() != null and main.has_method("_unstandable"), "world/main.gd and zone.gd compiled")
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var sanct := main.get_node_or_null("Zone/Braziers/Sanctuary")
		var want: Vector3 = sanct.call("spawn_point") if sanct else Vector3(0, 0.4, 26.5)
		_ok(p != null and p.global_position.distance_to(want) < 3.0, "save: a checkpoint over nothing wakes at the spawn brazier (%s)" % (p.global_position if p else Vector3.ZERO))
		# 3. braziers' spawn points
		var n := 0
		for b in main.find_children("*", "", true, false):
			if b is Brazier:
				n += 1
				var sp: Vector3 = (b as Brazier).spawn_point()
				var why: String = main.call("_unstandable", sp)
				_ok(why == "", "brazier %s spawn point %s standable %s" % [b.name, sp.snapped(Vector3.ONE * 0.1), why])
		_ok(n >= 5, "found the braziers (%d)" % n)
		# 3b. r35: no key or mouse button does two things. Scanned once the whole night is up, so the
		# actions that UI nodes add for themselves are in the map too (G was the staff strike AND the
		# Gear menu). The engine's own ui_* actions are menu navigation and may overlap.
		var clash := _input_clashes()
		_ok(clash.is_empty(), "every key and mouse button has one action%s" % ("" if clash.is_empty() else ": " + ", ".join(clash)))
		_ok(InputMap.has_action("gear") and not _bound("staff_strike", KEY_O) and _bound("gear", KEY_O) and not _bound("gear", KEY_G), "Gear is O, the staff strike keeps G")
		# 4. the settings menu
		var sm: Node = null
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.get_script() and String((c.get_script() as Script).resource_path).ends_with("settings_menu.gd"):
				sm = c
		_ok(sm != null, "settings menu present")
		if sm:
			sm.call("open")
			for i in 4:
				sm.call("_show_tab", i)
			_ok(String(sm.call("_keys_text", ["dodge"], "?")) == "V", "keys list reads the InputMap (dodge = %s)" % sm.call("_keys_text", ["dodge"], "?"))
			_ok(String(sm.call("_pad_text", ["jump"], "")) == "A", "pad list reads the InputMap (jump = %s)" % sm.call("_pad_text", ["jump"], ""))
			sm.call("close")
			_ok(not get_tree().paused, "settings close unpauses")
			# prompts name the device in hand
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_A
			pad.pressed = true
			Settings._input(pad)
			var on_pad := Interactable.prompt_key()
			var key := InputEventKey.new()
			key.physical_keycode = KEY_W
			key.pressed = true
			Settings._input(key)
			_ok(on_pad == "X" and Interactable.prompt_key() == "E", "interact prompt follows the device (pad %s, keys %s)" % [on_pad, Interactable.prompt_key()])
			# opened over a menu that paused the world (Kindling, dialogue, shop): closing Settings
			# must leave it paused for that menu
			get_tree().paused = true
			sm.call("open")
			sm.call("close")
			_ok(get_tree().paused, "settings over a paused menu leaves it paused")
			get_tree().paused = false
		_finish()


func _finish() -> void:
	set_process(false)
	for f: String in [Travel.SAVE_PATH, Travel.SAVE_PATH + ".bak", Travel.SAVE_PATH + ".tmp", Settings.PATH, Settings.PATH + ".tmp"]:
		_rm(f)
	for f: String in [Travel.SAVE_PATH, Travel.SAVE_PATH + ".bak", Settings.PATH]:
		_mv(BK + f.get_file(), f)
	Settings.set("_save_pending", false)
	print("ROBUST done bad=%d" % bad)
	get_tree().quit()


## "KEY_G: staff_strike + gear" for every keyboard key / mouse button bound to two or more actions.
func _input_clashes() -> PackedStringArray:
	var by: Dictionary = {}
	for act: StringName in InputMap.get_actions():
		if String(act).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(act):
			var id := ""
			if ev is InputEventKey:
				var k := ev as InputEventKey
				id = "key " + OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
			elif ev is InputEventMouseButton:
				id = "mouse %d" % (ev as InputEventMouseButton).button_index
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


func _bound(action: String, key: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ((ev as InputEventKey).physical_keycode == key or (ev as InputEventKey).keycode == key):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	print(("ROBUST ok   " if cond else "ROBUST FAIL ") + what)
	if not cond:
		bad += 1


func _mv(from: String, to: String) -> void:
	if FileAccess.file_exists(from):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

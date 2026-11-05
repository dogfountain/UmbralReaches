extends Node
## Save slots and the title screen (r37): savegame.cfg is per slot (slot_<n>/savegame.cfg), an old single save
## migrates into slot 1 without loss (.bak kept, atomic .tmp/.bak write intact), New Game wipes only its slot,
## "Erase Saved Progress" ends the session's silence (r35 B10: saving works again after a new slot is picked),
## the title screen builds and chooses, and a harness run skips it.
##   HOME=<scratch> godot --headless --path . res://zz/slots_test.tscn
const SaveDir := preload("res://core/util/save_dir.gd")
const TitleScreen := preload("res://ui/title_screen.gd")
const BK := "user://slots_test_backup/"
var bad := 0
var _moved: Array[String] = []


func _ready() -> void:
	Travel._busy = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BK))
	_stash()
	_migration()
	_slots()
	_erase()
	await _title()
	_restore()
	print("SLOTS done bad=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _files() -> Array[String]:
	var out: Array[String] = ["user://savegame.cfg", "user://savegame.cfg.bak", "user://savegame.cfg.migrated", "user://savegame.cfg.bak.migrated",
		"user://slots.cfg", "user://codex.cfg"]
	for n in range(1, 4):
		for suf in ["", ".bak", ".tmp"]:
			out.append("user://slot_%d/savegame.cfg%s" % [n, suf])
		out.append("user://slot_%d/codex.cfg" % n)
	return out


func _stash() -> void:
	for f in _files():
		if FileAccess.file_exists(f):
			var dest := BK + f.trim_prefix("user://").replace("/", "__")
			DirAccess.rename_absolute(ProjectSettings.globalize_path(f), ProjectSettings.globalize_path(dest))
			_moved.append(f)


func _restore() -> void:
	for f in _files():
		_rm(f)
	for f in _moved:
		var src := BK + f.trim_prefix("user://").replace("/", "__")
		DirAccess.rename_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(f))
	Travel.use_slot(1)


func _write(path: String, marker: int) -> void:
	var c := ConfigFile.new()
	c.set_value("progress", "version", 1)
	c.set_value("progress", "items", {"marker": marker})
	c.set_value("progress", "bosses", {"thornwarden": true})
	c.set_value("progress", "lit_by_path", {"res://world/main.tscn": PackedStringArray(["A", "B"])})
	c.save(path)


func _marker(path: String) -> int:
	var c := ConfigFile.new()
	if c.load(path) != OK:
		return -1
	return int((c.get_value("progress", "items", {}) as Dictionary).get("marker", -2))


func _migration() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://slot_1/"))
	_write("user://savegame.cfg", 7)
	_write("user://savegame.cfg.bak", 3)
	Travel._migrate_legacy()
	_ok(_marker("user://slot_1/savegame.cfg") == 7 and _marker("user://slot_1/savegame.cfg.bak") == 3, "an old savegame.cfg and its .bak are copied into slot 1")
	_ok(not FileAccess.file_exists("user://savegame.cfg") and FileAccess.file_exists("user://savegame.cfg.migrated"), "...and the old file is kept, renamed .migrated (nothing lost)")
	_rm("user://slot_1/savegame.cfg")
	_rm("user://slot_1/savegame.cfg.bak")
	Travel._migrate_legacy()
	_ok(not FileAccess.file_exists("user://slot_1/savegame.cfg"), "an erased slot 1 is not refilled from the old file")
	_write("user://slot_1/savegame.cfg", 7)
	Travel._migrate_legacy()
	_ok(_marker("user://slot_1/savegame.cfg") == 7, "migration never overwrites a slot")


func _slots() -> void:
	Travel.use_slot(1)
	_ok(Travel.SAVE_PATH.ends_with("slot_1/savegame.cfg") and int(Travel.items.get("marker", 0)) == 7, "slot 1 loads its save (marker %s)" % [Travel.items.get("marker")])
	Travel.use_slot(2, true)
	_ok(Travel.items.is_empty() and Travel.SAVE_PATH.ends_with("slot_2/savegame.cfg"), "a New Game in slot 2 starts empty")
	Travel.items["gold_x"] = 2
	Travel.save_now()
	_ok(FileAccess.file_exists(Travel.SAVE_PATH) and not FileAccess.file_exists(Travel.SAVE_PATH + ".tmp"), "slot 2 saved atomically (no .tmp left)")
	Travel.save_now()
	_ok(FileAccess.file_exists(Travel.SAVE_PATH + ".bak"), "the second save keeps the first as .bak")
	_ok(_marker("user://slot_1/savegame.cfg") == 7, "slot 1 was not touched by slot 2's saves")
	var s2 := Travel.slot_summary(2)
	var s3 := Travel.slot_summary(3)
	_ok(bool(s2.exists) and String(s2.text).contains("fire") and not bool(s3.exists), "slot summaries: 2 has a save (%s), 3 is empty" % s2.text)
	var s1 := Travel.slot_summary(1)
	_ok(int(s1.fires) == 2 and int(s1.bosses) == 1, "slot 1 reads 2 fires and 1 keeper slain (%s)" % s1.text)
	Travel.use_slot(1)
	_ok(int(Travel.items.get("marker", 0)) == 7 and not Travel.items.has("gold_x"), "back in slot 1: its own items, none of slot 2's")
	var last := ConfigFile.new()
	last.load("user://slots.cfg")
	_ok(int(last.get_value("slots", "last", 0)) == 1, "the last slot used is remembered")


func _erase() -> void:
	Travel.use_slot(1)
	Travel.erase_save()
	_ok(Travel.erased and not FileAccess.file_exists(Travel.SAVE_PATH), "erase wipes the slot's file")
	Travel.save_now()
	_ok(not FileAccess.file_exists(Travel.SAVE_PATH), "...and the erased session writes nothing more")
	Travel.use_slot(1, true)
	Travel.items["after"] = 1
	Travel.save_now()
	_ok(not Travel.erased and FileAccess.file_exists(Travel.SAVE_PATH), "r35 B10: choosing a slot again lets the session save")


func _title() -> void:
	_ok(not TitleScreen.wanted(), "a headless / harness run skips the title screen")
	for n in range(1, 4):
		for suf in ["", ".bak"]:
			_rm("user://slot_%d/savegame.cfg%s" % [n, suf])
	var t: CanvasLayer = TitleScreen.new()
	add_child(t)
	await get_tree().process_frame
	var buttons: Array = t.get("_buttons")
	var names: Array[String] = []
	for b: Button in buttons:
		names.append(b.text)
	_ok(names == ["Continue", "New Game", "Settings", "Quit"], "the title offers Continue, New Game, Settings, Quit (%s)" % [names])
	_ok((buttons[0] as Button).disabled, "Continue is greyed out when no slot holds a save")
	var got: Array = []
	t.chosen.connect(func(s: int, f: bool) -> void: got.append([s, f]))
	t.call("_open_slots", "new")
	await get_tree().process_frame
	t.call("_slot_pressed", 3)
	_ok(got == [[3, true]], "New Game on an empty slot chooses it at once (%s)" % [got])
	t.queue_free()
	_write("user://slot_2/savegame.cfg", 9)
	var t2: CanvasLayer = TitleScreen.new()
	add_child(t2)
	await get_tree().process_frame
	_ok(not ((t2.get("_buttons") as Array)[0] as Button).disabled, "Continue is enabled once a slot holds a save")
	var got2: Array = []
	t2.chosen.connect(func(s: int, f: bool) -> void: got2.append([s, f]))
	t2.call("_open_slots", "continue")
	_ok(got2 == [[2, false]], "Continue with one save goes straight to it (%s)" % [got2])
	t2.queue_free()
	var t3: CanvasLayer = TitleScreen.new()
	add_child(t3)
	await get_tree().process_frame
	var got3: Array = []
	t3.chosen.connect(func(s: int, f: bool) -> void: got3.append([s, f]))
	t3.call("_open_slots", "new")
	t3.call("_slot_pressed", 2)
	_ok(got3.is_empty(), "New Game on an occupied slot asks first")
	t3.call("_slot_pressed", 2)
	_ok(got3 == [[2, true]], "...and wipes it on the second press")
	t3.queue_free()
	# the first scene: the title shows when forced (Travel.to_title), and the flag is spent
	Travel.forced_title = true
	var boot: Node = (load("res://ui/title_boot.tscn") as PackedScene).instantiate()
	add_child(boot)
	await get_tree().process_frame
	_ok(boot.get_node_or_null("TitleScreen") != null and not Travel.forced_title, "title_boot opens the title screen when forced")
	boot.queue_free()


func _ok(cond: bool, what: String) -> void:
	print(("SLOTS ok   " if cond else "SLOTS FAIL ") + what)
	if not cond:
		bad += 1


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

extends Node
## Save hardening: a save asked for during a scene change is written when it ends, and a save whose
## rename never landed is recovered from the .tmp beside it (main, then .tmp, then .bak).
##   HOME=<scratch> godot --headless --path . res://zz/save_recover_test.tscn
var bad := 0


func _ready() -> void:
	Travel._busy = false
	_recover()
	_missed()
	_erased()
	print("SAVE RECOVER TEST PASS" if bad == 0 else "SAVE RECOVER TEST FAIL %d" % bad)
	get_tree().quit(bad)


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)


func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(_abs(p))


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _cfg_with(n: int) -> ConfigFile:
	var c := ConfigFile.new()
	c.set_value("progress", "version", 1)
	c.set_value("progress", "items", {"grave_ash": n})
	return c


func _recover() -> void:
	Travel.use_slot(1, true)
	var main := Travel.SAVE_PATH
	Travel.give("grave_ash", 7)
	Travel.save_game()
	_rm(main + ".bak")
	DirAccess.rename_absolute(_abs(main), _abs(main + ".tmp"))
	Travel.items.clear()
	Travel.load_game()
	_ok(Travel.count("grave_ash") == 7, "temp recovery: the unfinished save loads when the main file is gone")

	# the main file wins over a newer-looking temp
	for s in ["", ".tmp", ".bak"]:
		_rm(main + s)
	_cfg_with(7).save(main)
	_cfg_with(9).save(main + ".tmp")
	Travel.items.clear()
	Travel.load_game()
	_ok(Travel.count("grave_ash") == 7, "order: the main file wins over the .tmp")

	# a garbage temp is skipped and the backup loads
	_rm(main)
	_put(main + ".tmp", "garbage")
	_cfg_with(5).save(main + ".bak")
	Travel.items.clear()
	Travel.load_game()
	_ok(Travel.count("grave_ash") == 5, "bad temp, good backup: the backup loads")
	for s in ["", ".tmp", ".bak"]:
		_rm(main + s)


func _missed() -> void:
	Travel.use_slot(2, true)
	var main := Travel.SAVE_PATH
	Travel._busy = true
	Travel.give("grave_ash", 3, false, false)
	Travel.save_game()
	_ok(not FileAccess.file_exists(main) and Travel._save_missed, "missed save: nothing written while busy, and it is remembered")
	Travel._busy = false
	Travel._flush_missed()
	var c := ConfigFile.new()
	var good := FileAccess.file_exists(main) and c.load(main) == OK
	var held: Dictionary = c.get_value("progress", "items", {}) if good else {}
	_ok(good and int(held.get("grave_ash", 0)) == 3 and not Travel._save_missed, "missed save: written when the scene change ends")


func _erased() -> void:
	var main := Travel.SAVE_PATH
	Travel.erase_save()
	Travel.save_game()
	_ok(not FileAccess.file_exists(main) and not Travel._save_missed, "erased: save_game writes nothing and remembers nothing")
	Travel.use_slot(1, true)
	for n in [1, 2]:
		for s in ["", ".tmp", ".bak"]:
			_rm("user://slot_%d/savegame.cfg%s" % [n, s])


func _ok(cond: bool, what: String) -> void:
	print(("SAVEREC ok " if cond else "SAVEREC FAIL ") + what)
	if not cond:
		bad += 1

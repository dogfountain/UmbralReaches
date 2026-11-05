extends Node
## Save-file robustness: an old save (zz/fixtures/savegame_pre_storage.cfg, written before the
## atomic/backup format) loads; a round trip keeps every value, drops empty kindle lists and keeps
## keys this build doesn't know; a corrupt main file falls back to the .bak; wrong-typed values load
## as empty; erase removes the backup too. Backs up and restores the real save itself.
##   godot --headless --path . res://zz/storage_save_test.tscn
const FIXTURE := "res://zz/fixtures/savegame_pre_storage.cfg"
const BK := "user://storage_test_backup/"
var bad := 0


func _ready() -> void:
	var save := Travel.SAVE_PATH
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BK))
	for s: String in ["", ".bak", ".tmp"]:
		_mv(save + s, BK + "savegame.cfg" + s)
	_run(save)
	for s: String in ["", ".bak", ".tmp"]:
		_rm(save + s)
		_mv(BK + "savegame.cfg" + s, save + s)
	Travel.set("_busy", true)      # no save-on-exit over the restored real save
	print("STORAGE_SAVE done bad=%d" % bad)
	get_tree().quit()


func _run(save: String) -> void:
	var fx := ConfigFile.new()
	_ok(fx.load(FIXTURE) == OK, "fixture readable")
	# 1. the old save loads
	_copy(FIXTURE, save)
	Travel.load_game()
	_ok(Travel.bosses_slain.size() == (fx.get_value("progress", "bosses", {}) as Dictionary).size(), "old save: bosses")
	_ok(Travel.seals_broken.size() == (fx.get_value("progress", "seals", {}) as Dictionary).size(), "old save: seals")
	_ok(Travel.count("grave_ash") == int((fx.get_value("progress", "items", {}) as Dictionary).get("grave_ash", 0)), "old save: items")
	_ok(Travel.relics.size() == (fx.get_value("progress", "relics", {}) as Dictionary).size(), "old save: relics")
	# 2. round trip: same values, compact kindles, version, backup of the previous file
	var before := FileAccess.get_file_as_bytes(save).size()
	Travel.save_game()
	var rt := ConfigFile.new()
	_ok(rt.load(save) == OK, "round trip readable")
	_ok(int(rt.get_value("progress", "version", 0)) == Travel.SAVE_VERSION, "version written")
	for k: String in ["bosses", "seals", "items", "relics", "area_lit", "checkpoints"]:
		_ok(rt.get_value("progress", k) == fx.get_value("progress", k, {}), "round trip " + k)
	var lit: Dictionary = rt.get_value("progress", "lit_by_path", {})
	for k in lit:
		_ok(not (lit[k] as PackedStringArray).is_empty(), "no empty kindle list " + str(k))
	_ok(lit.has("res://world/main.tscn"), "lit kindles kept")
	_ok(FileAccess.file_exists(save + ".bak"), "backup written")
	_ok(not FileAccess.file_exists(save + ".tmp"), "temp file renamed away")
	print("SAVE size %d -> %d bytes" % [before, FileAccess.get_file_as_bytes(save).size()])
	# 3. keys this build doesn't know survive a save
	var fut := ConfigFile.new()
	fut.load(save)
	fut.set_value("progress", "future_key", 7)
	fut.set_value("story", "chapter", "two")
	fut.save(save)
	Travel.load_game()
	Travel.save_game()
	var back := ConfigFile.new()
	back.load(save)
	_ok(int(back.get_value("progress", "future_key", 0)) == 7, "unknown key kept")
	_ok(String(back.get_value("story", "chapter", "")) == "two", "unknown section kept")
	# 4. corrupt main file -> the backup loads
	var f := FileAccess.open(save, FileAccess.WRITE)
	f.store_string("[progress\nversion=garbage{{{ ]]")
	f = null
	Travel.bosses_slain.clear()
	Travel.load_game()
	_ok(Travel.bosses_slain.size() == (fx.get_value("progress", "bosses", {}) as Dictionary).size(), "corrupt main: backup loaded")
	# 5. wrong-typed values load as empty, not as an error
	var wt := ConfigFile.new()
	wt.set_value("progress", "version", 1)
	wt.set_value("progress", "lit_by_path", "oops")
	wt.set_value("progress", "items", 5)
	wt.save(save)
	Travel.load_game()
	_ok(Travel.lit_by_path.is_empty() and Travel.items.is_empty(), "wrong types load empty")
	# 5b. wrong-typed values INSIDE the sections load what is good and drop the rest (critF)
	var nt := ConfigFile.new()
	nt.set_value("progress", "version", 1)
	nt.set_value("progress", "lit_by_path", {"res://world/main.tscn": "Sanctuary", "res://a.tscn": ["Shrine", 3, null]})
	nt.set_value("progress", "items", {"grave_ash": "12", "relic_fragment": {"x": 1}, "charm_chalk": 2.0, "neg": -5})
	nt.set_value("progress", "checkpoints", {"res://world/main.tscn": "here", "res://b.tscn": Vector3(INF, 0, 0), "res://c.tscn": Vector3(1, 2, 3)})
	nt.set_value("progress", "relics", {"bone": 5, "thorn": "briar"})
	nt.set_value("progress", "seals", {"henge": true, "summit": false, "oss_gallery": "yes"})
	nt.set_value("progress", "hollows", "many")
	nt.save(save)
	Travel.load_game()
	_ok(Travel.lit_by_path.size() == 1 and (Travel.lit_by_path["res://a.tscn"] as PackedStringArray) == PackedStringArray(["Shrine"]), "nested: kindle lists cleaned")
	_ok(Travel.count("grave_ash") == 12 and Travel.count("charm_chalk") == 2 and not Travel.items.has("relic_fragment") and not Travel.items.has("neg"), "nested: item counts cleaned")
	_ok(Travel.checkpoints.size() == 1 and Travel.checkpoint_for("res://c.tscn") == Vector3(1, 2, 3) and Travel.checkpoint_for("res://world/main.tscn") == Vector3.INF, "nested: bad checkpoints dropped")
	_ok(Travel.relics.size() == 1 and Travel.relics.get("thorn") == &"briar", "nested: bad relic dropped")
	_ok(Travel.seals_broken.has("henge") and Travel.seals_broken.has("oss_gallery") and not Travel.seals_broken.has("summit"), "nested: seal flags")
	_ok(Travel.saved_hollows == 0, "nested: hollows")
	Travel.save_game()
	var again := ConfigFile.new()
	_ok(again.load(save) == OK and again.has_section("progress"), "nested: cleaned save writes back")
	# 6. erase removes main and backup
	Travel.erase_save()
	_ok(not FileAccess.file_exists(save) and not FileAccess.file_exists(save + ".bak"), "erase removes backup")
	# 7. after an erase nothing more is written this session (the running night still holds the old
	# progress in its nodes: a save on quit would write it straight back)
	Travel.bosses_slain["bone_abbot"] = true
	Travel.save_game()
	_ok(not FileAccess.file_exists(save), "no save after erase")
	Travel.erased = false


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		bad += 1


func _copy(from: String, to: String) -> void:
	FileAccess.open(to, FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(from))


func _mv(from: String, to: String) -> void:
	if FileAccess.file_exists(from):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

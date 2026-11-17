extends RefCounted
## The wanderer's journal, as data (no class_name: preload by path). What has been read, which
## places have been found, in the order it happened. Static, so it outlives scene changes without
## an autoload. Persisted in its own small file, user://codex.cfg (not Travel's save), written on
## every new entry. `-- --fresh` starts an empty journal (like Travel). Tests point `path` elsewhere
## or switch `persist` off so they never touch the player's journal.
##
##   const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
##   CodexStore.record_read("rd_way_12")      -> true the first time
##   CodexStore.discover("road")              -> true the first time

const SaveDir := preload("res://core/util/save_dir.gd")
const DEFAULT_PATH := "user://codex.cfg"
const VERSION := 1

static var path: String = preload("res://core/util/save_dir.gd").path("codex.cfg")   ## DEFAULT_PATH unless `-- --save-dir=`
static var persist := true
static var read: Dictionary = {}        ## lore id -> order it was first read (int)
static var places: Dictionary = {}      ## region id -> order it was first entered (int)
static var _n := 0
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if persist and not "--fresh" in OS.get_cmdline_user_args():
		load_file()


static func has_read(id: String) -> bool:
	ensure()
	return read.has(id)


static func discovered(region: String) -> bool:
	ensure()
	return places.has(region)


## Mark `id` read. Returns true when it is new to the journal.
static func record_read(id: String) -> bool:
	ensure()
	if id == "" or read.has(id):
		return false
	_n += 1
	read[id] = _n
	save()
	return true


## Mark region `id` found. Returns true when it is new.
static func discover(id: String) -> bool:
	ensure()
	if id == "" or places.has(id):
		return false
	_n += 1
	places[id] = _n
	save()
	return true


## Ids read, oldest first.
static func read_in_order() -> Array[String]:
	ensure()
	var ids: Array[String] = []
	for id: String in read:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return int(read[a]) < int(read[b]))
	return ids


static func save() -> void:
	if not persist or not _writable():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("codex", "version", VERSION)
	cfg.set_value("codex", "read", read)
	cfg.set_value("codex", "places", places)
	cfg.set_value("codex", "n", _n)
	var err := SaveDir.save_atomic(cfg, path)   # through a temp file: a crash mid-write keeps the old journal
	if err != OK:
		push_warning("Codex: could not save %s (%s)" % [path, err])


## The player's journal is only written by the game itself: a zz/ test harness that loads the
## world (realm walks, boss tests) must not fill it. Tests that point `path` elsewhere still write.
static func _writable() -> bool:
	if path != DEFAULT_PATH:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var cs: Node = tree.current_scene if tree else null
	return cs == null or not cs.scene_file_path.begins_with("res://zz/")


static func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	if int(cfg.get_value("codex", "version", 0)) > VERSION:
		push_warning("Codex: %s is from a newer build; reading what it can" % path)
	var r: Variant = cfg.get_value("codex", "read", {})
	var p: Variant = cfg.get_value("codex", "places", {})
	read = (r as Dictionary).duplicate() if r is Dictionary else {}
	places = (p as Dictionary).duplicate() if p is Dictionary else {}
	_n = int(cfg.get_value("codex", "n", read.size() + places.size()))


## Forget everything in memory (and on disk when `wipe_file`). Tests and "erase progress".
static func reset(wipe_file := false) -> void:
	read.clear()
	places.clear()
	_n = 0
	_loaded = true
	if wipe_file and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Use another file (tests): forget memory and read that file instead.
static func use_path(p: String, load_it := true) -> void:
	path = p
	read.clear()
	places.clear()
	_n = 0
	_loaded = true
	if load_it:
		load_file()

extends RefCounted
## Where the player's files live: user:// by default. Tests and tools point every save at a scratch
## folder instead, so they can never write Luke's savegame.cfg / settings.cfg / codex.cfg:
##   godot --path . res://zz/some_test.tscn -- --save-dir=/private/tmp/scratch_saves
## (or the env var UMBRAL_SAVE_DIR). Read by Travel (savegame.cfg), Settings (settings.cfg) and
## CodexStore (codex.cfg) when they start. No class_name: preload by path.
##   const SaveDir := preload("res://core/util/save_dir.gd")

## r37, three save slots: savegame.cfg lives in <dir>/slot_<n>/ (an old <dir>/savegame.cfg is copied into
## slot_1 on first launch: Travel._migrate_legacy). The Journal's codex.cfg is per slot too, but slot 1 keeps
## the original <dir>/codex.cfg (the Journal of every existing save, and CodexStore's test guard), slots 2 and 3
## use <dir>/slot_<n>/codex.cfg. Everything else (settings.cfg, hud.cfg, slots.cfg) is shared.
const SLOTS := 3

static var _dir: Variant = null
static var slot := 1                 ## the slot in play (Travel.use_slot sets it)


## The folder (ends in "/"): user:// unless a --save-dir / UMBRAL_SAVE_DIR override was given.
static func dir() -> String:
	if _dir == null:
		var d := OS.get_environment("UMBRAL_SAVE_DIR")
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--save-dir="):
				d = a.trim_prefix("--save-dir=")
		if d == "":
			_dir = "user://"
		else:
			_dir = d if d.ends_with("/") else d + "/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	return String(_dir)


## `file` inside dir(), e.g. path("settings.cfg"); a per-slot file inside the current slot's folder.
static func path(file: String) -> String:
	if file == "savegame.cfg" or (file == "codex.cfg" and slot > 1):
		return slot_path(slot, file)
	return dir() + file


## `file` of save slot `n`: <dir>/slot_<n>/<file>. The folder is made.
static func slot_path(n: int, file: String) -> String:
	var d := dir() + "slot_%d/" % n
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	return d + file


## True when saves are redirected away from user:// (tests, tools).
static func redirected() -> bool:
	return dir() != "user://"

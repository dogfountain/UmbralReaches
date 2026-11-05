extends RefCounted
## Where the player's files live: user:// by default. Tests and tools point every save at a scratch
## folder instead, so they can never write Luke's savegame.cfg / settings.cfg / codex.cfg:
##   godot --path . res://zz/some_test.tscn -- --save-dir=/private/tmp/scratch_saves
## (or the env var UMBRAL_SAVE_DIR). Read by Travel (savegame.cfg), Settings (settings.cfg) and
## CodexStore (codex.cfg) when they start. No class_name: preload by path.
##   const SaveDir := preload("res://core/util/save_dir.gd")

static var _dir: Variant = null


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


## `file` inside dir(), e.g. path("savegame.cfg").
static func path(file: String) -> String:
	return dir() + file


## True when saves are redirected away from user:// (tests, tools).
static func redirected() -> bool:
	return dir() != "user://"

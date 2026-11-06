extends Node
## Loads every script listed in $GD_LIST (one res-relative path per line) inside the project, autoloads present,
## and prints COMPILE BAD for any that fail. The import grep does not compile every script; this does.
##   git diff --name-only <base> HEAD -- "*.gd" > /tmp/list; GD_LIST=/tmp/list godot --headless --path . res://zz/compile_check.tscn
func _ready() -> void:
	var list := FileAccess.get_file_as_string(OS.get_environment("GD_LIST")).split("\n", false)
	var bad := 0
	for f in list:
		var s := ResourceLoader.load("res://" + f, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if s == null or not s.can_instantiate():
			if s == null or s.reload() != OK:
				print("COMPILE BAD ", f)
				bad += 1
	print("COMPILE checked %d bad %d" % [list.size(), bad])
	get_tree().quit(0)

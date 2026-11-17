extends SceneTree
## Loads every GDScript in the shipping folders and the tests so each parse error shows in one run (the boot only
## loads what main.tscn reaches, so a merge can hide errors behind each other).
##   godot --headless --path . --script res://tools/parse_all.gd 2>&1 | grep -E "Parse Error|PARSE_ALL"

const ROOTS := ["res://autoload", "res://core", "res://ui", "res://world", "res://zz"]


func _initialize() -> void:
	var files: PackedStringArray = []
	for r: String in ROOTS:
		_walk(r, files)
	var bad := 0
	for f in files:
		var s: Variant = ResourceLoader.load(f, "GDScript", ResourceLoader.CACHE_MODE_REUSE)
		if s == null or not (s as GDScript).can_instantiate():
			bad += 1
			print("PARSE_ALL bad ", f)
	print("PARSE_ALL %d scripts, %d bad" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _walk(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)

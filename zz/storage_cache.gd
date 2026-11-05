extends Node
## GenCache housekeeping: size per generator, stale entries (generator edited or deleted since the
## entry was written), duplicate geometry. `--prune` deletes the stale entries (dev only).
##   godot --headless --path . res://zz/storage_cache.tscn [-- --prune]
const GenCache := preload("res://core/world/realm/gen_cache.gd")


func _ready() -> void:
	var prune := "--prune" in OS.get_cmdline_user_args()
	for dir: String in [GenCache.RES_DIR, GenCache.USER_DIR]:
		var r := GenCache.report(dir)
		print("CACHE %s  %d files  %.2f MB" % [dir, int(r.files), int(r.bytes) / 1048576.0])
		var rows: Dictionary = r.by_script
		for k: String in rows:
			print("  %-48s %4d files %7.2f MB" % [k, int(rows[k][0]), int(rows[k][1]) / 1048576.0])
		print("  stale: %d   duplicate geometry: %d" % [(r.stale as Array).size(), (r.dupes as Array).size()])
		for d: Array in r.dupes:
			print("    dupe %s == %s" % [d[0], d[1]])
		if prune and dir == GenCache.RES_DIR:
			print("  pruned %d stale entries" % GenCache.prune(dir))
	print("STORAGE_CACHE done")
	get_tree().quit()

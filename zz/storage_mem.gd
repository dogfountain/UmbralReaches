extends Node
## Storage probe: static memory and video memory at fixed points of the Realm, plus which asset
## files are actually loaded (ResourceLoader.has_cached, swept at every point) so unused-asset
## candidates rest on runtime evidence, not only on grep.
##   godot --path . res://zz/storage_mem.tscn [-- --out=/abs/path/report.txt]
## Windowed (video memory is 0 headless). Writes the real save on quit: back it up first.
const VIEWS := [
	["spawn", Vector3(0.0, 0.2, 24.0), 0.0, -0.06],
	["tavern", Vector3(12.0, -0.5, 27.0), -0.9, -0.08],
	["ossuary", Vector3(19.0, 4.0, -36.0), 0.0, -0.05],
	["summit", Vector3(0.0, 27.9, -92.0), 0.0, -0.05],
	["thornwood", Vector3(-80.0, 3.0, 10.0), 0.4, -0.02],
]
const SETTLE := 90
const ROOTS := ["res://art", "res://world", "res://assets", "res://ui", "res://core"]
const EXTS := ["png", "jpg", "jpeg", "webp", "exr", "hdr", "glb", "gltf", "wav", "ogg", "mp3", "res", "tres", "tscn", "ttf", "otf"]

var p: Player
var i := -1
var wait := 0
var out_path := ""
var lines: PackedStringArray = []
var assets: PackedStringArray = []
var seen := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 800)
	for r: String in ROOTS:
		_collect(r)
	_point("boot")
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _collect(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null or FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for sub in d.get_directories():
		if dir == "res://art" and sub == "realm_cache":
			continue
		_collect(dir.path_join(sub))
	for f in d.get_files():
		if f.get_extension().to_lower() in EXTS:
			assets.append(dir.path_join(f))


func _sweep() -> void:
	for a in assets:
		if not seen.has(a) and ResourceLoader.has_cached(a):
			seen[a] = true


func _point(label: String) -> void:
	_sweep()
	var l := "MEM %-10s static %7.1f MB  video %7.1f MB  textures %7.1f MB  buffers %7.1f MB  objects %d" % [label,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT))]
	print(l)
	lines.append(l)


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not p.get_parent().has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		if wait % 30 == 0:
			_sweep()
		return
	if i >= 0:
		_point(String(VIEWS[i][0]))
	i += 1
	if i >= VIEWS.size():
		_finish()
		return
	_hold()
	p.set_view(float(VIEWS[i][2]), float(VIEWS[i][3]))
	wait = SETTLE


func _hold() -> void:
	p.global_position = VIEWS[i][1]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _finish() -> void:
	_sweep()
	var unseen: PackedStringArray = []
	for a in assets:
		if not seen.has(a):
			unseen.append(a)
	# Every live GPU texture (what the editor's Video RAM tab lists), biggest first, grouped by source.
	var usage: Array = RenderingServer.texture_debug_usage()
	usage.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
	var total := 0
	var groups := {}
	for u: Dictionary in usage:
		total += int(u.bytes)
		var path := String(u.path)
		var g := "file" if path.begins_with("res://") else ("runtime" if path == "" else "other")
		groups[g] = int(groups.get(g, 0)) + int(u.bytes)
	lines.append("VRAM textures %d, %.1f MB: %s" % [usage.size(), total / 1048576.0, str(groups.keys().map(func(k: String) -> String: return "%s %.1f MB" % [k, int(groups[k]) / 1048576.0]))])
	for k in mini(40, usage.size()):
		var u: Dictionary = usage[k]
		lines.append("VRAM %7.2f MB  %dx%dx%d fmt %d  %s" % [int(u.bytes) / 1048576.0, int(u.width), int(u.height), int(u.depth), int(u.format), String(u.path) if String(u.path) != "" else "(runtime) " + str(u.get("type", ""))])
	lines.append("LOADED %d of %d asset files; never loaded during the tour:" % [seen.size(), assets.size()])
	for a in unseen:
		lines.append("UNSEEN " + a)
	lines.append("STORAGE_MEM done")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string("\n".join(lines) + "\n")
	print("STORAGE_MEM done (%d unseen)" % unseen.size())
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	OS.kill(OS.get_process_id())

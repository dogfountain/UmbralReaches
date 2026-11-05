extends Node
## Screenshots of the loading screen while it runs: godot --path . res://zz/loading_shot.tscn -- --loading
## -> shots/loading_<n>.png every 0.6 s until it lifts, then one of the game. Never writes the save.
var t := 0.0
var next := 0.3
var n := 0
var seen := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Settings.fullscreen = false
	Settings.monitor = -1
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	var ls := get_tree().root.find_child("LoadingScreen", true, false)
	if ls:
		seen = true
	if t >= next:
		next = t + 0.6
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/loading_%d.png" % n))
		n += 1
	if (seen and ls == null and t > 2.0) or t > 40.0:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/loading_after.png"))
		print("LOADING_SHOT %d frames" % n)
		get_tree().quit()

extends Node
## Runs another scene with Travel._busy held true every frame, so nothing it does writes the save:
##   godot --path . res://zz/char_wrap.tscn -- --scene=res://zz/move_course.tscn [its own args]


func _ready() -> void:
	Travel._busy = true
	get_tree().process_frame.connect(Travel.set.bind("_busy", true))
	get_tree().physics_frame.connect(Travel.set.bind("_busy", true))
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			path = a.trim_prefix("--scene=")
	if path == "":
		push_error("char_wrap: pass --scene=res://...")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file.call_deferred(path)

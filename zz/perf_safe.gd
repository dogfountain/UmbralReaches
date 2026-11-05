extends Node
## Runs another test/render scene with Travel saves blocked first (the lead's save rule), for tests
## that do not set Travel._busy themselves:
##   godot [--headless] --path . res://zz/perf_safe.tscn -- --run=res://zz/check.tscn [test args]
## (a test that travels can clear _busy itself; compare the save's checksum when it matters)


func _ready() -> void:
	Travel._busy = true
	var target := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--run="):
			target = a.trim_prefix("--run=")
	if target == "":
		push_error("perf_safe: pass --run=res://zz/<test>.tscn")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file.call_deferred(target)

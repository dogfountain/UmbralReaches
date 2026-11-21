extends Node
## Parse check: loads the scripts named after `--` (the autoloads are up in a scene run) and prints PARSE ok/FAIL.
func _ready() -> void:
	for p in OS.get_cmdline_user_args():
		var s := load(p) as GDScript
		print("PARSE ", p, " ", "OK" if s != null else "FAIL")
	get_tree().quit()

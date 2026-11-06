extends SceneTree
## Saves the shared menu Theme for the editor: godot --headless --path . --script tools/bake_ui_theme.gd
## (the game builds the same Theme in code from ui/medieval_style.gd; this file is for scenes and other agents).
func _init() -> void:
	var med: GDScript = load("res://ui/medieval_style.gd")
	var t: Theme = med.call("theme")
	print("theme saved: ", ResourceSaver.save(t, "res://ui/medieval_theme.tres"))
	quit()

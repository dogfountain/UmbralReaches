extends Node
func _ready() -> void:
	var bad := 0
	var stack := ["res://autoload", "res://core", "res://ui", "res://world", "res://tools"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s := load(d + "/" + f) as GDScript
				if s == null or not s.can_instantiate():
					print("BAD ", d + "/" + f)
					bad += 1
	print("CHECK DONE bad=", bad)
	get_tree().quit()

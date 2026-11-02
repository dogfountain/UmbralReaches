extends SceneTree


func _initialize() -> void:
	var packed: PackedScene = load("res://core/player/magic_bolt.tscn")
	if packed == null:
		push_error("SMOKE missing magic_bolt.tscn")
		quit(1)
		return
	var bolt: Node = packed.instantiate()
	root.add_child(bolt)
	print("SMOKE bolt=", bolt.get_class(), " name=", bolt.name)
	quit(0)

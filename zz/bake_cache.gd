extends Node
## Bake the shipped Realm cache: `godot --headless --path . res://zz/bake_cache.tscn -- --bake-cache` (a clean HOME).
## Loads the night, waits for the Realm to finish building (every generator has written its entries), then quits.
var main: Node
var after := 0
func _ready() -> void:
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	add_child(main)
func _process(_d: float) -> void:
	if not main.has_meta("realm_done"):
		return
	after += 1
	if after == 300:
		print("BAKE realm built; cache written")
		get_tree().quit()

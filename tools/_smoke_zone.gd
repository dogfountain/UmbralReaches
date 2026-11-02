extends SceneTree
## Headless boot of the stair. Confirms sky flare and canopy fill, then quits.


func _initialize() -> void:
	var packed: PackedScene = load("res://world/main.tscn")
	if packed == null:
		push_error("SMOKE missing main.tscn")
		quit(1)
		return
	var zone: Node = packed.instantiate()
	root.add_child(zone)
	call_deferred("_check", zone)


func _check(zone: Node) -> void:
	var flare := zone.get_node_or_null("SkyFlare")
	var fill := zone.find_child("CanopyFill", true, false)
	var fill2 := zone.find_child("CanopyFill2", true, false)
	print("SMOKE flare=%s fill=%s fill2=%s" % [flare != null, fill != null, fill2 != null])
	quit(0 if flare != null and fill != null else 1)

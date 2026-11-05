extends Node
## Floor heights across the Ossuary pit (trailer boss staging): rays from y 9 down to y 0.
var main: Node
func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(2.0).timeout
	var sp := (main as Node3D).get_world_3d().direct_space_state
	for z in range(-96, -73, 2):
		var row := "PIT z=%d " % z
		for x in range(6, 27, 2):
			var h := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 9.0, z), Vector3(x, 0.0, z), Layers.WORLD))
			row += ("%5.1f" % (h.position as Vector3).y) if not h.is_empty() else "    -"
		print(row)
	get_tree().quit()

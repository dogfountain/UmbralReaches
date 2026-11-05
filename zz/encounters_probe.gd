extends Node
## Encounters: why a candidate point is or is not usable (haunts, bells, posts).
##   godot --headless --path . res://zz/encounters_probe.tscn -- --fresh --pts=x,z;x,z;...
var main: Node
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()
func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	for i in 5: await get_tree().physics_frame
	var d := main.get_node("Encounters")
	var pts: Array[Vector2] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pts="):
			for s in a.trim_prefix("--pts=").split(";"):
				pts.append(Vector2(float(s.split(",")[0]), float(s.split(",")[1])))
	var space := (main as Node3D).get_world_3d().direct_space_state
	for c in pts:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, 90, c.y), Vector3(c.x, -50, c.y), Layers.WORLD))
		var why := ""
		if hit.is_empty():
			why = "no hit"
		else:
			var at: Vector3 = hit.position
			why = "hit %s y %.2f n.y %.2f by %s" % [at.snapped(Vector3.ONE * 0.1), at.y, (hit.normal as Vector3).y, (hit.collider as Node).name]
			var sq := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
			sq.shape = cap
			sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.95, 0))
			sq.collision_mask = Layers.WORLD
			var ov := space.intersect_shape(sq, 4)
			var names := []
			for o in ov: names.append((o.collider as Node).name)
			why += " overlap %s" % [names]
			why += " site '%s'" % [WorldLanes.site_at(Vector2(at.x, at.z), 0.8).get("name", "")]
			why += " lit %s haven %s water %s ok %s" % [LightGrid.repel(at, 4.0) != Vector3.ZERO, d.call("_in_haven", at), load("res://core/world/realm/realm_land.gd").in_water(at.x, at.z), d.call("spot_ok", at)]
		print("PROBE ", c, " ", why)
	get_tree().quit()

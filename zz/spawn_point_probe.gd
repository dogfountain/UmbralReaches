extends Node
## Why a point passes or fails the spawn rules: the floor, the rules' verdict, what overlaps a body standing there.
##   godot --headless --path . res://zz/spawn_point_probe.tscn -- --pts=x,z;x,z;...
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
var main: Node
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()
func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	for i in 5: await get_tree().physics_frame
	var pts: Array[Vector2] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pts="):
			for s in a.trim_prefix("--pts=").split(";"):
				pts.append(Vector2(float(s.split(",")[0]), float(s.split(",")[1])))
	var space := (main as Node3D).get_world_3d().direct_space_state
	for c in pts:
		var g := SpawnRules.floor_at(space, c)
		var a := SpawnRules.assess(space, g)
		print("PT ", c, " floor ", g, " site ", WorldLanes.site_at(c, 1.0).get("name", "-"), " lit ", LightGrid.is_lit(g) if g != Vector3.INF else false, " ", a)
		var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
		var sq := PhysicsShapeQueryParameters3D.new(); sq.shape = cap; sq.collision_mask = Layers.WORLD
		sq.transform = Transform3D(Basis.IDENTITY, g + Vector3(0, 0.97, 0))
		for o in space.intersect_shape(sq, 6):
			var n := o.collider as Node
			print("   overlaps ", n.get_path(), " ", n.get_class(), " shape ", o.shape)
			var rest := space.get_rest_info(sq)
			print("   rest ", rest)
		var line := "   heights:"
		for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x + dx, g.y + 5, c.y), Vector3(c.x + dx, g.y - 5, c.y), Layers.WORLD))
			line += " %.2f" % ((h.position as Vector3).y if h else NAN)
		print(line)
	get_tree().quit()

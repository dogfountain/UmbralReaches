extends Node
const RoadLore := preload("res://core/world/realm/lore/road.gd")
## The boom through the west March Wall gate (Pilgrims' Road, z 62, x about -145): stands the wanderer along the road facing
## west and prints the camera's boom length at each step; with --shot it also saves the frame.
##   godot --path . res://zz/cam_gate.tscn -- --out=<dir> [--tag=x]   -> "GATE x=.. boom=.." and shots
var main: Node
var p: Player
var out := "/tmp"
var tag := "x"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	await get_tree().create_timer(3.0, true, false, true).timeout
	DirAccess.make_dir_recursive_absolute(out)
	var x := -134.0
	var i := 0
	while x > -159.0:
		var zr := float((RoadLore.road_at(x)[0] as Vector2).y) if not "--z62" in OS.get_cmdline_user_args() else 62.0
		var y := RealmLayout.ground(p.get_world_3d().direct_space_state, x, zr) + 0.15
		p.global_position = Vector3(x, y, zr)
		p.velocity = Vector3.ZERO
		p._yaw = PI * 0.5
		for k in 40:
			await get_tree().physics_frame
		await get_tree().process_frame
		print("GATE x=%.1f z=%.1f boom=%.2f" % [x, zr, p.camera_ctl._cam_len])
		var sp := p.get_world_3d().direct_space_state
		var o: Vector3 = p._arm.global_position
		var pq := PhysicsPointQueryParameters3D.new()
		pq.position = o
		pq.collision_mask = Layers.WORLD
		var ins := sp.intersect_point(pq, 3)
		var rq := PhysicsRayQueryParameters3D.create(o, o + p._arm.global_basis.z.normalized() * 4.0, Layers.WORLD, [p.get_rid()])
		var h := sp.intersect_ray(rq)
		if p.camera_ctl._cam_len < 2.0:
			print("GATE   arm origin %s player %s" % [str(o), str(p.global_position)])
			for dn: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var r2 := PhysicsRayQueryParameters3D.create(o, o + dn * 6.0, Layers.WORLD, [p.get_rid()])
				var h2 := sp.intersect_ray(r2)
				print("GATE   ray %s -> %s" % [str(dn), (str(h2.position) + " n " + str(h2.normal)) if not h2.is_empty() else "none"])
			print("GATE   road_at %s" % str(RoadLore.road_at(x)))
			print("GATE   arm inside %s ; boom ray hits %s" % [str(ins[0].collider.get_path()) if ins.size() > 0 else "-", str(h.collider.get_path()) + "@" + str(o.distance_to(h.position)) if not h.is_empty() else "none"])
		if i % 3 == 0:
			get_viewport().get_texture().get_image().save_png("%s/gate_%s_%d.png" % [out, tag, int(-x)])
		x -= 1.0
		i += 1
	get_tree().quit()

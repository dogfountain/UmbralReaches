extends Node
## The ambush planner's view of points on the ways: its features and score there, and the trees round it.
##   godot --headless --path . res://zz/ambush_probe.tscn -- --pts=x,z;x,z;...
const AmbushSites := preload("res://core/life/encounters/ambush_sites.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
var main: Node
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()
func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	for i in 5: await get_tree().physics_frame
	print("AMBPROBE trees in the flora list: ", Flora.trees.size())
	var space := (main as Node3D).get_world_3d().direct_space_state
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pts="):
			for s in a.trim_prefix("--pts=").split(";"):
				var p := Vector2(float(s.split(",")[0]), float(s.split(",")[1]))
				var f := AmbushSites.features(space, p, p + Vector2(0, -12), p + Vector2(0, 12))
				var n := 0
				var near := 99.0
				for tr: Array in Flora.trees:
					var d := Vector2((tr[0] as Vector3).x, (tr[0] as Vector3).z).distance_to(p)
					near = minf(near, d)
					if d < 12.0:
						n += 1
				print("AMBPROBE ", p, " way ", snappedf(RealmLayout.path_dist(p), 0.1), " biome ", RealmLayout.biome_at(p.x, p.y), " trees<12 ", n, " nearest ", snappedf(near, 0.1), " ", f)
	get_tree().quit()

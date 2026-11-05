extends Node
## Per-tree worst gap under the trunk's bottom ring (not the averaged base): a trunk on a slope can
## sit on its uphill side and hang in the air on the downhill side.
##   godot --headless --path . res://zz/trunk_gaps.tscn [-- --only=x0,z0,x1,z1]  ->  "TRUNKS floating=N"
const TOL := 0.25
var f := 0
var area := Rect2(-80, -140, 160, 200)
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var v := a.trim_prefix("--only=").split(",")
			area = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	f += 1
	if f != 200: return
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1) as Node3D
	var space := root.get_world_3d().direct_space_state
	var total := 0
	for path: String in ["Zone/Forest/GiantTrunks", "Zone/DeadTrees", "Zone/Boulders", "Zone/Ruins"]:
		var mi := root.get_node_or_null(path) as MeshInstance3D
		if mi == null or mi.mesh == null: continue
		var xf := mi.global_transform
		var n := 0
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size(): idx[i] = i
			var pc: Array = SeatProps.pieces(verts, idx, xf)
			var piece: PackedInt32Array = pc[0]
			var info: Dictionary = pc[1]
			var worst := {}
			var used := {}
			for t in idx: used[t] = true
			for vi: int in used:
				var r := piece[vi]
				if r < 0: continue
				var bb: AABB = info[r][0]
				var w := xf * verts[vi]
				if w.y > bb.position.y + 0.6 or not area.has_point(Vector2(w.x, w.z)): continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(w + Vector3.DOWN * 0.02, w + Vector3.DOWN * 12.0, Layers.WORLD))
				if hit.is_empty() or not String((hit.collider as Node).name).contains("Terrain"): continue
				var gap: float = w.y - (hit.position as Vector3).y
				if gap > float(worst.get(r, [0.0])[0]): worst[r] = [gap, w]
			for r: int in worst:
				if float(worst[r][0]) > TOL:
					n += 1
					if n <= 12: print("  ", path, " gap %.2f at %s (tree h %.1f)" % [worst[r][0], (worst[r][1] as Vector3).snapped(Vector3.ONE * 0.1), (info[r][0] as AABB).size.y])
		if n > 0: print("FLOAT ", path, " ", n)
		total += n
	print("TRUNKS floating=%d" % total)
	get_tree().quit()

extends Node
## Floating / buried baked props after terracing (headless is fine: meshes, not MultiMeshes).
## Every baked prop mesh under Zone is split into pieces (each tree, rock, ruin stone); a piece
## floats when the ground under its footprint centre is more than TOL below its lowest point and
## nothing else is under it. Lanterns, braziers, menhirs and gates are checked by their origin.
##   godot --headless --path . res://zz/prop_audit.tscn  ->  "PROPS floating=N buried=M"
const TOL := 0.45
const MESHES := ["Zone/Ruins", "Zone/Boulders", "Zone/DeadTrees", "Zone/Forest/GiantTrunks", "Zone/RiftCrystals", "Zone/Ring"]
var f := 0
var _orphans := 0


func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	f += 1
	if f != 200:
		return
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1) as Node3D
	var space := root.get_world_3d().direct_space_state
	var floating := 0
	var buried := 0
	for path: String in MESHES:
		var mi := root.get_node_or_null(path) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var n := 0
		var worst := 0.0
		var at := Vector3.ZERO
		var all := islands(mi)
		for isl: Array in all:
			var bb: AABB = isl[0]
			var base: Vector3 = isl[1]
			var held := false                    # a knot inside a larger part's bounds (a crown)
			for o: Array in all:
				var ob: AABB = o[0]
				if ob.size.length() > 2.5 and ob != bb and ob.grow(0.3).has_point(base):
					held = true
					break
			if held:
				continue
			# from just under the island's lowest point, so its own collision is not what we hit
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3.DOWN * 0.05, base + Vector3.DOWN * 30.0, Layers.WORLD))
			if hit.is_empty():
				continue
			var gap: float = base.y - (hit.position as Vector3).y
			gap += 0.05
			if gap > TOL and String((hit.collider as Node).name).contains("Terrain"):
				print("    float ", path, " base ", base.snapped(Vector3.ONE * 0.1), " box ", bb.size.snapped(Vector3.ONE * 0.1), " gap ", snappedf(gap, 0.01))
				n += 1
				if gap > worst: worst = gap; at = base
			elif _ground_above(space, bb) > 0.6:
				buried += 1
		if n > 0:
			print("  FLOAT %s islands=%d worst=%.2f m at %s" % [path, n, worst, at.snapped(Vector3.ONE * 0.1)])
		floating += n
	# canopy crowns: each needs a trunk piece under it reaching to within 3 m of its underside
	var trunks_mi := root.get_node_or_null("Zone/Forest/GiantTrunks") as MeshInstance3D
	for canopy_path: String in ["Zone/Forest/Canopy", "Zone/Forest/CanopyFill"]:
		_crowns(root.get_node_or_null(canopy_path) as MeshInstance3D, trunks_mi, canopy_path)
	floating += _orphans
	for node in root.find_children("*", "Node3D", true, false):
		var p := String(node.get_parent().name) if node.get_parent() else ""
		var nm := String(node.name)
		if not (p in ["Lanterns", "Braziers"] or nm.begins_with("Menhir") or nm.ends_with("Mirror")):
			continue
		var o: Vector3 = (node as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 0.3, o + Vector3.DOWN * 30.0, Layers.WORLD, [] as Array[RID]))
		if hit and String((hit.collider as Node).name).contains("Terrain") and o.y - (hit.position as Vector3).y > TOL:
			floating += 1
			print("  FLOAT %s %.2f m at %s" % [root.get_path_to(node), o.y - (hit.position as Vector3).y, o.snapped(Vector3.ONE * 0.1)])
	print("PROPS floating=%d buried=%d" % [floating, buried])
	get_tree().quit()


func _ground_above(space: PhysicsDirectSpaceState3D, bb: AABB) -> float:
	var top := bb.get_center() + Vector3.UP * (bb.size.y * 0.5)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3.UP * 40.0, top, Layers.WORLD))
	if hit and String((hit.collider as Node).name).contains("Terrain"):
		return (hit.position as Vector3).y - top.y
	return 0.0


## [AABB, base point] per piece (one tree, rock, ruin stone), as SeatProps groups them.
static func islands(mi: MeshInstance3D) -> Array:
	var out: Array = []
	for si in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		out.append_array((SeatProps.pieces(verts, idx, mi.global_transform)[1] as Dictionary).values())
	return out


func _crowns(canopy: MeshInstance3D, trunks_mi: MeshInstance3D, label: String) -> void:
	if canopy == null or canopy.mesh == null or trunks_mi == null or trunks_mi.mesh == null:
		return
	var trunks := islands(trunks_mi)
	var orphans := 0
	var worst_at := Vector3.ZERO
	for crown: Array in islands(canopy):
		var cb: AABB = crown[0]
		var c := cb.get_center()
		var held := false
		for t: Array in trunks:
			var tb: AABB = t[0]
			if tb.grow(1.0).has_point(Vector3(c.x, tb.get_center().y, c.z)) and tb.end.y > cb.position.y - 3.0:
				held = true
				break
		if not held:
			orphans += 1
			worst_at = c
	if orphans > 0:
		print("  FLOAT %s crowns with no trunk under them=%d e.g. at %s" % [label, orphans, worst_at.snapped(Vector3.ONE * 0.1)])
	_orphans += orphans

class_name NightDress
extends RefCounted
## Runtime dark-fantasy set dressing for Stair. Adds branch cards, hanging moss,
## twisted roots, fallen limbs, rune slabs, and cairns without rebaking main.tscn.

const ROOT_GLB := "res://art/models/twisted_root.glb"
const BRANCH_GLB := "res://art/models/fallen_branch.glb"
const RUNE_GLB := "res://art/models/rune_slab.glb"
const CAIRN_GLB := "res://art/models/cairn.glb"
const Check := preload("res://core/debug/check.gd")


static func dress(root: Node) -> void:
	if root == null or root.has_meta("night_dressed"):
		return
	root.set_meta("night_dressed", true)
	var holder := Node3D.new()
	holder.name = "NightDress"
	root.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var ground_hits := _sample_ground(root, rng, 28)
	_scatter_props(holder, ground_hits, rng)
	_scatter_cards(holder, root, rng)
	print("NIGHT_DRESS props+cards on ", holder.get_child_count(), " nodes")


static func _scatter_props(holder: Node3D, hits: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	if hits.is_empty():
		return
	var bags: Array = [
		{"path": ROOT_GLB, "n": 5, "sc": Vector2(0.85, 1.35), "y": 0.0},
		{"path": BRANCH_GLB, "n": 7, "sc": Vector2(0.7, 1.25), "y": 0.0},
		{"path": RUNE_GLB, "n": 4, "sc": Vector2(0.8, 1.15), "y": 0.0},
		{"path": CAIRN_GLB, "n": 4, "sc": Vector2(0.75, 1.2), "y": 0.0},
	]
	var idx := 0
	for bag in bags:
		if Check.res(bag.path, PackedScene) == null:
			continue
		for _i in int(bag.n):
			if idx >= hits.size():
				break
			var p: Vector3 = hits[idx]
			idx += 1
			# Keep the stair corridor clear.
			if absf(p.x) < 2.4 and p.z > -8.0 and p.z < 55.0:
				continue
			var model := Check.attach_glb(holder, bag.path, "%s_%d" % [String(bag.path).get_file().get_basename(), idx])
			if model == null:
				continue
			var sc := rng.randf_range(bag.sc.x, bag.sc.y)
			model.global_position = p + Vector3(0.0, bag.y, 0.0)
			model.scale = Vector3.ONE * sc
			model.rotation.y = rng.randf() * TAU
			model.rotation.x = rng.randf_range(-0.08, 0.08)
			model.rotation.z = rng.randf_range(-0.06, 0.06)
			# the old point test kept roots whose limbs sprawled across the stair: test the mesh bounds
			var lane := WorldLanes.intrudes(holder.get_world_3d().direct_space_state, WorldLanes.bounds(model))
			if lane != "":
				model.get_parent().remove_child(model)
				model.free()
				continue
			for gi in model.find_children("*", "GeometryInstance3D", true, false):
				var g := gi as GeometryInstance3D
				g.visibility_range_end = 42.0
				g.visibility_range_end_margin = 8.0
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _scatter_cards(holder: Node3D, root: Node, rng: RandomNumberGenerator) -> void:
	var branch_mat := load("res://art/materials/branch.tres") as Material
	var moss_mat := load("res://art/materials/moss_hang.tres") as Material
	if branch_mat == null or moss_mat == null:
		push_error("NIGHT_DRESS missing branch/moss materials")
		return
	var branch_mesh := _card_mesh(Vector2(1.35, 1.55), false)
	var moss_mesh := _card_mesh(Vector2(0.55, 1.45), true)
	var trunk_pts := _trunk_anchors(root, rng, 18)
	print("NIGHT_DRESS cards on %d real trunks" % trunk_pts.size())
	var space := (root as Node3D).get_world_3d().direct_space_state
	_mmi(holder, "DeadBranches", branch_mesh, branch_mat, _clear_of_lanes(space, branch_mesh, _branch_xforms(trunk_pts, rng)), 48.0)
	_mmi(holder, "HangingMoss", moss_mesh, moss_mat, _clear_of_lanes(space, moss_mesh, _moss_xforms(trunk_pts, rng)), 40.0)
	# Extra branch cards on the forest floor edge for crunchy undergrowth silhouette.
	var floor_hits := _sample_ground(root, rng, 16)
	var under: Array[Transform3D] = []
	for p in floor_hits:
		if absf(p.x) < 3.0:
			continue
		var xf := Transform3D.IDENTITY
		xf.origin = p + Vector3(0.0, 0.55, 0.0)
		xf.basis = Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
		xf.basis = xf.basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.15))
		if WorldLanes.intrudes((root as Node3D).get_world_3d().direct_space_state, xf * branch_mesh.get_aabb()) != "":
			continue
		under.append(xf)
	_mmi(holder, "FloorTwigs", branch_mesh, branch_mat, under, 36.0)


static func _clear_of_lanes(space: PhysicsDirectSpaceState3D, mesh: Mesh, xforms: Array) -> Array:
	var out: Array = []
	for xf: Transform3D in xforms:
		if WorldLanes.intrudes(space, xf * mesh.get_aabb()) == "":
			out.append(xf)
	return out


static func _card_mesh(size: Vector2, hang: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	# Foliage wind sways UV.y→0. Hang cards put tips at UV.y=0 so strands flutter.
	var uv_top := 1.0 if hang else 0.0
	var uv_bot := 0.0 if hang else 1.0
	for yaw in [0.0, PI * 0.5]:
		var c := cos(yaw)
		var s := sin(yaw)
		var v0 := Vector3(-hx * c, -hy, -hx * s)
		var v1 := Vector3(hx * c, -hy, hx * s)
		var v2 := Vector3(hx * c, hy, hx * s)
		var v3 := Vector3(-hx * c, hy, -hx * s)
		st.set_uv(Vector2(0, uv_bot)); st.add_vertex(v0)
		st.set_uv(Vector2(1, uv_bot)); st.add_vertex(v1)
		st.set_uv(Vector2(1, uv_top)); st.add_vertex(v2)
		st.set_uv(Vector2(0, uv_bot)); st.add_vertex(v0)
		st.set_uv(Vector2(1, uv_top)); st.add_vertex(v2)
		st.set_uv(Vector2(0, uv_top)); st.add_vertex(v3)
	st.generate_normals()
	return st.commit()


static func _mmi(parent: Node, n_name: String, mesh: Mesh, mat: Material, xforms: Array, fade: float) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var box := AABB((xforms[0] as Transform3D).origin, Vector3.ZERO)
	for i in xforms.size():
		var xf: Transform3D = xforms[i]
		mm.set_instance_transform(i, xf)
		box = box.expand(xf.origin)
	mm.custom_aabb = box.grow(4.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = fade
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)


static func _branch_xforms(anchors: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for t: Array in anchors:
		var foot: Vector3 = t[0]
		var r: float = t[1]
		var h: float = t[2]
		for _k in rng.randi_range(1, 2):
			var yaw := rng.randf() * TAU
			var xf := Transform3D.IDENTITY
			# rooted in the bark, reaching out: the card's centre half its width off the trunk
			xf.origin = foot + Vector3(cos(yaw) * (r + 0.45), rng.randf_range(1.2, minf(4.5, h * 0.7)), sin(yaw) * (r + 0.45))
			xf.basis = Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.3), -yaw, rng.randf_range(-0.35, 0.35)))
			xf.basis = xf.basis.scaled(Vector3.ONE * rng.randf_range(0.85, 1.4))
			out.append(xf)
	return out


static func _moss_xforms(anchors: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for t: Array in anchors:
		var foot: Vector3 = t[0]
		var r: float = t[1]
		var h: float = t[2]
		for _k in rng.randi_range(2, 4):
			var xf := Transform3D.IDENTITY
			var yaw := rng.randf() * TAU
			# draped on the bark, its top above the ground by at least its own length
			xf.origin = foot + Vector3(cos(yaw) * (r + 0.05), rng.randf_range(1.6, minf(5.2, h * 0.8)), sin(yaw) * (r + 0.05))
			xf.basis = Basis.from_euler(Vector3(0.15, -yaw + PI * 0.5, 0.0))
			xf.basis = xf.basis.scaled(Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.9, 1.5), 1.0))
			out.append(xf)
	return out


## Real trunks to hang branch and moss cards on: [foot, radius, height] per tree, from the trunk
## island of each piece (SeatProps.pieces) of GiantTrunks and DeadTrees, nearest the walked
## middle of the hub first. (This used to pick random points inside the meshes' whole bounding
## box at its lowest y, so every card hung in open air with no tree under it.)
static func _trunk_anchors(root: Node, rng: RandomNumberGenerator, want: int) -> Array:
	var trees: Array = []
	for path in ["Zone/Forest/GiantTrunks", "Zone/DeadTrees"]:
		var mi := root.get_node_or_null(path) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			var pc: Array = SeatProps.pieces(verts, idx, mi.global_transform)
			var ibox: Dictionary = pc[2]
			var ipiece: Dictionary = pc[3]
			for c: int in ibox:
				if int(ipiece[c]) != c:
					continue                    # roots only: the trunk, not its branches
				var bb: AABB = ibox[c]
				if bb.size.y < 3.0:
					continue                    # a stump or log, nothing to hang from
				var foot: Vector3 = (pc[1][c] as Array)[1]
				if absf(foot.x) > 40.0 or foot.z < -20.0 or foot.z > 64.0:
					continue
				var r := clampf(minf(bb.size.x, bb.size.z) * 0.5, 0.15, 1.6)
				trees.append([foot, r, bb.size.y])
	trees.sort_custom(func(a: Array, b: Array) -> bool: return Vector2((a[0] as Vector3).x, (a[0] as Vector3).z - 22.0).length() < Vector2((b[0] as Vector3).x, (b[0] as Vector3).z - 22.0).length())
	var out: Array = []
	var step := maxi(1, trees.size() / maxi(want, 1))
	var i := rng.randi_range(0, step - 1)
	while i < trees.size() and out.size() < want:
		out.append(trees[i])
		i += step
	return out


static func _sample_ground(root: Node, rng: RandomNumberGenerator, want: int) -> PackedVector3Array:
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else null
	var out := PackedVector3Array()
	if space == null:
		return out
	var tries := 0
	while out.size() < want and tries < want * 14:
		tries += 1
		var x := rng.randf_range(-28.0, 28.0)
		var z := rng.randf_range(-18.0, 62.0)
		if absf(x) < 2.2 and z > -6.0 and z < 50.0:
			continue
		var from := Vector3(x, 40.0, z)
		var to := Vector3(x, -8.0, z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1  # Layers.WORLD
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if n.y < 0.55:
			continue
		out.append(hit.position)
	return out

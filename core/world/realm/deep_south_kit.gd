extends RefCounted
## The Deep South's models (tools/blender/reach_south.py) as kits: a glb holds several pieces side by side at its origin,
## each a set of `<Piece>__<set>` meshes, a `<Piece>_Far__<set>` silhouette and a `<Piece>` collision body. A piece is
## placed by reading its meshes once and instancing them wherever a bay, a pier course or a stack is wanted (the
## shared meshes), or, with a `batch` array, collected and merged per set into a few spatial chunks (merge()): a
## hundred courses then cost a handful of draws. Dressed with the West Marches tiling sets (west_marches_kit.gd mat()).
## Load by path.

const WestKit := preload("res://core/world/realm/west_marches_kit.gd")
const M := "res://art/models/"

static var _cache := {}          ## file -> {"pieces": {name -> {"meshes": [[Mesh, set]], "shape": [Shape3D], "layer", "mask"}}}


static func release() -> void:
	_cache.clear()


static func _load(file: String) -> Dictionary:
	if _cache.has(file):
		return _cache[file]
	var ps := load(M + file) as PackedScene
	var out := {"pieces": {}}
	if ps == null:
		push_warning("deep_south_kit: no %s" % file)
		_cache[file] = out
		return out
	var root := ps.instantiate()
	var pieces: Dictionary = out.pieces
	for n in root.get_children():
		var nm := String(n.name)
		if n is MeshInstance3D:
			var parts := nm.split("__")
			if parts.size() < 2:
				continue
			var pn := parts[0]
			var set_name := parts[1].get_slice("_", 0)
			if not pieces.has(pn):
				pieces[pn] = {"meshes": [], "shape": [], "layer": 1, "mask": 0}
			(pieces[pn].meshes as Array).append([(n as MeshInstance3D).mesh, set_name])
		elif n is StaticBody3D:
			if not pieces.has(nm):
				pieces[nm] = {"meshes": [], "shape": [], "layer": 1, "mask": 0}
			pieces[nm].layer = (n as StaticBody3D).collision_layer
			pieces[nm].mask = (n as StaticBody3D).collision_mask
			for c in n.get_children():
				if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
					(pieces[nm].shape as Array).append((c as CollisionShape3D).shape)
	root.free()                      # the meshes and shapes are resources: they outlive the scene
	_cache[file] = out
	return out


static func has_piece(file: String, piece: String) -> bool:
	return _load(file).pieces.has(piece)


## Instance `piece` under `parent` at the world transform `xf`: a Node3D with a MeshInstance3D per set (`vis_end` m, 0 =
## never) and a StaticBody3D with the piece's collision (when `collide`). Returns the Node3D (null if the piece is missing).
static func add(parent: Node3D, file: String, piece: String, xf: Transform3D, vis_end := 0.0, collide := true, shadow := true, batch: Variant = null) -> Node3D:
	var pc: Dictionary = _load(file).pieces.get(piece, {})
	if pc.is_empty():
		return null
	var host := Node3D.new()
	host.name = piece
	parent.add_child(host)
	host.global_transform = xf
	for pair: Array in pc.meshes:
		if batch is Array:
			(batch as Array).append([pair[0], pair[1], xf])
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		var sn: String = pair[1]
		mi.material_override = WestKit.mat(sn)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_end_margin = vis_end * 0.1
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mi)
	if collide and not (pc.shape as Array).is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = int(pc.layer)
		body.collision_mask = int(pc.mask)
		for sh: Shape3D in pc.shape:
			var cs := CollisionShape3D.new()
			cs.shape = sh
			body.add_child(cs)
		host.add_child(body)
	return host


## A merged far mesh (one surface of vertex colour) from `items`: [[file, piece, Transform3D (relative to the host)]]
## using each piece's `<piece>_Far` meshes, and [[null, AABB-hull Mesh, Transform3D]] for plain boxes.
static func far_merged(items: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it: Array in items:
		var xf: Transform3D = it[2]
		if it[0] == null:
			st.append_from(it[1] as Mesh, 0, xf)
			continue
		var pc: Dictionary = _load(String(it[0])).pieces.get(String(it[1]) + "_Far", {})
		for pair: Array in pc.get("meshes", []):
			var m: Mesh = pair[0]
			for s in m.get_surface_count():
				st.append_from(m, s, xf)
	var out := st.commit()
	if out.get_surface_count() > 0:
		out.surface_set_material(0, FarDetail.far_material())
	return out


## The collected pieces (add(..., batch)) merged: one MeshInstance3D per set per `cell` metres along x, under `parent`
## (world transforms), each with its own visibility range. Returns the draws made.
static func merge(parent: Node3D, batch: Array, cell: float, vis_end: float, shadow := true) -> int:
	var groups := {}
	for it: Array in batch:
		var xf: Transform3D = it[2]
		var key := "%s|%d" % [String(it[1]), floori(xf.origin.x / cell)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(it)
	var made := 0
	for key: String in groups:
		var list: Array = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var centre := Vector3.ZERO
		for it: Array in list:
			centre += (it[2] as Transform3D).origin
		centre /= float(list.size())
		var to_local := Transform3D(Basis.IDENTITY, -centre)
		for it: Array in list:
			var m: Mesh = it[0]
			for si in m.get_surface_count():
				st.append_from(m, si, to_local * (it[2] as Transform3D))
		var mi := MeshInstance3D.new()
		mi.name = "Merged_" + key.replace("|", "_")
		mi.mesh = st.commit()
		mi.material_override = WestKit.mat(key.get_slice("|", 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_end_margin = vis_end * 0.1
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mi.add_to_group(Groups.CULL_SKIP)
		parent.add_child(mi)
		mi.global_position = centre
		made += 1
	return made

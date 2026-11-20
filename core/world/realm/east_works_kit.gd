extends RefCounted
## Placing the East Marches' modelled pieces (art/models/r37e_*.glb) at building scale: a mesh by name, an instance
## or a MultiMesh of it, and its collision from the generated box tables, all at a uniform scale `k` about the
## piece's origin (the Saltmarket houses are the old hamlet models at 1.5x, the works' sheds are modelled at size).
## Used by realm_pois_east_works.gd and realm_pois_east_saltmarket.gd. Load by path (no class_name).

const SiteProps := preload("res://core/world/realm/site_props.gd")
static var _meshes := {}
static var _win_mat: StandardMaterial3D = null


static func release() -> void:
	_meshes.clear()
	_win_mat = null
	_stack_parts.clear()


## A lit window: warm and low (under the bloom threshold; the hearth is behind it).
static func _window_mat() -> StandardMaterial3D:
	if _win_mat == null:
		_win_mat = StandardMaterial3D.new()
		_win_mat.albedo_color = Color(0.9, 0.6, 0.3)
		_win_mat.emission_enabled = true
		_win_mat.emission = Color(1.0, 0.62, 0.28)
		_win_mat.emission_energy_multiplier = 0.4
		_win_mat.roughness = 0.4
	return _win_mat


## One mesh of a kit GLB. The art wave's textures are night values (the lore kit lifts them): lifted here too.
static func mesh(path: String, nm: String) -> Mesh:
	var key := path + "#" + nm
	if _meshes.has(key):
		return _meshes[key]
	var out: Mesh = null
	var ps := load(path) as PackedScene
	if ps:
		var inst := ps.instantiate()
		var mi := inst.find_child(nm, true, false) as MeshInstance3D
		if mi:
			out = mi.mesh
			for i in out.get_surface_count():
				var sm := out.surface_get_material(i) as StandardMaterial3D
				if sm != null and sm.albedo_texture != null:
					var m2 := sm.duplicate() as StandardMaterial3D
					m2.albedo_color = Color(1.2, 1.3, 1.45) if sm.resource_name == "plaster" else Color(1.55, 1.5, 1.45)
					# The hamlet's slate (tavern_slate, mean value 24 of 255) and beams (25) stayed black under the moon even
					# lifted 1.55x (a flat black roof slab): they take the west kit's slate and timber albedo (value 71 and 86)
					if sm.resource_name == "slate":
						m2.albedo_texture = load("res://art/textures/r37_slate_albedo.png")
						m2.albedo_color = Color(0.95, 0.95, 1.0)
					elif sm.resource_name == "timber":
						m2.albedo_texture = load("res://art/textures/r37_timber_albedo.png")
						m2.albedo_color = Color(1.1, 1.08, 1.05)
					out.surface_set_material(i, m2)
		inst.free()
	_meshes[key] = out
	return out


## A transform at `p`, turned `yaw` about up, uniformly `k` times its size.
static func xf(p: Vector3, yaw: float, k := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), p)


## One instance of a piece; `lod` = [begin, end] visibility range (0 = open), faded.
static func piece(host: Node3D, path: String, nm: String, t: Transform3D, lod := Vector2(0, 0), shadows := true, lit_windows := false) -> MeshInstance3D:
	var m := mesh(path, nm)
	if m == null:
		push_warning("east kit: no mesh %s in %s" % [nm, path])
		return null
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lod != Vector2.ZERO:
		mi.visibility_range_begin = lod.x
		mi.visibility_range_begin_margin = lod.x * 0.12 if lod.x > 0.0 else 0.0
		mi.visibility_range_end = lod.y
		mi.visibility_range_end_margin = lod.y * 0.12 if lod.y > 0.0 else 0.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	host.add_child(mi)
	mi.global_transform = t
	if lit_windows:
		for i in m.get_surface_count():
			var sm2 := m.surface_get_material(i)
			if sm2 != null and sm2.resource_name == "window_glass":
				mi.set_surface_override_material(i, _window_mat())
				Interiors.pane_lights(mi, i, Color(1.0, 0.58, 0.24))        # the warm cone out of each pane
	return mi


## Many instances of one piece as one MultiMesh (kerbs, trestle bents, racks): one draw.
static func multi(host: Node3D, node_name: String, path: String, nm: String, xfs: Array, view_end := 240.0) -> void:
	var m := mesh(path, nm)
	if m == null or xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # static: interpolating a MultiMesh makes its add wait on the GPU (zz/stream_probe.gd)
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.visibility_range_end = view_end
	mmi.visibility_range_end_margin = view_end * 0.12
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	host.add_child(mmi)


## Many instances of one piece as separate nodes under one parent (a few dozen, each with its own range): for pieces the
## MultiMesh chunking (atmosphere.gd) would cut into cells and lose track of.
static func many(host: Node3D, node_name: String, path: String, nm: String, xfs: Array, view_end := 240.0) -> void:
	var parent := Node3D.new()
	parent.name = node_name
	host.add_child(parent)
	for t: Transform3D in xfs:
		if nm == "Block_Stack" and _salt_stack(parent, t, view_end):
			continue
		piece(parent, path, nm, t, Vector2(0, view_end))


const SALT_STACK := "res://art/models/salt_stack.glb"
static var _stack_parts: Array = []


## The salt block stack as the modelled piece (tools/blender/polish_salt.py: bevelled loaves, a plank, sacks, a rope) in place of r37e_works'
## five courses of plain boxes; false when it is not imported (the old piece then stands). One mesh a set (chalk, timber, cloth).
static func _salt_stack(parent: Node3D, t: Transform3D, view_end: float) -> bool:
	if _stack_parts.is_empty():
		var ps := load(SALT_STACK) as PackedScene if ResourceLoader.exists(SALT_STACK) else null
		if ps == null:
			return false
		var inst := ps.instantiate()
		for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var set_name := String(mi.name).get_slice("__", 1).get_slice(".", 0)
			var mat: Material = OssKit.mat("chalk") if set_name == "chalk" else (SiteProps.wood() if set_name == "timber" else null)
			if set_name == "cloth":
				mat = SiteProps.cloth()
			if mi.mesh != null and mat != null:
				_stack_parts.append([mi.mesh, mat])
		inst.free()
	if _stack_parts.is_empty():
		return false
	var host := Node3D.new()
	host.name = "Block_Stack"
	parent.add_child(host)
	host.global_transform = t
	for pr: Array in _stack_parts:
		var mi2 := MeshInstance3D.new()
		mi2.mesh = pr[0]
		mi2.material_override = pr[1]
		mi2.visibility_range_end = view_end
		mi2.visibility_range_end_margin = view_end * 0.1
		mi2.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mi2)
	return true


## Collision of a box table (rows [cx, cy, cz, sx, sy, sz, qx, qy, qz, qw], local to the piece) for each transform in
## `ts` (uniform scale in the basis), as one body.
static func cols(host: Node3D, node_name: String, rows: Array, ts: Array) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	for t: Transform3D in ts:
		var sc := t.basis.get_scale().x
		var rot := t.basis.orthonormalized()
		for r: Array in rows:
			var b := rot * Basis(Quaternion(float(r[6]), float(r[7]), float(r[8]), float(r[9])))
			var c := t * Vector3(float(r[0]), float(r[1]), float(r[2]))
			var size := Vector3(float(r[3]), float(r[4]), float(r[5])) * sc
			k._box_col(c, b.x * size.x * 0.5, b.y * size.y * 0.5, b.z * size.z * 0.5)
	k.commit(host, node_name)

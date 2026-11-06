class_name FarDetail
extends RefCounted
## far detail (docs/r37_expansion.md, "Far detail"). The camera sees VIEW_FAR metres (it was 82), so the world
## beyond the near field is always loaded, at very low detail, and detail fades in as you come up to it:
##   - terrain is one whole mesh plus the horizon ring (RealmLand); water, fog and sky do the rest
##   - trees: near mesh -> @far mesh (cross-faded at NEAR_END) -> a canopy shell per forest chunk (canopy_shell)
##   - everything else the Realm builds gets a visibility range with a DITHER FADE by its size (generic_range): small
##     clutter ends 70-130 m out, props 240 m, landmarks (>= 14 m) never end. Nothing is a hard cut.
##   - grass and small clutter keep their own short ranges and thin out (RealmFlora)
## For a landmark's own far mesh (a ~100-300 triangle silhouette of a tower, a wall, a statue):
##     var far := FarDetail.hull(aabb)                                   # or your own Mesh
##     FarDetail.register(host_node, far, xf, 90.0)                      # drawn from 90 m out to the horizon
## register() also fades the host's own meshes out at the same distance (cross-fade), so the near model stops where
## the far mesh starts. Anything you register stays loaded to the horizon (group cull_skip: nothing re-ranges it).

const VIEW_FAR := 420.0                  ## camera far plane (m); the fog has swallowed the world by then
const FAR_TREE_END := 210.0              ## the @far tree meshes end here (the canopy shell carries on)
const CANOPY_BEGIN := 150.0              ## a forest chunk's canopy shell fades in from here
const SHELL_CELL := 4.0

static var _shell_mat: StandardMaterial3D
static var _far_mat: StandardMaterial3D


## A low-poly far mesh for a landmark: its AABB as a box, tapered towards the top (`taper` 0 = a box, 1 = a point
## at the top: a tower or a roofed hall), the base sunk 0.5 m. Dark and matte: fog and the grade colour it.
static func hull(box: AABB, taper := 0.0, color := Color(0.16, 0.17, 0.2)) -> ArrayMesh:
	var p := box.position
	var s := box.size
	var inset := s * 0.5 * clampf(taper, 0.0, 1.0)
	var lo := PackedVector3Array([
		Vector3(p.x, p.y - 0.5, p.z), Vector3(p.x + s.x, p.y - 0.5, p.z), Vector3(p.x + s.x, p.y - 0.5, p.z + s.z), Vector3(p.x, p.y - 0.5, p.z + s.z)])
	var top := PackedVector3Array([
		Vector3(p.x + inset.x, p.y + s.y, p.z + inset.z), Vector3(p.x + s.x - inset.x, p.y + s.y, p.z + inset.z),
		Vector3(p.x + s.x - inset.x, p.y + s.y, p.z + s.z - inset.z), Vector3(p.x + inset.x, p.y + s.y, p.z + s.z - inset.z)])
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in 4:
		var k2 := (k + 1) % 4
		var b := verts.size()
		verts.append_array(PackedVector3Array([lo[k], lo[k2], top[k2], top[k]]))
		idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
	var b2 := verts.size()
	verts.append_array(top)
	idx.append_array(PackedInt32Array([b2, b2 + 1, b2 + 2, b2, b2 + 2, b2 + 3]))
	var nrms := PackedVector3Array()
	nrms.resize(verts.size())
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(color)
	# flat normals per face (each quad owns its four vertices)
	for q in range(0, verts.size() - 4, 4):
		var n := (verts[q + 1] - verts[q]).cross(verts[q + 2] - verts[q]).normalized()
		for j in 4:
			nrms[q + j] = -n if n.dot(verts[q] - (box.position + s * 0.5)) < 0.0 else n
	for j in 4:
		nrms[b2 + j] = Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, far_material())
	return m


## The shared matte material of far meshes (vertex colour, no shadows, no specular).
static func far_material() -> StandardMaterial3D:
	if _far_mat == null:
		_far_mat = StandardMaterial3D.new()
		_far_mat.vertex_color_use_as_albedo = true
		_far_mat.roughness = 1.0
		_far_mat.metallic_specular = 0.0
		_far_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _far_mat


## Draw `far` under `host` (a Node3D) from `near_end` metres out to the horizon, cross-fading with the host's own
## meshes, which stop at the same distance. `xf` is local to host. Returns the MeshInstance3D.
static func register(host: Node, far: Mesh, xf := Transform3D.IDENTITY, near_end := 90.0, material: Material = null, fade_host := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FarMesh"
	mi.mesh = far
	if material != null:
		mi.material_override = material
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var margin := maxf(8.0, near_end * 0.12)
	mi.visibility_range_begin = near_end
	mi.visibility_range_begin_margin = margin
	mi.visibility_range_end = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.extra_cull_margin = 4.0
	mi.set_meta(&"far_detail", true)
	mi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mi)
	if fade_host:
		near_ends(host, near_end, margin, mi)
	return mi


## The geometry under `node` ends at `end` metres (dither fade over `margin`), except `skip` and far meshes.
static func near_ends(node: Node, end: float, margin: float, skip: Node = null) -> int:
	var n := 0
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		if gi == skip or gi.has_meta(&"far_detail") or gi is GPUParticles3D:
			continue
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = margin
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.add_to_group(Groups.CULL_SKIP)
		n += 1
	if node is GeometryInstance3D and node != skip and not node.has_meta(&"far_detail"):
		var g := node as GeometryInstance3D
		g.visibility_range_end = end
		g.visibility_range_end_margin = margin
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		g.add_to_group(Groups.CULL_SKIP)
		n += 1
	return n


## The range a Realm-built mesh gets by its size (world extent of its AABB), with a dither fade. Returns true when it
## set one. Instances that already have a range, a far mesh, or sit in cull_skip are left alone.
static func generic_range(gi: GeometryInstance3D, extent: float) -> bool:
	if gi.visibility_range_end > 0.0 or gi.visibility_range_begin > 0.0 or gi.is_in_group(Groups.CULL_SKIP) or gi.has_meta(&"far_detail"):
		return false
	var end := 0.0
	var margin := 0.0
	if extent < 1.5:
		end = 70.0
		margin = 10.0
	elif extent < 5.0:
		end = 130.0
		margin = 16.0
	elif extent < 14.0:
		end = 240.0
		margin = 30.0
	else:
		return false                                 # landmarks: loaded to the horizon
	gi.visibility_range_end = end
	gi.visibility_range_end_margin = margin
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return true


## One forest chunk's canopy as a coarse heightfield shell: `trees` = [[base Vector3, height, crown radius]], the
## chunk's centre `c` and half size. Cells without crown sit 0.8 m under the ground (buried). Dark, matte; drawn
## from CANOPY_BEGIN to the horizon, fading in as the individual trees fade out.
static func canopy_shell(host: Node3D, c: Vector3, half: float, trees: Array, ground: Callable, nm: String) -> MeshInstance3D:
	var n := int(ceil(half * 2.0 / SHELL_CELL)) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	cols.resize(n * n)
	var any := false
	for j in n:
		for i in n:
			var x := c.x - half + float(i) * SHELL_CELL
			var z := c.z - half + float(j) * SHELL_CELL
			var gy: float = ground.call(x, z)
			var top := gy - 0.8
			var shade := 0.0
			for t: Array in trees:
				var b: Vector3 = t[0]
				var r: float = t[2]
				var dx := x - b.x
				var dz := z - b.z
				var d2 := (dx * dx + dz * dz) / (r * r)
				if d2 < 1.0:
					var h: float = t[1]
					# a crown is an ellipsoid over the upper two thirds of the tree
					var y := b.y + h * (0.42 + 0.56 * sqrt(1.0 - d2))
					if y > top:
						top = y
						shade = 1.0 - d2
						any = true
			var k := j * n + i
			verts[k] = Vector3(x - c.x, top - c.y, z - c.z)
			cols[k] = Color(0.07, 0.1, 0.08).lerp(Color(0.1, 0.15, 0.11), shade)
	if not any:
		return null
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array(PackedInt32Array([a, a + 1, a + n, a + 1, a + n + 1, a + n]))
	var nrms := PackedVector3Array()
	nrms.resize(n * n)
	for j in n:
		for i in n:
			var hl := verts[j * n + maxi(i - 1, 0)].y
			var hr := verts[j * n + mini(i + 1, n - 1)].y
			var hd := verts[maxi(j - 1, 0) * n + i].y
			var hu := verts[mini(j + 1, n - 1) * n + i].y
			nrms[j * n + i] = Vector3(-(hr - hl) / (2.0 * SHELL_CELL), 1.0, -(hu - hd) / (2.0 * SHELL_CELL)).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _shell_mat == null:
		_shell_mat = StandardMaterial3D.new()
		_shell_mat.vertex_color_use_as_albedo = true
		_shell_mat.roughness = 1.0
		_shell_mat.metallic_specular = 0.0
	m.surface_set_material(0, _shell_mat)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_begin = CANOPY_BEGIN
	mi.visibility_range_begin_margin = 30.0
	mi.visibility_range_end = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.set_meta(&"far_detail", true)
	mi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mi)
	return mi


## Collect one chunk's tall trees [[base, height, crown radius]] for its canopy shell (RealmFlora._emit).
static func note_crowns(canopy: Dictionary, key: Vector3i, list: Array, h: float, spread: float) -> void:
	if not canopy.has(key):
		canopy[key] = []
	for e: Array in list:
		var xf: Transform3D = e[0]
		var sc := xf.basis.get_scale().x
		(canopy[key] as Array).append([xf.origin, h * sc, maxf(spread * sc * 0.85, 1.0)])


## A canopy shell for every collected chunk (key x, z in chunk units); returns how many were made.
static func shells(host: Node3D, canopy: Dictionary, chunk: float, ground: Callable) -> int:
	var made := 0
	for key: Vector3i in canopy:
		var cx := (key.x + 0.5) * chunk
		var cz := (key.y + 0.5) * chunk
		var gy: float = ground.call(cx, cz)
		if canopy_shell(host, Vector3(cx, gy, cz), chunk * 0.5 + 2.0, canopy[key], ground, "Canopy_%d_%d" % [key.x, key.y]) != null:
			made += 1
	return made


## Release the shared materials (RealmFlora / Realm.release_caches: no engine resource outlives the tree).
static func release() -> void:
	_shell_mat = null
	_far_mat = null

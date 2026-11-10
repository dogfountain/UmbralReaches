class_name SeatProps
extends RefCounted
## Drops baked floor props onto the terrain mesh.
## They were planted with the height formula; the visible ground is a 2 m grid of that formula,
## so a stem sampled between vertices hangs in the air or clips through the slope.


static func seat(root: Node) -> int:
	var world: World3D = root.get_world_3d()
	if world == null:
		return 0
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var n := 0
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var kind := _kind(String(node.name))
		if kind == "":
			continue
		n += _seat_multi(node as MultiMeshInstance3D, space, kind)
	for node in root.find_children("Hero*", "MeshInstance3D", true, false):
		if _seat_hero(node as MeshInstance3D, space):
			n += 1
	return n


## Union-find over vertices welded by position: one id per connected island (index = vertex).
static func island_of(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedInt32Array:
	var weld := {}
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 500.0).round())
		parent[i] = weld.get(key, i)
		if not weld.has(key):
			weld[key] = i
	var find := func(a: int) -> int:
		while parent[a] != a:
			a = parent[a]
		return a
	for t in range(0, idx.size(), 3):
		var r0: int = find.call(idx[t])
		for k in [1, 2]:
			var rk: int = find.call(idx[t + k])
			if rk != r0:
				parent[rk] = r0
	var used := PackedByteArray()
	used.resize(verts.size())
	for i in idx:
		used[i] = 1
	var out := PackedInt32Array()
	out.resize(verts.size())
	for i in verts.size():
		out[i] = find.call(i) if used[i] == 1 else -1
	return out


## Pieces of one prop: a tree's trunk, branches and twigs interpenetrate without sharing
## vertices, so each island hangs off one parent: the lowest-starting island whose box overlaps
## its own (a branch -> its trunk); chains end at a root that rests on nothing: the trunk, the
## rock. One parent each, so touching crowns never chain a whole grove into one piece.
## Returns [per-vertex piece id (-1 unused), {piece: [world AABB, base point]},
## {island: world AABB}, {island: piece}] for one surface; base = centroid of lowest vertices.
static func pieces(verts: PackedVector3Array, idx: PackedInt32Array, xf: Transform3D) -> Array:
	var comp := island_of(verts, idx)
	var box := {}
	for vi in verts.size():
		if comp[vi] < 0:
			continue
		var w := xf * verts[vi]
		box[comp[vi]] = (box[comp[vi]] as AABB).expand(w) if box.has(comp[vi]) else AABB(w, Vector3.ZERO)
	var low := {}
	for vi in verts.size():
		if comp[vi] < 0:
			continue
		var w := xf * verts[vi]
		if w.y < (box[comp[vi]] as AABB).position.y + 0.3:
			var acc: Array = low.get(comp[vi], [Vector3.ZERO, 0])
			low[comp[vi]] = [acc[0] + w, int(acc[1]) + 1]
	var foot := {}
	for c: int in box:
		var acc: Array = low[c]
		foot[c] = acc[0] / float(acc[1])
	# spatial hash of island boxes on 4 m xz cells
	var cells := {}
	for c: int in box:
		var bb: AABB = box[c]
		for i in range(floori(bb.position.x / 4.0), floori(bb.end.x / 4.0) + 1):
			for j in range(floori(bb.position.z / 4.0), floori(bb.end.z / 4.0) + 1):
				var key := Vector2i(i, j)
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append(c)
	var up := {}
	for c: int in box:
		var cb: AABB = box[c]
		var best := -1
		var best_y := cb.position.y - 0.05
		var seen := {}
		for i in range(floori(cb.position.x / 4.0), floori(cb.end.x / 4.0) + 1):
			for j in range(floori(cb.position.z / 4.0), floori(cb.end.z / 4.0) + 1):
				for o: int in cells.get(Vector2i(i, j), []):
					if o == c or seen.has(o):
						continue
					seen[o] = true
					var ob: AABB = box[o]
					if ob.position.y < best_y and ob.grow(0.1).intersects(cb):
						best = o
						best_y = ob.position.y
		up[c] = best
	var root_of := func(c: int) -> int:
		while int(up[c]) >= 0:
			c = up[c]
		return c
	var island_piece := {}
	for c: int in box:
		island_piece[c] = root_of.call(c)
	var piece := PackedInt32Array()
	piece.resize(verts.size())
	var pbox := {}
	for vi in verts.size():
		if comp[vi] < 0:
			piece[vi] = -1
			continue
		var r: int = island_piece[comp[vi]]
		piece[vi] = r
		var w := xf * verts[vi]
		pbox[r] = (pbox[r] as AABB).expand(w) if pbox.has(r) else AABB(w, Vector3.ZERO)
	var info := {}
	for r: int in pbox:
		info[r] = [pbox[r], foot[r]]
	return [piece, info, box, island_piece]


static func _sample_ground(outer: _HeightField, heart: _HeightField, has_heart: bool, x: float, z: float) -> float:
	if has_heart and maxf(absf(x), absf(z)) <= 96.0:
		var hy: float = heart.sample(x, z)
		if hy < 1.0e8:
			return hy
	return outer.sample(x, z)


class _HeightField:
	var verts: PackedVector3Array
	var nx := 1
	var nz := 1
	var x0 := 0.0
	var z0 := 0.0
	var step := 1.0

	func load_mesh(mesh: Mesh) -> bool:
		var raw: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if raw.size() < 4:
			return false
		var xs := {}
		var zs := {}
		for v in raw:
			xs[roundi(v.x * 100.0)] = true
			zs[roundi(v.z * 100.0)] = true
		var xkeys: Array = xs.keys()
		var zkeys: Array = zs.keys()
		xkeys.sort()
		zkeys.sort()
		if xkeys.size() < 2 or zkeys.size() < 2:
			return false
		nx = xkeys.size()
		nz = zkeys.size()
		x0 = float(xkeys[0]) / 100.0
		z0 = float(zkeys[0]) / 100.0
		step = (float(xkeys[1]) - float(xkeys[0])) / 100.0
		if step < 0.01:
			return false
		verts = PackedVector3Array()
		verts.resize(nx * nz)
		for v in raw:
			var ix := roundi((v.x - x0) / step)
			var iz := roundi((v.z - z0) / step)
			if ix >= 0 and iz >= 0 and ix < nx and iz < nz:
				verts[iz * nx + ix] = v
		return true

	func sample(x: float, z: float) -> float:
		var fx := (x - x0) / step
		var fz := (z - z0) / step
		if fx < 0.0 or fz < 0.0 or fx >= float(nx - 1) or fz >= float(nz - 1):
			return 1.0e9
		var i := floori(fx)
		var j := floori(fz)
		var tx := fx - float(i)
		var tz := fz - float(j)
		var y00: float = verts[j * nx + i].y
		var y10: float = verts[j * nx + i + 1].y
		var y01: float = verts[(j + 1) * nx + i].y
		var y11: float = verts[(j + 1) * nx + i + 1].y
		if tx + tz <= 1.0:
			return y00 + (y10 - y00) * tx + (y01 - y00) * tz
		return y11 + (y01 - y11) * (1.0 - tx) + (y10 - y11) * (1.0 - tz)


static func _shade_caps(mmi: MultiMeshInstance3D, kind: String) -> void:
	if kind != "shroom" or mmi.material_override is ShaderMaterial:
		return
	var old := mmi.material_override as StandardMaterial3D
	if old == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/cap.gdshader")
	mat.set_shader_parameter("glow", maxf(old.emission_energy_multiplier, 1.2))
	mat.set_shader_parameter("stem_color", Color(0.62, 0.55, 0.46))
	mmi.material_override = mat


static func _kind(node_name: String) -> String:
	var n := node_name.to_lower()
	if n.begins_with("glowbud") or n.begins_with("glowcap") or n.begins_with("nightcap") or n.begins_with("cap"):
		return "shroom"
	if n.begins_with("grass") or n.begins_with("fern"):
		return "blade"
	if n.begins_with("pebble"):
		return "pebble"
	return ""


static func _seat_multi(mmi: MultiMeshInstance3D, space: PhysicsDirectSpaceState3D, kind: String) -> int:
	var src := mmi.multimesh
	if src == null or src.instance_count < 1:
		return 0
	var mm := _clone_mm(src)
	mmi.multimesh = mm
	_shade_caps(mmi, kind)
	# one buffer read and one write: per-instance setters on these cells did not stick (and stall)
	var buf := mm.buffer
	var stride := _stride(mm)
	if buf.size() != mm.instance_count * stride:
		return 0                                # a layout this code does not write (e.g. 2D transforms)
	var xf := mmi.global_transform
	var inv := xf.affine_inverse()
	var seated := 0
	for i in mm.instance_count:
		var o := i * stride
		var world := xf * _xf_at(buf, o)
		var hit := _terrain(space, world.origin)
		if hit.is_empty():
			continue
		var p: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		if kind == "shroom":
			world = _plant(world, p, normal, 0.16)
		elif kind == "pebble":
			var half_h := 0.3 * world.basis.get_scale().y
			world.origin = Vector3(world.origin.x, p.y + half_h * 0.45, world.origin.z)
		else:
			world.origin.y = p.y - 0.22
		_put_xf(buf, o, inv * world)
		seated += 1
	_commit(mm, buf)
	return seated


## Write the edited buffer and keep the CPU copy on the MultiMesh: reading `buffer` back in the
## same frame returns the GPU's stale data (seen on Metal), so WorldLanes.cull_scatter used to
## write the old heights straight back. custom_aabb grows to the moved instances so the cell is
## not frustum-culled where its foliage dropped with the terraces.
static func _commit(mm: MultiMesh, buf: PackedFloat32Array) -> void:
	mm.buffer = buf
	mm.set_meta("cpu_buffer", buf)
	if mm.custom_aabb.size == Vector3.ZERO:
		return
	var box := mm.custom_aabb
	var stride := _stride(mm)
	for i in mm.instance_count:
		var o := i * stride
		box = box.expand(Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
	mm.custom_aabb = box


## Copy of a MultiMesh with its layout set before its buffer (Resource.duplicate() restores the
## buffer first on some, which fails with "different size from the existing buffer").
static func _clone_mm(src: MultiMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = src.transform_format
	mm.use_colors = src.use_colors
	mm.use_custom_data = src.use_custom_data
	mm.mesh = src.mesh
	mm.custom_aabb = src.custom_aabb
	mm.instance_count = src.instance_count
	mm.visible_instance_count = src.visible_instance_count
	if DisplayServer.get_name() == "headless":
		return mm                               # the dummy renderer refuses its own buffer back
	var b := src.buffer
	if b.size() == mm.buffer.size():
		mm.buffer = b
	return mm


static func _stride(mm: MultiMesh) -> int:
	return 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)


## MultiMesh buffer rows: basis row + origin component, three times (TRANSFORM_3D).
static func _xf_at(buf: PackedFloat32Array, o: int) -> Transform3D:
	return Transform3D(
		Vector3(buf[o], buf[o + 4], buf[o + 8]),
		Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
		Vector3(buf[o + 2], buf[o + 6], buf[o + 10]),
		Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))


static func _put_xf(buf: PackedFloat32Array, o: int, t: Transform3D) -> void:
	var b := t.basis
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = t.origin.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = t.origin.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = t.origin.z


static func _seat_hero(mi: MeshInstance3D, space: PhysicsDirectSpaceState3D) -> bool:
	if mi.mesh == null:
		return false
	var hit := _terrain(space, mi.global_position)
	if hit.is_empty():
		return false
	var before := mi.global_position
	var planted := _plant(mi.global_transform, hit.position, hit.normal, 0.16)
	_refresh_hero_mesh(mi)
	mi.global_transform = planted
	var delta := mi.global_position - before
	var parent := mi.get_parent()
	if parent == null or delta.length_squared() < 0.0001:
		return true
	for child in parent.get_children():
		if child is OmniLight3D and not child.has_meta("seated"):
			if child.global_position.distance_squared_to(before) < 9.0:
				child.global_position += delta
				child.set_meta("seated", true)
				break
	return true


static func _refresh_hero_mesh(mi: MeshInstance3D) -> void:
	var h := mi.mesh.get_aabb().size.y
	var spec := 1 if h < 0.85 else (2 if h < 1.22 else 0)
	var col := _cap_color(mi.mesh)
	mi.mesh = load("res://core/util/mushroom_mesh.gd").build(spec, 1.0, 1, col)


static func _cap_color(mesh: Mesh) -> Color:
	var best := Color("#C41E3A")
	var raw = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if raw == null:
		return best
	var cols: PackedColorArray = raw
	var sat := -1.0
	for c in cols:
		if c.s > sat:
			sat = c.s
			best = c
	return best


static func _plant(world: Transform3D, point: Vector3, normal: Vector3, sink: float) -> Transform3D:
	var up := normal.normalized()
	var sc := world.basis.get_scale()
	var flat := Vector3(world.basis.x.x, 0.0, world.basis.x.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(1.0, 0.0, 0.0)
	flat = flat.normalized()
	var x := (flat - up * flat.dot(up))
	if x.length_squared() < 0.0001:
		x = up.cross(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(up).normalized()
	x = up.cross(z).normalized()
	return Transform3D(Basis(x, up, z).scaled(sc), point - up * sink)


static func _terrain(space: PhysicsDirectSpaceState3D, origin: Vector3) -> Dictionary:
	var hit := _ground(space, origin + Vector3(0.0, 2.8, 0.0), origin + Vector3(0.0, -3.2, 0.0))
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	var p: Vector3 = hit.position
	if n.y < 0.35 or absf(p.y - origin.y) > 2.2:
		return {}
	return hit


## First terrain hit along the ray, looking through up to four other colliders.
static func _ground(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = []
	for _i in 5:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = exclude
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var col := hit.collider as Node
		var nm := "" if col == null else String(col.name).to_lower()
		if nm.contains("terrain"):
			return hit
		exclude.append(hit.rid)
	return {}

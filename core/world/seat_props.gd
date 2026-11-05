class_name SeatProps
extends RefCounted
## Drops baked floor props onto the terrain mesh.
## They were planted with the height formula; the visible ground is a 2 m grid of that formula,
## so a stem sampled between vertices hangs in the air or clips through the slope.


## Builder roots (and streamed Area_* scenes): everything under them is placed at runtime, after
## the terrain was shaped.
const BUILT := ["Glimmers", "HollowLantern", "ThornHenge", "StairWorks", "SummitAltar", "Ossuary"]


## `baked`: the scatter was planted on the pre-terrace ground, so it first follows
## TerrainStamp.delta_at() (hills dropped up to ~8 m) and then snaps to the new ground.
static func seat(root: Node, baked := false) -> int:
	var world: World3D = root.get_world_3d()
	if world == null:
		return 0
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var n := 0
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var follow := baked and _baked(node)
		var kind := _kind(String(node.name))
		if kind == "":
			if follow:
				n += _shift_multi(node as MultiMeshInstance3D, space)
			continue
		n += _seat_multi(node as MultiMeshInstance3D, space, kind, follow)
	for node in root.find_children("Hero*", "MeshInstance3D", true, false):
		if _seat_hero(node as MeshInstance3D, space, baked and _baked(node)):
			n += 1
	return n


static func _baked(node: Node) -> bool:
	var p := node
	while p:
		if p.has_meta("site") or String(p.name) in BUILT or String(p.name).begins_with("Area_"):
			return false
		p = p.get_parent()
	return true


## Baked props that stood on the hills before terracing: [mesh, collision body]. The hills dropped
## up to ~13 m, and plant_solid only closes gaps under 0.55 m, so trees, rocks and ruins were left
## hanging in the air (with their collision and trunk occluders).
const FOLLOW := [
	["Zone/Forest/GiantTrunks", "Zone/ForestBody"],
	["Zone/DeadTrees", "Zone/TreesBody"],
	["Zone/Boulders", "Zone/BouldersBody"],
	["Zone/Ruins", "Zone/RuinsBody"],
	["Zone/RiftCrystals", ""],
]


## Move every baked piece (one tree, rock or ruin stone) rigidly by the terracing under its
## base (TerrainStamp.shape_delta_at), so it keeps its shape and lands where it stood; canopy crowns
## follow the trunk under them; collision, trunk occluders, menhirs, lanterns, braziers and gates
## go with them. Run after TerrainStamp.apply, before plant_solid (which then fine-seats).
static func follow_terrain(root: Node) -> void:
	if root.has_meta("props_followed"):
		return
	root.set_meta("props_followed", true)
	var moved := 0
	var trunks: Array = []                  # [base xz, dy] of every tree in GiantTrunks (for crowns)
	for pair: Array in FOLLOW:
		var mi := root.get_node_or_null(String(pair[0])) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var shifts := _shift_islands(mi, func(_bb: AABB, base: Vector3) -> float: return TerrainStamp.shape_delta_at(base.x, base.z))
		moved += shifts.size()
		if String(pair[0]).ends_with("GiantTrunks"):
			for s: Array in shifts:
				trunks.append([Vector2((s[1] as Vector3).x, (s[1] as Vector3).z), s[2]])
		_shift_body(root, String(pair[1]), shifts)
	_drop_loose_bits(root)
	var canopy := root.get_node_or_null("Zone/Forest/Canopy") as MeshInstance3D
	if canopy and canopy.mesh:
		moved += _shift_islands(canopy, func(bb: AABB, _base: Vector3) -> float:
			var c := Vector2(bb.get_center().x, bb.get_center().z)
			var best := 8.0
			var dy := TerrainStamp.shape_delta_at(c.x, c.y)
			for t: Array in trunks:
				var d := c.distance_to(t[0])
				if d < best:
					best = d
					dy = float(t[1])
			return dy).size()
	var nodes := 0
	for node in root.find_children("*", "Node3D", true, false):
		var p := node.get_parent()
		var nm := String(node.name)
		if p == null or not (String(p.name) in ["Lanterns", "Braziers"] or (nm.begins_with("Menhir") and p.name == &"Zone") or node is MirrorGate or nm.ends_with("Mirror")):
			continue
		var o: Vector3 = (node as Node3D).global_position
		var dy := TerrainStamp.shape_delta_at(o.x, o.z)
		if absf(dy) > 0.02:
			(node as Node3D).global_position.y += dy
			nodes += 1
	print("SEAT followed the terraces: %d islands, %d props" % [moved, nodes])


## Small tree fragments (a knot or twig not touching any other part of a tree) left hanging over
## nothing once the hills came down: removed. The terrain mesh is sampled directly (collision of
## other props is not built into the query), so "over nothing" means more than 1.5 m above the
## ground (or off the terrain) and not resting on a larger part of the same mesh.
static func _drop_loose_bits(root: Node) -> void:
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	var field := _HeightField.new()
	if terrain == null or terrain.mesh == null or not field.load_mesh(terrain.mesh):
		return
	for path: String in ["Zone/Forest/GiantTrunks", "Zone/DeadTrees"]:
		var mi := root.get_node_or_null(path) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := mi.global_transform
		var out := ArrayMesh.new()
		var dropped := 0
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			var pc: Array = pieces(verts, idx, xf)
			var piece: PackedInt32Array = pc[0]
			var info: Dictionary = pc[1]
			var drop := {}
			for r: int in info:
				var bb: AABB = info[r][0]
				var base: Vector3 = info[r][1]
				if bb.size.length() > 2.5:
					continue
				var g := field.sample(base.x, base.z)
				if g < 1.0e8 and base.y - g < 1.5:
					continue                     # on (or near) the ground
				var held := false
				for o: int in info:
					var ob: AABB = info[o][0]
					if o != r and ob.size.length() > 2.5 and ob.grow(0.3).has_point(base):
						held = true
						break
				if not held:
					drop[r] = true
			if not drop.is_empty():
				var keep := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					if drop.has(piece[idx[t]]):
						dropped += 1
						continue
					keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
				arrays[Mesh.ARRAY_INDEX] = keep
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(si, mi.mesh.surface_get_material(si))
		if dropped > 0:
			mi.mesh = out
			print("SEAT removed %d tris of loose fragments hanging in the air from %s" % [dropped, path])


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


## Shift each piece of `mi` by dy_of(world AABB, base point). Returns [[AABB, base, dy], ...]
## (old positions) for the pieces that moved.
static func _shift_islands(mi: MeshInstance3D, dy_of: Callable) -> Array:
	var xf := mi.global_transform
	var inv := xf.affine_inverse()
	var out := ArrayMesh.new()
	var shifts: Array = []
	for si in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var pc: Array = pieces(verts, idx, xf)
		var piece: PackedInt32Array = pc[0]
		var info: Dictionary = pc[1]
		var dy := {}
		for r: int in info:
			var d: float = dy_of.call(info[r][0], info[r][1])
			if absf(d) > 0.02:
				dy[r] = d
				shifts.append([info[r][0], info[r][1], d])
		if not dy.is_empty():
			for vi in verts.size():
				if dy.has(piece[vi]):
					verts[vi] = inv * (xf * verts[vi] + Vector3.UP * float(dy[piece[vi]]))
			arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mi.mesh.surface_get_material(si))
	if not shifts.is_empty():
		mi.mesh = out
	return shifts


## Collision follows its islands: trunk primitives (and the occluders made from them) by the island
## under their origin, trimesh faces by the island holding their centre.
static func _shift_body(root: Node, body_path: String, shifts: Array) -> void:
	var body := root.get_node_or_null(body_path) as Node3D
	if body == null or shifts.is_empty():
		return
	var dy_at := func(p: Vector3, grow: float) -> float:
		for s: Array in shifts:
			if (s[0] as AABB).grow(grow).has_point(p):
				return float(s[2])
		return 0.0                          # not part of anything that moved: stays put
	var occ := root.get_node_or_null("Occluders")
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if not (cs.shape is ConcavePolygonShape3D):
			var old := cs.global_position
			var d: float = dy_at.call(old, 0.5)
			if absf(d) < 0.02:
				continue
			cs.global_position = old + Vector3.UP * d
			if occ:
				for o in occ.get_children():
					if (o as Node3D).global_position.distance_to(old) < 0.05:
						(o as Node3D).global_position += Vector3.UP * d
			continue
		var cx := cs.global_transform
		var ci := cx.affine_inverse()
		var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
		for i in range(0, faces.size(), 3):
			var m := cx * ((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
			var d: float = dy_at.call(m, 0.3)
			if absf(d) < 0.02:
				continue
			for k in 3:
				faces[i + k] = ci * (cx * faces[i + k] + Vector3.UP * d)
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = (cs.shape as ConcavePolygonShape3D).backface_collision
		sh.set_faces(faces)
		cs.shape = sh


## Pulls stone, trunks, the path and the gate down onto the visible terrain grid.
## Baked props used the height formula; the ground mesh is the bilinear grid of that formula.
static func plant_solid(root: Node) -> void:
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	if terrain == null or terrain.mesh == null:
		return
	var field := _HeightField.new()
	if not field.load_mesh(terrain.mesh):
		return
	var heart_mi := root.find_child("TerrainHeart", true, false) as MeshInstance3D
	var heart := _HeightField.new()
	var has_heart := heart_mi != null and heart_mi.mesh != null and heart.load_mesh(heart_mi.mesh)
	var moved := 0
	for gate in root.find_children("*", "Node3D", true, false):
		if not (gate is MirrorGate or String(gate.name).ends_with("Mirror")):
			continue
		var gy: float = _sample_ground(field, heart, has_heart, gate.global_position.x, gate.global_position.z)
		# Only gates already standing on the terrain. The summit portal sits on the stair platform,
		# far above the ground mesh, and must stay there.
		if gy < 1.0e8 and absf(gate.global_position.y - gy) < 2.0:
			gate.global_position.y = gy
			moved += 1
	for prop in root.find_children("*", "Node3D", true, false):
		var parent := prop.get_parent()
		if parent == null:
			continue
		var pn := String(parent.name)
		if pn != "Lanterns" and pn != "Braziers" and pn != "Haven":
			continue
		var py: float = _sample_ground(field, heart, has_heart, prop.global_position.x, prop.global_position.z)
		# Only props already standing on the terrain (same guard as the gates above): the Landing and
		# Threshold braziers stand on the stair, 30-45 m above the chasm floor under them, and used to
		# be dragged down onto it -- two checkpoints silently missing from the climb.
		if py < 1.0e8 and absf(prop.global_position.y - py) < 2.0:
			prop.global_position.y = py - 0.12
			moved += 1
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == terrain or mi == heart_mi or mi.mesh == null:
			continue
		if _skip_solid(mi):
			continue
		if _plantable(mi):
			moved += _fit_mesh(mi, field, false, heart if has_heart else null)
	var disk := root.find_child("RingCol", true, false) as CollisionShape3D
	if disk:
		disk.disabled = true
	print("SEAT solid ", moved)
	DressedProps.dress_zone(root)


static func _skip_solid(mi: MeshInstance3D) -> bool:
	var n := String(mi.name)
	if n in ["Terrain", "TerrainHeart", "River", "Water", "Canopy", "Leaves", "Heart", "Glass", "Fire", "IronArch", "Flame", "Coals", "Bowl", "Deck", "Boards", "Path", "Walk", "Keel"]:
		return true
	var p: Node = mi
	while p:
		if p is CharacterBody3D or String(p.name) == "Player" or String(p.name) == "Visual":
			return true
		p = p.get_parent()
	return false


static func _sample_ground(outer: _HeightField, heart: _HeightField, has_heart: bool, x: float, z: float) -> float:
	if has_heart and maxf(absf(x), absf(z)) <= 96.0:
		var hy: float = heart.sample(x, z)
		if hy < 1.0e8:
			return hy
	return outer.sample(x, z)


static func _plantable(mi: MeshInstance3D) -> bool:
	var n := String(mi.name)
	if n in ["Ring", "Boulders", "GiantTrunks", "DeadTrees"]:
		return true
	if n.begins_with("Post"):
		var p := mi.get_parent()
		if p != null and String(p.name) in ["Bridge", "Dock"]:
			return false
		return true
	return false


static func _surface_arrays(mesh: Mesh) -> Array:
	if mesh is ArrayMesh:
		return mesh.surface_get_arrays(0)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	return st.commit().surface_get_arrays(0)


static func _fit_mesh(mi: MeshInstance3D, field, drape: bool, heart = null) -> int:
	if mi.mesh == null or mi.mesh.get_surface_count() < 1:
		return 0
	var arrays: Array = _surface_arrays(mi.mesh)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := mi.global_transform
	var inv := xf.affine_inverse()
	var changed := 0
	for i in verts.size():
		var w: Vector3 = xf * verts[i]
		var g: float = field.sample(w.x, w.z)
		if heart != null and maxf(absf(w.x), absf(w.z)) <= 96.0:
			var hy: float = heart.sample(w.x, w.z)
			if hy < 1.0e8:
				g = hy
		if g > 1.0e8:
			continue
		var gap := w.y - g
		if drape:
			w.y = g + 0.045
			changed += 1
		elif gap > 0.05 and gap < 0.55:
			w.y = g - 0.06
			changed += 1
		else:
			continue
		verts[i] = inv * w
	if changed == 0:
		return 0
	arrays[Mesh.ARRAY_VERTEX] = verts
	var rebuilt := ArrayMesh.new()
	rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = rebuilt
	return changed


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


static func sink_river_crystals(root: Node) -> void:
	var mi := root.find_child("EmberCrystals", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var mesh := mi.mesh.duplicate() as ArrayMesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sunk := 0
	for i in verts.size():
		var v := verts[i]
		var rz := 4.2 + sin(v.x * 0.11) * 6.4 + sin(v.x * 0.27 + 1.1) * 2.0
		if absf(v.z - rz) < 2.6 and v.y > -0.05:
			v.y = -0.42
			verts[i] = v
			sunk += 1
	if sunk == 0:
		return
	arrays[Mesh.ARRAY_VERTEX] = verts
	var rebuilt := ArrayMesh.new()
	rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = rebuilt
	print("SEAT crystals sunk ", sunk)


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


static func _seat_multi(mmi: MultiMeshInstance3D, space: PhysicsDirectSpaceState3D, kind: String, follow := false) -> int:
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
		if follow:
			world.origin.y += TerrainStamp.delta_at(world.origin.x, world.origin.z)
			_put_xf(buf, o, inv * world)                  # kept even if the fine snap below misses
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


## Scatter with no seating rule (spores drift above the floor): carried by the ground change and
## kept out of the ground, only where it hangs over the terrain (not the chasm or a structure).
static func _shift_multi(mmi: MultiMeshInstance3D, space: PhysicsDirectSpaceState3D) -> int:
	var src := mmi.multimesh
	if src == null or src.instance_count < 1:
		return 0
	var mm := _clone_mm(src)
	mmi.multimesh = mm
	var buf := mm.buffer
	var stride := _stride(mm)
	if buf.size() != mm.instance_count * stride:
		return 0                                # a layout this code does not write (e.g. 2D transforms)
	var xf := mmi.global_transform
	var inv := xf.affine_inverse()
	var moved := 0
	for i in mm.instance_count:
		var o := i * stride
		var world := xf * _xf_at(buf, o)
		var at := world.origin + Vector3.UP * TerrainStamp.delta_at(world.origin.x, world.origin.z)
		var hit := _ground(space, at + Vector3.UP * 6.0, at + Vector3.DOWN * 6.0)
		if hit.is_empty():
			continue
		var gy: float = (hit.position as Vector3).y
		if at.y - gy > 4.0 or at.y - gy < -2.0:
			continue
		at.y = maxf(at.y, gy + 0.1)                   # none left in the ground
		if absf(at.y - world.origin.y) < 0.02:
			continue
		world.origin = at
		_put_xf(buf, o, inv * world)
		moved += 1
	if moved > 0:
		_commit(mm, buf)
	return moved


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


static func _seat_hero(mi: MeshInstance3D, space: PhysicsDirectSpaceState3D, follow := false) -> bool:
	if mi.mesh == null:
		return false
	if follow:
		var gp := mi.global_position
		mi.global_position.y += TerrainStamp.delta_at(gp.x, gp.z)
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

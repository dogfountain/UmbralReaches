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


static func _seat_multi(mmi: MultiMeshInstance3D, space: PhysicsDirectSpaceState3D, kind: String) -> int:
	var src := mmi.multimesh
	if src == null or src.instance_count < 1:
		return 0
	var mm := src.duplicate() as MultiMesh
	mmi.multimesh = mm
	_shade_caps(mmi, kind)
	var inv := mmi.global_transform.affine_inverse()
	var seated := 0
	for i in mm.instance_count:
		var local: Transform3D = mm.get_instance_transform(i)
		var world := mmi.global_transform * local
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
		mm.set_instance_transform(i, inv * world)
		seated += 1
	return seated


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
	var exclude: Array[RID] = []
	var from := origin + Vector3(0.0, 2.8, 0.0)
	var to := origin + Vector3(0.0, -3.2, 0.0)
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
			var n: Vector3 = hit.normal
			var p: Vector3 = hit.position
			if n.y < 0.35 or absf(p.y - origin.y) > 2.2:
				return {}
			return hit
		exclude.append(hit.rid)
	return {}

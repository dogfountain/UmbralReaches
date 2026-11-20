extends RefCounted
## A skirt down the horizon ring's outer edge (RealmLand._ring_data): the far mountains end in a face that falls to Y_FOOT,
## so a look from the summit or a high spot never finds the ring's underside or the sky through its last row (polish, 20 Nov).
## Load by path (no class_name): const RingSkirt := preload("res://core/world/realm/ring_skirt.gd")

const Y_FOOT := -70.0


## Append the skirt quads of the ring part `accept` covers to the part's arrays. `grid` = [nx, nz, x0, z0, step]; `splat` is
## Callable(x, z, h) -> [COLOR, UV, UV2] (RealmLand._splat on the ring).
static func add(hs: PackedFloat32Array, grid: Array, accept: Callable, splat: Callable, verts: PackedVector3Array,
		nrms: PackedVector3Array, cols: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> void:
	var nx: int = grid[0]
	var nz: int = grid[1]
	var x0: float = grid[2]
	var z0: float = grid[3]
	var step: float = grid[4]
	# [cell i, cell j, a corner, b corner (grid indices), outward normal]
	var segs: Array = []
	for i in nx - 1:
		segs.append([i, 0, Vector2i(i, 0), Vector2i(i + 1, 0), Vector3(0, 0, -1)])
		segs.append([i, nz - 2, Vector2i(i, nz - 1), Vector2i(i + 1, nz - 1), Vector3(0, 0, 1)])
	for j in nz - 1:
		segs.append([0, j, Vector2i(0, j), Vector2i(0, j + 1), Vector3(-1, 0, 0)])
		segs.append([nx - 2, j, Vector2i(nx - 1, j), Vector2i(nx - 1, j + 1), Vector3(1, 0, 0)])
	for sg: Array in segs:
		if not bool(accept.call(int(sg[0]), int(sg[1]))):
			continue
		var out_n: Vector3 = sg[4]
		var tops: Array[Vector3] = []
		for c: Vector2i in [sg[2], sg[3]]:
			tops.append(Vector3(x0 + c.x * step, hs[c.y * nx + c.x], z0 + c.y * step))
		var corners: Array[Vector3] = [tops[0], tops[1], Vector3(tops[1].x, Y_FOOT, tops[1].z), Vector3(tops[0].x, Y_FOOT, tops[0].z)]
		var base := verts.size()
		for v: Vector3 in corners:
			verts.append(v)
			nrms.append(out_n)
			var sp: Array = splat.call(v.x, v.z, maxf(tops[0].y, 30.0))       # the rim's own scree, top to foot
			cols.append(sp[0])
			uv.append(sp[1])
			uv2.append(sp[2])
		# front faces are clockwise seen from outside: the right-hand normal of (p1 - p0) x (p2 - p0) points inward
		var flip := (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(out_n) > 0.0
		if flip:
			idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
		else:
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

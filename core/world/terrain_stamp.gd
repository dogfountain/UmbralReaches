class_name TerrainStamp
extends RefCounted
## Terrain yields to architecture. Before any prop is seated, the hub terrain (a 2 m grid mesh +
## a matching trimesh) is adjusted under every footprint in WorldLanes.FOOTPRINTS:
##   - where a structure's underside floats above the ground, the ground rises to meet it;
##   - where the ground covers a structure's walk surface, it drops just below it;
## then the change fades out over FALLOFF metres so no ridge or pit is left at the edge.
## Measured against the structure's visible mesh (temporary trimesh proxies on a private layer),
## so it fixes what you see, not what the collision happens to be.

const PROXY := 1 << 18
const CONTACT := Metrics.CONTACT
const FALLOFF := 4.0         ## metres over which a stamp blends back into the original ground


## Terraced hills. The valley's hills rose 20 m at 40 degrees: unusable ground. Here every hill
## (ground above SHAPE_BASE) is compressed to SHAPE_K of its height and cut into terraces the way
## a hillside is laid out for building -- level platforms joined by walkable banks -- with step
## heights that change across the land (2.4-4.4 m) and terrace edges that wander, so the result
## follows the old contours and is never symmetrical. Sanctuary, stair foot and Ossuary keep their
## ground (weighted out with a falloff); the chasm (below SHAPE_BASE) is untouched.
const SHAPE_BASE := 0.6
const SHAPE_K := 0.45
const SHAPE_FLAT := 0.52               ## share of each band that is level platform
const KEEP := [                         ## [rect xz, falloff m]
	[Rect2(-11.0, 12.0, 22.0, 29.0), 8.0],      # sanctuary
	[Rect2(-7.0, -14.0, 14.0, 26.0), 8.0],      # stair foot and lower flight
	[Rect2(2.0, -106.0, 30.0, 84.0), 6.0],      # the Ossuary over the chasm
]

## How far the ground moved (shape + stamps), per grid vertex of the current terrain. Baked scatter
## was planted on the old ground; SeatProps adds delta_at() before it snaps to the new one.
static var _dh := {}
static var _dh_shape := {}               ## the terracing alone (no site stamps)
static var _dh_grid: _Grid
static var _dh_owner := 0


## Total ground height change at (x, z) since the baked terrain, bilinear between grid vertices.
static func delta_at(x: float, z: float) -> float:
	if _dh_grid == null or _dh.is_empty() or not is_instance_valid(instance_from_id(_dh_owner)):
		return 0.0
	return _dh_grid.field(_dh, x, z)


## Ground change from the terracing alone. Baked props follow this, not the site stamps: a site
## clears its own footprint, and its fill would otherwise lift the props round its edge into it.
static func shape_delta_at(x: float, z: float) -> float:
	if _dh_grid == null or _dh_shape.is_empty() or not is_instance_valid(instance_from_id(_dh_owner)):
		return 0.0
	return _dh_grid.field(_dh_shape, x, z)


static func _own(body: StaticBody3D, grid: _Grid) -> void:
	if _dh_owner != body.get_instance_id():
		_dh = {}
		_dh_shape = {}
		_dh_grid = grid
		_dh_owner = body.get_instance_id()


static func shape(root: Node) -> void:
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	var body := root.find_child("TerrainBody", true, false) as StaticBody3D
	if terrain == null or terrain.mesh == null or body == null or root.has_meta("terrain_shaped"):
		return
	root.set_meta("terrain_shaped", true)
	var arrays := terrain.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var grid := _Grid.new()
	if not grid.build(verts, terrain.global_transform):
		return
	_own(body, grid)
	var steps := FastNoiseLite.new()
	steps.seed = 1201
	steps.frequency = 0.018
	var warp := FastNoiseLite.new()
	warp.seed = 77
	warp.frequency = 0.045
	var out := {}
	for idx in grid.nx * grid.nz:
		if grid.vert_of[idx] < 0:
			continue
		var w := grid.world(idx)
		var u := w.y - SHAPE_BASE
		if u <= 0.05:
			continue
		var keep := 0.0
		for kz: Array in KEEP:
			var r: Rect2 = kz[0]
			var fall: float = kz[1]
			var d := _rect_dist(r, Vector2(w.x, w.z))
			keep = maxf(keep, 1.0 - clampf(d / fall, 0.0, 1.0))
		if keep >= 0.999:
			continue
		var step := lerpf(2.4, 4.4, steps.get_noise_2d(w.x, w.z) * 0.5 + 0.5)
		var t := (u * SHAPE_K) / step + warp.get_noise_2d(w.x, w.z) * 0.22
		var lvl := floorf(t)
		var fr := t - lvl
		var r2 := smoothstep(SHAPE_FLAT, 1.0, fr)
		var shaped := SHAPE_BASE + maxf(0.0, (lvl + r2) * step)
		var target := lerpf(shaped, w.y, keep * keep * (3.0 - 2.0 * keep))
		if absf(target - w.y) > 0.02:
			out[idx] = target - w.y
	if out.is_empty():
		return
	_write(terrain, body, grid, arrays, verts, out)
	_dh_shape = out.duplicate()
	WorldLanes.clear_cache()
	print("TERRAIN_SHAPE %d of %d vertices terraced" % [out.size(), grid.nx * grid.nz])


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()


static func apply(root: Node) -> void:
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	var body := root.find_child("TerrainBody", true, false) as StaticBody3D
	if terrain == null or terrain.mesh == null or body == null or root.has_meta("terrain_stamped"):
		return
	root.set_meta("terrain_stamped", true)
	var arrays := terrain.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var grid := _Grid.new()
	if not grid.build(verts, terrain.global_transform):
		push_warning("TerrainStamp: terrain is not a regular grid; skipped")
		return
	_own(body, grid)
	# temporary proxies of the registered structures
	var proxies: Array[StaticBody3D] = []
	var zones: Array = []
	for fp: Array in (WorldLanes.FOOTPRINTS if WorldLanes.legacy else []):
		var mi := root.get_node_or_null(String(fp[0])) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var sh := mi.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if sh == null:
			continue
		sh.backface_collision = true
		var pb := StaticBody3D.new()
		pb.collision_layer = PROXY
		pb.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = sh
		pb.add_child(cs)
		root.add_child(pb)
		pb.global_transform = mi.global_transform
		proxies.append(pb)
		var bb := mi.global_transform * mi.get_aabb()
		var clip: AABB = fp[1]
		zones.append([bb.intersection(clip) if clip.size != Vector3.ZERO else bb, float(fp[2])])
	if proxies.is_empty() and WorldLanes.sites.is_empty():
		return
	await root.get_tree().physics_frame
	var space := (root as Node3D).get_world_3d().direct_space_state
	var delta := {}          # grid index -> dy
	var hard := {}           # grid indices whose cut ends at a wall: no falloff from them
	for z: Array in zones:
		var box: AABB = z[0]
		var max_adj: float = z[1]
		for idx in grid.indices_in(box.position.x, box.position.z, box.end.x, box.end.z):
			var w := grid.world(idx)
			var th := w.y
			var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(w + Vector3.UP * 0.02, w + Vector3.UP * max_adj, PROXY))
			var dy := 0.0
			if up and (up.normal as Vector3).y < -0.3:
				dy = (up.position as Vector3).y - CONTACT - th        # rise to the underside
			else:
				var dn := space.intersect_ray(PhysicsRayQueryParameters3D.create(w + Vector3.UP * 0.02, w + Vector3.DOWN * max_adj, PROXY))
				if dn and (dn.normal as Vector3).y > 0.6:
					dy = (dn.position as Vector3).y - CONTACT - 0.02 - th   # drop under a buried walk surface
			if absf(dy) > 0.02 and (not delta.has(idx) or absf(dy) > absf(float(delta[idx]))):
				delta[idx] = dy
	# registered building sites: cut the ground down to the site's cut height inside the footprint
	# (never fill: a building's foundation goes below grade, so a downhill gap is just more plinth)
	for st in WorldLanes.sites:
		var r: Rect2 = (st.rect as Rect2).grow(0.6)
		for idx in grid.indices_in(r.position.x, r.position.y, r.end.x, r.end.y):
			var w := grid.world(idx)
			var fy := WorldLanes.site_floor(st, Vector2(w.x, w.z), 0.6)
			if is_nan(fy):
				continue
			var target: float = (fy - 0.05) if st.get("level", false) else (float(st.cut_y) if not st.has("seg") else fy - 0.35)
			var dy: float = target - w.y
			if not st.get("level", false) and dy > -0.02:
				continue                    # rect sites and flights only cut
			if absf(dy) < 0.02:
				continue
			if not delta.has(idx) or absf(dy) > absf(float(delta[idx])):
				delta[idx] = dy
				if st.get("hard", false):
					hard[idx] = true
	for pb in proxies:
		pb.queue_free()
	if delta.is_empty():
		print("TERRAIN_STAMP nothing to fix")
		return
	# falloff: every stamped vertex pushes its neighbours within FALLOFF, smoothstep-weighted;
	# a neighbour keeps the strongest push (core vertices keep their exact value)
	var out := delta.duplicate()
	var r := ceili(FALLOFF / grid.step)
	for idx: int in delta:
		if hard.has(idx):
			continue
		var dv: float = delta[idx]
		var ci := idx % grid.nx
		var cj := idx / grid.nx
		for j in range(cj - r, cj + r + 1):
			for i in range(ci - r, ci + r + 1):
				if i < 0 or j < 0 or i >= grid.nx or j >= grid.nz:
					continue
				var n := j * grid.nx + i
				if delta.has(n):
					continue
				var d := Vector2(i - ci, j - cj).length() * grid.step
				if d > FALLOFF:
					continue
				var t := 1.0 - d / FALLOFF
				var v := dv * t * t * (3.0 - 2.0 * t)
				if not out.has(n) or absf(v) > absf(float(out[n])):
					out[n] = v
	_write(terrain, body, grid, arrays, verts, out)
	WorldLanes.clear_cache()
	print("TERRAIN_STAMP %d vertices stamped, %d blended" % [delta.size(), out.size() - delta.size()])


## Apply a per-grid-vertex height delta to the terrain mesh (verts + normals) and its collision.
static func _write(terrain: MeshInstance3D, body: StaticBody3D, grid: _Grid, arrays: Array, verts: PackedVector3Array, out: Dictionary) -> void:
	_own(body, grid)
	for idx: int in out:
		_dh[idx] = float(_dh.get(idx, 0.0)) + float(out[idx])
	var inv := terrain.global_transform.affine_inverse()
	for idx: int in out:
		var vi: int = grid.vert_of[idx]
		if vi < 0:
			continue
		var wv := terrain.global_transform * verts[vi]
		verts[vi] = inv * (wv + Vector3.UP * float(out[idx]))
	# normals of the touched vertices, from their grid neighbours
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for idx: int in out:
			var vi: int = grid.vert_of[idx]
			if vi >= 0:
				nrm[vi] = grid.normal_at(idx, verts, terrain.global_transform)
		arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain.mesh.surface_get_material(0))
	terrain.mesh = mesh
	# collision follows: shift each face vertex by the same field (bilinear between grid points)
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs == null or not (cs.shape is ConcavePolygonShape3D):
			continue
		var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
		var xf := body.global_transform * cs.transform
		var xi := xf.affine_inverse()
		for k in faces.size():
			var wp := xf * faces[k]
			var dy := grid.field(out, wp.x, wp.z)
			if dy != 0.0:
				faces[k] = xi * (wp + Vector3.UP * dy)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = (cs.shape as ConcavePolygonShape3D).backface_collision
		shape.set_faces(faces)
		cs.shape = shape


class _Grid:
	var nx := 0
	var nz := 0
	var x0 := 0.0
	var z0 := 0.0
	var step := 1.0
	var vert_of := PackedInt32Array()     # grid index -> vertex index (-1 none)
	var ys := PackedFloat32Array()        # world y per grid index
	var xf := Transform3D.IDENTITY

	func build(verts: PackedVector3Array, t: Transform3D) -> bool:
		xf = t
		var xs := {}
		var zs := {}
		for v in verts:
			var w := t * v
			xs[roundi(w.x * 100.0)] = true
			zs[roundi(w.z * 100.0)] = true
		var xk: Array = xs.keys()
		var zk: Array = zs.keys()
		xk.sort()
		zk.sort()
		if xk.size() < 2 or zk.size() < 2:
			return false
		nx = xk.size()
		nz = zk.size()
		x0 = float(xk[0]) / 100.0
		z0 = float(zk[0]) / 100.0
		step = (float(xk[1]) - float(xk[0])) / 100.0
		if step < 0.05 or nx * nz > verts.size() * 2:
			return false
		vert_of.resize(nx * nz)
		vert_of.fill(-1)
		ys.resize(nx * nz)
		for vi in verts.size():
			var w := t * verts[vi]
			var i := roundi((w.x - x0) / step)
			var j := roundi((w.z - z0) / step)
			if i >= 0 and j >= 0 and i < nx and j < nz:
				vert_of[j * nx + i] = vi
				ys[j * nx + i] = w.y
		return true

	func world(idx: int) -> Vector3:
		return Vector3(x0 + float(idx % nx) * step, ys[idx], z0 + float(idx / nx) * step)

	func indices_in(ax: float, az: float, bx: float, bz: float) -> PackedInt32Array:
		var out := PackedInt32Array()
		var i0 := clampi(floori((ax - x0) / step), 0, nx - 1)
		var i1 := clampi(ceili((bx - x0) / step), 0, nx - 1)
		var j0 := clampi(floori((az - z0) / step), 0, nz - 1)
		var j1 := clampi(ceili((bz - z0) / step), 0, nz - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				if vert_of[j * nx + i] >= 0:
					out.append(j * nx + i)
		return out

	func field(d: Dictionary, x: float, z: float) -> float:
		var fx := (x - x0) / step
		var fz := (z - z0) / step
		var i := floori(fx)
		var j := floori(fz)
		if i < 0 or j < 0 or i >= nx - 1 or j >= nz - 1:
			return 0.0
		var tx := fx - float(i)
		var tz := fz - float(j)
		var a: float = d.get(j * nx + i, 0.0)
		var b: float = d.get(j * nx + i + 1, 0.0)
		var c: float = d.get((j + 1) * nx + i, 0.0)
		var e: float = d.get((j + 1) * nx + i + 1, 0.0)
		if a == 0.0 and b == 0.0 and c == 0.0 and e == 0.0:
			return 0.0
		return lerpf(lerpf(a, b, tx), lerpf(c, e, tx), tz)

	func normal_at(idx: int, verts: PackedVector3Array, t: Transform3D) -> Vector3:
		var i := idx % nx
		var j := idx / nx
		var h := func(ii: int, jj: int) -> float:
			ii = clampi(ii, 0, nx - 1)
			jj = clampi(jj, 0, nz - 1)
			var vi: int = vert_of[jj * nx + ii]
			return (t * verts[vi]).y if vi >= 0 else 0.0
		var dx: float = float(h.call(i + 1, j)) - float(h.call(i - 1, j))
		var dz: float = float(h.call(i, j + 1)) - float(h.call(i, j - 1))
		var n := Vector3(-dx, 2.0 * step, -dz).normalized()
		return (t.basis.inverse() * n).normalized()

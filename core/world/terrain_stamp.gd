class_name TerrainStamp
extends RefCounted
## Terrain yields to architecture. Before any prop is seated, the hub terrain (a 2 m grid mesh +
## a matching trimesh) is adjusted under every registered site:
##   - where a structure's underside floats above the ground, the ground rises to meet it;
##   - where the ground covers a structure's walk surface, it drops just below it;
## then the change fades out over FALLOFF metres so no ridge or pit is left at the edge.

const CONTACT := Metrics.CONTACT
const FALLOFF := 4.0         ## metres over which a stamp blends back into the original ground


## How far the ground moved (site stamps), per grid vertex of the current terrain. Baked scatter
## was planted on the old ground; SeatProps adds delta_at() before it snaps to the new one.
static var _dh := {}
static var _settled := {}          ## the same, for settle()'s lowering alone
static var _dh_grid: _Grid
static var _dh_owner := 0


## Total ground height change at (x, z) since the baked terrain, bilinear between grid vertices.
static func delta_at(x: float, z: float) -> float:
	if _dh_grid == null or _dh.is_empty() or not is_instance_valid(instance_from_id(_dh_owner)):
		return 0.0
	return _dh_grid.field(_dh, x, z)


## The part of delta_at() that settle() added: what the ground dropped after the buildings stood, when things
## were already seated on it (GroundFollow lowers those by this).
static func settle_delta_at(x: float, z: float) -> float:
	if _dh_grid == null or _settled.is_empty() or not is_instance_valid(instance_from_id(_dh_owner)):
		return 0.0
	return _dh_grid.field(_settled, x, z)


static func _own(body: StaticBody3D, grid: _Grid) -> void:
	if _dh_owner != body.get_instance_id():
		_dh = {}
		_settled = {}
		_dh_grid = grid
		_dh_owner = body.get_instance_id()


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
	if WorldLanes.sites.is_empty():
		return
	await root.get_tree().physics_frame
	var delta := {}          # grid index -> dy
	var hard := {}           # grid indices whose cut ends at a wall: no falloff from them
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
	var heaped := {}
	for m: Dictionary in mounds:
		heaped.merge(_mound_delta(grid, m))
	mounds.clear()
	if delta.is_empty() and heaped.is_empty():
		print("TERRAIN_STAMP nothing to fix")
		return
	var out := _spread(delta, hard, grid)
	for idx: int in heaped:
		if not out.has(idx) or float(out[idx]) < float(heaped[idx]):
			out[idx] = heaped[idx]
	if not heaped.is_empty():
		var lo := 0.0
		var hi := 0.0
		for v: float in heaped.values():
			lo = minf(lo, v)
			hi = maxf(hi, v)
		print("TERRAIN_MOUND %d vertices heaped under roots and the like (%.2f .. %.2f)" % [heaped.size(), lo, hi])
	_write(terrain, body, grid, arrays, verts, out)
	WorldLanes.clear_cache()
	print("TERRAIN_STAMP %d vertices stamped, %d blended" % [delta.size(), out.size() - delta.size()])


## Falloff: every stamped vertex pushes its neighbours within FALLOFF, smoothstep-weighted; a
## neighbour keeps the strongest push (core vertices keep their exact value).
static func _spread(delta: Dictionary, hard: Dictionary, grid: _Grid) -> Dictionary:
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
	return out


const SETTLE_GAP := 0.04         ## the ground ends this far under a floor that stands on it
const SETTLE_BELOW := 0.25       ## a walk surface this far under a site's floor height ...
const SETTLE_ABOVE := 0.35       ## ... or this far over it is that site's floor
const SETTLE_STEP := 0.5
const SETTLE_BURIED := 0.45      ## a floor buried deeper than this is in the hillside (a cellar, a sunk boathouse): the ground is left alone
const SETTLE_DEEPEST := 1.5      ## and no vertex drops further than this


## The ground height and the walk surface that meets it near `fy` under p, as Vector2(ground,
## floor) (NAN where there is none): the walk surface nearest the ground, so a floor the ground has
## swallowed or fights is found, and a stepped yard's upper treads are not. Repeated rays: one body
## holds many shapes.
static func walk_surface(space: PhysicsDirectSpaceState3D, p: Vector2, fy: float) -> Vector2:
	p += Vector2(0.0037, 0.0029)             # off the grid lines: a ray on a triangle edge can slip through
	var ground := NAN
	var tops: Array[float] = []
	var from := Vector3(p.x, fy + 4.0, p.y)  # from well above: a hillside can stand higher than the floor
	var to := Vector3(p.x, fy - 6.0, p.y)
	var skip: Array[RID] = []
	for k in 40:                             # the ground first (whole bodies set aside until the terrain answers)
		var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return Vector2(NAN, NAN)
		skip.append(hit.rid)
		if String((hit.collider as Node).name) == "TerrainBody":
			ground = (hit.position as Vector3).y
			break
	skip = [skip[skip.size() - 1]]           # the terrain only: a floor laid exactly on it must still be seen
	var y0 := from.y
	for k in 40:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, y0, p.y), to, Layers.WORLD)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var y: float = (hit.position as Vector3).y
		y0 = y - 0.0002
		if (hit.normal as Vector3).y > 0.9 and y >= fy - SETTLE_BELOW and y <= fy + SETTLE_ABOVE:
			tops.append(y)
	if is_nan(ground) or tops.is_empty():
		return Vector2(NAN, NAN)
	var best := tops[0]
	for y in tops:                                  # the surface nearest the site's floor height (a stepped yard has several)
		if absf(y - fy) < absf(best - fy) - 0.0005:
			best = y
	return Vector2(ground, best)


## After every building is standing: wherever a walk surface (the real colliders) lies inside a
## registered site and the ground there is within SETTLE_GAP of it or above it, the grid vertices of
## that terrain cell drop to SETTLE_GAP under the lowest floor they touch. The stamp cut to a figure
## decided before the building existed; this measures the floor that was built. Only ever lowers.
static func settle(root: Node) -> void:
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	var body := root.find_child("TerrainBody", true, false) as StaticBody3D
	if terrain == null or terrain.mesh == null or body == null or WorldLanes.sites.is_empty():
		return
	for pass_n in 3:           # each sees what the one before's blending brought up to a floor
		await root.get_tree().physics_frame
		if not _settle_pass(root, terrain, body, pass_n == 0):
			return


static func _settle_pass(root: Node, terrain: MeshInstance3D, body: StaticBody3D, report: bool) -> bool:
	var arrays := terrain.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var grid := _Grid.new()
	if not grid.build(verts, terrain.global_transform):
		return false
	var space := (root as Node3D).get_world_3d().direct_space_state
	var cap := {}            # grid index -> the highest this vertex may stand
	var fixed := 0
	var deep := {}
	for st: Dictionary in WorldLanes.sites:
		if not WorldLanes.is_floor_site(st):
			continue
		var r: Rect2 = st.rect
		var fy: float = st.floor_y
		var x := r.position.x + SETTLE_STEP * 0.5
		while x < r.end.x:
			var z := r.position.y + SETTLE_STEP * 0.5
			while z < r.end.y:
				var p := Vector2(x, z)
				z += SETTLE_STEP
				if is_nan(WorldLanes.site_floor(st, p)):
					continue
				var s := walk_surface(space, p, fy)
				if not is_nan(s.x) and not is_nan(s.y) and s.x - s.y > SETTLE_BURIED:
					deep[st.name] = int(deep.get(st.name, 0)) + 1
				if is_nan(s.x) or is_nan(s.y) or s.x < s.y - SETTLE_GAP or s.x - s.y > SETTLE_BURIED:
					continue                       # no floor or no ground here, already clear, or a cellar
				var fi := floori((p.x - grid.x0) / grid.step)
				var fj := floori((p.y - grid.z0) / grid.step)
				fixed += 1
				for dj in 2:
					for di in 2:
						var i := fi + di
						var j := fj + dj
						if i < 0 or j < 0 or i >= grid.nx or j >= grid.nz:
							continue
						var idx := j * grid.nx + i
						cap[idx] = minf(float(cap.get(idx, INF)), s.y - SETTLE_GAP)
			x += SETTLE_STEP
	if report and not deep.is_empty():
		print("TERRAIN_SETTLE floors left in the hillside (ground over 45 cm above): ", deep)
	var delta := {}
	for idx: int in cap:
		if grid.vert_of[idx] < 0:
			continue
		var dy: float = float(cap[idx]) - grid.ys[idx]
		if dy < -0.005:
			delta[idx] = maxf(dy, -SETTLE_DEEPEST)
	if delta.is_empty():
		return false
	var out := _spread(delta, {}, grid)
	_write(terrain, body, grid, arrays, verts, out)
	for idx: int in out:
		_settled[idx] = float(_settled.get(idx, 0.0)) + float(out[idx])
	WorldLanes.clear_cache()
	print("TERRAIN_SETTLE %d floor samples met the ground; %d vertices lowered, %d blended" % [fixed, delta.size(), out.size() - delta.size()])
	return true


## Earth heaped under something modelled for flat ground (a colossal tree's roots), queued before the stamp
## (so the flora grows on it): {c: Vector2 centre, core: float, out: float, bins: int, ring: PackedFloat32Array}.
## `ring` holds a world y per metre of distance d and angle bin (index d * bins + a, NAN for none); within `core`
## of the centre the ground rises to it (bilinear between bins), and from core to out it blends back to the land
## as it was. Only ever raises. apply() raises it and clears the queue.
static var mounds: Array[Dictionary] = []


static func _mound_y(m: Dictionary, d: float, ang: float) -> float:
	var ring: PackedFloat32Array = m.ring
	var n: int = m.bins
	var rows := ring.size() / n
	var fa := ang / TAU * float(n)
	var a0 := (floori(fa) % n + n) % n
	var a1 := (a0 + 1) % n
	var ta := fa - floorf(fa)
	var d0 := mini(int(d), rows - 1)
	var d1 := mini(d0 + 1, rows - 1)
	var td := clampf(d - float(d0), 0.0, 1.0)
	var y0 := lerpf(ring[d0 * n + a0], ring[d0 * n + a1], ta)
	var y1 := lerpf(ring[d1 * n + a0], ring[d1 * n + a1], ta)
	return lerpf(y0, y1, td)


static func _mound_delta(grid: _Grid, m: Dictionary) -> Dictionary:
	var raw := {}
	var c: Vector2 = m.c
	var core: float = m.core
	var reach: float = m.out
	for idx in grid.indices_in(c.x - reach, c.y - reach, c.x + reach, c.y + reach):
		var w := grid.world(idx)
		var off := Vector2(w.x, w.z) - c
		var d := off.length()
		if d > reach:
			continue
		var tgt := _mound_y(m, minf(d, core), atan2(off.x, off.y))
		var dy := 0.0
		if not is_nan(tgt):
			dy = maxf(tgt - w.y, 0.0) * (1.0 - smoothstep(core, reach, d)) * smoothstep(2.0, 5.0, d)
		raw[idx] = dy
	# one vertex standing up alone is a spike on a 2 m grid: two passes of a 3 x 3 mean make the heap one swell
	for pass_n in 4:
		var soft := {}
		for idx: int in raw:
			var sum := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					sum += float(raw.get(idx + dj * grid.nx + di, 0.0))
			soft[idx] = sum / 9.0
		raw = soft
	var out := {}
	for idx: int in raw:
		var dy := float(raw[idx])
		if m.has("floor"):                       # inside the hollow the floor is level, whatever the land did there
			var w := grid.world(idx)
			var d := Vector2(w.x, w.z).distance_to(c)
			var wf := 1.0 - smoothstep(5.3, 6.3, d)
			var off := absf(wrapf(atan2(w.x - c.x, w.z - c.y) - float(m.door), -PI, PI))
			var wd := (1.0 - smoothstep(0.35, 1.0, off)) * (1.0 - smoothstep(10.0, 14.0, d)) * (1.0 - wf)
			var ramp := float(m.sill) - float(m.ramp) * maxf(d - 6.2, 0.0)       # the doorway's approach, up or down to it
			dy = lerpf(lerpf(dy, float(m.floor) - w.y, wf), ramp - w.y, wd)
		if absf(dy) > 0.02:
			out[idx] = dy
	return out


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

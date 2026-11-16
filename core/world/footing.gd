extends RefCounted
## (No class_name: const Footing := preload("res://core/world/footing.gd").)
## Seating a rigid prop on uneven ground. A prop modelled on a flat floor and set down by one ground
## sample hangs over the land on its downhill side. Here the prop's footing (the lowest vertices of its
## mesh, one per small cell) is turned and scaled as it stands, the ground is read under each, and the
## origin is lowered until none of them is more than GAP over the ground. Only ever lowers, and never by
## more than `cap`: past that the prop is on a cliff and the land is the problem.

const GAP := 0.03
static var _cache := {}            ## Mesh -> PackedVector3Array


## The lowest vertices of `mesh` (those within `slab` of its lowest), the lowest one in each `cell` square.
static func base_points(mesh: Mesh, slab := 0.35, cell := 0.3) -> PackedVector3Array:
	if mesh == null:
		return PackedVector3Array()
	if _cache.has(mesh):
		return _cache[mesh]
	var faces := mesh.get_faces()
	var lo := INF
	for v in faces:
		lo = minf(lo, v.y)
	var cells := {}
	for v in faces:
		if v.y < lo + slab:
			var key := Vector2i(roundi(v.x / cell), roundi(v.z / cell))
			if not cells.has(key) or (cells[key] as Vector3).y > v.y:
				cells[key] = v
	var pts := PackedVector3Array(cells.values())
	_cache[mesh] = pts
	return pts


## The y for the prop's origin at `at` (x, z) so its footing `pts`, turned by `basis`, stands no more than
## GAP over `ground` (a Callable x, z -> y). `y0` is where it would stand otherwise; `cap` the deepest it
## may be lowered from y0.
static func seat_y(ground: Callable, pts: PackedVector3Array, basis: Basis, at: Vector2, y0: float, cap: float) -> float:
	var out := y0
	for v in pts:
		var w := basis * v
		var g: float = ground.call(at.x + w.x, at.y + w.z)
		out = minf(out, g + GAP - w.y)
	return maxf(out, y0 - cap)


## terrain_y as a ground Callable for seat_y, the macro height its fallback (worked out only when it is needed).
static func terrain_fn(space: PhysicsDirectSpaceState3D) -> Callable:
	return func(x: float, z: float) -> float:
		var g := terrain_y(space, x, z, NAN)
		return RealmLayout.macro_height(x, z) if is_nan(g) else g


## The terrain's own height at (x, z): the ray passes through props (their colliders are on the same layer)
## to the ground. `fallback` where there is none. While the Realm builds, TerrainStamp.ground_at() gives the same
## figure from the terrain's grid (a cliff's footing was a few hundred rays).
static func terrain_y(space: PhysicsDirectSpaceState3D, x: float, z: float, fallback: float) -> float:
	var g := TerrainStamp.ground_at(x + 0.0037, z + 0.0029)      # while the Realm builds: the terrain's triangles, no rays
	if g >= -60.0 and g <= 160.0:
		return g
	var ex: Array[RID] = []
	for i in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 160.0, z + 0.0029), Vector3(x + 0.0037, -60.0, z + 0.0029), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return fallback

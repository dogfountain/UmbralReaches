extends RefCounted
## (No class_name: const GroundSeat := preload("res://core/world/realm/ground_seat.gd").)
## the one way a placing system sets a rigid piece on uneven ground. A piece modelled on a flat floor and set down by one
## ground sample hangs over the land on its downhill side (the grounding probe's float) or, on a rise, buries its door. Here the piece's
## footing (its mesh's lowest vertices, Footing.base_points) is read against the ground under each point as it stands, and the origin is
## lowered until the lowest-standing point touches (and raised again when the whole base is buried past `allow`). Pieces that lie on the
## ground (logs, planks, bones, flags) can also take its normal (`lie`). Build-time only: no rays when TerrainStamp's grid is up.

const Footing := preload("res://core/world/footing.gd")
const StoneProps := preload("res://core/world/realm/lore/stone_props.gd")

const STAND := 0.2                   ## an origin this far over the ground or less is 'on the ground'

static var _file_pts := {}           ## glb file -> PackedVector3Array (the model's footing, every part)


const Land := preload("res://core/world/realm/realm_land.gd")


## The build's ground as a Callable x, z -> y with no ray: the terrain's own triangles while the Realm builds (TerrainStamp.ground_at), the land's height
## formula where the grid does not answer.
static func fast_fn() -> Callable:
	return func(x: float, z: float) -> float:
		var g := TerrainStamp.ground_at(x + 0.0037, z + 0.0029)
		return g if g >= -60.0 and g <= 160.0 else Land.height_at(x, z)


static func release() -> void:
	_file_pts.clear()


## The footing of a stone-model glb (every part's lowest vertices, the global lowest slab kept).
static func file_points(file: String) -> PackedVector3Array:
	if _file_pts.has(file):
		return _file_pts[file]
	var all := PackedVector3Array()
	var lo := INF
	for p: Dictionary in (StoneProps.info(file).parts as Array):
		for v: Vector3 in Footing.base_points(p.mesh as Mesh):
			all.append(v)
			lo = minf(lo, v.y)
	var out := PackedVector3Array()
	for v: Vector3 in all:
		if v.y < lo + 0.35:
			out.append(v)
	_file_pts[file] = out
	return out


## The footing of several meshes (a model's parts) kept under `key`.
static func parts_points(key: String, meshes: Array) -> PackedVector3Array:
	if _file_pts.has(key):
		return _file_pts[key]
	var all := PackedVector3Array()
	var lo := INF
	for m: Mesh in meshes:
		for v: Vector3 in Footing.base_points(m):
			all.append(v)
			lo = minf(lo, v.y)
	var out := PackedVector3Array()
	for v: Vector3 in all:
		if v.y < lo + 0.35:
			out.append(v)
	_file_pts[key] = out
	return out


## `xf` with its origin lowered (never more than `cap`) so the footing `pts` stands on the ground; raised by up to `raise` when every
## point is buried deeper than `allow`.
static func seat_pts(ground: Callable, pts: PackedVector3Array, xf: Transform3D, cap := 1.0, allow := 0.55, raise := 0.4) -> Transform3D:
	if pts.is_empty():
		return xf
	var at := Vector2(xf.origin.x, xf.origin.z)
	if xf.origin.y > float(ground.call(at.x, at.y)) + STAND:
		return xf                                # its origin is set above the ground on purpose (on a plinth, a deck, a step): not the land's to seat
	var y := Footing.seat_y(ground, pts, xf.basis, at, xf.origin.y, cap)
	if y <= xf.origin.y - cap + 0.001:
		return xf                                # further up than `cap`: it stands on a wall, a step or a rise of its own, not on the land
	if y >= xf.origin.y - 0.0001:
		# nothing lowered: are all points buried? lift to `allow` under the lowest-gap point
		var gap := INF
		for v: Vector3 in pts:
			var w := xf.basis * v
			gap = minf(gap, (xf.origin.y + w.y) - float(ground.call(at.x + w.x, at.y + w.z)))
		if gap < -allow:
			y = xf.origin.y + minf(raise, -gap - allow)
	return Transform3D(xf.basis, Vector3(xf.origin.x, y, xf.origin.z))


static func seat_mesh(ground: Callable, mesh: Mesh, xf: Transform3D, cap := 1.0) -> Transform3D:
	return seat_pts(ground, Footing.base_points(mesh), xf, cap)


static func seat_file(ground: Callable, file: String, xf: Transform3D, cap := 1.0) -> Transform3D:
	return seat_pts(ground, file_points(file), xf, cap)


## A basis that stands `basis` on a ground whose normal under `at` is worked out from four samples 0.5 m round it; `k` = how much of the
## slope it takes (1 = lies flat on it, 0.5 = half).
static func lie(ground: Callable, at: Vector2, basis: Basis, k := 1.0) -> Basis:
	var e := 0.5
	var dx := float(ground.call(at.x + e, at.y)) - float(ground.call(at.x - e, at.y))
	var dz := float(ground.call(at.x, at.y + e)) - float(ground.call(at.x, at.y - e))
	var n := Vector3(-dx, 2.0 * e, -dz).normalized()
	var tilt := Quaternion(Vector3.UP, Vector3.UP.lerp(n, k).normalized())
	return Basis(tilt) * basis

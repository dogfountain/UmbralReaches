extends RefCounted
## The West Reach (docs/far_reaches.md): helpers its four builders share. Models are the in-house glbs of
## tools/blender/reach_west*.py (art/models/reach_w_*.glb), dressed by west_marches_kit.gd; everything is placed by ground
## ray at build time. No class_name: preload by path.

const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const Pois := preload("res://core/world/realm/realm_pois.gd")

const LOOT := {
	"keep_top": ["iron", {"grave_ash": 22, "grave_iron": 2, "relic_fragment": 1}],
	"keep_hall": ["wood", {"grave_ash": 10, "grave_iron": 1}],
	"fell_shrine": ["reliquary", {"grave_ash": 16, "relic_fragment": 1}],
	"caps_ring": ["wood", {"grave_ash": 12}],
	"milestone_toll": ["wood", {"grave_ash": 9, "grave_iron": 1}],
	"king_barrow": ["reliquary", {"grave_ash": 26, "relic_fragment": 2}],
	"row_cist": ["iron", {"grave_ash": 14, "grave_iron": 1}],
	"reedholm_loft": ["wood", {"grave_ash": 9}],
	"heron_cache": ["wood", {"grave_ash": 12, "relic_fragment": 1}],
}


## A POI host (group world_poi) with the contract's metas.
static func host(holder: Node3D, space: PhysicsDirectSpaceState3D, id: String, d: Dictionary) -> Node3D:
	var at: Vector2 = d.at
	var h := Node3D.new()
	h.name = "Poi_" + id
	h.set_meta("site", "poi_" + id)
	holder.add_child(h)
	h.add_to_group("world_poi")
	h.set_meta("reach", true)
	h.set_meta("poi", id)
	h.set_meta("title", d.title)
	h.set_meta("line", d.line)
	h.set_meta("region", d.region)
	h.set_meta("centre", Vector3(at.x, RealmLayout.ground(space, at.x, at.y), at.y))
	h.set_meta("radius", float(d.r))
	h.set_meta("reach_west", true)
	return h


## The highest solid surface over xz (a ray down from 90 m), as a point, or Vector3.INF.
static func top(space: PhysicsDirectSpaceState3D, x: float, z: float, from_y := 90.0) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -40.0, z), Layers.WORLD))
	return (hit.position as Vector3) if hit else Vector3.INF


static func chest(h: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	h.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


static func lore(h: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	h.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


## A model placed at xz on the ground (y from the ray unless given), yaw about up; `far` = [AABB, taper, colour, near_end]
## registers a hull silhouette, `far_node` the name prefix of a far mesh in the file itself.
static func model(h: Node3D, space: PhysicsDirectSpaceState3D, file: String, at: Vector2, yaw: float, y := NAN, opts := {}) -> Node3D:
	var gy := y if not is_nan(y) else RealmLayout.ground(space, at.x, at.y)
	var root := Kit.place(h, file, Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, gy, at.y)), opts)
	if root == null:
		return null
	var fn := String(opts.get("far_node", ""))
	if fn != "":
		for n in root.find_children(fn + "*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var mesh := mi.mesh
			mi.get_parent().remove_child(mi)
			mi.queue_free()
			FarDetail.register(root, mesh, Transform3D.IDENTITY, float(opts.get("far_from", 150.0)))
			break
	elif opts.has("far"):
		var f: Array = opts.far
		FarDetail.register(root, FarDetail.hull(f[0], f[1], f[2]), Transform3D.IDENTITY, f[3])
	return root


static func anchor(h: Node3D, at: Vector3, stand: Vector3, reach := 22.0) -> Node3D:
	return Pois._grapple(h, at, stand, reach, true)


static func perch(h: Node3D, at: Vector3, facing: Vector3, drop := 60.0) -> Node3D:
	return Pois._perch(h, at, facing, drop)


## A rim of the `n` highest, well-spread standing surfaces on a footprint (grapple anchors and a perch for a tall ruin).
static func high_points(space: PhysicsDirectSpaceState3D, centre: Vector2, half: Vector2, step: float, min_h: float, n: int, spread: float) -> Array:
	var best: Array = []
	var x := centre.x - half.x
	while x <= centre.x + half.x:
		var z := centre.y - half.y
		while z <= centre.y + half.y:
			var t := top(space, x, z)
			if t != Vector3.INF and t.y >= min_h:
				best.append(t)
			z += step
		x += step
	best.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var out: Array = []
	for p: Vector3 in best:
		var ok := true
		for q: Vector3 in out:
			if Vector2(p.x - q.x, p.z - q.z).length() < spread:
				ok = false
				break
		if ok:
			out.append(p)
			if out.size() >= n:
				break
	return out

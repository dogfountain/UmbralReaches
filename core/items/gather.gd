extends Node
## Gathering (r33): lays the Realm's ash-blooms and grave-iron stones (gather_node.gd) once the
## terrain stands. Added by progression.gd beside the gear runtime; it does not touch any world
## scene. Sites are seeded (the same every night), off the walked paths, out of Hearthward, the
## rift and the crypt, on open terrain, at least SPACING apart:
##   ash-bloom   meadow, heath, glade, the Thornwood, the chapel's ruin  (BLOOMS sites)
##   grave-iron  the Hollow Fen and the Barrow Field, the heath, the Crowns' foot, ruins (IRON sites)
## What they feed: Hild smelts grave-iron into ember shards and forges it into fire-dogs; Bet and
## the Keg cook with ash-blooms (hearth_db.gd TRADES, MEALS and WORKS that name "mats").
## No class_name; group "gathering".

const GatherNode := preload("res://core/items/gather_node.gd")
const SEED := 3301
## r34 places: the Realm doubled (docs/r34/layout.md), so the counts doubled to keep the density (r33:
## 16 blooms, 12 stones over 50,600 m2); the Cinder Orchard's ash grows blooms, the Founder's Pits'
## slag and the Saints' Quarry's benches hold grave-iron (the "ash" biome joined both lists).
const BLOOMS := 32
const IRON := 24
const SPACING := 9.0
const BLOOM_BIOMES := ["meadow", "heath", "glade", "oldforest", "ruin", "ash"]
const IRON_BIOMES := ["fen", "heath", "crag", "ruin", "ash"]
const HOME := Vector2(0.0, 33.0)
const HOME_KEEP := 34.0
const RIFT := Rect2(-34.0, -122.0, 68.0, 114.0)

var sites: Array = []          ## [[kind, Vector3]] laid


func _ready() -> void:
	name = "Gathering"
	add_to_group("gathering")
	_lay.call_deferred()


func _lay() -> void:
	if not is_inside_tree():
		return
	for i in 3:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var root := get_parent()
	var space := (root as Node3D).get_world_3d().direct_space_state if root is Node3D else get_viewport().find_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var taken: Array[Vector2] = []
	for spec: Array in [["ash_bloom", BLOOMS, BLOOM_BIOMES], ["grave_iron", IRON, IRON_BIOMES]]:
		var placed := 0
		var tries := 0
		while placed < int(spec[1]) and tries < 1800:
			tries += 1
			var b := RealmLayout.BOUNDS.grow(-10.0)
			var xz := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
			var y := _site_ok(space, xz, spec[2], taken)
			if is_nan(y):
				continue
			taken.append(xz)
			var n: Node3D = GatherNode.new()
			n.set("kind", String(spec[0]))
			n.set("rng_seed", SEED + taken.size())
			n.name = "Gather_%s_%d" % [String(spec[0]), placed]
			add_child(n)
			n.global_position = Vector3(xz.x, y, xz.y)
			sites.append([String(spec[0]), n.global_position])
			placed += 1


## The ground height at `xz` when it is a good site, else NAN.
func _site_ok(space: PhysicsDirectSpaceState3D, xz: Vector2, biomes: Array, taken: Array[Vector2]) -> float:
	if xz.distance_to(HOME) < HOME_KEEP or RIFT.has_point(xz):
		return NAN
	if not biomes.has(RealmLayout.biome_at(xz.x, xz.y)):
		return NAN
	if RealmLayout.path_dist(xz) < 3.5:
		return NAN
	if not WorldLanes.site_at(xz, 1.0).is_empty():
		return NAN                                   # r34 layout: never on a site (the raid floors above all)
	for t in taken:
		if t.distance_to(xz) < SPACING:
			return NAN
	var mh := RealmLayout.macro_height(xz.x, xz.y)
	if mh > 18.0 or mh < -0.7:
		return NAN                                   # the Crowns' heights, the fen's pools
	if space == null:
		return mh
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x + 0.0037, 120.0, xz.y + 0.0029), Vector3(xz.x, -60.0, xz.y), 1))
	if hit.is_empty():
		return NAN
	if not String((hit.collider as Node).name).begins_with("Terrain"):
		return NAN                                   # a rock, a wall, a roof: not open ground
	var nrm: Vector3 = hit.normal
	if nrm.y < 0.8:
		return NAN                                   # too steep
	return (hit.position as Vector3).y

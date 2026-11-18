extends RefCounted
## Where the night may put a hostile: one set of rules for every spawner (the camps and their patrols, the
## Gloom tide's hunters, the road ambushes, the surges, the roaming events, the rares, elites and guardians)
## and for zz/spawn_audit, which lists every spawn point against them. Pure/static.
##   safe places  Hearthward (the hub) and its tavern, the Rooted Holds and the towns (Weirford, Saltmarket,
##                Lastlight, Fallowmere, Reedholm): nothing of ours stands inside a place's ring; a camp keeps
##                CAMP_MARGIN beyond it and a patrol PATROL_MARGIN, so a town's door is never a fight
##   ways         a hostile never stands on a way (it rises from the verge, WAY_BERTH off the edge); round the
##                hub (HUB_ROADS_R) the roads keep a wider berth, HUB_BERTH
##   ground       open, walkable floor: not in water past the ankle, not steeper than MAX_SLOPE, not on a
##                ledge's lip (a drop of LIP_DROP within LIP_R), not inside a collider or a prop, not on lava
## Load by path (no class_name):  const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")

const RealmLand := preload("res://core/world/realm/realm_land.gd")

## id, centre, ring radius (nothing of ours inside), and "camp": how far past the ring a camp's centre keeps
## (CAMP_MARGIN unless given: the hub's first camps are its starter fights just past the haven, the Holds' clearing
## has its hermits' neighbours). The towns' rings cover their houses, yards and gates.
const SAFE := [
	{"id": "hearthward", "c": Vector2(4.0, 36.0), "r": 34.0, "camp": 10.0},
	{"id": "holds", "c": Vector2(-134.0, 12.0), "r": 21.0, "camp": 6.0},
	{"id": "weirford", "c": Vector2(-203.0, 66.0), "r": 30.0},
	{"id": "saltmarket", "c": Vector2(213.0, 95.0), "r": 22.0},
	{"id": "lastlight", "c": Vector2(326.0, 46.0), "r": 40.0},
	{"id": "fallowmere", "c": Vector2(-158.0, 300.0), "r": 30.0},
	{"id": "reedholm", "c": Vector2(-324.0, 298.0), "r": 22.0},
]
## The towns among the safe places (the Holds' clearing is safe-ish: nothing rises in it, but the Gloom may well up
## at its hall and the wanderer fights it at the clearing's edge).
const TOWNS := ["hearthward", "weirford", "saltmarket", "lastlight", "fallowmere", "reedholm"]
const CAMP_MARGIN := 22.0          ## a camp's centre this far beyond a safe ring
const PATROL_MARGIN := 14.0        ## a patrol's round this far beyond it
const HUB := Vector2(4.0, 36.0)
const HUB_ROADS_R := 110.0         ## the hub's roads: every way within this of Hearthward
const WAY_BERTH := 2.0             ## off a way's edge (RealmLayout.path_dist is from the edge)
const HUB_BERTH := 6.0
const MAX_SLOPE := 0.78            ## the floor's normal.y (about 39 degrees)
const LIP_R := 1.6
const LIP_DROP := 1.8
const WADE := 0.2                  ## water deeper than this over the floor is water
const LAVA_CLEAR := 3.0            ## above the rift's lava

static var _cap: CapsuleShape3D


## The safe place `p` is in, its ring grown by `margin` ("" when none).
static func safe_at(p: Vector2, margin := 0.0) -> String:
	for s: Dictionary in SAFE:
		if p.distance_to(s.c) < float(s.r) + margin:
			return String(s.id)
	if Rect2(RealmLayout.TAVERN).grow(6.0 + margin).has_point(p):
		return "hearthward"
	return ""


## How far `p` is outside the nearest safe ring (negative inside), which, and the camp margin it asks for.
static func safe_gap(p: Vector2) -> Array:
	var best := INF
	var id := ""
	var margin := CAMP_MARGIN
	for s: Dictionary in SAFE:
		var d := p.distance_to(s.c) - float(s.r)
		if d < best:
			best = d
			id = String(s.id)
			margin = float(s.get("camp", CAMP_MARGIN))
	return [best, id, margin]


## The berth a hostile keeps off the ways at `p` (wider on the hub's roads).
static func berth(p: Vector2) -> float:
	return HUB_BERTH if p.distance_to(HUB) < HUB_ROADS_R else WAY_BERTH


static func on_way(p: Vector2) -> bool:
	return RealmLayout.path_dist(p) < berth(p)


## Water over the floor at `at` (0 when dry or on a deck above it).
static func water_depth(at: Vector3) -> float:
	if not RealmLand.in_water(at.x, at.z):
		return 0.0
	return maxf(0.0, RealmLand.water_y_at(at.x, at.z) - at.y)


## The first walkable floor straight down at xz (a tree's trunk or the top of a rock face is no floor).
## Vector3.INF when there is none. `n` gets the floor's normal when given.
static func floor_at(space: PhysicsDirectSpaceState3D, xz: Vector2, from_y := 90.0, depth := 150.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x + 0.0037, from_y, xz.y + 0.0029), Vector3(xz.x + 0.0037, from_y - depth, xz.y + 0.0029), Layers.WORLD)
	var hit := space.intersect_ray(q)
	var skipped: Array[RID] = []
	while not hit.is_empty() and skipped.size() < 6 and EnemySpawner._is_flora_body(hit.collider as Node):
		skipped.append(hit.rid)
		q.exclude = skipped
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	var at: Vector3 = hit.position
	at.x = xz.x
	at.z = xz.y
	return at


## Everything the rules say about a floor point (a camp pawn, a patrol stop, a hunter's spot):
## {ok, why, ny (the floor's normal y), drop (the deepest fall within LIP_R), water (depth), way (m off the
## nearest way's edge), safe (the safe place it is in, if any), solid (a collider in the body's room),
## prop (a prop in it)}. `opts`: "ways": false skips the way rule (a seal guard on the Crossing's deck,
## an ambush's trigger point on the road), "safe": false the safe places (a rare that walks the Holds' edge by
## design), "safe_margin": metres beyond the safe rings. Light is the caller's (LightGrid).
static func assess(space: PhysicsDirectSpaceState3D, at: Vector3, opts := {}) -> Dictionary:
	var out := {"ok": true, "why": "", "ny": 1.0, "drop": 0.0, "water": 0.0, "way": INF, "safe": "", "solid": "", "prop": ""}
	var why := PackedStringArray()
	var xz := Vector2(at.x, at.z)
	if at == Vector3.INF or is_nan(at.y):
		out.ok = false
		out.why = "no floor"
		return out
	if not RealmLayout.BOUNDS.grow(-4.0).has_point(xz):
		why.append("out of bounds")
	var safe := safe_at(xz, float(opts.get("safe_margin", 0.0)))
	out.safe = safe
	if safe != "" and bool(opts.get("safe", true)):
		why.append("in " + safe)
	out.way = RealmLayout.path_dist(xz)
	if bool(opts.get("ways", true)) and float(out.way) < berth(xz):
		why.append("on a way (%.1f m)" % float(out.way))
	if at.y < RealmLayout.LAVA_Y + LAVA_CLEAR:
		why.append("over lava")
	if RealmLayout.in_ossuary(at):
		why.append("in the Ossuary")
	out.water = water_depth(at)
	if float(out.water) > WADE:
		why.append("in water (%.2f m)" % float(out.water))
	if space != null:
		# the floor's slope where it stands
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0.0037, 1.2, 0.0029), at + Vector3(0.0037, -1.5, 0.0029), Layers.WORLD))
		if not hit.is_empty():
			out.ny = (hit.normal as Vector3).y
			if float(out.ny) < MAX_SLOPE:
				why.append("steep (n.y %.2f)" % float(out.ny))
		# a ledge's lip: any fall deeper than LIP_DROP within LIP_R (rising ground beside it is a bank, not a lip)
		var drop := 0.0
		for k in 6:
			var a := TAU * float(k) / 6.0 + 0.3
			var q := xz + Vector2(cos(a), sin(a)) * LIP_R
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, at.y + 6.0, q.y), Vector3(q.x, at.y - 8.0, q.y), Layers.WORLD))
			drop = maxf(drop, (at.y - (h.position as Vector3).y) if not h.is_empty() else 8.0)
		out.drop = drop
		if drop > LIP_DROP:
			why.append("on a lip (%.1f m drop)" % drop)
		# room for a body
		if _cap == null:
			_cap = CapsuleShape3D.new()
			_cap.radius = 0.4
			_cap.height = 1.7
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = _cap
		sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.97, 0.0))
		sq.collision_mask = Layers.WORLD
		var solid := space.intersect_shape(sq, 1)
		if not solid.is_empty():
			out.solid = String((solid[0].collider as Node).name) if solid[0].collider is Node else "?"
			why.append("inside " + String(out.solid))
		sq.collision_mask = Layers.PROPS
		var prop := space.intersect_shape(sq, 32)
		for pr: Dictionary in prop:
			var n := pr.collider as Node
			if n == null or n is Enemy or n is CharacterBody3D or (n.get_parent() is Enemy):
				continue
			out.prop = String(n.name)
			why.append("inside a prop (%s)" % n.name)
			break
	out.ok = why.is_empty()
	out.why = ", ".join(why)
	return out


static func ok(space: PhysicsDirectSpaceState3D, at: Vector3, opts := {}) -> bool:
	return bool(assess(space, at, opts).ok)


## The nearest point to `c` (itself, then rings out to `reach` m) whose floor passes the rules, from `from_y`
## down; within `dy` of `near_y` when that is given (not NAN). Vector3.INF when there is none.
static func find(space: PhysicsDirectSpaceState3D, c: Vector2, reach: float, from_y := 90.0, opts := {}, near_y := NAN, dy := 3.0) -> Vector3:
	var r := 0.0
	while r <= reach + 0.01:
		var n := 1 if r == 0.0 else int(r * 1.6) + 6
		for k in n:
			var a := TAU * float(k) / float(n) + r * 0.37
			var q := c + Vector2(cos(a), sin(a)) * r
			var g := floor_at(space, q, from_y)
			if g == Vector3.INF or (not is_nan(near_y) and absf(g.y - near_y) > dy):
				continue
			if ok(space, g, opts):
				return g
		r += 1.5 if r < 6.0 else 2.5
	return Vector3.INF

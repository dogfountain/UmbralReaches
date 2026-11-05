class_name RealmLayout
extends RefCounted
## THE CONTRACT for the redesigned zone ("the Realm", docs/REALM_PLAN.md). Every module places
## against these numbers and this macro height, so the modules can be built in parallel and still
## meet. Change a value here only by agreement (it moves everyone). World units: metres, +Y up,
## the spawn brazier at (0, 0, 33). Bounds are about twice the old playable area.
##
## `macro_height(x, z)` is the designed landform (no small detail). RealmLand turns it into the
## terrain mesh (adding detail noise, path carving and site stamps); everyone else asks
## `RealmLayout.ground(space, x, z)` once the terrain exists, or `macro_height()` before it does.

const BOUNDS := Rect2(-110.0, -150.0, 220.0, 230.0)        ## playable xz (x -110..110, z -150..80)
const OUTER := Rect2(-200.0, -240.0, 400.0, 410.0)         ## terrain extent incl. the horizon ring
const LAVA_Y := -15.5                                       ## the rift's lava surface (LavaWorks)

## Fixed points (do not move: the kept brazier, tavern, Ossuary and summit depend on them).
const SPAWN := Vector3(0.0, 0.0, 33.0)                     ## the spawn brazier (Zone/Braziers/Sanctuary)
const PLAYER_START := Vector3(0.0, 0.15, 26.5)
const TAVERN := Rect2(10.0, 25.6, 16.0, 9.2)               ## Tavern.X0..X1, Z0..Z1 (+ yard east to x 29)
const OSSUARY := AABB(Vector3(2.0, -6.0, -110.0), Vector3(30.0, 32.0, 88.0))   ## streamed crypt (keep)
const SUMMIT := Vector3(0.0, 24.5, -83.5)                  ## summit platform holder (keep)
const SUMMIT_DAIS := Vector3(0.0, 27.35, -103.9)           ## Ascended Warden's fighting dais (r 14)
const SUMMIT_WARD := Vector3(0.0, 25.2, -70.9)             ## where the crossing arrives; the summit seal

## Regions: [id, name, centre xz, radius or rect, biome, lore one-liner]. Biomes drive flora,
## ground material and props. Radii are soft (RealmLand blends 15-25 m between biomes).
const REGIONS := [
	{"id": "hearth", "name": "Hearthward", "c": Vector2(6, 38), "r": 34.0, "biome": "meadow",
		"lore": "The last kindled village: the Kindled Keg, the spawn brazier, cottages gone quiet."},
	{"id": "road", "name": "The Pilgrims' Road", "rect": Rect2(-110, 50, 220, 30), "biome": "heath",
		"lore": "The old road the ascension pilgrims walked in, lined with waystones and their dead."},
	{"id": "chapel", "name": "Chapel of the First Kindling", "c": Vector2(-72, 52), "r": 22.0, "biome": "ruin",
		"lore": "Where the first fire was lit against the gloom; roofless now, its saints defaced."},
	{"id": "thornwood", "name": "The Thornwood", "rect": Rect2(-110, -70, 80, 115), "biome": "oldforest",
		"lore": "Ancient oaks the Thornwarden keeps; the pagan henge on its hill predates the ascension."},
	{"id": "henge", "name": "Thorn Henge", "c": Vector2(-72, -18), "r": 16.0, "biome": "oldforest",
		"lore": "Boss: the Thornwarden. Seal 'henge'."},
	{"id": "fen", "name": "The Hollow Fen", "rect": Rect2(40, -80, 70, 115), "biome": "fen",
		"lore": "Black pools and drowned graves where the hollowed were laid when the crypt was full."},
	{"id": "barrows", "name": "The Barrow Field", "c": Vector2(78, -42), "r": 20.0, "biome": "fen",
		"lore": "Grave mounds of the abbey's lay brothers; the path down to the Ossuary starts here."},
	{"id": "rift", "name": "The Ashen Rift", "rect": Rect2(-30, -118, 60, 106), "biome": "ash",
		"lore": "The wound the ascension tore in the land; lava where the pilgrims' stair once stood."},
	{"id": "ossuary", "name": "The Ossuary", "rect": Rect2(2, -110, 30, 88), "biome": "ash",
		"lore": "Boss: the Bone Abbot. Seal 'oss_gallery'. Streamed area (world/areas/ossuary)."},
	{"id": "summit", "name": "The Summit of Ascension", "c": Vector2(0, -95), "r": 30.0, "biome": "crag",
		"lore": "Boss: the Ascended Warden, last priest of the ascension. Seal 'summit'."},
	{"id": "crags", "name": "The Crowns", "rect": Rect2(-110, -150, 220, 40), "biome": "crag",
		"lore": "The mountain wall the sky turns inward over; the world's northern edge."},
	{"id": "glade", "name": "The Glimmer Glade", "c": Vector2(-38, 8), "r": 18.0, "biome": "glade",
		"lore": "Bioluminescent clearing between the village and the Thornwood; a shrine to the lost."},
]

## The walked network: polylines (xz) with a half width. RealmLand carves/levels them and keeps
## flora off; RealmLore lines them with waystones; enemies patrol near, never on, them.
const PATHS := [
	{"id": "west_way", "w": 1.8, "pts": [Vector2(-4, 30), Vector2(-20, 24), Vector2(-38, 10), Vector2(-52, -2), Vector2(-62, -12)]},
	{"id": "east_way", "w": 1.8, "pts": [Vector2(26, 22), Vector2(42, 10), Vector2(58, -12), Vector2(72, -34), Vector2(78, -42)]},
	{"id": "fen_descent", "w": 1.6, "pts": [Vector2(78, -42), Vector2(62, -56), Vector2(44, -62), Vector2(34, -66)]},
	{"id": "road", "w": 2.2, "pts": [Vector2(-104, 64), Vector2(-72, 60), Vector2(-40, 58), Vector2(-6, 54), Vector2(2, 44), Vector2(40, 60), Vector2(104, 66)]},
	{"id": "chapel_lane", "w": 1.4, "pts": [Vector2(-60, 58), Vector2(-68, 52)]},
	{"id": "rift_rim", "w": 2.0, "pts": [Vector2(0, 22), Vector2(0, 4), Vector2(0, -8)]},
]

## The crossing (RealmRift): a walkable ruined viaduct from the rift's south rim to the summit ward,
## built from the old stair kit (stair_step / stair_column / stair_platform .glb) and OssKit stone.
## It replaces the hub stair's job (the only way up) but must not read as a stairway: broken arches,
## platforms, ramps, a gap bridged by a fallen column, switchbacks round basalt pillars.
const CROSSING_FOOT := Vector3(0.0, 0.6, -8.0)
const CROSSING_HEAD := SUMMIT_WARD

## Boss / landmark anchors (centre on the ground; y from the terrain).
const HENGE_C := Vector2(-72.0, -18.0)                     ## ThornHenge.C xz (was (-42, 1))
const HENGE_STAIR_FOOT := Vector2(-58.0, -4.0)             ## end of west_way
const CHAPEL_C := Vector2(-72.0, 52.0)
const GLADE_C := Vector2(-38.0, 8.0)
const BARROWS_C := Vector2(78.0, -42.0)
const OSSUARY_GATE := Vector3(34.0, 4.0, -66.0)            ## where fen_descent meets the crypt (RealmBosses)


## Designed landform. Smooth, deterministic, cheap: the land's big shapes only.
## - meadow basin round Hearthward at ~0, the Pilgrims' Road plain south at ~0.5
## - Thornwood: rolling hills to ~9, Thorn Henge on a broad hilltop (flattened by its terrace)
## - Hollow Fen: low, -1.5 .. 0, with pools below the water line (-0.9)
## - the Ashen Rift: the kept chasm (old baked terrain) down to below the lava
## - the summit crag under the summit platform, and the Crowns rising to ~45 at the north edge
## - outside BOUNDS the ground climbs into a horizon ring of hills so the edge is never seen
static func macro_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.0
	# rolling base
	h += sin(x * 0.031 + 0.7) * cos(z * 0.027 - 0.4) * 1.6 + sin(x * 0.011 - z * 0.017) * 1.2
	# Thornwood hills, Henge hill
	var tw := _rect_w(p, Rect2(-110, -70, 80, 115), 22.0)
	h += tw * (4.0 + 3.0 * sin(x * 0.07) * sin(z * 0.06))
	h += 7.5 * _bump(p, HENGE_C, 24.0)
	# Hollow Fen hollow
	h -= 1.8 * _rect_w(p, Rect2(40, -80, 70, 115), 18.0)
	# hearth basin and the road plain: pulled flat towards 0 / 0.5
	var hearth := _bump(p, Vector2(6, 38), 40.0)
	h = lerpf(h, 0.0, hearth)
	h = lerpf(h, 0.5, 0.7 * _rect_w(p, Rect2(-110, 50, 220, 30), 10.0) * (1.0 - hearth))
	# the Crowns (north wall) and the summit crag
	var north := clampf((-110.0 - z) / 40.0, 0.0, 1.0)
	h += north * north * 45.0
	h = maxf(h, 24.2 * _bump(p, Vector2(0, -95), 34.0) - 2.0)
	# the rift: the kept chasm. Inside the rift rect the baked terrain is authoritative (RealmLand
	# keeps the old heights there); this is only the macro shape for planning.
	var rift := _rect_w(p, Rect2(-24, -118, 48, 106), 10.0) * (1.0 - _bump(p, Vector2(0, -95), 30.0))
	h = lerpf(h, -18.0, rift * 0.9)
	# horizon ring
	var out := _out_dist(p, BOUNDS)
	h += smoothstep(0.0, 60.0, out) * 28.0
	return h


## The named place at xz: the most specific region wins (r30). The small landmark circles (the chapel,
## the henge, the barrows, the summit, the glade) all sit inside a larger rect whose weight is 1.0
## all through, and the old "first highest weight" pick gave them 0 % of their own ground: no banner,
## no Journal discovery, the wrong encounter tier. Each circle now owns its ground out to 0.8 of its
## radius (falling off to 1.4 r), and where two places both hold full weight the smaller one wins.
## The codex (ui/codex.gd) and the encounter tiers use this; biome_at keeps the landform blend.
static func region_at(x: float, z: float) -> Dictionary:
	var best := {}
	var best_s := 0.0
	for r: Dictionary in REGIONS:
		var sc := place_score(r, x, z)
		if sc > best_s:
			best_s = sc
			best = r
	return best


## Selection score for region_at: a plateau weight plus a tiny bonus for being small.
static func place_score(r: Dictionary, x: float, z: float) -> float:
	var w := place_weight(r, x, z)
	if w <= 0.0:
		return 0.0
	return w + 0.01 * (1.0 - clampf(_area(r) / 60000.0, 0.0, 1.0))


## 1.0 inside a rect or within 0.8 r of a circle's centre, then a smooth falloff (rect: 18 m, circle:
## to 1.4 r, where region_weight also ends).
static func place_weight(r: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	if r.has("rect"):
		return _rect_w(p, r.rect, 18.0)
	var rr := float(r.r)
	var d := p.distance_to(r.c)
	var t := clampf(1.0 - (d - rr * 0.8) / (rr * 0.6), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _area(r: Dictionary) -> float:
	if r.has("rect"):
		return (r.rect as Rect2).get_area()
	return PI * float(r.r) * float(r.r)


static func region_weight(r: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	if r.has("rect"):
		return _rect_w(p, r.rect, 18.0)
	return _bump(p, r.c, float(r.r) * 1.4)


## The landform biome (footsteps, weather, wildlife, ambience): the heaviest region by its blend
## weight, as RealmLand painted the ground. Not region_at: a place's name may sit on another's land
## (the summit circle reaches over the rift's ash, whose lava ambience must stay).
static func biome_at(x: float, z: float) -> String:
	var best := {}
	var best_w := 0.0
	for r: Dictionary in REGIONS:
		var w := region_weight(r, x, z)
		if w > best_w:
			best_w = w
			best = r
	return String(best.get("biome", "meadow"))


## Ground height from the real terrain (after RealmLand), or the macro shape before it exists.
static func ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	if space:
		# nudged a few mm: a ray exactly on a terrain grid edge can slip through the trimesh (Jolt)
		x += 0.0037
		z += 0.0029
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 120, z), Vector3(x, -60, z), 1))
		if hit and String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
	return macro_height(x, z)


## Distance from p to the nearest path centreline (and which path), for keeping things off paths.
static func path_dist(p: Vector2) -> float:
	var best := INF
	for path: Dictionary in PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - float(path.w))
	return best


static func _bump(p: Vector2, c: Vector2, r: float) -> float:
	var t := clampf(1.0 - p.distance_to(c) / r, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _rect_w(p: Vector2, r: Rect2, fall: float) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	var d := Vector2(dx, dz).length()
	var t := clampf(1.0 - d / fall, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _out_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

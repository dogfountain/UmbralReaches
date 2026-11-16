class_name Endgame
extends RefCounted
## Where the end of the night stands (Luke, 16 Nov: the final boss "next to the village ... makes no sense"): the Ashen
## Rift, the Crossing, the Pilgrims' Threshold and the Summit of Ascension are at the Realm's far north-east, beyond
## Lastlight, where the pilgrims' road turned to the mountain, the last place the wanderer reaches.
##
## They were built round a chasm on x 0 under Hearthward. Their builders keep those coordinates (the chasm's centreline
## is still x 0 in them) and stand under hosts moved by O; whatever asks the world from inside them (a ground ray, a way,
## a site, a lane, RealmLayout) adds O first. A pure shift east along the Crowns: north stays north, heights stay, the
## mountain still stands behind the summit. RealmLayout's own anchors (SUMMIT, SUMMIT_DAIS, SUMMIT_WARD, CROSSING_FOOT,
## OSSUARY_OLD, the summit raid, the rift and summit regions) are already where the endgame stands now.

const O := Vector3(310.0, 0.0, 0.0)
const O2 := Vector2(310.0, 0.0)


## A point in the builders' own (old, chasm-on-x-0) coordinates, where it stands in the world.
static func w(p: Vector3) -> Vector3:
	return p + O


static func w2(p: Vector2) -> Vector2:
	return p + O2


static func wr(r: Rect2) -> Rect2:
	return Rect2(r.position + O2, r.size)


## A world point in the builders' own coordinates.
static func l(p: Vector3) -> Vector3:
	return p - O


static func l2(p: Vector2) -> Vector2:
	return p - O2


# --- built at home, then moved -----------------------------------------------------------------------
## The Crossing, the Threshold and the chasm's features were made against the chasm under Hearthward, and their
## placement reads the world round them (rays at their walls and piers, their own sites, the instances near them).
## So RealmRift builds them there unchanged, on a copy of the north-east's ground: RealmLand lends home the ground O east
## (borrow(): the old chasm reads where it was baked, Endgame.back_x, so both places hold it, and the burn, the Choir
## House's terrace and the berms come with it), settle() moves the finished pieces and everything they registered east
## by O, and endgame_ground.gd puts the land's own heights back at home (meadow and wood up to the Crowns' foot).

## The chasm is still at home (RealmLand lent it the north-east's ground). Set by Realm.build before the land.
static var at_home := true
## Home's ground lent the north-east's while the rift builds (builders' coordinates): the rift, the old Ossuary, the
## summit and their berms, up to the Hollow Fen.
const HOME_ZONE := Rect2(-62.0, -146.0, 100.0, 156.0)
## Grid vertex -> the land's own height there, while the ground is lent (endgame_ground.gd puts them back).
static var home_keep := {}


## Lends home the north-east's ground (RealmLand, after its mesh data and before the terrain is made from the heights).
static func borrow(h: PackedFloat32Array, x0: float, z0: float, step: float, nx: int) -> PackedFloat32Array:
	home_keep = {}
	if not at_home:
		return h
	h = h.duplicate()                                 # (the land cache may hold this very array)
	var shift := int(roundf(O.x / step))
	var nz := h.size() / nx
	var i0 := maxi(int(ceilf((HOME_ZONE.position.x - x0) / step)), 0)
	var i1 := mini(int(floorf((HOME_ZONE.end.x - x0) / step)), nx - 1 - shift)
	var j0 := maxi(int(ceilf((HOME_ZONE.position.y - z0) / step)), 0)
	var j1 := mini(int(floorf((HOME_ZONE.end.y - z0) / step)), nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * nx + i
			home_keep[k] = h[k]
			h[k] = h[k + shift]
	return h


## How far west the old baked terrain is read for a point at x (the moved chasm reads home's samples).
static func back_x(x: float) -> float:
	return O.x if x > O.x * 0.5 else 0.0


## RealmRift built at home: move it and what it registered (sites, flights, lanes, the chapel's marks) east by O,
## (the ground at home is laid again by endgame_ground.gd, after). `s0` / `l0`: WorldLanes' site and lane counts before
## the rift built.
static func settle(root: Node, s0: int, l0: int) -> void:
	var host := root.get_node_or_null("RealmRift") as Node3D
	if host != null:
		host.position += O
		for k in range(s0, WorldLanes.sites.size()):
			var s: Dictionary = WorldLanes.sites[k]
			var r: Rect2 = s.rect
			s.rect = Rect2(r.position + O2, r.size)
			if s.has("seg"):
				var sg: Array = s.seg
				s.seg = [(sg[0] as Vector3) + O, (sg[1] as Vector3) + O, sg[2]]
			if s.has("circle"):
				var c: Vector3 = s.circle
				s.circle = Vector3(c.x + O.x, c.y + O.z, c.z)
		for k in range(l0, WorldLanes.extra_lanes.size()):
			var l: Array = WorldLanes.extra_lanes[k]
			var pts: Array = []
			for q: Vector2 in l[1]:
				pts.append(q + O2)
			l[1] = pts
		WorldLanes._floor.clear()
		for mark in host.find_children("ChapelMarker", "Node3D", true, false):
			for key: String in ["floor", "chest_at", "stone_at", "door"]:
				if mark.has_meta(key):
					mark.set_meta(key, (mark.get_meta(key) as Vector3) + O)

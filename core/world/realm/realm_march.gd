class_name RealmMarch
extends RefCounted
## The March Wall's line and the Marches' cross-ridges (the numbers; RealmLayout shapes the land from them,
## realm_pois_south_marches.gd builds the wall on them). The wall follows the land: one polyline (x, z; z
## ascending) per side that swings out onto knolls and ridges and back, straight only where the road crosses
## (the gates, x +-155; RealmLayout.MARCH_GATES). Spurs run out to a tower on a knoll (the land lifts under
## the tip). RUINS is the long fall: [side, z0, z1], stubs and rubble, nothing to bar the way. OPENINGS are
## extra breaches besides the gates and the track crossings: [side, z]. RIDGES break up the long north-south
## valleys (a polyline, half width, height); a way that crosses one gets a saddle.

const WALL_WEST := [Vector2(-157, -112), Vector2(-165, -90), Vector2(-172, -66), Vector2(-163, -40), Vector2(-170, -14),
	Vector2(-160, 10), Vector2(-155, 34), Vector2(-155, 52), Vector2(-155, 82), Vector2(-152, 104), Vector2(-158, 128),
	Vector2(-162, 150), Vector2(-157, 172), Vector2(-165, 196), Vector2(-163, 214), Vector2(-158, 230), Vector2(-156, 242)]
const WALL_EAST := [Vector2(157, -112), Vector2(163, -92), Vector2(171, -70), Vector2(160, -46), Vector2(159, -22),
	Vector2(163, 8), Vector2(166, 30), Vector2(158, 44), Vector2(155, 56), Vector2(155, 84), Vector2(152, 106),
	Vector2(158, 128), Vector2(153, 150), Vector2(162, 172), Vector2(166, 196), Vector2(166, 214), Vector2(160, 230), Vector2(157, 242)]
## Short spurs: the wall runs out from its line to a tower on a knoll (the land lifts under the tip).
const SPURS := [{"side": -1, "base": Vector2(-160, 10), "tip": Vector2(-176, 24)}, {"side": 1, "base": Vector2(158, 44), "tip": Vector2(170, 50)}]
## The long fall: [side, z0, z1] where the wall has come down (stubs and rubble, nothing to bar the way).
const RUINS := [[-1, 112.0, 184.0]]
## Extra openings besides the gates and the track crossings: [side, z].
const OPENINGS := [[-1, -24.0], [1, -26.0], [1, 132.0]]
## Cross-ridges in the Marches (they break up the long north-south valleys): a polyline, half width, height.
## A way that crosses one gets a saddle.
const RIDGES := [
	{"pts": [Vector2(-262, 30), Vector2(-238, 21), Vector2(-214, 28), Vector2(-196, 23), Vector2(-176, 30), Vector2(-160, 24)], "w": 15.0, "h": 6.5},
	{"pts": [Vector2(160, -57), Vector2(184, -64), Vector2(208, -59), Vector2(234, -65), Vector2(262, -57)], "w": 11.0, "h": 6.0},
]


## x of the March Wall at z on one side (-1 west, +1 east): its polyline, held at the ends.
static func wall_x(side: int, z: float) -> float:
	var pts: Array = WALL_WEST if side < 0 else WALL_EAST
	var first: Vector2 = pts[0]
	if z <= first.y:
		return first.x
	for i in pts.size() - 1:
		var b: Vector2 = pts[i + 1]
		if z <= b.y:
			var a: Vector2 = pts[i]
			return lerpf(a.x, b.x, (z - a.y) / maxf(b.y - a.y, 0.001))
	var last: Vector2 = pts[pts.size() - 1]
	return last.x


## Distance from p to the March Wall's line on p's side of the Realm (a spur's wall is not counted).
static func wall_dist(p: Vector2) -> float:
	var pts: Array = WALL_WEST if p.x < 0.0 else WALL_EAST
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var ab := (pts[i + 1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## 0..1 across a ridge's polyline: 1 on the crest line, easing to 0 at its half width.
static func ridge_w(p: Vector2, rg: Dictionary) -> float:
	var pts: Array = rg.pts
	var w := float(rg.w)
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var ab := (pts[i + 1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	if best >= w * 1.6:
		return 0.0
	var u := 1.0 - best / (w * 1.6)
	return u * u * (3.0 - 2.0 * u)

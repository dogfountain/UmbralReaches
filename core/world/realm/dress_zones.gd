extends RefCounted
## Where the Realm's ground is lived in, as data: settlement squares and yards, the walk lanes through
## them, wet spots (wells, troughs), fire pads, raid-floor rims and wall breaches. Three readers:
##   - realm_land.gd paints it into the ground splat (flagstones in the squares, packed earth along the
##     lanes and round the fires, mud at the wells)
##   - realm_flora.gd lets low plants creep back over the cleared ground (soft margins, tufts in the
##     paving where nobody walks) and keeps the lanes bare
##   - site_dress.gd stands the clutter (barrels, crates, firewood, stones, bones ...) off the lanes
## Pure data and maths (thread-safe: the land's splat rows call it from worker threads). Load by path:
##   const Zones := preload("res://core/world/realm/dress_zones.gd")

const BOSSES := "res://core/world/realm/realm_bosses.gd"      # by path: realm_bosses reaches the places that reach the land
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const Cast := preload("res://core/life/village/village_cast.gd")

## Open ground the people use: {id, c, r, kind}. "square" = cobbled and dressed round its rim;
## "yard" = the same on a working hamlet's ground (more stores). "market" = how many stalls it stands (site_dress.gd).
const SQUARES := [
	{"id": "hearthward", "c": Vector2(0.0, 34.0), "r": 12.5, "kind": "square"},
	{"id": "weirford", "c": Vector2(-193.0, 71.0), "r": 11.5, "kind": "square", "market": 4},
	{"id": "saltmarket", "c": Vector2(215.0, 97.0), "r": 14.5, "kind": "yard", "market": 8},
]
## Wet ground: mud, a puddle's worth of dark earth. [centre, radius]
const WET := [
	[Vector2(-10.0, 48.5), 2.6], [Vector2(-191.0, 76.2), 2.4], [Vector2(11.5, 60.5), 1.8],
]
## Walk lanes outside Hearthward's own network (Weirford's square, Saltmarket's yard): polylines of
## the nodes their people walk (realm_pois_west_marches.gd, realm_pois_east_marches.gd)
const LANES := [
	[Vector2(-186.0, 62.6), Vector2(-186.0, 64.8), Vector2(-186.0, 70.6), Vector2(-185.0, 70.6)],
	[Vector2(-194.4, 65.6), Vector2(-194.8, 69.8), Vector2(-196.0, 71.4), Vector2(-199.6, 74.6), Vector2(-201.8, 77.6)],
	[Vector2(-196.0, 71.4), Vector2(-192.8, 74.4), Vector2(-191.0, 76.2)],
	[Vector2(-185.0, 70.6), Vector2(-192.8, 74.4), Vector2(-195.6, 77.4)],
	[Vector2(-186.0, 64.8), Vector2(-177.0, 64.8), Vector2(-174.0, 70.4)],
	[Vector2(216.2, 98.6), Vector2(213.0, 94.0), Vector2(218.0, 91.0), Vector2(222.4, 85.0)],
	[Vector2(216.2, 98.6), Vector2(213.0, 102.0), Vector2(206.0, 105.8)],
	[Vector2(216.2, 98.6), Vector2(219.6, 100.0), Vector2(222.0, 106.4), Vector2(225.0, 105.0)],
	[Vector2(213.0, 94.0), Vector2(206.0, 88.4)],
]
const LANE_W := 0.9                    ## half width kept bare along a lane

static var _sq: Array = []             ## squares(): SQUARES as built


## SQUARES as built: the scale pilot's Weirford has a wider square, a little south of the old one.
static func squares() -> Array:
	if _sq.is_empty():
		var out: Array = []
		for s: Dictionary in SQUARES:
			var d := s.duplicate()
			if Pilot.on() and String(s.id) == "weirford":
				d["c"] = Pilot.SQUARE[0]
				d["r"] = Pilot.SQUARE[1]
			out.append(d)
		_sq = out                        # set whole: the land's splat rows read this from worker threads
	return _sq

static var _off := -1                  ## --no-site-dress: the world as it was (before / after shots, perf A/B)

static var _lanes: Array = []          ## [[a, b, bbox Rect2]] every lane segment
static var _squares: Array = []        ## SQUARES with the Hearthward walk inside
static var _inited := false


## True under `-- --no-site-dress`: no paving, lanes, soft margins, clutter or settlement life.
static func off() -> bool:
	if _off < 0:
		_off = 1 if "--no-site-dress" in OS.get_cmdline_user_args() else 0
	return _off == 1


## Lane segments: Hearthward's walking network (village_cast.gd) inside its square, plus LANES.
static func lanes() -> Array:
	_init_once()
	return _lanes


static func _init_once() -> void:
	if _inited:
		return
	off()
	_inited = true
	squares()                              # built here, on the caller's thread, before any worker reads it
	fire_points()
	var hw: Dictionary = SQUARES[0]
	var hc: Vector2 = hw.c
	var nodes: Dictionary = Cast.nodes()
	for e: Array in Cast.edges():
		var a: Vector2 = nodes[e[0]]
		var b: Vector2 = nodes[e[1]]
		if a.distance_to(hc) < float(hw.r) + 2.0 and b.distance_to(hc) < float(hw.r) + 2.0:
			_add_lane(a, b)
	for pl: Array in LANES:
		for i in pl.size() - 1:
			_add_lane(Pilot.xz(pl[i]), Pilot.xz(pl[i + 1]))


static func _add_lane(a: Vector2, b: Vector2) -> void:
	_lanes.append([a, b, Rect2(a.min(b), (b - a).abs()).grow(LANE_W + 3.5)])


## Distance from p to the nearest lane's edge (0 on it), INF when far from every lane.
static func lane_dist(p: Vector2) -> float:
	_init_once()
	if off():
		return INF
	var best := INF
	for l: Array in _lanes:
		if not (l[2] as Rect2).has_point(p):
			continue
		var a: Vector2 = l[0]
		var ab: Vector2 = (l[1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t) - LANE_W)
	return maxf(best, 0.0) if best != INF else INF


## 0..1 worn earth along a lane (the ground shader's path overlay).
static func lane_wear(p: Vector2) -> float:
	if off():
		return 0.0
	var d := lane_dist(p)
	if d == INF:
		return 0.0
	return 1.0 - smoothstep(0.0, 1.3, d)


## 0..1 flagstone paving: full inside a square's core, broken up and ragged out to its rim.
static func pave_w(x: float, z: float, patch: float) -> float:
	if off():
		return 0.0
	var p := Vector2(x, z)
	var best := 0.0
	for s: Dictionary in squares():
		var c: Vector2 = s.c
		var r: float = s.r
		var d := p.distance_to(c)
		if d > r + 2.0:
			continue
		# the rim is ragged (noise `patch` is -1..1) and the paving thins into earth with distance
		var rim := r + patch * 2.2
		var w := 1.0 - smoothstep(rim - 5.0, rim, d)
		# worn lanes break the stones: the splat's wear then paints earth over them
		best = maxf(best, w * (0.82 + 0.18 * clampf(patch * 2.0 + 0.5, 0.0, 1.0)))
	return best


## 0..1 mud round a well or trough.
static func wet_w(x: float, z: float) -> float:
	if off():
		return 0.0
	var p := Vector2(x, z)
	var best := 0.0
	for w: Array in WET:
		var d := p.distance_to(Pilot.xz(w[0] as Vector2))
		var r: float = w[1]
		if d < r + 1.5:
			best = maxf(best, 1.0 - smoothstep(r * 0.4, r + 1.5, d))
	return best


## 0..1 packed earth round a fire pad.
static func fire_wear(x: float, z: float) -> float:
	if off():
		return 0.0
	var p := Vector2(x, z)
	var best := 0.0
	for pos: Vector2 in fire_points():
		var d := p.distance_to(pos)
		if d < 4.0:
			best = maxf(best, 1.0 - smoothstep(1.2, 3.8, d))
	return best


static var _fires: Array[Vector2] = []


## Every checkpoint fire's xz (call once from the main thread before any worker reads it).
static func fire_points() -> Array[Vector2]:
	if _fires.is_empty():
		var consts: Dictionary = (load(BOSSES) as GDScript).get_script_constant_map()
		for key: String in ["BRAZIERS", "R34_FIRES"]:
			var tbl: Dictionary = consts[key]
			for n: String in tbl:
				_fires.append(Pilot.xz((tbl[n] as Array)[0]))
	return _fires


## The wall's openings as [centre xz, outward direction]: the extra breaches (RealmRealmMarch.OPENINGS).
static func breaches() -> Array:
	var out: Array = []
	for o: Array in RealmMarch.OPENINGS:
		var side: int = o[0]
		var z: float = o[1]
		var pts: Array = RealmMarch.WALL_WEST if side < 0 else RealmMarch.WALL_EAST
		var x := float(side) * 158.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if z >= a.y and z <= b.y:
				x = lerpf(a.x, b.x, (z - a.y) / maxf(b.y - a.y, 0.001))
		out.append([Vector2(x, z), Vector2(float(side), 0.0)])
	return out


## A repeatable 0..1 from a position (the soft margins must not shift the flora's random stream).
static func h01(x: float, z: float) -> float:
	return float(absi(hash(Vector2i(roundi(x * 17.0), roundi(z * 17.0)))) % 1000) / 1000.0


## Low plants creep back over cleared ground: a keep-out's edge wanders by noise (EDGE_S metres at a site,
## EDGE_P at a path: tongues of grass run in, bare bays run out) and the density ramps over EDGE_W metres
## either side, instead of a ruled line. Symmetric, so the plant count stays what it was.
const SOFT_KINDS := ["grass", "tallgrass", "flowers", "heather", "litter", "moss"]
const EDGE_S := 2.2
const EDGE_P := 0.9
const EDGE_W := 0.9


## Share of full density at a spot `sd` from the nearest keep-out and `pd` from the nearest path edge
## (the kind keeps `keep_s` / `keep_p` from them), `inside` from soft_field, `n` a noise value (-0.5..0.5).
static func edge_f(sd: float, inside: float, pd: float, keep_s: float, keep_p: float, n: float) -> float:
	var wob := clampf(n * 2.2, -1.0, 1.0)
	var es := maxf(keep_s + wob * EDGE_S, 0.35)
	var ep := maxf(keep_p + wob * EDGE_P, 0.25)
	return maxf(smoothstep(es - EDGE_W, es + EDGE_W, sd), inside) * smoothstep(ep - EDGE_W, ep + EDGE_W, pd)
const SOFT_IN_SQUARE := 0.02           ## low plants' share of full density in the paving where nobody walks (a square in use is kept: 0.08 grew tall clumps mid-square) ...
const SOFT_IN_SQ_RIM := 0.2            ## ... along a square's rim
const SOFT_IN_RIM := 0.3               ## ... and a pad's margin


## Where low plants may grow inside the keep-outs, 0..1 of full density, on the flora's ground grid
## (cell `cell`, origin x0 z0, nx by nz): the squares' paving, the margins of the pads (sites) and the
## rims of the raid floors. The caller zeroes it on lava and where the first thing hit is not terrain.
static func soft_field(x0: float, z0: float, nx: int, nz: int, cell: float) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(nx * nz)
	f.fill(0.0)
	if off():
		return f
	var grid := Rect2(x0, z0, nx * cell, nz * cell)
	for sq: Dictionary in squares():
		var c: Vector2 = sq.c
		var r: float = sq.r
		_stamp(f, grid, nx, cell, c, r, func(p: Vector2) -> float:
			var d := p.distance_to(c)
			return lerpf(SOFT_IN_SQUARE, SOFT_IN_SQ_RIM, smoothstep(r - 5.0, r, d)) if d < r else 0.0)
	for st: Dictionary in WorldLanes.sites:
		var nm := String(st.name)
		if st.get("hard", false) or st.has("seg") or nm.begins_with("rift_") or nm.begins_with("henge") or nm.begins_with("brazier_") \
				or nm.begins_with("oss_") or nm.begins_with("tavern"):
			continue
		var rc: Rect2 = st.rect
		if st.has("circle"):
			continue                                   # the raid floors stay clear
		elif rc.size.x * rc.size.y >= 12.0:
			_stamp(f, grid, nx, cell, rc.get_center(), maxf(rc.size.x, rc.size.y), func(p: Vector2) -> float:
				if not rc.has_point(p):
					return 0.0
				var edge := minf(minf(p.x - rc.position.x, rc.end.x - p.x), minf(p.y - rc.position.y, rc.end.y - p.y))
				return lerpf(SOFT_IN_RIM, 0.06, smoothstep(0.0, 2.5, edge)))
	return f


## Raise `f` (a nx-wide grid of `cell` metre cells over `grid`) to fn(cell centre) inside `reach` of c.
static func _stamp(f: PackedFloat32Array, grid: Rect2, nx: int, cell: float, c: Vector2, reach: float, fn: Callable) -> void:
	var nz := int(grid.size.y / cell)
	var i0 := clampi(int(floor((c.x - reach - grid.position.x) / cell)), 0, nx - 1)
	var i1 := clampi(int(ceil((c.x + reach - grid.position.x) / cell)), 0, nx - 1)
	var j0 := clampi(int(floor((c.y - reach - grid.position.y) / cell)), 0, nz - 1)
	var j1 := clampi(int(ceil((c.y + reach - grid.position.y) / cell)), 0, nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var w: float = fn.call(Vector2(grid.position.x + i * cell, grid.position.y + j * cell))
			if w > f[j * nx + i]:
				f[j * nx + i] = w

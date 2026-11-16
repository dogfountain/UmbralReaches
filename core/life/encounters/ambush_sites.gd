extends RefCounted
## Encounters: where the road ambushes wait (director.gd walks them and springs them). Not every forty metres of
## every way: where the land suggests one. Each sample along a way scores what is round it --
##   ford      the way crosses the river (a ford, a bridge's foot)
##   causeway  water on both sides of the way
##   cutting   banks rise on both sides (nowhere to step off)
##   ruin      walls or a place's ground beside the way (something to wait behind)
##   cover     trees at the verge (a wood, a holt)
##   bend      a blind turn
##   crest     the way tops a rise (what waits beyond it is out of sight)
##   verge     the Pilgrims' Road's own verge, where the pilgrims who never reached the mountain sat down
## -- and the best sites win, GAP metres apart, never in or near a safe place (SpawnRules.SAFE, SAFE_CLEAR
## beyond its ring), on the hub's roads (SpawnRules.HUB_ROADS_R), near a fire or a camp or in the Ossuary, and only where
## the hollowed have fair ground to rise on beside the way. A site keeps its reason: it picks the banner line.
## Load by path:  const AmbushSites := preload("res://core/life/encounters/ambush_sites.gd")

const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const STEP := 4.0
const GAP := 40.0
const MIN_SCORE := 1.0
const FIRE_CLEAR := 24.0
const SAFE_CLEAR := 30.0
const CAMP_CLEAR := 20.0               ## off a camp (an ambush beside a camp is one fight, not two beats)
const SKIP_WAYS := ["rift_rim", "north_lane", "chapel_lane", "oss_lane"]
const WEIGHT := {"ford": 2.0, "causeway": 2.0, "cutting": 2.0, "ruin": 1.5, "cover": 1.6, "bend": 1.0, "crest": 1.0, "verge": 1.0}
const TREE_R := 12.0                   ## trees this near the way are cover; TREES of them are a wood
## The kinds that lie in wait by a way (the formation kinds -- bulwark, chanter, tollman, cinder caster, quiller --
## hold camps, they do not hide in the verge).
const LURKERS := ["wretch", "crawler", "leaper", "gaunt", "burrower", "pilgrim", "husk", "spitter", "mite", "ossuant"]
## Where the hollowed rise for a walker going `fwd` (side = fwd turned left): ahead on both verges, then beside.
const RISE := [Vector2(10.0, 4.5), Vector2(10.0, -5.0), Vector2(2.0, 8.0), Vector2(2.0, -8.0), Vector2(-9.0, 5.0),
	Vector2(14.0, 7.0), Vector2(14.0, -7.0), Vector2(6.0, 10.0), Vector2(6.0, -10.0)]


## Every planned site: {at (on the way), dir (Vector2), path, why, score, cd}. `keep_off`: fires and the like
## (FIRE_CLEAR round each). `ground(Vector3, from_y) -> Vector3` finds open floor (INF if none) and
## `fair(Vector3) -> bool` is the director's spot rule for something rising there.
static func plan(space: PhysicsDirectSpaceState3D, keep_off: Array[Vector2], ground: Callable, fair: Callable) -> Array[Dictionary]:
	reset()
	var cands: Array[Dictionary] = []
	for path: Dictionary in RealmLayout.PATHS:
		if String(path.id) in SKIP_WAYS:
			continue
		var pts := _resample(path.pts as Array)
		for i in pts.size():
			var p: Vector2 = pts[i]
			if p.distance_to(SpawnRules.HUB) < SpawnRules.HUB_ROADS_R or SpawnRules.safe_at(p, SAFE_CLEAR) != "":
				continue
			if not RealmLayout.BOUNDS.grow(-12.0).has_point(p) or not WorldLanes.site_at(p, 2.0).is_empty():
				continue
			var near_fire := false
			for o in keep_off:
				if p.distance_to(o) < FIRE_CLEAR:
					near_fire = true
					break
			for cp: Dictionary in EnemySpawner.REALM_CAMPS:
				if p.distance_to(Vector2(cp.at.x, cp.at.z)) < CAMP_CLEAR:
					near_fire = true
					break
			if near_fire:
				continue
			var a: Vector2 = pts[maxi(i - 3, 0)]
			var b: Vector2 = pts[mini(i + 3, pts.size() - 1)]
			var f := features(space, p, a, b, String(path.id))
			var score := 0.0
			var why := ""
			var best := 0.0
			for k: String in f:
				var v := float(WEIGHT[k]) * float(f[k])
				score += v
				if v > best:
					best = v
					why = k
			if score >= MIN_SCORE:
				cands.append({"p": p, "dir": (b - a).normalized(), "path": String(path.id), "why": why, "score": score})
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.score) > float(y.score))
	var out: Array[Dictionary] = []
	for c: Dictionary in cands:
		var p: Vector2 = c.p
		var crowded := false
		for s: Dictionary in out:
			if p.distance_to(Vector2((s.at as Vector3).x, (s.at as Vector3).z)) < GAP:
				crowded = true
				break
		if crowded:
			continue
		# the way's own floor (from just over the ground: a gate's vault or a bridge's arch above it is not the way)
		var g: Vector3 = ground.call(Vector3(p.x, 0.0, p.y), RealmLand.height_at(p.x, p.y) + 3.0)
		if g == Vector3.INF or RealmLayout.in_ossuary(g) or not SpawnRules.ok(space, g, {"ways": false}):
			continue
		if rise_spots(g, c.dir, ground, fair).size() < 2:
			continue                                   # nowhere fair to come up from: not here
		out.append({"at": g, "dir": c.dir, "cd": 0.0, "path": c.path, "why": c.why, "score": c.score})
	var tally := {}
	for s: Dictionary in out:
		tally[s.why] = int(tally.get(s.why, 0)) + 1
	print("AMBUSHES planned: %d sites from %d candidate points %s" % [out.size(), cands.size(), tally])
	reset()
	return out


## The way's points every STEP metres (the meandered line).
static func _resample(src: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if src.is_empty():
		return out
	var carry := 0.0
	out.append(src[0])
	for i in src.size() - 1:
		var a: Vector2 = src[i]
		var b: Vector2 = src[i + 1]
		var ln := a.distance_to(b)
		var t := STEP - carry
		while t <= ln:
			out.append(a.lerp(b, t / maxf(ln, 0.001)))
			t += STEP
		carry = ln - (t - STEP)
	return out


## What is round a point of a way (from a and b, 12 m either side along it): {feature: strength 0..1}.
static func features(space: PhysicsDirectSpaceState3D, p: Vector2, a: Vector2, b: Vector2, way := "") -> Dictionary:
	var f := {}
	if way == "road":
		f["verge"] = 1.0
	var d := (b - a).normalized()
	var side := Vector2(-d.y, d.x)
	var h := RealmLand.height_at(p.x, p.y)
	# a ford or a bridge's foot: the river under or beside the way
	if RealmLayout.river_mask(p.x, p.y) > 0.25 or RealmLayout.river_mask(a.x, a.y) > 0.5 or RealmLayout.river_mask(b.x, b.y) > 0.5:
		f["ford"] = 1.0
	# water on both hands
	var wet := 0
	for s: float in [-1.0, 1.0]:
		for r: float in [5.0, 8.0]:
			var q := p + side * s * r
			if RealmLand.in_water(q.x, q.y):
				wet += 1
				break
	if wet == 2 and not f.has("ford"):
		f["causeway"] = 1.0
	# banks on both hands
	var bank := INF
	for s: float in [-1.0, 1.0]:
		var top := -INF
		for r: float in [5.0, 7.0, 9.0]:
			var q := p + side * s * r
			top = maxf(top, RealmLand.height_at(q.x, q.y) - h)
		bank = minf(bank, top)
	if bank > 1.4:
		f["cutting"] = clampf((bank - 1.4) / 1.6 + 0.5, 0.5, 1.0)
	# a ruin or a place's walls beside the way
	for s: float in [-1.0, 1.0]:
		if not WorldLanes.site_at(p + side * s * 9.0, 4.0).is_empty():
			f["ruin"] = 1.0
			break
	# trees at the verge
	var trees := _trees(space, p, TREE_R)
	var bio := RealmLayout.biome_at(p.x, p.y)
	var cover := clampf(float(trees) / 3.0, 0.0, 1.0)
	if bio in ["oldforest", "fen"]:
		cover = maxf(cover, 0.55)          # an old wood's undergrowth, the fen's reeds
	if cover > 0.2:
		f["cover"] = cover
	# a blind bend
	var turn := absf((p - a).normalized().angle_to((b - p).normalized()))
	if turn > deg_to_rad(38.0):
		f["bend"] = clampf(turn / deg_to_rad(70.0), 0.6, 1.0)
	# a crest
	var over := h - maxf(RealmLand.height_at(a.x, a.y), RealmLand.height_at(b.x, b.y))
	if over > 0.8:
		f["crest"] = clampf(over / 2.0, 0.5, 1.0)
	return f


## The flora's own tree list (RealmFlora.trees; the trunks' colliders exist only round the wanderer), bucketed once
## into 16 m cells for the plan.
const _CELL := 16.0
static var _grid: Dictionary = {}


static func _trees(_space: PhysicsDirectSpaceState3D, p: Vector2, r: float) -> int:
	if _grid.is_empty():
		for tr: Array in Flora.trees:
			var tp: Vector3 = tr[0]
			var k := Vector2i(floori(tp.x / _CELL), floori(tp.z / _CELL))
			var cell: PackedVector2Array = _grid.get(k, PackedVector2Array())
			cell.append(Vector2(tp.x, tp.z))
			_grid[k] = cell                                # a packed array is a value: store it back
		if _grid.is_empty():
			_grid[Vector2i(99999, 99999)] = PackedVector2Array()      # no trees: do not rebuild every call
	var n := 0
	var c := Vector2i(floori(p.x / _CELL), floori(p.y / _CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for q: Vector2 in _grid.get(c + Vector2i(dx, dz), PackedVector2Array()):
				if q.distance_to(p) < r:
					n += 1
	return n


## The tree buckets live only while a plan runs (built on its first count, dropped when it ends).
static func reset() -> void:
	_grid.clear()


## The spots the hollowed may rise on for a walker at `at` going `dir` (in order), through `fair`.
static func rise_spots(at: Vector3, dir: Vector2, ground: Callable, fair: Callable) -> Array[Vector3]:
	var fwd := Vector3(dir.x, 0.0, dir.y).normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var out: Array[Vector3] = []
	for o: Vector2 in RISE:
		var spot: Vector3 = ground.call(at + fwd * o.x + side * o.y, at.y + 25.0)
		if spot != Vector3.INF and absf(spot.y - at.y) < 6.0 and bool(fair.call(spot)):
			out.append(spot)
	return out


## The region's ambushers: its pool's lurkers (wretches and crawlers when it has none).
static func kinds(pool: Array) -> Array:
	var out: Array = []
	for k: Variant in pool:
		if String(k) in LURKERS:
			out.append(String(k))
	return out if not out.is_empty() else ["wretch", "crawler"]


## The banner's line: the way's own, else the reason's.
static func line(path: String, why: String) -> String:
	match path:
		"road":
			return "The pilgrims who sat down by the road get up."
		"west_way":
			return "The Thornwood's edge was not empty."
		"east_way", "fen_descent":
			return "The drowned climb out of the verge."
		"mere_causeway":
			return "The drowned climb up onto the causeway."
		"necropolis_way":
			return "The pilgrims in the verge were not asleep."
		"west_track":
			return "The wood closes in behind you."
		"moor_track":
			return "Something has been pacing you across the moor."
		"fell_track":
			return "The garrison's dead come down off the fell."
		"barrow_track":
			return "The kings' men rise out of the heather."
		"reed_ford":
			return "The drowned were waiting in the reeds."
		"fallow_way":
			return "The scarecrows step down off their poles."
		"arches_way", "arches_link":
			return "They were waiting under the arches."
		"southwood_way":
			return "The holly closes behind you."
		"bell_track", "bell_link":
			return "A bell in the dark. The tollmen come."
		"nave_track":
			return "The choir comes up out of the water."
		"cairn_track":
			return "Some of the cairns were never stones."
		"salt_south", "salt_track":
			return "The salt-crusted get up off the white."
	match why:
		"ford":
			return "They were waiting at the crossing."
		"causeway":
			return "The water on both sides is not empty."
		"cutting":
			return "They come down the banks at you."
		"ruin":
			return "They come out of the ruin."
		"bend":
			return "They were round the bend, waiting."
		"crest":
			return "Over the rise, they were waiting."
	return "The hollowed rise from the verge."

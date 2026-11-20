extends RefCounted
## The wayside (Luke, 15 Nov: "increase the world's density ... something worth walking to always in view"): the small
## places between the landmarks. Fallen field walls, folds, ruined cottages, wayside shrines, standing stones and rings,
## cairn fields, broken carts, cold camps, wells, grave plots, woodpiles, saints, masons' blocks, battle ground, bell
## shards, barrows, charcoal clamps, field corners, milestones, jetties, the ribs of something big, and a lookout on a
## high point in most regions. Each region favours its own (wayside_themes.gd), keeps a few named ones (discoveries:
## group "world_poi"), and some hold a box or a writing (lore/wayside_texts.gd).
##
## Where they stand is planned, not scattered: every way is walked and wherever the next thing worth a look is more
## than GAP_WAY off, a place goes up beside it, a little way off the edge so it reads from the road; then the open
## ground is filled the same way to GAP_OPEN; lookouts take each region's most prominent rise. A place keeps off the
## ways, every registered site, the camps, fires, outposts, raid floors, towns, the slots the region builders were
## given, the water (a jetty wants it), steep ground and the nav tiles' seams.
##
## Planned at the flora's start (plan(), from flora_layers.gd: every landmark, lore stone and wonder is registered by
## then), so the solid pieces' ground is registered as open-air sites (no stamp) and a place in a wood cuts its own
## clearing (RealmFlora.tree_clear); the flora then grows round them (flora_layers.gd's creep). Built after the flora
## from RealmPois (REACH_POIS: build). `-- --no-density` turns the wayside and the flora's layers off (A/B).
## Load by path (no class_name).

const Themes := preload("res://core/world/realm/wayside_themes.gd")
const Kit := preload("res://core/world/realm/wayside_kit.gd")
const Build := preload("res://core/world/realm/wayside_build.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Tables := preload("res://core/world/realm/flora_tables.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const PlacementCacheRef := preload("res://core/world/realm/placement_cache.gd")

const GAP_WAY := 30.0        ## along a way, the next place worth a look is never further than this
const GAP_OPEN := 44.0       ## off the ways
const DRESS_STEP := 11.0     ## the dressing's candidate grid
const DRESS_SPACING := 17.0  ## no two of the wayside's places nearer than this when dressing
## The dressing's share by ground: the Far Reaches in full, the Marches most, the old valley (already full of its
## own places) lightly.
const DENSITY := {"reaches": 1.0, "marches": 0.8, "old": 0.4}
const WAY_STEP := 6.0
const OPEN_STEP := 20.0
const MILE := 115.0          ## a milestone this often along the Far Reaches' and the Marches' ways
const KEEP_CAMP := 13.0
const KEEP_FIRE := 12.0
const KEEP_OUTPOST := 11.0
const KEEP_SLOT := {"poi": 19.0, "poi_wet": 17.0, "camp": 14.0, "fire": 12.0}
const KEEP_WALK := 3.5       ## a place keeps this far off a patrol round or a walked path (the tests walk them)
const WATER := -0.9
const SAME_NEAR := 110.0     ## the same kind twice inside this reads as copied
const CELL := 32.0

static var plan: Array[Dictionary] = []      ## the planned places (tests and flora_layers read it)
static var glades: Array = []                ## [Vector2, radius] clearings the places cut in the woods
static var stats := {}
static var built := 0
static var rejects := {}                     ## why spots were turned down (tuning)

static var _space: PhysicsDirectSpaceState3D
static var _grid := {}                       ## Vector2i(CELL) -> Array of Rect2: everything worth a look
static var _sgrid := {}                      ## Vector2i(CELL) -> Array of site indices (WorldLanes.sites at the plan's start)
static var _pgrid := {}                      ## Vector2i(CELL) -> Array of planned places
static var _by_kind := {}                    ## kind -> Array of Vector2: where the planned places of each kind stand
static var _segs: Array = []                 ## [a, b, half width] every way's segments
static var _seg_grid := {}                   ## Vector2i(CELL) -> Array of indices into _segs
static var _kgrid := {}                      ## Vector2i(CELL) -> Array of _keep entries whose round (and a place's reach) touches the cell
static var _keep: Array = []                 ## [Vector2, radius] the camps', fires', outposts' and slots' rounds
static var _rng := RandomNumberGenerator.new()
static var _n := 0
static var _force_qs := {}                   ## "region/stage" -> the spots _force tries
static var _sraid: Array = []                ## per site index: a raid floor (its own, finer test)
static var _loose := false                   ## the named places' last resort: nearer the rounds and the ways (see _force)


## A/B: the world without the wayside and the flora's layers.
static func off() -> bool:
	return "--no-density" in OS.get_cmdline_user_args() or "--no-wayside" in OS.get_cmdline_user_args()


## REACH_POIS' reserve step: nothing here (the plan waits for the flora's start, when every landmark is registered).
static func reserve(_root: Node) -> void:
	pass


## Plan every place, register their ground and hand their clearings to the flora (`tree_clear`: RealmFlora.tree_clear).
static func plan_now(root: Node, tree_clear: Array) -> void:
	var t0 := Time.get_ticks_msec()
	plan.clear()
	glades.clear()
	stats = {}
	rejects = {}
	_grid.clear()
	_sgrid.clear()
	_pgrid.clear()
	_by_kind.clear()
	_index_segs()
	_keep.clear()
	_kgrid.clear()
	_force_qs.clear()
	_n = 0
	if off():
		return
	var pk := PlacementCacheRef.key("wayside_plan", _brazier_spots(root))
	var hit: Variant = PlacementCacheRef.load_picks("wayside_plan", pk)
	var t_way := Time.get_ticks_usec()
	if hit != null and not PlacementCacheRef.verify:
		_adopt(hit as Dictionary)
		PlacementCacheRef.note("wayside_plan", "hit")
	else:
		var skipped_before := PlacementLog.entries.size()
		_solve(root)
		var picks := {"plan": plan.duplicate(), "rejects": rejects.duplicate(), "skips": PlacementLog.entries.slice(skipped_before)}
		if hit == null:
			PlacementCacheRef.save_picks(pk, picks)
			PlacementCacheRef.note("wayside_plan", "miss")
			if PlacementCacheRef.verify:
				PlacementCacheRef.compare("wayside_plan", pk, picks, PlacementCacheRef.load_picks("wayside_plan", pk))
		else:
			PlacementCacheRef.compare("wayside_plan", pk, picks, hit)
	PlacementCacheRef.lap("wayside plan", t_way)
	for v: Dictionary in plan:
		var i := 0
		for r: Rect2 in v.feet:
			WorldLanes.register_site("wayside_%s_%d" % [v.id, i], r, float((v.at as Vector3).y), float(v.top) + 0.5)
			i += 1
		# trunks keep off the solid pieces' ground (the sites); a crown over a ruined wall is as it should be. A tall
		# place keeps crowns off too, and in a wood a place stands in a clearing of its own
		var gr := float(Themes.KINDS[v.kind].glade)
		var c2 := Vector2((v.at as Vector3).x, (v.at as Vector3).z)
		if v.ctx == "wood" and gr > 0.0:
			glades.append([c2, gr])
			tree_clear.append([c2, gr])
		elif float(Themes.KINDS[v.kind].get("tall", 0.0)) > 0.0:
			tree_clear.append([c2, float(Themes.KINDS[v.kind].tall)])
		stats[v.kind] = int(stats.get(v.kind, 0)) + 1
	var named := 0
	for v: Dictionary in plan:
		if String(v.get("name", "")) != "":
			named += 1
	print("WAYSIDE rejects %s" % [rejects])
	print("WAYSIDE planned %d places (%d named, %d glades) in %d ms: %s" % [plan.size(), named, glades.size(), Time.get_ticks_msec() - t0, stats])


## The search itself: every pass in order (a miss, or the equality test).
static func _solve(root: Node) -> void:
	_space = (root as Node3D).get_world_3d().direct_space_state
	_rng.seed = 20261124
	for pass_name: String in ["interests", "lookouts", "ways", "miles", "open", "dress", "assign"]:
		match pass_name:
			"interests":
				_interests(root)
				_index_keeps()
			"lookouts": _lookouts()
			"ways": _ways()
			"miles": _miles()
			"open": _open()
			"dress": _dress()
			"assign": _assign()


## A stored plan's picks stand in for the search: the plan, why spots were turned down, the skips the assignment logged.
static func _adopt(picks: Dictionary) -> void:
	plan.assign(picks.plan as Array)
	rejects = (picks.rejects as Dictionary).duplicate()
	for e: Dictionary in picks.skips as Array:
		PlacementLog.skip(String(e.system), String(e.id), e.at as Vector3, String(e.why))


## Where the braziers stand (the plan keeps off their fires): part of the plan's key.
static func _brazier_spots(root: Node) -> Array:
	var out: Array = []
	for b in root.find_children("*", "Brazier", true, false):
		out.append((b as Node3D).global_position)
	return out


# --- what is already there -----------------------------------------------------------------------

## Index the rounds by cell: each lands in every cell its round plus the widest place's reach (8 m) touches.
static func _index_keeps() -> void:
	_kgrid.clear()
	for kp: Array in _keep:
		var c: Vector2 = kp[0]
		var reach := float(kp[1]) + 8.0
		for cj in range(floori((c.y - reach) / CELL), floori((c.y + reach) / CELL) + 1):
			for ci in range(floori((c.x - reach) / CELL), floori((c.x + reach) / CELL) + 1):
				var key := Vector2i(ci, cj)
				if not _kgrid.has(key):
					_kgrid[key] = []
				(_kgrid[key] as Array).append(kp)


static func _interests(root: Node) -> void:
	if "--wayside-sites" in OS.get_cmdline_user_args():
		for st: Dictionary in WorldLanes.sites:
			print("WAYSIDE site %-28s %s" % [st.name, (st.rect as Rect2)])
	for st: Dictionary in WorldLanes.sites:
		if String(st.name).begins_with("raid_"):
			continue
		_add_interest(st.rect as Rect2)
	for rd: Dictionary in RealmLayout.RAIDS:
		var c: Vector2 = rd.c
		_add_interest(Rect2(c - Vector2(8, 8), Vector2(16, 16)))
		_keep.append([c, float(rd.r) + float(rd.fall) + 4.0])
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var a: Vector3 = c.at
		_add_interest(Rect2(Vector2(a.x, a.z) - Vector2(3, 3), Vector2(6, 6)))
		_keep.append([Vector2(a.x, a.z), KEEP_CAMP])
	for b in root.find_children("*", "Brazier", true, false):
		var bp := (b as Node3D).global_position
		_add_interest(Rect2(Vector2(bp.x, bp.z) - Vector2(2, 2), Vector2(4, 4)))
		_keep.append([Vector2(bp.x, bp.z), KEEP_FIRE])
	# the walks the world's own tests and its patrols take: the camps' patrol rounds and the fen postern's crest path
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var pat: Variant = c.get("patrol", [])
		if pat is Array:
			_keep_line(pat as Array, KEEP_WALK)
	var crest: Variant = (load("res://core/life/secrets/site_fen.gd") as GDScript).get_script_constant_map().get("CREST", [])
	if crest is Array:
		_keep_line(crest as Array, KEEP_WALK)
	var cast := load("res://core/life/village/village_cast.gd") as GDScript
	var outposts: Dictionary = cast.get_script_constant_map().get("OUTPOSTS", {}) if cast else {}
	for id: String in outposts:
		var nears: Variant = (outposts[id] as Dictionary).get("near", [])
		for nv: Variant in (nears if nears is Array else [nears]):
			_keep.append([nv as Vector2, KEEP_OUTPOST])
	for slots: Dictionary in [RealmLayout.SLOTS, RealmReaches.SLOTS]:
		for rid: String in slots:
			for s: Dictionary in slots[rid]:
				var q: Vector2 = s.at
				var kind := String(s.kind)
				_keep.append([q, float(KEEP_SLOT.get(kind, 14.0)), true])
				if kind.begins_with("poi"):
					_add_interest(Rect2(q - Vector2(6, 6), Vector2(12, 12)))


## A walked line (a patrol round, a crest path) kept clear: a round of `rad` every few metres along it.
static func _keep_line(pts: Array, rad: float) -> void:
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]          # (a patrol is a loop; the crest's closing leg only adds a few rounds)
		var n := maxi(1, ceili(a.distance_to(b) / 3.0))
		for k in n:
			_keep.append([a.lerp(b, float(k) / float(n)), rad])


static func _add_interest(r: Rect2) -> void:
	for cj in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
		for ci in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			var key := Vector2i(ci, cj)
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(r)


## Distance from q to the nearest thing worth a look (capped at `cap`).
static func _interest_d(q: Vector2, cap := 120.0) -> float:
	var best := cap
	var n := ceili(cap / CELL)
	var c0 := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	for dj in range(-n, n + 1):
		for di in range(-n, n + 1):
			for r: Rect2 in _grid.get(c0 + Vector2i(di, dj), []):
				var dx := maxf(maxf(r.position.x - q.x, 0.0), q.x - r.end.x)
				var dz := maxf(maxf(r.position.y - q.y, 0.0), q.y - r.end.y)
				best = minf(best, sqrt(dx * dx + dz * dz))
	return best


# --- the tests a spot must pass ----------------------------------------------------------------------

## The region a place at q belongs to, or "" where the wayside leaves the ground alone.
static func _region(q: Vector2) -> String:
	var rd := RealmLayout.region_at(q.x, q.y)
	var id := String(rd.get("id", ""))
	if id in Themes.SKIP:
		return ""
	return id if id != "" else "meadow"


## Ground under q as [height, is the terrain itself].
static func _ground(q: Vector2) -> Array:
	var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x + 0.0037, 140.0, q.y + 0.0029), Vector3(q.x, -70.0, q.y), Layers.WORLD | Layers.PROPS))
	if hit.is_empty():
		return [RealmLayout.macro_height(q.x, q.y), true]
	return [(hit.position as Vector3).y, String((hit.collider as Node).name).begins_with("Terrain")]


## Can a place of `kind` stand at q facing `yaw`? Returns its ground height, or NAN.
static func _fits(kind: String, q: Vector2, yaw: float) -> float:
	var d: Dictionary = Themes.KINDS[kind]
	var r := float(d.r)
	if not RealmLayout.BOUNDS.grow(-16.0).has_point(q) or Tables.on_edge_wall(q, r + 2.0):
		return _no("edge")
	for t: Array in Themes.TOWNS:
		if q.distance_to(t[0]) < float(t[1]) + r:
			return _no("town")
	for kp: Array in _kgrid.get(Vector2i(floori(q.x / CELL), floori(q.y / CELL)), []):
		if q.distance_to(kp[0]) < _keep_d(float(kp[1]), r, kp.size() > 2):
			return _no("keep-out")
	for sx: float in [-262.0, 262.0]:
		if absf(q.x - sx) < r + 1.0:
			return _no("nav seam")
	# the March Wall (x +-155 across the old Realm) and its gates: the wall's own dressing stands there
	if q.y < RealmLayout.OLD_BOUNDS.end.y + 2.0 and absf(absf(q.x) - RealmLayout.MARCH_WALL_X) < r + 3.0:
		return _no("march wall")
	for gq: Vector2 in RealmLayout.MARCH_GATES:
		if q.distance_to(gq) < r + 14.0:
			return _no("march wall")
	for sz: float in [86.0, 246.0]:
		if absf(q.y - sz) < r + 1.0:
			return _no("nav seam")
	if Rect2(-34, -122, 68, 114).has_point(q) or Rect2(-66, 142, 114, 54).has_point(q):
		return NAN                                   # the rift and the Ossuary's pit
	var pd := RealmLayout.path_dist(q)
	if kind == "milestone":
		if pd < 1.4 or pd > 3.4:
			return _no("milestone off its way")
	elif pd < (1.5 + r * 0.35 if _loose else r + 2.2):
		return _no("way")
	var rect := Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0)
	if not _clear(rect, 0.3 if _loose else (1.2 if kind != "milestone" else 0.4)):
		return _no("site")
	var c0 := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for v: Dictionary in _pgrid.get(c0 + Vector2i(di, dj), []):
				var va: Vector3 = v.at
				if Vector2(va.x, va.z).distance_to(q) < ((float(v.r) + r) * 0.75 if _loose else float(v.r) + r + 1.0):
					return _no("another place")
	var c: Array = _ground(q)
	if not bool(c[1]):
		return _no("not terrain")
	var gy := float(c[0])
	if gy < RealmLayout.LAVA_Y + 6.0:
		return _no("lava")
	if bool(d.get("sunk", false)):
		# a ruin sunk in a mere: its middle in open water, a wading depth or more
		return gy if Land.in_water(q.x, q.y) and gy < WATER - 0.4 and gy > WATER - 3.0 else _no("not sunk")
	var lo := gy
	var hi := gy
	var wet := bool(d.get("wet", false))
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		var s: Array = _ground(q + Vector2(cos(a), sin(a)) * r * 0.85)
		if not bool(s[1]):
			return _no("not terrain")
		lo = minf(lo, float(s[0]))
		hi = maxf(hi, float(s[0]))
	if hi - lo > float(d.rise) * 1.25:
		return _no("uneven")
	if wet:
		# a shore: dry under the landward end, open water a few metres out in front (local -z)
		if gy < WATER + 0.05 or gy > WATER + 0.9:
			return _no("no shore")
		var front := Vector2(-sin(yaw), -cos(yaw))
		for k: float in [4.5, 6.5]:
			var w := q + front * k
			if not Land.in_water(w.x, w.y) or float(_ground(w)[0]) > WATER - 0.15:
				return _no("no water ahead")
		return gy
	if (lo < WATER + 0.3 and Tables.wet(q.x, q.y)) or Land.in_water(q.x, q.y):
		return _no("water")
	# nothing standing there already (a rock, a wall, a wonder) above knee height, nor overhead (a gate's vault, an arch)
	var sq := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(r * 1.6, 6.3, r * 1.6)
	sq.shape = bx
	sq.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, gy + 3.85, q.y))
	sq.collision_mask = Layers.WORLD | Layers.PROPS
	# room for every overlap: with 8, the terrain's own faces could fill the list before a rock beside them, and which
	# came first is Jolt's order, which shifts with the build's timing (the plan, the wood's fingerprint and the
	# necropolis' grass came out one of two ways between runs)
	for h: Dictionary in _space.intersect_shape(sq, 64):
		if not String((h.collider as Node).name).begins_with("Terrain"):
			return _no("standing")
	return gy


## How far a place's middle keeps from a round of radius `kr` (a camp, fire or slot). The last-resort pass for the named
## places (`_loose`) comes as near as the wayside test's floors allow (a camp 12 m, a fire 11 m); the layout's slots' own
## rounds (`slot`) do not count then, the live camps and fires and the sites hold the ground.
static func _keep_d(kr: float, r: float, slot: bool) -> float:
	if _loose:
		if slot:
			return kr * 0.4                      # (a slot's round is for what may be built there, but its core stays clear: a reshuffled loose place once sat on the Grandmother Oak)
		return 0.0 if kr >= 15.0 else kr - 0.5
	return kr + (r if slot else r * 0.4)


static func _no(why: String) -> float:
	rejects[why] = int(rejects.get(why, 0)) + 1
	return NAN


## LoreKit.clear_of (off the ways and every site by `margin`) with the sites looked up on a grid.
static func _clear(rect: Rect2, margin: float) -> bool:
	if _sgrid.is_empty():
		var sites := WorldLanes.sites
		_sraid.clear()
		for i in sites.size():
			_sraid.append(String(sites[i].name).begins_with("raid_"))
			var r: Rect2 = (sites[i].rect as Rect2).grow(2.0)
			for cj in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				for ci in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
					var key := Vector2i(ci, cj)
					if not _sgrid.has(key):
						_sgrid[key] = []
					(_sgrid[key] as Array).append(i)
	var g := rect.grow(margin)
	for cj in range(floori(g.position.y / CELL), floori(g.end.y / CELL) + 1):
		for ci in range(floori(g.position.x / CELL), floori(g.end.x / CELL) + 1):
			for i: int in _sgrid.get(Vector2i(ci, cj), []):
				var st: Dictionary = WorldLanes.sites[i]
				var sr: Rect2 = st.rect
				if sr.position.x - margin >= rect.end.x or sr.end.x + margin <= rect.position.x or sr.position.y - margin >= rect.end.y or sr.end.y + margin <= rect.position.y:
					continue                             # (the plain box test first, without the grow's copy)
				if not (_sraid[i] as bool) or WorldLanes.site_hits_rect(st, rect, margin):
					return false
	# the ways: LoreKit's own test with no site in it
	var pts: Array[Vector2] = [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.get_center()]
	for si: int in _segs_near(rect.grow(margin + 2.0)):
		var sg: Array = _segs[si]
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		for pq in pts:
			var t := clampf((pq - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if pq.distance_to(a + ab * t) - float(sg[2]) < margin:
				return false
	return true


## Distance from q to the nearest way, on the planner's own grid (99 where none is within 64 m): it only orders spots.
static func _way_d(q: Vector2) -> float:
	var best := 99.0
	for si: int in _segs_near(Rect2(q - Vector2(64.0, 64.0), Vector2(128.0, 128.0))):
		var sg: Array = _segs[si]
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t) - float(sg[2]))
	return best


## The yaw that turns a place's front (local -z) to the nearest way.
static func _face(q: Vector2) -> float:
	var best := q + Vector2(0, -1)
	var bd := INF
	var near := _segs_near(Rect2(q - Vector2(64.0, 64.0), Vector2(128.0, 128.0)))
	if near.is_empty():
		near = range(_segs.size())
	for i: int in near:
		var sg: Array = _segs[i]
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var c := a + ab * t
		var dd := c.distance_squared_to(q)
		if dd < bd:
			bd = dd
			best = c
	var d := best - q
	return atan2(-d.x, -d.y)


static func _index_segs() -> void:
	_segs.clear()
	_seg_grid.clear()
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		var w := float(p.w)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var idx := _segs.size()
			_segs.append([a, b, w])
			var r := Rect2(a, Vector2.ZERO).expand(b).grow(w + 2.0)
			for cj in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				for ci in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
					var key := Vector2i(ci, cj)
					if not _seg_grid.has(key):
						_seg_grid[key] = []
					(_seg_grid[key] as Array).append(idx)


## Indices of the ways' segments that may come within reach of r.
static func _segs_near(r: Rect2) -> Array:
	var seen := {}
	for cj in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
		for ci in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for i: int in _seg_grid.get(Vector2i(ci, cj), []):
				seen[i] = true
	return seen.keys()


## The kind for a place at q (`ctx` way / open / wood) by its region's weights, kept from repeating nearby.
static func _kinds_for(region: String, q: Vector2, ctx: String) -> Array[String]:
	var biome := RealmLayout.biome_at(q.x, q.y)
	var w: Dictionary = Themes.weights(region, biome, ctx)
	var cand := {}
	for kind: String in w:
		if kind == "milestone" or kind == "lookout":
			continue                                 # their own passes
		var kd: Dictionary = Themes.KINDS.get(kind, {})
		if kd.is_empty() or not (ctx in (kd.ctx as Array) or (ctx == "wood" and "open" in (kd.ctx as Array))):
			continue
		var f := float(w[kind])
		for at: Vector2 in _by_kind.get(kind, []):
			var dd := q.distance_to(at)
			if dd < SAME_NEAR:
				f *= 0.12
			elif dd < SAME_NEAR * 2.0:
				f *= 0.6
		cand[kind] = f
	var out: Array[String] = []
	while not cand.is_empty() and out.size() < 4:
		var tot := 0.0
		for kind: String in cand:
			tot += float(cand[kind])
		var pick := _rng.randf() * tot
		var chosen := ""
		for kind: String in cand:
			pick -= float(cand[kind])
			if pick <= 0.0:
				chosen = kind
				break
		if chosen == "":
			chosen = cand.keys()[0]
		out.append(chosen)
		cand.erase(chosen)
	return out


## Plan one place (lays it out, measures its footprint). Returns it, or {} when its pieces do not fit after all.
static func _place(kind: String, q: Vector2, yaw: float, gy: float, region: String, ctx: String) -> Dictionary:
	var seed_n := hash([kind, int(q.x * 10.0), int(q.y * 10.0)])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var geo := Kit.layout(kind, rng)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, gy, q.y))
	var feet := Kit.footprints(geo, xf)
	var top := gy
	for r: Rect2 in feet:
		if RealmLayout.path_dist(r.get_center()) < maxf(r.size.x, r.size.y) * 0.5 + 0.6:
			return {}
		top = maxf(top, float(_ground(r.get_center())[0]))
	_n += 1
	var v := {"id": "%03d" % _n, "kind": kind, "at": Vector3(q.x, gy, q.y), "yaw": yaw, "xf": xf, "geo": geo, "feet": feet, "top": top,
		"region": region, "ctx": ctx, "seed": seed_n, "r": float(Themes.KINDS[kind].r)}
	for e: Dictionary in geo:
		if e.t == "tower":
			v["tower_top"] = float(e.h)
	plan.append(v)
	var pk := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	if not _pgrid.has(pk):
		_pgrid[pk] = []
	(_pgrid[pk] as Array).append(v)
	if not _by_kind.has(kind):
		_by_kind[kind] = []
	(_by_kind[kind] as Array).append(q)
	var r0 := float(Themes.KINDS[kind].r)
	_add_interest(Rect2(q - Vector2(r0, r0), Vector2(r0, r0) * 2.0))
	return v


## Try `kinds` (in order) at the spots `qs` (in order); the first that fits is planned.
static func _try(kinds: Array[String], qs: Array, region: String, ctx: String) -> Dictionary:
	for kind: String in kinds:
		var wet := bool(Themes.KINDS[kind].get("wet", false))
		for q: Vector2 in qs:
			var yaw := _shore_yaw(q) if wet else 0.0
			var gy := _fits(kind, q, yaw)
			if is_nan(gy):
				continue
			if not wet:
				yaw = _face(q)
			var v := _place(kind, q, yaw, gy, region, ctx)
			if not v.is_empty():
				return v
	return {}


## Which way the water lies from a shore point (the deepest of eight looks), for a jetty.
static func _shore_yaw(q: Vector2) -> float:
	var best := 0.0
	var lo := INF
	for i in 8:
		var a := TAU * float(i) / 8.0
		var w := q + Vector2(cos(a), sin(a)) * 5.5
		var g := float(_ground(w)[0])
		if g < lo:
			lo = g
			best = a
	var dirv := Vector2(cos(best), sin(best))
	return atan2(-dirv.x, -dirv.y)


static func _ctx(q: Vector2) -> String:
	if RealmLayout.path_dist(q) < 16.0:
		return "way"
	return "wood" if RealmLayout.biome_at(q.x, q.y) == "oldforest" else "open"


# --- the passes ------------------------------------------------------------------------------------

## A lookout on each region's most prominent rise (one per region, where one stands clear of the rest).
static func _lookouts() -> void:
	for rd: Dictionary in RealmLayout.REGIONS:
		var id := String(rd.id)
		if not Themes.REGIONS.has(id) or not ("lookout" in (Themes.REGIONS[id].get("open", {}) as Dictionary)):
			continue
		var area: Rect2 = rd.rect if rd.has("rect") else Rect2((rd.c as Vector2) - Vector2(rd.r, rd.r), Vector2(rd.r, rd.r) * 2.0)
		var cands: Array = []
		var z := area.position.y + 6.0
		while z < area.end.y - 6.0:
			var x := area.position.x + 6.0
			while x < area.end.x - 6.0:
				var q := Vector2(x, z)
				if RealmLayout.place_weight(rd, x, z) > 0.9:
					var gy := float(_ground(q)[0])
					var ring := 0.0
					for i in 8:
						var a := TAU * float(i) / 8.0
						ring += float(_ground(q + Vector2(cos(a), sin(a)) * 26.0)[0])
					cands.append([gy - ring / 8.0, q])
				x += 9.0
			z += 9.0
		cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var tries := 0
		for c: Array in cands:
			if float(c[0]) < 1.6 or tries > 40:
				break
			tries += 1
			var lk: Array[String] = ["lookout"]
			var v := _try(lk, [c[1]], id, "open")
			if not v.is_empty():
				break


## Walk every way; wherever nothing worth a look stands within GAP_WAY, put a place beside it.
static func _ways() -> void:
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		var w := float(p.w)
		var s := 0.0
		var side := 1.0 if hash(String(p.id)) % 2 == 0 else -1.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			var t := WAY_STEP * 0.5
			while t < seg:
				var q := a.lerp(b, t / seg)
				t += WAY_STEP
				s += WAY_STEP
				rejects["way samples"] = int(rejects.get("way samples", 0)) + 1
				if _interest_d(q, GAP_WAY + 1.0) <= GAP_WAY:
					continue
				var region := _region(q)
				if region == "":
					continue
				rejects["way gaps"] = int(rejects.get("way gaps", 0)) + 1
				var dirv := (b - a) / seg
				var nrm := Vector2(-dirv.y, dirv.x)
				var qs: Array = []
				for off: float in [4.0, 7.5, 12.0, 17.0, 23.0]:
					for sg: float in [side, -side]:
						for sh: float in [0.0, 7.0, -7.0]:
							qs.append(q + nrm * sg * (w + off + 2.0) + dirv * sh)
				var kinds := _kinds_for(region, q, "way")
				var v := _try(kinds, qs, region, "way")
				if v.is_empty():
					var kinds2 := _kinds_for(region, q, "open")
					v = _try(kinds2, qs, region, "way")
				if not v.is_empty():
					side = -side                         # the next one stands on the other side


## Milestones along the ways of the new ground, one every MILE, alternating sides.
static func _miles() -> void:
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		var w := float(p.w)
		var acc := MILE * 0.5
		var side := 1.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			var t := 0.0
			while t < seg:
				var step := minf(seg - t, 4.0)
				t += step
				acc += step
				if acc < MILE:
					continue
				var q := a.lerp(b, t / seg)
				if RealmLayout.OLD_BOUNDS.grow(-2.0).has_point(q):
					continue                         # the old road has its own waystones
				var region := _region(q)
				if region == "":
					continue
				var near := false
				for v: Dictionary in plan:
					if v.kind == "milestone" and Vector2((v.at as Vector3).x, (v.at as Vector3).z).distance_to(q) < MILE * 0.7:
						near = true
						break
				if near:
					continue
				var dirv := (b - a) / seg
				var nrm := Vector2(-dirv.y, dirv.x)
				var qs: Array = []
				for sg: float in [side, -side]:
					for sh: float in [0.0, 3.0, -3.0, 6.0]:
						qs.append(q + nrm * sg * (w + 2.2) + dirv * sh)
				var ms: Array[String] = ["milestone"]
				var v2 := _try(ms, qs, region, "way")
				if not v2.is_empty():
					acc = 0.0
					side = -side


## Off the ways: the open ground and the woods, filled to GAP_OPEN, the emptiest first.
static func _open() -> void:
	var cands: Array = []
	var b := RealmLayout.BOUNDS.grow(-18.0)
	var z := b.position.y
	while z < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			var q := Vector2(x + _rng.randf_range(-6.0, 6.0), z + _rng.randf_range(-6.0, 6.0))
			cands.append([_interest_d(q, 120.0), q])
			x += OPEN_STEP
		z += OPEN_STEP
	cands.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) > float(c[0]))
	for c: Array in cands:
		var q: Vector2 = c[1]
		if _interest_d(q, GAP_OPEN + 1.0) <= GAP_OPEN:
			continue
		var region := _region(q)
		if region == "":
			continue
		rejects["open gaps"] = int(rejects.get("open gaps", 0)) + 1
		var ctx := _ctx(q)
		var qs: Array = [q]
		for r: float in [4.0, 8.0, 12.0]:
			for i in 6:
				var a := TAU * float(i) / 6.0 + r
				qs.append(q + Vector2(cos(a), sin(a)) * r)
		_try(_kinds_for(region, q, ctx), qs, region, ctx)


## The dressing: the minor kinds (walls, stones, cairns, carts, woodpiles, field corners...) spread over every
## suitable spot DRESS_SPACING apart, by the region's taste and its ground's share (DENSITY), so the land between the
## places is lived-in and fought-over rather than bare.
static func _dress() -> void:
	var cands: Array = []
	var b := RealmLayout.BOUNDS.grow(-18.0)
	var z := b.position.y
	while z < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			cands.append(Vector2(x + _rng.randf_range(-5.0, 5.0), z + _rng.randf_range(-5.0, 5.0)))
			x += DRESS_STEP
		z += DRESS_STEP
	for i in range(cands.size() - 1, 0, -1):                 # a fixed shuffle: no sweep direction shows in the spacing
		var j := _rng.randi_range(0, i)
		var tmp: Vector2 = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	for q: Vector2 in cands:
		var share := float(DENSITY["old"]) if RealmLayout.OLD_BOUNDS.has_point(q) else (float(DENSITY["marches"]) if RealmReaches.MARCH_BOUNDS.has_point(q) else float(DENSITY["reaches"]))
		if _rng.randf() > share:
			continue
		if _near_place(q, DRESS_SPACING):
			continue
		var region := _region(q)
		if region == "":
			continue
		rejects["dress tries"] = int(rejects.get("dress tries", 0)) + 1
		var ctx := _ctx(q)
		var kinds: Array[String] = []
		for kind: String in _kinds_for(region, q, ctx if ctx != "wood" else "open"):
			if bool(Themes.KINDS[kind].get("dress", false)) and kinds.size() < 2:
				kinds.append(kind)
		if kinds.is_empty():
			continue
		var qs: Array = [q, q + Vector2(4.5, 1.5), q + Vector2(-1.5, -4.5)]
		_try(kinds, qs, region, ctx)


static func _near_place(q: Vector2, d: float) -> bool:
	var n := ceili(d / CELL)
	var c0 := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	for dj in range(-n, n + 1):
		for di in range(-n, n + 1):
			for v: Dictionary in _pgrid.get(c0 + Vector2i(di, dj), []):
				var a: Vector3 = v.at
				if Vector2(a.x, a.z).distance_to(q) < d:
					return true
	return false


# --- names, boxes and writings -------------------------------------------------------------------------

static func _assign() -> void:
	var boxes := {}                              # region -> count
	for region: String in Themes.NAMED:
		for e: Dictionary in Themes.NAMED[region]:
			var best := {}
			var bd := INF
			for v: Dictionary in plan:
				if v.region != region or String(v.get("name", "")) != "" or not (String(v.kind) in (e.kinds as Array)):
					continue
				var d := RealmLayout.path_dist(Vector2((v.at as Vector3).x, (v.at as Vector3).z))
				if d < bd:
					bd = d
					best = v
			if best.is_empty():
				best = _force(region, e.kinds as Array)
			if best.is_empty():
				print("WAYSIDE no place for %s in %s" % [e.id, region])
				PlacementLog.skip("wayside", String(e.id), Vector3.ZERO, "no %s in %s" % [e.kinds, region])
				continue
			best["name"] = String(e.name)
			best["line"] = String(e.line)
			best["poi"] = "way_" + String(e.id)
			_give_lore(best, String(e.lore))
			if bool(e.get("box", false)):
				_give_box(best, "way_" + String(e.id), boxes)
	# one more box in each themed region that has none yet, on a place that can hold one
	for region: String in Themes.REGIONS:
		var want := 2 if region in RealmReaches.IDS else 1
		for v: Dictionary in plan:
			if int(boxes.get(region, 0)) >= want:
				break
			if v.region == region and String(v.get("box", "")) == "" and bool(Themes.KINDS[v.kind].get("cache", false)):
				_give_box(v, "way_%s_%s" % [region, v.id], boxes)
	for region: String in Themes.LORE:
		for e: Array in Themes.LORE[region]:
			var done := false
			for v: Dictionary in plan:
				if v.region == region and String(v.get("lore", "")) == "" and String(v.kind) in (e[1] as Array):
					_give_lore(v, String(e[0]))
					done = true
					break
			if not done:
				var f := _force(region, ["milestone"])
				if not f.is_empty():
					_give_lore(f, String(e[0]))


## A place of one of `kinds` in `region` where the passes left none: the open ground nearest the region's ways. A
## small region its camps, fire and landmark fill (the Bellfall) has it on the ground just round it (stage 1), failing that nearer the camps and the ways (stage 2: `_loose`, a named
## place is worth more than the quiet round a camp), failing that a little further out (stage 3).
static func _force(region: String, kinds: Array, stage := 0) -> Dictionary:
	var rd := {}
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == region:
			rd = r
	if rd.is_empty():
		return {}
	var ck := "%s/%d" % [region, stage]
	if not _force_qs.has(ck):
		_force_qs[ck] = _force_spots(rd, stage)
	var qs: Array = _force_qs[ck]
	_loose = stage >= 2
	var found := {}
	for kind: String in kinds:
		var ks: Array[String] = [kind]
		found = _try(ks, qs, region, "way")
		if not found.is_empty():
			break
	_loose = false
	if not found.is_empty():
		return found
	return {} if stage >= 3 else _force(region, kinds, stage + 1)


## The spots `_force` tries in a region at a stage: by its ways, then the rest nearest them (cached per region).
static func _force_spots(rd: Dictionary, stage: int) -> Array:
	var area: Rect2 = rd.rect if rd.has("rect") else Rect2((rd.c as Vector2) - Vector2(rd.r, rd.r), Vector2(rd.r, rd.r) * 2.0)
	var w_min := 0.8 if stage == 0 else (0.25 if stage < 3 else -1.0)   # (place_weight falls to 0 over 18 m past a rect: 0.25 is ~13 m out)
	if stage > 0:
		area = area.grow(14.0 if stage < 3 else 34.0)
	var qs: Array = []
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			var t := 3.0
			while t < seg:
				var q := a.lerp(b, t / seg)
				t += 9.0
				if not area.has_point(q) or RealmLayout.place_weight(rd, q.x, q.y) < w_min:
					continue
				var dirv := (b - a) / seg
				var nrm := Vector2(-dirv.y, dirv.x)
				for off: float in [3.0, 8.0, 14.0, 20.0]:
					for sg: float in [1.0, -1.0]:
						qs.append(q + nrm * sg * (float(p.w) + off))
	# then the rest of the region, nearest its ways first
	var more: Array = []
	var z := area.position.y + 4.0
	while z < area.end.y - 4.0:
		var x := area.position.x + 4.0
		while x < area.end.x - 4.0:
			var q2 := Vector2(x, z)
			if RealmLayout.place_weight(rd, x, z) > w_min:
				more.append([_way_d(q2), q2])
			x += 7.0
		z += 7.0
	more.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for m: Array in more:
		qs.append(m[1])
	# (a region with no room for the kind gives up soon; the last stage looks deeper in, past the ways' busy
	# verges: 19 Nov, the downs' 150 nearest spots all had a place on them and the Lost Fold went unbuilt)
	return qs.slice(0, 150 if stage < 3 else 450)


## Give a place its writing: its own carrier piece if it has one of the right kind, else a carrier beside it.
static func _give_lore(v: Dictionary, id: String) -> void:
	if id == "":
		return
	v["lore"] = id
	for e: Dictionary in v.geo:
		if e.t == "lore":
			if e.c != "waystone":
				var lp := (v.xf as Transform3D) * Vector3((e.p as Vector2).x, 0.0, (e.p as Vector2).y)
				(v.feet as Array).append(Rect2(Vector2(lp.x, lp.z) - Vector2(0.75, 0.75), Vector2(1.5, 1.5)))
			return
	var c := "page"
	if String(v.kind) in ["stones", "circle", "barrow", "cairns", "bones", "debris", "lookout"]:
		c = "rune"
	elif String(v.kind) in ["fold", "farm"]:
		c = "notice"
	elif String(v.kind) in ["well", "blocks"]:
		c = "tablet"
	var r := float(v.r)
	var q := Vector2(r * 0.45, -r * 0.8)
	(v.geo as Array).append({"t": "lore", "c": c, "p": q})
	var p := (v.xf as Transform3D) * Vector3(q.x, 0.0, q.y)
	(v.feet as Array).append(Rect2(Vector2(p.x, p.z) - Vector2(0.7, 0.7), Vector2(1.4, 1.4)))


static func _give_box(v: Dictionary, id: String, boxes: Dictionary) -> void:
	v["box"] = id
	var tier := "iron" if v.kind == "lookout" else "wood"
	v["box_tier"] = tier
	var loot: Array = Themes.LOOT[tier]
	v["loot"] = loot[absi(hash(id)) % loot.size()]
	boxes[v.region] = int(boxes.get(v.region, 0)) + 1


# --- build ------------------------------------------------------------------------------------------

## REACH_POIS' build step (after the flora): the planned places, a holder per 96 m chunk drawn as merged meshes
## (wayside_build.gd), lookouts alone; the named ones are discoveries.
const BUILD_CELL := 96.0
const VIEW_END := 110.0             ## from a chunk's middle (the integrator's range: 150 drew ~40 more in the Thornwarden fight)
const TALL_RANGE := 220.0           ## a lookout's tower reads from further

static func build(holder: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	built = 0
	if plan.is_empty():
		return
	var root := Node3D.new()
	root.name = "Wayside"
	root.set_meta("site", "wayside")
	holder.add_child(root)
	var space := root.get_world_3d().direct_space_state
	var cells := {}
	for v: Dictionary in plan:
		var a: Vector3 = v.at
		var key: Variant = "tall_" + String(v.id) if v.kind == "lookout" else Vector2i(floori(a.x / BUILD_CELL), floori(a.z / BUILD_CELL))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(v)
	for key: Variant in cells:
		var vs: Array = cells[key]
		var nm := ("Way_" + String(key)) if key is String else "Way_%d_%d" % [(key as Vector2i).x, (key as Vector2i).y]
		Build.build(root, nm, vs, space, TALL_RANGE if key is String else VIEW_END)
		built += vs.size()
	for v: Dictionary in plan:
		if String(v.get("poi", "")) != "":
			var host := Node3D.new()
			host.name = "Poi_" + String(v.poi)
			root.add_child(host)
			host.global_position = v.at
			host.add_to_group("world_poi")
			host.set_meta("poi", String(v.poi))
			host.set_meta("title", String(v.name))
			host.set_meta("line", String(v.line))
			host.set_meta("centre", v.at)
			host.set_meta("radius", float(v.r) + 5.0)
			host.set_meta("region", String(v.region))
			host.set_meta("wayside", String(v.kind))
	print("WAYSIDE built %d places in %d cells in %d ms" % [built, cells.size(), Time.get_ticks_msec() - t0])

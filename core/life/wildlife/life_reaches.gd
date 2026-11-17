extends RefCounted
## The Far Reaches' wildlife, and the Marches' regions that had next to none (docs/living_realm.md). A roster per
## region says what lives there; the spots are read from whatever the Realm built (structure tops and tree crowns
## round the region's places, big trunks, pools, open ground), off every camp (and the camp slots the enemy session
## fills), fire, site and raid floor. Each region draws from its own stream, so nothing the old Realm or the Marches
## placed moves. Placed by life_director.gd after its own passes; `add` is its _add_group.
##   crows     roosts of ravens on the region's places (or its trees, or its stones), strutting on the ground
##   owls      areas of big trunks in its woods, with field mice under them
##   hares     forms of two or three on open ground; foxes alone at the edges
##   flocks    lapwings feeding on the heath and the fields, lifting and wheeling when disturbed
##   fireflies clusters over its wet and grassy edges; bats over its ruins, crater and vaults
##   herons    on the banks of its pools, frogs in a chorus at the pools nobody claimed yet
## Load by path: const Reaches := preload("res://core/life/wildlife/life_reaches.gd")

const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")
const Birds := preload("res://core/life/wildlife/life_birds.gd")
const Flock := preload("res://core/life/wildlife/life_flock.gd")
const Pond := preload("res://core/life/wildlife/life_pond.gd")
const RL := preload("res://core/world/realm/realm_land.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const SEED := 13127
const SEARCH := 60                      ## lattice points a roster tests at most (each test ~0.2 ms: the scan is shuffled)

## region id -> {kind: how many}. crows = roosts, owls = areas, hares = forms, foxes, flocks = lapwing flocks,
## fireflies = clusters, bats = swarms, herons = pool groups, ponds = frog pools.
const ROSTER := {
	# --- the West Reach ---
	"greyfell": {"crows": 3, "bats": 1, "foxes": 1},
	"lanternwood": {"owls": 3, "fireflies": 3, "foxes": 1, "bats": 1, "crows": 2, "roadbats": 3},
	"kingsbarrows": {"crows": 3, "hares": 4, "flocks": 1, "foxes": 2, "bats": 1, "fireflies": 1, "roadbats": 1},
	"reedmere": {"herons": 2, "ponds": 2, "fireflies": 4, "crows": 2, "owls": 1, "bats": 1, "flocks": 1, "roadbats": 2},
	# --- the Deep South ---
	"fallow": {"hares": 4, "foxes": 3, "flocks": 2, "crows": 3, "owls": 1, "fireflies": 3, "bats": 1, "roadbats": 1},
	"arches": {"bats": 2, "crows": 2, "owls": 1, "foxes": 1, "hares": 3, "fireflies": 1, "roadbats": 1},
	"southwood": {"owls": 2, "fireflies": 3, "foxes": 1, "crows": 2, "bats": 1, "roadbats": 3},
	# --- the East Reach ---
	"bellfall": {"bats": 2, "crows": 2},
	"lastlight": {"hares": 3, "foxes": 1, "flocks": 1, "crows": 2, "fireflies": 2, "owls": 1},
	"nave": {"bats": 2, "herons": 1, "ponds": 1, "crows": 2, "owls": 1, "fireflies": 2, "roadbats": 1},
	"cairns": {"crows": 3, "hares": 4, "flocks": 2, "foxes": 2, "fireflies": 1},
	# --- the Marches' and the old Realm's empty ground ---
	"moor": {"hares": 2, "crows": 1, "flocks": 1},
	"plinth": {"crows": 2, "owls": 1, "foxes": 1},
	"oak": {"owls": 1, "fireflies": 2, "crows": 1, "roadbats": 1},
	"anchorholds": {"crows": 2},
	"siege": {"crows": 2, "foxes": 1},
	"saltpans": {"flocks": 1, "hares": 1},
	"crags": {"crows": 1},
	"downs": {"hares": 2, "foxes": 1, "crows": 1},
	"holds": {"owls": 1, "foxes": 1, "roadbats": 1},
	"well": {"crows": 1, "hares": 1},
	"sorrow": {"roadbats": 2},
	"thornwood": {"roadbats": 1},
}

## Hand-placed (the Far Reaches' first life pass, kept): bats round the high and hollow places at the height of what
## stands there [xz, height over the ground, radius, count], and fireflies on the meres' reedy edges, the hamlet's
## hedges and orchard, the lit wood, the nave's shore, the Southwood. The rosters' own bats and fireflies fill in
## round these (never within 20-30 m of one).
const BATS := [[Vector2(-318, -108), 18.0, 10.0, 7], [Vector2(-345, 152), 6.0, 7.0, 5], [Vector2(0, 342), 22.0, 14.0, 8],
	[Vector2(-60, 352), 14.0, 7.0, 4], [Vector2(350, 102), 8.0, 10.0, 6], [Vector2(318, 164), 16.0, 14.0, 8],
	[Vector2(327, 324), 16.0, 6.0, 5], [Vector2(226, 362), 8.0, 7.0, 4]]
const FIREFLIES := [Vector2(-300, 330), Vector2(-262, 360), Vector2(-344, 312), Vector2(-178, 286), Vector2(-136, 318),
	Vector2(-320, 4), Vector2(-344, -20), Vector2(-300, 40), Vector2(296, 150), Vector2(342, 190), Vector2(140, 320),
	Vector2(196, 344), Vector2(306, 40), Vector2(-60, 300), Vector2(40, 300)]

static var _camps: Array[Vector2] = []
static var _fires: Array[Vector2] = []
static var report := {}                 ## region -> {kind: n placed} (tests, census)
static var new_pools: Array[Dictionary] = []   ## LifePlace.pools(true) as place() found them (life_signs.gd reuses them)
static var _memo := {}
static var _tree_cells := {}            ## Vector2i -> the flora's trees in that 24 m cell                  ## lattice point -> [q, cover, biome] or [] (the scan's tests, made once)


## Places every roster. `dir` is the director (its groups are read so nothing lands on its own placements).
static func place(dir: Node3D, root: Node, space: PhysicsDirectSpaceState3D, add: Callable) -> void:
	report = {}
	_tree_cells.clear()
	var t0 := Time.get_ticks_msec()
	_camps = keep_camps()
	_fires = keep_fires(root)
	var by_region := {}
	for t: Dictionary in LifePlace.trunks(root, ["oldforest", "ruin", "glade", "fen", "heath", "meadow"], 0.3, true):
		var b: Vector3 = t.base
		var rid0 := String(RealmLayout.region_at(b.x, b.z).get("id", ""))
		if ROSTER.has(rid0):
			if not by_region.has(rid0):
				by_region[rid0] = []
			(by_region[rid0] as Array).append(t)
	var pools := LifePlace.pools(true)
	new_pools = pools
	_hand_placed(dir)

	for rid: String in ROSTER:
		var reg := _region(rid)
		if reg.is_empty():
			continue
		var want: Dictionary = ROSTER[rid]
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + absi(hash(rid)) % 100000
		var scan := _scan(reg, rng)
		for k: String in ["crows", "owls", "herons", "ponds", "hares", "foxes", "flocks", "fireflies", "bats", "roadbats"]:
			var n := int(want.get(k, 0))
			if n <= 0:
				continue
			var made := 0
			match k:
				"crows": made = _crows(dir, root, space, add, reg, rng, n)
				"owls": made = _owls(dir, space, add, reg, rng, n, by_region.get(rid, []))
				"herons": made = _herons(dir, space, add, reg, rng, n, pools)
				"ponds": made = _ponds(dir, space, add, reg, rng, n, pools)
				"hares": made = _hares(dir, space, add, reg, rng, n, scan)
				"foxes": made = _foxes(dir, space, add, reg, rng, n, scan)
				"flocks": made = _flocks(dir, add, reg, rng, n, scan)
				"fireflies": made = _fireflies(dir, reg, rng, n, scan)
				"bats": made = _bats(dir, space, reg, rng, n)
				"roadbats": made = _road_bats(dir, reg, rng, n)
			if made > 0:
				if not report.has(rid):
					report[rid] = {}
				(report[rid] as Dictionary)[k] = made
	print("LIFE reaches in %d ms: %s" % [Time.get_ticks_msec() - t0, report])



static func _hand_placed(dir: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var flies: Array = dir.get("fireflies")
	for i in FIREFLIES.size():
		var s: Vector2 = FIREFLIES[i]
		if not _clear(s, 16.0, 5.0):
			continue
		var n := 12 + (i % 3) * 4
		var mmi := LifeKit.group("firefly", n)
		mmi.name = "FirefliesR"
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))))
			mmi.multimesh.set_instance_custom_data(k, Color(rng.randf_range(2.0, 4.5), rng.randf_range(0.12, 0.3), rng.randf_range(0.5, 1.7), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-7, -0.5, -7), Vector3(14, 4, 14))
		mmi.visibility_range_end = 55.0
		mmi.visibility_range_end_margin = 6.0
		dir.add_child(mmi)
		mmi.global_position = Vector3(s.x, RL.height_at(s.x, s.y), s.y)
		flies.append(mmi)
		_note(dir, "firefly", n)
	var swarms: Array = dir.get("bats")
	for e: Array in BATS:
		var at: Vector2 = e[0]
		var r: float = e[2]
		var n2: int = e[3]
		var mmi2 := LifeKit.group("bat", n2)
		mmi2.name = "BatsR"
		for k in n2:
			mmi2.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2, 2), rng.randf_range(-1.5, 1.5), rng.randf_range(-2, 2))))
			var sp := rng.randf_range(0.45, 0.9) * (1.0 if rng.randf() < 0.6 else -1.0)
			mmi2.multimesh.set_instance_custom_data(k, Color(r * rng.randf_range(0.45, 1.0), sp, rng.randf_range(1.0, 3.0), rng.randf_range(0.0, TAU)))
		mmi2.multimesh.custom_aabb = AABB(Vector3(-r * 1.5 - 3, -6, -r * 1.5 - 3), Vector3(r * 3 + 6, 12, r * 3 + 6))
		mmi2.visibility_range_end = 100.0
		mmi2.visibility_range_end_margin = 10.0
		dir.add_child(mmi2)
		mmi2.global_position = Vector3(at.x, RL.height_at(at.x, at.y) + float(e[1]), at.y)
		swarms.append(mmi2)
		_note(dir, "bat", n2)


# --- keep-offs -------------------------------------------------------------------------------------

## Every camp's ground (EnemySpawner.REALM_CAMPS, their patrols, and the Far Reaches' camp slots the enemy session
## fills): wildlife near a camp is on watch for good, and a creature on a camp's floor is in a fight.
static func keep_camps() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = c.at
		out.append(Vector2(at.x, at.z))
		for q: Variant in c.get("patrol", []):
			if q is Vector3:
				out.append(Vector2((q as Vector3).x, (q as Vector3).z))
			elif q is Vector2:
				out.append(q as Vector2)
	for rid: String in RealmReaches.SLOTS:
		for sl: Dictionary in RealmReaches.SLOTS[rid]:
			if String(sl.kind) == "camp":
				out.append(sl.at as Vector2)
	for el: Dictionary in (load("res://core/life/encounters/elites.gd").ELITES as Dictionary).values():
		for h: Vector2 in el.get("haunt", []):
			out.append(h)
	return out


## The fires (every region's fire slot and every brazier built): people and their light, not a hare's form.
static func keep_fires(root: Node) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for rid: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			if String(sl.kind) == "fire":
				out.append(sl.at as Vector2)
	if root != null:
		for b in root.find_children("*", "Brazier", true, false):
			var p := (b as Node3D).global_position
			out.append(Vector2(p.x, p.z))
	return out


static func _clear(p: Vector2, camp_r: float, fire_r := 9.0) -> bool:
	for c in _camps:
		if c.distance_squared_to(p) < camp_r * camp_r:
			return false
	for f in _fires:
		if f.distance_squared_to(p) < fire_r * fire_r:
			return false
	for rd: Dictionary in RealmLayout.RAIDS:
		if p.distance_to(rd.c) < float(rd.r) + 8.0:
			return false
	return true


## Near a group the director (or an earlier roster) already placed of this kind.
static func _taken(dir: Node3D, p: Vector2, kind: String, r: float) -> bool:
	for g: Node in dir.get("groups"):
		if not is_instance_valid(g) or String(g.get("kind")) != kind:
			continue
		var c: Vector3 = g.get("center")
		if Vector2(c.x, c.z).distance_to(p) < r:
			return true
	return false


# --- the region's ground ----------------------------------------------------------------------------

static func _region(rid: String) -> Dictionary:
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == rid:
			return r
	return {}


static func _in(reg: Dictionary, p: Vector2) -> bool:
	return String(RealmLayout.region_at(p.x, p.y).get("id", "")) == String(reg.id)


static func _bbox(reg: Dictionary) -> Rect2:
	if reg.has("rect"):
		var r: Rect2 = reg.rect
		return r.intersection(RealmLayout.BOUNDS.grow(-8.0))
	var c: Vector2 = reg.c
	var rr := float(reg.r)
	return Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0).intersection(RealmLayout.BOUNDS.grow(-8.0))


## The region's ground on a jittered 7 m lattice, shuffled: Vector2s, not yet tested (a roster needs a few spots, so
## each is tested only when a placement reaches it: _cand()).
static func _scan(reg: Dictionary, rng: RandomNumberGenerator) -> Array:
	_memo.clear()
	var out: Array = []
	var bb := _bbox(reg)
	var x := bb.position.x + 3.5
	while x < bb.end.x:
		var z := bb.position.y + 3.5
		while z < bb.end.y:
			out.append(Vector2(x + rng.randf_range(-2.5, 2.5), z + rng.randf_range(-2.5, 2.5)))
			z += 7.0
		x += 7.0
	LifePlace.shuffle(out, rng)
	return out


## A lattice point's test, made once: [q, canopy cover, biome] when it is the region's open ground off the ways, else [].
static func _cand(reg: Dictionary, q: Vector2) -> Array:
	if _memo.has(q):
		return _memo[q]
	var r: Array = []
	if RealmLayout.path_dist(q) > 2.5 and _in(reg, q) and LifePlace.open_ground(q.x, q.y):
		r = [q, Flora.cover_at(q.x, q.y), RealmLayout.biome_at(q.x, q.y)]
	_memo[q] = r
	return r


## Points beside the region's ways: one every `every` m along each way (either side, lo..hi m off its edge).
static func _along_ways(reg: Dictionary, rng: RandomNumberGenerator, every: float, lo: float, hi: float) -> Array[Vector2]:
	var bb := _bbox(reg)
	var out: Array[Vector2] = []
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var w := float(path.w)
		var carry := rng.randf() * every
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ln := a.distance_to(b)
			if ln < 0.01 or not bb.grow(4.0).intersects(Rect2(a, Vector2.ZERO).expand(b), true):
				carry += ln
				continue
			var side := (b - a).orthogonal() / ln
			var t := every - fmod(carry, every)
			while t < ln:
				var q := a.lerp(b, t / ln) + side * (1.0 if rng.randf() < 0.5 else -1.0) * (w + rng.randf_range(lo, hi))
				if bb.has_point(q):
					out.append(q)
				t += every
			carry += ln
	return out


## The verges (lo..hi m off a way) first, then the scan: the grass is short there (the ways are worn and the flora
## keeps off them), and it is where the wanderer looks; a hare in the heather past 12 m is not seen at all. The verge
## points are laid along the region's ways (a point every 6 m, either side), not sorted out of the lattice.
static func _verge_first(reg: Dictionary, scan: Array, rng: RandomNumberGenerator, lo: float, hi: float) -> Array:
	var bb := _bbox(reg).grow(4.0)
	var near: Array = []
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var w := float(path.w)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if not bb.intersects(Rect2(a, Vector2.ZERO).expand(b), true):
				continue
			var ab := b - a
			var ln := ab.length()
			if ln < 0.01:
				continue
			var side := Vector2(-ab.y, ab.x) / ln
			var m := maxi(1, int(ln / 6.0))
			for k in m:
				var c := a + ab * ((float(k) + rng.randf()) / float(m))
				var sg := 1.0 if rng.randf() < 0.5 else -1.0
				var q := c + side * sg * (w + rng.randf_range(lo, hi))
				if bb.has_point(q):
					near.append(q)
	LifePlace.shuffle(near, rng)
	return near + scan


static func _slope_ok(q: Vector2, r := 2.5, dh := 0.9) -> bool:
	var h := RL.height_at(q.x, q.y)
	for k in 4:
		var a := float(k) * PI * 0.5
		if absf(RL.height_at(q.x + cos(a) * r, q.y + sin(a) * r) - h) > dh:
			return false
	return true


static func _note(dir: Node3D, kind: String, n: int) -> void:
	var counts: Dictionary = dir.get("counts")
	counts[kind] = int(counts.get(kind, 0)) + n


# --- crows ------------------------------------------------------------------------------------------

## Ravens on the region's places: the tops of whatever stands within 16 m of each of its place slots (walls,
## barrows, cairns, the bell, roofs), else the crowns of its trees, else its stones; with ground perches round
## them (they strut and peck). A roost needs four perches.
static func _crows(dir: Node3D, root: Node, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int) -> int:
	var rid := String(reg.id)
	var centres: Array[Vector2] = []
	for sl: Dictionary in RealmLayout.SLOTS.get(rid, []):
		if String(sl.kind).begins_with("poi"):
			centres.append(sl.at as Vector2)
	# then beside its ways (what stands by a road: a wall, a cart, a cairn, the trees at its edge), where they are seen
	var roadside := _along_ways(reg, rng, 45.0, 6.0, 12.0)
	LifePlace.shuffle(roadside, rng)
	centres.append_array(roadside.slice(0, 12))
	var made := 0
	var placed: Array[Vector2] = []
	# 30 m off the camps; a small region full of them (the Bellfall: two by its crater) tries again at 16 m rather
	# than staying empty (crows are bolder than that)
	for camp_r: float in [30.0, 16.0]:
		if made > 0:
			break
		for c in centres:
			if made >= n:
				break
			if not _in(reg, c) or not _clear(c, camp_r, 10.0) or _taken(dir, c, "crow", 40.0):
				continue
			var far := true
			for o in placed:
				if o.distance_to(c) < 36.0:
					far = false
			if not far:
				continue
			var perches := _crow_perches(space, c, rng)
			if perches.size() < 4:
				continue
			var g := Birds.new()
			g.name = "CrowsR_%s_%d" % [rid, made]
			g.setup("crow", perches, clampi(perches.size() - 1, 3, 5), SEED + 101 * made + absi(hash(rid)) % 997)
			add.call(g)
			placed.append(c)
			made += 1
	return made


## The flora's trees within ~24 m of c (an index of 24 m cells, made once a build).
static func _trees_near(c: Vector2) -> Array:
	if _tree_cells.is_empty():
		for tr: Array in Flora.trees:
			var b: Vector3 = tr[0]
			var k := Vector2i(floori(b.x / 24.0), floori(b.z / 24.0))
			if not _tree_cells.has(k):
				_tree_cells[k] = []
			(_tree_cells[k] as Array).append(tr)
		_tree_cells[Vector2i(1 << 20, 0)] = []          # (built, even for a Realm without trees)
	var out: Array = []
	var k0 := Vector2i(floori(c.x / 24.0), floori(c.y / 24.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			out.append_array(_tree_cells.get(k0 + Vector2i(dx, dz), []))
	return out


static func _crow_perches(space: PhysicsDirectSpaceState3D, c: Vector2, rng: RandomNumberGenerator) -> Array:
	var gy := LifePlace.ground(space, c.x, c.y)
	var tops: Array = []
	for i in 70:
		var a := rng.randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 16.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, gy + 24.0, q.y), Vector3(q.x, gy - 4.0, q.y), 1))
		if hit.is_empty():
			continue
		var hp: Vector3 = hit.position
		var col := hit.collider as Node
		var g2 := RL.height_at(q.x, q.y)
		if col != null and not String(col.name).begins_with("Terrain") and hit.normal.y > 0.55 and hp.y > g2 + 0.5 and hp.y < g2 + 18.0:
			if not String(col.name).begins_with("FloraBody") and not col.is_in_group(Groups.ENEMY):
				tops.append([hp, rng.randf_range(-PI, PI)])
	# the crowns of the trees round it
	if tops.size() < 3:
		for tr: Array in _trees_near(c):
			var b: Vector3 = tr[0]
			if Vector2(b.x, b.z).distance_to(c) > 18.0:
				continue
			var id := String(tr[1])
			var d: Dictionary = Flora.TreeGen.kind(id)
			var sc := float(tr[3]) / maxf(float(d.get("h", 1.0)), 0.01)
			var top := b + Vector3(0, Flora.mesh_aabb(id).end.y * sc * 0.92, 0)
			if top.y - b.y > 3.0:
				tops.append([top, rng.randf_range(-PI, PI)])
			if tops.size() >= 5:
				break
	LifePlace.shuffle(tops, rng)
	tops = tops.slice(0, 4)
	# and the ground between: open, dry, off the way
	var floor_ps: Array = []
	for i in 30:
		if floor_ps.size() >= 4:
			break
		var a2 := rng.randf() * TAU
		var q2 := c + Vector2(cos(a2), sin(a2)) * rng.randf_range(1.5, 9.0)
		if RL.in_water(q2.x, q2.y) or RealmLayout.path_dist(q2) < 1.2 or not WorldLanes.site_at(q2, 0.6).is_empty():
			continue
		var y := LifePlace.ground(space, q2.x, q2.y)
		if absf(y - RL.height_at(q2.x, q2.y)) > 0.4:
			continue                                        # (on something, not the ground: the tops pass has it)
		floor_ps.append([Vector3(q2.x, y, q2.y), rng.randf_range(-PI, PI)])
	return tops + floor_ps


# --- owls -------------------------------------------------------------------------------------------

## Areas of three to six big trunks 14 m apart in the region (none within 45 m of an owl area already placed),
## one or two owls each, their branch stubs facing the nearest way, field mice in the open ground under them.
static func _owls(dir: Node3D, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, trunks_all: Array) -> int:
	var rid := String(reg.id)
	var mine: Array = []
	for t: Dictionary in trunks_all:
		var b: Vector3 = t.base
		var q := Vector2(b.x, b.z)
		if RealmLayout.path_dist(q) > 1.5 and _clear(q, 24.0, 6.0):
			mine.append(t)
	LifePlace.shuffle(mine, rng)
	var areas: Array = []
	for t: Dictionary in mine:
		var b: Vector3 = t.base
		var put := false
		for ar: Array in areas:
			if (ar[0] as Dictionary).base.distance_to(b) < 26.0:
				var spaced := true
				for o: Dictionary in ar:
					if (o.base as Vector3).distance_to(b) < 9.0:
						spaced = false
				if spaced and ar.size() < 6:
					ar.append(t)
				put = true
				break
		if not put:
			var far := true
			for ar2: Array in areas:
				if (ar2[0] as Dictionary).base.distance_to(b) < 45.0:
					far = false
			if far and not _taken(dir, Vector2(b.x, b.z), "owl", 45.0):
				areas.append([t])
	var made := 0
	for ar: Array in areas:
		if made >= n or ar.size() < 3:
			continue
		var perches: Array = []
		var xfs: Array = []
		for t: Dictionary in ar:
			var b: Vector3 = t.base
			var r: float = t.r
			var dir2 := _toward_path(Vector2(b.x, b.z), rng)
			var h := rng.randf_range(2.9, 3.8)
			var xf := Transform3D(Basis(Vector3.UP, atan2(-dir2.y, dir2.x)), b + Vector3(dir2.x, 0, dir2.y) * r * 0.7 + Vector3(0, h, 0))
			var perch := xf * Vector3(1.1, 0.13, 0.0)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(perch + Vector3(0, 0.6, 0), perch + Vector3(0, 0.02, 0), 1)).is_empty():
				continue
			xfs.append(xf)
			var side := Vector3(-dir2.y, 0, dir2.x)
			perches.append([perch, Birds.yaw_to(side if rng.randf() < 0.5 else -side)])
		if perches.size() < 3:
			continue
		var prey: Array[Vector3] = []
		for pe: Array in perches:
			var b2: Vector3 = pe[0]
			for k in 6:
				if prey.size() >= 5:
					break
				var a := rng.randf_range(0.0, TAU)
				var q := Vector2(b2.x, b2.z) + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 14.0)
				if LifePlace.open_ground(q.x, q.y) and RealmLayout.path_dist(q) > 2.0:
					prey.append(Vector3(q.x, RL.height_at(q.x, q.y), q.y))
					break
		var g := Birds.new()
		g.name = "OwlsR_%s_%d" % [rid, made]
		g.setup("owl", perches, 1 + int(perches.size() >= 5), SEED + 211 * made + absi(hash(rid)) % 991, xfs, prey)
		add.call(g)
		var tracks: Variant = dir.get("tracks")
		if tracks != null:
			for pe2: Array in perches:
				var b3: Vector3 = pe2[0]
				tracks.print_at(Vector3(b3.x + rng.randf_range(-0.8, 0.8), 0, b3.z + rng.randf_range(-0.8, 0.8)), rng.randf_range(-PI, PI), 4, INF)
		made += 1
	return made


static func _toward_path(p: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var ab: Vector2 = (pts[i + 1] as Vector2) - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var q := a + ab * t
			var d := p.distance_to(q)
			if d < bd and d > 0.01:
				bd = d
				best = (q - p) / d
	if bd > 60.0 or best == Vector2.INF:
		var ang := rng.randf_range(0.0, TAU)
		best = Vector2(cos(ang), sin(ang))
	return best


# --- water --------------------------------------------------------------------------------------

static func _pools_in(reg: Dictionary, pools: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in pools:
		if int(p.n) >= 3 and _in(reg, p.center as Vector2):
			out.append(p)
	return out


## Herons on the banks of the region's bigger pools, two to four perches each, facing the water.
static func _herons(dir: Node3D, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, pools: Array[Dictionary]) -> int:
	var made := 0
	for p: Dictionary in _pools_in(reg, pools):
		if made >= n:
			break
		var pc: Vector2 = p.center
		if _taken(dir, pc, "heron", 30.0) or not _clear(pc, 26.0, 8.0):
			continue
		var edge: Array = (p.edge as Array).duplicate()
		if edge.size() < 4:
			continue
		LifePlace.shuffle(edge, rng)
		var perches: Array = []
		for e: Vector2 in edge:
			if perches.size() >= 4:
				break
			var gy := LifePlace.ground(space, e.x, e.y)
			if gy > RL.water_y_at(e.x, e.y) + 0.9 or RealmLayout.path_dist(e) < 1.5:
				continue
			var spaced := true
			for o: Array in perches:
				if (o[0] as Vector3).distance_to(Vector3(e.x, gy, e.y)) < 5.0:
					spaced = false
			if not spaced:
				continue
			var w := LifePlace.nearest_water(p, e)
			perches.append([Vector3(e.x, gy, e.y), Birds.yaw_to(Vector3(w.x - e.x, 0, w.y - e.y))])
		if perches.size() < 2:
			continue
		var g := Birds.new()
		g.name = "HeronsR_%s_%d" % [String(reg.id), made]
		g.setup("heron", perches, 1 + int(perches.size() >= 4), SEED + 307 * made + absi(hash(String(reg.id))) % 983)
		add.call(g)
		made += 1
	return made


## A frog chorus at the region's pools that have none yet (the director keeps six for all the new ground).
static func _ponds(dir: Node3D, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, pools: Array[Dictionary]) -> int:
	var made := 0
	for p: Dictionary in _pools_in(reg, pools):
		if made >= n:
			break
		var pc: Vector2 = p.center
		if _taken(dir, pc, "pond", 24.0) or not _clear(pc, 26.0, 6.0):
			continue
		var edge: Array = (p.edge as Array).duplicate()
		LifePlace.shuffle(edge, rng)
		var spots: Array[Vector3] = []
		for e: Vector2 in edge:
			if spots.size() >= clampi(int(p.n) / 4 + 3, 3, 7):
				break
			var ok := true
			for s in spots:
				if Vector2(s.x, s.z).distance_to(e) < 1.3:
					ok = false
			var gy := LifePlace.ground(space, e.x, e.y)
			var wy := RL.water_y_at(e.x, e.y)
			if ok and gy <= wy + 1.2 and gy >= wy - 0.05:
				spots.append(Vector3(e.x, gy, e.y))
		if spots.size() < 3:
			continue
		var g := Pond.new()
		g.name = "PondR_%s_%d" % [String(reg.id), made]
		g.setup(p, spots, SEED + 31 * made + absi(hash(String(reg.id))) % 977)
		add.call(g)
		_note(dir, "frog", spots.size())
		made += 1
	return made


# --- the ground's beasts --------------------------------------------------------------------------

## Hare forms: two or three hares within 8 m on open, gentle ground well off the camps.
static func _hares(dir: Node3D, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, scan: Array) -> int:
	var made := 0
	var placed: Array[Vector2] = []
	for q0: Vector2 in _verge_first(reg, scan, rng, 2.2, 7.0).slice(0, SEARCH):
		if made >= n:
			break
		var e := _cand(reg, q0)
		if e.is_empty():
			continue
		var c: Vector2 = e[0]
		if float(e[1]) > 0.12 or not _clear(c, 30.0) or _taken(dir, c, "hare", 30.0) or not _slope_ok(c):
			continue
		var spaced := true
		for o in placed:
			if o.distance_to(c) < 34.0:
				spaced = false
		if not spaced:
			continue
		var spots: Array[Vector3] = []
		for k in 30:
			if spots.size() >= 2 + (made % 2):
				break
			var q := c + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-6.0, 6.0))
			if not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 2.0 or not _in(reg, q):
				continue
			var near := false
			for s0 in spots:
				if Vector2(s0.x, s0.z).distance_to(q) < 1.5:
					near = true
			if not near:
				spots.append(Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y))
		if spots.size() < 2:
			continue
		var g := Beasts.new()
		g.name = "HareR_%s_%d" % [String(reg.id), made]
		g.setup("hare", spots, SEED + 517 * made + absi(hash(String(reg.id))) % 971)
		add.call(g)
		placed.append(c)
		made += 1
	return made


## Foxes alone, at the edge of cover (a hedge, a wood's margin), 40 m off the camps so one can hunt.
static func _foxes(dir: Node3D, space: PhysicsDirectSpaceState3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, scan: Array) -> int:
	var made := 0
	for pass_i in 2:
		for q0: Vector2 in _verge_first(reg, scan, rng, 2.5, 9.0).slice(0, SEARCH):
			if made >= n:
				break
			var e := _cand(reg, q0)
			if e.is_empty():
				continue
			var c: Vector2 = e[0]
			if pass_i == 0 and (float(e[1]) > 0.1 or Flora.cover_at(c.x + 8.0, c.y) + Flora.cover_at(c.x - 8.0, c.y) + Flora.cover_at(c.x, c.y + 8.0) + Flora.cover_at(c.x, c.y - 8.0) < 0.5):
				continue                              # (the first pass wants an edge; the second takes any open ground)
			if not _clear(c, 40.0) or _taken(dir, c, "fox", 40.0) or not _slope_ok(c):
				continue
			var spots: Array[Vector3] = [Vector3(c.x, LifePlace.ground(space, c.x, c.y), c.y)]
			var g := Beasts.new()
			g.name = "FoxR_%s_%d" % [String(reg.id), made]
			g.setup("fox", spots, SEED + 401 * made + absi(hash(String(reg.id))) % 967)
			add.call(g)
			made += 1
	return made


## Lapwings on wide open ground (a 3 m apron round the spot open too), 40 m from any other flock.
static func _flocks(dir: Node3D, add: Callable, reg: Dictionary, rng: RandomNumberGenerator, n: int, scan: Array) -> int:
	var made := 0
	for q0: Vector2 in _verge_first(reg, scan, rng, 3.5, 9.0).slice(0, SEARCH):
		if made >= n:
			break
		var e := _cand(reg, q0)
		if e.is_empty():
			continue
		var c: Vector2 = e[0]
		if float(e[1]) > 0.06 or String(e[2]) == "oldforest" or RealmLayout.path_dist(c) < 3.5 or not _clear(c, 28.0) or _taken(dir, c, "plover", 40.0) or not _slope_ok(c, 4.0, 1.0):
			continue
		var ok := true
		for dx: float in [-3.0, 3.0]:
			for dz: float in [-3.0, 3.0]:
				if not LifePlace.open_ground(c.x + dx, c.y + dz):
					ok = false
		if not ok:
			continue
		var g := Flock.new()
		g.name = "LapwingsR_%s_%d" % [String(reg.id), made]
		g.setup(Vector3(c.x, RL.height_at(c.x, c.y), c.y), rng.randi_range(9, 14), SEED + 503 * made + absi(hash(String(reg.id))) % 961)
		add.call(g)
		made += 1
	return made


# --- shader flocks ----------------------------------------------------------------------------------

## Fireflies over the region's wet and grassy edges: near water first, then the margins of its woods.
static func _fireflies(dir: Node3D, reg: Dictionary, rng: RandomNumberGenerator, n: int, scan: Array) -> int:
	# near water first, then the margins of its woods, then any open ground (tested lazily, the first 120 points)
	var wet: Array[Vector2] = []
	var edge: Array[Vector2] = []
	var other: Array[Vector2] = []
	for q0: Vector2 in scan.slice(0, SEARCH):
		var e := _cand(reg, q0)
		if e.is_empty():
			continue
		var c: Vector2 = e[0]
		if RL.in_water(c.x + 6.0, c.y) or RL.in_water(c.x - 6.0, c.y) or RL.in_water(c.x, c.y + 6.0) or RL.in_water(c.x, c.y - 6.0):
			wet.append(c)
		elif float(e[1]) < 0.2 and Flora.cover_at(c.x + 7.0, c.y) + Flora.cover_at(c.x - 7.0, c.y) > 0.5:
			edge.append(c)
		else:
			other.append(c)
	var want: Array[Vector2] = wet + edge + other
	var made := 0
	var placed: Array[Vector2] = []
	var flies: Array = dir.get("fireflies")
	for c in want:
		if made >= n:
			break
		if not _clear(c, 20.0, 6.0):
			continue
		var spaced := true
		for o in placed:
			if o.distance_to(c) < 24.0:
				spaced = false
		for f: Node in flies:
			var fp := (f as Node3D).global_position
			if Vector2(fp.x, fp.z).distance_to(c) < 20.0:
				spaced = false
		if not spaced:
			continue
		var cnt := 12 + (made % 3) * 4
		var mmi := LifeKit.group("firefly", cnt)
		mmi.name = "FirefliesR"
		for k in cnt:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))))
			mmi.multimesh.set_instance_custom_data(k, Color(rng.randf_range(2.0, 4.5), rng.randf_range(0.12, 0.3), rng.randf_range(0.5, 1.7), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-7, -0.5, -7), Vector3(14, 4, 14))
		mmi.visibility_range_end = 55.0
		mmi.visibility_range_end_margin = 6.0
		dir.add_child(mmi)
		mmi.global_position = Vector3(c.x, RL.height_at(c.x, c.y), c.y)
		flies.append(mmi)
		_note(dir, "firefly", cnt)
		placed.append(c)
		made += 1
	return made


## Bats hawking over the region's ways where they run by a wood (a wood's edge each side within 9 m): seen against the
## sky from the road, a few at a time, on a shader's loop (no script time).
static func _road_bats(dir: Node3D, reg: Dictionary, rng: RandomNumberGenerator, n: int) -> int:
	var made := 0
	var swarms: Array = dir.get("bats")
	var placed: Array[Vector2] = []
	var cands := _along_ways(reg, rng, 24.0, -1.0, 1.0)
	LifePlace.shuffle(cands, rng)
	for c in cands:
		if made >= n:
			break
		if not _in(reg, c) or Flora.cover_at(c.x, c.y) > 0.5:
			continue
		var wood := maxf(Flora.cover_at(c.x + 9.0, c.y), Flora.cover_at(c.x - 9.0, c.y)) + maxf(Flora.cover_at(c.x, c.y + 9.0), Flora.cover_at(c.x, c.y - 9.0))
		if wood < 0.5:
			continue
		var spaced := true
		for o in placed:
			if o.distance_to(c) < 60.0:
				spaced = false
		for sw: Node in swarms:
			var sp3 := (sw as Node3D).global_position
			if Vector2(sp3.x, sp3.z).distance_to(c) < 40.0:
				spaced = false
		if not spaced:
			continue
		var r := rng.randf_range(5.0, 8.0)
		var cnt := rng.randi_range(3, 5)
		var mmi := LifeKit.group("bat", cnt)
		mmi.name = "BatsRoad"
		for k in cnt:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-3, 3), rng.randf_range(-1.0, 1.5), rng.randf_range(-3, 3))))
			var sp := rng.randf_range(0.5, 0.95) * (1.0 if rng.randf() < 0.6 else -1.0)
			mmi.multimesh.set_instance_custom_data(k, Color(r * rng.randf_range(0.5, 1.0), sp, rng.randf_range(0.8, 2.2), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-r * 1.5 - 4, -5, -r * 1.5 - 4), Vector3(r * 3 + 8, 10, r * 3 + 8))
		mmi.visibility_range_end = 80.0
		mmi.visibility_range_end_margin = 10.0
		dir.add_child(mmi)
		mmi.global_position = Vector3(c.x, RL.height_at(c.x, c.y) + rng.randf_range(4.5, 6.5), c.y)
		swarms.append(mmi)
		_note(dir, "bat", cnt)
		placed.append(c)
		made += 1
	return made


## Bats over the region's places (its place slots, a little over the tallest thing there) and, failing those, its
## crater or its highest ground.
static func _bats(dir: Node3D, space: PhysicsDirectSpaceState3D, reg: Dictionary, rng: RandomNumberGenerator, n: int) -> int:
	var rid := String(reg.id)
	var centres: Array[Vector2] = []
	for sl: Dictionary in RealmLayout.SLOTS.get(rid, []):
		if String(sl.kind).begins_with("poi"):
			centres.append(sl.at as Vector2)
	if rid == "bellfall":
		centres.push_front(RealmReaches.CRATER_C)
	var bb := _bbox(reg)
	centres.append(bb.get_center())
	var made := 0
	var swarms: Array = dir.get("bats")
	var placed: Array[Vector2] = []
	for c in centres:
		if made >= n:
			break
		var spaced := true
		for o in placed:
			if o.distance_to(c) < 30.0:
				spaced = false
		for sw: Node in swarms:
			var sp3 := (sw as Node3D).global_position
			if Vector2(sp3.x, sp3.z).distance_to(c) < 30.0:
				spaced = false
		if not spaced:
			continue
		var gy := RL.height_at(c.x, c.y)
		var top := gy
		for k in 9:
			var q := c + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, gy + 40.0, q.y), Vector3(q.x, gy - 4.0, q.y), 1))
			if not hit.is_empty():
				top = maxf(top, (hit.position as Vector3).y)
		var r := rng.randf_range(7.0, 11.0)
		var cnt := rng.randi_range(5, 8)
		var mmi := LifeKit.group("bat", cnt)
		mmi.name = "BatsR"
		for k in cnt:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2, 2), rng.randf_range(-1.5, 1.5), rng.randf_range(-2, 2))))
			var sp := rng.randf_range(0.45, 0.9) * (1.0 if rng.randf() < 0.6 else -1.0)
			mmi.multimesh.set_instance_custom_data(k, Color(r * rng.randf_range(0.45, 1.0), sp, rng.randf_range(1.0, 3.0), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-r * 1.5 - 3, -6, -r * 1.5 - 3), Vector3(r * 3 + 6, 12, r * 3 + 6))
		mmi.visibility_range_end = 90.0
		mmi.visibility_range_end_margin = 10.0
		dir.add_child(mmi)
		mmi.global_position = Vector3(c.x, maxf(top, gy + 4.0) + rng.randf_range(4.0, 7.0), c.y)
		swarms.append(mmi)
		_note(dir, "bat", cnt)
		placed.append(c)
		made += 1
	if made == 0:
		# every spot already had a swarm over it (the Bellfall's crater has the Realm's own): those are the region's bats
		for sw: Node in swarms:
			var p3 := (sw as Node3D).global_position
			if bb.has_point(Vector2(p3.x, p3.z)):
				made += 1
	return mini(made, n)

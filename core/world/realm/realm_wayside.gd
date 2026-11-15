extends RefCounted
## The wayside (docs/far_reaches.md, density): small things left in the wild all over the Realm, old ground and
## new, between the named places. A broken run of field wall, a fallen boundary marker by a lone grave, a cart
## left on its side with its load spilled, a cairn, a leaning waystone, a roofless wayside shrine, a stone sunk in
## a mere, a pier of some wall nobody remembers. Chosen by the ground's biome, one at most per CELL square
## (seeded per cell, so the world is the same every night), kept off the ways, the sites, the water, the raid
## floors, the towns, the camps and the fires, and only on open, level ground with nothing standing there.
## Meshes are the props kits' (art/models/props, PropModels), committed per CHUNK square as one mesh per
## material set with LODs and a fade by distance. Walls, carts and shrines get a box to walk round.
## Built by realm_pois.gd (REACH_POIS) after the flora. --no-wayside skips it.

const PropModels := preload("res://core/world/realm/prop_models.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

const CELL := 44.0
const CHUNK := 132.0
const VIEW_END := 150.0
const SEED := 20261115
## Regions nothing is scattered in: the towns and their yards, the boss floors' regions, the dungeon's quarry.
const KEEP_REGIONS := ["hearth", "weirford", "saltmarket", "lastlight", "fallow", "summit", "rift", "ossuary", "henge", "crags"]
## What each biome leaves lying about, and how likely a cell holds one.
const BIOME_P := {"meadow": 0.6, "heath": 0.7, "ruin": 0.8, "oldforest": 0.45, "glade": 0.3, "fen": 0.45, "crag": 0.4, "ash": 0.35, "salt": 0.3}
const THEMES := {
	"meadow": ["wall", "wall", "marker", "cart", "waystone", "cairn", "shrine"],
	"heath": ["cairn", "cairn", "waystone", "wall", "marker", "stele"],
	"ruin": ["wall", "pier", "marker", "shrine", "stele", "wall"],
	"oldforest": ["shrine", "pier", "stele", "cairn", "marker"],
	"glade": ["stele", "cairn"],
	"fen": ["drowned", "marker", "drowned", "cart"],
	"crag": ["cairn", "pier", "cairn"],
	"ash": ["cairn", "cart", "pier"],
	"salt": ["cart", "cairn", "marker"],
}
## kind -> [[file, offset xz, yaw offset, scale, tilt (deg)], ...], footprint radius, solid
const KINDS := {
	"wall": {"parts": [["wall_low.glb", Vector2(0, 0), 0.0, 1.0, 0.0], ["wall_low.glb", Vector2(3.1, 0.4), 0.12, 0.9, 4.0], ["wall_low.glb", Vector2(-2.9, -0.5), -0.2, 0.75, 9.0]], "r": 5.0, "solid": true},
	"marker": {"parts": [["ruin_marker.glb", Vector2(0, 0), 0.0, 1.0, 7.0], ["lore_headstone_broken.glb", Vector2(1.8, 1.2), 0.5, 1.0, 5.0]], "r": 2.8, "solid": false},
	"cart": {"parts": [["handcart.glb", Vector2(0, 0), 0.0, 1.0, 0.0], ["barrel_tipped.glb", Vector2(1.6, 0.9), 1.1, 1.0, 0.0], ["sack.glb", Vector2(-1.2, 1.0), 0.4, 1.0, 0.0], ["crate_broken.glb", Vector2(0.9, -1.4), 2.0, 1.0, 0.0]], "r": 3.4, "solid": true},
	"cairn": {"parts": [["lore_cairn_stack.glb", Vector2(0, 0), 0.0, 1.2, 0.0]], "r": 1.8, "solid": false},
	"waystone": {"parts": [["lore_waystone.glb", Vector2(0, 0), 0.0, 1.0, 11.0]], "r": 1.6, "solid": false},
	"shrine": {"parts": [["ruin_shrine.glb", Vector2(0, 0), 0.0, 1.0, 0.0]], "r": 4.2, "solid": true},
	"stele": {"parts": [["lore_stele.glb", Vector2(0, 0), 0.0, 1.0, 6.0], ["lore_tablet_leaning.glb", Vector2(-1.6, 0.8), 0.7, 1.0, 0.0]], "r": 2.4, "solid": false},
	"drowned": {"parts": [["ruin_drowned.glb", Vector2(0, 0), 0.0, 1.0, 0.0]], "r": 3.6, "solid": true},
	"pier": {"parts": [["wall_pier.glb", Vector2(0, 0), 0.0, 1.0, 5.0], ["wall_low.glb", Vector2(2.4, 0.2), 0.1, 0.7, 12.0]], "r": 3.6, "solid": true},
}

static var placed: Array[Dictionary] = []      ## last build: {kind, at (Vector3), yaw} (tests, stills)


static func reserve(_root: Node) -> void:
	pass


static func build(holder: Node) -> void:
	placed.clear()
	if "--no-wayside" in OS.get_cmdline_user_args():
		return
	var t0 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "Wayside"
	host.set_meta("site", "realm_wayside")
	holder.add_child(host)
	var space := (host as Node3D).get_world_3d().direct_space_state
	var keep: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		keep.append(Vector2((c.at as Vector3).x, (c.at as Vector3).z))
	for rid: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			keep.append(sl.at)
	var chunks := {}                                 # Vector2i -> PropModels
	var body := StaticBody3D.new()
	body.name = "WaysideBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	host.add_child(body)
	var b := RealmLayout.BOUNDS.grow(-10.0)
	var nx := int(b.size.x / CELL)
	var nz := int(b.size.y / CELL)
	for j in nz:
		for i in nx:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i * 7919 + j * 104729
			var c := b.position + Vector2((i + rng.randf_range(0.2, 0.8)) * CELL, (j + rng.randf_range(0.2, 0.8)) * CELL)
			var biome := RealmLayout.biome_at(c.x, c.y)
			if rng.randf() > float(BIOME_P.get(biome, 0.0)):
				continue
			var themes: Array = THEMES.get(biome, [])
			if themes.is_empty():
				continue
			var kind := String(themes[rng.randi() % themes.size()])
			var d: Dictionary = KINDS[kind]
			var r: float = d.r
			for attempt in 12:
				var q := c + Vector2(rng.randf_range(-CELL * 0.3, CELL * 0.3), rng.randf_range(-CELL * 0.3, CELL * 0.3))
				var y := _fits(space, q, r, kind == "drowned", keep, 0.92 if biome in ["oldforest", "glade"] else 0.55)
				if is_nan(y):
					continue
				var yaw := rng.randf_range(-PI, PI)
				var p := RealmLayout.path_dist(q)
				if kind in ["wall", "cart", "waystone"] and p < 18.0:
					yaw = _along_way(q)          # walls and carts lie along the way they belonged to
				var ck := Vector2i(floori(q.x / CHUNK), floori(q.y / CHUNK))
				if not chunks.has(ck):
					chunks[ck] = PropModels.new()
				_put(chunks[ck] as PropModels, body, space, d, q, y, yaw, rng)
				placed.append({"kind": kind, "at": Vector3(q.x, y, q.y), "yaw": yaw})
				break
	for ck: Vector2i in chunks:
		var node := Node3D.new()
		node.name = "Wayside_%d_%d" % [ck.x, ck.y]
		host.add_child(node)
		for mi in (chunks[ck] as PropModels).commit(node, "Ruins", true, true):
			mi.visibility_range_end = VIEW_END
			mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	print("REALM_WAYSIDE %d pieces in %d chunks (%d ms)" % [placed.size(), chunks.size(), Time.get_ticks_msec() - t0])
	if "--wayside-list" in OS.get_cmdline_user_args():
		for pc: Dictionary in placed:
			print("WAYSIDE %s %s" % [pc.kind, pc.at])


## The ground height to stand a piece of radius r at q, or NAN: open, level, dry (or wet for a drowned one), off
## the ways, sites, raid floors, towns, camps, fires and slots, with no tree, rock or building in the way.
static func _fits(space: PhysicsDirectSpaceState3D, q: Vector2, r: float, wet: bool, keep: Array[Vector2], max_cover: float) -> float:
	if String(RealmLayout.region_at(q.x, q.y).get("id", "")) in KEEP_REGIONS:
		return NAN
	if RealmLayout.path_dist(q) < r + 1.0 or not WorldLanes.site_at(q, r + 1.5).is_empty():
		return NAN
	for rd: Dictionary in RealmLayout.RAIDS:
		if q.distance_to(rd.c) < float(rd.r) + float(rd.fall) + r:
			return NAN
	for k in keep:
		if k.distance_to(q) < 11.0 + r:
			return NAN
	if Flora.cover_at(q.x, q.y) > max_cover:
		return NAN
	var lo := INF
	var hi := -INF
	for k in 7:
		var a := TAU * float(k) / 6.0
		var o := Vector2.ZERO if k == 6 else Vector2(cos(a), sin(a)) * r
		var g := RealmLayout.ground(space, q.x + o.x, q.y + o.y)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	if hi - lo > 0.35 * r + 0.3:
		return NAN
	var water := Land.in_water(q.x, q.y) or not is_nan(RealmLayout.water_level_at(q.x, q.y))
	if water != wet:
		return NAN
	var sq := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r * 1.6, 2.0, r * 1.6)
	sq.shape = bs
	sq.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, hi + 1.3, q.y))
	sq.collision_mask = Layers.WORLD | Layers.PROPS
	for hit: Dictionary in space.intersect_shape(sq, 4):
		if not String((hit.collider as Node).name).begins_with("Terrain"):
			return NAN
	return lo + 0.04


static func _along_way(q: Vector2) -> float:
	var best := INF
	var dir := Vector2.RIGHT
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var ab: Vector2 = (pts[i + 1] as Vector2) - a
			var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var dd := q.distance_to(a + ab * t)
			if dd < best:
				best = dd
				dir = ab.normalized()
	return atan2(dir.x, dir.y) + PI * 0.5


static func _put(pm: PropModels, body: StaticBody3D, space: PhysicsDirectSpaceState3D, d: Dictionary, q: Vector2, y: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for part: Array in d.parts:
		var off: Vector2 = part[1]
		var o3 := rot * Vector3(off.x, 0.0, off.y)
		var at := Vector2(q.x + o3.x, q.y + o3.z)
		var gy := RealmLayout.ground(space, at.x, at.y)
		var tilt := deg_to_rad(float(part[4])) * rng.randf_range(-1.0, 1.0)
		var b := Basis(Vector3.UP, yaw + float(part[2])) * Basis(Vector3.RIGHT, tilt)
		var s: float = float(part[3]) * rng.randf_range(0.92, 1.08)
		pm.add(String(part[0]), Transform3D(b.scaled(Vector3.ONE * s), Vector3(at.x, minf(gy, y + 0.3) - 0.06, at.y)))
		if bool(d.solid):
			var sz := PropModels.size_of(String(part[0])) * s
			if sz.y > 0.6 and maxf(sz.x, sz.z) > 0.7:
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(maxf(sz.x * 0.85, 0.3), sz.y * 0.9, maxf(sz.z * 0.85, 0.3))
				cs.shape = bx
				body.add_child(cs)
				cs.global_transform = Transform3D(Basis(Vector3.UP, yaw + float(part[2])), Vector3(at.x, gy + sz.y * 0.45, at.y))

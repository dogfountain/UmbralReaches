extends RefCounted
## FLORA module of the Realm (docs/REALM_PLAN.md): trees, undergrowth and ground cover over the whole map, by biome.
## Runs after land, rift, bosses, tavern, lore and TerrainStamp.apply, so every site, flight, portal and arena is
## registered and the ground is final. Layered dressing and the wayside's plan: flora_layers.gd (docs/world_density.md).
##   1 sample the ground on a 1 m grid (one ray per cell: height, slope, and whether the first
##     thing hit is the terrain at all, so nothing grows inside a building, rock or bridge)
##   2 keep-out field: distance to the nearest path edge (RealmLayout.PATHS + runtime lanes) and to
##     the nearest site / flight / portal / boss arena / the spawn clearing / the Crossing
##   3 trees: jittered candidates, chance by biome (blended region weights) x clumping noise,
##     minimum spacing per species; trunks seated on the lowest ground under their root flare
##   4 undergrowth on a 2 m grid: densities by biome, canopy cover and noise
##   5 one MultiMesh per (kind, 24 m chunk), whole buffers written once (Metal reads them back
##     stale); solid meshes get LODs (MeshChunks.with_lods), card meshes never do and use
##     visibility ranges instead; trunks over 4 m and logs collide (one StaticBody per chunk)
## Meshes come from tree_gen.gd. Results for tests: `placed` (kind -> count) and `trees`.

const Footing := preload("res://core/world/footing.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const MarchesLooks := preload("res://core/world/realm/flora_looks_marches.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")
const OldUnder := preload("res://core/world/realm/flora_old_undergrowth.gd")
const Emit := preload("res://core/world/realm/flora_emit.gd")
const Cache := preload("res://core/world/realm/flora_cache.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const Scorch := preload("res://core/world/realm/rift/scorch.gd")     ## the rift's burned ground (dying ring, snags, bare ash)

const CHUNK := Emit.CHUNK              ## undergrowth chunks
const TREE_CHUNK := Emit.TREE_CHUNK    ## tree chunks
const CELL := 1.0                      ## ground sample grid
const UCELL := 2.0                     ## undergrowth grid
const MARGIN := 18.0                   ## trees also grow this far outside BOUNDS (the horizon)
const WATER_Y := -0.9                  ## fen pools (RealmLand)
const SPAWN_CLEAR := 10.0
const OUTPOST_CAST := "res://core/life/village/village_cast.gd"
const OUTPOST_CLEAR := 7.5             ## bare round each outpost candidate (a camp reaches ~5 m from its fire)

## tree species: chance per candidate (3.5 m jittered grid) by biome, min spacing (m)
const TREE_P := {
	"oak": {"oldforest": 0.8, "meadow": 0.03, "ruin": 0.07, "glade": 0.05, "heath": 0.012},
	"birch": {"oldforest": 0.09, "meadow": 0.03, "glade": 0.16, "heath": 0.025, "ruin": 0.05, "fen": 0.01},
	"pine": {"oldforest": 0.08, "crag": 0.14, "heath": 0.012, "ash": 0.004},
	"willow": {"fen": 0.2},
	"snag": {"fen": 0.09, "oldforest": 0.035, "ash": 0.02, "ruin": 0.035, "crag": 0.015, "heath": 0.006, "salt": 0.004},
	"sapling": {"oldforest": 0.3, "glade": 0.08, "meadow": 0.012, "fen": 0.04, "ruin": 0.06, "heath": 0.015, "crag": 0.04},
	"windtree": {}, "yew": {},                     # r34: only where a LOOK adds them
}
const TREE_SPACING := {"oak": 6.2, "birch": 3.2, "pine": 3.6, "willow": 6.5, "snag": 3.0, "sapling": 1.6,
	"windtree": 4.5, "yew": 5.0, "fruit": 4.0, "cypress": 2.6}

const Tables := preload("res://core/world/realm/flora_tables.gd")
const UNDER := Tables.UNDER           ## undergrowth: instances per m2 by biome
const LOOKS := Tables.LOOKS           ## each new region's own look over its biome (flora_tables.gd)
const TINTED := ["grass", "tallgrass", "heather", "flowers", "fern", "shrub", "moss"]
const LOOK_EDGE := 8.0                 ## a look fades out this far outside its region
static var r30 := false                ## --no-r31-flora (A/B)
## Tree-free rounds [Vector2 centre, radius] other modules ask for before the flora runs (r31: the
## places' vistas, realm_pois.gd). Undergrowth still grows there; only trees keep out.
static var tree_clear: Array = []


static func _under_table(sp: String) -> Dictionary:
	return OldUnder.UNDER[sp] if r30 and OldUnder.UNDER.has(sp) else UNDER[sp]

const STYLE := Emit.STYLE         ## species groups: visibility range end, shadows, keep-off path distance, site clearance

static var placed := {}                ## species -> instance count (last build)
static var trees: Array = []           ## [Vector3 base, kind id, trunk r, height]
static var instances: Array = []       ## [kind id, Vector3 pos] of everything (tests)
static var build_ms := 0
static var gen_ms := 0                 ## of build_ms: making plant / rock meshes (cold GenCache only)
static var cached := false             ## the last build adopted the stored placement
static var last_fp := ""               ## its fingerprint (flora_cache.gd)
static var rejects := {}               ## why tree candidates were dropped (tuning)

# --- the field -----------------------------------------------------------------------------------
static var _x0 := 0.0
static var _z0 := 0.0
static var _nx := 0
static var _nz := 0
static var _gy := PackedFloat32Array()          # ground y
static var _gn := PackedFloat32Array()          # normal y
static var _gnx := PackedFloat32Array()         # normal x
static var _gnz := PackedFloat32Array()         # normal z
static var _ok := PackedByteArray()             # 1 = the terrain itself was hit
static var _pd := PackedFloat32Array()          # distance to the nearest path edge (capped)
static var _sd := PackedFloat32Array()          # distance to the nearest keep-out (capped)
static var _soft := PackedFloat32Array()        # 0..1: low plants allowed inside a keep-out (squares, pad margins)
static var _cover := PackedFloat32Array()       # canopy cover 0..1 (UCELL grid)
static var _bw: Array = []                      # biome weights per 4 m cell: Dictionary
static var _bnx := 0
static var _bnz := 0
static var _noise: Array[FastNoiseLite] = []


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var g0 := int(Realm.prof.get("gen: trees", 0)) + int(Realm.prof.get("gen: rockkit", 0))
	placed.clear()
	rejects.clear()
	r30 = "--no-r31-flora" in OS.get_cmdline_user_args()
	no_looks = "--no-r34-flora" in OS.get_cmdline_user_args()
	trees.clear()
	instances.clear()
	var old := root.get_node_or_null("RealmFlora")
	if old:
		old.free()
	await root.get_tree().physics_frame
	var space := (root as Node3D).get_world_3d().direct_space_state
	preload("res://core/world/realm/flora_layers.gd").plan(root, tree_clear)        # the wayside's places register their ground and clearings before the fingerprint
	_noises()
	var area := RealmLayout.BOUNDS.grow(MARGIN)
	_x0 = RealmLayout.OLD_BOUNDS.position.x - MARGIN - 4.0 * ceilf((RealmLayout.OLD_BOUNDS.position.x - area.position.x - MARGIN) / 4.0)   # the old Realm's lattice phase (cover, biome cells)
	_z0 = area.position.y
	_nx = int((area.end.x - _x0) / CELL) + 1
	_nz = int(area.size.y / CELL) + 1
	_lap("")
	_canopy.clear()
	var fp := Cache.fingerprint(root)
	var hit := Cache.load_hit(fp)
	_lap("cache load")
	var warm := not hit.is_empty() and Cache.verify(space, hit["sp"], _x0, _z0, _nx, _nz, CELL)
	last_fp = fp
	cached = warm
	_lap("cache verify")
	if warm:
		_adopt(hit)
	else:
		_scatter(root, space)
		Cache.save(fp, {"items": _final_items, "stones": _final_stones, "canopy": _canopy, "trees": trees, "placed": placed, "rejects": rejects,
			"gy": _gy, "cover": _cover, "sp": Cache.sparse(_gy, _gn, _ok, _nx, _nz)})
		_lap("cache save")
	var t4 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "RealmFlora"
	root.add_child(host)
	host.add_child((load("res://core/world/realm/flora_fight.gd") as GDScript).new())
	var stats := Emit.emit(host, _final_items, _final_stones, _canopy, Callable(ground_y), Callable(_prop_mesh))
	_lap("emit")
	build_ms = Time.get_ticks_msec() - t0
	gen_ms = (int(Realm.prof.get("gen: trees", 0)) + int(Realm.prof.get("gen: rockkit", 0)) - g0) / 1000
	print("FLORA %s: placement %d ms, nodes %d ms; %d multimeshes, %d colliders; mesh gen %d ms" % [
		"cached" if warm else "scattered", t4 - t0, Time.get_ticks_msec() - t4, stats.x, stats.y, gen_ms])
	var keys := placed.keys()
	keys.sort()
	var line := ""
	for k: String in keys:
		line += "%s %d  " % [k, placed[k]]
	print("FLORA laps ", laps)
	print("FLORA counts: ", line)
	print("FLORA tree rejects: ", rejects)
	if OS.get_cmdline_user_args().has("--flora-sites"):
		for st: Dictionary in WorldLanes.sites:
			print("FLORA site %-24s %s floor %.1f" % [st.name, st.rect, st.floor_y])
		for l: Array in WorldLanes.extra_lanes:
			print("FLORA lane ", l[0], " w ", l[2])


## The scatter proper: the ground, keep-outs, biomes, then trees, undergrowth and stones into
## _final_items / _final_stones (the cache stores exactly those).
static func _scatter(root: Node, space: PhysicsDirectSpaceState3D) -> void:
	_last_buf = null
	_sample(space)
	_lap("sample")
	_keepout(root)
	_lap("keepout")
	_find_tall_sites(space)
	_index_sites()
	_space = space
	_index_regions()
	_biomes()
	_lap("biomes")
	_looks()
	_lap("looks")
	var items := {}                     # kind id -> chunk key -> Buf
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	_place_trees(space, rng, items)
	_lap("trees")
	_place_under(rng, items)
	_lap("under")
	var srng := RandomNumberGenerator.new()
	srng.seed = 20261105
	var stone_items := _place_stones(srng)
	preload("res://core/world/realm/flora_layers.gd").decorate(items, load(Cache.SELF), stone_items)      # the layers; then the wayside's ground cleared
	_final_items = _finish(items, true)
	_final_stones = _finish(stone_items, false)
	_lap("stones")


static func _adopt(hit: Dictionary) -> void:
	_final_items = hit["items"]
	_final_stones = hit["stones"]
	_canopy = hit["canopy"]
	trees = hit["trees"]
	placed = hit["placed"]
	rejects = hit["rejects"]
	_gy = hit["gy"]
	_cover = hit["cover"]


static var _lap_at := 0
static var laps := {}                  ## build phase -> ms (last build)


static func _lap(what: String) -> void:
	var now := Time.get_ticks_usec()
	if what == "":
		laps.clear()
	else:
		laps[what] = int(laps.get(what, 0)) + (now - _lap_at) / 1000
	_lap_at = now


static func _noises() -> void:
	_noise.clear()
	for k in 6:
		var n := FastNoiseLite.new()
		n.seed = 77 + k * 31
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = [0.035, 0.06, 0.09, 0.02, 0.12, 0.05][k]
		n.fractal_octaves = 2
		_noise.append(n)


static func _idx(x: float, z: float) -> int:
	var i := clampi(int((x - _x0) / CELL), 0, _nx - 1)
	var j := clampi(int((z - _z0) / CELL), 0, _nz - 1)
	return j * _nx + i


## Bilinear ground height.
static func ground_y(x: float, z: float) -> float:
	var fx := clampf((x - _x0) / CELL, 0.0, _nx - 1.001)
	var fz := clampf((z - _z0) / CELL, 0.0, _nz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := _gy[j * _nx + i]
	var b := _gy[j * _nx + i + 1]
	var c := _gy[(j + 1) * _nx + i]
	var d := _gy[(j + 1) * _nx + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func _sample(space: PhysicsDirectSpaceState3D) -> void:
	var n := _nx * _nz
	_gy.resize(n)
	_gn.resize(n)
	_gnx.resize(n)
	_gnz.resize(n)
	_ok.resize(n)
	var q := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Layers.WORLD | Layers.PROPS)
	for j in _nz:
		var z := _z0 + j * CELL
		for i in _nx:
			var x := _x0 + i * CELL
			var k := j * _nx + i
			q.from = Vector3(x, 140.0, z)
			q.to = Vector3(x, -70.0, z)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				_gy[k] = RealmLayout.macro_height(x, z)
				_gn[k] = 1.0
				_gnx[k] = 0.0
				_gnz[k] = 0.0
				_ok[k] = 1
				continue
			var p: Vector3 = hit.position
			var nn: Vector3 = hit.normal
			_gy[k] = p.y
			_gn[k] = nn.y
			_gnx[k] = nn.x
			_gnz[k] = nn.z
			_ok[k] = 1 if String((hit.collider as Node).name).begins_with("Terrain") else 0


## Distance fields: paths (exact per segment, banded) and keep-outs (sites, flights, portals,
## arenas, spawn, tavern, the Crossing, lava).
static func _keepout(root: Node) -> void:
	var n := _nx * _nz
	_pd.resize(n)
	_pd.fill(99.0)
	_sd.resize(n)
	_sd.fill(99.0)
	const BAND := 14.0
	var paths: Array = []
	for p: Dictionary in RealmLayout.PATHS:
		paths.append([p.pts, float(p.w)])
	for l: Array in WorldLanes.extra_lanes:
		paths.append([l[1], float(l[2])])
	for pth: Array in paths:
		var pts: Array = pth[0]
		var w: float = pth[1]
		for s in pts.size() - 1:
			var a: Vector2 = pts[s]
			var b: Vector2 = pts[s + 1]
			_seg_field(_pd, a, b, w, BAND)
	for l: Array in Zones.lanes(): _seg_field(_pd, l[0], l[1], Zones.LANE_W, BAND)         # the squares' walk lanes stay bare
	# keep-outs
	# sites by their bounding rect, as WorldLanes.intrudes and zz/audit judge them (a round terrace
	# or a diagonal flight claims its whole box)
	# (r34: the raid floors by their circle -- their 60 m boxes emptied the hill round them; the
	# older round sites keep their box, so the wood elsewhere grows exactly as it did)
	for st: Dictionary in WorldLanes.sites:
		if st.has("circle") and String(st.name).begins_with("raid_"):
			var cc: Vector3 = st.circle
			_disc_field(_sd, Vector2(cc.x, cc.y), cc.z, BAND)
		elif not String(st.name).begins_with("wayside_"):         # (flora_layers.gd clears the wayside's ground after the scatter)
			_rect_field(_sd, st.rect, BAND)
	for p: Dictionary in WorldLanes.portals:
		var at: Vector3 = p.at
		var out: Vector3 = p.out
		_seg_field(_sd, Vector2(at.x, at.z) - Vector2(out.x, out.z), Vector2(at.x, at.z) + Vector2(out.x, out.z) * 3.5, float(p.w) * 0.5 + 0.6, BAND)
	for a in root.get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as Node3D
		_disc_field(_sd, Vector2(ar.global_position.x, ar.global_position.z), float(ar.get("radius")) + 2.0, BAND)
	_disc_field(_sd, Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z), SPAWN_CLEAR, BAND)
	_rect_field(_sd, Rect2(RealmLayout.TAVERN.position, Vector2(29.0 - RealmLayout.TAVERN.position.x, RealmLayout.TAVERN.size.y)).grow(1.0), BAND)
	var cf := RealmLayout.CROSSING_FOOT
	var ch := RealmLayout.CROSSING_HEAD
	_seg_field(_sd, Vector2(cf.x, cf.z), Vector2(ch.x, ch.z), 5.0, BAND)
	_disc_field(_sd, Vector2(RealmLayout.SUMMIT.x, RealmLayout.SUMMIT.z), 14.0, BAND)
	_disc_field(_sd, Vector2(RealmLayout.SUMMIT_DAIS.x, RealmLayout.SUMMIT_DAIS.z), 16.0, BAND)
	# the extended dais SummitDress registers after the wood (site "summit_dais": the square inside its 28 m disc, centred on
	# the holder's (0, -34.5) = world (0, -118), half = 0.7 * 28): reserved here so no stone is left inside it
	_rect_field(_sd, Rect2(-19.6, -137.6, 39.2, 39.2), BAND)
	_disc_field(_sd, Vector2(RealmLayout.OSSUARY_GATE.x, RealmLayout.OSSUARY_GATE.z), 5.0, BAND)
	# r34 flora: the outpost camps (village.gd _outposts, built after the flora) look for clear ground
	# round their candidate spots (village_cast.gd OUTPOSTS): keep those rounds bare, so the camp
	# settles on its first spot with no grass through its fire pit and seat
	if ResourceLoader.exists(OUTPOST_CAST):
		var cast := load(OUTPOST_CAST) as GDScript
		var outposts: Dictionary = cast.get_script_constant_map().get("OUTPOSTS", {}) if cast else {}
		for id: String in outposts:
			var nears: Variant = (outposts[id] as Dictionary).get("near", [])
			for nv: Variant in (nears if nears is Array else [nears]):
				_disc_field(_sd, nv as Vector2, OUTPOST_CLEAR, BAND)
	# lava and anything that is not the terrain itself
	for k in n:
		if _gy[k] < RealmLayout.LAVA_Y + 2.5 or _ok[k] == 0:
			_sd[k] = 0.0
	_soft = Zones.soft_field(_x0, _z0, _nx, _nz, CELL)         # where low plants may grow inside a keep-out
	for k in n:
		if _gy[k] < RealmLayout.LAVA_Y + 2.5 or _ok[k] == 0:
			_soft[k] = 0.0


static func _cells_in(r: Rect2) -> Rect2i:
	var i0 := clampi(int(floor((r.position.x - _x0) / CELL)), 0, _nx - 1)
	var j0 := clampi(int(floor((r.position.y - _z0) / CELL)), 0, _nz - 1)
	var i1 := clampi(int(ceil((r.end.x - _x0) / CELL)), 0, _nx - 1)
	var j1 := clampi(int(ceil((r.end.y - _z0) / CELL)), 0, _nz - 1)
	return Rect2i(i0, j0, i1 - i0, j1 - j0)


static func _seg_field(f: PackedFloat32Array, a: Vector2, b: Vector2, w: float, band: float) -> void:
	var r := _cells_in(Rect2(a.min(b), (b - a).abs()).grow(w + band))
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	for j in range(r.position.y, r.end.y + 1):
		for i in range(r.position.x, r.end.x + 1):
			var p := Vector2(_x0 + i * CELL, _z0 + j * CELL)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var d := maxf(p.distance_to(a + ab * t) - w, 0.0)
			var k := j * _nx + i
			if d < f[k]:
				f[k] = d


static func _disc_field(f: PackedFloat32Array, c: Vector2, rad: float, band: float) -> void:
	var r := _cells_in(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0).grow(band))
	for j in range(r.position.y, r.end.y + 1):
		for i in range(r.position.x, r.end.x + 1):
			var d := maxf(Vector2(_x0 + i * CELL, _z0 + j * CELL).distance_to(c) - rad, 0.0)
			var k := j * _nx + i
			if d < f[k]:
				f[k] = d


static func _rect_field(f: PackedFloat32Array, rect: Rect2, band: float) -> void:
	var r := _cells_in(rect.grow(band))
	for j in range(r.position.y, r.end.y + 1):
		for i in range(r.position.x, r.end.x + 1):
			var p := Vector2(_x0 + i * CELL, _z0 + j * CELL)
			var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
			var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
			var d := Vector2(dx, dz).length()
			var k := j * _nx + i
			if d < f[k]:
				f[k] = d


## Biome weights on a 4 m grid (normalised; gaps between regions fall back to meadow, and
## outside BOUNDS the horizon is forest on the west and crag elsewhere).
static func _biomes() -> void:
	_bnx = int(_nx * CELL / 4.0) + 2
	_bnz = int(_nz * CELL / 4.0) + 2
	_bw.resize(_bnx * _bnz)
	for j in _bnz:
		for i in _bnx:
			var x := _x0 + i * 4.0
			var z := _z0 + j * 4.0
			var w := {}
			var tot := 0.0
			var at := Vector2(x, z)
			for e: Array in _wreach:
				if not (e[1] as Rect2).has_point(at):
					continue
				var r: Dictionary = e[0]
				var rw := RealmLayout.region_weight(r, x, z)
				if rw <= 0.001:
					continue
				var b := String(r.biome)
				w[b] = maxf(float(w.get(b, 0.0)), rw)
			for b: String in w:
				tot += float(w[b])
			if tot < 0.3:
				w["meadow"] = float(w.get("meadow", 0.0)) + (0.3 - tot)
				tot = 0.3
			for b: String in w.keys():
				w[b] = float(w[b]) / tot
			_bw[j * _bnx + i] = w


## r34 flora: per 4 m biome cell, the region looks there ([LOOKS entry, weight]), the undergrowth
## rate of every UNDER kind (biome blend x looks; one array read per plant kind instead of two
## dictionary walks), the grass tint and the fen share (shore reeds).
static var _lk: Array = []                      # per cell: Array of [look Dictionary, weight]
static var _rc: Array = []                      # per cell: PackedFloat32Array, undergrowth rate /m2 per kind
static var _tc := PackedColorArray()            # per cell: tint of the grassy kinds
static var _fw := PackedFloat32Array()          # per cell: fen weight
static var _ck: Array = []                      # per cell: PackedInt32Array of the kinds that can grow


static func _look_weight(r: Dictionary, x: float, z: float) -> float:
	if r.has("rect"):
		return 1.0 - smoothstep(0.0, LOOK_EDGE, RealmLayout._out_dist(Vector2(x, z), r.rect))
	var d := Vector2(x, z).distance_to(r.c)
	return 1.0 - smoothstep(float(r.r), float(r.r) + LOOK_EDGE, d)


static var no_looks := false             ## --no-r34-flora (A/B, "before" shots): the regions bare of their looks


static func looks_at(x: float, z: float) -> Array:
	var out: Array = []
	if no_looks:
		return out
	if _lreach.is_empty():
		_index_regions()
	var at := Vector2(x, z)
	for e: Array in _lreach:
		if not (e[2] as Rect2).has_point(at):
			continue
		var r: Dictionary = e[0]
		var lw := _look_weight(r, x, z) * (RealmLayout.marches_mask(at) if String(r.id) in RealmLayout.MARCHES_IDS else 1.0)
		if lw > 0.001:
			out.append([e[1], lw, String(r.id)])
	return out


static var _wreach: Array = []                  # [region, Rect2 beyond which its blend weight is 0]
static var _lreach: Array = []                  # [region, look, Rect2 beyond which its look weight is 0]


## Every region's reach, once per build: the biome and look grids ask 14 000 cells about ~50 regions
## each, and all but a few are certainly 0 there (a rect region blends over 18 m plus its ragged
## edge warp, <= 26 m for the Marches' long waves; a look over LOOK_EDGE).
static func _index_regions() -> void:
	_wreach.clear()
	_lreach.clear()
	for r: Dictionary in RealmLayout.REGIONS:
		var reach: Rect2
		var lreach: Rect2
		if r.has("rect"):
			var march := String(r.id) in RealmLayout.MARCHES_IDS
			reach = (r.rect as Rect2).grow(18.0 + (44.0 if march else 10.0))
			for b: Dictionary in r.get("blobs", []):
				var br := float(b.r) * 1.4 + 1.0
				reach = reach.merge(Rect2((b.c as Vector2) - Vector2(br, br), Vector2(br, br) * 2.0))
			lreach = (r.rect as Rect2).grow(LOOK_EDGE + 1.0)
		else:
			var rr := float(r.r) * 1.4 + 1.0
			reach = Rect2((r.c as Vector2) - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
			var lr := float(r.r) + LOOK_EDGE + 1.0
			lreach = Rect2((r.c as Vector2) - Vector2(lr, lr), Vector2(lr, lr) * 2.0)
		_wreach.append([r, reach])
		var look: Dictionary = LOOKS.get(r.id, MarchesLooks.LOOKS.get(r.id, {}))
		if not look.is_empty():
			_lreach.append([r, look, lreach])


static func _looks() -> void:
	var kinds := UNDER.keys()
	var nk := kinds.size()
	var nc := _bnx * _bnz
	var bvec := {}                                  # biome -> rate per kind
	for s in nk:
		var tb: Dictionary = _under_table(kinds[s])
		for bio: String in tb:
			var v := PackedFloat32Array()
			if bvec.has(bio):
				v = bvec[bio]
			else:
				v.resize(nk)
			v[s] = float(tb[bio])
			bvec[bio] = v                           # packed arrays copy on write: store it back
	var row := PackedFloat32Array()
	row.resize(nk)
	var i_reeds := kinds.find("reeds")
	var i_cattail := kinds.find("cattail")
	_lk.resize(nc)
	_ck.resize(nc)
	_rc.resize(nc)
	_tc.resize(nc)
	_fw.resize(nc)
	for j in _bnz:
		for i in _bnx:
			var c := j * _bnx + i
			var x := _x0 + i * 4.0
			var z := _z0 + j * 4.0
			var w: Dictionary = _bw[c]
			var lk := looks_at(x, z)
			_lk[c] = lk
			_fw[c] = float(w.get("fen", 0.0))
			var tint := Color(1, 1, 1)
			for e: Array in lk:
				var lw: float = e[1]
				tint = tint.lerp(tint * ((e[0] as Dictionary).get("tint", Color(1, 1, 1)) as Color), lw)
			_tc[c] = Scorch.grass_tint(tint, x, z)
			row.fill(0.0)
			for bio: String in w:
				if bvec.has(bio):
					var bw := float(w[bio])
					var v: PackedFloat32Array = bvec[bio]
					for s in nk:
						row[s] += v[s] * bw
			for e: Array in lk:
				var L: Dictionary = e[0]
				var lw: float = e[1]
				var mul: Dictionary = L.get("under_mul", {})
				var add: Dictionary = L.get("under_add", {})
				for s in nk:
					var sp: String = kinds[s]
					row[s] = row[s] * lerpf(1.0, float(mul.get(sp, 1.0)), lw) + float(add.get(sp, 0.0)) * lw
			row = Scorch.under(row, kinds, x, z)
			var ks := PackedInt32Array()
			for s in nk:
				if row[s] > 0.0 or (_fw[c] > 0.2 and (s == i_reeds or s == i_cattail)):
					ks.append(s)
			_rc[c] = row.duplicate()
			_ck[c] = ks


static func _bidx(x: float, z: float) -> int:
	return clampi(roundi((z - _z0) / 4.0), 0, _bnz - 1) * _bnx + clampi(roundi((x - _x0) / 4.0), 0, _bnx - 1)


static func biome_w(x: float, z: float) -> Dictionary:
	var i := clampi(roundi((x - _x0) / 4.0), 0, _bnx - 1)
	var j := clampi(roundi((z - _z0) / 4.0), 0, _bnz - 1)
	return _bw[j * _bnx + i]


static func _rate(table: Dictionary, w: Dictionary) -> float:
	var r := 0.0
	for b: String in w:
		r += float(table.get(b, 0.0)) * float(w[b])
	return r


# --- trees ---------------------------------------------------------------------------------------

static func _place_trees(space: PhysicsDirectSpaceState3D, rng_main: RandomNumberGenerator, items: Dictionary) -> void:
	var grid := {}                      # Vector2i(4 m) -> Array of [Vector2, spacing]
	var cands: Array = []
	var step := 3.5
	# the old Realm's candidates first, from the old streams (its wood is the wood it was); the new ground's follow
	var area := RealmLayout.OLD_BOUNDS.grow(MARGIN)
	var z := area.position.y
	while z < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			cands.append(Vector2(x + rng_main.randf_range(0.0, step), z + rng_main.randf_range(0.0, step)))
			x += step
		z += step
	var n_old := cands.size()
	var rng_new := RandomNumberGenerator.new()
	var rng_new_look := RandomNumberGenerator.new()
	rng_new.seed = 20261137
	rng_new_look.seed = 20261138
	var full := RealmLayout.BOUNDS.grow(MARGIN)
	z = full.position.y
	while z < full.end.y:
		var x := full.position.x
		while x < full.end.x:
			if not area.has_point(Vector2(x, z)):
				cands.append(Vector2(x + rng_new.randf_range(0.0, step), z + rng_new.randf_range(0.0, step)))
			x += step
		z += step
	# big trees first so the small ones fill round them
	var order := ["oak", "willow", "pine", "birch", "snag", "sapling", "windtree", "yew"]
	var cover := {}                     # Vector2i(UCELL) -> cover
	# r34 flora: candidates inside a region LOOK draw from their own stream (rng2), so the r33 ground
	# keeps the trees it had; the orchard rows and the cypress avenue go in first
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 20261134
	_place_rows(space, rng2, items, grid, cover)
	var clk: Array = []
	var cw: Array = []                  # per candidate: biome weights, which stream, the stand noise
	var csel := PackedInt32Array()
	var cn0 := PackedFloat32Array()
	for ci in cands.size():
		var c: Vector2 = cands[ci]
		var lk0: Array = _lk[_bidx(c.x, c.y)]
		clk.append(lk0)
		cw.append(biome_w(c.x, c.y))
		cn0.append(_noise[0].get_noise_2d(c.x, c.y))
		var newg := ci >= n_old or (RealmLayout.BOUNDS.has_point(c) and not RealmLayout.OLD_BOUNDS.has_point(c))
		csel.append((0 if lk0.is_empty() else 1) + (2 if newg else 0))
	var streams: Array = [rng_main, rng2, rng_new, rng_new_look]
	for sp: String in order:
		var spacing: float = TREE_SPACING[sp]
		var ids := TreeGen.ids(sp)
		if sp == "snag":
			ids.erase("snag_2")                       # the charred one belongs to the rift (below); the rest are the plain deadwood
		for ci in cands.size():
			var c: Vector2 = cands[ci]
			var lk: Array = clk[ci]
			var rng: RandomNumberGenerator = streams[csel[ci]]
			var w: Dictionary = cw[ci]
			var p := _rate(TREE_P[sp], w)
			for e: Array in lk:
				var L: Dictionary = e[0]
				var lw: float = e[1]
				p = p * lerpf(1.0, float((L.get("tree_mul", {}) as Dictionary).get(sp, 1.0)), lw) + float((L.get("tree_add", {}) as Dictionary).get(sp, 0.0)) * lw
			if p <= 0.0:
				continue
			p *= _tree_mod(sp, c, w, cn0[ci])
			if rng.randf() >= p:
				continue
			var at := c + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			var k := _idx(at.x, at.y)
			if _gn[k] < (0.72 if sp != "pine" else 0.62):
				continue
			var y := _gy[k]
			if sp == "willow" or sp == "sapling" or sp == "snag":
				if y < WATER_Y + 0.15 and Tables.wet(at.x, at.y):
					continue
			elif y < WATER_Y + 0.35 and Tables.wet(at.x, at.y):
				continue
			var id: String = _variant(ids, at.x, at.y, TREE_CHUNK, 2, rng)
			var dead := 0.55
			for e: Array in lk:
				dead = lerpf(dead, float((e[0] as Dictionary).get("dead_willow", dead)), float(e[1]))
			if sp == "willow" and rng.randf() < dead:
				id = "willow_2"                       # the fen's willows are mostly dead (the mere's nearly all)
			if (sp == "snag" and _rate({"ash": 1.0}, w) > 0.3) or Scorch.charred(at):
				id = "snag_2"                         # scorched at the rift
			var d: Dictionary = TreeGen.kind(id)
			var spread: float = d.spread
			var st: Array = STYLE[sp]
			if _pd[k] < float(st[2]) + float(d.r):
				continue
			if _sd[k] < float(d.r) + 2.0:
				rejects[sp + " site"] = int(rejects.get(sp + " site", 0)) + 1
				continue
			if not _spaced(grid, at, spacing):
				rejects[sp + " spacing"] = int(rejects.get(sp + " spacing", 0)) + 1
				continue
			# seat on the lowest ground under the root flare
			var r: float = maxf(float(d.r), 0.1)
			var gy := _ray_y(space, at.x, at.y, y)
			for a in 4:
				var o := Vector2(cos(a * PI * 0.5 + 0.4), sin(a * PI * 0.5 + 0.4)) * r * 1.2
				gy = minf(gy, _ray_y(space, at.x + o.x, at.y + o.y, y))
			if (gy < WATER_Y + 0.05 and Tables.wet(at.x, at.y)) or RealmLayout.path_dist(at) < float(st[2]) + float(d.r):
				continue
			var s := rng.randf_range(0.85, 1.15)
			var yaw := rng.randf() * TAU
			if sp == "windtree":
				yaw = WIND_YAW + (yaw / TAU - 0.5) * 0.7      # thrown downwind (the foliage shader's wind_dir)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.92, 1.08), s))
			var pos := Vector3(at.x, gy, at.y)
			if _clash(space, id, Transform3D(basis, pos), true):
				# its whole crown keeps clear of sites, lanes and doors: try a smaller tree there
				var alt := ""
				for opt: Array in ([["oak_0", 0.85], ["oak_3", 0.8], ["oak_0", 0.62], ["birch_0", 1.0], ["sapling_0", 1.2]] if sp == "oak" else []):
					var a: String = opt[0]
					var sc: float = opt[1]
					var b2 := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
					if not _clash(space, a, Transform3D(b2, pos), true):
						alt = a
						basis = b2
						break
				if alt == "":
					rejects[sp + " clash"] = int(rejects.get(sp + " clash", 0)) + 1
					continue
				id = alt
				d = TreeGen.kind(id)
				s = basis.get_scale().x
			var key := Vector2i(floori(at.x / 4.0), floori(at.y / 4.0))
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append([at, spacing])
			var tint := Scorch.tree_tint(_tint(rng, 0.1), at, sp)
			# a vista round a place (tree_clear): tested after every draw this candidate makes and its spacing taken,
			# so the rest of the wood keeps the exact layout it had without it
			var cleared := Tables.on_edge_wall(at, float(d.spread))
			for tc: Array in tree_clear:
				if at.distance_to(tc[0]) < float(tc[1]) + float(d.spread) * 0.6:
					cleared = true
			if cleared:
				rejects[sp + " vista"] = int(rejects.get(sp + " vista", 0)) + 1
				continue
			# the scale pilot (scale_pilot.gd): fewer, bigger, stouter trees on its ground. Decided here, after every draw and
			# test and from a hash of the spot, so the rest of the wood keeps the layout it had (a thinned tree still holds its
			# spacing); a tree too big for its spot stays the size it was.
			if not Pilot.keeps(at.x, at.y) or not Scorch.tree_keeps(at, sp, id):
				continue
			var pk := Pilot.tree(at.x, at.y, sp)
			var hs := s
			# the full size first, then halfway: a tree too big for its spot stays the size it was
			for f: float in ([1.0, 0.5] if pk.x > 1.01 else []):
				var kk := Vector2.ONE.lerp(pk, f)
				var big := basis.scaled(Vector3(kk.x, kk.y, kk.x))
				if not _clash(space, id, Transform3D(big, pos), true) and _hangs(space, id, big, at, gy) < 0.3:
					basis = big
					s *= kk.x
					hs *= kk.y
					break
			if _hangs(space, id, basis, at, gy) > 0.6:
				continue                                  # even at its own size its roots stand out over a bank: no tree here
			pos.y = maxf(_foot_y(space, id, basis, at, gy), WATER_Y + 0.02 if Tables.wet(at.x, at.y) else -INF)      # after every draw and test: the layout is the one it was
			_add(items, id, Transform3D(basis, pos), tint)
			if bool(d.tall):
				trees.append([pos, id, float(d.r) * s, float(d.h) * hs])
			# canopy cover for the undergrowth
			var cr := spread * s
			var n := int(cr / UCELL) + 1
			for jj in range(-n, n + 1):
				for ii in range(-n, n + 1):
					var q := Vector2i(floori(at.x / UCELL) + ii, floori(at.y / UCELL) + jj)
					var dd := Vector2(q.x * UCELL, q.y * UCELL).distance_to(at) / maxf(cr, 0.5)
					if dd < 1.0:
						cover[q] = minf(float(cover.get(q, 0.0)) + (1.0 - dd) * (0.9 if sp != "snag" else 0.2), 1.0)
	_cover_from(cover)


const WIND_YAW := -0.6435             ## Basis(UP, yaw) turns a windtree's lean (+x) to the shader's wind (0.8, 0.6)


static func _region(id: String) -> Dictionary:
	for r: Dictionary in RealmLayout.REGIONS:
		if r.id == id:
			return r
	return {}


## r34 flora: planted trees. The Cinder Orchard's burned fruit trees stand in rows (gaps where trees
## were lost), and cypresses line the necropolis way up the Waiting Field and its two long sides --
## the planted order reads at once as a made place, the way WoW's and Enshrouded's farmsteads and
## graveyards do. Same checks as the wild trees (_plant_tree); the spacing grid then keeps the wild
## ones off them.
static func _place_rows(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, items: Dictionary, grid: Dictionary, cover: Dictionary) -> void:
	if no_looks:
		return
	var orch := _region("orchard")
	if not orch.is_empty():
		var rect: Rect2 = (orch.rect as Rect2).grow(-2.0)
		var c := rect.get_center()
		var ax := Vector2(cos(0.18), sin(0.18))
		var ay := Vector2(-ax.y, ax.x)
		var v := -40.0
		while v <= 40.0:
			var u := -60.0 + rng.randf_range(0.0, 2.0)
			while u <= 60.0:
				var at := c + ax * u + ay * v + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
				var keep := rng.randf() < 0.78
				var id := "fruit_2" if rng.randf() < 0.15 else "fruit_%d" % rng.randi_range(0, 1)
				if keep and rect.has_point(at):
					_plant_tree(space, rng, items, grid, cover, "fruit", id, at, rng.randf() * TAU)
				u += 5.5
			v += 7.0
	var nec := _region("necropolis")
	if not nec.is_empty():
		var rect: Rect2 = nec.rect
		var spots: Array = []
		for pth: Dictionary in RealmLayout.PATHS:
			if pth.id != "necropolis_way":
				continue
			var pts: Array = pth.pts
			var off := float(pth.w) + 3.4
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var d := (b - a).normalized()
				var n := Vector2(-d.y, d.x)
				var t := 0.0
				while t < a.distance_to(b):
					var q := a + d * t
					if rect.grow(-1.0).has_point(q):
						spots.append(q + n * off)
						spots.append(q - n * off)
					t += 8.0
		var z := rect.position.y + 5.0
		while z < rect.end.y - 3.0:
			for x: float in [rect.position.x + 3.0, rect.end.x - 3.0]:
				if rng.randf() < 0.75:
					spots.append(Vector2(x, z))
			z += 9.0
		# lone cypresses standing over the ranks of graves, a few to a rank
		z = rect.position.y + 8.0
		while z < rect.end.y - 4.0:
			var x := rect.position.x + 7.0
			while x < rect.end.x - 6.0:
				if rng.randf() < 0.6:
					spots.append(Vector2(x, z))
				x += 9.0
			z += 12.0
		for q: Vector2 in spots:
			var id := "cypress_%d" % (0 if rng.randf() < 0.7 else 1)
			# graves and tombs fill the field: a cypress that cannot stand on its mark takes the
			# nearest free ground a step or two off it
			for k in 4:
				var o := Vector2.ZERO if k == 0 else Vector2(cos(k * 2.1), sin(k * 2.1)) * (1.2 + k * 0.6)
				if _plant_tree(space, rng, items, grid, cover, "cypress", id, q + o, rng.randf() * TAU):
					break


static func _plant_tree(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, items: Dictionary, grid: Dictionary, cover: Dictionary, sp: String, id: String, at: Vector2, yaw: float) -> bool:
	var k := _idx(at.x, at.y)
	if _gn[k] < 0.72 or (_gy[k] < WATER_Y + 0.35 and Tables.wet(at.x, at.y)) or _ok[k] == 0:
		rejects[sp + " ground"] = int(rejects.get(sp + " ground", 0)) + 1
		return false
	var d: Dictionary = TreeGen.kind(id)
	var st: Array = STYLE[sp]
	if _pd[k] < float(st[2]) + float(d.r) or _sd[k] < float(d.r) + 2.0:
		rejects[sp + " site"] = int(rejects.get(sp + " site", 0)) + 1
		return false
	var spacing: float = TREE_SPACING[sp]
	if not _spaced(grid, at, spacing):
		rejects[sp + " spacing"] = int(rejects.get(sp + " spacing", 0)) + 1
		return false
	var y := _gy[k]
	var r: float = maxf(float(d.r), 0.1)
	var gy := _ray_y(space, at.x, at.y, y)
	for a in 4:
		var o := Vector2(cos(a * PI * 0.5 + 0.4), sin(a * PI * 0.5 + 0.4)) * r * 1.2
		gy = minf(gy, _ray_y(space, at.x + o.x, at.y + o.y, y))
	if (gy < WATER_Y + 0.05 and Tables.wet(at.x, at.y)) or RealmLayout.path_dist(at) < float(st[2]) + float(d.r):
		return false
	var s := rng.randf_range(0.88, 1.12)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.94, 1.06), s))
	var pos := Vector3(at.x, gy, at.y)
	if _clash(space, id, Transform3D(basis, pos), true):
		rejects[sp + " clash"] = int(rejects.get(sp + " clash", 0)) + 1
		return false
	var tint := _tint(rng, 0.1)                                  # (drawn before the edge band and tree_clear: a row tree they take leaves the stream as it was)
	if Tables.on_edge_wall(at, float(d.spread)) or tree_clear.any(func(tc: Array) -> bool: return at.distance_to(tc[0]) < float(tc[1]) + float(d.spread) * 0.6): return false
	var key := Vector2i(floori(at.x / 4.0), floori(at.y / 4.0))
	if not grid.has(key):
		grid[key] = []
	(grid[key] as Array).append([at, spacing])
	pos.y = maxf(_foot_y(space, id, basis, at, gy), WATER_Y + 0.02 if Tables.wet(at.x, at.y) else -INF)
	_add(items, id, Transform3D(basis, pos), tint)
	if bool(d.tall):
		trees.append([pos, id, float(d.r) * s, float(d.h) * s])
	var cr := float(d.spread) * s
	var n := int(cr / UCELL) + 1
	for jj in range(-n, n + 1):
		for ii in range(-n, n + 1):
			var q := Vector2i(floori(at.x / UCELL) + ii, floori(at.y / UCELL) + jj)
			var dd := Vector2(q.x * UCELL, q.y * UCELL).distance_to(at) / maxf(cr, 0.5)
			if dd < 1.0:
				cover[q] = minf(float(cover.get(q, 0.0)) + (1.0 - dd) * 0.5, 1.0)
	return true


static var _aabbs := {}


## Mesh bounds of a kind (near and far versions together), local to the plant.
static func mesh_aabb(id: String) -> AABB:
	if _aabbs.has(id):
		return _aabbs[id]
	var out := AABB()
	var first := true
	for kid: String in ([id, id + "@far"] if id.substr(0, id.rfind("_")) in TreeGen.FAR else [id]):
		var d: Dictionary = TreeGen.kind(kid)
		for key: String in ["solid", "cards"]:
			if d[key] != null:
				var b: AABB = (d[key] as Mesh).get_aabb()
				out = b if first else out.merge(b)
				first = false
	_aabbs[id] = out
	return out


## Sites with something tall in them (roofs, towers, the Crossing deck): tree crowns keep clear
## of these. Low sites (menhirs, braziers, graves, low walls, gardens) only keep trunks off.
static var _tall_sites: Array[Dictionary] = []
static var _space: PhysicsDirectSpaceState3D


static func _find_tall_sites(space: PhysicsDirectSpaceState3D) -> void:
	_tall_sites.clear()
	var q := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Layers.WORLD | Layers.PROPS)
	for st: Dictionary in WorldLanes.sites:
		var n := String(st.name)
		if n.begins_with("wayside_"): continue                  # (built after the flora; flora_layers.gd clears their ground)
		if n.begins_with("rift_") or n.begins_with("tavern") or n.begins_with("oss_"):
			_tall_sites.append(st)
			continue
		var r: Rect2 = st.rect
		var fy := float(st.floor_y)
		var tall := false
		for j in 4:
			for i in 4:
				var x := r.position.x + r.size.x * (i + 0.5) / 4.0
				var z := r.position.y + r.size.y * (j + 0.5) / 4.0
				q.from = Vector3(x, fy + 40.0, z)
				q.to = Vector3(x, fy - 2.0, z)
				var hit := space.intersect_ray(q)
				if not hit.is_empty() and not String((hit.collider as Node).name).begins_with("Terrain") \
						and (hit.position as Vector3).y > fy + 3.0:
					tall = true
		if tall:
			_tall_sites.append(st)


## Keep-out test for one plant. Trees: the trunk and root footprint (bottom 2.5 m, as zz/audit
## proxies tall MultiMesh instances) against every site box, portal approach and runtime lane, and
## the whole crown against tall sites only. Undergrowth: its whole box against sites and portals.
static func _clash(space: PhysicsDirectSpaceState3D, id: String, xf: Transform3D, tree: bool, given := AABB(), pad := 0.4) -> bool:
	var la := mesh_aabb(id) if given.size == Vector3.ZERO else AABB()
	var full := xf * la if given.size == Vector3.ZERO else given
	var boxes: Array[AABB] = [full]
	if tree:
		var d: Dictionary = TreeGen.kind(id)
		var sc := xf.basis.get_scale().x
		var tr := maxf(float(d.r) * sc * 1.4 + 0.35, 0.75)
		boxes = [AABB(Vector3(xf.origin.x - tr, xf.origin.y - 0.6, xf.origin.z - tr), Vector3(tr * 2.0, 3.1, tr * 2.0))]
		# zz/audit proxies a tall instance by a 1.5 m column under its mesh box centre, which sits
		# off the trunk when the crown leans: keep that clear too
		var c := xf * Vector3(la.get_center().x, la.position.y, la.get_center().z)
		var hw := 0.75 * sc + 0.4
		boxes.append(AABB(Vector3(c.x - hw, c.y, c.z - hw), Vector3(hw * 2.0, 2.6, hw * 2.0)))
		# r34 flora: and the audit proxies each crown mesh (near and far cards) by the same column from
		# the crown's underside: a low crown on a slope reached down into a site's 6.4 m volume
		for kid: String in ([id, id + "@far"] if id.substr(0, id.rfind("_")) in TreeGen.FAR else [id]):
			var kd: Dictionary = TreeGen.kind(kid)
			if kd.cards != null:
				var cb: AABB = (kd.cards as Mesh).get_aabb()
				var cc := xf * Vector3(cb.get_center().x, cb.position.y, cb.get_center().z)
				boxes.append(AABB(Vector3(cc.x - hw, cc.y, cc.z - hw), Vector3(hw * 2.0, 2.6 * sc, hw * 2.0)))
		var fr := Rect2(full.position.x, full.position.z, full.size.x, full.size.z)
		for st: Dictionary in _tall_sites:
			if _site_hits(st, fr, 0.5) and full.end.y > float(st.floor_y) - 1.0:
				return true
	for wb in boxes:
		var r := Rect2(wb.position.x, wb.position.z, wb.size.x, wb.size.z)
		var sites := WorldLanes.sites
		var c0 := Vector2i(floori((r.position.x - 0.5) / SITE_CELL), floori((r.position.y - 0.5) / SITE_CELL))
		var c1 := Vector2i(floori((r.end.x + 0.5) / SITE_CELL), floori((r.end.y + 0.5) / SITE_CELL))
		for cj in range(c0.y, c1.y + 1):
			for ci in range(c0.x, c1.x + 1):
				var cell := Vector2i(ci, cj)
				for si: int in _site_grid.get(cell, _NONE):
					var st: Dictionary = sites[si]
					if _site_hits(st, r, pad) and wb.end.y > float(st.floor_y) - 1.0 and (wb.position.y < float(st.floor_y) + 6.4 or pad > 0.5):
						return true
				for pi: int in _portal_grid.get(cell, _NONE):
					if _portal_boxes[pi].intersects(wb):
						return true
		if space != null and WorldLanes.intrudes(space, wb, 0.3) != "":
			return true
	return false


## r34 flora: sites bucketed on an 8 m grid (by their box grown 1 m) and the portals' boxes made
## once, so a plant's clash test looks at its neighbours only (it walked all ~250 sites per plant
## near any keep-out: about half the undergrowth's time over the doubled Realm).
const SITE_CELL := 8.0
static var _site_grid := {}
static var _portal_boxes: Array[AABB] = []
static var _portal_grid := {}          ## Vector2i(8 m) -> indices into _portal_boxes of those reaching the cell
static var _NONE: Array = []


## Runtime lanes' boxes (WorldLanes.extra_lanes grown by their width and intrudes' pads): only a
## plant inside one needs WorldLanes.intrudes (its physics floor test); the site half of intrudes is
## the grid test above with intrudes' 0.6 m pad.
static var _lane_rects: Array[Rect2] = []


static func _near_lane(b: AABB) -> bool:
	var r := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
	for lr in _lane_rects:
		if lr.intersects(r):
			return true
	return false


static func _index_sites() -> void:
	_site_grid.clear()
	_portal_boxes.clear()
	_portal_grid.clear()
	_lane_rects.clear()
	_lane_bounds.clear()
	for lane: Array in WorldLanes.extra_lanes:
		var pl := Rect2((lane[1] as Array)[0], Vector2.ZERO)
		for v: Vector2 in lane[1]:
			pl = pl.expand(v)
		_lane_bounds.append([lane, pl])
	for l: Array in WorldLanes.extra_lanes:
		var pts: Array = l[1]
		var lr := Rect2(pts[0], Vector2.ZERO)
		for v: Vector2 in pts:
			lr = lr.expand(v)
		_lane_rects.append(lr.grow(float(l[2]) + 1.2))
	var sites := WorldLanes.sites
	for si in sites.size():
		if String(sites[si].name).begins_with("wayside_"): continue      # (flora_layers.gd clears the wayside's ground after the scatter)
		var r: Rect2 = (sites[si].rect as Rect2).grow(1.0)
		for cj in range(floori(r.position.y / SITE_CELL), floori(r.end.y / SITE_CELL) + 1):
			for ci in range(floori(r.position.x / SITE_CELL), floori(r.end.x / SITE_CELL) + 1):
				var key := Vector2i(ci, cj)
				if not _site_grid.has(key):
					_site_grid[key] = []
				(_site_grid[key] as Array).append(si)
	for p: Dictionary in WorldLanes.portals:
		var pb: Array = WorldLanes.portal_box(p)
		var ext: Vector3 = pb[1]
		var pbox := (pb[0] as Transform3D) * AABB(-ext - Vector3(0.3, 0.3, 0.3), ext * 2.0 + Vector3(0.6, 0.6, 0.6))
		for cj in range(floori((pbox.position.z - 0.5) / SITE_CELL), floori((pbox.end.z + 0.5) / SITE_CELL) + 1):
			for ci in range(floori((pbox.position.x - 0.5) / SITE_CELL), floori((pbox.end.x + 0.5) / SITE_CELL) + 1):
				var pk := Vector2i(ci, cj)
				if not _portal_grid.has(pk):
					_portal_grid[pk] = []
				(_portal_grid[pk] as Array).append(_portal_boxes.size())
		_portal_boxes.append(pbox)


## r34: a raid floor by its circle, any other site by its box (as before r34).
static func _site_hits(st: Dictionary, r: Rect2, pad: float) -> bool:
	if String(st.name).begins_with("raid_"):
		return WorldLanes.site_hits_rect(st, r, pad)
	return (st.rect as Rect2).grow(pad).intersects(r)


static func _tree_mod(sp: String, c: Vector2, w: Dictionary, n0: float) -> float:
	# n0: the stands-and-clearings noise at c
	var m := clampf(1.0 + n0 * 1.3, 0.05, 1.8)
	if float(w.get("oldforest", 0.0)) > 0.5 and n0 < -0.45:
		m *= 0.1                                           # Thornwood clearings
	var gd := c.distance_to(RealmLayout.GLADE_C)
	if gd < 18.0:
		m *= smoothstep(10.0, 15.0, gd) * (1.6 if sp == "birch" else 1.0)   # the glade is open, ringed by birch
	if not RealmLayout.BOUNDS.has_point(c):
		m *= 1.4 if sp in ["oak", "pine", "birch"] else 0.3   # a dark wall of trees beyond the edge
	return m


static func _spaced(grid: Dictionary, p: Vector2, spacing: float) -> bool:
	var k := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for j in range(-2, 3):
		for i in range(-2, 3):
			var lst: Array = grid.get(k + Vector2i(i, j), [])
			for e: Array in lst:
				if (e[0] as Vector2).distance_to(p) < maxf(spacing, float(e[1])) * 0.5 + minf(spacing, float(e[1])) * 0.5:
					return false
	return true


const FOOT_SINK := 1.5              ## no tree is sunk further than this under the ground at its middle
## A tree's origin y on a slope: lowered until no part of its footing (Footing) hangs over the ground.
static func _foot_y(space: PhysicsDirectSpaceState3D, id: String, basis: Basis, at: Vector2, gy: float) -> float:
	var gf := func(x: float, z: float) -> float: return _ray_y(space, x, z, gy)
	return Footing.seat_y(gf, Footing.base_points((TreeGen.kind(id).solid) as Mesh), basis, at, gy, FOOT_SINK)


## How far the worst root of `id` (basis, seated at `at`) stands over the ground: a bigger flare reaches over a
## bank's edge or into a ditch where the tree's own size fitted.
static func _hangs(space: PhysicsDirectSpaceState3D, id: String, basis: Basis, at: Vector2, gy: float) -> float:
	var y := _foot_y(space, id, basis, at, gy)
	var worst := 0.0
	for v: Vector3 in Footing.base_points((TreeGen.kind(id).solid) as Mesh):
		var w := basis * v
		worst = maxf(worst, y + w.y - _ray_y(space, at.x + w.x, at.y + w.z, gy))
	return worst


static func _ray_y(space: PhysicsDirectSpaceState3D, x: float, z: float, fallback: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, fallback + 30.0, z), Vector3(x, fallback - 30.0, z), Layers.WORLD))
	return (hit.position as Vector3).y if not hit.is_empty() else fallback


static func _cover_from(cover: Dictionary) -> void:
	var nx := int(_nx * CELL / UCELL) + 1
	var nz := int(_nz * CELL / UCELL) + 1
	_cover.resize(nx * nz)
	_cover.fill(0.0)
	for q: Vector2i in cover:
		var i := int((q.x * UCELL - _x0) / UCELL)
		var j := int((q.y * UCELL - _z0) / UCELL)
		if i >= 0 and j >= 0 and i < nx and j < nz:
			_cover[j * nx + i] = cover[q]


static func cover_at(x: float, z: float) -> float:
	var nx := int(_nx * CELL / UCELL) + 1
	var i := clampi(int((x - _x0) / UCELL), 0, nx - 1)
	var j := clampi(int((z - _z0) / UCELL), 0, int(_nz * CELL / UCELL))
	var k := j * nx + i
	return _cover[k] if k < _cover.size() else 0.0


# --- undergrowth ---------------------------------------------------------------------------------

## r34 flora: the undergrowth row by row (2 m), each row from its own seed, then the physics checks
## near the ways (WorldLanes.intrudes) for the rows' plants in order. (WorkerThreadPool rows were
## tried: GDScript's shared refcounts and per-call debug counters made 12 threads slower than one.)
## Rates come from the per-cell table (_looks); this reshuffled every plant once against r33.
static var _under_kinds: Array = []
static var _under_ids := {}


static func _place_under(_rng: RandomNumberGenerator, items: Dictionary) -> void:
	var kinds := UNDER.keys()
	var ids := {}
	for sp: String in kinds:
		ids[sp] = TreeGen.ids(sp)
		var w := 0.0
		for id: String in ids[sp]:
			w = maxf(w, float(TreeGen.kind(id).spread))
		spreads[sp] = minf(w, 3.0)
		_list_hash[sp] = hash(ids[sp][0]) if not (ids[sp] as Array).is_empty() else 0
	_under_kinds = kinds
	_under_ids = ids
	_soft_on = not r30 and not Zones.off()
	_nm.resize(9)
	_ukind.clear()
	for sp: String in kinds:
		var st: Array = STYLE[sp]
		_ukind.append([int(KCODE.get(sp, 99)), float(st[2]), float(st[3]) + float(spreads[sp]), sp in TINTED,
			sp in Zones.SOFT_KINDS and _soft_on, ids[sp], _list_hash[sp]])
	# the old Realm's rows as they were; the rest of the new world is a second set of rows from other seeds
	var b := RealmLayout.OLD_BOUNDS
	var nrow := int(ceil(b.size.y / UCELL))
	var out: Array = []
	for j in nrow:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261103 + j * 7919
		var z := b.position.y + j * UCELL
		var x := b.position.x
		while x < b.end.x:
			_under_cell(rng, items, out, kinds, x, z)
			x += UCELL
	var nb := RealmLayout.BOUNDS
	var nrow2 := int(ceil(nb.size.y / UCELL))
	for j in nrow2:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 20261141 + j * 7919
		var z2 := nb.position.y + j * UCELL
		var x2 := nb.position.x
		while x2 < nb.end.x:
			if not b.has_point(Vector2(x2, z2)):
				_under_cell(rng2, items, out, kinds, x2, z2)
			x2 += UCELL
	_lap("under_cells")
	for e: Array in out:
		if bool(e[3]) and _intrudes((e[1] as Transform3D) * mesh_aabb(e[0]), 0.3):
			continue
		_add(items, e[0], e[1], e[2], e[4])


static var _list_hash := {}
static var _lane_bounds: Array = []    ## [lane, Rect2 of its points] of the fixed and runtime lanes


## WorldLanes.intrudes(_space, b, pad) != "" with the same tests, minus the walk over every site and
## lane per call: sites come from the 8 m grid (_index_sites), lane bounds are made once.
static func _intrudes(b: AABB, pad: float) -> bool:
	var rect := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
	var lo := rect.position
	var hi := rect.end
	var q := rect.grow(pad + 0.3)
	var sites := WorldLanes.sites
	for cj in range(floori(q.position.y / SITE_CELL), floori(q.end.y / SITE_CELL) + 1):
		for ci in range(floori(q.position.x / SITE_CELL), floori(q.end.x / SITE_CELL) + 1):
			for si: int in _site_grid.get(Vector2i(ci, cj), []):
				var st: Dictionary = sites[si]
				if WorldLanes.site_hits_rect(st, rect, pad + 0.3) and b.end.y > float(st.floor_y) - 1.0:
					return true
	for e: Array in _lane_bounds:
		var lane: Array = e[0]
		var w: float = float(lane[2]) + pad
		var lb: Rect2 = e[1]
		if hi.x < lb.position.x - w or lo.x > lb.end.x + w or hi.y < lb.position.y - w or lo.y > lb.end.y + w:
			continue
		var pts: Array = lane[1]
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var c: Vector2 = pts[k + 1]
			var n := maxi(1, ceili(a.distance_to(c) / WorldLanes.STEP))
			for i in n + 1:
				var sp := a.lerp(c, float(i) / float(n))
				if sp.clamp(lo, hi).distance_to(sp) > w:
					continue
				var fy := WorldLanes.floor_at(_space, sp)
				if is_nan(fy):
					continue
				if b.position.y < fy + WorldLanes.HEADROOM and b.end.y > fy + 0.06:
					return true
	return false

static var spreads := {}               ## species -> widest variant footprint radius (m)


## Kind codes for the undergrowth's hot loops (an int match instead of string compares).
const KCODE := {"grass": 0, "tallgrass": 1, "flowers": 2, "heather": 3, "fern": 4, "litter": 5, "moss": 6, "roots": 7,
	"mushroom": 8, "shrub": 9, "bramble": 10, "glowcap": 11, "gorse": 12, "deadbush": 13, "scaffold": 14,
	"ashdrift": 15, "cinders": 16, "lily": 17, "reeds": 18, "cattail": 19, "log": 20, "stump": 21}
static var _ukind: Array = []          ## per UNDER kind: [code, keep_p, keep_s, tinted, soft kind, variant list, list hash]
static var _nm := PackedFloat32Array() ## noise values of the cell being placed (NAN = not asked yet)
static var _soft_on := true


## One 2 m cell of undergrowth into `items`; plants on a runtime lane's ground into `out` as
## [id, Transform3D, Color, true, species] for the physics check.
static func _under_cell(rng: RandomNumberGenerator, items: Dictionary, out: Array, kinds: Array, x: float, z: float) -> void:
	var k := _idx(x + UCELL * 0.5, z + UCELL * 0.5)
	if (_sd[k] < 0.3 and _soft[k] <= 0.0) or _pd[k] < 0.0:
		return
	var bc := _bidx(x, z)
	var cov := cover_at(x, z)
	var y := _gy[k]
	var shore := y < WATER_Y + 0.3 and y > WATER_Y - 0.35
	var fen := _fw[bc]
	var tint := _tc[bc]
	var rates: PackedFloat32Array = _rc[bc]
	var ok := _ok
	var pd := _pd
	var sd := _sd
	var softf := _soft
	var gnv := _gn
	var gyv := _gy
	var x0 := _x0
	var z0 := _z0
	var nx := _nx
	var nz := _nz
	_nm.fill(NAN)
	var near_spawn := Vector2(x, z).distance_to(Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z)) < 18.0
	for s: int in _ck[bc]:
		var sp: String = kinds[s]
		var uk: Array = _ukind[s]
		var code: int = uk[0]
		var rate := rates[s] * Pilot.under_more(sp)
		var wet := code == 18 or code == 19
		if rate <= 0.0 and not (wet and shore):
			continue
		if wet:
			if shore and fen > 0.2:
				var boost := (0.3 if code == 18 else 0.1) * clampf(_nv(7, 2, x * 1.7, z * 1.7) * 3.0 + 0.2, 0.0, 1.5)
				for e: Array in _lk[bc]:
					boost *= lerpf(1.0, float(((e[0] as Dictionary).get("under_mul", {}) as Dictionary).get(sp, 1.0)), float(e[1]))
				rate += boost
		if rate <= 0.0:
			continue
		if code == 17 and y > WATER_Y - 0.12:
			continue                                   # pads only on open water
		rate *= _under_mod(code, x, z, cov, near_spawn)
		var expect := rate * UCELL * UCELL
		var n := int(expect)
		if rng.randf() < expect - n:
			n += 1
		if n == 0:
			continue
		var keep_p: float = uk[1]
		var keep_s: float = uk[2]
		var tinted: bool = uk[3]
		var soft_kind: bool = uk[4]
		var list: Array = uk[5]
		var lh: int = uk[6]
		for c in n:
			var px := x + rng.randf() * UCELL
			var pz := z + rng.randf() * UCELL
			var kk := clampi(int((pz - z0) / CELL), 0, nz - 1) * nx + clampi(int((px - x0) / CELL), 0, nx - 1)
			var pdk := pd[kk]
			var sdk := sd[kk]
			if ok[kk] == 0 or (not soft_kind and (pdk < keep_p or sdk < keep_s)):
				continue
			if soft_kind and (sdk < keep_s + 3.2 or pdk < keep_p + 2.0):      # near a keep-out: a ragged edge, not a ruled one
				var f := Zones.edge_f(sdk, softf[kk], pdk, keep_s, keep_p, _noise[2].get_noise_2d(px * 0.35, pz * 0.35))
				if f <= 0.0 or (f < 1.0 and Zones.h01(px, pz) > f) or (pdk < 2.0 and RealmLayout.path_dist(Vector2(px, pz)) < 0.4):      # (the grid is 1 m: a cell that reads 1.x can hold ground 0.2 m from the edge)
					continue
			elif pdk < keep_p + 1.5 and RealmLayout.path_dist(Vector2(px, pz)) < keep_p:
				continue                                   # the grid is 1 m: exact near the edge
			if (code == 20 or code == 21) and Tables.on_walk_route(Vector2(px, pz)):
				continue                                   # no log or stump across a walked route off the paths
			# ground_y(px, pz), inline
			var fx := clampf((px - x0) / CELL, 0.0, nx - 1.001)
			var fz := clampf((pz - z0) / CELL, 0.0, nz - 1.001)
			var gi := int(fx)
			var gj := int(fz)
			var gtx := fx - gi
			var gtz := fz - gj
			var gbase := gj * nx + gi
			var gy := lerpf(lerpf(gyv[gbase], gyv[gbase + 1], gtx), lerpf(gyv[gbase + nx], gyv[gbase + nx + 1], gtx), gtz)
			if code == 17:
				if gy > WATER_Y - 0.15 or not Land.in_water(px, pz):
					continue
				gy = WATER_Y
			elif gy < WATER_Y + 0.12 and not wet and Tables.wet(px, pz):      # (a dry hollow under the fen's level grows as the ground round it)
				continue
			if wet and gy < WATER_Y - 0.4:
				continue
			if gnv[kk] < 0.6 and code != 6 and code != 17:
				continue
			var nrm := Vector3(_gnx[kk], gnv[kk], _gnz[kk]).normalized() if code != 17 else Vector3.UP
			var id: String = _variant(list, px, pz, CHUNK, 1, rng, lh)
			var xf := _plant_xf(rng, code, Vector3(px, gy, pz), nrm)
			var gk := Pilot.under(sp)
			if gk != 1.0:
				xf.basis = xf.basis.scaled(Vector3(gk, gk, gk))     # the low growth's size (scale_pilot.UNDER)
			var near_way := pdk < 4.0
			if (sdk < 8.0 or near_way) and _clash(null, id, xf, false, AABB(), 0.6 if near_way else 0.4):
				continue
			var lane := false
			if near_way:
				lane = _near_lane(xf * mesh_aabb(id))
			var col := _tint(rng, 0.14 if code != 2 else 0.05)
			if tinted:
				col = Color(col.r * tint.r, col.g * tint.g, col.b * tint.b, 1.0) * (preload("res://core/world/realm/flora_signature.gd").flower_tint(px, pz) if code == 2 else Color.WHITE)      # flowers take the region's own hue
			if lane:
				out.append([id, xf, col, lane, sp])        # the lane check after the pass
			else:
				_add(items, id, xf, col, sp)


## A noise value for the cell being placed, asked once per slot: the kinds of a cell share the same
## few lookups.
static func _nv(slot: int, ni: int, x: float, z: float) -> float:
	var v := _nm[slot]
	if is_nan(v):
		v = _noise[ni].get_noise_2d(x, z)
		_nm[slot] = v
	return v


static func _under_mod(code: int, x: float, z: float, cov: float, near_spawn: bool) -> float:
	var m := 1.0
	match code:
		0, 2, 3, 1:                                    # grass, flowers, heather, tallgrass
			m *= 1.0 - 0.75 * cov
			m *= clampf(0.85 + _nv(0, 1, x, z) * 0.7, 0.35, 1.4)
		4:                                             # fern
			m *= 0.35 + 1.1 * cov
			m *= clampf(0.6 + _nv(1, 2, x, z) * 1.5, 0.0, 1.8)
			m *= 1.0 + 0.8 * _edge(cov)
		5, 6, 8, 7:                                    # litter, moss, mushroom, roots
			m *= 0.25 + 1.3 * cov
			m *= clampf(0.6 + _nv(3, 4, x, z) * 1.3, 0.0, 1.8)
		9, 10:                                         # shrub, bramble
			m *= clampf(0.4 + _nv(4, 5, x, z) * 1.8, 0.0, 2.2)
			m *= 1.0 + 1.6 * _edge(cov)
		11:                                            # glowcap
			m *= 0.3 + cov
		12, 13, 14:                                    # gorse, deadbush, scaffold
			m *= clampf(0.4 + _nv(4, 5, x, z) * 1.8, 0.0, 2.2)
		15, 16:                                        # ashdrift, cinders
			m *= clampf(0.7 + _nv(5, 4, x * 0.8, z * 0.8) * 1.6, 0.0, 2.0)
		17:                                            # lily
			m *= clampf(0.5 + _nv(6, 2, x * 1.3, z * 1.3) * 2.0, 0.0, 2.0)
	if code == 2:
		m *= clampf(0.3 + _nv(2, 3, x, z) * 2.0, 0.0, 2.0)
	# the meadow round the spawn and the tavern stays walkable and open: grass only near them
	if near_spawn and (code == 9 or code == 10 or code == 1 or code == 20 or code == 21):
		m *= 0.1
	return m


## 1 where the canopy is broken (a wood's edge, a clearing's rim), 0 in the open and in deep shade:
## undergrowth crowds the light at a forest's edge.
static func _edge(cov: float) -> float:
	if r30:
		return 0.0
	return clampf(1.0 - absf(cov - 0.35) / 0.3, 0.0, 1.0)


static func _plant_xf(rng: RandomNumberGenerator, code: int, p: Vector3, nrm: Vector3) -> Transform3D:
	var yaw := rng.randf() * TAU
	var s := rng.randf_range(0.8, 1.25)
	var up := Vector3.UP
	match code:
		5, 6, 7, 15, 14:                               # litter, moss, roots, ashdrift, scaffold
			up = nrm
		17:                                            # lily
			up = Vector3.UP
		20:                                            # log
			up = nrm.lerp(Vector3.UP, 0.3).normalized()
		_:
			up = nrm.lerp(Vector3.UP, 0.7).normalized()
	var fwd := Vector3(cos(yaw), 0, sin(yaw))
	var rt := up.cross(fwd).normalized()
	fwd = rt.cross(up).normalized()
	var basis := Basis(rt, up, fwd)
	if code == 20:
		s = rng.randf_range(0.85, 1.1)
	elif code == 18 or code == 19 or code == 1:
		basis = basis.scaled(Vector3(1, rng.randf_range(0.85, 1.25), 1))
	var sink := 0.0
	if code == 20 or code == 21 or code == 7:
		sink = -0.08
	return Transform3D(basis.scaled(Vector3(s, s, s)), p + up * sink)


## Each chunk draws only `per` variants of a species (every variant is a draw call per chunk);
## neighbouring chunks pick different ones, so the variety is still there across the wood.
static var _vcx := -999999
static var _vcz := -999999
static var _vh := 0


static func _variant(list: Array, x: float, z: float, csize: float, per: int, rng: RandomNumberGenerator, lh := 0) -> String:
	if list.size() <= per:
		return list[rng.randi() % list.size()]
	var cx := floori(x / csize)
	var cz := floori(z / csize)
	if cx != _vcx or cz != _vcz:
		_vcx = cx
		_vcz = cz
		_vh = hash(Vector2i(cx, cz))
	var h := absi(_vh + (lh if lh != 0 else hash(list[0])))
	return list[(h + rng.randi() % per) % list.size()]


static func _tint(rng: RandomNumberGenerator, amt: float) -> Color:
	var v := rng.randf_range(1.0 - amt, 1.0 + amt * 0.6)
	return Color(v * rng.randf_range(0.96, 1.04), v, v * rng.randf_range(0.96, 1.04), 1.0)


## Instances of one kind in one chunk while placing: 16 floats each (a MultiMesh row: basis rows
## with the origin relative to the chunk node, then colour). A holder, so appends are in place.
class Buf:
	var f := PackedFloat32Array()
	var pos := Vector3.ZERO             ## the chunk node's position


static var _last_buf: Buf              ## the batch the last plant went into
static var _last_store := {}
static var _last_name := ""
static var _last_key := Vector3i.ZERO
static var _canopy := {}               ## tall-tree chunk key -> [[base, height, crown radius, conifer]] for its far shell
static var _kinds := {}                ## kind id -> [chunk size, tag]


## Append one plant to `store[name][chunk key]`; the chunk is `csize` m, `tag` 1 for the tall trees.
static func _push(store: Dictionary, name: String, csize: float, tag: int, xf: Transform3D, col: Color) -> Vector3i:
	var key := Vector3i(floori(xf.origin.x / csize), floori(xf.origin.z / csize), tag)
	var b: Buf
	if _last_buf != null and is_same(_last_store, store) and _last_name == name and _last_key == key:
		b = _last_buf
	else:
		var per: Dictionary = store.get(name, {})
		if per.is_empty():
			store[name] = per
		b = per.get(key)
		if b == null:
			b = Buf.new()
			var cx := (key.x + 0.5) * csize
			var cz := (key.y + 0.5) * csize
			b.pos = Vector3(cx, ground_y(cx, cz), cz)
			per[key] = b
		_last_buf = b
		_last_store = store
		_last_name = name
		_last_key = key
	var org := xf.origin - b.pos
	var bs := xf.basis
	var o := b.f.size()
	b.f.resize(o + 16)
	var f := b.f
	f[o] = bs.x.x; f[o + 1] = bs.y.x; f[o + 2] = bs.z.x; f[o + 3] = org.x
	f[o + 4] = bs.x.y; f[o + 5] = bs.y.y; f[o + 6] = bs.z.y; f[o + 7] = org.y
	f[o + 8] = bs.x.z; f[o + 9] = bs.y.z; f[o + 10] = bs.z.z; f[o + 11] = org.z
	f[o + 12] = col.r; f[o + 13] = col.g; f[o + 14] = col.b; f[o + 15] = col.a
	return key


static func _add(items: Dictionary, id: String, xf: Transform3D, col: Color, sp := "") -> void:
	var kd: Array = _kinds.get(id, [])
	if kd.is_empty():
		kd = [Emit.chunk_of(id), 0]
		_kinds[id] = kd
	var cs: Vector2 = kd[0]
	var key := _push(items, id, cs.x, int(cs.y), xf, col)
	if sp == "":
		sp = id.substr(0, id.rfind("_"))
	placed[sp] = int(placed.get(sp, 0)) + 1
	var d: Dictionary = TreeGen.kind(id)
	if cs.y > 0.0 and float(d.h) > 4.0:
		FarDetail.note_crowns(_canopy, key, [[xf, col]], float(d.h), float(d.spread), sp in ["pine", "cypress", "yew"])


## The buffers as plain packed arrays: undergrowth chunks in random order (a lower
## visible_instance_count, apply_detail, then thins the whole chunk evenly instead of dropping one
## corner), trees and stones as placed.
static func _finish(store: Dictionary, shuffle: bool) -> Dictionary:
	var out := {}
	for name: String in store:
		var per: Dictionary = store[name]
		var done := {}
		for key: Vector3i in per:
			var f: PackedFloat32Array = (per[key] as Buf).f
			if shuffle and key.z == 0:
				var n := f.size() / 16
				var perm := PackedInt32Array()
				perm.resize(n)
				for i in n:
					perm[i] = i
				var srng := RandomNumberGenerator.new()
				srng.seed = hash([name, key])
				for k in range(n - 1, 0, -1):
					var r := srng.randi_range(0, k)
					var tmp := perm[k]
					perm[k] = perm[r]
					perm[r] = tmp
				var sh := PackedFloat32Array()
				for i in n:
					sh.append_array(f.slice(perm[i] * 16, perm[i] * 16 + 16))
				f = sh
			done[key] = f
		out[name] = done
	return out


## Order-free digest of final buffers (tests: the stored placement is the one placed).
static func placement_digest(items: Dictionary, stones: Dictionary) -> int:
	var d := 0
	for store: Dictionary in [items, stones]:
		for name: String in store:
			for key: Vector3i in store[name]:
				d += hash([name, key, hash(store[name][key])])
	return d


static func built_digest() -> int:
	return placement_digest(_final_items, _final_stones)


## Everything placed as [kind id, position] (tests): rebuilt from the buffers on first use.
static func instance_list() -> Array:
	if instances.is_empty():
		for name: String in _final_items:
			_list_into(name, _final_items[name])
		for name: String in _final_stones:
			var kind := name.split("|")[0]
			_list_into(("stone_" + kind.substr(5)) if kind.begins_with("stone") else kind + "_0", _final_stones[name])
	return instances


static func _list_into(nm: String, per: Dictionary) -> void:
	for key: Vector3i in per:
		var cs := TREE_CHUNK if key.z == 1 else CHUNK
		var cx := (key.x + 0.5) * cs
		var cz := (key.y + 0.5) * cs
		var base := Vector3(cx, ground_y(cx, cz), cz)
		var f: PackedFloat32Array = per[key]
		for i in f.size() / 16:
			instances.append([nm, base + Vector3(f[i * 16 + 3], f[i * 16 + 7], f[i * 16 + 11])])


static var _final_items := {}
static var _final_stones := {}


# --- stones in the turf (r31) -------------------------------------------------------------------

## Stones per m2 by biome: half-buried RockKit boulders (shared, LOD'd meshes), ankle-high, no
## collision. Mossy in the wood and the fen, granite on the open ground, ash by the rift.
const STONES := {"crag": 0.07, "ruin": 0.05, "heath": 0.035, "oldforest": 0.032, "ash": 0.03, "glade": 0.015, "meadow": 0.01, "fen": 0.012, "salt": 0.004}
const STONE_STYLE := {"oldforest": "mossy", "fen": "mossy", "glade": "mossy", "ash": "ash"}
const STONE_SIZES := Emit.STONE_SIZES
const STONE_CELL := 4.0


const PROPS := Emit.PROPS


static func _place_stones(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}                      # mesh key "kind|style|variant" -> Array of [Transform3D, Color]
	if r30:
		return out
	# the old Realm's cells first from `rng` (as before); the new ground's from a stream of its own
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 20261139
	_stone_pass(rng, out, true)
	_stone_pass(rng2, out, false)
	return out


static func _stone_pass(rng: RandomNumberGenerator, out: Dictionary, old: bool) -> void:
	var b := RealmLayout.OLD_BOUNDS if old else RealmLayout.BOUNDS
	var z := b.position.y
	while z < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			if not old and RealmLayout.OLD_BOUNDS.has_point(Vector2(x, z)):
				x += STONE_CELL
				continue
			var w := biome_w(x, z)
			var lk: Array = _lk[_bidx(x, z)]
			var smul := 1.0
			var lstyle := ""
			for e: Array in lk:
				smul = lerpf(smul, float((e[0] as Dictionary).get("stone_mul", 1.0)), float(e[1]))
				if float(e[1]) > 0.5:
					lstyle = String((e[0] as Dictionary).get("style", ""))
			var expect := _rate(STONES, w) * STONE_CELL * STONE_CELL * smul
			expect *= clampf(0.5 + _noise[3].get_noise_2d(x * 0.7, z * 0.7) * 1.6, 0.0, 2.0)     # stony patches
			var n := int(expect)
			if rng.randf() < expect - n:
				n += 1
			for c in n:
				var px := x + rng.randf() * STONE_CELL
				var pz := z + rng.randf() * STONE_CELL
				var k := _idx(px, pz)
				if _ok[k] == 0 or _pd[k] < 1.2 or _sd[k] < 1.0 or _gn[k] < 0.7:
					continue
				# the grid is 1 m: a cell that reads 1.2 or 1.0 can hold ground 0.5 m from the edge, so the near ones are measured exactly
				if (_pd[k] < 2.0 and RealmLayout.path_dist(Vector2(px, pz)) < 1.2) or (_sd[k] < 2.0 and not WorldLanes.site_at(Vector2(px, pz), 1.0).is_empty()):
					continue
				var gy := ground_y(px, pz)
				if gy < WATER_Y + 0.6 and Tables.wet(px, pz):
					continue                            # sunk in the turf, never under the fen's water line
				var best := ""
				var bw := 0.0
				for bio: String in w:
					if float(w[bio]) > bw:
						bw = float(w[bio])
						best = bio
				var style := String(STONE_STYLE.get(best, "granite")) if lstyle == "" else lstyle
				var si := 0 if rng.randf() < 0.78 else 1
				# one rock variant per chunk and style (each variant is a draw call per chunk)
				var key := "stone%d|%s|%d" % [si, style, absi(hash(Vector2i(floori(px / CHUNK), floori(pz / CHUNK)))) % 4]
				var sz: Vector3 = STONE_SIZES[si]
				var sc := rng.randf_range(0.7, 1.3) * Pilot.stone(px, pz)       # the scale pilot: boulders on its ground, and fewer
				var nrm := Vector3(_gnx[k], _gn[k], _gnz[k]).normalized()
				var bas := Basis(Vector3.UP, rng.randf() * TAU)
				bas = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.4).normalized())) * bas
				var pos := Vector3(px, gy - sz.y * sc * rng.randf_range(0.35, 0.55), pz)
				var sxf := Transform3D(bas.scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.1), sc)), pos)
				var stint := _tint(rng, 0.12)
				if not Pilot.keeps(px, pz):
					continue
				_push(out, key, CHUNK, 0, sxf, stint)
				placed["stone"] = int(placed.get("stone", 0)) + 1
			for e: Array in lk:
				var props: Dictionary = (e[0] as Dictionary).get("props", {})
				for kind: String in props:
					_place_prop(rng, out, kind, float(props[kind]) * float(e[1]), String((e[0] as Dictionary).get("style", "granite")), x, z)
			x += STONE_CELL
		z += STONE_CELL


static func _place_prop(rng: RandomNumberGenerator, out: Dictionary, kind: String, rate: float, lstyle: String, x: float, z: float) -> void:
	var pr: Array = PROPS[kind]
	var expect := rate * STONE_CELL * STONE_CELL * clampf(0.5 + _noise[5].get_noise_2d(x * 0.8, z * 0.8) * 1.6, 0.0, 2.0)
	var n := int(expect)
	if rng.randf() < expect - n:
		n += 1
	var sz: Vector3 = pr[1]
	var big := maxf(sz.x, sz.z) * 0.7
	for c in n:
		var px := x + rng.randf() * STONE_CELL
		var pz := z + rng.randf() * STONE_CELL
		var k := _idx(px, pz)
		if _ok[k] == 0 or _pd[k] < 1.5 + big or _sd[k] < 1.2 + big or _gn[k] < 0.75:
			continue
		var gy := ground_y(px, pz)
		if gy < WATER_Y + 0.6 and Tables.wet(px, pz):
			continue
		if _pd[k] < 4.0 + big and RealmLayout.path_dist(Vector2(px, pz)) < 1.5 + big:
			continue
		var style := String(pr[2]) if String(pr[2]) != "" else lstyle
		var key := "%s|%s|%d" % [kind, style, absi(hash(Vector2i(floori(px / CHUNK), floori(pz / CHUNK)))) % 3]
		var sc := rng.randf_range(0.8, 1.2)
		var yaw := rng.randf() * TAU
		var bas := Basis(Vector3.UP, yaw)
		match kind:
			"headstone":
				# every grave faces the mountain (north, -z); old ones lean
				bas = Basis(Vector3.UP, PI + rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, rng.randf_range(-0.22, 0.12))
			"block":
				bas = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
			_:
				var nrm := Vector3(_gnx[k], _gn[k], _gnz[k]).normalized()
				bas = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.5).normalized())) * bas
		var pos := Vector3(px, gy - sz.y * sc * float(pr[3]), pz)
		var xf := Transform3D(bas.scaled(Vector3(sc, sc, sc)), pos)
		var box := xf * AABB(Vector3(-sz.x * 0.5, 0.0, -sz.z * 0.5), sz)
		if _sd[k] < 8.0 and _clash(null, "", Transform3D(), false, box):
			continue
		_push(out, key, CHUNK, 0, xf, _tint(rng, 0.1))
		placed[kind] = int(placed.get(kind, 0)) + 1


static func _prop_mesh(key: String) -> Mesh:
	var parts := key.split("|")
	var kind := parts[0]
	var v := int(parts[2])
	if kind.begins_with("stone"):
		return RockKit.boulder(v, STONE_SIZES[int(kind.substr(5))], parts[1])
	var pr: Array = PROPS[kind]
	match String(pr[0]):
		"slab":
			return RockKit.slab(v, pr[1], parts[1], 0.3 if kind == "headstone" else 0.0, kind == "headstone")
		"cairn":
			return RockKit.cairn(v, pr[1], parts[1])
	return RockKit.boulder(v + 5, pr[1], parts[1])


# --- world detail (Settings.detail via Atmosphere) ---------------------------------------------------

static func apply_detail(host: Node, d: int) -> void:
	Emit.apply_detail(host, d)

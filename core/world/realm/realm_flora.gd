extends RefCounted
## FLORA module of the Realm (docs/REALM_PLAN.md): trees, undergrowth and ground cover over the
## whole map, by biome. Runs after land, rift, bosses, tavern, lore and TerrainStamp.apply, so
## every site, flight, portal and arena is registered and the ground is final.
##
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

const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")

const CHUNK := 24.0                    ## undergrowth chunks
const TREE_CHUNK := 32.0               ## tree chunks
const NEAR_END := 38.0                 ## chunk-origin distance where big trees swap to their @far meshes
const CELL := 1.0                      ## ground sample grid
const UCELL := 2.0                     ## undergrowth grid
const MARGIN := 18.0                   ## trees also grow this far outside BOUNDS (the horizon)
const WATER_Y := -0.9                  ## fen pools (RealmLand)
const SPAWN_CLEAR := 10.0

## tree species: chance per candidate (3.5 m jittered grid) by biome, min spacing (m)
const TREE_P := {
	"oak": {"oldforest": 0.8, "meadow": 0.03, "ruin": 0.07, "glade": 0.05, "heath": 0.012},
	"birch": {"oldforest": 0.09, "meadow": 0.03, "glade": 0.16, "heath": 0.025, "ruin": 0.05, "fen": 0.01},
	"pine": {"oldforest": 0.08, "crag": 0.14, "heath": 0.012, "ash": 0.004},
	"willow": {"fen": 0.2},
	"snag": {"fen": 0.09, "oldforest": 0.035, "ash": 0.02, "ruin": 0.035, "crag": 0.015, "heath": 0.006},
	"sapling": {"oldforest": 0.3, "glade": 0.08, "meadow": 0.012, "fen": 0.04, "ruin": 0.06, "heath": 0.015, "crag": 0.04},
}
const TREE_SPACING := {"oak": 6.2, "birch": 3.2, "pine": 3.6, "willow": 5.5, "snag": 3.0, "sapling": 1.6}

## undergrowth: instances per m2 by biome
## r31 (docs/enshrouded/world.md): layered like an Enshrouded wood -- a grass floor even under the
## oaks, bracken and shrubs thickest at the forest's edges (_under_mod), tall-grass and flower drifts
## on the open ground, and stones in the turf (STONES). Measured with zz/perf_tour --stress=2.
const UNDER := {
	"grass": {"meadow": 6.5, "heath": 3.2, "glade": 3.8, "oldforest": 1.3, "ruin": 3.2, "fen": 1.6, "crag": 1.1, "ash": 0.03},
	"tallgrass": {"meadow": 0.2, "heath": 0.32, "fen": 0.28, "ruin": 0.2, "glade": 0.09, "oldforest": 0.05},
	"flowers": {"meadow": 0.45, "heath": 0.2, "glade": 0.48, "ruin": 0.14, "oldforest": 0.015},
	"heather": {"heath": 0.42, "crag": 0.2, "meadow": 0.012, "ruin": 0.03},
	"fern": {"oldforest": 0.42, "glade": 0.16, "fen": 0.04, "ruin": 0.07, "meadow": 0.006},
	"shrub": {"oldforest": 0.075, "meadow": 0.01, "heath": 0.018, "ruin": 0.035, "glade": 0.022, "fen": 0.016, "crag": 0.016},
	"bramble": {"oldforest": 0.022, "ruin": 0.03, "fen": 0.005},
	"litter": {"oldforest": 0.22, "glade": 0.025, "ruin": 0.045, "meadow": 0.005},
	"moss": {"oldforest": 0.14, "fen": 0.1, "glade": 0.05, "crag": 0.04, "ruin": 0.04},
	"mushroom": {"oldforest": 0.035, "fen": 0.015, "glade": 0.012},
	"glowcap": {"oldforest": 0.004, "glade": 0.02, "fen": 0.005},
	"reeds": {"fen": 0.01},
	"cattail": {"fen": 0.004},
	"log": {"oldforest": 0.006, "fen": 0.003, "glade": 0.002},
	"stump": {"oldforest": 0.005, "fen": 0.004, "meadow": 0.001, "heath": 0.001, "ash": 0.001},
	"roots": {"oldforest": 0.008},
}
## The r30 table, kept for A/B perf runs: `-- --no-r31-flora` builds the wood as it was (this table,
## no edge crowding, no stones).
const UNDER_R30 := {
	"grass": {"meadow": 6.5, "heath": 2.8, "glade": 3.6, "oldforest": 0.7, "ruin": 3.0, "fen": 1.3, "crag": 0.9, "ash": 0.03},
	"tallgrass": {"meadow": 0.1, "heath": 0.22, "fen": 0.18, "ruin": 0.14, "glade": 0.06, "oldforest": 0.03},
	"flowers": {"meadow": 0.32, "heath": 0.14, "glade": 0.4, "ruin": 0.1},
	"heather": {"heath": 0.38, "crag": 0.16, "meadow": 0.012, "ruin": 0.03},
	"fern": {"oldforest": 0.3, "glade": 0.12, "fen": 0.03, "ruin": 0.05, "meadow": 0.004},
	"shrub": {"oldforest": 0.05, "meadow": 0.006, "heath": 0.01, "ruin": 0.025, "glade": 0.015, "fen": 0.01, "crag": 0.012},
	"bramble": {"oldforest": 0.018, "ruin": 0.025, "fen": 0.004},
	"litter": {"oldforest": 0.2, "glade": 0.02, "ruin": 0.04, "meadow": 0.005},
	"moss": {"oldforest": 0.1, "fen": 0.09, "glade": 0.04, "crag": 0.03, "ruin": 0.03},
}
static var r30 := false                ## --no-r31-flora (A/B)
## Tree-free rounds [Vector2 centre, radius] other modules ask for before the flora runs (r31: the
## places' vistas, realm_pois.gd). Undergrowth still grows there; only trees keep out.
static var tree_clear: Array = []


static func _under_table(sp: String) -> Dictionary:
	return UNDER_R30[sp] if r30 and UNDER_R30.has(sp) else UNDER[sp]

## species groups: visibility range end (0 = none: the camera far plane, 82 m, ends them),
## shadows, keep-off path distance (m from the path edge), clearance from sites
const STYLE := {
	"grass": [38.0, false, 1.0, 0.6], "tallgrass": [40.0, false, 3.0, 0.8], "flowers": [36.0, false, 3.0, 0.6],
	"heather": [38.0, false, 3.0, 0.6], "fern": [44.0, false, 3.0, 1.0], "shrub": [58.0, false, 3.5, 1.5],
	"bramble": [58.0, false, 3.5, 2.0], "litter": [32.0, false, 3.0, 0.8], "moss": [34.0, false, 3.0, 0.8],
	"mushroom": [26.0, false, 3.0, 0.8], "glowcap": [46.0, false, 3.0, 0.8], "reeds": [52.0, false, 3.0, 0.8],
	"cattail": [52.0, false, 3.0, 0.8], "log": [64.0, true, 3.5, 3.0], "stump": [56.0, false, 3.0, 1.5],
	"roots": [50.0, false, 3.0, 1.5],
	"stone": [44.0, false, 1.2, 1.0],                                  # r31 stones in the turf (_place_stones)
	"oak": [0.0, true, 3.5, 0.0], "birch": [0.0, true, 3.0, 0.0], "pine": [0.0, true, 3.0, 0.0],
	"willow": [0.0, true, 3.0, 0.0], "snag": [0.0, true, 3.0, 0.0], "sapling": [60.0, false, 3.0, 1.5],
}

static var placed := {}                ## species -> instance count (last build)
static var trees: Array = []           ## [Vector3 base, kind id, trunk r, height]
static var instances: Array = []       ## [kind id, Vector3 pos] of everything (tests)
static var build_ms := 0
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
static var _cover := PackedFloat32Array()       # canopy cover 0..1 (UCELL grid)
static var _bw: Array = []                      # biome weights per 4 m cell: Dictionary
static var _bnx := 0
static var _bnz := 0
static var _noise: Array[FastNoiseLite] = []


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	placed.clear()
	rejects.clear()
	r30 = "--no-r31-flora" in OS.get_cmdline_user_args()
	trees.clear()
	instances.clear()
	var old := root.get_node_or_null("RealmFlora")
	if old:
		old.free()
	await root.get_tree().physics_frame
	var space := (root as Node3D).get_world_3d().direct_space_state
	_noises()
	var area := RealmLayout.BOUNDS.grow(MARGIN)
	_x0 = area.position.x
	_z0 = area.position.y
	_nx = int(area.size.x / CELL) + 1
	_nz = int(area.size.y / CELL) + 1
	_sample(space)
	var t1 := Time.get_ticks_msec()
	_keepout(root)
	_find_tall_sites(space)
	_space = space
	_biomes()
	var t2 := Time.get_ticks_msec()
	var items := {}                     # kind id -> Array of [Transform3D, Color]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	_place_trees(space, rng, items)
	var t3 := Time.get_ticks_msec()
	_place_under(rng, items)
	var srng := RandomNumberGenerator.new()
	srng.seed = 20261105
	var stone_items := _place_stones(srng)
	var t4 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "RealmFlora"
	root.add_child(host)
	var stats := _emit(host, items)
	stats.x += _emit_stones(host, stone_items)
	build_ms = Time.get_ticks_msec() - t0
	print("FLORA ground %d ms, field %d ms, trees %d ms, under %d ms, nodes %d ms; %d multimeshes, %d colliders" % [
		t1 - t0, t2 - t1, t3 - t2, t4 - t3, Time.get_ticks_msec() - t4, stats.x, stats.y])
	var keys := placed.keys()
	keys.sort()
	var line := ""
	for k: String in keys:
		line += "%s %d  " % [k, placed[k]]
	print("FLORA counts: ", line)
	print("FLORA tree rejects: ", rejects)
	if OS.get_cmdline_user_args().has("--flora-sites"):
		for st: Dictionary in WorldLanes.sites:
			print("FLORA site %-24s %s floor %.1f" % [st.name, st.rect, st.floor_y])
		for l: Array in WorldLanes.extra_lanes:
			print("FLORA lane ", l[0], " w ", l[2])


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
	# keep-outs
	# sites by their bounding rect, as WorldLanes.intrudes and zz/audit judge them (a round terrace
	# or a diagonal flight claims its whole box)
	for st: Dictionary in WorldLanes.sites:
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
	_disc_field(_sd, Vector2(RealmLayout.OSSUARY_GATE.x, RealmLayout.OSSUARY_GATE.z), 5.0, BAND)
	# lava and anything that is not the terrain itself
	for k in n:
		if _gy[k] < RealmLayout.LAVA_Y + 2.5 or _ok[k] == 0:
			_sd[k] = 0.0


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
			for r: Dictionary in RealmLayout.REGIONS:
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

static func _place_trees(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, items: Dictionary) -> void:
	var grid := {}                      # Vector2i(4 m) -> Array of [Vector2, spacing]
	var cands: Array = []
	var step := 3.5
	var area := RealmLayout.BOUNDS.grow(MARGIN)
	var z := area.position.y
	while z < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			cands.append(Vector2(x + rng.randf_range(0.0, step), z + rng.randf_range(0.0, step)))
			x += step
		z += step
	# big trees first so the small ones fill round them
	var order := ["oak", "willow", "pine", "birch", "snag", "sapling"]
	var cover := {}                     # Vector2i(UCELL) -> cover
	for sp: String in order:
		var spacing: float = TREE_SPACING[sp]
		var ids := TreeGen.ids(sp)
		for c: Vector2 in cands:
			var w := biome_w(c.x, c.y)
			var p := _rate(TREE_P[sp], w)
			if p <= 0.0:
				continue
			p *= _tree_mod(sp, c, w)
			if rng.randf() >= p:
				continue
			var at := c + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			var k := _idx(at.x, at.y)
			if _gn[k] < (0.72 if sp != "pine" else 0.62):
				continue
			var y := _gy[k]
			if sp == "willow" or sp == "sapling" or sp == "snag":
				if y < WATER_Y + 0.15:
					continue
			elif y < WATER_Y + 0.35:
				continue
			var id: String = _variant(ids, at.x, at.y, TREE_CHUNK, 2, rng)
			if sp == "willow" and rng.randf() < 0.55:
				id = "willow_2"                       # the fen's willows are mostly dead
			if sp == "snag" and _rate({"ash": 1.0}, w) > 0.3:
				id = "snag_2"                         # scorched at the rift
			elif sp == "snag" and id == "snag_2" and rng.randf() < 0.7:
				id = "snag_%d" % rng.randi_range(0, 1)
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
			if gy < WATER_Y + 0.05 or RealmLayout.path_dist(at) < float(st[2]) + float(d.r):
				continue
			var s := rng.randf_range(0.85, 1.15)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.92, 1.08), s))
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
			# a vista round a place (tree_clear): tested last, after every draw this candidate makes,
			# so the rest of the wood keeps the exact layout it had without it
			var cleared := false
			for tc: Array in tree_clear:
				if at.distance_to(tc[0]) < float(tc[1]) + float(d.spread) * 0.6:
					cleared = true
			if cleared:
				rejects[sp + " vista"] = int(rejects.get(sp + " vista", 0)) + 1
				continue
			var key := Vector2i(floori(at.x / 4.0), floori(at.y / 4.0))
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append([at, spacing])
			_add(items, id, Transform3D(basis, pos), _tint(rng, 0.1))
			if bool(d.tall):
				trees.append([pos, id, float(d.r) * s, float(d.h) * s])
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
static func _clash(space: PhysicsDirectSpaceState3D, id: String, xf: Transform3D, tree: bool) -> bool:
	var la := mesh_aabb(id)
	var full := xf * la
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
		var fr := Rect2(full.position.x, full.position.z, full.size.x, full.size.z)
		for st: Dictionary in _tall_sites:
			if (st.rect as Rect2).grow(0.5).intersects(fr) and full.end.y > float(st.floor_y) - 1.0:
				return true
	for wb in boxes:
		var r := Rect2(wb.position.x, wb.position.z, wb.size.x, wb.size.z)
		for st: Dictionary in WorldLanes.sites:
			if (st.rect as Rect2).grow(0.4).intersects(r) and wb.end.y > float(st.floor_y) - 1.0 and wb.position.y < float(st.floor_y) + 6.4:
				return true
		for p: Dictionary in WorldLanes.portals:
			var pb: Array = WorldLanes.portal_box(p)
			var ext: Vector3 = pb[1]
			var box := (pb[0] as Transform3D) * AABB(-ext - Vector3(0.3, 0.3, 0.3), ext * 2.0 + Vector3(0.6, 0.6, 0.6))
			if box.intersects(wb):
				return true
		if space != null and WorldLanes.intrudes(space, wb, 0.3) != "":
			return true
	return false


static func _tree_mod(sp: String, c: Vector2, w: Dictionary) -> float:
	var n0 := _noise[0].get_noise_2d(c.x, c.y)            # stands and clearings
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

static func _place_under(rng: RandomNumberGenerator, items: Dictionary) -> void:
	var kinds := UNDER.keys()
	var ids := {}
	for sp: String in kinds:
		ids[sp] = TreeGen.ids(sp)
		var w := 0.0
		for id: String in ids[sp]:
			w = maxf(w, float(TreeGen.kind(id).spread))
		spreads[sp] = minf(w, 3.0)
	var b := RealmLayout.BOUNDS
	var z := b.position.y
	while z < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			_under_cell(rng, items, kinds, ids, x, z)
			x += UCELL
		z += UCELL


static var spreads := {}               ## species -> widest variant footprint radius (m)


static func _under_cell(rng: RandomNumberGenerator, items: Dictionary, kinds: Array, ids: Dictionary, x: float, z: float) -> void:
	var k := _idx(x + UCELL * 0.5, z + UCELL * 0.5)
	if _sd[k] < 0.3 or _pd[k] < 0.0:
		return
	var w := biome_w(x, z)
	var cov := cover_at(x, z)
	var y := _gy[k]
	var shore := y < WATER_Y + 0.3 and y > WATER_Y - 0.35
	var wet := y < WATER_Y + 0.15
	for sp: String in kinds:
		var rate := _rate(_under_table(sp), w)
		if sp == "reeds" or sp == "cattail":
			if shore and float(w.get("fen", 0.0)) > 0.2:
				rate += (0.3 if sp == "reeds" else 0.1) * clampf(_noise[2].get_noise_2d(x * 1.7, z * 1.7) * 3.0 + 0.2, 0.0, 1.5)
		if rate <= 0.0:
			continue
		rate *= _under_mod(sp, x, z, cov)
		var expect := rate * UCELL * UCELL
		var n := int(expect)
		if rng.randf() < expect - n:
			n += 1
		for c in n:
			var px := x + rng.randf() * UCELL
			var pz := z + rng.randf() * UCELL
			var kk := _idx(px, pz)
			var st: Array = STYLE[sp]
			if _pd[kk] < float(st[2]) or _sd[kk] < float(st[3]) + spreads[sp] or _ok[kk] == 0:
				continue
			if _pd[kk] < float(st[2]) + 1.5 and RealmLayout.path_dist(Vector2(px, pz)) < float(st[2]):
				continue                                   # the grid is 1 m: exact near the edge
			var gy := ground_y(px, pz)
			if gy < WATER_Y + 0.12 and not (sp == "reeds" or sp == "cattail"):
				continue
			if (sp == "reeds" or sp == "cattail") and gy < WATER_Y - 0.4:
				continue
			if _gn[kk] < 0.6 and sp != "moss":
				continue
			var nrm := Vector3(_gnx[kk], _gn[kk], _gnz[kk]).normalized()
			var list: Array = ids[sp]
			var id: String = _variant(list, px, pz, CHUNK, 1, rng)
			var xf := _plant_xf(rng, sp, Vector3(px, gy, pz), nrm)
			if (_sd[kk] < 8.0 or _pd[kk] < 4.0) and _clash(_space if _pd[kk] < 4.0 else null, id, xf, false):
				continue
			_add(items, id, xf, _tint(rng, 0.14 if sp != "flowers" else 0.05))


static func _under_mod(sp: String, x: float, z: float, cov: float) -> float:
	var m := 1.0
	match sp:
		"grass", "flowers", "heather", "tallgrass":
			m *= 1.0 - 0.75 * cov
			m *= clampf(0.85 + _noise[1].get_noise_2d(x, z) * 0.7, 0.35, 1.4)
		"fern":
			m *= 0.35 + 1.1 * cov
			m *= clampf(0.6 + _noise[2].get_noise_2d(x, z) * 1.5, 0.0, 1.8)
			m *= 1.0 + 0.8 * _edge(cov)
		"litter", "moss", "mushroom", "roots":
			m *= 0.25 + 1.3 * cov
			m *= clampf(0.6 + _noise[4].get_noise_2d(x, z) * 1.3, 0.0, 1.8)
		"shrub", "bramble":
			m *= clampf(0.4 + _noise[5].get_noise_2d(x, z) * 1.8, 0.0, 2.2)
			m *= 1.0 + 1.6 * _edge(cov)
		"glowcap":
			m *= 0.3 + cov
		"flowers":
			pass
	if sp == "flowers":
		m *= clampf(0.3 + _noise[3].get_noise_2d(x, z) * 2.0, 0.0, 2.0)
	# the meadow round the spawn and the tavern stays walkable and open: grass only near them
	var sd := Vector2(x, z).distance_to(Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z))
	if sd < 18.0 and sp in ["shrub", "bramble", "tallgrass", "log", "stump"]:
		m *= 0.1
	return m


## 1 where the canopy is broken (a wood's edge, a clearing's rim), 0 in the open and in deep shade:
## undergrowth crowds the light at a forest's edge.
static func _edge(cov: float) -> float:
	if r30:
		return 0.0
	return clampf(1.0 - absf(cov - 0.35) / 0.3, 0.0, 1.0)


static func _plant_xf(rng: RandomNumberGenerator, sp: String, p: Vector3, nrm: Vector3) -> Transform3D:
	var yaw := rng.randf() * TAU
	var s := rng.randf_range(0.8, 1.25)
	var up := Vector3.UP
	match sp:
		"litter", "moss", "roots":
			up = nrm
		"log":
			up = nrm.lerp(Vector3.UP, 0.3).normalized()
		_:
			up = nrm.lerp(Vector3.UP, 0.7).normalized()
	var fwd := Vector3(cos(yaw), 0, sin(yaw))
	var rt := up.cross(fwd).normalized()
	fwd = rt.cross(up).normalized()
	var basis := Basis(rt, up, fwd)
	if sp == "log":
		s = rng.randf_range(0.85, 1.1)
	elif sp in ["reeds", "cattail", "tallgrass"]:
		basis = basis.scaled(Vector3(1, rng.randf_range(0.85, 1.25), 1))
	var sink := 0.0
	if sp in ["log", "stump", "roots"]:
		sink = -0.08
	return Transform3D(basis.scaled(Vector3(s, s, s)), p + up * sink)


## Each chunk draws only `per` variants of a species (every variant is a draw call per chunk);
## neighbouring chunks pick different ones, so the variety is still there across the wood.
static func _variant(list: Array, x: float, z: float, csize: float, per: int, rng: RandomNumberGenerator) -> String:
	if list.size() <= per:
		return list[rng.randi() % list.size()]
	var h := absi(hash(Vector2i(floori(x / csize), floori(z / csize))) + hash(list[0]))
	return list[(h + rng.randi() % per) % list.size()]


static func _tint(rng: RandomNumberGenerator, amt: float) -> Color:
	var v := rng.randf_range(1.0 - amt, 1.0 + amt * 0.6)
	return Color(v * rng.randf_range(0.96, 1.04), v, v * rng.randf_range(0.96, 1.04), 1.0)


static func _add(items: Dictionary, id: String, xf: Transform3D, col: Color) -> void:
	if not items.has(id):
		items[id] = []
	(items[id] as Array).append([xf, col])
	var sp := id.substr(0, id.rfind("_"))
	placed[sp] = int(placed.get(sp, 0)) + 1
	instances.append([id, xf.origin])


# --- stones in the turf (r31) -------------------------------------------------------------------

## Stones per m2 by biome: half-buried RockKit boulders (shared, LOD'd meshes), ankle-high, no
## collision. Mossy in the wood and the fen, granite on the open ground, ash by the rift.
const STONES := {"crag": 0.07, "ruin": 0.05, "heath": 0.035, "oldforest": 0.032, "ash": 0.03, "glade": 0.015, "meadow": 0.01, "fen": 0.012}
const STONE_STYLE := {"oldforest": "mossy", "fen": "mossy", "glade": "mossy", "ash": "ash"}
const STONE_SIZES := [Vector3(0.55, 0.34, 0.48), Vector3(0.9, 0.5, 0.75)]
const STONE_RANGE := 44.0
const STONE_CELL := 4.0


static func _place_stones(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}                      # mesh key "style|variant|size" -> Array of [Transform3D, Color]
	if r30:
		return out
	var b := RealmLayout.BOUNDS
	var z := b.position.y
	while z < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			var w := biome_w(x, z)
			var expect := _rate(STONES, w) * STONE_CELL * STONE_CELL
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
				var gy := ground_y(px, pz)
				if gy < WATER_Y + 0.6:
					continue                            # sunk in the turf, never under the fen's water line
				var best := ""
				var bw := 0.0
				for bio: String in w:
					if float(w[bio]) > bw:
						bw = float(w[bio])
						best = bio
				var style := String(STONE_STYLE.get(best, "granite"))
				var si := 0 if rng.randf() < 0.78 else 1
				# one rock variant per chunk and style (each variant is a draw call per chunk)
				var key := "%s|%d|%d" % [style, absi(hash(Vector2i(floori(px / CHUNK), floori(pz / CHUNK)))) % 4, si]
				var sz: Vector3 = STONE_SIZES[si]
				var sc := rng.randf_range(0.7, 1.3)
				var nrm := Vector3(_gnx[k], _gn[k], _gnz[k]).normalized()
				var bas := Basis(Vector3.UP, rng.randf() * TAU)
				bas = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.4).normalized())) * bas
				var pos := Vector3(px, gy - sz.y * sc * rng.randf_range(0.35, 0.55), pz)
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append([Transform3D(bas.scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.1), sc)), pos), _tint(rng, 0.12)])
				placed["stone"] = int(placed.get("stone", 0)) + 1
				instances.append(["stone_%d" % si, pos])
			x += STONE_CELL
		z += STONE_CELL
	return out


static func _emit_stones(host: Node3D, out: Dictionary) -> int:
	var n_mm := 0
	for key: String in out:
		var parts := key.split("|")
		var mesh := RockKit.boulder(int(parts[1]), STONE_SIZES[int(parts[2])], parts[0])
		var per := {}
		for e: Array in out[key]:
			var xf: Transform3D = e[0]
			var ck := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
			if not per.has(ck):
				per[ck] = []
			(per[ck] as Array).append(e)
		for ck: Vector2i in per:
			var list: Array = per[ck]
			var cx := (ck.x + 0.5) * CHUNK
			var cz := (ck.y + 0.5) * CHUNK
			var ch := Node3D.new()
			ch.name = "Stones_%d_%d" % [ck.x, ck.y]
			host.add_child(ch)
			ch.position = Vector3(cx, ground_y(cx, cz), cz)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				var xf: Transform3D = list[i][0]
				mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - ch.position))
				mm.set_instance_color(i, list[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Flora_stone_s"
			mmi.multimesh = mm
			mmi.set_meta("site_owned", true)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.extra_cull_margin = 1.0
			mmi.lod_bias = 0.5
			mmi.visibility_range_end = STONE_RANGE
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.add_to_group(Groups.CULL_SKIP)
			mmi.set_meta(&"flora", ["stone", "s", false, STONE_RANGE, list.size(), 0])
			ch.add_child(mmi)
			n_mm += 1
	return n_mm


# --- nodes ---------------------------------------------------------------------------------------

static func _emit(host: Node3D, items: Dictionary) -> Vector2i:
	var chunks := {}                    # Vector3i(x, z, tall) -> Node3D
	var bodies := {}                    # Vector3i -> StaticBody3D
	var n_mm := 0
	var n_col := 0
	var solid_lod := {}
	for id: String in items:
		var d: Dictionary = TreeGen.kind(id)
		var sp := id.substr(0, id.rfind("_"))
		var st: Array = STYLE[sp]
		var per := {}                   # chunk -> Array
		var csize := TREE_CHUNK if bool(d.tall) else CHUNK
		var tag := 1 if bool(d.tall) else 0
		for e: Array in items[id]:
			var xf: Transform3D = e[0]
			var key := Vector3i(floori(xf.origin.x / csize), floori(xf.origin.z / csize), tag)
			if not per.has(key):
				per[key] = []
			(per[key] as Array).append(e)
		var meshes: Array = []          # [mesh, tag, range begin, range end]
		var swap := bool(d.tall) and sp in TreeGen.FAR
		var near_end := NEAR_END if swap else float(st[0])
		if d.solid != null:
			if not solid_lod.has(id):
				solid_lod[id] = MeshChunks.with_lods(d.solid)
			meshes.append([solid_lod[id], "s", 0.0, near_end])
		if d.cards != null:
			meshes.append([d.cards, "c", 0.0, near_end])
		if swap:
			var fd: Dictionary = TreeGen.kind(id + "@far")
			if fd.solid != null:
				meshes.append([MeshChunks.with_lods(fd.solid), "fs", NEAR_END, 0.0])
			if fd.cards != null:
				meshes.append([fd.cards, "fc", NEAR_END, 0.0])
		for key: Vector3i in per:
			var ch: Node3D = chunks.get(key)
			if ch == null:
				ch = Node3D.new()
				ch.name = "%s_%d_%d" % ["Trees" if key.z == 1 else "Chunk", key.x, key.y]
				host.add_child(ch)
				var cx := (key.x + 0.5) * csize
				var cz := (key.y + 0.5) * csize
				ch.position = Vector3(cx, ground_y(cx, cz), cz)
				chunks[key] = ch
			var list: Array = per[key]
			if not bool(d.tall):
				# undergrowth in random order, so a lower visible_instance_count (world detail,
				# apply_detail) thins the whole chunk evenly instead of dropping one corner
				var srng := RandomNumberGenerator.new()
				srng.seed = hash([id, key])
				for k in range(list.size() - 1, 0, -1):
					var r := srng.randi_range(0, k)
					var tmp: Variant = list[k]
					list[k] = list[r]
					list[r] = tmp
			var buf := PackedFloat32Array()
			buf.resize(list.size() * 16)
			var o := 0
			for e: Array in list:
				var xf: Transform3D = e[0]
				var b := xf.basis
				var org := xf.origin - ch.position
				var c: Color = e[1]
				buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = org.x
				buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = org.y
				buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = org.z
				buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
				o += 16
			for m: Array in meshes:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = m[0]
				mm.instance_count = list.size()
				mm.buffer = buf
				mm.set_meta("cpu_buffer", buf)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Flora_%s_%s" % [id, m[1]]
				mmi.multimesh = mm
				mmi.set_meta("site_owned", true)        # placed clear of sites already: cull_scatter skips it
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(st[1]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if m[1] == "fs" or m[1] == "fc":
					# far trees start 38 m from their chunk centre; moon shadows fade out from ~23 m
					# and end at 30 m (LightPolicy), so a far tree's shadow is never seen, but it was
					# drawn into both shadow splits every frame
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for a in OS.get_cmdline_user_args():           # perf probes: --flora-hide=oak,grass,s,c
					if a.begins_with("--flora-hide=") and (sp in a.trim_prefix("--flora-hide=").split(",") or m[1] in a.trim_prefix("--flora-hide=").split(",")):
						mmi.visible = false
				mmi.extra_cull_margin = 1.5
				if m[1] == "s" or m[1] == "fs":
					mmi.lod_bias = 0.45            # trunks and branches simplify early; cards never do
				var rb: float = m[2]
				var re: float = m[3]
				if swap:
					# near and far meshes hand over at one distance with the same hysteresis
					mmi.visibility_range_begin = rb
					mmi.visibility_range_begin_margin = 3.0 if rb > 0.0 else 0.0
					mmi.visibility_range_end = re
					mmi.visibility_range_end_margin = 3.0 if re > 0.0 else 0.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				elif re > 0.0:
					_set_range(mmi, m[1], re)
				mmi.add_to_group(Groups.CULL_SKIP)
				mmi.set_meta(&"flora", [sp, m[1], bool(d.tall), re, list.size(), int(mmi.cast_shadow)])
				ch.add_child(mmi)
				n_mm += 1
			# collision: tall trunks, logs, stumps
			var solid_r: float = d.r
			if solid_r > 0.0 and ((bool(d.tall) and float(d.h) > 4.0) or sp == "log" or sp == "stump"):
				var body: StaticBody3D = bodies.get(key)
				if body == null:
					body = StaticBody3D.new()
					body.name = "FloraBody"
					body.collision_layer = Layers.WORLD
					body.collision_mask = 0
					ch.add_child(body)
					bodies[key] = body
				for e: Array in list:
					var xf: Transform3D = e[0]
					var sc := xf.basis.get_scale().x
					var cs := CollisionShape3D.new()
					if sp == "log":
						var bx := BoxShape3D.new()
						bx.size = Vector3(float(d.spread) * 2.0 * sc, solid_r * 1.6 * sc, solid_r * 1.6 * sc)
						cs.shape = bx
						cs.transform = Transform3D(xf.basis.orthonormalized(), xf.origin - ch.position + xf.basis.y.normalized() * solid_r * 0.55 * sc)
					else:
						var cy := CylinderShape3D.new()
						var hh := 3.5 if sp != "stump" else float(d.h) * sc
						cy.radius = solid_r * sc * (0.95 if sp != "stump" else 1.0)
						cy.height = hh
						cs.shape = cy
						cs.position = xf.origin - ch.position + Vector3(0, hh * 0.5, 0)
					body.add_child(cs)
					n_col += 1
	return Vector2i(n_mm, n_col)


## Undergrowth range `re` (chunk-origin distance where it starts to fade, as before). Cards (`c`)
## fade by thinning out plant by plant over the next 6 m (realm_foliage.gdshader, instance uniform
## fade_end) and the chunk is culled at re + 6 m with no engine fade. The engine's FADE_SELF drew a
## fading chunk alpha-blended (transparent pass, no depth prepass, every overlapping card shaded):
## standing where dense grass chunks sat in their fade band cost up to ~6 ms at 4x pixels at the hub.
## Solid pieces (stumps, logs, caps) are sparse and keep the engine fade.
const FADE_BAND := 6.0                 ## realm_foliage.gdshader thins over fade_end .. fade_end + 6


static func _set_range(mmi: MultiMeshInstance3D, tag: String, re: float) -> void:
	if tag == "c":
		mmi.set_instance_shader_parameter(&"fade_end", re)
		mmi.visibility_range_end = re + FADE_BAND
		mmi.visibility_range_end_margin = 0.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	else:
		mmi.visibility_range_end = re
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


# --- world detail (Settings.detail via Atmosphere) ---------------------------------------------------

## Undergrowth share kept and range scale per detail level (0 low, 1 medium, 2 high). Medium is the
## look as built. Low keeps 60 % of the undergrowth (evenly: instance order is shuffled per chunk)
## and pulls its ranges in by a fifth; trees keep every instance, their leaf cards stop casting.
const DETAIL_DENSITY := [0.6, 1.0, 1.0]
const DETAIL_RANGE := [0.8, 1.0, 1.12]


static func apply_detail(host: Node, d: int) -> void:
	if host == null:
		return
	d = clampi(d, 0, 2)
	if int(host.get_meta(&"detail", -1)) == d:
		return
	host.set_meta(&"detail", d)
	for n in host.find_children("Flora_*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var f: Array = mmi.get_meta(&"flora", [])
		if f.is_empty() or mmi.multimesh == null:
			continue
		var tall: bool = f[2]
		var re: float = f[3]
		if not tall:
			mmi.multimesh.visible_instance_count = -1 if d >= 1 else maxi(1, int(round(float(f[4]) * DETAIL_DENSITY[d])))
			if re > 0.0:
				_set_range(mmi, String(f[1]), re * DETAIL_RANGE[d])
		elif f[1] == "c" or f[1] == "fc":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if d == 0 else (f[5] as int)

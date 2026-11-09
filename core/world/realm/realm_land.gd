extends RefCounted
## RealmLand: the Realm's ground (docs/REALM_PLAN.md, module "land"). Replaces the baked hub terrain
## (Zone/Terrain + Zone/TerrainBody) at runtime with a larger, detailed land over RealmLayout.BOUNDS
## plus a horizon ring out to RealmLayout.OUTER.
##
## Heights, in order (per 2 m grid vertex):
##   1 RealmLayout.macro_height + detail (ridged/eroded hills, meadow undulation, fen hummocks,
##     horizon ridges); hollows are floored (no stray ponds) and fen pools kept <= 0.55 m deep
##   2 the PATHS are levelled across (flat at their smoothed centreline profile) with soft shoulders
##   3 flat at the spawn brazier (r 9) and round the tavern site
##   4 the kept core (rift rect, Ossuary AABB, summit circle) takes the OLD baked heights exactly,
##     blended over KEEP_FALL metres outside them
##   5 fen_descent is cut down to the Ossuary gate's level (it may override the blend band)
## Ground material: art/materials/realm_ground.tres (world/realm/realm_ground.gdshader), biome
## weights in vertex COLOR / UV / UV2 (see the shader header). Pools: one "FenWater" mesh at WATER_Y.
##
## Node contract: Zone/Terrain (MeshInstance3D, ONE regular 2 m grid) and Zone/TerrainBody
## (StaticBody3D, layer WORLD, one ConcavePolygonShape3D of the same triangles), so TerrainStamp,
## SeatProps and WorldLanes find and edit them by name. Horizon ring: Zone/TerrainRing{N,S,E,W}
## (no collision); Zone/RealmBounds holds invisible walls just outside BOUNDS.
##
## API for other modules (load this script by path; no class_name by rule):
##   height_at(x, z)        designed ground height before site stamps (bilinear, BOUNDS + 10 m)
##   old_height_at(x, z)    the old baked terrain's height (kept core reference), NAN outside it
##   biome_weights(x, z)    {"meadow", "loam", "mud", "ash", "heath", "crag", "ruin", "salt"} -> 0..1
##   in_water(x, z)         true where a fen pool covers the ground; WATER_Y is its surface
##   keep_weight(x, z)      1 inside the kept core, fading to 0 over KEEP_FALL

const STEP := 2.0
## the grid covers BOUNDS + 12 m (BOUNDS x -260..260, z -150..240); the ring covers OUTER on a
## 4 m lattice that the grid's outer rows land on (GX0 - RX0 and GZ0 - RZ0 are multiples of 4).
const GX0 := -272.0
const GZ0 := -160.0
const GNX := 273                      ## x -272 .. 272
const GNZ := 207                      ## z -160 .. 252
const RSTEP := 4.0
const RX0 := -352.0
const RZ0 := -240.0
const RNX := 177                      ## x -352 .. 352
const RNZ := 144                      ## z -240 .. 332
const KEEP_FALL := 15.0
const WATER_Y := -0.9
const POOL_DEPTH := 0.55
const SPAWN_R := 9.0
const SPAWN_FALL := 12.0
const SPAWN_Y := -0.02
const TAVERN_FLAT := Rect2(8.5, 24.0, 21.5, 12.4)    ## TAVERN + its east yard, a little margin
const TAVERN_FALL := 7.0
const SUMMIT_C := Vector2(0.0, -95.0)
const SUMMIT_R := 30.0
const MAT := "res://art/materials/realm_ground.tres"
const WATER_MAT := "res://art/materials/realm_ground_water.tres"
## Paths whose profile is pinned at their last point (and may cut into the keep blend band).
const PATH_PIN := {"fen_descent": [4.0, true], "rift_rim": [0.4, false]}
const BIOMES := ["meadow", "loam", "mud", "ash", "heath", "crag", "ruin", "salt"]
const NB := 8                          ## biome weights ("salt", the White Pans, is analytic in the ground shader: salt_rect)
const BIOME_OF := {"meadow": 0, "oldforest": 1, "fen": 2, "ash": 3, "heath": 4, "crag": 5, "ruin": 6, "salt": 7, "glade": 0}

static var _h := PackedFloat32Array()           ## final designed heights (GNX * GNZ)
static var _water := PackedByteArray()          ## per grid cell: 1 = pool
static var _old := PackedFloat32Array()
static var _old_nx := 0
static var _old_nz := 0
static var _old_x0 := 0.0
static var _old_z0 := 0.0
static var _old_step := 2.0
static var _n_roll: FastNoiseLite
static var _n_ridge: FastNoiseLite
static var _n_fine: FastNoiseLite
static var _n_patch: FastNoiseLite
const Zones := preload("res://core/world/realm/dress_zones.gd")
static var _n_gully: FastNoiseLite
static var _n_step: FastNoiseLite
static var _wear_g := PackedFloat32Array()     ## path wear per grid vertex
static var _rift_r := Rect2(-30, -118, 60, 106)
static var _oss_r := Rect2(2, -110, 30, 88)
static var _profiles: Array = []                ## per path: {id, w, pts (resampled), s, prof, pin, over}


# ------------------------------------------------------------------------------------------ build

static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var zone := root.get_node_or_null("Zone") as Node3D
	if zone == null:
		push_warning("RealmLand: no Zone node")
		return
	var old_mi := zone.get_node_or_null("Terrain") as MeshInstance3D
	var old_body := zone.get_node_or_null("TerrainBody") as StaticBody3D
	if old_mi != null and old_mi.mesh != null:
		_sample_old(old_mi)
	if old_mi != null:
		old_mi.name = "TerrainOld"
		old_mi.visible = false
	if old_body != null:
		old_body.name = "TerrainBodyOld"
		old_body.collision_layer = 0
		for cs in old_body.find_children("*", "CollisionShape3D", true, false):
			(cs as CollisionShape3D).disabled = true
	_init_noise()
	for r: Dictionary in RealmLayout.REGIONS:
		if r.id == "rift":
			_rift_r = r.rect
	var ob := RealmLayout.OSSUARY
	_oss_r = Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z)
	RealmLayout.prepare()
	_make_profiles()
	_heights()
	var t1 := Time.get_ticks_msec()
	var terrain := _terrain_mesh()
	terrain.name = "Terrain"
	terrain.layers = LightPolicy.NO_FIRE_LAYER       # seen, lit and moon-shadowed as before; not in the fire shadow
	zone.add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces(terrain.mesh))
	cs.shape = shape
	body.add_child(cs)
	zone.add_child(body)
	var t2 := Time.get_ticks_msec()
	var rings := _ring(zone)
	var t3 := Time.get_ticks_msec()
	var pools := _pools(zone)
	_bounds(zone)
	if old_mi != null:
		old_mi.queue_free()
	if old_body != null:
		old_body.queue_free()
	WorldLanes.clear_cache()
	var tris := 0
	for n in zone.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null and (String(mi.name).begins_with("Terrain") or mi.name == "FenWater") and mi.visible:
			tris += (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("REALM_LAND heights %d ms, meshes %d ms (terrain+collision %d, ring %d); grid %dx%d, ring %d meshes, pool cells %d, %d triangles in %d draws" % [
		t1 - t0, Time.get_ticks_msec() - t1, t2 - t1, t3 - t2, GNX, GNZ, rings, pools, tris, 2 + rings])


static func _init_noise() -> void:
	_n_roll = FastNoiseLite.new()
	_n_roll.seed = 4401
	_n_roll.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_roll.frequency = 0.035
	_n_roll.fractal_octaves = 4
	_n_ridge = FastNoiseLite.new()
	_n_ridge.seed = 4402
	_n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_ridge.frequency = 0.016
	_n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_ridge.fractal_octaves = 5
	_n_ridge.fractal_gain = 0.5
	_n_ridge.domain_warp_enabled = true
	_n_ridge.domain_warp_amplitude = 18.0
	_n_ridge.domain_warp_frequency = 0.01
	_n_fine = FastNoiseLite.new()
	_n_fine.seed = 4403
	_n_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_fine.frequency = 0.11
	_n_fine.fractal_octaves = 2
	_n_gully = FastNoiseLite.new()
	_n_gully.seed = 4405
	_n_gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_gully.frequency = 0.045
	_n_gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_gully.fractal_octaves = 3
	_n_gully.domain_warp_enabled = true
	_n_gully.domain_warp_amplitude = 8.0
	_n_gully.domain_warp_frequency = 0.03
	_n_step = FastNoiseLite.new()
	_n_step.seed = 4406
	_n_step.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_step.frequency = 0.02
	_n_step.fractal_octaves = 2
	_n_patch = FastNoiseLite.new()
	_n_patch.seed = 4404
	_n_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_patch.frequency = 0.06
	_n_patch.fractal_octaves = 3


# ------------------------------------------------------------------------------------- old terrain

static func _sample_old(mi: MeshInstance3D) -> void:
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := mi.global_transform
	var x0 := INF
	var z0 := INF
	var x1 := -INF
	var z1 := -INF
	for v in verts:
		var w := xf * v
		x0 = minf(x0, w.x)
		z0 = minf(z0, w.z)
		x1 = maxf(x1, w.x)
		z1 = maxf(z1, w.z)
	_old_step = 2.0
	_old_x0 = x0
	_old_z0 = z0
	_old_nx = roundi((x1 - x0) / _old_step) + 1
	_old_nz = roundi((z1 - z0) / _old_step) + 1
	_old.resize(_old_nx * _old_nz)
	_old.fill(NAN)
	for v in verts:
		var w := xf * v
		var i := roundi((w.x - x0) / _old_step)
		var j := roundi((w.z - z0) / _old_step)
		if i >= 0 and j >= 0 and i < _old_nx and j < _old_nz:
			_old[j * _old_nx + i] = w.y


static func old_height_at(x: float, z: float) -> float:
	if _old.is_empty():
		return NAN
	var fx := (x - _old_x0) / _old_step
	var fz := (z - _old_z0) / _old_step
	var i := clampi(floori(fx), 0, _old_nx - 2)
	var j := clampi(floori(fz), 0, _old_nz - 2)
	if fx < -0.001 or fz < -0.001 or fx > _old_nx - 0.999 or fz > _old_nz - 0.999:
		return NAN
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var a := _old[j * _old_nx + i]
	var b := _old[j * _old_nx + i + 1]
	var c := _old[(j + 1) * _old_nx + i]
	var d := _old[(j + 1) * _old_nx + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


# -------------------------------------------------------------------------------------- weights

static func _rect_d(r: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dz := maxf(maxf(r.position.y - z, 0.0), z - r.end.y)
	return sqrt(dx * dx + dz * dz)


## Distance outside the kept core (0 inside it).
static func _keep_d(x: float, z: float) -> float:
	var d := minf(_rect_d(_rift_r, x, z), _rect_d(_oss_r, x, z))
	return minf(d, maxf(Vector2(x, z).distance_to(SUMMIT_C) - SUMMIT_R, 0.0))


static func keep_weight(x: float, z: float) -> float:
	if _old.is_empty():
		return 0.0
	return 1.0 - smoothstep(0.0, KEEP_FALL, _keep_d(x, z))


## Biome weights, normalised: [meadow, loam, mud, ash, heath, crag, ruin, salt].
static func _bw(x: float, z: float) -> PackedFloat32Array:
	var w := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
	for r: Dictionary in RealmLayout.REGIONS:
		var k := RealmLayout.region_weight(r, x, z)
		if k <= 0.0:
			continue
		var b: String = r.biome
		if b == "glade":
			w[0] = maxf(w[0], k * 0.6)
			w[1] = maxf(w[1], k * 0.6)
		else:
			var i: int = BIOME_OF.get(b, 0)
			w[i] = maxf(w[i], k)
	var tot := 0.0
	for v in w:
		tot += v
	if tot < 1.0:
		w[0] += 1.0 - tot
		tot = 1.0
	for i in NB:
		w[i] /= tot
	return w


static func biome_weights(x: float, z: float) -> Dictionary:
	var w := _bw(x, z)
	var out := {}
	for i in NB:
		out[BIOMES[i]] = w[i]
	return out


# -------------------------------------------------------------------------------------- heights

## Macro + detail + hollow floors (no paths, flats or kept core). Shared by grid and ring.
static func _base(x: float, z: float, bw: PackedFloat32Array, river := true) -> float:
	var m := RealmLayout.macro_dry(x, z)
	var out := RealmLayout._out_dist(Vector2(x, z), RealmLayout.BOUNDS)
	var roll := _n_roll.get_noise_2d(x, z)
	var ridge := _n_ridge.get_noise_2d(x, z)            # ridged: sharp crests, broad valleys
	var fine := _n_fine.get_noise_2d(x, z)
	# r34: the raid floors and the quarry's benches are flat by design: no hill noise on them
	var calm := 1.0 - _designed_w(x, z)
	var hill := smoothstep(1.5, 9.0, m) * calm
	var mountain := clampf(smoothstep(12.0, 40.0, m) + smoothstep(0.0, 50.0, out), 0.0, 1.0) * calm
	var amp_roll := 0.35 * bw[0] + 0.3 * bw[4] + 0.9 * bw[1] + 0.35 * bw[2] + 0.5 * bw[3] + 1.0 * bw[5] + 0.3 * bw[6] + 0.08 * bw[7]
	var gully := _n_gully.get_noise_2d(x, z)            # ridged: sharp spurs between gullies
	var h := m
	h += roll * amp_roll * calm
	h += (ridge + 0.25) * (hill * 3.6 + mountain * 9.0)
	h += (gully + 0.3) * (hill * 1.3 + mountain * 2.5 + 0.35 * bw[1] + 0.15 * bw[4])
	h += fine * (0.09 + 0.12 * bw[2] + 0.1 * bw[1]) * calm
	# strata: hills break into soft ledges (bench + riser) so rock shows on the risers
	var strat := clampf(hill + mountain, 0.0, 1.0) * (1.0 - bw[2])
	if strat > 0.0:
		var stp := lerpf(2.2, 4.0, _n_step.get_noise_2d(x, z) * 0.5 + 0.5)
		var t := h / stp + _n_step.get_noise_2d(z * 1.7, x * 1.7) * 0.35
		var lv := floorf(t)
		var fr := t - lv
		var ledge := (lv + smoothstep(0.45, 0.95, fr)) * stp - _n_step.get_noise_2d(z * 1.7, x * 1.7) * 0.35 * stp
		h = lerpf(h, ledge, strat * 0.55)
	h = RealmLayout.post_detail(x, z, h)
	# hollows: floored (dry) outside the fen, shallow pools inside it
	var fen := smoothstep(0.3, 0.7, bw[2])
	var dry := h
	if h < -0.6:
		dry = -0.6 - 0.25 * (1.0 - exp(-(-0.6 - h) / 0.25))
	var wet := h
	if h < WATER_Y:
		wet = WATER_Y - POOL_DEPTH * (1.0 - exp(-(WATER_Y - h) / 0.5))
	return RealmLayout.final_shape(x, z, lerpf(dry, wet, fen), river)


## r34: 1 on the raid floors and the quarry (where the designed shape must stay flat/stepped), 0 away.
static func _designed_w(x: float, z: float) -> float:
	var w := 0.0
	var p := Vector2(x, z)
	for r: Dictionary in RealmLayout.RAIDS:
		w = maxf(w, 1.0 - smoothstep(float(r.r) + 1.0, float(r.r) + 6.0, p.distance_to(r.c)))
	var q := Vector2((x - RealmLayout.QUARRY_C.x) * 0.8, z - RealmLayout.QUARRY_C.y)
	w = maxf(w, 0.85 * (1.0 - smoothstep(34.0, 46.0, q.length())))
	return w


static func _make_profiles() -> void:
	_profiles = []
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var w: float = path.w
		var res: Array[Vector2] = []
		var ss := PackedFloat32Array()
		var acc := 0.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(1, ceili(a.distance_to(b)))
			for k in n:
				var p := a.lerp(b, float(k) / n)
				if not res.is_empty():
					acc += p.distance_to(res[-1])
				res.append(p)
				ss.append(acc)
		acc += (pts[-1] as Vector2).distance_to(res[-1])
		res.append(pts[-1])
		ss.append(acc)
		var pin: Array = PATH_PIN.get(path.id, [])
		var raw := PackedFloat32Array()
		raw.resize(res.size())
		for k in res.size():
			var p := res[k]
			var tdir := (res[mini(k + 1, res.size() - 1)] - res[maxi(k - 1, 0)]).normalized()
			var nrm := Vector2(-tdir.y, tdir.x)
			var sum := 0.0
			for o in [-w - 1.0, -w * 0.5, 0.0, w * 0.5, w + 1.0]:
				var q := p + nrm * float(o)
				sum += _base(q.x, q.y, _bw(q.x, q.y), false)       # (the river is crossed on a bridge, not filled)
			raw[k] = maxf(sum / 5.0, WATER_Y + 0.28)      # causeways over the fen pools
		# in the kept core's blend band the base shape means nothing: hold the last free value (or the pin)
		var last := NAN
		for k in raw.size():
			if keep_weight(res[k].x, res[k].y) > 0.01:
				raw[k] = float(pin[0]) if not pin.is_empty() else (last if not is_nan(last) else raw[k])
			else:
				last = raw[k]
		var prof := raw
		for pass_i in 3:
			prof = _smooth(prof, 6)
		if not pin.is_empty():
			for k in prof.size():
				var t := 1.0 - smoothstep(0.0, 10.0, acc - ss[k])
				prof[k] = lerpf(prof[k], float(pin[0]), t)
		# r34: runs of 16 samples with their bounds (grown by the 14 m reach), so a lookup skips far runs
		# whole: twice the land and twice the roads made the per-sample scan the heights' main cost
		var runs: Array = []
		for k0 in range(0, res.size() - 1, 16):
			var k1 := mini(k0 + 16, res.size() - 1)
			var bb := Rect2(res[k0], Vector2.ZERO)
			for k in range(k0, k1 + 1):
				bb = bb.expand(res[k])
			runs.append([bb.grow(14.0), k0, k1])
		_profiles.append({"id": path.id, "w": w, "pts": res, "s": ss, "prof": prof, "over": (not pin.is_empty()) and bool(pin[1]), "runs": runs})


static func _smooth(a: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		var sum := 0.0
		var n := 0
		for k in range(maxi(0, i - r), mini(a.size(), i + r + 1)):
			sum += a[k]
			n += 1
		out[i] = sum / n
	return out


## Nearest point on a profile's resampled polyline: [distance, profile height].
static func _path_near(pr: Dictionary, x: float, z: float) -> Vector2:
	var pts: Array[Vector2] = pr.pts
	var prof: PackedFloat32Array = pr.prof
	var p := Vector2(x, z)
	var best := INF
	var hy := 0.0
	for run: Array in pr.runs:
		if not (run[0] as Rect2).has_point(p):
			continue
		for k in range(int(run[1]), int(run[2])):
			var a := pts[k]
			if absf(a.x - x) > 14.0 or absf(a.y - z) > 14.0:
				continue
			var b := pts[k + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < best:
				best = d
				hy = lerpf(prof[k], prof[k + 1], t)
	return Vector2(best, hy)


## Carve weight of a path at distance d from its centreline.
static func _carve_w(d: float, w: float) -> float:
	return 1.0 - smoothstep(w + 0.8, w + 5.0, d)


## One grid row of designed heights and path wear (thread-safe: reads only).
static func _pre_row(j: int) -> Array:
	var hr := PackedFloat32Array()
	hr.resize(GNX)
	var wr := PackedFloat32Array()
	wr.resize(GNX)
	var z := GZ0 + j * STEP
	for i in GNX:
		var x := GX0 + i * STEP
		var h := _base(x, z, _bw(x, z))
		var kd := _keep_d(x, z)
		var free := 1.0 - (1.0 - smoothstep(0.0, KEEP_FALL, kd) if not _old.is_empty() else 0.0)
		var wear := 0.0
		var rmask := RealmLayout.river_mask(x, z)
		for pr: Dictionary in _profiles:
			var near := _path_near(pr, x, z)
			if near.x == INF:
				continue
			if kd > 0.0:
				var e: float = float(pr.w) + _n_patch.get_noise_2d(x * 1.7, z * 1.7) * 0.6
				wear = maxf(wear, (1.0 - smoothstep(e - 1.6, e + 1.8, near.x)) * (1.0 - rmask))     # wide ramp: the shader cuts the edge
			if not pr.over:
				h = lerpf(h, near.y, _carve_w(near.x, pr.w) * free * (1.0 - rmask))
		wear = maxf(wear, maxf(Zones.lane_wear(Vector2(x, z)) * 0.85, Zones.fire_wear(x, z) * 0.7))     # the walk lanes of the squares, the fire pads
		wr[i] = wear
		hr[i] = h
	return [hr, wr]


static func _heights() -> void:
	_h.resize(GNX * GNZ)
	var tav_sum := 0.0
	var tav_n := 0
	var pre := PackedFloat32Array()
	pre.resize(GNX * GNZ)
	_wear_g.resize(GNX * GNZ)
	Zones.lane_dist(Vector2.ZERO)          # builds its tables here, on this thread, before the rows read them
	# rows in parallel (pure math: noise reads, path distances); each task fills its own row,
	# the rows are stitched together after (no shared writes)
	var rows: Array = []
	rows.resize(GNZ)
	var task := WorkerThreadPool.add_group_task(func(j: int) -> void: rows[j] = _pre_row(j), GNZ)
	WorkerThreadPool.wait_for_group_task_completion(task)
	for j in GNZ:
		var r: Array = rows[j]
		var hr: PackedFloat32Array = r[0]
		var wr: PackedFloat32Array = r[1]
		for i in GNX:
			pre[j * GNX + i] = hr[i]
			_wear_g[j * GNX + i] = wr[i]
			if TAVERN_FLAT.has_point(Vector2(GX0 + i * STEP, GZ0 + j * STEP)):
				tav_sum += hr[i]
				tav_n += 1
	var tav_y := tav_sum / maxi(tav_n, 1)
	for j in GNZ:
		for i in GNX:
			var x := GX0 + i * STEP
			var z := GZ0 + j * STEP
			var h := pre[j * GNX + i]
			var ts := 1.0 - smoothstep(0.0, TAVERN_FALL, _rect_d(TAVERN_FLAT, x, z))
			h = lerpf(h, tav_y, ts)
			var sp := 1.0 - smoothstep(SPAWN_R, SPAWN_R + SPAWN_FALL, Vector2(x, z).distance_to(Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z)))
			h = lerpf(h, SPAWN_Y, sp)
			var k := keep_weight(x, z)
			if k > 0.0:
				var o := old_height_at(x, z)
				if not is_nan(o):
					h = lerpf(h, o, k)
				h = RealmLayout.raid_shape(x, z, h)          # r34: the summit's raid volume is cut out of the kept core too
			if _keep_d(x, z) > 0.0:
				for pr: Dictionary in _profiles:
					if not pr.over:
						continue
					var near := _path_near(pr, x, z)
					if near.x < INF:
						h = lerpf(h, near.y, _carve_w(near.x, pr.w))
			_h[j * GNX + i] = h
	# outer rows: odd vertices follow their even neighbours so the 4 m ring meets them without cracks
	for i in range(1, GNX - 1, 2):
		for j in [0, GNZ - 1]:
			_h[j * GNX + i] = (_h[j * GNX + i - 1] + _h[j * GNX + i + 1]) * 0.5
	for j in range(1, GNZ - 1, 2):
		for i in [0, GNX - 1]:
			_h[j * GNX + i] = (_h[(j - 1) * GNX + i] + _h[(j + 1) * GNX + i]) * 0.5


static func height_at(x: float, z: float) -> float:
	if _h.is_empty():
		return RealmLayout.macro_height(x, z)
	var fx := clampf((x - GX0) / STEP, 0.0, GNX - 1.001)
	var fz := clampf((z - GZ0) / STEP, 0.0, GNZ - 1.001)
	var i := floori(fx)
	var j := floori(fz)
	var tx := fx - i
	var tz := fz - j
	return lerpf(lerpf(_h[j * GNX + i], _h[j * GNX + i + 1], tx), lerpf(_h[(j + 1) * GNX + i], _h[(j + 1) * GNX + i + 1], tx), tz)


## The surface of the water at xz (the fen's WATER_Y unless a reach / the lake / the Well gives one).
static func water_y_at(x: float, z: float) -> float:
	var wl := RealmLayout.water_level_at(x, z)
	return WATER_Y if is_nan(wl) else wl


static func in_water(x: float, z: float) -> bool:
	if _water.is_empty():
		return false
	var i := floori((x - GX0) / STEP)
	var j := floori((z - GZ0) / STEP)
	if i < 0 or j < 0 or i >= GNX - 1 or j >= GNZ - 1:
		return false
	return _water[j * GNX + i] == 1 and height_at(x, z) < water_y_at(x, z)


# -------------------------------------------------------------------------------------- meshes

## How much of the flagstone ground stays at (x, z): 1 outside the Siege Lines and on the pads round the siege tower
## and the three trebuchets, falling to 0 over 8 m off them (their pads are levelled by realm_pois_r37_west.gd).
const SIEGE_RECT := Rect2(-262.0, 100.0, 108.0, 150.0)
const SIEGE_PADS := [[Vector2(-236.0, 170.0), 11.0], [Vector2(-204.0, 206.0), 10.0], [Vector2(-190.0, 210.0), 10.0], [Vector2(-176.0, 206.0), 10.0]]


static func _siege_flags(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if not SIEGE_RECT.has_point(p):
		return 1.0
	var best := 0.0
	for pad: Array in SIEGE_PADS:
		best = maxf(best, 1.0 - smoothstep(float(pad[1]), float(pad[1]) + 8.0, p.distance_to(pad[0])))
	return best


## Vertex splat for one point: COLOR, UV, UV2.
static func _splat(x: float, z: float, h: float, nrm_y: float, ring: bool) -> Array:
	var bw: PackedFloat32Array
	if ring:
		var b := RealmLayout.BOUNDS
		bw = _bw(clampf(x, b.position.x + 4.0, b.end.x - 4.0), clampf(z, b.position.y + 4.0, b.end.y - 4.0))
	else:
		bw = _bw(x, z)
	# ruins: flagstone only in patches, meadow/heath between
	var ruin := bw[6]
	if ruin > 0.0:
		var patch := smoothstep(0.0, 0.25, _n_patch.get_noise_2d(x, z))
		bw[6] = ruin * patch
		bw[0] += ruin * (1.0 - patch) * 0.6
		bw[4] += ruin * (1.0 - patch) * 0.4
		# the Siege Lines are trampled earth and heath, not a paved court: flags only round the tower and the trebuchets
		var keep := _siege_flags(x, z)
		if keep < 1.0:
			var drop := bw[6] * (1.0 - keep)
			bw[6] -= drop
			bw[1] += drop * 0.45
			bw[4] += drop * 0.55
	# high ground and rough slopes turn to scree
	var crag := smoothstep(14.0, 26.0, h) * (1.0 - bw[3]) + (1.0 - smoothstep(0.78, 0.9, nrm_y)) * 0.5
	if crag > 0.0:
		for i in NB:
			bw[i] *= 1.0 - clampf(crag, 0.0, 1.0)
		bw[5] += clampf(crag, 0.0, 1.0)
	# loam creeps into meadow edges, mud gathers in fen hollows
	if bw[2] > 0.0 and h > -0.3:
		var dry := smoothstep(-0.3, 0.6, h) * 0.45 * bw[2]
		bw[2] -= dry
		bw[4] += dry * 0.5
		bw[0] += dry * 0.5
	# settlement squares are cobbled, the ground round a well is mud (dress_zones.gd)
	var pave := Zones.pave_w(x, z, _n_patch.get_noise_2d(x * 2.1, z * 2.1))
	if pave > 0.0:
		for i in NB:
			bw[i] *= 1.0 - pave * 0.92
		bw[6] += pave * 0.92
	var mud := Zones.wet_w(x, z)
	if mud > 0.0:
		for i in NB:
			bw[i] *= 1.0 - mud * 0.8
		bw[2] += mud * 0.8
	var tot := 0.0
	for v in bw:
		tot += v
	for i in NB:
		bw[i] /= maxf(tot, 0.0001)
	var wear := 0.0 if ring else _wear_g[roundi((z - GZ0) / STEP) * GNX + roundi((x - GX0) / STEP)]
	return [Color(bw[0], bw[1], bw[2], bw[3]), Vector2(bw[4], bw[5]), Vector2(bw[6], wear)]


static func _grid_normal(hs: PackedFloat32Array, nx: int, nz: int, step: float, i: int, j: int) -> Vector3:
	var hl := hs[j * nx + maxi(i - 1, 0)]
	var hr := hs[j * nx + mini(i + 1, nx - 1)]
	var hd := hs[maxi(j - 1, 0) * nx + i]
	var hu := hs[mini(j + 1, nz - 1) * nx + i]
	var sx := step * float(mini(i + 1, nx - 1) - maxi(i - 1, 0))
	var sz := step * float(mini(j + 1, nz - 1) - maxi(j - 1, 0))
	return Vector3(-(hr - hl) / sx, 1.0, -(hu - hd) / sz).normalized()


static func _terrain_mesh() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var n := GNX * GNZ
	verts.resize(n)
	nrms.resize(n)
	cols.resize(n)
	uv.resize(n)
	uv2.resize(n)
	# r34: rows in parallel (the splat's biome blend is the cost and pure math); stitched after
	var rows: Array = []
	rows.resize(GNZ)
	var task := WorkerThreadPool.add_group_task(func(j: int) -> void: rows[j] = _mesh_row(j), GNZ)
	WorkerThreadPool.wait_for_group_task_completion(task)
	for j in GNZ:
		var r: Array = rows[j]
		var rn: PackedVector3Array = r[0]
		var rc: PackedColorArray = r[1]
		var ru: PackedVector2Array = r[2]
		var ru2: PackedVector2Array = r[3]
		for i in GNX:
			var k := j * GNX + i
			verts[k] = Vector3(GX0 + i * STEP, _h[k], GZ0 + j * STEP)
			nrms[k] = rn[i]
			cols[k] = rc[i]
			uv[k] = ru[i]
			uv2[k] = ru2[i]
	var idx := _grid_indices(GNX, GNZ, func(_i: int, _j: int) -> bool: return true)
	var mi := MeshInstance3D.new()
	mi.mesh = _array_mesh(verts, nrms, cols, uv, uv2, idx)
	mi.material_override = load(MAT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## One grid row's normals and splat (thread-safe: reads only).
static func _mesh_row(j: int) -> Array:
	var rn := PackedVector3Array()
	var rc := PackedColorArray()
	var ru := PackedVector2Array()
	var ru2 := PackedVector2Array()
	rn.resize(GNX)
	rc.resize(GNX)
	ru.resize(GNX)
	ru2.resize(GNX)
	var z := GZ0 + j * STEP
	for i in GNX:
		var k := j * GNX + i
		var nv := _grid_normal(_h, GNX, GNZ, STEP, i, j)
		var sp := _splat(GX0 + i * STEP, z, _h[k], nv.y, false)
		rn[i] = nv
		rc[i] = sp[0]
		ru[i] = sp[1]
		ru2[i] = sp[2]
	return [rn, rc, ru, ru2]


## Two clockwise-from-above triangles per accepted cell (Godot's front face), same diagonal everywhere.
static func _grid_indices(nx: int, nz: int, accept: Callable) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			if not accept.call(i, j):
				continue
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	return idx


static func _array_mesh(verts: PackedVector3Array, nrms: PackedVector3Array, cols: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _faces(m: Mesh) -> PackedVector3Array:
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var f := PackedVector3Array()
	f.resize(idx.size())
	for k in idx.size():
		f[k] = v[idx[k]]
	return f


## Horizon ring: a 4 m grid over OUTER minus the inner grid, in four meshes (N, S, W, E). Its
## inner edge takes the inner grid's heights so the two meet without cracks.
static func _ring(zone: Node3D) -> int:
	var hs := PackedFloat32Array()
	hs.resize(RNX * RNZ)
	var i0 := roundi((GX0 - RX0) / RSTEP)
	var i1 := roundi((GX0 + (GNX - 1) * STEP - RX0) / RSTEP)
	var j0 := roundi((GZ0 - RZ0) / RSTEP)
	var j1 := roundi((GZ0 + (GNZ - 1) * STEP - RZ0) / RSTEP)
	# r34: rows in parallel (pure math), stitched after
	var bb := RealmLayout.BOUNDS.grow(-4.0)
	var rows: Array = []
	rows.resize(RNZ)
	var task := WorkerThreadPool.add_group_task(func(j: int) -> void:
		var row := PackedFloat32Array()
		row.resize(RNX)
		for i in RNX:
			var x := RX0 + i * RSTEP
			var z := RZ0 + j * RSTEP
			if i >= i0 and i <= i1 and j >= j0 and j <= j1:
				row[i] = height_at(x, z)
			else:
				row[i] = _base(x, z, _bw(clampf(x, bb.position.x, bb.end.x), clampf(z, bb.position.y, bb.end.y)))
		rows[j] = row, RNZ)
	WorkerThreadPool.wait_for_group_task_completion(task)
	for j in RNZ:
		var row: PackedFloat32Array = rows[j]
		for i in RNX:
			hs[j * RNX + i] = row[i]
	var parts := {"N": [], "S": [], "W": [], "E": []}
	var made := 0
	for key: String in parts:
		var accept := func(i: int, j: int) -> bool:
			var inner := i >= i0 and i < i1 and j >= j0 and j < j1
			if inner:
				return false
			match key:
				"N": return j < j0
				"S": return j >= j1
				"W": return j >= j0 and j < j1 and i < i0
				_: return j >= j0 and j < j1 and i >= i1
		var idx := _grid_indices(RNX, RNZ, accept)
		if idx.is_empty():
			continue
		# compact to the vertices this part uses
		var remap := {}
		var verts := PackedVector3Array()
		var nrms := PackedVector3Array()
		var cols := PackedColorArray()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		for k in idx.size():
			var g := idx[k]
			if not remap.has(g):
				remap[g] = verts.size()
				var gi := g % RNX
				var gj := g / RNX
				var x := RX0 + gi * RSTEP
				var z := RZ0 + gj * RSTEP
				var nv := _grid_normal(hs, RNX, RNZ, RSTEP, gi, gj)
				verts.append(Vector3(x, hs[g], z))
				nrms.append(nv)
				var sp := _splat(x, z, hs[g], nv.y, true)
				cols.append(sp[0])
				uv.append(sp[1])
				uv2.append(sp[2])
			idx[k] = remap[g]
		var mi := MeshInstance3D.new()
		mi.name = "TerrainRing" + key
		mi.mesh = _array_mesh(verts, nrms, cols, uv, uv2, idx)
		mi.material_override = load(MAT)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zone.add_child(mi)
		made += 1
	return made


## Water: one mesh over every grid cell whose ground dips below its water level (outside the kept core),
## grown by one cell so the shoreline is the terrain's own intersection. a cell's level is the fen's
## WATER_Y unless RealmLayout.water_level_at gives one (the Sorrow's stepped reaches, the lake, the Well's
## pool); where two neighbours differ a vertical skirt closes the step (the weir's lip).
static func _pools(zone: Node3D) -> int:
	_water.resize(GNX * GNZ)
	_water.fill(0)
	var lvl := PackedFloat32Array()
	lvl.resize(GNX * GNZ)
	for j in GNZ - 1:
		for i in GNX - 1:
			var wl := RealmLayout.water_level_at(GX0 + (i + 0.5) * STEP, GZ0 + (j + 0.5) * STEP)
			lvl[j * GNX + i] = WATER_Y if is_nan(wl) else wl
	var wet := PackedByteArray()
	wet.resize(GNX * GNZ)
	wet.fill(0)
	for j in GNZ - 1:
		for i in GNX - 1:
			var k := j * GNX + i
			var lo := minf(minf(_h[k], _h[k + 1]), minf(_h[k + GNX], _h[k + GNX + 1]))
			var x := GX0 + (i + 0.5) * STEP
			var z := GZ0 + (j + 0.5) * STEP
			if lo < lvl[k] - 0.01 and keep_weight(x, z) < 0.05:
				wet[k] = 1
	# pools reaching into the kept core's blend band follow their own shore (flood fill), but never
	# down into the chasm: a cell joins only if its ground stays shallow
	var front: Array[int] = []
	for k in wet.size():
		if wet[k] == 1:
			front.append(k)
	while not front.is_empty():
		var k: int = front.pop_back()
		var ci := k % GNX
		var cj := k / GNX
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ii := ci + d.x
			var jj := cj + d.y
			if ii < 0 or jj < 0 or ii >= GNX - 1 or jj >= GNZ - 1:
				continue
			var n := jj * GNX + ii
			if wet[n] == 1:
				continue
			var lo2 := minf(minf(_h[n], _h[n + 1]), minf(_h[n + GNX], _h[n + GNX + 1]))
			if lo2 < lvl[n] - 0.01 and lo2 > lvl[n] - 2.0:
				wet[n] = 1
				front.append(n)
	var cells := 0
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var on_cell := PackedByteArray()
	on_cell.resize(GNX * GNZ)
	on_cell.fill(0)
	for j in GNZ - 1:
		for i in GNX - 1:
			var on := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := i + di
					var jj := j + dj
					if ii >= 0 and jj >= 0 and ii < GNX - 1 and jj < GNZ - 1 and wet[jj * GNX + ii] == 1:
						on = true
			if not on:
				continue
			# skip cells wholly above the water (the grown ring outside the shore)
			var k := j * GNX + i
			var lo := minf(minf(_h[k], _h[k + 1]), minf(_h[k + GNX], _h[k + GNX + 1]))
			var wy := lvl[k]
			if lo > wy + 0.02:
				continue
			_water[k] = 1
			on_cell[k] = 1
			cells += 1
			var x := GX0 + i * STEP
			var z := GZ0 + j * STEP
			var b := verts.size()
			verts.append_array(PackedVector3Array([Vector3(x, wy, z), Vector3(x + STEP, wy, z), Vector3(x, wy, z + STEP), Vector3(x + STEP, wy, z + STEP)]))
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	if cells == 0:
		return 0
	# skirts where neighbouring reaches stand at different levels: a vertical face down the shared edge
	for j in GNZ - 1:
		for i in GNX - 1:
			var k := j * GNX + i
			if on_cell[k] == 0:
				continue
			var x := GX0 + i * STEP
			var z := GZ0 + j * STEP
			if i + 1 < GNX - 1 and on_cell[k + 1] == 1 and absf(lvl[k] - lvl[k + 1]) > 0.01:
				var hi := maxf(lvl[k], lvl[k + 1])
				var lo := minf(lvl[k], lvl[k + 1])
				var b := verts.size()
				verts.append_array(PackedVector3Array([Vector3(x + STEP, hi, z), Vector3(x + STEP, hi, z + STEP), Vector3(x + STEP, lo, z), Vector3(x + STEP, lo, z + STEP)]))
				idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2, b, b + 2, b + 1, b + 1, b + 2, b + 3]))
			if j + 1 < GNZ - 1 and on_cell[k + GNX] == 1 and absf(lvl[k] - lvl[k + GNX]) > 0.01:
				var hi2 := maxf(lvl[k], lvl[k + GNX])
				var lo2 := minf(lvl[k], lvl[k + GNX])
				var b2 := verts.size()
				verts.append_array(PackedVector3Array([Vector3(x, hi2, z + STEP), Vector3(x + STEP, hi2, z + STEP), Vector3(x, lo2, z + STEP), Vector3(x + STEP, lo2, z + STEP)]))
				idx.append_array(PackedInt32Array([b2, b2 + 1, b2 + 2, b2 + 1, b2 + 3, b2 + 2, b2, b2 + 2, b2 + 1, b2 + 1, b2 + 2, b2 + 3]))
	var nrms := PackedVector3Array()
	nrms.resize(verts.size())
	nrms.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "FenWater"
	mi.mesh = m
	mi.material_override = load(WATER_MAT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := m.get_aabb()                    # a sheet has no thickness: grow it so a glance along it stays in frame
	box.position.y -= 3.0
	box.size.y += 6.0
	mi.custom_aabb = box
	zone.add_child(mi)
	return cells


## Invisible walls just outside BOUNDS (10 m segments from below the ground to well above it).
static func _bounds(zone: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "RealmBounds"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	zone.add_child(body)
	var b := RealmLayout.BOUNDS
	var seg := 10.0
	var edges := [
		[Vector2(b.position.x, b.position.y), Vector2(b.end.x, b.position.y), Vector2(0, -1)],
		[Vector2(b.position.x, b.end.y), Vector2(b.end.x, b.end.y), Vector2(0, 1)],
		[Vector2(b.position.x, b.position.y), Vector2(b.position.x, b.end.y), Vector2(-1, 0)],
		[Vector2(b.end.x, b.position.y), Vector2(b.end.x, b.end.y), Vector2(1, 0)],
	]
	for e: Array in edges:
		var a: Vector2 = e[0]
		var c: Vector2 = e[1]
		var out: Vector2 = e[2]
		var n := ceili(a.distance_to(c) / seg)
		for k in n:
			var p0 := a.lerp(c, float(k) / n)
			var p1 := a.lerp(c, float(k + 1) / n)
			var lo := INF
			var hi := -INF
			for t in 6:
				var q := p0.lerp(p1, t / 5.0) + out * 0.8
				var y := height_at(q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
			var box := BoxShape3D.new()
			var len := p0.distance_to(p1) + 1.0
			var hgt := hi - lo + 16.0
			box.size = Vector3(len if out.x == 0.0 else 1.0, hgt, 1.0 if out.x == 0.0 else len)
			var cs := CollisionShape3D.new()
			cs.shape = box
			var mid := (p0 + p1) * 0.5 + out * 1.0
			cs.position = Vector3(mid.x, lo - 4.0 + hgt * 0.5, mid.y)
			body.add_child(cs)

extends RefCounted
## The flora's layers (Luke, 15 Nov: "richer flora per biome: layered undergrowth, clusters and clearings, not even
## scatter"). RealmFlora scatters by rate and noise; these place by what is there, the way a wood grows:
##   feet      round a tree's foot: ferns on its shady side, moss and roots on the flare, a ring of mushrooms now and
##             then; tall grass and flowers round a lone tree in the open; heather round the fell pines
##   verges    along every way, a broken band of tall grass and flowers (bracken and bramble in the woods, heather
##             on the heath, reeds by water) between the trodden edge and the field, gapped by noise
##   thickets  at a wood's broken edge, a sapling or two with shrubs, bramble and fern packed round them
##   deadfall  in deep shade, a fallen trunk with fungus along it, moss and ferns at its ends, a stump nearby
##   drifts    on open ground, a patch of one flower (each chunk draws one variant) or a clump of gorse on the heath
##   glades    the clearings the wayside's places cut in the woods (realm_wayside.gd): flowers in the light, a rim of
##             bracken, bramble and shrub where the shade begins, a stump left by the cutters
##   creep     round every wayside place: what grows on a ruin, a fold, a grave plot (wayside_themes.gd KINDS creep)
##   rings     in the Lanternwood, rings of cold fungus round an old stump
## Same rules as the undergrowth (realm_flora.gd _under_cell): the terrain itself, off the sites and ways by the
## species' keep-off (verges and creep come nearer, as plants do), off the water, the lanes' floors, the walk routes;
## each chunk draws its own variant. Plants go into the flora's own buffers (no draw call of their own), from their
## own random streams (the scatter before them is untouched). Measured: zz/perf_tour, the fight bench (flora_fight.gd
## thins them with the rest). Load by path; reads realm_flora.gd's fields through the script it is handed.

const Wayside := preload("res://core/world/realm/realm_wayside.gd")
const Themes := preload("res://core/world/realm/wayside_themes.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const Tables := preload("res://core/world/realm/flora_tables.gd")

const WATER := -0.9
static var counts := {}                  ## layer -> plants (last build)
static var ms := 0

static var F: Variant                    ## realm_flora.gd (its static fields and helpers)
static var _items: Dictionary
static var _rng := RandomNumberGenerator.new()
static var _noise := FastNoiseLite.new()
static var _gy := PackedFloat32Array()
static var _gn := PackedFloat32Array()
static var _gnx := PackedFloat32Array()
static var _gnz := PackedFloat32Array()
static var _ok := PackedByteArray()
static var _pd := PackedFloat32Array()
static var _sd := PackedFloat32Array()
static var _x0 := 0.0
static var _z0 := 0.0
static var _nx := 0
static var _nz := 0
static var _ids := {}
static var _style := {}


## RealmFlora.build, before its fingerprint: the wayside plans its places (and their clearings) now that every landmark
## is registered.
static func plan(root: Node, tree_clear: Array) -> void:
	Wayside.plan_now(root, tree_clear)


## RealmFlora._scatter, after the undergrowth and the stones: the layers into `items` (kind -> chunk -> Buf), then the
## wayside's ground cleared of whatever grew on it (`stones` too). `flora` is realm_flora.gd. The places' sites are kept out
## of the scatter's keep-out field (realm_flora.gd _keepout), so the scatter is the one the world has without them: no
## tree candidate turned away early re-rolls the wood after it, no ragged keep-out edge thins the meadow round a ruin.
static func decorate(items: Dictionary, flora: Variant, stones := {}) -> void:
	counts = {}
	if "--no-density" in OS.get_cmdline_user_args() or bool(flora.r30):
		return
	var t0 := Time.get_ticks_msec()
	F = flora
	_items = items
	_gy = F._gy
	_gn = F._gn
	_gnx = F._gnx
	_gnz = F._gnz
	_ok = F._ok
	_pd = F._pd
	_sd = F._sd
	_x0 = F._x0
	_z0 = F._z0
	_nx = F._nx
	_nz = F._nz
	_style = F.STYLE
	_ids.clear()
	_noise.seed = 4411
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.07
	_rng.seed = 20261151
	_creep()
	_rng.seed = 20261152
	_feet()
	_rng.seed = 20261153
	_verges()
	_rng.seed = 20261154
	_woods()
	_rng.seed = 20261155
	_drifts()
	_rng.seed = 20261156
	_glades()
	_clear_ground(items, stones)
	ms = Time.get_ticks_msec() - t0
	print("FLORA layers %d ms: %s" % [ms, counts])
	F = null
	_items = {}


# --- one plant -----------------------------------------------------------------------------------

static func _list(sp: String) -> Array:
	if not _ids.has(sp):
		_ids[sp] = TreeGen.ids(sp)
	return _ids[sp]


static func _biome(x: float, z: float) -> String:
	var w: Dictionary = F.biome_w(x, z)
	var best := "meadow"
	var bw := 0.0
	for b: String in w:
		if float(w[b]) > bw:
			bw = float(w[b])
			best = b
	return best


## One plant of `sp` at x, z (layer `layer`), `near` metres nearer the sites and ways than the species keeps
## (0 = its own keep-off). Returns true when it went in.
static func _put(layer: String, sp: String, x: float, z: float, near := 0.0, s := 1.0) -> bool:
	var i := clampi(int((x - _x0)), 0, _nx - 1)
	var j := clampi(int((z - _z0)), 0, _nz - 1)
	var k := j * _nx + i
	if _ok[k] == 0:
		return false
	var st: Array = _style[sp]
	var keep_p := maxf(float(st[2]) - near, 1.0)
	var keep_s := maxf(float(st[3]) - near, 0.3)
	if _sd[k] < keep_s or _pd[k] < keep_p:
		return false
	if _pd[k] < keep_p + 1.5 and RealmLayout.path_dist(Vector2(x, z)) < keep_p:
		return false
	var wet := sp == "reeds" or sp == "cattail"
	if _gn[k] < (0.6 if sp != "moss" else 0.35):
		return false
	var y: float = F.ground_y(x, z)
	if wet:
		if y < WATER - 0.35 or y > WATER + 0.5:
			return false
	elif y < WATER + 0.15 and Tables.wet(x, z):
		return false
	if (sp == "log" or sp == "stump") and Tables.on_walk_route(Vector2(x, z)):
		return false
	var list := _list(sp)
	if list.is_empty():
		return false
	var code := int(F.KCODE.get(sp, 99))
	var id: String = F._variant(list, x, z, F.CHUNK, 1, _rng, hash(list[0]))
	var nrm := Vector3(_gnx[k], _gn[k], _gnz[k]).normalized()
	var xf: Transform3D = F._plant_xf(_rng, code, Vector3(x, y, z), nrm)
	if s != 1.0:
		xf.basis = xf.basis.scaled(Vector3(s, s, s))
	if bool(TreeGen.kind(id).tall) and sp != "sapling":
		return false
	var near_way := _pd[k] < 4.0
	if (_sd[k] < 8.0 or near_way) and bool(F._clash(null, id, xf, false, AABB(), 0.6 if near_way else 0.4)):
		return false
	if near_way and bool(F._near_lane(xf * (F.mesh_aabb(id) as AABB))) and bool(F._intrudes(xf * (F.mesh_aabb(id) as AABB), 0.3)):
		return false
	var col: Color = F._tint(_rng, 0.14 if sp != "flowers" else 0.05)
	if sp in F.TINTED:
		var tc: Color = F._tc[F._bidx(x, z)]
		col = Color(col.r * tc.r, col.g * tc.g, col.b * tc.b, 1.0)
	if sp == "flowers":
		var fh: Color = F._fc[F._bidx(x, z)]
		col = Color(col.r * fh.r, col.g * fh.g, col.b * fh.b, 1.0)
	F._add(_items, id, xf, col, sp)
	counts[layer] = int(counts.get(layer, 0)) + 1
	return true


## `n` plants of `sp` in the ring r0..r1 round c (an arc of `span` radians about `dir` when span < TAU).
static func _ring(layer: String, sp: String, c: Vector2, n: int, r0: float, r1: float, near := 0.0, dir := 0.0, span := TAU) -> void:
	for i in n:
		var a := dir + _rng.randf_range(-span * 0.5, span * 0.5)
		var r := sqrt(_rng.randf_range(r0 * r0, r1 * r1)) if r1 > r0 else r0
		_put(layer, sp, c.x + cos(a) * r, c.y + sin(a) * r, near)


# --- the layers ------------------------------------------------------------------------------------

## Round the wayside's places.
static func _creep() -> void:
	for v: Dictionary in Wayside.plan:
		var c := Vector2((v.at as Vector3).x, (v.at as Vector3).z)
		var kd: Dictionary = Themes.KINDS[v.kind]
		for cr: Array in kd.get("creep", []):
			_ring("creep", String(cr[0]), c, int(cr[1]), float(cr[2]), float(cr[3]), 1.2)


## Round the trees' feet.
static func _feet() -> void:
	var trees: Array = F.trees
	for tr: Array in trees:
		var p: Vector3 = tr[0]
		var r: float = float(tr[2])
		var c := Vector2(p.x, p.z)
		if _rng.randf() < 0.35:
			continue
		var shade := _rng.randf() * TAU                   # the side the moss and ferns keep to
		match _biome(p.x, p.z):
			"oldforest":
				_ring("feet", "fern", c, _rng.randi_range(2, 4), r + 0.7, r + 2.6, 0.6, shade, 2.2)
				_ring("feet", "moss", c, _rng.randi_range(1, 2), r + 0.15, r + 0.7, 0.6, shade, 2.6)
				if _rng.randf() < 0.3:
					_ring("feet", "mushroom", c, _rng.randi_range(2, 4), r + 0.3, r + 1.1, 0.6, shade + PI, 1.6)
				if _rng.randf() < 0.18:
					_ring("feet", "roots", c, 1, r + 0.2, r + 0.6, 0.6)
				if _rng.randf() < 0.2:
					_ring("feet", "litter", c, 2, r + 0.5, r + 2.5, 0.6)
			"glade", "meadow":
				_ring("feet", "tallgrass", c, _rng.randi_range(3, 5), r + 0.6, r + 2.6, 0.8)
				if _rng.randf() < 0.5:
					_ring("feet", "flowers", c, _rng.randi_range(2, 4), r + 0.8, r + 3.0, 0.8, shade, 2.0)
			"heath", "crag":
				_ring("feet", "heather", c, _rng.randi_range(2, 4), r + 0.5, r + 2.2, 0.6)
				_ring("feet", "tallgrass", c, _rng.randi_range(1, 2), r + 0.5, r + 2.0, 0.6)
			"fen":
				_ring("feet", "moss", c, 2, r + 0.2, r + 0.9, 0.6, shade, 2.6)
				_ring("feet", "reeds", c, _rng.randi_range(1, 3), r + 0.6, r + 2.2, 0.6)
				_ring("feet", "fern", c, 1, r + 0.8, r + 2.0, 0.6)
			"ruin":
				_ring("feet", "fern", c, 2, r + 0.6, r + 2.2, 0.6, shade, 2.4)
				_ring("feet", "tallgrass", c, 2, r + 0.5, r + 2.2, 0.6)
				if _rng.randf() < 0.4:
					_ring("feet", "bramble", c, 1, r + 1.0, r + 2.4, 0.6)
			"ash":
				_ring("feet", "ashdrift", c, 2, r + 0.3, r + 1.8, 0.6)
				if _rng.randf() < 0.5:
					_ring("feet", "cinders", c, 1, r + 0.3, r + 1.4, 0.6)


## The verges of every way.
static func _verges() -> void:
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		var w := float(p.w)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			if seg < 0.1:
				continue
			var dirv := (b - a) / seg
			var nrm := Vector2(-dirv.y, dirv.x)
			var t := _rng.randf() * 2.0
			while t < seg:
				var q := a + dirv * t
				t += 2.3
				if _in_town(q):
					continue
				for sg: float in [1.0, -1.0]:
					var nz := _noise.get_noise_2d(q.x * 0.6 + sg * 31.0, q.y * 0.6)
					if nz < -0.15:
						continue                         # the verge breaks: a gateway, a trodden gap, bare chalk
					var bio := _biome(q.x, q.y)
					var n := 1 + int(nz > 0.3)
					for m in n:
						var off := w + _rng.randf_range(1.15, 2.9)
						var x := q.x + nrm.x * sg * off + dirv.x * _rng.randf_range(-1.0, 1.0)
						var z := q.y + nrm.y * sg * off + dirv.y * _rng.randf_range(-1.0, 1.0)
						var sp := _verge_kind(bio, x, z)
						if sp != "":
							_put("verges", sp, x, z, 2.2 if sp in ["tallgrass", "flowers", "heather", "reeds", "deadbush"] else 1.4)


static func _verge_kind(bio: String, x: float, z: float) -> String:
	var r := _rng.randf()
	match bio:
		"meadow", "glade":
			return "tallgrass" if r < 0.6 else ("flowers" if r < 0.92 else "shrub")
		"heath":
			return "heather" if r < 0.45 else ("tallgrass" if r < 0.85 else ("gorse" if r < 0.95 else "flowers"))
		"crag":
			return "heather" if r < 0.55 else ("tallgrass" if r < 0.85 else "")
		"oldforest":
			return "fern" if r < 0.5 else ("tallgrass" if r < 0.8 else ("bramble" if r < 0.9 else "shrub"))
		"fen":
			return ("reeds" if F.ground_y(x, z) < WATER + 0.35 else "tallgrass") if r < 0.7 else "moss"
		"ruin":
			return "tallgrass" if r < 0.65 else ("bramble" if r < 0.8 else "fern")
		"ash":
			return "ashdrift" if r < 0.5 else ("deadbush" if r < 0.7 else "")
		"salt":
			return "deadbush" if r < 0.15 else ""
	return "tallgrass"


static func _in_town(q: Vector2) -> bool:
	for t: Array in Themes.TOWNS:
		if q.distance_to(t[0]) < float(t[1]) - 6.0:
			return true
	return false


## Thickets at the woods' broken edges, deadfall in their deep shade, fungus rings in the Lanternwood.
static func _woods() -> void:
	var b := RealmLayout.BOUNDS
	var z := b.position.y + 4.0
	while z < b.end.y - 4.0:
		var x := b.position.x + 4.0
		while x < b.end.x - 4.0:
			var q := Vector2(x + _rng.randf_range(-4.0, 4.0), z + _rng.randf_range(-4.0, 4.0))
			x += 11.0
			var w: Dictionary = F.biome_w(q.x, q.y)
			var wood := float(w.get("oldforest", 0.0)) + float(w.get("glade", 0.0)) * 0.6 + float(w.get("ruin", 0.0)) * 0.3
			if wood < 0.4:
				continue
			var cov: float = F.cover_at(q.x, q.y)
			var nv := _noise.get_noise_2d(q.x * 0.4, q.y * 0.4)
			if cov > 0.1 and cov < 0.62 and nv > 0.05 and _rng.randf() < 0.55:
				_thicket(q)
			elif cov >= 0.62 and _rng.randf() < 0.16:
				_deadfall(q)
			if _rng.randf() < 0.05 and RealmLayout.region_at(q.x, q.y).get("id", "") == "lanternwood":
				_fungus_ring(q)
		z += 11.0


static func _thicket(c: Vector2) -> void:
	if _rng.randf() < 0.6:
		_put("thickets", "sapling", c.x + _rng.randf_range(-0.8, 0.8), c.y + _rng.randf_range(-0.8, 0.8))
	_ring("thickets", "shrub", c, _rng.randi_range(1, 3), 0.6, 2.6)
	_ring("thickets", "bramble", c, _rng.randi_range(0, 2), 0.8, 2.8)
	_ring("thickets", "fern", c, _rng.randi_range(2, 4), 1.0, 3.4)
	_ring("thickets", "tallgrass", c, _rng.randi_range(1, 3), 1.6, 3.6)


static func _deadfall(c: Vector2) -> void:
	if not _put("deadfall", "log", c.x, c.y):
		return
	_ring("deadfall", "mushroom", c, _rng.randi_range(2, 5), 0.3, 1.6)
	_ring("deadfall", "moss", c, _rng.randi_range(1, 3), 0.2, 1.8)
	_ring("deadfall", "fern", c, _rng.randi_range(1, 3), 1.4, 3.0)
	if _rng.randf() < 0.4:
		_ring("deadfall", "stump", c, 1, 2.5, 4.5)


static func _fungus_ring(c: Vector2) -> void:
	if not _put("rings", "stump", c.x, c.y):
		return
	var r := _rng.randf_range(1.4, 2.4)
	var n := _rng.randi_range(9, 14)
	for i in n:
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.12, 0.12)
		var rr := r + _rng.randf_range(-0.15, 0.15)
		_put("rings", "mushroom", c.x + cos(a) * rr, c.y + sin(a) * rr, 0.4)


## Patches of one flower on the open ground, gorse clumps on the heath.
static func _drifts() -> void:
	var b := RealmLayout.BOUNDS
	var z := b.position.y + 4.0
	while z < b.end.y - 4.0:
		var x := b.position.x + 4.0
		while x < b.end.x - 4.0:
			var q := Vector2(x + _rng.randf_range(-6.0, 6.0), z + _rng.randf_range(-6.0, 6.0))
			x += 15.0
			var nv := _noise.get_noise_2d(q.x * 0.3 + 100.0, q.y * 0.3)
			if nv < 0.15 or _in_town(q):
				continue
			var w: Dictionary = F.biome_w(q.x, q.y)
			var meadow := float(w.get("meadow", 0.0)) + float(w.get("glade", 0.0))
			var heath := float(w.get("heath", 0.0))
			if meadow > 0.5 and _rng.randf() < 0.65:
				var r := _rng.randf_range(2.5, 5.5)
				_ring("drifts", "flowers", q, int(r * r * 0.9), 0.0, r)
				_ring("drifts", "tallgrass", q, int(r * 1.5), r * 0.7, r + 1.5)
			elif heath > 0.5 and _rng.randf() < 0.45:
				if _rng.randf() < 0.5:
					_ring("drifts", "gorse", q, _rng.randi_range(2, 5), 0.0, 2.2)
				else:
					var r2 := _rng.randf_range(2.0, 4.0)
					_ring("drifts", "flowers", q, int(r2 * r2 * 0.7), 0.0, r2)
		z += 15.0


## The wayside's clearings in the woods.
static func _glades() -> void:
	for gl: Array in Wayside.glades:
		var c: Vector2 = gl[0]
		var r: float = gl[1]
		_ring("glades", "flowers", c, int(r * 2.2), r * 0.35, r * 0.85)
		_ring("glades", "tallgrass", c, int(r * 1.6), r * 0.5, r * 1.0)
		_ring("glades", "fern", c, int(r * 1.4), r * 0.85, r * 1.35)
		_ring("glades", "bramble", c, int(r * 0.35), r * 0.9, r * 1.3)
		_ring("glades", "shrub", c, int(r * 0.3), r * 0.95, r * 1.4)
		if _rng.randf() < 0.6:
			_ring("glades", "stump", c, 1, r * 0.55, r * 0.9)


# --- the wayside's ground --------------------------------------------------------------------------

const CLEAR_CELL := 8.0
const CLEAR_TALL := 1.5                 ## a tall tree's trunk keeps this far off a place's solid ground
const CLEAR_STONE := 0.8
const CLEAR_LOW := 0.3                  ## undergrowth, saplings, the flora's props


## Every plant, tree and stone standing on a wayside place's ground (its sites' boxes) taken out of the buffers, with the
## tall trees' entries in RealmFlora.trees and their crowns in the canopy shells.
static func _clear_ground(items: Dictionary, stones: Dictionary) -> void:
	var feet: Array[Rect2] = []
	for v: Dictionary in Wayside.plan:
		for r: Rect2 in v.feet:
			feet.append(r)
	if feet.is_empty():
		return
	var grid := {}                                    # 8 m cell -> indices into feet (grown by the tall margin)
	for i in feet.size():
		var g := feet[i].grow(CLEAR_TALL)
		for cz in range(floori(g.position.y / CLEAR_CELL), floori(g.end.y / CLEAR_CELL) + 1):
			for cx in range(floori(g.position.x / CLEAR_CELL), floori(g.end.x / CLEAR_CELL) + 1):
				var c := Vector2i(cx, cz)
				if not grid.has(c):
					grid[c] = []
				(grid[c] as Array).append(i)
	var on := func(x: float, z: float, margin: float) -> bool:
		var c := Vector2i(floori(x / CLEAR_CELL), floori(z / CLEAR_CELL))
		for i: int in grid.get(c, []):
			if feet[i].grow(margin).has_point(Vector2(x, z)):
				return true
		return false
	var touched := {}                                 # Vector2(chunk size, tag) -> {chunk key: true}
	var gone := 0
	for name: String in items:
		var kd: Array = F._kinds.get(name, [])
		if kd.is_empty():
			continue
		gone += _clear_store(items[name] as Dictionary, kd[0] as Vector2, name, feet, touched, on)
	var sg := 0
	for name: String in stones:
		sg += _clear_store(stones[name] as Dictionary, Vector2(F.CHUNK, 0.0), "", feet, touched, on)
	var keep: Array = []
	var trees: Array = F.trees
	for tr: Array in trees:
		var p: Vector3 = tr[0]
		if not on.call(p.x, p.z, CLEAR_TALL):
			keep.append(tr)
	var tg := trees.size() - keep.size()
	trees.clear()
	trees.append_array(keep)
	var canopy: Dictionary = F._canopy
	for key: Vector3i in canopy:
		var cr: Array = canopy[key]
		var left: Array = cr.filter(func(e: Array) -> bool: return not on.call((e[0] as Vector3).x, (e[0] as Vector3).z, CLEAR_TALL))
		if left.size() != cr.size():
			cr.clear()
			cr.append_array(left)
	counts["cleared"] = gone + sg
	print("FLORA wayside ground: %d plants, %d stones, %d tall trees cleared off %d footprints" % [gone, sg, tg, feet.size()])


## One kind's chunks: the instances on a footprint dropped (the buffer compacted). Returns how many went.
static func _clear_store(per: Dictionary, cs: Vector2, name: String, feet: Array[Rect2], touched: Dictionary, on: Callable) -> int:
	var size := cs.x
	var tag := int(cs.y)
	var margin := CLEAR_TALL if tag > 0 else (CLEAR_STONE if name == "" else CLEAR_LOW)
	if not touched.has(cs):
		var keys := {}
		for r: Rect2 in feet:
			var g := r.grow(margin)
			for kz in range(floori(g.position.y / size), floori(g.end.y / size) + 1):
				for kx in range(floori(g.position.x / size), floori(g.end.x / size) + 1):
					keys[Vector3i(kx, kz, tag)] = true
		touched[cs] = keys
	var tk: Dictionary = touched[cs]
	var out := 0
	var sp := name.substr(0, name.rfind("_")) if name != "" else ""
	for key: Vector3i in (per.keys() if per.size() < tk.size() else tk.keys()):
		if not tk.has(key) or not per.has(key):
			continue
		var b: Variant = per[key]
		var f: PackedFloat32Array = b.f
		var n := f.size() / 16
		var kept := PackedFloat32Array()
		var drop := 0
		for i in n:
			var o := i * 16
			if on.call(b.pos.x + f[o + 3], b.pos.z + f[o + 11], margin):
				drop += 1
			else:
				kept.append_array(f.slice(o, o + 16))
		if drop > 0:
			b.f = kept
			out += drop
	if sp != "" and out > 0:
		F.placed[sp] = maxi(int(F.placed.get(sp, 0)) - out, 0)
	return out

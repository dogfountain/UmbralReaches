extends RefCounted
## The enemy camps as places (the camps and villages look checklist). A camp used to be a few foes standing on grass. Once the
## spawner has settled every camp on the final ground (EnemySpawner._settle), each one is dressed by what it is, round its purpose, every prop turned to it:
##   bivouac   a cooking fire in a ring of stones (banked flames and coals, no light), seats round it, lean-to tents behind it with bedrolls under, a store of crates,
##             barrels and sacks, a weapon rack by the approach, hides on a frame in the woods, a cart; big camps add a lookout on the approach and a palisade either
##             side of a gap the way comes through
##   post      a seal's or a garrison's: the lookout, the palisade, two racks, a tent, the fire
##   halt      where a patrol rests: the fire, two seats, a bedroll, a store
##   den       the beasts' (mites, crawlers, burrowers, leapers, gaunts, spitters): a den of branches and ribs, a second for a big pack
##   vigil     the pilgrims' and the ossuants': a ring of headstones turned to a cairn
## Every spot is tested (ground, water, a way, a site, a slope, a collider, the foes' own places and patrol lines, the camp's own props) and a prop with none is dropped,
## so a camp is never made of what the land would not take. All of it is static: one WonderKit per 96 m cell (MultiMeshes, no collision, flames and halos with no
## light), faded at 150 m and the flames at 380 m. Nothing runs per frame. Load by path (no class_name).

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const GroundSeat := preload("res://core/world/realm/ground_seat.gd")
const Props := preload("res://core/world/realm/site_props.gd")
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const WEST := "res://core/world/realm/realm_pois_west_marches.gd"

const CELL := 96.0
const NEAR_END := 150.0
const FLAME_END := 380.0
const OSSUARY := Rect2(-150.0, 60.0, 260.0, 210.0)
const BEASTS := ["mite", "crawler", "burrower", "leaper", "gaunt", "spitter"]
const VIGILS := ["pilgrim", "ossuant"]
const ARMED := ["bulwark", "husk", "chanter", "tollman", "cinder"]
const WOODS := ["thornwood", "lanternwood", "southwood", "kingsbarrows", "quarry"]
const STONES := ["lore_headstone_cross.glb", "lore_headstone_round.glb", "lore_headstone_slab.glb", "lore_headstone_broken.glb"]
const STORE := ["crate.glb", "barrel.glb", "sack.glb", "barrel.glb", "crate_broken.glb", "sack_open.glb", "firewood.glb"]

static var last := ""

var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _kits := {}                         ## cell -> WonderKit
var _pts := {}                          ## glb file -> its footing
var _box := BoxShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()
var _gfn: Callable
var _host: Node3D
var _taken: Array = []                  ## this camp's own footprints: [Vector2, radius]
var _pawns: Array[Vector2] = []
var _route: Array[Vector2] = []
var _west_camps: Array = []
var _props := 0
var _fires := 0
var _skipped := 0
var _dropped := 0
var _bare := 0


## camps: [{center: Vector3, ats: Array[Vector3], kinds: PackedStringArray, seal: String, route: Array[Vector3]}] (EnemySpawner._camp_view)
static func build(host: Node3D, camps: Array) -> void:
	var cd := new()
	await cd._run(host, camps)


func _run(host: Node3D, camps: Array) -> void:
	if "--no-camp-dress" in OS.get_cmdline_user_args() or host == null or host.get_node_or_null("CampDress") != null:
		return
	_host = host
	_space = host.get_world_3d().direct_space_state
	_q.shape = _box
	_q.collision_mask = Layers.WORLD | Layers.PROPS
	_gfn = func(x: float, z: float) -> float:
		var g := _ground(x, z)
		return g if not is_nan(g) else RealmLayout.macro_height(x, z)
	_west_camps = ((load(WEST) as GDScript).get_script_constant_map().get("CAMPS", []) as Array)
	var root := Node3D.new()
	root.name = "CampDress"
	host.add_child(root)
	_host = root
	var t0 := Time.get_ticks_msec()
	var done := 0
	var tree := host.get_tree()
	for c: Dictionary in camps:
		if _dress(c):
			done += 1
		if (done + _skipped) % 5 == 4:
			await tree.process_frame
	for key: Vector2i in _kits:
		var k: WK = _kits[key]
		k.commit(0.0)
		for ch in k.host.get_children():
			var gi := ch as GeometryInstance3D
			if gi == null:
				continue
			var far := String(ch.name) in ["Flames", "FireHalos"]
			gi.visibility_range_end = FLAME_END if far else NEAR_END
			gi.visibility_range_end_margin = 20.0 if far else 12.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		await tree.process_frame
	last = "%d camps dressed (%d skipped, %d of them with no ground for a fire), %d props (%d dropped for want of ground), %d fires in %d kits, %d ms" % [done, _skipped, _bare, _props, _dropped, _fires, _kits.size(), Time.get_ticks_msec() - t0]
	print("CAMP_DRESS ", last)


# --- one camp ---------------------------------------------------------------------------------------------

func _dress(c: Dictionary) -> bool:
	var ctr3: Vector3 = c.center
	var ctr := Vector2(ctr3.x, ctr3.z)
	var rid := String(RealmLayout.region_at(ctr.x, ctr.y).get("id", ""))
	if OSSUARY.has_point(ctr) or rid in ["rift", "summit", "ossuary"] or not RealmLayout.BOUNDS.grow(-10.0).has_point(ctr):
		_skipped += 1
		return false
	for wc: Vector2 in _west_camps:                          # the Marches' seven are dressed by their own builder
		if wc.distance_to(ctr) < 9.0:
			_skipped += 1
			return false
	_taken.clear()
	_pawns.clear()
	_route.clear()
	for a: Vector3 in c.ats:
		_pawns.append(Vector2(a.x, a.z))
	var route: Array = c.get("route", [])
	for i in route.size():
		var p0 := route[i] as Vector3
		var p1 := route[(i + 1) % route.size()] as Vector3
		for k in 4:
			var q := Vector2(p0.x, p0.z).lerp(Vector2(p1.x, p1.z), float(k) / 4.0)
			_route.append(q)
	_rng.seed = hash(Vector2i(roundi(ctr.x * 4.0), roundi(ctr.y * 4.0)))
	var kinds: PackedStringArray = c.kinds
	var n := kinds.size()
	var beasts := 0
	var vigils := 0
	var armed := false
	for kn in kinds:
		var base := kn.get_slice("@", 0)
		if base in BEASTS:
			beasts += 1
		if base in VIGILS:
			vigils += 1
		if base in ARMED:
			armed = true
	var seal := String(c.get("seal", ""))
	var style := "bivouac"
	if seal != "":
		style = "post"
	elif vigils * 2 >= n:
		style = "vigil"
	elif beasts * 2 > n:
		style = "den"
	elif not route.is_empty():
		style = "halt"
	var fwd := _toward_way(ctr)
	var fa := fwd.angle()
	var fire := ctr
	if style in ["bivouac", "post", "halt"]:
		fire = _hearth(ctr)
		if is_nan(fire.x):                                      # no dry, flat, free ground for a fire within 5 m (a mere, a reed bed): nothing is built, a lone crate would be the scatter again
			_skipped += 1
			_bare += 1
			return false
	match style:
		"bivouac":
			_bivouac(fire, fa, n, armed, rid, n >= 4 or (armed and n >= 3), true)
		"post":
			_bivouac(fire, fa, n, true, rid, true, true)
			_one("camp_rack.glb", fire, fa + 2.1, 5.0, 1.3, true)
		"halt":
			_fire(fire, true)
			for a: float in [-1.6, 1.9]:
				_one("camp_log.glb", fire, fa + PI + a, 2.0, 0.8, false, true)
			_one("camp_bedroll.glb", fire, fa + PI, 3.4, 0.7, true)
			_store(fire, fa + PI + 1.1, 5.2, 2)
		"den":
			var base_a := fa + PI
			_one("camp_den.glb", fire, base_a + _rng.randf_range(-0.3, 0.3), 4.6, 1.6, true)
			if n >= 4:
				_one("camp_den.glb", fire, base_a + 2.2, 5.2, 1.6, true)
		"vigil":
			var m := 5 + n
			for i in m:
				var a := fa + TAU * float(i) / float(m) + _rng.randf_range(-0.12, 0.12)
				_stone_at(fire, a, 5.4 + _rng.randf_range(-0.5, 0.9))
	return true


## Where the fire goes: the camp's middle, else the nearest ground that takes a hearth (a lone foe stands on the middle: the fire is beside him).
func _hearth(c: Vector2) -> Vector2:
	for r: float in [0.0, 2.6, 5.0]:
		for k in (1 if r == 0.0 else 8):
			var o := c if r == 0.0 else c + Vector2.from_angle(TAU * float(k) / 8.0 + 0.3) * r
			var crowded := false
			for p: Vector2 in _pawns:
				if p.distance_to(o) < 1.9:
					crowded = true
			if not crowded and not _fits(o, 0.0, 1.2, "").is_empty():
				return o
	return Vector2(NAN, NAN)


## The way the foes face the world: toward the nearest way (where the wanderer comes from), else toward the hub.
func _toward_way(c: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for k in 12:
		var d := Vector2.from_angle(TAU * float(k) / 12.0)
		var pd := RealmLayout.path_dist(c + d * 16.0)
		if pd < bd:
			bd = pd
			best = d
	if bd > 70.0:
		best = (Vector2(0.0, 33.0) - c).normalized()
	return best


func _bivouac(f: Vector2, fa: float, n: int, armed: bool, rid: String, fortified: bool, fire_on: bool) -> void:
	var back := fa + PI
	if fire_on:
		_fire(f, true)
	for a: float in [-1.15, 0.2, 1.4]:                                         # seats round the fire
		_one("camp_log.glb", f, back + a + _rng.randf_range(-0.2, 0.2), 2.05, 0.8, false, true)
	var nt := clampi(ceili(float(n) / 2.0), 1, 3)
	for k in nt:                                                              # tents behind it, a bedroll or two under each
		var a := back + (float(k) - float(nt - 1) * 0.5) * 0.95
		var r := 5.7 + _rng.randf_range(-0.3, 0.5)
		var spot := _spot("camp_tent.glb", f, a, r, 2.0, Vector2(-0.1, 0.0))
		if spot.is_empty():
			continue
		var yaw: float = spot.yaw
		var at: Vector2 = spot.at
		var b := Basis(Vector3.UP, yaw)
		_place("camp_tent.glb", at, yaw, 2.0, spot)
		for sx: float in [-0.7, 0.75]:
			var bp := at + Vector2((b * Vector3(sx, 0.0, 0.15)).x, (b * Vector3(sx, 0.0, 0.15)).z)
			_place_at("camp_bedroll.glb", bp, yaw + _rng.randf_range(-0.1, 0.1), 0.5, true)
		if k == 0 and _rng.randf() < 0.7:
			_store_at(at + Vector2((b * Vector3(2.6, 0.0, 0.8)).x, (b * Vector3(2.6, 0.0, 0.8)).z), yaw)
	if n >= 3:                                                                 # one who sleeps by the fire
		_one("camp_bedroll.glb", f, back + 2.3, 3.5, 0.7, true)
	_store(f, back - 1.9, 6.4, 3 if n >= 3 else 2)
	if armed:
		_one("camp_rack.glb", f, fa + 0.95, 4.7, 1.3, true)
	if rid in WOODS and _rng.randf() < 0.55:
		_one("camp_hides.glb", f, back + 1.2, 6.8, 1.2, true)
	if n >= 3 and _rng.randf() < 0.6:
		_cart(f, back - 2.6, 6.6)
	if fortified:
		_one("camp_watch.glb", f, fa + 0.38, 8.8, 1.9, true)
		for a2: float in [-1.0, -0.6, 0.62, 1.0]:                              # a palisade either side of the gap the way comes through
			_one("camp_stakes.glb", f, fa + a2, 7.6, 1.7, true)


# --- parts ------------------------------------------------------------------------------------------------

func _fire(f0: Vector2, flames: bool) -> void:
	var yaw := _rng.randf() * TAU
	var f := f0
	var chk := {}
	for t in 7:                                               # the middle, else the nearest place beside it
		f = f0 + (Vector2.ZERO if t == 0 else Vector2.from_angle(float(t) * 1.05) * 1.3)
		chk = _fits(f, yaw, 1.2, "camp_spit.glb")
		if not chk.is_empty():
			break
	if chk.is_empty():
		_dropped += 1
		return
	var g: float = chk.g
	_place("camp_spit.glb", f, yaw, 1.2, chk)
	var k := _kit(f)
	k.kit.box("glow", Vector3(f.x, g + 0.09, f.y), Vector3(0.62, 0.05, 0.62), Basis(Vector3.UP, _rng.randf() * TAU), false, 1.0)
	if flames:
		k.fire(Vector3(f.x, g + 0.1, f.y), 0.5, 0.0, false)
		_fires += 1


## A prop at (centre + a ring of radius r at angle a), turned to the centre (or lying tangent), tried at a few nearby places. `inward`: +z to the centre.
func _one(file: String, c: Vector2, a: float, r: float, rad: float, inward: bool, tangent := false) -> bool:
	var s := _spot(file, c, a, r, rad, Vector2.ZERO, tangent if not inward else false)
	if s.is_empty():
		return false
	return _place(file, s.at as Vector2, float(s.yaw), rad, s)


func _spot(file: String, c: Vector2, a: float, r: float, rad: float, _off: Vector2, tangent := false) -> Dictionary:
	for t in 9:
		var aa := a + (0.0 if t == 0 else float((t + 1) / 2) * 0.17 * (1.0 if t % 2 == 1 else -1.0))
		var rr := r + (0.0 if t < 3 else 0.5 * float(t - 2))
		var at := c + Vector2.from_angle(aa) * rr
		var yaw := atan2(c.x - at.x, c.y - at.y)
		if tangent:
			yaw = -(aa + PI * 0.5)
		var chk := _fits(at, yaw, rad, file)
		if not chk.is_empty():
			return {"at": at, "yaw": yaw, "g": chk.g}
	_dropped += 1
	return {}


func _store(c: Vector2, a: float, r: float, count: int) -> void:
	for i in count:
		var file: String = STORE[_rng.randi() % STORE.size()]
		_one(file, c, a + 0.32 * float(i) + _rng.randf_range(-0.05, 0.05), r + _rng.randf_range(-0.2, 0.3), 0.55, false)


func _store_at(p: Vector2, yaw: float) -> void:
	for i in 3:
		var file: String = STORE[_rng.randi() % STORE.size()]
		_place_at(file, p + Vector2(0.9 * float(i) * cos(yaw), -0.9 * float(i) * sin(yaw)) + Vector2(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2)), yaw + _rng.randf_range(-0.6, 0.6), 0.55)


func _cart(c: Vector2, a: float, r: float) -> void:
	var s := _spot("handcart.glb", c, a, r, 1.4, Vector2.ZERO, true)
	if not s.is_empty():
		_place("handcart.glb", s.at as Vector2, float(s.yaw), 1.4, s)


func _stone_at(c: Vector2, a: float, r: float) -> void:
	var file: String = STONES[_rng.randi() % STONES.size()]
	var s := _spot(file, c, a, r, 0.6, Vector2.ZERO)
	if not s.is_empty():
		_place(file, s.at as Vector2, float(s.yaw), 0.6, s)


func _place_at(file: String, at: Vector2, yaw: float, rad: float, nested := false) -> bool:
	var chk := _fits(at, yaw, rad, file, nested)
	if chk.is_empty():
		_dropped += 1
		return false
	return _place(file, at, yaw, rad, {"g": chk.g})


## Test a spot: the ground (and water, slope), a way, a site, the foes' places and patrol, this camp's own props, a collider. {g} if it takes the prop, else {}.
func _fits(at: Vector2, yaw: float, rad: float, _file: String, nested := false) -> Dictionary:
	if not RealmLayout.BOUNDS.grow(-8.0).has_point(at):
		return {}
	var g := _ground(at.x, at.y)
	if is_nan(g) or SpawnRules.water_depth(Vector3(at.x, g, at.y)) > 0.02:
		return {}
	if not nested:                                            # (a bedroll under its tent stands inside the tent's own footprint)
		for t: Array in _taken:
			if (t[0] as Vector2).distance_to(at) < float(t[1]) + rad * 0.85:
				return {}
	for p: Vector2 in _pawns:
		if p.distance_to(at) < rad + 0.7:
			return {}
	for q: Vector2 in _route:
		if q.distance_to(at) < rad + 1.0:
			return {}
	if RealmLayout.path_dist(at) < rad + 0.8 or not WorldLanes.site_at(at, minf(rad, 1.5)).is_empty():
		return {}
	var lo := g
	var hi := g
	for k in 4:
		var o := Vector2.from_angle(float(k) * PI * 0.5 + yaw) * rad * 0.7
		var h := _ground(at.x + o.x, at.y + o.y)
		if is_nan(h):
			return {}
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if hi - lo > 0.35 + rad * 0.3:
		return {}
	_box.size = Vector3(rad * 1.5, 1.3, rad * 1.5)
	_q.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, g + 1.05, at.y))
	for hit: Dictionary in _space.intersect_shape(_q, 8):
		if not String((hit.collider as Node).name).begins_with("Terrain"):
			return {}
	return {"g": g}


func _place(file_glb: String, at: Vector2, yaw: float, rad: float, spot: Dictionary) -> bool:
	var file := file_glb.get_basename()                       # (site_props takes a model's name, not its file)
	var g: float = spot.g
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, g, at.y))
	if not _pts.has(file):
		var meshes: Array = []
		for pd: Dictionary in Props.parts(file):
			meshes.append(pd.mesh)
		_pts[file] = GroundSeat.parts_points("camp:" + file, meshes)
	xf = GroundSeat.seat_pts(_gfn, _pts[file] as PackedVector3Array, xf, 0.6)
	var k := _kit(at)
	k._prec.append([file, xf])
	_taken.append([at, rad])
	_props += 1
	if file == "camp_watch":                              # the lookout's lantern: a lit pane on the hook (no light: the glow shader only)
		var b := xf.basis
		k.kit.box("glow", xf.origin + b * Vector3(0.0, 5.05, 1.05), Vector3(0.2, 0.26, 0.2), b, false, 1.0)
	return true


func _kit(at: Vector2) -> WK:
	var key := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
	if not _kits.has(key):
		var k := WK.new()
		k.setup(_host, "Camps_%d_%d" % [key.x, key.y], 3900 + key.x * 31 + key.y)
		_kits[key] = k
	return _kits[key]


func _ground(x: float, z: float) -> float:
	var ex: Array[RID] = []
	for k in 8:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 160.0, z), Vector3(x, -70.0, z), Layers.WORLD)
		q.exclude = ex
		var hit := _space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN

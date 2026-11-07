extends RefCounted
## Realm module "dress": the clutter of lived-in and fought-over ground, stood after everything else
## is built (so every collider, lane, interactable and nav edge is known): barrels, crates, sacks,
## firewood, benches, troughs, buckets, a handcart, hay, straw and fallen leaves in the squares and
## yards (dress_zones.gd); stones, kindling and leaves round the fire pads; rubble, cracked flagstones,
## bones and dead leaves round the rims of the boss floors; rubble and leaves at the wall's breaches.
## Nothing is placed on a walk lane (the villagers' nav edges, a path, the squares' lanes), near an
## interactable or a fire, on anything that is not bare terrain, or where a collider is. One
## MultiMesh per (zone, kind), no collision, visibility range with fade. Meshes: site_props.gd.
##   godot --path . -- --realm-modules=...,dress   (it needs the village for the lanes)

const Props := preload("res://core/world/realm/site_props.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")
const VillageScript := preload("res://core/life/village/village.gd")

const LANE_MARGIN := 0.9               ## clear of a walk lane's centreline by this plus the prop's radius
const KEEP_OFF := 1.7                  ## from an interactable, a fire, a lamp, a stall
const FOOT := {"crate": 0.45, "barrel": 0.36, "sack": 0.3, "firewood": 0.62, "bench": 0.85, "trough": 0.8, "bucket": 0.2,
	"cart": 1.3, "log": 0.55, "hay": 0.5, "kindling": 0.25, "straw": 0.2, "leaf": 0.2, "flag": 0.55, "flag2": 0.45,
	"rubble": 0.25, "rubble2": 0.25, "stone": 0.32, "stone2": 0.32, "bone": 0.3, "rib": 0.3, "skull": 0.15,
	"stall": 1.5, "stall2": 1.5, "stall3": 1.5, "cross": 1.9, "saltheap": 0.9, "trestle": 0.95, "goods": 1.0, "loadcart": 1.3}
const SMALL := ["straw", "leaf", "kindling", "bucket", "bone", "rib", "skull", "stone", "stone2", "rubble", "rubble2", "flag", "flag2"]
const FLAT := ["straw", "leaf", "flag", "flag2", "kindling"]      ## lie on the ground: slopes do not matter

static var stats: Dictionary = {}      ## zone id -> {kind: count} (last build; tests)
static var build_ms := 0
static var total := 0

static var _space: PhysicsDirectSpaceState3D
static var _walk: Array = []           ## [a Vector2, b Vector2, Rect2 bbox] lane segments (nav edges, the squares' lanes)
static var _avoid: Array[Vector2] = [] ## interactables, fires, lamps, stalls
static var _box := BoxShape3D.new()
static var _q := PhysicsShapeQueryParameters3D.new()
static var _made: Array = []           ## footprints placed in the zone being dressed: [Vector2, radius]
static var _out: Dictionary = {}       ## kind -> Array of [Transform3D, Color] (world)
static var _rng := RandomNumberGenerator.new()


static func build(root: Node) -> void:
	if Zones.off():
		return
	var t0 := Time.get_ticks_msec()
	stats.clear()
	total = 0
	var old := root.get_node_or_null("SiteDress")
	if old:
		old.free()
	await root.get_tree().physics_frame
	_space = (root as Node3D).get_world_3d().direct_space_state
	_q.shape = _box
	_q.collision_mask = Layers.WORLD | Layers.PROPS
	_gather(root)
	var host := Node3D.new()
	host.name = "SiteDress"
	root.add_child(host)
	for sq: Dictionary in Zones.SQUARES:
		_begin(String(sq.id))
		if int(sq.get("market", 0)) > 0:
			_market(sq)
		_square(sq)
		_emit(host, String(sq.id), sq.c)
	var fires: Array[Vector2] = Zones.fire_points()
	for i in fires.size():
		var inside := false
		for sq: Dictionary in Zones.SQUARES:
			if fires[i].distance_to(sq.c) < float(sq.r) + 2.0:
				inside = true
		if inside:
			continue
		_begin("fire_%d" % i)
		_fire_pad(fires[i])
		_emit(host, "fire_%d" % i, fires[i])
	for rd: Dictionary in RealmLayout.RAIDS:
		_begin("raid_" + String(rd.id))
		_raid(rd)
		_emit(host, "raid_" + String(rd.id), rd.c)
	var bi := 0
	for b: Array in Zones.breaches():
		_begin("breach_%d" % bi)
		_breach(b[0])
		_emit(host, "breach_%d" % bi, b[0])
		bi += 1
	_settle_life(host)
	build_ms = Time.get_ticks_msec() - t0
	var line := ""
	for id: String in stats:
		var n := 0
		for k: String in stats[id]:
			n += int(stats[id][k])
		line += "%s %d  " % [id, n]
		total += n
	print("SITE_DRESS %d props in %d ms: %s" % [total, build_ms, line])


# --- what must stay clear ------------------------------------------------------------------------

static func _gather(root: Node) -> void:
	_walk.clear()
	_avoid.clear()
	for l: Array in Zones.lanes():
		_walk.append([l[0], l[1], l[2]])
	var v := root.get_node_or_null("Village") as VillageScript
	if v and v.nav:
		var nav: RefCounted = v.nav
		var nodes: Dictionary = nav.get("nodes")
		var edges: Dictionary = nav.get("edges")
		var seen := {}
		for a: String in edges:
			for b: String in edges[a]:
				if seen.has(b + a):
					continue
				seen[a + b] = true
				var pa := Vector2((nodes[a] as Vector3).x, (nodes[a] as Vector3).z)
				var pb := Vector2((nodes[b] as Vector3).x, (nodes[b] as Vector3).z)
				_walk.append([pa, pb, Rect2(pa.min(pb), (pb - pa).abs()).grow(LANE_MARGIN + 1.6)])
		for id: String in nodes:
			var p := Vector2((nodes[id] as Vector3).x, (nodes[id] as Vector3).z)
			_walk.append([p, p, Rect2(p, Vector2.ZERO).grow(LANE_MARGIN + 1.6)])       # a seat or a post is a lane of length 0
		for key: String in v.anchors:
			var a3: Vector3 = v.anchors[key]
			_avoid.append(Vector2(a3.x, a3.z))
		for id: String in v.lamps:
			var lp: Vector3 = (v.lamps[id] as Dictionary).get("pos", Vector3.INF)
			if lp != Vector3.INF:
				_avoid.append(Vector2(lp.x, lp.z))
	for g: String in [Groups.INTERACTABLE, Groups.BRAZIER, Groups.LIGHT_SOURCE]:
		for n in root.get_tree().get_nodes_in_group(g):
			if n is Node3D:
				var gp := (n as Node3D).global_position
				_avoid.append(Vector2(gp.x, gp.z))
	for p: Dictionary in WorldLanes.portals:
		var at: Vector3 = p.at
		_avoid.append(Vector2(at.x, at.z))
	for f in Zones.fire_points():
		_avoid.append(f)


static func _lane_d(p: Vector2) -> float:
	var best := INF
	for w: Array in _walk:
		if not (w[2] as Rect2).has_point(p):
			continue
		var a: Vector2 = w[0]
		var ab: Vector2 = (w[1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


# --- placing -------------------------------------------------------------------------------------

static func _begin(id: String) -> void:
	_made.clear()
	_out.clear()
	stats[id] = {}
	_rng.seed = hash(id) + 20261107


## Put one prop at xz if the spot is bare terrain, clear of lanes, interactables, colliders and the other
## props. `lift` stands it on something (a second crate). Returns whether it was placed.
static func _put(kind: String, p: Vector2, yaw: float, scale := 1.0, lift := 0.0, tint := 0.1) -> bool:
	var rad: float = float(FOOT.get(kind, 0.4)) * scale
	if lift == 0.0:
		if _lane_d(p) < LANE_MARGIN + rad:
			return false
		for a: Vector2 in _avoid:
			if p.distance_squared_to(a) < (KEEP_OFF + rad * 0.5) * (KEEP_OFF + rad * 0.5):
				return false
		if RealmLayout.path_dist(p) < 1.2 + rad:
			return false
		for m: Array in _made:
			var lim := rad + float(m[1]) * 0.8
			if p.distance_squared_to(m[0] as Vector2) < lim * lim:
				return false
	var hit := _ground(p)
	if hit.is_empty():
		return false
	var nrm: Vector3 = hit.normal
	var y: float = hit.y
	if kind not in FLAT and nrm.y < 0.9:
		return false
	if y < -0.7:
		return false                                   # the fen's water line
	if lift == 0.0 and kind not in FLAT and _blocked(Vector3(p.x, y, p.y), rad):
		return false
	var bas := Basis(Vector3.UP, yaw)
	if kind in FLAT or kind in SMALL:
		bas = Basis(Quaternion(Vector3.UP, nrm.lerp(Vector3.UP, 0.3).normalized())) * bas
	var sink := 0.0
	match kind:
		"rubble", "rubble2", "stone", "stone2":
			sink = -0.09 * scale
		"flag", "flag2":
			sink = -0.05
			bas = bas * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
	var v := _rng.randf_range(1.0 - tint, 1.0 + tint * 0.5)
	var col := Color(v, v, v, 1.0)
	if kind == "sack":
		col = Color(v * _rng.randf_range(0.9, 1.1), v, v * 0.9, 1.0)
	if not _out.has(kind):
		_out[kind] = []
	(_out[kind] as Array).append([Transform3D(bas.scaled(Vector3.ONE * scale), Vector3(p.x, y + sink + lift, p.y)), col])
	if lift == 0.0:
		_made.append([p, rad])
	return true


## {y, normal} of the bare terrain at p, or {} when the first thing hit going down is anything else.
static func _ground(p: Vector2) -> Dictionary:
	var gy := RealmLayout.ground(_space, p.x, p.y)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, gy + 2.2, p.y), Vector3(p.x, gy - 1.2, p.y), Layers.WORLD | Layers.PROPS)
	var h := _space.intersect_ray(ray)
	if h.is_empty():
		return {}
	var c := h.collider as Node
	if c == null or not String(c.name).begins_with("Terrain"):
		return {}
	return {"y": (h.position as Vector3).y, "normal": h.normal}


static func _blocked(p: Vector3, rad: float) -> bool:
	_box.size = Vector3(rad * 2.0 + 0.2, 1.1, rad * 2.0 + 0.2)
	_q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
	for h in _space.intersect_shape(_q, 4):
		var c := h.collider as Node
		if c and not String(c.name).begins_with("Terrain"):
			return true
	return false


static func _ring(c: Vector2, d: float, ang: float) -> Vector2:
	return c + Vector2(cos(ang), sin(ang)) * d


# --- recipes -------------------------------------------------------------------------------------

## A square or yard: stores, firewood, benches and troughs on the rim, straw, leaves and stones over the rest.
static func _square(sq: Dictionary) -> void:
	var c: Vector2 = sq.c
	var r: float = sq.r
	var yard: bool = sq.kind == "yard"
	var clusters := 16 if yard else 12
	var cart_done := String(sq.id) == "hearthward"            # the ash-wife's cart stands there already
	for i in clusters * 3:
		if clusters <= 0:
			break
		var ang := _rng.randf() * TAU
		var p := _ring(c, r * _rng.randf_range(0.45, 1.06), ang)
		var yaw := ang + PI * 0.5 + _rng.randf_range(-0.4, 0.4)
		var pick := _rng.randf()
		var ok := false
		if pick < (0.4 if yard else 0.32):
			ok = _stores(p, yaw, yard)
		elif pick < 0.55:
			ok = _put("firewood", p, yaw) and (_put("log", p + Vector2(1.0, 0.4).rotated(yaw), yaw + 0.5, 0.8) or true)
		elif pick < 0.7:
			ok = _put("bench", p, yaw) and (_put("bucket", p + Vector2(1.1, 0.2).rotated(yaw), 0.0) or true)
		elif pick < 0.8:
			ok = _put("trough", p, yaw) and (_put("bucket", p + Vector2(-1.1, 0.1).rotated(yaw), 0.0) or true)
		elif pick < 0.9 and yard:
			ok = _put("hay", p, yaw) and (_put("hay", p + Vector2(0.9, 0.2).rotated(yaw), yaw + 0.4) or true)
		elif pick < 0.95 and not cart_done:
			cart_done = _put("cart", p, yaw)
			ok = cart_done
		else:
			ok = _put("sack", p, yaw)
		if ok:
			clusters -= 1
	# the loose litter of a used place: straw where goods were handled, leaves in the corners, small stones
	_scatter("straw", c, r * 1.05, 44 if yard else 32, 0.9, 1.7)
	_scatter("leaf", c, r * 1.1, 44, 1.1, 1.9)
	var traded := int(sq.get("market", 0)) > 0
	_scatter("stone", c, r * 1.05, 5 if traded else 20, 0.9, 1.4)      # a market's cobbles are swept: a few stones, not a field of eggs
	_scatter("stone2", c, r * 1.05, 3 if traded else 10, 0.9, 1.3)
	_scatter("kindling", c, r * 0.95, 6, 1.1, 1.5)


## A trading square: a stepped cross near the middle, `market` awninged stalls ringed round it facing in, each with
## a table or a stack of goods in front and salt or sacks beside, a loaded cart or two. Placed before the rest of
## the dressing so the big pieces take their ground first; every one still keeps off lanes, fires and colliders.
static func _market(sq: Dictionary) -> void:
	var c: Vector2 = sq.c
	var r: float = sq.r
	var n := int(sq.market)
	var kinds := ["stall", "stall2", "stall3"]
	for i in 30:
		var q := c + Vector2(_rng.randf_range(-3.5, 3.5), _rng.randf_range(-3.5, 3.5))
		if _put("cross", q, _rng.randf() * TAU, 1.0, 0.0, 0.05):
			break
	var a0 := _rng.randf() * TAU
	var placed := 0
	for i in n * 60:
		if placed >= n:
			break
		var ang := a0 + float(placed) * TAU / float(n) + _rng.randf_range(-0.6, 0.6)
		var p := _ring(c, r * _rng.randf_range(0.5, 0.95), ang)
		var inward := (c - p).normalized()
		var yaw := atan2(inward.x, inward.y) + _rng.randf_range(-0.2, 0.2)
		if not _put(kinds[placed % 3], p, yaw, 1.0, 0.0, 0.06):
			continue
		placed += 1
		var side := Vector2(inward.y, -inward.x)
		_put("trestle" if placed % 2 == 0 else "goods", p + inward * 2.7 + side * _rng.randf_range(-0.6, 0.6), yaw + _rng.randf_range(-0.4, 0.4))
		_put("saltheap" if placed % 3 != 1 else "goods", p + side * (2.5 if placed % 2 == 0 else -2.5) + inward * 0.8, _rng.randf() * TAU)
		_put("sack", p - inward * 1.7 + side * 0.9, _rng.randf() * TAU)
	for i in 2:
		for t in 30:
			if _put("loadcart", _ring(c, r * _rng.randf_range(0.4, 0.8), _rng.randf() * TAU), _rng.randf() * TAU):
				break
	print("MARKET %s: %d of %d stalls stood" % [sq.id, placed, n])
	if String(sq.id) == "saltmarket":
		_scatter("saltheap", c, r * 0.95, 5, 0.8, 1.2)


static func _stores(p: Vector2, yaw: float, yard: bool) -> bool:
	var ok := _put("barrel", p, yaw)
	if _put("barrel", p + Vector2(0.72, 0.1).rotated(yaw), yaw + 1.1, 0.95):
		ok = true
	var crate_at := p + Vector2(0.1, 0.95).rotated(yaw)
	if _put("crate", crate_at, yaw + 0.2, _rng.randf_range(0.9, 1.15)):
		ok = true
		if _rng.randf() < 0.45:
			_put("crate", crate_at, yaw + 0.7, 0.8, 0.6)
	if _put("sack", p + Vector2(-0.7, 0.5).rotated(yaw), yaw + 2.0):
		ok = true
	if yard and _rng.randf() < 0.6:
		_put("sack", p + Vector2(-0.5, 1.2).rotated(yaw), yaw + 0.5)
	return ok


static func _scatter(kind: String, c: Vector2, r: float, n: int, rmin: float, rmax: float) -> void:
	var done := 0
	for i in n * 4:
		if done >= n:
			break
		var p := _ring(c, r * sqrt(_rng.randf_range(rmin * rmin * 0.3, 1.0)), _rng.randf() * TAU)
		if _put(kind, p, _rng.randf() * TAU, _rng.randf_range(rmin + 0.3, rmax), 0.0, 0.18):
			done += 1


## A fire pad: a broken ring of stones, kindling and ash-dark leaves, a log to sit on.
static func _fire_pad(f: Vector2) -> void:
	var a0 := _rng.randf() * TAU
	for i in 8:
		var a := a0 + float(i) * TAU / 8.0 + _rng.randf_range(-0.2, 0.2)
		if _rng.randf() < 0.2:
			continue                                     # a gap: the ring is a camp's, not a wall's
		_put("stone" if i % 3 else "stone2", _ring(f, _rng.randf_range(2.1, 2.9), a), _rng.randf() * TAU, _rng.randf_range(1.3, 2.0))
	_put("log", _ring(f, 2.6, a0 + 1.0), a0 + 1.0 + PI * 0.5, 1.0)
	_put("kindling", _ring(f, 1.8, a0 + 3.0), a0)
	_put("kindling", _ring(f, 2.0, a0 + 4.4), a0 + 1.0)
	_scatter("leaf", f, 4.8, 9, 0.5, 1.1)
	_scatter("straw", f, 4.0, 3, 0.5, 1.0)


## A boss floor's rim: rubble, cracked flagstones, bones and dead leaves in a band along the wall; the
## fighting space (everything inside the band) and the gate stay clear.
static func _raid(rd: Dictionary) -> void:
	var c: Vector2 = rd.c
	var r: float = rd.r
	var gate: Vector2 = rd.gate
	var gate_ang := (gate - c).angle()
	var n := int(r * 1.8)
	var placed := 0
	for i in n * 4:
		if placed >= n:
			break
		var ang := _rng.randf() * TAU
		if absf(angle_difference(ang, gate_ang)) < 0.42:
			continue                                     # the way in stays clear
		var p := _ring(c, r - _rng.randf_range(1.2, 5.0), ang)
		var pick := _rng.randf()
		var ok := false
		if pick < 0.34:
			ok = _put("rubble" if _rng.randf() < 0.6 else "rubble2", p, _rng.randf() * TAU, _rng.randf_range(1.3, 2.4))
			if ok:
				for j in 2:
					_put("rubble", p + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7)), _rng.randf() * TAU, _rng.randf_range(1.0, 1.7))
		elif pick < 0.58:
			ok = _put("flag" if _rng.randf() < 0.6 else "flag2", p, _rng.randf() * TAU, _rng.randf_range(1.2, 1.9))
		elif pick < 0.78:
			var kind: String = ["bone", "rib", "skull", "bone"][_rng.randi() % 4]
			ok = _put(kind, p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
			if ok:
				_put("bone", p + Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)), _rng.randf() * TAU)
		else:
			ok = _put("leaf", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.4))
		if ok:
			placed += 1


## The wall's breach: fallen stones and leaves heaped to either side of the way through.
static func _breach(b: Vector2) -> void:
	for i in 40:
		var p := b + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-7.0, 7.0))
		var pick := _rng.randf()
		if pick < 0.45:
			_put("rubble" if _rng.randf() < 0.6 else "rubble2", p, _rng.randf() * TAU, _rng.randf_range(1.4, 2.8))
		elif pick < 0.6:
			_put("flag" if _rng.randf() < 0.5 else "flag2", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.4))
		elif pick < 0.7:
			_put("stone", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.6))
		else:
			_put("leaf", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.4))
	_scatter("leaf", b, 8.0, 8, 0.5, 1.2)


# --- things that move ----------------------------------------------------------------------------

const WEST := "res://core/world/realm/realm_pois_r37_west.gd"

## Washing lines and banners stirring in the wind (Sway), chimney smoke over Weirford's lived-in houses,
## embers off the forges' hearths. Every one placed where nobody walks, like the clutter.
static func _settle_life(host: Node3D) -> void:
	var life := Node3D.new()
	life.name = "SettleLife"
	host.add_child(life)
	var n_line := 0
	var n_banner := 0
	for sq: Dictionary in Zones.SQUARES:
		_made.clear()
		_rng.seed = hash(String(sq.id)) + 77
		if _line(life, sq.c, sq.r):
			n_line += 1
		if String(sq.id) != "hearthward" and _banner(life, sq.c, sq.r):
			n_banner += 1
	# Weirford's chimneys: the inn, the smithy, the two cottages (the shape of realm_pois_r37_west.gd _house)
	var west: Dictionary = (load(WEST) as GDScript).get_script_constant_map()
	var blds: Dictionary = west.get("BLD", {})
	var n_smoke := 0
	for id: String in ["inn", "smithy", "cot_a", "cot_b"]:
		if not blds.has(id):
			continue
		var d: Dictionary = blds[id]
		var floor_y := NAN
		for st: Dictionary in WorldLanes.sites:
			if st.name == "r37w_" + id:
				floor_y = float(st.floor_y)
		if is_nan(floor_y):
			continue
		var size: Vector2 = d.size
		var h: float = d.h
		var rise := (size.y * 0.5 + 0.7) * tan(deg_to_rad(38.0))
		var b := Basis(Vector3.UP, float(d.yaw))
		var at: Vector2 = d.at
		var top := Vector3(at.x, floor_y, at.y) + b * Vector3(size.x * 0.3, h + rise * 1.35 + 1.5, -size.y * 0.18)
		_emitter(life, "Smoke_" + id, top, Color(0.34, 0.33, 0.34, 0.5), {"count": 7, "life": 4.2, "speed": Vector2(0.2, 0.45), "size": 0.8, "gravity": 0.12, "radius": 0.2, "additive": false, "damping": 0.2})
		n_smoke += 1
	# embers rising from the forges' hearths (Hearthward's, Weirford's smithy)
	var n_ember := 0
	for hp: Vector2 in [Vector2(9.6, 61.3), Vector2(-176.2, 72.6)]:
		var gy := RealmLayout.ground(_space, hp.x, hp.y)
		_emitter(life, "Embers", Vector3(hp.x, gy + 1.0, hp.y), Color(1.0, 0.5, 0.16), {"count": 6, "life": 1.8, "speed": Vector2(0.3, 0.8), "size": 0.035, "gravity": -0.5, "radius": 0.18, "additive": true, "spread": 35.0})
		n_ember += 1
	stats["settle_life"] = {"washing_line": n_line, "banner": n_banner, "chimney_smoke": n_smoke, "forge_embers": n_ember}


static func _emitter(parent: Node3D, nm: String, at: Vector3, col: Color, opts: Dictionary) -> void:
	var p := Vfx.emitter(col, opts)
	if p == null:
		return
	p.name = nm
	parent.add_child(p)
	p.global_position = at
	p.visibility_range_end = 60.0
	p.emitting = true


## A clear spot (ground y or NAN) for something `rad` wide that needs no foot-print kept.
static func _free(p: Vector2, rad: float) -> float:
	if _lane_d(p) < LANE_MARGIN + rad or RealmLayout.path_dist(p) < 1.2 + rad:
		return NAN
	for a: Vector2 in _avoid:
		if p.distance_squared_to(a) < (KEEP_OFF + rad * 0.5) * (KEEP_OFF + rad * 0.5):
			return NAN
	var hit := _ground(p)
	if hit.is_empty() or float(hit.y) < -0.7 or (hit.normal as Vector3).y < 0.9:
		return NAN
	if _blocked(Vector3(p.x, float(hit.y), p.y), rad):
		return NAN
	return float(hit.y)


## A washing line between two posts on the square's rim, three cloths on it.
static func _line(life: Node3D, c: Vector2, r: float) -> bool:
	for i in 60:
		var ang := _rng.randf() * TAU
		var p := _ring(c, r * _rng.randf_range(0.8, 1.15), ang)
		var yaw := _rng.randf() * TAU
		var dir := Vector2(cos(yaw), -sin(yaw))
		var ys: Array[float] = []
		var ok := true
		for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var y := _free(p + dir * 3.2 * t, 0.5)
			if is_nan(y):
				ok = false
				break
			ys.append(y)
		if not ok:
			continue
		var k := OssKit.new()
		k.keep_lanes = false
		var rope_y := 2.1
		for e: int in [0, 4]:
			var q := p + dir * 3.2 * float(e) * 0.25
			k.box("wood", Vector3(q.x, ys[e] + rope_y * 0.5, q.y), Vector3(0.1, rope_y + 0.1, 0.1), Basis.IDENTITY, false, 0.9)
		var mid := p + dir * 1.6
		k.box("iron", Vector3(mid.x, (ys[0] + ys[4]) * 0.5 + rope_y, mid.y), Vector3(0.02, 0.02, 3.2), Basis(Vector3.UP, yaw + PI * 0.5), false, 0.7)
		k.commit(life, "LineBody")
		for f: float in [0.12, 0.42, 0.7]:
			var q2 := p + dir * 3.2 * f
			Sway.flag(life, Vector3(q2.x, ys[0] + rope_y - 0.5, q2.y), yaw, "plaster", Vector2(0.7, 0.95), 4)
		_made.append([p + dir * 1.6, 2.0])
		return true
	return false


## A banner on a pole.
static func _banner(life: Node3D, c: Vector2, r: float) -> bool:
	for i in 60:
		var p := _ring(c, r * _rng.randf_range(0.6, 1.0), _rng.randf() * TAU)
		var y := _free(p, 0.7)
		if is_nan(y):
			continue
		var k := OssKit.new()
		k.keep_lanes = false
		k.box("wood", Vector3(p.x, y + 1.6, p.y), Vector3(0.1, 3.2, 0.1), Basis.IDENTITY, false, 0.9)
		k.commit(life, "BannerBody")
		Sway.flag(life, Vector3(p.x + 0.05, y + 2.9, p.y), _rng.randf() * TAU, "plaster", Vector2(0.75, 1.1), 5)
		return true
	return false


# --- emit ----------------------------------------------------------------------------------------

## One node at the zone's centre (visibility range measures to the node origin) with a MultiMesh per kind.
static func _emit(host: Node3D, id: String, c: Vector2) -> void:
	if _out.is_empty():
		return
	var gy := RealmLayout.ground(_space, c.x, c.y)
	var zone := Node3D.new()
	zone.name = "Dress_" + id
	host.add_child(zone)
	zone.position = Vector3(c.x, gy, c.y)
	for kind: String in _out:
		var list: Array = _out[kind]
		var d := Props.get_prop(kind)
		if d.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = d.mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i][0]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - zone.position))
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Dress_" + kind
		mmi.multimesh = mm
		if d.mat:
			mmi.material_override = d.mat
		var small := kind in SMALL
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(d.shadow) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 2.0
		mmi.visibility_range_end = 46.0 if small else 80.0
		mmi.visibility_range_end_margin = 5.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_meta("site_owned", true)
		mmi.add_to_group(Groups.CULL_SKIP)
		zone.add_child(mmi)
		stats[id][kind] = list.size()

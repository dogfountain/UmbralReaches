extends RefCounted
## West Marches (docs/r37_expansion.md): the places of Weirford, the Sorrow's Banks, the Fallen Hierarch
## and the Siege Lines, in the manner of realm_pois_r34.gd: ground reserved before the stamp and the flora
## (reserve), the places built after them (build), everything placed by ground ray, never fixed heights.
##
##   weirford_bridge   the stone bridge on the Pilgrims' Road over the Sorrow (r37_bridge.glb)
##   weirford_mill     the mill on the weir, its wheel turning (r37_mill.glb)
##   weirford_town     the inn (The Grey Heron), the smithy, two cottages, the stables, the square's well and
##                     stall, the watch hut: lit windows (no lights), people (village_cast_r37_west.gd)
##   sorrow_shrine     the drowned shrine in the river (a secret: site_r37_west.gd), a chest, fords and posts
##   hierarch_statue   the Fallen Hierarch (r37_statue.glb): the skull's floor is the Speaking Crown's room
##   hierarch_hand     the open hand, palm up: steps up to it, a chest on the palm
##   siege_line        the outer earthwork's palisade and gate, a chest-high stair to the rampart
##   siege_trebs       three rotted trebuchets
##   siege_tower       a four-storey siege tower you can climb (its stairs are built in), a chest at the top
## Same API as the Realm's other places (groups "world_poi", "loot_chest"; every host carries meta "region").
## Built by realm_pois.gd. No class_name: preload by path.

const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/r37_west_kit.gd")
const Raid := preload("res://core/world/hierarch_raid.gd")

const WATER := -0.9

## The statue: the skull's centre is the Fallen Hierarch's raid floor (RealmLayout RAIDS "hierarch"), the
## body lies away from it along BODY_DIR (xz), the model's +X. The gate faces the way the weir track arrives.
const HEAD_C := Vector2(-214.0, -104.0)
const BODY_DIR := Vector2(-0.35, 0.94)
const FLOOR_Y := 4.0
const HAND_LOCAL := Vector3(38.0, 2.7, 37.5)          ## the palm's top, model frame in Godot axes (x along the body, z = -Blender y)

## id -> {at, size (footprint, local x by z), yaw, h (wall height), region, title, line, kind}
const BLD := {
	"inn": {"at": Vector2(-186.0, 56.0), "size": Vector2(13.0, 9.0), "yaw": 0.0, "h": 3.4, "roof": "slate", "wall": "plaster", "glow": 4, "region": "weirford"},
	"smithy": {"at": Vector2(-174.0, 75.0), "size": Vector2(8.0, 6.0), "yaw": PI, "h": 3.0, "roof": "slate", "wall": "brick", "glow": 1, "open": true, "region": "weirford"},
	"cot_a": {"at": Vector2(-165.0, 59.0), "size": Vector2(6.5, 5.0), "yaw": 0.0, "h": 2.7, "roof": "wood", "wall": "plaster", "glow": 1, "region": "weirford"},
	"cot_b": {"at": Vector2(-158.0, 74.0), "size": Vector2(6.0, 5.0), "yaw": PI, "h": 2.7, "roof": "wood", "wall": "plaster", "glow": 1, "region": "weirford"},
	"stables": {"at": Vector2(-224.0, 78.0), "size": Vector2(12.0, 7.0), "yaw": PI * 0.5, "h": 3.0, "roof": "wood", "wall": "wood", "glow": 0, "open": true, "region": "weirford"},
	"watch_hut": {"at": Vector2(-230.0, 61.0), "size": Vector2(5.0, 4.0), "yaw": 0.0, "h": 2.6, "roof": "wood", "wall": "wood", "glow": 1, "region": "weirford"},
	"mill_house": {"at": Vector2(-221.5, 52.5), "size": Vector2(11.0, 9.5), "yaw": 0.0, "h": 0.0, "region": "weirford"},
}

const POIS := {
	"weirford_bridge": {"at": Vector2(-206.0, 65.6), "title": "Weirford Bridge", "line": "the last bridge the Order did not burn", "region": "weirford", "r": 16.0},
	"weirford_mill": {"at": Vector2(-214.0, 52.5), "title": "The Weir Mill", "line": "it ground the abbey's flour, and kept its head down", "region": "weirford", "r": 14.0},
	"weirford_town": {"at": Vector2(-190.0, 66.0), "title": "Weirford", "line": "warm, and wary", "region": "weirford", "r": 26.0},
	"sorrow_shrine": {"at": Vector2(-208.0, -40.0), "title": "The Drowned Shrine", "line": "the river came to see it, and stayed", "region": "sorrow", "r": 9.0, "wet": true},
	"hierarch_statue": {"at": HEAD_C, "title": "The Fallen Hierarch", "line": "he was raised taller than the Stair", "region": "hierarch", "r": 34.0},
	"hierarch_hand": {"at": Vector2(-236.0, -84.0), "title": "The Hierarch's Hand", "line": "palm up, as if for a coin", "region": "hierarch", "r": 7.0},
	"siege_line": {"at": Vector2(-214.0, 120.0), "title": "The Outer Earthwork", "line": "the Marches dug in here, and then dug in deeper", "region": "siege", "r": 22.0},
	"siege_trebs": {"at": Vector2(-190.0, 208.0), "title": "The Trebuchet Line", "line": "every arm cocked toward the gates", "region": "siege", "r": 18.0},
	"siege_tower": {"at": Vector2(-236.0, 170.0), "title": "The Siege Tower", "line": "four floors, and the gate it never reached", "region": "siege", "r": 10.0},
}

const LOOT := {
	"sorrow_shrine": ["reliquary", {"grave_ash": 18, "relic_fragment": 1}],
	"hierarch_hand": ["iron", {"grave_ash": 16, "relic_fragment": 1}],
	"hierarch_crown": ["reliquary", {"grave_ash": 28, "relic_fragment": 2, "ember_shard": 2}],
	"siege_tower_top": ["iron", {"grave_ash": 15, "grave_iron": 2, "relic_fragment": 1}],
	"weirford_loft": ["wood", {"grave_ash": 9, "grave_iron": 1}],
	"siege_camp": ["wood", {"grave_ash": 8, "grave_iron": 1}],
}

## The Marches camps' dressing: lean-to + cold ring + a bedroll or two (EnemySpawner.REALM_CAMPS holds the foes).
const CAMPS := [Vector2(-232.0, 0.0), Vector2(-178.0, -50.0), Vector2(-178.0, -124.0), Vector2(-180.0, 150.0), Vector2(-240.0, 218.0),
	Vector2(-248.0, -116.0), Vector2(-222.0, 190.0), Vector2(-196.0, 228.0)]

static var spots := {}                   ## id -> {at: Vector3, yaw, rect}
static var built: Array[String] = []
static var arena: Node = null            ## the Speaking Crown's BossArena (tests)


static func release() -> void:
	spots.clear()
	arena = null
	Kit.release()


static func body_yaw() -> float:
	return atan2(-BODY_DIR.y, BODY_DIR.x)


static func _bx(ctr: Vector2, half: Vector2) -> Rect2:
	return Rect2(ctr - half, half * 2.0)


static func _footprint(d: Dictionary) -> Rect2:
	var s: Vector2 = d.size
	var half := s * 0.5 + Vector2(1.6, 1.6)
	if absf(sin(float(d.yaw))) > 0.7:
		half = Vector2(half.y, half.x)
	return _bx(d.at, half)


# --- reserve (before the stamp and the flora) ---------------------------------------------------

static func reserve(root: Node) -> void:
	spots.clear()
	for a in OS.get_cmdline_user_args():
		if a == "--no-r37-west":
			return
	var space := (root as Node3D).get_world_3d().direct_space_state
	for id: String in BLD:
		var d: Dictionary = BLD[id]
		var rc := _footprint(d)
		var lo := INF
		var hi := -INF
		for ix in 5:
			for iz in 5:
				var gy := RealmLayout.ground(space, rc.position.x + rc.size.x * ix * 0.25, rc.position.y + rc.size.y * iz * 0.25)
				lo = minf(lo, gy)
				hi = maxf(hi, gy)
		spots["bld_" + id] = {"at": Vector3(d.at.x, lo, d.at.y), "yaw": float(d.yaw), "rect": rc}
		WorldLanes.register_site("r37w_" + id, rc, lo + 0.05, lo)
	WorldLanes.register_lane("r37w_bridge", [Vector2(-224.0, 65.6), Vector2(-188.0, 65.6)], 3.4)
	WorldLanes.register_lane("r37w_weir", [Vector2(-215.0, 52.5), Vector2(-199.0, 52.5)], 3.0)
	Flora.tree_clear.append([Vector2(-200.0, 66.0), 30.0])
	# the statue's body and arm lie on the land as it is: no cut, nothing grows on them
	var yaw := body_yaw()
	var dir := BODY_DIR.normalized()
	var right := Vector2(-dir.y, dir.x)
	for i in 5:
		var c := HEAD_C + dir * (28.0 + 7.5 * float(i))
		var rc2 := _bx(c, Vector2(11.0, 11.0))
		WorldLanes.register_site("r37w_body_%d" % i, rc2, _hi(space, rc2), _hi(space, rc2) + 1.0)
	var hand := _hand_xz()
	var arm := _bx((HEAD_C + dir * 40.0 + hand) * 0.5, Vector2(18.0, 18.0))
	WorldLanes.register_site("r37w_arm", arm, _hi(space, arm), _hi(space, arm) + 1.0)
	Flora.tree_clear.append([HEAD_C + dir * 30.0, 34.0])
	# the siege tower and the trebuchets: levelled pads
	var tw := _bx(Vector2(-236.0, 170.0), Vector2(7.5, 7.5))
	var tlo := _lo(space, tw)
	WorldLanes.register_site("r37w_tower", tw, tlo + 0.05, tlo)
	for i in 3:
		var tc := _bx(Vector2(-204.0 + 14.0 * float(i), 206.0 + 4.0 * float(i % 2)), Vector2(8.0, 5.0))
		var tl := _lo(space, tc)
		WorldLanes.register_site("r37w_treb_%d" % i, tc, tl + 0.05, tl)
	Flora.tree_clear.append([Vector2(-236.0, 170.0), 14.0])
	Flora.tree_clear.append([Vector2(-196.0, 208.0), 22.0])
	print("REALM_POI r37 west reserved %s" % [spots.keys()])


static func _hi(space: PhysicsDirectSpaceState3D, rc: Rect2) -> float:
	var hi := -INF
	for ix in 4:
		for iz in 4:
			hi = maxf(hi, RealmLayout.ground(space, rc.position.x + rc.size.x * ix / 3.0, rc.position.y + rc.size.y * iz / 3.0))
	return hi


static func _lo(space: PhysicsDirectSpaceState3D, rc: Rect2) -> float:
	var lo := INF
	for ix in 4:
		for iz in 4:
			lo = minf(lo, RealmLayout.ground(space, rc.position.x + rc.size.x * ix / 3.0, rc.position.y + rc.size.y * iz / 3.0))
	return lo


## The palm's xz in the world (model (38, 37.5) in x-along-body / lateral terms).
static func _hand_xz() -> Vector2:
	var b := Basis(Vector3.UP, body_yaw())
	var w := b * Vector3(HAND_LOCAL.x, 0.0, HAND_LOCAL.z)
	return HEAD_C + Vector2(w.x, w.z)


static func _g(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


# --- build (after the flora) ------------------------------------------------------------------------

static func build(holder: Node3D) -> void:
	built.clear()
	var space := holder.get_world_3d().direct_space_state
	for id: String in POIS:
		var d: Dictionary = POIS[id]
		var at: Vector2 = d.at
		var host := Node3D.new()
		host.name = "Poi_" + id
		host.set_meta("site", "poi_" + id)
		holder.add_child(host)
		host.global_position = Vector3(at.x, _g(space, at.x, at.y), at.y)
		host.add_to_group("world_poi")
		host.set_meta("poi", id)
		host.set_meta("title", d.title)
		host.set_meta("line", d.line)
		host.set_meta("region", d.region)
		host.set_meta("centre", host.global_position)
		host.set_meta("radius", float(d.r))
		host.set_meta("r37", true)
		match id:
			"weirford_bridge": _bridge(host, space)
			"weirford_mill": _mill(host, space)
			"weirford_town": _town(host, space)
			"sorrow_shrine": _shrine(host, space)
			"hierarch_statue": _statue(host, space)
			"hierarch_hand": _hand(host, space)
			"siege_line": _siege_line(host, space)
			"siege_trebs": _trebs(host, space)
			"siege_tower": _tower(host, space)
		built.append(id)
	_camps(holder, space)
	print("REALM_POI r37 west built %s" % [built])


# --- shared pieces ------------------------------------------------------------------------------

static func _chest(host: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


## An inscription (lore_db entry `id`) standing at `at`.
static func _lore(host: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	host.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


static func _kit() -> OssKit:
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	return k


## A gabled building in local space (+z the front, rotated by yaw): a stone course, walls with a door in the
## front, a roof of two slabs, gable fills, a chimney. `o`: wall (OssKit key), roof (key), glow (lit window
## panes on the front), open (no front wall: a forge, a stable), door_w. Walls are solid, the floor is the
## levelled ground (the site cut it).
static func _house(k: OssKit, base: Vector3, yaw: float, size: Vector2, h: float, o: Dictionary) -> void:
	var b := Basis(Vector3.UP, yaw)
	var w := size.x
	var d := size.y
	var t := 0.32
	var wall: String = o.get("wall", "plaster")
	var roof: String = o.get("roof", "slate")
	var dw := float(o.get("door_w", 1.4))
	var open := bool(o.get("open", false))
	k.box("stone", base + b * Vector3(0, 0.32, -d * 0.5 + t * 0.5), Vector3(w + 0.2, 0.64, t + 0.12), b, true, 0.8)
	k.box("stone", base + b * Vector3(-w * 0.5 + t * 0.5, 0.32, 0), Vector3(t + 0.12, 0.64, d), b, true, 0.8)
	k.box("stone", base + b * Vector3(w * 0.5 - t * 0.5, 0.32, 0), Vector3(t + 0.12, 0.64, d), b, true, 0.8)
	k.box(wall, base + b * Vector3(0, 0.64 + (h - 0.64) * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h - 0.64, t), b, true, 0.9)
	k.box(wall, base + b * Vector3(-w * 0.5 + t * 0.5, 0.64 + (h - 0.64) * 0.5, 0), Vector3(t, h - 0.64, d), b, true, 0.9)
	k.box(wall, base + b * Vector3(w * 0.5 - t * 0.5, 0.64 + (h - 0.64) * 0.5, 0), Vector3(t, h - 0.64, d), b, true, 0.9)
	if open:
		# a half wall and two corner posts at the front; a beam across
		for sx: float in [-1.0, 1.0]:
			k.box("wood", base + b * Vector3(sx * (w * 0.5 - 0.2), h * 0.5, d * 0.5 - 0.2), Vector3(0.34, h, 0.34), b, true, 0.75)
		k.box("wood", base + b * Vector3(0, h - 0.15, d * 0.5 - 0.2), Vector3(w, 0.3, 0.3), b, false, 0.8)
	else:
		var seg := (w - dw) * 0.5
		for sx: float in [-1.0, 1.0]:
			k.box(wall, base + b * Vector3(sx * (dw * 0.5 + seg * 0.5), 0.64 + (h - 0.64) * 0.5, d * 0.5 - t * 0.5), Vector3(seg, h - 0.64, t), b, true, 0.9)
			k.box("stone", base + b * Vector3(sx * (dw * 0.5 + seg * 0.5), 0.32, d * 0.5 - t * 0.5), Vector3(seg + 0.1, 0.64, t + 0.12), b, true, 0.8)
		k.box("wood", base + b * Vector3(0, 2.3 + (h - 2.3) * 0.5, d * 0.5 - t * 0.5), Vector3(dw + 0.2, h - 2.3, t), b, true, 0.8)
	# timber frame on the front and back
	for x: float in [-w * 0.5 + 0.15, w * 0.5 - 0.15]:
		k.box("wood", base + b * Vector3(x, h * 0.5, d * 0.5 - 0.08), Vector3(0.22, h, 0.14), b, false, 0.75)
	k.box("wood", base + b * Vector3(0, h - 0.1, d * 0.5 - 0.06), Vector3(w + 0.1, 0.2, 0.16), b, false, 0.8)
	# lit windows: warm panes proud of the front (no lights; the glow mat sits just over the threshold)
	var nglow := int(o.get("glow", 0))
	for i in nglow:
		var x := (float(i) - float(nglow - 1) * 0.5) * (w / float(nglow + 1)) * 1.2 + (0.0 if nglow > 1 else -w * 0.28)
		if absf(x) < dw * 0.5 + 0.7 and not open:
			x = signf(x if x != 0.0 else 1.0) * (dw * 0.5 + 1.1)
		k.box("glow", base + b * Vector3(x, 1.7, d * 0.5 + 0.02), Vector3(0.9, 0.7, 0.05), b, false, 1.0)
		k.box("wood", base + b * Vector3(x, 1.7, d * 0.5 + 0.0), Vector3(1.1, 0.9, 0.06), b, false, 0.6)
	# roof: two slabs and the gable fills
	var pitch := deg_to_rad(36.0)
	var run := d * 0.5 + 0.55
	var slope_len := run / cos(pitch)
	var rise := run * tan(pitch)
	for s: float in [-1.0, 1.0]:
		var c := b * Vector3(0, h + rise * 0.5 - 0.05, s * (d * 0.25 + 0.2))
		k.box(roof, base + c, Vector3(w + 1.0, 0.16, slope_len), b * Basis(Vector3.RIGHT, s * pitch), false, 0.85)
	k.box("wood", base + b * Vector3(0, h + rise - 0.02, 0), Vector3(w + 1.1, 0.22, 0.28), b, false, 0.7)
	for j in 3:
		var hw := (d - 0.6) * (1.0 - float(j) / 3.2)
		k.box(wall, base + b * Vector3(-w * 0.5 + t * 0.5, h + 0.3 + 0.6 * float(j), 0), Vector3(t, 0.6, hw), b, false, 0.85)
		k.box(wall, base + b * Vector3(w * 0.5 - t * 0.5, h + 0.3 + 0.6 * float(j), 0), Vector3(t, 0.6, hw), b, false, 0.85)
	k.box("stone", base + b * Vector3(w * 0.3, h + rise * 0.7, -d * 0.2), Vector3(0.9, rise * 1.3, 0.9), b, true, 0.8)


static func _building(host: Node3D, space: PhysicsDirectSpaceState3D, id: String) -> Vector3:
	var d: Dictionary = BLD[id]
	var rc := _footprint(d)
	var lo := INF
	for ix in 5:
		for iz in 5:
			lo = minf(lo, _g(space, rc.position.x + rc.size.x * ix * 0.25, rc.position.y + rc.size.y * iz * 0.25))
	var at := Vector3(d.at.x, lo, d.at.y)
	var k := _kit()
	_house(k, at, float(d.yaw), d.size, float(d.h), d)
	k.commit(host, "Bld_" + id)
	return at


## Barrels and crates in a corner: small boxes, no fuss.
static func _clutter(k: OssKit, base: Vector3, yaw: float, rng: RandomNumberGenerator, n: int, spread: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for i in n:
		var p := b * Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
		var s := rng.randf_range(0.5, 0.85)
		if rng.randf() < 0.5:
			k.box("wood", base + p + Vector3(0, s * 0.5, 0), Vector3(s * 0.8, s, s * 0.8), Basis(Vector3.UP, rng.randf() * TAU), true, 0.8)
			k.box("iron", base + p + Vector3(0, s * 0.3, 0), Vector3(s * 0.86, 0.05, s * 0.86), Basis(Vector3.UP, 0.0), false, 0.7)
		else:
			k.box("wood", base + p + Vector3(0, s * 0.45, 0), Vector3(s, s * 0.9, s), Basis(Vector3.UP, rng.randf() * TAU), true, 0.75)


# --- Weirford -------------------------------------------------------------------------------------

static func _bridge(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var ge := _g(space, -190.0, 65.6)
	var gw := _g(space, -222.0, 65.6)
	var y := maxf(ge, gw) - 0.05
	Kit.place(host, "r37_bridge.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(-206.0, y, 65.6)))
	host.set_meta("approach", Vector3(-192.0, ge, 65.6))
	_lore(host, "r37w_bridge", Vector3(-193.5, y + 1.0, 63.6), Vector3(-193.5, y + 1.0, 63.6))


static func _mill(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var y := _g(space, -221.5, 52.5)
	var root := Kit.place(host, "r37_mill.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(-207.0, y, 52.5)), {"spin": "Wheel", "spin_rate": 0.55})
	if root:
		host.set_meta("walk", [false])
	# the mill's door faces the road: a lit window pane on the south wall and a sack-hoist's landing
	var k := _kit()
	k.box("glow", Vector3(-221.5, y + 5.0, 56.45), Vector3(0.9, 0.7, 0.05), Basis.IDENTITY, false, 1.0)
	k.box("glow", Vector3(-218.0, y + 5.0, 56.45), Vector3(0.9, 0.7, 0.05), Basis.IDENTITY, false, 1.0)
	k.commit(host, "MillGlow")
	_chest(host, "weirford_loft", Vector3(-224.5, y + 3.6, 50.5), 0.4)
	_lore(host, "r37w_mill", Vector3(-217.0, y + 1.0, 57.0), Vector3(-217.0, y + 1.0, 57.0))


static func _town(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37001
	var ats := {}
	for id: String in BLD:
		if id == "mill_house":
			continue
		ats[id] = _building(host, space, id)
	# the inn's sign and the smithy's anvil are in the people's routines; here the dressing
	var k := _kit()
	var inn: Vector3 = ats.inn
	k.box("wood", inn + Vector3(-3.4, 2.6, 4.9), Vector3(0.1, 1.9, 0.1), Basis.IDENTITY, false, 0.7)      # the sign's post
	k.box("wood", inn + Vector3(-2.7, 3.2, 4.9), Vector3(1.5, 0.12, 0.1), Basis.IDENTITY, false, 0.7)
	k.box("wood", inn + Vector3(-2.7, 2.6, 4.9), Vector3(0.9, 0.8, 0.07), Basis.IDENTITY, false, 0.6)
	_clutter(k, inn + Vector3(5.6, 0, 3.6), 0.0, rng, 6, 1.1)
	var sm: Vector3 = ats.smithy
	k.box("iron", sm + Vector3(0.6, 0.55, -1.2), Vector3(0.9, 0.5, 0.45), Basis.IDENTITY, true, 0.7)      # the anvil
	k.box("stone", sm + Vector3(-2.2, 0.5, -1.8), Vector3(1.4, 1.0, 1.1), Basis.IDENTITY, true, 0.8)      # the forge's hearth
	k.box("glow", sm + Vector3(-2.2, 1.02, -1.78), Vector3(0.8, 0.04, 0.6), Basis.IDENTITY, false, 1.0)   # coals
	_clutter(k, sm + Vector3(3.2, 0, 1.5), PI, rng, 4, 0.7)
	var st: Vector3 = ats.stables
	for i in 3:
		k.box("wood", st + Basis(Vector3.UP, PI * 0.5) * Vector3(-3.6 + 3.6 * float(i), 0.9, -0.2), Vector3(0.18, 1.8, 3.2), Basis(Vector3.UP, PI * 0.5), true, 0.75)   # stall partitions
	k.box("wood", st + Vector3(3.1, 0.35, 0.0), Vector3(1.0, 0.7, 2.2), Basis.IDENTITY, true, 0.8)       # a hay bale stack outside
	# the square: a covered well, a stall, benches, a notice post
	var sq := Vector3(-196.0, _g(space, -192.0, 74.0), 74.0)
	var well := Vector3(-191.0, _g(space, -191.0, 78.0), 78.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.box("stone", well + Vector3(cos(a) * 0.9, 0.5, sin(a) * 0.9), Vector3(0.7, 1.0, 0.45), Basis(Vector3.UP, -a), true, 0.85)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", well + Vector3(sx * 0.95, 1.6, 0), Vector3(0.14, 2.2, 0.14), Basis.IDENTITY, false, 0.7)
	k.box("wood", well + Vector3(0, 2.7, 0), Vector3(2.2, 0.12, 0.2), Basis.IDENTITY, false, 0.7)
	k.box("slate", well + Vector3(0, 2.95, 0), Vector3(2.4, 0.1, 1.5), Basis(Vector3.RIGHT, 0.0), false, 0.8)
	var stall := Vector3(-184.0, _g(space, -184.0, 72.5), 72.5)
	k.box("wood", stall + Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 0.9), Basis.IDENTITY, true, 0.8)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", stall + Vector3(sx * 1.4, 1.2, -0.5), Vector3(0.12, 2.4, 0.12), Basis.IDENTITY, false, 0.7)
	k.box("plaster", stall + Vector3(0, 2.5, -0.1), Vector3(3.1, 0.07, 1.6), Basis(Vector3.RIGHT, -0.18), false, 0.75)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", sq + Vector3(sx * 1.6 - 3.0, 0.3, 2.4), Vector3(0.1, 0.6, 0.5), Basis.IDENTITY, false, 0.7)
	k.box("wood", sq + Vector3(-3.0, 0.62, 2.4), Vector3(3.4, 0.1, 0.5), Basis.IDENTITY, true, 0.75)
	# lamp posts on the bridge's east end and the square: lit glass, no light
	for lp: Vector2 in [Vector2(-193.2, 63.7), Vector2(-193.2, 67.5), Vector2(-199.5, 71.0), Vector2(-218.8, 63.7), Vector2(-218.8, 67.5)]:
		var lg := _g(space, lp.x, lp.y)
		k.box("iron", Vector3(lp.x, lg + 1.5, lp.y), Vector3(0.1, 3.0, 0.1), Basis.IDENTITY, false, 0.7)
		k.box("glow", Vector3(lp.x, lg + 3.1, lp.y), Vector3(0.28, 0.34, 0.28), Basis.IDENTITY, false, 1.0)
		k.box("iron", Vector3(lp.x, lg + 3.34, lp.y), Vector3(0.4, 0.06, 0.4), Basis.IDENTITY, false, 0.7)
	k.commit(host, "TownDressing")
	_lore(host, "r37w_inn", inn + Vector3(-5.5, 1.1, 5.3), inn + Vector3(-5.5, 1.1, 5.3))
	_lore(host, "r37w_notice", sq + Vector3(-5.5, 1.1, -5.0), sq + Vector3(-5.5, 1.1, -5.0))
	_lore(host, "r37w_smith", sm + Vector3(-4.4, 1.1, 3.4), sm + Vector3(-4.4, 1.1, 3.4))
	host.set_meta("route", [Vector3(-186.0, inn.y, 61.0)])
	host.set_meta("walk", [true])


# --- the Sorrow's Banks ---------------------------------------------------------------------------------

static func _shrine(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var at := Vector3(-208.0, _g(space, -208.0, -40.0), -40.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37002
	var k := _kit()
	# a roofless little shrine on a plinth in the shallows: four piers, a broken arch, a stone altar, a leaning saint
	var base := at + Vector3(0, 0.05, 0)
	k.box("ruin", base + Vector3(0, 0.2, 0), Vector3(6.6, 0.5, 6.6), Basis.IDENTITY, true, 0.8)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box("stone", base + Vector3(sx * 2.6, 1.9, sz * 2.6), Vector3(0.8, 3.4, 0.8), Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), true, 0.85)
	k.box("stone", base + Vector3(0, 3.6, -2.6), Vector3(5.4, 0.7, 0.8), Basis.IDENTITY, true, 0.82)       # the lintel over the back, the front's gone
	k.box("stone", base + Vector3(-1.6, 3.6, 2.6), Vector3(1.9, 0.7, 0.8), Basis(Vector3.UP, 0.0), true, 0.8)
	k.box("stone", base + Vector3(0, 0.9, -1.4), Vector3(2.0, 0.9, 1.0), Basis.IDENTITY, true, 0.9)      # the altar
	k.box("stone", base + Vector3(0.0, 1.9, -1.4), Vector3(0.7, 1.2, 0.5), Basis(Vector3.RIGHT, 0.2), true, 0.85)   # the saint, toppled forward
	for i in 5:
		var s := rng.randf_range(0.5, 1.0)
		k.box("ruin", base + Vector3(rng.randf_range(-4.5, 4.5), 0.2, rng.randf_range(-4.5, 4.5)), Vector3(s, s * 0.6, s), Basis(Vector3.UP, rng.randf() * TAU), false, 0.8)
	k.commit(host, "ShrineBody")
	# fords: pairs of marker posts with a rope hook, on weir_track where it crosses and at two more banks
	for fp: Vector2 in [Vector2(-196.0, -66.0), Vector2(-190.0, -22.0), Vector2(-206.0, 20.0)]:
		for sx: float in [-1.0, 1.0]:
			var gx := fp.x + sx * 5.2
			var gy := _g(space, gx, fp.y)
			k.box("wood", Vector3(gx, gy + 1.1, fp.y), Vector3(0.16, 2.4, 0.16), Basis.IDENTITY, false, 0.7)
			k.box("iron", Vector3(gx, gy + 2.2, fp.y), Vector3(0.3, 0.05, 0.05), Basis.IDENTITY, false, 0.7)
	k.commit(host, "FordPosts")
	_chest(host, "sorrow_shrine", base + Vector3(1.6, 1.4, 0.4), 0.0)
	_lore(host, "r37w_shrine", base + Vector3(-2.2, 1.2, 3.4), base + Vector3(-2.2, 1.2, 3.4))
	host.set_meta("wet", true)
	host.set_meta("approach", Vector3(-202.0, _g(space, -202.0, -37.0), -37.0))


# --- the Fallen Hierarch -------------------------------------------------------------------------------

static func _statue(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var yaw := body_yaw()
	var origin := Vector3(HEAD_C.x, FLOOR_Y - 0.15, HEAD_C.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), origin)
	# the near model (the engine's own mesh LODs) fades out where the far mesh takes over
	var near := Kit.place(host, "r37_statue.glb", xf, {"range_end": 420.0})
	if near:
		near.name = "Statue"
	var far := Kit.place(host, "r37_statue_far.glb", xf, {"shadow": false})
	if far:
		far.name = "StatueFar"
		far.set_meta("far_mesh", true)             # the Foundation's far-detail hook finds it by this meta
		for mi in far.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			m.visibility_range_begin = 330.0
			m.visibility_range_begin_margin = 40.0
			m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for b in far.find_children("*", "StaticBody3D", true, false):
			b.queue_free()                         # the far copy is only to look at
	# the arena: the floor inside the skull; its mouth is the gate toward the weir track
	var c := Vector3(HEAD_C.x, FLOOR_Y, HEAD_C.y)
	var raid := RealmLayout.raid("hierarch")
	var gate2: Vector2 = raid.gate
	var out := (gate2 - HEAD_C).normalized()
	var mouth := c + Vector3(out.x, 0.0, out.y) * 21.0
	mouth.y = _g(space, mouth.x, mouth.z)
	var room: Node3D = Raid.new()
	room.name = "HierarchRoom"
	host.add_child(room)
	room.global_position = c
	room.set("centre", c)
	room.set("radius", 20.0)
	var spawn := c - Vector3(out.x, 0.0, out.y) * 5.0 + Vector3.UP * 0.1
	var ar: BossArena = BossArena.make(host, "r37_hierarch", "The Speaking Crown", c, 20.0, HierarchVoice, spawn)
	ar.room = room
	ar.ceiling = 26.0
	ar.subtitle = "the Hierarch's voice, kept in his head"
	var gate := WardSeal.make_arena_gate(host, "hierarch", mouth, Vector3(-out.x, 0.0, -out.y), 12.0, 6.0, "light")
	ar.gate = gate
	ar.on_slain = func(fresh: bool) -> void:
		if fresh:
			Events.toast.emit("The horn goes quiet. The skull is only stone.")
		var sp := RealmLayout.ground(host.get_world_3d().direct_space_state, c.x + out.x * 3.0, c.z + out.y * 3.0)
		if host.get_node_or_null("Chest_hierarch_crown") == null:
			_chest(host, "hierarch_crown", Vector3(c.x + out.x * 3.0, sp, c.z + out.y * 3.0), 0.0)
	arena = ar
	# cover on the floor: three fallen tines (stone slabs on edge), solid, so the Echo's feet and the
	# Toll's gaps have something to be read against; the mouth's inside edge is lit by the horn's ember
	var k := _kit()
	for i in 3:
		var a := TAU * (float(i) + 0.4) / 3.0
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 12.0
		var pg := _g(space, p.x, p.z)
		var bb := Basis(Vector3.UP, a + 0.4) * Basis(Vector3.FORWARD, 0.18)
		k.box("lore_tstone", Vector3(p.x, pg + 2.4, p.z), Vector3(1.8, 4.8, 1.2), bb, true, 0.9)
	k.commit(host, "CrownTines")
	_lore(host, "r37w_statue", Vector3(HEAD_C.x + out.x * 24.5, _g(space, HEAD_C.x + out.x * 24.5, HEAD_C.y + out.y * 24.5) + 1.1, HEAD_C.y + out.y * 24.5 + 2.5), Vector3(HEAD_C.x + out.x * 24.5, FLOOR_Y + 1.1, HEAD_C.y + out.y * 24.5))
	host.set_meta("approach", mouth)
	host.set_meta("boss", "r37_hierarch")


static func _hand(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var hx := _hand_xz()
	var origin_y := FLOOR_Y - 0.15
	var palm := Vector3(hx.x, origin_y + HAND_LOCAL.y, hx.y)
	host.global_position = palm
	host.set_meta("centre", palm)
	var k := _kit()
	var b := Basis(Vector3.UP, body_yaw())
	# a stair of fallen blocks up to the palm from the open (finger) side, so the hand can be walked onto
	var from := palm + b * Vector3(0.0, 0.0, 6.2)
	var g0 := _g(space, from.x, from.z)
	var rise := palm.y - g0 - 0.2
	var n := clampi(ceili(rise / 0.42), 1, 14)
	for i in n:
		var t := float(i + 1) / float(n)
		var p := from.lerp(palm + b * Vector3(0, 0, 3.4), float(i) / float(n)) + b * Vector3(3.0, 0, 0)
		k.box("ruin", Vector3(p.x, g0 + rise * t * 0.5 - 0.1, p.z), Vector3(1.8, rise * t + 0.2, 1.4), b, true, 0.85)
	k.commit(host, "HandSteps")
	_chest(host, "hierarch_hand", palm + b * Vector3(0.0, 0.1, 0.4), body_yaw())
	_lore(host, "r37w_hand", palm + b * Vector3(-1.5, 0.9, -1.2), palm + b * Vector3(-1.5, 0.9, -1.2))
	host.set_meta("approach", Vector3(from.x, g0, from.z))


# --- the Siege Lines --------------------------------------------------------------------------------------

static func _siege_line(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37003
	var gate_at := Vector2(-214.0, 116.0)
	var gy := _g(space, gate_at.x, gate_at.y)
	Kit.place(host, "r37_palisade.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(gate_at.x, gy, gate_at.y)), {"pick": "PalGate", "shift": Vector3(26.0, 0.0, 0.0)})
	var variants := ["PalA", "PalA", "PalB", "PalA", "PalC", "PalB", "PalA", "PalA"]
	var shifts := {"PalA": 0.0, "PalB": 8.0, "PalC": 16.0}
	for side: float in [-1.0, 1.0]:
		for i in 8:
			var x := gate_at.x + side * (5.0 + 4.2 * float(i)) - side * 0.0
			var z := gate_at.y + 0.02 * float(i) * float(i) * rng.randf_range(0.6, 1.4)
			var gg := _g(space, x, z)
			var v: String = variants[(i + (0 if side < 0.0 else 3)) % variants.size()]
			Kit.place(host, "r37_palisade.glb", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(x, gg - 0.05, z)), {"pick": v, "shift": Vector3(float(shifts[v]), 0.0, 0.0), "range_end": 260.0})
	# a second, shorter line south on the track, and stakes scattered in front of the gate
	for i in 5:
		var z2 := 138.0 + 4.2 * float(i)
		var x2 := -218.0 + 1.5 * float(i)
		var g2 := _g(space, x2, z2)
		Kit.place(host, "r37_palisade.glb", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x2, g2 - 0.05, z2)), {"pick": "PalB" if i % 2 == 0 else "PalA", "shift": Vector3(8.0 if i % 2 == 0 else 0.0, 0.0, 0.0), "range_end": 260.0})
	var k := _kit()
	for i in 14:
		var p := Vector2(gate_at.x + rng.randf_range(-14.0, 14.0), gate_at.y - rng.randf_range(3.0, 11.0))
		var pg := _g(space, p.x, p.y)
		k.box("wood", Vector3(p.x, pg + 0.6, p.y), Vector3(0.14, 1.4, 0.14), Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.3, 0.6)), false, 0.7)
	k.commit(host, "Stakes")
	_lore(host, "r37w_siege_line", Vector3(gate_at.x + 5.0, gy + 1.1, gate_at.y - 3.0), Vector3(gate_at.x + 5.0, gy + 1.1, gate_at.y - 3.0))


static func _trebs(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	for i in 3:
		var x := -204.0 + 14.0 * float(i)
		var z := 206.0 + 4.0 * float(i % 2)
		var gy := _lo(space, _bx(Vector2(x, z), Vector2(8.0, 5.0)))
		var fallen := i == 1
		Kit.place(host, "r37_trebuchet.glb", Transform3D(Basis(Vector3.UP, -PI * 0.25 + 0.1 * float(i)), Vector3(x, gy + 0.05, z)),
			{"pick": "TrebB" if fallen else "TrebA", "shift": Vector3(30.0 if fallen else 0.0, 0.0, 0.0), "range_end": 300.0})
	_lore(host, "r37w_trebs", Vector3(-194.0, _g(space, -194.0, 200.0) + 1.1, 200.0), Vector3(-194.0, _g(space, -194.0, 200.0) + 1.1, 200.0))


static func _tower(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rc := _bx(Vector2(-236.0, 170.0), Vector2(7.5, 7.5))
	var gy := _lo(space, rc)
	var at := Vector3(-236.0, gy - 0.1, 170.0)
	Kit.place(host, "r37_siege_tower.glb", Transform3D(Basis(Vector3.UP, -PI * 0.5), at), {"range_end": 400.0})
	# its top: the platform (z 14.4 in the model) is 14.4 m over the wheels' foot
	_chest(host, "siege_tower_top", at + Vector3(0.0, 14.6, 0.0), -PI * 0.5)
	var fb := Basis(Vector3.UP, -PI * 0.5)                # the tower's open face (model +Y, Godot -Z) looks east, toward the Realm
	host.set_meta("route", [at + fb * Vector3(0.0, 0.2, -13.0), at + Vector3(0.0, 14.5, 0.0)])
	host.set_meta("walk", [true, true])
	host.set_meta("approach", at + fb * Vector3(0.0, 0.0, -13.0))
	_lore(host, "r37w_tower", at + fb * Vector3(-3.4, 1.0, -6.0), at + fb * Vector3(-3.4, 1.0, -6.0))


# --- camps' dressing ---------------------------------------------------------------------------------------

static func _camps(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var host := Node3D.new()
	host.name = "R37WestCamps"
	host.set_meta("site", "r37w_camps")
	holder.add_child(host)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37004
	var k := _kit()
	for c: Vector2 in CAMPS:
		var gy := _g(space, c.x, c.y)
		var yaw := rng.randf() * TAU
		var b := Basis(Vector3.UP, yaw)
		var base := Vector3(c.x, gy, c.y)
		# a lean-to: two poles and a slanted hide, a cold ring of stones, a bedroll, a pack
		k.box("wood", base + b * Vector3(-1.4, 0.9, 2.6), Vector3(0.1, 1.8, 0.1), b, false, 0.7)
		k.box("wood", base + b * Vector3(1.4, 0.9, 2.6), Vector3(0.1, 1.8, 0.1), b, false, 0.7)
		k.box("plaster", base + b * Vector3(0, 0.95, 3.1), Vector3(3.2, 0.06, 1.7), b * Basis(Vector3.RIGHT, 0.6), false, 0.55)
		for i in 8:
			var a := TAU * float(i) / 8.0
			k.box("ruin", base + Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3(0.3, 0.22, 0.3), Basis(Vector3.UP, a), false, 0.7)
		k.box("wax", base + b * Vector3(0.6, 0.08, 1.9), Vector3(0.7, 0.14, 1.9), b * Basis(Vector3.UP, 0.1), false, 0.7)
		k.box("wood", base + b * Vector3(-0.9, 0.2, 1.7), Vector3(0.5, 0.4, 0.4), b, false, 0.7)
	k.commit(host, "CampDressing")
	_chest(host, "siege_camp", Vector3(CAMPS[3].x + 2.0, _g(space, CAMPS[3].x + 2.0, CAMPS[3].y + 1.0), CAMPS[3].y + 1.0), 0.3)

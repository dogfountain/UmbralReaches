extends RefCounted
## West Marches (docs/r37_expansion.md): the places of Weirford, the Sorrow's Banks, the Fallen Hierarch
## and the Siege Lines, in the manner of realm_pois_doubled_realm.gd: ground reserved before the stamp and the flora
## (reserve), the places built after them (build), everything placed by ground ray, never fixed heights.
##
##   weirford_bridge   the stone bridge on the Pilgrims' Road over the Sorrow (r37_bridge.glb)
##   weirford_mill     the mill on the weir, its wheel turning (r37_mill.glb)
##   weirford_town     the inn (The Grey Heron), the smithy, two cottages, the stables, the square's well and
##                     stall, the watch hut: lit windows (no lights), people (village_cast_west_marches.gd)
##   sorrow_shrine     the drowned shrine in the river (a secret: site_west_marches.gd), a chest, fords and posts
##   hierarch_*        the Fallen Hierarch in the Siege Lines, his hand, and his empty plinth in the old valley
##                     (realm_pois_hierarch.gd builds them; the POIS entries stay here)
##   siege_line        the inner earthwork's palisade arcs and the north gate, ringing the fallen Hierarch
##   siege_trebs       three rotted trebuchets behind the palisade, every arm cocked on the skull
##   siege_tower       a four-storey siege tower you can climb (its stairs are built in), a chest at the top; its
##                     ramp runs down toward the skull
## Same API as the Realm's other places (groups "world_poi", "loot_chest"; every host carries meta "region").
## Built by realm_pois.gd. No class_name: preload by path.

const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const Hearth := preload("res://core/world/realm/cottage_hearth.gd")
const Hier := preload("res://core/world/realm/realm_pois_hierarch.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")

const WATER := -0.9

## id -> {at, size (footprint, local x by z), yaw, h (wall height), region, title, line, kind}
const BLD := {
	"inn": {"at": Vector2(-186.0, 56.0), "size": Vector2(13.0, 9.0), "yaw": 0.0, "h": 3.4, "roof": "slate", "wall": "brick", "glow": 4, "region": "weirford"},
	"smithy": {"at": Vector2(-174.0, 75.0), "size": Vector2(8.0, 6.0), "yaw": PI, "h": 3.0, "roof": "slate", "wall": "brick", "glow": 1, "open": true, "region": "weirford"},
	"cot_a": {"at": Vector2(-165.0, 59.0), "size": Vector2(6.5, 5.0), "yaw": 0.0, "h": 2.7, "roof": "wood", "wall": "brick", "glow": 1, "region": "weirford"},
	"cot_b": {"at": Vector2(-158.0, 74.0), "size": Vector2(6.0, 5.0), "yaw": PI, "h": 2.7, "roof": "wood", "wall": "brick", "glow": 1, "region": "weirford"},
	"stables": {"at": Vector2(-196.0, 92.0), "size": Vector2(12.0, 7.0), "yaw": PI * 0.5, "h": 3.0, "roof": "wood", "wall": "wood", "glow": 0, "open": true, "region": "weirford"},
	"watch_hut": {"at": Vector2(-230.0, 61.0), "size": Vector2(5.0, 4.0), "yaw": 0.0, "h": 2.6, "roof": "wood", "wall": "wood", "glow": 1, "region": "weirford"},
	"mill_house": {"at": Vector2(-221.5, 58.0), "size": Vector2(11.0, 9.5), "yaw": 0.0, "h": 0.0, "region": "weirford"},
}

const POIS := {
	"weirford_bridge": {"at": Vector2(-208.0, 65.6), "title": "Weirford Bridge", "line": "the last bridge the Order did not burn", "region": "weirford", "r": 16.0},
	"weirford_mill": {"at": Vector2(-214.0, 58.0), "title": "The Weir Mill", "line": "it ground the abbey's flour, and kept its head down", "region": "weirford", "r": 14.0},
	"weirford_town": {"at": Vector2(-190.0, 66.0), "title": "Weirford", "line": "warm, and wary", "region": "weirford", "r": 26.0},
	"sorrow_shrine": {"at": Vector2(-208.0, -40.0), "title": "The Drowned Shrine", "line": "the river came to see it, and stayed", "region": "sorrow", "r": 9.0, "wet": true},
	"hierarch_statue": {"at": Hier.HEAD_C, "title": "The Fallen Hierarch", "line": "he was raised taller than the Stair", "region": "siege", "r": 34.0},
	"hierarch_hand": {"at": Hier.HEAD_C + Vector2(-26.0, 46.0), "title": "The Hierarch's Hand", "line": "palm up, as if for a coin", "region": "siege", "r": 7.0},
	"hierarch_plinth": {"at": Hier.PLINTH_C, "title": "The Empty Plinth", "line": "his feet are still on it", "region": "plinth", "r": 26.0},
	"siege_line": {"at": Vector2(-206.0, 110.0), "title": "The Outer Earthwork", "line": "the Marches dug in here, and then dug in deeper", "region": "siege", "r": 22.0},
	"siege_trebs": {"at": Vector2(-200.0, 114.0), "title": "The Trebuchet Line", "line": "every arm cocked on the giant", "region": "siege", "r": 18.0},
	"siege_tower": {"at": TOWER_AT, "title": "The Siege Tower", "line": "four floors, and a giant to climb", "region": "siege", "r": 10.0},
}

const LOOT := {
	"sorrow_shrine": ["reliquary", {"grave_ash": 18, "relic_fragment": 1}],
	"siege_tower_top": ["iron", {"grave_ash": 15, "grave_iron": 2, "relic_fragment": 1}],
	"weirford_loft": ["wood", {"grave_ash": 9, "grave_iron": 1}],
	"siege_camp": ["wood", {"grave_ash": 8, "grave_iron": 1}],
}

## The Marches camps' dressing: lean-to + cold ring + a bedroll or two (EnemySpawner.REALM_CAMPS holds the foes).
const CAMPS := [Vector2(-232.0, 0.0), Vector2(-178.0, -50.0), Vector2(-187.0, -102.0), Vector2(-240.0, 168.0), Vector2(-240.0, 218.0),
	Vector2(-216.0, 226.0), Vector2(-196.0, 230.0)]

## The Siege Lines' engines, drawn up round the fallen Hierarch (HEAD_C): the trebuchets stand behind the palisade
## (xz, each aimed at the skull), the siege tower on the east flank with its ramp running down toward the skull.
const TREBS := [Vector2(-230.0, 118.0), Vector2(-196.0, 113.0), Vector2(-185.0, 116.0)]
const TOWER_AT := Vector2(-172.0, 128.0)
const RING_R := 46.0                     ## the inner earthwork's radius round the skull (RealmLayout.SIEGE_RINGS)

static var spots := {}                   ## id -> {at: Vector3, yaw, rect}
static var built: Array[String] = []
static var deck_rect := Rect2()          ## the bridge's walkable deck (xz) ...
static var deck_y := 0.0                 ## ... and its top: the walking network floors it (people cross the Sorrow)
static var arena: Node = null            ## the Speaking Crown's BossArena (tests)


static func release() -> void:
	spots.clear()
	deck_rect = Rect2()
	arena = null
	Kit.release()


## The walkable decks for the villagers' nav (village_nav.gd decks): [] until the bridge is built.
static func decks() -> Array:
	if deck_rect.size == Vector2.ZERO:
		return []
	return [{"rect": deck_rect, "y": deck_y}]


static func _bx(ctr: Vector2, half: Vector2) -> Rect2:
	return Rect2(ctr - half, half * 2.0)


## A building as built: BLD's design, with the scale pilot's plot and proportions over it ("s": its scale about its foot).
static func bld(id: String) -> Dictionary:
	return Pilot.bld(id, BLD[id])


static func _footprint(d: Dictionary) -> Rect2:
	var s: Vector2 = (d.size as Vector2) * float(d.get("s", 1.0))
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
		var d: Dictionary = bld(id)
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
	var bk := Pilot.BRIDGE if Pilot.on() else Vector3.ONE
	WorldLanes.register_lane("r37w_bridge", [Vector2(-208.0 - 16.0 * bk.x, 65.6), Vector2(-208.0 + 18.0 * bk.x, 65.6)], 3.4 * bk.z)
	WorldLanes.register_lane("r37w_weir", [Vector2(-215.0, 58.0), Vector2(-199.0, 58.0)], 3.0)
	Flora.tree_clear.append([Vector2(-200.0, 66.0), 30.0])
	Hier.reserve(space)
	# the siege tower and the trebuchets: levelled pads
	var tw := _bx(TOWER_AT, Vector2(7.5, 7.5))
	var tlo := _lo(space, tw)
	WorldLanes.register_site("r37w_tower", tw, tlo + 0.05, tlo)
	for i in TREBS.size():
		var tc := _bx(TREBS[i], Vector2(8.0, 8.0))
		var tl := _lo(space, tc)
		WorldLanes.register_site("r37w_treb_%d" % i, tc, tl + 0.05, tl)
	Flora.tree_clear.append([TOWER_AT, 14.0])
	Flora.tree_clear.append([TREBS[1], 28.0])
	print("REALM_POI r37 west reserved %s" % [spots.keys()])


static func _lo(space: PhysicsDirectSpaceState3D, rc: Rect2) -> float:
	var lo := INF
	for ix in 4:
		for iz in 4:
			lo = minf(lo, RealmLayout.ground(space, rc.position.x + rc.size.x * ix / 3.0, rc.position.y + rc.size.y * iz / 3.0))
	return lo


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
		host.add_to_group("world_poi")
		host.set_meta("poi", id)
		host.set_meta("title", d.title)
		host.set_meta("line", d.line)
		host.set_meta("region", d.region)
		host.set_meta("centre", Vector3(at.x, _g(space, at.x, at.y), at.y))
		host.set_meta("radius", float(d.r))
		host.set_meta("r37", true)
		match id:
			"weirford_bridge": _bridge(host, space)
			"weirford_mill": _mill(host, space)
			"weirford_town": _town(host, space)
			"sorrow_shrine": _shrine(host, space)
			"hierarch_statue": arena = Hier.statue(host, space)
			"hierarch_hand": Hier.hand(host, space)
			"hierarch_plinth": Hier.plinth(host, space)
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
	c.set("big", lerpf(1.0, Pilot.PROP, Pilot.weight(at.x, at.z)))
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


## An inscription (lore_db entry `id`) standing at `at`.
static func _lore(host: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	host.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


static func _kit() -> Pilot.SKit:
	LK.ensure_mats()
	var k := Pilot.SKit.new()
	k.keep_lanes = false
	return k


## Our own wall materials for OssKit (world-triplanar over the tiling sets): coursed, irregular ashlar for walls
## (calm: no per-brick bevel) and weathered boards for frames, doors and shutters.
static func _mats() -> void:
	if OssKit._mats.has("r37_wall"):
		return
	OssKit._mats["r37_plaster"] = Hearth.plaster()
	for pair: Array in [["r37_wall", "ashlar", 0.22], ["r37_board", "timber", 0.5]]:
		var m := Kit.mat(String(pair[1])).duplicate() as StandardMaterial3D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 6.0
		m.uv1_scale = Vector3.ONE * float(pair[2])
		OssKit._mats[String(pair[0])] = m
	Pilot.ensure_mats()


## A window in the front wall (local +z face): stone sill and lintel, timber frame, a mullion and a transom, four small
## panes with the glow behind them (recessed, so it reads as light through glass), shutters standing ajar.
static func _window(k: OssKit, base: Vector3, b: Basis, x: float, y: float, z: float, lit: bool) -> void:
	k.box("stone", base + b * Vector3(x, y - 0.55, z + 0.1), Vector3(1.3, 0.12, 0.3), b, false, 0.85)
	k.box("stone", base + b * Vector3(x, y + 0.55, z + 0.04), Vector3(1.3, 0.14, 0.2), b, false, 0.85)
	k.box("wood", base + b * Vector3(x, y, z - 0.02), Vector3(0.96, 0.96, 0.05), b, false, 0.35)
	if lit:
		for sx: float in [-0.21, 0.21]:
			for sy: float in [-0.21, 0.21]:
				k.box("glow", base + b * Vector3(x + sx, y + sy, z + 0.01), Vector3(0.36, 0.36, 0.03), b, false, 1.0)
	for sx: float in [-0.48, 0.48]:
		k.box("r37_board", base + b * Vector3(x + sx, y, z + 0.05), Vector3(0.09, 1.0, 0.1), b, false, 0.8)
	for sy: float in [-0.5, 0.5]:
		k.box("r37_board", base + b * Vector3(x, y + sy, z + 0.05), Vector3(1.0, 0.09, 0.1), b, false, 0.8)
	k.box("r37_board", base + b * Vector3(x, y, z + 0.06), Vector3(0.06, 1.0, 0.08), b, false, 0.8)
	k.box("r37_board", base + b * Vector3(x, y, z + 0.06), Vector3(1.0, 0.06, 0.08), b, false, 0.8)
	for sx: float in [-1.0, 1.0]:
		k.box("r37_board", base + b * Vector3(x + sx * 0.82, y, z + 0.08), Vector3(0.5, 1.0, 0.06), b * Basis(Vector3.UP, sx * 0.9), false, 0.7)


## The street lanterns: (x, z, facing). lanterns() is the list as built (the scale pilot stands them at the wider bridge's ends).
const LANTERNS := [Vector3(-195.0, 63.7, PI), Vector3(-195.0, 67.5, 0.0), Vector3(-199.5, 71.0, 0.0), Vector3(-221.0, 63.7, PI), Vector3(-221.0, 67.5, 0.0)]


static func lanterns() -> Array:
	return Pilot.LANTERNS if Pilot.on() else LANTERNS


## An iron lantern on a post with a bracket: cage bars, cold glass inside, a cap and a ring.
static func _lantern(k: Pilot.SKit, at: Vector3, face: float) -> void:
	k.at(at, Pilot.prop(), false)
	var b := Basis(Vector3.UP, face)
	k.box("iron", at + Vector3(0, 0.12, 0), Vector3(0.28, 0.24, 0.28), Basis.IDENTITY, false, 0.7)
	k.box("iron", at + Vector3(0, 1.6, 0), Vector3(0.09, 3.2, 0.09), Basis.IDENTITY, false, 0.7)
	k.box("iron", at + b * Vector3(0, 3.1, 0.3), Vector3(0.06, 0.06, 0.6), b, false, 0.7)
	k.box("iron", at + b * Vector3(0, 3.35, 0.14), Vector3(0.05, 0.4, 0.05), b, false, 0.7)
	var lp := at + b * Vector3(0, 2.8, 0.6)
	k.box("dark", lp, Vector3(0.22, 0.36, 0.22), Basis.IDENTITY, false, 0.5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box("iron", lp + Vector3(sx * 0.13, 0, sz * 0.13), Vector3(0.035, 0.42, 0.035), Basis.IDENTITY, false, 0.7)
	k.box("iron", lp + Vector3(0, -0.24, 0), Vector3(0.32, 0.04, 0.32), Basis.IDENTITY, false, 0.7)
	k.box("iron", lp + Vector3(0, 0.26, 0), Vector3(0.3, 0.08, 0.3), Basis(Vector3.UP, 0.78), false, 0.7)
	k.box("iron", lp + Vector3(0, 0.38, 0), Vector3(0.12, 0.1, 0.12), Basis.IDENTITY, false, 0.7)


## A gabled building in local space (+z the front, rotated by yaw) on a level stone plinth: coursed walls, a framed
## door (lintel, jambs, plank leaf with a strap, step), timber framing on every wall, windows (_window), a thick roof
## with eaves, under-boarding, fascia and ridge tiles, and a chimney with a drip course, a cap and pots.
## `o`: roof, glow (windows lit), open (a forge, a stable: no front wall), door_w.
static func _house(k: OssKit, base: Vector3, yaw: float, size: Vector2, h: float, o: Dictionary) -> void:
	_mats()
	var b := Basis(Vector3.UP, yaw)
	var w := size.x
	var d := size.y
	var t := 0.34
	var wall := "r37_wall"
	var roof: String = o.get("roof", "slate")
	var dw := float(o.get("door_w", 1.4))
	var dh := float(o.get("door_h", 2.4))            # the door's head (design metres over the foot)
	var big := float(o.get("s", 1.0)) > 1.01         # the scale pilot: the floor slab is the floor, and steps reach it
	var open := bool(o.get("open", false))
	k.box("stone", base + b * Vector3(0, -0.5, 0), Vector3(w + 0.7, 1.4, d + 0.7), b, true, 0.78)
	var y0 := 0.66 if big else 0.9                   # scaled, the slot between the floor and the wall's foot would show: the wall stands on the floor
	var wh := h - y0 + 0.2
	k.box(wall, base + b * Vector3(0, y0 + wh * 0.5, -d * 0.5 + t * 0.5), Vector3(w, wh, t), b, true, 0.9)
	k.box(wall, base + b * Vector3(-w * 0.5 + t * 0.5, y0 + wh * 0.5, 0), Vector3(t, wh, d), b, true, 0.9)
	k.box(wall, base + b * Vector3(w * 0.5 - t * 0.5, y0 + wh * 0.5, 0), Vector3(t, wh, d), b, true, 0.9)
	k.box("stone", base + b * Vector3(0, 0.6, 0), Vector3(w + 0.3, 0.12, d + 0.3), b, big, 0.8)
	if open:
		if big:                                       # three full-width steps up to the floor (each under the nav's 0.32 m)
			for i in 3:
				k.box("stone", base + b * Vector3(0, 0.165 * float(i + 1) - 0.4, d * 0.5 + 0.325 + 0.45 * float(2 - i)), Vector3(w + 0.3, 0.8, 0.45), b, true, 0.85)
		for sx: float in [-1.0, 1.0]:
			k.box("r37_board", base + b * Vector3(sx * (w * 0.5 - 0.2), h * 0.5 + 0.5, d * 0.5 - 0.2), Vector3(0.36, h, 0.36), b, true, 0.8)
		k.box("r37_board", base + b * Vector3(0, h - 0.1, d * 0.5 - 0.2), Vector3(w, 0.34, 0.34), b, false, 0.8)
		for sx: float in [-1.0, 1.0]:
			k.box("r37_board", base + b * Vector3(sx * (w * 0.5 - 0.9), h - 0.6, d * 0.5 - 0.2), Vector3(0.16, 1.1, 0.16), b * Basis(Vector3(0, 0, 1), sx * 0.7), false, 0.8)
	else:
		var seg := (w - dw) * 0.5
		for sx: float in [-1.0, 1.0]:
			k.box(wall, base + b * Vector3(sx * (dw * 0.5 + seg * 0.5), y0 + wh * 0.5, d * 0.5 - t * 0.5), Vector3(seg, wh, t), b, true, 0.9)
		k.box(wall, base + b * Vector3(0, dh + (h + 0.2 - dh) * 0.5 + 0.1, d * 0.5 - t * 0.5), Vector3(dw + 0.3, h - dh + 0.2, t), b, true, 0.9)
		for sx: float in [-1.0, 1.0]:
			k.box("r37_board", base + b * Vector3(sx * (dw * 0.5 + 0.08), (dh + 0.8) * 0.5, d * 0.5 + 0.03), Vector3(0.16, dh - 0.1, 0.14), b, false, 0.85)
		k.box("r37_board", base + b * Vector3(0, dh, d * 0.5 + 0.03), Vector3(dw + 0.4, 0.18, 0.16), b, false, 0.85)
		k.box("stone", base + b * Vector3(0, dh + 0.15, d * 0.5 + 0.04), Vector3(dw + 0.7, 0.16, 0.26), b, false, 0.85)
		k.box("r37_board", base + b * Vector3(-dw * 0.25, (dh - 0.1) * 0.5, d * 0.5 - 0.18), Vector3(dw * 0.5, dh - 0.1, 0.08), b * Basis(Vector3.UP, -1.0), false, 0.65)
		k.box("iron", base + b * Vector3(-dw * 0.25, dh - 0.5, d * 0.5 - 0.12), Vector3(dw * 0.46, 0.08, 0.04), b * Basis(Vector3.UP, -1.0), false, 0.7)
		# two low risers up to the door (each a body's step high: the people's nav climbs 0.32 m at most)
		k.box("stone", base + b * Vector3(0, 0.33, d * 0.5 + 0.35), Vector3(dw + 0.5, 0.28, 0.7), b, true, 0.85)
		k.box("stone", base + b * Vector3(0, -0.06, d * 0.5 + 1.0), Vector3(dw + 0.9, 0.68, 0.6), b, true, 0.85)
		if big:                                   # scaled, the lowest riser is too tall for a body's step: one more under it
			k.box("stone", base + b * Vector3(0, -0.2, d * 0.5 + 1.6), Vector3(dw + 1.3, 0.68, 0.6), b, true, 0.85)
	for x: float in [-w * 0.5, w * 0.5]:
		for z: float in [-d * 0.5, d * 0.5]:
			k.box("r37_board", base + b * Vector3(x, h * 0.5 + 0.3, z), Vector3(0.3, h + 0.2, 0.3), b, false, 0.8)
	for z: float in [-d * 0.5 - 0.02, d * 0.5 + 0.02]:
		k.box("r37_board", base + b * Vector3(0, h + 0.05, z), Vector3(w + 0.3, 0.26, 0.2), b, false, 0.8)
		k.box("r37_board", base + b * Vector3(0, dh - 0.2, z), Vector3(w, 0.16, 0.14), b, false, 0.75)
	for x: float in [-w * 0.5 - 0.02, w * 0.5 + 0.02]:
		k.box("r37_board", base + b * Vector3(x, h + 0.05, 0), Vector3(0.2, 0.26, d + 0.3), b, false, 0.8)
		k.box("r37_board", base + b * Vector3(x, dh - 0.2, 0), Vector3(0.14, 0.16, d), b, false, 0.75)
		for s: float in [-1.0, 1.0]:
			k.box("r37_board", base + b * Vector3(x, 1.9, s * d * 0.28), Vector3(0.12, 0.14, 2.0), b * Basis(Vector3.RIGHT, s * 0.7), false, 0.75)
	var nglow := int(o.get("glow", 0))
	if not open:
		var span := w * 0.5 - dw * 0.5 - 1.0
		if span > 0.9:
			var xs: Array[float] = [-(dw * 0.5 + span * 0.55), dw * 0.5 + span * 0.55]
			for i in xs.size():
				_window(k, base, b, xs[i], 1.9 + (dh - 2.4) * 0.4, d * 0.5 + 0.02, i < nglow or nglow >= 2)
	var pitch := deg_to_rad(38.0)
	var run := d * 0.5 + 0.7
	var slope_len := run / cos(pitch)
	var rise := run * tan(pitch)
	for s: float in [-1.0, 1.0]:
		var c := b * Vector3(0, h + rise * 0.5 + 0.05, s * (d * 0.25 + 0.3))
		var rb := b * Basis(Vector3.RIGHT, s * pitch)
		k.box(roof, base + c, Vector3(w + 1.2, 0.34, slope_len), rb, false, 0.85)
		k.box("r37_board", base + c + rb * Vector3(0, -0.2, 0), Vector3(w + 1.0, 0.14, slope_len - 0.1), rb, false, 0.75)
		k.box("r37_board", base + c + rb * Vector3(0, 0.0, slope_len * 0.5), Vector3(w + 1.3, 0.22, 0.14), rb, false, 0.8)
	for i in int(w / 0.8):
		k.box("stone", base + b * Vector3(-w * 0.5 + 0.4 + 0.8 * float(i), h + rise + 0.16, 0), Vector3(0.7, 0.26, 0.5), b, false, 0.85)
	for j in (int(rise / 0.5) if big else 4):                # scaled, the gable is stepped all the way up under the roof (the four courses left its top open)
		var hw := (d - 0.6) * (1.0 - float(j) / 4.2) if not big else maxf(2.0 * (run - 0.5 * float(j + 1) / tan(pitch)) - 0.5, 0.4)
		for sx: float in [-1.0, 1.0]:
			k.box(wall, base + b * Vector3(sx * (w * 0.5 - t * 0.5), h + 0.3 + 0.5 * float(j), 0), Vector3(t, 0.5, hw), b, false, 0.9)
	var cx := w * 0.3
	var cz := -d * 0.18
	if not open:
		cz = -d * 0.5 + t + 0.35             # the stack stands on the back wall, over the hearth
		Hearth.surround(k, base, b, w, d, h, t, dw, cx, dh)
	k.box("stone", base + b * Vector3(cx, h + rise * 0.6, cz), Vector3(1.1, rise * 1.5 + 1.4, 1.1 if open else 0.7), b, true, 0.8)
	k.box("stone", base + b * Vector3(cx, h + rise * 1.35 + 0.6, cz), Vector3(1.4, 0.2, 1.4), b, false, 0.85)
	for sx: float in [-0.25, 0.25]:
		k.box("ruin", base + b * Vector3(cx + sx, h + rise * 1.35 + 0.95, cz), Vector3(0.3, 0.5, 0.3), b, false, 0.7)


static func _building(host: Node3D, space: PhysicsDirectSpaceState3D, id: String) -> Vector3:
	var d: Dictionary = bld(id)
	var s := float(d.get("s", 1.0))
	var rc := _footprint(d)
	var lo := INF
	for ix in 5:
		for iz in 5:
			lo = minf(lo, _g(space, rc.position.x + rc.size.x * ix * 0.25, rc.position.y + rc.size.y * iz * 0.25))
	var at := Vector3(d.at.x, lo, d.at.y)
	var k := _kit()
	k.at(at, s)
	_house(k, at, float(d.yaw), d.size, float(d.h), d)
	k.at(at, 1.0)
	k.commit(host, "Bld_" + id)
	if not bool(d.get("open", false)) and float(d.h) > 0.0:
		var t := 0.34
		var hh := (float(d.h) - 0.66) * 0.5
		Interiors.room_lights(host, "bld_" + id, at + Basis(Vector3.UP, float(d.yaw)) * Vector3(0, (0.66 + hh) * s, 0), float(d.yaw), Vector3(d.size.x * 0.5 - t, hh, d.size.y * 0.5 - t) * s, int(d.get("glow", 0)) > 0, 1.8 * s)
		if int(d.get("glow", 0)) > 0:
			Hearth.fire(host, at, Basis(Vector3.UP, float(d.yaw)), float(d.size.y), t, float(d.size.x) * 0.3, "bld_" + id, s)
			_window_trails(host, id, at, float(d.yaw), d)
	elif int(d.get("glow", 0)) > 0:
		var b := Basis(Vector3.UP, float(d.yaw))
		var mouth := at + b * (Vector3(0.0, 1.2, float(d.size.y) * 0.5 + 0.5) * s)
		Interiors.shaft(host, "OpenTrail_%s" % id, mouth, b * Vector3(0.0, -0.2, 1.0), Color(1.0, 0.42, 0.14), 1.5 * s, 11.0, 38.0)
	return at


## Cones out of the lit panes and the door, aimed down the front face (local +z). Same openings as _house.
static func _window_trails(host: Node3D, id: String, at: Vector3, yaw: float, d: Dictionary) -> void:
	var b := Basis(Vector3.UP, yaw)
	var w := float(d.size.x)
	var depth := float(d.size.y)
	var dw := float(d.get("door_w", 1.4))
	var dh := float(d.get("door_h", 2.4))
	var s := float(d.get("s", 1.0))
	var nglow := int(d.get("glow", 0))
	var span := w * 0.5 - dw * 0.5 - 1.0
	if span > 0.9:
		var xs: Array[float] = [-(dw * 0.5 + span * 0.55), dw * 0.5 + span * 0.55]
		for i in xs.size():
			if i < nglow or nglow >= 2:
				var pos := at + b * (Vector3(xs[i], 1.9 + (dh - 2.4) * 0.4, depth * 0.5 + 0.35) * s)
				Interiors.shaft(host, "WinTrail_%s_%d" % [id, i], pos, b * Vector3(0.0, -0.45, 1.0), Color(1.0, 0.58, 0.26), 1.15 * s, 10.0, 24.0)
	var door := at + b * (Vector3(0.0, 1.35 + (dh - 2.4) * 0.4, depth * 0.5 + 0.45) * s)
	Interiors.shaft(host, "DoorTrail_%s" % id, door, b * Vector3(0.0, -0.32, 1.0), Color(1.0, 0.52, 0.2), 1.3 * s, 11.0, 32.0)


## Barrels and crates in a corner: small boxes, no fuss.
static func _clutter(k: Pilot.SKit, base: Vector3, yaw: float, rng: RandomNumberGenerator, n: int, spread: float) -> void:
	k.at(base, Pilot.prop(), false)
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
	var bk := Pilot.BRIDGE if Pilot.on() else Vector3.ONE        # the scale pilot: a longer, much wider deck
	var xe := -208.0 + 14.0 * bk.x
	var xw := -208.0 - 14.0 * bk.x
	var ge := _g(space, xe, 65.6)
	var gw := _g(space, xw, 65.6)
	var y := maxf(ge, gw) - 0.05
	var br := Kit.place(host, "r37_bridge.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(-208.0, y, 65.6)), {"scale": bk})
	if br:
		FarDetail.register(br, FarDetail.hull(AABB(Vector3(-14.0, -2.0, -2.2), Vector3(28.0, 3.0, 4.4)), 0.0, Color(0.16, 0.15, 0.14)), Transform3D.IDENTITY, 110.0 * bk.z)
	deck_rect = Rect2(Vector2(xw, 65.6 - 1.3 * bk.z), Vector2(28.0 * bk.x, 2.6 * bk.z))
	deck_y = y
	_abutment(host, space, y, bk)
	host.set_meta("approach", Vector3(xe, ge, 65.6))
	var lp := Vector3(xe - 1.5, y + 1.0, 65.6 - 2.0 * bk.z)
	_lore(host, "r37w_bridge", lp, lp)


## The deck stands half a metre over the west bank: a stone approach ramp from its end down to the ground
## (a tilted slab, its far end buried), so the Watch's road does not drop off the bridge.
static func _abutment(host: Node3D, space: PhysicsDirectSpaceState3D, y: float, bk := Vector3.ONE) -> void:
	var xa := -208.0 - 13.8 * bk.x
	var xb := xa - 4.6 * bk.x
	var yb := _g(space, xb, 65.6)
	var dir := Vector2(xb - xa, yb - y)
	var len := dir.length()
	var ang := atan2(dir.y, dir.x)
	var u := dir / len
	var up := Vector2(u.y, -u.x)            # u runs west and down: this is the slab's upper normal
	var thick := 1.4
	var run := len + 1.0
	var c2 := Vector2(xa, y) + u * (run * 0.5 - 0.3) - up * (thick * 0.5)
	var k := _kit()
	k.box("stone", Vector3(c2.x, c2.y, 65.6), Vector3(run, thick, 2.2 * bk.z), Basis(Vector3.BACK, ang), true, 0.85)
	k.commit(host, "BridgeApproach")


static func _mill(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	# the scale pilot: the mill is `ms` times its size about a new origin `mo` (its wheel's water side where it was,
	# the house clear of the wider bridge); everything below is written in the old frame and carried over by `mp`
	var ms := Pilot.MILL if Pilot.on() else 1.0
	var mo := Pilot.MILL_AT if Pilot.on() else Pilot.MILL_OLD
	var y := _g(space, mo.x - 14.5 * ms, mo.y)
	var o_old := Vector3(-207.0, y, 58.0)
	var o_new := Vector3(mo.x, y, mo.y)
	var mp := func(v: Vector3) -> Vector3: return o_new + (v - o_old) * ms
	var root := Kit.place(host, "r37_mill.glb", Transform3D(Basis(Vector3.UP, 0.0), o_new), {"spin": "Wheel", "spin_rate": 0.55 / ms, "scale": Vector3.ONE * ms})
	if root:
		host.set_meta("walk", [false])
		FarDetail.register(root, FarDetail.hull(AABB(Vector3(-20.0, 0.0, -4.0), Vector3(12.0, 10.0, 8.0)), 0.5, Color(0.14, 0.12, 0.1)), Transform3D.IDENTITY, 110.0 * ms)
	# the weir itself stands at the water: its crest (model z 0.25) just over the reach's surface
	var wl := RealmLayout.river_level(58.0)
	var wk := Vector3(1.0, 1.3, 1.2) if Pilot.on() else Vector3.ONE          # the weir keeps the river's width: taller posts, a deeper apron
	Kit.place(host, "r37_weir.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(-207.0, wl - 0.15 - 0.25 * (wk.y - 1.0), 58.0)), {"scale": wk})
	# the mill's door faces the road: a lit window pane on the south wall and a sack-hoist's landing
	var k := _kit()
	k.origin = o_old
	k.to = o_new
	k.s = ms
	k.box("glow", Vector3(-221.5, y + 5.0, 61.95), Vector3(0.9, 0.7, 0.05), Basis.IDENTITY, false, 1.0)
	k.box("glow", Vector3(-218.0, y + 5.0, 61.95), Vector3(0.9, 0.7, 0.05), Basis.IDENTITY, false, 1.0)
	for mx: float in [-221.5, -218.0]:
		Interiors.shaft(host, "MillTrail_%d" % int(mx), mp.call(Vector3(mx, y + 4.9, 62.15)), Vector3(0.0, -0.55, 1.0), Color(1.0, 0.58, 0.26), 1.1 * ms, 12.0, 18.0)
	k.commit(host, "MillGlow")
	_chest(host, "weirford_loft", mp.call(Vector3(-224.5, y + 3.6, 56.0)), 0.4)
	var lq: Vector3 = mp.call(Vector3(-217.0, y, 63.0)) + Vector3(0.0, 1.0, 0.0)
	_lore(host, "r37w_mill", lq, lq)


static func _town(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37001
	var ats := {}
	var sc := {}                        # id -> the building's scale about its foot (1, or the scale pilot's)
	var fl := {}                        # id -> its floor over its foot where the slab is the floor (the pilot), else 0
	for id: String in BLD:
		if id == "mill_house":
			continue
		ats[id] = _building(host, space, id)
		sc[id] = float(bld(id).get("s", 1.0))
		fl[id] = 0.66 * float(sc[id]) if float(sc[id]) > 1.01 else 0.0
	var pk := Pilot.on()
	# the inn's sign and the smithy's anvil are in the people's routines; here the dressing
	var k := _kit()
	var inn: Vector3 = ats.inn
	var si: float = sc.inn
	k.at(inn, si)
	k.box("wood", inn + Vector3(-3.4, 2.6, 4.9), Vector3(0.1, 1.9, 0.1), Basis.IDENTITY, false, 0.7)      # the sign's post
	k.box("wood", inn + Vector3(-2.7, 3.2, 4.9), Vector3(1.5, 0.12, 0.1), Basis.IDENTITY, false, 0.7)
	k.box("wood", inn + Vector3(-2.7, 2.6, 4.9), Vector3(0.9, 0.8, 0.07), Basis.IDENTITY, false, 0.6)
	_clutter(k, inn + Vector3(5.6 * si, fl.inn, 3.6 * si), 0.0, rng, 6, 1.1)
	var sm: Vector3 = ats.smithy
	var ss: float = sc.smithy
	var an := sm + Vector3(0.6 * ss, fl.smithy, -1.2 * ss)                # the anvil's foot
	var fg := sm + Vector3(-2.2 * ss, fl.smithy, -1.8 * ss)               # the forge's
	k.at(an, Pilot.prop(), false)
	if pk:                                                               # on the floor now: a block under the anvil
		k.box("wood", an + Vector3(0, 0.22, 0), Vector3(0.5, 0.44, 0.42), Basis.IDENTITY, true, 0.7)
		k.box("iron", an + Vector3(0, 0.6, 0), Vector3(0.9, 0.32, 0.4), Basis.IDENTITY, true, 0.7)
	else:
		k.box("iron", an + Vector3(0, 0.55, 0), Vector3(0.9, 0.5, 0.45), Basis.IDENTITY, true, 0.7)      # the anvil
	k.at(fg, Pilot.prop(), false)
	k.box("stone", fg + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.1), Basis.IDENTITY, true, 0.8)           # the forge's hearth
	k.box("glow", fg + Vector3(0, 1.02, 0.02), Vector3(0.8, 0.04, 0.6), Basis.IDENTITY, false, 1.0)      # coals
	_clutter(k, sm + Vector3(3.2 * ss, fl.smithy, 1.5 * ss), PI, rng, 4, 0.7)
	var st: Vector3 = ats.stables
	var sst: float = sc.stables
	k.at(st, sst)
	var stb := Basis(Vector3.UP, float(bld("stables").yaw))
	for i in 3:
		k.box("wood", st + stb * Vector3(-3.6 + 3.6 * float(i), 0.9, -0.2), Vector3(0.18, 1.8, 3.2), stb, true, 0.75)   # stall partitions
	var hay := st + stb * Vector3(0.0, fl.stables, 3.1 * sst)
	k.at(hay, Pilot.prop(), false)
	k.box("wood", hay + Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 2.2), stb * Basis(Vector3.UP, -PI * 0.5), true, 0.8)          # a hay bale stack by the open side
	# the square: a covered well, a stall, benches, a notice post (the scale pilot's square is wider: Pilot.xz)
	var sq := Vector3(-196.0, _g(space, -192.0, 74.0), 74.0)
	var wq := Pilot.xz(Vector2(-191.0, 78.0))
	var well := Vector3(wq.x, _g(space, wq.x, wq.y), wq.y)
	k.at(well, Pilot.prop(), false)
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.box("stone", well + Vector3(cos(a) * 0.9, 0.5, sin(a) * 0.9), Vector3(0.7, 1.0, 0.45), Basis(Vector3.UP, -a), true, 0.85)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", well + Vector3(sx * 0.95, 1.6, 0), Vector3(0.14, 2.2, 0.14), Basis.IDENTITY, false, 0.7)
	k.box("wood", well + Vector3(0, 2.7, 0), Vector3(2.2, 0.12, 0.2), Basis.IDENTITY, false, 0.7)
	k.box("slate", well + Vector3(0, 2.95, 0), Vector3(2.4, 0.1, 1.5), Basis(Vector3.RIGHT, 0.0), false, 0.8)
	var tq := Pilot.STALL if pk else Vector2(-184.0, 72.5)
	var stall := Vector3(tq.x, _g(space, tq.x, tq.y), tq.y)
	k.at(stall, Pilot.prop(), false)
	k.box("wood", stall + Vector3(0, 0.55, 0), Vector3(2.6, 1.1, 0.9), Basis.IDENTITY, true, 0.8)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", stall + Vector3(sx * 1.4, 1.2, -0.5), Vector3(0.12, 2.4, 0.12), Basis.IDENTITY, false, 0.7)
	k.box("plaster", stall + Vector3(0, 2.5, -0.1), Vector3(3.1, 0.07, 1.6), Basis(Vector3.RIGHT, -0.18), false, 0.75)
	var bq := Pilot.xz(Vector2(sq.x - 3.0, sq.z + 2.4))
	var bench := Vector3(bq.x, sq.y if not pk else _g(space, bq.x, bq.y), bq.y)
	k.at(bench, Pilot.prop(), false)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", bench + Vector3(sx * 1.6, 0.3, 0), Vector3(0.1, 0.6, 0.5), Basis.IDENTITY, false, 0.7)
	k.box("wood", bench + Vector3(0, 0.62, 0), Vector3(3.4, 0.1, 0.5), Basis.IDENTITY, true, 0.75)
	# iron lanterns on the bridge's ends and in the square (cold glass in a cage: the wanderer lights them, lamps/lamp_places.gd)
	for lp: Vector3 in lanterns():
		_lantern(k, Vector3(lp.x, _g(space, lp.x, lp.y), lp.y), lp.z)
	k.at(Vector3.ZERO, 1.0)
	k.commit(host, "TownDressing")
	var l_inn := inn + Vector3(-5.5 * si, 1.1, 5.3 * si)
	_lore(host, "r37w_inn", l_inn, l_inn)
	var nq := Pilot.xz(Vector2(sq.x - 5.5, sq.z - 5.0))
	var l_not := Vector3(nq.x, (sq.y if not pk else _g(space, nq.x, nq.y)) + 1.1, nq.y)
	_lore(host, "r37w_notice", l_not, l_not)
	var l_sm := sm + Vector3(-4.4 * ss, 1.1, 3.4 * ss)
	_lore(host, "r37w_smith", l_sm, l_sm)
	host.set_meta("route", [inn + Vector3(0.0, 0.0, 5.0 * si + (1.2 if pk else 0.0))])
	host.set_meta("walk", [true])
	host.set_meta("approach", Vector3(inn.x, _g(space, inn.x, inn.z + 8.0 * si), inn.z + 8.0 * si))     # the street in front of the inn


# --- the Sorrow's Banks ---------------------------------------------------------------------------------

static func _shrine(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var at := Vector3(-208.0, _g(space, -208.0, -40.0), -40.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37002
	var k := _kit()
	# a roofless little shrine on a plinth in the shallows: four piers, a broken arch, a stone altar, a leaning saint
	var wl := RealmLayout.river_level(-40.0)
	var top := wl + 0.35                                  # the plinth stands just over the reach's surface
	var base := Vector3(at.x, top, at.z)
	k.box("ruin", Vector3(at.x, (at.y + top) * 0.5 - 0.1, at.z), Vector3(6.6, top - at.y + 0.2, 6.6), Basis.IDENTITY, true, 0.8)
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
	var sb := Node3D.new()
	sb.name = "Shrine"
	host.add_child(sb)
	k.commit(sb, "ShrineBody")
	FarDetail.register(sb, FarDetail.hull(AABB(Vector3(at.x - 3.6, top - 0.5, at.z - 3.6), Vector3(7.2, 5.0, 7.2)), 0.0, Color(0.16, 0.15, 0.14)), Transform3D.IDENTITY, 110.0)
	# fords: pairs of marker posts with a rope hook, on weir_track where it crosses and at two more banks
	for fp: Vector2 in [Vector2(-196.0, -66.0), Vector2(-190.0, -22.0), Vector2(-206.0, 20.0)]:
		for sx: float in [-1.0, 1.0]:
			var gx := fp.x + sx * 5.2
			var gy := _g(space, gx, fp.y)
			k.box("wood", Vector3(gx, gy + 1.1, fp.y), Vector3(0.16, 2.4, 0.16), Basis.IDENTITY, false, 0.7)
			k.box("iron", Vector3(gx, gy + 2.2, fp.y), Vector3(0.3, 0.05, 0.05), Basis.IDENTITY, false, 0.7)
	k.commit(host, "FordPosts")
	_chest(host, "sorrow_shrine", base + Vector3(1.6, 0.0, 0.4), 0.0)                 # on the plinth's paving, beside the altar
	_lore(host, "r37w_shrine", base + Vector3(-2.2, 1.2, 3.4), base + Vector3(-2.2, 1.2, 3.4))
	host.set_meta("wet", true)
	host.set_meta("plinth_y", top)
	host.set_meta("approach", Vector3(-202.0, _g(space, -202.0, -37.0), -37.0))


# --- the Siege Lines --------------------------------------------------------------------------------------

static func _siege_line(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37003
	var hc := Hier.HEAD_C
	var line := Node3D.new()
	line.name = "Palisade"
	host.add_child(line)
	# the north gate stands in the inner ring's breach; the palisade runs along the bank's crest on either side
	var gate_at := Vector2(hc.x, hc.y - RING_R)
	var gy := _g(space, gate_at.x, gate_at.y)
	Kit.place(line, "r37_palisade.glb", Transform3D(Basis(Vector3.UP, 0.0), Vector3(gate_at.x, gy, gate_at.y)), {"pick": "PalGate", "shift": Vector3(26.0, 0.0, 0.0)})
	var variants := ["PalA", "PalA", "PalB", "PalA", "PalC", "PalB", "PalA", "PalA"]
	var shifts := {"PalA": 0.0, "PalB": 8.0, "PalC": 16.0}
	var da := rad_to_deg(4.2 / RING_R)
	var i := 0
	# two arcs of bearings (degrees, 0 = east, 90 = south): the north-west run to the gate and the north-east run to the
	# breach where the east flank is open (the March Wall's foot closes the ring beyond it)
	for arc: Array in [[-136.0, -97.0], [-83.0, -48.0]]:
		var a := float(arc[0])
		while a <= float(arc[1]):
			var ar := deg_to_rad(a)
			var x := hc.x + cos(ar) * RING_R
			var z := hc.y + sin(ar) * RING_R
			var gg := _g(space, x, z)
			var v: String = variants[i % variants.size()]
			var yaw := atan2(-cos(ar), -sin(ar)) + rng.randf_range(-0.06, 0.06)
			Kit.place(line, "r37_palisade.glb", Transform3D(Basis(Vector3.UP, yaw), Vector3(x, gg - 0.05, z)), {"pick": v, "shift": Vector3(float(shifts[v]), 0.0, 0.0), "range_end": 260.0})
			a += da
			i += 1
	var k := _kit()
	for j in 14:
		var p := Vector2(gate_at.x + rng.randf_range(-14.0, 14.0), gate_at.y - rng.randf_range(3.0, 11.0))
		var pg := _g(space, p.x, p.y)
		k.box("wood", Vector3(p.x, pg + 0.6, p.y), Vector3(0.14, 1.4, 0.14), Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.3, 0.6)), false, 0.7)
	k.commit(host, "Stakes")
	_lore(host, "r37w_siege_line", Vector3(gate_at.x + 5.0, gy + 1.1, gate_at.y - 3.0), Vector3(gate_at.x + 5.0, gy + 1.1, gate_at.y - 3.0))


static func _trebs(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	for i in TREBS.size():
		var at: Vector2 = TREBS[i]
		var gy := _lo(space, _bx(at, Vector2(8.0, 8.0)))
		var fallen := i == 1
		# the arm throws toward the model's +X: aimed at the skull
		var to := Hier.HEAD_C - at
		var tr := Kit.place(host, "r37_trebuchet.glb", Transform3D(Basis(Vector3.UP, atan2(-to.y, to.x) + 0.08 * float(i - 1)), Vector3(at.x, gy + 0.05, at.y)),
			{"pick": "TrebB" if fallen else "TrebA", "shift": Vector3(30.0 if fallen else 0.0, 0.0, 0.0)})
		if tr:
			FarDetail.register(tr, FarDetail.hull(AABB(Vector3(-12.0, 0.0, -4.0), Vector3(19.0, 12.0, 8.0)), 0.3, Color(0.14, 0.12, 0.1)), Transform3D.IDENTITY, 110.0)
	var lp := Vector3(-202.0, _g(space, -202.0, 109.0) + 1.1, 109.0)
	_lore(host, "r37w_trebs", lp, lp)


static func _tower(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var rc := _bx(TOWER_AT, Vector2(7.5, 7.5))
	var gy := _lo(space, rc)
	var at := Vector3(TOWER_AT.x, gy - 0.1, TOWER_AT.y)
	# the open face (model -Z) looks along the ramp, toward the skull's brow
	var to := (Hier.HEAD_C + Vector2(-6.0, -4.0)) - TOWER_AT
	var face := to.normalized()
	var yaw := atan2(-face.x, -face.y)
	var fb := Basis(Vector3.UP, yaw)
	var tw := Kit.place(host, "r37_siege_tower.glb", Transform3D(fb, at))
	if tw:
		FarDetail.register(tw, FarDetail.hull(AABB(Vector3(-3.4, 0.0, -3.4), Vector3(6.8, 16.0, 6.8)), 0.1, Color(0.14, 0.12, 0.1)), Transform3D.IDENTITY, 120.0)
	# the drawbridge's foot (15 m out along the face, 0.2 up) is the lowest ground's height plus 0.2 and the ground may fall
	# away beyond the pad: a few low timber steps carry it down to the ground it meets, so the ramp can be walked onto
	var out := Vector3(face.x, 0.0, face.y)
	var foot := at + out * 15.0 + Vector3(0.0, 0.2, 0.0)
	var sk := _kit()
	var prev := foot.y
	var sb := Basis(Vector3.UP, atan2(-face.y, face.x))        # local x along the ramp
	for j in 7:
		var sp := foot + out * (0.5 + 0.55 * float(j))
		var gi := _g(space, sp.x, sp.z)
		var top := prev - 0.2
		if top <= gi + 0.12:
			break
		sk.box("wood", Vector3(sp.x, (top + gi - 0.4) * 0.5, sp.z), Vector3(0.55, top - gi + 0.4, 4.4), sb, true, 0.8)
		prev = top
	sk.commit(host, "TowerFootSteps")
	# its top: the platform (z 14.4 in the model) is 14.4 m over the wheels' foot
	_chest(host, "siege_tower_top", at + Vector3(0.0, 14.6, 0.0), yaw)
	host.set_meta("route", [at + out * 13.0 + Vector3(0.0, 0.2, 0.0), at + Vector3(0.0, 14.5, 0.0)])
	host.set_meta("walk", [true, true])
	host.set_meta("approach", at + out * 13.0)
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

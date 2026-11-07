extends RefCounted
## r34 places (docs/r34/places.md): the doubled Realm's new ground filled with places worth leaving
## the road for, in the r31 manner (realm_pois.gd: a structure, a chest, a climb, grapple anchors,
## glide perches and updrafts, a fighting floor where a guardian stands). World of Warcraft gives
## each zone a handful of named sub-places with a reason to go (a quest giver, a rare, a chest on a
## roof); Enshrouded hides a chest in every ruin's loft and puts a perch on every tower. Ours, in the
## valley's own story (docs/LORE.md):
##
##   quarry_crane     The Unfinished Stair (Saints' Quarry): giant squared blocks stepped up to a
##                    crane's pier on the pit floor; the jib over the pit; a perch off the deck
##   quarry_winch     The Winch-House (Saints' Quarry): the Order's tread-wheel house on a high bench
##   holds_hall       The Hall-Mound (Rooted Holds): a turf-roofed hall; walk its banks to the ridge
##   holds_houses     The Earth-Houses (Rooted Holds): three turf domes round a cold fire-ring
##   foundry_furnace  The Bell Furnace (Founder's Pits): a 12 m furnace tower, its outside stair
##                    broken once; the mouth breathes an updraft; the Founder's relic chest on top
##   foundry_pits     The Casting Pits (Founder's Pits): three warm pits, the cracked mould of a
##                    fourth bell, a gantry over them
##   moor_tor         The Cairn Tor (Lanternless Moor): a guide-cairn ring and the watcher's seat
##   moor_shrine      The Lanternless Shrine (Lanternless Moor): the lantern hooks struck off by Edict I
##   orchard_press    The Press-House (Cinder Orchard): roofless, the great screw press, a loft
##   orchard_heart    The Mother Tree (Cinder Orchard): a ring of burned trees round a dead giant
##   necro_mausoleum  The First Pilgrims' Tomb (Waiting Field): a podium tomb with a vault inside it
##                    (a stair down from the tomb house), buttresses up to the roof
##   necro_ranks      The Pilgrims' Ranks (Waiting Field): stelae facing the mountain, a bell-post,
##                    the field-warden's lodge
##   mere_chapel      The Half-Sunk Chapel (Corvin's Mere): wade the nave, climb the tower stub
##   mere_landing     Corvin's Landing (Corvin's Mere): the boat-house, its jetty and lamp racks
##
## Same API as r31 (groups "world_poi", "miniboss_site"/"guardian_site", "grapple_anchor",
## "glide_perch", "updraft", "loot_chest"); every host also carries meta "region". The r34 guardian
## floors leave meta "guardian" empty: the enemies pass picks (Guardians.pick_id by region).
## Built by realm_pois.gd: reserve() from its reserve (RealmBosses, before the stamp and the flora),
## build() from its build (after the flora). No class_name: preload by path.

const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")

const WATER := -0.9                     ## RealmFlora.WATER_Y
const CAMP_CLEAR := 9.0
const FIRE_CLEAR := 7.0                 ## metres between a place's footprint and an r34 fire

## id -> {at (prefer xz), search (m), half (xz half extents), rise (max ground rise), title, line,
##        region, face (xz the front looks at; default the nearest way), wet, nocut, vista}
const POIS := {
	"quarry_crane": {"at": Vector2(-127, -102), "search": 12.0, "half": Vector2(8, 8), "rise": 1.5,
		"title": "The Unfinished Stair", "line": "four thousand steps, and these", "region": "quarry", "vista": 16.0},
	"quarry_winch": {"at": Vector2(-140, -116), "search": 10.0, "half": Vector2(4.5, 4.5), "rise": 3.5,
		"title": "The Winch-House", "line": "the wheel that lifted the Stair", "region": "quarry", "face": Vector2(-127, -104)},
	"holds_hall": {"at": Vector2(-124, 10), "search": 4.0, "half": Vector2(6.5, 6.5), "rise": 3.5,
		"title": "The Hall-Mound", "line": "the Rooted's long house", "region": "holds", "face": Vector2(-134, 10)},
	"holds_houses": {"at": Vector2(-119.5, 24.5), "search": 4.0, "half": Vector2(6.5, 6.5), "rise": 3.2,
		"title": "The Earth-Houses", "line": "doors that face the ground", "region": "holds", "face": Vector2(-131, 19)},
	"foundry_furnace": {"at": Vector2(131, -111), "search": 10.0, "half": Vector2(7.5, 7.5), "rise": 3.5,
		"title": "The Bell Furnace", "line": "Hope, Patience, Homecoming", "region": "foundry", "face": Vector2(124, -92), "vista": 12.0},
	"foundry_pits": {"at": Vector2(129, -90), "search": 10.0, "half": Vector2(7, 6), "rise": 2.0,
		"title": "The Casting Pits", "line": "the fourth bell was never rung", "region": "foundry", "face": Vector2(123, -78)},
	"moor_tor": {"at": Vector2(141, -24), "search": 5.0, "half": Vector2(5.5, 5.5), "rise": 9.0,
		"title": "The Cairn Tor", "line": "count the cairns, not the stars", "region": "moor", "face": Vector2(141, -44), "nocut": true, "vista": 14.0},
	"moor_shrine": {"at": Vector2(140, 13), "search": 10.0, "half": Vector2(4.5, 4.5), "rise": 2.4,
		"title": "The Lanternless Shrine", "line": "lanterns are for doubters", "region": "moor", "face": Vector2(134, 18)},
	"orchard_press": {"at": Vector2(-128, 132), "search": 10.0, "half": Vector2(8.5, 8.5), "rise": 1.2,
		"title": "The Press-House", "line": "the abbey's cider, the road's bread", "region": "orchard", "face": Vector2(-112, 124)},
	"orchard_heart": {"at": Vector2(-86, 122), "search": 10.0, "half": Vector2(8.5, 8.5), "rise": 1.4,
		"title": "The Mother Tree", "line": "the first graft, the last to burn", "region": "orchard", "face": Vector2(-80, 132)},
	"necro_mausoleum": {"at": Vector2(0, 145), "search": 10.0, "half": Vector2(7.5, 7.5), "rise": 4.0,
		"title": "The First Pilgrims' Tomb", "line": "first in line when the sky calls", "region": "necropolis", "face": Vector2(0, 128), "vista": 10.0},
	"necro_ranks": {"at": Vector2(-24, 118), "search": 10.0, "half": Vector2(10, 8), "rise": 2.0,
		"title": "The Pilgrims' Ranks", "line": "every face toward the mountain", "region": "necropolis", "face": Vector2(-24, 100)},
	"mere_chapel": {"at": Vector2(79, 112), "search": 5.0, "half": Vector2(6.5, 6.5), "rise": 9.0,
		"title": "The Half-Sunk Chapel", "line": "Corvin's last mass was sung wading", "region": "mere", "face": Vector2(92, 112), "wet": true, "vista": 10.0},
	"mere_landing": {"at": Vector2(131, 123), "search": 10.0, "half": Vector2(6, 6), "rise": 1.6,
		"title": "Corvin's Landing", "line": "where the lamp-boat put out", "region": "mere", "face": Vector2(131, 112), "wet": true},
}

## The fighting floors (a guardian's ground, the enemies pass fills them): poi -> [floor id, radius,
## local offsets tried first]. Chosen at reserve and levelled by the stamp (a WorldLanes terrace
## "poi_floor_<id>"), so each is flat and open whatever the hillside: off the places, the ways, the
## water, 5 m+ past a camp's edge and 9 m+ past a fire's (a fire is a sanctuary). The Rooted Holds
## have none: the clearing is a haven (the enemies pass sends a rare round it instead).
const FLOORS := {
	"quarry_crane": ["quarry_pit", 7.0, [Vector3(-11.0, 0, -2.0), Vector3(-11.0, 0, -4.0), Vector3(-10.0, 0, 6.0), Vector3(10.0, 0, 7.0), Vector3(0, 0, 12.0), Vector3(-2.0, 0, -12.0)]],
	"foundry_furnace": ["foundry_floor", 7.0, [Vector3(0, 0, 9.5), Vector3(-8.0, 0, 7.0), Vector3(8.0, 0, 8.0), Vector3(-9.0, 0, -2.0)]],
	"moor_tor": ["moor_foot", 6.5, [Vector3(0, 0, 13.0), Vector3(10.0, 0, 9.0), Vector3(-10.0, 0, 9.0), Vector3(12.0, 0, -4.0), Vector3(-12.0, 0, -4.0)]],
	"orchard_press": ["orchard_yard", 6.5, [Vector3(0, 0, 5.0), Vector3(-6.0, 0, 7.0), Vector3(6.0, 0, 6.0), Vector3(0, 0, 9.0)]],
	"orchard_heart": ["orchard_ring", 6.0, [Vector3(0, 0, 13.0), Vector3(10.0, 0, 8.0), Vector3(-10.0, 0, 8.0), Vector3(0, 0, -13.0)]],
	"necro_mausoleum": ["necro_forecourt", 7.0, [Vector3(0, 0, 13.1), Vector3(-6.0, 0, 11.6), Vector3(6.0, 0, 11.6), Vector3(0, 0, 15.6)]],
	"mere_chapel": ["mere_hummock", 6.5, [Vector3(0, 0, 13.0), Vector3(6.0, 0, 14.0), Vector3(-6.0, 0, 14.0), Vector3(9.0, 0, 9.0), Vector3(0, 0, 17.0)]],
	"mere_landing": ["mere_bank", 6.0, [Vector3(-9.0, 0, -4.0), Vector3(9.0, 0, -6.0), Vector3(0, 0, -11.0), Vector3(-8.0, 0, -11.0)]],
}

## Loot per chest: [tier, ItemDB ids -> amount] (loot_chest.gd rolls the gear piece).
const LOOT := {
	"quarry_jib": ["iron", {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1}],
	"quarry_winch": ["wood", {"grave_ash": 9, "grave_iron": 1}],
	"holds_hall": ["iron", {"grave_ash": 13, "ash_bloom": 2, "relic_fragment": 1}],
	"holds_house": ["wood", {"grave_ash": 8, "ash_bloom": 1}],
	"foundry_relic": ["reliquary", {"grave_ash": 22, "ember_shard": 2, "relic_fragment": 2}],
	"foundry_mould": ["iron", {"grave_ash": 14, "grave_iron": 3}],
	"moor_tor": ["iron", {"grave_ash": 13, "relic_fragment": 1}],
	"moor_shrine": ["wood", {"grave_ash": 9}],
	"orchard_loft": ["iron", {"grave_ash": 13, "ash_bloom": 2, "relic_fragment": 1}],
	"orchard_hollow": ["wood", {"grave_ash": 9, "ash_bloom": 2}],
	"necro_vault": ["reliquary", {"grave_ash": 20, "relic_fragment": 2}],
	"necro_lodge": ["wood", {"grave_ash": 9}],
	"mere_loft": ["iron", {"grave_ash": 14, "relic_fragment": 1}],
	"mere_landing": ["wood", {"grave_ash": 9, "grave_iron": 1}],
}

## Extra world-event (surge) grounds and named spots in the new regions (world_events.gd and
## realm_discovery.gd read these): id -> [xz, name, line, radius].
const EXTRA := {
	"quarry_benches": [Vector2(-112, -112), "The Cutters' Benches", "bench by bench into the mountain", 9.0],
	"moor_cairns": [Vector2(136, -46), "The Guide-Cairns", "one cairn, one hundred paces", 10.0],
	"orchard_rows": [Vector2(-118, 112), "The Black Rows", "no fruit for the Kindlers", 12.0],
	"field_ranks": [Vector2(14, 126), "The Long Ranks", "they face the mountain", 12.0],
	"mere_reeds": [Vector2(116, 136), "The Lamp-Reeds", "his lamps still float", 10.0],
}

static var spots := {}                  ## id -> {at: Vector3, yaw, rect, lo, hi}
static var built: Array[String] = []
static var causeways := {}              ## id -> [Vector2] (plank walks over water)
static var floors := {}                 ## floor id -> Vector3 (centre xz, levelled y), from reserve


# --- reserve (RealmBosses via RealmPois.reserve, before stamp and flora) -----------------------

static func reserve(root: Node, skip: PackedStringArray) -> void:
	spots.clear()
	causeways.clear()
	floors.clear()
	for a in OS.get_cmdline_user_args():
		if a == "--no-r34-pois":
			return
	var space := (root as Node3D).get_world_3d().direct_space_state
	var camps: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		camps.append(Vector2((c.at as Vector3).x, (c.at as Vector3).z))
	var fires: Array[Vector2] = []
	var rb := load("res://core/world/realm/realm_bosses.gd") as GDScript
	var rf: Variant = rb.get("R34_FIRES") if rb else null
	if rf is Dictionary:
		for n: String in rf:
			fires.append((rf as Dictionary)[n][0])
	for id: String in POIS:
		if id in skip:
			continue
		var d: Dictionary = POIS[id]
		var half: Vector2 = d.half
		var wet := bool(d.get("wet", false))
		var q := _search(space, id, d, camps, fires)
		if q == Vector2.INF:
			var pref: Vector2 = d.at
			print("REALM_POI r34 skip %s: no clear ground near %s (there: %s)" % [id, pref, LK.blocker(Rect2(pref - half, half * 2.0), 1.2)])
			continue
		var rect := Rect2(q - half, half * 2.0)
		var lo := INF
		var hi := -INF
		for ix in 5:
			for iz in 5:
				var gy := RealmLayout.ground(space, rect.position.x + rect.size.x * ix * 0.25, rect.position.y + rect.size.y * iz * 0.25)
				lo = minf(lo, gy)
				hi = maxf(hi, gy)
		var cy := RealmLayout.ground(space, q.x, q.y)
		var base := cy if bool(d.get("nocut", false)) or wet else lo
		var face: Vector2 = d.get("face", _nearest_way(q))
		var to := face - q
		var yaw := atan2(to.x, to.y)
		spots[id] = {"at": Vector3(q.x, base, q.y), "yaw": yaw, "rect": rect, "lo": lo, "hi": hi}
		if bool(d.get("nocut", false)):
			WorldLanes.register_site("poi_" + id, rect, cy, hi + 1.0)      # the tor keeps its rocks: no cut
		elif wet:
			WorldLanes.register_site("poi_" + id, rect, lo + 0.05, cy + 0.4)
		else:
			WorldLanes.register_site("poi_" + id, rect, lo + 0.05, lo)
		if d.has("vista"):
			Flora.tree_clear.append([q, float(d.vista)])
	for id: String in FLOORS:
		if spots.has(id):
			_reserve_floor(space, id, camps, fires)
	if spots.has("mere_chapel"):
		_reserve_causeway("mere_chapel", 3.6)
	if spots.has("mere_landing"):
		_reserve_jetty()
	print("REALM_POI r34 reserved %s" % [spots.keys()])


## The best footprint round a place's preferred spot (rings every 2 m out to `search`): hard rules
## inside the world (8 m off the edge), clear of ways and sites (1.2 m), dry (unless "wet"); then the
## least bad by distance from the preference, ground rise past `rise`, closeness to camps (9 m wanted
## between footprint and camp, 3 m at least: the enemies pass plants its camps on the same ground) and
## to the r34 fires (7 m wanted, 3 m at least).
static func _search(space: PhysicsDirectSpaceState3D, id: String, d: Dictionary, camps: Array[Vector2], fires: Array[Vector2]) -> Vector2:
	var half: Vector2 = d.half
	var pref: Vector2 = d.at
	var wet := bool(d.get("wet", false))
	var rmax := float(d.search)
	var best := Vector2.INF
	var best_s := INF
	var dbg := ("--poi-debug=" + id) in OS.get_cmdline_user_args()
	var r := 0.0
	while r <= rmax + 0.01:
		var n := 1 if r == 0.0 else maxi(6, int(TAU * r / 2.0))
		for i in n:
			var a := TAU * float(i) / float(n) + r * 0.37
			var q := pref + Vector2(cos(a), sin(a)) * r
			var rc := Rect2(q - half, half * 2.0)
			if not RealmLayout.BOUNDS.grow(-8.0).encloses(rc):
				continue
			if not LK.clear_of(rc, 1.2):
				if dbg:
					print("POI r34 %s at %s: blocked by %s" % [id, q, LK.blocker(rc, 1.2)])
				continue
			var lo := INF
			var hi := -INF
			for ix in 3:
				for iz in 3:
					var y := RealmLayout.ground(space, rc.position.x + rc.size.x * float(ix) * 0.5, rc.position.y + rc.size.y * float(iz) * 0.5)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if not wet and lo < WATER + 0.08:
				continue
			var rise := hi - lo
			if rise > float(d.rise) * 1.6 + 0.8:
				if dbg:
					print("POI r34 %s at %s: rise %.1f" % [id, q, rise])
				continue
			var cg := INF
			for c in camps:
				cg = minf(cg, Vector2(maxf(absf(c.x - q.x) - half.x, 0.0), maxf(absf(c.y - q.y) - half.y, 0.0)).length())
			var fg := INF
			for f in fires:
				fg = minf(fg, Vector2(maxf(absf(f.x - q.x) - half.x, 0.0), maxf(absf(f.y - q.y) - half.y, 0.0)).length())
			if cg < 3.0 or fg < 3.0:
				if dbg:
					print("POI r34 %s at %s: camp %.1f fire %.1f" % [id, q, cg, fg])
				continue
			var sc := r * 0.35 + maxf(0.0, rise - float(d.rise)) * 3.0 + maxf(0.0, CAMP_CLEAR - cg) * 1.5 + maxf(0.0, FIRE_CLEAR - fg) * 2.0
			if sc < best_s:
				best_s = sc
				best = q
		r += 2.0
	return best


static func _nearest_way(q: Vector2) -> Vector2:
	var best := q + Vector2(0, 1)
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var c := a + ab * t
			if c.distance_to(q) < bd:
				bd = c.distance_to(q)
				best = c
	return best


## A plank walk from the dry bank (toward the place's face point) to its front, over the water.
static func _reserve_causeway(id: String, front: float) -> void:
	var s: Dictionary = spots[id]
	var c := Vector2((s.at as Vector3).x, (s.at as Vector3).z)
	var fwd := Vector2(sin(float(s.yaw)), cos(float(s.yaw)))
	var end := c + fwd * front
	var start := end
	for i in 40:
		var q := end + fwd * float(i) * 0.5
		start = q
		if RealmLayout.macro_height(q.x, q.y) > WATER + 0.5 and i > 4:
			break
	start += fwd * 1.2
	if start.distance_to(end) < 3.0:
		return
	var mid := (start + end) * 0.5 + Vector2(-fwd.y, fwd.x) * 1.2
	causeways[id] = [start, mid, end]
	WorldLanes.register_lane("poi_cw_" + id, causeways[id], 0.9)


static func _reserve_jetty() -> void:
	var s: Dictionary = spots.mere_landing
	var c := Vector2((s.at as Vector3).x, (s.at as Vector3).z)
	var fwd := Vector2(sin(float(s.yaw)), cos(float(s.yaw)))
	causeways["mere_landing"] = [c + fwd * 4.2, c + fwd * 14.0]


# --- build (after the flora; RealmPois.build) --------------------------------------------------

static func build(holder: Node3D) -> void:
	built.clear()
	var space := holder.get_world_3d().direct_space_state
	for id: String in spots:
		var s: Dictionary = spots[id]
		var d: Dictionary = POIS[id]
		var host := Node3D.new()
		host.name = "Poi_" + id
		host.set_meta("site", "poi_" + id)
		holder.add_child(host)
		host.add_to_group(P.GROUP_POI)
		host.set_meta("poi", id)
		host.set_meta("title", d.title)
		host.set_meta("line", d.line)
		host.set_meta("region", d.region)
		host.set_meta("centre", s.at)
		host.set_meta("radius", (d.half as Vector2).length() + 4.0)
		host.set_meta("r34", true)
		match id:
			"quarry_crane": _quarry_crane(host, space, s)
			"quarry_winch": _quarry_winch(host, space, s)
			"holds_hall": _holds_hall(host, space, s)
			"holds_houses": _holds_houses(host, space, s)
			"foundry_furnace": _foundry_furnace(host, space, s)
			"foundry_pits": _foundry_pits(host, space, s)
			"moor_tor": _moor_tor(host, space, s)
			"moor_shrine": _moor_shrine(host, space, s)
			"orchard_press": _orchard_press(host, space, s)
			"orchard_heart": _orchard_heart(host, space, s)
			"necro_mausoleum": _necro_mausoleum(host, space, s)
			"necro_ranks": _necro_ranks(host, space, s)
			"mere_chapel": _mere_chapel(host, space, s)
			"mere_landing": _mere_landing(host, space, s)
		built.append(id)
		var fl := ""
		for m in host.get_children():
			if m.is_in_group(P.GROUP_MINIBOSS):
				fl += " floor %s at %s r %.1f" % [m.get_meta("id"), (m as Node3D).global_position.snapped(Vector3.ONE * 0.1), float(m.get_meta("radius"))]
		var ch := ""
		for c in host.get_children():
			if c.is_in_group("loot_chest"):
				ch += " chest %s (%s) at %s" % [c.get("chest_id"), c.get("tier"), (c as Node3D).global_position.snapped(Vector3.ONE * 0.1)]
		print("REALM_POI r34 %s at %s yaw %.0f%s%s" % [id, (s.at as Vector3).snapped(Vector3.ONE * 0.1), rad_to_deg(float(s.yaw)), fl, ch])
	_beacons(holder)


## The big places read from afar: a faint column over each (landmark_beacon.gd, drawn inside the far
## plane). Dimmer and shorter than a boss's: these say "a place", not "a fight".
static func _beacons(holder: Node3D) -> void:
	var wf := load("res://core/world/realm/realm_wayfinding.gd") as GDScript
	for b: Array in [["foundry_furnace", Color(0.62, 0.34, 0.2), 15.0], ["necro_mausoleum", Color(0.42, 0.46, 0.56), 10.0], ["mere_chapel", Color(0.34, 0.46, 0.56), 10.0], ["quarry_crane", Color(0.5, 0.46, 0.4), 15.0]]:
		if not spots.has(b[0]):
			continue
		var at: Vector3 = spots[b[0]].at
		var n: Variant = wf.call("beacon", holder, at, "", b[1], 34.0, 0.3, float(b[2]), false, 100.0)
		if n is Node:
			(n as Node).name = "Beacon_" + String(b[0])
			(n as Node).set_meta("poi", b[0])


# --- shared pieces -----------------------------------------------------------------------------

static func _xf(s: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(s.yaw)), s.at)


## Local point -> world, standing on the ground there plus v.y.
static func _gl(space: PhysicsDirectSpaceState3D, xf: Transform3D, v: Vector3) -> Vector3:
	var p := xf * Vector3(v.x, 0.0, v.z)
	p.y = RealmLayout.ground(space, p.x, p.z) + v.y
	return p


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


## The place's fighting floor (reserved and levelled): a guardian site at its centre.
static func _floor(host: Node3D, fid: String) -> void:
	if not floors.has(fid):
		return
	var c: Vector3 = floors[fid]
	var space := host.get_world_3d().direct_space_state
	c.y = RealmLayout.ground(space, c.x, c.z)
	var r := 6.5
	for pid: String in FLOORS:
		if String(FLOORS[pid][0]) == fid:
			r = float(FLOORS[pid][1])
	var m := P._miniboss(host, fid, c, r, String(host.get_meta("region")))
	m.set_meta("r34", true)


static func _reserve_floor(space: PhysicsDirectSpaceState3D, id: String, camps: Array[Vector2], fires: Array[Vector2]) -> void:
	var f: Array = FLOORS[id]
	var fid := String(f[0])
	var r := float(f[1])
	var s: Dictionary = spots[id]
	var xf := _xf(s)
	var cands: Array = (f[2] as Array).duplicate()
	for rr: float in [r + 5.0, r + 7.0, r + 10.0, r + 13.0, r + 16.0, r + 20.0]:
		for i in 24:
			var a := TAU * float(i) / 24.0
			cands.append(Vector3(cos(a) * rr, 0, sin(a) * rr))
	var best := Vector3.INF
	var best_s := INF
	var why := {}
	for limit: float in [3.0, 4.8]:
		if best != Vector3.INF:
			break
		for i in cands.size():
			var off: Vector3 = cands[i]
			var c3 := xf * off
			var q := Vector2(c3.x, c3.z)
			var rc := Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0)
			if not RealmLayout.BOUNDS.grow(-4.0).encloses(rc):
				why["bounds"] = int(why.get("bounds", 0)) + 1
				continue
			if RealmLayout.path_dist(q) < r * 0.6:
				why["path"] = int(why.get("path", 0)) + 1
				continue
			var hit_site := ""
			for st: Dictionary in WorldLanes.sites:
				if String(st.name) == "poi_" + id and id == "quarry_crane":
					continue                    # the pit floor round the crane is the crane's own yard
				if WorldLanes.site_hits_rect(st, rc, 0.3) if String(st.name).begins_with("raid_") else (st.rect as Rect2).grow(0.3).intersects(rc):
					hit_site = String(st.name)
					break
			if hit_site != "":
				why[hit_site] = int(why.get(hit_site, 0)) + 1
				continue
			var bad := false
			for cp in camps:
				if cp.distance_to(q) < r + 3.5:
					bad = true
			for fp in fires:
				if fp.distance_to(q) < r + 9.0:
					bad = true
			if bad:
				why["camp/fire"] = int(why.get("camp/fire", 0)) + 1
				continue
			var hs: Array[float] = []
			for j in 9:
				var qq := q if j == 8 else q + Vector2(cos(TAU * float(j) / 8.0), sin(TAU * float(j) / 8.0)) * r
				hs.append(RealmLayout.ground(space, qq.x, qq.y))
			hs.sort()
			if hs[0] < WATER + 0.15:
				why["water"] = int(why.get("water", 0)) + 1
				continue
			var rise := hs[8] - hs[0]
			if rise > limit:
				why["rise"] = int(why.get("rise", 0)) + 1
				continue
			var sc := rise * 1.2 + Vector2(off.x, off.z).length() * 0.5 + (0.0 if i < (f[2] as Array).size() else 1.5)
			if sc < best_s:
				best_s = sc
				best = Vector3(q.x, hs[4], q.y)
	if best == Vector3.INF:
		print("REALM_POI r34 %s: no ground for a fighting floor (%s)" % [fid, why])
		return
	floors[fid] = best
	WorldLanes.register_terrace("poi_floor_" + fid, Vector2(best.x, best.z), r, best.y)


## A glide perch facing whichever of 8 ways (round `pref`) falls farthest within 6 m; none under 5.5 m.
static func _perch_auto(host: Node3D, space: PhysicsDirectSpaceState3D, at: Vector3, pref: Vector3) -> void:
	var best := Vector3.ZERO
	var best_drop := 0.0
	var a0 := atan2(pref.x, pref.z)
	for i in 8:
		var a := a0 + TAU * float(i) / 8.0
		var f := Vector3(sin(a), 0, cos(a))
		var g := RealmLayout.ground(space, at.x + f.x * 6.0, at.z + f.z * 6.0)
		var drop := at.y - maxf(g, WATER)
		if drop > best_drop + (0.4 if i > 0 else 0.0):
			best_drop = drop
			best = f
	if best_drop > 5.5:
		P._perch(host, at, best, best_drop)


static func _cyl_mesh(r0: float, r1: float, h: float, sides := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var v00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var v01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var v10 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var v11 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for v: Vector3 in [v00, v10, v11, v00, v11, v01, Vector3(0, h, 0), v11, v10]:
			st.set_uv(Vector2(float(i) / sides, v.y))
			st.set_color(Color(1, 1, 1, 1))
			st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A post / trunk / barrel from `a` to `b` (radius r0 at a, r1 at b), with a box of collision.
static func _cyl(k: OssKit, key: String, a: Vector3, b: Vector3, r0: float, r1: float, solid := false, sides := 10) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var bas := Basis(side, up, side.cross(up))
	k.append_mesh(key, _cyl_mesh(r0, r1, d.length(), sides), Transform3D(bas, a))
	if solid:
		LK.col_box(k, (a + b) * 0.5, Vector3(maxf(r0, r1) * 1.7, d.length(), maxf(r0, r1) * 1.7), bas)


## Climbing blocks: [local x, local z, top (m above the place's floor), size xz (, bottom)]; each a
## solid stone from under the ground (or `bottom`) to its top. Returns the stand points (world).
static func _steps(k: OssKit, xf: Transform3D, steps: Array, key := "stone", jit := 0.04, rng: RandomNumberGenerator = null) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var b := xf.basis
	for st: Array in steps:
		var x: float = st[0]
		var z: float = st[1]
		var top: float = st[2]
		var sz: Vector2 = st[3]
		var yj := rng.randf_range(-jit, jit) if rng else 0.0
		var h := top + 1.2 if st.size() < 5 else top - float(st[4])
		k.box(key, xf * Vector3(x, top - h * 0.5, z), Vector3(sz.x, h, sz.y), b * Basis(Vector3.UP, yj), true, 0.86)
		k.box(key, xf * Vector3(x, top + 0.04, z), Vector3(sz.x + 0.08, 0.1, sz.y + 0.08), b * Basis(Vector3.UP, yj), false, 0.96)
		out.append(xf * Vector3(x, top, z))
	return out


static func _smoke(host: Node3D, at: Vector3, col := Color(0.32, 0.3, 0.3), count := 10) -> void:
	var smoke := Vfx.emitter(col, {"count": count, "life": 4.5, "speed": Vector2(0.2, 0.5), "size": 0.9, "gravity": 0.15, "radius": 0.6, "additive": false, "damping": 0.2})
	host.add_child(smoke)
	smoke.global_position = at
	smoke.emitting = true


## Overgrowth round a place with a footprint to keep out of (a local-space rect, grown by 0.6 m).
static func _grow(host: Node3D, space: PhysicsDirectSpaceState3D, xf: Transform3D, rng: RandomNumberGenerator, kinds: Array, keep: Rect2 = Rect2()) -> void:
	var items := {}
	var inv := xf.affine_inverse()
	var avoid := func(q: Vector2) -> bool:
		if keep.size == Vector2.ZERO:
			return false
		var lq := inv * Vector3(q.x, (xf.origin).y, q.y)
		return keep.grow(0.6).has_point(Vector2(lq.x, lq.z))
	for kd: Array in kinds:
		P._ring_plants(items, space, rng, String(kd[0]), xf.origin, float(kd[1]), float(kd[2]), int(kd[3]), avoid)
	P._plants(host, items)


# --- The Unfinished Stair (quarry pit floor) ---------------------------------------------------

const CRANE_DECK := 8.0

static func _quarry_crane(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34001
	var k := OssKit.new()
	k.keep_lanes = false
	# the giant stair: squared blocks the cutters set as steps up to the crane's pier (each 1.6 m)
	var stand := _steps(k, xf, [[2.6, 5.0, 1.6, Vector2(2.4, 1.5)], [2.3, 3.5, 3.2, Vector2(2.4, 1.5)], [2.7, 2.0, 4.8, Vector2(2.4, 1.5)], [2.4, 0.5, 6.4, Vector2(2.4, 1.5)]], "stone", 0.05, rng)
	# the pier: courses of squared stone, a timber deck on top
	var pc := Vector3(2.5, 0, -2.6)
	for i in 4:
		var y0 := float(i) * 2.0
		k.box("stone", xf * (pc + Vector3(0, y0 + 1.0 - (0.6 if i == 0 else 0.0), 0)), Vector3(4.2 - 0.1 * i, 2.0 + (1.2 if i == 0 else 0.0), 4.2 - 0.1 * i), b * Basis(Vector3.UP, 0.02 * float(i % 2)), true, 0.8 + 0.04 * float(i % 2))
	for j in 6:
		k.box("wood", xf * (pc + Vector3(-1.65 + 0.7 * j, CRANE_DECK + 0.06, 0)), Vector3(0.66, 0.12, 3.85), b, true, rng.randf_range(0.75, 0.95))
	# the crane: a mast with two struts, the jib out over the pit (local -x), a rope and a block
	var mast := pc + Vector3(-1.2, CRANE_DECK, -0.9)
	_cyl(k, "wood", xf * mast, xf * (mast + Vector3(0, 7.2, 0)), 0.24, 0.2, true)
	for sd: float in [-1.0, 1.0]:
		_cyl(k, "wood", xf * (mast + Vector3(1.4, 0, sd * 1.2)), xf * (mast + Vector3(0.1, 4.6, 0)), 0.1, 0.09)
	var j0 := mast + Vector3(0.6, 6.4, 0)
	var j1 := mast + Vector3(-9.0, 8.6, 0)
	_cyl(k, "wood", xf * j0, xf * j1, 0.2, 0.13)
	_cyl(k, "wood", xf * (mast + Vector3(0, 7.2, 0)), xf * (mast + Vector3(-6.0, 8.0, 0)), 0.05, 0.05)   # the stay
	# r36: the rope and its block hang from the jib's sheave and swing, slow and heavy
	var sheave := j1 + Vector3(0.1, 0, 0)
	var sw := Sway.hang(host, xf * sheave, b.get_euler().y, 0.012, 4.6, 0.5)
	var kh := OssKit.new()
	kh.keep_lanes = false
	_cyl(kh, "iron", Vector3.ZERO, Vector3(0, 3.4 - sheave.y, 0), 0.035, 0.035)    # the rope
	kh.box("stone", Vector3(0, 2.5 - sheave.y, 0), Vector3(1.4, 1.0, 1.0), Basis(Vector3.UP, 0.4), false, 0.84)
	sw.take(kh, 120.0)
	# the windlass on the deck
	_cyl(k, "wood", xf * (pc + Vector3(0.6, CRANE_DECK + 0.7, -1.6)), xf * (pc + Vector3(0.6, CRANE_DECK + 0.7, 1.0)), 0.32, 0.32)
	for z: float in [-1.7, 1.1]:
		k.box("wood", xf * (pc + Vector3(0.6, CRANE_DECK + 0.45, z)), Vector3(0.16, 0.9, 0.16), b, true, 0.8)
	# squared blocks waiting for a cart that never came, rollers and a sledge
	for i in 11:
		var row := i % 4
		var col := i / 4
		var v := Vector3(-3.8 - 1.9 * float(col), 0.0, 3.2 + 1.3 * float(row) - 2.0 * float(col))
		var y := RealmLayout.ground(space, (xf * v).x, (xf * v).z)
		var p := xf * v
		p.y = y + 0.42
		k.box("stone", p, Vector3(1.7, 0.9, 1.0), b * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), true, rng.randf_range(0.78, 0.92))
		if i % 3 == 0:
			k.box("stone", p + Vector3(0, 0.88, 0), Vector3(1.6, 0.86, 0.95), b * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), true, 0.88)
	for i in 3:
		var r := _gl(space, xf, Vector3(-1.2 + 0.7 * float(i), 0.12, 7.2))
		_cyl(k, "wood", r + b * Vector3(0, 0, -0.9), r + b * Vector3(0, 0, 0.9), 0.12, 0.12)
	var sl := _gl(space, xf, Vector3(-0.3, 0.3, 7.4))
	k.box("stone", sl + Vector3.UP * 0.1, Vector3(1.6, 0.8, 1.0), b * Basis(Vector3.UP, 0.1), true, 0.86)
	for side: float in [-0.45, 0.45]:
		k.box("wood", sl + b * Vector3(0, -0.28, side), Vector3(2.4, 0.16, 0.14), b, false, 0.7)
	k.commit(host, "CraneBody")
	var deck := xf * (pc + Vector3(-0.2, CRANE_DECK, 1.3))
	stand.append(deck)
	host.set_meta("route", stand)
	host.set_meta("walk", [false, false, false, false, false])
	host.set_meta("approach", xf * Vector3(2.6, 0, 7.6))
	_chest(host, "quarry_jib", xf * (pc + Vector3(1.4, CRANE_DECK + 0.12, 1.3)), float(s.yaw) + PI)
	P._lore(host, "poi_quarry_stair", xf * Vector3(2.6, 1.0, 5.0 + 0.78))
	P._lore(host, "poi_quarry_crane", xf * (pc + Vector3(-0.6, CRANE_DECK + 1.0, -0.4)), xf * (mast + Vector3(0, 1.2, 0)))
	P._grapple(host, xf * (mast + Vector3(0, 7.0, 0)), deck)
	P._grapple(host, xf * (j1 + Vector3(0.6, -0.2, 0)), deck, 16.0)
	P._perch(host, xf * (pc + Vector3(-1.95, CRANE_DECK, 1.2)), -b.x, CRANE_DECK)
	P._light(host, xf * (j1 + Vector3(0.4, -0.6, 0)), Color(0.75, 0.82, 1.0), 0.8, 8.0)
	_floor(host, "quarry_pit")
	_grow(host, space, xf, rng, [["moss", 1.0, 9.0, 24], ["grass", 4.0, 10.0, 40], ["tallgrass", 6.0, 11.0, 12]], Rect2(-1.0, -5.0, 6.0, 11.0))


# --- The Winch-House (quarry high bench) --------------------------------------------------------

static func _quarry_winch(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34002
	var k := OssKit.new()
	k.keep_lanes = false
	var hx := 3.0
	var hz := 2.3
	var t := 0.5
	var wh := 3.4
	k.box("floor", xf * Vector3(0, 0.02, 0), Vector3(hx * 2.0 - 0.2, 0.2, hz * 2.0 - 0.2), b, true, 0.85)
	k.box("stone", xf * Vector3(0, -0.4, 0), Vector3(hx * 2.0 + 0.3, 1.0, hz * 2.0 + 0.3), b, true, 0.72)
	# walls: the front (+z, toward the pit) has the door; the east (+x) wall has the wheel's axle-hole
	for wl: Array in [[Vector3(0, wh * 0.5, -hz + t * 0.5), Vector3(hx * 2.0, wh, t)], [Vector3(-hx + t * 0.5, wh * 0.5, 0), Vector3(t, wh, hz * 2.0)],
			[Vector3(hx - t * 0.5, wh * 0.5, 0), Vector3(t, wh, hz * 2.0)], [Vector3(-1.85, wh * 0.5, hz - t * 0.5), Vector3(2.3, wh, t)], [Vector3(1.85, wh * 0.5, hz - t * 0.5), Vector3(2.3, wh, t)],
			[Vector3(0, wh - 0.5, hz - t * 0.5), Vector3(1.4, 1.0, t)]]:
		k.box("stone", xf * (wl[0] as Vector3), wl[1], b, true, rng.randf_range(0.8, 0.9))
	k.box("slate", xf * Vector3(0, wh + 0.15, 0), Vector3(hx * 2.0, 0.3, hz * 2.0), b, true, 0.85)
	# inside: the winding drum on two trestles, coils of rope
	_cyl(k, "wood", xf * Vector3(-1.6, 1.1, -1.2), xf * Vector3(2.2, 1.1, -1.2), 0.45, 0.45, true)
	for x: float in [-1.4, 1.9]:
		k.box("wood", xf * Vector3(x, 0.55, -1.2), Vector3(0.18, 1.1, 0.9), b, true, 0.75)
	# the tread-wheel outside the east wall, its axle through to the drum
	var wc := Vector3(hx + 0.9, 2.3, -0.2)
	# r36: the wheel creaks round on its axle (something in the pit still hauls on the rope)
	var wheel := Sway.turner(host, xf * wc, b.get_euler().y, Vector3.RIGHT, -0.16)
	var kw := OssKit.new()
	kw.keep_lanes = false
	for i in 16:
		var a := TAU * float(i) / 16.0
		var p := Vector3(0, sin(a) * 2.0, cos(a) * 2.0)
		kw.box("wood", p, Vector3(1.3, 0.16, 0.82), Basis(Vector3.RIGHT, -a), false, rng.randf_range(0.7, 0.9))
	for i in 4:
		var a := PI * float(i) / 4.0
		kw.box("wood", Vector3.ZERO, Vector3(0.12, 4.0, 0.14), Basis(Vector3.RIGHT, a), false, 0.75)
	wheel.take(kw, 120.0)
	_cyl(k, "wood", xf * (wc + Vector3(-1.2, 0, 0)), xf * (wc + Vector3(0.8, 0, 0)), 0.16, 0.16)
	for z: float in [-2.1, 1.7]:
		k.box("wood", xf * (wc + Vector3(0.75, -1.2, z)), Vector3(0.2, 2.6, 0.2), b, true, 0.75)
	# the rope down to the pit floor, frayed
	_cyl(k, "iron", xf * (wc + Vector3(0.0, -0.4, 2.1)), xf * Vector3(wc.x, -3.0, 13.0), 0.04, 0.04)
	# a stack of stone to climb onto the roof (west side)
	var stand := _steps(k, xf, [[-hx - 0.72, 0.9, 2.2, Vector2(1.4, 1.4)]], "stone", 0.0, rng)
	# a post on the roof the Tether can catch
	k.box("wood", xf * Vector3(1.6, wh + 1.0, -1.2), Vector3(0.22, 1.7, 0.22), b, true, 0.75)
	k.commit(host, "WinchBody")
	var roof := xf * Vector3(-2.3, wh + 0.3, 0.9)
	stand.append(roof)
	host.set_meta("route", stand)
	host.set_meta("walk", [false, false])
	host.set_meta("approach", xf * Vector3(-hx - 1.0, 0, 3.4))
	_chest(host, "quarry_winch", xf * Vector3(1.5, 0.12, 0.7), float(s.yaw) - PI * 0.5)
	P._lore(host, "poi_quarry_tally", xf * Vector3(-hx + t + 0.6, 1.3, 0.0), xf * Vector3(-hx + t + 0.02, 1.6, 0.0))
	P._lore(host, "poi_quarry_winch", xf * Vector3(1.2, 1.2, hz + 0.9), xf * Vector3(1.2, 1.6, hz + 0.02))
	P._grapple(host, xf * Vector3(1.6, wh + 1.85, -1.2), roof)
	_perch_auto(host, space, xf * Vector3(0.0, wh + 0.3, hz - 0.3), b.z)
	_grow(host, space, xf, rng, [["moss", 3.0, 7.0, 16], ["grass", 4.0, 8.0, 30], ["heather", 4.5, 8.0, 14]], Rect2(-hx - 1.6, -hz - 0.6, hx * 2.0 + 4.8, hz * 2.0 + 1.6))


# --- The Hall-Mound (Rooted Holds) -------------------------------------------------------------

const HALL_RIDGE := 5.0

static func _holds_hall(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34003
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var hx := 3.0                      # outer half width (walls' outer face)
	var hz := 5.0
	var wy := 2.4                      # wall top
	var t := 0.7
	k.box("lore_soil", xf * Vector3(0, 0.03, 0), Vector3(hx * 2.0 - 0.4, 0.14, hz * 2.0 - 0.4), b, true, 0.8)
	k.box("lore_moss", xf * Vector3(0, -0.45, 0), Vector3(hx * 2.0 + 0.4, 1.0, hz * 2.0 + 0.4), b, true, 0.7)
	for wl: Array in [[Vector3(-hx + t * 0.5, wy * 0.5, 0), Vector3(t, wy, hz * 2.0)], [Vector3(hx - t * 0.5, wy * 0.5, 0), Vector3(t, wy, hz * 2.0)],
			[Vector3(0, wy * 0.5, -hz + t * 0.5), Vector3(hx * 2.0, wy, t)],
			[Vector3(-1.9, wy * 0.5, hz - t * 0.5), Vector3(1.6, wy, t)], [Vector3(1.9, wy * 0.5, hz - t * 0.5), Vector3(1.6, wy, t)]]:
		k.box("lore_moss", xf * (wl[0] as Vector3), wl[1], b, true, rng.randf_range(0.8, 0.9))
	# the door: two great jambs and a lintel stone, a carved door-stone set on its side
	for sx: float in [-1.0, 1.0]:
		k.box("lore_tstone", xf * Vector3(sx * 1.2, 1.25, hz - t * 0.5 + 0.05), Vector3(0.5, 2.5, 0.85), b, true, 0.95)
	k.box("lore_tstone", xf * Vector3(0, 2.62, hz - t * 0.5 + 0.05), Vector3(3.0, 0.5, 0.95), b, true, 0.9)
	# the roof: turf on both slopes from the wall tops to the ridge, and the gables stepped in turf
	var run := hx
	var rise := HALL_RIDGE - wy
	var ang := atan2(rise, run)
	var ln := sqrt(run * run + rise * rise) + 0.3
	for sx: float in [-1.0, 1.0]:
		# the slab's top face runs from the wall top (hx, wy) to the ridge (0, HALL_RIDGE)
		var nrm := Vector3(sx * sin(ang), cos(ang), 0)
		var c := Vector3(sx * hx * 0.5, (wy + HALL_RIDGE) * 0.5, 0) - nrm * 0.25
		k.box("lore_earth", xf * c, Vector3(ln, 0.5, hz * 2.0 + 0.5), b * Basis(Vector3.BACK, sx * -ang), true, 0.8)
	for zs: float in [-1.0, 1.0]:
		for row in 6:
			var y := wy + rise * (float(row) + 0.5) / 6.0
			var w := hx * 2.0 * (1.0 - (float(row) + 0.5) / 6.0)
			if zs > 0.0 and row < 1:
				continue                               # over the door: the lintel carries it
			k.box("lore_earth", xf * Vector3(0, y, zs * (hz - 0.35)), Vector3(w, rise / 6.0 + 0.02, 0.7), b, true, 0.78)
	# earth banks against the long walls: walk up them onto the roof (35 degrees)
	var ba := deg_to_rad(40.0)
	var bank_run := wy / tan(ba)
	for sx: float in [-1.0, 1.0]:
		var bl := wy / sin(ba)
		var bn := Vector3(sx * sin(ba), cos(ba), 0)
		var bc := Vector3(sx * (hx + bank_run * 0.5), wy * 0.5, 0) - bn * 0.3
		k.box("lore_earth", xf * bc, Vector3(bl + 0.4, 0.6, hz * 2.0 - 1.4), b * Basis(Vector3.BACK, sx * -ba), true, 0.76)
	# the smoke-hole: a dark square in the ridge, a breath of hearth smoke
	k.box("dark", xf * Vector3(0, HALL_RIDGE + 0.18, -1.0), Vector3(0.9, 0.05, 1.0), b, false, 0.3)
	# inside: the hearth-pit, benches along the walls, the high seat at the back
	var hearth := Vector3(0, 0, 0.6)
	for i in 10:
		var a := TAU * float(i) / 10.0
		k.box("lore_rock", xf * (hearth + Vector3(cos(a) * 0.7, 0.12, sin(a) * 1.1)), Vector3(0.36, 0.26, 0.32), b * Basis(Vector3.UP, a), false, 0.8)
	k.box("glow", xf * (hearth + Vector3(0, 0.1, 0)), Vector3(0.5, 0.05, 0.9), b, false, 0.25)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", xf * Vector3(sx * (hx - t - 0.3), 0.3, 0.6), Vector3(0.5, 0.45, 5.4), b, true, 0.75)
	var seat := Vector3(0, 0, -hz + t + 0.55)
	k.box("lore_tstone", xf * (seat + Vector3(0, 0.3, 0)), Vector3(1.4, 0.6, 0.8), b, true, 0.9)
	k.box("lore_tstone", xf * (seat + Vector3(0, 1.1, -0.3)), Vector3(1.4, 1.6, 0.25), b, true, 0.92)
	for sx: float in [-1.0, 1.0]:
		k.box("lore_tstone", xf * (seat + Vector3(sx * 0.62, 0.8, 0)), Vector3(0.16, 0.5, 0.8), b, false, 0.9)
	# a post on the front gable the Tether can catch
	k.box("wood", xf * Vector3(0, HALL_RIDGE + 0.6, hz - 0.3), Vector3(0.22, 1.4, 0.22), b, true, 0.75)
	k.commit(host, "HallBody")
	_smoke(host, xf * Vector3(0, HALL_RIDGE + 0.4, -1.0), Color(0.3, 0.29, 0.28), 6)
	var ridge := xf * Vector3(hx * 0.12, HALL_RIDGE - hx * 0.12 * (HALL_RIDGE - wy) / hx, 0.0)   # just off the ridge line, on the slope
	host.set_meta("route", [xf * Vector3(hx + bank_run * 0.45, wy * 0.55, 0), xf * Vector3(hx * 0.45, wy + rise * 0.55, 0), ridge] as Array[Vector3])
	host.set_meta("walk", [true, true, true])
	host.set_meta("approach", xf * Vector3(hx + bank_run + 1.6, 0, 0))
	_chest(host, "holds_hall", xf * (seat + Vector3(0, 0.0, 1.1)), float(s.yaw) + PI)
	P._lore(host, "poi_holds_hall", xf * Vector3(1.9, 1.2, hz + 0.6), xf * Vector3(1.2, 1.4, hz + 0.1))
	P._lore(host, "poi_holds_seat", xf * (seat + Vector3(0.9, 0.9, 1.0)), xf * (seat + Vector3(0, 1.4, -0.14)))
	Interiors.room_lights(host, "holds_hall", xf * Vector3(0, 1.4, 0), float(s.yaw), Vector3(hx - t, 1.8, hz - t), false, 1.6)
	Interiors.light(host, "HallHearth", xf * (hearth + Vector3(0, 0.7, 0)), Color(1.0, 0.5, 0.2), 3.2, 8.0, false, 0.12)
	P._grapple(host, xf * Vector3(0, HALL_RIDGE + 1.25, hz - 0.3), ridge)
	_perch_auto(host, space, ridge, b.z)
	_grow(host, space, xf, rng, [["heather", hx + 3.5, 10.0, 40], ["grass", hx + 3.0, 10.0, 50], ["flowers", hx + 3.5, 9.0, 14]], Rect2(-hx - 4.0, -hz - 0.5, hx * 2.0 + 8.0, hz * 2.0 + 1.0))


# --- The Earth-Houses (Rooted Holds) -----------------------------------------------------------

static func _holds_houses(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34004
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var ring := Vector3(0, 0, 3.0)
	var houses := [Vector3(-3.6, 0, 0.4), Vector3(3.6, 0, 0.4), Vector3(0, 0, -3.4)]
	var open_c := Vector3.ZERO
	for hi in houses.size():
		var hc: Vector3 = houses[hi]
		var to := (ring - hc).normalized()
		var door_a := atan2(to.x, to.z)
		var base := _gl(space, xf, hc)
		var hy := base.y
		var hb := b * Basis(Vector3.UP, door_a)
		# five courses of turf, each stepping in, a gap for the door facing the fire-ring (headroom
		# under the fifth course: 2.17 m)
		for tier in 5:
			var r := 2.6 - 0.25 * float(tier)
			var n := 12
			for i in n:
				var a := TAU * (float(i) + 0.5) / float(n)
				if tier < 4 and absf(angle_difference(a, 0.0)) < 0.4:
					continue                         # the door (local +z of the house)
				var q := Vector3(sin(a) * r, 0.25 + 0.55 * float(tier), cos(a) * r)
				k.box("lore_earth", Vector3(base.x, hy, base.z) + hb * q, Vector3(TAU * r / float(n) + 0.12, 0.58, 0.62), hb * Basis(Vector3.UP, a), true, rng.randf_range(0.74, 0.86))
		k.box("lore_earth", Vector3(base.x, hy + 2.86, base.z), Vector3(2.2, 0.36, 2.2), hb * Basis(Vector3.UP, 0.4), true, 0.8)
		k.box("lore_earth", Vector3(base.x, hy + 3.1, base.z), Vector3(1.6, 0.3, 1.6), hb, true, 0.82)
		# door-stones: two uprights and a lintel
		for sx: float in [-1.0, 1.0]:
			k.box("lore_tstone", Vector3(base.x, hy, base.z) + hb * Vector3(sx * 0.78, 1.0, 2.55), Vector3(0.3, 2.0, 0.4), hb, true, 0.9)
		k.box("lore_tstone", Vector3(base.x, hy, base.z) + hb * Vector3(0, 2.12, 2.55), Vector3(1.9, 0.28, 0.5), hb, true, 0.9)
		k.box("lore_soil", Vector3(base.x, hy + 0.03, base.z), Vector3(3.6, 0.06, 3.6), hb, false, 0.8)
		if hi == 0:
			open_c = Vector3(base.x, hy, base.z) + hb * Vector3(0, 0.06, -0.7)
		else:
			k.box("lore_beam", Vector3(base.x, hy, base.z) + hb * Vector3(0, 1.0, 2.6), Vector3(1.3, 1.95, 0.1), hb, true, 0.6)   # a shut door
	# the fire-ring, cold, a drying rack and a quern
	var rc := _gl(space, xf, ring)
	for i in 9:
		var a := TAU * float(i) / 9.0
		k.box("lore_rock", rc + Vector3(cos(a) * 1.0, 0.12, sin(a) * 1.0), Vector3(0.4, 0.26, 0.34), Basis(Vector3.UP, a), false, 0.8)
	k.box("dark", rc + Vector3(0, 0.03, 0), Vector3(1.4, 0.04, 1.4), Basis.IDENTITY, false, 0.3)
	var rack := _gl(space, xf, Vector3(4.4, 0, 4.8))
	for sx: float in [-1.0, 1.0]:
		k.box("wood", rack + b * Vector3(sx * 1.2, 0.9, 0), Vector3(0.12, 1.8, 0.12), b, true, 0.7)
	k.box("wood", rack + b * Vector3(0, 1.75, 0), Vector3(2.6, 0.08, 0.08), b, false, 0.7)
	for j in 4:
		k.box("lore_beam", rack + b * Vector3(-0.9 + 0.6 * j, 1.35, 0), Vector3(0.12, 0.7, 0.04), b, false, 0.5)
	var qn := _gl(space, xf, Vector3(-3.8, 0, 4.8))
	_cyl(k, "lore_tstone", qn, qn + Vector3.UP * 0.35, 0.45, 0.45, true, 12)
	_cyl(k, "lore_tstone", qn + Vector3.UP * 0.37, qn + Vector3.UP * 0.55, 0.42, 0.4, false, 12)
	k.commit(host, "HousesBody")
	_chest(host, "holds_house", open_c, float(s.yaw))
	P._lore(host, "poi_holds_door", _gl(space, xf, Vector3(-1.4, 1.3, 3.6)), _gl(space, xf, Vector3(-2.6, 2.1, 2.4)))
	P._lore(host, "poi_holds_quern", qn + b * Vector3(0.6, 0.9, 0.6), qn + Vector3.UP * 0.6)
	_grow(host, space, xf, rng, [["heather", 7.0, 11.0, 36], ["grass", 2.0, 11.0, 60], ["flowers", 3.0, 9.0, 12]], Rect2(-6.4, -6.2, 12.8, 9.6))


# --- The Bell Furnace (Founder's Pits) ---------------------------------------------------------

const FURN_W := 6.0
const FURN_TOP := 12.0

static func _foundry_furnace(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34005
	var k := OssKit.new()
	k.keep_lanes = false
	var h := FURN_W * 0.5
	var zc := -1.0                        # the tower stands back on the site; the casting floor before it
	# the furnace: a battered stone stack, stepping in at two courses, iron hoops
	k.box("stone", xf * Vector3(0, 2.5 - 0.6, zc), Vector3(FURN_W + 1.2, 5.0 + 1.2, FURN_W + 1.2), b, true, 0.78)
	k.box("stone", xf * Vector3(0, 5.0 + 3.5, zc), Vector3(FURN_W, 7.0, FURN_W), b, true, 0.84)
	k.box("stone", xf * Vector3(0, 5.0, zc), Vector3(FURN_W + 1.25, 0.3, FURN_W + 1.25), b, false, 0.92)
	for y: float in [7.0, 10.0]:
		k.box("iron", xf * Vector3(0, y, zc), Vector3(FURN_W + 0.1, 0.18, FURN_W + 0.1), b, false, 0.85)
	# the chimney on the platform's back half
	k.box("stone", xf * Vector3(0.0, FURN_TOP + 2.0, zc - 1.6), Vector3(2.4, 4.0, 2.2), b, true, 0.86)
	k.box("dark", xf * Vector3(0.0, FURN_TOP + 4.02, zc - 1.6), Vector3(1.5, 0.04, 1.3), b, false, 0.3)
	# the mouth: an arch of dark firebrick on the front, glowing deep inside
	k.box("dark", xf * Vector3(0, 1.3, zc + h + 0.6 + 0.01), Vector3(1.9, 2.6, 0.06), b, false, 0.35)
	k.box("glow", xf * Vector3(0, 0.6, zc + h + 0.6 + 0.02), Vector3(1.4, 0.9, 0.04), b, false, 0.45)
	k.box("stone", xf * Vector3(0, 2.85, zc + h + 0.75), Vector3(2.6, 0.5, 0.5), b, true, 0.9)
	for sx: float in [-1.0, 1.0]:
		k.box("stone", xf * Vector3(sx * 1.25, 1.3, zc + h + 0.75), Vector3(0.45, 2.6, 0.5), b, true, 0.9)
	# the outside stair: up the east face (+x), across the back, a broken last flight on the west
	var sw := 1.3
	var d := h + 0.6 + sw * 0.5             # the first course is 0.6 wider each side
	var east_lo := Vector3(d, 0.0, zc + h + 0.4)
	var east_hi := Vector3(d, 5.0, zc - h + 0.6)
	k.stairs("stone", xf * east_lo, xf * east_hi, sw, 16)
	k.box("stone", xf * Vector3(d, 4.7, zc - h - 0.15), Vector3(sw, 0.6, sw), b, true, 0.9)
	# the ledge round the first course top (y 5) is the landing; from the back the upper flight
	var d2 := h + sw * 0.5
	var back_lo := Vector3(d2, 5.0, zc - h - sw * 0.5)
	var back_hi := Vector3(-d2 + 1.6, 9.0, zc - h - sw * 0.5)
	k.stairs("stone", xf * back_lo, xf * back_hi, sw, 13)
	k.box("stone", xf * Vector3(-d2 + 1.0, 8.7, zc - h - sw * 0.5), Vector3(1.2, 0.6, sw), b, true, 0.9)
	# the west flight fell: two corbel stones jut from the wall, grab them to the platform
	var c1 := Vector3(-d2, 10.6, zc - h + 0.7)
	k.box("stone", xf * (c1 + Vector3(0, -0.3, 0)), Vector3(sw, 0.6, 1.3), b, true, 0.88)
	k.box("stone", xf * (c1 + Vector3(0.3, -1.0, 0)), Vector3(0.6, 1.4, 0.6), b, false, 0.8)
	var top_c := Vector3(-1.0, FURN_TOP, zc + 1.2)
	# the charging platform: a parapet on three sides, open where the corbels come up (west)
	for wl: Array in [[Vector3(0, FURN_TOP + 0.4, zc + h - 0.2), Vector3(FURN_W, 0.8, 0.4)], [Vector3(h - 0.2, FURN_TOP + 0.4, zc), Vector3(0.4, 0.8, FURN_W)]]:
		k.box("stone", xf * (wl[0] as Vector3), wl[1], b, true, 0.9)
	k.box("stone", xf * Vector3(0, FURN_TOP - 0.15, zc), Vector3(FURN_W - 0.02, 0.3, FURN_W - 0.02), b, true, 0.86)
	# the charging hatch: an iron lid, a heap of charcoal, a crucible ladle
	k.box("iron", xf * Vector3(1.4, FURN_TOP + 0.04, zc + 1.2), Vector3(1.1, 0.08, 1.1), b, false, 0.8)
	for i in 6:
		k.box("dark", xf * Vector3(1.8 + rng.randf_range(-0.4, 0.4), FURN_TOP + 0.12, zc + 0.0 + rng.randf_range(-0.5, 0.5)), Vector3(0.4, 0.2, 0.35), b * Basis(Vector3.UP, rng.randf() * TAU), false, 0.4)
	# slag tipped down the flank, ingot moulds before the mouth
	for i in 6:
		var a := PI * 0.5 + rng.randf_range(-0.9, 0.9)
		var q := Vector3(cos(a) * rng.randf_range(5.0, 7.0), 0, zc + sin(a) * -rng.randf_range(5.0, 7.0))
		P._rock(host, _gl(space, xf, q) + Vector3.DOWN * 0.35, Vector3(1.6, 0.8, 1.3) * rng.randf_range(0.8, 1.3), "ash", 40 + i, rng.randf() * TAU)
	for i in 4:
		var mp := _gl(space, xf, Vector3(-2.4 + 1.6 * float(i), 0, zc + h + 3.0))
		k.box("stone", mp + Vector3.UP * 0.12, Vector3(1.0, 0.24, 0.6), b, false, 0.8)
		k.box("iron", mp + Vector3.UP * 0.25, Vector3(0.7, 0.04, 0.3), b, false, 0.7)
	k.commit(host, "FurnaceBody")
	_smoke(host, xf * Vector3(0.0, FURN_TOP + 4.4, zc - 1.6), Color(0.3, 0.28, 0.27), 12)
	var route: Array[Vector3] = [xf * (east_lo + Vector3(0, 0, 0.6)), xf * Vector3(d, 5.0, zc - h - 0.15), xf * (back_hi + Vector3(-0.6, 0, 0)), xf * c1, xf * top_c]
	host.set_meta("route", route)
	host.set_meta("walk", [true, true, true, false, false])
	host.set_meta("approach", xf * (east_lo + Vector3(0, 0, 2.4)))
	_chest(host, "foundry_relic", xf * Vector3(-0.4, FURN_TOP, zc + 2.0), float(s.yaw) + PI)
	P._lore(host, "poi_foundry_furnace", xf * Vector3(-1.9, 1.3, zc + h + 1.6), xf * Vector3(-1.25, 1.6, zc + h + 1.02))
	P._lore(host, "poi_foundry_relic", xf * Vector3(-2.0, FURN_TOP + 0.3, zc + 2.2))
	# the mouth breathes: ride it up the front with a spread robe to the platform
	P._updraft(host, xf * Vector3(0, 0.6, zc + h + 2.0), 2.4, FURN_TOP + 3.0, 6.0)
	P._grapple(host, xf * Vector3(h - 0.2, FURN_TOP + 1.0, zc + h - 0.2), xf * top_c)
	P._perch(host, xf * Vector3(-h + 0.4, FURN_TOP, zc + 1.6), -b.x, FURN_TOP)
	P._light(host, xf * Vector3(0, 1.0, zc + h + 1.6), Color(1.0, 0.45, 0.2), 1.2, 9.0)
	_floor(host, "foundry_floor")
	_grow(host, space, xf, rng, [["moss", h + 1.5, 9.0, 10], ["litter", h + 2.0, 9.0, 16]], Rect2(-h - 2.5, zc - h - 2.5, FURN_W + 5.0, FURN_W + 6.0))


# --- The Casting Pits (Founder's Pits) ---------------------------------------------------------

static func _foundry_pits(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34006
	var k := OssKit.new()
	k.keep_lanes = false
	var pits := [Vector3(-4.2, 0, -1.5), Vector3(0.6, 0, -3.2), Vector3(4.6, 0, 0.2)]
	var mould_c := Vector3.ZERO
	for i in pits.size():
		var pc: Vector3 = _gl(space, xf, pits[i])
		var r := 2.1 if i != 1 else 2.6
		# a kerb of firebrick, the pit's floor a crust of slag, warm underneath
		var n := 14
		for j in n:
			var a := TAU * float(j) / float(n)
			k.box("stone", pc + Vector3(cos(a) * r, 0.35, sin(a) * r), Vector3(TAU * r / float(n) + 0.05, 0.9, 0.5), Basis(Vector3.UP, -a + PI * 0.5), true, rng.randf_range(0.7, 0.85))
		k.box("dark", pc + Vector3(0, 0.08, 0), Vector3(r * 1.6, 0.06, r * 1.6), Basis(Vector3.UP, 0.4), false, 0.3)
		if i != 1:
			k.box("glow", pc + Vector3(0, 0.12, 0), Vector3(r * 0.8, 0.03, r * 0.6), Basis(Vector3.UP, rng.randf() * TAU), false, 0.2)
			P._updraft(host, pc + Vector3.UP * 0.3, r * 0.8, 11.0, 5.0)
			_smoke(host, pc + Vector3.UP * 0.6, Color(0.36, 0.33, 0.32), 5)
		else:
			mould_c = pc
	# the fourth bell's mould, cracked open in the big pit: a cope of clay, the core half out of it
	var bell := P._bell_mesh()
	k.append_mesh("plaster", bell, Transform3D(Basis(Vector3.RIGHT, 0.5).scaled(Vector3(2.2, 2.2, 2.2)), mould_c + Vector3(0.0, 0.2, 0.3)))
	k.box("plaster", mould_c + Vector3(0.9, 0.5, -0.8), Vector3(1.3, 0.9, 0.4), Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, 0.4), true, 0.8)
	LK.col_box(k, mould_c + Vector3(0.0, 1.0, 0.3), Vector3(2.4, 2.0, 2.4), Basis(Vector3.RIGHT, 0.5))
	# the gantry: two A-frames and a beam over the pits, a chain and a hook
	for sx: float in [-7.6, 7.6]:
		var f := _gl(space, xf, Vector3(sx, 0, -1.4))
		for sz: float in [-1.0, 1.0]:
			_cyl(k, "wood", f + b * Vector3(0, 0, sz * 1.4), f + b * Vector3(0, 5.6, 0), 0.16, 0.13, true)
	_cyl(k, "wood", _gl(space, xf, Vector3(-7.8, 5.5, -1.4)), _gl(space, xf, Vector3(7.8, 5.5, -1.4)), 0.18, 0.18)
	# r36: the chain and its hook sway over the pits
	var hk := Sway.hang(host, _gl(space, xf, Vector3(0.6, 5.4, -1.4)), b.get_euler().y, 0.03, 3.4, 0.8)
	var kk := OssKit.new()
	kk.keep_lanes = false
	_cyl(kk, "iron", Vector3.ZERO, Vector3(0, -2.8, 0), 0.04, 0.04)
	kk.box("iron", Vector3(0, -2.95, 0), Vector3(0.3, 0.3, 0.06), Basis.IDENTITY, false, 0.8)
	hk.take(kk, 90.0)
	# the founders' bench: tongs, a crucible, a ledger slab
	var bench := _gl(space, xf, Vector3(-1.6, 0, 4.4))
	for sx: float in [-0.9, 0.9]:
		k.box("stone", bench + b * Vector3(sx, 0.4, 0), Vector3(0.4, 0.8, 0.7), b, true, 0.8)
	k.box("stone", bench + b * Vector3(0, 0.88, 0), Vector3(2.4, 0.16, 0.9), b, true, 0.86)
	_cyl(k, "iron", bench + b * Vector3(0.6, 0.96, 0), bench + b * Vector3(0.6, 1.36, 0), 0.24, 0.3)
	k.box("iron", bench + b * Vector3(-0.5, 0.99, 0.1), Vector3(0.9, 0.04, 0.08), b * Basis(Vector3.UP, 0.3), false, 0.8)
	k.commit(host, "PitsBody")
	_chest(host, "foundry_mould", mould_c + b * Vector3(-1.5, 0.12, 0.9), float(s.yaw) + 0.6)
	P._lore(host, "poi_foundry_mould", mould_c + b * Vector3(-1.4, 1.0, 2.2), mould_c + Vector3(0, 1.2, 0))
	P._lore(host, "poi_foundry_ledger", bench + b * Vector3(-0.4, 1.3, 0.7), bench + b * Vector3(-0.6, 1.0, 0))
	P._light(host, _gl(space, xf, Vector3(0, 1.2, -0.6)), Color(1.0, 0.42, 0.18), 1.0, 9.0)
	_grow(host, space, xf, rng, [["litter", 3.0, 10.0, 24], ["moss", 6.0, 10.0, 10]])


# --- The Cairn Tor (Lanternless Moor) ----------------------------------------------------------

static func _moor_tor(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34007
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	# the tor's own rocks: weathered granite stacks round the crown (the ground is not cut here)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.4
		var q := Vector3(cos(a) * 5.4, 0, sin(a) * 5.4)
		if q.z > 3.0 and absf(q.x) < 3.0:
			continue                                   # the way up from the front stays open
		var g := _gl(space, xf, q)
		P._rock(host, g + Vector3.DOWN * 0.5, Vector3(3.0, 2.2, 2.6) * rng.randf_range(0.8, 1.2), "granite", 50 + i, rng.randf() * TAU, true, 140.0)
	# the guide-cairn ring: nine waist-high cairns, a stone for every hundred paces of the crossing
	var cairns: Array[Vector3] = []
	for i in 9:
		var a := TAU * float(i) / 9.0
		var g := _gl(space, xf, Vector3(cos(a) * 3.2, 0, sin(a) * 3.2))
		cairns.append(g)
		for j in 4:
			var sz := Vector3(0.7 - 0.13 * float(j), 0.28, 0.6 - 0.1 * float(j))
			k.box("lore_rock", g + Vector3(rng.randf_range(-0.06, 0.06), 0.1 + 0.27 * float(j), rng.randf_range(-0.06, 0.06)), sz, Basis(Vector3.UP, rng.randf() * TAU), j == 0, rng.randf_range(0.78, 0.92))
	# the watcher's seat: a slab chair on a stepped stone stack, its back to the moor, looking west
	var g0 := _gl(space, xf, Vector3(0, 0, 3.8)).y - o.y          # the ground the climb starts from
	var g1 := _gl(space, xf, Vector3(0, 0, -0.6)).y - o.y
	var t0 := g0 + 1.5
	var t1 := maxf(t0 + 1.5, g1 + 1.5)
	var stand := _steps(k, xf, [[0.0, 1.75, t0, Vector2(1.8, 3.1)], [0.0, -0.6, t1, Vector2(2.2, 1.6)]], "lore_rock", 0.0, rng)
	var top: Vector3 = stand[1]
	k.box("lore_tstone", top + b * Vector3(0, 0.25, -0.4), Vector3(1.2, 0.5, 0.6), b, true, 0.9)
	k.box("lore_tstone", top + b * Vector3(0, 0.9, -0.75), Vector3(1.2, 1.3, 0.2), b, true, 0.92)
	k.commit(host, "TorBody")
	host.set_meta("route", [stand[0], top + b * Vector3(-0.5, 0, 0.4)] as Array[Vector3])
	host.set_meta("walk", [false, false])
	host.set_meta("approach", _gl(space, xf, Vector3(0, 0, 4.3)))
	_chest(host, "moor_tor", top + b * Vector3(0.6, 0.09, 0.3), float(s.yaw))
	P._lore(host, "poi_moor_cairns", cairns[2] + Vector3(0, 1.0, 0) + (cairns[2] - o).normalized() * 0.6, cairns[2] + Vector3.UP * 0.9)
	P._lore(host, "poi_moor_seat", top + b * Vector3(0.9, 0.9, 0.3), top + b * Vector3(0, 1.2, -0.6))
	_perch_auto(host, space, top + b * Vector3(0, 0, 0.6), b.z)
	_floor(host, "moor_foot")
	_grow(host, space, xf, rng, [["heather", 2.0, 12.0, 60], ["grass", 4.0, 12.0, 40], ["moss", 1.0, 6.0, 16]])


# --- The Lanternless Shrine (Lanternless Moor) -------------------------------------------------

static func _moor_shrine(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34008
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	# a stepped base, a tall pillar with four iron arms -- each lantern hook struck off at the root
	k.box("lore_tstone", xf * Vector3(0, 0.1, 0), Vector3(3.2, 0.6, 3.2), b, true, 0.8)
	k.box("lore_tstone", xf * Vector3(0, 0.5, 0), Vector3(2.2, 0.3, 2.2), b, true, 0.86)
	k.box("lore_tstone", xf * Vector3(0, 2.6, 0), Vector3(0.8, 4.0, 0.8), b, true, 0.92)
	LK.half_disc(k, "lore_tstone", Transform3D(b, xf * Vector3(0, 4.6, 0)), 0.42, 0.0, 0.8, 2, true, 0.9)
	for i in 4:
		var a := PI * 0.5 * float(i)
		var f := Vector3(sin(a), 0, cos(a))
		k.box("iron", xf * (f * 0.75 + Vector3(0, 3.9, 0)), Vector3(0.7, 0.08, 0.08) if absf(f.x) > 0.5 else Vector3(0.08, 0.08, 0.7), b, false, 0.8)
		k.box("iron", xf * (f * 1.1 + Vector3(0, 3.82, 0)), Vector3(0.06, 0.18, 0.06), b, false, 0.6)    # the stub where the hook was
	# the offering niche in the front of the pillar, the box set in it
	k.box("dark", xf * Vector3(0, 1.2, 0.41), Vector3(0.6, 0.7, 0.04), b, false, 0.3)
	# a ring of eight low stones: the faithful knelt here in the dark and went on
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var q := Vector3(cos(a) * 3.6, 0, sin(a) * 3.6)
		if q.z > 2.4 and absf(q.x) < 1.5:
			continue
		var g := _gl(space, xf, q)
		k.box("lore_rock", g + Vector3.UP * 0.2, Vector3(0.7, 0.6, 0.5), Basis(Vector3.UP, -a), true, rng.randf_range(0.78, 0.9))
	# lanterns left on the ground, glass broken, every one cold
	for i in 5:
		var a := rng.randf_range(-1.2, 1.2)
		var g := _gl(space, xf, Vector3(sin(a) * 2.1, 0, cos(a) * 2.1))
		k.box("iron", g + Vector3.UP * 0.15, Vector3(0.22, 0.3, 0.22), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, 0.0 if i % 2 == 0 else 1.4), false, 0.7)
	k.commit(host, "ShrineBody")
	_chest(host, "moor_shrine", xf * Vector3(0, 0.65, 1.15), float(s.yaw))
	P._lore(host, "poi_moor_shrine", xf * Vector3(0.9, 1.3, 1.4), xf * Vector3(0, 2.4, 0.41))
	P._lore(host, "poi_moor_edict", xf * Vector3(-0.9, 1.3, 1.4), xf * Vector3(0, 3.3, 0.41))
	_grow(host, space, xf, rng, [["heather", 2.0, 8.0, 34], ["grass", 2.0, 8.0, 40]], Rect2(-1.7, -1.7, 3.4, 4.2))


# --- The Press-House (Cinder Orchard) ----------------------------------------------------------

const PRESS_LOFT := 4.4

static func _orchard_press(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34009
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var hx := 5.0
	var hz := 3.6
	var t := 0.55
	var hc := Vector3(0, 0, -3.0)            # the house on the back half, the yard before it
	k.box("floor", xf * (hc + Vector3(0, 0.02, 0)), Vector3(hx * 2.0 - 0.1, 0.22, hz * 2.0 - 0.1), b, true, 0.85)
	k.box("stone", xf * (hc + Vector3(0, -0.4, 0)), Vector3(hx * 2.0 + 0.3, 0.9, hz * 2.0 + 0.3), b, true, 0.72)
	# walls, scorched, the front with a wide cart door and the roof gone
	var segs := [[-3.1, 3.8, 4.4, -1], [2.6, 4.8, 3.6, -1], [-3.6, 2.8, 4.2, 1], [3.6, 2.8, 4.0, 1]]
	for sg: Array in segs:
		var cx: float = sg[0]
		var lnx: float = sg[1]
		var hh: float = sg[2]
		var sz: float = sg[3]
		k.box("stone", xf * (hc + Vector3(cx, hh * 0.5 - 0.2, sz * (hz - t * 0.5))), Vector3(lnx, hh + 0.4, t), b, true, rng.randf_range(0.7, 0.8))
	for sx: float in [-1.0, 1.0]:
		k.box("stone", xf * (hc + Vector3(sx * (hx - t * 0.5), 2.1, 0)), Vector3(t, 4.6, hz * 2.0), b, true, 0.76)
	for row in 5:
		k.box("stone", xf * (hc + Vector3(-(hx - t * 0.5), 4.6 + 0.4 * float(row), 0)), Vector3(t, 0.42, hz * 2.0 * (1.0 - float(row) / 5.5)), b, true, 0.8)
	# soot over the walls' tops (char), a fallen roof timber across the yard
	for sg: Array in segs:
		k.box("lore_char", xf * (hc + Vector3(float(sg[0]), float(sg[2]) + 0.05, float(sg[3]) * (hz - t * 0.5))), Vector3(float(sg[1]) - 0.2, 0.12, t + 0.04), b, false, 0.6)
	_cyl(k, "lore_char", _gl(space, xf, Vector3(-4.6, 0.2, 3.2)), _gl(space, xf, Vector3(2.4, 1.6, 0.3)), 0.2, 0.17, true)
	# the loft over the west third, on posts
	var lx0 := -hx + t
	var lx1 := -1.4
	k.box("wood", xf * (hc + Vector3((lx0 + lx1) * 0.5, PRESS_LOFT - 0.08, 0)), Vector3(lx1 - lx0, 0.16, hz * 2.0 - t * 2.0), b, true, 0.8)
	for zz: float in [-hz + t + 0.2, hz - t - 0.2]:
		k.box("wood", xf * (hc + Vector3(lx1 - 0.15, (PRESS_LOFT - 0.2) * 0.5, zz)), Vector3(0.22, PRESS_LOFT - 0.2, 0.22), b, true, 0.72)
	# the great screw press in the middle: two posts, a head beam, the screw and the stone bed
	var pr := hc + Vector3(1.2, 0, 0)
	for sz2: float in [-1.4, 1.4]:
		k.box("wood", xf * (pr + Vector3(0, 1.8, sz2)), Vector3(0.45, 3.6, 0.45), b, true, 0.75)
	k.box("wood", xf * (pr + Vector3(0, 3.7, 0)), Vector3(0.6, 0.5, 3.4), b, true, 0.78)
	_cyl(k, "wood", xf * (pr + Vector3(0, 1.3, 0)), xf * (pr + Vector3(0, 3.5, 0)), 0.2, 0.2, false, 8)
	for i in 8:
		k.box("wood", xf * (pr + Vector3(0, 1.4 + 0.25 * float(i), 0)), Vector3(0.48, 0.06, 0.48), b * Basis(Vector3.UP, 0.4 * float(i)), false, 0.65)
	k.box("wood", xf * (pr + Vector3(0, 1.25, 0)), Vector3(1.6, 0.18, 1.6), b, false, 0.7)
	k.box("stone", xf * (pr + Vector3(0, 0.45, 0)), Vector3(2.2, 0.9, 2.2), b, true, 0.82)
	k.box("dark", xf * (pr + Vector3(0, 0.91, 0)), Vector3(1.8, 0.03, 1.8), b, false, 0.35)
	# the store under the loft is boarded off; vats stand against the boards: the way up
	k.box("wood", xf * (hc + Vector3(lx1 - 0.08, PRESS_LOFT * 0.5, 0)), Vector3(0.16, PRESS_LOFT, hz * 2.0 - t * 2.0), b, true, 0.7)
	var vat := hc + Vector3(lx1 + 0.75, 0, 1.6)
	var keg := hc + Vector3(lx1 + 0.75, 0, 0.1)
	var steps := _steps(k, xf, [[vat.x, vat.z, 1.5, Vector2(1.3, 1.4)], [keg.x, keg.z, 3.0, Vector2(1.3, 1.4)]], "wood", 0.0)
	for st: Vector3 in steps:
		_cyl(k, "wood", st + Vector3.UP * 0.1, st + Vector3.UP * 0.12, 0.62, 0.62, false, 12)        # the vats' rims
	for i in 4:
		var bp := _gl(space, xf, Vector3(3.6 + 0.9 * float(i % 2), 0, -0.9 + 1.0 * float(i / 2) + hc.z + 3.0))
		_cyl(k, "wood", bp, bp + Vector3.UP * 1.0, 0.38, 0.38, true, 10)
	k.commit(host, "PressBody")
	var route: Array[Vector3] = [steps[0], steps[1], xf * (hc + Vector3(lx1 - 0.7, PRESS_LOFT, -0.6))]
	host.set_meta("route", route)
	host.set_meta("walk", [false, false, false])
	host.set_meta("approach", xf * (vat + Vector3(0.6, 0, 2.0)))
	_chest(host, "orchard_loft", xf * (hc + Vector3(lx0 + 1.0, PRESS_LOFT, -1.0)), float(s.yaw) + PI * 0.5)
	P._lore(host, "poi_orchard_press", xf * (pr + Vector3(1.4, 1.0, 1.6)), xf * (pr + Vector3(0, 3.7, 0.3)))
	P._lore(host, "poi_orchard_writ", xf * (hc + Vector3(lx0 + 1.6, PRESS_LOFT + 0.4, 1.2)))
	var peak := xf * (hc + Vector3(-(hx - t * 0.5), 4.6 + 0.4 * 4.0 + 0.22, 0))
	P._grapple(host, peak + Vector3.UP * 0.6, xf * (hc + Vector3(lx1 - 0.7, PRESS_LOFT, -0.6)), 16.0, false)
	_floor(host, "orchard_yard")
	_grow(host, space, xf, rng, [["grass", 1.0, 9.0, 60], ["litter", 1.0, 8.0, 24], ["bramble", 7.0, 10.0, 6]], Rect2(-hx - 0.3, hc.z - hz - 0.3, hx * 2.0 + 0.6, hz * 2.0 + 0.6))


# --- The Mother Tree (Cinder Orchard) ----------------------------------------------------------

static func _orchard_heart(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34010
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	# the trunk: a ring of charred staves round a hollow you can step into (open toward +z)
	var n := 11
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		if absf(angle_difference(a, 0.0)) < 0.45:
			continue
		var q := Vector3(sin(a) * 1.25, 0, cos(a) * 1.25)
		var hh := 4.6 + rng.randf_range(-0.8, 1.2)
		var bb := b * Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.06)
		k.box("lore_char", xf * (q + Vector3(0, hh * 0.5 - 0.4, 0)), Vector3(0.95, hh + 0.8, 0.55), bb, true, rng.randf_range(0.7, 0.9))
	k.box("lore_char", xf * Vector3(0, 4.9, 0), Vector3(2.6, 0.9, 2.6), b * Basis(Vector3.UP, 0.3), true, 0.7)
	# the great limbs, black and split, reaching over the ring
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.6
		var root := xf * Vector3(sin(a) * 0.8, 4.6 + 0.3 * float(i % 2), cos(a) * 0.8)
		var tip := xf * Vector3(sin(a) * 6.5, 6.4 + rng.randf_range(-0.6, 1.4), cos(a) * 6.5)
		_cyl(k, "lore_char", root, tip, 0.42, 0.12, false, 8)
		var fork := root.lerp(tip, 0.6)
		_cyl(k, "lore_char", fork, fork + (tip - root).normalized().rotated(Vector3.UP, 0.7) * 2.4 + Vector3.UP * 1.2, 0.14, 0.05, false, 6)
	# roots over the ground
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.25
		if absf(angle_difference(a, 0.0)) < 0.5:
			continue
		_cyl(k, "lore_char", _gl(space, xf, Vector3(sin(a) * 1.2, 0.3, cos(a) * 1.2)), _gl(space, xf, Vector3(sin(a) * 3.4, -0.1, cos(a) * 3.4)), 0.3, 0.1, false, 6)
	# inside the hollow: the Kindlers' cache, a cinder-stone, a ring of stubs of candle
	k.candle_cluster(xf * Vector3(0.4, 0.05, -0.5), 5, 0.25, rng)
	k.box("lore_rock", xf * Vector3(-0.5, 0.15, -0.5), Vector3(0.5, 0.3, 0.45), b, false, 0.8)
	# the ring of burned trees round the Mother: nine snags, a cut stump where the tenth was
	var ring_ids := TreeGen.ids("snag")
	var items := {}
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.17
		var q := _gl(space, xf, Vector3(sin(a) * 7.6, 0, cos(a) * 7.6))
		if ring_ids.is_empty():
			break
		var id: String = ring_ids[i % ring_ids.size()]
		if not items.has(id):
			items[id] = []
		var sc := rng.randf_range(0.85, 1.15)
		(items[id] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), q + Vector3.DOWN * 0.1))
		LK.col_box(k, q + Vector3.UP * 1.5, Vector3(0.5, 3.0, 0.5), Basis.IDENTITY)
	P._plants(host, items, 90.0)
	k.commit(host, "MotherBody")
	_chest(host, "orchard_hollow", xf * Vector3(0, 0.0, -0.2), float(s.yaw))
	P._lore(host, "poi_orchard_tree", xf * Vector3(1.6, 1.2, 1.8), xf * Vector3(0.9, 1.6, 1.0))
	P._lore(host, "poi_orchard_kindlers", xf * Vector3(-0.4, 0.9, 0.4), xf * Vector3(-0.5, 0.35, -0.5))
	P._light(host, xf * Vector3(0, 1.2, -0.2), Color(1.0, 0.55, 0.28), 0.7, 5.0)
	_floor(host, "orchard_ring")
	_grow(host, space, xf, rng, [["litter", 2.0, 9.0, 30], ["grass", 3.0, 9.0, 30], ["flowers", 2.5, 6.0, 8]])


# --- The First Pilgrims' Tomb (Waiting Field) --------------------------------------------------

const POD_H := 2.8                       ## the podium; the vault is inside it
const TOMB_H := 4.0                      ## the tomb house's walls on the podium

static func _necro_mausoleum(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34011
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var px := 5.2                        # podium half extents (x) and z range
	var pz0 := -6.0
	var pz1 := 2.6
	var t := 0.6
	# the podium: a hollow box of ashlar -- the burial vault is inside it
	k.box("lore_ashlar", xf * Vector3(0, -0.3, (pz0 + pz1) * 0.5), Vector3(px * 2.0 + 0.2, 0.7, pz1 - pz0 + 0.2), b, true, 0.75)
	for wl: Array in [[Vector3(-px + t * 0.5, POD_H * 0.5, (pz0 + pz1) * 0.5), Vector3(t, POD_H, pz1 - pz0)], [Vector3(px - t * 0.5, POD_H * 0.5, (pz0 + pz1) * 0.5), Vector3(t, POD_H, pz1 - pz0)],
			[Vector3(0, POD_H * 0.5, pz0 + t * 0.5), Vector3(px * 2.0, POD_H, t)], [Vector3(0, POD_H * 0.5, pz1 - t * 0.5), Vector3(px * 2.0, POD_H, t)]]:
		k.box("lore_ashlar", xf * (wl[0] as Vector3), wl[1], b, true, 0.82)
	k.box("lore_ashlar", xf * Vector3(0, POD_H + 0.06, (pz0 + pz1) * 0.5), Vector3(px * 2.0 + 0.3, 0.14, pz1 - pz0 + 0.3), b, false, 0.9)
	# the vault floor and its roof (the tomb house's floor), open over the stair down (east side)
	k.box("floor", xf * Vector3(0, 0.04, (pz0 + pz1) * 0.5), Vector3(px * 2.0 - t * 2.0, 0.12, pz1 - pz0 - t * 2.0), b, true, 0.8)
	var sx0 := 1.9                       # the stair well: x 1.9 .. 3.5 (inside the tomb house), z -4.6 .. 0
	var sx1 := 3.5
	var wz0 := -4.6
	var wz1 := 0.0
	var slab_y := POD_H - 0.15
	var iz0 := pz0 + t
	var iz1 := pz1 - t
	k.box("lore_ashlar", xf * Vector3((-px + t + sx0) * 0.5, slab_y, (iz0 + iz1) * 0.5), Vector3(sx0 + px - t, 0.3, iz1 - iz0), b, true, 0.86)
	k.box("lore_ashlar", xf * Vector3((sx1 + px - t) * 0.5, slab_y, (iz0 + iz1) * 0.5), Vector3(px - t - sx1, 0.3, iz1 - iz0), b, true, 0.86)
	k.box("lore_ashlar", xf * Vector3((sx0 + sx1) * 0.5, slab_y, (iz0 + wz0) * 0.5), Vector3(sx1 - sx0, 0.3, wz0 - iz0), b, true, 0.86)
	k.box("lore_ashlar", xf * Vector3((sx0 + sx1) * 0.5, slab_y, (wz1 + iz1) * 0.5), Vector3(sx1 - sx0, 0.3, iz1 - wz1), b, true, 0.86)
	# the stair down inside, from the tomb house floor (by the door) back and down into the vault
	k.stairs("lore_ashlar", xf * Vector3((sx0 + sx1) * 0.5, 0.1, wz0 + 0.3), xf * Vector3((sx0 + sx1) * 0.5, POD_H, wz1), sx1 - sx0 - 0.04, 9, o.y)
	# in the vault: three stone coffins of the first pilgrims, feet to the mountain, candles
	for i in 3:
		var cz := -4.4 + 1.9 * float(i)
		k.box("lore_tstone", xf * Vector3(-1.4, 0.45, cz), Vector3(2.4, 0.8, 1.0), b, true, 0.86)
		k.box("lore_tstone", xf * Vector3(-1.4, 0.92, cz), Vector3(2.5, 0.14, 1.1), b * Basis(Vector3.UP, 0.03 * float(i - 1)), true, 0.92)
		k.candle_cluster(xf * Vector3(0.2, 0.1, cz), 3, 0.15, rng)
	# the tomb house on the podium: walls, a door to the north (+z) under a pediment, a roof slab
	var tx := 4.2
	var tz0 := -5.6
	var tz1 := 0.6
	var ty := POD_H
	for wl: Array in [[Vector3(-tx + t * 0.5, ty + TOMB_H * 0.5, (tz0 + tz1) * 0.5), Vector3(t, TOMB_H, tz1 - tz0)], [Vector3(tx - t * 0.5, ty + TOMB_H * 0.5, (tz0 + tz1) * 0.5), Vector3(t, TOMB_H, tz1 - tz0)],
			[Vector3(0, ty + TOMB_H * 0.5, tz0 + t * 0.5), Vector3(tx * 2.0, TOMB_H, t)],
			[Vector3(-2.5, ty + TOMB_H * 0.5, tz1 - t * 0.5), Vector3(3.4, TOMB_H, t)], [Vector3(2.5, ty + TOMB_H * 0.5, tz1 - t * 0.5), Vector3(3.4, TOMB_H, t)],
			[Vector3(0, ty + TOMB_H - 0.6, tz1 - t * 0.5), Vector3(1.6, 1.2, t)]]:
		k.box("lore_ashlar", xf * (wl[0] as Vector3), wl[1], b, true, rng.randf_range(0.86, 0.94))
	var roof_y := ty + TOMB_H
	k.box("lore_slates", xf * Vector3(0, roof_y + 0.18, (tz0 + tz1) * 0.5 + 0.55), Vector3(tx * 2.0, 0.36, tz1 - tz0 + 1.7), b, true, 0.85)
	for row in 3:
		k.box("lore_ashlar", xf * Vector3(0, roof_y + 0.36 + 0.22 + 0.36 * float(row), tz0 + 0.4), Vector3((tx * 2.0) * (1.0 - float(row) / 3.4), 0.36, 0.5), b, true, 0.88)
	# a porch: two columns before the door holding the roof's front edge
	for sx: float in [-1.0, 1.0]:
		_cyl(k, "lore_ashlar", xf * Vector3(sx * 2.4, ty, tz1 + 1.1), xf * Vector3(sx * 2.4, roof_y, tz1 + 1.1), 0.32, 0.28, true, 12)
	# the front steps from the forecourt up to the podium
	k.stairs("lore_ashlar", xf * Vector3(0, 0.0, pz1 + 3.6), xf * Vector3(0, POD_H, pz1 - 0.2), 2.6, 9)
	# the climb, on the west side: a run of fallen ashlar blocks stepping up against the podium, the
	# last against the tomb house's wall, and the roof
	var climb := _steps(k, xf, [[-px - 1.2, 0.6, 1.6, Vector2(2.2, 1.5)], [-px - 1.2, -0.9, 3.2, Vector2(2.2, 1.5)], [-px - 1.2, -2.4, 4.8, Vector2(2.2, 1.5)],
			[-px + 0.5, -2.4, 6.0, Vector2(1.0, 1.5), POD_H]], "lore_ashlar", 0.0)
	k.commit(host, "TombBody")
	climb.append(xf * Vector3(-tx + 1.0, roof_y + 0.36, -2.4))
	host.set_meta("route", climb)
	host.set_meta("walk", [false, false, false, false, false])
	host.set_meta("approach", xf * Vector3(-px - 1.2, 0, 2.4))
	host.set_meta("vault", xf * Vector3(0.0, 0.1, -1.0))
	_chest(host, "necro_vault", xf * Vector3(-3.6, 0.1, -1.0), float(s.yaw) + PI * 0.5)
	P._lore(host, "poi_necro_door", xf * Vector3(1.6, POD_H + 1.2, tz1 + 1.6), xf * Vector3(0, POD_H + TOMB_H - 0.6, tz1 + 0.02))
	P._lore(host, "poi_necro_vault", xf * Vector3(0.4, 1.0, -2.5), xf * Vector3(-1.4, 1.0, -2.5))
	P._lore(host, "poi_necro_roof", xf * Vector3(-tx + 1.8, roof_y + 0.9, -3.6))
	P._light(host, xf * Vector3(0.0, 1.6, -2.0), Color(0.62, 0.72, 1.0), 0.8, 6.0)
	P._perch(host, xf * Vector3(0, roof_y + 0.36, tz1 + 1.2), b.z, roof_y + 0.36)
	_floor(host, "necro_forecourt")
	_grow(host, space, xf, rng, [["grass", px + 1.5, 11.0, 70], ["flowers", px + 2.0, 10.0, 16], ["moss", px + 0.4, px + 2.0, 20]], Rect2(-px - 2.4, pz0 - 0.6, px * 2.0 + 3.0, pz1 - pz0 + 4.6))


# --- The Pilgrims' Ranks (Waiting Field) -------------------------------------------------------

static func _necro_ranks(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34012
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	# three ranks of tall stelae, every one turned to the mountain (the place faces north: local +z)
	for row in 3:
		for i in 7:
			if row == 1 and i == 3:
				continue                                 # a gap in the middle rank: the warden's walk
			var q := Vector3(-6.0 + 2.0 * float(i) + rng.randf_range(-0.15, 0.15), 0, -1.0 - 2.6 * float(row))
			var g := _gl(space, xf, q)
			var hh := rng.randf_range(1.5, 2.1)
			var bb := b * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.04))
			k.box("lore_tstone", g + bb * Vector3(0, hh * 0.5 - 0.2, 0), Vector3(0.62, hh, 0.2), bb, true, rng.randf_range(0.82, 0.96))
			LK.half_disc(k, "lore_tstone", Transform3D(bb, g + bb * Vector3(0, hh - 0.2, 0)), 0.31, 0.0, 0.2, 4, false, 0.9)
			k.box("lore_earth", g + Vector3.UP * 0.06, Vector3(0.9, 0.16, 1.8), b, false, 0.7)
	# the bell-post at the ranks' head: rung for every new burial
	var bp := _gl(space, xf, Vector3(7.8, 0, 1.2))
	for sx: float in [-0.7, 0.7]:
		k.box("wood", bp + b * Vector3(sx, 1.4, 0), Vector3(0.18, 2.8, 0.18), b, true, 0.72)
	k.box("wood", bp + b * Vector3(0, 2.75, 0), Vector3(1.8, 0.2, 0.22), b, false, 0.75)
	k.append_mesh("iron", P._bell_mesh(), Transform3D(b.scaled(Vector3(0.45, 0.45, 0.45)), bp + Vector3.UP * 2.05))
	# the field-warden's lodge: a stone cell, its door open
	var lc := _gl(space, xf, Vector3(-8.2, 0, 2.0))
	var lb := b * Basis(Vector3.UP, PI * 0.5)
	for wl: Array in [[Vector3(0, 1.2, -1.4), Vector3(3.2, 2.4, 0.4)], [Vector3(-1.4, 1.2, 0), Vector3(0.4, 2.4, 3.2)], [Vector3(1.4, 1.2, 0), Vector3(0.4, 2.4, 3.2)],
			[Vector3(-1.05, 1.2, 1.4), Vector3(1.1, 2.4, 0.4)], [Vector3(1.05, 1.2, 1.4), Vector3(1.1, 2.4, 0.4)], [Vector3(0, 2.25, 1.4), Vector3(1.0, 0.3, 0.4)]]:
		k.box("lore_tstone", lc + lb * (wl[0] as Vector3), wl[1], lb, true, rng.randf_range(0.8, 0.9))
	k.box("lore_slates", lc + lb * Vector3(0, 2.55, 0), Vector3(3.6, 0.3, 3.6), lb * Basis(Vector3.RIGHT, 0.08), true, 0.85)
	k.box("wood", lc + lb * Vector3(-0.6, 0.35, -0.6), Vector3(1.6, 0.7, 0.8), lb, true, 0.7)
	k.commit(host, "RanksBody")
	_chest(host, "necro_lodge", lc + lb * Vector3(0.6, 0.0, -0.6), float(s.yaw) + PI * 0.5)
	P._lore(host, "poi_necro_ranks", _gl(space, xf, Vector3(0, 1.2, 0.4)), _gl(space, xf, Vector3(0, 1.2, -1.1)))
	P._lore(host, "poi_necro_warden", lc + lb * Vector3(0.9, 1.1, 2.2), lc + lb * Vector3(-0.6, 0.9, -0.6))
	_grow(host, space, xf, rng, [["grass", 0.0, 9.0, 90], ["flowers", 0.0, 9.0, 20], ["tallgrass", 6.0, 10.0, 16]], Rect2(-7.0, -7.6, 14.0, 7.2))


# --- The Half-Sunk Chapel (Corvin's Mere) ------------------------------------------------------

const CH_LOFT := 7.8

static func _mere_chapel(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34013
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var base := minf(o.y, WATER - 0.35)          # the nave floor lies under the mere
	var nx := 2.8
	var nz0 := -5.2                               # the tower at the back (-z), the door at the front (+z)
	var nz1 := 3.4
	var t := 0.95                                # thick enough to walk along the top
	var wy := base + 4.6                         # the nave walls stand 3.6 m out of the water
	var loft_y := wy + 4.8                       # the bell loft
	k.box("stone", Vector3(o.x, base - 0.3, o.z) + b * Vector3(0, 0, (nz0 + nz1) * 0.5), Vector3(nx * 2.0 + 0.4, 0.6, nz1 - nz0 + 0.4), b, true, 0.7)
	var walls := [[Vector3(-nx + t * 0.5, 0, (nz0 + nz1) * 0.5), Vector3(t, 0, nz1 - nz0), 1.0], [Vector3(nx - t * 0.5, 0, (nz0 + nz1) * 0.5 + 1.4), Vector3(t, 0, nz1 - nz0 - 2.8), 0.7],
			[Vector3(-1.75, 0, nz1 - t * 0.5), Vector3(1.6, 0, t), 1.0], [Vector3(1.75, 0, nz1 - t * 0.5), Vector3(1.6, 0, t), 0.85]]
	for wl: Array in walls:
		var c: Vector3 = wl[0]
		var sz: Vector3 = wl[1]
		var hh := (wy - base) * float(wl[2])
		k.box("stone", Vector3(o.x, base + hh * 0.5, o.z) + b * Vector3(c.x, 0, c.z), Vector3(sz.x, hh, sz.z), b, true, rng.randf_range(0.72, 0.84))
	for z: float in [-2.6, 0.2]:
		k.box("dark", Vector3(o.x, base + 2.8, o.z) + b * Vector3(-nx - 0.01, 0, z), Vector3(0.05, 1.2, 0.35), b, false, 0.3)
	# the tower stub at the back: solid to the bell loft, its corner piers broken, a bell still hung
	var tw := 3.6
	var tc := Vector3(0, 0, nz0 - tw * 0.5 + 0.3)
	k.box("stone", Vector3(o.x, (base - 0.3 + loft_y) * 0.5, o.z) + b * tc, Vector3(tw, loft_y - base + 0.3, tw), b, true, 0.82)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph := 2.4 if not (sx > 0.0 and sz < 0.0) else 1.0
			k.box("stone", Vector3(o.x, loft_y + ph * 0.5, o.z) + b * (tc + Vector3(sx * (tw - 0.8) * 0.5, 0, sz * (tw - 0.8) * 0.5)), Vector3(0.8, ph, 0.8), b, true, 0.88)
	k.box("wood", Vector3(o.x, loft_y + 2.0, o.z) + b * tc, Vector3(tw - 0.4, 0.26, 0.3), b, false, 0.8)
	k.append_mesh("iron", P._bell_mesh(), Transform3D(b * Basis(Vector3.FORWARD, 0.12) * Basis().scaled(Vector3(0.7, 0.7, 0.7)), Vector3(o.x, loft_y + 1.0, o.z) + b * tc))
	# the climb: two heaps of fallen tracery against the west wall, the wall top (walk it back to the
	# tower), two corbels on the tower's west face, the loft
	var route: Array[Vector3] = []
	route.append_array(_steps(k, xf, [[-nx - 1.0, -1.4, base + 1.6 - o.y, Vector2(1.3, 1.3)], [-nx - 0.85, -2.9, base + 3.2 - o.y, Vector2(1.2, 1.3)]], "stone", 0.05, rng))
	route.append(Vector3(o.x, wy, o.z) + b * Vector3(-nx + t * 0.5, 0, -3.0))
	route.append(Vector3(o.x, wy, o.z) + b * Vector3(-nx + t * 0.5, 0, nz0 + 0.45))
	var cx := -tw * 0.5 - 0.55
	for st: Array in [[nz0 - 0.75, 1.6], [nz0 - 2.1, 3.2]]:
		var cc := Vector3(cx, 0, float(st[0]))
		var top := wy + float(st[1])
		k.box("stone", Vector3(o.x, top - 0.3, o.z) + b * cc, Vector3(1.1, 0.6, 1.1), b, true, 0.86)
		k.box("stone", Vector3(o.x, top - 1.1, o.z) + b * (cc + Vector3(0.3, 0, 0)), Vector3(0.5, 1.0, 0.5), b, false, 0.8)
		route.append(Vector3(o.x, top, o.z) + b * cc)
	var loft := Vector3(o.x, loft_y, o.z) + b * (tc + Vector3(-0.4, 0, 0.0))
	route.append(loft)
	k.commit(host, "ChapelBody")
	_causeway(host, space, rng, causeways.get("mere_chapel", []))
	host.set_meta("route", route)
	host.set_meta("walk", [false, false, false, true, false, false, false])
	host.set_meta("approach", xf * Vector3(-nx - 1.2, 0, 1.2))
	_chest(host, "mere_loft", Vector3(o.x, loft_y, o.z) + b * (tc + Vector3(0.6, 0, -0.9)), float(s.yaw))
	P._lore(host, "poi_mere_chapel", Vector3(o.x, wy - 2.2, o.z) + b * Vector3(1.8, 0, nz1 + 0.6), Vector3(o.x, wy - 1.0, o.z) + b * Vector3(1.75, 0, nz1 + 0.02))
	P._lore(host, "poi_mere_bell", Vector3(o.x, loft_y + 0.6, o.z) + b * (tc + Vector3(-0.6, 0, 0.6)))
	P._grapple(host, Vector3(o.x, loft_y + 2.3, o.z) + b * tc, loft)
	_perch_auto(host, space, Vector3(o.x, loft_y, o.z) + b * (tc + Vector3(0, 0, -tw * 0.5 + 0.6)), -b.z)
	P._light(host, loft + Vector3.UP * 1.3, Color(0.7, 0.82, 1.0), 0.9, 7.0)
	_lamps(host, xf, rng, 7, 6.0, 14.0)
	# the fighting floor: the nearest dry hummock (the bank the causeway leaves from)
	_floor(host, "mere_hummock")
	_grow(host, space, xf, rng, [["reeds", 4.0, 11.0, 50], ["cattail", 4.0, 10.0, 18], ["moss", 1.0, 5.0, 10]], Rect2(-nx - 1.8, nz0 - tw, nx * 2.0 + 3.6, nz1 - nz0 + tw + 1.0))


## Corvin's lamps: little lights left floating on the mere, bobbing (one OmniLight for all of them).
static func _lamps(host: Node3D, xf: Transform3D, rng: RandomNumberGenerator, n: int, r0: float, r1: float) -> void:
	var lamps := Node3D.new()
	lamps.name = "FloatingLamps"
	host.add_child(lamps)
	var k := OssKit.new()
	k.keep_lanes = false
	var pts: Array[Vector3] = []
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(r0, r1)
		var q := xf * Vector3(cos(a) * r, 0, sin(a) * r)
		var g := RealmLayout.macro_height(q.x, q.z)
		if g > WATER - 0.1:
			continue
		q.y = WATER + 0.06
		pts.append(q)
		k.box("wood", q, Vector3(0.36, 0.08, 0.36), Basis(Vector3.UP, rng.randf() * TAU), false, 0.7)
		k.box("glow", q + Vector3.UP * 0.16, Vector3(0.12, 0.18, 0.12), Basis.IDENTITY, false, 0.55)
	k.commit(lamps, "LampsBody")
	for c in lamps.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = 140.0
	var tw := lamps.create_tween().set_loops()
	tw.tween_property(lamps, "position:y", 0.05, 2.3).from(-0.03).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lamps, "position:y", -0.03, 2.3).set_trans(Tween.TRANS_SINE)
	if not pts.is_empty():
		var mid := Vector3.ZERO
		for p in pts:
			mid += p
		P._light(host, mid / float(pts.size()) + Vector3.UP * 0.8, Color(1.0, 0.7, 0.4), 0.7, 9.0)


## Planks on posts over the water from the bank to a place's front (r31's belfry causeway).
static func _causeway(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, pts: Array) -> void:
	if pts.size() < 2:
		return
	var k := OssKit.new()
	k.keep_lanes = false
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(c) / 1.0))
		var dir := (c - a).normalized()
		var yaw := atan2(dir.x, dir.y)
		for j in n:
			var tt := (float(j) + 0.5) / float(n)
			var p := a.lerp(c, tt)
			var g := RealmLayout.ground(space, p.x, p.y)
			var deck := maxf(g, WATER) + 0.32
			var bb := Basis(Vector3.UP, yaw + rng.randf_range(-0.03, 0.03))
			k.box("wood", Vector3(p.x, deck - 0.05, p.y), Vector3(1.5, 0.1, a.distance_to(c) / float(n) - 0.06), bb, true, rng.randf_range(0.75, 0.95))
			if j % 2 == 0:
				for side: float in [-0.62, 0.62]:
					var q := p + Vector2(dir.y, -dir.x) * side
					var gq := RealmLayout.ground(space, q.x, q.y)
					k.box("wood", Vector3(q.x, (deck - 0.1 + gq - 0.6) * 0.5, q.y), Vector3(0.16, deck - 0.1 - gq + 0.6, 0.16), bb, false, 0.7)
	var cw := Node3D.new()
	cw.name = "Causeway"
	host.add_child(cw)
	k.commit(cw, "CausewayBody")


# --- Corvin's Landing (Corvin's Mere) ----------------------------------------------------------

const BH_LOFT := 2.7

static func _mere_landing(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 34014
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var gy := RealmLayout.ground(space, o.x, o.z)
	var y0 := maxf(gy, WATER) + 0.2
	# the boat-house: a stone footing, timber posts, a slate roof, open to the water (+z)
	var hx := 2.8
	var hz0 := -3.4
	var hz1 := 3.2
	k.box("stone", Vector3(o.x, y0 - 0.5, o.z) + b * Vector3(0, 0, (hz0 + hz1) * 0.5), Vector3(hx * 2.0 + 0.3, 1.0, hz1 - hz0 + 0.3), b, true, 0.75)
	k.box("wood", Vector3(o.x, y0 + 0.05, o.z) + b * Vector3(0, 0, (hz0 + hz1) * 0.5), Vector3(hx * 2.0 - 0.2, 0.1, hz1 - hz0 - 0.2), b, true, 0.8)
	for sx: float in [-1.0, 1.0]:
		for zz: float in [hz0 + 0.2, (hz0 + hz1) * 0.5, hz1 - 0.2]:
			k.box("wood", Vector3(o.x, y0 + 2.0, o.z) + b * Vector3(sx * (hx - 0.2), 0, zz), Vector3(0.24, 4.0, 0.24), b, true, 0.72)
		k.box("wood", Vector3(o.x, y0 + 1.0, o.z) + b * Vector3(sx * (hx - 0.12), 0, (hz0 + hz1) * 0.5), Vector3(0.08, 2.0, hz1 - hz0 - 0.4), b, true, 0.65)   # plank side walls
	k.box("wood", Vector3(o.x, y0 + 1.6, o.z) + b * Vector3(0, 0, hz0 + 0.12), Vector3(hx * 2.0 - 0.2, 3.2, 0.1), b, true, 0.65)
	for sx: float in [-1.0, 1.0]:
		k.box("lore_slates", Vector3(o.x, y0 + 4.5, o.z) + b * Vector3(sx * hx * 0.5, 0, (hz0 + hz1) * 0.5), Vector3(hx + 0.6, 0.18, hz1 - hz0 + 0.8), b * Basis(Vector3.BACK, sx * -0.5), true, 0.85)
	# the loft over the back half, a ladder of cleats up the back wall
	k.box("wood", Vector3(o.x, y0 + BH_LOFT, o.z) + b * Vector3(0, 0, (hz0 + 0.0) * 0.5), Vector3(hx * 2.0 - 0.5, 0.14, -hz0 - 0.2), b, true, 0.8)
	k.stairs("wood", Vector3(o.x, y0 + 0.05, o.z) + b * Vector3(0.6, 0, 3.4), Vector3(o.x, y0 + BH_LOFT + 0.07, o.z) + b * Vector3(0.6, 0, 0.05), 0.95, 10)
	var stand: Array[Vector3] = [Vector3(o.x, y0 + BH_LOFT + 0.07, o.z) + b * Vector3(0.6, 0, -0.4)]
	# the lamp racks: iron frames of hooks, a crate of lamp-glass
	for i in 2:
		var rp := Vector3(o.x, y0, o.z) + b * Vector3(-hx - 1.4, 0, -1.6 + 3.0 * float(i))
		for sz: float in [-0.8, 0.8]:
			k.box("iron", rp + b * Vector3(0, 1.0, sz), Vector3(0.08, 2.0, 0.08), b, true, 0.8)
		k.box("iron", rp + b * Vector3(0, 1.9, 0), Vector3(0.08, 0.08, 1.7), b, false, 0.8)
		for j in 4:
			k.box("iron", rp + b * Vector3(0, 1.6, -0.6 + 0.4 * float(j)), Vector3(0.14, 0.24, 0.14), b, false, 0.7)
	# two upturned boats on the bank, a third rotted at the jetty's foot
	for i in 2:
		var bp := _gl(space, xf, Vector3(hx + 2.4, 0, -1.8 + 3.4 * float(i)))
		var bb := b * Basis(Vector3.UP, 0.2 * float(i) - 0.1)
		k.box("wood", bp + bb * Vector3(0, 0.45, 0), Vector3(1.3, 0.12, 3.6), bb, true, 0.7)
		for sx: float in [-1.0, 1.0]:
			k.box("wood", bp + bb * Vector3(sx * 0.6, 0.22, 0), Vector3(0.1, 0.5, 3.4), bb * Basis(Vector3.FORWARD, sx * 0.3), false, 0.65)
	k.commit(host, "LandingBody")
	_jetty(host, space, rng, causeways.get("mere_landing", []))
	var loft := Vector3(o.x, y0 + BH_LOFT + 0.07, o.z) + b * Vector3(0.6, 0, -2.0)
	stand.append(loft)
	host.set_meta("route", stand)
	host.set_meta("walk", [true, true])
	host.set_meta("approach", Vector3(o.x, y0, o.z) + b * Vector3(0.6, 0, 4.6))
	host.set_meta("lever_at", Vector3(o.x, y0, o.z) + b * Vector3(-hx + 0.6, 0, -1.6))
	_chest(host, "mere_landing", Vector3(o.x, y0 + BH_LOFT + 0.07, o.z) + b * Vector3(-1.4, 0, -2.4), float(s.yaw))
	P._lore(host, "poi_mere_landing", Vector3(o.x, y0 + 1.2, o.z) + b * Vector3(-hx - 2.2, 0, 0.0), Vector3(o.x, y0 + 1.6, o.z) + b * Vector3(-hx - 1.4, 0, -0.1))
	P._lore(host, "poi_mere_log", Vector3(o.x, y0 + BH_LOFT + 0.5, o.z) + b * Vector3(1.2, 0, -1.0))
	_lamps(host, Transform3D(b, Vector3(o.x, o.y, o.z) + b * Vector3(0, 0, 12.0)), rng, 6, 2.0, 9.0)
	_floor(host, "mere_bank")
	_grow(host, space, xf, rng, [["reeds", 3.5, 10.0, 40], ["grass", 4.0, 10.0, 40], ["cattail", 5.0, 10.0, 10]], Rect2(-hx - 2.4, hz0 - 0.5, hx * 2.0 + 6.0, 14.0))


static func _jetty(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, pts: Array) -> void:
	if pts.size() < 2:
		return
	_causeway(host, space, rng, pts)

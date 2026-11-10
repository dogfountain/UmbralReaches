extends Node
## r34 places (core/world/realm/realm_pois_doubled_realm.gd, docs/r34/places.md), in memory only (saves held,
## the satchel and system state restored):
##   - the fourteen new places built, named, with a chest, lore stones and a region; each first visit
##     raises its subzone banner, and the named open spots (EXTRA) are subzones too
##   - every chest opens once and remembers it; the fighting floors are level, open, clear of camps
##     and of the fires; perches drop, the furnace and the pits breathe updrafts, beacons stand
##   - the seven new fires are Ember Road stops (map markers, ember-posts), 13 m+ from every camp
##   - every new lore entry is placed; each new region holds 6+ readable stones
##   - world events can rise at the new places and grounds
##   - the three new secrets: the nook (only the Tether or a glide reaches its top), the Ninth Rank's
##     lamps (wrong order stays shut, right order opens the tomb), Corvin's Sluice (the lever raises
##     the walk); each cache pays once
##   - gather nodes laid in the new ground
##   - every climb route is grabbable step by step, and the real wanderer climbs each to its top
## Run: HOME=<scratch> godot --headless --path . res://zz/places_r34_test.tscn [-- --no-climb] [-- --only=quarry_crane]
const Pois := preload("res://core/world/realm/realm_pois.gd")
const R34 := preload("res://core/world/realm/realm_pois_doubled_realm.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const State := preload("res://core/life/secrets/state.gd")
const SiteR34 := preload("res://core/life/secrets/site_doubled_realm.gd")
const NEW_REGIONS := ["quarry", "holds", "foundry", "moor", "orchard", "necropolis", "mere"]

var p: Player
var main: Node
var t := 0
var step := 0
var wait := 0
var fails := 0
var climbs: Array = []
var ci := -1
var route: Array = []
var ri := 0
var rt := 0.0
var rj := -1.0
var banners: Array[String] = []
var items_before := {}
var systems_before := {}


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	CodexStore.persist = false
	CodexStore.use_path("user://codex_places_test.cfg", false)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	Events.region_discovered.connect(func(id: String, kind: String) -> void:
		if kind == "subzone":
			banners.append(id))


func check(name: String, ok: bool) -> void:
	print("PLACES ", "PASS " if ok else "FAIL ", name)
	if not ok:
		fails += 1


func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _hosts() -> Array:
	return get_tree().get_nodes_in_group(Pois.GROUP_POI).filter(func(h: Node) -> bool: return h.has_meta("r34"))


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 600:
		print("PLACES FAIL timeout at step ", step)
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if wait > 0:
		wait -= 1
		return
	match step:
		0:
			if not main.has_meta("realm_done") or main.get_node_or_null("RealmPois") == null:
				return
			p.set_physics_process(true)
			p.set("gloom", 0.0); p.set("wounds", 0.0)
			items_before = Travel.items.duplicate(true)
			systems_before = Travel.systems.duplicate(true)
			State.quiet = true
			_static_checks()
			_fires()
			_lore()
			_events()
			_gather()
			step = 1
		1:
			_chests()
			_secrets()
			step = 2
		2:
			var disc := main.get_node_or_null("Discovery")
			if disc and float(disc.get("_clock")) < 7.0:
				return
			step = 3
			disc.set("_spots_t", 0.0)
			disc.call("_collect_spots")
			var ids: Array = disc.call("spot_ids")
			var want := 0
			for h in _hosts():
				want += 1
				_tp((h.get_meta("centre") as Vector3) + Vector3(0, 30.0, 0))
				await get_tree().create_timer(0.7).timeout
			for id: String in R34.EXTRA:
				check("named spot %s is a subzone" % id, id in ids)
				var q: Vector2 = R34.EXTRA[id][0]
				_tp(Vector3(q.x, 40.0, q.y))
				await get_tree().create_timer(0.7).timeout
				want += 1
			var mine := banners.filter(func(b: String) -> bool: return b.begins_with("sub_poi_") or String(b.trim_prefix("sub_")) in R34.EXTRA)
			check("each new place named on the first visit (%d of %d)" % [mine.size(), want], mine.size() >= want)
			if "--no-climb" in OS.get_cmdline_user_args():
				step = 99
				return
			var only := ""
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--only="):
					only = a.trim_prefix("--only=")
			for h in _hosts():
				if h.has_meta("route") and (only == "" or String(h.get_meta("poi")) in only.split(",")):
					climbs.append([String(h.get_meta("poi")), h.get_meta("route"), h.get_meta("approach")])
			step = 10
		10:
			ci += 1
			if ci >= climbs.size():
				step = 99
				return
			route = climbs[ci][1]
			var ap: Vector3 = climbs[ci][2]
			ap.y = RealmLayout.ground(p.get_world_3d().direct_space_state, ap.x, ap.z) + 0.2
			_tp(ap)
			ri = 0
			rt = 0.0
			rj = -1.0
			step = 11
			wait = 10
		11:
			_climb_tick(1.0 / 60.0)
		99:
			p.debug_drive(Vector3.ZERO)
			Input.action_release("jump")
			_restore()
			print("PLACES DONE %d FAIL" % fails if fails > 0 else "PLACES DONE all passed")
			get_tree().quit(1 if fails > 0 else 0)
			step = 100


func _static_checks() -> void:
	var space := p.get_world_3d().direct_space_state
	var hosts := _hosts()
	var ids: Array[String] = []
	for h in hosts:
		ids.append(String(h.get_meta("poi")))
	ids.sort()
	check("fourteen new places built %s" % [ids], ids.size() == R34.POIS.size())
	var per_region := {}
	for h in hosts:
		var id := String(h.get_meta("poi"))
		var reg := String(h.get_meta("region", ""))
		per_region[reg] = int(per_region.get(reg, 0)) + 1
		var c: Vector3 = h.get_meta("centre")
		var at_r := String(RealmLayout.region_at(c.x, c.z).get("id", ""))
		print("PLACES %s (%s) at %s, region %s (region_at %s)" % [id, h.get_meta("title"), c.snapped(Vector3.ONE * 0.1), reg, at_r])
		check("%s is in the world" % id, RealmLayout.BOUNDS.grow(-4.0).has_point(Vector2(c.x, c.z)))
		check("%s has its stones" % id, h.find_children("Lore_poi_*", "", true, false).size() >= 2)
		check("%s has a chest" % id, h.find_children("Chest_*", "", true, false).size() == 1)
	for reg: String in NEW_REGIONS:
		check("region %s has 2+ places (%d)" % [reg, int(per_region.get(reg, 0))], int(per_region.get(reg, 0)) >= 2)
	# the fighting floors
	var floors := Pois.miniboss_sites(get_tree()).filter(func(s: Dictionary) -> bool: return String(s.id) in ["quarry_pit", "holds_green", "foundry_floor", "moor_foot", "orchard_yard", "orchard_ring", "necro_forecourt", "mere_hummock", "mere_bank"])
	check("r34 guardian floors (%d)" % floors.size(), floors.size() >= 8)
	for s: Dictionary in floors:
		var c: Vector3 = s.at
		var r: float = s.radius
		var blocked := 0
		for i in 16:
			var a := TAU * float(i) / 16.0
			for f: float in [0.4, 0.8]:
				var q := c + Vector3(cos(a), 0, sin(a)) * r * f
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 4.0, q + Vector3.DOWN * 4.0, Layers.WORLD))
				if hit.is_empty() or absf((hit.position as Vector3).y - c.y) > 1.2 or (hit.normal as Vector3).y < 0.75:
					blocked += 1
		var near_camp := INF
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a3: Vector3 = cmp.at
			near_camp = minf(near_camp, Vector2(a3.x - c.x, a3.z - c.z).length())
		var near_fire := INF
		for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
			near_fire = minf(near_fire, Vector2((b as Node3D).global_position.x - c.x, (b as Node3D).global_position.z - c.z).length())
		print("PLACES floor %s at %s r %.1f: blocked %d/32, camp %.1f m, fire %.1f m" % [s.id, c.snapped(Vector3.ONE * 0.1), r, blocked, near_camp, near_fire])
		check("floor %s level and open" % s.id, blocked <= 4)
		check("floor %s clear of camps" % s.id, near_camp > r + 4.0)
		check("floor %s clear of the fires" % s.id, near_fire > r + 8.0)
	var perches := Pois.anchors(get_tree(), Pois.GROUP_GLIDE).filter(func(d: Dictionary) -> bool: return (d.node as Node).get_parent().has_meta("r34"))
	check("r34 glide perches (%d)" % perches.size(), perches.size() >= 5)
	for pc: Dictionary in perches:
		var at: Vector3 = pc.at
		var g := maxf(RealmLayout.ground(space, at.x + (pc.facing as Vector3).x * 6.0, at.z + (pc.facing as Vector3).z * 6.0), -0.9)
		check("perch at %s has a real drop (%.1f)" % [at.snapped(Vector3.ONE * 0.1), at.y - g], at.y - g > 5.0)
	var drafts := Pois.anchors(get_tree(), Pois.GROUP_UPDRAFT).filter(func(d: Dictionary) -> bool: return (d.node as Node).get_parent().has_meta("r34"))
	check("updrafts at the furnace and the pits (%d)" % drafts.size(), drafts.size() >= 3)
	var grapples := Pois.anchors(get_tree(), Pois.GROUP_GRAPPLE).filter(func(d: Dictionary) -> bool: return (d.node as Node).get_parent().has_meta("r34"))
	check("r34 grapple anchors (%d)" % grapples.size(), grapples.size() >= 6)
	var beacons := get_tree().get_nodes_in_group(&"landmark_beacon").filter(func(b: Node) -> bool: return b.has_meta("poi"))
	check("landmark beacons over the big places (%d)" % beacons.size(), beacons.size() >= 3)
	# every climb route: each rise inside the grab reach, each stand point solid
	for h in hosts:
		if not h.has_meta("route"):
			continue
		var rte: Array = h.get_meta("route")
		var walk: Array = h.get_meta("walk", [])
		var ap: Vector3 = h.get_meta("approach")
		var prev := RealmLayout.ground(space, ap.x, ap.z)
		var ok := true
		for i in rte.size():
			var pt: Vector3 = rte[i]
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 1.5, pt + Vector3.DOWN * 1.0, Layers.WORLD | Layers.PROPS))
			var y: float = (hit.position as Vector3).y if not hit.is_empty() else -INF
			var rise := y - prev
			var walked := i < walk.size() and bool(walk[i])
			print("PLACES %s step %d at %s: top %.2f rise %.2f %s" % [h.get_meta("poi"), i, pt.snapped(Vector3.ONE * 0.1), y, rise, "walk" if walked else "grab"])
			if absf(y - pt.y) > 0.25 or (not walked and rise > Player.GRAB_MAX):
				ok = false
			prev = y
		check("%s climb: every rise reachable, every stand point solid" % h.get_meta("poi"), ok)


func _fires() -> void:
	var posts := 0
	var fires: Dictionary = (load("res://core/world/realm/realm_bosses.gd") as GDScript).get("R34_FIRES")
	var space := p.get_world_3d().direct_space_state
	for n: String in fires:
		var b := main.get_node_or_null("Zone/Braziers/" + n) as Brazier
		check("fire %s stands" % n, b != null)
		if b == null:
			continue
		var at: Vector2 = fires[n][0]
		var near := INF
		var camp := Vector3.ZERO
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a3: Vector3 = cmp.at
			var dd := Vector2(a3.x - at.x, a3.z - at.y).length()
			if dd < near:
				near = dd
				camp = a3
		print("PLACES fire %s (%s) at %s: nearest camp %.1f m %s" % [n, b.display_name(), b.global_position.snapped(Vector3.ONE * 0.1), near, camp])
		var gs: Array[float] = []
		for o2: Vector2 in [Vector2(1.6, 0), Vector2(-1.6, 0), Vector2(0, 1.6), Vector2(0, -1.6)]:
			gs.append(RealmLayout.ground(space, at.x + o2.x, at.y + o2.y))
		gs.sort()
		var gm := (gs[1] + gs[2]) * 0.5
		print("PLACES fire %s y %.2f, ground round it %s" % [n, b.global_position.y, gs])
		check("fire %s on the ground" % n, absf(b.global_position.y - gm) < 0.7)
		check("fire %s is a travel marker" % n, b.is_in_group(&"map_marker") and String(b.get_meta(&"map_kind", "")) == "travel")
		check("fire %s 13 m+ from the camps" % n, near >= 13.0)
		check("fire %s named for its region (%s)" % [n, b.display_name()], b.display_name() != "A brazier")
		if b.get_node_or_null("EmberPost") != null:
			posts += 1
	check("every new fire has an ember-post", posts == fires.size())


func _lore() -> void:
	var placed := {}
	for s in get_tree().root.find_children("Lore_*", "", true, false):
		placed[String(s.get("lore_id"))] = true
	var per := {}
	for id: String in LoreDB.TEXTS:
		var reg := String(LoreDB.TEXTS[id].region)
		if not reg in NEW_REGIONS:
			continue
		check("lore %s placed" % id, placed.has(id))
		if placed.has(id):
			per[reg] = int(per.get(reg, 0)) + 1
	for reg: String in NEW_REGIONS:
		check("region %s holds 6+ readable stones (%d)" % [reg, int(per.get(reg, 0))], int(per.get(reg, 0)) >= 6)
		check("region %s in the Journal's order" % reg, reg in LoreDB.REGION_ORDER and LoreDB.PLACE_INFO.has(reg))
	for s: String in ["founder", "lamplog"]:
		check("series %s complete" % s, LoreDB.series_ids(s).size() == int(LoreDB.SERIES[s].count))


func _events() -> void:
	var we := main.get_node_or_null("WorldEvents")
	check("world events running", we != null)
	if we == null:
		return
	we.set("auto", false)
	var ids: Array[String] = []
	for s: Dictionary in we.call("sites"):
		ids.append(String(s.id))
	for id: String in R34.POIS:
		check("surge site %s" % id, id in ids)
	for id: String in R34.EXTRA:
		check("surge ground %s" % id, id in ids)
	check("a surge can be called in the Cinder Orchard's rows", bool(we.call("start_event", "orchard_rows")))
	we.call("_end", "faded")


func _gather() -> void:
	var nodes := get_tree().get_nodes_in_group("gather_node")
	var newg := 0
	for n in nodes:
		var q := (n as Node3D).global_position
		if String(RealmLayout.region_at(q.x, q.z).get("id", "")) in NEW_REGIONS:
			newg += 1
	print("PLACES gather nodes %d (%d in the new regions)" % [nodes.size(), newg])
	check("gather nodes doubled (%d)" % nodes.size(), nodes.size() >= 40)
	check("gather nodes in the new ground (%d)" % newg, newg >= 8)


func _chests() -> void:
	var chests := get_tree().get_nodes_in_group("loot_chest").filter(func(c: Node) -> bool: return R34.LOOT.has(String(c.get("chest_id"))))
	check("fourteen new chests (%d)" % chests.size(), chests.size() == R34.LOOT.size())
	var tiers := {}
	for c in chests:
		var id := String(c.get("chest_id"))
		tiers[c.get("tier")] = true
		var ash0 := Travel.count("grave_ash")
		check("chest %s closed at first" % id, c.call("can_interact"))
		var got: Array = c.call("open")
		check("chest %s gave its ash (%s)" % [id, got], Travel.count("grave_ash") > ash0)
		var again: Array = c.call("open")
		check("chest %s gives once" % id, again.is_empty())
	check("all three chest tiers in the new ground", tiers.size() == 3)


func _secrets() -> void:
	for id: String in ["cutters_nook", "ninth_rank", "corvin_sluice"]:
		check("secret %s registered" % id, not State.site(id).is_empty())
	var space := p.get_world_3d().direct_space_state
	# the nook: tall, sheer, reached by the Tether from the crane deck
	var nk := State.site("cutters_nook")
	if not nk.is_empty():
		var deck: Vector3 = nk.deck
		var lip: Vector3 = nk.anchor
		var foot: Vector3 = nk.foot
		var stand: Vector3 = nk.stand
		check("the nook's top is out of a jump's reach (%.1f m)" % (stand.y - foot.y), stand.y - foot.y > Player.GRAB_MAX + 3.0)
		check("the Tether reaches the nook from the deck (%.1f m)" % deck.distance_to(lip), deck.distance_to(lip) <= 18.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(deck + Vector3.UP * 1.4, lip, Layers.WORLD))
		check("the deck sees the nook's anchor", hit.is_empty() or (hit.position as Vector3).distance_to(lip) < 1.0)
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 1.0, stand + Vector3.DOWN * 1.0, Layers.WORLD))
		check("the nook's top is solid", not top.is_empty())
		var f := Travel.count("relic_fragment")
		State.take("cutters_nook", stand)
		check("the cutters' strongbox gives a fragment", Travel.count("relic_fragment") == f + 1)
	# the Ninth Rank: the slate's order
	var nr := State.site("ninth_rank")
	if not nr.is_empty():
		var lamps: Array = nr.lamps
		var tomb: Vector3 = nr.tomb
		SiteR34.light(1, lamps, tomb)
		SiteR34.light(2, lamps, tomb)
		check("a wrong lamp keeps the tomb shut", not State.has("solved", "ninth") and (nr.lid as StaticBody3D).collision_layer != 0)
		for i: int in SiteR34.RANK_ORDER:
			SiteR34.light(i, lamps, tomb)
		check("lit in the slate's order: the tomb opens", State.has("solved", "ninth") and (nr.lid as StaticBody3D).collision_layer == 0)
		var f2 := Travel.count("relic_fragment")
		var cache := (nr.node as Node).find_child("Cache_ninth_rank", true, false)
		cache.get("action").call(null)
		check("the ninth rank's cache gives a fragment once", Travel.count("relic_fragment") == f2 + 1 and not State.take("ninth_rank", tomb))
	# Corvin's Sluice: the lever raises the walk
	var sl := State.site("corvin_sluice")
	if not sl.is_empty():
		var walk: StaticBody3D = sl.door
		check("the walk lies sunk before the lever", walk.collision_layer == 0)
		SiteR34.pull(sl.lever)
		check("the lever raises the walk", State.has("open", "sluice") and walk.collision_layer != 0)
		var e: Array = sl.walk
		var mid: Vector3 = ((e[0] as Vector3) + (e[1] as Vector3)) * 0.5
		var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3.UP * 2.0, mid + Vector3.DOWN * 2.0, Layers.WORLD))
		check("the raised walk is solid over the water", not hit2.is_empty() and (hit2.position as Vector3).y > -0.9)
		var at: Vector3 = sl.at
		var bottom := RealmLayout.ground(space, at.x + 2.5, at.z + 2.5)
		check("the islet is out of reach from the water (%.1f m)" % (at.y - bottom), at.y - bottom > Player.GRAB_MAX + 0.3)
		var f3 := Travel.count("relic_fragment")
		State.take("corvin_sluice", at)
		check("Corvin's lamp-box gives a fragment", Travel.count("relic_fragment") == f3 + 1)


func _restore() -> void:
	Travel.items = items_before
	Travel.systems = systems_before
	State.quiet = false


## Walk at the next stand point, jump when close and below it, hold through the hang; 9 s a step.
func _climb_tick(dt: float) -> void:
	rt += dt
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	var id: String = climbs[ci][0]
	if ri >= route.size():
		check("climbed the %s to its top (%.1f m)" % [id, p.global_position.y], true)
		p.debug_drive(Vector3.ZERO)
		Input.action_release("jump")
		step = 10
		wait = 10
		return
	var target: Vector3 = route[ri]
	var d := Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
	p.debug_drive(d.normalized() if d.length() > 0.25 else Vector3.ZERO)
	p.set("gloom", 0.0); p.set("wounds", 0.0)
	if p.is_grounded() and p.global_position.y > target.y - 0.4 and d.length() < 0.9:
		print("PLACES %s step %d reached in %.1f s at %s" % [id, ri, rt, p.global_position.snapped(Vector3.ONE * 0.01)])
		ri += 1
		rt = 0.0
		rj = -1.0
		Input.action_release("jump")
		return
	if rj < 0.0 and p.is_grounded() and p.global_position.y < target.y - 0.5 and d.length() < 2.0:
		Input.action_press("jump")
		rj = rt
	elif rj >= 0.0 and rt - rj > 0.3:
		Input.action_release("jump")
		if p.is_grounded() and rt - rj > 1.2:
			rj = -1.0
	if rt > 9.0:
		check("climbed %s step %d (stuck at %s, target %s, hanging %s)" % [id, ri, p.global_position.snapped(Vector3.ONE * 0.01), target.snapped(Vector3.ONE * 0.01), p.is_hanging()], false)
		p.debug_drive(Vector3.ZERO)
		Input.action_release("jump")
		step = 10
		wait = 10

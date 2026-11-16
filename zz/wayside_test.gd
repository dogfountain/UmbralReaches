extends Node
## The world density pass (core/world/realm/realm_wayside.gd, wayside_kit.gd, flora_layers.gd; docs/world_density.md),
## in memory only (saves held, the satchel and system state restored):
##   - the wayside planned and built its places: enough of them, every Far Reaches region holding its share, kinds mixed
##   - every place stands on dry ground (a jetty at a shore), its solid ground off the ways, 12 m+ from the camps and
##     fires, outside the towns
##   - most of each region's named places are there, each a discovery (world_poi with a name, a line and a centre)
##   - every box opens once, gives its ash and remembers it
##   - every writing given to a place is in the world, reads, and its sense point stands in open air
##   - along every way, the next registered place is near (coverage)
##   - the flora's layers all grew (feet, verges, thickets, deadfall, drifts, glades, creep)
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh wayside
const Wayside := preload("res://core/world/realm/realm_wayside.gd")
const Themes := preload("res://core/world/realm/wayside_themes.gd")
const FloraLayers := preload("res://core/world/realm/flora_layers.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Texts := preload("res://core/world/realm/lore/wayside_texts.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const Footing := preload("res://core/world/footing.gd")

const MIN_PLACES := 180
const MIN_PER_REACH := 5
const NAMED_SHARE := 0.85

var main: Node
var t := 0.0
var done := false
var fails := 0


func _ready() -> void:
	Travel._busy = true
	CodexStore.persist = false
	CodexStore.use_path("user://codex_wayside_test.cfg", false)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(what: String, ok: bool) -> void:
	print("WAYSIDE_T ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 260.0:
		print("WAYSIDE_T FAIL timeout")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 2.0:
		return
	done = true
	await get_tree().physics_frame
	_check()
	print("WAYSIDE_T %s %d" % ["DONE PASS" if fails == 0 else "DONE FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _check() -> void:
	var plan: Array = Wayside.plan
	print("WAYSIDE_T planned %d, built %d; kinds %s" % [plan.size(), Wayside.built, Wayside.stats])
	check("planned %d places (>= %d)" % [plan.size(), MIN_PLACES], plan.size() >= MIN_PLACES)
	check("every planned place built (%d of %d)" % [Wayside.built, plan.size()], Wayside.built == plan.size())
	check("kinds mixed (%d kinds)" % Wayside.stats.size(), Wayside.stats.size() >= 15)
	var per := {}
	for v: Dictionary in plan:
		per[v.region] = int(per.get(v.region, 0)) + 1
	for id: String in RealmReaches.IDS:
		if id in ["lastlight"]:
			continue                 # the waystation's flat is its town: its outskirts only
		check("%s holds %d places (>= %d)" % [id, int(per.get(id, 0)), MIN_PER_REACH], int(per.get(id, 0)) >= MIN_PER_REACH)
	_ground(plan)
	_named(plan)
	_boxes()
	_writings(plan)
	_coverage()
	if Flora.cached:
		print("WAYSIDE_T skip the flora layers' counts (the placement came from the cache)")
	else:
		for layer: String in ["feet", "verges", "thickets", "deadfall", "drifts", "glades", "creep"]:
			check("flora layer %s grew (%d)" % [layer, int(FloraLayers.counts.get(layer, 0))], int(FloraLayers.counts.get(layer, 0)) > 20)


func _ground(plan: Array) -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var bad: Array[String] = []
	var fires: Array[Vector2] = []
	for b in get_tree().root.find_children("*", "Brazier", true, false):
		fires.append(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
	for v: Dictionary in plan:
		var a: Vector3 = v.at
		var q := Vector2(a.x, a.z)
		var wet: bool = v.kind == "jetty" or v.kind == "drowned"
		if not wet and Land.in_water(a.x, a.z):
			bad.append("%s %s in the water" % [v.kind, v.id])
		var g := Footing.terrain_y(space, a.x, a.z, a.y)          # (the terrain itself: the place stands on its own middle)
		if absf(g - a.y) > 0.8:
			bad.append("%s %s floats or sinks %.2f m" % [v.kind, v.id, a.y - g])
		for r: Rect2 in v.feet:
			if RealmLayout.path_dist(r.get_center()) < maxf(r.size.x, r.size.y) * 0.5 + 0.3 and v.kind != "milestone":
				bad.append("%s %s footprint on a way at %s" % [v.kind, v.id, r.get_center()])
				break
		for c: Dictionary in EnemySpawner.REALM_CAMPS:
			var ca: Vector3 = c.at
			if Vector2(ca.x, ca.z).distance_to(q) < 12.0:
				bad.append("%s %s by a camp at %s" % [v.kind, v.id, ca])
		for f in fires:
			if f.distance_to(q) < 11.0:
				bad.append("%s %s by a fire at %s" % [v.kind, v.id, f])
		for tw: Array in Themes.TOWNS:
			if q.distance_to(tw[0]) < float(tw[1]):
				bad.append("%s %s in a town" % [v.kind, v.id])
	for b2 in bad.slice(0, 12):
		print("WAYSIDE_T   ", b2)
	check("every place on dry ground, off the ways, the camps, the fires and the towns (%d bad)" % bad.size(), bad.is_empty())


func _named(plan: Array) -> void:
	var want := 0
	for region: String in Themes.NAMED:
		want += (Themes.NAMED[region] as Array).size()
	var hosts := get_tree().get_nodes_in_group("world_poi").filter(func(h: Node) -> bool: return h.has_meta("wayside"))
	check("named places %d of %d (>= %d %%)" % [hosts.size(), want, int(NAMED_SHARE * 100.0)], float(hosts.size()) >= float(want) * NAMED_SHARE)
	var ids := {}
	for h in hosts:
		var ok: bool = String(h.get_meta("title", "")) != "" and String(h.get_meta("line", "")) != "" and h.has_meta("centre")
		if not ok:
			check("named place %s has a name, a line and a centre" % h.name, false)
		ids[String(h.get_meta("poi"))] = true
	check("named places' ids unique (%d)" % ids.size(), ids.size() == hosts.size())
	var disc := main.get_node_or_null("Discovery")
	if disc != null:
		disc.call("_collect_spots")
		var spots: Array = disc.call("spot_ids")
		var found := 0
		for id: String in ids:
			if ("poi_" + id) in spots:
				found += 1
		check("the discovery knows every named place (%d of %d)" % [found, ids.size()], found == ids.size())


func _boxes() -> void:
	var items_before := Travel.items.duplicate(true)
	var systems_before := Travel.systems.duplicate(true)
	var chests := get_tree().get_nodes_in_group("loot_chest").filter(func(c: Node) -> bool: return String(c.get("chest_id")).begins_with("way_"))
	check("boxes in the wayside (%d)" % chests.size(), chests.size() >= 18)
	var ok := true
	for c in chests:
		var ash0 := Travel.count("grave_ash")
		if not bool(c.call("can_interact")):
			ok = false
			print("WAYSIDE_T   box %s not closed at first" % c.get("chest_id"))
			continue
		c.call("open")
		if Travel.count("grave_ash") <= ash0 or bool(c.call("can_interact")):
			ok = false
			print("WAYSIDE_T   box %s gave nothing or stayed shut" % c.get("chest_id"))
	check("every box opens once and pays", ok)
	Travel.items = items_before
	Travel.systems = systems_before


func _writings(plan: Array) -> void:
	var given := {}
	for v: Dictionary in plan:
		if String(v.get("lore", "")) != "":
			given[String(v.lore)] = true
	var scraps := {}
	for s in get_tree().root.find_children("Lore_*", "", true, false):
		scraps[String(s.get("lore_id"))] = s
	var missing: Array[String] = []
	for id: String in given:
		if not scraps.has(id):
			missing.append(id)
	check("every writing given to a place is in the world (%d of %d; missing %s)" % [given.size() - missing.size(), given.size(), missing], missing.is_empty())
	check("most of the wayside's writings placed (%d of %d)" % [given.size(), Texts.TEXTS.size()], given.size() >= int(Texts.TEXTS.size() * 0.8))
	var space := (main as Node3D).get_world_3d().direct_space_state
	var inside := 0
	for id: String in given:
		var s: Node3D = scraps.get(id)
		if s == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.25
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, s.global_position + Vector3.UP * 0.9)
		q.collision_mask = Layers.WORLD
		if not space.intersect_shape(q, 1).is_empty():
			inside += 1
			print("WAYSIDE_T   writing %s's sense point inside something at %s" % [id, s.global_position])
		(s as Interactable).interact(null)
		if not CodexStore.has_read(id):
			check("%s reads into the journal" % id, false)
	check("the writings' sense points in open air (%d inside)" % inside, inside == 0)


func _coverage() -> void:
	var far := 0
	var n := 0
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var seg := a.distance_to(b)
			var s := 0.0
			while s < seg:
				var q := a.lerp(b, s / seg)
				s += 5.0
				n += 1
				var best := 999.0
				for st: Dictionary in WorldLanes.sites:
					var r: Rect2 = st.rect
					var dx := maxf(maxf(r.position.x - q.x, 0.0), q.x - r.end.x)
					var dz := maxf(maxf(r.position.y - q.y, 0.0), q.y - r.end.y)
					best = minf(best, sqrt(dx * dx + dz * dz))
				if best > 45.0:
					far += 1
	check("along the ways the next place is within 45 m (%d of %d samples further)" % [far, n], far <= n / 50)

extends Node
## r31 world pass (core/world/realm/realm_pois.gd, docs/enshrouded/world.md), in memory only (saves
## held, the satchel and system state restored):
##   - the four places are built, named, and each first visit raises its banner
##   - every chest opens once, gives its loot, and remembers it
##   - the mini-boss floors are level, open and clear of camps; grapple points and glide perches exist
##   - the causeway's boards are walkable over the fen
##   - every climb route is grabbable step by step, and the real wanderer climbs the belfry, the
##     almonry loft and the Watchers' Spire to the top
## Run: HOME=<scratch> godot --headless --path . res://zz/world_poi_test.tscn [-- --only=spire]
const Pois := preload("res://core/world/realm/realm_pois.gd")
var p: Player
var main: Node
var t := 0
var step := 0
var wait := 0
var fails := 0
var climbs: Array = []                  # [id, route, approach]
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
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	# r33: the places are named by the zone discovery (realm_discovery.gd): one subzone discovery each
	Events.region_discovered.connect(func(id: String, kind: String) -> void:
		if kind == "subzone" and id.begins_with("sub_poi_"):
			banners.append(id))


func check(name: String, ok: bool) -> void:
	print("POI ", "PASS " if ok else "FAIL ", name)
	if not ok:
		fails += 1


func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 400:
		print("POI FAIL timeout at step ", step)
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
			_static_checks()
			step = 1
		1:
			_chests()
			step = 2
		2:
			# banners: stand in each place once (step 3 holds while this coroutine runs)
			var disc := main.get_node_or_null("Discovery")
			if disc and float(disc.get("_clock")) < 7.0:
				return                                  # the discovery arms after the night's title card
			step = 3
			var hosts := _hosts()
			for h in hosts:
				var c: Vector3 = h.get_meta("centre")
				_tp(c + Vector3(0, 30.0, 0))           # in the air over it: the watch is distance-only
				await get_tree().create_timer(0.7).timeout
			var want := hosts.size()
			check("each place named on the first visit (%d banners for %d places)" % [banners.size(), want], banners.size() >= want)
			var before := banners.size()
			_tp((hosts[0].get_meta("centre") as Vector3) + Vector3(0, 30.0, 0))
			await get_tree().create_timer(0.7).timeout
			check("a place is named once", banners.size() == before)
			for h in hosts:
				if h.has_meta("route"):
					var only := ""
					for a in OS.get_cmdline_user_args():
						if a.begins_with("--only="):
							only = a.trim_prefix("--only=")
					if only == "" or String(h.get_meta("poi")) in only.split(","):
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
			print("POI DONE %d FAIL" % fails if fails > 0 else "POI DONE all passed")
			get_tree().quit(1 if fails > 0 else 0)
			step = 100


func _static_checks() -> void:
	var space := p.get_world_3d().direct_space_state
	var hosts := _hosts()
	var ids: Array[String] = []
	for h in hosts:
		ids.append(String(h.get_meta("poi")))
	ids.sort()
	check("four places built %s" % [ids], ids.size() == 4)
	# the mini-boss floors: level and open, inside the world, clear of camps
	var sites := Pois.miniboss_sites(get_tree()).filter(func(d: Dictionary) -> bool: return String(d.poi) in Pois.POIS)
	check("four mini-boss floors (%d)" % sites.size(), sites.size() >= 4)
	check("each floor is a guardian site", get_tree().get_nodes_in_group(Pois.GROUP_GUARDIAN).size() >= sites.size())
	for s: Dictionary in sites:
		var c: Vector3 = s.at
		var r: float = s.radius
		var worst := 0.0
		var blocked := 0
		for i in 16:
			var a := TAU * float(i) / 16.0
			for f: float in [0.4, 0.8]:
				var q := c + Vector3(cos(a), 0, sin(a)) * r * f
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 4.0, q + Vector3.DOWN * 4.0, Layers.WORLD))
				if hit.is_empty():
					blocked += 1
					continue
				var dy := absf((hit.position as Vector3).y - c.y)
				worst = maxf(worst, dy)
				if dy > 1.2 or (hit.normal as Vector3).y < 0.75:
					blocked += 1
		var near_camp := INF
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a3: Vector3 = cmp.at
			near_camp = minf(near_camp, Vector2(a3.x - c.x, a3.z - c.z).length())
		print("POI floor %s at %s r %.1f: worst rise %.2f, blocked %d/32, nearest camp %.1f m" % [s.id, c.snapped(Vector3.ONE * 0.1), r, worst, blocked, near_camp])
		check("floor %s level and open" % s.id, blocked <= 3)
		check("floor %s clear of camps" % s.id, near_camp > r + 4.0)
		check("floor %s inside the world" % s.id, RealmLayout.BOUNDS.grow(-6.0).has_point(Vector2(c.x, c.z)))
	var grapples := Pois.anchors(get_tree(), Pois.GROUP_GRAPPLE)
	var perches := Pois.anchors(get_tree(), Pois.GROUP_GLIDE)
	check("grapple points (%d)" % grapples.size(), grapples.size() >= 4)
	check("glide perches (%d)" % perches.size(), perches.size() >= 3)
	check("updrafts over the charcoal clamps (%d)" % Pois.anchors(get_tree(), Pois.GROUP_UPDRAFT).size(), Pois.anchors(get_tree(), Pois.GROUP_UPDRAFT).size() >= 3)
	for pc: Dictionary in perches:
		var at: Vector3 = pc.at
		var g := RealmLayout.ground(space, at.x + (pc.facing as Vector3).x * 6.0, at.z + (pc.facing as Vector3).z * 6.0)
		print("POI perch at %s drop %.1f (ground ahead %.1f)" % [at.snapped(Vector3.ONE * 0.1), float(pc.drop), g])
		check("perch at %s has a real drop" % at.snapped(Vector3.ONE * 0.1), at.y - g > 5.0)
	# the causeway: boards over the fen, walkable
	var cw: Array = Pois.causeway
	var ok_boards := cw.size() >= 2
	if ok_boards:
		for i in 9:
			var q: Vector2 = (cw[0] as Vector2).lerp(cw[1], 0.03 + float(i) / 4.4) if i < 5 else (cw[1] as Vector2).lerp(cw[2], float(i - 4) / 4.4)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, 6.0, q.y), Vector3(q.x, -4.0, q.y), Layers.WORLD))
			var gy := RealmLayout.ground(space, q.x, q.y)
			var y: float = (hit.position as Vector3).y if not hit.is_empty() else -INF
			if y < gy + 0.1 and y < -0.6:
				ok_boards = false
				print("POI causeway gap at %s (hit %.2f ground %.2f)" % [q, y, gy])
	check("the causeway is walkable to the belfry", ok_boards)
	# the readable stones of the places
	var lore := 0
	for h in hosts:
		lore += h.find_children("Lore_poi_*", "", true, false).size()
	check("seven readable stones in the places (%d)" % lore, lore == 7)
	# every climb route: each rise inside the grab reach, each stand point real ground
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
			print("POI %s step %d at %s: top %.2f rise %.2f %s" % [h.get_meta("poi"), i, pt.snapped(Vector3.ONE * 0.1), y, rise, "walk" if i < walk.size() and bool(walk[i]) else "grab"])
			var walked := i < walk.size() and bool(walk[i])
			if absf(y - pt.y) > 0.2 or (not walked and rise > Player.GRAB_MAX):
				ok = false
			prev = y
		check("%s climb: every rise reachable, every stand point solid" % h.get_meta("poi"), ok)


## r34: the r31 four only (the new ground's places have zz/places_r34_test).
func _hosts() -> Array:
	return get_tree().get_nodes_in_group(Pois.GROUP_POI).filter(func(h: Node) -> bool: return not h.has_meta("r34") and not h.has_meta("r37") and not h.has_meta("reach") and not h.has_meta("wayside"))      # the r34, r37 and Far Reaches places have their own tests


func _chests() -> void:
	items_before = Travel.items.duplicate(true)
	systems_before = Travel.systems.duplicate(true)
	var chests := get_tree().get_nodes_in_group("loot_chest").filter(func(c: Node) -> bool: return Pois.LOOT.has(String(c.get("chest_id"))))
	check("four chests (%d)" % chests.size(), chests.size() == 4)
	for c in chests:
		var id := String(c.get("chest_id"))
		var ash0 := Travel.count("grave_ash")
		check("chest %s closed at first" % id, c.call("can_interact"))
		var got: Array = c.call("open")
		var ash1 := Travel.count("grave_ash")
		print("POI chest %s (%s) gave %s" % [id, c.get("tier"), got])
		check("chest %s gave its ash" % id, ash1 > ash0)
		check("chest %s remembered" % id, (Travel.system_state("world_pois").chests as Dictionary).has(id) and not c.call("can_interact"))
		var again: Array = c.call("open")
		check("chest %s gives once" % id, again.is_empty() and Travel.count("grave_ash") == ash1)


func _restore() -> void:
	Travel.items = items_before
	Travel.systems = systems_before


## Walk at the next stand point, jump when close and below it, hold through the hang; 9 s a step.
func _climb_tick(dt: float) -> void:
	rt += dt
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()                   # guardians and camps rise near the places: not this test's fight
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
	if p.is_grounded() and p.global_position.y > target.y - 0.2 and d.length() < 0.9:
		print("POI %s step %d reached in %.1f s at %s" % [id, ri, rt, p.global_position.snapped(Vector3.ONE * 0.01)])
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

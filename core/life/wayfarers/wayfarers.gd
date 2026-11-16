extends Node3D
## People on the roads (docs/living_realm.md): pilgrims, the Watch's patrols, peddlers, a mother and her boy, fishers,
## a messenger, mourners. Built by the life module (wildlife.gd) after the village; "Wayfarers" under the zone root.
##
## The ways are one network (road_graph.gd); its havens are the towns, every brazier and outpost fire near a way, and
## the watch posts. Stretches that pass a camp's ground (EnemySpawner.REALM_CAMPS, the camp slots, the elites'
## haunts) are not walked: the living keep to the safe roads between lit places, so the dark country stays empty and
## the roads near the towns are walked. A party lives near its home (WayfarerDB.PARTIES) and goes haven to haven:
##   WALK  along its way in file, the lantern first           REST  at a fire: warming, watching, praying, talking
##   AWAY  inside a town for a while (unseen)                 FLEE  turned back (or hurrying on) from a hollowed thing
##   HALT  a patrol stands and faces the dark
## A lit brazier draws them (a fire you kindled is a place to rest); a dark one is passed, or prayed at.
## Far off a party is a point on its way and a lantern's glow (wayfarer_lamp.gdshader: one MultiMesh, no script per
## frame beyond moving it); within NEAR_ON of the camera its people are drawn and walk (villager.gd in follow mode:
## real feet on the ground, steering round what is in the way). They stop and greet the wanderer (a few words of
## babble) when she comes close, and step round her.
## Load by path: const Wayfarers := preload("res://core/life/wayfarers/wayfarers.gd")

const RoadGraph := preload("res://core/life/wayfarers/road_graph.gd")
const DB := preload("res://core/life/wayfarers/wayfarer_db.gd")
const Reaches := preload("res://core/life/wildlife/life_reaches.gd")
const VillagerScript := preload("res://core/life/village/villager.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const RL := preload("res://core/world/realm/realm_land.gd")
const LAMP_SH := preload("res://core/life/wayfarers/wayfarer_lamp.gdshader")

## Towns: where they live and go indoors. Reedholm's stilt-houses are the Reedmere's place slot.
const TOWNS := {
	"Hearthward": Vector2(6.0, 38.0), "Weirford": Vector2(-205.0, 66.0), "Saltmarket": Vector2(212.0, 92.0),
	"Lastlight": RealmReaches.TOWN_E, "Fallowmere": RealmReaches.TOWN_F, "Reedholm": Vector2(-328.0, 296.0),
}
## How far out a town's edge is (its region's radius; the Far Reaches' towns are smaller).
const TOWN_EDGE := {"Hearthward": 36.0, "Weirford": 28.0, "Saltmarket": 22.0, "Lastlight": 24.0, "Fallowmere": 22.0, "Reedholm": 16.0}
## Homes that are not towns (the fire nearest is home).
const PLACES := {"Kings' Barrows": Vector2(-318.0, 96.0), "the Cairns": Vector2(300.0, 286.0), "the Siege Lines": Vector2(-214.0, 100.0),
	"the Southwood": Vector2(150.0, 296.0), "the Long Arches": Vector2(-24.0, 318.0), "the Greyfell": Vector2(-310.0, -66.0)}

const NEAR_ON := 92.0             ## a party's people are made real within this of the camera
const NEAR_OFF := 108.0           ## and put away past this (their rigs have faded by then)
const RIG_RANGE := 86.0           ## the people's rigs fade out from here (the lamp quad takes over)
const CAMP_R := 22.0              ## a way this near a camp is not walked (a grunt chases 11-14 m from where it stands)
const SNAP := 26.0                ## a fire further than this from a way is not a haven
const AHEAD := 3.4                ## the leader walks after a point this far on along the way
const SEE_R := 20.0               ## a hollowed thing this near sends them back
const CALM_R := 34.0              ## ... and none this near for CALM_T seconds lets them go on
const CALM_T := 5.0
const GREET_R := 5.0

enum { WALK, REST, AWAY, FLEE, HALT }

var village                        ## the village director (village.gd): its walking network's floor probe
var director                       ## the Wildlife (life_director.gd): the near hollowed things
var graph: RoadGraph
var havens: Array = []             ## {name, kind: town/fire/post, at: Vector2, node: int, brazier: Node3D}
var parties: Array = []
var lamps: MultiMeshInstance3D
var report: Array[String] = []
var greets := 0                    ## (tests)
var flights := 0
var arrivals := 0
var _rng := RandomNumberGenerator.new()
var _t4 := 0.0
var _t10 := 0.0
var _tide := false
var _cam := Vector3.ZERO


static func build(root: Node) -> void:
	if root.get_node_or_null("Wayfarers") != null or "--no-wayfarers" in OS.get_cmdline_user_args():
		return
	var v := root.get_node_or_null("Village")
	if v == null:
		return
	var t := Time.get_ticks_usec()
	var w := new()
	w.name = "Wayfarers"
	root.add_child(w)
	w._build(root, v)
	Realm.prof_add("life: wayfarers", t)


func _build(root: Node, v: Node) -> void:
	village = v
	director = root.get_node_or_null("Wildlife")
	_rng.seed = 91001
	add_to_group(&"life_census")
	graph = RoadGraph.new()
	graph.build(RealmLayout.PATHS)
	var no_go: Array[Vector2] = Reaches.keep_camps()
	for rd: Dictionary in RealmLayout.RAIDS:
		no_go.append(rd.c as Vector2)
	graph.mark_unsafe(no_go, CAMP_R)
	_havens(root)
	var stops: Array[int] = []
	for h: Dictionary in havens:
		stops.append(int(h.node))
	graph.compress(stops)
	_lamps()
	for spec: Dictionary in DB.PARTIES:
		_party(spec)
	if Events.has_signal("gloom_tide"):
		Events.gloom_tide.connect(func(on: bool) -> void: _tide = on)
	report.append("%d nodes (%d kept), %d havens, %d parties" % [graph.pts.size(), graph.cnode.size(), havens.size(), parties.size()])
	print("LIFE wayfarers: ", " | ".join(report))


# --- havens -----------------------------------------------------------------------------------------

func _havens(root: Node) -> void:
	for nm: String in TOWNS:
		# a town's haven is its edge (where a way leaves it): travellers go in and out there and never stand about
		# in its square among its own people
		var at: Vector2 = TOWNS[nm]
		var edge_r: float = TOWN_EDGE.get(nm, 22.0)
		var n := -1
		var bd := INF
		for i in graph.pts.size():
			if (graph.adj[i] as Array).is_empty():
				continue
			var d := graph.pts[i].distance_to(at)
			if d >= edge_r and d < bd:
				bd = d
				n = i
		if n >= 0 and bd < edge_r + 30.0:
			havens.append({"name": nm, "kind": "town", "at": graph.pts[n], "node": n, "brazier": null})
	var fires: Array = []
	for b in root.find_children("*", "Brazier", true, false):
		fires.append([(b as Node3D).global_position, b])
	var outs: Dictionary = village.get("outpost_at")
	for id: String in outs:
		fires.append([outs[id] as Vector3, null])
	for f: Array in fires:
		var p: Vector3 = f[0]
		var q := Vector2(p.x, p.z)
		var n := graph.nearest(q, SNAP)
		if n < 0:
			continue
		var dup := false
		for h: Dictionary in havens:
			if (h.at as Vector2).distance_to(q) < 8.0:
				dup = true
		if not dup:
			havens.append({"name": String((f[1] as Node).name) if f[1] != null else "outpost", "kind": "fire", "at": q, "node": n, "brazier": f[1]})
	for wp in get_tree().get_nodes_in_group(&"watch_post"):
		var p2 := (wp as Node3D).global_position
		var q2 := Vector2(p2.x, p2.z)
		var n2 := graph.nearest(q2, SNAP)
		if n2 >= 0:
			havens.append({"name": String(wp.get("title")), "kind": "post", "at": q2 + ((graph.pts[n2] - q2).normalized() * 3.0 if graph.pts[n2].distance_to(q2) > 3.0 else Vector2.ZERO), "node": n2, "brazier": null})


func _lit(h: Dictionary) -> bool:
	var b: Variant = h.brazier
	if b == null or not is_instance_valid(b):
		return true
	return (b as Brazier).lit


## Where a party stands on arriving: the way's node for a town, a step short of the fire for a fire, the post.
func _stand(hi: int, from: Vector2) -> Vector2:
	var h: Dictionary = havens[hi]
	if String(h.kind) == "fire":
		var at: Vector2 = h.at
		var d := (from - at)
		return at + (d.normalized() if d.length() > 0.1 else Vector2(1, 0)) * 3.4
	return h.at


# --- parties ----------------------------------------------------------------------------------------

func _party(spec: Dictionary) -> void:
	var home := _home_haven(String(spec.home))
	if home < 0:
		report.append("no home for %s at %s" % [spec.kind, spec.home])
		return
	var kind := String(spec.kind)
	var dist := graph.reach(int(havens[home].node))
	var roam: Array[int] = []
	for hi in havens.size():
		var cn: Variant = graph.cid.get(int(havens[hi].node))
		if cn != null and dist[int(cn)] <= float(spec.roam):
			if String(havens[hi].kind) == "post" and kind != "patrol":
				continue
			roam.append(hi)
	if roam.size() < 2:
		report.append("%s at %s: nowhere to go" % [kind, spec.home])
		return
	var p := {"kind": kind, "spec": DB.KINDS[kind], "home": home, "roam": roam, "people": [], "at": home, "to": -1,
		"route": PackedVector2Array(), "cum": PackedFloat32Array(), "s": 0.0, "dir": 1.0, "state": WALK, "t": 0.0,
		"near": false, "greet_t": 0.0, "calm_t": 0.0, "speed": float(DB.KINDS[kind].speed) * _rng.randf_range(0.92, 1.08),
		"phase": _rng.randf() * TAU, "spots": [], "act": "", "seen_t": 0.0, "lamp_i": parties.size(), "name": "%s of %s" % [kind, spec.home]}
	var i := 0
	for look: Dictionary in spec.people:
		p.people.append(_person(look, kind, parties.size(), i))
		i += 1
	parties.append(p)
	# a start somewhere along a first way, so the roads are walked from the first minute
	if _depart(p, Vector2(havens[home].at)):
		p.s = _rng.randf_range(0.1, 0.8) * float(p.cum[p.cum.size() - 1])
		if _rng.randf() < 0.25:
			_arrive(p)
			p.t = _rng.randf_range(5.0, float(p.t))
	else:
		# no way out from home just now: they stay by it a while and try again (never a walk on an empty way)
		p.state = REST
		p.act = ""
		p.t = 30.0
		p.spots = _ring(p, home)
	_hide_people(p)


func _home_haven(nm: String) -> int:
	var at: Vector2 = TOWNS.get(nm, PLACES.get(nm, Vector2.INF))
	if at == Vector2.INF:
		return -1
	var best := -1
	var bd := 60.0
	for hi in havens.size():
		var h: Dictionary = havens[hi]
		var d := (h.at as Vector2).distance_to(at)
		if String(h.name) == nm:
			return hi
		if d < bd:
			bd = d
			best = hi
	return best


func _person(look: Dictionary, kind: String, pi: int, i: int) -> VillagerScript:
	var rig := DB.rig_look(look)
	var lamp := String(rig.get("l", "")) == "lantern"
	var v: VillagerScript = VillagerScript.new()
	v.setup("road_%d_%d" % [pi, i], {"name": "A traveller", "camp": "road", "fearless": true, "speed": 1.0, "routines": {}, "light": lamp, "rig": rig}, village)
	add_child(v)
	v.remove_from_group(Groups.INTERACTABLE)
	v.remove_from_group("villager")          # not Hearthward's: they walk off its map
	if v.rig != null and v.rig.mesh_instance != null:
		var mi: GeometryInstance3D = v.rig.mesh_instance
		mi.visibility_range_end = RIG_RANGE
		mi.visibility_range_end_margin = 8.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	v.set_meta(&"wayfarer", kind)
	return v


## Pick where to go next from `p.at` and set the way there. False when there is nowhere.
func _depart(p: Dictionary, from: Vector2) -> bool:
	var at: int = p.at
	var kind := String(p.kind)
	var cands: Array = []
	var total := 0.0
	for hi: int in p.roam:
		if hi == at or (havens[hi].at as Vector2).distance_to(havens[at].at as Vector2) < 25.0:
			continue
		var h: Dictionary = havens[hi]
		var w := 1.0
		match String(h.kind):
			"town":
				w = 2.0
			"fire":
				w = 3.0 if _lit(h) else (1.4 if kind in ["pilgrims", "mourners"] else 0.5)
			"post":
				w = 3.0
		if hi == p.home:
			w *= 1.5
		cands.append([hi, w])
		total += w
	_rng.randf()
	for _try in 6:
		if cands.is_empty():
			return false
		var pick := _rng.randf() * total
		var chosen: Array = cands[0]
		for c: Array in cands:
			pick -= float(c[1])
			if pick <= 0.0:
				chosen = c
				break
		var to: int = chosen[0]
		var edges := graph.route(int(havens[at].node), int(havens[to].node))
		if edges.is_empty():
			cands.erase(chosen)
			total -= float(chosen[1])
			continue
		var line := RoadGraph.polyline(edges, from, _stand(to, graph.pts[int(havens[to].node)]))
		p.to = to
		p.route = line
		var cum := PackedFloat32Array([0.0])
		for k in range(1, line.size()):
			cum.append(cum[k - 1] + line[k].distance_to(line[k - 1]))
		p.cum = cum
		p.s = 0.0
		p.dir = 1.0
		p.state = WALK
		p.calm_t = 0.0
		return true
	return false


func _pos(p: Dictionary, s: float) -> Vector2:
	var line: PackedVector2Array = p.route
	var cum: PackedFloat32Array = p.cum
	if line.is_empty():
		return havens[int(p.at)].at
	s = clampf(s, 0.0, cum[cum.size() - 1])
	var k := cum.bsearch(s)
	if k <= 0:
		return line[0]
	if k >= line.size():
		return line[line.size() - 1]
	var seg := cum[k] - cum[k - 1]
	return line[k - 1].lerp(line[k], (s - cum[k - 1]) / maxf(seg, 0.001))


func _len(p: Dictionary) -> float:
	var cum: PackedFloat32Array = p.cum
	return cum[cum.size() - 1] if not cum.is_empty() else 0.0


## The way's distance nearest to q, searched round s0.
func _project(p: Dictionary, q: Vector2, s0: float) -> float:
	var line: PackedVector2Array = p.route
	var cum: PackedFloat32Array = p.cum
	if line.size() < 2:
		return 0.0
	var k0 := clampi(cum.bsearch(s0) - 12, 0, line.size() - 2)
	var k1 := clampi(k0 + 24, 0, line.size() - 2)
	var best := s0
	var bd := INF
	for k in range(k0, k1 + 1):
		var a := line[k]
		var b := line[k + 1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := q.distance_to(a + ab * t)
		if d < bd:
			bd = d
			best = cum[k] + (cum[k + 1] - cum[k]) * t
	return best


func _arrive(p: Dictionary) -> void:
	arrivals += 1
	var at: int = p.to if float(p.dir) > 0.0 else int(p.at)
	p.at = at
	var h: Dictionary = havens[at]
	var spec: Dictionary = p.spec
	p.dir = 1.0
	match String(h.kind):
		"town":
			if bool(p.near):
				# in view: they stop at the town's edge and talk a while, then go on (nobody vanishes in plain sight)
				p.state = REST
				p.act = "chat"
				p.t = _rng.randf_range(10.0, 22.0)
			else:
				p.state = AWAY
				p.t = _rng.randf_range(float(spec.away[0]), float(spec.away[1])) * (0.5 if _tide else 1.0)
		"fire", "post":
			var act := ""
			if String(h.kind) == "post":
				act = "watch" if String(p.kind) == "patrol" else ""
			elif _lit(h):
				act = String(spec.rest)
			else:
				act = String(spec.dark)
			if act == "":
				p.state = REST
				p.act = ""
				p.t = _rng.randf_range(2.0, 5.0)
			else:
				p.state = REST
				p.act = act
				p.t = _rng.randf_range(float(spec.rest_t[0]), float(spec.rest_t[1])) * (0.4 if _tide else 1.0)
	p.spots = _ring(p, at)
	if bool(p.near):
		_settle(p)


## Spots round a fire (or a post) for each of the party, facing it.
func _ring(p: Dictionary, hi: int) -> Array:
	var h: Dictionary = havens[hi]
	var c: Vector2 = h.at
	var n := (p.people as Array).size()
	var out: Array = []
	var start := _rng.randf() * TAU
	var r := 2.5 if String(h.kind) == "fire" else 1.6
	for i in n:
		var a := start + TAU * float(i) / float(maxi(n, 1)) * 0.55
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


# --- the frame --------------------------------------------------------------------------------------

var perf_us := 0.0                  ## this node's script time a frame (µs, eased; the people's own villager.gd is apart)


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame(dt)
	perf_us = lerpf(perf_us, float(Time.get_ticks_usec() - t0), 0.02)


func _frame(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_cam = cam.global_position
	var k := 1.6 if _tide else 1.0
	for p: Dictionary in parties:
		if bool(p.near):
			continue
		match int(p.state):
			WALK, FLEE:
				p.s = float(p.s) + float(p.dir) * float(p.speed) * k * dt
				if float(p.s) >= _len(p) or float(p.s) <= 0.0:
					_arrive(p)
			REST, AWAY, HALT:
				p.t = float(p.t) - dt
				if float(p.t) <= 0.0:
					_leave(p)
	_t10 -= dt
	if _t10 <= 0.0:
		_t10 = 0.1
		_lamps_step()
	_t4 -= dt
	if _t4 <= 0.0:
		_t4 = 0.25
		for p: Dictionary in parties:
			_lod(p)
			if bool(p.near):
				_drive(p, 0.25)


func _leave(p: Dictionary) -> void:
	var from: Vector2 = havens[int(p.at)].at
	if bool(p.near) and not (p.people as Array).is_empty():
		var lp: Vector3 = (p.people[0] as Node3D).global_position
		from = Vector2(lp.x, lp.z)
		for v: VillagerScript in p.people:
			v.release()
	if not _depart(p, from):
		p.state = REST
		p.t = 20.0
	elif bool(p.near):
		_walkers(p)


## Made real near the camera, put away beyond it.
func _lod(p: Dictionary) -> void:
	var at := _lead_xz(p)
	var d := Vector2(_cam.x, _cam.z).distance_to(at)
	if not bool(p.near) and d < NEAR_ON and int(p.state) != AWAY:
		_show_people(p)
	elif bool(p.near) and (d > NEAR_OFF or int(p.state) == AWAY):
		if int(p.state) in [WALK, FLEE]:
			p.s = _project(p, at, float(p.s))
		elif int(p.state) == HALT:
			p.s = _project(p, at, float(p.s))
			p.state = WALK                       # (a greeting or a stand, left behind: on along the way)
		_hide_people(p)


func _lead_xz(p: Dictionary) -> Vector2:
	if bool(p.near) and not (p.people as Array).is_empty():
		var lp: Vector3 = (p.people[0] as Node3D).global_position
		return Vector2(lp.x, lp.z)
	if int(p.state) in [WALK, FLEE]:
		return _pos(p, float(p.s))
	var spots: Array = p.spots
	return spots[0] if not spots.is_empty() else havens[int(p.at)].at


func _show_people(p: Dictionary) -> void:
	p.near = true
	var gap := float(p.spec.gap)
	var i := 0
	for v: VillagerScript in p.people:
		var q := Vector2.ZERO
		if int(p.state) in [WALK, FLEE]:
			q = _pos(p, float(p.s) - float(p.dir) * gap * float(i))
		else:
			var spots: Array = p.spots
			q = spots[i] if i < spots.size() else _lead_xz(p)
		v.global_position = Vector3(q.x, village.nav.floor_at(q.x, q.y), q.y)
		v.visible = true
		v.process_mode = Node.PROCESS_MODE_INHERIT
		v.body.collision_layer = Layers.PROPS
		v.release()
		v.hurry = 1.0
		i += 1
	if int(p.state) in [WALK, FLEE]:
		_walkers(p)
	else:
		_settle(p, true)


func _hide_people(p: Dictionary) -> void:
	p.near = false
	for v: VillagerScript in p.people:
		v.release()
		v.visible = false
		v.process_mode = Node.PROCESS_MODE_DISABLED
		if v.body != null:
			v.body.collision_layer = 0           # an unseen traveller is not a wall in the road


## Walking: the leader after a point AHEAD on the way, the rest after the one in front of them.
func _walkers(p: Dictionary) -> void:
	var people: Array = p.people
	var hurry := 1.9 if int(p.state) == FLEE else (1.5 if _tide else 1.0)
	for i in people.size():
		var v: VillagerScript = people[i]
		v.pinned = false
		v.speed = float(p.speed) / 1.2 * (1.0 if i == 0 else 1.15)
		v.hurry = hurry
		if i > 0:
			v.follow = people[i - 1]
			v.follow_gap = float(p.spec.gap)
			v.follow_wait_r = 1.0e9          # (an escort waits for the wanderer; a traveller who fell behind catches up)
	_lead_on(p)


func _lead_on(p: Dictionary) -> void:
	var lead: VillagerScript = p.people[0]
	var q := _pos(p, float(p.s) + float(p.dir) * AHEAD)
	lead.follow = Vector3(q.x, lead.global_position.y, q.y)


## At a fire or a post: each walks to their spot round it and, there, holds the party's act facing it.
func _settle(p: Dictionary, snap := false) -> void:
	var spots: Array = p.spots
	var h: Dictionary = havens[int(p.at)]
	var c: Vector2 = h.at
	var i := 0
	for v: VillagerScript in p.people:
		var q: Vector2 = spots[i] if i < spots.size() else c
		if snap:
			v.global_position = Vector3(q.x, village.nav.floor_at(q.x, q.y), q.y)
		var there := snap or v.global_position.distance_to(Vector3(q.x, v.global_position.y, q.y)) < 0.6
		if there and String(p.act) != "":
			if not (v.pinned and v.act == String(p.act)):
				v.hold(String(p.act), Vector3(c.x, v.global_position.y, c.y))
		elif not there and not v.pinned:
			v.follow = Vector3(q.x, v.global_position.y, q.y)
		i += 1


## A near party, four times a second: the leader's point on the way, arrival, the wanderer, danger, the rest's end.
func _drive(p: Dictionary, dt: float) -> void:
	var people: Array = p.people
	var lead: VillagerScript = people[0]
	var lp := lead.global_position
	var foe := _nearest_foe(people)
	var fd := lp.distance_to(foe) if foe != Vector3.INF else INF
	var player := _player()
	p.greet_t = maxf(0.0, float(p.greet_t) - dt)
	match int(p.state):
		WALK, FLEE:
			p.s = _project(p, Vector2(lp.x, lp.z), float(p.s))
			if fd < SEE_R:
				_frighten(p, foe)
				if int(p.state) == HALT:
					return
			elif int(p.state) == FLEE:
				p.calm_t = float(p.calm_t) + dt
				if fd > CALM_R and float(p.calm_t) > CALM_T:
					p.state = WALK                   # (turned back, they still go back the way they came)
					_walkers(p)
			if (float(p.dir) > 0.0 and float(p.s) >= _len(p) - 1.2) or (float(p.dir) < 0.0 and float(p.s) <= 1.2):
				_arrive(p)
				return
			# the wanderer close and in front: the leader stops, turns to her and says a few words
			if int(p.state) == WALK and player != Vector3.INF and float(p.greet_t) <= 0.0 and lp.distance_to(player) < GREET_R:
				p.greet_t = 40.0
				greets += 1
				lead.hold("watch" if String(p.kind) == "patrol" else "idle", player)
				_say(lead, 3, false)
				p.state = HALT
				p.t = 2.4
				return
			_lead_on(p)
		REST:
			if fd < SEE_R:
				_frighten(p, foe)
				return
			_settle(p)
			p.t = float(p.t) - dt
			if float(p.t) <= 0.0:
				_leave(p)
			elif String(p.act) in ["warm", "chat"] and _rng.randf() < dt / 9.0:
				_say(people[_rng.randi_range(0, people.size() - 1)] as VillagerScript, _rng.randi_range(2, 4), _rng.randf() < 0.3)
		HALT:
			p.t = float(p.t) - dt
			if fd < SEE_R * 0.5 and not bool(p.spec.stand):
				_frighten(p, foe)
			elif float(p.t) <= 0.0 and fd > SEE_R:
				for v: VillagerScript in people:
					v.release()
				p.state = WALK
				_walkers(p)


## Something hollowed is near: a patrol (when it is not yet close) halts and faces it; the others turn back to where
## they came from if it is ahead of them, or hurry on if it is behind.
func _frighten(p: Dictionary, foe: Vector3) -> void:
	var lead: VillagerScript = p.people[0]
	p.calm_t = 0.0
	if bool(p.spec.stand) and lead.global_position.distance_to(foe) > 9.0:
		if int(p.state) != HALT:
			for v: VillagerScript in p.people:
				v.hold("watch", foe)
			_say(lead, 2, false, 3.0)
		p.state = HALT
		p.t = 3.0
		return
	if int(p.state) == FLEE:
		return
	flights += 1
	var ahead := _pos(p, float(p.s) + float(p.dir) * 6.0)
	var lp := lead.global_position
	var to_foe := Vector2(foe.x - lp.x, foe.z - lp.z)
	var fwd := ahead - Vector2(lp.x, lp.z)
	if int(p.state) == REST:
		# resting: they go back the way they came (a way of their own back to where they were before)
		var from := Vector2(lp.x, lp.z)
		var prev: int = p.at
		if _depart(p, from):
			p.state = FLEE
			p.at = prev
		else:
			return
	elif to_foe.dot(fwd) > 0.0:
		p.dir = -float(p.dir)
	p.state = FLEE
	for v: VillagerScript in p.people:
		v.release()
	_walkers(p)
	_say(lead, 2, true, 4.0)


func _nearest_foe(people: Array) -> Vector3:
	if director == null:
		return Vector3.INF
	var foes: Array[Vector3] = director.near_enemies()
	var best := Vector3.INF
	var bd := INF
	for f in foes:
		for v: Node3D in people:
			var d := f.distance_squared_to(v.global_position)
			if d < bd:
				bd = d
				best = f
	return best


func _player() -> Vector3:
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return pl.global_position if pl != null else Vector3.INF


func _say(v: VillagerScript, n: int, question: bool, vol := 0.0) -> void:
	if v.global_position.distance_to(_cam) > 22.0:
		return
	var sp: Node = v.get_node_or_null("Voice")
	if sp == null:
		sp = Voice.speaker3d(v, 24.0)
	Voice.say(sp, v.voice, n, 0.6, question, vol - 6.0)


# --- lanterns ---------------------------------------------------------------------------------------

func _lamps() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = LifeKit.mesh("firefly")
	mm.instance_count = DB.PARTIES.size()
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -500, 0)))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	mm.custom_aabb = AABB(Vector3(-400, -60, -200), Vector3(800, 160, 640))
	lamps = MultiMeshInstance3D.new()
	lamps.name = "WayLamps"
	lamps.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = LAMP_SH
	lamps.material_override = mat
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamps.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lamps.add_to_group(Groups.CULL_SKIP)
	lamps.set_meta("chunked", true)
	add_child(lamps)


func _lamps_step() -> void:
	var mm := lamps.multimesh
	for i in parties.size():
		var p: Dictionary = parties[i]
		var li: int = p.lamp_i
		if li >= mm.instance_count:
			continue
		if int(p.state) == AWAY:
			mm.set_instance_custom_data(li, Color(0, 0, 0, 0))
			continue
		var q := _lead_xz(p)
		var y := RL.height_at(q.x, q.y)
		if bool(p.near):
			y = (p.people[0] as Node3D).global_position.y
		mm.set_instance_transform(li, Transform3D(Basis.IDENTITY, Vector3(q.x, y + 1.05, q.y)))
		mm.set_instance_custom_data(li, Color(1.0, float(p.phase), 1.0 if int(p.state) in [WALK, FLEE] else 0.0, 0.0))


# --- census -----------------------------------------------------------------------------------------

func census() -> Dictionary:
	var out := {}
	for p: Dictionary in parties:
		var q := _lead_xz(p)
		var rid := String(RealmLayout.region_at(q.x, q.y).get("id", "?"))
		if not out.has(rid):
			out[rid] = {}
		var d: Dictionary = out[rid]
		var key := "away" if int(p.state) == AWAY else "wayfarers"
		d[key] = int(d.get(key, 0)) + (p.people as Array).size()
	return out

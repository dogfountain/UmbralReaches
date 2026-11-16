extends Node3D
## The living world's conductor (life system, docs/LIFE_PLAN.md). Built once by wildlife.gd after the
## Realm modules: places every group from what the Realm built (life_place.gd), owns the weather,
## and each frame ticks only the groups near the camera (far ones are hidden and frozen; idle groups
## past 16 m update at 20 Hz, 10 Hz past 60 m). Shader-only flocks (moths round flames, fireflies, bats) cost no
## script time at all. Listens to the game's events: spells, kills, hurts, boss fights and thunder
## frighten what is near; a newly kindled brazier gets its moths.
##
## Read-only for other systems: this node is "Wildlife" under the zone root, meta "weather" holds the
## Weather node (state {mist, rain, wind, thunder}, front, `thundered` signal).

const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const Birds := preload("res://core/life/wildlife/life_birds.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")
const Pond := preload("res://core/life/wildlife/life_pond.gd")
const WeatherScript := preload("res://core/life/wildlife/weather.gd")
const Flock := preload("res://core/life/wildlife/life_flock.gd")
const TracksScript := preload("res://core/life/wildlife/tracks.gd")
const PhenomenaScript := preload("res://core/life/wildlife/phenomena.gd")
const RL := preload("res://core/world/realm/realm_land.gd")
const Marches := preload("res://core/life/wildlife/life_marches.gd")
const Settle := preload("res://core/life/wildlife/life_settle.gd")
const Reaches := preload("res://core/life/wildlife/life_reaches.gd")       ## the Far Reaches' rosters (docs/living_realm.md)
const Signs := preload("res://core/life/wildlife/life_signs.gd")           ## carrion, raven kettles, marsh lights, eyes, howls

const NEAR_R := 16.0
const OUT_TICK := 0.2                    ## logic interval for groups out of the camera's view
## A herd on the move in view under 45 m ticks every frame instead of 30/7.5 Hz with interpolation
## (r30 option, off: the interpolation over the next interval already draws it without pops, and
## every frame cost ~60-90 us a frame for a fleeing herd in lifeprof). Tools can switch it on.
static var herd_every_frame := false
const BUILD_SEED := 4127

var root: Node
var weather: Node3D
var tracks: MultiMeshInstance3D         ## prints and signs (tracks.gd)
var phenomena: Node3D                   ## meteors, rift surges, wisps, the white hart (phenomena.gd)
var off := false                        ## --scape-off: the r23 wildlife only (perf A/B)
var groups: Array = []                   ## life_group.gd nodes
var moths := {}                          ## OmniLight3D -> MultiMeshInstance3D
var fireflies: Array[MultiMeshInstance3D] = []
var bats: Array[MultiMeshInstance3D] = []
var rats: Node3D                         ## the Ossuary's rats (built while the crypt is loaded)
var signs: Node3D                        ## life_signs.gd
var counts := {}                         ## kind -> creatures placed (tests, report)
var kind_us := {}                        ## accumulated tick time per kind (profiling)
var perf_us := 0.0                       ## mean script time per frame (µs), this node + weather
var perf_p50 := 0.0                      ## its median, 90th percentile and worst over the same 120 frames
var perf_p90 := 0.0
var perf_max := 0.0
var _perf_ring := PackedFloat32Array()
var quiet := false                       ## tests: no calls
var tide := false                        ## encounters' Gloom tide is up: the wild goes still
var glide := true                        ## moving groups redrawn between ticks (--no-glide: A/B)

var _rng := RandomNumberGenerator.new()
var _rng2 := RandomNumberGenerator.new()   ## r28 additions draw from their own stream: r23 placement is unchanged
var _rng3 := RandomNumberGenerator.new()   ## the Marches' and the downs' placements: the old Realm's streams are untouched
var _frame := 0
var _enemy_t := 0.0
var _enemies: Array[Vector3] = []
var _last_player := Vector3.INF
var _player_speed := 0.0
var _acc := PackedFloat32Array()         ## per group (index in `groups`): accumulated dt (far groups)
var _gc := PackedVector3Array()          ## per group: center (fixed after placement), cached:
var _gr := PackedFloat32Array()          ## per group: active_r   a by-name get() per group per frame cost more
var _rescan_t := 3.0
var _act := PackedInt32Array()          ## groups within their reach (visited every frame)
var _scan_t := 0.0
var _scan_cp := Vector3.INF
var _kid := PackedInt32Array()          ## per group: its kind's index in _knames
var _knames: Array[String] = []
var _kacc := PackedFloat32Array()       ## this frame's script time per kind (folded into kind_us)
var _kgl := PackedFloat32Array()        ## ...of which gliding (kind_glide_us)
var kind_glide_us := {}                 ## the part of kind_us spent redrawing between ticks
var _herd := PackedByteArray()          ## per group: 1 if it carries its node with it (herds)
var _oss_t := 1.0
var _oss_wait := -1.0
var _perf_acc := 0.0
var _perf_n := 0
var _wx_last := {}
var _time := 0.0
var _arriving: Array = []               ## [moth MultiMeshInstance3D, k] finding a new flame
var _kindle_wait: Array = []            ## [brazier, seconds left] waiting for its flame to grow
var _kindle_t := 0.0


func setup(r: Node) -> void:
	var t_setup := Time.get_ticks_msec()
	root = r
	name = "Wildlife"
	_rng.seed = BUILD_SEED
	_rng2.seed = BUILD_SEED + 2
	_rng3.seed = BUILD_SEED + 3
	LifePlace.pool_cache.clear()                # (this build's pools are found once and shared)
	var space := get_world_3d().direct_space_state
	weather = WeatherScript.new()
	add_child(weather)
	weather.setup(root, BUILD_SEED + 1)
	weather.thundered.connect(_on_thunder)
	set_meta("weather", weather)
	off = "--scape-off" in OS.get_cmdline_user_args()
	glide = "--no-glide" not in OS.get_cmdline_user_args()
	if not off:
		tracks = TracksScript.new()
		add_child(tracks)
	_place_moths()
	Settle.moths(self, root, counts)
	_place_pools(space)
	_place_pools(space, true)
	_place_crows(space)
	Settle.rats(self, space, _add_group, counts)
	_place_owls(space)
	_place_owls(space, true)
	_place_herds(space)
	_place_fireflies()
	_place_bats()
	_place_elk(space)
	if not off:
		_place_flocks()
		if "--no-life-reaches" not in OS.get_cmdline_user_args():          # perf A/B: the rosters and signs off
			Reaches.place(self, root, space, _add_group)
			signs = Signs.new()
			add_child(signs)
			signs.setup(self, root, space, _add_group)
		phenomena = PhenomenaScript.new()
		add_child(phenomena)
		phenomena.setup(self, weather, BUILD_SEED + 5)
		set_meta("phenomena", phenomena)
	for e in [["skill_cast", _on_skill], ["enemy_killed", _on_kill], ["player_hurt", _on_hurt], ["boss_engaged", _on_boss], ["brazier_kindled", _on_kindled], ["gloom_tide", _on_tide]]:
		if Events.has_signal(e[0]):
			Events.connect(e[0], e[1])
	print("LIFE placed in %d ms: %s" % [Time.get_ticks_msec() - t_setup, counts])


## The hollowed things near the camera (refreshed twice a second).
func near_enemies() -> Array[Vector3]:
	return _enemies


func _add_group(g: Node3D) -> void:
	add_child(g)
	groups.append(g)
	_gc.resize(0)
	g.visible = false
	g.space = get_world_3d().direct_space_state
	g.tracks = tracks
	counts[g.kind] = int(counts.get(g.kind, 0)) + g.positions().size()


# --- placement --------------------------------------------------------------------------------------

func _place_moths() -> void:
	for l in LifePlace.moth_lights(root):
		if not _unlit(l):
			_moths_for(l)


## A light whose brazier is not kindled yet: no moths until it is (they come when it is lit).
func _unlit(l: Node) -> bool:
	var n := l.get_parent()
	while n != null and n != root:
		if n is Brazier:
			return not (n as Brazier).lit
		n = n.get_parent()
	return false


func _moths_for(l: OmniLight3D) -> void:
	if moths.has(l):
		return
	var n := clampi(int(4.0 + l.light_energy * 2.5), 4, 10)
	var g := LifeKit.group("moth", n)
	g.name = "Moths"
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(l.get_path()))
	for i in n:
		g.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, r.randf_range(-0.15, 0.25), 0)))
		var sp := r.randf_range(1.6, 3.6) * (1.0 if r.randf() < 0.5 else -1.0)
		g.multimesh.set_instance_custom_data(i, Color(r.randf_range(0.3, 1.0), sp, r.randf_range(0.12, 0.4), r.randf_range(0.0, TAU)))
	g.multimesh.custom_aabb = AABB(Vector3(-1.8, -1.0, -1.8), Vector3(3.6, 2.2, 3.6))
	g.visibility_range_end = 30.0
	g.visibility_range_end_margin = 4.0
	add_child(g)
	g.global_position = l.global_position + Vector3(0, 0.15, 0)
	moths[l] = g
	counts["moth"] = int(counts.get("moth", 0)) + n


func _place_pools(space: PhysicsDirectSpaceState3D, new_ground := false) -> void:
	var pools := LifePlace.pools(new_ground)
	var heron_perches: Array = []
	var pr := _rng3 if new_ground else _rng         # the Marches' pools shuffle from their own stream
	var made := 0
	for pi in pools.size():
		var p: Dictionary = pools[pi]
		if int(p.n) < 3 or made >= (6 if new_ground else 12):              # r34 flora: was 9 (the mere's pools came after the fen's); the Marches' six more
			continue
		# r34 merge: a chorus 22 m from a camp is never heard (the pond falls silent with a hollowed
		# thing within 22 m and camps respawn): keep the frog pools 26 m+ off every camp
		var pc: Vector2 = p.center
		var by_camp := false
		for camp: Dictionary in EnemySpawner.REALM_CAMPS:
			var cat: Vector3 = camp.at
			if pc.distance_to(Vector2(cat.x, cat.z)) < 26.0:
				by_camp = true
				break
		if by_camp:
			continue
		var edge: Array = (p.edge as Array).duplicate()
		LifePlace.shuffle(edge, pr)
		var spots: Array[Vector3] = []
		for e: Vector2 in edge:
			if spots.size() >= clampi(int(p.n) / 4 + 3, 3, 8):
				break
			var ok := true
			for s in spots:
				if Vector2(s.x, s.z).distance_to(e) < 1.3:
					ok = false
					break
			if not ok:
				continue
			var gy := LifePlace.ground(space, e.x, e.y)
			var wy := RL.water_y_at(e.x, e.y)                 # the river's reaches stand at their own levels
			if gy > wy + 1.2 or gy < wy - 0.05:
				continue
			spots.append(Vector3(e.x, gy, e.y))
		var g := Pond.new()
		g.name = ("PondM%d" if new_ground else "Pond%d") % made
		g.setup(p, spots, BUILD_SEED + 31 * pi)
		_add_group(g)
		counts["frog"] = int(counts.get("frog", 0)) + spots.size()
		made += 1
		# herons: two spots on each of the bigger pools' banks, facing the water
		if pi < (3 if new_ground else 6) and edge.size() >= 4:
			for k in 2:
				var e: Vector2 = edge[(k * edge.size()) / 2]
				var w := LifePlace.nearest_water(p, e)
				var gy := LifePlace.ground(space, e.x, e.y)
				if gy < RL.WATER_Y + 0.9:
					heron_perches.append([Vector3(e.x, gy, e.y), Birds.yaw_to(Vector3(w.x - e.x, 0, w.y - e.y))])
	if heron_perches.size() >= 3:
		LifePlace.shuffle(heron_perches, pr)
		var h := Birds.new()
		h.name = "HeronsM" if new_ground else "Herons"
		h.setup("heron", heron_perches, 2, BUILD_SEED + (8 if new_ground else 7))
		_add_group(h)


func _place_crows(space: PhysicsDirectSpaceState3D) -> void:
	var roosts := LifePlace.crow_roosts(root, space, _rng)
	var i := 0
	for r: Dictionary in roosts:
		var per: Array = r.perches
		var n := clampi(per.size() - 2, 3, 6 if String(r.name) == "henge" else 4)
		var g := Birds.new()
		g.name = "Crows_" + String(r.name)
		g.setup("crow", per, n, BUILD_SEED + 101 * i)
		_add_group(g)
		if tracks != null:
			for k in 2:
				var pe: Array = per[_rng2.randi() % per.size()]
				var b: Vector3 = pe[0]
				tracks.print_at(Vector3(b.x + _rng2.randf_range(-1.5, 1.5), 0, b.z + _rng2.randf_range(-1.5, 1.5)), _rng2.randf_range(-PI, PI), 3, INF)
		i += 1


func _place_owls(space: PhysicsDirectSpaceState3D, new_ground := false) -> void:
	# the old Realm's owls from the old streams; the Marches' from the third (up to 8 more areas)
	var ra := _rng3 if new_ground else _rng
	var rb := _rng3 if new_ground else _rng2
	var trunks := LifePlace.trunks(root, ["oldforest", "ruin", "glade"], 0.32, new_ground)
	trunks.append_array(LifePlace.trunks(root, ["fen"], 0.22, new_ground))
	LifePlace.shuffle(trunks, ra)
	# areas of ~55 m: each with a few trees to sit in and one or two owls
	var areas := {}
	for t: Dictionary in trunks:
		var b: Vector3 = t.base
		if RealmLayout.path_dist(Vector2(b.x, b.z)) < 1.5:
			continue
		var cell := Vector2i(floori(b.x / 55.0), floori(b.z / 55.0))
		if not areas.has(cell):
			areas[cell] = []
		var lst: Array = areas[cell]
		var spaced := true
		for o: Dictionary in lst:
			if (o.base as Vector3).distance_to(b) < 14.0:
				spaced = false
				break
		if spaced and lst.size() < 6:
			lst.append(t)
	var ai := 0
	for cell: Vector2i in areas:
		var lst: Array = areas[cell]
		if lst.size() < 3 or ai >= 8:
			continue
		var perches: Array = []
		var xfs: Array = []
		for t: Dictionary in lst:
			var b: Vector3 = t.base
			var r: float = t.r
			# the branch faces the nearest path (owls watch the walkers)
			var dir := _toward_path(Vector2(b.x, b.z), ra)
			var h := ra.randf_range(2.9, 3.8)
			var root_p := b + Vector3(dir.x, 0, dir.y) * r * 0.7 + Vector3(0, h, 0)
			var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x))
			var xf := Transform3D(basis, root_p)
			# keep it clear of the ground and not inside another solid
			var perch := xf * Vector3(1.1, 0.13, 0.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(perch + Vector3(0, 0.6, 0), perch + Vector3(0, 0.02, 0), 1))
			if not hit.is_empty():
				continue
			xfs.append(xf)
			var side := Vector3(-dir.y, 0, dir.x)       # along the trunk's tangent, toward open ground
			if side.dot(Vector3(dir.x, 0, dir.y)) < 0.0:
				side = -side
			perches.append([perch, Birds.yaw_to(side if ra.randf() < 0.5 else -side)])
		if perches.size() < 3:
			continue
		# field mice in the open ground under the trees (the owls' hunting)
		var prey: Array[Vector3] = []
		if not off:
			for pe: Array in perches:
				var b: Vector3 = pe[0]
				for k in 6:
					if prey.size() >= 5:
						break
					var a := rb.randf_range(0.0, TAU)
					var q := Vector2(b.x, b.z) + Vector2(cos(a), sin(a)) * rb.randf_range(6.0, 14.0)
					if LifePlace.open_ground(q.x, q.y) and RealmLayout.path_dist(q) > 2.0 and not RL.in_water(q.x, q.y):
						prey.append(Vector3(q.x, RL.height_at(q.x, q.y), q.y))
						break
		var g := Birds.new()
		g.name = ("OwlsM%d" if new_ground else "Owls%d") % ai
		g.setup("owl", perches, 1 + int(perches.size() >= 5), BUILD_SEED + 211 * ai + (7000 if new_ground else 0), xfs, prey)
		_add_group(g)
		# pellets and a moulted feather under the trees they sit in
		if tracks != null:
			for pe: Array in perches:
				var b: Vector3 = pe[0]
				var u := Vector3(b.x + rb.randf_range(-0.8, 0.8), 0, b.z + rb.randf_range(-0.8, 0.8))
				tracks.print_at(u, rb.randf_range(-PI, PI), 4, INF)
				if rb.randf() < 0.5:
					tracks.print_at(u + Vector3(rb.randf_range(-1, 1), 0, rb.randf_range(-1, 1)), rb.randf_range(-PI, PI), 3, INF)
		ai += 1


func _toward_path(p: Vector2, rng: RandomNumberGenerator = null) -> Vector2:
	var best := Vector2.RIGHT
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var q := a + ab * t
			var d := p.distance_to(q)
			if d < bd and d > 0.01:
				bd = d
				best = (q - p) / d
	if bd > 60.0:
		var ang := (rng if rng != null else _rng).randf_range(0.0, TAU)
		best = Vector2(cos(ang), sin(ang))
	return best


func _place_herds(space: PhysicsDirectSpaceState3D) -> void:
	# r31: the herds draw from their own seed, so a place built elsewhere in the valley (which shifts
	# how many numbers the owls, crows and plovers draw first) does not reshuffle where they graze
	var hrng := RandomNumberGenerator.new()
	hrng.seed = BUILD_SEED + 1
	var edges := LifePlace.forest_edges(hrng)
	LifePlace.shuffle(edges, hrng)
	# r30: grazers keep 30 m from every camp (Deer1 grazed between the Keg and the rift-rim camp), and
	# the Thornwood, the largest region, gets its herds first: clearings under its trees
	var camps: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		camps.append(Vector2((c.at as Vector3).x, (c.at as Vector3).z))
	var thornwood := Rect2(-150, -66, 120, 111)        # r34 layout: RealmLayout REGIONS "thornwood" (was -110, -70, 80, 115)
	var wood: Array[Vector3] = []
	var rest: Array[Vector3] = []
	for e in edges:
		var far := true
		# r34 layout: not on the rim of a raid floor (RealmLayout.RAIDS): the open ring round the henge's
		# floor read as a clearing, and half of a herd's grazing spots fell on the floor itself
		for rd: Dictionary in RealmLayout.RAIDS:
			if Vector2(e.x, e.z).distance_to(rd.c) < float(rd.r) + 14.0:
				far = false
		for c in camps:
			if c.distance_to(Vector2(e.x, e.z)) < 30.0:
				far = false
				break
		if not far:
			continue
		if thornwood.has_point(Vector2(e.x, e.z)) and LifePlace.Flora.cover_at(e.x, e.z) < 0.12:
			wood.append(e)
		else:
			rest.append(e)
	var herds: Array[Vector3] = []
	for pass_i in 2:
		var pool: Array[Vector3] = wood.duplicate()
		if pass_i == 1:
			pool.append_array(rest)
		for e: Vector3 in pool:
			var ok := true
			for h in herds:
				if h.distance_to(e) < 45.0:
					ok = false
					break
			if ok:
				herds.append(e)
			if herds.size() >= (2 if pass_i == 0 else 6):     # r34 flora: twice the ground (was 4)
				break
	# no deer herds (Luke, 14 Nov: "we can get rid of deer, they suck"). The foxes, hares and the elk stay, and the
	# white hart is its own event (phenomena.gd). `-- --deer` brings the herds back for the tools that film them.
	if "--deer" in OS.get_cmdline_user_args():
		Marches.make_herds(_add_group, space, herds, hrng, 0, "Deer%d", 0)
		Marches.herds(_add_group, space, camps, BUILD_SEED)
	_place_foxes_and_hares(space, camps)


func _place_foxes_and_hares(space: PhysicsDirectSpaceState3D, camps: Array[Vector2]) -> void:
	# foxes: the village's edge gardens (r30: not the green), the chapel's graves, the road verge
	# A fox counts an enemy at 1.9x its distance inside a 26 m alert radius, so a camp within ~50 m keeps
	# it on its guard for good: it never hunts (r30 merge: the verge foxes stood beside the road camp).
	# the green's edge first: in the village's light no hollowed walk, so one fox at least can hunt
	# (the first two foxes may settle short of the clearance when none is clear: a fox on watch still
	# lives; the green's fox hunts)
	var fox_at: Array[Vector2] = [Vector2(14, 40), Vector2(32, 48), Vector2(-64, 34), Vector2(-24, 60), Vector2(20, 62), Vector2(10, 20), Vector2(-50, -10)]
	var keep_off := camps.duplicate()
	for el: Dictionary in (load("res://core/life/encounters/elites.gd").ELITES as Dictionary).values():
		for h: Vector2 in el.get("haunt", []):
			keep_off.append(h)                       # an elite walks its haunt: as bad as a camp
	# then anywhere in the realm that is clear: a scan for open ground 52 m from camps and haunts
	var scan: Array[Vector2] = []
	var ob: Rect2 = RealmLayout.OLD_BOUNDS            # the old Realm's scan as it was; the Marches follow below
	var gy := ob.position.y + 6.0
	while gy < ob.end.y - 6.0:
		var gx := ob.position.x + 6.0
		while gx < ob.end.x - 6.0:
			var q0 := Vector2(gx, gy)
			var ok := true
			for cp in keep_off:
				if cp.distance_to(q0) < 60.0:
					ok = false
					break
			if ok:
				scan.append(q0)
			gx += 12.0
		gy += 12.0
	LifePlace.shuffle(scan, _rng)
	fox_at.append_array(scan)
	var fi := 0
	var placed: Array[Vector2] = []
	for c in fox_at:
		var spaced := true
		for pq in placed:
			if pq.distance_to(c) < 40.0:
				spaced = false
		if not spaced:
			continue
		var found := false
		for k in 40:
			var q := c + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18))
			var clear := true
			for cp in keep_off:
				if cp.distance_to(q) < 52.0:
					clear = false
					break
			if (clear or (fi <= 1 and k >= 20)) and LifePlace.open_ground(q.x, q.y) and RealmLayout.path_dist(q) > 2.5:
				var spots: Array[Vector3] = [Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y)]
				var g := Beasts.new()
				placed.append(q)
				g.name = "Fox%d" % fi
				g.setup("fox", spots, BUILD_SEED + 401 * fi)
				_add_group(g)
				fi += 1
				found = true
				break
		if found and fi >= 5:                       # r34 flora: twice the ground (was 3)
			break
	Marches.foxes(_add_group, space, keep_off, _rng3, BUILD_SEED)
	_place_hares(space, keep_off)


## r33 world: brown hares on the open heath and the road's verges, two or three to a form, well
## off the camps (a camp in sight keeps a hare on watch for good) and off the paths.
func _place_hares(space: PhysicsDirectSpaceState3D, keep_off: Array) -> void:
	var hrng := RandomNumberGenerator.new()
	hrng.seed = BUILD_SEED + 733
	# the open ground farthest from every camp and elite haunt (scanned r33): the road's south verge,
	# the meadow between Hearthward and the fen, the fen's west rim. Not the Thornwood: that is the
	# deer's, and a hare bolting past a herd sets it running too
	var want: Array[Vector2] = [Vector2(6.0, 68.0), Vector2(36.0, 36.0), Vector2(36.0, -44.0),
		# r34 flora: the Lanternless Moor's heather, the Waiting Field's grass, the Rooted Holds' clearing
		Vector2(146.0, 2.0), Vector2(30.0, 140.0), Vector2(-134.0, 6.0)]
	var hi := 0
	for c in want:
		var spots: Array[Vector3] = []
		for k in 40:
			if spots.size() >= 2 + (hi % 2):
				break
			var q := c + Vector2(hrng.randf_range(-9.0, 9.0), hrng.randf_range(-7.0, 7.0))
			var clear := true
			for cp: Vector2 in keep_off:
				if cp.distance_to(q) < 20.0:
					clear = false
					break
			if not clear or not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 2.0:
				continue
			var near := false
			for s0 in spots:
				if Vector2(s0.x, s0.z).distance_to(q) < 1.5:
					near = true
			if not near:
				spots.append(Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y))
		if spots.size() < 2:
			continue
		var g := Beasts.new()
		g.name = "Hare%d" % hi
		g.setup("hare", spots, BUILD_SEED + 517 * hi)
		_add_group(g)
		hi += 1
		if hi >= 6:
			break
	var hj := Marches.hares(_add_group, space, keep_off, BUILD_SEED)
	print("LIFE hares: %d forms (+%d in the Marches)" % [hi, hj])


## The great elk: on the most prominent open rise west of the Thornwood or out on the heath.
func _place_elk(space: PhysicsDirectSpaceState3D) -> void:
	var best := Vector3.INF
	var best_s := -INF
	# r34 flora: the whole doubled Realm south of the Crowns (was x -104..104, z -66..72); off the raid
	# floors and the camps (the moor's tor is now the highest open rise)
	var bb := RealmLayout.BOUNDS.grow(-8.0)
	var camps: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		camps.append(Vector2((c.at as Vector3).x, (c.at as Vector3).z))
	var x := bb.position.x
	while x <= bb.end.x:
		var z := -66.0
		while z <= bb.end.y:
			var clear := not Rect2(-48, -130, 96, 125).has_point(Vector2(x, z)) and Vector2(x, z).distance_to(RealmLayout.HENGE_C) > 28.0
			for rd: Dictionary in RealmLayout.RAIDS:
				if Vector2(x, z).distance_to(rd.c) < float(rd.r) + 10.0:
					clear = false
			for c in camps:
				if c.distance_to(Vector2(x, z)) < 30.0:
					clear = false
			if clear and LifePlace.Flora.cover_at(x, z) < 0.08 and LifePlace.Flora.cover_at(x + 9, z) < 0.3 and LifePlace.Flora.cover_at(x - 9, z) < 0.3 and LifePlace.open_ground(x, z) and RealmLayout.path_dist(Vector2(x, z)) > 6.0 and Vector2(x, z).distance_to(Vector2(6, 38)) > 45.0:
				var h := RL.height_at(x, z)
				var ring := 0.0
				for k in 8:
					var a := float(k) / 8.0 * TAU
					ring += RL.height_at(x + cos(a) * 18.0, z + sin(a) * 18.0)
				var s := h - ring / 8.0 + h * 0.15
				if s > best_s:
					best_s = s
					best = Vector3(x, h, z)
			z += 6.0
		x += 6.0
	if best == Vector3.INF:
		return
	var spot: Array[Vector3] = [Vector3(best.x, LifePlace.ground(space, best.x, best.z), best.z)]
	var g := Beasts.new()
	g.name = "GreatElk"
	g.setup("elk", spot, BUILD_SEED + 999)
	_add_group(g)


## Lapwing flocks: out on the heath along the Pilgrims' Road, and on the open ground east of Hearthward.
func _place_flocks() -> void:
	var wanted: Array[Vector2] = [Vector2(-40, 66), Vector2(58, 68), Vector2(40, 30), Vector2(-78, 66), Vector2(80, 60), Vector2(-20, 66),
		Vector2(140, 10), Vector2(24, 120), Vector2(-96, 140)]    # r34 flora: the moor, the Waiting Field, the orchard's south rows
	var placed: Array[Vector2] = []
	var old_flocks := wanted.size()
	# the downs and the Marches' open ground (the first five are as ever; up to four more here, from the third stream)
	wanted.append_array([Vector2(-110, 205), Vector2(20, 210), Vector2(120, 206), Vector2(-232, 36), Vector2(190, 56)])
	for wi in wanted.size():
		var c: Vector2 = wanted[wi]
		if placed.size() >= 9:
			break
		if wi < old_flocks and placed.size() >= 5:
			continue
		for k in 40:
			var q := c + Vector2(_rng2.randf_range(-16, 16), _rng2.randf_range(-10, 10))
			if not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 4.0:
				continue
			var ok := true
			for o in placed:
				if o.distance_to(q) < 40.0:
					ok = false
			for dx: float in [-3.0, 3.0]:
				for dz: float in [-3.0, 3.0]:
					if not LifePlace.open_ground(q.x + dx, q.y + dz):
						ok = false
			if not ok:
				continue
			var g := Flock.new()
			g.name = "Lapwings%d" % placed.size()
			g.setup(Vector3(q.x, RL.height_at(q.x, q.y), q.y), _rng2.randi_range(9, 13), BUILD_SEED + 503 * placed.size())
			_add_group(g)
			placed.append(q)
			break


func _place_fireflies() -> void:
	var spots: Array[Vector3] = []
	var g := RealmLayout.GLADE_C
	for k in 4:
		var a := float(k) / 4.0 * TAU + 0.4
		spots.append(Vector3(g.x + cos(a) * 9.0, 0.0, g.y + sin(a) * 9.0))
	for p in LifePlace.pools().slice(0, 7):
		var e: Array = p.edge
		if e.size() > 0:
			var q: Vector2 = e[e.size() / 3]
			spots.append(Vector3(q.x, 0.0, q.y))
	# r34 flora: + the Rooted Holds' clearing, the mere's east bank, the orchard rows, the quarry mouth
	for q: Vector2 in [Vector2(-80, 46), Vector2(-14, 50), Vector2(28, 50), Vector2(-62, 22), Vector2(-88, -40), Vector2(-50, -46), Vector2(-96, 10), Vector2(60, 10),
			Vector2(-130, 4), Vector2(126, 112), Vector2(-120, 116), Vector2(-112, -78),
			# the Sorrow's banks, Stillwater's north shore and the downs' hollows
			Vector2(-222, 30), Vector2(-196, -34), Vector2(-218, 100), Vector2(176, -18), Vector2(196, 54), Vector2(-40, 214)]:
		spots.append(Vector3(q.x, 0.0, q.y))
	var i := 0
	for s in spots:
		var n := 12 + (i % 3) * 3
		var mmi := LifeKit.group("firefly", n)
		mmi.name = "Fireflies"
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))))
			mmi.multimesh.set_instance_custom_data(k, Color(_rng.randf_range(2.0, 4.5), _rng.randf_range(0.12, 0.3), _rng.randf_range(0.5, 1.7), _rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-7, -0.5, -7), Vector3(14, 4, 14))
		mmi.visibility_range_end = 50.0
		mmi.visibility_range_end_margin = 5.0
		add_child(mmi)
		mmi.global_position = Vector3(s.x, RL.height_at(s.x, s.z), s.z)
		fireflies.append(mmi)
		counts["firefly"] = int(counts.get("firefly", 0)) + n
		i += 1


func _place_bats() -> void:
	# [centre, radius, count, visible to]
	var swarms := [
		# the chasm's (the far north-east: Endgame)
		[Vector3(0, -4, -28) + Endgame.O, 13.0, 10, 140.0], [Vector3(-10, -2, -50) + Endgame.O, 15.0, 10, 140.0],
		[Vector3(9, 1, -74) + Endgame.O, 12.0, 9, 140.0], [Vector3(-4, 4, -92) + Endgame.O, 10.0, 7, 140.0],
		[Vector3(-9, 17, -50) + Endgame.O, 7.0, 6, 90.0],
		[Vector3(18, 9.5, 30), 6.0, 4, 55.0], [Vector3(-82, 9, 52), 7.0, 5, 60.0], [Vector3(80, 5, -40), 9.0, 4, 70.0],
		# the Ossuary's gate-hall roof and its chapel spire (nothing lived on the high ground); where it stands now
		[Vector3(-43, 13.6, 175), 6.0, 5, 90.0], [Vector3(29, 6.6, 167), 5.0, 4, 70.0],
		# r34 flora: the Founder's Pits' slag heaps, the quarry pit, the mausoleum at the field's top
		[Vector3(132, RL.height_at(132, -90) + 9.0, -90), 9.0, 6, 90.0], [Vector3(-127, RL.height_at(-127, -104) + 7.0, -104), 10.0, 6, 90.0],
		[Vector3(0, RL.height_at(0, 144.5) + 7.0, 144.5), 6.0, 4, 70.0],
		# the Anchorholds' cliff, the Well of Echoes' pit, the Fallen Hierarch's broken crown
		[Vector3(236, RL.height_at(236, -110) + 9.0, -110), 9.0, 6, 90.0], [Vector3(72, -4, 204), 11.0, 7, 90.0],
		[Vector3(-206, RL.height_at(-206, 148) + 24.0, 148), 14.0, 6, 110.0],
	]
	var i := 0
	for s: Array in swarms:
		var n: int = s[2]
		var r: float = s[1]
		var mmi := LifeKit.group("bat", n)
		mmi.name = "Bats"
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(_rng.randf_range(-2, 2), _rng.randf_range(-1.5, 1.5), _rng.randf_range(-2, 2))))
			var sp := _rng.randf_range(0.45, 0.9) * (1.0 if _rng.randf() < 0.6 else -1.0)
			mmi.multimesh.set_instance_custom_data(k, Color(r * _rng.randf_range(0.45, 1.0), sp, _rng.randf_range(1.0, 3.0), _rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-r * 1.5 - 3, -6, -r * 1.5 - 3), Vector3(r * 3 + 6, 12, r * 3 + 6))
		mmi.visibility_range_end = float(s[3])
		mmi.visibility_range_end_margin = 10.0
		add_child(mmi)
		mmi.global_position = s[0]
		bats.append(mmi)
		counts["bat"] = int(counts.get("bat", 0)) + n
		i += 1


## Rats live in the Ossuary only while the crypt is streamed in.
func _rats_step(dt: float) -> void:
	_oss_t -= dt
	if _oss_t > 0.0:
		return
	_oss_t = 1.0
	var area := root.get_node_or_null("Area_ossuary") as Node3D
	if area == null:
		if rats != null:
			# the rat groups themselves are in `groups` (their holder never was): drop them before
			# freeing, or the next frame touches freed nodes
			groups = groups.filter(func(g: Node) -> bool: return not rats.is_ancestor_of(g))
			_gc.resize(0)
			rats.queue_free()
			rats = null
			_oss_wait = -1.0
		return
	if rats != null:
		return
	if _oss_wait < 0.0:
		_oss_wait = 1.5                      # let its collision settle
		return
	_oss_wait -= 1.0
	if _oss_wait > 0.0:
		return
	var space := get_world_3d().direct_space_state
	var r := RandomNumberGenerator.new()
	r.seed = BUILD_SEED + 77
	rats = Node3D.new()
	rats.name = "OssuaryRats"
	add_child(rats)
	for nm: String in ["GalleryA", "GalleryB", "HallFill", "PitCandles", "BridgeUnder"]:
		var l := area.get_node_or_null(nm) as Node3D
		if l == null:
			continue
		var lp := l.global_position
		var fy := LifePlace.floor_below(space, lp.x, lp.y, lp.z, 14.0)
		if is_nan(fy):
			continue
		var spots: Array[Vector3] = []
		for k in 24:
			if spots.size() >= 4:
				break
			var a := r.randf_range(0.0, TAU)
			var q := lp + Vector3(cos(a), 0, sin(a)) * r.randf_range(0.8, 3.5)
			var y := LifePlace.floor_below(space, q.x, fy + 1.2, q.z, 3.0)
			if not is_nan(y) and absf(y - fy) < 0.3:
				spots.append(Vector3(q.x, y, q.z))
		if spots.size() < 2:
			continue
		var g := Beasts.new()
		g.name = "Rats_" + nm
		g.floor_y = fy
		g.setup("rat", spots, BUILD_SEED + hash(nm) % 1000)
		rats.add_child(g)
		groups.append(g)
		_gc.resize(0)
		g.space = space
		g.visible = false
		counts["rat"] = int(counts.get("rat", 0)) + spots.size()


# --- frame ---------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame += 1
	_time += dt
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var cf := -cam.global_basis.z
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var pp := player.global_position if player != null else Vector3(0, -1000, 0)
	if _last_player != Vector3.INF and dt > 0.0:
		var v := Vector2(pp.x - _last_player.x, pp.z - _last_player.z).length() / dt
		_player_speed = lerpf(_player_speed, minf(v, 30.0), clampf(dt * 6.0, 0.0, 1.0))
	_last_player = pp
	_enemy_t -= dt
	if _enemy_t <= 0.0:
		_enemy_t = 0.5
		_enemies.clear()
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			var n3 := e as Node3D
			if n3 != null and n3.is_inside_tree() and n3.global_position.distance_to(cp) < 130.0:
				_enemies.append(n3.global_position)
		_fireflies_danger()
	var ctx := {"cam": cp, "player": pp, "player_speed": _player_speed, "enemies": _enemies, "time": _time,
		"dt": dt, "weather": weather.state, "quiet": quiet or tide, "tide": tide}
	# which groups are within their reach: a full pass 5 times a second (or at once after a jump of
	# the camera); every frame only those are visited
	_scan_t -= dt
	if _gc.size() != groups.size() or _scan_t <= 0.0 or cp.distance_squared_to(_scan_cp) > 25.0:
		_scan_groups(cp)
	_kacc.fill(0.0)
	_kgl.fill(0.0)
	for k in _act:
		var g: Node3D = groups[k]
		var d := _gc[k].distance_to(cp)
		var tg := Time.get_ticks_usec()
		# How often a group's logic runs (limbs and wings animate on the GPU either way):
		#   in view, within 16 m     10 Hz idle, 15 Hz on the move (herds 30, a pool 10 unless you are on
		#                            its bank), and between ticks it glides: redrawn every frame from
		#                            where its velocities, head turns, strides and throats take it
		#                            (still groups skip that), so nothing steps on a 144 Hz screen
		#   in view, further out     on the move 7.5 Hz (5 past 45 m), gliding up to 70 m; idle birds
		#                            and flocks 5 Hz and gliding to 60 m; idle herds 20 / 10 Hz
		#   out of view              5 Hz, no redraw: a roost behind you does not need its frames
		#                            (it is ticked the frame it comes back into view)
		# --no-glide restores r28: every frame near, 20/10 Hz idle and 30/15 Hz busy further out.
		var interval := 0.0
		var inview := true
		var moving := false
		if glide:
			# a herd moves its node with it; the others' nodes sit at their centre
			var gp := g.position if _herd[k] == 1 else _gc[k]
			inview = _in_view(gp, cp, cf, gp.distance_to(cp))
			if not inview:
				interval = OUT_TICK
			else:
				moving = g.busy()
				if moving and _herd[k] == 1 and d < 45.0 and herd_every_frame:
					interval = 0.0          # a herd on the move in view: every frame (~17 us a tick, r30)
				elif d <= NEAR_R:
					interval = g.near_interval(moving)
				elif moving:
					interval = 1.0 / 7.5 if d < 45.0 else 0.2
				elif g.cheap_glide:
					interval = 0.2
				else:
					interval = 0.05 if d < 60.0 else 0.1
		elif d > NEAR_R:
			if not g.busy():
				interval = 0.05 if d < 60.0 else 0.1
			else:
				interval = 1.0 / 30.0 if d < 45.0 else 1.0 / 15.0
		var acc := _acc[k] + dt
		if acc < interval:
			_acc[k] = acc
			# within 16 m everything glides (heads, pecks, strides: a still group returns at once);
			# further out only what is on the move (flight, a fleeing herd, a wheeling flock)
			# herds glide in view out to 60 m even grazing: their meshes draw that far now, and an idle herd's heads,
			# steps and shuffles stepped at 20 Hz read as lag (Luke, 7 Nov: "deer are very laggy")
			if glide and inview and (d <= NEAR_R or (moving and d < 70.0) or (g.cheap_glide and d < 60.0) or (_herd[k] == 1 and d < 60.0)):
				g.glide(acc, interval)
				var gu := float(Time.get_ticks_usec() - tg)
				_kacc[_kid[k]] += gu
				_kgl[_kid[k]] += gu
			continue
		# keep the phase (r30): the next tick is due one interval after this one was due, not one
		# interval after this frame, so a 1/30 s interval at 120 fps is 4 frames every time (resetting
		# to 0 made it 4 or 5 as float rounding fell, and the glide held a frame on the short ones).
		# The tick steps the time it covers; a long gap (back in view) is stepped at once, phase reset.
		var step := acc
		var rem := 0.0
		if interval > 0.0:
			rem = acc - interval
			if rem < interval:
				step = interval
			else:
				rem = 0.0
		_acc[k] = rem
		g.tick(step, ctx)
		_kacc[_kid[k]] += float(Time.get_ticks_usec() - tg)
	for i in _kacc.size():
		if _kacc[i] > 0.0:
			var kn: String = _knames[i]
			kind_us[kn] = float(kind_us.get(kn, 0.0)) + _kacc[i]
			if _kgl[i] > 0.0:
				kind_glide_us[kn] = float(kind_glide_us.get(kn, 0.0)) + _kgl[i]
	_rats_step(dt)
	_weather_uniforms()
	_rescan(dt)
	if tracks != null:
		tracks.step(dt, float(weather.state.rain))
	if phenomena != null:
		phenomena.step(dt, pp, _enemies)
	if not _arriving.is_empty():
		_arrive_step(dt)
	if not _kindle_wait.is_empty():
		_kindle_t -= dt
		if _kindle_t <= 0.0:
			_kindle_t = 0.5
			_kindle_check()
	var us := float(Time.get_ticks_usec() - t0)
	_perf_acc += us
	if _perf_ring.size() != 120:
		_perf_ring.resize(120)
	_perf_ring[_perf_n % 120] = us
	_perf_n += 1
	if _perf_n >= 120:
		perf_us = _perf_acc / float(_perf_n)
		var srt := _perf_ring.duplicate()
		srt.sort()
		perf_p50 = srt[60]
		perf_p90 = srt[108]
		perf_max = srt[119]
		_perf_acc = 0.0
		_perf_n = 0


## Roughly in front of the camera (a group's creatures spread or wander up to ~25 m round its node):
## only those need gliding; behind you the next tick is soon enough.
static func _in_view(c: Vector3, cp: Vector3, cf: Vector3, d: float) -> bool:
	if d < 3.0:
		return true
	return cf.dot((c - cp) / d) > cos(minf(1.05 + atan(25.0 / d), PI))


func _scan_groups(cp: Vector3) -> void:
	if _gc.size() != groups.size():
		_cache_groups()
	_scan_t = 0.2
	_scan_cp = cp
	_act.clear()
	for k in groups.size():
		var g: Node3D = groups[k]
		if not is_instance_valid(g):
			continue
		var on: bool = _gc[k].distance_to(cp) < _gr[k]
		if on != g.visible:
			g.visible = on
			if not on:
				g.rest()
		if on and not g.has_meta(&"fade_set"):
			_fade_group(g, _gr[k] - FADE_PAD)
		if on:
			_act.append(k)


## A group switches on and off whole at its radius (a herd of deer appeared in one frame at 80-110 m, Luke 9 Nov:
## "objects pop in"). Its creatures now fade out over the last FADE_BAND metres before their old `active_r` (seen as
## far as before), and the group switches FADE_PAD further out: past the fade even for a herd ~25 m off its centre,
## so the switch happens unseen. The fade guard is told these ranges are final (range_k).
const FADE_PAD := 30.0
const FADE_BAND := 10.0
static func _fade_group(g: Node3D, active_r: float) -> void:
	g.set_meta(&"fade_set", true)
	var end := maxf(12.0, active_r - 5.0)
	for n in g.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0 and gi.visibility_range_end + gi.visibility_range_end_margin <= active_r:
			continue                                 # (its own range already ends inside: the mice, the far birds)
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = FADE_BAND
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.set_meta(&"range_k", Vector2(gi.visibility_range_begin, end))


func _cache_groups() -> void:
	var n := groups.size()
	_kid.resize(n)
	_herd.resize(n)
	for k in n:
		var g: Node = groups[k]
		var kn := String(g.get("kind"))
		var ki := _knames.find(kn)
		if ki < 0:
			_knames.append(kn)
			ki = _knames.size() - 1
		_kid[k] = ki
		_herd[k] = 1 if g is Beasts and g.get_parent() == self else 0
	_kacc.resize(_knames.size())
	_kgl.resize(_knames.size())
	_gc.resize(n)
	_gr.resize(n)
	var had := _acc.size()
	_acc.resize(n)
	for k in n:
		_gc[k] = groups[k].get("center")
		_gr[k] = float(groups[k].get("active_r")) + FADE_PAD     # (switch past the fade: _fade_group)
		# r30: groups already ticking keep their phase; a new group starts up to 0.1 s late, by the
		# golden ratio of its index, so groups on the same interval do not all tick on one frame
		if k >= had:
			_acc[k] = -0.1 * fposmod(float(k) * 0.618034, 1.0)


var _wx_t := 0.0


func _weather_uniforms() -> void:
	_wx_t -= get_process_delta_time()
	if _wx_t > 0.0:
		return
	_wx_t = 0.25
	var wx: Dictionary = weather.state
	var rain := float(wx.rain)
	var wind := float(weather.gust)
	var key := "%.2f %.2f %s" % [rain, wind, tide]
	if _wx_last.get("k", "") == key:
		return
	_wx_last.k = key
	var calm := clampf((1.0 - rain) * (1.0 - clampf(wind - 0.4, 0.0, 1.0) * 0.8), 0.0, 1.0) * (0.25 if tide else 1.0)
	LifeKit.material("moth").set_shader_parameter("activity", calm)
	LifeKit.material("firefly").set_shader_parameter("activity", clampf(calm * 1.1, 0.0, 1.0))
	LifeKit.material("bat").set_shader_parameter("activity", clampf(1.0 - rain * 0.6, 0.0, 1.0))
	for k: String in ["crow", "owl", "heron", "deer", "stag", "fox", "elk", "frog", "plover", "mouse", "hare"]:
		LifeKit.material(k).set_shader_parameter("wet", rain * 0.8)


func _fireflies_danger() -> void:
	for f in fireflies:
		var on := 1.0
		for e in _enemies:
			if e.distance_to(f.global_position) < 16.0:
				on = 0.15
				break
		if float(f.get_meta("cluster_on", 1.0)) != on:
			f.set_meta("cluster_on", on)
			f.set_instance_shader_parameter("cluster_on", on)


## Lights other systems add after us (village lamps, secrets, encounters' braziers) get moths too.
func _rescan(dt: float) -> void:
	if _rescan_t < 0.0:
		return
	_rescan_t -= dt
	if _rescan_t <= 0.0:
		_rescan_t = -1.0
		_place_moths()
	for l in moths.keys():
		if not is_instance_valid(l):
			(moths[l] as Node).queue_free()
			moths.erase(l)


# --- loading-screen warm-up ------------------------------------------------------------------------

## For the loading screen's shader warm-up (lead: ui/loading_screen.gd). warm_show(true, at) puts every
## r28 effect that is normally hidden (lightning bolt and cloud flash, rain, splashes, wind debris,
## mist banks, meteors and the bolide, the surge overlay, the wisp and its motes, the white hart)
## in view at `at`; warm_show(false) puts them all back. Lapwings and mice share the creature shader.
func warm_show(on: bool, at := Vector3.ZERO) -> void:
	weather.warm(on, at)
	if phenomena != null:
		phenomena.warm(on, at)


# --- events ----------------------------------------------------------------------------------------

func alarm(at: Vector3, strength: float, only := "") -> void:
	for g in groups:
		if only != "" and g.kind != only:
			continue
		if (g.center as Vector3).distance_to(at) < 60.0 + 80.0 * strength:
			g.alarm(at, strength)


func _player_pos() -> Vector3:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return p.global_position if p != null else Vector3.INF


func _on_skill(_id: StringName) -> void:
	var p := _player_pos()
	if p != Vector3.INF:
		alarm(p, 0.35)


func _on_kill(enemy: Node) -> void:
	if is_instance_valid(enemy) and enemy is Node3D:
		alarm((enemy as Node3D).global_position, 0.6)


func _on_hurt(_amount: float, _from: Vector3) -> void:
	var p := _player_pos()
	if p != Vector3.INF:
		alarm(p, 0.4)


func _on_boss(_boss: Node, _title: String) -> void:
	var p := _player_pos()
	if p != Vector3.INF:
		alarm(p, 1.0)


## A brazier was kindled: its flame (once it has grown: the light eases up after the kindling) gets
## a moth swarm, and the moths are not there yet: they come in out of the dark over half a minute.
func _on_kindled(b: Node3D) -> void:
	_kindle_wait.append([b, 12.0])
	_kindle_check()


func _kindle_check() -> void:
	for i in range(_kindle_wait.size() - 1, -1, -1):
		var e: Array = _kindle_wait[i]
		var b := e[0] as Node3D
		e[1] = float(e[1]) - 0.5
		if not is_instance_valid(b) or float(e[1]) <= 0.0:
			_kindle_wait.remove_at(i)
			continue
		for l in b.find_children("*", "OmniLight3D", true, false):
			var ol := l as OmniLight3D
			if moths.has(ol) or _unlit(ol) or not LifePlace.eligible_light(root, ol):
				continue
			_moths_for(ol)
			if not off and moths.has(ol):
				var mg := moths[ol] as MultiMeshInstance3D
				mg.set_instance_shader_parameter("arrive", 0.0)
				mg.extra_cull_margin = 12.0
				_arriving.append([mg, 0.0])
			_kindle_wait.remove_at(i)
			break


func _arrive_step(dt: float) -> void:
	for i in range(_arriving.size() - 1, -1, -1):
		var e: Array = _arriving[i]
		var mg := e[0] as MultiMeshInstance3D
		if not is_instance_valid(mg):
			_arriving.remove_at(i)
			continue
		var k := minf(1.0, float(e[1]) + dt / 28.0)
		e[1] = k
		mg.set_instance_shader_parameter("arrive", smoothstep(0.0, 1.0, k))
		if k >= 1.0:
			mg.extra_cull_margin = 0.0
			_arriving.remove_at(i)


## The rift surges (phenomena.gd): bats boil, crows go up, herds look toward the chasm, frogs hush.
func on_surge(at: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam != null else Vector3.ZERO
	for g in groups:
		if (g.center as Vector3).distance_to(cp) > 160.0:
			continue
		match String(g.kind):
			"crow":
				g.alarm(g.center, 0.9)
			"deer", "elk", "fox", "hare":
				g.startle(at, 0.6)
			"pond":
				g.alarm(g.center, 0.5)
			"plover":
				if _rng.randf() < 0.5:
					g.alarm(g.center, 0.6)


## The Gloom tide (encounters): while it is up the frogs and birds fall silent, fireflies go out,
## and everything near the wanderer takes fright as it rises.
func _on_tide(active: bool) -> void:
	tide = active
	_wx_t = 0.0
	if active:
		var p := _player_pos()
		if p != Vector3.INF:
			alarm(p, 1.0)


## Thunder: crows go up from every roost in earshot (most of them), owls sometimes, frogs hush,
## the herds' heads come up toward it (and a strike close by sends them running), lapwings lift.
func _on_thunder(at: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam != null else Vector3.ZERO
	for g in groups:
		if (g.center as Vector3).distance_to(cp) > 160.0:
			continue
		match String(g.kind):
			"deer", "elk", "fox", "hare":
				var near := Vector2(at.x - g.center.x, at.z - g.center.z).length() < 140.0
				if near:
					g.alarm(at, 1.0)
				else:
					g.startle(at, 0.4)
			"plover":
				if Vector2(at.x - g.center.x, at.z - g.center.z).length() < 400.0:
					g.alarm(g.center, 0.5)
			"crow":
				if _rng.randf() < 0.75:
					g.alarm(g.center, 1.0)
			"owl":
				if _rng.randf() < 0.3:
					g.alarm(g.center, 0.4)
			"pond":
				g.alarm(g.center, 1.0)

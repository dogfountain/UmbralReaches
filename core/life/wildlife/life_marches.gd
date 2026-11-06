extends RefCounted
## The Marches' and the downs' wildlife (Foundation): extra deer herds, foxes and hares on the new ground,
## from streams of their own, so the old Realm's placements stay exactly as they were. Placed by life_director.gd
## (`add` is its _add_group; `Beasts` the walking animals).

const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")


## Deer herds from the spots `herds` (shared by the old Realm's pass and the Marches').
static func make_herds(add: Callable, space: PhysicsDirectSpaceState3D, herds: Array[Vector3], hrng: RandomNumberGenerator, hi0: int, name_fmt: String, seed_off: int, seed_base := 4127) -> int:
	var hi := hi0
	for h in herds:
		var spots: Array[Vector3] = []
		var n := hrng.randi_range(3, 5)
		for k in 30:
			if spots.size() >= n:
				break
			var a := hrng.randf_range(0.0, TAU)
			var q := h + Vector3(cos(a), 0, sin(a)) * hrng.randf_range(0.0, 6.0)
			if not LifePlace.open_ground(q.x, q.z):
				continue
			var near := false
			for s in spots:
				if s.distance_to(q) < 1.6:
					near = true
			if near:
				continue
			spots.append(Vector3(q.x, LifePlace.ground(space, q.x, q.z), q.z))
		if spots.size() < 2:
			continue
		var g := Beasts.new()
		g.name = name_fmt % hi
		g.setup("deer", spots, seed_base + 307 * hi + seed_off)
		add.call(g)
		hi += 1
	return hi


## Up to six herds on the Marches' and the downs' forest edges.
static func herds(add: Callable, space: PhysicsDirectSpaceState3D, camps: Array[Vector2], seed_base: int) -> void:
	# the Marches' and the downs' herds: their own stream, their own list, up to six more
	var hrng2 := RandomNumberGenerator.new()
	hrng2.seed = seed_base + 1001
	var edges2 := LifePlace.forest_edges(hrng2, true)
	LifePlace.shuffle(edges2, hrng2)
	var herds2: Array[Vector3] = []
	for e: Vector3 in edges2:
		var far2 := true
		for rd: Dictionary in RealmLayout.RAIDS:
			if Vector2(e.x, e.z).distance_to(rd.c) < float(rd.r) + 14.0:
				far2 = false
		for c in camps:
			if c.distance_to(Vector2(e.x, e.z)) < 30.0:
				far2 = false
				break
		for h2 in herds2:
			if h2.distance_to(e) < 45.0:
				far2 = false
				break
		if far2:
			herds2.append(e)
		if herds2.size() >= 6:
			break
	make_herds(add, space, herds2, hrng2, 0, "DeerM%d", 307 * 40)


## Up to five more foxes, scanned off the camps and haunts.
static func foxes(add: Callable, space: PhysicsDirectSpaceState3D, keep_off: Array, rng3: RandomNumberGenerator, seed_base: int) -> void:
	# the Marches and the downs: up to five more foxes, scanned off the camps and haunts on their own stream
	var scan2: Array[Vector2] = []
	var nb: Rect2 = RealmLayout.BOUNDS
	var gy2 := nb.position.y + 6.0
	while gy2 < nb.end.y - 6.0:
		var gx2 := nb.position.x + 6.0
		while gx2 < nb.end.x - 6.0:
			var q2 := Vector2(gx2, gy2)
			if not RealmLayout.OLD_BOUNDS.has_point(q2):
				var ok2 := true
				for cp in keep_off:
					if cp.distance_to(q2) < 60.0:
						ok2 = false
						break
				if ok2:
					scan2.append(q2)
			gx2 += 12.0
		gy2 += 12.0
	LifePlace.shuffle(scan2, rng3)
	var placed2: Array[Vector2] = []
	var fi2 := 0
	for c2 in scan2:
		var spaced2 := true
		for pq in placed2:
			if pq.distance_to(c2) < 40.0:
				spaced2 = false
		if not spaced2:
			continue
		for k in 40:
			var q := c2 + Vector2(rng3.randf_range(-18, 18), rng3.randf_range(-18, 18))
			var clear2 := true
			for cp in keep_off:
				if cp.distance_to(q) < 52.0:
					clear2 = false
					break
			if clear2 and LifePlace.open_ground(q.x, q.y) and RealmLayout.path_dist(q) > 2.5:
				var spots2: Array[Vector3] = [Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y)]
				var g2 := Beasts.new()
				placed2.append(q)
				g2.name = "FoxM%d" % fi2
				g2.setup("fox", spots2, seed_base + 401 * (fi2 + 40))
				add.call(g2)
				fi2 += 1
				break
		if fi2 >= 5:
			break


## Five more hare forms; returns how many were made.
static func hares(add: Callable, space: PhysicsDirectSpaceState3D, keep_off: Array, seed_base: int) -> int:
	# five more forms on the downs, the west bank and the east shore (their own stream)
	var hrng2 := RandomNumberGenerator.new()
	hrng2.seed = seed_base + 1733
	var hj := 0
	for c: Vector2 in [Vector2(-110.0, 205.0), Vector2(20.0, 214.0), Vector2(125.0, 205.0), Vector2(-232.0, 34.0), Vector2(190.0, 54.0)]:
		var spots2: Array[Vector3] = []
		for k in 40:
			if spots2.size() >= 2 + (hj % 2):
				break
			var q := c + Vector2(hrng2.randf_range(-9.0, 9.0), hrng2.randf_range(-7.0, 7.0))
			var clear := true
			for cp: Vector2 in keep_off:
				if cp.distance_to(q) < 20.0:
					clear = false
					break
			if not clear or not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 2.0:
				continue
			var near := false
			for s0 in spots2:
				if Vector2(s0.x, s0.z).distance_to(q) < 1.5:
					near = true
			if not near:
				spots2.append(Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y))
		if spots2.size() < 2:
			continue
		var g2 := Beasts.new()
		g2.name = "HareM%d" % hj
		g2.setup("hare", spots2, seed_base + 517 * (hj + 20))
		add.call(g2)
		hj += 1
	return hj

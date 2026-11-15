extends RefCounted
## The Far Reaches' wildlife (docs/far_reaches.md): the doubled ground gets the life the Marches have, on streams
## of its own so nothing already placed moves. Foxes and hare forms on the open heaths and fields, lapwing flocks
## over the fallow strips and the cairn heath, fireflies on the meres' edges, the hedges and the lit wood's
## clearings, bats round the high and hollow places (the keep, the barrow, the arches, the bell's crater, the
## nave's vault, the cairn tower). No deer (Luke, 14 Nov). Placed by life_director.gd after its own pass.

const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")
const Flock := preload("res://core/life/wildlife/life_flock.gd")
const RL := preload("res://core/world/realm/realm_land.gd")

const SEED := 4127 + 7919

## Hare forms and lapwing flocks: open ground on the heaths, the fields and the meadows.
const HARES := [Vector2(-330, 96), Vector2(-300, 210), Vector2(-176, 340), Vector2(-120, 372), Vector2(300, 18),
	Vector2(346, 300), Vector2(296, 372), Vector2(-300, -96)]
const FLOCKS := [Vector2(-180, 360), Vector2(-320, 190), Vector2(330, 330), Vector2(330, 0), Vector2(-40, 372)]
## Fireflies: the meres' reedy edges, the hamlet's hedges and orchard, the lit wood, the nave's shore, the Southwood.
const FIREFLIES := [Vector2(-300, 330), Vector2(-262, 360), Vector2(-344, 312), Vector2(-178, 286), Vector2(-136, 318),
	Vector2(-320, 4), Vector2(-344, -20), Vector2(-300, 40), Vector2(296, 150), Vector2(342, 190), Vector2(140, 320),
	Vector2(196, 344), Vector2(306, 40), Vector2(-60, 300), Vector2(40, 300)]
## Bats: [xz, height over the ground, radius, count]
const BATS := [[Vector2(-318, -108), 18.0, 10.0, 7], [Vector2(-345, 152), 6.0, 7.0, 5], [Vector2(0, 342), 22.0, 14.0, 8],
	[Vector2(-60, 352), 14.0, 7.0, 4], [Vector2(318, -100), 8.0, 13.0, 6], [Vector2(318, 164), 16.0, 14.0, 8],
	[Vector2(327, 324), 16.0, 6.0, 5], [Vector2(226, 362), 8.0, 7.0, 4]]


static func place(d: Node, add: Callable, space: PhysicsDirectSpaceState3D, keep_off: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_foxes(add, space, keep_off, rng)
	_hares(add, space, keep_off, rng)
	_flocks(add, rng)
	_fireflies(d, rng)
	_bats(d, rng)


static func _far(q: Vector2) -> bool:
	return not RealmReaches.MARCH_BOUNDS.has_point(q) and RealmLayout.BOUNDS.grow(-8.0).has_point(q)


static func _clear(q: Vector2, keep_off: Array, r: float) -> bool:
	for cp: Vector2 in keep_off:
		if cp.distance_to(q) < r:
			return false
	return true


## Up to seven foxes on the Reaches' open ground, 52 m off camps and haunts (a camp in sight keeps a fox on watch).
static func _foxes(add: Callable, space: PhysicsDirectSpaceState3D, keep_off: Array, rng: RandomNumberGenerator) -> void:
	var scan: Array[Vector2] = []
	var b := RealmLayout.BOUNDS
	var gz := b.position.y + 8.0
	while gz < b.end.y - 8.0:
		var gx := b.position.x + 8.0
		while gx < b.end.x - 8.0:
			var q := Vector2(gx, gz)
			if _far(q) and _clear(q, keep_off, 60.0):
				scan.append(q)
			gx += 14.0
		gz += 14.0
	LifePlace.shuffle(scan, rng)
	var placed: Array[Vector2] = []
	for c in scan:
		if placed.size() >= 7:
			break
		var spaced := true
		for pq in placed:
			if pq.distance_to(c) < 60.0:
				spaced = false
		if not spaced:
			continue
		for k in 30:
			var q := c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16))
			if _far(q) and _clear(q, keep_off, 52.0) and LifePlace.open_ground(q.x, q.y) and RealmLayout.path_dist(q) > 2.5:
				var g := Beasts.new()
				g.name = "FoxR%d" % placed.size()
				g.setup("fox", [Vector3(q.x, LifePlace.ground(space, q.x, q.y), q.y)] as Array[Vector3], SEED + 401 * placed.size())
				add.call(g)
				placed.append(q)
				break


static func _hares(add: Callable, space: PhysicsDirectSpaceState3D, keep_off: Array, rng: RandomNumberGenerator) -> void:
	var n := 0
	for c: Vector2 in HARES:
		var spots: Array[Vector3] = []
		for k in 40:
			if spots.size() >= 2 + (n % 2):
				break
			var q := c + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
			if not _clear(q, keep_off, 20.0) or not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 2.0:
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
		g.name = "HareR%d" % n
		g.setup("hare", spots, SEED + 517 * n)
		add.call(g)
		n += 1


static func _flocks(add: Callable, rng: RandomNumberGenerator) -> void:
	var placed: Array[Vector2] = []
	for c: Vector2 in FLOCKS:
		for k in 40:
			var q := c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-10, 10))
			if not LifePlace.open_ground(q.x, q.y) or RealmLayout.path_dist(q) < 4.0:
				continue
			var ok := true
			for dx: float in [-3.0, 3.0]:
				for dz: float in [-3.0, 3.0]:
					ok = ok and LifePlace.open_ground(q.x + dx, q.y + dz)
			if not ok:
				continue
			var g := Flock.new()
			g.name = "LapwingsR%d" % placed.size()
			g.setup(Vector3(q.x, RL.height_at(q.x, q.y), q.y), rng.randi_range(9, 14), SEED + 503 * placed.size())
			add.call(g)
			placed.append(q)
			break


static func _fireflies(d: Node, rng: RandomNumberGenerator) -> void:
	var counts: Dictionary = d.get("counts")
	var list: Array = d.get("fireflies")
	for i in FIREFLIES.size():
		var s: Vector2 = FIREFLIES[i]
		var n := 12 + (i % 3) * 4
		var mmi := LifeKit.group("firefly", n)
		mmi.name = "Fireflies"
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))))
			mmi.multimesh.set_instance_custom_data(k, Color(rng.randf_range(2.0, 4.5), rng.randf_range(0.12, 0.3), rng.randf_range(0.5, 1.7), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-7, -0.5, -7), Vector3(14, 4, 14))
		mmi.visibility_range_end = 50.0
		mmi.visibility_range_end_margin = 5.0
		d.add_child(mmi)
		mmi.global_position = Vector3(s.x, RL.height_at(s.x, s.y), s.y)
		list.append(mmi)
		counts["firefly"] = int(counts.get("firefly", 0)) + n


static func _bats(d: Node, rng: RandomNumberGenerator) -> void:
	var counts: Dictionary = d.get("counts")
	var list: Array = d.get("bats")
	for s: Array in BATS:
		var at: Vector2 = s[0]
		var r: float = s[2]
		var n: int = s[3]
		var mmi := LifeKit.group("bat", n)
		mmi.name = "Bats"
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-2, 2), rng.randf_range(-1.5, 1.5), rng.randf_range(-2, 2))))
			var sp := rng.randf_range(0.45, 0.9) * (1.0 if rng.randf() < 0.6 else -1.0)
			mmi.multimesh.set_instance_custom_data(k, Color(r * rng.randf_range(0.45, 1.0), sp, rng.randf_range(1.0, 3.0), rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-r * 1.5 - 3, -6, -r * 1.5 - 3), Vector3(r * 3 + 6, 12, r * 3 + 6))
		mmi.visibility_range_end = 100.0
		mmi.visibility_range_end_margin = 10.0
		d.add_child(mmi)
		mmi.global_position = Vector3(at.x, RL.height_at(at.x, at.y) + float(s[1]), at.y)
		list.append(mmi)
		counts["bat"] = int(counts.get("bat", 0)) + n

extends RefCounted
## Way-posts at the ways' junctions (map audit, 18 Nov: some thirty junctions and not one sign on any). Where a way ends on
## another, or two ways' ends meet, a post (art/models/props/fingerpost.glb) stands beside the meeting, on its outside,
## clear of the ways, the places and the trees, with one arm (fingerpost_arm.glb) pointing down each way that leaves it.
## Built after the flora by RealmWayfinding.build; one merged mesh per material set per 96 m cell (a couple of draws in
## view), faded out past 150 m; a thin collider on each post. Each post registers a small site so later builders keep off.
## No class_name: preload by path.

const PropModels := preload("res://core/world/realm/prop_models.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

const CELL := 96.0
const MERGE_R := 9.0                    ## junctions closer than this share one post
const MEET := 2.2                       ## a way's end within this of another way's line meets it
const AHEAD := 12.0                     ## an arm points at the way this far on from the junction
const ARM_Y := [2.25, 1.95, 1.67, 1.39]
const SAME_DIR := 0.9                   ## two leaving directions closer than this (cos) are one arm

static var posts: Array[Vector3] = []   ## last build (tests, stills)


static func build(holder: Node3D, space: PhysicsDirectSpaceState3D) -> int:
	posts.clear()
	var juncs: Array = []               # [junction xz, Array[Vector2] directions it can be left by]
	var paths: Array = RealmLayout.PATHS
	for i in paths.size():
		var pa: Array = (paths[i] as Dictionary).pts
		if pa.size() < 2:
			continue
		for end: int in [0, pa.size() - 1]:
			var q: Vector2 = pa[end]
			var dirs: Array[Vector2] = []
			var into := _toward(pa, end == 0, q)
			if into != Vector2.ZERO:
				dirs.append(into)
			for j in paths.size():
				if j == i:
					continue
				var pb: Array = (paths[j] as Dictionary).pts
				if _dist(pb, q) > MEET:
					continue
				for fwd: bool in [true, false]:
					var d := _along(pb, q, fwd)
					if d != Vector2.ZERO:
						_add_dir(dirs, d)
			if dirs.size() < 2:
				continue
			var merged := false
			for jn: Array in juncs:
				if (jn[0] as Vector2).distance_to(q) < MERGE_R:
					for d: Vector2 in dirs:
						_add_dir(jn[1], d)
					merged = true
					break
			if not merged:
				juncs.append([q, dirs])
	var kits := {}                       # cell -> PropModels
	var n := 0
	for jn: Array in juncs:
		var q: Vector2 = jn[0]
		var dirs: Array = jn[1]
		var at := _spot(space, q, dirs)
		if at == Vector3.INF:
			continue
		var key := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
		if not kits.has(key):
			kits[key] = PropModels.new()
		var pm: PropModels = kits[key]
		var yaw := float(absi(hash(Vector2i(roundi(at.x), roundi(at.z)))) % 628) / 100.0
		pm.add("fingerpost.glb", Transform3D(Basis(Vector3.UP, yaw), at))
		var k := 0
		for d: Vector2 in dirs:
			if k >= ARM_Y.size():
				break
			var aim := (q + d * AHEAD) - Vector2(at.x, at.z)
			if aim.length() < 0.5:
				continue
			aim = aim.normalized()
			pm.add("fingerpost_arm.glb", Transform3D(Basis(Vector3.UP, atan2(-aim.y, aim.x)), at + Vector3.UP * float(ARM_Y[k])))
			k += 1
		_collider(holder, at)
		WorldLanes.register_site("signpost_%d" % n, Rect2(at.x - 0.6, at.z - 0.6, 1.2, 1.2), at.y, at.y)
		posts.append(at)
		n += 1
	for key: Vector2i in kits:
		for mi: MeshInstance3D in (kits[key] as PropModels).commit(holder, "Signposts_%d_%d" % [key.x, key.y], false):
			mi.visibility_range_end = 150.0
			mi.visibility_range_end_margin = 15.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return n


## Where the post stands: on a ring round the junction just past the ways' edges, on dry open ground off every way, place
## and tree, preferring the outside of the meeting (away from the ways that leave it). INF if nowhere fits.
static func _spot(space: PhysicsDirectSpaceState3D, q: Vector2, dirs: Array) -> Vector3:
	var mean := Vector2.ZERO
	for d: Vector2 in dirs:
		mean += d
	var best := Vector3.INF
	var best_s := -INF
	for r: float in [2.6, 3.2, 3.9]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var c := q + Vector2(cos(a), sin(a)) * r
			var pd := RealmLayout.path_dist(c)
			if pd < 1.9 or Land.in_water(c.x, c.y) or not WorldLanes.site_at(c, 0.7).is_empty() or RealmMarch.wall_dist(c) < 3.0:
				continue
			if _near_tree(c):
				continue
			var y := RealmLayout.ground(space, c.x, c.y)
			if absf(y - Land.height_at(c.x, c.y)) > 0.35:
				continue                                      # something built stands there
			var s := minf(pd, 3.5) - 0.4 * r - 0.8 * (Vector2(cos(a), sin(a)).dot(mean.normalized()) if mean.length() > 0.01 else 0.0)
			if s > best_s:
				best_s = s
				best = Vector3(c.x, y - 0.04, c.y)
	return best


static func _near_tree(c: Vector2) -> bool:
	for t: Array in Flora.trees:
		var p: Vector3 = t[0]
		if Vector2(p.x, p.z).distance_to(c) < float(t[2]) + 0.9:
			return true
	return false


static func _collider(holder: Node3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "SignpostBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.18, 2.7, 0.18)
	cs.shape = bs
	body.add_child(cs)
	holder.add_child(body)
	body.global_position = at + Vector3.UP * 1.35


## The direction a way leaves its end `q` by: toward its own polyline AHEAD m on (ZERO for a way too short).
static func _toward(pts: Array, from_start: bool, q: Vector2) -> Vector2:
	var p := _walk(pts, 0 if from_start else pts.size() - 1, 1 if from_start else -1, AHEAD)
	return (p - q).normalized() if p.distance_to(q) > 3.0 else Vector2.ZERO


## The direction way `pts` leaves the point nearest `q` by, forward or back along it (ZERO when it ends within 4 m).
static func _along(pts: Array, q: Vector2, fwd: bool) -> Vector2:
	var best := INF
	var bi := 0
	var bp := q
	for i in pts.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1])
		if c.distance_to(q) < best:
			best = c.distance_to(q)
			bi = i
			bp = c
	var room := 0.0
	var k := bi + 1 if fwd else bi
	var prev := bp
	var step := 1 if fwd else -1
	while k >= 0 and k < pts.size() and room < AHEAD:
		var nx: Vector2 = pts[k]
		var seg := prev.distance_to(nx)
		if room + seg >= AHEAD:
			prev = prev.lerp(nx, (AHEAD - room) / maxf(seg, 0.001))
			room = AHEAD
			break
		room += seg
		prev = nx
		k += step
	if room < 4.0:
		return Vector2.ZERO
	return (prev - q).normalized()


static func _walk(pts: Array, i0: int, step: int, dist: float) -> Vector2:
	var room := 0.0
	var prev: Vector2 = pts[i0]
	var k := i0 + step
	while k >= 0 and k < pts.size():
		var nx: Vector2 = pts[k]
		var seg := prev.distance_to(nx)
		if room + seg >= dist:
			return prev.lerp(nx, (dist - room) / maxf(seg, 0.001))
		room += seg
		prev = nx
		k += step
	return prev


static func _dist(pts: Array, q: Vector2) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1]).distance_to(q))
	return best


static func _add_dir(dirs: Array, d: Vector2) -> void:
	for e: Vector2 in dirs:
		if e.dot(d) > SAME_DIR:
			return
	dirs.append(d)

extends RefCounted
## The Ashen Rift's rim, re-landscaped (docs/far_reaches.md, the lava area; the field is rift/scorch.gd). Built by
## RealmPois (REACH_POIS): reserve(root) before the stamp and the flora, build(holder) after the flora, so nothing
## here stands in a tree and the flora already thinned, browned and charred the wood round the lip.
##   - the rift's breath: the smoke column out of the lava at the rift's head (rift/plume.gd)
##   - basalt: spatter heaped along both lips, bombs thrown out over the burn, slabs heaved up on the flows,
##     rubble at the flows' toes, a few black tors in the burned wood
##   - charred trunks lying where the fire dropped them (TreeGen logs, burned black)
##   - steam where the flows' fronts stopped in the fen's water, smoke where their crust is still warm
## Everything keeps off the ways, the Crossing, every registered site and the chasm itself.

const Scorch := preload("res://core/world/realm/rift/scorch.gd")
const Plume := preload("res://core/world/realm/rift/plume.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")

const SEED := 7307
const CHAR := Color(0.24, 0.215, 0.2)          ## a burned trunk's tint over its bark


static func reserve(_root: Node) -> void:
	pass


static func build(holder: Node) -> void:
	if "--no-scorch" in OS.get_cmdline_user_args():
		return
	var t0 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "RiftScorch"
	host.set_meta("site", "rift_scorch")
	holder.add_child(host)
	var space := host.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var rocks := {}                               # mesh -> Array[Transform3D]
	var n_rock := _spatter(space, rng, rocks) + _bombs(space, rng, rocks) + _flow_rocks(space, rng, rocks)
	var n_tor := _tors(host, space, rng)
	_commit_rocks(host, rocks)
	var n_log := _logs(host, space, rng)
	var n_steam := _steam(host, space, rng)
	Plume.build(host)
	WorldLanes.own(host)
	print("RIFT_RIM scorch dressed: %d rocks, %d tors, %d charred trunks, %d steam/smoke vents, the plume (%d ms)" % [
		n_rock, n_tor, n_log, n_steam, Time.get_ticks_msec() - t0])


# --- placement ------------------------------------------------------------------------------------

## Terrain height at xz if the first thing a ray from above meets is the ground itself (NAN on anything built).
static func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 90.0, z + 0.0029), Vector3(x, -40.0, z), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not String((hit.collider as Node).name).begins_with("Terrain"):
		return NAN
	return (hit.position as Vector3).y


## The ground's normal there (for seating a rock with the slope).
static func _normal(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 90.0, z), Vector3(x, -40.0, z), Layers.WORLD)
	var hit := space.intersect_ray(q)
	return (hit.normal as Vector3) if not hit.is_empty() else Vector3.UP


## True where nothing may be put: the ways, the Crossing's lanes, a site's floor, inside the chasm.
static func _blocked(p: Vector2, pad: float) -> bool:
	if RealmLayout.path_dist(p) < 1.6 + pad:
		return true
	if absf(p.x) < 25.5 and p.y > -123.0 and p.y < -10.0:
		return true                                  # the chasm and its lip
	for s: Dictionary in WorldLanes.sites:
		if String(s.name) == "rift_scorch":
			continue
		if not is_nan(WorldLanes.site_floor(s, p, pad + 0.6)):
			return true
	for l: Array in WorldLanes.extra_lanes:
		var pts: Array = l[1]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(l[2]) + pad + 0.8:
				return true
	return false


static func _rock_mesh(rocks: Dictionary, seed: int, size: Vector3, style: String) -> Mesh:
	var m := RockKit.boulder(posmod(seed, 4), size, style)          # four shapes a size and style: few draws
	if not rocks.has(m):
		rocks[m] = []
	return m


static func _put(rocks: Dictionary, m: Mesh, at: Vector3, n: Vector3, yaw: float, s: Vector3, sink: float) -> void:
	var up := n.lerp(Vector3.UP, 0.4).normalized()
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := up.cross(fwd).normalized()
	fwd = side.cross(up).normalized()
	var b := Basis(side * s.x, up * s.y, fwd * s.z)
	(rocks[m] as Array).append(Transform3D(b, at - up * sink))


# --- basalt -------------------------------------------------------------------------------------------

## Spatter heaped along both lips: clots of black rock thrown out as the rift fountained, in a ragged rampart.
static func _spatter(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, rocks: Dictionary) -> int:
	var n := 0
	for side: float in [-1.0, 1.0]:
		var z := -16.0
		while z > -118.0:
			z -= rng.randf_range(1.6, 3.4)
			if z > -40.0 and side > 0.0:
				continue                             # the Fen postern's crest walk runs on the east lip there
			for k in rng.randi_range(1, 3):
				var p := Vector2(side * rng.randf_range(26.5, 31.5), z + rng.randf_range(-1.2, 1.2))
				if _blocked(p, 0.3):
					continue
				var y := _ground(space, p.x, p.y)
				if is_nan(y) or y < -6.0:
					continue
				var s := rng.randf_range(0.45, 1.25)
				var m := _rock_mesh(rocks, rng.randi(), Vector3(1.3, 0.8, 1.1), "basalt" if rng.randf() < 0.6 else "ash")
				_put(rocks, m, Vector3(p.x, y, p.y), _normal(space, p.x, p.y), rng.randf() * TAU, Vector3(s, s * rng.randf_range(0.55, 0.9), s * rng.randf_range(0.8, 1.1)), 0.12 * s)
				n += 1
	return n


## Bombs: lone black boulders thrown out over the burn, thickest near the lip, a crater of ash round some.
static func _bombs(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, rocks: Dictionary) -> int:
	var n := 0
	var tries := 0
	while n < 120 and tries < 2400:
		tries += 1
		var p := Vector2(rng.randf_range(Scorch.RECT.position.x, Scorch.RECT.end.x), rng.randf_range(-138.0, -14.0))
		var b := Scorch.burn(p.x, p.y)
		if b < 0.45 or rng.randf() > b * b or Scorch.flow(p.x, p.y) > 0.05 or _blocked(p, 0.6):
			continue
		var y := _ground(space, p.x, p.y)
		if is_nan(y) or y < -5.0:
			continue
		var big := rng.randf() < 0.18
		var s := rng.randf_range(1.2, 2.2) if big else rng.randf_range(0.35, 0.9)
		var m := _rock_mesh(rocks, rng.randi(), Vector3(1.4, 1.0, 1.2) if big else Vector3(0.9, 0.6, 0.8), "ash" if rng.randf() < 0.55 else "basalt")
		_put(rocks, m, Vector3(p.x, y, p.y), _normal(space, p.x, p.y), rng.randf() * TAU, Vector3(s, s * rng.randf_range(0.6, 0.95), s), 0.18 * s)
		n += 1
	return n


## On the flows: slabs of crust heaved up and tilted (pressure ridges), and rubble piled at their toes.
static func _flow_rocks(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, rocks: Dictionary) -> int:
	var n := 0
	for f: Dictionary in Scorch.flows():
		var pts: Array = f.pts
		var hws: Array = f.hw
		# heaved slabs along the spine's middle reach
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := int(a.distance_to(b) / 2.2)
			for k in steps:
				if rng.randf() > 0.45:
					continue
				var c := a.lerp(b, (k + rng.randf()) / float(maxi(steps, 1)))
				var dirn := (b - a).normalized()
				var off := Vector2(-dirn.y, dirn.x) * rng.randf_range(-1.0, 1.0) * float(hws[i]) * 0.65
				var p := c + off
				if Scorch.flow(p.x, p.y) < 0.25 or _blocked(p, 0.3):
					continue
				var y := _ground(space, p.x, p.y)
				if is_nan(y):
					continue
				var s := rng.randf_range(0.8, 1.7)
				var m := _rock_mesh(rocks, rng.randi(), Vector3(2.0, 0.55, 1.4), "basalt")
				var yaw := atan2(dirn.x, dirn.y) + PI * 0.5 + rng.randf_range(-0.4, 0.4)      # ridges stand across the flow
				var tilt := Basis(Vector3(cos(yaw), 0.0, -sin(yaw)), rng.randf_range(0.25, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0))
				_put(rocks, m, Vector3(p.x, y, p.y), tilt * Vector3.UP, yaw, Vector3(s, s * rng.randf_range(0.7, 1.0), s), 0.2 * s)
				n += 1
		# the toe: rubble round the lobe's front
		var end: Vector2 = pts[pts.size() - 1]
		var prev: Vector2 = pts[pts.size() - 2]
		var fwd := (end - prev).normalized()
		var hw: float = hws[hws.size() - 1]
		for k in 16:
			var ang := rng.randf_range(-1.6, 1.6)
			var dir := fwd.rotated(ang)
			var p := end + dir * (hw * rng.randf_range(0.85, 1.15))
			if _blocked(p, 0.3):
				continue
			var y := _ground(space, p.x, p.y)
			if is_nan(y):
				continue
			var s := rng.randf_range(0.4, 1.0)
			var m := _rock_mesh(rocks, rng.randi(), Vector3(1.0, 0.7, 0.9), "basalt")
			_put(rocks, m, Vector3(p.x, y, p.y), _normal(space, p.x, p.y), rng.randf() * TAU, Vector3(s, s * rng.randf_range(0.6, 1.0), s), 0.1 * s)
			n += 1
	return n


## A few black tors standing out of the burned wood: the rift's basalt pushed up through the hill.
static func _tors(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> int:
	var n := 0
	for c: Vector2 in [Vector2(-42.0, -108.0), Vector2(-46.0, -74.0), Vector2(38.0, -116.0), Vector2(-38.0, -126.0)]:
		var p := c
		var ok := false
		for k in 10:
			if not _blocked(p, 2.5) and Scorch.burn(p.x, p.y) > 0.4:
				ok = true
				break
			p = c + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
		if not ok:
			continue
		var y := _ground(space, p.x, p.y)
		if is_nan(y):
			continue
		var h := rng.randf_range(3.2, 5.0)
		var mesh := RockKit.basalt_columns(rng.randi(), rng.randf_range(1.6, 2.4), h)
		var mi := RockKit.spawn(host, mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y - 0.6, p.y)), true, 240.0)
		mi.name = "BasaltTor%d" % n
		n += 1
	return n


static func _commit_rocks(host: Node3D, rocks: Dictionary) -> void:
	var i := 0
	for m: Mesh in rocks:
		var xfs: Array = rocks[m]
		if xfs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "ScorchRocks%d" % i
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.visibility_range_end = 150.0
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)
		# the bigger ones stop the wanderer (one body each, its hull scaled into the shape: bodies take no scale;
		# the small clots are walked over)
		var hull := RockKit.collision_shape(m) as ConvexPolygonShape3D
		for xf: Transform3D in xfs:
			if hull == null or xf.basis.get_scale().x * m.get_aabb().size.x < 1.1:
				continue
			var pts := PackedVector3Array()
			for q: Vector3 in hull.points:
				pts.append(xf.basis * q)
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			var body := StaticBody3D.new()
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			host.add_child(body)
			body.global_position = xf.origin
		i += 1


# --- charred trunks ------------------------------------------------------------------------------------

## Trunks the fire felled, lying in the burn and burned black (TreeGen logs; the bark tinted to char).
static func _logs(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> int:
	var by_id := {}
	var n := 0
	var tries := 0
	while n < 34 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(Scorch.RECT.position.x, Scorch.RECT.end.x), rng.randf_range(-136.0, -18.0))
		var b := Scorch.burn(p.x, p.y)
		if b < 0.4 or b > 0.95 or Scorch.flow(p.x, p.y) > 0.02 or _blocked(p, 3.0):
			continue
		var y := _ground(space, p.x, p.y)
		if is_nan(y) or y < -3.0:
			continue
		var yaw := rng.randf() * TAU
		var dir := Vector2(sin(yaw), cos(yaw))
		var ok := true
		for t: float in [-2.6, 2.6]:
			var q := p + dir * t
			var gq := _ground(space, q.x, q.y)
			if is_nan(gq) or absf(gq - y) > 0.9 or _blocked(q, 0.5):
				ok = false
		if not ok:
			continue
		var id := "log_%d" % rng.randi_range(0, 1)
		if not by_id.has(id):
			by_id[id] = []
		var s := rng.randf_range(0.9, 1.3)
		(by_id[id] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(p.x, y - 0.05, p.y)))
		n += 1
	for id: String in by_id:
		var d: Dictionary = TreeGen.kind(id)
		var mesh: Mesh = d.get("solid")
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		var xfs: Array = by_id[id]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
			mm.set_instance_color(k, CHAR * rng.randf_range(0.85, 1.1))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CharredLogs_" + id
		mmi.multimesh = mm
		mmi.visibility_range_end = 110.0
		mmi.visibility_range_end_margin = 15.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)
	return n


# --- steam and smoke -------------------------------------------------------------------------------------

## Steam where each flow's front stopped in wet ground; thin smoke off the warm crust near the lip.
static func _steam(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> int:
	var n := 0
	for f: Dictionary in Scorch.flows():
		var pts: Array = f.pts
		var end: Vector2 = pts[pts.size() - 1]
		var prev: Vector2 = pts[pts.size() - 2]
		var hw: float = (f.hw as Array)[(f.hw as Array).size() - 1]
		var front := end + (end - prev).normalized() * hw * 0.8
		var y := _ground(space, front.x, front.y)
		if is_nan(y):
			continue
		var wet := y < 0.2                              # down at the fen's water: the front boils it
		var steam := Vfx.emitter(Color(0.62, 0.66, 0.72, 0.16 if wet else 0.1), {"count": 14 if wet else 8, "life": 7.0, "speed": Vector2(0.5, 1.2),
			"size": 2.6, "gravity": 0.35, "radius": hw * 0.4, "spread": 18.0, "additive": false, "turbulence": true, "damping": 0.25, "grow": 0.4})
		if steam:
			steam.name = "FlowSteam"
			steam.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 16, 16))
			steam.preprocess = 7.0
			host.add_child(steam)
			steam.global_position = Vector3(front.x, y + 0.4, front.y)
			steam.emitting = true
			n += 1
		# the crust's warm reach near the lip smokes a little
		var src: Vector2 = pts[1]
		var ys := _ground(space, src.x, src.y)
		if not is_nan(ys):
			var smoke := Vfx.emitter(Color(0.14, 0.12, 0.12, 0.28), {"count": 10, "life": 6.0, "speed": Vector2(0.6, 1.4), "size": 1.8, "gravity": 0.3,
				"radius": 1.2, "spread": 12.0, "additive": false, "turbulence": true, "damping": 0.2, "grow": 0.5})
			if smoke:
				smoke.name = "CrustSmoke"
				smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
				smoke.preprocess = 6.0
				host.add_child(smoke)
				smoke.global_position = Vector3(src.x, ys + 0.2, src.y)
				smoke.emitting = true
				n += 1
	return n

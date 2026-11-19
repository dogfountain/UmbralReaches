extends Node
## Soundness probe for the visual and performance pass (docs/r39/visual_perf.md): builds the real night and tests, with
## coordinates, the places the map audit and the combat pass left open, the way a player would meet them:
##   hall    the Bone Abbot's pit hall (world/areas/ossuary/oss_hall.gd): rays out from the floor at three heights on
##           every bearing (a gap in the wall), rays down round the floor's edge (a hole), and the wanderer walking and
##           Rift-Stepping outward from the floor's edge on every bearing (where does the body end up?)
##   crown   the Speaking Crown's siege yard: a ray grid for holes under the yard, and Rift Steps outward from a ring
##           of spots toward the earthwork (MA4: down through the yard)
##   step    the same Rift Step fan at any --at=x,z (r 4..--r)
##   engaged the first Events.boss_engaged: each listener called on its own and timed, first call and second
##   godot --path . res://zz/visual_probe.tscn -- --only=hall,crown [--at=x,z --r=30]
## Prints "VPROBE ..." lines; a finding starts "VPROBE BAD".

const OssHall := preload("res://world/areas/ossuary/oss_hall.gd")
const Hierarch := preload("res://core/world/realm/realm_pois_hierarch.gd")

var only: Array = []
var at2 := Vector2.INF
var ring_r := 30.0
var main: Node
var p: Player
var t0 := 0
var started := false
var bad := 0


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a.begins_with("--at="):
			var v := a.trim_prefix("--at=")
			at2 = Vector2(float(v.get_slice(",", 0)), float(v.get_slice(",", 1)))
		elif a.begins_with("--r="):
			ring_r = float(a.trim_prefix("--r="))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	Travel._busy = true
	if started:
		return
	if Time.get_ticks_msec() - t0 > 400000:
		print("VPROBE never got a world")
		get_tree().quit(3)
		return
	if is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p != null:
			started = true
			_run.call_deferred()


func _physics_process(_d: float) -> void:
	if p != null:
		p.gloom = 0.0                          # (the dark is not what is probed: a long stand underground hollowed him)
		p.wounds = 0.0


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return _space().intersect_ray(PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, [p.get_rid()]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _bad(s: String) -> void:
	bad += 1
	print("VPROBE BAD " + s)


func _run() -> void:
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		(e as Node3D).visible = false
		for cs in (e as Node).find_children("*", "CollisionShape3D", true, false):
			(cs as CollisionShape3D).disabled = true
	await _frames(30)
	if _want("hall"):
		await _hall()
	if _want("hallwalk"):
		await _walk_fan("hall", OssHall.WC, 26.0, 6.0, OssHall.WALL_R + 0.6, OssHall.wat(0.0, 0.0).y - 1.0)
		await _shove_fan()
	if _want("crown"):
		await _crown()
	if _want("crownwalk"):
		# MA4: walk outward on every bearing from rings round the yard's centre and round the reported spot; a body that
		# ends 2 m under the ground it started on has gone through
		var c := Vector3(Hierarch.HEAD_C.x, Hierarch.FLOOR_Y, Hierarch.HEAD_C.y)
		for at: Vector2 in [Vector2(c.x, c.z), Vector2(-207.5, 171.6), Vector2(-216.8, 169.7)]:
			await _under_walk(at)
	if _want("engaged"):
		await _engaged()
	if _want("chapel"):
		await _chapel()
	if _want("countdoor"):
		_countdoor()
	if _want("apse"):
		await _apse()
	if _want("deadzone"):
		_deadzone()
	if _want("probebody"):
		await _probe_body()
	if _want("sig"):
		_sig()
	if _want("step") and at2 != Vector2.INF:
		var g := _ground(at2.x, at2.y, 80.0)
		await _step_fan("step", Vector3(at2.x, g, at2.y), 4.0, ring_r, 8, 24)
	print("VPROBE done, %d findings" % bad)
	get_tree().quit(0)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


## The NE chapel (315 deg), where the walk and shove fans left the hall: rays from inside out on each degree at three heights,
## once hitting back faces and once not (a body passes a face it meets from behind), then a walk traced every 10 frames.
func _chapel() -> void:
	var fy := OssHall.wat(0.0, 0.0).y
	for deg in range(300, 331, 1):
		var line := PackedStringArray()
		for hgt: float in [0.4, 1.1, 1.9]:
			var a := OssHall.wat(float(deg), 27.0, OssHall.FLOOR_Y + hgt)
			var b := OssHall.wat(float(deg), 56.0, OssHall.FLOOR_Y + hgt)
			var both := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, [p.get_rid()])
			var front := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, [p.get_rid()])
			front.hit_back_faces = false
			var h1 := _space().intersect_ray(both)
			var h2 := _space().intersect_ray(front)
			var r1 := OssHall.wflat_r(h1.position as Vector3) if not h1.is_empty() else -1.0
			var r2 := OssHall.wflat_r(h2.position as Vector3) if not h2.is_empty() else -1.0
			line.append("%.1f:%.1f/%.1f%s" % [hgt, r1, r2, ("" if h2.is_empty() else " " + String((h2.collider as Node).name))])
		print("VPROBE chapel %d deg: %s" % [deg, " | ".join(line)])
	# shape queries against the chapel's back wall: a capsule overlapping it, a capsule cast through it, the body's own test_move
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	for deg: float in [311.0, 315.0, 313.0]:
		var at := OssHall.wat(deg, 44.1, OssHall.FLOOR_Y + 1.0)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = Layers.WORLD
		q.transform = Transform3D(Basis.IDENTITY, at)
		var hits := _space().intersect_shape(q, 8)
		var names := PackedStringArray()
		for h: Dictionary in hits:
			names.append(String((h.collider as Node).name))
		var from := OssHall.wat(deg, 40.0, OssHall.FLOOR_Y + 1.0)
		var to := OssHall.wat(deg, 48.0, OssHall.FLOOR_Y + 1.0)
		q.transform = Transform3D(Basis.IDENTITY, from)
		q.motion = to - from
		var fr := _space().cast_motion(q)
		p.teleport(from + Vector3.DOWN * 0.95)
		await _frames(2)
		var tm := p.test_move(p.global_transform, to - from)
		print("VPROBE chapel shapes %d deg: overlap %s | cast %s | test_move %s" % [int(deg), ",".join(names), str(fr), str(tm)])
	# the floor near the chapel's back corner: rays down at points along the 315 chapel's axis and across it
	var ax := deg_to_rad(315.0)
	var radial := Vector3(cos(ax), 0.0, sin(ax))
	var side := radial.cross(Vector3.UP).normalized()
	for al: float in [41.5, 42.5, 42.9, 43.1, 43.4, 43.7]:
		var line := PackedStringArray()
		for lat: float in [-3.1, -2.9, -2.5, -1.5, 0.0, 1.5, 2.9]:
			var lp := OssHall.C + radial * al + side * lat
			var wp := OssFrame.w(Vector3(lp.x, OssHall.FLOOR_Y + 1.0, lp.z))
			var h := _ray(wp, wp + Vector3.DOWN * 3.0)
			line.append("%.1f:%s" % [lat, ("-" if h.is_empty() else "%.2f %s" % [(h.position as Vector3).y - fy, String((h.collider as Node).name).left(5)])])
		print("VPROBE chapel floor along %.1f: %s" % [al, " | ".join(line)])
	# the catch under the floor: is it there, and does it take a body put under the floor?
	var uc := main.find_child("UnderCatch", true, false) as Area3D
	if uc == null:
		print("VPROBE chapel catch: no UnderCatch")
	else:
		var cs := uc.get_child(0) as CollisionShape3D
		print("VPROBE chapel catch at %s size %s monitoring %s mask %d in tree %s" % [uc.global_position.snapped(Vector3.ONE * 0.1), (cs.shape as BoxShape3D).size, uc.monitoring, uc.collision_mask, uc.is_inside_tree()])
		var under := OssHall.wat(311.0, 46.0, OssHall.FLOOR_Y - 6.0)
		p.teleport(under)
		for f in 30:
			await get_tree().physics_frame
			if f % 5 == 0:
				print("VPROBE chapel catch f%d pos %s r %.1f overlaps %d" % [f, p.global_position.snapped(Vector3.ONE * 0.1), OssHall.wflat_r(p.global_position), uc.get_overlapping_bodies().size()])
	for deg: float in [309.0, 311.0, 313.0, 317.0, 319.0]:
		var start := OssHall.wat(deg, 27.5, OssHall.FLOOR_Y + 0.15)
		var c := OssHall.WC
		var out := start - c
		out.y = 0.0
		out = out.normalized()
		p.teleport(start)
		await _frames(4)
		for f in 300:
			p.debug_drive(out, true)
			await get_tree().physics_frame
			var rr := OssHall.wflat_r(p.global_position)
			if deg == 311.0 and rr > 42.6 and rr < 45.0:
				var cols := PackedStringArray()
				for ci in p.get_slide_collision_count():
					var kc := p.get_slide_collision(ci)
					cols.append("%s n%s" % [String((kc.get_collider() as Node).name) if kc.get_collider() is Node else "?", kc.get_normal().snapped(Vector3.ONE * 0.01)])
				var pcap := p._col.shape as CapsuleShape3D
				var tmv := p.test_move(p.global_transform, Vector3.DOWN * 0.2)
				print("VPROBE chapel contact f%d r %.2f wall %s floor %s v %s cols [%s] pos %s | col dis %s h %.2f r %.2f at %s layer %d mask %d exc %d tm %s mantle %.2f slide %s" % [f, rr, p.is_on_wall(), p.is_on_floor(), p.velocity.snapped(Vector3.ONE * 0.01), ", ".join(cols), p.global_position.snapped(Vector3.ONE * 0.01), p._col.disabled, pcap.height, pcap.radius, p._col.position, p.collision_layer, p.collision_mask, p.get_collision_exceptions().size(), tmv, p._mantle_t, p._sliding])
			if f % 10 == 0:
				var q := p.global_position
				print("VPROBE chapel walk %d f%d r %.2f y %.2f deg %.1f (local %s)" % [int(deg), f, OssHall.wflat_r(q), q.y - fy, OssHall.wang_of(q), OssFrame.l(q).snapped(Vector3.ONE * 0.01)])
		p.debug_drive(Vector3.ZERO)


## The Count door's view (map audit F27): from the threshold's eye, a fan of rays east and south-east; what each meets
## first, from the front and from behind (a ray that meets only a back face is looking at the land's underside).
func _countdoor() -> void:
	const OSS := preload("res://world/areas/ossuary/ossuary.gd")
	var eye := OssFrame.w(Vector3(26.5, OSS.PIT_Y + 1.7, OssHall.DOOR_Z))
	for yd: float in [-0.3, 0.0, 0.3]:
		for ad in range(-10, 75, 8):
			var a := deg_to_rad(float(ad))
			var dl := Vector3(cos(a), yd, sin(a)).normalized()           # local: +x into the bank, +z south
			var dw := OssFrame.wd(dl)
			var both := PhysicsRayQueryParameters3D.create(eye, eye + dw * 80.0, Layers.WORLD, [p.get_rid()])
			var front := PhysicsRayQueryParameters3D.create(eye, eye + dw * 80.0, Layers.WORLD, [p.get_rid()])
			front.hit_back_faces = false
			var h1 := _space().intersect_ray(both)
			var h2 := _space().intersect_ray(front)
			var s1 := "-" if h1.is_empty() else "%.1f %s %s" % [eye.distance_to(h1.position as Vector3), String((h1.collider as Node).name).left(14), OssFrame.l(h1.position as Vector3).snapped(Vector3.ONE * 0.1)]
			var s2 := "-" if h2.is_empty() else "%.1f %s" % [eye.distance_to(h2.position as Vector3), String((h2.collider as Node).name).left(14)]
			print("VPROBE countdoor dir %d deg, dy %.1f: both %s | front %s" % [ad, yd, s1, s2])


## Where do queries stop finding the chapel's floor? A world-aligned grid round the 315 chapel's apse, a ray down at each
## point from 0.5 m over the floor: '#' hit, '.' nothing; and the same with the player moved far away.
func _deadzone() -> void:
	var fy := OssHall.wat(0.0, 0.0).y
	var ax := deg_to_rad(315.0)
	var cen := OssFrame.w(OssHall.C + Vector3(cos(ax), 0.0, sin(ax)) * 42.0)
	var tb := CharacterBody3D.new()
	tb.collision_layer = 0
	tb.collision_mask = Layers.WORLD
	var tcs := CollisionShape3D.new()
	var tcap := CapsuleShape3D.new()
	tcap.radius = 0.35
	tcap.height = 1.7
	tcs.shape = tcap
	tcs.position = Vector3(0, 0.85, 0)
	tb.add_child(tcs)
	main.add_child(tb)
	tb.global_position = Vector3(0.0, 60.0, 0.0)
	for pass_i in 3:
		if pass_i == 1:
			p.teleport(Vector3(0.0, 40.0, 0.0))
		var lines := PackedStringArray()
		for j in range(-8, 9):
			var row := ""
			for i in range(-8, 9):
				var q := Vector3(cen.x + float(i) * 0.5, fy, cen.z + float(j) * 0.5)
				if pass_i == 2:
					# a fresh body standing there: does it find the floor under it?
					tb.global_position = q + Vector3.UP * 0.03
					row += "#" if tb.test_move(tb.global_transform, Vector3.DOWN * 0.2) else "."
					continue
				var h := _ray(q + Vector3.UP * 0.5, q + Vector3.DOWN * 0.5)
				row += "#" if not h.is_empty() else "."
			lines.append(row)
		print("VPROBE deadzone (%s) round %s, x -> +x, rows +z:\n%s" % [["rays", "rays, player away", "a body's test_move"][pass_i], cen.snapped(Vector3.ONE * 0.1), "\n".join(lines)])


## A fresh CharacterBody3D (the wanderer's capsule) at points along the 315 chapel's axis: does its own test_move see the
## floor under it, and does a space query of the same capsule there see it? (MA1: the wanderer's did not past r ~43.)
func _probe_body() -> void:
	var tb := CharacterBody3D.new()
	tb.collision_layer = 0
	tb.collision_mask = Layers.WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	tb.add_child(cs)
	main.add_child(tb)
	var ax := deg_to_rad(315.0)
	var radial := Vector3(cos(ax), 0.0, sin(ax))
	for al: float in [30.0, 36.0, 38.0, 40.0, 41.5, 42.5, 43.0, 43.5]:
		var lp := OssHall.C + radial * al
		var wp := OssFrame.w(Vector3(lp.x, OssHall.FLOOR_Y + 0.03, lp.z))
		tb.global_position = wp
		p.teleport(wp)
		await _frames(3)
		var t1 := tb.test_move(tb.global_transform, Vector3.DOWN * 0.2)
		var t2 := p.test_move(p.global_transform, Vector3.DOWN * 0.2)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = Layers.WORLD
		q.transform = Transform3D(Basis.IDENTITY, wp + Vector3(0, 0.85 - 0.1, 0))
		var hits := _space().intersect_shape(q, 8)
		var names := PackedStringArray()
		for h: Dictionary in hits:
			names.append(String((h.collider as Node).name))
		var ray := _ray(wp + Vector3.UP * 0.5, wp + Vector3.DOWN * 0.5)
		print("VPROBE body along %.1f: fresh %s wanderer %s | capsule 10 cm low meets [%s] | ray %s" % [al, t1, t2, ",".join(names), "-" if ray.is_empty() else String((ray.collider as Node).name)])
	tb.queue_free()
	# the chapel floor's own faces near the apse's end: VaultBody's triangles whose middle lies within 1.2 m (xz) of the axis
	# points 42.0 .. 43.6, with their height and size
	var vb := main.find_child("VaultBody", true, false) as StaticBody3D
	if vb != null:
		var sh := (vb.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
		var f := sh.get_faces()
		var bx := vb.global_transform
		print("VPROBE body VaultBody %d faces, body at %s" % [f.size() / 3, vb.global_position.snapped(Vector3.ONE * 0.01)])
		for al: float in [42.0, 42.8, 43.2, 43.6]:
			var lp := OssHall.C + radial * al
			var wp := OssFrame.w(Vector3(lp.x, OssHall.FLOOR_Y, lp.z))
			var near := PackedStringArray()
			for t in range(0, f.size(), 3):
				var a := bx * f[t]
				var b := bx * f[t + 1]
				var c := bx * f[t + 2]
				var m := (a + b + c) / 3.0
				# the triangle covers the point in plan (barycentric in xz) and lies near the floor's height
				var v0 := Vector2(c.x - a.x, c.z - a.z)
				var v1 := Vector2(b.x - a.x, b.z - a.z)
				var v2 := Vector2(wp.x - a.x, wp.z - a.z)
				var den := v0.x * v1.y - v1.x * v0.y
				if absf(den) < 1e-6 or absf(m.y - wp.y) > 3.0:
					continue
				var u := (v2.x * v1.y - v1.x * v2.y) / den
				var w := (v0.x * v2.y - v2.x * v0.y) / den
				if u >= 0.0 and w >= 0.0 and u + w <= 1.0:
					near.append("y%.2f n%s A%.2f" % [m.y - wp.y, (b - a).cross(c - a).normalized().snapped(Vector3.ONE * 0.1), (b - a).cross(c - a).length() * 0.5])
			print("VPROBE body faces near along %.1f: %d: %s" % [al, near.size(), " ; ".join(near.slice(0, 10))])
	var aps := main.find_child("ApseSolids", true, false) as StaticBody3D
	if aps != null:
		for cs2 in aps.get_children():
			var c2 := cs2 as CollisionShape3D
			var lc := OssFrame.l(c2.global_position)
			var rr2 := Vector2(lc.x - OssHall.C.x, lc.z - OssHall.C.z)
			print("VPROBE body apse solid at local %s (r %.2f, %.1f deg) size %s" % [lc.snapped(Vector3.ONE * 0.01), rr2.length(), rad_to_deg(rr2.angle()), (c2.shape as BoxShape3D).size])


## The NE chapel's apse: the body put at rest on a grid of floor points; does it stay on the floor, does test_move see the
## floor under it, and what are its collision exceptions (MA1: it fell through at r ~43 from rest).
func _apse() -> void:
	var ax := deg_to_rad(315.0)
	var radial := Vector3(cos(ax), 0.0, sin(ax))
	var side := radial.cross(Vector3.UP).normalized()
	var fy := OssHall.wat(0.0, 0.0).y
	print("VPROBE apse exceptions %d mask %d layer %d" % [p.get_collision_exceptions().size(), p.collision_mask, p.collision_layer])
	for al: float in [41.0, 42.0, 42.6, 43.0, 43.3]:
		var line := PackedStringArray()
		for lat: float in [-2.6, -1.5, 0.0, 1.5, 2.6]:
			var lp := OssHall.C + radial * al + side * lat
			var wp := OssFrame.w(Vector3(lp.x, OssHall.FLOOR_Y + 0.05, lp.z))
			p.teleport(wp)
			p.velocity = Vector3.ZERO
			await _frames(2)
			var tm := p.test_move(p.global_transform, Vector3.DOWN * 0.3)
			await _frames(28)
			line.append("%.1f:%s%s" % [lat, "T" if tm else "f", "%.2f" % (p.global_position.y - fy)])
		print("VPROBE apse along %.1f: %s" % [al, " | ".join(line)])


## Walk outward from `at` on 72 bearings for 5 s each; any frame the body is 1.5 m under the land's own surface over it
## is a finding: it went through the ground.
func _under_walk(at: Vector2) -> void:
	var n_bad := 0
	for i in 72:
		var a := TAU * float(i) / 72.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var g := _ground(at.x + dir.x * 2.0, at.y + dir.z * 2.0, 80.0)
		if is_nan(g):
			continue
		p.teleport(Vector3(at.x + dir.x * 2.0, g + 0.1, at.y + dir.z * 2.0))
		p.velocity = Vector3.ZERO
		await _frames(4)
		for f in 300:
			p.debug_drive(dir, true)
			await get_tree().physics_frame
			if f % 3 != 0:
				continue
			var q := p.global_position
			var top := _ray(Vector3(q.x, q.y + 30.0, q.z), Vector3(q.x, q.y - 30.0, q.z))
			if not top.is_empty() and (top.position as Vector3).y > q.y + 1.5 and String((top.collider as Node).name).begins_with("Terrain"):
				n_bad += 1
				_bad("crown walk from %s at %d deg: under the surface at %s (surface %.1f, %s)" % [at, i * 5, q.snapped(Vector3.ONE * 0.1), (top.position as Vector3).y, (top.collider as Node).name])
				break
		p.debug_drive(Vector3.ZERO)
	print("VPROBE crown walk from %s: %d bearings went under" % [at, n_bad])


## The regions' signature props (region_dressing.gd): one line per prop, its kind and place (each cell's host keeps them).
func _sig() -> void:
	var n := 0
	for host in main.find_children("Sig_*", "Node3D", true, false):
		if not host.has_meta(&"props"):
			continue
		for it: Array in (host.get_meta(&"props") as Array):
			var c: Vector2 = it[0]
			print("VPROBE sig %s %s %.1f,%.1f,%.1f yaw %.2f" % [String(host.name), String(it[2]), c.x, c.y, float(it[1]), float(it[3])])
			n += 1
	print("VPROBE sig total %d" % n)


func _ground(x: float, z: float, from_y: float) -> float:
	var hit := _ray(Vector3(x, from_y, z), Vector3(x, from_y - 200.0, z))
	return float((hit.position as Vector3).y) if not hit.is_empty() else NAN


# --- the pit hall -------------------------------------------------------------------------------------------

func _hall() -> void:
	var fy := OssHall.wat(0.0, 0.0).y
	print("VPROBE hall centre %s floor y %.2f wall r %.1f floor r %.1f door %.1f deg" % [OssHall.WC, fy, OssHall.WALL_R, OssHall.FLOOR_R, OssHall.door_ang()])
	# 1) rays out from the floor at three heights
	var gaps := 0
	for i in 360:
		var deg := float(i)
		for up: float in [0.4, 1.1, 1.9]:
			var a := OssHall.wat(deg, 14.0, OssHall.FLOOR_Y + up)
			var b := OssHall.wat(deg, 48.0, OssHall.FLOOR_Y + up)
			var hit := _ray(a, b)
			var r := 99.0 if hit.is_empty() else OssHall.wflat_r(hit.position)
			if r > 44.5:
				gaps += 1
				_bad("hall ray out at %d deg, +%.1f m: nothing until r %.1f (%s)" % [i, up, r, "none" if hit.is_empty() else str((hit.position as Vector3).snapped(Vector3.ONE * 0.1))])
	print("VPROBE hall rays out: %d open" % gaps)
	# 2) rays down from 2 m over the floor, round the edge (r 28 .. 44): what is under each spot
	for i in 180:
		var deg := float(i) * 2.0
		var r := 28.0
		while r <= 44.0:
			var top := OssHall.wat(deg, r, OssHall.FLOOR_Y + 2.2)
			var hit := _ray(top, top + Vector3.DOWN * 30.0)
			if hit.is_empty() or (hit.position as Vector3).y < fy - 1.0:
				_bad("hall ray down at %d deg r %.1f: %s" % [int(deg), r, "nothing" if hit.is_empty() else "%.1f under the floor" % (fy - (hit.position as Vector3).y)])
			r += 1.0
	# 3) walk out from the floor's edge on every bearing, then Rift Step out
	await _walk_fan("hall", OssHall.WC, 26.0, 8.0, OssHall.WALL_R + 0.6, fy - 1.0)


## Walk (drive) and Rift Step outward from a ring of radius `r0` round `c` on 72 bearings; a body that ends past
## `r_out` from c or under `y_min` is a finding.
func _walk_fan(tag: String, c: Vector3, r0: float, secs: float, r_out: float, y_min: float) -> void:
	for mode: String in ["walk", "step"]:
		var worst := 0.0
		for i in 72:
			var a := TAU * float(i) / 72.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			var start := c + dir * r0
			var g := _ground(start.x, start.z, c.y + 3.0)
			if is_nan(g):
				continue
			start.y = g + 0.1
			p.teleport(start)
			p.velocity = Vector3.ZERO
			p.set_view(atan2(-dir.x, -dir.z), -0.1)
			p._face_now(dir)
			await _frames(6)
			var low := p.global_position.y
			var far := 0.0
			if mode == "walk":
				var n := int(secs * 60.0)
				for f in n:
					p.debug_drive(dir, true)
					await get_tree().physics_frame
					low = minf(low, p.global_position.y)
					far = maxf(far, Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length())
				p.debug_drive(Vector3.ZERO)
			else:
				for s in 4:
					p._step_t = 0.0
					p.shadowstep()
					for f in 40:
						await get_tree().physics_frame
						low = minf(low, p.global_position.y)
						far = maxf(far, Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length())
			worst = maxf(worst, far)
			var end := p.global_position
			if far > r_out or low < y_min:
				_bad("%s %s out at %d deg from r %.0f: reached r %.1f, lowest y %.1f (floor %.1f), ended %s" % [tag, mode, i * 5, r0, far, low, y_min + 1.0, end.snapped(Vector3.ONE * 0.1)])
		print("VPROBE %s %s fan: farthest r %.1f" % [tag, mode, worst])


# --- the Speaking Crown's yard -------------------------------------------------------------------------------

func _crown() -> void:
	var c := Vector3(Hierarch.HEAD_C.x, Hierarch.FLOOR_Y, Hierarch.HEAD_C.y)
	print("VPROBE crown yard centre %s" % c)
	# holes: from 1.6 m over the yard's own level and from high above, on a 1 m grid to 46 m
	var holes := 0
	for ix in range(-46, 47):
		for iz in range(-46, 47):
			var x := c.x + float(ix)
			var z := c.z + float(iz)
			if Vector2(ix, iz).length() > 46.0:
				continue
			var top := _ray(Vector3(x, 60.0, z), Vector3(x, -60.0, z))
			if top.is_empty():
				holes += 1
				_bad("crown no ground at all at (%.0f, %.0f)" % [x, z])
				continue
			# under the first surface: is there anything within 6 m below it (a shell over a void)?
			var y0 := float((top.position as Vector3).y)
			var under := _ray(Vector3(x, y0 - 0.05, z), Vector3(x, y0 - 40.0, z))
			if under.is_empty() and (top.collider as Node) != null and not String((top.collider as Node).name).begins_with("Terrain"):
				var land := _land_y(x, z)
				if land < y0 - 0.5 or is_nan(land):
					holes += 1
					_bad("crown a shell (%s) over no ground at (%.0f, %.1f, %.0f), land %.1f" % [(top.collider as Node).name, x, y0, z, land])
	print("VPROBE crown holes %d" % holes)
	await _step_fan("crown", c, 8.0, 31.0, 6, 24)


## The terrain's own surface (the Terrain body's faces only) under x,z.
func _land_y(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -60.0, z), Layers.WORLD, [p.get_rid()])
	var ex: Array[RID] = [p.get_rid()]
	for k in 8:
		q.exclude = ex
		var hit := _space().intersect_ray(q)
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain") or (hit.collider as Node).get_parent().name.begins_with("Terrain"):
			return float((hit.position as Vector3).y)
		ex.append(hit.rid)
	return NAN


## Rift Steps outward from rings round `c` (radii r0..r1 in `rings` steps, `n` bearings each), four steps a spot;
## the body must stay on the ground (nothing under the land's surface, no fall).
func _step_fan(tag: String, c: Vector3, r0: float, r1: float, rings: int, n: int) -> void:
	var worst := 0.0
	for k in rings:
		var r := lerpf(r0, r1, float(k) / maxf(1.0, float(rings - 1)))
		for i in n:
			var a := TAU * float(i) / float(n)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var start := c + dir * r
			var g := _ground(start.x, start.z, c.y + 30.0)
			if is_nan(g):
				continue
			start.y = g + 0.1
			p.teleport(start)
			p.velocity = Vector3.ZERO
			p.set_view(atan2(-dir.x, -dir.z), -0.1)
			p._face_now(dir)
			await _frames(4)
			for s in 3:
				p._step_t = 0.0
				var before := p.global_position
				p.shadowstep()
				var low := p.global_position.y
				for f in 45:
					await get_tree().physics_frame
					low = minf(low, p.global_position.y)
				var land := _land_y(p.global_position.x, p.global_position.z)
				var drop := before.y - low
				worst = maxf(worst, drop)
				if drop > 6.0 or (not is_nan(land) and low < land - 1.0):
					_bad("%s step from %s (r %.0f, %d deg, step %d): lowest y %.1f, land there %.1f, now %s" % [tag, before.snapped(Vector3.ONE * 0.1), r, int(rad_to_deg(a)), s,
						low, land, p.global_position.snapped(Vector3.ONE * 0.1)])
					break
	print("VPROBE %s step fan: worst drop %.1f m" % [tag, worst])


# --- the first pull: who pays for Events.boss_engaged ------------------------------------------------------------

func _engaged() -> void:
	var arena: BossArena = null
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id.contains("thornwarden"):
			arena = a as BossArena
	var boss := Node3D.new()
	boss.name = "ProbeBoss"
	get_tree().current_scene.add_child(boss)
	boss.global_position = arena.global_position if arena != null else p.global_position + Vector3(0, 0, -8)
	p.teleport(boss.global_position + Vector3(0, 0.2, 8.0))
	await _frames(20)
	for round_i in 2:
		var tot := 0.0
		for c: Dictionary in Events.boss_engaged.get_connections():
			var cb := c.callable as Callable
			var t0u := Time.get_ticks_usec()
			cb.call(boss, "The Thornwarden")
			var ms := (Time.get_ticks_usec() - t0u) / 1000.0
			tot += ms
			print("VPROBE engaged %s %s.%s %.2f ms" % ["first" if round_i == 0 else "again", (cb.get_object() as Object).get_script().resource_path.get_file() if cb.get_object() != null and (cb.get_object() as Object).get_script() != null else str(cb.get_object()), cb.get_method(), ms])
		var t1 := Time.get_ticks_usec()
		await get_tree().process_frame
		await get_tree().process_frame
		print("VPROBE engaged %s total %.2f ms (next two frames %.2f ms)" % ["first" if round_i == 0 else "again", tot, (Time.get_ticks_usec() - t1) / 1000.0])
		await _frames(30)
	boss.queue_free()


## The crozier's shove on the floor's edge (a heavy blow pushes the wanderer off it at up to 4 m/s): from r 27 on 72 bearings,
## shoved outward every 0.4 s for 3 s; and down the raid door's corridor.
func _shove_fan() -> void:
	var c := OssHall.WC
	var fy := OssHall.wat(0.0, 0.0).y
	var worst := 0.0
	for i in 72:
		var a := TAU * float(i) / 72.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var deg := OssHall.wang_of(c + dir * 10.0)
		var start := OssHall.wat(deg, 27.5, OssHall.FLOOR_Y + 0.15)
		p.teleport(start)
		await _frames(4)
		var out := (start - c)
		out.y = 0.0
		out = out.normalized()
		var low := p.global_position.y
		var far := 0.0
		for f in 180:
			if f % 24 == 0:
				p.velocity += out * 4.0
			p.debug_drive(out, true)
			await get_tree().physics_frame
			low = minf(low, p.global_position.y)
			far = maxf(far, Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length())
		p.debug_drive(Vector3.ZERO)
		worst = maxf(worst, far)
		if low < fy - 1.0 or far > OssHall.WALL_R + 0.6:
			_bad("hall shove out at hall %d deg: reached r %.1f, lowest y %.1f (floor %.1f), ended %s" % [int(deg), far, low, fy, p.global_position.snapped(Vector3.ONE * 0.1)])
	print("VPROBE hall shove fan: farthest r %.1f" % worst)

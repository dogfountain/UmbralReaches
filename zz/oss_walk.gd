extends Node
## The Ossuary walk (the redesign, 21 Nov): the REAL Player (debug_drive: capsule, gravity, step-up) from the lane to the Pit Hall
## and every branch, no teleports along a route:
##   descent  oss_lane -> the Landing -> the bone bridge -> the gate hall -> the north stair -> the niche gallery -> the
##            pit stair -> the charnel pit -> the chapel and back -> the Counting Door -> eight flights -> the raid door
##   abbey    the church on the bank: the downs_track along its north wall, the gable's end, the back, the tower's foot
##   count    the sexton's slab, the chapel flight, the cells, the drum, the cage up to the gallery
## godot --path . res://zz/oss_walk.tscn [-- --only=descent,abbey,count]   (headless is fine)
## Prints "OSSWALK ok|FAIL ..." per route and "OSSWALK DONE n fails".
const State := preload("res://core/life/secrets/state.gd")
const Hall := preload("res://world/areas/ossuary/oss_hall.gd")

var main: Node
var p: Player
var fails := 0
var only: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	Travel.set("_busy", true)
	Travel.bosses_slain.clear()
	Travel.system_state("secrets").clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _physics_process(_d: float) -> void:
	if p and is_instance_valid(p):
		p.gloom = 0.0
		p.wounds = 0.0
	if Engine.get_physics_frames() % 20 == 0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not n.has_meta("elite"):
				(n as Node).queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _want(id: String) -> bool:
	return only.is_empty() or id in only


func ok(label: String, good: bool) -> void:
	if not good:
		fails += 1
	print("OSSWALK %s %s" % ["ok  " if good else "FAIL", label])


func _wait_world() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		if main.is_inside_tree() and main.has_meta("realm_done"):
			var d := main.find_child("LowerCount", true, false)
			if d and bool(d.get("built")) and main.find_child("CountCut", true, false) != null and main.find_child("Abbey", true, false) != null:
				break
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return p != null


func _ow(pts: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector3 in pts:
		var q := OssFrame.w(v)
		out.append(Vector3(q.x, v.y, q.z))
	return out


func _teleport(at: Vector3) -> void:
	var sp := (main as Node3D).get_world_3d().direct_space_state
	var y := at.y if absf(at.y) > 0.01 else RealmLayout.ground(sp, at.x, at.z) + 0.9
	p.global_position = Vector3(at.x, y, at.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _walk_pts(label: String, pts: Array[Vector3], end_y := NAN, tol := 0.8) -> bool:
	var prev := p.global_position
	for i in pts.size():
		var goal := pts[i]
		var t := 0.0
		var limit := 6.0 + Vector2(goal.x - prev.x, goal.z - prev.z).length() / 2.0
		while true:
			var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
			if d.length() < 0.55:
				break
			t += get_physics_process_delta_time()
			if t > limit:
				print("OSSWALK STUCK %s leg %d goal %s at %s (local %s)" % [label, i, Vector2(goal.x, goal.z), p.global_position.snapped(Vector3.ONE * 0.01), OssFrame.l(p.global_position).snapped(Vector3.ONE * 0.01)])
				_blockers()
				p.debug_drive(Vector3.ZERO)
				return false
			p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)
			await get_tree().physics_frame
		prev = goal
	p.debug_drive(Vector3.ZERO)
	await _frames(10)
	var lp := OssFrame.l(p.global_position)
	print("OSSWALK %s done at local (%.1f, %.1f, %.1f)" % [label, lp.x, lp.y, lp.z])
	if not is_nan(end_y) and absf(lp.y - end_y) > tol:
		print("OSSWALK %s ended at local y %.2f, wanted %.2f" % [label, lp.y, end_y])
		return false
	return true


func _blockers() -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, p.global_position + Vector3.UP * 0.9)
	q.exclude = [p.get_rid()]
	for hit: Dictionary in p.get_world_3d().direct_space_state.intersect_shape(q, 12):
		var c := hit.get("collider") as CollisionObject3D
		if c != null and c.name != "TerrainBody":
			print("  BLOCKER %s" % c.get_path())


func _run() -> void:
	ok("world built (the abbey, the count cut, the Lower Count)", await _wait_world())
	if p == null:
		get_tree().quit(1)
		return
	for w in main.find_children("*", "", true, false):
		if w is WardSeal:
			(w as WardSeal).release()
	var wf := main.find_child("Wayfarers", true, false)
	if wf:
		wf.queue_free()
	await _frames(30)
	if _want("descent"):
		await _descent()
	if _want("abbey"):
		await _abbey()
	if _want("count"):
		await _count()
	print("OSSWALK DONE %d fails" % fails)
	get_tree().quit(1 if fails > 0 else 0)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


func _descent() -> void:
	var lane: Array[Vector3] = [Vector3(-41.5, 0, 141.0), Vector3(-40.0, 0, 147.0)]
	_teleport(Vector3(-40.0, 0.0, 134.5))
	await _frames(20)
	ok("lane to the Landing", await _walk_pts("lane", lane))
	var pts: Array = []
	for v: Array in [[-10.0, -34.0], [-1.0, -34.0], [8.0, -34.0], [17.0, -34.0], [19.5, -36.0], [23.0, -37.0]]:
		pts.append(Vector3(v[0], 0, v[1]))
	ok("the bone bridge into the gate hall, to the stair head", await _walk_pts("bridge", _ow(pts), Ossuary.HALL_Y, 0.9))
	pts = []
	for v: Array in [[23.0, -41.0], [23.0, -45.0], [23.0, -49.5], [23.0, -52.5], [20.5, -55.0], [20.5, -61.0], [21.0, -65.5]]:
		pts.append(Vector3(v[0], 0, v[1]))
	ok("down the north stair, through the gallery to its far door", await _walk_pts("gallery", _ow(pts), Ossuary.GAL_Y, 0.9))
	pts = []
	for v: Array in [[21.0, -69.0], [21.0, -73.0], [21.0, -77.0], [20.5, -80.0], [17.5, -84.0]]:
		pts.append(Vector3(v[0], 0, v[1]))
	ok("down the pit stair onto the charnel pit", await _walk_pts("pit", _ow(pts), Ossuary.PIT_Y, 0.9))
	pts = []
	for v: Array in [[16.0, -92.0], [16.0, -97.5], [14.5, -100.5], [14.5, -104.0], [16.0, -98.0], [17.0, -92.0], [21.0, -86.0]]:
		pts.append(Vector3(v[0], 0, v[1]))
	ok("the chapel and back", await _walk_pts("chapel", _ow(pts), Ossuary.PIT_Y, 0.9))
	var lanes := [(Hall.LANE_A.x + Hall.LANE_A.y) * 0.5, (Hall.LANE_B.x + Hall.LANE_B.y) * 0.5]
	var dz := Hall.DOOR_Z
	var zn := (Hall.ZN + Hall.ZN_OUT) * 0.5
	var sp: Array = [Vector3(24.5, 0, dz), Vector3(28.6, 0, dz), Vector3(lanes[0], 0, dz)]
	for i in range(1, Hall.FLIGHTS + 1):
		var ln: float = lanes[0] if i % 2 == 1 else lanes[1]
		var other: float = lanes[1] if i % 2 == 1 else lanes[0]
		var end_z := zn if i % 2 == 1 else dz
		sp.append(Vector3(ln, 0, end_z))
		if i < Hall.FLIGHTS:
			sp.append(Vector3(other, 0, end_z))
	sp.append(Vector3(Hall.SX1 + 0.9, 0, dz))
	var da := Hall.door_ang()
	for r: float in [Hall.TIER_A.x + 3.4, Hall.TIER_A.x + 1.0]:
		var q := Hall.at(da, r)
		sp.append(Vector3(q.x, 0, q.z))
	ok("the Counting Door, eight flights, the raid door", await _walk_pts("stair", _ow(sp), Hall.FLOOR_Y, 0.9))


func _abbey() -> void:
	var ab: Node = main.find_child("Abbey", true, false)
	ok("the abbey stands", ab != null and ab.get_node_or_null("AbbeyBody") != null)
	_teleport(OssFrame.w(Vector3(40.4, 0, -28.0)))
	await _frames(20)
	var a: Array = []
	for z: float in [-45.0, -62.0, -80.0, -100.0, -108.0]:
		a.append(Vector3(40.4, 0, z))
	ok("along the downs_track in front of the church (no snag, no wall on the road)", await _walk_pts("track", _ow(a)))
	a = [Vector3(52.0, 0, -112.0), Vector3(62.0, 0, -100.0), Vector3(62.0, 0, -60.0), Vector3(62.0, 0, -30.0), Vector3(52.0, 0, -24.0)]
	ok("round the gable, the back and the tower's foot", await _walk_pts("round", _ow(a)))
	# the church is a shell: a ray through the tower's base meets the wall, not the open air
	var sp := (main as Node3D).get_world_3d().direct_space_state
	var from := OssFrame.w(Vector3(30.0, 22.0, -35.0))
	var to := OssFrame.w(Vector3(52.0, 22.0, -35.0))
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))
	ok("the tower's wall is solid", not hit.is_empty())


func _count() -> void:
	var deep := main.find_child("LowerCount", true, false)
	var slab := deep.find_child("Slab", true, false)
	Travel.bosses_slain["bone_abbot"] = true
	_teleport(OssFrame.w(Vector3(16.0, Ossuary.PIT_Y + 0.4, -97.0)))
	await _frames(20)
	if slab:
		slab.call("interact", p)
	await _frames(200)
	var s := State.site("lower_count")
	var r: Dictionary = s.route
	var pts: Array[Vector3] = []
	for v: Vector3 in r.pts:
		pts.append(v)
	_teleport(r.from)
	await _frames(10)
	ok("the chapel flight into the Uncounted Cells", await _walk_pts("cells", pts, float(s.goal.y) if absf(float(s.goal.y)) > 0.001 else NAN, 1.5))
	# the cage: its pin out, a ride up to the gallery's west arcade, the step off into the gallery
	var rb := deep.find_child("RopeBottom", true, false)
	_teleport(OssFrame.w(Vector3(15.3, -1.9, -64.4)))
	await _frames(30)
	if rb:
		rb.call("interact", p)
	await _frames(20)
	ok("walk onto the cage", await _walk_pts("cage-on", _ow([Vector3(15.2, 0, -62.4)])))
	var chain := deep.find_child("HaulChain", true, false)
	if chain:
		chain.call("interact", p)
	var t0 := Time.get_ticks_msec()
	var lift: Node = deep.get("_lift")
	while Time.get_ticks_msec() - t0 < 20000 and lift != null and bool(lift.call("moving")):
		await get_tree().physics_frame
	await _frames(30)
	var ly := OssFrame.l(p.global_position).y
	ok("the cage rode up to the gallery (local y %.2f)" % ly, absf(ly - Ossuary.GAL_Y) < 0.8)
	ok("step off through the arcade into the niche gallery", await _walk_pts("cage-off", _ow([Vector3(17.2, 0, -62.1), Vector3(19.6, 0, -62.1)]), Ossuary.GAL_Y, 1.0))

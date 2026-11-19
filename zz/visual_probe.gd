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
	if _want("engaged"):
		await _engaged()
	if _want("step") and at2 != Vector2.INF:
		var g := _ground(at2.x, at2.y, 80.0)
		await _step_fan("step", Vector3(at2.x, g, at2.y), 4.0, ring_r, 8, 24)
	print("VPROBE done, %d findings" % bad)
	get_tree().quit(0)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


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

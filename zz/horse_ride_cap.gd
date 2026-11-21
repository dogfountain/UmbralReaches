extends Node
## The horse as a player sees it: the real Realm (world/main.tscn), the player's own follow camera (the real camera
## script, no extra camera), a real horse ridden by LIVE INPUT (Input actions: move, look, sprint, interact), shot at
## full size from the main viewport. Run windowed at a fixed 60 fps so every frame is on the clock:
##   godot --path . --fixed-fps 60 --resolution 1280x720 res://zz/horse_ride_cap.tscn -- --out=<dir> [--breed=palfrey]
## Segments (each saved as a contact sheet and a frame sequence, with the frame-to-frame numbers printed as "HRIDE"):
##   mount, walk_to_sprint, sprint, left_gentle, right_gentle, left_sharp, right_sharp, pack (ridden into a pack of
##   husks and fought from the saddle), dismount.
## Never writes the save (Travel._busy). Headless it runs the logic and takes no images.

const HorseScript := preload("res://core/world/mount/horse.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const CELL := Vector2i(427, 240)
const COLS := 6

var out := "/tmp/horse_ride_cap"
var breed := "palfrey"
var breeds: Array = []                   ## --breeds=a,b: each ridden through the same run, into <out>/<breed>
var only: Array = []                     ## --only=a,b: just these segments
var fps_k := 1.0                         ## --fps=144 (with --fixed-fps 144): the run is in 60 fps frames, scaled
var out_base := ""
var main: Node
var p: Player
var horse: Node3D
var headless := false
var t_start := 0
var started := false
var realm_s := -1.0
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var _pack: Array[Node3D] = []
var _samples: Array = []
var _recording := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t_start = Time.get_ticks_msec()
	headless = DisplayServer.get_name() == "headless"
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--breed="):
			breed = a.trim_prefix("--breed=")
		elif a.begins_with("--breeds="):
			breeds = Array(a.trim_prefix("--breeds=").split(",", false))
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a.begins_with("--fps="):
			fps_k = float(a.trim_prefix("--fps=")) / 60.0
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 90}
	out_base = out
	if breeds.is_empty():
		breeds = [breed]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	process_physics_priority = 100
	process_priority = 1000                  # after the horse, the rider and the camera have all been placed this frame


func _process(_d: float) -> void:
	Travel._busy = true
	var el := float(Time.get_ticks_msec() - t_start) / 1000.0
	if el > 1700.0:
		print("HRIDE watchdog")
		get_tree().quit(3)
		return
	if _recording and p != null and horse != null and is_instance_valid(horse):
		_sample()
	if not started and is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		if realm_s < 0.0:
			realm_s = el
		if el - realm_s > 4.0:
			started = true
			_run.call_deferred()


func _physics_process(_d: float) -> void:
	if p != null and is_instance_valid(p):
		p.gloom = 0.0
		p.wounds = 0.0


static func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(p.get_world_3d().direct_space_state, x, z)


func _find_runway() -> void:
	var best := 1.0e9
	var sp := p.get_world_3d().direct_space_state
	for c2: Vector2 in [Vector2(40, 20), Vector2(30, 60), Vector2(60, 15), Vector2(-20, 45), Vector2(20, 100), Vector2(-60, 70), Vector2(110, 30), Vector2(40, 130), Vector2(-90, 40)]:
		for k in 8:
			var yaw := TAU * float(k) / 8.0
			var d := _dir(yaw)
			var lo := 1.0e9
			var hi := -1.0e9
			var pen := 0.0
			for step in 41:
				var q := c2 + Vector2(d.x, d.z) * 4.0 * float(step)
				var y := _gy(q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
				if RealmLand.in_water(q.x, q.y) or not RealmLayout.BOUNDS.grow(-10.0).has_point(q):
					pen += 40.0
				var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.2, q.y), Vector3(q.x, y + 1.2, q.y) + d * 4.0, Layers.WORLD | Layers.PROPS))
				if not hit.is_empty():
					pen += 25.0
			var sc := (hi - lo) + pen
			if sc < best:
				best = sc
				start_pos = Vector3(c2.x, _gy(c2.x, c2.y), c2.y)
				start_yaw = yaw
	print("HRIDE runway ", start_pos, " yaw ", snappedf(start_yaw, 0.01), " score ", snappedf(best, 0.01))


func _release() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down", "sprint", "jump", "interact", "staff_strike"]:
		Input.action_release(a)


func _hold(a: String, s := 1.0) -> void:
	Input.action_press(a, s)


func _frames(n: int) -> void:
	for i in int(float(n) * fps_k):
		await get_tree().process_frame


## Put the horse and the wanderer back at the run's start, the horse standing, the wanderer on it, the camera behind.
func _reset_ride() -> void:
	_release()
	if p.riding != null:
		horse.dismount()
	await _frames(2)
	horse.global_position = start_pos
	horse.global_basis = Basis(Vector3.UP, start_yaw)
	horse.set("_yaw", start_yaw)
	horse.set("speed", 0.0)
	horse.reset_physics_interpolation()
	p.teleport(start_pos + Vector3.UP * 0.12 + _dir(start_yaw).cross(Vector3.UP) * 1.2)
	p.reset_physics_interpolation()
	p.set_view(start_yaw, -0.16)
	await _frames(20)
	horse.mount(p)
	await _frames(100)
	horse.reset_physics_interpolation()


func _run() -> void:
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	for vp in get_tree().get_nodes_in_group(&"vow_panel"):
		(vp as Node).remove_from_group(&"vow_panel")          # a vow offer would pause the run
	_find_runway()
	await _frames(420)                      # the zone's title and the first hints have gone by
	for b: String in breeds:
		breed = b
		horse = null
		for h in get_tree().get_nodes_in_group(&"horse"):
			if String(h.get("breed")) == breed:
				horse = h as Node3D
		if horse == null:
			print("HRIDE no horse of breed ", breed)
			continue
		var st := HorseScript.state()
		if not (st.owned as Array).has(breed):
			(st.owned as Array).append(breed)
		out = out_base if breeds.size() == 1 else out_base.path_join(breed)
		print("HRIDE breed ", breed)
		await _ride()
	print("HRIDE done")
	get_tree().quit(0)


func _want(label: String) -> bool:
	return only.is_empty() or only.has(label)


func _ride() -> void:
	# 1. mount: the real step up (the wanderer beside the horse)
	_release()
	horse.global_position = start_pos
	horse.global_basis = Basis(Vector3.UP, start_yaw)
	horse.set("_yaw", start_yaw)
	horse.reset_physics_interpolation()
	p.teleport(start_pos + Vector3.UP * 0.12 + _dir(start_yaw).cross(Vector3.UP) * 1.2)
	p.reset_physics_interpolation()
	p.set_view(start_yaw, -0.16)
	await _frames(30)
	await _segment("mount", 80, 4, 4, func(f: int) -> void:
		if f == 0:
			horse.mount(p))
	await _frames(40)
	# 2. a walk, then the sprint
	await _segment("walk_to_sprint", 260, 40, 5, func(f: int) -> void:
		_hold("move_forward", 0.5 if f < 90 else 1.0)
		if f >= 150:
			_hold("sprint"))
	# 3. flat out
	await _frames(1)
	await _segment("sprint", 150, 0, 5, func(_f: int) -> void:
		_hold("move_forward")
		_hold("sprint"))
	# 4. turns while sprinting: the camera swings on the look stick as a player's does, the stick forward
	for tn: Array in [["left_gentle", "look_left", 0.35, 0.0], ["right_gentle", "look_right", 0.35, 0.0], ["left_sharp", "look_left", 1.0, 1.0], ["right_sharp", "look_right", 1.0, 1.0]]:
		if not _want(String(tn[0])):
			continue
		await _reset_ride()
		await _segment(String(tn[0]), 330, 150, 5, func(f: int) -> void:
			_hold("move_forward")
			_hold("sprint")
			if f >= 150 and f < 240:
				_hold(String(tn[1]), float(tn[2]))
				if float(tn[3]) > 0.0:
					_hold("move_left" if String(tn[1]) == "look_left" else "move_right", 0.7)
			else:
				Input.action_release(String(tn[1]))
				Input.action_release("move_left")
				Input.action_release("move_right"))
	# 5. the pack: ridden into at a gallop, then fought from the saddle
	if _want("pack"):
		await _reset_ride()
		_spawn_pack()
		await _segment("pack", 400, 150, 4, func(f: int) -> void:
			if f < 220:
				_hold("move_forward")
				_hold("sprint")
			elif f < 320:
				_hold("move_forward", 0.5)
				if f % 25 == 0:
					Input.action_press("staff_strike")
				elif f % 25 == 3:
					Input.action_release("staff_strike")
			else:
				Input.action_release("move_forward")
				Input.action_release("sprint"))
		_release()
		for e in _pack:
			if is_instance_valid(e):
				e.queue_free()
	# 6. down: the interact key, as a player presses it
	if _want("dismount"):
		await _reset_ride()
		await _segment("dismount", 150, 20, 3, func(f: int) -> void:
			if f == 0:
				_hold("move_forward", 0.5)
			if f == 40:
				_release()
			if f == 80:
				var ev := InputEventAction.new()
				ev.action = &"interact"
				ev.pressed = true
				Input.parse_input_event(ev))
	_release()
	if p.riding != null:
		horse.dismount()
	await _frames(10)


func _spawn_pack() -> void:
	_pack.clear()
	var fwd := _dir(start_yaw)
	var right := fwd.cross(Vector3.UP)
	var scr := load("res://core/enemy/husk.gd") as GDScript
	var k := 0
	for row in 3:
		for col in 3:
			var at := start_pos + fwd * (48.0 + float(row) * 5.0) + right * (float(col - 1) * 4.5 + (3.0 if row == 1 else 0.0))
			at.y = _gy(at.x, at.z)
			var e := scr.new() as Enemy
			main.add_child(e)
			e.global_position = at + Vector3.UP * 0.1
			e.home = e.global_position
			e.wake()
			_pack.append(e)
			k += 1


## Run `frames` rendered frames, calling `drive(frame)` before each; from `cap_from` every `every`th frame is shot.
func _segment(label: String, frames: int, cap_from: int, every: int, drive: Callable) -> void:
	if not _want(label):
		return
	var shots: Array[Image] = []
	var ids: Array[int] = []
	_samples.clear()
	_recording = true
	var k := fps_k
	for f in int(float(frames) * k):
		drive.call(int(float(f) / k))
		await RenderingServer.frame_post_draw
		if not headless and f >= int(float(cap_from) * k) and (f - int(float(cap_from) * k)) % maxi(int(float(every) * k), 1) == 0:
			var im := get_viewport().get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			shots.append(im)
			ids.append(f)
	_recording = false
	_release()
	_report(label)
	_save(label, shots, ids)


func _sample() -> void:
	var rig: Node3D = horse.get("_rig")
	var skel: Skeleton3D = rig.get("skel") if rig != null else null
	if skel == null:
		return
	var cam := get_viewport().get_camera_3d()
	var piv: Node3D = p.get("_rig")
	var s := {"dbg": p.camera_ctl.dbg, "len": p._arm.spring_length, "shx": p._arm.position.x, "rise": p._cam.position.y, "piv": piv.global_position, "cam": cam.global_position, "camy": cam.global_basis.get_euler().y, "root": rig.global_position, "yaw": rig.global_basis.get_euler().y, "speed": float(horse.get("speed")), "air": bool(horse.get("_air")), "vy": float(horse.get("_vy"))}
	var vis: Node3D = p.get_node_or_null("Visual")
	if vis != null:
		s["rider"] = vis.global_position
		var barrel := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("barrel")).origin
		s["rel"] = rig.global_basis.inverse() * (vis.global_position - barrel)
	s["inside"] = _lens_inside()
	_samples.append(s)


## True when the lens sits in a solid that is not a thin trunk (cylinder under 1.2 m radius: it dithers away near the lens).
func _lens_inside() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.1
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, get_viewport().get_camera_3d().global_position)
	q.collision_mask = Layers.WORLD
	for hit: Dictionary in p.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var srid := PhysicsServer3D.body_get_shape(hit.rid as RID, int(hit.shape))
		if PhysicsServer3D.shape_get_type(srid) == PhysicsServer3D.SHAPE_CYLINDER:
			var d: Variant = PhysicsServer3D.shape_get_data(srid)
			var r := float((d as Dictionary).get("radius", 9.0)) if d is Dictionary else (float((d as Vector2).x) if d is Vector2 else 9.0)
			if r < 1.2:
				continue
		return true
	return false


func _report(label: String) -> void:
	var n := _samples.size()
	if n < 5:
		print("HRIDE %-16s too few samples (%d)" % [label, n])
		return
	var pj_i := 0
	var cj := 0.0
	var lj := 0.0
	var lj_i := 0
	var sj := 0.0
	var rj2 := 0.0
	var pj := 0.0
	var cy := 0.0
	var rj := 0.0
	var rj_i := 0
	var rel := 0.0
	var ys := 0.0
	var vmax := 0.0
	var cr := 0.0
	for i in range(2, n):
		var a: Dictionary = _samples[i - 2]
		var b: Dictionary = _samples[i - 1]
		var c: Dictionary = _samples[i]
		var ljd := absf(float(c.len) - 2.0 * float(b.len) + float(a.len))
		if ljd > lj:
			lj_i = i
		lj = maxf(lj, ljd)
		sj = maxf(sj, absf(float(c.shx) - 2.0 * float(b.shx) + float(a.shx)))
		rj2 = maxf(rj2, absf(float(c.rise) - 2.0 * float(b.rise) + float(a.rise)))
		var pjd := (((c.piv as Vector3) - (b.piv as Vector3)) - ((b.piv as Vector3) - (a.piv as Vector3))).length()
		if pjd > pj:
			pj_i = i
		pj = maxf(pj, (((c.piv as Vector3) - (b.piv as Vector3)) - ((b.piv as Vector3) - (a.piv as Vector3))).length())
		cj = maxf(cj, (((c.cam as Vector3) - (b.cam as Vector3)) - ((b.cam as Vector3) - (a.cam as Vector3))).length())
		cy = maxf(cy, absf(((c.cam as Vector3).y - (b.cam as Vector3).y) - ((b.cam as Vector3).y - (a.cam as Vector3).y)))
		var rjd := (((c.root as Vector3) - (b.root as Vector3)) - ((b.root as Vector3) - (a.root as Vector3))).length()
		if rjd > rj:
			rj = rjd
			rj_i = i
		ys = maxf(ys, absf(rad_to_deg(angle_difference(float(b.yaw), float(c.yaw)) - angle_difference(float(a.yaw), float(b.yaw)))) * 60.0)
		if c.has("rel") and b.has("rel"):
			rel = maxf(rel, ((c.rel as Vector3) - (b.rel as Vector3)).length())
		cr = maxf(cr, absf(rad_to_deg(angle_difference(float(b.camy), float(c.camy)))))
		vmax = maxf(vmax, float(c.speed))
	if pj > 0.02:
		var seq := []
		for k in range(maxi(pj_i - 4, 0), mini(pj_i + 3, n)):
			var q2: Dictionary = _samples[k]
			var pv: Vector3 = q2.piv
			seq.append("(%.1f,%.1f,%.1f)" % [pv.x * 100.0, pv.y * 100.0, pv.z * 100.0])
		print("HRIDE   pivot jerk frame ", pj_i, " of ", n, " pivot cm ", seq)
	if rj > 0.05:
		var ex := []
		for k in range(maxi(rj_i - 3, 0), mini(rj_i + 2, n)):
			var q: Dictionary = _samples[k]
			ex.append("v%.1f y%.3f air%d" % [float(q.speed), (q.root as Vector3).y, int(bool(q.air))])
		print("HRIDE   root jerk frame ", rj_i, " ", ex)
	if lj > 0.1:
		var seq2 := []
		for k in range(maxi(lj_i - 4, 0), mini(lj_i + 3, n)):
			var d4: Vector4 = (_samples[k] as Dictionary).dbg
			seq2.append("reach %.2f lead %.2f want %.2f len %.2f" % [d4.x, d4.y, d4.z, d4.w])
		print("HRIDE   arm jerk frame ", lj_i, " ", seq2)
	var inside := 0
	for sm: Dictionary in _samples:
		if bool(sm.get("inside", false)):
			inside += 1
	print("HRIDE   lens inside a solid (not a thin trunk): %d of %d frames" % [inside, n])
	print("HRIDE   boom jerk: arm length %.2f cm, shoulder %.2f cm, rise %.2f cm" % [lj * 100.0, sj * 100.0, rj2 * 100.0])
	print("HRIDE %-16s n=%d speed_max=%.1f pivot_jerk=%.2fcm cam_jerk=%.2fcm cam_y_jerk=%.2fcm root_jerk=%.2fcm yaw_snap=%.0fdeg/s rider_vs_barrel_jump=%.2fcm cam_yaw_step=%.2fdeg" % [label, n, vmax, pj * 100.0, cj * 100.0, cy * 100.0, rj * 100.0, ys, rel * 100.0, cr])


func _save(label: String, shots: Array[Image], ids: Array[int]) -> void:
	if shots.is_empty():
		return
	var dir := out.path_join(label)
	DirAccess.make_dir_recursive_absolute(dir)
	var rows := ceili(float(shots.size()) / float(COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var im: Image = shots[i]
		im.save_png(dir.path_join("f%03d.png" % ids[i]))
		var sm := im.duplicate() as Image
		sm.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(sm, Rect2i(0, 0, CELL.x, CELL.y), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	sheet.save_png(out.path_join(label + "_strip.png"))
	if label in ["mount", "dismount", "pack", "left_sharp"]:
		var ccell := Vector2i(640, 400)
		var ccols := 4
		var crows := ceili(float(shots.size()) / float(ccols))
		var csheet := Image.create(ccell.x * ccols, ccell.y * crows, false, Image.FORMAT_RGB8)
		for i in shots.size():
			var full: Image = shots[i]
			var cr := full.get_region(Rect2i(full.get_width() / 2 - 320, full.get_height() / 2 - 230, 640, 400))
			csheet.blit_rect(cr, Rect2i(0, 0, ccell.x, ccell.y), Vector2i((i % ccols) * ccell.x, (i / ccols) * ccell.y))
		csheet.save_png(out.path_join(label + "_crop.png"))
	print("HRIDE strip ", out.path_join(label + "_strip.png"), " frames=", shots.size())

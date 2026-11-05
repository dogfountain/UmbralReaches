extends Node3D
## Movement course: a synthetic test track (no main.tscn, so it runs in ~10 s) with the real Player
## driven by debug_drive() and pressed input actions. Each leg reports time, speed, how bumpy the
## view was (camera-rig jerk) and frames spent airborne where the ground was continuous.
##   godot --headless --path . res://zz/move_course.tscn [-- --only=stairs_up]
## Prints "MOVE <leg> ok|FAIL ..." per leg and "MOVE DONE pass=N fail=M".
##
## Legs (all start from rest on their own lane):
##   accel      rest -> 90 % walk speed, time
##   stop       sprint, release -> stop distance and time
##   turn       sprint one way, reverse the stick -> time until 90 % speed the other way
##   flat       20 m flat run (walk): speed, no air frames
##   stairs_up / stairs_down   standard flight (0.27 x 0.72) up and down: no stuck, low jerk
##   steep_up / steep_down     0.42 risers (near STEP_MAX): no stuck
##   slope      25 deg ramp up then down: stays grounded going down, keeps speed going up
##   gap        sprint-jump a 2.6 m pit
##   ledge      jump at a 1.0 m ledge: mantles up
##   slide      sprint then slide: distance > 4 m, capsule restored after
##   land       drop 3 m: lands, recovers to walk speed (a moving hard landing rolls it out)
## Traversal (r28):
##   vault      sprint at a 0.9 m wall 0.4 m thick: over it without a jump, speed kept
##   grab       jump at a 2.0 m wall: catches the ledge, hangs, pushing on climbs up
##   wallkick   jump at a 5 m wall, jump again against it: kicked up and away
##   steep      walk off onto a 55 deg slope: slides down it under control, runs out at the foot
##   slidejump  sprint, slide, jump out of it: the slide's speed carries into a long jump
##   beam       a 0.3 m beam over a drop: balance across (slowed, kept on it)
##   roll       dodge: a roll of ~4 m with i-frames, capsule low then restored
##   lock       lock onto a foe and strafe: the lock holds, the body keeps facing it

const WORLD := 1
var p: Player
var cam_rig: Node3D
var legs: Array = []
var leg := -1
var t := 0.0
var state := {}
var only := ""
var passed := 0
var failed := 0
var results: Array[String] = []
# per-leg samples
var cam_y: Array[float] = []
var vis_y: Array[float] = []
var air := 0
var dist := 0.0
var last_pos := Vector3.ZERO
var stall_t := 0.0


func _ready() -> void:
	Travel._busy = true                 # never write the save
	process_physics_priority = -10      # press inputs before the Player reads them
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	_build_course()
	_spawn_player()
	legs = [
		["accel", 0.0], ["stop", 0.0], ["turn", 0.0], ["flat", 0.0],
		["stairs_up", 8.0], ["stairs_down", 8.0], ["steep_up", 16.0], ["steep_down", 16.0],
		["slope", 24.0], ["gap", 32.0], ["ledge", 40.0], ["slide", 48.0], ["land", 56.0],
		["vault", 64.0], ["grab", 72.0], ["wallkick", 80.0], ["steep", 88.0], ["slidejump", 96.0],
		["beam", 104.0], ["roll", 112.0], ["lock", 120.0],
		# r29 (critique B): hardening
		["rollwall", 208.0], ["crawl", 216.0], ["mantle_tp", 40.0], ["fallout", 232.0], ["unstuck", 240.0],
	]


# --- the track ------------------------------------------------------------------------------

func _box(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	b.add_child(mi)
	add_child(b)
	b.position = pos
	b.rotation = rot


func _build_course() -> void:
	# lane 0: flat floor for accel/stop/turn/flat
	_box(Vector3(0, -0.5, -40), Vector3(6, 1, 100))
	# lane 8: standard flight up 10 x 0.27 (2.7 m), landing, flight down
	_flight(8.0, 0.27, 0.72, 10)
	# lane 16: steep flight 0.42 x 0.55
	_flight(16.0, 0.42, 0.55, 6)
	# lane 24: 25 deg ramp up 6 m, plateau, down
	var ang := deg_to_rad(25.0)
	var run := 6.0 / tan(ang)
	_box(Vector3(24, -0.5, 0), Vector3(6, 1, 12))
	var len := 6.0 / sin(ang)
	_box(Vector3(24, 3.0 - 0.5 * cos(ang), -6 - run * 0.5), Vector3(6, 1, len + 0.2), Vector3(ang, 0, 0))
	_box(Vector3(24, 5.5, -6 - run - 3), Vector3(6, 1, 6))
	_box(Vector3(24, 3.0 - 0.5 * cos(ang), -6 - run - 6 - run * 0.5), Vector3(6, 1, len + 0.2), Vector3(-ang, 0, 0))
	_box(Vector3(24, -0.5, -6 - 2 * run - 6 - 10), Vector3(6, 1, 20))
	# lane 32: pit 2.6 m wide
	_box(Vector3(32, -0.5, -4), Vector3(6, 1, 20))
	_box(Vector3(32, -0.5, -14 - 2.6 - 10), Vector3(6, 1, 20))
	_box(Vector3(32, -6.5, -15.3), Vector3(6, 1, 4))          # pit floor
	# lane 40: a 1.0 m ledge at z -10
	_box(Vector3(40, -0.5, -4), Vector3(6, 1, 20))
	_box(Vector3(40, 0.0, -20), Vector3(6, 2.0, 20))
	# lane 48: long flat for the slide
	_box(Vector3(48, -0.5, -30), Vector3(6, 1, 80))
	# lane 56: 3 m drop
	_box(Vector3(56, 2.5, 0), Vector3(6, 1, 12))
	_box(Vector3(56, -0.5, -20), Vector3(6, 1, 30))
	# lane 64: a 0.9 m wall, 0.4 m thick, across the lane
	_box(Vector3(64, -0.5, -20), Vector3(6, 1, 60))
	_box(Vector3(64, 0.45, -8.2), Vector3(6, 0.9, 0.4))
	# lane 72: a 2.0 m block (face at z -8), deep enough to stand on
	_box(Vector3(72, -0.5, -10), Vector3(6, 1, 40))
	_box(Vector3(72, 1.0, -12), Vector3(6, 2.0, 8))
	# lane 80: a 5 m wall
	_box(Vector3(80, -0.5, -5), Vector3(6, 1, 30))
	_box(Vector3(80, 2.5, -8.5), Vector3(6, 5, 1))
	# lane 88: a 7 m platform, a 55 deg slope down, the floor
	var sa := deg_to_rad(55.0)
	var srun := 7.0 / tan(sa)
	_box(Vector3(88, 6.5, 1), Vector3(6, 1, 6))
	_box(Vector3(88, 3.5 - 0.5 * cos(sa), -2.0 - srun * 0.5), Vector3(6, 1, 7.0 / sin(sa) + 0.3), Vector3(-sa, 0, 0))
	_box(Vector3(88, -0.5, -2.0 - srun - 10.0), Vector3(6, 1, 20.4))
	# lane 96: long flat (slide jump)
	_box(Vector3(96, -0.5, -30), Vector3(6, 1, 80))
	# lane 104: platform, a 0.3 m beam 8 m long over a 3 m drop, platform
	_box(Vector3(104, -0.5, 1), Vector3(6, 1, 6))
	_box(Vector3(104, -0.15, -6), Vector3(0.3, 0.3, 8))
	_box(Vector3(104, -0.5, -13), Vector3(6, 1, 6))
	_box(Vector3(104, -3.5, -6), Vector3(6, 1, 8))
	# lane 112, 120: flat
	_box(Vector3(112, -0.5, -10), Vector3(6, 1, 40))
	_box(Vector3(120, -0.5, -10), Vector3(6, 1, 40))
	# r29 lanes, well clear of the others (lock strafes off lane 120 to the right)
	# lane 208: a tall wall 3 m ahead (roll into it, then walk away)
	_box(Vector3(208, -0.5, -5), Vector3(6, 1, 20))
	_box(Vector3(208, 2.0, -3.5), Vector3(6, 4, 1))
	# lane 216: a low slab (underside 1.2 m) from z -4 to -8: roll under, crawl out
	_box(Vector3(216, -0.5, -8), Vector3(6, 1, 30))
	_box(Vector3(216, 1.45, -6.0), Vector3(6, 0.5, 4.0))
	# lane 224: where mantle_tp throws the body
	_box(Vector3(224, -0.5, 0), Vector3(6, 1, 6))
	# lane 232: a 6 m platform ending in nothing
	_box(Vector3(232, -0.5, 0), Vector3(6, 1, 6))
	# lane 240: floor and a 1 m block the body gets pushed into
	_box(Vector3(240, -0.5, -5), Vector3(6, 1, 20))
	_box(Vector3(240, 0.5, -6.0), Vector3(6, 1.0, 3.0))


## Up `n` risers, a 3 m landing, down `n` risers, then flat. Starts at z = 0 going -Z.
func _flight(x: float, rise: float, tread: float, n: int) -> void:
	_box(Vector3(x, -0.5, 4), Vector3(6, 1, 8))
	var z := 0.0
	for i in n:
		var top := rise * float(i + 1)
		_box(Vector3(x, top * 0.5 - 0.25, z - tread * 0.5), Vector3(6, top + 0.5, tread))
		z -= tread
	var top_y := rise * float(n)
	_box(Vector3(x, top_y * 0.5 - 0.25, z - 1.5), Vector3(6, top_y + 0.5, 3.0))
	z -= 3.0
	for i in n:
		var top := rise * float(n - i - 1)
		if top > 0.0:
			_box(Vector3(x, top * 0.5 - 0.25, z - tread * 0.5), Vector3(6, top + 0.5, tread))
		z -= tread
	_box(Vector3(x, -0.5, z + tread - 6), Vector3(6, 1, 12))
	set_meta("flight_%d" % int(x), [z, top_y])


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.position.y = 1.55
	pl.add_child(rig)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	arm.position.x = 0.5
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	arm.spring_length = 4.4
	arm.margin = 0.25
	pitch.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 58.0
	arm.add_child(cam)
	pl.position = Vector3(0, 0.1, 0)
	add_child(pl)
	p = pl as Player
	cam_rig = rig


# --- driving --------------------------------------------------------------------------------

func _place(x: float, z := 0.0, y := 0.05) -> void:
	p.global_position = Vector3(x, y, z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(0.0, -0.2)
	last_pos = p.global_position


func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _drive(dir: Vector3, sprint := false) -> void:
	p.debug_drive(dir, sprint)


func _hspeed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _next() -> void:
	_drive(Vector3.ZERO)
	for a in ["jump", "slide", "dodge", "sprint"]:
		_press(a, false)
	if p:
		p._release_lock()
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	leg += 1
	while leg < legs.size() and only != "" and legs[leg][0] != only:
		leg += 1
	if leg >= legs.size():
		var s := "MOVE DONE pass=%d fail=%d" % [passed, failed]
		print(s)
		get_tree().quit()
		return
	t = 0.0
	state = {}
	cam_y.clear()
	vis_y.clear()
	air = 0
	dist = 0.0
	stall_t = 0.0
	var x := float(legs[leg][1])
	match String(legs[leg][0]):
		"stairs_down", "steep_down":
			var info: Array = get_meta("flight_%d" % int(x))
			var n := 10 if x == 8.0 else 6
			var tread := 0.72 if x == 8.0 else 0.55
			_place(x, -float(n) * tread - 1.5, float(info[1]) + 0.05)
		"land":
			_place(x, 0.0, 3.05)
		"steep":
			_place(x, 2.5, 7.05)
		"beam":
			_place(x, 2.5, 0.05)
		_:
			_place(x)


func _jerk(a: Array[float]) -> Vector2:
	# max and rms of the second difference (m per frame^2): how hard the height jolts
	var mx := 0.0
	var acc := 0.0
	var n := 0
	for i in range(2, a.size()):
		var j := absf(a[i] - 2.0 * a[i - 1] + a[i - 2])
		mx = maxf(mx, j)
		acc += j * j
		n += 1
	return Vector2(mx, sqrt(acc / maxf(1.0, float(n))))


func _report(ok: bool, msg: String) -> void:
	var cj := _jerk(cam_y)
	var vj := _jerk(vis_y)
	var line := "MOVE %-11s %s t=%.2fs %s cam_jerk=%.4f/%.4f vis_jerk=%.4f/%.4f air=%d" % [legs[leg][0], "ok  " if ok else "FAIL", t, msg, cj.x, cj.y, vj.x, vj.y, air]
	print(line)
	results.append(line)
	if ok:
		passed += 1
	else:
		failed += 1
	_next()


func _physics_process(delta: float) -> void:
	if p == null or not p.is_inside_tree():
		return
	if leg < 0:
		if Engine.get_physics_frames() > 20:
			_next()
		return
	if leg >= legs.size():
		return
	t += delta
	var moved := Vector2(p.global_position.x - last_pos.x, p.global_position.z - last_pos.z).length()
	dist += moved
	last_pos = p.global_position
	cam_y.append(cam_rig.global_position.y)
	vis_y.append((p.get_node("Visual") as Node3D).global_position.y)
	var fwd := Vector3.FORWARD
	if OS.get_cmdline_user_args().has("--trace"):
		print("  t=%.2f pos=%s v=%s floor=%s ground=%s wall=%s vis=%.3f cam=%.3f" % [t, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_floor(), p.is_grounded(), p.is_on_wall(), vis_y[-1] if vis_y.size() else 0.0, cam_y[-1] if cam_y.size() else 0.0])
	match legs[leg][0]:
		"accel":
			_drive(fwd)
			if _hspeed() >= p.walk_speed * 0.9:
				_report(t < 0.35, "to90=%.2fs" % t)
			elif t > 2.0:
				_report(false, "never reached walk speed")
		"stop":
			if not state.has("released"):
				_drive(fwd, true)
				if t > 1.6:
					state["released"] = t
					state["at"] = p.global_position
					_drive(Vector3.ZERO)
			else:
				if _hspeed() < 0.05:
					var d := p.global_position.distance_to(state["at"])
					_report(d < 1.6, "stop_dist=%.2fm stop_t=%.2fs" % [d, t - float(state["released"])])
				elif t > 4.0:
					_report(false, "never stopped")
		"turn":
			if not state.has("rev"):
				_drive(fwd, true)
				if t > 1.6:
					state["rev"] = t
			else:
				_drive(-fwd, true)
				if p.velocity.z > p.sprint_speed * 0.9:
					_report(t - float(state["rev"]) < 0.8, "turnaround=%.2fs" % (t - float(state["rev"])))
				elif t > 5.0:
					_report(false, "never turned")
		"flat":
			_drive(fwd)
			if p.global_position.z < -20.0:
				_report(air == 0, "avg=%.2fm/s" % (20.0 / t))
			elif t > 8.0:
				_report(false, "slow")
			if not p.is_grounded() and t > 0.1:
				air += 1
		"stairs_up", "steep_up":
			var x := float(legs[leg][1])
			var top: float = (get_meta("flight_%d" % int(x)) as Array)[1]
			_drive(fwd)
			if p.global_position.y > top - 0.05 and p.is_grounded():
				_report(true, "climb=%.2fm avg=%.2fm/s" % [top, dist / t])
			elif _stalled(delta) or t > 12.0:
				_report(false, "stuck at y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
		"stairs_down", "steep_down":
			var x := float(legs[leg][1])
			var info: Array = get_meta("flight_%d" % int(x))
			_drive(fwd)
			if not p.is_grounded():
				air += 1
			if p.global_position.y < 0.1 and p.global_position.z < float(info[0]) - 1.0 and p.is_grounded():
				_report(air < 6, "descend=%.2fm avg=%.2fm/s" % [float(info[1]), dist / t])
			elif _stalled(delta) or t > 12.0:
				_report(false, "stuck at y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
		"slope":
			_drive(fwd)
			if not state.has("up_speed") and p.global_position.y > 2.0 and p.global_position.y < 4.0:
				state["up_speed"] = _hspeed()
			if p.global_position.y < 4.0 and p.global_position.z < -25.0 and not p.is_grounded():
				air += 1
			if p.global_position.z < -45.0:
				_report(air < 4 and float(state.get("up_speed", 0.0)) > p.walk_speed * 0.75, "uphill=%.2fm/s" % float(state.get("up_speed", 0.0)))
			elif _stalled(delta) or t > 20.0:
				_report(false, "stuck at y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
		"gap":
			_drive(fwd, true)
			if not state.has("jumped") and p.global_position.z < -13.6:
				_press("jump", true)
				state["jumped"] = t
			elif state.has("jumped") and t - float(state["jumped"]) > 0.25:
				_press("jump", false)
			if p.global_position.y < -3.0:
				_report(false, "fell in the pit")
			elif p.global_position.z < -18.5 and p.is_grounded():
				_report(true, "cleared")
			elif t > 6.0:
				_report(false, "timeout z=%.2f" % p.global_position.z)
		"ledge":
			_drive(fwd)
			if not state.has("jumped") and p.global_position.z < -9.2:
				_press("jump", true)
				state["jumped"] = t
			elif state.has("jumped") and t - float(state["jumped"]) > 0.3:
				_press("jump", false)
			if p.global_position.y > 0.9 and p.is_grounded():
				_report(true, "mantled in %.2fs" % (t - float(state.get("jumped", 0.0))))
			elif t > 6.0:
				_report(false, "never got up y=%.2f" % p.global_position.y)
		"slide":
			if not state.has("slid"):
				_drive(fwd, true)
				if t > 1.4:
					_press("slide", true)
					state["slid"] = p.global_position
			else:
				_drive(fwd, true)
				if not p.is_sliding() and t > 1.6:
					_press("slide", false)
					var d := p.global_position.distance_to(state["slid"])
					var cap := (p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
					_report(d > 4.0 and is_equal_approx(cap.height, 1.7), "slide_dist=%.2fm" % d)
				elif t > 6.0:
					_report(false, "slide never ended")
		"land":
			_drive(fwd)
			if not state.has("landed") and p.is_grounded() and p.global_position.y < 0.2:
				state["landed"] = t
				state["min"] = _hspeed()
			if state.has("landed"):
				state["min"] = minf(float(state["min"]), _hspeed())
				if p.is_rolling():
					state["rolled"] = true
				if t - float(state["landed"]) > 0.05 and _hspeed() > p.walk_speed * 0.9:
					_report(true, "landing_min_speed=%.2f recover=%.2fs rolled=%s" % [float(state["min"]), t - float(state["landed"]), state.has("rolled") or p.is_rolling()])
			if t > 6.0:
				_report(false, "never recovered")
		_:
			_trav(delta)


func _trav(delta: float) -> void:
	var fwd := Vector3.FORWARD
	match legs[leg][0]:
		"vault":
			_drive(fwd, true)
			if p._vault_t >= 0.0:
				state["vaulted"] = true
			if p.global_position.z < -5.0 and p.global_position.z > -11.0:
				state["min"] = minf(float(state.get("min", 99.0)), _hspeed())
			if p.global_position.z < -11.0 and p.is_grounded():
				_report(state.has("vaulted") and float(state["min"]) > p.walk_speed * 0.9, "vaulted=%s min_speed=%.2f" % [state.has("vaulted"), float(state.get("min", 0.0))])
			elif _stalled(delta) or t > 6.0:
				_report(false, "stopped at z=%.2f y=%.2f" % [p.global_position.z, p.global_position.y])
		"grab":
			_drive(fwd)
			if not state.has("jumped") and p.global_position.z < -6.9:
				_press("jump", true)
				state["jumped"] = t
			elif state.has("jumped") and t - float(state["jumped"]) > 0.25:
				_press("jump", false)
			if p.is_hanging() and not state.has("hung"):
				state["hung"] = t
			if p.global_position.y > 1.95 and p.is_grounded() and p._climb_t < 0.0:
				_report(state.has("hung"), "hung=%s climbed in %.2fs" % [state.has("hung"), t - float(state.get("hung", 0.0))])
			elif t > 6.0:
				_report(false, "never up y=%.2f hanging=%s" % [p.global_position.y, p.is_hanging()])
		"wallkick":
			_drive(fwd)
			if not state.has("jumped") and p.global_position.z < -6.6:
				_press("jump", true)
				state["jumped"] = t
			elif state.has("jumped") and not state.has("released") and t - float(state["jumped"]) > 0.08:
				_press("jump", false)
				state["released"] = t
			elif state.has("released") and not state.has("kicked") and not p.is_grounded() and (p._wall_t > 0.0 or p.global_position.z < -7.6):
				_press("jump", true)
				state["kicked"] = t
				if OS.get_cmdline_user_args().has("--trace"):
					print("  kick? can=%s coyote=%.2f grounded=%s wall_t=%.2f steep_t=%.2f air_jumps=%d" % [p._can_wallkick(Vector3.FORWARD), p._coyote, p._grounded, p._wall_t, p._steep_t, p._air_jumps_left])
			elif state.has("kicked") and not state.has("out") and t - float(state["kicked"]) > 0.06:
				state["out"] = Vector2(p.velocity.z, p.velocity.y)     # (an injected press reads a tick late)
				_press("jump", false)
			if state.has("out"):
				var o: Vector2 = state["out"]
				_report(o.x > 3.0 and o.y > 4.0, "kick_out=%.2f kick_up=%.2f" % [o.x, o.y])
			elif t > 4.0:
				_report(false, "no kick (wall_t %.2f z %.2f)" % [p._wall_t, p.global_position.z])
		"steep":
			_drive(fwd)
			state["k"] = maxf(float(state.get("k", 0.0)), p._steep_k)
			if p.global_position.z < -10.0 and p.is_grounded():
				_report(float(state["k"]) > 0.5 and _hspeed() > 3.0, "steep_k=%.2f out_speed=%.2f" % [float(state["k"]), _hspeed()])
			elif _stalled(delta) or t > 8.0:
				_report(false, "stuck at y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
		"slidejump":
			_drive(fwd, true)
			if t > 1.4 and not state.has("slid"):
				_press("slide", true)
				state["slid"] = t
			elif state.has("slid") and not state.has("jumped") and t - float(state["slid"]) > 0.25:
				_press("jump", true)
				state["jumped"] = p.global_position.z
			elif state.has("jumped") and not state.has("v"):
				_press("slide", false)
				state["v"] = _hspeed()
			elif state.has("v") and not state.has("air") and not p.is_grounded():
				state["air"] = true
			elif state.has("air") and p.is_grounded():
				_press("jump", false)
				var d := float(state["jumped"]) - p.global_position.z
				_report(float(state["v"]) > p.sprint_speed * 1.05 and d > 4.5, "takeoff=%.2fm/s jump=%.2fm" % [float(state["v"]), d])
			if t > 6.0:
				_report(false, "never landed")
		"beam":
			# on the beam, a little sideways drift on the stick: the balance keeps you on it
			_drive(Vector3(0.12 if p.global_position.z < -2.3 else 0.0, 0.0, -1.0).normalized())
			state["k"] = maxf(float(state.get("k", 0.0)), p._beam_k)
			if p.global_position.y < -1.0:
				_report(false, "fell off at z=%.2f" % p.global_position.z)
			elif p.global_position.z < -11.0 and p.is_grounded():
				_report(float(state["k"]) > 0.7, "beam_k=%.2f avg=%.2fm/s" % [float(state["k"]), dist / t])
			elif _stalled(delta) or t > 10.0:
				_report(false, "stuck z=%.2f" % p.global_position.z)
		"roll":
			_drive(fwd)
			if t > 0.8 and not state.has("at"):
				_press("dodge", true)
				state["at"] = p.global_position
			elif state.has("at") and not state.has("done"):
				_press("dodge", false)
				if p.is_evading():
					state["ev"] = int(state.get("ev", 0)) + 1
				if p.is_rolling():
					state["rolled"] = true
				elif state.has("rolled"):
					state["done"] = p.global_position.distance_to(state["at"])
			if state.has("done"):
				var cap := (p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
				_report(float(state["done"]) > 3.0 and int(state.get("ev", 0)) > 5 and is_equal_approx(cap.height, 1.7), "roll=%.2fm iframes=%d" % [float(state["done"]), int(state.get("ev", 0))])
			elif t > 4.0:
				_report(false, "no roll")
		"rollwall":
			if not state.has("at"):
				_drive(fwd)
				if t > 0.25:
					_press("dodge", true)
					state["at"] = t
			elif not state.has("ended"):
				_press("dodge", false)
				_drive(fwd)
				if t - float(state["at"]) > 1.0:
					state["ended"] = p.global_position.z
			else:
				_drive(-fwd)
				var cap := (p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
				if p.global_position.z > float(state["ended"]) + 1.5 and is_equal_approx(cap.height, 1.7):
					_report(true, "walked away %.2f m, stood up" % (p.global_position.z - float(state["ended"])))
				elif t > 5.0:
					_report(false, "soft-locked: z %.2f roll_t %.2f capsule %.2f" % [p.global_position.z, p._roll_t, cap.height])
		"crawl":
			var cap := (p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
			_drive(fwd)
			if not state.has("at") and p.global_position.z < -1.6:
				_press("dodge", true)
				state["at"] = t
			elif state.has("at"):
				_press("dodge", false)
			var under := p.global_position.z < -4.2 and p.global_position.z > -7.8
			if under and cap.height > 1.2:
				state["bad"] = true                   # stood up into the slab
			if under:
				state["under"] = true
			if p.global_position.z < -8.6 and is_equal_approx(cap.height, 1.7):
				_report(state.has("under") and not state.has("bad"), "crawled out (stood up under it: %s)" % state.has("bad"))
			elif t > 9.0:
				_report(false, "stuck under z %.2f capsule %.2f roll_t %.2f" % [p.global_position.z, cap.height, p._roll_t])
		"mantle_tp":
			_drive(Vector3.ZERO if state.has("tp") else fwd)
			if not state.has("jumped") and p.global_position.z < -9.2:
				_press("jump", true)
				state["jumped"] = t
			elif state.has("jumped"):
				_press("jump", false)
			if p._mantle_t >= 0.0 and not state.has("tp"):
				state["tp"] = Vector3(224.0, 0.05, 0.0)
				p.teleport(state["tp"])               # a lava throw / respawn mid-mantle
				_drive(Vector3.ZERO)
				state["tp_t"] = t
			elif state.has("tp") and t - float(state["tp_t"]) > 0.4:
				var d := p.global_position.distance_to(state["tp"])
				_report(d < 0.6 and p._mantle_t < 0.0, "stayed where thrown (%.2f m off), mantle %.2f" % [d, p._mantle_t])
			elif t > 5.0:
				_report(false, "never mantled")
		"fallout":
			if not state.has("off"):
				if t < 0.05:
					p.gloom = 0.0; p.wounds = 0.0                       # earlier legs fill it in the dark
				_drive(fwd)
				if p.global_position.z < -3.5:
					state["off"] = true
					state["g"] = p.gloom
			else:
				_drive(Vector3.ZERO)
				if p.global_position.y > -1.0 and absf(p.global_position.z) < 3.8 and p.is_grounded() and t > 1.0 and state.has("fell"):
					_report(p.gloom > float(state["g"]) + 4.0, "back on safe ground, gloom +%.1f" % (p.gloom - float(state["g"])))
				if p.global_position.y < -5.0:
					state["fell"] = true
				if t > 8.0:
					_report(false, "not rescued y %.2f" % p.global_position.y)
		"unstuck":
			if not state.has("in"):
				p.global_position = Vector3(240.0, 0.35, -6.0)   # pushed into the block (a moving platform...)
				p.velocity = Vector3.ZERO
				state["in"] = true
			_drive(fwd)
			if p.global_position.y > 0.95 and p.is_grounded():
				_report(true, "out of the block at y %.2f after %.2fs" % [p.global_position.y, t])
			elif t > 4.0:
				_report(false, "still inside y %.2f" % p.global_position.y)
		"lock":
			if not state.has("e"):
				var e := (load("res://core/enemy/wretch.gd") as GDScript).new() as Enemy
				add_child(e)
				e.global_position = Vector3(124.0, 0.1, -9.0)
				e.home = e.global_position
				e.sleep()
				e.chase_range = 0.0
				state["e"] = e
			elif t > 0.3 and not state.has("locked"):
				p._toggle_lock()
				state["locked"] = p.lock_target() != null
			elif state.has("locked"):
				_drive(Basis(Vector3.UP, p._yaw) * Vector3.RIGHT)  # strafe round it
				if OS.get_cmdline_user_args().has("--trace"):
					var en: Enemy = state["e"]
					print("  lock vis=%.2f roll=%.2f crawl=%s hang=%s slide=%s vault=%.2f climb=%.2f mv=%s" % [p._visual.rotation.y, p._roll_t, p._crawl, p._hang, p._sliding, p._vault_t, p._climb_t, p._visual.move_playing()])
				if t > 2.3:
					var e: Enemy = state["e"]
					var to := e.global_position - p.global_position
					var fwd_v := -p._visual.global_basis.z
					var face := Vector2(fwd_v.x, fwd_v.z).normalized().dot(Vector2(to.x, to.z).normalized())
					_report(p.lock_target() == e and face > 0.9, "locked=%s held=%s facing=%.2f" % [state["locked"], p.lock_target() == e, face])
			if t > 4.0:
				_report(false, "lock timeout")


func _stalled(delta: float) -> bool:
	if _hspeed() < 0.3:
		stall_t += delta
	else:
		stall_t = 0.0
	return stall_t > 1.0

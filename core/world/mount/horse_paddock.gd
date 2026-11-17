extends RefCounted
## A horse at its hitching post is not a statue (stables): it strolls the paddock. Unowned, unridden stock within a few
## metres of its post picks a point now and then, turns its head and body toward it at the breed's easing, walks there
## at a walk (the rig's own gait, paced by the ground covered: no skating), grazes a while, and does it again. A wanderer
## who comes within 4.5 m (to buy it) stops it and has it turn to face him. A forward ray turns it from fences and
## walls; the ground is followed with a ray, eased. While it strolls it draws itself every rendered frame (physics
## interpolation off on the node: moved in _process); when it is bought or ridden the mode is given back. Cost: one ray a
## few times a second per horse within 40 m of the camera; asleep beyond. Static; `h` is the Horse, `wd` its state.
const RANGE := 3.4                         ## how far from its post it strolls
const WALK := 0.95                         ## m/s
const NEAR_BUYER := 4.5
const SLEEP_R := 40.0


static func step(h: Variant, wd: Dictionary, dt: float) -> void:
	var node := h as Node3D
	var live: bool = h.rider == null and not h.owned() and h.at_post and not h._air and float(h._land) <= 0.0 and float(h._gather) <= 0.0
	if not live:
		if bool(wd.get("off", false)):
			wd["off"] = false
			wd["moving"] = false
			node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
			node.reset_physics_interpolation()
		return
	var cam := node.get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(node.global_position) > SLEEP_R:
		wd["moving"] = false
		return
	if not wd.has("home"):
		wd["home"] = node.global_position
		wd["goal"] = node.global_position
		wd["wait"] = 2.0 + randf() * 6.0
		wd["ray"] = 0.0
	if not bool(wd.get("off", false)):
		wd["off"] = true
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var home: Vector3 = wd.home
	var pos := node.global_position
	var player := node.get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var buyer := player != null and player.global_position.distance_to(pos) < NEAR_BUYER
	var want := 0.0
	var yaw_goal := node.global_rotation.y
	if buyer:
		# face the one who has come to buy: the head toward him, the body turning slowly
		var to := player.global_position - pos
		yaw_goal = atan2(-to.x, -to.z)
		wd["wait"] = maxf(float(wd.get("wait", 0.0)), 2.0)
		node.global_rotation.y = lerp_angle(node.global_rotation.y, yaw_goal, 1.0 - exp(-2.0 * dt))
	elif float(wd.get("wait", 0.0)) > 0.0:
		wd["wait"] = float(wd.wait) - dt
		if float(wd.wait) <= 0.0:
			wd["goal"] = _pick(h, home)
	else:
		var goal: Vector3 = wd.goal
		var to2 := Vector2(goal.x - pos.x, goal.z - pos.z)
		var d := to2.length()
		if d < 0.3:
			wd["wait"] = 7.0 + randf() * 14.0
			h._graze_t = 7.0                        # it puts its head down to the grass on arriving
		else:
			yaw_goal = atan2(-to2.x, -to2.y)
			var diff := absf(angle_difference(node.global_rotation.y, yaw_goal))
			node.global_rotation.y = lerp_angle(node.global_rotation.y, yaw_goal, 1.0 - exp(-2.6 * dt))
			want = WALK * smoothstep(0.0, 1.2, d) * (1.0 - smoothstep(0.35, 0.9, diff))
			# a fence or a wall ahead: think again
			wd["ray"] = float(wd.get("ray", 0.0)) - dt
			if float(wd.ray) <= 0.0:
				wd["ray"] = 0.35
				var fwd := Vector3(-sin(node.global_rotation.y), 0.0, -cos(node.global_rotation.y))
				var sp: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.9, pos + Vector3.UP * 0.9 + fwd * 1.8, Layers.WORLD | Layers.PROPS)
				if not sp.intersect_ray(q).is_empty():
					wd["goal"] = _pick(h, home)
					want = 0.0
	h.speed = lerpf(float(h.speed), want, 1.0 - exp(-3.0 * dt))
	if float(h.speed) < 0.02 and want == 0.0:
		h.speed = 0.0
	wd["moving"] = float(h.speed) > 0.0
	if float(h.speed) > 0.0:
		var fwd2 := Vector3(-sin(node.global_rotation.y), 0.0, -cos(node.global_rotation.y))
		var np := pos + fwd2 * float(h.speed) * dt
		np.y = lerpf(pos.y, h._ground(np).y, 1.0 - exp(-8.0 * dt))
		node.global_position = np
		h._phase += TAU * h._rig.freq(float(h.speed)) * dt


## A point within the paddock that is not a cliff: the ground there no more than half a metre from the post's.
static func _pick(h: Variant, home: Vector3) -> Vector3:
	for _i in 6:
		var a := randf() * TAU
		var p := home + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.2, RANGE)
		var g: Vector3 = h._ground(p)
		if absf(g.y - home.y) < 0.5:
			return g
	return home

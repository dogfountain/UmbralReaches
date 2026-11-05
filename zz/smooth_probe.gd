extends Node
## Motion smoothness per RENDERED frame: walks the wanderer straight ahead and records, every
## _process, where the camera, the body and a hand bone are drawn. A step far below the median is a
## repeated pose (that thing only moved every other frame: "feels like 60 at 120 fps"); far above is
## a catch-up jump. Never writes the save or settings.
##   godot --path . res://zz/smooth_probe.tscn -- [--vsync=0|1] [--cap=120] [--screen=1] [--sprint]
const WALK_S := 5.0
var p: Player
var t := 0.0
var phase := "load"
var samples: Array = []          # [usec, cam, body, bone]
var vsync := 1
var cap := 120
var sprint := false
var skel: Skeleton3D
var bone := -1
var _found := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100000      # sample after every other _process: what will be drawn
	Travel._busy = true
	Settings.fullscreen = false
	Settings.monitor = -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vsync="):
			vsync = int(a.trim_prefix("--vsync="))
		elif a.begins_with("--cap="):
			cap = int(a.trim_prefix("--cap="))
		elif a.begins_with("--screen="):
			DisplayServer.window_set_current_screen(int(a.trim_prefix("--screen=")))
		elif a == "--sprint":
			sprint = true
	Settings.vsync = vsync != 0
	Settings.fps_limit = cap
	get_window().size = Vector2i(1600, 900)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	match phase:
		"load":
			if Realm.enabled() and not p.get_parent().has_meta("realm_done"):
				return
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			Settings.changed.emit()
			phase = "settle"
			t = 0.0
		"settle":
			if t < 6.0:
				return
			p.teleport(Vector3(-20.0, 0.6, 46.0))
			p.set_view(0.0, -0.25)
			p.debug_drive(Vector3(0, 0, -1), sprint)
			for s in p.find_children("*", "Skeleton3D", true, false):
				skel = s
				for name in ["hand_r", "HandR", "hand.R", "forearm_r"]:
					bone = skel.find_bone(name)
					if bone >= 0:
						break
				if bone < 0 and skel.get_bone_count() > 0:
					bone = skel.get_bone_count() - 1
				break
			print("SMOOTH vsync %d max_fps %d screen %d hz %d skel %s bone %d" % [DisplayServer.window_get_vsync_mode(), Engine.max_fps, DisplayServer.window_get_current_screen(), Settings.refresh_hz(), skel != null, bone])
			phase = "warm"
			t = 0.0
		"warm":
			if t > 1.0:
				phase = "walk"
				t = 0.0
		"walk":
			var cam := get_viewport().get_camera_3d()
			var body := (p.get_node("Visual") as Node3D).get_global_transform_interpolated().origin
			var b := Vector3.ZERO
			if skel and bone >= 0:
				b = (skel.get_global_transform_interpolated() * skel.get_bone_global_pose(bone)).origin
			var rig := (p.get_node("CameraRig") as Node3D).global_position
			var arm := p.get_node("CameraRig/Pitch/SpringArm") as SpringArm3D
			if cam.position.z < 2.0 and not _found:
				_found = true
				var arm_n := p.get_node("CameraRig/Pitch/SpringArm") as Node3D
				var q := PhysicsShapeQueryParameters3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.24
				q.shape = sph
				q.transform = Transform3D(Basis.IDENTITY, arm_n.global_position)
				q.motion = arm_n.global_basis.z.normalized() * 3.7
				q.collision_mask = Layers.WORLD
				q.exclude = [p.get_rid()]
				var sp := p.get_world_3d().direct_space_state
				var fr := sp.cast_motion(q)
				q.transform.origin += q.motion * fr[1]
				q.motion = Vector3.ZERO
				for h in sp.intersect_shape(q, 4):
					var c: Object = h.collider
					print("SMOOTH camera blocked by %s (%s) at %s, frac %.2f" % [c.get("name"), c.get_class(), (c as Node3D).global_position if c is Node3D else Vector3.ZERO, fr[0]])
					var n: Node = c as Node
					var path := ""
					while n != null and path.count("/") < 5:
						path = String(n.name) + "/" + path
						n = n.get_parent()
					print("SMOOTH   path ", path)
			var lp := skel.get_bone_pose(bone).origin if skel and bone >= 0 else Vector3.ZERO
			samples.append([Time.get_ticks_usec(), cam.global_position, body, b, rig, Vector3(arm.get_hit_length(), cam.position.z, float(Engine.get_physics_frames())), lp])
			if t > WALK_S:
				p.debug_drive(Vector3.ZERO)
				_report()
				var same := 0
				var same_moved := 0
				for k in range(1, samples.size()):
					if samples[k][5].z == samples[k - 1][5].z:
						same += 1
						if (samples[k][6] as Vector3).distance_to(samples[k - 1][6]) > 1e-5:
							same_moved += 1
				print("SMOOTH frames with no physics tick %d, local hand pose changed on %d of them" % [same, same_moved])
				for k in range(40, 70):
					print("SMOOTH_ROW %d dt %.2f phys %d cam %s rig %s arm %.3f camz %.3f" % [k, (samples[k][0] - samples[k - 1][0]) * 0.001, int(samples[k][5].z), samples[k][1], samples[k][4], samples[k][5].x, samples[k][5].y])
				get_tree().quit()


func _report() -> void:
	var dts: Array[float] = []
	for k in range(1, samples.size()):
		dts.append(float(samples[k][0] - samples[k - 1][0]) * 0.001)
	dts.sort()
	print("SMOOTH frames %d  dt median %.2f ms  p5 %.2f  p95 %.2f  max %.2f" % [samples.size(), dts[dts.size() / 2], dts[int(dts.size() * 0.05)], dts[int(dts.size() * 0.95)], dts[-1]])
	for col in [[1, "camera"], [2, "body"], [3, "hand bone"], [4, "rig"]]:
		var steps: Array[float] = []
		for k in range(1, samples.size()):
			steps.append((samples[k][col[0]] as Vector3).distance_to(samples[k - 1][col[0]]))
		var sorted := steps.duplicate()
		sorted.sort()
		var med: float = sorted[sorted.size() / 2]
		var low := 0
		var high := 0
		var alt := 0
		for k in steps.size():
			if steps[k] < med * 0.35:
				low += 1
			elif steps[k] > med * 1.65:
				high += 1
			if k > 0 and absf(steps[k] - steps[k - 1]) > med * 0.6:
				alt += 1
		# jitter: how far each frame sits off the midpoint of its neighbours, in median steps. Smooth
		# motion (even a swinging limb) stays well under 0.1; a pose that only updates every other
		# frame sits ~0.5 off on those frames.
		var jit: Array[float] = []
		for k in range(1, samples.size() - 1):
			var mid: Vector3 = ((samples[k - 1][col[0]] as Vector3) + (samples[k + 1][col[0]] as Vector3)) * 0.5
			jit.append((samples[k][col[0]] as Vector3).distance_to(mid) / maxf(med, 1e-6))
		jit.sort()
		print("SMOOTH %-9s jitter median %.3f  p90 %.3f  p99 %.3f" % [col[1], jit[jit.size() / 2], jit[int(jit.size() * 0.9)], jit[int(jit.size() * 0.99)]])
		print("SMOOTH %-9s step median %.4f m  repeats %d (%.0f%%)  jumps %d (%.0f%%)  big swings %.0f%%" % [col[1], med, low, 100.0 * low / steps.size(), high, 100.0 * high / steps.size(), 100.0 * alt / steps.size()])

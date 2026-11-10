extends Node
## NPC script cost in the real world (npc agent): loads the Realm, stands the wanderer at a view,
## takes the NPC nodes (tavern patrons, the keep, the villagers, the village director, the tasks'
## world side, the Keg's scenes, the talk drivers and the story director) off the
## engine's process list and runs their _process from here, timed with the microsecond clock, so the
## number is exactly what the NPCs cost per frame at that view, nothing else. Also counts their
## draws: visible NPC mesh instances (+ glow parts) and those that cast shadows.
##   godot --path . res://zz/npc_perf.tscn [-- --only=r_spawn_west,r_tavern_in --seconds=4 --preset=2]
##     [--nolod]  every NPC posed every frame (the cost without the update-rate policy)
## Prints "NPCPERF <point> mean .. us  p95 .. us  max .. us | npcs .. posed/frame .. | draws .. shadow ..".
## Settings stay in memory (never saved); Travel._busy blocks save writes; exits with OS.kill.

const Life := preload("res://core/npc/npc_life.gd")
const POINTS := [
	["r_spawn_west", Vector3(0.0, NAN, 30.0), PI * 0.5],
	["r_spawn_north", Vector3(0.0, NAN, 40.0), 0.0],
	["r_tavern_in", Vector3(11.4, -0.6, 27.0), -0.9],
	["r_forge", Vector3(9.0, NAN, 53.0), PI],
]

var main: Node
var p: Node3D
var t := 0.0
var i := -1
var settle := 0.0
var seconds := 4.0
var only: Array = []
var npcs: Array[Node] = []
var samples := PackedFloat32Array()
var per := {}
var sum_us := 0.0
var sum_t := 0.0
var points: Array = []


func _ready() -> void:
	process_priority = 1000
	var preset := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
		elif a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a == "--nolod":
			Life.every_frame = true
		elif a.begins_with("--preset="):
			preset = int(a.trim_prefix("--preset="))
	for pt: Array in POINTS:
		if only.is_empty() or only.has(pt[0]):
			points.append(pt.duplicate())
	Settings.set_preset_fields(preset)
	Settings.fullscreen = false
	Travel._busy = true
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _collect() -> void:
	npcs.clear()
	for n in get_tree().root.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		if sc == null:
			continue
		var f := sc.resource_path.get_file()
		if f in ["dwarf_npc.gd", "bartender.gd", "villager.gd", "village.gd", "quest_world.gd", "keg_scenes.gd", "village_talk.gd", "story.gd"]:
			npcs.append(n)
			n.set_process(false)


func _process(d: float) -> void:
	t += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		return
	if not main.has_meta("realm_done"):
		return
	var v := get_tree().root.find_child("Village", true, false)
	if v == null or not v.has_meta("village_done") or t < 8.0:
		return
	if npcs.is_empty():
		_collect()
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			if n is Node3D:
				n.process_mode = Node.PROCESS_MODE_DISABLED
				(n as Node3D).visible = false
		_next()
		return
	# run the NPCs (they are off the engine's list), timed
	var t0 := Time.get_ticks_usec()
	for n in npcs:
		if is_instance_valid(n) and n.is_inside_tree():
			var a := Time.get_ticks_usec()
			n.call("_process", d)
			var f: String = n.get_script().resource_path.get_file()
			per[f] = float(per.get(f, 0.0)) + float(Time.get_ticks_usec() - a)
	var us := float(Time.get_ticks_usec() - t0)
	_hold()
	settle -= d
	if settle > 0.0:
		return
	samples.append(us)
	sum_us += us
	sum_t += d
	if float(samples.size()) * d >= seconds and samples.size() > 30:
		_report()
		_next()


func _hold() -> void:
	var at: Vector3 = points[i][1]
	if is_nan(at.y):
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
		points[i][1] = at
	if p.global_position.distance_to(at) > 0.3:
		p.global_position = at
		p.reset_physics_interpolation()
	if "velocity" in p:
		p.set("velocity", Vector3.ZERO)


func _next() -> void:
	i += 1
	samples = PackedFloat32Array()
	per = {}
	sum_us = 0.0
	sum_t = 0.0
	if i >= points.size():
		# micro-bench: one full pose of each kind
		for f: String in ["dwarf_npc.gd", "bartender.gd", "villager.gd"]:
			for n in npcs:
				if is_instance_valid(n) and n.get_script().resource_path.get_file() == f:
					var a := Time.get_ticks_usec()
					for k in 200:
						match f:
							"dwarf_npc.gd": n.call("animate", 0.016)
							"bartender.gd": n.call("animate", 0.016, false, false, null)
							_: n.call("_pose", 0.016)
					print("NPCPERF bench %s one pose %.1f us" % [f, float(Time.get_ticks_usec() - a) / 200.0])
					break
		print("NPCPERF done")
		OS.kill(OS.get_process_id())
		return
	settle = 2.0
	_hold()
	if p.has_method("set_view"):
		p.call("set_view", float(points[i][2]), -0.08)


func _report() -> void:
	var s := samples.duplicate()
	s.sort()
	var mean := 0.0
	for x in s:
		mean += x
	mean /= float(s.size())
	var cam := get_viewport().get_camera_3d()
	var vis := 0
	var shadow := 0
	var glow := 0
	var near := 0
	for n in npcs:
		if not (n is Node3D) or not (n as Node3D).is_visible_in_tree() or String(n.name) == "Village":
			continue
		var np := n as Node3D
		for mi in np.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.is_visible_in_tree():
				continue
			var dd := cam.global_position.distance_to(m.global_position)
			var far: float = m.visibility_range_end if m.visibility_range_end > 0.0 else INF
			if dd > far:
				continue
			if not cam.is_position_in_frustum(m.global_position + Vector3.UP * 0.8) and dd > 2.0:
				continue
			vis += 1
			if String(m.name) == "Glow":
				glow += 1
			if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow += 1
		if cam.global_position.distance_to(np.global_position) < 35.0:
			near += 1
	var parts := PackedStringArray()
	for f: String in per:
		parts.append("%s %.0f" % [f.get_basename(), float(per[f]) / float(maxi(samples.size(), 1))])
	print("NPCPERF %-14s by script (us/frame, incl. settle): %s" % [points[i][0], ", ".join(parts)])
	# most NPC work is paced in seconds (poses at 30/20/12 Hz), so the frame cost depends on the
	# frame rate this run got; normalise to Luke's 120 Hz display
	print("NPCPERF %-14s fps %.0f  ->  at 120 fps: %.0f us/frame (%.0f us per second of play)" % [points[i][0], float(samples.size()) / maxf(sum_t, 0.001), sum_us / maxf(sum_t, 0.001) / 120.0, sum_us / maxf(sum_t, 0.001)])
	print("NPCPERF %-14s mean %6.0f us  p95 %6.0f us  max %6.0f us | npc nodes %d (within 35 m %d) | visible npc draws %d (glow %d) shadow casters %d | frame draws %d" % [points[i][0], mean, s[int(float(s.size()) * 0.95)], s[s.size() - 1], npcs.size(), near, vis, glow, shadow, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

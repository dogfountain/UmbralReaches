class_name PerfWatch
extends Node
## Spike logger. When frame time stays above 1.4x its rolling median for 0.5 s, appends one line
## to user://perf_spikes.log with what the scene looked like at that moment (draws, primitives,
## GPU/CPU ms, particles, lights, enemies, shades, nodes, player position). Throttled to one line
## per 3 s. Send the file over and the cause is usually obvious.
## Also runs the post-build performance pass (Atmosphere.post_build: terrain occluder, flora
## detail) once the Realm reports `realm_done`, so no builder has to call it.

const PATH := "user://perf_spikes.log"
const HIST := 600
var _hist := PackedFloat32Array()                ## ring of the last HIST frame times
var _hist_i := 0
var _hist_n := 0
var _hi_t := 0.0
var _cool := 0.0
var _median := 1.0 / 60.0
var _since_sort := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_line("# perf spikes, %s" % Time.get_datetime_string_from_system())


var _post_done := false


var _fps_log := "--fps-log" in OS.get_cmdline_user_args()
var _no_particles_t := 20.0 if "--no-particles" in OS.get_cmdline_user_args() else -1.0   ## A/B (measurement only)
var _census_t := 25.0 if "--census" in OS.get_cmdline_user_args() else -1.0


## `--census` (with --fps-log): 25 s in, each top-level part of the world is hidden for a few frames and the draw calls
## it was costing printed, heaviest first (release builds too: what the player's own view draws).
func _census() -> void:
	var zone := get_parent()
	var vp := get_viewport().get_viewport_rid()
	for _i in 6:
		await get_tree().process_frame
	var base := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var rows: Array = []
	var parts: Array[Node] = []
	for c in zone.get_children():
		if c is Node3D and (c as Node3D).visible:
			parts.append(c)
	for c in get_tree().root.get_children():
		if c != zone and c is Node3D and (c as Node3D).visible:
			parts.append(c)
	for c in parts:
		(c as Node3D).visible = false
		for _i in 4:
			await get_tree().process_frame
		var d := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		(c as Node3D).visible = true
		for _i in 2:
			await get_tree().process_frame
		rows.append([base - d, String(c.name)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("CENSUS base draws %d (vp %s)" % [base, vp])
	for r: Array in rows:
		if int(r[0]) > 4:
			print("CENSUS %6d  %s" % [r[0], r[1]])
var _fl_t := 0.0
var _fl_n := 0
var _fl_worst := 0.0
var _fl_measuring := false


func _process(delta: float) -> void:
	if _no_particles_t > 0.0:
		_no_particles_t -= delta
		if _no_particles_t <= 0.0:
			var n := 0
			for g in get_tree().root.find_children("*", "GPUParticles3D", true, false):
				(g as GPUParticles3D).emitting = false
				(g as GPUParticles3D).visible = false
				n += 1
			print("FPS particles off: %d" % n)
	if _census_t > 0.0:
		_census_t -= delta
		if _census_t <= 0.0:
			_census()
	if _fps_log:
		# `--fps-log`: once a second, the frames drawn, the worst frame, draws and where the player is (release builds too)
		_fl_t += delta
		_fl_n += 1
		_fl_worst = maxf(_fl_worst, delta)
		if _fl_t >= 1.0:
			var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
			var vp := get_viewport().get_viewport_rid()
			if not _fl_measuring:
				RenderingServer.viewport_set_measure_render_time(vp, true)
				_fl_measuring = true
			print("FPS %.1f worst %.1f ms draws %d objs %d prims %dk | process %.2f physics %.2f render-cpu %.2f gpu %.2f ms at %s" % [
				_fl_n / _fl_t, _fl_worst * 1000.0,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				pl.global_position.snapped(Vector3.ONE * 0.1) if pl else Vector3.ZERO])
			print("FPS2 nav %.2f ms | physics active %d pairs %d islands %d | nodes %d objects %d" % [
				Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
				Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT)])
			_fl_t = 0.0
			_fl_n = 0
			_fl_worst = 0.0
	if not _post_done:
		var zone := get_parent()
		if zone == null or not Realm.enabled():
			_post_done = true
		elif zone.has_meta("realm_done"):
			_post_done = true
			Atmosphere.post_build(zone)
			_counts_t = -100.0
			for type: String in ["GPUParticles3D", "OmniLight3D", "SpotLight3D"]:
				_count(zone, type)                   # warm now (still loading), not in a spike
	_cool = maxf(0.0, _cool - delta)
	if _hist.is_empty():
		_hist.resize(HIST)
	_hist[_hist_i] = delta                       # a ring: no 600-float copy every frame
	_hist_i = (_hist_i + 1) % HIST
	_hist_n = mini(_hist_n + 1, HIST)
	if _hist_n < 120:
		return
	_since_sort += 1
	if _since_sort >= 30:                        # re-derive the median twice a second, not per frame
		_since_sort = 0
		var sorted := _hist.slice(0, _hist_n)
		sorted.sort()
		_median = sorted[sorted.size() / 2]
	var median := _median
	_hi_t = _hi_t + delta if delta > median * 1.4 else 0.0
	if _hi_t > 0.5 and _cool <= 0.0:
		_cool = 3.0
		_hi_t = 0.0
		_log(delta, median)


func _log(dt: float, median: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var rid := get_viewport().get_viewport_rid()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var line := "%s frame %.1f ms (median %.1f) gpu %.1f cpu %.1f draws %d prims %dk | particles %d omni %d spot %d enemies %d shades %d nodes %d | at %s" % [
		Time.get_time_string_from_system(), dt * 1000.0, median * 1000.0,
		RenderingServer.viewport_get_measured_render_time_gpu(rid), RenderingServer.viewport_get_measured_render_time_cpu(rid),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000,
		_count(root, "GPUParticles3D"), _count(root, "OmniLight3D"),
		_count(root, "SpotLight3D"), get_tree().get_nodes_in_group(Groups.ENEMY).size(),
		get_tree().get_nodes_in_group(Groups.SHADE).size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		str(p.global_position.snapped(Vector3.ONE * 0.1)) if p else "-"]
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
	print("PERF_SPIKE ", line)


## Node counts for the log, refreshed at most every 60 s (warmed when the Realm is done): a full-tree
## scan is ~8k nodes, several ms, and logging a spike must not make the next one.
var _counts := {}
var _counts_t := -100.0


func _count(root: Node, type: String) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _counts_t > 60.0:
		_counts_t = now
		_counts.clear()
	if not _counts.has(type):
		_counts[type] = root.find_children("*", type, true, false).size()
	return _counts[type]

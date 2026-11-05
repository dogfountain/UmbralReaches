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


func _process(delta: float) -> void:
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

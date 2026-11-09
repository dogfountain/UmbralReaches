class_name PerfWatch
extends Node
## Spike logger. When frame time stays above 1.4x its rolling median for 0.5 s, appends one line
## to user://perf_spikes.log with what the scene looked like at that moment (draws, primitives,
## GPU/CPU ms, particles, lights, enemies, shades, nodes, player position). Throttled to one line
## per 3 s. Send the file over and the cause is usually obvious.
## Also runs the post-build performance pass (Atmosphere.post_build: terrain occluder, flora
## detail) once the Realm reports `realm_done`, so no builder has to call it.

const PATH := "user://perf_spikes.log"
const LightDirectorScript := preload("res://core/world/light_director.gd")
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
var _pcensus_t := 30.0 if "--pcensus" in OS.get_cmdline_user_args() else -1.0


## Brackets every node's _process / _physics_process in the frame (the first and last to run): the scripts' own
## time, without the renderer's or the frame's jitter. `--pcensus` measures with it; --fps-log prints it.
class Mark extends Node:
	var cb: Callable
	var phys := false
	func _process(_d: float) -> void:
		if not phys:
			cb.call()
	func _physics_process(_d: float) -> void:
		if phys:
			cb.call()


var _sp0 := 0
var _sp_acc := 0.0                ## idle scripts, usec this window
var _pp0 := 0
var _pp_acc := 0.0                ## physics scripts, usec this window
var _sp_frames := 0
var _pp_ticks := 0
var _meters := false
var _it0 := -1                    ## this frame's first mark (physics or idle)
var _busy: PackedFloat32Array = PackedFloat32Array()   ## frame start -> after draw, ms, this window


var _sp1 := -1
var _pe := -1
var _seg := [0.0, 0.0]            ## usec: last physics script -> first idle script (physics step, nav); last idle script -> after draw
var _seg_n := [0, 0]


var _pre := -1
var _flush := 0.0


func _on_post_draw() -> void:
	if _sp1 >= 0:
		_seg[1] += Time.get_ticks_usec() - _sp1
		_seg_n[1] += 1
		if _pre > _sp1:
			_flush += _pre - _sp1
		_sp1 = -1
	if _it0 >= 0:
		_busy.append((Time.get_ticks_usec() - _it0) / 1000.0)
	_it0 = -1


## busy ms: mean, 95th percentile, share of frames over 8.33 ms (120 Hz), since the last call
func _busy_stats() -> Vector3:
	var a := _busy
	_busy = PackedFloat32Array()
	if a.is_empty():
		return Vector3(-1, -1, -1)
	a.sort()
	var sum := 0.0
	var over := 0
	for v in a:
		sum += v
		if v > 8.33:
			over += 1
	return Vector3(sum / a.size(), a[int(a.size() * 0.95)], 100.0 * over / a.size())


func _meter() -> void:
	if _meters:
		return
	_meters = true
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre = Time.get_ticks_usec())
	var marks := [[-2000000000, false, func() -> void:
			_sp0 = Time.get_ticks_usec()
			if _it0 < 0: _it0 = _sp0
			if _pe >= 0: _seg[0] += _sp0 - _pe; _seg_n[0] += 1
			_pe = -1],
		[2000000000, false, func() -> void: _sp1 = Time.get_ticks_usec(); _sp_acc += _sp1 - _sp0; _sp_frames += 1],
		[-2000000000, true, func() -> void:
			_pp0 = Time.get_ticks_usec()
			if _it0 < 0: _it0 = _pp0],
		[2000000000, true, func() -> void: _pe = Time.get_ticks_usec(); _pp_acc += _pe - _pp0; _pp_ticks += 1]]
	for m: Array in marks:
		var n := Mark.new()
		n.cb = m[2]
		n.phys = m[1]
		n.process_mode = Node.PROCESS_MODE_ALWAYS
		if m[1]:
			n.process_physics_priority = m[0]
		else:
			n.process_priority = m[0]
		get_tree().root.add_child.call_deferred(n)


## (idle scripts ms a frame, physics scripts ms a frame) since the last call.
func _script_ms() -> Vector2:
	var v := Vector2(_sp_acc / 1000.0 / maxf(1.0, _sp_frames), _pp_acc / 1000.0 / maxf(1.0, _sp_frames))
	_sp_acc = 0.0
	_pp_acc = 0.0
	_sp_frames = 0
	_pp_ticks = 0
	return v


## `--pcensus` (measurement only): 30 s in, every processing node is grouped by its script (or its engine class for
## animation players / trees and particles); each group's processing is switched off for a moment and the frame time
## it was costing printed, heaviest first. Everything is switched back on after.
var _pcensus_running := false
var _drawlist_t := 25.0 if "--drawlist" in OS.get_cmdline_user_args() else -1.0
var _tp_t := 8.0                       ## `--tp=x,z[,yaw]` (measurement only): the wanderer is put there 8 s in


## `--drawlist` (measurement only): every mesh instance in the camera's view (frustum, draw range, layers), by
## top-level part and by host, with what merging each host's plain meshes by material / shadow / range would leave.
func _drawlist() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var planes := cam.get_frustum()
	var at := cam.global_position
	var parts := {}
	var hosts := {}
	var flora := {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or (g.layers & cam.cull_mask) == 0:
			continue
		var ab := g.global_transform * g.get_aabb()
		var d := at.distance_to(ab.get_center())
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		if g.visibility_range_begin > 0.0 and d < g.visibility_range_begin - g.visibility_range_begin_margin:
			continue
		var inside := true
		for pl in planes:
			var c := ab.get_center()
			var e := ab.size * 0.5
			var r := absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z
			if pl.distance_to(c) > r:
				inside = false
				break
		if not inside:
			continue
		var top: Node = g
		while top.get_parent() != null and top.get_parent() != get_parent() and top.get_parent() != get_tree().root:
			top = top.get_parent()
		var surf := 1
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			surf = (g as MeshInstance3D).mesh.get_surface_count()
		var pk := String(top.name)
		parts[pk] = int(parts.get(pk, 0)) + surf
		if pk == "RealmFlora":
			var fk := String(g.name).rstrip("0123456789_")
			var fl: Variant = g.get_meta(&"flora", null) if g.has_meta(&"flora") else null
			if fl is Array and (fl as Array).size() > 1:
				fk = "%s/%s shadow %d" % [fl[0], fl[1], int(g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)]
			flora[fk] = int(flora.get(fk, 0)) + 1
		var host := g.get_parent()
		var hk := "%s/%s#%d" % [pk, host.name, host.get_instance_id() % 10000]
		if not hosts.has(hk):
			hosts[hk] = {"n": 0, "keys": {}, "scripted": 0, "mm": 0}
		var H: Dictionary = hosts[hk]
		H.n += surf
		if g is MultiMeshInstance3D:
			H.mm += 1
		elif g.get_script() != null:
			H.scripted += 1
		elif g is MeshInstance3D:
			var mi := g as MeshInstance3D
			var mat: Variant = mi.material_override if mi.material_override else (mi.get_active_material(0) if mi.mesh else null)
			var key := "%s|%d|%d|%d|%d" % [mat.get_instance_id() if mat else 0, mi.cast_shadow, roundi(mi.visibility_range_end), roundi(mi.visibility_range_begin), mi.layers]
			H.keys[key] = true
	var fks := flora.keys()
	fks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(flora[a]) > int(flora[b]))
	for k: Variant in fks.slice(0, 30):
		print("DRAWLIST flora %4d  %s" % [flora[k], k])
	var pks := parts.keys()
	pks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(parts[a]) > int(parts[b]))
	for k: Variant in pks.slice(0, 20):
		print("DRAWLIST part %5d  %s" % [parts[k], k])
	var hks := hosts.keys()
	hks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(hosts[a].n) - (hosts[a].keys as Dictionary).size() > int(hosts[b].n) - (hosts[b].keys as Dictionary).size())
	var save := 0
	for k: Variant in hks:
		var H2: Dictionary = hosts[k]
		var plain := int(H2.n) - int(H2.mm) - int(H2.scripted)
		save += maxi(0, plain - (H2.keys as Dictionary).size())
	print("DRAWLIST merging every host's plain meshes would save %d surfaces in view" % save)
	for k: Variant in hks.slice(0, 40):
		var H: Dictionary = hosts[k]
		print("DRAWLIST host %4d surfaces, %3d mergeable groups, %3d multimesh, %3d scripted  %s" % [H.n, (H.keys as Dictionary).size(), H.mm, H.scripted, k])
var _rcensus_t := 30.0 if "--rcensus" in OS.get_cmdline_user_args() else -1.0


## `--rcensus` (measurement only): each top-level part of the world hidden for a moment; the frame time
## (wall clock, base / hidden / base) it was costing, heaviest first.
func _rcensus() -> void:
	var zone := get_parent()
	var parts: Array[Node] = []
	for c in zone.get_children():
		if c is Node3D and (c as Node3D).visible:
			parts.append(c)
	for c in get_tree().root.get_children():
		if c != zone and c is Node3D and (c as Node3D).visible:
			parts.append(c)
	var rows: Array = []
	if "--rcensus-all" in OS.get_cmdline_user_args():
		var hud: Array[Node] = []
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if (n as CanvasLayer).visible:
				hud.append(n)
		for rep in 3:
			var a0 := await _wall_frame(120)
			for c in parts:
				(c as Node3D).visible = false
			await _wall_frame(6)
			var w0 := await _wall_frame(120)
			for c in parts:
				(c as Node3D).visible = true
			for h in hud:
				(h as CanvasLayer).visible = false
			await _wall_frame(6)
			var h0 := await _wall_frame(120)
			for h in hud:
				(h as CanvasLayer).visible = true
			await _wall_frame(6)
			print("RCENSUS all: base %.2f | world hidden %.2f | HUD hidden %.2f ms" % [a0, w0, h0])
		return
	for c in parts:
		var a := await _wall_frame(90)
		(c as Node3D).visible = false
		await _wall_frame(6)
		var off := await _wall_frame(90)
		(c as Node3D).visible = true
		await _wall_frame(6)
		var b := await _wall_frame(90)
		rows.append([(a + b) * 0.5 - off, String(c.name)])
		print("RCENSUS- %6.2f ms  %s  (%.2f / %.2f, off %.2f)" % [(a + b) * 0.5 - off, c.name, a, b, off])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for r: Array in rows:
		if absf(float(r[0])) > 0.08:
			print("RCENSUS %6.2f ms  %s" % [r[0], r[1]])
	print("RCENSUS done")


func _wall_frame(frames: int) -> float:
	var t0 := Time.get_ticks_usec()
	for _i in frames:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / frames


func _pcensus() -> void:
	_pcensus_running = true
	_meter()
	for _i in 10:
		await get_tree().process_frame
	# canvas items that redraw (their _draw runs outside any script's process): redraws in 2 s
	var counts := {}
	var conns := []
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci.get_script() == null:
			continue
		var cb := func() -> void: counts[ci] = int(counts.get(ci, 0)) + 1
		ci.draw.connect(cb)
		conns.append([ci, cb])
	var t0 := Time.get_ticks_msec()
	for _i in 240:
		await get_tree().process_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	for c: Array in conns:
		if is_instance_valid(c[0]):
			(c[0] as CanvasItem).draw.disconnect(c[1])
	var dr: Array = []
	for ci: Variant in counts:
		if is_instance_valid(ci):
			dr.append([float(counts[ci]) / secs, String((ci as Node).get_path())])
	dr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in dr.slice(0, 25):
		print("PREDRAW %6.1f /s  %s" % [r[0], r[1]])

	var kinds := {}
	for n in get_tree().root.find_children("*", "", true, false):
		if n == self or n is Mark:
			continue
		var key := ""
		if n is AnimationMixer:
			key = "<%s>" % n.get_class()
		elif n.get_script() != null and (n.is_processing() or n.is_physics_processing()):
			key = String((n.get_script() as Script).resource_path).get_file()
		if key == "":
			continue
		if not kinds.has(key):
			kinds[key] = []
		kinds[key].append(n)
	var rows: Array = []
	print("PCENSUS %d kinds" % kinds.size())
	for key: String in kinds:
		var nodes: Array = kinds[key]
		var base := await _mean_frame(60)
		var saved := []
		for n: Node in nodes:
			if not is_instance_valid(n):
				saved.append(null)
				continue
			if n is AnimationMixer:
				saved.append([(n as AnimationMixer).active])
				(n as AnimationMixer).active = false
			else:
				saved.append([n.is_processing(), n.is_physics_processing()])
				n.set_process(false)
				n.set_physics_process(false)
		await _mean_frame(5)
		var off := await _mean_frame(60)
		for i in nodes.size():
			var n: Node = nodes[i]
			if saved[i] == null or not is_instance_valid(n):
				continue
			if n is AnimationMixer:
				(n as AnimationMixer).active = saved[i][0]
			else:
				n.set_process(saved[i][0])
				n.set_physics_process(saved[i][1])
		await _mean_frame(5)
		var base2 := await _mean_frame(60)
		var cost := (base + base2) * 0.5 - off
		rows.append([cost, key, nodes.size()])
		print("PCENSUS- %6.2f ms  %4d  %s  (base %.2f / %.2f, off %.2f)" % [cost, nodes.size(), key, base, base2, off])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in rows:
		print("PCENSUS %6.2f ms  %4d  %s" % [r[0], r[2], r[1]])
	print("PCENSUS done")


func _mean_frame(frames: int) -> float:
	_script_ms()
	for _i in frames:
		await get_tree().process_frame
	var v := _script_ms()
	return v.x + v.y


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
	if _tp_t > 0.0:
		_tp_t -= delta
		if _tp_t <= 0.0:
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--tp="):
					var v := a.trim_prefix("--tp=").split(",")
					var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
					if pl and v.size() >= 2:
						var x := float(v[0])
						var z := float(v[1])
						pl.teleport(Vector3(x, RealmLayout.ground(pl.get_world_3d().direct_space_state, x, z) + 0.2, z))
						if v.size() >= 3:
							pl.set_view(float(v[2]), -0.08)
	if _drawlist_t > 0.0:
		_drawlist_t -= delta
		if _drawlist_t <= 0.0:
			_drawlist()
	if _rcensus_t > 0.0:
		_rcensus_t -= delta
		if _rcensus_t <= 0.0:
			_rcensus()
	if _pcensus_t > 0.0:
		_pcensus_t -= delta
		if _pcensus_t <= 0.0:
			_pcensus()
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
			_meter()
			var sm := _script_ms() if not _pcensus_running else Vector2(-1, -1)
			var bs := _busy_stats()
			print("FPS3 scripts idle %.2f physics %.2f ms a frame | busy mean %.2f p95 %.2f over-8.33 %.1f%% | step+nav %.2f ms a tick, flush+canvas+draw %.2f ms a frame (of it before the draw %.2f)" % [sm.x, sm.y, bs.x, bs.y, bs.z,
				_seg[0] / 1000.0 / maxi(1, _seg_n[0]), _seg[1] / 1000.0 / maxi(1, _seg_n[1]), _flush / 1000.0 / maxi(1, _seg_n[1])])
			_flush = 0.0
			_seg = [0.0, 0.0]
			_seg_n = [0, 0]
			var ld := get_tree().root.find_child("LightDirector", true, false)
			if ld and ld.get_script() == LightDirectorScript:
				var st: Vector3i = (ld as LightDirectorScript).stats()
				print("FPS4 lights governed %d, local in reach %d, cut by budget %d" % [st.x, st.y, st.z])
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

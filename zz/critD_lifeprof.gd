extends Node
## Wildlife script-time breakdown (critique D, r29), headless:
##   godot --headless --path . res://zz/critD_lifeprof.tscn [-- --at=70,-20]
## At the fen (the busiest spot), times each active group's tick() and its buffer write alone over
## 300 calls, so the cost per kind splits into logic and MultiMesh writing. Also reports the
## director's own frame (perf_us) after 4 s. Holds Travel._busy; quits by itself.
## Ends LIFEPROF DONE.

var main: Node
var t := 0.0
var started := false
var at := Vector3(70, 0, -20)


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector3(float(v[0]), 0, float(v[1]))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 240000:
		print("LIFEPROF TIMEOUT")
		get_tree().quit(1)
		return
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		return
	started = true
	_run()


func _run() -> void:
	var w := main.get_node("Wildlife")
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, at.x, at.z)
	player.global_position = Vector3(at.x, y + 0.2, at.z)
	for i in 240:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	var ctx := {"cam": cam.global_position, "player": player.global_position, "player_speed": 0.0, "enemies": [] as Array[Vector3],
		"time": 100.0, "dt": 1.0 / 60.0, "weather": w.weather.state, "quiet": true, "tide": false}
	var tick := {}
	var write := {}
	var n := {}
	for g in w.groups:
		if not g.visible:
			continue
		var k := String(g.kind)
		var t0 := Time.get_ticks_usec()
		for i in 300:
			ctx.time = 100.0 + float(i) / 60.0
			g.tick(1.0 / 60.0, ctx)
		var t1 := Time.get_ticks_usec()
		for i in 300:
			g._write()
		var t2 := Time.get_ticks_usec()
		tick[k] = float(tick.get(k, 0.0)) + float(t1 - t0) / 300.0
		write[k] = float(write.get(k, 0.0)) + float(t2 - t1) / 300.0
		n[k] = int(n.get(k, 0)) + 1
	for k: String in tick:
		print("LIFEPROF %-7s groups %d  tick %.1f us (of which write %.1f us) per frame if all ticked" % [k, n[k], tick[k], write[k]])
	# the r28 write path (a PackedFloat32Array per creature from row(), every buffer and box re-sent)
	# against the r29 one, on the same birds: A/B within one run
	var LG := preload("res://core/life/wildlife/life_group.gd")
	var old_us := 0.0
	var new_us := 0.0
	var nb := 0
	for g in w.groups:
		if not g.visible or not ("birds" in g) or g.get("mmi") == null:
			continue
		var birds: Array = g.get("birds")
		var mm: MultiMesh = (g.get("mmi") as MultiMeshInstance3D).multimesh
		var c: Vector3 = g.center
		var t0 := Time.get_ticks_usec()
		for i in 300:
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for b in birds:
				lo = lo.min(b.pos)
				hi = hi.max(b.pos)
			mm.custom_aabb = AABB(lo - c - Vector3(1.2, 0.6, 1.2), hi - lo + Vector3(2.4, 2.0, 2.4))
			var buf := PackedFloat32Array()
			for b in birds:
				var basis := Basis(Vector3.UP, float(b.yaw))
				buf.append_array(LG.row(Transform3D(basis, (b.pos as Vector3) - c), Color(float(b.fly), float(b.head), float(b.gait), float(b.pitch))))
			mm.buffer = buf
		var t1 := Time.get_ticks_usec()
		for i in 300:
			g._write()
		var t2 := Time.get_ticks_usec()
		old_us += float(t1 - t0) / 300.0
		new_us += float(t2 - t1) / 300.0
		nb += birds.size()
	print("LIFEPROF write path for %d birds: r28 row() %.1f us, r29 put+commit %.1f us per write of all" % [nb, old_us, new_us])
	# the director's own parts (each called 300 times as it would be per frame)
	var parts := {}
	var tA := Time.get_ticks_usec()
	for i in 300:
		w.phenomena.step(1.0 / 60.0, player.global_position, [] as Array[Vector3])
	parts["phenomena"] = float(Time.get_ticks_usec() - tA) / 300.0
	tA = Time.get_ticks_usec()
	for i in 300:
		w.tracks.step(1.0 / 60.0, 0.0)
	parts["tracks"] = float(Time.get_ticks_usec() - tA) / 300.0
	tA = Time.get_ticks_usec()
	for i in 300:
		w.weather._step(1.0 / 60.0)
	parts["weather"] = float(Time.get_ticks_usec() - tA) / 300.0
	tA = Time.get_ticks_usec()
	for i in 300:
		w._process(1.0 / 60.0)
	parts["director frame (all)"] = float(Time.get_ticks_usec() - tA) / 300.0
	print("LIFEPROF parts (us per call) ", parts)
	# an owl group's parts
	for g in w.groups:
		if String(g.kind) != "owl" or not g.visible:
			continue
		var tq := Time.get_ticks_usec()
		for i in 300:
			g._mice_step(1.0 / 60.0, ctx)
		var mice_us := float(Time.get_ticks_usec() - tq) / 300.0
		tq = Time.get_ticks_usec()
		for i in 300:
			g._calls(1.0 / 60.0, ctx)
		var calls_us := float(Time.get_ticks_usec() - tq) / 300.0
		tq = Time.get_ticks_usec()
		for i in 300:
			g._is_still()
			g._mice_are_still()
		var still_us := float(Time.get_ticks_usec() - tq) / 300.0
		tq = Time.get_ticks_usec()
		for i in 300:
			g.busy()
		var busy_us := float(Time.get_ticks_usec() - tq) / 300.0
		print("LIFEPROF owl %s: %d birds %d mice  mice_step %.1f  calls %.1f  still %.1f  busy %.1f us" % [g.name, g.birds.size(), g.mice.size(), mice_us, calls_us, still_us, busy_us])
	if "--thunder" in OS.get_cmdline_user_args():
		# life_test's worst case: a fast run through the fronts (thunder after thunder puts every
		# roost up), then back to the fen
		var B1: GDScript = load("res://core/life/wildlife/life_birds.gd")
		w.weather.speed = 400.0
		for i in 240:
			await get_tree().process_frame
		w.weather.speed = 1.0
		w.weather.force("clear", true)
		await get_tree().create_timer(1.5).timeout
		player.global_position = Vector3(at.x, y + 0.2, at.z)
		await get_tree().create_timer(1.0).timeout
		w.kind_us.clear()
		if B1.get("PROF") is Dictionary:
			(B1.get("PROF") as Dictionary).clear()
		var fz := Engine.get_process_frames()
		await get_tree().create_timer(3.5).timeout
		var nz := maxi(Engine.get_process_frames() - fz, 1)
		var pz := {}
		for k: String in w.kind_us:
			pz[k] = snappedf(float(w.kind_us[k]) / nz, 0.1)
		print("LIFEPROF thunder case, live by kind ", pz, " total %.0f (director %.0f weather %.0f) median %.0f" % [w.perf_us + w.weather.perf_us, w.perf_us, w.weather.perf_us, w.perf_p50])
		if B1.get("PROF") is Dictionary:
			var pr: Dictionary = B1.get("PROF")
			var outp := {}
			for k: String in pr:
				outp[k] = snappedf(float(pr[k]) / nz, 0.1)
			print("LIFEPROF thunder birds sections ", outp)
		var states := {}
		for g in w.groups:
			if g.visible and "birds" in g:
				var st := []
				for b in g.birds:
					st.append(int(b.get("state", -1)))
				states[g.name] = st
		print("LIFEPROF thunder bird states ", states)
		get_tree().quit(0)
		return
	# the busy case: everything near takes fright, then 4 s of flight, flocks and flight paths
	w.alarm(player.global_position, 1.0)
	for i in 30:
		await get_tree().process_frame
	w.kind_us.clear()
	var B0: GDScript = load("res://core/life/wildlife/life_birds.gd")
	if B0.get("PROF") is Dictionary:
		(B0.get("PROF") as Dictionary).clear()
	var tB := Time.get_ticks_usec()
	for i in 120:
		w._process(1.0 / 60.0)
	var tight := float(Time.get_ticks_usec() - tB) / 120.0
	var per_t := {}
	for k: String in w.kind_us:
		per_t[k] = snappedf(float(w.kind_us[k]) / 120.0, 0.1)
	print("LIFEPROF scared, tight loop: director frame %.0f us, by kind %s" % [tight, per_t])
	var B: GDScript = load("res://core/life/wildlife/life_birds.gd")
	if B.get("PROF") is Dictionary:
		var pr: Dictionary = B.get("PROF")
		var outp := {}
		for k: String in pr:
			outp[k] = snappedf(float(pr[k]) / 120.0, 0.1)
		print("LIFEPROF birds sections (us/frame, tight loop incl. earlier) ", outp)
	w.kind_us.clear()
	w._perf_acc = 0.0
	w._perf_n = 0
	var f0 := Engine.get_process_frames()
	for i in 240:
		await get_tree().process_frame
	var nf := maxi(Engine.get_process_frames() - f0, 1)
	var per := {}
	for k: String in w.kind_us:
		per[k] = snappedf(float(w.kind_us[k]) / nf, 0.1)
	print("LIFEPROF live by kind (us/frame) ", per)
	print("LIFEPROF live total %.0f us (director %.0f, weather %.0f)" % [w.perf_us + w.weather.perf_us, w.perf_us, w.weather.perf_us])
	print("LIFEPROF director per frame: median %.0f  p90 %.0f  worst %.0f us" % [w.perf_p50, w.perf_p90, w.perf_max])
	print("LIFEPROF DONE")
	get_tree().quit(0)

extends Zone
## Stair of Ascension. Unique bits: gothic raise, demo walk, benchmark, shade smoke test.
## User args (after "--"):  --demo  --quit-after-demo  --shots-dir=<path>  --test-shade
##   --walk-rec=<dir>  --walk-frames=N  in-game OTS walk dump (player cam, not debug rig)
##   --deepdive-rec=<dir>  --deepdive-hz=12  continuous JPEG dump during demo
##   --perf-baseline  fullscreen vsync-off benches at sanctuary / mid-stair / summit

var _shots_dir := ""
var _args: PackedStringArray
const BENCH_SECONDS := 10.0
const SessionState := preload("res://core/world/session_state.gd")
var _bench_t := -1.0
var _bench_frames := PackedFloat32Array()
var _bench_gpu := PackedFloat32Array()
var _bench_cpu := PackedFloat32Array()
var _bench_draws := 0
var _bench_prims := 0
var _bench_n := 0
var _bench_quit := false
var _bench_vsync := DisplayServer.VSYNC_ENABLED
var _bench_last := ""
var _walk_rec := ""
var _walk_frames := 36
var _deepdive = null

## Streamed areas (docs/ZONE_PLAN.md). Anchors are area centres; radii in metres (horizontal).
const AREAS: Array[Dictionary] = [
	# load_r covers the whole Realm: the Ossuary loads at boot under the loading screen instead of a
	# ~265 ms freeze when a player first walks within 110 m of it (from the far west)
	{"id": "ossuary", "source": "res://world/areas/ossuary/ossuary.gd", "anchor": Vector3(19.0, 4.0, -36.0), "load_r": 400.0, "unload_r": 500.0},
]


func _ready() -> void:
	super._ready()
	# r30: there is no stair under the Realm any more; the card names the land
	if Realm.enabled():
		Events.zone_entered.emit("THE UMBRAL REACHES", "where the sky turns inward")
	else:
		Events.zone_entered.emit("STAIR OF ASCENSION", "where the sky turns inward")
	# Summit glass removed with the Crimson Vale — next night TBD.
	var dress_path := "res://world/zones/ascension/dress.tscn"
	if ResourceLoader.exists(dress_path):
		add_child((load(dress_path) as PackedScene).instantiate())
	elif not Realm.enabled():
		Gothic.raise(self)            # the stair's window gobos (r30: under the Realm they lit windows that no longer exist)
	Atmosphere.apply(self, _env, _cam, _moon, 82.0, Color("#12183A"), Color("#060A1C"), Color("#1E4AA0"))   # fog glows azure, not violet
	_spawn_glimmers()
	if not Realm.enabled():
		EnemySpawner.seed_stair(self)
	else:
		EnemySpawner.seed_realm(self)     # camps of the redesigned zone (RealmBosses)
	AreaStreamer.attach(self, AREAS)
	var pw := PerfWatch.new()
	pw.name = "PerfWatch"
	add_child(pw)
	LavaWorks.attach(self)
	var satchel := Satchel.new()
	satchel.name = "Satchel"
	add_child(satchel)
	var amb := Ambience.new()
	amb.name = "Ambience"
	add_child(amb)
	# The Landing brazier stood at x 1.9, in the mouth of the Ossuary bone bridge; move it to the
	# landing's west side (runtime, so main.tscn stays untouched; kindle memory is by name).
	var landing := get_node_or_null("Zone/Braziers/Landing") as Node3D
	if landing and not Realm.enabled():          # under the Realm, RealmBosses places it
		landing.position = Vector3(-1.6, landing.position.y, landing.position.z)
	finish_zone_setup()
	if _player.get_node_or_null("CameraRig/Pitch/SpringArm") is SpringArm3D:
		(_player.get_node("CameraRig/Pitch/SpringArm") as SpringArm3D).spring_length = 3.7
	_args = OS.get_cmdline_user_args()
	for a in _args:
		if a.begins_with("--shots-dir="):
			_shots_dir = a.trim_prefix("--shots-dir=")
		elif a.begins_with("--walk-rec="):
			_walk_rec = a.trim_prefix("--walk-rec=")
		elif a.begins_with("--walk-frames="):
			_walk_frames = maxi(8, int(a.trim_prefix("--walk-frames=")))
	_deepdive = DeepdiveRec.from_args(_args)
	if _walk_rec != "":
		_record_walk()
	elif "--demo" in _args:
		if _deepdive:
			_deepdive.start(self)
		_start_demo()
	elif "--bench" in _args:
		_bench_quit = true
		_arm_benchmark()
	elif "--perf-baseline" in _args:
		_run_perf_baseline()
	elif "--test-shade" in _args:
		_test_shade()


## Drive the real Player + OTS camera forward; dump JPEGs then quit.
func _record_walk() -> void:
	DirAccess.make_dir_recursive_absolute(_walk_rec)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.global_position = Vector3(0.0, 1.2, 6.0)
	_player.set_view(0.0, -0.22)
	_player.debug_drive(Vector3(0.0, 0.0, -1.0), false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.35).timeout  # let title card begin fading
	for i in _walk_frames:
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_jpg(_walk_rec.path_join("ingame_%04d.jpg" % i), 0.78)
	_player.debug_drive(Vector3.ZERO, false)
	print("WALK_REC frames=", _walk_frames, " dir=", _walk_rec, " pos=", _player.global_position)
	get_tree().quit()


## Torn down (quit, or the Deeper Night rebuilding the night in this process): the night's static
## state belongs to this build only. The list lives in core/world/session_state.gd.
func _exit_tree() -> void:
	SessionState.reset_night()


func _process(delta: float) -> void:
	super._process(delta)
	if _deepdive:
		_deepdive.tick(delta)
	if _bench_t >= 0.0:
		_player.velocity = Vector3.ZERO
		_bench_t += delta
		_bench_frames.append(delta)
		var rid := get_viewport().get_viewport_rid()
		_bench_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_bench_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		_bench_draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_bench_prims += int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		_bench_n += 1
		if _bench_t >= BENCH_SECONDS:
			_finish_benchmark()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("demo") and not _player.autopilot:
		_start_demo()
	elif event.is_action_pressed("benchmark"):
		_start_benchmark()


func _spawn_glimmers() -> void:
	var g := Glimmers.new()
	g.name = "Glimmers"
	g.seed_n = 11
	g.half = 30.0
	g.z_min = -72.0
	g.z_max = 40.0
	g.skip_corridor = true
	g.skip_river = false
	g.skip_shards = true
	g.palettes = PackedColorArray([
		Color(0.55, 0.85, 2.6),
		Color(1.55, 0.55, 3.3),
		Color(0.45, 1.05, 3.1),
		Color(0.85, 0.6, 2.4),
	])
	add_child(g)


# --- Benchmark: F8 samples frame times where the player is standing, so optimisation work has
# a number from real hardware instead of a guess. Result is pinned in the F3 overlay.

func _start_benchmark() -> void:
	if _bench_t >= 0.0:
		return
	_bench_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_bench_t = 0.0
	_bench_frames = PackedFloat32Array()
	_bench_gpu = PackedFloat32Array()
	_bench_cpu = PackedFloat32Array()
	_bench_draws = 0
	_bench_prims = 0
	_bench_n = 0
	Events.toast.emit("Benchmarking %d s - hold still" % int(BENCH_SECONDS))


func _mean_positive(samples: PackedFloat32Array) -> float:
	var s := 0.0
	var n := 0
	for v in samples:
		if v > 0.0:
			s += v
			n += 1
	return s / float(maxi(n, 1))


func _finish_benchmark() -> void:
	DisplayServer.window_set_vsync_mode(_bench_vsync)
	_bench_t = -1.0
	var n := _bench_frames.size()
	if n == 0:
		return
	var times := Array(_bench_frames)
	times.sort()                      # ascending frame time, so the slowest frames are last
	var total := 0.0
	for t in times:
		total += t
	# 1% low: the mean framerate across the slowest 1% of frames, which is what stutter feels like.
	var slowest := maxi(1, n / 100)
	var slow_total := 0.0
	for i in range(n - slowest, n):
		slow_total += times[i]

	var avg_fps := n / total
	var low_fps := slowest / slow_total
	var worst: float = times[n - 1]
	var gpu := _mean_positive(_bench_gpu)
	var cpu := _mean_positive(_bench_cpu)
	var draws := _bench_draws / maxi(_bench_n, 1)
	var prims := _bench_prims / maxi(_bench_n, 1)
	var win := get_window().size
	var scale_3d := get_viewport().scaling_3d_scale
	var summary := "avg %.1f  ·  1%% low %.1f  ·  GPU %.2f ms  ·  render CPU %.2f ms  ·  worst %.1f ms  ·  %d draws  ·  %s prims  ·  3D %dx%d @ %d%% (window %dx%d)" % [
		avg_fps, low_fps, gpu, cpu, worst * 1000.0, draws,
		String.num_int64(prims),
		roundi(float(win.x) * scale_3d), roundi(float(win.y) * scale_3d),
		roundi(scale_3d * 100.0), win.x, win.y]
	_bench_last = summary
	print("BENCH ", summary)
	Events.benchmark_done.emit(summary)
	Events.toast.emit("avg %.0f fps  ·  1%% low %.0f fps" % [avg_fps, low_fps])
	if _bench_quit:
		get_tree().quit()


func _arm_benchmark() -> void:
	await get_tree().create_timer(6.0).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_start_benchmark()


func _stand_at(marker: Marker3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var origin := marker.global_position
	var q := PhysicsRayQueryParameters3D.create(
		origin + Vector3(0.0, 12.0, 0.0), origin + Vector3(0.0, -80.0, 0.0))
	q.collision_mask = 1
	q.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3 = origin + Vector3(0.0, 0.2, 0.0)
	if not hit.is_empty():
		pos = (hit.position as Vector3) + Vector3(0.0, 0.15, 0.0)
	_player.velocity = Vector3.ZERO
	_player.global_position = pos
	_player.checkpoint = pos
	var yaw := float(marker.get_meta("yaw", 0.0))
	var pitch := float(marker.get_meta("pitch", 0.0))
	_player.set_view(yaw, pitch)
	var rig := _player.get_node_or_null("CameraRig") as Node3D
	if rig:
		rig.rotation.y = yaw
	var pitch_node := _player.get_node_or_null("CameraRig/Pitch") as Node3D
	if pitch_node:
		pitch_node.rotation.x = pitch
	print("PERF_BASELINE stand marker=", marker.name, " hit=", not hit.is_empty(), " pos=", pos)


func _run_perf_baseline() -> void:
	# In-memory only — do not Settings.apply(), which would write the owner's cfg.
	Settings.fullscreen = true
	Settings.vsync = false
	_apply_settings()
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(1.2).timeout
	print("PERF_BASELINE settings preset=%d shadows=%d fog=%s ssao=%s glow=%s grade=%s scale=%.2f cap=%d window=%s mode=%d screen=%s render=%s" % [
		Settings.quality_preset, Settings.shadow_quality, Settings.fog_enabled,
		Settings.ssao_enabled, Settings.glow_enabled, Settings.grade_enabled,
		Settings.render_scale, Settings.render_height_cap(),
		str(get_window().size), get_window().mode,
		str(DisplayServer.screen_get_size()),
		str(get_viewport().get_visible_rect().size)])
	await get_tree().create_timer(1.0).timeout
	var points: Array = [
		["sanctuary", $Demo/WP01_Sanctuary],
		["mid-stair", $Demo/WP05_Climb],
		["summit", $Demo/WP11_Gaze],
	]
	for p in points:
		await _stand_at(p[1] as Marker3D)
		await get_tree().create_timer(0.6).timeout
		_start_benchmark()
		while _bench_t >= 0.0:
			await get_tree().process_frame
		print("PERF_BASELINE point=", p[0], " pos=", _player.global_position, " ", _bench_last)
	get_tree().quit()


# --- Demo: walks the Demo/WP* markers, kindles braziers, optionally captures shots

func _start_demo() -> void:
	var markers: Array[Marker3D] = []
	for c in $Demo.get_children():
		if c is Marker3D:
			markers.append(c)
	if not Events.autopilot_reached.is_connected(_on_marker):
		Events.autopilot_reached.connect(_on_marker)
		Events.autopilot_finished.connect(_on_demo_done)
	_player.start_autopilot(markers)


func _on_marker(marker_name: String) -> void:
	var m := $Demo.get_node(marker_name) as Marker3D
	if _shots_dir != "" and m.get_meta("shot", false):
		await get_tree().create_timer(float(m.get_meta("shot_delay", 0.6))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shots_dir.path_join("%s.png" % marker_name))
		print("SHOT ", marker_name)


func _on_demo_done() -> void:
	var lit := 0
	for b in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if b is Brazier and (b as Brazier).lit:
			lit += 1
	print("SMOKE demo_done braziers_lit=%d light_zones=%d gloom=%.1f pos=%s hollowed=%d" % [
		lit, LightGrid.count(), _player.gloom, _player.global_position, _player.hollow_count])
	if _deepdive:
		_deepdive.stop()
	if "--quit-after-demo" in _args:
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()


# --- Shade test: stand in the dark at full Gloom; expect spawn, chase, Hollowed, respawn

func _test_shade() -> void:
	Events.shade_spawned.connect(func() -> void: print("SMOKE shade_spawned"))
	Events.hollowed.connect(func() -> void: print("SMOKE hollowed"))
	Events.respawned.connect(func(at: Vector3) -> void:
		print("SMOKE respawned at=%s gloom=%.1f" % [at, _player.gloom])
		await get_tree().create_timer(1.0).timeout
		get_tree().quit())
	await get_tree().create_timer(1.0).timeout
	_player.global_position = Vector3(0.0, 1.0, 8.0)
	_player.add_gloom(99.5)
	await get_tree().create_timer(15.0).timeout
	print("SMOKE shade_test_timeout")
	get_tree().quit(1)


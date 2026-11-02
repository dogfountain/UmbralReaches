extends Zone
## Stair of Ascension. Unique bits: gothic raise, demo walk, benchmark, shade smoke test.
## User args (after "--"):  --demo  --quit-after-demo  --shots-dir=<path>  --test-shade
##   --walk-rec=<dir>  --walk-frames=N  in-game OTS walk dump (player cam, not debug rig)
##   --deepdive-rec=<dir>  --deepdive-hz=12  continuous JPEG dump during demo

var _shots_dir := ""
var _args: PackedStringArray
const BENCH_SECONDS := 10.0
var _bench_t := -1.0
var _bench_frames := PackedFloat32Array()
var _bench_quit := false
var _bench_vsync := DisplayServer.VSYNC_ENABLED
var _walk_rec := ""
var _walk_frames := 36
var _deepdive = null


func _ready() -> void:
	super._ready()
	Events.zone_entered.emit("STAIR OF ASCENSION", "where the sky turns inward")
	# Summit glass removed with the Crimson Vale — next night TBD.
	load("res://core/world/gothic.gd").raise(self)
	load("res://core/world/atmosphere.gd").apply(self, _env, _cam, _moon, 82.0, Color("#12183A"), Color("#060A1C"), Color("#3A2480"))
	_spawn_glimmers()
	load("res://core/enemy/enemy_spawner.gd").seed_stair(self)
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
	_deepdive = load("res://core/debug/deepdive_rec.gd").from_args(_args)
	if _walk_rec != "":
		_record_walk()
	elif "--demo" in _args:
		if _deepdive:
			_deepdive.start(self)
		_start_demo()
	elif "--bench" in _args:
		_bench_quit = true
		_arm_benchmark()
	elif "--test-shade" in _args:
		_test_shade()


## Drive the real Player + OTS camera forward; dump JPEGs then quit.
func _record_walk() -> void:
	DirAccess.make_dir_recursive_absolute(_walk_rec)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.global_position = Vector3(0.0, 1.2, 6.0)
	_player.set("_yaw", 0.0)
	_player.set("_pitch", -0.22)
	if _player.get_node_or_null("CameraRig"):
		(_player.get_node("CameraRig") as Node3D).rotation.y = 0.0
	# World-space forward (facing -Z). action_press is unreliable before InputMap settles.
	_player.set_meta("force_wish", Vector3(0.0, 0.0, -1.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.35).timeout  # let title card begin fading
	for i in _walk_frames:
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_jpg(_walk_rec.path_join("ingame_%04d.jpg" % i), 0.78)
	_player.remove_meta("force_wish")
	print("WALK_REC frames=", _walk_frames, " dir=", _walk_rec, " pos=", _player.global_position)
	get_tree().quit()


func _process(delta: float) -> void:
	super._process(delta)
	if _deepdive:
		_deepdive.tick(delta)
	if _bench_t >= 0.0:
		_bench_t += delta
		_bench_frames.append(delta)
		if _bench_t >= BENCH_SECONDS:
			_finish_benchmark()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("demo") and not _player.autopilot:
		_start_demo()
	elif event.is_action_pressed("benchmark"):
		_start_benchmark()


func _spawn_glimmers() -> void:
	var g := Node3D.new()
	g.set_script(load("res://core/world/glimmers.gd"))
	g.name = "Glimmers"
	g.set("seed_n", 11)
	g.set("half", 30.0)
	g.set("z_min", -72.0)
	g.set("z_max", 40.0)
	g.set("skip_corridor", true)
	g.set("skip_river", false)
	g.set("skip_shards", true)
	g.set("palettes", PackedColorArray([
		Color(0.55, 0.85, 2.6),
		Color(1.55, 0.55, 3.3),
		Color(0.45, 1.05, 3.1),
		Color(0.85, 0.6, 2.4),
	]))
	add_child(g)


# --- Benchmark: F8 samples frame times where the player is standing, so optimisation work has
# a number from real hardware instead of a guess. Result is pinned in the F3 overlay.

func _start_benchmark() -> void:
	if _bench_t >= 0.0:
		return
	_bench_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_bench_t = 0.0
	_bench_frames = PackedFloat32Array()
	Events.toast.emit("Benchmarking %d s - hold still" % int(BENCH_SECONDS))


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
	var render := get_viewport().get_visible_rect().size
	var win := get_window().size
	var summary := "avg %.1f  ·  1%% low %.1f  ·  worst %.1f ms  ·  render %dx%d @ %d%% (window %dx%d)  ·  %d draws" % [
		avg_fps, low_fps, worst * 1000.0, int(render.x), int(render.y),
		roundi(get_viewport().scaling_3d_scale * 100.0), win.x, win.y,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	print("BENCH ", summary)
	Events.benchmark_done.emit(summary)
	Events.toast.emit("avg %.0f fps  ·  1%% low %.0f fps" % [avg_fps, low_fps])
	if _bench_quit:
		get_tree().quit()


func _arm_benchmark() -> void:
	await get_tree().create_timer(6.0).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_start_benchmark()


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


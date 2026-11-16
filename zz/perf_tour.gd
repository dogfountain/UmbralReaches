extends Node
## Windowed perf tour (1600x1000, vsync off, no fps cap for this run only; settings are set in
## memory and never saved, and Travel saves are blocked so the real save is not touched).
##   godot --path . res://zz/perf_tour.tscn [-- options]
## Phases (default: points then path):
##   points  the player stands at each view for SECONDS:  "PERF <point> fps .. 1%low .. worst .."
##   path    a fixed run through the Realm (west way to the henge, east way to the barrows and the
##           Ossuary gate, rift rim over the Crossing to the dais), driven like a player at a sprint;
##           per leg and in total: fps, 1% low, p99, worst frame, stddev, frames over 20/33 ms.
## Options:
##   --points-only / --path-only     one phase
##   --only=a,b                      only these points
##   --preset=0|1|2                  quality preset (default 1 Balanced); --fov=90 (default 90, Luke's)
##   --attrib[=point]                at the point (default the worst two), switch each render feature off
##                                   and on in paired windows and print what it costs (Metal reports no
##                                   GPU time, so this is how GPU cost is attributed)
##                                   --feat=a,b: only the features whose name contains a or b
##                                   --reps=N: on/off pairs per feature (default 2; prints the median pair)
##   --blame                         per-script process+physics cost at the first point
##   --stress=2                      render 2x2 the pixels: the GPU becomes the bottleneck at every view, so
##                                   fps compares GPU cost (a Mac at 120 Hz otherwise paces frames at the
##                                   display and the GPU clocks down: frame time then says little)
##   --shader=res://a.gdshader=/abs/b.gdshader   run with b's code in a (memory only, for A/B)
##   --census                        per view, what each top-level node / flora species adds (exact counts)
##   --pan=40                        points (and attrib) swing the view +-10 deg at up to 40 deg/s, like a
##                                   player looking about: motion blur and streaming work as in play
##   --luke                          Luke's pacing and window: vsync on, 144 fps cap, 1920x1080
##   --moon=k:v,...  --rs=atlas:N,filter:N   moon / shadow-atlas overrides once the Realm is built (A/B)
##   --hitches[=ms]                  points: print every frame over 20 ms (or ms): time into the window, draws
##                                   (path: frames over ms, default 33)
##   --loading                       run the real loading screen (build + shader warm-up) first
##   --early                         start measuring the moment the Realm is built (no 6 s settle):
##                                   shows what a player meets right after the load
## Frame time is the real frame delta (vsync off). "scripts" = every _process and _physics_process
## per frame (stamped first/last in line), "render-cpu" = the renderer's CPU side, "rest(gpu)" =
## frame - scripts - render-cpu: on Metal (no GPU timings) that is the GPU wait plus engine overhead.
const SECONDS := 4.0
const SETTLE := 1.2
var points := []
## Realm views (y = NAN: stand on the ground there). The first eight are the r19 set (compare runs).
var realm_points := [
	["r_spawn_west", Vector3(0.0, NAN, 30.0), PI * 0.5],
	# the Southern Downs (Luke's 104 fps, 7 Nov: 2866 draws, 421 omni at -147.7, 195.7), four ways round
	["r_orchard_save", Vector3(-100.8, NAN, 103.7), 0.0],            # Luke's save (88 fps in the release app, 7 Nov)
	["r_downs_w_n", Vector3(-147.7, NAN, 195.7), 0.0],
	["r_downs_w_e", Vector3(-147.7, NAN, 195.7), -PI * 0.5],
	["r_downs_w_s", Vector3(-147.7, NAN, 195.7), PI],
	["r_downs_w_w", Vector3(-147.7, NAN, 195.7), PI * 0.5],
	["r_thorn_edge", Vector3(-28.0, NAN, 30.0), -2.0 + PI],
	["r_thorn_deep", Vector3(-90.0, NAN, -40.0), 0.4 + PI],
	["r_thorn_in", Vector3(-75.0, NAN, 20.0), -2.4 + PI],
	["r_glade", Vector3(-30.0, NAN, 14.0), -2.0 + PI],
	["r_meadow", Vector3(8.0, NAN, 48.0), -2.2 + PI],
	["r_fen", Vector3(52.0, NAN, 12.0), 2.3 + PI],
	["r_road", Vector3(-30.0, NAN, 62.0), -1.57 + PI],
	# r22 additions: the heavy vistas
	["r_spawn_north", Vector3(0.0, NAN, 40.0), 0.0],                 # village to the rift and the Crowns
	["r_tavern_in", Vector3(11.4, -0.6, 27.0), -0.9],
	["r_rim", Vector3(0.0, 0.8, -10.0), 0.0],                       # the Crossing from its forecourt
	["r_spindle", Vector3(-8.3, 18.0, -43.5), 0.3],                 # on the viaduct by the Spindle
	["r_summit", Vector3(0.0, 27.9, -92.0), 0.0],
	["r_summit_back", Vector3(0.0, 28.2, -96.0), PI],               # the whole Realm from the dais
	["r_henge", Vector3(-62.0, 8.0, -12.0), 0.9],
	["r_barrows", Vector3(70.0, NAN, -34.0), 2.4],                  # toward the Ossuary door
	["r_chapel", Vector3(-58.0, NAN, 60.0), 1.2],
	# r34 layout: the new ground (docs/r34/layout.md); yaw = atan2(-dx, -dz) toward the place
	["r34_quarry", Vector3(-124.0, NAN, -80.0), 0.12],                # into the pit from its mouth
	["r34_holds", Vector3(-124.0, NAN, 26.0), 0.62],
	["r34_foundry", Vector3(126.0, NAN, -70.0), -0.27],
	["r34_moor", Vector3(128.0, NAN, 10.0), -0.37],                    # north over the moor to the tor
	["r34_orchard", Vector3(-100.0, NAN, 100.0), 2.45],
	["r34_necropolis", Vector3(-2.0, NAN, 100.0), -3.09],          # up the Waiting Field
	["r34_mere", Vector3(97.0, NAN, 92.0), -2.9],
	["r34_henge_raid", Vector3(-62.0, NAN, -14.0), 1.18],      # the raid floor from its rim
	# r37: the Outer Marches and the downs (far detail: the long views are the cost)
	["r37_river", Vector3(-188.0, NAN, 40.0), 1.57],           # west across the Sorrow
	["r37_lake", Vector3(190.0, NAN, 46.0), -0.42],             # north over Stillwater to the Spire's bluff
	["r37_well", Vector3(72.0, NAN, 176.0), 3.14],              # south to the sinkhole
	["r37_pans", Vector3(172.0, NAN, 138.0), -2.1],             # over the White Pans
	["r37_marches", Vector3(-160.0, NAN, 20.0), 1.57],          # the west Marches from the March Wall's line
	["r37_far_east", Vector3(150.0, NAN, 10.0), -1.57],         # the east Marches from the moor
	# the Far Reaches' towns (core/world/realm/reach_towns.gd): from inside each, across it; Lastlight from the road
	["t_reedholm", Vector3(-316.0, NAN, 300.0), -0.53],          # from the landing over the stilt houses
	["t_fallowmere", Vector3(-146.0, NAN, 300.0), 1.11],         # from the green to the tithe barn
	["t_lastlight", Vector3(314.0, NAN, 64.0), -0.92],           # from the street over the yard, the inn and the tower
	["t_ll_road", Vector3(266.0, NAN, 72.0), -1.27],             # the walls from the road
]
## The path: legs of [goal xz (y ignored), label]; a leg starting with "@" teleports there instead.
var route := [
	[Vector3(0, 0, 26.5), "@spawn"],
	[Vector3(-4, 0, 30), "west_way"], [Vector3(-20, 0, 24), "west_way"], [Vector3(-38, 0, 10), "glade"],
	[Vector3(-52, 0, -2), "thornwood"], [Vector3(-58, 0, -4), "henge foot"],
	[Vector3(26, 0, 22), "@east"],
	[Vector3(42, 0, 10), "east_way"], [Vector3(58, 0, -12), "east_way"], [Vector3(72, 0, -34), "fen"],
	[Vector3(78, 0, -42), "barrows"], [Vector3(62, 0, -56), "fen_descent"], [Vector3(44, 0, -62), "fen_descent"],
	[Vector3(54, 0, -59.5), "fen fire"],
	[Vector3(0, 0, 22), "@rim"],
	[Vector3(0, 0, 4), "rift_rim"], [Vector3(0, 0, -10.5), "forecourt"], [Vector3(0, 0, -15.5), "rim steps"],
	[Vector3(0, 0, -21), "tower 1"], [Vector3(-13, 0, -30), "viaduct"], [Vector3(-1.8, 0, -40), "fallen column"],
	[Vector3(-1.8, 0, -49.5), "spindle flight"],
]
var p: Player
var main: Node
var t := 0.0
var i := -1
var settle := 0.0
var acc := {}
var ft := PackedFloat32Array()        # frame times (s) of the current window
var vp_rid: RID
var phase := ""                      # "points" | "path" | "attrib" | "blame"
var do_points := true
var do_path := true
var attrib := false
var attrib_at: Array = []
var census := false
var load_ms := 0
var summary: Array = []              # [name, fps, low1, worst, draws, prims]
var t0_ms := 0
## Script cost per frame: a first-in-line node stamps the start of the process and physics passes,
## this node (last in line) the end; the difference is every script's _process/_physics_process.
var _first: Node
var _proc_us := 0
var _phys_us := 0
var _phys_begin := 0

var blame := false
var _held: Array[Resource] = []
var _blur: Node3D
var pan := 0.0                        ## deg/s peak (--pan)
var hitches := false
var hitch_ms := 20.0
var _prev_proc_us := 0
var groups := {}          # script/class -> nodes
var gkeys: Array = []
var gi := -1
var base_proc := 0.0
var results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0_ms = Time.get_ticks_msec()
	process_priority = 1 << 30
	process_physics_priority = 1 << 30
	_first = Node.new()
	_first.name = "PerfFirst"
	_first.process_mode = Node.PROCESS_MODE_ALWAYS
	_first.process_priority = -(1 << 30)
	_first.process_physics_priority = -(1 << 30)
	_first.set_script(_STAMP)
	_first.set_meta("tour", self)
	get_tree().root.add_child.call_deferred(_first)
	var args := OS.get_cmdline_user_args()
	blame = "--blame" in args
	do_points = not ("--path-only" in args)
	do_path = not ("--points-only" in args) and not blame
	points = realm_points
	_spindle_route()
	var preset := 1
	var fov := 90.0
	var stress := 0.0
	for a in args:
		if a.begins_with("--only="):
			var keep := a.trim_prefix("--only=").split(",")
			points = points.filter(func(e: Array) -> bool: return e[0] in keep)
		elif a.begins_with("--preset="):
			preset = int(a.trim_prefix("--preset="))
		elif a.begins_with("--fov="):
			fov = float(a.trim_prefix("--fov="))
		elif a.begins_with("--stress="):
			stress = float(a.trim_prefix("--stress="))
		elif a.begins_with("--pan="):
			pan = float(a.trim_prefix("--pan="))
		elif a.begins_with("--hitches"):
			hitches = true
			if a.contains("="):
				hitch_ms = float(a.get_slice("=", 1))
		elif a == "--census":
			census = true
			do_path = false
		elif a.begins_with("--reps="):
			a_reps = maxi(1, int(a.trim_prefix("--reps=")))
		elif a.begins_with("--attrib"):
			attrib = true
			do_path = false
			if a.contains("="):
				attrib_at = Array(a.get_slice("=", 1).split(","))
	# settings in memory only (Settings.apply() would write Luke's settings.cfg)
	Settings.set_preset_fields(preset)
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.fps_limit = 0
	Settings.render_scale = stress if stress > 0.0 else 0.0
	Settings.fov = fov
	print("PERF config preset %s fov %.0f window 1600x1000 vsync off uncapped%s" % [Settings.PRESET_NAMES[clampi(preset, 0, 2)], fov,
		" STRESS render scale %.2f (GPU-bound: fps compares GPU cost)" % stress if stress > 0.0 else ""])
	Travel._busy = true                                 # no save writes from this tool
	for a in args:
		# --shader=res://x.gdshader=/abs/variant.gdshader: this run uses the variant's code (in memory
		# only: A/B a shader change without touching the project file other runs read)
		if a.begins_with("--shader="):
			var parts := a.trim_prefix("--shader=").split("=")
			var sh := load(parts[0]) as Shader
			var code := FileAccess.get_file_as_string(parts[1])
			if sh and code != "":
				sh.code = code
				_held.append(sh)                    # held: a dropped Resource leaves the cache
				print("PERF shader variant %s <- %s" % [parts[0], parts[1].get_file()])
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


## --moon=k:v,...  DirectionalLight3D properties on every moon; --rs=atlas:N,filter:N  RenderingServer
## shadow settings. Applied once the Realm is built (after the zone's own LightPolicy pass): A/B a
## shadow setup without touching the project.
func _tune_moon() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--moon="):
			for kv in a.trim_prefix("--moon=").split(","):
				for d in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
					d.set(kv.get_slice(":", 0), float(kv.get_slice(":", 1)))
			print("PERF moon ", a)
		elif a.begins_with("--rs="):
			for kv in a.trim_prefix("--rs=").split(","):
				var v := int(kv.get_slice(":", 1))
				match kv.get_slice(":", 0):
					"atlas":
						RenderingServer.directional_shadow_atlas_set_size(v, true)
					"filter":
						RenderingServer.directional_soft_shadow_filter_set_quality(v as RenderingServer.ShadowQuality)
			print("PERF rs ", a)


const _STAMP_SRC := """extends Node
var tour: Node
func _ready() -> void:
	tour = get_meta("tour")
func _process(_d: float) -> void:
	tour.set("_proc_begin", Time.get_ticks_usec())
func _physics_process(_d: float) -> void:
	tour.set("_phys_begin", Time.get_ticks_usec())
"""
static var _STAMP: GDScript = _make_stamp()
var _proc_begin := 0


static func _make_stamp() -> GDScript:
	var g := GDScript.new()
	g.source_code = _STAMP_SRC
	g.reload()
	return g


func _physics_process(_d: float) -> void:
	if _phys_begin > 0:
		_phys_us += Time.get_ticks_usec() - _phys_begin


## Enemies are switched off and hidden, not freed: a freed camp member respawns every 10 s
## (EnemySpawner.RESPAWN) and each spawn builds its creature meshes, which put 40-140 ms frames
## into every window that the views themselves do not cause. (--with-enemies keeps them.)
func _quiet_enemies() -> void:
	if "--with-enemies" in OS.get_cmdline_user_args():
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):      # every frame: the spawner wakes them
		if n is Node3D:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(n as Node3D).visible = false


## --mute=a.gd,b.gd: switch off _process/_physics_process of every node running these scripts (find
## which script makes a one-off spike by elimination)
var _muted := false


func _mute_scripts() -> void:
	if _muted:
		return
	_muted = true
	var names: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mute="):
			names = a.trim_prefix("--mute=").split(",")
	if names.is_empty():
		return
	var n := 0
	for node in get_tree().root.find_children("*", "", true, false):
		var sc: Script = node.get_script()
		if sc and sc.resource_path.get_file() in names:
			node.set_process(false)
			node.set_physics_process(false)
			n += 1
	print("PERF muted %d nodes running %s" % [n, ",".join(names)])


## HUD calibration: 90 frames at 4x the pixels (scale 2.0) right before measuring; perf_hud.py finds
## that block of heavy frames in the HUD log and from it the offset between the HUD's frame counter
## and Engine.get_frames_drawn().
var _cal := -1
var _cal_scale := 1.0


func _cal_step() -> bool:
	if _cal == -2:
		return false
	var vp := get_viewport()
	if _cal == -1:
		_cal_scale = vp.scaling_3d_scale
		vp.scaling_3d_scale = 2.0
		_cal = Engine.get_frames_drawn()
		return true
	if Engine.get_frames_drawn() - _cal < 90:
		return true
	vp.scaling_3d_scale = _cal_scale
	print("PERFCAL %d %d" % [_cal + 1, Engine.get_frames_drawn()])
	_cal = -2
	settle = 1.0
	return false


func _spindle_route() -> void:
	var spin := Vector2(-8.3, -50.0)
	for k in range(1, 25):
		var th := -TAU * float(k) / 24.0
		var q := spin + Vector2(cos(th), sin(th)) * 6.5
		route.append([Vector3(q.x, 0, q.y), "spindle"])
	route.append_array([[Vector3(-1.8, 0, -56), "flights"], [Vector3(-1.8, 0, -61.5), "flights"],
		[Vector3(0, 0, -66.5), "ward landing"], [Vector3(0, 0, -71.4), "summit stairs"],
		[Vector3(0, 0, -77.5), "summit stairs"], [Vector3(-2.8, 0, -79.5), "summit"], [Vector3(-3.6, 0, -83.5), "summit"],
		[Vector3(-2.6, 0, -87.0), "summit"], [Vector3(0, 0, -89.0), "summit"], [Vector3(0, 0, -92.0), "dais"],
		[Vector3(0, 0, -103.9), "dais"]])


func _process(d: float) -> void:
	t += d
	var script_us := Time.get_ticks_usec() - _proc_begin if _proc_begin > 0 else 0
	_proc_us = script_us + _phys_us
	_phys_us = 0
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
		return
	if not main.has_meta("realm_done"):
		return
	if load_ms == 0 and main.get_node_or_null("LoadingScreen") != null:
		return                                   # --loading: measure from the moment the cover lifts
	if load_ms == 0:
		load_ms = Time.get_ticks_msec() - t0_ms
		t = 0.0
		print("PERF load %d ms to realm_done (incl. scene instance)" % load_ms)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if "--luke" in OS.get_cmdline_user_args():
			# Luke's pacing: vsync on, 144 cap (frame times then show what he sees: a missed
			# vsync is a long frame, not a faster one)
			Engine.max_fps = 144
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			get_window().size = Vector2i(1920, 1080)       # his window (3D capped at 960 rows)
		else:
			get_window().size = Vector2i(1600, 1000)       # (was unconditional: --luke ran at 1600x1000)
		_tune_moon()
		# exact setups: --screen=1 --fullscreen --vsync=1 --cap=120 (cap -1 = Settings' own pacing)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--screen="):
				DisplayServer.window_set_current_screen(int(a.trim_prefix("--screen=")))
			elif a == "--fullscreen":
				get_window().mode = Window.MODE_FULLSCREEN
			elif a.begins_with("--vsync="):
				var vm := int(a.trim_prefix("--vsync="))  # 0 off, 1 on, 2 mailbox, 3 adaptive
				Settings.vsync = vm != 0                 # in memory: Zone re-applies pacing on resize
				DisplayServer.window_set_vsync_mode(vm)
				print("PERF vsync mode asked %d got %d" % [vm, DisplayServer.window_get_vsync_mode()])
			elif a.begins_with("--cap="):
				Settings.fps_limit = int(a.trim_prefix("--cap="))   # -1 = match display
				Engine.max_fps = Settings.effective_max_fps()
			elif a == "--native":
				Settings.native_output = true
		if "--fullscreen" in OS.get_cmdline_user_args():
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				var w := get_window()
				print("PERF window now screen %d size %s output rows %d (content mode %d) max_fps %d" % [DisplayServer.window_get_current_screen(), w.size, roundi(get_viewport().get_visible_rect().size.y) if w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT else w.size.y, w.content_scale_mode, Engine.max_fps]))
			print("PERF window screen %d size %s hz %.0f vsync %d max_fps %d" % [DisplayServer.window_get_current_screen(), DisplayServer.window_get_size(), DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen()), DisplayServer.window_get_vsync_mode(), Engine.max_fps])
		vp_rid = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		for w in main.find_children("*", "", true, false):
			if w is WardSeal:
				(w as WardSeal).release()
	if t < (0.0 if "--early" in OS.get_cmdline_user_args() else 6.0):   # streaming, lava, first shader compiles
		return
	_mute_scripts()
	_quiet_enemies()
	if _cal_step():
		return
	if phase == "":
		if blame:
			phase = "blame"
			points = [points[0]]
			_next_point()
		elif do_points or attrib:
			phase = "points"
			_next_point()
		else:
			phase = "path"
			_start_path()
		return
	match phase:
		"blame":
			if gi >= -1:
				_blame_step(d)
		"points":
			_point_step(d)
		"path":
			_path_step(d)
		"attrib":
			_attrib_step(d)
		"census":
			_census_step()


# --- static views ----------------------------------------------------------------------------------

func _point_step(d: float) -> void:
	_hold()
	_pan()
	settle -= d
	if settle > 0.0:
		return
	_sample(d)
	if hitches and d * 1000.0 > hitch_ms:
		print("PERF hitch %-14s %.1f ms at %.2f s draws %d prims %d | scripts %.2f ms (prev frame %.2f) render-cpu %.2f physics %.2f" % [points[i][0], d * 1000.0, float(acc.time),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			_proc_us / 1000.0, _prev_proc_us / 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_prev_proc_us = _proc_us
	if float(acc.time) >= SECONDS:
		var r := _report("PERF %-14s" % points[i][0])
		summary.append([points[i][0]] + r)
		if census:
			phase = "census"
			_census_begin()
			return
		_next_point()


func _next_point() -> void:
	i += 1
	acc = {}
	ft = PackedFloat32Array()
	if i >= points.size():
		if attrib:
			_start_attrib()
		elif do_path:
			_start_path()
		else:
			_finish()
		return
	settle = SETTLE
	_hold()
	p.set_view(float(points[i][2]), -0.08)


## --pan: swing the view +-10 deg about the point's yaw, peak speed `pan` deg/s.
func _pan() -> void:
	if pan <= 0.0 or i < 0 or i >= points.size():
		return
	var amp := deg_to_rad(10.0)
	p.set_view(float(points[i][2]) + amp * sin(t * pan / 10.0), -0.08)


func _hold() -> void:
	if i < 0 or i >= points.size():
		return
	var at: Vector3 = points[i][1]
	if is_nan(at.y):
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
		points[i][1] = at
	# let the wanderer stand once he is there: re-placing him every frame dropped him 0.15 m and put
	# him back, a bobbing camera that kept motion blur (and anything else that reacts) running
	if p.global_position.distance_to(at) > 0.3 or (phase == "points" and settle > SETTLE - 0.25):
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _sample(d: float) -> void:
	if not acc.has("f0"):
		acc.f0 = Engine.get_frames_drawn()
	acc.f1 = Engine.get_frames_drawn()
	acc.frames = int(acc.get("frames", 0)) + 1
	acc.time = float(acc.get("time", 0.0)) + d
	ft.append(d)
	acc.cpu = float(acc.get("cpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) \
		+ RenderingServer.get_frame_setup_time_cpu()
	acc.draws = int(acc.get("draws", 0)) + int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	acc.prims = int(acc.get("prims", 0)) + int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	acc.max_draws = maxi(int(acc.get("max_draws", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	acc.max_prims = maxi(int(acc.get("max_prims", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	acc.objs = int(acc.get("objs", 0)) + int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	acc.sh_draws = int(acc.get("sh_draws", 0)) + RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	acc.sh_prims = int(acc.get("sh_prims", 0)) + RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	acc.proc = float(acc.get("proc", 0.0)) + float(_proc_us) / 1e6
	acc.phys = float(acc.get("phys", 0.0)) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	if _blur == null:
		var cam := get_viewport().get_camera_3d()
		_blur = cam.get_node_or_null("MotionBlur") as Node3D if cam else null
	if _blur and _blur.visible:
		acc.blur = int(acc.get("blur", 0)) + 1


## Frame-time stats of `ft`: [fps, 1% low fps, p99 ms, worst ms, stddev ms, n>20ms, n>33ms]
static func frame_stats(times: PackedFloat32Array) -> Array:
	var n := times.size()
	if n == 0:
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0, 0]
	var s := times.duplicate()
	s.sort()
	var total := 0.0
	var over20 := 0
	var over33 := 0
	for x in s:
		total += x
		if x > 0.020:
			over20 += 1
		if x > 0.0333:
			over33 += 1
	var mean := total / n
	var var_sum := 0.0
	for x in s:
		var_sum += (x - mean) * (x - mean)
	var k := maxi(1, ceili(n * 0.01))
	var worst_sum := 0.0
	for j in k:
		worst_sum += s[n - 1 - j]
	return [n / total, k / worst_sum, s[mini(n - 1, int(n * 0.99))] * 1000.0, s[n - 1] * 1000.0,
		sqrt(var_sum / n) * 1000.0, over20, over33]


## Prints one line for the window in acc/ft; returns [fps, 1% low, worst ms, draws, prims].
## Also "PERFWIN <label> <first frame> <last frame>" so a Metal HUD log (MTL_HUD_ENABLED=1
## MTL_HUD_LOG_ENABLED=1, per-frame GPU time on stderr) can be matched to the window: zz/perf_hud.py.
func _report(label: String) -> Array:
	if acc.has("f0"):
		print("PERFWIN %s %d %d" % [label.get_slice(" ", 1) if label.get_slice(" ", 1) != "" else label, int(acc.f0), int(acc.f1)])
	var n := float(acc.frames)
	var st := frame_stats(ft)
	var frame_ms := 1000.0 / float(st[0])
	var proc := float(acc.proc) / n * 1000.0
	var phys := float(acc.phys) / n * 1000.0
	var cpu := float(acc.cpu) / n
	print("%s fps %6.1f  1%%low %6.1f  p99 %5.1f  worst %5.1f ms  sd %4.2f  >33ms %d  | scripts %5.2f physics(max/s) %5.2f render-cpu %5.2f rest(gpu) %5.2f ms | draws %4d (max %4d, shadow %d) objs %5d prims %7d (max %7d, shadow %d) | blur %d%%" % [
		label, st[0], st[1], st[2], st[3], st[4], st[6], proc, phys, cpu, maxf(0.0, frame_ms - proc - cpu),
		int(float(acc.draws) / n), int(acc.max_draws), int(float(acc.get("sh_draws", 0)) / n), int(float(acc.objs) / n),
		int(float(acc.prims) / n), int(acc.max_prims), int(float(acc.get("sh_prims", 0)) / n), roundi(100.0 * float(acc.get("blur", 0)) / n)])
	return [st[0], st[1], st[3], int(float(acc.draws) / n), int(float(acc.prims) / n), int(acc.max_draws), int(acc.max_prims), st[6]]


# --- the path ----------------------------------------------------------------------------------------

var leg := 0
var leg_t := 0.0
var leg_label := ""
var path_all := PackedFloat32Array()
var path_acc := {}
var yaw := 0.0


func _start_path() -> void:
	phase = "path"
	leg = 0
	acc = {}
	ft = PackedFloat32Array()
	_begin_leg()


func _begin_leg() -> void:
	leg_t = 0.0
	if leg >= route.size():
		_end_section()
		var keep_acc := acc
		acc = path_acc
		ft = path_all
		var r := _report("PATH %-14s" % "TOTAL")
		summary.append(["path"] + r)
		acc = keep_acc
		_finish()
		return
	var lbl: String = route[leg][1]
	if lbl.begins_with("@"):
		_end_section()
		var at: Vector3 = route[leg][0]
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.4
		p.global_position = at
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.debug_drive(Vector3.ZERO)
		settle = SETTLE
		leg_label = lbl.trim_prefix("@")
		leg += 1
		_begin_leg()
		return


func _end_section() -> void:
	if ft.size() > 10:
		_report("PATH %-14s" % leg_label)
		print("PATH %-14s peak prims %d at %s" % [leg_label, int(acc.get("peak", 0)), acc.get("peak_at", "-")])
	acc = {}
	ft = PackedFloat32Array()


func _path_step(d: float) -> void:
	if leg >= route.size():
		return
	settle -= d
	var goal: Vector3 = route[leg][0]
	var dv := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	if dv.length() < 0.8:
		leg += 1
		_begin_leg()
		return
	leg_t += d
	if leg_t > 14.0 or p.global_position.y < -14.0:
		print("PATH stuck on leg %d (%s) at %s, skipping" % [leg, route[leg][1], p.global_position.snapped(Vector3.ONE * 0.1)])
		leg += 1
		_begin_leg()
		return
	var dir := Vector3(dv.x, 0.0, dv.y).normalized()
	p.debug_drive(dir, true)
	var want := atan2(-dir.x, -dir.z)
	yaw = want if settle > SETTLE - 0.05 else lerp_angle(yaw, want, minf(1.0, d * 4.0))
	p.set_view(yaw, -0.06)
	if settle > 0.0:
		return
	_sample(d)
	for k in ["frames", "time", "cpu", "draws", "prims", "objs", "proc", "phys", "sh_draws", "sh_prims"]:
		path_acc[k] = path_acc.get(k, 0) + acc[k] - (acc.get("_last_" + k, 0))
		acc["_last_" + k] = acc[k]
	var pr := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if pr > int(acc.get("peak", 0)):
		acc.peak = pr
		acc.peak_at = "%s yaw %.2f" % [p.global_position.snapped(Vector3.ONE * 0.1), yaw]
	path_acc.max_draws = maxi(int(path_acc.get("max_draws", 0)), int(acc.max_draws))
	path_acc.max_prims = maxi(int(path_acc.get("max_prims", 0)), int(acc.max_prims))
	path_all.append(d)
	if d > (hitch_ms * 0.001 if hitches else 0.0333):
		print("PATH hitch %.1f ms at %s (%s) draws %d prims %d" % [d * 1000.0, p.global_position.snapped(Vector3.ONE * 0.1),
			route[leg][1], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


# --- feature attribution ---------------------------------------------------------------------------

const ATTRIB_WIN := 2.0
var feats: Array = []
var fi := 0
var a_phase := 0
var a_rep := 0
var a_on := 0.0
var a_off := 0.0
var a_reps := 2                      ## on/off pairs per feature (--reps=N)
var _a_pairs: Array[float] = []
var _a_last_on := 0.0
var a_points: Array = []
var a_pi := -1


func _start_attrib() -> void:
	phase = "attrib"
	if attrib_at.is_empty():
		var sorted := summary.duplicate()
		sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		for e: Array in sorted.slice(0, 2):
			attrib_at.append(e[0])
	for e: Array in realm_points:
		if e[0] in attrib_at:
			a_points.append(e)
	points = a_points
	a_pi = -1
	_attrib_next_point()


func _attrib_next_point() -> void:
	a_pi += 1
	if a_pi >= a_points.size():
		_finish()
		return
	i = a_pi
	_hold()
	p.set_view(float(points[i][2]), -0.08)
	feats = _features()
	for a in OS.get_cmdline_user_args():             # --feat=moon,shadow: only features whose name has one of these
		if a.begins_with("--feat="):
			var want := a.trim_prefix("--feat=").split(",")
			feats = feats.filter(func(f: Array) -> bool:
				for w in want:
					if String(f[0]).contains(w):
						return true
				return false)
	fi = 0
	a_phase = 0
	a_rep = 0
	a_on = 0.0
	a_off = 0.0
	settle = SETTLE
	acc = {}
	ft = PackedFloat32Array()
	print("ATTRIB at %s" % points[i][0])


func _features() -> Array:
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var moon := main.get_node_or_null("Moon") as DirectionalLight3D
	var out: Array = []
	# only what is on now (restoring sets it back as it was)
	for prop: String in ["volumetric_fog_enabled", "ssao_enabled", "glow_enabled", "ssr_enabled", "sdfgi_enabled"]:
		if bool(env.get(prop)):
			out.append([prop.trim_suffix("_enabled"), func(on: bool) -> void: env.set(prop, on)])
	if moon and moon.shadow_enabled:
		out.append(["moon shadow", func(on: bool) -> void: moon.shadow_enabled = on])
		var ang := moon.light_angular_distance
		if ang > 0.0:
			out.append(["moon soft shadow (angular)", func(on: bool) -> void: moon.light_angular_distance = ang if on else 0.0])
		# r29 (LightPolicy._moon) against the r28 setup it replaced: 1024 atlas, very low filter,
		# 30 m, near split 0.1, bias 0.035 / 1.8
		var r29 := [moon.directional_shadow_max_distance, moon.directional_shadow_split_1, moon.shadow_bias, moon.shadow_normal_bias]
		var r29_atlas: int = LightPolicy.MOON_ATLAS[clampi(Settings.shadow_quality, 0, 2)]
		var r29_filter: int = LightPolicy.MOON_FILTER[clampi(Settings.shadow_quality, 0, 2)]
		out.append(["moon r29 setup (vs r28)", func(on: bool) -> void:
			RenderingServer.directional_shadow_atlas_set_size(r29_atlas if on else 1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality((r29_filter if on else 1) as RenderingServer.ShadowQuality)
			moon.directional_shadow_max_distance = r29[0] if on else 30.0
			moon.directional_shadow_split_1 = r29[1] if on else 0.1
			moon.shadow_bias = r29[2] if on else 0.035
			moon.shadow_normal_bias = r29[3] if on else 1.8])
		out.append(["moon atlas %d (vs 1024)" % r29_atlas, func(on: bool) -> void:
			RenderingServer.directional_shadow_atlas_set_size(r29_atlas if on else 1024, true)])
		out.append(["moon atlas %d (vs 2048)" % r29_atlas, func(on: bool) -> void:
			RenderingServer.directional_shadow_atlas_set_size(r29_atlas if on else 2048, true)])
		out.append(["moon filter %d (vs 1)" % r29_filter, func(on: bool) -> void:
			RenderingServer.directional_soft_shadow_filter_set_quality((r29_filter if on else 1) as RenderingServer.ShadowQuality)])
		var bl := moon.directional_shadow_blend_splits
		if bl:
			out.append(["moon blend splits", func(on: bool) -> void: moon.directional_shadow_blend_splits = on])
		var casters: Array = main.find_children("*", "GeometryInstance3D", true, false).filter(func(g: Node) -> bool:
			return (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (g as Node3D).is_visible_in_tree())
		var flora_c: Array = casters.filter(func(g: Node) -> bool: return String(g.name).begins_with("Flora_") and (String(g.name).ends_with("_c") or String(g.name).ends_with("_fc")))
		out.append(["shadow: flora cards (%d)" % flora_c.size(), func(on: bool) -> void:
			for g in flora_c:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
		var flora_s: Array = casters.filter(func(g: Node) -> bool: return String(g.name).begins_with("Flora_") and not g in flora_c)
		out.append(["shadow: flora solids (%d)" % flora_s.size(), func(on: bool) -> void:
			for g in flora_s:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
		var other: Array = casters.filter(func(g: Node) -> bool: return not String(g.name).begins_with("Flora_") and not String(g.name).begins_with("Terrain") and not main.get_node("Player").is_ancestor_of(g))
		var keep_cs := other.map(func(g: Node) -> int: return int((g as GeometryInstance3D).cast_shadow))
		out.append(["shadow: other casters (%d)" % other.size(), func(on: bool) -> void:
			for k in other.size():
				if is_instance_valid(other[k]):
					(other[k] as GeometryInstance3D).cast_shadow = keep_cs[k] if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
	var shown := func(n: Node) -> bool: return (n as Node3D).is_visible_in_tree()
	var omnis := (main.find_children("*", "OmniLight3D", true, false) + main.find_children("*", "SpotLight3D", true, false)).filter(shown)
	out.append(["point/spot lights (%d)" % omnis.size(), func(on: bool) -> void:
		for l in omnis:
			if is_instance_valid(l):
				(l as Light3D).visible = on])
	for grp: Array in [["lights: lava glows", "Zone/Lava"], ["lights: window rig", "WindowRig"], ["lights: player", "Player"]]:
		var under_g := main.get_node_or_null(String(grp[1]))
		if under_g:
			var ls: Array = under_g.find_children("*", "Light3D", true, false).filter(shown)
			if not ls.is_empty():
				out.append(["%s (%d)" % [grp[0], ls.size()], func(on: bool) -> void:
					for l in ls:
						(l as Light3D).visible = on])
	var grade := main.get_node_or_null("Grade") as CanvasLayer
	if grade:
		out.append(["grade", func(on: bool) -> void: grade.visible = on])
	var blur: Array = main.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and String((n.get_script() as Script).resource_path).ends_with("motion_blur.gd"))
	if not blur.is_empty():
		# by strength: the blur hides itself while the camera is at rest
		var mb_s: float = blur[0].get("strength")
		out.append(["motion blur", func(on: bool) -> void: blur[0].set("strength", mb_s if on else 0.0)])
	var flora := main.get_node_or_null("RealmFlora") as Node3D
	if flora:
		var cards: Array = flora.find_children("Flora_*_c", "", true, false) + flora.find_children("Flora_*_fc", "", true, false)
		out.append(["flora (all)", func(on: bool) -> void: flora.visible = on])
		out.append(["flora leaf cards", func(on: bool) -> void:
			for c in cards:
				(c as Node3D).visible = on])
	var parts := main.find_children("*", "GPUParticles3D", true, false).filter(shown)
	out.append(["particles (%d)" % parts.size(), func(on: bool) -> void:
		for q in parts:
			if is_instance_valid(q):
				(q as Node3D).visible = on])
	var fogv := main.find_children("*", "FogVolume", true, false).filter(shown)
	out.append(["fog volumes (%d)" % fogv.size(), func(on: bool) -> void:
		for q in fogv:
			if is_instance_valid(q):
				(q as Node3D).visible = on])
	var bg := env.background_mode
	out.append(["sky background", func(on: bool) -> void: env.background_mode = bg if on else Environment.BG_COLOR])
	for gname: String in ["Zone/Terrain", "RealmLore", "RealmRift", "Area_ossuary", "HollowLantern", "SummitAltar", "Player",
			"Wildlife", "Village", "Secrets", "Encounters"]:
		var g := main.get_node_or_null(gname) as Node3D
		if g and g.visible:
			out.append([gname, func(on: bool) -> void: g.visible = on])
	var ring: Array = main.get_node("Zone").get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("TerrainRing") and (n as Node3D).visible) if main.has_node("Zone") else []
	if not ring.is_empty():
		out.append(["terrain ring (%d)" % ring.size(), func(on: bool) -> void:
			for r in ring:
				(r as Node3D).visible = on])
	var under: Array = []
	if flora:
		under = flora.find_children("Flora_*", "MultiMeshInstance3D", true, false).filter(func(n: Node) -> bool: return String(n.get_parent().name).begins_with("Chunk_"))
		out.append(["flora undergrowth", func(on: bool) -> void:
			for u in under:
				(u as Node3D).visible = on])
		# what the undergrowth's cost scales with: its far end or its density
		var ends := under.map(func(u: Node) -> float: return (u as GeometryInstance3D).visibility_range_end)
		out.append(["undergrowth range x0.65", func(on: bool) -> void:
			for k in under.size():
				(under[k] as GeometryInstance3D).visibility_range_end = ends[k] if on else ends[k] * 0.65])
		out.append(["undergrowth density 60%", func(on: bool) -> void:
			for u in under:
				var mm := (u as MultiMeshInstance3D).multimesh
				mm.visible_instance_count = -1 if on else int(mm.instance_count * 0.6)])
	var vp := get_viewport()
	var lt := vp.mesh_lod_threshold
	out.append(["mesh lod threshold x2", func(on: bool) -> void: vp.mesh_lod_threshold = lt if on else lt * 2.0])
	var sc := vp.scaling_3d_scale
	out.append(["render scale 100->50%", func(on: bool) -> void: vp.scaling_3d_scale = sc if on else sc * 0.5])
	if sc < 0.999:
		# what the 3D upscale costs (only below 1:1, e.g. the 960-row cap at 1080): the current mode
		# against bilinear, and rendering the output's own rows instead
		var sm := vp.scaling_3d_mode
		out.append(["upscale mode %d (vs bilinear)" % sm, func(on: bool) -> void:
			vp.scaling_3d_mode = sm if on else Viewport.SCALING_3D_MODE_BILINEAR])
		out.append(["upscale fsr (vs bilinear)", func(on: bool) -> void:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if on else Viewport.SCALING_3D_MODE_BILINEAR])
		out.append(["native rows (vs %.3f)" % sc, func(on: bool) -> void: vp.scaling_3d_scale = 1.0 if on else sc])
	return out


func _attrib_step(d: float) -> void:
	_hold()
	_pan()
	settle -= d
	if settle > 0.0:
		return
	if not acc.has("f0"):
		acc.f0 = Engine.get_frames_drawn()
	acc.frames = int(acc.get("frames", 0)) + 1
	acc.time = float(acc.get("time", 0.0)) + d
	if float(acc.time) < ATTRIB_WIN:
		return
	var ms := float(acc.time) / float(acc.frames) * 1000.0
	var f: Array = feats[fi]
	print("PERFWIN %s|%s|%s %d %d" % [points[i][0], String(f[0]).replace(" ", "_"), "on" if a_phase % 2 == 0 else "off", int(acc.f0), Engine.get_frames_drawn()])
	acc = {}
	settle = 0.35
	# phases: 0 measure on, 1 measure off, repeated (on/off/on/off, --reps=N pairs, default 2) so
	# drift cancels; with other GPU work on the machine the median pair says more than the mean
	if a_phase % 2 == 0:
		a_on += ms
		_a_last_on = ms
		(f[1] as Callable).call(false)
	else:
		a_off += ms
		_a_pairs.append(_a_last_on - ms)
		(f[1] as Callable).call(true)
	a_phase += 1
	if a_phase < 2 * a_reps:
		return
	_a_pairs.sort()
	print("ATTRIB %-26s on %6.2f ms  off %6.2f ms  cost %+6.2f ms  (median pair %+.2f of %d)" % [f[0], a_on / float(a_reps), a_off / float(a_reps),
		(a_on - a_off) / float(a_reps), _a_pairs[_a_pairs.size() / 2], _a_pairs.size()])
	_a_pairs.clear()
	fi += 1
	a_phase = 0
	a_on = 0.0
	a_off = 0.0
	if fi >= feats.size():
		_attrib_next_point()


# --- census: what each part of the world adds to this view (draws and primitives are exact) ------

var c_groups: Array = []             # [label, Array of nodes]
var c_k := 0
var c_wait := 0
var c_base := Vector4i.ZERO
var c_rows: Array = []


func _counts() -> Vector4i:
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var sh := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	return Vector4i(RenderingServer.viewport_get_render_info(vp_rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, sh, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, sh, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))


func _census_begin() -> void:
	c_groups.clear()
	var flora := main.get_node_or_null("RealmFlora")
	for c in main.get_children():
		if c is Node3D and (c as Node3D).visible and c != flora and not c is Player:
			c_groups.append([String(c.name), [c]])
	var player := main.get_node_or_null("Player")
	if player:
		c_groups.append(["Player", [player]])
	if flora:
		var by := {}
		for mmi in flora.find_children("Flora_*", "MultiMeshInstance3D", true, false):
			var nm := String(mmi.name).trim_prefix("Flora_")
			var tag := nm.get_slice("_", nm.get_slice_count("_") - 1)
			var sp := nm.get_slice("_", 0)
			var key := "flora " + sp + " " + tag
			if not by.has(key):
				by[key] = []
			(by[key] as Array).append(mmi)
		for k: String in by:
			c_groups.append([k, by[k]])
	c_k = -1
	c_wait = 4
	c_rows.clear()


func _census_step() -> void:
	_hold()
	c_wait -= 1
	if c_wait > 0:
		return
	if c_k == -1:
		c_base = _counts()
	else:
		var now := _counts()
		var dlt := c_base - now
		c_rows.append([c_groups[c_k][0], dlt])
		for n in c_groups[c_k][1]:
			(n as Node3D).visible = true
	c_k += 1
	if c_k >= c_groups.size():
		c_rows.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector4i).y + (a[1] as Vector4i).w > (b[1] as Vector4i).y + (b[1] as Vector4i).w)
		print("CENSUS %s total draws %d prims %d (shadow draws %d prims %d)" % [points[i][0], c_base.x, c_base.y, c_base.z, c_base.w])
		for r: Array in c_rows:
			var v: Vector4i = r[1]
			if v.x != 0 or v.y != 0 or v.z != 0 or v.w != 0:
				print("CENSUS   %-30s draws %4d prims %8d | shadow draws %4d prims %8d" % [r[0], v.x, v.y, v.z, v.w])
		var cam := get_viewport().get_camera_3d()
		var rows: Array = []
		for l in main.find_children("*", "Light3D", true, false):
			var lt := l as Light3D
			if lt is DirectionalLight3D or not lt.is_visible_in_tree():
				continue
			var rng := (lt as OmniLight3D).omni_range if lt is OmniLight3D else (lt as SpotLight3D).spot_range
			var dist := cam.global_position.distance_to(lt.global_position)
			var faded := lt.distance_fade_enabled and dist > lt.distance_fade_begin + lt.distance_fade_length
			if dist - rng > 82.0 or faded:
				continue
			rows.append([dist, "CENSUS   light %-22s %-6s range %5.1f at %5.1f m  fade %s  shadow %s  energy %.2f  vfog %.2f  %s" % [
				str(lt.get_meta(&"light_class", "?")), "omni" if lt is OmniLight3D else "spot", rng, dist,
				("%.0f" % lt.distance_fade_begin) if lt.distance_fade_enabled else "off", lt.shadow_enabled, lt.light_energy,
				lt.light_volumetric_fog_energy, str(main.get_path_to(lt)).substr(0, 60)]])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		print("CENSUS %s lights not faded out: %d" % [points[i][0], rows.size()])
		for r: Array in rows:
			print(r[1])
		phase = "points"
		_next_point()
		return
	for n in c_groups[c_k][1]:
		(n as Node3D).visible = false
	c_wait = 4


func _finish() -> void:
	if not summary.is_empty():
		var worst_fps := INF
		var worst_low := INF
		var worst_frame := 0.0
		var max_draws := 0
		var max_prims := 0
		var over33 := 0
		var at := ""
		for r: Array in summary:
			if float(r[1]) < worst_fps:
				worst_fps = r[1]
				at = r[0]
			worst_low = minf(worst_low, r[2])
			worst_frame = maxf(worst_frame, r[3])
			max_draws = maxi(max_draws, r[6])
			max_prims = maxi(max_prims, r[7])
			over33 += int(r[8])
		print("PERF summary: lowest fps %.1f (%s), lowest 1%% low %.1f, worst frame %.1f ms, frames >33ms %d, max draws %d, max prims %d, load %d ms" % [
			worst_fps, at, worst_low, worst_frame, over33, max_draws, max_prims, load_ms])
	print("PERF done (nodes %d, static mem %.0f MB, video mem %.0f MB)" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	OS.kill(OS.get_process_id())


## --blame: at the first point, for each script in turn measure the frame's process+physics time
## with its nodes switched off and then back on (paired windows, so drift cancels), and report
## what switching it off saves.
var _phase := 0          # 0 = measuring "off", 1 = measuring "on"
var _off_ms := 0.0


func _blame_step(d: float) -> void:
	_hold()
	settle -= d
	if settle > 0.0:
		return
	acc.frames = int(acc.get("frames", 0)) + 1
	acc.time = float(acc.get("time", 0.0)) + d
	# the stamped script time (first-in-line to last-in-line), not TIME_PROCESS: on Metal that
	# monitor includes the wait for the GPU and swamps every script
	acc.proc = float(acc.get("proc", 0.0)) + float(_proc_us) / 1e6
	if float(acc.time) < 1.5:
		return
	var ms := float(acc.proc) / float(acc.frames) * 1000.0
	acc = {}
	settle = 0.3
	if gi == -1:
		base_proc = ms
		for n in get_tree().root.find_children("*", "", true, false):
			if n == self or not (n.is_processing() or n.is_physics_processing()):
				continue
			var sc: Script = n.get_script()
			var key := sc.resource_path.get_file() if sc else n.get_class()
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(n)
		gkeys = groups.keys()
		print("BLAME base scripts (process+physics) %.3f ms, %d processing groups" % [ms, gkeys.size()])
		gi = 0
		_set_group(gi, false)
		_phase = 0
		return
	if _phase == 0:
		_off_ms = ms
		_set_group(gi, true)
		_phase = 1
		return
	results.append([ms - _off_ms, gkeys[gi], (groups[gkeys[gi]] as Array).size()])
	gi += 1
	if gi >= gkeys.size():
		results.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for r: Array in results:
			print("BLAME %6.3f ms  %-34s x%d" % [r[0], r[1], r[2]])
		OS.kill(OS.get_process_id())
		return
	_set_group(gi, false)
	_phase = 0


func _set_group(g: int, on: bool) -> void:
	for n in groups[gkeys[g]]:
		if not is_instance_valid(n):
			continue
		if not on:
			n.set_meta("_bp", n.is_processing()); n.set_meta("_bpp", n.is_physics_processing())
			n.set_process(false); n.set_physics_process(false)
		else:
			n.set_process(n.get_meta("_bp", true)); n.set_physics_process(n.get_meta("_bpp", false))

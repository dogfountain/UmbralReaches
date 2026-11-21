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
##   --only=a,b                      only these points; --seconds=N: stand N s at each (default 4)
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
##                                   --census-split=A,B: these top-level nodes counted child by child
##   --casters                       per view, the shadow casters within 40 m by size, and the heaviest
##   --pan=40                        points (and attrib) swing the view +-10 deg at up to 40 deg/s, like a
##                                   player looking about: motion blur and streaming work as in play
##   --luke                          Luke's pacing and window: vsync on, 144 fps cap, 1920x1080
##   --moon=k:v,...  --rs=atlas:N,filter:N   moon / shadow-atlas overrides once the Realm is built (A/B)
##   --hitches[=ms]                  points: print every frame over 20 ms (or ms): time into the window, draws
##                                   (path: frames over ms, default 33); and from the load on, "HITCH" records of the
##                                   slow frame's last four frames: nodes added/freed (named), resources, objects, memory,
##                                   pipelines compiled, scripts, and the deferred flush / pre-draw / draw split
##                                   --hitches-under: the loading screen's frames too
##   --probe[-split=A,B]             (with --hitches) a frame whose scripts run over 8 ms names the subtrees that took
##                                   the time: every processing node's priority is renumbered by subtree (order kept
##                                   exactly: old priority first, then tree order) and a stamp runs between subtrees
##                                   --probe-ms=N: name the subtrees of every frame whose scripts run over N ms (default 8)
##   --loading                       run the real loading screen (build + shader warm-up) first
##   --moments / --psolog / --clean-quit   play moments (zz/perf_moments.gd); name each in-play compile (zz/pso_watch.gd);
##                                   quit like a player at the end (the engine saves its pipeline cache), not a kill
##   --camps[=a,b] / --towns[=a,b]   the camps and villages run (zz/perf_camps.gd): each camp crossed at a sprint or a gallop
##                                   with its foes awake, each town ridden into, looked round and left; frames over 16 ms named
##   --defer-probe[ --defer-ms=8]    (with --hitches) name what ran in a slow frame's deferred flush: each redraw's _draw,
##                                   each skeleton's update (zz/defer_probe.gd)
##   --early                         start measuring the moment the Realm is built (no 6 s settle):
##                                   shows what a player meets right after the load
## Frame time is the real frame delta (vsync off). "scripts" = every _process and _physics_process
## per frame (stamped first/last in line), "render-cpu" = the renderer's CPU side, "rest(gpu)" =
## frame - scripts - render-cpu: on Metal (no GPU timings) that is the GPU wait plus engine overhead.
const SECONDS := 4.0
const RiftCrossing := preload("res://core/world/realm/rift/crossing.gd")
var _stand := SECONDS                 ## --seconds=N: stand this long at each view (a native profiler's sample)
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
	["r_rim", Vector3(0.0, 2.3, -7.0) + Endgame.O, 0.0],            # the Crossing from the Lip (the far north-east: Endgame)
	["r_crag", Vector3(6.0, 27.0, -65.2) + Endgame.O, PI],                  # at the well-head on the Ward Crag, looking down the stair's shaft to the rim
	["r_summit", Vector3(0.0, 27.9, -92.0) + Endgame.O, 0.0],
	["r_summit_back", Vector3(0.0, 28.2, -96.0) + Endgame.O, PI],               # the whole Realm from the dais
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
	["t_hearthward", Vector3(-8.0, NAN, 46.0), -0.62],           # Hearthward's square: from the well over the green to the Keg
	# the rest of the Far Reaches (docs/far_reaches.md, perf critique 16 Nov): 40 m out from each, toward Hearthward, facing it
	["fr_greyfell", Vector3(-277.0, NAN, -88.0), 1.265],         # the Broken Keep on its crag
	["fr_lanternwood", Vector3(-275.0, NAN, 8.0), 1.596],        # the ring of giant caps
	["fr_kings_barrows", Vector3(-279.0, NAN, 135.0), 2.012],    # the heather ridge of great barrows
	["fr_long_arches", Vector3(0.0, NAN, 277.0), PI],            # the aqueduct across the dry valley
	["fr_southwood", Vector3(157.5, NAN, 282.0), -2.633],        # the charcoal burners' ruin
	["fr_drowned_nave", Vector3(279.6, NAN, 146.4), -2.054],     # the flooded cathedral
	["fr_cairns", Vector3(286.8, NAN, 287.7), -2.358],           # the Thousand Cairns and the Cairn Tower
]
## The path: legs of [goal xz (y ignored), label]; a leg starting with "@" teleports there instead.
var route := [
	[Vector3(0, 0, 26.5), "@spawn"],
	[Vector3(-4, 0, 30), "west_way"], [Vector3(-20, 0, 24), "west_way"], [Vector3(-38, 0, 10), "glade"],
	[Vector3(-46, 0, -5), "thornwood"], [Vector3(-50, 0, -10), "henge foot"],     # to the henge stair's foot (RealmLayout.HENGE_STAIR_FOOT): straight at -52/-58 it stuck on the plateau's bank
	[Vector3(26, 0, 22), "@east"],
	[Vector3(42, 0, 10), "east_way"], [Vector3(58, 0, -12), "east_way"], [Vector3(72, 0, -34), "fen"],
	[Vector3(78, 0, -42), "barrows"], [Vector3(62, 0, -56), "fen_descent"], [Vector3(44, 0, -62), "fen_descent"],
	[Vector3(54, 0, -59.5), "fen fire"],
	# the Crossing (the far north-east, from Lastlight's north postern: Endgame)
	[Vector3(0, 0, 22) + Endgame.O, "@rim"],
	[Vector3(0, 0, 4) + Endgame.O, "rift_rim"],     # (the Cinder Way's lanes follow: _spindle_route)
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
var _phys_us_shown := 0                ## this frame's physics share of _proc_us (the probe)
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
	if Array(args).any(func(a: String) -> bool: return a.begins_with("--hitches")):
		get_tree().node_added.connect(_ev_added)
		get_tree().node_removed.connect(_ev_removed)
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
		elif a.begins_with("--seconds="):
			_stand = float(a.trim_prefix("--seconds="))
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
	_psow = _PsoWatch.new()
	_psow.tour = self
	add_child(_psow)
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
		_probe_tp_span = Vector2i(_phys_begin, Time.get_ticks_usec())     # (the probe: this tick's ends)
		_probe_ticks += 1


## A conversation or an offer that opens by itself where the tour stands (a found start by the towns) pauses the night,
## and every later view measured a paused tree from one frozen camera (19 Nov: the towns and the Far Reaches all read
## "120 fps, 2126 draws"). Close it and go on.
const _DialogueUI := preload("res://ui/dialogue.gd")
const _QuestOffer := preload("res://ui/quest_offer.gd")


func _unpause() -> void:
	if not get_tree().paused:
		return
	var what: PackedStringArray = []
	for n in get_tree().get_nodes_in_group(&"dialogue_open"):
		if n is _DialogueUI:
			(n as _DialogueUI).close()
			what.append(String(n.name))
	for n in get_tree().get_nodes_in_group(&"quest_offer"):
		if n is _QuestOffer and (n as _QuestOffer).is_open():
			(n as _QuestOffer).close()
			what.append(String(n.name))
	get_tree().paused = false
	print("PERF unpaused (opened by itself: %s)" % (", ".join(what) if not what.is_empty() else "a panel"))


## Enemies are switched off and hidden, not freed: a freed camp member respawns every 10 s
## (EnemySpawner.RESPAWN) and each spawn builds its creature meshes, which put 40-140 ms frames
## into every window that the views themselves do not cause. (--with-enemies keeps them.)
## 16 Nov (frame pacing): they were switched off and hidden every frame while the spawner, the rares and the director
## woke every foe in reach on their half-second ticks, so each tick showed and re-enabled a few dozen foes and the
## next frame hid them again: a 4-10 ms frame twice a second, about the whole of each window's "1% low". Now each foe
## is put to sleep for good (sleep_range below zero: every tick puts it to sleep, which it already is) and only its
## parts are hidden (the body, the bar, a rare's shimmer), so nothing toggles.
func _quiet_enemies() -> void:
	if "--with-enemies" in OS.get_cmdline_user_args() or _camps_run:
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not (n is Node3D):
			continue
		if n.has_meta(&"tour_awake"):
			continue                                          # --moments: the fight's own foes
		if n.process_mode != Node.PROCESS_MODE_DISABLED:
			n.process_mode = Node.PROCESS_MODE_DISABLED       # (an ambush's 0.9 s wake timer)
		if n.has_meta(&"tour_muted") or n.has_meta(&"tour_awake"):
			continue
		n.set_meta(&"tour_muted", true)
		if "sleep_range" in n:
			n.set("sleep_range", -1.0)
		for c in n.get_children():
			if c is Node3D and not (c is CollisionShape3D):
				(c as Node3D).visible = false


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


## (20 Nov, the fps pass: these legs were still in the rift's old home frame after it moved to Endgame.O, so the run stood pressing on a
## wall for 35 legs of 14 s each; r39: the Cinder Way's own lanes, from its layout) The Lip, the Descent, the causeway, the Ward Stair, the
## ward landing, the summit.
func _spindle_route() -> void:
	for key: String in ["rift_crossing", "rift_crossing_turn", "rift_crossing_top"]:
		for q: Vector2 in RiftCrossing.lane_pts(key):
			route.append([Vector3(q.x, 0, q.y) + Endgame.O, key.trim_prefix("rift_")])
	for e: Array in [[Vector3(0, 0, -77.5), "summit stairs"], [Vector3(-2.8, 0, -79.5), "summit"], [Vector3(-3.6, 0, -83.5), "summit"],
			[Vector3(-2.6, 0, -87.0), "summit"], [Vector3(0, 0, -89.0), "summit"], [Vector3(0, 0, -92.0), "dais"],
			[Vector3(0, 0, -103.9), "dais"]]:
		route.append([(e[0] as Vector3) + Endgame.O, e[1]])


func _process(d: float) -> void:
	t += d
	var script_us := Time.get_ticks_usec() - _proc_begin if _proc_begin > 0 else 0
	_proc_us = script_us + _phys_us
	_phys_us_shown = _phys_us
	_phys_us = 0
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
		return
	if not main.has_meta("realm_done"):
		return
	if load_ms > 0 and not (_moments != null and _moments.map_open):
		_unpause()
		# the dark is not what is measured: a long stand away from light hollowed the wanderer mid-tour (19 Nov, at the
		# Long Arches), a respawn and a teleport inside a measured window
		p.gloom = 0.0
		p.wounds = 0.0
	if load_ms == 0 and main.get_node_or_null("LoadingScreen") != null:
		if "--hitches-under" in OS.get_cmdline_user_args():
			_hitch_log(d)                        # (the frames under the cover too)
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
	_hitch_log(d)
	_probe_report()
	if t < (0.0 if "--early" in OS.get_cmdline_user_args() else 6.0):   # streaming, lava, first shader compiles
		return
	# and the post-build pass (the static merge: the loading screen waits for it, so a player never plays during it; it
	# ran into the first views once it took longer than the settle)
	if not main.has_meta("post_done") and not "--early" in OS.get_cmdline_user_args() and t < 40.0:
		return
	_mute_scripts()
	_quiet_enemies()
	if _cal_step():
		return
	if phase == "":
		print("PSO at start of play: %s" % _pso_totals())
		_psow.go_live()
		if "--moments" in OS.get_cmdline_user_args():
			phase = "moments"
			_moments = _PerfMoments.new()
			_moments.tour = self
			_moments.p = p
			_moments.main = main
			_moments.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_moments)
			_moments.run()
		elif "--bosses" in OS.get_cmdline_user_args():
			phase = "bosses"
			_bosses_begin()
		elif _camps_run:                                    # --camps / --towns (zz/perf_camps.gd)
			phase = "camps"
			_camps = _PerfCamps.new()
			_camps.set("tour", self)
			_camps.set("p", p)
			_camps.set("main", main)
			_camps.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_camps)
			_camps.call("run")
		elif blame:
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
		"bosses":
			_bosses_step(d)
		"path":
			_path_step(d)
		"attrib":
			_attrib_step(d)
		"census":
			_census_step()



## The window a frame belongs to (PsoWatch labels each compile with it).
const _PsoWatch := preload("res://zz/pso_watch.gd")
const _PerfMoments := preload("res://zz/perf_moments.gd")
const _PerfCamps := preload("res://zz/perf_camps.gd")
const _DeferProbe := preload("res://zz/defer_probe.gd")
var _defer: Node
var _defer_on := "--defer-probe" in OS.get_cmdline_user_args()
var _camps: Node
var _camps_run := Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--camps") or a.begins_with("--towns"))
var _psow: _PsoWatch
var _moments: _PerfMoments


func where() -> String:
	match phase:
		"points", "attrib", "census", "blame":
			return "pt:" + (String(points[i][0]) if i >= 0 and i < points.size() else "?")
		"path":
			return "path:" + (String(route[leg][1]) if leg < route.size() else "end")
		"bosses":
			return "boss:%s%s" % [(_bs_arenas[_bs_i] as BossArena).boss_id if _bs_i >= 0 and _bs_i < _bs_arenas.size() and is_instance_valid(_bs_arenas[_bs_i]) else "?", " pull" if _bs_stage == 1 else ""]
		"moments":
			return "moments:" + (_moments.name_now if _moments != null and _moments.name_now != "" else "-")
		"camps":
			return "camps:" + (String(_camps.get("name_now")) if _camps != null else "-")
	return "settle"


# --- hitch attribution (--hitches): what a slow frame's neighbours did ---------------------------------------
## Per frame: nodes added / removed (the first few named), resources and objects made, static memory. A slow
## frame prints the last four frames' records, so a spawn, a free or a load burst names itself.
var _ev_add := 0
var _ev_rem := 0
var _ev_names := PackedStringArray()
var _ev_ring: Array = []              ## last 4 frames: [frame, added, removed, names, res delta, obj delta, mem delta KB, scripts ms, delta ms]
var _ev_res := 0
var _ev_obj := 0
var _ev_mem := 0
var _hitch_n := 0
var _ev_pso := [0, 0, 0, 0]
const _PSO := [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]


## Pipeline compiles so far, by kind (canvas, mesh, surface, draw, specialization) and their sum.
func _pso_totals() -> String:
	var parts := PackedStringArray()
	var sum := 0
	for k in _PSO.size():
		var n := int(RenderingServer.get_rendering_info(_PSO[k]))
		sum += n
		parts.append(str(n))
	return "canvas/mesh/surface/draw/spec %s = %d" % ["/".join(parts), sum]


func _ev_note(sign: String, n: Node) -> void:
	if _ev_names.size() < 5:
		var sc: Script = n.get_script()
		_ev_names.append("%s%s/%s%s" % [sign, n.get_parent().name if n.get_parent() else "?", n.name, "(" + sc.resource_path.get_file() + ")" if sc else ""])


func _ev_added(n: Node) -> void:
	_ev_add += 1
	_ev_note("+", n)


func _ev_removed(n: Node) -> void:
	_ev_rem += 1
	_ev_note("-", n)


## Marks after the scripts: the deferred flush (a CanvasItem's _draw, call_deferred work, the delete queue), the
## renderer's pre-draw and post-draw; the record of a frame carries [deferred, to pre-draw, draw] ms.
var _m_proc_end := 0
var _m_def := 0
var _m_pre := 0
var _m_post := 0
var _m_hooked := false


func _mark_def() -> void:
	_m_def = Time.get_ticks_usec()


func _hitch_log(d: float) -> void:
	if not hitches:
		return
	if not _m_hooked:
		_m_hooked = true
		RenderingServer.frame_pre_draw.connect(func() -> void: _m_pre = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func() -> void: _m_post = Time.get_ticks_usec())
	var segs := ""
	if _m_proc_end > 0 and _m_def >= _m_proc_end and _m_pre >= _m_def and _m_post >= _m_pre:
		segs = " | def %.1f pre %.1f draw %.1f" % [(_m_def - _m_proc_end) / 1000.0, (_m_pre - _m_def) / 1000.0, (_m_post - _m_pre) / 1000.0]
	if _defer == null and phase != "" and _defer_on:
		_defer = _DeferProbe.new()                   # (zz/defer_probe.gd: who spends the deferred flush)
		_defer.set("tour", self)
		add_child(_defer)
	if _defer != null and _m_proc_end > 0 and _m_def >= _m_proc_end:
		_defer.call("frame", _m_proc_end, _m_def, t)
	_m_proc_end = Time.get_ticks_usec()
	_mark_def.call_deferred()
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var obj := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem := int(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1024
	var pso := []
	var pso_txt := ""
	for k in _PSO.size():
		pso.append(RenderingServer.get_rendering_info(_PSO[k]))
		if _ev_pso.size() == _PSO.size() and int(pso[k]) != int(_ev_pso[k]):
			pso_txt += " %s+%d" % [["canvas", "mesh", "surface", "draw", "spec"][k], int(pso[k]) - int(_ev_pso[k])]
	_ev_pso = pso
	var rcpu := (RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()) if vp_rid.is_valid() else 0.0
	var info := "draws %d rcpu %.1f%s%s" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), rcpu, (" PSO" + pso_txt) if pso_txt != "" else "", segs]
	_ev_ring.append([Engine.get_process_frames(), _ev_add, _ev_rem, info + " " + ",".join(_ev_names), res - _ev_res, obj - _ev_obj, mem - _ev_mem, _proc_us / 1000.0, d * 1000.0])
	_ev_add = 0
	_ev_rem = 0
	_ev_names = PackedStringArray()
	_ev_res = res
	_ev_obj = obj
	_ev_mem = mem
	if _ev_ring.size() > 4:
		_ev_ring.pop_front()
	if d * 1000.0 > hitch_ms and _hitch_n < (2000 if _camps_run else 400):     # (a camps run teleports two dozen times)
		_hitch_n += 1
		print("HITCH t %.2f s %s %.1f ms:" % [t, phase if phase != "" else "settle", d * 1000.0])
		for e: Array in _ev_ring:
			print("HITCH   f%d +%d -%d res %+d obj %+d mem %+d KB scripts %.1f delta %.1f %s" % [e[0], e[1], e[2], e[4], e[5], e[6], e[7], e[8], e[3]])



# --- subtree probe (--probe) --------------------------------------------------------------------------------
## Units: Main's children, and the children of each that has at most PROBE_SPLIT. Every node of unit k keeps its old
## priority's order: new = old * PROBE_STRIDE + 2k + 1 (old priorities this tour itself uses are left alone), and a
## stamp node runs at 2k + 2 in both passes. A burst frame prints the units between the widest stamps.
const PROBE_SPLIT := 200
const PROBE_STRIDE := 20000
var _probe_on := false
var _probe_units: Array[String] = []
var _probe_t := PackedInt64Array()           ## idle pass: stamp time by unit
var _probe_tp_last := PackedInt64Array()     ## physics pass: each unit's stamp in the last tick
var _probe_tp_span := Vector2i.ZERO          ## the last tick's first and last stamp (the tour's own)
var _probe_ticks := 0                        ## physics ticks since the last idle frame
var _probe_left := 120                       ## reports at most this many frames
var _probe_us := 8000                        ## a frame whose scripts run over this is reported (--probe-ms=N)

const _PROBE_SRC := """extends Node
var tour: Node
var k := 0
func _process(_d: float) -> void:
	tour._probe_stamp(k, false)
func _physics_process(_d: float) -> void:
	tour._probe_stamp(k, true)
"""


func _probe_setup() -> void:
	if _probe_on or not ("--probe" in OS.get_cmdline_user_args()):
		return
	_probe_on = true
	var units: Array[Node] = []
	var split: PackedStringArray = []                 # --probe-split=A,B: these subtrees by child, however small
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-ms="):              # a lower bar names the units of the smaller bursts (2 Hz ticks)
			_probe_us = int(float(a.trim_prefix("--probe-ms=")) * 1000.0)
			_probe_left = 600
		if a.begins_with("--probe-split="):
			split = a.trim_prefix("--probe-split=").split(",")
	# the autoloads and Main's own node are units too (a burst outside Main's children was reported as nobody's); Main's
	# children come after and take their subtrees back
	for c in get_tree().root.get_children():
		if c != self and not String(c.name).begins_with("Perf"):
			units.append(c)
	for c in main.get_children():
		if c.get_child_count() <= PROBE_SPLIT and not (String(c.name) in split):
			units.append(c)
		else:
			units.append(c)                     # the parent itself (its own processing) is a unit too
			for cc in c.get_children():
				units.append(cc)
				if (String(c.name) + "/" + String(cc.name)) in split:     # a second level named as "Parent/Child": its children are units too
					for c3 in cc.get_children():
						units.append(c3)
	var script := GDScript.new()
	script.source_code = _PROBE_SRC
	script.reload()
	var holder := Node.new()
	holder.name = "PerfProbes"
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(holder)
	# each node is renumbered once, by the last (the deepest) unit that holds it: a subtree that is also split into units
	# was renumbered twice, which moved it past every stamp (its time showed as nobody's)
	var unit_of := {}                                 # node id -> [node, unit]
	for k in units.size():
		var u := units[k]
		_probe_units.append(String(main.get_path_to(u)))
		var nodes: Array[Node] = [u]
		if not ((u.get_child_count() > PROBE_SPLIT or String(u.name) in split) and u.get_parent() == main):
			nodes.append_array(u.find_children("*", "", true, false))
		for n in nodes:
			unit_of[n.get_instance_id()] = [n, k]
	for id: int in unit_of:
		var n := unit_of[id][0] as Node
		var k := int(unit_of[id][1])
		var p := n.process_priority
		var pp := n.process_physics_priority
		if absi(p) < PROBE_STRIDE / 2:
			n.process_priority = p * PROBE_STRIDE + 2 * k + 1
		if absi(pp) < PROBE_STRIDE / 2:
			n.process_physics_priority = pp * PROBE_STRIDE + 2 * k + 1
	var renumbered := unit_of.size()
	for k in units.size():
		var st := Node.new()
		st.set_script(script)
		st.set("tour", self)
		st.set("k", k)
		st.process_priority = 2 * k + 2
		st.process_physics_priority = 2 * k + 2
		st.process_mode = Node.PROCESS_MODE_ALWAYS
		holder.add_child(st)
	_probe_t.resize(units.size())
	_probe_tp_last.resize(units.size())
	print("PROBE %d units, %d nodes renumbered" % [units.size(), renumbered])


func _probe_stamp(k: int, phys: bool) -> void:
	if phys:
		_probe_tp_last[k] = Time.get_ticks_usec()
	else:
		_probe_t[k] = Time.get_ticks_usec()


## On a frame whose scripts ran over 8 ms: the units with the widest gaps before their stamps (idle pass), and the
## physics pass's widest gaps from its last tick.
func _probe_report() -> void:
	if not _probe_on:
		_probe_setup()
		return
	if _proc_us > _probe_us and _probe_left > 0:
		_probe_left -= 1
		var gaps: Array = []
		var last := _probe_t.size() - 1
		if _probe_t[0] > 0 and _proc_begin > 0:
			gaps.append([_probe_t[0] - _proc_begin, 0])      # unit 0, and every node spawned since the setup (priority 0)
		for k in range(1, _probe_t.size()):
			if _probe_t[k] > 0 and _probe_t[k - 1] > 0:
				gaps.append([_probe_t[k] - _probe_t[k - 1], k])
		if _probe_t[last] > 0:
			gaps.append([Time.get_ticks_usec() - _probe_t[last], -1])         # after the last unit: a node with a priority past the bands
		var pg: Array = []
		if _probe_tp_last[0] > 0 and _probe_tp_span.x > 0 and _probe_tp_last[0] >= _probe_tp_span.x:
			pg.append([_probe_tp_last[0] - _probe_tp_span.x, 0])          # unit 0 and the nodes spawned since (as above)
		for k in range(1, _probe_tp_last.size()):
			if _probe_tp_last[k] > 0 and _probe_tp_last[k - 1] > 0 and _probe_tp_last[k] >= _probe_tp_last[k - 1]:
				pg.append([_probe_tp_last[k] - _probe_tp_last[k - 1], k])
		if _probe_tp_last[_probe_tp_last.size() - 1] > 0 and _probe_tp_span.y >= _probe_tp_last[_probe_tp_last.size() - 1]:
			pg.append([_probe_tp_span.y - _probe_tp_last[_probe_tp_last.size() - 1], -1])
		gaps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		pg.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var txt := PackedStringArray()
		for g: Array in gaps.slice(0, 4):
			txt.append("%s %.1f" % [_probe_units[g[1]] if int(g[1]) >= 0 else "(after the last unit)", g[0] / 1000.0])
		var ptxt := PackedStringArray()
		for g: Array in pg.slice(0, 3):
			ptxt.append("%s %.1f" % [_probe_units[g[1]] if int(g[1]) >= 0 else "(after the last unit)", g[0] / 1000.0])
		print("PROBE t %.2f scripts %.1f ms (idle %.1f, physics %.1f in %d ticks) | idle: %s | last tick: %s" % [t, _proc_us / 1000.0,
			(_proc_us - _phys_us_shown) / 1000.0, _phys_us_shown / 1000.0, _probe_ticks, ", ".join(txt), ", ".join(ptxt)])
		if not gaps.is_empty() and int((gaps[0] as Array)[1]) == -1:
			_probe_tail()
	_probe_t.fill(0)
	_probe_ticks = 0


## The tail is the nodes processed after the last unit's stamp: a priority past the bands (a positive one, or one set since
## the setup). Name the ones processing now (a scan of the tree: only on such a report).
func _probe_tail() -> void:
	var top := 2 * _probe_units.size() + 2
	var by := {}                                      # script (or class) -> [count, a path]
	for n in get_tree().root.find_children("*", "", true, false):
		if n == self or String(n.name).begins_with("Perf") or not (n.is_processing() or n.is_processing_internal()):
			continue
		if n.process_priority > top and n.process_priority < (1 << 30):
			var scr := n.get_script() as Script
			var k := "%s %d" % [scr.resource_path.get_file() if scr else n.get_class(), n.process_priority / PROBE_STRIDE]
			if not by.has(k):
				by[k] = [0, str(n.get_path())]
			by[k][0] += 1
	var out := PackedStringArray()
	for k: String in by:
		out.append("%s x%d (%s)" % [k, int(by[k][0]), String(by[k][1])])
	print("PROBE tail: %s" % ", ".join(out))


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
	if float(acc.time) >= _stand:
		var r := _report("PERF %-14s" % points[i][0])
		summary.append([points[i][0]] + r)
		if "--casters" in OS.get_cmdline_user_args():
			_casters_report()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--why-under="):
				_why_under(a.trim_prefix("--why-under=").split(","))
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
	acc.cv_draws = int(acc.get("cv_draws", 0)) + RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
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
	print("%s fps %6.1f  1%%low %6.1f  p99 %5.1f  worst %5.1f ms  sd %4.2f  >33ms %d  | scripts %5.2f physics(max/s) %5.2f render-cpu %5.2f rest(gpu) %5.2f ms | draws %4d (max %4d, shadow %d) objs %5d prims %7d (max %7d, shadow %d) | blur %d%% | canvas draws %d" % [
		label, st[0], st[1], st[2], st[3], st[4], st[6], proc, phys, cpu, maxf(0.0, frame_ms - proc - cpu),
		int(float(acc.draws) / n), int(acc.max_draws), int(float(acc.get("sh_draws", 0)) / n), int(float(acc.objs) / n),
		int(float(acc.prims) / n), int(acc.max_prims), int(float(acc.get("sh_prims", 0)) / n), roundi(100.0 * float(acc.get("blur", 0)) / n),
		int(float(acc.get("cv_draws", 0)) / n)])
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


# --- casters (--casters): the shadow casters near the view by size, and the heaviest ones ---------

const _MeshMerge := preload("res://core/util/mesh_merge.gd")


## --why-under=A/B,C: under each of these nodes (paths from Main), what draws in view and why each plain mesh is not
## merged (MeshMerge._why): MultiMeshes, ranged / unranged meshes, and the reasons, counted.
func _why_under(paths: PackedStringArray) -> void:
	var cam := get_viewport().get_camera_3d()
	for path in paths:
		var root := main.get_node_or_null(NodePath(path))
		if root == null:
			continue
		var why := {}
		var n_mm := 0
		var n_mi := 0
		var near := 0
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if not gi.is_visible_in_tree():
				continue
			if gi is MultiMeshInstance3D:
				n_mm += 1
				continue
			if not (gi is MeshInstance3D):
				continue
			var mi := gi as MeshInstance3D
			if mi.mesh == null:
				continue
			var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
			var d := ab.get_center().distance_to(cam.global_position)
			var shown := mi.visibility_range_end <= 0.0 or d < mi.visibility_range_end + mi.visibility_range_end_margin
			if not shown or d < mi.visibility_range_begin:
				continue
			n_mi += 1
			near += 1 if d < 60.0 else 0
			var w := _MeshMerge._why(mi)
			if w == "ok":
				w = "ok (merged? %s, range %.0f, parent %s)" % [mi.has_meta(&"merged"), mi.visibility_range_end, mi.get_parent().get_class() if mi.get_parent().get_script() == null else String((mi.get_parent().get_script() as Script).resource_path).get_file()]
			why[w] = int(why.get(w, 0)) + 1
		var keys := why.keys()
		keys.sort_custom(func(x: Variant, y: Variant) -> bool: return int(why[x]) > int(why[y]))
		var parts := PackedStringArray()
		for k: Variant in keys.slice(0, 10):
			parts.append("%s x%d" % [k, why[k]])
		print("WHY %s %s: %d meshes in range (%d within 60 m), %d multimeshes | %s" % [points[i][0], path, n_mi, near, n_mm, "; ".join(parts)])


static func _mesh_tris(m: Mesh) -> int:
	var am := m as ArrayMesh
	if am == null:
		return 12                                    # a primitive box or sphere: a handful
	var t := 0
	for si in am.get_surface_count():
		var n := am.surface_get_array_index_len(si)
		t += (n if n > 0 else am.surface_get_array_len(si)) / 3
	return t


## Every mesh within 40 m of the camera (the moon's shadow reach; the fire's is less) that casts, by the size of its
## world box: count and triangles a class, and the twenty heaviest with their paths (a MultiMesh counts its instances).
func _casters_report() -> void:
	var cam := get_viewport().get_camera_3d()
	var bounds := [0.3, 0.6, 1.2, 2.5, 1e9]
	var cls: Array = []
	for b in bounds:
		cls.append([0, 0])
	var heavy: Array = []
	for g in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not gi.is_visible_in_tree():
			continue
		var tris := 0
		var big := 0.0
		var at := gi.global_position
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var m := (gi as MeshInstance3D).mesh
			var ab: AABB = gi.global_transform * m.get_aabb()
			at = ab.get_center()
			big = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
			tris = _mesh_tris(m)
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null and (gi as MultiMeshInstance3D).multimesh.mesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			var ab2 := mm.mesh.get_aabb()
			big = maxf(ab2.size.x, maxf(ab2.size.y, ab2.size.z))
			var per := _mesh_tris(mm.mesh)
			var cnt := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			tris = per * cnt
			at = (gi.global_transform * gi.get_aabb()).get_center()
		else:
			continue
		if at.distance_to(cam.global_position) > 40.0:
			continue
		for k in bounds.size():
			if big < bounds[k]:
				cls[k][0] += 1
				cls[k][1] += tris
				break
		heavy.append([tris, big, str(main.get_path_to(gi)).substr(0, 70)])
	heavy.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("CASTERS %s by size (count, tris): <0.3 m %s, <0.6 m %s, <1.2 m %s, <2.5 m %s, larger %s" % [points[i][0], cls[0], cls[1], cls[2], cls[3], cls[4]])
	for h: Array in heavy.slice(0, 20):
		print("CASTERS   %7d tris  %5.2f m  %s" % [h[0], h[1], h[2]])


# --- census: what each part of the world adds to this view (draws and primitives are exact) ------

var c_groups: Array = []             # [label, Array of nodes]
var c_k := 0
var c_wait := 0
var c_base := Vector4i.ZERO
var c_rows: Array = []
var c_base_cv := 0                   # canvas draws in the census's base frame


func _canvas_draws() -> int:
	return RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


## A census group's nodes shown or hidden (3D nodes, and the HUD's canvas items).
static func _c_show(n: Variant, on: bool) -> void:
	if not is_instance_valid(n):
		return                                       # (freed since the census listed it: a HUD row rebuilt, a merged mesh)
	if n is Node3D:
		(n as Node3D).visible = on
	elif n is CanvasItem:
		(n as CanvasItem).visible = on


func _counts() -> Vector4i:
	var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var sh := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	return Vector4i(RenderingServer.viewport_get_render_info(vp_rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, vis, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, sh, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp_rid, sh, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))


## A canvas layer's parts as census groups: plain containers (no script, with children) are opened, anything else is a row.
func _c_ui(n: Node, label: String) -> void:
	for cc in n.get_children():
		if not (cc is CanvasItem) or not (cc as CanvasItem).visible:
			continue
		var nm := label + "/" + String(cc.name)
		if cc.get_script() == null and cc.get_child_count() > 0:
			_c_ui(cc, nm)
		else:
			c_groups.append([nm, [cc]])


func _census_begin() -> void:
	c_groups.clear()
	var flora := main.get_node_or_null("RealmFlora")
	var split: PackedStringArray = []                 # --census-split=A,B: these top-level nodes by child
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--census-split="):
			split = a.trim_prefix("--census-split=").split(",")
	for c in main.get_children():
		if c is Node3D and (c as Node3D).visible and c != flora and not c is Player:
			if String(c.name) in split:
				for cc in c.get_children():
					if cc is Node3D and (cc as Node3D).visible:
						c_groups.append([String(c.name) + "/" + String(cc.name), [cc]])
			else:
				c_groups.append([String(c.name), [c]])
	var player := main.get_node_or_null("Player")
	if player:
		c_groups.append(["Player", [player]])
	for cl in main.find_children("*", "CanvasLayer", true, false):          # the HUD's canvas items, by part
		if (cl as CanvasLayer).visible:
			_c_ui(cl, "ui " + String(cl.name))
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
		c_base_cv = _canvas_draws()
	else:
		var now := _counts()
		var dlt := c_base - now
		c_rows.append([c_groups[c_k][0], dlt, c_base_cv - _canvas_draws()])
		for n in c_groups[c_k][1]:
			_c_show(n, true)
	c_k += 1
	if c_k >= c_groups.size():
		c_rows.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector4i).y + (a[1] as Vector4i).w > (b[1] as Vector4i).y + (b[1] as Vector4i).w)
		print("CENSUS %s total draws %d prims %d (shadow draws %d prims %d) canvas draws %d" % [points[i][0], c_base.x, c_base.y, c_base.z, c_base.w, c_base_cv])
		for r: Array in c_rows:
			var v: Vector4i = r[1]
			if v.x != 0 or v.y != 0 or v.z != 0 or v.w != 0 or int(r[2]) != 0:
				print("CENSUS   %-30s draws %4d prims %8d | shadow draws %4d prims %8d | canvas %4d" % [r[0], v.x, v.y, v.z, v.w, int(r[2])])
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
		_c_show(n, false)
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
	_psow.report()
	print("PSO at end: %s" % _pso_totals())
	print("PERF done (nodes %d, static mem %.0f MB, video mem %.0f MB)" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	if "--clean-quit" in OS.get_cmdline_user_args():
		get_tree().quit()                    # a player's quit: the engine writes its pipeline cache on the way out
		return
	OS.kill(OS.get_process_id())


## --bosses: for each boss arena in turn, the wanderer stands APPROACH_R m past its edge (the warm and staging zone) for
## 5 s, then is put at its centre (the pull). Prints the worst frame of each window and the frames over 16 ms; the arena
## itself prints "BOSSPULL" with what its pull cost. The Realm's other life goes on (--hitches names what was built).
const APPROACH_R := 16.0
var _bs_arenas: Array = []
var _bs_i := -1
var _bs_t := 0.0
var _bs_stage := 0
var _bs_worst := 0.0
var _bs_over := 0


func _bosses_begin() -> void:
	BossArena.staging = not ("--no-stage" in OS.get_cmdline_user_args())
	for a: Node in get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as BossArena
		if ar != null and not ar.slain() and ar.boss_script != null:
			_bs_arenas.append(ar)
	print("BOSSES %d arenas" % _bs_arenas.size())
	_bs_i = -1
	_bosses_next()


func _bosses_next() -> void:
	_bs_i += 1
	_bs_stage = 0
	_bs_t = 0.0
	_bs_worst = 0.0
	_bs_over = 0
	if _bs_i >= _bs_arenas.size():
		_finish()


func _bosses_stand(a: BossArena, off: Vector3) -> void:
	var at := a.global_position + off
	var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 40.0, Layers.WORLD))
	at.y = (hit.position as Vector3).y + 0.2 if not hit.is_empty() else a.global_position.y + 0.2
	if p.global_position.distance_to(at) > 0.3:
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _bosses_step(d: float) -> void:
	var a := _bs_arenas[_bs_i] as BossArena
	if not is_instance_valid(a):
		_bosses_next()
		return
	_bs_t += d
	if _bs_t > 0.6 or _bs_stage == 1:
		_bs_worst = maxf(_bs_worst, d * 1000.0)
		if d > 0.016:
			_bs_over += 1
	if _bs_stage == 0:
		_bosses_stand(a, Vector3(a.radius + APPROACH_R, 0.0, 0.0))
		if _bs_t > 6.0:
			print("BOSSES %s approach: worst frame %.1f ms, %d frames over 16 ms" % [a.boss_id, _bs_worst, _bs_over])
			_bs_stage = 1
			_bs_t = 0.0
			_bs_worst = 0.0
			_bs_over = 0
	else:
		_bosses_stand(a, Vector3.ZERO)
		if _bs_t > 4.0:
			print("BOSSES %s pull: worst frame %.1f ms, %d frames over 16 ms, fight %s" % [a.boss_id, _bs_worst, _bs_over, "begun" if bool(a.get("_active")) else "NOT begun"])
			_bosses_next()


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

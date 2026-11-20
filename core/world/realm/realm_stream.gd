class_name RealmStream
extends Node
## The Realm's node instancing, streamed. The placement DATA stays global (quests, the map, the waypoint and the
## tests read all of it); what streams is the node / mesh emission built from it: a builder hands this node one small
## job per place (a flora chunk, a terrain tile...) with where it stands, and
##   - jobs inside the build ring (RING_R round the spawn or save) run at once, so the ground the wanderer wakes on
##     is complete before control;
##   - the rest are queued and run nearest-first, in slices of BUDGET_US a frame (the loading screen gets a bigger
##     slice, BOOT_BUDGET_US), while the wanderer plays;
##   - a jump (fast travel, a death respawn, a tether...) calls ensure() for the target: its ring is built before the
##     fade lifts.
## Headless runs and the tests build all at once (the default there): submit() runs the job in place, so the tree
## the tests read is the one they always read. `--stream` turns streaming on headless (the stream's own test),
## `--build-all` turns it off in a window.
## One node per night under the zone (RealmStream.of(root)); no statics hold nodes or callables.

signal drained                              ## the queue is empty (every streamed piece is built)

const RING_R := 170.0                       ## built before control: everything within this of the build centre
const BUDGET_US := 2000                     ## main-thread slice a frame in play
const BOOT_BUDGET_US := 9000                ## ... under the loading screen (the cover hides the frames)
const RESORT_M := 24.0                      ## the queue is re-ordered after the wanderer moves this far
const SLOW_FRAME := 0.0125                  ## a frame this slow gets no slice (the stream never makes a hitch worse)

var center := Vector2.ZERO                  ## where the first ring is built (the spawn or the save)
var _jobs: Array = []                       ## [pos: Vector2, job: Callable, tier: int], sorted far-to-near after _sort()
var _dirty := false
var _sorted_at := Vector2(INF, INF)
var _focus := Vector2.ZERO
var _focus_until := 0                       ## msec: the focus holds until then
var _was_focused := false
var _done_jobs := 0
var _total_jobs := 0
var _t_first := 0
var _started := false                       ## the build is over (start_pumping): only then is an empty queue 'drained'
var _busy_us := 0
var _play_frames := 0
var _over_16 := 0
var _over_free := 0
var _last_slice := 0
var _paces: Array[float] = []
var _worst_play := 0.0
var _worst_us := 0


static var force_on := false                ## a test turns the stream on in a headless run before it builds the night


static func wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	if force_on or "--stream" in args:
		return true
	return DisplayServer.get_name() != "headless" and not ("--build-all" in args)


## The stream of the night under `root`, or null when none was set up.
static func of(root: Node) -> RealmStream:
	return root.get_node_or_null("RealmStream") as RealmStream if root != null else null


## Set up at the start of the Realm's build (realm.gd): `at` is where the first ring is built.
static func begin(root: Node, at: Vector2) -> RealmStream:
	var s := of(root)
	if s != null:
		return s
	s = RealmStream.new()
	s.name = "RealmStream"
	s.center = at
	root.add_child(s)
	s.set_process(false)
	return s


## Hand over a piece of the build. Without a stream, or when the piece is inside the ring, it runs now.
## Returns true if it ran now. `tier` -1 jobs always run now (what is seen from afar: the canopy shells and the tall trees,
## which show to the horizon); tier 0 jobs go before every tier 1 job of any distance.
static func submit(root: Node, pos: Vector2, job: Callable, tier := 1) -> bool:
	var s := of(root)
	if s == null or not s.streaming() or tier < 0 or pos.distance_to(s.center) <= RING_R:
		job.call()
		return true
	s._jobs.append([pos, job, tier])
	s._total_jobs += 1
	s._dirty = true
	return false


## True while jobs may still be queued (the build is over and the queue is not).
func streaming() -> bool:
	return wanted()


func pending() -> int:
	return _jobs.size()


## Run every queued job within `radius` of `pos` now (a jump's target; a place that needs its flora).
func ensure(pos: Vector2, radius := RING_R) -> int:
	var n := 0
	var i := _jobs.size() - 1
	while i >= 0:
		var j: Array = _jobs[i]
		if (j[0] as Vector2).distance_to(pos) <= radius:
			_jobs.remove_at(i)
			(j[1] as Callable).call()
			_done_jobs += 1
			n += 1
		i -= 1
	_after()
	return n


## Run everything still queued, now (a place that must read all of it; the tests' wait).
func drain() -> void:
	while not _jobs.is_empty():
		var j: Array = _jobs.pop_back()
		(j[1] as Callable).call()
		_done_jobs += 1
	_after()


## The build is over: start the background work.
func start_pumping() -> void:
	_started = true
	_t_first = Time.get_ticks_msec()
	_dirty = true
	if _jobs.is_empty():
		_after()
		return
	set_process(true)


## The loading screen is up: the frames are hidden, so the slices are big.
func _loading() -> bool:
	return get_tree().get_first_node_in_group(&"loading_screen") != null


## A place the wanderer is about to be at (a respawn's fire): its ring is built first, in big slices, for `seconds`.
func focus(pos: Vector2, seconds: float) -> void:
	_focus = pos
	_focus_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_dirty = true
	if _started and not _jobs.is_empty():
		set_process(true)


func _player_xz() -> Vector2:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return center
	return Vector2(p.global_position.x, p.global_position.z)


## Far-to-near (the last element runs first): tier 0 before tier 1, then by distance to the wanderer.
func _sort() -> void:
	var at := _player_xz()
	_sorted_at = at
	_dirty = false
	var focused := Time.get_ticks_msec() < _focus_until
	var keyed: Array = []
	keyed.resize(_jobs.size())
	for i in _jobs.size():
		var j: Array = _jobs[i]
		var p: Vector2 = j[0]
		var dist := p.distance_to(at)
		if focused:
			dist = minf(dist, p.distance_to(_focus))
		keyed[i] = [dist + (0.0 if int(j[2]) == 0 else 100000.0), j]
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in keyed.size():
		_jobs[i] = (keyed[i] as Array)[1]


var _probed := false


## (measurement only: --stream-probe) what an add_child costs in play, by kind of node.
func _probe() -> void:
	_probed = true
	var host := Node3D.new()
	host.name = "ProbeHost"
	add_child(host)
	var box := BoxMesh.new()
	var rows := []
	for kind in ["node3d", "mmi_plain", "mmi_range", "mmi_range_fade", "mmi_big", "mesh_inst"]:
		var tot := 0
		var worst := 0
		for k in 12:
			var n: Node
			match kind:
				"node3d":
					n = Node3D.new()
				"mesh_inst":
					var mi := MeshInstance3D.new()
					mi.mesh = box
					n = mi
				_:
					var mm := MultiMesh.new()
					mm.transform_format = MultiMesh.TRANSFORM_3D
					mm.use_colors = true
					mm.mesh = box
					var cnt := 600 if kind == "mmi_big" else 4
					mm.instance_count = cnt
					var buf := PackedFloat32Array()
					buf.resize(cnt * 16)
					mm.buffer = buf
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					if kind == "mmi_range" or kind == "mmi_range_fade":
						mmi.visibility_range_end = 90.0
					if kind == "mmi_range_fade":
						mmi.visibility_range_end_margin = 6.0
						mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
					n = mmi
			var t0 := Time.get_ticks_usec()
			host.add_child(n)
			var took := Time.get_ticks_usec() - t0
			tot += took
			worst = maxi(worst, took)
		rows.append("%s avg %.2f worst %.2f ms" % [kind, tot / 12000.0, worst / 1000.0])
	print("STREAM probe add_child: ", "; ".join(rows))
	host.queue_free()


func _process(delta: float) -> void:
	if not _probed and "--stream-probe" in OS.get_cmdline_user_args() and not _loading():
		_probe()
	if _jobs.is_empty():
		_after()
		return
	var focused := Time.get_ticks_msec() < _focus_until
	var cover := _loading()
	if cover:
		return                                    # the loading screen's own frames are for its tour; the stream works once the wanderer plays
	var slice := BOOT_BUDGET_US if focused else BUDGET_US     # (a focus is under a fade: black)
	if not cover:
		_play_frames += 1                         # the frames the wanderer plays while the stream works
		if delta > 0.016:
			if _last_slice > 0:
				_over_16 += 1                     # (this frame carried the last frame's slice)
			else:
				_over_free += 1                   # a slow frame the stream had no part in
		_worst_play = maxf(_worst_play, delta)
		_paces.append(delta)
		if _paces.size() > 40:
			_paces.remove_at(0)
	_last_slice = 0
	if not focused and not cover and _paces.size() >= 8:
		var s := _paces.duplicate()
		s.sort()
		var med: float = s[s.size() >> 1]
		if delta > maxf(med * 1.3, SLOW_FRAME):      # a frame the game already struggles with gets no slice
			return
	if focused != _was_focused:
		_was_focused = focused
		_dirty = true
	if _dirty or _player_xz().distance_to(_sorted_at) > RESORT_M:
		_sort()
	var t0 := Time.get_ticks_usec()
	while not _jobs.is_empty():
		var j: Array = _jobs.pop_back()
		(j[1] as Callable).call()
		_done_jobs += 1
		if Time.get_ticks_usec() - t0 > slice:
			break
	var used := Time.get_ticks_usec() - t0
	_last_slice = used
	_busy_us += used
	_worst_us = maxi(_worst_us, used)
	if _jobs.is_empty():
		_after()


func _after() -> void:
	if not _started or not _jobs.is_empty() or not is_inside_tree():
		return
	set_process(false)
	var root := get_parent()
	if root != null and not root.has_meta(&"realm_streamed"):
		root.set_meta(&"realm_streamed", true)
		print("STREAM drained: %d queued jobs, %d ms from the hand-over, %.1f ms of slices (worst %.1f ms); %d frames in play, %d over 16 ms after a slice (%d with none), worst %.1f ms" % [
			_total_jobs, Time.get_ticks_msec() - _t_first if _t_first > 0 else 0, _busy_us / 1000.0, _worst_us / 1000.0,
			_play_frames, _over_16, _over_free, _worst_play * 1000.0])
		drained.emit()

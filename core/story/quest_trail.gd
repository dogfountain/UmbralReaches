extends Node
## The trail (docs/quest_trail.md): where the tracked task's one waypoint hangs while its place is not in plain sight
## along the way. Like Destiny 2's moving waypoint (Luke, 17 Nov: one marker, not three; the same mark the whole way; it
## works from 10 m to 500 m out and goes when you arrive): ui/waypoint.gd draws the one mark; this says where. While the
## way to the place bends, the mark hangs over the farthest point of the route that the straight sight-line from the
## wanderer still follows (within CORRIDOR m of it, at most LOOK m along it), held there until you are REACH m from it,
## then on to the next; the place itself (guide is INF) only on the last straight within LOOK m. Far off, it is never the
## place (Luke: "the destination one shouldn't be visible if 500m away, it should be the checkpoint"). One per night, a child of the story director (story.gd), group
## "quest_trail".
##   - the route: from the wanderer to the tracked step's foot point (quest_track.gd). The ways first: on to the nearest
##     road or lane, along it (TrailRoute: an A* over RealmLayout.PATHS and the walkway lanes), off at the one nearest
##     the place; the legs on and off by the navigation mesh (asked asynchronously, one query each) or straight, and the
##     mesh's own path (or a straight line, with the mesh still baking) where the ways would not help. Rebuilt only when
##     the followed step or its place changes, the place moves more than MOVED m, the wanderer strays STRAY m off the
##     route, or the mesh came in; at most every REBUILD_GAP seconds. Nothing searches per frame: the aim is a few
##     thousand point-to-segment checks five times a second.
##   - the point is seated once per aim, on the surface under it nearest the height of the way (terrain, floors, decks),
##     and the mark hangs HOVER m over it.
##   - quiet: nothing in a fight, a lock-on, a conversation, narration, a menu, the loading screen or the staged
##     opening (the waypoint reads `quiet`).
## Load by path: const QuestTrail := preload("res://core/story/quest_trail.gd")

const TrailRoute := preload("res://core/story/trail_route.gd")
const TextDirector := preload("res://ui/text_director.gd")
const Hud := preload("res://ui/hud.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")
const QuestTrack := preload("res://core/story/quest_track.gd")

const LOOK := 150.0                ## a checkpoint is at most this far ahead along the route; the place shows only nearer
const REACH := 20.0                ## this close to a checkpoint (along the way), it jumps on to the next
const CORRIDOR := 5.0              ## the sight-line to it keeps within this of the route on the way
const DENSE := 3.0                 ## the route resampled this finely
const STRAY := 14.0                ## further than this off the route, it is made again
const MOVED := 8.0                 ## the place moved this much: made again
const REBUILD_GAP := 1.5
const NEAR := 11.0                 ## closer than this to the place, no route: the mark is on the place
const HOVER := 2.4                 ## the mark's point over its seat (as high as a place's own mark hangs)

var guide := Vector3.INF           ## where the one mark hangs now (INF: on the place itself)
var left := -1.0                   ## metres along the way to the place (-1: no route; the waypoint measures straight)
var quiet := true                  ## nothing should show now

var _track: QuestTrack
var _ways := TrailRoute.new()
# the route, resampled every DENSE metres (xz, height or NAN, arc length)
var _rp := PackedVector2Array()
var _ry := PackedFloat32Array()
var _rs := PackedFloat32Array()
var _idx := -1                                           ## the dense point nearest the wanderer
var _sp := 0.0                                           ## the wanderer's progress along the route (m)
var _off := 0.0                                          ## and how far off it
var _gi := -1                                            ## the dense point the mark is on (-1: none yet)
var _poll := 0.0
var _gap := 0.0
var _dirty := true
var _goal := Vector3.INF                                 ## the place the route was made for
var _req := 0                                            ## the route being made (async legs answer to it)
var _legs: Array = []                                    ## [{type, a, b, pts}] while the route is being made
var _pending := 0
var _wait := 0.0
var _wants_nav := false                                  ## made without the mesh: made again when it is in


func _ready() -> void:
	name = "QuestTrail"
	add_to_group("quest_trail")


func _find_track() -> void:
	if _track == null or not is_instance_valid(_track):
		_track = get_tree().get_first_node_in_group("quest_track") as QuestTrack
		if _track != null:
			_track.changed.connect(func() -> void: _dirty = true)


func _process(delta: float) -> void:
	_poll -= delta
	_gap -= delta
	if _pending > 0:
		_wait += delta
	if _poll <= 0.0:
		_poll = 0.2
		_tick()


# --- the poll ---------------------------------------------------------------------------------------------------

func _tick() -> void:
	_find_track()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _track == null or p == null:
		_drop_aim()
		return
	quiet = _quiet(p)
	var foot: Vector3 = _track.current().get("foot", Vector3.INF)
	if foot == Vector3.INF:
		_clear()
		_drop_aim()
		return
	var here := p.global_position
	# is the route still the right one?
	var stale := _dirty or _goal == Vector3.INF or Vector2(foot.x - _goal.x, foot.z - _goal.z).length() > MOVED
	if not stale and not _rp.is_empty() and _off > STRAY:
		stale = true
	if not stale and _wants_nav and NavAssist.ready():
		stale = true
	if not stale and _rp.is_empty() and _pending == 0 and Vector2(foot.x - here.x, foot.z - here.z).length() > NEAR + 8.0:
		stale = true                                # it was there; the wanderer has walked off from it
	if _pending > 0 and _wait > 3.0:
		_finish_legs(true)                          # the mesh did not answer: the legs go straight
	if stale and _gap <= 0.0 and _pending == 0:
		_build(here, foot)
	if _rp.is_empty():
		_aim_straight(here, foot)
		return
	_progress(here)
	_aim(here)


## Quiet while anything else has the screen (or the wanderer's mind).
func _quiet(p: Player) -> bool:
	var tree := get_tree()
	if tree.paused or p.lock_target() != null:
		return true
	var zone := tree.current_scene
	if zone != null and zone.get_node_or_null("LoadingScreen") != null:
		return true
	var hud := tree.get_first_node_in_group(&"hud") as Hud
	if hud != null and not hud.staged_in():
		return true
	var td := TextDirector.of(self)
	return td != null and (td.in_combat() or td.narration_or_dialogue())


func _drop_aim() -> void:
	guide = Vector3.INF
	left = -1.0
	_gi = -1


# --- the route --------------------------------------------------------------------------------------------------

func _clear() -> void:
	_req += 1
	_pending = 0
	_legs.clear()
	_rp = PackedVector2Array()
	_ry = PackedFloat32Array()
	_rs = PackedFloat32Array()
	_goal = Vector3.INF
	_idx = -1
	_gi = -1
	_off = 0.0
	_dirty = false


func _build(here: Vector3, foot: Vector3) -> void:
	_clear()
	_gap = REBUILD_GAP
	_goal = foot
	_wants_nav = false
	var from := Vector2(here.x, here.z)
	var to := Vector2(foot.x, foot.z)
	var straight := from.distance_to(to)
	if straight < NEAR:
		return                                      # there: the mark is on the place
	var legs: Array = []
	var r: Dictionary = _ways.route(from, to) if straight > 40.0 else {}
	if not r.is_empty():
		var total := float(r.entry) + float(r.length) + float(r.exit)
		if float(r.entry) > 120.0 or float(r.exit) > 150.0 or total > straight * 2.0 + 80.0:
			r = {}
	if r.is_empty():
		legs.append({"type": "nav", "a": here, "b": foot})
	else:
		var way: PackedVector2Array = r.pts
		if float(r.entry) > 4.0:
			legs.append({"type": "nav" if float(r.entry) > 14.0 else "line", "a": here, "b": Vector3(way[0].x, NAN, way[0].y)})
		var wp := PackedVector3Array()
		for q in way:
			wp.append(Vector3(q.x, NAN, q.y))
		legs.append({"type": "ways", "pts": wp})
		if float(r.exit) > 4.0:
			var last := way[way.size() - 1]
			legs.append({"type": "nav" if float(r.exit) > 14.0 else "line", "a": Vector3(last.x, NAN, last.y), "b": foot})
	_legs = legs
	_pending = 0
	_wait = 0.0
	var req := _req
	for i in legs.size():
		var leg: Dictionary = legs[i]
		if String(leg.type) != "nav":
			continue
		if not NavAssist.ready():
			_wants_nav = true
			leg["type"] = "line"
			continue
		var a: Vector3 = leg.a
		var b: Vector3 = leg.b
		var q := NavigationPathQueryParameters3D.new()
		q.map = NavAssist.map
		q.start_position = Vector3(a.x, RealmLayout.macro_height(a.x, a.z) if is_nan(a.y) else a.y, a.z)
		q.target_position = Vector3(b.x, RealmLayout.macro_height(b.x, b.z) if is_nan(b.y) else b.y, b.z)
		q.path_search_max_polygons = NavAssist.MAX_POLYS
		var res := NavigationPathQueryResult3D.new()
		_pending += 1
		NavigationServer3D.query_path(q, res, func() -> void: _leg_done.call_deferred(req, i, res))
	if _pending == 0:
		_finish_legs(false)


func _leg_done(req: int, i: int, res: NavigationPathQueryResult3D) -> void:
	if req != _req or i >= _legs.size():
		return
	(_legs[i] as Dictionary)["pts"] = res.path
	_pending -= 1
	if _pending <= 0:
		_finish_legs(false)


## Every leg is in: join them and resample.
func _finish_legs(timed_out: bool) -> void:
	_pending = 0
	var pts := PackedVector3Array()
	for leg: Dictionary in _legs:
		var seg := PackedVector3Array()
		match String(leg.type):
			"ways":
				seg = leg.pts
			"nav":
				var np: PackedVector3Array = leg.get("pts", PackedVector3Array()) if not timed_out else PackedVector3Array()
				var b: Vector3 = leg.b
				# the mesh's answer is used when it got there; else the leg goes straight
				if np.size() >= 2 and Vector2(np[np.size() - 1].x - b.x, np[np.size() - 1].z - b.z).length() < 18.0:
					seg = np
				else:
					seg = PackedVector3Array([leg.a, b])
			_:
				seg = PackedVector3Array([leg.a, leg.b])
		for q in seg:
			if pts.is_empty() or Vector2(pts[pts.size() - 1].x - q.x, pts[pts.size() - 1].z - q.z).length() > 0.5:
				pts.append(q)
	_legs.clear()
	_dirty = false
	if pts.size() < 2:
		return
	_resample(pts)
	_idx = -1
	_gi = -1
	_off = 0.0


func _resample(pts: PackedVector3Array) -> void:
	_rp = PackedVector2Array()
	_ry = PackedFloat32Array()
	_rs = PackedFloat32Array()
	var s := 0.0
	_rp.append(Vector2(pts[0].x, pts[0].z))
	_ry.append(pts[0].y)
	_rs.append(0.0)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		var n := maxi(1, int(ceilf(seg / DENSE)))
		for k in range(1, n + 1):
			var t := float(k) / float(n)
			_rp.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t)))
			_ry.append(lerpf(a.y, b.y, t) if not is_nan(a.y) and not is_nan(b.y) else (b.y if k == n else a.y))
			_rs.append(s + seg * t)
		s += seg


## Where the wanderer is along the route: the dense point nearest, looked for near the last one.
func _progress(here: Vector3) -> void:
	var at := Vector2(here.x, here.z)
	var lo := 0
	var hi := _rp.size() - 1
	if _idx >= 0:
		lo = maxi(0, _idx - 8)
		hi = mini(_rp.size() - 1, _idx + 40)
	var best := INF
	var bi := maxi(_idx, 0)
	for i in range(lo, hi + 1):
		var d := at.distance_squared_to(_rp[i])
		if d < best:
			best = d
			bi = i
	_idx = bi
	_sp = _rs[bi]
	_off = sqrt(best)


# --- the aim -------------------------------------------------------------------------------------------------------

## The one mark's point, the checkpoint: the farthest dense point ahead, at most LOOK m along, whose straight sight-line
## from the wanderer keeps within CORRIDOR m of every route point before it (the next bend, or LOOK m down a long
## straight); the place itself only once it is the last straight and within LOOK. It holds until the wanderer comes
## within REACH of it, then jumps on.
func _aim(here: Vector3) -> void:
	var n := _rp.size()
	var last := n - 1
	left = maxf(0.0, _rs[last] - _sp)
	var at := Vector2(here.x, here.z)
	# the checkpoint holds until the wanderer is within REACH of it (or has passed it, or the way to it is no longer in
	# line): Destiny's waypoint stays put and then jumps on; it never creeps ahead step by step
	if _gi > _idx and _gi < n and _rs[_gi] - _sp > REACH and _in_line(at, _gi):
		if _gi >= last:
			guide = Vector3.INF
		return
	var best := mini(_idx + 1, last)
	var j := best + 1
	while j < n and _rs[j] - _sp <= LOOK:
		if not _in_line(at, j):
			break
		best = j
		j += 1
	if best >= last:
		guide = Vector3.INF                         # the last straight: the mark is on the place
		_gi = last
		return
	if best != _gi or guide == Vector3.INF:
		_gi = best
		guide = Vector3(_rp[best].x, _seat(best, here) + HOVER, _rp[best].y)


## Does the straight line from the wanderer to dense point j keep within CORRIDOR of the route on the way?
func _in_line(at: Vector2, j: int) -> bool:
	for k in range(_idx + 1, j):
		if Geometry2D.get_closest_point_to_segment(_rp[k], at, _rp[j]).distance_to(_rp[k]) > CORRIDOR:
			return false
	return true


## No route yet (being made, or none found) and the place far: a checkpoint LOOK m toward it, never the place itself.
func _aim_straight(here: Vector3, foot: Vector3) -> void:
	var d := Vector2(foot.x - here.x, foot.z - here.z)
	if d.length() <= LOOK:
		_drop_aim()
		return
	if guide != Vector3.INF and _gi == -2 and Vector2(guide.x - here.x, guide.z - here.z).length() > REACH:
		return                                      # holds like any checkpoint
	var q := Vector2(here.x, here.z) + d.normalized() * LOOK
	_gi = -2
	left = -1.0
	guide = Vector3(q.x, RealmLayout.macro_height(q.x, q.y) + HOVER, q.y)


## The surface under a route point: of the WORLD hits straight down, the walkable one nearest the height of the way
## (the mesh's own height there, else the wanderer's): terrain in the open, the deck of a bridge, the floor under a roof.
func _seat(i: int, here: Vector3) -> float:
	var k := RealmLayout.macro_height(_rp[i].x, _rp[i].y)
	var ref := _ry[i]
	if is_nan(ref):
		ref = here.y if absf(k - here.y) < 40.0 else k
	var space := get_viewport().world_3d.direct_space_state if is_inside_tree() else null
	if space == null:
		return ref
	var best := NAN
	var best_d := INF
	var first := NAN
	var top := 80.0
	var skip: Array[RID] = []
	for _n in 5:
		var q := PhysicsRayQueryParameters3D.create(Vector3(_rp[i].x, top, _rp[i].y), Vector3(_rp[i].x, -50.0, _rp[i].y), Layers.WORLD)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var y: float = (hit.position as Vector3).y
		if is_nan(first):
			first = y
		if (hit.normal as Vector3).y > 0.55 and absf(y - ref) < best_d:
			best_d = absf(y - ref)
			best = y
		skip.append(hit.rid)
		top = y - 0.05
	if not is_nan(best):
		return best
	return first if not is_nan(first) else ref

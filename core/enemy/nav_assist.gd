class_name NavAssist
extends RefCounted
## The fallback behind flat steering (docs: enemy.gd header). One per agent that needs it, made on first use.
## An agent walks straight at its goal. Only when the straight line is walled (a chest-high ray against
## WORLD, taken at the agent's think rate) or it has made no progress for ~STALL_T, it asks the baked
## navigation mesh (core/world/realm/realm_nav.gd) for a path ONCE, follows its corners, and asks again
## at most every REQUERY seconds. Not a NavigationAgent3D: those tick every physics frame.
## With no mesh (still baking, or --no-realm) every call answers "no help" and flat steering carries on.

const REQUERY := 0.5
const STALL_T := 0.45
const CORNER_R := 0.8            ## a corner this close (planar) is reached
const BEND := 1.5                ## a path bending less than this off the straight line is not worth following
const CLEAR_THINKS := 3          ## consecutive clear thinks before it drops back to the straight line

static var map: RID
static var region_id := 0
static var probe := Vector3.INF          ## a point on the mesh: the map has taken the region once it answers for it
static var _synced := false
## Path queries made, and the time they took (tests and the perf watch read these).
static var queries := 0
static var query_usec := 0
const MAX_POLYS := 100000               ## the server's default search stops after 4096 polygons and returns the best so far: on this mesh (75k polygons) any route over ~100 m ended far short of its goal


## A path over the shared map with the search cap lifted (map_get_path stops at 4096 polygons).
static func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var q := NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = from
	q.target_position = to
	q.path_search_max_polygons = MAX_POLYS
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path

var pts := PackedVector3Array()
var idx := 0
var _since := 9.0                ## seconds since the last query
var _goal := Vector3.INF
var _clear := 0
var _prog_pos := Vector3.INF
var _prog_t := 0.0
var stalled := false


static func ready() -> bool:
	if region_id == 0 or not is_instance_valid(instance_from_id(region_id)):
		_synced = false
		return false
	if not _synced:
		# the server merges a new region over a few frames; before that the map answers (0, 0, 0)
		_synced = probe != Vector3.INF and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 1.0
	return _synced


## Called by RealmNav when a fresh region goes in.
static func set_region(id: int, on_mesh: Vector3) -> void:
	region_id = id
	probe = on_mesh
	_synced = false


## A wall across the chest-high line from -> to on WORLD. Only a face steeper than ~70 degrees counts: a
## steep bump or bank the body can climb is not a wall, and the mesh (max slope 40) would send it the long way.
static func line_blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: RID) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	if exclude.is_valid():
		q.exclude = [exclude]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and absf((hit.normal as Vector3).y) <= 0.35


func active() -> bool:
	return not pts.is_empty()


func reset() -> void:
	pts = PackedVector3Array()
	idx = 0
	_clear = 0
	_prog_pos = Vector3.INF
	_prog_t = 0.0
	stalled = false


## Planar progress watch: call once per think while the agent is trying to move (`moving`), `dt` since the
## last call. Sets `stalled` when it covered less than 30% of `expect` m/s over STALL_T.
func watch(pos: Vector3, dt: float, expect: float, moving: bool) -> void:
	if not moving:
		_prog_pos = Vector3.INF
		_prog_t = 0.0
		stalled = false
		return
	if _prog_pos == Vector3.INF:
		_prog_pos = pos
		_prog_t = 0.0
		return
	_prog_t += dt
	if _prog_t >= STALL_T:
		var moved := Vector2(pos.x - _prog_pos.x, pos.z - _prog_pos.z).length()
		stalled = moved < expect * 0.3 * _prog_t
		_prog_pos = pos
		_prog_t = 0.0


## The next point to walk to on the way to `goal`, or Vector3.INF for "go straight". `blocked` is the
## caller's ray result for the straight line. Call at think rate (dt = 1 / think_hz).
func next_point(pos: Vector3, goal: Vector3, blocked: bool, dt: float) -> Vector3:
	_since += dt
	if not ready():
		if not pts.is_empty():
			reset()
		return Vector3.INF
	if not pts.is_empty() and Vector2(goal.x - _goal.x, goal.z - _goal.z).length() > 8.0:
		reset()                                 # a different errand (chase -> home, a teleport): old corners are void
	var need := blocked or stalled
	if pts.is_empty():
		if not need or _since < REQUERY:
			return Vector3.INF
		_query(pos, goal)
	else:
		if need:
			_clear = 0
			# a moving goal, a stall or a path used up: ask again, but not more than every REQUERY
			if _since >= REQUERY and (stalled or idx >= pts.size() or Vector2(goal.x - _goal.x, goal.z - _goal.z).length() > 1.5):
				_query(pos, goal)
		else:
			_clear += 1
			if _clear >= CLEAR_THINKS:
				pts = PackedVector3Array()
				return Vector3.INF
	stalled = false
	while idx < pts.size():
		if Vector2(pts[idx].x - pos.x, pts[idx].z - pos.z).length() < CORNER_R:
			idx += 1
		else:
			return pts[idx]
	pts = PackedVector3Array()                  # arrived: straight line for the last stretch
	return Vector3.INF


func _query(pos: Vector3, goal: Vector3) -> void:
	_since = 0.0
	_goal = goal
	_clear = 0
	var t := Time.get_ticks_usec()
	var p := NavAssist.path(pos, goal)
	query_usec += Time.get_ticks_usec() - t
	queries += 1
	if p.size() < 2:
		pts = PackedVector3Array()                # unreachable on the mesh: flat steering
		return
	# a path that never leaves the straight line (by more than BEND m) has nothing to teach flat steering,
	# and walking its stale, collinear corners fights the local wall-following round a wall the mesh does
	# not know (a gate, a briar): the mesh only helps where it bends
	var a2 := Vector2(pos.x, pos.z)
	var line := Vector2(goal.x, goal.z) - a2
	var ll := line.length()
	var bend := 0.0
	if ll > 0.1:
		for q in p:
			bend = maxf(bend, absf(line.cross(Vector2(q.x, q.z) - a2)) / ll)
	if bend < BEND:
		pts = PackedVector3Array()
		return
	pts = p
	idx = 1

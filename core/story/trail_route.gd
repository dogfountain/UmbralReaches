extends RefCounted
## The ways as a graph, for the trail (core/story/quest_trail.gd). RealmLayout.PATHS (the road and its tracks, lanes and
## causeways) and the walkway lanes the builders register (WorldLanes.extra_lanes: the Crossing, the henge's way, the
## Keg's path, causeways and bridges) are cut into nodes every STEP metres and joined where one way meets or crosses
## another (within JOIN). One AStar2D over xz, built once per night and again when more lanes were registered; a route
## is one A* over about a thousand nodes (well under a millisecond), asked for only when the trail rebuilds.
## Load by path: const TrailRoute := preload("res://core/story/trail_route.gd")

const RealmLayout := preload("res://core/world/realm/realm_layout.gd")

const STEP := 6.0                  ## a node at least this often along a way
const JOIN := 5.0                  ## two ways this close are one crossing
const ON_REACH := 120.0            ## a way this far from the wanderer may be the one to get on (the trail's entry cap)
const OFF_REACH := 150.0           ## ... and this far from the place, the one to get off (its exit cap)
const OFF_COST := 2.5              ## a metre across country counts as this many along a way (the ways win where they go: at 1.6 the
                                   ## meadow fire's way to the thorn seal went round the Thornwood's hill, not up the henge way)
## Registered lanes that are walked (the others reserve ground: walls, hollow ways' sides).
const LANES := ["rift_crossing", "rift_crossing_turn", "rift_crossing_top", "henge_way", "tavern_path", "poi_causeway", "poi_cw_", "r37w_bridge", "r37w_weir"]

## The graph with the legs onto and off the ways costed apart (_compute_cost is the engine's hook for it).
class Ways extends AStar2D:
	var on_id := -1
	var off_id := -1
	var off_cost := 1.0

	func _compute_cost(a: int, b: int) -> float:
		var d := get_point_position(a).distance_to(get_point_position(b))
		return d * off_cost if a == on_id or b == off_id else d


var _astar := Ways.new()
var _pos := PackedVector2Array()
var _extra := -1


## Build (or rebuild, when lanes were registered since).
func ensure() -> void:
	var n := WorldLanes.extra_lanes.size() + ThornHenge.stair_pts.size() * 1000
	if _extra == n and not _pos.is_empty():
		return
	_extra = n
	_astar.clear()
	_pos = PackedVector2Array()
	var poly_of: Array[int] = []
	var polys: Array = []
	for path: Dictionary in RealmLayout.PATHS:
		polys.append(path.pts)
	for l: Array in WorldLanes.extra_lanes:
		if walked(String(l[0])):
			polys.append(l[1])
	if not ThornHenge.stair_pts.is_empty():           # the pilgrim stair up to the henge (its lane, henge_way, stops at the foot)
		var stair: Array = [RealmLayout.HENGE_STAIR_FOOT]
		for v: Vector3 in ThornHenge.stair_pts:
			stair.append(Vector2(v.x, v.z))
		polys.append(stair)
	for pi in polys.size():
		var pts: Array = polys[pi]
		var prev := -1
		for i in pts.size():
			var b: Vector2 = pts[i]
			if i > 0:
				var a: Vector2 = pts[i - 1]
				var k := int(ceilf(a.distance_to(b) / STEP))
				for j in range(1, k):
					prev = _node(a.lerp(b, float(j) / float(k)), pi, prev, poly_of)
			prev = _node(b, pi, prev, poly_of)
	# joins: ways whose nodes pass close to each other's
	var cell := {}
	for id in _pos.size():
		var c := Vector2i(floori(_pos[id].x / JOIN), floori(_pos[id].y / JOIN))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for o: int in cell.get(Vector2i(c.x + dx, c.y + dz), []):
					if poly_of[o] != poly_of[id] and _pos[o].distance_to(_pos[id]) <= JOIN and not _astar.are_points_connected(id, o):
						_astar.connect_points(id, o)
		var arr: Array = cell.get(c, [])
		arr.append(id)
		cell[c] = arr


## Is the registered lane `n` walked (one of LANES), not ground held back for a wall?
static func walked(n: String) -> bool:
	for p: String in LANES:
		if n == p or (p.ends_with("_") and n.begins_with(p)):
			return true
	return false


func _node(p: Vector2, poly: int, prev: int, poly_of: Array[int]) -> int:
	var id := _pos.size()
	_pos.append(p)
	poly_of.append(poly)
	_astar.add_point(id, p)
	if prev >= 0:
		_astar.connect_points(prev, id)
	return id


func is_empty() -> bool:
	return _pos.is_empty()


## The way from `from` to `to`: one A* from the wanderer to the place, where every node of the ways within ON_REACH of
## the wanderer is a way on and every node within OFF_REACH of the place a way off, and those legs across country cost
## OFF_COST a metre (so the search gets on at the right node of the right way, not the nearest node of whichever way:
## the network is in pieces, and the nearest piece to the meadow fire is a lane that goes nowhere):
## {pts: PackedVector2Array, entry: metres from `from` to the way, exit: metres from the way to `to`, length: along it};
## {} when there is no way between them.
func route(from: Vector2, to: Vector2) -> Dictionary:
	ensure()
	if _pos.is_empty():
		return {}
	var s := _astar.get_available_point_id()
	_astar.add_point(s, from)
	var e := _astar.get_available_point_id()
	_astar.add_point(e, to)
	_astar.on_id = s
	_astar.off_id = e
	_astar.off_cost = OFF_COST
	var ons := 0
	var offs := 0
	for id in _pos.size():
		if _pos[id].distance_to(from) <= ON_REACH:
			_astar.connect_points(s, id, false)
			ons += 1
		if _pos[id].distance_to(to) <= OFF_REACH:
			_astar.connect_points(id, e, false)
			offs += 1
	var ids := _astar.get_id_path(s, e) if ons > 0 and offs > 0 else PackedInt64Array()
	_astar.remove_point(s)
	_astar.remove_point(e)
	if ids.size() < 3:
		return {}
	var pts := PackedVector2Array()
	var length := 0.0
	for k in range(1, ids.size() - 1):
		var q := _pos[ids[k]]
		if not pts.is_empty():
			length += pts[pts.size() - 1].distance_to(q)
		pts.append(q)
	return {"pts": pts, "entry": from.distance_to(pts[0]), "exit": pts[pts.size() - 1].distance_to(to), "length": length}

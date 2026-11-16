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
## Registered lanes that are walked (the others reserve ground: walls, hollow ways' sides).
const LANES := ["rift_crossing", "rift_crossing_turn", "rift_crossing_top", "henge_way", "tavern_path", "poi_causeway", "poi_cw_", "r37w_bridge", "r37w_weir"]

var _astar := AStar2D.new()
var _pos := PackedVector2Array()
var _extra := -1


## Build (or rebuild, when lanes were registered since).
func ensure() -> void:
	var n := WorldLanes.extra_lanes.size()
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
		if _walked(String(l[0])):
			polys.append(l[1])
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


func _walked(n: String) -> bool:
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


## The way's nodes from the one nearest `from` to the one nearest `to`:
## {pts: PackedVector2Array, entry: metres from `from` to the way, exit: metres from the way to `to`, length: along it};
## {} when there is no way between them.
func route(from: Vector2, to: Vector2) -> Dictionary:
	ensure()
	if _pos.is_empty():
		return {}
	var a := _astar.get_closest_point(from)
	var b := _astar.get_closest_point(to)
	if a < 0 or b < 0:
		return {}
	var ids := _astar.get_id_path(a, b)
	if ids.is_empty():
		return {}
	var pts := PackedVector2Array()
	var length := 0.0
	for id in ids:
		if not pts.is_empty():
			length += pts[pts.size() - 1].distance_to(_pos[id])
		pts.append(_pos[id])
	return {"pts": pts, "entry": from.distance_to(_pos[a]), "exit": _pos[b].distance_to(to), "length": length}

extends RefCounted
## Hearthward's walking network (village system; no class_name). Named nodes (xz) joined by edges,
## checked against the real world once the Realm is built:
##   - every node stands on a floor (first hit going down from 1.9 m over the terrain: plinths and
##     floors count) and has a 0.6 m clear column above it from knee to head height (a node that
##     fails is nudged up to 1.4 m to the nearest clear spot);
##   - every edge is sampled each 0.35 m: the same clear column (walls, fences, barrels, trunks, the
##     brazier block it), no step over 0.32 m between samples, no water;
## so a villager walking an edge never passes through a building or a prop. Paths are A* over the
## kept edges; each comes back as world points with their floor heights. Load by path:
##   const VillageNav := preload("res://core/life/village/village_nav.gd")

const STEP := 0.35
const CLEAR_R := 0.26              ## half width of the clear column (a body is ~0.5 m across)
const CLEAR_LO := 0.32             ## column from this over the floor ...
const CLEAR_HI := 1.6              ## ... to this
const MAX_STEP := 0.32

var nodes := {}                    ## id -> Vector3 (validated, y = floor)
var want := {}                     ## id -> Vector2 (as authored)
var edges := {}                    ## id -> {other id: length}
var dropped: Array[String] = []    ## "a-b: why" for the report
var moved: Array[String] = []
var decks: Array = []  ## {rect: Rect2 (xz), y: deck top}: a bridge over low ground; the ground ray would start under it
var _space: PhysicsDirectSpaceState3D
var _q := PhysicsShapeQueryParameters3D.new()
var _exclude: Array[RID] = []
var _astar := AStar3D.new()
var _ids := {}                     ## id -> astar index


func _init() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(CLEAR_R * 2.0, CLEAR_HI - CLEAR_LO, CLEAR_R * 2.0)
	_q.shape = box
	_q.collision_mask = Layers.WORLD | Layers.PROPS


## Floor height at xz (first solid going down from 1.9 m over the terrain), or NAN.
func floor_at(x: float, z: float) -> float:
	var gy := RealmLayout.ground(_space, x, z)
	var ex := _exclude
	for d in decks:
		if (d.rect as Rect2).has_point(Vector2(x, z)):
			var dh := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, float(d.y) + 1.0, z), Vector3(x, float(d.y) - 0.6, z), Layers.WORLD, ex))
			if dh:
				return (dh.position as Vector3).y
	for i in 3:
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, gy + 1.9, z), Vector3(x, gy - 1.5, z), Layers.WORLD, ex))
		if not hit:
			return gy
		# r34: a foe standing on the spot is not floor (the outposts are out where foes walk)
		var c := hit.collider as Node
		if c and _mobile(c):
			ex = ex.duplicate()
			ex.append(hit.rid)
			continue
		return (hit.position as Vector3).y
	return gy


## A foe's body: never part of the floor or a wall for the network (the wanderer still is: people
## step round you, not through you).
static func _mobile(c: Node) -> bool:
	return c.is_in_group(Groups.ENEMY) or (c.get_parent() != null and c.get_parent().is_in_group(Groups.ENEMY))


var blocker := ""                  ## what the last failed clear() found (the report names it)


## The clear column at a floor point: true when nothing but terrain is in it.
func clear(p: Vector3) -> bool:
	_q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * ((CLEAR_LO + CLEAR_HI) * 0.5))
	_q.exclude = _exclude
	for h in _space.intersect_shape(_q, 6):
		var c := h.collider as Node
		if c == null:
			continue
		if String(c.name).begins_with("Terrain") or _mobile(c):
			continue
		blocker = String(c.get_path())
		return false
	return true


## clear() that also ignores `ex` (a walker's own body).
func clear_ex(p: Vector3, ex: Array[RID]) -> bool:
	var keep := _exclude
	var both: Array[RID] = keep.duplicate()
	both.append_array(ex)
	_exclude = both
	var r := clear(p)
	_exclude = keep
	return r


func ok_at(x: float, z: float) -> Vector3:
	var y := floor_at(x, z)
	var p := Vector3(x, y, z)
	if _wet(x, z, y) or not clear(p):
		return Vector3.INF
	return p


static func _water_y() -> float:
	return -0.85


## Water only lies in the fen (RealmLand's pools); elsewhere low floors (the Keg's porch) are dry.
static func _wet(x: float, z: float, y: float) -> bool:
	var wl := RealmLayout.water_level_at(x, z)          # the Sorrow, the lake and the Well's pit stand at their own levels
	if not is_nan(wl):
		return y < wl
	return y < _water_y() and RealmLayout.biome_at(x, z) == "fen"


func use_space(space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> void:
	_space = space
	_exclude = exclude


## Build from {id: Vector2} and [[a, b], ...]. `exclude` = bodies the checks ignore (villagers).
func build(space: PhysicsDirectSpaceState3D, node_xz: Dictionary, edge_list: Array, exclude: Array[RID] = []) -> void:
	_space = space
	_exclude = exclude
	nodes.clear()
	edges.clear()
	dropped.clear()
	moved.clear()
	want = node_xz.duplicate()
	for id: String in node_xz:
		var xz: Vector2 = node_xz[id]
		var p := ok_at(xz.x, xz.y)
		if p == Vector3.INF:
			p = _nudge(xz)
			if p != Vector3.INF:
				moved.append("%s %.1f,%.1f -> %.1f,%.1f" % [id, xz.x, xz.y, p.x, p.z])
		if p == Vector3.INF:
			dropped.append("%s: no clear floor" % id)
			continue
		nodes[id] = p
	for e: Array in edge_list:
		var a := String(e[0])
		var b := String(e[1])
		if not nodes.has(a) or not nodes.has(b):
			dropped.append("%s-%s: missing node" % [a, b])
			continue
		var why := _edge_ok(nodes[a], nodes[b])
		if why != "":
			dropped.append("%s-%s: %s" % [a, b, why])
			continue
		var l := (nodes[a] as Vector3).distance_to(nodes[b])
		if not edges.has(a):
			edges[a] = {}
		if not edges.has(b):
			edges[b] = {}
		edges[a][b] = l
		edges[b][a] = l
	_astar.clear()
	_ids.clear()
	var i := 0
	for id: String in nodes:
		_ids[id] = i
		_astar.add_point(i, nodes[id])
		i += 1
	for a: String in edges:
		for b: String in edges[a]:
			if not _astar.are_points_connected(_ids[a], _ids[b]):
				_astar.connect_points(_ids[a], _ids[b])


func _nudge(xz: Vector2) -> Vector3:
	for r: float in [0.35, 0.7, 1.05, 1.4]:
		for i in 12:
			var a := TAU * float(i) / 12.0
			var p := ok_at(xz.x + cos(a) * r, xz.y + sin(a) * r)
			if p != Vector3.INF:
				return p
	return Vector3.INF


## "" when a straight walk from a to b is clear, else why not.
func _edge_ok(a: Vector3, b: Vector3) -> String:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var n := maxi(1, ceili(flat.length() / STEP))
	var prev := a.y
	for i in range(1, n):
		var t := float(i) / float(n)
		var x := lerpf(a.x, b.x, t)
		var z := lerpf(a.z, b.z, t)
		var y := floor_at(x, z)
		if absf(y - prev) > MAX_STEP:
			return "step %.2f at %.1f,%.1f" % [y - prev, x, z]
		if _wet(x, z, y):
			return "water at %.1f,%.1f" % [x, z]
		if not clear(Vector3(x, y, z)):
			return "blocked at %.1f,%.1f by %s" % [x, z, blocker]
		prev = y
	if absf(b.y - prev) > MAX_STEP:
		return "step at end"
	return ""


func has(id: String) -> bool:
	return nodes.has(id)


func at(id: String) -> Vector3:
	return nodes.get(id, Vector3.INF)


## Nearest node to a world point (xz).
func nearest(p: Vector3) -> String:
	var best := ""
	var bd := INF
	for id: String in nodes:
		var q: Vector3 = nodes[id]
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
		if d < bd and edges.has(id):
			bd = d
			best = id
	return best


## Node ids from a to b (inclusive), [] if unreachable.
func route(a: String, b: String) -> Array[String]:
	var out: Array[String] = []
	if not _ids.has(a) or not _ids.has(b):
		return out
	if a == b:
		out.append(a)
		return out
	var inv := {}
	for id: String in _ids:
		inv[_ids[id]] = id
	for pi in _astar.get_id_path(_ids[a], _ids[b]):
		out.append(String(inv[pi]))
	return out


## World points along the route, resampled every STEP with their floor heights (smoothed).
func path(a: String, b: String) -> PackedVector3Array:
	var ids := route(a, b)
	var pts := PackedVector3Array()
	if ids.is_empty():
		return pts
	pts.append(nodes[ids[0]])
	for i in range(1, ids.size()):
		var p0: Vector3 = nodes[ids[i - 1]]
		var p1: Vector3 = nodes[ids[i]]
		var n := maxi(1, ceili(Vector2(p1.x - p0.x, p1.z - p0.z).length() / (STEP * 2.0)))
		for j in range(1, n + 1):
			var t := float(j) / float(n)
			var x := lerpf(p0.x, p1.x, t)
			var z := lerpf(p0.z, p1.z, t)
			pts.append(Vector3(x, floor_at(x, z) if j < n else p1.y, z))
	return pts


## Every node reachable from `from` (for the test's connectivity check).
func reachable(from: String) -> Dictionary:
	var seen := {from: true}
	var todo: Array[String] = [from]
	while not todo.is_empty():
		var a: String = todo.pop_back()
		for b: String in edges.get(a, {}):
			if not seen.has(b):
				seen[b] = true
				todo.append(b)
	return seen

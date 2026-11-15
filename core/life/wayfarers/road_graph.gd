extends RefCounted
## The Realm's ways as one network (wayfarers.gd). Built from RealmLayout.PATHS: every vertex a node, every segment
## an edge; vertices within MERGE of each other are one node, and a way's end that meets another way between its
## vertices splits that segment there (a T-junction). Edges near a camp are marked unsafe. Then the network is
## compressed: only junctions, ends and the stops asked for (havens) stay nodes, and each run between them is one
## edge carrying its own polyline, so a route is a Dijkstra over a hundred nodes, not fifteen hundred.
## Load by path: const RoadGraph := preload("res://core/life/wayfarers/road_graph.gd")

const MERGE := 1.2               ## vertices this close are one node
const TEE := 2.5                 ## a way's end this close to another way's segment joins it there

var pts := PackedVector2Array()   ## full node -> position
var adj: Array = []               ## full node -> Array of [other node, length]
var unsafe := {}                  ## Vector2i(a, b) (a < b) -> true
var _cells := {}                  ## Vector2i cell -> PackedInt32Array of nodes
## the compressed network
var cid := {}                     ## full node -> compressed index
var cnode := PackedInt32Array()   ## compressed index -> full node
var cadj: Array = []              ## compressed index -> Array of {to, len, poly (PackedVector2Array, from -> to), safe}


func build(paths: Array) -> void:
	var ends: Array[int] = []
	for path: Dictionary in paths:
		var prev := -1
		var pl: Array = path.pts
		for k in pl.size():
			var i := _node(pl[k] as Vector2)
			if prev >= 0 and prev != i:
				_link(prev, i)
			prev = i
			if k == 0 or k == pl.size() - 1:
				ends.append(i)
	for e in ends:
		if (adj[e] as Array).size() > 1:
			continue
		var p := pts[e]
		var best := INF
		var ba := -1
		var bb := -1
		for a in pts.size():
			if absf(pts[a].x - p.x) > 80.0 or absf(pts[a].y - p.y) > 80.0:
				continue
			for l: Array in adj[a]:
				var b: int = l[0]
				if b <= a or a == e or b == e:
					continue
				var d := Geometry2D.get_closest_point_to_segment(p, pts[a], pts[b]).distance_to(p)
				if d < best:
					best = d
					ba = a
					bb = b
		if ba < 0 or best > TEE:
			continue
		var q2 := Geometry2D.get_closest_point_to_segment(p, pts[ba], pts[bb])
		_unlink(ba, bb)
		var n := pts.size()
		pts.append(q2)
		adj.append([])
		_link(ba, n)
		_link(n, bb)
		_link(n, e)


func _node(p: Vector2) -> int:
	var c := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cc := c + Vector2i(dx, dz)
			if not _cells.has(cc):
				continue
			for i: int in _cells[cc]:
				if pts[i].distance_to(p) < MERGE:
					return i
	var n := pts.size()
	pts.append(p)
	adj.append([])
	if not _cells.has(c):
		_cells[c] = PackedInt32Array()
	(_cells[c] as PackedInt32Array).append(n)
	return n


func _link(a: int, b: int) -> void:
	for l: Array in adj[a]:
		if int(l[0]) == b:
			return
	var d := pts[a].distance_to(pts[b])
	(adj[a] as Array).append([b, d])
	(adj[b] as Array).append([a, d])


func _unlink(a: int, b: int) -> void:
	adj[a] = (adj[a] as Array).filter(func(l: Array) -> bool: return int(l[0]) != b)
	adj[b] = (adj[b] as Array).filter(func(l: Array) -> bool: return int(l[0]) != a)


static func _key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## Mark every edge that passes within `r` of any of `spots` unsafe (before compress()).
func mark_unsafe(spots: Array[Vector2], r: float) -> void:
	for a in pts.size():
		for l: Array in adj[a]:
			var b: int = l[0]
			if b <= a:
				continue
			var mid := (pts[a] + pts[b]) * 0.5
			for s in spots:
				if absf(s.x - mid.x) > r + 40.0 or absf(s.y - mid.y) > r + 40.0:
					continue
				if Geometry2D.get_closest_point_to_segment(s, pts[a], pts[b]).distance_to(s) < r:
					unsafe[_key(a, b)] = true
					break


## The full node nearest p (within max_d), or -1.
func nearest(p: Vector2, max_d := INF) -> int:
	var best := -1
	var bd := max_d
	for i in pts.size():
		if (adj[i] as Array).is_empty():
			continue
		var d := pts[i].distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Keep only junctions, ends and `stops` (full nodes) as nodes; every run between two of them is one edge.
func compress(stops: Array[int]) -> void:
	var keep := {}
	for i in pts.size():
		var deg := (adj[i] as Array).size()
		if deg != 2 and deg > 0:
			keep[i] = true
	for s in stops:
		if s >= 0:
			keep[s] = true
	cid.clear()
	cnode = PackedInt32Array()
	for i: int in keep:
		cid[i] = cnode.size()
		cnode.append(i)
	cadj.resize(cnode.size())
	for c in cnode.size():
		cadj[c] = []
	for c in cnode.size():
		var a := cnode[c]
		for l: Array in adj[a]:
			# walk the run from a through degree-2 nodes until the next kept node
			var poly := PackedVector2Array([pts[a]])
			var prev := a
			var cur: int = l[0]
			var length := float(l[1])
			var safe := not unsafe.has(_key(a, cur))
			var guard := 0
			while not keep.has(cur) and guard < 5000:
				guard += 1
				poly.append(pts[cur])
				var nxt := -1
				for l2: Array in adj[cur]:
					if int(l2[0]) != prev:
						nxt = int(l2[0])
						length += float(l2[1])
						break
				if nxt < 0:
					break
				if unsafe.has(_key(cur, nxt)):
					safe = false
				prev = cur
				cur = nxt
			if not keep.has(cur):
				continue
			poly.append(pts[cur])
			(cadj[c] as Array).append({"to": int(cid[cur]), "len": length, "poly": poly, "safe": safe})


## Shortest safe route between two kept full nodes: [edges] ({to, len, poly, safe} in order), or [] if none.
func route(a_full: int, b_full: int, allow_unsafe := false) -> Array:
	if not cid.has(a_full) or not cid.has(b_full):
		return []
	var a: int = cid[a_full]
	var b: int = cid[b_full]
	if a == b:
		return []
	var n := cnode.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var via: Array = []
	via.resize(n)
	var done := PackedByteArray()
	done.resize(n)
	dist[a] = 0.0
	while true:
		var u := -1
		var ud := INF
		for k in n:
			if done[k] == 0 and dist[k] < ud:
				ud = dist[k]
				u = k
		if u < 0 or u == b:
			break
		done[u] = 1
		for e: Dictionary in cadj[u]:
			if not bool(e.safe) and not allow_unsafe:
				continue
			var v: int = e.to
			var nd := ud + float(e.len)
			if nd < dist[v]:
				dist[v] = nd
				via[v] = [u, e]
	if dist[b] == INF:
		return []
	var out: Array = []
	var c := b
	while c != a:
		var w: Array = via[c]
		out.push_front(w[1])
		c = int(w[0])
	return out


## Safe route lengths from a kept full node to every kept node (compressed index -> metres).
func reach(a_full: int) -> PackedFloat32Array:
	var n := cnode.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	if not cid.has(a_full):
		return dist
	var done := PackedByteArray()
	done.resize(n)
	dist[int(cid[a_full])] = 0.0
	while true:
		var u := -1
		var ud := INF
		for k in n:
			if done[k] == 0 and dist[k] < ud:
				ud = dist[k]
				u = k
		if u < 0:
			break
		done[u] = 1
		for e: Dictionary in cadj[u]:
			if bool(e.safe) and ud + float(e.len) < dist[int(e.to)]:
				dist[int(e.to)] = ud + float(e.len)
	return dist


## A route (from route()) as one dense polyline (a point every `step` m), from `start` to `finish` (off the network:
## where the walker stands, where it is going).
static func polyline(edges: Array, start: Vector2, finish: Vector2, step := 1.5) -> PackedVector2Array:
	var key := PackedVector2Array([start])
	for e: Dictionary in edges:
		for q: Vector2 in e.poly:
			if key[key.size() - 1].distance_to(q) > 0.3:
				key.append(q)
	if key[key.size() - 1].distance_to(finish) > 0.3:
		key.append(finish)
	var out := PackedVector2Array([key[0]])
	for k in key.size() - 1:
		var a := key[k]
		var b := key[k + 1]
		var m := maxi(1, ceili(a.distance_to(b) / step))
		for j in range(1, m + 1):
			out.append(a.lerp(b, float(j) / float(m)))
	return out

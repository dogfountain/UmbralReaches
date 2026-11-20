class_name WorldLanes
extends RefCounted
## The walkways of the whole world in one table: the routes the player actually travels, as XZ
## polylines with a half-width. Every runtime scatterer (night dressing, twigs, rocks, etc.) asks
## `intrudes()` before it keeps a prop, so set dressing can never again end up across a stair,
## a bridge or a doorway. zz/lanes.gd sweeps a capsule along the same table to audit the result.

const HEADROOM := 2.2        ## a prop intrudes when it occupies [floor + 0.06, floor + HEADROOM]
const STEP := 0.5

static var _floor: Dictionary = {}      # Vector2i(sample * 2) -> floor y (only cached on a hit)
## Runtime registry, filled by builders before anything is scattered (placement order: landmark
## builds and registers -> terrain stamp cuts its site -> props/grass avoid it).
## site = {name, rect (Rect2 in XZ), floor_y, cut_y}
static var sites: Array[Dictionary] = []
static var extra_lanes: Array = []      # same shape as LANES
## Doorways that must stay clear: {name, at (threshold centre, floor), out (unit, horizontal), w, h}
static var portals: Array[Dictionary] = []


## A site with a floor of its own: it levels the ground (a terrace), or cuts it below its floor (a
## building). Open-air landmarks (waymarks, graves, low walls) stand on the land as it is.
static func is_floor_site(st: Dictionary) -> bool:
	if st.has("seg"):
		return false
	return st.get("level", false) or float(st.cut_y) < float(st.floor_y) - 0.01


static func register_portal(n: String, at: Vector3, out: Vector3, w := Metrics.DOOR.x, h := Metrics.DOOR.y) -> void:
	for p in portals:
		if p.name == n:
			return
	portals.append({"name": n, "at": at, "out": Vector3(out.x, 0, out.z).normalized(), "w": w, "h": h})


## The 3 m approach box in front of a portal (world transform + half extents) for clearance tests.
static func portal_box(p: Dictionary, depth := 3.0) -> Array:
	var out: Vector3 = p.out
	var side := out.cross(Vector3.UP).normalized()
	var c: Vector3 = (p.at as Vector3) + out * (depth * 0.5 + 0.15) + Vector3.UP * (float(p.h) * 0.5 + 0.2)
	return [Transform3D(Basis(side, Vector3.UP, out), c), Vector3(float(p.w) * 0.5 + 0.2, float(p.h) * 0.5 - 0.15, depth * 0.5)]


static func register_site(n: String, rect: Rect2, floor_y: float, cut_y := NAN, hard := false) -> void:
	for s in sites:
		if s.name == n:
			return
	if rect.size.x < 0.0 or rect.size.y < 0.0:
		push_warning("WorldLanes: site %s registered with a negative size %s (flipped)" % [n, rect])
		rect = rect.abs()            # a negative rect made every later intersects() an engine error
	sites.append({"name": n, "rect": rect, "floor_y": floor_y, "cut_y": floor_y - 0.3 if is_nan(cut_y) else cut_y, "hard": hard})


## A levelled round terrace: the ground inside is cut AND filled to `y` (TerrainStamp).
static func register_terrace(n: String, centre: Vector2, r: float, y: float) -> void:
	for s in sites:
		if s.name == n:
			return
	sites.append({"name": n, "rect": Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), "floor_y": y, "cut_y": y, "circle": Vector3(centre.x, centre.y, r), "level": true})


## r34 layout: does a site's real footprint (a round terrace's or zone's circle, else its rect) reach
## into rect `r` grown by `pad`? The r34 raid floors are 60 m circles: their bounding boxes claimed
## 800 m2 of hillside each beyond the floor, which emptied the henge hill's corners of trees and stones.
static func site_hits_rect(st: Dictionary, r: Rect2, pad := 0.0) -> bool:
	var sr: Rect2 = st.rect
	if not sr.grow(pad).intersects(r):
		return false
	if not st.has("circle"):
		return true
	var c: Vector3 = st.circle
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_to(Vector2(c.x, c.y)) < c.z + pad


## r34 layout: a round reserved floor that only cuts (a raid room built over lower ground, the summit's):
## the ground inside is cut down to `cut_y`, never filled; everything else keeps out of the circle.
## `owners`: names of the builders whose things already stand in it (the audit lets them be).
static func register_zone(n: String, centre: Vector2, r: float, floor_y: float, cut_y: float, owners: Array = []) -> void:
	for s in sites:
		if s.name == n:
			return
	sites.append({"name": n, "rect": Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), "floor_y": floor_y, "cut_y": cut_y, "circle": Vector3(centre.x, centre.y, r), "owners": owners})


## A built stair corridor a -> b (floors at their y), `half_w` wide: ground above the flight is
## cut away under it; props and grass keep off it.
static func register_flight(n: String, a: Vector3, b: Vector3, half_w: float) -> void:
	for s in sites:
		if s.name == n:
			return
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2(half_w, half_w)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2(half_w, half_w)
	sites.append({"name": n, "rect": Rect2(lo, hi - lo), "floor_y": minf(a.y, b.y), "cut_y": minf(a.y, b.y), "seg": [a, b, half_w]})


## Inside a site's real shape (rect, circle or flight), grown by margin. Returns the floor there
## (NAN when outside).
static func site_floor(s: Dictionary, p: Vector2, margin := 0.0) -> float:
	if s.has("circle"):
		var c: Vector3 = s.circle
		return float(s.floor_y) if p.distance_to(Vector2(c.x, c.y)) <= c.z + margin else NAN
	if s.has("seg"):
		var a: Vector3 = s.seg[0]
		var b: Vector3 = s.seg[1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		var t := clampf((p - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a2 + ab * t) > float(s.seg[2]) + margin:
			return NAN
		return lerpf(a.y, b.y, t)
	return float(s.floor_y) if (s.rect as Rect2).grow(margin).has_point(p) else NAN


## Past a flight's end (before its foot or beyond its head): the stamp's round cap round each end. TerrainStamp cuts the cap flush with
## the floor, not 0.35 under it like the flight itself, so the ground meeting a stair's top or foot is level with it.
static func past_end(s: Dictionary, p: Vector2) -> bool:
	if not s.has("seg"):
		return false
	var a: Vector3 = s.seg[0]
	var b: Vector3 = s.seg[1]
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var t := (p - a2).dot(ab) / maxf(ab.length_squared(), 0.0001)
	return t < 0.0 or t > 1.0


static func register_lane(n: String, pts: Array, half_w: float) -> void:
	for l: Array in extra_lanes:
		if l[0] == n:
			return
	extra_lanes.append([n, pts, half_w])


## Site whose footprint (grown by `margin`) covers XZ point p, or {} (the first such in `sites`).
static func site_at(p: Vector2, margin := 0.0) -> Dictionary:
	if margin > _SITE_REACH:
		for s in sites:
			if not is_nan(site_floor(s, p, margin)):
				return s
		return {}
	_index_sites()
	var ids: Variant = _site_cells.get(Vector2i(floori(p.x / _SITE_CELL), floori(p.y / _SITE_CELL)))
	if ids == null:
		return {}
	for i: int in ids as PackedInt32Array:
		if not is_nan(site_floor(sites[i], p, margin)):
			return sites[i]
	return {}


## site_at's index: the sites whose rect grown by _SITE_REACH meets each _SITE_CELL square, in list order (a scan
## of every site was a few thousand checks a call, and the build makes tens of thousands of calls). `sites` only
## ever grows or is cleared: new ones are added as they come; a list that shrank or starts with another site
## (cleared and filled again) is indexed afresh.
const _SITE_CELL := 16.0
const _SITE_REACH := 8.0
static var _site_cells := {}             ## Vector2i -> PackedInt32Array of indices into sites
static var _site_n := 0
static var _site_first: Dictionary = {}


static func _index_sites() -> void:
	if sites.size() < _site_n or (_site_n > 0 and not is_same(sites[0], _site_first)):
		_site_cells.clear()
		_site_n = 0
	while _site_n < sites.size():
		var s: Dictionary = sites[_site_n]
		if _site_n == 0:
			_site_first = s
		var r := (s.get("rect", Rect2()) as Rect2).grow(_SITE_REACH)
		for cz in range(floori(r.position.y / _SITE_CELL), floori(r.end.y / _SITE_CELL) + 1):
			for cx in range(floori(r.position.x / _SITE_CELL), floori(r.end.x / _SITE_CELL) + 1):
				var k := Vector2i(cx, cz)
				var ids: PackedInt32Array = _site_cells.get(k, PackedInt32Array())
				ids.append(_site_n)
				_site_cells[k] = ids
		_site_n += 1


static func _on_runtime_lane(p: Vector2, reach: float) -> bool:
	for l: Array in extra_lanes:
		var pts: Array = l[1]
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(l[2]) + reach:
				return true
	return false


## Mark `node` and every MultiMesh under it as placed on purpose: cull_scatter keeps them even inside a site.
## Returns how many MultiMeshes were marked. Never call it on the flora: the flora is what the cull is for.
static func own(node: Node) -> int:
	node.set_meta(&"site_owned", true)
	var n := 1 if node is MultiMeshInstance3D else 0
	for mmi in node.find_children("*", "MultiMeshInstance3D", true, false):
		mmi.set_meta(&"site_owned", true)
		n += 1
	return n


## Drop scattered MultiMesh instances (grass, ferns, pebbles, caps, twigs) that stand inside a
## registered site: nothing grows through a floor or a wall.
static func cull_scatter(root: Node, margin := 0.35) -> int:
	if sites.is_empty():
		return 0
	# every site's and runtime-lane segment's XZ bounds, once: per MultiMesh, a coarse grid then
	# lists the few that can touch each cell, and each instance is tested exactly (site_floor, the
	# lane distance) against those only (it was every site and every lane segment per instance)
	var site_b: Array[Rect2] = []
	for st in sites:
		site_b.append(_site_bounds(st))
	var segs: Array = []                     # [a, b, half_w] in extra_lanes order
	var seg_b: Array[Rect2] = []
	for l: Array in extra_lanes:
		var pts: Array = l[1]
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			segs.append([a, b, float(l[2])])
			seg_b.append(Rect2(a, Vector2.ZERO).expand(b).grow(float(l[2])))
	var removed := 0
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.instance_count == 0 or mmi.has_meta("site_owned") or mmi.has_meta(&"live_pool"):     # (a runtime pool: its slots are its own)
			continue
		# one buffer read and one write per MultiMesh: per-instance getters fetch the whole GPU buffer
		# SeatProps leaves its CPU copy: a same-frame read of `buffer` can return the GPU's stale data
		var buf: PackedFloat32Array = mm.get_meta("cpu_buffer") if mm.has_meta("cpu_buffer") else mm.buffer
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var n := mm.instance_count
		if buf.size() < n * stride:
			continue
		var xf := mmi.global_transform
		var ext := 0.0
		if mm.mesh:
			var mb := mm.mesh.get_aabb()
			ext = maxf(maxf(absf(mb.position.x), absf(mb.end.x)), maxf(absf(mb.position.z), absf(mb.end.z)))
		var pos := PackedVector2Array()
		pos.resize(n)
		var reach := PackedFloat64Array()
		reach.resize(n)
		var box := Rect2()
		var max_reach := 0.0
		for i in n:
			var o := i * stride
			var w := xf * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var sc := Vector3(buf[o], buf[o + 4], buf[o + 8]).length()          # basis x column length
			var r := margin + ext * sc                                         # the plant's spread, not its stem
			pos[i] = Vector2(w.x, w.z)
			reach[i] = r
			max_reach = maxf(max_reach, r)
			box = Rect2(pos[i], Vector2.ZERO) if i == 0 else box.expand(pos[i])
		# candidates per cell: anything whose bounds, grown by the largest reach, overlap the cell
		var cell := maxf(8.0, maxf(box.size.x, box.size.y) / 64.0)
		var g0 := box.position
		var gw := int(box.size.x / cell) + 1
		var gh := int(box.size.y / cell) + 1
		var grid := {}                       # cell index -> [site indices, seg indices]
		var near_any := false
		for kind in 2:
			var bounds: Array[Rect2] = site_b if kind == 0 else seg_b
			for j in bounds.size():
				var bb := bounds[j].grow(max_reach + 0.01)
				if not bb.intersects(box, true):
					continue
				near_any = true
				var x0 := clampi(int(floorf((bb.position.x - g0.x) / cell)), 0, gw - 1)
				var x1 := clampi(int(floorf((bb.end.x - g0.x) / cell)), 0, gw - 1)
				var y0 := clampi(int(floorf((bb.position.y - g0.y) / cell)), 0, gh - 1)
				var y1 := clampi(int(floorf((bb.end.y - g0.y) / cell)), 0, gh - 1)
				for cy in range(y0, y1 + 1):
					for cx in range(x0, x1 + 1):
						var key := cy * gw + cx
						if not grid.has(key):
							grid[key] = [[], []]
						(grid[key][kind] as Array).append(j)
		if not near_any:
			continue
		var out := PackedFloat32Array()
		var kept := 0
		for i in n:
			var p2 := pos[i]
			var cx := clampi(int(floorf((p2.x - g0.x) / cell)), 0, gw - 1)
			var cy := clampi(int(floorf((p2.y - g0.y) / cell)), 0, gh - 1)
			var cand: Variant = grid.get(cy * gw + cx)
			if cand == null or not _hits(cand as Array, segs, p2, reach[i]):
				out.append_array(buf.slice(i * stride, i * stride + stride))
				kept += 1
		if kept == n:
			continue
		removed += n - kept
		mm.instance_count = 0
		mm.instance_count = kept
		if kept > 0:
			mm.buffer = out
		if mm.has_meta("cpu_buffer"):
			mm.set_meta("cpu_buffer", out)
	return removed


## XZ bounds of a site's footprint (site_floor's shapes, ungrown).
static func _site_bounds(s: Dictionary) -> Rect2:
	if s.has("circle"):
		var c: Vector3 = s.circle
		return Rect2(c.x - c.z, c.y - c.z, c.z * 2.0, c.z * 2.0)
	if s.has("seg"):
		var a: Vector3 = s.seg[0]
		var b: Vector3 = s.seg[1]
		return Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z)).grow(float(s.seg[2]))
	return s.rect as Rect2


## cull_scatter's exact test against one cell's candidates: the same as site_at(p, reach) non-empty
## or _on_runtime_lane(p, reach).
static func _hits(cand: Array, segs: Array, p: Vector2, reach: float) -> bool:
	for j: int in cand[0]:
		if not is_nan(site_floor(sites[j], p, reach)):
			return true
	for j: int in cand[1]:
		var sg: Array = segs[j]
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < float(sg[2]) + reach:
			return true
	return false


static func clear_cache() -> void:
	_floor.clear()


static func floor_at(space: PhysicsDirectSpaceState3D, p: Vector2) -> float:
	var key := Vector2i(roundi(p.x * 2.0), roundi(p.y * 2.0))
	if _floor.has(key):
		return _floor[key]
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -40.0, p.y), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	var y: float = (hit.position as Vector3).y
	_floor[key] = y
	return y


## Name of the first lane the world-space box `b` blocks, or "" when it is clear.
static func intrudes(space: PhysicsDirectSpaceState3D, b: AABB, pad := 0.0) -> String:
	if space == null:
		return ""
	var lo := Vector2(b.position.x, b.position.z)
	var hi := Vector2(b.end.x, b.end.z)
	for st in sites:
		if site_hits_rect(st, Rect2(lo, hi - lo), pad + 0.3) and b.end.y > float(st.floor_y) - 1.0:
			return String(st.name)
	for lane: Array in extra_lanes:
		var pts: Array = lane[1]
		var w: float = float(lane[2]) + pad
		# cheap reject: lane bounding rect grown by w
		var llo := Vector2(INF, INF)
		var lhi := Vector2(-INF, -INF)
		for v: Vector2 in pts:
			llo = llo.min(v)
			lhi = lhi.max(v)
		if hi.x < llo.x - w or lo.x > lhi.x + w or hi.y < llo.y - w or lo.y > lhi.y + w:
			continue
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var c: Vector2 = pts[k + 1]
			var n := maxi(1, ceili(a.distance_to(c) / STEP))
			for i in n + 1:
				var s := a.lerp(c, float(i) / float(n))
				var nearest := s.clamp(lo, hi)
				if nearest.distance_to(s) > w:
					continue
				var fy := floor_at(space, s)
				if is_nan(fy):
					continue
				if b.position.y < fy + HEADROOM and b.end.y > fy + 0.06:
					return String(lane[0])
	return ""


## World AABB of every visible mesh under `n`.
static func bounds(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for node in n.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		if vi is GPUParticles3D or vi is Light3D:
			continue
		var bb := vi.global_transform * vi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	if n is VisualInstance3D:
		var own := (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		out = own if first else out.merge(own)
	return out

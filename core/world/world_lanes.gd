class_name WorldLanes
extends RefCounted
## The walkways of the whole world in one table: the routes the player actually travels, as XZ
## polylines with a half-width. Every runtime scatterer (night dressing, twigs, rocks, etc.) asks
## `intrudes()` before it keeps a prop, so set dressing can never again end up across a stair,
## a bridge or a doorway. zz/lanes.gd sweeps a capsule along the same table to audit the result.

## [name, [Vector2(x, z) ...], half width]
const LANES := [
	["sanctuary", [Vector2(0, 30), Vector2(0, 4)], 1.8],
	["stair", [Vector2(0, 2), Vector2(0, -31.5), Vector2(0, -36.5), Vector2(0, -68.5)], 3.6],
	["landing_bridge", [Vector2(0, -34), Vector2(13.4, -34)], 1.6],
	["hall", [Vector2(13.4, -34), Vector2(19.5, -34), Vector2(23, -36.5), Vector2(23, -39.5)], 1.3],
	["summit", [Vector2(0, -66), Vector2(0, -77.6)], 2.9],
	["jetty", [Vector2(2, -89), Vector2(12.8, -89)], 1.4],
]
## Lanes inside streamed areas, whose floors do not exist yet when their props are placed: points
## carry the floor height. [name, [Vector3(x, floor y, z) ...], half width]
const FIXED_LANES := [
	["oss_hall", [Vector3(13.4, 12.6, -34), Vector3(19.6, 12.6, -34), Vector3(20.2, 12.6, -36.6), Vector3(23, 12.6, -36.6), Vector3(23, 12.6, -39.5)], 0.8],
	["oss_stair1", [Vector3(23, 12.6, -39.5), Vector3(23, 8.4, -49.5), Vector3(23, 8.4, -52.5)], 1.0],
	["oss_gallery", [Vector3(23, 8.4, -52.5), Vector3(20, 8.4, -58), Vector3(20, 8.4, -65.5), Vector3(21, 8.4, -67.5)], 0.8],
	["oss_stair2", [Vector3(21, 8.4, -68.5), Vector3(21, 4.2, -78), Vector3(20.5, 4.2, -80), Vector3(17.5, 4.2, -84)], 0.9],
	["oss_chapel", [Vector3(17.5, 4.2, -84), Vector3(16, 4.2, -95.5), Vector3(16, 4.2, -104)], 0.8],
]
## Structures the terrain must meet: [node path under the zone root, clip box (zero = whole mesh),
## max adjustment in metres]. TerrainStamp raises ground to their undersides and drops it under
## buried walk surfaces. The cap keeps lintels, arches and high flights from pulling the ground up.
const FOOTPRINTS := [
	["Zone/Ruins", AABB(), 0.8],
	["Zone/Stair", AABB(Vector3(-6, -3, -7), Vector3(12, 6, 9)), 1.6],
]
const HEADROOM := 2.2        ## a prop intrudes when it occupies [floor + 0.06, floor + HEADROOM]
const STEP := 0.5

static var _floor: Dictionary = {}      # Vector2i(sample * 2) -> floor y (only cached on a hit)
## Runtime registry, filled by builders before anything is scattered (placement order: landmark
## builds and registers -> terrain stamp cuts its site -> props/grass avoid it).
## site = {name, rect (Rect2 in XZ), floor_y, cut_y}
static var sites: Array[Dictionary] = []
static var extra_lanes: Array = []      # same shape as LANES
## false under the Realm (docs/REALM_PLAN.md): the old stair-era LANES / FIXED_LANES / FOOTPRINTS
## describe a world that is no longer built, so they must not keep props or ground away from it
static var legacy := true
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


static func register_lane(n: String, pts: Array, half_w: float) -> void:
	for l: Array in extra_lanes:
		if l[0] == n:
			return
	extra_lanes.append([n, pts, half_w])


## Site whose footprint (grown by `margin`) covers XZ point p, or {}.
static func site_at(p: Vector2, margin := 0.0) -> Dictionary:
	for s in sites:
		if not is_nan(site_floor(s, p, margin)):
			return s
	return {}


## Site clearance: loose fragments of a merged mesh (ruin stones, rubble) that stand inside a
## registered site or a portal's approach are taken away whole, visual and collision together, so a
## building never goes up around a stone. Fragments = connected triangle islands of the mesh.
static func clear_fragments(root: Node, mesh_path: String, body_path: String, max_size := 12.0, crowns: Array[String] = [], on_lanes := false) -> int:
	var mi := root.get_node_or_null(mesh_path) as MeshInstance3D
	if mi == null or mi.mesh == null or (sites.is_empty() and portals.is_empty()):
		return 0
	var keep_out: Array[AABB] = []
	for st in sites:
		var r: Rect2 = (st.rect as Rect2).grow(0.3)
		keep_out.append(AABB(Vector3(r.position.x, float(st.floor_y) - 1.0, r.position.y), Vector3(r.size.x, 7.0, r.size.y)))
	for pt in portals:
		var pb: Array = portal_box(pt)
		var xf: Transform3D = pb[0]
		var he: Vector3 = pb[1]
		keep_out.append(xf * AABB(-he, he * 2.0))
	if on_lanes:
		for l: Array in extra_lanes:
			var pts: Array = l[1]
			var w: float = float(l[2])
			for k in pts.size() - 1:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var n := maxi(1, ceili(a.distance_to(b) / 1.0))
				for i in n + 1:
					var c := a.lerp(b, float(i) / float(n))
					keep_out.append(AABB(Vector3(c.x - w, -60.0, c.y - w), Vector3(w * 2.0, 120.0, w * 2.0)))
	var xf := mi.global_transform
	var out := ArrayMesh.new()
	var gone: Array[AABB] = []
	var gone_pieces: Array[AABB] = []         # whole removed trees (for the log)
	var gone_holders: Array[AABB] = []        # whole trees removed / kept (crowns sit on them)
	var kept_holders: Array[AABB] = []
	var removed := 0
	for si in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		# whole pieces (SeatProps.pieces: a tree's trunk, branches and twigs together), so clearing
		# a trunk off a site does not leave its upper branches hanging above the keep-out box
		var pc: Array = SeatProps.pieces(verts, idx, xf)
		var piece: PackedInt32Array = pc[0]
		var info: Dictionary = pc[1]
		var ibox: Dictionary = pc[2]
		var ipiece: Dictionary = pc[3]
		var drop := {}
		for c: int in ibox:
			var r: int = ipiece[c]
			if drop.has(r):
				continue
			var bb: AABB = ibox[c]
			if bb.size.length() > max_size:
				continue                    # not a loose fragment (a wall run, the ground)
			# judged where it will stand: baked props still hang at the pre-terrace height here and
			# come down with the terraces later (SeatProps.follow_terrain)
			var base: Vector3 = info[r][1]
			bb.position.y += TerrainStamp.shape_delta_at(base.x, base.z)
			if bb.position.y > (info[r][0] as AABB).position.y + 1.5:
				continue                    # a branch overhanging the site: the tree may stay
			for ko in keep_out:
				if ko.intersects(bb):
					drop[r] = true
					break
		for c: int in ibox:
			if drop.has(ipiece[c]):
				gone.append(ibox[c])        # per island, so collision of what stays is untouched
		for r: int in drop:
			gone_pieces.append(info[r][0])
		for r: int in info:
			if (info[r][0] as AABB).size.y < 3.0:
				continue                    # stumps, logs, rocks hold no crown
			if drop.has(r):
				gone_holders.append(info[r][0])
			else:
				kept_holders.append(info[r][0])
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if drop.has(piece[idx[t]]):
				removed += 1
				continue
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mi.mesh.surface_get_material(si))
	if removed == 0:
		return 0
	mi.mesh = out
	var body := root.get_node_or_null(body_path) as Node3D
	if body:
		for c in body.get_children():
			var cs := c as CollisionShape3D
			if cs == null:
				continue
			if not (cs.shape is ConcavePolygonShape3D):
				# one primitive per fragment (tree trunks): drop the one standing in a removed fragment
				var o := cs.global_position
				for g in gone:
					if Rect2(g.position.x - 0.3, g.position.z - 0.3, g.size.x + 0.6, g.size.z + 0.6).has_point(Vector2(o.x, o.z)):
						cs.disabled = true
						cs.queue_free()
						break
				continue
			var cx := cs.global_transform
			var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
			var kept := PackedVector3Array()
			for i in range(0, faces.size(), 3):
				var m := cx * ((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
				var hit := false
				for g in gone:
					if g.grow(0.05).has_point(m):
						hit = true
						break
				if not hit:
					kept.append_array(PackedVector3Array([faces[i], faces[i + 1], faces[i + 2]]))
			var sh := ConcavePolygonShape3D.new()
			sh.backface_collision = (cs.shape as ConcavePolygonShape3D).backface_collision
			sh.set_faces(kept)
			cs.shape = sh
	# what grew from a removed fragment goes with it: canopy islands centred over it, occluders in it
	for cp in crowns:
		var cm := root.get_node_or_null(cp) as MeshInstance3D
		if cm == null or cm.mesh == null:
			continue
		_drop_crowns(cm, gone_holders, kept_holders)
	for oc in root.find_children("*", "OccluderInstance3D", true, false):
		var o := (oc as Node3D).global_position
		for g in gone:
			if g.grow(1.0).has_point(o):
				oc.queue_free()
				break
	print("SITE clearance: %d piece(s), %d tris from %s" % [gone_pieces.size(), removed, mesh_path])
	return gone_pieces.size()


## A crown goes only with its own tree: it is dropped when a removed trunk/branch held it and no
## remaining one does ("held" = its centre over that tree's bounds, grown 1 m, reaching to within
## 3 m of the crown's underside -- the same test zz/prop_audit uses), or when it hangs over a
## building site with no tree left to hold it. It used to drop every crown
## inside a removed tree's whole footprint (15-40 m across), leaving spawn's other trees bare.
static func _drop_crowns(mi: MeshInstance3D, gone_holders: Array[AABB], kept_holders: Array[AABB]) -> void:
	if gone_holders.is_empty():
		return
	var xf := mi.global_transform
	var out := ArrayMesh.new()
	var dropped := 0
	var holds := func(t: AABB, cb: AABB) -> bool:
		var c := cb.get_center()
		return t.grow(1.0).has_point(Vector3(c.x, t.get_center().y, c.z)) and t.end.y > cb.position.y - 3.0
	for si in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var comp := SeatProps.island_of(verts, idx)
		var box := {}
		for vi in verts.size():
			if comp[vi] >= 0:
				var w := xf * verts[vi]
				box[comp[vi]] = (box[comp[vi]] as AABB).expand(w) if box.has(comp[vi]) else AABB(w, Vector3.ZERO)
		var drop := {}
		for c: int in box:
			var cb: AABB = box[c]
			var lost := site_at(Vector2(cb.get_center().x, cb.get_center().z), 0.0).size() > 0   # over a building
			for g in gone_holders:
				if holds.call(g, cb):
					lost = true
					break
			if not lost:
				continue
			for k in kept_holders:
				if holds.call(k, cb):
					lost = false
					break
			if lost:
				drop[c] = true
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if drop.has(comp[idx[t]]):
				dropped += 1
				continue
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mi.mesh.surface_get_material(si))
	if dropped > 0:
		mi.mesh = out


## Props (separate nodes, e.g. menhirs) standing on a runtime lane are moved aside to line it,
## as stones line a processional way, then dropped back onto the ground.
static func line_lanes(root: Node, prefix: String) -> int:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var moved := 0
	for zn in root.find_children(prefix + "*", "Node3D", true, false):
		var n := zn as Node3D
		var p := Vector2(n.global_position.x, n.global_position.z)
		for l: Array in extra_lanes:
			var pts: Array = l[1]
			var w: float = float(l[2]) + 1.0
			for k in pts.size() - 1:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var near := a + ab * t
				var d := p.distance_to(near)
				if d < w:
					var away := (p - near).normalized() if d > 0.01 else Vector2(-ab.y, ab.x).normalized()
					p = near + away * (w + 0.4)
					if not site_at(p, 1.2).is_empty():
						p = near - away * (w + 0.4)            # the other side of the way
					if not site_at(p, 1.2).is_empty():
						n.visible = false                      # nowhere to stand: take it away
						for co in n.find_children("*", "CollisionObject3D", true, false):
							(co as CollisionObject3D).collision_layer = 0
						break
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 40, p.y), Vector3(p.x, -30, p.y), Layers.WORLD))
					n.global_position = Vector3(p.x, (hit.position as Vector3).y if hit else n.global_position.y, p.y)
					moved += 1
	return moved


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
		if mm == null or mm.instance_count == 0 or mmi.has_meta("site_owned"):
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
	for lane: Array in (LANES + extra_lanes if legacy else extra_lanes):
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


## Fixed-floor lanes only (no physics needed): for scatterers that run before their floors exist.
static func intrudes_fixed(b: AABB, pad := 0.0) -> String:
	if not legacy:
		return ""
	for lane: Array in FIXED_LANES:
		var pts: Array = lane[1]
		var w: float = float(lane[2]) + pad
		var lo := Vector2(b.position.x, b.position.z)
		var hi := Vector2(b.end.x, b.end.z)
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]
			var c: Vector3 = pts[k + 1]
			var n := maxi(1, ceili(Vector2(a.x, a.z).distance_to(Vector2(c.x, c.z)) / STEP))
			for i in n + 1:
				var s3 := a.lerp(c, float(i) / float(n))
				var s := Vector2(s3.x, s3.z)
				if s.clamp(lo, hi).distance_to(s) > w:
					continue
				if b.position.y < s3.y + HEADROOM and b.end.y > s3.y - 0.3:
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

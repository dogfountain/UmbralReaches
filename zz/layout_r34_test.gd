extends Node
## r34 layout checks (docs/r34/layout.md), on the built Realm, in memory only (Travel._busy):
##   bounds     BOUNDS ~ twice the r33 area, the fixed points inside it, the terrain grid and the
##              horizon ring cover it, the invisible walls stand on all four new edges
##   regions    every region has an id, name, known biome and lore, a Journal entry, names its own
##              centre (region_at), and a road reaches into it
##   roads      the walked network is one connected graph from Hearthward, every way stays on the
##              ground inside the bounds, never steeper than a walk (1 m samples)
##   raids      the raid floors are flat and clear (henge) or cut below the deck (summit): no tree,
##              camp or foreign site on them
##   void       every fire, map marker, camp and place of interest stands on ground inside the bounds,
##              not under it (in a cliff) or over nothing
##   minimap    the painted map covers the new bounds
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh layout_r34
const Land := preload("res://core/world/realm/realm_land.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")

const BIOMES := ["meadow", "oldforest", "fen", "ash", "heath", "crag", "ruin", "glade"]
const NEW_REGIONS := ["quarry", "holds", "foundry", "moor", "orchard", "necropolis", "mere"]

var main: Node
var t := 0.0
var done := false
var fails := 0
var space: PhysicsDirectSpaceState3D


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(what: String, ok: bool) -> void:
	print("LAYOUT34 ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 220.0:
		print("LAYOUT34 FAIL timeout")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 4.0:
		return
	done = true
	await get_tree().physics_frame
	space = (main as Node3D).get_world_3d().direct_space_state
	_bounds()
	_regions()
	_roads()
	_raids()
	_void()
	await _minimap()
	print("LAYOUT34 %s %d" % ["DONE PASS" if fails == 0 else "DONE FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## Terrain height (ignores props), NAN when there is no terrain.
func _terrain(x: float, z: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 140, z + 0.0029), Vector3(x, -80, z), Layers.WORLD))
	var ex: Array[RID] = []
	for i in 8:
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append((hit.collider as CollisionObject3D).get_rid())
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 140, z + 0.0029), Vector3(x, -80, z), Layers.WORLD, ex))
	return NAN


# --- bounds ---------------------------------------------------------------------------------------

func _bounds() -> void:
	var b := RealmLayout.BOUNDS
	var old := Rect2(-110.0, -150.0, 220.0, 230.0)
	check("BOUNDS area %.0f m2 is ~2x the r33 %.0f (1.85..2.3)" % [b.get_area(), old.get_area()], b.get_area() / old.get_area() > 1.85 and b.get_area() / old.get_area() < 2.3)
	check("BOUNDS holds the r33 world", b.encloses(old))
	for n: String in ["SPAWN", "PLAYER_START", "SUMMIT", "SUMMIT_DAIS", "SUMMIT_WARD"]:
		var v: Vector3 = (load("res://core/world/realm/realm_layout.gd") as GDScript).get_script_constant_map()[n]
		check("%s inside BOUNDS" % n, b.has_point(Vector2(v.x, v.z)))
	check("fixed points kept (spawn, start, tavern, ossuary, summit)", RealmLayout.SPAWN == Vector3(0, 0, 33) and RealmLayout.PLAYER_START == Vector3(0, 0.15, 26.5)
		and RealmLayout.TAVERN == Rect2(10, 25.6, 16, 9.2) and RealmLayout.OSSUARY == AABB(Vector3(2, -6, -110), Vector3(30, 32, 88)) and RealmLayout.SUMMIT == Vector3(0, 24.5, -83.5))
	var grid := Rect2(Land.GX0, Land.GZ0, (Land.GNX - 1) * Land.STEP, (Land.GNZ - 1) * Land.STEP)
	check("terrain grid %s covers BOUNDS + 8 m" % grid, grid.encloses(b.grow(8.0)))
	var ring := Rect2(Land.RX0, Land.RZ0, (Land.RNX - 1) * Land.RSTEP, (Land.RNZ - 1) * Land.RSTEP)
	check("horizon ring %s covers OUTER, 60 m+ past BOUNDS" % ring, ring.encloses(RealmLayout.OUTER.grow(-0.5)) and RealmLayout.OUTER.encloses(b.grow(60.0)))
	for k: String in ["N", "S", "E", "W"]:
		check("horizon ring %s built" % k, main.get_node_or_null("Zone/TerrainRing" + k) != null)
	# the ground everywhere inside the bounds (a 10 m lattice)
	var holes := 0
	var x := b.position.x + 5.0
	while x < b.end.x:
		var z := b.position.y + 5.0
		while z < b.end.y:
			if is_nan(_terrain(x, z)):
				holes += 1
			z += 10.0
		x += 10.0
	check("terrain under every 10 m point of the bounds (%d holes)" % holes, holes == 0)
	# the invisible walls on all four edges
	var walls := main.get_node_or_null("Zone/RealmBounds")
	var edges := {"N": false, "S": false, "W": false, "E": false}
	if walls:
		for cs in walls.get_children():
			var p: Vector3 = (cs as Node3D).position
			if absf(p.z - b.position.y) < 2.0: edges.N = true
			if absf(p.z - b.end.y) < 2.0: edges.S = true
			if absf(p.x - b.position.x) < 2.0: edges.W = true
			if absf(p.x - b.end.x) < 2.0: edges.E = true
	check("bounds walls on every edge %s" % edges, edges.values().all(func(v: bool) -> bool: return v))
	# the edge reads as a boundary: rock or rising ground every 20 m along the south, west and east
	var open := 0
	var rocks: Array[Vector3] = []
	var er := main.find_child("EdgeRocks", true, false)
	if er:
		for c in er.get_children():
			rocks.append((c as Node3D).global_position)
	for run: Array in [[Vector2(b.position.x, b.end.y), Vector2(b.end.x, b.end.y), Vector2(0, -1)], [Vector2(b.position.x, b.position.y + 45.0), Vector2(b.position.x, b.end.y), Vector2(1, 0)], [Vector2(b.end.x, b.position.y + 45.0), Vector2(b.end.x, b.end.y), Vector2(-1, 0)]]:
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var n := int(a.distance_to(c) / 20.0)
		for i in n + 1:
			var q := a.lerp(c, float(i) / n) + (run[2] as Vector2) * 2.0
			var near := false
			for r in rocks:
				if Vector2(r.x, r.z).distance_to(q) < 14.0:
					near = true
					break
			var rise := _terrain(q.x, q.y) - _terrain(q.x + (run[2] as Vector2).x * 14.0, q.y + (run[2] as Vector2).y * 14.0)
			if not near and not (rise > 2.5):
				open += 1
				print("LAYOUT34   open edge at ", q)
	check("the south, west and east edges are rock or rising ground (%d open)" % open, open <= 2)


# --- regions --------------------------------------------------------------------------------------

func _regions() -> void:
	var ids: Array[String] = []
	for r: Dictionary in RealmLayout.REGIONS:
		ids.append(String(r.id))
		var ok := r.has("id") and r.has("name") and r.has("biome") and r.has("lore") and (r.has("rect") or (r.has("c") and r.has("r")))
		check("region %s complete (biome %s known)" % [r.id, r.biome], ok and String(r.biome) in BIOMES)
		check("region %s has a Journal entry" % r.id, LoreDB.PLACE_INFO.has(String(r.id)))
		var c: Vector2 = r.c if r.has("c") else (r.rect as Rect2).get_center()
		check("region %s centre inside BOUNDS" % r.id, RealmLayout.BOUNDS.has_point(c))
		if String(r.id) in NEW_REGIONS:
			check("region_at names %s at its centre (got %s)" % [r.id, RealmLayout.region_at(c.x, c.y).get("id", "")], RealmLayout.region_at(c.x, c.y).get("id", "") == r.id)
			check("region %s has a purpose" % r.id, String(r.get("purpose", "")) != "")
	for id: String in NEW_REGIONS:
		check("new region %s exists" % id, id in ids)
	# the suggested slots (RealmLayout.SLOTS) stand where a builder can use them
	for rid: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			var q: Vector2 = sl.at
			var why := _slot_why(rid, String(sl.kind), q)
			if not why.is_empty():
				var best := Vector2.INF
				for k in 140:
					var a := float(k) * 2.39996
					var c := q + Vector2(cos(a), sin(a)) * (1.0 + float(k) * 0.1)
					if _slot_why(rid, String(sl.kind), c.round()).is_empty():
						best = c.round()
						break
				print("LAYOUT34   slot %s %s: nearest usable %s" % [rid, sl.kind, best])
			check("slot %s %s at %s usable %s" % [rid, sl.kind, q, why], why.is_empty())
	check("at least 4 new regions", NEW_REGIONS.size() >= 4)


# --- roads ----------------------------------------------------------------------------------------

func _roads() -> void:
	var paths: Array = RealmLayout.PATHS
	# connectivity: two ways meet where one's polyline passes within 3 m of the other's vertex
	var adj := {}
	for a: Dictionary in paths:
		adj[a.id] = []
	for a: Dictionary in paths:
		for b: Dictionary in paths:
			if a == b:
				continue
			for v: Vector2 in b.pts:
				if _poly_dist(a.pts, v) < 3.0:
					(adj[a.id] as Array).append(b.id)
					(adj[b.id] as Array).append(a.id)
					break
	# Hearthward's green is walked freely: every way that starts in it meets the others there
	adj["hearth"] = []
	for a: Dictionary in paths:
		for v: Vector2 in a.pts:
			if RealmLayout.place_weight(RealmLayout.REGIONS[0], v.x, v.y) >= 0.9:
				(adj["hearth"] as Array).append(a.id)
				(adj[a.id] as Array).append("hearth")
				break
	var seen := {"road": true}
	var front := ["road"]
	while not front.is_empty():
		var id: String = front.pop_back()
		for n: String in adj[id]:
			if not seen.has(n):
				seen[n] = true
				front.append(n)
	var lost: Array = []
	for pth: Dictionary in paths:
		if not seen.has(pth.id):
			lost.append(pth.id)
	check("every way joins the road network %s" % [lost], lost.is_empty())
	# every region is reached by a way (a way vertex or 1 m sample well inside it)
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) in ["rift", "ossuary", "summit", "crags"]:
			continue                    # reached by the Crossing / the fen door / it is the wall
		if String(r.id) == "henge":
			# west_way ends at the stair foot; the henge's own stair climbs to the raid floor's rim
			var head: Vector3 = ThornHenge.stair_pts[3] if ThornHenge.stair_pts.size() > 3 else Vector3.INF
			var ww: Array = paths[0].pts
			check("west_way ends at the henge stair's foot, the stair reaches the raid floor (head %s)" % head,
				(ww[ww.size() - 1] as Vector2) == RealmLayout.HENGE_STAIR_FOOT and Vector2(head.x, head.z).distance_to(RealmLayout.raid("henge").c) < float(RealmLayout.raid("henge").r) + 1.0)
			continue
		var best := 0.0
		for pth: Dictionary in paths:
			var pts: Array = pth.pts
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var bb: Vector2 = pts[i + 1]
				var n := maxi(1, int(a.distance_to(bb)))
				for k in n + 1:
					var q := a.lerp(bb, float(k) / n)
					best = maxf(best, RealmLayout.place_weight(r, q.x, q.y))
		check("a way reaches into %s (weight %.2f)" % [r.id, best], best >= 0.6)
	# every way on the ground, inside the bounds, walkable
	for pth: Dictionary in paths:
		var pts: Array = pth.pts
		var worst := 0.0
		var outside := 0
		var nan := 0
		var prev := NAN
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var bb: Vector2 = pts[i + 1]
			var n := maxi(1, int(a.distance_to(bb)))
			for k in n:
				var q := a.lerp(bb, float(k) / n)
				if not RealmLayout.BOUNDS.grow(-1.0).has_point(q):
					outside += 1
				var y := _terrain(q.x, q.y)
				if is_nan(y):
					nan += 1
					continue
				if not is_nan(prev) and pth.id != "rift_rim" and pth.id != "fen_descent":
					worst = maxf(worst, absf(y - prev) / (a.distance_to(bb) / n))
				prev = y
		check("%s inside the bounds and on the ground (%d out, %d holes), steepest %.2f m/m" % [pth.id, outside, nan, worst], outside == 0 and nan == 0 and worst < 0.75)


func _slot_why(rid: String, kind: String, q: Vector2) -> PackedStringArray:
	var why := PackedStringArray()
	# r34 places: a slot a phase-2 place or fire now stands on (or beside: its builder moved it a few
	# metres, its stamp cut the ground) is used, not unusable
	if kind != "camp":
		for st: Dictionary in WorldLanes.sites:
			var sn := String(st.name)
			if (sn.begins_with("poi_") or sn.begins_with("brazier_")) and not is_nan(WorldLanes.site_floor(st, q, 6.0)):
				return why
	if String(RealmLayout.region_at(q.x, q.y).get("id", "")) != rid:
		why.append("in %s" % RealmLayout.region_at(q.x, q.y).get("id", "-"))
	var g := _terrain(q.x, q.y)
	var lo := INF
	var hi := -INF
	for o: Vector2 in [Vector2(2.5, 0), Vector2(-2.5, 0), Vector2(0, 2.5), Vector2(0, -2.5)]:
		var gy := _terrain(q.x + o.x, q.y + o.y)
		lo = minf(lo, gy)
		hi = maxf(hi, gy)
	if is_nan(g):
		why.append("no ground")
	elif hi - lo > (2.2 if kind == "camp" else 1.6):
		why.append("steep (%.1f m over 5 m)" % (hi - lo))
	if kind != "poi_wet" and (Land.in_water(q.x, q.y) or Land.in_water(q.x + 2.0, q.y) or Land.in_water(q.x - 2.0, q.y) or Land.in_water(q.x, q.y + 2.0) or Land.in_water(q.x, q.y - 2.0)):
		why.append("in water")
	if RealmLayout.path_dist(q) < (3.0 if kind == "camp" else 2.0):
		why.append("on a way")
	# r34 places: a slot a phase-2 builder used (a place, a fire's pad, a lore stone, a secret, a camp
	# planted there) is taken, not blocked; only a site from before phase 2 makes it unusable
	for st: Dictionary in WorldLanes.sites:
		var sn := String(st.name)
		if sn.begins_with("poi_") or sn.begins_with("brazier_") or sn.begins_with("r34_") or sn.begins_with("secrets_"):
			continue
		if not is_nan(WorldLanes.site_floor(st, q, 1.0)):
			why.append("on site %s" % sn)
			break
	return why


func _poly_dist(pts: Array, p: Vector2) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t2 := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t2))
	return best


# --- raids ----------------------------------------------------------------------------------------

func _raids() -> void:
	for r: Dictionary in RealmLayout.RAIDS:
		var c: Vector2 = r.c
		var rr: float = r.r
		var y: float = r.y
		check("raid %s is %.0f m across (55..65)" % [r.id, rr * 2.0], rr * 2.0 >= 55.0 and rr * 2.0 <= 65.0)
		check("raid %s inside BOUNDS" % r.id, RealmLayout.BOUNDS.grow(-2.0).encloses(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)))
		var lo := INF
		var hi := -INF
		var above := 0
		var x := -rr
		while x <= rr:
			var z := -rr
			while z <= rr:
				var on_stair := false
				if String(r.id) == "henge" and ThornHenge.stair_pts.size() > 3:
					var f: Vector3 = ThornHenge.stair_pts[0]
					var h3: Vector3 = ThornHenge.stair_pts[3]
					on_stair = _poly_dist([Vector2(f.x, f.z), Vector2(h3.x, h3.z)], c + Vector2(x, z)) < 4.5    # its own cut under the treads
				if Vector2(x, z).length() <= rr - 1.0 and not on_stair:
					var g := _terrain(c.x + x, c.y + z)
					if not is_nan(g):
						lo = minf(lo, g)
						hi = maxf(hi, g)
						if g > y - 0.4:
							above += 1
				z += 2.0
			x += 2.0
		if String(r.mode) == "level":
			check("raid %s floor level at %.2f (ground %.2f..%.2f)" % [r.id, y, lo, hi], hi - lo < 0.5 and absf((hi + lo) * 0.5 - y) < 0.4)
		else:
			check("raid %s: no ground above the deck at %.2f (%d points, highest %.2f)" % [r.id, y, above, hi], above == 0)
		var trees := 0
		for tr: Array in Flora.trees:
			var tp: Vector3 = tr[0]
			if Vector2(tp.x, tp.z).distance_to(c) < rr + 1.0:
				trees += 1
		check("raid %s: no trees on it (%d)" % [r.id, trees], trees == 0)
		var camps := 0
		for cp: Dictionary in EnemySpawner.REALM_CAMPS:
			var at: Vector3 = cp.at
			if Vector2(at.x, at.z).distance_to(c) < rr:
				camps += 1
				print("LAYOUT34   camp in raid %s at %s" % [r.id, at])
		check("raid %s: no camp on it (%d)" % [r.id, camps], camps == 0)
		if String(r.id) == "henge":
			var foreign: Array = []
			for st: Dictionary in WorldLanes.sites:
				var nm := String(st.name)
				if nm.begins_with("raid_") or nm.begins_with("henge"):
					continue
				var sr: Rect2 = st.rect
				var cl := Vector2(clampf(c.x, sr.position.x, sr.end.x), clampf(c.y, sr.position.y, sr.end.y))
				if cl.distance_to(c) < rr - 0.5:
					foreign.append(nm)
			check("raid henge: no foreign site on it %s" % [foreign], foreign.is_empty())
	check("Ossuary hall reserve is underground (top %.1f) and clear of the crypt's box" % RealmLayout.OSSUARY_HALL.end.y,
		RealmLayout.OSSUARY_HALL.end.y <= RealmLayout.OSSUARY.position.y + 0.01 and RealmLayout.OSSUARY_HALL.size.x >= 50.0 and RealmLayout.OSSUARY_HALL.size.z >= 50.0)
	var hall := RealmLayout.OSSUARY_HALL
	var low := INF
	var hx := hall.position.x + 1.0
	while hx < hall.end.x:
		var hz := hall.position.z + 1.0
		while hz < hall.end.z:
			var g := _terrain(hx, hz)
			if not is_nan(g):
				low = minf(low, g)
			hz += 2.0
		hx += 2.0
	check("ground over the Ossuary hall stays 4 m+ above its top (lowest %.2f)" % low, low > hall.end.y + 4.0)


# --- nothing in the void --------------------------------------------------------------------------

func _void() -> void:
	var bad: Array = []
	var things: Array[Node3D] = []
	for g: StringName in [Groups.BRAZIER, &"map_marker", &"world_poi"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and (n as Node).is_inside_tree() and not (n as Node3D).is_in_group(Groups.PLAYER):
				things.append(n as Node3D)
	for n: Node3D in things:
		var p := n.global_position
		if RealmLayout.in_ossuary(p) or p.y < -4.0:
			continue                    # underground (the crypt) or down in the rift: not on the surface
		if not RealmLayout.BOUNDS.has_point(Vector2(p.x, p.z)):
			bad.append("%s outside at %s" % [n.name, p])
			continue
		var g := _terrain(p.x, p.z)
		if is_nan(g):
			bad.append("%s over nothing at %s" % [n.name, p])
		elif p.y < g - 1.5:
			bad.append("%s %.1f m under the ground at %s" % [n.name, g - p.y, p])
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = cp.at
		if not RealmLayout.BOUNDS.grow(-4.0).has_point(Vector2(at.x, at.z)):
			bad.append("camp outside at %s" % at)
		elif is_nan(_terrain(at.x, at.z)):
			bad.append("camp over nothing at %s" % at)
	for b in bad:
		print("LAYOUT34   ", b)
	check("nothing in the void or in the ground (%d of %d things, %d camps)" % [bad.size(), things.size(), EnemySpawner.REALM_CAMPS.size()], bad.is_empty())


# --- the minimap ----------------------------------------------------------------------------------

func _minimap() -> void:
	var mm: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() == load("res://ui/minimap.gd"):
			mm = n
			break
	if mm == null:
		mm = (load("res://ui/minimap.gd") as GDScript).new()
		add_child(mm)
	var t0 := Time.get_ticks_msec()
	while mm.get("_tex") == null and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	var tex: Texture2D = mm.get("_tex")
	var o: Vector2 = mm.get("_origin")
	var s: Vector2 = mm.get("_size_m")
	check("minimap painted over BOUNDS (origin %s size %s, texture %s)" % [o, s, tex.get_size() if tex else Vector2.ZERO],
		tex != null and o == RealmLayout.BOUNDS.position and s == RealmLayout.BOUNDS.size and tex.get_size().x >= RealmLayout.BOUNDS.size.x)

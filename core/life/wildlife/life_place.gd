extends RefCounted
## Where the wildlife lives (life system): reads the built Realm (lights, menhirs, graves, fen pools,
## trunk colliders, forest edges, the Ossuary floors) and returns anchors for the groups. Run once at
## build, after every Realm module before it. Load by path (no class_name).

const RL := preload("res://core/world/realm/realm_land.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")

## lights whose name says they are indoors, cold or not a flame
const LIGHT_SKIP := ["hearth", "taproom", "glow", "orb", "fill", "bolt", "seal", "rim", "window", "crystal", "chapel", "pit", "gallery", "bridge"]


## Fisher-Yates with a seeded generator (Array.shuffle uses the global one: placement must repeat).
static func shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


static func ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


## Any solid floor under (x, y_from, z) (crypt floors, stones, decks), or NAN.
static func floor_below(space: PhysicsDirectSpaceState3D, x: float, y_from: float, z: float, depth := 30.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, y_from, z + 0.0029), Vector3(x + 0.0037, y_from - depth, z + 0.0029), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit.position as Vector3).y


## Warm flame lights outdoors (braziers, lanterns, the forge, shrine candles): moth swarms.
static func moth_lights(root: Node) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for n in root.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if not eligible_light(root, l):
			continue
		out.append(l)
	return out


static func eligible_light(root: Node, l: OmniLight3D) -> bool:
	if l == null or not l.is_inside_tree():
		return false
	var c := l.light_color
	if c.r < 0.9 or c.b > 0.45 or l.light_energy < 0.2:
		return false
	var path := str(root.get_path_to(l)).to_lower()
	if path.begins_with("player") or path.contains("lava") or path.contains("wildlife") or path.begins_with("area_"):
		return false
	var nm := String(l.name).to_lower()
	for k: String in LIGHT_SKIP:
		if nm.contains(k):
			return false
	var p := l.global_position
	# no moths at a lamp indoors (the tavern's candles, a cottage's hearth): beside a bright candle their lit
	# wings bloomed into glowing discs the size of a plate floating round the room
	if path.contains("hollowlantern") or Interiors.at(p) > 0.0:
		return false
	return RealmLayout.BOUNDS.grow(4.0).has_point(Vector2(p.x, p.z))


## The fen pools: grid cells under water flood-filled into pools, biggest first.
## Each: {cells: Array[Vector2], center: Vector2, edge: Array[Vector2] (land just off the water,
## nudged toward it), n: cell count}.
static var pool_cache := {}          ## this build's pools, every one, biggest first (the director clears it per build)


static func pools(new_ground := false) -> Array[Dictionary]:
	if not pool_cache.has("all"):
		pool_cache["all"] = _all_pools()
	# the old Realm's pools (centre inside OLD_BOUNDS) keep their place in the list; the Marches' (the Sorrow,
	# Stillwater, the Well's pool) are asked for with new_ground = true
	var keep: Array[Dictionary] = []
	for p: Dictionary in pool_cache["all"]:
		if RealmLayout.OLD_BOUNDS.has_point(p.center as Vector2) != new_ground:
			keep.append(p)
	return keep


## The flood fill (a quarter of a second over the doubled Realm's grid: made once a build).
static func _all_pools() -> Array[Dictionary]:
	var wet := {}
	for j in RL.GNZ - 1:
		for i in RL.GNX - 1:
			var x := RL.GX0 + float(i) * RL.STEP + RL.STEP * 0.5
			var z := RL.GZ0 + float(j) * RL.STEP + RL.STEP * 0.5
			if RL.in_water(x, z):
				wet[Vector2i(i, j)] = true
	var seen := {}
	var out: Array[Dictionary] = []
	for k: Vector2i in wet:
		if seen.has(k):
			continue
		var cells: Array[Vector2] = []
		var edge: Array[Vector2] = []
		var edge_seen := {}
		var stack: Array[Vector2i] = [k]
		seen[k] = true
		var sum := Vector2.ZERO
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			var cp := Vector2(RL.GX0 + float(c.x) * RL.STEP + 1.0, RL.GZ0 + float(c.y) * RL.STEP + 1.0)
			cells.append(cp)
			sum += cp
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nb := c + d
				if wet.has(nb):
					if not seen.has(nb):
						seen[nb] = true
						stack.append(nb)
				elif not edge_seen.has(nb):
					edge_seen[nb] = true
					var np := Vector2(RL.GX0 + float(nb.x) * RL.STEP + 1.0, RL.GZ0 + float(nb.y) * RL.STEP + 1.0)
					var toward := np + (cp - np) * 0.35
					if not RL.in_water(toward.x, toward.y) and RealmLayout.BOUNDS.grow(-3.0).has_point(toward):
						edge.append(toward)
		out.append({"cells": cells, "center": sum / float(cells.size()), "edge": edge, "n": cells.size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.n) > int(b.n))
	return out


## Nearest water cell centre to p (for frogs leaping in, herons facing the pool).
static func nearest_water(pool: Dictionary, p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for c: Vector2 in pool.cells:
		var d := c.distance_squared_to(p)
		if d < bd:
			bd = d
			best = c
	return best


## Crow roosts: the henge menhirs' crowns and the grave fields (drowned graves, barrows, the chapel
## yard, the road's graves). Each: {name, center: Vector3, perches: Array[[Vector3, yaw]]}.
static func crow_roosts(root: Node, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var henge := root.get_node_or_null("ThornHenge")
	if henge != null:
		var tops: Array = []
		for c in henge.get_children():
			if String(c.name).begins_with("Menhir") and c is Node3D:
				var top := _top(c as Node3D)
				if top != Vector3.INF:
					tops.append([top, rng.randf_range(-PI, PI)])
		shuffle(tops, rng)
		if tops.size() > 0:
			out.append({"name": "henge", "center": _mean(tops), "perches": tops.slice(0, 9)})
	var lore := root.get_node_or_null("RealmLore")
	if lore != null:
		for site_name: String in ["DrownedGraves", "BarrowField", "KindlersYard", "PilgrimsRoad"]:
			var site := lore.get_node_or_null(site_name)
			if site == null:
				continue
			var groups := {}          # 16 m cells -> perches
			for c in site.get_children():
				if not String(c.name).begins_with("Lore_") or not (c is Node3D):
					continue
				if site_name == "PilgrimsRoad" and not String(c.name).contains("grave") and not String(c.name).contains("way"):
					continue
				var p := (c as Node3D).global_position
				var cell := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
				if not groups.has(cell):
					groups[cell] = []
				var perch := _stone_top(space, p, rng)
				(groups[cell] as Array).append([perch, rng.randf_range(-PI, PI)])
				# a couple more on the ground nearby: crows strut and peck between the stones
				for k in 2:
					var a := rng.randf_range(0.0, TAU)
					var q := p + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.8, 2.2)
					var gy := ground(space, q.x, q.z)
					if not RL.in_water(q.x, q.z) and absf(gy - p.y) < 1.5:
						(groups[cell] as Array).append([Vector3(q.x, gy, q.z), rng.randf_range(-PI, PI)])
			# the two busiest stretches of each grave field get a roost
			var cells := groups.keys()
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (groups[a] as Array).size() > (groups[b] as Array).size())
			for cell: Vector2i in cells.slice(0, 2):
				var ps: Array = groups[cell]
				if ps.size() < 4:
					continue
				shuffle(ps, rng)
				out.append({"name": "%s_%d_%d" % [site_name, cell.x, cell.y], "center": _mean(ps), "perches": ps.slice(0, 7)})
	# r34 flora: crows in the Waiting Field's cypresses and on the Cinder Orchard's burned trees (the
	# busiest 24 m stand of each), sat on the tree tops
	for pair: Array in [["necropolis", "cypress_", 0.97], ["orchard", "fruit_", 0.8]]:
		var groups := {}
		for tr: Array in Flora.trees:
			var id := String(tr[1])
			var b: Vector3 = tr[0]
			if not id.begins_with(String(pair[1])) or String(RealmLayout.region_at(b.x, b.z).get("id", "")) != String(pair[0]):
				continue
			var d: Dictionary = Flora.TreeGen.kind(id)
			var sc := float(tr[3]) / maxf(float(d.h), 0.01)
			var top := b + Vector3(0, Flora.mesh_aabb(id).end.y * sc * float(pair[2]), 0)
			var cell := Vector2i(floori(b.x / 24.0), floori(b.z / 24.0))
			if not groups.has(cell):
				groups[cell] = []
			(groups[cell] as Array).append([top, rng.randf_range(-PI, PI)])
		var best := Vector2i.ZERO
		var bn := 0
		for cell: Vector2i in groups:
			if (groups[cell] as Array).size() > bn:
				bn = (groups[cell] as Array).size()
				best = cell
		if bn >= 3:
			var ps: Array = groups[best]
			out.append({"name": "%s_trees" % pair[0], "center": _mean(ps), "perches": ps.slice(0, 6)})
	if not Zones.off():
		out.append_array(settlement_roosts(space, rng))
	return out


## Crows where people live and where the wall is broken: on the roofs round each square, strutting
## on its stones off the walk lanes, and on the wall's crumbled tops at the breaches. A roost needs at
## least five perches (the director seats three or four crows on them).
static func settlement_roosts(space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sq: Dictionary in Zones.squares():
		var c: Vector2 = sq.c
		var r: float = sq.r
		var gy := ground(space, c.x, c.y)
		var tops: Array = []
		var floor_ps: Array = []
		for i in 90:
			var a := rng.randf() * TAU
			var d := r + rng.randf_range(1.0, 14.0)
			var p := c + Vector2(cos(a), sin(a)) * d
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, gy + 14.0, p.y), Vector3(p.x, gy - 2.0, p.y), 1))
			if hit.is_empty():
				continue
			var hp: Vector3 = hit.position
			if hp.y > gy + 2.2 and hp.y < gy + 10.0 and hit.normal.y > 0.3 and not String((hit.collider as Node).name).begins_with("Terrain"):
				tops.append([hp, rng.randf_range(-PI, PI)])
		for i in 40:
			var a2 := rng.randf() * TAU
			var q := c + Vector2(cos(a2), sin(a2)) * r * rng.randf_range(0.2, 0.95)
			if Zones.lane_dist(q) < 2.6:
				continue
			var gq := ground(space, q.x, q.y)
			floor_ps.append([Vector3(q.x, gq, q.y), rng.randf_range(-PI, PI)])
		shuffle(tops, rng)
		var ps: Array = tops.slice(0, 3) + floor_ps.slice(0, 3)
		if ps.size() >= 5:
			out.append({"name": "town_" + String(sq.id), "center": _mean(ps), "perches": ps})
	var bi := 0
	for b: Array in Zones.breaches():
		var bp: Vector2 = b[0]
		var gb := ground(space, bp.x, bp.y)
		var tops2: Array = []
		for i in 60:
			var q2 := bp + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-11.0, 11.0))
			var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q2.x, gb + 12.0, q2.y), Vector3(q2.x, gb - 3.0, q2.y), 1))
			if hit2.is_empty():
				continue
			var hp2: Vector3 = hit2.position
			if hp2.y > gb + 1.6 and hit2.normal.y > 0.5 and not String((hit2.collider as Node).name).begins_with("Terrain"):
				tops2.append([hp2, rng.randf_range(-PI, PI)])
		shuffle(tops2, rng)
		if tops2.size() >= 5:
			out.append({"name": "breach_%d" % bi, "center": _mean(tops2), "perches": tops2.slice(0, 6)})
		bi += 1
	return out


## Top of the stone at p: the highest hit near it (gravestones, menhirs), or the ground.
static func _stone_top(space: PhysicsDirectSpaceState3D, p: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var best := Vector3(p.x, ground(space, p.x, p.z), p.z)
	for k in 6:
		var a := float(k) / 6.0 * TAU + rng.randf() * 0.5
		var r := 0.15 + 0.35 * float(k % 3)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		var y := floor_below(space, x, p.y + 4.0, z, 8.0)
		if not is_nan(y) and y > best.y + 0.05 and y < p.y + 3.0:
			best = Vector3(x, y, z)
	return best


static func _top(n: Node3D) -> Vector3:
	var box := AABB()
	var any := false
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb()
		box = b if not any else box.merge(b)
		any = true
	if not any:
		return Vector3.INF
	var ctr := box.get_center()
	return Vector3(ctr.x, box.end.y - 0.04, ctr.z)


static func _mean(ps: Array) -> Vector3:
	var s := Vector3.ZERO
	for e: Array in ps:
		s += e[0] as Vector3
	return s / float(maxi(ps.size(), 1))


## Big trunks (flora collision cylinders) in a biome list: owl trees. Each {base: Vector3, r: float}.
static func trunks(root: Node, biomes: Array, min_r: float, new_ground := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flora := root.get_node_or_null("RealmFlora")
	if flora == null:
		return out
	for b in flora.find_children("FloraBody", "StaticBody3D", true, false):
		for c in b.get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is CylinderShape3D):
				continue
			var cy := cs.shape as CylinderShape3D
			if cy.radius < min_r or cy.height < 3.0:
				continue
			var p := cs.global_position - Vector3(0, cy.height * 0.5, 0)
			if not RealmLayout.BOUNDS.grow(-4.0).has_point(Vector2(p.x, p.z)):
				continue
			if RealmLayout.OLD_BOUNDS.grow(-4.0).has_point(Vector2(p.x, p.z)) == new_ground:
				continue                                     # the old Realm's trees, or (new_ground) the Marches' and the downs'
			if not (RealmLayout.biome_at(p.x, p.z) in biomes):
				continue
			# trees on a site were culled from the flora MultiMesh but keep their collider: skip them
			if not WorldLanes.site_at(Vector2(p.x, p.z), 3.0).is_empty():
				continue
			out.append({"base": p, "r": cy.radius})
	return out


## Open ground fit for a deer to stand on.
static func open_ground(x: float, z: float) -> bool:
	if not RealmLayout.BOUNDS.grow(-8.0).has_point(Vector2(x, z)):
		return false
	if RL.in_water(x, z) or RL.in_water(x + 1.5, z) or RL.in_water(x - 1.5, z) or RL.in_water(x, z + 1.5) or RL.in_water(x, z - 1.5):
		return false
	if z > 128.0 and z < 196.0 and OssFrame.pit_d(Vector2(x, z)) < 10.0:
		return false                                       # the Ossuary's quarry: its bed and its brink
	var b := RealmLayout.biome_at(x, z)
	if b == "ash" or b == "crag":
		return false
	if Rect2(-32, -120, 64, 110).has_point(Vector2(x, z)):        # the rift and its rims
		return false
	if not WorldLanes.site_at(Vector2(x, z), 2.0).is_empty():
		return false
	if Vector2(x, z).distance_to(Vector2(-70.0, 206.0)) < 8.5:       # the Grandmother Oak's hollow and its doorway
		return false
	if Vector2(x, z).distance_to(Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z)) < 18.0:
		return false
	return true


## Grazing spots at the forest's edges: open ground (no canopy overhead) with woodland close by
## (RealmFlora's canopy cover), anywhere a deer could stand.
static func forest_edges(rng: RandomNumberGenerator, new_ground := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	# r34 layout: the whole (doubled) Realm; the old Realm's lattice as it was, and (new_ground) the Marches' and
	# the downs' on a lattice of their own
	var bb := (RealmLayout.BOUNDS if new_ground else RealmLayout.OLD_BOUNDS).grow(-6.0)
	var x := bb.position.x
	while x < bb.end.x:
		var z := maxf(bb.position.y, -66.0)           # (south of the Crowns)
		while z < bb.end.y:
			var px := x + rng.randf_range(-2.5, 2.5)
			var pz := z + rng.randf_range(-2.5, 2.5)
			if new_ground and RealmLayout.OLD_BOUNDS.grow(-6.0).has_point(Vector2(px, pz)):
				z += 7.0
				continue
			if Flora.cover_at(px, pz) < 0.12 and open_ground(px, pz) and RealmLayout.path_dist(Vector2(px, pz)) > 3.0:
				var wood := 0.0
				for k in 8:
					var a := float(k) / 8.0 * TAU
					wood = maxf(wood, Flora.cover_at(px + cos(a) * 14.0, pz + sin(a) * 14.0))
				if wood > 0.45:
					out.append(Vector3(px, RL.height_at(px, pz), pz))
			z += 7.0
		x += 7.0
	return out


const Flora := preload("res://core/world/realm/realm_flora.gd")

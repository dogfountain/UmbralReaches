extends RefCounted
## Realm module "yards" (the world pass, after "dress"): the towns' backyards and edges, lived in. Hearthward, Reedholm,
## Fallowmere and Lastlight each get 10-16 yard scenes on open ground inside their circle: washing on a line between
## poles, a kitchen garden of beds and stakes, an animal pen (a fence ring, hay, a trough, sheep or pigs), a smith's lean-to
## (anvil, a forge with a fire, a tool rack, barrels), a small graveyard (rows of markers, a lantern), a market corner
## (crate stacks, a table under a hung awning, goods). Placed after every collider, lane and site exists: the ground must be
## open terrain (a ray lands on the height grid, not on a roof), 3.6 x 3.6 x 2.4 m free of any WORLD collider, off the walk
## lanes and the ways, outside every registered site. Scenes are built per 56 m cell (one kit, a handful of meshes and one flame MultiMesh for all its scenes), faded
## at 120 m; nothing is solid except fences and stands' bodies are not needed (nothing blocks a lane). Build-time only.

const SELF := "res://core/world/realm/settlement_yards.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")
const More := preload("res://core/world/realm/settlement_yards_more.gd")

const TOWNS := [[Vector2(6.0, 38.0), 34.0, 10, 0.62], [Vector2(-311.0, 281.0), 30.0, 11], [Vector2(-160.0, 300.0), 34.0, 12], [Vector2(324.5, 53.5), 40.0, 14],
	[Vector2(212.0, 100.0), 30.0, 7], [Vector2(-196.0, 70.0), 34.0, 8], [Vector2(-165.0, 18.0), 24.0, 5]]
const NOT_HOUSES := ["walk", "bank", "wall", "garden", "deck", "landing", "stair", "bridge", "fire", "notice", "shrine", "well", "hearthstone", "punt", "rick", "rack", "pole", "stook",
	"scarecrow", "hurdle", "gate", "trap", "stack", "lamp", "forge", "brazier", "pier", "dock", "pit", "grave", "stall", "cross", "weir", "wheel", "treb", "tower_top"]
const KINDS := ["washing", "garden", "pen", "smith", "grave", "market", "well", "pen", "fence", "workshop", "linen", "garden", "geese", "well", "workshop", "fence"]


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 9393
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 2.4, 3.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Layers.WORLD
	var total := 0
	var made: Array[Vector2] = []
	var cells := {}                         ## 56 m cell -> scenes: one kit per cell (a handful of meshes for all its scenes), not one per scene
	for t: Array in TOWNS:
		var c: Vector2 = t[0]
		var r: float = t[1]
		var want: int = t[2]
		var inner: float = float(t[3]) if t.size() > 3 else 0.0      # Hearthward's yards stay on its outer ring: the plaza, the graves and the fire are the villagers' own
		var n := 0
		# Anchored: a yard belongs to a house. It stands against the house's back (the side furthest from the lanes and the walks), 4.9 m out from the wall,
		# its x along the wall and its +z turned away from it (a lean-to rests its back on the wall; a line of washing, a garden and a pen are the house's own).
		# (It used to be a random point in the town's disc with a random heading: pens in the green, a smithy facing nothing.)
		var anchors := _anchors(c, r, inner)
		for i in range(anchors.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Array = anchors[i]
			anchors[i] = anchors[j]
			anchors[j] = tmp
		for an: Array in anchors:
			if n >= want:
				break
			var rc: Rect2 = an[1]
			var cands: Array = []
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var half := rc.size.x * 0.5 if d.x != 0.0 else rc.size.y * 0.5
				var along := rc.size.y if d.x != 0.0 else rc.size.x
				var perp := Vector2(d.y, d.x)
				for out_m: float in [4.9, 6.3]:
					for tt: float in [0.0, -0.28, 0.28]:
						var p0 := rc.get_center() + d * (half + out_m) + perp * (tt * along)
						cands.append([minf(Zones.lane_dist(p0), 24.0) + minf(_town_walk_dist(p0), 24.0) + minf(RealmLayout.path_dist(p0), 12.0) - out_m, p0, d])
			cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
			for cd: Array in cands:
				var p: Vector2 = cd[1]
				if not _open(space, q, p, made, String(an[0])):
					continue
				var g := WK.span(p, Vector2(3.4, 3.4), 0.0).x      # the scene stands on its lowest ground (the high side buried, nothing in the air)
				var kind := String(KINDS[(n * 3 + anchors.find(an)) % KINDS.size()])
				if kind == "grave" and p.distance_to(c) < r * 0.6:
					kind = "garden"
				var dd: Vector2 = cd[2]
				var key := Vector2i(floori(p.x / 56.0), floori(p.y / 56.0))
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append([Vector3(p.x, g, p.y), kind, atan2(dd.x, dd.y)])
				made.append(p)
				n += 1
				break
		total += n
		print("REALM yards %s: %d buildings, %d yards" % [c, anchors.size(), n])
	for key: Vector2i in cells:
		var k := WK.new()
		k.setup(root, "Yards_%d_%d" % [key.x, key.y], 9400 + key.x * 17 + key.y)
		if not k.cached(WK.fp(SELF, [key, cells[key]])):
			for sc: Array in (cells[key] as Array):
				_scene(k, String(sc[1]), sc[0] as Vector3, float(sc[2]))
		k.commit(120.0)
	print("REALM yards: %d scenes in %d towns, %d kits; refused: %s" % [total, TOWNS.size(), cells.size(), why])


## The buildings of a town: the registered sites whose middle lies in its disc (past `inner` of it), of a house's size and not a well, a walk, a deck or a wall.
func _anchors(c: Vector2, r: float, inner: float) -> Array:
	var out: Array = []
	for st: Dictionary in WorldLanes.sites:
		var rc: Rect2 = st.rect
		var d := rc.get_center().distance_to(c)
		var area := rc.size.x * rc.size.y
		if d > r or d < inner * r * 0.6 or area < 22.0 or area > 700.0:
			continue
		var nm := String(st.name).to_lower()
		var skip := false
		for w: String in NOT_HOUSES:
			if nm.contains(w):
				skip = true
				break
		if not skip:
			out.append([String(st.name), rc])
	return out


func _open(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, p: Vector2, made: Array[Vector2], anchor := "") -> bool:
	for m: Vector2 in made:
		if m.distance_to(p) < 7.5:
			return _no("near another yard")
	if RealmLayout.path_dist(p) < 3.5:
		return _no("a way")
	if WK.wet(p.x, p.y):
		return _no("wet")
	if Zones.lane_dist(p) < 3.2 or WK.near_walk(p, 5.0):
		return _no("a lane or walk")
	if _town_walk_dist(p) < 4.0:               # off the towns' own walks too: a fence on one left a reeve stuck mid-lane (21 Nov)
		return _no("a town walk")
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -20.0, p.y), Layers.WORLD))
	# (the ground behind a house was settled up to a metre off the height formula: the ray's own ground is the one the scene stands on)
	if hit.is_empty() or absf((hit.position as Vector3).y - WK.h(p.x, p.y)) > 1.2:
		return _no("not open ground")
	var span := WK.span(p, Vector2(3.4, 3.4), 0.0)       # the whole scene (a fence row runs 3 m each way), not its middle 4 m
	if span.x == INF or span.y - span.x > 0.7:
		return _no("slope")
	for st: Dictionary in WorldLanes.sites:
		# a yard keeps 3.6 m off every other building's site (a door's approach lies in that strip: a fence stood 3.4 m out of the tithe barn's door, zone fit);
		# its own house allows 2 m: it stands on that house's back
		if WorldLanes.site_hits_rect(st, Rect2(p - Vector2(2.4, 2.4), Vector2(4.8, 4.8)), 2.0 if String(st.name) == anchor else 3.6):
			return _no("a site")
	q.transform = Transform3D(Basis.IDENTITY, Vector3((hit.position as Vector3).x, (hit.position as Vector3).y + 1.5, (hit.position as Vector3).z))
	if not space.intersect_shape(q, 1).is_empty():
		return _no("something solid")
	return true


static var why := {}


func _no(r: String) -> bool:
	why[r] = int(why.get(r, 0)) + 1
	return false


func _scene(k, kind: String, o: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rng: RandomNumberGenerator = k.rng
	if kind in More.KINDS:
		More.scene(k as WK, kind, o, yaw)
		return
	match kind:
		"washing":
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 2.2, 0.0, 0.0), o + b * Vector3(s * 2.2, 2.4, 0.0), 0.07, 0.06, 5, false, 0.7)
			Dress.rope(k, o + b * Vector3(-2.2, 2.3, 0.0), o + b * Vector3(2.2, 2.3, 0.0), 0.3, 0.02, "wood_big", 6)
			for i in 5:
				var x := -1.7 + 0.8 * float(i)
				var h := 0.8 + 0.5 * rng.randf()
				var tp := o + b * Vector3(x, 2.15 - 0.25 * absf(x) * 0.2, 0.0)
				k.kit.quad("chalk", tp, tp + b * Vector3(0.6, 0.0, 0.0), tp + b * Vector3(0.58, -h, 0.0), tp + b * Vector3(0.02, -h * 0.95, 0.0), b * Vector3(0.0, 0.0, 1.0), false, 0.78 + 0.15 * rng.randf())
				k.kit.quad("chalk", tp, tp + b * Vector3(0.6, 0.0, 0.0), tp + b * Vector3(0.58, -h, 0.0), tp + b * Vector3(0.02, -h * 0.95, 0.0), b * Vector3(0.0, 0.0, -1.0), false, 0.6)
			Dress.barrel(k, o + b * Vector3(0.0, 0.0, 1.0), yaw, 0.9)
		"garden":
			for i in 3:
				var bp := o + b * Vector3(-1.5 + 1.5 * float(i), 0.0, 0.0)
				k.kit.box("lore_soil" if false else "dark", bp + Vector3.UP * 0.1, Vector3(1.2, 0.2, 2.6), b, false, 0.6)
				for j in 5:
					k.kit.box("cave_moss", bp + b * Vector3(rng.randf_range(-0.45, 0.45), 0.28, -1.0 + 0.5 * float(j)), Vector3(0.28, 0.3 + 0.2 * rng.randf(), 0.24), Basis(Vector3.UP, rng.randf() * TAU), false, 0.8 + 0.2 * rng.randf())
				if i == 1:
					for s: float in [-1.0, 1.0]:
						k.tube("wood_big", bp + b * Vector3(s * 0.5, 0.0, 1.0), bp + b * Vector3(s * 0.5, 1.5, 1.0), 0.03, 0.03, 4, false, 0.7)
					k.beam("wood_big", bp + b * Vector3(-0.5, 1.4, 1.0), bp + b * Vector3(0.5, 1.4, 1.0), 0.03, 0.03, false, 0.7)
			Dress.barrel(k, o + b * Vector3(2.8, 0.0, 1.0), yaw, 0.8)
		"pen":
			for i in 12:
				var a := TAU * float(i) / 12.0
				var p := o + b * Vector3(cos(a) * 2.0, 0.0, sin(a) * 1.7)
				k.tube("wood_big", p, p + Vector3.UP * 1.1, 0.06, 0.05, 4, false, 0.7)
				var a2 := TAU * float(i + 1) / 12.0
				var p2 := o + b * Vector3(cos(a2) * 2.0, 0.0, sin(a2) * 1.7)
				for y: float in [0.45, 0.85]:
					k.beam("wood_big", p + Vector3.UP * y, p2 + Vector3.UP * y, 0.05, 0.05, false, 0.7)
			k.kit.box("wood_big", o + b * Vector3(-1.0, 0.3, 0.0), Vector3(1.0, 0.4, 0.5), b, false, 0.75)
			k.kit.box("chalk", o + b * Vector3(0.8, 0.15, 0.6), Vector3(0.9, 0.3, 0.7), b, false, 0.85)
			for i in 3:
				var sp := o + b * Vector3(rng.randf_range(-0.8, 1.0), 0.0, rng.randf_range(-0.8, 0.8))
				var sb := Basis(Vector3.UP, rng.randf() * TAU)
				k.kit.box("chalk", sp + Vector3.UP * 0.5, Vector3(0.5, 0.45, 0.8), sb, false, 0.8)
				k.kit.box("dark", sp + sb * Vector3(0.0, 0.62, -0.5), Vector3(0.22, 0.24, 0.3), sb, false, 0.5)
				for s: float in [-1.0, 1.0]:
					k.kit.box("dark", sp + sb * Vector3(s * 0.18, 0.12, 0.28), Vector3(0.08, 0.25, 0.08), sb, false, 0.5)
					k.kit.box("dark", sp + sb * Vector3(s * 0.18, 0.12, -0.28), Vector3(0.08, 0.25, 0.08), sb, false, 0.5)
		"smith":
			k.kit.box("brick_big", o + b * Vector3(-1.0, 0.6, 0.0), Vector3(1.4, 1.2, 1.2), b, true, 0.8)
			k.kit.box("brick_big", o + b * Vector3(-1.0, 1.7, 0.2), Vector3(0.6, 1.0, 0.6), b, false, 0.8)
			k.fire(o + b * Vector3(-1.0, 1.25, -0.2), 0.45, 1.3)
			k.kit.box("iron", o + b * Vector3(0.8, 0.5, 0.0), Vector3(0.6, 0.35, 0.3), b, true, 0.55)
			k.kit.box("wood_big", o + b * Vector3(0.8, 0.2, 0.0), Vector3(0.5, 0.4, 0.5), b, false, 0.7)
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 2.0, 0.0, -1.0), o + b * Vector3(s * 2.0, 2.2, -1.0), 0.07, 0.07, 5, false, 0.7)
			k.beam("wood_big", o + b * Vector3(-2.0, 2.2, -1.0), o + b * Vector3(2.0, 2.2, 0.8), 0.1, 0.1, false, 0.7)
			k.kit.box("wood_big", o + b * Vector3(0.0, 2.3, -0.1), Vector3(4.4, 0.1, 2.0), b * Basis(Vector3.RIGHT, 0.25), false, 0.65)
			for i in 4:
				k.tube("iron", o + b * Vector3(1.6 + 0.2 * float(i), 1.6, -1.0), o + b * Vector3(1.6 + 0.2 * float(i), 0.9, -1.0), 0.03, 0.02, 4, false, 0.55)
			Dress.barrel(k, o + b * Vector3(2.4, 0.0, 0.9), yaw, 0.9)
		"grave":
			for i in 3:
				for j in 3:
					var gp := o + b * Vector3(-1.4 + 1.4 * float(j), 0.0, -1.2 + 1.2 * float(i))
					k.kit.box("cave_moss", gp + Vector3.UP * 0.1, Vector3(0.7, 0.2, 1.4), b, false, 0.8)
					k.kit.box("stone_big", gp + b * Vector3(0.0, 0.45, -0.7), Vector3(0.45, 0.9 + 0.2 * rng.randf(), 0.14), b * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), false, 0.85)
			k.tube("iron", o + b * Vector3(2.4, 0.0, 0.0), o + b * Vector3(2.4, 2.0, 0.0), 0.04, 0.04, 4, false, 0.6)
			k.kit.lantern(o + b * Vector3(2.4, 2.18, 0.0), Vector3(0.22, 0.3, 0.22), b)
		_:
			for i in 3:
				var cp := o + b * Vector3(-1.4 + 1.0 * float(i), 0.0, 0.8)
				Dress.crate(k, cp, yaw + float(i) * 0.3, 0.8)
				if i != 1:
					Dress.crate(k, cp + Vector3.UP * 0.8, yaw + float(i), 0.6)
			k.kit.box("wood_big", o + b * Vector3(0.3, 0.8, -0.8), Vector3(2.4, 0.1, 1.0), b, false, 0.8)
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 1.1 + 0.3, 0.0, -0.8), o + b * Vector3(s * 1.1 + 0.3, 2.3, -0.8), 0.05, 0.05, 4, false, 0.7)
			k.kit.box("chalk", o + b * Vector3(0.3, 2.3, -0.5), Vector3(2.8, 0.06, 1.6), b * Basis(Vector3.RIGHT, 0.2), false, 0.8)
			for i in 6:
				k.kit.box("wax", o + b * Vector3(-0.6 + 0.35 * float(i), 0.92, -0.8), Vector3(0.22, 0.14 + 0.1 * rng.randf(), 0.2), Basis(Vector3.UP, rng.randf() * TAU), false, 0.9)


static var _walks: Array = []


## The reach towns' villager walks (village_reach_towns.gd NODES / EDGES): the distance from `p` to the nearest.
static func _town_walk_dist(p: Vector2) -> float:
	if _walks.is_empty():
		var src := (load("res://core/life/village/village_reach_towns.gd") as GDScript).get_script_constant_map()
		var nodes: Dictionary = src.get("NODES", {})
		for e: Array in src.get("EDGES", []):
			if nodes.has(e[0]) and nodes.has(e[1]):
				_walks.append([nodes[e[0]] as Vector2, nodes[e[1]] as Vector2])
	var best := INF
	for w: Array in _walks:
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best

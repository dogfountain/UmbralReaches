extends RefCounted
## Realm module "yards" (the world pass, after "dress"): the towns' backyards and edges, lived in. Hearthward, Reedholm,
## Fallowmere and Lastlight each get 10-16 yard scenes on open ground inside their circle: washing on a line between
## poles, a kitchen garden of beds and stakes, an animal pen (a fence ring, hay, a trough, sheep or pigs), a smith's lean-to
## (anvil, a forge with a fire, a tool rack, barrels), a small graveyard (rows of markers, a lantern), a market corner
## (crate stacks, a table under a hung awning, goods). Placed after every collider, lane and site exists: the ground must be
## open terrain (a ray lands on the height grid, not on a roof), 3.6 x 3.6 x 2.4 m free of any WORLD collider, off the walk
## lanes and the ways, outside every registered site. Scenes are built per 56 m cell (one kit, a handful of meshes and one flame MultiMesh for all its scenes), faded
## at 120 m; nothing is solid except fences and stands' bodies are not needed (nothing blocks a lane). Build-time only.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")

const TOWNS := [[Vector2(6.0, 38.0), 34.0, 16], [Vector2(-311.0, 281.0), 30.0, 11], [Vector2(-160.0, 300.0), 34.0, 12], [Vector2(324.5, 53.5), 40.0, 14]]
const KINDS := ["washing", "garden", "pen", "smith", "grave", "market", "garden", "pen", "washing"]


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
		var n := 0
		var tries := 0
		while n < want and tries < want * 40:
			tries += 1
			var a := rng.randf() * TAU
			var p := c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r * 0.95
			if not _open(space, q, p, made):
				continue
			var g := WK.h(p.x, p.y)
			var kind := String(KINDS[(n + tries) % KINDS.size()])
			if kind == "grave" and p.distance_to(c) < r * 0.6:
				kind = "garden"
			var key := Vector2i(floori(p.x / 56.0), floori(p.y / 56.0))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append([Vector3(p.x, g, p.y), kind, rng.randf() * TAU])
			made.append(p)
			n += 1
		total += n
	for key: Vector2i in cells:
		var k := WK.new()
		k.setup(root, "Yards_%d_%d" % [key.x, key.y], 9400 + key.x * 17 + key.y)
		for sc: Array in (cells[key] as Array):
			_scene(k, String(sc[1]), sc[0] as Vector3, float(sc[2]))
		k.commit(120.0)
	print("REALM yards: %d scenes in %d towns, %d kits" % [total, TOWNS.size(), cells.size()])


func _open(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, p: Vector2, made: Array[Vector2]) -> bool:
	for m: Vector2 in made:
		if m.distance_to(p) < 9.0:
			return false
	if RealmLayout.path_dist(p) < 3.5 or WK.wet(p.x, p.y) or Zones.lane_dist(p) < 3.2:
		return false
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -20.0, p.y), Layers.WORLD))
	if hit.is_empty() or absf((hit.position as Vector3).y - WK.h(p.x, p.y)) > 0.6:
		return false
	var span := WK.span(p, Vector2(2.0, 2.0), 0.0)
	if span.x == INF or span.y - span.x > 0.7:
		return false
	for st: Dictionary in WorldLanes.sites:
		if WorldLanes.site_hits_rect(st, Rect2(p - Vector2(2.4, 2.4), Vector2(4.8, 4.8)), 0.6):
			return false
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, WK.h(p.x, p.y) + 1.5, p.y))
	return space.intersect_shape(q, 1).is_empty()


func _scene(k, kind: String, o: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rng: RandomNumberGenerator = k.rng
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
			k.kit.box("glow", o + b * Vector3(2.4, 2.1, 0.0), Vector3(0.22, 0.3, 0.22), b, false, 1.0)
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

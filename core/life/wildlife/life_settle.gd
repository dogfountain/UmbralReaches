extends RefCounted
## Life where people live (life system; site dressing): moths round the lamplighter's lamps that burn from
## the first night, a few rats round the barrels at the Keg's back, the stables' and the salt-shed's walls.
## Life gathers where the light and the people are; the dark beyond stays quiet. Called by life_director.gd.

const Zones := preload("res://core/world/realm/dress_zones.gd")
const RL := preload("res://core/world/realm/realm_land.gd")
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")
const SEED := 4127


static func moths(dir: Node3D, root: Node, counts: Dictionary) -> void:
	if Zones.off():
		return
	var v := root.get_node_or_null("Village")
	if v == null:
		return
	var lamps: Dictionary = v.get("lamps")
	for id: String in ["lamp_keg", "lamp_green_ne", "lamp_green_sw", "lamp_maud", "lamp_rim"]:
		if not lamps.has(id):
			continue
		var at: Vector3 = (lamps[id] as Dictionary).pos
		var n := 5
		var g := LifeKit.group("moth", n)
		g.name = "Moths_" + id
		var r := RandomNumberGenerator.new()
		r.seed = hash(id)
		for i in n:
			g.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, r.randf_range(-0.15, 0.25), 0)))
			var sp := r.randf_range(1.6, 3.6) * (1.0 if r.randf() < 0.5 else -1.0)
			g.multimesh.set_instance_custom_data(i, Color(r.randf_range(0.3, 1.0), sp, r.randf_range(0.12, 0.4), r.randf_range(0.0, TAU)))
		g.multimesh.custom_aabb = AABB(Vector3(-1.8, -1.0, -1.8), Vector3(3.6, 2.2, 3.6))
		g.visibility_range_end = 30.0
		g.visibility_range_end_margin = 4.0
		dir.add_child(g)
		g.global_position = at + Vector3(0, 0.1, 0)
		counts["moth"] = int(counts.get("moth", 0)) + n


static func rats(dir: Node3D, space: PhysicsDirectSpaceState3D, add_group: Callable, _counts: Dictionary) -> void:
	if Zones.off():
		return
	var r := RandomNumberGenerator.new()
	r.seed = SEED + 91
	for e: Array in [["Keg", Vector2(8.6, 28.4)], ["Stables", Vector2(-192.0, 99.8)], ["SaltShed", Vector2(227.6, 108.4)]]:
		var c: Vector2 = e[1]
		var fy := LifePlace.ground(space, c.x, c.y)
		var spots: Array[Vector3] = []
		for k in 20:
			if spots.size() >= 3:
				break
			var q := c + Vector2.from_angle(r.randf() * TAU) * r.randf_range(0.5, 2.6)
			var y := LifePlace.ground(space, q.x, q.y)
			if absf(y - fy) < 0.4 and not RL.in_water(q.x, q.y) and RealmLayout.path_dist(q) > 1.2:
				spots.append(Vector3(q.x, y, q.y))
		if spots.size() < 2:
			continue
		var g := Beasts.new()
		g.name = "Rats_" + String(e[0])
		g.floor_y = fy                       # unset, a fleeing rat's height read NAN
		g.setup("rat", spots, SEED + hash(String(e[0])) % 1000)
		add_group.call(g)

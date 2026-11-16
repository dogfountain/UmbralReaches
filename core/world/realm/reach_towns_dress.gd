extends RefCounted
## The towns' life left lying about (reach_towns.gd calls dress() after the buildings): the yards' clutter from the
## props kit (art/models/props through site_props.gd: barrels, crates, sacks, firewood, benches, troughs, handcarts,
## a market stall), the few warm lights a town is allowed (each one a reason: a hearth, the lantern on the lamp
## tower), and the writings (lore_db.gd, the `# --- the towns ---` block; reach_towns_texts.gd). Positions are world
## xz (reach_towns_plan.gd's ground). No class_name: preload by path.

const SiteProps := preload("res://core/world/realm/site_props.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const SecretsKit := preload("res://core/life/secrets/kit.gd")

## Trodden ground (no grass, no flowers): [x, z, radius] — the yards, the green, the landing's bank, the doors.
const TRODDEN := [
	Vector3(-316.0, 300.0, 5.5), Vector3(-313.0, 288.0, 3.5), Vector3(-313.5, 274.0, 3.5), Vector3(-313.0, 257.4, 3.5),
	Vector3(-322.0, 279.0, 4.0), Vector3(-312.0, 305.0, 3.0),
	Vector3(-146.0, 294.0, 6.0), Vector3(-176.0, 294.5, 6.0), Vector3(-170.0, 303.0, 4.5), Vector3(-138.0, 297.0, 4.0),
	Vector3(-130.0, 313.0, 3.5), Vector3(-188.0, 296.0, 4.0), Vector3(-190.0, 321.0, 5.0),
	Vector3(318.0, 55.0, 7.0), Vector3(326.0, 52.0, 6.0), Vector3(335.0, 52.0, 5.0), Vector3(310.0, 64.0, 6.0),
	Vector3(326.0, 64.0, 6.0), Vector3(342.0, 63.0, 6.0), Vector3(348.0, 52.0, 4.0), Vector3(311.0, 69.0, 5.0),
	Vector3(338.0, 69.0, 4.5), Vector3(304.0, 44.0, 3.5), Vector3(325.0, 72.0, 4.0), Vector3(300.0, 69.5, 5.0),
	Vector3(322.0, 58.0, 10.0), Vector3(312.0, 60.0, 8.0), Vector3(334.0, 58.0, 8.0), Vector3(346.0, 62.0, 7.0),
	Vector3(304.0, 68.0, 6.0), Vector3(316.0, 70.0, 6.0), Vector3(350.0, 56.0, 4.0),
	Vector3(-178.0, 298.0, 7.0), Vector3(-160.0, 296.0, 6.0), Vector3(-144.0, 292.0, 7.0),
]

## [town, prop file, x, z, yaw]
const CLUTTER := [
	# Reedholm: on the bank by the landing and the smokehouse (the decks carry their own baskets and nets)
	["reedholm", "barrel", -318.4, 304.8, 0.3], ["reedholm", "barrel", -317.6, 305.8, 1.2], ["reedholm", "crate", -319.0, 306.0, 0.4],
	["reedholm", "firewood", -327.8, 283.6, 0.0], ["reedholm", "firewood", -322.8, 275.4, 1.57], ["reedholm", "sack", -323.4, 282.4, 0.2],
	["reedholm", "bench", -314.4, 304.8, 1.4], ["reedholm", "crate", -326.0, 264.6, 0.9], ["reedholm", "barrel", -324.4, 263.8, 0.1],
	# Fallowmere: by the barn's porch and the farmhouse door, on the green
	["fallowmere", "barrel", -183.0, 292.4, 0.0], ["fallowmere", "barrel", -182.2, 293.6, 0.8], ["fallowmere", "sack", -172.0, 293.4, 0.4],
	["fallowmere", "sack", -171.0, 294.2, 1.9], ["fallowmere", "crate", -173.6, 294.0, 0.2], ["fallowmere", "handcart", -165.4, 295.0, -0.5],
	["fallowmere", "bench", -143.2, 289.8, 0.4], ["fallowmere", "firewood", -178.0, 320.4, 0.0], ["fallowmere", "trough", -183.0, 320.6, 1.57],
	["fallowmere", "barrel", -166.0, 304.4, 0.2], ["fallowmere", "bench", -133.0, 293.4, 0.0], ["fallowmere", "firewood", -129.6, 286.4, 1.57],
	# the barn's foot: a woodstack against its west end, sacks and crates at the east, a cart left by the winnowing door
	["fallowmere", "firewood", -193.4, 285.6, 1.57], ["fallowmere", "firewood", -193.4, 281.0, 1.57], ["fallowmere", "sack", -162.8, 287.4, 0.7],
	["fallowmere", "sack", -162.4, 288.6, 2.1], ["fallowmere", "crate", -162.6, 284.8, 0.3], ["fallowmere", "crate", -162.0, 283.6, 1.1],
	["fallowmere", "handcart", -172.0, 274.8, 1.4], ["fallowmere", "barrel", -183.2, 276.4, 0.5], ["fallowmere", "trough", -190.6, 292.6, 0.0],
	# Reedholm's bank: creels and sacks by the walks' steps, a woodpile by the hall's walk
	["reedholm", "sack", -316.8, 271.6, 0.4], ["reedholm", "barrel", -316.6, 276.6, 0.2], ["reedholm", "crate", -319.6, 288.4, 1.0],
	["reedholm", "firewood", -322.8, 263.2, 0.0],
	# Lastlight: the yard, the inn's front, the stable's mouth, the store's door
	["lastlight", "barrel", 322.6, 48.6, 0.2], ["lastlight", "barrel", 321.6, 49.6, 1.1], ["lastlight", "crate", 337.0, 49.4, 0.4],
	["lastlight", "crate", 338.2, 50.2, 1.2], ["lastlight", "bench", 315.4, 53.2, 0.5], ["lastlight", "bench", 320.4, 57.0, -0.4],
	["lastlight", "trough", 327.2, 60.4, 0.0], ["lastlight", "sack", 304.4, 42.2, 0.3], ["lastlight", "sack", 304.0, 43.4, 1.4],
	["lastlight", "crate", 299.4, 48.6, 0.0], ["lastlight", "handcart", 330.0, 70.6, 2.6], ["lastlight", "firewood", 344.4, 70.6, 0.0],
	["lastlight", "barrel", 306.4, 70.2, 0.1], ["lastlight", "barrel", 319.8, 70.4, 0.9],
]

## A market stall where a town sells: [town, glb, x, z, yaw]
const STALLS := [["reedholm", "market_stall_a", -311.4, 306.2, -2.4]]

## [town, x, y over the ground, z, colour, energy, range]: a hearth through a door, the lamp tower's lantern
const LIGHTS := [
	["reedholm", -306.2, 2.6, 271.8, Color(1.0, 0.6, 0.28), 0.6, 7.0],
	["fallowmere", -174.2, 1.8, 305.6, Color(1.0, 0.6, 0.28), 0.6, 7.0],
	["lastlight", 328.0, 2.2, 49.6, Color(1.0, 0.62, 0.3), 0.75, 8.0],
	["lastlight", 347.0, 23.4, 44.0, Color(1.0, 0.72, 0.42), 1.5, 26.0],
	["lastlight", 350.6, 3.2, 62.8, Color(1.0, 0.62, 0.3), 0.7, 10.0],       # the watch's lanterns in the shut gate's court
	["reedholm", -303.6, 2.6, 289.0, Color(1.0, 0.6, 0.28), 0.5, 6.0],      # hearths through the doors of the houses
	["reedholm", -301.0, 2.6, 260.4, Color(1.0, 0.6, 0.28), 0.5, 6.0],
	["reedholm", -324.6, 2.6, 292.4, Color(1.0, 0.6, 0.28), 0.5, 6.0],
	["fallowmere", -178.0, 2.6, 290.4, Color(1.0, 0.64, 0.32), 0.55, 7.0],   # the Reeve's lantern in the barn's porch
]

## [town, lore id, x, y over the ground, z] or [town, lore id, "@piece", local Vector3 in that piece's frame]
const WRITINGS := [
	["reedholm", "town_rh_board", "@RH_Landing", Vector3(-3.4, 1.4, 3.3)],
	["reedholm", "town_rh_lampbook", "@RH_Hall", Vector3(4.6, 2.4, 1.2)],
	["reedholm", "town_rh_grave", -333.4, 0.6, 285.0],
	["fallowmere", "town_fm_tithe", -175.6, 1.6, 293.4],
	["fallowmere", "town_fm_strips", -146.0, 0.6, 336.0],
	["fallowmere", "town_fm_almanac", -168.2, 1.0, 304.4],
	["lastlight", "town_ll_plaque", 352.2, 1.4, 61.2],
	["lastlight", "town_ll_book", 326.4, 1.2, 49.8],
	["lastlight", "town_ll_orders", 335.0, 1.4, 70.8],
	["reedholm", "town_rh_heron", -317.4, 1.2, 296.8],
	["fallowmere", "town_fm_dovecote", -155.4, 1.2, 319.6],
	["lastlight", "town_ll_shrine", "@LL_Shrine", Vector3(0.0, 1.3, 0.9)],
	["lastlight", "town_ll_bridles", "@LL_Stable", Vector3(-2.0, 1.6, -2.6)],
]


static func dress(hosts: Dictionary, _shapes: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var pk := Pilot.prop()
	var by := {}                       # town -> {file -> [Transform3D]}
	for r: Array in CLUTTER:
		var q := Vector2(float(r[2]), float(r[3]))
		if RealmLayout.path_dist(q) < 1.4:
			continue
		var y := _top(space, q)
		var t := Transform3D(Basis(Vector3.UP, float(r[4])).scaled(Vector3.ONE * pk), Vector3(q.x, y, q.y))
		((by.get_or_add(String(r[0]), {}) as Dictionary).get_or_add(String(r[1]), []) as Array).append(t)
	for town: String in by:
		var host: Node3D = hosts[town]
		var k := OssKit.new()
		k.keep_lanes = false
		for file: String in by[town]:
			var xfs: Array = by[town][file]
			for part: Dictionary in SiteProps.parts(file):
				var mmi := OssKit.multimesh(part.mesh, xfs, part.mat, true)
				mmi.name = "Yard_" + file
				mmi.visibility_range_end = 120.0
				mmi.visibility_range_end_margin = 14.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				host.add_child(mmi)
			if file in ["barrel", "crate", "handcart", "firewood", "trough"]:
				var bb := AABB()
				var first := true
				for part2: Dictionary in SiteProps.parts(file):
					var a := (part2.mesh as Mesh).get_aabb()
					bb = a if first else bb.merge(a)
					first = false
				for t2: Transform3D in xfs:
					LK.col_box(k, t2 * (bb.get_center()), bb.size * pk * 0.95, t2.basis.orthonormalized())
		k.commit(host, "YardBody")
	for town2: String in hosts:
		var pm := PropModels.new()
		pm.big = true
		var any := false
		for s: Array in STALLS:
			if String(s[0]) != town2:
				continue
			var q2 := Vector2(float(s[2]), float(s[3]))
			pm.add(String(s[1]) + ".glb", Transform3D(Basis(Vector3.UP, float(s[4])).scaled(Vector3.ONE * pk), Vector3(q2.x, _top(space, q2), q2.y)))
			any = true
		if any:
			pm.commit(hosts[town2], "Stall", true, true)
	SecretsKit.clear_flora(null, TRODDEN)
	for l: Array in LIGHTS:
		var q3 := Vector2(float(l[1]), float(l[3]))
		P._light(hosts[String(l[0])], Vector3(q3.x, RealmLayout.ground(space, q3.x, q3.y) + float(l[2]), q3.y), l[4], float(l[5]), float(l[6]))
	var Towns: Variant = load("res://core/world/realm/reach_towns.gd")
	for w: Array in WRITINGS:
		if w[2] is String:
			var at: Vector3 = Towns.local(String(w[0]), String(w[2]).trim_prefix("@"), w[3])
			if at != Vector3.INF:
				P._lore(hosts[String(w[0])], String(w[1]), at)
			continue
		var q4 := Vector2(float(w[2]), float(w[4]))
		P._lore(hosts[String(w[0])], String(w[1]), Vector3(q4.x, _top(space, q4) + float(w[3]) - 1.0, q4.y))


## The top surface under a point (a deck, a step, the ground).
static func _top(space: PhysicsDirectSpaceState3D, q: Vector2) -> float:
	var gy := RealmLayout.ground(space, q.x, q.y)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, gy + 4.0, q.y), Vector3(q.x, gy - 0.5, q.y), Layers.WORLD))
	return (hit.position as Vector3).y if hit else gy

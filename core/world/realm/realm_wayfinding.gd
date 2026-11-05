extends RefCounted
## r30 world-builder pass (docs/critique/r30/world_builder.md), run from RealmAssets.build after the
## stamp, the flora and the summit dress:
##   lanterns()   waystone lanterns along the three spokes (west_way, east_way, fen_descent): warm,
##                small, unshadowed; 0 lamps lit 134 m of east_way and fen_descent at night
##   cold_glows() a pale coal glint over every unlit brazier (core/world/realm/unkindled_glow.gd)
##   edges()      the world's edges: a band of RockKit cliffs just inside BOUNDS on the open south,
##                west and east sides, so the invisible wall (RealmLand._bounds) stands behind real
##                rock instead of on flat ground; and a rockfall across the Pilgrims' Road beyond
##                each of its two broken gates (the road ran on through them into the wall)
##   climb_tower() a ruined watchtower by the green: a jump-and-grab climb to a vista (zz/world_r30_test)
##   beacon()     landmark light columns (the henge here, the summit from SummitDress), drawn inside
##                the 82 m far plane by core/world/realm/landmark_beacon.gd

const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Glow := preload("res://core/world/realm/unkindled_glow.gd")
const Beacon := preload("res://core/world/realm/landmark_beacon.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")

const LANTERN_PATHS := ["west_way", "east_way", "fen_descent"]
const LANTERN_STEP := 26.0              ## metres between lanterns along a path
const EDGE_STEP := 10.0                 ## cliff spacing along an edge
const EDGE_INSET := 1.4                 ## cliff centre this far inside BOUNDS (their backs touch the wall)
const CLIFF_SIZES := [Vector3(12.0, 8.5, 4.5), Vector3(11.0, 6.5, 4.5)]
const BOULDER := Vector3(2.4, 1.6, 2.0)


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	if root.get_node_or_null("RealmWayfinding") != null:
		return
	var holder := Node3D.new()
	holder.name = "RealmWayfinding"
	root.add_child(holder)
	var space := holder.get_world_3d().direct_space_state
	var nl := lanterns(holder, space)
	var t1 := Time.get_ticks_msec()
	var ne := edges(holder, space)
	var t2 := Time.get_ticks_msec()
	var ng := cold_glows(root)
	var tower := climb_tower(holder, space)
	# the henge reads as "the boss is here" from west_way and the glade: an ember shaft over its hill
	beacon(holder, ThornHenge.C, "thornwarden", Color(1.0, 0.52, 0.46), 46.0, 0.42)
	# r31: the places worth leaving the road for (ground reserved by RealmBosses before the flora)
	var pois := load("res://core/world/realm/realm_pois.gd") as GDScript
	if pois and pois.can_instantiate():
		pois.call("build", root)
	print("REALM wayfinding: %d lanterns (%d ms), %d edge rocks (%d ms), %d cold glows, watchtower at %s (%d ms total)" % [nl, t1 - t0, ne, t2 - t1, ng, tower, Time.get_ticks_msec() - t0])


# --- lanterns ----------------------------------------------------------------------------------

static func lanterns(holder: Node3D, space: PhysicsDirectSpaceState3D) -> int:
	var k := OssKit.new()
	k.keep_lanes = false
	var spots: Array[Vector3] = []
	var side := 1.0
	for path: Dictionary in RealmLayout.PATHS:
		if not String(path.id) in LANTERN_PATHS:
			continue
		var pts: Array = path.pts
		var w := float(path.w)
		var walked := 0.0
		var next := LANTERN_STEP * 0.5
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			var t := (b - a) / maxf(seg, 0.001)
			var n := Vector2(-t.y, t.x)
			while next <= walked + seg:
				var c := a + t * (next - walked)
				next += LANTERN_STEP
				var placed := false
				for flip: float in [side, -side]:
					for extra: float in [1.1, 2.2, 3.4]:
						var q := c + n * flip * (w + extra)
						if _lantern_ok(holder, q):
							var g := RealmLayout.ground(space, q.x, q.y)
							spots.append(Vector3(q.x, g, q.y))
							placed = true
							break
					if placed:
						break
				side = -side
			walked += seg
	for p in spots:
		_lantern(k, holder, p)
	var host := Node3D.new()
	host.name = "WayLanterns"
	holder.add_child(host)
	k.commit(host, "WayLanternBody")
	return spots.size()


static func _lantern_ok(holder: Node3D, q: Vector2) -> bool:
	if RealmLayout.path_dist(q) < 0.6:
		return false
	if not WorldLanes.site_at(q, 0.8).is_empty():
		return false
	# not beside a fire or another lamp that already lights this stretch
	for l in holder.get_tree().get_nodes_in_group(Groups.BRAZIER):
		if Vector2((l as Node3D).global_position.x, (l as Node3D).global_position.z).distance_to(q) < 9.0:
			return false
	return true


static func _lantern(k: OssKit, holder: Node3D, p: Vector3) -> void:
	var yaw := fposmod(p.x * 1.7 + p.z * 0.9, 0.6) - 0.3     # deterministic, per spot
	var b := Basis(Vector3.UP, yaw)
	k.box("stone", p + Vector3.UP * 0.2, Vector3(0.55, 0.6, 0.55), b, true, 0.85)       # plinth, set in the ground
	k.box("stone", p + Vector3.UP * 1.1, Vector3(0.3, 1.4, 0.3), b, true, 0.95)         # the waystone shaft
	k.box("iron", p + Vector3.UP * 1.84, Vector3(0.36, 0.06, 0.36), b, false)
	k.box("glow", p + Vector3.UP * 2.02, Vector3(0.2, 0.28, 0.2), b, false, 0.55)      # the lamp
	k.box("iron", p + Vector3.UP * 2.2, Vector3(0.32, 0.06, 0.32), b, false)
	var l := OmniLight3D.new()
	l.name = "WayLamp"
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 1.0
	l.omni_range = 7.5
	l.shadow_enabled = false
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": 1.0, "r": 7.5, "a": 1.0})
	holder.add_child(l)
	l.global_position = p + Vector3.UP * 2.05
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	l.shadow_enabled = false


# --- unlit braziers ----------------------------------------------------------------------------

static func cold_glows(root: Node) -> int:
	var n := 0
	for b in root.get_tree().get_nodes_in_group(Groups.BRAZIER):
		if _glow_on(b as Node):
			n += 1
	var tree := root.get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)       # the Ossuary's fire and the summit fire come later
	return n


static func _on_node_added(node: Node) -> void:
	if node is Brazier:
		_glow_later.call_deferred(weakref(node))


static func _glow_later(ref: WeakRef) -> void:
	var node := ref.get_ref() as Node
	if node != null and node.is_inside_tree():
		_glow_on(node)


static func _glow_on(b: Node) -> bool:
	if b == null or not (b is Brazier) or b.get_node_or_null("UnkindledGlow") != null:
		return false
	if not Realm.enabled():
		return false
	var g: Node3D = Glow.new()
	g.name = "UnkindledGlow"
	b.add_child(g)
	return true


# --- the world's edges -------------------------------------------------------------------------

static func edges(holder: Node3D, space: PhysicsDirectSpaceState3D) -> int:
	var host := Node3D.new()
	host.name = "EdgeRocks"
	holder.add_child(host)
	var bd := RealmLayout.BOUNDS
	var count := 0
	# [start, end, inward normal, style]
	var runs := [
		[Vector2(bd.position.x, bd.end.y), Vector2(bd.end.x, bd.end.y), Vector2(0, -1), "granite"],          # south: the road plain
		[Vector2(bd.position.x, bd.position.y + 40.0), Vector2(bd.position.x, bd.end.y), Vector2(1, 0), "mossy"],   # west: the Thornwood
		[Vector2(bd.end.x, bd.position.y + 40.0), Vector2(bd.end.x, bd.end.y), Vector2(-1, 0), "mossy"],       # east: the fen
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 30330
	for run: Array in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var inward: Vector2 = run[2]
		var style: String = run[3]
		var n := ceili(a.distance_to(b) / EDGE_STEP)
		for i in n + 1:
			var c := a.lerp(b, float(i) / float(n)) + inward * EDGE_INSET
			c += (b - a).normalized() * rng.randf_range(-1.5, 1.5)
			var g := RealmLayout.ground(space, c.x, c.y)
			var gin := RealmLayout.ground(space, c.x + inward.x * 12.0, c.y + inward.y * 12.0)
			if g - gin > 6.0:
				continue                                  # the land already rises here (the Crowns' foot)
			var along := (b - a).normalized()
			var clash := false
			for u: float in [-7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5]:
				for v: float in [-1.0, 1.5, 3.0]:
					var sp := c + along * u + inward * v
					if not WorldLanes.site_at(sp, 0.8).is_empty():
						clash = true                   # the whole face, not just its centre: no rock in a site
			if clash:
				continue
			# two cliff sizes x four variants per style (RockKit caches one mesh per key: a handful of
			# shared meshes, varied by yaw and scale, not 60 one-offs)
			var size: Vector3 = CLIFF_SIZES[rng.randi() % CLIFF_SIZES.size()]
			var mesh := RockKit.cliff(rng.randi_range(0, 3), size, style)
			var yaw := atan2(inward.x, inward.y) + rng.randf_range(-0.18, 0.18)
			var s := rng.randf_range(0.9, 1.15)
			var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(c.x, minf(g, gin) - 0.8, c.y))
			_spawn(host, mesh, xf, true, 140.0)
			count += 1
			# a few boulders spilled in front of the face
			for j in 2:
				var q := c + inward * rng.randf_range(3.2, 5.5) + (b - a).normalized() * rng.randf_range(-4.0, 4.0)
				if RealmLayout.path_dist(q) < 1.5 or not WorldLanes.site_at(q, 2.0).is_empty():
					continue
				var bm := RockKit.boulder(rng.randi_range(0, 3), BOULDER, style)
				var gq := RealmLayout.ground(space, q.x, q.y)
				var bs := rng.randf_range(0.7, 1.25)
				_spawn(host, bm, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bs, bs, bs)), Vector3(q.x, gq - 0.25, q.y)), true, 90.0)
				count += 1
	count += _road_falls(host, space, rng)
	return count


## The Pilgrims' Road ran on through its two broken gates (x +-100) for 10 m into the invisible wall.
## A rockfall now buries it just past each gate: the road vanishes under the slide.
static func _road_falls(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> int:
	var n := 0
	for path: Dictionary in RealmLayout.PATHS:
		if path.id != "road":
			continue
		var pts: Array = path.pts
		for end: Array in [[pts[0], pts[1]], [pts[pts.size() - 1], pts[pts.size() - 2]]]:
			var tip: Vector2 = end[0]
			var back: Vector2 = end[1]
			var along := (tip - back).normalized()         # outward, along the road
			var across := Vector2(-along.y, along.x)
			for k in 6:
				var q := tip - along * rng.randf_range(-1.0, 2.6) + across * rng.randf_range(-3.2, 3.2)
				var g := RealmLayout.ground(space, q.x, q.y)
				var m := RockKit.boulder(rng.randi_range(0, 3), BOULDER, "granite")
				var bs := rng.randf_range(1.0, 1.5)
				_spawn(host, m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bs, bs, bs)), Vector3(q.x, g - 0.3, q.y)), true, 120.0)
				n += 1
			# the slide's tongue: a slab of cliff tipped across the road behind the boulders
			var c := tip + along * 2.6
			var g2 := RealmLayout.ground(space, c.x, c.y)
			var cm := RockKit.cliff(1, CLIFF_SIZES[1], "granite")
			var yaw := atan2(-along.x, -along.y)
			_spawn(host, cm, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.12), Vector3(c.x, g2 - 0.6, c.y)), true, 140.0)
			n += 1
	return n


static var _hulls := {}


## RockKit.spawn, but the collision hull is made from the LOD0 vertices directly (Jolt builds the
## hull natively: ~0.1 ms) instead of Mesh.create_convex_shape's simplified hull (~37 ms a mesh,
## uncached: 0.6 s for this pass's 16 meshes).
static func _spawn(parent: Node3D, mesh: ArrayMesh, xf: Transform3D, collide: bool, vis_end: float) -> MeshInstance3D:
	var mi := RockKit.spawn(parent, mesh, xf, false, vis_end)
	if not collide:
		return mi
	var sh: ConvexPolygonShape3D = _hulls.get(mesh)
	if sh == null:
		var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pts := PackedVector3Array()
		for i in range(0, v.size(), 3):
			pts.append(v[i])
		sh = ConvexPolygonShape3D.new()
		sh.points = pts
		_hulls[mesh] = sh
	var body := StaticBody3D.new()
	body.name = "RockBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	return mi


## A landmark beacon (r30): a thin light column rising from `ceiling` metres above `at` (clear of the
## fight under it), the "where do I go" read from across the map. Alpha-blended, not additive: it
## reads as a warm line against the bright vortex (an additive column vanished into it), unshaded
## and under the glow threshold. Not built if `boss_id` is already slain; it narrows and goes out
## when that boss falls.
static func beacon(parent: Node3D, at: Vector3, boss_id: String, col: Color, height: float, radius: float, ceiling := 9.0) -> Node3D:
	if boss_id != "" and Travel.bosses_slain.has(boss_id):
		return null
	var root: Node3D = Beacon.new()
	root.name = "Beacon_" + boss_id
	root.set("anchor", at + Vector3.UP * ceiling)       # drawn inside the 82 m far plane (landmark_beacon.gd)
	parent.add_child(root)
	for layer: Array in [[radius, 0.5, 1.0], [radius * 2.6, 0.1, 0.85]]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = float(layer[0]) * 0.55
		cyl.top_radius = float(layer[0])
		cyl.height = height
		cyl.radial_segments = 10
		cyl.rings = 1
		cyl.cap_top = false
		cyl.cap_bottom = false
		mi.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		m.albedo_texture = _fade_tex()
		var c := col * float(layer[2])
		c.a = float(layer[1])
		m.albedo_color = c
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.extra_cull_margin = 20.0
		mi.position = Vector3(0, height * 0.5, 0)
		root.add_child(mi)
	if boss_id != "":
		Events.boss_slain.connect(func(id: String) -> void:
			if id != boss_id or not is_instance_valid(root):
				return
			var tw := root.create_tween()
			tw.tween_property(root, "scale", Vector3(0.02, 1.0, 0.02), 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(root.queue_free))
	return root


## Vertical alpha ramp for the beacon: fades in above its foot and out towards its top.
static var _ftex: GradientTexture2D
static func _fade_tex() -> GradientTexture2D:
	if _ftex:
		return _ftex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	_ftex = GradientTexture2D.new()
	_ftex.gradient = g
	_ftex.fill_from = Vector2(0, 1)
	_ftex.fill_to = Vector2(0, 0)
	_ftex.width = 4
	_ftex.height = 64
	return _ftex


# --- a climb for a vista -----------------------------------------------------------------------

const TOWER_AT := Vector2(19.0, 10.4)        ## by the Keg, on the rift's south shoulder: open sky, off the paths
const TOWER_SITE := 4.7                      ## half size of its reserved site (tower + plinth + rubble)
const TOWER_HALF := 2.5                      ## a 5 x 5 m masonry stump
const TOWER_TOP := 8.1                       ## the last block (6.8) + 1.3: a grab onto the top
const STEP_RISE := 1.7                       ## each buttress block: above the vault (1.25), in the grab (1.1-2.25)

## The ruined watchtower (r30: "nothing to climb for a vista"): a solid masonry stump by the green
## with four broken buttress blocks stepping up one face, each 1.7 m above the last (too high to
## vault, a jump-and-grab), then a turn to the wall and a last grab onto a parapeted top 8.1 m up that
## looks over the green, the rift and east_way.
## Its ground is reserved by reserve_tower() (RealmBosses, before the stamp and the flora), so the
## stamp levels it and nothing grows or is placed there. Returns its centre.
static func climb_tower(holder: Node3D, space: PhysicsDirectSpaceState3D) -> Vector3:
	var c := TOWER_AT
	var g := INF
	for o: Vector2 in [Vector2.ZERO, Vector2(TOWER_HALF, TOWER_HALF), Vector2(-TOWER_HALF, TOWER_HALF), Vector2(TOWER_HALF, -TOWER_HALF), Vector2(-TOWER_HALF, -TOWER_HALF)]:
		g = minf(g, RealmLayout.ground(space, c.x + o.x, c.y + o.y))
	# the climb face looks at the spawn fire (local +z), so the route is seen from the green
	var to := Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z) - c
	var yaw := atan2(to.x, to.y)
	var b := Basis(Vector3.UP, yaw)
	var o3 := Vector3(c.x, g, c.y)
	var at := func(v: Vector3) -> Vector3: return o3 + b * v
	var k := OssKit.new()
	k.keep_lanes = false
	var foot := -0.6
	k.box("stone", at.call(Vector3(0, (TOWER_TOP + foot) * 0.5, 0)), Vector3(TOWER_HALF * 2.0, TOWER_TOP - foot, TOWER_HALF * 2.0), b, true, 0.86)
	k.box("stone", at.call(Vector3(0, 0.3, 0)), Vector3(TOWER_HALF * 2.0 + 0.6, 1.2, TOWER_HALF * 2.0 + 0.6), b, true, 0.78)    # battered plinth
	# string courses and slit windows (dark), for scale
	for y: float in [3.2, 6.4]:
		k.box("stone", at.call(Vector3(0, y, 0)), Vector3(TOWER_HALF * 2.0 + 0.16, 0.22, TOWER_HALF * 2.0 + 0.16), b, false, 0.95)
	for f: Vector3 in [Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		for y: float in [4.2, 6.6]:
			var wp: Vector3 = f * (TOWER_HALF + 0.01) + Vector3(0, y, 0)
			k.box("dark", at.call(wp), Vector3(0.3 if f.x == 0.0 else 0.05, 1.1, 0.05 if f.x == 0.0 else 0.3), b, false)
	# the climb: four buttress blocks along the +z face (the last one's back is the tower wall: turn and grab)
	var blocks: Array[AABB] = []
	for n in 4:
		var x0 := -TOWER_HALF + 0.1 + 1.2 * float(n)
		blocks.append(AABB(Vector3(x0, foot, TOWER_HALF - 0.05), Vector3(1.2, STEP_RISE * float(n + 1) - foot, 1.05)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7711
	for bb in blocks:
		k.box("stone", at.call(bb.get_center()), bb.size, b, true, rng.randf_range(0.8, 0.95))
		# a chipped, sloping cap on each (visual only; the collision top stays flat to stand on)
		var top := bb.get_center() + Vector3(0, bb.size.y * 0.5 + 0.05, 0)
		k.box("stone", at.call(top), Vector3(bb.size.x + 0.08, 0.12, bb.size.z + 0.08), b, false, 0.98)
	# parapet round the top (local frame boxes: centre, size), open over the last block (+z face,
	# x 0.9 .. 2.5: 1.25 m clear inside the +x run)
	var t := TOWER_TOP
	var w := TOWER_HALF
	var ph := 0.85
	var walls := [
		[Vector3(0, t + ph * 0.5, -w + 0.175), Vector3(w * 2.0, ph, 0.35)],
		[Vector3(-0.8, t + ph * 0.5, w - 0.175), Vector3(3.4, ph, 0.35)],
		[Vector3(-w + 0.175, t + ph * 0.5, 0), Vector3(0.35, ph, w * 2.0)],
		[Vector3(w - 0.175, t + ph * 0.5, 0), Vector3(0.35, ph, w * 2.0)],
	]
	for wl: Array in walls:
		k.box("stone", at.call(wl[0]), wl[1], b, true, 0.9)
	# broken merlons on the two far walls
	for i in 4:
		if rng.randf() < 0.3:
			continue
		var u := -w + 0.6 + 1.25 * float(i)
		var mh := rng.randf_range(0.35, 0.6)
		k.box("stone", at.call(Vector3(u, t + ph + mh * 0.5, -w + 0.175)), Vector3(0.6, mh, 0.4), b, true, 0.92)
		k.box("stone", at.call(Vector3(-w + 0.175, t + ph + mh * 0.5, u)), Vector3(0.4, mh, 0.6), b, true, 0.92)
	# fallen masonry at the foot (the tower's missing crown)
	for i in 5:
		var q := Vector3(rng.randf_range(-w - 2.0, -w - 0.6), 0.2, rng.randf_range(-w, w))      # the far (-x) side, off the climb
		k.box("stone", at.call(q), Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 1.0)), b * Basis(Vector3.UP, rng.randf() * TAU), true, 0.8)
	var host := Node3D.new()
	host.name = "Watchtower"
	host.set_meta("site", "wb_watchtower")
	holder.add_child(host)
	k.commit(host, "WatchtowerBody")
	var route: Array[Vector3] = []                 # the stand points, bottom to top (zz/world_r30_test checks them)
	for bb in blocks:
		route.append(at.call(bb.get_center() + Vector3(0, bb.size.y * 0.5, 0)))
	route.append(at.call(Vector3(1.8, TOWER_TOP, w - 0.8)))
	host.set_meta("route", route)
	host.set_meta("approach", at.call(Vector3(blocks[0].get_center().x, 0.0, TOWER_HALF + 2.6)))
	return o3


## Reserve the watchtower's ground (called by RealmBosses.build, before the stamp and the flora).
static func reserve_tower(root: Node) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var g := RealmLayout.ground(space, TOWER_AT.x, TOWER_AT.y)
	WorldLanes.register_site("wb_watchtower", Rect2(TOWER_AT - Vector2(TOWER_SITE, TOWER_SITE), Vector2(TOWER_SITE, TOWER_SITE) * 2.0), g)

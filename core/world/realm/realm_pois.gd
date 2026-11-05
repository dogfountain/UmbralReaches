extends RefCounted
## r31 world pass (docs/enshrouded/world.md): places worth leaving the road for. Enshrouded fills
## its map with hand-built points of interest -- a ruin with a chest in the loft, a tower you climb
## for the view and glide down from, a camp in a clearing that something big has taken over -- and
## lets the player see them from far off. These are ours, in the valley's own story:
##
##   belfry    The Drowned Belfry (Hollow Fen): Saint Corvin's bell-tower, sunk to its knees in the
##             fen. A plank causeway on posts from east_way; a rubble-and-ledge climb up its face to
##             the open bell stage (12 m): a chest, the cracked bell, a perch to glide off.
##   charcoal  The Charcoal Hollow (deep Thornwood): the Founder's charcoal-burners' clearing, three
##             clamps still smouldering, a lean-to, a woodpile and an axe in a stump. Its clearing is
##             a fighting floor (a mini-boss site).
##   almonry   The Almonry (the meadow between Hearthward and the fen): the abbey's roofless bread
##             house for the road. A broken stair inside and a jump to the loft, where the almoner's
##             iron chest still sits. Its walled yard is a fighting floor.
##   spire     The Watchers' Spire (under the Crowns): a 16 m watch-tower of the Order, its stone
##             stair wrapped round the outside and broken twice (two jump-and-grabs). The beacon cage,
##             a chest and the best perch in the valley are on its roof.
##
## API for the other systems (groups and metas on plain Node3Ds; nothing to import):
##   GROUP_POI       "world_poi"      every place: meta poi (id), title, centre (Vector3), radius
##   GROUP_MINIBOSS  "miniboss_site"  a fighting floor at its centre: meta id, poi, radius, region,
##                                    floor_y; keep the fight inside `radius` (open, level, no camp).
##                                    The same node is in "guardian_site" (Guardians.GROUP) with metas
##                                    guardian (which one holds it) and site_key, so a guardian and its
##                                    escort hold each place
##   GROUP_GRAPPLE   "grapple_anchor" the Tether line's anchors (core/player/grapple_anchor.gd, the
##                                    combat pass's API): meta reach, land (local offset of where the
##                                    haul ends), plus stand (world point it is meant to put you on)
##   GROUP_UPDRAFT   "updraft"        hot air the cloak-glide rides (Player._updraft): meta radius,
##                                    height, lift -- the charcoal clamps breathe one each
##   GROUP_GLIDE     "glide_perch"    a high lip worth jumping off: meta facing (Vector3, flat), drop (m)
##   chests: core/world/realm/loot_chest.gd (group "loot_chest")
## miniboss_sites(tree) / anchors(tree, group) return them as Dictionaries.
## Ground is reserved by reserve() (RealmBosses, before the stamp and the flora, like the r30
## watchtower), so the stamp levels it and nothing else is placed there; build() runs after the
## flora (RealmWayfinding.build) and dresses each place with its own overgrowth.

const RockKit := preload("res://core/world/realm/rock_kit.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
## Tree-free round kept round a place so it reads from afar and its top has a view (RealmFlora).
const RealmFloraWater := -0.9          ## RealmFlora.WATER_Y: the fen's pools
const VISTA := {"belfry": 13.0, "spire": 36.0}

const GROUP_POI := "world_poi"
const GROUP_MINIBOSS := "miniboss_site"
const GROUP_GRAPPLE := "grapple_anchor"          ## the Tether line's group (core/player/grapple_anchor.gd)
const GROUP_GLIDE := "glide_perch"
const GROUP_GUARDIAN := "guardian_site"           ## core/life/encounters/guardians.gd (the enemies pass)
const GROUP_UPDRAFT := "updraft"                  ## the cloak-glide's lift (Player._updraft)
const SID := "world_pois"

## [prefer xz, search radius, half extents, max ground rise, title, banner line, region]
const POIS := {
	"belfry": [Vector2(82.0, -18.0), 14.0, Vector2(6.0, 6.0), 1.2, "The Drowned Belfry", "the bell that rang for the sunk", "fen"],
	"charcoal": [Vector2(-86.0, -62.0), 34.0, Vector2(8.0, 8.0), 3.2, "The Charcoal Hollow", "three clamps still burning", "thornwood"],
	"almonry": [Vector2(46.0, 40.0), 12.0, Vector2(8.5, 8.0), 1.3, "The Almonry", "one loaf, one blessing, one night", "road"],
	"spire": [Vector2(-52.0, -100.0), 16.0, Vector2(6.5, 6.5), 2.2, "The Watchers' Spire", "the Order kept watch on the sky", "crags"],
}
const CAMP_CLEAR := 9.0                 ## metres between a place's footprint and a camp's centre

## Loot per chest (ItemDB ids; see loot_chest.gd for the gear roll).
const LOOT := {
	"belfry_bell": ["iron", {"grave_ash": 14, "relic_fragment": 1}],
	"charcoal_box": ["wood", {"grave_ash": 8}],
	"almonry_loft": ["iron", {"grave_ash": 12, "relic_fragment": 1}],
	"spire_cage": ["reliquary", {"grave_ash": 20, "relic_fragment": 2}],
}

static var spots := {}                  ## poi id -> {at: Vector3 (centre, ground), yaw, rect}
static var built: Array[String] = []    ## last build (tests)
static var causeway: Array = []         ## the belfry causeway's xz points (tests)


# --- reserve (RealmBosses, before stamp and flora) ---------------------------------------------

static func reserve(root: Node) -> void:
	spots.clear()
	causeway.clear()
	Flora.tree_clear.clear()
	var skip: PackedStringArray = []
	for a in OS.get_cmdline_user_args():                  # A/B switch for perf and placement checks:
		if a == "--no-r31-pois":                          # --no-r31-pois (all) or --no-r31-pois=belfry,spire
			return
		if a.begins_with("--no-r31-pois="):
			skip = a.trim_prefix("--no-r31-pois=").split(",")
	var space := (root as Node3D).get_world_3d().direct_space_state
	var camps: Array[Vector2] = []
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		camps.append(Vector2((c.at as Vector3).x, (c.at as Vector3).z))
	# the Thornwood's natural clearings (RealmFlora's stand noise, _tree_mod) are where the deer
	# graze (core/life/wildlife): the burners cut their own clearing in the standing wood instead
	var stands := FastNoiseLite.new()
	stands.seed = 77
	stands.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stands.frequency = 0.035
	stands.fractal_octaves = 2
	for id: String in POIS:
		if id in skip:
			continue
		var d: Array = POIS[id]
		var half: Vector2 = d[2]
		var ok := func(q: Vector2) -> bool:
			if id != "belfry":
				# dry ground: off the fen's pools and their shores (the belfry alone stands in them)
				for ix in 3:
					for iz in 3:
						var gq := RealmLayout.ground(space, q.x - half.x + half.x * ix, q.y - half.y + half.y * iz)
						if gq < RealmFloraWater + 0.08:
							return false
			if id == "charcoal":
				if stands.get_noise_2d(q.x, q.y) < -0.2:
					return false
			for c in camps:
				var dx := maxf(absf(c.x - q.x) - half.x, 0.0)
				var dz := maxf(absf(c.y - q.y) - half.y, 0.0)
				if Vector2(dx, dz).length() < CAMP_CLEAR:
					return false
			return true
		var pref: Vector2 = d[0]
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--poi-prefer=" + id + ":"):
				var f := a.split(":")
				pref = Vector2(float(f[1]), float(f[2]))
		var q := LK.search_spot(space, pref, d[1], half, 1.5, d[3], [], 2.0, ok)
		if q == Vector2.INF:
			print("REALM_POI skip %s: no clear ground near %s" % [id, d[0]])
			continue
		var rect := Rect2(q - half, half * 2.0)
		var lo := INF
		for ix in 5:
			for iz in 5:
				lo = minf(lo, RealmLayout.ground(space, rect.position.x + rect.size.x * ix * 0.25, rect.position.y + rect.size.y * iz * 0.25))
		var yaw := _yaw_for(id, q)
		spots[id] = {"at": Vector3(q.x, lo, q.y), "yaw": yaw, "rect": rect}
		WorldLanes.register_site("poi_" + id, rect, lo + 0.05, lo)
		if VISTA.has(id):
			Flora.tree_clear.append([q, float(VISTA[id])])
	if spots.has("belfry"):
		_reserve_causeway(space)
	print("REALM_POI reserved %s" % [spots.keys()])


## Each place faces where the player comes from.
static func _yaw_for(id: String, q: Vector2) -> float:
	var to := Vector2.ZERO
	match id:
		"belfry":
			to = _nearest_on_path("east_way", q) - q          # the causeway comes from east_way
		"almonry":
			to = Vector2(q.x - 4.0, q.y - 14.0) - q            # the door looks back at the village
		"spire":
			to = Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z) - q
		_:
			to = Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z) - q
	return atan2(to.x, to.y)


static func _nearest_on_path(path_id: String, p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	var pts := LK.path_pts(path_id)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var c := a + ab * t
		if c.distance_to(p) < bd:
			bd = c.distance_to(p)
			best = c
	return best


## A plank causeway on posts from the edge of east_way to the belfry's climb face.
static func _reserve_causeway(_space: PhysicsDirectSpaceState3D) -> void:
	var s: Dictionary = spots.belfry
	var at: Vector3 = s.at
	var c := Vector2(at.x, at.z)
	var fwd := Vector2(sin(float(s.yaw)), cos(float(s.yaw)))
	var start := _nearest_on_path("east_way", c)
	start += (c - start).normalized() * 2.4                 # off the path's edge
	var end := c + fwd * 6.2                                 # just short of the climb rubble
	if start.distance_to(end) < 4.0:
		return
	var mid := (start + end) * 0.5 + Vector2(-(end - start).y, (end - start).x).normalized() * 2.0   # a slight dog-leg
	causeway = [start, mid, end]
	WorldLanes.register_lane("poi_causeway", causeway, 0.9)


# --- build (after the flora) -------------------------------------------------------------------

static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	built.clear()
	if root.get_node_or_null("RealmPois") != null:
		return
	var holder := Node3D.new()
	holder.name = "RealmPois"
	root.add_child(holder)
	var space := holder.get_world_3d().direct_space_state
	for id: String in spots:
		var s: Dictionary = spots[id]
		var host := Node3D.new()
		host.name = "Poi_" + id
		host.set_meta("site", "poi_" + id)
		holder.add_child(host)
		host.add_to_group(GROUP_POI)
		var d: Array = POIS[id]
		host.set_meta("poi", id)
		host.set_meta("title", d[4])
		host.set_meta("line", d[5])
		host.set_meta("centre", s.at)
		host.set_meta("radius", (d[2] as Vector2).length() + 4.0)
		match id:
			"belfry":
				_belfry(host, space, s)
			"charcoal":
				_charcoal(host, space, s)
			"almonry":
				_almonry(host, space, s)
			"spire":
				_spire(host, space, s)
		built.append(id)
	# r33: the places are named by the zone discovery (realm_discovery.gd: regions + subzones, the
	# carved banner, Events.region_discovered); world events (world_events.gd) pick their sites here
	if root.get_node_or_null("Discovery") == null:
		var dsc: Node = (load("res://core/world/realm/realm_discovery.gd") as GDScript).new()
		dsc.name = "Discovery"
		root.add_child(dsc)
	if root.get_node_or_null("WorldEvents") == null:
		var we: Node = (load("res://core/world/world_events.gd") as GDScript).new()
		we.name = "WorldEvents"
		root.add_child(we)
	print("REALM_POI built %s in %d ms" % [built, Time.get_ticks_msec() - t0])


## The fighting floors (for the mini-boss spawner): [{id, poi, at, radius, region, floor_y}].
static func miniboss_sites(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in tree.get_nodes_in_group(GROUP_MINIBOSS):
		var m := n as Node3D
		out.append({"id": m.get_meta("id"), "poi": m.get_meta("poi"), "at": m.global_position,
			"radius": m.get_meta("radius"), "region": m.get_meta("region"), "floor_y": m.get_meta("floor_y")})
	return out


## Grapple points or glide perches: [{at, node, ...metas}].
static func anchors(tree: SceneTree, group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in tree.get_nodes_in_group(group):
		var d := {"at": (n as Node3D).global_position, "node": n}
		for k: StringName in n.get_meta_list():
			d[String(k)] = n.get_meta(k)
		out.append(d)
	return out


# --- shared pieces -----------------------------------------------------------------------------

static func _xf(s: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(s.yaw)), s.at)


static func _miniboss(host: Node3D, id: String, at: Vector3, radius: float, region: String, guardian := "") -> Node3D:
	var m := Node3D.new()
	m.name = "MinibossSite"
	host.add_child(m)
	m.global_position = at
	m.add_to_group(GROUP_MINIBOSS)
	m.add_to_group(GROUP_GUARDIAN)                   # the enemies pass's guardians stand here
	m.set_meta("site_key", "poi_" + id)
	if guardian != "":
		m.set_meta("guardian", guardian)
	m.set_meta("id", id)
	m.set_meta("poi", String(host.get_meta("poi")))
	m.set_meta("radius", radius)
	m.set_meta("region", region)
	m.set_meta("floor_y", at.y)
	return m


## Of the local offsets, the level, open spot farthest from any camp (a fighting floor of radius r).
static func _open_floor(space: PhysicsDirectSpaceState3D, xf: Transform3D, offsets: Array, r: float) -> Vector3:
	var best := Vector3.INF
	var best_s := -INF
	for off: Vector3 in offsets:
		var c: Vector3 = xf * off
		c.y = RealmLayout.ground(space, c.x, c.z)
		var near := INF
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a: Vector3 = cmp.at
			near = minf(near, Vector2(a.x - c.x, a.z - c.z).length())
		var bad := 0
		for i in 12:
			var a := TAU * float(i) / 12.0
			var q := c + Vector3(cos(a), 0, sin(a)) * r * 0.8
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 4.0, q + Vector3.DOWN * 4.0, Layers.WORLD))
			if hit.is_empty() or absf((hit.position as Vector3).y - c.y) > 1.0 or (hit.normal as Vector3).y < 0.75:
				bad += 1
		if not RealmLayout.BOUNDS.grow(-8.0).has_point(Vector2(c.x, c.z)):
			bad += 20
		var sc := minf(near, 30.0) - float(bad) * 6.0
		if sc > best_s:
			best_s = sc
			best = c
	return best


static func _grapple(host: Node3D, at: Vector3, stand: Vector3, reach := 18.0, land := true) -> Node3D:
	var m: Node3D
	var gs := "res://core/player/grapple_anchor.gd"
	if ResourceLoader.exists(gs):
		m = (load(gs) as GDScript).new()                  # the Tether's own ring and glow
	else:
		m = Node3D.new()
	m.name = "GrappleAnchor"
	m.set_meta("reach", reach)
	m.set_meta("stand", stand)
	if land:
		m.set_meta("land", stand - at + Vector3.UP * 0.1)
	host.add_child(m)
	m.global_position = at
	m.add_to_group(GROUP_GRAPPLE)
	return m


static func _updraft(host: Node3D, at: Vector3, radius: float, height: float, lift: float) -> Node3D:
	var m := Node3D.new()
	m.name = "Updraft"
	host.add_child(m)
	m.global_position = at
	m.add_to_group(GROUP_UPDRAFT)
	m.set_meta("radius", radius)
	m.set_meta("height", height)
	m.set_meta("lift", lift)
	return m


static func _perch(host: Node3D, at: Vector3, facing: Vector3, drop: float) -> Node3D:
	var m := Node3D.new()
	m.name = "GlidePerch"
	host.add_child(m)
	m.global_position = at
	m.add_to_group(GROUP_GLIDE)
	m.set_meta("facing", Vector3(facing.x, 0.0, facing.z).normalized())
	m.set_meta("drop", drop)
	return m


static func _chest(host: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


static func _lore(host: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	host.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


## A boulder from the rock kit (shared meshes), with collision when `collide`.
static func _rock(host: Node3D, at: Vector3, size: Vector3, style: String, seed_n: int, yaw: float, collide := true, vis := 90.0) -> void:
	var m := RockKit.boulder(seed_n % 4, size, style)
	var wf := load("res://core/world/realm/realm_wayfinding.gd") as GDScript
	wf.call("_spawn", host, m, Transform3D(Basis(Vector3.UP, yaw), at), collide, vis)


## Overgrowth inside a place (the flora keeps out of registered sites; ruins in this valley are
## not swept): one MultiMesh per plant kind, the flora's own meshes and materials.
static func _plants(host: Node3D, items: Dictionary, vis := 46.0) -> void:
	for id: String in items:
		var xfs: Array = items[id]
		if xfs.is_empty():
			continue
		var d: Dictionary = TreeGen.kind(id)
		for mesh: Variant in [d.solid, d.cards]:
			if mesh == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
				mm.set_instance_color(i, Color(1, 1, 1, 1))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Overgrowth_" + id
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = vis
			mmi.visibility_range_end_margin = 4.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mmi.set_instance_shader_parameter(&"fade_end", vis - 6.0)
			mmi.add_to_group(Groups.CULL_SKIP)
			mmi.set_meta("site_owned", true)
			host.add_child(mmi)


## Scatter `n` plants of `kind` (species id, e.g. "fern") in the ring round `c` (r0..r1), on the ground.
static func _ring_plants(items: Dictionary, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator, kind: String, c: Vector3, r0: float, r1: float, n: int, avoid: Callable = Callable()) -> void:
	var ids := TreeGen.ids(kind)
	if ids.is_empty():
		return
	for i in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		if avoid.is_valid() and bool(avoid.call(Vector2(x, z))):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, c.y + 6.0, z), Vector3(x, c.y - 6.0, z), Layers.WORLD))
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		if kind != "moss" and not String((hit.collider as Node).name).begins_with("Terrain"):
			continue                                       # on the ground, not on wall tops (moss may)
		var id: String = ids[rng.randi() % ids.size()]
		var s := rng.randf_range(0.8, 1.25)
		if not items.has(id):
			items[id] = []
		(items[id] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), hit.position as Vector3))


static func _light(host: Node3D, at: Vector3, col: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "PoiLight"
	l.light_color = col
	l.light_energy = e
	l.omni_range = r
	l.shadow_enabled = false
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	host.add_child(l)
	l.global_position = at
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	l.shadow_enabled = false
	return l


## A bell (lathe), for the belfry.
static func _bell_mesh() -> ArrayMesh:
	var prof := [Vector2(0.0, 1.25), Vector2(0.16, 1.24), Vector2(0.3, 1.16), Vector2(0.36, 1.0), Vector2(0.4, 0.7),
		Vector2(0.48, 0.35), Vector2(0.62, 0.1), Vector2(0.66, 0.0), Vector2(0.58, 0.02), Vector2(0.44, 0.3),
		Vector2(0.34, 0.68), Vector2(0.28, 1.0), Vector2(0.0, 1.06)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 18
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		for j in prof.size() - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
				st.set_uv(Vector2(float(i) / sides, v.y))
				st.set_color(Color(1, 1, 1, 1))
				st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- the Drowned Belfry ------------------------------------------------------------------------

const BELFRY_W := 4.6
const BELFRY_FLOOR := 9.0               ## the bell stage, above the fen
const BELFRY_TOP := 12.4

static func _belfry(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var at := func(v: Vector3) -> Vector3: return xf * v
	var k := OssKit.new()
	k.keep_lanes = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 31001
	var w := BELFRY_W
	var sink := 1.6                                      # the tower stands in the fen to its knees
	# the shaft: solid to the bell stage, a battered plinth, string courses, a sunk door
	k.box("stone", at.call(Vector3(0, (BELFRY_FLOOR - sink) * 0.5, 0)), Vector3(w, BELFRY_FLOOR + sink, w), b, true, 0.84)
	k.box("stone", at.call(Vector3(0, 0.05, 0)), Vector3(w + 0.9, 1.0, w + 0.9), b, true, 0.72)
	for y: float in [3.2, 6.2]:
		k.box("stone", at.call(Vector3(0, y, 0)), Vector3(w + 0.18, 0.24, w + 0.18), b, false, 0.95)
	k.box("dark", at.call(Vector3(0, 0.9, -w * 0.5 - 0.01)), Vector3(1.2, 2.0, 0.06), b, false)         # the drowned door
	for f: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		for y: float in [4.4, 7.2]:
			k.box("dark", at.call(f * (w * 0.5 + 0.01) + Vector3(0, y, 0)), Vector3(0.05, 1.0, 0.28), b, false)
	# clasping buttresses at the corners, stepping in as they rise
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (w * 0.5 + 0.25), 0, sz * (w * 0.5 + 0.25))
			k.box("stone", at.call(c + Vector3(0, 1.4, 0)), Vector3(0.7, 3.4, 0.7), b, true, 0.8)
			k.box("stone", at.call(c * 0.93 + Vector3(0, 4.4, 0)), Vector3(0.5, 2.6, 0.5), b, true, 0.86)
	# the bell stage: four corner piers, a cornice, three lintels (the climb side's has fallen)
	var pier := 1.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph := BELFRY_TOP - BELFRY_FLOOR
			if sx > 0.0 and sz > 0.0:
				ph = 2.1                                   # one pier broken off
			k.box("stone", at.call(Vector3(sx * (w - pier) * 0.5, BELFRY_FLOOR + ph * 0.5, sz * (w - pier) * 0.5)), Vector3(pier, ph, pier), b, true, 0.9)
	for side: Array in [[Vector3(0, 0, -1), true], [Vector3(-1, 0, 0), true], [Vector3(1, 0, 0), false]]:
		var nrm: Vector3 = side[0]
		if not bool(side[1]):
			continue
		var along := Vector3(absf(nrm.z), 0, absf(nrm.x))
		k.box("stone", at.call(nrm * (w - pier) * 0.5 + Vector3(0, BELFRY_TOP - 0.45, 0)), along * (w - 0.1) + Vector3(0, 0.9, 0) + nrm.abs() * pier, b, true, 0.92)
	# a low sill on the far side (the near side, +z, is where you climb in)
	k.box("stone", at.call(Vector3(0, BELFRY_FLOOR + 0.35, -(w - 0.4) * 0.5)), Vector3(w - 2.0 * pier, 0.7, 0.4), b, true, 0.9)
	# the bell beam and the bell, cracked, hanging still
	k.box("wood", at.call(Vector3(0, BELFRY_TOP - 1.25, 0)), Vector3(w - 0.4, 0.32, 0.36), b, true, 0.85)
	k.append_mesh("iron", _bell_mesh(), Transform3D(b * Basis(Vector3.RIGHT, 0.08), at.call(Vector3(0.0, BELFRY_TOP - 1.42 - 1.25, -0.2))))
	# fallen pieces of the broken pier and cornice on the stage floor and in the fen
	k.box("stone", at.call(Vector3(1.1, BELFRY_FLOOR + 0.22, 1.2)), Vector3(0.9, 0.44, 0.7), b * Basis(Vector3.UP, 0.5), true, 0.85)
	# the climb: rubble of the nave that once leaned on this face, then the old roof corbel ledge,
	# then a fallen bell-frame crate at the corner, then the stage
	var route: Array[Vector3] = []
	var steps := [[4.25, 1.6], [3.1, 3.2], [1.95, 4.8], [0.8, 6.4], [-0.35, 8.0]]     # [local x, top]: right to left, the last between the stage's piers
	var face := w * 0.5
	for i in steps.size():
		var sx: float = steps[i][0]
		var top: float = steps[i][1]
		var depth := 1.15
		var c := Vector3(sx, (top - sink) * 0.5, face + depth * 0.5 - 0.02)
		var sz := Vector3(1.15, top + sink, depth)
		k.box("stone", at.call(c), sz, b * Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)), true, rng.randf_range(0.76, 0.9))
		k.box("stone", at.call(Vector3(sx, top + 0.05, face + depth * 0.5)), Vector3(sz.x + 0.1, 0.12, depth + 0.08), b, false, 0.96)
		route.append(at.call(Vector3(sx, top, face + depth * 0.5)))
	route.append(at.call(Vector3(-0.35, BELFRY_FLOOR, face - 0.9)))       # over the sill-less lip onto the stage
	# rubble and drowned grave-slabs round the foot
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(w * 0.7, w * 1.25)
		var q := Vector3(cos(a) * r, 0, sin(a) * r)
		if q.z > face - 0.5 and absf(q.x) < 4.2:
			continue                                     # keep the climb and the causeway end clear
		_rock(host, at.call(q) + Vector3.DOWN * 0.35, Vector3(1.4, 0.9, 1.2) * rng.randf_range(0.8, 1.3), "mossy", i, rng.randf() * TAU)
	for i in 5:
		var a := -PI * 0.5 + rng.randf_range(-1.1, 1.1)
		var q := Vector3(cos(a) * rng.randf_range(7.0, 10.0), 0, sin(a) * rng.randf_range(7.0, 10.0))
		var gq := RealmLayout.ground(space, (at.call(q) as Vector3).x, (at.call(q) as Vector3).z)
		var p: Vector3 = at.call(q)
		p.y = gq
		k.box("stone", p + Vector3.UP * 0.35, Vector3(0.55, 1.0, 0.16), b * Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.25)), true, 0.82)
	k.commit(host, "BelfryBody")
	_causeway(host, space, rng)
	host.set_meta("route", route)
	host.set_meta("walk", [])
	host.set_meta("approach", at.call(Vector3(4.25, 0.0, face + 3.0)))
	var stage: Vector3 = at.call(Vector3(-0.35, BELFRY_FLOOR, 1.3))
	_chest(host, "belfry_bell", at.call(Vector3(0.0, BELFRY_FLOOR, -1.55)), float(s.yaw))
	_lore(host, "poi_belfry", at.call(Vector3(0.9, 1.3, face + 0.05)))
	_lore(host, "poi_belfry_top", at.call(Vector3(0, BELFRY_TOP - 1.25, 0.2)))
	_grapple(host, at.call(Vector3(0, BELFRY_TOP - 1.05, 0)), stage)
	_perch(host, at.call(Vector3(0.0, BELFRY_FLOOR, face - 0.3)), b.z, BELFRY_FLOOR - o.y)
	# the fighting floor: the open fen behind the tower
	var mb := _open_floor(space, xf, [Vector3(0, 0, -11.0), Vector3(-11.0, 0, -2.0), Vector3(11.0, 0, -2.0), Vector3(-9.0, 0, 8.0), Vector3(9.0, 0, 9.0)], 7.0)
	_miniboss(host, "belfry_fen", mb, 7.0, "fen", "sexton")
	# a pale lamp left in the bell stage: the tower reads from east_way at night
	_light(host, stage + Vector3.UP * 1.4, Color(0.75, 0.85, 1.0), 0.9, 7.0)
	# reeds and moss round its knees
	var items := {}
	var avoid := func(q: Vector2) -> bool:
		var lq := xf.affine_inverse() * Vector3(q.x, o.y, q.y)
		return absf(lq.x) < w * 0.5 + 1.3 and absf(lq.z) < w * 0.5 + 1.3 or (lq.z > 0.0 and absf(lq.x) < 2.6)
	_ring_plants(items, space, rng, "reeds", o, 3.6, 7.5, 40, avoid)
	_ring_plants(items, space, rng, "cattail", o, 3.6, 7.0, 14, avoid)
	_ring_plants(items, space, rng, "moss", o, 3.0, 6.0, 18, avoid)
	_ring_plants(items, space, rng, "grass", o, 4.0, 8.0, 40, avoid)
	_plants(host, items)


## The belfry causeway: planks on posts, a hand's breadth over the pools, a few boards missing.
static func _causeway(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> void:
	if causeway.size() < 2:
		return
	var k := OssKit.new()
	k.keep_lanes = false
	for i in causeway.size() - 1:
		var a: Vector2 = causeway[i]
		var c: Vector2 = causeway[i + 1]
		var n := maxi(1, int(a.distance_to(c) / 1.0))
		var dir := (c - a).normalized()
		var yaw := atan2(dir.x, dir.y)
		for j in n:
			var t := (float(j) + 0.5) / float(n)
			var p := a.lerp(c, t)
			var g := RealmLayout.ground(space, p.x, p.y)
			var deck := maxf(g, -0.9) + 0.32
			var bb := Basis(Vector3.UP, yaw + rng.randf_range(-0.03, 0.03))
			if rng.randf() < 0.1 and j > 0 and j < n - 1:
				deck -= 0.07                               # a sodden board, sagged into the water
				bb = bb * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06))
			k.box("wood", Vector3(p.x, deck - 0.05, p.y), Vector3(1.5, 0.1, a.distance_to(c) / float(n) - 0.06), bb, true, rng.randf_range(0.75, 0.95))
			if j % 2 == 0:
				for side: float in [-0.62, 0.62]:
					var q := p + Vector2(dir.y, -dir.x) * side
					var gq := RealmLayout.ground(space, q.x, q.y)
					k.box("wood", Vector3(q.x, (deck - 0.1 + gq - 0.6) * 0.5, q.y), Vector3(0.16, deck - 0.1 - gq + 0.6, 0.16), bb, false, 0.7)
				# runners under the boards
			if j % 3 == 1:
				k.box("wood", Vector3(p.x, deck - 0.16, p.y), Vector3(1.6, 0.1, 0.14), bb, false, 0.6)
	var cw := Node3D.new()
	cw.name = "Causeway"
	host.add_child(cw)
	k.commit(cw, "CausewayBody")


# --- the Charcoal Hollow -----------------------------------------------------------------------

static func _charcoal(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var at := func(v: Vector3) -> Vector3:
		var p: Vector3 = xf * v
		p.y = RealmLayout.ground(space, p.x, p.z) + v.y
		return p
	var rng := RandomNumberGenerator.new()
	rng.seed = 31002
	var k := OssKit.new()
	k.keep_lanes = false
	# three clamps: low smouldering earth domes on the clearing's far side
	var clamps: Array[Vector3] = []
	for i in 3:
		var a := PI + (float(i) - 1.0) * 0.75
		var q := Vector3(sin(a) * 7.2, -0.35, cos(a) * 7.2)
		var p: Vector3 = at.call(q)
		clamps.append(p)
		_rock(host, p, Vector3(3.4, 1.3, 3.0), "ash", 11 + i, rng.randf() * TAU, true, 110.0)
		var smoke := Vfx.emitter(Color(0.32, 0.3, 0.3), {"count": 10, "life": 4.5, "speed": Vector2(0.2, 0.5), "size": 0.9, "gravity": 0.15, "radius": 0.8, "additive": false, "damping": 0.2})
		host.add_child(smoke)
		smoke.global_position = p + Vector3.UP * 1.0
		smoke.emitting = true
		_updraft(host, p + Vector3.UP * 0.6, 2.2, 14.0, 5.5)          # the clamp's heat lifts a spread robe
	_light(host, (clamps[0] + clamps[1] + clamps[2]) / 3.0 + Vector3.UP * 0.8, Color(1.0, 0.45, 0.2), 1.1, 9.0)
	# the burners' lean-to on the near side: two forked posts, a ridge pole, a slope of slabs
	var lt := Vector3(-4.6, 0, 3.4)
	var ly: float = (at.call(lt) as Vector3).y
	var lb := b * Basis(Vector3.UP, 0.5)
	var lp := func(v: Vector3) -> Vector3: return Vector3((at.call(lt) as Vector3).x, ly, (at.call(lt) as Vector3).z) + lb * v
	for x: float in [-1.6, 1.6]:
		k.box("wood", lp.call(Vector3(x, 1.1, 0.6)), Vector3(0.18, 2.4, 0.18), lb, true, 0.75)
	k.box("wood", lp.call(Vector3(0, 2.25, 0.6)), Vector3(3.8, 0.18, 0.18), lb, false, 0.8)
	for j in 6:
		var x := -1.65 + 0.66 * float(j)
		k.box("wood", lp.call(Vector3(x, 1.2, -0.4)), Vector3(0.6, 0.08, 2.5), lb * Basis(Vector3.RIGHT, 0.85 + rng.randf_range(-0.05, 0.05)), false, rng.randf_range(0.6, 0.85))
	k.box("wood", lp.call(Vector3(0, 0.15, 0.1)), Vector3(2.6, 0.3, 1.0), lb, true, 0.65)          # a sleeping bench of split logs
	# the woodpile and an axe in a stump
	for row in 3:
		for j in 4 - row:
			var v := Vector3(4.6 + 0.0, 0.18 + 0.32 * float(row), 3.6 + (float(j) - (3.0 - row) * 0.5) * 0.34)
			k.box("wood", at.call(v), Vector3(1.8, 0.3, 0.3), b * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), row == 0, rng.randf_range(0.7, 0.9))
	var stump: Vector3 = at.call(Vector3(2.2, 0.0, 5.4))
	var sd: Dictionary = TreeGen.kind("stump_0")
	if sd.solid != null:
		k.append_mesh("wood", sd.solid, Transform3D(Basis(Vector3.UP, 1.0), stump + Vector3.DOWN * 0.05))
	k.box("wood", stump + Vector3(0, 0.75, 0), Vector3(0.06, 0.7, 0.06), Basis(Vector3.FORWARD, 0.35), false, 0.7)
	k.box("iron", stump + Vector3(0.12, 0.47, 0), Vector3(0.3, 0.14, 0.04), Basis(Vector3.FORWARD, 0.35), false, 0.9)
	# a notice post
	var post: Vector3 = at.call(Vector3(-1.2, 0.0, 7.4))
	k.box("wood", post + Vector3(0, 0.9, 0), Vector3(0.16, 1.8, 0.16), b, true, 0.75)
	k.box("wood", post + b * Vector3(0, 1.55, 0.1), Vector3(0.8, 0.5, 0.05), b, false, 0.9)
	k.commit(host, "CharcoalBody")
	_lore(host, "poi_charcoal", post + b * Vector3(0, 1.55, 0.14))
	var chest_at: Vector3 = lp.call(Vector3(0.9, 0.0, -0.1))
	_chest(host, "charcoal_box", chest_at, float(s.yaw) + 0.5 + PI)
	# the fighting floor: the clearing between the lean-to and the clamps
	_miniboss(host, "charcoal_clearing", at.call(Vector3(0, 0, 0.4)), 5.6, "thornwood", "brood_mother")
	# bracken and brambles ring the clearing, ash and litter on its floor
	var items := {}
	_ring_plants(items, space, rng, "fern", o, 8.0, 10.5, 70)
	_ring_plants(items, space, rng, "bramble", o, 8.6, 10.5, 10)
	_ring_plants(items, space, rng, "litter", o, 2.0, 8.0, 30)
	_ring_plants(items, space, rng, "mushroom", o, 7.0, 10.0, 12)
	_plants(host, items)
	host.set_meta("approach", at.call(Vector3(0, 0, 9.5)))


# --- the Almonry -------------------------------------------------------------------------------

const ALM := Vector2(5.8, 3.6)          ## half extents of the hall (outer)
const ALM_T := 0.6                      ## wall thickness
const LOFT_Y := 3.5

static func _almonry(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var g := o.y
	var at := func(v: Vector3) -> Vector3: return xf * v
	var rng := RandomNumberGenerator.new()
	rng.seed = 31003
	var k := OssKit.new()
	k.keep_lanes = false
	# the hall sits on the north half of the site, its door (+z wall) on the yard
	var hc := Vector3(0, 0, -3.4)
	var hx := ALM.x
	var hz := ALM.y
	var t := ALM_T
	k.box("floor", at.call(hc + Vector3(0, 0.02, 0)), Vector3(hx * 2.0 - 0.1, 0.24, hz * 2.0 - 0.1), b, true, 0.85)
	k.box("stone", at.call(hc + Vector3(0, -0.35, 0)), Vector3(hx * 2.0 + 0.3, 0.9, hz * 2.0 + 0.3), b, true, 0.72)   # footing
	# long walls: north whole but broken-topped; south with the door gap and a window
	var segs := [
		# [centre x, length, height, z side]
		[-2.9, 5.8, 4.3, -1], [2.0, 2.4, 3.7, -1], [4.5, 2.6, 4.6, -1],
		[-4.3, 3.0, 4.1, 1], [-0.2, 2.0, 4.4, 1], [1.6, 1.6, 1.6, 1], [4.1, 3.4, 4.4, 1],
	]
	for sg: Array in segs:
		var cx: float = sg[0]
		var ln: float = sg[1]
		var h: float = sg[2]
		var sz: float = sg[3]
		k.box("stone", at.call(hc + Vector3(cx, h * 0.5 - 0.2, sz * (hz - t * 0.5))), Vector3(ln, h + 0.4, t), b, true, rng.randf_range(0.8, 0.9))
		# a ragged top: two or three blocks of the next course
		for j in 2:
			var bx := cx + rng.randf_range(-ln * 0.35, ln * 0.35)
			k.box("stone", at.call(hc + Vector3(bx, h + 0.2, sz * (hz - t * 0.5))), Vector3(rng.randf_range(0.5, 0.9), 0.4, t), b, true, 0.86)
	# gable ends: the east one stands to its peak (stepped), the west one fell to 2.6 m
	for row in 7:
		var y := 4.5 + 0.42 * float(row)
		var wdt := (hz * 2.0) * (1.0 - float(row) / 7.5)
		k.box("stone", at.call(hc + Vector3(hx - t * 0.5, y, 0)), Vector3(t, 0.44, wdt), b, true, 0.86)
	k.box("stone", at.call(hc + Vector3(hx - t * 0.5, 2.25 - 0.2, 0)), Vector3(t, 4.9, hz * 2.0), b, true, 0.84)
	k.box("stone", at.call(hc + Vector3(-hx + t * 0.5, 1.1, 0)), Vector3(t, 2.6, hz * 2.0), b, true, 0.8)
	k.box("dark", at.call(hc + Vector3(hx - t - 0.01, 5.6, 0)), Vector3(0.05, 0.9, 0.35), b, false)                   # a slit in the gable
	# the hearth on the west wall
	k.box("stone", at.call(hc + Vector3(-hx + t + 0.45, 0.6, 0)), Vector3(0.9, 1.2, 1.8), b, true, 0.7)
	k.box("dark", at.call(hc + Vector3(-hx + t + 0.91, 0.55, 0)), Vector3(0.04, 0.7, 1.0), b, false)
	# the loft: plank floor over the east third on two beams, held by posts
	var lx0 := 1.6
	var lx1 := hx - t
	k.box("wood", at.call(hc + Vector3((lx0 + lx1) * 0.5, LOFT_Y - 0.08, 0)), Vector3(lx1 - lx0, 0.16, hz * 2.0 - t * 2.0), b, true, 0.8)
	for zz: float in [-hz + t + 0.15, hz - t - 0.15]:
		k.box("wood", at.call(hc + Vector3(lx0 + 0.15, (LOFT_Y - 0.2) * 0.5, zz)), Vector3(0.22, LOFT_Y - 0.2, 0.22), b, true, 0.72)
	k.box("wood", at.call(hc + Vector3(lx0 + 0.15, LOFT_Y - 0.26, 0)), Vector3(0.26, 0.26, hz * 2.0 - t * 2.0), b, false, 0.7)
	# the stair along the north wall up toward the loft: its top flight has fallen in
	var st_lo := hc + Vector3(-2.6, 0.14, -hz + t + 1.0)
	var st_hi := hc + Vector3(0.45, 1.85, -hz + t + 1.0)
	k.stairs("stone", at.call(st_lo), at.call(st_hi), 1.1, 6)
	k.box("stone", at.call(Vector3(st_hi.x + 0.3, 1.85 * 0.5, st_hi.z)), Vector3(0.6, 1.85, 1.1), b, true, 0.85)      # the stair's head block
	for i in 3:
		k.box("stone", at.call(hc + Vector3(0.6 + rng.randf_range(-0.3, 0.3), 0.25, -hz + t + 1.6 + rng.randf_range(-0.3, 0.6))), Vector3(0.7, 0.3, 0.45), b * Basis(Vector3.UP, rng.randf() * TAU), false, 0.8)
	# the yard: low walls, a well, the alms-table
	var yc := Vector3(0, 0, 3.6)
	for wl: Array in [[Vector3(-7.2, 0.5, 3.4), Vector3(0.6, 1.0, 7.2)], [Vector3(7.2, 0.5, 3.0), Vector3(0.6, 1.0, 6.0)], [Vector3(-4.6, 0.45, 7.3), Vector3(5.0, 0.9, 0.6)], [Vector3(5.0, 0.45, 7.3), Vector3(4.2, 0.9, 0.6)]]:
		var p: Vector3 = at.call(wl[0])
		p.y = RealmLayout.ground(space, p.x, p.z) + (wl[1] as Vector3).y * 0.5 - 0.15
		k.box("stone", p, wl[1], b * Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), true, 0.78)
	var well: Vector3 = at.call(Vector3(-4.8, 0, 5.0))
	well.y = RealmLayout.ground(space, well.x, well.z)
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.box("stone", well + Vector3(cos(a) * 0.75, 0.35, sin(a) * 0.75), Vector3(0.62, 0.7, 0.3), Basis(Vector3.UP, -a + PI * 0.5), true, 0.82)
	k.box("dark", well + Vector3(0, 0.12, 0), Vector3(1.1, 0.04, 1.1), Basis.IDENTITY, false)
	var table: Vector3 = at.call(Vector3(3.6, 0, 1.4))
	table.y = RealmLayout.ground(space, table.x, table.z)
	for x: float in [-0.7, 0.7]:
		k.box("stone", table + b * Vector3(x, 0.38, 0), Vector3(0.35, 0.76, 0.5), b, true, 0.8)
	k.box("stone", table + b * Vector3(0, 0.84, 0), Vector3(2.0, 0.16, 0.8), b * Basis(Vector3.FORWARD, 0.04), true, 0.88)
	k.commit(host, "AlmonryBody")
	_lore(host, "poi_almonry", table + b * Vector3(0, 0.95, 0.1))
	var loft: Vector3 = at.call(hc + Vector3((lx0 + lx1) * 0.5 + 0.4, LOFT_Y, -0.6))
	_chest(host, "almonry_loft", loft, float(s.yaw) - PI * 0.5)
	_lore(host, "poi_almoner", at.call(hc + Vector3((lx0 + lx1) * 0.5 + 0.2, LOFT_Y + 0.1, 1.4)))
	var route: Array[Vector3] = [at.call(st_hi + Vector3(0.3, 0, 0)), at.call(hc + Vector3(lx0 + 0.9, LOFT_Y, -hz + t + 1.0))]
	host.set_meta("route", route)
	host.set_meta("walk", [true, false])
	host.set_meta("approach", at.call(st_lo + Vector3(-1.0, 0, 0)))
	var peak: Vector3 = at.call(hc + Vector3(hx - t * 0.5, 4.5 + 0.42 * 6.0 + 0.22, 0))
	_grapple(host, peak + Vector3.UP * 0.6, peak + Vector3.UP * 0.05, 18.0, false)
	_perch(host, peak, -b.z, peak.y - g)
	_miniboss(host, "almonry_yard", Vector3((at.call(yc) as Vector3).x, g, (at.call(yc) as Vector3).z), 6.5, String(POIS.almonry[6]), "tithe_knight")
	# grass gone to seed in the hall and the yard, nettles along the walls
	var items := {}
	var inside := func(q: Vector2) -> bool:
		var lq := xf.affine_inverse() * Vector3(q.x, g, q.y)
		return absf(lq.x - 3.6) < 1.3 and absf(lq.z - 1.4) < 0.8          # not through the table
	_ring_plants(items, space, rng, "grass", o + b * Vector3(0, 0, 3.6), 0.0, 6.5, 110, inside)
	_ring_plants(items, space, rng, "tallgrass", o, 6.0, 9.5, 30)
	_ring_plants(items, space, rng, "flowers", o + b * Vector3(0, 0, 3.6), 1.0, 6.0, 26, inside)
	_ring_plants(items, space, rng, "shrub", o, 8.5, 10.5, 8)
	_ring_plants(items, space, rng, "moss", o + b * hc, 0.0, 4.0, 14)
	_plants(host, items)


# --- the Watchers' Spire -----------------------------------------------------------------------

const SPIRE_W := 6.0                    ## the tower's side
const SPIRE_TOP := 16.0                 ## roof walk
const STAIR_W := 1.3                    ## the outside stair

static func _spire(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var b := xf.basis
	var o: Vector3 = s.at
	var at := func(v: Vector3) -> Vector3: return xf * v
	var rng := RandomNumberGenerator.new()
	rng.seed = 31004
	var k := OssKit.new()
	k.keep_lanes = false
	var h := SPIRE_W * 0.5
	var foot := -1.2
	k.box("stone", at.call(Vector3(0, (SPIRE_TOP + foot) * 0.5, 0)), Vector3(SPIRE_W, SPIRE_TOP - foot, SPIRE_W), b, true, 0.84)
	k.box("stone", at.call(Vector3(0, 0.2, 0)), Vector3(SPIRE_W + 1.0, 1.4, SPIRE_W + 1.0), b, true, 0.72)
	for y: float in [4.0, 8.0, 12.0]:
		k.box("stone", at.call(Vector3(0, y, 0)), Vector3(SPIRE_W + 0.16, 0.2, SPIRE_W + 0.16), b, false, 0.95)
	for f: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]:
		for y: float in [5.6, 9.8, 13.6]:
			var thin := Vector3(0.05, 1.1, 0.3) if f.x != 0.0 else Vector3(0.3, 1.1, 0.05)
			k.box("dark", at.call(f * (h + 0.01) + Vector3(0, y, 0) + Vector3(f.z, 0, f.x) * 1.2), thin, b, false)
	# the stair: round the outside, counter-clockwise from the south-west corner (local +z is south,
	# toward the valley). Corner landings at d = h + STAIR_W / 2. [from corner, to corner, y0, y1, kind]
	var d := h + STAIR_W * 0.5
	var C := [Vector3(-d, 0, d), Vector3(d, 0, d), Vector3(d, 0, -d), Vector3(-d, 0, -d), Vector3(-d, 0, d), Vector3(d, 0, d)]
	var lands := [0.0, 3.0, 6.0, 9.0, 12.6, 15.6]
	var route: Array[Vector3] = [at.call(C[0])]          # the stair foot (the corner before the first tread)
	var walk: Array[bool] = [true]
	for i in 5:
		var a: Vector3 = C[i]
		var c: Vector3 = C[i + 1]
		var dir := (c - a).normalized()
		var y0: float = lands[i]
		var y1: float = lands[i + 1]
		var p0: Vector3 = a + dir * (STAIR_W * 0.5)
		var p1: Vector3 = c - dir * (STAIR_W * 0.5)
		match i:
			1:
				# the east flight broke: a stub of steps, a gap, a flat run of the broken flight at the top
				var mid0 := p0.lerp(p1, 0.4)
				k.stairs("stone", at.call(p0 + Vector3(0, y0, 0)), at.call(mid0 + Vector3(0, 4.2, 0)), STAIR_W, 4)
				var mid1 := p0.lerp(p1, 0.62)
				var run := p1 - mid1
				k.box("stone", at.call((mid1 + p1) * 0.5 + Vector3(0, y1 - 0.3, 0)), Vector3(STAIR_W, 0.6, run.length()) if absf(dir.z) > 0.5 else Vector3(run.length(), 0.6, STAIR_W), b, true, 0.86)
				route.append(at.call(mid0 + Vector3(0, 4.2, 0) - dir * 0.4))
				route.append(at.call(mid1 + dir * 0.6 + Vector3(0, y1, 0)))
				walk.append_array([true, false])
			3:
				# the west flight stops short: grab the jutting landing at the south-west corner
				var mid := p0.lerp(p1, 0.82)
				k.stairs("stone", at.call(p0 + Vector3(0, y0, 0)), at.call(mid + Vector3(0, 11.0, 0)), STAIR_W, 9)
				route.append(at.call(mid + Vector3(0, 11.0, 0) - dir * 0.4))
				walk.append(true)
			_:
				var steps := int(round((y1 - y0) / 0.3))
				k.stairs("stone", at.call(p0 + Vector3(0, y0, 0)), at.call(p1 + Vector3(0, y1, 0)), STAIR_W, steps)
		# corbels under the flight
		for j in 3:
			var q := p0.lerp(p1, (float(j) + 0.5) / 3.0)
			var qy := lerpf(y0, y1, (float(j) + 0.5) / 3.0) - 0.9
			if qy > 0.6:
				k.box("stone", at.call(q + Vector3(0, qy, 0)), Vector3(0.55, 0.5, 0.55), b, false, 0.8)
		# the landing at the far corner
		var ly: float = y1
		k.box("stone", at.call(c + Vector3(0, ly - 0.3, 0)), Vector3(STAIR_W, 0.6, STAIR_W), b, true, 0.9)
		route.append(at.call(c + Vector3(0, ly, 0)))
		walk.append(i != 3)                              # the south-west landing is a grab
	route.append(at.call(Vector3(1.2, SPIRE_TOP, 1.2)))
	walk.append(true)
	# roof walk: a parapet on three sides, open where the stair arrives (south-east)
	var ph := 0.9
	var pt := 0.35
	var walls := [
		[Vector3(0, SPIRE_TOP + ph * 0.5, -h + pt * 0.5), Vector3(SPIRE_W, ph, pt)],
		[Vector3(-h + pt * 0.5, SPIRE_TOP + ph * 0.5, 0), Vector3(pt, ph, SPIRE_W)],
		[Vector3(h - pt * 0.5, SPIRE_TOP + ph * 0.5, -1.0), Vector3(pt, ph, SPIRE_W - 2.0)],
		[Vector3(-1.0, SPIRE_TOP + ph * 0.5, h - pt * 0.5), Vector3(SPIRE_W - 2.0, ph, pt)],
	]
	for wl: Array in walls:
		k.box("stone", at.call(wl[0]), wl[1], b, true, 0.9)
	for i in 6:
		if rng.randf() < 0.35:
			continue
		var u := -h + 0.5 + float(i)
		k.box("stone", at.call(Vector3(u, SPIRE_TOP + ph + 0.25, -h + pt * 0.5)), Vector3(0.55, 0.5, pt + 0.05), b, true, 0.92)
	# the beacon cage: four iron posts, two hoops, a bed of dead coals
	var cage := Vector3(-0.8, SPIRE_TOP, -0.8)
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.6, 0.6]:
			k.box("iron", at.call(cage + Vector3(sx, 1.1, sz)), Vector3(0.08, 2.2, 0.08), b, true, 0.9)
	for y: float in [1.0, 2.2]:
		for sd: Array in [[Vector3(0, y, 0.6), Vector3(1.28, 0.06, 0.06)], [Vector3(0, y, -0.6), Vector3(1.28, 0.06, 0.06)], [Vector3(0.6, y, 0), Vector3(0.06, 0.06, 1.28)], [Vector3(-0.6, y, 0), Vector3(0.06, 0.06, 1.28)]]:
			k.box("iron", at.call(cage + sd[0]), sd[1], b, false, 0.9)
	k.box("dark", at.call(cage + Vector3(0, 0.95, 0)), Vector3(1.1, 0.12, 1.1), b, true)
	k.box("glow", at.call(cage + Vector3(0, 1.04, 0)), Vector3(0.5, 0.08, 0.5), b, false, 0.35)
	# a rock spur the tower is built on, and rubble round its foot
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		var q := Vector3(cos(a), 0, sin(a)) * (h + 1.8)
		if q.z > h - 0.5:
			continue                                     # the south face (the stair's first flight) stays clear
		_rock(host, at.call(q) + Vector3.DOWN * 0.4, Vector3(2.4, 1.6, 2.0) * rng.randf_range(0.8, 1.3), "granite", 20 + i, rng.randf() * TAU)
	k.commit(host, "SpireBody")
	host.set_meta("route", route)
	host.set_meta("walk", walk)
	host.set_meta("approach", at.call(C[0] + Vector3(0, 0, 2.2)))
	var roof := Vector3(0.8, SPIRE_TOP, 0.8)
	_chest(host, "spire_cage", at.call(Vector3(1.4, SPIRE_TOP, -1.6)), float(s.yaw) + PI)
	_lore(host, "poi_watch", at.call(C[0] + Vector3(0.9, 1.3, 0.0) + Vector3(0, 0, -STAIR_W * 0.5 - 0.02)))
	_lore(host, "poi_watch_log", at.call(cage + Vector3(1.0, 0.9, 0.8)))
	_grapple(host, at.call(Vector3(-h + 0.2, SPIRE_TOP + ph, h - 0.2)), at.call(roof))
	_grapple(host, at.call(Vector3(h + 0.1, 7.6, -1.0)), at.call(C[2] + Vector3(0, 6.0, 0)), 12.0)   # over the east flight's gap
	_perch(host, at.call(Vector3(0.5, SPIRE_TOP, h - 0.5)), b.z, SPIRE_TOP)
	# the fighting floor: the open ground off the spire's flank (not on its stair foot)
	var mb := _open_floor(space, xf, [Vector3(11.0, 0, 2.0), Vector3(-11.0, 0, -2.0), Vector3(2.0, 0, 12.0), Vector3(0, 0, -12.0)], 6.0)
	_miniboss(host, "spire_foot", mb, 6.0, "crags", "pale_stalker")
	# the cold cage gives off a little light: the spire is a mark on the Crowns' foot at night
	_light(host, at.call(cage + Vector3(0, 1.5, 0)), Color(0.7, 0.8, 1.0), 1.0, 8.0)
	var items := {}
	_ring_plants(items, space, rng, "heather", o, h + 1.5, 8.0, 40)
	_ring_plants(items, space, rng, "grass", o, h + 1.2, 8.0, 60)
	_ring_plants(items, space, rng, "moss", o, h + 0.8, 4.5, 16)
	_plants(host, items)


# --- discovery ---------------------------------------------------------------------------------
# r33: the r31 Watch (a zone_entered title card per place) became realm_discovery.gd's subzones.

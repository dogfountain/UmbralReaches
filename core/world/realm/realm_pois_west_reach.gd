extends RefCounted
## The West Reach's places (docs/far_reaches.md; realm_pois.gd REACH_POIS): so far the Greyfell's Broken Keep and fell shrine
## (west_reach_greyfell.gd; models tools/blender/reach_west*.py -> art/models/reach_w_*.glb). Reedholm is the towns'
## (reach_towns*.gd). `reserve(root)` before the terrain stamp and the flora, `build(holder)` after. `--no-west-reach` skips it.

const Greyfell := preload("res://core/world/realm/west_reach_greyfell.gd")
const Kit37 := preload("res://core/world/realm/west_marches_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const CAPS := "vista_caps.glb"
const RING_C := Vector2(-330.0, -8.0)            ## the ring of giant caps (the Lanternwood's slot)
## giants round the clearing: [bearing deg, distance, piece, yaw]
const BARROW := "vista_barrow.glb"
const BARROW_C := Vector2(-345.0, 152.0)          ## the King's Barrow (its slot); it lies along the ridge, its door to the south
const ROW_C := Vector2(-300.0, 128.0)             ## the stone row's middle; it runs north-south along the ridge
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const MILE := "vista_milestone.glb"
const MILE_C := Vector2(-350.0, 44.0)             ## the Last Milestone (its slot), by the road's end
const HERON_C := Vector2(-340.0, 360.0)           ## the heron stones, standing in the mere
const GIANTS := [[200.0, 9.5, "Giant0", 0.4], [320.0, 10.5, "Giant1", 2.3], [80.0, 9.0, "Giant2", 4.1]]

static var built: Array[String] = []


static func _off() -> bool:
	return "--no-west-reach" in OS.get_cmdline_user_args()


const CHAIN_STAIR_FOOT := Vector2(-342.4, -12.0)         ## the chain span wonder's west approach stair, where it meets the ground

static func reserve(root: Node) -> void:
	if _off():
		return
	Greyfell.release()
	var space := (root as Node3D).get_world_3d().direct_space_state
	Greyfell.reserve(space)
	Flora.tree_clear.append([RING_C, 20.0])
	Flora.tree_clear.append([BARROW_C, 24.0])
	WorldLanes.register_terrace("poi_kings_barrow", BARROW_C + Vector2(0.0, 3.0), 18.5, RealmLayout.ground(space, BARROW_C.x, BARROW_C.y))
	Flora.tree_clear.append([ROW_C, 26.0])
	Flora.tree_clear.append([MILE_C + Vector2(0.0, -4.0), 14.0])
	var mg := RealmLayout.ground(space, MILE_C.x, MILE_C.y)
	WorldLanes.register_site("poi_last_milestone", Rect2(MILE_C - Vector2(5.0, 12.0), Vector2(10.0, 15.0)), mg, mg)
	Flora.tree_clear.append([HERON_C, 20.0])               # the willows' fronds reach far: the stones stand in open water
	var g := RealmLayout.ground(space, RING_C.x, RING_C.y)
	WorldLanes.register_site("poi_giant_caps", Rect2(RING_C - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), g, g)


static func build(holder: Node3D) -> void:
	built.clear()
	if _off():
		return
	Greyfell.build(holder, holder.get_world_3d().direct_space_state)
	built.append("greyfell")
	_caps(holder, holder.get_world_3d().direct_space_state)
	built.append("giant_caps")
	_barrow(holder, holder.get_world_3d().direct_space_state)
	built.append("kings_barrow")
	_milestone(holder, holder.get_world_3d().direct_space_state)
	built.append("last_milestone")
	_herons(holder, holder.get_world_3d().direct_space_state)
	built.append("heron_stones")
	print("REALM_POI west reach built %s" % [built])


static var _mats := {}


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m: StandardMaterial3D
	if kind == "turf":
		m = Kit37.mat("daub").duplicate() as StandardMaterial3D
		m.albedo_texture = null
		m.normal_scale = 0.5
		m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	elif kind == "stone":
		m = Kit37.mat("hewn").duplicate() as StandardMaterial3D
		m.normal_scale = 0.45
		m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	elif kind == "glow":
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# a cold glow under the gills, not a neon band (region_lanternwood_0, 19 Nov: the brightest, most saturated thing in
		# the Far Reaches, as loud as a UI mark): darker and a little greyed toward the night
		m.albedo_color = Color(0.62, 0.68, 0.7)
	else:
		m = Kit37.mat("daub").duplicate() as StandardMaterial3D
		m.albedo_texture = null                       # the skin's colour is the vertex tone; the set gives it grain
		m.normal_scale = 0.35
		m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	_mats[kind] = m
	return m


## The ring of giant caps: three giants round a clearing, a fairy ring of small ones between them, spores drifting in the
## cold light under the gills. The light is the fungus's own: cold, not warmth (nothing here burns).
static func _caps(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var host := Node3D.new()
	host.name = "Poi_giant_caps"
	host.set_meta("site", "poi_giant_caps")
	host.add_to_group("world_poi")
	host.set_meta("reach", true)
	host.set_meta("poi", "giant_caps")
	host.set_meta("title", "The Ring of Caps")
	host.set_meta("line", "the light grows out of the dead")
	host.set_meta("region", "lanternwood")
	host.set_meta("centre", Vector3(RING_C.x, RealmLayout.ground(space, RING_C.x, RING_C.y) + 3.0, RING_C.y))
	host.set_meta("radius", 18.0)
	holder.add_child(host)
	var pieces: Array = []
	for gd: Array in GIANTS:
		var a := deg_to_rad(float(gd[0]))
		pieces.append([RING_C + Vector2(cos(a), sin(a)) * float(gd[1]), String(gd[2]), float(gd[3]), 1.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for k in 14:
		var a := TAU * (k + rng.randf_range(-0.25, 0.25)) / 14.0
		var r := rng.randf_range(13.0, 16.0)
		pieces.append([RING_C + Vector2(cos(a), sin(a)) * r, "Small%d" % (k % 3), rng.randf() * TAU, rng.randf_range(0.8, 1.35)])
	for pc: Array in pieces:
		var q: Vector2 = pc[0]
		if RealmLayout.path_dist(q) < 2.0:
			continue
		if q.distance_to(CHAIN_STAIR_FOOT) < 6.0:
			continue                          # the Chain Span's west stair foot: zone fit, a small cap stood across its first step
		var y := RealmLayout.ground(space, q.x, q.y) - 0.25
		var root := Kit37.place(host, CAPS, Transform3D(Basis(Vector3.UP, float(pc[2])), Vector3(q.x, y, q.y)), {"pick": String(pc[1]), "scale": Vector3.ONE * float(pc[3])})
		if root == null:
			continue
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var glow := String(mi.name).contains("__glow")
			mi.material_override = _mat("glow" if glow else "skin")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if glow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if String(pc[1]).begins_with("Giant"):
			var e := Vfx.emitter(Color(0.45, 0.95, 0.85, 0.55), {"count": 14, "life": 7.0, "speed": Vector2(0.02, 0.1), "size": 0.04, "gravity": -0.01, "radius": 3.0, "turbulence": true, "explosive": 0.0})
			if e:
				e.name = "CapSpores"
				host.add_child(e)
				e.global_position = Vector3(q.x, y + 6.0, q.y)
				e.visibility_range_end = 45.0
	P._perch(host, Vector3(pieces[0][0].x, RealmLayout.ground(space, pieces[0][0].x, pieces[0][0].y) + 14.5, pieces[0][0].y), Vector3(1, 0, 0), 14.0)


## The King's Barrow (tools/blender/vista_barrow.py): the long mound with its kerb, the horned forecourt and the open
## door, a passage into a corbelled chamber with a chest; and the stone row along the ridge (weathered RockKit slabs,
## leaning, one fallen), a named place each.
static func _barrow(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var g := RealmLayout.ground(space, BARROW_C.x, BARROW_C.y)
	var host := _poi(holder, "kings_barrow", "The King's Barrow", "one door stands open", "kingsbarrows", Vector3(BARROW_C.x, g + 3.0, BARROW_C.y), 22.0)
	# it lies along the ridge's contour (north-south), the door to the south: the forecourt and the back end at one height
	var by := g - 0.1                                     # on its levelled terrace (reserve)
	var root := Kit37.place(host, BARROW, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(BARROW_C.x, by, BARROW_C.y)), {})
	if root != null:
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			mi.material_override = _mat("turf" if String(mi.name).contains("Mound") else "stone")
		var ch: Node3D = Chest.new()
		ch.name = "Chest_kings_barrow"
		ch.set("chest_id", "kings_barrow")
		ch.set("tier", "iron")
		ch.set("loot", {"grave_ash": 16, "grave_iron": 2, "relic_fragment": 1})
		host.add_child(ch)
		ch.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), root.global_transform * Vector3(3.5 - 1.6, 0.05, 0.0))
	var row := _poi(holder, "stone_row", "The Stone Row", "the kings' road to the west, in stone", "kingsbarrows", Vector3(ROW_C.x, RealmLayout.ground(space, ROW_C.x, ROW_C.y) + 1.5, ROW_C.y), 24.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	for k in 14:
		var z := ROW_C.y - 22.0 + k * 3.3
		var x := ROW_C.x + 1.2 * sin(k * 0.7)
		var q := Vector2(x, z)
		if RealmLayout.path_dist(q) < 2.5:
			continue
		var h := rng.randf_range(1.4, 3.2) * (1.25 if k == 7 else 1.0)
		var fallen := k == 10
		var mesh := RockKit.slab(rng.randi(), Vector3(rng.randf_range(0.9, 1.3), h, rng.randf_range(0.45, 0.7)), "mossy", 0.3)
		var y := RealmLayout.ground(space, x, z)
		var b := Basis(Vector3.UP, rng.randf_range(-0.25, 0.25) + PI * 0.5)
		if fallen:
			b = b * Basis(Vector3.RIGHT, PI * 0.47)
		else:
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.1, 0.1))
		RockKit.spawn(row, mesh, Transform3D(b, Vector3(x, y - (0.0 if fallen else 0.3), z)))


static func _poi(holder: Node3D, id: String, title: String, line: String, region: String, centre: Vector3, r: float) -> Node3D:
	var host := Node3D.new()
	host.name = "Poi_" + id
	host.set_meta("site", "poi_" + id)
	host.add_to_group("world_poi")
	host.set_meta("reach", true)
	host.set_meta("poi", id)
	host.set_meta("title", title)
	host.set_meta("line", line)
	host.set_meta("region", region)
	host.set_meta("centre", centre)
	host.set_meta("radius", r)
	holder.add_child(host)
	return host


## The Last Milestone and the toll-house (tools/blender/vista_milestone.py) where the road ends: the stone by the road,
## the house behind it to the north, its door to the road.
static func _milestone(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var g := RealmLayout.ground(space, MILE_C.x, MILE_C.y)
	var host := _poi(holder, "last_milestone", "The Last Milestone", "the road went on; the pilgrims did not", "lanternwood", Vector3(MILE_C.x, g + 2.0, MILE_C.y), 12.0)
	var root := Kit37.place(host, MILE, Transform3D(Basis.IDENTITY, Vector3(MILE_C.x, g - 0.15, MILE_C.y)), {})
	if root == null:
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).contains("__hewn"):
			mi.material_override = _mat("stone")


## The heron stones: seven tall slabs standing in the mere in a ring, one fallen into the water (the herons stand on them).
static func _herons(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var host := _poi(holder, "heron_stones", "The Heron Stones", "the fishers' first shrine; the herons keep it", "reedmere", Vector3(HERON_C.x, RealmLayout.ground(space, HERON_C.x, HERON_C.y) + 2.0, HERON_C.y), 12.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4848
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf_range(-0.12, 0.12)
		var q := HERON_C + Vector2(cos(a), sin(a)) * rng.randf_range(5.0, 6.2)
		var h := rng.randf_range(3.0, 4.6)
		var mesh := RockKit.slab(rng.randi(), Vector3(rng.randf_range(0.8, 1.1), h, rng.randf_range(0.4, 0.6)), "mossy", 0.35)
		var y := RealmLayout.ground(space, q.x, q.y)
		var b := Basis(Vector3.UP, a + PI * 0.5)
		if k == 4:
			b = b * Basis(Vector3.RIGHT, PI * 0.42)
		else:
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
		RockKit.spawn(host, mesh, Transform3D(b, Vector3(q.x, y - 0.4, q.y)))

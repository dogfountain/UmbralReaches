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
const GIANTS := [[200.0, 9.5, "Giant0", 0.4], [320.0, 10.5, "Giant1", 2.3], [80.0, 9.0, "Giant2", 4.1]]

static var built: Array[String] = []


static func _off() -> bool:
	return "--no-west-reach" in OS.get_cmdline_user_args()


static func reserve(root: Node) -> void:
	if _off():
		return
	Greyfell.release()
	var space := (root as Node3D).get_world_3d().direct_space_state
	Greyfell.reserve(space)
	Flora.tree_clear.append([RING_C, 20.0])
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
	print("REALM_POI west reach built %s" % [built])


static var _mats := {}


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m: StandardMaterial3D
	if kind == "glow":
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
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

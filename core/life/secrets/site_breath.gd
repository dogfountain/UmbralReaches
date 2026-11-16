extends RefCounted
## THE ASH-HERMIT'S PERCH (r28, agent D): a ruined watch-tower on the rift's west rim, its door
## choked with rubble, its stair long fallen. At its foot a fissure breathes out every nine
## seconds (breath_vent.gd): jump into the hot column as it roars and it carries you up past the
## broken parapet onto the top, where a hermit lived eleven winters watching the Crossing. His
## brazier is the small red light you see from the Crossing. Timing (the rift's breath) and
## traversal (a jump, then steering in the air) in one.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Vent := preload("res://core/life/secrets/breath_vent.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")

const RIM_NEAR := Vector2(-36.0, -50.0) + Endgame.O2       ## the west rim, north of the Fallen Bells (the far north-east)
const TR := 2.0                  ## tower radius (outer)
const TH := 6.0                  ## top floor above its foot


static func build(root: Node, host: Node3D) -> void:
	var sp := Kit.space(root)
	# the nearest clear rim ground to RIM_NEAR where the tower and its vent (east of it) stand level
	var ok := func(q: Vector2) -> bool:
		var v := q + Vector2(TR + 1.25, 0.0)
		var lo := Kit.low(sp, q, TR)
		var gv := Kit.gy(sp, v.x, v.y)
		return absf(gv - lo) < 0.9 and gv > RealmLayout.LAVA_Y + 8.0 and Kit.low(sp, v, 1.3) > gv - 0.7
	var t2 := LK.search_spot(sp, RIM_NEAR, 26.0, Vector2(4.6, 3.0), 1.2, 1.4, ["secrets_breath"], 2.5, ok)
	if t2 == Vector2.INF:            # r34 merge: the doubled land steepened this rim; look further along it
		t2 = LK.search_spot(sp, RIM_NEAR, 44.0, Vector2(4.6, 3.0), 1.2, 1.4, ["secrets_breath"], 2.5, ok)
	if t2 == Vector2.INF:            # the rift's berms and the burn's dressing left one level spot in 44 m: further, a little rougher
		t2 = LK.search_spot(sp, RIM_NEAR, 64.0, Vector2(4.6, 3.0), 1.2, 1.9, ["secrets_breath"], 2.0, ok)
	if t2 == Vector2.INF:
		print("SECRETS hermit's perch: no clear spot")
		PlacementLog.skip("secrets", "hermits_perch", Vector3(RIM_NEAR.x, 0, RIM_NEAR.y), "no clear spot")
		return
	var vent2 := t2 + Vector2(TR + 1.25, 0.0)
	var node := Node3D.new()
	node.name = "HermitsPerch"
	node.set_meta("site", "secrets_breath")
	host.add_child(node)
	var fy := Kit.low(sp, t2, TR + 0.2)
	var top := fy + TH
	Kit.clear_flora(root, [Vector3(t2.x + 0.6, t2.y, 5.0)])
	Kit.site(root, "secrets_breath", Rect2(t2.x - 2.6, t2.y - 2.6, 6.8, 5.2), fy)
	var k := OssKit.new()
	k.keep_lanes = false
	LK.ensure_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var c := Vector3(t2.x, fy, t2.y)
	# the tower: a ring of coursed stone, broken lower on the rift side, rubble choking the door
	var n := 18
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		var dir := Vector3(cos(a), 0, sin(a))
		var broken := absf(angle_difference(a, 0.0)) < 0.5          # east: the parapet is gone
		var h := TH + (0.0 if broken else rng.randf_range(0.7, 1.3))
		var seg := TAU * (TR - 0.25) / float(n) + 0.06
		var b := Basis(Vector3.UP, -a + PI * 0.5)
		k.box("lore_ashlar", c + dir * (TR - 0.25) + Vector3.UP * (h * 0.5 - 0.4), Vector3(seg, h + 0.8, 0.5), b, true, rng.randf_range(0.8, 1.0))
		if i % 3 == 0:
			k.box("lore_ashlar", c + dir * (TR - 0.05) + Vector3.UP * (h * 0.3), Vector3(seg * 0.6, 0.18, 0.2), b, false, 0.85)   # string course
		if not broken and i % 2 == 0:
			k.box("lore_ashlar", c + dir * (TR - 0.25) + Vector3.UP * (h + 0.25), Vector3(seg * 0.7, 0.5, 0.5), b, true, 0.9)     # merlons
	# the top floor: a disc of flags under the hermit's camp, a thick slab under it
	var cc := c + Vector3.UP * TH
	for i in 16:
		var a0 := TAU * float(i) / 16.0
		var a1 := TAU * float(i + 1) / 16.0
		var p0 := cc + Vector3(cos(a0), 0, sin(a0)) * (TR - 0.45)
		var p1 := cc + Vector3(cos(a1), 0, sin(a1)) * (TR - 0.45)
		k.quad("lore_rubble", cc, p0, p1, cc, Vector3.UP)
	k.block("lore_ashlar", cc + Vector3(-TR + 0.6, -0.4, -TR + 0.6), cc + Vector3(TR - 0.6, -0.02, TR - 0.6), false, 0.7)
	var door := c + Vector3(-TR, 0, 0)
	L_rubble(k, door + Vector3(-0.4, 0, 0), rng)
	# inside the top: bedroll, brazier, the slate, the cache
	var deck := c + Vector3.UP * TH
	k.box("lore_cloth", deck + Vector3(-0.5, 0.06, 0.6), Vector3(0.7, 0.12, 1.6), Basis(Vector3.UP, 0.3), false, 0.75)
	k.box("iron", deck + Vector3(-0.6, 0.3, -0.7), Vector3(0.5, 0.5, 0.5), Basis(Vector3.UP, 0.2), true, 0.6)
	k.box("lore_char", deck + Vector3(-0.6, 0.57, -0.7), Vector3(0.38, 0.06, 0.38), Basis(Vector3.UP, 0.4), false, 0.4)
	k.box("wood", deck + Vector3(0.35, 0.22, -0.9), Vector3(0.55, 0.44, 0.38), Basis(Vector3.UP, -0.3), true, 0.7)
	k.box("iron", deck + Vector3(0.35, 0.24, -0.9), Vector3(0.57, 0.05, 0.4), Basis(Vector3.UP, -0.3), false)
	# the vent: a split in the rock, its crack faintly hot, scorched stones round it
	var vg := Kit.gy(sp, vent2.x, vent2.y)
	var vent := Vector3(vent2.x, vg, vent2.y)
	for j in 10:
		var ra := TAU * float(j) / 10.0 + rng.randf() * 0.3
		k.box("lore_rock", vent + Vector3(cos(ra) * 0.95, 0.05, sin(ra) * 0.95), Vector3(0.45, 0.3, 0.35), Basis(Vector3.UP, ra) * Basis(Vector3.RIGHT, 0.3), j % 3 == 0, 0.45)
	k.commit(node, "PerchBody")
	_fade(node, 160.0)
	var crack := MeshInstance3D.new()
	crack.name = "Crack"
	crack.mesh = _box(Vector3(1.3, 0.04, 0.22))
	crack.material_override = OssKit.mat("lore_ember")
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var vn: Node3D = Vent.new()
	vn.name = "Breath"
	vn.set("top_y", top)
	vn.add_child(crack)
	vn.position = vent                # the holder sits at the origin: set before _ready builds
	node.add_child(vn)
	crack.rotation.y = 0.6
	# the hermit's brazier light, seen from the Crossing (well under the glow threshold)
	var bl := Kit.omni(node, deck + Vector3(-0.6, 1.1, -0.7), Color(1.0, 0.42, 0.16), 1.0, 6.0)
	bl.distance_fade_begin = 120.0
	bl.distance_fade_length = 20.0
	var ember := MeshInstance3D.new()
	ember.mesh = _box(Vector3(0.3, 0.1, 0.3))
	ember.material_override = OssKit.mat("lore_ember")
	node.add_child(ember)
	ember.global_position = deck + Vector3(-0.6, 0.62, -0.7)
	State.reading(node, "sc_breath", vent + Vector3(-1.1, 0.5, 1.0))
	State.reading(node, "sc_breath_top", deck + Vector3(0.6, 0.5, 0.5))
	State.cache(node, "breath", deck + Vector3(0.35, 0.5, -0.9), "the hermit's box", Callable())
	State.register({"id": "breath", "name": "The Ash-Hermit's Perch", "at": deck, "r": 2.2, "node": node,
		"vent": vent, "top": deck + Vector3(-0.2, 0.0, 0.0),
		"route": {"from": Vector3(vent.x + 1.0, 0.0, vent.z + 8.0), "pts": [Vector3(vent.x + 1.0, 0, vent.z + 3.0), Vector3(vent.x, 0, vent.z + 1.8)] as Array[Vector3]},
		"goal": Vector3(vent.x, vg, vent.z + 1.8)})


static func L_rubble(k: OssKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for j in 9:
		var q := at + Vector3(rng.randf_range(-0.6, 0.4), rng.randf_range(0.1, 1.4), rng.randf_range(-0.7, 0.7))
		k.box("lore_ashlar", q, Vector3(rng.randf_range(0.35, 0.6), rng.randf_range(0.25, 0.4), rng.randf_range(0.3, 0.5)), Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))), true, 0.8)


static func _fade(node: Node3D, end: float) -> void:
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = end
			(ch as GeometryInstance3D).visibility_range_end_margin = end * 0.1
			(ch as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

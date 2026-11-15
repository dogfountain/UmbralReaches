extends RefCounted
## The East Reach's landmarks (docs/far_reaches.md; RealmPois REACH_POIS: reserve() before the stamp and the flora,
## build() after), placed by ground ray. Lastlight and its East Gate are the towns' (reach_towns*.gd).
##
##   bellfall   the eighth bell (tools/blender/vista_bell.py): fallen on its side in the
##              crater at RealmReaches.CRATER_C, a third sunk, its mouth toward the south lip where bell_track comes in;
##              the lip's shards thrown across the floor, fallen rock heaped round it, thin smoke still rising from the
##              impact's cracks, a chest in its mouth, a glide perch on its back. Far mesh from 140 m.
##   nave       the Drowned Nave (tools/blender/reach_east_nave.py, the East agent's model): the unfinished cathedral in
##              its flooded basin at NAVE_C, west front to nave_track; far mesh from 160 m.
##   `-- --no-east-reach` turns it off.

const Kit37 := preload("res://core/world/realm/west_marches_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const SMOKE := preload("res://core/world/realm/vistas/beacon_smoke.gdshader")
const SecretKit := preload("res://core/life/secrets/kit.gd")

const BELL := "vista_bell.glb"
const SCALE := 1.55                          ## the model is 12.6 m across the mouth: the eighth bell is ~20
const BELL_FAR := "res://art/models/vista_bell_far.glb"
const NAVE := "res://art/models/reach_e_nave.glb"
const NEAR_END := 140.0
const LOOT := {"bellfall_mouth": ["iron", {"grave_ash": 18, "grave_iron": 2, "relic_fragment": 1}]}

static var built: Array[String] = []
static var _mats := {}
static var _bell_y := 0.0


static func off() -> bool:
	return "--no-east-reach" in OS.get_cmdline_user_args()


static func reserve(root: Node) -> void:
	if off():
		return
	var space := (root as Node3D).get_world_3d().direct_space_state
	var c := RealmReaches.CRATER_C
	_bell_y = INF
	for k in 9:
		var q := c + Vector2(cos(TAU * k / 9.0), sin(TAU * k / 9.0)) * (0.0 if k == 0 else 5.0)
		_bell_y = minf(_bell_y, RealmLayout.ground(space, q.x, q.y))
	Flora.tree_clear.append([c, 34.0])                # the crater burned: nothing grows in it yet
	var nc := RealmReaches.NAVE_C
	Flora.tree_clear.append([nc, 30.0])
	for k in 5:                                          # nave_track's last bend: the west front seen down the water
		Flora.tree_clear.append([Vector2(298.0, 124.0).lerp(nc, float(k) / 5.0), 9.0 + k])
	WorldLanes.register_site("poi_nave", Rect2(nc - Vector2(10.0, 30.0), Vector2(20.0, 60.0)), RealmLayout.ground(space, nc.x, nc.y), RealmLayout.ground(space, nc.x, nc.y))
	WorldLanes.register_site("poi_bellfall", Rect2(c - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), _bell_y, _bell_y)


static func build(holder: Node3D) -> void:
	built.clear()
	if off():
		return
	var space := holder.get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "Poi_bellfall"
	host.set_meta("site", "poi_bellfall")
	host.add_to_group("world_poi")
	host.set_meta("poi", "bellfall")
	host.set_meta("title", "The Eighth Bell")
	host.set_meta("line", "cast in the sky, and the sky let it fall")
	host.set_meta("region", "bellfall")
	holder.add_child(host)
	_bell(host, space)
	built.append("bellfall")
	if _nave(holder, space):
		built.append("nave")
	print("REALM_POI east reach built %s" % [built])


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m: StandardMaterial3D
	match kind:
		"bronze":
			m = Kit37.mat("iron").duplicate() as StandardMaterial3D
			m.albedo_texture = null                     # the bronze and its patina are the vertex colour
			m.metallic_texture = null
			m.metallic = 0.72
			m.roughness = 0.9                           # (x the orm's roughness)
			m.normal_scale = 0.45
			m.uv1_scale = Vector3(3.0, 3.0, 3.0)
		"glow":
			m = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.5, 0.62, 0.8)    # cold, faint: well under the glow threshold
		_:
			m = Kit37.mat(kind)
	_mats[kind] = m
	return m


static func _bell(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var c := RealmReaches.CRATER_C
	var at := Vector3(c.x, _bell_y, c.y)
	var root := Kit37.place(host, BELL, Transform3D(Basis(Vector3.UP, deg_to_rad(-8.0)), at), {"scale": Vector3.ONE * SCALE})
	if root == null:
		return
	root.name = "EighthBell"
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		var kind := nm.get_slice("__", 1).get_slice(".", 0) if nm.contains("__") else "bronze"
		mi.material_override = _mat(kind)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "glow" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var fs := (load(BELL_FAR) as PackedScene).instantiate()
	var fm := fs.find_children("*", "MeshInstance3D", true, false)
	if not fm.is_empty():
		FarDetail.register(root, (fm[0] as MeshInstance3D).mesh, Transform3D.IDENTITY, NEAR_END, _mat("bronze"))
	fs.free()
	# fallen rock heaped round it: the floor thrown up where it struck (more on the low, north side)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for k in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, 24.0)
		var q := c + Vector2(cos(a), sin(a) * 0.85) * r
		if RealmLayout.path_dist(q) < 3.0:
			continue
		var s := rng.randf_range(0.8, 2.6) * (1.25 if sin(a) < 0.0 else 1.0)
		var y := RealmLayout.ground(space, q.x, q.y)
		var bm := RockKit.boulder(rng.randi(), Vector3(s * 1.4, s * 0.75, s), "granite")
		RockKit.spawn(host, bm, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), Vector3(q.x, y - 0.2 * s, q.y)), s > 1.2)
	# smoke still rising from the impact's cracks
	for k in 4:
		var a := 0.9 + k * 1.6
		var q := c + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 15.0)
		var mi := MeshInstance3D.new()
		mi.name = "BellSmoke%d" % k
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 16.0)
		quad.center_offset = Vector3(0.0, 8.0, 0.0)
		var sm := ShaderMaterial.new()
		sm.shader = SMOKE
		sm.set_shader_parameter("energy", 0.42)
		sm.set_shader_parameter("wind", Vector2(0.35, 0.5))
		quad.material = sm
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("seed", float(k) * 2.3)
		mi.visibility_range_end = 220.0
		mi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mi)
		mi.global_position = Vector3(q.x, RealmLayout.ground(space, q.x, q.y) - 0.3, q.y)
	# a chest in its mouth, a perch on its back
	var ch: Node3D = Chest.new()
	ch.name = "Chest_bellfall_mouth"
	ch.set("chest_id", "bellfall_mouth")
	ch.set("tier", LOOT.bellfall_mouth[0])
	ch.set("loot", (LOOT.bellfall_mouth[1] as Dictionary).duplicate())
	host.add_child(ch)
	var mouth := root.global_transform * Vector3(0.0, 0.0, 2.6)
	ch.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(mouth.x, RealmLayout.ground(space, mouth.x, mouth.z) + 0.02, mouth.z))
	P._perch(host, root.global_transform * Vector3(0.0, 8.2, -2.0), Vector3(0.0, 0.0, 1.0), 8.0)


static func _nave(holder: Node3D, space: PhysicsDirectSpaceState3D) -> bool:
	var ps := load(NAVE) as PackedScene
	if ps == null:
		return false
	var nc := RealmReaches.NAVE_C
	var host := Node3D.new()
	host.name = "Poi_nave"
	host.set_meta("site", "poi_nave")
	host.add_to_group("world_poi")
	host.set_meta("poi", "nave")
	host.set_meta("title", "The Drowned Nave")
	host.set_meta("line", "the water came in before the floor did")
	host.set_meta("region", "nave")
	holder.add_child(host)
	var root := ps.instantiate() as Node3D
	root.name = "DrownedNave"
	host.add_child(root)
	root.global_transform = Transform3D(Basis.IDENTITY, Vector3(nc.x, RealmLayout.ground(space, nc.x, nc.y), nc.y))
	var far: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.begins_with("NaveCol"):
			mi.create_trimesh_collision()
			mi.visible = false
		elif nm.begins_with("NaveFar"):
			far = mi.mesh
			mi.queue_free()
	if far != null:
		FarDetail.register(root, far, Transform3D.IDENTITY, 160.0)
	_nave_shafts(host, root)
	return true


## Moonlight down through the vault where it stands open (the bays past the third): soft shafts along the moon's own
## direction (the glades' shaft material), falling on the water between the piers.
static func _nave_shafts(host: Node3D, root: Node3D) -> void:
	var moon := Vector3(0.35, -0.85, 0.4).normalized()
	for l in host.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if not l.has_meta(&"no_shadow"):
			moon = -(l as DirectionalLight3D).global_basis.z
			break
	var up := -moon
	var mesh := QuadMesh.new()
	mesh.size = Vector2(5.0, 30.0)
	mesh.center_offset = Vector3(0, 15.0, 0)
	var mat := SecretKit.shader_mat("shaft")
	var node := Node3D.new()
	node.name = "VaultShafts"
	host.add_child(node)
	for zl: float in [-6.0, 4.0, 13.0, 21.0]:
		var at := root.global_transform * Vector3(0.0, -0.4, zl)
		for k in 2:
			var yaw := float(k) * PI * 0.5 + 0.3
			var side := Vector3(cos(yaw), 0, sin(yaw)).cross(up).normalized()
			var fwd := side.cross(up).normalized()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 110.0
			mi.visibility_range_end_margin = 14.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mi)
			mi.global_transform = Transform3D(Basis(side, up, fwd), at)
			mi.set_instance_shader_parameter(&"strength", 1.0)

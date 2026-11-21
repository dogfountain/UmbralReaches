extends RefCounted
## THE WORLD'S MATERIALS, WARMED (behind the loading cover; NightWarm.show calls `show`). The loading screen's tour draws what the Realm placed near its
## stops; materials the world makes later or only in a few places were first built and compiled mid-play. Drawn here once, each on the instanced or plain
## path it is used on:
##   every OssKit material (world/areas/ossuary/oss_kit.gd mat(): the masonry, caves and cave moss, crystal, bone, wax, lit glass "glow", and the candle flame and halo
##   shaders on a MultiMesh as the landmark kits draw them): the deep halls, caves, the Titan Gates, the Wardens' cresset and the Sleeper are built of these;
##   every RockKit style (strata, lichen, moss, ash and ember: granite, mossy, basalt, ash) on a RockKit boulder with its vertex colours;
##   the wonder kits' water plane (WonderKit._water_mat) and the shorelines' wet band (the same flags, drawn alike);
##   every tree-bark and foliage material (TreeGen.BARK, the cap, and each art/materials/realm_foliage*.tres) on a MultiMesh quad.
## Nothing here edits a builder: the lists are the builders' own constants where they have them (RockKit.STYLES, TreeGen.BARK) and a list checked against the
## source by zz/night_life_test.tscn where they do not (`OSS_KEYS` against oss_kit.gd's match). Files in the wonders' newest builder folder that make a material
## must be in `COVERED`. Static; load by path.

const OssKit := preload("res://world/areas/ossuary/oss_kit.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const WonderKit := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")

const OSS_KEYS := ["hub", "stone", "plaster", "brick", "ruin", "floor", "dark", "iron", "wood", "slate", "stone_big", "ruin_big", "brick_big", "wood_big", "bark", "chalk",
	"cave", "cave_moss", "crystal", "bone", "bone_cm", "wax", "halo", "glow", "flame"]

## the wonders builders' files that make a material of their own -> how it is warmed
const COVERED := {
	"wonder_kit.gd": "the water plane (WonderKit._water_mat) on a plane (show)",
	"shorelines.gd": "the wet band: the same flags as its StandardMaterial3D, on a quad (show)",
}


static func show(host: Node3D, out: Array[Node], c: Vector3, right: Vector3, fwd: Vector3) -> void:
	var base := c + fwd * 4.0
	var n := 0
	# the kit materials: a box each, in rows of ten; flame and halo on a MultiMesh of quads (how the kits draw them)
	for key: String in OSS_KEYS:
		var at := base + right * (float(n % 10) - 5.0) * 0.6 + fwd * float(n / 10) * 0.6 + Vector3.UP * 0.4
		n += 1
		var m := OssKit.mat(key)
		if key == "flame" or key == "halo":
			_multi(host, out, m, at)
		else:
			_mesh(host, out, BoxMesh.new(), m, at)
	# the rock kit's styles, on a real boulder
	var ri := 0
	for style: String in RockKit.STYLES:
		var rm: ArrayMesh = RockKit.boulder(11 + ri, Vector3(0.7, 0.6, 0.7), style)
		_mesh(host, out, rm, RockKit.material(style), base + right * (float(ri) * 1.0 - 2.0) + fwd * 2.4 + Vector3.UP * 0.3)
		ri += 1
	# the water plane and the shore's wet band
	var plane := QuadMesh.new()
	plane.size = Vector2(1.5, 1.5)
	plane.orientation = PlaneMesh.FACE_Y
	_mesh(host, out, plane, WonderKit._water_mat(), base + right * 4.5 + Vector3.UP * 0.05)
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.03, 0.04, 0.045, 0.55)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.25
	wet.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(host, out, plane, wet, base + right * 6.5 + Vector3.UP * 0.05)
	# the bark and foliage materials, each on a one-instance MultiMesh of a quad (the cards' instanced path)
	var paths: Array[String] = []
	for k: String in TreeGen.BARK:
		paths.append(String(TreeGen.BARK[k]))
	paths.append(TreeGen.CAP_MAT)
	for f: String in DirAccess.get_files_at("res://art/materials/"):
		if f.begins_with("realm_foliage") and f.ends_with(".tres"):
			var p := "res://art/materials/" + f
			if not paths.has(p):
				paths.append(p)
	var fi := 0
	for p: String in paths:
		var res := load(p) as Material
		if res != null:
			_multi(host, out, res, base - right * (3.0 + float(fi) * 0.5) + Vector3.UP * 1.0)
		fi += 1


static func _mesh(host: Node3D, out: Array[Node], mesh: Mesh, mat: Material, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = at
	out.append(mi)


static func _multi(host: Node3D, out: Array[Node], mat: Material, at: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, at))
	var mi := MultiMeshInstance3D.new()
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # never moves (umbral-donts: Static MultiMeshes)
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))
	host.add_child(mi)
	mi.global_position = Vector3.ZERO
	out.append(mi)

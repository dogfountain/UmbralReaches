extends RefCounted
## West Marches: placing the in-house landmark models (tools/blender/r37_west.py) in the world.
## Each glb is a set of mesh nodes named `<part>__<set>` (set = stone / ashlar / timber / iron), a
## `<asset>-colonly` collision node (Godot makes it a StaticBody3D with trimesh shape), and sometimes a
## node that moves (the mill's wheel). The meshes carry metric box UVs and baked vertex tone; the
## tiling PBR sets art/textures/r37_<set>_{albedo,normal,orm}.png (tools/blender/r37_west_textures.py)
## dress them here. Load by path (no class_name).

const T := "res://art/textures/"
const M := "res://art/models/"
const WheelSpin := preload("res://core/world/realm/mill_wheel_spin.gd")

static var _mats := {}
static var _scenes := {}


static func release() -> void:
	_mats.clear()
	_scenes.clear()


## The tiling PBR material of a set ("stone", "ashlar", "timber", "iron").
static func mat(set_name: String) -> StandardMaterial3D:
	if _mats.has(set_name):
		return _mats[set_name]
	var m := StandardMaterial3D.new()
	var base := T + "r37_%s_" % set_name
	m.albedo_texture = load(base + "albedo.png")
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.png")
	var orm: Texture2D = load(base + "orm.png")
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	if set_name == "iron":
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[set_name] = m
	return m


## The same sets for small props (a headstone, a cairn, a lectern): the texture tiles 3x finer and the normal map
## is quieter, so a 0.5 m stone is not covered in a building's coarse grain.
static func prop_mat(set_name: String) -> StandardMaterial3D:
	var key := "prop_" + set_name
	if _mats.has(key):
		return _mats[key]
	var m := mat(set_name).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(3, 3, 3)
	m.normal_scale = 0.35
	_mats[key] = m
	return m


static func scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		_scenes[file] = load(M + file) as PackedScene
	return _scenes[file]


## Instance `file` under `parent` at `xf` (world), dressed. `opts`: pick (a child node name to keep, the
## rest dropped: palisade / trebuchet variants), shadow (bool, default true), range_end (visibility range
## for the visual meshes, fades), shift (local offset of the picked variant in the file), spin (name prefix of the node that turns: the wheel), spin_rate (rad/s).
static func place(parent: Node3D, file: String, xf: Transform3D, opts := {}) -> Node3D:
	var ps := scene(file)
	if ps == null:
		push_warning("r37_west_kit: no %s" % file)
		return null
	var root := ps.instantiate() as Node3D
	parent.add_child(root)
	root.global_transform = xf
	if opts.has("shift"):                       # a variant modelled apart in the file: bring it to the root
		root.global_position -= root.global_basis * (opts.shift as Vector3)
	var keep := String(opts.get("pick", ""))
	var meshes: Array[MeshInstance3D] = []
	if keep != "":
		for b in root.find_children("*", "StaticBody3D", true, false):
			if not String(b.name).begins_with(keep):        # the other variants' collision goes with them
				b.queue_free()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if keep != "" and not nm.begins_with(keep) and not nm.contains("-colonly"):
			mi.queue_free()
			continue
		var parts := nm.split("__")
		if parts.size() >= 2:
			var set_name := parts[parts.size() - 1].get_slice(".", 0).get_slice("_", 0)
			if set_name in ["stone", "ashlar", "timber", "iron"]:
				mi.material_override = mat(set_name)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(opts.get("shadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				meshes.append(mi)
	if opts.has("range_end"):
		for mi in meshes:
			mi.visibility_range_end = float(opts.range_end)
			mi.visibility_range_end_margin = float(opts.range_end) * 0.1
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if opts.has("spin"):
		var sp := String(opts.spin)
		var wheel_nodes: Array[Node3D] = []
		for mi in meshes:
			if String(mi.name).begins_with(sp):
				wheel_nodes.append(mi)
		if not wheel_nodes.is_empty():
			var w: Node = WheelSpin.new()
			w.name = "WheelSpin"
			w.set("targets", wheel_nodes)
			w.set("rate", float(opts.get("spin_rate", 0.5)))
			root.add_child(w)
	return root

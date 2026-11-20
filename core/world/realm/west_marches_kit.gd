extends RefCounted
## West Marches: placing the in-house landmark models (tools/blender/r37_west.py) in the world.
## Each glb is a set of mesh nodes named `<part>__<set>` (set = stone / ashlar / timber / iron / wax), a
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


## The tiling PBR material of a set ("stone", "ashlar", "hewn", "timber", "iron", "wax", "cloth", "thatch", "daub", "slate").
## "hewn" is the dressed grain of modelled masonry (each stone geometry): a gentler normal, as the beacons use it.
static func mat(set_name: String) -> StandardMaterial3D:
	if _mats.has(set_name):
		return _mats[set_name]
	if set_name != "stone" and not ResourceLoader.exists(T + "r37_%s_albedo.png" % set_name):
		return mat("stone")                   # a prop's set with no tiling textures of its own (a water plane): stone
	var m := StandardMaterial3D.new()
	var base := T + "r37_%s_" % set_name
	m.albedo_texture = load(base + "albedo.png")
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.png")
	if set_name == "hewn":
		m.normal_scale = 0.45
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
		m.metallic = 0.4          # (1.0: a metal has nothing to reflect in the night, so every modelled hoop, hinge and post drew black: the polish pass, 20 Nov)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[set_name] = m
	return m


## The same set at prop size: a finer tile (uv 3x) and a gentler normal (0.35), so a barrel's staves read as planks, not crust.
static func prop_mat(set_name: String) -> StandardMaterial3D:
	var key := "prop_" + set_name
	if _mats.has(key):
		return _mats[key]
	var base := mat(set_name)
	var m := base.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(3, 3, 3)
	m.normal_scale = base.normal_scale * 0.35
	_sky_fill(m, set_name, 0.07)
	_mats[key] = m
	return m


## A modelled prop dressed at building density (Hearthward's gate, forge, shrine, market: PropModels.big): the building set
## with the sky-bounce fill below, cached apart from the buildings' own mat().
static func lit_mat(set_name: String) -> StandardMaterial3D:
	var key := "lit_" + set_name
	if _mats.has(key):
		return _mats[key]
	var m := mat(set_name).duplicate() as StandardMaterial3D
	_sky_fill(m, set_name, 0.2)
	_mats[key] = m
	return m


## Timber and slate props (the village gate's underside, the forge's posts and lean-to, hitching rails) crushed to
## black on their shaded faces under the moon (ambient is 0.125, and a lifted albedo multiplies almost nothing there): a
## cool sky-bounce fill that follows the texture's own detail, on prop sets only (the buildings' mat() and the global
## ambient stay as they were).
static func _sky_fill(m: StandardMaterial3D, set_name: String, energy: float) -> void:
	if set_name != "timber" and set_name != "slate":
		return
	m.emission_enabled = true
	m.emission = Color(0.3, 0.21, 0.15)
	m.emission_energy_multiplier = energy
	m.emission_texture = m.albedo_texture


static func scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		_scenes[file] = load(M + file) as PackedScene
	return _scenes[file]


## Instance `file` under `parent` at `xf` (world), dressed. `opts`: pick (a child node name to keep, the
## rest dropped: palisade / trebuchet variants), shadow (bool, default true), range_end (visibility range
## for the visual meshes, fades), shift (local offset of the picked variant in the file), spin (name prefix of the node that turns: the wheel), spin_rate (rad/s),
## scale (Vector3, about the model's origin: the scale pilot's bigger mill and wider bridge; the colliders are rebuilt at that size).
static func place(parent: Node3D, file: String, xf: Transform3D, opts := {}) -> Node3D:
	var ps := scene(file)
	if ps == null:
		push_warning("r37_west_kit: no %s" % file)
		return null
	var root := ps.instantiate() as Node3D
	parent.add_child(root)
	root.global_transform = xf
	var sc: Vector3 = opts.get("scale", Vector3.ONE)
	if not sc.is_equal_approx(Vector3.ONE):
		root.global_transform = Transform3D(xf.basis * Basis.from_scale(sc), xf.origin)
		_bake_bodies(root, xf)
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
			if set_name in ["stone", "ashlar", "hewn", "timber", "iron", "wax", "cloth", "thatch", "daub", "slate"]:
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


## A scaled model's colliders, rebuilt at the scaled size in unscaled bodies (a physics body is never left scaled:
## a trimesh under a stretched body is the engine's guess, and a walk surface must be where it is drawn).
static func _bake_bodies(root: Node3D, unscaled: Transform3D) -> void:
	for n in root.find_children("*", "StaticBody3D", true, false):
		var body := n as StaticBody3D
		var shapes: Array = []
		for c in body.get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is ConcavePolygonShape3D):
				continue
			var src := cs.shape as ConcavePolygonShape3D
			var gx := cs.global_transform
			var faces := src.get_faces()
			var flip := gx.basis.determinant() < 0.0
			for i in faces.size():
				faces[i] = unscaled.affine_inverse() * (gx * faces[i])
			if flip:
				for i in range(0, faces.size() - 2, 3):
					var t := faces[i + 1]
					faces[i + 1] = faces[i + 2]
					faces[i + 2] = t
			var sh := ConcavePolygonShape3D.new()
			sh.backface_collision = src.backface_collision
			sh.set_faces(faces)
			shapes.append([cs, sh])
		body.global_transform = unscaled
		for pair: Array in shapes:
			(pair[0] as CollisionShape3D).shape = pair[1]
			(pair[0] as CollisionShape3D).transform = Transform3D.IDENTITY


extends RefCounted
## The light inside the Grandmother Oak's hollow, so the floor, the tendrils and the wall pockets read at night
## without a lamp: glowcap fungus on the rotted floor and the roots, two faint cold fills, a few drifting motes
## and a thin moon-shaft down the open crown. All of it dim (under the bloom threshold) and none of it a fire.
## No class_name: const OakHollowGlow := preload("res://core/world/realm/oak_hollow_glow.gd").

const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const SWAY0 := Vector3(0.506, 0.0, 0.499)       ## the trunk's axis at the ground (the model's sway at y 0)


## `xf` is the oak's transform (local y 0 = the floor). Adds the glow to `host`.
static func build(host: Node3D, xf: Transform3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	var d: Dictionary = TreeGen.kind("glowcap_0")
	var spots: Array[Transform3D] = []
	for k in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 2.8 + 0.5
		var s := rng.randf_range(1.2, 2.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		spots.append(Transform3D(b, xf * (SWAY0 + Vector3(sin(a) * r, -0.12, cos(a) * r))))
	# and in the pockets of the wall low down, between the stair's turns
	for k in 8:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.5, 3.0)
		var r := 4.5 - y * 0.02
		var s := rng.randf_range(1.0, 1.8)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		spots.append(Transform3D(b, xf * (SWAY0 + Vector3(sin(a) * r, y, cos(a) * r))))
	for key: String in ["solid", "cards"]:
		var mesh: Mesh = d.get(key)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = spots.size()
		for i in spots.size():
			mm.set_instance_transform(i, spots[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "HollowGlowcaps_" + key
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 70.0
		mmi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mmi)
	var centre: Vector3 = xf * (SWAY0 + Vector3(0.0, 0.7, 0.0))
	_light(host, OmniLight3D.new(), centre + Vector3(0.6, 0.0, -0.8), Color(0.45, 0.85, 0.7), 0.7, 6.5)
	_light(host, OmniLight3D.new(), xf * (SWAY0 + Vector3(-1.5, 4.0, 1.0)), Color(0.4, 0.55, 0.9), 0.45, 8.0)
	var shaft := SpotLight3D.new()
	shaft.spot_angle = 11.0
	shaft.spot_range = 44.0
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_light(host, shaft, xf * (SWAY0 + Vector3(0.0, 38.0, 0.0)), Color(0.5, 0.62, 0.95), 0.9, 44.0)
	_motes(host, xf * (SWAY0 + Vector3(0.0, 3.0, 0.0)))


static func _light(host: Node3D, l: Light3D, at: Vector3, col: Color, e: float, r: float) -> void:
	l.name = "HollowLight"
	l.light_color = col
	l.light_energy = e
	if l is OmniLight3D:
		(l as OmniLight3D).omni_range = r
	l.shadow_enabled = false
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	host.add_child(l)
	l.global_position = at
	LightPolicy.apply_fade(l)
	l.light_volumetric_fog_energy = 0.0
	LightPolicy.apply_illumination(l)
	l.shadow_enabled = false


## A few pale motes turning slowly in the hollow's air.
static func _motes(host: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "HollowMotes"
	p.amount = 18
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.2, 3.0, 3.2)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.12
	p.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.55, 0.9, 0.75, 0.55)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	m.disable_fog = true
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 60.0
	host.add_child(p)
	p.global_position = at

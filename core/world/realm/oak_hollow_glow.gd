extends RefCounted
## The light inside the Grandmother Oak's hollow, so the floor, the roots and the wall pockets read at night
## without a lamp: small clusters of glowing mushrooms along the floor's edge and in a few pockets of the wall
## (each with a tiny cyan-green light), two faint cold fills, a few drifting motes and a thin moon-shaft down the
## open crown. All of it dim and none of it a fire.
## No class_name: const OakHollowGlow := preload("res://core/world/realm/oak_hollow_glow.gd").

const SWAY0 := Vector3(0.506, 0.0, 0.499)       ## the trunk's axis at the ground (the model's sway at y 0)
const CAP_GLOW := Color(0.3, 0.95, 0.78)


## `xf` is the oak's transform (local y 0 = the floor). Adds the glow to `host`.
static func build(host: Node3D, xf: Transform3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	var meshes: Array[Mesh] = [_cluster(1), _cluster(2), _cluster(3)]
	var spots: Array[Array] = []                  # [mesh index, transform]
	for k in 9:                                    # along the floor's edge, between the roots
		var a := TAU * (float(k) + rng.randf_range(-0.25, 0.25)) / 9.0
		var r := rng.randf_range(3.5, 4.3)
		var s := rng.randf_range(1.0, 1.5)
		spots.append([k % 3, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), xf * (SWAY0 + Vector3(sin(a) * r, -0.1, cos(a) * r)))])
	for k in 4:                                    # in pockets of the wall, low down
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.4, 1.6)
		var s := rng.randf_range(0.9, 1.3)
		# a cluster on the wall: its stems grow out of the wall, so it is turned to lie against it
		var out := Vector3(sin(a), 0.0, cos(a))
		var b := Basis.looking_at(-out, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		spots.append([k % 3, Transform3D(b.scaled(Vector3(s, s, s)), xf * (SWAY0 + out * 4.75 + Vector3(0, y, 0)))])
	for mi in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[mi]
		var mine: Array[Transform3D] = []
		for sp: Array in spots:
			if int(sp[0]) == mi:
				mine.append(sp[1])
		mm.instance_count = mine.size()
		for i in mine.size():
			mm.set_instance_transform(i, mine[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "HollowShrooms%d" % mi
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 70.0
		mmi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mmi)
		mmi.global_transform = Transform3D.IDENTITY          # the spots are world transforms
	for k in mini(6, spots.size()):                # a tiny light for six of them
		var at: Vector3 = (spots[k * 2][1] as Transform3D).origin + Vector3(0, 0.3, 0)
		_light(host, OmniLight3D.new(), at, CAP_GLOW, 0.32, 2.6)
	var centre: Vector3 = xf * (SWAY0 + Vector3(0.0, 0.7, 0.0))
	_light(host, OmniLight3D.new(), centre + Vector3(0.6, 0.6, -0.8), Color(0.5, 0.9, 0.75), 1.0, 7.5)
	_light(host, OmniLight3D.new(), xf * (SWAY0 + Vector3(-1.5, 4.0, 1.0)), Color(0.4, 0.55, 0.9), 0.4, 8.0)
	var shaft := SpotLight3D.new()
	shaft.spot_angle = 11.0
	shaft.spot_range = 44.0
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_light(host, shaft, xf * (SWAY0 + Vector3(0.0, 38.0, 0.0)), Color(0.5, 0.62, 0.95), 0.9, 44.0)
	_motes(host, xf * (SWAY0 + Vector3(0.0, 3.0, 0.0)))


## A cluster of 5 to 8 little glowing caps on thin stems, one mesh (a dark stem, a softly emissive cap).
static func _cluster(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131
	var stem_m := StandardMaterial3D.new()
	stem_m.albedo_color = Color(0.55, 0.62, 0.55)
	stem_m.roughness = 0.9
	var cap_m := StandardMaterial3D.new()
	cap_m.albedo_color = Color(0.1, 0.32, 0.26)
	cap_m.emission_enabled = true
	cap_m.emission = CAP_GLOW
	cap_m.emission_energy_multiplier = 0.65
	cap_m.roughness = 0.6
	var out := ArrayMesh.new()
	for pass_n in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(stem_m if pass_n == 0 else cap_m)
		for k in rng.randi_range(5, 8):
			var h := rng.randf_range(0.1, 0.3)
			var r := rng.randf_range(0.05, 0.11)
			var at := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
			var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
			if pass_n == 0:
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.012
				cyl.bottom_radius = 0.02
				cyl.height = h
				cyl.radial_segments = 5
				cyl.rings = 1
				st.append_from(cyl, 0, Transform3D(lean, at + lean * Vector3(0, h * 0.5, 0)))
			else:
				var cap := SphereMesh.new()
				cap.radius = r
				cap.height = r * 1.1
				cap.is_hemisphere = true
				cap.radial_segments = 8
				cap.rings = 3
				st.append_from(cap, 0, Transform3D(lean, at + lean * Vector3(0, h, 0)))
		st.generate_normals()
		st.commit(out)
	return out


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

extends RefCounted
## The light inside the Grandmother Oak's hollow, so the floor, the roots and the wall read at night without a
## lamp: little domed mushrooms rooted in the floor's soil, shelf-fungus brackets on the wall above the stair (each
## with a tiny cyan-green light), a faint cold fill, a few drifting motes and a thin moon-shaft down the open
## crown. All of it dim and none of it a fire.
## No class_name: const OakHollowGlow := preload("res://core/world/realm/oak_hollow_glow.gd").

const CAP_GLOW := Color(0.3, 0.95, 0.78)
const A0 := PI + 0.55                    ## the stair's first tread (r37_south_oak.py)
const TURN := 26.0
const RISE := 0.21
const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 glow : source_color = vec3(0.3, 0.95, 0.78);
uniform float energy = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.05, 0.14, 0.12);
	ROUGHNESS = 0.7;
	EMISSION = glow * (0.18 + rim * 1.3) * energy;
}
"""


static func _sway(y: float) -> Vector3:
	return Vector3(1.3 * sin(y * 0.11 + 0.4) + 0.02 * y, 0.0, 1.1 * cos(y * 0.09 + 1.1))


static func _r_in(y: float) -> float:
	var ro := 6.2 - 1.0 * (y / 5.0) if y < 5.0 else 5.2 - 0.7 * ((y - 5.0) / 33.0)
	return ro - (1.25 + 0.15 * sin(y * 0.35))


## `xf` is the oak's transform (local y 0 = the floor). Adds the glow to `host`.
static func build(host: Node3D, xf: Transform3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7117
	var floor_m := _clump(1, false)
	var shelf_m := _clump(2, true)
	var floor_tf: Array[Transform3D] = []
	var shelf_tf: Array[Transform3D] = []
	for k in 6:                                    # in the soil of the floor, clear of the stair's first turn
		var a := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / 6.0 + 0.3
		var r := rng.randf_range(1.2, 2.6)
		var s := rng.randf_range(1.1, 1.6)
		floor_tf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), xf * (_sway(0.0) + Vector3(sin(a) * r, -0.12, cos(a) * r))))
	for k in 5:                                    # shelf fungus on the wall, above head height over the stair
		var a := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / 5.0 + 0.9
		var turn_frac := fposmod((a - A0) / TAU, 1.0)
		var y := 0.14 + RISE * TURN * turn_frac + rng.randf_range(2.1, 2.7) + (0.0 if k % 2 == 0 else RISE * TURN)
		var out := Vector3(sin(a), 0.0, cos(a))
		var wall := _sway(y) + out * (_r_in(y) - 0.02) + Vector3(0, y, 0)
		var s := rng.randf_range(0.9, 1.3)
		# the shelf's flat side to the wall: its dome (local +y) points out from the wall
		var up_to_out := Basis(Quaternion(Vector3.UP, out))
		shelf_tf.append(Transform3D(up_to_out.scaled(Vector3(s, s, s)), xf * wall))
	_instances(host, floor_m, floor_tf, "HollowShrooms")
	_instances(host, shelf_m, shelf_tf, "HollowShelves")
	var lit: Array[Transform3D] = []
	lit.append_array(floor_tf.slice(0, 3))
	lit.append_array(shelf_tf.slice(0, 2))
	for t: Transform3D in lit:
		_light(host, OmniLight3D.new(), t.origin + t.basis.y * 0.3 + Vector3(0, 0.2, 0), CAP_GLOW, 0.5, 3.6)
	var centre: Vector3 = xf * (_sway(0.0) + Vector3(0.0, 0.7, 0.0))
	_light(host, OmniLight3D.new(), centre + Vector3(0.6, 0.6, -0.8), Color(0.5, 0.9, 0.75), 1.7, 8.5)
	_light(host, OmniLight3D.new(), xf * (_sway(4.0) + Vector3(-1.5, 4.0, 1.0)), Color(0.4, 0.55, 0.9), 0.8, 9.0)
	var shaft := SpotLight3D.new()
	shaft.spot_angle = 11.0
	shaft.spot_range = 44.0
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_light(host, shaft, xf * (_sway(38.0) + Vector3(0.0, 38.0, 0.0)), Color(0.5, 0.62, 0.95), 0.9, 44.0)
	_motes(host, xf * (_sway(3.0) + Vector3(0.0, 3.0, 0.0)))


static func _instances(host: Node3D, mesh: Mesh, tfs: Array[Transform3D], nm: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 70.0
	mmi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY          # the instances are world transforms


## A clump of little domed caps (a hemisphere over a dark gilled underside), on stems from the soil (floor) or
## stacked as brackets on a stem-less shelf (wall). One mesh, three surfaces: stems, caps (a soft rim glow), gills.
static func _clump(seed: int, shelf: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131
	var stem_m := StandardMaterial3D.new()
	stem_m.albedo_color = Color(0.5, 0.58, 0.52)
	stem_m.roughness = 0.9
	var cap_m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	cap_m.shader = sh
	cap_m.set_shader_parameter("glow", CAP_GLOW)
	cap_m.set_shader_parameter("energy", 0.9)
	var gill_m := StandardMaterial3D.new()
	gill_m.albedo_color = Color(0.03, 0.05, 0.045)
	gill_m.roughness = 1.0
	gill_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var out := ArrayMesh.new()
	var sts: Array[SurfaceTool] = []
	for m: Material in [stem_m, cap_m, gill_m]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(m)
		sts.append(st)
	for k in rng.randi_range(5, 7):
		var h := 0.0 if shelf else rng.randf_range(0.12, 0.3)
		var r := rng.randf_range(0.07, 0.13) * (1.5 if shelf else 1.0)
		var at := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
		if shelf:
			at.y = rng.randf_range(0.0, 0.1) * 0.0
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)) * Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2))
		var top := at + lean * Vector3(0, h, 0)
		if not shelf:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.012
			cyl.bottom_radius = 0.022
			cyl.height = h + 0.1
			cyl.radial_segments = 5
			cyl.rings = 1
			sts[0].append_from(cyl, 0, Transform3D(lean, at + lean * Vector3(0, h * 0.5 - 0.04, 0)))
		var cap := SphereMesh.new()
		cap.radius = r
		cap.height = r * (0.7 if shelf else 1.0)
		cap.is_hemisphere = true
		cap.radial_segments = 10
		cap.rings = 4
		sts[1].append_from(cap, 0, Transform3D(lean, top))
		var gill := CylinderMesh.new()
		gill.top_radius = r * 0.98
		gill.bottom_radius = r * 0.98
		gill.height = 0.004
		gill.radial_segments = 10
		gill.rings = 1
		sts[2].append_from(gill, 0, Transform3D(lean, top))
	for st in sts:
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

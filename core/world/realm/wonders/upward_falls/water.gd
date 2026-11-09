extends RefCounted
## The Upward Falls' water, as the eye has it: the strip of river climbing the glacis, the basin it fills, the
## sheet that stands up out of the basin (three crossed planes, one of them turning to face the camera), the
## rings and foam where it comes down on the river, the spray going up and the fine rain coming back, and the
## two cold lights. All of it is shader and GPU particles: nothing here runs per frame.

const RISE := preload("res://core/world/realm/wonders/upward_falls/rise.gdshader")
const FLOW := preload("res://core/world/realm/wonders/upward_falls/flow.gdshader")
const POOL := preload("res://core/world/realm/wonders/upward_falls/pool.gdshader")

const HEIGHT := 90.0                         ## the sheet's height over the basin
const LEAN := Vector3(7.0, 0.0, 20.0)        ## where its top has drifted to (the spray is carried south, over the pool)
const COLD := Color(0.52, 0.76, 1.0)

static var _soft: Texture2D = null


static func _mat(sh: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## A flat ribbon along `pts` (widths[i] across at each), UV.x 0..1 across and UV.y the metres along.
static func strip(pts: Array, widths: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var run := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		var d: Vector3 = (pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		var side := Vector3(d.z, 0.0, -d.x).normalized()
		if side == Vector3.ZERO:
			side = Vector3.RIGHT
		if i > 0:
			run += p.distance_to(pts[i - 1])
		var hw: float = float(widths[i]) * 0.5
		verts.append(p - side * hw)
		verts.append(p + side * hw)
		uvs.append(Vector2(0.0, run))
		uvs.append(Vector2(1.0, run))
		nrm.append(Vector3.UP)
		nrm.append(Vector3.UP)
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _column_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := 34
	for i in n + 1:
		var h := HEIGHT * pow(float(i) / float(n), 1.35)
		verts.append(Vector3(-1.0, h, 0.0))
		verts.append(Vector3(1.0, h, 0.0))
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _no_shadow(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(Groups.CULL_SKIP)


## The river climbing the glacis and crossing the roof to the basin (`pts` from the foot up), and the basin's disc.
static func channel(host: Node3D, pts: Array, widths: Array, basin: Vector3, basin_r: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Climb"
	mi.mesh = strip(pts, widths)
	mi.material_override = _mat(FLOW, {"disc": 0.0, "period": 1.95})
	mi.extra_cull_margin = 6.0
	_no_shadow(mi)
	host.add_child(mi)
	var disc := MeshInstance3D.new()
	disc.name = "Basin"
	var pm := PlaneMesh.new()
	pm.size = Vector2(basin_r * 2.0, basin_r * 2.0)
	disc.mesh = pm
	disc.material_override = _mat(FLOW, {"disc": 1.0})
	_no_shadow(disc)
	host.add_child(disc)
	disc.position = basin


## The rising sheet from `base` (the basin's middle): the camera-facing one and two fixed fins.
static func column(host: Node3D, base: Vector3) -> void:
	var mesh := _column_mesh()
	var holder := Node3D.new()
	holder.name = "RisingWater"
	host.add_child(holder)
	holder.position = base
	var specs := [[1.0, 1.6, 0.0, 1.0, 0.0], [0.0, 1.2, 0.0, 0.55, 0.61], [0.0, 1.1, 1.0, 0.5, -0.92]]
	for i in specs.size():
		var s: Array = specs[i]
		var mi := MeshInstance3D.new()
		mi.name = "Sheet%d" % i
		mi.mesh = mesh
		mi.material_override = _mat(RISE, {"billboard": s[0], "base_w": s[1], "seed": s[2], "strength": s[3], "height": HEIGHT, "lean": LEAN, "speed": 7.0 + float(i) * 0.7})
		mi.rotation.y = float(s[4])
		mi.custom_aabb = AABB(Vector3(-14.0, -2.0, -8.0), Vector3(42.0, HEIGHT + 6.0, 40.0))
		_no_shadow(mi)
		holder.add_child(mi)


## Rain rings and foam laid over the river below the weir.
static func pool(host: Node3D, at: Vector3, size: Vector2, rain_c: Vector2, wall_z: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "RainPool"
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = _mat(POOL, {"centre": rain_c, "wall_z": wall_z, "reach": 9.0})
	_no_shadow(mi)
	host.add_child(mi)
	mi.position = at


# --- particles ----------------------------------------------------------------------------------------

static func _soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func _pmat(col: Color, soft: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 4.5
	if soft:
		m.albedo_texture = _soft_tex()
	return m


static func _ramp(a: float, peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak * a), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _emitter(nm: String, parent: Node3D, at: Vector3, amount: int, life: float, pm: ParticleProcessMaterial, mesh: Mesh, aabb: AABB, range_end := 0.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.explosiveness = 0.0
	p.local_coords = false
	p.visibility_aabb = aabb
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		p.visibility_range_end = range_end
		p.visibility_range_end_margin = range_end * 0.1
		p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	return p


static func _quad(size: Vector2, col: Color, soft := true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = _pmat(col, soft)
	return q


static func particles(host: Node3D, basin: Vector3, rain_c: Vector3, pool_c: Vector3) -> void:
	# drops flung up out of the basin and carried on up the column
	var up := ParticleProcessMaterial.new()
	up.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	up.emission_sphere_radius = 1.5
	up.direction = Vector3.UP
	up.spread = 9.0
	up.initial_velocity_min = 6.0
	up.initial_velocity_max = 19.0
	up.gravity = Vector3(0.5, 3.4, 1.5)
	up.scale_min = 0.5
	up.scale_max = 1.5
	up.color_ramp = _ramp(0.7, 0.9)
	_emitter("Spray", host, basin, 240, 3.6, up, _quad(Vector2(0.17, 0.17), Color(0.8, 0.94, 1.0, 1.0)), AABB(Vector3(-12, -4, -10), Vector3(44, 92, 50)), 260.0)
	# the churn on the basin itself
	var jet := ParticleProcessMaterial.new()
	jet.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	jet.emission_ring_axis = Vector3.UP
	jet.emission_ring_radius = 1.4
	jet.emission_ring_inner_radius = 0.2
	jet.emission_ring_height = 0.05
	jet.direction = Vector3.UP
	jet.spread = 28.0
	jet.initial_velocity_min = 2.0
	jet.initial_velocity_max = 5.5
	jet.gravity = Vector3(0, -6.0, 0)
	jet.scale_min = 0.5
	jet.scale_max = 1.2
	jet.color_ramp = _ramp(0.6, 1.0)
	_emitter("BasinSpray", host, basin + Vector3.UP * 0.3, 110, 1.3, jet, _quad(Vector2(0.14, 0.14), Color(0.85, 0.96, 1.0, 1.0)), AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12)), 120.0)
	# the fine rain that comes back, as streaks
	var rain := ParticleProcessMaterial.new()
	rain.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(10.0, 0.5, 8.0)
	rain.direction = Vector3.DOWN
	rain.spread = 0.0
	rain.initial_velocity_min = 0.0
	rain.initial_velocity_max = 2.0
	rain.gravity = Vector3(0.5, -9.8, 1.0)
	rain.particle_flag_align_y = true
	rain.color_ramp = _ramp(0.9, 0.55)
	_emitter("Rain", host, rain_c, 560, 3.0, rain, _quad(Vector2(0.022, 0.85), Color(0.7, 0.88, 1.0, 1.0), false), AABB(Vector3(-14, -48, -12), Vector3(30, 52, 26)), 150.0)
	# mist lying on the pool
	var mist := ParticleProcessMaterial.new()
	mist.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(5.5, 0.3, 6.0)
	mist.direction = Vector3.UP
	mist.spread = 40.0
	mist.initial_velocity_min = 0.2
	mist.initial_velocity_max = 0.8
	mist.gravity = Vector3(0.1, 0.05, 0.25)
	mist.scale_min = 0.8
	mist.scale_max = 1.8
	mist.color_ramp = _ramp(0.8, 0.045)
	_emitter("Mist", host, pool_c, 46, 7.0, mist, _quad(Vector2(3.6, 3.6), Color(0.6, 0.78, 0.95, 1.0)), AABB(Vector3(-10, -2, -10), Vector3(20, 10, 20)), 170.0)


static func lights(host: Node3D, deck: Vector3, pool_c: Vector3) -> void:
	for spec: Array in [[deck + Vector3(0.0, 4.5, 1.2), 3.4, 30.0], [pool_c + Vector3(0.0, 3.0, 0.0), 3.2, 19.0]]:
		var l := OmniLight3D.new()
		l.name = "CoolLight"
		l.light_color = COLD
		l.light_energy = float(spec[1])
		l.omni_range = float(spec[2])
		l.omni_attenuation = 1.0
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.4
		l.distance_fade_enabled = true
		l.distance_fade_begin = 110.0
		l.distance_fade_length = 25.0
		l.set_meta(&"light_class", &"fill")
		host.add_child(l)
		l.global_position = spec[0]

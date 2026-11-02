class_name Vfx
extends RefCounted
## One-shot combat effects shared by skills, enemies and movement: particle bursts (optionally
## with ribbon trails), persistent emitters, ground shockwave rings, flash lights, ribbon streaks,
## jagged arcs and scorch decals. All GPU resources are built once and cached by preset, so a
## burst costs one node; nodes free themselves when done.
##
## Colours are HDR on purpose (> 1 blooms under the tight glow budget: threshold 1.15).

const RING_SHADER := preload("res://world/vfx/ring_wave.gdshader")

static var _dot: GradientTexture2D
static var _scorch_tex: GradientTexture2D
static var _draw_mats := {}
static var _procs := {}
static var _quads := {}
static var _trail_meshes := {}
static var _ring_mats := {}
static var _ring_mesh: PlaneMesh
static var _fade: GradientTexture1D


static func host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null


# --- particles ------------------------------------------------------------------------------

## opts: count, life, speed (Vector2 min/max), size, gravity (float, +up), spread (deg),
##       dir (Vector3), radius (emission sphere), ring (emission ring radius), damping,
##       additive (bool), trail (seconds, 0 = none), radial (radial accel), scale_var.
static func burst(at: Vector3, color: Color, opts := {}) -> GPUParticles3D:
	var h := host()
	if h == null:
		return null
	var p := _make(color, opts, true)
	h.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Same presets, but looping and owned by the caller (charge swirl, slide dust, ward embers).
static func emitter(color: Color, opts := {}) -> GPUParticles3D:
	var p := _make(color, opts, false)
	p.emitting = false
	return p


static func _make(color: Color, opts: Dictionary, one_shot: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(opts.get("count", 32))
	p.lifetime = float(opts.get("life", 0.5))
	p.one_shot = one_shot
	p.explosiveness = float(opts.get("explosive", 0.95 if one_shot else 0.0))
	p.local_coords = bool(opts.get("local", false))
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _proc(color, opts)
	var additive := bool(opts.get("additive", true))
	var trail := float(opts.get("trail", 0.0))
	if trail > 0.0:
		p.trail_enabled = true
		p.trail_lifetime = trail
		p.draw_pass_1 = _trail_mesh(float(opts.get("size", 0.06)), additive)
	else:
		p.draw_pass_1 = _quad(float(opts.get("size", 0.1)), additive)
	return p


static func _proc(color: Color, opts: Dictionary) -> ParticleProcessMaterial:
	var key := "%s|%s" % [color, opts]
	if _procs.has(key):
		return _procs[key]
	var pm := ParticleProcessMaterial.new()
	if opts.has("ring"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_radius = float(opts.ring)
		pm.emission_ring_inner_radius = float(opts.ring) * 0.85
		pm.emission_ring_height = 0.05
		pm.emission_ring_axis = Vector3.UP
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(opts.get("radius", 0.1))
	pm.direction = opts.get("dir", Vector3.UP)
	pm.spread = float(opts.get("spread", 180.0))
	var spd: Vector2 = opts.get("speed", Vector2(1.5, 4.0))
	pm.initial_velocity_min = spd.x
	pm.initial_velocity_max = spd.y
	pm.gravity = Vector3(0.0, float(opts.get("gravity", -2.0)), 0.0)
	pm.damping_min = float(opts.get("damping", 1.5))
	pm.damping_max = float(opts.get("damping", 1.5)) * 1.6
	pm.radial_accel_min = float(opts.get("radial", 0.0))
	pm.radial_accel_max = float(opts.get("radial", 0.0))
	pm.tangential_accel_min = float(opts.get("swirl", 0.0))
	pm.tangential_accel_max = float(opts.get("swirl", 0.0)) * 1.4
	pm.scale_min = 1.0 - float(opts.get("scale_var", 0.45))
	pm.scale_max = 1.0 + float(opts.get("scale_var", 0.45))
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, float(opts.get("grow", 1.0))))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = color
	pm.color_ramp = _fade_ramp()
	if bool(opts.get("turbulence", false)):
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.4
		pm.turbulence_noise_scale = 3.0
	_procs[key] = pm
	return pm


static func _fade_ramp() -> GradientTexture1D:
	if _fade == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.6, 1.5, 1.6, 1.0))
		g.add_point(0.25, Color(1, 1, 1, 0.95))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
		_fade = GradientTexture1D.new()
		_fade.gradient = g
	return _fade


static var _scorch_glow_tex: GradientTexture2D


static func _scorch_glow() -> GradientTexture2D:
	if _scorch_glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 0.95])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
		_scorch_glow_tex = GradientTexture2D.new()
		_scorch_glow_tex.gradient = g
		_scorch_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_glow_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_glow_tex.fill_to = Vector2(0.5, 0.0)
		_scorch_glow_tex.width = 64
		_scorch_glow_tex.height = 64
	return _scorch_glow_tex


static func dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.6))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 64
		_dot.height = 64
	return _dot


static func _draw_mat(additive: bool, trails: bool) -> StandardMaterial3D:
	var key := "%s%s" % [additive, trails]
	if _draw_mats.has(key):
		return _draw_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if trails:
		m.use_particle_trails = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = dot()
	_draw_mats[key] = m
	return m


static func _quad(size: float, additive: bool) -> QuadMesh:
	var key := "%s%s" % [size, additive]
	if _quads.has(key):
		return _quads[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _draw_mat(additive, false)
	_quads[key] = q
	return q


static func _trail_mesh(size: float, additive: bool) -> RibbonTrailMesh:
	var key := "%s%s" % [size, additive]
	if _trail_meshes.has(key):
		return _trail_meshes[key]
	var r := RibbonTrailMesh.new()
	r.shape = RibbonTrailMesh.SHAPE_CROSS
	r.size = size
	r.sections = 4
	r.section_segments = 2
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	r.curve = c
	r.material = _draw_mat(additive, true)
	_trail_meshes[key] = r
	return r


# --- rings, lights, decals ------------------------------------------------------------------

## Expanding ground (or `up`-facing) shockwave ring.
static func ring(at: Vector3, radius: float, color: Color, time := 0.45, width := 0.08, up := Vector3.UP, energy := 1.0) -> void:
	var h := host()
	if h == null:
		return
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(2.0, 2.0)
	var key := "%s|%s" % [color, width]
	if not _ring_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = RING_SHADER
		m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("width", width)
		_ring_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = _ring_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	var b := Basis.IDENTITY
	if absf(up.dot(Vector3.UP)) < 0.999:
		var x := up.cross(Vector3.UP).normalized()
		b = Basis(x, up, x.cross(up)).orthonormalized()
	mi.global_transform = Transform3D(Basis(b.x * radius, b.y, b.z * radius), at + up * 0.04)
	mi.set_instance_shader_parameter(&"energy", energy)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"progress", v), 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


static func light(at: Vector3, color: Color, energy: float, rng: float, time := 0.3) -> void:
	var h := host()
	if h == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.6
	l.set_meta("light_class", "player_orb")
	h.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Burn mark projected onto whatever is below (lance impact, nova). Glows, then cools to soot.
static func scorch(at: Vector3, radius: float, glow: Color, time := 2.5) -> void:
	var h := host()
	if h == null:
		return
	if _scorch_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.95))
		g.add_point(0.55, Color(0, 0, 0, 0.6))
		g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0))
		_scorch_tex = GradientTexture2D.new()
		_scorch_tex.gradient = g
		_scorch_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_tex.fill_to = Vector2(0.5, 0.0)
	var d := Decal.new()
	d.size = Vector3(radius * 2.0, 1.6, radius * 2.0)
	d.texture_albedo = _scorch_tex
	d.texture_emission = _scorch_glow()     # black RGB at the rim: a dot() here glowed as a square
	d.emission_energy = 2.5
	d.modulate = glow
	d.albedo_mix = 0.85
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	h.add_child(d)
	d.global_position = at
	d.rotation.y = randf() * TAU
	var tw := d.create_tween()
	tw.tween_property(d, "emission_energy", 0.0, time * 0.35)
	tw.tween_property(d, "albedo_mix", 0.0, time * 0.65)
	tw.tween_callback(d.queue_free)


# --- ribbons and arcs -----------------------------------------------------------------------

## A crossed ribbon through `pts`, tapering width0 → width1, fading out over `time`.
static func ribbon(pts: PackedVector3Array, width0: float, width1: float, color: Color, time := 0.25, additive := true) -> void:
	var h := host()
	if h == null or pts.size() < 2:
		return
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(1, 1, 1, 1)
	for plane in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
		for i in pts.size():
			var t := float(i) / float(pts.size() - 1)
			var fwd := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var side := fwd.cross(Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT).normalized()
			if plane == 1:
				side = side.cross(fwd).normalized()
			var w := lerpf(width0, width1, t) * 0.5
			var c := Color(color.r, color.g, color.b, color.a * (0.35 + 0.65 * t))
			im.surface_set_color(c)
			im.surface_add_vertex(pts[i] + side * w)
			im.surface_set_color(c)
			im.surface_add_vertex(pts[i] - side * w)
		im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Jagged lightning between two points (Nova detonating a mark).
static func arc(from: Vector3, to: Vector3, color: Color, time := 0.22, jag := 0.28) -> void:
	var pts := PackedVector3Array()
	var n := 9
	var dir := (to - from)
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up2 := side.cross(dir.normalized())
	for i in n:
		var t := float(i) / float(n - 1)
		var j := sin(t * PI) * jag
		pts.append(from + dir * t + side * randf_range(-j, j) + up2 * randf_range(-j, j))
	ribbon(pts, 0.09, 0.03, color, time)
	ribbon(pts, 0.22, 0.08, Color(color.r, color.g, color.b, 0.35), time * 0.8)

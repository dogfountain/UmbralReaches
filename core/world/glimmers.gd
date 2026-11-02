extends Node3D
## Scattered bioluminescence for both zones. Runtime so the stair scene is never rebaked.

@export var seed_n := 11
@export var half := 34.0
@export var z_min := -34.0
@export var z_max := 34.0
@export var skip_corridor := false
@export var skip_river := false
@export var skip_shards := false
@export var palettes: PackedColorArray = PackedColorArray()

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _pulses: Array[Dictionary] = []
var _floaty = preload("res://core/world/floaty.gd")
var _mush = preload("res://core/util/mushroom_mesh.gd")
var _cap_shader: Shader


func _ready() -> void:
	await get_tree().physics_frame
	_rng.seed = seed_n
	_cap_shader = load("res://world/cap.gdshader")
	var root := get_parent()
	if root != null:
		var seat = load("res://core/world/seat_props.gd")
		var seated: int = seat.seat(root)
		seat.sink_river_crystals(root)
		seat.plant_solid(root)
		print("SEAT props ", seated)
	_light_existing_caps()
	_scatter_wisps()
	_scatter_buds()
	if not skip_shards:
		_scatter_shards()
	_scatter_swarms()
	if root != null:
		load("res://core/world/seat_props.gd").seat(self)
	_fade_own_lights()
	if root != null and root.has_method("refresh_lights"):
		root.refresh_lights()


func _process(delta: float) -> void:
	_t += delta
	for p in _pulses:
		var light: OmniLight3D = p.light
		if not is_instance_valid(light):
			continue
		light.light_energy = p.base * (0.78 + 0.22 * sin(_t * p.hz + p.phase))


func _light_existing_caps() -> void:
	var root := get_parent()
	if root == null:
		return
	var placed := 0
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if placed >= 6:
			break
		var mmi := node as MultiMeshInstance3D
		var n := String(mmi.name).to_lower()
		var glow := n.begins_with("glowcap") or n.begins_with("nightcap")
		var dim := n.begins_with("cap")
		if not glow and not dim:
			continue
		if dim and _rng.randf() > 0.38:
			continue
		var mm: MultiMesh = mmi.multimesh
		if mm == null or mm.instance_count < 1:
			continue
		var idx := _rng.randi_range(0, mm.instance_count - 1)
		var xf: Transform3D = mmi.global_transform * mm.get_instance_transform(idx)
		var col := _palette(_rng.randi())
		if mm.use_colors:
			var ic := mm.get_instance_color(idx)
			if ic.a > 0.01 and ic.get_luminance() > 0.04:
				col = Color(ic.r * 1.8 + 0.2, ic.g * 1.8 + 0.15, ic.b * 1.8 + 0.1)
		_omni(xf.origin + Vector3(0.0, 0.7, 0.0), col, 1.7 if glow else 1.25, 6.2 if glow else 5.0)
		placed += 1


func _scatter_wisps() -> void:
	var n := 3
	var hits := _points(n * 3)
	var made := 0
	for p in hits:
		if made >= n:
			break
		var col := _palette(made)
		var holder := Node3D.new()
		holder.position = p + Vector3(0.0, _rng.randf_range(0.85, 2.2), 0.0)
		holder.set_script(_floaty)
		holder.set("amplitude", _rng.randf_range(0.12, 0.32))
		holder.set("period", _rng.randf_range(4.5, 9.0))
		holder.set("spin", _rng.randf_range(-0.4, 0.4))
		add_child(holder)
		var orb := SphereMesh.new()
		var r := _rng.randf_range(0.07, 0.13)
		orb.radius = r
		orb.height = r * 2.0
		orb.radial_segments = 8
		orb.rings = 5
		var core := MeshInstance3D.new()
		core.mesh = orb
		var core_mat := StandardMaterial3D.new()
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core_mat.albedo_color = Color(col.r * 1.2, col.g * 1.2, col.b * 1.2)
		core_mat.disable_receive_shadows = true
		core.material_override = core_mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.visibility_range_end = 36.0
		core.visibility_range_end_margin = 8.0
		core.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(core)
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		var hs := r * 7.0
		q.size = Vector2(hs, hs)
		halo.mesh = q
		var hmat := StandardMaterial3D.new()
		hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hmat.disable_receive_shadows = true
		hmat.albedo_color = Color(col.r, col.g, col.b)
		hmat.albedo_texture = _radial()
		halo.material_override = hmat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.visibility_range_end = 36.0
		halo.visibility_range_end_margin = 8.0
		halo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(halo)
		_omni(Vector3.ZERO, col, _rng.randf_range(1.15, 1.85), _rng.randf_range(4.8, 7.0), holder)
		made += 1


func _scatter_buds() -> void:
	var hits := _points(4)
	if hits.is_empty():
		return
	var mesh: ArrayMesh = _mush.build(0, 1.2, 0, Color("#2BD99A"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = hits.size()
	var box := AABB(hits[0], Vector3.ZERO)
	for i in hits.size():
		var p: Vector3 = hits[i]
		var sc := _rng.randf_range(0.7, 1.35)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc), p)
		mm.set_instance_transform(i, xf)
		var col := _palette(i)
		mm.set_instance_color(i, Color(clampf(col.r * 0.22, 0.1, 0.82), clampf(col.g * 0.22, 0.08, 0.7), clampf(col.b * 0.22, 0.08, 0.8)))
		mm.set_instance_custom_data(i, Color(col.r, col.g, col.b, 2.8))
		box = box.expand(p)
		if i % 4 == 0:
			_omni(p + Vector3(0.0, 0.85, 0.0), col, 1.35, 5.5)
	mm.custom_aabb = box.grow(3.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GlowBuds"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = _cap_shader
	mat.set_shader_parameter("glow", 2.6)
	mat.set_shader_parameter("stem_color", Color(0.55, 0.72, 0.62))
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 32.0
	mmi.visibility_range_end_margin = 6.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)


func _scatter_shards() -> void:
	var hits := _points(18)
	if hits.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in hits.size():
		var p: Vector3 = hits[i]
		var s := _rng.randf_range(0.18, 0.38)
		_octa(st, p + Vector3(0.0, s * 0.85, 0.0), s, _palette(i))
		if i % 2 == 0:
			_omni(p + Vector3(0.0, 0.85, 0.0), _palette(i), 1.4, 5.2)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "GlowShards"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.2, 0.45)
	mat.emission_enabled = true
	mat.emission = _palette(0)
	mat.emission_energy_multiplier = 2.8
	mat.roughness = 0.18
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 28.0
	mi.visibility_range_end_margin = 6.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)


func _scatter_swarms() -> void:
	var hits := _points(1)
	for i in hits.size():
		var p: Vector3 = hits[i]
		var gp := GPUParticles3D.new()
		gp.name = "Fireflies%d" % i
		gp.position = p + Vector3(0.0, 1.4, 0.0)
		gp.amount = 12
		gp.lifetime = 7.0
		gp.preprocess = 4.0
		gp.visibility_aabb = AABB(Vector3(-7, -2, -7), Vector3(14, 8, 14))
		gp.visibility_range_end = 28.0
		gp.visibility_range_end_margin = 8.0
		gp.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(4.5, 1.8, 4.5)
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 0.04
		pm.initial_velocity_max = 0.22
		pm.gravity = Vector3(0.0, 0.03, 0.0)
		pm.scale_min = 0.45
		pm.scale_max = 1.2
		pm.turbulence_enabled = false
		gp.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 0.16)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.disable_receive_shadows = true
		mat.albedo_color = _palette(i)
		mat.albedo_texture = _radial()
		q.material = mat
		gp.draw_pass_1 = q
		add_child(gp)


func _points(want: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var tries := 0
	while out.size() < want and tries < want * 10:
		tries += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(z_min, z_max)
		if skip_corridor and absf(x) < 2.0 and z < 8.0 and z > -70.0:
			continue
		if skip_river:
			var rz := 4.2 + sin(x * 0.11) * 6.4 + sin(x * 0.27 + 1.1) * 2.0
			if absf(z - rz) < 2.4:
				continue
			if absf(x) < 2.7 and z > -14.0 and z < 16.0:
				continue
		var p := _ground(x, z)
		if p.x > 1.0e8:
			continue
		var ok := true
		for q in out:
			if q.distance_squared_to(p) < 6.5:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func _ground(x: float, z: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 46.0, z), Vector3(x, -10.0, z))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3(INF, INF, INF)
	var n := hit.collider as Node
	while n:
		var nm := String(n.name).to_lower()
		if nm.contains("water") or nm.contains("river") or nm.contains("player") or nm.contains("lava"):
			return Vector3(INF, INF, INF)
		n = n.get_parent()
	var normal := hit.normal as Vector3
	if normal.y < 0.42:
		return Vector3(INF, INF, INF)
	var p := hit.position as Vector3
	if p.y < 0.08:
		return Vector3(INF, INF, INF)
	return p


func _omni(pos: Vector3, col: Color, energy: float, reach: float, parent: Node = null) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(clampf(col.r, 0.2, 1.0), clampf(col.g, 0.2, 1.0), clampf(col.b, 0.2, 1.0))
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.set_meta("glimmer", true)
	light.set_meta("light_class", "glimmer")
	light.light_volumetric_fog_energy = 0.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 16.0
	light.distance_fade_shadow = 10.0
	light.distance_fade_length = 8.0
	(parent if parent else self).add_child(light)
	_pulses.append({
		"light": light,
		"base": energy,
		"phase": _rng.randf() * TAU,
		"hz": _rng.randf_range(1.4, 2.6),
	})


func _fade_own_lights() -> void:
	for light in find_children("*", "OmniLight3D", true, false):
		light.set_meta("glimmer", true)
		light.set_meta("light_class", "glimmer")
		load("res://core/world/light_policy.gd").apply_fade(light)


func _radial() -> GradientTexture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.width = 64
	g.height = 64
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	return g


func _palette(i: int) -> Color:
	if palettes.is_empty():
		return Color(0.4, 2.2, 1.6)
	return palettes[i % palettes.size()]


func _octa(st: SurfaceTool, at: Vector3, s: float, col: Color) -> void:
	var pts: Array[Vector3] = [
		at + Vector3(0, s, 0),
		at + Vector3(s, 0, 0),
		at + Vector3(0, 0, s),
		at + Vector3(-s, 0, 0),
		at + Vector3(0, 0, -s),
		at + Vector3(0, -s, 0),
	]
	var faces := [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1], [5, 2, 1], [5, 3, 2], [5, 4, 3], [5, 1, 4]]
	for f in faces:
		for k in 3:
			st.set_color(col)
			st.add_vertex(pts[int(f[k])])

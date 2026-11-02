extends RefCounted
## Shared lighting, fog, and culling. Traditional fog is far-depth only; volumetric
## carries the night colour. High aerial-perspective and ambient-inject turned the
## mid-ground grey. Visibility ranges for open scenes, occlusion for trunks/ruins,
## light distance fade so off-screen lamps drop.


static func apply(root: Node, env: Environment, cam: Camera3D, moon: DirectionalLight3D, far_m: float, fog_light: Color, vol_albedo: Color, vol_emit: Color) -> void:
	cam.near = 0.08
	cam.far = far_m
	_fog(env, fog_light, vol_albedo, vol_emit)
	_moon(moon, far_m)
	_fog_volumes(root)
	load("res://core/world/light_policy.gd").apply_all(root, moon)
	_cull_geometry(root, far_m)
	_occluders(root)
	_aim_sky_moon(env, moon)
	_swirl_vortex(env)
	_sky_flare(root, moon)
	_thicken_canopy(root)
	_thin_particles(root)
	_darken_unlit()
	load("res://core/world/surface_detail.gd").apply()
	apply_quality(env, cam)


static func _thin_particles(root: Node) -> void:
	for node in root.find_children("*", "GPUParticles3D", true, false):
		var p := node as GPUParticles3D
		var n := String(p.name).to_lower()
		if n.contains("flame"):
			continue
		var keep := 1.0
		if n.contains("rift") or n.contains("spirit"):
			keep = 0.22
		elif n.contains("ember") or n.contains("spore") or n.contains("firefly"):
			keep = 0.30
		elif n.contains("spark"):
			keep = 0.38
		elif p.amount > 80:
			keep = 0.35
		else:
			continue
		p.amount = maxi(int(round(float(p.amount) * keep)), 14)


static func apply_zone_settings(root: Node, env: Environment, cam: Camera3D, moon: DirectionalLight3D) -> void:
	set_fog(env, Settings.fog_enabled)
	if Settings.quality_preset == 0:
		env.volumetric_fog_enabled = false
	apply_quality(env, cam)
	env.ssao_enabled = Settings.ssao_enabled
	env.glow_enabled = Settings.glow_enabled
	load("res://core/world/light_policy.gd").apply_all(root, moon)


static func set_fog(env: Environment, on: bool) -> void:
	env.fog_enabled = on
	env.volumetric_fog_enabled = on


static func _fog(env: Environment, fog_light: Color, vol_albedo: Color, vol_emit: Color) -> void:
	env.fog_enabled = true
	env.fog_light_color = fog_light
	env.fog_light_energy = 0.48
	env.fog_sun_scatter = 0.06
	env.fog_density = 0.0055
	env.fog_aerial_perspective = 0.16
	env.fog_sky_affect = 0.14
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_albedo = vol_albedo
	env.volumetric_fog_emission = vol_emit
	env.volumetric_fog_emission_energy = 0.22
	env.volumetric_fog_anisotropy = 0.32
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_detail_spread = 1.15
	env.volumetric_fog_sky_affect = 0.16
	env.volumetric_fog_ambient_inject = 0.08
	env.ambient_light_energy = 0.22
	env.tonemap_exposure = 0.91
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.25
	env.ssao_light_affect = 0.32
	env.tonemap_white = 6.5
	env.glow_intensity = 0.62
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_glow_budget(env)


static func _moon(moon: DirectionalLight3D, far_m: float) -> void:
	moon.light_energy = maxf(moon.light_energy, 0.5)
	moon.light_volumetric_fog_energy = 1.35
	moon.light_angular_distance = 2.5
	moon.shadow_opacity = maxf(moon.shadow_opacity, 0.84)
	moon.directional_shadow_blend_splits = true
	moon.directional_shadow_fade_start = 0.82
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.9
	moon.directional_shadow_max_distance = minf(moon.directional_shadow_max_distance, far_m * 0.5)


static func _fog_volumes(root: Node) -> void:
	for fv in root.find_children("*", "FogVolume", true, false):
		var mat: FogMaterial = fv.material as FogMaterial
		if mat == null:
			continue
		mat = mat.duplicate()
		fv.material = mat
		var fog_name := String(fv.name).to_lower()
		if fog_name.begins_with("shaft"):
			continue
		mat.edge_fade = maxf(mat.edge_fade, 0.55)
		if fog_name.contains("ground") or fog_name.contains("mist"):
			mat.density = minf(mat.density, 0.028)
			fv.position.y = 0.38
			var s: Vector3 = fv.size
			fv.size = Vector3(s.x, minf(s.y, 2.2), s.z)
		elif fog_name.contains("wood"):
			mat.density = minf(mat.density, 0.016)
		elif fog_name.contains("river") or fog_name.contains("water"):
			mat.density = minf(mat.density, 0.03)
		elif mat.density > 0.1:
			mat.density *= 0.65


## Crushed dark base; electric blue midtones live in the maps + grade + rim.
## Do not zero terrain detail — crunch needs the high-frequency overlay.
static func _darken_unlit() -> void:
	var stone := load("res://art/materials/stone.tres") as StandardMaterial3D
	if stone:
		stone.albedo_color = Color(0.48, 0.56, 0.82)
		stone.rim = 0.68
		stone.rim_tint = 0.18
		stone.normal_scale = 2.35
		stone.roughness = 0.42
	var rock := load("res://art/materials/rock.tres") as StandardMaterial3D
	if rock:
		rock.albedo_color = Color(0.44, 0.50, 0.72)
		rock.rim = 0.52
		rock.rim_tint = 0.32
		rock.normal_scale = 2.25
		rock.roughness = 0.68
	var bark := load("res://art/materials/bark.tres") as StandardMaterial3D
	if bark:
		bark.albedo_color = Color(0.40, 0.46, 0.64)
		bark.rim = 0.50
		bark.normal_scale = 2.55
	var bark_g := load("res://art/materials/bark_giant.tres") as StandardMaterial3D
	if bark_g:
		bark_g.albedo_color = Color(0.78, 0.84, 0.90)
		bark_g.emission_enabled = true
		bark_g.emission = Color(0.18, 0.28, 0.55)
		bark_g.emission_energy_multiplier = 0.55
		bark_g.rim = 0.50
		bark_g.normal_scale = 2.45
	var terrain := load("res://art/materials/terrain.tres") as ShaderMaterial
	if terrain:
		terrain.set_shader_parameter("tint", Vector3(0.58, 0.68, 0.98))
		terrain.set_shader_parameter("rim_color", Vector3(0.45, 0.72, 1.0))
		terrain.set_shader_parameter("rim_strength", 0.20)
		terrain.set_shader_parameter("detail", 1.0)
	var crystal := load("res://art/materials/crystal.tres") as StandardMaterial3D
	if crystal:
		crystal.albedo_color = Color(0.05, 0.07, 0.16)
		crystal.emission = Color(0.42, 0.55, 1.45)
		crystal.emission_energy_multiplier = 4.4


## Tight halo only. The wide levels turned every flame into a fog bank.
static func _glow_budget(env: Environment) -> void:
	for i in 7:
		env.set_glow_level(i, i <= 1)


static func apply_quality(env: Environment, cam: Camera3D) -> void:
	env.ssr_enabled = Settings.ssr_enabled
	env.ssr_max_steps = 4
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	_glow_budget(env)
	var attrs := cam.attributes as CameraAttributesPractical
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		cam.attributes = attrs
	# The sky is the far plane. Far blur smears the stars, so it stays off.
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false


static func _cull_geometry(root: Node, far_m: float) -> void:
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		if _under_player(gi) or _under_enemy(gi):
			continue
		var n := String(gi.name).to_lower()
		# Visibility range is distance to the *node origin*, not the mesh. The
		# stair is one ArrayMesh at (0,0,0) that runs 75 m to the summit — a
		# 57 m fade hid the treads underfoot, then one step toward origin
		# brought the whole flight back. Same trap as ForestFloor / lava.
		if _skips_range(n) or _named_under(gi, "Lava"):
			continue
		if _is_span_mesh(gi, n):
			_pin_span(gi)
			continue
		var end := 0.0
		var margin := 6.0
		var cull := 0.0
		if n.begins_with("grass") or n.begins_with("fern"):
			# Range is to the MultiMesh node origin (world 0), not each blade.
			# A 16 m cap hid grass underfoot the moment you left spawn.
			end = 0.0
			margin = 0.0
			cull = 14.0
		elif n.begins_with("spore"):
			end = 24.0
			margin = 8.0
			cull = 8.0
		elif n.contains("cap") or n.contains("night"):
			end = 32.0
			margin = 10.0
			cull = 8.0
		elif n.contains("pebble"):
			end = 28.0
			margin = 8.0
			cull = 8.0
		elif gi is GPUParticles3D:
			end = 22.0
			margin = 6.0
		elif gi.visibility_range_end > 0.01:
			end = minf(gi.visibility_range_end, far_m * 0.62)
			margin = maxf(gi.visibility_range_end_margin, 6.0)
		else:
			end = far_m * 0.55
			margin = 8.0
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = margin
		gi.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED if end <= 0.01
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		)
		if cull > 0.0:
			gi.extra_cull_margin = maxf(gi.extra_cull_margin, cull)
	_repair_floor_aabb(root)
	_pin_named_spans(root)


static func _repair_floor_aabb(root: Node) -> void:
	var floor := root.find_child("ForestFloor", true, false)
	if floor == null:
		return
	for node in floor.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm: MultiMesh = mmi.multimesh
		if mm == null or mm.instance_count < 1:
			continue
		var box := AABB()
		var started := false
		for i in mm.instance_count:
			var p: Vector3 = mm.get_instance_transform(i).origin
			if not started:
				box = AABB(p, Vector3.ZERO)
				started = true
			else:
				box = box.expand(p)
		if started:
			mmi.custom_aabb = box.grow(3.5)
			mmi.visibility_range_end = 0.0
			mmi.visibility_range_end_margin = 0.0
			mmi.extra_cull_margin = maxf(mmi.extra_cull_margin, 14.0)
			mmi.ignore_occlusion_culling = true


static func _skips_range(n: String) -> bool:
	const SKIP := [
		"terrain", "water", "river", "glass", "mirror", "nave", "window",
		"masonry", "starburst", "flare", "flame", "fire", "coals", "lava", "ember",
	]
	for key in SKIP:
		if n.contains(key):
			return true
	return false


## Walkable / unique world meshes sit at the zone origin with vertices tens of
## metres away. A visibility_range on those is a close-range vanish.
static func _is_span_mesh(gi: GeometryInstance3D, n: String) -> bool:
	const KEEP := [
		"stair", "sanctuary", "ruin", "boulder", "bridge", "dock",
		"walk", "approach", "path", "deck", "arch", "gate", "column",
		"pillar", "wall", "canopy", "leaf", "trunk", "bark", "tree",
		"haven", "grotto", "cave", "tablet", "lore", "forest",
		"tavern", "keg", "dwarf", "landmark", "cairn", "watch",
	]
	for key in KEEP:
		if n.contains(key):
			return true
	var mi := gi as MeshInstance3D
	if mi != null and mi.mesh != null:
		if mi.mesh.get_aabb().size.length() > 22.0:
			return true
	return false


static func _pin_span(gi: GeometryInstance3D) -> void:
	gi.visibility_range_end = 0.0
	gi.visibility_range_end_margin = 0.0
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	gi.extra_cull_margin = maxf(gi.extra_cull_margin, 40.0)
	gi.ignore_occlusion_culling = true
	var mi := gi as MeshInstance3D
	if mi != null and mi.mesh != null and mi.custom_aabb.size.length() < 1.0:
		mi.custom_aabb = mi.mesh.get_aabb().grow(8.0)


static func _pin_named_spans(root: Node) -> void:
	for mesh_name in ["Stair", "Sanctuary", "Ruins", "DeadTrees", "GiantTrunks", "Boulders", "Terrain", "TerrainHeart"]:
		var mi := root.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null:
			continue
		_pin_span(mi)


static func _occluders(root: Node) -> void:
	if root.get_node_or_null("Occluders") != null:
		return
	var group := Node3D.new()
	group.name = "Occluders"
	root.add_child(group)
	for col in root.find_children("*", "CollisionShape3D", true, false):
		# Only trunks. Architecture boxes ate the stair when you stood on it,
		# and spawning an occluder per rock is more raster work than it saves.
		if not String(col.name).begins_with("Trunk"):
			continue
		if _under_player(col) or _skip_occluder(col):
			continue
		var shape: Shape3D = (col as CollisionShape3D).shape
		if shape == null:
			continue
		var size := Vector3.ZERO
		if shape is BoxShape3D:
			size = (shape as BoxShape3D).size
		elif shape is CylinderShape3D:
			var c := shape as CylinderShape3D
			size = Vector3(c.radius * 1.7, c.height, c.radius * 1.7)
		elif shape is CapsuleShape3D:
			var k := shape as CapsuleShape3D
			size = Vector3(k.radius * 1.7, k.height, k.radius * 1.7)
		else:
			continue
		if size.x > 14.0 or size.y > 16.0 or size.z > 14.0:
			continue
		if size.x < 0.35 or size.y < 0.8:
			continue
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = size
		occ.occluder = box
		group.add_child(occ)
		occ.global_transform = (col as CollisionShape3D).global_transform


static func _skip_occluder(n: Node) -> bool:
	var p := n
	while p:
		if p is Brazier:
			return true
		var nm := String(p.name)
		if nm in ["Bridge", "Dock", "Braziers", "Flame", "Walk", "Approach", "Stair", "StairBody", "Sanctuary", "SanctuaryBody", "Ruins", "RuinsBody", "Terrain", "TerrainBody", "Boulders", "BouldersBody"]:
			return true
		p = p.get_parent()
	return false


static func _named_under(n: Node, ancestor: String) -> bool:
	var p := n
	while p:
		if String(p.name) == ancestor:
			return true
		p = p.get_parent()
	return false


static func _under_player(n: Node) -> bool:
	var p := n
	while p:
		if p.is_in_group("player") or p.has_method("hollow"):
			return true
		p = p.get_parent()
	return false


static func _under_enemy(n: Node) -> bool:
	var p := n
	while p:
		if p.is_in_group(Groups.ENEMY):
			return true
		p = p.get_parent()
	return false


static func _swirl_vortex(env: Environment) -> void:
	if env == null or env.sky == null:
		return
	var mat := env.sky.sky_material as ShaderMaterial
	if mat == null or mat.shader == null:
		return
	if not String(mat.shader.resource_path).ends_with("vortex.gdshader"):
		return
	# Radiance cubemap is TIME-less (vortex.gdshader AT_CUBEMAP_PASS). REALTIME re-rendered
	# six identical faces every frame; QUALITY bakes once and on property change.
	env.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky.radiance_size = Sky.RADIANCE_SIZE_256


static func _aim_sky_moon(env: Environment, moon: DirectionalLight3D) -> void:
	if env == null or env.sky == null or moon == null:
		return
	var mat := env.sky.sky_material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("moon_dir", moon.global_basis.z)


static func _sky_flare(root: Node, moon: DirectionalLight3D) -> void:
	if moon == null:
		return
	var flare := root.get_node_or_null("SkyFlare") as MeshInstance3D
	if flare == null:
		flare = MeshInstance3D.new()
		flare.name = "SkyFlare"
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var q := QuadMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/sky_flare.gdshader")
		mat.set_shader_parameter("color", Color(0.58, 0.78, 1.12, 1.0))
		q.material = mat
		flare.mesh = q
		root.add_child(flare)
		flare.set_script(load("res://world/sky_flare.gd"))
		flare.set("moon", moon)
	if flare.mesh is QuadMesh:
		(flare.mesh as QuadMesh).size = Vector2(8.0, 8.0)


static func _thicken_canopy(root: Node) -> void:
	var canopy := root.find_child("Canopy", true, false) as MeshInstance3D
	if canopy == null or canopy.has_meta("thickened") or canopy.mesh == null:
		return
	canopy.set_meta("thickened", true)
	_canopy_fill(canopy, "CanopyFill", Vector3(1.16, 1.12, 1.16), 0.55, 0.37)


static func _canopy_fill(canopy: MeshInstance3D, fill_name: String, sc: Vector3, lift: float, yaw: float) -> void:
	var fill := canopy.duplicate() as MeshInstance3D
	fill.name = fill_name
	fill.scale = sc
	fill.position.y += lift
	fill.rotation.y = yaw
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canopy.get_parent().add_child(fill)

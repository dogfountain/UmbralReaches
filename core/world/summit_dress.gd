extends RefCounted
## Cathedral-scale mossy summit monument + orb mage. Runtime only.

const PLATFORM := "res://art/models/mossy_platform.glb"
const MAGE := "res://art/models/summit_mage.glb"
const PILLAR := "res://art/models/summit_pillar.glb"
const MOSS_DIFF := "res://art/textures/import/rock_moss_diff.jpg"
const MOSS_NOR := "res://art/textures/import/rock_moss_nor.jpg"
const Check := preload("res://core/debug/check.gd")

## Existing summit disc ~r=5.4 at z=-73.5. Seat cathedral behind it so the
## climb stays clear; approach stairs face +Z onto that disc.
const PLATFORM_RADIUS := 12.0
const SUMMIT := Vector3(0.0, 24.5, -83.5)
const TOP_DECK_Y := 2.85


static func dress(root: Node) -> void:
	if root == null or root.has_meta("summit_dressed"):
		return
	if Check.res(PLATFORM, PackedScene) == null or Check.res(MAGE, PackedScene) == null:
		push_error("SUMMIT_DRESS missing platform/mage glb")
		return
	root.set_meta("summit_dressed", true)
	var holder := Node3D.new()
	holder.name = "SummitAltar"
	root.add_child(holder)
	holder.global_position = SUMMIT

	var platform := Check.attach_glb(holder, PLATFORM, "MossyPlatform")
	if platform == null:
		return
	platform.position = Vector3.ZERO
	_paint_platform(platform)
	_solidify_tiers(holder)

	var mage := Check.attach_glb(holder, MAGE, "OrbMage")
	if mage:
		mage.position = Vector3(0.0, TOP_DECK_Y, 0.35)
		mage.rotation.y = PI
		mage.scale = Vector3.ONE * 1.35
		_dress_orb_light(mage)
		_paint_mage(mage)

	# Outer cathedral pillars on the mid terrace only — top dais already has the ref rail.
	if Check.res(PILLAR, PackedScene) != null:
		var spots := [
			Vector3(-7.2, 2.05, -6.8),
			Vector3(7.2, 2.05, -6.8),
		]
		for i in spots.size():
			var pillar := Check.attach_glb(holder, PILLAR, "SummitPillar%d" % i)
			if pillar == null:
				continue
			pillar.position = spots[i]
			pillar.rotation.y = fposmod(float(i) * 1.3 + 0.5, TAU)
			pillar.scale = Vector3.ONE * 0.85
			_paint_pillar(pillar)

	# Moss hang on lower rims only — keep the cobble circle clean like the ref.
	_drape_moss_cards(holder)

	print("SUMMIT_DRESS cathedral platform r=%.1f at %s" % [PLATFORM_RADIUS, SUMMIT])


static func _solidify_tiers(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PlatformBody"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	# Pull outer drums slightly -Z so they do not wall off the summit disc approach.
	for spec in [
		{"r": 10.2, "h": 1.15, "y": 0.575, "z": -1.6},
		{"r": 9.2, "h": 0.9, "y": 1.6, "z": -0.4},
		{"r": 6.4, "h": 0.8, "y": 2.45, "z": 0.0},
	]:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = spec.r
		cyl.height = spec.h
		shape.shape = cyl
		shape.position = Vector3(0.0, spec.y, spec.z)
		body.add_child(shape)
	# Stepped approach toward +Z (onto the existing summit disc).
	var steps := 10
	var stair_w := 5.5
	var depth := 0.58
	for s in steps:
		var z0 := (float(s) / float(steps)) * TOP_DECK_Y
		var h := TOP_DECK_Y / float(steps) + 0.04
		var z_front := PLATFORM_RADIUS + 0.15 - float(s) * depth
		var step := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(stair_w, h, depth)
		step.shape = box
		step.position = Vector3(0.0, z0 + h * 0.5, z_front - depth * 0.5)
		body.add_child(step)


static func _moss_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.72, 0.38)
	var diff := Check.res(MOSS_DIFF, Texture2D) as Texture2D
	var nor := Check.res(MOSS_NOR, Texture2D) as Texture2D
	if diff:
		m.albedo_texture = diff
	if nor:
		m.normal_enabled = true
		m.normal_scale = 1.4
		m.normal_texture = nor
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return m


static func _stone_material() -> Material:
	var stone := load("res://art/materials/stone.tres") as StandardMaterial3D
	if stone:
		var s := stone.duplicate() as StandardMaterial3D
		s.albedo_color = Color(0.48, 0.55, 0.68)
		s.uv1_scale = Vector3(0.12, 0.12, 0.12)
		return s
	return null


static func _paint_platform(model: Node) -> void:
	var moss := _moss_material()
	var stone := _stone_material()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name).to_lower()
		if n.contains("moss"):
			mi.material_override = moss
		elif n.contains("cobble"):
			var cobble := StandardMaterial3D.new()
			# Let the mossy albedo speak — light cool tint only.
			cobble.albedo_color = Color(0.85, 0.95, 0.92)
			var ctex := Check.res("res://art/textures/cobble_ring.png", Texture2D) as Texture2D
			var cn := Check.res("res://art/textures/cobble_ring_n.png", Texture2D) as Texture2D
			if ctex:
				cobble.albedo_texture = ctex
			if cn:
				cobble.normal_enabled = true
				cobble.normal_scale = 1.85
				cobble.normal_texture = cn
			cobble.roughness = 0.52
			cobble.metallic = 0.05
			cobble.rim_enabled = true
			cobble.rim = 0.5
			cobble.rim_tint = 0.22
			cobble.uv1_triplanar = true
			cobble.uv1_world_triplanar = true
			cobble.uv1_scale = Vector3(0.18, 0.18, 0.18)
			mi.material_override = cobble
		elif stone:
			mi.material_override = stone
		mi.visibility_range_end = 0.0
		mi.ignore_occlusion_culling = true
		mi.extra_cull_margin = 8.0


static func _paint_pillar(model: Node) -> void:
	var moss := _moss_material()
	var stone := _stone_material()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name).to_lower()
		if n.contains("moss"):
			mi.material_override = moss
		elif stone:
			mi.material_override = stone
		mi.visibility_range_end = 0.0
		mi.ignore_occlusion_culling = true


static func _drape_moss_cards(holder: Node3D) -> void:
	var tex := load("res://art/textures/moss_hang.png") as Texture2D
	var mat := ShaderMaterial.new()
	var shader := load("res://world/zones/foliage.gdshader") as Shader
	if shader == null or tex == null:
		return
	mat.shader = shader
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("tint", Color(0.55, 1.15, 0.7))
	mat.set_shader_parameter("alpha_cut", 0.35)
	mat.set_shader_parameter("backlight", 0.4)
	mat.set_shader_parameter("rim_strength", 0.2)
	mat.set_shader_parameter("rim_color", Vector3(0.35, 0.8, 0.55))
	mat.set_shader_parameter("wind_strength", 0.12)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := 0.7
	var hy := 1.8
	for yaw in [0.0, PI * 0.5]:
		var c := cos(yaw)
		var s := sin(yaw)
		var v0 := Vector3(-hx * c, -hy, -hx * s)
		var v1 := Vector3(hx * c, -hy, hx * s)
		var v2 := Vector3(hx * c, hy, hx * s)
		var v3 := Vector3(-hx * c, hy, -hx * s)
		# Tips at UV.y=0 so wind flutters the hang.
		st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(v1)
		st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
		st.set_uv(Vector2(0, 1)); st.add_vertex(v3)
	st.generate_normals()
	var mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Skip the top deck — ref dais is clean cobble.
	var tiers: Array[float] = [1.15, 2.05]
	for tier_y in tiers:
		var rad: float = 11.2 if tier_y < 1.5 else 8.6
		for i in 22:
			var a: float = float(i) / 22.0 * TAU + tier_y

			var xf := Transform3D.IDENTITY
			xf.origin = Vector3(cos(a) * rad, tier_y + rng.randf_range(0.2, 1.1), sin(a) * rad)
			xf.basis = Basis.from_euler(Vector3(0.2, a + PI, 0.0))
			xf.basis = xf.basis.scaled(Vector3.ONE * rng.randf_range(0.9, 1.5))
			xforms.append(xf)
	mm.instance_count = xforms.size()
	var box := AABB(xforms[0].origin, Vector3.ZERO)
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		box = box.expand(xforms[i].origin)
	mm.custom_aabb = box.grow(6.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MonumentMossHang"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.ignore_occlusion_culling = true
	holder.add_child(mmi)


static func _paint_mage(model: Node) -> void:
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.05, 0.07, 0.14)
	robe.roughness = 0.88
	robe.rim_enabled = true
	robe.rim = 0.62
	robe.rim_tint = 0.22
	var void_m := StandardMaterial3D.new()
	void_m.albedo_color = Color(0.01, 0.01, 0.02)
	void_m.roughness = 1.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		if n.begins_with("Void"):
			mi.material_override = void_m
		elif n.begins_with("Orb"):
			continue
		elif n.begins_with("Robe"):
			mi.material_override = robe
		mi.visibility_range_end = 0.0
		mi.ignore_occlusion_culling = true


static func _dress_orb_light(mage: Node) -> void:
	var orb_mi: MeshInstance3D = null
	for node in mage.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Orb"):
			orb_mi = node as MeshInstance3D
			break
	if orb_mi == null:
		push_error("SUMMIT_DRESS no Orb mesh on mage")
		return
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.75, 0.85, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.45, 0.62, 1.0)
	orb_mat.emission_energy_multiplier = 3.2
	orb_mat.roughness = 0.25
	orb_mi.material_override = orb_mat
	orb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "OrbLight"
	light.light_color = Color(0.55, 0.7, 1.0)
	light.light_energy = 1.55
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.7
	orb_mi.add_child(light)

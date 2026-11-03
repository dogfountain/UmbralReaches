class_name SummitDress
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
## Holder-space box cut out of the rails where the Ossuary lift jetty meets the mid tier
## (jetty: world x 6.4..11.7, z -89 +-1.25 -> holder x 6.4..11.7, z -5.5 +-1.25).
const LIFT_LANE := AABB(Vector3(2.6, 0.8, -7.3), Vector3(10.0, 3.6, 3.6))   ## no rocks on the jetty route
const LIFT_GATE := AABB(Vector3(4.6, 1.2, -7.1), Vector3(8.0, 3.2, 3.2))


## Remove the triangles of `mi` whose centre falls inside `box` (holder space): a real gap in the
## visible rail, and (since collision is built from the same mesh afterwards) in its collision.
static func _cut_gate(mi: MeshInstance3D, holder: Node3D, box: AABB) -> void:
	var to_h := holder.global_transform.affine_inverse() * mi.global_transform
	var src := mi.mesh
	var out := ArrayMesh.new()
	var removed := 0
	for si in src.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(src, si)
		var arrays := st.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var c := to_h * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
			if box.has_point(c):
				removed += 1
				continue
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	if removed > 0:
		mi.mesh = out
		print("SUMMIT_DRESS gate cut in %s: %d tris" % [mi.name, removed])


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
	_solidify_from_meshes(holder, platform)

	# The monument: a carved stone mage on a rune pedestal, facing the stair (+Z).
	var statue := MageStatue.new()
	statue.name = "MageStatue"
	holder.add_child(statue)
	statue.position = Vector3(0.0, TOP_DECK_Y, 0.0)
	statue.rotation.y = PI

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

	# (The hanging moss cards stood up off the tiers like stray grass blades; removed.)

	print("SUMMIT_DRESS cathedral platform r=%.1f at %s" % [PLATFORM_RADIUS, SUMMIT])


static func _solidify_tiers(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PlatformBody"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	# Tier collision now comes from the monument mesh itself (_solidify_from_meshes): the old
	# drum cylinders stopped ~2 m short of the visible rim, so you could drop through its edge.
	# The approach stairs are a smooth ramp under the step nosings (0.29 m risers cannot be
	# climbed by a capsule without jumping), the same trick the main stair uses.
	var steps := 10
	var stair_w := 5.5
	var depth := 0.58
	var z_lo := PLATFORM_RADIUS + 0.15
	var z_hi := z_lo - float(steps) * depth
	var run := z_lo - z_hi
	var ang := atan2(TOP_DECK_Y, run)
	var ramp := CollisionShape3D.new()
	ramp.name = "ApproachRamp"
	var rb := BoxShape3D.new()
	rb.size = Vector3(stair_w, 0.3, sqrt(run * run + TOP_DECK_Y * TOP_DECK_Y) + 0.3)
	ramp.shape = rb
	var up := Vector3(0.0, cos(ang), sin(ang))
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, ang), Vector3(0.0, TOP_DECK_Y * 0.5, (z_lo + z_hi) * 0.5) - up * 0.15)
	body.add_child(ramp)


## Collision from the visible meshes: trimesh for the stone monument and its rails, simplified
## convex hulls for every moss rock (you used to walk straight through them).
static func _solidify_from_meshes(holder: Node3D, platform: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "MonumentBody"
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var inv := holder.global_transform.affine_inverse()
	var rocks := 0
	for node in platform.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		var shape: Shape3D = null
		if n == "StoneMonument":
			# cut the approach corridor out: the ramp alone carries you up through the tiers there
			var xf := inv * mi.global_transform
			var faces := mi.mesh.get_faces()
			var kept := PackedVector3Array()
			for i in range(0, faces.size(), 3):
				var a := xf * faces[i]
				var b := xf * faces[i + 1]
				var c := xf * faces[i + 2]
				var m := (a + b + c) / 3.0
				if absf(m.x) < 3.0 and m.z > 5.6:
					continue
				kept.append_array(PackedVector3Array([a, b, c]))
			var cps := ConcavePolygonShape3D.new()
			cps.set_faces(kept)
			var ccs := CollisionShape3D.new()
			ccs.shape = cps
			body.add_child(ccs)
			continue
		elif n.begins_with("StoneRail") or n == "StoneDaisRail":
			_cut_gate(mi, holder, LIFT_GATE)          # opening where the Ossuary lift jetty arrives
			shape = mi.mesh.create_trimesh_shape()
		elif n.begins_with("MossRock"):
			var centre := inv * mi.global_transform * mi.get_aabb().get_center()
			if LIFT_LANE.has_point(centre):
				mi.visible = false                     # a rock sat in the lift jetty's mouth
				continue
			shape = mi.mesh.create_convex_shape(true, true)
			rocks += 1
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = inv * mi.global_transform
		body.add_child(cs)
	print("SUMMIT_DRESS collision from meshes: monument+rails trimesh, %d rock hulls" % rocks)


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
	# Dressed limestone shared with the Ossuary (was the cyan-seamed cobble stone).
	var s := StandardMaterial3D.new()
	var t := "res://art/textures/oss_ashlar"
	s.albedo_texture = load(t + "_albedo.png")
	s.normal_enabled = true
	s.normal_texture = load(t + "_normal.png")
	s.roughness_texture = load(t + "_rough.png")
	s.ao_enabled = true
	s.ao_texture = load(t + "_ao.png")
	s.albedo_color = Color(0.74, 0.76, 0.84)
	s.uv1_triplanar = true
	s.uv1_world_triplanar = true
	s.uv1_triplanar_sharpness = 4.0
	s.uv1_scale = Vector3.ONE * 0.3
	s.rim_enabled = true
	s.rim = 0.25
	s.rim_tint = 0.4
	return s


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
			cobble.roughness = 0.7
			cobble.metallic = 0.0
			cobble.normal_scale = 1.2
			cobble.albedo_color = Color(0.62, 0.66, 0.72)
			cobble.rim_enabled = true
			cobble.rim = 0.2
			cobble.rim_tint = 0.3
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

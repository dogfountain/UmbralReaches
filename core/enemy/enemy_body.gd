extends RefCounted
## Jointed, textured body for Enemy types. Not the wanderer robe. Uses existing
## stone / bark / ground maps so flesh and rags read as surfaces, not flat grey.

const STONE_A := "res://art/textures/stone_albedo.png"
const STONE_N := "res://art/textures/stone_normal.png"
const BARK_A := "res://art/textures/bark_albedo.png"
const BARK_N := "res://art/textures/bark_normal.png"
const GROUND_A := "res://art/textures/ground_albedo.png"
const GROUND_N := "res://art/textures/ground_normal.png"

static var _cache: Dictionary = {}
static var _joint_meshes := {}
const Check := preload("res://core/debug/check.gd")


static func dress(rig: CharacterRig, kind: StringName) -> void:
	if rig == null:
		push_error("enemy_body.dress rig null")
		return
	var pack: Dictionary = _mats(kind)
	var flesh: Material = pack.flesh
	var rag: Material = pack.rag
	var hide: Material = pack.hide
	var void_m: Material = pack.void_m
	var bone: Material = pack.bone

	_put(rig, "pelvis", "Hips", ProcMesh.sphere(0.14, 0.17, 12, 6), Vector3(0.0, -0.06, 0.0), flesh, Vector3.ZERO, true)
	var mesh_kind := kind
	if kind == &"crawler":
		mesh_kind = &"wretch"
	elif kind == &"leaper":
		mesh_kind = &"husk"
	var used_torso := _attach_glb(rig, "chest", "res://art/models/%s_torso.glb" % mesh_kind, pack)
	if not used_torso:
		_put(rig, "chest", "Rib", ProcMesh.capsule(0.16, 0.44), Vector3(0.0, 0.02, 0.02), flesh, Vector3.ZERO, true)
		_put(rig, "chest", "Belly", ProcMesh.sphere(0.13, 0.16, 10, 6), Vector3(0.0, -0.16, 0.04), flesh)
		_put(rig, "chest", "Wrap", ProcMesh.cyl(0.18, 0.16, 0.24, 12, 1), Vector3(0.0, -0.02, 0.03), rag, Vector3.ZERO, true)
		_put(rig, "chest", "Sash", ProcMesh.cyl(0.185, 0.13, 0.08, 10, 1), Vector3(0.0, -0.14, 0.02), rag)
		_put(rig, "chest", "Neck", ProcMesh.cyl(0.05, 0.058, 0.12, 10, 1), Vector3(0.0, 0.28, 0.0), flesh)
		_put(rig, "chest", "Spine", ProcMesh.cyl(0.03, 0.04, 0.28, 8, 1), Vector3(0.0, 0.02, 0.09), bone)

	var used_head := _attach_glb(rig, "head", "res://art/models/%s_head.glb" % mesh_kind, pack)
	if not used_head:
		_put(rig, "head", "Skull", ProcMesh.sphere(0.11, 0.17, 14, 8), Vector3(0.0, 0.04, 0.01), flesh, Vector3.ZERO, true)
		_put(rig, "head", "Jaw", ProcMesh.sphere(0.072, 0.085, 10, 5), Vector3(0.0, -0.05, 0.03), flesh)
		_put(rig, "head", "Nose", ProcMesh.sphere(0.02, 0.032, 8, 4), Vector3(0.0, 0.02, -0.09), flesh)
		_put(rig, "head", "Brow", ProcMesh.cyl(0.092, 0.082, 0.04, 10, 1), Vector3(0.0, 0.07, -0.06), flesh, Vector3(1.2, 0.0, 0.0))
		_put(rig, "head", "EarL", ProcMesh.sphere(0.024, 0.042, 8, 4), Vector3(-0.09, 0.03, 0.01), flesh)
		_put(rig, "head", "EarR", ProcMesh.sphere(0.024, 0.042, 8, 4), Vector3(0.09, 0.03, 0.01), flesh)
		_put(rig, "head", "EyeL", ProcMesh.sphere(0.024, 0.032, 8, 4), Vector3(-0.035, 0.04, -0.08), void_m)
		_put(rig, "head", "EyeR", ProcMesh.sphere(0.024, 0.032, 8, 4), Vector3(0.035, 0.04, -0.08), void_m)
		_put(rig, "head", "Teeth", ProcMesh.cyl(0.038, 0.03, 0.02, 8, 1), Vector3(0.0, -0.04, -0.07), bone, Vector3(1.1, 0.0, 0.0))
		_put(rig, "head", "FangL", ProcMesh.cyl(0.01, 0.004, 0.04, 6, 1), Vector3(-0.02, -0.07, -0.07), bone)
		_put(rig, "head", "FangR", ProcMesh.cyl(0.01, 0.004, 0.04, 6, 1), Vector3(0.02, -0.07, -0.07), bone)
		if kind == &"wretch":
			_put(rig, "head", "Cowl", ProcMesh.cyl(0.085, 0.14, 0.18, 12, 1), Vector3(0.0, 0.08, -0.01), rag, Vector3.ZERO, true)
			_put(rig, "head", "CowlDrape", ProcMesh.cyl(0.13, 0.08, 0.14, 10, 1), Vector3(0.0, -0.02, 0.04), rag)

	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		_put(rig, "shoulder_" + side, "Deltoid", ProcMesh.sphere(0.08, 0.095, 10, 5), Vector3(sx * 0.02, 0.0, 0.0), flesh, Vector3.ZERO, true)
		_put(rig, "shoulder_" + side, "Upper", ProcMesh.cyl(0.058, 0.046, 0.28, 10, 1), Vector3(0.0, -0.15, 0.0), flesh, Vector3.ZERO, true)
		_put(rig, "elbow_" + side, "Fore", ProcMesh.cyl(0.044, 0.034, 0.26, 10, 1), Vector3(0.0, -0.14, 0.0), flesh)
		_put(rig, "elbow_" + side, "Wrap", ProcMesh.cyl(0.05, 0.048, 0.07, 8, 1), Vector3(0.0, -0.04, 0.0), rag)
		_put(rig, "hand_" + side, "Palm", ProcMesh.sphere(0.04, 0.056, 10, 5), Vector3.ZERO, hide)
		for f in 3:
			var fx := sx * (0.01 + float(f) * 0.016)
			_put(rig, "hand_" + side, "Finger%d" % f, ProcMesh.cyl(0.011, 0.008, 0.055, 6, 1), Vector3(fx, -0.018, -0.038), hide, Vector3(0.95, 0.0, 0.0))
			_put(rig, "hand_" + side, "Claw%d" % f, ProcMesh.cyl(0.007, 0.002, 0.028, 5, 1), Vector3(fx, -0.03, -0.07), bone, Vector3(1.1, 0.0, 0.0))
		_put(rig, "hip_" + side, "Thigh", ProcMesh.cyl(0.078, 0.056, 0.38, 10, 1), Vector3(0.0, -0.20, 0.0), flesh, Vector3.ZERO, true)
		_put(rig, "knee_" + side, "Shin", ProcMesh.cyl(0.052, 0.042, 0.38, 10, 1), Vector3(0.0, -0.20, 0.0), flesh, Vector3.ZERO, true)
		_put(rig, "knee_" + side, "Wrap", ProcMesh.cyl(0.058, 0.054, 0.06, 8, 1), Vector3(0.0, -0.02, 0.0), rag)
		_put(rig, "foot_" + side, "Last", ProcMesh.cyl(0.05, 0.056, 0.08, 10, 1), Vector3(0.0, 0.02, -0.03), hide, Vector3(1.15, 0.0, 0.0))
		_put(rig, "foot_" + side, "Toe", ProcMesh.sphere(0.044, 0.05, 8, 4), Vector3(0.0, 0.02, -0.07), hide)
		_put(rig, "foot_" + side, "Talon", ProcMesh.cyl(0.012, 0.004, 0.04, 6, 1), Vector3(0.0, 0.0, -0.11), bone, Vector3(1.2, 0.0, 0.0))

	if kind == &"husk" and not used_torso:
		_put(rig, "chest", "RibShow", ProcMesh.cyl(0.145, 0.13, 0.08, 12, 1), Vector3(0.0, 0.08, 0.04), bone)
		_put(rig, "pelvis", "RagSkirt", ProcMesh.cyl(0.17, 0.21, 0.2, 12, 1), Vector3(0.0, -0.16, 0.0), rag, Vector3.ZERO, true)
		_put(rig, "chest", "Hollow", ProcMesh.sphere(0.055, 0.065, 8, 4), Vector3(0.0, 0.06, 0.12), void_m)
	_merge_joints(rig, kind)


static func _attach_glb(rig: CharacterRig, socket_name: String, path: String, pack: Dictionary) -> bool:
	var joint := rig.socket(socket_name)
	if joint == null:
		push_error("enemy_body: socket '%s' missing for %s" % [socket_name, path])
		return false
	var model := Check.attach_glb(joint, path, "Mesh")
	if model == null:
		return false
	_paint_prefix(model, "Flesh", pack.get("flesh"))
	_paint_prefix(model, "Rag", pack.get("rag"))
	_paint_prefix(model, "Bone", pack.get("bone"))
	_paint_prefix(model, "Void", pack.get("void_m"))
	return true


static func _paint_prefix(model: Node, prefix: String, mat: Variant) -> void:
	if model == null:
		push_error("enemy_body.paint null model %s" % prefix)
		return
	if mat == null or not (mat is Material):
		push_error("enemy_body.paint null mat %s" % prefix)
		return
	var n := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(prefix):
			(node as MeshInstance3D).material_override = mat
			n += 1
	if n == 0 and prefix == "Flesh":
		push_error("enemy_body.paint %s: no Flesh mesh" % model.name)


static func _merge_joints(rig: CharacterRig, kind: StringName) -> void:
	const SOCKETS := [
		"pelvis", "chest", "head",
		"shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r",
		"hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r",
	]
	for socket_name in SOCKETS:
		var joint := rig.socket(socket_name)
		if joint == null:
			continue
		var by_mat := {}
		for c in joint.get_children():
			if not (c is MeshInstance3D) or c.get_child_count() > 0:
				continue
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var mid := 0
			if mi.material_override:
				mid = int(mi.material_override.get_rid().get_id())
			if not by_mat.has(mid):
				by_mat[mid] = {"mat": mi.material_override, "mis": []}
			by_mat[mid].mis.append(mi)
		for mid in by_mat:
			var g: Dictionary = by_mat[mid]
			if g.mis.size() < 2:
				continue
			var cache_key := "%s/%s/%d" % [kind, socket_name, mid]
			var combined: ArrayMesh = _joint_meshes.get(cache_key)
			if combined == null:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for mi in g.mis:
					st.append_from(mi.mesh, 0, mi.transform)
				combined = st.commit()
				_joint_meshes[cache_key] = combined
			var merged := MeshInstance3D.new()
			merged.name = "Merged"
			merged.mesh = combined
			merged.material_override = g.mat
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			joint.add_child(merged)
			for mi in g.mis:
				joint.remove_child(mi)
				mi.free()


static func _put(rig: CharacterRig, socket_name: String, n_name: String, mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO, shadow := false) -> void:
	var joint := rig.socket(socket_name)
	if joint == null:
		push_error("enemy_body._put socket '%s' missing" % socket_name)
		return
	if mesh == null:
		push_error("enemy_body._put null mesh %s/%s" % [socket_name, n_name])
		return
	ProcMesh.mesh(joint, n_name, mesh, mat, at, rot, shadow)


static func _mats(kind: StringName) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var flesh_tint := Color(0.82, 0.64, 0.50)
	var rag_tint := Color(0.36, 0.22, 0.14)
	var hide_tint := Color(0.22, 0.16, 0.12)
	var bone_tint := Color(0.84, 0.72, 0.56)
	if kind == &"husk":
		flesh_tint = Color(0.42, 0.34, 0.30)
		rag_tint = Color(0.16, 0.12, 0.10)
		hide_tint = Color(0.14, 0.11, 0.09)
		bone_tint = Color(0.58, 0.50, 0.40)
	elif kind == &"crawler":
		flesh_tint = Color(0.58, 0.50, 0.42)
		rag_tint = Color(0.22, 0.16, 0.12)
		hide_tint = Color(0.18, 0.14, 0.10)
		bone_tint = Color(0.70, 0.62, 0.48)
	elif kind == &"leaper":
		flesh_tint = Color(0.62, 0.28, 0.26)
		rag_tint = Color(0.22, 0.08, 0.10)
		hide_tint = Color(0.16, 0.08, 0.08)
		bone_tint = Color(0.72, 0.48, 0.40)
	var pack := {
		"flesh": _tri(STONE_A, STONE_N, flesh_tint, 0.72, 0.55),
		"rag": _tri(BARK_A, BARK_N, rag_tint, 0.9, 0.35),
		"hide": _tri(GROUND_A, GROUND_N, hide_tint, 0.88, 0.4),
		"bone": _tri(STONE_A, STONE_N, bone_tint, 0.42, 0.7),
		"void_m": _void(),
	}
	_cache[kind] = pack
	return pack


static func _tri(albedo_path: String, normal_path: String, tint: Color, rough: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	var albedo := Check.res(albedo_path, Texture2D) as Texture2D
	var normal := Check.res(normal_path, Texture2D) as Texture2D
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = normal
	m.normal_scale = 1.15
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(scale, scale, scale)
	m.uv1_triplanar_sharpness = 2.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.rim_enabled = true
	m.rim = 0.48
	m.rim_tint = 0.35
	return m


static func _void() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.02, 0.015, 0.02)
	return m

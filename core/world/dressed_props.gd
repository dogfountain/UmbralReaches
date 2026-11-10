class_name DressedProps
extends RefCounted
## Dresses the braziers with the Blender brazier model and stands menhirs for the henge.

const BRAZIER := "res://art/models/brazier.glb"
const MENHIR := "res://art/models/menhir.glb"
const MENHIR_H := 3.2
const Check := preload("res://core/debug/check.gd")


static func dress_brazier(node: Node3D) -> void:
	if node == null:
		push_error("DRESS brazier node null")
		return
	if node.has_meta("dressed"):
		return
	var base := node.get_node_or_null("Base") as MeshInstance3D
	var bowl := node.get_node_or_null("Bowl") as MeshInstance3D
	var model := Check.attach_glb(node, BRAZIER, "DressedBrazier")
	if model == null:
		return
	node.set_meta("dressed", true)
	_paint(model, "Plinth", base.material_override if base != null else null)
	_paint(model, "Bowl", bowl.material_override if bowl != null else null)
	if base != null:
		base.visible = false
	if bowl != null:
		bowl.visible = false
	_solidify_brazier(node, model)
	for gi in node.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).ignore_occlusion_culling = true
		(gi as GeometryInstance3D).visibility_range_end = 0.0
	var coals := node.get_node_or_null("Coals") as MeshInstance3D
	if coals != null:
		coals.position = Vector3(0.0, 1.18, 0.0)
		coals.scale = Vector3(0.65, 1.0, 0.65)
	var flame := node.get_node_or_null("Flame") as GPUParticles3D
	if flame != null:
		flame.position.y = 1.62
		flame.visibility_aabb = AABB(Vector3(-1.6, -0.4, -1.6), Vector3(3.2, 3.4, 3.2))
		flame.ignore_occlusion_culling = true
		flame.visibility_range_end = 0.0
		var draw := flame.draw_pass_1
		if draw is QuadMesh:
			var q := draw as QuadMesh
			q.size = Vector2(0.62, 0.78)
			var mat := q.material as StandardMaterial3D
			if mat:
				mat = mat.duplicate()
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
				q.material = mat
		if flame.get_node_or_null("Cards") == null:
			var cards := Node3D.new()
			cards.name = "Cards"
			cards.visible = flame.emitting
			flame.add_child(cards)
			var shader: Shader = Check.res("res://world/brazier_flame.gdshader", Shader) as Shader
			if shader == null:
				push_error("DRESS missing brazier_flame.gdshader")
				return
			for i in 2:
				var mi := MeshInstance3D.new()
				var plane := QuadMesh.new()
				plane.size = Vector2(0.72, 1.15)
				var sm := ShaderMaterial.new()
				sm.shader = shader
				plane.material = sm
				mi.mesh = plane
				mi.position = Vector3(0.0, 0.42, 0.0)
				mi.rotation.y = float(i) * PI * 0.5
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.ignore_occlusion_culling = true
				cards.add_child(mi)
	var shape := node.get_node_or_null("Body/Shape") as CollisionShape3D
	if shape != null and shape.shape is CylinderShape3D:
		var cyl := shape.shape as CylinderShape3D
		cyl.radius = 0.58
		cyl.height = 1.5
		shape.position.y = 0.75


static func _place_menhir(parent: Node, foot: Vector3, yaw: float, height: float, mat: Material, face: Vector3, face_center: bool) -> void:
	if parent == null:
		push_error("DRESS menhir parent null")
		return
	var model := Check.attach_glb(parent, MENHIR, "Menhir%d" % parent.get_child_count())
	if model == null:
		return
	model.global_position = foot
	model.scale = Vector3.ONE * clampf(height / MENHIR_H, 0.75, 1.7)
	if face_center and Vector2(face.x - foot.x, face.z - foot.z).length() > 0.4:
		var target := Vector3(face.x, foot.y, face.z)
		model.look_at(target, Vector3.UP)
		model.rotate_y(PI)
	else:
		model.rotation.y = yaw
	var stone: Material = StoneBodies.material_for(parent)
	_paint(model, "Stone", stone if stone != null else mat)
	StoneBodies.solidify(model as Node3D)
	_moss(model as Node3D, height)


static func _moss(model: Node3D, height: float) -> void:
	if model == null or model.get_node_or_null("MossSkirt") != null:
		return
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color(0.14, 0.22, 0.16)
	moss.albedo_texture = load("res://art/textures/ground_albedo.png")
	moss.normal_enabled = true
	moss.normal_texture = load("res://art/textures/ground_normal.png")
	moss.roughness = 0.92
	moss.uv1_triplanar = true
	moss.uv1_world_triplanar = true
	moss.uv1_scale = Vector3(0.7, 0.7, 0.7)
	moss.uv1_triplanar_sharpness = 4.0
	var h := clampf(height * 0.12, 0.18, 0.42)
	ProcMesh.mesh(model, "MossSkirt", ProcMesh.cyl(0.42, 0.58, h, 12, 1), moss, Vector3(0.0, h * 0.35, 0.0), Vector3.ZERO, false)
	ProcMesh.mesh(model, "Lichen", ProcMesh.sphere(0.16, 0.08, 8, 4), moss, Vector3(0.18, height * 0.35, 0.12), Vector3.ZERO, false)


static func _paint(model: Node, prefix: String, mat: Material) -> void:
	if mat == null:
		return
	var n := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(prefix):
			(node as MeshInstance3D).material_override = mat
			n += 1
	if n == 0:
		push_error("DRESS %s: no mesh begins with '%s'" % [model.name, prefix])


## The braziers were ghosts: you walked straight through plinth and bowl. A cylinder on the PROPS
## layer (player and enemies collide, the camera arm ignores it) sized from the dressed model.
static func _solidify_brazier(node: Node3D, model: Node) -> void:
	if node.get_node_or_null("BrazierBody") != null or not node.is_inside_tree():
		return
	var bb := node.global_transform.affine_inverse() * WorldLanes.bounds(model)
	if bb.size.y < 0.2:
		return
	var body := StaticBody3D.new()
	body.name = "BrazierBody"
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = clampf(minf(bb.size.x, bb.size.z) * 0.36, 0.2, 0.6)
	cyl.height = bb.size.y
	cs.shape = cyl
	cs.position = Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.5, bb.get_center().z)
	body.add_child(cs)
	node.add_child(body)

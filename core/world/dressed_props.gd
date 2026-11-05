class_name DressedProps
extends RefCounted
## Swaps the baked cylinders and boxes for the Blender lantern, brazier, and menhir.
## Runs on the already-seated scene so main.tscn does not have to be rebaked.

const LANTERN := "res://art/models/lantern.glb"
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


static func dress_zone(root: Node) -> void:
	if root == null:
		push_error("DRESS zone root null")
		return
	if Check.res(LANTERN, PackedScene) == null:
		return
	if Check.res(MENHIR, PackedScene) == null:
		return
	var lamps := 0
	var stones := 0
	var lanterns := root.find_child("Lanterns", true, false)
	if lanterns != null and not lanterns.has_meta("dressed"):
		lanterns.set_meta("dressed", true)
		for lamp in lanterns.get_children():
			if lamp.get_node_or_null("Pole") != null:
				_dress_lamp(lamp)
				lamps += 1
	var dock := root.find_child("Dock", true, false)
	if dock != null and dock.get_node_or_null("LampPost") != null and not dock.has_meta("dressed_lamp"):
		dock.set_meta("dressed_lamp", true)
		_dress_dock(dock)
		lamps += 1
	var circle := root.find_child("StandingStones", true, false)
	if circle != null:
		stones += _dress_standing(circle.get_node_or_null("Ring") as MeshInstance3D, true)
	var shrine_ring := root.get_node_or_null("Zone/Shrine/Ring") as MeshInstance3D
	if shrine_ring != null:
		shrine_ring.visible = false
	var ruins := root.find_child("Ruins", true, false) as MeshInstance3D
	if ruins != null:
		stones += _dress_standing(ruins, false)
	if lamps > 0 or stones > 0:
		print("DRESS lanterns=%d stones=%d" % [lamps, stones])
	DemoDress.dress(root)
	StoneBodies.harden(root)
	NightDress.dress(root)
	SummitDress.dress(root)


static func _dress_lamp(lamp: Node) -> void:
	if lamp == null:
		push_error("DRESS lamp null")
		return
	var pole := lamp.get_node_or_null("Pole") as MeshInstance3D
	var cage := lamp.get_node_or_null("Cage") as MeshInstance3D
	var model := Check.attach_glb(lamp, LANTERN, "DressedLantern")
	if model == null:
		return
	_paint(model, "Post", pole.material_override if pole != null else null)
	_paint(model, "Iron", cage.material_override if cage != null else null)
	_quiet_glass(model)
	for child in lamp.get_children():
		if child == model:
			continue
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	_move_light(model, lamp.get_node_or_null("Light") as OmniLight3D)


static func _dress_dock(dock: Node) -> void:
	if dock == null:
		push_error("DRESS dock null")
		return
	var post := dock.get_node_or_null("LampPost") as MeshInstance3D
	if post == null:
		push_error("DRESS dock LampPost missing")
		return
	var model := Check.attach_glb(dock, LANTERN, "DressedLantern")
	if model == null:
		return
	var foot := post.position
	foot.y += post.get_aabb().position.y
	model.position = foot
	_paint(model, "Post", post.material_override)
	var cage := dock.get_node_or_null("Cage") as MeshInstance3D
	if cage != null:
		_paint(model, "Iron", cage.material_override)
		cage.visible = false
	post.visible = false
	var glow := dock.get_node_or_null("Lamp") as MeshInstance3D
	if glow != null:
		glow.visible = false
	_quiet_glass(model)
	_move_light(model, dock.get_node_or_null("Light") as OmniLight3D)


static func _dress_standing(mesh_node: MeshInstance3D, face_center: bool) -> int:
	if mesh_node == null or mesh_node.has_meta("dressed") or mesh_node.mesh == null:
		return 0
	mesh_node.set_meta("dressed", true)
	var tris: Array = _triangles(mesh_node.mesh)
	if tris.is_empty():
		return 0
	var islands: Array = _islands(tris)
	var keep: Array = []
	var replaced: Array = []
	for island in islands:
		var span: Dictionary = _span(island)
		var size: Vector3 = span.mx - span.mn
		# Columns lean a little, so their footprint is wider than the mesh radius.
		# Wall slabs are at least 2.5 m long and stay in the ruin mesh.
		var narrow := maxf(size.x, size.z) < 2.15
		if size.y > 1.1 and narrow:
			replaced.append(span)
		else:
			keep.append_array(island)
	if replaced.is_empty():
		return 0
	var center := Vector3.ZERO
	if not keep.is_empty():
		var acc := Vector3.ZERO
		var n := 0
		for t in keep:
			acc += _centroid(t)
			n += 1
		center = acc / float(n)
	if keep.is_empty():
		mesh_node.visible = false
	else:
		mesh_node.mesh = _rebuild(keep)
	var body := mesh_node.get_parent().get_node_or_null(String(mesh_node.name) + "Body/Shape") as CollisionShape3D
	if body != null:
		if keep.is_empty():
			body.disabled = true
		else:
			body.shape = mesh_node.mesh.create_trimesh_shape()
	var mat := mesh_node.material_override
	var placed := 0
	for span in replaced:
		var mn: Vector3 = span.mn
		var mx: Vector3 = span.mx
		var foot := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
		foot = mesh_node.global_transform * foot
		var height: float = (span.mx as Vector3).y - (span.mn as Vector3).y
		var yaw := fposmod(foot.x * 1.7 + foot.z * 0.37, TAU)
		_place_menhir(mesh_node.get_parent(), foot, yaw, height, mat, center if face_center else Vector3.ZERO, face_center)
		placed += 1
	return placed


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


static func _quiet_glass(model: Node) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var name := String(node.name)
		if name.begins_with("Glass") or name.begins_with("Ember"):
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _move_light(model: Node, light: OmniLight3D) -> void:
	if light == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("Ember"):
			var mi := node as MeshInstance3D
			light.global_position = mi.global_transform * mi.get_aabb().get_center()
			return


static func _triangles(mesh: Mesh) -> Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tris: Array = []
	if idx.is_empty():
		for i in range(0, verts.size() - 2, 3):
			tris.append([verts[i], verts[i + 1], verts[i + 2]])
	else:
		for i in range(0, idx.size() - 2, 3):
			tris.append([verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]]])
	return tris


static func _islands(tris: Array, cell := 50.0) -> Array:
	var parent: Array = []
	parent.resize(tris.size())
	for i in tris.size():
		parent[i] = i
	var buckets := {}
	for i in tris.size():
		for v in tris[i]:
			var key := Vector3i(roundi(v.x * cell), roundi(v.y * cell), roundi(v.z * cell))
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append(i)
	for key in buckets:
		var ids: Array = buckets[key]
		for j in range(1, ids.size()):
			_union(parent, ids[0], ids[j])
	var groups := {}
	for i in tris.size():
		var root := _find(parent, i)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(tris[i])
	return groups.values()


static func _find(parent: Array, i: int) -> int:
	while int(parent[i]) != i:
		parent[i] = parent[int(parent[i])]
		i = int(parent[i])
	return i


static func _union(parent: Array, a: int, b: int) -> void:
	a = _find(parent, a)
	b = _find(parent, b)
	if a != b:
		parent[b] = a


static func _span(tris: Array) -> Dictionary:
	var mn := Vector3(1.0e9, 1.0e9, 1.0e9)
	var mx := Vector3(-1.0e9, -1.0e9, -1.0e9)
	for t in tris:
		for v in t:
			mn = mn.min(v)
			mx = mx.max(v)
	return {"mn": mn, "mx": mx}


static func _centroid(tri: Array) -> Vector3:
	return (tri[0] + tri[1] + tri[2]) / 3.0


static func _rebuild(tris: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in tris:
		st.add_vertex(t[0])
		st.add_vertex(t[1])
		st.add_vertex(t[2])
	st.generate_normals()
	return st.commit()


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

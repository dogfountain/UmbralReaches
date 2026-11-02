class_name DemoDress
extends RefCounted
## Replaces the demo stair boxes, the sphere boulders, and adds path lanterns.
## The walk ramp and the boulder trimesh stay; only the visible meshes change.

const Dress := preload("res://core/world/dressed_props.gd")
const LANTERN := "res://art/models/lantern.glb"
const STEP := "res://art/models/stair_step.glb"
const COLUMN := "res://art/models/stair_column.glb"
const PLATFORM := "res://art/models/stair_platform.glb"
const ROCK_A := "res://art/models/rock_a.glb"
const ROCK_B := "res://art/models/rock_b.glb"

const RUN := 1.1
const RISE := 0.42
const BREAK_AT := 30
const LANDING := 3.0
const WIDTH := 5.0


static func dress(root: Node) -> void:
	if not ResourceLoader.exists(STEP) or not ResourceLoader.exists(ROCK_A):
		return
	var stair := root.find_child("Stair", true, false) as MeshInstance3D
	var boulders := root.find_child("Boulders", true, false) as MeshInstance3D
	var steps := 0
	var rocks := 0
	if stair != null and not stair.has_meta("demo_dressed"):
		stair.set_meta("demo_dressed", true)
		steps = _dress_stair(stair)
		if root.find_child("Lanterns", true, false) == null and ResourceLoader.exists(LANTERN):
			_lanterns(stair.get_parent())
		if boulders != null and not boulders.has_meta("demo_dressed"):
			boulders.set_meta("demo_dressed", true)
			rocks = _dress_boulders(boulders)
	if steps > 0 or rocks > 0:
		print("DEMO stair=%d rocks=%d" % [steps, rocks])


static func _dress_stair(mesh_node: MeshInstance3D) -> int:
	var tris: Array = Dress._triangles(mesh_node.mesh)
	var islands: Array = Dress._islands(tris, 100.0)
	var keep: Array = []
	var stone := mesh_node.material_override
	var placed := 0
	var step_scene := load(STEP) as PackedScene
	var column_scene := load(COLUMN) as PackedScene
	var platform_scene := load(PLATFORM) as PackedScene
	var rock_scene := load(ROCK_A) as PackedScene
	for island in islands:
		var span: Dictionary = Dress._span(island)
		var size: Vector3 = span.mx - span.mn
		var scene: PackedScene = null
		if size.y > 15.0:
			scene = column_scene
		elif size.x > 8.0 and size.z > 8.0 and size.y < 3.0:
			scene = platform_scene
		elif size.x > 3.2 and size.y < 1.3 and size.z < 5.5:
			scene = step_scene
		elif size.y > 1.15 and maxf(size.x, size.z) < 2.4:
			scene = column_scene
		elif size.y < 1.3 and size.x < 1.6:
			scene = rock_scene
		if scene == null:
			keep.append_array(island)
			continue
		_fit(mesh_node, scene, span.mn, span.mx, stone)
		placed += 1
	mesh_node.mesh = Dress._rebuild(keep) if not keep.is_empty() else ArrayMesh.new()
	_merge_into(mesh_node)
	return placed


static func _dress_boulders(mesh_node: MeshInstance3D) -> int:
	var tris: Array = Dress._triangles(mesh_node.mesh)
	var islands: Array = Dress._islands(tris, 100.0)
	var rock := mesh_node.material_override
	var a := load(ROCK_A) as PackedScene
	var b := load(ROCK_B) as PackedScene
	var placed := 0
	for island in islands:
		var span: Dictionary = Dress._span(island)
		var size: Vector3 = span.mx - span.mn
		if size.length() < 0.4:
			continue
		_fit(mesh_node, a if placed % 2 == 0 else b, span.mn, span.mx, rock)
		placed += 1
	mesh_node.mesh = ArrayMesh.new()
	_merge_into(mesh_node)
	return placed


static func _fit(parent: Node3D, scene: PackedScene, mn: Vector3, mx: Vector3, mat: Material) -> void:
	var model := scene.instantiate() as Node3D
	model.name = "Dressed%d" % parent.get_child_count()
	parent.add_child(model)
	var box := _aabb(model)
	var have := box.size
	var want := mx - mn
	var scale := Vector3(
		want.x / maxf(have.x, 0.001),
		want.y / maxf(have.y, 0.001),
		want.z / maxf(have.z, 0.001)
	)
	model.scale = scale
	var center := (mn + mx) * 0.5
	var local := box.get_center()
	model.position = center - Vector3(local.x * scale.x, local.y * scale.y, local.z * scale.z)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = mat
	if model is MeshInstance3D:
		(model as MeshInstance3D).material_override = mat


static func _merge_into(host: MeshInstance3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dressed: Array = []
	for child in host.get_children():
		if String(child.name).begins_with("Dressed"):
			dressed.append(child)
	var any := false
	for child in dressed:
		var nodes: Array = []
		if child is MeshInstance3D:
			nodes.append(child)
		nodes.append_array(child.find_children("*", "MeshInstance3D", true, false))
		for node in nodes:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var xf := _to_root(mi, host)
			var order: PackedInt32Array = idx if not idx.is_empty() else _range(verts.size())
			for i in order.size():
				var v := order[i]
				if v < norms.size():
					st.set_normal((xf.basis * norms[v]).normalized())
				st.add_vertex(xf * verts[v])
			any = true
		host.remove_child(child)
		child.free()
	if any:
		var built := st.commit()
		if host.mesh != null and host.mesh.get_surface_count() > 0:
			var prior := host.mesh
			var merged := ArrayMesh.new()
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prior.surface_get_arrays(0))
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built.surface_get_arrays(0))
			host.mesh = merged
		else:
			host.mesh = built


static func _range(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = i
	return out


static func _aabb(model: Node) -> AABB:
	var list: Array = []
	if model is MeshInstance3D:
		list.append(model)
	list.append_array(model.find_children("*", "MeshInstance3D", true, false))
	var acc := AABB()
	var started := false
	for node in list:
		var mi := node as MeshInstance3D
		var ab := _to_root(mi, model) * mi.get_aabb()
		if not started:
			acc = ab
			started = true
		else:
			acc = acc.merge(ab)
	return acc


static func _to_root(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


static func _lanterns(zone: Node) -> void:
	var holder := Node3D.new()
	holder.name = "Lanterns"
	zone.add_child(holder)
	var scene := load(LANTERN) as PackedScene
	var spots: Array[Vector2i] = [
		Vector2i(2, -1),
		Vector2i(16, 1),
		Vector2i(29, -1),
		Vector2i(52, 1),
	]
	for n in spots.size():
		var spot: Vector2i = spots[n]
		var lamp := Node3D.new()
		lamp.name = "Lamp%d" % n
		holder.add_child(lamp)
		var depth := RUN
		lamp.position = Vector3(
			float(spot.y) * (WIDTH * 0.5 - 0.45),
			_top_y(spot.x),
			_z_front(spot.x) - depth * 0.5
		)
		var model := scene.instantiate()
		model.name = "DressedLantern"
		lamp.add_child(model)
		var inward := Vector3(-signf(lamp.position.x), 0.0, 0.0)
		lamp.basis = Basis.looking_at(-inward, Vector3.UP)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if String(mi.name).begins_with("Glass") or String(mi.name).begins_with("Ember"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.70, 0.28)
		light.light_energy = 1.0
		light.omni_range = 5.5
		light.shadow_enabled = false
		lamp.add_child(light)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with("Ember"):
				var ember := node as MeshInstance3D
				light.position = _to_root(ember, lamp) * ember.get_aabb().get_center()
				break


static func _z_front(i: int) -> float:
	return -float(i) * RUN - (LANDING if i >= BREAK_AT else 0.0)


static func _top_y(i: int) -> float:
	return float(i + 1) * RISE

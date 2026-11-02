extends RefCounted
## Fail-loud helpers. Callers must not swallow a null from these.

static func ok(cond: bool, msg: String) -> bool:
	if cond:
		return true
	push_error(msg)
	return false


static func res(path: String, type: Variant = null) -> Resource:
	if path == "":
		push_error("Check.res empty path")
		return null
	if not ResourceLoader.exists(path):
		push_error("Check.res missing %s" % path)
		return null
	var r := load(path)
	if r == null:
		push_error("Check.res load null %s" % path)
		return null
	if type != null and not is_instance_of(r, type):
		push_error("Check.res %s is %s, wanted %s" % [path, r.get_class(), type])
		return null
	return r


static func scene(path: String) -> Node:
	var packed := res(path, PackedScene) as PackedScene
	if packed == null:
		return null
	var n := packed.instantiate()
	if n == null:
		push_error("Check.scene instantiate null %s" % path)
		return null
	return n


static func mesh_count(node: Node) -> int:
	if node == null:
		return 0
	var n := 0
	if node is MeshInstance3D:
		n += 1
	n += node.find_children("*", "MeshInstance3D", true, false).size()
	return n


static func attach_glb(parent: Node, path: String, n_name: String) -> Node:
	if parent == null:
		push_error("Check.attach_glb parent null %s" % path)
		return null
	var n := scene(path)
	if n == null:
		return null
	n.name = n_name
	parent.add_child(n)
	if mesh_count(n) == 0:
		push_error("Check.attach_glb no MeshInstance3D in %s" % path)
		return null
	return n


static func shader_set(sm: ShaderMaterial, key: String, value: Variant) -> bool:
	if sm == null:
		push_error("Check.shader_set null material %s" % key)
		return false
	if sm.shader == null:
		push_error("Check.shader_set no shader %s" % key)
		return false
	sm.set_shader_parameter(key, value)
	var got: Variant = sm.get_shader_parameter(key)
	if not _near(got, value):
		push_error("Check.shader_set %s wrote %s read %s" % [key, str(value), str(got)])
		return false
	return true


static func vec3_of(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Color:
		var c: Color = v
		return Vector3(c.r, c.g, c.b)
	return Vector3(NAN, NAN, NAN)


static func _near(a: Variant, b: Variant) -> bool:
	if a is Color or a is Vector3 or b is Color or b is Vector3:
		var va := vec3_of(a)
		var vb := vec3_of(b)
		if is_nan(va.x) or is_nan(vb.x):
			return false
		return va.distance_to(vb) <= 0.04
	return a == b

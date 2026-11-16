extends RefCounted
## Static props merged into fewer draws with nothing seen changing: the plain MeshInstance3D children of one
## parent that share a material, shadow mode, layers and draw range become one mesh (one per surface
## format), their transforms baked in. Positions go through the child's transform, normals through its
## inverse transpose and tangents through its basis (what the shader did per instance), so the pixels
## are the same; only the draw count drops.
## Left alone: children with a script, children of their own, a skeleton, instance shader parameters,
## no material_override, a hidden child, or a group of one.
## Load by path (no class_name): const MeshMerge := preload("res://core/util/mesh_merge.gd")


## Merge `parent`'s eligible children. Returns the draws saved.
static func merge_children(parent: Node3D) -> int:
	var groups := {}
	for c in parent.get_children():
		var mi := c as MeshInstance3D
		if not _eligible(mi):
			continue
		var key := _key(mi)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var saved := 0
	for key: String in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var first := list[0] as MeshInstance3D
		var mesh := bake(list, parent)
		if mesh == null:
			continue
		var out := MeshInstance3D.new()
		out.name = _plural(String(first.name))
		out.mesh = mesh
		out.material_override = mat_of(first)
		out.cast_shadow = first.cast_shadow
		out.layers = first.layers
		out.gi_mode = first.gi_mode
		out.visibility_range_begin = first.visibility_range_begin
		out.visibility_range_begin_margin = first.visibility_range_begin_margin
		out.visibility_range_end = first.visibility_range_end
		out.visibility_range_end_margin = first.visibility_range_end_margin
		out.visibility_range_fade_mode = first.visibility_range_fade_mode
		out.extra_cull_margin = first.extra_cull_margin
		for g in first.get_groups():
			out.add_to_group(g)
		for mi: MeshInstance3D in list:
			parent.remove_child(mi)
			mi.queue_free()
		parent.add_child(out)
		saved += list.size() - 1
	return saved


static func _eligible(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null or mi.get_script() != null or mi.get_child_count() > 0 or not mi.visible:
		return false
	if mi.skin != null or mi.mesh.get_surface_count() != 1:
		return false
	if not (mi.mesh is PrimitiveMesh):                # (a box / sphere / cylinder is always triangles; it reports no type)
		if mi.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		const OTHER := Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 \
			| Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3
		if mi.mesh.surface_get_format(0) & OTHER:
			return false
	var mat := mat_of(mi)
	if mat == null or not safe_material(mat):
		return false
	if uses_model_normal(mat):
		var sc := mi.global_basis.get_scale()
		if not (is_equal_approx(sc.x, sc.y) and is_equal_approx(sc.y, sc.z)):
			return false
	if mi.has_meta(&"fade_end"):
		return false
	return true


## The material the mesh draws with: its override, else its surface's.
static func mat_of(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	if mi.get_surface_override_material(0) != null:
		return mi.get_surface_override_material(0)
	return mi.mesh.surface_get_material(0)


static func _key(mi: MeshInstance3D) -> String:
	var a: Array = _arrays(mi.mesh)
	var fmt := 0
	for k in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		fmt = fmt * 2 + (1 if a[k] != null else 0)
	return "%d|%d|%d|%d|%.3f|%.3f|%.3f|%.3f|%d|%.3f|%d|%s" % [mat_of(mi).get_instance_id(), mi.cast_shadow, mi.layers, mi.gi_mode,
		mi.visibility_range_begin, mi.visibility_range_begin_margin, mi.visibility_range_end, mi.visibility_range_end_margin,
		mi.visibility_range_fade_mode, mi.extra_cull_margin, fmt, str(mi.get_groups())]


static var _arr_cache := {}


static func _arrays(m: Mesh) -> Array:
	if _arr_cache.has(m):
		return _arr_cache[m]
	var a: Array = (m as PrimitiveMesh).get_mesh_arrays() if m is PrimitiveMesh else m.surface_get_arrays(0)
	_arr_cache[m] = a
	return a


## "Stem3" -> "Stems", "Rock" -> "Rocks" (the name rules in atmosphere.gd read words, not numbers).
static func _plural(n: String) -> String:
	var i := n.length()
	while i > 0 and n[i - 1] >= "0" and n[i - 1] <= "9":
		i -= 1
	var base := n.substr(0, i) if i > 0 else n
	return base + "s" if not base.ends_with("s") else base


## One ArrayMesh from single-surface meshes in `parent`'s space.
static func bake(list: Array, parent: Node3D, origin := Transform3D.IDENTITY) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tan := PackedFloat32Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var first: Array = _arrays((list[0] as MeshInstance3D).mesh)
	var has_n: bool = first[Mesh.ARRAY_NORMAL] != null
	var has_t: bool = first[Mesh.ARRAY_TANGENT] != null
	var has_c: bool = first[Mesh.ARRAY_COLOR] != null
	var has_uv: bool = first[Mesh.ARRAY_TEX_UV] != null
	var has_uv2: bool = first[Mesh.ARRAY_TEX_UV2] != null
	for mi: MeshInstance3D in list:
		var a: Array = _arrays(mi.mesh)
		var xf: Transform3D = origin.affine_inverse() * (mi.transform if mi.get_parent() == parent else parent.global_transform.affine_inverse() * mi.global_transform)
		var nb := xf.basis.inverse().transposed()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if (a[Mesh.ARRAY_NORMAL] != null) != has_n or (a[Mesh.ARRAY_TANGENT] != null) != has_t or (a[Mesh.ARRAY_COLOR] != null) != has_c \
				or (a[Mesh.ARRAY_TEX_UV] != null) != has_uv or (a[Mesh.ARRAY_TEX_UV2] != null) != has_uv2:
			return null
		var base := pos.size()
		for p in v:
			pos.append(xf * p)
		if has_n:
			for n: Vector3 in a[Mesh.ARRAY_NORMAL]:
				nrm.append((nb * n).normalized())
		if has_t:
			var t: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
			for k in range(0, t.size(), 4):
				var tv := (xf.basis * Vector3(t[k], t[k + 1], t[k + 2])).normalized()
				tan.append_array([tv.x, tv.y, tv.z, t[k + 3] * (1.0 if xf.basis.determinant() >= 0.0 else -1.0)])
		if has_c:
			col.append_array(a[Mesh.ARRAY_COLOR])
		if has_uv:
			uv.append_array(a[Mesh.ARRAY_TEX_UV])
		if has_uv2:
			uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		var ix: Variant = a[Mesh.ARRAY_INDEX]
		var flip := xf.basis.determinant() < 0.0
		if ix == null:
			for k in range(0, v.size(), 3):
				if flip:
					idx.append_array([base + k, base + k + 2, base + k + 1])
				else:
					idx.append_array([base + k, base + k + 1, base + k + 2])
		else:
			var ii: PackedInt32Array = ix
			for k in range(0, ii.size(), 3):
				if flip:
					idx.append_array([base + ii[k], base + ii[k + 2], base + ii[k + 1]])
				else:
					idx.append_array([base + ii[k], base + ii[k + 1], base + ii[k + 2]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	if has_n:
		arr[Mesh.ARRAY_NORMAL] = nrm
	if has_t:
		arr[Mesh.ARRAY_TANGENT] = tan
	if has_c:
		arr[Mesh.ARRAY_COLOR] = col
	if has_uv:
		arr[Mesh.ARRAY_TEX_UV] = uv
	if has_uv2:
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## A material whose look does not depend on the instance: opaque (sorted transparency would reorder), no
## billboards, no object-space triplanar, no per-object dither fade; a shader that never reads the node's
## position or matrix, instance uniforms, or alpha.
static func safe_material(m: Material) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			return false
		if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or b.grow or b.proximity_fade_enabled:
			return false
		if (b.uv1_triplanar and not b.uv1_world_triplanar) or (b.uv2_triplanar and not b.uv2_world_triplanar):
			return false
		if b.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER or b.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA:
			return false
		if b.next_pass != null:
			return false
		return true
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null or (m as ShaderMaterial).next_pass != null:
			return false
		if _shader_ok.has(sh):
			return bool(_shader_ok[sh])
		var code := _strip_world(sh.code)
		var ok := true
		for word in BAD_WORDS:
			if code.contains(word):
				ok = false
				break
		_shader_ok[sh] = ok
		return ok
	return false


static var _shader_ok := {}
const BAD_WORDS := ["MODEL_MATRIX", "NODE_POSITION", "INSTANCE", "instance uniform", "ALPHA", "MODELVIEW", "MODEL_NORMAL",
	"OBJECT", "#include", "skip_vertex_transform", "world_vertex_coords"]


## A shader's code without the world-space transforms of the vertex and normal (MODEL_MATRIX * vec4(VERTEX, 1.0),
## MODEL_MATRIX * vec4(NORMAL, 0.0)): a merged mesh gives the same world values (its pieces are uniformly
## scaled: uses_model_normal() pieces are checked for that).
static func _strip_world(code: String) -> String:
	var c := code.replace(" ", "")
	c = c.replace("MODEL_MATRIX*vec4(VERTEX,1.0)", "W").replace("MODEL_MATRIX*vec4(NORMAL,0.0)", "W")
	return c.replace("instanceuniform", "instance uniform")


## Does the shader take the normal through MODEL_MATRIX (right only under uniform scale)?
static func uses_model_normal(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null \
		and (m as ShaderMaterial).shader.code.replace(" ", "").contains("MODEL_MATRIX*vec4(NORMAL,0.0)")


static func _mat_why(m: Material) -> String:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "std transparency %d" % b.transparency
		if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED: return "std billboard"
		if b.grow: return "std grow"
		if b.proximity_fade_enabled: return "std proximity"
		if (b.uv1_triplanar and not b.uv1_world_triplanar) or (b.uv2_triplanar and not b.uv2_world_triplanar): return "std triplanar"
		if b.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return "std distance fade %d" % b.distance_fade_mode
		if b.next_pass != null: return "std next_pass"
		return "std ?"
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null: return "shader null"
		if (m as ShaderMaterial).next_pass != null: return "shader next_pass"
		var code := _strip_world(sh.code)
		for word in BAD_WORDS:
			if code.contains(word):
				return "shader %s: %s" % [String(sh.resource_path).get_file(), word]
		return "shader ?"
	return m.get_class()
const CELL := 6.0                   ## ranged pieces merge within a cell this size: each still fades within ~4 m of where it did
const CELL_FAR := 24.0              ## pieces with no range (never fade): only frustum culling coarsens
const MAX_TRIS := 3000              ## a heavier mesh keeps its own draw (and its LODs)


## The world pass (Atmosphere.post_build, after ranges and shadows are final): under each of `roots`, every
## host's mergeable children are merged by material, shadow, range, layers and cell. A mesh any script
## holds (a property, an array or dictionary in one) or that is in a group is left as it is: something
## may move, hide or swap it. Returns [meshes before, draws after].
static func merge_world(root: Node, roots: Array) -> Vector2i:
	var cands := {}
	for rn: String in roots:
		var r := root.get_node_or_null(rn)
		if r == null:
			continue
		for n in r.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if not _eligible(mi) or mi.get_parent() is not Node3D or not _plain_groups(mi) or mi.get_meta_list().has(&"far_detail"):
				continue
			if _tris(mi.mesh) > MAX_TRIS:
				continue
			cands[mi.get_instance_id()] = mi
	if "--merge-why" in OS.get_cmdline_user_args():
		var why := {}
		for rn: String in roots:
			var r := root.get_node_or_null(rn)
			if r == null:
				continue
			for n in r.find_children("*", "MeshInstance3D", true, false):
				var w := _why(n as MeshInstance3D)
				why[w] = int(why.get(w, 0)) + 1
		print("MERGE why: ", why)
	if cands.is_empty():
		return Vector2i.ZERO
	var n0 := cands.size()
	_drop_held(root.get_tree().root, cands)
	if "--merge-why" in OS.get_cmdline_user_args():
		print("MERGE held by scripts: %d of %d" % [n0 - cands.size(), n0])
	var groups := {}
	for id: int in cands:
		var mi := cands[id] as MeshInstance3D
		var c := mi.transform * mi.mesh.get_aabb().get_center()
		var cs := CELL if (mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0) else CELL_FAR
		var cell := Vector3i(floori(c.x / cs), floori(c.y / cs), floori(c.z / cs))
		var key := "%d|%s|%s" % [mi.get_parent().get_instance_id(), _key(mi), cell]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var before := 0
	var after := 0
	for key: String in groups:
		var list: Array = groups[key]
		before += list.size()
		if list.size() < 2:
			after += 1
			continue
		var parent := (list[0] as MeshInstance3D).get_parent() as Node3D
		var ctr := Vector3.ZERO
		for mi: MeshInstance3D in list:
			ctr += mi.transform * mi.mesh.get_aabb().get_center()
		ctr /= float(list.size())
		var origin := Transform3D(Basis.IDENTITY, ctr)
		var mesh := bake(list, parent, origin)
		if mesh == null:
			after += list.size()
			continue
		var first := list[0] as MeshInstance3D
		var out := MeshInstance3D.new()
		out.name = _plural(String(first.name))
		out.mesh = mesh
		out.transform = origin
		out.material_override = mat_of(first)
		out.cast_shadow = first.cast_shadow
		out.layers = first.layers
		out.gi_mode = first.gi_mode
		out.lod_bias = first.lod_bias
		out.visibility_range_begin = first.visibility_range_begin
		out.visibility_range_begin_margin = first.visibility_range_begin_margin
		out.visibility_range_end = first.visibility_range_end
		out.visibility_range_end_margin = first.visibility_range_end_margin
		out.visibility_range_fade_mode = first.visibility_range_fade_mode
		out.extra_cull_margin = first.extra_cull_margin
		out.ignore_occlusion_culling = first.ignore_occlusion_culling
		for m in first.get_meta_list():
			out.set_meta(m, first.get_meta(m))       # the fade guard's range_k / fade_orig: already applied
		out.set_meta(&"merged", list.size())
		for mi: MeshInstance3D in list:
			parent.remove_child(mi)
			mi.queue_free()
		parent.add_child(out)
		after += 1
	return Vector2i(before, after)


static func _why(mi: MeshInstance3D) -> String:
	if mi.mesh == null: return "no mesh"
	if mi.get_script() != null: return "script"
	if mi.get_child_count() > 0: return "children"
	if not mi.visible: return "hidden"
	if mi.mesh.get_surface_count() != 1: return "surfaces"
	var mat := mat_of(mi)
	if mat == null: return "no material"
	if not safe_material(mat): return "material " + _mat_why(mat)
	if not _plain_groups(mi): return "groups " + str(mi.get_groups())
	if _tris(mi.mesh) > MAX_TRIS: return "tris"
	if not _eligible(mi): return "other"
	return "ok"


## Only the render passes' own groups (a mesh some system finds by group is left as it is).
static func _plain_groups(mi: Node) -> bool:
	for g in mi.get_groups():
		if not String(g).begins_with("cull_"):
			return false
	return true


static func _tris(m: Mesh) -> int:
	var am := m as ArrayMesh
	if am == null:
		return 0                                  # a primitive (box, sphere): small
	var n := am.surface_get_array_index_len(0)
	return (n if n > 0 else am.surface_get_array_len(0)) / 3


## Candidates some script holds are not merged: every scripted node's own variables (an Object, or one in
## an Array / Dictionary, two levels deep).
static func _drop_held(top: Node, cands: Dictionary) -> void:
	var by := {}
	var vars_of := {}                                 # Script -> the names of its variables that can hold an Object
	for n in top.find_children("*", "", true, false):
		var sc: Variant = n.get_script()
		if sc == null or String(n.name) == "FadeGuard":
			continue                                  # (the fade guard tracks every instance; a freed one leaves it)
		if not vars_of.has(sc):
			vars_of[sc] = _object_vars(n)
		var before := cands.size()
		for v: StringName in vars_of[sc]:
			_drop_in(n.get(v), cands, 0)
		if before != cands.size():
			var k := String((n.get_script() as Script).resource_path).get_file()
			by[k] = int(by.get(k, 0)) + before - cands.size()
	if "--merge-why" in OS.get_cmdline_user_args():
		print("MERGE held by: ", by)


## A script's variables that can hold an Object (untyped, Object, Array, Dictionary), looked up once per script:
## the scan used to walk every scripted node's whole property list (~1.4 s of the post-build pass, perf critique
## 16 Nov); ints, floats, strings, vectors and packed arrays can hold no mesh.
static func _object_vars(n: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	for p in n.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var t := int(p.type)
		if t == TYPE_NIL or t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY:
			out.append(StringName(p.name))
	return out


static func _drop_in(v: Variant, cands: Dictionary, depth: int) -> void:
	# typeof + is_instance_valid(Variant): `v is Object` / cast on a freed instance errors
	match typeof(v):
		TYPE_OBJECT:
			if is_instance_valid(v):
				cands.erase((v as Object).get_instance_id())
		TYPE_ARRAY:
			if depth < 2:
				for e: Variant in (v as Array):
					_drop_in(e, cands, depth + 1)
		TYPE_DICTIONARY:
			if depth < 2:
				var d: Dictionary = v
				for k: Variant in d:
					_drop_in(k, cands, depth + 1)
					_drop_in(d[k], cands, depth + 1)

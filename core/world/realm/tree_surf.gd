extends RefCounted
## One mesh surface being built by TreeGen (vertex arrays, material, commit), split from tree_gen.gd.

var v := PackedVector3Array()
var n := PackedVector3Array()
var t := PackedFloat32Array()
var uv := PackedVector2Array()
var uv2 := PackedVector2Array()
var c := PackedColorArray()
var i := PackedInt32Array()
var mat: Material

func add(p: Vector3, nn: Vector3, u: Vector2, col: Color, u2 := Vector2.ZERO, tg := Vector3.RIGHT) -> int:
	v.append(p)
	n.append(nn)
	uv.append(u)
	uv2.append(u2)
	c.append(col)
	t.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, 1.0]))
	return v.size() - 1

func tri(a: int, b: int, cc: int) -> void:
	i.append_array(PackedInt32Array([a, b, cc]))

func commit_to(m: ArrayMesh, tangents: bool) -> void:
	if i.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	if tangents:
		arr[Mesh.ARRAY_TANGENT] = t
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = i
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)

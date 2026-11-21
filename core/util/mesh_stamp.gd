extends RefCounted
## Copies of a few modelled meshes stamped into one ArrayMesh (a ring of wall modules, a run of stair blocks): each part's
## transform is baked into its vertices and normals, its colours and UVs carried over. Used at build time behind the cover
## (and cached by the caller through GenCache), never per frame.
## Load by path (no class_name): const MeshStamp := preload("res://core/util/mesh_stamp.gd")


## `parts` = [[Mesh, Transform3D], ...] (surface 0 of each, one material). Returns null when nothing usable was given.
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var has_col := false
	for pt: Array in parts:
		var m := pt[0] as Mesh
		if m == null or m.get_surface_count() == 0:
			continue
		var xf: Transform3D = pt[1]
		var a := m.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var u: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if ix.is_empty():
			ix.resize(v.size())
			for i in v.size():
				ix[i] = i
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in v.size():
			verts.append(xf * v[i])
			nrms.append((nb * n[i]).normalized() if i < n.size() else Vector3.UP)
			uvs.append(u[i] if i < u.size() else Vector2.ZERO)
			cols.append(c[i] if i < c.size() else Color.WHITE)
		has_col = has_col or not c.is_empty()
		var flip := xf.basis.determinant() < 0.0
		for i in range(0, ix.size(), 3):
			if flip:
				idx.append_array(PackedInt32Array([base + ix[i], base + ix[i + 2], base + ix[i + 1]]))
			else:
				idx.append_array(PackedInt32Array([base + ix[i], base + ix[i + 1], base + ix[i + 2]]))
	if verts.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if has_col:
		arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

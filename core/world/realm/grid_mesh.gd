extends RefCounted
## Regular-grid mesh helpers for RealmLand's terrain and horizon ring (no state). Load by path (no class_name):
##   const GridMesh := preload("res://core/world/realm/grid_mesh.gd")


## The normal at grid vertex (i, j) of heights `hs` (nx x nz, `step` apart), from its neighbours.
static func normal(hs: PackedFloat32Array, nx: int, nz: int, step: float, i: int, j: int) -> Vector3:
	var hl := hs[j * nx + maxi(i - 1, 0)]
	var hr := hs[j * nx + mini(i + 1, nx - 1)]
	var hd := hs[maxi(j - 1, 0) * nx + i]
	var hu := hs[mini(j + 1, nz - 1) * nx + i]
	var sx := step * float(mini(i + 1, nx - 1) - maxi(i - 1, 0))
	var sz := step * float(mini(j + 1, nz - 1) - maxi(j - 1, 0))
	return Vector3(-(hr - hl) / sx, 1.0, -(hu - hd) / sz).normalized()


## Two clockwise-from-above triangles per accepted cell (Godot's front face), same diagonal everywhere:
## [a, b, c, b, d, c] with a = (i, j), b = (i + 1, j), c = (i, j + 1), d = (i + 1, j + 1).
static func indices(nx: int, nz: int, accept: Callable) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			if not accept.call(i, j):
				continue
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	return idx


## Surface arrays for an ArrayMesh with positions, normals, a colour and two UV sets.
static func arrays(verts: PackedVector3Array, nrms: PackedVector3Array, cols: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = nrms
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_TEX_UV2] = uv2
	a[Mesh.ARRAY_INDEX] = idx
	return a


static func mesh(a: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## The triangles' corners in index order (a ConcavePolygonShape3D's faces).
static func faces(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var f := PackedVector3Array()
	f.resize(idx.size())
	for k in idx.size():
		f[k] = v[idx[k]]
	return f

extends RefCounted
## Vertex weathering for every modelled prop (the world pass: "grounded props"): when StoneProps first reads a glb
## (once per file per run, at build time), each part's vertex colours get what the Blender export does not have,
## so the props read as having stood in the weather and not as clean models:
##   - contact dirt at the foot: the lowest 0.55 m of the whole prop darkens to ~66 % (damp and splash, AO under it)
##   - undersides darken (a lintel's soffit, a table's underside, a cart's bed) to 72 %
##   - moss on the up faces: a cool green cast and 3 % lift on faces within ~35 degrees of up
## The prop materials already use vertex colour as albedo (WestKit.mat), so this costs nothing at runtime: no
## shader work, no texture, the same vertex count. Built meshes are new ArrayMeshes (the imported ones are left alone).
## No class_name: preload by path.

const FOOT := 0.55


## The lowest y of a set of meshes (a prop's parts share a frame).
static func foot_y(meshes: Array) -> float:
	var lo := INF
	for m: Variant in meshes:
		if m is Mesh:
			lo = minf(lo, (m as Mesh).get_aabb().position.y)
	return 0.0 if lo == INF else lo


static func bake(mesh: Mesh, foot: float) -> Mesh:
	if not (mesh is ArrayMesh) or mesh.get_surface_count() == 0:
		return mesh
	var src := mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var prim := src.surface_get_primitive_type(s)
		if vs.is_empty() or prim != Mesh.PRIMITIVE_TRIANGLES:
			out.add_surface_from_arrays(prim, arr)
			out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
			continue
		var ns := PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			ns = arr[Mesh.ARRAY_NORMAL]
		var cols := PackedColorArray()
		if arr[Mesh.ARRAY_COLOR] is PackedColorArray:
			cols = arr[Mesh.ARRAY_COLOR]
		if cols.size() != vs.size():
			cols = PackedColorArray()
			cols.resize(vs.size())
			cols.fill(Color(1.0, 1.0, 1.0, 1.0))
		for i in vs.size():
			var t := clampf((vs[i].y - foot) / FOOT, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			var k := lerpf(0.66, 1.0, t)
			var gr := 0.0
			if ns.size() == vs.size():
				if ns[i].y < -0.5:
					k *= 0.72
				gr = smoothstep(0.82, 0.96, ns[i].y)
			var c := cols[i]
			cols[i] = Color(c.r * k * (1.0 - 0.05 * gr), c.g * k * (1.0 + 0.03 * gr), c.b * k * (1.0 - 0.07 * gr), c.a)
		arr[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(prim, arr)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	return out

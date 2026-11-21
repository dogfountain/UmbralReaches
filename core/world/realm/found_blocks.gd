extends RefCounted
## The Lamplighters' Spire footing's look (polish, 20 Nov), moved out of realm_pois_east_marches.gd to keep that file under
## the lint ceiling. Load by path (no class_name): const FoundBlocks := preload("res://core/world/realm/found_blocks.gd")

const EastKit := preload("res://core/world/realm/east_works_kit.gd")
const M := "res://art/models/"
const FOUND := M + "found_block.glb"
const FOUND_N := 1.04                    ## the block's size (tools/blender/polish_blocks.py)


## The footing's look: each rim cell's column laid in courses of dressed blocks from its foot to the slab (a MultiMesh, one draw), the
## cells inside only the top course (the apron the tower stands on). Replaces the column of one plain box per cell.
static func build(holder: Node3D, xf: Transform3D, stack: Array) -> void:
	var ms: Array[Mesh] = []
	for nm: String in ["Block0", "Block1", "Block2"]:
		var m := EastKit.mesh(FOUND, nm)
		if m != null:
			ms.append(m)
	if ms.is_empty():
		return                                # not imported: no look (the colliders stand)
	var per: Array = []
	for _i in ms.size():
		per.append([])
	for e: Array in stack:
		var mid: Vector3 = e[0]
		var bottom: float = e[1]
		var top: float = e[2]
		var rim: bool = e[3]
		var sz: Vector2 = e[4]
		var lo := bottom if rim else maxf(bottom, top - FOUND_N)
		var count := maxi(1, ceili((top - lo) / FOUND_N - 0.05))
		var sy := (top - lo) / (float(count) * FOUND_N)
		var hsh := absi(hash(Vector3i((mid * 7.0).round())))
		for j in count:
			var pick := (hsh + j * 5 + j / 3) % ms.size()
			var yaw := float(((hsh >> 3) + j * 3) % 4) * PI * 0.5 + float((hsh + j) % 7 - 3) * 0.006
			var b := xf.basis * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sz.x / FOUND_N + 0.01, sy, sz.y / FOUND_N + 0.01))
			var at := Vector3(mid.x, lo + (float(j) + 0.5) * sy * FOUND_N, mid.z) + xf.basis * Vector3(float((hsh + j * 11) % 5 - 2) * 0.004, 0.0, float((hsh * 3 + j) % 5 - 2) * 0.004)
			(per[pick] as Array).append(Transform3D(b, at))
	var mat := (OssKit.mat("stone") as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = mat.albedo_color * 1.7              # lifted like the tower above it: it stands in its shadow
	for i in ms.size():
		var xs: Array = per[i]
		if xs.is_empty():
			continue
		var mmi := OssKit.multimesh(ms[i], xs, mat, true)
		mmi.name = "Footing%d" % i
		holder.add_child(mmi)

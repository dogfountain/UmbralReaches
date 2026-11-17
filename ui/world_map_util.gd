extends RefCounted
## Pure helpers of the world map sheet (moved out of ui/world_map.gd to keep it under the line ceiling).
## Load by path (no class_name): const MapUtil := preload("res://ui/world_map_util.gd")


static func sorted_z(a: PackedVector3Array) -> PackedVector3Array:
	var arr: Array = Array(a)
	arr.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.y < q.y)
	return PackedVector3Array(arr)


static func blur(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var inv := 1.0 / float(2 * r + 1)
	for j in h:
		for i in w:
			var s := 0.0
			for k in range(-r, r + 1):
				s += a[j * w + clampi(i + k, 0, w - 1)]
			tmp[j * w + i] = s * inv
	for j in h:
		for i in w:
			var s2 := 0.0
			for k in range(-r, r + 1):
				s2 += tmp[clampi(j + k, 0, h - 1) * w + i]
			out[j * w + i] = s2 * inv
	return out

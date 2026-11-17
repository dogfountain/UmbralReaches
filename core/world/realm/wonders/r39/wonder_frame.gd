extends RefCounted
## A basis whose z axis runs along `dir` (the same as WK.frame, static, for helpers that have no kit). No class_name.

static func of(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var up := Vector3.UP if absf(z.y) < 0.97 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)

extends RefCounted
## Layered wear for Hearthward's people (the deeper-models pass), kept out of villager_rig.gd (a mesh builder, called at
## the end of its _body_v): see the function. No class_name: preload by path.

## Layered wear (the deeper-models pass): a belt with a brass buckle and a pouch (not on a coat, robe or dress, which have their
## own waist), sewn patches in a second cloth, a stitched yoke line across the shoulders . A private
## random stream keyed on the person's seed: their looks are unchanged and the same person always wears the same.
static func wear(r: Node, mb: Variant, cloth: Color, cloth2: Color, leather: Color, f: bool, girth: float, garment: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.cfg.get("seed", 1)) * 7919 + 17
	mb.bind(r.B_SPINE)
	if garment == "shirt" or garment == "":
		var y := r.P + 0.03 * r.k
		var loop := PackedVector3Array()
		for i in 25:
			var a := TAU * float(i) / 24.0
			var dir := Vector3(sin(a), 0.0, -cos(a))
			loop.append(Vector3(dir.x, 0.0, dir.z) * (r._env(dir, y, girth, f) + 0.012 * r.k) + Vector3(0.0, y, 0.0))
		mb.tube(loop, r._pf(_rep(0.011, 25), r.k), 5, leather.darkened(0.15), DwarfMesh.MAT_LEATHER, {"squash": Vector2(1.0, 1.6), "lumps": 0.0, "caps": false})
		mb.blob(Vector3(0.0, y, -(r._env(Vector3(0, 0, -1), y, girth, f) + 0.016 * r.k)), Vector3(0.022, 0.019, 0.006) * r.k, Basis.IDENTITY, r.BRASS.darkened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 5, "segs": 10})
		var pa := 1.05 if rng.randf() < 0.5 else -1.05
		var pdir := Vector3(sin(pa), 0.0, -cos(pa))
		var pp := Vector3(pdir.x, 0.0, pdir.z) * (r._env(pdir, y, girth, f) + 0.03 * r.k) + Vector3(0.0, y - 0.035 * r.k, 0.0)
		mb.blob(pp, Vector3(0.032, 0.04, 0.024) * r.k, Basis(Vector3.UP, -pa), leather.lightened(0.05), DwarfMesh.MAT_LEATHER, {"lumps": 0.08, "rings": 6, "segs": 10})
		mb.blob(pp + Vector3(0.0, 0.026 * r.k, 0.0), Vector3(0.034, 0.014, 0.026) * r.k, Basis(Vector3.UP, -pa), leather.darkened(0.1), DwarfMesh.MAT_LEATHER, {"lumps": 0.05, "rings": 4, "segs": 10})
	mb.bind(r.B_CHEST)
	var patch := cloth.lerp(cloth2, 0.6).lerp(Color(0.55, 0.5, 0.38), 0.3)
	for i in 2:
		if rng.randf() < 0.6:
			var py := (1.1 + 0.12 * rng.randf()) * r.k
			var px := (rng.randf_range(-0.07, 0.07))
			var pd := Vector3(px, 0.0, -0.2).normalized()
			var pr := r._env(pd, py, girth, f)
			mb.blob(Vector3(px * r.k, py, -pr - 0.004 * r.k), Vector3(0.026, 0.03, 0.004) * r.k, Basis.IDENTITY, patch, DwarfMesh.MAT_LINEN, {"lumps": 0.02, "rings": 4, "segs": 8})
	var yoke := PackedVector3Array()
	for i in 9:
		var u := lerpf(-0.12, 0.12, float(i) / 8.0)
		var yd := Vector3(u, 0.0, -0.2).normalized()
		yoke.append(Vector3(u * r.k, 1.2 * r.k - 0.012 * r.k * absf(u) * 4.0, -r._env(yd, 1.2 * r.k, girth, f) - 0.003 * r.k))
	mb.tube(yoke, r._pf(_rep(0.003, 9), r.k), 4, cloth.darkened(0.3), DwarfMesh.MAT_LINEN, {"lumps": 0.0})


static func _rep(v: float, n: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(v)
	return a

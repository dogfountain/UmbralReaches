extends RefCounted
## The Ossuary kit's bone and candle meshes (moved out of oss_kit.gd to keep it under the lint ceiling; OssKit caches them).
## Load by path (no class_name): const BoneMeshes := preload("res://world/areas/ossuary/oss_bone_meshes.gd")


static func build_skull(with_jaw: bool) -> ArrayMesh:
	var cm := CreatureMesh.new(77 if with_jaw else 79)
	var w := Color(1, 1, 1)
	var hole := Color(0.06, 0.045, 0.04)
	var tooth := Color(1.05, 1.0, 0.92)
	cm.blob(Vector3(0, 0.1, 0.015), Vector3(0.098, 0.094, 0.118), Basis.IDENTITY, w, 0.0, 0.04, 0.0, 7, 11)
	cm.blob(Vector3(0, 0.075, 0.075), Vector3(0.08, 0.072, 0.055), Basis.IDENTITY, w, 0.0, 0.04, 0.0, 5, 8)    # occiput
	cm.blob(Vector3(0, 0.083, -0.088), Vector3(0.088, 0.022, 0.03), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 8)   # brow ridge
	cm.blob(Vector3(0, 0.025, -0.084), Vector3(0.048, 0.034, 0.036), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 5, 8)  # maxilla
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.062, 0.04, -0.07), Vector3(0.03, 0.02, 0.036), Basis.IDENTITY, w, 0.0, 0.03, 0.0, 4, 6)  # cheekbone
		cm.blob(Vector3(s * 0.034, 0.058, -0.112), Vector3(0.026, 0.024, 0.018), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 4, 7)
		cm.blob(Vector3(s * 0.088, 0.07, 0.0), Vector3(0.012, 0.03, 0.03), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 3, 5)   # temple hollow
	cm.blob(Vector3(0, 0.035, -0.118), Vector3(0.012, 0.018, 0.01), Basis.IDENTITY, hole, 0.0, 0.0, 0.0, 3, 5)      # nasal
	for k in 6:
		var x := (float(k) - 2.5) * 0.011
		cm.blob(Vector3(x, -0.002, -0.106 + absf(x) * 0.5), Vector3(0.0055, 0.01, 0.006), Basis.IDENTITY, tooth, 0.0, 0.0, 0.0, 2, 4)
	if with_jaw:
		cm.tube(PackedVector3Array([Vector3(-0.052, 0.012, -0.02), Vector3(-0.047, -0.03, -0.068), Vector3(0, -0.042, -0.098), Vector3(0.047, -0.03, -0.068), Vector3(0.052, 0.012, -0.02)]),
			PackedFloat32Array([0.012, 0.015, 0.017, 0.015, 0.012]), 5, w, 0.0, 0.03)
		for k in 4:
			var x := (float(k) - 1.5) * 0.012
			cm.blob(Vector3(x, -0.016, -0.1 + absf(x) * 0.4), Vector3(0.005, 0.009, 0.005), Basis.IDENTITY, tooth, 0.0, 0.0, 0.0, 2, 4)
	return cm.commit()


static func build_femur() -> ArrayMesh:
	var cm := CreatureMesh.new(81)
	cm.tube(PackedVector3Array([Vector3(0, 0, -0.2), Vector3(0, 0.006, -0.06), Vector3(0, 0.004, 0.08), Vector3(0, 0, 0.2)]), PackedFloat32Array([0.02, 0.014, 0.014, 0.02]), 6, Color.WHITE, 0.0, 0.03)
	for s: float in [-1.0, 1.0]:
		cm.blob(Vector3(s * 0.017, -0.004, 0.215), Vector3(0.019, 0.021, 0.023), Basis.IDENTITY, Color.WHITE, 0.0, 0.04, 0.0, 4, 6)
	cm.tube(PackedVector3Array([Vector3(0, 0, -0.2), Vector3(0.022, 0.012, -0.225)]), PackedFloat32Array([0.016, 0.013]), 5)
	cm.blob(Vector3(0.03, 0.016, -0.232), Vector3(0.022, 0.022, 0.022), Basis.IDENTITY, Color.WHITE, 0.0, 0.02, 0.0, 4, 6)
	cm.blob(Vector3(-0.012, -0.006, -0.205), Vector3(0.016, 0.02, 0.02), Basis.IDENTITY, Color.WHITE, 0.0, 0.03, 0.0, 3, 5)
	return cm.commit()


static func build_rib() -> ArrayMesh:
	var cm := CreatureMesh.new(82)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 7:
		var a := float(i) / 6.0 * 2.2
		pts.append(Vector3(sin(a) * 0.17, 0.0, -cos(a) * 0.17 + 0.08))
		rad.append(lerpf(0.011, 0.006, float(i) / 6.0))
	cm.tube(pts, rad, 4, Color(0.95, 0.92, 0.88), 0.0, 0.02, 0.0, Vector2(1.0, 0.45))
	return cm.commit()


static func build_vertebra() -> ArrayMesh:
	var cm := CreatureMesh.new(83)
	cm.blob(Vector3.ZERO, Vector3(0.03, 0.022, 0.028), Basis.IDENTITY, Color.WHITE, 0.0, 0.05, 0.0, 4, 7)
	cm.tube(PackedVector3Array([Vector3(0, 0.0, 0.025), Vector3(0, 0.03, 0.06)]), PackedFloat32Array([0.009, 0.004]), 4)
	for s: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(s * 0.02, 0, 0.012), Vector3(s * 0.055, 0.006, 0.02)]), PackedFloat32Array([0.008, 0.004]), 4)
	return cm.commit()


static func build_candle(h: float, seed_n: int) -> ArrayMesh:
	var cm := CreatureMesh.new(seed_n)
	var wax := Color(1.0, 0.97, 0.9)
	var old := Color(0.92, 0.84, 0.66)
	cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0.002, h * 0.5, 0), Vector3(0, h - 0.008, 0)]), PackedFloat32Array([0.036, 0.034, 0.032]), 8, wax, 0.0, 0.025)
	cm.blob(Vector3(0, h - 0.006, 0), Vector3(0.036, 0.014, 0.036), Basis.IDENTITY, wax, 0.0, 0.18, 0.0, 3, 9)   # melted lip
	cm.blob(Vector3(0, h + 0.002, 0), Vector3(0.022, 0.006, 0.022), Basis.IDENTITY, old, 0.0, 0.0, 0.0, 2, 8)   # pool
	for k in 3:
		var a := TAU * float(k) / 3.0 + float(seed_n)
		var len := h * (0.25 + 0.2 * float(k))
		var o := Vector3(cos(a) * 0.033, h - 0.004, sin(a) * 0.033)
		cm.tube(PackedVector3Array([o, o + Vector3(cos(a) * 0.004, -len * 0.5, sin(a) * 0.004), o + Vector3(cos(a) * 0.006, -len, sin(a) * 0.006)]),
			PackedFloat32Array([0.011, 0.009, 0.007]), 4, old, 0.0, 0.0)
	cm.tube(PackedVector3Array([Vector3(0, h, 0), Vector3(0.004, h + 0.028, 0)]), PackedFloat32Array([0.003, 0.002]), 3, Color(0.04, 0.03, 0.03))
	return cm.commit()

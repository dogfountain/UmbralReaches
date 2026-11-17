extends RefCounted
## Lived-in detail for the code-built cottages (the deeper-models pass; core/world/realm/lore/cottage.gd calls `dress`
## for a whole cottage): sills, lintels and fixed shutters on every window, flower boxes, a lintel and a hung lantern at the
## door, a ridge cap along the roof, drip stones along the foot of the long walls, and a garden: a low fence of posts and
## rails with a gap at the door, a bed of turned soil with leaf tufts. All kit boxes at build time, none solid (none of it blocks). No class_name: preload by path.


static func dress(L: RefCounted, xf: Transform3D, w: float, d: float, bas: Basis, rng: RandomNumberGenerator, state: String) -> void:
	var k: OssKit = L.k
	var hw := w * 0.5
	var hd := d * 0.5
	var H := 2.6
	var ridge := H + hd * 0.95
	# windows: [local x, local z of the wall's outer face, outward sign]
	var wins := [[-hw + w * 0.72, -hd, -1.0], [hw - w * 0.3, hd, 1.0], [hw - w * 0.7, hd, 1.0]]
	for wn: Array in wins:
		var x: float = wn[0]
		var z: float = wn[1]
		var o: float = wn[2]
		k.box("lore_tstone", xf * Vector3(x, 0.93, z + o * 0.09), Vector3(1.05, 0.08, 0.22), bas, false, 0.9)
		k.box("lore_beam", xf * Vector3(x, 1.91, z + o * 0.04), Vector3(1.12, 0.13, 0.14), bas, false, 0.6)
		for s: float in [-1.0, 1.0]:
			k.box("lore_beam", xf * Vector3(x + s * 0.6, 1.4, z + o * 0.04), Vector3(0.36, 0.96, 0.045), bas, false, 0.62 + 0.06 * rng.randf())
		if rng.randf() < 0.6:
			k.box("lore_beam", xf * Vector3(x, 0.8, z + o * 0.15), Vector3(0.9, 0.16, 0.2), bas, false, 0.6)
			k.box("lore_leaf", xf * Vector3(x, 0.92, z + o * 0.15), Vector3(0.86, 0.1, 0.15), bas, false, 0.9)
	# the door: a lintel and a hung lantern on a bracket
	var dx := -hw + w * 0.36
	k.box("lore_beam", xf * Vector3(dx, 2.12, -hd - 0.05), Vector3(1.4, 0.16, 0.16), bas, false, 0.58)
	k.box("lore_beam", xf * Vector3(dx + 0.95, 2.0, -hd - 0.12), Vector3(0.05, 0.05, 0.3), bas, false, 0.6)
	k.box("iron", xf * Vector3(dx + 0.95, 1.86, -hd - 0.27), Vector3(0.025, 0.22, 0.025), bas, false, 0.6)
	k.box("glow" if state == "lit" else "iron", xf * Vector3(dx + 0.95, 1.7, -hd - 0.27), Vector3(0.16, 0.22, 0.16), bas, false, 1.0)
	# the roof: a ridge cap with a stone finial each end
	k.box("lore_beam", xf * Vector3(0, ridge + 0.04, 0), Vector3(w + 0.9, 0.13, 0.24), bas, false, 0.6)
	for s: float in [-1.0, 1.0]:
		k.box("lore_tstone", xf * Vector3(s * (hw + 0.42), ridge + 0.1, 0), Vector3(0.2, 0.2, 0.2), bas, false, 0.85)
	# drip stones along both long walls, a step of laid stones at the back
	for i in 7:
		var x := lerpf(-hw + 0.3, hw - 0.3, float(i) / 6.0)
		k.box("lore_rubble", xf * Vector3(x, 0.06, -hd - 0.3), Vector3(0.34 + 0.1 * rng.randf(), 0.12, 0.2), bas * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), false, 0.8)
		k.box("lore_rubble", xf * Vector3(x, 0.06, hd + 0.3), Vector3(0.34 + 0.1 * rng.randf(), 0.12, 0.2), bas * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), false, 0.8)
	# a garden in front: a fence of posts and two rails with a gap at the door, and a bed of turned soil
	var fz := -hd - 3.6
	for i in 9:
		var x := lerpf(-hw - 0.8, hw + 0.8, float(i) / 8.0)
		if absf(x - dx) < 0.9:
			continue
		k.box("lore_beam", xf * Vector3(x, 0.5, fz), Vector3(0.1, 1.0, 0.1), bas * Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)), false, 0.55 + 0.1 * rng.randf())
	for y: float in [0.42, 0.8]:
		k.box("lore_beam", xf * Vector3((-hw - 0.8 + dx - 0.9) * 0.5, y, fz), Vector3(maxf(dx - 0.9 + hw + 0.8, 0.1), 0.07, 0.07), bas, false, 0.55)
		k.box("lore_beam", xf * Vector3((dx + 0.9 + hw + 0.8) * 0.5, y, fz), Vector3(maxf(hw + 0.8 - (dx + 0.9), 0.1), 0.07, 0.07), bas, false, 0.55)
	k.box("lore_soil", xf * Vector3(-hw * 0.4, 0.04, fz + 1.4), Vector3(w * 0.5, 0.1, 1.5), bas, false, 0.8)
	for i in 6:
		k.box("lore_leaf", xf * Vector3(-hw * 0.4 + (float(i) - 2.5) * 0.4, 0.2, fz + 1.4 + rng.randf_range(-0.4, 0.4)), Vector3(0.22, 0.26, 0.2), bas * Basis(Vector3.UP, rng.randf() * TAU), false, 0.8 + 0.2 * rng.randf())

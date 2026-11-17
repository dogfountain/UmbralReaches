extends "res://core/enemy/beast_body.gd"
## The Thornwarden in the villagers' style, to its own design: a great stag-wolf of bark and thorn, long-legged, the
## head low on a long neck, a crown of briar antlers; thorns down its spine, moss on its back, a bramble whip of a tail;
## ember eyes; a heart-knot of roots glowing at its breast (its weak point: the "front" socket).
## No class_name (project rule): const ThornBody := preload("res://core/enemy/thorn_body.gd")

const BARK := Color(0.26, 0.19, 0.13)
const BARK_L := Color(0.38, 0.28, 0.19)
const THORN := Color(0.52, 0.46, 0.36)
const MOSS := Color(0.24, 0.31, 0.17)
const HEART := Color(1.0, 0.55, 0.18)
const WOOD := DMesh.MAT_WOOD


func _layout() -> void:
	# low and heavy in front: a hump of hackles over the shoulders, the head carried low and forward on a thick neck
	var fl := [Vector3(-0.21, 0.82, -0.34), Vector3(-0.22, 0.43, -0.3), Vector3(-0.22, 0.06, -0.36)]
	var bl := [Vector3(-0.2, 0.84, 0.5), Vector3(-0.23, 0.42, 0.66), Vector3(-0.23, 0.06, 0.52)]
	var m := func(v: Vector3) -> Vector3:
		return Vector3(-v.x, v.y, v.z)
	rests = [Vector3.ZERO, Vector3(0, 0.9, 0.45), Vector3(0, 0.96, 0.1), Vector3(0, 1.0, -0.22), Vector3(0, 1.02, -0.46),
		Vector3(0, 1.1, -0.8), Vector3(0, 1.04, -0.88), Vector3(0, 0.92, 0.62), Vector3(0, 0.84, 0.86), Vector3(0, 0.72, 1.06),
		fl[0], fl[1], m.call(fl[0]), m.call(fl[1]), bl[0], bl[1], m.call(bl[0]), m.call(bl[1])]
	feet = [fl[2], m.call(fl[2]), bl[2], m.call(bl[2])]
	glints.clear()
	for s: float in [-1.0, 1.0]:
		glints.append([B_HEAD, Vector3(s * 0.085, 1.17, -0.9), 0.02, EMBER])
	glints.append([B_CHEST, Vector3(0, 0.86, -0.5), 0.055, HEART])
	muzzle_at = [B_HEAD, Vector3(0, 1.06, -1.12)]


func _body_v(mb: Variant) -> void:
	# the trunk: heavy at the shoulders, narrow at the haunch, gnarled bark
	mb.bind_blend(B_HIPS, B_CHEST, rests[B_HIPS], rests[B_CHEST])
	mb.tube(PackedVector3Array([Vector3(0, 0.9, 0.66), Vector3(0, 0.93, 0.4), Vector3(0, 0.97, 0.1), Vector3(0, 1.0, -0.2), Vector3(0, 0.98, -0.44)]), _pf([0.19, 0.24, 0.28, 0.34, 0.3]), 20, BARK, WOOD, {"squash": Vector2(1.0, 1.12), "ref": Vector3.UP, "lumps": 0.2, "caps": true, "ripple": Vector2(0.05, 4.0)})
	mb.bind(B_CHEST)
	mb.blob(Vector3(0, 1.22, -0.24), Vector3(0.3, 0.16, 0.26), Basis.IDENTITY, BARK, WOOD, {"lumps": 0.22, "rings": 7, "segs": 14})
	mb.blob(Vector3(0, 1.32, -0.2), Vector3(0.18, 0.07, 0.16), Basis.IDENTITY, MOSS, DMesh.MAT_FUR, {"lumps": 0.35, "rings": 5, "segs": 10})
	mb.bind(B_HIPS)
	mb.blob(Vector3(0, 1.08, 0.4), Vector3(0.14, 0.05, 0.12), Basis.IDENTITY, MOSS, DMesh.MAT_FUR, {"lumps": 0.35, "rings": 5, "segs": 10})
	# thorns: a mane of them over the shoulders, a row down the spine, raked back
	for i in 15:
		var t := float(i) / 14.0
		var z := lerpf(0.66, -0.42, t)
		var hump := exp(-pow((z + 0.22) / 0.2, 2.0))
		var y := 1.12 + 0.2 * hump + 0.04 * sin(t * PI)
		var b := B_HIPS if z > 0.3 else (B_SPINE if z > -0.05 else B_CHEST)
		mb.bind(b)
		var h := 0.12 + 0.2 * hump + 0.04 * sin(t * PI)
		for side: float in ([0.0] if hump < 0.4 else [-0.09, 0.0, 0.09]):
			mb.tube(PackedVector3Array([Vector3(side, y - absf(side) * 0.4, z), Vector3(side * 1.6, y + h - absf(side) * 0.4, z + 0.09)]), _pf([0.035, 0.002]), 6, THORN, WOOD, {"lumps": 0.05})
	# the heart-knot: roots knotted round a light at the breast
	mb.bind(B_CHEST)
	var hk := Vector3(0, 0.86, -0.5)
	for i in 3:
		var a := float(i) * PI / 3.0
		var loop := PackedVector3Array()
		for j in 9:
			var u := TAU * float(j) / 8.0
			loop.append(hk + Basis(Vector3.UP, a) * Vector3(cos(u) * 0.085, sin(u) * 0.085, 0))
		mb.tube(loop, _pf(_rep(0.014, 9)), 5, BARK_L, WOOD, {"lumps": 0.2, "caps": false})
	# the neck, thick and low, the head long and wolfish
	mb.bind_blend(B_CHEST, B_NECK, rests[B_CHEST], rests[B_NECK])
	mb.tube(PackedVector3Array([Vector3(0, 1.02, -0.36), Vector3(0, 1.03, -0.5)]), _pf([0.25, 0.21]), 14, BARK, WOOD, {"lumps": 0.18, "caps": false})
	mb.bind(B_NECK)
	mb.tube(PackedVector3Array([Vector3(0, 1.03, -0.5), Vector3(0, 1.07, -0.64), Vector3(0, 1.1, -0.76)]), _pf([0.21, 0.17, 0.14]), 14, BARK, WOOD, {"lumps": 0.18, "ripple": Vector2(0.06, 6.0)})
	mb.bind(B_HEAD)
	mb.blob(Vector3(0, 1.15, -0.84), Vector3(0.14, 0.12, 0.16), Basis(Vector3.RIGHT, -0.1), BARK_L, WOOD, {"lumps": 0.18, "rings": 8, "segs": 12})
	mb.tube(PackedVector3Array([Vector3(0, 1.13, -0.94), Vector3(0, 1.1, -1.06), Vector3(0, 1.07, -1.14)]), _pf([0.095, 0.075, 0.055]), 10, BARK_L, WOOD, {"lumps": 0.14})
	for s: float in [-1.0, 1.0]:
		mb.blob(Vector3(s * 0.085, 1.17, -0.89), Vector3(0.035, 0.026, 0.022), Basis.IDENTITY, HOLLOW, WOOD, {"lumps": 0.0, "rings": 5, "segs": 8})
		mb.blob(Vector3(s * 0.095, 1.2, -0.87), Vector3(0.04, 0.012, 0.03), Basis(Vector3.BACK, s * 0.3), BARK.darkened(0.2), WOOD, {"lumps": 0.1, "rings": 4, "segs": 8})
		mb.tube(PackedVector3Array([Vector3(s * 0.1, 1.23, -0.76), Vector3(s * 0.15, 1.32, -0.7)]), _pf([0.035, 0.005]), 6, BARK, WOOD, {"lumps": 0.1})
		_antler(mb, s)
	mb.bind(B_JAW)
	mb.tube(PackedVector3Array([Vector3(0, 1.05, -0.86), Vector3(0, 1.03, -1.0), Vector3(0, 1.02, -1.1)]), _pf([0.09, 0.065, 0.045]), 10, BARK, WOOD, {"lumps": 0.14})
	for s: float in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.04, 1.06, -1.08), Vector3(s * 0.04, 1.13, -1.09)]), _pf([0.014, 0.001]), 5, THORN.lightened(0.15), WOOD, {"lumps": 0.0})
		mb.tube(PackedVector3Array([Vector3(s * 0.05, 1.1, -1.05), Vector3(s * 0.05, 1.03, -1.06)]), _pf([0.013, 0.001]), 5, THORN.lightened(0.15), WOOD, {"lumps": 0.0})
	# the legs: thick-muscled above, knotted joints, clawed feet; the hind legs with a hock
	for i in 4:
		var bu := B_LEG + 2 * i
		var up: Vector3 = rests[bu]
		var kn: Vector3 = rests[bu + 1]
		var ft: Vector3 = feet[i]
		mb.bind(bu)
		mb.blob(up.lerp(kn, 0.3) + Vector3(0, 0.02, 0), Vector3(0.14, 0.22, 0.16), Basis.IDENTITY, BARK, WOOD, {"lumps": 0.22, "rings": 7, "segs": 10})
		mb.tube(PackedVector3Array([up, up.lerp(kn, 0.5), kn]), _pf([0.11, 0.09, 0.07]), 10, BARK, WOOD, {"lumps": 0.18})
		mb.bind_blend(bu, bu + 1, kn + (up - kn) * 0.2, kn + (ft - kn) * 0.2)
		mb.blob(kn, Vector3(0.075, 0.075, 0.075), Basis.IDENTITY, BARK_L, WOOD, {"lumps": 0.25, "rings": 5, "segs": 8})
		mb.bind(bu + 1)
		mb.tube(PackedVector3Array([kn, kn.lerp(ft, 0.5), ft]), _pf([0.065, 0.055, 0.05]), 10, BARK, WOOD, {"lumps": 0.15})
		mb.blob(ft + Vector3(0, -0.01, -0.03), Vector3(0.08, 0.05, 0.1), Basis.IDENTITY, BARK_L.darkened(0.2), WOOD, {"lumps": 0.2, "rings": 5, "segs": 8})
		for c in 3:
			var cx := (float(c) - 1.0) * 0.04
			mb.tube(PackedVector3Array([ft + Vector3(cx, -0.02, -0.09), ft + Vector3(cx * 1.3, -0.05, -0.16)]), _pf([0.014, 0.002]), 5, THORN, WOOD, {"lumps": 0.0})
	# the tail: a bramble whip, thorns on it
	var tl := PackedVector3Array([rests[7], rests[8], rests[9], Vector3(0, 0.56, 1.22)])
	for i in 3:
		mb.bind(B_TAIL + i)
		mb.tube(PackedVector3Array([tl[i], tl[i + 1]]), _pf([0.075 - 0.02 * float(i), 0.055 - 0.02 * float(i)]), 8, BARK, WOOD, {"lumps": 0.2})
		for j in 2:
			var p := tl[i].lerp(tl[i + 1], 0.3 + 0.4 * float(j))
			var side := 1.0 if (i + j) % 2 == 0 else -1.0
			mb.tube(PackedVector3Array([p, p + Vector3(side * 0.07, 0.06, 0.03)]), _pf([0.018, 0.002]), 5, THORN, WOOD, {"lumps": 0.0})

	_ornament(mb)


## Tertiary forms: ridged bark plates down the flanks, moss strands hanging from the belly, bracket fungus on the haunch,
## root tendrils wrapped on the legs and a band of small thorns at each knee.
func _ornament(mb: Variant) -> void:
	for i in 7:
		var z := 0.62 - 0.17 * float(i)
		var bone := B_HIPS if z > 0.3 else (B_SPINE if z > -0.05 else B_CHEST)
		mb.bind(bone)
		for s: float in [-1.0, 1.0]:
			mb.blob(Vector3(s * 0.27, 0.86 + 0.02 * sin(float(i)), z), Vector3(0.06, 0.045, 0.09), Basis(Vector3.BACK, s * 0.5), BARK_L, WOOD, {"lumps": 0.3, "rings": 4, "segs": 8})
			var bx := Vector3(s * (0.1 + 0.02 * float(i % 3)), 0.74, z)
			mb.tube(PackedVector3Array([bx, bx + Vector3(0.0, -0.1, 0.0), bx + Vector3(s * 0.01, -0.2 - 0.03 * float(i % 2), 0.02)]), _pf([0.012, 0.009, 0.003]), 4, MOSS, DMesh.MAT_FUR, {"lumps": 0.2})
	mb.bind(B_HIPS)
	for j in 3:
		mb.blob(Vector3(0.24, 0.98 - 0.07 * float(j), 0.46 - 0.06 * float(j)), Vector3(0.08 - 0.015 * float(j), 0.016, 0.06 - 0.01 * float(j)), Basis(Vector3.BACK, -0.4), Color(0.7, 0.62, 0.5), WOOD, {"lumps": 0.25, "rings": 4, "segs": 8})
	for i in 4:
		var bu := B_LEG + 2 * i
		var up: Vector3 = rests[bu]
		var kn: Vector3 = rests[bu + 1]
		mb.bind(bu)
		var loop := PackedVector3Array()
		for j in 9:
			var u := TAU * float(j) / 8.0 * 1.5
			loop.append(up.lerp(kn, 0.2 + 0.6 * float(j) / 8.0) + Vector3(cos(u) * 0.105, 0.0, sin(u) * 0.105))
		mb.tube(loop, _pf(_rep(0.012, 9)), 5, BARK_L, WOOD, {"lumps": 0.2, "caps": false})
		for j in 6:
			var a := TAU * float(j) / 6.0
			mb.tube(PackedVector3Array([kn + Vector3(cos(a) * 0.07, 0.0, sin(a) * 0.07), kn + Vector3(cos(a) * 0.1, 0.035, sin(a) * 0.1)]), _pf([0.01, 0.001]), 4, THORN, WOOD, {"lumps": 0.0})


## A briar antler: a beam up, back and out from the brow, tines off it, thorns all along: a tall spread crown.
func _antler(mb: Variant, s: float) -> void:
	var beam := PackedVector3Array([Vector3(s * 0.07, 1.24, -0.82), Vector3(s * 0.16, 1.42, -0.8), Vector3(s * 0.28, 1.6, -0.74), Vector3(s * 0.42, 1.74, -0.64), Vector3(s * 0.52, 1.82, -0.52)])
	mb.tube(beam, _pf([0.04, 0.034, 0.027, 0.019, 0.007]), 7, BARK, WOOD, {"lumps": 0.12})
	for i in [1, 2, 3]:
		var b: Vector3 = beam[i]
		var tip := b + Vector3(s * 0.03, 0.2 - 0.03 * float(i), -0.12 + 0.04 * float(i))
		mb.tube(PackedVector3Array([b, b.lerp(tip, 0.5) + Vector3(s * 0.02, 0, 0), tip]), _pf([0.022, 0.015, 0.003]), 6, BARK, WOOD, {"lumps": 0.1})
	for i in 7:
		var p := beam[0].lerp(beam[4], float(i) / 7.0 + 0.05)
		mb.tube(PackedVector3Array([p, p + Vector3(s * 0.045, 0.025 * float(i % 2), -0.035)]), _pf([0.009, 0.001]), 4, THORN, WOOD, {"lumps": 0.0})

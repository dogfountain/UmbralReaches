extends "res://core/enemy/boss_body.gd"
## The Bone Abbot, built in the villagers' style but to his own design (17 Nov, Luke: "the style, not the exact look";
## "have some creativity"): the same skeleton, soft skinning, shader and detail maps as Hearthward's people
## (VillagerRig / DwarfMesh primitives: lofts, tubes, lumpy blobs), but a body of his own:
##   tall and hunched, the head jutting forward under a huge hood whose peak rises up and back like a horn,
##   a crown of bone tines round its brim, nothing in it but dark and two ember eyes;
##   a broad stiff mantle over the shoulders, ragged at the edge, candles burning on it;
##   the robe torn open on the breast over a ribcage, the reliquary burning inside it for a heart (his weak spot);
##   long sleeves and big skeletal hands, the right round a crozier of stacked vertebrae with a spiral crook and a
##   flame hung in it, the left an open claw;
##   a robe that flares to the floor in tatters, a cord with tally bones and a rosary of small skulls.
## Glowing points (eyes, the heart, the crook's flame, candles) are `glints`, lit by VillagerBossRig.
## No class_name (project rule): const AbbotBody := preload("res://core/enemy/abbot_body.gd")

const ROBE := Color(0.12, 0.1, 0.11)
const MANTLE := Color(0.3, 0.07, 0.08)
const WAX := Color(0.86, 0.82, 0.7)
const CORD := Color(0.42, 0.36, 0.26)

func _joints() -> Dictionary:
	# taller than a man, long-armed, hunched (the neck and head forward of the hips)
	return {"pelvis": Vector3(0, 0.88, 0), "chest": Vector3(0, 1.18, -0.02), "neck": Vector3(0, 1.44, -0.07), "head": Vector3(0, 1.53, -0.13),
		"shoulder": Vector3(0.2, 1.37, 0.0), "elbow": Vector3(0.25, 1.03, 0.03), "wrist": Vector3(0.27, 0.69, 0.0),
		"hip": Vector3(0.09, 0.84, 0.0), "knee": Vector3(0.1, 0.46, -0.01), "ankle": Vector3(0.1, 0.075, 0.012)}


# =====================================================================================================
# the body
# =====================================================================================================

func _body_v(mb: Variant) -> void:
	_ab_robe(mb)
	_ab_torso(mb)
	_ab_ribs(mb)
	_ab_mantle(mb)
	_ab_hood(mb)
	for side in 2:
		_ab_sleeve(mb, side)
		_ab_claw(mb, side, side == 0)
	_ab_crozier(mb)
	_ab_cord(mb)
	_ab_ornament(mb)


func _ab_robe(mb: Variant) -> void:
	# from the waist to the floor, flaring, deep pleats; it follows the stride (skirt skinning)
	mb.bind_skirt(P + 0.02 * k, 0.1 * k, 0.7, 0.14 * k)
	var pts := PackedVector3Array()
	for y: float in [P + 0.06 * k, 0.7 * k, 0.5 * k, 0.3 * k, 0.12 * k, 0.03 * k]:
		pts.append(Vector3(0, y, 0.015 * k))
	mb.tube(pts, _pf([0.17, 0.2, 0.25, 0.31, 0.37, 0.41], k), 34, ROBE, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.05, 11.0), "lumps": 0.04, "caps": false})
	# the hem in tatters: flat tongues of different lengths hanging off it
	for i in 26:
		var a := TAU * float(i) / 26.0 + 0.07 * sin(float(i) * 3.1)
		var dir := Vector3(sin(a), 0, -cos(a))
		var top := Vector3(0, 0.06 * k, 0.015 * k) + dir * 0.405 * k
		var ln := (0.05 + 0.06 * absf(sin(float(i) * 2.3))) * k
		mb.tube(PackedVector3Array([top, top + dir * 0.015 * k + Vector3(0, -ln * 0.6, 0), top + dir * 0.03 * k + Vector3(0, -ln, 0)]), _pf([0.05, 0.04, 0.014], k), 6, ROBE.darkened(0.12), DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 0.2), "ref": dir, "lumps": 0.12})


func _ab_torso(mb: Variant) -> void:
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08 * k, 0), Vector3(0, P + 0.3 * k, 0))
	var ys := PackedFloat32Array([1.38 * k, 1.3 * k, 1.16 * k, 1.02 * k, P - 0.02 * k])
	mb.loft(ys, _pf([0.12, 0.19, 0.18, 0.16, 0.17], k), _pf([0.09, 0.12, 0.115, 0.105, 0.11], k), _pf([-0.05, -0.03, -0.015, 0.0, 0.0], k), PackedFloat32Array(), 26, ROBE, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.02, 9.0), "lumps": 0.02})
	# the neck, bone, into the hood
	mb.bind_blend(B_CHEST, B_HEAD, Vector3(0, 1.36, -0.05) * k, Vector3(0, 1.46, -0.09) * k)
	mb.tube(PackedVector3Array([Vector3(0, 1.34, -0.04) * k, Vector3(0, 1.44, -0.08) * k, hc + Vector3(0, -0.06, 0.03) * k]), _pf([0.035, 0.03, 0.03], k), 8, BONE.darkened(0.1), DwarfMesh.MAT_LINEN, {"lumps": 0.06, "ripple": Vector2(0.15, 30.0)})


## The robe torn open on the breast: a dark hollow, a ribcage over it, the reliquary burning inside for a heart.
func _ab_ribs(mb: Variant) -> void:
	mb.bind(B_CHEST)
	mb.blob(Vector3(0, 1.17, -0.105) * k, Vector3(0.12, 0.16, 0.035) * k, Basis.IDENTITY, HOLLOW, DwarfMesh.MAT_CLOTH, {"lumps": 0.08, "rings": 8, "segs": 14})
	# the torn edges of the robe round it
	for s: float in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.04, 1.33, -0.12) * k, Vector3(s * 0.12, 1.24, -0.13) * k, Vector3(s * 0.13, 1.1, -0.125) * k, Vector3(s * 0.06, 1.0, -0.12) * k]), _pf([0.016, 0.02, 0.02, 0.014], k), 6, ROBE.lightened(0.04), DwarfMesh.MAT_CLOTH, {"lumps": 0.25})
	mb.tube(PackedVector3Array([Vector3(0, 1.31, -0.135) * k, Vector3(0, 1.18, -0.15) * k, Vector3(0, 1.06, -0.14) * k]), _pf([0.014, 0.016, 0.012], k), 7, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.05})
	for j in 5:
		var y := (1.29 - 0.055 * float(j)) * k
		for s: float in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for t: float in [0.0, 0.3, 0.6, 0.85, 1.0]:
				var a := t * 1.35
				pts.append(Vector3(s * (0.015 + sin(a) * 0.125), -t * 0.05 - 0.02 * t * t, -(0.145 - (1.0 - cos(a)) * 0.08)) * k + Vector3(0, y, 0))
			mb.tube(pts, _pf([0.009, 0.01, 0.0095, 0.008, 0.006], k), 6, BONE.darkened(0.03 * float(j)), DwarfMesh.MAT_LINEN, {"lumps": 0.04})
	# the reliquary: a gilt cage, the flame is a glint
	var rq := Vector3(0, 1.15, -0.12) * k
	mb.ring(rq + Vector3(0, 0.045, 0) * k, Vector2(0.03, 0.03) * k, 0.005 * k, 0.008 * k, Basis.IDENTITY, GILT, DwarfMesh.MAT_METAL, 12)
	mb.ring(rq - Vector3(0, 0.045, 0) * k, Vector2(0.03, 0.03) * k, 0.005 * k, 0.008 * k, Basis.IDENTITY, GILT, DwarfMesh.MAT_METAL, 12)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var o := Vector3(cos(a), 0, sin(a)) * 0.03 * k
		mb.tube(PackedVector3Array([rq + o + Vector3(0, 0.045, 0) * k, rq + o * 1.25, rq + o - Vector3(0, 0.045, 0) * k]), _pf([0.004, 0.004, 0.004], k), 4, GILT, DwarfMesh.MAT_METAL, {"lumps": 0.0})


## A broad stiff mantle over the shoulders, wine wool, ragged at the edge, gilt at the hem; candles burn on it.
func _ab_mantle(mb: Variant) -> void:
	mb.bind(B_CHEST)
	var c := Vector3(0, 1.33, 0.0) * k
	mb.blob(c, Vector3(0.36, 0.13, 0.28) * k, Basis.IDENTITY, MANTLE, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.56), "lumps": 0.06, "rings": 9, "segs": 28, "folds": Vector3(0.06, 9.0, 0.2)})
	for i in 30:
		var a := TAU * float(i) / 30.0
		var dir := Vector3(sin(a), 0, -cos(a))
		if dir.z < -0.85:
			continue                                 # open at the throat over the ribs
		var edge := c + Vector3(dir.x * 0.355, -0.03, dir.z * 0.275) * k
		var ln := (0.05 + 0.04 * absf(sin(float(i) * 1.7))) * k
		mb.tube(PackedVector3Array([edge, edge + dir * 0.012 * k + Vector3(0, -ln, 0)]), _pf([0.03, 0.008], k), 5, MANTLE.darkened(0.1), DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 0.3), "ref": dir, "lumps": 0.04})
	mb.ring(c + Vector3(0, -0.02, 0) * k, Vector2(0.355, 0.275) * k, 0.007 * k, 0.014 * k, Basis.IDENTITY, GILT, DwarfMesh.MAT_METAL, 30)
	for cd: Array in _ab_candles():
		var b: Vector3 = cd[0]
		var ht: float = cd[1]
		mb.blob(b, Vector3(0.026, 0.009, 0.024) * k, Basis.IDENTITY, WAX.darkened(0.08), DwarfMesh.MAT_LINEN, {"lumps": 0.2, "rings": 5, "segs": 10})
		mb.tube(PackedVector3Array([b, b + Vector3(0, ht, 0)]), _pf([0.012, 0.011], k), 8, WAX, DwarfMesh.MAT_LINEN, {"lumps": 0.03})
		mb.tube(PackedVector3Array([b + Vector3(0.01 * k, ht * 0.85, 0), b + Vector3(0.012 * k, ht * 0.45, 0.002 * k)]), _pf([0.004, 0.003], k), 4, WAX, DwarfMesh.MAT_LINEN, {"lumps": 0.0})


## Candles on the mantle: [base point, height].
func _ab_candles() -> Array:
	var out := []
	for s: float in [-1.0, 1.0]:
		for e: Array in [[0.22, 0.04, 0.09], [0.27, 0.07, 0.06], [0.2, 0.1, 0.045], [0.25, -0.03, 0.035]]:
			var x := float(e[0])
			var z := float(e[1])
			var top := 1.33 + 0.13 * sqrt(maxf(0.0, 1.0 - (x / 0.36) * (x / 0.36) - (z / 0.28) * (z / 0.28)))
			out.append([Vector3(s * x, top - 0.004, z) * k, float(e[2]) * k])
	return out


## A huge hood: a deep shell round the head, a rolled rim framing nothing but dark, the peak rising up and back like a
## horn; the bone crown round the brim; inside, only two ember eyes (glints) (a bone jaw under them grinned).
func _ab_hood(mb: Variant) -> void:
	var c := hc
	mb.bind(B_HEAD)
	var hood := ROBE.darkened(0.1)
	# one deep cowl: a tube from the back of the skull to the face opening (a shell with a separate rim left the rim
	# standing in front of it, a hoop beside the face), the back closed by a blob, the dark inside it
	var cowl := PackedVector3Array([c + Vector3(0, 0.03, 0.12) * k, c + Vector3(0, 0.035, 0.02) * k, c + Vector3(0, 0.025, -0.07) * k, c + Vector3(0, 0.01, -0.14) * k])
	mb.tube(cowl, _pf([0.13, 0.165, 0.158, 0.135], k), 22, hood, DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 1.22), "ref": Vector3.UP, "lumps": 0.06, "caps": false, "ripple": Vector2(0.04, 3.0)})
	mb.blob(c + Vector3(0, 0.03, 0.12) * k, Vector3(0.13, 0.16, 0.06) * k, Basis.IDENTITY, hood, DwarfMesh.MAT_CLOTH, {"lumps": 0.05, "rings": 8, "segs": 18})
	mb.blob(c + Vector3(0, 0.0, 0.0) * k, Vector3(0.12, 0.15, 0.08) * k, Basis.IDENTITY, HOLLOW, DwarfMesh.MAT_CLOTH, {"lumps": 0.0, "rings": 8, "segs": 14})
	var rim := PackedVector3Array()
	for i in 23:
		var a := TAU * float(i) / 22.0
		rim.append(c + Vector3(sin(a) * 0.135, cos(a) * 0.135 * 1.22 + 0.01, -0.14) * k)
	mb.tube(rim, _pf(_rep(0.017, 23), k), 7, hood.darkened(0.15), DwarfMesh.MAT_CLOTH, {"lumps": 0.12, "caps": false})
	# the peak: up off the crown and back like a horn, the tip curling down behind
	var peak := PackedVector3Array([c + Vector3(0, 0.17, 0.05) * k, c + Vector3(0, 0.29, 0.09) * k, c + Vector3(0, 0.38, 0.15) * k, c + Vector3(0, 0.43, 0.23) * k, c + Vector3(0, 0.42, 0.31) * k, c + Vector3(0, 0.36, 0.35) * k])
	mb.tube(peak, _pf([0.1, 0.075, 0.052, 0.034, 0.018, 0.006], k), 12, hood, DwarfMesh.MAT_CLOTH, {"lumps": 0.05, "squash": Vector2(1.0, 0.85)})
	# the crown, a circlet round the cowl above the brow, the tines fanned over the face
	var cc := c + Vector3(0, 0.12, -0.01) * k
	mb.ring(cc, Vector2(0.142, 0.15) * k, 0.01 * k, 0.014 * k, Basis(Vector3.RIGHT, 0.12), GILT, DwarfMesh.MAT_METAL, 24)
	for i in 9:
		var a := lerpf(-1.9, 1.9, float(i) / 8.0)
		var h := (0.06 + 0.11 * pow(cos(a / 1.9 * PI * 0.5), 1.4)) * k
		var base := cc + Vector3(sin(a) * 0.142, 0.0, -cos(a) * 0.15) * k
		var out_d := Vector3(sin(a), 0, -cos(a))
		mb.tube(PackedVector3Array([base, base + Vector3(0, h * 0.55, 0) + out_d * 0.016 * k, base + Vector3(0, h, 0) + out_d * 0.008 * k]), _pf([0.011, 0.007, 0.0015], k), 6, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.04})


func _ab_sleeve(mb: Variant, side: int) -> void:
	var ba := B_ARM_R if side == 0 else B_ARM_L
	var sh: Vector3 = rests[ba]
	var el: Vector3 = rests[ba + 1]
	var wr: Vector3 = rests[ba + 2]
	mb.bind(ba)
	mb.tube(PackedVector3Array([sh + Vector3(0, 0.03, 0) * k, sh.lerp(el, 0.5), el]), _pf([0.075, 0.07, 0.072], k), 12, ROBE, DwarfMesh.MAT_CLOTH, {"lumps": 0.04, "ripple": Vector2(0.06, 6.0)})
	mb.bind_blend(ba, ba + 1, el + (sh - el) * 0.2, el + (wr - el) * 0.2)
	mb.blob(el, Vector3(0.075, 0.075, 0.075) * k, Basis.IDENTITY, ROBE, DwarfMesh.MAT_CLOTH, {"lumps": 0.04, "rings": 6, "segs": 12})
	mb.bind(ba + 1)
	var cuff := wr + (el - wr) * 0.12
	mb.tube(PackedVector3Array([el, el.lerp(cuff, 0.6), cuff]), _pf([0.074, 0.088, 0.105], k), 14, ROBE, DwarfMesh.MAT_CLOTH, {"lumps": 0.06, "folds": Vector2(0.03, 6.0), "caps": false})
	# the bare forearm bones out of the cuff to the wrist
	mb.tube(PackedVector3Array([cuff + (el - wr) * 0.15, wr]), _pf([0.022, 0.018], k), 7, BONE.darkened(0.08), DwarfMesh.MAT_LINEN, {"lumps": 0.05})


## A skeletal hand, long-fingered: a fist round the grip (`fist`), or an open claw.
func _ab_claw(mb: Variant, side: int, fist: bool) -> void:
	var s := 1.0 if side == 0 else -1.0
	var ba := B_ARM_R if side == 0 else B_ARM_L
	var w: Vector3 = rests[ba + 2]
	var fo: Vector3 = (w - rests[ba + 1]).normalized()
	var pn := Vector3(-s, 0, 0).slide(fo).normalized()
	var ax: Vector3 = grip_ax[side]
	var g: Vector3 = grip[side]
	var K := k
	mb.bind(ba + 2)
	mb.blob(w + fo * 0.05 * K, Vector3(0.042, 0.055, 0.016) * K, Basis(ax, fo, ax.cross(fo)).orthonormalized(), BONE.darkened(0.05), DwarfMesh.MAT_LINEN, {"lumps": 0.08, "rings": 6, "segs": 10})
	for i in 4:
		var o := (float(i) - 1.5) * 0.024 * K
		var kn := w + fo * 0.1 * K + ax * o
		var pts := PackedVector3Array([kn - fo * 0.012 * K])
		if fist:
			for th: float in [0.2, 1.1, 2.0, 2.8]:
				pts.append(g + ax * o + (fo * cos(th) + pn * sin(th)) * 0.034 * K)
		else:
			# a claw: long, jointed, hooked at the tips
			pts.append(kn + fo * 0.045 * K + pn * 0.01 * K)
			pts.append(kn + fo * 0.085 * K + pn * 0.035 * K)
			pts.append(kn + fo * 0.105 * K + pn * 0.07 * K)
		var radii: Array = [0.009, 0.008, 0.007, 0.006, 0.003]
		mb.tube(pts, _pf(radii.slice(0, pts.size()), K), 6, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.05})
		for j in range(1, pts.size() - 1):
			mb.blob(pts[j], Vector3(0.009, 0.009, 0.009) * K, Basis.IDENTITY, BONE.darkened(0.05), DwarfMesh.MAT_LINEN, {"lumps": 0.0, "rings": 4, "segs": 6})
	var tb := w + fo * 0.03 * K + ax * 0.03 * K + pn * 0.012 * K
	var th_end := (g + ax * 0.04 * K + pn * 0.03 * K) if fist else (tb + fo * 0.07 * K + ax * 0.02 * K + pn * 0.04 * K)
	mb.tube(PackedVector3Array([tb, tb.lerp(th_end, 0.5) + pn * 0.01 * K, th_end]), _pf([0.01, 0.008, 0.004], K), 6, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.05})


## The crozier: a staff of stacked vertebrae, a gilt knop, a spiral crook with a flame hung in it.
func _ab_crozier(mb: Variant) -> void:
	var g: Vector3 = grip[0]
	var ax: Vector3 = grip_ax[0]
	var fd: Vector3 = (grip_up[0] as Vector3).slide(ax).normalized()
	var sd := ax.cross(fd).normalized()
	var K := k
	var along := Basis(Quaternion(Vector3.UP, ax))
	mb.bind(B_HAND_R)
	mb.tube(PackedVector3Array([g - ax * 1.12 * K, g + ax * 0.62 * K]), _pf([0.013, 0.015], K), 7, BONE.darkened(0.15), DwarfMesh.MAT_LINEN, {"lumps": 0.03})
	for i in 30:
		var t := lerpf(-1.08, 0.58, float(i) / 29.0)
		if absf(t) < 0.07:
			continue                                     # the fist
		mb.blob(g + ax * t * K, Vector3(0.026, 0.012, 0.026) * K * (1.0 + 0.15 * float(i % 2)), along, BONE.darkened(0.04 * float(i % 3)), DwarfMesh.MAT_LINEN, {"lumps": 0.1, "rings": 5, "segs": 9})
	var top := g + ax * 0.62 * K
	mb.blob(top, Vector3(0.04, 0.03, 0.04) * K, along, GILT, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 6, "segs": 12})
	# the crook: up, over toward the front and round in a shrinking spiral
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	var cc := top + ax * 0.12 * K + fd * 0.1 * K
	for i in 15:
		var t := float(i) / 14.0
		var a := PI + t * PI * 1.7
		pts.append(cc + (fd * cos(a) + ax * sin(a)) * lerpf(0.11, 0.035, t) * K)
		rr.append(lerpf(0.02, 0.009, t) * K)
	mb.tube(pts, rr, 8, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.06})
	# a little gilt cage hung from the crook on a chain: the flame is a glint
	var hang := cc + fd * 0.005 * K - ax * 0.02 * K
	mb.tube(PackedVector3Array([cc + ax * 0.03 * K, hang + ax * 0.025 * K]), _pf([0.003, 0.003], K), 4, GILT, DwarfMesh.MAT_METAL, {"lumps": 0.0})
	mb.ring(hang + ax * 0.02 * K, Vector2(0.018, 0.018) * K, 0.004 * K, 0.006 * K, along, GILT, DwarfMesh.MAT_METAL, 10)
	mb.ring(hang - ax * 0.02 * K, Vector2(0.018, 0.018) * K, 0.004 * K, 0.006 * K, along, GILT, DwarfMesh.MAT_METAL, 10)
	for i in 3:
		var o := (fd * cos(TAU * float(i) / 3.0) + sd * sin(TAU * float(i) / 3.0)) * 0.018 * K
		mb.tube(PackedVector3Array([hang + ax * 0.02 * K + o, hang - ax * 0.02 * K + o]), _pf([0.003, 0.003], K), 4, GILT, DwarfMesh.MAT_METAL, {"lumps": 0.0})


## A cord at the waist, its ends hanging, tally bones on strings and a rosary of small skulls on the left.
func _ab_cord(mb: Variant) -> void:
	mb.bind(B_SPINE)
	var y := P + 0.03 * k
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(Vector3(sin(a) * 0.178 * k, y, (0.015 - cos(a) * 0.125) * k))
		rr.append(0.011 * k)
	mb.tube(pts, rr, 6, CORD, DwarfMesh.MAT_LINEN, {"lumps": 0.04, "caps": false})
	var kn: Vector3 = pts[2]
	mb.blob(kn, Vector3(0.022, 0.02, 0.018) * k, Basis.IDENTITY, CORD, DwarfMesh.MAT_LINEN, {"lumps": 0.15, "rings": 5, "segs": 8})
	mb.bind_skirt(P + 0.02 * k, 0.1 * k, 0.7, 0.14 * k)
	for e in 2:
		mb.tube(PackedVector3Array([kn, kn + Vector3(0.012 * float(e), -0.2, -0.03) * k, kn + Vector3(0.02 * float(e), -0.4, -0.05) * k]), _pf([0.008, 0.008, 0.006], k), 5, CORD, DwarfMesh.MAT_LINEN, {"lumps": 0.04})
	# the rosary of small skulls on the left hip
	var r0 := Vector3(-0.165 * k, y, -0.04 * k)
	for i in 6:
		var t := float(i + 1) / 6.0
		var p := r0 + Vector3(-0.012 * sin(t * 3.0), -0.32 * t, -0.04 * sin(t * PI)) * k
		mb.blob(p, (Vector3(0.022, 0.024, 0.022) if i % 2 == 1 else Vector3(0.009, 0.009, 0.009)) * k, Basis.IDENTITY, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.06, "rings": 5, "segs": 8})
	# tally bones on strings at the right hip
	for i in 4:
		var t0 := Vector3((0.13 + 0.02 * float(i)) * k, y, (-0.09 + 0.03 * float(i)) * k)
		var t1 := t0 + Vector3(0, -(0.1 + 0.03 * float(i % 2)), -0.01) * k
		mb.tube(PackedVector3Array([t0, t1]), _pf([0.003, 0.003], k), 4, CORD, DwarfMesh.MAT_LINEN, {"lumps": 0.0})
		mb.tube(PackedVector3Array([t1, t1 + Vector3(0.004, -0.08, 0.0) * k]), _pf([0.009, 0.008], k), 6, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.05})


## Glints' rest points (set with the layout, so a cached mesh has them): the eyes, the heart, the crook's flame, the
## candles. And the muzzle at the crook.
func _layout_glints() -> void:
	glints.clear()
	for s: float in [-1.0, 1.0]:
		glints.append([B_HEAD, hc + Vector3(s * 0.036, 0.01, -0.09) * k, 0.012 * k, EMBER])
	glints.append([B_CHEST, Vector3(0, 1.15, -0.12) * k, 0.026 * k, FLAME])
	var g: Vector3 = grip[0]
	var ax: Vector3 = grip_ax[0]
	var fd: Vector3 = (grip_up[0] as Vector3).slide(ax).normalized()
	var cc := g + ax * 0.74 * k + fd * 0.1 * k
	glints.append([B_HAND_R, cc + fd * 0.005 * k - ax * 0.02 * k, 0.014 * k, FLAME])
	muzzle_at = [B_HAND_R, cc]
	for cd: Array in _ab_candles():
		glints.append([B_CHEST, (cd[0] as Vector3) + Vector3(0, float(cd[1]) + 0.016 * k, 0), 0.008 * k, FLAME])


## Tertiary forms: wax run down the mantle from the candles, gilt thread bands down the robe's flanks, a chain of small
## vertebrae over the mantle's rim with a reliquary medal, bone studs on the hood's rolled rim, tattered grave-ribbons
## hanging from the belt.
func _ab_ornament(mb: Variant) -> void:
	mb.bind(B_CHEST)
	for cd: Array in _ab_candles():
		var b: Vector3 = cd[0]
		mb.tube(PackedVector3Array([b + Vector3(0.01 * k, 0.0, 0.0), b + Vector3(0.012 * k, -0.06 * k, 0.01 * k), b + Vector3(0.012 * k, -0.1 * k, 0.012 * k)]), _pf([0.007, 0.006, 0.01], k), 4, WAX.darkened(0.06), DwarfMesh.MAT_LINEN, {"lumps": 0.1})
	var c := Vector3(0, 1.33, 0.0) * k
	for i in 16:
		var a := lerpf(-2.6, 2.6, float(i) / 15.0)
		mb.blob(c + Vector3(sin(a) * 0.34, -0.012, -cos(a) * 0.26) * k, Vector3(0.016, 0.012, 0.012) * k, Basis(Vector3.UP, -a), WAX.darkened(0.15), DwarfMesh.MAT_LINEN, {"lumps": 0.2, "rings": 4, "segs": 6})
	mb.blob(c + Vector3(0, -0.06, -0.28) * k, Vector3(0.03, 0.04, 0.01) * k, Basis.IDENTITY, GILT, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 5, "segs": 10})
	mb.bind(B_SPINE)
	for ang: float in [-1.0, 1.0, -2.2, 2.2]:
		var band := PackedVector3Array()
		for y: float in [0.8, 0.62, 0.45, 0.3, 0.16]:
			var r := (0.2 + (0.8 - y) * 0.3) * k
			band.append(Vector3(sin(ang) * r, y * k, 0.015 * k - cos(ang) * r))
		mb.tube(band, _pf(_rep(0.012, band.size()), k), 5, GILT.darkened(0.25), DwarfMesh.MAT_METAL, {"squash": Vector2(1.0, 0.25), "ref": Vector3(sin(ang), 0.0, -cos(ang)), "lumps": 0.0})
	for i in 5:
		var x := -0.12 + 0.06 * float(i)
		var top := Vector3(x, P - 0.01 * k, -0.17 * k)
		mb.tube(PackedVector3Array([top, top + Vector3(0.0, -0.12 * k, -0.01 * k), top + Vector3(0.01 * k, -0.25 * k - 0.03 * k * float(i % 2), 0.0)]), _pf([0.012, 0.01, 0.003], k), 4, CORD.darkened(0.2), DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 0.3), "ref": Vector3.FORWARD, "lumps": 0.1})

extends RefCounted
## A sculpted head for the tavern dwarves (dwarf_rig.gd) and Hearthward's people (villager_rig.gd);
## no class_name. One continuous skin surface instead of a pile of overlapping blobs (which read as
## lumps up close): an ellipsoid skull, tapered to the jaw, with the face displaced along its normal
## by smooth features laid out in normalised face coordinates (x -1..1 across, y -1..1 down the
## skull, front only): eye sockets, an arched brow ridge, temples, cheekbones, a nose from root to
## tip with wings and the groove round them, philtrum, an upper and a lower lip with a lip line and
## corners, the mentolabial fold, a chin, nasolabial folds, and with age bags under the eyes, a crease
## below them, crow's feet, forehead lines and hollow cheeks. Vertex colour carries the cheeks, the
## nose tip, the lips, socket shadow, nostrils and a beard shadow (stubble); alpha carries cavity AO.
## The grid is dense on the face (latitude rows packed between brow and chin, columns packed at the
## front) and sparse round the back. The mouth is a real slit: along the lip line the rows are
## doubled inside the mouth's width, the upper copy on the head and the lower on the jaw, so the
## jaw opens the lips over a dark mouth with teeth and a tongue.
## Also: eyes (sclera, iris, pupil, a wet cornea), an upper lid on the lid bone (blinks), a lower lid,
## a lash line, brows, and ears with a helix, a lobe and a bowl.
## Usage: var f := Face.new(); set c, R, params; f.build(mb); f.eyes(mb, ...); f.brows(...); f.ears(...)
## Model space: front is -Z. Load by path: const Face := preload("res://core/npc/npc_face.gd")

const DwarfMesh := preload("res://core/npc/dwarf_mesh.gd")

var c := Vector3.ZERO                      ## skull centre (model space)
var R := Vector3(0.086, 0.108, 0.098)      ## skull radii: half width, half height, half depth
var female := false
var child := false
var age := 0.0          ## 0 young .. 1 old
var brow := 1.0         ## brow ridge
var nose := 1.0         ## nose length and projection
var nose_w := 1.0       ## nose width
var bulb := 0.0         ## round tip and fat wings (the dwarves)
var hook := 0.0         ## a bump on the bridge
var cheek := 1.0        ## cheekbones
var fat := 0.0          ## full round cheeks
var chin := 1.0
var jaw := 0.7          ## chin width as a share of the skull's
var lip := 1.0          ## lip fullness
var mouth_y := -0.555   ## lip line (normalised y)
var eye_x := 0.4
var eye_y := 0.11
var eye_r := 0.0125     ## eyeball radius (m); 0 = from R
## models pass: the whole face's relief, scaled. The sculpted features were laid out right but
## shallow (a nose 2 cm proud, sockets 8 mm deep): on the skull's egg that read as a painted doll.
var relief := 1.6
var skin := Color(0.8, 0.58, 0.42)
var lip_c := Color(0.62, 0.3, 0.26)
var ruddy := Color(0.84, 0.46, 0.32)
var stubble := 0.0      ## beard shadow on the lip, chin and jaw (0..1)
var stubble_c := Color(0.22, 0.17, 0.14)
## models pass: the hair's colour and where its edge meets the brow (normalised y; 2 = none). The
## skin under the edge takes the hair's colour in a soft band, so a cap grows out of the scalp
## instead of sitting on it.
var hair_c := Color(0, 0, 0, 0)
var hairline := 2.0
var b_head := 3
var b_jaw := 4
var b_lid := 15

const SLIT := 0.3       ## the mouth slit's half width (normalised x)


# =====================================================================================================
# the shape
# =====================================================================================================

static func _g(x: float, y: float, cx: float, cy: float, sx: float, sy: float) -> float:
	var dx := (x - cx) / sx
	var dy := (y - cy) / sy
	return exp(-(dx * dx + dy * dy))


static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _tip_y() -> float:
	return -0.27 - 0.04 * (nose - 1.0) - 0.03 * bulb


## Displacement (in units of R.z) of the face at normalised (x, y).
func height(x: float, y: float) -> float:
	var ax := absf(x)
	var male := 0.0 if female else 1.0
	var kid := 0.55 if child else 1.0
	var h := 0.0
	# eye sockets: a soft hollow, and a pocket under the lids deep enough that the eyeball (which
	# sits just proud of the skull line) is never buried in skin
	h -= 0.13 * _g(ax, y, eye_x, eye_y - 0.01, 0.24, 0.17)          # models pass: deeper (was 0.08)
	var er := _er()
	var pd := Vector2((ax - eye_x) / (er * 1.3 / R.x), (y - eye_y) / (er * 1.05 / R.y)).length()
	h -= (er * 1.35 / R.z) * (1.0 - smoothstep(0.5, 1.0, pd))
	# temples
	h -= 0.06 * _g(ax, y, 0.86, 0.32, 0.16, 0.24)
	# brow ridge: an arched band over the eyes, heavy on men, and the bone between them
	var by := eye_y + 0.21 + 0.035 * cos(ax * 3.2)
	h += (0.045 + 0.06 * male) * brow * kid * exp(-pow((y - by) / 0.075, 2.0)) * (1.0 - smoothstep(0.55, 0.88, ax))
	h += 0.02 * male * brow * _g(ax, y, 0.0, eye_y + 0.17, 0.12, 0.08)
	# forehead: rounder on women and children
	h += (0.02 + 0.03 * (1.0 - kid)) * (1.0 - male * 0.7) * _g(ax, y, 0.0, 0.62, 0.55, 0.25)
	# cheekbones, full cheeks, hollows with age
	h += 0.1 * cheek * _g(ax, y, 0.6, -0.08, 0.2, 0.12)
	# models pass: the hollow under the cheekbone, and the angle of the jaw (a skull, not an egg)
	h -= 0.04 * (1.0 - fat) * kid * _g(ax, y, 0.62, -0.36, 0.16, 0.13)
	h += (0.03 + 0.04 * male) * kid * _g(ax, y, 0.8, -0.66, 0.12, 0.12)
	h += 0.075 * fat * _g(ax, y, 0.45, -0.3, 0.27, 0.2)
	h += 0.03 * (1.0 - kid) * _g(ax, y, 0.42, -0.3, 0.25, 0.2)
	h -= 0.045 * age * _g(ax, y, 0.56, -0.42, 0.14, 0.12)
	# the nose: root between the eyes, a bridge that rises and widens to the tip, then tucks under
	var top := eye_y + 0.07
	var tip := _tip_y()
	var t := clampf((top - y) / (top - tip), 0.0, 1.0)
	var win := 0.0
	if y > top:
		win = 1.0 - smoothstep(top, top + 0.12, y)
	elif y > tip:
		win = 1.0
	else:
		win = 1.0 - smoothstep(tip, tip - 0.1, y)
	var hb := (0.04 + 0.24 * pow(t, 1.25)) * nose * kid + 0.025 * hook * _g(0.0, y, 0.0, top - 0.17, 1.0, 0.07)
	var sx := (0.065 + 0.05 * t) * nose_w * (1.0 + 0.25 * bulb)
	h += hb * exp(-pow(x / sx, 2.0)) * win
	h += (0.03 + 0.09 * bulb) * nose * _g(x, y, 0.0, tip - 0.015, (0.085 + 0.07 * bulb) * nose_w, 0.07 + 0.04 * bulb)
	var wx := (0.12 + 0.05 * bulb) * nose_w
	h += (0.07 + 0.05 * bulb) * nose_w * _g(ax, y, wx, tip - 0.065, 0.06 + 0.02 * bulb, 0.06)
	h -= 0.025 * _g(ax, y, wx + 0.075, tip - 0.04, 0.03, 0.08)
	# under the tip the columella tucks in to the lip (a notch, so the nose does not run into a snout)
	h -= (0.035 + 0.05 * bulb) * nose * _g(x, y, 0.0, tip - 0.115 - 0.03 * bulb, 0.12 + 0.05 * bulb, 0.03)
	# philtrum (a groove between two ridges)
	var my := mouth_y
	h -= 0.016 * _g(x, y, 0.0, my + 0.11, 0.035, 0.055)
	h += 0.009 * _g(ax, y, 0.05, my + 0.11, 0.02, 0.055)
	# lips: upper, lower, the lip line, the corners; the fold under the lower lip
	var lf := lip * (1.0 - 0.3 * age) * (1.18 if female else 1.0)
	h += 0.07 * lf * _g(x, y, 0.0, my + 0.045, 0.27, 0.045)
	h += 0.085 * lf * _g(x, y, 0.0, my - 0.062, 0.23, 0.05)
	h -= 0.05 * exp(-pow((y - my) / 0.02, 2.0)) * (1.0 - smoothstep(0.24, 0.34, ax))
	h -= 0.028 * _g(ax, y, 0.31, my - 0.005, 0.045, 0.045)
	h -= 0.035 * _g(x, y, 0.0, my - 0.15, 0.2, 0.04)
	# chin (squarer and stronger on men)
	h += (0.07 + 0.05 * male) * chin * _g(x, y, 0.0, -0.84, 0.22 + 0.08 * male, 0.1)
	h += 0.025 * male * chin * _g(ax, y, 0.62, -0.72, 0.15, 0.12)
	# nasolabial folds: a crease from the nose wing past the mouth corner, a soft cheek outside it
	var pa := Vector2(wx + 0.08, tip - 0.05)
	var pb := Vector2(0.37, my - 0.1)
	var nl := _seg(Vector2(ax, y), pa, pb)
	h -= (0.01 + 0.03 * age + 0.01 * fat) * exp(-pow(nl / 0.028, 2.0))
	h += (0.01 + 0.02 * age + 0.025 * fat) * exp(-pow(_seg(Vector2(ax - 0.07, y), pa, pb) / 0.05, 2.0))
	if age > 0.0:
		# bags under the eyes and the crease below them; crow's feet; forehead lines
		h += 0.035 * age * _g(ax, y, eye_x, eye_y - 0.15, 0.15, 0.045)
		var ed := Vector2((ax - eye_x) * 1.0, (y - (eye_y - 0.03)) * 1.2).length()
		if y < eye_y - 0.05:
			h -= 0.016 * age * exp(-pow((ed - 0.21) / 0.02, 2.0))
		var ang := atan2(y - eye_y, ax - eye_x)
		h -= 0.007 * age * pow(maxf(0.0, sin(ang * 9.0)), 2.0) * _g(ax, y, eye_x + 0.24, eye_y, 0.08, 0.09)
		h -= 0.008 * age * pow(maxf(0.0, sin(y * 52.0)), 2.0) * smoothstep(0.42, 0.5, y) * (1.0 - smoothstep(0.72, 0.82, y)) * (1.0 - smoothstep(0.35, 0.7, ax))
	return h * relief


## Skin colour at normalised (x, y): cheeks, the nose tip, lips, socket shadow, nostrils, stubble.
func tint(x: float, y: float) -> Color:
	var ax := absf(x)
	var col := skin
	var tip := _tip_y()
	col = col.lerp(ruddy, clampf(0.26 * _g(ax, y, 0.5, -0.22, 0.22, 0.18) + 0.25 * fat * _g(ax, y, 0.45, -0.3, 0.25, 0.2), 0.0, 0.7))
	col = col.lerp(ruddy, 0.35 * _g(x, y, 0.0, tip, 0.12, 0.12) * (1.0 + bulb))
	col = col.lerp(ruddy.darkened(0.1), 0.3 * _g(ax, y, 0.95, 0.0, 0.2, 0.3))
	var my := mouth_y
	var lw := maxf(_g(x, y, 0.0, my + 0.04, 0.25, 0.04), _g(x, y, 0.0, my - 0.058, 0.21, 0.045))
	col = col.lerp(lip_c, clampf(lw * 1.5, 0.0, 1.0) * 0.85)
	col = col.darkened(0.12 * _g(ax, y, eye_x, eye_y, 0.17, 0.13) * (0.5 + age))
	col = col.lerp(Color(0.12, 0.05, 0.04), 0.9 * _g(ax, y, 0.065 * nose_w * (1.0 + 0.3 * bulb), tip - 0.1, 0.035, 0.025))
	if hair_c.a > 0.0 and hairline < 1.5:
		var edge := hairline - 0.08 * smoothstep(0.3, 0.85, ax)          # it dips at the temples
		col = col.lerp(col.lerp(hair_c, 0.5).darkened(0.12), 0.6 * smoothstep(edge - 0.13, edge + 0.02, y))
	if stubble > 0.0:
		var region := maxf(smoothstep(tip - 0.06, tip - 0.14, y), smoothstep(0.5, 0.7, ax) * smoothstep(-0.15, -0.35, y))
		col = col.lerp(stubble_c, stubble * 0.4 * region * (1.0 - clampf(lw * 1.5, 0.0, 1.0)))
	return col


func _taper(y: float) -> float:
	return lerpf(1.0, jaw, smoothstep(-0.25, -0.95, y))


## Model-space point of the face surface at normalised (x, y) (front side).
func point(x: float, y: float) -> Vector3:
	var zz := sqrt(maxf(1.0 - x * x - y * y, 0.0))
	var p0 := Vector3(R.x * x, R.y * y, -R.z * zz)
	var nd := Vector3(p0.x / (R.x * R.x), p0.y / (R.y * R.y), p0.z / (R.z * R.z)).normalized()
	var fw := smoothstep(0.0, 0.35, zz)
	return c + Vector3(p0.x * _taper(y), p0.y, p0.z) + nd * height(x, y) * fw * R.z


## Outward surface normal at normalised (x, y).
func normal(x: float, y: float) -> Vector3:
	var e := 0.01
	var dx := point(x + e, y) - point(x - e, y)
	var dy := point(x, y + e) - point(x, y - e)
	var n := dy.cross(dx).normalized()
	return n if n.dot(point(x, y) - c) > 0.0 else -n


## Eyeball centre: behind the bare skull line (no face displacement) so the front of the eye sits
## a little proud of it, under the brow.
func eye_center(s: float) -> Vector3:
	var x := s * eye_x
	var zz := sqrt(maxf(1.0 - x * x - eye_y * eye_y, 0.0))
	return c + Vector3(R.x * x * _taper(eye_y), R.y * eye_y, -R.z * zz) + Vector3(0, 0, _er() * 0.72)


func _er() -> float:
	return eye_r if eye_r > 0.0 else R.x * 0.145


## Jaw share of a vertex at normalised (x, y) with front-ness f (lower=true: the slit's jaw row).
func _jaw_w(x: float, y: float, f: float, lower: bool) -> float:
	var side := 1.0 - smoothstep(0.5, 0.92, absf(x))
	var below := 1.0 if lower else smoothstep(mouth_y - 0.005, mouth_y - 0.08, y)
	return side * below * smoothstep(-0.25, 0.25, f)


# =====================================================================================================
# the mesh
# =====================================================================================================

static func _span(a: float, b: float, n: int, out: PackedFloat32Array, first: bool) -> void:
	for i in range(0 if first else 1, n + 1):
		out.append(lerpf(a, b, float(i) / float(n)))


## The skull and face (head bone), lower lip and chin on the jaw.
func build(mb: Variant, segs := 48) -> void:
	var phis := PackedFloat32Array()
	var pa := acos(0.66)
	var pm := acos(mouth_y)
	var pb := acos(-0.93)
	_span(0.0, pa, 8, phis, true)
	_span(pa, pm, 30, phis, false)
	var mrow := phis.size() - 1
	_span(pm, pb, 12, phis, false)
	_span(pb, PI, 3, phis, false)
	var nr := phis.size()
	var nc := segs + 1
	var P := PackedVector3Array()
	var XY := PackedVector2Array()
	var FW := PackedFloat32Array()
	var H := PackedFloat32Array()
	P.resize(nr * nc)
	XY.resize(nr * nc)
	FW.resize(nr * nc)
	H.resize(nr * nc)
	for i in nr:
		var ph := phis[i]
		for j in nc:
			var t := float(j) / float(segs) * 2.0 - 1.0
			var u := PI * (0.35 * t + 0.65 * t * t * t)
			var sp := sin(ph)
			var p0 := Vector3(R.x * sp * sin(u), R.y * cos(ph), -R.z * sp * cos(u))
			var xn := sp * sin(u)
			var yn := cos(ph)
			var front := sp * cos(u)
			var nd := Vector3(p0.x / (R.x * R.x), p0.y / (R.y * R.y), p0.z / (R.z * R.z)).normalized()
			var fw := smoothstep(0.0, 0.35, front)
			var hh := height(xn, yn) * fw
			var k := i * nc + j
			P[k] = c + Vector3(p0.x * _taper(yn), p0.y, p0.z) + nd * hh * R.z
			XY[k] = Vector2(xn, yn)
			FW[k] = front
			H[k] = hh
	var circ := PI * (R.x + R.z)
	var idx_up := PackedInt32Array()
	var idx_dn := PackedInt32Array()
	idx_up.resize(nr * nc)
	idx_dn.resize(nr * nc)
	for i in nr:
		for j in nc:
			var k := i * nc + j
			var p := P[k]
			var jp := j + 1 if j < segs else 1
			var jm := j - 1 if j > 0 else segs - 1
			var du := P[i * nc + jp] - P[i * nc + jm]
			var dv := P[mini(i + 1, nr - 1) * nc + j] - P[maxi(i - 1, 0) * nc + j]
			var n := dv.cross(du)
			if n.length_squared() < 1e-12 or i == 0 or i == nr - 1:
				n = p - c
			n = n.normalized()
			if n.dot(p - c) < 0.0:
				n = -n
			var xy := XY[k]
			var fw := smoothstep(0.0, 0.35, FW[k])
			var col := skin.lerp(tint(xy.x, xy.y), fw)
			var ao := clampf(1.0 + 2.4 * minf(H[k], 0.0), 0.55, 1.0)
			var uv := Vector2(float(j) / float(segs) * circ, phis[i] * R.y)
			var w := _jaw_w(xy.x, xy.y, FW[k], false)
			var a: int = mb.vert_w(p, n, uv, col, DwarfMesh.MAT_SKIN, ao, b_head, b_jaw, w)
			idx_up[k] = a
			idx_dn[k] = a
			if i == mrow and absf(xy.x) < SLIT and FW[k] > 0.2:
				idx_up[k] = mb.vert_w(p, n, uv, col, DwarfMesh.MAT_SKIN, ao, b_head, b_jaw, 0.0)
				idx_dn[k] = mb.vert_w(p, n, uv, col, DwarfMesh.MAT_SKIN, ao, b_head, b_jaw, _jaw_w(xy.x, xy.y, FW[k], true))
	for i in nr - 1:
		for j in segs:
			var a0 := idx_dn[i * nc + j]
			var a1 := idx_dn[i * nc + j + 1]
			var b0 := idx_up[(i + 1) * nc + j]
			var b1 := idx_up[(i + 1) * nc + j + 1]
			if i == 0:
				mb.tri(a0, b1, b0)
			elif i == nr - 2:
				mb.tri(a0, a1, b0)
			else:
				mb.tri(a0, b0, a1)
				mb.tri(a1, b0, b1)
	mb.occ_ellipsoid(c, R * 0.9)
	# the mouth behind the lips: a dark cavity, teeth (upper on the head, lower on the jaw), a tongue
	var mp := point(0.0, mouth_y)
	var mw := R.x * 0.22
	mb.bind(b_head)
	mb.blob(mp + Vector3(0, R.y * 0.0, R.z * 0.2), Vector3(mw, R.y * 0.09, R.z * 0.14), Basis.IDENTITY, Color(0.1, 0.03, 0.03), DwarfMesh.MAT_SKIN, {"lumps": 0.0, "rings": 6, "segs": 12, "occ": false, "ao": 0.4})
	mb.blob(mp + Vector3(0, R.y * 0.025, R.z * 0.075), Vector3(mw * 0.82, R.y * 0.03, R.z * 0.05), Basis.IDENTITY, Color(0.86, 0.8, 0.68), DwarfMesh.MAT_EYE, {"lumps": 0.0, "rings": 4, "segs": 12, "occ": false, "phi": Vector2(0.0, 0.6), "ao": 0.7})
	mb.bind(b_jaw)
	mb.blob(mp + Vector3(0, -R.y * 0.04, R.z * 0.09), Vector3(mw * 0.74, R.y * 0.025, R.z * 0.05), Basis.IDENTITY, Color(0.82, 0.76, 0.64), DwarfMesh.MAT_EYE, {"lumps": 0.0, "rings": 4, "segs": 12, "occ": false, "phi": Vector2(0.4, 1.0), "ao": 0.6})
	mb.blob(mp + Vector3(0, -R.y * 0.05, R.z * 0.15), Vector3(mw * 0.7, R.y * 0.035, R.z * 0.1), Basis.IDENTITY, Color(0.45, 0.14, 0.13), DwarfMesh.MAT_SKIN, {"lumps": 0.0, "rings": 5, "segs": 10, "occ": false, "ao": 0.5})


## Eyeballs (head), upper lids (lid bone: blink), lower lids (head) and a lash line. `heavy` 0..1
## lowers the upper lid (old, tired, dwarvish).
func eyes(mb: Variant, iris: Color, heavy := 0.0) -> void:
	var er := _er()
	var lid_c := skin.darkened(0.06).lerp(ruddy, 0.12)
	for s: float in [-1.0, 1.0]:
		var e := eye_center(s)
		mb.bind(b_head)
		mb.blob(e, Vector3(er, er, er), Basis.IDENTITY, Color(0.72, 0.66, 0.6), DwarfMesh.MAT_EYE, {"lumps": 0.0, "rings": 10, "segs": 14, "occ": false})
		# iris (a shallow dome proud of the sclera), the pupil, and a catch light comes from MAT_EYE
		var fw := Vector3(s * 0.06, 0.02, -1.0).normalized()
		var ib := Basis(Quaternion(Vector3.FORWARD, fw))
		mb.blob(e + fw * er * 0.86, Vector3(er * 0.5, er * 0.5, er * 0.22), ib, iris, DwarfMesh.MAT_EYE, {"lumps": 0.0, "rings": 6, "segs": 14, "occ": false})
		mb.blob(e + fw * er * 1.03, Vector3(er * 0.22, er * 0.22, er * 0.08), ib, Color(0.02, 0.015, 0.015), DwarfMesh.MAT_EYE, {"lumps": 0.0, "rings": 4, "segs": 10, "occ": false})
		# lower lid on the head
		mb.blob(e + Vector3(0, -er * 0.05, 0.0), Vector3(er * 1.12, er * 1.1, er * 1.1), Basis(Vector3.RIGHT, 0.22), lid_c, DwarfMesh.MAT_SKIN, {"phi": Vector2(0.7, 1.0), "lumps": 0.0, "rings": 4, "segs": 16, "occ": false})
		# upper lid and lash line on the lid bone
		mb.bind(b_lid)
		# the upper lid's edge sits over the top of the iris (+0.42 er at the front); heavy lowers it.
		# Blink: the lid bone turns about -X by ~1 rad (DwarfRig.blink)
		# models pass: a little more lid at rest (0.12 rad lower): a fully open eye reads as a doll's
		var lb := Basis(Vector3.RIGHT, 0.4 - 0.3 * heavy)      # models pass: 0.32 made every face sleepy
		mb.blob(e, Vector3(er * 1.14, er * 1.14, er * 1.12), lb, lid_c, DwarfMesh.MAT_SKIN, {"phi": Vector2(0.0, 0.5), "lumps": 0.0, "rings": 7, "segs": 18, "occ": false})
		# the fold over the lid (crease) shadows the lid top
		mb.blob(e + Vector3(0, er * 0.12, 0.0), Vector3(er * 1.2, er * 1.15, er * 1.16), lb * Basis(Vector3.RIGHT, 0.35), lid_c.darkened(0.08), DwarfMesh.MAT_SKIN, {"phi": Vector2(0.18, 0.42), "lumps": 0.0, "rings": 3, "segs": 18, "occ": false})
		var lash := PackedVector3Array()
		var rr := PackedFloat32Array()
		for i in 9:
			var th := -PI * 0.5 + lerpf(-1.25, 1.25, float(i) / 8.0)
			lash.append(e + lb * (Vector3(cos(th), -0.02, sin(th)) * er * 1.15))
			rr.append(er * (0.07 + 0.05 * sin(PI * float(i) / 8.0)))
		mb.tube(lash, rr, 4, Color(0.08, 0.05, 0.04), DwarfMesh.MAT_HAIR, {"lumps": 0.0, "squash": Vector2(1.0, 0.6), "caps": false})
	mb.bind(b_head)


## A trimmed beard: a shell over the lower face (jaw, chin, up the cheeks to the sideburns) laid
## `thick` (m) off the skin and thinning to nothing at its edge, the lips left clear; hair runs
## down it (MAT_HAIR's strands follow v). Skinned like the face under it (jaw share by region).
## `top` is how high it climbs the cheek at the sides (normalised y).
func beard_shell(mb: Variant, col: Color, thick: float, top := -0.05, chin_drop := 0.0) -> void:
	var nx := 26
	var ny := 16
	var ids := PackedInt32Array()
	ids.resize((nx + 1) * (ny + 1))
	var lim := func(x: float) -> float:
		var ax := absf(x)
		return mouth_y - 0.1 if ax < 0.3 else lerpf(mouth_y + 0.02, top, smoothstep(0.3, 0.86, ax))
	for j in ny + 1:
		for i in nx + 1:
			var x := lerpf(-0.9, 0.9, float(i) / float(nx))
			var hi: float = lim.call(x)
			var lo := -sqrt(maxf(0.97 - x * x, 0.0))
			var v := float(j) / float(ny)
			var y := lerpf(hi, lo, v)
			var edge := minf(smoothstep(0.0, 0.25, v), 1.0 - smoothstep(0.78, 0.9, absf(x)))
			var tk := thick * (0.25 + 0.75 * edge) + chin_drop * smoothstep(0.5, 1.0, v) * (1.0 - smoothstep(0.0, 0.6, absf(x)))
			var p := point(x, y)
			var n := normal(x, y)
			var pos := p + n * tk + Vector3.DOWN * chin_drop * 0.5 * smoothstep(0.6, 1.0, v) * (1.0 - smoothstep(0.0, 0.6, absf(x)))
			var front := sqrt(maxf(1.0 - x * x - y * y, 0.0))
			var w := _jaw_w(x, y, front, false)
			var cc := col.lightened(0.06 * sin(x * 37.0) * cos(y * 23.0))
			ids[j * (nx + 1) + i] = mb.vert_w(pos, n, Vector2(x * R.x * 2.0, -y * R.y * 1.5), cc, DwarfMesh.MAT_HAIR, 0.75 + 0.25 * edge, b_head, b_jaw, w)
	for j in ny:
		for i in nx:
			var a0 := ids[j * (nx + 1) + i]
			var a1 := ids[j * (nx + 1) + i + 1]
			var b0 := ids[(j + 1) * (nx + 1) + i]
			var b1 := ids[(j + 1) * (nx + 1) + i + 1]
			mb.tri(a0, b0, a1)
			mb.tri(a1, b0, b1)


## Pivot of the lid bone at rest (both eye centres lie on its X axis).
func lid_pivot() -> Vector3:
	var e := eye_center(1.0)
	return Vector3(0.0, e.y, e.z)


## Eyebrows along the brow ridge: a flattened band and a few strands (bushy 0..1).
func brows(mb: Variant, col: Color, bushy := 0.0, rng: RandomNumberGenerator = null) -> void:
	mb.bind(b_head)
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for i in 7:
			var t := float(i) / 6.0
			var x := lerpf(0.1, 0.66, t)
			var y := eye_y + 0.2 + 0.05 * sin(t * PI) - 0.04 * t
			pts.append(point(s * x, y) + normal(s * x, y) * R.z * 0.012)
			rr.append(R.y * (0.019 - 0.01 * t) * (1.0 + 0.9 * bushy))       # models pass: thinner (were sausages)
		mb.tube(pts, rr, 6, col, DwarfMesh.MAT_HAIR, {"lumps": 0.12, "squash": Vector2(1.0, 0.3), "ref": Vector3.BACK})
		if bushy > 0.0 and rng != null:
			for k in int(6 + 8 * bushy):
				var t2 := float(k) / float(5 + 8 * bushy)
				var x2 := lerpf(0.12, 0.66, t2)
				var y2 := eye_y + 0.22 + 0.05 * sin(t2 * PI) - 0.04 * t2
				mb.strand(point(s * x2, y2) + normal(s * x2, y2) * R.z * 0.01, Vector3(s * 1.0, 0.18, -0.12), R.y * rng.randf_range(0.12, 0.2) * bushy, R.y * 0.022, col.lightened(rng.randf_range(-0.06, 0.1)), Vector3(0, -0.6, 0), 0.3, 3, 4)


## Ears: a cupped shell, the helix rim, a lobe and the dark bowl. `big` scales them (dwarves).
func ears(mb: Variant, col: Color, big := 1.0) -> void:
	mb.bind(b_head)
	var hh := R.y * 0.29 * big
	for s: float in [-1.0, 1.0]:
		var ec := c + Vector3(s * R.x * 0.97, -R.y * 0.04, R.z * 0.08)
		var b := Basis(Vector3.UP, s * 0.42) * Basis(Vector3.FORWARD, s * 0.08)
		var out := b * Vector3(s, 0, 0)
		var fw := b * Vector3(0, 0, -1)
		mb.blob(ec + out * hh * 0.12, Vector3(hh * 0.16, hh, hh * 0.62), b, col, DwarfMesh.MAT_SKIN, {"lumps": 0.02, "rings": 8, "segs": 12})
		# helix: from the front of the top round the back to the lobe
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for i in 9:
			var a := lerpf(-0.4, PI * 1.05, float(i) / 8.0)
			pts.append(ec + out * hh * 0.28 + Vector3.UP * cos(a) * hh * 0.9 + (-fw) * sin(a) * hh * 0.55 + fw * hh * 0.08)
			rr.append(hh * (0.11 - 0.03 * float(i) / 8.0))
		mb.tube(pts, rr, 6, col.lerp(ruddy, 0.3), DwarfMesh.MAT_SKIN, {"lumps": 0.02})
		mb.blob(ec + out * hh * 0.2 + Vector3.DOWN * hh * 0.82 + fw * hh * 0.05, Vector3(hh * 0.12, hh * 0.24, hh * 0.2), b, col.lerp(ruddy, 0.4), DwarfMesh.MAT_SKIN, {"lumps": 0.0, "rings": 6, "segs": 10})
		mb.blob(ec + out * hh * 0.17 + fw * hh * 0.08 + Vector3.DOWN * hh * 0.05, Vector3(hh * 0.05, hh * 0.38, hh * 0.24), b, col.darkened(0.25), DwarfMesh.MAT_SKIN, {"lumps": 0.0, "rings": 6, "segs": 10, "occ": false, "ao": 0.75})

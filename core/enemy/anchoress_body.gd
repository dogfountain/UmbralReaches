extends "res://core/enemy/boss_body.gd"
## The Anchoress in the villagers' style, to her own design: a gaunt hermit, tall and bowed, in grey wool to the floor,
## wound round and round in the chain she bound herself with; a hood, a pale face with the eyes shut in prayer and a
## gag across the mouth; a cairn-stone anchor hanging from her right fist on a length of chain (`hang_r`: the boss rig
## lets it hang, and swings it up and over in the strike); a caged lantern from her left hand at the hip (her weak
## point, the Toll of the Cell).
## No class_name (project rule): const AnchoressBody := preload("res://core/enemy/anchoress_body.gd")

const WOOL := Color(0.36, 0.35, 0.33)
const HOOD := Color(0.27, 0.26, 0.25)
const SKIN_P := Color(0.72, 0.68, 0.64)
const LINEN_G := Color(0.6, 0.56, 0.48)
const STONE := Color(0.45, 0.44, 0.41)
const SKIRT := [0.15, 0.18, 0.22, 0.27, 0.32]

## The right hand's tool hangs from the fist at rest (the anchor on its chain).
var hang_r := true


func _joints() -> Dictionary:
	return {"pelvis": Vector3(0, 0.86, 0), "chest": Vector3(0, 1.15, -0.01), "neck": Vector3(0, 1.4, -0.04), "head": Vector3(0, 1.49, -0.07),
		"shoulder": Vector3(0.17, 1.34, 0.0), "elbow": Vector3(0.21, 1.02, 0.02), "wrist": Vector3(0.23, 0.72, 0.0),
		"hip": Vector3(0.085, 0.82, 0.0), "knee": Vector3(0.09, 0.45, -0.01), "ankle": Vector3(0.09, 0.075, 0.012)}


func _body_v(mb: Variant) -> void:
	_skirt(mb, 0.9, SKIRT, WOOL, 20)
	_torso_b(mb, [[1.38, 0.09, 0.07, -0.03], [1.3, 0.16, 0.1, -0.02], [1.15, 0.15, 0.1, -0.01], [1.0, 0.13, 0.09, 0.0], [0.86, 0.15, 0.1, 0.0]], WOOL)
	# the chain she bound herself with, wound from the shoulders to the knees
	mb.bind(B_SPINE)
	var ch := PackedVector3Array()
	for i in 70:
		var t := float(i) / 69.0
		var a := t * TAU * 3.2 + 0.6
		var y := lerpf(1.3, 0.42, t)
		var r := (_skirt_r(y) if y < 0.9 else lerpf(0.13, 0.16, clampf((y - 0.9) / 0.4, 0.0, 1.0))) + 0.022
		ch.append(Vector3(sin(a) * r, y - 0.04 * sin(a * 0.5), -cos(a) * r * 0.75))
	mb.tube(ch, _pf(_rep(0.014, ch.size()), 1.0), 6, IRON_D, DwarfMesh.MAT_METAL, {"ripple": Vector2(0.45, 90.0), "lumps": 0.0})
	# the head: a pale gaunt face, eyes shut, a gag; the hood over it, a shawl on the shoulders
	var fc: Variant = face()
	fc.skin = SKIN_P
	fc.ruddy = SKIN_P.darkened(0.05)
	fc.lip_c = SKIN_P.darkened(0.15)
	fc.build(mb)
	fc.eyes(mb, Color(0.35, 0.36, 0.38), 0.95)
	mb.bind(B_HEAD)
	var c := hc
	var R: Vector3 = fc.R
	var gag := PackedVector3Array()
	for i in 17:
		var a := lerpf(-2.3, 2.3, float(i) / 16.0)
		gag.append(c + Vector3(sin(a) * (R.x + 0.006), -0.058, -cos(a) * (R.z + 0.004)))
	mb.tube(gag, _pf(_rep(0.011, gag.size()), 1.0), 6, LINEN_G, DwarfMesh.MAT_LINEN, {"squash": Vector2(1.0, 1.6), "ref": Vector3.UP, "lumps": 0.1})
	mb.tube(PackedVector3Array([c + Vector3(0, 0.035, 0.1), c + Vector3(0, 0.04, 0.0), c + Vector3(0, 0.02, -0.09)]), _pf([0.11, 0.135, 0.118], 1.0), 20, HOOD, DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 1.25), "ref": Vector3.UP, "lumps": 0.06, "caps": false})
	mb.blob(c + Vector3(0, 0.035, 0.1), Vector3(0.11, 0.14, 0.05), Basis.IDENTITY, HOOD, DwarfMesh.MAT_CLOTH, {"lumps": 0.05, "rings": 8, "segs": 16})
	mb.bind(B_CHEST)
	mb.blob(Vector3(0, 1.33, 0.0), Vector3(0.24, 0.1, 0.18), Basis.IDENTITY, HOOD, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.6), "lumps": 0.08, "rings": 7, "segs": 22, "folds": Vector3(0.08, 7.0, 0.3)})
	# thin sleeves, thin pale hands
	for side in 2:
		_sleeve_v(mb, side, 0.055, 0.075, WOOL, 0.92)
		_hand_b(mb, side, true, SKIN_P, DwarfMesh.MAT_SKIN, 1.0, 0.008)
	_anchor(mb)
	_lantern(mb)


func _skirt_r(y: float) -> float:
	var t := clampf((0.9 - y) / 0.87, 0.0, 1.0) * float(SKIRT.size() - 1)
	var i := mini(int(t), SKIRT.size() - 2)
	return lerpf(float(SKIRT[i]), float(SKIRT[i + 1]), t - float(i))


## The anchor: a chain out of the right fist along the tool axis, a rough cairn-stone in an iron collar at its end.
func _anchor(mb: Variant) -> void:
	var g: Vector3 = grip[0]
	var ax: Vector3 = grip_ax[0]
	mb.bind(B_HAND_R)
	mb.tube(PackedVector3Array([g, g + ax * 0.25, g + ax * 0.5]), _pf([0.013, 0.013, 0.013], 1.0), 6, IRON_D, DwarfMesh.MAT_METAL, {"ripple": Vector2(0.45, 40.0), "lumps": 0.0})
	var st := g + ax * 0.62
	mb.blob(st, Vector3(0.13, 0.15, 0.12), Basis(Quaternion(Vector3.UP, ax)), STONE, DwarfMesh.MAT_LINEN, {"lumps": 0.25, "rings": 8, "segs": 12})
	mb.ring(st - ax * 0.1, Vector2(0.09, 0.09), 0.014, 0.03, Basis(Quaternion(Vector3.UP, ax)), IRON_D, DwarfMesh.MAT_METAL, 12)


## A caged lantern hanging from the left fist (the glass is a glint).
func _lantern(mb: Variant) -> void:
	var g: Vector3 = grip[1]
	var fd: Vector3 = (grip_up[1] as Vector3).slide(grip_ax[1]).normalized()
	var lc := g + fd * 0.17
	var b := Basis(Quaternion(Vector3.UP, fd))
	mb.bind(B_HAND_L)
	mb.tube(PackedVector3Array([g, lc - fd * 0.07]), _pf([0.004, 0.004], 1.0), 4, IRON_D, DwarfMesh.MAT_METAL, {"lumps": 0.0})
	mb.ring(lc - fd * 0.06, Vector2(0.045, 0.045), 0.008, 0.012, b, IRON_D, DwarfMesh.MAT_METAL, 10)
	mb.ring(lc + fd * 0.06, Vector2(0.045, 0.045), 0.008, 0.012, b, IRON_D, DwarfMesh.MAT_METAL, 10)
	var sd := fd.cross(Vector3.FORWARD).normalized() if absf(fd.dot(Vector3.FORWARD)) < 0.9 else fd.cross(Vector3.RIGHT).normalized()
	var sd2 := fd.cross(sd).normalized()
	for i in 4:
		var o := (sd * cos(TAU * float(i) / 4.0) + sd2 * sin(TAU * float(i) / 4.0)) * 0.042
		mb.tube(PackedVector3Array([lc - fd * 0.06 + o, lc + fd * 0.06 + o]), _pf([0.004, 0.004], 1.0), 4, IRON_D, DwarfMesh.MAT_METAL, {"lumps": 0.0})


func _layout_glints() -> void:
	var g: Vector3 = grip[1]
	var fd: Vector3 = (grip_up[1] as Vector3).slide(grip_ax[1]).normalized()
	glints.append([B_HAND_L, g + fd * 0.17, 0.034, FLAME])
	var g0: Vector3 = grip[0]
	muzzle_at = [B_HAND_R, g0 + (grip_ax[0] as Vector3) * 0.62]

extends "res://core/enemy/boss_body.gd"
## The Speaking Crown (the Hierarch's cantor) in the villagers' style, to its own design: a squat, heavy husk under a
## stone cope that hangs to the shins, cracked, embers in the cracks; thick stone arms and great stone fists; and where
## a head should be, a bronze speaking-horn rising and opening to the sky, its throat glowing with the voice (its weak point).
## No class_name (project rule): const CrownBody := preload("res://core/enemy/crown_body.gd")

const STONE := Color(0.44, 0.42, 0.38)
const STONE_D := Color(0.3, 0.29, 0.27)
const BRONZE := Color(0.55, 0.4, 0.2)
const CRACK := Color(0.85, 0.42, 0.12)
const VOICE := Color(1.0, 0.85, 0.55)


func _joints() -> Dictionary:
	return {"pelvis": Vector3(0, 0.72, 0), "chest": Vector3(0, 1.02, -0.04), "neck": Vector3(0, 1.24, -0.12), "head": Vector3(0, 1.32, -0.2),
		"shoulder": Vector3(0.3, 1.18, -0.02), "elbow": Vector3(0.38, 0.88, 0.0), "wrist": Vector3(0.4, 0.58, -0.06),
		"hip": Vector3(0.13, 0.68, 0.0), "knee": Vector3(0.14, 0.36, -0.02), "ankle": Vector3(0.14, 0.075, 0.01)}


func _body_v(mb: Variant) -> void:
	# legs: stone pillars under the cope
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		var bt := B_THIGH_R if side == 0 else B_THIGH_L
		var hip: Vector3 = rests[bt]
		var kn: Vector3 = rests[bt + 1]
		var an := ankle(s)
		mb.bind(bt)
		mb.tube(PackedVector3Array([hip, kn]), _pf([0.11, 0.1], 1.0), 10, STONE_D, DwarfMesh.MAT_LINEN, {"lumps": 0.15})
		mb.bind(bt + 1)
		mb.tube(PackedVector3Array([kn, an]), _pf([0.1, 0.09], 1.0), 10, STONE_D, DwarfMesh.MAT_LINEN, {"lumps": 0.15})
		mb.blob(an + Vector3(0, -0.035, -0.05), Vector3(0.1, 0.05, 0.14), Basis.IDENTITY, STONE_D, DwarfMesh.MAT_LINEN, {"lumps": 0.2, "rings": 6, "segs": 10})
	_torso_b(mb, [[1.24, 0.14, 0.12, -0.1], [1.14, 0.28, 0.17, -0.05], [0.98, 0.26, 0.17, -0.02], [0.82, 0.22, 0.15, 0.0], [0.7, 0.22, 0.15, 0.0]], STONE_D, DwarfMesh.MAT_LINEN)
	# the cope: a heavy stone bell from the shoulders to the shins, cracked, embers in the cracks
	mb.bind(B_CHEST)
	var cope := PackedVector3Array([Vector3(0, 1.22, -0.02), Vector3(0, 1.08, 0.0), Vector3(0, 0.8, 0.02), Vector3(0, 0.5, 0.03), Vector3(0, 0.3, 0.03)])
	mb.tube(cope, _pf([0.3, 0.42, 0.47, 0.5, 0.52], 1.0), 26, STONE, DwarfMesh.MAT_LINEN, {"folds": Vector2(0.06, 7.0), "lumps": 0.12, "caps": false})
	mb.blob(Vector3(0, 1.22, -0.02), Vector3(0.3, 0.06, 0.26), Basis.IDENTITY, STONE, DwarfMesh.MAT_LINEN, {"lumps": 0.1, "rings": 6, "segs": 20})
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.4
		var crack := PackedVector3Array()
		for j in 5:
			var y := lerpf(1.05, 0.38, float(j) / 4.0)
			var r := lerpf(0.43, 0.515, float(j) / 4.0) + 0.006
			var aa := a + 0.08 * sin(float(j) * 2.7 + float(i))
			crack.append(Vector3(sin(aa) * r, y, 0.02 - cos(aa) * r))
		mb.tube(crack, _pf([0.006, 0.008, 0.007, 0.008, 0.005], 1.0), 4, CRACK, DwarfMesh.MAT_LINEN, {"lumps": 0.0})
	# arms of stone, no sleeves; great fists
	for side in 2:
		var ba := B_ARM_R if side == 0 else B_ARM_L
		var sh: Vector3 = rests[ba]
		var el: Vector3 = rests[ba + 1]
		var wr: Vector3 = rests[ba + 2]
		mb.bind(ba)
		mb.blob(sh + Vector3(0, 0.02, 0), Vector3(0.13, 0.11, 0.13), Basis.IDENTITY, STONE, DwarfMesh.MAT_LINEN, {"lumps": 0.15, "rings": 7, "segs": 12})
		mb.tube(PackedVector3Array([sh, el]), _pf([0.1, 0.09], 1.0), 10, STONE_D, DwarfMesh.MAT_LINEN, {"lumps": 0.15})
		mb.bind(ba + 1)
		mb.tube(PackedVector3Array([el, wr]), _pf([0.095, 0.085], 1.0), 10, STONE_D, DwarfMesh.MAT_LINEN, {"lumps": 0.15})
		_hand_b(mb, side, true, STONE, DwarfMesh.MAT_LINEN, 1.0, 0.02)
	# the speaking-horn for a head: out of the neck, forward and up, flaring to a wide bell, its throat dark and lit
	mb.bind(B_HEAD)
	var c := hc
	# the horn rises out of the shoulders and opens to the sky, tipped a little forward (a gramophone): from the ground
	# you see its bronze flank and the light in its throat (flaring toward you, its inside faces were culled and only
	# the rim showed)
	var horn := PackedVector3Array([c + Vector3(0, -0.06, 0.06), c + Vector3(0, 0.04, 0.0), c + Vector3(0, 0.16, -0.04), c + Vector3(0, 0.3, -0.09), c + Vector3(0, 0.42, -0.15)])
	mb.tube(horn, _pf([0.1, 0.1, 0.12, 0.19, 0.32], 1.0), 22, BRONZE, DwarfMesh.MAT_METAL, {"lumps": 0.03, "caps": false, "ripple": Vector2(0.02, 6.0)})
	var inner := PackedVector3Array()
	for i in range(horn.size() - 1, -1, -1):
		inner.append(horn[i])
	mb.tube(inner, _pf([0.3, 0.175, 0.11, 0.09, 0.09], 1.0), 22, BRONZE.darkened(0.2), DwarfMesh.MAT_METAL, {"lumps": 0.0, "caps": false})
	var facing := Basis(Quaternion(Vector3.UP, (horn[4] - horn[3]).normalized()))
	mb.ring(horn[4], Vector2(0.325, 0.325), 0.022, 0.03, facing, BRONZE.lightened(0.15), DwarfMesh.MAT_METAL, 28)
	mb.blob(c + Vector3(0, 0.14, -0.035), Vector3(0.1, 0.03, 0.1), facing, HOLLOW, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 5, "segs": 12})

	_ornament(mb)


## Tertiary forms: bronze bands and studs on the cope, a chain at the waist with hung bells, lichen on the shoulders and fists,
## chips knocked from the hem, a cord of prayer-flags round the horn's throat.
func _ornament(mb: Variant) -> void:
	mb.bind(B_CHEST)
	for y: float in [0.92, 0.64]:
		var r := 0.41 + (1.08 - y) * 0.25
		mb.ring(Vector3(0, y, 0.02), Vector2(r + 0.012, r + 0.012), 0.016, 0.05, Basis.IDENTITY, BRONZE, DwarfMesh.MAT_METAL, 30)
	for i in 14:
		var a := TAU * float(i) / 14.0 + 0.2
		var r := 0.42 + 0.02
		mb.blob(Vector3(sin(a) * r, 0.92, 0.02 - cos(a) * r), Vector3(0.022, 0.022, 0.02), Basis.IDENTITY, BRONZE.lightened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 8})
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.9
		var r := 0.48
		mb.tube(PackedVector3Array([Vector3(sin(a) * r, 0.66, 0.02 - cos(a) * r), Vector3(sin(a) * (r + 0.02), 0.58, 0.02 - cos(a) * (r + 0.02))]), _pf([0.006, 0.004], 1.0), 4, BRONZE, DwarfMesh.MAT_METAL, {"lumps": 0.0})
		mb.blob(Vector3(sin(a) * (r + 0.02), 0.55, 0.02 - cos(a) * (r + 0.02)), Vector3(0.026, 0.034, 0.026), Basis.IDENTITY, BRONZE, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 5, "segs": 8})
	var lichen := Color(0.34, 0.42, 0.26)
	for s: float in [-1.0, 1.0]:
		mb.blob(Vector3(s * 0.26, 1.25, -0.04), Vector3(0.1, 0.03, 0.08), Basis(Vector3.BACK, s * 0.3), lichen, DwarfMesh.MAT_CLOTH, {"lumps": 0.4, "rings": 4, "segs": 8})
		mb.blob(Vector3(s * 0.12, 1.28, 0.1), Vector3(0.06, 0.025, 0.05), Basis.IDENTITY, lichen, DwarfMesh.MAT_CLOTH, {"lumps": 0.4, "rings": 4, "segs": 8})
		mb.blob(Vector3(s * 0.38, 0.55, 0.1), Vector3(0.06, 0.12, 0.04), Basis.IDENTITY, STONE_D.darkened(0.25), DwarfMesh.MAT_LINEN, {"lumps": 0.4, "rings": 4, "segs": 8})    # a chip out of the hem
	mb.bind(B_HEAD)
	var c := hc
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p := c + Vector3(sin(a) * 0.12, 0.0, 0.02 + cos(a) * 0.1)
		mb.tube(PackedVector3Array([p, p + Vector3(0.0, -0.1, 0.0), p + Vector3(sin(a) * 0.02, -0.17, 0.0)]), _pf([0.008, 0.007, 0.003], 1.0), 4, CRACK.darkened(0.3), DwarfMesh.MAT_CLOTH, {"lumps": 0.0})


func _layout_glints() -> void:
	glints.append([B_HEAD, hc + Vector3(0, 0.2, -0.06), 0.07, VOICE])
	muzzle_at = [B_HEAD, hc + Vector3(0, 0.42, -0.15)]

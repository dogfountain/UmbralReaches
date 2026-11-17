extends "res://core/enemy/boss_body.gd"
## The Ascended Warden in the villagers' style, to its own design: a tall hollowed priest that floats (no step, the
## bell of its robe clear of the floor), ivory and gold; a smooth gold mask with light in its eye slits under an ivory
## hood; a great gold mandorla of rays behind its head (its halo, the weak point); long hanging sleeves, gilded hands.
## No class_name (project rule): const WardenBody := preload("res://core/enemy/warden_body.gd")

const IVORY := Color(0.82, 0.78, 0.68)
const GOLD := Color(0.8, 0.6, 0.26)
const LINING := Color(0.3, 0.34, 0.44)
const LIGHT := Color(1.0, 0.93, 0.72)
const BELL := [0.17, 0.23, 0.33, 0.45, 0.55, 0.61]      ## the robe's radius from the waist (1.0) to the hem (0.04)


func _joints() -> Dictionary:
	return {"pelvis": Vector3(0, 1.0, 0), "chest": Vector3(0, 1.32, 0), "neck": Vector3(0, 1.58, 0), "head": Vector3(0, 1.69, -0.01),
		"shoulder": Vector3(0.21, 1.5, 0.0), "elbow": Vector3(0.27, 1.18, 0.02), "wrist": Vector3(0.3, 0.88, -0.02),
		"hip": Vector3(0.09, 0.96, 0.0), "knee": Vector3(0.1, 0.55, 0.0), "ankle": Vector3(0.1, 0.12, 0.0)}


func _body_v(mb: Variant) -> void:
	# the bell: from the waist to the hem, rigid on the hips (it floats; nothing steps under it), gold bands near the hem
	mb.bind(B_SPINE)
	var pts := PackedVector3Array()
	for i in BELL.size():
		pts.append(Vector3(0, lerpf(1.02, 0.04, float(i) / float(BELL.size() - 1)), 0))
	mb.tube(pts, _pf(BELL, 1.0), 32, IVORY, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.04, 12.0), "lumps": 0.03, "caps": false})
	mb.blob(Vector3(0, 0.09, 0), Vector3(0.58, 0.02, 0.58), Basis.IDENTITY, HOLLOW, DwarfMesh.MAT_CLOTH, {"lumps": 0.0, "rings": 4, "segs": 24})
	for y: float in [0.12, 0.2]:
		mb.ring(Vector3(0, y, 0), Vector2.ONE * (_bell_r(y) + 0.008), 0.012, 0.03 if y < 0.15 else 0.014, Basis.IDENTITY, GOLD, DwarfMesh.MAT_METAL, 32)
	# a gold band down the front, from the throat to the hem
	var band := PackedVector3Array()
	for y: float in [1.52, 1.3, 1.02, 0.8, 0.55, 0.3, 0.08]:
		band.append(Vector3(0, y, -(_front_r(y) + 0.008)))
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, 1.05, 0), Vector3(0, 1.3, 0))
	mb.tube(band, _pf(_rep(0.045, band.size()), 1.0), 6, GOLD, DwarfMesh.MAT_METAL, {"squash": Vector2(1.0, 0.18), "ref": Vector3.FORWARD, "lumps": 0.0})
	_torso_b(mb, [[1.58, 0.1, 0.08, 0.0], [1.5, 0.2, 0.12, 0.0], [1.32, 0.18, 0.12, 0.0], [1.12, 0.15, 0.11, 0.0], [0.98, 0.17, 0.12, 0.0]], IVORY)
	# a stiff gold collar over the shoulders
	mb.bind(B_CHEST)
	mb.blob(Vector3(0, 1.47, 0), Vector3(0.29, 0.09, 0.2), Basis.IDENTITY, GOLD, DwarfMesh.MAT_METAL, {"phi": Vector2(0.0, 0.55), "lumps": 0.02, "rings": 7, "segs": 24})
	# the mandorla: an almond of gold behind the head, rays standing out of it
	var mc := Vector3(0, 1.74, 0.2)
	var up_b := Basis(Vector3.RIGHT, PI * 0.5)
	mb.ring(mc, Vector2(0.4, 0.5), 0.024, 0.03, up_b, GOLD, DwarfMesh.MAT_METAL, 36)
	mb.ring(mc, Vector2(0.3, 0.38), 0.012, 0.02, up_b, GOLD.lightened(0.1), DwarfMesh.MAT_METAL, 30)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var d := Vector3(sin(a) * 0.4, cos(a) * 0.5, 0)
		var ln := 0.16 if i % 2 == 0 else 0.09
		mb.tube(PackedVector3Array([mc + d, mc + d * (1.0 + ln / d.length())]), _pf([0.018, 0.003], 1.0), 5, GOLD, DwarfMesh.MAT_METAL, {"lumps": 0.0})
	# the hood and the mask
	mb.bind(B_HEAD)
	var c := hc
	mb.tube(PackedVector3Array([c + Vector3(0, 0.03, 0.11), c + Vector3(0, 0.035, 0.0), c + Vector3(0, 0.02, -0.1)]), _pf([0.12, 0.15, 0.13], 1.0), 20, IVORY, DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 1.25), "ref": Vector3.UP, "lumps": 0.04, "caps": false})
	mb.blob(c + Vector3(0, 0.03, 0.11), Vector3(0.12, 0.15, 0.05), Basis.IDENTITY, IVORY, DwarfMesh.MAT_CLOTH, {"lumps": 0.03, "rings": 8, "segs": 16})
	mb.blob(c + Vector3(0, 0.0, -0.035), Vector3(0.082, 0.112, 0.07), Basis.IDENTITY, GOLD.lightened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 10, "segs": 18})
	for s: float in [-1.0, 1.0]:
		mb.blob(c + Vector3(s * 0.033, 0.015, -0.1), Vector3(0.024, 0.006, 0.006), Basis(Vector3.BACK, s * 0.15), HOLLOW, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 8})
	# long hanging sleeves, the lining showing at the cuff; gilded hands, open
	for side in 2:
		_sleeve_v(mb, side, 0.07, 0.17, IVORY, 0.85)
		_hand_b(mb, side, false, GOLD.lightened(0.2), DwarfMesh.MAT_METAL, 1.1, 0.009)


func _bell_r(y: float) -> float:
	var t := clampf((1.02 - y) / 0.98, 0.0, 1.0) * float(BELL.size() - 1)
	var i := mini(int(t), BELL.size() - 2)
	return lerpf(float(BELL[i]), float(BELL[i + 1]), t - float(i))


func _front_r(y: float) -> float:
	if y > 1.02:
		return lerpf(0.12, 0.08, clampf((y - 1.3) / 0.28, 0.0, 1.0)) if y > 1.3 else 0.12
	return _bell_r(y)


func _layout_glints() -> void:
	for s: float in [-1.0, 1.0]:
		glints.append([B_HEAD, hc + Vector3(s * 0.033, 0.015, -0.104), 0.008, LIGHT])
	muzzle_at = [B_HEAD, hc + Vector3(0, 0.0, -0.12)]

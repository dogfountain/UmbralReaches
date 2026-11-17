extends "res://core/life/village/villager_rig.gd"
## The base of a boss built in the villagers' style (17 Nov, Luke: "simple like the villager", "the style, not the exact
## look", "have some creativity"): VillagerRig's skeleton, soft skinning, shader, detail maps and GenCache, with the
## boss's own proportions and body. A body script extends this and overrides:
##   _joints()          the skeleton at rest (model space before SCALE, front -Z, the floor at y 0)
##   _body_v(mb)        the mesh, in DwarfMesh / VMesh primitives (lofts, tubes, lumpy blobs, rings)
##   _layout_glints()   glowing points ([bone, rest point, radius, colour]) and `muzzle_at`, lit by VillagerBossRig
## Built by `Body.new().made(opts)` (opts: VillagerRig KEYS, usually just a seed).
## No class_name (project rule): const BossBody := preload("res://core/enemy/boss_body.gd")

const BONE := Color(0.72, 0.67, 0.56)
const HOLLOW := Color(0.02, 0.015, 0.016)
const GILT := Color(0.7, 0.5, 0.2)
const IRON_D := Color(0.16, 0.15, 0.15)
const EMBER := Color(1.0, 0.5, 0.15)
const FLAME := Color(1.0, 0.72, 0.32)

## Glowing points the boss rig carries: [bone, rest point, radius, colour].
var glints: Array = []
## Where spells leave from: [bone, rest point]; empty = the head.
var muzzle_at: Array = []
var _j := {}


func made(opts: Dictionary) -> Node3D:
	name = "Rig"
	_build(opts)
	return self


## The skeleton at rest. Keys: pelvis, chest, neck (head bone), head (head centre), shoulder, elbow, wrist (the right
## side: the left is mirrored), hip, knee (right), ankle (right). All Vector3.
func _joints() -> Dictionary:
	return {}


func _layout_glints() -> void:
	pass


func _prep(opts: Dictionary) -> String:
	var key := super(opts)
	var path: String = (get_script() as Script).resource_path
	_key = "boss|%s|%s|%d|%d" % [path.get_file(), key, GenCache.salt(path), GenCache.salt("res://core/enemy/boss_body.gd")]
	glints.clear()
	muzzle_at = []
	_layout_glints()
	return _key


func _rest_layout() -> void:
	_j = _joints()
	var m := func(v: Vector3) -> Vector3:
		return Vector3(-v.x, v.y, v.z)
	P = (_j.pelvis as Vector3).y
	hc = _j.head
	rests.clear()
	rests = [Vector3.ZERO, _j.pelvis, _j.chest, _j.neck, hc + Vector3(0, -0.04, -0.035) * hs,
		_j.shoulder, _j.elbow, _j.wrist, m.call(_j.shoulder), m.call(_j.elbow), m.call(_j.wrist),
		_j.hip, _j.knee, m.call(_j.hip), m.call(_j.knee), Vector3.ZERO]
	_face = null
	var fc: Variant = face()
	rests[B_LID] = fc.lid_pivot()
	mouth = fc.point(0.0, fc.mouth_y)
	mug_rim = mouth
	mug_base = mouth
	_q.clear()
	_gq.clear()
	_gp.clear()
	for i in BONES.size():
		_q.append(Quaternion.IDENTITY)
		_gq.append(Quaternion.IDENTITY)
		_gp.append(rests[i])
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		var ba := B_ARM_R if side == 0 else B_ARM_L
		var w: Vector3 = rests[ba + 2]
		var fo: Vector3 = (w - rests[ba + 1]).normalized()
		var pn := Vector3(-s, 0, 0).slide(fo).normalized()
		grip[side] = w + fo * 0.07 + pn * 0.04
		grip_ax[side] = fo.cross(pn).normalized() * s
		grip_up[side] = fo


func ankle(s: float) -> Vector3:
	var a: Vector3 = _j.get("ankle", Vector3(0.1, 0.075, 0.012))
	return Vector3(s * a.x, a.y, a.z)


# =====================================================================================================
# shared helpers
# =====================================================================================================

static func _rep(v: float, n: int) -> Array:
	var a := []
	for i in n:
		a.append(v)
	return a


## A long garment from y `top` to the floor, skirt-skinned (it follows the stride), pleated, the hem in tatters.
func _skirt(mb: Variant, top: float, radii: Array, col: Color, tatters := 22, z := 0.0) -> void:
	mb.bind_skirt(top - 0.04, 0.1, 0.7, 0.14)
	var pts := PackedVector3Array()
	var n := radii.size()
	for i in n:
		pts.append(Vector3(0, lerpf(top, 0.03, float(i) / float(n - 1)), z))
	mb.tube(pts, _pf(radii, 1.0), 30, col, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.05, 10.0), "lumps": 0.04, "caps": false})
	var r: float = radii[n - 1]
	for i in tatters:
		var a := TAU * float(i) / float(tatters) + 0.07 * sin(float(i) * 3.1)
		var dir := Vector3(sin(a), 0, -cos(a))
		var t0 := Vector3(0, 0.06, z) + dir * (r - 0.005)
		var ln := 0.05 + 0.06 * absf(sin(float(i) * 2.3))
		mb.tube(PackedVector3Array([t0, t0 + dir * 0.015 + Vector3(0, -ln * 0.6, 0), t0 + dir * 0.03 + Vector3(0, -ln, 0)]), _pf([0.05, 0.04, 0.014], 1.0), 6, col.darkened(0.12), DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 0.2), "ref": dir, "lumps": 0.12})


## A sleeve from the shoulder to near the wrist (`cuff` its radius at the end), with the elbow blended.
func _sleeve_v(mb: Variant, side: int, r_up: float, r_cuff: float, col: Color, end_t := 0.88) -> void:
	var ba := B_ARM_R if side == 0 else B_ARM_L
	var sh: Vector3 = rests[ba]
	var el: Vector3 = rests[ba + 1]
	var wr: Vector3 = rests[ba + 2]
	mb.bind(ba)
	mb.tube(PackedVector3Array([sh + Vector3(0, 0.03, 0), sh.lerp(el, 0.5), el]), _pf([r_up, r_up * 0.94, r_up * 0.96], 1.0), 12, col, DwarfMesh.MAT_CLOTH, {"lumps": 0.04, "ripple": Vector2(0.06, 6.0)})
	mb.bind_blend(ba, ba + 1, el + (sh - el) * 0.2, el + (wr - el) * 0.2)
	mb.blob(el, Vector3.ONE * r_up, Basis.IDENTITY, col, DwarfMesh.MAT_CLOTH, {"lumps": 0.04, "rings": 6, "segs": 12})
	mb.bind(ba + 1)
	var cuff := el.lerp(wr, end_t)
	mb.tube(PackedVector3Array([el, el.lerp(cuff, 0.6), cuff]), _pf([r_up, lerpf(r_up, r_cuff, 0.5), r_cuff], 1.0), 14, col, DwarfMesh.MAT_CLOTH, {"lumps": 0.05, "folds": Vector2(0.03, 6.0), "caps": false})


## A hand: a fist round the grip (`fist`) or an open hand, fingers `flen` long, in `col` and material `mat`.
func _hand_b(mb: Variant, side: int, fist: bool, col: Color, mat: int, flen := 1.0, fr := 0.009) -> void:
	var s := 1.0 if side == 0 else -1.0
	var ba := B_ARM_R if side == 0 else B_ARM_L
	var w: Vector3 = rests[ba + 2]
	var fo: Vector3 = (w - rests[ba + 1]).normalized()
	var pn := Vector3(-s, 0, 0).slide(fo).normalized()
	var ax: Vector3 = grip_ax[side]
	var g: Vector3 = grip[side]
	mb.bind(ba + 2)
	mb.blob(w + fo * 0.05, Vector3(0.042, 0.055, 0.018), Basis(ax, fo, ax.cross(fo)).orthonormalized(), col.darkened(0.05), mat, {"lumps": 0.06, "rings": 6, "segs": 10})
	for i in 4:
		var o := (float(i) - 1.5) * 0.024
		var kn := w + fo * 0.1 + ax * o
		var pts := PackedVector3Array([kn - fo * 0.012])
		if fist:
			for th: float in [0.2, 1.1, 2.0, 2.8]:
				pts.append(g + ax * o + (fo * cos(th) + pn * sin(th)) * 0.034)
		else:
			pts.append(kn + (fo * 0.045 + pn * 0.01) * flen)
			pts.append(kn + (fo * 0.085 + pn * 0.035) * flen)
			pts.append(kn + (fo * 0.105 + pn * 0.07) * flen)
		var radii: Array = [fr, fr * 0.9, fr * 0.8, fr * 0.66, fr * 0.33]
		mb.tube(pts, _pf(radii.slice(0, pts.size()), 1.0), 6, col, mat, {"lumps": 0.05})
	var tb := w + fo * 0.03 + ax * 0.03 + pn * 0.012
	var th_end := (g + ax * 0.04 + pn * 0.03) if fist else (tb + (fo * 0.07 + ax * 0.02 + pn * 0.04) * flen)
	mb.tube(PackedVector3Array([tb, tb.lerp(th_end, 0.5) + pn * 0.01, th_end]), _pf([fr * 1.1, fr * 0.9, fr * 0.45], 1.0), 6, col, mat, {"lumps": 0.05})


## A torso from the waist to the shoulders: rows [y, half width, half depth, z centre], top first.
func _torso_b(mb: Variant, rows: Array, col: Color, mat := DwarfMesh.MAT_CLOTH) -> void:
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08, 0), (rests[B_CHEST] as Vector3))
	var ys := PackedFloat32Array()
	var rx := PackedFloat32Array()
	var rz := PackedFloat32Array()
	var zc := PackedFloat32Array()
	for r: Array in rows:
		ys.append(r[0])
		rx.append(r[1])
		rz.append(r[2])
		zc.append(r[3])
	mb.loft(ys, rx, rz, zc, PackedFloat32Array(), 26, col, mat, {"folds": Vector2(0.02, 9.0), "lumps": 0.02})

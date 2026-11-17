extends "res://core/life/village/villager_rig.gd"
## The Bone Abbot in the villagers' style (17 Nov, Luke: "the style, not the exact look"): the VillagerRig's body, robe,
## hood, arms and crook (one soft-skinned procedural surface, the same shader and detail maps), with the Abbot's own
## head and trimmings built in the same primitives:
##   a skull in the hood (cranium, brow ridge, dark sockets, nasal hollow, cheekbones, a row of teeth, the mandible on
##   the jaw bone), ember eyes and candle flames as small glow parts (`glints`, carried by VillagerBossRig);
##   a crown of bone tines on a gilt circlet round the hood; a wine stole edged in gilt down the breast; candles stuck
##   on both shoulders in their own wax.
## No class_name (project rule): const AbbotBody := preload("res://core/enemy/abbot_body.gd")

const SELF_A := "res://core/enemy/abbot_body.gd"
const BONE := Color(0.72, 0.67, 0.56)
const HOLLOW := Color(0.03, 0.022, 0.022)
const GILT := Color(0.7, 0.5, 0.2)
const WINE := Color(0.34, 0.06, 0.07)
const WAX := Color(0.86, 0.82, 0.7)
const EMBER := Color(1.0, 0.55, 0.18)
const FLAME := Color(1.0, 0.72, 0.32)

## Glowing points the boss rig carries: [bone, rest point, radius, colour] (model space before SCALE).
var glints: Array = []


## Build from options (VillagerRig KEYS) on a fresh instance: `AbbotBody.new().made(opts)`.
func made(opts: Dictionary) -> Node3D:
	name = "Rig"
	_build(opts)
	return self


func _prep(opts: Dictionary) -> String:
	glints.clear()
	var key := super(opts)
	_key = "abbot1|%s|%d" % [key, GenCache.salt(SELF_A)]
	_layout_glints()
	return _key


func _hair_v(_mb: Variant, _hair: Color, _style: String, _f: bool) -> void:
	pass


## The skull (no painted face): bone, hollows and teeth; the mandible rides the jaw bone.
func _head_v(mb: Variant, _f: bool, _skin: Color, _age: String, _hair: Color) -> void:
	var R: Vector3 = face().R
	var c := hc
	var S := hs
	var o := {"lumps": 0.03, "rings": 10, "segs": 18}
	mb.bind(B_HEAD)
	mb.blob(c + Vector3(0, 0.014, 0.006) * S, Vector3(R.x * 1.04, R.y * 0.9, R.z * 1.02), Basis.IDENTITY, BONE, DwarfMesh.MAT_LINEN, o)
	mb.blob(c + Vector3(0, 0.03, 0) * S + Vector3(0, 0, -R.z * 0.84), Vector3(R.x * 0.84, 0.015 * S, 0.022 * S), Basis.IDENTITY, BONE.darkened(0.06), DwarfMesh.MAT_LINEN, o)
	for s: float in [-1.0, 1.0]:
		var e := c + Vector3(s * R.x * 0.42, 0.006 * S, -R.z * 0.86)
		mb.blob(e, Vector3(0.025, 0.022, 0.013) * S, Basis.IDENTITY, HOLLOW, DwarfMesh.MAT_LINEN, {"lumps": 0.0, "rings": 6, "segs": 10})
		mb.blob(c + Vector3(s * R.x * 0.66, -0.03 * S, -R.z * 0.7), Vector3(0.022, 0.013, 0.022) * S, Basis.IDENTITY, BONE, DwarfMesh.MAT_LINEN, o)
		mb.blob(c + Vector3(s * R.x * 0.9, -0.02 * S, -R.z * 0.2), Vector3(0.012, 0.026, 0.03) * S, Basis.IDENTITY, BONE.darkened(0.08), DwarfMesh.MAT_LINEN, o)
	mb.blob(c + Vector3(0, -0.026 * S, -R.z * 0.94), Vector3(0.011, 0.018, 0.008) * S, Basis.IDENTITY, HOLLOW, DwarfMesh.MAT_LINEN, {"lumps": 0.0, "rings": 5, "segs": 8})
	mb.blob(c + Vector3(0, -0.058 * S, -R.z * 0.7), Vector3(R.x * 0.56, 0.018 * S, 0.036 * S), Basis.IDENTITY, BONE, DwarfMesh.MAT_LINEN, o)
	for i in 8:
		var x := (float(i) - 3.5) * 0.0074 * S
		mb.blob(c + Vector3(x, -0.07 * S, -R.z * 0.86 + x * x * 7.0 / S), Vector3(0.0034, 0.0075, 0.004) * S, Basis.IDENTITY, BONE.lightened(0.1), DwarfMesh.MAT_LINEN, {"lumps": 0.0, "rings": 4, "segs": 6})
	mb.bind(B_JAW)
	var jaw := PackedVector3Array()
	for t: float in [-1.0, -0.66, -0.3, 0.0, 0.3, 0.66, 1.0]:
		var a := t * 1.25
		jaw.append(c + Vector3(sin(a) * R.x * 0.78, -0.098 * S + absf(t) * 0.05 * S, -cos(a) * R.z * 0.78))
	mb.tube(jaw, _pf([0.01, 0.012, 0.013, 0.014, 0.013, 0.012, 0.01], S), 7, BONE.darkened(0.04), DwarfMesh.MAT_LINEN, {"lumps": 0.02})
	for i in 7:
		var x := (float(i) - 3.0) * 0.0074 * S
		mb.blob(c + Vector3(x, -0.082 * S, -R.z * 0.82 + x * x * 7.0 / S), Vector3(0.0032, 0.007, 0.004) * S, Basis.IDENTITY, BONE.lightened(0.08), DwarfMesh.MAT_LINEN, {"lumps": 0.0, "rings": 4, "segs": 6})


## The glints' rest points (the eyes deep in the sockets, a flame on each candle): set with the layout, so a mesh from
## GenCache has them too.
func _layout_glints() -> void:
	var R: Vector3 = face().R
	for s: float in [-1.0, 1.0]:
		glints.append([B_HEAD, hc + Vector3(s * R.x * 0.42, 0.004 * hs, -R.z * 0.97), 0.0095 * hs, EMBER])     # proud of the hollow
	for cd: Array in _candles():
		glints.append([B_CHEST, (cd[0] as Vector3) + Vector3(0, float(cd[1]) + 0.016 * k, 0), 0.008 * k, FLAME])


## Candles on the shoulders: [base point, height] (on the capelet's top, model space).
func _candles() -> Array:
	var out := []
	for s: float in [-1.0, 1.0]:
		for e: Array in [[0.13, 0.0, 0.075], [0.16, 0.03, 0.05], [0.115, 0.035, 0.035]]:
			var x := float(e[0])
			var z := float(e[1])
			var top := 1.24 + 0.07 * sqrt(maxf(0.0, 1.0 - (x / 0.2) * (x / 0.2) - ((z - 0.02) / 0.16) * ((z - 0.02) / 0.16)))   # the capelet's crown
			out.append([Vector3(s * x, top - 0.003, z) * k, float(e[2]) * k])
	return out


func _body_v(mb: Variant) -> void:
	super(mb)
	var c := hc
	var S := hs
	# the crown: a gilt circlet round the hood above the brow, a fan of bone tines rising from it, tallest over the face
	mb.bind(B_HEAD)
	mb.ring(c + Vector3(0, 0.06, 0.018) * S, Vector2(0.123, 0.13) * S, 0.009 * S, 0.012 * S, Basis.IDENTITY, GILT, DwarfMesh.MAT_METAL, 22)
	for i in 9:
		var a := lerpf(-1.9, 1.9, float(i) / 8.0)
		var h := (0.05 + 0.1 * pow(cos(a / 1.9 * PI * 0.5), 1.4)) * S
		var base := c + Vector3(sin(a) * 0.123, 0.064, 0.018 - cos(a) * 0.13) * S
		var out_d := Vector3(sin(a), 0, -cos(a))
		mb.tube(PackedVector3Array([base, base + Vector3(0, h * 0.5, 0) + out_d * 0.012 * S, base + Vector3(0, h, 0) + out_d * 0.006 * S]), _pf([0.009, 0.006, 0.0015], S), 6, BONE, DwarfMesh.MAT_LINEN, {"lumps": 0.04})
	# the stole: two wine bands from the neck down the breast to below the cord, gilt at the edges and the ends
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08 * k, 0), Vector3(0, P + 0.26 * k, 0))
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		for y: float in [1.2, 1.1, 0.98, 0.88, 0.8]:
			var dir := Vector3(s * 0.35, 0, -1).normalized()
			pts.append(Vector3(0, y * k, 0) + dir * (_env(dir, y * k) + 0.022 * k) + Vector3(s * 0.012 * k, 0, 0))
		# flat against the breast: thin along the normal (`ref`), wide across (edge-on they stood off it as four bars)
		var nrm := Vector3(s * 0.35, 0, -1).normalized()
		mb.tube(pts, _pf([0.032, 0.032, 0.032, 0.032, 0.032], k), 8, WINE.lightened(0.08), DwarfMesh.MAT_CLOTH, {"squash": Vector2(1.0, 0.16), "ref": nrm, "lumps": 0.0, "caps": true})
		mb.tube(PackedVector3Array([pts[3].lerp(pts[4], 0.55), pts[4]]), _pf([0.034, 0.034], k), 8, GILT, DwarfMesh.MAT_METAL, {"squash": Vector2(1.0, 0.2), "ref": nrm, "lumps": 0.0})
	# candles stuck on the shoulders in their own wax
	mb.bind(B_CHEST)
	for cd: Array in _candles():
		var b: Vector3 = cd[0]
		var ht: float = cd[1]
		mb.blob(b, Vector3(0.024, 0.008, 0.022) * k, Basis.IDENTITY, WAX.darkened(0.08), DwarfMesh.MAT_LINEN, {"lumps": 0.2, "rings": 5, "segs": 10})
		mb.tube(PackedVector3Array([b, b + Vector3(0, ht, 0)]), _pf([0.011, 0.01], k), 8, WAX, DwarfMesh.MAT_LINEN, {"lumps": 0.03})
		mb.tube(PackedVector3Array([b + Vector3(0.009 * k, ht * 0.8, 0), b + Vector3(0.011 * k, ht * 0.45, 0.002 * k)]), _pf([0.004, 0.003], k), 4, WAX, DwarfMesh.MAT_LINEN, {"lumps": 0.0})

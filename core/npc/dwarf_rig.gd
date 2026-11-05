class_name DwarfRig
extends Node3D
## A procedural dwarf on a 15-bone runtime skeleton:
##   root, spine (pelvis), chest, head, jaw, arm/fore/hand x2, thigh/shin x2.
## Built by DwarfMesh (core/npc/dwarf_mesh.gd) and shaded by dwarf.gdshader with procedural detail
## maps (DwarfLook): a face with a heavy brow, lidded eyes (sclera, iris, pupil), a bulbous nose
## with nostrils, ruddy cheeks, ears and a lower lip on the jaw; a layered beard (jaw mass, chest
## mass, dozens of strands, a drooping moustache, bushy brows, sideburns, iron-ringed braids or a
## fork); hats (riveted helm, hood with cowl and tail, felt cap) or bare heads (bald pate with a
## fringe, or a mane); a pleated wool tunic with patches, a buckled belt, a pouch and a knife; sleeves
## with rolled cuffs or laced bracers; fists with fingers round a staved, hooped tankard with a foam
## head; trousers with knee wrinkles; boots with cuffs, straps, toe caps and soles.
## Soft skinning at the elbows, knees and the beard (jaw -> chest). Ambient occlusion is baked into
## the vertex colour. ONE skinned surface with LODs: 1 draw per dwarf, cached through GenCache.
## Front is -Z, the origin is on the floor; a seated dwarf sits on a 0.47 m seat (`SEAT`).
## Animate with `q()` / `arm_to()` / `apply()` (DwarfNpc, Bartender).

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const DwarfMesh := preload("res://core/npc/dwarf_mesh.gd")
const DwarfLook := preload("res://core/npc/dwarf_look.gd")
const SELF := "res://core/npc/dwarf_rig.gd"
const MESH_SRC := "res://core/npc/dwarf_mesh.gd"

const Face := preload("res://core/npc/npc_face.gd")
const FACE_SRC := "res://core/npc/npc_face.gd"

const BONES := ["root", "spine", "chest", "head", "jaw", "arm_r", "fore_r", "hand_r", "arm_l", "fore_l", "hand_l", "thigh_r", "shin_r", "thigh_l", "shin_l", "lid"]
const PARENT := [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 0, 13, 3]
enum { B_ROOT, B_SPINE, B_CHEST, B_HEAD, B_JAW, B_ARM_R, B_FORE_R, B_HAND_R, B_ARM_L, B_FORE_L, B_HAND_L, B_THIGH_R, B_SHIN_R, B_THIGH_L, B_SHIN_L, B_LID }

const SEAT := 0.47              ## seat top a seated dwarf rests on (bench and chair)
const H := 0.57                 ## pelvis height (seated and standing alike)

# palettes, authored in sRGB (dwarf.gdshader converts): deep enough to hold colour under the grade
## Tunics are madder, moss, ochre, woad, russet, teal, slate and rust: deep and only moderately
## saturated, so the grade's x1.42 saturation lands them at "dyed wool" rather than neon orange,
## while warm ones keep enough chroma (> 0.4) to stay out of the azure pull.
const TUNICS := [Color(0.56, 0.27, 0.14), Color(0.27, 0.42, 0.22), Color(0.62, 0.47, 0.2), Color(0.24, 0.32, 0.52), Color(0.5, 0.33, 0.19), Color(0.18, 0.4, 0.38), Color(0.4, 0.38, 0.42), Color(0.48, 0.22, 0.12)]
const TROUSERS := [Color(0.36, 0.25, 0.15), Color(0.34, 0.33, 0.34), Color(0.24, 0.28, 0.17), Color(0.2, 0.22, 0.32), Color(0.44, 0.33, 0.2)]
## greys and whites are warm (ivory, ash-brown): neutral greys fall into the grade's azure band
const BEARDS := [Color(0.6, 0.28, 0.1), Color(0.1, 0.075, 0.06), Color(0.54, 0.47, 0.4), Color(0.84, 0.77, 0.64), Color(0.44, 0.17, 0.06), Color(0.72, 0.54, 0.26), Color(0.32, 0.18, 0.08)]
const SKINS := [Color(0.84, 0.6, 0.43), Color(0.76, 0.55, 0.37), Color(0.64, 0.46, 0.3), Color(0.86, 0.68, 0.5), Color(0.52, 0.37, 0.23)]
const EYES := [Color(0.27, 0.16, 0.07), Color(0.2, 0.34, 0.48), Color(0.3, 0.34, 0.2), Color(0.32, 0.32, 0.34)]
const LEATHERS := [Color(0.5, 0.3, 0.15), Color(0.38, 0.23, 0.11), Color(0.6, 0.4, 0.2)]
const LINEN := Color(0.7, 0.6, 0.45)
const IRON := Color(0.45, 0.45, 0.48)
const BRASS := Color(0.78, 0.58, 0.24)
const WOOD := Color(0.5, 0.32, 0.16)
const FOAM := Color(0.97, 0.93, 0.82)

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var seated := true
var rests: Array[Vector3] = []          ## bone rest positions, model space
var mouth := Vector3.ZERO               ## lips at rest (model space)
var mug_rim := Vector3.ZERO             ## the tankard's rim nearest the face, at rest
var mug_base := Vector3.ZERO            ## bottom centre of the tankard, at rest
var has_mug := true
var hips := H                          ## compatibility (old callers)
var _q: Array[Quaternion] = []
var _gq: Array[Quaternion] = []
var _gp: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _key := ""
var _o := {}                            ## build options


## opts: seated (bool), seed (int), apron (bool), hat ("helm"/"hood"/"cap"/"bare"/"" = random),
## rag (bool: a cloth in the left hand, the keep), mug (bool, default true)
static func make(opts := {}) -> DwarfRig:
	var r := DwarfRig.new()
	r.name = "Rig"
	r._build(opts)
	return r


func _build(opts: Dictionary) -> void:
	_o = opts
	seated = bool(opts.get("seated", true))
	has_mug = bool(opts.get("mug", true))
	var sd := int(opts.get("seed", 1))
	_rng.seed = sd
	var hat := String(opts.get("hat", ""))
	_rest_layout()
	_key = "dwarf4|%s|%d|%s|%s|%s|%s|%d" % [seated, sd, opts.get("apron", false), hat, opts.get("rag", false), has_mug, GenCache.salt(MESH_SRC) ^ GenCache.salt(FACE_SRC)]
	var mesh := GenCache.load_mesh(_key, SELF)
	if mesh == null:
		var t0 := Time.get_ticks_msec()
		var mb := DwarfMesh.new(sd)
		_body(mb, hat)
		mb.bake_ao()
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mb.arrays(), [], {}, null, "dwarf")
		im.generate_lods(25.0, 60.0, [])
		mesh = im.get_mesh()
		GenCache.save_mesh(_key, SELF, mesh)
		print("DWARF built %s: %d verts in %d ms" % [_key.get_slice("|", 2), mb.vertex_count(), Time.get_ticks_msec() - t0])
	mesh.surface_set_material(0, DwarfLook.material())
	_assemble(mesh)


func _rest_layout() -> void:
	rests.clear()
	var arm := func(s: float) -> Array:
		return [Vector3(s * 0.25, H + 0.5, 0.02), Vector3(s * 0.31, H + 0.25, 0.05), Vector3(s * 0.28, H + 0.17, -0.19)]
	var leg := func(s: float) -> Array:
		if seated:
			return [Vector3(s * 0.12, H - 0.035, 0.0), Vector3(s * 0.14, 0.51, -0.31)]
		return [Vector3(s * 0.12, H - 0.035, 0.0), Vector3(s * 0.13, 0.31, -0.02)]
	var ar: Array = arm.call(1.0)
	var al: Array = arm.call(-1.0)
	var lr: Array = leg.call(1.0)
	var ll: Array = leg.call(-1.0)
	rests = [Vector3.ZERO, Vector3(0, H, 0), Vector3(0, H + 0.3, 0.01), Vector3(0, H + 0.64, -0.01), Vector3(0, H + 0.73, -0.05),
		ar[0], ar[1], ar[2], al[0], al[1], al[2], lr[0], lr[1], ll[0], ll[1], Vector3.ZERO]
	var fc: Variant = face()
	rests[B_LID] = fc.lid_pivot()
	mouth = fc.point(0.0, fc.mouth_y) + Vector3(0, 0, -0.012)
	_mug_center()
	_q.clear()
	_gq.clear()
	_gp.clear()
	for i in BONES.size():
		_q.append(Quaternion.IDENTITY)
		_gq.append(Quaternion.IDENTITY)
		_gp.append(rests[i])


func ankle(s: float) -> Vector3:
	return Vector3(s * 0.14, 0.1, -0.33) if seated else Vector3(s * 0.13, 0.095, 0.0)


func head_top() -> float:
	return H + 0.81 + 0.16


var _face: Variant = null

## The sculpted face (npc_face.gd) for this dwarf: a broad skull, a heavy brow, a big round nose,
## full ruddy cheeks; proportions vary by seed (its own generator, so a cached mesh and a fresh
## build agree on the lid pivot and the lips).
func face() -> Variant:
	if _face != null:
		return _face
	var r := RandomNumberGenerator.new()
	r.seed = int(_o.get("seed", 1)) * 7919 + 13
	var f: Variant = Face.new()
	f.c = Vector3(0, H + 0.81, -0.03)
	f.R = Vector3(0.135, 0.15, 0.145)
	f.mouth_y = -0.55
	f.eye_x = 0.37
	f.eye_y = 0.1
	f.brow = r.randf_range(1.3, 1.8)
	f.nose = r.randf_range(0.95, 1.2)
	f.nose_w = r.randf_range(1.1, 1.35)
	f.bulb = r.randf_range(1.0, 1.5)
	f.hook = r.randf_range(0.0, 0.3)
	f.cheek = r.randf_range(0.6, 0.9)
	f.fat = r.randf_range(0.5, 1.0)
	f.jaw = r.randf_range(0.8, 0.9)
	f.chin = 0.8
	f.lip = r.randf_range(0.85, 1.05)
	f.age = r.randf_range(0.2, 0.8)
	f.b_head = B_HEAD
	f.b_jaw = B_JAW
	f.b_lid = B_LID
	_face = f
	return f


# =====================================================================================================
# the body
# =====================================================================================================

func _pick(a: Array) -> Variant:
	return a[_rng.randi_range(0, a.size() - 1)]


func _body(mb: Variant, hat: String) -> void:
	var tunic: Color = _pick(TUNICS)
	var trouser: Color = _pick(TROUSERS)
	var beard: Color = _pick(BEARDS)
	var skin: Color = _pick(SKINS)
	var eye: Color = _pick(EYES)
	var leather: Color = _pick(LEATHERS)
	if hat == "":
		hat = String(_pick(["helm", "hood", "cap", "bare", "bare"]))
	var belly := _rng.randf_range(0.92, 1.12) if not _o.get("apron", false) else 0.95
	var long := _rng.randf()
	var style := _rng.randi_range(0, 2)            # 0 one braid, 1 forked, 2 full and broad
	var shirt := bool(_rng.randf() < 0.45)         # linen shirt sleeves under a sleeveless tunic
	var fur := bool(_rng.randf() < 0.3) and hat != "hood"
	var bracers := bool(_rng.randf() < 0.4)
	if _o.get("apron", false):
		shirt = true
		fur = false
	_torso(mb, tunic, leather, belly, shirt, fur)
	_head(mb, skin, eye, beard)
	_beard(mb, beard, long, style)
	_hat(mb, hat, tunic, beard, leather)
	_arms(mb, tunic, skin, leather, shirt, bracers)
	_legs(mb, trouser, leather)
	if has_mug:
		_mug(mb)
	if _o.get("rag", false):
		_rag(mb)


func _torso(mb: Variant, tunic: Color, leather: Color, belly: float, shirt: bool, fur: bool) -> void:
	# chest (spine -> chest), belly (spine), pleated skirt (spine)
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, H + 0.12, 0), Vector3(0, H + 0.32, 0))
	mb.blob(Vector3(0, H + 0.36, 0.0), Vector3(0.255, 0.27, 0.205), Basis.IDENTITY, tunic, DwarfMesh.MAT_CLOTH, {"rings": 12, "segs": 22, "lumps": 0.012, "folds": Vector3(0.015, 9.0, 0.55)})
	mb.bind(B_SPINE)
	mb.blob(Vector3(0, H + 0.16, -0.035), Vector3(0.245, 0.2, 0.226) * belly, Basis.IDENTITY, tunic.darkened(0.05), DwarfMesh.MAT_CLOTH, {"rings": 10, "segs": 22, "lumps": 0.012})
	var hem := H - (0.08 if seated else 0.17)
	var skirt := PackedVector3Array([Vector3(0, H + 0.1, -0.05), Vector3(0, H + 0.02, -0.05), Vector3(0, hem + 0.04, -0.045), Vector3(0, hem, -0.045)])
	var flare := 0.272 if not seated else 0.255
	mb.tube(skirt, PackedFloat32Array([0.222, 0.238, flare - 0.006, flare]), 26, tunic.darkened(0.12), DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.06, 9.0), "lumps": 0.02, "caps": false, "ao": 0.85})
	# hem binding: a darker band round the skirt's foot
	mb.tube(PackedVector3Array([Vector3(0, hem + 0.025, -0.045), Vector3(0, hem - 0.005, -0.045)]), PackedFloat32Array([flare + 0.004, flare + 0.006]), 26, tunic.darkened(0.3), DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.06, 9.0), "lumps": 0.02, "caps": false})
	# belt: follows the body round the waist, a brass buckle, the tongue end hanging
	var by := H + 0.085
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 29:
		var a := TAU * float(i) / 28.0
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var r := _body_r(dir, by, belly) + 0.012
		pts.append(Vector3(0, by, -0.035) + dir * r)
		rr.append(0.013)
	mb.tube(pts, rr, 6, leather, DwarfMesh.MAT_LEATHER, {"squash": Vector2(1.0, 2.6), "lumps": 0.0, "caps": false, "ref": Vector3.UP})
	var front: Vector3 = pts[0] + Vector3(0, 0, -0.012)
	for e: Array in [[Vector3(-0.034, 0.03, 0), Vector3(0.034, 0.03, 0)], [Vector3(-0.034, -0.03, 0), Vector3(0.034, -0.03, 0)], [Vector3(-0.034, -0.03, 0), Vector3(-0.034, 0.03, 0)], [Vector3(0.034, -0.03, 0), Vector3(0.034, 0.03, 0)], [Vector3(0, -0.026, -0.004), Vector3(0, 0.026, -0.004)]]:
		mb.tube(PackedVector3Array([front + e[0], front + e[1]]), PackedFloat32Array([0.0065, 0.0065]), 6, BRASS, DwarfMesh.MAT_METAL, {"lumps": 0.0})
	var tip := front + Vector3(-0.05, -0.005, -0.004)
	mb.tube(PackedVector3Array([tip, tip + Vector3(-0.025, -0.04, -0.006), tip + Vector3(-0.03, -0.1, -0.004)]), PackedFloat32Array([0.012, 0.012, 0.011]), 6, leather.darkened(0.08), DwarfMesh.MAT_LEATHER, {"squash": Vector2(0.45, 1.0), "lumps": 0.0})
	# pouch (right hip) and knife (left hip)
	var pdir := Vector3(sin(0.75 * PI), 0, -cos(0.75 * PI))
	pdir = Vector3(sin(1.15), 0, -cos(1.15))
	var pc := Vector3(0, by - 0.07, -0.035) + pdir * (_body_r(pdir, by, belly) + 0.04)
	var pb := Basis.looking_at(-pdir, Vector3.UP)
	mb.blob(pc, Vector3(0.055, 0.06, 0.03), pb, leather.lightened(0.06), DwarfMesh.MAT_LEATHER, {"lumps": 0.12, "rings": 8, "segs": 12, "ao": 0.9})
	mb.blob(pc + Vector3(0, 0.035, 0) + pdir * 0.012, Vector3(0.058, 0.03, 0.025), pb, leather.darkened(0.05), DwarfMesh.MAT_LEATHER, {"lumps": 0.04, "rings": 6, "segs": 12})
	mb.blob(pc + Vector3(0, 0.02, 0) + pdir * 0.04, Vector3(0.01, 0.01, 0.006), pb, BRASS, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 6})
	var kdir := Vector3(sin(-1.2), 0, -cos(-1.2))
	var kc := Vector3(0, by - 0.02, -0.035) + kdir * (_body_r(kdir, by, belly) + 0.02)
	mb.tube(PackedVector3Array([kc, kc + Vector3(0.01, -0.17, 0.03)]), PackedFloat32Array([0.022, 0.008]), 6, leather.darkened(0.15), DwarfMesh.MAT_LEATHER, {"squash": Vector2(0.5, 1.0), "lumps": 0.0})
	mb.tube(PackedVector3Array([kc + Vector3(0, 0.0, 0), kc + Vector3(-0.005, 0.07, -0.01)]), PackedFloat32Array([0.011, 0.012]), 6, WOOD.darkened(0.2), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
	mb.tube(PackedVector3Array([kc + Vector3(-0.015, 0.005, 0), kc + Vector3(0.015, 0.005, 0)]), PackedFloat32Array([0.007, 0.007]), 5, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0})
	# patches on the tunic, with stitches
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, H + 0.12, 0), Vector3(0, H + 0.32, 0))
	for k in _rng.randi_range(1, 3):
		var a := _rng.randf_range(-2.4, 2.4)
		var py := _rng.randf_range(H + 0.2, H + 0.42)
		var dir := Vector3(sin(a), 0, -cos(a))
		var r := _body_r(dir, py, belly)
		var c := Vector3(0, py, 0.0) + dir * (r + 0.004)
		var bb := Basis.looking_at(-dir, Vector3.UP) * Basis(Vector3.BACK, _rng.randf_range(-0.4, 0.4))
		var sz := Vector2(_rng.randf_range(0.04, 0.06), _rng.randf_range(0.035, 0.055))
		var pcol: Color = LINEN.darkened(0.25) if _rng.randf() < 0.5 else tunic.lightened(0.18).lerp(Color(0.4, 0.3, 0.2), 0.4)
		mb.blob(c, Vector3(sz.x, sz.y, 0.006), bb, pcol, DwarfMesh.MAT_LINEN, {"lumps": 0.02, "rings": 4, "segs": 10, "occ": false})
		for st in 8:
			var sa := TAU * float(st) / 8.0
			var sp := c + bb * Vector3(cos(sa) * sz.x * 0.9, sin(sa) * sz.y * 0.9, -0.004)
			var sd := bb * Vector3(-sin(sa), cos(sa), 0.0) * 0.006 + bb * Vector3(cos(sa), sin(sa), 0) * 0.008
			mb.tube(PackedVector3Array([sp - sd, sp + sd]), PackedFloat32Array([0.0018, 0.0018]), 3, Color(0.15, 0.1, 0.07), DwarfMesh.MAT_LINEN, {"lumps": 0.0})
	# shoulders and collar (chest)
	mb.bind(B_CHEST)
	for s: float in [-1.0, 1.0]:
		mb.blob(Vector3(s * 0.215, H + 0.5, 0.015), Vector3(0.115, 0.095, 0.115), Basis.IDENTITY, tunic.lightened(0.04), DwarfMesh.MAT_CLOTH, {"lumps": 0.04, "rings": 8, "segs": 14})
		# seam along the shoulder
		mb.tube(PackedVector3Array([Vector3(s * 0.12, H + 0.585, 0.0), Vector3(s * 0.2, H + 0.59, 0.01), Vector3(s * 0.3, H + 0.52, 0.02)]), PackedFloat32Array([0.006, 0.006, 0.006]), 4, tunic.darkened(0.3), DwarfMesh.MAT_CLOTH, {"lumps": 0.0})
	mb.ring(Vector3(0, H + 0.585, 0.0), Vector2(0.105, 0.1), 0.02, 0.028, Basis.IDENTITY, LINEN.darkened(0.1) if shirt else tunic.darkened(0.15), DwarfMesh.MAT_LINEN, 18)
	if fur:
		var furc := Color(0.38, 0.3, 0.22) if _rng.randf() < 0.5 else Color(0.22, 0.2, 0.18)
		mb.ring(Vector3(0, H + 0.56, 0.02), Vector2(0.2, 0.17), 0.055, 0.0, Basis.IDENTITY, furc, DwarfMesh.MAT_FUR, 22, {"lumps": 0.2, "ring_sides": 8})
		for t in 22:
			var a := TAU * float(t) / 22.0
			var d := Vector3(sin(a), 0, -cos(a))
			mb.strand(Vector3(0, H + 0.575, 0.02) + d * 0.2, d * 0.6 + Vector3.DOWN, 0.045, 0.02, furc.lightened(_rng.randf_range(-0.08, 0.1)), Vector3.ZERO, 0.3, 3, 4)
	# apron (the keep): a sheet over the belly, bib to the chest, neck strap and ties
	if _o.get("apron", false):
		mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, H + 0.12, 0), Vector3(0, H + 0.32, 0))
		_apron(mb, belly)


## Radius of the torso (belly/chest/skirt envelope) toward horizontal `dir` at height y.
func _body_r(dir: Vector3, y: float, belly: float) -> float:
	var best := 0.0
	for e: Array in [[Vector3(0, H + 0.36, 0.0), Vector3(0.255, 0.27, 0.205)], [Vector3(0, H + 0.16, -0.035), Vector3(0.245, 0.2, 0.226) * belly]]:
		var c: Vector3 = e[0]
		var r: Vector3 = e[1]
		var dy := (y - c.y) / r.y
		if absf(dy) >= 1.0:
			continue
		var k := sqrt(1.0 - dy * dy)
		# ray from the belt centre (0, y, -0.035) toward dir, against the ellipse slice
		var o := Vector2(0.0, -0.035 - c.z)
		var d := Vector2(dir.x, dir.z)
		var ax := r.x * k
		var az := r.z * k
		var A := d.x * d.x / (ax * ax) + d.y * d.y / (az * az)
		var B := 2.0 * (o.x * d.x / (ax * ax) + o.y * d.y / (az * az))
		var C := o.x * o.x / (ax * ax) + o.y * o.y / (az * az) - 1.0
		var disc := B * B - 4.0 * A * C
		if disc > 0.0:
			best = maxf(best, (-B + sqrt(disc)) / (2.0 * A))
	if y < H + 0.1:
		# the skirt: a circle of radius ~0.226 about (0, -0.05)
		var o2 := Vector2(0.0, -0.035 + 0.05)
		var d2 := Vector2(dir.x, dir.z)
		var b2 := o2.dot(d2)
		var c2 := o2.length_squared() - 0.226 * 0.226
		best = maxf(best, -b2 + sqrt(maxf(b2 * b2 - c2, 0.0)))
	return best


func _apron(mb: Variant, belly: float) -> void:
	var col := LINEN.darkened(0.08)
	var top := H + 0.42
	var bot := H - (0.05 if seated else 0.22)
	var cols := 9
	var rows := 12
	var grid: Array[Vector3] = []
	for r in rows + 1:
		var v := float(r) / float(rows)
		var y := lerpf(top, bot, v)
		var half := lerpf(0.11, 0.2, smoothstep(0.0, 0.45, v))
		for c in cols + 1:
			var u := float(c) / float(cols) * 2.0 - 1.0
			var x := u * half
			var dir := Vector3(x, 0, -0.25).normalized()
			var rr := _body_r(dir, clampf(y, H + 0.0, H + 0.55), belly) if y > H - 0.05 else 0.3
			var p := Vector3(0, y, -0.035) + dir * (rr + 0.026)
			p.z -= 0.012 * sin(u * 7.0 + v * 2.0) * smoothstep(0.3, 1.0, v)      # folds
			grid.append(p)
	mb.sheet(grid, cols, rows, col, DwarfMesh.MAT_LINEN, 0.006, Vector3.FORWARD)
	mb.bind(B_CHEST)
	for s: float in [-1.0, 1.0]:
		mb.tube(PackedVector3Array([Vector3(s * 0.1, top, -0.2), Vector3(s * 0.085, H + 0.55, -0.12), Vector3(s * 0.07, H + 0.6, -0.03), Vector3(s * 0.06, H + 0.6, 0.06)]), PackedFloat32Array([0.01, 0.01, 0.01, 0.01]), 5, col.darkened(0.08), DwarfMesh.MAT_LINEN, {"squash": Vector2(0.5, 1.6), "lumps": 0.0})
	mb.bind(B_SPINE)
	for s: float in [-1.0, 1.0]:
		var e := Vector3(s * 0.235, H + 0.1, -0.02)
		mb.tube(PackedVector3Array([e, e + Vector3(s * 0.02, -0.05, 0.06), e + Vector3(s * 0.015, -0.14, 0.09)]), PackedFloat32Array([0.009, 0.009, 0.008]), 5, col.darkened(0.12), DwarfMesh.MAT_LINEN, {"squash": Vector2(0.5, 1.5), "lumps": 0.0})



func _head(mb: Variant, skin: Color, eye: Color, beard: Color) -> void:
	mb.bind_blend(B_CHEST, B_HEAD, Vector3(0, H + 0.58, 0), Vector3(0, H + 0.68, 0))
	mb.tube(PackedVector3Array([Vector3(0, H + 0.55, 0.0), Vector3(0, H + 0.64, -0.015), Vector3(0, H + 0.72, -0.03)]), PackedFloat32Array([0.075, 0.072, 0.07]), 12, skin.darkened(0.06), DwarfMesh.MAT_SKIN, {"caps": false})
	var f: Variant = face()
	f.skin = skin
	f.ruddy = skin.lerp(Color(0.86, 0.44, 0.26), 0.3)
	f.lip_c = f.ruddy.lerp(Color(0.6, 0.2, 0.18), 0.35)
	f.build(mb)
	f.eyes(mb, eye, 0.35 + 0.3 * f.age)
	f.ears(mb, f.ruddy.darkened(0.04), 0.95)


func _beard(mb: Variant, beard: Color, long: float, style: int) -> void:
	var hc := Vector3(0, H + 0.81, -0.03)
	var f: Variant = face()
	var my: float = f.mouth_y
	# brows: a bushy band on the ridge, strands swept up and out; sideburns joining hair to beard
	f.brows(mb, beard.darkened(0.04), 1.0, _rng)
	mb.bind(B_HEAD)
	for s: float in [-1.0, 1.0]:
		mb.blob(hc + Vector3(s * 0.118, -0.04, -0.015), Vector3(0.038, 0.085, 0.06), Basis(Vector3.FORWARD, s * 0.15), beard.darkened(0.04), DwarfMesh.MAT_HAIR, {"lumps": 0.14, "rings": 8, "segs": 10})
	# moustache: combed locks from under the nose over the upper lip, out past the corners and down
	for s: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for q: Array in [[0.03, my + 0.14, 0.012], [0.2, my + 0.08, 0.024], [0.38, my - 0.06, 0.03], [0.46, my - 0.28, 0.034]]:
			path.append(f.point(s * float(q[0]), float(q[1])) + f.normal(s * float(q[0]), float(q[1])) * float(q[2]))
		path.append(path[3] + Vector3(s * 0.01, -0.05, -0.012))
		mb.tube(path, PackedFloat32Array([0.016, 0.02, 0.016, 0.01, 0.004]), 8, beard.lightened(0.04), DwarfMesh.MAT_HAIR, {"lumps": 0.08, "squash": Vector2(1.0, 0.7)})
		for k in 7:
			var t := float(k) / 6.0
			var off := Vector3(0, _rng.randf_range(-0.006, 0.006), _rng.randf_range(-0.004, 0.004))
			var lock := PackedVector3Array()
			for j in path.size():
				lock.append(path[j] + off * (1.0 + float(j)) + Vector3(0, -0.004 * t, -0.006 * t))
			lock[0] = lock[0].lerp(path[1], t * 0.6)
			mb.tube(lock, PackedFloat32Array([0.008, 0.009, 0.007, 0.005, 0.002]), 5, beard.lightened(_rng.randf_range(-0.06, 0.12)), DwarfMesh.MAT_HAIR, {"lumps": 0.0, "squash": Vector2(1.0, 0.5)})
	# the beard: a jaw mass (jaw) and a chest mass that fades to the chest bone, then combed locks
	# laid over that envelope (they hug it instead of sticking out as spikes), three layers deep
	var top := hc + Vector3(0, -0.12, 0)
	var bot := hc + Vector3(0, -0.34 - 0.08 * long, 0)
	mb.bind_blend(B_JAW, B_CHEST, top, bot)
	var broad := 1.18 if style == 2 else 1.0
	mb.blob(hc + Vector3(0, -0.14, -0.055), Vector3(0.135 * broad, 0.085, 0.07), Basis.IDENTITY, beard.darkened(0.12), DwarfMesh.MAT_HAIR, {"lumps": 0.12, "rings": 10, "segs": 18})
	mb.blob(hc + Vector3(0, -0.26 - 0.03 * long, -0.105), Vector3(0.12 * broad, 0.14 + 0.05 * long, 0.045), Basis(Vector3.RIGHT, -0.18), beard.darkened(0.14), DwarfMesh.MAT_HAIR, {"lumps": 0.15, "rings": 10, "segs": 16})
	# locks: clumps that start under the lower lip in front and up at the sideburns, wave, taper to
	# a point and curl a little at the tip; lengths vary so the hem is ragged, not a curtain
	var y1 := -0.36 - 0.1 * long
	var n := 34 if style == 2 else 30
	for layer in 2:
		var lift := 1.0 + 0.07 * float(layer)
		for k in n:
			var a := lerpf(-1.5, 1.5, (float(k) + _rng.randf_range(-0.45, 0.45)) / float(n - 1)) * (1.0 - 0.15 * float(layer))
			var fork := signf(a) * 0.035 if style == 1 else 0.0
			var ln := _rng.randf_range(0.7, 1.0) - absf(a) * 0.2
			var y0 := lerpf(-0.112, -0.05, smoothstep(0.35, 1.3, absf(a)))
			var segs := 8
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			var wave := _rng.randf_range(0.0, TAU)
			var amp := _rng.randf_range(0.003, 0.008)
			var w0 := _rng.randf_range(0.024, 0.031) * (1.1 - 0.15 * float(layer))
			var curl := _rng.randf_range(-1.0, 1.0)
			for j in segs + 1:
				var t := float(j) / float(segs) * ln
				var y := lerpf(y0, y1, t)
				var rx := lerpf(0.145, 0.055, pow(t, 1.2)) * broad
				var rz := lerpf(0.068, 0.045, t)
				var cz := lerpf(-0.045, -0.13, pow(t, 0.8))
				var aa := a * lerpf(1.0, 0.72, t)
				var p := hc + Vector3(sin(aa) * rx * lift + fork * t + sin(wave + t * 11.0) * amp, y, cz - cos(aa) * rz * lift - 0.012 * float(layer))
				p += Vector3(curl * 0.02, 0.012, -0.012) * smoothstep(0.75, 1.0, t / ln)
				pts.append(p)
				rr.append(w0 * (1.0 - 0.88 * pow(t / ln, 1.4)))
			mb.tube(pts, rr, 6, beard.lightened(_rng.randf_range(-0.1, 0.1) + 0.06 * float(layer) - 0.03), DwarfMesh.MAT_HAIR, {"lumps": 0.03, "squash": Vector2(1.0, 0.42), "ao": 0.85 + 0.08 * float(layer)})
	# braids with iron rings, or a fork of two
	var tips: Array[Vector3] = []
	if style == 0:
		tips.append(hc + Vector3(0, -0.38 - 0.08 * long, -0.17))
	elif style == 1:
		tips.append(hc + Vector3(-0.045, -0.37 - 0.07 * long, -0.165))
		tips.append(hc + Vector3(0.045, -0.37 - 0.07 * long, -0.165))
	for t: Vector3 in tips:
		var lb := 0.16 + 0.08 * long
		var path := PackedVector3Array([t, t + Vector3(t.x * 0.2, -lb * 0.5, -0.02), t + Vector3(t.x * 0.5, -lb, -0.01)])
		mb.bind(B_CHEST)
		mb.braid(path, 0.03, beard.darkened(0.02), 8)
		for fr: float in [0.3, 0.75]:
			var c := DwarfMesh._along(path, fr * lb)
			mb.ring(c, Vector2(0.026, 0.024) * (1.0 - fr * 0.3), 0.007, 0.018, Basis.IDENTITY, IRON if _rng.randf() < 0.6 else BRASS, DwarfMesh.MAT_METAL, 12)
		mb.strand(path[2], Vector3(t.x * 0.4, -1, 0.0), 0.05, 0.016, beard, Vector3.ZERO, 0.2, 3, 4)


func _hat(mb: Variant, hat: String, tunic: Color, beard: Color, leather: Color) -> void:
	var hc := Vector3(0, H + 0.81, -0.03)
	mb.bind(B_HEAD)
	if hat != "hood":
		# hair over the nape, so no bare neck shows from behind
		mb.bind_blend(B_HEAD, B_CHEST, hc + Vector3(0, -0.06, 0), hc + Vector3(0, -0.22, 0))
		mb.blob(hc + Vector3(0, -0.085, 0.07), Vector3(0.118, 0.115, 0.08), Basis(Vector3.RIGHT, 0.25), beard.darkened(0.12), DwarfMesh.MAT_HAIR, {"lumps": 0.12, "rings": 8, "segs": 14})
		mb.bind(B_HEAD)
	match hat:
		"helm":
			# hair showing at the back, a riveted iron cap with a rim band, crest and nasal
			for k in 30:
				var a := lerpf(-2.1, 2.1, (float(k) + _rng.randf_range(-0.4, 0.4)) / 29.0) + PI
				var root := hc + Vector3(sin(a) * 0.14, -0.005, -cos(a) * 0.14)
				mb.strand(root, Vector3(sin(a) * 0.08, -1, -cos(a) * 0.1), _rng.randf_range(0.11, 0.17), 0.011, beard.lightened(_rng.randf_range(-0.08, 0.06)), Vector3.ZERO, 0.3, 4, 4)
			mb.blob(hc + Vector3(0, 0.065, 0.005), Vector3(0.155, 0.14, 0.158), Basis.IDENTITY, IRON, DwarfMesh.MAT_METAL, {"phi": Vector2(0.0, 0.56), "lumps": 0.01, "rings": 10, "segs": 22})
			mb.ring(hc + Vector3(0, 0.042, 0.005), Vector2(0.16, 0.163), 0.012, 0.03, Basis.IDENTITY, IRON.darkened(0.2), DwarfMesh.MAT_METAL, 24)
			for k in 12:
				var a := TAU * float(k) / 12.0
				mb.blob(hc + Vector3(sin(a) * 0.172, 0.044, 0.005 - cos(a) * 0.175), Vector3(0.007, 0.007, 0.007), Basis.IDENTITY, IRON.lightened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 6, "occ": false})
			mb.tube(PackedVector3Array([hc + Vector3(0, 0.05, -0.168), hc + Vector3(0, 0.18, -0.09), hc + Vector3(0, 0.215, 0.02), hc + Vector3(0, 0.17, 0.13)]), PackedFloat32Array([0.01, 0.014, 0.014, 0.01]), 6, IRON.lightened(0.08), DwarfMesh.MAT_METAL, {"lumps": 0.0, "squash": Vector2(1.0, 0.5)})
			mb.tube(PackedVector3Array([hc + Vector3(0, 0.05, -0.168), hc + Vector3(0, 0.03, -0.19), hc + Vector3(0, 0.0, -0.198)]), PackedFloat32Array([0.012, 0.01, 0.008]), 6, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0, "squash": Vector2(1.0, 0.45)})
		"hood":
			# a deep hood framing the face, folds round the face opening, a cowl on the shoulders
			# (chest) and a liripipe tail down the back
			var hood := tunic.darkened(0.3).lerp(Color(0.3, 0.24, 0.18), 0.35)
			mb.blob(hc + Vector3(0, 0.02, 0.025), Vector3(0.17, 0.175, 0.172), Basis(Vector3.RIGHT, 1.05), hood, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.68), "lumps": 0.05, "rings": 10, "segs": 22, "folds": Vector3(0.05, 7.0, 0.3)})
			mb.tube(PackedVector3Array([hc + Vector3(0, 0.08, 0.15), hc + Vector3(0, -0.05, 0.22), hc + Vector3(0.02, -0.25, 0.24), hc + Vector3(0.03, -0.42, 0.22)]), PackedFloat32Array([0.07, 0.045, 0.025, 0.01]), 10, hood, DwarfMesh.MAT_CLOTH, {"lumps": 0.08})
			mb.bind(B_CHEST)
			mb.blob(Vector3(0, H + 0.58, 0.03), Vector3(0.25, 0.08, 0.21), Basis.IDENTITY, hood, DwarfMesh.MAT_CLOTH, {"lumps": 0.06, "rings": 8, "segs": 22, "folds": Vector3(0.12, 8.0, 0.4)})
		"cap":
			# felt cap with a rolled brim and a floppy point, a little hair below
			var felt := tunic.lightened(0.08).lerp(Color(0.5, 0.15, 0.1), 0.3)
			for k in 24:
				var a := lerpf(-1.9, 1.9, (float(k) + _rng.randf_range(-0.4, 0.4)) / 23.0) + PI
				var root := hc + Vector3(sin(a) * 0.14, 0.01, -cos(a) * 0.14)
				mb.strand(root, Vector3(sin(a) * 0.08, -1, -cos(a) * 0.1), _rng.randf_range(0.08, 0.13), 0.011, beard.lightened(_rng.randf_range(-0.08, 0.06)), Vector3.ZERO, 0.3, 4, 4)
			mb.blob(hc + Vector3(0, 0.04, 0.01), Vector3(0.152, 0.13, 0.155), Basis.IDENTITY, felt, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.52), "lumps": 0.04, "rings": 9, "segs": 20})
			mb.ring(hc + Vector3(0, 0.03, 0.01), Vector2(0.158, 0.162), 0.022, 0.0, Basis.IDENTITY, felt.darkened(0.15), DwarfMesh.MAT_CLOTH, 22, {"lumps": 0.06})
			mb.tube(PackedVector3Array([hc + Vector3(0, 0.15, 0.02), hc + Vector3(0.05, 0.22, 0.08), hc + Vector3(0.12, 0.2, 0.15), hc + Vector3(0.17, 0.1, 0.17)]), PackedFloat32Array([0.075, 0.055, 0.03, 0.012]), 12, felt, DwarfMesh.MAT_CLOTH, {"lumps": 0.06})
		_:
			if _rng.randf() < 0.5:
				# bald pate (the skull's own skin) and a fringe of hair round the back
				for k in 40:
					var a := lerpf(-2.0, 2.0, (float(k) + _rng.randf_range(-0.4, 0.4)) / 39.0) + PI
					var root := hc + Vector3(sin(a) * 0.14, 0.03 + 0.02 * cos(a * 2.0), -cos(a) * 0.14)
					mb.strand(root, Vector3(sin(a) * 0.4, -1, -cos(a) * 0.5), _rng.randf_range(0.1, 0.16), 0.012, beard.lightened(_rng.randf_range(-0.08, 0.08)), Vector3.ZERO, 0.3, 4, 4)
				mb.blob(hc + Vector3(0, -0.005, 0.03), Vector3(0.145, 0.11, 0.13), Basis.IDENTITY, beard.darkened(0.08), DwarfMesh.MAT_HAIR, {"phi": Vector2(0.4, 0.8), "lumps": 0.1, "rings": 6, "segs": 18})
			else:
				# a full mane combed back, tied at the nape
				mb.blob(hc + Vector3(0, 0.03, 0.02), Vector3(0.15, 0.15, 0.155), Basis(Vector3.RIGHT, 0.5), beard.darkened(0.06), DwarfMesh.MAT_HAIR, {"phi": Vector2(0.0, 0.55), "lumps": 0.08, "rings": 9, "segs": 20})
				for k in 44:
					var a := lerpf(-1.9, 1.9, (float(k) + _rng.randf_range(-0.4, 0.4)) / 43.0)
					var root := hc + Vector3(sin(a) * 0.12, 0.13, -0.08 + absf(a) * 0.02)
					mb.strand(root, Vector3(sin(a) * 0.2, 0.25, 1.0), _rng.randf_range(0.2, 0.28), 0.011, beard.lightened(_rng.randf_range(-0.08, 0.08)), Vector3(0, -0.6, 0), 0.55, 6, 4)
				mb.ring(hc + Vector3(0, -0.07, 0.15), Vector2(0.026, 0.026), 0.007, 0.016, Basis.IDENTITY, leather, DwarfMesh.MAT_LEATHER, 10)
				mb.tube(PackedVector3Array([hc + Vector3(0, -0.02, 0.145), hc + Vector3(0, -0.12, 0.155), hc + Vector3(0, -0.24, 0.14)]), PackedFloat32Array([0.026, 0.022, 0.008]), 8, beard.darkened(0.06), DwarfMesh.MAT_HAIR, {"lumps": 0.1})


func _arms(mb: Variant, tunic: Color, skin: Color, leather: Color, shirt: bool, bracers: bool) -> void:
	var sleeve := LINEN.darkened(0.06) if shirt else tunic.lightened(0.03)
	for side: int in [0, 1]:
		var s := 1.0 if side == 0 else -1.0
		var ba := B_ARM_R if side == 0 else B_ARM_L
		var sh: Vector3 = rests[ba]
		var el: Vector3 = rests[ba + 1]
		var wr: Vector3 = rests[ba + 2]
		var up := (el - sh).normalized()
		var fo := (wr - el).normalized()
		# upper sleeve: puffed, bunched at the elbow, soft-skinned arm -> fore over the elbow
		mb.bind_blend(ba, ba + 1, el - up * 0.05, el + fo * 0.05)
		mb.tube(PackedVector3Array([sh - up * 0.02, sh.lerp(el, 0.35), sh.lerp(el, 0.75), el, el + fo * 0.06]), PackedFloat32Array([0.085, 0.088, 0.078, 0.074, 0.068]), 14, sleeve, DwarfMesh.MAT_LINEN if shirt else DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.06, 5.0), "ripple": Vector2(0.04, 9.0), "lumps": 0.03})
		mb.bind(ba + 1)
		mb.tube(PackedVector3Array([el + fo * 0.04, el.lerp(wr, 0.5), wr - fo * 0.03]), PackedFloat32Array([0.068, 0.062, 0.056]), 14, sleeve.darkened(0.03), DwarfMesh.MAT_LINEN if shirt else DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.05, 6.0), "ripple": Vector2(0.03, 11.0), "lumps": 0.03})
		if bracers:
			mb.tube(PackedVector3Array([wr - fo * 0.12, wr - fo * 0.06, wr - fo * 0.005]), PackedFloat32Array([0.062, 0.06, 0.058]), 12, leather, DwarfMesh.MAT_LEATHER, {"lumps": 0.02})
			for k in 4:
				var p := wr - fo * (0.02 + 0.028 * float(k))
				var out := Vector3(s, 0.4, 0).normalized()
				mb.tube(PackedVector3Array([p + out * 0.062 - fo * 0.008, p + out * 0.064 + fo * 0.008]), PackedFloat32Array([0.003, 0.003]), 3, leather.darkened(0.4), DwarfMesh.MAT_LEATHER, {"lumps": 0.0})
		else:
			# rolled cuff
			mb.tube(PackedVector3Array([wr - fo * 0.05, wr - fo * 0.02, wr]), PackedFloat32Array([0.064, 0.068, 0.062]), 14, sleeve.lightened(0.05), DwarfMesh.MAT_LINEN if shirt else DwarfMesh.MAT_CLOTH, {"lumps": 0.06})
		mb.tube(PackedVector3Array([wr - fo * 0.02, wr + fo * 0.02]), PackedFloat32Array([0.04, 0.042]), 10, skin, DwarfMesh.MAT_SKIN, {"caps": false})
		mb.bind(ba + 2)
		var grip := side == 0 and has_mug
		_hand(mb, wr, fo, s, skin, grip)


## A hand at wrist `w` along forearm `fo`. Grip: a fist with its knuckles stacked vertically round a
## tankard handle (the tankard sits inboard of it). Else relaxed, fingers half curled.
func _hand(mb: Variant, w: Vector3, fo: Vector3, s: float, skin: Color, grip: bool) -> void:
	var f := Vector3(fo.x, 0.0, fo.z).normalized() if grip else fo
	var up := Vector3.UP if grip else Vector3.UP.slide(fo).normalized()
	var side := f.cross(up).normalized() * s          # outward (thumb side is inboard for a fist)
	var bas := Basis(side, up, -f).orthonormalized()
	var knuckle := skin.darkened(0.06)
	if grip:
		var palm := w + f * 0.045
		mb.blob(palm, Vector3(0.028, 0.045, 0.047), bas, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.05, "rings": 8, "segs": 12})
		for k in 4:
			var y := (1.5 - float(k)) * 0.0215
			var r := 0.0125 - 0.001 * float(k)
			var b0 := w + f * 0.083 + up * y + side * 0.006
			var b1 := b0 + f * 0.022 - side * 0.016
			var b2 := b1 - side * 0.02 - f * 0.012
			var b3 := b2 - f * 0.018 - side * 0.002
			mb.tube(PackedVector3Array([b0 - f * 0.012, b0, b1, b2, b3]), PackedFloat32Array([r * 1.1, r * 1.12, r, r * 0.95, r * 0.85]), 7, knuckle if k % 2 == 0 else skin, DwarfMesh.MAT_SKIN, {"lumps": 0.04})
			mb.blob(b0 + side * 0.006, Vector3(0.008, 0.008, 0.007), bas, knuckle.darkened(0.05), DwarfMesh.MAT_SKIN, {"lumps": 0.0, "rings": 4, "segs": 6, "occ": false})
		var t0 := w + f * 0.03 - side * 0.02 + up * 0.03
		mb.tube(PackedVector3Array([t0, t0 + f * 0.03 - side * 0.006 + up * 0.016, t0 + f * 0.058 - side * 0.012 + up * 0.022]), PackedFloat32Array([0.016, 0.0135, 0.011]), 7, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.04})
	else:
		var palm2 := w + f * 0.048
		mb.blob(palm2, Vector3(0.042, 0.022, 0.05), Basis(Vector3.FORWARD, s * 0.3) * Basis.looking_at(-f, up), skin, DwarfMesh.MAT_SKIN, {"lumps": 0.05, "rings": 8, "segs": 12})
		var across := f.cross(up).normalized()
		for k in 4:
			var x := (float(k) - 1.5) * 0.019
			var r2 := 0.011 - 0.0008 * float(k)
			var b0 := w + f * 0.09 + across * x + up * 0.004
			var b1 := b0 + f * 0.03 - up * 0.012
			var b2 := b1 + f * 0.018 - up * 0.022
			mb.tube(PackedVector3Array([b0 - f * 0.01, b0, b1, b2]), PackedFloat32Array([r2 * 1.1, r2, r2 * 0.92, r2 * 0.8]), 6, skin if k % 2 == 0 else knuckle, DwarfMesh.MAT_SKIN, {"lumps": 0.04})
		var tb := w + f * 0.03 - across * s * 0.035
		mb.tube(PackedVector3Array([tb, tb + f * 0.035 - across * s * 0.012 - up * 0.008, tb + f * 0.06 - across * s * 0.012 - up * 0.02]), PackedFloat32Array([0.015, 0.012, 0.01]), 6, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.04})


## The tankard in the right fist: staves, iron hoops, a handle into the fist, a foam head with a drip.
func _mug(mb: Variant) -> void:
	mb.bind(B_HAND_R)
	_tankard(mb, _mug_center(), _mug_side())


func _mug_side() -> Vector3:
	var fo := (rests[B_HAND_R] - rests[B_FORE_R]).normalized()
	return Vector3(fo.x, 0.0, fo.z).normalized().cross(Vector3.UP).normalized()


## The tankard sits inboard of the right fist (rest pose); also sets mug_base / mug_rim, which the
## animation needs whether the mesh was built or came from the cache.
func _mug_center() -> Vector3:
	var fo := (rests[B_HAND_R] - rests[B_FORE_R]).normalized()
	var f := Vector3(fo.x, 0.0, fo.z).normalized()
	var mc: Vector3 = rests[B_HAND_R] + f * 0.075 - _mug_side() * 0.072 + Vector3.DOWN * 0.005
	mug_base = mc + Vector3.DOWN * 0.07
	mug_rim = mc + Vector3(0, 0.075, 0) + Vector3(0, 0, 0.05)
	return mc


static func _tankard(mb: Variant, mc: Vector3, side: Vector3) -> void:
	var lo := mc + Vector3.DOWN * 0.07
	var hi := mc + Vector3.UP * 0.07
	mb.tube(PackedVector3Array([lo, mc, hi]), PackedFloat32Array([0.047, 0.051, 0.05]), 16, WOOD, DwarfMesh.MAT_WOOD, {"lumps": 0.0, "folds": Vector2(0.03, 16.0)})
	for hy: float in [-0.052, 0.0, 0.052]:
		mb.ring(mc + Vector3.UP * hy, Vector2(0.0525, 0.0525) if hy == 0.0 else Vector2(0.051, 0.051), 0.004, 0.012, Basis.IDENTITY, IRON.darkened(0.15), DwarfMesh.MAT_METAL, 18)
	mb.tube(PackedVector3Array([hi + Vector3.DOWN * 0.006, hi + Vector3.UP * 0.006]), PackedFloat32Array([0.044, 0.044]), 16, Color(0.55, 0.32, 0.08), DwarfMesh.MAT_FOAM, {"lumps": 0.0, "caps": false})
	mb.blob(hi + Vector3.UP * 0.008, Vector3(0.05, 0.022, 0.05), Basis.IDENTITY, FOAM, DwarfMesh.MAT_FOAM, {"lumps": 0.22, "rings": 6, "segs": 14})
	var drip := hi + Vector3(0, 0.0, 0) + (-side * 0.0 + Vector3(0, 0, -1)) * 0.05
	mb.tube(PackedVector3Array([drip, drip + Vector3(0, -0.02, -0.004), drip + Vector3(0, -0.035, -0.002)]), PackedFloat32Array([0.007, 0.006, 0.004]), 5, FOAM.darkened(0.04), DwarfMesh.MAT_FOAM, {"lumps": 0.0})
	# handle: from the mug's outboard side round into the fist
	var hs := mc + side * 0.05
	mb.tube(PackedVector3Array([hs + Vector3.UP * 0.045, hs + side * 0.03 + Vector3.UP * 0.04, hs + side * 0.04, hs + side * 0.03 + Vector3.DOWN * 0.04, hs + Vector3.DOWN * 0.045]), PackedFloat32Array([0.011, 0.011, 0.011, 0.011, 0.011]), 7, WOOD.darkened(0.15), DwarfMesh.MAT_WOOD, {"lumps": 0.0, "squash": Vector2(0.6, 1.0)})


## The keep's bar cloth, hanging from the left hand.
func _rag(mb: Variant) -> void:
	var w: Vector3 = rests[B_HAND_L]
	var fo := (w - rests[B_FORE_L]).normalized()
	mb.bind(B_HAND_L)
	var c := w + fo * 0.07 + Vector3.DOWN * 0.04
	mb.blob(c, Vector3(0.04, 0.03, 0.035), Basis.IDENTITY, LINEN.darkened(0.2), DwarfMesh.MAT_LINEN, {"lumps": 0.3, "rings": 6, "segs": 10})
	mb.tube(PackedVector3Array([c, c + Vector3(0.01, -0.06, 0.0), c + Vector3(-0.01, -0.13, 0.01)]), PackedFloat32Array([0.035, 0.04, 0.03]), 10, LINEN.darkened(0.24), DwarfMesh.MAT_LINEN, {"lumps": 0.3, "squash": Vector2(1.0, 0.3)})


func _legs(mb: Variant, trouser: Color, leather: Color) -> void:
	for side: int in [0, 1]:
		var s := 1.0 if side == 0 else -1.0
		var bt := B_THIGH_R if side == 0 else B_THIGH_L
		var hip: Vector3 = rests[bt]
		var knee: Vector3 = rests[bt + 1]
		var an := ankle(s)
		var th := (knee - hip).normalized()
		var sn := (an - knee).normalized()
		mb.bind_blend(bt, bt + 1, knee - th * 0.06, knee + sn * 0.06)
		mb.tube(PackedVector3Array([hip - th * 0.04, hip.lerp(knee, 0.5), knee - th * 0.03, knee + sn * 0.04]), PackedFloat32Array([0.1, 0.096, 0.088, 0.084]), 14, trouser, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.05, 4.0), "ripple": Vector2(0.03, 7.0), "lumps": 0.03})
		mb.bind(bt + 1)
		var top := an + Vector3.UP * 0.19
		mb.tube(PackedVector3Array([knee + sn * 0.02, knee.lerp(top, 0.6), top]), PackedFloat32Array([0.082, 0.078, 0.076]), 14, trouser.darkened(0.04), DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.06, 5.0), "ripple": Vector2(0.04, 10.0), "lumps": 0.03})
		# boot: shaft, folded cuff, strap and buckle, foot, toe cap, sole and heel
		var fwd := Vector3(0, 0, -1)
		mb.tube(PackedVector3Array([an + Vector3.DOWN * 0.03, an + Vector3.UP * 0.08, an + Vector3.UP * 0.17]), PackedFloat32Array([0.074, 0.078, 0.082]), 14, leather.darkened(0.25), DwarfMesh.MAT_LEATHER, {"lumps": 0.04, "ripple": Vector2(0.03, 14.0)})
		mb.tube(PackedVector3Array([an + Vector3.UP * 0.15, an + Vector3.UP * 0.2, an + Vector3.UP * 0.215]), PackedFloat32Array([0.09, 0.094, 0.088]), 14, leather.darkened(0.12), DwarfMesh.MAT_LEATHER, {"lumps": 0.06})
		mb.ring(an + Vector3.UP * 0.07, Vector2(0.082, 0.082), 0.007, 0.018, Basis.IDENTITY, leather.darkened(0.4), DwarfMesh.MAT_LEATHER, 16)
		mb.blob(an + Vector3(s * 0.08, 0.07, -0.01), Vector3(0.006, 0.014, 0.012), Basis.IDENTITY, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 6})
		mb.blob(an + Vector3(0, -0.03, -0.075), Vector3(0.068, 0.052, 0.115), Basis.IDENTITY, leather.darkened(0.25), DwarfMesh.MAT_LEATHER, {"lumps": 0.05, "rings": 8, "segs": 14})
		mb.blob(an + Vector3(0, -0.035, -0.15), Vector3(0.056, 0.044, 0.05), Basis.IDENTITY, leather.darkened(0.18), DwarfMesh.MAT_LEATHER, {"lumps": 0.03, "rings": 6, "segs": 12})
		mb.blob(an + Vector3(0, -0.078, -0.07) + fwd * 0.0, Vector3(0.074, 0.018, 0.135), Basis.IDENTITY, Color(0.12, 0.09, 0.07), DwarfMesh.MAT_LEATHER, {"lumps": 0.0, "rings": 5, "segs": 16})
		mb.blob(an + Vector3(0, -0.07, 0.02), Vector3(0.06, 0.022, 0.045), Basis.IDENTITY, Color(0.1, 0.08, 0.06), DwarfMesh.MAT_LEATHER, {"lumps": 0.0, "rings": 5, "segs": 12})


# =====================================================================================================
# skeleton, skin, mesh instance
# =====================================================================================================

func _assemble(mesh: ArrayMesh) -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for i in BONES.size():
		skeleton.add_bone(BONES[i])
		if PARENT[i] >= 0:
			skeleton.set_bone_parent(i, PARENT[i])
	for i in BONES.size():
		var parent_at: Vector3 = rests[PARENT[i]] if PARENT[i] >= 0 else Vector3.ZERO
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, rests[i] - parent_at))
	skeleton.reset_bone_poses()
	var skin := Skin.new()
	for i in BONES.size():
		skin.add_named_bind(BONES[i], skeleton.get_bone_global_rest(i).affine_inverse())
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.skin = skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = 40.0
	mesh_instance.visibility_range_end_margin = 6.0
	mesh_instance.extra_cull_margin = 0.6       # the arms reach out of the rest bounds


# =====================================================================================================
# posing: local rotations, forward kinematics, two-bone arm IK
# =====================================================================================================

func bone(n: String) -> int:
	return BONES.find(n)


## Set a bone's rotation relative to its rest (identity = rest pose). Call apply() when done.
func q(b: int, rot: Quaternion) -> void:
	_q[b] = rot


func get_q(b: int) -> Quaternion:
	return _q[b]


## Compatibility: pose by name and push at once.
func pose(n: String, rot: Quaternion) -> void:
	var i := bone(n)
	if i >= 0:
		_q[i] = rot
		skeleton.set_bone_pose_rotation(i, rot)


func reset() -> void:
	for i in _q.size():
		_q[i] = Quaternion.IDENTITY


## Model-space rotation / position of bone b under the current local rotations.
func fk(b: int) -> void:
	var p: int = PARENT[b]
	if p < 0:
		_gq[b] = _q[b]
		_gp[b] = rests[b]
		return
	_gq[b] = _gq[p] * _q[b]
	_gp[b] = _gp[p] + _gq[p] * (rests[b] - rests[p])


func fk_all() -> void:
	for i in BONES.size():
		fk(i)


func gpos(b: int) -> Vector3:
	return _gp[b]


func grot(b: int) -> Quaternion:
	return _gq[b]


## A rest-pose point carried by bone b into its current place (needs fk up to b).
func carry(b: int, rest_point: Vector3) -> Vector3:
	return _gp[b] + _gq[b] * (rest_point - rests[b])


## Lips under the current head and jaw pose (call fk_all first).
func lips() -> Vector3:
	return carry(B_HEAD, mouth)


## Two-bone IK: put the wrist of `side` ("r"/"l") on `target` (model space) with the elbow toward
## `pole`, and turn the hand to `hand_q` (model space; null = keep the forearm's line). Uses the
## current chest pose: set spine/chest first. Writes arm/fore/hand local rotations.
func arm_to(side: String, target: Vector3, pole := Vector3.ZERO, hand_q: Variant = null) -> void:
	var ba := B_ARM_R if side == "r" else B_ARM_L
	var s := 1.0 if side == "r" else -1.0
	fk(B_ROOT)
	fk(B_SPINE)
	fk(B_CHEST)
	fk(ba)
	var sp := _gp[ba]
	var u0: Vector3 = rests[ba + 1] - rests[ba]
	var f0: Vector3 = rests[ba + 2] - rests[ba + 1]
	var l1 := u0.length()
	var l2 := f0.length()
	var to := target - sp
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dir := to.normalized() if to.length() > 1e-5 else Vector3.DOWN
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	if pole == Vector3.ZERO:
		pole = Vector3(s * 0.7, -0.5, 0.5)
	var pp := (pole - dir * pole.dot(dir))
	if pp.length() < 1e-4:
		pp = Vector3(s, 0, 0).slide(dir)
	pp = pp.normalized()
	var e := sp + dir * a + pp * h
	var t := sp + dir * d
	var u1 := (e - sp).normalized()
	var f1 := (t - e).normalized()
	var n0 := u0.normalized().cross(f0.normalized()).normalized()
	var n1 := u1.cross(f1).normalized()
	var b0 := Basis(u0.normalized(), n0, u0.normalized().cross(n0)).orthonormalized()
	var b1 := Basis(u1, n1, u1.cross(n1)).orthonormalized()
	var r1 := Quaternion(b1 * b0.inverse()).normalized()
	var fr := r1 * f0.normalized()
	var r2 := (_quat_arc(fr, f1) * r1).normalized()
	_q[ba] = (_gq[B_CHEST].inverse() * r1).normalized()
	_q[ba + 1] = (r1.inverse() * r2).normalized()
	_q[ba + 2] = (r2.inverse() * (hand_q as Quaternion)).normalized() if hand_q != null else Quaternion.IDENTITY
	fk(ba)
	fk(ba + 1)
	fk(ba + 2)


static func _quat_arc(a: Vector3, b: Vector3) -> Quaternion:
	var c := a.cross(b)
	var dt := a.dot(b)
	if c.length() < 1e-6:
		return Quaternion.IDENTITY if dt > 0.0 else Quaternion(Vector3.UP, PI)
	return Quaternion(c.normalized(), atan2(c.length(), dt))


## The wrist target that puts a point of the hand (rest position `rest_point`, e.g. the mug rim)
## on `goal` with the hand turned to `hand_q` (model space).
func wrist_for(side: String, rest_point: Vector3, goal: Vector3, hand_q: Quaternion) -> Vector3:
	var bh := B_HAND_R if side == "r" else B_HAND_L
	return goal - hand_q * (rest_point - rests[bh])


func rest_of(n: String) -> Vector3:
	return rests[bone(n)]


func apply() -> void:
	for i in BONES.size():
		skeleton.set_bone_pose_rotation(i, _q[i])


## The shared dwarf material (served tankards on the counter use it too).
static func _cloth() -> Material:
	return DwarfLook.material()

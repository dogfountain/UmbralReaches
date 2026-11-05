extends "res://core/npc/dwarf_rig.gd"
## Hearthward's people (village system, docs/LIFE_PLAN.md; no class_name). The tavern dwarves' rig
## (same 15 bones, posing, two-bone IK, shader, detail maps and GenCache) re-proportioned for humans:
## a long-legged adult (about 1.7 m once scaled), an old stooped one, a teen and a child, men and
## women. Built from VMesh (DwarfMesh + skirt skinning for coats, dresses and robes):
##   a face with brow, lidded eyes, a straight nose, lips, cheekbones and ears (jaw bone for the
##   chin and lower lip); hair (bun under a kerchief, loose, braids, short, a balding fringe, wild),
##   beards (short, long and grey), hoods, brimmed hats and caps; shirts with rolled sleeves, long
##   coats with buttons and a collar, dresses with aprons, ragged robes, belts, satchels, shawls;
##   trousers, boots or rag-wrapped feet; hands with fingers (open, or a fist round a tool);
##   tools bound to the hand: hammer, lamplighter's pole, staff, spade, axe, scoop, lantern, candle,
##   chalk. Glowing bits (lantern glass, candle flame) are a separate small mesh on a
##   mesh carried with its hand (`glow`, `update_glow()`), the only second draw a villager can have.
## Tools are built in the fist along the hand's `ax` axis through grip point `grip[side]`; pose them
## with `hold(side, G, D, U)`: the grip goes to G (model space), the tool axis to D, the fingers
## to U. One skinned surface with LODs, cached through GenCache by its options.
## Model space: front -Z, origin on the ground, built at 1/SCALE and shown at SCALE (the AO grid
## of DwarfMesh stops at 1.55 m).

const VMesh := preload("res://core/life/village/villager_mesh.gd")
const SELF_V := "res://core/life/village/villager_rig.gd"
const SCALE := 1.1                 ## adults are built 1.53 m tall and shown at 1.68 m

const KEYS := ["seed", "sex", "age", "garment", "apron", "hood", "hat", "hair", "beard", "r", "l", "satchel", "shawl", "pale", "barefoot", "girth", "cloth", "cloth2", "hair_c", "skin", "leather"]

static var _mem := {}              ## key -> ArrayMesh (the portrait reuses the world copy)


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_mem.clear()

var cfg := {}
var k := 1.0                       ## body size factor (child 0.68)
var hs := 1.0                      ## head size factor
var P := 0.8                       ## pelvis height (model)
var hc := Vector3.ZERO             ## head centre at rest
var grip: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]      ## [r, l] grip point at rest
var grip_ax: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
var grip_up: Array[Vector3] = [Vector3.DOWN, Vector3.DOWN]
var tips: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## [r, l] tool working ends at rest (pole hook, blade, lantern)
var glow: MeshInstance3D           ## lantern glass / candle flame / hot iron (carried by update_glow), or null
var glow_mat: StandardMaterial3D
var _glow_side := 0
var _glow_at := Vector3.ZERO
var _glow_basis := Basis.IDENTITY


## A villager from build options (see KEYS; unknown keys ignored). Returns the rig, built.
static func create(opts: Dictionary) -> Node3D:
	var r := new()
	r.name = "Rig"
	r._build(opts)
	return r


func _build(opts: Dictionary) -> void:
	cfg = opts
	_o = opts
	seated = false
	has_mug = false
	var sd := int(opts.get("seed", 1))
	_rng.seed = sd
	match String(opts.get("age", "adult")):
		"child":
			k = 0.68
			hs = 0.86
		"teen":
			k = 0.9
			hs = 0.95
		"old":
			k = 0.97
			hs = 0.98
		_:
			k = 1.0
			hs = 1.0
	_rest_layout()
	var parts := PackedStringArray()
	for key: String in KEYS:
		parts.append(str(opts.get(key, "")))
	_key = "vil4|%s|%d|%d" % ["|".join(parts), GenCache.salt(SELF_V), GenCache.salt("res://core/life/village/villager_mesh.gd") ^ GenCache.salt(MESH_SRC) ^ GenCache.salt(FACE_SRC)]
	var mesh: ArrayMesh = _mem.get(_key)
	if mesh == null:
		mesh = GenCache.load_mesh(_key, SELF_V)
	if mesh == null:
		var t0 := Time.get_ticks_msec()
		var mb: Variant = VMesh.new(sd)
		_body_v(mb)
		mb.bake_ao()
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mb.arrays(), [], {}, null, "villager")
		im.generate_lods(25.0, 60.0, [])
		mesh = im.get_mesh()
		GenCache.save_mesh(_key, SELF_V, mesh)
		print("VILLAGER built %s: %d verts in %d ms" % [opts.get("name", sd), mb.vertex_count(), Time.get_ticks_msec() - t0])
	_mem[_key] = mesh
	mesh.surface_set_material(0, DwarfLook.material_outdoor())
	_assemble(mesh)
	scale = Vector3.ONE * SCALE
	mesh_instance.visibility_range_end = 60.0
	mesh_instance.visibility_range_end_margin = 8.0
	mesh_instance.extra_cull_margin = 1.2 if String(opts.get("r", "")) == "pole" else 0.6
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_glow_part()


# =====================================================================================================
# layout
# =====================================================================================================

func _rest_layout() -> void:
	var f := String(cfg.get("sex", "m")) == "f"
	var sw := (0.17 if f else 0.185)
	P = 0.8 * k
	var neck := 1.3 * k
	if String(cfg.get("age", "")) == "child":
		neck = 1.3 * k - 0.04
	hc = Vector3(0, neck + 0.098 * hs, -0.012 * k)
	rests.clear()
	var arm := func(s: float) -> Array:
		return [Vector3(s * sw, 1.205, 0.012) * k, Vector3(s * (sw + 0.028), 0.955, 0.035) * k, Vector3(s * (sw + 0.034), 0.73, 0.0) * k]
	var leg := func(s: float) -> Array:
		return [Vector3(s * 0.088, 0.765, 0.0) * k, Vector3(s * 0.095, 0.425, -0.012) * k]
	var ar: Array = arm.call(1.0)
	var al: Array = arm.call(-1.0)
	var lr: Array = leg.call(1.0)
	var ll: Array = leg.call(-1.0)
	rests = [Vector3.ZERO, Vector3(0, P, 0), Vector3(0, P + 0.24 * k, 0.01 * k), Vector3(0, neck, 0.0), hc + Vector3(0, -0.04, -0.035) * hs,
		ar[0], ar[1], ar[2], al[0], al[1], al[2], lr[0], lr[1], ll[0], ll[1], Vector3.ZERO]
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
	# grips (rest pose): the fist's tool axis points forward, through the palm's face
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		var ba := B_ARM_R if side == 0 else B_ARM_L
		var w: Vector3 = rests[ba + 2]
		var fo: Vector3 = (w - rests[ba + 1]).normalized()
		var pn := Vector3(-s, 0, 0).slide(fo).normalized()
		grip[side] = w + fo * 0.05 * k + pn * 0.036 * k
		grip_ax[side] = fo.cross(pn).normalized() * s
		grip_up[side] = fo


func ankle(s: float) -> Vector3:
	return Vector3(s * 0.1, 0.075, 0.012) * k


## The sculpted face (npc_face.gd): proportions by sex and age, varied by seed with a generator of
## its own (a cached mesh and a fresh build agree on the lid pivot and the lips).
func face() -> Variant:
	if _face != null:
		return _face
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 1)) * 7919 + 29
	var fem := String(cfg.get("sex", "m")) == "f"
	var age := String(cfg.get("age", "adult"))
	var f: Variant = Face.new()
	f.c = hc
	f.R = Vector3(0.086 * (0.94 if fem else 1.0), 0.108, 0.098) * hs
	f.female = fem
	f.child = age == "child"
	match age:
		"old":
			f.age = r.randf_range(0.8, 1.0)
		"adult":
			f.age = r.randf_range(0.12, 0.35)
		_:
			f.age = 0.0
	f.brow = r.randf_range(0.8, 1.2)
	f.nose = r.randf_range(0.85, 1.2) * (0.7 if age == "child" else (0.9 if age == "teen" else 1.0))
	f.nose_w = r.randf_range(0.85, 1.15)
	f.hook = r.randf_range(0.0, 0.25) if fem else r.randf_range(0.0, 0.8)
	f.cheek = r.randf_range(0.8, 1.25)
	f.fat = 0.4 if age == "child" else r.randf_range(0.0, 0.3) * clampf(float(cfg.get("girth", 1.0)) - 0.85, 0.0, 1.0) * 4.0
	f.chin = r.randf_range(0.8, 1.2)
	f.jaw = r.randf_range(0.63, 0.69) if fem else r.randf_range(0.7, 0.78)
	f.lip = r.randf_range(0.85, 1.15)
	if age == "child":
		f.eye_r = f.R.x * 0.16
		f.eye_y = 0.06
	f.b_head = B_HEAD
	f.b_jaw = B_JAW
	f.b_lid = B_LID
	_face = f
	return f


# =====================================================================================================
# posing helpers
# =====================================================================================================

## Put the tool (or fist) of `side` (0 right, 1 left) with its grip at G, its axis along D and the
## fingers toward U (model space, U is made perpendicular to D). Elbow toward `pole_dir`.
func hold(side: int, G: Vector3, D: Vector3, U: Vector3, pole_dir := Vector3.ZERO) -> void:
	var d := D.normalized()
	var u := U.slide(d).normalized()
	if u.length() < 0.1:
		u = Vector3.DOWN.slide(d).normalized()
	var ax: Vector3 = grip_ax[side]
	var up: Vector3 = (grip_up[side] as Vector3).slide(ax).normalized()
	var rest_b := Basis(ax, up, ax.cross(up))
	var want_b := Basis(d, u, d.cross(u))
	var hq := Quaternion((want_b * rest_b.inverse()).orthonormalized()).normalized()
	var sd := "r" if side == 0 else "l"
	var wrist := wrist_for(sd, grip[side], G, hq)
	var s := 1.0 if side == 0 else -1.0
	arm_to(sd, wrist, pole_dir if pole_dir != Vector3.ZERO else Vector3(s * 0.8, -0.4, 0.5), hq)


## Model-space position of a rest-pose point carried by the right hand (tool tips) after fk.
func tool_point(rest_point: Vector3, side := 0) -> Vector3:
	return carry(B_HAND_R if side == 0 else B_HAND_L, rest_point)


func head_top() -> float:
	return (hc.y + 0.112 * hs) * SCALE


# =====================================================================================================
# the body
# =====================================================================================================

static func _pf(a: Array, m: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v: float in a:
		out.append(v * m)
	return out


func _c(key: String, fallback: Color) -> Color:
	var v: Variant = cfg.get(key, null)
	return v if v is Color else fallback


func _body_v(mb: Variant) -> void:
	var f := String(cfg.get("sex", "m")) == "f"
	var age := String(cfg.get("age", "adult"))
	var skin := _c("skin", SKINS[_rng.randi_range(0, SKINS.size() - 1)])
	if bool(cfg.get("pale", false)):
		skin = skin.lerp(Color(0.78, 0.8, 0.86), 0.55)
	var cloth := _c("cloth", TUNICS[_rng.randi_range(0, TUNICS.size() - 1)])
	var cloth2 := _c("cloth2", TROUSERS[_rng.randi_range(0, TROUSERS.size() - 1)])
	var hair := _c("hair_c", BEARDS[_rng.randi_range(0, BEARDS.size() - 1)])
	var leather := _c("leather", LEATHERS[_rng.randi_range(0, LEATHERS.size() - 1)])
	var girth := float(cfg.get("girth", 1.0))
	var garment := String(cfg.get("garment", "shirt"))
	_torso_v(mb, f, cloth, leather, girth, garment, age)
	_head_v(mb, f, skin, age, hair)
	_hair_v(mb, hair, String(cfg.get("hair", "short")), f)
	if String(cfg.get("beard", "")) != "":
		_beard_v(mb, hair, String(cfg.get("beard", "")))
	_headwear(mb, cloth, cloth2, hair, leather)
	_arms_v(mb, cloth, skin, leather, garment)
	_legs_v(mb, cloth2, leather, garment, bool(cfg.get("barefoot", false)))
	_garment_v(mb, garment, cloth, cloth2, leather, f, girth)
	if String(cfg.get("apron", "")) != "":
		_apron_v(mb, String(cfg.get("apron", "")), girth, garment)
	if bool(cfg.get("satchel", false)):
		_satchel(mb, leather)
	if bool(cfg.get("shawl", false)):
		_shawl(mb, cloth2)
	_tool(mb, 0, String(cfg.get("r", "")), skin)
	_tool(mb, 1, String(cfg.get("l", "")), skin)


var _prof: Array = []

## Torso profile, hips to neck (model space before SCALE): rows [y, rx, rz, zc, front bulge].
## Women: wider hips, a waist, a bust; girth widens the belly. One loft (DwarfMesh.loft).
func _tprof() -> Array:
	if not _prof.is_empty():
		return _prof
	var f := String(cfg.get("sex", "m")) == "f"
	var age := String(cfg.get("age", "adult"))
	var g := float(cfg.get("girth", 1.0))
	var bust := 0.0
	if f and age != "child":
		bust = 0.03 if age == "old" else (0.026 if age == "teen" else 0.036)
	var belly := clampf(g - 1.0, 0.0, 0.3) * 0.22 + (0.012 if age == "old" and not f else 0.0)
	var rows := [
		# dy over the pelvis, rx man, rx woman, rz, zc, front
		[-0.08, 0.152, 0.168, 0.104, 0.0, 0.0],
		[0.0, 0.148, 0.16, 0.1, 0.0, belly * 0.6],
		[0.09, 0.142, 0.134, 0.096, 0.0, belly],
		[0.18, 0.148, 0.138, 0.098, 0.0, belly * 0.6],
		[0.26, 0.158, 0.146, 0.103, 0.004, bust * 0.6],
		[0.32, 0.166, 0.15, 0.106, 0.006, bust],
		[0.37, 0.168, 0.152, 0.103, 0.008, bust * 0.45],
		[0.42, 0.152, 0.14, 0.09, 0.01, 0.0],
		[0.46, 0.112, 0.102, 0.072, 0.01, 0.0],
		[0.49, 0.062, 0.056, 0.054, 0.004, 0.0],
	]
	for r: Array in rows:
		var top := float(r[0]) > 0.4
		var gw := 1.0 if top else g
		_prof.append([P + float(r[0]) * k, float(r[2] if f else r[1]) * k * gw, float(r[3]) * k * gw, float(r[4]) * k, float(r[5]) * k])
	return _prof


## Loft the torso profile, grown by `grow` (m) and `scale`, between heights y_lo and y_hi.
func _loft_torso(mb: Variant, y_lo: float, y_hi: float, grow: float, col: Color, mat: int, opts := {}) -> void:
	var ys := PackedFloat32Array()
	var rx := PackedFloat32Array()
	var rz := PackedFloat32Array()
	var zc := PackedFloat32Array()
	var fr := PackedFloat32Array()
	for r: Array in _tprof():
		var y: float = r[0]
		if y < y_lo - 0.001 or y > y_hi + 0.001:
			continue
		ys.append(y)
		rx.append(float(r[1]) + grow)
		rz.append(float(r[2]) + grow)
		zc.append(float(r[3]))
		fr.append(float(r[4]))
	if ys.size() < 2:
		return
	# the loft runs top -> bottom so the fold weight grows toward the hem
	ys.reverse()
	rx.reverse()
	rz.reverse()
	zc.reverse()
	fr.reverse()
	mb.loft(ys, rx, rz, zc, fr, int(opts.get("sides", 26)), col, mat, opts)


## Torso envelope radius toward horizontal dir at height y (for belts, straps, aprons).
func _env(dir: Vector3, y: float, _girth := 1.0, _f := false) -> float:
	var pr := _tprof()
	var a: Array = pr[0]
	var b: Array = pr[pr.size() - 1]
	for i in pr.size() - 1:
		if y >= float(pr[i][0]) and y <= float(pr[i + 1][0]):
			a = pr[i]
			b = pr[i + 1]
			break
	if y < float(a[0]):
		b = a
	var t := clampf((y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	var rx := lerpf(float(a[1]), float(b[1]), t)
	var rz := lerpf(float(a[2]), float(b[2]), t)
	var fr := lerpf(float(a[4]), float(b[4]), t)
	var d := Vector2(dir.x, dir.z).normalized()
	var r := 1.0 / sqrt(d.x * d.x / (rx * rx) + d.y * d.y / (rz * rz))
	if d.y < 0.0:
		r += fr * pow(-d.y, 3.0) * (1.0 - absf(d.x) * 0.6)
	return r


func _torso_v(mb: Variant, f: bool, cloth: Color, leather: Color, girth: float, garment: String, age: String) -> void:
	var g := girth
	var body := cloth if garment != "shirt" else LINEN.lerp(cloth, 0.55)
	var mat: int = DwarfMesh.MAT_CLOTH if garment != "shirt" else DwarfMesh.MAT_LINEN
	mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08 * k, 0), Vector3(0, P + 0.26 * k, 0))
	_loft_torso(mb, P - 0.1 * k, P + 0.5 * k, 0.0, body, mat, {"lumps": 0.012, "folds": Vector2(0.025, 11.0), "wrinkle": 0.012, "seam": 0.03})
	# shoulders, collar line, the neck
	mb.bind(B_CHEST)
	var sw: float = absf((rests[B_ARM_R] as Vector3).x)
	for s: float in [-1.0, 1.0]:
		mb.blob(Vector3(s * (sw - 0.03), 1.195, 0.012) * k, Vector3(0.046, 0.042, 0.05) * k, Basis.IDENTITY, body.lightened(0.03), DwarfMesh.MAT_CLOTH, {"lumps": 0.03, "rings": 8, "segs": 14})
		mb.tube(PackedVector3Array([Vector3(s * 0.06, 1.255, 0.0) * k, Vector3(s * (sw - 0.04), 1.248, 0.01) * k, Vector3(s * (sw + 0.02), 1.19, 0.02) * k]), _pf([0.004, 0.004, 0.004], k), 4, body.darkened(0.3), DwarfMesh.MAT_CLOTH, {"lumps": 0.0})
	mb.ring(Vector3(0, 1.255 * k, 0.0), Vector2(0.056, 0.05) * k, 0.008 * k, 0.012 * k, Basis.IDENTITY, body.darkened(0.12), DwarfMesh.MAT_CLOTH, 16)
	var skin_n := _c("skin", SKINS[0])
	if bool(cfg.get("pale", false)):
		skin_n = skin_n.lerp(Color(0.78, 0.8, 0.86), 0.55)
	mb.bind_blend(B_CHEST, B_HEAD, Vector3(0, 1.24 * k, 0), (rests[B_HEAD] as Vector3) + Vector3(0, 0.03, 0))
	mb.tube(PackedVector3Array([Vector3(0, 1.22 * k, 0.005), (rests[B_HEAD] as Vector3) + Vector3(0, -0.02, -0.005), hc + Vector3(0, -0.06, 0.0) * hs]), _pf([0.05, 0.045, 0.043], k * (0.92 if f else 1.0)), 12, skin_n.darkened(0.06), DwarfMesh.MAT_SKIN, {"caps": false})
	# belt (except robes with a cord, dresses with a sash)
	var by := P + 0.09 * k
	var belt_col := leather if garment != "dress" else cloth.darkened(0.25)
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 29:
		var a := TAU * float(i) / 28.0
		var dir := Vector3(sin(a), 0.0, -cos(a))
		pts.append(Vector3(0, by, 0) + dir * (_env(dir, by, g, f) + (0.026 if garment in ["coat", "robe"] else 0.008) * k))
		rr.append((0.012 if garment != "robe" else 0.008) * k)
	mb.bind(B_SPINE)
	mb.tube(pts, rr, 6, belt_col if garment != "robe" else Color(0.46, 0.4, 0.3), DwarfMesh.MAT_LEATHER if garment != "robe" else DwarfMesh.MAT_LINEN, {"squash": Vector2(1.0, 2.4) if garment != "robe" else Vector2.ONE, "lumps": 0.0, "caps": false, "ref": Vector3.UP})
	if garment != "robe" and garment != "dress":
		var front: Vector3 = pts[0] + Vector3(0, 0, -0.01 * k)
		mb.blob(front, Vector3(0.028, 0.026, 0.008) * k, Basis.IDENTITY, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 8})
	else:
		# a cord knot and two hanging ends
		var kn: Vector3 = pts[3]
		mb.blob(kn, Vector3(0.02, 0.018, 0.016) * k, Basis.IDENTITY, Color(0.46, 0.4, 0.3), DwarfMesh.MAT_LINEN, {"lumps": 0.1, "rings": 4, "segs": 8})
		for e in 2:
			mb.tube(PackedVector3Array([kn, kn + Vector3(0.01 * float(e), -0.12, -0.01) * k, kn + Vector3(0.02 * float(e), -0.24, 0.0) * k]), _pf([0.006, 0.006, 0.005], k), 4, Color(0.46, 0.4, 0.3), DwarfMesh.MAT_LINEN, {"lumps": 0.0})


func _head_v(mb: Variant, f: bool, skin: Color, age: String, hair: Color) -> void:
	var fc: Variant = face()
	var pale := bool(cfg.get("pale", false))
	fc.skin = skin
	fc.ruddy = skin.lerp(Color(0.84, 0.46, 0.32), 0.05 if pale else 0.2)
	fc.lip_c = fc.ruddy.lerp(Color(0.62, 0.24, 0.22), (0.3 if f else 0.18) * (0.4 if pale else 1.0))
	if not f and age in ["adult", "old"]:
		fc.stubble = 0.5 if String(cfg.get("beard", "")) == "" else 1.0
		fc.stubble_c = hair.darkened(0.35).lerp(skin, 0.3) if String(cfg.get("beard", "")) == "" else hair.darkened(0.2)
	fc.build(mb)
	var eye_c: Color = EYES[_rng.randi_range(0, EYES.size() - 1)]
	if pale:
		eye_c = Color(0.55, 0.62, 0.7)
	fc.eyes(mb, eye_c, 0.55 if age == "old" else 0.15)
	fc.brows(mb, hair.darkened(0.12), 0.6 if (age == "old" and not f) else 0.0, _rng)
	if not bool(cfg.get("hood", false)):
		fc.ears(mb, fc.ruddy.darkened(0.04), 1.0)


func _hair_v(mb: Variant, hair: Color, style: String, f: bool) -> void:
	var c := hc
	var S := hs
	mb.bind(B_HEAD)
	var hood := bool(cfg.get("hood", false))
	if style == "bald" or (hood and style in ["short", "fringe"]):
		return
	match style:
		"short", "fringe":
			if style == "short":
				mb.blob(c + Vector3(0, 0.012, 0.006) * S, Vector3(0.092, 0.11, 0.104) * S, Basis(Vector3.RIGHT, 0.36), hair.darkened(0.08), DwarfMesh.MAT_HAIR, {"phi": Vector2(0.0, 0.45), "lumps": 0.12, "rings": 8, "segs": 20})
			for i in (36 if style == "short" else 30):
				var a := lerpf(-2.2, 2.2, (float(i) + _rng.randf_range(-0.4, 0.4)) / 35.0) + PI
				var root := c + Vector3(sin(a) * 0.088, 0.02 + (0.03 if style == "short" else 0.0) - 0.01 * cos(a), -cos(a) * 0.098) * S
				mb.strand(root, Vector3(sin(a) * 0.3, -1, -cos(a) * 0.4), _rng.randf_range(0.04, 0.07) * S, 0.009 * S, hair.lightened(_rng.randf_range(-0.08, 0.08)), Vector3.ZERO, 0.3, 3, 4)
		"bun", "braids", "long", "wild":
			# a combed scalp (parting), then the style
			mb.blob(c + Vector3(0, 0.014, 0.004) * S, Vector3(0.094, 0.112, 0.106) * S, Basis(Vector3.RIGHT, 0.36), hair.darkened(0.06), DwarfMesh.MAT_HAIR, {"phi": Vector2(0.0, 0.38 if String(cfg.get("hat", "")) != "" else 0.47), "lumps": 0.06, "rings": 9, "segs": 20})
			for i in 26:
				var a2 := lerpf(-1.35, 1.35, float(i) / 25.0)
				var root2 := c + Vector3(sin(a2) * 0.03, 0.105, -0.04) * S
				var dir2 := Vector3(sin(a2) * 1.0, -0.15, 0.7 + absf(a2) * 0.2)
				mb.strand(root2, dir2, (0.12 + absf(a2) * 0.03) * S, 0.009 * S, hair.lightened(_rng.randf_range(-0.06, 0.08)), Vector3(0, -0.8, 0), 0.6, 5, 4)
			match style:
				"bun":
					mb.blob(c + Vector3(0, 0.02, 0.105) * S, Vector3(0.045, 0.04, 0.035) * S, Basis.IDENTITY, hair.darkened(0.1), DwarfMesh.MAT_HAIR, {"lumps": 0.2, "rings": 7, "segs": 12})
					mb.ring(c + Vector3(0, 0.02, 0.098) * S, Vector2(0.03, 0.026) * S, 0.006 * S, 0.0, Basis(Vector3.RIGHT, PI * 0.5), LEATHERS[1], DwarfMesh.MAT_LEATHER, 10)
				"braids":
					for s: float in [-1.0, 1.0]:
						var t0 := c + Vector3(s * 0.07, -0.04, 0.05) * S
						var path := PackedVector3Array([t0, t0 + Vector3(s * 0.02, -0.12, -0.01) * S, t0 + Vector3(s * 0.03, -0.24, -0.035) * S])
						mb.bind_blend(B_HEAD, B_CHEST, t0, t0 + Vector3(0, -0.15, 0))
						mb.braid(path, 0.022 * S, hair.darkened(0.02), 7)
						mb.ring(path[2] + Vector3(0, 0.02, 0), Vector2(0.016, 0.016) * S, 0.005 * S, 0.012 * S, Basis.IDENTITY, Color(0.5, 0.42, 0.3), DwarfMesh.MAT_LINEN, 8)
						mb.bind(B_HEAD)
				"long", "wild":
					var n := 60 if style == "long" else 70
					mb.bind_blend(B_HEAD, B_CHEST, c + Vector3(0, -0.05, 0) * S, c + Vector3(0, -0.25, 0) * S)
					for i in n:
						var a3 := lerpf(-2.0, 2.0, (float(i) + _rng.randf_range(-0.45, 0.45)) / float(n - 1)) + PI
						var root3 := c + Vector3(sin(a3) * 0.095, 0.03 + 0.02 * cos(a3), -cos(a3) * 0.103) * S
						var ln := _rng.randf_range(0.2, 0.3) if style == "long" else _rng.randf_range(0.14, 0.3)
						var curl := Vector3.ZERO if style == "long" else Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.3, 0.5))
						mb.strand(root3, Vector3(sin(a3) * 0.25, -1, -cos(a3) * 0.35), ln * S, 0.011 * S, hair.lightened(_rng.randf_range(-0.08, 0.08)), curl, 0.35, 6, 4)
					mb.bind(B_HEAD)


func _beard_v(mb: Variant, hair: Color, kind: String) -> void:
	var fc: Variant = face()
	var my: float = fc.mouth_y
	var rz: float = fc.R.z
	var S := hs
	var col := hair.lerp(Color(0.6, 0.53, 0.44), 0.25)
	# (the skin under the beard is already painted in the hair colour: stubble 1 on the face)
	# moustache: two combed locks from under the nose out over the corners of the mouth
	mb.bind(B_HEAD)
	for s: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for q: Array in [[0.03, my + 0.13, 0.08], [0.17, my + 0.08, 0.12], [0.3, my - 0.02, 0.12], [0.36, my - 0.15, 0.1]]:
			path.append(fc.point(s * float(q[0]), float(q[1])) + fc.normal(s * float(q[0]), float(q[1])) * rz * float(q[2]))
		mb.tube(path, _pf([0.006, 0.0075, 0.006, 0.003], S), 7, col.lightened(0.04), DwarfMesh.MAT_HAIR, {"lumps": 0.1, "squash": Vector2(1.0, 0.65)})
	# short: a trimmed shell over jaw and chin, and a fringe of short hairs along its lower edge
	fc.beard_shell(mb, col.darkened(0.05), 0.0045 * S, -0.08, 0.004 * S if kind == "short" else 0.0)
	for i in 40:
		var x := _rng.randf_range(-0.8, 0.8)
		var y := -sqrt(maxf(0.95 - x * x, 0.0)) + _rng.randf_range(0.0, 0.06)
		var root: Vector3 = fc.point(x, y)
		var nn: Vector3 = fc.normal(x, y)
		mb.bind(B_JAW if absf(x) < 0.55 else B_HEAD)
		mb.strand(root + nn * 0.003 * S, Vector3.DOWN + nn * 0.4, _rng.randf_range(0.012, 0.02) * S, 0.004 * S, col.lightened(_rng.randf_range(-0.08, 0.08)), Vector3.ZERO, 0.2, 2, 3)
	if kind != "long":
		mb.bind(B_HEAD)
		return
	# long: a mass from the jaw onto the chest, combed locks laid over it in two layers
	var c := hc
	mb.bind_blend(B_JAW, B_CHEST, c + Vector3(0, -0.08, 0) * S, c + Vector3(0, -0.34, 0) * S)
	mb.blob(c + Vector3(0, -0.1, -0.055) * S, Vector3(0.068, 0.045, 0.05) * S, Basis.IDENTITY, col.darkened(0.12), DwarfMesh.MAT_HAIR, {"lumps": 0.12, "rings": 8, "segs": 16})
	mb.blob(c + Vector3(0, -0.22, -0.075) * S, Vector3(0.055, 0.11, 0.032) * S, Basis(Vector3.RIGHT, -0.15), col.darkened(0.14), DwarfMesh.MAT_HAIR, {"lumps": 0.15, "rings": 8, "segs": 14})
	for layer in 2:
		var m := 17
		for i2 in m:
			var a := lerpf(-1.4, 1.4, (float(i2) + _rng.randf_range(-0.4, 0.4)) / float(m - 1)) * (1.0 - 0.1 * float(layer))
			var ln := _rng.randf_range(0.6, 1.0) - absf(a) * 0.25
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			var wave := _rng.randf_range(0.0, TAU)
			for j in 7:
				var t := float(j) / 6.0 * ln
				var y2 := lerpf(-0.07, -0.36, t)
				var rx := lerpf(0.074, 0.03, pow(t, 1.2)) * (1.0 + 0.05 * float(layer))
				var rzz := lerpf(0.06, 0.03, t)
				var aa := a * lerpf(1.0, 0.7, t)
				pts.append(c + Vector3(sin(aa) * rx + sin(wave + t * 10.0) * 0.008 * t, y2, lerpf(-0.045, -0.085, t) - cos(aa) * rzz - 0.006 * float(layer)) * S)
				rr.append(0.014 * S * (1.0 - 0.9 * pow(t / ln, 1.3)))
			mb.tube(pts, rr, 6, col.lightened(_rng.randf_range(-0.1, 0.12) + 0.05 * float(layer) - 0.04), DwarfMesh.MAT_HAIR, {"lumps": 0.03, "squash": Vector2(1.0, 0.45)})
	mb.bind(B_HEAD)


func _headwear(mb: Variant, cloth: Color, cloth2: Color, hair: Color, leather: Color) -> void:
	var c := hc
	var S := hs
	mb.bind(B_HEAD)
	if bool(cfg.get("hood", false)):
		var hood := cloth.darkened(0.15)
		mb.blob(c + Vector3(0, 0.012, 0.02) * S, Vector3(0.118, 0.13, 0.125) * S, Basis(Vector3.RIGHT, 1.05), hood, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.66), "lumps": 0.05, "rings": 10, "segs": 22, "folds": Vector3(0.05, 7.0, 0.3)})
		# the hood's rim frames the face: forward of the brow and nearly upright (it used to lean back
		# through the face, a band across the eyes from any camera above her)
		mb.ring(c + Vector3(0, 0.0, -0.088) * S, Vector2(0.094, 0.112) * S, 0.012 * S, 0.0, Basis(Vector3.RIGHT, PI * 0.5 - 0.16), hood.darkened(0.12), DwarfMesh.MAT_CLOTH, 20, {"lumps": 0.1})
		mb.bind(B_CHEST)
		mb.blob(Vector3(0, 1.24 * k, 0.02 * k), Vector3(0.2, 0.07, 0.16) * k, Basis.IDENTITY, hood, DwarfMesh.MAT_CLOTH, {"lumps": 0.06, "rings": 8, "segs": 22, "folds": Vector3(0.12, 8.0, 0.4)})
		return
	match String(cfg.get("hat", "")):
		"brim":
			# worn pushed back off the brow (tb): level, the brim hid the whole face from any camera
			# above eye height, which is every camera the wanderer has
			var felt := cloth2.darkened(0.25).lerp(Color(0.18, 0.16, 0.15), 0.4)
			var tb := Basis(Vector3.RIGHT, 0.24)
			var o := Vector3(0, 0.012, 0.012)
			mb.blob(c + tb * (Vector3(0, 0.065, 0.005) + o) * S, Vector3(0.094, 0.07, 0.102) * S, tb, felt, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.55), "lumps": 0.04, "rings": 8, "segs": 20})
			mb.tube(PackedVector3Array([c + tb * (Vector3(0, 0.05, 0.005) + o) * S, c + tb * (Vector3(0, 0.058, 0.005) + o) * S]), _pf([0.138, 0.132], S), 26, felt.darkened(0.05), DwarfMesh.MAT_CLOTH, {"lumps": 0.08, "folds": Vector2(0.04, 5.0)})
			mb.ring(c + tb * (Vector3(0, 0.07, 0.005) + o) * S, Vector2(0.097, 0.105) * S, 0.007 * S, 0.016 * S, tb, leather, DwarfMesh.MAT_LEATHER, 18)
		"cap":
			var cc := cloth2.lightened(0.05)
			mb.blob(c + Vector3(0, 0.05, 0.01) * S, Vector3(0.1, 0.075, 0.108) * S, Basis(Vector3.RIGHT, -0.15), cc, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.0, 0.55), "lumps": 0.05, "rings": 8, "segs": 20})
			mb.blob(c + Vector3(0, 0.045, -0.1) * S, Vector3(0.07, 0.008, 0.04) * S, Basis.IDENTITY, cc.darkened(0.15), DwarfMesh.MAT_CLOTH, {"lumps": 0.0, "rings": 4, "segs": 12})
		"kerchief":
			var kc := cloth2.lerp(Color(0.62, 0.22, 0.12), 0.45)
			mb.blob(c + Vector3(0, 0.03, 0.012) * S, Vector3(0.099, 0.104, 0.11) * S, Basis(Vector3.RIGHT, 0.55), kc, DwarfMesh.MAT_LINEN, {"phi": Vector2(0.0, 0.5), "lumps": 0.05, "rings": 8, "segs": 20, "folds": Vector3(0.03, 9.0, 0.2)})
			var kn := c + Vector3(0, -0.02, 0.1) * S
			mb.blob(kn, Vector3(0.025, 0.02, 0.018) * S, Basis.IDENTITY, kc.darkened(0.1), DwarfMesh.MAT_LINEN, {"lumps": 0.15, "rings": 5, "segs": 8})
			for e: float in [-1.0, 1.0]:
				mb.tube(PackedVector3Array([kn, kn + Vector3(e * 0.03, -0.05, 0.02) * S, kn + Vector3(e * 0.04, -0.09, 0.01) * S]), _pf([0.014, 0.012, 0.004], S), 6, kc.darkened(0.05), DwarfMesh.MAT_LINEN, {"lumps": 0.05, "squash": Vector2(1.0, 0.3)})


## A hand at wrist w along forearm fo: a fist round the tool axis, or open and half curled.
func _hand_v(mb: Variant, side: int, skin: Color, fist: bool) -> void:
	var s := 1.0 if side == 0 else -1.0
	var ba := B_ARM_R if side == 0 else B_ARM_L
	var w: Vector3 = rests[ba + 2]
	var fo: Vector3 = (w - rests[ba + 1]).normalized()
	var pn := Vector3(-s, 0, 0).slide(fo).normalized()
	var ax: Vector3 = grip_ax[side]
	var K := k
	var knuckle := skin.darkened(0.06)
	mb.bind(ba + 2)
	mb.blob(w + fo * 0.045 * K, Vector3(0.036, 0.046, 0.018) * K, Basis(ax, fo, ax.cross(fo)).orthonormalized(), skin, DwarfMesh.MAT_SKIN, {"lumps": 0.04, "rings": 8, "segs": 12})
	var g: Vector3 = grip[side]
	var rp := 0.017 * K
	for i in 4:
		var o := (float(i) - 1.5) * 0.019 * K
		var r := (0.0095 - 0.0007 * float(i)) * K
		var kn := w + fo * 0.088 * K + ax * o
		var pts := PackedVector3Array([kn - fo * 0.01 * K])
		if fist:
			for th: float in [0.25, 1.2, 2.2, 2.9]:
				pts.append(g + ax * o + (fo * cos(th) + pn * sin(th)) * (rp + r * 1.1))
		else:
			pts.append(kn + fo * 0.025 * K + pn * 0.004 * K)
			pts.append(kn + fo * 0.048 * K + pn * 0.014 * K)
			pts.append(kn + fo * 0.062 * K + pn * 0.03 * K)
		var radii := PackedFloat32Array()
		for j in pts.size():
			radii.append(r * (1.1 - 0.25 * float(j) / float(pts.size())))
		mb.tube(pts, radii, 6, skin if i % 2 == 0 else knuckle, DwarfMesh.MAT_SKIN, {"lumps": 0.03})
	# thumb (on the forward side of the palm)
	var tb := w + fo * 0.025 * K + ax * 0.026 * K + pn * 0.012 * K
	if fist:
		mb.tube(PackedVector3Array([tb, g + ax * 0.034 * K - fo * 0.012 * K + pn * 0.004 * K, g + ax * 0.03 * K + fo * 0.012 * K + pn * 0.022 * K]), _pf([0.012, 0.01, 0.0085], K), 6, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.03})
	else:
		mb.tube(PackedVector3Array([tb, tb + fo * 0.03 * K + ax * 0.012 * K + pn * 0.01 * K, tb + fo * 0.05 * K + ax * 0.008 * K + pn * 0.022 * K]), _pf([0.012, 0.01, 0.0085], K), 6, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.03})


func _arms_v(mb: Variant, cloth: Color, skin: Color, leather: Color, garment: String) -> void:
	var rolled := garment == "shirt" and String(cfg.get("apron", "")) == "leather"
	var sleeve := cloth if garment != "shirt" else LINEN.lerp(cloth, 0.55)
	var mat: int = DwarfMesh.MAT_CLOTH if garment != "shirt" else DwarfMesh.MAT_LINEN
	var pale := bool(cfg.get("pale", false))
	if pale:
		skin = skin.lerp(Color(0.78, 0.8, 0.86), 0.55)
	var wide := 1.25 if garment == "robe" else 1.0
	for side in 2:
		var ba := B_ARM_R if side == 0 else B_ARM_L
		var sh: Vector3 = rests[ba]
		var el: Vector3 = rests[ba + 1]
		var wr: Vector3 = rests[ba + 2]
		var up := (el - sh).normalized()
		var fo := (wr - el).normalized()
		mb.bind_blend(ba, ba + 1, el - up * 0.05 * k, el + fo * 0.05 * k)
		mb.tube(PackedVector3Array([sh + up * 0.01 * k, sh.lerp(el, 0.4), el, el + fo * 0.05 * k]), _pf([0.044, 0.05, 0.046, 0.044], k * wide), 14, sleeve, mat, {"folds": Vector2(0.05, 5.0), "ripple": Vector2(0.03, 9.0), "lumps": 0.03})
		mb.bind(ba + 1)
		if rolled:
			mb.tube(PackedVector3Array([el + fo * 0.02 * k, el + fo * 0.07 * k]), _pf([0.05, 0.048], k), 14, sleeve.lightened(0.06), mat, {"lumps": 0.08})
			mb.tube(PackedVector3Array([el + fo * 0.06 * k, el.lerp(wr, 0.55), wr - fo * 0.01 * k]), _pf([0.04, 0.036, 0.03], k), 12, skin, DwarfMesh.MAT_SKIN, {"lumps": 0.03})
		else:
			var cuff := 1.35 if garment == "robe" else 1.0
			mb.tube(PackedVector3Array([el + fo * 0.03 * k, el.lerp(wr, 0.5), wr - fo * 0.02 * k]), _pf([0.045 * wide, 0.042 * wide, 0.038 * cuff], k), 14, sleeve.darkened(0.03), mat, {"folds": Vector2(0.04, 6.0), "ripple": Vector2(0.03, 11.0), "lumps": 0.03})
			mb.tube(PackedVector3Array([wr - fo * 0.04 * k, wr - fo * 0.005 * k]), _pf([0.04 * cuff, 0.041 * cuff], k), 14, sleeve.lightened(0.05), mat, {"lumps": 0.05})
		mb.tube(PackedVector3Array([wr - fo * 0.02 * k, wr + fo * 0.02 * k]), _pf([0.027, 0.028], k), 10, skin, DwarfMesh.MAT_SKIN, {"caps": false})
		var fist := String(cfg.get("r" if side == 0 else "l", "")) != ""
		_hand_v(mb, side, skin, fist)


func _legs_v(mb: Variant, trouser: Color, leather: Color, garment: String, barefoot: bool) -> void:
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		var bt := B_THIGH_R if side == 0 else B_THIGH_L
		var hip: Vector3 = rests[bt]
		var knee: Vector3 = rests[bt + 1]
		var an := ankle(s)
		var th := (knee - hip).normalized()
		var sn := (an - knee).normalized()
		mb.bind_blend(bt, bt + 1, knee - th * 0.05 * k, knee + sn * 0.05 * k)
		mb.tube(PackedVector3Array([hip - th * 0.04 * k, hip.lerp(knee, 0.5), knee - th * 0.02 * k, knee + sn * 0.04 * k]), _pf([0.078, 0.07, 0.058, 0.054], k), 14, trouser, DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.04, 4.0), "ripple": Vector2(0.025, 7.0), "lumps": 0.03})
		mb.bind(bt + 1)
		var top := an + Vector3.UP * (0.2 * k if not barefoot else 0.05 * k)
		mb.tube(PackedVector3Array([knee + sn * 0.02 * k, knee.lerp(top, 0.55), top]), _pf([0.053, 0.05, 0.044], k), 14, trouser.darkened(0.04), DwarfMesh.MAT_CLOTH, {"folds": Vector2(0.05, 5.0), "ripple": Vector2(0.03, 10.0), "lumps": 0.03})
		if barefoot:
			# rag-wrapped feet: bindings round the ankle, a lumpy wrapped foot
			var rag := Color(0.52, 0.47, 0.4)
			mb.tube(PackedVector3Array([an + Vector3.DOWN * 0.03 * k, an + Vector3.UP * 0.06 * k]), _pf([0.04, 0.042], k), 12, rag, DwarfMesh.MAT_LINEN, {"lumps": 0.12, "ripple": Vector2(0.08, 18.0)})
			mb.blob(an + Vector3(0, -0.04, -0.06) * k, Vector3(0.045, 0.035, 0.1) * k, Basis.IDENTITY, rag.darkened(0.1), DwarfMesh.MAT_LINEN, {"lumps": 0.12, "rings": 7, "segs": 12})
			continue
		var boot := leather.darkened(0.25)
		mb.tube(PackedVector3Array([an + Vector3.DOWN * 0.03 * k, an + Vector3.UP * 0.08 * k, an + Vector3.UP * 0.19 * k]), _pf([0.05, 0.052, 0.055], k), 14, boot, DwarfMesh.MAT_LEATHER, {"lumps": 0.04, "ripple": Vector2(0.03, 14.0)})
		mb.tube(PackedVector3Array([an + Vector3.UP * 0.17 * k, an + Vector3.UP * 0.21 * k]), _pf([0.06, 0.058], k), 14, boot.lightened(0.08), DwarfMesh.MAT_LEATHER, {"lumps": 0.05})
		mb.blob(an + Vector3(0, -0.035, -0.06) * k, Vector3(0.048, 0.04, 0.105) * k, Basis.IDENTITY, boot, DwarfMesh.MAT_LEATHER, {"lumps": 0.04, "rings": 8, "segs": 14})
		mb.blob(an + Vector3(0, -0.07, -0.055) * k, Vector3(0.052, 0.014, 0.118) * k, Basis.IDENTITY, Color(0.1, 0.08, 0.06), DwarfMesh.MAT_LEATHER, {"lumps": 0.0, "rings": 5, "segs": 14})
		mb.ring(an + Vector3.UP * 0.07 * k, Vector2(0.054, 0.054) * k, 0.005 * k, 0.012 * k, Basis.IDENTITY, leather.darkened(0.4), DwarfMesh.MAT_LEATHER, 14)


## Coat tails, dress skirts, robes: skinned in skirt mode (VMesh) so the hem follows the stride.
func _garment_v(mb: Variant, garment: String, cloth: Color, cloth2: Color, leather: Color, f: bool, girth: float) -> void:
	var g := girth
	var top := P + 0.11 * k
	match garment:
		"shirt":
			mb.bind(B_SPINE)
			var hem := P - 0.06 * k
			mb.tube(PackedVector3Array([Vector3(0, P + 0.06 * k, 0), Vector3(0, hem + 0.02 * k, 0), Vector3(0, hem, 0)]), _pf([0.16 * g, 0.172 * g, 0.175 * g], k), 24, LINEN.lerp(cloth, 0.55).darkened(0.06), DwarfMesh.MAT_LINEN, {"folds": Vector2(0.05, 8.0), "lumps": 0.02, "caps": false})
		"coat", "dress", "robe":
			var hem := 0.4 * k if garment == "coat" else (0.1 * k if garment == "dress" else 0.16 * k)
			var r0 := (0.165 if f else 0.158) * g * k
			var r1 := (0.25 if garment == "coat" else 0.28) * k * (1.0 + 0.1 * (g - 1.0))
			mb.bind_skirt(top, hem, 0.62 if garment != "coat" else 0.7, 0.11 * k)
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			var n := 7
			for i in n:
				var t := float(i) / float(n - 1)
				pts.append(Vector3(0, lerpf(top, hem, t), 0.01 * k * t))
				rr.append(lerpf(r0, r1, pow(t, 0.8)))
			var col := cloth if garment != "robe" else cloth.darkened(0.08)
			var folds := Vector2(0.07, 9.0) if garment != "coat" else Vector2(0.05, 7.0)
			mb.tube(pts, rr, 30, col, DwarfMesh.MAT_CLOTH, {"folds": folds, "lumps": 0.05 if garment == "robe" else 0.025, "caps": false, "ripple": Vector2(0.02, 3.0)})
			# hem: a darker band (dress), a tattered fringe (robe), a turned-back edge (coat)
			var hb := Vector3(0, hem, 0.01 * k)
			if garment == "robe":
				for i in 30:
					var a := TAU * float(i) / 30.0
					var dir := Vector3(sin(a), 0, -cos(a))
					var root := hb + dir * r1 * 0.98 + Vector3.UP * 0.02 * k
					mb.strand(root, Vector3.DOWN + dir * 0.2, _rng.randf_range(0.03, 0.08) * k, 0.012 * k, col.darkened(_rng.randf_range(0.0, 0.2)), Vector3.ZERO, 0.0, 2, 3)
			else:
				mb.tube(PackedVector3Array([hb + Vector3.UP * 0.03 * k, hb]), PackedFloat32Array([r1 + 0.002, r1 + 0.004]), 30, col.darkened(0.25), DwarfMesh.MAT_CLOTH, {"folds": folds, "lumps": 0.02, "caps": false})
			# coat: an overcoat shell on the torso, a collar, a button line
			if garment == "coat":
				mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08 * k, 0), Vector3(0, P + 0.24 * k, 0))
				_loft_torso(mb, P + 0.0 * k, P + 0.46 * k, 0.012 * k, col, DwarfMesh.MAT_CLOTH, {"lumps": 0.015, "folds": Vector2(0.03, 9.0), "wrinkle": 0.015, "seam": 0.03})
				# lapels: two turned-back flaps from the collar to the top button
				for s: float in [-1.0, 1.0]:
					var lg := PackedVector3Array()
					var lr := PackedFloat32Array()
					for i in 5:
						var t := float(i) / 4.0
						var yy := lerpf(P + 0.47 * k, P + 0.3 * k, t)
						var dx := Vector3(s * lerpf(0.06, 0.012, t), 0, -1).normalized()
						lg.append(Vector3(0, yy, 0) + dx * (_env(dx, yy) + 0.02 * k))
						lr.append(lerpf(0.016, 0.006, t) * k)
					mb.tube(lg, lr, 5, col.darkened(0.18), DwarfMesh.MAT_CLOTH, {"lumps": 0.0, "squash": Vector2(2.2, 0.45)})
				mb.bind(B_CHEST)
				mb.ring(Vector3(0, 1.26 * k, 0.0), Vector2(0.075, 0.068) * k, 0.016 * k, 0.05 * k, Basis(Vector3.RIGHT, -0.15), col.darkened(0.1), DwarfMesh.MAT_CLOTH, 18, {"lumps": 0.05})
				for i in 5:
					var by := lerpf(P + 0.42 * k, P + 0.06 * k, float(i) / 4.0)
					var dir := Vector3(0, 0, -1)
					var pz := -_env(dir, by, g, f) - 0.018 * k
					mb.bind(B_CHEST if by > P + 0.24 * k else B_SPINE)
					mb.blob(Vector3(0.01 * k, by, pz), Vector3(0.011, 0.011, 0.006) * k, Basis.IDENTITY, BRASS.darkened(0.3), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 8})
			elif garment == "robe":
				# a cowl folded round the shoulders (hooded or not)
				if not bool(cfg.get("hood", false)):
					mb.bind(B_CHEST)
					mb.blob(Vector3(0, 1.235 * k, 0.025 * k), Vector3(0.2, 0.065, 0.155) * k, Basis.IDENTITY, col.lightened(0.04), DwarfMesh.MAT_CLOTH, {"lumps": 0.08, "rings": 8, "segs": 22, "folds": Vector3(0.14, 8.0, 0.4)})
				mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.08 * k, 0), Vector3(0, P + 0.24 * k, 0))
				_loft_torso(mb, P + 0.0 * k, P + 0.44 * k, 0.018 * k, col, DwarfMesh.MAT_CLOTH, {"lumps": 0.03, "folds": Vector2(0.05, 8.0), "wrinkle": 0.02})
			mb.bind(B_SPINE)


func _apron_v(mb: Variant, kind: String, girth: float, garment: String) -> void:
	var leather := kind == "leather"
	var col := Color(0.34, 0.22, 0.13) if leather else LINEN.darkened(0.06)
	var f := String(cfg.get("sex", "m")) == "f"
	var top := P + (0.42 if leather else 0.12) * k
	var bot := (0.3 if leather else 0.22) * k
	var cols := 8
	var rows := 12
	var grid: Array[Vector3] = []
	var flare := 0.03 * k if garment == "dress" else 0.0
	for r in rows + 1:
		var v := float(r) / float(rows)
		var y := lerpf(top, bot, v)
		var half := lerpf(0.1, 0.16, smoothstep(0.0, 0.35, v)) * k
		for c in cols + 1:
			var u := float(c) / float(cols) * 2.0 - 1.0
			var dir := Vector3(u * half, 0, -0.2 * k).normalized()
			var rr := _env(dir, clampf(y, P, P + 0.42 * k), girth, f) if y > P else _env(dir, P, girth, f) + (P - y) * (0.25 if garment != "shirt" else 0.06) + flare
			var p := Vector3(u * half, y, -rr - 0.02 * k)
			p.z -= 0.01 * k * sin(u * 6.0 + v * 2.0) * smoothstep(0.3, 1.0, v)
			grid.append(p)
	if garment in ["dress", "coat", "robe"]:
		mb.bind_skirt(P + 0.1 * k, bot, 0.5, 0.11 * k)
	else:
		mb.bind_blend(B_SPINE, B_CHEST, Vector3(0, P + 0.1 * k, 0), Vector3(0, P + 0.28 * k, 0))
	mb.sheet(grid, cols, rows, col, DwarfMesh.MAT_LEATHER if leather else DwarfMesh.MAT_LINEN, 0.006 * k, Vector3.FORWARD)
	mb.bind(B_CHEST)
	if leather:
		for s: float in [-1.0, 1.0]:
			mb.tube(PackedVector3Array([Vector3(s * 0.09, top, -0.13) * Vector3(1, 1, k), Vector3(s * 0.07, 1.25 * k, -0.06 * k), Vector3(s * 0.05, 1.27 * k, 0.04 * k)]), _pf([0.008, 0.008, 0.008], k), 5, col.darkened(0.1), DwarfMesh.MAT_LEATHER, {"squash": Vector2(0.5, 1.6), "lumps": 0.0})


func _satchel(mb: Variant, leather: Color) -> void:
	mb.bind(B_CHEST)
	var a := Vector3(0.11, 1.25, -0.02) * k
	var b := Vector3(-0.16, P / k + 0.02, -0.0) * k
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		var p := a.lerp(b, t)
		var dir := Vector3(p.x, 0, -1.0).normalized()
		p.z = -_env(dir, p.y, float(cfg.get("girth", 1.0)), String(cfg.get("sex", "m")) == "f") - 0.012 * k
		pts.append(p)
		rr.append(0.009 * k)
	mb.tube(pts, rr, 5, leather.darkened(0.1), DwarfMesh.MAT_LEATHER, {"squash": Vector2(0.5, 2.2), "lumps": 0.0})
	mb.bind(B_SPINE)
	mb.blob(Vector3(-0.19, P / k - 0.02, 0.02) * k, Vector3(0.05, 0.075, 0.09) * k, Basis(Vector3.UP, 0.3), leather, DwarfMesh.MAT_LEATHER, {"lumps": 0.1, "rings": 8, "segs": 12})
	# a tin pilgrim's badge: the open door
	mb.bind(B_CHEST)
	mb.blob(pts[2] + Vector3(0, 0, -0.008) * k, Vector3(0.016, 0.022, 0.004) * k, Basis.IDENTITY, Color(0.62, 0.62, 0.6), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 4, "segs": 10})


func _shawl(mb: Variant, col: Color) -> void:
	mb.bind(B_CHEST)
	var sc := col.lerp(Color(0.3, 0.27, 0.25), 0.4)
	mb.blob(Vector3(0, 1.2 * k, 0.03 * k), Vector3(0.21, 0.09, 0.15) * k, Basis(Vector3.RIGHT, -0.12), sc, DwarfMesh.MAT_CLOTH, {"phi": Vector2(0.15, 0.95), "lumps": 0.06, "rings": 8, "segs": 22, "folds": Vector3(0.1, 10.0, 0.3)})
	mb.blob(Vector3(0, 1.13 * k, 0.11 * k), Vector3(0.16, 0.13, 0.04) * k, Basis(Vector3.RIGHT, 0.2), sc.darkened(0.05), DwarfMesh.MAT_CLOTH, {"lumps": 0.05, "rings": 8, "segs": 14})
	for i in 14:
		var x := lerpf(-0.14, 0.14, float(i) / 13.0)
		mb.strand(Vector3(x, 1.03, 0.13) * k, Vector3(0, -1, 0.2), 0.05 * k, 0.005 * k, sc.darkened(0.1), Vector3.ZERO, 0.0, 2, 3)


# =====================================================================================================
# tools, built along the fist's axis through the grip
# =====================================================================================================

func _tool(mb: Variant, side: int, kind: String, skin: Color) -> void:
	if kind == "":
		return
	var g: Vector3 = grip[side]
	var ax: Vector3 = grip_ax[side]
	var fd: Vector3 = (grip_up[side] as Vector3).slide(ax).normalized()        # the fingers' direction
	var K := k
	mb.bind(B_HAND_R if side == 0 else B_HAND_L)
	match kind:
		"hammer":
			mb.tube(PackedVector3Array([g - ax * 0.07 * K, g + ax * 0.12 * K, g + ax * 0.27 * K]), _pf([0.014, 0.013, 0.012], K), 8, WOOD, DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			var hh := g + ax * 0.28 * K
			mb.tube(PackedVector3Array([hh - fd * 0.06 * K, hh + fd * 0.035 * K]), _pf([0.026, 0.022], K), 10, IRON.darkened(0.2), DwarfMesh.MAT_METAL, {"lumps": 0.0, "squash": Vector2(1.0, 0.8)})
			tips[side] = hh + fd * 0.045 * K
		"tongs":
			for e: float in [-1.0, 1.0]:
				var side_v := ax.cross(fd).normalized() * 0.008 * K * e
				mb.tube(PackedVector3Array([g - ax * 0.06 * K + side_v, g + ax * 0.2 * K + side_v, g + ax * 0.3 * K + side_v * 0.3]), _pf([0.006, 0.006, 0.005], K), 5, IRON.darkened(0.3), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			tips[side] = g + ax * 0.36 * K
		"pole":
			mb.tube(PackedVector3Array([g - ax * 0.8 * K, g, g + ax * 1.3 * K, g + ax * 1.75 * K]), _pf([0.016, 0.017, 0.015, 0.013], K), 8, WOOD.darkened(0.1), DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			var tp := g + ax * 1.75 * K
			mb.tube(PackedVector3Array([tp, tp + ax * 0.05 * K, tp + ax * 0.08 * K + fd * 0.04 * K, tp + ax * 0.06 * K + fd * 0.07 * K]), _pf([0.007, 0.006, 0.005, 0.004], K), 5, BRASS, DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([tp - ax * 0.02 * K, tp + ax * 0.03 * K]), _pf([0.017, 0.012], K), 8, BRASS.darkened(0.2), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			tips[side] = tp + ax * 0.05 * K
		"staff", "crook":
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			for i in 9:
				var t := float(i) / 8.0
				var p := g + ax * lerpf(-1.05, 0.38, t) * K
				p += ax.cross(fd).normalized() * sin(t * 9.0) * 0.01 * K + fd * cos(t * 7.0) * 0.008 * K
				pts.append(p)
				rr.append(lerpf(0.017, 0.021, t) * K)
			mb.tube(pts, rr, 8, WOOD.darkened(0.25).lerp(Color(0.35, 0.3, 0.24), 0.3), DwarfMesh.MAT_WOOD, {"lumps": 0.08})
			if kind == "crook":
				var c0: Vector3 = pts[pts.size() - 1]
				mb.tube(PackedVector3Array([c0, c0 + ax * 0.06 * K - fd * 0.04 * K, c0 + ax * 0.04 * K - fd * 0.1 * K, c0 - fd * 0.1 * K]), _pf([0.02, 0.018, 0.016, 0.013], K), 8, WOOD.darkened(0.3), DwarfMesh.MAT_WOOD, {"lumps": 0.06})
			else:
				# a rag tied under the knob, a bundle of charms
				var kb: Vector3 = pts[7]
				mb.ring(kb, Vector2(0.024, 0.024) * K, 0.006 * K, 0.02 * K, Basis(ax, fd, ax.cross(fd)).orthonormalized() * Basis(Vector3.FORWARD, PI * 0.5), Color(0.5, 0.18, 0.1), DwarfMesh.MAT_LINEN, 10)
			tips[side] = g - ax * 1.05 * K
		"spade":
			mb.tube(PackedVector3Array([g - ax * 0.12 * K, g + ax * 0.5 * K, g + ax * 0.92 * K]), _pf([0.015, 0.015, 0.016], K), 8, WOOD, DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			var th := g - ax * 0.12 * K
			mb.tube(PackedVector3Array([th - ax.cross(fd).normalized() * 0.06 * K, th + ax.cross(fd).normalized() * 0.06 * K]), _pf([0.014, 0.014], K), 7, WOOD.darkened(0.15), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
			var bl := g + ax * 1.04 * K
			mb.blob(bl, Vector3(0.085, 0.11, 0.008) * K, Basis(ax.cross(fd).normalized(), ax, fd).orthonormalized(), IRON.darkened(0.35), DwarfMesh.MAT_METAL, {"lumps": 0.02, "rings": 6, "segs": 12})
			mb.blob(bl + ax * 0.04 * K, Vector3(0.08, 0.05, 0.02) * K, Basis(ax.cross(fd).normalized(), ax, fd).orthonormalized(), Color(0.24, 0.18, 0.13), DwarfMesh.MAT_LEATHER, {"lumps": 0.3, "rings": 5, "segs": 10})
			tips[side] = g + ax * 1.16 * K
		"axe":
			mb.tube(PackedVector3Array([g - ax * 0.08 * K, g + ax * 0.3 * K, g + ax * 0.55 * K]), _pf([0.015, 0.014, 0.016], K), 8, WOOD, DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			var ah := g + ax * 0.52 * K
			mb.blob(ah + fd * 0.05 * K, Vector3(0.012, 0.07, 0.04) * K, Basis(ax.cross(fd).normalized(), fd, ax).orthonormalized(), IRON.darkened(0.25), DwarfMesh.MAT_METAL, {"lumps": 0.0, "rings": 6, "segs": 10})
			tips[side] = ah + fd * 0.1 * K
		"sword":
			# r36 the Kindled Watch: a plain arming sword, wrapped grip, a bar guard, a flat blade
			mb.tube(PackedVector3Array([g - ax * 0.07 * K, g + ax * 0.08 * K]), _pf([0.014, 0.014], K), 7, (LEATHERS[1] as Color).darkened(0.3), DwarfMesh.MAT_LEATHER, {"lumps": 0.0})
			var gd := g + ax * 0.09 * K
			mb.tube(PackedVector3Array([gd - fd * 0.09 * K, gd + fd * 0.09 * K]), _pf([0.011, 0.011], K), 6, IRON.darkened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([gd + ax * 0.01 * K, gd + ax * 0.45 * K, gd + ax * 0.74 * K]), _pf([0.02, 0.017, 0.004], K), 6, IRON.lightened(0.15), DwarfMesh.MAT_METAL, {"lumps": 0.0, "squash": Vector2(1.0, 0.22)})
			tips[side] = gd + ax * 0.74 * K
		"scoop":
			mb.tube(PackedVector3Array([g - ax * 0.05 * K, g + ax * 0.22 * K]), _pf([0.011, 0.01], K), 7, WOOD.darkened(0.1), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
			mb.blob(g + ax * 0.28 * K - fd * 0.02 * K, Vector3(0.05, 0.03, 0.05) * K, Basis.IDENTITY, IRON.darkened(0.3), DwarfMesh.MAT_METAL, {"phi": Vector2(0.45, 1.0), "lumps": 0.0, "rings": 6, "segs": 12})
			tips[side] = g + ax * 0.28 * K
		"chalk":
			mb.blob(g + ax * 0.01 * K - fd * 0.02 * K, Vector3(0.008, 0.02, 0.008) * K, Basis.IDENTITY, Color(0.92, 0.9, 0.85), DwarfMesh.MAT_LINEN, {"lumps": 0.1, "rings": 4, "segs": 6})
		"lantern":
			# a bail from the fist, an iron cage with a cap and a base; the glass is the glow part
			var lc := g + fd * 0.2 * K
			mb.tube(PackedVector3Array([g - ax * 0.02 * K, g + fd * 0.06 * K, lc - fd * 0.11 * K]), _pf([0.004, 0.004, 0.004], K), 4, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([lc - fd * 0.1 * K, lc - fd * 0.075 * K]), _pf([0.03, 0.055], K), 8, IRON.darkened(0.3), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([lc + fd * 0.075 * K, lc + fd * 0.095 * K]), _pf([0.055, 0.05], K), 8, IRON.darkened(0.3), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			for i in 4:
				var a := TAU * float(i) / 4.0 + PI * 0.25
				var o := (ax * cos(a) + ax.cross(fd).normalized() * sin(a)) * 0.05 * K
				mb.tube(PackedVector3Array([lc + o + fd * 0.075 * K, lc + o - fd * 0.075 * K]), _pf([0.004, 0.004], K), 4, IRON.darkened(0.2), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			tips[side] = lc
		"candle":
			var cb := g + fd * 0.0
			mb.tube(PackedVector3Array([cb - ax * 0.02 * K, cb + ax * 0.04 * K]), _pf([0.035, 0.038], K), 10, IRON.darkened(0.3), DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([cb + ax * 0.03 * K, cb + ax * 0.12 * K]), _pf([0.012, 0.011], K), 8, Color(0.92, 0.88, 0.76), DwarfMesh.MAT_LINEN, {"lumps": 0.02})
			tips[side] = cb + ax * 0.135 * K


## The lantern's glass, the candle's flame or the iron in the tongs: a tiny unshaded mesh on a
## mesh carried with the hand (the villager dims it: `glow_mat.emission_energy_multiplier`, `glow.visible`).
func _glow_part() -> void:
	var kind := String(cfg.get("l", ""))
	var side := 1
	if not kind in ["lantern", "tongs"]:
		kind = String(cfg.get("r", ""))
		side = 0
		if kind != "candle":
			return
	_glow_side = side
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.66, 0.32) if kind != "tongs" else Color(1.0, 0.45, 0.12)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.55, 0.2) if kind != "tongs" else Color(1.0, 0.36, 0.06)
	glow_mat.emission_energy_multiplier = 1.25
	glow = MeshInstance3D.new()
	glow.name = "Glow"
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visibility_range_end = 80.0
	var fd: Vector3 = (grip_up[side] as Vector3).slide(grip_ax[side]).normalized()
	var ax: Vector3 = grip_ax[side]
	match kind:
		"lantern":
			var m := CylinderMesh.new()
			m.top_radius = 0.042 * k
			m.bottom_radius = 0.046 * k
			m.height = 0.14 * k
			m.radial_segments = 8
			m.rings = 1
			glow.mesh = m
			glow.basis = Basis(Quaternion(Vector3.UP, fd))
		"tongs":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.018, 0.018, 0.16) * k
			glow.mesh = bm
			glow.basis = Basis(Quaternion(Vector3.BACK, ax))
		_:
			var f := SphereMesh.new()
			f.radius = 0.012 * k
			f.height = 0.045 * k
			f.radial_segments = 8
			f.rings = 4
			glow.mesh = f
			glow.basis = Basis(Quaternion(Vector3.UP, ax))
	glow.material_override = glow_mat
	_glow_at = (tips[side] as Vector3) + ax * (0.02 * k if kind == "candle" else 0.0)
	_glow_basis = glow.basis
	add_child(glow)
	update_glow()


## Carry the glow part with its hand (call after posing; needs fk of the hand).
func update_glow() -> void:
	if glow == null:
		return
	var b := B_HAND_R if _glow_side == 0 else B_HAND_L
	fk_all()
	glow.position = carry(b, _glow_at)
	glow.basis = Basis(grot(b)) * _glow_basis

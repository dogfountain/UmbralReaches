extends RefCounted
## Bodies for the r28 enemy kin, built on an existing kind's body (EnemyBody, unchanged and shared)
## plus their own parts and their own copy of the flesh material. Parts go through GenCache (keyed
## by this file and CreatureMesh), the material is one per kin. Silhouettes, so each reads at 15 m:
##   Bulwark   husk frame behind a tall plank-and-iron door-shield with a skull boss, a slit iron
##             helm with a crest of spikes, heavy pauldrons; ash-grey hide, ember eyes
##   Chanter   gaunt wretch frame in a long dark robe to the ground and a tall peaked hood, a
##             bone staff topped by a caged corpse-light (pale green); bluish skin
##   Burrower  crawler frame, bigger, under a domed earth-crusted carapace, two great shovel claws
##             on the forelegs, an eyeless ridged snout; brown, dim amber glow
##   Mite      a crawler at half size, pale, with a glowing teal sac on its back (a swarm reads as
##             a scatter of moving lights)
## Load by path (no class_name):  const KinLook := preload("res://core/enemy/kin_look.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const GruntModel := preload("res://core/enemy/grunt_model.gd")
const SELF_PATH := "res://core/enemy/kin_look.gd"
const CM_PATH := "res://core/enemy/creature_mesh.gd"

const IRON := Color(0.3, 0.29, 0.32)
const RUST := Color(0.46, 0.27, 0.17)
const WOOD := Color(0.34, 0.24, 0.17)
const BONE := Color(0.92, 0.88, 0.8)
const CLOTH := Color(0.55, 0.5, 0.5)
const GLOAM := Color(0.75, 1.9, 0.45)
const MITE_GLOW := Color(0.35, 1.6, 1.25)

const KINS := {
	"bulwark": {"base": &"husk", "skin": Color(0.38, 0.36, 0.4), "deep": Color(0.11, 0.09, 0.11), "eye": Color(1.9, 0.6, 0.15), "rim": 0.4, "bone": Color(0.5, 0.48, 0.5), "linen": Color(0.3, 0.24, 0.19)},
	"chanter": {"base": &"wretch", "skin": Color(0.5, 0.53, 0.62), "deep": Color(0.12, 0.1, 0.2), "eye": Color(0.75, 1.9, 0.45), "rim": 0.6, "linen": Color(0.12, 0.11, 0.12), "rag": Color(0.07, 0.06, 0.07)},
	"burrower": {"base": &"crawler", "skin": Color(0.44, 0.33, 0.24), "deep": Color(0.13, 0.08, 0.05), "eye": Color(1.2, 0.55, 0.1), "rim": 0.45, "bone": Color(0.4, 0.31, 0.22)},
	"mite": {"base": &"crawler", "skin": Color(0.64, 0.58, 0.72), "deep": Color(0.2, 0.12, 0.24), "eye": Color(0.35, 1.6, 1.25), "rim": 0.85, "bone": Color(0.5, 0.44, 0.56)},
}

static var _mats := {}
static var _parts := {}
static var _glow := {}


static func has(kind: String) -> bool:
	return KINS.has(kind)


static func base_kind(kind: String) -> StringName:
	return KINS.get(kind, {}).get("base", &"wretch")


static func material(kind: String) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var p: Dictionary = KINS[kind]
	var m := EnemyBody.material(p.base).duplicate() as ShaderMaterial
	m.set_shader_parameter("skin", p.skin)
	m.set_shader_parameter("skin_deep", p.deep)
	m.set_shader_parameter("eye_col", p.eye)
	var ec: Color = p.eye
	var em := maxf(ec.r, maxf(ec.g, ec.b))
	m.set_shader_parameter("rim_col", Color(ec.r / em, ec.g / em, ec.b / em))   # the kin's own eye-colour accent edge
	m.set_shader_parameter("rim_amount", float(p.rim) * 0.7)
	if p.has("bone"):
		m.set_shader_parameter("bone_col", p.bone)
	if p.has("linen"):
		m.set_shader_parameter("linen_col", p.linen)
	if p.has("rag"):
		m.set_shader_parameter("rag_col", p.rag)
	_mats[kind] = m
	return m


static func glow_mat(kind: String) -> Material:
	if not _glow.has(kind):
		_glow[kind] = ProcMesh.glow_mat(MITE_GLOW if kind == "mite" else GLOAM)
	return _glow[kind]


## Dress the enemy's rig: the base kind's shared body under this kin's material, then its parts.
## Returns the flesh parts (for hit flash / glint / dissolve), parts named "Kin_<part>_<socket>".
static func dress(e: Enemy, kind: String) -> Array[MeshInstance3D]:
	var rig := e._rig
	# r30: a modelled kin (tools/blender/grunt_*.py) replaces the base body and these parts whole
	if GruntModel.has(StringName(kind)):
		var modelled := GruntModel.dress(rig, StringName(kind))
		if not modelled.is_empty():
			return modelled
	var flesh := EnemyBody.dress(rig, base_kind(kind))
	var mat := material(kind)
	for mi in flesh:
		mi.material_override = mat
	var parts := parts_for(kind, rig)
	for key: String in parts:
		var bits := key.split(":")
		var sock := bits[bits.size() - 1]
		var tag := bits[0] if bits.size() > 1 else "part"
		var at := rig.socket(sock)
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Kin_%s_%s" % [tag, sock]
		mi.mesh = parts[key]
		var glow := tag == "glow"
		mi.material_override = glow_mat(kind) if glow else mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tag == "shield" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		if not glow:
			flesh.append(mi)
	return flesh


static func parts_for(kind: String, rig: CharacterRig) -> Dictionary:
	if _parts.has(kind):
		return _parts[kind]
	var full := "kin_%s_%d" % [kind, GenCache.salt(CM_PATH)]
	var got := {}
	var joints: Variant = GenCache.load_var(full + "_joints", SELF_PATH)
	if joints is PackedStringArray:
		for j: String in joints:
			var m := GenCache.load_mesh(full + "_" + j.replace(":", "-"), SELF_PATH)
			if m == null:
				got.clear()
				break
			got[j] = m
	if got.is_empty():
		match kind:
			"bulwark": got = _bulwark()
			"chanter": got = _chanter()
			"burrower": got = _burrower(rig as QuadRig)
			"mite": got = _mite(rig as QuadRig)
		var names := PackedStringArray()
		for j: String in got:
			names.append(j)
			GenCache.save_mesh(full + "_" + j.replace(":", "-"), SELF_PATH, got[j])
		GenCache.save_var(full + "_joints", SELF_PATH, names)
	_parts[kind] = got
	return got


static func _cm(seed_v: int) -> CreatureMesh:
	var c := CreatureMesh.new(seed_v)
	c.metric_uv = true
	return c


static func _ring(c: CreatureMesh, center: Vector3, r: float, thick: float, col: Color, bone := 1.0) -> void:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 13:
		var a := TAU * float(i) / 12.0
		pts.append(center + Vector3(cos(a) * r, sin(a * 3.0) * 0.004, sin(a) * r))
		rad.append(thick)
	c.tube(pts, rad, 4, col, bone, 0.0)


# --- Bulwark ----------------------------------------------------------------------------------

## The door-shield rides the chest socket (not a hand: a hand swings with every step and rake),
## held a hand's breadth in front, from the knees to the brow.
static func _bulwark() -> Dictionary:
	var parts := {}
	var s := _cm(5101)
	var cz := -0.4
	for k in 5:
		var x := -0.24 + 0.12 * float(k)
		var tall := 0.5 + 0.03 * float((k * 3) % 2)
		s.plate(Vector3(x, -0.24 + 0.02 * float(k % 2), cz), Vector3(tall, 0.035, 0.068), Vector3(0, 0, -1), WOOD, 1.0, 0.1)
	for y: float in [0.1, -0.24, -0.6]:
		s.tube(PackedVector3Array([Vector3(-0.31, y, cz - 0.03), Vector3(0.0, y + 0.01, cz - 0.045), Vector3(0.31, y, cz - 0.03)]),
			PackedFloat32Array([0.02, 0.022, 0.02]), 5, IRON, 1.0, 0.04, 0.0, Vector2(0.5, 1.0))
		for k in 4:
			s.blob(Vector3(-0.24 + 0.16 * float(k), y, cz - 0.06), Vector3(0.014, 0.014, 0.012), Basis.IDENTITY, Color(0.55, 0.52, 0.5), 1.0, 0.0, 0.0, 3, 6)
	# a skull boss nailed to the middle, eyes glowing faintly
	s.blob(Vector3(0.0, -0.12, cz - 0.08), Vector3(0.07, 0.08, 0.06), Basis.IDENTITY, BONE, 1.0, 0.06)
	for sx: float in [-1.0, 1.0]:
		s.blob(Vector3(sx * 0.028, -0.1, cz - 0.13), Vector3(0.016, 0.016, 0.01), Basis.IDENTITY, Color(0.1, 0.05, 0.03), 0.0, 0.0, 0.9, 3, 6)
	s.blob(Vector3(0.0, -0.18, cz - 0.11), Vector3(0.04, 0.02, 0.03), Basis.IDENTITY, BONE, 1.0, 0.04)
	# a rim of spikes along the top edge
	for k in 5:
		s.claw(Vector3(-0.22 + 0.11 * float(k), 0.27 + 0.02 * float(k % 2), cz), Vector3(0, 1, -0.15).normalized(), 0.1, 0.018, Vector3.ZERO, IRON)
	# the arm strap behind it
	s.tube(PackedVector3Array([Vector3(-0.2, -0.2, cz + 0.04), Vector3(-0.1, -0.14, -0.2), Vector3(0.05, -0.1, -0.14)]),
		PackedFloat32Array([0.016, 0.016, 0.016]), 4, Color(0.28, 0.18, 0.12), 0.0, 0.05, 0.0, Vector2(0.4, 1.0), 0.6)
	parts["shield:chest"] = s.commit()
	var h := _cm(5102)
	h.blob(Vector3(0, 0.05, 0.0), Vector3(0.135, 0.11, 0.14), Basis.IDENTITY, IRON, 1.0, 0.06, 0.0, 7, 12)
	_ring(h, Vector3(0, -0.01, 0.0), 0.138, 0.014, RUST)
	h.tube(PackedVector3Array([Vector3(-0.07, 0.03, -0.13), Vector3(0.07, 0.03, -0.13)]), PackedFloat32Array([0.008, 0.008]), 4, Color(0.05, 0.03, 0.02), 0.0, 0.0, 0.8)
	h.tube(PackedVector3Array([Vector3(0.0, 0.1, -0.13), Vector3(0.0, -0.05, -0.145)]), PackedFloat32Array([0.006, 0.006]), 4, Color(0.05, 0.03, 0.02), 0.0, 0.0, 0.6)
	for k in 5:
		var z := -0.09 + 0.045 * float(k)
		h.claw(Vector3(0, 0.15, z), Vector3(0, 1, 0.25 + 0.1 * float(k)).normalized(), 0.12 - 0.012 * float(absi(k - 2)), 0.02, Vector3(0, 0, 0.05), IRON)
	parts["head"] = h.commit()
	for side: String in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var a := _cm(5103 + (0 if side == "l" else 1))
		a.plate(Vector3(sx * 0.03, 0.05, 0.0), Vector3(0.13, 0.04, 0.13), Vector3(sx * 0.6, 1.0, 0.0), IRON, 1.0, 0.1)
		a.plate(Vector3(sx * 0.06, -0.04, 0.0), Vector3(0.11, 0.035, 0.11), Vector3(sx * 0.95, 0.6, 0.0), RUST, 1.0, 0.12)
		a.wrap(Vector3(0, -0.1, 0), Vector3(0, -0.3, 0), 0.07, 2.5, 0.016, Color(0.6, 0.52, 0.42))
		parts["shoulder_" + side] = a.commit()
	return parts


# --- Chanter ----------------------------------------------------------------------------------

static func _chanter() -> Dictionary:
	var parts := {}
	# robe: long dark panels to the ground, longer behind
	var r := _cm(5201)
	var n := 16
	for k in n:
		var ang := TAU * float(k) / float(n)
		var o := Vector3(cos(ang) * 0.16, -0.02, sin(ang) * 0.13)
		var back := clampf(sin(ang), 0.0, 1.0)
		var length := 0.86 + 0.14 * back + 0.06 * float((k * 5) % 3) / 2.0
		var out := Vector3(cos(ang), 0.0, sin(ang)) * (0.14 + 0.06 * back)
		r.tube(PackedVector3Array([o, o + Vector3(0, -length * 0.35, 0) + out * 0.35, o + Vector3(0, -length * 0.7, 0) + out * 0.75, o + Vector3(0, -length, 0) + out]),
			PackedFloat32Array([0.05, 0.06, 0.065, 0.025]), 5, CLOTH, 0.0, 0.25, 0.0, Vector2(1.0, 0.22), 1.0)
	_ring(r, Vector3(0, -0.04, 0), 0.17, 0.018, Color(0.6, 0.5, 0.4), 0.0)
	parts["pelvis"] = r.commit()
	# tall peaked hood, falling to the shoulders, with a veil of strands over the face
	var h := _cm(5202)
	var hp := PackedVector3Array([Vector3(0, -0.12, 0.04), Vector3(0, 0.0, 0.03), Vector3(0, 0.12, 0.05), Vector3(0, 0.26, 0.1), Vector3(0, 0.4, 0.2)])
	h.tube(hp, PackedFloat32Array([0.17, 0.16, 0.14, 0.08, 0.0]), 10, CLOTH, 0.0, 0.18, 0.0, Vector2.ONE, 1.0)
	for k in 7:
		var x := -0.06 + 0.02 * float(k)
		h.strand(Vector3(x, 0.08, -0.13), Vector3(0, -1, -0.15).normalized(), 0.16 + 0.03 * float(k % 3), 0.012, 0.01, Color(0.3, 0.28, 0.26), 1.0, 0.45, 4)
	parts["head"] = h.commit()
	# a cord of finger-bones and talismans across the chest
	var c := _cm(5203)
	for k in 9:
		var t := float(k) / 8.0
		var p := Vector3(lerpf(-0.13, 0.13, t), 0.12 - sin(t * PI) * 0.16, -0.14 - sin(t * PI) * 0.02)
		c.blob(p, Vector3(0.012, 0.022, 0.012), Basis(Vector3.FORWARD, t * 2.0 - 1.0), BONE, 1.0, 0.0, 0.0, 3, 6)
	parts["chest"] = c.commit()
	# the staff: a long bone shaft held at the middle, a cage of ribs at the top
	var s := _cm(5204)
	s.tube(PackedVector3Array([Vector3(0, -0.85, 0), Vector3(0.01, -0.2, 0.0), Vector3(-0.01, 0.4, 0.01), Vector3(0, 0.72, 0)]),
		PackedFloat32Array([0.018, 0.022, 0.02, 0.024]), 6, BONE, 1.0, 0.1)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var o := Vector3(cos(a), 0.0, sin(a))
		s.tube(PackedVector3Array([Vector3(0, 0.72, 0), Vector3(0, 0.76, 0) + o * 0.07, Vector3(0, 0.88, 0) + o * 0.08, Vector3(0, 0.98, 0) + o * 0.02]),
			PackedFloat32Array([0.008, 0.009, 0.008, 0.0]), 4, BONE, 1.0, 0.0)
	parts["hand_r"] = s.commit()
	var g := _cm(5205)
	g.blob(Vector3(0, 0.85, 0), Vector3(0.05, 0.06, 0.05), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 6, 8)
	parts["glow:hand_r"] = g.commit()
	return parts


# --- Burrower ---------------------------------------------------------------------------------

static func _burrower(rig: QuadRig) -> Dictionary:
	var parts := {}
	var L := rig.body_len if rig else 0.72
	var b := _cm(5301)
	for k in 5:
		var z := lerpf(L * 0.32, -L * 0.3, float(k) / 4.0)
		var w := 0.2 - 0.02 * absf(float(k) - 2.0)
		b.plate(Vector3(0, 0.15 + 0.03 * sin(float(k) * 0.9), z), Vector3(w, 0.05, 0.11), Vector3(0, 1.0, -0.25), Color(0.6, 0.5, 0.4), 1.0, 0.16)
	for k in 9:
		var z := lerpf(L * 0.35, -L * 0.3, float(k) / 8.0)
		var sx := -1.0 if k % 2 == 0 else 1.0
		b.blob(Vector3(sx * 0.12, 0.18, z), Vector3(0.05, 0.03, 0.045), Basis.IDENTITY, Color(0.35, 0.26, 0.18), 0.0, 0.25)     # clods of earth
	parts["body"] = b.commit()
	for side: String in ["fl", "fr"]:
		var sx := -1.0 if side == "fl" else 1.0
		var f := _cm(5302 + (0 if side == "fl" else 1))
		for k in 3:
			var off := Vector3(sx * 0.02 * float(k - 1), 0.0, -0.03 * float(k - 1))
			f.claw(Vector3(0, 0.04, 0) + off, Vector3(sx * 0.15, -0.55, -1.0).normalized(), 0.24, 0.05, Vector3(0, -0.25, 0), Color(0.75, 0.66, 0.5))
		f.plate(Vector3(0, 0.06, -0.04), Vector3(0.06, 0.03, 0.08), Vector3(0, 0.4, -1.0), Color(0.6, 0.5, 0.4), 1.0, 0.12)
		parts["leg_%s_foot" % side] = f.commit()
	var h := _cm(5304)
	for k in 4:
		h.plate(Vector3(0, 0.06 - 0.01 * float(k), -0.03 - 0.045 * float(k)), Vector3(0.07 - 0.01 * float(k), 0.025, 0.05), Vector3(0, 1.0, -0.6), Color(0.62, 0.52, 0.42), 1.0, 0.1)
	h.claw(Vector3(0, 0.0, -0.18), Vector3(0, -0.3, -1.0).normalized(), 0.12, 0.035, Vector3(0, -0.1, 0), Color(0.8, 0.72, 0.58))
	parts["head"] = h.commit()
	return parts


# --- Mite -------------------------------------------------------------------------------------

static func _mite(rig: QuadRig) -> Dictionary:
	var parts := {}
	var L := rig.body_len if rig else 0.72
	var g := _cm(5401)
	g.blob(Vector3(0, 0.16, L * 0.18), Vector3(0.12, 0.1, 0.16), Basis.IDENTITY, Color.WHITE, 0.0, 0.08, 1.0, 6, 10)
	parts["glow:body"] = g.commit()
	var b := _cm(5402)
	for k in 6:
		var z := lerpf(L * 0.05, -L * 0.35, float(k) / 5.0)
		b.claw(Vector3(0, 0.12, z), Vector3(0, 1.0, 0.5).normalized(), 0.09, 0.02, Vector3(0, -0.05, 0.08), Color(0.7, 0.62, 0.78))
	_ring(b, Vector3(0, 0.12, L * 0.18), 0.13, 0.014, Color(0.4, 0.32, 0.45), 1.0)
	parts["body"] = b.commit()
	return parts

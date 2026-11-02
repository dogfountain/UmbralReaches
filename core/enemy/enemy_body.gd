class_name EnemyBody
extends RefCounted
## Organic bodies for every enemy kind, built with CreatureMesh and cached per (kind, joint):
## an enemy instance only adds MeshInstance3Ds that point at shared ArrayMeshes and ONE shared
## flesh ShaderMaterial per kind (≈ one draw call per joint). Replaces the old ~60 primitive
## cylinders per enemy and the stone/bark triplanar maps that made skin read as rock.
##
## Silhouette rules, so each type reads at 15 m in greyscale:
##   Wretch  hunched, gaunt, long arms ending in hooked claws, open jaw
##   Husk    bloated belly, cage of exposed ribs, small sunken head, a glowing hollow in the chest
##   Spitter thin and pale, long forward neck, dorsal glands, throat sac (spitter.gd)
##   Crawler low and spidery on four legs, mandibles, four eyes, stub tail       (QuadRig)
##   Leaper  long body, heavy haunches, dorsal spines, long spiked tail, crest    (QuadRig)

const FLESH := preload("res://core/enemy/flesh.gdshader")
const SHADOWED := ["chest", "pelvis", "head", "body", "front"]

static var _meshes := {}    # kind -> {joint: ArrayMesh}
static var _mats := {}      # kind -> ShaderMaterial


## Attach the cached body for `kind` to the rig's sockets. Returns the MeshInstance3Ds so Enemy
## can drive the per-instance flash / glint / dissolve uniforms.
static func dress(rig: CharacterRig, kind: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if rig == null:
		push_error("EnemyBody.dress: rig null")
		return out
	if not _meshes.has(kind):
		_meshes[kind] = _quad_parts(kind, rig as QuadRig) if rig is QuadRig else _humanoid_parts(kind)
	var parts: Dictionary = _meshes[kind]
	var mat := material(kind)
	for joint in parts:
		var socket := rig.socket(joint)
		if socket == null:
			push_error("EnemyBody.dress: socket '%s' missing for %s" % [joint, kind])
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Flesh_" + String(joint)
		mi.mesh = parts[joint]
		mi.material_override = mat
		var big := String(joint) in SHADOWED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if big else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(mi)
		out.append(mi)
	return out


static func material(kind: StringName) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var m := ShaderMaterial.new()
	m.shader = FLESH
	var p: Dictionary = {
		&"wretch": {"skin": Color(0.6, 0.56, 0.6), "deep": Color(0.22, 0.13, 0.2), "eye": Color(1.0, 0.32, 0.1), "rim": 0.55},
		&"husk": {"skin": Color(0.42, 0.37, 0.41), "deep": Color(0.14, 0.09, 0.11), "eye": Color(1.0, 0.45, 0.12), "rim": 0.45},
		&"spitter": {"skin": Color(0.7, 0.74, 0.66), "deep": Color(0.24, 0.3, 0.25), "eye": Color(0.3, 1.4, 1.0), "rim": 0.5, "vein": Color(0.08, 0.2, 0.12)},
		&"crawler": {"skin": Color(0.5, 0.45, 0.52), "deep": Color(0.15, 0.09, 0.14), "eye": Color(1.3, 0.18, 0.12), "rim": 0.6},
		&"leaper": {"skin": Color(0.48, 0.3, 0.34), "deep": Color(0.17, 0.05, 0.08), "eye": Color(1.4, 0.62, 0.1), "rim": 0.7},
		&"ossuant": {"skin": Color(0.82, 0.76, 0.64), "deep": Color(0.3, 0.24, 0.2), "eye": Color(1.1, 0.5, 2.6), "rim": 0.35},
	}.get(kind, {"skin": Color(0.6, 0.56, 0.6), "deep": Color(0.2, 0.12, 0.18), "eye": Color(1.0, 0.3, 0.1), "rim": 0.5})
	m.set_shader_parameter("skin", p.skin)
	m.set_shader_parameter("skin_deep", p.deep)
	m.set_shader_parameter("eye_col", p.eye)
	m.set_shader_parameter("rim_amount", p.rim)
	if p.has("vein"):
		m.set_shader_parameter("vein", p.vein)
	_mats[kind] = m
	return m


# --- humanoid kinds -------------------------------------------------------------------------
# Joint frames (CharacterRig): limbs hang along -Y from their joint, the body faces -Z.
# pelvis → hip_l/r (±0.11, -0.19) → knee (-0.42) → foot (-0.42); chest is 0.34 above pelvis,
# head 0.36 above chest, shoulders (±0.24, +0.12) → elbow (-0.32) → hand (-0.30).

static func _humanoid_parts(kind: StringName) -> Dictionary:
	var husk := kind == &"husk" or kind == &"ossuant"
	var spit := kind == &"spitter"
	var limb_r := 1.45 if husk else (0.8 if spit else 1.0)
	var claw := 0.08 if husk else (0.07 if spit else 0.13)
	var parts := {}
	var sd := hash(kind) % 1000

	# pelvis: hips + hanging rags
	var cm := CreatureMesh.new(sd)
	cm.blob(Vector3(0, -0.05, 0.0), Vector3(0.15, 0.1, 0.11) * (1.25 if husk else 1.0), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
	# a belt of torn strips hanging round the hips (thin, ragged, splayed — not a skirt)
	cm.tube(PackedVector3Array([Vector3(-0.15, -0.04, 0.0), Vector3(0.0, -0.06, -0.12), Vector3(0.15, -0.04, 0.0), Vector3(0.0, -0.02, 0.12), Vector3(-0.15, -0.04, 0.0)]),
		PackedFloat32Array([0.02, 0.02, 0.02, 0.02, 0.02]), 5, Color(0.8, 0.7, 0.65), 0.0, 0.2, 0.0, Vector2.ONE, 1.0)
	for k in 9:
		var ang := TAU * float(k) / 9.0 + 0.3
		var o := Vector3(cos(ang) * 0.14, -0.05, sin(ang) * 0.12)
		var rag_len := 0.16 + 0.14 * float((k * 7) % 4) / 3.0
		var splay := Vector3(cos(ang), 0.0, sin(ang)) * 0.05
		cm.tube(PackedVector3Array([o, o + Vector3(0, -rag_len * 0.5, 0) + splay * 0.5, o + Vector3(0, -rag_len, 0) + splay]),
			PackedFloat32Array([0.03, 0.026, 0.008]), 5, Color(0.9, 0.82, 0.8), 0.0, 0.3, 0.0, Vector2(1.0, 0.25), 1.0)
	parts["pelvis"] = cm.commit()

	# chest: torso, spine, ribs, neck
	cm = CreatureMesh.new(sd + 1)
	var spine := PackedVector3Array([Vector3(0, -0.32, 0.09), Vector3(0, -0.12, 0.12), Vector3(0, 0.08, 0.14), Vector3(0, 0.24, 0.08)])
	if husk:
		cm.blob(Vector3(0, -0.17, -0.05), Vector3(0.25, 0.22, 0.23), Basis.IDENTITY, Color(1.0, 0.92, 0.92), 0.0, 0.16)
		cm.blob(Vector3(0, 0.07, 0.0), Vector3(0.22, 0.15, 0.15), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		for k in 4:
			for side in [-1.0, 1.0]:
				cm.rib(Vector3(0, 0.12 - 0.07 * float(k), 0.15), side, 0.17, 0.05, 0.017, 0.82)
		cm.blob(Vector3(0, -0.02, -0.2), Vector3(0.06, 0.07, 0.03), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 6, 8)
	elif spit:
		cm.blob(Vector3(0, 0.0, 0.01), Vector3(0.13, 0.18, 0.1), Basis.IDENTITY, Color.WHITE, 0.0, 0.1)
		cm.tube(PackedVector3Array([Vector3(0, -0.32, 0.02), Vector3(0, -0.16, 0.0), Vector3(0, -0.04, 0.0)]), PackedFloat32Array([0.09, 0.08, 0.11]), 9)
		for k in 3:
			cm.blob(Vector3((float(k) - 1.0) * 0.06, 0.06 - 0.09 * float(k % 2), 0.13), Vector3(0.035, 0.04, 0.03), Basis.IDENTITY, Color.WHITE, 0.0, 0.05, 1.0, 5, 8)
	else:
		cm.blob(Vector3(0, 0.0, 0.0), Vector3(0.16, 0.2, 0.12), Basis(Vector3.RIGHT, -0.25), Color.WHITE, 0.0, 0.14)
		cm.tube(PackedVector3Array([Vector3(0, -0.32, 0.03), Vector3(0, -0.18, 0.01), Vector3(0, -0.06, 0.01)]), PackedFloat32Array([0.11, 0.09, 0.13]), 9, Color.WHITE, 0.0, 0.1, 0.0, Vector2(1.0, 0.8))
		for k in 3:
			for side in [-1.0, 1.0]:
				cm.rib(Vector3(0, -0.02 - 0.07 * float(k), 0.12), side, 0.14, 0.04, 0.012, 0.7)
		for side in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.19, 0.12, 0.05), Vector3(0.09, 0.07, 0.08), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
	cm.vertebrae(spine, 0.032 * (1.3 if husk else 1.0), 7, Vector3.BACK)
	if spit:
		cm.tube(PackedVector3Array([Vector3(0, 0.16, 0.03), Vector3(0, 0.28, -0.04), Vector3(0, 0.36, -0.1), Vector3(0, 0.4, -0.14)]), PackedFloat32Array([0.07, 0.055, 0.05, 0.05]), 9)
	elif not husk:
		cm.tube(PackedVector3Array([Vector3(0, 0.16, 0.05), Vector3(0, 0.27, 0.0), Vector3(0, 0.36, -0.05)]), PackedFloat32Array([0.065, 0.05, 0.048]), 9)
	parts["chest"] = cm.commit()

	# head
	cm = CreatureMesh.new(sd + 2)
	var ho := Vector3(0, 0.02, -0.14) if spit else (Vector3(0, -0.06, -0.06) if husk else Vector3.ZERO)
	var hs := 0.82 if husk else 1.0
	cm.blob(ho + Vector3(0, 0.06, -0.02) * hs, Vector3(0.095, 0.1, 0.135) * hs, Basis(Vector3.RIGHT, 0.2), Color.WHITE, 0.0, 0.12)
	cm.tube(PackedVector3Array([ho + Vector3(-0.07, 0.1, -0.1) * hs, ho + Vector3(0, 0.085, -0.145) * hs, ho + Vector3(0.07, 0.1, -0.1) * hs]),
		PackedFloat32Array([0.018, 0.024, 0.018]), 6, Color(0.85, 0.8, 0.8))
	# open jaw, slung low; teeth on both rows
	var jaw := PackedVector3Array([ho + Vector3(-0.065, 0.0, -0.01) * hs, ho + Vector3(-0.045, -0.06, -0.09) * hs, ho + Vector3(0, -0.075, -0.135) * hs,
		ho + Vector3(0.045, -0.06, -0.09) * hs, ho + Vector3(0.065, 0.0, -0.01) * hs])
	cm.tube(jaw, PackedFloat32Array([0.024, 0.03, 0.032, 0.03, 0.024]), 7, Color(1.0, 0.85, 0.85))
	for k in 5:
		var tx := (float(k) - 2.0) * 0.022
		cm.claw(ho + Vector3(tx, -0.058, -0.12 + absf(tx) * 0.6) * hs, Vector3(0, 1, -0.2).normalized(), 0.035, 0.007)
		cm.claw(ho + Vector3(tx, 0.025, -0.125 + absf(tx) * 0.6) * hs, Vector3(0, -1, -0.15).normalized(), 0.03, 0.006)
	for side in [-1.0, 1.0]:
		cm.blob(ho + Vector3(side * 0.04, 0.065, -0.128) * hs, Vector3(0.02, 0.012, 0.012), Basis(Vector3.FORWARD, side * 0.3), Color.WHITE, 0.0, 0.0, 1.0, 5, 8)
	if kind == &"wretch":
		for k in 3:
			cm.claw(Vector3((float(k) - 1.0) * 0.05, 0.14, 0.02), Vector3((float(k) - 1.0) * 0.4, 0.6, 1.0).normalized(), 0.09, 0.018, Vector3(0, -0.3, 0))
	parts["head"] = cm.commit()

	# arms
	for tag: String in ["l", "r"]:
		var sx := -1.0 if tag == "l" else 1.0
		cm = CreatureMesh.new(sd + 10)
		cm.blob(Vector3(sx * 0.01, 0.0, 0.0), Vector3(0.07, 0.065, 0.07) * limb_r, Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		cm.limb(Vector3.ZERO, Vector3(0, -0.31, -0.01), 0.052 * limb_r, 0.038 * limb_r, Color.WHITE, Vector3(sx * 0.008, 0, -0.012))
		parts["shoulder_" + tag] = cm.commit()
		cm = CreatureMesh.new(sd + 11)
		cm.limb(Vector3.ZERO, Vector3(0, -0.29, -0.01), 0.04 * limb_r, 0.027 * limb_r, Color.WHITE, Vector3(0, 0, 0.01))
		cm.blob(Vector3(0, 0.0, 0.03), Vector3(0.028, 0.03, 0.022) * limb_r, Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 4, 6)
		parts["elbow_" + tag] = cm.commit()
		cm = CreatureMesh.new(sd + 12)
		cm.blob(Vector3(0, -0.03, 0), Vector3(0.034, 0.045, 0.024) * limb_r, Basis.IDENTITY, Color.WHITE, 0.0, 0.1)
		for f in 3:
			var fx := (float(f) - 1.0) * 0.022
			var tip := Vector3(fx * 1.4, -0.15 - claw * 0.3, -0.03)
			cm.limb(Vector3(fx, -0.06, -0.005), tip, 0.012 * limb_r, 0.008 * limb_r, Color.WHITE, Vector3(0, 0, -0.012), 0.05)
			cm.claw(tip, Vector3(0, -0.6, -1.0).normalized(), claw, 0.009, Vector3(0, -0.6, 0.4))
		parts["hand_" + tag] = cm.commit()

	# legs
	for tag: String in ["l", "r"]:
		cm = CreatureMesh.new(sd + 20)
		cm.limb(Vector3(0, 0.02, 0), Vector3(0, -0.41, 0.0), 0.072 * limb_r, 0.05 * limb_r, Color.WHITE, Vector3(0, 0, -0.025))
		parts["hip_" + tag] = cm.commit()
		cm = CreatureMesh.new(sd + 21)
		cm.limb(Vector3.ZERO, Vector3(0, -0.4, 0.02), 0.05 * limb_r, 0.034 * limb_r, Color.WHITE, Vector3(0, 0, 0.015))
		cm.blob(Vector3(0, 0.0, -0.04), Vector3(0.035, 0.035, 0.025) * limb_r, Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 4, 6)
		parts["knee_" + tag] = cm.commit()
		cm = CreatureMesh.new(sd + 22)
		cm.tube(PackedVector3Array([Vector3(0, 0.0, 0.03), Vector3(0, -0.03, -0.05), Vector3(0, -0.045, -0.12)]),
			_k([0.045, 0.04, 0.032], limb_r), 8)
		for t in 3:
			var tx := (float(t) - 1.0) * 0.025
			cm.claw(Vector3(tx, -0.05, -0.13), Vector3(tx * 3.0, -0.35, -1.0).normalized(), 0.055, 0.011, Vector3(0, -0.5, 0))
		parts["foot_" + tag] = cm.commit()
	return parts


# --- quadruped kinds (QuadRig) ----------------------------------------------------------------

static func _quad_parts(kind: StringName, rig: QuadRig) -> Dictionary:
	var leaper := kind == &"leaper"
	var parts := {}
	var sd := hash(kind) % 1000
	var L := rig.body_len
	var h := rig.body_height

	# body: ribcage + haunch + belly, spine ridge, dorsal spines (leaper)
	var cm := CreatureMesh.new(sd)
	var bulk := 1.25 if leaper else 0.9
	cm.blob(Vector3(0, 0.03, -L * 0.22), Vector3(0.15, 0.14, 0.22) * bulk, Basis.IDENTITY, Color.WHITE, 0.0, 0.14)
	cm.blob(Vector3(0, 0.02, L * 0.24), Vector3(0.16, 0.13, 0.2) * bulk * (1.15 if leaper else 1.0), Basis.IDENTITY, Color.WHITE, 0.0, 0.14)
	cm.tube(PackedVector3Array([Vector3(0, -0.02, L * 0.35), Vector3(0, -0.04, 0.0), Vector3(0, -0.01, -L * 0.35)]),
		_k([0.11, 0.1, 0.12], bulk), 10, Color(0.92, 0.88, 0.9), 0.0, 0.16)
	var spine := PackedVector3Array([Vector3(0, 0.12 * bulk, L * 0.42), Vector3(0, 0.16 * bulk, 0.0), Vector3(0, 0.15 * bulk, -L * 0.4)])
	cm.vertebrae(spine, 0.03 * bulk, 9, Vector3.UP)
	if leaper:
		for k in 6:
			var z := lerpf(L * 0.32, -L * 0.3, float(k) / 5.0)
			cm.claw(Vector3(0, 0.17 * bulk, z), Vector3(0, 1.0, 0.7).normalized(), 0.11 + 0.05 * sin(float(k) * 1.3), 0.02, Vector3(0, -0.2, 0.3))
	else:
		for side in [-1.0, 1.0]:
			for k in 3:
				var z := lerpf(L * 0.2, -L * 0.25, float(k) / 2.0)
				cm.blob(Vector3(side * 0.12, 0.08, z), Vector3(0.03, 0.025, 0.03), Basis.IDENTITY, Color.WHITE, 0.0, 0.05, 1.0, 4, 6)
	parts["body"] = cm.commit()

	# front: neck
	cm = CreatureMesh.new(sd + 1)
	cm.tube(PackedVector3Array([Vector3(0, -0.02, 0.08), Vector3(0, 0.0, -0.04), Vector3(0, 0.02, -0.15)]),
		_k([0.11, 0.09, 0.075], bulk), 9, Color.WHITE, 0.0, 0.14)
	parts["front"] = cm.commit()

	# head
	cm = CreatureMesh.new(sd + 2)
	var hs := 1.2 if leaper else 0.9
	cm.blob(Vector3(0, 0.01, -0.07) * hs, Vector3(0.075, 0.065, 0.13) * hs, Basis(Vector3.RIGHT, 0.12), Color.WHITE, 0.0, 0.12)
	var jaw := PackedVector3Array([Vector3(-0.05, -0.03, -0.01) * hs, Vector3(-0.035, -0.07, -0.1) * hs, Vector3(0, -0.08, -0.16) * hs,
		Vector3(0.035, -0.07, -0.1) * hs, Vector3(0.05, -0.03, -0.01) * hs])
	cm.tube(jaw, _k([0.02, 0.025, 0.026, 0.025, 0.02], hs), 7, Color(1.0, 0.85, 0.85))
	for k in 5:
		var tx := (float(k) - 2.0) * 0.018 * hs
		cm.claw(Vector3(tx, -0.06 * hs, (-0.15 + absf(tx) * 0.9) * hs), Vector3(0, 1, -0.3).normalized(), 0.03 * hs, 0.006)
	if leaper:
		for side in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.035, 0.035, -0.15) * hs, Vector3(0.02, 0.013, 0.014), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 5, 8)
			for k in 3:
				cm.claw(Vector3(side * (0.03 + 0.015 * float(k)), 0.06, 0.0 + 0.03 * float(k)) * hs,
					Vector3(side * 0.4, 0.5, 1.0).normalized(), 0.09 - 0.015 * float(k), 0.014, Vector3(0, -0.2, 0))
	else:
		for k in 4:
			var ex := (0.022 + 0.022 * float(k % 2)) * (-1.0 if k < 2 else 1.0)
			cm.blob(Vector3(ex, 0.03 + 0.012 * float(k % 2), -0.14 + 0.02 * float(k % 2)) * hs, Vector3(0.012, 0.01, 0.01), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 4, 6)
		for side in [-1.0, 1.0]:
			cm.claw(Vector3(side * 0.04, -0.05, -0.15) * hs, Vector3(side * -0.25, -0.15, -1.0).normalized(), 0.08, 0.014, Vector3(side * -0.5, 0, 0))
	parts["head"] = cm.commit()

	# tail
	cm = CreatureMesh.new(sd + 3)
	var tl := 0.85 if leaper else 0.28
	var tpts := PackedVector3Array()
	var trad := PackedFloat32Array()
	for k in 7:
		var t := float(k) / 6.0
		tpts.append(Vector3(0, -0.02 - 0.08 * t * t, tl * t))
		trad.append(0.07 * bulk * (1.0 - t))
	cm.tube(tpts, trad, 8, Color.WHITE, 0.0, 0.12)
	if leaper:
		for k in 4:
			var t := 0.25 + 0.18 * float(k)
			cm.claw(Vector3(0, 0.04 - 0.08 * t * t, tl * t), Vector3(0, 1.0, 0.5).normalized(), 0.07, 0.014)
	parts["tail"] = cm.commit()

	# legs: upper (hip → knee goes out and up), lower (knee → foot), toe claws
	for tag: String in ["fl", "fr", "bl", "br"]:
		var sx := -1.0 if tag.ends_with("l") else 1.0
		var hind: bool = tag.begins_with("b")
		var thick := (1.5 if hind and leaper else 1.0) * bulk
		cm = CreatureMesh.new(sd + 10)
		var knee := Vector3(sx * rig.upper_len, 0.1, 0.0)
		cm.blob(Vector3.ZERO, Vector3(0.06, 0.055, 0.06) * thick, Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		cm.limb(Vector3.ZERO, knee, 0.05 * thick, 0.034 * thick, Color.WHITE, Vector3(0, 0.03, 0))
		parts["leg_%s_hip" % tag] = cm.commit()
		cm = CreatureMesh.new(sd + 11)
		var foot := Vector3(sx * 0.07, -(h + 0.08), 0.0)
		cm.blob(Vector3.ZERO, Vector3(0.035, 0.035, 0.035) * thick, Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 4, 6)
		cm.limb(Vector3.ZERO, foot, 0.033 * thick, 0.016, Color.WHITE, Vector3(sx * 0.03, 0, 0), 0.08)
		parts["leg_%s_knee" % tag] = cm.commit()
		cm = CreatureMesh.new(sd + 12)
		for t in 3:
			var ang := (float(t) - 1.0) * 0.5
			cm.claw(Vector3.ZERO, Vector3(sin(ang) * 0.7 + sx * 0.2, -0.25, -cos(ang)).normalized(), 0.07, 0.012, Vector3(0, -0.6, 0))
		parts["leg_%s_foot" % tag] = cm.commit()
	return parts


static func _k(values: Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in values:
		out.append(float(v) * k)
	return out

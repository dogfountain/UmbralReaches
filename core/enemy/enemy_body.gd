class_name EnemyBody
extends RefCounted
## Organic bodies for every enemy kind and boss, built with CreatureMesh and cached per
## (kind, joint): an enemy instance only adds MeshInstance3Ds that point at shared ArrayMeshes and
## ONE shared flesh ShaderMaterial per kind (about one draw call per joint). Meshes go through
## GenCache (salted by this file and CreatureMesh), so a kind is built once per install, not per run.
##
## Anatomy pass (r22): sinew cords on necks and limbs, collarbones, shoulder blades, kneecaps and
## shin ridges, knuckles and thumbs, sunken eye sockets with glowing eyes, per-kind hair / rags /
## bandages / chitin / bark, skin detail maps (SkinTex) over metric UVs.
##
## Silhouette rules, so each type reads at 15 m in greyscale:
##   Wretch   hunched, gaunt, lank hair, rag shawl, long arms ending in hooked claws, open jaw
##   Husk     bloated belly with a stitched seam, bandaged limbs, small sunken head, chest hollow
##   Spitter  thin and pale, long forward neck, a ridge of glowing glands, throat sac (spitter.gd)
##   Crawler  low and spidery on four legs, chitin plates, mandibles, four eyes, leg spines
##   Leaper   long body, heavy haunches, ribbed flanks, dorsal spines, long spiked tail, crest
##   Ossuant  husk frame under bone armour: skull mask, pauldrons, outer ribs, fauld of long bones
## Bosses (their own material and parts named Boss_*):
##   Thornwarden      leaper frame in bark plates, a crown of branching thorn antlers, vines, an
##                    ember crack through the chest
##   Bone Abbot       ossuant frame under a bone mitre, a cassock of long rags to the ground, a
##                    glowing reliquary lantern at the breast, a hooked bone crozier
##   Ascended Warden  a gaunt priest in a floor-length robe and veil, a blank bone mask with slit
##                    eyes, a cracked halo of violet light behind the head

const FLESH := preload("res://core/enemy/flesh.gdshader")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SkinTex := preload("res://core/enemy/skin_tex.gd")
const GruntModel := preload("res://core/enemy/grunt_model.gd")
const SELF_PATH := "res://core/enemy/enemy_body.gd"
const CM_PATH := "res://core/enemy/creature_mesh.gd"
const SHADOWED := ["chest", "pelvis", "head", "body", "front"]
const BOSSES := [&"thornwarden", &"bone_abbot", &"ascended_warden",
	&"hierarch"]       # --- west marches ---

static var _meshes := {}    # kind -> {joint: ArrayMesh}
static var _mats := {}      # kind -> ShaderMaterial
static var _glow_mats := {}

const RAG := Color(0.85, 0.8, 0.78)
const SINEW := Color(0.78, 0.6, 0.62)
const DARK := Color(0.45, 0.32, 0.36)


## Attach the cached body for `kind` to the rig's sockets. Returns the MeshInstance3Ds so Enemy
## can drive the per-instance flash / glint / dissolve uniforms.
static func dress(rig: CharacterRig, kind: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if rig == null:
		push_error("EnemyBody.dress: rig null")
		return out
	if MODELS.has(kind) and ResourceLoader.exists(MODELS[kind]):
		out = _dress_model(rig, kind)
		if not out.is_empty():
			return out
	# r30: the rank-and-file kinds are modelled too (tools/blender/grunt_*.py), when built
	if GruntModel.has(kind):
		out = GruntModel.dress(rig, kind)
		if not out.is_empty():
			return out
	var parts := _parts(kind, rig)
	var mat := material(kind)
	for joint: String in parts:
		# "socket" = flesh; "boss:socket" = a boss's own part; "armour:socket" = bone plates;
		# "glow:socket" = an unshaded light part (no hit flash)
		var bits := joint.split(":")
		var socket_name := bits[bits.size() - 1]
		var tag := bits[0] if bits.size() > 1 else ""
		var socket := rig.socket(socket_name)
		if socket == null:
			push_error("EnemyBody.dress: socket '%s' missing for %s" % [socket_name, kind])
			continue
		var mi := MeshInstance3D.new()
		var glow := tag == "glow"
		mi.name = {"boss": "Boss_", "glow": "Boss_glow_", "armour": "Bone_"}.get(tag, "Flesh_") + socket_name
		mi.mesh = parts[joint]
		mi.material_override = _glow_mat(kind) if glow else mat
		var big := socket_name in SHADOWED and not glow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if big else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(mi)
		if not glow:
			out.append(mi)
	return out


# --- modelled bosses (r30) ------------------------------------------------------------------------
# Built in Blender (tools/blender/boss_*.py) in the rig's rest pose, baked into one atlas and split
# into one mesh per socket, origin on the joint. Used in place of the procedural body when present.
const MODELS := {
	&"bone_abbot": "res://art/models/boss_bone_abbot.glb",
	&"ascended_warden": "res://art/models/boss_ascended_warden.glb",
	&"thornwarden": "res://art/models/boss_thornwarden.glb",
	# --- west marches ---
	&"hierarch": "res://art/models/boss_hierarch.glb",
}
const BOSS_PBR := preload("res://core/enemy/boss_pbr.gdshader")
static var _model_meshes := {}   # kind -> {mesh name: Mesh}
static var _model_mats := {}


static func _dress_model(rig: CharacterRig, kind: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var meshes: Dictionary = _model_meshes.get(kind, {})
	if meshes.is_empty():
		var ps := load(MODELS[kind]) as PackedScene
		if ps == null:
			return out
		var inst := ps.instantiate()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi0 := n as MeshInstance3D
			if mi0.mesh:
				meshes[String(mi0.name)] = mi0.mesh
		inst.free()
		_model_meshes[kind] = meshes
	var mat := _model_mat(kind)
	if mat == null:
		return out
	for nm: String in meshes:
		# "chest" goes on the chest; "boss_hand_r" is a held thing on the hand (named Boss_ so the
		# boss script can find it: the Abbot keeps his crozier upright by it)
		var held := nm.begins_with("boss_")
		var socket_name := nm.substr(5) if held else nm
		var socket := rig.socket(socket_name)
		if socket == null:
			push_error("EnemyBody: model %s part '%s' has no socket" % [kind, nm])
			continue
		var mi := MeshInstance3D.new()
		mi.name = ("Boss_" if held else "Flesh_") + socket_name
		mi.mesh = meshes[nm]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if socket_name in ["pelvis", "chest", "head", "body", "front"] or held else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		socket.add_child(mi)
		out.append(mi)
	return out


## Ask the loader's worker threads for a modelled boss's mesh and textures, so the rig's first build finds
## them already read and decoded instead of stalling a frame on the disk.
static func prefetch(kind: StringName) -> void:
	if not MODELS.has(kind) or _model_mats.has(kind):
		return
	var base := String(MODELS[kind]).get_file().get_basename()
	for path: String in [MODELS[kind], "res://art/textures/%s_albedo.png" % base, "res://art/textures/%s_normal.png" % base,
			"res://art/textures/%s_orm.png" % base, "res://art/textures/%s_emit.png" % base]:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


static func _model_mat(kind: StringName) -> ShaderMaterial:
	if _model_mats.has(kind):
		return _model_mats[kind]
	var base := String(MODELS[kind]).get_file().get_basename()
	var albedo := "res://art/textures/%s_albedo.png" % base
	if not ResourceLoader.exists(albedo):
		return null
	var m := ShaderMaterial.new()
	m.shader = BOSS_PBR
	m.set_shader_parameter("albedo_tex", load(albedo))
	m.set_shader_parameter("normal_tex", load("res://art/textures/%s_normal.png" % base))
	m.set_shader_parameter("orm_tex", load("res://art/textures/%s_orm.png" % base))
	m.set_shader_parameter("emit_tex", load("res://art/textures/%s_emit.png" % base))
	m.set_shader_parameter("normal_depth", 1.25)
	m.set_shader_parameter("rim_amount", 0.2)
	# family finish: Ossuary dust, hollowed wet sheen, bark/heat on the living thorn
	match kind:
		&"bone_abbot":
			m.set_shader_parameter("dust", 0.72)
			m.set_shader_parameter("dust_col", Color(0.48, 0.44, 0.38))
		&"ascended_warden":
			m.set_shader_parameter("wet", 0.55)
		&"thornwarden":
			m.set_shader_parameter("heat", 0.55)
			m.set_shader_parameter("dust", 0.28)
			m.set_shader_parameter("dust_col", Color(0.32, 0.26, 0.18))
		&"hierarch":
			m.set_shader_parameter("wet", 0.7)
			m.set_shader_parameter("heat", 0.35)
	_model_mats[kind] = m
	return m


## Cached parts for a kind: memory, then GenCache on disk, then built.
static func _parts(kind: StringName, rig: CharacterRig) -> Dictionary:
	if _meshes.has(kind):
		return _meshes[kind]
	var quad := rig is QuadRig
	var shape := "h"
	if quad:
		var q := rig as QuadRig
		shape = "q%.2f_%.2f_%.2f" % [q.body_len, q.body_height, q.upper_len]
	var key := "enemy_body_%s_%s_%d" % [kind, shape, GenCache.salt(CM_PATH)]
	var joints: Variant = GenCache.load_var(key + "_joints", SELF_PATH)
	if joints is PackedStringArray:
		var cached := {}
		for j: String in joints:
			var m := GenCache.load_mesh(key + "_" + j, SELF_PATH)
			if m == null:
				cached.clear()
				break
			cached[j] = m
		if not cached.is_empty():
			_meshes[kind] = cached
			return cached
	var parts: Dictionary = _quad_parts(kind, rig as QuadRig) if quad else _humanoid_parts(kind)
	var names := PackedStringArray()
	for j: String in parts:
		names.append(j)
		GenCache.save_mesh(key + "_" + j, SELF_PATH, parts[j])
	GenCache.save_var(key + "_joints", SELF_PATH, names)
	_meshes[kind] = parts
	return parts


static func material(kind: StringName) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var m := ShaderMaterial.new()
	m.shader = FLESH
	var p: Dictionary = {
		# r30 value / colour keys per family, in hues the grade keeps (ember, gold, green-teal): every kind
		# was the same mid mauve-grey and read alike at 15 m
		&"wretch": {"skin": Color(0.36, 0.33, 0.36), "deep": Color(0.1, 0.07, 0.09), "eye": Color(1.6, 0.42, 0.1), "rim": 0.3, "tex": &"wretch", "matte": 0.2},
		&"husk": {"skin": Color(0.56, 0.56, 0.4), "deep": Color(0.18, 0.17, 0.08), "eye": Color(1.0, 0.45, 0.12), "rim": 0.25, "tex": &"husk", "linen": Color(0.42, 0.37, 0.3), "matte": 0.3, "depth": 0.5},
		&"spitter": {"skin": Color(0.72, 0.76, 0.68), "deep": Color(0.24, 0.3, 0.25), "eye": Color(0.3, 1.4, 1.0), "rim": 0.55, "vein": Color(0.08, 0.2, 0.12), "tex": &"spitter"},
		&"crawler": {"skin": Color(0.3, 0.27, 0.3), "deep": Color(0.08, 0.05, 0.07), "eye": Color(1.3, 0.18, 0.12), "rim": 0.3, "tex": &"crawler", "bone": Color(0.26, 0.22, 0.24), "matte": 0.35, "depth": 0.45},
		&"leaper": {"skin": Color(0.24, 0.17, 0.17), "deep": Color(0.07, 0.03, 0.03), "eye": Color(2.0, 0.7, 0.12), "rim": 0.3, "tex": &"leaper", "matte": 0.25, "depth": 0.5},
		&"ossuant": {"skin": Color(0.36, 0.3, 0.27), "deep": Color(0.12, 0.08, 0.07), "eye": Color(2.2, 1.3, 0.35), "rim": 0.25, "tex": &"ossuant", "bone": Color(0.9, 0.86, 0.76), "matte": 0.15},
		# bosses: their own accent in a protected band (the grade pulled every boss violet to the world's blue)
		&"thornwarden": {"skin": Color(0.3, 0.22, 0.17), "deep": Color(0.06, 0.03, 0.02), "eye": Color(2.6, 0.7, 0.12), "rim": 0.2, "tex": &"thorn", "bone": Color(0.4, 0.3, 0.2), "vein": Color(0.7, 0.12, 0.05), "crease": 0.8, "matte": 0.5, "depth": 0.45},
		&"bone_abbot": {"skin": Color(0.34, 0.28, 0.26), "deep": Color(0.12, 0.08, 0.07), "eye": Color(2.6, 1.5, 0.4), "rim": 0.2, "tex": &"ossuant", "bone": Color(0.92, 0.88, 0.78), "linen": Color(0.085, 0.07, 0.075), "matte": 0.15},
		&"ascended_warden": {"skin": Color(0.6, 0.6, 0.62), "deep": Color(0.16, 0.14, 0.16), "eye": Color(2.8, 2.3, 1.4), "rim": 0.25, "tex": &"spitter", "bone": Color(0.95, 0.88, 0.7), "linen": Color(0.66, 0.63, 0.58), "rag": Color(0.6, 0.58, 0.54), "matte": 0.1},
	}.get(kind, {"skin": Color(0.6, 0.56, 0.6), "deep": Color(0.2, 0.12, 0.18), "eye": Color(1.0, 0.3, 0.1), "rim": 0.5, "tex": &"wretch"})
	m.set_shader_parameter("skin", p.skin)
	m.set_shader_parameter("skin_deep", p.deep)
	m.set_shader_parameter("eye_col", p.eye)
	m.set_shader_parameter("rim_amount", p.rim)
	if p.has("vein"):
		m.set_shader_parameter("vein", p.vein)
	if p.has("bone"):
		m.set_shader_parameter("bone_col", p.bone)
	if p.has("linen"):
		m.set_shader_parameter("linen_col", p.linen)
	if p.has("rag"):
		m.set_shader_parameter("rag_col", p.rag)
	if p.has("crease"):
		m.set_shader_parameter("crease", p.crease)
	m.set_shader_parameter("matte", float(p.get("matte", 0.15)))
	if p.has("depth"):
		m.set_shader_parameter("detail_depth", float(p.depth))
	var maps: Array = SkinTex.maps(p.tex)
	m.set_shader_parameter("detail_normal", maps[0])
	m.set_shader_parameter("detail_height", maps[1])
	m.set_shader_parameter("detail_tile", CreatureMesh.TILE)
	_mats[kind] = m
	return m


## Unshaded glow for boss light parts (the Warden's halo, the Abbot's lantern, thorn embers).
static func _glow_mat(kind: StringName) -> Material:
	if not _glow_mats.has(kind):
		# white-gold, candle-gold, ember: hues the grade keeps (violet went to the world's blue)
		var c: Color = {&"ascended_warden": Color(3.0, 2.5, 1.5), &"bone_abbot": Color(3.0, 1.75, 0.5), &"thornwarden": Color(2.6, 0.6, 0.15)}.get(kind, Color(2.6, 1.6, 0.6))
		if kind == &"bone_abbot":    # the reliquary lantern glows from inside (falloff, flicker)
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://core/enemy/weak_glow.gdshader")
			sm.set_shader_parameter("glow_col", c)
			sm.set_shader_parameter("flicker_rate", 3.5)
			_glow_mats[kind] = sm
		else:
			_glow_mats[kind] = ProcMesh.glow_mat(c)
	return _glow_mats[kind]


static func _cm(seed_v: int) -> CreatureMesh:
	var cm := CreatureMesh.new(seed_v)
	cm.metric_uv = true
	return cm


# --- humanoid kinds -------------------------------------------------------------------------
# Joint frames (CharacterRig): limbs hang along -Y from their joint, the body faces -Z.
# pelvis → hip_l/r (±0.11, -0.19) → knee (-0.42) → foot (-0.42); chest is 0.34 above pelvis,
# head 0.36 above chest, shoulders (±0.24, +0.12) → elbow (-0.32) → hand (-0.30).

static func _humanoid_parts(kind: StringName) -> Dictionary:
	var abbot := kind == &"bone_abbot"
	var warden := kind == &"ascended_warden"
	var husk := kind == &"husk" or kind == &"ossuant" or abbot
	var spit := kind == &"spitter"
	var wretch := kind == &"wretch"
	var limb_r := 1.45 if husk else (0.8 if spit or warden else 1.0)
	var claw := 0.08 if husk else (0.07 if spit else (0.15 if warden else 0.13))
	var parts := {}
	var sd := hash(kind) % 1000

	# --- pelvis: hips, iliac crests, rags (robes for the bosses) ---
	var cm := _cm(sd)
	cm.blob(Vector3(0, -0.05, 0.0), Vector3(0.15, 0.1, 0.11) * (1.25 if husk else 1.0), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
	for side: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(side * 0.06, 0.0, 0.08), Vector3(side * 0.15, 0.02, 0.0), Vector3(side * 0.11, -0.01, -0.08)]),
			PackedFloat32Array([0.016, 0.02, 0.012]), 5, Color(0.92, 0.88, 0.8), 1.0, 0.05)
	cm.tube(PackedVector3Array([Vector3(-0.15, -0.04, 0.0), Vector3(0.0, -0.06, -0.12), Vector3(0.15, -0.04, 0.0), Vector3(0.0, -0.02, 0.12), Vector3(-0.15, -0.04, 0.0)]),
		PackedFloat32Array([0.022, 0.022, 0.022, 0.022, 0.022]), 5, RAG, 0.0, 0.2, 0.0, Vector2.ONE, 1.0)
	if abbot or warden:
		# r30: one lofted robe with real folds (it was 18 separate rods with the legs showing between).
		# The Abbot's cassock reaches the ground; the Warden's bell hangs short of it (it floats, no legs).
		if abbot:
			cm.skirt(Vector3(0, -0.02, 0.0), 0.19, 0.16, 1.04, 0.12, 0.6, 9, 0.18, Color(0.95, 0.92, 0.92))
			cm.tube(PackedVector3Array([Vector3(-0.19, -0.04, 0.0), Vector3(0.0, -0.06, -0.17), Vector3(0.19, -0.04, 0.0), Vector3(0.0, -0.02, 0.17), Vector3(-0.19, -0.04, 0.0)]),
				PackedFloat32Array([0.018, 0.018, 0.018, 0.018, 0.018]), 6, Color(1.0, 0.74, 0.32), 1.0, 0.02)    # a gilt girdle
		else:
			cm.skirt(Vector3(0, 0.0, 0.0), 0.2, 0.18, 0.74, 0.1, 1.0, 11, 0.35, Color(0.95, 0.93, 0.9))
			for k in 6:
				var th := 0.35 + float(k) * (PI - 0.7) / 5.0          # tatters trailing behind, off the hem
				var root := Vector3(cos(th) * 0.36, -0.66, sin(th) * 0.32)
				cm.ribbon(root, Vector3(cos(th) * 0.2, -0.5, 1.0).normalized(), 0.32 + 0.1 * float(k % 3), 0.07, 0.08, Color(0.9, 0.88, 0.85), 1.0, 0.5, 6)
		if abbot:
			# rope girdle with hanging finger-bone beads
			for k in 7:
				var x := -0.09 + 0.03 * float(k)
				cm.strand(Vector3(x, -0.05, -0.13), Vector3(0.0, -1.0, -0.1).normalized(), 0.18 + 0.04 * float(k % 3), 0.008, 0.0, Color(0.85, 0.8, 0.75), 0.0, 1.0, 4)
				cm.blob(Vector3(x, -0.25 - 0.04 * float(k % 3), -0.15), Vector3(0.012, 0.02, 0.012), Basis.IDENTITY, Color.WHITE, 1.0, 0.0, 0.0, 3, 5)
	else:
		var strips := 11 if wretch else (9 if husk else 7)
		for k in strips:
			var ang := TAU * float(k) / float(strips) + 0.3
			var o := Vector3(cos(ang) * 0.14, -0.05, sin(ang) * 0.12)
			var rag_len := 0.18 + 0.16 * float((k * 7) % 4) / 3.0 + (0.12 if wretch else 0.0)
			var splay := Vector3(cos(ang), 0.0, sin(ang)) * 0.05
			cm.tube(PackedVector3Array([o, o + Vector3(0, -rag_len * 0.5, 0) + splay * 0.5, o + Vector3(0, -rag_len, 0) + splay]),
				PackedFloat32Array([0.034, 0.03, 0.006]), 5, Color(0.9, 0.82, 0.8), 0.0, 0.3, 0.0, Vector2(1.0, 0.25), 1.0)
		if wretch:
			# a long front flap of loincloth
			cm.tube(PackedVector3Array([Vector3(0, -0.06, -0.13), Vector3(0.01, -0.2, -0.15), Vector3(-0.01, -0.36, -0.13)]),
				PackedFloat32Array([0.07, 0.06, 0.02]), 5, Color(0.8, 0.72, 0.7), 0.0, 0.3, 0.0, Vector2(1.0, 0.18), 1.0)
		if husk:
			cm.wrap(Vector3(0, -0.02, 0), Vector3(0, -0.1, 0), 0.19, 1.5, 0.018)
	parts["pelvis"] = cm.commit()

	# --- chest: torso, spine, ribs, clavicles, shoulder blades, neck cords ---
	cm = _cm(sd + 1)
	var spine := PackedVector3Array([Vector3(0, -0.32, 0.09), Vector3(0, -0.12, 0.12), Vector3(0, 0.08, 0.14), Vector3(0, 0.24, 0.08)])
	if husk:
		cm.blob(Vector3(0, -0.17, -0.05), Vector3(0.25, 0.22, 0.23), Basis.IDENTITY, Color(1.0, 0.92, 0.92), 0.0, 0.16)
		cm.blob(Vector3(0, -0.28, -0.1), Vector3(0.2, 0.1, 0.17), Basis.IDENTITY, Color(0.95, 0.85, 0.85), 0.0, 0.2)   # sagging fold
		cm.blob(Vector3(0, 0.07, 0.0), Vector3(0.22, 0.15, 0.15), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		for side: float in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.13, 0.17, 0.05), Vector3(0.11, 0.08, 0.09), Basis(Vector3.FORWARD, side * 0.5), Color.WHITE, 0.0, 0.12)   # trapezius mass
		for k in 4:
			for side: float in [-1.0, 1.0]:
				cm.rib(Vector3(0, 0.12 - 0.07 * float(k), 0.15), side, 0.17, 0.05, 0.017, 0.82)
		cm.blob(Vector3(0, -0.02, -0.2), Vector3(0.06, 0.07, 0.03), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 6, 8)
		# the stitched seam down the belly: a dark cut crossed by stitches
		cm.tube(PackedVector3Array([Vector3(0, -0.06, -0.255), Vector3(0.01, -0.18, -0.285), Vector3(0, -0.32, -0.25)]),
			PackedFloat32Array([0.008, 0.01, 0.008]), 5, Color(0.35, 0.12, 0.15), 0.0, 0.0)
		for k in 6:
			var y := -0.08 - 0.045 * float(k)
			var z := -0.255 - 0.03 * sin(float(k) / 5.0 * PI)
			cm.tube(PackedVector3Array([Vector3(-0.03, y + 0.008, z + 0.01), Vector3(0, y, z - 0.008), Vector3(0.03, y - 0.008, z + 0.01)]),
				PackedFloat32Array([0.004, 0.005, 0.004]), 4, Color(0.3, 0.25, 0.22), 1.0, 0.0)
		if not abbot:
			cm.wrap(Vector3(-0.2, 0.15, 0.0), Vector3(0.2, -0.25, 0.0), 0.2, 0.5, 0.022)   # a bandage across the chest
	elif spit:
		cm.blob(Vector3(0, 0.0, 0.01), Vector3(0.13, 0.18, 0.1), Basis.IDENTITY, Color.WHITE, 0.0, 0.1)
		cm.tube(PackedVector3Array([Vector3(0, -0.32, 0.02), Vector3(0, -0.16, 0.0), Vector3(0, -0.04, 0.0)]), PackedFloat32Array([0.09, 0.08, 0.11]), 9)
		for k in 3:
			for side: float in [-1.0, 1.0]:
				cm.rib(Vector3(0, -0.0 - 0.06 * float(k), 0.1), side, 0.11, 0.03, 0.009, 0.7)
		# a ridge of glowing glands down the back
		for k in 5:
			var y := 0.18 - 0.1 * float(k)
			for side: float in [-1.0, 1.0]:
				cm.blob(Vector3(side * (0.045 + 0.01 * float(k % 2)), y, 0.12 - 0.01 * float(k)), Vector3(0.026, 0.032, 0.022) * (1.0 - 0.1 * float(k)), Basis.IDENTITY, Color.WHITE, 0.0, 0.05, 1.0, 5, 8)
	else:
		var gaunt := 0.85 if warden else 1.0
		cm.blob(Vector3(0, 0.0, 0.0), Vector3(0.16, 0.2, 0.12) * Vector3(gaunt, 1.05, gaunt), Basis(Vector3.RIGHT, -0.25), Color.WHITE, 0.0, 0.14)
		cm.tube(PackedVector3Array([Vector3(0, -0.32, 0.03), Vector3(0, -0.18, 0.01), Vector3(0, -0.06, 0.01)]), PackedFloat32Array([0.1, 0.075, 0.12]), 9, Color.WHITE, 0.0, 0.1, 0.0, Vector2(1.0, 0.8))
		for k in 4:
			for side: float in [-1.0, 1.0]:
				cm.rib(Vector3(0, 0.04 - 0.065 * float(k), 0.12), side, 0.145 - 0.008 * float(k), 0.04, 0.012, 0.72)
		for side: float in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.19, 0.12, 0.05), Vector3(0.09, 0.07, 0.08), Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
			# shoulder blades jutting from the hunched back
			cm.plate(Vector3(side * 0.1, 0.1, 0.13), Vector3(0.07, 0.012, 0.09), Vector3(side * 0.3, 0.3, 1.0), Color(0.95, 0.9, 0.85), 0.5)
		if wretch:
			# rag shawl over the shoulders: torn strips hanging front and back
			for k in 12:
				var side := -1.0 if k < 6 else 1.0
				var j := k % 6
				var front := j < 3
				var root := Vector3(side * (0.08 + 0.05 * float(j % 3)), 0.2, (-0.07 if front else 0.12))
				cm.strand(root, Vector3(side * 0.15, -1.0, -0.25 if front else 0.35).normalized(), 0.22 + 0.06 * float(j % 3), 0.035, 0.02, Color(0.75, 0.68, 0.66), 1.0, 0.3, 5)
	# clavicles, sternum
	for side: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(side * 0.02, 0.15, -0.1), Vector3(side * 0.12, 0.17, -0.08), Vector3(side * 0.21, 0.15, -0.02)]),
			PackedFloat32Array([0.012, 0.014, 0.016]), 5, Color(0.95, 0.92, 0.85), 1.0, 0.05)
	cm.vertebrae(spine, 0.032 * (1.3 if husk else 1.0), 8, Vector3.BACK)
	# neck with the cords standing out
	if spit:
		cm.tube(PackedVector3Array([Vector3(0, 0.16, 0.03), Vector3(0, 0.28, -0.04), Vector3(0, 0.36, -0.1), Vector3(0, 0.4, -0.14)]), PackedFloat32Array([0.07, 0.055, 0.05, 0.05]), 9)
		cm.vertebrae(PackedVector3Array([Vector3(0, 0.18, 0.08), Vector3(0, 0.3, 0.02), Vector3(0, 0.38, -0.06)]), 0.02, 5, Vector3(0, 0.5, 1.0).normalized())
	elif not husk:
		cm.tube(PackedVector3Array([Vector3(0, 0.16, 0.05), Vector3(0, 0.27, 0.0), Vector3(0, 0.36, -0.05)]), PackedFloat32Array([0.055, 0.045, 0.045]), 9)
		for side: float in [-1.0, 1.0]:
			cm.tube(PackedVector3Array([Vector3(side * 0.025, 0.15, -0.07), Vector3(side * 0.035, 0.26, -0.04), Vector3(side * 0.04, 0.35, -0.02)]),
				PackedFloat32Array([0.012, 0.014, 0.01]), 5, SINEW, 0.0, 0.05)
	if abbot:
		# a stole of dark cloth over the shoulders, and the reliquary chain
		for side: float in [-1.0, 1.0]:
			cm.ribbon(Vector3(side * 0.1, 0.24, -0.13), Vector3(side * 0.04, -1.0, -0.14).normalized(), 0.64, 0.075, 0.02, Color(1.0, 0.74, 0.32), 0.0, 0.1, 7, 1.0)
		# a heavy cope over the shoulders, open at the breast so the reliquary shows
		cm.skirt(Vector3(0, 0.2, 0.03), 0.25, 0.19, 0.5, 0.22, 0.4, 7, 0.12, Color(0.95, 0.92, 0.92), 0.6)
		cm.tube(PackedVector3Array([Vector3(-0.14, 0.22, -0.08), Vector3(-0.06, 0.02, -0.24), Vector3(0, -0.04, -0.27), Vector3(0.06, 0.02, -0.24), Vector3(0.14, 0.22, -0.08)]),
			PackedFloat32Array([0.008, 0.008, 0.008, 0.008, 0.008]), 4, Color(0.6, 0.55, 0.5), 1.0, 0.0)
	if warden:
		# the robe's yoke and a hanging hood at the back of the neck
		cm.blob(Vector3(0, 0.15, 0.02), Vector3(0.24, 0.07, 0.17), Basis.IDENTITY, Color(0.9, 0.85, 0.85), 0.0, 0.2, 0.0, 6, 12, 1.0)
		cm.blob(Vector3(0, 0.22, 0.14), Vector3(0.15, 0.13, 0.08), Basis(Vector3.RIGHT, 0.4), Color(0.85, 0.8, 0.8), 0.0, 0.25, 0.0, 6, 10, 1.0)
		# a mantle over the shoulders (a surface, not a fan of spikes), a gilt hem on it
		cm.skirt(Vector3(0, 0.19, 0.02), 0.26, 0.2, 0.42, 0.12, 0.45, 8, 0.15, Color(0.95, 0.93, 0.9), 0.5)
		for side: float in [-1.0, 1.0]:
			cm.ribbon(Vector3(side * 0.08, 0.2, -0.15), Vector3(side * 0.05, -1.0, -0.1).normalized(), 0.55, 0.06, 0.02, Color(1.0, 0.88, 0.6), 0.0, 0.1, 7, 1.0)
	parts["chest"] = cm.commit()
	if abbot:
		var lantern := _cm(sd + 3)
		lantern.blob(Vector3(0, -0.06, -0.29), Vector3(0.05, 0.065, 0.05), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 6, 8)
		parts["glow:chest"] = lantern.commit()
		var cage := _cm(sd + 4)
		for k in 6:
			var ang := TAU * float(k) / 6.0
			var o := Vector3(cos(ang) * 0.06, 0.0, sin(ang) * 0.06)
			cage.tube(PackedVector3Array([Vector3(0, 0.03, -0.29) + o * 0.5, Vector3(0, -0.04, -0.29) + o, Vector3(0, -0.12, -0.29) + o * 0.9, Vector3(0, -0.16, -0.29) + o * 0.3]),
				PackedFloat32Array([0.006, 0.008, 0.008, 0.006]), 4, Color(0.9, 0.85, 0.75), 1.0, 0.0)
		cage.claw(Vector3(0, -0.16, -0.29), Vector3.DOWN, 0.08, 0.012, Vector3.ZERO, Color(0.9, 0.85, 0.75))
		parts["boss:chest"] = cage.commit()

	# --- head ---
	cm = _cm(sd + 2)
	var ho := Vector3(0, 0.02, -0.14) if spit else (Vector3(0, -0.06, -0.06) if husk else Vector3.ZERO)
	var hs := 0.82 if husk else 1.0
	cm.blob(ho + Vector3(0, 0.06, -0.02) * hs, Vector3(0.095, 0.1, 0.135) * hs * (Vector3(0.92, 1.1, 1.0) if warden else Vector3.ONE), Basis(Vector3.RIGHT, 0.2), Color.WHITE, 0.0, 0.12)
	# brow ridge and cheekbones
	cm.tube(PackedVector3Array([ho + Vector3(-0.07, 0.1, -0.1) * hs, ho + Vector3(0, 0.085, -0.145) * hs, ho + Vector3(0.07, 0.1, -0.1) * hs]),
		PackedFloat32Array([0.018, 0.024, 0.018]), 6, Color(0.85, 0.8, 0.8))
	for side: float in [-1.0, 1.0]:
		cm.blob(ho + Vector3(side * 0.065, 0.025, -0.1) * hs, Vector3(0.025, 0.018, 0.03) * hs, Basis.IDENTITY, Color(0.95, 0.9, 0.85), 0.7, 0.05, 0.0, 4, 6)
		# sunken socket, the eye burning in it
		cm.blob(ho + Vector3(side * 0.04, 0.062, -0.122) * hs, Vector3(0.03, 0.022, 0.016) * hs, Basis(Vector3.FORWARD, side * 0.3), Color(0.25, 0.12, 0.14), 0.0, 0.0, 0.0, 4, 8)
		cm.blob(ho + Vector3(side * 0.04, 0.064, -0.13) * hs, Vector3(0.022, 0.014, 0.012) * (1.25 if warden else 1.0), Basis(Vector3.FORWARD, side * 0.3), Color.WHITE, 0.0, 0.0, 1.0, 5, 8)
	# open jaw, slung low; teeth on both rows
	var jaw := PackedVector3Array([ho + Vector3(-0.065, 0.0, -0.01) * hs, ho + Vector3(-0.045, -0.06, -0.09) * hs, ho + Vector3(0, -0.075, -0.135) * hs,
		ho + Vector3(0.045, -0.06, -0.09) * hs, ho + Vector3(0.065, 0.0, -0.01) * hs])
	cm.tube(jaw, PackedFloat32Array([0.024, 0.03, 0.032, 0.03, 0.024]), 7, Color(1.0, 0.85, 0.85))
	cm.blob(ho + Vector3(0, -0.035, -0.08) * hs, Vector3(0.04, 0.02, 0.05) * hs, Basis.IDENTITY, Color(0.45, 0.1, 0.12), 0.0, 0.1, 0.25, 4, 6)   # the wet maw
	for k in 5:
		var tx := (float(k) - 2.0) * 0.022
		cm.claw(ho + Vector3(tx, -0.058, -0.12 + absf(tx) * 0.6) * hs, Vector3(0, 1, -0.2).normalized(), 0.035, 0.007)
		cm.claw(ho + Vector3(tx, 0.025, -0.125 + absf(tx) * 0.6) * hs, Vector3(0, -1, -0.15).normalized(), 0.03, 0.006)
	if wretch:
		for k in 3:
			cm.claw(Vector3((float(k) - 1.0) * 0.05, 0.14, 0.02), Vector3((float(k) - 1.0) * 0.4, 0.6, 1.0).normalized(), 0.09, 0.018, Vector3(0, -0.3, 0))
		# torn, pointed ears and lank hair hanging past the shoulders
		for side: float in [-1.0, 1.0]:
			cm.claw(Vector3(side * 0.09, 0.07, 0.0), Vector3(side * 1.0, 0.5, 0.4).normalized(), 0.08, 0.022, Vector3(0, -0.2, 0.1), Color(0.85, 0.75, 0.75))
		for k in 16:
			var ang := -2.3 + 4.6 * float(k) / 15.0
			var root := Vector3(sin(ang) * 0.085, 0.13 - 0.03 * absf(sin(ang)), cos(ang) * 0.07 + 0.01)
			var out := Vector3(sin(ang) * 0.5, -1.0, cos(ang) * 0.45 + 0.25).normalized()
			cm.strand(root, out, 0.3 + 0.18 * float((k * 7) % 5) / 4.0, 0.016, 0.04, Color(0.55, 0.5, 0.5), 1.0, 0.6, 6)
	elif husk and not abbot:
		# stitches across the scalp
		cm.tube(PackedVector3Array([ho + Vector3(0.0, 0.15, -0.08) * hs, ho + Vector3(0.01, 0.168, 0.0) * hs, ho + Vector3(0.0, 0.15, 0.08) * hs]),
			PackedFloat32Array([0.005, 0.006, 0.005]), 4, Color(0.35, 0.12, 0.15), 0.0, 0.0)
		for k in 4:
			var z := -0.05 + 0.035 * float(k)
			cm.tube(PackedVector3Array([ho + Vector3(-0.018, 0.158, z) * hs, ho + Vector3(0.005, 0.17, z) * hs, ho + Vector3(0.026, 0.158, z) * hs]),
				PackedFloat32Array([0.003, 0.004, 0.003]), 4, Color(0.3, 0.25, 0.22), 1.0, 0.0)
	elif spit:
		for k in 5:
			cm.claw(ho + Vector3(0, 0.15 - 0.01 * float(k), 0.04 * float(k)), Vector3(0, 0.6, 1.0).normalized(), 0.07 - 0.008 * float(k), 0.012, Vector3(0, -0.2, 0))
	parts["head"] = cm.commit()
	if abbot:
		parts["boss:head"] = _abbot_mitre(sd + 5)
	elif warden:
		parts["boss:head"] = _warden_mask(sd + 5)
		parts["glow:head"] = _warden_halo(sd + 6)

	# --- arms ---
	for tag: String in ["l", "r"]:
		var sx := -1.0 if tag == "l" else 1.0
		cm = _cm(sd + 10)
		cm.blob(Vector3(sx * 0.01, 0.0, 0.0), Vector3(0.07, 0.065, 0.07) * limb_r, Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		cm.limb(Vector3.ZERO, Vector3(0, -0.31, -0.01), 0.052 * limb_r, 0.038 * limb_r, Color.WHITE, Vector3(sx * 0.008, 0, -0.012))
		cm.tube(PackedVector3Array([Vector3(sx * 0.02, -0.04, -0.045 * limb_r), Vector3(sx * 0.01, -0.16, -0.05 * limb_r), Vector3(0, -0.28, -0.03 * limb_r)]),
			PackedFloat32Array([0.01, 0.014, 0.008]), 5, SINEW, 0.0, 0.05)    # biceps cord
		if husk and not abbot:
			cm.wrap(Vector3(0, -0.12, 0), Vector3(0, -0.27, -0.01), 0.05 * limb_r, 2.5, 0.012)
		if warden or abbot:
			cm.skirt(Vector3(0, -0.02, 0.0), 0.075, 0.075, 0.34, 0.0, 0.55, 5, 0.1, Color(0.95, 0.92, 0.92), 0.0, 6, 18)    # a wide sleeve
		parts["shoulder_" + tag] = cm.commit()
		cm = _cm(sd + 11)
		cm.limb(Vector3.ZERO, Vector3(0, -0.29, -0.01), 0.04 * limb_r, 0.027 * limb_r, Color.WHITE, Vector3(0, 0, 0.01))
		cm.blob(Vector3(0, 0.0, 0.03), Vector3(0.028, 0.03, 0.022) * limb_r, Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 4, 6)
		for k in 2:
			var x := (float(k) - 0.5) * 0.024 * limb_r
			cm.tube(PackedVector3Array([Vector3(x, -0.03, -0.03 * limb_r), Vector3(x * 1.2, -0.15, -0.033 * limb_r), Vector3(x, -0.27, -0.022 * limb_r)]),
				PackedFloat32Array([0.006, 0.009, 0.005]), 4, SINEW, 0.0, 0.05)    # forearm tendons
		if wretch or (husk and not abbot):
			cm.wrap(Vector3(0, -0.15, -0.005), Vector3(0, -0.27, -0.01), 0.034 * limb_r, 2.0, 0.009)
		if warden:
			cm.skirt(Vector3(0, -0.06, 0.0), 0.06, 0.06, 0.3, 0.06, 1.1, 6, 0.3, Color(0.95, 0.93, 0.9), 0.0, 6, 18)     # the sleeve's bell
		parts["elbow_" + tag] = cm.commit()
		cm = _cm(sd + 12)
		cm.blob(Vector3(0, -0.03, 0), Vector3(0.034, 0.045, 0.024) * limb_r, Basis.IDENTITY, Color.WHITE, 0.0, 0.1)
		var fingers := 4 if warden else 3
		for f in fingers:
			var fx := (float(f) - float(fingers - 1) * 0.5) * 0.022
			var flen := (0.2 if warden else 0.15) + claw * 0.3
			var tip := Vector3(fx * 1.4, -flen, -0.03)
			cm.blob(Vector3(fx, -0.065, -0.012), Vector3(0.011, 0.011, 0.011) * limb_r, Basis.IDENTITY, Color.WHITE, 1.0, 0.0, 0.0, 3, 5)   # knuckle
			cm.limb(Vector3(fx, -0.06, -0.005), tip, 0.012 * limb_r, 0.008 * limb_r, Color.WHITE, Vector3(0, 0, -0.012), 0.05)
			cm.claw(tip, Vector3(0, -0.6, -1.0).normalized(), claw, 0.009, Vector3(0, -0.6, 0.4))
		var thumb := Vector3(-sx * 0.04, -0.09, -0.04)
		cm.limb(Vector3(-sx * 0.02, -0.03, -0.01), thumb, 0.011 * limb_r, 0.008 * limb_r, Color.WHITE, Vector3.ZERO, 0.05)
		cm.claw(thumb, Vector3(-sx * 0.3, -0.5, -1.0).normalized(), claw * 0.6, 0.008, Vector3(0, -0.4, 0))
		parts["hand_" + tag] = cm.commit()
	if abbot:
		parts["boss:hand_r"] = _crozier(sd + 7)

	# --- legs ---
	for tag: String in ["l", "r"]:
		cm = _cm(sd + 20)
		cm.limb(Vector3(0, 0.02, 0), Vector3(0, -0.41, 0.0), 0.072 * limb_r, 0.05 * limb_r, Color.WHITE, Vector3(0, 0, -0.025))
		cm.tube(PackedVector3Array([Vector3(0, -0.04, 0.05 * limb_r), Vector3(0, -0.2, 0.06 * limb_r), Vector3(0, -0.38, 0.035 * limb_r)]),
			PackedFloat32Array([0.01, 0.014, 0.009]), 5, SINEW, 0.0, 0.05)    # hamstring
		parts["hip_" + tag] = cm.commit()
		cm = _cm(sd + 21)
		cm.limb(Vector3.ZERO, Vector3(0, -0.4, 0.02), 0.05 * limb_r, 0.034 * limb_r, Color.WHITE, Vector3(0, 0, 0.015))
		cm.blob(Vector3(0, -0.005, -0.04 * limb_r), Vector3(0.03, 0.036, 0.02) * limb_r, Basis.IDENTITY, Color(0.85, 0.8, 0.75), 0.45, 0.05, 0.0, 4, 6)   # kneecap
		cm.tube(PackedVector3Array([Vector3(0, -0.05, -0.04 * limb_r), Vector3(0, -0.2, -0.042 * limb_r), Vector3(0, -0.36, -0.03 * limb_r)]),
			PackedFloat32Array([0.01, 0.009, 0.007]), 5, Color(0.85, 0.8, 0.74), 0.7 if wretch else 0.35, 0.05)    # shin ridge
		if husk and not abbot:
			cm.wrap(Vector3(0, -0.08, 0), Vector3(0, -0.34, 0.01), 0.048 * limb_r, 3.0, 0.012)
		parts["knee_" + tag] = cm.commit()
		cm = _cm(sd + 22)
		cm.tube(PackedVector3Array([Vector3(0, 0.0, 0.03), Vector3(0, -0.03, -0.05), Vector3(0, -0.045, -0.12)]),
			_k([0.045, 0.04, 0.032], limb_r), 8)
		cm.claw(Vector3(0, -0.02, 0.05), Vector3(0, -0.5, 1.0).normalized(), 0.05, 0.014, Vector3.ZERO)     # heel spur
		for t in 3:
			var tx := (float(t) - 1.0) * 0.025
			cm.claw(Vector3(tx, -0.05, -0.13), Vector3(tx * 3.0, -0.35, -1.0).normalized(), 0.055, 0.011, Vector3(0, -0.5, 0))
		parts["foot_" + tag] = cm.commit()
	if kind == &"ossuant" or abbot:
		for j: String in _ossuant_armour():
			parts["armour:" + j] = _armour[j]
	if warden:
		for j: String in ["hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r"]:
			parts.erase(j)                          # it does not walk: the bell robe floats over the dais
	return parts


static var _armour := {}


## Ossuant: bone armour over the husk frame so it reads as its own creature, not a recolour --
## a crowned skull mask, shoulder pauldrons with spurs, an outer ribcage, a spinal ridge, and a
## fauld of hanging long bones.
static func _ossuant_armour() -> Dictionary:
	if _armour.is_empty():
		var w := Color(1, 1, 1)
		var dark := Color(0.35, 0.3, 0.28)
		var cm := _cm(9101)
		cm.blob(Vector3(0, 0.07, -0.02), Vector3(0.13, 0.13, 0.15), Basis.IDENTITY, w, 0.6, 0.05, 0.0, 7, 10)
		cm.blob(Vector3(0, 0.0, -0.12), Vector3(0.08, 0.07, 0.06), Basis.IDENTITY, w, 0.6, 0.04, 0.0, 5, 8)
		for sd: float in [-1.0, 1.0]:
			cm.blob(Vector3(sd * 0.045, 0.05, -0.155), Vector3(0.032, 0.03, 0.02), Basis.IDENTITY, dark, 0.0, 0.0, 0.0, 4, 6)
			cm.blob(Vector3(sd * 0.045, 0.05, -0.16), Vector3(0.016, 0.012, 0.01), Basis.IDENTITY, w, 0.0, 0.0, 1.0, 4, 6)
			cm.claw(Vector3(sd * 0.08, 0.16, 0.02), Vector3(sd * 0.5, 1.0, 0.35).normalized(), 0.2, 0.025, Vector3(0, 0, 0.05), w)
		cm.claw(Vector3(0, 0.19, 0.0), Vector3(0, 1.0, 0.45).normalized(), 0.24, 0.028, Vector3(0, 0, 0.06), w)
		for k in 5:
			var x := (float(k) - 2.0) * 0.022
			cm.blob(Vector3(x, -0.05, -0.15), Vector3(0.009, 0.016, 0.008), Basis.IDENTITY, w, 0.0, 0.0, 0.0, 2, 4)
		_armour["head"] = cm.commit()
		cm = _cm(9102)
		for sd: float in [-1.0, 1.0]:
			cm.blob(Vector3(sd * 0.27, 0.14, 0.0), Vector3(0.12, 0.08, 0.12), Basis(Vector3.FORWARD, sd * -0.4), w, 0.6, 0.06, 0.0, 5, 8)
			for j in 2:
				cm.claw(Vector3(sd * (0.3 + 0.05 * float(j)), 0.19, 0.03 - 0.07 * float(j)), Vector3(sd * 0.8, 0.7, 0.2).normalized(), 0.18 - 0.04 * float(j), 0.022, Vector3(0, 0.03, 0), w)
			for k in 4:
				cm.rib(Vector3(0, 0.1 - 0.075 * float(k), 0.14), sd, 0.24, 0.06, 0.02, 0.95)
		for k in 6:
			var y := 0.2 - 0.09 * float(k)
			cm.claw(Vector3(0, y, 0.17), Vector3(0, 0.45, 1.0).normalized(), 0.12 + 0.03 * float(k % 2), 0.02, Vector3(0, 0.03, 0), w)
		cm.blob(Vector3(0, -0.02, -0.24), Vector3(0.1, 0.13, 0.04), Basis.IDENTITY, w, 0.6, 0.05, 0.0, 5, 8)
		_armour["chest"] = cm.commit()
		cm = _cm(9103)
		for k in 7:
			var a := -1.2 + 2.4 * float(k) / 6.0
			var o := Vector3(sin(a) * 0.17, -0.06, -cos(a) * 0.13)
			cm.tube(PackedVector3Array([o, o + Vector3(0, -0.14, 0) + o * 0.15, o + Vector3(0, -0.28, 0) + o * 0.3]), PackedFloat32Array([0.022, 0.016, 0.02]), 5, w, 0.6, 0.03)
		_armour["pelvis"] = cm.commit()
	return _armour


## Bone Abbot: a tall closed mitre (one shield-section crown narrowing to a single peak, not two
## diverging plates that read as ears), a gilt circlet and front band, a burning sigil on the brow,
## two lappets falling behind.
static func _abbot_mitre(seed_v: int) -> ArrayMesh:
	var cm := _cm(seed_v)
	var w := Color(1.0, 0.97, 0.9)
	var gold := Color(1.0, 0.74, 0.32)
	var pts := PackedVector3Array([Vector3(0, 0.12, 0.0), Vector3(0, 0.2, 0.0), Vector3(0, 0.3, -0.005), Vector3(0, 0.4, -0.01), Vector3(0, 0.48, -0.012), Vector3(0, 0.55, -0.01)])
	cm.tube(pts, PackedFloat32Array([0.118, 0.124, 0.11, 0.08, 0.04, 0.0]), 16, w, 1.0, 0.015, 0.0, Vector2(1.0, 0.62))
	var band := PackedVector3Array()
	var br := PackedFloat32Array()
	for k in 25:
		var a := TAU * float(k) / 24.0
		band.append(Vector3(cos(a) * 0.12, 0.13, sin(a) * 0.076))
		br.append(0.016)
	cm.tube(band, br, 6, gold, 1.0, 0.02)                       # the circlet
	for z: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(0, 0.14, z * 0.078), Vector3(0, 0.3, z * 0.07), Vector3(0, 0.44, z * 0.035), Vector3(0, 0.53, z * 0.006)]),
			PackedFloat32Array([0.013, 0.012, 0.01, 0.006]), 5, gold, 1.0, 0.02)          # the orphrey bands
	cm.vertebrae(PackedVector3Array([Vector3(0.118, 0.15, 0.0), Vector3(0.1, 0.3, 0.0), Vector3(0.05, 0.47, 0.0)]), 0.014, 6, Vector3.RIGHT)
	cm.vertebrae(PackedVector3Array([Vector3(-0.118, 0.15, 0.0), Vector3(-0.1, 0.3, 0.0), Vector3(-0.05, 0.47, 0.0)]), 0.014, 6, Vector3.LEFT)
	cm.blob(Vector3(0, 0.25, -0.083), Vector3(0.03, 0.04, 0.01), Basis.IDENTITY, w, 0.0, 0.0, 1.0, 4, 6)    # the sigil
	for side: float in [-1.0, 1.0]:
		cm.ribbon(Vector3(side * 0.045, 0.14, 0.075), Vector3(side * 0.1, -1.0, 0.3).normalized(), 0.42, 0.055, 0.04, gold, 0.0, 0.2, 7, 1.0)
	return cm.commit()

## Bone Abbot's crozier: a long staff of fused vertebrae ending in a hooked spiral, held upright.
static func _crozier(seed_v: int) -> ArrayMesh:
	var cm := _cm(seed_v)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 8:
		var t := float(k) / 7.0
		pts.append(Vector3(0.0, lerpf(-0.75, 1.15, t), -0.04 + 0.02 * sin(t * 5.0)))
		radii.append(0.022)
	cm.tube(pts, radii, 6, Color(0.9, 0.85, 0.75), 1.0, 0.1)
	cm.vertebrae(pts, 0.03, 14, Vector3.BACK)
	var hook := PackedVector3Array()
	var hr := PackedFloat32Array()
	for k in 10:
		var a := float(k) / 9.0 * PI * 1.5
		hook.append(Vector3(0.0, 1.15 + sin(a) * 0.14, -0.04 - (1.0 - cos(a)) * 0.12))
		hr.append(0.022 * (1.0 - float(k) / 12.0))
	cm.tube(hook, hr, 6, Color(0.9, 0.85, 0.75), 1.0, 0.05)
	cm.claw(hook[9], Vector3(0, -1.0, 0.3).normalized(), 0.08, 0.016, Vector3.ZERO, Color.WHITE)
	cm.blob(Vector3(0, 1.0, -0.04), Vector3(0.05, 0.06, 0.05), Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 5, 8)   # a small skull at the crook
	cm.blob(Vector3(0, 0.99, -0.085), Vector3(0.012, 0.01, 0.008), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 3, 5)
	return cm.commit()


## Ascended Warden: one blank oval mask of white gold, two slit eyes burning, a hairline crack, and
## a veil falling from the crown behind it (ribbons: a veil was a fan of spikes).
static func _warden_mask(seed_v: int) -> ArrayMesh:
	var cm := _cm(seed_v)
	var mask := Color(1.0, 0.93, 0.78)
	cm.blob(Vector3(0, 0.075, -0.112), Vector3(0.088, 0.122, 0.045), Basis(Vector3.RIGHT, 0.12), mask, 1.0, 0.01, 0.0, 10, 16)
	for side: float in [-1.0, 1.0]:
		cm.blob(Vector3(side * 0.036, 0.09, -0.152), Vector3(0.028, 0.005, 0.006), Basis(Vector3.FORWARD, side * 0.12), Color.WHITE, 0.0, 0.0, 1.0, 3, 6)
	cm.tube(PackedVector3Array([Vector3(0.012, 0.19, -0.13), Vector3(0.02, 0.13, -0.152), Vector3(0.004, 0.06, -0.156), Vector3(0.016, -0.02, -0.146)]),
		PackedFloat32Array([0.002, 0.0026, 0.0026, 0.0015]), 4, Color(0.2, 0.12, 0.08), 1.0, 0.0)
	for k in 7:
		var ang := -1.9 + 3.8 * float(k) / 6.0
		var root := Vector3(sin(ang) * 0.1, 0.17, cos(ang) * 0.07 + 0.03)
		cm.ribbon(root, Vector3(sin(ang) * 0.3, -1.0, cos(ang) * 0.3 + 0.25).normalized(), 0.62 + 0.08 * float(k % 3), 0.085, 0.04, Color(0.95, 0.93, 0.9), 1.0, 0.25, 7)
	return cm.commit()

## Ascended Warden: a mandorla behind the head -- a solid ring with an inner hairline ring and a
## wheel of radial blades (it was a dotted ring of sausages and spikes, like barbed wire).
static func _warden_halo(seed_v: int) -> ArrayMesh:
	var cm := _cm(seed_v)
	var c := Vector3(0, 0.14, 0.2)
	cm.ring(c, Vector3.BACK, 0.33, 0.014, Color.WHITE, 0.0, 1.0, 40)
	cm.ring(c, Vector3.BACK, 0.27, 0.006, Color.WHITE, 0.0, 1.0, 32)
	for k in 16:
		var a := TAU * float(k) / 16.0
		var d := Vector3(cos(a), sin(a), 0.0)
		var len := 0.1 if k % 2 == 0 else 0.06
		cm.tube(PackedVector3Array([c + d * 0.275, c + d * (0.34 + len * 0.4), c + d * (0.34 + len)]), PackedFloat32Array([0.006, 0.016, 0.0]), 4, Color.WHITE, 0.0, 0.0, 1.0, Vector2(1.0, 0.3))
	return cm.commit()

# --- quadruped kinds (QuadRig) ----------------------------------------------------------------

static func _quad_parts(kind: StringName, rig: QuadRig) -> Dictionary:
	var thorn := kind == &"thornwarden"
	var leaper := kind == &"leaper" or thorn
	var parts := {}
	var sd := hash(kind) % 1000
	var L := rig.body_len
	var h := rig.body_height
	var bark := Color(0.95, 0.85, 0.8)

	# body: ribcage + haunch + belly, spine ridge, dorsal spines (leaper), chitin (crawler)
	var cm := _cm(sd)
	var bulk := 1.25 if leaper else 0.9
	cm.blob(Vector3(0, 0.03, -L * 0.22), Vector3(0.15, 0.14, 0.22) * bulk, Basis.IDENTITY, Color.WHITE, 0.0, 0.14)
	cm.blob(Vector3(0, 0.02, L * 0.24), Vector3(0.16, 0.13, 0.2) * bulk * (1.15 if leaper else 1.0), Basis.IDENTITY, Color.WHITE, 0.0, 0.14)
	cm.tube(PackedVector3Array([Vector3(0, -0.02, L * 0.35), Vector3(0, -0.04, 0.0), Vector3(0, -0.01, -L * 0.35)]),
		_k([0.11, 0.1, 0.12], bulk), 10, Color(0.92, 0.88, 0.9), 0.0, 0.16)
	var spine := PackedVector3Array([Vector3(0, 0.12 * bulk, L * 0.42), Vector3(0, 0.16 * bulk, 0.0), Vector3(0, 0.15 * bulk, -L * 0.4)])
	cm.vertebrae(spine, 0.03 * bulk, 11, Vector3.UP)
	if leaper:
		for k in 7:
			var z := lerpf(L * 0.34, -L * 0.34, float(k) / 6.0)
			cm.claw(Vector3(0, 0.17 * bulk, z), Vector3(0, 1.0, 0.7).normalized(), (0.11 + 0.05 * sin(float(k) * 1.3)) * (1.5 if thorn else 1.0), 0.02, Vector3(0, -0.2, 0.3))
		# ribs showing through the flanks, and the shoulder hump
		for side: float in [-1.0, 1.0]:
			for k in 5:
				var z := -L * 0.32 + L * 0.11 * float(k)
				cm.tube(PackedVector3Array([Vector3(side * 0.06, 0.13 * bulk, z), Vector3(side * 0.17 * bulk, 0.04, z + 0.01), Vector3(side * 0.15 * bulk, -0.08, z + 0.02)]),
					PackedFloat32Array([0.012, 0.016, 0.01]), 5, Color(0.95, 0.9, 0.85), 0.5, 0.05)
		cm.blob(Vector3(0, 0.12, -L * 0.3), Vector3(0.14, 0.09, 0.12) * bulk, Basis.IDENTITY, Color.WHITE, 0.0, 0.15)
	else:
		# chitin plates down the back, overlapping like a woodlouse
		for k in 6:
			var z := lerpf(L * 0.36, -L * 0.36, float(k) / 5.0)
			cm.plate(Vector3(0, 0.1 + 0.02 * sin(float(k) / 5.0 * PI), z), Vector3(0.16, 0.025, 0.075), Vector3(0, 1.0, -0.35), Color(0.9, 0.85, 0.9), 0.75, 0.05)
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var z := lerpf(L * 0.2, -L * 0.25, float(k) / 2.0)
				cm.blob(Vector3(side * 0.12, 0.08, z), Vector3(0.024, 0.02, 0.024), Basis.IDENTITY, Color(0.8, 0.6, 0.6), 0.0, 0.05, 0.1, 4, 6)   # weeping pores
	if thorn:
		# r30: bark shingles of varying size laid like roof tiles, spine to flank (two rows of nine
		# identical pills before); a bramble mane along the spine; the ember heart a split down the
		# sternum (it was a glowing stick under the jaw)
		var rng := RandomNumberGenerator.new()
		rng.seed = sd + 77
		for row in 3:
			var n := 10 - row * 2
			for k in n:
				var z := lerpf(L * 0.4, -L * 0.42, (float(k) + 0.5 * float(row % 2)) / float(n))
				for side: float in [-1.0, 1.0]:
					var a := 0.25 + 0.5 * float(row)
					var sz := Vector3(rng.randf_range(0.08, 0.13), 0.028, rng.randf_range(0.07, 0.11)) * bulk * (1.0 - 0.12 * float(row))
					var at := Vector3(side * sin(a) * 0.16 * bulk, cos(a) * 0.15 * bulk - 0.01 * float(row), z)
					cm.plate(at, sz, Vector3(side * sin(a) * 1.2, cos(a), 0.35).normalized(), bark * rng.randf_range(0.8, 1.05), 0.85, 0.22)
		for k in 9:
			var t := float(k) / 8.0
			var z := lerpf(L * 0.36, -L * 0.42, t)
			for side: float in [-1.0, 1.0]:
				cm.claw(Vector3(side * 0.025, 0.19 * bulk, z), Vector3(side * 0.5, 1.0, 0.6).normalized(), 0.12 + 0.05 * sin(t * 7.0), 0.014, Vector3(side * 0.2, -0.1, 0.3), Color(0.55, 0.42, 0.35))
		cm.wrap(Vector3(0, -0.02, L * 0.3), Vector3(0, -0.02, -L * 0.3), 0.15 * bulk, 2.5, 0.016, Color(0.6, 0.5, 0.45))
		for side: float in [-1.0, 1.0]:
			cm.plate(Vector3(side * 0.06, -0.02, -L * 0.45), Vector3(0.07, 0.025, 0.11), Vector3(side * 0.4, 0.0, -1.0).normalized(), bark, 0.85, 0.2)
		cm.tube(PackedVector3Array([Vector3(0.0, 0.08, -L * 0.47), Vector3(0.012, -0.0, -L * 0.5), Vector3(-0.008, -0.08, -L * 0.49), Vector3(0.004, -0.15, -L * 0.45)]),
			PackedFloat32Array([0.012, 0.022, 0.02, 0.008]), 5, Color.WHITE, 0.0, 0.05, 1.0, Vector2(0.45, 1.0))
	parts["body"] = cm.commit()

	# front: neck (+ a mane of quills on the leaper)
	cm = _cm(sd + 1)
	cm.tube(PackedVector3Array([Vector3(0, -0.02, 0.08), Vector3(0, 0.0, -0.04), Vector3(0, 0.02, -0.15)]),
		_k([0.11, 0.09, 0.075], bulk), 9, Color.WHITE, 0.0, 0.14)
	if leaper:
		for k in 9:
			var a := -1.2 + 2.4 * float(k) / 8.0
			cm.claw(Vector3(sin(a) * 0.06, 0.08, -0.02 + 0.03 * cos(a)), Vector3(sin(a) * 0.6, 0.8, 0.6).normalized(), 0.12 + 0.04 * float(k % 2), 0.012, Vector3(0, -0.2, 0.2))
	parts["front"] = cm.commit()

	# head
	cm = _cm(sd + 2)
	var hs := 1.2 if leaper else 0.9
	cm.blob(Vector3(0, 0.01, -0.07) * hs, Vector3(0.075, 0.065, 0.13) * hs, Basis(Vector3.RIGHT, 0.12), Color.WHITE, 0.0, 0.12)
	var jaw := PackedVector3Array([Vector3(-0.05, -0.03, -0.01) * hs, Vector3(-0.035, -0.07, -0.1) * hs, Vector3(0, -0.08, -0.16) * hs,
		Vector3(0.035, -0.07, -0.1) * hs, Vector3(0.05, -0.03, -0.01) * hs])
	cm.tube(jaw, _k([0.02, 0.025, 0.026, 0.025, 0.02], hs), 7, Color(1.0, 0.85, 0.85))
	cm.blob(Vector3(0, -0.045, -0.09) * hs, Vector3(0.03, 0.015, 0.05) * hs, Basis.IDENTITY, Color(0.45, 0.1, 0.12), 0.0, 0.1, 0.25, 4, 6)
	for k in 5:
		var tx := (float(k) - 2.0) * 0.018 * hs
		cm.claw(Vector3(tx, -0.06 * hs, (-0.15 + absf(tx) * 0.9) * hs), Vector3(0, 1, -0.3).normalized(), 0.03 * hs, 0.006)
		cm.claw(Vector3(tx, -0.005 * hs, (-0.16 + absf(tx) * 0.9) * hs), Vector3(0, -1, -0.2).normalized(), 0.028 * hs, 0.006)
	if leaper:
		for side: float in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.035, 0.032, -0.148) * hs, Vector3(0.028, 0.02, 0.016) * hs, Basis.IDENTITY, Color(0.25, 0.12, 0.14), 0.0, 0.0, 0.0, 4, 6)
			cm.blob(Vector3(side * 0.035, 0.035, -0.155) * hs, Vector3(0.02, 0.013, 0.014), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 5, 8)
			if not thorn:
				for k in 3:
					cm.claw(Vector3(side * (0.03 + 0.015 * float(k)), 0.06, 0.0 + 0.03 * float(k)) * hs,
						Vector3(side * 0.4, 0.5, 1.0).normalized(), 0.09 - 0.015 * float(k), 0.014, Vector3(0, -0.2, 0))
	else:
		for k in 4:
			var ex := (0.022 + 0.022 * float(k % 2)) * (-1.0 if k < 2 else 1.0)
			cm.blob(Vector3(ex, 0.03 + 0.012 * float(k % 2), -0.14 + 0.02 * float(k % 2)) * hs, Vector3(0.012, 0.01, 0.01), Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 4, 6)
		for side: float in [-1.0, 1.0]:
			cm.claw(Vector3(side * 0.04, -0.05, -0.15) * hs, Vector3(side * -0.25, -0.15, -1.0).normalized(), 0.08, 0.014, Vector3(side * -0.5, 0, 0))
			# feelers
			cm.strand(Vector3(side * 0.03, 0.05, -0.14) * hs, Vector3(side * 0.4, 0.5, -1.0).normalized(), 0.16, 0.006, -0.04, Color(0.8, 0.75, 0.8), 0.0, 1.0, 5)
	if thorn:
		# a long bone-white deer skull worn over the snout: the focal value of the boss
		cm.blob(Vector3(0, 0.035, -0.11) * hs, Vector3(0.068, 0.045, 0.15) * hs, Basis(Vector3.RIGHT, 0.18), Color(1.0, 0.96, 0.88), 1.0, 0.04, 0.0, 8, 12)
		cm.blob(Vector3(0, 0.05, -0.02) * hs, Vector3(0.085, 0.06, 0.07) * hs, Basis.IDENTITY, Color(1.0, 0.96, 0.88), 1.0, 0.05, 0.0, 8, 12)
		for side: float in [-1.0, 1.0]:
			cm.blob(Vector3(side * 0.042, 0.05, -0.12) * hs, Vector3(0.026, 0.02, 0.02) * hs, Basis.IDENTITY, Color(0.12, 0.06, 0.05), 0.0, 0.0, 0.0, 4, 8)   # deep sockets
			cm.blob(Vector3(side * 0.042, 0.05, -0.128) * hs, Vector3(0.012, 0.01, 0.008) * hs, Basis.IDENTITY, Color.WHITE, 0.0, 0.0, 1.0, 4, 6)       # embers in them
	parts["head"] = cm.commit()
	if thorn:
		parts["boss:head"] = _thorn_crown(sd + 30, hs, 1.6)

	# tail
	cm = _cm(sd + 3)
	var tl := 0.85 if leaper else 0.28
	var tpts := PackedVector3Array()
	var trad := PackedFloat32Array()
	for k in 8:
		var t := float(k) / 7.0
		tpts.append(Vector3(0, -0.02 - 0.08 * t * t, tl * t))
		trad.append(0.07 * bulk * (1.0 - t))
	cm.tube(tpts, trad, 8, Color.WHITE, 0.0, 0.12)
	if leaper:
		for k in 5:
			var t := 0.2 + 0.16 * float(k)
			cm.claw(Vector3(0, 0.04 - 0.08 * t * t, tl * t), Vector3(0, 1.0, 0.5).normalized(), 0.07, 0.014)
			for side: float in [-1.0, 1.0]:
				cm.claw(Vector3(side * 0.03 * (1.0 - t), -0.02 - 0.08 * t * t, tl * t), Vector3(side, 0.3, 0.5).normalized(), 0.045, 0.01)
	parts["tail"] = cm.commit()

	# legs: upper (hip → knee goes out and up), lower (knee → foot), toe claws
	for tag: String in ["fl", "fr", "bl", "br"]:
		var sx := -1.0 if tag.ends_with("l") else 1.0
		var hind: bool = tag.begins_with("b")
		var thick := (1.5 if hind and leaper else 1.0) * bulk
		cm = _cm(sd + 10)
		var knee := Vector3(sx * rig.upper_len, 0.1, 0.0)
		cm.blob(Vector3.ZERO, Vector3(0.06, 0.055, 0.06) * thick, Basis.IDENTITY, Color.WHITE, 0.0, 0.12)
		cm.limb(Vector3.ZERO, knee, 0.05 * thick, 0.034 * thick, Color.WHITE, Vector3(0, 0.03, 0))
		cm.tube(PackedVector3Array([Vector3(0, 0.03 * thick, 0.02), knee * 0.5 + Vector3(0, 0.07 * thick, 0.02), knee + Vector3(0, 0.02, 0.01)]),
			PackedFloat32Array([0.01, 0.013, 0.008]), 5, SINEW, 0.0, 0.05)
		if thorn:
			cm.wrap(Vector3.ZERO, knee, 0.05 * thick, 1.5, 0.012, Color(0.6, 0.5, 0.45))
		parts["leg_%s_hip" % tag] = cm.commit()
		cm = _cm(sd + 11)
		var foot := Vector3(sx * 0.07, -(h + 0.08), 0.0)
		cm.blob(Vector3.ZERO, Vector3(0.035, 0.035, 0.035) * thick, Basis.IDENTITY, Color.WHITE, 1.0, 0.05, 0.0, 4, 6)
		cm.limb(Vector3.ZERO, foot, 0.033 * thick, 0.016, Color.WHITE, Vector3(sx * 0.03, 0, 0), 0.08)
		if not leaper:
			# bristling spines down the shin
			for k in 3:
				var t := 0.25 + 0.22 * float(k)
				cm.claw(foot * t + Vector3(sx * 0.03 * (1.0 - t), 0, 0), Vector3(sx, 0.4, 0.2).normalized(), 0.05, 0.008, Vector3(0, 0.3, 0))
		else:
			cm.claw(Vector3(sx * 0.02, 0.02, 0.0), Vector3(sx * 0.6, 0.8, 0.3).normalized(), 0.07 * thick, 0.014, Vector3.ZERO)   # spur on the joint
		parts["leg_%s_knee" % tag] = cm.commit()
		cm = _cm(sd + 12)
		if thorn:
			# splayed root toes that grip the ground, and a pad (it stood on four pointed stilts)
			cm.blob(Vector3(0, -0.01, 0.0), Vector3(0.05, 0.03, 0.06), Basis.IDENTITY, Color(0.75, 0.62, 0.55), 0.6, 0.15, 0.0, 5, 8)
			for t in 5:
				var ang := (float(t) - 2.0) * 0.55 + (PI if t == 4 else 0.0) * 0.0
				var d := Vector3(sin(ang) * 0.8, -0.3, -cos(ang)).normalized() if t < 4 else Vector3(sx * 0.3, -0.35, 1.0).normalized()
				cm.tube(PackedVector3Array([Vector3.ZERO, d * 0.06 + Vector3(0, 0.01, 0), d * 0.12 + Vector3(0, -0.02, 0), d * 0.16 + Vector3(0, -0.035, 0)]),
					PackedFloat32Array([0.016, 0.013, 0.009, 0.0]), 5, Color(0.75, 0.62, 0.55), 0.6, 0.2)
		else:
			for t in 3:
				var ang := (float(t) - 1.0) * 0.5
				cm.claw(Vector3.ZERO, Vector3(sin(ang) * 0.7 + sx * 0.2, -0.25, -cos(ang)).normalized(), 0.07 * (1.4 if leaper else 1.0), 0.012, Vector3(0, -0.6, 0))
		parts["leg_%s_foot" % tag] = cm.commit()
	return parts


## Thornwarden: a crown of branching antlers with real mass (it was two wire-thin beams, smaller than
## the head, that read as insect antennae): each beam forks three levels deep, the tines barbed,
## bramble wound through the lower branches.
static func _thorn_crown(seed_v: int, head: float, grow: float) -> ArrayMesh:
	var hs := head * grow
	var cm := _cm(seed_v)
	var bark := Color(0.85, 0.74, 0.66)
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * 0.045, 0.06, -0.03) * head          # rooted in the skull
		_antler(cm, base, Vector3(side * 0.5, 1.0, 0.25).normalized(), 0.3 * hs, 0.034 * hs, 3, side, bark)
	return cm.commit()


## One antler branch: a curving beam from `root` along `dir`, forking twice toward its tip into
## smaller branches (`depth` levels), the last level ending in barbed tines.
static func _antler(cm: CreatureMesh, root: Vector3, dir: Vector3, length: float, radius: float, depth: int, side: float, col: Color) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var bend := Vector3(side * 0.3, -0.05, 0.15)
	for k in 6:
		var t := float(k) / 5.0
		pts.append(root + dir * length * t + bend * length * t * t)
		radii.append(radius * (1.0 - t * 0.6) if depth > 1 else radius * (1.0 - t))
	cm.tube(pts, radii, 7 if depth > 1 else 5, col, 0.85, 0.25)
	if depth <= 1:
		cm.claw(pts[2], Vector3(side, 0.5, -0.3).normalized(), length * 0.22, radius * 0.4, Vector3.ZERO, col)   # a barb
		return
	if depth == 3:
		cm.wrap(pts[0], pts[2], radius * 1.05, 2.0, radius * 0.18, Color(0.45, 0.4, 0.3))                        # bramble
	for f in 2:
		var i := 2 + f * 2
		var tan := (pts[i + 1] - pts[i - 1]).normalized()
		var out := (tan + Vector3(0, 0.9, 0) + Vector3(side * 0.2, 0, (0.5 if f == 0 else -0.4))).normalized()
		_antler(cm, pts[i], out, length * 0.5, radii[i] * 0.7, depth - 1, side, col)
	_antler(cm, pts[5], (pts[5] - pts[4]).normalized(), length * 0.4, radii[5] * 0.9, depth - 1, side, col)

static func _k(values: Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in values:
		out.append(float(v) * k)
	return out

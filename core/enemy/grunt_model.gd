extends RefCounted
## Modelled bodies for the rank-and-file enemies (r30). tools/blender/grunt_humanoid.py and
## grunt_quad.py build each kind in its rig's rest pose -- fused metaball muscle, cloth, bone,
## chitin, iron -- bake one atlas per kind and export ONE skinned mesh on a flat skeleton, a bone
## per rig socket (the two-legged kinds that wear things -- chanter, tollman, pilgrim, bulwark, wretch,
## gaunt, ossuant, quiller, cinder_caster -- come from tools/blender/biped_*.py: garments and armour cut from
## the body's own surface, see biped_sculpt_lib.py), weighted across every joint (knees, elbows, the waist bend as flesh; no cracks
## between rigid parts). GruntSkin poses the bones from the sockets each frame. EnemyBody / KinLook
## dress with these when the GLB exists and fall back to the procedural CreatureMesh body.
##
## Other meshes in the GLB are rigid, on a socket: "shield_<socket>" is the Bulwark's door-shield
## (node Kin_shield_<socket>, which bulwark.gd looks up and breaks off); "bell_<socket>" is the Tollman's
## hand-bell (node "Bell", which tollman.gd swings when it tolls).
## Load by path (no class_name): const GruntModel := preload("res://core/enemy/grunt_model.gd")

const SHADER := preload("res://core/enemy/grunt_pbr.gdshader")
const GruntSkin := preload("res://core/enemy/grunt_skin.gd")
const SHADOWED := ["chest", "pelvis", "head", "body", "front"]

## kind -> [glb, shader params]. Families: hollowed people = wet; rift-born = heat; Ossuary dead = dust
const BossLook := preload("res://core/enemy/boss_look.gd")
const KINDS := {
	&"wretch": ["res://art/models/grunt_wretch.glb", {"rim_col": Color(1.0, 0.46, 0.16), "rim_amount": 0.08, "wet": 0.0, "normal_depth": 1.2}],
	&"quiller": ["res://art/models/grunt_quiller.glb", {"rim_col": Color(0.62, 0.78, 1.0), "rim_amount": 0.09, "rim_scale": 0.3, "normal_depth": 1.25}],
	&"cinder_caster": ["res://art/models/grunt_cinder_caster.glb", {"rim_col": Color(1.3, 0.45, 0.12), "rim_amount": 0.11, "emit_pulse": 0.5, "pulse_rate": 1.6, "heat": 0.55, "normal_depth": 1.25}],
	&"gaunt": ["res://art/models/grunt_gaunt.glb", {"rim_col": Color(0.75, 0.82, 1.0), "rim_amount": 0.1, "rim_scale": 0.12, "emit_pulse": 0.5, "pulse_rate": 2.4, "wet": 0.0, "normal_depth": 1.25}],
	&"husk": ["res://art/models/grunt_husk.glb", {"rim_col": Color(1.0, 0.5, 0.12), "rim_amount": 0.08, "emit_pulse": 0.4, "pulse_rate": 1.4, "wet": 0.0, "normal_depth": 1.25}],
	&"spitter": ["res://art/models/grunt_spitter.glb", {"rim_col": Color(0.3, 1.0, 0.72), "rim_amount": 0.15, "emit_pulse": 0.5, "pulse_rate": 3.0, "membrane": 0.7, "wet": 0.0, "normal_depth": 1.15}],
	&"ossuant": ["res://art/models/grunt_ossuant.glb", {"rim_col": Color(1.0, 0.82, 0.48), "rim_amount": 0.09, "dust": 0.78, "dust_col": Color(0.46, 0.43, 0.38), "normal_depth": 1.3}],
	&"bulwark": ["res://art/models/grunt_bulwark.glb", {"rim_col": Color(1.0, 0.55, 0.2), "rim_amount": 0.1, "wet": 0.0, "normal_depth": 1.25}],
	&"chanter": ["res://art/models/grunt_chanter.glb", {"rim_col": Color(0.62, 1.0, 0.4), "rim_amount": 0.04, "emit_pulse": 0.12, "pulse_rate": 1.1, "wet": 0.0, "normal_depth": 1.2}],
	# the robed bipeds' remodel: cloth, not wet flesh
	&"tollman": ["res://art/models/grunt_tollman.glb", {"rim_col": Color(0.9, 0.62, 0.3), "rim_amount": 0.08, "wet": 0.0, "normal_depth": 1.2}],
	&"pilgrim": ["res://art/models/grunt_pilgrim.glb", {"rim_col": Color(1.0, 0.78, 0.42), "rim_amount": 0.1, "emit_pulse": 0.3, "pulse_rate": 1.3, "wet": 0.0, "normal_depth": 1.2}],
	&"crawler": ["res://art/models/grunt_crawler.glb", {"rim_col": Color(1.0, 0.26, 0.16), "rim_amount": 0.25, "heat": 0.72, "normal_depth": 1.3}],
	&"leaper": ["res://art/models/grunt_leaper.glb", {"rim_col": Color(1.0, 0.6, 0.14), "rim_amount": 0.02, "rim_scale": 0.0, "emit_pulse": 0.3, "pulse_rate": 1.8, "heat": 0.72, "normal_depth": 1.5}],
	&"burrower": ["res://art/models/grunt_burrower.glb", {"rim_col": Color(1.0, 0.62, 0.22), "rim_amount": 0.1, "emit_pulse": 0.35, "pulse_rate": 1.2, "heat": 0.62, "normal_depth": 1.6}],
	# the Thornwarden (a boss, r38d): bark and ember, one skinned body like the grunts'
	&"thornwarden": ["res://art/models/boss_thornwarden.glb", {"rim_col": Color(1.0, 0.42, 0.1), "rim_amount": 0, "rim_scale": 0.0, "heat": 0.55, "dust": 0.28, "dust_col": Color(0.32, 0.26, 0.18), "normal_depth": 1.25}],
	# the modelled bosses (tools/blender/boss_*.py): one skinned mesh each, a bone per rig socket
	&"bone_abbot": ["res://art/models/boss_bone_abbot.glb", {"rim_col": Color(1.0, 0.7, 0.32), "rim_amount": 0.08, "emit_energy": 2.0, "emit_pulse": 0.22, "pulse_rate": 3.2, "dust": 0.35, "dust_col": Color(0.48, 0.44, 0.38), "normal_depth": 1.25}],
	&"ascended_warden": ["res://art/models/boss_ascended_warden.glb", {"rim_col": Color(1.0, 0.88, 0.55), "rim_amount": 0.09, "emit_pulse": 0.12, "pulse_rate": 1.2, "wet": 0.0, "normal_depth": 1.2}],
	&"hierarch": ["res://art/models/boss_hierarch.glb", {"rim_col": Color(0.9, 0.85, 0.5), "rim_amount": 0.08, "emit_pulse": 0.18, "pulse_rate": 1.0, "dust": 0.25, "dust_col": Color(0.42, 0.4, 0.36), "normal_depth": 1.3}],
	&"anchoress": ["res://art/models/boss_anchoress.glb", {"rim_col": Color(0.8, 0.6, 0.4), "rim_amount": 0.065, "emit_pulse": 0.2, "pulse_rate": 1.6, "wet": 0.0, "normal_depth": 1.2}],
	&"mite": ["res://art/models/grunt_mite.glb", {"rim_col": Color(0.3, 1.0, 0.88), "rim_amount": 0.3, "emit_pulse": 0.48, "pulse_rate": 2.6, "membrane": 0.6, "heat": 0.6, "normal_depth": 1.15}],
}

static var _scenes := {}
static var _mats := {}


## Kinds whose model is BUILT (tools/blender/grunt_build.py): clean geometry with named surfaces, dressed in the tiling
## materials of boss_look.gd like the wanderer, not one baked atlas.
const BUILT := {}       # every kind is baked now (tools/blender/bake_kind.py): its own four maps, as the old atlases were


static func has(kind: StringName) -> bool:
	if BUILT.has(kind) and KINDS.has(kind):
		return ResourceLoader.exists(KINDS[kind][0])
	return KINDS.has(kind) and ResourceLoader.exists(KINDS[kind][0]) and ResourceLoader.exists(_tex(kind, "albedo"))


static func _tex(kind: StringName, map: String) -> String:
	return "res://art/textures/%s_%s.png" % [String(KINDS[kind][0]).get_file().get_basename(), map]


## Dress `rig` with the modelled `kind`. Returns the MeshInstance3Ds (hit flash / glint / dissolve),
## or an empty array when the model is missing.
static func dress(rig: CharacterRig, kind: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if rig == null or not has(kind):
		return out
	var ps := _scene(kind)
	if ps == null:
		return out
	var inst := ps.instantiate()
	var skel := inst.find_children("*", "Skeleton3D", true, false)
	var mat := material(kind)
	var phase := randf() * TAU
	var body: MeshInstance3D = null
	if not skel.is_empty():
		var sk := skel[0] as Skeleton3D
		for n in sk.find_children("*", "MeshInstance3D", true, false):
			body = n as MeshInstance3D
		if body == null:
			for n in inst.find_children("body*", "MeshInstance3D", true, false):
				body = n as MeshInstance3D
		if body != null:
			for n in [sk] + sk.find_children("*", "", true, false):
				n.owner = null
			sk.get_parent().remove_child(sk)
			sk.name = "GruntSkeleton"
			sk.transform = Transform3D.IDENTITY
			rig.add_child(sk)
			if body.get_parent() != sk:
				body.get_parent().remove_child(body)
				sk.add_child(body)
			body.skeleton = NodePath("..")
			body.transform = Transform3D.IDENTITY
			body.name = "Flesh_body"
			if BUILT.has(kind):
				BossLook.dress(kind, [body] as Array[MeshInstance3D])          # named surfaces in tiling materials
			else:
				body.material_override = mat
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			body.set_instance_shader_parameter(&"pulse_phase", phase)
			var drv := GruntSkin.new()
			drv.name = "GruntSkin"
			sk.add_child(drv)
			drv.setup(sk, rig, body)
			out.append(body)
	# rigid parts: "<tag>_<socket>" meshes, origin on that socket's joint
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi0 := n as MeshInstance3D
		if mi0 == body or mi0.mesh == null:
			continue
		var nm := String(mi0.name)
		var tag := ""
		var sock := nm
		for t: String in ["shield", "staff", "bell"]:
			if nm.begins_with(t + "_"):
				tag = t
				sock = nm.substr(t.length() + 1)
		var at := rig.socket(sock)
		if at == null:
			push_error("GruntModel: %s part '%s' has no socket" % [kind, nm])
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Bell" if tag == "bell" else {"shield": "Kin_shield_", "staff": "Kin_glow_"}.get(tag, "Flesh_") + sock
		mi.mesh = mi0.mesh
		if BUILT.has(kind):
			BossLook.dress(kind, [mi] as Array[MeshInstance3D])
		else:
			mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sock in SHADOWED or tag == "shield" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter(&"pulse_phase", phase)
		at.add_child(mi)
		out.append(mi)
	inst.free()
	# the Chanter's staff is skinned to its hand; chanter.gd reads the tip off this marker
	if kind == &"chanter" and rig.socket("hand_r") and rig.socket("hand_r").get_node_or_null("Kin_glow_hand_r") == null:
		var mark := Node3D.new()
		mark.name = "Kin_glow_hand_r"
		rig.socket("hand_r").add_child(mark)
	return out


## Ask the loader's worker threads for a modelled body's mesh and maps, so the first dress finds them read.
static func prefetch(kind: StringName) -> void:
	if not KINDS.has(kind):
		return
	for path: String in [KINDS[kind][0], _tex(kind, "albedo"), _tex(kind, "normal"), _tex(kind, "orm"), _tex(kind, "emit")]:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


static func _scene(kind: StringName) -> PackedScene:
	if not _scenes.has(kind):
		_scenes[kind] = load(KINDS[kind][0]) as PackedScene
	return _scenes[kind]


static func material(kind: StringName) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", load(_tex(kind, "albedo")))
	m.set_shader_parameter("normal_tex", load(_tex(kind, "normal")))
	m.set_shader_parameter("orm_tex", load(_tex(kind, "orm")))
	m.set_shader_parameter("emit_tex", load(_tex(kind, "emit")))
	var params: Dictionary = KINDS[kind][1]
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	_mats[kind] = m
	return m

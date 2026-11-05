extends RefCounted
## Modelled bodies for the rank-and-file enemies (r30). tools/blender/grunt_humanoid.py and
## grunt_quad.py build each kind in its rig's rest pose -- fused metaball muscle, cloth, bone,
## chitin, iron -- bake one atlas per kind and export ONE skinned mesh on a flat skeleton, a bone
## per rig socket, weighted across every joint (knees, elbows, the waist bend as flesh; no cracks
## between rigid parts). GruntSkin poses the bones from the sockets each frame. EnemyBody / KinLook
## dress with these when the GLB exists and fall back to the procedural CreatureMesh body.
##
## Other meshes in the GLB are rigid, on a socket: "shield_<socket>" is the Bulwark's door-shield
## (node Kin_shield_<socket>, which bulwark.gd looks up and breaks off).
## Load by path (no class_name): const GruntModel := preload("res://core/enemy/grunt_model.gd")

const SHADER := preload("res://core/enemy/grunt_pbr.gdshader")
const GruntSkin := preload("res://core/enemy/grunt_skin.gd")
const SHADOWED := ["chest", "pelvis", "head", "body", "front"]

## kind -> [glb, shader params]
const KINDS := {
	&"wretch": ["res://art/models/grunt_wretch.glb", {"rim_amount": 0.14}],
	&"husk": ["res://art/models/grunt_husk.glb", {"emit_pulse": 0.35, "pulse_rate": 1.4}],
	&"spitter": ["res://art/models/grunt_spitter.glb", {"emit_pulse": 0.45, "pulse_rate": 3.0, "membrane": 0.6}],
	&"ossuant": ["res://art/models/grunt_ossuant.glb", {}],
	&"bulwark": ["res://art/models/grunt_bulwark.glb", {}],
	&"chanter": ["res://art/models/grunt_chanter.glb", {"emit_pulse": 0.2, "pulse_rate": 1.1}],
	&"crawler": ["res://art/models/grunt_crawler.glb", {}],
	&"leaper": ["res://art/models/grunt_leaper.glb", {"emit_pulse": 0.25, "pulse_rate": 1.8}],
	&"burrower": ["res://art/models/grunt_burrower.glb", {"emit_pulse": 0.3, "pulse_rate": 1.2}],
	&"mite": ["res://art/models/grunt_mite.glb", {"emit_pulse": 0.4, "pulse_rate": 2.6, "membrane": 0.5}],
}

static var _scenes := {}
static var _mats := {}


static func has(kind: StringName) -> bool:
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
		for t: String in ["shield", "staff"]:
			if nm.begins_with(t + "_"):
				tag = t
				sock = nm.substr(t.length() + 1)
		var at := rig.socket(sock)
		if at == null:
			push_error("GruntModel: %s part '%s' has no socket" % [kind, nm])
			continue
		var mi := MeshInstance3D.new()
		mi.name = {"shield": "Kin_shield_", "staff": "Kin_glow_"}.get(tag, "Flesh_") + sock
		mi.mesh = mi0.mesh
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

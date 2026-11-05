class_name DefaultLoadout
extends RefCounted
## The wanderer's starting gear: robe layers on the procedural skeleton, all generated
## (core/player/wanderer_gen.gd, cached) -- a long split-front coat over an under-tunic, a dagged
## shoulder mantle, a deep hood with its tail, sleeves with bell cuffs, belt and baldric with a
## satchel, gloves, boots and wrapped legs. The right hand holds the staff, the left the lantern.
## CharacterRig bakes all of it into one skinned mesh (wanderer_body.gd) unless use_legacy is on.
## legacy() is the previous glb loadout (robe_*.glb, boot/gauntlet/staff glbs), kept for A/B renders.

const WPiece := preload("res://core/player/wanderer_piece.gd")
const WStaff := preload("res://core/player/wanderer_staff.gd")
const WLantern := preload("res://core/player/wanderer_lantern.gd")

## true: build the old glb robe instead (for comparisons; zz/move_char_shot -- --legacy).
static var use_legacy := false


static func entries() -> Array[Dictionary]:
	if use_legacy:
		return legacy()
	var out: Array[Dictionary] = []
	out.append(_e("chest", "coat", _gen("coat", Vector4(0.28, 1.42, 1.0, 1.0), "Torso")))
	out.append(_e("chest", "mantle", _gen("mantle", Vector4(0.31, 0.36, 0.0, 0.55))))
	out.append(_e("chest", "gear", _gen("gear")))
	out.append(_e("head", "hood", _gen("hood", Vector4(0.26, 0.4, 0.0, 0.35))))
	out.append(_e("hood_peak", "peak", _gen("tail", Vector4(0.1, 0.3, 0.0, 0.5))))
	for side in ["l", "r"]:
		out.append(_e("shoulder_" + side, "sleeve_" + side, _gen("sleeve", Vector4(0.05, 0.36, 0.0, 0.25))))
		out.append(_e("elbow_" + side, "bracer_" + side, _gen("bell", Vector4(0.0, 0.28, 0.0, 0.45))))
		out.append(_e("hip_" + side, "thigh_" + side, _gen("thigh")))
		out.append(_e("knee_" + side, "shin_" + side, _gen("shin")))
		out.append(_e("foot_" + side, "boot_" + side, _gen("boot")))
	out.append(_e("hand_l", "hand_l", _gen("glove_l")))
	var grip := _gen("glove_r")
	out.append(_e("hand_r", "hand_r", grip))
	var bag := _gen("satchel")
	bag.offset = Vector3(-0.27, -0.12, 0.03)
	out.append(_e("pelvis", "satchel", bag))
	out.append(_e("hand_r", "weapon_main", WStaff.new()))
	var lantern := WLantern.new()
	lantern.offset = Vector3(0.05, -0.12, -0.05)
	out.append(_e("hand_l", "lantern", lantern))
	return out


static func _gen(part: String, wave := Vector4(0.28, 1.42, 1.0, 1.0), mesh_name := "") -> EquipmentPiece:
	var p := WPiece.new()
	p.part = part
	p.wave = wave
	p.mesh_name = mesh_name
	return p


static func legacy() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_e("chest", "coat", _mesh("res://art/models/robe_torso.glb")))
	out.append(_e("head", "hood", _mesh("res://art/models/robe_hood.glb")))
	out.append(_e("hood_peak", "peak", _mesh("res://art/models/robe_peak.glb")))
	var sleeve := _mesh("res://art/models/robe_sleeve.glb")
	var bracer := _mesh("res://art/models/robe_bracer.glb")
	out.append(_e("shoulder_r", "sleeve_r", sleeve))
	out.append(_e("shoulder_l", "sleeve_l", sleeve))
	out.append(_e("elbow_r", "bracer_r", bracer))
	out.append(_e("elbow_l", "bracer_l", bracer))
	for side in ["l", "r"]:
		var boot := BootPiece.new()
		boot.offset = Vector3(0.0, 0.02, -0.02)
		out.append(_e("foot_" + side, "boot_" + side, boot))
		out.append(_e("hand_" + side, "hand_" + side, GauntletPiece.new()))
	var staff := StaffPiece.new()
	out.append(_e("hand_r", "weapon_main", staff))
	var lantern := LanternPiece.new()
	lantern.offset = Vector3(0.05, -0.12, -0.05)
	lantern.rotation_deg = Vector3(18.0, 0.0, -12.0)
	out.append(_e("hand_l", "lantern", lantern))
	return out


static func _mesh(path: String) -> MeshPiece:
	if path == "" or not ResourceLoader.exists(path):
		push_error("DefaultLoadout missing %s" % path)
	var p := MeshPiece.new()
	p.scene_path = path
	return p


static func _e(socket: String, key: String, piece: EquipmentPiece) -> Dictionary:
	return {"socket": socket, "key": key, "piece": piece}

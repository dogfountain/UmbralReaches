class_name DefaultLoadout
extends RefCounted
## The wanderer's starting gear. The body is the robe pieces on the procedural skeleton.
## The right hand holds the staff. The lantern hangs at the hip.


static func entries() -> Array[Dictionary]:
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
	lantern.offset = Vector3(-0.55, -0.15, -0.05)
	out.append(_e("pelvis", "lantern", lantern))
	return out


static func _mesh(path: String) -> MeshPiece:
	if path == "" or not ResourceLoader.exists(path):
		push_error("DefaultLoadout missing %s" % path)
	var p := MeshPiece.new()
	p.scene_path = path
	return p


static func _e(socket: String, key: String, piece: EquipmentPiece) -> Dictionary:
	return {"socket": socket, "key": key, "piece": piece}

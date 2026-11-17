extends Node
## THE DOOR AND THE ROOM (night life). Two jobs:
##   THE DOOR     the camera's being inside a registered room (Interiors.at) eases a registry term, `indoor` (0..1, about a third of
##                a second either way), that every outdoor term of the night reads: the mist banks, the puddle glints, the drips, the
##                moths' glow, the ground pools and the lent lights fade out as the wanderer steps in and back in as he steps out, so
##                the threshold is a dissolve and not a pop. (The weather's own warm ambient and thin fog ease at the same door.)
##   THE ROOMS    every room the world has registered is checked once the Realm is up (and again after half a minute, for the
##                areas that stream in) for a light inside its box; a room that has none is given a warm hearth glow (a flickering omni,
##                through Interiors.light, so the director budgets and fades it like the others): no enterable room is left dark.
## Cost: one Interiors.at test a frame (a loop over the registered rooms, a handful of transforms); the audit is two passes over the
## scene's lights, at 4 s and 34 s after start.
const Reg := preload("res://core/world/night_life/night_registry.gd")

var _t := 0.0
var _audits := 0
var _filled := {}                              ## room id -> true: a fill was made


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null and Reg.enabled:
		var want := 1.0 if Interiors.at(cam.global_position) > 0.0 else 0.0
		Reg.indoor = lerpf(Reg.indoor, want, 1.0 - exp(-4.0 * delta))
	else:
		Reg.indoor = lerpf(Reg.indoor, 0.0, 1.0 - exp(-4.0 * delta))
	if (_audits == 0 and _t > 4.0) or (_audits == 1 and _t > 34.0):
		_audits += 1
		_audit()


func _audit() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lights: Array[Node] = root.find_children("*", "OmniLight3D", true, false)
	lights.append_array(root.find_children("*", "SpotLight3D", true, false))
	var rooms: Dictionary = Interiors.rooms()
	for id: String in rooms:
		if _filled.has(id):
			continue
		var r: Dictionary = rooms[id]
		var inv: Transform3D = r.inv
		var half: Vector3 = r.half
		var found := false
		for n: Node in lights:
			var l := n as Light3D
			if l == null or not l.is_inside_tree() or (l.get_parent() != null and String(l.get_parent().name) == "Player"):
				continue
			var p: Vector3 = inv * l.global_position
			if absf(p.x) <= half.x + 0.5 and absf(p.y) <= half.y + 1.0 and absf(p.z) <= half.z + 0.5:
				found = true
				break
		if found:
			continue
		_filled[id] = true
		var centre := inv.affine_inverse().origin
		var host := root as Node3D              # the night's own scene; under a test harness, the nearest 3D ancestor
		var up: Node = get_parent()
		while host == null and up != null:
			host = up as Node3D
			up = up.get_parent()
		if host == null:
			return
		Interiors.light(host, "RoomFill_" + id, centre + Vector3(0.0, half.y * 0.5, 0.0), Interiors.FIRE.lerp(Interiors.CANDLE, 0.4), 1.5, maxf(half.x, half.z) * 1.7, false, 0.07)

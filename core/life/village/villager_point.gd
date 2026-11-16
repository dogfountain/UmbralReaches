extends RefCounted
## A villager points the wanderer the way. The guide (core/story/guide.gd) sets `point_at` (a world point) and
## `point_t` (seconds) on one who calls out where the next step is: the body turns to stand between the wanderer and
## the place, the free arm goes out toward it, the head follows, all eased in and out; then the old facing comes back.
## A walker only calls out (no pointing on the move). Kept out of villager.gd (its size ratchet): one call in _pose.
## Load by path (no class_name): const Point := preload("res://core/life/village/villager_point.gd")

const LEN := 3.2                         ## the guide's point_t: ease in over the first 0.5 s, out over the last 0.6 s


## Pose the pointing over the rig `r` (already posed this frame); returns where the head should look.
static func pose(v: Node3D, r, k: float, look: Vector3, dt: float, tool_r: String, tool_l: String) -> Vector3:
	var t: float = v.get("point_t")
	if t <= 0.0:
		return look
	t -= dt
	v.set("point_t", t)
	var at: Vector3 = v.get("point_at")
	if t <= 0.0 or at == Vector3.INF or String(v.get("state")) == "walk" or v.get("attend") != null:
		if v.has_meta(&"point_yaw"):
			v.set("face_yaw", float(v.get_meta(&"point_yaw")))
			v.remove_meta(&"point_yaw")
		return look
	if not v.has_meta(&"point_yaw"):
		# turn to stand between the one asking and the place: half toward each
		v.set_meta(&"point_yaw", float(v.get("face_yaw")))
		var p := v.get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var to_place := _yaw(v, at)
		v.set("face_yaw", lerp_angle(_yaw(v, p.global_position), to_place, 0.65) if p else to_place)
	var right := tool_r in ["", "chalk"]
	if not right and tool_l != "":
		return at                            # both hands full: a nod and a look will do
	var e := smoothstep(LEN, LEN - 0.5, t) * smoothstep(0.0, 0.6, t)
	var rig := v.get("rig") as Node3D
	var side := 1.0 if right else -1.0
	var sh := Vector3(0.17 * side, 1.34, -0.02) * k
	var d := rig.global_transform.affine_inverse() * at - sh
	d.y = clampf(d.y, -0.25 * d.length(), 0.45 * d.length())        # out and a little up, never straight at the ground
	d.z = minf(d.z, 0.15 * d.length())                              # in front: a point over the shoulder reads as a shrug
	d = d.normalized()
	var rest := Vector3(0.21 * side, 0.86, -0.06) * k
	var hand := sh + d * 0.58 * k
	r.arm_to("r" if right else "l", rest.lerp(hand, e), Vector3(0.9 * side, -0.5, 0.2), null)
	return at if e > 0.3 else look


static func _yaw(v: Node3D, p: Vector3) -> float:
	var d := p - v.global_position
	return atan2(-d.x, -d.z)

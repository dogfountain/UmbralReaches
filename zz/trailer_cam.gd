extends RefCounted
## Camera grammar shared by the trailer's shot files. `d` is the director (zz/trailer.gd); every move ends in
## d.frame_cam / d.hold_cam, which collision-check and ease the lens. All moves are pure functions of the shot clock.

var d


func _init(director: Object) -> void:
	d = director


## Direction (world, flat) -> the yaw the Player faces.
static func yaw_dir(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


static func flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD


## A trailing vista: the lens rides behind and above the wanderer, drifts sideways and rises over the shot, and looks
## from the wanderer's shoulder toward `look`. k is the shot's eased progress 0..1.
func vista(look: Vector3, k: float, back: float, h: float, lat: float, rise: float, weight := 0.75) -> void:
	var me: Vector3 = d.pp()
	var dir := flat(look - me)
	var side := dir.cross(Vector3.UP)
	var from := me - dir * back + side * lat * (k * 2.0 - 1.0) + Vector3.UP * (h + rise * k)
	var at := (me + Vector3.UP * 1.4).lerp(look, weight)
	d.frame_cam(from, at)


## A slow orbit around `c`: radius r0 -> r1, angle a0 -> a1 (radians), height h0 -> h1 above c.
func orbit(c: Vector3, k: float, r0: float, r1: float, a0: float, a1: float, h0: float, h1: float, look_up := 1.0) -> void:
	var a := lerpf(a0, a1, k)
	var r := lerpf(r0, r1, k)
	d.frame_cam(c + Vector3(sin(a) * r, lerpf(h0, h1, k), cos(a) * r), c + Vector3.UP * look_up)


## A straight dolly from `a` to `b` while looking at `at`.
func dolly(a: Vector3, b: Vector3, at: Vector3, k: float) -> void:
	d.frame_cam(a.lerp(b, k), at)

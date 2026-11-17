extends RefCounted
## What stands between the listener and a sound (the open moor against the other side of a hill or a wall). One ray from the camera
## to the emitter per one-shot, on the world layer only, at most six a physics frame; a sound whose ray is stopped well short of it
## is turned down and darkened (Sfx applies both). No class_name. Load by path: const Occlusion := preload("res://core/audio/occlusion.gd")

const NEAR := 6.0                 ## closer than this nothing is occluded
const BUDGET := 6
static var _frame := -1
static var _left := 0


## How many dB a sound at `at` loses to what is between it and the camera (0 when the way is open or the budget is spent).
static func db(cam: Camera3D, at: Vector3) -> float:
	if cam == null or not cam.is_inside_tree():
		return 0.0
	var from := cam.global_position
	var d := from.distance_to(at)
	if d < NEAR:
		return 0.0
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_left = BUDGET
	if _left <= 0:
		return 0.0
	_left -= 1
	var w := cam.get_world_3d()
	if w == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(from, at + Vector3.UP * 0.8, Layers.WORLD)
	var hit := w.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	var hp: Vector3 = hit.position
	if hp.distance_to(at) < 1.5 or hp.distance_to(from) < 1.5:
		return 0.0                       # the emitter's own ground, or the camera's
	return clampf(3.0 + (d - NEAR) * 0.07, 3.0, 7.0)

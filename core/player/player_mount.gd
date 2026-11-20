class_name PlayerMount
extends Node
## Riding: while the wanderer sits a horse (core/world/mount/horse.gd) the horse takes the wish.
## Part of Player (core/player/player.gd): `riding` and `_visual.ride` stay where the horse and the
## rig already look for them.

const HorseScript := preload("res://core/world/mount/horse.gd")

var player: Player
var _cam_w := 0.0                      ## 0..1: how much the camera follows the horse's own motion instead of the seat's
var _cam_y := 0.0                      ## the horse's height as the camera takes it (damped)
var _cam_at := Vector3.ZERO            ## where the camera was following: held while it lets go after the rider is down


func _init(p: Player) -> void:
	player = p


## Off the horse (a hollow, a fall out of the world, the interact key): the horse stays where it is.
func get_down(animated := false) -> void:
	if player.riding != null and is_instance_valid(player.riding):
		(player.riding as HorseScript).dismount(animated)


## One physics tick on horseback. Returns true when the horse drove the tick (Player skips its
## own movement); false when the wanderer is on foot or was just unseated.
func ride_tick(wish: Vector3, sprint: bool, delta: float) -> bool:
	var horse := player.riding
	if horse == null:
		return false
	if not is_instance_valid(horse) or player._hollowing:
		player.riding = null
		return false
	if Input.is_action_just_pressed("jump"):
		(horse as HorseScript).try_jump()             # the jump key leaps the horse; [interact] gets down
	(horse as HorseScript).drive(player, wish, sprint, delta)
	player._grounded = true
	player._visual.ride = lerpf(player._visual.ride, 1.0, 1.0 - exp(-8.0 * delta))
	if player._visual.ride > 0.995:
		player._visual.ride = 1.0
	player._visual.animate(Vector3.ZERO, true, delta)
	player._tick_always(delta)
	return true


## The camera's pivot (the Player's interpolated body origin `body`, or the horse's own motion while ridden). The seat
## bounces with the gait and the rider's spring, and a camera bolted to it bobbed; the horse's interpolated root is
## smooth. The height takes a light low-pass (a leap or a kerb is felt, not jerked); the blend in and out is 0.3 s,
## so getting on and getting down move the view across, not cut it.
func camera_origin(body: Vector3, delta: float) -> Vector3:
	var h := player.riding as HorseScript
	var on := h != null and is_instance_valid(h) and h.camera_ready()
	if on:
		var a := h.camera_anchor()
		if _cam_w <= 0.0:
			_cam_y = a.y
		_cam_y = lerpf(_cam_y, a.y, 1.0 - exp(-9.0 * delta))
		_cam_at = Vector3(a.x, _cam_y, a.z)
	_cam_w = move_toward(_cam_w, 1.0 if on else 0.0, delta * (4.0 if on else 3.5))
	if _cam_w <= 0.0:
		return body
	return body.lerp(_cam_at, smoothstep(0.0, 1.0, _cam_w))

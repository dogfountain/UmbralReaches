class_name PlayerMount
extends Node
## Riding: while the wanderer sits a horse (core/world/mount/horse.gd) the horse takes the wish.
## Part of Player (core/player/player.gd): `riding` and `_visual.ride` stay where the horse and the
## rig already look for them.

var player: Player


func _init(p: Player) -> void:
	player = p


## One physics tick on horseback. Returns true when the horse drove the tick (Player skips its
## own movement); false when the wanderer is on foot, was just unseated, or jumped down.
func ride_tick(wish: Vector3, sprint: bool, delta: float) -> bool:
	var horse := player.riding
	if horse == null:
		return false
	if not is_instance_valid(horse) or player._hollowing:
		player.riding = null
		return false
	if Input.is_action_just_pressed("jump"):
		horse.call("dismount")
		return false
	horse.call("drive", player, wish, sprint, delta)
	player._grounded = true
	player._visual.ride = move_toward(player._visual.ride, 1.0, delta * 4.0)
	player._visual.animate(Vector3.ZERO, true, delta)
	player.vitals._update_gloom(delta)
	return true

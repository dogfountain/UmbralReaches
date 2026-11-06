class_name PlayerMount
extends Node
## Riding: while the wanderer sits a horse (core/world/mount/horse.gd) the horse takes the wish.
## Part of Player (core/player/player.gd): `riding` and `_visual.ride` stay where the horse and the
## rig already look for them.

const HorseScript := preload("res://core/world/mount/horse.gd")

var player: Player


func _init(p: Player) -> void:
	player = p


## Off the horse (a hollow, a fall out of the world, the interact key): the horse stays where it is.
func get_down() -> void:
	if player.riding != null and is_instance_valid(player.riding):
		player.riding.call("dismount")


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
	horse.call("drive", player, wish, sprint, delta)
	player._grounded = true
	player._visual.ride = lerpf(player._visual.ride, 1.0, 1.0 - exp(-8.0 * delta))
	if player._visual.ride > 0.995:
		player._visual.ride = 1.0
	player._visual.animate(Vector3.ZERO, true, delta)
	player.vitals._update_gloom(delta)
	return true

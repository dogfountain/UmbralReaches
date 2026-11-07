extends OmniLight3D
## A light carried by an enemy shot. It eases down to a fifth near the player (their lantern pool already
## lights that ground) so it never washes the screen, and is full in the dark.

const NEAR := 2.0
const FAR := 6.0

var base_energy := 1.0
var _p: Node3D


func _process(_delta: float) -> void:
	if _p == null or not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if _p == null:
			return
	var d := global_position.distance_to(_p.global_position)
	light_energy = base_energy * lerpf(0.2, 1.0, clampf((d - NEAR) / (FAR - NEAR), 0.0, 1.0))

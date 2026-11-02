class_name Interactable
extends Node3D
## Something the wanderer can use with E. Add to Groups.INTERACTABLE in _ready.

func can_interact() -> bool:
	return false


func interact_text() -> String:
	return ""


func interact(_by: Node) -> void:
	pass


## Override to use a wider reach than the player's default. <= 0 means use the player range.
func interact_reach() -> float:
	return -1.0

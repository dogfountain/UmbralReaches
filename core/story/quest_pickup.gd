extends Interactable
## Something a task wants found, read, taken or put back (story; no class_name). quest_world.gd
## places one per active pickup in quest_chains.gd PICKUPS and removes it when the step moves on.
## Interacting hands the key back to the world side (`world.take(key)`).

var key := ""
var world: Node
var label := ""
var verb := "Take"
var live := true                  ## false: only shown (the lantern under the hollowed man)


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	add_to_group("quest_pickup")


func can_interact() -> bool:
	return live and world != null


func interact_text() -> String:
	return "[%s]  %s %s" % [Interactable.prompt_key(), verb, label]


func interact_reach() -> float:
	return 1.9


func interact_feel() -> StringName:
	return &"use"


func interact(_by: Node) -> void:
	if can_interact():
		world.call("take", key)

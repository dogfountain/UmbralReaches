extends Interactable
## The seat by every lit fire: "Make camp". One CampSpot stands a couple of metres from each kindled brazier (laid by the
## Kindling runtime beside the fire's own spot, core/life/progression/kindling.gd). Use it and the wanderer sits to the fire:
## the camp rite (core/world/camp_rite.gd). Load by path (no class_name).

const Days := preload("res://core/story/days.gd")
const OFFSET := Vector3(1.9, 0.0, -1.5)      ## from the fire, on the side away from the ember post and the respawn spot

var brazier: Node3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func interact_reach() -> float:
	return 1.5


func can_interact() -> bool:
	return brazier is Brazier and (brazier as Brazier).lit and not CampRite.running(get_tree())


func interact_text() -> String:
	var k := Interactable.prompt_key()
	return "[%s]  Make camp%s" % [k, "  ·  the night turns" if Days.due() else ""]


func interact_feel() -> StringName:
	return &"use"


func interact(by: Node) -> void:
	if brazier is Brazier:
		CampRite.begin(brazier as Brazier, by as Player)

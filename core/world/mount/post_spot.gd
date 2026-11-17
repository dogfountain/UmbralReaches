extends Interactable
## The rail of a hitching post as something to use: "Tend the stable". Opens the stable panel (ui/horse_panel.gd) for the
## breed kept at this post: care (feed, groom), tack, saddlebags and the courier board. Always available; a horse not yet bought
## shows what it is and what it costs. Load by path (no class_name).

const HorsePanel := preload("res://ui/horse_panel.gd")

var breed := ""


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func interact_reach() -> float:
	return 1.8


func can_interact() -> bool:
	return breed != ""


func interact_text() -> String:
	return "[%s]  Tend the stable" % Interactable.prompt_key()


func interact_feel() -> StringName:
	return &"use"


func interact(_by: Node) -> void:
	var p := get_tree().get_first_node_in_group(&"horse_panel") as HorsePanel
	if p != null:
		p.open_for(breed)

extends Interactable
## The one prompt at a kindled brazier (progression): "Rest · Kindling" when the fire is not yet the
## wanderer's checkpoint (the press rests there, then opens the Kindling), "Tend the fire · Kindling"
## once it is. The brazier itself only speaks while unlit ("Kindle the brazier"). Relics swap in the
## satchel (sheets 117, 118).

var brazier: Node3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func can_interact() -> bool:
	return brazier is Brazier and (brazier as Brazier).lit


func interact_text() -> String:
	var rest := brazier is Brazier and not (brazier as Brazier).is_checkpoint()
	return "[%s]  %s  ·  Kindling" % [Interactable.prompt_key(), "Rest" if rest else "Tend the fire"]


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	if brazier is Brazier and not (brazier as Brazier).is_checkpoint():
		(brazier as Brazier).remember(by)       # resting here moves the checkpoint (sheet 117)
	var g := get_tree().get_first_node_in_group("growth")
	if g:
		g.call("open_menu", true)

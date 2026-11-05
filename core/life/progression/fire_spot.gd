extends Interactable
## "Tend the fire" at a kindled brazier (progression): opens the Kindling. It only offers itself
## while the brazier has nothing of its own to say once lit (no relics yet); with relics the
## brazier's own "Attune" opens the Satchel in attune mode, which hands over to the Kindling too
## (ui/satchel.gd hook), so either way a lit fire is where ash is spent.

var brazier: Node3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func can_interact() -> bool:
	return is_instance_valid(brazier) and bool(brazier.get("lit")) and not brazier.call("can_interact")


func interact_text() -> String:
	return "[%s]  Tend the fire  ·  Kindling" % Interactable.prompt_key()


func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	var g := get_tree().get_first_node_in_group("growth")
	if g:
		g.call("open_menu", true)

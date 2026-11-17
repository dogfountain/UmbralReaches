extends RefCounted
## Whether a menu may open now. While the wanderer is hollowing (the 0.9 s before the respawn, core/player/
## player_vitals.gd hollow()) none does: the respawn's timer does not wait for a window, and the screen opening
## on it paused the world over a teleport. Preload it (`const MenuGate := preload("res://ui/menu_gate.gd")`).


static func blocked(node: Node) -> bool:
	var p := node.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return p != null and p.is_hollowing()

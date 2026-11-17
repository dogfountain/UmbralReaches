extends RefCounted
## The Ember Road from the world map. At a lit fire (the ember-post beside it) the road already listed the other fires
## (core/world/fire_road.gd); now the map does it too: open the map while you stand by a lit fire, and every other lit
## fire on the sheet answers a click (or the pad's confirm) by carrying you there. The rules are the road's own: never
## in a boss's fight, never with a foe awake nearby; the fire you land at becomes your checkpoint.
## Load by path (no class_name): const MapTravel := preload("res://ui/world_map_travel.gd")

const FireRoad := preload("res://core/world/fire_road.gd")
const REACH := 9.0                          ## how near a lit fire the wanderer must stand to take the road from the map


## The lit fire the wanderer stands by (the road's starting stop), or null.
static func origin(tree: SceneTree) -> Brazier:
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return null
	var best: Brazier = null
	var bd := REACH * REACH
	for n in tree.get_nodes_in_group(Groups.BRAZIER):
		var b := n as Brazier
		if b == null or not b.lit or not b.is_inside_tree():
			continue
		var d := b.global_position.distance_squared_to(p.global_position)
		if d < bd:
			bd = d
			best = b
	return best


## The tooltip's note for a lit fire on the sheet.
static func note(tree: SceneTree, b: Brazier) -> String:
	var o := origin(tree)
	if o == null:
		return "A lit fire: a stop on the Ember Road (take it from beside a lit fire)"
	if o == b:
		return "The fire you stand by"
	return "Click to ride the Ember Road here, from %s" % o.display_name()


## A click (or confirm) on mark `m` of the map: a lit fire other than this one carries the wanderer. True when it acted.
static func click(map: Node, m: Dictionary) -> bool:
	var f: Variant = m.get("fire")
	if not (f is Brazier) or not is_instance_valid(f):
		return false
	var dest := f as Brazier
	if not dest.lit:
		return false
	var tree := map.get_tree()
	var from := origin(tree)
	if from == null:
		Events.toast.emit("Stand beside a lit fire to take the Ember Road from the map.")
		return true
	if from == dest:
		return true
	map.close()
	FireRoad.travel(from, dest)
	return true


## The hitching posts as pins (kind "horse"): where each breed is sold. They are known from the first night (the
## villagers say where the stables are), so fog does not hide them.
static func posts(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in tree.get_nodes_in_group(&"hitching_post"):
		var p := n as Node3D
		if p != null and p.is_inside_tree():
			out.append({"at": Vector2(p.global_position.x, p.global_position.z), "kind": "horse",
				"name": String(p.get_meta(&"map_label", "A hitching post")), "note": "Horses are kept here, for grave ash"})
	return out

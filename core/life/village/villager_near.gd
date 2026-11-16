extends RefCounted
## The villagers that can be near a point, for the scans a villager makes as it walks (villager.gd: who blocks the
## way, whom to step apart from, who walks past): the group is every villager in the Realm (~60 with the Far
## Reaches' towns and the roads' parties), and each scan walked all of it, every step of every walker. Their places
## are taken once a frame; `near()` gives those that stood within reach, plus MARGIN (far more than a villager walks
## in a frame), in the group's own order, and the caller tests each one live as before: the same one is found
## first and the same pushes add up. One per scene (its meta), freed with it. Load by path (no class_name).

const MARGIN := 1.0

var _frame := -1
var _nodes: Array = []
var _pos := PackedVector3Array()


## The scene's (made on first use).
static func of(tree: SceneTree) -> RefCounted:
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	var vn: Variant = host.get_meta(&"villager_near") if host.has_meta(&"villager_near") else null
	if vn == null:
		vn = (load("res://core/life/village/villager_near.gd") as GDScript).new()
		host.set_meta(&"villager_near", vn)
	return vn


## The villagers whose place this frame was within `r` (flat) of `at`, plus MARGIN, in the group's order.
func near(tree: SceneTree, at: Vector3, r: float) -> Array:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_nodes = tree.get_nodes_in_group(&"villager")
		_pos.resize(_nodes.size())
		for i in _nodes.size():
			var n := _nodes[i] as Node3D
			_pos[i] = n.global_position if n != null else Vector3(INF, INF, INF)
	var out: Array = []
	var rr := (r + MARGIN) * (r + MARGIN)
	for i in _pos.size():
		var d := _pos[i] - at
		if d.x * d.x + d.z * d.z <= rr:
			out.append(_nodes[i])
	return out

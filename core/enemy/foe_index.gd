extends RefCounted
## The foes that can be near a point, for the scans every awake foe makes each think (Enemy._update_separation).
## Every foe in the Realm is in Groups.ENEMY (~370 in the doubled Realm, nearly all asleep at their camps), and
## each awake one walked the whole group ten times a second: a fifth of all the foes' tick time in a fight.
## A foe that does not process (asleep, or its area switched off) does not move, so those sit in a grid of
## CELL metres; the processing ones (awake, dying, the great ones) are listed whole. `near()` gives every
## processing foe and every resting one within reach, as indices in the group's own order (`node(i)`), so a
## scan over them meets the same foes in the same order as the scan over the whole group did, and adds up
## to exactly the same. Rebuilt when a foe comes or goes, wakes or sleeps (Enemy bumps `epoch`), and every
## REFRESH_MS regardless (anything that moved a resting one by hand: the camps' settle on the final ground).
## One per scene (its meta), freed with it. Load by path (no class_name).

const CELL := 16.0
const MARGIN := 2.0                     ## metres added to a reach (a resting foe set down by hand since the build)
const REFRESH_MS := 2000

const TOUCH := [Node.NOTIFICATION_ENTER_TREE, Node.NOTIFICATION_EXIT_TREE, Node.NOTIFICATION_ENABLED, Node.NOTIFICATION_DISABLED,
	Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_UNPAUSED]    ## the notifications on which Enemy bumps `epoch`
static var epoch := 0                   ## a counter Enemy bumps; the index rebuilds when it moved (nothing to reset)

var _built := -1
var _built_n := -1                      ## the group's size at the build (a foe put in or taken out by hand)
var _built_ms := -100000
var _nodes: Array = []                  ## the group as it was at the build (indices below point here)
var _dyn := PackedInt32Array()          ## processing foes
var _grid := {}                         ## Vector2i cell -> PackedInt32Array of resting foes


## The scene's index (made on first use).
static func of(tree: SceneTree) -> RefCounted:
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	var fi: Variant = host.get_meta(&"foe_index") if host.has_meta(&"foe_index") else null
	if fi == null:
		fi = (load("res://core/enemy/foe_index.gd") as GDScript).new()
		host.set_meta(&"foe_index", fi)
	return fi


## Indices (ascending: the group's order) of every processing foe and of every resting foe within `r` of `at`
## (flat distance; a superset: the caller still measures each one, and skips one no longer in the group).
func near(tree: SceneTree, at: Vector3, r: float) -> PackedInt32Array:
	if _built != epoch or tree.get_node_count_in_group(Groups.ENEMY) != _built_n or Time.get_ticks_msec() - _built_ms > REFRESH_MS:
		_build(tree)
	var out := _dyn.duplicate()
	var rr := r + MARGIN
	for cx in range(floori((at.x - rr) / CELL), floori((at.x + rr) / CELL) + 1):
		for cz in range(floori((at.z - rr) / CELL), floori((at.z + rr) / CELL) + 1):
			var cell: Variant = _grid.get(Vector2i(cx, cz))
			if cell != null:
				out.append_array(cell)
	out.sort()
	return out


func node(i: int) -> Node:
	return _nodes[i]


func _build(tree: SceneTree) -> void:
	_built = epoch
	_built_ms = Time.get_ticks_msec()
	_nodes = tree.get_nodes_in_group(Groups.ENEMY)
	_built_n = _nodes.size()
	_dyn.clear()
	_grid.clear()
	for i in _nodes.size():
		var n := _nodes[i] as Node3D
		if n == null or n.can_process():
			_dyn.append(i)
			continue
		var p := n.global_position
		var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		var cell: PackedInt32Array = _grid.get(c, PackedInt32Array())
		cell.append(i)
		_grid[c] = cell


## The foes that can be within `r` of `at`, as nodes (still in the group, valid), in the group's order: every processing
## foe and the resting ones near. A superset: the caller measures each. For the scans that walked the whole group a tick
## (the horse's shoulder, the head's look, Breath's fight check, the music's sense, the HUD's lesson, the wildlife's).
static func around(tree: SceneTree, at: Vector3, r: float) -> Array[Node3D]:
	var fi: Variant = of(tree)
	var out: Array[Node3D] = []
	for i: int in fi.near(tree, at, r):
		var n: Variant = fi.node(i)
		if is_instance_valid(n) and n is Node3D and (n as Node).is_in_group(Groups.ENEMY):
			out.append(n as Node3D)
	return out

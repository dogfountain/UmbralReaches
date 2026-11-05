extends Node
var p: Player
var t := 0
var leg := 0
var leg_t := 0.0
var route: Array[Vector3] = [
	Vector3(0.5, 12.6, -34), Vector3(7.5, 12.6, -34),            # onto the bridge (walk)
	Vector3(13.6, 12.6, -34), Vector3(17.0, 12.6, -34),           # (teleported over the gap) to the door
	Vector3(20.0, 12.6, -34), Vector3(23.0, 12.6, -36.5),         # into the hall, to the north door
	Vector3(23.0, 12.6, -38.6), Vector3(23.0, 8.4, -49.5),        # down stair 1
	Vector3(23.0, 8.4, -52.0), Vector3(20.0, 8.4, -58.0),         # gallery west aisle
	Vector3(20.0, 8.4, -65.5), Vector3(21.0, 8.4, -67.5),         # to the north door
	Vector3(21.0, 4.2, -78.0), Vector3(20.5, 4.2, -80.0),         # down stair 2 to the pit landing
	Vector3(18.5, 4.2, -84.0), Vector3(19.0, 4.2, -92.0),         # across the widened pit (round the mound)
	Vector3(16.0, 4.2, -97.5), Vector3(16.0, 4.2, -103.5),        # into the chapel
]
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t < 20:
		return
	if t == 20:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		p.global_position = Vector3(0.0, 12.7, -34.0)
		p.reset_physics_interpolation()
	if leg >= route.size():
		print("WALK DONE all legs ok, end=", p.global_position)
		get_tree().quit()
		return
	var goal := route[leg]
	if leg == 2 and leg_t == 0.0:
		p.global_position = Vector3(13.5, 12.7, -34.0)   # the gap is a Rift Step; tested separately
		p.reset_physics_interpolation()
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.6:
		print("LEG ", leg, " reached ", goal, " in ", snappedf(leg_t, 0.01), "s y=", snappedf(p.global_position.y, 0.01))
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 8.0:
		print("STUCK leg ", leg, " goal=", goal, " at ", p.global_position)
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), true)

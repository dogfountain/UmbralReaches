extends Node
var p: Player
var t := 0
var leg := 0
var leg_t := 0.0
var route: Array[Vector3] = [Vector3(2.0, 0, -89.0), Vector3(12.8, 0, -89.0), Vector3(2.0, 0, -89.0)]
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t == 20:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		var lift := get_tree().root.find_child("ChainLift", true, false) as ChainLift
		lift._t = lift.dwell + lift.travel_time + 0.1     # parked at the top
		lift.set_physics_process(false)
		lift._place(1.0)
		p.global_position = Vector3(2.0, 27.5, -89.0)
		p.reset_physics_interpolation()
	if t < 30:
		return
	if leg >= route.size():
		print("LANEWALK ok end=", p.global_position)
		get_tree().quit()
		return
	var g := route[leg]
	var d := Vector2(g.x - p.global_position.x, g.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.5:
		print("LEG ", leg, " reached y=", snappedf(p.global_position.y, 0.01))
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 6.0:
		print("STUCK leg ", leg, " at ", p.global_position)
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)

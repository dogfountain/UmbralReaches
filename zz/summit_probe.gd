extends Node
var p: Player
var t := 0
var leg := 0
var leg_t := 0.0
var route: Array[Vector3] = [Vector3(0, 0, -66.0), Vector3(0, 0, -71.0), Vector3(0, 0, -76.0), Vector3(-2.8, 0, -79.5), Vector3(-3.6, 0, -83.5), Vector3(-2.6, 0, -87.0), Vector3(0, 0, -89.0), Vector3(0, 0, -92.0), Vector3(0, 0, -103.9), Vector3(-8.0, 0, -112.0), Vector3(9.0, 0, -110.0)]
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _down(x: float, z: float) -> String:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, 0, z), Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return "MISS" if h.is_empty() else "%.2f" % (h.position as Vector3).y
func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t == 20:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		var line := "PROFILE z=-89: "
		for i in 17:
			var x := 6.0 + 0.5 * float(i)
			line += "x%.1f=%s " % [x, _down(x, -89.0)]
		print(line)
		line = "PROFILE z=-83.5: "
		for i in 17:
			var x := 6.0 + 0.5 * float(i)
			line += "x%.1f=%s " % [x, _down(x, -83.5)]
		print(line)
		p.global_position = Vector3(0, 25.6, -64.5)
		p.reset_physics_interpolation()
	if t < 30:
		return
	if leg >= route.size():
		print("SUMMIT WALK ok end=", p.global_position)
		get_tree().quit()
		return
	var goal := route[leg]
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.6:
		print("LEG ", leg, " ", goal, " y=", snappedf(p.global_position.y, 0.01), " t=", snappedf(leg_t, 0.01))
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 7.0:
		print("STUCK leg ", leg, " at ", p.global_position)
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), true)

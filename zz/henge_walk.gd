extends Node
var p: Player
var t := 0
var leg := 0
var leg_t := 0.0
var route: Array[Vector3] = [
	Vector3(-6.0, 0, 18.0), Vector3(-18.5, 0, 22.5), Vector3(-20.0, 0, 22.0),   # henge way to the stair foot
	Vector3(-26.3, 0, 14.3), Vector3(-28.0, 0, 12.2), Vector3(-32.9, 0, 6.2),   # up the pilgrim stair
	Vector3(-36.0, 0, 2.5),                                                     # through the trilithon
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
		p.global_position = Vector3(-3.0, 0.5, 17.0)
		var c2 := Vector2(ThornHenge.C.x, ThornHenge.C.z)
		var tf := (ThornHenge.FOOT - c2).normalized()
		var hd := c2 + tf * ThornHenge.R
		var md := ThornHenge.FOOT.lerp(hd, 0.5)
		var inn := c2 + tf * (ThornHenge.R - 3.5)
		route = [Vector3(-6.0, 0, 18.0), Vector3(-18.5, 0, 22.5), Vector3(ThornHenge.FOOT.x, 0, ThornHenge.FOOT.y),
			Vector3(md.x, 0, md.y), Vector3(hd.x, 0, hd.y), Vector3(inn.x, 0, inn.y)]
		p.reset_physics_interpolation()
	if leg >= route.size():
		print("HENGEWALK DONE all legs ok, end=", p.global_position)
		get_tree().quit()
		return
	var goal := route[leg]
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.6:
		print("LEG ", leg, " reached ", goal, " in ", snappedf(leg_t, 0.01), "s y=", snappedf(p.global_position.y, 0.01))
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 14.0:
		print("STUCK leg ", leg, " goal=", goal, " at ", p.global_position)
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), true)

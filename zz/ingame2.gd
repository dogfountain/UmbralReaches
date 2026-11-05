extends Node
var p: Player
var f := 0
var i := 0
var views := [
	["terraces", Vector3(-20.0, 1.0, 30.0), 1.05, 0.05],
	["terraces_w", Vector3(-44.0, 8.5, 18.0), 0.6, -0.12],
	["terraces_e", Vector3(24.0, 3.0, 20.0), -2.2, -0.1],
	["henge_big", Vector3(-33.0, 8.2, 8.5), 0.82, -0.06],
	["tavern_big", Vector3(18.0, 0.5, 15.5), 2.85, -0.04],
	["crypt", Vector3(21.5, 4.8, -79.5), 0.55, -0.2],
	["summit_dais", Vector3(0.0, 27.9, -89.5), 0.0, -0.18],
	["summit_back", Vector3(3.0, 27.9, -114.0), PI, -0.05],
]
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	f += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if f == 8:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
	if i >= views.size():
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
		return
	var v: Array = views[i]
	if f % 14 == 10:
		p.global_position = v[1]
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.set_view(v[2], v[3])
	if f % 14 == 13 and v[0] == "satchel":
		var sat := _ui_satchel()
		if sat: sat.open_menu()
	if f % 14 == 0 and f > 14:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/ig_%s.png" % v[0]))
		print("SHOT ", v[0], " player=", p.global_position, " floor=", p.is_on_floor())
		var sat2 := _ui_satchel()
		if sat2 and sat2.is_open(): sat2.close_menu()
		i += 1



## The inventory screen (a CanvasLayer named Satchel), not the satchel bag on the wanderer's belt.
func _ui_satchel() -> Node:
	for n in get_tree().root.find_children("Satchel", "CanvasLayer", true, false):
		return n
	return null

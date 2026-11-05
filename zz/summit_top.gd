extends Node
## Top-down / oblique renders of the summit for planning and checking the dais.
## godot --path . res://zz/summit_top.tscn  ->  shots/summit_top.png, shots/summit_oblique.png
var f := 0
var cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	f += 1
	if f == 120:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		cam = Camera3D.new()
		get_tree().root.add_child(cam)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 44.0
		cam.far = 200.0
		cam.global_position = SummitDress.SUMMIT + Vector3(0, 40, -8)
		cam.look_at(SummitDress.SUMMIT + Vector3(0, 0, -8), Vector3.FORWARD)
		cam.current = true
	if f == 150:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/summit_top.png"))
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 60.0
		cam.global_position = SummitDress.SUMMIT + Vector3(22, 16, 14)
		cam.look_at(SummitDress.SUMMIT + Vector3(0, 2, -10))
	if f == 180:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/summit_oblique.png"))
		print("SUMMIT_TOP shots saved")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())

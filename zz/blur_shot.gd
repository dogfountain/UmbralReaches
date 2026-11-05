extends Node
## Motion blur check: a still frame, then frames mid-turn and mid-run.
##   godot --path . res://zz/blur_shot.tscn  ->  shots/blur_still.png, blur_turn.png, blur_run.png
var t := 0.0
var p: Player
var stage := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1600, 900)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _save(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/blur_%s.png" % n))
func _process(d: float) -> void:
	t += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t < 9.0:
		p.set_view(0.4, -0.08)
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
		return
	match stage:
		0:
			_save("still"); stage = 1
		1, 2, 3, 4, 5, 6, 7, 8:
			p.set_view(0.4 + 0.035 * float(stage), -0.08)    # a brisk mouse turn
			stage += 1
		9:
			_save("turn"); stage = 10; p.set_view(0.0, -0.08)
		_:
			p.debug_drive(Vector3(0, 0, -1), true)
			stage += 1
			if stage == 70:
				_save("run")
				print("BLUR_SHOT saved")
				get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())

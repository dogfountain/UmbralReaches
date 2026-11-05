extends Node
## The dialogue box and the objective lines in game (HUD on, grade on):
##   godot --path . res://zz/story_ui_shot.tscn  -> shots/story_ui_<n>.png
## Puts the wanderer at the bar facing the keep, talks to him (first meeting), screenshots the
## typed line, the choice menu, and the room after with the objectives. Story flags are set in
## memory only; exits with OS.kill so the real save is never written.
var t := 0.0
var step := 0
var story: Node
var p: Node3D
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	Travel.story = {}
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/story_ui_%s.png" % n))
	print("UI shot ", n)
func _process(d: float) -> void:
	t += d
	if story == null:
		story = get_tree().get_first_node_in_group("story")
		return
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	for e in get_tree().get_nodes_in_group(Groups.ENEMY): (e as Node).queue_free()
	match step:
		0:
			if t > 9.0:
				var keep := get_tree().get_first_node_in_group("keep") as Node3D
				keep.set("_goal_x", 15.4)
				keep.global_position.x = 15.4
				p.global_position = Vector3(15.6, -0.66, 31.5)
				p.set("_yaw", PI)
				story.set("_lit", {})
				step = 1
		1:
			if t > 10.5:
				story.talk("keep", get_tree().get_first_node_in_group("keep"), p)
				step = 2
		2:
			if t > 11.2:
				_shot("typing")
				step = 3
		3:
			if t > 13.5:
				story.ui.press()
				story.ui.press()
				story.ui.press()
				story.ui.finish_line()
				step = 4
		4:
			if t > 14.3:
				_shot("menu")
				story.ui.chosen.emit(2)
				story.ui.finish_line()
				step = 5
		5:
			if t > 15.0:
				_shot("answer")
				story.ui.press()
				story.ui.finish_line()
				step = 6
		6:
			if t > 15.5:
				story.ui.chosen.emit(1)
				story.ui.press()
				story.ui.press()
				step = 7
		7:
			if t > 17.5:
				_shot("after")
				OS.kill(OS.get_process_id())

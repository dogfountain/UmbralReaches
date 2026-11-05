extends Node
## In-game NPC renders with the colour grade ON (zz/spot_shot hides every CanvasLayer, the grade
## too): godot --path . res://zz/story_shot.tscn -- --at=x,y,z --look=x,y,z --name=n [--times=9,10]
##   [--keep=x] parks the keep at x (behind the counter) for the frames.
## Exits with OS.kill so nothing saves (the real save is never written by a render).
var t := 0.0
var cam: Camera3D
var at := Vector3.ZERO
var look := Vector3.FORWARD
var nm := "story"
var keep_x := INF
var times: Array[float] = [12.0]
var ti := 0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2: continue
		var p := v[1].split(",")
		match v[0]:
			"--at": at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--look": look = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--name": nm = v[1]
			"--keep": keep_x = float(v[1])
			"--times":
				times.clear()
				for x in p: times.append(float(x))
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if t > 8.0 and cam == null:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if String(c.name) != "Grade":
				(c as CanvasLayer).visible = false
		cam = Camera3D.new(); cam.fov = 60.0; cam.far = 400.0
		get_tree().root.add_child(cam); cam.current = true
		cam.global_position = at; cam.look_at(look)
	if cam != null and keep_x < INF:
		var k := get_tree().get_first_node_in_group("keep") as Node3D
		if k:
			k.set("_goal_x", keep_x)
			k.set("_task_len", 999.0)
	if cam != null and ti < times.size() and t > times[ti]:
		var suffix := "" if times.size() == 1 else "_%d" % ti
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/story_%s%s.png" % [nm, suffix]))
		ti += 1
	if ti >= times.size():
		print("STORY SHOT saved ", nm)
		OS.kill(OS.get_process_id())

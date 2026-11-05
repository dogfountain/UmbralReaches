extends Node
## Free-camera renders: godot --path . res://zz/spot_shot.tscn -- --at=x,y,z --look=x,y,z --name=n
##   [--times=9,10.5,12]  several frames from the same camera (seconds after load) -> spot_n_<i>.png
var t := 0.0
var cam: Camera3D
var at := Vector3.ZERO
var look := Vector3.FORWARD
var nm := "spot"
var times: Array[float] = [9.0]
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
			"--times":
				times.clear()
				for x in p: times.append(float(x))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if t > 8.0 and cam == null:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
		cam = Camera3D.new(); cam.fov = 60.0; cam.far = 400.0
		get_tree().root.add_child(cam); cam.current = true
		cam.global_position = at; cam.look_at(look)
	if cam != null and ti < times.size() and t > times[ti]:
		var suffix := "" if times.size() == 1 else "_%d" % ti
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/spot_%s%s.png" % [nm, suffix]))
		ti += 1
	if ti >= times.size():
		print("SPOT saved ", nm)
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())

extends SceneTree
## Look-dev capture: loads main.tscn and renders fixed camera views to PNG.
## godot --path . -s tools/capture.gd -- --out=/tmp/shots [--only=forest_left,floor_close]
## Each view costs ~45s under software rendering, so --only is worth using.

var views := [
	["forest_left", Vector3(-4.0, 2.2, 22.0), Vector3(-26.0, 5.0, 30.0)],
	["forest_right", Vector3(5.0, 2.0, 8.0), Vector3(24.0, 4.0, 20.0)],
	["floor_close", Vector3(-11.0, 1.4, 14.0), Vector3(-20.0, 0.0, 22.0)],
	["valley_wide", Vector3(0.0, 9.0, 52.0), Vector3(0.0, 6.0, 0.0)],
	["stair_foot", Vector3(0.0, 2.4, 20.0), Vector3(0.0, 6.0, -8.0)],
	["landing", Vector3(-1.2, 14.2, -24.0), Vector3(3.2, 15.4, -34.0)],
	["summit", Vector3(0.0, 27.4, -62.0), Vector3(0.0, 27.0, -76.0)],
]

func _initialize() -> void:
	var out := "/tmp"
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",", false)
	if not only.is_empty():
		var picked := []
		for v in views:
			if v[0] in only:
				picked.append(v)
		if picked.is_empty():
			push_error("capture: --only matched no view, expected any of %s" % [views.map(func(v): return v[0])])
			quit(1)
			return
		views = picked
	var main: Node = load("res://world/main.tscn").instantiate()
	get_root().add_child(main)
	main.get_node("HUD").visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	main.add_child(cam)
	await process_frame
	await physics_frame
	await physics_frame
	cam.current = true
	for v in views:
		cam.look_at_from_position(v[1], v[2])
		for i in 36:
			await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("CAP ", v[0], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit()

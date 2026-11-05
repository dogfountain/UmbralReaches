extends Node
## Agent D: draws / primitives / frame time at fixed views (the Lower Count, the new valley
## secrets), for A/B against `-- --no-r28-secrets`. Free camera; the player is parked under it.
## Save-safe (Travel._busy).
##   HOME=<scratch>/home godot --path . res://zz/secret_perf.tscn [-- --no-r28-secrets] [--views=name@x,y,z@lx,ly,lz;...]
const VIEWS := "pit@21,9,-74@15,2,-92;count@18,-0.3,-92@18,-0.6,-82;under@3,2,-66@18,-3,-86;gallery@22,9.9,-52.5@22,9.4,-66;glade@-30,2.2,14@-34,1.2,26"
var main: Node
var cam: Camera3D
var views: Array = []
var vi := 0
var t := 0.0
var vt := -1.0
var ready_t := -1.0
var samples := PackedFloat32Array()
var draws := 0
var prims := 0
var n := 0


func _ready() -> void:
	Travel.set("_busy", true)
	var spec := VIEWS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--views="):
			spec = a.trim_prefix("--views=")
	for s in spec.split(";", false):
		var p := s.split("@")
		var a3 := p[1].split(",")
		var l3 := p[2].split(",")
		views.append([p[0], Vector3(float(a3[0]), float(a3[1]), float(a3[2])), Vector3(float(l3[0]), float(l3[1]), float(l3[2]))])
	get_window().size = Vector2i(1600, 1000)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 220.0:
		OS.kill(OS.get_process_id())
	if ready_t < 0.0:
		if main and main.is_inside_tree() and main.has_meta("realm_done"):
			ready_t = t
		return
	if t - ready_t < 4.0:
		return
	if cam == null and "--skulls" in OS.get_cmdline_user_args():
		var lc := main.find_child("LowerCount", true, false)
		for mmi in lc.find_children("Skull*", "MultiMeshInstance3D", false, false):
			var mm := (mmi as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var o := mm.get_instance_transform(i).origin
				if o.x < 13.0 and o.z < -99.0 and o.z > -107.0:
					print("SKULL ", mmi.name, " ", o, " vis ", (mmi as MultiMeshInstance3D).visibility_range_end, " vis? ", (mmi as MultiMeshInstance3D).is_visible_in_tree())
		OS.kill(OS.get_process_id())
	if cam == null:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = String(c.name) == "Grade"
		cam = Camera3D.new()
		cam.fov = 70.0
		cam.far = 400.0
		get_tree().root.add_child(cam)
		cam.current = true
	if vi >= views.size():
		print("SECRET_PERF done")
		OS.kill(OS.get_process_id())
		return
	var v: Array = views[vi]
	if vt < 0.0:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		cam.global_position = v[1]
		cam.look_at(v[2])
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			pl.process_mode = Node.PROCESS_MODE_DISABLED
			pl.global_position = (v[1] as Vector3) + Vector3.DOWN * 1.6
		vt = t
		samples.clear()
		draws = 0
		prims = 0
		n = 0
		return
	if t - vt < 2.0:
		return                     # settle (streaming, shaders)
	samples.append(d * 1000.0)
	draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	n += 1
	if n >= 240:
		var s := Array(samples)
		s.sort()
		var mean := 0.0
		for x: float in s:
			mean += x
		mean /= float(s.size())
		print("SECRET_PERF %-8s fps %6.1f  p95 %5.2f ms  draws %4d  prims %8d" % [v[0], 1000.0 / mean, float(s[int(s.size() * 0.95)]), draws / n, prims / n])
		vi += 1
		vt = -1.0

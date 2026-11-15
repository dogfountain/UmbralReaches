extends Node
## Pop-in walk: the wanderer is carried along the Pilgrims' Road at walking pace (5 m/s) and a frame is read every 0.25 s
## (1.25 m). The mean absolute difference of each frame from the last (160 x 100 greys) is printed; a pop shows as a spike
## against its neighbours, and frames either side of a spike are saved.
##   godot --path <abs> res://zz/road_walk.tscn -- --out=<dir> [--from=x,z] [--to=x,z] [--secs=n]
var p: Player
var main: Node
var f := 0
var out := "/tmp/road_walk"
var a := Vector2(0.0, 62.0)
var b := Vector2(-150.0, 62.0)
var frames: Array[Image] = []
var diffs: Array[float] = []
var step := 0
var steps := 0
var wait := 0
var settled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--out="):
			out = s.trim_prefix("--out=")
		elif s.begins_with("--from="):
			var g := s.trim_prefix("--from=").split(",")
			a = Vector2(float(g[0]), float(g[1]))
		elif s.begins_with("--to="):
			var g2 := s.trim_prefix("--to=").split(",")
			b = Vector2(float(g2[0]), float(g2[1]))
	steps = int(a.distance_to(b) / 1.25)
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 800)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	f += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or f < 400:
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	var d := (b - a).normalized()
	var yaw := atan2(-d.x, -d.y)
	var pos := a + d * 1.25 * float(step)
	var spot := Vector3(pos.x, p.global_position.y if step > 0 else 2.0, pos.y)
	p.global_position = spot
	p.velocity = Vector3.ZERO
	p.set_view(yaw, -0.05)
	if not settled:
		settled = true
		wait = 120
	if wait > 0:
		wait -= 1
		return
	if step > 0 or frames.size() == 0:
		var im := get_viewport().get_texture().get_image()
		var small := im.duplicate() as Image
		small.resize(160, 100)
		small.convert(Image.FORMAT_L8)
		if frames.size() > 0:
			var prev := frames[frames.size() - 1]
			var s := 0.0
			var da := small.get_data()
			var db := prev.get_data()
			for i in da.size():
				s += absf(float(da[i]) - float(db[i]))
			diffs.append(s / float(da.size()))
		frames.append(small)
		im.save_png(out.path_join("w_%03d.png" % frames.size()))
	step += 1
	wait = 14                 # ~0.25 s of frames at 60
	if step > steps:
		var mean := 0.0
		for v in diffs:
			mean += v
		mean /= maxf(1.0, float(diffs.size()))
		for i in diffs.size():
			var flag := " <-- SPIKE" if diffs[i] > mean * 2.2 else ""
			print("WALK %03d diff %.2f%s" % [i + 1, diffs[i], flag])
		print("WALK mean %.2f frames %d done" % [mean, frames.size()])
		get_tree().quit()

extends Node
## The Kindled Keg's people, filmed where they live (windowed, the built world): the real Bartender and DwarfNpcs, posed every
## frame, from a camera standing in the tavern. Three rows of ten frames 0.35 s apart, taken 4, 14 and 30 s into the run (so
## the routine has had time to walk, wipe, fill and serve), and the planted-foot skate of the keep over the whole 45 s: every
## frame the keep's body travelled in, a sole within 1.2 cm of its floor level that moved, per metre walked.
##   godot --path . res://zz/keg_seq.tscn -- [--tag=x] [--cam=bar|room]
## -> shots/keg_seq_<tag>_<cam>.png ; "KEGSEQ contact keep ..." and "KEGSEQ done".
var tag := "x"
var cam_name := "bar"
var main: Node
var cam: Camera3D
var t := 0.0
var started := false
var keep: Node3D
var rows: Array = []
var cur: Array[Image] = []
var next_row := 0
var acc := 0.0
var feet: Array = [[], []]
var walk_d := 0.0
var prev := Vector3.INF
var dbg := 0
var log_rows: Array = []
const ROW_AT := [4.0, 14.0, 30.0]
const LEN := 45.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--cam="):
			cam_name = a.trim_prefix("--cam=")
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _foot(rig: DwarfRig, i: int) -> Vector3:
	var bt := 11 if i == 0 else 13
	var hip: Vector3 = rig.rests[bt]
	var knee: Vector3 = rig.rests[bt + 1]
	var ank: Vector3 = rig.ankle(1.0 if i == 0 else -1.0)
	return rig.global_transform * (hip + rig.get_q(bt) * ((knee - hip) + rig.get_q(bt + 1) * (ank - knee)))


func _process(d: float) -> void:
	if not started:
		if Engine.get_process_frames() < 1500 or not main.has_meta("realm_done"):
			return
		var Life: GDScript = load("res://core/npc/npc_life.gd")
		Life.set("every_frame", true)
		keep = get_tree().get_first_node_in_group("keep") as Node3D
		if keep == null:
			print("KEGFAIL no keep")
			get_tree().quit()
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			pl.global_position = Vector3(40.0, pl.global_position.y, 60.0)      # out of the picture
		for h in get_tree().get_nodes_in_group(&"hud"):
			if h is CanvasItem or h is CanvasLayer:
				h.set("visible", false)
		cam = Camera3D.new()
		cam.fov = 50.0
		get_tree().root.add_child(cam)
		cam.current = true
		var kp := keep.global_position
		if cam_name == "bar":
			cam.global_position = Vector3(kp.x + 2.5, kp.y + 1.6, kp.z - 3.6)
			cam.look_at(Vector3(kp.x + 0.8, kp.y + 1.0, kp.z))
		else:
			cam.global_position = Vector3(24.0, kp.y + 2.4, 27.0)
			cam.look_at(Vector3(17.0, kp.y + 0.6, 31.0))
		started = true
		print("KEGSEQ keep at ", kp)
		return
	t += d
	var rig: DwarfRig = keep.get("rig")
	var moved := 0.0
	if prev != Vector3.INF:
		moved = Vector2(keep.global_position.x - prev.x, keep.global_position.z - prev.z).length()
		walk_d += moved
	prev = keep.global_position
	if OS.get_cmdline_user_args().has("--dbg"):
		log_rows.append("%.2f w=%.2f task=%s moved=%.3f yaw=%.2f" % [t, float(keep.get("_walk")), String(keep.get("_task")), moved, keep.global_rotation.y])
	for i in 2:
		(feet[i] as Array).append(_foot(rig, i) if moved > 0.003 else Vector3.INF)
	if next_row < ROW_AT.size() and t >= float(ROW_AT[next_row]):
		acc += d
		if acc >= 0.35 or cur.is_empty():
			acc = 0.0
			var im := get_viewport().get_texture().get_image()
			im.resize(384, 216, Image.INTERPOLATE_BILINEAR)
			cur.append(im)
			if cur.size() >= 8:
				rows.append(cur.duplicate())
				cur.clear()
				next_row += 1
	if t >= LEN:
		_finish()


func _finish() -> void:
	var tot := 0.0
	for i in 2:
		var a: Array = feet[i]
		var ymin := 1.0e9
		for f: Variant in a:
			if f is Vector3 and f != Vector3.INF:
				ymin = minf(ymin, (f as Vector3).y)
		for j in range(1, a.size()):
			var f0: Vector3 = a[j - 1]
			var f1: Vector3 = a[j]
			if f0 == Vector3.INF or f1 == Vector3.INF:
				continue
			if f0.y < ymin + 0.012 and f1.y < ymin + 0.012:
				var sl := Vector2(f1.x - f0.x, f1.z - f0.z).length()
				tot += sl
				if sl > 0.012 and OS.get_cmdline_user_args().has("--dbg") and dbg < 40:
					dbg += 1
					print("KEGSLIDE foot %d frame %d slide %.3f m" % [i, j, sl])
	if OS.get_cmdline_user_args().has("--dbg"):
		for ln: String in log_rows:
			print("KEGLOG ", ln)
	print("KEGSEQ contact keep %.1f cm/m over %.1f m of walking (%.0f s)" % [100.0 * tot / maxf(walk_d, 0.01), walk_d, t])
	var sheet := Image.create(384 * 8, 216 * maxi(rows.size(), 1), false, Image.FORMAT_RGB8)
	for ri in rows.size():
		for ci in (rows[ri] as Array).size():
			var im: Image = rows[ri][ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 384, 216), Vector2i(ci * 384, ri * 216))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/keg_seq_%s_%s.png" % [tag, cam_name]))
	print("KEGSEQ done")
	get_tree().quit()

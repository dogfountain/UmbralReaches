extends Node
## The Kindled Keg's people, filmed where they live (windowed, the built world), one subject a run, framed large and lit by a
## harness-only fill light at the camera. Rows of four frames 0.6 s apart: three rows (taken at 4, 14, 30 s into the run) for the
## keep and the seated dwarf, and for the standing dwarf (whose trip to the bar is set going at once) three rows from 5 s on
## at 1.0 s spacing so the walk and the idle at the counter both show. The keep's planted-foot skate over the whole 45 s is printed:
## every frame his body travelled in, a sole within 1.2 cm of its floor level that moved, per metre walked.
##   godot --path . res://zz/keg_seq.tscn -- [--tag=x] [--who=keep|seated|stand]
## -> shots/keg_seq_<tag>_<who>.png ; "KEGSEQ contact keep ..." and "KEGSEQ done".
var tag := "x"
var who := "keep"
var main: Node
var cam: Camera3D
var t := 0.0
var started := false
var keep: Node3D
var subject: Node3D
var rows: Array = []
var cur: Array[Image] = []
var next_row := 0
var acc := 0.0
var feet: Array = [[], []]
var walk_d := 0.0
var prev := Vector3.INF
var row_at: Array = [4.0, 14.0, 30.0]
var kinds: Array = []             ## the keep's rows: the first time each of these is what he is doing
var cap_t := 0.0
var capturing := false
var last_cap := -9.0
var gap := 0.6
var _cam_ang := INF
var _cam_try := 0.0
var dbg := 0
var cat := {}
var log_rows: Array = []
const LEN := 45.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--who="):
			who = a.trim_prefix("--who=")
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


func _pick_subject() -> void:
	keep = get_tree().get_first_node_in_group("keep") as Node3D
	subject = keep
	if who == "keep":
		return
	for n: Node in get_tree().root.find_children("*", "Node3D", true, false):
		if n is DwarfNpc:
			var d := n as DwarfNpc
			if who == "seated" and bool(d.get("seated")) and not bool(d.get("wanders")) and d.global_position.distance_to(keep.global_position) < 12.0:
				subject = d
				d.cue("talk", 1.0e6)
				break
			if who == "stand" and bool(d.get("wanders")):
				subject = d
				d.set("_trip_wait", 0.1)
				break


## A camera spot 3.2 m out from `chest`, at the angle nearest the last one where nothing stands between (a wall, a patron's
## back, the counter) and it is inside the tavern: so the subject is framed large and free, whichever way he turns.
func _clear_spot(chest: Vector3) -> Vector3:
	var space := subject.get_world_3d().direct_space_state
	var best := Vector3.INF
	var best_cost := 1.0e9
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var spot := chest + Vector3(cos(ang), 0.0, sin(ang)) * 3.2 + Vector3.UP * 0.8
		if not Rect2(10.6, 26.1, 14.8, 8.2).has_point(Vector2(spot.x, spot.z)):
			continue
		var q := PhysicsRayQueryParameters3D.create(spot, chest, 0xFFFFFFFF)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(chest) > 0.7:
			continue
		var cost := absf(angle_difference(ang, _cam_ang)) if _cam_ang != INF else 0.0
		if cost < best_cost:
			best_cost = cost
			best = spot
			_cam_try = ang
	if best == Vector3.INF:
		return cam.global_position
	_cam_ang = _cam_try
	return best


func _process(d: float) -> void:
	if not started:
		if Engine.get_process_frames() < 1500 or not main.has_meta("realm_done"):
			return
		var Life: GDScript = load("res://core/npc/npc_life.gd")
		Life.set("every_frame", true)
		_pick_subject()
		if keep == null or subject == null:
			print("KEGFAIL no subject")
			get_tree().quit()
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			pl.global_position = Vector3(40.0, pl.global_position.y, 60.0)      # out of the picture
		for h in get_tree().get_nodes_in_group(&"hud"):
			h.set("visible", false)
		cam = Camera3D.new()
		cam.fov = 38.0
		get_tree().root.add_child(cam)
		cam.current = true
		var fill := OmniLight3D.new()                       # harness-only fill, so a dark tavern can be judged
		fill.light_energy = 2.6
		fill.omni_range = 9.0
		fill.shadow_enabled = false
		cam.add_child(fill)
		if who == "stand":
			row_at = [5.0, 9.0, 13.0]
			gap = 1.0
		if who == "keep":
			kinds = ["walk", "wipe", "serve", "chat"]
			gap = 0.5
		started = true
		print("KEGSEQ scales keep ", keep.scale, " rig ", (keep.get("rig") as Node3D).scale, " global ", (keep.get("rig") as Node3D).global_basis.get_scale())
		print("KEGSEQ subject ", who, " ", subject.name, " at ", subject.global_position)
		return
	t += d
	var chest := subject.global_position + Vector3.UP * 0.85
	cam.global_position = _clear_spot(chest)
	cam.look_at(chest)
	var rig: DwarfRig = keep.get("rig")
	var moved := 0.0
	if prev != Vector3.INF:
		moved = Vector2(keep.global_position.x - prev.x, keep.global_position.z - prev.z).length()
		walk_d += moved
	prev = keep.global_position
	if OS.get_cmdline_user_args().has("--dbg"):
		log_rows.append("t=%.2f w=%.2f spd=%.2f armed=%s task=%s moved=%.3f" % [t, float(keep.get("_walk")), float(keep.get("_spd")), str(keep.get("_armed")), String(keep.get("_task")), moved])
	for i in 2:
		(feet[i] as Array).append(_foot(rig, i) if moved > 0.003 else Vector3.INF)
	if OS.get_cmdline_user_args().has("--ft") and float(keep.get("_spd")) >= 0.99 and dbg < 70:
		dbg += 1
		var f0: Vector3 = _foot(rig, 0)
		print("KFT body %.3f foot0 x %.3f y %.3f" % [keep.global_position.x, f0.x, f0.y])
	if who == "seated":
		var dd := subject as DwarfNpc
		if t > 4.0 and t < 4.1:
			dd.speaking = true                      # row 1: talking
		elif t > 13.5 and t < 13.6:
			dd.speaking = false
			dd.cue("drink", 6.0)                    # row 2: drinking
		elif t > 29.5 and t < 29.6:
			dd.cue("laugh", 4.0)                    # row 3: laughing
	var go := false
	if who == "keep":
		if not capturing and next_row < kinds.size() and t - last_cap > 3.0:
			var k := String(kinds[next_row])
			var task := String(keep.get("_task"))
			var w := float(keep.get("_walk"))
			go = (k == "walk" and w >= 0.9) or (k == "wipe" and task == "wipe" and w < 0.05) or (k == "serve" and task in ["serve", "fill"] and w < 0.05) or (k == "chat" and task == "chat" and w < 0.05)
			if go:
				capturing = true
				acc = 99.0
	elif next_row < row_at.size() and t >= float(row_at[next_row]):
		go = true
	if go or capturing:
		acc += d
		if acc >= gap or cur.is_empty():
			acc = 0.0
			var im := get_viewport().get_texture().get_image()
			im.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			cur.append(im)
			if cur.size() >= 4:
				rows.append(cur.duplicate())
				cur.clear()
				next_row += 1
				capturing = false
				last_cap = t
	if t >= (80.0 if who == "keep" else LEN) or (who == "stand" and next_row >= row_at.size()) or (who == "keep" and next_row >= kinds.size()):
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
				var lr: String = log_rows[j] if j < log_rows.size() else ""
				var key := "steady" if lr.contains("spd=1.00") else ("ramp" if lr.contains("w=1.00") else "other")
				cat[key] = float(cat.get(key, 0.0)) + sl
				if sl > 0.01 and dbg < 25 and OS.get_cmdline_user_args().has("--dbg"):
					dbg += 1
					print("KEGSLIDE foot %d %.3f m at %s" % [i, sl, log_rows[j] if j < log_rows.size() else "?"])
	if OS.get_cmdline_user_args().has("--dbg"):
		print("KEGCAT ", cat, " walked ", walk_d)
	if who == "keep":
		print("KEGSEQ contact keep %.1f cm/m over %.1f m of walking (%.0f s)" % [100.0 * tot / maxf(walk_d, 0.01), walk_d, t])
	var sheet := Image.create(480 * 4, 270 * maxi(rows.size(), 1), false, Image.FORMAT_RGB8)
	for ri in rows.size():
		for ci in (rows[ri] as Array).size():
			var im: Image = rows[ri][ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 480, 270), Vector2i(ci * 480, ri * 270))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/keg_seq_%s_%s.png" % [tag, who]))
	print("KEGSEQ done")
	get_tree().quit()

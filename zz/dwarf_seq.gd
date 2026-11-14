extends Node3D
## Motion strips of the tavern's people (the critique's animation seat): a standing DwarfNpc (idle, talk, walk) and the
## Bartender (work at the counter, a walk along it and the serve), each a real node of its own class, in a lit studio with a
## checker floor (a sliding foot shows). Rows of consecutive real-time frames; the walks print the planted foot's skate.
##   godot --path . res://zz/dwarf_seq.tscn -- [--tag=x]
## -> shots/dwarf_seq_<tag>_<who>.png ; "DSEQ contact <who> <cm/m>" and "DSEQ done".
var tag := "x"
var cam: Camera3D
var subject: Node3D
var rows: Array = []
var prev_pos := Vector3.INF
var feet: Array = [[], []]
var walk_d := 0.0
var meas := false
var floor_mi: MeshInstance3D


func _ready() -> void:
	Travel._busy = true
	Engine.max_fps = 60
	get_window().size = Vector2i(720, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var Life: GDScript = load("res://core/npc/npc_life.gd")
	Life.set("every_frame", true)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.31, 0.34)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.65, 0.7)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.2
	add_child(key)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(0.4, 0.4, 0.42) if ((x / 32) + (y / 32)) % 2 == 0 else Color(0.22, 0.22, 0.24))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 4.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fl.mesh = pm
	fl.material_override = mat
	add_child(fl)
	floor_mi = fl
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _frame() -> float:
	await get_tree().process_frame
	_measure()
	_cam()
	return get_process_delta_time()


func _foot(i: int) -> Vector3:
	var rig: DwarfRig = subject.get("rig")
	var bt := 11 if i == 0 else 13
	var hip: Vector3 = rig.rests[bt]
	var knee: Vector3 = rig.rests[bt + 1]
	var ank: Vector3 = rig.ankle(1.0 if i == 0 else -1.0)
	var f: Vector3 = hip + rig.get_q(bt) * ((knee - hip) + rig.get_q(bt + 1) * (ank - knee))
	return rig.global_transform * f


func _measure() -> void:
	if not meas or subject == null or not subject.is_inside_tree():
		return
	var moved := 0.0
	if prev_pos != Vector3.INF:
		moved = Vector2(subject.global_position.x - prev_pos.x, subject.global_position.z - prev_pos.z).length()
		walk_d += moved
	prev_pos = subject.global_position
	for i in 2:
		# only frames the body travelled in: a figure standing and shifting its weight is not skating
		(feet[i] as Array).append(_foot(i) if moved > 0.003 else Vector3.INF)
		if i == 0 and moved > 0.003 and OS.get_cmdline_user_args().has("--ft"):
			print("DF y=%.3f z=%.3f x=%.3f body x=%.3f" % [(feet[0] as Array)[-1].y, (feet[0] as Array)[-1].z, (feet[0] as Array)[-1].x, subject.global_position.x])


func _contact() -> float:
	var tot := 0.0
	for i in 2:
		var a: Array = feet[i]
		var ymin := 1.0e9
		for f: Vector3 in a:
			if f != Vector3.INF:
				ymin = minf(ymin, f.y)
		for j in range(1, a.size()):
			var f0: Vector3 = a[j - 1]
			var f1: Vector3 = a[j]
			if f0 == Vector3.INF or f1 == Vector3.INF:
				continue
			if f0.y < ymin + 0.012 and f1.y < ymin + 0.012:
				tot += Vector2(f1.x - f0.x, f1.z - f0.z).length()
	return 100.0 * tot / maxf(walk_d, 0.01)


func _cam() -> void:
	if subject == null:
		return
	var at := subject.global_position + Vector3.UP * 0.8
	cam.global_position = at + Vector3(3.0, 0.25, -1.4).normalized() * 3.0
	cam.look_at(at)


func _row(nm: String, n: int, step: float) -> void:
	var frames: Array[Image] = []
	var acc := 0.0
	while frames.size() < n:
		acc += await _frame()
		if acc >= step:
			acc -= step
			var im := get_viewport().get_texture().get_image()
			im = im.get_region(Rect2i(0, 60, 720, 600))
			im.resize(240, 200, Image.INTERPOLATE_BILINEAR)
			frames.append(im)
	rows.append([nm, frames])


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		t += await _frame()


func _run() -> void:
	await get_tree().process_frame
	# --- a standing dwarf: idle, talk, walk
	var d := DwarfNpc.new()
	d.name = "dwarf_a"
	d.set("seated", false)
	d.set("seed_n", 7023)
	d.set("hat", "hood")
	add_child(d)
	subject = d
	await _wait(0.5)
	d.cue("idle", 99.0)
	await _row("idle", 8, 0.4)
	d.speaking = true
	await _wait(0.4)
	await _row("talk", 8, 0.3)
	d.speaking = false
	d.cue("idle", 99.0)
	# the walk: driven on the spot's rails as the tavern's wanderers are (their own _animate_walk and gait)
	d.set_process(false)
	d.rotation.y = 0.0
	d.set("_yaw", 0.0)
	d.global_position = Vector3(0, 0, 8)
	var Life: GDScript = load("res://core/npc/npc_life.gd")
	d.set("_walk", 1.0)
	var t := 0.0
	var acc := 0.0
	var frames: Array[Image] = []
	meas = true
	while t < 4.0:
		var dt := await _frame()
		t += dt
		var step := 0.75 * dt
		d.global_position.z -= step
		d.set("_gait", fposmod(float(d.get("_gait")) + step / Life.calib_stride(d.rig, 0.38, 0.95, 0.022), 1.0))
		d.call("_animate_walk", dt)
		d.rig.apply()
		acc += dt
		if acc >= 0.1 and frames.size() < 8 and t > 1.0:
			acc = 0.0
			var im := get_viewport().get_texture().get_image().get_region(Rect2i(0, 60, 720, 600))
			im.resize(240, 200, Image.INTERPOLATE_BILINEAR)
			frames.append(im)
	meas = false
	rows.append(["walk", frames])
	print("DSEQ contact dwarf %.1f cm/m over %.1f m" % [_contact(), walk_d])
	_sheet("dwarf")
	d.queue_free()
	rows.clear()
	feet = [[], []]
	walk_d = 0.0
	prev_pos = Vector3.INF
	# --- the bartender: work at the counter, the walk along it, the serve
	# the Keg's counter as Tavern builds it: the floor at -0.7, the counter's top 1.08 over it (bar_y 0.38), its back edge at z 33.33
	floor_mi.position.y = -0.7                                 # the floor plane
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(8.0, 1.08, 0.7)
	bar.mesh = bm
	bar.position = Vector3(15.0, -0.7 + 0.54, 33.33 - 0.35)
	add_child(bar)
	var b := Bartender.new()
	b.name = "Bartender"
	b.lane_x = Vector2(12.0, 18.0)
	b.lane_z = 33.6
	b.bar_y = 0.38
	b.bar_z = 33.33
	b.keg = Vector3(19.2, -0.6, 33.75)
	b.facing = 0.0
	b.position = Vector3(13.0, -0.7, 33.6)
	add_child(b)
	subject = b
	b.set("_task", "wipe")
	b.set("_task_len", 99.0)
	await _wait(0.6)
	await _row("wipe", 8, 0.5)
	b.set("_task", "polish")
	b.set("_task_t", 0.0)
	b.set("_task_len", 99.0)
	await _wait(0.4)
	await _row("polish", 8, 0.5)
	meas = true
	b.serve_at(17.0)
	await _row("serve_walk", 10, 0.5)
	meas = false
	print("DSEQ contact bartender %.1f cm/m over %.1f m" % [_contact(), walk_d])
	await _row("serve_set", 8, 0.3)
	_sheet("bartender")
	print("DSEQ done")
	get_tree().quit()


func _sheet(who: String) -> void:
	var sheet := Image.create(240 * 10, 200 * rows.size(), false, Image.FORMAT_RGB8)
	for ri in rows.size():
		var fr: Array = rows[ri][1]
		for ci in fr.size():
			var im: Image = fr[ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 240, 200), Vector2i(ci * 240, ri * 200))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/dwarf_seq_%s_%s.png" % [tag, who]))
	print("DSEQ sheet ", who, " rows=", rows.map(func(r: Array) -> String: return r[0]))

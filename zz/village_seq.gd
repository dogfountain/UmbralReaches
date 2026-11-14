extends Node3D
## Motion strips of the village cast (the critique's animation seat): a real Villager (villager.gd, its own pose
## system) under a stub director, in a lit studio with a checker floor (a sliding foot shows). Per villager,
## rows of consecutive real-time frames: idle (0.35 s apart), walk (0.07 s: the gait cycle), a stop, talk
## (attending the wanderer, 0.3 s), then the work of the rig's tool (hammer / chop ...) at 0.12 s.
##   godot --path . res://zz/village_seq.tscn -- [--only=hild,col] [--tag=x] [--cam=side|q34|front]
## -> shots/village_seq_<tag>_<id>.png; prints "VSEQ slide <id> <cm/m>" (soles low and moving, per metre walked) and "VSEQ done".
const Vil := preload("res://core/life/village/villager.gd")
const Cast := preload("res://core/life/village/village_cast.gd")


## What the villager needs of its director: a flat nav.
class StubNav extends RefCounted:
	func clear(_p: Vector3) -> bool:
		return true

	func clear_ex(_p: Vector3, _ex: Array) -> bool:
		return true

	func floor_at(_x: float, _z: float) -> float:
		return 0.0

	func has(_n: String) -> bool:
		return false


## ... the clock, anchors in front of it, and the work's effects as no-ops.
class StubDir extends Node:
	var time_scale := 1.0
	var nav := StubNav.new()
	var at := Vector3.ZERO

	func anchor(_k: String) -> Vector3:
		return at

	func strike(_v: Node3D) -> void:
		pass

	func quench(_v: Node3D) -> void:
		pass

	func grind_sparks(_v: Node3D) -> void:
		pass

	func chop(_v: Node3D) -> void:
		pass

	func dig(_v: Node3D) -> void:
		pass

	func talk(_v: Node3D, _by: Node) -> void:
		pass


var tag := "x"
var view := "side"
var only: Array = []
var dir_node: StubDir
var cam: Camera3D
var v: Node3D
var wanderer: Node3D
var rows: Array = []
var prev_feet: Array = [Vector3.INF, Vector3.INF]
var slide_d := 0.0
var walk_d := 0.0
var meas := false
var prev_pos := Vector3.INF


func _ready() -> void:
	Travel._busy = true
	Engine.max_fps = 60
	get_window().size = Vector2i(720, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--cam="):
			view = a.trim_prefix("--cam=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	if only.is_empty():
		only = ["hild", "col", "fennick", "nan"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
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
	mat.uv1_scale = Vector3.ONE * 4.0           # 0.25 m checks
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fl.mesh = pm
	fl.material_override = mat
	add_child(fl)
	dir_node = StubDir.new()
	add_child(dir_node)
	wanderer = Node3D.new()
	wanderer.add_to_group(Groups.PLAYER)
	add_child(wanderer)
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.current = true
	_run.call_deferred()


func _frame() -> float:
	await get_tree().process_frame
	_measure()
	return get_process_delta_time()


## Planted-foot slide while walking: a sole near the floor that moved, per metre the body travelled.
func _measure() -> void:
	if not meas or v == null:
		return
	var rig: Object = v.get("rig")
	if rig == null:
		return
	if prev_pos != Vector3.INF:
		walk_d += Vector2(v.global_position.x - prev_pos.x, v.global_position.z - prev_pos.z).length()
	prev_pos = v.global_position
	for i in 2:
		var f := _foot(i)
		if prev_feet[i] != Vector3.INF and f.y < 0.09 and (prev_feet[i] as Vector3).y < 0.09:
			slide_d += Vector2(f.x - prev_feet[i].x, f.z - prev_feet[i].z).length()
		if OS.get_cmdline_user_args().has("--ft") and i == 0:
			print("VF y=%.3f z=%.3f bodyz=%.3f" % [f.y, f.z, v.global_position.z])
		prev_feet[i] = f


func _foot(i: int) -> Vector3:
	var rig: Node3D = v.get("rig")
	var bt := 11 if i == 0 else 13
	var rests: Array = rig.get("rests")
	var hip: Vector3 = rests[bt]
	var knee: Vector3 = rests[bt + 1]
	var ank: Vector3 = rig.call("ankle", 1.0 if i == 0 else -1.0)
	var qt: Quaternion = rig.call("get_q", bt)
	var qs: Quaternion = rig.call("get_q", bt + 1)
	return rig.global_transform * (hip + qt * ((knee - hip) + qs * (ank - knee)))


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		t += await _frame()
		_cam()


func _cam() -> void:
	if v == null:
		return
	var at := v.global_position + Vector3.UP * 0.9
	var d := Vector3(1, 0, 0)
	match view:
		"q34":
			d = Vector3(0.7, 0, -0.7).normalized()
		"front":
			d = Vector3(0, 0, -1)
	cam.global_position = at + d * 3.4 + Vector3.UP * 0.25
	cam.look_at(at)


## `n` frames `step` s apart, laid out as one row.
func _row(nm: String, n: int, step: float) -> void:
	var frames: Array[Image] = []
	var acc := 0.0
	while frames.size() < n:
		acc += await _frame()
		_cam()
		if acc >= step:
			acc -= step
			var im := get_viewport().get_texture().get_image()
			im = im.get_region(Rect2i(0, 60, 720, 600))
			im.resize(240, 200, Image.INTERPOLATE_BILINEAR)
			frames.append(im)
	rows.append([nm, frames])


func _spawn(id: String) -> void:
	if is_instance_valid(v):
		v.queue_free()
	v = Vil.new()
	v.setup(id, Cast.CAST[id], dir_node)
	add_child(v)
	v.global_position = Vector3.ZERO
	v.state = "idle"
	v.act = "idle"
	v.pinned = true
	v.act_len = 1.0e6
	rows.clear()
	wanderer.global_position = Vector3(0, 0.0, -3.0)


func _run() -> void:
	await get_tree().process_frame
	for id: String in only:
		_spawn(id)
		await _wait(0.6)
		await _row("idle", 8, 0.35)
		# walking: along -z off the network
		v.pinned = false
		v.follow = Vector3(0, 0, -60)
		v.follow_gap = 0.0
		await _wait(1.2)
		prev_feet = [Vector3.INF, Vector3.INF]
		prev_pos = Vector3.INF
		slide_d = 0.0
		walk_d = 0.0
		meas = true
		await _row("walk", 10, 0.07)
		await _wait(2.0)
		meas = false
		print("VSEQ slide %s %.1f cm/m over %.1f m" % [id, 100.0 * slide_d / maxf(walk_d, 0.01), walk_d])
		v.follow = null
		v.state = "idle"
		# the stop: the legs and the body after a walk
		await _row("stop", 8, 0.1)
		# talk: attending the wanderer
		v.face_yaw = 0.0
		v.attend = wanderer
		await _wait(0.8)
		await _row("talk", 8, 0.3)
		v.attend = null
		# the work of the rig's tool
		var tool := String((Cast.CAST[id].rig as Dictionary).get("r", ""))
		var act: String = {"hammer": "hammer", "axe": "chop", "scoop": "dig"}.get(tool, "")
		if act != "":
			v.pinned = true
			v.global_position = Vector3.ZERO
			v.yaw = 0.0
			v.rotation.y = 0.0
			v.face_yaw = 0.0
			dir_node.at = Vector3(0.0, 0.0, -0.8)
			v.hold(act, Vector3.INF)
			await _wait(0.6)
			await _row(act, 8, 0.12)
		_sheet(id)
	print("VSEQ done")
	get_tree().quit()


func _sheet(id: String) -> void:
	var sheet := Image.create(240 * 10, 200 * rows.size(), false, Image.FORMAT_RGB8)
	for ri in rows.size():
		var frames: Array = rows[ri][1]
		for ci in frames.size():
			var im: Image = frames[ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 240, 200), Vector2i(ci * 240, ri * 200))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/village_seq_%s_%s.png" % [tag, id]))
	print("VSEQ sheet ", id, " rows=", rows.map(func(r: Array) -> String: return r[0]))

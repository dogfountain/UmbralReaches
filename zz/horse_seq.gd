extends Node3D
## Motion strips of a real Horse under a real Player, in a lit studio: a mount, a walk, a trot, a gallop (and its mane), a hop over
## a low stone at a trot and a gallop leap, a halt, and the dismount. Each moment is a row of consecutive frames taken in real time.
##   godot --path . res://zz/horse_seq.tscn -- [--tag=x] [--breed=palfrey] [--cam=side|q34|front]
## -> shots/horse_seq_<tag>_<cam>.png ; prints "HSEQ done". Never writes the save.

const HorseScript := preload("res://core/world/mount/horse.gd")
const WORLD := 1
## [name, start s, frames, every n rendered frames]
const ROWS := [["mount", 0.0, 10, 7], ["walk", 3.1, 10, 6], ["trot", 6.2, 10, 3], ["gallop", 10.5, 10, 3], ["hop_trot", 13.2, 10, 4],
	["leap_gallop", 17.6, 10, 4], ["halt", 21.8, 10, 5], ["dismount", 24.8, 8, 6]]
var p: Player
var horse: Node3D
var cam: Camera3D
var tag := "x"
var view := "side"
var breed := "palfrey"
var t := 0.0
var started := false
var row_i := 0
var skip := 0
var fr := 0
var cur: Array[Image] = []
var sheets: Array = []
var dismounted := false
var mounted := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--cam="):
			view = a.trim_prefix("--cam=")
		elif a.begins_with("--breed="):
			breed = a.trim_prefix("--breed=")
	Travel._busy = true
	Engine.max_fps = 60
	get_window().size = Vector2i(960, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.31, 0.34)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 1.3
	add_child(key)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(0.34, 0.34, 0.36) if ((x / 32) + (y / 32)) % 2 == 0 else Color(0.2, 0.2, 0.22))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 2.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_box(Vector3(0, -0.5, -150), Vector3(80, 1, 400), mat)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.42, 0.4)
	_box(Vector3(0, 0.17, -86), Vector3(1.2, 0.34, 0.5), stone)             # the hop's stone (trot)
	_box(Vector3(0, 0.2, -150), Vector3(1.4, 0.4, 0.6), stone)              # the gallop leap's
	_spawn_player()
	horse = HorseScript.new()
	horse.breed = breed
	add_child(horse)
	horse.global_position = Vector3(0, 0, 0)
	horse.reset_physics_interpolation()
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	add_child(b)
	b.position = pos


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var r := Node3D.new()
	r.name = "CameraRig"
	r.position.y = 1.55
	pl.add_child(r)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	r.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var pcam := Camera3D.new()
	pcam.name = "Camera"
	arm.add_child(pcam)
	pl.position = Vector3(-1.4, 0.05, 1.0)
	add_child(pl)
	p = pl as Player


func _physics_process(delta: float) -> void:
	if p == null:
		return
	p.gloom = 0.0
	p.wounds = 0.0
	if not started:
		t += delta
		if t > 0.5:
			started = true
			t = 0.0
		return
	t += delta
	if not mounted:
		mounted = true
		horse.mount(p)
	# timeline: stand 0-3 (mount), walk 3-6, trot 6-10, gallop 10-13, trot to the stone 13-16, gallop to the leap 16-20, halt 21, dismount 24
	var w := Vector3.ZERO
	var sprint := false
	if t >= 3.0 and t < 6.0:
		w = Vector3(0, 0, -0.5)
	elif t >= 6.0 and t < 10.0:
		w = Vector3(0, 0, -1)
	elif t >= 10.0 and t < 13.0:
		w = Vector3(0, 0, -1)
		sprint = true
	elif t >= 13.0 and t < 17.0:
		w = Vector3(0, 0, -1)
	elif t >= 17.0 and t < 21.0:
		w = Vector3(0, 0, -1)
		sprint = true
	p.debug_drive(w, sprint)
	if t > 24.0 and not dismounted:
		dismounted = true
		horse.dismount()
	if t > 30.0:
		_finish()


func _process(_d: float) -> void:
	if p == null or not started or not is_instance_valid(horse):
		return
	var at := horse.global_position + Vector3.UP * 1.1
	var dir := Vector3(1, 0, 0)
	var dist := 6.2
	match view:
		"q34":
			dir = Vector3(0.7, 0, -0.7).normalized()
		"front":
			dir = Vector3(0, 0, -1)
			dist = 7.0
		"back":
			dir = Vector3(0, 0, 1)
	cam.global_position = at + dir * dist + Vector3.UP * 0.7
	cam.look_at(at)
	if row_i >= ROWS.size():
		return
	var b: Array = ROWS[row_i]
	# a mount row waits on the clock too; a hop row is timed by the horse (the first frame it is in the air)
	if t < float(b[1]):
		return
	skip -= 1
	if skip > 0:
		return
	skip = int(b[3])
	var im := get_viewport().get_texture().get_image()
	var h := im.get_height()
	var w := im.get_width()
	im = im.get_region(Rect2i(w / 2 - h * 3 / 8 - h / 8, 0, h * 3 / 4 + h / 4, h))
	im.resize(260, 240, Image.INTERPOLATE_BILINEAR)
	cur.append(im)
	fr += 1
	if fr >= int(b[2]):
		sheets.append([String(b[0]), cur.duplicate()])
		cur.clear()
		fr = 0
		skip = 0
		row_i += 1


func _finish() -> void:
	set_physics_process(false)
	var cols := 0
	for r: Array in sheets:
		cols = maxi(cols, (r[1] as Array).size())
	var sheet := Image.create(260 * cols, 240 * sheets.size(), false, Image.FORMAT_RGB8)
	for ri in sheets.size():
		var frames: Array = sheets[ri][1]
		for ci in frames.size():
			var im: Image = frames[ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(0, 0, 260, 240), Vector2i(ci * 260, ri * 240))
	var path := "res://shots/horse_seq_%s_%s.png" % [tag, view]
	sheet.save_png(ProjectSettings.globalize_path(path))
	print("HSEQ sheet ", path, " rows=", sheets.map(func(r: Array) -> String: return r[0]))
	print("HSEQ done")
	get_tree().quit()

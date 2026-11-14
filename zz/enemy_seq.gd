extends Node3D
## Motion strips of every enemy kind and boss (the critique's animation seat): in a lit studio, side-on, each
## kind's rig is driven by hand as the studio does and eight consecutive poses 0.1 s apart are laid out in a row:
## row 1 walking at its own pace (on the spot: the stride, the arms, the head), row 2 a strike's telegraph from its
## start (the rear-up and what follows it).
##   godot --path . res://zz/enemy_seq.tscn -- [--only=wretch,husk] [--tag=x]
## -> shots/enemy_seq/<tag>_<kind>.png, one sheet a kind (2 rows x 8). Never writes the save.
const Studio := preload("res://zz/combat_studio.gd")
const N := 8
const STEP := 0.1
var order: Array[String] = []
var tag := "seq"
var ki := 0
var cur: Enemy
var cam: Camera3D
var row := 0
var fi := 0
var wait := 0
var frames: Array[Image] = []
var t_row := 0.0
var struck := false


func _ready() -> void:
	Travel._busy = true
	get_window().size = Vector2i(600, 600)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			for k in a.trim_prefix("--only=").split(","):
				if Studio.KINDS.has(k): order.append(k)
	if order.is_empty():
		for k: String in Studio.KINDS: order.append(k)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/enemy_seq"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.85)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.rotation = Vector3(-0.8, 0.7, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.36, 0.36, 0.38)
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.current = true
	_spawn()


func _spawn() -> void:
	if is_instance_valid(cur):
		cur.queue_free()
	cur = (load(Studio.KINDS[order[ki]]) as GDScript).new() as Enemy
	add_child(cur)
	cur.global_position = Vector3.ZERO
	cur.sleep()
	if cur._hp_bar: cur._hp_bar.visible = false
	row = 0
	fi = 0
	wait = 20
	acc = 0.0
	t_row = 0.0
	struck = false
	frames.clear()


const ROWS := [["walk", 0.12], ["attack", 0.1], ["stagger", 0.16], ["collapse", 0.12]]


var acc := 0.0


func _process(d: float) -> void:
	if cur == null:
		return
	var h := maxf(cur.hp_bar_y, 1.0)
	var look := Vector3(0, h * 0.5, 0)
	cam.global_position = look + Vector3(-1.0, 0.14, 0.4).normalized() * (h * 2.1 + 1.0)
	cam.look_at(look)
	if wait > 0:
		wait -= 1
		if cur._rig:
			cur._rig.animate(Vector3.ZERO, true, 1.0 / 60.0)
		return
	# real time: the rig is driven every rendered frame (as in play), and a still is kept each `step` seconds
	var step: float = ROWS[row][1]
	var v := (-cur.global_basis.z * cur.walk_speed) if row == 0 else Vector3.ZERO
	if cur._rig:
		cur._rig.animate(v, true, d)
	acc += d
	if ROWS[row][0] == "attack" and not struck and t_row + d >= 0.45 and cur._rig and cur._rig.has_method("strike"):
		struck = true
		cur._rig.call("strike")
	t_row += d
	if acc < step:
		return
	acc -= step
	frames.append(get_viewport().get_texture().get_image())
	fi += 1
	if fi < N:
		return
	fi = 0
	row += 1
	t_row = 0.0
	struck = false
	if row >= ROWS.size():
		_sheet()
		ki += 1
		if ki >= order.size():
			print("ENEMYSEQ done ", order.size())
			get_tree().quit()
			return
		_spawn()
		return
	var nm: String = ROWS[row][0]
	if cur._rig:
		if nm == "attack" and cur._rig.has_method("telegraph"):
			cur._rig.call("telegraph", 0.45)
		elif nm == "stagger" and cur._rig.has_method("stagger"):
			cur._rig.call("stagger")
		elif nm == "collapse" and cur._rig.has_method("collapse"):
			cur._rig.call("collapse", false)


func _sheet() -> void:
	if frames.is_empty():
		return
	var tw := 300
	var rows := ceili(float(frames.size()) / float(N))
	var sheet := Image.create(tw * N, tw * rows, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var im := frames[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, tw, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, tw), Vector2i((i % N) * tw, (i / N) * tw))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/enemy_seq/%s_%s.png" % [tag, order[ki]]))

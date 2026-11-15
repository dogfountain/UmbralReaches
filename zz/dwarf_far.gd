extends Node3D
## The tavern's talkers at about 15 m, in a lit studio (the critique's "must read at 15 m" check): a standing pair (one
## talks, one listens) and a seated pair at a trestle, from an angle where yaw and lean show. 20 real-time frames, one every
## 0.5 s (10 s), laid out in one sheet.
##   godot --path . res://zz/dwarf_far.tscn -- [--tag=x] [--dist=15]
## -> shots/dwarf_far_<tag>.png (a row per 5 s) ; "DFAR done".
var tag := "x"
var dist := 15.0
var cam: Camera3D
var frames: Array[Image] = []


func _ready() -> void:
	Travel._busy = true
	Engine.max_fps = 60
	get_window().size = Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		elif a.begins_with("--dist="): dist = float(a.trim_prefix("--dist="))
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
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.3, 0.32)
	pm.material = fm
	fl.mesh = pm
	add_child(fl)
	var a := _dwarf("a", Vector3(-1.2, 0, 0), 0.5, false, 7023)
	var b := _dwarf("b", Vector3(-0.2, 0, 0.2), 0.5 + PI * 0.75, false, 4411)
	a.partner = b
	b.partner = a
	a.cue("talk", 999.0)
	b.cue("listen", 999.0)
	var c := _dwarf("c", Vector3(1.6, 0, 0), 0.0, true, 9001)
	var d := _dwarf("d", Vector3(1.6, 0, 1.2), PI, true, 5120)
	c.partner = d
	d.partner = c
	c.cue("listen", 999.0)
	d.cue("talk", 999.0)
	cam = Camera3D.new()
	cam.fov = 28.0
	add_child(cam)
	cam.current = true
	var at := Vector3(0.2, 0.8, 0.5)
	cam.global_position = at + Vector3(0.62, 0.12, 0.78).normalized() * dist
	cam.look_at(at)
	_run.call_deferred()


func _dwarf(n: String, pos: Vector3, yaw: float, seated: bool, seed_n: int) -> DwarfNpc:
	var d := DwarfNpc.new()
	d.name = "dwarf_" + n
	d.set("seated", seated)
	d.set("seed_n", seed_n)
	d.set("facing", yaw)
	add_child(d)
	d.global_position = pos
	return d


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var acc := 0.0
	while frames.size() < 20:
		await get_tree().process_frame
		acc += get_process_delta_time()
		if acc >= 0.5:
			acc -= 0.5
			var im := get_viewport().get_texture().get_image()
			im = im.get_region(Rect2i(560, 280, 480, 300))
			frames.append(im)
	# how much moved: the share of pixels that differ by more than a visible step from the frame 2 s earlier
	var tot := 0.0
	for i in range(4, frames.size()):
		var x := frames[i].get_data()
		var y := frames[i - 4].get_data()
		var n := 0
		for k in range(0, x.size(), 4):
			if absi(int(x[k]) - int(y[k])) + absi(int(x[k + 1]) - int(y[k + 1])) > 40:
				n += 1
		tot += float(n) / float(x.size() / 4)
	print("DFAR motion %.4f of the frame's pixels change (2 s apart)" % (tot / float(frames.size() - 4)))
	var sheet := Image.create(480 * 5, 300 * 4, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var im := frames[i]
		sheet.blit_rect(im, Rect2i(0, 0, 480, 300), Vector2i((i % 5) * 480, (i / 5) * 300))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/dwarf_far_%s.png" % tag))
	print("DFAR done")
	get_tree().quit()

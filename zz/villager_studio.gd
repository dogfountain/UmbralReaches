extends Node3D
## Hearthward's work loops, one act at a time (the critique's "do they read at 15 m" check). Each act in the village cast is
## spawned on its own villager (the first person whose routine uses it; the idle stances on several), under a moonlit rig with a
## warm glow where the work is, and filmed in real time at 15 m and at 5 m from the front and side, through the game's field of
## view. Per act it prints how much of the 15 m picture moves ("VSTUDIO <act> 15m motion x%") and writes a sheet.
##   godot --path . res://zz/villager_studio.tscn -- [--tag=x] [--only=hammer,heat]
## -> shots/villagers/<tag>_<act>.png (rows 1-2: 15 m, 16 frames --step s apart (0.25); rows 3-4: 5 m) ; "VSTUDIO done".
const Cast := preload("res://core/life/village/village_cast.gd")
const Villager := preload("res://core/life/village/villager.gd")
const FRAMES := 16
var step := 0.25                ## frame spacing; the slow acts (a stand about gestures every 8-13 s) use SLOW_STEP
const SLOW := ["idle", "doze", "sit", "look_up", "watch", "read", "mourn", "lean", "warm", "kneel", "sell"]
const SLOW_STEP := 0.6
var fixed_step := 0.0
var near := true               ## --near=0: the 15 m row only (half the time)
## acts that play once over their own length (quench, knock, light): held for that long and filmed from their start
const ONCE := {"quench": 4.6, "light": 5.0, "knock": 7.0}
const SETTLE := 2.5
var tag := "x"
var only: PackedStringArray = []
var cam: Camera3D
var glow: OmniLight3D
var cur: Node3D
var jobs: Array = []          ## [label, act, person id]


## The village director, as far as one villager needs it (the real one is village.gd).
class Stub extends Node:
	var time_scale := 1.0
	var nav: Object = null

	func anchor(n: String) -> Vector3:
		# the real forge's anchors (village.gd) relative to where the smith stands facing them (he faces -Z here)
		return {"@anvil": Vector3(0.0, 0.87, -0.75), "@coals": Vector3(0.0, 0.95, -1.2), "@water": Vector3(0.0, 0.58, -1.29),
			"@wheel": Vector3(0.0, 0.86, -0.48), "@fire": Vector3(0.0, 0.2, -1.1), "@pit": Vector3(0.0, 0.0, -0.8)}.get(n, Vector3(0.0, 0.5, -0.7))

	func strike(_v: Node) -> void:
		pass

	func quench(_v: Node) -> void:
		pass

	func chop(_v: Node) -> void:
		pass

	func dig(_v: Node) -> void:
		pass

	func grind_sparks(_v: Node) -> void:
		pass

	func lamp_needs(_i: String) -> bool:
		return false

	func light_lamp(_i: String) -> void:
		pass


func _ready() -> void:
	Travel._busy = true
	get_window().size = Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--step="):
			fixed_step = float(a.trim_prefix("--step="))
		elif a == "--near=0":
			near = false
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	var seen := {}
	var idles := 0
	for pid: String in Cast.CAST:
		var routines: Dictionary = (Cast.CAST[pid] as Dictionary).get("routines", {})
		for rn: String in routines:
			for st: Variant in routines[rn]:
				var act := String((st as Dictionary).get("act", ""))
				if act == "" or act == "chat":
					continue
				if act == "idle":
					if idles < 3 and not seen.has("idle_" + pid):
						seen["idle_" + pid] = true
						idles += 1
						jobs.append(["idle_" + pid, "idle", pid])
				elif not seen.has(act):
					seen[act] = true
					jobs.append([act, act, pid])
	if not only.is_empty():
		jobs = jobs.filter(func(j: Array) -> bool: return String(j[0]) in only or String(j[1]) in only)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.05, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.42, 0.7)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.8
	moon.rotation = Vector3(-0.9, 0.9, 0)
	add_child(moon)
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.light_energy = 3.0
	glow.omni_range = 7.0
	glow.position = Vector3(0.2, 1.2, -1.0)
	add_child(glow)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.22)
	pm.material = fm
	fl.mesh = pm
	add_child(fl)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/villagers"))
	_run.call_deferred()


func _spawn(job: Array) -> void:
	if is_instance_valid(cur):
		cur.queue_free()
	var stub := Stub.new()
	stub.name = "Village"
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(stub)
	var v := Villager.new()
	var d: Dictionary = Cast.CAST[job[2]]
	v.setup(String(job[2]), d, stub)
	holder.add_child(v)
	v.hold(String(job[1]), Vector3.INF, float(ONCE.get(String(job[1]), 1.0e6)))
	cur = holder


func _shoot(dist: float, crop: Vector2i, up: int) -> Image:
	var at := Vector3(0, 0.9, 0)
	var a := deg_to_rad(-55.0)                    # from the front and the side (he faces -Z)
	cam.global_position = Vector3(sin(a) * dist, 1.5, -cos(a) * dist)
	cam.look_at(at)
	await get_tree().process_frame
	await get_tree().process_frame
	var im := get_viewport().get_texture().get_image()
	var c := Vector2i(800, 450)
	var r := im.get_region(Rect2i(c.x - crop.x / 2, c.y - crop.y / 2, crop.x, crop.y))
	r.convert(Image.FORMAT_RGBA8)
	r.resize(crop.x * up, crop.y * up, Image.INTERPOLATE_NEAREST)
	return r


func _run() -> void:
	for job: Array in jobs:
		step = fixed_step if fixed_step > 0.0 else (SLOW_STEP if String(job[1]) in SLOW else 0.25)
		_spawn(job)
		await get_tree().create_timer(0.1 if ONCE.has(String(job[1])) else SETTLE).timeout
		var rows: Array = []
		var motion := 0.0
		for dist in ([15.0, 5.0] if near else [15.0]):
			var crop := Vector2i(150, 190) if dist > 10.0 else Vector2i(280, 340)
			var up := 2 if dist > 10.0 else 1
			var frames: Array[Image] = []
			var acc := 0.0
			var t_prev := Time.get_ticks_msec()
			while frames.size() < FRAMES:
				acc += (Time.get_ticks_msec() - t_prev) / 1000.0
				t_prev = Time.get_ticks_msec()
				if acc >= step:
					acc -= step
					frames.append(await _shoot(dist, crop, up))
				else:
					await get_tree().process_frame
			rows.append(frames)
			if dist > 10.0:
				var tot := 0.0
				for i in range(2, frames.size()):
					var x := frames[i].get_data()
					var y := frames[i - 2].get_data()
					var n := 0
					for k in range(0, x.size(), 4):
						if absi(int(x[k]) - int(y[k])) + absi(int(x[k + 1]) - int(y[k + 1])) + absi(int(x[k + 2]) - int(y[k + 2])) > 60:
							n += 1
					tot += float(n) / float(x.size() / 4)
				motion = tot / float(frames.size() - 2)
		print("VSTUDIO %-16s 15m motion %.2f%% of the crop changes between frames %.2f s apart" % [job[0], motion * 100.0, step * 2.0])
		var sheet := Image.create(8 * 300, (4 if near else 2) * 380, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.05, 0.05, 0.08))
		for ri in rows.size():
			for i in FRAMES:
				var im: Image = (rows[ri] as Array)[i]
				sheet.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i((i % 8) * 300, (ri * 2 + i / 8) * 380))
		sheet.save_png(ProjectSettings.globalize_path("res://shots/villagers/%s_%s.png" % [tag, job[0]]))
	print("VSTUDIO done")
	get_tree().quit()

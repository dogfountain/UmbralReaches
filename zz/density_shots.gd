extends Node
## Stills for the world density pass (realm_wayside.gd, flora_layers.gd), in the real night, windowed, in memory only:
##   godot --path . --always-on-top res://zz/density_shots.tscn -- --out=<dir> [--tag=a] [--places=N] [--region=id,id]
##       [--view=name:x:y:z:tx:ty:tz ...] [--no-density] [--perf]
## --perf (run with --disable-vsync): no stills; at each view the frame times of 90 drawn frames after it settles,
## and the draw calls; prints "DPERF <view> median .. p95 .. draws .." per view and over all of them (A/B with
## --no-density on the same views: zz/density_shots then compares the world with and without the pass).
## Without --view: a still at each named wayside place (from 9 m off its front, eye 2.2 m up) and up to N more of
## each region's places, plus a long look along each Far Reaches way. y / ty are metres over the ground.
## Each still waits for drawn frames and is taken again when it matches the last one (a window that stopped drawing).
const Footing := preload("res://core/world/footing.gd")
const Wayside := preload("res://core/world/realm/realm_wayside.gd")
var main: Node
var p: Player
var cam: Camera3D
var t := 0
var out := "/tmp"
var tag := "a"
var per_region := 2
var only: PackedStringArray = []
var views: Array = []              # [name, eye Vector3, target Vector3] (y over ground)
var started := false
var _last: Image
var perf := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--places="):
			per_region = int(a.trim_prefix("--places="))
		elif a == "--perf":
			perf = true
		elif a.begins_with("--region="):
			only = a.trim_prefix("--region=").split(",")
		elif a.begins_with("--view="):
			var f := a.trim_prefix("--view=").split(":")
			views.append([f[0], Vector3(float(f[1]), float(f[2]), float(f[3])), Vector3(float(f[4]), float(f[5]), float(f[6]))])
	get_window().size = Vector2i(1280, 800)
	get_window().position = Vector2i(24, 40)            # off the middle of the screen, where other sessions' windows open
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _ground(x: float, z: float) -> float:
	return Footing.terrain_y((main as Node3D).get_world_3d().direct_space_state, x, z, 0.0)


func _process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if started or not main.has_meta("realm_done") or t < 500:
		return
	started = true
	_run()


func _auto() -> void:
	var seen := {}
	for v: Dictionary in Wayside.plan:
		var region := String(v.region)
		if not only.is_empty() and not region in only:
			continue
		var named := String(v.get("name", "")) != ""
		if not named and int(seen.get(region, 0)) >= per_region:
			continue
		if not named:
			seen[region] = int(seen.get(region, 0)) + 1
		var a: Vector3 = v.at
		var yaw := float(v.yaw)
		var front := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var d := float(v.r) + 6.0
		var eye := a + front * d + Vector3(front.z, 0.0, -front.x) * 2.5
		views.append(["%s_%s_%s" % [region, v.kind, v.id], Vector3(eye.x, 2.2, eye.z), Vector3(a.x, 0.8, a.z)])


func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	get_window().position = Vector2i(24, 40)            # (the night's settings centre the window again when it loads)
	(p.get_node("Visual") as Node3D).visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	add_child(cam)
	cam.make_current()
	if views.is_empty():
		_auto()
	print("DSHOTS %d views" % views.size())
	for v: Array in views:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		var a: Vector3 = v[1]
		var b: Vector3 = v[2]
		var eye := Vector3(a.x, _ground(a.x, a.z) + a.y, a.z)
		var tgt := Vector3(b.x, _ground(b.x, b.z) + b.y, b.z)
		p.global_position = Vector3(a.x, eye.y + 0.5, a.z)
		p.velocity = Vector3.ZERO
		cam.global_position = eye
		cam.look_at(tgt, Vector3.UP)
		if perf:
			await _measure(String(v[0]), a, eye)
			continue
		var img: Image = null
		for attempt in 8:
			for f in 14:
				await RenderingServer.frame_post_draw
				p.global_position = Vector3(a.x, eye.y + 0.5, a.z)
				p.velocity = Vector3.ZERO
			img = get_viewport().get_texture().get_image()
			if _last == null or img.get_data() != _last.get_data():
				break
			print("DSHOTS stale frame at %s, waiting" % v[0])
		_last = img
		var path := out.path_join("%s_%s.png" % [v[0], tag])
		img.save_png(path)
		print("DSHOT ", path)
	if perf:
		_all.sort()
		_dr.sort()
		print("DPERF all %d views: median %.2f ms p95 %.2f ms; draws median %d" % [views.size(), _all[_all.size() / 2], _all[int(_all.size() * 0.95)], _dr[_dr.size() / 2]])
	print("DSHOTS done")
	get_tree().quit()


var _all: Array[float] = []
var _dr: Array[int] = []


func _measure(nm: String, a: Vector3, eye: Vector3) -> void:
	for f in 30:
		await RenderingServer.frame_post_draw
		p.global_position = Vector3(a.x, eye.y + 0.5, a.z)
		p.velocity = Vector3.ZERO
	var ft: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for f in 90:
		await RenderingServer.frame_post_draw
		var t1 := Time.get_ticks_usec()
		ft.append((t1 - t0) / 1000.0)
		t0 = t1
		p.global_position = Vector3(a.x, eye.y + 0.5, a.z)
		p.velocity = Vector3.ZERO
	var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	ft.sort()
	_all.append_array(ft)
	_dr.append(draws)
	print("DPERF %-34s median %.2f ms p95 %.2f ms draws %d" % [nm, ft[ft.size() / 2], ft[int(ft.size() * 0.95)], draws])

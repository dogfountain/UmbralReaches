extends Node
## In-world frames of the wanderer moving: the real game camera (HUD off, grade on) or a tracking
## side camera, through a scripted run: idle, walk, sprint, jump (rise, apex, land), slide, stop.
##   godot --path . res://zz/move_shots.tscn [-- --tag=x] [--side|--close] [--legacy] [--at=x,z] [--yaw=rad] [--casts]
##   --casts  a casting run instead: idle, run, each skill's pose (bolt, lance charge + throw, nova,
##            ward, rift step), a hit, turning on the spot
## -> shots/move_<tag>_<cam>_<NN>_<event>.png and shots/move_<tag>_<cam>_sheet.png
## Prints "MOVESHOTS done".
var p: Player
var tag := "now"
var side := false
var close := false
var at := Vector2(0.0, 26.0)
var yaw := 0.0
var t := 0.0
var started := false
var cam: Camera3D
var files: Array[String] = []
var shot_i := 0
## [time from start (s), event name, wish (local: x right, z back), sprint, press]
const PLAN := [
	[0.0, "", Vector3.ZERO, false, ""],
	[1.2, "idle", Vector3.ZERO, false, ""],
	[1.25, "", Vector3(0, 0, -1), false, ""],
	[2.4, "walk", Vector3(0, 0, -1), false, ""],
	[2.45, "", Vector3(0, 0, -1), true, ""],
	[3.9, "sprint", Vector3(0, 0, -1), true, ""],
	[4.0, "", Vector3(0, 0, -1), true, "jump"],
	[4.15, "jump_rise", Vector3(0, 0, -1), true, ""],
	[4.42, "jump_apex", Vector3(0, 0, -1), true, ""],
	[4.62, "jump_fall", Vector3(0, 0, -1), true, ""],
	[4.85, "landed", Vector3(0, 0, -1), true, ""],
	[5.6, "", Vector3(0, 0, -1), true, "slide"],
	[5.85, "slide", Vector3(0, 0, -1), true, "slide"],
	[6.3, "", Vector3(-1, 0, -1), true, ""],
	[6.7, "turn", Vector3(-1, 0, -1), true, ""],
	[6.75, "", Vector3.ZERO, false, ""],
	[6.95, "stopping", Vector3.ZERO, false, ""],
	[8.0, "settled", Vector3.ZERO, false, ""],
]
## [time, event name, wish, sprint, action]: actions fire the rig's cast poses like the skills do
const CAST_PLAN := [
	[0.0, "", Vector3.ZERO, false, ""],
	[1.0, "idle", Vector3.ZERO, false, ""],
	[1.05, "", Vector3(0, 0, -1), true, ""],
	[2.4, "sprint", Vector3(0, 0, -1), true, ""],
	[2.45, "", Vector3.ZERO, false, ""],
	[3.3, "", Vector3.ZERO, false, "bolt"],
	[3.4, "bolt", Vector3.ZERO, false, ""],
	[3.9, "", Vector3.ZERO, false, "charge"],
	[4.6, "lance_charge", Vector3.ZERO, false, ""],
	[4.65, "", Vector3.ZERO, false, "lance"],
	[4.73, "lance_throw", Vector3.ZERO, false, ""],
	[5.5, "", Vector3.ZERO, false, "nova"],
	[5.75, "nova_raise", Vector3.ZERO, false, ""],
	[5.95, "nova_slam", Vector3.ZERO, false, ""],
	[6.8, "", Vector3.ZERO, false, "ward"],
	[7.1, "ward", Vector3.ZERO, false, ""],
	[8.0, "", Vector3.ZERO, false, "hurt"],
	[8.08, "hurt", Vector3.ZERO, false, ""],
	[8.8, "", Vector3.ZERO, false, "turn"],
	[9.25, "turn", Vector3.ZERO, false, ""],
	[9.6, "", Vector3.ZERO, false, ""],
]
var plan_i := 0
var plan: Array = PLAN
var charging := false
var turning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a == "--side":
			side = true
		elif a == "--close":
			side = true
			close = true
		elif a == "--legacy":
			DefaultLoadout.use_legacy = true          # the old glb robe, for before/after
		elif a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector2(float(v[0]), float(v[1]))
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a == "--casts":
			plan = CAST_PLAN
	Travel._busy = true                    # never write the save
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(delta: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if Realm.enabled() and not p.get_parent().has_meta("realm_done"):
			return
		t += delta
		if t < 1.5:
			return
		started = true
		t = 0.0
		var space := p.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80.0, at.y), Vector3(at.x, -80.0, at.y), Layers.WORLD)
		var hit := space.intersect_ray(q)
		var y: float = (hit.position as Vector3).y + 0.05 if not hit.is_empty() else 1.0
		p.global_position = Vector3(at.x, y, at.y)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.set_view(yaw, -0.16)
		if side:
			cam = Camera3D.new()
			cam.fov = 40.0
			cam.far = 300.0
			get_tree().root.add_child(cam)
			cam.current = true
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	p.gloom = 0.0; p.wounds = 0.0
	Travel._busy = true
	t += delta
	if charging:
		p.set_charge_glow(clampf(p.get_meta("charge_c", 0.0) + delta * 1.6, 0.0, 1.0))
		p.set_meta("charge_c", clampf(p.get_meta("charge_c", 0.0) + delta * 1.6, 0.0, 1.0))
	if turning:
		p.set_view(p._yaw + delta * 2.6, -0.16)
		p.note_combat()                         # the body faces the camera: it turns on the spot
	while plan_i < plan.size() and t >= float(plan[plan_i][0]):
		var e: Array = plan[plan_i]
		var wish := Basis(Vector3.UP, yaw) * (e[2] as Vector3)
		p.debug_drive(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, e[3])
		for a: String in ["jump", "slide"]:
			if a == e[4]:
				Input.action_press(a)
			else:
				Input.action_release(a)
		if e.size() > 4 and plan == CAST_PLAN:
			_act(String(e[4]))
		if String(e[1]) != "":
			_queue_shot(String(e[1]))
		plan_i += 1
	if plan_i >= plan.size() and pending.is_empty():
		_sheet()
		print("MOVESHOTS done ", tag)
		get_tree().quit()


var pending: Array[String] = []


func _act(a: String) -> void:
	turning = a == "turn"
	if a != "charge" and charging:
		charging = false
		p.set_charge_glow(0.0)
	match a:
		"bolt":
			p.fire_bolt({})
			Events.skill_cast.emit(&"bolt")
		"charge":
			charging = true
			p.set_meta("charge_c", 0.0)
		"lance":
			p.fire_bolt({"heavy": true})
			Events.skill_cast.emit(&"lance")
		"nova":
			p._visual.cast()
			Events.skill_cast.emit(&"nova")
		"ward":
			Events.skill_cast.emit(&"ward")
		"hurt":
			p._visual.hurt_react(p.global_position + p._visual.global_basis * Vector3(1.0, 1.0, -2.0), 30.0)


func _queue_shot(ev: String) -> void:
	pending.append(ev)


func _process(_d: float) -> void:
	if cam and p:
		var body := p.get_global_transform_interpolated().origin
		var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		if close:
			cam.global_position = body + right * 0.9 + fwd * 1.5 + Vector3.UP * 1.6
			cam.look_at(body + Vector3.UP * 1.25)
		else:
			cam.global_position = body + right * 3.4 + fwd * 0.8 + Vector3.UP * 1.25
			cam.look_at(body + Vector3.UP * 0.95)
	if not pending.is_empty():
		var ev: String = pending.pop_front()
		var path := ProjectSettings.globalize_path("res://shots/move_%s_%s_%02d_%s.png" % [tag, "side" if side else "cam", shot_i, ev])
		get_viewport().get_texture().get_image().save_png(path)
		files.append(path)
		shot_i += 1


func _sheet() -> void:
	if files.is_empty():
		return
	var tw := 480
	var th := 300
	var cols := 4
	var rows := ceili(float(files.size()) / float(cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in files.size():
		var im := Image.load_from_file(files[i])
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/move_%s_%s_sheet.png" % [tag, "side" if side else "cam"]))

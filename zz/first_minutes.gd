extends Node
## The first minutes, as a new player sees them, plus a per-RENDERED-frame smoothness read of the
## moves (critique B, r29). Loads the night with its loading screen, logs when the cover lifts, when
## the title card / controls hint / opening narration are on screen, takes shots of each, closes the
## narration like a player would, then plays a scripted sequence from the real spawn (walk, sprint,
## jump, slide, roll, reversal, stop, Rift Step, double jump, stick orbit, hang/land...) and, per
## segment and per channel (camera position / angle / FOV / roll, body, body yaw, hand bone), says
## whether that channel moves on frames WITHOUT a physics tick ("tick ratio": ~1 smooth, ~0 means it
## only moves on physics ticks = steps at 60 Hz at 120 fps) and its jitter in median steps.
##   godot --path . res://zz/first_minutes.tscn -- --loading [--cap=120] [--tag=x] [--no-shots]
## Prints "FIRST ..." timeline lines, "FEEL <segment> <channel> ..." and "FIRST done". Never writes
## the save or settings (Travel._busy, HOME isolated by the caller). Quits itself (90 s cap).

const CAP_S := 120.0
var p: Player
var t := 0.0
var t_all := 0.0
var phase := "load"
var cap := 120
var tag := "now"
var shots := true
var ls_seen := false
var ls_done_t := -1.0
var title_t := -1.0
var hint_t := -1.0
var dlg_t := -1.0
var dlg: Node = null
var hud: Node = null
var skel: Skeleton3D
var bone := -1
var samples: Array = []   # [phys_frame, seg, cam_pos, cam_basis, fov, roll, body, body_basis, hand]
var seg := ""
var _shot_n := 0
var _spawn := Vector3.ZERO
var _yaw0 := 0.0
var _pressed: Dictionary = {}

## [start s, end s, segment, wish (x right, z back, camera-relative), sprint, actions at start]
const PLAN := [
	[0.0, 1.5, "idle", Vector3.ZERO, false, []],
	[1.5, 4.0, "walk", Vector3(0, 0, -1), false, []],
	[4.0, 6.5, "sprint", Vector3(0, 0, -1), true, []],
	[6.5, 7.9, "jump", Vector3(0, 0, -1), true, ["jump"]],
	[7.9, 9.4, "slide", Vector3(0, 0, -1), true, ["slide"]],
	[9.4, 10.4, "roll", Vector3(0, 0, -1), false, ["dodge"]],
	[10.4, 12.0, "reverse", Vector3(0, 0, 1), true, []],
	[12.0, 13.4, "stop", Vector3.ZERO, false, []],
	[13.4, 14.6, "rift", Vector3(0, 0, 1), false, ["rift"]],
	[14.6, 16.6, "airjump", Vector3(0, 0, 1), true, ["jump", "jump2"]],
	[16.6, 18.6, "orbit", Vector3(0, 0, 1), false, ["look"]],
	[18.6, 20.0, "strafe", Vector3(1, 0, 0), false, []],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100000      # sample after every other _process: what will be drawn
	Travel._busy = true
	Settings.fullscreen = false
	Settings.monitor = -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cap="):
			cap = int(a.trim_prefix("--cap="))
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a == "--no-shots":
			shots = false
	Settings.vsync = false
	Settings.fps_limit = cap
	get_window().size = Vector2i(1600, 900)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _shot(name: String) -> void:
	if not shots:
		return
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	var path := "res://shots/critB_first_%s_%s.png" % [tag, name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("FIRST shot %s at %.2f s" % [path, t_all])


func _process(d: float) -> void:
	t += d
	t_all += d
	if t_all > CAP_S:
		print("FIRST cap reached in phase %s" % phase)
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if hud == null:
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if (n as Node).get_script() and String((n as Node).get_script().resource_path).ends_with("ui/hud.gd"):
				hud = n
				break
	var zone := p.get_parent()
	var ls := zone.get_node_or_null("LoadingScreen") if zone else null
	if ls and not ls_seen:
		ls_seen = true
		print("FIRST loading screen up at %.2f s" % t_all)
	if ls_seen and ls == null and ls_done_t < 0.0:
		ls_done_t = t_all
		print("FIRST loading screen lifted at %.2f s" % t_all)
	_watch_ui()
	match phase:
		"load":
			if ls_done_t < 0.0 and (ls_seen or t_all < 20.0):
				return
			if ls_done_t < 0.0:
				ls_done_t = t_all
				print("FIRST no loading screen (harness?)")
			phase = "first"
			t = 0.0
			_shot("00_lift")
		"first":
			# the player's first 14 seconds: what is on screen
			if t > 0.6 and _shot_n == 0:
				_shot_n = 1
				_shot("01_after_0.6s")
			elif t > 3.0 and _shot_n == 1:
				_shot_n = 2
				_shot("02_after_3s")
			elif t > 8.0 and _shot_n == 2:
				_shot_n = 3
				_shot("03_after_8s")
			if t > 14.0:
				print("FIRST after 14 s: title seen %s, hint seen %s, narration open %s" % [title_t >= 0.0, hint_t >= 0.0, dlg_t >= 0.0])
				_close_dialogue()
				phase = "settle"
				t = 0.0
		"settle":
			if _dialogue_open():
				_close_dialogue()
				t = 0.0
				return
			if t < 1.0:
				return
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			_spawn = p.global_position
			_yaw0 = p._yaw
			p.set_view(_yaw0, -0.18)
			for s in p.find_children("*", "Skeleton3D", true, false):
				skel = s
				bone = skel.get_bone_count() - 1
				break
			print("FIRST play from spawn %s yaw %.2f (bone %d)" % [_spawn, _yaw0, bone])
			phase = "play"
			t = 0.0
		"play":
			_play()
		"done":
			pass


func _watch_ui() -> void:
	if hud and title_t < 0.0:
		var tl := hud.get("_title") as Label
		if tl and tl.modulate.a > 0.5 and tl.is_visible_in_tree():
			title_t = t_all
			print("FIRST title card visible at %.2f s (loading lifted %.2f)" % [t_all, ls_done_t])
			_shot("title")
	if hud and hint_t < 0.0:
		var hl := hud.get("_hint") as Label
		if hl and hl.modulate.a > 0.5 and ls_done_t >= 0.0:
			hint_t = t_all
			print("FIRST controls hint visible at %.2f s, width %.0f px of %.0f" % [t_all, hl.get_combined_minimum_size().x + hl.position.x, hl.get_viewport_rect().size.x])
	if dlg_t < 0.0 and _dialogue_open():
		dlg_t = t_all
		print("FIRST opening narration open at %.2f s (loading lifted %.2f)" % [t_all, ls_done_t])
		if ls_done_t >= 0.0:
			_shot("narration")


func _dialogue_open() -> bool:
	if dlg == null:
		dlg = get_tree().root.get_node_or_null("Dialogue")
	return dlg != null and dlg.has_method("is_open") and bool(dlg.call("is_open"))


func _close_dialogue() -> void:
	if _dialogue_open() and dlg.has_method("close"):
		dlg.call("close")


func _press(a: String) -> void:
	Input.action_press(a)
	_pressed[a] = t


func _play() -> void:
	# release taps after 0.3 s (a held jump is a full jump)
	for a in _pressed.keys():
		if t - float(_pressed[a]) > 0.3:
			Input.action_release(a)
			_pressed.erase(a)
	var cur: Array = []
	for row in PLAN:
		if t >= float(row[0]) and t < float(row[1]):
			cur = row
			break
	if cur.is_empty():
		Input.action_release("look_right")
		p.debug_drive(Vector3.ZERO)
		phase = "done"
		_report()
		print("FIRST done")
		get_tree().quit()
		return
	var name: String = cur[2]
	if name != seg:
		seg = name
		print("FIRST seg %-8s at %s vel %s ground %s hang %s roll %.2f slide %s mantle %.2f step %.2f" % [name, p.global_position, p.velocity, p.is_grounded(), p.is_hanging(), p._roll_t, p.is_sliding(), p._mantle_t, p._step_t])
		for act in cur[5]:
			match String(act):
				"jump":
					_press("jump")
				"slide":
					Input.action_press("slide")
					get_tree().create_timer(1.2).timeout.connect(func() -> void: Input.action_release("slide"))
				"dodge":
					_press("dodge")
				"rift":
					p.debug_drive(Basis(Vector3.UP, p._yaw) * (cur[3] as Vector3), false)
					p.shadowstep()
				"jump2":
					get_tree().create_timer(0.38).timeout.connect(func() -> void: _press("jump"))
				"look":
					Input.action_press("look_right", 0.6)
					get_tree().create_timer(1.6).timeout.connect(func() -> void: Input.action_release("look_right"))
		if name in ["walk", "sprint", "reverse", "strafe"] and shots:
			_shot("seg_" + name)
	var wish := Basis(Vector3.UP, p._yaw) * (cur[3] as Vector3)
	p.debug_drive(wish, bool(cur[4]))
	var cam := get_viewport().get_camera_3d()
	var vis := p.get_node("Visual") as Node3D
	var vx := vis.get_global_transform_interpolated()
	var hand := Vector3.ZERO
	if OS.get_cmdline_user_args().has("--yaw-trace") and seg == "strafe":
		print("YAW phys %d raw %.4f interp %.4f body_interp %.4f frac %.2f" % [Engine.get_physics_frames(), vis.rotation.y, vx.basis.get_euler().y, p.get_global_transform_interpolated().basis.get_euler().y, Engine.get_physics_interpolation_fraction()])
	var rig := p.get_node("Visual")
	if rig.has_method("muzzle_drawn"):
		hand = rig.call("muzzle_drawn")
	elif skel and bone >= 0:
		hand = (skel.get_global_transform_interpolated() * skel.get_bone_global_pose(bone)).origin
	samples.append([Engine.get_physics_frames(), seg, cam.global_position, cam.global_basis, cam.fov, cam.rotation.z, vx.origin, vx.basis, hand, (p.get_node("CameraRig/Pitch") as Node3D).rotation.x, Time.get_ticks_usec()])


static func _ang(a: Basis, b: Basis) -> float:
	var q := Quaternion(a.orthonormalized()).inverse() * Quaternion(b.orthonormalized())
	return absf(q.normalized().get_angle())


func _delta(ch: int, k: int) -> float:
	var a = samples[k - 1][ch]
	var b = samples[k][ch]
	if a is Vector3:
		return (a as Vector3).distance_to(b)
	if a is Basis:
		return _ang(a, b)
	return absf(float(b) - float(a))


func _report() -> void:
	var chans := [[2, "cam_pos"], [3, "cam_ang"], [4, "fov"], [5, "cam_roll"], [9, "pitch"], [6, "body"], [7, "body_yaw"], [8, "hand"]]
	var segs: Array[String] = []
	for s in samples:
		if not segs.has(s[1]):
			segs.append(s[1])
	var worst := 1.0
	var worst_at := ""
	for sname in segs:
		var line := "FEEL %-8s" % sname
		for c in chans:
			var tick := 0.0
			var tick_n := 0
			var free := 0.0
			var free_n := 0
			var steps: Array[float] = []
			for k in range(1, samples.size()):
				if samples[k][1] != sname or samples[k - 1][1] != sname:
					continue
				var dt := maxf(float(samples[k][10] - samples[k - 1][10]) * 0.000001, 0.0005)
				var dv := _delta(c[0], k) / dt * 0.00833     # per 1/120 s: frame pacing doesn't skew it
				steps.append(dv)
				if int(samples[k][0]) != int(samples[k - 1][0]):
					tick += dv
					tick_n += 1
				else:
					free += dv
					free_n += 1
			var total := tick + free
			var thresh := 0.002 if c[1] in ["cam_pos", "body", "hand"] else (0.02 if c[1] == "fov" else 0.0004)
			if steps.size() < 6 or tick_n == 0 or free_n == 0 or total / float(steps.size()) < thresh:
				line += "  %s -" % c[1]
				continue
			var ratio := (free / free_n) / maxf(tick / tick_n, 1e-9)
			if ratio < worst:
				worst = ratio
				worst_at = "%s/%s" % [sname, c[1]]
			line += "  %s %.2f" % [c[1], ratio]
		print(line)
	print("FEEL worst tick ratio %.2f at %s (1 = moves every rendered frame, 0 = only on physics ticks)" % [worst, worst_at])

extends Node
## A heavy fight, measured (the night's harness starts it: core/debug/main_harness.gd, so packed builds run it too).
##   <game> -- --fight-bench --fps-log [--boss=thornwarden|bone_abbot|anchoress|warden|none] [--n=10] [--secs=20] [--no-cast]
## The night is built, the wanderer stands on open ground, a boss and N grunts are spawned round him and come at
## him, and every spell slot is pressed over and over (cooldowns reset). He cannot die (his wounds are cleared).
## At the end "FIGHT" prints the frame times and the engine monitors averaged over the fight; --ab-enemies then
## measures the foes' thinking (far, near) and the spells by switching each off for a few seconds.
const Tiers := preload("res://core/life/encounters/tiers.gd")
const SPOT := Vector2(62.0, 60.0)
const BOSSES := {"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"anchoress": "res://core/enemy/anchoress.gd", "warden": "res://core/enemy/ascended_warden.gd"}
const KINDS := ["wretch", "husk", "spitter", "ossuant", "leaper", "crawler"]

var main: Node
var p: Player
var t := 0
var started := false
var boss := "thornwarden"
var n := 10
var secs := 20.0
var cast := true
var _frames_ms := PackedFloat32Array()
var _mon := {}
var _book: SkillBook


func begin(night: Node) -> void:
	main = night
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			boss = a.trim_prefix("--boss=")
		elif a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--secs="):
			secs = float(a.trim_prefix("--secs="))
		elif a == "--no-cast":
			cast = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)     # the real cost, not the refresh cap


func _process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if main != null and main.has_meta("realm_done") and t > 300:
			started = true
			_run()
		return
	p.wounds = 0.0
	p.gloom = 0.0
	if _frames_ms.size() < 100000:
		_frames_ms.append(delta * 1000.0)


func _run() -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var gy := RealmLayout.ground(space, SPOT.x, SPOT.y)
	var base := Vector3(SPOT.x, gy, SPOT.y)
	p.teleport(base + Vector3(0, 0.3, 0))
	p.set_view(0.0, -0.08)                       # looking down -z, where they come from
	await _wait(2.0)
	if boss != "none":
		var bs := load(BOSSES.get(boss, BOSSES.thornwarden)) as GDScript
		var b := bs.new() as Enemy
		main.add_child(b)
		b.global_position = base + Vector3(0, 0.2, -16.0)
		b.home = b.global_position
	for i in n:
		var e := (load(Tiers.KIND_PATHS[KINDS[i % KINDS.size()]]) as GDScript).new() as Enemy
		main.add_child(e)
		var a := -PI * 0.5 + PI * float(i) / maxf(float(n - 1), 1.0)
		e.global_position = base + Vector3(cos(a) * 11.0, 0.3, -absf(sin(a)) * 11.0 - 3.0)
		e.home = e.global_position
	for c in p.find_children("*", "", true, false):
		if c is SkillBook:
			_book = c
			break
	print("FIGHT start: boss %s, %d grunts, casting %s" % [boss, n, cast])
	_frames_ms.clear()
	var t0 := Time.get_ticks_msec()
	var slot := 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if cast and _book:
			_book.reset_cooldowns()
			_book.press(slot % 4)                   # not slot 4 (Rift Step): it blinks the wanderer down the road
			slot += 1
		_sample()
		await get_tree().create_timer(0.12).timeout
	_report()
	if "--ab-enemies" in OS.get_cmdline_user_args():
		# the same fight with every foe's logic and physics frozen (still drawn): what the foes' thinking costs
		var fr: float = await _avg_frame(4.0)
		var far := 0
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if (e as Node3D).global_position.distance_to(p.global_position) > 40.0:
				(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
				far += 1
		var off_far: float = await _avg_frame(4.0)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
		var off: float = await _avg_frame(4.0)
		print("FIGHT A/B all foes thinking %.2f ms | the %d far ones frozen %.2f ms (far cost %.2f) | all frozen %.2f ms (near cost %.2f)" % [fr, far, off_far, fr - off_far, off, off_far - off])
		# the spells' lights: every light the casting made (bolts, wards, wells) switched off
		var lit := 0
		for l in get_tree().root.find_children("*", "OmniLight3D", true, false):
			if String((l as Node).get_meta(&"light_class", "")) == "player_orb":
				(l as Light3D).visible = false
				lit += 1
		print("FIGHT %d player-orb lights at the moment" % lit)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).process_mode = Node.PROCESS_MODE_INHERIT
		var none: float = await _avg_frame(3.0)
		cast = false
		var quiet: float = await _avg_frame(4.0)
		print("FIGHT A/B casting %.2f ms, not casting %.2f ms -> spells %.2f ms a frame" % [none, quiet, none - quiet])
	get_tree().quit()


func _avg_frame(s: float) -> float:
	var n0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(s * 1.0e6):
		if cast and _book:
			_book.reset_cooldowns()
			_book.press(randi() % 4)
		await get_tree().create_timer(0.12).timeout
	return float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(Engine.get_process_frames() - n0), 1.0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _sample() -> void:
	var m := {
		"process ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"prims k": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		"enemies": float(get_tree().get_nodes_in_group(Groups.ENEMY).size()),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"physics active": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
	}
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	m["render cpu ms"] = RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	m["gpu ms"] = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	for k: String in m:
		var arr: Array = _mon.get(k, [])
		arr.append(float(m[k]))
		_mon[k] = arr


func _report() -> void:
	var f := Array(_frames_ms)
	f.sort()
	var avg := 0.0
	for x: float in f:
		avg += x
	avg /= maxf(float(f.size()), 1.0)
	var p95: float = f[int(f.size() * 0.95)] if f.size() > 0 else 0.0
	var p99: float = f[int(f.size() * 0.99)] if f.size() > 0 else 0.0
	print("FIGHT frames %d  avg %.2f ms (%.0f fps)  p95 %.2f  p99 %.2f  worst %.2f" % [f.size(), avg, 1000.0 / maxf(avg, 0.01), p95, p99, f.back() if f.size() > 0 else 0.0])
	for k: String in _mon:
		var arr: Array = _mon[k]
		var s := 0.0
		var mx := 0.0
		for x: float in arr:
			s += x
			mx = maxf(mx, x)
		print("FIGHT %-15s avg %8.2f  max %8.2f" % [k, s / maxf(float(arr.size()), 1.0), mx])

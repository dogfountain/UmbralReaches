extends Node
## The wanderer's render cost, A/B, quickly and robust to other processes' spikes: the same view and
## settings as zz/perf_tour (r_spawn_west, Cinematic, 2x2 pixels, vsync off, settings in memory only,
## no save writes), then each part of the Player switched off and on in short paired windows, many
## times; the cost is the MEDIAN of the on-off differences (a spike spoils one pair, not the result).
##   godot --path . res://zz/char_cost.tscn [-- --pairs=14 --preset=2 --stress=2]
## Prints "CHARCOST <part> median +x.xx ms (pairs n, on a ms off b ms)" and "CHARCOST done".
const AT := Vector3(0.0, NAN, 30.0)
const YAW := PI * 0.5
const WIN := 0.5
const SETTLE := 0.2
var main: Node
var p: Player
var pairs := 14
var parts: Array = []        # [name, Callable(on: bool)]
var pi := 0
var k := 0                   # window index: even = on, odd = off
var t := 0.0
var wait := 3.0
var acc_t := 0.0
var acc_n := 0
var on_ms := PackedFloat32Array()
var off_ms := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preset := 2
	var stress := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pairs="):
			pairs = int(a.trim_prefix("--pairs="))
		elif a.begins_with("--preset="):
			preset = int(a.trim_prefix("--preset="))
		elif a.begins_with("--stress="):
			stress = float(a.trim_prefix("--stress="))
	Settings.set_preset_fields(preset)
	Settings.fullscreen = false
	Settings.vsync = false
	Settings.fps_limit = 0
	Settings.render_scale = stress
	Settings.fov = 90.0
	Travel._busy = true
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _parts() -> void:
	var vis := p.get_node("Visual") as Node3D
	var lights: Array = p.find_children("*", "Light3D", true, false)
	var body: Array = vis.find_children("Skeleton", "Skeleton3D", true, false)
	var fx: Array = vis.find_children("*", "GPUParticles3D", true, false) + vis.find_children("Starburst", "", true, false) + vis.find_children("Face", "", true, false)
	parts = [
		["player (all)", func(on: bool) -> void: p.visible = on],
		["player lights", func(on: bool) -> void:
			for l in lights:
				(l as Light3D).visible = on],
		["body mesh + shadow proxy", func(on: bool) -> void:
			for b in body:
				(b as Node3D).visible = on],
		["face, particles, flare", func(on: bool) -> void:
			for f in fx:
				(f as Node3D).visible = on],
		["  void face + mist", func(on: bool) -> void:
			for f in vis.find_children("Face", "", true, false):
				(f as Node3D).visible = on],
		["  orb trail motes", func(on: bool) -> void:
			for f in vis.find_children("Trail", "", true, false):
				(f as Node3D).visible = on],
		["  orb starburst flare", func(on: bool) -> void:
			for f in vis.find_children("Starburst", "", true, false):
				(f as Node3D).visible = on],
		["not the wanderer (fx, ring)", func(on: bool) -> void:
			for c in p.get_children():
				if c is Node3D and c != vis and String(c.name) != "CameraRig":
					(c as Node3D).visible = on],
	]
	if "--only-fx" in OS.get_cmdline_user_args():
		parts = parts.slice(3)


func _process(d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
		return
	if Realm.enabled() and not main.has_meta("realm_done"):
		return
	Travel._busy = true
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if n is Node3D:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(n as Node3D).visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	_hold()
	if parts.is_empty():
		_parts()
	if wait > 0.0:
		wait -= d
		return
	t += d
	if t < SETTLE:
		return
	acc_t += d
	acc_n += 1
	if t < SETTLE + WIN:
		return
	var ms := acc_t / float(acc_n) * 1000.0
	if k % 2 == 0:
		on_ms.append(ms)
	else:
		off_ms.append(ms)
	acc_t = 0.0
	acc_n = 0
	t = 0.0
	k += 1
	(parts[pi][1] as Callable).call(k % 2 == 0)        # next window: on after an off, off after an on
	if k < pairs * 2:
		return
	var diffs := PackedFloat32Array()
	for j in mini(on_ms.size(), off_ms.size()):
		diffs.append(on_ms[j] - off_ms[j])
	diffs.sort()
	var med := diffs[diffs.size() / 2] if diffs.size() % 2 == 1 else (diffs[diffs.size() / 2 - 1] + diffs[diffs.size() / 2]) * 0.5
	on_ms.sort()
	off_ms.sort()
	print("CHARCOST %-26s median %+.2f ms (pairs %d, on %.2f ms off %.2f ms, iqr %+.2f..%+.2f)" % [parts[pi][0], med, diffs.size(),
		on_ms[on_ms.size() / 2], off_ms[off_ms.size() / 2], diffs[diffs.size() / 4], diffs[diffs.size() * 3 / 4]])
	(parts[pi][1] as Callable).call(true)
	on_ms.clear()
	off_ms.clear()
	k = 0
	pi += 1
	wait = 0.5
	if pi >= parts.size():
		print("CHARCOST done")
		get_tree().quit()


func _hold() -> void:
	var at := AT
	if is_nan(at.y):
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
	if p.global_position.distance_to(at) > 0.3:
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.set_view(YAW, -0.08)

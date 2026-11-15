extends Node
## Where the wanderer's per-frame cost goes: boots the Realm, stands at the spawn and at the fen, and times the pieces of
## Player._process / _physics_process (and the two whole) over many calls in this one process.
##   godot --headless --path . res://zz/player_parts.tscn  -> "PARTS <view> <us per call> <piece>"
const REPS := 400
var main: Node
var p: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	await get_tree().create_timer(4.0, true, false, true).timeout
	for pt: Array in [["spawn", Vector3(0.0, NAN, 30.0)], ["fen", Vector3(70.0, NAN, -20.0)]]:
		var at: Vector3 = pt[1]
		at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
		p.global_position = at
		p.velocity = Vector3.ZERO
		await get_tree().create_timer(2.5, true, false, true).timeout
		_time(String(pt[0]), "_process (whole)", func() -> void: p._process(1.0 / 60.0))
		_time(String(pt[0]), "_physics_process (whole)", func() -> void: p._physics_process(1.0 / 60.0))
		_time(String(pt[0]), "camera _update_arm", func() -> void: p.camera_ctl._update_arm(1.0 / 60.0))
		_time(String(pt[0]), "camera _cam_frame", func() -> void: p.camera_ctl._cam_frame(1.0 / 60.0))
		_time(String(pt[0]), "casting _frame_fx", func() -> void: p.casting._frame_fx())
		_time(String(pt[0]), "locomotion _step_down", func() -> void: p.locomotion._step_down())
		_time(String(pt[0]), "traversal _beam_probe", func() -> void: p.traversal._beam_probe(Vector3.ZERO))
		_time(String(pt[0]), "traversal _note_contacts", func() -> void: p.traversal._note_contacts(1.0 / 60.0))
		_time(String(pt[0]), "camera _update_camera", func() -> void: p.camera_ctl._update_camera(1.0 / 60.0, Vector3.ZERO, false, 0.0))
		_time(String(pt[0]), "casting _animate", func() -> void: p.casting._animate(1.0 / 60.0, Vector3.ZERO))
		_time(String(pt[0]), "vitals _stuck_tick", func() -> void: p.vitals._stuck_tick(1.0 / 60.0, Vector3.ZERO))
		_time(String(pt[0]), "move_and_slide (idle)", func() -> void: p.velocity = Vector3.ZERO; p.move_and_slide())
		_time(String(pt[0]), "locomotion _try_step_up", func() -> void: p.locomotion._try_step_up(Vector3.ZERO, 1.0 / 60.0))
		_time(String(pt[0]), "locomotion _land", func() -> void: p.locomotion._land(true, 0.0))
		_time(String(pt[0]), "vitals _update_gloom", func() -> void: p.vitals._update_gloom(1.0 / 60.0))
		_time(String(pt[0]), "targeting _lock_tick", func() -> void: p.targeting._lock_tick(1.0 / 60.0))
		_time(String(pt[0]), "evasion _updraft", func() -> void: p.evasion._updraft(p.global_position))
	get_tree().quit()


func _time(view: String, nm: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for i in REPS:
		f.call()
	print("PARTS %-6s %8.1f us  %s" % [view, float(Time.get_ticks_usec() - t0) / float(REPS), nm])

extends Node
## Tree swap look check: the player walks a straight line a metre a step (STEP_FRAMES frames each) and every step
## is saved, so trees crossing their near / far swap (45-63 m) can be seen dissolving (or popping) frame to frame.
##   godot --path . res://zz/tree_fade_shots.tscn -- [--from=x,z] [--yaw=rad] [--steps=40] [--out=/abs/dir]
## Saves are blocked (Travel._busy); settings in memory only.

const STEP_FRAMES := 6
var p: Player
var main: Node
var from := Vector2(-100.8, 103.7)
var yaw := 0.0
var steps := 40
var out := ""
var started := 0
var k := -1
var wait := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			var v := a.trim_prefix("--from=").split(",")
			from = Vector2(float(v[0]), float(v[1]))
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--steps="):
			steps = int(a.trim_prefix("--steps="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if out == "":
		out = ProjectSettings.globalize_path("res://shots/tree_fade")
	DirAccess.make_dir_recursive_absolute(out)
	Settings.set_preset_fields(2)
	Settings.fov = 90.0
	Settings.fullscreen = false
	Settings.vsync = true
	Settings.fps_limit = 0
	Settings.motion_blur = 0.0
	get_window().size = Vector2i(1280, 800)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			Settings.changed.emit()
			get_window().size = Vector2i(1280, 800)
		return
	if not main.has_meta("realm_done"):
		return
	started += 1
	if started < 240:
		return
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	_place()
	if wait > 0:
		wait -= 1
		return
	if k >= 0:
		get_viewport().get_texture().get_image().save_png("%s/step_%03d.png" % [out, k])
	k += 1
	if k >= steps:
		print("TREE_FADE done %s" % out)
		OS.kill(OS.get_process_id())
		return
	wait = STEP_FRAMES


func _place() -> void:
	var dir := Vector2(sin(yaw), cos(yaw)) * -1.0
	var at2 := from + dir * float(maxi(k, 0))
	var at := Vector3(at2.x, 0.0, at2.y)
	at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.1
	if p.global_position.distance_to(at) > 0.05:
		p.global_position = at
		p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.set_view(yaw, -0.03)

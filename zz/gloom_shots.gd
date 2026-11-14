extends Node
## The world answering the Gloom: one view, pinned at three Gloom levels (windowed; headless cannot render).
##   godot --path <abs> res://zz/gloom_shots.tscn -- --out=<dir> [--levels=0,20,60,90,0] [--at=x,z] [--yaw=a] [--pitch=a] [--hold=9]
## Boots the night, stands the wanderer at --at (default: the spawn) looking along --yaw, then for each level pins
## p.gloom, waits --hold seconds for the eased state to settle, saves <out>/gloom_<level>_<n>.png and prints the mean
## frame time over the last 2 s of the hold ("GLOOMSHOT level ... ms ...") and GloomWorld's severity.
var main: Node
var p: Player
var out := "/tmp/gloom_shots"
var levels: Array = [0, 20, 60, 90, 0]
var at := Vector2.INF
var yaw := INF
var pitch := -0.12
var hold := 9.0
var frames := 0
var placed := false
var li := 0
var t := 0.0
var acc := 0.0
var acc_n := 0
var gw: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--levels="):
			levels = Array(a.trim_prefix("--levels=").split(","))
		elif a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector2(float(v[0]), float(v[1]))
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--pitch="):
			pitch = float(a.trim_prefix("--pitch="))
		elif a.begins_with("--hold="):
			hold = float(a.trim_prefix("--hold="))
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(delta: float) -> void:
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.wounds = 0.0
	if not placed:
		if frames < 500 or not main.has_meta("realm_done"):
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		if at != Vector2.INF:
			var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 120.0, at.y), Vector3(at.x, -50.0, at.y), Layers.WORLD)
			var h := p.get_world_3d().direct_space_state.intersect_ray(q)
			p.global_position = (h.position if h else Vector3(at.x, 2.0, at.y)) + Vector3.UP * 0.3
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
		if yaw != INF:
			p.set_view(yaw, pitch)
		gw = main.get_node_or_null("GloomWorld")
		placed = true
		t = -1.5
		return
	var lv := float(levels[li])
	p.gloom = lv
	if int(frames) % 6 == 0:
		Events.gloom_changed.emit(lv, p.gloom_max)
	t += delta
	if t > hold - 2.0:
		acc += delta
		acc_n += 1
	if t >= hold:
		var path := out.path_join("gloom_%03d_%d.png" % [int(lv), li])
		get_viewport().get_texture().get_image().save_png(path)
		print("GLOOMSHOT level ", lv, " sev ", snappedf(gw.severity, 0.001) if gw else -1.0, " ms ", snappedf(acc / maxf(acc_n, 1) * 1000.0, 0.01), " ", path)
		li += 1
		t = 0.0
		acc = 0.0
		acc_n = 0
		if li >= levels.size():
			print("GLOOMSHOT done")
			get_tree().quit()

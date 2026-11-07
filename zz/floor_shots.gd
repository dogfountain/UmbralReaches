extends Node
## Floor stills: the player camera inside a registered site (WorldLanes.sites), looking down at its
## floor, to see the ground showing through. In memory only (saves held).
##   godot --path . res://zz/floor_shots.tscn -- --out=<dir> --sites=glade_shrine,r37w_stables [--tag=before]
const SETTLE := 70
var p: Player
var main: Node
var views: Array = []
var i := -1
var wait := 0
var out := "/tmp"
var tag := "shot"
var names: PackedStringArray = []
var t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--sites="):
			names = a.trim_prefix("--sites=").split(",")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _build_views() -> void:
	for st: Dictionary in WorldLanes.sites:
		if not String(st.name) in names:
			continue
		var r: Rect2 = st.rect
		var c := r.get_center()
		var fy := float(st.floor_y)
		# a spot on the floor at one end, looking across to the middle
		var from := Vector3(c.x - r.size.x * 0.05, fy + 0.1, c.y - r.size.y * 0.1)
		var to := Vector3(c.x - r.size.x * 0.25, fy, c.y + r.size.y * 0.1)
		views.append([String(st.name), from, to])


func _process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or t < 600:
		return
	if views.is_empty() and i < 0:
		_build_views()
		if views.is_empty():
			print("FLOORSHOT no such sites")
			get_tree().quit()
			return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if i >= 0 and i < views.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("%s_%s.png" % [views[i][0], tag])
		get_viewport().get_texture().get_image().save_png(path)
		print("FLOORSHOT ", path)
	i += 1
	if i >= views.size():
		print("FLOORSHOTS done")
		get_tree().quit()
		return
	_hold()
	var v: Array = views[i]
	var d: Vector3 = (v[2] as Vector3) - (v[1] as Vector3)
	p.set_view(atan2(-d.x, -d.z), -0.5)
	wait = SETTLE


func _hold() -> void:
	p.global_position = views[i][1]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()

extends Node
## Stills from a free camera in the real night (windowed; in memory only, saves held).
##   godot --path . res://zz/free_shots.tscn -- --out=<dir> [--tag=after] --view=name:cx:cy:cz:tx:ty:tz ...
## cx,cz / tx,tz are world xz; cy / ty are metres over the ground there (eye and look-at). Prints each
## view's ground heights and the terrain under the look-at point.
const Footing := preload("res://core/world/footing.gd")
const QuestProps := preload("res://core/story/quest_props.gd")
const SETTLE := 60
var p: Player
var main: Node
var views: Array = []
var i := -1
var wait := 0
var out := "/tmp"
var tag := "shot"
var t := 0
var cam: Camera3D
var bell := Vector3.ZERO         ## --bell=x:z puts a bell prop on the ground there
var bell_kind := "bell"
var lamp := false                ## --lamp: a lantern-warm light beside the bell


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a == "--lamp":
			lamp = true
		elif a.begins_with("--bell="):
			var g := a.trim_prefix("--bell=").split(":")
			bell = Vector3(float(g[0]), 0.0, float(g[1]))
			if g.size() > 2:
				bell_kind = g[2]
			if g.size() > 3:
				bell.y = float(g[3])
		elif a.begins_with("--view="):
			var f := a.trim_prefix("--view=").split(":")
			views.append([f[0], Vector3(float(f[1]), float(f[2]), float(f[3])), Vector3(float(f[4]), float(f[5]), float(f[6]))])
	get_window().size = Vector2i(1280, 800)
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
	if not main.has_meta("realm_done") or t < 600:
		return
	(p.get_node("Visual") as Node3D).visible = false
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if cam == null and bell != Vector3.ZERO:
		if bell.y == 0.0:
			bell.y = _ground(bell.x, bell.z)
		QuestProps.make(main as Node3D, "TestBell", bell_kind, Transform3D(Basis.IDENTITY, bell))
		if lamp:
			var ol := OmniLight3D.new()
			ol.light_color = Color(1.0, 0.68, 0.36)
			ol.light_energy = 1.6
			ol.omni_range = 7.0
			main.add_child(ol)
			ol.global_position = bell + Vector3(1.4, 1.3, 1.2)
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 70.0
		cam.near = 0.08
		add_child(cam)
		cam.make_current()
	if i >= 0 and i < views.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("%s_%s.png" % [views[i][0], tag])
		get_viewport().get_texture().get_image().save_png(path)
		print("FREESHOT ", path)
	i += 1
	if i >= views.size():
		print("FREESHOTS done")
		get_tree().quit()
		return
	_hold()
	wait = SETTLE


func _hold() -> void:
	var v: Array = views[i]
	var a := v[1] as Vector3
	var b := v[2] as Vector3
	var eye := Vector3(a.x, _ground(a.x, a.z) + a.y, a.z)
	var tgt := Vector3(b.x, _ground(b.x, b.z) + b.y, b.z)
	p.global_position = Vector3(a.x, eye.y - 3.0, a.z) if i < 0 else p.global_position
	cam.global_position = eye
	cam.look_at(tgt, Vector3.UP)
	# keep the player (and the streaming around it) at the view
	p.global_position = Vector3(a.x, eye.y + 0.5, a.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()

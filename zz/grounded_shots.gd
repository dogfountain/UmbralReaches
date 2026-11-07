extends Node
## Stills of a prop's base from a low side camera (the ground showing under it, against the sky).
## In memory only (saves held).
##   godot --path . res://zz/grounded_shots.tscn -- --out=<dir> [--tag=after] [--only=oak_w,oak_s]
##   --view=name:x:z:look_x:look_z:look_up  adds a view (camera on the ground at x,z, eye 1.7 m, looking at
##   the terrain height under look_x,look_z plus look_up metres)
const SETTLE := 70
var p: Player
var main: Node
var views: Array = []
var i := -1
var wait := 0
var out := "/tmp"
var tag := "shot"
var only: PackedStringArray = []
var t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	var oak := Vector2(-70.0, 206.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
		elif a.begins_with("--view="):
			var f := a.trim_prefix("--view=").split(":")
			views.append([f[0], Vector2(float(f[1]), float(f[2])), Vector2(float(f[3]), float(f[4])), float(f[5])])
	if views.is_empty():
		# the Grandmother Oak from four sides, 17 m out, the base against the sky
		for d: Array in [["oak_w", Vector2(-1, 0)], ["oak_s", Vector2(0, 1)], ["oak_e", Vector2(1, 0)], ["oak_n", Vector2(0, -1)]]:
			views.append([d[0], oak + (d[1] as Vector2) * 17.0, oak, 2.5])
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _ground(x: float, z: float) -> float:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for k in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 140, z), Vector3(x, -60, z), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return 0.0


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
	if i >= 0 and i < views.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join("%s_%s.png" % [views[i][0], tag])
		get_viewport().get_texture().get_image().save_png(path)
		print("GROUNDSHOT ", path)
	i += 1
	while i < views.size() and not only.is_empty() and not String(views[i][0]) in only:
		i += 1
	if i >= views.size():
		print("GROUNDSHOTS done")
		get_tree().quit()
		return
	_hold()
	var v: Array = views[i]
	var from := v[1] as Vector2
	var to := v[2] as Vector2
	var eye := _ground(from.x, from.y) + 1.7
	var tgt := _ground(to.x, to.y) + float(v[3])
	var d := Vector3(to.x - from.x, tgt - eye, to.y - from.y)
	p.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	wait = SETTLE


func _hold() -> void:
	var v: Array = views[i]
	var from := v[1] as Vector2
	p.global_position = Vector3(from.x, _ground(from.x, from.y) + 0.05, from.y)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()

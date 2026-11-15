extends Node
## One still of a path where low plants grew on the road (realm_flora.gd, the undergrowth rows: the 1 m keep-off grid let a
## cell that read 1.x hold ground 0.2 m from the edge). Windowed:
##   godot --path . res://zz/flora_path_still.tscn -- --realm-modules=land,flora --out=/some/dir/name.png [--at=-166,-77]
## Saves are locked (Travel._busy); the HUD is hidden; quits itself.
var t := 0.0
var main: Node
var cam: Camera3D
var started := false
var out := "/private/tmp/flora_path.png"
var at := Vector2(-166.0, -77.0)


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector2(float(v[0]), float(v[1]))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if cam != null and not cam.current:
		cam.current = true
	if started:
		return
	if main == null or not main.has_meta("realm_done") or t < 8.0:
		if t > 200.0:
			get_tree().quit(1)
		return
	started = true
	_run()


func _run() -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	p.global_position = Vector3(at.x, 60.0, at.y)
	cam = Camera3D.new()
	cam.fov = 60.0
	main.add_child(cam)
	cam.current = true
	var gy := RealmLayout.ground(main.get_world_3d().direct_space_state, at.x, at.y)
	# look along the path from 5 m up the road
	var near := RealmLayout.path_dist(at)
	var dir := Vector2(1, 0)
	for k in 16:
		var a := TAU * float(k) / 16.0
		var q := at + Vector2(cos(a), sin(a)) * 3.0
		if RealmLayout.path_dist(q) < near:
			dir = Vector2(cos(a), sin(a))
	cam.global_position = Vector3(at.x - dir.x * 5.0, gy + 2.2, at.y - dir.y * 5.0)
	cam.look_at(Vector3(at.x + dir.x * 3.0, gy, at.y + dir.y * 3.0))
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("STILL saved ", out, " path_dist at the spot ", near)
	get_tree().quit()
